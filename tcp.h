/* File MSNTCP.H
 * Main include file for TCP/IP, as revised and modified for MS-DOS Kermit.
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
 *       Erick Engelke                Erick@development.watstar.uwaterloo.ca
 *       Faculty of Engineering
 *       University of Waterloo       (519) 885-1211 Ext. 2965
 *       200 University Ave.,
 *       Waterloo, Ont., Canada
 *       N2L 3G1
 * Adapted and modified for MS-DOS Kermit by Joe R. Doupnik, 
 *  Utah State University, jrd@cc.usu.edu, jrd@usu.Bitnet,
 *  and by Frank da Cruz, Columbia University, fdc@watsun.cc.columbia.edu.
 *
 * Name resolution services were adapted from sources made available by
 * the National Centre for Supercomputer Applications (NCSA) and Clarkson
 * University.
 *
 * The C code is designed for the small memory model of Microsoft C versions
 * 5.1 and later, with structures packed on one byte boundaries. No other
 * options are expected.
 *
 * Last edit:
 * 12 Jan 1995 version 3.14
 */
 
#define KERMIT

/*
 * Typedefs and constants
 */

#ifndef byte
typedef unsigned char byte;
#endif  /* byte */
#ifndef word
typedef unsigned int word;
#endif  /* word */
#ifndef longword
typedef unsigned long longword;
#endif /* longword */

typedef int (*procref)(void *, void *, int);
typedef byte eth_address[6];


/* MSC v6.0 & v7.0 &v8.0 definition of Far as _far */
#define FAR _far

/*
#define DEBUG
*/

#ifndef NULL
#define NULL 0
#endif

#define TRUE        1
#define FALSE       0

#define ETH_MSS 1460 			/* MSS for Ethernet >= 536 */
#define MAX_GATE_DATA 3
#define MAX_NAMESERVERS 3
#define MAX_COOKIES 0
#define MAX_STRING 64	
#define TICKS_SEC 18
#define PD_ETHER 1
#define PD_SLIP  6

#define	BOOT_FIXED	0	/* methods of obtaining our IP address */
#define	BOOT_BOOTP	1
#define	BOOT_RARP	2
#define BOOT_DHCP	3

/* Ethernet frame TYPE's in network order, reverse for host order */
#define TYPE_IP		0x0008
#define TYPE_ARP	0x0608
#define TYPE_RARP	0x3580

/* Ethernet protocol identifications */
#define ICMP_PROTO 0x01
#define TCP_PROTO  0x06
#define UDP_PROTO  0x11

				/* sock_mode byte bit-field */
#define TCP_MODE_NAGLE	0x01	/* TCP Nagle algorithm */
#define TCP_MODE_PASSIVE 0x02	/* TCP, opened in passive mode */
#define UDP_MODE_CHKSUM	0x08	/* UDP checksums */

/* The Ethernet header */
typedef struct {
    eth_address     destination;
    eth_address     source;
    word            type;
} eth_Header;

/* The Internet Header: */
typedef struct {
    byte	    hdrlen_ver;		/* both in one byte */
    byte	    tos;
    word            length;
    word            identification;
    word            frag;
    byte	    ttl;
    byte	    proto;
    word            checksum;
    longword        source;
    longword        destination;
} in_Header;

typedef struct {
    word	    srcPort;
    word	    dstPort;
    word	    length;
    word	    checksum;
} udp_Header;

typedef struct {
    word            srcPort;
    word            dstPort;
    longword        seqnum;
    longword        acknum;
    word            flags;
    word            window;
    word            checksum;
    word            urgentPointer;
} tcp_Header;

/* The TCP/UDP Pseudo Header */
typedef struct {
    longword    src;
    longword    dst;
    byte        mbz;
    byte        protocol;
    word        length;
    word        checksum;
} tcp_PseudoHeader;

