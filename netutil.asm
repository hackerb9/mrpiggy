   	NAME	msnut1
; File MSNUT1.ASM
; Provides various Intel 8088 level operations, including
; display facilities (via msg buffer or DOS) for char, strings, etc.
;
; Copyright 1991, University of Waterloo.
;	Copyright (C) 1982, 1999, Trustees of Columbia University in the 
;	City of New York.  The MS-DOS Kermit software may not be, in whole 
;	or in part, licensed or sold for profit as a software product itself,
;	nor may it be included in or distributed with commercial products
;	or otherwise distributed by commercial concerns to their clients 
;	or customers without written permission of the Office of Kermit 
;	Development and Distribution, Columbia University.  This copyright 
;	notice must not be removed, altered, or obscured.
; 
; Written by Erick Engelke of the University of Waterloo, Waterloo, 
;  Ontario, Canada,
;  and by Joe R. Doupnik, Utah State University, 
;  jrd@cc.usu.edu, jrd@usu.Bitnet.
;
; Edit history
; 12 Jan 1995 version 3.14
; Last edit
; 12 Jan 1995

cr	equ	0dh
lf	equ	0ah
conout	equ	2
dconio	equ	6
dos	equ	21h
ioctl	equ	44h
allocmem equ	48h
freemem	equ	49h

MSGBUFLEN equ	1024			; coordinate with msntnd.c
BIOSCLK	equ	046ch
HI_MAX	equ	018h
LO_MAX	equ     0b0h

_TEXT	SEGMENT  WORD PUBLIC 'CODE'
_TEXT	ENDS
_DATA	SEGMENT  WORD PUBLIC 'DATA'
_DATA	ENDS
CONST	SEGMENT  WORD PUBLIC 'CONST'
CONST	ENDS
_BSS	SEGMENT  WORD PUBLIC 'BSS'
_BSS	ENDS
DGROUP	GROUP	CONST, _BSS, _DATA
	ASSUME  CS: _TEXT, DS: DGROUP, SS: DGROUP

	include	symboldefs.h
data	segment
	extrn	flags:byte
data	ends

_DATA	SEGMENT
	extrn	_doslevel:word, _msgcnt:word, _msgbuf:byte,_display_mode:byte
	extrn	_tcpflag:byte, _dobinary:byte
_DATA	ENDS

_TEXT	segment

        ; Compute 1's-complement sum of data buffer
        ; unsigned checksum( unsigned word FAR *buf, unsigned cnt)

	public	_checksum
_checksum proc	near
	push	bp
	mov	bp,sp
	push	si
	push	bx
	push	cx
	push	dx
	push	DS
        lds     si,[bp+4+0]		; seg:offset of data to be checked
	mov     cx,[bp+4+4]		; cx = cnt
	mov	bl,cl			; save low order for odd byte length
	shr     cx,1			; group into words
	xor	dx,dx			; set checksum to 0
        cld
	jcxz	chk3			; z = no words to do
        clc
chk1:	lodsw				; add words
	adc	dx,ax			; with carry
	loop	chk1
					; resolve remainder
chk2:	adc     dx,0
        jc	chk2
chk3:	and	bl,1
	jz	chk5			; z = even number of bytes
        xor     ah,ah
	lodsb				; read odd byte + 0
        add     dx,ax
chk4:	adc     dx,0
	jc	chk4
chk5:	mov	ax,dx			; result into ax
        or      ax,ax			; 0?
	jnz	chk6			; nz = no
        mov     ax,0ffffh		; then make it be -1
chk6:	POP	DS
	pop	dx
	pop	cx
	pop	bx
	pop	si
	pop	bp
	ret
_checksum endp

;  ntohl(longword x)	32 bit network (big endian) to host (little endian)
;  htonl(longword x)	32 bit host (little endian) to network (big endian)
;  intel(longword x)
;  Reverse order of 4 byte groups between big and little endian forms
;
	public	_intel, _ntohl, _htonl

_intel	proc	near
_ntohl	equ	this byte
_htonl	equ	this byte
	push	bp
	mov	bp,sp
	mov	ax,[bp+4+2]		; high order incoming, low outgoing
	mov	dx,[bp+4+0]		; low order incoming, high outgoing
	xchg	al,ah
	xchg	dl,dh
	pop	bp
	ret
