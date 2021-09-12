 	NAME	msster
; File MSSTER.ASM
	include mssdef.h
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

	public	clscpt, defkey, clscpi, ploghnd, sloghnd, tloghnd
	public  dopar, shokey, cptchr, pktcpt, targ, replay, repflg
	public	kbdflg, shkadr, telnet, ttyact, write, dec2di, caplft
	public	cnvlin,  decout, valout, cnvstr, writeln
	public	pntchr, pntflsh, pntchk, prnhand, prnopen
	public	vfopen, vfread, ldiv, lmul, lgcd, atoi, atoibyte
	public  domath, domath_ptr, domath_cnt, domath_msg
	public	atoi_cnt, atoi_err, tod2secs

braceop	equ	7bh			; opening curly brace
bracecl	equ	7dh			; closing curly brace

data 	segment
	extrn	flags:byte, trans:byte, diskio:byte, portval:word
	extrn	rdbuf:byte, dosnum:word, filtst:byte, prnname:byte
	extrn	comand:byte, kstatus:word, flowon:byte, flowoff:byte
	extrn	cardet:byte
ifndef	no_terminal
	extrn	anspflg:byte
endif	; no_terminal

targ	termarg	<0,1,cptchr,0,parnon>
crlf    db      cr,lf,'$'
tmsg1	db	cr,lf,'(Connecting to host, type $' 
tmsg3	db	' C to return to PC)',cr,lf,cr,lf,cr,lf,'$'
erms21	db	cr,lf,'?Cannot start the connection.$'
erms25	db	cr,lf,'?Input must be numeric$' 
erms22	db	cr,lf,'?No open logging file$'
erms23	db	'*** Error writing session log, suspending capture ***$'
erms24	db	cr,lf,'?Error writing Packet log$'
erms26	db	' *** PRINTER IS NOT READY ***  press R to retry'
	db	' or D to discard printing:  $'
erms27	db	cr,lf
	db	'? Carrier signal not detected on this serial port.'
	db	cr,lf
	db    '  Use the DIAL command, SET CARRIER OFF, or check your modem.$'

esctl	db	'Control-$'
repflg	db	0		; REPLAY or SET TERM REPLAY filespec flag
reperr	db	cr,lf,'?File not found$'	; for REPLAY command
noterm	db	cr,lf,'Connect mode is not built into this Kermit$'
vfopbad	db	cr,lf,'?Cannot open file $'	; filename follows
vfclbad	db	cr,lf,'?Cannot close file$'
vfoptwice db	cr,lf,'?File is already open$'
vfnofile db	cr,lf,'?File is not open$'
vfrbad	db	cr,lf,'?Error while reading file$'
vfwbad	db	cr,lf,'?Error while writing file$'
vfrdbad	db	cr,lf,'?more parameters are needed$'
vfrhandle dw	-1			; READ FILE handle (-1 = invalid)
vfwhandle dw	-1			; WRITE FILE handle

opntab	db	3			; OPEN FILE table
	mkeyw	'Read',1
	mkeyw	'Write',2
	mkeyw	'Append',3

inthlp db cr,lf,' ', 22 dup ('-'),' Special keys within Connect mode '
       db	22 dup ('-')
       db cr,lf,'                           numeric keypad keys:'
       db cr,lf,'  Pg Up/Dn  roll screen vertically   Ctrl Pg Up/Dn  roll'
       db	' screen one line '
       db cr,lf,'  Home/End  roll to start/end screen Ctrl End screen dump'
       db cr,lf,'  - (minus) toggle status/mode line'
       db cr,lf,'                           other key combinations:'
       db cr,lf,'  Alt-b  send a BREAK                Alt-n  next active'
       db	' Telnet session'
       db cr,lf,'  Alt-c  start Compose sequence      Alt-x  exit emulator'
       db cr,lf,'  Alt-h  show this menu              Alt-z  network session'
       db	' hold'
       db cr,lf,'  Alt-= or Alt-r  reset emulator     Alt--  toggle terminal'
       db	' type'
       db cr,lf,'  Ctrl Prtscrn  toggle printing'
       db cr,lf,'  Additional commands are escape character '
inthlpc db '  '
       db	' followed by special characters.'
       db cr,lf,' ',78 dup ('-')
       db cr,lf,'  7n1 = SET TERM BYTE 7, SET PARITY NONE, 1 stop bit'
       db cr,lf,'  8n1 = SET TERM BYTE 8, SET PARITY NONE, 1 stop bit'
       db cr,lf,'  7e1 = SET PARITY EVEN, 1 stop bit   7s1 = SET PARITY SPACE'
       db	', 1 stop bit'
       db cr,lf,'  7o1 = SET PARITY ODD,  1 stop bit   7m1 = SET PARITY MARK'
       db	',  1 stop bit'
       db cr,lf,'  press a key to exit this menu'
       db	0

intqry db cr,lf,' ',20 dup ('-'),' Single character commands active now ' 
       db	20 dup ('-')
       db cr,lf,'  ?  Show this menu                  F  Dump screen to file'
       db cr,lf,'  C  Close the emulator              P  Push to DOS'
       db cr,lf,'  S  Status of the connection        Q  Quit logging'
       db cr,lf,'  M  Toggle mode line                R  Resume logging'
       db cr,lf,'  B  Send a Break                    0  Send a null'
       db cr,lf,'  L  Send a long 1.8 s Break         H  Hangup phone'
       db cr,lf,'  A  Send Telnet "Are You There"     I  Send Telnet' 
       db	' "Interrupt Process"' 
       db cr,lf,'  Typing the escape character '
intqryc db '  '					; where escape char glyphs go
       db	' will send it to the host'
       db cr,lf,'  press space bar to exit this menu'
       db 0

intprm	db	'Command> $'
intclet	db	'B','C','F','H','L'	; single letter commands
	db	'M','P','Q','R','S'	; must parallel dispatch table intcjmp
	db	'?','0','A','I'
numlet	equ	$ - intclet		; number of entries
	even
ifndef	no_terminal
intcjmp	dw	intchb,intchc,intchf,intchh,intchl
	dw	intchm,intchp,intchq,intchr,intchs
	dw	intchu,intchn,intayt,inttip
endif	; no_terminal

prnhand	dw	4		; printer file handle (4 = DOS default)

	even
ploghnd	dw	-1		; packet logging handle
sloghnd	dw	-1		; session logging handle
tloghnd	dw	-1		; transaction logging handle

clotab	db	6
	mkeyw	'READ-FILE',4001h
	mkeyw	'WRITE-FILE',4002h
	mkeyw	'All-logs',logpkt+logses+logtrn
	mkeyw	'Packets',logpkt
	mkeyw	'Session',logses
	mkeyw	'Transactions',logtrn

clseslog db	cr,lf,' Closing Session log$'
clpktlog db	cr,lf,' Closing Packet log$'
cltrnlog db	cr,lf,' Closing Transaction log$'

writetab db	5			; Write command log file types
	mkeyw	'FILE',4002h		; FILE
	mkeyw	'Packet',logpkt
	mkeyw	'Screen',80h		; unused value, to say screen
	mkeyw	'Session',logses
	mkeyw	'Transaction',logtrn

sttmsg	db	cr,lf,'Press space to continue ...$'
kbdflg	db	0			; non-zero means char here from Term
ttyact	db	1			; Connect mode active, if non-zero
shkadr	dw	0			; offset of replacement Show Key cmd
nbase	dw	10			; currently active number base
temp	dw	0
temp1	dw	0
tmp	db	0
tmp1	db	0
tmpstring db	6 dup (0)		; local string work buffer
pktlft	dw	cptsiz		; number free bytes left
caplft	dw	cptsiz		; number free bytes left

maxdepth equ	8			; domath, parenthesis nesting depth
listlen equ	6			; domath, outstanding numbers and ops
parendepth db	0			; domath, depth of ()'s
mathkind db	0			; domath, math operator symbol, temp
operators db	'()!~^*/%&+-|#@'	; domath, math operator list
operator_len equ $ - operators		; domath, length of the list
precedence db	6,6,5,4,3, 2,2,2,2,1, 1,1,1,1 ; domath, precedence of ops
fevalst	struc		; structure of demath work stacks, all on the stack
  savebp	dw	0		; where bp is pushed
  numcnt	dw	0		; count of values in numlist
  numlist	dw listlen dup (0,0)	; list of dword values
  opcnt		dw	0		; count of operators in oplist
  oplist	dw  listlen dup (0)	; list of pending operators
fevalst	ends
domath_ptr dw	0			; ds:offset of domath input text
domath_cnt dw	0			; count of bytes in input text
domath_msg dw	0			; non-zero to allow error msgs
matherr dw	0			; non-zero = offset of error msg
opmsg	db	'?too many math operators or too few values $'
opmsg1	db	'?math operator missing or invalid $'
opmsg2	db	'?unknown math symbol: $'
opmsg3 db	'?math expression error $'
opmsg4	db	'?parentheses nested too deeply $'
atoibyte db	0			; non-zero to say convert one char
atoi_err db	0			; atoi return error codes
atoi_cnt dw	0			; atoi, bytes supplied to/remaining
data	ends

data1	segment
rephlp	db	'name of file to playback$'
clohlp	db	cr,lf,' READ-FILE or WRITE-FILE, or the following log files:'
	db	cr,lf,' All-logs, Packets, Session, Transaction$'
msgtxt	db	'text to be written$'
vfophlp	db	'Filename$'
vfrdmsg	db	'name of variable  into which to read a line from file$'
pktbuf	db	cptsiz dup (0)	; packet logging buffer
pktbp	dw	pktbuf		; buffer pointer to next free byte
capbuf	db	cptsiz dup (0)	; session logging buffer
capbp	dw	capbuf		; buffer pointer to next free byte
prnbuf	db	cptsiz dup (0)	; printer buffer
pntptr	dw	prnbuf		; pointer to next free byte
data1	ends

code1	segment
	extrn	iseof:far, strlen:far, prtasz:far, isfile:far
	assume	cs:code1
code1	ends

code	segment
	extrn 	comnd:near, outchr:near, stat0:near, pcwait:far
	extrn	beep:near, puthlp:near, serhng:near, lnout:near
	extrn	serini:near, serrst:near, sendbr:near, putmod:near
	extrn	fpush:near,  sendbl:near, trnmod:near, dodecom:near
ifndef	no_terminal
	extrn	dumpscr:near,term:near
endif	; no_terminal
flnout	proc	far
	call	lnout
	ret
flnout	endp
	assume	cs:code, ds:data, es:nothing

; the show key command
shokey	proc	near
	cmp	shkadr,0		; keyboard translator present?
	je	shokey1			; e = no, use regular routines
	mov	bx,shkadr		; get offset of replacement routine
	jmp	bx			; and execute it rather than us
shokey1:clc
	ret
shokey	endp
; enter with ax/scan code to define, si/ pointer to definition, cx/ length
; of definition.  Defines it in definition table. Obsolete.
defkey	proc	near
	ret
defkey	endp


; This is the CONNECT command
ifdef	no_terminal
TELNET 	PROC	NEAR
	mov	ah,cmeol
	call	comnd			; get a confirm
	jnc	teln1			; nc = success
	ret
teln1:	mov	ah,prstr
	mov	dx,offset noterm
	int	dos
	clc
	ret
TELNET	ENDP
endif	; no_terminal
 
ifndef	no_terminal
TELNET 	PROC	NEAR
	mov	ah,cmeol
	call	comnd			; get a confirm
	jnc	teln1			; nc = success
	ret
teln1:	cmp	repflg,0		; REPLAY?
	jne	teln1d			; ne = yes
	call	serini			; ensure port is inited now
	jnc	teln1a			; nc = success
	test	flags.remflg,dquiet	; quiet display mode?
	jnz	teln1b			; nz = yes. Don't write to screen
	mov	dx,offset erms21	; say cannot start connection
	mov	ah,prstr
	int	dos
teln1b:	or	kstatus,ksgen		; general command failure
	ret
teln1a:	cmp	flags.comflg,'F'	; Fossil port?
	je	teln1c			; e = yes
	cmp	flags.comflg,'4'	; using real or Bios serial ports?
	ja	teln1d			; a = no
