/* File MSNSED.C
 * Ethernet Driver support routines
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
 * 12 Jan 1995 v3.14
 *
 *  The TCP code uses Ethernet constants for protocol numbers and 48 bits
 *  for address.  Also, 0xffffffffffff is assumed to be a broadcast.
 *
 *  If you need to write a new driver, implement it at this level and use
 *  the above mentioned constants as this program's constants, not device
 *  dependant constants.
 *
 *  The packet driver code lies below this.
 *
 *  eth_addr	- Ethernet address of this host.
 *  eth_brdcast	- Ethernet broadcast address.
 */

#include "tcp.h"
#include "netlibc.h"

#define ETH_MIN	60              /* Minimum Ethernet packet size */

eth_address eth_addr = {0};	/* local ethernet address */
eth_address eth_brdcast ={0xff,0xff,0xff,0xff,0xff,0xff};
				/* Ethernet broadcast address */
word pktdevclass = 1;		/* Ethernet = 1, SLIP = 6 */
extern word MAC_len;		/* length of a MAC address, bytes */

/* Ethernet Interface */

struct ether {
    byte	dest[6];
    byte	src[6];
    word	type;
    byte	data[ETH_MSS + 60];
};
static struct ether outbuf = {{0},{0},0,{0}};

/* Write Ethernet MAC header and return pointer to data field. */
/* Uses single output frame buffer, named outbuf. */
byte *
eth_formatpacket(void *eth_dest, word eth_type)
{
	memset(&outbuf, 0, 6+6+2+64);		/* clear small frame */

	switch (pktdevclass) 
	    	{
		case PD_ETHER:
			bcopy(eth_dest, outbuf.dest, 6);
			bcopy(eth_addr, outbuf.src, 6);
			outbuf.type = eth_type;
			return(outbuf.data);	/* outbuf is permanent */
		case PD_SLIP:
			return(outbuf.dest);	/* really data because no header */
    		}
	return (NULL);				/* default */
}

/*
 * eth_send does the actual transmission once we are complete with the
 * buffer.  Do any last minute patches here, like fix the size.
 */
int
eth_send(word len)
{
	if (len & 1) len++;		/* if odd make even */
	if ((pktdevclass == PD_ETHER) && ((len += 14) < ETH_MIN))
		len = ETH_MIN;
	return (pkt_send((byte *) &outbuf, len));  /* send to link driver */
}

/*
 * eth_free - free an input buffer once it is no longer needed
 * If pointer to NULL, release all buffers
 */
void 
eth_free(void *buf)
{
	if (buf != NULL)
		pkt_buf_release(buf);		/* free this buffer ptr */
	else
		pkt_buf_wipe();			/* if none then clear all */
}

/*
 * eth_arrived - if a new packet has arrived, read it and fill pointer
 * with type of packet
 */

byte * 
eth_arrived(word *type_ptr)
{
	register int i;
	register struct ether * temp;

	if (type_ptr == NULL) return (NULL);
	if ((temp = (struct ether *)pkt_received()) == NULL)
		return (NULL);			/* nothing there folks */

	switch (pktdevclass)
		{
		case PD_ETHER:
			*type_ptr = temp->type;		/* value of TYPE */
			if (MAC_len == 0)	/* no MAC address to test */
				return (temp->data);
	    		for (i = 5; i >= 0; i--)	/*source same as us?*/
		    		if (temp->src[i] != eth_addr[i])
					return(temp->data); /* ptr to data */
						/* NDIS echo stupidity */
			eth_free(temp->data);		/* discard packet */
			return (NULL);

		case PD_SLIP:
	    		*type_ptr = TYPE_IP;
			return((byte *)temp);		/* no MAC to skip */
		default:
			return (NULL);
    		}
}

/*
 * eth_release - release the hardware
 */
void 
eth_release(void)
{
    pkt_release();
}

/*
 * eth_hardware - return pointer to source hardware address of a frame
 */
eth_address *
eth_hardware(in_Header *p)
{
	if (p == NULL || pktdevclass == PD_SLIP) return (NULL);
	return (eth_address *)(p - 8);
}
