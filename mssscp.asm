	NAME	mssscp
; File MSSSCP.ASM
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
;       
; MS Kermit Script routines, DEC-20 style.
; Extensively rewritten for MS Kermit 2.29a by Joe R. Doupnik 5 July 86
;;
;    Created June, 1986 a.d.	By James Sturdevant
;					  A. C. Nielsen Co. Mpls.
;					  8401 Wayzata Blvd.
;					  Minneapolis, Mn. 55426
;					  (612)546-0600
;;;;;;;;
; Kermit command level usages and this file's entry points:
; Clear - clears serial port buffers. Procedure scclr.
; Echo text - displays text on local screen. Proc scecho.
; Pause [time] - waits indicated number of seconds (default is Input
;	Default-timeout, 1 second typically). Proc scpau.
; IF condtion command - tests condition (SUCCESS or FAILURE just now) and
;       if the condition is met executes the main-line Kermit command.
; GOTO label - rewinds Take file or Macro, locates the :label, transfers
;       parsing control to the next line.
; Input [time] text - waits up to time seconds while scanning serial port
;	input for a match with text. Default value for time is Input
;	Default-timeout, 1 second typically). Spaces or tabs are separators
;	between the time and text fields. Proc scinp.
;	A carriage return typed by the local user simulates a match.
; Reinput [time] text - like INPUT but non-destructively rereads the 128 byte
;       script buffer. Buffer can be added to, until full, if necessary.
; Output text - sends the text to the serial output port. Proc scout.
; Transmit text [prompt] - raw file transfer to host. Proceeds from source
;	line to source line upon receipt of prompt from host or carriage
;	return from us. Default prompt is linefeed. A null prompt (\0)
;	causes the file to be sent with no pausing or handshaking. Note
;	that linefeeds are stripped from outgoing material. Proc scxmit.
; In the above commands "text" may be replaced by "@filespec" to cause the
;	one line of that file to be used instead. @CON obtains one line of
;	text from the keyboard. Such "indirect command files" may be nested
;	to a depth of 100. Control codes are written as decimal numbers
;	in the form "\ddd" where d is a digit between 0 and 9. Carriage
;	return is \13, linefeed is \10, bell is \7; the special code \255
;	is used to match (Input) either cr or lf or both.
; These commands can be given individually by hand or automatically
;	in a Kermit Take file; Take files may be nested.
;;;;;;;;
; These routines expect to be invoked by the Kermit command dispatcher
; and can have their default operations controlled by the Kermit Set Input
; command (implemented in file mssset.asm). They parse their own cmd lines.
; Set Input accepts arguments of
;   Case Ignore or Observe  (default is ignore case when matching strings)
;   Default-timeout seconds (default is 5 seconds)
;   Echo On or Off	controls echoing of Input cmd text (default is Off)
;   Timeout-action Quit or Proceed (default is Proceed)
; These conditions are passed via global variables script.incasv, .indfto,
;   .inecho, .inactv, respectively, stored here in structure script.
;;;;;;;;;					

	public	script, scout, scinp, scpau, scecho, scclr, scxmit, scwait
    	public	sgoto, screinp, ifcmd, setalrm, inptim, chktmo, alrhms
	public	buflog, scpini, scpbuflen, decvar, incvar, scmpause, outpace
	public	scsleep, scapc, inpath_seg, sforward, scminput, xecho
	public	input_status, xifcmd, whilecmd, minpcnt, switch

linelen	 	equ	134		; length of working buffer line
maxtry		equ	5		; maximum number of output retries
stat_unk 	equ	0  		; status return codes.
stat_ok		equ	1		; have a port character
stat_cc		equ	2		; control-C typed
stat_tmo	equ	4		; timeout
stat_cr		equ	8		; carriage return typed

ifsuc		equ	0+0		; indicators for IF conditions
iffail		equ	1+0100h		; plus high byte = number of args
ifext		equ	2+0100h
iferr		equ	3+0100h
ifnot		equ	4+0
ifctr		equ	5+0
ifmdf		equ	6+0100h
ifalarm		equ	7+0100h
ifequal		equ	8+0200h
ifless		equ	9+0200h
ifsame		equ	10+0200h
ifmore		equ	11+0200h
ifllt		equ	12+0200h
iflgt		equ	13+0200h
ifpath		equ	14+0100h
ifdir		equ	15+0100h
ifnewer		equ	16+0100h
iftrue		equ	17+0
ifemulation	equ	18+0

braceop	equ	7bh		; opening curly brace
bracecl	equ	7dh		; closing curly brace

data	segment
	extrn	taklev:byte, takadr:word, portval:word, flags:byte
	extrn	rxtable:byte, spause:byte, errlev:byte, fsta:word
	extrn	kstatus:word, mcctab:byte, comand:byte, ttyact:byte
	extrn	keyboard:word, rdbuf:byte, apctrap:byte, filtst:byte
	extrn	diskio:byte, buff:byte, domath_ptr:word, domath_cnt:word
	extrn	domath_msg:word, pardone:word, parfail:word, ifelse:byte
	extrn	domacptr:word, marray:word

					; global (public) variables     
script	scptinfo <>			; global structure, containing:
;;inactv	db	0		; input action value (default proceed)
;;incasv	db	0		; input case  (default ignore)
;;indfto	dw	1		; input and pause timeout (def 1 sec)
;;inecho	db	1		; echo Input cmd text (0 = no)
;;infilter	db	1	; filer control sequences from screen (0=no)
;;xmitfill	db	0		; non-zero to TRANSMIT filler
;;xmitlf	db	0		; non-zero to TRANSMIT LF's
;;xmitpmt	db	lf		; prompt between lines

					; local variables
line	db	linelen+1 dup (0)	; line of output or input + terminator
		even
scpbuflen dw	128			; serial port local buffer def length
minpcnt dw	0			; minput successful match pattern
bufcnt	dw	0			; serial port buf byte cnt, must be 0
bufseg	dw	0			; segment of buffer
bufrptr dw	0			; input buffer read-next pointer
inpath_seg dw	0			; segment of inpath string (0=none)
reinflg	db	0			; 0=INPUT, 1=REINPUT, 2=MINPUT
notflag	db	0			; IF NOT flag
slablen	dw	0			; label length, for GOTO
forward	db	0			; 0=goto, else use Forward form
status	dw	0			; general status word
disp_state dw	0			; scdisp state machine state
fhandle	dw	0			; file handle storage place
temptr	dw	0			; temporary pointer
temptr2	dw	0			; ditto, points to end of INPUT string
tempd	dw	0			; temp
temp	dw	0			; a temp
temp1	dw	0			; high order part of temp
tempa	dw	0			; another temp
wtemp	db	0			; temp for WAIT
ltype	dw	0			; lex type for IF statements
retry	db	0			; number of output retries
parmsk	db	7fh			; 7/8 bit parity mask
lecho	db	0			; local echo of output (0 = no)
timout	dw	0			; work area (seconds before timeout)
timhms	db	4 dup (0)		; hhmmss.s time of day buffer
alrhms	db	4 dup (0)		; hhmmss.s time of day alarm buffer
outpace	dw	0			; OUTPUT pacing, millisec
input_status dw 0ffffh			; INPUT status for v(instatus)
deflabel db	'default',0		; label :default, asciiz

crlf	db	cr,lf,'$'
xfrfnf	db	cr,lf,'?Transmit file not found$'
xfrrer	db	cr,lf,'?error reading Transmit file$'
xfrcan	db	cr,lf,'?Transmission canceled$'
indmis	db	'?Indirect file not found',cr,lf,'$'
inderr	db	'?error reading indirect file',cr,lf,'$'
laberr	db	cr,lf,'?Label ":$'
laberr2	db	'" was not found.',cr,lf,'$'
tmomsg	db	cr,lf,'?Timeout',cr,'$'
wtbad	db	cr,lf,'?Command not understood, improper syntax $'
mpbad	db	cr,lf,'?Bad number$'

ifkind	db	0		; 0 = IF, 1 = XIF, 2 = WHILE

clrtable db	4
	mkeyw	"input-buffer",1
	mkeyw	"device-buffer",2
	mkeyw	"both",3
	mkeyw	'APC',4

iftable	db	20			; IF command dispatch table
	mkeyw	'Not',ifnot
	mkeyw	'<',ifless
	mkeyw	'=',ifsame
	mkeyw	'>',ifmore
	mkeyw	'Alarm',ifalarm
	mkeyw	'Count',ifctr
	mkeyw	'Defined',ifmdf
	mkeyw	'Directory',ifdir
	mkeyw	'Emulation',ifemulation
	mkeyw	'Errorlevel',iferr
	mkeyw	'Equal',ifequal
	mkeyw	'Exist',ifext
	mkeyw	'Inpath',ifpath
	mkeyw	'LGT',iflgt
	mkeyw	'LLT',ifllt
	mkeyw	'Newer',ifnewer
	mkeyw	'Numeric',ifnumeric
	mkeyw	'Failure',iffail
	mkeyw	'Success',ifsuc
	mkeyw	'True',iftrue
data	ends

data1	segment
outhlp	db	'line of text to be sent to remote host$'
apchlp	db	'Applications Program Commands to send to remote host$'
inphlp	db	'time-limit and line of text expected from remote host'
	db	cr,lf,' Time is number of seconds or until a specific'
	db	' hh:mm:ss (24 hour clock)$'
echhlp	db	'line of text to be Echoed to screen$'
ptshlp	db	'amount of time to pause/wait'
	db	cr,lf,' Time is number of seconds or until a specific'
	db	' hh:mm:ss (24 hour clock)$'
wthlp	db	cr,lf,' Optional modem status signals CD, CTS, DSR, RI which'
	db	' if asserted',cr,lf,'  will terminate waiting$'
xmthlp	db	' Name of file to be Transmitted$'
pmthlp	db	cr,lf
	db     ' Prompt character expected as an ACK from host (\0 for none)$'
ifdfhlp	db	cr,lf,' Name of macro or variable$'
alrmhlp	db	cr,lf,' Seconds from now or time of day (HH:MM:SS) for alarm,'
	db	' < 12H from present$'
mphlp	db	cr,lf,' Number of milliseconds to pause (0..65535)$'
ifmhlp	db	cr,lf,' Number, ARGC (1+argument count), COUNT, ERRORLEVEL,'
	db	' KEYBOARD, VERSION$'
ifnhlp	db	cr,lf,' Number which errorlevel should match or exceed$'
ifehlp	db	cr,lf,' word or variable to be compared$'
ifnewhlp db	' filename$'
whilehlp db	cr,lf,' While if-condition {command, command,...}'
chgvarhlp db	'name of variable$'
ssizehlp db	'amount, default is 1$'
clrhelp	db	cr,lf,' INPUT-BUFFER (script string matching buffer), or'
	db	cr,lf,' DEVICE-BUFFER (comms receive), or BOTH (buffers)'
	db	cr,lf,' APC (to not return to Connect mode after APC cmd)$'
mskcmd	db      ' Kermit command$'
	db	cr,lf,' "IF" condition is false, command will be ignored.$'
sleephlp db	cr,lf,' Wait seconds or time of day (HH:MM:SS), does not'
	db	' touch comms port.$'
switchhlp1 db	cr,lf,' index'
switchhlp2 db	' {body of Switch statement}$'

; ifkind    0 1 2	 3	4 5 6	    7 8       9      10
ifhlplst dw 0,0,ifnewhlp,ifnhlp,0,0,ifdfhlp,0,ifehlp,ifmhlp,ifmhlp
;	   11	  12	 13	14	 15	  16
	dw ifmhlp,ifehlp,ifehlp,ifnewhlp,ifnewhlp,ifnewhlp
data1	ends

code1	segment
	extrn	isdev:far, tolowr:far, prtasz:far, strlen:far, domath:far
	extrn	isfile:far, malloc:far, atpclr:near, atparse:near
	extrn	strcpy:far, prtscr:far, dec2di:far, strcat:far, docnv:far
	extrn	takrd:far, toupr:far, poplevel:far
	assume	cs:code1
code1	ends

code	segment
     
	extrn	comnd:near, clrbuf:near, prtchr:near, outchr:near
	extrn	cptchr:near, serini:near, pcwait:far, spath:near
	extrn	getmodem:near, sendbr:near, takclos:far
	extrn	sendbl:near, lnout:near, dopar:near, dodecom:near
	extrn	takopen_macro:far, cnvlin:near
	assume	cs:code, ds:data, es:nothing

fcptchr	proc	far
	call	cptchr
	ret
fcptchr	endp

fprtchr	proc	far
	call	prtchr
	ret
fprtchr	endp

; Initialize script routines before use, called as Kermit initializes.

SCPINI	PROC	NEAR
	mov	cx,scpbuflen		; (RE)INPUT buffer length
	mov	bx,cx			; string length, in bytes
	add	bx,15			; round up
	jnc	scpini1			; nc = under max size
scpini3:mov	bx,0ffffh		; 64KB-16 bytes, max buffer
scpini1:mov	cl,4
	shr	bx,cl			; convert to paragraphs (divide by 16)
scpini2:mov	cx,bx			; remember desired paragraphs
	mov	ah,alloc		; allocate a memory block
	int	dos
	jc	scpini4			; error, not enough memory
	mov	bufseg,ax		; store new segment
	mov	cl,4
	shl	bx,cl			; convert paragraphs to bytes
	mov	scpbuflen,bx		; new length
	mov	bufcnt,0		; clear the buffer (say is empty)
	mov	bufrptr,0		; buffer read-next pointer
	clc				; return success
	ret
scpini4:mov	scpbuflen,0
	stc				; carry set for failure to initialize
	ret
SCPINI	ENDP

; Clear input buffer(s) of serial port
; Clear command
;     
SCCLR	PROC	NEAR
	mov	comand.cmcr,1		; permit empty line
	mov	ah,cmkey
	mov	dx,offset clrtable
	mov	bx,offset clrhelp
	call	comnd
	mov	comand.cmcr,0
	mov	kstatus,kssuc		; global status
	push	bx			; cmd return
	mov	ah,cmeol		; get a confirm
	call	comnd
	pop	bx
	jnc	scclr1			; nc = success
	ret				; failure
scclr1:	xor	ax,ax
	mov	disp_state,ax		; reinit escape parser
	cmp	bx,1
	jne	scclr2
	mov	bufcnt,ax		; clear INPUT buffer (say is empty)
	mov	bufrptr,ax		; buffer read-next pointer
	clc
	ret
