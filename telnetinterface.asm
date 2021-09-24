	NAME	msntni
; File MSNTNI.ASM
; Telnet interface to MS-DOS Kermit
;
;	Copyright (C) 1982, 1999, Trustees of Columbia University in the 
;	City of New York.  The MS-DOS Kermit software may not be, in whole 
;	or in part, licensed or sold for profit as a software product itself,
;	nor may it be included in or distributed with commercial products
;	or otherwise distributed by commercial concerns to their clients 
;	or customers without written permission of the Office of Kermit 
;	Development and Distribution, Columbia University.  This copyright 
;	notice must not be removed, altered, or obscured.
;
; Written by Joe R. Doupnik, Utah State University, 
;  jrd@cc.usu.edu, jrd@usu.Bitnet.
;
; Edit history
; 12 Jan 1995 version 3.14
; Last edit
; 12 Jan 1995
;
; Some rules of the road.
; Starting a session: call ktpcopen. This will ensure the interrupts are
; hooked and will start a new session. Ktcpopen will return the ident of
; the new session, or -1 upon failure.
; Stopping a session: this must be done from outside Telnet. Call ktcpclose
; with a particular session ident (0.. MAXSESSIONS-1) to close that session
; or call it with an ident of -1 to close all and shutdown TCP. Ktcpclose
; will return with the ident of the next (cyclic) active session, or -1 if
; none remain active. Register AX holds incoming indent, outgoing status.
; When TCP/IP shuts down it releases all interrupts and disengages from the
; Packet Driver. This will occur upon closing the last active connection.
;
; Swapping active sessions: call ktcpswap with a new session ident to change
; to that new one. This will return with the new ident if successful, or -1.
; We have to guess session idents so an outside manager can pick and choose.
; Use ktcpswap to resume a session because ktcpstart always tries to start a
; new one.

	include	symboldefs.h