teln1c:	cmp	flags.carrier,0		; want CD on now?
	je	teln1d			; e = no
	test	cardet,80h		; CD on?
	jnz	teln1d			; nz = yes
	mov	ah,prstr		; complain on screen
	mov	dx,offset erms27
	int	dos
	stc				; fail
	ret
teln1d:	cmp	flags.vtflg,0		; emulating a terminal?
	jne	teln2			; ne= yes, no wait necessary
	mov	ah,prstr
	mov	dx,offset crlf		; output a crlf
	int	dos
	call	domsg			; reassure user
	mov	ax,2000			; two seconds
	call	pcwait			; pause
teln2:	xor	al,al			; initial flags
	mov	ttyact,1		; say telnet is active
	cmp	flags.vtflg,0		; emulating a terminal?
	je	teln3			; e = no, say mode line is to be off
	cmp	flags.modflg,0		; mode line enabled?
	jne	tel010			; ne = yes
teln3:	or	al,modoff		; no, make sure it stays off

tel010:	test	flags.debug,logses	; debug mode?
	jz	tel0			; z = no, keep going
	or	al,trnctl		; yes, show control chars
tel0:	cmp	flags.vtflg,0		; emulating a terminal?
	je	tel1			; e = no
	or	al,emheath		; say emulating some kind of terminal
tel1:	mov	bx,portval
	cmp	[bx].ecoflg,0		; echoing?
	jz	tel2			; z = no
	or	al,lclecho		; turn on local echo
tel2:	mov	targ.flgs,al		; store flags
	mov	ah,flags.comflg		; COMs port identifier
	mov	targ.prt,ah		; Port 1 or 2, etc
	mov	ah,[bx].parflg		; parity flag
	mov	targ.parity,ah
	mov	ax,[bx].baud		; baud rate identifier
	mov	targ.baudb,al
	xor	ah,ah
	test	flags.capflg,logses	; select session logging flag bit
	jz	tel3			; z = no logging
	mov	ah,capt			; set capture flag
tel3:	or	targ.flgs,ah
	jmp	short tem1

TEM:	call	serini			; init serial port
	jnc	tem1			; nc = success
	clc
	ret				; and exit Connect mode

tem1:	mov	dx,offset crlf		; give user an indication that we are
	mov	ah,prstr		; entering terminal mode
	int	dos
	mov	ttyact,1		; say telnet is active
	mov	ax,offset targ		; point to terminal arguments
	call	term			; call the main Terminal procedure
	mov	al,kbdflg		; get the char from Term, if any
	mov	kbdflg,0		; clear	the flag
	or	al,al			; was there a char from Term?
	jnz	intch2			; nz = yes, else ask for one from kbd

intchar:call	iseof			; stdin at eof?
	jnc	intch1			; nc = not eof, get more
	mov	al,'C'			; use C when file is empty
	jmp	intchc			;  to provide an exit
intch1:	cmp	al,0			; asking for help?
	jne	intch1b			; ne = no
	mov	al,' '
	mov	ah,trans.escchr
	cmp	ah,' '			; printable now?
	jae	intch1a			; ae = yes
	mov	al,'^'
	add	ah,40h			; make control visible
intch1a:mov	word ptr intqryc,ax	; store escape char code
	mov	ax,offset intqry	; '?' get help message
	call	puthlp			; write help msg
	mov	dx,offset intprm
	mov	ah,prstr		; show prompt
	int	dos
intch1b:mov	ah,0ch			; clear Bios keyboard buffer and do
	mov	al,coninq		;  read keyboard, no echo
	int	dos			; get a char
	or	al,al			; scan code indicator?
	jnz	intch1c			; nz = no, ascii
	mov	ah,coninq		; read and discard scan code
	int	dos
	jmp	short intch1		; try again
intch1c:cmp	al,'?'			; want to see menu again?
	jne	intch2			; ne = no
	xor	al,al			; prep for menu display
	jmp	short intchar

intch2:	mov	flags.cxzflg,0		; prevent Control-C carryover
	cmp	al,' '			; space?
	je	tem			; e = yes, ignore it
	cmp	al,cr			; check ^M (cr) against plain ascii M
	je	tem			; exit on cr
	cmp	al,trans.escchr		; is it the escape char?
	jne	intch3			; ne = no
	mov	ah,al
	call	outchr
	jmp	tem			; return, we are done here
intch3:	push	es
	push	ds
	pop	es
	mov	di,offset intclet	; command letters
	mov	cx,numlet		; quantity of them
	cmp	al,' '			; control code?
	jae	intch3a			; ae = no
	or	al,40H			; convert control chars to printable
intch3a:cmp	al,96			; lower case?
	jb	intch3b			; b = no
	and	al,not (20h)		; move to upper case
intch3b:cld
	repne	scasb			; find the matching letter
	pop	es
	jne	intch4			; ne = not found, beep and get another
	dec	di			; back up to letter
	sub	di,offset intclet	; get letter number
	shl	di,1			; make it a word index
	jmp	intcjmp[di]		; dispatch to it
intch4:	call	beep			; say illegal character
	jmp	intchar

intayt:	mov	ah,255			; 'I' Telnet Are You There
	call	outchr			; send IAC (255) AYT (246)
	mov	ah,246
	call	outchr
	jmp	tem

intchb:	call	sendbr			; 'B' send a break
	jmp	tem			; And return

intchc:	clc				; exit Connect mode
	ret

intchf:	call	dumpscr			; 'F' dump screen, use msy routine
	jmp	tem			; and return

intchh:	call	serhng			; 'H' hangup phone
	call	serrst			; turn off port
	jmp	tem

intchl:	call	sendbl			; 'L' send a long break
	jmp	tem

inttip:	mov	ah,255			; 'I' Telnet Interrrupt Process
	call	outchr			; send IAC (255) IP (244)
	mov	ah,244
	call	outchr
	jmp	tem

intchm:	cmp	flags.modflg,1		; 'M' toggle mode line, enabled?
	jne	intchma			; ne = no, leave it alone
	xor	targ.flgs,modoff	; enabled, toggle its state
intchma:jmp	tem			; and reconnect

intchp:	call	fpush			; 'P' push to DOS
	mov	dx,offset sttmsg	; say we have returned
	mov	ah,prstr
	int	dos
	jmp	short intchsb		; wait for a space

intchq:	and	targ.flgs,not capt	; 'Q' suspend session logging
	jmp	tem			; and resume

intchr:	test	flags.capflg,logses	; 'R' resume logging. Can we capture?
	jz	intchr1			; z = no
	or	targ.flgs,capt		; turn on session logging flag
intchr1:jmp	tem			; and resume

intchs:	call	stat0			; 'S' status, call stat0
	mov	dx,offset sttmsg
	mov	ah,prstr
	int	dos
intchsa:call	iseof			; is stdin at eof?
	jnc	intchsb			; nc = not eof, get more
	jmp	tem			; resume if EOF
intchsb:mov	ah,coninq		; console input, no echo
	int	dos
	cmp	al,' '			; space?
	jne	intchsa
	jmp	tem

intchu:	mov	ah,trans.escchr
	cmp	ah,' '			; printable now?
	jae	intchu1			; ae = yes
	mov	al,'^'
	add	ah,40h			; make control visible
intchu1:mov	word ptr inthlpc,ax	; store escape char code
	mov	ax,offset inthlp	; help message
	call	puthlp			; write help msg
	mov	ah,0ch			; clear Bios keyboard buffer and do
	mov	al,coninq		;  read keyboard, no echo
	int	dos			; get a char
	or	al,al			; scan code indicator?
	jnz	intchu2			; nz = no, ascii
	mov	ah,coninq		; read and discard scan code
	int	dos
intchu2:jmp	tem			; try again

intchn:	xor	ah,ah			; '0' send a null
	call	outchr
	jmp	tem
TELNET  ENDP
endif	; no_terminal
code	ends

code1	segment
	assume cs:code1
; Reassure user	about connection to the host. Tell him what escape sequence
; to use to return

DOMSG	PROC	FAR
	mov	ah,prstr
	mov	dx,offset tmsg1
	int	dos
	call	escprt
	mov	ah,prstr
	mov	dx,offset tmsg3
	int	dos
	ret
DOMSG	ENDP

; print	the escape character in readable format.  

ESCPRT	PROC	NEAR
	mov	dl,trans.escchr
	cmp	dl,' '
	jge	escpr2
	push	dx
	mov	ah,prstr
	mov	dx,offset esctl
	int	dos
	pop	dx
	add	dl,040H		; Make it printable
escpr2:	mov	ah,conout
	int	dos
	ret
ESCPRT	ENDP
code1	ends

code	segment
	assume	cs:code 

; Set parity for character in Register AL

dopar:	push	bx
	mov	bx,portval
	mov	bl,[bx].parflg		; get parity flag byte
	test	bl,PARHARDWARE		; hardware?
	jnz	parret			; nz = yes
	cmp	bl,parnon		; No parity?
	je	parret			; Just return
	and	al,07FH			; Strip parity. Same as Space parity
	cmp	bl,parspc		; Space parity?
	je	parret			; e = yes, then we are done here
	cmp	bl,parevn		; Even parity?
	jne	dopar0			; ne = no
	or	al,al
	jpe	parret			; pe = even parity now
	xor	al,080H			; Make it even parity
	jmp	short parret
dopar0:	cmp	bl,parmrk		; Mark parity?
	jne	dopar1			; ne = no
	or	al,080H			; Turn on the parity bit
	jmp	short parret
dopar1:	cmp	bl,parodd		; Odd parity?	
	or	al,al
	jpo	parret			; Already odd, leave it
	xor	al,080H			; Make it odd parity
parret:	pop	bx
	ret

; REPLAY filespec  through terminal emulator
replay	proc	near
	mov	bx,offset rdbuf		; place for filename
	mov	dx,offset rephlp	; help
	mov	repflg,0		; clear the replay active flag
	mov	ah,cmword		; get filename
	call	comnd
	jc	replay2			; c = failure
	mov	ah,cmeol		; get an EOL confirm
	call	comnd
	jc	replay2			; c = failure
ifndef	no_terminal
	mov	ah,open2		; open file
	xor	al,al			; open readonly
	cmp	byte ptr dosnum+1,2	; above DOS 2?
	jna	replay1			; na = no, so no shared access
	mov	al,0+40h		; open readonly, deny none
replay1:mov	dx,offset rdbuf		; asciiz filename
	int	dos
	jnc	replay3			; nc = success
	mov	ah,prstr
	mov	dx,offset reperr	; Cannot open that file
	int	dos
	clc
	ret
replay3:mov	diskio.handle,ax	; file handle
	mov	repflg,1		; set replay flag
	call	telnet			; enter Connect mode
	mov	bx,diskio.handle
	mov	ah,close2		; close the file
	int	dos
endif	; no_terminal
	mov	repflg,0		; clear the flag
	clc
replay2:ret
replay	endp

cptchr	proc	near			; session capture routine, char in al
	test	flags.capflg,logses	; session logging active now?
	jz	cptch1			; z = no
	push	di
	push	es
	mov	di,data1		; seg of capbp and capbuf
	mov	es,di
	cld
	mov	di,es:capbp		; buffer pointer
	stosb
	inc	es:capbp
	pop	es
	pop	di
	dec	caplft			; decrement chars remaining
	jg	cptch1			; more room, forget this part
	call	cptdmp			; dump the info
cptch1:	ret
cptchr	endp

cptdmp	proc	near			; empty the capture buffer
	push	ax
	push	bx
	push	cx
	push	dx
	mov	bx,sloghnd		; get file handle
	or	bx,bx			; is file open?
	jle	cptdm1			; le = no, skip it
	mov	cx,cptsiz		; original buffer size
	sub	cx,caplft		; minus number remaining
	jl	cptdm2			; means error
	jcxz	cptdm1			; z = nothing to do
	push	ds
	mov	dx,data1		; seg of capbuf
	mov	ds,dx
	mov	dx,offset capbuf	; the capture routine buffer
	mov	ah,write2		; write with filehandle
	int	dos			; write out the block
	pop	ds
	jc	cptdm2			; carry set means error
	cmp	ax,cx			; wrote all?
	jne	cptdm2			; no, an error
	push	es
	mov	dx,data1		; seg of capbuf and capbp
	mov	es,dx
	mov	es:capbp,offset capbuf
	pop	es
	mov	caplft,cptsiz		; init buffer ptr & chrs left
	clc
	jmp	short cptdm1
