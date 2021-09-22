/* File MSNBTP.C
 * Bootp requestor
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
 * Rewritten and extended for MS-DOS Kermit by Joe R. Doupnik, 
 *  Utah State University, jrd@cc.usu.edu, jrd@usu.Bitnet.
 *
 * Last edit
 * 31 Oct 2000 v3.16
 *
 *   BOOTP - Boot and DHCP Protocols, RFCs 951, 1048, 1395, 1531, 1541, 1533
 *   and successors 2131 and 2132.
 */

#include "msntcp.h"
#include "msnlib.h"

/*
 * structure for send and receives
 */
typedef struct bootp {
	byte	 bp_op;		/* packet op code / message type. */
	byte	 bp_htype;	/* hardware address type, 1 = Ethernet */
	byte	 bp_hlen;	/* hardware address len, eg '6' for Ethernet*/
	byte	 bp_hops;	/* client sets to zero, optionally used by
				   gateways in cross-gateway booting. */
	longword bp_xid;	/* transaction ID, a random number */
	word	 bp_secs;	/* filled in by client, seconds elapsed since
				   client started trying to boot. */
	word	 bp_flags;	/* DHCP flags */
	longword bp_ciaddr;	/* client IP address filled in by client */
				/*  if known */
	longword bp_yiaddr;	/* 'your' (client) IP address
				   filled by server if client doesn't know */
	longword bp_siaddr;	/* server IP address returned in bootreply */
	longword bp_giaddr;	/* gateway IP address,
				   used in optional cross-gateway booting. */
	byte	 bp_chaddr[16];	/* client hardware address, filled by client */
	byte	 bp_sname[64];	/* optional server host name, null terminated*/

	byte	 bp_file[128];	/* boot file name, null terminated string
				   'generic' name or null in bootrequest,
				   fully qualified directory-path
				   name in bootreply. */
	byte	 bp_vend[64+248]; /* 64 vendor-specific area + 248 DHCP */
};

/* UDP port numbers, server and client */
#define	IPPORT_BOOTPS	67
#define	IPPORT_BOOTPC	68

/* bootp.bp_op */
#define BOOTREQUEST 	1
#define BOOTREPLY	2

/* DHCP values from RFC 1531, RFC 1533 et seq. */
/* Command codes, option type 53, single octet of data */
#define	DHCPDISCOVER   1
#define	DHCPOFFER      2
#define	DHCPREQUEST    3
#define	DHCPDECLINE    4
#define	DHCPACK	       5
#define	DHCPNAK	       6
#define	DHCPRELEASE    7
#define DHCPINFORM     8
#define DHCPRENEWING	100

/* DHCP command code, 53 decimal */
#define DHCP_COMMAND	53
#define OPTION_SERVERID 54
#define OPTION_END	255

#define VM_RFC1048   0x63538263L	/* magic cookie for BOOTP */
#define BOOTPTIMEOUT 30			/* seconds timeout to do bootup */

static longword DHCP_server_IP;		/* IP of DHCP server */
static long DHCP_lease, DHCP_renewal, DHCP_rebind;
static byte DHCP_state;
static longword xid;			/* opaque msg ident */
static use_RFC2131;			/* Use RFC2131 REQUESTs */

/* Values for request_busy word */
#define REQ_IDLE 0			/* have not sent datagram yet */
#define REQ_SENT 1			/* have sent datagram */
#define REQ_BUSY 4			/* request() has not exited yet */
int request_busy = REQ_IDLE;		/* DHCP request() lock */

/* global variables */
longword bootphost = 0xffffffffL;	/* broadcast IP */

byte hostname[MAX_STRING+1] = {0};	/* our fully qualified IP name */
extern word arp_hardware, MAC_len;	/* media details from msnpdi.asm */
extern byte kdomain[];			/* our IP domain string */
extern byte kbtpserver[];		/* IP of responding server */
extern	eth_address eth_addr;		/* six byte array */
extern	byte kdebug;			/* general debugging kind control */
extern  char tcpflag;			/* from msntni.asm, 2 if doing Int 8*/
extern	byte bootmethod;		/* which boot techinque to try */