_intel	endp

;  ntohs(word x)	16 bit network (big endian) to host (little endian)
;  htons(word x)	16 bit host (little endian) to network (big endian)
;  intel16(word x)
;  Reverse order of 2 byte groups between big and little endian forms
	public	_intel16, _ntohs, _htons
_intel16 proc	near
_ntohs	equ	this byte
_htons	equ	this byte
	push	bp
	mov	bp,sp
	mov	ax,[bp+4+0]
	xchg	al,ah
	pop	bp
	ret
_intel16 endp


; int ourmod(int top, int bottom)
; Perform modulo function on 16 bit quantities
	public	_ourmod
_ourmod	proc	near
	push	bp
	mov	bp,sp
	push	bx
	mov	ax,[bp+4+0]		; top number
	mov	bx,[bp+4+2]		; bottom number (radix)
	xor	dx,dx
	or	bx,bx			; bottom is zero?
	jz	ourmod1			; z = yes, return zero
	div	bx
ourmod1:mov	ax,dx			; return remainder
	pop	bx
	pop	bp
	ret
_ourmod	endp

; int ourdiv(int top, int bottom)
; Perform 16 bit integer division
	public	_ourdiv
_ourdiv	proc	near
	push	bp
	mov	bp,sp
	push	bx
	mov	ax,[bp+4+0]		; top
	mov	bx,[bp+4+2]		; bottom
	xor	dx,dx
	or	bx,bx			; divide by zero?
	jz	outdiv1			; z = yes, divide by one
	div	bx
outdiv1:pop	bx
	pop	bp			; quotient is returned in ax
	ret
_ourdiv	endp

; int ourlmod(long top, int bottom)
; Perform 32 bit integer modulo function
	public	_ourlmod
_ourlmod proc	near
	push	bp
	mov	bp,sp
	push	bx
	mov	ax,[bp+4+0]		; top lower 16 bits
	mov	dx,[bp+4+2]		; top upper 16 bits
	mov	bx,[bp+4+4]		; bottom
	or	bx,bx			; zero?
	jz	outlmo1			; z = yes divide by 2^16 and quit
	div	bx
outlmo1:mov	ax,dx			; return remainder in ax
	pop	bx
	pop	bp
	ret
_ourlmod endp

; int ourldiv(long top, int bottom)
; Perform 32 bit integer division of 32 bit quotient by 16 bit divisor
	public	_ourldiv
_ourldiv proc	near
	push	bp
	mov	bp,sp
	push	bx
	mov	ax,[bp+4+0]		; top lower 16 bits
	mov	dx,[bp+4+2]		; top upper 16 bits
	mov	bx,[bp+4+4]		; bottom
	cmp	dx,bx			; about to overflow?
	jae	ourldiv1		; ae = yes, return 0xffffh
	div	bx
	xor	dx,dx			; clear remainder (high order ret)
	pop	bx
	pop	bp			; quotient is returned in dx:ax
	ret
ourldiv1:mov	ax,0ffffh		; overflow indication
	xor	dx,dx			; clear high order
	pop	bx
	pop	bp
	ret
_ourldiv endp

; long ourlmul(long top, int bottom)
; Perform 32 bit integer multiplication of 32 bit multiplicand by 16 bit mult
	public	_ourlmul
_ourlmul proc	near
	push	bp
	mov	bp,sp
	push	bx
	push	cx
	mov	ax,[bp+4+2]		; top upper 16 bits
	mov	bx,[bp+4+4]		; bottom
	mul	bx
	mov	cx,ax			; save product (no overflow noted)
	mov	ax,[bp+4+0]		; top lower 16 bits
	mul	bx
	adc	dx,cx			; new upper 16 bits
	pop	cx
	pop	bx
	mov	sp,bp
	pop	bp			; long product is returned in dx:ax
	ret
_ourlmul endp

; void * bcopy(src, dest, count)
; void *dest, *src;
; size_t count;
; copy count bytes from src to dest
	public	_bcopy
