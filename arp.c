/* File MSNARP.C
 * ARP and RARP packet processor
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
 * Adapted, modified, redesigned for MS-DOS Kermit by Joe R. Doupnik, 
 *  Utah State University, jrd@cc.usu.edu, jrd@usu.Bitnet.
 *
 * Last edit
 * 12 Jan 1995 v3.14
 *
 * Address Resolution Protocol  RFC826.TXT
 * Reverse Address Resolution Protocol RFC903.TXT
 *  Externals:
 *  ap_handler(pb) - returns 1 on handled correctly, 0 on problems
 *  arp_resolve - rets 1 on success, 0 on fail
 *               - does not return hardware address if passed NULL for buffer
 *
 */
#include "msntcp.h"
#include "msnlib.h"

#define MAX_ARP_DATA 10			/* cache entries */
#define MAX_ARP_ALIVE  300		/* cache lifetime, five minutes */
#define MAX_ARP_GRACE  100		/* additional grace upon expiration */
#define PLEN	4			/* bytes in an IP address longword */
#define NEW_EXPIRY			/* refresh cache on the fly */

/* ARP and RARP header. Note that address lengths and hardware type ident
   vary depending on frame type at the hardware level. The frame handler
   (Packet Driver or ODI driver) will set these values. jrd */

typedef	struct {
    word	hwType;			/* hardware type ident */
    word	protType;		/* protocol ident */
    byte	hlen;			/* length of MAC hardware address */
    byte	plen;			/* plen, length of protocol address */
    word	opcode;
    byte	sender_mac[6];		/* But smaller MAC_lens are usable */
    longword	sender_IP;		/*  by not referencing these entries*/
    byte	target_mac[6];		/*  directly: use sender_mac+offset */
    longword	target_IP;
} arp_header;

typedef struct
	{
	longword	ip;		/* host IP number */
	eth_address	mac;		/* mac address to use */
	byte		flags;		/* cache entry status */
	byte		bits;		/* reserved */
	longword	expiry;		/* Bios tics when entry expires */
	} arp_tables;

typedef struct
	{
	longword	gate_ip;
	} gate_tables;

/* ARP style op codes */
#define ARP_REQUEST 0x0100		/* ARP request */
#define ARP_REPLY   0x0200		/* ARP reply */
#define RARP_REQUEST 0x0300		/* RARP request */
#define RARP_REPLY  0x0400		/* RARP reply */

#define ARP_FLAG_NEED	0		/* cache state, no mac address yet */
#define ARP_FLAG_FOUND  1		/* have mac address */
#define ARP_FLAG_FIXED  2		/* cannot be removed */
#define ARP_FLAG_IMPOSTER 4		/* imposter response discovered */

extern longword ipbcast;		/* IP broadcast address */
extern	byte kdebug;

/* MAC_len and arp_hardware can be set by the packet frame routines */
word MAC_len = 6;			/* bytes in MAC level hardware addr */
word arp_hardware = 0x0001;		/* ARP, hardware ident, little end */

/*
 * arp resolution cache - we zero fill it to save an initialization routine
 */

static arp_tables arp_data[MAX_ARP_DATA] = {0};
gate_tables arp_gate_data[MAX_GATE_DATA] = {0};
word arp_last_gateway = 0;
static word arp_index = 0;		/* rotates round-robin */
static void arp_display(arp_header *, longword, longword);

/*
 * arp_add_gateway
 */
void 
arp_add_gateway(byte *data, longword ip)
{
	if ((data == NULL) && (ip == 0L)) return; 	/* nothing to do */

	if ((data != NULL) && (ip == 0L))	/* if text form given */
		ip = aton(data);		/* convert to 32 bit long */

	if (arp_last_gateway >= MAX_GATE_DATA) return;

	arp_gate_data[arp_last_gateway].gate_ip = ip;
	arp_last_gateway++;			/* used up another one */
}

longword
arp_rpt_gateway(int i)			/* report IP of gateway i */
{
	if (i >= 0 && i < MAX_GATE_DATA)
		return (arp_gate_data[i].gate_ip);
	else	return (0L);
}

