/* File MSNTND.C
 * Telnet driver
 *
 *	Copyright (C) 1982, 1999, Trustees of Columbia University in the 
 *	City of New York.  The MS-DOS Kermit software may not be, in whole 
 *	or in part, licensed or sold for profit as a software product itself,
 *	nor may it be included in or distributed with commercial products
 *	or otherwise distributed by commercial concerns to their clients 
 *	or customers without written permission of the Office of Kermit 
 *	Development and Distribution, Columbia University.  This copyright 
 *	notice must not be removed, altered, or obscured.
 *
 * Written for MS-DOS Kermit by Joe R. Doupnik, 
 *  Utah State University, jrd@cc.usu.edu, jrd@usu.Bitnet,
 *  and by Frank da Cruz, Columbia Univ., fdc@watsun.cc.columbia.edu.
 * With earlier contributions by Erick Engelke of the University of
 *  Waterloo, Waterloo, Ontario, Canada.
 *
 * Last edit
 * 12 Jan 1995 v3.14
 */
#include "tcp.h"
#include "netlibc.h"

#define	MAXSESSIONS 6
#define MSGBUFLEN 1024

/* TCP/IP Telnet negotiation support code */
#define IAC     255
#define DONT    254
#define DO      253
#define WONT    252
#define WILL    251
#define SB      250
#define AYT	246
#define BREAK   243
#define SE      240
#define EOR	239

#define	TELOPT_BINARY	0
#define TELOPT_ECHO     1
#define TELOPT_SGA      3
#define TELOPT_STATUS   5
#define TELOPT_TTYPE    24
#define TELOPT_EOR	25
#define TELOPT_NAWS	31

#define BIN_REJECT	0	/* Binary mode, decline option */
#define BIN_REQUEST	1	/* Binary mode, option has been requested */
#define BIN_RESPONSE	2	/* Binary mode, option has been answered */

#define BAPICON		0xa0	/* 3Com BAPI, connect to port */
#define BAPIDISC	0xa1	/* 3Com BAPI, disconnect */
#define BAPIWRITE	0xa4	/* 3Com BAPI, write block */
#define BAPIREAD	0xa5	/* 3Com BAPI, read block */
#define BAPIBRK		0xa6	/* 3Com BAPI, send short break */
#define BAPISTAT	0xa7	/* 3Com BAPI, read status (# chars avail) */
#define BAPIHERE	0xaf	/* 3Com BAPI, presence check */
#define BAPIEECM	0xb0	/* 3Com BAPI, enable/disable ECM char */
#define BAPIECM		0xb1	/* 3Com BAPI, trap Enter Command Mode char */
#define BAPIPING	0xb2	/* Send Ping, Kermit extension of BAPI */
#define BAPITO_3270	0xb3	/* Write to 3270, Kermit extension of BAPI */
#define BAPINAWS	0xb4	/* Send NAWS update, Kermit extension */

#define BAPISTAT_SUC	0	/* function successful */
#define BAPISTAT_NCW	1	/* no character written */
#define BAPISTAT_NCR	2	/* no character read */
#define BAPISTAT_NSS	3	/* no such session */
#define BAPISTAT_NOS	7	/* session aborted */
#define BAPISTAT_NSF	9	/* no such function */

#define	SUCCESS		0	/* tcp_status for main body of Kermit */
#define NO_DRIVER	1
#define NO_LOCAL_ADDRESS 2
#define BOOTP_FAILED	3
#define RARP_FAILED	4
#define BAD_SUBNET_MASK 5
#define SESSIONS_EXCEEDED 6
#define HOST_UNKNOWN	7
#define HOST_UNREACHABLE 8
#define CONNECTION_REJECTED 9

#define TSBUFSIZ 41
static byte sb[TSBUFSIZ];	/* Buffer for subnegotiations */

static byte *termtype;		/* Telnet, used in negotiations */
/*static int sgaflg = 0;		/* Telnet SGA flag */


int sgaflg = 0;			/* Telnet SGA flag */
static int dosga  = 0;		/* Telnet 1 if I sent DO SGA from tn_ini() */
static int wttflg = 0;		/* Telnet Will Termtype flag */
static int doEOR = 0;		/* Telnet EOR done if not zero */
byte echo = 1;			/* Telnet echo, default on, but hate it */
byte bootmethod = BOOT_FIXED;	/* Boot method (fixed, bootp, rarp) */

struct	{
	word ident;
	char *name;
	} termarray[]=		/* terminal type names, from symboldefs.h */
		{
		{0,"UNKNOWN"}, {1,"H-19"}, {2,"VT52"}, {4,"VT100"},
		{8,"VT102"}, {0x10,"VT220"}, {0x20,"VT320"}, {0x40,"TEK4014"},
		{0x80,"VIP7809"}, {0x100, "PT200"}, {0x200, "D463"},
		{0x400, "D470"}, {0x800, "wyse50"},
		{0x2000, "ANSI"}, {0xff,"UNKNOWN"}
		};