_bcopy proc	near
	push	bp
	mov	bp,sp
	push	es
	push	si
	push	di
	push	cx
	mov	ax,ds			; set to same data segment
	mov	es,ax
	mov	si,[bp+4+0]		; offset of source
	mov	di,[bp+4+2]		; offset of destination
	mov	cx,[bp+4+4]		; count
	cld
	push	di			; push dest address for return
	jcxz	bcopy2			; z = nothing to copy
	or	si,si			; is source NULL?
	jz	bcopy2			; z = yes, don't do a thing
	or	di,di			; is destination NULL?
	jz	bcopy2			; z = yes, don't do a thing
	cmp	si,di			; is source after destination?
	ja	bcopy1			; a = yes, no overlap problem
	je	bcopy2			; e = same place, do nothing
	add	di,cx			; start at the ends
	dec	di
	add	si,cx
	dec	si
	std				; work backward
bcopy1:	rep	movsb
bcopy2:	pop	ax			; recover return destination
	cld
	pop	cx
	pop	di
	pop	si
	pop	es
	mov	sp,bp
	pop	bp
	ret
_bcopy endp

; void * bcopyff(src, dest, count)
; void * FAR dest, * FAR src;
; size_t count;
; copy count bytes from src to dest
	public	_bcopyff
_bcopyff proc	near
	push	bp
	mov	bp,sp
	push	es
	push	ds
	push	si
	push	di
	push	cx
	push	dx
	lds	si,dword ptr [bp+4+0]	; source
	les	di,dword ptr [bp+4+4]	; destination
	mov	cx,[bp+4+8]		; count
	cld
	jcxz	bcopyff2		; z = nothing to copy
	mov	ax,ds
	mov	dx,es
	or	ax,ax			; is source NULL?
	jz	bcopyff2		; z = yes, don't do a thing
	or	dx,dx			; is destination NULL?
	jz	bcopyff2		; z = yes, don't do a thing
	cmp	ax,dx			; is source seg after destination?
	ja	bcopyff1		; a = yes, no overlap problem
	jb	bcopyff3		; b = no, no overlap the other way
	cmp	si,di			; is source offset after destination?
	ja	bcopyff1		; a = yes, no overlap problem
	je	bcopyff2		; e = same place, do nothing
bcopyff3:add	di,cx			; start at the ends
	dec	di
	add	si,cx
	dec	si
	std				; work backward
bcopyff1:rep	movsb
bcopyff2:xor	ax,ax			; say null destination
	cld
	pop	dx
	pop	cx
	pop	di
	pop	si
	pop	ds
	pop	es
	mov	sp,bp
	pop	bp
	ret
_bcopyff endp


; void * memset(dest, c, count)
; void *dest;
; char c;
; size_t count;
; Store count copies of byte c in destination area dest
	public	_memset
_memset	proc	near
	push	bp
	mov	bp,sp
	push	es
	push	di
	push	cx
	mov	ax,ds			; setup data segment
	mov	es,ax
	mov	di,[bp+4+0]		; offset of destination
	or	di,di			; is it NULL?
	jz	memset1			; z = yes, don't do a thing
	push	di			; save dest for return
	mov	al,[bp+4+2]		; byte of character c
	mov	ah,al
	mov	cx,[bp+4+4]		; count
	jcxz	memset1			; z = do nothing
	cld
	shr	cx,1
	jnc	memset2
	stosb
memset2:rep	stosw
	pop	ax			; return pointer to destination
memset1:pop	cx
	pop	di
	pop	es
	mov	sp,bp
	pop	bp
	ret
_memset	endp

; Allocate size bytes from DOS free memory.
; void FAR * malloc(size_t size)
; Returns FAR pointer in dx:ax, or 0L if failure. Size is an unsigned int.
	public	_malloc
_malloc	proc	near
	push	bp
	mov	bp,sp
	push	bx
	push	cx
	mov	bx,[bp+4+0]		; bytes wanted
	add	bx,15			; round up
	mov	cl,4
	shr	bx,cl			; convert to # of paragraphs
	mov	cx,bx			; remember quantity wanted
	mov	ah,allocmem		; DOS memory allocator
	int	dos			; returns segment in ax
	jc	malloc1			; c = fatal error
	cmp	cx,bx			; paragraphs wanted vs delivered
	je	malloc2			; e = got the block
	push	es			; insufficient, return it
	mov	es,ax			; identify the block
	mov	ah,freemem		; free the unwanted block
	int	dos
	pop	es
