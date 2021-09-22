/* File MSNTCP.C
 * Main TCP protocol code
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
 * Adapted and redesigned for MS-DOS Kermit by Joe R. Doupnik, 
 *  Utah State University, jrd@cc.usu.edu, jrd@usu.Bitnet.
 *
 * Last edit
 * 12 Jan 1995 v3.14
 * Class edition: 2 Feb 1996
 *
 */

#include "msntcp.h"
#include "msnlib.h"

extern	int arp_handler(in_Header *);
extern	int rarp_handler(void *);
extern	int icmp_handler(void *);
extern	void icmp_noport(void *);
extern	void server_hello(tcp_Socket *s);
extern	void eth_release(void);
extern	void icmp_init(void);
extern	int eth_init(void);
extern	word tcp_status;
extern	void krto(word);
extern	void end_bootp(void);
extern	int DHCP_refresh(void);
extern	int request_busy;	/* msnbtp.c, DHCP request() lock */
extern	int odi_busy(void);

static	int tcp_handler(in_Header *);
static	int tcp_rst(in_Header *, tcp_Header FAR *);
static	int tcp_read(tcp_Socket *, byte FAR *, int);
static	int tcp_write(tcp_Socket *, byte FAR *, int);
static	int tcp_close(tcp_Socket *);
static	int tcp_processdata(tcp_Socket *, tcp_Header FAR *, int);
static	int tcp_send(tcp_Socket *);
static	int tcp_retransmitter(void);
static	int tcp_unthread(tcp_Socket *);
static	int udp_handler(in_Header *);
static	int udp_read(udp_Socket *, byte FAR *, int);
static	int udp_write(udp_Socket *, byte FAR *, int);
static	int udp_close(udp_Socket *);
static	void lost_ack(tcp_Socket *);
static	void new_rto(tcp_Socket *, int);

longword ipbcast = 0xffffffffL;		/* default IP broadcast address */

static	initialized = 0;		/* if have started the stack */
static	imposter = 0;			/* ARP for own IP toggle */
extern	byte kdebug;			/* non-zero if debug mode is active */
extern	word ktcpmss;			/* MSS override */
/*
 * Local IP address
 */
longword my_ip_addr = 0L;		/* for external references */
longword sin_mask = 0xfffffe00L;	/* IP subnet mask */

static int ip_id = 0;			/* IP packet number */
static int next_tcp_port = 1024;	/* auto incremented */
static int next_udp_port = 1024;
static tcp_Socket *tcp_allsocs = NULL;	/* TCP socket linked list head */
static udp_Socket *udp_allsocs = NULL;	/* UDP socket linked list head */

#define tcp_FlagFIN     0x0001
#define tcp_FlagSYN     0x0002
#define tcp_FlagRST     0x0004
#define tcp_FlagPUSH    0x0008
#define tcp_FlagACK     0x0010
#define tcp_FlagURG     0x0020
#define tcp_FlagDO      0xF000
#define tcp_GetDataOffset(tp) (ntohs((tp)->flags) >> 12)
/* IP More Fragments header bit, in network order */
#define IP_MF		0x2000

/* Timer definitions */
#define tcp_LONGTIMEOUT 13      /* timeout, sec, for opens */
#define tcp_TIMEOUT 13          /* timeout, sec, during a connection */

#define TCP_SBUFSIZE 4096 	/* max bytes to buffer in a tcp socket */
#define TCP_RBUFSIZE 4096
#define UDP_BUFSIZE ETH_MSS	/* max bytes to buffer in a udp socket */
#define UDP_LENGTH (sizeof(udp_Header))

#define CONNECTION_REJECTED 9	/* a returnable status */

#define tcp_NOSEND	0	/* for tcp send_kind */
#define tcp_SENDNOW	1 	/* repeat sending anything */
#define tcp_SENDACK	2	/* send an ACK even if our data is blocked */

word	mss = ETH_MSS;		/* Maximum Segment Size */
static word do_window_probe = 0; /* to probe closed windows in tcp_send() */
longword start_time;		/* debugging, time first session began */

#define in_GetVersion(ip) ((ip)->hdrlen_ver >> 4)
#define in_GetHdrlen(ip)  ((ip)->hdrlen_ver & 0xf)  /* 32 bit word size */
#define in_GetHdrlenBytes(ip)  (in_GetHdrlen(ip) << 2) /* 8 bit byte size */

/* Start reassembly section */
static in_Header * reasm(in_Header *);
static int use_reasmbuf;	/* 0 = not doing fragmented IP datagram */
				/* else is 1 + slot number to clean later*/
#define MAXSLOTS	4	/* number of datagrams in progress */
#define FRAGDATALEN (576-20)	/* size of each datagram */
typedef struct {
	int	next;		/* must be first element */
	int	first;		/* offsets from slot->ipdata[0] */
	int	last;
	} Hole;

/* Fragmentation buffer is organized as MAXSLOTS slots, each of which is
   FRAGDATALEN + 20 IP header plus three words of local overhead.
*/
struct reasmstruct {
   	longword frag_tmo;	/* reassembly timeout, 0 = unused slot */
	int hole_count;			/* count of holes in datagram */
	in_Header iphdr;		/* IP header, 20 bytes */
	byte ipdata[FRAGDATALEN];	/* IP data, 556 bytes */
	} reasmbuf[MAXSLOTS], * slot;
/* End reassembly section */

/*	Network order diagrams

	IP header
    0                   1                   2                   3   
    0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |Version|  IHL  |Type of Service|          Total Length         |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |         Identification        |Flags|      Fragment Offset    |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |  Time to Live |    Protocol   |         Header Checksum       |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                       Source Address                          |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                    Destination Address                        |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                    Options                    |    Padding    |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

   	UDP header
                  0      7 8     15 16    23 24    31  
                 +--------+--------+--------+--------+ 
                 |     Source      |   Destination   | 
                 |      Port       |      Port       | 
                 +--------+--------+--------+--------+ 
                 |                 |                 | 
                 |     Length      |    Checksum     | 
                 +--------+--------+--------+--------+ 
                 |                                     
                 |          data octets ...            
                 +---------------- ...                 


	TCP Header
    0                   1                   2                   3   
    0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |          Source Port          |       Destination Port        |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                        Sequence Number                        |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                    Acknowledgment Number                      |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |  Data |           |U|A|P|R|S|F|                               |
   | Offset| Reserved  |R|C|S|S|Y|I|            Window             |
   |       |           |G|K|H|T|N|N|                               |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |           Checksum            |         Urgent Pointer        |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                    Options                    |    Padding    |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |                             data                              |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
*/
/*
 * tcp_init - Initialize the tcp implementation
 *	    - may be called more than once without hurting
 */
int
tcp_init(void)
{
	if (initialized != 0) return (1);	/* success, inited already */
					/* initialize TCP/IP stack */
	icmp_init();			/* clear ICMP material */
	request_busy = 0;		/* clear DHCP request() logic */
	last_nameserver = 0;		/* reset the name server table */
	arp_last_gateway = 0;		/* clear old gateway info */
	tcp_allsocs = NULL;		/* zero socket pointers */
	udp_allsocs = NULL;
	ip_id = (int)(set_timeout(0) & 0xffff);/* packet number, convenient */
	use_reasmbuf = 0;		/* 0 = not using IP reassembly buf */
	memset(reasmbuf, 0, sizeof (reasmbuf));
	imposter = 0;			/* ARP for own IP flag */
	initialized = eth_init();	/* init the hardware, can fail */
					/* next port numbers to choose */
	next_udp_port = next_tcp_port = 1024 + (int)(set_timeout(0) & 0x1ff);
	eth_free (NULL);		/* clear all pkt rcv bufs */
	return (initialized);		/* success (1) or failure (0) */
}

/*
 * Shut down the data link and all services
 */
void
tcp_shutdown(void)
{
	if (initialized)
		{
		while (tcp_abort(tcp_allsocs)) ; /* stop each TCP session */
		end_bootp();			/* release DHCP IP lease */
		}
	initialized = 0;
}

int 
udp_open(udp_Socket *s, word lport, longword ina, word port)
{
	if (s == NULL) return (0);
	if (imposter == 0 && arp_resolve(my_ip_addr, NULL))/* imposter check */
		{
		outs("\r\n WARNING: our IP address is used by");
		outs(" another station! Quitting.");
		return(0);			/* fail back to user */
		}
	imposter++;				/* say have done the check */
	if (s->rdata) free(s->rdata);		/* free any allocated buffer*/
	memset(s, 0, sizeof(udp_Socket));
	if (lport == 0) lport = ++next_udp_port;  /* get a nonzero port val */
	s->myport = lport;
	/* check for broadcast */
	if (ina == 0xffffffffL || ina == 0L || ina == ipbcast)
		memset(s->hisethaddr, 0xff, sizeof(eth_address));
	else
		if (arp_resolve(ina, &s->hisethaddr[0]) == 0)
			return (0);			/* fail */
	if ((s->rdata = malloc(UDP_BUFSIZE + sizeof(udp_Header))) == NULL)
		return (0);				/* fail */
	s->hisaddr = ina;
	s->hisport = port;
	s->ip_type = UDP_PROTO;
	s->next = udp_allsocs;
	udp_allsocs = s;
	s->sock_mode = UDP_MODE_CHKSUM;		/* turn on checksums */
	s->sisopen = SOCKET_OPEN;
	return (1);					/* success */
}

/*
 * Actively open a TCP connection to a particular destination.
 * return 0 on error
 */
int 
tcp_open(tcp_Socket *s, word lport, longword ina, word port) 
{
	if (s == NULL) return (0);
	if (s->sisopen != SOCKET_CLOSED)
		return (0);

	if (imposter == 0 && arp_resolve(my_ip_addr, NULL))/* imposter check */
		{
		outs("\r\n WARNING: our IP address is used by");
		outs(" another station! Quitting.");
		return(0);			/* fail back to user */
		}
	imposter++;				/* say have done the check */
	if (s->rdata) free(s->rdata);		/* free preallocated buf */
	if (s->sdata) free(s->sdata);		/* free preallocated buf */

	memset(s, 0, sizeof(tcp_Socket));	/* zero everything */
	s->mss = mss;				/* hardware limit */
	if ((ina ^ my_ip_addr) & sin_mask)	/* if not on this network */
		s->mss = (mss > 536)? 536: mss;	/* non-fragmentable max-40 */
	if (ktcpmss < s->mss)			/* user override */
		s->mss = ktcpmss;		/*  is an upper limit */
	if (lport == 0)
		lport = ++next_tcp_port;  /* get a nonzero port value */
	s->myport = lport;
	if (arp_resolve(ina, &s->hisethaddr[0]) == 0)
		return (0);		/* failed to get host Ethernet addr */
						/* create data bufs */
	if ((s->rdata = malloc(TCP_RBUFSIZE + sizeof(tcp_Header))) == NULL)
		return (0);			/* fail */
	if ((s->sdata = malloc(TCP_SBUFSIZE)) == NULL)
		{
		free(s->rdata);
		s->rdata = NULL;
		return (0);
		}
	s->next = tcp_allsocs;
	tcp_allsocs = s;
	s->hisaddr = ina;
	s->hisport = port;
	s->seqnum = ntohl(set_timeout(0)) >> 16;
	s->flags = tcp_FlagSYN;
	s->state = tcp_StateSYNSENT;
	s->ip_type = TCP_PROTO;
	s->sisopen = SOCKET_OPEN;
	s->sock_mode = TCP_MODE_NAGLE;		/* Nagle slow start */
	s->rto = 18 * 4;			/* assume four seconds */
	s->cwindow = s->mss;			/* slow start VJ algorithm */
	s->ssthresh = TCP_RBUFSIZE;
	s->timeout = set_timeout(tcp_LONGTIMEOUT); /* seconds */
	start_time = set_ttimeout(0);		/* log time reference */
	return (tcp_send(s));			/* fail if send fails */
}