extern  byte FAR * bapiadr;	/* Far address of local Telnet client's buf */
extern	int bapireq, bapiret;	/* count of chars in/out */
extern	longword my_ip_addr, sin_mask; /* binary of our IP, netmask */
extern	longword ipbcast;	/* binary IP of broadcast */
extern	byte * def_domain;	/* default domain string */
extern	byte * hostname;	/* our name from BootP server */
static	longword host;		/* binary IP of host */
byte	tempip[18] = {0};	/* for IP string from NET.CFG, count, string*/
byte	dobinary = 0;		/* local NVT-ASCII (0) or Binary (1) mode */
byte	inbinary = 0;		/* incoming Binary, Option status */
byte	outbinary = 0;		/* outgoing Binary, Option status */
byte	do_greeting;		/* non-zero to show Telnet server herald */
int	doslevel = 1;		/* operating at DOS level if != 0 */
static	tcp_Socket *s;		/* ptr to active socket */
int	msgcnt = 0;		/* count of chars in message buffer */
byte	msgbuf[MSGBUFLEN+1] = {0}; /* message buffer for client */

extern	int hookvect(void);
extern	int unhookvect(void);
extern	void kecho(byte);
extern	void kmode(byte);
extern	void readback(void);
extern	void get_kscreen(void);

int	session_close(int);
int	session_rotate(int);
void	session_cleanout(void);
int	tn_ini(void);
int	ttinc(void);
int	tn_doop(word);
int	send_iac(byte, int);
int	tn_sttyp(void);
int	tn_snaws(void);
int	subnegotiate(void);
void	optdebug(byte, int);
void	server_hello(tcp_Socket *);

extern byte kmyip[];			/* our IP number */
extern byte knetmask[];			/* our netmask */
extern byte kdomain[];			/* our domain */
extern byte kgateway[];			/* our gateway */
extern byte kns1[];			/* our nameserver #1 */
extern byte kns2[];			/* our nameserver #2 */
extern byte kbcast[];			/* broadcast address pattern */
extern byte khost[];			/* remote host name/IP # */
extern word kport;			/* remote host TCP port */
extern word kserver;			/* if Kermit is in server mode */
extern byte ktttype[];			/* user term type override string */
extern byte kterm;			/* terminal type index, from symboldefs.h*/
extern byte kterm_lines;		/* terminal screen height */
extern word kterm_cols;			/* terminal screen width */
extern byte kbtpserver[];		/* IP of Bootp host answering query */
extern byte kdebug;			/* non-zero if debug mode is active */
extern byte ktnmode;			/* 0=NVT-ASCII, 1=BINARY */
extern word tcp_status;			/* report errors and > 0 */

static struct sessioninfo
	{
	tcp_Socket socketdata;		/* current socket storage area */
	int sessionid;			/* identifying session */
	int tn_inited;			/* Telnet Options inited */
	byte echo;			/* local echo state (0=remote) */
	byte dobinary;			/* mode NVT-ASCII (0) or Binary (1) */
	byte server_mode;		/* if Telnet server */
	byte nawsflg;			/* NAWS flag (1=offered, 2=wanted) */
	} session[MAXSESSIONS];

static int num_sessions = 0;		/* qty of active sessions */
static int active = -1;			/* ident of active session */
	