static int status;			/* return value from request() */
static longword master_timeout;		/* hard shutdown grace interval */
static longword sendtimeout;		/* timeout between sends */
static longword readtimeout;		/* timeout for reading */
static word magictimeout = 1;		/* current read timeout interval */
struct bootp bootppkt, *bp = &bootppkt;	/* Bootp/DHCP structure */
static udp_Socket bsock;		/* UDP socket structure */

static int request(void);		/* send request, decode reply */
static void decode(struct bootp *, int);	/* decode Options */
static int notdhcp(struct bootp *, int);	/* detect DHCP pkt */
static int tasksr(void);		/* task level send/receive */
static int bootptick(void);		/* worker for tasksr */

/*
 * do_bootp - Do Bootp or DHCP negotiations.
 *             returns 0 on success and sets ip address
 */

int 
do_bootp()
{
	outs("\r\n Requesting a ");
	if (bootmethod == BOOT_BOOTP)
		outs("Bootp server ");
	else	outs("DHCP server ");

	bootphost = 0xffffffffL;	/* broadcast IP */
	my_ip_addr = 0L;		/* init our IP address to unknown */
	DHCP_server_IP = 0L;		/* DHCP server IP address, 0 = none */
	DHCP_lease = 0L;		/* no lease expiration */
	DHCP_state = DHCPDISCOVER;	/* discover a DHCP server */
	request_busy = REQ_IDLE;	/* request() lock, unlock it */
	master_timeout = 0;		/* kill hard shutdown timer */
	kbtpserver[0] = 0;		/* found server's IP address */
	xid = htonl(set_timeout(0));	/* set xid as tod in Bios ticks */
	if (tasksr() == -1)		/* do send receives */
		return (-1);		/* fail */

	if (DHCP_server_IP == 0L)	/* no DHCP response, use Bootp */
		{
		bootmethod = BOOT_BOOTP;
		return (my_ip_addr != 0? 0: -1); /* -1 for fail, 0 for succ */
		}

					/* DHCP negotiations, continued */
	DHCP_lease = 0L;		/* no lease expiration, yet */
	bootmethod = BOOT_DHCP;
	DHCP_state = DHCPREQUEST;	/* set conditions for request() */
	xid++;		/* change id tag so competing responses are ignored */
	use_RFC2131 = 1;		/* use revision RFC2131 of DHCP */
	if (tasksr() == -1)		/* do send receives */
		return (-1);		/* fail */
	if (DHCP_state == DHCPNAK	/* if Request refused */
		&& use_RFC2131)		/* and we used new style request */
		{
		use_RFC2131 = 0;	/* try again with RFC1541 style */
		DHCP_state = DHCPREQUEST; /* set conditions for request() */
		if (tasksr() == -1)		/* do send receives */
			return (-1);		/* fail */
		}

	use_RFC2131 = 1;		/* reset for next attempt */
	if (DHCP_state != DHCPACK)
		return (-1);		/* failure to negotiate DHCP */
	bootphost = DHCP_server_IP;	/* only now remember server */
	return (my_ip_addr != 0? 0: -1); /* -1 for failure, 0 for success */
}

/* Run at task level, not from Int 8. Do timed send and receives, with
   checking for aborts by Control-C and net failure. Calls tcp_tick()
   to read fresh packets.
*/
int
tasksr(void)
{
			/* send/process DHCP REQUEST and ACK*/
		sendtimeout = set_timeout(BOOTPTIMEOUT);
		magictimeout = 1;
		bootptick();		/* check for aborts, do send/receive*/
		while (request_busy != REQ_IDLE)
			status = bootptick();
		if (status == -1)
			return (-1);		/* fail */
		return 0;
}

