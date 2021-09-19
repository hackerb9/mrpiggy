/* File MSNLIB.H
 * Kermit include file for TCP C modules
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
 * The C code is designed for the small memory model of Microsoft C versions
 * 5.1 and later, with structures packed on one byte boundaries. No other
 * options are expected.
 *
 * Last edit:
 * 12 Jan 1995 version 3.14
 */

#ifndef NULL
#define NULL 0
#endif

/* Function prototypes */

#ifndef __BCC__
#ifndef byte
typedef unsigned char byte;
#endif  /* byte */
#ifndef word
typedef unsigned int word;
#endif  /* word */
#ifndef longword
typedef unsigned long longword;
#endif /* longword */
#endif /* __BCC__*/

void outch( byte );		/* print character to stdio */
void outs( byte * );		/* print an ASCIIZ string to stdio */
void outsn( byte *, int );	/* print a string with len max n */
void outhex( byte );
void outhexes( void *, int );
void outdec(int);
void ntoa(byte *, unsigned long);

unsigned long set_timeout( unsigned int );
unsigned long set_ttimeout( unsigned int );
int chk_timeout( unsigned long );

unsigned long intel( unsigned long );
unsigned intel16( unsigned );
unsigned int checksum( void FAR *ptr, int len ); /* IP checksum */

int  ourmod(int, int);
int  ourdiv(int, int);
long ourlmod(long, int);
long ourldiv(long, int);

/* Library function replacements */

int    atoi(byte *);
byte * ltoa(long, byte *, int);
byte * itoa(int, byte *, int);
int    isdigit(const byte);
byte * strchr(void *, const byte);
byte FAR * strchrf(byte FAR *, const byte);
byte * strcat(void *, void *);
byte * strncat(void *, void *, int);
byte * strcpy(void *, void *);
byte * strncpy(void *, void *, int);
int    strlen(void *);
int    strcmp(void *, void *);
int    stricmp(void *, void *);
int    strncmp(byte *, void *, int);
void * bcopy(void *, void *, int);
void * bcopyff(void FAR *, void FAR *, int);
void * memset(void *, byte, int);
void * pkt_received(void);
int    pkt_eth_init(void);
int    pkt_init(void);
int    pkt_send(byte *, int);
int    pkt_release(void);
void   pkt_buf_release(byte *);
void   pkt_buf_wipe(void);
void   enable(void);
void   disable (void);

/* supporting assembly language routines in file msnut1.asm */
longword intel(longword x);
word	intel16(word x);
void FAR * malloc(word x);
void	free(void FAR *);
int	fstchr(const char FAR *, word, byte);
int	destuff(const char FAR *, int, const char FAR *, int, void *, void *);
longword aton(byte *);
int	chkcon(void);
