/* File MSNPKT.C
 * Packet Driver interface
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
 *  Utah State University, jrd@cc.usu.edu, jrd@usu.Bitnet
 *
 * Last edit
 * 12 Jan 1995 v3.14
 */
#include "tcp.h"
#include "netlibc.h"

#define BUFSIZE	(8*1024)		/* size of pkt receive buffer */

word	pkt_ip_type = 0x0008;		/* these are little endian values */
word	pkt_arp_type = 0x0608;
word	pkt_rarp_type = 0x3580;

int	pkt_ip_handle = -1;		/* -1 means invalid handle */
int	pkt_arp_handle = -1;
int	pkt_rarp_handle = -1;

int	pdversion, pdtype, pdnum, pdfunct;
extern	word pktdevclass;
extern	int pdinit(void *, void *);
extern	int pdinfo(int *, int *, int *, int *, int *);
extern	int pdaccess(int *, int, int *);
extern	int pdclose(int);
extern	eth_address eth_addr;			/* six byte array */
extern	word MAC_len;
extern	word mss;
extern	byte kdebug;

byte pktbuf[BUFSIZE] = {0};	/* linked list packet receive buffer */
static byte * pktbuf_read = pktbuf;
byte pktwnum = 0;		/* seq number for packets written to buffer */
byte pktrnum = 0;		/* seq number for packets read from buffer */
byte * pktbuf_wrote = &pktbuf[BUFSIZE - 4];
long watch_timeout;

int
eth_init()
{
    	pkt_buf_wipe();		/* clean out and init receiver buffer */
	mss = ETH_MSS;		/* set default max seg size */
	if (pdinit(pktbuf, eth_addr) == 0)
    		{
		outs("\r\nCannot attach to an Ethernet Packet Driver");
		outs(" or a Novell ODI driver.");
		return( 0 );
		}
	pkt_buf_wipe();

    				/* lets find out about the driver */
	if ((pdinfo(&pdversion, &pktdevclass, &pdtype, &pdnum, &pdfunct))
		== 0)
		{
		outs("\r\nCannot obtain Packet Driver or ODI information");
		return (0);
		}

	if (pdaccess(&pkt_ip_type, 
	(pktdevclass == PD_SLIP)? 0: sizeof(pkt_ip_handle), &pkt_ip_handle)
		== 0)
 		{
		outs("\r\n\7Cannot access IP type packets");
		return (0);
		}

/* Check for real SLIP and for ODI with SLIP_PPP; neither uses ARP and RARP */
/* ODI returns length of MAC header, such as 6 for real Ethernet and 0
   for SLIP and PPP. We get Ethernet style frames for ODI material. */
	if (pktdevclass == PD_SLIP ||
		( pktdevclass == PD_ETHER && MAC_len == 0))
		return (1);

	if (pdaccess(&pkt_arp_type, sizeof(pkt_arp_handle), &pkt_arp_handle)
		== 0)
 		{
		outs("\r\n\7Cannot access ARP type packets");
		return (0);
		}
	return (1);				/* say success */
}

int
pkt_rarp_init()				/* access PD or ODI for RARP */
{
	if (pkt_rarp_handle != -1)
		return (1);		/* have handle already */

	if (pdaccess(&pkt_rarp_type, sizeof(pkt_rarp_handle), &pkt_rarp_handle)
		== 0)
 		{
		outs("\r\n\7Cannot access RARP type packets");
		return (0);
		}
	return (1);				/* say success */
}

int
pkt_release()
{
	register int status = 1;			/* assume success */

	if (pkt_ip_handle != -1)
		if (pdclose(pkt_ip_handle) == 0)
			{
			outs("\r\nERROR releasing Packet Driver for IP");
			status = 0;
			}
		else pkt_ip_handle = -1;	/* handle is out of service */

    	if (pkt_arp_handle != -1)
		if (pdclose(pkt_arp_handle) == 0)
			{
			outs("\r\nERROR releasing Packet Driver for ARP");
			status = 0;
			}
		else pkt_arp_handle = -1;	/* handle is out of service */

	if (pkt_rarp_handle != -1)
		if (pdclose(pkt_rarp_handle) == 0)
			{
			outs("\r\nERROR releasing Packet Driver for RARP");
			status = 0;
			}
		else pkt_rarp_handle = -1;	/* handle is out of service */
	return (status);
}