malloc1:xor	ax,ax			; return 0L on failure
malloc2:mov	dx,ax			; segment
	xor	ax,ax			; offset
	pop	cx
	pop	bx
	pop	bp
	ret
_malloc	endp

; Free a block of memory allocated from the DOS memory pool.
; void free(FAR * memblock);
	public	_free
_free	proc	near
	push	bp
	mov	bp,sp
	push	ax
	push	es
	mov	ax,[bp+4+2]		; get high order (segment) arg
	or	ax,ax			; NULL?
	jz	free1			; z = yes, leave it alone
	mov	es,ax			; identify the block
	mov	ah,freemem		; free the unwanted block
	int	dos
free1:	pop	es
	pop	ax
	pop	bp
	ret
_free	endp

; Copy bytes from src buffer to dest buffer. Src has srclen bytes present,
; dest buffer can hold destlen bytes. Convert CR NUL to CR en route.
; Report count of bytes destcnt placed in dest, last read byte in last_read,
; and return int bytes read from source. s->last_read is to track CR NUL
; across arriving packets.
; int 
; destuff(FAR * src, srclen, FAR * dest, destlen, * destcnt, * last_read)
;		0    4             6     10         12	       14
	public	_destuff
_destuff proc	near
	push	bp
	mov	bp,sp
	mov	al,_dobinary		; save as stack word so we can use
	xor	ah,ah			; ds and es for far pointers
	push	ax			; [bp-2] temp storage of _dobinary
	push	es
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	ds
	mov	cx,[bp+4+4]		; srclen
	mov	ax,[bp+4+10]		; destlen
	cmp	ax,cx			; destlen > srclen?
	ja	destuf1			; a = yes, use srclen
	mov	cx,ax			; use destlen as the shorter
destuf1:lds	si,dword ptr [bp+4+0]	; src
	les	di,dword ptr [bp+4+6]	; dest
	xor	ax,ax			; bytes read
	xor	dx,dx			; bytes written
	mov	bx,es			; check for NULL
	or	bx,bx			; NULL?
	jz	destufx			; z = yes, return 0
	mov	bx,ds			; check for NULL
	or	bx,bx
	jz	destufx			; z = NULL
	push	ds
	mov	bx,DGROUP		; get ds reg back to Dgroup for a sec
	mov	ds,bx
	mov	bx,[bp+4+14]		; &s->last_read, last read byte
	mov	ah,ds:[bx]		; last read byte
	pop	ds
	jcxz	destufx			; z = empty string, return -1
	cld
	mov	bx,[bp+4+4]		; srclen
destuf3:lodsb				; read source
	dec	bx			; chars left in source
	or	al,al			; NUL?
	jnz	destuf4			; nz = no
	cmp	ah,CR			; last read was Carriage return?
	jne	destuf4			; ne = no
	cmp	word ptr [bp-2],0	; doing binary mode (_dobinary)?
	je	destuf5			; e = no, NVT-ASCII, skip NUL
destuf4:stosb				; write destination
	inc	dx			; chars written to dest
destuf5:mov	ah,al			; remember last read byte
	or	bx,bx			; any source left?
	jz	destuf6			; z = no, stop now
	loop	destuf3

destuf6:mov	cx,[bp+4+4]		; srclen
	sub	cx,bx			; return count of bytes read
destufx:pop	ds			; restore addressablity
	mov	bx,[bp+4+14]		; &s->last_read
	mov	ds:[bx],ah		; store last read character
	mov	bx,[bp+4+12]		; &destcnt, count of bytes written
	mov	ds:[bx],dx
	mov	ax,cx			; return count of bytes consumed
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	es
	add	sp,2			; temp storage area
	pop	bp
	ret
_destuff endp


; int fstchr(const char FAR * p, word len, byte c)
; Finds first occurence of unsigned byte in low part of c and returns
; the number of bytes preceeding it in the buffer, or len if not found.
	public	_fstchr