scclr2:	cmp	bx,2
	jne	scclr3			; default, gibberish bx
	call	clrbuf
	clc
	ret
scclr3:	cmp	bx,3			; BOTH?
	jne	scclr4			; ne = no
	mov	bufcnt,ax		; clear INPUT buffer (say is empty)
	mov	bufrptr,ax		; buffer read-next pointer
	call	clrbuf			; clear system serial port buffer too
	clc
	ret
scclr4:	cmp	bx,4			; APC?
	jne	scclr7
scclr5:	call	poplevel		; pop macro/take level
	ret
scclr7:	stc				; fail
	ret
SCCLR	ENDP

XECHO	proc	near
	mov	temp,1			; say want no leading cr/lf
	jmp	short echo1
XECHO	endp

;
; Echo a line of text to our screen
; Echo text
;
SCECHO	PROC	NEAR
	mov	temp,0			; say do cr/lf before text
echo1:	mov	ah,cmline		; get a whole line of asciiz text
	mov	bx,offset rdbuf		; where to store in
	mov	comand.cmdonum,1	; \number conversion allowed
	mov	comand.cmblen,cmdblen	; set line capacity (length of rdbuf)
	mov	dx,offset echhlp	; help
	call	comnd
	jnc	echo2
	ret
echo2:	push	ax			; returned byte count
	cmp	temp,0			; perform leading cr/lf?
	jne	echo3			; ne = no
	mov	ah,prstr
	mov	dx,offset crlf
	int	dos
echo3:	pop	cx			; recover byte count
	mov	di,offset rdbuf		; start of line
	call	prtscr			; print all bytes in ds:di, cx = count
	clc				; return success
	ret				; error
SCECHO	ENDP

; Extract label from command line. Store in LINE, length in slablen.
; Jump to line in Take or Macro following that label.
SGOTO	PROC	NEAR
	mov	forward,0		; assume goto, not forward
goto0:	mov	kstatus,kssuc		; global status
	mov	ah,cmword		; get label (leaves ending CR unread)
	mov	bx,offset line		; buffer to hold label
	xor	dx,dx			; no help (non-interactive command)
	mov	slablen,dx		; clear label holding buffer
	call	comnd
	jnc	goto1			; nc = success
	ret				; failure
goto1:	mov	slablen,ax		; save count here
	cmp	slablen,0		; need contents
	jz	goto2			; empty, fail
	cmp	flags.cxzflg,'C'	; check for Control-C breakout
	je	goto2			; e = yes, fail
	cmp	taklev,0		; in a Take file or Macro?
	jne	goto3			; ne = yes, find the label
	clc				; ignore interactive command
	ret
goto2:	stc
	ret
goto3:	call	getto			; far call the label finding worker
	mov	comand.cmkeep,0		; do not keep open the macro after EOF
	ret
SGOTO	ENDP

; Like GOTO but searches only forward from the current point.
; Forward cascades upward during searches of surrounding Take files/macros.
SFORWARD proc	near
	mov	forward,1		; say search only forward
	jmp	goto0
SFORWARD endp

; SWITCH variable {:label,commands,:label,commands,...}
; Have label :default present for unmatched labels.
SWITCH	proc	near
	mov	ah,cmword		; get variable
	mov	bx,offset line		; where to store it
	mov	comand.cmdonum,0	; \number conversion NOT allowed
	mov	dx,offset switchhlp1	; help
	call	comnd
	jnc	swit1
	ret
swit1:	mov	slablen,ax		; length of label
	mov	ah,cmline
	mov	bx,offset rdbuf+2	; buffer for switch body
	mov	dx,offset switchhlp2	; help
	mov	comand.cmdonum,1	; \number conversion is allowed
	mov	comand.cmper,1		; do not react to '\%' in macro name
	mov	comand.cmcnvkind,cmcnv_crprot ; allow CR within {..}
	mov	comand.cmblen,cmdblen	; set line capacity (length of rdbuf)
	call	comnd
	jnc	swit2
	ret
swit2:	mov	word ptr rdbuf,ax	; length to start of string
	mov	si,ds
	mov	es,si
	mov	si,offset rdbuf		; es:si is source of string
	call	docnv			; convert macro string in-place
	call	takopen_macro		; open macro
	jnc	swit3			; nc = succeeded
	ret
swit3:	mov	ax,word ptr rdbuf	; string length
	add	ax,2			; plus count word
	call	malloc			; ax has size of buffer
	jnc	swit4			; nc = success
	ret				; fail

swit4:	mov	bx,takadr		; point to current macro structure
	mov	[bx].takbuf,ax		; segment of definition string struc
	mov	cx,word ptr rdbuf	; string length
	mov	[bx].takcnt,cx		; number of chars in definition
	mov	[bx].takptr,2		; where to read first string byte
	or	[bx].takattr,take_malloc; say have buffer to be removed
	or	[bx].takattr,take_switch ; doing Switch, for Break/Continue
	mov	si,offset rdbuf		; switch body string
	push	es
	mov	es,ax			; new memory segment
	xor	di,di			; follow with string
	add	cx,2			; copy count word too
	cld
	rep	movsb			; copy string to malloc'd buffer
	pop	es
	mov	forward,2		; identify SWITCH operation
	call	getto			; find line after label or fail
	jc	swit5			; c = failed, try label :default
	ret				; found, execute
swit5:	mov	si,offset deflabel	; label :default
	mov	di,offset line
	call	strcpy
	mov	dx,offset line
	call	strlen
	mov	slablen,cx
	mov	bx,takadr		; rewind the macro
	mov	[bx].takptr,2		; where to read next time
	mov	ax,[bx].takbuf		; segment of string
	mov	es,ax
	mov	ax,es:[0]		; get string length from string
	mov	[bx].takcnt,ax		; quantity unread
	call	getto			; dispatch to label :default
	jc	swit6			; failed to find :default
	ret				; success, do :default commands
swit6:	call	takclos			; close switch macro
	stc				; fail
	ret
SWITCH	endp

; IF [NOT] {< }| = | > | ALARM | COUNT | FAILURE | SUCCESS | INPATH filespec
;	| ERRORLEVEL \number | EQUAL string string | EXIST filespec |
;	NUMBER } command

IFCMD	PROC	NEAR
	xor	ax,ax
	mov	ifkind,al		; say doing IF, not XIF or WHILE
	mov	notflag,al		; assume NOT keyword is absent
	mov	ifelse,al		; say ELSE if not yet permitted

ifcmd1:	mov	ah,cmkey		; parse keyword
	mov	dx,offset iftable	; table of keywords
	xor	bx,bx			; help is the table
	call	comnd
	jnc	ifcmd1a			; nc = success
	ret				; failure
ifcmd1a:cmp	bx,ifnot		; NOT keyword?
	jne	ifcmd2			; ne = no
	xor	notflag,1		; toggle not flag
	jmp	short ifcmd1		; and get next keyword

ifcmd2:	cmp	bx,ifsuc		; IF SUCCESS?
	jne	ifcmd4			; ne = no
	cmp	kstatus,kssuc		; do we have success?
	je	ifcmd2a			; e = yes
	jmp	ifcmdf			; ne = no, no jump
ifcmd2a:jmp	ifcmdp			; yes

ifcmd4:	cmp	bx,iferr		; IF ERRORLEVEL?
	jne	ifcmd5			; ne = no
	jmp	ifnum			; parse number to binary in line

ifcmd5:	cmp	bx,ifext		; IF EXIST filespec?
	je	ifcmd5a			; e = yes
	cmp	bx,ifpath		; IF INPATH filespec?
	je	ifcmd5a			; e = yes
	cmp	bx,ifdir		; IF DIR filespec?
	jne	ifcmd6			; ne = no
ifcmd5a:mov	ah,cmword		; read a filespec
	mov	dx,offset ifnewhlp	; help
	mov	comand.cmblen,cmdblen	; long for long paths
	push	bx
	mov	bx,offset rdbuf		; buffer for filespec
	mov	word ptr [bx],0
	call	comnd
	pop	bx
	jnc	ifcmd5k			; nc = success
	ret				; failure
ifcmd5k:or	ax,ax			; any text?
	jnz	ifcmd5b			; nz = yes
	jmp	ifcmdf			; fail

ifcmd5b:mov	si,offset rdbuf		; file spec, top of loop
	mov	dx,si
	call	strlen
	add	si,cx			; look at last char
	or	cx,cx			; if any bytes
	jz	ifcmd5d			; z = none
	cmp	byte ptr [si-1],':'	; ends on ":"?
	je	ifcmd5f			; e = yes, just a drive letter
	cmp	byte ptr [si-1],'\'	; ends on backslash?
	je	ifcmd5e			; e = yes
	cmp	byte ptr [si-1],'.'	; ends on dot?
	jne	ifcmd5d			; ne = no
ifcmd5e:mov	byte ptr [si-1],0	; trim trailing backslash
	jmp	short ifcmd5b		; keep trimming

ifcmd5f:cmp	bx,ifdir		; IF DIRECTORY?
	jne	ifcmd5d			; ne = no
	mov	ah,gcurdsk		; get current disk
	int	dos
	push	ax			; save current disk in al
	xor	dl,dl
	xchg	dl,rdbuf		; get drive letter, set rdbuf=0 fail
	or	dl,40h			; to lower
	sub	dl,'a'			; 'a' is 0
	mov	ah,seldsk		; select disk
	int	dos
	jc	ifcmd5g			; c = fail
	cmp	ah,0ffh			; 0ffh is failure too
	je	ifcmd5g			; e = failure
	inc	rdbuf			; 1 is success
ifcmd5g:pop	ax
	mov	dl,al			; current disk
	mov	ah,seldsk		; reset to current directory
	int	dos
	cmp	rdbuf,0			; fail?
	je	ifcmdf			; e = yes
	jmp	ifcmdp			; pass

ifcmd5d:cmp	bx,ifpath		; IF INPATH?
	je	ifcmd5c			; e = yes
	mov	ax,offset rdbuf		; isfile wants pointer in ds:ax
	push	bx
	call	isfile			; see if file EXISTS
	pop	bx
	jc	ifcmdf			; c = no, fail
	cmp	bx,ifdir		; IF DIRECTORY?
	jne	ifcmdp			; ne = no, Exists so succeed
	test	byte ptr filtst.dta+21,10H ; subdirectory name?
	jnz	ifcmdp			; nz = yes
	cmp	filtst.fname,2eh	; directory name?
	je	ifcmdp			; e = yes
	jmp	ifcmdf			; else fail
ifcmd5c:push	es
	mov	ax,inpath_seg		; preexisting inpath_seg?
	or	ax,ax
	jz	ifcmd5h			; z = no buffer yet
	mov	es,ax			; free it now
	mov	ah,freemem
	int	dos
	mov	inpath_seg,0		; say no segment
ifcmd5h:pop	es
	mov	ax,offset rdbuf		; file pointer
	call	spath			; search path
	jc	ifcmdf			; c = no such file
	push	es
	push	ax
	mov	dx,ax			; offset of local copy of ds:string
	call	strlen
	mov	si,ax			; start of string
	add	si,cx			; end of string + 1
ifcmd5i:dec	si
	cmp	byte ptr [si],'\'	; path/filename separator?
	je	ifcmd5j			; e = yes
	cmp	byte ptr [si],':'	; drive separator?
	je	ifcmd5j			; e = yes
	loop	ifcmd5i
ifcmd5j:inc	si
	inc	cx
	mov	byte ptr [si],0		; stuff a terminator
	mov	ax,cx			; length needed
	add	ax,2			; plus length word
	call	malloc			; create a buffer
	mov	inpath_seg,ax		; segment of string
	mov	es,ax
	xor	di,di
	mov	ax,cx
	cld
	stosw				; store count
	pop	si			; ds:offset of path string (was AX)
	rep	movsb			; copy string to buffer
	pop	es
	jmp	ifcmdp			; succeed, do the succeed stuff
	
ifcmd6:	cmp	bx,iffail		; IF FAIL?
	jne	ifcmd7
	test	kstatus,not (kssuc)	; check all bits
	jz	ifcmdf			; z = not that condition, no jump 
	jmp	ifcmdp

ifcmd7:	cmp	bx,ifctr		; IF COUNT?
	jne	ifcmd8			; ne = no
	cmp	taklev,0		; in a Take file?
	je	ifcmdf			; e = no, fail
	push	bx
	mov	bx,takadr		; current Take structure
	cmp	[bx].takctr,0		; exhausted count?
	je	ifcmd7a			; e = yes, dec no more ye counter
	dec	[bx].takctr		; dec COUNT if non-zero
	jz	ifcmd7a			; z = exhausted
	pop	bx
	jmp	ifcmdp			; COUNT > 0 at entry, execute command
ifcmd7a:pop	bx
	jmp	ifcmdf			; do not execute command

ifcmd8:	cmp	bx,ifmdf		; IF DEF?
	jne	ifcmd9			; ne = no
	jmp	ifmdef			; do further parsing below

ifcmd9:	cmp	bx,ifalarm		; IF ALARM?
	jne	ifcmd10			; ne = no
	jmp	ifalrm			; do further parsing below

ifcmd10:cmp	bx,ifequal		; IF EQUAL?
	jne	ifcmd10a		; ne = no
	jmp	ifequ			; do further parsing below
ifcmd10a:cmp	bx,iflgt		; IF LGT?
	jne	ifcmd10b		; ne = no
	jmp	ifequ
ifcmd10b:cmp	bx,ifllt		; IF LLT?
	jne	ifcmd11			; ne = no
	jmp	ifequ

ifcmd11:cmp	bx,ifless		; IF <?
	je	ifcmd12			; e = yes
	cmp	bx,ifsame		; IF =?
	je	ifcmd12
	cmp	bx,ifmore		; IF > ?
	jne	ifcmd13			; ne = no
ifcmd12:jmp	ifmath

ifcmd13:cmp	bx,ifnumeric		; IF NUMBER?
	jne	ifcmd14			; ne = no
	jmp	ifnumeric

ifcmd14:cmp	bx,ifnewer		; IF NEWER?
	jne	ifcmd17
	jmp	tstnewer		; do file newer test

ifcmd17:cmp	bx,iftrue		; IF TRUE?
	jne	ifcmd18			; ne = no
	jmp	ifcmdp			; jump to test passed code