/* Deliver pointer to start of packet (destination address) or NULL.
 * Simple linked list: byte flag, byte pkt seq number, int count, 
 * byte data[count] and so on.
 * Status on the link flag byte is
 * 0 = end of buffer (count has size to point to start of buffer)
 * 1 = this slot is free (unused)
 * 2 = this slot has an unread packet
 * 4 = this slot is allocated for a packet, packet not yet loaded into it
 * 8 = this slot has a packet which has been read once
 * A two byte count value follows the flag byte, for number of bytes in 
 * this slot. Pktbuf_read remembers the pointer to the last-read slot.
*/

void * 
pkt_received()
{
	register byte * p;
	register int i;

	p = pktbuf_read;			/* start with last read */
	for (i = 0; i < 2 * (BUFSIZE / (60 + 4)); i++)	/* 2 * max pkts */
		{
		if (*(p+1) == pktrnum)
		{
		if (*p == 2) 			/* 2 == ready to be read */
			{			/* if this is the next pkt */
 			pktbuf_read = p;	/* where we have read */
			*p = 8;			/* mark as have read */
			pktrnum++;		/* next one to read */
			watch_timeout = 0;	/* kill watchdog timer */
			return (p + 4);		/* return ptr to pkt*/
			}
		if (*p == 4) 			/* 4 == only allocated */
			if (watch_timeout == 0)	/* if not started timing */
				{
				watch_timeout = set_timeout(1); /* 1 sec */
				return (NULL);
				}
			else
				{	/* if timed out waiting for filling */
				if (chk_timeout(watch_timeout) == TIMED_OUT)
					{
					pkt_buf_wipe();	/* emergency treatment */
					if (kdebug & DEBUG_STATUS)
				outs("\7 Flushing stuck receive queue\r\n");
					}
				return (NULL);
				}
		}	/* end of *(p+1) == pktrnum and *p == 2 | 4 */

/* if link is:      end of buf  free      ready      allocated  have read */
		if (*p == 0 || *p == 1 || *p == 2 || *p == 4 || *p == 8)
			{
			p += 4 + *(word *)(p+2);   /* point at next link */
			continue;
			}
		else				/* bad link information */
			{
			pkt_buf_wipe();		/* emergency treatment */
			if (kdebug & DEBUG_STATUS)
				outs("\7 Flushing corrupt receive queue\r\n");
			break;
			}
		if (p == pktbuf_read)	break;	/* where we came in */
		}
	return (NULL);
}
	
void
pkt_buf_release(byte *p)	/* return a buffer to the pool */
{
	if (pktdevclass == PD_SLIP)
		p -= 4;			/* just link info */
	else
		p -= 4 + 6 + 6 + 2;	/* link info and MAC header */

	if (*p == 8)			/* if packet has been read */
		{
		*(p+1) = pktrnum - 1;	/* backdate to avoid confusion */
		*p = 1;			/* mark link as freed */
		}
}

void
pkt_buf_wipe()					/* clear all buffers */
{
	disable();
	pktbuf[0] = 1;				/* flag first link as free */
	pktbuf[1] = 0;
	*(word *)&pktbuf[2] = BUFSIZE - 8; /* free space, size - two links */

	pktbuf[BUFSIZE - 4] = 0;		/* flag as end of buffer */
	pktbuf[BUFSIZE - 3] = 0;		/* pkt buffer seq number */
				/* count below points to start of buffer */
	*(int *)&pktbuf[BUFSIZE - 2] = - BUFSIZE; 
	pktbuf_read = pktbuf;				/* where last read */
	pktbuf_wrote = &pktbuf[BUFSIZE - 4];		/* where last wrote*/
	pktwnum = pktrnum = 0;		/* reset buffer sequence numbers */
	watch_timeout = 0;
	enable();
}