_fstchr proc	near
	push	bp
	mov	bp,sp
	push	es
	push	bx
	push	cx
	push	di
	les	di,dword ptr [bp+4+0]	; Far string address
	mov	bx,es			; check for NULL
	mov	ax,-1			; error return value
	or	bx,bx			; NULL?
	jz	fstchr1			; z = yes, return -1
	mov	bx,di			; remember starting offset
	mov	cx,[bp+4+4]		; number of bytes to examine
	jcxz	fstchr1			; z = empty string, return -1
	mov	ax,[bp+4+6]		; pattern is in al
	cld
	repne	scasb
	mov	ax,di			; ending place
	jne	fstchr2			; ne = not found
	dec	ax			; minus auto inc of rep
fstchr2:sub	ax,bx			; minus starting offset
fstchr1:pop	di
	pop	cx
	pop	bx
	pop	es
	pop	bp
	ret
_fstchr endp

;  Timer routines - use set_*timeout to receive a clock value which
;                   can later be tested by calling chk_timeout with
;                   that clock value to determine if a timeout has
;                   occurred.  chk_timeout returns 0 if NOT timed out.
;  Usage:   long set_timeout( int seconds );
;           long set_ttimeout( int bios_ticks );
;           int chk_timeout( long value );
;
;  (c) 1990 University of Waterloo,
;           Faculty of Engineering,
;           Engineering Microcomputer Network Development Office
;  Rewritten by Joe Doupnik, Jan 1994
;
; Return Bios clock ticks at argument Bios ticks from the present
	public	_set_ttimeout
_set_ttimeout proc	near
	push	bp
	mov	bp,sp
	push	es
	push	bx
	push	cx
	xor     ax,ax
        mov     es,ax
_set_ttimeout1:
	mov	cx,es:[biosclk+0]
	mov	dx,es:[biosclk+2]
	in	al,61h			; pause
	in	al,61h
	mov	ax,es:[biosclk+0]
	mov	bx,es:[biosclk+2]
	cmp	ax,cx
	jne	_set_ttimeout1		; ne = time jumped
	cmp	bx,dx
	jne	_set_ttimeout1		; ne = time jumped
	mov	ax,[bp+4+0]
	cwd				; sign extend ax to dx
        add     ax,cx
        adc     dx,bx
	pop	cx			; end critical section
	pop	bx
	pop	es
	pop	bp
	ret
_set_ttimeout endp

; Return Bios clock ticks at argument seconds from the present
	public	_set_timeout
_set_timeout proc near
	push	bp
	mov	bp,sp
	push	es
	push	cx
	xor	ax,ax			; reference low memory
	mov	es,ax
	mov	ax,[bp+4+0]		; seconds
	xor	dx,dx
	mov	cx,1165
	mul	cx			; 1165/64 = 18.203...
	mov	cx,6
tmp:	shr	dx,1
	rcr	ax,1
	loop	tmp
	push	ax
	push	dx

_set_timeout1:
	mov	cx,es:[biosclk+0]
	mov	dx,es:[biosclk+2]
	in	al,61h
	in	al,61h
	mov	ax,es:[biosclk+0]
	mov	bx,es:[biosclk+2]
	cmp	ax,cx
	jne	_set_timeout1		; time jumped
	cmp	bx,dx
	jne	_set_timeout1		; time jumped
	pop	dx
	pop	ax
	add	ax,cx
	adc	dx,bx
	pop	cx			; end critical section
	pop	es
	pop	bp
	ret
_set_timeout	endp

; Return 1 for timed-out if argument Bios clock ticks is older (smaller) 
; than the current Bios clock time, else return 0 for not-timed-out.
	public	_chk_timeout
_chk_timeout	proc near
	push	bp
	mov	bp,sp
	push	cx
	push	es
	xor	ax,ax
	mov	es,ax