static void 
arp_request(longword ip)
{
	register arp_header *op;
	longword temp;

	if (ip == 0L || ip == 0xffffffffL)
		return;			/* can't ARP for these */

	op = (arp_header *)eth_formatpacket(&eth_brdcast[0], TYPE_ARP);
	op->hwType = htons(arp_hardware);		/* hardware frame */
	op->protType = TYPE_IP;				/* IP protocol */
	op->hlen = (byte)(MAC_len & 0xff);		/* MAC address len */
	op->plen = PLEN;				/* IP address len */
	op->opcode = ARP_REQUEST;
							/* our MAC address */
	bcopy(&eth_addr[6-MAC_len], op->sender_mac, MAC_len);
	temp = htonl(my_ip_addr);
	bcopy(&temp, &op->sender_mac[MAC_len], PLEN);	/* our IP */
	temp = htonl(ip);
	bcopy(&temp, &op->sender_mac[MAC_len * 2 + PLEN], PLEN); /* host IP */
	eth_send(sizeof(arp_header));    		/* send the packet */
	if (kdebug & DEBUG_STATUS)
		arp_display(op, my_ip_addr, ip);
}

/* Search ARP table, given an IP address ip. Create an entry if 
   create is != 0.
   Return  pointer to entry if IP is in the table (perhaps from a
   create request), else NULL for no entry found.
*/

static arp_tables *
arp_search(longword ip, int create)
{
	register int i;
	register arp_tables *arp_ptr;

	for (i = 0; i < MAX_ARP_DATA; i++)
		if (ip == arp_data[i].ip)
			    return(&arp_data[i]); /* found an entry */

	if (create == 0)			/* do not create new one */
		return (NULL);

						/* pick an old or empty one */
	for (i = 0; i < MAX_ARP_DATA; i++)
		{
		arp_ptr = &arp_data[i];
		if ((arp_ptr->ip == 0L) ||
    			chk_timeout(arp_ptr->expiry + MAX_ARP_GRACE))
		arp_ptr->flags = ARP_FLAG_NEED;	/* clear status flag */
		return(arp_ptr);
		}
						/* pick one at pseudo-random */
	arp_index = (arp_index + 1) % MAX_ARP_DATA;
	arp_ptr->flags = ARP_FLAG_NEED;		/* new MAC address needed */
	return (&arp_data[arp_index]);
}

void 
arp_register(longword new_IP, longword old_IP)
{	/* insert new IP to use instead of old IP */
	register arp_tables *arp_ptr;

	if (arp_ptr = arp_search(old_IP, 0)) 	/* if in ARP cache */
		{			/* insert MAC address of new IP */
		arp_resolve(new_IP, arp_ptr->mac);
		arp_ptr->expiry = set_timeout(MAX_ARP_ALIVE);
		return;
		}
	arp_ptr = arp_search(new_IP, 1);		/* create a new one */
	arp_ptr->flags = ARP_FLAG_NEED;
	arp_ptr->ip = old_IP;
	arp_resolve(new_IP, arp_ptr->mac);
	arp_ptr->expiry = set_timeout(MAX_ARP_ALIVE);
}

/*
 * arp_handler - handle incoming ARP packets
 * Information will be put into the ARP cache only if an entry for that IP
 * already exists (from an arp_resolve call).
 */
int
arp_handler(arp_header *in)
{
	register arp_header *op;
	longword his_ip, target_ip, temp;
	register arp_tables *arp_ptr;
	byte *sender_mac;

	if (in == NULL) return (0);			/* failure */

	if (in->protType != TYPE_IP)			/* IP protocol */
		return(0);				/* 0 means no, fail */

	/* continuously accept data - but only for people we talk to */
	bcopy(&in->sender_mac[MAC_len], &his_ip, PLEN);
	his_ip = ntohl(his_ip);
	bcopy(&in->sender_mac[MAC_len * 2 + PLEN], &target_ip, PLEN);
	target_ip = ntohl(target_ip);

	if ((in->opcode == ARP_REPLY) &&       	/* a resolution reply */
		(arp_ptr = arp_search(his_ip, 0)) != NULL)
		{				/* do not create entry */
		if (kdebug & DEBUG_STATUS) 
			arp_display(in, his_ip, target_ip);
		arp_ptr->expiry = set_timeout(MAX_ARP_ALIVE);
		memset(arp_ptr->mac, 0, 6);	/* zero their MAC address */
			/* then copy their MAC address to the trailing end */
		bcopy(in->sender_mac, &arp_ptr->mac[6 - MAC_len], MAC_len);
		arp_ptr->flags = ARP_FLAG_FOUND;
		if (his_ip == my_ip_addr)	/* their IP == my IP, uh oh */
			{
			arp_ptr->flags = ARP_FLAG_IMPOSTER;
			outs("\r\n Another station is using our IP address");
			outs(" from MAC address ");

			//	outhexes(&in->sender_mac, in->hlen);
			/* BCC is failing to compile this. */
			/* Try splitting it into two lines. */
			sender_mac=in->sender_mac;
			outhexes(&sender_mac, in->hlen);

			outs("\r\n");
			}
		}			/* end of REPLY section */


			/* Does someone want our hardware address? */
	if ((in->opcode == ARP_REQUEST) && (target_ip == my_ip_addr))
		{
		if (kdebug & DEBUG_STATUS)
			{
			arp_display(in, his_ip, target_ip);
			outs(" ARP Request is for our IP; replying.\r\n");
			}
		op = (arp_header *)eth_formatpacket(in->sender_mac, TYPE_ARP);
		op->hwType = htons(arp_hardware);
		op->protType = TYPE_IP;			/* IP protocol */
		op->hlen = (byte) (MAC_len & 0xff);	/* MAC address len */
		op->plen = PLEN;			/* IP address len */
		op->opcode = ARP_REPLY;
						/* host's MAC and IP address */
		bcopy(in->sender_mac,		/* to target_mac */
			&op->sender_mac[MAC_len + PLEN], MAC_len + PLEN);
						 /* our MAC and IP address */
		bcopy(&eth_addr[6-MAC_len], op->sender_mac, MAC_len);
		temp = htonl(my_ip_addr);	/* our IP in net order */
		bcopy(&temp, &op->sender_mac[MAC_len], PLEN);
		return (eth_send(sizeof(arp_header)));	/* send the packet */
		}
	return (1);					/* for success */
}

