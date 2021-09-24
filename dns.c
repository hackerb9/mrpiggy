/* File MSNDNS.C
 * Domain name server requester
 *
 * Copyright (C) 1991, University of Waterloo.
 *	Copyright (C) 1982, 1999, Trustees of Columbia University in the 
 *	City of New York.  The MS-DOS Kermit software may not be, in whole 
 *	or in part, licensed or sold for profit as a software product itself,
 *	nor may it be included in or distributed with commercial products
 *	or otherwise distributed by commercial concerns to their clients 
 *	or customers without written permission of the Office of Kermit 
 *	Development and Distribution, Columbia University.  This copyright 
 *	notice must not be removed, altered, or obscured.
 *
 * Original version created by Erick Engelke of the University of
 *  Waterloo, Waterloo, Ontario, Canada.
 * Adapted and modified for MS-DOS Kermit by Joe R. Doupnik, 
 *  Utah State University, jrd@cc.usu.edu
 *
 * Last edit
 * 12 Jan 1995 v3.14
 *
 * Originally based on NCSA Telnet
 *
 */

#include "tcp.h"
#include "netlibc.h"

byte *def_domain;

longword def_nameservers[ MAX_NAMESERVERS ];
int last_nameserver;
extern int icmp_unreach;		/* catch ICMP unreachable msgs */

static udp_Socket *dom_sock;

#define DNS_PORT 53		/* Domain Name Service lookup port */
#define DOMSIZE 512 		/* maximum domain message size to mess with */

/*
 *  Header for the DOMAIN queries
 */
struct dhead {
	word	ident,		/* unique identifier */
		flags,
		qdcount,	/* question section, # of entries */
		ancount,	/* answers, how many */
		nscount,	/* count of name server Response Records */
		arcount;	/* number of "additional" records */
};

/*
 *  flag masks for the flags field of the DOMAIN header
 */
#define DQR		0x8000	/* query = 0, response = 1 */
#define DOPCODE		0x7100	/* opcode, see below */
#define DAA		0x0400	/* Authoritative answer */
#define DTC		0x0200	/* Truncation, response was cut off at 512 */
#define DRD		0x0100	/* Recursion desired */
#define DRA		0x0080	/* Recursion available */
#define DRCODE		0x000F	/* response code, see below */

/* opcode possible values: */
#define DOPQUERY	0	/* a standard query */
#define DOPIQ		1	/* an inverse query */
#define DOPCQM		2	/* a completion query, multiple reply */
#define DOPCQU		3     	/* a completion query, single reply */
/* the rest reserved for future */

/* legal response codes: */
#define DROK	0		/* okay response */
#define DRFORM	1		/* format error */
#define DRFAIL	2		/* their problem, server failed */
#define DRNAME	3		/* name error, we know name doesn't exist */
#define DRNOPE	4		/* no can do request */
#define DRNOWAY	5		/* name server refusing to do request */

#define DTYPEA		1	/* host address resource record (RR) */
#define DTYPEPTR	12	/* a domain name ptr */

#define DIN		1	/* ARPA Internet class */
#define DWILD		255	/* wildcard for several classifications */

/*
 *  a resource record is made up of a compressed domain name followed by
 *  this structure.  All of these ints need to be byteswapped before use.
 */
struct rrpart {
    word   	rtype,		/* resource record type = DTYPEA */
		rclass;		/* RR class = DIN */
    longword	ttl;		/* time-to-live, changed to 32 bits */
    word	rdlength;	/* length of next field */
    byte 	rdata[DOMSIZE];	/* data field */
};

static int packdom(byte *, byte *);
static int unpackdom(byte *, byte *, byte *);
static word sendom(byte *, longword, word);
static longword Sdomain(byte *, int, longword, byte *);
static int countpaths(byte *);
static int ddextract(struct useek *, longword *);
static byte * getpath(byte *, int);
static byte * nextdomain(byte *, int);
static int isaddr(byte *);

/*
 *  data for domain name lookup
 */
static struct useek {
    struct	dhead h;
    byte	x[DOMSIZE];
} *question;

static void
qinit() {
    question->h.flags = htons(DRD);
    question->h.qdcount = htons(1);
    question->h.ancount = 0;
    question->h.nscount = 0;
    question->h.arcount = 0;
}

int 
add_server(int *counter, int max, longword *array, longword value)
{
	if (array == NULL) return (0);			/* failure */
	if (value && (*counter < max))
		array[ (*counter)++ ] = value;
	return (1);
}

