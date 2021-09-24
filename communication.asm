	NAME	msscom
; File MSSCOM.ASM
	include symboldefs.h
;	Copyright (C) 1982, 1999, Trustees of Columbia University in the 
;	City of New York.  The MS-DOS Kermit software may not be, in whole 
;	or in part, licensed or sold for profit as a software product itself,
;	nor may it be included in or distributed with commercial products
;	or otherwise distributed by commercial concerns to their clients 
;	or customers without written permission of the Office of Kermit 
;	Development and Distribution, Columbia University.  This copyright 
;	notice must not be removed, altered, or obscured.
;
; Edit history
; 12 Jan 1995 version 3.14
; Last edit
; 12 Jan 1995
; 8 Dec 1992 version 3.13
; 6 Sept 1991 version 3.11
; 2 March 1991 version 3.10

	public	spack, rpack, spause, bufclr, pakptr, bufrel
	public	makebuf, getbuf, pakdup, chkwind, firstfree, windused
	public	rpacket, windlow, chkparflg, maxbufparas, peekreply
	public	winusedmax, krto, k_sa, k_sd, k_rto, tcp_rto, windgrow
	public	windshrink, cwindow, ssthresh

stat_suc equ	0		; success
stat_tmo equ	1		; timeout
stat_chk equ	2		; checksum mismatch
stat_ptl equ	4		; packet too long
stat_int equ	8		; user interrupt
stat_eol equ	10h		; eol char seen
stat_echo equ	20h		; echo of sent packet
stat_bad equ	80h		; packet is bad (premature EOL)
BIOSCLK	equ	046ch
HI_MAX	equ	018h
LO_MAX	equ     0b0h

data	segment
	extrn	flags:byte, trans:byte, fsta:word, ssta:word, fmtdsp:byte
	extrn	pktnum:byte, portval:word, denyflg:word, cardet:byte
	extrn	parmsk:byte

badpflag db	0		; flag to say have shown bad parity message
spmes	db	'Spack: $'
rpmes 	db	'Rpack: $'
crlf    db      cr,lf,'$'
msgstl	db	'Internal Error: send packet is too long',cr,lf,0,'$'
msgheader db	'<$'
msgtmo	db	'Timeout$'
msgchk	db	'Bad checksum $'
msgint	db	'Interrupted$'
msgptl	db	'Pkt too long$'
msgbad	db	'Early EOL$'
msgtail	db	'>',cr,lf,'$'
msgecho	db	cr,lf,'<Echo of sent packet>',cr,lf,'$'
msgbadsnd db	cr,lf,'<Error sending packet bytes>',cr,lf,'$'
msgbadpare db	'Unexpected Parity from host! Changing Parity to EVEN'
	db	cr,lf,0
msgbadparo db	'Unexpected Parity from host! Changing Parity to ODD'
	db	cr,lf,0
msgbadparm db	'Unexpected Parity from host! Changing Parity to MARK'
	db	cr,lf,0
tmp	db	0
spause	dw	0		; # millisec to wait before sending pkt
timeval	db	0		; active receive timeout value, seconds
prvtyp  db      0		; Type of last packet sent
prvlen	dw	0		; bytes sent, for echo suppression
portcount dw	0		; bytes in prtchr ready-to-read buffer
chkparflg db	0		; non-zero to check parity on received pkts
chklength db	1		; active checksum length
prevchar db	0		; previous char from comms line (for ^C exit)
SOHchar	db	0		; start of packet char, local copy
lentyp	db	0		; packet length type, 3, 0, 1
debflg	db	0		; debug display, send/receive flag
timeit	db	0		; arm timeout counter
tcp_rto	dw	0		; rto (Bios ticks) from internal TCP/IP stack
k_rto	dw	0		; Kermit round trip timeout, Bios ticks
k_sa	dw	0		; Kermit smoothed avg round trip time
k_sd	dw	0		; Kermit std deviation of round trip time

				; sliding windows data structures
windlow	db	0		; lower border of window
windused db	0		; number of window slots in use
winusedmax db	0		; max used window slots
cwindow	db	0,0		; congestion window, fractions of slot
ssthresh db	0		; congestion threshold slot count
thirtytwo db	32		; divisor for window congestion counting
prolog  db	10 dup (0)	; prolog: SOH, LEN, SEQ, TYPE, xlen,...,null
epilog	db	10 dup (0)	; epilog: checksum, eol, handshake + null term
rbuf	db	128 dup (0)	; static packet buffer for replies
	even
pbufseg	dw	0		; segment of packet buffer memory block
maxbufparas dw	0		; paragraphs available in free memory
bufnum	dw	0		; number of buffers available now
buflist dw	maxwind dup (0) ; pointers to packet structures in pktlist
bufuse	dw	maxwind dup (0) ; in-use flag (0 = not in use)
pktlist	pktinfo maxwind dup (<>) ; pktinfo structured members (private)
rpacket	pktinfo <rbuf,0,length rbuf,0,0> ; reply pktinfo
	even
rtemp	dw	0		; address of pktinfo structure for rpack
stemp	dw	0		; address of pktinfo structure for spack
linecnt	db	0		; debug line width counter
colcnt	db	0
chksum	dw	0		; running checksum (two char)
chrcnt	dw	0		; number of bytes in data field of a packet
pktcnt	dw	0		; number of bytes sent/rcvd in this packet
status	dw	0		; status of packet receiver (0 = ok)
rptim	db	4 dup (0)	; read packet timeout slots
ninefive dw	95		; for mult/div with long packets
bias	db	' '		; ascii bias for checksum calculations
prolog_len dw	0		; length of prolog information, for crc
temp	dw	0
data	ends

code1	segment
	extrn	strlen:far, isdev:far, decout:far, dec2di:far, sndblk:far
	assume	cs:code1
code1	ends

code	segment
	extrn	prtchr:near, outchr:near, prtblk:far
	extrn	sppos:near, ermsg:near, clearl:near, rppos:near
	extrn	pktcpt:near, pcwait:far, peekcom:far

	assume 	cs:code, ds:data, es:nothing
prtchr1	proc	far		; near-far interface routines for code1 seg
	call	prtchr
	ret
prtchr1	endp
foutchr	proc	far
	call	outchr
	ret
foutchr	endp
rppos1	proc	far
	call	rppos
	ret
rppos1	endp
sppos1	proc	far
	call	sppos
	ret
sppos1	endp
ermsg1	proc	far
	call	ermsg
	ret
ermsg1	endp
clearl1	proc	far
	call	clearl
	ret
clearl1	endp
fpktcpt	proc	far
	call	pktcpt
	ret
fpktcpt	endp
code	ends

code1	segment
	assume 	cs:code1, ds:data, es:nothing

; Send_Packet
; This routine assembles a packet from the arguments given and sends it
; to the host.
;
; Expects the following:
;	SI = pointer to pktinfo structure, as
;	[SI].PKTYPE - Packet type letter
;	[SI].SEQNUM - Packet sequence number
;	[SI].DATLEN - Number of data characters
;	[SI].DATADR - DWord Address of data field for packet
; Returns: carry clear if success, carry set if failure.
; Packet construction areas:
; 	Prolog (8 bytes)			Data	 null  Epilog
;+----------------------------------------+---------------+---------------+
;| SOH,LEN,SEQ,TYPE,Xlen(2-3),Xlen chksum | packet's data | chksum,EOL,HS |
;+----------------------------------------+---------------+---------------+
; where Xlen is 2 byte (Long) or 3 byte (Extra Long) count of bytes to follow.
;
SPACK	PROC	FAR
	mov	stemp,si	; save pkt pointer
	mov	ah,[si].pktype
	mov	prvtyp,ah	; remember packet type
	mov	pktcnt,0	; number of bytes sent in this packet
	mov	prolog_len,0
	mov	ax,spause	; wait spause milliseconds before sending pkt
	or	ax,ax		; zero?
	jz	spac1		; z = yes
	call	pcwait		;   to let other side get ready
spac1:	mov	cl,trans.spad	; get the number of padding chars
	xor	ch,ch
	jcxz	spac4		; z = none
	xor	al,al
	xchg	al,trans.sdbl	; doubling char, stash and clear it
	push	ax
	mov	al,trans.spadch	; get padding char
spac2:	call	spkout		; send padding char
	jnc	spac3		; nc = success
	ret			; failed
spac3:	loop	spac2
	pop	ax		; recover doubling char
	xchg	trans.sdbl,al