/* Display contents of an ARP packet, given initial IP address info */
void
arp_display(arp_header *in, longword sender_ip, longword target_ip)
{
	byte temp[17];

	outs("\r\n ARP");
	if (in->opcode == ARP_REQUEST)
		outs(" request");
	if (in->opcode == ARP_REPLY)
		outs(" reply");
	if (sender_ip == my_ip_addr)
		outs(" sent. Sender_IP=");
	else
		outs(" received. Sender_IP=");
	ntoa(temp, sender_ip);
	outs(temp);
	outs(", Target_IP=");
	ntoa(temp, target_ip);
	outs(temp);
	outs("\r\n  Sender_MAC=");
	outhexes(in->sender_mac, in->hlen);
}

/*
 * arp_resolve - resolve IP address to hardware address
 * return non-zero if successful, else zero
 */
int
arp_resolve(longword ina, eth_address *ethap)
{
	register arp_tables *arp_ptr;
	register word i;
	byte nametemp[17];
	int j;
	longword timeout, resend;
	static int arp_gateway = 0;	/* distinguish gateway from host */

	/* If we are running SLIP or ODI's SLIP_PPP which do not use
						MAC level addresses */
	if (pktdevclass == PD_SLIP || 
		(pktdevclass == PD_ETHER && MAC_len == 0 ))
		if (ina == my_ip_addr)
			return (0);		/* fail if ARP for self */
		else
			return(1);

	if (ina == 0L || ina == 0xffffffffL || ina == ipbcast)
		return (0);	/* cannot resolve IP of 0's or 0xff's*/

						/* check cache first */
	if (((arp_ptr = arp_search(ina, 0)) != NULL) &&
		(arp_ptr->flags & (ARP_FLAG_FOUND + ARP_FLAG_FIXED)))
		{
		if (ethap != NULL)
			bcopy(arp_ptr->mac, ethap, 6); /* keep 6 byte MACs */
#ifdef NEW_EXPIRY
		if (chk_timeout(arp_ptr->expiry + MAX_ARP_GRACE) == TIMED_OUT)
			arp_ptr->flags = ARP_FLAG_NEED;	/* too old, expire */
		else
#endif /* NEW_EXPIRY */
			return(1);				/* success */
		}

		/* we must look elsewhere - but is it on our subnet? */
	if (((ina ^ my_ip_addr) & sin_mask)	/* not on this network */
		&& (arp_gateway == 0))		/* host, not gateway */
		{
		for (i = 0; i < arp_last_gateway; i++)
			{		/* watch out RECURSIVE CALL! */
			arp_gateway = 1;	/* remember doing gateway */
			j = arp_resolve(arp_gate_data[i].gate_ip, ethap);
			arp_gateway = 0;	/* done doing gateway */
			if (j != 0)
				   return (j);		/* success */
			}
		return (0);				/* fail */
		}
					    /* make a new entry if necessary */
	if (arp_ptr == NULL)
    		{
		arp_ptr = arp_search(ina, 1);	/* 1 means create an entry */
		arp_ptr->flags = ARP_FLAG_NEED;	/* say need mac address */
		}

	tcp_tick(NULL);			/* read packets thus far */
					/* is on our subnet, we must resolve */
	timeout = set_timeout(2);	/* two seconds is long for ARP */
	if (ina == my_ip_addr)
		timeout = set_ttimeout(6);	/* briefly look for imposter*/

	while (chk_timeout(timeout) != TIMED_OUT)
		{					/* do the request */
		resend = set_ttimeout(4);		/*  4 / 18.2 sec */
		arp_request(arp_ptr->ip = ina);

		while (chk_timeout(resend) != TIMED_OUT)
			{
			tcp_tick(NULL);			/* read packets */
			if (arp_ptr->flags == ARP_FLAG_NEED)
				continue;
			if (arp_ptr->flags & ARP_FLAG_IMPOSTER)
				return (1);		/* IP imposter */
			if (arp_ptr->flags & (ARP_FLAG_FOUND + ARP_FLAG_FIXED))
				{
				if (ethap != NULL)	/* get MAC address */
					bcopy(arp_ptr->mac, ethap, 6);
				return (1);		/* success */
				}
			}		/* end of resend while */
    		}			/* end of timeout while */

	if (ina != my_ip_addr)			/* if not my own IP address */
		{
		outs("\r\n Unable to ARP resolve ");
		if (arp_gateway == 1) outs("gateway ");
		ntoa(nametemp, ina);
		outs(nametemp);			/* show IP involved */
		}
	return(0);			/* fail */
}