/*
 * Passive open: listen for a connection on a particular port
 */
tcp_listen(tcp_Socket *s, word lport, longword ina, word port, word timeout)
{
	if (s == NULL) return (0);

	if (s->rdata) free(s->rdata);		/* free preallocated buf */
	if (s->sdata) free(s->sdata);		/* free preallocated buf */
	memset(s, 0, sizeof(tcp_Socket));	/* zero everything */
	s->ip_type = TCP_PROTO;
	s->mss = mss;				/* hardware limit */
	s->cwindow = s->mss;			/* slow start VJ algorithm */
	s->rto = 18 * 4;			/* assume four seconds */
	s->state = tcp_StateLISTEN;
	if (timeout != 0)
		s->timeout = set_timeout(timeout);	/* seconds */
	s->myport = lport;
	s->hisport = port;
	s->hisaddr = ina;
	s->seqnum = ntohl(set_timeout(0)) >> 16;
	if ((s->rdata = malloc(TCP_RBUFSIZE + sizeof(tcp_Header))) == NULL)
		return (0);			/* fail */
	if ((s->sdata = malloc(TCP_SBUFSIZE)) == NULL)
		{
		free(s->rdata);
		s->rdata = NULL;
		return (0);
		}
	s->next = tcp_allsocs;			/* active socket list */
	tcp_allsocs = s;			/* remember active socket */
	s->ip_type = TCP_PROTO;			/* we speak TCP here */
	s->sisopen = SOCKET_OPEN;		/* socket is open */
	s->sock_mode = TCP_MODE_PASSIVE + TCP_MODE_NAGLE;
	s->send_kind = tcp_NOSEND;		/* say no pending sends */
	timeout = 0;
	return (1);
}


static int
udp_close(udp_Socket *ds)
{
	register udp_Socket *sp;

	sp = udp_allsocs;		/* ptr to first socket */
	if (sp == NULL) return (0);	/* failure */
	ds->sisopen = SOCKET_CLOSED;	/* say socket is closed, do first */

	if (sp == ds)
		udp_allsocs = ds->next; /* if we are first, unlink */
	while (sp != NULL)
		{
		if (sp->next == ds)	/* if current points to us */
			{
			sp->next = ds->next; /* point it to our successor */
   			break;
			}
		sp = sp->next;		/* look at next socket */
		}
	if (ds->rdata != NULL)
		{
		free(ds->rdata);	/* free received data buffer */
		ds->rdata = NULL;	/* invalidate data buffer address */
		}
        ds->rdatalen = 0;		/* flush pending reads */
	return (1);			/* success */
}

/*
 * Send a FIN on a particular port -- only works if it is open
 * Must still allow receives
 * Returns 0 for failure
 */
static int 
tcp_close(tcp_Socket *s)
{

	if (s == NULL || s->ip_type != TCP_PROTO)
		return (0);			/* failure */

	s->sdatalen = s->sdatahwater;	 /* cannot send new data now */
	if (s->state & (tcp_StateESTAB | tcp_StateSYNREC | tcp_StateCLOSWT))
		{
		if (kdebug & DEBUG_STATUS) outs("FIN sent, closing\r\n");
		if (s->state == tcp_StateCLOSWT)
			s->state = tcp_StateLASTACK;
		else
			s->state = tcp_StateFINWT1;
		s->flags = tcp_FlagACK | tcp_FlagFIN;
		s->timeout = set_timeout(tcp_TIMEOUT);	/* added */
		s->send_kind = tcp_SENDACK;	/* sending our FIN */
		tcp_send(s);
		return (1);			/* success */
		}
	s->state = tcp_StateCLOSED;
	tcp_unthread(s);			/* remove socket from list */
	return (0);
}

/*
 * Abort a tcp connection
 * Returns 0 if failure
 */
int 
tcp_abort(tcp_Socket *s)
{
	if (s == NULL) return (0);		/* failure */

	if (kdebug & DEBUG_STATUS) outs("TCP_ABORT\r\n");
	if ((s->state != tcp_StateLISTEN) && (s->state != tcp_StateCLOSED))
		{
		s->flags = tcp_FlagRST | tcp_FlagACK;
		s->send_kind = tcp_SENDACK;	/* force a response */
		tcp_send(s);
		}
	s->sdatalen = 0;
	s->state = tcp_StateCLOSED;
	tcp_unthread(s);
	return (1);				/* success */
}

/*
 * Retransmitter - called periodically to perform tcp retransmissions
 * Returns 0 if failure
 */
static int
tcp_retransmitter(void)
{
	register tcp_Socket *s;
	register int i;

	for (s = tcp_allsocs; s != NULL; s = s->next)
		{

		/* Trigger to send, s->send_kind, from functions, */
		/* or there is data not yet sent */
		if ((s->send_kind != tcp_NOSEND) ||
				(s->sdatalen - s->sdatahwater))
			tcp_send(s);

#ifdef DELAY_ACKS
		/* If outgoing ACK is in delay queue */
		if (s->delayed_ack &&
			chk_timeout(s->delayed_ack) == TIMED_OUT)
			{		/* if timed out send ACK now */
			s->delayed_ack = 0;
			s->send_kind |= tcp_SENDACK;
			tcp_send(s);
			}
#endif	/* DELAY_ACKS */

		/* Check for timeout of returned ACKs */
		for (i = 0; i < s->sendqnum; i++)	 /* waiting for ACK */
			if (chk_timeout(s->sendq[i].timeout) == TIMED_OUT)
				{
				lost_ack(s);	/* lost ACK actions */
				break;		/* exit sendq for-loop */
    				}
		
		/* If probing closed window, or sending keepalive check */
		if (s->winprobe ||
		   (s->keepalive && (chk_timeout(s->keepalive) == TIMED_OUT)))
			{
			do_window_probe++;	/* window probe */
			tcp_send(s);		/* send probe */
			}

  				/* if no transmission for idle ticks */
  		if (s->idle && (chk_timeout(s->idle) == TIMED_OUT))
			s->cwindow = s->mss;	/* use slow start */

			/* IP reassembly buffer timeout checks */
		for (i = 0; i < MAXSLOTS; i++)
			if (reasmbuf[i].frag_tmo &&
			       chk_timeout(reasmbuf[i].frag_tmo) == TIMED_OUT)
			         reasmbuf[i].frag_tmo = 0; /* empty the slot */

	/* TCP machine states which can timeout via variable s->timeout */
		if (s->timeout && (chk_timeout(s->timeout) == TIMED_OUT))
			switch (s->state)
			{
			case tcp_StateSYNREC:
			case tcp_StateSYNSENT:
				tcp_close(s);		/* graceful close */
				break;
			case tcp_StateTIMEWT:
				s->state = tcp_StateCLOSED;
				tcp_unthread(s);	/* purge it */
				break;
			default:
				tcp_abort(s);
				break;
			}		/* end of switch */
		}			/* foot of for loop */

	if (DHCP_refresh() == -1)	/* if failed to refresh lease */
		{	/* create no new output from here on, else loops */
		tcp_shutdown();		/* end all traffic */
		return (0);		/* failure */
		}

	return (1);			/* success */
}

/*
 * Unthread a socket from the socket list, if it's there. Return 0 on failure
 */
static int
tcp_unthread(tcp_Socket *ds)
{
	register tcp_Socket *sp;

	if (ds == NULL) return (0);		/* failure */

	ds->sisopen = SOCKET_CLOSED;		/* say socket is closed */

	if ((sp = tcp_allsocs) == NULL)		/* no socket in the queue */ 
		return (0);

	if (sp == ds)
		tcp_allsocs = ds->next; /* if we are first, unlink */
	while (sp != NULL)
		{
		if (sp->next == ds)		/* if current points to us */
			{
			sp->next = ds->next; /* point it to our successor */
   			break;
			}
		sp = sp->next;			/* look at next socket */
		}
	return (1);				/* success */
}

/*
 * tcp_tick - called periodically by user application
 *	    - returns 0 when our socket closes
 *	    - called with socket parameter or NULL
 */
tcp_tick(sock_type *s)
{
	in_Header *ip;
	in_Header * temp_ip;
	int packettype;

					/* read a packet */
	while ((ip = (in_Header *)eth_arrived(&packettype)) != NULL)
	{
	switch (packettype)	  	/* network big endian form */
	{
	case TYPE_IP:					/* do IP */
		if ((in_GetVersion(ip) != 4) ||
		(checksum(ip, in_GetHdrlenBytes(ip)) != 0xffff))
			{
			if (kdebug & DEBUG_STATUS)
			    outs("IP Received BAD Checksum \r\n");
			break;
			}
		if ((my_ip_addr == 0L) || 
			(htonl(ip->destination)	== my_ip_addr))
			{
			if ((temp_ip = reasm(ip)) == NULL)
				break;	/* reassembly in progress, wait */

			if (use_reasmbuf > 0)
			 	{	/* reassembly completed, process */
				eth_free(ip); 	/* free lan adapter queue */
				ip = temp_ip;	/* look at reassembly buf */
				}
			switch (ip->proto & 0xff)
				{
				case TCP_PROTO:
					tcp_handler(ip);
					break;
				case UDP_PROTO:
					udp_handler(ip);
					break;
				case ICMP_PROTO:
					icmp_handler(ip);
					break;
				default:
					break;
				}	/* end of switch (ip->proto) */
			}
		break;

	case TYPE_ARP:					/* do ARP */
		arp_handler(ip);
		break;
	case TYPE_RARP:					/* do RARP */
		rarp_handler(ip);
		break;
	default:				/* unknown type */
		break;
	}				/* end of switch */

	if (use_reasmbuf > 0)	/* if processing from reassembly buffer */
		{
		reasmbuf[use_reasmbuf - 1].frag_tmo = 0; /* clear buffer */
		use_reasmbuf = 0;			/* done using it */
		temp_ip = NULL;
		}
	else
		eth_free(ip);		/* free the processed packet */
    }					/* end of while */
	if (tcp_retransmitter() == 0)
		return (0);		/* check on pending sends */
	return ((s != NULL)? s->tcp.sisopen: 0); /* 0 means closed socket */
}