/*********************************************************************/
/*  packdom
 *   pack a regular text string into a packed domain name, suitable
 *   for the name server.
 *
 *   returns length
*/
static int
packdom(byte *dst, byte *src)
{
    register byte *p, *q;
    byte *savedst;
    int i, dotflag, defflag;

    if (dst == NULL || src == NULL) return (0);		/* failure */
    dotflag = defflag = 0;
    p = src;
    savedst = dst;

    do {			/* copy whole string */
	*dst = 0;
	q = dst + 1;
	while (*p && (*p != '.'))
	    *q++ = *p++;

	i = p - src;
	if (i > 0x3f)			/* if string is too long */
	    return (-1);
	*dst = (byte)i;			/* leading length byte */
	*q = 0;

	if (*p) {			/* if a next field */
	    dotflag = 1;		/* say dot seen in string */
	    src = ++p;
	    dst = q;
	}
	else if ((dotflag == 0) && (defflag == 0) && (def_domain != NULL)) {
	    p = def_domain;		/* continue packing with default */
	    defflag = 1;		/* say using default domain ext */
	    src = p;
	    dst = q;
	}
    }
    while (*p);
    q++;
    return (q - savedst);		/* length of packed string */
}

/*********************************************************************/
/*  unpackdom
 *  Unpack a compressed domain name that we have received from another
 *  host.  Handles pointers to continuation domain names -- buf is used
 *  as the base for the offset of any pointer which is present.
 *  returns the number of bytes at src which should be skipped over.
 *  Includes the NULL terminator in its length count.
 */
static int
unpackdom(byte *dst, byte *src, byte *buf)
{
    register word i, j;
    int retval;
    byte *savesrc;

    if (src == NULL || dst == NULL || buf == NULL)
    	return (-1);	/* failure */
    savesrc = src;
    retval = 0;

    while (*src) {
	j = *src & 0xff;			/* length byte */
	while ((j & 0xC0) == 0xC0) { 		/* while 14-bit pointer */
	    if (retval == 0)
		retval = src - savesrc + 2;
	    src++;
	    src = &buf[(j & 0x3f)*256+(*src & 0xff)]; /* 14-bit pointer deref */
	    j = *src & 0xff;			/* new length byte */
	}

	src++;					/* assumes 6-bit count */
	for (i = 0; i < (j & 0x3f); i++)
	    *dst++ = *src++;			/* copy counted string */
	*dst++ = '.';				/* append a dot */
    }
    *(--dst) = 0;			/* add terminator */
    src++;				/* account for terminator on src */

    if (retval == 0)
	retval = src - savesrc;
    return (retval);
}

/*********************************************************************/
/*  sendom
 *   put together a domain lookup packet and send it
 *   uses UDP port 53
 *	num is used as identifier
 */
static word
sendom(byte *s, longword towho, word num)
{
    word i, ulen;
    register byte *psave;
    register byte *p;

    psave = question->x;
    i = packdom(question->x, s);	/* i = length of packed string */

    p = &(question->x[i]);
    *p++ = 0;				/* high byte of qtype */
    *p++ = DTYPEA;		/* number is < 256, so we know high byte=0 */
    *p++ = 0;				/* high byte of qclass */
    *p++ = DIN;				/* qtype is < 256 */

    question->h.ident = htons(num);
    ulen = sizeof(struct dhead) + (p - psave);

    if (dom_sock->sisopen != SOCKET_OPEN)
    	if (udp_open(dom_sock, 0, towho, DNS_PORT) == 0)	/* failure */
    		return (0); 					/* fail*/

    if ((word)sock_write((sock_type *)dom_sock, (byte *)question, ulen) != ulen)
    	return (0);						/* fail */

    return (ulen);
}

static int 
countpaths(byte * pathstring)
{
    register int count = 0;
    register byte *p;

    for (p = pathstring; (*p != 0) || (*(p+1) != 0); p++)
	if (*p == '.')
	    count++;

    return (++count);
}

static byte *
getpath(byte * pathstring, int whichone)
/* pathstring	the path list to search */
/* whichone	which path to get, starts at 1 */
{
	register byte *retval;

	if (pathstring == NULL) return (NULL);	/* failure */

	if (whichone > countpaths(pathstring))
		return (NULL);
	whichone--;
	for (retval = pathstring; whichone > 0; retval++)
		if (*retval == '.')
			whichone--;
	return (retval);
}

/*********************************************************************/
/*  ddextract
 *   Extract the ip number from a response message.
 *   Returns the appropriate status code and if the ip number is available,
 *   and copies it into mip.
 */