/* worker for tasksr(). Does its work minus the timed retries. */
int
bootptick(void)
{
	/* if not running from Int 8 background tick, check keyboard */
	if (tcpflag != 2 && chkcon() != 0)	/* Control-C abort */
		{
		outs(" Canceled by user");
		sock_close(&bsock);
		request_busy = REQ_IDLE;	/* done */
		return (-1);			/* failing status */
		}

	/* if no data yet and not running from Int 8 background tick */
	if (bsock.rdatalen == 0 && tcpflag != 2 &&
		bsock.sisopen == SOCKET_OPEN) 
		if (tcp_tick(&bsock) == 0)		/* read packets */
			{		/* major network error if UDP fails */
			outs(" Network troubles, quitting");
			sock_close(&bsock);
			request_busy = REQ_IDLE;	/* unlock access */
			return (-1);			/* fail */
			}
	return (request());			/* do send/receives */
}

/* Request Bootp/DHCP information and decode responses
   This can be called at task level by do_bootp(), and at Int 8 background
   level via DHCP_refresh(). To prevent reentrancy problems request_busy sets
   the REQ_BUSY bit. To keep state on whether we need to transmit or receive
   bit REQ_SENT is used to say have transmitted so instead do receive code.
   Flag byte tcpflag value of 2 (from msntni.asm) means we are running from
   Int 8 and may not do calls to the Bios or DOS and we must be fast.
*/
static int
request(void)
{
	int reply_len;

/* if have sent datagram and receive waiting has time to go, then receive */	

	request_busy |= REQ_BUSY;	/* say we have entered request() */

	if (request_busy & REQ_SENT && chk_timeout(readtimeout) != TIMED_OUT)
		goto inprogress;	/* not timed out reading */

	if (chk_timeout(sendtimeout) == TIMED_OUT) /* sent for too long */
		{			/* failed attempt, no respondent */
		sock_close(&bsock);
		request_busy = REQ_IDLE;
		return (-1);				/* fail */
		}

	memset((byte *)bp, 0, sizeof(struct bootp));

	bp->bp_op = BOOTREQUEST;
	bp->bp_htype = (byte)(arp_hardware & 0xff); /* hardware type */
	bcopy(eth_addr, bp->bp_chaddr, MAC_len); /* hardware address */
	bp->bp_hlen = (byte) MAC_len;		/* length of MAC address */
	bp->bp_xid = xid;			/* identifier, opaque */
	bp->bp_ciaddr = htonl(my_ip_addr);	/* client IP identifier */
	*(long *)&bp->bp_vend[0] = VM_RFC1048;	/* magic cookie longword */
	bp->bp_vend[4] = OPTION_END;		/* end of Options, BOOTP */

	if (bootmethod == BOOT_DHCP)		/* DHCP details */
		{
		bp->bp_vend[4] = DHCP_COMMAND;	/* option, DHCP command */
		bp->bp_vend[5] = 1;		/* length of value */
		bp->bp_vend[6] = DHCPREQUEST;	/* Request data */
		bp->bp_vend[7] = OPTION_END;	/* end of Options */
		if (DHCP_state == DHCPDISCOVER)	/* if first probe */
			{
			bp->bp_flags = htons(1); /* set DHCP Broadcast bit */
			bp->bp_vend[6] = DHCPDISCOVER; /* DHCP server discov*/
			}
		if (DHCP_state == DHCPREQUEST)	/* if Request, not Renewal */
			{
			bp->bp_vend[7] = OPTION_SERVERID; /* server id */
			bp->bp_vend[8] = 4;		/* length of value */
			*(long *)&bp->bp_vend[9] = htonl(DHCP_server_IP);
			bp->bp_vend[13] = OPTION_END;	/* end of Options */
			if (use_RFC2131)	  /* if not using RFC1541 */
				{
				bp->bp_ciaddr = 0; /* no client identifier */
				bp->bp_vend[13] = 50;	/* Requested IP Addr*/
				bp->bp_vend[14] = 4;	/* length of value */
						/* our IP address goes here */
				*(long *)&bp->bp_vend[15] = htonl(my_ip_addr);
				bp->bp_vend[19] = OPTION_END;
				}
			my_ip_addr = 0;     /* now forget IP from DISCOVER */
			}
		}

	if (bsock.sisopen == SOCKET_OPEN) 
		sock_close(&bsock);			/* just in case */
	if (udp_open(&bsock, IPPORT_BOOTPC, bootphost, IPPORT_BOOTPS) == 0)
		{
		request_busy = REQ_IDLE;		/* clear lock */
		sock_close(&bsock);
       		return (-1);				/* fail */
		}

		/* send only bootp length requests, accept DHCP replies */
						/* send datagram */
	bsock.rdatalen = 0;			/* clear old received data */
	sock_write(&bsock, (byte *)bp, sizeof(struct bootp) - 248);
	readtimeout = set_timeout(magictimeout++); /* receiver timeout */
	if (magictimeout > 8)
		magictimeout = 8;		/* truncate waits */
	if (bootmethod == BOOT_BOOTP || DHCP_state == DHCPDISCOVER)
		outs(".");			/* progress indicator */
	request_busy = REQ_SENT;		/* exiting but not done */
	return (-1);			/* next call does reading thread */

inprogress:			/* here we read UDP responses */

	reply_len = sock_fastread(&bsock, (byte *)bp, 
						sizeof(struct bootp));

	if ((reply_len < sizeof(struct bootp) - 248) || /* too short */
	    (bp->bp_xid != xid) ||			/* not our ident */
	    (bp->bp_yiaddr == 0) ||		/* no IP address for us */
	    (*(long *)&bp->bp_vend != VM_RFC1048) ||	/* wrong vendor id */
	    (bootmethod == BOOT_DHCP && DHCP_state != DHCPDISCOVER &&
			(DHCP_server_IP != ntohl(bp->bp_siaddr) ||
			notdhcp(bp, reply_len))) )
			/* no DHCP server IP, no DHCP msg */
		{
		request_busy = REQ_SENT; 		/* not done yet */
		return (-1);		/* not a required DHCP response */
		}

	decode(bp, reply_len);		/* extract response data */

	if (my_ip_addr == 0L)		/* if first time through */
		{
		my_ip_addr = ntohl(bp->bp_yiaddr); /* bootp header */
		if (DHCP_server_IP == 0) 	/* if no DHCP server addr */
			ntoa(kbtpserver, ntohl(bp->bp_siaddr)); /* bootp */
		else
			ntoa(kbtpserver, DHCP_server_IP); /* decode() swaps */
		}
	sock_close(&bsock);
	request_busy = REQ_IDLE;		/* done processing */
	return (my_ip_addr != 0? 0: -1); /* -1 for fail, 0 for success */
}