/* IP fragment reassembly process. Enter with packet IP pointer, ip.
   Return that IP pointer if packet is not fragmented.
   Return NULL if do not process packet further (such as building pieces).
   Return new IP pointer for reassembled packet, pointing to a reasmbuf.
   Global variable use_reasmbuf is 0 to not use reassembly results, else
   is 1 + index of reasmbuf to be cleared after use.
   Global variables reasmbuf[..]->frag_tmo hold buffer timeout (Bios ticks);
   clear these to dis-use the buffer.
*/
in_Header *
reasm(in_Header *ip)
{
	int ip_hlen, frag, frag_first, frag_last, frag_len;
	Hole * previous;
	register int i;
	register Hole * hole;

	use_reasmbuf = 0;	/* assume not finishing IP datagram */

/* Fragmented datagrams have either More Frags flag bit set or the 
   fragment offset field non-zero. Unfragmented datagrams have both clear.
*/
	if ((frag = ntohs(ip->frag) & 0x3fff) == 0) /* frag flags and offset */
		return (ip);			/* not fragmented */

/* See if this fragment has a reassembly buffer assigned. Match on protocol,
   IP identification, source IP, and if not allocated a timeout.
*/
	for (i = 0; i < MAXSLOTS; i++)
		{
		slot = &reasmbuf[i];
		use_reasmbuf = i + 1; /* assume finishing IP datagram */
		if ((slot->iphdr.identification == ip->identification) &&
				(slot->iphdr.source == ip->source) &&
				(slot->iphdr.proto == ip->proto) &&
				(slot->frag_tmo != 0))
			goto include;	/* have some pieces already */
		}

	for (i = 0; i < MAXSLOTS; i++)	/* find an empty slot for new reasm */
		{
		slot = &reasmbuf[i];
		if (slot->frag_tmo == 0)	/* if slot is unused */
			break;
		}
	if (i >= MAXSLOTS)
		{
		use_reasmbuf = 0;
		return (NULL);		/* insufficient space, discard pkt */
		}

	slot->frag_tmo = set_timeout(1 + ip->ttl >> 2); /* timeout from TTL */
	bcopy((byte *)ip, &slot->iphdr, 20);	/* copy basic IP header */
	hole = (Hole *)&slot->ipdata[0]; /* first hole struct goes here */
	previous = (Hole *)&slot->iphdr.checksum;
	previous->next = 0;		/* pointer to first hole struct */
	hole->first = hole->next = 0;
	hole->last = FRAGDATALEN;	/* infinity */
	slot->hole_count = 1;		/* count of holes, just initial one */

		/* Move data into the existing reassembly buffer */
include:
	ip_hlen = in_GetHdrlenBytes(ip);	/* IP header length */
	frag_len = ntohs(ip->length) - ip_hlen;	/* bytes of IP data */
	frag_first = (frag & 0x1fff) << 3;	/* offset of first data byte*/
	frag_last = frag_first + frag_len - 1;	/* offset of last data byte */
			 /* if More Frags bit is clear then have end of
			 /* datagram and hence can get datagram length */
	if ((frag & IP_MF) == 0)		/* if More Frags is clear */
		slot->iphdr.length = ntohs(frag_last + ip_hlen + 1);

	previous = (Hole *)&slot->iphdr.checksum; 	/* first hole */
	hole = (Hole *)&slot->ipdata[previous->next];

				/* find hole where at least one edge fits */
	for ( i = 0; i < slot->hole_count; i++)
		if (frag_first > hole->last || frag_last < hole->first)
			{    /* does not go into this hole, look at next */
			previous = hole;	/* remember backward */
			hole = (Hole *)&slot->ipdata[hole->next]; 
			}
		else
			break;		/* goes in hole, figure where below */

	if (i >= slot->hole_count)	/* exhausted search for opening */
		{
		slot->frag_tmo = 0;
		use_reasmbuf = 0;
		return (NULL);		/* Failed, no slot matching offset */
		}

	slot->hole_count--;		/* delete current hole pointer */
	previous->next = hole->next;	/* forward link over this hole */  

	if (frag_first > hole->first) 		/* leaves empty beginning */
		{
			/* recreate forward pointer to this new hole */
		previous->next = hole->first;	/* point to this hole */
		hole->last = frag_first - 1;	/* end of this hole */
		slot->hole_count++;
			/* move view to next hole for trailing edge test */
		if (hole->last < FRAGDATALEN)	/* if so there is another */
			{
			previous = hole;
			hole = (Hole *)&slot->ipdata[hole->next];
			}
		}

	if ((frag & IP_MF) &&		 	/* if More Frags bit is set */
	   (frag_last < hole->last))  		/* and leaves empty ending */
		{		/* create a new hole for empty portion */
		int old_next, old_last;

		old_next = hole->next;		/* old forward pointer */
		old_last = hole->last;
		hole = (Hole *)&slot->ipdata[frag_last + 1]; /* make new hole*/
		hole->next = old_next;		/* copy old pointers */
		hole->last = old_last;
		hole->first = previous->next = frag_last + 1;
		slot->hole_count++;
		}

	if ((frag_first + frag_len) > FRAGDATALEN) /* length safety check */
		{
		slot->frag_tmo = 0;		/* delete this buffer */
		use_reasmbuf = 0;
		return (NULL);			/* fail */
		}

	bcopy((byte *)ip + ip_hlen, &slot->ipdata[frag_first], frag_len);

	if (slot->hole_count)		/* fully reassembled yet? */
		{
		use_reasmbuf = 0;	/* not finished IP datagram */
		return (NULL);		/* not fully reassembled yet */
		}
	slot->iphdr.frag = 0;		/* clear frags information */
	return (&slot->iphdr); 		/* use this datagram pointer */
}

static int
udp_write(udp_Socket *s, byte FAR *datap, int len)
{
	tcp_PseudoHeader ph;
	struct pkt
		{
		in_Header  in;
		udp_Header udp;
		int	   data;
		} register *pkt;

	if (s == NULL || datap == NULL)
		return (0);			/* failure */

	pkt = (struct pkt *)eth_formatpacket(&s->hisethaddr[0], TYPE_IP);
	pkt->in.length = htons(sizeof(in_Header) + UDP_LENGTH + len);
						/* UDP header */
	pkt->udp.srcPort = htons(s->myport);
	pkt->udp.dstPort = htons(s->hisport);
	pkt->udp.length = htons(UDP_LENGTH + len);
	bcopyff(datap, &pkt->data, len);
						/* Internet header */
	pkt->in.hdrlen_ver = 0x45;		/* version 4, hdrlen 5 */
	pkt->in.tos = 0;
	pkt->in.identification = htons(++ip_id);	/* was post inc */
	pkt->in.frag = 0;
	pkt->in.ttl = 60;
	pkt->in.proto = UDP_PROTO;			/* UDP */
	pkt->in.checksum = 0;
	pkt->in.source = htonl(my_ip_addr);
	pkt->in.destination = htonl(s->hisaddr);
	pkt->in.checksum = ~checksum(&pkt->in, sizeof(in_Header));
					/* compute udp checksum if desired */
	if (s->sock_mode & UDP_MODE_CHKSUM == 0)
		pkt->udp.checksum = 0;
	else
		{
		ph.src = pkt->in.source;		/* big endian now */
		ph.dst = pkt->in.destination;
		ph.mbz = 0;
		ph.protocol = UDP_PROTO;		/* UDP */
		ph.length = pkt->udp.length;		/* big endian now */
		ph.checksum = checksum(&pkt->udp, htons(ph.length));
		pkt->udp.checksum = ~checksum(&ph, sizeof(ph));
		}
	if (eth_send(ntohs(pkt->in.length)) != 0)	/* send pkt */
			return (len);
	if (kdebug & DEBUG_STATUS) outs("Failed to put packet on wire\r\n");
	  	return (0);			/* sending failed */
}

/*
 * udp_read - read data from buffer, does large buffering.
 * Return 0 on failure.
 */
static int 
udp_read(udp_Socket *s, byte FAR * datap, int maxlen)
{
	register int x;

	if (s == NULL || datap == NULL || s->rdata == NULL || maxlen ==0) 
				return (0);	/* failure */
	if ((x = s->rdatalen) > 0)
		{
		if (x > maxlen) x = maxlen;
		bcopyff(s->rdata, datap, x);
		s->rdatalen -= x;
    		}
	return (x);
}

udp_cancel(in_Header *ip)
{
	int len;
	register udp_Header *up;
	register udp_Socket *s;
						/* match to a udp socket */
	len = in_GetHdrlenBytes(ip);
	up = (udp_Header *)((byte *)ip + len);	/* udp frame pointer */
						/* demux to active sockets */
	for (s = udp_allsocs; s != NULL; s = s->next)
		{
	        if (s->hisport != 0 &&
		     ntohs(up->dstPort) == s->myport &&
		     ntohs(up->srcPort) == s->hisport &&
		     ntohl(ip->source) == s->hisaddr)
		     	break;
        	if (s->hisport != 0 &&		/* ICMP repeat of our pkt */
		     ntohs(up->dstPort) == s->hisport &&
		     ntohs(up->srcPort) == s->myport &&
		     ntohl(ip->source) == my_ip_addr)
			break;		
		}

	if (s == NULL)				/* demux to passive sockets */
		for (s = udp_allsocs; s != NULL; s = s->next)
	    		if (s->hisport == 0 && 
				ntohs(up->dstPort) == s->myport)
	    			break;

	if (s != NULL)
		udp_close(s);
	return (1);				/* success */
}

int
tcp_cancel(in_Header *ip)
{
	int len;
	register tcp_Socket *s;
	register tcp_Header *tp;

	if (ip == NULL) return (0);		/* failure */
	len = in_GetHdrlenBytes(ip);		/* check work */

	tp = (tcp_Header *)((byte *)ip + len);	/* TCP frame pointer */
					    /* demux to active sockets */
	for (s = tcp_allsocs; s != NULL; s = s->next)
		{
        	if (s->hisport != 0 &&		/* them to us */
		     ntohs(tp->dstPort) == s->myport &&
		     ntohs(tp->srcPort) == s->hisport &&
		     ntohl(ip->source) == s->hisaddr)
		     	break;
        	if (s->hisport != 0 &&		/* ICMP repeat of our pkt */
		     ntohs(tp->dstPort) == s->hisport &&
		     ntohs(tp->srcPort) == s->myport &&
		     ntohl(ip->source) == my_ip_addr)
			break;		
		}

	if (s == NULL)			/* demux to passive sockets */
		for (s = tcp_allsocs; s != NULL; s = s->next)
	    		if (s->hisport == 0 &&
				ntohs(tp->dstPort) == s->myport)
	    			break;

	if (s != NULL)
		{
		s->rdatalen = 0;
		s->state = tcp_StateCLOSED;
		tcp_unthread(s);
		}
	return (1);				/* success */
}