/* TCP states */
#define tcp_StateLISTEN  0x0000      /* listening for connection */
#define tcp_StateSYNSENT 0x0001      /* syn sent, active open */
#define tcp_StateSYNREC  0x0002      /* syn received, synack+syn sent. */
#define tcp_StateESTAB   0x0004      /* established */
#define tcp_StateFINWT1  0x0008      /* sent FIN */
#define tcp_StateFINWT2  0x0010      /* sent FIN, received FINACK */
#define tcp_StateCLOSWT  0x0020      /* received FIN waiting for close */
#define tcp_StateCLOSING 0x0040      /* sent FIN, recvd FIN (waiting for FINACK) */
#define tcp_StateLASTACK 0x0080      /* fin received, finack+fin sent */
#define tcp_StateTIMEWT  0x0100      /* dally after sending final FINACK */
#define tcp_StateCLOSEMSL 0x0200
#define tcp_StateCLOSED  0x0400       /* finack received */

#define SOCKET_OPEN	1		/* if socket structure is active */
#define SOCKET_CLOSED	0
#define TIMED_OUT	1		/* if a timer has expired */

#define DEBUG_STATUS	1		/* Set TCP DEBUG for general info */
#define DEBUG_TIMING	2		/* for round trip timing */
/*
 * UDP socket definition, must match start of tcp_socket.
 */
typedef struct udp_socket {
    struct udp_socket *next;
    word	    ip_type;		/* always set to UDP_PROTO */
    byte	    sisopen;		/* non-zero if socket is open */
    byte	    sock_mode;	        /* a logical OR of bits */
    eth_address     hisethaddr;		/* peer's Ethernet address */
    longword        hisaddr;		/* peer's Internet address */
    word	    hisport;		/* peer's UDP port */
    word	    myport;		/* our UDP port */
    int             rdatalen;      	/* signed, bytes in receive buffer */
    byte	    FAR * rdata;	/* Far ptr to data buffer */
} udp_Socket;

/* TCP segment send queue status per segment */
typedef struct sendqstat {
	longword	time_sent;	/* Bios ticks when datagram was sent*/
	longword	timeout;	/* Bios ticks when dgram times out */
	longword	next_seq;	/* seq number of start of next dgram */
};
#define NSENDQ	20			/* number of timed segments */
#define DELAY_ACKS			/* define to use delayed ACKs */

/*
 * TCP Socket definition
 */

typedef struct tcp_socket {
    struct tcp_socket *next;
    word	    ip_type;	    /* always set to TCP_PROTO */
    byte	    sisopen;	    /* non-zero if socket is open */
    byte	    sock_mode;	    /* a logical OR of bits */
    eth_address     hisethaddr;     /* Ethernet address of peer */
    longword        hisaddr;        /* Internet address of peer */
    word            hisport;	    /* TCP port at peer */
    word	    myport;	    /* our TCP port */
    int             rdatalen;       /* signed, bytes in receive buffer */
    byte	    FAR * rdata;    /* Far ptr to receive data buffer */
    				/* above must also match udp_socket */
    byte            FAR * sdata;    /* Far ptr to send data buffer */
    int 	    sdatalen;	    /* signed number of bytes of data to send*/
    int		    sdatahwater;    /* high water mark in buffer */
    word	    state;          /* connection state */
    longword        acknum;	    /* last received byte + 1 */
    longword	    seqnum; 	    /* last sent byte + 1 */
    word            flags;          /* tcp flags word for last packet sent */
    word            mss;	    /* active Max Segment Size */
    word	    window;	    /* remote host's window size */
    word	    old_window;	    /* remote host's previous window size */
    word	    cwindow;	    /* Van Jacobson's algorithm, congest win*/
    word	    ssthresh;	    /* VJ congestion threshold */
    byte	    loss_count;	    /* times in row have lost pkt */
    byte	    last_read;	    /* last byte read by tcp_read, for CR NUL*/
    word	    vj_sa;	    /* VJ's algorithm, standard average */
    word	    vj_sd;	    /* VJ's algorithm, standard deviation */
    word	    rto;	    /* round trip timeout */
    longword        timeout;        /* TCP state timeout, in Bios tics */
    longword	    notimeseq;	    /* seq number below which repeats sent */
    longword	    idle;	    /* timeout for last xmission + rto */
    longword	    winprobe;	    /* timeout on window probes */
    longword	    keepalive;	    /* timeout on passive open'd keepalives */
#ifdef DELAY_ACKS
    longword	    delayed_ack;    /* timeout on pending delayed ACK */
#endif
    word	    probe_wait;	    /* ticks between window probes */
    word	    window_last_sent; /* our window, last sent value */
    byte	    send_kind;	    /* flag, nosend, sendnow */
    int		    sendqnum;	    /* number of active entries in sendq */
    struct sendqstat sendq[NSENDQ]; /* send queue stats per IP datagram */
} tcp_Socket;