static int
ddextract(struct useek *qp, longword *mip)
{
	register int i;
	int nans, rcode;
	struct rrpart *rrp;
	byte *p;
	byte space[260];

	if (qp == NULL || mip == NULL) return (0);	/* failure */
	memset(space, 0, sizeof(space));
	nans = ntohs(qp->h.ancount);		/* number of answers */
	rcode = DRCODE & ntohs(qp->h.flags);	/* return code for message*/
	if (rcode != 0)
		return (rcode);

	if (nans == 0 || (ntohs(qp->h.flags) & DQR) == 0)
		return (-1); 		/* if no answer or no response flag */

	p = qp->x;				/* where question starts */
	if ((i = unpackdom(space, p, (byte *)qp)) == -1)
						/* unpack question name */
		return (-1);			/* failure to unpack */

	/*  spec defines name then  QTYPE + QCLASS = 4 bytes */
	p += i + 4;
/*
 *  At this point, there may be several answers.  We will take the first
 *  one which has an IP number.  There may be other types of answers that
 *  we want to support later.
 */
	while (nans-- > 0) {			/* look at each answer */
	    if ((i = unpackdom(space, p, (byte *)qp)) == -1)
	    		/* answer name to unpack */
	    	return (-1);			/* failure to unpack */

	    p += i;				/* account for string */
	    rrp = (struct rrpart *)p;		/* resource record here */
	    if (*p == 0 && *(p+1) == DTYPEA && 	/* correct type and class */
	    *(p+2) == 0 && *(p+3) == DIN) {


   //		bcopy(&rrp->rdata, mip, 4);	/* save binary IP # */
	      /* This is failing to compiile under BCC. */
	      /* Try splitting it up into two separate lines */
	      byte *rdata=rrp->rdata;
	      bcopy(&rdata, mip, 4);	/* save binary IP # */

	      return (0);			/* successful return */
	    }
	    p += 10 + ntohs(rrp->rdlength);	/* length of rest of RR */
	}
	return (-1);				/* generic failed to parse */
}

/*********************************************************************/
/*  getdomain
 *   Look at the results to see if our DOMAIN request is ready.
 *   It may be a timeout, which requires another query.
 */

static longword 
udpdom() {
	register int i, uret;
	longword desired;

	uret = sock_fastread((sock_type *)dom_sock, (byte *)question, sizeof(struct useek));

	if (uret == 0) return (0L);		/* fastread failed to read */

	/* check if the necessary information was in the UDP response */
	i = ddextract(question, &desired);
	switch (i)
		{
        	case 0: return (ntohl(desired)); /* we found the IP number */
        	case 3:				/* name does not exist */
        	case -1:		/* strange ret code from ddextract */
        	default: return (0);		/* dunno */
		}
}


/**************************************************************************/
/*  Sdomain
 *   DOMAIN based name lookup
 *   query a domain name server to get an IP number
 *	Returns the machine number of the machine record for future reference.
 *   Events generated will have this number tagged with them.
 *   Returns various negative numbers on error conditions.
 *
 *   if adddom is nonzero, add default domain
 */
static longword
Sdomain(byte *mname, int adddom, longword nameserver, byte *timedout)
/* *timedout	set to 1 on timeout */
{
#define NAMBUFSIZ 256
    byte namebuff[NAMBUFSIZ];
    int namlen;
    register int i;
    register byte *p;
    byte *nextdomain(byte *, int);
    longword response, timeout;

	response = 0;
	*timedout = 1;			/* presume a timeout */

	if (nameserver == 0L)
		{			/* no nameserver, give up now */
		outs("\r\n No nameserver defined!");
		return (0);
		}

	while (*mname == ' ' || *mname == '\t') mname++;
    					/* kill leading spaces */
	if (*mname == '\0')		/* no host name, fail */
		return (0L);

	qinit();			/* initialize some flag fields */

	namlen = strlen(mname);		/* Get length of name */
	if (namlen >= NAMBUFSIZ || namlen == 0)	/* Check it before copying */
		return (0L);

	strcpy(namebuff, mname);			/* OK to copy */
	if(namebuff[strlen(namebuff) - 1] == '.')
		namebuff[strlen(namebuff) - 1] = '\0';

	if (adddom > 0 && adddom <= countpaths(def_domain))
		{ 				/* there is a search list */
		p = getpath(def_domain, adddom); /* get end of def_domain */
		if (p != NULL)			/* if got something */
			{
			if (strlen(p) > (NAMBUFSIZ - namlen - 1))
				return (0L);		/* if too big */
			if (*p != '.')			/* one dot please */
				strcat(namebuff, ".");
			strcat(namebuff, p);	/* new name to try */
			}
	    	}

	outs("\r\n  trying name "); outs(namebuff); /* hand holder */

	/*
 	* This is not terribly good, but it attempts to use a binary
 	* exponentially increasing delays.
 	*/
	for (i = 2; i < 17; i *= 2)
		{
		if (sendom(namebuff, nameserver, 0xf001) == 0)	/* try UDP */
			goto sock_err;			/* sendom() failed */

		timeout = set_timeout(i);
		do
			{
			if (icmp_unreach != 0)		/* unreachable? */
			 	goto sock_err;
			if (tcp_tick((sock_type *)dom_sock) == 0) 	/* read packets */
				goto sock_err;		/* socket is closed */
			if (chk_timeout(timeout) == TIMED_OUT)
				break;			/* timeout */
			if (sock_dataready((sock_type *)dom_sock))	/* have response */
				*timedout = 0;		/* say no timeout */
			if (chkcon() != 0)		/* Control-Break */
				goto sock_err;		/* bail out */
			} while (*timedout);

		if (*timedout == 0) break;	/* got an answer */
		}

	if (*timedout == 0)			/* if answer, else fall thru*/
		{
		response = udpdom();		/* process the received data*/
		sock_close((sock_type *)dom_sock);
		return (response);
		}

sock_err:
	outs("\r\n  Cannot reach name server ");
	ntoa(namebuff, nameserver);	/* nameserver IP to dotted decimal */
	outs(namebuff);			/* display nameserver's IP */
	*timedout = 1;			/* say timeout */
	sock_close((sock_type *)dom_sock);
	while (chkcon()) ;		/* consume extra ^Cs */
	return (0);
}