cptdm2:	and	targ.flgs,not capt	; so please stop capturing
	and	flags.capflg,not logses	; deselect session logging flag bit
	mov	dx,offset erms23	; tell user the bad news
	call	putmod			; write on mode line
	stc
cptdm1:	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
cptdmp	endp

pktcpt	proc	near			; packet log routine, char in al
	test	flags.capflg,logpkt	; logging packets now?
	jz	pktcp1			; z = no
	push	di
	push	es
	mov	di,data1		; seg of pktbuf and pktbp
	mov	es,di
	mov	di,es:pktbp		; buffer pointer
	cld
	stosb				; store char in buffer
	inc	es:pktbp		; move pointer to next free byte
	pop	es
	pop	di
	dec	pktlft			; decrement chars remaining
	jg	pktcp1			; g = more room, forget this part
	call	pktdmp			; dump the info
pktcp1:	ret
pktcpt	endp

pktdmp	proc	near			; empty the capture buffer
	push	ax
	push	bx
	push	cx
	push	dx
	mov	bx,ploghnd		; get file handle
	or	bx,bx			; is file open?
	jle	cptdm1			; le = no, skip it
	mov	cx,cptsiz		; original buffer size
	sub	cx,pktlft		; minus number remaining
	jl	pktdm2			; l means error
	jcxz	pktdm1			; z = nothing to do
	push	ds
	mov	dx,data1		; seg of pktbuf
	mov	ds,dx
	mov	dx,offset pktbuf	; the capture routine buffer
	mov	ah,write2		; write with filehandle
	int	dos			; write out the block
	pop	ds
	jc	pktdm2			; carry set means error
	cmp	ax,cx			; wrote all?
	jne	pktdm2			; ne = no, error
	push	es
	mov	dx,data1		; seg of pktbuf
	mov	es,dx
	mov	es:pktbp,offset pktbuf
	pop	es
	mov	pktlft,cptsiz		; init buffer ptr & chrs left
	jmp	short pktdm1
pktdm2:	and	flags.capflg,not logpkt	; so please stop capturing
	mov	dx,offset erms24	; tell user the bad news
	mov	ah,prstr
	int	dos
	call	clscp4			; close the packet log
pktdm1:	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
pktdmp	endp

; CLOSE command

clscpt	proc	near
	mov	ah,cmkey		; get kind of file to close
	mov	dx,offset clotab	; close table
	mov	bx,offset clohlp	; help
	call	comnd
       	jc	clscp2			; c = failure
	mov	temp,bx
	mov	ah,cmeol
	call	comnd
       	jc	clscp2			; c = failure
	mov	kstatus,kssuc		; success status thus far
	mov	bx,temp
	cmp	bh,40h			; READ-FILE or WRITE-FILE?
	jne	clscp0			; ne = no
	mov	ax,bx
	jmp	vfclose			; close FILE, pass kind in AX
clscp0:	cmp	bx,logpkt+logses+logtrn	; close all?
	je	clscpi			; e = yes
	cmp	bx,logpkt		; just packet?
	je	clscp4
	cmp	bx,logses		; just session?
	je	clscp6
	cmp	bx,logtrn		; just session?
	jne	clscp1			; ne = no
	jmp	clscp8
clscp1:	mov	dx,offset erms22	; say none active
	mov	ah,prstr
	int	dos
	clc
	ret
clscp2:	mov	kstatus,ksgen		; general cmd failure status
	stc
	ret
					; CLSCPI called at Kermit exit
CLSCPI:	mov	bx,portval
	mov	[bx].flowc,0		; set no flow control so no sending it
	call	pntflsh			; flush PRN buffer
	call	clscp4			; close packet log
	call	clscp6			; close session log
	call	clscp8			; close transaction log
	mov	al,2			; close WRITE FILE log
	call	vfclose
	clc				; return success
	ret

clscp4:	push	bx			; PACKET LOG
	mov	bx,ploghnd		; packet log handle
	or	bx,bx			; is it open?
	jle	clscp5			; e = no
	call	pktdmp			; dump buffer
	mov	ah,close2
	int	dos
	cmp	flags.takflg,0		; ok to echo?
	je	clscp5			; e = no
	mov	ah,prstr
	mov	dx,offset clpktlog	; tell what we are doing
	int	dos
clscp5:	mov	ploghnd,-1		; say handle is invalid
	pop	bx
	and	flags.capflg,not logpkt	; say this log is closed
	ret

clscp6:	push	bx			; SESSION LOG
	mov	bx,sloghnd		; session log handle
	or	bx,bx			; is it open?
	jle	clscp7			; e = no
	call	cptdmp			; dump buffer
	mov	ah,close2
	int	dos
	cmp	flags.takflg,0		; ok to echo?
	je	clscp7			; e = no
	mov	ah,prstr
	mov	dx,offset clseslog	; tell what we are doing
	int	dos
clscp7:	mov	sloghnd,-1		; say handle is invalid
	pop	bx
	and	flags.capflg,not logses	; say this log is closed
	ret

clscp8:	push	bx			; TRANSACTION LOG
	mov	bx,tloghnd		; transaction log handle
	or	bx,bx			; is it open?
	jle	clscp9			; e = no
	mov	ah,close2
	int	dos
	cmp	flags.takflg,0		; ok to echo?
	je	clscp9			; e = no
	mov	ah,prstr
	mov	dx,offset cltrnlog	; tell what we are doing
	int	dos
clscp9:	mov	tloghnd,-1		; say handle is invalid
	pop	bx
	and	flags.capflg,not logtrn	; say this log is closed
	ret
clscpt	endp

; Print on PRN the char in register al. On success return with C bit clear.
; On failure do procedure pntchk and return its C bit (typically C set).
; Uses buffer dumpbuf (screen dump).
pntchr	proc	near
	push	es
	push	ax
	mov	ax,data1		; segment of pntptr and prnbuf
	mov	es,ax
	cmp	es:pntptr,offset prnbuf+cptsiz ; buffer full yet?
	pop	ax
	pop	es
	jb	pntchr1			; b = no
	call	pntflsh			; flush buffer now
	jnc	pntchr1			; nc = success
	ret				; c = fail, discard char
pntchr1:push	es
	push	bx
	mov	bx,data1		; segment of pntptr and prnbuf
	mov	es,bx
	mov	bx,es:pntptr		; pointer to next open slot
	mov	es:[bx],al		; store the character
	inc	bx			; update pointer
	mov	es:pntptr,bx		; save pointer
	pop	bx
	pop	es
	clc				; clear carry bit
	ret
pntchr	endp

; Flush printer buffer. Return carry clear if success.
; On failure do procedure pntchk and return its C bit (typically C set).
; Uses buffer dumpbuf (screen dump).
pntflsh	proc	near
	push	es
	push	ax
	mov	ax,data1		; segment of pntptr and prnbuf
	mov	es,ax
	cmp	es:pntptr,offset prnbuf	; any text in buffer?
	pop	ax
	pop	es
	ja	pntfls1			; a = yes
	clc
	ret				; else nothing to do
pntfls1:cmp	prnhand,0		; is printer handle valid?
	jg	pntfls2			; g = yes
	push	es
	push	ax
	mov	ax,data1		; segment of pntptr and prnbuf
	mov	es,ax
	mov	es:pntptr,offset prnbuf
	pop	ax
	pop	es
	clc				; omit printing, quietly
	ret
pntfls2:push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	es
	mov	ah,flowoff		; get flow control char
	or	ah,ah			; flow control active?
	jz	pntfls3			; z = no, not using xoff
	call	outchr			; output xoff (ah), no echo
pntfls3:mov	bx,prnhand		; file handle for DOS printer PRN
	push	DS			; about to change DS
	mov	dx,data1		; segment of prnbuf
	mov	ds,dx			; set DS
	mov	dx,offset prnbuf	; start of buffer
	mov	cx,ds:pntptr
	sub	cx,dx			; cx = current byte count
pntfls4:push	cx
	push	dx
	mov	cx,1
	mov	ah,write2
	int	dos			; write buffer to printer
	pop	dx
	pop	cx
	jc	pntfls5			; c = call failed
	cmp	ax,1			; did we write it?
	jne	pntfls5			; ne = no, dos critical error
	inc	dx			; point to next char
	loop	pntfls4
	mov	ds:pntptr,offset prnbuf	; reset buffer pointer
	pop	DS			; restore DS
	clc				; declare success
	jmp	pntfls11
pntfls5:mov	si,dx			; address of next char to be printed
	mov	di,offset prnbuf	; start of buffer
	sub	dx,di			; dx now = number successful prints
	mov	cx,ds:pntptr
	sub	cx,si			; count of chars to be printed
	jle	pntfls6
	mov	ax,ds
	mov	es,ax
	cld
	rep	movsb			; copy unwritten to start of buffer
pntfls6:sub	ds:pntptr,dx		; move back printer pointer by ok's
	pop	DS			; restore DS

pntfls7:mov	dx,offset erms26	; printer not ready, get user action
	call	putmod			; write new mode line
	call	beep			; make a noise
	mov	ah,0ch			; clear DOS typeahead buffer
	mov	al,1			; read from DOS buffer
	int	dos
	or	al,al			; Special key?
	jnz	pntfls8			; nz = no, consume
	mov	al,1			; consume scan code
	int	dos
	jmp	short pntfls7		; try again

pntfls8:and	al,not 20h		; lower to upper case quicky
	cmp	al,'R'			; Retry?
	jne	pntfls8a		; ne = no
	call	trnmod			; toggle mode line
	call	trnmod			; back to same state as before
	jmp	pntfls3			; go retry
pntfls8a:cmp	al,'D'			; Discard printing?
	jne	pntfls7			; ne = no, try again
	mov	bx,prnhand
	cmp	bx,4			; stdin/stdout/stderr/stdaux/stdprn?
	jbe	pntfls9			; be = yes, always available
	mov	ah,close2		; close this file
	int	dos
pntfls9:mov	bx,offset prnname	; name of printer file
	mov	word ptr [bx],'UN'	; set to NUL<0>
	mov	word ptr [bx+2],'L'+0
	push	es
	mov	ax,data1		; seg for pntptr
	mov	es,ax
	mov	es:pntptr,offset prnbuf	; reset pointer
	pop	es
	mov	prnhand,-1		; declare handle invalid
ifndef	no_terminal
	mov	anspflg,0		; mszibm/msyibm print status flag off
endif	; no_terminal
pntfls10:call	trnmod			; toggle mode line
	call	trnmod			; back to same state as before
	stc				; declare failure
pntfls11:pushf
	mov	ah,flowon
	or	ah,ah			; flow control active?
	jz	pntfls12		; z = no, not using xon
	call	outchr			; output xon (al), no echo
pntfls12:popf
	pop	es
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret				; nc = success
pntflsh	endp

