/* File MSNICM.C
 * ICMP packet processor
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
 *  Utah State University, jrd@cc.usu.edu, jrd@usu.Bitnet.
 *
 * Last edit
 * 31 Oct 2000 v3.16
 */
#include "msntcp.h"
#include "msnlib.h"

/*
 * ICMP - RFC 792
 */

static byte *unreach[] = {
	"Network Unreachable",
	"Host Unreachable",
	"Protocol Unreachable",
	"Port Unreachable",
	"Fragmentation needed and DF set",
	"Source Route Failed"
};

static byte *exceed[] = {
	"TTL exceeded in transit",
	"Frag ReAsm time exceeded"
};

static byte *redirect[] = {
	"Redirect for Network",
	"Redirect for Host",
	"Redirect for TOS and Network",
	"Redirect for TOS and Host"
};

typedef struct icmp_unused {
	byte 	type;
	byte	code;
	word	checksum;
	longword	unused;
	in_Header	ip;
	byte	spares[ 8 ];
};

typedef struct icmp_pointer {
	byte	type;
	byte	code;
	word	checksum;
	byte	pointer;
	byte	unused[ 3 ];
	in_Header	ip;
};
typedef struct icmp_ip {
	byte	type;
	byte	code;
	word	checksum;
	longword	ipaddr;
	in_Header	ip;
};
typedef struct icmp_echo {
	byte	type;
	byte	code;
	word	checksum;
	word	identifier;
	word	sequence;
};

typedef struct icmp_timestamp {
	byte	type;
	byte	code;
	word	checksum;
	word	identifier;
	word	sequence;
	longword	original;	/* original timestamp */
	longword	receive;	/* receive timestamp */
	longword	transmit;	/* transmit timestamp */
};

typedef struct icmp_info {
	byte	type;
	byte	code;
	word	checksum;
	word	identifier;
	word	sequence;
};

typedef union  {
	struct icmp_unused	unused;
	struct icmp_pointer	pointer;
	struct icmp_ip		ip;
	struct icmp_echo	echo;
	struct icmp_timestamp	timestamp;
	struct icmp_info	info;
} icmp_pkt;

typedef struct pkt {
	in_Header 	in;
	icmp_pkt 	icmp;
	in_Header	data;
};

static	word icmp_id = 0;
static	word ping_number = 0L;
int	icmp_unreach = 0;		/* tell world about unreachables */
int	icmp_redirect = 0;
extern	byte kdebug;

void
icmp_init()				/* reinit all local statics */
{
	ping_number = icmp_id = 0;
	icmp_unreach = icmp_redirect = 0;
	return;
}

void
icmp_print(byte *msg)
{
	if (msg == NULL) return;
	if (kdebug & DEBUG_STATUS)
		{
		outs("\n\r ICMP: ");
		outs(msg);
		}
}

struct pkt *
icmp_Format(longword destip)
{
	eth_address dest;

	    /* we use arp rather than supplied hardware address */

	if (arp_resolve(destip, dest) == 0)
		return (NULL);			/* unable to find address */
	return ((struct pkt*)eth_formatpacket(dest, TYPE_IP));
}
/*
 * icmp_Reply - format a reply packet
 *  	      - note that src and dest are NETWORK order
 */
int
icmp_Reply(struct pkt *p, longword src, longword dest, int icmp_length)
{

	if (p == NULL) return (0);		/* failure */
	if ((dest == 0xffffffffL) || (dest == 0L)) /* broadcasts, ignore */
		return(0);
	if ((src == 0xffffffffL) || (dest == 0L)) /* broadcasts, ignore */
		return(0);

	/* finish the icmp checksum portion */
	p->icmp.unused.checksum = 0;
	p->icmp.unused.checksum = ~checksum(&p->icmp, icmp_length);

	/* encapsulate into a nice IP packet */
	p->in.hdrlen_ver = 0x45;
	p->in.length = htons(sizeof(in_Header) + icmp_length);
	p->in.tos = 0;
	p->in.identification = htons(icmp_id++);	/* not using IP id */
	p->in.frag = 0;
	p->in.ttl = 250;
	p->in.proto = ICMP_PROTO;
	p->in.checksum = 0;
	p->in.source = src;
	p->in.destination = dest;
	p->in.checksum = ~checksum(&p->in, sizeof(in_Header));

	return (eth_send(htons(p->in.length)));		/* send the reply */
}

int
do_ping(byte * hostid, longword hostip)
{
	register struct pkt *pkt;
	byte mybuf[17];

	if (hostip == 0L) 		/* if no host IP number yet */
		if ((hostip = resolve(hostid)) == 0L)
		return (-1);		/* failed to resolve host */

	pkt = icmp_Format(hostip);
	pkt->icmp.echo.type = 8;			/* Echo Request */
	pkt->icmp.echo.code = 0;
	pkt->icmp.echo.identifier = (word)(htonl(my_ip_addr) & 0xffff);
	pkt->icmp.echo.sequence = ping_number++;
	pkt->icmp.timestamp.original = htonl(0x12345678);
	icmp_Reply(pkt, htonl(my_ip_addr), htonl(hostip),
					4 + sizeof(struct icmp_echo));
	outs("\r\n Sending Ping to ");
	ntoa(mybuf, hostip); outs(mybuf);
	return (0);
}