/* this runs at Kermit task level */
int
tnmain(void)					/* start TCP from Kermit */
{
	int status = 0;
	register byte *p;
	register int i;

	doslevel = 1;			/* at DOS level i/o */
	tcp_status = SUCCESS;		/* assume all this works */

	if (num_sessions == 0)		/* then initialize the system */
	{
	my_ip_addr = 0L;
	def_domain = kdomain;		/* define our domain */
	host = 0L;		/* BELONGS IN SESSION, but is global */
	msgcnt = 0;

	for (i = 0; i < MAXSESSIONS; i++)	/* init sessioninfo array */
		{
		session[i].sessionid = -1;
		session[i].socketdata.sisopen = SOCKET_CLOSED;
		}

	if (hookvect() == 0)
		{
		outs("\r\n Hooking vectors failed");
		tcp_status = NO_DRIVER;
		goto anyerr;
		}
	
	s = NULL;			/* no TCP socket yet */
	if (tcp_init() == 0)		/* init TCP code */
		{
		outs("\r\n Unable to initialize TCP/IP system, quitting");
		tcp_status = NO_DRIVER;
		goto anyerr;
		}

	if (tempip[1] != '\0' && stricmp(kmyip, "Telebit-PPP") == 0)
		strcpy(kmyip, &tempip[1]);	/* our IP from NET.CFG */

	if (kdebug)		/* can debug to file */
		doslevel = 0;	/* say not at DOS level, to buffer msgs */

		/* set Ethernet broadcast to all 1's or all 0's */
	ipbcast = resolve(kbcast);	/* IP broadcast address */
	bootphost = ipbcast;		/* set Bootp to this IP too */

	if ((p = strchr(kmyip, ' ')) != NULL)	/* have a space */
		*p = '\0';			/* terminate on the space */

	if (kmyip == NULL)
		{
		outs("\r\n No TCP/IP address specified for this station.");
		tcp_status = NO_LOCAL_ADDRESS;
		goto anyerr;
		}

	if (stricmp(kmyip, "bootp") == 0) bootmethod = BOOT_BOOTP;
	if (stricmp(kmyip, "DHCP") == 0) bootmethod = BOOT_DHCP;
	if (bootmethod == BOOT_BOOTP || bootmethod == BOOT_DHCP)
		{
		if (do_bootp() != 0)
			{
			outs("\r\n Bootp/DHCP query failed. Quitting.");
			tcp_status = BOOTP_FAILED;
			goto anyerr;
			}

		ntoa(kmyip, my_ip_addr);
		if (sin_mask != 0L)
			ntoa(knetmask, sin_mask);
		if (arp_rpt_gateway(0) != 0L)
			ntoa(kgateway, arp_rpt_gateway(0));
		if (last_nameserver > 0) 
			ntoa(kns1, def_nameservers[0]);
		if (last_nameserver > 1)
			ntoa(kns2, def_nameservers[1]);
		if (kdomain[0] == '\0' && hostname[0] != '\0')
						/* construct domain */
			if (p = strchr(hostname, '.')) /* find dot */
				strcpy(kdomain, &p[1]);
		}

	if (stricmp(kmyip, "rarp") == 0 || bootmethod == BOOT_RARP)
		{
		if (pkt_rarp_init() == 0)
			{
			tcp_status = NO_DRIVER;
			goto anyerr;	/* no RARP handle */
			}

		if (do_rarp() == 0) 	/* use RARP */
			{
			outs("\r\n RARP query failed.");
			tcp_status = RARP_FAILED;
			goto anyerr;
			}
		ntoa(kmyip, my_ip_addr);
		bootmethod = BOOT_RARP;
		}

	if ((my_ip_addr = resolve(kmyip)) == 0L)
    		{			/* something drastically wrong */
		outs("\r\n Cannot understand my IP address, terminating");
		tcp_status = NO_LOCAL_ADDRESS;
		goto anyerr;
		}
	ntoa(kmyip, my_ip_addr);	/* binary to dotted decimal */
	readback();

	if ((sin_mask = resolve(knetmask)) == 0L)
	    	{			/* something drastically wrong */
		outs("\r\n Bad network submask, terminating");
		tcp_status = BAD_SUBNET_MASK;
		goto anyerr;
		}

	if (stricmp(kns1, "unknown"))
		add_server(&last_nameserver, MAX_NAMESERVERS, def_nameservers,
			resolve(kns1));
	if (stricmp(kns2, "unknown"))
		add_server(&last_nameserver, MAX_NAMESERVERS, def_nameservers,
		resolve(kns2));

	if (stricmp(kgateway, "unknown"))
		arp_add_gateway(kgateway, 0L);

	}	/* end of initial system setup */


/* starting a new session */
	session_cleanout();		/* clean out deceased sessions */
	msgcnt = 0;

	if (num_sessions >= MAXSESSIONS)
		{
		tcp_status = SESSIONS_EXCEEDED;
		outs("\nAll sessions are in use. Sorry\n");
		return (-1);		/* say can't do another, fail */
		}

	status = -1;
	for (i = 0; i < MAXSESSIONS; i++)	/* find free ident */
		if (session[i].sessionid < 0 && 
				session[i].socketdata.sisopen == SOCKET_CLOSED)
			{
			s = &session[i].socketdata;	/* active socket */
			s->sisopen = SOCKET_CLOSED;
			session[i].sessionid = i;	/* ident */
			status = i;
			active = i;		/* identify active session */
			session[i].echo = echo = 1;/* Telnet echo from mainpgm */
			 			/* mode, assume NVT-ASCII */
			session[i].dobinary = dobinary = 0;
			session[i].tn_inited = 0; /* do Telnet Options init */
			session[i].server_mode = 0; /* assume not server */
			num_sessions++;	/* say have another active session */
			break;
			}

	if (status == -1)
		{
		tcp_status = SESSIONS_EXCEEDED;
		goto sock_err;		/* report bad news and exit */
		}
	status = 0;

	if (ktttype[0] != '\0')		/* if user override given */
		termtype = ktttype;
	else				/* get termtype from real use */
		{
		for (i = 0; termarray[i].ident != 0xff; i++)
    			if (termarray[i].ident == kterm)	/* match */
				break;
		termtype = termarray[i].name;
		}

	/* kserver is set by main body SERVER command. If khost[0] is '*'
	then also behave as a server/listener for any main body mode. */

	if ((khost[0] == '*') || (kserver != 0))
		{
		if (khost[0] == '*')
			host = 0L;		/* force no host IP */
		else
			{
			outs("\r\n Resolving address of host ");
			outs(khost); outs(" ...");
			if ((host = resolve(khost)) == 0)
				{
				outs( "\r\n Cannot resolve address of host ");
				outs(khost);
				tcp_status = HOST_UNKNOWN;
				goto anyerr;
				}
			}
		session[active].server_mode = 1;  /* say being a server */
		tcp_listen(s, kport, host, 0, 0); /* post a listen */
		}
	else					/* normal client mode */
		{
		session[active].server_mode = 0;  /* say being a client */
		outs("\r\n Resolving address of host ");
		outs(khost); outs(" ...");
		if ((host = resolve(khost)) == 0)
			{
			outs( "\r\n Cannot resolve address of host ");
			outs(khost);
			tcp_status = HOST_UNKNOWN;
			goto anyerr;
			}
		outs("\r\n");		/* get clean screen line */
		}

	if ((host == my_ip_addr) || ((host & 0x7f000000L) == 0x7f000000L))
		{
		outs("\r\n Cannot talk to myself, sorry.");
		tcp_status = HOST_UNREACHABLE;
		goto anyerr;
		}
	do_greeting = FALSE;		/* Telnet server greeting msg */

	if (session[active].server_mode != 0) /* if server */
		{
		doslevel = 0;			/* end of DOS level i/o */
		if (kserver == 0)
			outs("\r\n Operating as a Telnet server. Waiting...");
		do_greeting = TRUE;
		}
	else					/* we are a client */
		{
		if (tcp_open(s, 0, host, kport) == 0)
			{
			outs("\r\n Unable to contact the host.");
			outs("\r\n The host may be down or");
			outs(" a gateway may be needed.");
			tcp_status = HOST_UNREACHABLE;
			goto anyerr;
			}
		sock_wait_established((sock_type *)s, 30, NULL, &status);
		}

	doslevel = 0;			/* end of DOS level i/o */
	return (active); 		/* return handle of this session */


sock_err:
	switch (status)
		{
		case 1 : outs("\r\n Session is closed");
			break;
		case -1:/* outs("\r\n Cannot start a connection");*/
			break;
		}

anyerr:	session_close(active);
	if (num_sessions <= 0)
		{
		tcp_shutdown();
		eth_release();			/* do absolutely */
		unhookvect();
		msgcnt = 0;			/* clear message buffer */
		doslevel = 1;			/* at DOS level i/o */
		}
	return (-1);				/* say have stopped */
}