/* Return zero if reply contains a DHCP Command, else return non-zero */
static int
notdhcp(struct bootp * bp, int reply_len)
{
	byte *p, *q;

	p = &bp->bp_vend[4];		/* Point just after magic cookie */
	q = &bp->bp_op + reply_len;	/* end of all possible vendor data */

	while (*p != 255 && (q - p) > 0)
		switch(*p)
		{
                case 0: 		/* Nop Pad character */
                	p++;
                	break;
		case 53:		/* DHCP Command from server */
			return (0);
		case 255:		/* end of options */
			return(1);
		default:
		  	p += *(p+1) + 2; /* skip other options */
			break;
                  }
	return(1);
}

/* Decode Bootp/DHCP Options from received packet */
static void
decode(struct bootp * bp, int reply_len)
{
	byte *p, *q;
	word len;
	longword tempip;
	extern word arp_last_gateway;	/* in msnarp.c */
	extern int last_nameserver;	/* in msndns.c */

	p = &bp->bp_vend[4];		/* Point just after magic cookie */
	q = &bp->bp_op + reply_len;	/* end of all possible vendor data */

	while (*p != 255 && (q - p) > 0)
		switch(*p)
		{
                case 0: /* Nop Pad character */
                	p++;
                	break;
		case 1: /* Subnet Mask */
			sin_mask = ntohl(*(longword *)(&p[2]));
			p += *(p+1) + 2;
			break;
		case 3: /* gateways */
			arp_last_gateway = 0; 		/* clear old values */
			for (len = 0; len < *(p+1); len += 4)
			  arp_add_gateway(NULL,ntohl(*(longword*)(&p[2+len])));
			p += *(p+1) + 2;
			break;
		case 6: /* Domain Name Servers (BIND) */
			last_nameserver = 0;		/* clear old values */
			for (len = 0; len < *(p+1); len += 4)
		    	add_server(&last_nameserver, MAX_NAMESERVERS,
			def_nameservers, ntohl(*(longword*)(&p[2 + len])));
			p += *(p+1) + 2;
			break;
		case 12: /* our hostname, hopefully complete */
			bcopyff(p+2, hostname, (int)(p[1] & 0xff));
			hostname[(int)(p[1] & 0xff)] = '\0';
			p += *(p+1) + 2;
			break;
		case 15: /* RFC-1395, Domain Name tag */
			bcopyff(p+2, kdomain, (int)(p[1] & 0xff));
			kdomain[(int)(p[1] & 0xff)] = '\0';
			p += *(p+1) + 2;
			break;

		case 51:	/* DHCP Offer lease time, seconds */
			if (p[1] == 4)
				{
				DHCP_lease = ntohl(*(longword*)(&p[2]));
				if (DHCP_lease == -1L)	/* -1 is infinite */
					DHCP_lease = 0;	/* no timeout */
				else
					{
					if (DHCP_lease > 0x0ffffL)
						DHCP_lease = 0x0ffffL;

					DHCP_lease = set_timeout((int)(0xffff 
						& DHCP_lease));
					}
				/* below: safety if server does not state */
				if (DHCP_renewal == 0L)
					DHCP_renewal = DHCP_lease;
				if (DHCP_rebind == 0L)
					DHCP_rebind = DHCP_lease;
				}
			p += *(p+1) + 2;
			break;

		case 53:	/* DHCP Command from server */
			DHCP_state = p[2];	/* Command, to local state */
			p += *(p+1) + 2;
			break;
		case 54:	/* DHCP server IP address */
			if (p[1] == 4)
				if (tempip = *(longword*)(&p[2]))
					DHCP_server_IP = ntohl(tempip);
			p += *(p+1) + 2;
			break;
		case 58:	/* DHCP lease renewal time (T1) */
			if (p[1] == 4)
				{
				DHCP_renewal = ntohl(*(longword*)(&p[2]));
				if (DHCP_renewal == -1L)
					DHCP_renewal = 0;	/* no timeout */
				else
				     {
				     if (DHCP_renewal > 0x0ffffL)
						DHCP_lease = 0x0ffffL;
				     DHCP_renewal = set_timeout((int)(0xffff & 
						DHCP_renewal));
				     }
				}
			p += *(p+1) + 2;
			break;
		case 59:	/* DHCP rebind time (T2) */
			if (p[1] == 4)
				{
				DHCP_rebind = ntohl(*(long*)(&p[2]));
				if (DHCP_rebind > 0x0ffffL)
					DHCP_rebind = 0x0ffffL;
				DHCP_lease = DHCP_rebind =
				set_timeout((int)(0xffff & DHCP_rebind));
				}
			p += *(p+1) + 2;
			break;

		case 255:	/* end of options */
			break;
		default:
		  	p += *(p+1) + 2;
			break;
                  } 			/* end of switch */
}