int
icmp_handler(in_Header *ip)
{
	register icmp_pkt *icmp, *newicmp;
	struct pkt *pkt;
	int len, code;
	in_Header *ret;
	byte nametemp[17];
	extern void do_redirect(long, void *);
	extern void do_quench(void *);

	len = (ip->hdrlen_ver & 0xf) << 2;	/* quad bytes to bytes */
	icmp = (icmp_pkt *)((byte *)ip + len);
	len = ntohs(ip->length) - len;
	if (checksum(icmp, len) != 0xffff)
		return (0);				/* 0 = failure */

	if (len > 1500 - 20)				/* pkt too long? */
		len = 1500 - 20;			/* max buffer */
	if (my_ip_addr == 0L)
		return (0);		/* we have no IP address yet */
	if (ntohl(ip->destination) != my_ip_addr)
		return (0);		/* not a unicast, ignore */

	code = icmp->unused.code;

	switch (icmp->unused.type)
	{
	case 0: 			/* icmp echo reply received */
		icmp_print("received icmp echo receipt");

		/* check if we were waiting for it */
		if (icmp->echo.identifier == (word)(ntohl(my_ip_addr)&0xffff))
			{			/* answer to our request */
			if (kdebug & DEBUG_STATUS)
				outs("\r\n host is alive\r\n");
			break;
			}
		break;

	case 3 :	 	/* destination or port unreachable message */
		if (code < 6)
			{
			icmp_print(unreach[code]);	/* display msg */
			icmp_unreach = 1 + code; /* say unreachable condx */
						/* handle udp or tcp socket */
			ret = &icmp->ip.ip;	/* ret'd IP header + 8 bytes*/
			if (ret->proto == TCP_PROTO)
				tcp_cancel(ret);
			if (ret->proto == UDP_PROTO)
				udp_cancel(ret);
			}
		break;

	case 4:				/* source quench */
		icmp_print("Source Quench");
		do_quench(&icmp->ip.ip);	/* returned IP header */
		break;

	case 5:				 /* redirect */
		if (code < 4)
			{
					/* new gateway IP address to use */ 
			arp_register(ntohl(icmp->ip.ipaddr), 
				ntohl(icmp->ip.ip.destination));
					/* for this host IP address */
					/* and add to list of gateways */
			if (kdebug & DEBUG_STATUS)
			{
			icmp_print(redirect[code]);
			ntoa(nametemp, ntohl(icmp->ip.ipaddr));
			outs(" to gateway "); outs(nametemp);
			ntoa(nametemp, ntohl(ip->source));
			outs(" from gateway ");	outs(nametemp);
			}
			do_redirect(ntohl(icmp->ip.ipaddr), &icmp->ip.ip);
					/* new gateway  returned IP header */
			}
		break;

	case 8: 			/* icmp echo request */
		icmp_print("Ping request\r\n");
	        /* format the packet with the request's hardware address */
		pkt = (struct pkt*)(eth_formatpacket(
				(eth_address *)eth_hardware(ip), TYPE_IP));
		newicmp = &pkt->icmp;
		bcopy(icmp, newicmp, len);
		newicmp->echo.type = 0;
		newicmp->echo.code = (byte)(code & 0xff);

		/* use supplied ip values in case we ever multi-home */
		/* note that ip values are still in network order */

		icmp_Reply(pkt, ip->destination, ip->source, len);
		break;

	case 11: 			/* time exceeded message */
		if (code < 2)
			icmp_print(exceed[code]);
		break;

	case 12: 			/* parameter problem message */
		icmp_print("IP Parameter problem");
		break;

	case 13: 			/* timestamp message */
/*		icmp_print("Timestamp message"); */
		/* send reply */
		break;

	case 14:			 /* timestamp reply */
/*		icmp_print("Timestamp reply"); */
		/* should store */
		break;

	case 15: 			/* info request */
/*		icmp_print("Info requested"); */
		/* send reply */
		break;

	case 16: 			/* info reply */
/*		icmp_print("Info reply"); */
		break;
	}				/* end of switch */
	return (1);			/* status of success */
}

/* Return ICMP Destination and Port Unreachable message */
void
icmp_noport(in_Header *ip)
{
	register icmp_pkt *icmp, *newicmp;
	struct pkt *pkt;
	int len;

	if (my_ip_addr == 0L)
		return;				/* we have no address yet */
	len = (ip->hdrlen_ver & 0xf) << 2;	/* quad bytes to bytes */
	icmp = (icmp_pkt *)((byte *)ip + len);
	pkt = (struct pkt*)(eth_formatpacket(
			(eth_address *)eth_hardware(ip), TYPE_IP));
	newicmp = &pkt->icmp;
	newicmp->unused.type = 3;	/* destination unreachable */
	newicmp->unused.code = 3;	/* port unreachable */
	newicmp->unused.unused = 0L;	/* must be zero for unreachables */
		/* send back Internet header + first 64 bits of datagram */
	bcopy(ip, &newicmp->unused.ip, 8 + sizeof(in_Header));
	icmp_Reply(pkt, ip->destination, ip->source, 
		sizeof(struct icmp_unused));	/* compose and send reply */
}