/* this runs at Kermit task level */
int
tnexit(int value)			/* stop TCP from Kermit */
{
	register int i;

	for (i = 0; i < MAXSESSIONS; i++)
		session_close(i);	/* close session, free buffers */
	num_sessions = 0;
	tcp_shutdown();			/* force the issue if necessary */
	eth_release();			/* do absolutely */
	unhookvect();
	msgcnt = 0;			/* clear message buffer */
	return (-1);
}

/* return the int of the next available session after session "ident", or
   return -1 if none. Do not actually change sessions. 
*/
int
session_rotate(int ident)
{	
	register int i, j;
	
	session_cleanout();		/* clean out deceased sessions */
	if (ident == -1) ident = 0;

	for (i = 1; i <= MAXSESSIONS; i++)
		{
		j = (i + ident) % MAXSESSIONS;	/* modulo maxsessions */
		if (session[j].sessionid != -1) 	/* if active */
			return (j);
		}
	return (-1);
}

/* Change to session ident "ident" and active to "ident", return "active"
   if that session is valid, else  return -1.
*/
int
session_change(int ident)
{					/* change active session to ident */
	if (ident == -1 || ident >= MAXSESSIONS)
		return (-1);

	if (session[ident].sessionid == -1)
		return (-1);			/* inactive session */

	s = &session[ident].socketdata;		/* watch mid-stream stuff */
	kecho(echo = session[ident].echo);	/* update Kermit main body */
	kmode(dobinary = session[ident].dobinary); /* mode */
	return (active = ident);		/* ident of active session */
}

/* Close session "ident". Return ident of next available session, if any,
   without actually changing sessions. Returns -1 if no more sessions or
   if ident is out of legal range or if the session is already closed.
*/
int
session_close(int ident)	/* close a particular, ident, session */
{
	register tcp_Socket *s;

	if (ident != -1 && ident < MAXSESSIONS &&
		session[ident].sessionid != -1)		/* graceful close */
		{
		s = &session[ident].socketdata;
		s->rdatalen = 0;		/* flush read buffer */
		sock_close((sock_type *)s);
		}
	session_cleanout();	/* clean out deceased sessions */
				/* activate, rtn next available session */
	return (session_change(session_rotate(ident)));
}

/* Adjust num_sessions to reflect deceased sessions.
   Memory freeing is done here to ensure we are not within DOS.
*/
void
session_cleanout(void)
{
	register int i;
	register tcp_Socket *s;

	for (i = 0; i < MAXSESSIONS; i++)	/* clean out old sessions */
		if ((session[i].sessionid != -1) &&
			(session[i].socketdata.sisopen == SOCKET_CLOSED))
			{
			num_sessions--;		/* qty active sessions */
			session[i].sessionid = -1; /* user level closed */
			s = &session[i].socketdata;
			if (s->sdata != NULL)
				{
				free(s->sdata);		/* free send buffer */
				s->sdata = NULL;	/* clear pointer */
				s->sdatalen = 0;
				}
			if (s->rdata != NULL)
				{
				free(s->rdata);		/* free recv buffer */
				s->rdata = NULL;	/* clear pointer */
				s->rdatalen = 0;
				}
			}
}

/* This is called by the main body of Kermit to transfer data. It returns
   the transfer status as a BAPI valued int. */