ifcmd18:cmp	bx,ifemulation		; IF EMULATION?
	jne	ifcmdf			; ne = no
	jmp	ifcmdf			; always evaluates as False

					; Jump points for worker routines
					; failure
ifcmdf:	cmp	notflag,0		; need to apply not condition?
	jne	ifcmdp2			; ne = yes, take other exit
ifcmdf2:cmp	ifkind,1		; doing XIF command, and failed?
	jne	ifcmdf3			; ne = no
	mov	bx,offset rdbuf
	xor	dx,dx			; help
	mov	comand.cmper,1		; don't expand variables at this time
	mov	comand.cmblen,cmdblen
	mov	comand.cmcnvkind,cmcnv_crprot ; allow CR within {..}
	mov	ah,cmword		; read the success word
	call	comnd
	jc	ifcmdf3
	mov	bx,offset rdbuf		; now read ELSE
	xor	dx,dx			; help
	mov	comand.cmper,1		; don't expand variables at this time
	mov	comand.cmblen,cmdblen
	mov	ah,cmword
	call	comnd
	jc	ifcmdf3
	cmp	ax,4			; four bytes for ELSE?
	jne	ifcmdf3			; ne = no, fail outright
	mov	ax,word ptr rdbuf	; check spelling
	or	ax,2020h		; quick to lower case
	cmp	ax,'le'
	jne	ifcmdf3			; ne = spelling failure
	mov	ax,word ptr rdbuf+2
	or	ax,2020h
	cmp	ax,'es'
	jne	ifcmdf3			; ne = not present, use failure case
	jmp	ifcmdp2			; make macro of rest of line	

ifcmdf3:mov	ifelse,1		; say permit following ELSE command
	cmp	taklev,0		; in a macro/take file?
	je	ifcmdf4a		; e = not in macro/take file
	mov	bx,takadr
	test	[bx].takattr,take_while	; is this a for/while macro?
	jz	ifcmdf4a		; z = no
	mov	[bx].takcnt,0		; read nothing more from While macro
	mov	ifelse,0		; no following ELSE command

ifcmdf4a:mov	bx,offset rdbuf+2	; soak line with no echo
	xor	dx,dx			; no help
	mov	comand.cmblen,cmdblen
	mov	comand.cmkeep,0
	mov	comand.cmcnvkind,cmcnv_crprot ; allow CR within {..}
	mov	ah,cmline		; soak up rest of line
	call	comnd
ifcmdf5:clc				; force success on discard of line
	ret

					; success (pass)
ifcmdp:	cmp	notflag,0		; need to apply not condition?
	jne	ifcmdf2			; ne = yes, take other exit
ifcmdp2:mov	bx,offset rdbuf+2
	xor	dx,dx			; help
	mov	comand.cmper,1		; don't expand variables at this time
	mov	comand.cmblen,cmdblen
	mov	comand.cmcnvkind,cmcnv_crprot ; allow CR within {..}
	mov	ah,cmword		; read word into buffer
	cmp	ifkind,1		; xif?
	je	ifcmdp2a		; e = yes, read word
	mov	ah,cmline		; read line for non-XIF's
	cmp	taklev,0		; in a takefile/macro?
	je	ifcmdp2a		; e = no
	push	bx
	mov	bx,takadr
	test	[bx].takattr,take_while	; for/while?
	pop	bx
	jz	ifcmdp2a		; z = no
	mov	comand.cmkeep,1		; keep for/while open after read
ifcmdp2a:call	comnd
	jnc	ifcmdp3			; nc = success
	ret

ifcmdp3:cmp	ifkind,1		; xif?
	je	ifcmdp3d		; e = yes, no rewinding
	cmp	taklev,0		; still in a take file?
	je	ifcmdp3d		; e = no
	push	bx
	mov	al,taklev
	mov	bx,takadr
	test	[bx].takattr,take_while	; is a for/while macro active?
	jz	ifcmdp3b		; z = no, no rewind
	mov	ax,[bx].takbuf		; rewind the macro,  seg of buffer
	mov	es,ax
	mov	ax,es:[0]		; get original filling qty
	mov	[bx].takcnt,ax		; set as unread qty
	mov	[bx].takptr,2		; from offset 2
ifcmdp3b:pop	bx

ifcmdp3d:cmp	ifkind,1		; xif?
	jne	ifcmdp3a		; ne = no, have read line
	mov	ah,cmline		; read and discard rest of line
	mov	comand.cmblen,cmdblen	; discards the else <cmds> part
	inc	bx
	mov	dx,offset mskcmd	; enter any command
	mov	comand.cmcnvkind,cmcnv_crprot ; allow CR within {..}
	mov	comand.cmper,1		; don't expand variables at this time
	call	comnd

ifcmdp3a:mov	dx,offset rdbuf+2
	call	strlen			; docnv cmds which permit {,..,}
	mov	word ptr rdbuf,cx	; plant count word for docnv
	mov	ax,ds
	mov	es,ax
	mov	si,offset rdbuf		; need count word here
	cmp	ifkind,1		; XIF?
	je	ifcmdp3c		; e = yes
	mov	bx,takadr
	test	[bx].takattr,take_while	; is a for/while macro active?
	jz	ifcmdp3e		; z = no
ifcmdp3c:call	docnv			; convert macro string in place
ifcmdp3e:mov	ax,cx
	add	ax,2			; plus count word
	call	malloc			; grab memory
	mov	es,ax			; segment
	mov	di,2			; start two bytes in
	mov	si,offset rdbuf+2
	push	cx
	cld
	rep	movsb			; copy to malloc'd area
	pop	cx
	call	takopen_macro		; open a macro
	mov	bx,takadr		; point to current macro structure
	mov	ax,es			; segment of definition
	mov	[bx].takbuf,ax		; segment of definition string struc
	mov	[bx].takcnt,cx		; number of chars in definition
	mov	es:[0],cx		; original amount in buffer
	mov	[bx].takargc,0		; our argument count
	mov	[bx].takptr,2		; offset to read next command char
	or	[bx].takattr,take_malloc ; free buffer when done
	cmp	taklev,1		; at least second macro level?
	jbe	ifcmd3f			; be = ne, skip caller-testing
	push	bx
	sub	bx,size takinfo		; backup to main macro
	test	[bx].takattr,take_while	; was it a for/while loop?
	pop	bx
	jz	ifcmd3f			; z = no
	or	[bx].takattr,take_subwhile ; mark this macro as part of it
ifcmd3f:clc
	ret
IFCMD	ENDP


XIFCMD	proc near
	mov	ifkind,1		; say doing XIF command
	mov	notflag,0		; assume NOT keyword is absent
	jmp	ifcmd1			; do common code
XIFCMD	endp

; While if-condition {command, command,...}
WHILECMD proc	near
	mov	di,offset rdbuf+2
	mov	word ptr [di],'FI'
	mov	byte ptr [di+2],' '	; 'IF ' prefix
	add	di,3			; append line to prefix

while1:	mov	ah,cmkey		; parse keyword
	mov	dx,offset iftable	; table of keywords
	push	di			; save built-up string
	xor	bx,bx			; help is the table
	call	comnd
	pop	di
	jnc	while2			; nc = success
whilex:	ret				; failure
while2:	mov	temp,bx			; save keyword value
	cmp	bx,ifnot		; NOT keyword?
	jne	while3			; ne = no
	mov	word ptr [di],'ON'	; insert 'NOT '
	mov	word ptr [di+2],' T'
	add	di,4
	jmp	short while1		; and get next keyword
while3:	mov	dx,offset iftable	; table of keywords
	call	revlookup		; get cx,si for keyword text
	jc	whilex			; c = fail, should never happen
	mov	ax,ds
	mov	es,ax
	cld
	rep	movsb			; copy keyword text
	mov	al,' '			; plus a space
	stosb
	mov	bx,di			; work with bx as destination now
	xor	ch,ch	
	mov	cl,byte ptr [si+1]	; number of following arguments
	jcxz	while6			; z = none, get command

while4:	mov	comand.cmper,1		; don't expand variables here
	mov	al,byte ptr temp	; keyword value
	xor	ah,ah
	mov	si,ax
	shl	si,1
	mov	ax,seg ifhlplst		; where help text lives
	mov	es,ax
	mov	dx,es:ifhlplst[si]	; get help msg pointer
	mov	ah,cmword		; read argument word
	push	cx			; save loop counter
	call	comnd
	pop	cx
	jnc	while5
	ret
while5:	mov	byte ptr [bx],' '	; space
	inc	bx			; ready for next phrase
	loop	while4

while6:	mov	comand.cmper,1		; don't expand variables here
	mov	comand.cmblen,cmdblen
	mov	comand.cmcnvkind,cmcnv_crprot ; allow CR within {..}
	mov	dx,offset mskcmd
	mov	ah,cmline		; read whole line as command
	call	comnd
	jnc	while7
	ret
while7:	mov	ifkind,2		; say doing WHILE command
	mov	si,offset rdbuf+2
	mov	dx,si
	call	strlen			; length of final string
	mov	ax,cx
	add	ax,2+1			; plus count word plus safety
	call	malloc
	mov	es,ax			; seg
	mov	di,2			; start two bytes in
	push	cx
	cld
	rep	movsb			; copy to malloc'd area
	pop	cx
	call	takopen_macro		; open a macro
	mov	bx,takadr		; point to current macro structure
	mov	ax,es			; segment of definition
	mov	[bx].takbuf,ax		; segment of definition string struc
	mov	[bx].takcnt,cx		; number of chars in definition
	mov	es:[0],cx		; count for goto's
	mov	[bx].takargc,0		; our argument count
	mov	[bx].takptr,2		; offset to read next command char
	or	[bx].takattr,take_malloc ; free buffer when done
	or	[bx].takattr,take_while	; mark as our While loop
	clc
	ret
WHILECMD endp

; Compare errlev against user number. Jump successfully if errlev >= number.
; Worker for IF [NOT] ERRORLEVEL number <command>
ifnum	proc	near
	mov	ah,cmword		; get following number
	mov	bx,offset rdbuf
	mov	comand.cmblen,cmdblen
	mov	dx,offset ifnhlp	; help
	call	comnd
	jnc	ifnum1			; nc = success
	ret				; failure
ifnum1:	mov	domath_ptr,offset rdbuf	; text in compare buffer
	mov	domath_cnt,ax
	mov	domath_msg,1		; no error message
	call	domath			; convert to number in dx:ax
	cmp	domath_cnt,0		; converted whole word?
	je	ifnum2			; e = yes
	mov	notflag,0		; fail completely
	jmp	ifcmdf
ifnum2:	cmp	errlev,al		; at or above this level?
	jae	ifnum3			; ae = yes, succeed
	jmp	ifcmdf			; else fail
ifnum3:	jmp	ifcmdp			; jump to main command Success exit
ifnum	endp

; Compare text as number. Jump successfully if number.
ifnumeric proc	near
	mov	ah,cmword		; get following number
	mov	bx,offset rdbuf
	mov	comand.cmblen,cmdblen
	mov	dx,offset ifnhlp	; help
	call	comnd
	jnc	ifnumer1		; nc = success
	ret				; failure
ifnumer1:mov	cx,ax			; length of string
	mov	si,offset rdbuf		; where string starts
	cmp	cx,1			; more than one char?
	je	ifnumer2		; e = no
	jb	ifnumer3		; b = no chars
	lodsb				; could be +/- digits
	dec	cx
	cmp	al,'+'			; leading sign?
	je	ifnumer2		; e = acceptable
	cmp	al,'-'
	je	ifnumer2		; e = acceptable
	inc	cx			; back up to first byte
	dec	si
ifnumer2:lodsb
	cmp	al,'0'			; check for '0'..'9' as numeric
	jb	ifnumer3		; b = non-numeric
	cmp	al,'9'
	ja	ifnumer3		; a = non-numeric
	loop	ifnumer2
	jmp	ifcmdp			; jump to main command Success exit
ifnumer3:jmp	ifcmdf			; jump to main command Failure exit
ifnumeric endp

; Process IF [NOT] DEF <macro name or array element> <command>
ifmdef	proc	near
	mov	bx,offset rdbuf+2	; point to work buffer
	mov	dx,offset ifdfhlp	; help
	mov	comand.cmblen,cmdblen
	mov	ah,cmword		; get macro name
	mov	comand.cmper,1		; do not react to \%x
	mov	comand.cmarray,1	; allow sub in [..] of \&<char> arrays
	call	comnd
	jnc	ifmde1			; nc = success
	ret				; failure
ifmde1:	mov	word ptr rdbuf,ax	; store length in buffer
	cmp	word ptr rdbuf+2,'&\'	; array?
	je	ifmde20			; e = yes
	mov	bx,offset mcctab+1	; table of macro keywords
	mov	tempd,0			; tempd = current keyword
	cmp	byte ptr [bx-1],0	; any macros defined?
	je	ifmde9			; e = no, failure, exit now
					; match table keyword and user word
ifmde3:	mov	si,offset rdbuf		; pointer to user's cnt+name
	mov	cx,[si]			; length of user's macro name
	add	si,2			; point to macro name
	cmp	cx,[bx]			; compare length vs table keyword
	jne	ifmde7			; ne = not equal lengths, try another
	push	si			; lengths match, how about spelling?
	push	bx
	add	bx,2			; point at start of keyword
ifmde4:	mov	ah,[bx]			; keyword char
	mov	al,[si]			; new text char
	cmp	al,'a'			; map lower case to upper
	jb	ifmde5
	cmp	al,'z'
	ja	ifmde5
	sub	al,'a'-'A'
ifmde5:	cmp	al,ah			; test characters
	jne	ifmde6			; ne = no match
	inc 	si			; move to next char
	inc	bx
	loop	ifmde4			; loop through entire length
ifmde6:	pop	bx
	pop	si
	jcxz	ifmde10			; z: cx = 0, found the name
					; select next keyword
ifmde7:	inc	tempd			; number of keyword to test next
	mov	cx,tempd
	cmp	cl,mcctab		; all done? Recall, tempd starts at 0
	jae	ifmde9			; ae = yes, no match
	mov	ax,[bx]			; cnt (keyword length from macro)
	add	ax,4			; skip over '$' and two byte value
	add	bx,ax			; bx = start of next keyword slot
	jmp	short ifmde3		; do another comparison