_chk_timeout1:
	mov	cx,es:[biosclk+0]
	mov	dx,es:[biosclk+2]
	in	al,61h
	in	al,61h
	mov	ax,es:[biosclk+0]
	mov	bx,es:[biosclk+2]
	cmp	ax,cx
	jne	_chk_timeout1		; time jumped
	cmp	bx,dx
	jne	_chk_timeout1		; time jumped

	pop	es
	mov	ax,[bp+4+0]		; timeout value
	mov	dx,[bp+4+2]
	cmp	dx,bx			; if timeout < clock, has expired
        jb	ret_tru			; b = timed out
	ja	ret_fal			; a = not timed out
	cmp	ax,cx
        jb	ret_tru			; b = timed out
					; may have gone over by one day
	sub	ax,LO_MAX
	sbb	dx,HI_MAX
	jc	ret_fal			; c = nope, timeout is today
					; test timeout new values
	cmp	dx,bx
	jb	ret_tru			; b = timed out
	ja	ret_fal			; a = not timed out
	cmp	ax,cx
	jae	ret_fal			; ae = not timed out
ret_tru:mov	ax,1			; say have timed out
	pop	cx
	pop	bp
	ret

ret_fal:xor	ax,ax			; say have not timed out
	pop	cx
	pop	bp
	ret
_chk_timeout	endp

; void _chkstk()
; Stack checker
; {
;  ;
; }
	public	__chkstk, __aNchkstk
__chkstk proc	near			; MSC v5.1
__aNchkstk equ	this byte		; MSC v6.00
	pop	bx			; pop return address
	sub	sp,ax			; down adjust stack pointer
	jmp	bx			; return the no-stack way
__chkstk endp

; Check real console for ^C. Return 1 if so, else do nothing and return 0.
; Do nothing and return 0 if not at DOS level or stdin is not a device.
	public	_chkcon
_chkcon	proc	near
	push	bx
	push	dx
	push	es
	mov	bx,seg data
	mov	es,bx
	cmp	es:flags.cxzflg,'C'	; ^C seen ?
	pop	es
	je	chkcon1			; e = yes
	cmp	_doslevel,0		; outside DOS level?
	je	chkcon2			; e = yes, do nothing here
	test	_tcpflag,2 		; running on Int 8h?
	jnz	chkcon2			; nz = yes
	xor	bx,bx			; handle 0 is stdin
	xor	al,al			; get device info
	mov	ah,ioctl
	int	dos			; is stdin a device, not a disk file?
	rcl	dl,1			; put ISDEV bit into the carry bit
	jnc	chkcon2			; nc, a disk file so do not read here
	mov	dl,0ffh
	mov	ah,dconio		; read console
	int	dos
	jz	chkcon2			; z = nothing there
	and	al,1fh			; make char a control code
	cmp	al,'C'-40h		; Control-C?
	jne	chkcon2			; ne = no
chkcon1:mov	ax,1			; return 1, ^C sensed
	pop	dx
	pop	bx
	ret
chkcon2:xor	ax,ax			; return 0, no ^C
	pop	dx
	pop	bx
	ret
_chkcon	endp

; Microsoft C v7.0 direct support. Shift left dx:ax by cx. No C calling conv.
; Long shift left
	public	__aNlshl
__aNlshl proc	near
	jcxz	lshift2			; z = no shift
lshift1:shl	ax,1
	rcl	dx,1
	loop	lshift1
lshift2:ret
__aNlshl endp

; Microsoft C v7.0 direct support. Shift rgt dx:ax by cx. No C calling conv.
; Unsigned long shift right
	public	__aNulshr
__aNulshr proc	near
	jcxz	rshift2			; z = no shift
rshift1:shr	dx,1
	rcr	ax,1
	loop	rshift1
rshift2:ret
__aNulshr endp

; void 
; outch(char ch)
; Sends character to the screen via the msgbuf buffer if operating at
; interrupt level, or via DOS if operating at task level.
	public	_outch
_outch	proc	near
	push	bp
	mov	bp,sp
	push	ax
	cmp	_display_mode,0		; quiet screen?
	je	outch3			; e = yes
	mov	ax,[bp+4]		; get the character
	cmp	_doslevel,0		; at DOS task level?
	je	outch1			; e = no
	test	_tcpflag,2 		; running on Int 8h?
	jnz	outch1			; nz = yes
	mov	ah,conout		; use DOS
	push	dx
	mov	dl,al
	int	dos
	pop	dx
	jmp	short outch3