static int 
tcp_read(tcp_Socket *s, byte FAR *datap, int maxlen)
{
	register int x;
	int obtained = 0;

	if (s == NULL || datap == NULL || s->rdata == NULL || maxlen <= 0)
			return (0);		/* failure or read nothing */
	if (s->rdatalen <= 0)			/* if nothing to read */
		return (0);

	/* read from rdata, destuff CR NUL, deliver up to maxlen
	   bytes to output buffer datap, report # obtained in int
	   obtained, remember last read byte for CR NUL state.
	   Returns raw bytes consumed from buffer, in x, and number
	   of bytes delivered to caller, in obtained. */
	x = destuff(s->rdata, s->rdatalen, datap, maxlen, &obtained,
		&s->last_read);
	if (x <= 0)
		return (obtained);

	s->rdatalen -= x;			/* bytes consumed */
	bcopyff(&s->rdata[x], s->rdata, s->rdatalen);  /* copy down */

	/* Send a window update if either the window has opened
	by two MSS' since our last transmission, or opening
	across half the total buffer */

	if ( (TCP_RBUFSIZE - s->rdatalen >= 
			(int)s->window_last_sent + 2 * (int)s->mss) ||
		(s->rdatalen < TCP_RBUFSIZE / 2 &&
			s->rdatalen + x >= TCP_RBUFSIZE / 2) )
			s->send_kind = tcp_SENDACK;	/* send now */

	return (obtained);		/* return bytes obtained */
}

/*
 * Write data to a connection.
 * Returns number of bytes written, 0 when connection is not in
 * established state. tcp_retransmitter senses data to be transmitted.
 */
static int
tcp_write(tcp_Socket *s, byte FAR *dp, int len)
{
	register int x;

	if (s == NULL || dp == NULL || s->sdata == NULL)
		return (0);				/* failure */
	if (s->state != tcp_StateESTAB) 
		return (0);
	x = TCP_SBUFSIZE - s->sdatalen;		/* space remaining in buf */
	if (x > len) x = len;
	if (x < 0)
		x = 0;				/* catch negative errors */
	if (x > 0)
		{
		bcopyff(dp, &s->sdata[s->sdatalen], x); /* append to buf */
		s->sdatalen += x;		/* data in send buffer */
		}
	return (x);
}

/*
 * Handler for incoming UDP packets. If no socket tell the host via ICMP.
 */
static int
udp_handler(in_Header *ip)
{
	register udp_Header FAR * up;
	register udp_Socket *s;
	tcp_PseudoHeader ph;
	byte	FAR * dp;
	word	len;
	int	ip_hlen;

	ip_hlen = in_GetHdrlenBytes(ip);
	up = (udp_Header FAR *)((byte *)ip + ip_hlen); /* UDP dgram pointer */
	len = ntohs(up->length);
        if (ntohs(ip->frag) & 0x3fff)   	/* frag flags and offset */
                return (0);             /* can't deal with fragments here */

	if (up->checksum)			/* if checksum field used */
		{
		ph.src = ip->source;		/* already network order */
		ph.dst = ip->destination;
		ph.mbz = 0;
		ph.protocol = UDP_PROTO;
		ph.length = up->length;
		ph.checksum = checksum(up, len);
		if (checksum(&ph, sizeof(tcp_PseudoHeader)) != 0xffff)
			return (0);		/* failure */
		}

				/* demux to active sockets */
	for (s = udp_allsocs; s != NULL; s = s->next)
		if (s->sisopen == SOCKET_OPEN && s->hisport != 0 && 
		    ntohs(up->dstPort) == s->myport &&
		    ntohs(up->srcPort) == s->hisport
		/*  && ntohl(ip->source) == s->hisaddr */)
				break;

	if (s == NULL)			/* demux to passive sockets */
		for (s = udp_allsocs; s != NULL; s = s->next)
			if (s->sisopen == SOCKET_OPEN && s->hisaddr == 0 &&
				ntohs(up->dstPort) == s->myport)
				{
				if (arp_resolve(htonl(ip->source),
					&s->hisethaddr[0]))
					{
		   			s->hisaddr = ntohl(ip->source);
		    			s->hisport = ntohs(up->srcPort);
					}
				break;
	    			}

	if (s == NULL)		/* demux to broadcast sockets */
		for (s = udp_allsocs; s != NULL; s = s->next)
			if (s->sisopen == SOCKET_OPEN && 
				s->hisaddr == ipbcast &&
				ntohs(up->dstPort) == s->myport)
					break;

	if (s == NULL)
		{
		icmp_noport(ip);	/* tell host port is unreachable */
		if (kdebug & DEBUG_STATUS) outs(" UDP discarding...\r\n");
		return (0);			/* say no socket */
		}

	if (s->sisopen == SOCKET_CLOSED) return (0);

					    /* process user data */
	if ((len -= UDP_LENGTH) > 0)
		{
		dp = (byte FAR *)(up);
		if (len > UDP_BUFSIZE) len = UDP_BUFSIZE;
		bcopyff(&dp[UDP_LENGTH], s->rdata, len); /* write to buf */
		s->rdatalen = len;
		s->hisaddr = ntohl(ip->source); /* sender's IP */
		}
	return (1);				/* success */
}

/* Handle TCP packets. If no socket send an RST pkt. */