; Check for PRN (DOS's printer) being ready. If ready, return with C clear
; Otherwise, write Not Ready msg on mode line and return with C bit set.
; N.B. DOS Critical Error will occur here if PRN is not ready.  [jrd]
pntchk	proc	near
	push	dx
	push	cx
	push	ax
	mov	cx,10			; ten retries before declaring error
	cmp	prnhand,0		; printer handle valid?
	jle	pntchk2			; le = no, invalid
pntchk0:push	bx
	mov	bx,prnhand		; file handle
	mov	ah,ioctl		; get printer status, via DOS
	mov	al,7			; status for output
	int	dos
	pop	bx
	jc	pntchk1			; c = call failed
	cmp	al,0ffh			; code for Ready?
	je	pntchk3			; e = yes, assume printer is ready
pntchk1:push	cx			; save counter, just in case
	mov	ax,100			; wait 100 millisec
	call	pcwait
	pop	cx
	loop	pntchk0			; and try a few more times
					; get here when printer is not ready
pntchk2:pop	ax
	pop	cx
	pop	dx
	stc				; say printer not ready
	ret
pntchk3:pop	ax
	pop	cx
	pop	dx
	clc				; say printer is ready
	ret
pntchk	endp


prnopen	proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	mov	prnhand,4		; preset default handle
	mov	dx,offset prnname	; name of disk file, from msssho
	mov	ax,dx			; where isfile wants name ptr
	call	isfile			; what kind of file is this?
	jc	prnop3			; c = no such file, create it
	test	byte ptr filtst.dta+21,1fh ; file attributes, ok to write?
	jnz	prnop2			; nz = no
	mov	al,1			; writing
	mov	ah,open2		; open existing file
	int	dos
	jc	prnop2			; c = failure
	mov	prnhand,ax		; save file handle
	mov	bx,ax			; handle for DOS
	mov	ah,ioctl
	mov	al,0			; get info
	int	dos
	or	dl,20h			; turn on binary mode
	xor	dh,dh
	mov	ah,ioctl
	mov	al,1			; set info
	int	dos
	mov	cx,0ffffh		; setup file pointer
	mov	dx,-1			; and offset
	mov	al,2			; move to eof minus one byte
	mov	ah,lseek		; seek the end
	int	dos
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	clc
	ret
prnop2:	pop	dx
	pop	cx
	pop	bx
	pop	ax
	stc
	ret
prnop3:	test	filtst.fstat,80h	; access problem?
	jnz	prnop2			; nz = yes
	mov	ah,creat2		; file did not exist
	mov	cx,20h			; attributes, archive bit
	int	dos
	mov	prnhand,ax		; save file handle
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret				; may have carry set
prnopen	endp

; worker: copy line from si to di, first removing trailing spaces, second
; parsing out curly braced strings, then third converting \{b##} in strings
; to binary numbers. Returns carry set if error; else carry clear, with byte
; count in cx. Braces are optional but must occur in pairs.
; Items which cannot be converted to legal numbers are copied verbatium
; to the output string (ex: \{c}  is copied as \{c}  but \{x0d} is hex 0dh).
; '\\' is written as '\'
; Requires byte count in CX to handle embedded \0 bytes.
cnvlin	proc	near
	push	ax
	push	si			; source ptr
	push	di			; destination ptr
	push	bp			; end of string marker
	push	temp			; output length counter
	push	es			; end of save regs
	push	ds			; move ds into es
	pop	es			; use data segment for es:di
	mov	temp,di			; initial output position
	call	cnvstr			; parse curly braces
	xor	dx,dx			; initialize returned byte count
	cld
	mov	bp,si
	add	bp,cx			; point to last byte + 1 of string
cnvln1:	cmp	si,bp			; at end of string?
	jae	cnvlnx			; ae = yes, exit
	mov	al,[si]			; look at starting byte
	cmp	al,'\'			; numeric intro?
	jne	cnvln3			; ne = no
	mov	atoi_cnt,cx		; length for atoi
	mov	atoibyte,1		; convert only one character
	call	atoi			; deal with \numbers
	jnc	cnvln4			; nc = success, converted number
cnvln3:	lodsb				; reread from string literally
	xor	ah,ah			; only one byte of output
cnvln4:	cld
	stosb				; save the char
	or	ah,ah			; is returned number > 255?
	jz	cnvln1			; z = no, do more chars
cnvln5:	stosb				; save high order byte next
	jmp	short cnvln1		; do more chars
cnvlnx:	mov	byte ptr [di],0		; plant terminator
	clc				; clear c bit, success
	sub	di,temp			; current - inital output position
	mov	cx,di			; returned byte count to CX
	pop	es			; restore regs
	pop	temp
	pop	bp
	pop	di			; destination ptr
	pop	si			; source ptr
	pop	ax
	ret
cnvlin	endp

; Convert string by removing surrounding curly brace delimiter pair. 
; Converts text in place.
; Enter with source ptr in si.
; Preserves all registers, uses byte tmp. 9 Oct 1987 [jrd]
; 
cnvstr	proc	near
	push	ax
	push	bx
	push	dx
	push	si			; save start of source string
	push	di
	push	es
	xor	bx,bx 			; output count, assume none
	mov	dx,si			; source address
	jcxz	cnvst4			; z = nothing there
	push	ds
	pop	es			; set es to data segment
	cld
	mov	di,si			; set destination address to source
					; 2. Parse off curly brace delimiters
	mov	bx,cx			; assume no changes to byte count
	cmp	byte ptr [si],braceop	; opening brace?
	jne	cnvst4			; ne = no, ignore brace-matching code
	xor	bx,bx			; count up output bytes
	inc	si			; skip opening brace
	mov	dl,braceop		; opening brace (we count them up)
	mov	dh,bracecl		; closing brace (we count them down)
	mov	tmp,1			; we are at brace level 1
cnvst1:	cld				; search forward
	lodsb				; read a string char
	stosb				; store char (skips opening brace)
	dec	cx
	inc	bx			; count bytes read and written
	or	cx,cx			; at end of string?
	jle	cnvst4			; le = yes, we are done
	cmp	al,dl			; an opening brace?
	jne	cnvst2			; ne = no
	inc	tmp			; yes, increment brace level
	jmp	short cnvst1		;  and continue scanning

cnvst2:	cmp	al,dh			; closing brace?
	jne	cnvst1			; ne = no, continue scanning
	dec	tmp			; yes, decrement brace level
	or	cx,cx			; have we just read the last char?
	jnz	cnvst3			; nz = no, continue scanning
	mov	tmp,0			; yes, this is the closing brace
cnvst3:	cmp	tmp,0			; at level 0?
	jne	cnvst1			; ne = no, #opening > #closing braces
	dec	bx			; don't count terminating brace
	mov	byte ptr [di-1],0	; plant terminator on closing brace

cnvst4:	pop	es			; recover original registers
	pop	di
	pop	si
	pop	dx
	mov	cx,bx			; return count in cx
	pop	bx
	pop	ax
	ret
cnvstr	endp

; OPEN { READ | WRITE | APPEND } filespec
vfopen	proc	near
	mov	ah,cmkey		; get READ/WRITE/APPEND keyword
	mov	dx,offset opntab	; keyword table
	xor	bx,bx			; help
	call	comnd
	jc	vfopen1			; c = failed
	mov	temp,bx
	mov	ah,cmword		; read filespec
	mov	bx,offset rdbuf		; buffer for filename
	mov	dx,offset vfophlp	; help
	call	comnd
	jc	vfopen1			; c = failed
	mov	ah,cmeol		; get end of line confirmation
	call	comnd
	jnc	vfopen2
	mov	kstatus,ksgen		; general cmd failure status
vfopen1:ret				; error return, carry set

vfopen2:mov	kstatus,kssuc		; assume success status
	mov	dx,offset rdbuf		; filename, asiiz
	mov	bx,temp			; kind of open
	cmp	bx,1			; open for reading?
	jne	vfopen4			; ne = no
					; OPEN READ
	cmp	vfrhandle,0		; is it open now?
	jge	vfopen8			; ge = yes, complain
	mov	ah,open2		; file open
	xor	al,al			; 0 = open readonly
	cmp	dosnum,300h		; at or above DOS 3?
	jb	vfopen3			; b = no, so no shared access
	or	al,40h			; open readonly, deny none
vfopen3:int	dos
	jc	vfopen9			; c = failed to open the file
	mov	vfrhandle,ax		; save file handle
	clc
	ret
					; OPEN WRITE or APPEND
vfopen4:cmp	vfwhandle,0		; is it open now?
	jge	vfopen8			; ge = yes, complain
	mov	ax,dx			; filename for isfile
	call	isfile		; check for read-only/system/vol-label/dir
	jc	vfopen7			; c = file does not exist
	test	byte ptr filtst.dta+21,1fh	; the no-no file attributes
	jnz	vfopen9			; nz = do not write over one of these
vfopen5:test	filtst.fstat,80h	; access problem?
	jnz	vfopen9			; nz = yes, quit here
	test	byte ptr filtst.dta+21,1bh	; r/o, hidden, volume label?
	jnz	vfopen9			; we won't touch these
	mov	ah,open2	       ; open existing file (usually a device)
	mov	al,1+1			; open for writing
	int	dos
	jc	vfopen9			; carry set means can't open
	mov	vfwhandle,ax		; remember file handle
	mov	bx,ax			; file handle for lseek
	xor	cx,cx
	xor	dx,dx			; cx:dx = displacment
	xor	al,al			; 0 means from start of file
	cmp	temp,2			; WRITE? means from start of file
	je	vfopen6			; e = yes, else APPEND
	mov	al,2			; move to eof
vfopen6:mov	ah,lseek		; seek the place
	int	dos
	clc
	ret

vfopen7:cmp	temp,1			; READ?
	je	vfopen9			; e = yes, should not be here
	mov	ah,creat2		; create file
	xor	cx,cx			; 0 = attributes bits
	int	dos
	jc	vfopen9			; c = failed
	mov	vfwhandle,ax		; save file handle
	clc				; carry clear for success
	ret

vfopen8:mov	dx,offset vfoptwice	; trying to reopen a file
	mov	ah,prstr
	int	dos
	mov	kstatus,kstake		; Take file failure status
	stc
	ret
vfopen9:mov	dx,offset vfopbad	; can't open, complain
	mov	ah,prstr
	int	dos
	mov	dx,offset rdbuf		; filename
	call	prtasz
	mov	kstatus,kstake		; Take file failure status
	stc
	ret
vfopen	endp

; CLOSE {READ-FILE | WRITE-FILE}
vfclose	proc	near
	mov	tmp,al			; remember kind (1=READ, 2=WRITE)
	mov	bx,vfrhandle		; READ FILE handle
	cmp	al,1			; READ-FILE?
	je	vfclos1			; e = yes
	cmp	al,2			; WRITE-FILE?
	jne	vfclos3			; ne = no, a mistake
	mov	bx,vfwhandle		; write handle
	or	bx,bx
	jl	vfclos3			; l = invalid handle
	mov	dx,offset rdbuf
	xor	cx,cx			; zero length
	push	bx			; save handle
	mov	ah,write2		; set file high water mark
	int	dos
	pop	bx
vfclos1:or	bx,bx
	jl	vfclos3			; l = invalid handle
	mov	kstatus,kssuc		; success status thus far
	mov	ah,close2		; close file
	int	dos
	jc	vfclos4			; c = error
	cmp	tmp,1			; READ?
	jne	vfclos2			; ne = no, WRITE
	mov	vfrhandle,-1		; declare READ handle to be invalid
	clc
	ret
vfclos2:mov	vfwhandle,-1		; declare WRITE handle to be invalid
	clc
	ret
vfclos4:mov	ah,prstr
	mov	dx,offset vfclbad	; complain
	int	dos
vfclos3:mov	kstatus,ksgen		; general cmd failure status
	stc
	ret
vfclose	endp

; READ-FILE variable name
vfread	proc	near
	mov	comand.cmper,1		; do not react to '\%' in macro name
	mov	comand.cmarray,1	; allow sub in [..] of \&<char> arrays
	mov	ah,cmword
	mov	bx,offset rdbuf+2	; buffer for macro name
	mov	word ptr rdbuf,0
	mov	dx,offset vfrdmsg
	call	comnd			; get macro name
	jnc	vfread1			; nc = success
	mov	kstatus,ksgen		; general cmd failure status
	ret				; failure
vfread1:or	ax,ax			; null entry?
	jnz	vfread2			; nz = no
	mov	dx,offset vfrdbad	; more parameters needed
	mov	ah,prstr
	int	dos
	mov	kstatus,ksgen		; general cmd failure status
	stc
	ret

vfread2:push	ax
	mov	ah,cmeol		; get command confirmation
	call	comnd
	pop	ax			; ax is variable length
	jc	vfreadx			; c = failed
	mov	cx,cmdblen		; length of rdbuf
	sub	cx,ax			; minus macro name
	dec	cx			; minus space separator
	mov	temp,0			; leading whitespace and comment flgs
	mov	di,offset rdbuf+2	; destination buffer
	add	di,ax			; plus variable name
	mov	byte ptr [di],' '	; space separator
	inc	di			; put definition here
	mov	bx,vfrhandle		; READ FILE handle
	or	bx,bx			; check for valid handle
	jge	vfread3			; ge = valid
	mov	ah,prstr
	mov	dx,offset vfnofile	; say no file
	int	dos
vfreadx:mov	kstatus,ksgen		; general cmd failure status
	stc				; failure return
	ret
vfread3:push	cx			; read from file
	mov	kstatus,kssuc		; assume success status
	mov	cx,1			; read 1 char
	mov	dx,di			; place here
	mov	byte ptr [di],0		; insert terminator
	mov	ah,readf2
	int	dos
	pop	cx
	jc	vfreadx			; c = read failure
	or	ax,ax			; count of bytes read
	jz	vfread9			; z means end of file
	mov	al,[di]			; get the character
	cmp	flags.takflg,0		; echo Take files?
	je	vfread3a		; e = no
	push	ax
	mov	ah,conout
	mov	dl,al			; echo character
	int	dos
	pop	ax
vfread3a:cmp	al,CR			; CR?
	je	vfread7			; e = yes, ignore it
	cmp	al,LF			; LF?
	je	vfread8			; e = yes, exit
	cmp	byte ptr temp,0		; seen non-spacing char yet?
	jne	vfread6			; ne = yes
	cmp	al,' '			; is this a space?
	je	vfread7			; e = yes, skip it
	cmp	al,TAB			; or a tab?
	je	vfread7			; e = yes, skip it
	mov	byte ptr temp,1		; say have seen non-spacing char

vfread6:inc	di			; next storage cell
vfread7:loop	vfread3			; loop til end of line

vfread8:cmp	byte ptr [di-1],'-'	; last printable is line-continuation?
	jne	vfread10		; ne = no, use this line as-is
	dec	di			; point to hyphen
	mov	cx,offset rdbuf+cmdblen	; end of rdbuf
	sub	cx,di			; minus where we are now
	jle	vfread10		; le = no space remaining
	mov	temp,0			; leading whitespace and comment flgs
	jmp	vfread3			; read another line

vfread9:mov	kstatus,ksgen		; EOF, general command failure status

vfread10:cmp	flags.takflg,0		; echo Take files?
	je	vfread11		; e = no
	mov	ah,prstr
	mov	dx,offset crlf		; for last displayed line
	int	dos

vfread11:mov	byte ptr [di],0		; insert final terminator
	mov	dx,offset rdbuf+2	; start counting from here
	push	kstatus			; preserve status from above work
	call	strlen			; cx becomes length
	call	dodecom			; create the variable
	pop	kstatus			; recover reading status
	jc	vfread12		; c = failure
	ret
vfread12:mov	kstatus,ksgen		; general command failure status
	mov	ah,prstr
	mov	dx,offset vfrbad	; say error while reading
	int	dos
	stc
	ret
vfread	endp

; WRITELN {FILE or log} text   (adds trailing CR/LF)
writeln	proc	near
	mov	tmp,1			; flag for trailing CR/LF
	jmp	short write0		; common code
writeln	endp

; WRITE {FILE or log} text
Write	proc	near
	mov	tmp,0			; flag for no trailing CR/LF
write0:	mov	ah,cmkey		; get kind of log file
	mov	dx,offset writetab	; table of possibilities
	xor	bx,bx			; help, when we get there
	call	comnd
	jnc	write1			; nc = success
	mov	kstatus,ksgen		; general cmd failure status
	ret
write1:	mov	temp,bx			; save log file kind
	mov	comand.cmdonum,1	; \number conversion allowed
	mov	comand.cmblen,cmdblen	; use full length
	mov	ah,cmline		; get string to be written
	mov	bx,offset rdbuf		; where to put text
	mov	dx,offset msgtxt	; help
	call	comnd
	jnc	wpkt0
	mov	kstatus,ksgen		; general cmd failure status
	ret				; c = failure
wpkt0:	mov	kstatus,kssuc		; success status thus far
	mov	si,offset rdbuf		; start of text in buffer
	cmp	tmp,0			; add trailing CR/LF?
	je	wpkt0a			; e = no
	mov	bx,ax			; current length
	mov	word ptr rdbuf[bx],LF*256+CR ; add CR LF
	mov	word ptr rdbuf[bx+2],0	; and terminator
	add	ax,2
wpkt0a:	mov	bx,temp			; log file kind
	mov	cx,ax			; length 
	jcxz	wpkt2			; z = no chars to write
	cmp	bx,logpkt		; Packet log?
	jne	wses1			; ne = no
wpkt1:	lodsb				; get byte to al
	call	pktcpt			; write to packet log
	loop	wpkt1
wpkt2: 	clc				; say success
	ret

wses1:	cmp	bx,logses		; Session log?
	jne	wtrn1			; ne = no
wses2:	lodsb				; get byte to al
	call	cptchr			; write to log
	loop	wses2			; do cx chars
	clc				; say success
	ret

wtrn1:	cmp	bx,logtrn		; Transaction log?
	jne	wtrn2			; ne = no
	mov	bx,tloghnd		; file handle
	jmp	short wtrn4

wtrn2:	cmp	bx,80h			; WRITE SCREEN?
	jne	wtrn3			; ne = no
	xor	bx,bx			; handle is stdout
	jmp	short wtrn4

wtrn3:	cmp	bx,4002h		; WRITE FILE?
	jne	wtrn5			; ne = no, forget this
	mov	bx,vfwhandle		; handle

wtrn4:	or	bx,bx			; is handle valid?
	jl	wtrn5			; l = no
	mov	dx,offset rdbuf
	mov	ah,write2		; write to file handle in bx
	int	dos
	jc	wtrn4a			; c = failure
	clc
	ret
wtrn4a:	mov	ah,prstr
	mov	dx,offset vfwbad	; say error while writing
	int	dos
	mov	kstatus,ksgen
	stc
	ret
wtrn5:	mov	kstatus,ksgen		; general cmd failure status
	mov	ah,prstr
	mov	dx,offset vfnofile	; say no file
	int	dos
	stc
	ret
write	endp
code	ends

code1	segment
	assume	cs:code1

; Convert ascii strings of the form "\{bnnn}" to a binary dword in dx:ax.
; The braces are optional but must occur in pairs. Numeric base indicator "b"
; is O or o or X or x or D or d or missing, for octal, hex, or decimal (def).
; Enter with si pointing at "\".
; Returns binary value in ax with carry clear and si to right of "}" or at
; terminating non-numeric char if successful; otherwise, a failure,
; return carry set with si = entry value and first read char in al.
; Public byte  atoibyte  is used to control conversion of one character, if
;  non-zero, or as many as can be parsed if zero. This routine always clears
;  atoibyte upon exiting.
; atoi_err byte values, carry bit state, meaning
; 0 nc	successfully converted, can accept more data
; 1 nc	successfully converted and string is terminated
; 2 nc	successfully converted with break char pointed to by SI
; 4 c	insufficient bytes to resolve
; 8 c	syntax error in expression, cannot convert
atoi	proc	far
	push	temp
	push	temp1
	push	cx			; save working reg
	push	si			; save entry si
	push	bx
	push	ax			; save read char
	xor	ax,ax
	mov	temp,ax
	mov	temp1,ax
	mov	atoi_err,al		; assume success and can read more
	xor	bx,bx			; assume no opening brace
	cld
	mov	cx,atoi_cnt		; bytes available to examine
	or	cx,cx
	jnz	atoi1
	mov	atoi_cnt,16		; safety
atoi1:	call	atoi_read		; read a byte or fail
	jnc	atoi1a
	jmp	atoix			; fail

atoi1a:	cmp	al,' '			; leading space?
	je	atoi1			; e = yes, read again, for do_math
	cmp	al,'\'			; number introducer?
	jne	atoi1b			; ne = no
	call	atoi_read		; get next byte
	jnc	atoi1b
	jmp	atoix

atoi1b:	cmp	al,braceop		; opening brace?
	jne	atoi1c			; ne = no
	mov	bl,bracecl		; remember a closing brace is needed
	call	atoi_read		; get next byte
	jnc	atoi1c
	jmp	atoix

atoi1c:	call	isnumbase		; number base introducer?
	jc	atoi1d			; c = no
	call	atoi_read		; get next byte
	jnc	atoi2			; nc = got a byte
	jmp	atoix
atoi1d:	mov	nbase,10		; assume base 10
	mov	cx,3			; and three digits per char

atoi2:	call	cnvdig			; do we have a digit now?
	jnc	atoi2a			; nc = yes
	mov	atoi_err,8		; syntax error, digit required
	jmp	atoix
atoi2a:	dec	si			; back over it for read below
	inc	atoi_cnt
	mov	ax,cx			; number base byte count
	mov	cx,atoi_cnt		; available bytes
	cmp	atoibyte,0		; read as many bytes as possible?
	je	atoi3			; e = yes
	cmp	ax,cx			; number base wants more than we have?
	ja	atoi3			; a = yes, use available bytes
	mov	cx,ax			; limit loop to num base requirements
	mov	atoi_err,1		; presume successful and terminated

atoi3:	call	atoi_read		; get a byte
	jc	atoix			; c = failed
	call	cnvdig			; convert ascii to binary digit
	jc	atoi4			; c = cannot convert, SI-1 is break
	xor	ah,ah			; clear high order value
	cmp	atoibyte,0		; read as many bytes as possible?
	je	atoi3b			; e = yes
	push	ax			; test for fitting into byte result
	mov	ax,temp			; current low order value
	mul	nbase			; times number base
	add	dx,ax			; to dx, plus any overflow
	pop	ax
	add	dx,ax			; next result would be in dx
	or	dh,dh			; overflow beyond one byte
	jnz	atoi4			; nz = cannot accept this byte
	cmp	cx,1			; reading last byte?
	ja	atoi3b			; a = no
	
atoi3b:	inc	bh			; say we did a successful conversion
	push	ax			; save this byte's value
	mov	ax,temp1
	mul	nbase			; high order
	mov	temp1,ax		; keep low order part of product
	mov	ax,temp
	mul	nbase			; low order
	add	temp1,dx		; high order carry
	mov	temp,ax			; low order
	pop	ax			; recover binary digit
	add	temp,ax
	adc	temp1,0
	loop	atoi3			; get more
	jmp	short atoi4a		; out of data, don't backup
					; here on break char in al

atoi4:	dec	si			; backup to reread terminator
	inc	atoi_cnt
	mov	atoi_err,2		; terminated on break char
atoi4a:	or	bl,bl			; closing brace needed?
	jz	atoi6			; z = no, success so far
atoi5:	call	atoi_read		; get a byte for brace
	jnc	atoi5a
	cmp	atoi_cnt,0		; out of counts?
	je	atoix			; e = yes
atoi5a:	cmp	al,bl			; the closing brace?
	jne	atoi5b			; ne = no
	mov	atoi_err,1		; success, terminator seen (brace)
	jmp	atoi6
atoi5b:	cmp	al,' '			; space padding?
	je	atoi5			; e = yes, skip it
atoi5c:	mov	atoi_err,8		; syntax error (failed to get brace)
	jmp	atoix

atoi6:	or	bh,bh			; did we do any conversion?
	jz	atoix			; z = no
	pop	ax			; throw away old saved ax
	pop	bx			; restore bx
	pop	ax			; throw away starting si, keep current
	pop	cx			; restore old cx
	mov	dx,temp1
	mov	ax,temp
	pop	temp1
	pop	temp
	mov	atoibyte,0
	mov	atoi_cnt,0
	clc				; clear carry for success
	ret
atoix:	pop	ax			; restore first read al
	pop	bx
	pop	si			; restore start value
	pop	cx			; restore old cx
	pop	temp1
	pop	temp
	xor	dx,dx
	mov	atoibyte,0
	mov	atoi_cnt,0
	stc				; set carry for failure
	ret
atoi	endp

; Examine char in AL for being a number base indicator, O, X, D, in
; either case.
; If matched return carry clear, number base nbase set, and cx holding
; the qty of bytes in a single character result value.
; If not matched return carry set.
; AL is preserved.
isnumbase proc	near
	push	ax			; try for number bases
	cmp	al,'a'			; lower case?
	jb	isnum1			; b = no
	cmp	al,'z'			; in range of lower case?
	ja	isnum1			; a = no
	and	al,5fh			; map to upper case
isnum1:	cmp	al,'O'			; octal?
	jne	isnum2			; ne = no
	mov	nbase,8			; set number base
	cmp	atoibyte,0		; all bytes?
	je	isnum4			; e = yes
	mov	cx,3			; three octal chars per final char
	jmp	short isnum4
isnum2:	cmp	al,'X'			; hex?
	jne	isnum3			; ne = no
	mov	nbase,16
	cmp	atoibyte,0		; all bytes?
	je	isnum4			; e = yes
	mov	cx,2			; two hex chars per final char
	jmp	short isnum4
isnum3:	cmp	al,'D'			; decimal?
	jne	isnum5			; ne = no, syntax error
	mov	nbase,10
	cmp	atoibyte,0		; all bytes?
	je	isnum4			; e = yes
	mov	cx,3
isnum4:	pop	ax			; successful result
	clc
	ret
isnum5:	pop	ax
	stc				; carry set for failure
	ret
isnumbase endp

; Read a byte from ds:si.
; If success decrement byte atoi_cnt, inc si, return byte in AL, carry clear.
; If failure return carry set, no change to atoi_cnt, AL unchanged.
atoi_read proc	near
	cmp	atoi_cnt,0		; any bytes left?
	jg	atoi_read1		; g = yes
	mov	atoi_err,4		; c = insufficient bytes to resolve
	stc				; return failure
	ret
atoi_read1:
	cld
	lodsb				; get first char
	dec	atoi_cnt		; one less byte availble
	clc
	ret
atoi_read endp

					; worker for atoi
cnvdig	proc	near			; convert ascii code in al to binary
	push	ax			; return carry set if cannot
	cmp	al,'a'			; lower case hexadecimal candidate?
	jb	cnvdig1			; b = no
	sub	al,20h			; lower case hex to upper
cnvdig1:cmp	al,'A'			; uppercase hex
	jb	cnvdig2
	sub	al,'A'-10-'0'		; 'A' becomes '10'
cnvdig2:sub	al,'0'			; remove ASCII bias
	jc	cnvdigx			; c = out of range
	cmp	al,byte ptr nbase	; out of range?
	jae	cnvdigx			; ae = yes, out of range
	add	sp,2			; pop saved ax
	clc				; success, binary value is in al
	ret
cnvdigx:pop	ax			; return ax unchanged
	stc				; c set for failure
	ret
cnvdig	endp	

decout	proc	far		; display decimal number in ax
	push	ax
	push	cx
	push	dx
	mov	cx,10		; set the numeric base
	call	mvalout		; convert and output value
	pop	dx
	pop	cx
	pop	ax
	ret
decout	endp

mvalout	proc	near		; output number in ax using base in cx
				; corrupts ax and dx
	xor	dx,dx		; clear high word of numerator
	div	cx		; (ax / cx), remainder = dx, quotient = ax
	push	dx		; save remainder for outputting later
	or	ax,ax		; any quotient left?
	jz	mvalout1	; z = no
	call	mvalout		; yes, recurse
mvalout1:pop	dx		; get remainder
	add	dl,'0'		; make digit printable
	cmp	dl,'9'		; above 9?
	jbe	mvalout2	; be = no
	add	dl,'A'-1-'9'	; use 'A'--'F' for values above 9
mvalout2:mov	ah,conout
	int	dos
	ret
mvalout	endp


valout	proc	far		; output number in ax using base in cx
				; corrupts ax and dx
	xor	dx,dx		; clear high word of numerator
	div	cx		; (ax / cx), remainder = dx, quotient = ax
	push	dx		; save remainder for outputting later
	or	ax,ax		; any quotient left?
	jz	valout1		; z = no
	call	valout		; yes, recurse
valout1:pop	dx		; get remainder
	add	dl,'0'		; make digit printable
	cmp	dl,'9'		; above 9?
	jbe	valout2		; be = no
	add	dl,'A'-1-'9'	; use 'A'--'F' for values above 9
valout2:mov	ah,conout
	int	dos
	ret
valout	endp

; Write binary number in AX as decimal asciiz to buffer pointer DS:DI.
dec2di	proc	far		; output number in ax using base in cx
	push	ax
	push	cx
	push	dx
	mov	cx,10
	call	dec2di1		; recursive worker
	pop	dx
	pop	cx
	pop	ax
	ret

dec2di1	proc	near		; worker of dec2di
	xor	dx,dx		; clear high word of numerator
	div	cx		; (ax / cx), remainder = dx, quotient = ax
	push	dx		; save remainder for outputting later
	or	ax,ax		; any quotient left?
	jz	dec2di2		; z = no
	call	dec2di1		; yes, recurse
dec2di2:pop	dx		; get remainder
	add	dl,'0'		; make digit printable
	mov	[di],dl		; store char in buffer
	inc	di
	mov	byte ptr[di],0	; add terminator
	ret
dec2di1	endp
dec2di	endp

; Perform math. Reads argptr string, returns binary value in DX:AX.
; Expects pointer to string to be in domath_ptr and its length in domath_cnt.
; Note that value and operator lists are stored on the stack in positive
; order (increasing array values are at increasing addresses, not in push
; order).
; Returns carry set if error.
domath	proc	far
	push	bx
	push	cx
	push	si
	push	di
	mov	si,domath_ptr
	mov	di,domath_cnt
	mov	parendepth,0		; parenthesis nesting depth
	call	domath_main
	mov	domath_msg,0		; re-enable domath error messages
	jnc	domathx1
	mov	domath_ptr,si
	mov	domath_cnt,di
domathx1:	
	pop	di
	pop	si
	pop	cx
	pop	bx
	ret
domath	endp

domath_main proc near
	push	si
	push	bp
	sub	sp,size fevalst		; counters and lists
	mov	bp,sp			; remember base of lists
	mov	[bp].numcnt,0		; no numbers in list
	mov	[bp].opcnt,0		; no operators in list
	mov	[bp].numlist,0		; returned value
	mov	[bp].numlist[2],0	; high order returned value
	inc	parendepth		; recursion limit counter
	cmp	parendepth,maxdepth	; called too many times?
	jbe	domath0			; be = no
	mov	matherr,offset opmsg4
	jmp	domath_error		; a = too many parentheses

domath0:call	gettoken		; read a token from string
	jc	domath_exit		; c = nothing present
	cmp	bl,'O'			; operator?
	je	domath1			; e = yes
	cmp	[bp].numcnt,2		; have two numbers (num num)?
	jb	domath0			; b = no, get an operator
	mov	matherr,offset opmsg1	; missing operator
	jmp	domath_error		; exit with grammar error

	; have initial operator in AX, decide in/pre/post-fix style
domath1:cmp	al,'!'			; postfix? (number is on stack)
	jne	domath2			; ne = no
	call	domath_calc1		; do math on one arg, result on stack
	jc	domath_error		; failure, exit
	jmp	short domath0		; done here, get next tokens

					; prefix or infix?
domath2:call	gettoken		; get expected following number
	jc	domath_error		; c = eof, unexpected, error
	cmp	bl,'N'			; got the number?
	jne	domath4			; ne = no, operator
domath3:call	domath_la		; call lookahead proc
	; c clear, bl = N for use current number on stack
	; c clear, bl = O for have higher prec operator on stack & ax, delay
	; c clear, bl = F for read end of file, no next operator
	; c set,   bl = F for math failure, best to exit
	jc	domath_error		; failure on math
	cmp	bl,'F'			; end of file?
	je	domath_end		; e = eof, do remaining math
	cmp	bl,'O'			; found higher prec op (delay)?
	je	domath1			; e = yes, do newest operator
	call	domath_calc2		; bl = 'N', number ready, do math
	jc	domath_error		; c = failure
	cmp	[bp].opcnt,0		; any ops backlogged?
	jne	short domath3		; be = try again to reduce back math
	jmp	domath0			; start over

			; Have op op. Is second op a prefix operator?
domath4:cmp	al,'~'			; prefix?
	je	domath5			; e = yes
	cmp	al,'-'			; prefix, overload?
	je	domath5			; e = yes
	cmp	al,'+'			; prefix, overload?
	jne	domath_error		; ne = no, inconsistent syntax
		; could be  op number postfix  so look at next token to see
		; and if so reduce <number postfix> before applying prefix.
domath5:call	gettoken		; get expected number following prefix
	jc	domath_end		; c = eof, do remaining math
	cmp	bl,'O'			; operator?
	je	domath_error		; e = yes, that makes op op op
	call	domath_la		; do lookahead for postfix
	jc	domath_error		; c = failure on math
	call	domath_calc1		; do prefix calculation now
	jc	domath_error		; c = failure
	call	popop			; get first operator to ax
	call	pushop			; put it back as if just read
	mov	bl,'O'			; mark as operator
	jmp	short domath3		; reanalyze from new operator

					; end of data, finish up math & exit
domath_end:				; do calcs remaining on stack
	cmp	[bp].opcnt,0		; operators remaining to be done?
	je	domath_exit		; e = no
	call	domath_calc2		; finish math
	jc	domath_error		; c = failure
	jmp	short domath_end	; keep trying til no more operators

domath_error:				; math errors seen, exit in error
	mov	cx,1			; set carry for error
	jmp	short domath_exit1

domath_exit:				; only way out, restore stack
	xor	cx,cx			; assume success, cx = error counter
domath_exit1:
	dec	parendepth		; nesting depth
	cmp	[bp].numcnt,1		; only one value remaning?
	je	domath_exit2		; e = yes, that's good
	jb	domath_exit2a		; b = no numbers, empty arg
	jcxz	domath_exit2		; z = no error

	cmp	domath_msg,0		; msgs permitted?
	jnz	domath_exit2a		; nz = no
	mov	matherr,offset opmsg1	; missing operator
domath_exit2a:
	inc	cx			; say error
domath_exit2:
	cmp	[bp].opcnt,0		; used all operators?
	je	domath_exit3		; e = yes
	mov	matherr,offset opmsg	; too many operators
	inc	cx			; say error

domath_exit3:				; all returns
	mov	ax,[bp].numlist		; returned value
	mov	dx,[bp].numlist[2]	; high order part
	mov	sp,bp			; base of lists
	add	sp,size fevalst		; counters and lists
	or	cx,cx			; any errors?
	jz	domath_exit4		; z = no (clears carry bit)
	cmp	domath_msg,0		; ok to complain?
	jne	domath_exit3a		; ne = no, keep quiet
	mov	ah,prstr
	mov	dx,matherr		; math error pointer
	or	dx,dx			; if any
	jz	domath_exit3a		; z = none
	push	dx
	mov	dx,offset crlf
	int	dos
	pop	dx
	int	dos			; display error message
domath_exit3a:
	xor	ax,ax			; return zero on errors
	xor	dx,dx
	stc				; set carry for fail
domath_exit4:
	mov	matherr,0
	pop	bp
	pop	si
	ret				; all done. Result in DX:AX
domath_main endp

; Worker for domath. Reads argptr, inc's it, dec's arglen. Recognizes
; numbers (with or without leading \), recognizes math operators and ().
; Returns numbers as binary in DX:AX and BL = 'N',
; returns operator and precedence in AL and AH with BL = 'O'. 
; Returns Carry set and BL = 'F' if neither kind of token.
; Tolerates leading whitespace.
; Uses domath_ptr as source pointer, domath_cnt as source count.
; Array domath_tmp is owned by this routine as private space.
gettoken proc	near
	xor	ax,ax			; no operator, lowest precedence
	xor	dx,dx

gettok0:cmp	domath_cnt,0		; anything to read?
	jg	gettok1			; g = yes
	mov	bl,'F'			; F for end of file, failure
	stc
	ret

gettok1:mov	si,domath_ptr
	mov	al,byte ptr [si]
	cmp	al,' '			; leading whitepace?
	jne	gettok1a		; ne = no
	inc	domath_ptr
	dec	domath_cnt
	jmp	short gettok0

gettok1a:jb	gettok1b		; b = non-printable
	cmp	al,127
	jb	gettok2			; b = printable
gettok1b:mov	bl,'F'			; declare F for end of file, failure
	mov	domath_cnt,0		; truncate string
	clc
	ret

gettok2:mov	cx,domath_cnt
	mov	atoi_cnt,cx
	call	atoi			; convert DS:SI to number in DX:AX
	jc	gettok5			; c = failed to convert number
	mov	cx,si
	sub	cx,domath_ptr		; amount read
	sub	domath_cnt,cx		; deduct that read
	mov	domath_ptr,si		; break char
	call	pushval			; push onto number stack
	mov	bl,'N'			; say returning number
	ret				; may have carry bit set

gettok5:mov	si,domath_ptr
	lodsb				; reread non-numeric
	inc	domath_ptr
	dec	domath_cnt
	push	di			; look for operators
	push	es
	mov	di,seg operators	; list of math operators
	mov	es,di
	mov	di,offset operators
	mov	cx,operator_len		; length of list
	cld
	repne	scasb			; look for match
	pop	es
	je	gettok6			; e = found a match
	pop	di
	cmp	domath_msg,0		; allowed to display messages?
	jne	gettok5a		; ne = no
	push	ax
	mov	ah,prstr
	mov	dx,offset crlf
	int	dos
	mov	dx,offset opmsg2	; unknown symbol
	int	dos
	pop	ax
	mov	dl,al			; unknown op
	mov	ah,conout
	int	dos
	mov	ah,prstr
	mov	dx,offset crlf
	int	dos
gettok5a:
	dec	domath_ptr		; set to read on this symbol
	inc	domath_cnt
	mov	bl,'F'			; say returning parse failure
	stc				; fail
	ret
gettok6:sub	di,offset operators + 1	; index into list
	mov	ah,precedence[di]	; precedence to return
	pop	di
	mov	bl,'O'			; say returning operator
	cmp	al,'('			; start recursion?
	je	gettok7
	cmp	al,')'			; closure?
	je	gettok9			; e = yes, it's an EOF here
	call	pushop			; push operator on op stack
	clc
	ret

gettok7:call	domath_main		; '(', invoke new scan
	jnc	gettok8			; nc = succeeded
	ret				; c = return failure
gettok8:call	pushval			; push returned DX:AX
	mov	bl,'N'			; report number
	ret				; may have carry bit set

gettok9:mov	bl,'O'
	stc				; ')' returns EOF
	ret
gettoken endp

; Lookahead processor. Have ...<op><number> on stack
; Return bl = N for return number present on stack, carry clear
; Return bl = O for return higher prec operator on stack, carry clear
; Return bl = F and carry clear for end of file
; Return bl = F and carry set for math failure (errors)

domath_la proc near
	call	gettoken		; expect operator or end of file
	jnc	domath_la1		; nc = success
	mov	bl,'F'			; say eof
	clc				; carry clear for eof
	ret

domath_la1:
	cmp	bl,'O'			; lookahead operator?
	je	domath_la2		; e = yes
	mov	bl,'F'			; fail, case of number number
	stc				; syntax error, signal quit
	ret

domath_la2:
	mov	si,[bp].opcnt		; get size of op list
	dec	si			; zero based index
	or	si,si			; sanity check, should be > 0
	jnz	domath_la2a		; nz = have current op available
	mov	bl,'F'			; signal total failure
	stc
	ret
domath_la2a:
	shl	si,1			; index words
	mov	ax,[bp].oplist[si]	; lookahead operator
	mov	cx,[bp].oplist[si-2]	; currently active operator
	cmp	ah,ch			; lookahead versus current op
	ja	domath_la3		; a = lookahead is higher, delay
	call	popop			; remove lookahead operator from stack
	dec	domath_ptr		; set to reread operator
	inc	domath_cnt
	mov	bl,'N'			; signal number ready on stack
	clc
	ret

domath_la3:				; delay
	cmp	al,'!'			; postfix on number?
	jne	domath_la5		; ne = no, another operator, delay
	call	domath_calc1		; combine number!, report number
	jnc	domath_la4		; nc = success, use number on stack
	mov	bl,'F'			; report failed
	ret				; carry set

domath_la4:mov	bl,'N'			; report number is on stack
	clc				; say success
	ret

domath_la5:mov	bl,'O'		; lookahead (delayed op) is on stack and ax
	clc			; bl = 'O', signal delay and lookahead op
	ret			; is on the stack
domath_la endp

; Calculate results of top operator and one top value.
; Return value on top of the value stack.
; Returns carry set if failure
; Pops one operator, and zero (failure) or one value from stack before
; starting.
domath_calc1	proc	near
	mov	si,[bp].opcnt		; count of operators
	cmp	si,0			; any?
	jg	dom_c1_1a		; g = yes
	mov	matherr,offset opmsg3
	stc				; fail
	ret
dom_c1_1a:
	cmp	[bp].numcnt,0		; one or more values?
	jne	dom_c1_1b		; ne = yes
	mov	matherr,offset opmsg	; too few values
	stc
	ret
dom_c1_1b:
	call	popop			; get top operator from list to AX
	mov	mathkind,al		; operation to do
	call	popval			; get first value from list to DX:AX

	cmp	mathkind,'!'		; factorial?
	jne	dom_c1c			; ne = no
	mov	bx,ax			; save argument
	mov	cx,ax
	mov	ax,-1			; default for too large an arg
	mov	dx,ax
	cmp	cx,10			; largest within 32 bits?
	ja	dom_c1b			; a = too large, report -1
	mov	ax,1			; default for 0! and 1!
	xor	dx,dx
	sub	cx,ax
	jle	dom_c1b			; le = special cases of 0 and 1
	mov	ax,bx			; recover argument
dom_c1a:mul	cx
	loop	dom_c1a
dom_c1b:jmp	dom_c1_1x

dom_c1c:cmp	mathkind,'~'		; logical not?
	jne	dom_c1d			; ne = no
	not	ax			; 1's complement
	not	dx
	jmp	dom_c1_1x

dom_c1d:cmp	mathkind,'-'		; negate?
	jne	dom_c1e			; ne = no
	neg	dx
	neg	ax			; change sign
	sbb	dx,0
	jmp	dom_c1_1x

dom_c1e:cmp	mathkind,'+'		; unary '+'?
	je	dom_c1_1x		; e = yes

dom_c1f:stc				; unknown operator
	mov	matherr,offset opmsg2
	ret
dom_c1_1x:
	call	pushval
	ret				; may have carry bit set
domath_calc1 endp

; Calculate results of top operator and two top values.
; Return value on top of the value stack.
; Returns carry set if failure
; Pops one operator, and one (failure) or two values from stack before
; starting.
domath_calc2 proc near
	cmp	[bp].numcnt,2		; two or more args?
	jb	domath_calc1		; b = no, do 1 arg math

	call	popop			; get top operator from list to AX
	jnc	dom_c2_2a		; nc = success
	mov	matherr,offset opmsg3
	ret				; fail
dom_c2_2a:
	mov	mathkind,al		; operation to do
	call	popval			; get first value from list to DX:AX
	mov	bx,ax			; right side, low order
	mov	cx,dx			; right side, high order
	call	popval			; first (left side) to dx:ax
	cmp	mathkind,'^'		; raise arg1 to power of arg2?
	jne	dom_c2_6		; ne = no
	mov	cx,bx			; use low order of exponent
	dec	cx			;
	cmp	cx,31			; largest exponent we allow
	jbe	dom_c2_1		; be = ok
	mov	ax,-1			; report -1 as overflow result
	cwd
	jc	dom_c2_2y		; c = overflow error
dom_c2_1:or	cl,cl			; zero power?
	jne	dom_c2_2		; ne = no
	mov	ax,1			; report 1
	xor	dx,dx
	jmp	dom_c2_2x
dom_c2_2:push	si
	push	di
	mov	si,ax			; original number
	mov	di,dx
dom_c2_3:push	cx			; save loop counter
	mov	cx,di
	mov	bx,si			; original number
	call	lmul			; use long multiply
	pop	cx
	jc	dom_c2_4		; c = overflow
	loop	dom_c2_3
	pop	di
	pop	si
	jmp	dom_c2_2x
dom_c2_4:pop	di
	pop	si
	stc
	jmp	dom_c2_2y		; failure from overflow

dom_c2_6:cmp	mathkind,'*'		; times?
	jne	dom_c2_7		; ne = no
	call	lmul			; do 32 bit signed multiply
	jc	dom_c2_2y		; c = overflow error
	jmp	dom_c2_2x

dom_c2_7:cmp	mathkind,'/'		; divide?
	jne	dom_c2_8		; ne = no
	call	ldiv
	jc	dom_c2_2y		; c = overflow error
	jmp	dom_c2_2x

dom_c2_8:cmp	mathkind,'%'		; modulo?
	jne	dom_c2_9		; ne = no
	call	ldiv			; divide
	jc	dom_c2_2y		; c = overflow error
	xchg	cx,dx			; get remainder to dx:ax
	xchg	bx,ax
	jmp	dom_c2_2x

dom_c2_9:cmp	mathkind,'&'		; logical AND?
	jne	dom_c2_11		; ne = no
	and	ax,bx
	and	dx,cx
	jmp	dom_c2_2x

dom_c2_11:cmp	mathkind,'+'		; addition?
	jne	dom_c2_12		; ne = no
dom_c2_11a:
	push	si
	mov	si,dx			; get sign bit
	xor	si,cx			; different? if so then 1
	add	ax,bx
	adc	dx,cx
	test	si,8000h		; check for case of same start signs
	jnz	dom_c2_11b		; nz = different signs, no overflow
	mov	si,dx
	xor	si,cx			; different
	test	si,8000h		; different signs now?
	pop	si
	jnz	dom_c2_2y		; nz = yes, overflow
	jmp	dom_c2_2x
dom_c2_11b:pop	si
	jmp	dom_c2_2x

dom_c2_12:cmp	mathkind,'-'		; subtraction?
	jne	dom_c2_13		; ne = no
	neg	cx
	neg	bx			; change sign of right side number
	sbb	cx,0
	jmp	short dom_c2_11a	; now do addition with bounds check

dom_c2_13:cmp	mathkind,'|'		; logical OR?
	jne	dom_c2_14		; ne = no
	or	ax,bx
	or	dx,cx
	jmp	dom_c2_2x

dom_c2_14:cmp	mathkind,'#'		; exclusive OR?
	jne	dom_c2_15		; ne = no
	xor	ax,bx
	xor	dx,cx
	jmp	dom_c2_2x

dom_c2_15:cmp	mathkind,'@'		; GCD?
	jne	dom_c2_16		; ne = no
	call	lgcd			; call the gcd routine
	jc	dom_c2_2y		; c = overflow error
	jmp	dom_c2_2x
dom_c2_16:stc
	ret				; unknown operator

dom_c2_2x:
	call	pushval			; store result
	ret
dom_c2_2y:
	call	pushval			; store result (typically -1)
	mov	matherr,offset opmsg3
	stc				; say failure of math
	ret
domath_calc2 endp

; Push operator (AL) and precedence (AH) onto the operator stack.
; Increments [bp].opcnt.
; Return carry set if no room.
pushop	proc	near
	mov	si,[bp].opcnt		; count of operators
	cmp	si,listlen		; list full?
	jae	pushop1			; ae = yes, fail
	shl	si,1			; words
	mov	[bp].oplist[si],ax	; save operator (AL) and preced (AH)
	inc	[bp].opcnt		; one more operator in the list
	clc				; success
	ret
pushop1:mov	matherr,offset opmsg1
	stc				; fail
	ret
pushop	endp

; Pop current opcode from op stack to AX. Decrements [bp].opcnt.
; Returns carry set if no operators are available
popop	proc	near
	mov	si,[bp].opcnt		; count of operators in list
	or	si,si			; any?
	jz	popop1			; z = no, exit
	dec	si			; index from zero
	shl	si,1			; words
	mov	ax,[bp].oplist[si]	; get lookahead (last) operator
	dec	[bp].opcnt
	clc				; success
	ret
popop1:	mov	matherr,offset opmsg1
	stc				; failed to op (empty list)
	ret
popop	endp

; Push value in DX:AX onto value stack. Increments [bp].numcnt.
; Returns carry set if not enough space.
pushval	proc	near
	mov	si,[bp].numcnt
	cmp	si,listlen		; at limit of list?
	ja	pushval1		; a = exceeded list length, fail
	shl	si,1			; address dwords
	shl	si,1
	mov	[bp].numlist[si],ax	; push dx:ax onto value stack
	mov	[bp].numlist[si+2],dx	; high order part
	inc	[bp].numcnt		; occupancy is one greater
	clc				; succeed
	ret
pushval1:stc				; fail
	ret
pushval	endp

; Pop top value from value stack into DX:AX. Decrements [bp].numcnt.
; Returns carry set if no value were available.
popval	proc	near
	mov	si,[bp].numcnt		; count of values in list
	or	si,si			; count
	jz	popval1			; z = none
	dec	si			; index from 0
	shl	si,1			; address dwords
	shl	si,1
	mov	ax,[bp].numlist[si]	; pop top value to dx:ax
	mov	dx,[bp].numlist[si+2]	; high order part
	dec	[bp].numcnt		; occupancy is one less
	clc				; success
	ret
popval1:stc				; fail
	ret
popval	endp
					; end of domath procedures

; Perform 32 bit division. Numerator is in DX:AX, denominator in CX:BX.
; Returns quotient in DX:AX, remainder in CX:BX. Carry set and -1 on
; divide by zero.
ldiv	proc	far
	push	temp
	push	temp1
	push	si
	push	di
	mov	tmp,0			; holds final sign (0=positive)
	or	dx,dx			; numerator is negative?
	jge	ldiv1			; ge = no
	neg	dx
	neg	ax
	sbb	dx,0			; change sign
	xor	tmp,1			; remember to change sign later
ldiv1:	or	cx,cx			; denominator is negative?
	jge	ldiv2			; ge = no
	neg	cx
	neg	bx
	sbb	cx,0			; change sign
	xor	tmp,1			; remember to change sign later
ldiv2:	mov	di,cx			; denominator, hold here
	mov	si,bx
	cmp	dx,cx			; is numerator larger than denom?
	jne	ldiv10			; ne = yes, and 32 bits too
	or	dx,dx			; 32 bit number?
	jnz	ldiv10			; nz = yes
				; only 16 bit numbers here
	or	bx,bx			; denominator zero?
	jnz	ldiv3			; nz = no
	jmp	ldivf			; overflow, report failure

ldiv3:	div	bx			; regular signed division
	mov	bx,dx			; remainder
	xor	dx,dx			; high quotient
	xor	cx,cx			; high remainder
	jmp	ldivx			; exit success

				; 32 bit numbers here
ldiv10:	mov	tmp1,0			; shift counter
	mov	temp,0			; shift accumulator, low part
	mov	temp1,0			; shift accumulator, high part
	or	cx,cx			; check for zero denominator
	jnz	ldiv11			; nz = not zero
	or	bx,bx
	jz	ldivf			; zero, exit failure

ldiv11:	cmp	dx,di			; top vs bottom high order words
	jb	ldiv13			; b = top smaller than bottom
	ja	ldiv12			; a = top larger than bottom
					; high order words are the same
	cmp	ax,si			; top vs bottom low order words
	jb	ldiv13			; b = top eq or larger than bottom
	je	ldiv15			; e = top equals bottom
				; top is larger than bottom
ldiv12:	or	di,di			; can shift left further?
	js	ldiv14			; s = no, accumulate and back down
	inc	tmp1			; remember doing left shift
	shl	si,1			; shift denominator left one bit
	rcl	di,1			; include carry-out from low half
	jmp	short ldiv11		; compare again til top < bot

; either we start with top < bottom (tmp1 = 0), or we have left shifted
; the bottom enough (tmp1 > 0) to create that condition.

       				; top is smaller than or equal to bottom
ldiv13:	cmp	tmp1,0			; any shifts remaining?
	je	ldiv16			; e = no
; If tmp1 is 0 then we are done, no further adjustments can be made.
; Else back off tmp1 by one position
	dec	tmp1			; shift right by 1 to get top >= bot
	shr	di,1
	rcr	si,1

ldiv14:	cmp	dx,di			; is top less than bottom?
	jb	ldiv13			; b = yes, shift again
	ja	ldiv15			; a = no, greater than
	cmp	ax,si			; low order part
	jb	ldiv13			; b = top is less than bottom
ldiv15:	sub	ax,si			; (top - bottom) to get remainder
	sbb	dx,di
	call	ldiv_acc		; accumulate shifted success
	jmp	short ldiv14		; try again til top < bot

ldiv16:	mov	bx,ax			; remainder to cx:bx
	mov	cx,dx			; quotient to dx:ax
	mov	ax,temp			; extract accumlated shifts
	mov	dx,temp1		; and exit success

					; successful exit, update signs
ldivx:	cmp	tmp,0			; need to adjust signs?
	je	ldivx1			; e = no
	neg	dx
	neg	ax			; change sign of quotient
	sbb	dx,0
	neg	cx
	neg	bx			; change sign of remainder
	sbb	cx,0
ldivx1:	pop	di
	pop	si
	pop	temp1
	pop	temp
	clc				; success
	ret

ldivf:	mov	ax,-1			; failure
	cwd				; report -1
	mov	bx,ax
	mov	cx,ax
	pop	di			; failure exit
	pop	si
	pop	temp1
	pop	temp
	stc				; say failure
	ret

ldiv_acc proc	near			; add current shift to accumulator
	push	cx
	push	ax
	push	dx
	mov	cl,tmp1			; shift bit count
	xor	ch,ch
	mov	ax,1			; value = 2 ** temp1
	xor	dx,dx
	jcxz	ldiv_acc2		; z = nothing to do
ldiv_acc1:shl	ax,1
	rcl	dx,1
	loop	ldiv_acc1
ldiv_acc2:add	temp,ax			; accumulate shifts
	adc	temp1,dx
	pop	dx
	pop	ax
	pop	cx
	ret
ldiv_acc endp
ldiv	endp

; Multiplies 32 bit values in DX:AX by CX:BX and returns the result in
; DX:AX. Overflows result in carry set and -1 as the answer. Signed
; arithmetic is used here, beware.
lmul	proc	far
	push	si
	push	di
	push	bx
	push	cx
	push	temp
	mov	temp,0			; zero means no sign change at end
	or	dx,dx			; negative?
	jns	lmul1			; ns = no
	neg	ax			; make positive
	neg	dx
	sbb	dx,0
	xor	temp,1			; sign change needed
lmul1:	or	cx,cx			; ditto for cx:bx
	jns	lmul2
	neg	bx
	neg	cx
	sbb	cx,0
	xor	temp,1
lmul2:	or	cx,cx			; check for high word in both numbers
	jz	lmul3			; z = bottom does not have it
	or	dx,dx
	jnz	lmul4			; nz = both have parts too large

lmul3:	push	dx
	push	ax
	mul	bx			; low bottom time whole top
	mov	di,dx
	mov	si,ax			; regular product to di:si
	pop	ax
	pop	dx			; recover normal top
	push	dx
	push	ax
	mov	ax,dx
	mul	bx
	add	di,ax
	pop	ax
	pop	dx			; recover normal top
	js	lmul4			; s = overflow in high accumlator
	mul	cx			; high bottom times regular top
	add	di,ax			; high reg product plus new product
	jns	lmul5			; ns = no overflow in high accumulator

lmul4:	mov	ax,-1			; overflow, yield minus one as answer
	cwd				; extend sign to dx
	mov	temp,0			; no sign change
	stc				; carry set for problem
	jmp	short lmul6
lmul5:	mov	dx,di			; results to dx:ax
	mov	ax,si
	cmp	temp,0			; sign change needed?
	je	lmul6			; e = no
	neg	dx			; flip output sign
	neg	ax
	sbb	dx,0
	clc				; carry clear for no problem
lmul6:	pop	temp
	pop	cx
	pop	bx
	pop	di
	pop	si
	ret
lmul	endp

; Greatest common divisor, 32 bit (removes signs). Inputs are DX:AX and
; CX:BX. Results are in DX:AX. Carry bit set and -1 returned if error.
lgcd	proc	far
	push	bx
	push	cx
	or	dx,dx			; negative?
	jns	lgcd1			; ns = no
	neg	ax			; make positive
	neg	dx
	sbb	dx,0
lgcd1:	or	cx,cx			; negative?
	jns	lgcd2			; ns = no
	neg	bx
	neg	cx			; make positive
	sbb	cx,0
lgcd2:	cmp	dx,cx			; first arg same/larger than second?
	ja	lgcd4			; a = yes
	jb	lgcd3			; b = smaller
	cmp	ax,bx			; low order parts
	jae	lgcd4			; ae = larger
lgcd3:	xchg	dx,cx			; make largest the top number dx:ax
	xchg	ax,bx
lgcd4:	push	bx			; preserve smaller number
	push	cx
	call	ldiv			; large / small
	jc	lgcd6			; c = divide by zero
	mov	dx,cx			; temp spot
	or	dx,bx			; remainder?
	jz	lgcd5			; z = no, small is the answer
	pop	dx			; new values, new top is old bot
	pop	ax			; bottom is new remainder
	jmp	short lgcd2		; repeat calculation
lgcd5:	pop	dx			; recover smaller number from stack
	pop	ax			; result in dx:ax
	pop	dx
	pop	cx
	clc
	ret				; success
lgcd6:	pop	ax
	pop	ax			; clean stack
	pop	dx
	pop	cx
	mov	ax,-1			; dx:ax = -1 on error
	cwd
	stc
	ret
lgcd	endp

; Convert ASCIIZ string in DS:SI of form hh:mm:ss to ASCIIZ string seconds
; in ES:DI.
tod2secs proc	far
	mov	temp,0
	mov	temp1,0
	xor	dx,dx			; dh=field counter, dl=read byte
	xor	bx,bx			; three groups possible
tod2s1:	mov	dl,[si]			; get a char
	inc	si			; next char
	inc	dh			; count char in field
	or	dl,dl			; null terminator?
	jz	tod2s3			; z = yes, wrap calculations and quit
	cmp	dl,':'			; field separator?
	je	tod2s3			; e = a separator, step fields
	sub	dl,'0'			; remove ascii bias
	cmp	dl,9
	ja	short tod2s6		; a = failure to get expected digit
	cmp	dh,2			; more than two bytes in this field
	ja	tod2s6			; a = yes, fail translation
	mov	al,bh			; get sum to al
	mov	ah,10
	mul	ah			; sum times ten
	add	al,dl			; sum = 10 * previous + current
	mov	bh,al			; current sum
	mov	ah,60
	or	bl,bl			; doing hours?
	jne	tod2s2			; ne = no, min, sec
	mov	ah,24			; max for hours field
tod2s2:	cmp	bh,ah			; more than legal?
	jae	tod2s6			; ae = illegal
	jmp	short tod2s1		; continue analysis

tod2s3:	mov	al,bh			; current sum
	xor	ah,ah
	mov	cx,1
	cmp	bl,2			; seconds?
	je	tod2s4			; e = yes
	mov	cx,60
	or	bl,bl			; hours?
	jne	tod2s4			; ne = no
	mov	cx,60*60		; seconds per hour
tod2s4:	mul	cx
	add	temp,ax
	adc	temp1,dx
	xor	bh,bh			; bh = current field sum
	xor	dh,dh			; dh = counter of bytes in field
	cmp	byte ptr [si-1],0	; ended on null?
	je	tod2s5			; e = yes, end of conversion
	inc	bl			; point to next field
	cmp	bl,2			; last field to use (secs)
	jbe	tod2s1			; be = get more text
tod2s5:	mov	ax,temp
	mov	dx,temp1
	push	di
	mov	di,offset tmpstring	; build ASCII in this buffer
	call	flnout
	pop	di
	mov	dx,offset tmpstring
	mov	si,dx
	call	strlen
	cld
	rep	movsb			; copy string to es:di area
	mov	byte ptr es:[di],0	; and null terminator
	clc				; carry clear for success
	ret
tod2s6:	mov	byte ptr es:[di],0
	stc				; carry set for illegal value	
	ret
tod2secs endp
code1	ends 
	end