outch1:	cmp	_msgcnt,MSGBUFLEN	; is buffer filled?
	jae	outch3			; ae = yes, discard this byte
	push	bx
	mov	bx,_msgcnt
	mov	_msgbuf[bx],al
	inc	_msgcnt
	pop	bx
outch3:	pop	ax
	mov	sp,bp
	pop	bp
	ret
_outch	endp


; void 
; outsn(char * string, int count)
; display counted string
	public	_outsn
_outsn	proc	near
	push	bp
	mov	bp,sp
	push	ax
	push	si
	mov	si,[bp+4]		; string address
	mov	cx,[bp+4+2]		; string length
	cld
outsn1:	lodsb
	or	al,al
        jz      outsn2
	push	ax			; push arg
        call    _outch
	pop	ax			; clean stack
	loop	outsn1
outsn2:	pop	si
	pop	ax
	mov	sp,bp
	pop	bp
	ret
_outsn	endp

; void 
; outs(char * string)
; display asciiz string
	public	_outs
_outs	proc	near
	push	bp
	mov	bp,sp
	push	ax
	push	si
	mov	si,[bp+4]		; asciiz string address
	cld
outs1:	lodsb
        or      al,al			; terminator ?
	jz 	outs2			; z = yes
	push	ax			; push arg
	call    _outch
	pop	ax			; clean stack
	jmp	short outs1
outs2:	pop	si
	pop	ax
	mov	sp,bp
	pop	bp
	ret
_outs	endp

; void
; outhex(char c)
; display char in hex
	public _outhex
_outhex	proc	near
	push	bp
	mov	bp,sp
	push	ax
        mov     ax,[bp+4]		; incoming character
	push	cx
        mov     cl,4
        shr     al,cl
	pop	cx
        call    outh
        mov     ax,[bp+4]
        call    outh
	pop	ax
	mov	sp,bp
	pop	bp
	ret

; worker for outhex
outh	proc	near
	and     al,0fh
        cmp     al,9
        jbe     outh1
        add     al,'A' - '9' - 1
outh1:	add     al,'0'
        push    ax
        call    _outch
        pop     ax
        ret
outh	endp
_outhex	endp

; output a string of hex chars
; void
; outhexes(char * string, int count )
	public	_outhexes
_outhexes proc	near
	push	bp
	mov	bp,sp
	push	ax
	push	cx
	push	si			; preserve such things
	mov	si,[bp+4]		; get string pointer
	mov	cx,[bp+4+2]		; get char count
	jcxz	outhexs2		; z = nothing
	cld
outhexs1:lodsb				; read a byte
	push	cx			; save loop counter
	push	ax
	call	_outhex			; display as hex pair
	add	sp,2			; clean stack
	pop	cx
	loop	outhexs1		; do count's worth
outhexs2:pop	si
	pop	cx
	pop	ax
	mov	sp,bp
	pop	bp
	ret
_outhexes endp

; void
; outdec(int c)
; display int in decimal
	public	_outdec
_outdec	proc	near
	push	bp
	mov	bp,sp
	push	ax
	push	cx
	push	dx
	mov	ax,[bp+4]
	or	ax,ax		; negative?
	jge	outdec1		; ge = no
	mov	dl,'-'		; display minus sign
	push	dx		; push arg
	call	_outch
	add	sp,2		; clean stack
	neg	ax		; make positive
outdec1:call	outdec2		; do display recursively
	pop	dx
	pop	cx
	pop	ax
	mov	sp,bp
	pop	bp
	ret

outdec2	proc	near		; internal worker, ax has input value
	xor	dx,dx		; clear high word of numerator
	mov	cx,10
	div	cx		; (ax / cx), remainder = dx, quotient = ax
	push	dx		; save remainder for outputting later
	or	ax,ax		; any quotient left?
	jz	outdec3		; z = no
	call	outdec2		; yes, recurse
	jmp	short outdec3	; present to avoid MASM bug
outdec3:
	pop	dx		; get remainder
	add	dl,'0'		; make digit printable
	push	dx		; push arg for _outch
	call	_outch		; display the char
	pop	dx		; clean stack
	ret
outdec2	endp

_outdec	endp
filler	db	64 dup (0)
_TEXT	ends
        end