/* sock_type used for socket io */
typedef union {
    udp_Socket udp;
    tcp_Socket tcp;
} sock_type;

/*
 * socket macros
 */

/*
 * sock_wait_established()
 *	- waits then aborts if timeout on s connection
 * sock_wait_input()
 *	- waits for received input on s
 *	- may not be valid input for sock_Gets... check returned length
 * sock_wait_closed();
 *	- discards all received data
 *
 * jump to sock_err with contents of *statusptr set to
 *	 1 on closed
 *	-1 on timeout
 */
#define sock_wait_established(s, seconds, fn, statusptr) \
    if (ip_delay0(s, seconds, fn, statusptr)) goto sock_err;
#define sock_wait_input(s, seconds, fn , statusptr) \
    if (ip_delay1(s, seconds, fn, statusptr)) goto sock_err;
#define sock_wait_closed(s, seconds, fn, statusptr)\
    if (ip_delay2(s, seconds, fn, statusptr)) goto sock_err;

/* s is a pointer to a udp or tcp socket */
int	sock_read(sock_type *, byte FAR *, int);
int	sock_fastread(sock_type *, byte FAR *, int);
int	sock_write(sock_type *, byte FAR *, int);
word	sock_dataready(sock_type *);
int	sock_established(sock_type *);
int	sock_close(sock_type *);
void	sock_abort(sock_type *);
int	sock_setmode(tcp_Socket *, word, word);

/*
 * TCP or UDP specific material, must be used for open's and listens, but
 * sock calls are used for everything else.
 */
int	udp_open(udp_Socket *, word, longword, word);
int	tcp_open(tcp_Socket *, word, longword, word);
int	tcp_listen(tcp_Socket *, word, longword, word, word);
int	tcp_established(void *);

/* timers */
int	ip_delay0(sock_type *, int, procref, int *);
int	ip_delay1(sock_type *, int, procref, int *);
int	ip_delay2(sock_type *, int, procref, int *);

/* tcp_init/tcp_shutdown, init/kill all tcp and lower services.
   Call if sock_init is not used, else not recommended.
*/
int	tcp_init(void);
void	tcp_shutdown(void);
int	tcp_abort(tcp_Socket *);
/* tcp_tick - called periodically by user application in sock_wait.
  returns 0 when our socket closes
*/
int	tcp_tick(sock_type *);

int	tcp_cancel(in_Header *);
int	udp_cancel(in_Header *);

int	eth_init();
byte *	eth_formatpacket(void *, word);
int	eth_send(word);
void	eth_free(void *);
byte *	eth_arrived(word *);
void	eth_release(void);
void *	eth_hardware(byte *);
int	do_bootp(void);
int	do_rarp(void);
int	do_ping(byte *, longword);
longword resolve(byte *);
int	add_server(int *, int, longword *, longword);
void	arp_init(void);
int	arp_resolve(longword, eth_address *);
void	arp_register(longword, longword);
void	arp_add_gateway(byte *, longword);
longword arp_rpt_gateway(int);
int	pkt_rarp_init(void);

word 	ntohs(word);
word 	htons(word);
longword ntohl(longword);
longword htonl(longword);
void *	movmem(void *, void *, int);

extern	word pktdevclass;
extern	word mss;
extern	longword bootphost;
extern	longword my_ip_addr;
extern	eth_address eth_addr;
extern	eth_address eth_brdcast;
extern	longword sin_mask;
extern	int last_nameserver;
extern	word arp_last_gateway;
extern	longword def_nameservers[];
extern	word debug_on;