static 
tcp_handler(in_Header *ip)
{
	tcp_Header FAR * tp;
	register tcp_Socket *s;
	tcp_PseudoHeader ph;

	int ip_hlen, len, diff, data_for_us;	/* signed, please */
	word flags;
	long ldiff;				/* must be signed */

	ip_hlen = in_GetHdrlenBytes(ip);
	tp = (tcp_Header FAR *)((byte *)ip + ip_hlen); /* tcp frame pointer */
	len = ntohs(ip->length) - ip_hlen;	/* len of tcp material */
	flags = ntohs(tp->flags) & 0x003f;	/* tcp flags from pkt */
        if (ntohs(ip->frag) & 0x3fff)   	/* frag flags and offset */
                return (0);             /* can't deal with fragments here */

						/* pseudo header checking */
	ph.src = ip->source;			/* still in network order */
	ph.dst = ip->destination;
	ph.mbz = 0;
	ph.protocol = TCP_PROTO;
	ph.length = htons(len);
	ph.checksum =  checksum(tp, len);
	if (checksum(&ph, sizeof(ph)) != 0xffff)
		{
		if (kdebug & DEBUG_STATUS) outs("Bad TCP checksum\r\n");
		return (1);
		}

				/* demux to active sockets */
	for (s = tcp_allsocs; s != NULL; s = s->next)
		if (s->hisport != 0 &&
		    ntohs(tp->dstPort) == s->myport &&
		    ntohs(tp->srcPort) == s->hisport &&
		    ntohl(ip->source) == s->hisaddr)
			break;

	if (s == NULL)	/* demux to passive sockets, must be a new session */
		for (s = tcp_allsocs; s != NULL; s = s->next)
			if ((s->hisport == 0) &&
				(ntohs(tp->dstPort) == s->myport))
				break;

	if (s == NULL)
		{     /* no matching session exists so we must send a reset */
		tcp_rst(ip, tp);
		return (0);		/* 0 to say socket is closed */
		}
	if (s->sisopen == SOCKET_CLOSED) return (0);

	if (flags & tcp_FlagRST)	/* reset arrived */
		{
		long limit;

		if (kdebug & DEBUG_STATUS)
			outs("RST received.");
		outs(" Connection refused by host\r\n");
		if (flags & tcp_FlagACK)	/* if ACK is valid */
				/* current - prev ack*/
			ldiff = ntohl(tp->acknum) - s->seqnum;
		else
			ldiff = 0;		/* no ACK */
		if (ldiff < 0)			/* ack out of bounds */
			{
			outs("ACK is "); outdec(0xffff & (word)ldiff);
			outs(" bytes before last sent byte\r\n");
			return (0);		/* ignore it */
			}

		limit = s->sdatahwater;		/* last data byte sent */
		if (s->flags & (tcp_FlagSYN | tcp_FlagFIN))
			limit++;		/* count unack'd SYN or FIN */
	
		if (ldiff > limit)		/* if ACK out of window */
			{
			outs("ACK is "); outdec(0xffff & (word)ldiff);
			outs(" bytes beyond last sent byte\r\n");
			return (0);	/* ignore segment */
			}
		tcp_status = CONNECTION_REJECTED;
		s->rdatalen = 0;
		s->sdatalen = s->sdatahwater;
		if (s->sock_mode & TCP_MODE_PASSIVE)
			{
			s->state = tcp_StateLISTEN;
			}
		else
			{
			s->state = tcp_StateCLOSED;
			tcp_unthread(s);	/* unlink from service queue*/
			}
		return (0);		/* say session is closed */
		}

	    /* Update retransmission timeout, Van Jacobson's algorithm */
	if (flags & tcp_FlagACK)	 	/* ACK to something */
		{
		int i;
		longword their_ack;

		their_ack = ntohl(tp->acknum);	/* working copy */

		for (i = s->sendqnum - 1; i >= 0; i--)
			if ((s->notimeseq <= their_ack) &&   /* not a resend */
			    (s->sendq[i].next_seq <= their_ack))  /* in range */
				{	  		/* get new s->rto */
				new_rto(s, (int)(set_ttimeout(0) - 
						s->sendq[i].time_sent));
					/* move down remaining sendq entries*/
				bcopyff(&s->sendq[i], &s->sendq[0],
						(s->sendqnum - (i + 1)) * 
						sizeof (struct sendqstat));
				s->sendqnum -= i + 1;	/* adjust free slots*/
				break;
				}
		}		/* end of timer update from received ACK */


    /* Here starts the main TCP state machine */
    switch (s->state) {

    case tcp_StateLISTEN:			/* accepting SYNs */
    /* Passive open. Sit and wait for an arriving SYN, sync to it and */
    /* respond with an ACK to their SYN plus a SYN of our own. */
    /* Reset the session if SYN is absent */
        if (flags & tcp_FlagSYN)
		{
		if (kdebug & DEBUG_STATUS) outs("LISTEN\r\n");
		if (arp_resolve(ntohl(ip->source), &s->hisethaddr[0]) == 0)
			return (0);	/* failed to get host MAC address */
		s->hisport = ntohs(tp->srcPort);
		s->hisaddr = ntohl(ip->source);
					/* if not on this network */
		if ((s->hisaddr ^ my_ip_addr) & sin_mask)
			s->mss = (mss > 536)? 536: mss;	/* non-fragmentable */
		s->flags = tcp_FlagSYN | tcp_FlagACK;
		s->acknum = ntohl(tp->seqnum) + 1;   /* sync to their SYN */
		s->send_kind = tcp_SENDACK;	     /* reply */
		s->state = tcp_StateSYNREC;
		s->timeout = set_timeout(tcp_TIMEOUT);
		s->keepalive = set_timeout(100); /* keepalive */
		}
	else
        	tcp_rst(ip, tp);		/* send a RST */
        break;

    case tcp_StateSYNSENT:			/* we sent a SYN */
    /* We have sent a SYN from either active or passive opens. */
    /* Our s->seqnum points at it (no displacement yet). No SYN */
    /* has been received yet so s->acknum means nothing so far. */
    /* Get SYN+ACK to our SYN or get just SYN from the remote host. */
   
	if (kdebug & DEBUG_STATUS) outs("SYN_SENT\r\n");
	if ((flags & tcp_FlagSYN) == 0)		/* they did not send SYN */
		{
        	tcp_rst(ip, tp);		/* send a RST */
		break;
		}

	if (flags & tcp_FlagACK)		/* if they included an ACK */
		if (ntohl(tp->acknum) == s->seqnum + 1)
			{ 				/* for our SYN */
			s->state = tcp_StateESTAB;
			s->timeout = 0;			/* do not time out */
			s->seqnum++;			/* count our SYN */
			s->acknum = ntohl(tp->seqnum) + 1; /* sync to them */
			s->flags = tcp_FlagACK;		/* ACK their SYN */
			s->send_kind = tcp_SENDACK;
			tcp_processdata(s, tp, len);	/* if sent data */
			if (kdebug & DEBUG_STATUS) outs("ESTABLISHED\r\n");
			break;
			}
		else			/* simultaneous open or wrong ACK */
			{
			tcp_rst(ip, tp);	/* reset the connection */
			break;
			}

	/* bare SYN arrived, no ACK yet */
	s->acknum = ntohl(tp->seqnum) + 1;		/* sync to them */
	s->flags = tcp_FlagSYN  + tcp_FlagACK;		/* ACK their SYN */
	s->timeout = set_timeout(tcp_TIMEOUT);
	s->state = tcp_StateSYNREC;
	s->send_kind = tcp_SENDACK;			/* reply */
	break;

    case tcp_StateSYNREC:
    /* Received a SYN from active or passive opens, and it has been ACK'd. */
    /* Our s->acknum points one beyond it. We have sent a SYN but we are */
    /* awaiting an ACK to it. */

	if (kdebug & DEBUG_STATUS) outs("SYN_RECVD\r\n");
	if ((flags & tcp_FlagACK) && 			/* an ACK */
		(ntohl(tp->acknum) == (s->seqnum + 1)))	/* to our SYN */
		{
		s->flags = tcp_FlagACK;
		s->seqnum++;			/* move beyond our SYN */
		tcp_processdata(s, tp, len);	/* gather received data */
		s->send_kind = tcp_SENDACK;	/* reply */
		s->state = tcp_StateESTAB;
 /*       	s->timeout = 0;     		/* do not timeout */
		}
	break;


    case tcp_StateESTAB:
    /* Both sides have exchanged and ACK'd their SYNs. Proceed to exchange */
    /* data in both directions. An ACK is required on each packet. */

	s->timeout = 0;				/* do not timeout */
	if ((flags & tcp_FlagACK) == 0)
		break;			 /* they should ACK something*/

				/* process their ack value in packet */
	/* ldiff is their ack number minus our oldest sent seq number */
	/* ldiff < 0 their ack preceeds this window and is an old packet. */
	/* ldiff == 0 is typically an ACK and might represent their timeout.*/
	/* ldiff > 0 exceeding the window (our oldest seqnum + sent data */
	/* s-sdatalen) means pkt is out of order or a window probe (likely)*/
	/* just ACK to keep their timers happy. */
	/* However, in all cases grab any useful data for us. */		
	ldiff = ntohl(tp->acknum) - s->seqnum; /* current ACK - oldest sent */
	if (ldiff > 0 && ldiff <= s->sdatalen)
		{ 			/* their ack is in our window*/
		s->seqnum += ldiff;	/* update ACK'd file pointer */
		diff = (int)ldiff;	/* 16 bits, bigger than our window */
		s->sdatalen -= diff;	/* deduct amount ACK'd data */
		if ((s->sdatahwater -= diff) < 0) /* less old, sent data */
			s->sdatahwater = 0;
					/* move down residual in send buf */
 		bcopyff(&s->sdata[diff], s->sdata, s->sdatalen);

		if (s->loss_count >= 3)		/* if fast retransmit */
			s->cwindow = s->ssthresh; /* shrink congestion wind*/
		s->loss_count = 0;		/* end of lost packets */

		if (s->cwindow < s->ssthresh)	/* VJ congestion */
			s->cwindow += s->mss;	/* fast opening */
		else				/* additive increase */
		 	s->cwindow += s->mss / (s->cwindow / s->mss);
		if (s->cwindow > TCP_SBUFSIZE)
			s->cwindow = TCP_SBUFSIZE;
		}

	/* Case of ldiff < 0 means it's an old packet, they have ACK'd
	   a higher sequence value already, no action needed. */

			/* process incoming data, get s->window */
	data_for_us = tcp_processdata(s, tp, len);  /* get data for us */

	if (s->window)			/* if their window is now open */
		s->winprobe = 0;	/* end window probing, if any */

	/* They did not ACK more of our sent data, we sent data needing ACK, 
	   no window opening, and they sent us no data. These are congestion
	   loss criteria rather than just a window update. */
	
	if ((ldiff == 0) && s->sdatahwater && (s->window <= s->old_window)
		&& (data_for_us == 0))
		{
		s->loss_count++;	/* count lost packet */
		if (s->loss_count == 3)
			{
			word temp_hwater;

			if (kdebug & DEBUG_STATUS)
				outs(" Congestion loss\r\n");
				/* do Van Jacobson congestion avoidance */
				/* don't time below notimedseq seq number */
			s->notimeseq = s->seqnum + s->sdatahwater;
			s->sendqnum = 0;  	/* flush send-timer queue */
			s->ssthresh = s->cwindow >> 1; /* drop back */
			s->cwindow = s->mss;	/* one segment only */
			temp_hwater = s->sdatahwater;	/* save real info */
			s->sdatahwater = 0;	/* resend oldest segment */
			tcp_send(s);		/* send immediately */
			s->sdatahwater = temp_hwater; /* restore real info */
			s->cwindow = s->ssthresh + 3 * s->mss; /* count ACKs*/
			}
		if (s->loss_count > 3)	/* trailing/extra ACKs, count space */
			s->cwindow += s->mss;
		}

	s->old_window = s->window;	/* remember as old remote window */

	if (flags & tcp_FlagFIN)		/* they said FIN */
		{
		if (kdebug & DEBUG_STATUS) outs("FIN received\r\n");
		if (s->sdatalen)		/* we have more to send */
			s->state = tcp_StateCLOSWT;
		else
			{		/* we have nothing more to send */
 					/* say FIN to them too */
 			s->flags |= tcp_FlagFIN;
			s->state = tcp_StateLASTACK; /* nothing more from us*/
			}
		s->acknum++;			/* count their FIN */
		s->send_kind = tcp_SENDACK; 	/* reply */
		}
	break;

    case tcp_StateCLOSWT:
    	/* Have received and ACK'd their FIN. Our s->acknum points at it. */
	/* Obtain last minute ACKs of our data, send our FIN with our */
	/* s->seqnum pointing one byte before our FIN. */

	if (kdebug & DEBUG_STATUS) outs("CLOSEWT\r\n");
	ldiff = ntohl(tp->acknum) - s->seqnum; /* current - prev ack */
	if (ldiff > 0 && ldiff <= s->sdatalen) /* their ack is in our window*/
		{
		s->seqnum += ldiff;	/* update ACK'd file counter */
		diff = (int)ldiff;	/* 16 bits, more than our window */
		s->sdatalen -= diff;	/* deduct amount ACK'd */
		if ((s->sdatahwater -= diff) < 0) /* less old, sent data */
			s->sdatahwater = 0;
		bcopyff(&s->sdata[diff], s->sdata, s->sdatalen);
		}				/* move residual */

	if (s->sdatalen <= 0)
		{
		s->flags |= tcp_FlagFIN;	/* say no more data */
		s->state = tcp_StateLASTACK;	/* get their ACK */
		s->send_kind = tcp_SENDACK;	/* reply */
		}
	break;

    case tcp_StateFINWT1:
	/* Have sent our FIN, our s->seqnum points at it. */
	/* Expect to receive either an ACK for the FIN, or the remote FIN, */
	/* or a remote FIN and and ACK for our FIN. */

	if (kdebug & DEBUG_STATUS) outs("FINWAIT-1\r\n");
	s->sdatalen = s->sdatahwater; /* we can't send new from here */
	if (flags & tcp_FlagACK)
		{
		ldiff = ntohl(tp->acknum) - s->seqnum; /* current - prev ack*/
		if (ldiff > 0 && ldiff <= s->sdatalen)
			{		/* their ack is in our window */
			s->seqnum += ldiff;	/* update ACK'd file counter */
			diff = (int)ldiff;	/* 16 bits, more than our window */
			s->sdatalen -= diff;	/* deduct amount ACK'd */
			if ((s->sdatahwater -= diff) < 0) /* less old */
				s->sdatahwater = 0;
			bcopyff(&s->sdata[diff], s->sdata, s->sdatalen);
			}				/* move residual */
				/* process our data in the packet */
		tcp_processdata(s, tp, len);
		
				/* if this ACKs our FIN */
		if (ntohl(tp->acknum) == s->seqnum + 1)
			{
			s->seqnum++;		/* count our FIN */
			s->state = tcp_StateFINWT2;
			}
		}		/* fall through to look at their FIN bit */


	if (flags & (tcp_FlagFIN | tcp_FlagACK) == 
					(tcp_FlagFIN | tcp_FlagACK))
		{
		if (kdebug & DEBUG_STATUS) outs("FIN received\r\n");
		s->acknum++;		/* ACK their FIN */
		s->send_kind = tcp_SENDACK;

		/* if our FIN has been ACK'd then do timed wait */
		/* else go to CLOSING to await that ACK */
		if (ntohl(tp->acknum) < s->seqnum)	/* not ACK'd yet */
			{
			s->timeout = set_timeout(3);
			s->state = tcp_StateCLOSING;
			tcp_send(s);
			}
		else
			{	/* FINs have been ACK'd, we are done */
			/* state TIMEWT would be next if there were
			   something to drive it, but there isn't */
			tcp_send(s);
			s->state = tcp_StateCLOSED;	 /* no 2 msl */
			tcp_unthread(s);
			}
		}
	break;

    case tcp_StateFINWT2:
	/* Have sent our FIN and received an ACK to it. We have not */
	/* yet received a FIN from the remote side so wait for it here. */
	/* When that FIN arrives send and ACK and do TIMEWT (empty here).*/
	/* Our s->seqnum points at our FIN, their tp->acknum points to our */
	/* FIN too, so these two are equal */

	if (kdebug & DEBUG_STATUS) outs("FINWAIT-2\r\n");
	s->sdatalen = s->sdatahwater;	/* cannot send from here */
	if (flags & tcp_FlagFIN)
		if ((ntohl(tp->acknum) == s->seqnum) &&
			(ntohl(tp->seqnum) >= s->acknum))
			{
			s->acknum++;		/* ACK their FIN */
			s->send_kind = tcp_SENDACK;
			tcp_send(s);		/* send last ACK */
			/* state TIMEWT would be next if there were
			   something to drive it, but there isn't */
			s->state = tcp_StateCLOSED;	 /* no 2 msl */
			tcp_unthread(s);
			}
	break;

    case tcp_StateCLOSING:
    	/* Have sent our FIN, our s->seqnum points at it, but it has */
	/* not been ACK'd. Thus their tp->acknum < our s->seqnum */
	/* Have received their FIN, our s->acknum points at it, and */
	/* we have sent an ACK for their FIN. */
	/* Get an ACK to our FIN and then go to TIMEWT (empty here). */

	if (kdebug & DEBUG_STATUS) outs("CLOSING\r\n");
    	if (flags & tcp_FlagACK)
		if (ntohl(tp->acknum) == s->seqnum)
			{
			/* state TIMEWT would be next if there were
			   something to drive it, but there isn't */
			s->state = tcp_StateCLOSED;	 /* no 2 msl */
			tcp_unthread(s);
			}
	break;

    case tcp_StateLASTACK:
    /* Have received and ACK'd their FIN, so our s->acknum points at it. */
    /* Have sent a FIN to them with our s->seqnum one less than it. */
    /* Here we get their ACK to our FIN and exit the protocol stack. */

	if (kdebug & DEBUG_STATUS) outs("LAST_ACK\r\n");
	if (flags & tcp_FlagACK)		/* an ACK to our FIN */
		if (ntohl(tp->acknum) == s->seqnum + 1)
			{
			s->state = tcp_StateCLOSED;     /* no 2 msl */
			s->send_kind = tcp_NOSEND;	/* no repeats */
			tcp_unthread(s);
			break;
			}
	/* Get here if they lost our ACK + FIN pkts. Resend both */
	if (flags & tcp_FlagFIN)    
		{
		s->flags = tcp_FlagACK | tcp_FlagFIN;
		s->send_kind = tcp_SENDACK;		/* reply */
		}
	break;

	/* a dummy wait 2 MSL for old pkts to die before reusing this port */
    case tcp_StateTIMEWT:
	if (kdebug & DEBUG_STATUS) outs("TIMED_WAIT\r\n");
	s->state = tcp_StateCLOSED;		 /* no 2 msl */
	tcp_unthread(s);
	break;
    }						/* end switch */
    return (1);					/* success */
}