int
rarp_handler(arp_header *in)
{
	register word i;
	longword his_ip;
	register arp_tables *arp_ptr;

	if (in == NULL) return (0);			/* failure */

	if ((in->protType != TYPE_IP))			/* Internet protocol*/
		return (0);				/* 0 means no, fail */
	bcopy(&in->sender_mac[MAC_len], &his_ip, PLEN);
	his_ip = ntohl(his_ip);
	if ((arp_ptr = arp_search(his_ip, 0)) != NULL)
		{
		arp_ptr->expiry = set_timeout(MAX_ARP_ALIVE);
		memset(arp_ptr->mac, 0, 6);	/* zero their MAC address */
			/* then copy their MAC address to the trailing end */
		bcopy(in->sender_mac, &arp_ptr->mac[6 - MAC_len], MAC_len);
		arp_ptr->flags = ARP_FLAG_FOUND;
		}
					/* look for RARP Reply */
	if ((my_ip_addr == 0) && (in->opcode == RARP_REPLY))
		{	  		/* match our Ethernet address too */
		for (i = 0; i < MAC_len; i++)
			if (in->sender_mac[MAC_len + PLEN + i] != 
						eth_addr[6 - MAC_len + i])
				return (1);		/* not for us */
		bcopy(&in->sender_mac[MAC_len * 2 + PLEN], &my_ip_addr, PLEN);
		my_ip_addr = ntohl(my_ip_addr);		/* our IP addr */
		}
	return (1);					/* for success */
}

/* send a RARP packet to request an IP address for our MAC address */
static void 
arp_rev_request(void)
{
	register arp_header *op;

	op = (arp_header *)eth_formatpacket(&eth_brdcast[0], TYPE_RARP);
	op->hwType = htons(arp_hardware);
	op->protType = TYPE_IP;				/* IP protocol */
	op->hlen = (byte)(MAC_len & 0xff);		/* MAC address len */
	op->plen = PLEN;				/* IP address len */
	op->opcode = RARP_REQUEST;
		/* our MAC address into sender_mac and target_mac */
	bcopy(&eth_addr[6 - MAC_len], &op->sender_mac[0], MAC_len);
	bcopy(&eth_addr[6 - MAC_len], &op->sender_mac[MAC_len + PLEN], MAC_len);
	eth_send(sizeof(arp_header));    		/* send the packet */
}

/* Send a series of RARP requests until our IP address is non-zero or
   we timeout.
*/
int
do_rarp(void)
{
	longword timeout, resend;

	my_ip_addr = 0L;				/* init our IP */
	timeout = set_timeout(10);			/* 10 seconds total */
	while (chk_timeout(timeout) != TIMED_OUT)
	    	{
		arp_rev_request();			/* ask for our IP */
		resend = set_timeout(2);		/* two second retry */
		while (chk_timeout(resend) != TIMED_OUT)
			{
			tcp_tick(NULL);			/* read packets */
			if (my_ip_addr != 0L) return (1); /* got a reply */
			}
		}
	return (0);					/* got no reply */
}