int
serial_handler(word cmd)
{
	int cmdstatus;
	register int i, ch;
	extern int session_change(int);

	if (session[active].tn_inited == 0)	/* if not initialized yet */
		if (tn_ini() == -1)	/* init Telnet negotiations */
			return (BAPISTAT_NOS);	/* fatal error, quit */

	tcp_tick((sock_type *)s);       /* catch up on packet reading */

	cmdstatus = BAPISTAT_SUC;	/* success so far */

	if (do_greeting == TRUE && session[active].server_mode && 
		s->state == tcp_StateESTAB)
		{
		do_greeting = FALSE;
		server_hello(s);	/* send greeting message */
		}

	switch (cmd)			/* cmd is function code */
		{
		case BAPIWRITE:		/* write a block, bapireq chars */
			if (session[active].server_mode != 0 
					&& s->state != tcp_StateESTAB)
				{
				bapiret = bapireq; /* discard output and */
				break;	/* send nothing until client appears*/
				}
			if (s->state == tcp_StateESTAB)
				{
				bapiret = sock_write((sock_type *)s, bapiadr, bapireq);

				if (bapiret == -1)	 /* no session */
					cmdstatus = BAPISTAT_NOS;
				}
			else 
				{
				cmdstatus = BAPISTAT_NOS; /* no session */
				bapiret = bapireq;	/* discard data */
				break;
				}

		/* if terminal serving with no local echoing do echo here */
			if (session[active].echo == 0 && 
					session[active].server_mode != 0 && 
						kserver == 0)
				{		 /* echo to us */
				i = bapiret > MSGBUFLEN-msgcnt? 
						MSGBUFLEN-msgcnt: bapiret;
				bcopyff(bapiadr, msgbuf, i);
				outsn(msgbuf, i);
				}
			break;

		case BAPIREAD:		/* read block, count of bapireq */
			bapiret = 0;
			/* i = byte count in buffer preceeding an IAC */
			/* first, shorten search if bapireq < data in buf */
			if (s->rdatalen == 0)
				{
				cmdstatus = BAPISTAT_NCR;/* nothing present */
				break;
				}
			i = (bapireq > s->rdatalen)? s->rdatalen: bapireq;
			i = fstchr(s->rdata, i, IAC);
			if (i < 0)	/* negative -> nothing present */
				{
				cmdstatus = BAPISTAT_NCR;/* nothing present */
				break;
				}

			if (i > 0)  			/* read up to IAC */
				{
				if (i > bapireq)	/* safety check */
					i = bapireq;
 				bapiret = sock_fastread((sock_type *)s, bapiadr, i);

		/* if terminal serving with local echoing then echo to host */
				if (session[active].echo != 0 && 
					session[active].server_mode != 0 &&
						kserver == 0 &&
						s->myport == 23)
					sock_write((sock_type *)s, bapiadr, bapiret);
				break;
				}

		/* i = 0. IAC is at start of buffer, get escaped byte(s) */
		/* Delay until two bytes, or three for Telnet Options */
			if ((s->rdatalen < 2) || (s->rdatalen == 2 && 
				s->rdata[1] >= SB && s->rdata[1] != IAC))
				{
				cmdstatus = BAPISTAT_NCR;/* nothing present */
				break;
				}
	
			if ((ch = ttinc()) == -1)	/* read the IAC */
 					break;		/* no char */
			ch &= 0xff;
			if (ch != IAC)			/* not an IAC */
				{
				*bapiadr = (byte) ch;
				bapiret++;
				break;
				}
			 		 	/* get escaped byte */
			if ((ch = ttinc()) == -1)
				break;		/* none present */
			switch (ch &= 0xff)	/* dispatch on escaped byte */
				{
				case AYT:	/* Are You There */
    					sock_write((sock_type *)s, "Yes\r\n", 5);
					break;
				case IAC:	/* IAC IAC yields just IAC */
					*bapiadr = (byte) ch;
					bapiret++;
					break;
				default:
					if (ch < SB)	/* ignore if not */
						break;	/*  an Option */
					tn_doop(ch);	/* do Options */
					session[active].echo = echo;
					session[active].dobinary = dobinary;
					break;
				}
			break;

		case BAPIBRK:			/* send BREAK */
			{
			byte cmd[2];

			cmd[0] = IAC; cmd[1] = BREAK;
			if (sock_write((sock_type *)s, cmd, 2) == -1)
				cmdstatus = BAPISTAT_NOS; /* no session */
			break;
			}
		case BAPIPING:			/* Ping current host */
			do_ping(khost, host);
			break;

		case BAPINAWS:	/* if want to send screen size update */
			if (session[active].nawsflg == 2) /* if wanted */
				tn_snaws();	/* send NAWS Option */
			break;

		case BAPISTAT:		/* check read status (chars avail) */
			bapiret = sock_dataready((sock_type *)s); /* # chars available */
 			break;

		case BAPIDISC:			/* close this connection */
			session_close(active);
			/* fall through to do session rotate */
		case BAPIECM:
			i = session_rotate(active);	/* get new ident */
			if (i != -1)			/* if exists */
				i = session_change(i);	/* make active */
			bapiret = 0;	/* no chars processed */
			return (i);	/* New session or -1, special */

		default: cmdstatus = BAPISTAT_NSF;/* unsupported function */
			break;
		}

	if ((s->sisopen == SOCKET_CLOSED) && (msgcnt == 0) &&  
		(sock_dataready((sock_type *)s) == 0))	/* no data and no session */
			{
			session_close(active);	/* close deceased */
			return (BAPISTAT_NOS);	/* means exit session */
			}
	else
		return (cmdstatus);		/* stuff is yet unread */
}

/* ttinc   - destructively read char from socket buffer, return -1 if fail */

int 
ttinc(void)
{
	byte ch;
	
	tcp_tick((sock_type *)s);	   /* read another packet */
	if (sock_fastread((sock_type *)s, &ch, 1) != 0)	/* qty chars returned */
		return (0xff & ch);
	return (-1);
}

/* Initialize a telnet connection */
/* Returns -1 on error, 0 is ok */