/*
 * Process the data for us in an incoming packet.
 * Called from all states where incoming data can be received: established,
 * fin-wait-1, fin-wait-2
 * len is the length of TCP header + data
 * Sets s->send_kind if transmission is needed.
 * Returns int 0 for nothing needs doing, > 0 for data accepted,
 * and < 0 for data rejected.
 */
static int
tcp_processdata(tcp_Socket *s, tcp_Header FAR *tp, int len)
{
	register int diff, x;
	long ldiff;					/* signed */
	word numoptions, opt_temp;
	byte FAR * dp, FAR * options;

	if (s == NULL || tp == NULL) return (0);	/* failure */

	s->window = ntohs(tp->window);
	if (s->window > 0x7fff)			/* 64KB window nonsense? */
		s->window = 0x7fff;		/* yes, cut window to 32KB */

	ldiff = ntohl(tp->seqnum) - s->acknum;	/* new data, signed long */
	/* 
	   ldiff is normally zero, meaning their first data byte is what we
	   expect next. A negative value means they sent some old data,
	   a positive value means they are starting beyond/future of what
	   we expect (creating a hole).
	*/
	if (ntohs(tp->flags) & tcp_FlagSYN)
		ldiff++;			/* SYN counts as one unit */
	diff = (int)ldiff;			/* 16 bit version */
						/* find the data portion */
	x = tcp_GetDataOffset(tp) << 2;		/* quadword to byte count */
	dp = (byte FAR *)tp + x;		/* points to data */

						/* process those options */
	if (numoptions = x - sizeof(tcp_Header))
		{
		options = (byte FAR *)tp + sizeof(tcp_Header);
		while (numoptions-- > 0)
			switch (*(options++) & 0xff)
				{
				case 0: numoptions = 0;	/* end of options */
				case 1:	break;		/* nop */

				  /* we are very liberal on MSS stuff */
				case 2: if (*options == 4)	/* length */
						{
				opt_temp = ntohs(* (word FAR *)(&options[1]));
						if (opt_temp < s->mss)
							s->mss = opt_temp;
						}
					numoptions -= *options - 1;
					options += *options - 1;
			  		break;
				default: break;
				}	/* end of switch and while */
		}			/* end of if */
				    	/* done option processing */

	len -= x;			/* remove the TCP header */

	if ((len != 0) || (diff != 0))	/* data present or keepalive */
		{
#ifdef DELAY_ACKS
			/* if not delaying yet, do so now, by one avg rtt */
		if (s->delayed_ack == 0)
		 	s->delayed_ack = set_ttimeout(s->vj_sa);
#else	/* not implementing delayed ACKs */
			s->send_kind = tcp_SENDACK;	/* send now */

#endif /* DELAY_ACKS */
		}
	
	if (len <= 0)			/* amount of data in this packet */
		return (len);		/* no new data, 0 = must be an ACK */

				/* skip already received bytes */
				/* diff = last rcv'd byte - new start*/
	if (diff > 0)		/* if data starts beyond our last ACK */
		return (len);	/*  then ignore the data */	
	dp -= diff;		/* move to new data in packet */
	len += diff;		/* length of new data in packet */
	 			/* limit receive size to our window */
	if (s->rdatalen < 0)
		s->rdatalen = 0; /* sanity check */

	if (len > (x = TCP_RBUFSIZE - s->rdatalen))
			len = x;		/* space available only */
	if (len <= 0)				/* old packet */
		return (1);			/* say some data for us */

	bcopyff(dp, &s->rdata[s->rdatalen], len); /* copy data to buffer */
	s->rdatalen += len;		/* count of data in receiver buf */
	s->acknum += len;		 /* new ack begins at end of data */
	return (len);				/* success */
}

/* Measure elapsed time, given the observed round trip time (rtt) in tics
   calculate new s->rto, smoothed average and standard deviation */
void
new_rto(tcp_Socket * s, int rtt)
{
	register int rtt_error;

/* s->vj_sa is 8 * (smoothed average round trip time), Bios tics */
/* s->vj_sd is 8 * (std deviation from smoothed average), Bios tics */
/* rtt is segment ACK delay, Bios tics */
	
	if (rtt < 0)			/* delay time sanity, midnight fails*/
		return;
	rtt_error = (rtt << 3) - s->vj_sa;	/* 8 * error from avg */
	s->vj_sa += (rtt_error >> 3);	/* 8 * smoothed avg delay time */
	if (rtt_error < 0)		/* want magnitude of the error */
		rtt_error = - rtt_error;
	rtt_error -= (s->vj_sd >> 2);
	s->vj_sd += rtt_error;	 		/* 8 * smoothed std dev */
				/* round trip timeout: avg + 4 std_dev */
	s->rto = ((s->vj_sa >> 2) + s->vj_sd) >> 1;
	if (s->rto > 60 * 18)		/* PC clock ticks, 18.2/sec */
		s->rto = 60 * 18; 	/* 60 sec cap */
	if (s->rto < 4)
		s->rto = 4;		/* floor of four Bios tics */
	krto(s->rto);			/* tell Kermit main body */
	if (kdebug & DEBUG_TIMING)	/* show round trip time stats */
		{
		outs("time="); outdec((int)(0x7fffL &  
				(set_ttimeout(0) - start_time)));
		outs(" rtt="); outdec(rtt);
		outs(" avg="); outdec(s->vj_sa >> 3);
		outs(" std_dev="); outdec(s->vj_sd >> 3);
		outs(" rto="); outdec(s->rto);
		outs("\r\n");
		}
}

/* TCP ACK has been lost. Reduce congestion window and backoff s->rto.
   Resend oldest segment, or timeout completely to closed condition. */
void
lost_ack(tcp_Socket * s)
{
				/* don't time below notimedseq seq number */
	s->notimeseq = s->seqnum + s->sdatahwater;
	s->sendqnum = 0;  	 /* flush send queue timing information */
	s->sdatahwater = 0;	/* make all bytes be new to resend all */
				/* do Van Jacobson congestion reduction */
	s->ssthresh = s->cwindow >> 1; /* new congestion threshold */
	s->cwindow = s->mss;	/* congestion window to one full pkt */
	s->loss_count = 0;	/* fast retransmit ACK pkt loss counter */

	if (s->rto == 16 * 18 * 60) /* have reached threshold of pain, quit */
		{
		if (kdebug & DEBUG_STATUS) 
		   outs(" Closing session from excessive timeout delay\r\n");
		tcp_close(s);
		return;
		}
	if (kdebug & DEBUG_STATUS) outs(" Timeout, lost ACK\r\n");
	s->rto += s->rto;			/* double timeout */
	krto(s->rto + 5 * 18); /* tell Kermit main body 5 sec minimum */
	tcp_send(s);				/* resend oldest segment */
}

/*
 * Format and send an outgoing segment.
 * Global word do_window_probe != 0 can initiate a window probe rather than 
 * a regular data transmission.
 * Sets idle timeout s->idle after each call.
 */