/* Release DHCP granted IP information. Skip if DHCP ACK has not been
   received or if lease time is infinite (to help Novell's DHCP v2.0
   from clobbering itself with erasure of permanent assignments).
*/
void
end_bootp(void)
{
	longword wait;

	if (bootmethod != BOOT_DHCP)
		return;				/* not using DHCP */

	if (DHCP_lease == 0)			/* infinite lease */
		return;

	memset((byte *)bp, 0, sizeof(struct bootp));

	udp_open(&bsock, IPPORT_BOOTPC, bootphost, IPPORT_BOOTPS);
	bp->bp_op = BOOTREQUEST;
	bp->bp_htype = (byte)(arp_hardware & 0xff);
	bcopy(eth_addr, bp->bp_chaddr, MAC_len);
	bp->bp_hlen = (byte) MAC_len;		/* length of MAC address */
	bp->bp_xid = ++xid;
	*(long *)&bp->bp_vend[0] = VM_RFC1048;	/* magic cookie longword */
	bp->bp_vend[4] = DHCP_COMMAND;	/* option, DHCP command */
	bp->bp_vend[5] = 1;		/* length of value */
	bp->bp_vend[6] = DHCPRELEASE;	/* value, release DHCP server */
	bp->bp_vend[7] = OPTION_SERVERID; /* server identification */
	bp->bp_vend[8] = 4;		/* length of IP address */
	*(long *)&bp->bp_vend[9] = htonl(DHCP_server_IP);
	bp->bp_vend[13] = OPTION_END;	/* end of options */

	sock_write(&bsock, (byte *)bp, sizeof(struct bootp) - 248);
	wait = set_ttimeout(1);		/* one Bios clock tick */
	while (chk_timeout(wait) != TIMED_OUT) ;	/* pause */
							/* repeat */
	sock_write(&bsock, (byte *)bp, sizeof(struct bootp) - 248);
	sock_close(&bsock);

 	DHCP_server_IP = 0L;		/* DHCP server IP address, 0 = none */
	DHCP_lease = 0L;		/* no lease expiration */
	DHCP_state = DHCPDISCOVER;
	my_ip_addr = 0L;		/* lose our IP address too */
}