ifmde9:	jmp	ifcmdf			; jump to main command Failure exit
ifmde10:jmp	ifcmdp			; jump to main command Success exit
					; arrays \&<char>[subscript]
ifmde20:cmp	rdbuf[5],'['		; size bracket?
	jne	ifmde9			; ne = no, fail
	and	rdbuf[4],not 20h	; to upper case
	mov	al,rdbuf[4]		; array name
	cmp	al,'A'			; range check
	jb	ifmde9			; b = fail
	cmp	al,'Z'
	ja	ifmde9			; a = fail
	mov	si,offset rdbuf[6]	; point at size number
	xor	ah,ah
	cld
ifmde21:lodsb
	cmp	al,']'			; closing bracket?
	je	ifmde22			; e = yes
	inc	ah			; count byte
	loop	ifmde21			; keep looking
	jmp	ifmde9			; fail if got here
ifmde22:xor	al,al
	xchg	ah,al
	sub	si,ax			; point at start of number
	dec	si
	mov	domath_ptr,si
	mov	domath_cnt,ax
	call	domath			; do string to binary dx:ax
	jnc	ifmde23			; nc = success, value is in DX:AX
	jmp	ifmde9			; fail
ifmde23:mov	bl,rdbuf[4]		; get array name letter
	sub	bl,'@'			; remove bias
	xor	bh,bh			; preserve bx til end of proc
	shl	bx,1			; address words
	mov	si,ax			; index value
	shl	si,1			; index words
	mov	ax,marray[bx]		; current array seg
	or	ax,ax			; if any
	jz	ifmde9			; z = none, not defined
	push	es
	mov	es,ax
	mov	ax,es:[0]		; get array size
	shl	ax,1			; in words
	cmp	si,ax			; index versus size
	jbe	ifmde24			; be = in bounds
	pop	es
	jmp	ifmde9			; out of bounds, not defined
ifmde24:cmp	es:[si+2],0		; any string's segment?
	pop	es
	je	ifmde9			; e = no definition
	jmp	ifmde10			; array element is defined
ifmdef	endp

; IF [not] ALARM hh:mm:ss command
ifalrm	proc	near
	call	chkkbd			; check keyboard for override
	test	status,stat_cc		; Control-C?
	jz	ifalr1			; z = no
	stc
	ret				; yes, return failure now
ifalr1:	push	word ptr timhms
	push	word ptr timhms+2	; save working timeouts
	mov	ax,word ptr alrhms
	mov	word ptr timhms,ax
	mov	ax,word ptr alrhms+2
	mov	word ptr timhms+2,ax	; set alarm value
	call	chktmo			; check for timeout
	pop	word ptr timhms+2	; restore working timeouts
	pop	word ptr timhms
	test	status,stat_tmo		; tod past user time (alarm sounded)?
	jnz	ifalr2			; nz = yes, succeed
					; failure (not at alarm time yet)
	jmp	ifcmdf			; main fail exit
					; success (at or past alarm time)
ifalr2:	jmp	ifcmdp			; main pass exit
ifalrm	endp

; IF [NOT] {LLT, EQUAL, LGT} word word command
; Permits use of \number, {string}, @filespec
ifequ	proc	near
	mov	ltype,bx		; remember kind of lex test
	mov	comand.cmblen,cmdblen
	mov	comand.cmdonum,1	; \number conversion allowed
	mov	ah,cmword		; get a word
	mov	bx,offset rdbuf		; where to store
	mov	dx,offset ifehlp	; help
	call	comnd			; ignore parse error if no text
	jc	ifequ9			; carry set means error
	or	ax,ax			; byte count
	jz	ifequ3			; z = empty word
 	mov	tempd,ax
	mov	si,offset rdbuf		; start of line
	add	si,ax
	inc	si			; skip null terminator
	mov	temptr,si		; place to start second part
	mov	bx,si
	mov	ah,cmword		; get a word of text
	mov	dx,offset ifehlp	; help
	mov	comand.cmblen,cmdblen
	mov	comand.cmdonum,1	; \number conversion allowed
	call	comnd			; ignore parse error if no text
	jc	ifequ9			; c = failure
	mov	si,temptr		; start of second line
	cmp	tempd,ax		; first longer than second?
	jae	ifequ3			; ae = yes
	xchg	tempd,ax		; use length of shorter word
ifequ3:	or	ax,ax
	jz	ifequ9			; z = empty word
	inc	ax			; include null terminator in count
	mov	cx,ax
	mov	si,offset rdbuf		; first word
	mov	di,temptr		; second word
	push	es
	mov	ax,ds
	mov	es,ax
	cld
ifequ4:	lodsb
	mov	ah,[di]
	inc	di
	cmp	script.incasv,0		; case insensitive?
	jne	ifequ5			; ne = no
	call	toupr			; to upper case
ifequ5:	cmp	al,ah
	loope	ifequ4
	pop	es
	jb	ifequ6			; exited on before condition
	ja	ifequ7			; exited on above condition

	cmp	ltype,ifequal		; wanted EQUAL condition?
	jne	ifequ9			; ne = no, fail
	jmp	ifcmdp			; else success

ifequ6:	cmp	ltype,ifllt		; LLT test?
	jne	ifequ9			; ne = no, failed
	jmp	ifcmdp			; do IF cmd success

ifequ7:	cmp	ltype,iflgt		; LGT test?
	jne	ifequ9			; ne = no, failed
	jmp	ifcmdp			; do IF cmd success

ifequ9:	jmp	ifcmdf			; do IF cmd failure
ifequ	endp

; Worker for IF [NOT] < = > var var <command>
; var is ARGC, COUNT, ERRORLEVEL, VERSION, or a 16 bit number
ifmath	proc	near
	mov	tempa,bx		; save kind of math test here
	xor	ax,ax
	mov	temp,ax			; place to store first value
	mov	temp1,ax		; place to store high word of value
	mov	tempd,ax		; count times around this loop
ifmath1:mov	bx,offset rdbuf
	mov	dx,offset ifmhlp	; help
	mov	comand.cmblen,cmdblen
	mov	ah,cmword		; get following number
	call	comnd
	jnc	ifmath2			; nc = success
	ret				; failure
ifmath2:mov	si,offset rdbuf		; put text in compare buffer
	mov	ax,[si]			; get first two user chars
	or	ax,2020h		; lowercase both bytes
	xor	dx,dx			; high word of apparent value
	cmp	ax,'ra'			; ARGC?
	jne	ifmath3			; ne = no
	xor	ax,ax
	cmp	taklev,0		; in a Take/macro?
	je	ifmath8			; e = no, report ARGC as 0
	mov	bx,takadr		; current Take structure
	mov	ax,[bx].takargc		; get argument count
	jmp	short ifmath8
ifmath3:cmp	ax,'re'			; ERRORLEVEL?
	jne	ifmath4			; ne = no
	mov	al,errlev		; get errorlevel
	xor	ah,ah
	jmp	short ifmath8
ifmath4:cmp	ax,'oc'			; COUNT?
	jne	ifmath5			; ne = no
	xor	ax,ax
	cmp	taklev,0		; in a Take/macro?
	je	ifmath8			; e = no, report COUNT as 0
	mov	bx,takadr		; current Take structure
	mov	ax,[bx].takctr		; get COUNT
	jmp	short ifmath8
ifmath5:cmp	ax,'ev'			; VERSION?
	jne	ifmath5a		; ne = no
	mov	ax,version		; get version such as 300
	jmp	short ifmath8
ifmath5a:cmp	ax,'ek'			; KEYBOARD?
	jne	ifmath6			; ne = no
	mov	ax,keyboard		; get 88 or 101 for keys on keyboard
	jmp	short ifmath8
ifmath6:mov	dx,offset rdbuf		; text in compare buffer
	call	strlen
	mov	domath_cnt,cx
	mov	domath_ptr,dx		; text in compare buffer
	call	domath			; convert to number in dx:ax
	cmp	domath_cnt,0		; converted whole word?
	je	ifmath8			; e = yes
	mov	notflag,0		; fail completely
	jmp	short ifmathf
ifmath8:cmp	tempd,0			; have second value yet?
	ja	ifmath9			; a = yes, it is in ax
	mov	temp,ax			; save first value
	mov	temp1,dx		; high order part
	inc	tempd			; say we have been here
	jmp	ifmath1			; do second argument

ifmath9:mov	bx,tempa		; kind of math test
	cmp	bx,ifless		; "<"?
	jne	ifmath10		; ne = no
	cmp	temp1,dx		; val1 < val2?
	jl	ifmathp			; b = pass
	jg	ifmathf			; a = fail
	cmp	temp,ax			; val1 < val2?
	jl	ifmathp			; b = pass
	jmp	short ifmathf		; fail
ifmath10:cmp	bx,ifsame		; "="?
	jne	ifmath11		; ne = no
	cmp	temp1,dx		; val1 = val2?
	jne	ifmathf			; ne = no, fail
	cmp	temp,ax			; val1 = val2?
	je	ifmathp			; e = yes, pass
	jmp	short ifmathf		; fail
ifmath11:cmp	temp1,dx		; val2 > val1?
	jg	ifmathp			; a = yes, pass
	jl	ifcmdf			; b = no, fail
	cmp	temp,ax			; val2 > val1?
	jg	ifmathp			; a = yes, pass
ifmathf:jmp	ifcmdf			; else fail
ifmathp:jmp	ifcmdp			; jump to main command Success exit
ifmath	endp

; IF NEWER file1 file2 
tstnewer proc	near
	mov	ah,cmword		; get first filename
	mov	bx,offset rdbuf
	mov	comand.cmblen,cmdblen
	mov	dx,offset ifnewhlp	; help
	call	comnd
	jnc	tstnew1			; nc = success
	jmp	tstnewf			; failure
tstnew1:mov	ah,cmword		; get following number
	mov	bx,offset rdbuf+65	; second file name
	mov	comand.cmblen,cmdblen
	mov	dx,offset ifnewhlp	; help
	call	comnd
	jnc	tstnew2			; nc = success
	jmp	tstnewf				; failure
tstnew2:mov	bx,offset rdbuf		; first file
	call	getfdate		; filedate to dx:ax
	jc	tstnewf			; c = fail
	mov	word ptr rdbuf,ax	; save low part
	mov	word ptr rdbuf+2,dx	; higher
	mov	bx,offset rdbuf+65	; second file
	call	getfdate		; filedate to dx:ax
	jc	tstnewf			; c = fail
	cmp	word ptr rdbuf+2,dx	; first vs second, high word
	ja	tstnewp			; a = newer, pass
	jb	tstnewf			; b = older, fail
	cmp	word ptr rdbuf,ax	; first vs second, low word
	jbe	tstnewf			; be = older, fail
tstnewp:jmp	ifcmdp			; pass
tstnewf:jmp	ifcmdf			; fail
tstnewer endp

; Return file date/time stamp in dx:ax, given ASCIIZ filename in bx
getfdate proc	near
	push	di
	push	es
	mov	dx,offset diskio.dta	; data transfer address
	mov	ah,setdma		; set disk transfer address
	int	dos
	mov	dx,bx			; for file open
	xor	cx,cx			; attributes: find only normal files
	mov	ah,first2		; DOS 2.0 search for first
	int	dos			; get file's characteristics
	pushf				; save status
	mov	ah,setdma		; restore dta
	mov	dx,offset buff
	int	dos
	popf				; get status
	pop	es
	pop	di
	jnc	getfdat1		; nc = success
	ret				; fail
getfdat1:				; time/date stamp yyyymmdd hh:mm:ss
	mov	dl,diskio.dta+25	; yyyyyyym from DOS via file open
	xor	dh,dh
	shr	dx,1			; get year
	add	dx,1980			; add bias
	mov	ax,word ptr diskio.dta+24 ; yyyyyyyym mmmddddd  year+month+day
	clc
	ret
getfdate endp

; DECREMENT/INCREMENT variable size (default size 1)
; Permits variable to be \%<char> or a macro name. Non-negative results.
decvar	proc	near
	mov	temp,'--'		; marker to say dec
	jmp	short incvar1
decvar	endp

incvar	proc	near
	mov	temp,'++'		; marker to say inc
incvar1:mov	kstatus,ksgen		; general command failure
	mov	ah,cmword		; read variable name
	mov	bx,offset rdbuf+2	; reserve word 0 for entry count
	mov	word ptr rdbuf+2,0
	mov	dx,offset chgvarhlp
	mov	comand.cmper,1		; don't react to \%x variables
	call	comnd
	jnc	incvar2			; nc = success
	ret				; failure
incvar2:or	ax,ax			; necessary macro name?
	jnz	incvar3			; nz = yes
incvar2a:stc				; no, fail
	ret
incvar3:mov	word ptr rdbuf,ax	; save length of macro name
	mov	si,offset mcctab	; table of macro names
	cld
	lodsb
	mov	cl,al			; number of macro entries
	xor	ch,ch
	jcxz	incvar2a		; z = none
					; find variable
incvar4:push	cx			; save loop counter
	lodsw				; length of macro name to ax
	mov	cx,word ptr rdbuf	; length of user's string
	cmp	ax,cx			; variable name same as user spec?
	jne	incvar6			; ne = no, no match
	push	ax
	push	si			; save these around match test
	mov	di,offset rdbuf+2	; user's string
incvar5:mov	ah,[di]
	inc	di
	lodsb				; al = mac name char, ah = user char
	and	ax,not 2020h		; clear bits (uppercase chars)
	cmp	ah,al			; same?
	loope	incvar5			; while equal, do more
	pop	si			; restore regs
	pop	ax
	jne	incvar6			; ne = no match
	pop	cx			; remove loop counter
	jmp	short incvar7		; e = match
incvar6:add	si,ax			; point to next name, add name length
	add	si,2			;  and string pointer
	pop	cx			; recover loop counter
	loop	incvar4			; one less macro to examine
	xor	ax,ax
	mov	temp,ax			; indicate failure
	jmp	incvar13		; go do command confirmation

incvar7:mov	ax,[si-2]		; get length of variable string
	add	si,ax			; point to segment of definition
	mov	si,[si]			; seg of definition
	push	es
	mov	es,si
	mov	cx,es:[0]		; length of definition
	mov	di,offset rdbuf+2	; variable name from user
	add	di,[di-2]		; plus length of variable name
	mov	byte ptr [di],' '	; <count><varname><space>
	inc	di
	mov	si,2			; skip over definition count word