int 
tn_ini(void)
{
	sgaflg = 0;			/* SGA flag starts out this way */
	wttflg = 0;			/* Did not send WILL TERM TYPE yet. */
	session[active].nawsflg = 0;	/* Did not send NAWS info yet */
	dosga  = 0;			/* Did not send DO SGA yet. */
	dobinary = 0;			/* presume NVT-ASCII result */
	inbinary = outbinary = BIN_REJECT; /* NVT-ASCII mode (reject binary)*/
	doEOR = 0;
	session[active].tn_inited = 1;	/* say we are doing this proc */
	kecho(echo = 1);		/* start with local echoing */
				/* if not server or not Telnet port */
	if (session[active].server_mode != 0 ||	kport != 23)
			return (0);		/* don't go first */
		
	if (send_iac(WILL, TELOPT_TTYPE)) return( -1 );
	wttflg = 1;			/* remember we offered TTYPE */
	if (send_iac(WILL, TELOPT_NAWS)) return(-1);
	session[active].nawsflg = 1;	/* remember we offered NAWS */
	if (send_iac(DO, TELOPT_SGA)) return( -1 );
	dosga = 1;			/* remember we sent DO SGA */
	if (ktnmode != 0)		/* if we want Binary mode */
		{
		outbinary = inbinary = BIN_REQUEST;
		if (send_iac(DO, TELOPT_BINARY)) return (-1);
		if (send_iac(WILL, TELOPT_BINARY)) return (-1);
		}			/* remember said WILL and DO BINARY */
	kmode(dobinary);		/* tell main body current NVT state */
	return(0);
}

/*
 * send_iac - send interupt character and pertanent stuff
 *	    - return 0 on success
 */

int
send_iac(byte cmd, int opt)
{
	byte io_data[3];

	io_data[0] = IAC;
	io_data[1] = cmd;
	io_data[2] = (byte)(opt & 0xff);
	if (sock_write((sock_type *)s, io_data, 3) != 3 )
		return (1);			/* failed to write */
	if (kdebug & DEBUG_STATUS)
		{
		outs("Opt send ");
		optdebug(cmd, opt);
		outs("\r\n");
		}
	return (0);
}

/*
 * Process in-band Telnet negotiation characters from the remote host.
 * Call with the telnet IAC character and the current duplex setting
 * (0 = remote echo, 1 = local echo).
 * Returns:
 *  -1 on success or char 0x255 (IAC) when IAC is the first char read here.
 */