static int
tcp_send(tcp_Socket *s)
{
	tcp_PseudoHeader ph;
	struct pkt
		{
		in_Header in;
		tcp_Header tcp;
		word maxsegopt[2];
		} register *pkt;
	byte *dp;
	register int senddatalen, userdata;
	int sendpktlen, their_window, sendqindex;

	if (s == NULL) return (0);		/* failure */

	senddatalen = s->sdatalen - s->sdatahwater;	/* unsent bytes */
	if (senddatalen < 0)				/* sanity check */
		senddatalen = 0;

	if (s->flags & tcp_FlagSYN)		/* no s->window at SYN stage */
		goto send_packet;

	/* Closed window probe */

	if ((s->flags & tcp_FlagFIN) == 0)	/* no window probes on FIN */
		if (do_window_probe || ((s->window == 0) && senddatalen))
		{
		do_window_probe = 0;		/* clear trigger flag */
		s->send_kind = tcp_NOSEND;
				/* clear flag for tcp_retransmitter */
		if (s->winprobe)		/* if timing closed window */
			{
			if (chk_timeout(s->winprobe) != TIMED_OUT)
				return (0);	 /* can't send, still waiting*/
			else
				if ((s->probe_wait += s->probe_wait) > 60*18)
					s->probe_wait = 60 * 18;
			}
		else
			{
			s->probe_wait = s->rto << 1; /* initial probe interval */
			s->winprobe = set_ttimeout(s->probe_wait);
			return (0);		/* wait for timer to fire */
			}
		s->winprobe =  set_ttimeout(s->probe_wait); /* repeat probe */
		s->notimeseq = s->seqnum + s->sdatahwater; /* no timing */
		s->sendqnum = 0;  		 /* flush send queue timing */
		do_window_probe = 1;		/* say doing probe */
		their_window = 1;		/* pretend one open byte */
		senddatalen = 1;		/* for passive keepalive */
				/* tell Kermit main body 5 sec minimum */
		krto(s->probe_wait + 5 * 18);
		if (kdebug & DEBUG_STATUS) outs(" Window probe\r\n");
		goto send_packet;		/* bypass congestion window */
		}

	/* Nagle's condition: if have unsent data, and have data already 
	   sent but un-ACK'd, and the unsent data is of size less than one
	   MSS, and the socket is in Nagle mode then return without sending. 
	   See RFC 896. */
	/* Note: there are two approaches to measuring the amount to be
	   sent under Nagle conditions: one is the entire buffer of unsent
	   data, to be sent as whole segments and then a fractional end.
	   In this case the Nagle condition applies to the entire buffer.
	   This method makes sending larger buffers proceed with no waiting,
	   and there is a fractional segment sent at the end. This avoids
	   waiting for possibly delayed ACKs while processing this buffer,
	   unless this buffer is smaller than one segment.

	   The second approach deals with the buffer up to one MSS at a
	   time and applies the Nagle condition to each such piece
	   independently. The fractional end is held back pending arrival
	   of the awaited ACK, or supplemented to a full segment by newer
	   data later on. BSD uses this second approach and generates
	   full segments except at the end of a file. This approach makes
	   the fractional piece wait for the ACK and hence delays matters
	   considerably when the remote host uses a delayed ACK at this
	   point.
	   */

	if (senddatalen && s->sdatahwater && (senddatalen < (int)s->mss) &&
		    ((s->sock_mode & TCP_MODE_NAGLE) == TCP_MODE_NAGLE))
			senddatalen = 0;	/* block sending data */


	/* Congestion avoidance */

	/* their announced window minus bytes sent (unACK'd) from here */
	if ((their_window = s->window - s->sdatahwater) <= 0)
		senddatalen = 0; 	/* can't send data, no remote space */

	if (senddatalen > their_window)	    /* do not exceed their window */
		senddatalen = their_window;

			/* apply congestion avoidance limitation */
	userdata = s->cwindow - (s->cwindow % s->mss);	/* truncate cwindow*/
	userdata -= s->sdatahwater;		/* minus bytes already sent */
	/* cwindow is current, bytes already sent are historical, subtraction
	   to obtain userdata may be negative if cwindow shrinks */

	/* if  new data > congestion window available, limit sending */
	if (senddatalen > userdata)
		senddatalen = userdata;
 			 	/* safety in case s->cwindow shrinks on us */
	if (senddatalen < 0)
			senddatalen = 0;

	/* If data are allowed to be sent, or have an ACK to return,
	   or have a delayed ACK to return, or are sending a SYN/FIN
	   (not in sdata) then send packets. */
	if (senddatalen || s->send_kind & tcp_SENDACK ||
#ifdef DELAY_ACKS
			s->delayed_ack ||
#endif /* DELAY_ACKS */
			s->flags & (tcp_FlagSYN | tcp_FlagFIN))
		goto send_packet;

	/* else nothing to do */	
	s->send_kind = tcp_NOSEND;	/* clear trigger flag */
	return (0);

	/* Now we know how many bytes can be sent, senddatalen. Prepare
	standard TCP and IP headers, send packets. If the lan driver, ODI,
	does not become free for transmissions in a short time then abandon
	the attempt and let sdata bytes appear ready for work again by
	tcp_retransmitter. */

send_packet:

	if (odi_busy())	    	/* wait for structures to become free */
		return (0);	/* failed, try again later */

	sendqindex = s->sendqnum;	/* number of existing queue entries */
	pkt = (struct pkt *)eth_formatpacket(&s->hisethaddr[0], TYPE_IP);
	pkt->in.hdrlen_ver = 0x45;	/* version 4, hdrlen 5 */
	pkt->in.tos = 0;		/* type of service, normal */
	pkt->in.frag = 0;		/* fragment, none, allowed */
        pkt->in.ttl = 60;		/* TTL seconds */
	pkt->in.proto = TCP_PROTO;
       	pkt->in.source = htonl(my_ip_addr);
       	pkt->in.destination = htonl(s->hisaddr);
       	ph.src = pkt->in.source;	/* already in network order */
       	ph.dst = pkt->in.destination;
     	ph.mbz = 0;			/* must be zero */
       	ph.protocol = TCP_PROTO;
	pkt->tcp.srcPort = htons(s->myport);
	pkt->tcp.dstPort = htons(s->hisport);
	pkt->tcp.acknum = htonl(s->acknum);
	s->window_last_sent = TCP_RBUFSIZE - s->rdatalen;
	pkt->tcp.window = htons(s->window_last_sent);
	pkt->tcp.urgentPointer = 0;  /* not used in this program */

	while (1 == 1)
		{
		if (odi_busy())	 	/* wait for structures to become free */
			return (0);	/* failed, try again later */
		userdata = 0;			/* user data sent in this pkt*/
		dp = (byte *)pkt->maxsegopt;
				
					/* TCP header material */

		/* Set PSH bit when sending last byte of sdata buffer */
		if (senddatalen && 
			(senddatalen + s->sdatahwater >= s->sdatalen))
			s->flags |= tcp_FlagPUSH;
		else
			s->flags &= ~tcp_FlagPUSH;

		if (do_window_probe)			/* window probing */
			{
	        	pkt->tcp.seqnum = htonl(s->seqnum - 1); /* old data */
			s->flags &= ~tcp_FlagPUSH;	/* no PSH on probe */
			}
		else
        		pkt->tcp.seqnum = htonl(s->seqnum + s->sdatahwater);

        	pkt->tcp.checksum = 0;
       		pkt->tcp.flags = htons(s->flags | 0x5000); /* 5 quadbytes */
                sendpktlen = sizeof(tcp_Header) + sizeof(in_Header);

				/* do options if this is our first packet */
        	if (s->flags & tcp_FlagSYN)
			{				/* 5 + 1 quadbytes */
			pkt->tcp.flags = htons(s->flags | (0x5000 + 0x1000));
			pkt->maxsegopt[0] = 0x0402;
			pkt->maxsegopt[1] = htons(s->mss);
			sendpktlen += 4;
			dp += 4;		/* pointer to data bytes */
			}
		else
			{			/*  not a SYN packet */
			if (senddatalen > 0)	/* handle packets with data */
				{		/* limit pkt to mss */
	        		if (senddatalen > (int)s->mss)
						userdata = (int)s->mss;
				else
						userdata = senddatalen;
				if (do_window_probe == 0)
					bcopyff(&s->sdata[s->sdatahwater],
					 dp, userdata);
                		sendpktlen += userdata; /* len of this pkt */
				}
        		}
					/* Internet Packet header */
        	pkt->in.identification = htons(++ip_id); /* pre-inc req'd */
        	pkt->in.checksum = 0;
        	pkt->in.length = htons(sendpktlen);
        	pkt->in.checksum = ~checksum(&pkt->in, sizeof(in_Header));

        	/* compute TCP checksum, ph is pseudo header pointer */
        	ph.length = htons(sendpktlen - sizeof(in_Header));
        	ph.checksum = checksum(&pkt->tcp, 
				sendpktlen - sizeof(in_Header));
        	pkt->tcp.checksum = ~checksum(&ph, sizeof(ph));

	/* Send the packet before recording timeout information so the
	   time of slow transmissions (serial) don't confuse s->rto from
	   variable length packets. Failure to transmit will leave
	   s->send_kind intact, and hence cause retransmission. */

		if (eth_send(htons(pkt->in.length)) == 0) /* send packet */
			{				/* here if failed */
			if (kdebug & DEBUG_STATUS)
				outs(" Failed to put packet on wire\r\n");
			do_window_probe = 0;
		  	return (0);			/* sending failed */
			}

		s->delayed_ack = 0;		/* cancel delayed ACKs */

		if (do_window_probe)
			{
			do_window_probe = 0; 	/* finished construction */
			break;			/* no per-packet timing */
			}
		s->sdatahwater += userdata;	/* move have-sent-once marker */
						/* must be before timing */
/* Remember each TCP segments's ending sequence number and time of 
   transmission in sendq so that round trip time can be measured per 
   TCP segment, and so that we can timeout waiting for an ACK to sent data.
   If there are more outstanding segments than sendq entries reuse the last
   sendq slot for the most recent segment. No sendq entry created if no data.
*/
		if (userdata || (s->flags & (tcp_FlagSYN | tcp_FlagFIN)))
			{
						/* when sent, for rtt */
			s->sendq[sendqindex].time_sent = set_ttimeout(0);
						/* when segment times out */
			s->sendq[sendqindex].timeout =
				(s->rto < 18 * 60)?
				set_ttimeout(s->rto):
				set_timeout(60);	/* 60 sec max */
						/* seq number of next dgram */
			s->sendq[sendqindex].next_seq = s->seqnum + 
							s->sdatahwater;
			if (s->flags & tcp_FlagFIN)  /* cover FIN bit too */
				s->sendq[sendqindex].next_seq++;
			sendqindex++;
			if (sendqindex < NSENDQ - 1)	/* next slot open? */
				s->sendqnum = sendqindex;	/* yes */
			else
				sendqindex--;		/* no, reuse last */
			}
		senddatalen -= userdata;	/* qty user data yet to send */
		if (senddatalen <= 0)		/* if have sent all data */
			break;
	}					/* do next IP packet */

	s->idle = (4 + s->rto < 18 * 60)?
		set_ttimeout(s->rto + 4):	/* inactivity timer */
		set_timeout(60);		/* 60 sec max */
	if (s->keepalive)		/* passive open keepalive timer */
		s->keepalive = set_timeout(100); 	/* keepalive */
	s->send_kind = tcp_NOSEND;	/* clear flag for tcp_retransmitter */
	return (1);				/* success */
}

/*
 * Format and send a reset tcp packet
 */