incvar9:mov	al,es:[si]		; copy string to regular data segment
	mov	[di],al
	inc	si
	inc	di
	loop	incvar9
	pop	es
	mov	ax,temp			; get inc/dec +/- sign and a 1
	mov	[di],ax
	inc	di			; leave the '1' present
	push	di			; save place after '+/-'
	mov	bx,di			; optional step goes here
	mov	ah,cmword		; get step size, if any
	mov	dx,offset ssizehlp
	call	comnd
	pop	di
	jnc	incvar13
	ret
incvar13:push	di
	push	ax			; save step size string length
	mov	ah,cmeol
	call	comnd
	pop	ax
	pop	di
	jnc	incvar14		; nc = success
	ret
					; now convert step size, if any
incvar14:or	ax,ax			; is length zero?
	jnz	incvar15		; nz = no, convert number to binary
	mov	word ptr [di],'1'	; put '1' where optional is missing

incvar15:mov	di,offset rdbuf+2	; user's variable name
	add	di,[di-2]		; its length
	inc	di			; skip space separator
	push	di			; save for place to write result
	mov	dx,di
	call	strlen			; get string length
	mov	domath_cnt,cx
	mov	domath_ptr,dx
	call	domath			; convert to number in dx:ax
	cmp	domath_cnt,0		; converted whole word?
	pop	di			; clean stack
	je	incvar17		; e = yes
	stc
	ret				; fail
					; step size is in ax
incvar17:or	dx,dx			; is result negative?
	jns	incvar18		; ns = no, positive or zero
	neg	dx			; flip sign
	neg	ax
	sbb	dx,0
	mov	byte ptr [di],'-'	; show minus sign
	inc	di
incvar18:call	lnout			; binary to ascii decimal in ds:di
	mov	dx,offset rdbuf+2	; place of <var><space><value>
	call	strlen			; length to cx for dodecom
	call	dodecom			; re-define variable
	mov	kstatus,kssuc		; say success
	clc
	ret
incvar	endp

; SET ALARM <time, sec from now or HH:MM:SS>
SETALRM	PROC	NEAR
	mov	bx,offset line		; point to work buffer
	mov	word ptr line+2,0
	mov	dx,offset alrmhlp	; help
	mov	ah,cmword		; get macro name
	call	comnd
	jc	setal1			; c = failure
	mov	ah,cmeol		; get a confirm
	call	comnd
	jc	setal1			; c = failure
	push	word ptr timhms
	push	word ptr timhms+2	; save working timeouts
	mov	si,offset line		; source pointer
	call	inptim			; get the timeout time, sets si
	mov	ax,word ptr timhms	; save time in alarm area
	mov	word ptr alrhms,ax
	mov	ax,word ptr timhms+2
	mov	word ptr alrhms+2,ax
	pop	word ptr timhms+2	; restore working timeouts
	pop	word ptr timhms
	clc
setal1:	ret
SETALRM	ENDP

; MINPUT <timeout> <match text> <match text> ...<match text>
SCMINPUT PROC	NEAR
	mov	minpcnt,0		; matched pattern count
	mov	reinflg,2		; say doing MINPUT
	jmp	short input100
SCMINPUT ENDP

; REINPUT <timeout> <match text>
; Reread material in serial port buffer, seeking a match with user's text
; pattern. If user's pattern is longer than material in buffer then read
; additional characters from the serial port. Use SCINP to do the main work.

SCREINP	PROC	NEAR
	mov	reinflg,1		; say doing REINPUT, not INPUT
	jmp	short input100
SCREINP	ENDP

; Input from port command, match input with text pattern
; Input [timeout] text
;     
SCINP	PROC	NEAR
	mov	reinflg,0		; say doing INPUT, not REINPUT

input100:
	mov	kstatus,kssuc
	mov	bx,offset line+2	; place to put text
	mov	ah,cmword		; get pattern match word
	mov	dx,offset inphlp	; help message
	mov	comand.cmdonum,1	; \number conversion allowed
	cmp	reinflg,2		; MINPUT?
	je	input101		; e = yes, else INPUT or REINPUT
	mov	ah,cmline		; get time + pattern match string
input101:call	comnd			; get the pattern text
	jnc	input20			; nothing, complain
	ret				; failure
input20:mov	word ptr line,ax	; store length in preceeding word
	mov	bx,offset line+2+2	; leave a full word empty
	add	bx,ax			; skip current material
	mov	word ptr [bx-2],0	; clear for next count
	or	ax,ax			; any text?
	jnz	input21			; nz = yes
	stc				; fail
	ret
input21:mov	si,offset line+2	; source pointer
	call	inptim			; get the timeout time, sets si
	mov	bx,offset line+2	; basic line again, omitting count
	jnc	input22			; nc = got timeout, now get pattern
					; c = not legal time, must be pattern
	mov	ax,word ptr line	; get byte count
	add	bx,ax			; move bx to end + 1
	jmp	short input12		; simulate skipping inptim call

input22:cmp	reinflg,2		; MINPUT?
	je	input10			; e = yes, else INPUT or REINPUT
	push	di
	mov	di,offset line+2	; where results go
	mov	bx,si			; break char (text pattern)
	sub	bx,offset line+2	; length of time field
	mov	cx,word ptr line	; length of time + pattern
	sub	cx,bx			; cx = length of pattern
	call	cnvlin			; remove curly braces, cnv \numbers
	mov	word ptr line,cx	; length of final result
	add	di,cx			; step to end of line
	mov	word ptr [di],0		; zero count of next pattern
	pop	di
	jmp	short input13

input10:mov	kstatus,kssuc		; MINPUT, REINPUT
	mov	ah,cmword		; get pattern match word
	mov	dx,offset inphlp	; help message
	mov	comand.cmdonum,1	; \number conversion allowed
	call	comnd			; get the pattern text
	jnc	input12			; nothing, complain
	ret				; failure
input12:mov	si,bx			; terminating null
	sub	si,ax			; minus length
	mov	[si-2],ax		; store length in preceeding word
	add	bx,2			; leave a full word empty
	mov	word ptr [bx-2],0	; clear count of next element
	cmp	reinflg,2		; MINPUT?
	jne	input13			; ne = no
	or	ax,ax			; any text?
	jnz	input10			; nz = got text, get more
	mov	ah,cmeol
	call	comnd
	jnc	input13
	ret

input13:cmp	reinflg,1		; reinput command?
	je	input1a			; e = yes, don't reecho
	cmp	taklev,0		; are we in a Take file?
	je	input0			; e = no, display linefeed
	cmp	flags.takflg,0		; are Take commands being echoed?
	je	input1			; e = no, skip display
input0:	cmp	script.inecho,0		; Input echo off?
	je	input1			; e = yes
	mov	al,lf			; next line
	call	scdisp			; display the char
input1: call	serini			; initialize the system's serial port
	jnc	input1a			; nc = success
	ret
input1a:mov	status,stat_unk		; clear status flag
					; start main read and compare loop
input4:	mov	si,offset line		; <count word><pattern> sequence
	cmp	reinflg,2		; MINPUT?
	jne	input4a			; ne = no
	mov	minpcnt,0		; minput pattern match number
input4a:mov	cx,[si]			; length of pattern
	jcxz	input4d			; z = no pattern
	inc	minpcnt			; count minput pattern number
input4g:add	si,2			; point at pattern
input4c:call	inmat			; match strings
	jnc	input6			; nc = success
	add	si,cx			; skip to next pattern
	jmp	short input4a		; try again

input4d:mov	minpcnt,0		; clear \v(minput) match counter
	call	chkkbd			; check keyboard
	test	status,stat_cc		; did user type Control-C?
	jnz	input5			; nz = yes, quit
	test	status,stat_cr		; did user type cr? [js]
	jz	input4e			; z = no
	or	status,stat_tmo		; force timeout status too
	mov	input_status,1		; \v(instatus), timed out
	jmp	short input5
input4e:test	status,stat_tmo+stat_ok ; user override/timeout on last read
	jnz	input5			; nz = timed out, quit
	cmp	reinflg,1		; Reinput command?
	jne	input4f			; ne = no
	mov	ax,scpbuflen		; total buffer length
	cmp	bufcnt,ax		; full?
	jae	input5			; ae = yes, reinput fails
input4f:call	bufread			; read from serial port to buffer
	jmp	input4			; analyze character

input5:	or	errlev,ksrecv		; set RECEIVE failure condition
	or	fsta.xstatus,ksrecv	; set status
	or	kstatus,ksrecv
input6:	mov	input_status,0		; INPUT \v(instatus), assume success
	cmp	reinflg,2		; MINPUT?
	je	input6a			; e = yes
	mov	minpcnt,0		; clear \v(minput) match counter
input6a:test	status,stat_tmo		; timeout?
	jz	input7			; z = no
	mov	input_status,1		; \v(instatus), timed out
input7:	test	status,stat_cr+stat_cc	; user CR or Control-C?
	jz	input7a			; z = no
	mov	input_status,2		; \v(instatus), user Control-C
input7a:cmp	reinflg,2		; MINPUT?
	je	input7c			; e = yes
input7b:push	bx
	mov	bx,portval
	cmp	[bx].portrdy,0		; is port not-ready?
	pop	bx
	jne	input7c			; ne = no, port is ready
	mov	input_status,4		; connection lost
input7c:cmp	kstatus,kssuc		; success?
	je	input8			; e = yes
	mov	minpcnt,0		; clear \v(minput) match counter
	jmp	squit			; exit failure: timeout or Control-C
input8:	jmp	squit1			; skip timeout message, if any
inputx:	clc				; return success
	ret
SCINP	ENDP

; Match input buffer and cx string bytes at ds:si
; Strategy: scan INPUT buffer from beginning looking for match of first
; byte of pattern. If found try to match rest of pattern. Upon failure
; select next INPUT buffer byte and try to match with pattern.
inmat	proc	near
	push	cx
	push	es
	push	si
	push	di
	push	temp
	push	temp1			; buffer bytes to read
	mov	temp,cx			; retain count of pattern bytes
	mov	di,bufseg		; get buffer segment
	mov	es,di
	mov	di,bufcnt		; bytes in buffer
	cmp	reinflg,1		; Reinput command?
	je	inmat1			; e = yes, use start of buffer
	sub	di,bufrptr		; where to read-next, yields unread
	mov	temp1,di		; retain count of buffer bytes to read
	mov	di,bufrptr		; es:di is oldest unread byte
	jmp	short inmat2
inmat1:	mov	temp1,di		; retain count of bytes to read here
	xor	di,di			; reinput uses start of buffer
		; work on first pattern byte
inmat2:	cmp	temp1,cx		; unread bytes vs pattern bytes
	jb	inmatx			; b = insufficient, fail
	cld				; match first pattern byte
	mov	al,[si]			; read pattern byte into AL
	mov	cx,temp1		; buffer byte count
inmat10:mov	ah,es:[di]		; extract buffer char into AH
	inc	di
	cmp	script.incasv,0		; case ignore?
	jne	inmat13			; ne = no
	call	toupr			; upper case ax
inmat13:call	matchr			; chars match?
	jnc	inmat14			; nc = yes, first bytes match
	loop	inmat10			; continue matching
	jmp	inmatx			; failed

inmat14:	; have matched first pattern byte, now consider the rest
	push	di			; save position of to-be matched
	push	si			; save first pattern position
	inc	si			; point at second pattern byte
	mov	cx,temp			; count of pattern 
	dec	cx			; count of remaining pattern 
	jcxz	inmat17			; z = none, success
inmat15:lodsb				; pattern byte to AL
	mov	ah,es:[di]		; extract buffer char into AH
	inc	di			; point to next buffer byte
	cmp	script.incasv,0		; case ignore?
	jne	inmat16			; ne = no
	call	toupr			; upper case ax
inmat16:call	matchr			; chars match?
	jc	inmat18			; c = no
	loop	inmat15			; consider rest of pattern bytes
inmat17:cmp	reinflg,1		; Reinput command?
	je	inmat19			; e = yes, do not adjust bufrptr
	mov	bufrptr,di		; remember last read byte plus one
inmat19:pop	si
	pop	di			; success
	pop	temp1
	pop	temp
	pop	di
	pop	si
	pop	es
	pop	cx
	clc				; here match
	ret

inmat18:pop	si			; failed to match second etc bytes
	pop	di			; step along buffer stream
	mov	cx,bufcnt		; buffer count
	sub	cx,di			; minus bytes examined in buffer
	jle	inmatx			; le = none left, fail
	mov	temp1,cx		; bytes in buffer
	mov	cx,temp			; pattern bytes
	jmp	inmat2			; rescan buffer from last di

inmatx:	pop	temp1			; failure exit
	pop	temp
	pop	di
	pop	si
	pop	es
	pop	cx
	stc				; no match
	ret
inmat	endp

; worker for SCINP
; compare single characters, one in ah and the other in al. Allow the 0ffh
; wild card to match CR and LF individually. Return carry clear if match,
; or carry set if they do not match. Registers preserved.
matchr	proc	near
	cmp	ah,al		; do these match?
	je	matchr6		; e = yes
	cmp	ah,0ffh		; the match cr/lf indicator?
	je	matchr2		; e = yes	
	cmp	al,0ffh		; the match cr/lf indicator?
	jne	matchr5		; ne = no match at all.
matchr2:push	ax		; save both chars again
	and	ah,al		; make a common byte for testing
	cmp	ah,cr
	je	matchr4		; e = cr matches 0ffh
	cmp	ah,lf
	je	matchr4		; e = lf matches 0ffh
	pop	ax		; recover chars
matchr5:stc			; set carry (no match)
	ret
matchr4:pop	ax		; recover chars
matchr6:clc			; clear carry (match)
	ret
matchr	endp

; Pause for the indicated number of milliseconds, do not access comms channel
SCMPAUSE PROC	NEAR
	mov	kstatus,kssuc
	mov	ah,cmword		; get a word (number)
	mov	bx,offset line		; where to store it
	mov	dx,offset mphlp		; help msg
	call	comnd
	jnc	scmpau1			; nc = success
	ret
scmpau1:mov	dx,offset line		; text in compare buffer
	call	strlen
	mov	domath_cnt,cx
	mov	domath_ptr,dx
	call	domath			; convert to number in dx:ax
	jc	scmpau3			; c = failed to convert a number
	call	pcwait			; delay number of millisec in AX
	clc
	ret