int 
tn_doop(word ch)
{					/* enter after reading IAC char */
    register int c, x;

    	if (ch < SB) return(0);		/* ch is not in range of Options */

	if ((x = ttinc()) == -1)	/* read Option character */
		return (-1);		/* nothing there */
	x &= 0xff;
	c = ch;				/* use register'd character */

	if (kdebug & DEBUG_STATUS)
		{
		outs("Opt recv ");
		optdebug((byte)c, x);
		if ((byte)c != SB) outs("\r\n");
		}

    switch (x) {
      case TELOPT_ECHO:                 /* ECHO negotiation */
	if (c == WILL)			/* Host says it will echo */
		{
		if (echo != 0)		/* reply only if change required */
			{
			send_iac(DO,x);	/* Please do */
			kecho(echo = 0); /* echo is from the other side */
			}
		break;
		}

        if (c == WONT)			/* Host says it won't echo */
		{
		if (echo == 0)			/* If we not echoing now */
			{
			send_iac(DONT,x);	/* agree to no host echo */
			kecho(echo = 1); 	/* do local echoing */
			}
		break;
		}
	if (c == DO)
		{			/* Host wants me to echo to it */
		send_iac(WONT,x);	/* I say I won't */
		break;
        	}
	break;				/* do not respond to DONT */

      case TELOPT_SGA:                  /* Suppress Go-Ahead */
	if (c == WONT)			/* Host says it won't sup go-aheads */
		{
		if (sgaflg == 0)
			send_iac(DONT, x);	/* acknowledge */
		sgaflg = 1;			/* no suppress, remember */
		if (echo == 0)			/* if we're not echoing, */
			kecho(echo = 1);	/* switch to local echo */
		break;
		}

        if (c == WILL)			/* Host says it will sup go aheads */
		{
		if (sgaflg || !dosga)		/* ACK only if necessary */
			{
			sgaflg = 0;		/* supp go-aheads, remember */
			dosga++;		/* remember said DO */
			send_iac(DO,x);		/* this is a change, so ACK */
            		}
		break;
	        }
/*
  Note: The following is proper behavior, and required for talking to the
  Apertus interface to the NOTIS library system, e.g. at Iowa State U:
  scholar.iastate.edu.  Without this reply, the server hangs forever.  This
  code should not be loop-inducing, since Kermit never sends WILL SGA as
  an initial bid, so if DO SGA comes, it is never an ACK.
*/
	if (c == DO || c == DONT)	/* Server wants me to SGA, or not */
		{
		if (send_iac(WILL,x) < 0) /* I have to say WILL SGA, */
			return(-1);	/* even tho I'm not changing state */
		break;			/* or else server might hang. */
		}
	break;

      case TELOPT_TTYPE:                /* Terminal Type */
        switch (c) {
          case DO:                      /* DO terminal type */
	    if (wttflg == 0) {		/* If I haven't said so before, */
		send_iac(WILL, x);	/* say I'll send it if asked */
		wttflg++;
	    }
		break;

          case SB:			/* enter subnegotiations */
	    if (wttflg == 0)
	    	break;			/* we have not been introduced yet */
	    if (subnegotiate() != 0)	/* successful negotiation */
		tn_sttyp();		/* report terminal type */
	    break;
	    	
          default:                      /* ignore other TTYPE Options */
	    	goto refuse;
        }				/* end of inner switch (c) */
	break;

	case TELOPT_NAWS:		/* terminal width and height */
        switch (c) {
          case DO:                      /* DO terminal type */
	    if (session[active].nawsflg == 0) /* If haven't said so before, */
		send_iac(WILL, x);	/* say we will send it if asked */
	    tn_snaws();			/* report screen size */
	    session[active].nawsflg = 2;	/* say NAWS is wanted */
		break;

          default:                      /* ignore other NAWS Options */
	    	goto refuse;
        }				/* end of inner switch (c) */
	break;

	case TELOPT_BINARY:
	switch (c) {
		case DO:		/* what they want to receive from us*/
			if (outbinary & BIN_REQUEST != BIN_REQUEST)
				{		/* if have not sent WILL */ 
				send_iac(WILL, x);	/* we can send bin */
				outbinary |= BIN_REQUEST;
				}
			/* ensure the other direction works the same way */
			if (inbinary & BIN_REQUEST != BIN_REQUEST)
				{		/* if have not sent DO */
				send_iac(DO, x);	/* want you to bin */
				inbinary |= BIN_REQUEST;
				}
			outbinary |= BIN_RESPONSE;	/* they said DO */
			/* if we said WILL then BIN_REQUEST will be on */
			break;
		case WILL:		/* what they want to send to us */
			if (inbinary & BIN_REQUEST != BIN_REQUEST)
				{		/* if we have not said DO */
				send_iac(DO, x);	/* want you to bin */
				inbinary |= BIN_REQUEST;
				}
			/* ensure the other direction works the same way */
			if (outbinary & BIN_REQUEST != BIN_REQUEST)
				{		/* if we have not said WILL */	
				send_iac(WILL, x);	/* we can send bin */
				outbinary |= BIN_REQUEST;
				}
			inbinary |= BIN_RESPONSE;	/* they said WILL */
			/* if we said DO then BIN_REQUEST will be on */
			break;

		case DONT:		/* they will not receive binary */
			if (inbinary & BIN_REQUEST == BIN_REQUEST) {
			send_iac(WONT, x);	/* we won't receive binary */
			inbinary = BIN_REJECT | BIN_RESPONSE;
			}
			break;
		case WONT:		/* they will not send binary */
			if (outbinary & BIN_REQUEST == BIN_REQUEST) {
			send_iac(WONT, x);	/* we will not send binary */
			outbinary = BIN_REJECT | BIN_RESPONSE;
			}
			break;
		}		/* end of Binary switch (c) */
					/* if have both answers */
	if ((inbinary & outbinary & BIN_RESPONSE) == BIN_RESPONSE)
		{
		dobinary = ((inbinary & outbinary & BIN_REQUEST)
				== BIN_REQUEST) ? 1: 0;
		kmode( dobinary );	/* update main body, 1 = binary */
		}
	break;

	case TELOPT_EOR:
	switch (c) {
		case DO:
			if (ktnmode != 0 && doEOR == 0) {
			send_iac(WILL, x);	/* say I will */
			doEOR++;
			break;
			}
			if (ktnmode == 0) {
			send_iac(WONT, x);	/* I won't do EOR to you */
			doEOR = 0;
			}
			break;
		case WILL:
			if (ktnmode != 0 && doEOR == 0) {
			send_iac(DO, x);	/* tell host to do EORs */
			doEOR++;
			break;
			}
			if (ktnmode == 0) {
			send_iac(DONT, x);	/* don't do EORs */
			doEOR = 0;
			}
			break;
		case DONT:
			if (doEOR != 0) {
			send_iac(WONT, x);	/* say we won't */
			doEOR = 0;
			}
			break;
		case WONT:
			if (doEOR != 0) {
			send_iac(DONT, x);	/* say don't do it */
			doEOR = 0;
			}
			break;
		}		/* send of EOR switch (c) */
	break;

      default:				/* all other Options: refuse nicely */
refuse:					/* a useful label */
	switch(c) {
          case WILL:                    /* You will? */
		send_iac(DONT,x);	/* Please don't */
		break;
          case DO:                      /* You want me to? */
		send_iac(WONT,x);	/* I won't */
		break;

          case DONT:
		send_iac(WONT,x);	/* I won't */
		break;

          case WONT:                    /* You won't? */
		break;			/* Good */

	  default:
	  	break;			/* unknown character, discard */
          }				/* end of default switch (c) */
        break;
    }					/* end switch (x) */
    return (-1);			/* say done with Telnet Options */
}