/* Renew DHCP lease on our IP address. Skip if lease is infinite and if
   renewal has not timed out. DHCP_renewal is Bios time of day when renewal
   is needed; DHCP_lease is Bios time of day of lease (0 means infinite).
*/
int
DHCP_refresh()
{
	longword temp;

	if (request_busy & REQ_BUSY)
		return (0);			/* request() not exited yet */
	if (DHCP_lease == 0 ||			/* infinite lease */
		chk_timeout(DHCP_renewal) != TIMED_OUT)
		return (0);			/* nothing to do yet */
	if (master_timeout)			/* shutting down hard */
		if (chk_timeout(master_timeout) == TIMED_OUT)
			return (-1);		/* fail, shuts down stack */
		else
			return (0);		/* still in grace interval */

	DHCP_state = DHCPRENEWING;		/* set new state */
	sendtimeout = set_timeout(BOOTPTIMEOUT); /* sending timeout limit */
	magictimeout = 1;			/* one second */
	status = request();			/* send and read replies */
	if (request_busy != REQ_IDLE)
		return (0);			/* not done yet */

	if (status == 0)			/* if success */
		{
		if (DHCP_lease == 0 ||		/* infinite lease */
		chk_timeout(DHCP_renewal) != TIMED_OUT) /* lease renewed */
			return (0);		/* success, lease renewed */
		}

	outs("\r\n Failed to renew DHCP IP address lease");
	outs("\r\n Shutting down TCP/IP system in ");
	temp = DHCP_lease - set_ttimeout(0);	/* ticks from now */
	temp = ourldiv(temp, 18);		/* ticks to seconds */
	outdec((word)temp & 0xffff);
	outs(" seconds!\7\r\n");
	master_timeout = DHCP_lease;		/* set master shutdown */
	return (0);				/* stay alive for now */
}