scmpau3:mov	ah,prstr
	mov	dx,offset mpbad		; complain about bad number
	int	dos
	mov	kstatus,ksgen		; command status, failure
	stc
	ret
SCMPAUSE ENDP

; Pause for the specified number of seconds or until a time of day
; Pause [seconds or hh:mm:ss]
;
SCPAU	PROC	NEAR
	mov	kstatus,kssuc
	mov	ah,cmword		; get a word (number)
	mov	bx,offset line		; where to store it
	mov	dx,offset ptshlp	; help msg
	call	comnd
	jc	scpau1			; c = failure
	mov	si,offset line		; source pointer
	call	inptim			; parse pause time (or force default)
	jc	scpau1			; c = bad time value
	mov	wtemp,0			; no modem status to detect
	jmp	swait4			; finish in common code
scpau1:	ret				; return command failure
SCPAU	ENDP

;
; Wait for the indicated signal for the specified number of seconds or tod
; WAIT [seconds] \signal   where \signal is \cd, \dsr, \ri modem status lines.
; Use INPUT-TIMEOUT ACTION for failures.
;
SCWAIT	PROC	NEAR
	mov	kstatus,kssuc
	mov	ah,cmword		; get a word (number)
	mov	bx,offset line		; where to store it
	mov	dx,offset ptshlp	; time help msg
	call	comnd
	jnc	swait0			; nc = success
	ret
swait0:	mov	wtemp,0			; clear modem status test byte
	mov	si,offset line		; source pointer
	push	ax			; save length count
	call	inptim			; parse pause time (or force default)
	pop	ax
	jnc	swait0a			; nc = good time value
	ret
swait0a:cmp	si,offset line		; was a number parsed?
	je	swait1c			; e = no, reparse as modem signal

swait1:	mov	ah,cmword		; get optional modem signal word(s)
	mov	bx,offset line
	mov	dx,offset wthlp		; modem signal help
	call	comnd
	jnc	swait1c			; nc = success
	ret
swait1c:mov	si,offset line
	mov	cx,ax			; returned byte count
	or	cx,cx			; number of chars to examine
	jle	swait4			; le = none
	cld
swait1d:lodsb				; get a character
	dec	cx			; reduce count remaining
	cmp	al,'\'			; backslash signal introducer?
	je	swait1d			; e = yes, skip it
	cmp	cx,1			; at least two chars in signal?
	jl	swait3a			; l = no, bad syntax
	mov	ax,[si-1]		; get first two characters
	or	ax,2020h		; upper case to lower, two chars
	cmp	ax,'dc'			; carrier detect?
	jne	swait2			; ne = no, try next signal
	or	wtemp,modcd		; look for the CD bit
	inc	si			; skip this field and separator
	dec	cx			; two less chars left in the line
	jmp	short swait1		; continue the scan
swait2:	cmp	ax,'sd'			; data set ready?
	jne	swait3			; ne = no
	mov	al,[si+1]		; third letter
	or	al,20h			; to lower case
	cmp	al,'r'			; r for dsr?
	jne	swait3b			; ne = no
	or	wtemp,moddsr		; look for the DSR bit
	add	si,2			; skip this field and separator
	sub	cx,2			; three less chars left in the line
	jmp	short swait1
swait3:	cmp	ax,'tc'			; clear to send?
	jne	swait3a			; ne = no
	mov	al,[si+1]		; third letter
	or	al,20h			; to lower case
	cmp	al,'s'			; r for dsr?
	jne	swait3b			; ne = no
	or	wtemp,modcts		; look for the CTS bit
	add	si,2			; skip this field and separator
	sub	cx,2			; three less chars left in the line
	jmp	short swait1		; continue the scan
swait3a:cmp	ax,'ir'			; ring indicator
	jne	swait3b			; ne = no, try next signal
	or	wtemp,modri		; look for the RI bit
	inc	si			; skip this field and separator
	dec	cx			; two less chars left in the line
	jmp	short swait1		; continue the scan
swait3b:or	al,al			; null terminator?
	je	swait4			; e = yes, no more text
	mov	ah,prstr
	mov	dx,offset wtbad		; say bad syntax
	int	dos
	or	errlev,ksuser		; set user intervention error condx
	or	fsta.xstatus,ksuser	; set status
	or	kstatus,ksuser
	stc				; failure
	ret
					; SWAIT4 is used by PAUSE command
SWAIT4:	mov	ah,cmeol		; get command confirmation
	call	comnd
	jnc	swait4a
	ret				; c set is failure
swait4a:cmp	taklev,0		; are we in a Take file
	je	swait5			; e = no, print linefeed
	cmp	flags.takflg,0		; are commands being echoed
	je	swait6			; e = no, skip this
swait5:	cmp	script.inecho,0		; Input echoing off?
	je	swait6			; e = yes
	mov	al,lf			; next line
	call	scdisp			; display the char
swait6: call	serini			; initialize the system's serial port
	jc	swait9			; c = failure
	mov	status,stat_unk		; clear status flag
	push	si
	mov	parmsk,0ffh	  	; parity mask, assume 8 bit data
	mov	si,portval
	cmp	[si].parflg,parnon	; parity is none?
	pop	si
	je	swait7			; e = none
	mov	parmsk,07fh		; else strip parity (8th) bit
swait7:	cmp	wtemp,0			; anything to be tested?
	je	swait8			; e = no, just do the wait part
	call	getmodem		; modem handshake status to AL
	and	al,wtemp		; keep only bits to be tested
	cmp	al,wtemp		; check selected status bits
	jne	swait8			; ne = not all selected bits match	
	clc				; all match. take successful exit
	ret
swait8:	call	chkport			; get and show any new port char
	call	chkkbd			; check keyboard
	test	status,stat_cc		; control-c?
	jnz	swait9			; nz = yes, quit	
	call	chktmo			; check tod for timeout
	test	status,stat_tmo+stat_ok	; timeout or user override?
	jz	swait7			; z = no, continue to wait
	cmp	wtemp,0			; were we waiting on anything?
	jne	swait9			; ne = yes, timeout = failure
	test	status,stat_ok		; user intervention?
	jnz	swait9			; nz = yes, failure
	clc				;  else timeout = success
	ret
swait9:	or	errlev,ksuser		; set user intervention error condx
	or	fsta.xstatus,ksuser	; set status
	or	kstatus,ksuser
	jmp	squit			; take error exit
SCWAIT	ENDP

; SLEEP <number of sec or time of day>
; Does not access comms channels
SCSLEEP	PROC	NEAR
	mov	kstatus,kssuc
	mov	ah,cmword		; get a word (number)
	mov	bx,offset line		; where to store it
	mov	dx,offset sleephlp	; help msg
	call	comnd
	jc	scslee1			; c = failure
	mov	si,offset line		; source pointer
	call	inptim			; parse pause time (or force default)
	jnc	scslee2			; nc = good time value
scslee1:ret				; return command failure
scslee2:call	chkkbd			; check keyboard
	test	status,stat_cc		; control-c?
	jnz	scslee3			; nz = yes, quit	
	call	chktmo			; check tod for timeout
	test	status,stat_tmo+stat_ok	; timeout or user override?
	jz	scslee2			; z = no, continue to wait
	test	status,stat_ok		; user intervention?
	jnz	scslee3			; nz = yes, failure
	clc				;  else timeout = success
	ret
scslee3:or	errlev,ksuser		; set user intervention error condx
	or	fsta.xstatus,ksuser	; set status
	or	kstatus,ksuser
	jmp	squit			; take error exit
SCSLEEP	ENDP

; Output line of text to port, detect \b and \B as commands to send a Break
;  and \l and \L as a Long Break on the serial port line.
; Output text, display up to 100 received chars while doing so.
     
SCOUT	PROC	NEAR
	mov	kstatus,kssuc
	mov	ah,cmline		; get a whole line of asciiz text
	mov	bx,offset line		; store text here
	mov	dx,offset outhlp	; help message
	mov	comand.cmdonum,1	; \number conversion allowed
	call	comnd
	jnc	outp0d			; nc = success
	ret				; failure
outp0d:	mov	tempd,ax		; save byte count here
	cmp	apctrap,0		; disable from APC?
	je	outp0e			; e = no
	stc				; fail
	ret
outp0e:	cmp	taklev,0		; is this being done in a Take file?
	je	outpu0			; e = no, display linefeed
	cmp	flags.takflg,0		; are commands being echoed?
	je	outp0a			; e = no, skip the display
outpu0:	cmp	script.inecho,0		; Input echoing off?
	je	outp0a			; e = yes
	mov	al,lf			; next line
	call	scdisp			; display the char
outp0a:	mov	al,spause		; wait three millisec or more
	add	al,3
	xor	ah,ah
	call	pcwait			; breathing space for HDX systems
	call	serini			; initialize the system's serial port
	jnc	outp0c			; nc = success
	or	errlev,kssend		; set SEND failure condition
	or	fsta.xstatus,kssend	; set status
	or	kstatus,kssend
	jmp	squit

outp0c:	mov	status,stat_unk		; clear status flag
	mov	parmsk,0ffh	  	; parity mask, assume 8 bit data
	mov	si,portval
	cmp	[si].parflg,parnon	; parity is none?
	je	outp0b			; e = none
	mov	parmsk,07fh		; else strip parity (8th) bit
outp0b:	mov	si,portval		; serial port structure
	mov	bl,[si].ecoflg		; Get the local echo flag
	mov	lecho,bl		; our copy
	mov	temptr,offset line	; save pointer here
	mov	ttyact,1		; say interactive style output

outpu2:	cmp	tempd,0			; are we done?
	jg	outpu2a			; g = not done yet
	mov	ttyact,0		; reset interactive output flag
	clc				; return success
	ret
outpu2a:mov	si,temptr		; recover pointer
	cld
	lodsb				; get the character
	dec	tempd			; one less char to send
	mov	temptr,si		; save position on line
	mov	byte ptr tempa,al	; save char here for outchr
	mov	retry,0			; number of output retries
	cmp	al,5ch			; backslash?
	jne	outpu4d			; ne = no
	mov	al,[si]
	and	al,not 20h		; to upper case
	cmp	al,'B'			; "\B" for BREAK?
	jne	outpu4l			; ne = no
outpu4c:inc	temptr			; move scan ptr beyond "\b"
	dec	tempd
	call	sendbr			; call msx send-a-break procedure
	jmp	short outpu5		; resume beyond echoing
outpu4l:cmp	al,'L'			; "\L" for Long BREAK?
	jne	outpu4g			; ne = no
	inc	temptr
	dec	tempd
	call	sendbl			; send a Long BREAK
	jmp	short outpu5		; resume beyond echoing

outpu4d:inc	retry			; count output attempts
	cmp	retry,maxtry		; too many retries?
	jle	outpu4g			; le = no
	or	errlev,kssend		; set SEND failure condition
	or	fsta.xstatus,kssend	; set status
	or	kstatus,kssend
	jmp	squit			; return failure
outpu4g:
	mov	ax,outpace		; millisecs pacing delay
	inc	ax			; at least 1 ms
	call	pcwait
	mov	ah,byte ptr tempa	; outchr gets fed from ah
	call	outchr			; send the character to the port
	jc	outpu4d			; failure to send char
	cmp	lecho,0			; is Local echo active?
	je	outpu5			; e = no
	mov	al,byte ptr tempa
	test	flags.capflg,logses	; is capturing active?
	jz	outp4b			; z = no
	push	ax			; save char
	call	cptchr			; give it captured character
	pop	ax			; restore character and keep going
outp4b:	cmp	script.inecho,0		; Input echo off?
	je	outpu5			; e = yes
	call	scdisp			; echo character to the screen
					;
outpu5:	mov	tempa,100+1		; wait for max 100 chars in/out [dan]
outpu5a:mov	cx,10			; reset retry counter
outpu5b:push	cx
	call	chkkbd			; check keyboard for interruption
	pop	cx
	test	status,stat_cc		; control c interrupt?
	jnz	outpu6			; nz = yes, quit now
	cmp	script.inecho,0		; Input echo off?
	je	outpu5c			; e = yes, skip port reading/display
	dec	tempa			; reached maximum chars in yet? [dan]
	jz	outpu5c			; z = yes, send character anyway [dan]
	push	cx
	call	chkport			; check for char at serial port
	pop	cx
	test	status,stat_ok		;   and put any in buffer
	jnz	outpu5a			; nz = have a char, look for another
	mov	ax,1			; wait 1 millisec between rereads
	push	cx			; protect counter
	call	pcwait
	pop	cx
	dec	cx			; count down retries
	jge	outpu5b			; ge = keep trying
outpu5c:jmp	outpu2			; no more input, resume command
outpu6:	or	errlev,kssend		; set SEND failure condition
	or	fsta.xstatus,kssend	; set status
	or	kstatus,kssend
	mov	ttyact,0		; reset interactive output flag
	jmp	squit			; quit on control c
SCOUT	ENDP

; OUTPUT  ESC _ usertext ESC \   as APC command
SCAPC	PROC	NEAR
	mov	kstatus,kssuc
	mov	ah,cmline		; get a whole line of asciiz text
	mov	bx,offset line+2	; store text here
	mov	byte ptr[bx-2],ESCAPE	; ESC _ (APC)
	mov	byte ptr [bx-1],'_'
	mov	dx,offset apchlp	; help message
	call	comnd
	jnc	spapc1			; nc = success
	ret				; failure
spapc1:	mov	bx,ax			; user text
	add	bx,2			; prefix
	mov	line [bx],ESCAPE	; ESC \ (ST)
	mov	line [bx+1],'\'
	mov	line [bx+2],0		; terminator
	mov	al,script.inecho	; preserve echo status
	mov	ah,flags.takflg
	push	ax
	mov	script.inecho,0		; off
	mov	flags.takflg,0		; off
scapc2:	call	outp0a			; do work via OUTPUT
	pop	ax
	mov	script.inecho,al	; restore
	mov	flags.takflg,ah
	ret
SCAPC	ENDP
     
; Raw file transfer to host (strips linefeeds)
; Transmit filespec [prompt]
; Optional prompt is the single char expected from the host to ACK each line.
; Default prompt is a script.xmitpmt (linefeed) or a carriage return from us.
;     
SCXMIT	PROC	NEAR
	mov	kstatus,kssuc
	mov	ah,cmword		; get a filename, asciiz
	mov	bx,offset line		; where to store it
	mov	dx,offset xmthlp	; help message
	call	comnd
	jnc	xmit0c			; nc = success
	ret				; failure