/* Perform Telnet Option subnegotiation. SB byte has been read. Consume
   through IAC SE. Return 1 if successful, else 0.
*/
int
subnegotiate(void)
{
	register word flag, y;
 	word n;

            n = flag = 0;               /* flag for when done reading SB */
            while (n < TSBUFSIZ)
	    	{			/* loop looking for IAC SE */
                if ((y = ttinc()) == -1)
			continue; 	/* nothing there */
		y &= 0xff;              /* make sure it's just 8 bits */
		sb[n++] = (byte) y;	/* save what we got in buffer */

		if (kdebug & DEBUG_STATUS)
			{
			if (y == SE) outs(" se\r\n");
			else
			if (y != IAC)
				{
				if (n == 1 && y == 1)
					outs(" send");
				else
					{
					outs(" \\x"); 
					outhex((byte)y);
					}
				}
			}

		if (y == IAC) 		/* If this is an IAC */
		    {
		    if (flag)		/* If previous char was IAC */
		    	{
			n--;		/* it's quoted, keep one IAC */
			flag = 0;	/* and turn off the flag. */
			}
		    else flag = 1;	/* Otherwise set the flag. */
		    }
		else if (flag)  	/* Something else following IAC */
			{
		    if (y != SE)	/* If not SE, it's a protocol error */
		      flag = 0;
		    break;
                	}		/* end of if (y == IAC) */
		}			/* end while */

	    if (flag == 0 || y == -1)	/* no option IAC SE */
	       return (0);		/* flag == 0 is invalid SB */

	    if ( *sb == 1 )		/* wants us to report option */
		return (1);		/* say can do report */
	    else
	    	return (0);
}

/* Telnet send terminal type */
/* Returns -1 on error, 0 on success */

int 
tn_sttyp(void)
{                            		/* Send telnet terminal type. */
	register byte *ttn;
	register int ttnl;		/* Name & length of terminal type. */

	ttn = termtype;		/* we already have this from environment */
	if ((*ttn == 0) || ((ttnl = strlen(ttn)) >= TSBUFSIZ))
		{
		ttn = "UNKNOWN";
    		ttnl = 7;
		}
	sb[0] = (byte)IAC;
	sb[1] = (byte)SB;
	sb[2] = (byte)TELOPT_TTYPE;
	sb[3] = 0;			/* 'is'... */
	ttn = strcpy(&sb[4], ttn);	/* Copy to subnegotiation buffer */
	ttn = &sb[ttnl + 4];		/* go to end of buffer */
	*ttn++ = (byte)IAC;
	*ttn   = (byte)SE;

	sock_write((sock_type *)s, sb, ttnl + 6);
	if (kdebug & DEBUG_STATUS)
		{
		int i;

		outs("Opt send ");
		optdebug(SB, TELOPT_TTYPE);
		outs(" is "); 
		for (i = 0; i < ttnl; i++) outch(sb[i+4]);
		outs(" se\r\n");
		}
	return (0);
}

/* Send terminal width and height (characters). RFC 1073 */
/* IAC SB NAWS <16-bit value> <16-bit value> IAC SE */
int
tn_snaws(void)
{
	static byte sbuf[9] = {(byte)IAC, (byte)SB, (byte)TELOPT_NAWS,
				0,0, 0,0, (byte)IAC, (byte)SE};

	get_kscreen();				/* get current screen */
	sbuf[4] = kterm_cols;
	sbuf[6] = kterm_lines;
	sock_write((sock_type *)s, sbuf, sizeof(sbuf));
    	if (kdebug & DEBUG_STATUS)
    		{
		outs("Opt send ");
		optdebug(SB, TELOPT_NAWS);
		outs(" \\x"); 
		outhex(sbuf[4]);
		outs(" \\x"); 
		outhex(sbuf[6]);
		outs(" se\r\n");
		}
	return (0);
}

/* assist displaying of Telnet Options negotiation material */
void
optdebug(byte cmd, int option)
{
	switch (cmd)
		{
		case WILL: outs("will ");
				break;
		case WONT: outs("wont ");
				break;
		case DO: outs("do ");
				break;
		case DONT: outs("dont ");
				break;
		case SB: outs("sb ");
				break;
		default: outs("\\x "); outhex(cmd);
				break;
		}			/* end of switch c */
	switch (option)
		{
		case TELOPT_BINARY: outs("binary");
				break;
		case TELOPT_ECHO: outs("echo");
				break;
		case TELOPT_SGA: outs("sga");
				break;
		case TELOPT_TTYPE: outs("ttype");
				break;
		case TELOPT_EOR: outs("eor");
				break;
		case TELOPT_NAWS: outs("naws");
				break;
		default: outs("\\x"); outhex((byte)option);
				break;
		}
}


/* Compose a nice greeting message for incoming Telnet connections. Called
   by tcp_handler() in the tcp_StateLISTEN section. It also notifies the
   local terminal emulator of the client's presence and address. */

void
server_hello(tcp_Socket *s)
{
	char hellomsg[MSGBUFLEN];		/* work buffer, keep short */

	strcpy(hellomsg,
		"\r\n Welcome to the MS-DOS Kermit Telnet server at [");
	ntoa(&hellomsg[strlen(hellomsg)], my_ip_addr);		/* our IP */
	strcat(hellomsg, "].\r\n");		/* as [dotted decimal] */
	if (kserver != 0)			/* if file serving */
		{
		strcat(hellomsg," Escape back to your Kermit prompt and");
		strcat(hellomsg," issue Kermit file server commands.\r\n\n");
		}
	else					/* if terminal emulating */
		{
		strcat(hellomsg,
			" You are talking to the terminal emulator,\r\n");
		strcat(hellomsg, " adjust local echoing accordingly.\r\n");
		}

		
	sock_write((sock_type *)s, hellomsg, strlen(hellomsg));	/* tell remote */
				/* tell main body the news */
	strcpy(hellomsg, "\r\n Connection starting from [");
	ntoa(&hellomsg[strlen(hellomsg)], s->hisaddr);	/* their IP */
	strcat(hellomsg, "].\r\n");
	outs(hellomsg);		/* send connection info to main body */
}