bapicon	equ	0a0h		; 3Com BAPI, connect to port
bapidisc equ	0a1h		; 3Com BAPI, disconnect
bapiwrit equ	0a4h		; 3Com BAPI, write block
bapiread equ	0a5h		; 3Com BAPI, read block
bapibrk	equ	0a6h		; 3Com BAPI, send short break
bapistat equ	0a7h		; 3Com BAPI, read status (# chars to be read)
bapihere equ	0afh		; 3Com BAPI, presence check
bapieecm equ	0b0h		; 3Com BAPI, enable/disable ECM char
bapiecm	equ	0b1h		; 3Com BAPI, trap Enter Command Mode char

data	segment public 'kdata'
	extrn	tcptos:word		; top of stack for TCP code
	extrn	flags:byte, yflags:byte, portval:word, ttyact:byte
	extrn	crt_lins:byte, crt_cols:byte
	extrn	tcp_status:word
	extrn	tcpaddress:byte, tcpsubnet:byte, tcpdomain:byte
	extrn	tcpgateway:byte, tcpprimens:byte, tcpsecondns:byte
	extrn	tcphost:byte, tcpbcast:byte, tcpbtpserver:byte
	extrn	tcpport:word, tcppdint:word, tcpttbuf:byte, tcpnewline:byte
	extrn	tcpdebug:byte, tcpmode:byte, tcpmss:word, tcpbtpkind:byte
	extrn	tloghnd:word, tcp_rto:word
ifndef	no_terminal
	extrn	ftogmod:dword
endif	; no_terminal
data	ends

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

_DATA      SEGMENT
	public	_kmyip, _knetmask, _kdomain, _kgateway, _kns1, _kns2, _khost
	public	_kbcast, _bapiadr, _bapireq, _bapiret
	public	_display_mode, _kport, _kpdint, _kserver, _kdebug, _kterm
	public	_ktttype, _kterm_lines, _kterm_cols, _kbtpserver, _tcp_status
	public	_tcpflag, _ktnmode, _ktcpmss, int8cnt
	extrn	_msgcnt:word, _msgbuf:byte, _echo:byte, _bootmethod:byte

		db 10 dup (0)		; guard
		db 'DUMMY',0   		; null pointer guard
_kmyip		db 17 dup (0)		; our IP number
_knetmask	db 17 dup (0)		; our netmask
_kdomain	db 33 dup (0)		; our domain
_kgateway 	db 33 dup (0)		; our gateway
_kns1		db 17 dup (0)		; our nameserver #1
_kns2		db 17 dup (0)		; our nameserver #2
_khost		db 61 dup (0)		; remote host name/IP #
_kbcast		db 17 dup (0)		; broadcast IP
_ktttype	db 33 dup (0)		; terminal-type override string
_kbtpserver	db 17 dup (0)		; Bootp server which responded
_kserver	dw	0		; non-zero for Kermit server
_kport		dw	23		; TCP port (Telnet = 23)
_kpdint		dw	0		; Packet Driver Int, 0 = search
_kdebug		db	0		; if SET DEBUG ON is effective
_ktnmode	db	0		; Telnet mode (0=NVT-ASCII,1=BINARY)
_kterm		dw	0		; terminal type index, see symboldefs.h
_kterm_lines	db	0		; terminal screen height (24)
_kterm_cols	db	0		; terminal screen width (80)
_ktcpmss	dw	0		; MSS override
oldint8	dd	0			; original Int 8 owner
tcpstack dd	0			; TCP code stack
stack8	dd	0			; stack at Int 8 invokation
kstack	dw	0			; Kermit mainline stack pointer
tempax	dw	0			; a temp
_tcpflag db	0		; who is running TCP code: 1=Kermit, 2=Int 8
int8cnt	db	0			; Int 8 times called counter
hooked	db	0			; Int 8 hooked status (0 = unhooked)
_display_mode db 0			; msg, none if == 0
_bapireq dw	0			; BAPI count of chars requested
_bapiret dw	0			; BAPI count of chars processed
_bapiadr dd	0
_tcp_status dw	0			; tcp/ip status from msntnd.c
_DATA      ENDS

_TEXT	segment
	ASSUME  CS: _TEXT, DS: DGROUP, SS: DGROUP, es:nothing
	extrn	_serial_handler:near, _tnmain:near, _tnexit:near 
	extrn	_pkt_release:near, _tcp_tick:near
	extrn	_strlen:near, _strcpy:near, _session_close:near
	extrn	_session_change:near

	public	cpatch
cpatch	equ	this byte
	db	(100-($-cpatch)) dup (0)	; _TEXT segment patch buffer

public	_enable
enable	proc	near
_enable	equ	this byte
	sti
	ret
enable	endp

public	_disable
disable	proc	near
_disable equ	this byte
	cli
	ret
disable	endp

; Hook Interrupt 8h. Return AX = 1 if successful else 0.
; For use only by Telnet code as an internal procedure.
	public	_hookvect
hookvect proc	near
_hookvect equ	this byte
	cmp	hooked,0		; hooked already?
	je	hook0			; e = no
	mov	ax,1			; say success
	ret
hook0:	push	bp
	mov	bp,sp
	mov	ax,bp
	add	ax,2+2			; C sp just before this call
	cmp	word ptr tcpstack+2,0	; have setup stack?
	jne	hook1			; ne = yes
	mov	word ptr tcpstack,ax	; save as main prog stack level
hook1:	push	es
	mov	ah,getintv		; get interrupt vector
	mov	al,8			; vector number
	int	dos
	mov	ax,es
	mov	cx,cs
	cmp	ax,cx			; points to us now?
	je	hook2			; e = yes, do not touch
	mov	word ptr DGROUP:oldint8+2,ax	; save segment
	mov	word ptr DGROUP:oldint8,bx	; save offset
	mov	dx,offset ourtimer 	; new handler
	push	ds
	mov	ax,cs			; segment
	mov	ds,ax
	mov	al,8			; for Int 8
	mov	ah,setintv		; set interrupt address from ds:dx
	int	dos
	pop	ds
	mov	hooked,1		; say have hooked vector
hook2:	mov	_tcpflag,1 	; say Kermit but not Int 8 is running TCP
	mov	ax,1			; return 1 for success
	pop	es
	pop	bp
	ret
hook3:	call	unhookvect		; put any back
	xor	ax,ax			; return 0 for failure
	pop	es
	pop	bp
	ret
hookvect endp

; For use only by Telnet code as an internal procedure.
	public	_unhookvect
unhookvect proc	near
_unhookvect equ	this byte
	cmp	hooked,0		; hooked the vector?
	jne	unhook1			; ne = yes
	mov	ax,1			; say success
	ret
unhook1:push	bp
	mov	bp,sp
	push	es
	push	bx
	push	cx
	clc
	mov	tempax,0		; assume failure status
	mov	ah,getintv		; get interrupt vector
	mov	al,8			; vector number
	int	dos
	jc	unhook2			; c = failed
	mov	ax,es			; es:bx is current owner, us?
	mov	cx,cs
	cmp	ax,cx			; seg should be right here
	jne	unhook2			; ne = is not
	cmp	bx,offset ourtimer	; should be the same too
	jne	unhook2			; ne = is not, let them have the int
	mov	ax,word ptr DGROUP:oldint8+2	; segment
	mov	dx,word ptr DGROUP:oldint8	; offset
	mov	cx,dx
	or	cx,ax			; was it used by us?
	jz	unhook2			; z = no, leave alone
	push	ds
	mov	ds,ax
	mov	al,8			; for Int 8
	mov	ah,setintv		; set interrupt address from ds:dx
	int	dos
	pop	ds
	and	_tcpflag,not 2		; Int 8 no longer touches TCP
	mov	word ptr DGROUP:oldint8,0
	mov	word ptr DGROUP:oldint8+2,0
	mov	hooked,0		; say not hooked
	mov	tempax,1		; success status
	jmp	short unhook3
unhook2:mov	tempax,0		; failure
unhook3:mov	ax,tempax		; return status (1=success, 0=fail)
	pop	cx
	pop	bx
	pop	es
	pop	bp
	ret
unhookvect endp

; Int 8 routine to call the TCP code if Kermit main body does not.
; For use only by Telnet code as an internal procedure.
ourtimer proc near
	assume	ds:DGROUP, es:nothing
	push	ds
	push	ax
	mov	ax,dgroup		; set addressibility to our dgroup
	mov	ds,ax
	pushf				; simulate interrupt invokation
	call	dword ptr DGROUP:oldint8 ; call previous owner of Int 8
	mov	ax,DGROUP		; set addressibility to our dgroup
	mov	ds,ax
	test	_tcpflag,1+2		; is TCP code running now?
	jnz	ourtim2			; nz = yes, so we don't run now
	mov	al,int8cnt		; get our times-called counter
	inc	al			; up once again
	and	al,3			; keep 2 bits, about .25 sec @18.2t/s
	mov	int8cnt,al		; store
	or	al,al			; is it zero?
	jnz	ourtim2			; nz = no, go away for awhile
	or	_tcpflag,2		; say we are running the TCP code
	push	bp
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	es
	mov	ax,DGROUP
	mov	es,ax
	cli
	mov	ax,ss
	mov	word ptr stack8+2,ax	; save current stack
	mov	word ptr stack8,sp
	mov	ax,word ptr tcpstack+2	; get TCP stack seg
	mov	ss,ax			; set to TCP stack
	mov	sp,word ptr tcpstack
	sti				; restart interrupts
	xor	ax,ax			; socket pointer, null
	push	ax			; set call frame for tcp_tick(NULL)

	call	_tcp_tick		; process some incoming packets
	pop	ax			; clean call frame
	mov	ax,DGROUP
	mov	ds,ax
	mov	ax,word ptr stack8+2	; get original stack seg
	cli
	mov	ss,ax
	mov	sp,word ptr stack8
	sti
	pop	es
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	bp
	and	_tcpflag,not 2		; finished our running of TCP code
ourtim2:pop	ax
	pop	ds
	iret
ourtimer endp

; This routine is invoked from outside by a Far call. Enter with the caller's
; registers but our CS. Switch stacks and data segments.
; This version supports 3Com BAPI calls and does the near/far stuff via
; a local buffer.
; AH holds BAPI request code
; ES:BX is pointer to user's buffer, CX holds request count.
	public	ktcpcom
ktcpcom	 proc	FAR			; i/o service routine
	assume	ds:DGROUP, es:nothing
	push	ds
	push	ax
	mov	ax,DGROUP		; set addressibility to our dgroup
	mov	ds,ax
	pop	ax
	cmp	hooked,0		; have we inited (hooked vectors)?
	je	ourser7			; e = no, report nothing
	test	_tcpflag,2		; is Int 8 running TCP?
	jz	ourser8			; z = no, opposite should never happen
ourser7:mov	ah,1			; say no char written
	xor	cx,cx			; chars written
	pop	ds
	ret

ourser8:or	_tcpflag,1		; say we are running TCP
	push	es			; save regs on the user's stack
	push	di
	push	si
	push	dx
	push	bx
	push	bp
	mov	kstack,sp		; remember caller's stack now
	mov	sp,word ptr tcpstack	; move to our TCP stack
	mov	word ptr _bapiadr,bx	; remember caller's es:bx
	mov	word ptr _bapiadr+2,es	;  (i/o buffer address)
	mov	_bapireq,cx		; requested char count to TCP code
	mov	_bapiret,0		; init returned CX char count
	cmp	ah,bapihere		; presence check?
	jne	ourser2			; ne = no
	mov	ax,0af01h		; return this value
	jmp	ourser4			; done

ourser2:cmp	ah,bapiread		; read?
	jne	ourser3			; ne = no
	cmp	_msgcnt,0		; any outstanding msgs from TCP?
	je	ourser3			; e = no msgs
	call	oursmsg			; send back the msgs instead
	jnc	ourser4			; nc = gave data, ax has status of ok
ourser3:
	mov	bx,DGROUP		; set up es to dgroup too
	mov	es,bx			; bx is not needed at this time
	ASSUME	DS:DATA
	push	ds
	mov	bx,seg data		; address main body
	mov	ds,bx
	mov	es:_kserver,0		; assume not a server
	test	flags.remflg,dserver	; Server mode?
	jz	ourser3a		; z = no
	mov	es:_kserver,1		; say being a server
ourser3a:
	push	ax
	mov	al,tcpdebug		; debug option
	mov	es:_kdebug,al
	pop	ax
	pop	ds			; return ds to dgroup

	ASSUME	DS:DGROUP, ES:DGROUP
	xchg	ah,al			; put BAPI function code in al
	xor	ah,ah
	push	ax			; setup call frame

	call	_serial_handler		; a near call, _serial_handler(ax)
					; reg ax has return status
	add	sp,2			; clean stack
	mov	cx,DGROUP		; local addressing again
	mov	ds,cx
	mov	cx,_bapiret		; CX has count of chars returned
ourser4:clc				; assume success
	xchg	ah,al			; put return status in ah
	xor	al,al
	cmp	ah,3			; serious error status?
	jb	ourserx			; b = no, zero is success
	stc				; set carry too
ourserx:mov	sp,kstack 		; move to caller's stack
	and	_tcpflag,not 1		; say we are not running TCP
	pop	bp
	pop	bx
	pop	dx
	pop	si
	pop	di
	pop	es
	pop	ds
	ret				; AX and CX are changed as returns
ktcpcom endp

; Copy contents of msgbuf (local Telnet msg collector buffer) to main body.
; For use only by Telnet code as an internal procedure.
; Return CX as number of bytes delivered to Kermit main body.
oursmsg	proc	near
	assume	ds:DGROUP, es:nothing
	cmp	_msgcnt,0
	jne	oursmsg1		; ne = have msg
	stc				; say nothing done here
	ret
oursmsg1:
	push	es			; debug to log file
	mov	bx,seg tloghnd		; transaction log handle segment
	mov	es,bx
	mov	bx,es:tloghnd		; transaction log handle
	pop	es
	cmp	bx,-1			; transaction log open?
	je	oursmsg2		; e = no, no file writing
	push	ax
	push	cx
	mov	cx,_msgcnt
	mov	dx,offset DGROUP:_msgbuf ; ds:dx is source buffer
	mov	ah,write2		; write cx bytes with handle in bx
	int	dos
	sub	_msgcnt,ax		; deduct quantity written
	pop	cx			; preserve original cx
	pop	ax			; preserve original request in ax
	stc				; say no data to be read from here
	ret
oursmsg2:				; debug to main body
	push	ax
	push	cx
	mov	cx,_msgcnt
	cmp	cx,_bapireq		; longer than request?
	jbe	oursmsg3		; be = no
	mov	cx,_bapireq		; do this much now
oursmsg3:
	push	cx
	push	es
	mov	si,DGROUP
	mov	ds,si
	mov	si,offset DGROUP:_msgbuf ; whence it comes
	les	di,_bapiadr		; where it goes
	cld
	rep	movsb			; copy Telnet buffer to main body
	pop	es
	pop	cx			; return count in cx
	mov	_bapiret,cx		; return count to user
	sub	_msgcnt,cx		; deduct chars relayed
	cmp	_msgcnt,0		; examine remainder
	je	oursmsg4		; le = none
	push	es
	mov	si,DGROUP
	mov	es,si
	mov	si,offset DGROUP:_msgbuf ; whence it comes
	mov	di,si
	add	si,cx			; number bytes read
	mov	cx,_msgcnt		; number of bytes remaining
	cld
	rep	movsb
	pop	es
oursmsg4:pop	cx			; caller's request count
	pop	ax			; and function code
	mov	cx,_bapiret		; original count minus filled here
	xor	ax,ax			; return status of success
	clc				; filled caller's buffer
	ret				; cx has delivered byte count
oursmsg	endp


; tcpaddress db	'unknown',(32-($-tcpaddress)) dup (0),0
; tcpsubnet  db	'255.255.255.0',(32-($-tcpsubnet)) dup (0),0
; tcpdomain  db	'unknown',(32-($-tcpdomain)) dup (0),0
; tcpgateway db	'unknown',(32-($-tcpgateway)) dup (0),0
; tcpprimens db	'unknown',(32-($-tcpprimens)) dup (0),0
; tcpsecondns db 'unknown',(32-($-tcpsecondns)) dup (0),0
; tcphost db	(60 -($-tcphost)) dup (0),0
; tcpbcast db	'255.255.255.255',(32-($-tcpbcast)) dup (0),0
; tcpport dw	23
; tcppdint dw	0
; tcpttbuf db	32 dup (0),0		; term-type-override buffer
; tcpmss   dw	1500
; 
; tcpdata dw	offset tcpaddress ; externally visible far pointers
; 	dw	offset tcpsubnet	+ 2
; 	dw	offset tcpdomain	+ 4
; 	dw	offset tcpgateway	+ 6
; 	dw	offset tcpprimens	+ 8
; 	dw	offset tcpsecondns	+ 10
;	dw	offset tcphost		+ 12
;	dw	offset tcpbcast		+ 14
;	dw	offset tcpport		+ 16
;	dw	offset tcppdint		+ 18
;	dw	offset tcpttbuf		+ 20
;	dw	offset tcpbtpserver	+ 22
;	dw	offset tcpnewline	+ 24
;	dw	offset tcpdebug		+ 26
;	dw	offset tcpmode		+ 28
;	dw	offset tcpmss		+ 30
;
; Open a TCP/IP Telnet connection. Returns -1 if failure or if success it
; returns the small int session ident code. Creates a new session; use
; ktcpswap to reactivate existing sessions.
	public	ktcpopen
ktcpopen proc	far
	ASSUME	DS:DATA, ES:DGROUP
	push	es			; save regs on main Kermit stack
	push	ds
	push	di
	push	si
	push	dx
	push	cx
	push	bx
	push	bp
	mov	ax,DGROUP
	mov	es,ax			; destination is the TCP module
	cld
	mov	si,offset tcpaddress	; get offset of our IP address
	mov	di,offset DGROUP:_kmyip	; our storage slot
	mov	cx,16			; max bytes
start5:	lodsb
	stosb
	or	al,al
	loopne	start5			; copy IP address string, asciiz
	xor	al,al			; extra terminator
	stosb
	mov	si,offset tcpsubnet	; subnet mask
	mov	di,offset DGROUP:_knetmask
	mov	cx,16
start6:	lodsb
	stosb
	or	al,al
	loopne	start6
	xor	al,al
	stosb
	mov	si,offset tcpdomain	; domain
	mov	di,offset DGROUP:_kdomain
	mov	cx,32
start7:	lodsb
	stosb
	or	al,al
	loopne	start7
	xor	al,al
	stosb
	mov	si,offset tcpgateway		; gateway
	mov	di,offset DGROUP:_kgateway
	mov	cx,16
start8:	lodsb
	stosb
	or	al,al
	loopne	start8
	xor	al,al
	stosb
	mov	si,offset tcpprimens		; primary nameserver
	mov	di,offset DGROUP:_kns1
	mov	cx,16
start9:	lodsb
	stosb
	or	al,al
	loopne	start9
	xor	al,al
	stosb
	mov	si,offset tcpsecondns		; secondary nameserver
	mov	di,offset DGROUP:_kns2
	mov	cx,16
start10:lodsb
	stosb
	or	al,al
	loopne	start10
	xor	al,al
	stosb
	mov	si,offset tcphost		; remote host IP
	mov	di,offset DGROUP:_khost
	mov	cx,60
start11:lodsb
	stosb
	or	al,al
	loopne	start11
	xor	al,al
	stosb
	mov	si,offset tcpbcast		; IP broadcast
	mov	di,offset DGROUP:_kbcast
	mov	cx,16
start12:lodsb
	stosb
	or	al,al
	loopne	start12
	xor	al,al
	stosb
	mov	ax,tcpport		; port
	mov	es:_kport,ax
	mov	ax,tcppdint		; Packet Driver Interrupt
	mov	es:_kpdint,ax		; 0 means scan
	mov	si,offset tcpttbuf	; offset of term-type string
	mov	di,offset DGROUP:_ktttype ; local storage of the string
	mov	cx,32
start13:lodsb
	stosb
	or	al,al
	loopne	start13
	xor	al,al
	stosb
	mov	al,tcpdebug		; debug-Options
	mov	es:_kdebug,al
	mov	al,tcpmode		; mode
	mov	es:_ktnmode,al
	mov	ax,tcpmss		; MSS override
	mov	es:_ktcpmss,ax

	mov	si,portval
	mov	al,[si].ecoflg		; mainline SET echo flag
	mov	es:_echo,al		; init Options to this value

	mov	es:_display_mode,0	; presume quiet screen
	test	flags.remflg,dquiet	; quiet display mode?
	jnz	start14			; nz = yes. Don't write to screen
	inc	es:_display_mode	; say can write to screen
start14:mov	es:_kserver,0		; assume not a server
	test	flags.remflg,dserver	; Server mode?
	jz	start16			; z = no
	mov	es:_kserver,1		; say being a server (do Listen)
start16:mov	ax,flags.vtflg		; get terminal type index
	mov	es:_kterm,ax

start20:mov	bx,portval
	mov	al,[bx].ecoflg		; get mainline SET echo flag
	mov	es:_echo,al		; init Telnet echo status
	mov	bx,tcptos		; top of stack for tcp code

	assume	ds:DGROUP, ES:NOTHING
	
	mov	ax,dgroup		; set addressibility to our dgroup
	mov	ds,ax
	mov	es,ax
					; cold vs warm start
	mov	word ptr kstack,sp	; store Kermit's stack ptr
	cmp	word ptr tcpstack+2,0	; defined setup yet?
	je	start1			; e = no, get stack segment
	mov	ax,word ptr tcpstack	; set sp to existing TCP sp
	mov	sp,ax			; warm restart
	jmp	short start2

start1:	mov	word ptr tcpstack+2,ax	; set TCP stack seg to DGROUP
	mov	word ptr tcpstack,bx	; cold start
	mov	sp,bx			; new TCP stack pointer, DGROUP based

start2:	mov	bp,sp			; preset this as insurance
	or	_tcpflag,1		; say this is running TCP code

	call	_tnmain			; call the C code
	mov	sp,word ptr kstack	; restore for Kermit's main stack

	ASSUME	ES:DATA
	mov	bx,data			; main Kermit data segment
	mov	es,bx
	mov	bx,_tcp_status		; status from msntnd.c
	mov	es:tcp_status,bx	; return tcp_status to main body
	mov	bx,_kpdint		; report back Packet Driver Int
	mov	es:tcppdint,bx		; store value in main data seg
	ASSUME	ES:NOTHING
	and	_tcpflag,not 1		; finished running tcp code
	pop	bp			; restore regs, Kermit's main stack
	pop	bx
	pop	cx
	pop	dx
	pop	si
	pop	di
	pop	ds
	pop	es
	ret				; return to caller, status in AX
ktcpopen endp

; Close session whose session ident is in register AL. If AL holds -1
; then shut down all sessions and shutdown Telnet. Returns ident of next
; active session (cyclic from the current session ident) or -1 if none
; remains active.
	public	ktcpclose
ktcpclose proc	far
	assume	ds:dgroup, es:nothing
	push	es			; save regs on the user's stack
	push	ds
	push	di
	push	si
	push	dx
	push	cx
	push	bx
	push	bp
	mov	cx,dgroup		; set addressibility to dgroup
	mov	ds,cx
	mov	es,cx
	mov	kstack,sp		; remember Kermit's main sp
	cmp	word ptr tcpstack+2,0	; have setup stack?
	jne	ktcpclo4		; ne = yes
	mov	ax,-1			; set failure status
	jmp	short ktcpclo6		; e = no, skip this routine

ktcpclo4:or	_tcpflag,1		; say we are running TCP code
	mov	cx,word ptr tcpstack	; set sp to TCP sp
	mov	sp,cx
	mov	bp,sp			; preset this as insurance
	cbw				; sign extend
	cmp	al,-1			; close all sessions and TCP/IP?
	je	ktcpclo5		; e = yes
	push	ax			; AL = session number
	call	_session_close		; close this session
	add	sp,2			; returns status in AL
	jmp	short ktcpclo6		; common completion code

ktcpclo5:				; forceful shutdown of TCP/IP Telnet
	xor	ax,ax
	push	ax			; tnexit(0) setup
	call	_tnexit
	add	sp,2			; returns status in AX
ktcpclo6:cbw				; sign extend
	mov	sp,kstack
	mov	_tcpflag,0		; no one is running the TCP code
	pop	bp			; restore regs, Kermit's main stack
	pop	bx
	pop	cx
	pop	dx
	pop	si
	pop	di
	pop	ds
	pop	es
	ret				; return to caller
ktcpclose endp

; Change active sessions. Enter with AL holding desired session ident.
; Returns -1 if failure, else returns active session ident.
	public	ktcpswap
ktcpswap proc	far
	assume	ds:dgroup, es:nothing
	push	es			; save regs on the user's stack
	push	ds
	push	di
	push	si
	push	dx
	push	cx
	push	bx
	push	bp
	mov	cx,dgroup		; set addressibility to our dgroup
	mov	ds,cx
	mov	es,cx
	cmp	word ptr tcpstack+2,0	; have setup stack?
	jne	ktcpswap1		; ne = yes
	mov	ax,-1			; set failure status
	jmp	short ktcpswap2		; fail
ktcpswap1:or	_tcpflag,1		; say we are running TCP code
	mov	kstack,sp		; remember Kermit's main sp
	mov	sp,word ptr tcpstack	; move to our TCP stack
	mov	bp,sp			; preset this as insurance

	cbw				; sign extend now
	push	AX			; new session number
	call	_session_change
	add	sp,2			; pop argument, status is in AX
	mov	_tcpflag,0		; no one is running the TCP code
	mov	sp,kstack
ktcpswap2:pop	bp			; restore regs, Kermit's main stack
	pop	bx
	pop	cx
	pop	dx
	pop	si
	pop	di
	pop	ds
	pop	es
	ret				; return to caller
ktcpswap endp

; Copies TCP/IP info from Telnet space to main Kermit space via table of
; pointers tcpdata (in segment data, file mssset.asm).
; For use only by Telnet code as an internal procedure.
	public	_readback
_readback proc	near
	assume	ds:dgroup, es:nothing
	push	bp
	mov	bp,sp
	push	si
	push	di
	push	es
	mov	si,offset dgroup:_kmyip
	push	si
	push	si				; argument
	call	_strlen				; get length of string
	add	sp,2				; ax has string length
	pop	si

	ASSUME	ES:DATA

	mov	di,DATA
	mov	es,di
	mov	di,offset tcpaddress		; offset of the string
	mov	cx,ax				; length
	cld
	rep	movsb
	xor	al,al
	stosb					; terminator
	mov	si,offset dgroup:_knetmask
	mov	di,offset tcpsubnet
	mov	cx,17
	rep	movsb
	stosb					; terminator
	mov	si,offset dgroup:_kdomain
	mov	di,offset tcpdomain
	mov	cx,32
	rep	movsb
	stosb					; terminator
	mov	si,offset dgroup:_kgateway
	mov	di,offset tcpgateway
	mov	cx,17
	rep	movsb
	stosb					; terminator
	mov	si,offset dgroup:_kns1
	mov	di,offset tcpprimens
	mov	cx,17
	rep	movsb
	stosb					; terminator
	mov	si,offset dgroup:_kns2
	mov	di,offset tcpsecondns
	mov	cx,17
	rep	movsb
	stosb					; terminator
	mov	si,offset dgroup:_khost
	mov	di,offset tcphost
	mov	cx,60
	rep	movsb
	stosb					; terminator
	mov	di,offset tcpbtpserver
	mov	cx,16
	mov	si,offset dgroup:_kbtpserver
	rep	movsb
	stosb					; terminator
	mov	di,offset tcpbtpkind
	mov	al,_bootmethod
	stosb
	pop	es
	pop	di
	pop	si
	pop	bp
	ret
_readback endp

; Track Telnet echo variable (0 do not do local echo) into terminal emulator
; and Kermit main body. Call this each time Telnet options change echo.
; For use only by Telnet code as an internal procedure.
	public	_kecho
_kecho	proc	near
	assume	ds:data, es:dgroup
	push	bp
	mov	bp,sp
	push	ds
	push	es
	push	si
	push	ax
	mov	ax,data			; Kermit main data segment
	mov	ds,ax
	mov	ax,DGROUP
	mov	es,ax
	mov	ax,[bp+4+0]		; get Telnet _echo variable
	and	yflags,not lclecho	; assume no local echo in emulator
	or	al,al			; Telnet local echo is off?
	jz	kecho1			; z = yes
	mov	al,lclecho		; lclecho flag for emulator
kecho1:	or	yflags,al		; set terminal emulator
	mov	si,portval
	mov	[si].ecoflg,al		; set mainline SET echo flag
ifndef	no_terminal
	cmp	ttyact,0		; acting as a Terminal?
	je	kecho2			; e = no
	call	dword ptr ftogmod	; toggle mode line
	call	dword ptr ftogmod	; and again
endif	; no_terminal
kecho2:	pop	ax
	pop	si
	pop	es
	pop	ds
	pop	bp
	ret
_kecho	endp

; Track Telnet dobinary variable into Kermit main body. 
; Call this each time Telnet options change dobinary.
; For use only by Telnet code as an internal procedure.
	public	_kmode
_kmode	proc	near
	assume	ds:data, es:nothing
	push	bp
	mov	bp,sp
	push	ds
	push	ax
	push	bx
	mov	ax,data			; Kermit main data segment
	mov	ds,ax
	mov	al,[bp+4+0]		; get Telnet _dobinary variable
	mov	tcpmode,al		; update main body
	pop	bx
	pop	ax
	pop	ds
	pop	bp
	ret
_kmode	endp

; Get current terminal emulation screen lines and columns
	public	_get_kscreen
_get_kscreen	proc	near
	assume	ds:data, es:DGROUP
	push	ds
	push	es
	mov	ax,seg data		; address main body
	mov	ds,ax
	mov	ax,DGROUP
	mov	es,ax
	mov	al,ds:crt_lins		; get display height
	mov	es:_kterm_lines,al
	mov	al,ds:crt_cols		; get display width
	mov	es:_kterm_cols,al
	pop	es
	pop	ds
	ret
_get_kscreen	endp

; Report s->rto to tcp_rto variable for mainline Kermit
	public	_krto
_krto	proc	near
	ASSUME	ES:DATA
	push	bp
	mov	bp,sp
	push	es
	mov	ax,seg DATA
	mov	es,ax
	mov	ax,[bp+4]		; get s->rto
	mov	es:tcp_rto,ax		; report to mainline code
	pop	es
	pop	bp
	ret
	ASSUME	ES:NOTHING
_krto	endp
_TEXT	ends
        end