xmit0c:	mov	ah,cmword		; get a prompt string, asciiz
	mov	bx,offset line+81	; where to keep it (end of "line")
	mov	dx,offset pmthlp	; Help in case user types "?".
	mov	comand.cmdonum,1	; convert \number
	call	comnd
	jnc	xmit0d			; nc = success
	ret				; failure
xmit0d:	mov	line+80,al		; length of user's string
	mov	ah,cmeol		; confirm
	call	comnd
	jnc	xmit0e
	ret
xmit0e:	cmp	line,0			; filename given?
	je	xmit0a			; e = no
	cmp	line+80,0		; anything given?
	jz	xmit0			; z = no, use default
	mov	al,line+81		; get ascii char from user's prompt
xmit0b:	mov	script.xmitpmt,al	; set prompt
xmit0:	mov	dx,offset line		; point to filename
	mov	ah,open2		; DOS 2 open file
	xor	al,al			; open for reading
	int	dos
	mov	fhandle,ax		; store file handle here
	mov	temp,0			; counts chars/line
	jnc	xmit1			; nc = successful opening

xmit0a:	mov	ah,prstr		; give file not found error message
	mov	dx,offset xfrfnf
	int	dos
	or	errlev,kssend		; set SEND failure condition
	or	fsta.xstatus,kssend	; set status
	or	kstatus,kssend
	jmp	squit			; exit failure

xmitx:	mov	ah,prstr		; error during transfer
	mov	dx,offset xfrrer
	int	dos
xmitx2:	mov	bx,fhandle		; file handle
	mov	ah,close2		; close file
	int	dos
	mov	bufcnt,0		; clear INPUT buffer (say is empty)
	call	clrbuf			; clear local serial port buffer
	or	errlev,kssend		; set SEND failure condition
	or	fsta.xstatus,kssend	; set status
	or	kstatus,kssend
	jmp	squit			; exit failure
					;
xmity:	mov	bx,fhandle		; file handle
	mov	ah,close2		; close file
	int	dos
	mov	bufcnt,0		; clear INPUT buffer (say is empty)
	call	clrbuf
	clc				; and return success
	ret
xmit1:	call	serini			; initialize serial port
	jnc	xmit1b			; nc = success
	or	errlev,kssend		; set SEND failure condition
	or	fsta.xstatus,kssend	; set status
	or	kstatus,kssend
	jmp	squit

xmit1b:	mov	bufcnt,0		; clear INPUT buffer (say is empty)
	mov	bufrptr,0
	call	clrbuf			; clear serial port buffer
	mov	status,stat_unk		; clear status flag
	mov	parmsk,0ffh	  	; parity mask, assume 8 bit data
	mov	si,portval
	cmp	[si].parflg,parnon	; parity is none?
	je	xmit1a			; e = none
	mov	parmsk,07fh		; else strip parity (8th) bit
xmit1a:	mov	bl,[si].ecoflg		; get the local echo flag
	mov	lecho,bl		; our copy
	mov	dx,offset crlf		; display cr/lf
	mov	ah,prstr
	int	dos

xmit2:	mov	dx,offset line		; buffer to read into
	mov	cx,linelen		; # of bytes to read
	mov	ah,readf2		; read bytes from file
	mov	bx,fhandle		; file handle is stored here
	int	dos
	jnc	xmit2a			; nc = success
	jmp	xmitx			; exit failure
xmit2a:	mov	cx,ax			; number of bytes read
	jcxz	xmity			; z = none, end of file
	mov	si,offset line		; buffer for file reads
	cld
xmit3:	lodsb				; get a byte
	cmp	al,ctlz			; is this a Control-Z?
	jne	xmit3a			; ne = no
	cmp	flags.eofcz,0		; ignore Control-Z as EOF?
	je	xmit3a			; e = yes
	jmp	xmity			; ne = no, we are at EOF
xmit3a:	push	si			; save position on line
	push	cx			; and byte count
	cmp	al,cr			; CR, end of line?
	jne	xmit3b			; ne = no
	cmp	temp,0			; chars sent in this line, any?
	ja	xmit3c			; a = sent some
	cmp	script.xmitfill,0	; fill empty lines?
	je	xmit3c			; e = no, send the cr
	mov	al,script.xmitfill	; empty line fill char
	pop	cx
	pop	si
	dec	si			; backup read pointer to CR again
	inc	cx			; count filler as line information
	push	si
	push	cx
	jmp	short xmit3c
xmit3b:	cmp	al,lf			; line feed?
	jne	xmit3c			; ne = no
	cmp	script.xmitlf,0		; send LF's?
	je	xmit7			; e = no, don't send it
	mov	temp,-1			; -1 so inc returns 0 after send
xmit3c:	push	ax			; save char around outchr call
	mov	retry,0			; clear retry counter
xmit4f:	pop	ax			; recover saved char
	push	ax			; and save it again
	mov	ah,al			; outchr wants char in ah
	inc	retry			; count number of attempts
	cmp	retry,maxtry		; too many retries?
	jle	xmit4g			; le = no
	or	status,stat_cc		; simulate control-c abort
	pop	ax			; clean stack
	xor	al,al			; clear char
	jmp	xmita			; and abort transfer
xmit4g:	push	ax			; save char
	call	outchr			; send the character to the port
	pop	ax			; recover char
	pushf				; save carry flag
	cmp	flags.comflg,'t'	; using internal TCP/IP stack?
	jne	xmit4j			; ne = no
	mov	al,ah			; ah is the output byte
	call	dopar			; apply parity to al, if any
	cmp	al,0ffh			; IAC now?
	jne	xmit4j			; ne = no
	call	outchr			; double the IAC byte
xmit4j:	inc	temp			; count chars sent in this line
	popf				; recover carry flag
	jc	xmit4f			; c failed, try again
xmit4h:	pop	ax			; recover saved char
	cmp	lecho,0			; is local echoing active?
	je	xmit5			; e = no
	test	flags.capflg,logses	; capturing active?
	jz	xmit4a			; z = no
	call	cptchr			; give it the character just sent
xmit4a:	call	scdisp			; display char on screen

xmit5:	cmp	al,cr			; did we send a carriage return?
	je	xmit8			; e = yes, time to check keyboard

xmit7:	pop	cx
	pop	si
	dec	cx
	or	cx,cx
	jle	xmit7a			; le = finished this line
	jmp	xmit3			; finish this buffer full
xmit7a:	jmp	xmit2			; read next buffer

xmit8:	test	status,stat_cc		; Control-C seen?
	jnz	xmita			; nz = yes
	mov	temp,0			; say starting new char/line count
	call	chkkbd			; check keyboard (returns char in al)
	test	status,stat_ok		; have a char?
	jnz	xmita			; nz = yes
	cmp	script.xmitpmt,0	; is prompt char a null?
	jne	xmit8b			; ne = no
	mov	bufcnt,0		; clear serial port buf
	call	bufread			; check for char from serial port buf
	jnc	xmit8			; nc = a char, read til none
	jmp	short xmit8c		; continue transfer
xmit8b:	mov	bufcnt,0		; clear serial port buf
	call	bufread			; check for char from serial port buf
	jc	xmit8			; c = none
	cmp	al,script.xmitpmt	; is port char the ack?
	jne	xmit8			; ne = no, just ignore the char
xmit8c:	mov	ax,script.xmitpause	; get millisecs to pause
	or	ax,ax			; any time?
	jz	xmit7			; z = none
	call	pcwait			; wait this long
	jmp	short xmit7		; yes, continue transfer

xmita:	test	status,stat_cc		; Control-C?
	jnz	xmitc			; nz = yes
	test	status,stat_cr		; a local ack?
	jz	xmit8			; z = no, ignore local char
	mov	dx,offset crlf		; display cr/lf
	mov	ah,prstr
	int	dos
	jmp	xmit8c			; continue transfer
xmitc:	pop	cx			; Control-C, clear stack
	pop	si			; ...
	mov	dx,offset xfrcan	; say canceling transfer
	mov	ah,prstr
	int	dos
	mov	flags.cxzflg,0		; clear Control-C flag
	jmp	xmitx2			; ctrl-c, quit

SCXMIT	ENDP

;
; Squit is the script error exit pathway.
;
squit:	cmp	flags.cxzflg,'C'	; Control-C interrupt seen?
	je	squit5			; e = yes
	test	status,stat_tmo		; timeout?
	jz	squit2			; z = no, another kind of failure
	cmp	taklev,0		; in a Take/macro?
	jne	squit1			; ne = yes, skip timeout message
	push	dx
	mov	dx,offset tmomsg	; say timed out
	mov	ah,prstr
	int	dos			; display it
	pop	dx
squit1:	cmp	script.inactv,0		; action to do upon timeout
	je	squit4			; 0 = proceed, ne = non-zero = quit
squit5:	call	takclos			; close Take file or macro
squit2:	call	isdev			; stdin is a device (vs file)?
	jc	squit3			; c = device, not a file
	mov	flags.extflg,1		; set Kermit exit flag
squit3:	cmp	flags.cxzflg,'C'	; Control-C interrupt seen?
	jne	squit6			; ne = no
	or	kstatus,ksuser		; say user intervention
squit6:	stc
	ret				; return failure
squit4:	clc				; return success, ignore error
	ret
code	ends

code1	segment
	assume	cs:code1

;;;;;;;;;;;;;;;;;; local support procedures ;;;;;;;;;;
; Find line starting just after ":label". Label is in variable LINE
; (length in slablen). Readjust Take read pointer to start of that line.
; Performs file search from beginning of file, popping up levels if req'd.
; Exit carry clear if success, carry set otherwise. Local worker routine.
; Leaves  command.cmkeep,1 persistent, so be careful.
getto	proc	FAR
	push	bx			; global save of bx
gett0:	mov	comand.cmkeep,1		; keep Take file open after this call
	mov	bx,takadr
	cmp	[bx].taktyp,take_file	; get type of take (a file?)
	jne	gett2			; ne = no, a macro
	cmp	forward,0		; GOTO?
	jne	gett1			; ne = no, FORWARD, do not rewind
					; scan from start of Take file
	mov	word ptr [bx].takseek,0
	mov	word ptr [bx].takseek+2,0 ; seek distance, bytes
gett1:	call	takrd			; get a line
	mov	bx,takadr		; restore bx to working value
	jmp	short gett4
					; Take a Macro
gett2:	mov	cx,[bx].takbuf		; segment of macro definition
	push	es
	mov	es,cx
	mov	cx,es:[0]		; get string length byte
	pop	es
	mov	[bx].takcnt,cx		; set unread to full buffer (rewind)
	mov	[bx].takptr,2		; set read pointer to start of text

gett4:	call	getch			; get a character
	jc	gett14			; c = end of file, no char
	cmp	al,' '			; leading white space?
	je	gett4			; e = yes, read again
	cmp	al,TAB			; this kind of whitespace?
	je	gett4			; e = yes
	cmp	al,':'			; start of label?
	je	gett8			; e = yes
gett6:	cmp	al,CR			; end of line?
	je	gett4			; e = yes, seek colon for label
	call	getch			; get a character
	jc	gett14			; c = end of file, no char
	jmp	short gett6		; read until end of line

gett8:	mov	si,offset line		; label to search for
	mov	cx,slablen		; its length
	jcxz	gett12			; no chars to match
	cmp	byte ptr[si],':'	; user label starts with colon
	jne	gett10			; ne = no
	inc	si			; skip user's colon
	dec	cx
	jcxz	gett12			; no chars to match
gett10:	call	getch			; read file char into al
	jc	gett14			; c = end of file
	mov	ah,al
	cld
	lodsb
	call	tolowr			; convert al and ah to lower case
	cmp	al,ah			; match?
	jne	gett6			; ne = no, goto end of line
	loop	gett10			; continue matching
					; match obtained
	call	getch			; read next file character
	jc	gett13			; c = end of file, no char
	cmp	al,' '			; separator?
	je	gett12			; e = yes, unique label found
	cmp	al,TAB			; this kind of separator?
	je	gett12			; e = yes
	cmp	al,CR			; or end of line?
	je	gett13			; e = yes
	jmp	gett6			; not correct label, keep reading

gett12:	call	getch			; read past end of line
	jc	gett13			; c = end of file, no char
	cmp	al,CR			; end of line character?		
	jne	gett12			; ne = no, keep reading
gett13: pop	bx
	clc				; return carry clear
	ret				; Take pointers are ready to read line
					; failed to find label, pop a level
gett14:	cmp	forward,2		; SWITCH?
	jne	gett14a			; ne = no
	pop	bx
	stc				; set carry for failure
	ret
gett14a:call	takclos			; close this macro/take file
	cmp	taklev,0		; still in macro/take?
	je	gett15			; e = no, quit
	jmp	gett0			; try next level up
gett15:mov	ah,prstr		; say label not found
	mov	dx,offset laberr	; first part of error message
	int	dos
	mov	dx,offset line
	cmp	line,':'		; label starts with ":"?
	jne	gett16			; ne = no
	inc	dx			; yes, skip it
gett16:	call	prtasz			; print asciiz string
	mov	ah,prstr
	mov	dx,offset laberr2	; trailer of error message
	int	dos
gett20:	pop	bx
	mov	kstatus,ksgen		; command status, failure
	stc				; set carry for failure
	ret
getto	endp

; Read char from Take buffer. Returns carry clear and char in al, or if end
; of file returns carry set. Enter with BX holding takadr. Local worker.
getch	proc	near
	cmp	[bx].takcnt,0		; buffer empty?
	jg	getch2			; g = no
	cmp	[bx].taktyp,take_file	; file?
	jne	getch1			; ne = no, a macro
	call	takrd			; read another buffer
	cmp	[bx].takcnt,0		; end of file?
	jne	getch2			; ne = no
getch1:	stc				; e = yes, exit error
	ret
getch2:	push	si
	push	es
	mov	es,[bx].takbuf		; segment of buffer
	mov	si,[bx].takptr		; read a char from Take buffer
	mov	al,es:[si]
	inc	si
	mov	[bx].takptr,si		; move buffer pointer
	dec	[bx].takcnt		; decrease number of bytes remaining
	pop	es
	pop	si
	clc				; return carry clear
	ret