int
tcp_rst(in_Header *his_ip, tcp_Header FAR * oldtcpp)
{
	tcp_PseudoHeader ph;
	struct pkt
		{
        	in_Header in;
        	tcp_Header tcp;
		word maxsegopt[2];
		} register *pkt;
	eth_address eth_addr;				/* six byte array */
	register int sendtotlen;			/* length of packet */

	if (his_ip == NULL || oldtcpp == NULL) return (0);	/* failure */

	while (odi_busy()) ;	/* wait for data structures to become free */
					/* see RFC 793 page 65 for details */
	oldtcpp->flags = ntohs(oldtcpp->flags);		/* net to local */

	if (oldtcpp->flags & tcp_FlagRST)		/* if a RST to us */
		return (0);  
	if ((oldtcpp->flags & tcp_FlagACK) == 0)
	        oldtcpp->flags = tcp_FlagACK;
	else
        	oldtcpp->flags = 0;
	/* get MAC addr */
 	if (arp_resolve(htonl(his_ip->source), &eth_addr[0]) == 0)
		return (0);				/* failed */
	pkt = (struct pkt *)eth_formatpacket(&eth_addr[0], TYPE_IP);
	sendtotlen = sizeof(tcp_Header) + sizeof(in_Header);
	pkt->in.length = htons(sendtotlen);
					/* TCP header */
	pkt->tcp.srcPort = oldtcpp->dstPort;
	pkt->tcp.dstPort = oldtcpp->srcPort;
	pkt->tcp.seqnum = oldtcpp->acknum;
	pkt->tcp.acknum = htonl(ntohl(oldtcpp->seqnum) + 1);
	pkt->tcp.window = 0;
	pkt->tcp.flags = htons(tcp_FlagRST | oldtcpp->flags | 0x5000);
	pkt->tcp.checksum = 0;
	pkt->tcp.urgentPointer = 0;
					/* Internet header */
	pkt->in.hdrlen_ver = 0x45;		/* version 4, hdrlen 5 */
	pkt->in.tos = 0;
	pkt->in.identification = htons(++ip_id); /* use pre-inc here */
	pkt->in.frag = 0;
	pkt->in.ttl = 60;			/* time to live */
	pkt->in.proto = TCP_PROTO;
	pkt->in.checksum = 0;
	pkt->in.source = his_ip->destination;
	pkt->in.destination = his_ip->source;
	pkt->in.checksum = ~checksum(&pkt->in, sizeof(in_Header));
						/* compute TCP checksum */
	ph.src = pkt->in.source;		/* already big endian */
	ph.dst = pkt->in.destination;
	ph.mbz = 0;				/* must be zero */
	ph.protocol = TCP_PROTO;
	ph.length = htons(sendtotlen - sizeof(in_Header));
	ph.checksum = checksum(&pkt->tcp, sendtotlen - sizeof(in_Header));
	pkt->tcp.checksum = ~checksum(&ph, sizeof(ph));
	return (eth_send(htons(pkt->in.length)));
}

/* Handle ICMP Redirects. ICMP processor yields new gateway IP number
   in "gateway" and pointer to offending IP header which we have sent.
   Find socket with destination IP address matching the gateway
   sending us the Redirect message, replace the socket's destination
   Ethernet address with that of the new gateway (use arp_resolve).
   For TCP resend the packet, for UDP give up all hope.
*/
void
do_redirect(longword gateway, in_Header *ip)
{
	register udp_Socket *s_udp;
	register tcp_Socket *s_tcp;
	tcp_Header *tp;
	int len;
	longword host;

	len = in_GetHdrlenBytes(ip);
	tp = (tcp_Header *)((byte *)ip + len);	/* tcp frame pointer */
	host = ntohl(ip->destination);		/* destination IP */

	switch(ip->proto)
		{
		case TCP_PROTO:		/* active TCP sockets */
		for (s_tcp = tcp_allsocs; s_tcp != NULL; s_tcp = s_tcp->next)
			if ((host == s_tcp->hisaddr) &&	/* if same dest IP */
				(ntohs(tp->srcPort) == s_tcp->myport))
								/* & port */
				{
				arp_resolve(gateway, &s_tcp->hisethaddr[0]);
				tcp_send(s_tcp);	/* resend the packet */
				}
			break;
		case UDP_PROTO:			/* active UDP sockets */
		for (s_udp = udp_allsocs; s_udp != NULL; s_udp = s_udp->next)
			if ((host == s_udp->hisaddr) &&
				(ntohs(tp->srcPort) == s_udp->myport))
				arp_resolve(gateway, &s_udp->hisethaddr[0]);
			break;
		}
}

/* Handle ICMP Source Quench. Increase timeouts as if lost packet.
*/
void
do_quench(in_Header *ip)
{
	register tcp_Socket *s_tcp;
	register tcp_Header *tp;
	int len;
	longword host;

	len = in_GetHdrlenBytes(ip);
	tp = (tcp_Header *)((byte *)ip + len);	/* tcp frame pointer */
	host = ntohl(ip->destination);		/* destination IP */

	if (ip->proto != TCP_PROTO)
		return;

	for (s_tcp = tcp_allsocs; s_tcp != NULL; s_tcp = s_tcp->next)
		if ((host == s_tcp->hisaddr) &&		/* if same dest IP */
		    (ntohs(tp->srcPort) == s_tcp->myport))	/* & port */
			{
			s_tcp->rto++;		/* one Bios clock tick */
			s_tcp->ssthresh = 0;	/* return to slow start */
			s_tcp->cwindow = s_tcp->mss;
			break;
			}
}

/**********************************************************************
 * socket functions
 **********************************************************************/

/* socket based procedures */

/*
 * sock_setmode - set mode bit to true or false
 */
int
sock_setmode(tcp_Socket *s, word mode, word value)
{
	if (s == NULL)
		return (0);
	if (value == TRUE)
		s->sock_mode |= mode;
	else
		s->sock_mode &= ~mode;
	return (1);		/* success */
}

/*
 * sock_read - read a socket with maximum n bytes
 *	     - returns count also when connection gets closed
 */
int
sock_read(sock_type *s, byte FAR *dp, int len)
{
	register int templen, count;
	count = 0;

	if (s == NULL || dp == NULL) return (0);		/* failure */
	do    	{
		switch (s->tcp.ip_type)
			{
			case UDP_PROTO:
				templen = udp_read((udp_Socket *)s, dp, len);
				break;
			case TCP_PROTO:
				templen = tcp_read((tcp_Socket *)s, dp, len);
				if (templen == 0 && 
					s->tcp.sisopen == SOCKET_CLOSED)
						return (count); /*quit early*/
				break;
			default: return (0);
			}
		count += templen;
		len -= templen;
    		}
	while (len > 0);
   	return (count);
}

/*
 * sock_fastread - read a socket with maximum n bytes
 *	     - does not busywait until buffer is full
 */
int
sock_fastread(sock_type *s, byte FAR *dp, int len)
{
	if (s == NULL)  return (0);		/* failure */
	switch(s->tcp.ip_type)
		{
		case UDP_PROTO:
			return (udp_read((udp_Socket *)s, dp, len));
		case TCP_PROTO:
			return (tcp_read((tcp_Socket *)s, dp, len));
		default: return (0);
		}
}


/*
 * sock_write - writes data and returns length written
 */
sock_write(sock_type *s, byte FAR *dp, int len)
{
	if (s == NULL || dp == NULL) return (0);	/* failure */

	switch (s->tcp.ip_type)
		{
		case UDP_PROTO:
			return (udp_write((udp_Socket *)s, dp, len));
		case TCP_PROTO:
			return (tcp_write((tcp_Socket *)s, dp, len));
		default: return (0);
		}
}

/*
 * sock_dataready - returns number of bytes waiting to be read
 */
word 
sock_dataready(sock_type *s)
{
	if (s == NULL) 
		return (0);
        return (s->tcp.rdatalen);
}

int
sock_established(sock_type *s)
{
	if (s == NULL) return (0);			/* failure */
	switch (s->tcp.ip_type)
		{
		case UDP_PROTO:
			return (1);
		case TCP_PROTO:
			return (s->tcp.state == tcp_StateESTAB);
		default:
			return (0);
		}
}

int
sock_close(sock_type *s)
{
	register int status;

	if (s == NULL) return (0);			/* failure */
	tcp_tick(s);			/* process any last packets */
	switch (s->tcp.ip_type)
		{
		case UDP_PROTO:
			status = udp_close((udp_Socket *)s);
			break;
		case TCP_PROTO:
			status = tcp_close((tcp_Socket *)s);
			while ((tcp_Socket *)s->tcp.sisopen != SOCKET_CLOSED)
				tcp_tick(s);	/* do protocol close */
			break;
		default:
			return (0);
		}
	return (status);					/* success */
}

void 
sock_abort(sock_type *s)
{
	if (s == NULL) return;			/* do nothing */
	switch (s->tcp.ip_type)
		{
		case TCP_PROTO:
			tcp_abort((tcp_Socket *)s);
			break;
		case UDP_PROTO:
			udp_close((udp_Socket *)s);
			break;
		}
}

/*
 * ip_delay0 called by macro sock_wait_established()
 * ip_delay1 called by macro sock_wait_input()
 * ip_delay2 called by macro sock_wait_closed();
 *
 */

ip_delay0(sock_type *s, int timeoutseconds, procref fn, int *statusptr)
{
	register int status;
	longword timeout;

	if (s == NULL)
		{
		status = -1;		/* failure */
    		if (statusptr != NULL) *statusptr = status;
		return (status);
		}
	timeout = set_timeout(timeoutseconds);
	do
		{
		if (s->tcp.ip_type == TCP_PROTO)
			if (s->tcp.state == tcp_StateESTAB)
				{
				status = 0;
				break;
				}
		if (tcp_tick(s) == SOCKET_CLOSED)
			{
			status = -1;	/* get an early reset */
			break;
			}

		if (chk_timeout(timeout) == TIMED_OUT)
			{
			sock_close(s);
			status = -1;
			break;
			}
		if (fn != NULL) 
			if (status = fn(s, NULL, 0)) break;
		if (s->tcp.ip_type == UDP_PROTO)
			{
			status = 0;
			break;
			}
		if (chkcon())			/* check console for ^C */
			{
			status = -1;		/* a failure */
			while (chkcon()) ;	/* soak up ^C's */
			break;
			}
		} while (1 == 1);
	if (statusptr != NULL) *statusptr = status;
	return (status);
}

int
ip_delay1(sock_type *s, int timeoutseconds, procref fn, int *statusptr)
{
	register int status;
	longword timeout;

	if (s == NULL)
		{
		status = -1;		/* failure */
    		if (statusptr != NULL) *statusptr = status;
		return (status);
		}

	timeout = set_timeout(timeoutseconds);

	do
		{
		if (sock_dataready(s))
			{
			status = 0;
			break;
			}

		if (tcp_tick(s) == SOCKET_CLOSED)
			{
			status = 1;
			break;
			}
		if (chk_timeout(timeout) == TIMED_OUT)
			{
			sock_close(s);
			status = -1;
			break;
			}
		if (fn != NULL)
			if (status = fn(s, NULL, 0)) break;
		} while (1 == 1);

	if (statusptr != NULL) *statusptr = status;
	return (status);
}

int
ip_delay2(sock_type *s, int timeoutseconds, procref fn, int *statusptr)
{
	register int status;
	longword timeout;

	if (s == NULL)
		{
		status = 0;		/* failure */
    		if (statusptr != NULL) *statusptr = status;
		return (status);
		}

	timeout = set_timeout(timeoutseconds);

	if (s->tcp.ip_type != TCP_PROTO) return (1);

	do
		{
		if (tcp_tick(s) == SOCKET_CLOSED) 	/*  no socket */
			{
			status = 1;
			break;
			}
		if (chk_timeout(timeout) == TIMED_OUT)
			{
			sock_abort(s);
			status = 0;
			break;
			}
		if (fn != NULL)
			if (status = fn(s, NULL, 0)) break;
		} while (1 == 1);

	if (statusptr != NULL) *statusptr = status;
	return (status);
}