/*
 * nextdomain - given domain and count = 0,1,2,..., return next larger
 *		domain or NULL when no more are available
 */
static byte *
nextdomain(byte *domain, int count)
{
	register byte *p;
	register int i;

	if ((p = domain) == NULL) return (NULL);	/* failure */
	if (count < 0) return (NULL);

	for (i = 0; i < count; i++)
		{
		p = strchr(p, '.');
		if (p == NULL) return (NULL);
		p++;
		}
	return (p);
}

static longword
resolve2(byte *name)
{			/* detailed worker for resolve() */
	longword ip_address;
	register int count;
	register int i;
	byte timeout;
	struct useek qp;			/* temp buffer */
	udp_Socket ds;          		/* working socket (big!) */

	question = &qp;
	memset(&qp, 0, sizeof(struct useek));
	dom_sock = &ds;
	memset(&ds, 0, sizeof(udp_Socket));

	chkcon();			/* clear Control-Break flag */

	for (i = 0; i < last_nameserver; i++)	/* for each nameserver */
		{
		icmp_unreach = 0;	/* clear ICMP unreachable msg */
		count = 0;		/* number domain extensions to add */
		do			/* try name then name.extensions */
			{
			if (ip_address = Sdomain(name, count,
				def_nameservers[i], &timeout))
					return (ip_address);
			if (chkcon() != 0)		/* Control-Break */
				break;			/* quit */
			if (timeout != 0)		/* no nameserver */
				break; 			/* exit do-while */
			} 
		while (nextdomain(def_domain, count++) != NULL); /* are ext */
		}
	while (chkcon()) ;		/* soak up ^C's */
	return (0L);			/* return failure, IP of 0L */
}


/*
 * resolve()
 * 	convert domain name -> address resolution.
 * 	returns 0 if name is unresolvable right now
 */

longword 
resolve(byte *name)
{
	if (name == NULL) return (0L);

	if (isaddr(name) != 0)
		return (aton(name));	/* IP numerical address */
	return (resolve2(name));	/* call upon the worker */
}

/*
 * aton()
 *	- converts [a.b.c.d] or a.b.c.d to 32 bit long
 *	- returns 0 on error (safer than -1)
 */

longword 
aton(byte *text)
{
	register int i;
	longword ip, j;

	ip = 0;
	if (text == NULL) return (0L);		/* failure */

	if (*text == '[')
		text++;
	for (i = 24; i >= 0; i -= 8)
		{
		j = atoi(text) & 0xff;
		ip |= (j << i);
		while (*text != '\0' && *text != '.') text++;
		if (*text == '\0')
			break;
		text++;
		}
	return (ip);
}

/*
 * isaddr
 *	- returns nonzero if text is simply ip address
 * such as 123.456.789.012 or [same] or 123 456 789 012 or [same]
 */
int 
isaddr(byte *text)
{
	register byte ch;

	if (text == NULL) return (0);		/* failure */
	while (ch = *text++)
		{
		if (('0' <= ch) && (ch <= '9'))
			continue;	/* in digits */
		if ((ch == '.') || (ch == ' ') || (ch == '[') || (ch == ']'))
		    	continue;			/* and in punct */
		return (0);				/* failure */
		}
	return (1);
}