getch	endp

; worker: read the number of seconds to pause or timeout
;    returns time of day for timeout in timhms, and next non-space or
;    non-tab source char ptr in si. Time is either elapsed seconds or
;    a specific hh:mm:ss, determined from context of colons being present.
;    Last form can be abbreviated as hh:[mm[:ss]]. Returns carry set if
;    hh:mm:ss form has bad construction (invalid time).
inptim	proc	far
	push	ax
	push	bx
	push	cx
	push	dx
	push	di
	cld				; decode pure seconds construction
	mov	di,si			; remember source pointer
	mov	cx,10			; multiplier
	mov	bx,script.indfto	; no numbers yet, use default-timeout
	mov	al,byte ptr[si]
	cmp	al,':'			; stray hh:mm:ss separator?
	je	inptm8			; e = yes
	cmp	al,'9'			; start with numeric input?
	ja	inptm4			; a = no, use default time
	cmp	al,'0'			; ditto
	jb	inptm4
	xor	ah,ah			; source char holder
	xor	bx,bx			; accumulated sum
inptm1:	mov	al,byte ptr[si]		; get a byte into al
	cmp	al,':'			; hh:mm:ss construction?
	je	inptm8			; e = yes
	sub	al,'0'			; remove ascii bias
	cmp	al,9			; numeric?
	ja	inptm4			; a = non-numeric, exit loop, bx = sum
	xchg	ax,bx			; put sum into ax, char in bl
	mul	cx			; sum times ten 
	xchg	ax,bx			; put char into al, sum in bx
	add	bx,ax			; add to sum
	inc	si			; next char
	jmp	short inptm1		; loop thru all chars

inptm4:	cmp	bx,12*60*60		; half a day, in seconds
	jb	inptm5			; b = less than
	jmp	inptm13			; more than, error
inptm5:	push	si			; save ending scan position for return
	mov	timout,bx		; # seconds of timeout desired
	mov	ah,gettim		; read DOS tod clock
	int	dos
	mov	timhms[0],ch		; hours
	mov	timhms[1],cl		; minutes
	mov	timhms[2],dh		; seconds
	mov	timhms[3],dl		; hundredths of seconds
	mov	bx,2			; start with seconds field
inptm6: mov	ax,timout		; our desired timeout interval
	add	al,timhms[bx]		; add current tod digit to interval
	adc	ah,0
	xor	dx,dx			; clear high order part thereof
	mov	cx,60			; divide by 60
	div	cx			; compute number of minutes or hours
	mov	timout,ax		; quotient
	mov	timhms[bx],dl		; put remainder in timeout tod digit
	dec	bx			; look at next higher order time field
	or	bx,bx			; done all time fields?
	jge	inptm6			; ge = no
	cmp	timhms[0],24		; normalize hours
	jl	inptm7			; l = not 24 hours
	sub	timhms[0],24		; discard part over 24 hours
inptm7:	pop	si			; return ptr to next source char
	jmp	short inptm11		; trim trailing whitespace

inptm8:					; decode hh:[mm[:ss]] to timhms
	mov	si,di			; recall starting source pointer
	mov	word ptr timhms[0],0	; clear time out tod
	mov	word ptr timhms[2],0
	xor	bx,bx			; three groups possible
inptm9:	mov	dl,byte ptr[si]		; get a char
	cmp	dl,':'			; field separator?
	je	inptm10			; e = a separator, step fields
	sub	dl,'0'			; remove ascii bias
	cmp	dl,9
	ja	short inptm11		; a = failure to get expected digit
	mov	al,timhms[bx]		; get sum to al
	mov	ah,10
	mul	ah			; sum times ten
	add	al,dl			; sum = 10 * previous + current
	mov	timhms[bx],al		; current sum
	cmp	timhms[bx],60		; more than legal?
	jae	inptm13			; ae = illegal
	or	bx,bx			; doing hours?
	jnz	inptm9a			; nz = no, min or sec
	cmp	timhms[bx],24		; more than legal?
	jae	inptm13			; ae = illegal
inptm9a:inc	si			; next char
	jmp	short inptm9		; continue analysis
inptm10:inc	bx			; point to next field
	inc	si			; next char
	cmp	bx,2			; last subscript to use (secs)
	jbe	inptm9			; be = get more text

inptm11:cmp	byte ptr [si],spc	; examine break char, remove spaces
	jne	inptm12			; ne = no, stay at this char
	inc	si			; look at next char
	jmp	short inptm11		; continue scanning off white space
inptm12:clc				; carry clear for success	
	jnc	inptm14
inptm13:stc				; carry set for illegal value	
inptm14:pop	di			; return with si beyond our text
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
inptim	endp

; Read comms line, put most recent byte into buffer, 
; and into reg AL as a side effect used by scxmit.
bufread	proc	far
	call	chkport			; get any oldest char from port
	call	chktmo			; check tod for timeout
	cmp	bufcnt,0		; empty buffer?
	jne	bufrd1			; ne = no
	stc				; yes, set carry flag (no char)
	ret				; and quit (chkport sets status)

bufrd1:	clc				; clear carry flag (have a char)
	ret				; chkport sets status
bufread	endp

; Write byte AL to buffer. Manipulates bufcnt and bufrptr. Buffer is linear.
bufwrite proc	far
	push	ax
	push	si
	push	di
	push	es
	mov	si,bufseg		; segment of buffer
	mov	es,si
	mov	si,bufcnt		; buffer count
	cmp	si,scpbuflen		; filled?
	jb	bufwt2			; b = no
	push	ds			; save DS
	mov	di,bufseg
	mov	ds,di
	mov	cx,si			; count of bytes to be moved
	dec	cx			; leave a hole
	xor	di,di			; destination is at beginning
	mov	si,di
	inc	si			; source is one forward
	cld				; copy forward
	rep	movsb			; copy down the buffer contents
	pop	ds
	dec	bufcnt			; one hole left
	cmp	bufrptr,0		; is read pointer at start?
	je	bufwt1			; e = yes
	dec	bufrptr			; move it down too
bufwt1:	mov	si,bufcnt
bufwt2:	mov	es:[si],al		; store char held in al
	inc	bufcnt			; say have added a char to the buf
	pop	es
	pop	di
	pop	si
	pop	ax
	ret
bufwrite endp

; Report buffer status for dumping buffer to a log file.
; Yield ax, cx, es, si as indicated below.
buflog	proc	far
	mov	si,bufseg			; segment of buffer
	mov	es,si
	xor	si,si				; start of buffer
	mov	cx,bufcnt			; number of chars in buffer
	cmp	cx,cmdblen-1			; longer than command buffer?
	ja	buflog1				; a = yes, trim
	ret					; return these registers
buflog1:mov	si,cx				; ending offset
	mov	cx,cmdblen-1
	sub	si,cx				; starting offset
	ret
buflog	endp

; worker: check for timeout, return status=stat_tmo if timeout, else bit
;  stat_tmo is cleared.
chktmo	proc	far
	push	ax
	push	cx
	push	dx
	and	status,not stat_tmo
	mov	ah,gettim		; get the time of day
	int	dos
	sub	ch,timhms[0]		; hours difference, ch = (now-timeout)
	je	chktmo2			; e = same, check mmss.s
	jg	chktmo1			; g = past target hour
	add	ch,24			; we are early, see by how much
chktmo1:cmp	ch,12			; hours difference, large or small?
	jge	chktmox			; ge = not that time yet
	jl	chktmo3			; l = beyond that time
chktmo2:cmp	cl,timhms[1]		; minutes, hours match
	jb	chktmox			; b = early
	ja	chktmo3			; a = late
	cmp	dh,timhms[2]		; seconds, hhmm match
	jb	chktmox			; b = early
	ja	chktmo3			; a = late
	cmp	dl,timhms[3]		; fractions, hhmmss match
	jb	chktmox			; b = early
chktmo3:or	status,stat_tmo		; say timeout
	pop	dx
	pop	cx
	pop	ax
	stc
	ret
chktmox:pop	dx
	pop	cx
	pop	ax
	clc
	ret
chktmo	endp
;
; worker: check keyboard for char. Return status = stat_cc if control-C typed,
; stat_cr if carriage return, or stat_ok if any other char typed. Else return
; with these status bits cleared.
chkkbd	proc	far
	and	status,not (stat_ok+stat_cc+stat_cr) ; clear status bits
	xor	al,al
	cmp	flags.cxzflg,'C'	; Control-C interrupt seen?
	je	chkkbd0			; e = yes
	call	isdev			; is stdin a device, not disk file?
	jnc	chkkbd2			; nc = not device so do not read here
	mov	ah,dconio		; keyboard char present?
	mov	dl,0ffH
	int	dos
	je	chkkbd1			; e = none
	or	status,stat_ok		; have a char, return it in al
	cmp	al,3			; control c?
	jne	chkkbd1			; ne = not control c
chkkbd0:or	status,stat_cc		; say control c		 
chkkbd1:cmp	al,cr			; carriage return? [js]
	jne	chkkbd2			; ne = no
	or	status,stat_cr		; say carriage return [js]
chkkbd2:ret
chkkbd	endp

;
; worker: check serial port for received char. Return status = stat_ok if
;  char received, otherwise stat_ok cleared. Can echo char to screen. Will
;  write char to local circular buffer.
chkport	proc	far
	and	status,not stat_ok	; clear status bit
	call	fprtchr			; char at port (in al)?
	jnc	chkpor1			; nc = yes, analyze it
	push	bx
	mov	bx,portval
	cmp	[bx].portrdy,0		; is port not-ready?
	pop	bx
	jne	chkpor5			; ne = no, port is ready, just no char
	or	status,stat_cc		; Control-C for port not ready
chkpor5:stc
	ret				; no, return
chkpor1:and	al,parmsk		; strip parity, if any
	cmp	rxtable+256,0		; is translation turned off?
	je	chkpor0			; e = yes, no translation
	push	bx			; translate incoming character
	mov	bx,offset rxtable	; the translation table
	xlatb
	pop	bx
chkpor0:test	flags.capflg,logses	; capturing active?
	jz	chkpor3			; z = no
	test	flags.remflg,d8bit	; keep 8 bits for displays?
	jnz	chkpo0a			; nz = yes, 8 bits if possible
	cmp	flags.debug,0		; is debug mode active?
	jne	chkpo0a			; ne = yes, record 8 bits
	and	al,7fh			; remove high bit
chkpo0a:push	ax			; save char
	call	fcptchr			; give it captured character
	pop	ax			; restore character and keep going
chkpor3:test	flags.remflg,d8bit	; keep 8 bits for displays?
	jnz	chkpo3a			; nz = yes, 8 bits if possible
	and	al,7fh			; remove high bit
chkpo3a:cmp	script.inecho,0		; input echoing off?
	je	chkpor4			; e = yes
	call	scdisp			; display the char
chkpor4:call	bufwrite		; put char in buffer
	or	status,stat_ok		; say have a char (still in al)
	ret
chkport	endp

; Given a keyword table value in BX find the keyword text and length.
; Offset of table is in DX.
; Returns CX = length and SI pointing to text string, and carry clear.
; Failure returns carry set
revlookup proc	far
	push	ax
	push	di
	mov	si,dx			; offset of table
	xor	ch,ch
	mov	cl,byte ptr [si]	; number of table entires
	inc	si			; start of entries
	cld
	jcxz	revloo2			; z = no entries, fail
revloo1:lodsw				; length of this entry's keyword
	mov	di,si			; point at keyword
	add	di,ax			; point at value
	cmp	[di],bx			; a match?
	je	revloo3			; e = yes
	add	di,2			; step over value to next entry
	mov	si,di			; next entry
	loop	revloo1			; keep looking
revloo2:pop	di
	pop	ax
	stc				; no match, report failure
	ret
revloo3:mov	cx,ax			; length of keyword, si has ptr
	pop	di
	pop	ax
	clc				; success
	ret
revlookup endp

; worker: display the char in al on screen
; use caret-char notation for control codes
; parse out escape and control sequences
scdisp	proc	far
scdisp0:cmp	disp_state,0		; inited yet?
	jne	scdisp0a		; ne = yes
	mov	disp_state,offset scdisp1 ; init now
scdisp0a:push	ax
	push	bx
	push	cx			; used by atparse
	push	dx
	call	word ptr disp_state
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret				; keep near/far calls straight
scdisp	endp

scdisp1 proc	near			; worker for above
	mov	ah,conout		; our desired function
	test	flags.remflg,d8bit	; show all 8 bits?
	jnz	scdisp1a		; nz = yes
	and	al,7fh			; apply 7 bit display mask
scdisp1a:or	al,al			; null?
	jz	scdisp3			; z = yes, ignore
	cmp	al,del			; delete code?
	je	scdisp3			; e = yes, ignore
	cmp	script.infilter,0	; filter echos?
	je	scdisp2			; e = no, display as-is
	test	al,not 9fh		; C0/C1 control char?
	jnz	scdisp2			; ae = no, display as-is
	cmp	al,CSI			; CSI?
	je	scdisp6			; e = yes
	test	al,80h			; other C1?
	jnz	scdisp3			; nz = yes, ignore
	cmp	al,cr			; carriage return?
	je	scdisp2			; e = yes, display as-is
	cmp	al,lf			; line feed?
	je	scdisp2
	cmp	al,tab			; horizontal tab?
	je	scdisp2
	cmp	al,bell			; bell?
	je	scdisp2
	cmp	al,bs			; backspace?
	je	scdisp2
	cmp	al,escape		; escape?
	je	scdisp4
	or	al,40h			; control code to printable char
	push	ax
	mov	dl,5eh			; display caret first
	int	dos
	pop	ax
scdisp2:mov	dl,al			; the char to be displayed
	int	dos
scdisp3:ret

scdisp4:mov	disp_state,offset scdisp5	; here on ESC
	ret
scdisp5:cmp	al,'['			; ESC [?
	jne	scdisp7			; ne = no, consider to be terminator
scdisp6:call	atpclr			; clear parser
	mov	parfail,offset scdisp7	; next state upon failure
	mov	pardone,offset scdisp7	; next state upon success
	mov	disp_state,offset atparse ; parse sequences
	ret
scdisp7:mov	disp_state,offset scdisp1 ; normal display
	ret
scdisp1	endp

code1	ends
	end