spac4:	call	snddeb		; do debug display (while it's still our turn)
	mov	al,trans.ssoh	; get the start of header char
	mov	prolog,al	; put SOH in the packet
	mov	si,stemp	; address of send pktinfo
	mov	al,[si].seqnum	; SEQ
	add	al,20h		; ascii bias
	mov	prolog+2,al	; store SEQ in packet
	xor	ah,ah
	mov	chksum,ax	; start checksum
	mov	al,prvtyp	; TYPE
	mov	word ptr prolog+3,ax ; store TYPE (and null terminator)
	add	chksum,ax	; add to checksum
;
; packet length type is directly governed here by length of header plus data
; field, [si].datlen, plus chksum: regular <= 94, long <= 9024, else X long.
;
	mov	ax,[si].datlen	; DATA length
	add	ax,2		; add SEQ, TYPE lengths
	cmp	trans.chklen,'B'-'0' ; B blank-free checksum?
	jne	spac12		; ne = no
	add	al,2		; B is a special two byte checksum
	jmp	short spac13
spac12:	add	al,trans.chklen	; add checksum length at the end
spac13:	adc	ah,0		; propagate carry, yields overall new length
	cmp	ax,[si].datsize	; too big?
	jle	spac14		; le = ok
	push	ax		; for carry-on-regardless after error
	push	dx		; tell user an internal error has occurred
	mov	dx,offset msgstl ; packet is too long
	call	ermsg1		; display message on error line
	call	captdol		; put into packet log
	pop	dx
	pop	ax
	jmp	short spac14	; carry-on-regardless

spac14:	mov	lentyp,3	; assume regular packet
	cmp	ax,94		; longer than a regular?
	ja	spac15		; a = use Long
	add	al,20h		; convert length to ascii
	mov	prolog+1,al	; store LEN
	xor	ah,ah
	add	chksum,ax	; add LEN to checksum
	mov	bx,offset prolog+4 ; look at data field
	jmp	spac19		; do regular

				; use Long packets (type 0)
spac15:	sub	ax,2		; deduct SEQ and TYPE from above = data+chksum
	mov	lentyp,0	; assume type 0 packet
	cmp	ax,(95*95-1)	; longest type 0 Long packet (9024)
	jbe	spac16		; be = type 0
	mov	lentyp,1	; type 1 packet, Extra Long
spac16:	mov	cl,lentyp	; add new LEN field to checksum
	add	cl,20h		; ascii bias, tochar()
	xor	ch,ch
	add	chksum,cx	; add to running checksum
	mov	prolog+1,cl	; put LEN into packet
	mov	bx,offset prolog+4
	mov	cx,1		; a counter
	xor	dx,dx		; high order numerator of length
spac17:	div	ninefive	; divide ax by 95. quo = ax, rem = dx
	push	dx		; push remainder
	inc	cx		; count push depth
	cmp	ax,95		; quotient >= 95?
	jae	spac17		; ae = yes, recurse
	push	ax		; push for pop below
spac18:	pop	ax		; get a digit
	add	al,20h		; apply tochar()
	mov	[bx],al		; store in data field
	add	chksum,ax	; accumulate checksum for header
	inc	bx		; point to next data field byte
	loop	spac18		; get the rest
				;
	mov	ax,chksum	; current checksum
	shl	ax,1		; put two highest bits of al into ah
	shl	ax,1
	and	ah,3		; want just those two bits
	shr	al,1		; put al back in place
	shr	al,1
	add	al,ah		; add two high bits to earlier checksum
	and	al,03fh		; chop to lower 6 bits (mod 64)
	add	al,20h		; apply tochar()
	mov	[bx],al		; store that in length's header checksum
	inc	bx
	xor	ah,ah
	add	chksum,ax	; add that byte to running checksum
				; end of inserting Long pkt info

spac19:	mov	cx,bx		; where we stopped+1
	mov	bx,offset prolog ; place where prolog section starts
	sub	cx,bx
	mov	prolog_len,cx
	dec	prolog_len
	jcxz	spac22		; nothing
	mov	prvlen,cx	; count sent bytes for echo suppression
	sub	prvlen,3	;  minus LEN, SEQ, TYPE
	test	cardet,1	; Carrier detect, was on and is now off?
	jnz	spac33		; nz = yes, fail
	add	pktcnt,cx	; count number of bytes sent in this packet
	push	es
	push	ds
	pop	es
	call	sndblk		; block send cx bytes from es:bx
	pop	es
	jc	spac33		; c = bad send

spac22:	test	cardet,1	; Carrier detect, was on and is now off?
	jnz	spac33		; nz = yes, fail
	push	es
	mov	si,stemp	; address of pktinfo
	les	bx,[si].datadr	; select from given data buffer
	mov	cx,[si].datlen	; get the number of data bytes in packet
	add	prvlen,cx	; count bytes sent
	add	pktcnt,cx	; count number of bytes sent in this packet
	push	cx
	call	sndblk		; block send cx bytes from es:bx
	pop	cx
	jnc	spac23		; nc = success
	pop	es		; clean stack
	jmp	spac33		; bad send

spac23:	or	cx,cx		; any data chars remaining?
	jle	spac25		; le = no, finish up
	cmp	trans.chklen,2	; what kind of checksum are we using?
	jg	spac25		; g = 3 characters, skip linear checksum
	xor	ah,ah
	mov	dx,chksum
spac24:	mov	al,es:[bx]	; get a data char
	inc	bx		; point to next char
	add	dx,ax		; add the char to the checksum [umd]
	loop	spac24
	and	dx,0fffh	; keep only low order 12 bits
	mov	chksum,dx

spac25:	pop	es
	mov	bx,offset epilog ; area for epilog
	mov	cx,chksum
	mov	bias,' '+1	; bias for checksum char (+1 for non-blank)
	cmp	trans.chklen,'B'-'0'; special non-blank checksum?
	je	spac27		; e = yes
	dec	bias		; use ' ' for regular packets
	cmp	trans.chklen,2	; what kind of checksum are we using?
	je	spac27		; e = 2 characters
	jg	spac26		; g = 3 characters
	mov	al,cl		; 1 char: get the character total
	mov	ch,cl		; save here too (need 'cl' for shift)
	and	al,0C0H		; turn off all but the two high order bits
	mov	cl,6
	shr	al,cl		; shift them into the low order position
	mov	cl,ch
	add	al,cl		; add it to the old bits
	and	al,3FH		; turn off the two high order bits.  (MOD 64)
	add	al,' '		; add a space so the number is printable
	mov	[bx],al		; put in the packet
	inc	bx		; point to next char
	jmp	short spac30

spac26:	push	bx		; don't lose our place
	push	es
	mov	bx,ds		; set up es for crcclc
	mov	es,bx		; es:[bx] is src of data for crcclc
	mov	bx,offset prolog+1 ; first checksummed char, skip SOH
	mov	cx,prolog_len
	xor	dx,dx		; initial CRC value is 0
	call	crcclc		; calculate the CRC of prolog part, to cx
	mov	dx,cx		; first part of CRC returned in cx
	mov	si,stemp	; address of pktinfo
	mov	cx,[si].datlen
	les	bx,[si].datadr	; address of data
	call	crcclc		; do CRC of data, using current CRC in dx
	pop	es
	pop	bx		; recover place to store more debug info
	push	cx		; save the crc
	mov	ax,cx		; manipulate it here
	and	ax,0F000H	; get 4 highest bits
	mov	cl,4
	shr	ah,cl		; shift over 4 bits
	add	ah,' '		; make printable
	mov	[bx],ah		; add to buffer
	inc	bx
	pop	cx		; get back checksum value
spac27:	push	cx		; save it for now
	and	cx,0FC0H	; get bits 6-11
	mov	ax,cx
	mov	cl,6
	shr	ax,cl		; shift them bits over
	add	al,bias		; make printable
	mov	[bx],al		; add to buffer
	inc	bx
	pop	cx		; get back the original
	and	cx,003FH	; get bits 0-5
	add	cl,bias		; make printable
	mov	[bx],cl		; add to buffer
	inc	bx

spac30:	mov	al,trans.seol	; get the EOL the other host wants
	xor	ah,ah
	mov	[bx],ax		; put eol and terminator in buffer
	inc	bx
	xor	ch,ch
	mov	cl,trans.chklen	; checksum length
	cmp	cl,'B'-'0'	; special non-blank checksum?
	jne	spac32		; ne = no
	mov	cl,2		; Blank checksum is a two byte affair
spac32:	add	prvlen,cx	; bytes sent
	inc	cx		; plus EOL char
	add	pktcnt,cx	; count number of bytes sent in this packet
	push	cx
	push	es
	mov	ax,seg epilog
	mov	es,ax
	mov	bx,offset epilog; where to find data
	call	sndblk		; block send cx bytes from es:bx
	pop	es
	pop	cx		; epilog byte count
       
spac33:	pushf			; save carry of how got here
	cmp	debflg,0	; recording material?
	je	spac34		; e = no
	call	showsend	; enter with CX holding epilog byte count

spac34:	mov	ax,pktcnt	; number of bytes sent in this packet
	add	fsta.psbyte,ax	; file total bytes sent
	adc	fsta.psbyte+2,0	; propagate carry to high word
	add	fsta.pspkt,1	; statistics, count a packet being sent
	adc	fsta.pspkt+2,0	;  ripple carry
	call	chkcon		; check console for user interrupts
	mov	si,stemp	; restore pkt pointer
	call	getbtime	; get Bios time of day to dx:ax
	mov	word ptr [si].sndtime,ax ; low order sent time
	mov	word ptr [si].sndtime+2,dx ; high order
	popf			; restore carry from spac33
	jc	spac35		; c = failure to send
	clc			; carry clear for success
	ret			; return successfully
spac35:	mov	dx,offset msgbadsnd ; say sending error in log
	call	captdol
	stc			; carry set for failure
	ret			; bad send
SPACK	ENDP 

spkout	proc	near
	test	cardet,1	; Carrier detect, was on and is now off?
	jz	spkou4		; z = no
	stc			; fail now
	ret
spkou4:	cmp	al,255		; possible Telnet IAC char?
	jne	spkou2		; ne = no
	cmp	flags.comflg,'t' ; internal Telnet?
	je	spkou3		; e = yes, double the char
spkou2:	cmp	al,trans.sdbl	; double this char?
	jne	spkou1		; ne = no
spkou3:	call	spkou1		; do it once here and again via fall through
	jnc	spkou1		;  but again only if no failure
	ret			; return failure
spkou1:	push	bx		; send char in al out the serial port
	push	cx		; return carry clear if success
	push	dx
	push	es
	cmp	debflg,0	; recording material?
	je	spkour		; e = no
	call	captchr		; record in debugging log
spkour:	mov	ah,al		; foutchr wants char in ah
	inc	pktcnt		; count number of bytes sent in this packet
	call	foutchr		; serial port transmitter procedure
	pop	es
	pop	dx
	pop	cx
	pop	bx		; carry set by foutchr if failure to send
	ret
spkout	endp

; Log sent packet to debug area
showsend proc	near
	push	cx		; save epilog byte count

	mov	bx,offset prolog ; place where prolog section starts
	mov	cx,prolog_len
	inc	cx		; include SOH
	jz	showp		; should never be zero
showp:	mov	al,[bx]
	inc	bx
	push	bx
	push	cx
	call	captchr
	pop	cx
	pop	bx
	loop	showp

showp1:	push	es
	mov	si,stemp	; offset of given packet structure
	les	bx,[si].datadr	; select from given data buffer
	mov	cx,[si].datlen	; get the number of data bytes in packet
	jcxz	showd1		; z = none
showd:	mov	al,es:[bx]	; get a data char
	inc	bx		; point to next char
	push	bx
	push	cx
	call	captchr
	pop	cx
	pop	bx
	loop	showd
showd1:	pop	es

	pop	cx		; recover epilog byte count
	jcxz	showe1		; should never be zero
	mov	bx,offset epilog
showe:	mov	al,[bx]
	inc	bx
	push	bx
	push	cx
	call	captchr		; record in debugging log
	pop	cx
	pop	bx
	loop	showe
	mov	dx,offset crlf
	call	captdol
showe1:	ret
showsend	endp
     
; Calculate the CRC of the string whose address is in ES:BX, length CX bytes.
; Returns the CRC in CX.  Destroys BX and AX.
; The CRC is based on the SDLC polynomial: x**16 + x**12 + x**5 + 1.
; Original by Edgar Butt  28 Oct 1987 [ebb].
; Enter with initial CRC in DX (normally 0).
crcclc: push	dx
	jcxz	crc1
crc0:	push	cx
	mov	ah,es:[bx]		; get the next char of the string
        inc	bx
        xor	dl,ah			; XOR input with lo order byte of CRC
        mov	ah,dl			; copy it
	mov	cl,4			; load shift count
        shl	ah,cl			; shift copy
        xor	ah,dl			; XOR to get quotient byte in ah
        mov	dl,dh			; high byte of CRC becomes low byte
        mov	dh,ah			; initialize high byte with quotient
        xor	al,al
        shr	ax,cl			; shift quotient byte
        xor	dl,ah			; XOR (part of) it with CRC
        shr	ax,1			; shift it again
        xor	dx,ax			; XOR it again to finish up
	pop	cx
	loop	crc0
crc1:   mov	cx,dx			; return CRC in CX
        pop	dx
        ret

; Receive_Packet
; This routine waits for a packet arrive from the host. Two Control-C's in a
; row from the comms line will cause a Control-C interruption exit.
; Returns
;	SI = pointer to pktinfo structure, as
;	[SI].SEQNUM - Packet sequence number
;	[SI].DATLEN - Number of data characters
;	[SI].DATADR - Address of data field for packet
; Returns AH -  packet type (letter code)
; Returns: carry clear if success, carry set if failure.
; Packet construction areas:
; 	Prolog (8 bytes+2 nulls)	null	Data	null  Epilog   null
;+----------------------------------------+---------------+---------------+
;| SOH,LEN,SEQ,TYPE,Xlen(2-3),Xlen chksum | packet's data | chksum,EOL,HS |
;+----------------------------------------+---------------+---------------+
; where Xlen is 2 byte (Long) or 3 byte (Extra Long) count of bytes to follow.

RPACK	PROC	FAR
	mov	rtemp,si		; save pkt structure address
	xor	ax,ax			; get a zero
	mov	badpflag,al		; bad parity flag, clear it
	mov	prevchar,al		; clear previous recv'd char area
	mov	bias,al			; assume not using special B chksum
	mov	[si].pktype,'T'		; assume 'T' type packet (timeout)
	mov	[si].datlen,ax		; init to empty buffer
	cmp	flags.comflg,'t'	; internal Telnet?
	jne	rpack11			; ne = no
	mov	trans.stime,0		; no timeouts
	jmp	rpack10
rpack11:mov	ax,word ptr [si].sndtime ; time at which pkt was sent
	or	ax,word ptr [si].sndtime+2
	jnz	rpack10			; nz = have a send time
	cmp	flags.timflg,0		; are timeouts turned off?
	je	rpack10			; e = yes, just check for more input
	cmp	trans.stime,0		; doing time outs?
	je	rpack10			; e = no, go check for more input
	call	getbtime		; get Bios time of day to dx:ax
	sub	ax,2			; make two bios ticks ago
	sbb	dx,0
	mov	word ptr [si].sndtime,ax ; low order sent time
	mov	word ptr [si].sndtime+2,dx ; high order
rpack10:xor	ax,ax
	push	es
	les	bx,[si].datadr		; caller's data buffer
	mov	word ptr es:[bx],ax	; clear storage areas (asciiz)
	pop	es
	mov	word ptr prolog,ax
	mov	prolog_len,ax
	mov	word ptr epilog,ax
	mov	bx,offset prolog	; bx is buffer offset pointer
	mov	pktcnt,ax		; number of bytes rcvd in packet
	mov	al,trans.rsoh		; start of packet char
	mov	SOHchar,al		; save, local copy is modified
	call	rcvdeb			; setup debug display
	mov	bx,seg prolog
	mov	es,bx
	mov	bx,offset prolog	; set es:bx for logging
	jmp	rpack0a

; Get here with unexpected char (SOH or before) and echos with printable SOH
rpack0:	push	ax			; save char which got us here
	mov	bx,rtemp		; pktinfo address
	mov	[bx].datlen,0		; say no data yet
	mov	[bx].seqnum,0ffh	; illegal value
	mov	[bx].pktype,0		; illegal value
	xor	ax,ax			; get a zero
	push	es
	les	bx,[bx].datadr	 	; point to data buffer
	mov	word ptr es:[bx],ax	; clear start of that buffer
	pop	es
	mov	bx,seg prolog
	mov	es,bx			; set buffer pointer
	mov	bx,offset prolog
	mov	word ptr prolog,ax	; clear prolog field
	mov	word ptr epilog,ax	; clear epilog field
	mov	pktcnt,ax		; count of chars
	mov	al,trans.rsoh		; start of packet char
	mov	SOHchar,al		; save, local copy is modified
	mov	al,trans.stime		; time to wait for start of packet
	mov	timeval,al		; local timer value, seconds
	pop	ax
	test	status,stat_int		; interrupted?
	jz	rpack0d			; z = no
	jmp	rpack60			; yes, exit now

rpack0d:mov	cx,status		; current status
	mov	status,stat_suc		; presume success
	test	cx,stat_echo		; doing echo processing?
	jnz	rpack0h			; nz = yes
	cmp	al,SOHchar		; read SOH?
	jne	rpack0a			; ne = no, get it
	jmp	rpack1			; go read LEN

rpack0h:cmp	trans.rsoh,' '		; printable SOH (special case)?
	jb	rpack0a			; b = no, normal, get normal SOH
	; For printable SOH we need to step over possible repetitions used in
	; the general data stream. Thus we wait the length of the sent pkt.
	; This will hopefully gobble up echos of the last sent packet.
	mov	cx,prvlen		; LEN field of last sent packet
	jcxz	rpack0a			; in case zero by some accident
	cmp	cx,256			; keep waiting bounded
	jbe	rpack0f			; be = not very large
	mov	cx,256			; this should be enough bytes to wait
rpack0f:push	cx
	call	inchr			; get and discard cx bytes
	pop	cx
	test	status,stat_tmo+stat_int ; timeout or user intervention?
	jz	rpack0g			; z = no
	jmp	rpack60			; timeout or user intervention, quit
rpack0g:loop	rpack0f			; keep discarding bytes
	mov	status,stat_suc		; assume success
	mov	cl,trans.stime		; time to wait for start of packet
	mov	timeval,cl		; local timer value, seconds
	call	inchr			; this reads the EOP byte echo, maybe
	jnc	rpack0b			; nc = not EOP, consider as SOP
					; else discard echoed EOP
rpack0a:mov	status,stat_suc		; assume success
	mov	cl,trans.stime		; time to wait for start of packet
	mov	timeval,cl		; local timer value, seconds
	call	inchr			; get a character. SOH
	jnc	rpack0b			; nc = got one
	test	status,stat_eol		; hit eol from prev packet?
	jnz	rpack0			; nz = yes, restart
	jmp	rpack60			; timeout or user intervention

rpack0b:mov	ah,al			; copy the char
	and	ah,7fh			; strip any parity bit, regardless
	cmp	ah,SOHchar		; start of header char?
	je	rpack0c			; e = yes, SOH
	jmp	rpack0			; ne = no, go until it is
rpack0c:xor	ah,ah			; clear the terminator byte
	cmp	SOHchar,' '		; printable SOHchar?
	jb	rpack1			; b = no (else start crippled mode)
	mov	SOHchar,ah		; yes, set it to null for no matches

rpack1:	cmp	flags.timflg,0		; are timeouts turned off?
	je	rpack1h			; e = yes
	cmp	flags.comflg,'t'	; internal Telnet?
	je	rpack1h			; e = yes, use TCP timing info
	mov	timeval,2		; reduce local timer value to 2 secs
rpack1h:call	inchr			; get a character. LEN
	jc	rpack1a			; failure
	and	al,7fh			; strip any parity bit
	cmp	al,SOHchar		; start of header char?
	jne	rpack1b			; ne = no
rpack1a:jmp	rpack0			; yes, start over (common jmp point)

rpack1b:mov	chksum,ax		; start the checksum
	sub	al,20h			; unchar(LEN) to binary
	jnc	rpack1e			; nc = legal (printable)
	or	status,stat_ptl		; set bad length status
	jmp	rpack40			; and quit
rpack1e:mov	si,rtemp
	mov	[si].datlen,ax		; save the data count (byte)
	call	inchr			; get a character. SEQ
	jc	rpack1a			; c = failure
	and	al,7fh			; strip any parity bit
	cmp	al,SOHchar		; SOH?
	je	rpack1a			; e = yes, then go start over
	add	chksum,ax
	sub	al,' '			; get the real packet number
	jnc	rpack1f			; nc = no overflow
	or	status,stat_ptl		; say bad status
	jmp	rpack40			; and exit now
rpack1f:mov	si,rtemp
	mov	[si].seqnum,al		; save the packet number. SEQ
	call	inchr			; get a character. TYPE
	jc	rpack1a			; c = failure
	and	al,7fh			; strip any parity bit
	cmp	al,SOHchar		; SOH?
	je	rpack1a			; e = yes, then go start over
	mov	[si].pktype,al		; save the message type
	cmp	al,prvtyp		; echo of sent packet?
	jne	rpack1g			; ne = no
	or	status,stat_echo	; status is echo processing
	mov	dx,offset msgecho 	; say echo in log
	call	captdol
	jmp	rpack0			; start over

rpack1g:add	chksum,ax		; add it to the checksum
	call	parchk			; check parity on protocol characters
	call	getlen		; get complicated data length (reg, lp, elp)
				; into [si].datlen and kind into byte lentyp. carry set if error
	jnc	rpack1c			; nc = packet is ok so far
	jmp	rpack40			; failure
rpack1c:
; Start of change.
; Now determine block check type for this packet.  Here we violate the layered
; nature of the protocol by inspecting the packet type in order to detect when
; the two sides get out of sync.  Two heuristics allow us to resync here:
;   a. I and S packets always have a type 1 checksum.
;   b. A NAK never contains data, so its block check type is len - 1.
	mov	si,rtemp		; pktinfo address
	mov	ch,trans.chklen		; current checksum length
	cmp	ch,'B'-'0'		; special non-blank kind?
	jne	rpk4			; ne = no
	mov	ch,2			; yes, it's a special 2-byte flavor
rpk4:	mov	ax,[si].datlen		; length of packet information
	mov	cl,[si].pktype		; packet type byte itself
	cmp	cl,'S'			; "S" packet?
	jne	rpk0			; ne = no
	mov	ch,1			; S packets use one byte checksums
	jmp	short rpk3
rpk0:	cmp	cl,'I'			; I packets are like S packets
	jne	rpk1
	mov	ch,1			; I packets use one byte checksums
	jmp	short rpk3
rpk1:	cmp	cl,'N'			; NAK?
	jne	rpk3			; ne = no
	cmp	ax,1			; NAK, get length of data + chklen
	jb	rpk1a			; b = impossible length
	cmp	ax,3			; longest NAK (3 char checksum)
	jbe	rpk2			; be = possible
rpk1a:	or	status,stat_ptl		; status = bad length
	jmp	rpack40			; return on impossible length
rpk2:	mov	trans.chklen,al		; remainder must be checksum type
	mov	ch,al
rpk3:	sub	al,ch			; minus checksum length, for all pkts
	sbb	ah,0			; propagate borrow
	mov	[si].datlen,ax		; store apparent length of data field
	mov	chklength,ch		; remember for checking below
; End of change.
; For long packets we start the real data (after the extended byte
; count 3 or 4 bytes).
	sub	bx,offset prolog+1	; compute length of prolog (skip SOH)
	mov	prolog_len,bx

	mov	si,rtemp
	mov	dx,[si].datlen		; length of data field, excl LP header
	mov	chrcnt,dx
	cmp	dx,[si].datsize		; material longer than data buffer?
	jbe	rpk8c			; be = no
rpk8b:	or	status,stat_ptl		; failure status, packet too long
	jmp	rpack40			; too big, quit now
rpk8c:	les	bx,[si].datadr	 	; point to offset of data buffer
	mov	word ptr es:[bx],0	; clear start of that buffer

					; get DATA field characters
rpack2:	push	chrcnt			; save data length to be examined
	xor	cl,cl
	xchg	debflg,cl		; debugging done in checksum section
	push	cx			;  for data field bytes
rpak21:	cmp	chrcnt,0		; done all?
	jle	rpak25			; le = yes
	cmp	portcount,0		; any bytes ready to read?
	je	rpak22			; e = no, do timed read single byte
	mov	cx,chrcnt		; bytes wanted
	call	prtblk			; do block read of cx bytes to es:[bx]
	mov	portcount,dx		; available bytes
	jc	rpak22			; c = failed
	add	pktcnt,cx		; count bytes received
	sub	chrcnt,cx		; needed minus supplied = to be read
	jmp	short rpak21		; try to read more

					; do 1 byte timed read and check
rpak22:	call	inchr			; get a character into al. DATA
	jc	rpak23			; c = Control-C, timeout, eol
	dec	chrcnt			; count byte read
	cmp	al,SOHchar		; start of header char?
	jne	rpak21			; ne = no, read more data
	jmp	short rpak24		; yes, then go start over
rpak23:	test	status,stat_eol		; bare EOL in data part?
	jz	rpak24			; z = no, must be bad news, quit
	and	status,not stat_eol	; turn off status bit
	dec	chrcnt			; accept byte
	jmp	short rpak21		;  and carry on regardless

rpak24:	pop	cx			; failure
	xchg	debflg,cl		; restore debugging
	mov	cx,chrcnt		; bytes remaining to be read
	pop	chrcnt			; recover length of data field
	sub	chrcnt,cx		; reduce length available to log
	cmp	debflg,0		; recording material?
	je	rpak24b			; e = no
	call	rlogdata		; log data bytes
rpak24b:jmp	rpack40			; failed

rpak25:	pop	cx
	xchg	debflg,cl		; restore debugging
	pop	chrcnt			; recover length of data field
	cmp	debflg,0		; recording material?
	je	rpak26			; e = no
	call	rlogdata		; log data field bytes
rpak25a:cmp	chklength,2		; which checksum length is in use?
	ja	rpack3			; a = Three char CRC, skip chksum
rpak26:	mov	cx,chrcnt		; length of data field
	jcxz	rpack3			; z = empty, nothing to do
	mov	dx,chksum		; linear checksum thus far
	push	si
	push	ds
	lds	si,[si].datadr	 	; point to offset of data buffer
	xor	ah,ah
	cld
rpak27:	lodsb
	add	dx,ax			; add bytes to checksum
	loop	rpak27
	pop	ds
	pop	si
	mov	chksum,dx
 
rpack3:	and	chksum,0fffh	; keep only lower 12 bits of current checksum
	mov	bx,offset epilog	; record debugging in epilog buffer
	mov	ax,seg epilog
	mov	es,ax
	mov	word ptr es:[bx],0
	call	inchr			; start Checksum bytes
	jc	rpack3b			; failed
	mov	ah,al
	and	ah,7fh			; strip high bit
	cmp	ah,SOHchar		; start of header char?
	jne	rpack3a			; ne = no
	jmp	rpack0			; yes, then go start over
rpack3a:sub	al,' '			; unchar() back to binary
	mov	cx,chksum		; current checksum
	cmp	chklength,2		; which checksum length is in use?
	je	rpack5			; e = Two character checksum
	ja	rpack4			; a = Three char CRC, else one char
	shl	cx,1			; put two highest digits of al into ah
	shl	cx,1
	and	ch,3			; want just those two bits
	shr	cl,1			; put al back in place
	shr	cl,1
	add	cl,ch			;add two high bits to earlier checksum
	and	cl,03fh			; chop to lower 6 bits (mod 64)
	cmp	cl,al		; computed vs received checksum byte (binary)
	je	rpack3b			; e = equal, so finish up
	or	status,stat_chk		; say checksum failure
rpack3b:jmp	rpack40

rpack4:	mov	tmp,al			; save value from packet here
	push	bx			; three character CRC
	push	es
	mov	bx,seg prolog
	mov	es,bx
	mov	bx,offset prolog+1	; where data for CRC is, skipping SOH
	mov	cx,prolog_len		; length of prolog field
	xor	dx,dx			; initial CRC is zero
	call	crcclc			; calculate the CRC and put into CX
	mov	dx,cx			; previous CRC
	mov	bx,rtemp
	mov	cx,[bx].datlen		; length of data field
	les	bx,[bx].datadr		; data field segment
	call	crcclc			; final CRC is in CX
	mov	chksum,cx		; save computed checksum
	pop	es
	pop	bx
	mov	ah,ch			; cx = 16 bit binary CRC of rcv'd data
	and	ah,0f0h			; manipulate it here
	shr	ah,1
	shr	ah,1			; get 4 highest bits
	shr	ah,1
	shr	ah,1			; shift right 4 bits
	cmp	ah,tmp			; is what we got == calculated?
	je	rpack4a			; e = yes
	or	status,stat_chk		; checksum failure
rpack4a:call	inchr			; get next character of checksum
	jc	rpack40			; c = failed
	and	al,7fh			; strip high bit
	cmp	al,SOHchar		; SOH?
	jne	rpack4b			; ne = no
	jmp	rpack0			; start over
rpack4b:sub	al,' '			; get back real value
					; two character checksum + CRC
rpack5:	mov	ch,al			; save last char here for now
	mov	ax,chksum
	and	ax,0fc0h		; get bits 11..6
	mov	cl,6
	shr	ax,cl			; shift bits
	cmp	al,ch			; equal?
	je	rpack5a			; e = yes
	mov	bias,1			; try adding bias
	inc	al			; try 'B' method of +1 on bias
	cmp	al,ch			; same?
	je	rpack5a			; matched
	or	status,stat_chk		; checksum failure
rpack5a:call	inchr			; get last character of checksum
	jc	rpack40			; c = failed
	and	al,7fh			; strip high bit
	cmp	al,SOHchar		; SOH?
	jne	rpack5b			; ne = no
	jmp	rpack0			; e = yes
rpack5b:sub	al,' '			; get back real value
	mov	cx,chksum
	and	cl,3FH			; get bits 0-5
	add	cl,bias			; try 'B' method of +1 on bias
	cmp	al,cl			; do the last chars match?
	je	rpack40			; e = yes
	or	status,stat_chk		; say checksum failure

rpack40:test	status,stat_tmo		; timeout?
	jz	rpack41			; z = no
	jmp	rpack60			; nz = yes
rpack41:test	status,stat_eol		; premature eol?
	jz	rpack42			; z = no
	or	status,stat_bad		; say bad packet overall
	jmp	short rpack45		; now try for handshake

rpack42:call	inchr			; get eol char
	jnc	rpack43			; nc = got regular character
	test	status,stat_int		; interrupted?
	jnz	rpack60			; nz = yes
rpack43:and	status,not stat_tmo	; ignore timeouts on EOL character
	test	status,stat_eol		; eol char?
	jnz	rpack44			; nz = yes, got the EOL char
	and	al,7fh			; strip high bit
	cmp	al,SOHchar		; SOH already?
	jne	rpack44			; ne = no
	jmp	rpack0			; yes, start over

rpack44:and	status,not stat_eol 	; desired eol is not an error
					; test for line turn char
rpack45:mov	bx,portval		;   if doing handshaking
	cmp	[bx].hndflg,0		; doing half duplex handshaking?
	je	rpack60			; e = no
	mov	ah,[bx].hands		; get desired handshake char
	mov	tmp,ah			; keep handshake char here
	mov	bx,seg epilog		; where to store character
	mov	es,bx
	mov	bx,offset epilog
rpack45b:call	inchr			; get handshake char
	jnc	rpack46			; nc = regular character
	test	status,stat_eol		; EOL char?
	jnz	rpack46			; nz = yes
	jmp	short rpack48		; timeout or user intervention
rpack46:and	status,not stat_eol	; ignore unexpected eol status here
	and	al,7fh			; strip high bit
	cmp	al,SOHchar		; SOH already?
	jne	rpack47			; ne = no
	jmp	rpack0			; yes, start over
rpack47:cmp	al,tmp			; compare received char with handshake
	jne	rpack45		; ne = not handshake, try again til timeout
rpack48:and	status,not stat_tmo	; ignore timeouts on handshake char

					; Perform logging and debugging now
rpack60:call	chkcon			; check console for user interrupt
	cmp	debflg,0		; recording packets?
	je	rpack66			; e = no
	mov	dx,offset crlf
	call	captdol			; end current display line
	cmp	status,stat_suc		; success?
	je	rpack66			; e = yes
	mov	dx,offset msgheader	; starting "<"
	call	captdol
	test	status,stat_tmo		; timeout?
	jz	rpack61			; no
	mov	dx,offset msgtmo 	; say timeout in log
	call	captdol
	mov	si,rtemp
	mov	ah,'T'			; return packet type in ah
	mov	[si].pktype,ah		; say 'T' type packet (timeout)
rpack61:test	status,stat_chk		; checksum bad?
	jz	rpack62			; z = no
	mov	dx,offset msgchk
	call	captdol
rpack62:test	status,stat_ptl		; packet too long?
	jz	rpack63			; z = no
	mov	dx,offset msgptl
	call	captdol
rpack63:test	status,stat_int		; user interruption?
	jz	rpack64			; z = no
	mov	dx,offset msgint
	call	captdol
rpack64:test	status,stat_bad		; premature EOL?
	jz	rpack65			; z = no
	mov	dx,offset msgbad
	call	captdol
rpack65:mov	dx,offset msgtail	; end of error cause field
	call	captdol

rpack66:mov	ax,pktcnt		; number of bytes received in packet
	add	fsta.prbyte,ax		; file total received pkt bytes
	adc	fsta.prbyte+2,0		; propagate carry to high word
	add	fsta.prpkt,1		; file received packets
	adc	fsta.prpkt+2,0		;  ripple carry
	mov	si,rtemp		; restore pkt pointer
	mov	ah,[si].pktype		; return packet TYPE in ah
	cmp	status,stat_suc		; successful so far?
	jne	rpack72			; ne = no
	cmp	chkparflg,0		; do parity checking?
	je	rpack71			; e = no
	mov	chkparflg,0		; do only once
	test	badpflag,80h		; get parity error flagging bit
	jz	rpack71			; z = no parity error
	mov	bx,portval
	mov	cl,badpflag		; get new parity plus flagging bit
	and	cl,7fh			; strip flagging bit
	mov	[bx].parflg,cl		; force new parity
rpack71:clc				; carry clear for success
	ret
rpack72:stc				; carry set for failure
	ret				; failure exit
RPACK	ENDP

; Get packet if enough bytes for minimal pkt and SOP has been seen. Returns
; carry set if unable, else use Rpack to deliver the packet. Call the same
; as Rpack.
peekreply proc	far
	call	peekcom			; get comms SOP count
	jnc	peekrp1			; nc = have some bytes
	ret				; return carry set for nothing to do
peekrp1:cmp	cx,6			; enough for basic NAK?
	jb	peekrp2			; be = no
	mov	si,offset rpacket	; reset pointer needed at start
	jmp	rpack			; go decode the packet
peekrp2:stc				; say nothing to do
	ret
peekreply endp

; Check Console (keyboard). Return carry setif "action" chars: cr for forced
; timeout, Control-E for force out Error packet, Control-C for quit work now.
; Return carry clear on Control-X and Control-Z as these are acted upon by
; higher layers. Consume and ignore anything else.
chkcon:	call	isdev		; is stdin a device and not a disk file?
	jnc	chkco5		; nc = no, a disk file so do not read here
	mov	dl,0ffh
	mov	ah,dconio		; read console
	int	dos
	jz	chkco5			; z = nothing there
	and	al,1fh			; make char a control code
	cmp	al,CR			; carriage return?
	je	chkco3			; e = yes, simulate timeout
	cmp	al,'C'-40h		; Control-C?
	je	chkco1			; e = yes
	cmp	al,'E'-40h		; Control-E?
	je	chkco1			; e = yes
	cmp	al,'X'-40h		; Control-X?
	je	chkco4			; e = yes
	cmp	al,'Z'-40h		; Control-Z?
	je	chkco4		; record it, take no immmediate action here
	cmp	al,'Q'-40h		; Control-Q?
	je	chkco6			; e = yes
	or	al,al			; scan code being returned?
	jnz	chkco5			; nz = no, ignore ascii char
	mov	ah,dconio		; read and discard second byte
	mov	dl,0ffh
	int	dos
	jmp	short chkco5		; else unknown, ignore
chkco1:	or	al,40h			; make Control-C-E printable
	mov	flags.cxzflg,al		; remember what we saw
chkco2:	or	status,stat_int		; interrupted
	stc
	ret				; act now
chkco3:	or	status,stat_tmo		; CR simulates timeout
	stc
	ret				; act now
chkco4:	or	al,40h			; make control-X-Z printable
	mov	flags.cxzflg,al		; put into flags
	clc				; do not act on them here
	ret
chkco5:	cmp	flags.cxzflg,'C'	; control-C intercepted elsewhere?
	je	chkco2			; e = yes
	clc				; else say no immediate action needed
	ret
chkco6:	xchg	ah,al			; put Control-Q in AH for transmission
	call	spkout			; send it now
	jmp	short chkco5

getlen	proc	near		; compute packet length for short & long types
				; returns length in [si].datlen and
				; length type (0, 1, 3) in local byte lentyp
				; returns length of  data + checksum
	mov 	si,rtemp
	mov	ax,[si].datlen	; get LEN byte value
	and	ax,7fh		; clear unused high byte and parity bit

	cmp	al,3		; regular packet has 3 or larger here
	jb	getln1		; b = long packet
	sub	[si].datlen,2	; minus SEQ and TYPE = DATA + CHKSUM
	mov	lentyp,3	; store assumed length type (3 = regular)
	clc			; clear carry for success
	ret

getln1:	push	cx		; counter for number of length bytes
	mov	lentyp,0	; store assumed length type 0 (long)
	mov	cx,2		; two base-95 digits
	or	al,al		; is this a type 0 (long packet)?
	jz	getln2		; z = yes, go find & check length data
	mov	lentyp,1	; store length type (1 = extra long)
	inc	cx		; three base 95 digits
	cmp	al,1		; is this a type 1 (extra long packet)?
	je	getln2		; e = yes, go find & check length data
	pop	cx
	or	status,stat_ptl	; say packet too long (an unknown len code)
	stc			; set carry bit to say error
	ret
getln2:				; chk header chksum and recover binary length
	push	dx		; save working reg
	xor	ax,ax		; clear length accumulator, low part
	mov	[si].datlen,ax	; clear final length too
getln3:	xor	dx,dx		; ditto, high part
	mov	ax,[si].datlen	; length to date
	mul	ninefive	; multiply accumulation (in ax) by 95
	mov	[si].datlen,ax	; save results
	push	cx
	call	inchr		; read another serial port char into al
	pop	cx
	jc	getln4		; c = failure
	add	chksum,ax
	sub	al,20h		; subtract space, apply unchar()
	js	getln4		; sign set is failure
	mov	si,rtemp
	add	[si].datlen,ax	; add to overall length count
	loop	getln3		; cx preset earlier for type 0 or type 1
	mov	dx,chksum	; get running checksum
	shl	dx,1		; get two high order bits into dh
	shl	dx,1
	and	dh,3		; want just these two bits
	shr	dl,1		; put low order part back
	shr	dl,1
	add	dl,dh		; add low order byte to two high order bits
	and	dl,03fh		; chop to lower 6 bits (mod 64)
	add	dl,20h		; apply tochar()
	push	dx
	call	inchr		; read another serial port char
	pop	dx
	jc	getln4		; c = failure
	add	chksum,ax
	cmp	dl,al		; our vs their checksum, same?
	je	getln5		; e = checksums match, success
getln4:	or	status,stat_chk	; checksum failure
	pop	dx		; unsave regs (preserves flags)
	pop	cx
	stc			; else return carry set for error
	ret
getln5:	pop	dx		; unsave regs (preserves flags)
	pop	cx
	clc			; clear carry (say success)
	ret
getlen	endp

; Get char from serial port into al, with timeout and console check.
; Return carry set if timeout or console char or EOL seen,
; return carry clear and char in AL for other characters.
; Sets status of stat_eol if EOL seen.
inchr	proc	near
	mov	timeit,0	; reset timeout flag (do each char separately)
	push	es		; save debug buffer pointer es:bx
	push	bx
inchr1:	call	prtchr1		; read a serial port character
	mov	portcount,dx	; bytes remaining in ready-to-read buffer
	jc	inchr2		; c = nothing there
	pop	bx		; here with char in al from port
	pop	es		; debug buffer pointer
	mov	ah,al		; copy char to temp place AH
	and	ah,7fh		; strip parity bit from work copy
	and	al,parmsk	; apply 7/8 bit parity mask
	cmp	debflg,0	; recording material?
	je	inchr1a		; e = no
	call	captchr		; log char in al
inchr1a:inc	pktcnt		; count received byte
	test	flags.remflg,dserver ; acting as a server?
	jz	inchr6		; z = no
	cmp	ah,'C'-40h	; Control-C from comms line?
	jne	inchr6		; ne = no
	cmp	ah,prevchar	; was previous char also Control-C?
	jne	inchr6		; ne = no
	cmp	ah,SOHchar	; could Control-C also be an SOH?
	je	inchr6		; e = yes, do not exit
	cmp	ah,trans.reol	; could Control-C also be an EOL?
	je	inchr6		; e = yes
	test	denyflg,finflg	; is FIN enabled?
	jnz	inchr6		; nz = no, ignore server exit cmd
	mov	flags.cxzflg,'C'; set Control-C flag
	or	status,stat_int+stat_eol ; say interrupted and End of Line
	mov	al,ah		; use non-parity version
	xor	ah,ah		; always return with high byte clear
	mov	es:[bx],ax	; store char and null in debugging buffer
	inc	bx
	stc			; exit failure
	ret
inchr6:	mov	prevchar,ah	; remember current as previous char
	cmp	ah,trans.reol	; eol char we want?
	je	inchr7		; e = yes, ret with carry set
	xor	ah,ah		; always return with high byte clear
	mov	es:[bx],ax	; store char and null in buffer
	inc	bx
	clc			; char is in al
	ret

inchr7:	or	status,stat_eol	; set status appropriately
	xor	ah,ah		; always return with high byte clear
	mov	es:[bx],ax	; store char and null in buffer
	inc	bx
	stc			; set carry to say eol seen
	ret			; and return qualified failure
	
inchr2:	mov	bx,portval
	cmp	[bx].portrdy,0	; is port not-ready?
	jne	inchr2c		; ne = no, port is ready, just no char
	or	status,stat_int	; interrupted
	stc			; return failure (interruption)
	pop	bx
	pop	es
	ret

inchr2c:call	chkcon		; check console (about 250 microseconds)
	jnc	inchr2a		; nc = nothing to interrupt us
	pop	bx		; clean stack
	pop	es
	ret			; return failure for interruption

inchr2a:cmp	flags.timflg,0	; are timeouts turned off?
	je	inchr1		; e = yes, just check for more input
	cmp	timeval,0	; turned off running timeouts on receive?
	je	inchr1		; e = yes
	cmp	trans.stime,0	; doing time outs?
	je	inchr1		; e = no, go check for more input
	push	cx		; save regs
	push	dx
	cmp	timeit,0	; have we gotten time of day for first fail?
	jne	inchr4		; ne = yes, just compare times
	push	ax
	push	dx
	call	krto		; get current round trip timeout value
	call	getbtime	; get Bios time to dx:ax
	add	ax,k_rto	; add Bios ticks of timeout interval
	adc	dx,0
	mov	word ptr rptim,ax
	mov	word ptr rptim+2,dx
	pop	dx
	pop	ax
	mov	timeit,1	; say have tod of timeout
	jmp	short inchr4d

inchr4:	call	getbtime	; get Bios time
	cmp	dx,word ptr rptim+2 ; high order word
	ja	inchr4c		; a = we are late
	jb	inchr4d		; b = we are early
	cmp	ax,word ptr rptim ; low order word
	ja	inchr4c		; a = we are late
	jmp	inchr4d		; not timed out yet

inchr4c:or	status,stat_tmo	; say timeout
	pop	dx
	pop	cx
	pop	bx
	pop	es
	stc			; set carry bit
	ret			; failure
inchr4d:pop	dx
	pop	cx
	jmp	inchr1		; not timed out yet
inchr	endp

				; Packet Debug display routines
rcvdeb:	test	flags.debug,logpkt ; In debug mode?
	jnz	rcvde1		; nz = yes
	test	flags.capflg,logpkt ; log packets?
	jnz	rcvde1		; nz = yes
	ret			; no
rcvde1:	mov	debflg,'R'	; say receiving
	jmp	short deb1

snddeb:	test	flags.debug,logpkt ; In debug mode?
	jnz	sndde1		; nz = yes
	test	flags.capflg,logpkt ; log packets?
	jnz	sndde1		; yes
	ret			; no
sndde1:	mov	debflg,'S'	; say sending

deb1:	push	di		; Debug. Packet display
	test	flags.debug,logpkt	; is debug active (vs just logging)?
	jz	deb1e		; z = no, just logging
	cmp	fmtdsp,0	; non-formatted display?
	je	deb1d		; e = yes, skip extra line clearing
	cmp	debflg,'R'	; receiving?
	je	deb1a		; e = yes
	call	sppos1		; spack: cursor position
	jmp	short deb1b
deb1a:	call	rppos1		; rpack: cursor position
deb1b:	mov	cx,4		; clear 4 lines
deb1c:	push	cx
	call	clearl1		; clear the line
        mov	dx,offset crlf
        mov	ah,prstr	; display
        int	dos
	pop	cx
	loop	deb1c
	cmp	debflg,'R'	; receiving?
	je	deb1d		; e = yes
	call	sppos1		; reposition cursor for spack:
	jmp	short deb1e
deb1d:	call	rppos1		; reposition cursor for rpack:
deb1e:	mov	dx,offset spmes	; spack: message
	cmp	debflg,'R'
	jne	deb2		; ne = sending
	mov	dx,offset rpmes	; rpack: message
deb2:	mov	colcnt,0	; number of columns used so far
	mov	linecnt,0	; no lines completed yet
	call	captdol		; record dollar terminated string in Log file
	pop	di
	ret


captdol	proc	near		; write dollar sign terminated string in dx
				; to the capture file (Log file).
	push	ax		; save regs
	push	si
	push	es
	mov	si,dx		; point to start of string
	cld
captdo1:lodsb			; get a byte into al
	cmp	al,'$'		; at the end yet?
	je	captdo3		; e = yes
	or	al,al		; asciiz?
	jz	captdo3		; z = yes, this is also the end
	inc	colcnt
	cmp	al,lf		; new line?
	jne	captdo4		; ne = no
	inc	linecnt		; count displayed lines
	mov	colcnt,0	; start of new line
captdo4:test	flags.debug,logpkt ; debug display active?
	jz	captdo2		; z = no
	cmp	linecnt,4	; four lines used on screen?
	jae	captdo2		; ae = yes, omit more lines
	push	ax
	mov	dl,al
	mov	ah,conout
	int	dos		; display char in dl
	pop	ax
captdo2:test	flags.capflg,logpkt ; logging active?
	jz	captdo1		; z = no
	call	fpktcpt		; record the char, pktcpt is in msster.asm
	jmp	short captdo1	; repeat until dollar sign is encountered
captdo3:pop	es
	pop	si
	pop	ax
	ret
captdol	endp

captchr	proc	near		; record char in AL into the Log file
	test	flags.debug,logpkt ; debug display active?
	jnz	captch1		; nz = yes
	test	flags.capflg,logpkt ; logging active?
	jnz	captch1		; nz = yes
	ret
captch1:push	ax
	push	es
	test	al,80h		; high bit set?
	jz	captch2		; z = no
	push	ax
	mov	al,'~'
	call	captworker	; record the char
	pop	ax
	and	al,not 80h
captch2:cmp	al,DEL		; DEL?
	je	captch2a	; e = yes
	cmp	al,' '		; control char?
	jae	captch4		; ae = no
captch2a:add	al,40h		; uncontrollify the char
	push	ax		; save char in dl
	mov	al,5eh		; show caret before control code
	call	captworker	; record the char
	cmp	colcnt,70	; exhausted line count yet?
	jb	captch3		; b = not yet
	mov	al,CR
	call	captworker
	mov	al,LF
	call	captworker
captch3:pop	ax		; recover char in dl
captch4:call	captworker	; record the char
	cmp	colcnt,70
     	jb	captch5		; b = not yet
	mov	al,CR
	call	captworker
	mov	al,LF
	call	captworker
captch5:pop	es
	pop	ax
	ret
captchr	endp

captworker proc	near
	inc	colcnt		; count new character
	cmp	al,LF		; new line?
	jne	captw3		; ne = no
	inc	linecnt		; count displayed lines
	mov	colcnt,0	; start of new line
captw3:	test	flags.debug,logpkt ; debug display active?
	jz	captw1		; z = no
	cmp	linecnt,4	; four lines used on screen?
	jae	captw1		; ae = yes, omit more lines
	push	ax
	mov	dl,al
	mov	ah,conout
	int	dos
	pop	ax
captw1:	test	flags.capflg,logpkt ; logging active?
	jz	captw2		; z = no
	call	fpktcpt		; log to file
captw2:	ret
captworker endp

; Log bytes received in data 
rlogdata proc	near
	push	cx
	mov	cx,chrcnt		; bytes in data field
	jcxz	rlogda2			; z = none
	push	si			; log data field
	push	es
	les	si,[si].datadr	 	; point to offset of data buffer
	xor	ah,ah
	cld
rlogda1:mov	al,es:[si]
	inc	si
	push	cx
	push	si
	call	captchr			; log char in al
	pop	si
	pop	cx
	loop	rlogda1
	pop	es
	pop	si
rlogda2:pop	cx
	ret
rlogdata endp

parchk	proc	near			; check parity of pkt prolog chars
	cmp	chkparflg,0		; ok to check parity?
	jne	parchk0			; ne = yes
	ret
parchk0:push	ax
	push	bx
	push	cx
	push	dx
	mov	chkparflg,0		; don't check again until asked
	mov	ax,word ptr prolog	; first two prolog chars
	or	ax,word ptr prolog+2	; next two
	test	ax,8080h		; parity bit set?
	jz	parchk7			; z = no
	mov	parmsk,7fh		; set parity mask for 7 bits
	cmp	badpflag,0		; said bad parity once this packet?
	jne	parchk7			; ne = yes
	mov	cx,4			; do all four protocol characters
	xor	dx,dx			; dl=even parity cntr, dh=odd parity
	mov	bx,offset prolog
parchk1:mov	al,[bx]			; get a char
	inc	bx			; point to next char
	or	al,al			; sense parity
	jpo	parchk2			; po = odd parity
	inc	dl			; count even parity
	jmp	short parchk3
parchk2:inc	dh			; count odd parity
parchk3:loop	parchk1			; do all four chars
	cmp	dl,4			; got four even parity chars?
	jne	parchk4			; ne = no
	mov	badpflag,parevn+80h	; say even parity and flagging bit
	mov	dx,offset msgbadpare	; say using even parity
	jmp	short parchk6
parchk4:cmp	dh,4			; got four odd parity chars?
	jne	parchk5			; ne = no
	mov	badpflag,parodd+80h	; say odd parity and flagging bit
	mov	dx,offset msgbadparo	; say using odd parity
	jmp	short parchk6
parchk5:mov	badpflag,parmrk+80h	; say mark parity and flagging bit
	mov	dx,offset msgbadparm	; say using mark parity
parchk6:call	ermsg1
	call	captdol			; write in log file too
parchk7:pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
parchk	endp

; General packet buffer structure manipulation routines. The packet buffers
; consist of a arrays of words, bufuse and buflist, an array of pktinfo
; structure packet descriptors, and a malloc'd main buffer.
; Each pktinfo member describes a packet by holding the address (seg:offset 
; within segment data) of the data field of a packet (datadr), the length of 
; that field in bytes (datsize), the number of bytes currently occupying that 
; field (datlen), the packet sequence number, an ack-done flag byte, and the 
; number of retries of the packet.
; The data field requires a null terminator byte in packet routines rpack and
; spack. Trans.windo buffers are constructed by procedure makebuf.
; Bufuse is an array holding an in-use flag for each pktinfo member; 0 means
; the member is free, otherwise a caller has allocated the member via getbuf.
; Buflist holds the address (offset in segment 'data') of each pktinfo member,
; for rapid list searching.
;
; Packet structures are constructed and initialized by procedure makebuf.
; Other procedures below access the members in various ways. Details of
; buffer construction should remain local to these routines.
; Generally, SI is used to point to a pktinfo member and AL holds a packet
; sequence number (0 - 63 binary). BX and CX are used for some status reports.
;
;  bufuse	buflist		    pktlist (group of pktinfo members)
;  -------	-------		-------------------------------------------
; 0 for unused		      | datadr,datlen,datsize,seqnum,ackdone,numtry |
; 	   	pointers to ->+ datadr,datlen,datsize,seqnum,ackdone,numtry |
; 1 for used		      | datadr,datlen,datsize,seqnum,ackdone,numtry |
;						etc
;
; Construct new buffers, cleared, by computing the amount of DOS free memory,
; allocating as much as (window slots * desired packet length). When there
; is not enough memory shorten the packet length to yield the desired number
; of window slots. 
; This is called two ways: a protocol initialization stage with one normal
; length packet and a post negotiation stage with a stated length of packet.
; The first state finds the maximum available memory for packet buffers as
; well as allocating one regular packet from it. The second stage always
; follows spar() and that routine needs the maximum memory figure.
; Enter with trans.windo equal to the number of buffer slots and CX equal
; to the length of each buffer (we add one byte for null terminator here).
; Return word maxbufparas as number of paragraphs in free memory before
; allocations are done here.
makebuf	proc	far
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	mov	di,cx			; save real packet length
	mov	ax,pbufseg		; current buffer segment
	or	ax,ax			; segment allocated already?
	jz	makebu1			; z = no
	push	es
	mov	es,ax			; allocated segment
	mov	ah,freemem		; free it
	int	dos
	pop	es
makebu1:mov	bx,0ffffh		; allocate biggest chunk of memory
	mov	ah,alloc
	int	dos			; must fail, bx gets number paras free
	mov	maxbufparas,bx		; report max paragraphs available
	mov	al,trans.windo		; number of window slots
	xor	ah,ah
	or	ax,ax			; zero?
	jnz	makebu2			; nz = no
	inc	ax
	mov	trans.windo,al		; zero means one slot
makebu2:add	cx,15			; round, space for null at end of pkt
	and	cx,0fff0h		; and truncate
	mul	cx			; times pkt size per window slot
	mov	cx,4
makebu3:shr	dx,1			; divide double word by 16, to paras
	rcr	ax,1
	loop	makebu3			; ax gets paragraphs wanted
	cmp	ax,bx			; wanted versus available
	jae	makebu4			; ae = want more than available
	mov	bx,ax			; set bx to qty paragraphs wanted
makebu4:mov	cx,bx			; remember desired paragraphs
	mov	ah,alloc		; allocate a memory block
	int	dos
	mov	pbufseg,ax		; seg of memory area
	mov	ax,bx			; number paragraphs allocated
	mov	cl,trans.windo		; number of window slots
	xor	ch,ch
	mov	bufnum,cx		; number of buffers = window slots
	cmp	cx,1			; just one window slot?
	je	makebu5			; e = yes, save division
	xor	dx,dx
	div	cx			; paras per window slot to ax
makebu5:mov	dx,ax			; keep paragraphs per buffer in dx
;	mov	di,ax			; paragraphs per buffer
;	mov	cl,4
;	shl	di,cl			; bytes per buffer (9040 max)
	mov	cx,bufnum		; number of buffers wanted
	mov	ax,pbufseg		; seg where buffer starts
	mov	si,offset pktlist	; where pktinfo group starts
	xor	bx,bx			; index (words)
makebu6:mov	bufuse[bx],0		; say buffer slot is not used yet
	mov	buflist[bx],si		; pointer to pktinfo member
	mov	word ptr [si].datadr,0	 ; offset of data field
	mov	word ptr [si].datadr+2,ax ; segment of data field
	mov	[si].datsize,di		; data buffer size, bytes
	mov	[si].numtry,0		; clear number tries for this buffer
	mov	[si].ackdone,0		; not acked yet
	mov	[si].seqnum,0		; a dummy sequence number
	add	si,size pktinfo		; next pktinfo member
	add	ax,dx			; pointer to next buffer segment
	add	bx,2			; next buflist slot
	loop	makebu6			; make another structure member
	mov	windused,0		; no slots used yet
	mov	winusedmax,0		; max slots used
	mov	word ptr cwindow,1	; initial congestion window
	mov	ax,bufnum		; max slots availble
	mov	ssthresh,al		; save as congestion threshold
	clc				; success
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
makebuf	endp

; Allocate a buffer. Return carry clear and SI pointing at fresh pktinfo
; structure, or if failure return carry set and all regs preserved.
getbuf	proc	far
	push	ax
	push	cx
	push	si
	xor	si,si			; index
	mov	cx,bufnum		; number of buffers
	jcxz	getbuf2			; 0 means none, error
	mov	al,windused		; window slots in use now
	cmp	al,cwindow		; max slots allowed at this time
	jae	getbuf2			; ae = all in use, sorry

getbuf1:cmp	bufuse[si],0		; is this slot in use?
	je	getbuf3			; e = no, grab it
	add	si,2			; try next slot
	loop	getbuf1			; fall through on no free buffers
getbuf2:pop	si			; get here if all are in use
	pop	cx
	pop	ax
	stc				; return failure, si preserved
	ret

getbuf3:mov	bufuse[si],1		; mark buffer as being in use
	inc	windused		; one more slot in use
	mov	si,buflist[si]		; address of pktinfo member
	mov	al,pktnum		; next sequence number to be used
	mov	[si].seqnum,al		; use it as sequence number
	mov	[si].datlen,0		; no data in packet
	mov	[si].numtry,0		; clear number tries for this buffer
	mov	[si].ackdone,0		; not acked yet
	pop	cx			; discard originally saved si
	pop	cx
	pop	ax
	clc				; return success, buffer ptr in si
	ret
getbuf	endp

; Release all buffers (marks them as free, releases buffer memory).

bufclr	proc	far
	push	ax
	push	cx
	push	di
	push	es
	push	ds
	pop	es
	mov	cx,maxwind		; max number of buffers
	xor	ax,ax
	mov	di,offset bufuse	; buffer in-use list
	cld
	rep	stosw			; store zeros to clear the buffers
	mov	windused,0		; number now used (none)
	mov	ax,pbufseg		; segment of memory
	mov	es,ax			; es = segment affected
	mov	ah,freemem		; free it
	int	dos
	xor	ax,ax
	mov	pbufseg,ax		; say no buffer segment
	pop	es
	pop	di
	pop	cx
	pop	ax
	ret
bufclr	endp

; Release buffer whose pktinfo pointer is in SI.
; Return carry clear if success, or carry set if failure.
bufrel	proc	far
	push	bx
	push	cx
	mov	cx,bufnum		; number of buffers
	xor	bx,bx
bufrel1:cmp	buflist[bx],si		; compare addresses, match?
	je	bufrel2			; e = yes, found it
	add	bx,2
	loop	bufrel1
	pop	cx
	pop	bx
	stc				; no such buffer
	ret
bufrel2:mov	bufuse[bx],0		; say buffer is no longer in use
	dec	windused		; one less used buffer
	pop	cx
	pop	bx
	clc
	ret
bufrel	endp

; Grow sliding window slot count in accordance with Van Jacobson's
; TCP/IP congestion avoidance paper.
; An ACK has been received for a packet in the window.
; Inc cwindow by 1 if cwindow is below ssthresh, else inc by 1/cwindow.
; Keep fractions of a slot in byte cwindow+1.
; Limit cwindow to max slots in system, bufnum.
windgrow proc	far
	push	ax
	push	cx
	xor	ah,ah
	mov	al,cwindow	; congestion window, slots
	cmp	al,ssthresh 	; above congestion avoidance threshold?
	jae	windgr1		; ae = yes, grow slowly
	inc	cwindow		; fast opening, add one window slot
	jmp	short windgr2
windgr1:mov	al,thirtytwo	; congestion avoidance slow growth
	xor	ah,ah
	div	cwindow 	; 32 / cwindow, al=quo, ah=rem
	add	cwindow+1,al 	; increment qty of 32nds of slots
	mov	al,cwindow+1
	mov	cl,5		; divide cwindow+1 by 32
	shr	al,cl		; get whole number of window slots
	jz	windgr2		; z = none
	inc	cwindow		; increment cwindow
	mov	cwindow+1,0	; clear fraction
windgr2:mov	al,cwindow	; limit cwindow to max slots (bufnum)
	cmp	al,byte ptr bufnum ; exceeds max number of window slots?
	jbe	windgr3		; be = no
	mov	al,byte ptr bufnum ; limit
windgr3:mov	cwindow,al	; max window slots allowed at this time
	pop	cx
	pop	ax
	ret
windgrow endp

; Shrink sliding window slots. ssthresh <- cwindow / 2, cwindow <- 1.
windshrink proc far
	push	ax
	mov	al,cwindow	; current congestion window, slots
	shr	al,1		; divide by two
	jnz	windsh1		; nz = not too small
	mov	al,1		; must have at least one slot available
windsh1:mov	ssthresh,al	; new congestion threshold
	mov	word ptr cwindow,1 ; back to slow start
	pop	ax
	ret
windshrink endp

; Returns in BX the "packet pointer" for the buffer with the same seqnum as
; provided in AL. Returns carry set if no match found. Modifies BX.
pakptr	proc	far
	push	cx
	push	di
	mov	cx,bufnum		; number of buffers
	xor	di,di			; buffer index for tests
pakptr1:cmp	bufuse[di],0		; is buffer vacant?
	je	pakptr2			; e = yes, ignore
	mov	bx,buflist[di]		; bx = address of pktinfo member
	cmp	al,[bx].seqnum		; is this the desired sequence number?
	je	pakptr3			; e = yes
pakptr2:add	di,2			; next buffer index
	loop	pakptr1			; do next test
	xor	bx,bx			; say no pointer
	stc				; set carry for failure
	pop	di
	pop	cx
	ret
pakptr3:clc				; success, BX has buffer pointer
	pop	di
	pop	cx
	ret
pakptr	endp

; Returns in AH count of packets with a given sequence number supplied in AL
; and returns in BX the packet pointer of the last matching entry.
; Used to detect duplicated packets.
pakdup	proc	far
	push	cx
	push	dx
	push	di
	mov	cx,bufnum		; number of buffers
	xor	di,di			; buffer index for tests
	xor	ah,ah			; number of pkts with seqnum in al
	mov	dx,-1			; a bad pointer
pakdup1:cmp	bufuse[di],0		; is buffer vacant?
	je	pakdup2			; e = yes, ignore
	mov	bx,buflist[di]		; bx = address of pktinfo member
	cmp	al,[bx].seqnum		; is this the desired sequence number?
	jne	pakdup2			; ne = no
	mov	dx,bx			; yes, remember last pointer
	inc	ah			; count a found packet
pakdup2:add	di,2			; next buffer index
	loop	pakdup1			; do next test
	mov	bx,dx			; return last matching member's ptr
	pop	di
	pop	dx
	pop	cx
	or	ah,ah			; any found?
	jz	pakdup3			; z = no
	clc				; return success
	ret
pakdup3:stc				; return failure
	ret
pakdup	endp
	
; Find sequence number of first free window slot and return it in AL,
; Return carry set and al = windlow if window is full (no free slots).
firstfree proc	far
	mov	al,windlow		; start looking at windlow
	mov	ah,al
	add	ah,trans.windo
	and	ah,3fh			; ah = 1+top window seq number, mod 64
firstf1:push	bx
	call	pakptr			; buffer in use for seqnum in AL?
	pop	bx
	jc	firstf2			; c = no, seq number in not in use
	inc	al			; next sequence number
	and	al,3fh			; modulo 64
	cmp	al,ah			; done all yet?
	jne	firstf1			; ne = no, do more
	mov	al,windlow		; a safety measure
	stc				; carry set to say no free slots
	ret
firstf2:clc				; success, al has first free seqnum
	ret
firstfree endp

; Check sequence number for lying in the current or previous window or
; outside either window.
; Enter with sequence number of received packet in [si].seqnum.
; Returns:
;	carry clear and cx =  0 if [si].seqnum is within the current window,
;	carry set   and cx = -1 if [si].seqnum is inside previous window,
;	carry set   and cx = +1 if [si].seqnum is outside any window.
chkwind	proc	far
	mov	ch,[si].seqnum		; current packet sequence number
	mov	cl,trans.windo		; number of window slots
	sub	ch,windlow		; ch = distance from windlow
	jc	chkwin1			; c = negative result
	cmp	ch,cl			; span greater than # window slots?
	jb	chkwinz			; b = no, in current window
	sub	ch,64			; distance measured the other way
	neg	ch
	cmp	ch,cl			; more than window size?
	ja	chkwinp			; a = yes, outside any window
	jmp	short chkwinm		; else in previous window

					; sequence number less than windlow
chkwin1:neg	ch			; distance, positive, cl >= ch
	cmp	ch,cl			; more than window size?
	ja	chkwin2			; a = yes, maybe this window
	jmp	short chkwinm		; no, in previous window

chkwin2:sub	ch,64			; distance measured the other way
	neg	ch
	cmp	ch,cl			; greater than window size?
	jb	chkwinz			; b = no, in current window
					; else outside any window

chkwinp:mov	cx,1			; outside any window
	stc				; carry set for outside current window
	ret
chkwinz:xor	cx,cx			; inside current window
	clc				; carry clear, inside current window
	ret
chkwinm:mov	cx,-1			; in previous window
	stc				; carry set for outside current window
	ret
chkwind	endp

; Return Bios time of day in dx:ax
getbtime proc	far
	push	es
	push	bx
	push	cx
	xor     ax,ax
        mov     es,ax
getbt1:	mov	cx,es:[biosclk+0]
	mov	dx,es:[biosclk+2]
	in	al,61h			; pause
	in	al,61h
	mov	ax,es:[biosclk+0]
	mov	bx,es:[biosclk+2]
	cmp	ax,cx
	jne	getbt1			; ne = time jumped
	cmp	bx,dx
	jne	getbt1			; ne = time jumped
	mov	ax,[bp+4+0]
	cwd				; sign extend ax to dx
        add     ax,cx
        adc     dx,bx
	pop	cx			; end critical section
	pop	bx
	pop	es
	ret
getbtime endp

; Compute Kermit round trip timeout, k_rto, in Bios clock ticks.
; Enter with SI pointing to packet structure of sent packet
krto	proc	far
	cmp	flags.comflg,'t'	; internal Telnet?
	je	krto5			; e = yes, get rto from it
	push	ax
	push	dx
	call	getbtime		; get current Bios time to dx:ax
	sub	ax,word ptr [si].sndtime ; minus time at which pkt was sent
	sbb	dx,word ptr [si].sndtime+2
	jc	krto4			; c = negative elapsed time (midnight)
	; assume rtt Bios ticks fits into 13 bits (in AX), 450 minutes
	shl	ax,1
	shl	ax,1
	shl	ax,1			; rtt * 8
	sub	ax,k_sa			; minus 8 * smoothed average rtt
	mov	dx,ax			; dx = 8 * rtt_error
	sar	ax,1
	sar	ax,1
	sar	ax,1			; ax = rtt_error
	add	k_sa,ax			; k_sa += rtt_error
	or	ax,ax			; negative?
	jge	krto1			; ge = no
	neg	ax			; make error positve
krto1:	mov	dx,k_sd			; 8 * std dev
	shr	dx,1
	shr	dx,1			; k_sd >> 2
	sub	ax,dx			; rtt_error -= (k_sd >> 2)
	add	k_sd,ax			; k_sd += rtt_error
	mov	ax,k_sa
	shr	ax,1
	shr	ax,1
	add	ax,k_sd
	shr	ax,1			; k_rto = ((k_sa >> 2) + k_sd) >> 1
	cmp	ax,60 * 18 * 3		; more than 3 * 60 seconds?
	jle	krto2			; le = no
	mov	ax,60 * 18 * 3		; clamp at 3 * 60 seconds
krto2:	cmp	ax,9			; below floor of 9 Bios clock ticks
	jge	krto3			; ge = no
	mov	ax,9			; set floor
krto3:	mov	k_rto,ax		; predicted round trip time out, ticks
krto4:	pop	dx
	pop	ax
	ret
krto5:	push	ax			; Internal TCP/IP stack provides rto
	mov	ax,tcp_rto		; Bios ticks from TCP/IP stack
	add	ax,18 * 2		; bias up by two seconds
	mov	k_rto,ax
	pop	ax
	mov	timeit,0		; cancel previous timeout
	ret
krto	endp
code1	ends
	end
