;   	NAME	msscmd
; File MSSCMD.ASM
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

 	public comnd, comand, isdev, iseof, prompt, tolowr, toupr, valtab
	public parstate, pardone, parfail, nparam, param, lparam, ninter
	public inter, atparse, atpclr, atdispat, cspb, dspb, mprompt, nvaltoa
	public savepoff, saveplen, keyboard, fwrtdir, cspb1, filetdate
	public	fqryenv, ifelse, oldifelse, retbuf, vfile
	public	rfprep, rgetfile, findkind, rfileptr, rpathname, rfilename

dos	equ	21h
env	equ	2CH			; environment address in psp
braceop	equ	7bh			; opening curly brace
bracecl	equ	7dh			; closing curly brace

; codes for various \fxxx(arg list) operations
F_char		equ	1
F_code		equ	2
F_contents 	equ	3
F_definition	equ	4
;F_eval		equ	5
F_exec		equ	6
F_files		equ	7
F_index		equ	8
F_length	equ	9
F_literal	equ	10
F_lower		equ	11
F_lpad		equ	12
F_maximum 	equ	13
F_minimum 	equ	14
F_nextfile	equ	15
F_repeat 	equ	16
F_reverse	equ	17
F_right		equ	18
F_rpad		equ	19
F_substr	equ	20
F_upper		equ	21
F_date		equ	22
F_size		equ	23
F_replace	equ	24
F_eval		equ	25
F_rindex	equ	26
F_verify	equ	27
F_ipaddr	equ	28
F_tod2secs	equ	29
F_chksum	equ	30
F_basename	equ	31
F_directories	equ	32
F_rfiles	equ	33
F_rdirectories	equ	34

; Constants for valtoa 
V_environ	equ	0
V_argc		equ	1
V_carrier	equ	22
V_charset	equ	33
V_console	equ	27
V_count		equ	2
V_cmdlevel	equ	29
V_cps		equ	24
V_date		equ	3
V_ndate		equ	14
V_dir		equ	5
V_dosver	equ	19
V_errlev	equ	4
V_kbd		equ	10
V_line		equ	15
V_monitor 	equ	28
V_parity 	equ	21
V_platform 	equ	8
V_port 		equ	15
V_program 	equ	12
V_prompt 	equ	23
V_query		equ	31
V_session 	equ	17
V_tcpip		equ	20
V_space 	equ	25
V_speed 	equ	11
V_startup 	equ	26
V_status 	equ	13
V_sysid		equ	32
V_system 	equ	9
V_terminal 	equ	16
V_time		equ	6
V_ntime 	equ	18
V_version 	equ	7
V_input		equ	30
V_inpath	equ	34
V_disk		equ	35
V_cmdfile	equ	36
V_inidir	equ	37
V_instatus	equ	38
V_minput	equ	39
V_return	equ	40
V_connection	equ	41
V_filespec	equ	42
V_fsize		equ	43
V_crc16		equ	44
V_day		equ	45
V_nday		equ	46

; Like main filest, but shorter for local usage.
fileiost struc
mydta	db 26 dup(0)	; DOS, 21 resev'd bytes, file attr, 2 each date & time
mysizelo dw 0		; DOS, file size double word
mysizehi dw 0
filename db 13 dup(0)	; DOS, filename, asciiz, with dot. End of DOS section
fileiost ends

data 	segment
	extrn	flags:byte, taklev:byte, takadr:word, mcctab:byte
	extrn	kstatus:word, errlev:byte, psp:word, fsta:word
	extrn	portval:word, bdtab:byte, tdfmt:byte, machnam:byte
	extrn	verident:word, kstatus:word, errlev:byte, comptab:byte
	extrn	termtb:byte, dosnum:word, prmptr:word, startup:byte
	extrn	crt_mode:byte, tmpbuf:byte, buff:byte, minpcnt:word
	extrn	decbuf:byte, encbuf:byte, queryseg:word, inpath_seg:word
	extrn	cmdfile:byte, inidir:byte, dos_bottom:byte, marray:word
	extrn	input_status:word, domath_ptr:word, domath_cnt:word
	extrn	domath_msg:word, atoibyte:byte, atoi_err:byte, atoi_cnt:word
	extrn	crcword:word, lastfsize:dword
ifndef	no_tcp
	extrn	sescur:word, tcp_status:word
endif	; no_tcp

				; Start Patch structure. Must be first.
	even
dspb	dw	code		; segment values for patcher
	dw	code1
	dw	code2
	dw	data
	dw	data1
	dw	_TEXT
	db	64 dup (0)	; data segment patch buffer
				;  with space for other material, if req'd
				; end of Patch structure
progm	db	'MS-DOS_KERMIT$'	; for \v(program)
system	db	'MS-DOS$'		; for \v(system)
keyboard dw	88			; \v(keyboard) kind of keybd 88/101
ten	db	10			; for times ten

comand	cmdinfo	<>
cmer00  db      cr,lf,'?Program internal error, recovering$'
cmer01	db	cr,lf,'?More parameters are needed$'
cmer02	db	cr,lf,'?Word "$'
cmer03	db	'" is not usable here$'
cmer04	db	'" is ambiguous$'
cmer07	db	cr,lf,'?Ignoring extra characters "$'
cmer08	db	'"$'			; "
cmer09	db	cr,lf,'?Text exceeded available buffer capacity$'
cmin01	db	' Use one of the following words in this position:',cr,lf,'$'
stkmsg	db	cr,lf,bell,'?Exhausted work space! Circular definition?$'
moremsg	db	'... more, press a key to continue ...$'
crlf    db      cr,lf,'$'
ctcmsg	db	5eh,'C$'
cmunk	db	'unknown'
errflag	db	0			; non-zero to suppress cmcfrm errors
kwstat	db	0			; get-keyword status
subcnt	db	0			; count of chars matched in '\%'
subtype db	0			; kind of sub (% or v)
evaltype dw	0			; evaltoa kind
bracecnt db	0			; curly brace counter
parencnt db	0			; parenthesis counter
report_binary db 0			; subst reporting \number directly
argptr	dw	3 dup (0)		; \fxxx() argument pointers
arglen	dw	3 dup (0)		; \fxxx() argument lengths
replay_cnt dw	0			; report to app, no echo
replay_skip db	0			; non-zero to skip subst for replays
retbuf	db	130 dup (0)		; \v(return) buffer
vfile	db	65 dup (0)		; \v(filespec) buffer
maxdepth equ	15			; depth of directory search
fileio  fileiost maxdepth dup(<>)	; find first/next support
rfileptr dw	0			; pointer to search dta structure
rpathname db	64+1 dup (0)		; search path
rfilename db	8+3+1 dup (0)		; search filename

filecnt	dw	0			; count of files found
findkind db	0 ; find kind (1=file,2=dir,plus 4=recurse,0=nothing)
cmsflg	db	0			; Non-zero when last char was a space
cmkind	db	0			; command kind request (cmkey etc)
in_showprompt db 0			; Non-zero when in showprompt
cmdbuf	db	cmdblen dup (0)		; Buffer for command parsing
	db	0			; safety for overflow
rawbuf	db	cmdblen dup (0)		; input, what user provided
	db	0			; safety for overflow
read_source db	0			; channel whence we read
endedbackslash db 0
in_reparse db	0
	even
cmdstk	dw	0			; stack pointer at comand call time
cmptab	dw	0			; Address of present keyword table
cmhlp	dw	0			; Address of present help
cmwptr	dw	0			; Pointer for next char write
cmrptr	dw	0			; Pointer for next char read
cmsiz	dw	0			; Size info of user input
cmsptr	dw	0			; Place to save a pointer
mcmprmp	dw	0			; master prompt, string address
mcmrprs	dd	0			; master prompt, reparse address
mcmostp	dw	0			; master prompt, stack pointer
temp	dw	0			; temp (counts char/line so far)
cmrawptr dw	0			; non-substitution level, write ptr

ifndef	no_tcp
valtab	db	1+46			; table of values for \v(value)
else
valtab	db	1+46 - 2
endif	; no_tcp
	mkeyw	'argc)',V_argc
	mkeyw	'carrier)',V_carrier
	mkeyw	'charset)',V_charset
	mkeyw	'cmdfile)',V_cmdfile
	mkeyw	'connection)',V_connection
	mkeyw	'console)',V_console
	mkeyw	'count)',V_count
	mkeyw	'cmdlevel)',V_cmdlevel
	mkeyw	'cps)',V_cps
	mkeyw	'crc16)',V_crc16
	mkeyw	'date)',V_date
	mkeyw	'ndate)',V_ndate
	mkeyw	'day)',V_day
	mkeyw	'nday)',V_nday
	mkeyw	'directory)',V_dir
	mkeyw	'dosversion)',V_dosver
	mkeyw	'disk)',V_disk
	mkeyw	'errorlevel)',V_errlev
	mkeyw	'filespec)',V_filespec
	mkeyw	'fsize)',V_fsize
	mkeyw	'inidir)',V_inidir
	mkeyw	'inpath)',V_inpath
	mkeyw	'input)',V_input
	mkeyw	'instatus)',V_instatus
	mkeyw	'keyboard)',V_kbd
	mkeyw	'line)',V_port
	mkeyw	'minput)',V_minput
	mkeyw	'monitor)',V_monitor
	mkeyw	'parity)',V_parity
	mkeyw	'platform)',V_platform
	mkeyw	'port)',V_port
	mkeyw	'program)',V_program
	mkeyw	'prompt)',V_prompt
	mkeyw	'query)',V_query
	mkeyw	'return)',V_return
ifndef	no_tcp
	mkeyw	'session)',V_session
	mkeyw	'tcpip_status)',V_tcpip
endif	; no_tcp
	mkeyw	'space)',V_space
	mkeyw	'speed)',V_speed
	mkeyw	'startup)',V_startup
	mkeyw	'status)',V_status
	mkeyw	'sysid)',V_sysid
	mkeyw	'system)',V_system
	mkeyw	'terminal)',V_terminal
	mkeyw	'time)',V_time
	mkeyw	'ntime)',V_ntime
	mkeyw	'version)',V_version


evaltab	db	32			; \fverb(args)
	mkeyw	'basename(',F_basename
	mkeyw	'character(',F_char
	mkeyw	'checksum(',F_chksum
	mkeyw	'code(',F_code
	mkeyw	'contents(',F_contents
	mkeyw	'date(',F_date
	mkeyw	'definition(',F_definition
	mkeyw	'directories(',F_directories
	mkeyw	'eval(',F_eval
	mkeyw	'files(',F_files
	mkeyw	'index(',F_index
	mkeyw	'ipaddr(',F_ipaddr
	mkeyw	'length(',F_length
	mkeyw	'literal(',F_literal
	mkeyw	'lower(',F_lower
	mkeyw	'lpad(',F_lpad
	mkeyw	'maximum(',F_maximum
	mkeyw	'minimum(',F_minimum
	mkeyw	'nextfile(',F_nextfile
	mkeyw	'rindex(',F_rindex
	mkeyw	'repeat(',F_repeat
	mkeyw	'replace(',F_replace
	mkeyw	'reverse(',F_reverse
	mkeyw	'rdirectories(',F_rdirectories
	mkeyw	'rfiles(',F_rfiles
	mkeyw	'right(',F_right
	mkeyw	'rpad(',F_rpad
	mkeyw	'size(',F_size
	mkeyw	'substr(',F_substr
	mkeyw	'tod2secs(',F_tod2secs
	mkeyw	'verify(',F_verify
	mkeyw	'upper(',F_upper
; not implemented in MS-DOS Kermit
;	mkeyw	'execute(',F_exec

envtab	db	1			     	; \$(..) Environment table
	mkeyw	'An Environment variable)',0	; reserve 0 in valtab

numtab  db      1                               ; \number help table
        mkeyw   'a number such as \123',0

						; table of Parity strings
parmsgtab dw	parevnmsg,parmrkmsg,parnonmsg,paroddmsg,parspcmsg
parevnmsg db	'EVEN',0
parmrkmsg db	'MARK',0
parnonmsg db	'NONE',0
paroddmsg db	'ODD',0
parspcmsg db	'SPACE',0

onoffmsgtab dw	offmsg,onmsg		; on/off table, asciiz
offmsg	db	'OFF',0
onmsg	db	'ON',0

ansiword db	'ANSI',0		; \v(console) ASCIIZ strings
noneword db	'NONE',0
colormsg db	'COLOR',0		; \v(monitor) ASCIIZ strings
monomsg	db	'MONO',0
connmsg	db	'local',0		; \v(connection) state

valtmp	dw	0
numtmp	dw	0

	even
envadr	dd	0			; seg:offset of a string in Environemt
envlen	dw	0			; length of envadr's string

	even				; Control sequence storage area
maxparam equ	16			; number of ESC and DCS Parameters
maxinter equ	16			; number of ESC and DCS Intermediates

savepoff label	word			; Start per session save area
parstate dw	0			; parser state, init to startup
pardone dw	0			; where to jmp after Final char seen
parfail	dw	0			; where to jmp if parser fails
nparam	dw	0			; number of received Parameters
param	dw	maxparam dup (0)	; Parameters for ESC
lparam	db	0			; a single letter Parameter for ESC
ninter	dw	0			; number of received Intermediates
inter	db	maxinter dup (0),0	; Intermediates for ESC, + guard 
saveplen dw	($-savepoff)
ifelse	db	0		; non-zero if last IF statement failed
oldifelse db	0		; copy of ifelse from previous command
month	db	'Jan ','Feb ','Mar ','Apr ','May ','Jun '
	db	'Jul ','Aug ','Sep ','Oct ','Nov ','Dec '
day	db	'Sun','Mon','Tue','Wed','Thu','Fri','Sat'
data	ends

data1	segment
	db	0			; so error msg has non-zero offset
cmin00  db      ' Press ENTER to execute command$'
f1hlp	db	' number$'
f2hlp	db	' char$'
f3hlp	db	' variable or macro name$'
f8hlp	db	' pattern-text, string, start-position$'
f9hlp	db	' text$'
f12hlp	db	' text, pad-length, pad-char$'
f15hlp	db	' no argument$'
f16hlp	db	' repeat-text, repeat-count$'
f18hlp	db	' text, right-most count$'
f20hlp	db	' text, start-position, substring len$'
f22hlp	db	' filename$'
f24hlp	db	' source, pattern, replacement$'
f25hlp	db	' arithmetic expression$'
f30hlp	db	' string$'
n1hlp	db	' digits of a number whose value fits into one byte$'
data1	ends

ifndef	no_terminal
ifndef	no_tcp
_TEXT	segment
	extrn	cpatch:far
_TEXT	ends
endif	; no_tcp
endif	; no_terminal

code1	segment
	assume 	cs:code1
	extrn	shovarcps:near, dskspace:far, fparse:far
	extrn	strlen:far, prtscr:far, strcpy:far, prtasz:far, strcat:far
	extrn	dec2di:far, decout:far, malloc:far, domath:far
        extrn   atoi:far, takrd:far, buflog:far, tod2secs:far

cspb1	equ	this byte
	db	(256-($-cspb1)) dup (0)	; code1 segment patch buffer
				; end of Patch area
code1	ends

code	segment
	extrn	ctlu:near, cmblnk:near, locate:near
	extrn	takclos:far, docom:near, getenv:near
	extrn	getbaud:near, lnout:near, takopen_sub:far
	extrn	takopen_macro:far

	assume	cs:code, ds:data, es:nothing

				; Patch area. Must be first in MSK's Code Seg
cspb	equ	this byte
	dw	seg code1
	dw	seg code2
	dw	seg data
	dw	seg data1
	dw	seg _TEXT
	dw	seg _DATA

ifndef	no_terminal
ifndef	no_tcp
	dw	offset cpatch
endif	; no_tcp
endif	; no_terminal
	db	(256-($-cspb)) dup (0)	; code segment patch buffer
				; end of Patch area

fctlu	proc	far		; FAR callable versions of items in seg code
	call	ctlu		;  for calling from code segment code1 below
	ret
fctlu	endp
fcmblnk	proc	far
	call	cmblnk
	ret
fcmblnk	endp
fgetbaud proc	far
	call	getbaud
	ret
fgetbaud endp
fgetenv	proc	far
	call	getenv
	ret
fgetenv	endp
flocate	proc	far
	call	locate
	ret
flocate	endp

fdec2di	proc	far
	push	cx
	push	ds
	mov	cx,es
	mov	ds,cx
	call	dec2di
	pop	ds
	pop	cx
	ret
fdec2di	endp
ftakclos proc	far
	call	takclos
	ret
ftakclos endp

nvaltoa	proc	near
	push	es
	mov	ax,ds
	mov	es,ax
	call	fvaltoa
	pop	es
	ret
nvaltoa	endp
flnout	proc	far
	call	lnout
	ret
flnout	endp
fdskspace proc	far
	call	dskspace
	ret
fdskspace endp

;       This routine parses the specified function in AH. Any additional
;       information is in DX and BX.
;       Returns carry clear on success and carry set on failure
 
COMND	PROC NEAR
	mov	cmdstk,sp		; save stack ptr for longjmp exit
	mov	bracecnt,0		; curly brace counter
	cmp	ah,cmeol		; Parse a confirm?
	jne	cm2			; nz = no
	call	cmcfrm			; get a Carriage Return end of line
	ret
cm2:	mov	cmkind,ah		; remember for {} line continuation
	cmp	ah,cmkey		; Parse a keyword?
	jne	cm3			; ne = no
	xor	al,al			; get a zero/clear
	xchg	al,ifelse		; get current ifelse state
	mov	oldifelse,al		; remember here (one cmd delay)
	call	cmkeyw			; get keyword
	ret
cm3:	cmp	ah,cmline		; parse line of text
	jne	cm4
	call	cmtxt
	ret
cm4:	cmp	ah,cmword		; parse arbitrary word
	jne	cm5
	call	cmtxt
	ret
cm5:	mov	ah,prstr		; else give error
	mov	dx,offset cmer00	; "?Program internal error"
	int	dos
	jmp	prserr			; reparse
					; Control-C exit path (far to near)
cmexit	label	far
	mov	sp,cmdstk		; restore command entry stack pointer
	stc
	retn				;  and fail immediately (a longjmp)

COMND	ENDP
code	ends

code1	segment
	assume	cs:code1

; This routine parses a keyword from the table pointed at by DX, help text
; point to by BX. Format of the table is as follows (use macro mkeyw):
;	addr:	db	N	  ; Where N is the # of entries in the table
;		dw	M	  ; M is the size of the keyword
;		db	'string'  ; String is the keyword
;		dw	value	  ; Value is data to be returned
; Keywords may be in any order and in mixed case.
; Return is carry clear for success and carry set for failure.

; cmptab: pointer to keyword table (supplied by caller)
; cmhlp: pointer to help message (supplied by caller)
; cmsptr: pointer to current user word text
; cmsiz: length of user text, excluding terminator
; comand.cmcr: 0 = empty lines not allowed, 1 = empty lines allowed
; comand.cmwhite: non-zero allows leading whitespace for cmline and cmword,
;                 reset automatically at end of call
; cmwptr: buffer write pointer to next free byte
; cmrptr: buffer read pointer for next free byte
; comand.cmper:	0 to do \%x substitution. Set to 0 at end of call
; comand.impdo: non-zero permits keyword failure to retry as DO command, reset
;		 automatically at time of failure.
cmkeyw	proc	far
	mov	cmsiz,0			; user word length
	mov	ax,cmrptr		; get command reading pointer
	mov	cmsptr,ax		; set pointer for start of user word
	mov	cmhlp,bx		; save the help pointer
        mov	cmptab,dx		; save the beginning of keyword table
	mov	bx,dx
	cmp	byte ptr[bx],0		; get number of entries in table
	jne	cmky1
	jmp	cmky7			; e = no keywords to check, error
cmky1:	mov	cmsflg,0ffh		; skip leading spaces/tabs
	call	cmgtch			; get char from the user into ah
	jc	cmky3			; c = terminator
	mov	dx,cmrptr		; next byte to read
	dec	dx			; where we just read a char
	mov	cmsptr,dx		; remember start of keyword
	inc	cmsiz			; start counting user chars
cmky2:	call	cmgtch			; read until terminator
	jc	cmky3			; c = terminator
	inc	cmsiz			; count user chars
	jmp	short cmky2		; no terminator yet

cmky3:	cmp	ah,'?'              	; need help?
	jne	cmky4			; ne = no
	call	cmkyhlp			; display help
	jmp	repars
cmky4:	cmp	ah,escape		; escape?
	jne	cmky6			; ne = no
	call	cmkyesc			; process escape
	jc	cmky5			; c = failure (no unique keyword yet)
	mov	comand.cmper,0		; reset to variable recognition
	mov	comand.cmkeep,0
	mov	comand.impdo,0		; clear flag to prevent loops
	mov	comand.cmquiet,0	; permit echoing again
	mov	comand.cmcnvkind,cmcnv_none ; default is no conversion
	clc
	ret				; return successfully to user

cmky5:	cmp	cmsiz,0			; started a word yet?
	je	cmky1			; e = no, ignore escape, keep looking
	call	cmkyhlp			; display help
	jmp	repars

cmky6:	cmp	cmsiz,0			; length of user's text, empty?
	je	cmky7			; e = yes, parse error
	push	bx
	mov	bx,cmsptr		; point at first user character
	cmp	byte ptr[bx],':'	; start of a label?
	pop	bx
	jne	cmky6a			; ne = no, return success
	mov	cmsiz,1			; say just one byte
cmky6a:	call	getkw			; get unique kw, point to it with bx
	jc	cmky8			; c = not found
	add	bx,[bx]			; add length of keyword text (CNT)
	add	bx,2			; point at value field
	mov	bx,[bx]			; bx = return value following keyword
	call	optionclr		; clear parser options
	mov	errflag,0
	clc
	ret				; return successfully
					; all other terminators come here
cmky7:	cmp	cmsiz,0			; empty table or empty user's text?
	jne	cmky8			; ne = no
	cmp	comand.cmcr,0		; empty lines allowed?
	jne	cmky10			; ne = yes, do not complain
	push	dx
	mov	ah,prstr
	mov	dx,offset cmer01	; command word expected
	int	dos
	pop	dx
	xor	al,al
	mov	comand.cmquiet,al	; permit echoing again
	mov	comand.impdo,al		; clear flag to prevent loops
	stc				; failure
	ret

cmky8:	cmp	comand.impdo,0		; failed here, ok to try Macro table?
	je	cmky8a			; e = no, use regular exit path
	mov	comand.impdo,0		; yes, but clear flag to prevent loops
	mov	cmrptr,offset cmdbuf	; reinit read pointer
	mov	comand.cmquiet,1	; suppress echoing of same keyword
	mov	bx,offset docom		; return DO as "found" keyword
	clc
	ret				; return success to invoke DO

cmky8a:	cmp	comand.cmswitch,0	; looking for switch keyword?
	je	cmky8b			; e = no
	mov	comand.cmswitch,0
	mov	comand.impdo,0		; yes, but clear flag to prevent loops
	mov	ax,cmsptr		; where keyword started in buffer
	mov	cmrptr,ax		; reread it again later
	mov	comand.cmquiet,1	; suppress echoing of same keyword
	stc				; return with no complaint
	ret

cmky8b:	mov	errflag,1		; say already doing error recovery
	or	kstatus,ksgen		; global command status, failure
	mov	comand.cmquiet,0	; permit echoing again
	call	isdev			; reading pretyped lines?
	jnc	cmky9			; nc = yes, consume rest of line
	cmp	taklev,0		; in a Take file?
	jne	cmky9			; ne = yes
	call	cmskw			; display offending keyword
	mov	comand.impdo,0		; clear flag to prevent loops
	dec	cmrptr			; interactive, backup to terminator
	mov	bx,cmrptr		; look at it
	cmp	byte ptr [bx],' '	; got here on space terminator?
	jne	cmky10			; ne = no, (cr,lf,ff) exit failure
	mov	ah,prstr		; start a fresh line
	mov	dx,offset crlf
	int	dos
	call	bufdel			; cut back buffer to last good char
	jmp	repars			; reparse interactive lines

cmky9:	call	cmcfrm			; get formal end of command line
					;  to maintain illusion of typeahead
					;  and let user backspace to correct
					;  mistakes (we reparse everything)
	call	cmskw			; display offending keyword
cmky10:	mov	comand.cmquiet,0	; permit echoing again
	stc				; say failure
	ret
cmkeyw	endp

;;;;;; start support routines for keyword parsing.

cmkyesc	proc	near			; deal with escape terminator
	push	cmrptr			; points at ESC
	pop	cmwptr			; pointed one byte beyond ESC
	cmp	cmsiz,0 		; user word length, empty?
	jne	cmkye2			; ne = have user text, else complain
cmkye1:	call	esceoc			; do normal escape end-of-command
	stc				; say failure to fill out word
	ret
					; add unique keyword to buffer
cmkye2:	call	getkw			; is there a matching keyword?
	jc	cmkye1			; c = ambiguous or not found
	push	bx			; unique, bx points to structure
	push	si
	mov	cx,[bx]			; length of keyword
	add	bx,2			; point to first letter
	dec	cmrawptr		; overwrite ESC
	mov	si,cmrawptr		; where raw writes go
	mov	dx,cmsiz		; length of user word
	add	bx,dx			; add chars known so far
	sub	cx,dx			; calculate number yet to add
	jcxz	cmkye4			; z = none
cmkye3:	mov	al,[bx]			; get a keyword letter
	inc	bx
	call	tolowr			; lowercase
	mov	[si],al			; store it
	inc	si
	loop	cmkye3			; do all new chars
cmkye4:	mov	word ptr [si],'  '	; add trailing space, clear old next
	inc	si
	mov	cmrawptr,si
	pop	si
	pop	bx			; bx = keyword structure
	inc	cmrawptr		; bufdel backs up one char
	jmp	bufdel
cmkyesc	endp

esceoc	proc	near			; do normal escape end-of-command
	push	ax
	push	dx
	mov	ah,conout		; ring the bell
	mov	dl,bell
	int	dos
	pop	dx
	pop	ax
	call	bufreset		; reset buffer
	stc				; say error condition
	ret
esceoc	endp

; Help. Question mark entered by user.  Display all the keywords that match
; user text. If text is null then use external help if available; otherwise,
; display all keywords in the table. Removes question mark from buffer and
; invokes reparse of command line to-date. User word starts at cmsptr and
; is cmsiz bytes long.
cmkyhlp	proc	near
	xor	cx,cx			; clear number of keyword (none yet)
	cmp	cmsiz,0			; user text given?
	jne	cmkyh1			; ne = yes, use matching keywords
	cmp	cmhlp,0			; external help given?
	jne	cmkyh6			; yes, use it instead of full table
cmkyh1:	mov	temp,0			; count # chars printed on this line
	mov	bx,cmptab		; beginning of kw table
	mov	ch,[bx]			; length of table
	xor	cl,cl			; no keywords or help displayed yet
	inc	bx			; point at CNT field
cmkyh2:	cmp	cmsiz,0			; length of user word
	je	cmkyh3			; e = null, use full table
	call	cmpwrd			; compare keyword with user word
	jc	cmkyh5			; c = no match, get another keyword
cmkyh3:	mov	ax,[bx]			; length of table keyword
	add	byte ptr temp,al	; count chars printed so far
	cmp	temp,76			; will this take us beyond column 78?
	jbe	cmkyh4			; be = no, line has more room
	mov	byte ptr temp,al	; reset the count
	mov	ah,prstr
	mov	dx,offset crlf		; break the line
	int	dos
cmkyh4:	or	cl,cl			; any keywords found yet?
	jnz	cmkyh4a			; nz = yes
	mov	dx,offset cmin01	; start with One of the following: msg
	mov	ah,prstr
	int	dos
	inc	cl			; say one keyword has been found
cmkyh4a:mov	dl,spc			; put two spaces before each keyword
	mov	ah,conout
	int	dos
	int	dos
	add	temp,2			; count output chars
	mov	di,bx			; get current keyword structure
	add	di,2			; text part
	push	cx
	mov	cx,[bx]			; string length to cx, offset to di
	call	prtscr			; display counted string
	pop	cx
cmkyh5:	dec	ch			; are we at end of table?
	jle	cmkyh7			; le = yes, quit now
	add	bx,[bx]			; next keyword, add CNT chars to bx
	add	bx,4			; skip CNT and 16 bit value
	jmp	cmkyh2			; go examine this keyword

cmkyh6:	mov	si,cmhlp		; external help text in seg data1
	xor	bx,bx			; line counter
	push	es
	mov	ax,seg data1		; all help text is in data1
	mov	es,ax
	cld
cmkyh10:mov	al,es:[si]		; read a help msg byte
	inc	si
	cmp	al,'$'			; end of message?
	je	cmkyh14			; e = yes, stop
cmkyh11:mov	ah,conout
	mov	dl,al
	int	dos			; display byte
	cmp	dl,LF			; line break?
	jne	cmkyh10			; ne = no
	inc	bl			; count line
	cmp	bl,dos_bottom		; (24) time for a more msg?
	jbe	cmkyh10			; be = not yet
	xor	bl,bl			; reset line count
	call	iseof			; are we at EOF, such as from disk?
	jc	cmkyh10			; c = yes, ignore more msg
	mov	ah,prstr
	mov	dx,offset moremsg	; "... more..." msg
	int	dos
cmkyh13:mov	ah,coninq		; read the char from file, not device
	int	dos
	cmp	al,3			; a ^C?
	je	short cmkyh14		; e = yes, stop the display
	push	bx			; save line counter
	push	es			; and read pointer
	push	si
	call	fctlu			; clear display's line, reuse it
	pop	si
	pop	es
	pop	bx
	jmp	short cmkyh10		; continue
cmkyh14:pop	es
	inc	cl			; say gave help already

cmkyh7:	or	cl,cl			; found any keywords?
	jnz	cmkyh9			; nz = yes
	mov	cx,cmsiz		; length of word
	or	cx,cx
	jg	cmkyh8			; g = something to show
	push	dx
	mov	ah,prstr
	mov	dx,offset cmer01	; command word expected
	int	dos
	pop	dx
	jmp	prserr
cmkyh8:	mov	kwstat,0		; set keyword not-found status
	call	cmskw			; display offending keyword
cmkyh9:	mov	ah,prstr		; start a fresh line
	mov	dx,offset crlf
	int	dos
	call	bufdel			; unwrite the "?" (cmrptr is there)
	ret
cmkyhlp	endp

; See if keyword is ambiguous or not from what the user has typed in.
; Return carry set if word is ambiguous or not found, carry clear otherwise.
; Uses table pointed at by cmptab, user text pointed at by cmsptr and length
; in cmsiz.
cmambg	proc	near
	push	bx
	push	cx
	push	dx
	xor	dl,dl			; count keyword matches so far
	mov	bx,cmptab		; look at start of keyword table
	mov	cl,[bx]			; get number of entries in table
	xor	ch,ch			; use cx as a counter
	jcxz	cmamb8			; z = no table so always ambiguous
	inc	bx			; look at CNT byte of keyword
cmamb4:	call	cmpwrd			; user vs table words, same?
	jc	cmamb6			; c = no match
	inc	dl			; count this as a match
	cmp	dl,1			; more than one match?
	ja	cmamb8			; a = yes, quit now
cmamb6:	add	bx,[bx]			; add CNT chars to bx
	add	bx,4			; skip CNT and 16 bit value
	loop	cmamb4			; do rest of keyword table
	cmp	dl,1			; how many matches were found?
	jne	cmamb8			; ne = none or more than 1: ambiguous
	pop	dx			; restore main registers
	pop	cx
	pop	bx
	clc
	ret				; ret = not ambiguous
cmamb8:	pop	dx			; restore main registers
	pop	cx
	pop	bx
	stc
	ret				; return ambiguous or not found
cmambg	endp

; Compare user text with keyword, abbreviations are considered a match.
; Enter with bx pointing at keyword table CNT field for a keyword.
; Return carry clear if they match, set if they do not match. User text
; pointed at by cmsptr and length is in cmsiz.
; Registers preserved.

cmpwrd	proc	near
	push	cx
	mov	cx,cmsiz		; length of user's text
	jcxz	cmpwrd2			; z: null user word matches no keyword
	cmp	cx,[bx]			; user's text longer than keyword?
	ja	cmpwrd2			; a = yes, no match
	push	ax
	push	bx
	push	si
	add	bx,2		    	; point at table's keyword text
	mov	si,cmsptr		; buffer ptr to user input
	cld
cmpwrd1:lodsb				; user text
	mov	ah,[bx]			; keyword text
	inc	bx			; next keyword letter
	call	tolowr			; force lower case on both chars
	cmp	ah,al			; same?
	loope	cmpwrd1			; e = same so far
	pop	si
	pop	bx
	pop	ax
	jne	cmpwrd2			; ne = mismatch
	pop	cx			; recover keyword counter
	clc				; they match
	ret
cmpwrd2:pop	cx			; recover keyword counter
	stc				; they do not match
	ret
cmpwrd	endp

; Get pointer to keyword structure using user text. Uses keyword table
; pointed at by cmptab and cmsiz holding length of user's keyword (cmpwrd
; needs cmsptr pointing at user's keyword and length of cmsiz).
; Structure pointer returned in BX.
; Return carry clear for success and carry set for failure. Modifies BX.
getkw	proc	near
	push	cx
	mov	kwstat,0		; keyword status, set to not-found
	cmp	cmsiz,0			; length of user word, empty?
	je	getkw3			; e = yes, fail
	mov	bx,cmptab		; table of keywords
	mov	cl,[bx]			; number of keywords in table
	xor	ch,ch
	jcxz	getkw3			; z = none, fail
	inc	bx			; point to first
getkw1:	call	cmpwrd			; compare user vs table words
	jc	getkw2			; c = failed to match word, try next
	mov	kwstat,1		; say found one keyword, maybe more
	push	dx
	mov	dx,cmsiz		; users word length
	cmp	[bx],dx			; same length (end of keyword)?
	pop	dx
	je	getkw4			; e = yes, exact match. Done
	call	cmambg			; ambiguous?
	jnc	getkw4			; nc = unique, done, return with bx
	mov	kwstat,2		; say more than one such keyword
getkw2:	add	bx,[bx]			; next keyword, add CNT chars to bx
	add	bx,4			; skip CNT and 16 bit value
	loop	getkw1			; do all, exhaustion = failure
getkw3:	pop	cx
	stc				; return failure
	ret
getkw4:	pop	cx
	clc				; return success
	ret
getkw	endp

; show offending keyword message. Cmsptr points to user word,
; cmsiz has length. Modifies AX, CX, and DX.
cmskw	proc	near
	cmp	comand.cmquiet,0	; Quiet mode?
	je	cmskw0			; e = no, regular mode
	ret				; else say nothing
cmskw0:	mov	ah,prstr		; not one of the above terminators
	mov	dx,offset cmer02	; '?Word "'
	int	dos
	mov	ah,conout
	mov	cx,cmsiz		; length of word
	jcxz	cmskw3			; z = null
	mov	ah,conout
	push	si
	mov	si,cmsptr		; point to word
	cld
cmskw1:	lodsb
	cmp	al,' '			; control code?
	jae	cmskw2			; ae = no
	push	ax
	mov	dl,5eh			; caret
	int	dos
	pop	ax
	add	al,'A'-1		; plus ascii bias
cmskw2:	mov	dl,al			; display chars in word
	int	dos
	loop	cmskw1
	pop	si
cmskw3:	mov	dx,offset cmer03	; '" not usable here.'
	cmp	kwstat,1		; kywd status from getkw, not found?
	jb	cmskw4			; b = not found, a = ambiguous
	mov	dx,offset cmer04	; '" ambiguous'
cmskw4:	mov	ah,prstr
        int	dos
	ret
cmskw	endp
;;;;;;;;;; end of support routines for keyword parsing.

; CMLINE: Parse	arbitrary text up to a CR.
; CMWORD: Parse text up to first trailing space, or if starts with ()
;  then consume the line.
; Enter with BX = pointer to output buffer
; DX pointing to help text. Produces asciiz string. Return updated pointer in
; BX and output size in AX. Leading spaces are omitted unless comand.cmwhite
; is non-zero (cleared upon exit). It does not need to be followed by the
; usual call to confirm the line. Byte comand.cmblen can be used to specify
; the length of the caller's buffer; cleared to zero by this command to
; imply a length of 127 bytes (default) and if zero at startup use 127 bytes.
; If the line starts with an opening curly brace, then physical lines are
; automatically continued until the closing curly brace is obtained.
; Continuation breaks are a comma in the data stream and a CR/LF to the
; visual screen. Material after the closing brace is discarded.
;
; Lines and words starting on a curly brace and ending on a matching
; curly brace plus optional whitespace have the trailing whitespace
; omitted and both outer braces removed.
cmtxt	proc	far
	mov	cmptab,bx		; save pointer to data buffer
	xor	ax,ax
	mov	word ptr [bx],ax	; clear result buffer
	mov	cmhlp,dx		; save the help message
	mov	cmsiz,ax		; init the char count
	mov	parencnt,al		; clear count of parentheses
	cmp	comand.cmblen,ax	; length of user's buffer given?
	jne	cmtxt1			; ne = yes
	mov	comand.cmblen,127	; else set 127 byte limit plus null
cmtxt1:	cmp	comand.cmwhite,al	; allow leading whitespace?
	jne	cmtxt2			; ne = yes
	mov	cmsflg,0ffh		; omit leading space
cmtxt2:	call	cmgtch			; get a char
	jc	cmtxt3			; c = terminator 
	jmp	cmtxt10			; put char into the buffer

cmtxt3:	cmp	ah,' '			; space terminator?
	jne	cmtxt4			; ne = no
	cmp	cmkind,cmline		; parsing lines?
	je	cmtxt10			; e = yes, put space in the buffer
	mov	bx,cmptab		; words, check on () delimiters
	sub	bx,cmsiz
	cmp	byte ptr [bx],'('	; started word with paren?
	jne	cmtxt6			; ne = no, it's a terminator
	cmp	parencnt,0		; outside parens?
	jne	cmtxt10			; ne = no, use as data inside (..)
	jmp	cmtxt6			; space is terminator

cmtxt4:	cmp	ah,escape		; escape?
	jne	cmtxt5			; ne = no
	call	esceoc			; do normal escape end-of-command
	jmp	short cmtxt1		; try again

cmtxt5:	cmp	ah,'?'			; asking a question?
	je	cmtxt8			; e = yes
	cmp	ah,CR			; bare CR?
	je	cmtxt6			; e = yes, always a terminator
	cmp	cmkind,cmline		; reading a line?
	je	cmtxt10			; e = yes, other terms go into buffer
					; else terminators terminate words

cmtxt6:	mov	bx,cmptab		; pointer into destination array
	mov	byte ptr[bx],0		; put null terminator into the buffer
	xchg	ax,cmsiz		; return count in AX
	or	ax,ax			; empty?
	jz	cmtxt7a			; z = yes

cmtxt7:	push	si			; remove terminating curly braces
	mov	si,cmptab		; where next output byte goes
	sub	si,ax			; minus read, equals start of buffer
	mov	cx,ax			; count to cx for unbrace
	call	unbrace			; outer curly brace remover
	mov	ax,cx			; returned length back to AX
	mov	bx,si
	add	bx,ax			; bx points to null terminator
	pop	si
cmtxt7a:call	optionclr		; clear parser options
	cmp	cmkind,cmline		; lines?
	jne	cmtxt7f			; ne = no, words
	call	rprompt			; restore master prompt level
cmtxt7f:clc
	ret

cmtxt8:	inc	cmrptr			; count the ?
	cmp	cmsiz,0			; Is "?" first char?
	jne	cmtxt10			; ne = no, just add to buffer
	dec	cmrptr
	cmp	cmhlp,0			; external help given?
	jne	cmtxt9			; ne = yes
	mov	cmhlp,offset cmin00	; confirm with c/r msg
cmtxt9:	push	cmsiz
	mov	cmsiz,0			; so we do not use keyword table
	call	cmkyhlp			; use our help message
	pop	cmsiz
	jmp	cmtxt2

cmtxt10:inc	cmsiz			; increment the output count
	mov	bx,cmptab		; pointer into destination array
	mov	[bx],ah			; put char into the buffer
	cmp	cmkind,cmword		; word?
	jne	cmtxt12			; ne = no, line
	cmp	ah,'('			; opening paren?
	jne	cmtxt11			; ne = no
	inc	parencnt		; count up parens
	jmp	short cmtxt12
cmtxt11:cmp	ah,')'			; closing paren?
	jne	cmtxt12			; ne = no
	sub	parencnt,1
	jns	cmtxt12			; ns = no underflow
	mov	parencnt,1		; don't underflow
cmtxt12:inc	bx
	mov	cmptab,bx
	mov	cx,cmsiz		; length of command so far
	cmp	cx,4			; got four chars?
	jne	cmtxt12a		; ne = no
	cmp	comand.cmarray,0	; worry about \&<char> as destination?
	je	cmtxt12a		; e = no
	cmp	word ptr [bx-4],'&\'	; starts with array indicator?
	jne	cmtxt12a		; ne = no
	mov	comand.cmper,0		; allow substitution in [...]
	mov	comand.cmarray,0	; say have done array destination test
cmtxt12a:
	cmp	cx,comand.cmblen	; buffer filled?
	ja	cmtxt14			; a = yes, declare error
	jb	cmtxt13			; a = not filled yet
	mov	ah,conout		; notify user that the buffer is full
	mov	dl,bell
	int	dos
	jmp	cmtxt6			; quit

cmtxt13:jmp	cmtxt2

cmtxt14:mov	ah,prstr
	mov	dx,offset cmer09
	int	dos
	jmp	prserr			; declare parse error
cmtxt	endp


; This routine gets a confirm (CR) and displays any extra non-blank text.
; errflag non-zero means suppress "extra text" display in this routine
; because another routine is handling errors.
cmcfrm	proc	far
	mov	bracecnt,0
	mov	comand.cmper,1		; do not react to \%x substitutions
	cmp	cmrptr,offset cmdbuf	; empty buffer?
	je	cmcfr7			; e = yes
	mov	bx,cmrptr		; where to read next
	dec	bx			; last read byte
	cmp	byte ptr [bx],CR	; terminated already?
	je	cmcfr7			; e = yes

cmcfr1:	mov	cmsflg,0ffh		; set space-seen flag (skip spaces)
	call	cmgtch			; get a char
	push	cmrptr
	pop	temp			; remember first non-space position
	jc	cmcfr4			; c = terminator
	dec	temp			; backup to text char
cmcfr3:	mov	cmsflg,0ffh		; set space-seen flag (skip spaces)
	call	cmgtch
	jnc	cmcfr3			; read until terminator
cmcfr4:	cmp	ah,' '
	je	cmcfr3			; ignore ending on space
	cmp	ah,escape		; escape?
	jne	cmcfr5			; ne = no
	call	esceoc			; do standard end of cmd on escape
	mov	ax,cmrptr
	cmp	ax,temp			; started text yet?
	je	cmcfr1			; e = no
	jmp	short cmcfr3		; try again
cmcfr5: cmp	ah,'?'			; curious?
        jne	cmcfr6			; ne = no
	mov	cmhlp,offset cmin00	; msg Confirm with c/r
	mov	cmsiz,0			; no keyword
	mov	errflag,0
	jmp	cmkyhlp			; do help
cmcfr6:	cmp	ah,cr			; the confirmation char?
	jne	cmcfr3			; ne = no
	cmp	errflag,0		; already doing one error?
	jne	cmcfr7			; ne = yes, skip this one
	mov	cx,cmrptr		; pointer to terminator
	mov	dx,temp			; starting place
	sub	cx,dx			; end minus starting point = length
	jle	cmcfr7			; le = nothing to display
	push	dx			; save source pointer
	mov	ah,prstr
	mov	dx,offset cmer07	; ?Ignoring extras
	int	dos
	pop	dx
	mov	bx,1			; stdout handle, cx=count, dx=src ptr
	mov	ah,write2		; allow embedded dollar signs
	int	dos
	mov	ah,prstr
	mov	dx,offset cmer08	; trailer msg
	int	dos
cmcfr7:	xor	ax,ax
	mov	errflag,al
	call	optionclr		; clear parser options
	clc				; return confirmed
	ret
cmcfrm	endp

;;; Routines to get and edit incoming text.

; Detect '\%x' (x = '0' or above) and substitute the matching Macro string
; in place of the '\%x' phrase in the user's buffer. If comand.cmper != 0
; then treat '\%' as literal characters. If no matching parameter exists
; just remove '\%x'. Ditto for \v(variable). Returns carry clear if nothing
; done, else carry set and new text already placed in user's buffer.
; Includes \v(variable) and \$(Environment variable) and \m(macro name).
; Uses depth-first recursion algorithm. All registers preserved.
subst	proc	near
	cmp	comand.cmper,0		; recognize '\%','\v(','\$(','\m(' ?
	jne	subst0			; ne = no, treat as literals
	cmp	taklev,0		; in a Take file?
	je	subst0a			; e = no
	push	bx
	mov	bx,takadr
	cmp	[bx].takper,0		; expand macros?
	pop	bx
	je	subst0a			; e = yes
subst0:	clc				; report out to application
	ret
subst0a:cmp	subtype,'0'		; doing \numbers already?
	jne	subst0b			; ne = no
	jmp	subst30			; continue to parse digits

subst0b:cmp	ah,'\'			; is it the first char of the pattern?
	jne	subst1			; ne = no, try next
	cmp	subcnt,1		; \\?
	jne	subst0c			; ne = no
	mov	subcnt,0		; clear state and pass back one \
	clc
	ret
subst0c:cmp	endedbackslash,0	; ended sub macro on backslash?
	jne	subst1a			; ne = yes
	inc	subcnt			; say first char (\) is matched
	and	subcnt,1		; modulo 2
	mov	subtype,ah
	stc				; do not pass to application
	ret

subst1:	cmp	subcnt,1		; first char matched already?
	ja	subst3			; a = first two have been matched
	jb	subst0			; b = none yet
	mov	al,ah			; test kind of substitution
	or	al,20h			; convert to lower case
	cmp	ah,'%'			; second match char, same?
	je	subst2			; e = yes
	cmp	al,'v'			; \v(...)?
	je	subst2			; e = yes
	cmp	al,'$'			; \$(..)?
	je	subst2			; e = yes
	cmp	al,'m'			; \m(..)?
	je	subst2			; e = yes
	cmp	comand.cmarray,0	; allow array recognition?
	jne	subst1d			; ne = no
	cmp	al,'&'			; \&<char>[..]?
	je	subst2			; e = yes
subst1d:				; start \number
	cmp	comand.cmdonum,0	; convert \numbers allowed?
	je	subst1c			; e = no
	cmp	ah,'{'			; \{number}?
	je	subst1b			; e = yes
	cmp	al,'d'			; \Dnumber?
	je	subst1b			; e = yes
	cmp	al,'o'			; \Onumber?
	je	subst1b			; e = yes
	cmp	al,'x'			; \Xnumber?
	je	subst1b			; e = yes
	cmp	ah,'0'			; in range for numbers?
	jb	subst1c			; b = no
	cmp	ah,'9'
	ja	subst1c			; a = no
subst1b:mov	subtype,'0'		; mark as numeric
	mov	subcnt,2		; matched second introducer
	push	bx
	mov	bx,cmrptr
	sub	bx,2			; point at \
	mov	numtmp,bx		; where \number starts
	pop	bx
	stc				; do not pass to application
	ret
					; end \number
subst1c:cmp	al,'f'			; \fname(..)?
	jne	subst1a			; ne = no
	mov	subtype,al		; remember type
	inc	subcnt			; count match
	jmp	subst10			; read more bytes internally

subst1a:push	ax			; replay bytes as literals
	mov	al,subcnt		; previously matched bytes
	xor	ah,ah
	inc	ax			; plus current byte
	sub	cmrptr,ax
	mov	replay_cnt,ax		; trailer bytes, amount to replay
	pop	ax
	mov	subcnt,0		; mismatch, clear match counter
	mov	subtype,0
	mov	endedbackslash,0
	stc				; reread from input
	ret

subst2:	cmp	al,'%'			; starting \%?
	jne	subst2b			; ne = no
	cmp	subtype,'v'		; doing \v(..)? (dirs of c:\%foobar)
;;;	je	subst1a			; e = yes, don't expand \% inside

subst2b:mov	subtype,al		; remember kind of substitution
	inc	subcnt			; count match
	cmp	al,'%'
	je	subst10
	cmp	al,'&'			; doing \&<char>[..]?
	je	subst10			; e = yes
	stc				; do not pass to application
	ret

subst3:	cmp	subtype,'v'		; doing \v(..)?
	je	subst3a			; e = yes
	cmp	subtype,'$'		; doing \$(..)?
	je	subst3a			; e = yes
	cmp	subtype,'m'		; doing \m(..)?
	je	subst3a			; e = yes
	mov	subcnt,0		; clear match counter
	jmp	subst1a			; no match

subst3a:cmp	ah,'('			; have leading parenthesis?
	jne	subst1a			; ne = no, mismatch, exit
	jmp	subst10			; process \v(..), \$(..), \m(..)

					; \fname(..), \m(..), \v(..), \$(..)
subst10:push	bx			; save working regs
	push	cx
	push	es
	push	cmptab			; save current keyword parsing parms
	push	cmsptr
	push	cmsiz
	push	valtmp
	push	dx
	mov	subcnt,0		; clear match counter
	mov	cmhlp,0
	mov	ax,cmrptr
	mov	valtmp,ax		; remember current read pointer
	mov	cmsptr,ax		; start of word
	mov	cmptab,offset valtab	; table of keywords for \v(..)
	cmp	subtype,'v'		; \v(..)?
	je	subst10a		; e = yes
	mov	cmptab,offset envtab	; Environment variable table \$(..)
	cmp	subtype,'$'		; \$(..)?
	je	subst10a		; e = yes
	mov	cmptab,offset evaltab	; evaluate (name) table
	cmp	subtype,'f'		; \fname()?
	je	subst10a		; e = yes
	mov	cmptab,offset mcctab	; main Macro table for \m(..)
subst10a:mov	cmsflg,0		; see leading spaces/tabs
	mov	cmsiz,0			; word size
subst11:mov	ch,subtype		; save \type
	push	cx
	call	cmgtch			; read a character into ah
	rcl	al,1			; put carry bit into low bit of al
	pop	cx
	xchg	ch,subtype		; recover \type
	rcr	al,1			; recover carry bit
	jnc	subst13			; nc = non-terminator

	cmp	subtype,'%'		; \%<char>?
	jne	subst11d		; ne = no
	cmp	ah,' '			; question or similar?
	jbe	subst13			; be = no, a funny
	inc	cmrptr			; accept the terminator as data
	jmp	subst13
subst11d:
	cmp	subtype,'m'		; discard trailing spaces for these
	je	subst11b
	cmp	subtype,'v'
	je	subst11b
	cmp	subtype,'&'
	je	subst11b
	cmp	subtype,'$'
	jne	subst11c
subst11b:cmp	ah,' '			; space terminator?
	je	subst11			; e = yes, ignore it
subst11c:cmp	ah,'?'			; need help?
	jne	subst11a		; ne = no
	call	cmkyhlp			; display help information
	jmp	short subst11

subst11a:cmp	ah,escape		; escape?
	jne	subst12			; ne = no
	cmp	in_showprompt,0		; making new prompt?
	jne	subst12			; ne = yes, include literal escape
	call	cmkyesc			; process escape
	jmp	short subst11		; failed, ignore esc, read more
					;
subst12:cmp	subtype,'f'		; \fname(..)?
	je	subst12a		; e = yes, else no need to replay
	jmp	subst17

subst12a:mov	bx,cmsptr		; where \fname() word started
	sub	bx,2			; back over "\f" part
	mov	cx,cmrptr		; last read + 1
	sub	cx,bx			; bytes in \foobar
	mov	cmrptr,bx		; reread point is the \
	add	replay_cnt,cx		; bytes to reread (+external \ fails)
	jmp	subst17

subst13:inc	cmsiz			; count user chars
	cmp	subtype,'%'		; \%<char>?
	jne	subst13j		; ne = no
	cmp	ah,'0'			; large enough?
	jb	subst17			; b = no, fail
	mov	cmsiz,3+1		; size is three bytes, plus dec below
	sub	cmsptr,2		; backup to \
	jmp	short subst13b
subst13j:cmp	subtype,'f'		; \fname(...)?
	jne	subst13a		; ne = no
	cmp	ah,'('			; look for "(" as terminator
	je	subst13b		; e = found, lookup "name" as keyword
	cmp	ah,'0'			; numeric?
	jb	subst12a		; b = no, end of string
	cmp	ah,'9'
	jbe	subst11			; be = yes, keep reading
	call	tolowr			; to lower case
	cmp	ah,'z'
	ja	subst12a		; a = non-alpha, end of string
	cmp	ah,'a'
	jae	subst11			; ae = alpha, keep reading
	jmp	short subst12a		; yes, stop here

subst13a:cmp	subtype,'&'		; \&c[..]?
	jne	subst13i		; ne = no
	cmp	ah,']'			; end bracket?
	jne	subst11			; ne = no, keep going
	jmp	short subst13b		; have it
subst13i:cmp	ah,')'			; end bracket?
	jne	subst11			; ne = no, keep looking
subst13b:dec	cmsiz			; omit user's ')' from tests
	cmp	subtype,'&'		; \&char[..]?
	je	subst20			; e = yes, have all bytes
	cmp	subtype,'$'		; \$(..)?
	je	subst13c		; e = yes, no keyword in table
	push	cmsptr			; save pointer
subst13g:mov	bx,cmsptr
	cmp	byte ptr [bx],' '	; leading spaces?
	jne	subst13h		; ne = no
	inc	cmsptr			; look at next char
	jmp	short subst13g
subst13h:call	getkw			; \m(..) and \v(..) test for keyword
	pop	cmsptr
	jc	subst12			; c = failure
	jmp	short subst13d		; success

subst13c:call	envvar			; search Environment for the word
	jc	subst12			; c = failure
	mov	bx,V_environ		; set bx to kind of value for valtoa
	jmp	short subst13f

subst13d:cmp	subtype,'f'		; doing \fname(...)?
	jne	subst13f		; ne = no
	mov	subcnt,0		; clear \f match indicator
	add	bx,[bx]			; add length of keyword text (CNT)
	add	bx,2			; point at value field
	mov	bx,[bx]			; get value
subst13e:mov	evaltype,bx		; remember kind of operation
	call	evaltoa			; do \fname argument evaluation
	jc	subst12a		; error, reparse
	jmp	subst17

subst13f:mov	ax,valtmp		; where word started
	sub	ax,3			; backup to "\v(" or "\$("
	cmp	subtype,'%'		; doing \%<char>?
	jne	subst13k		; ne = no
	inc	ax			; one less field byte than others
subst13k:mov	cmrptr,ax		; write output where backslash was
	call	bufreset		; resets cmwptr too
	xor	dx,dx			; signal valtoa to not add trailing sp
	cmp	subtype,'$'		; \$(..)?
	je	subst14			; e = yes, no keyword structure
	mov	cx,[bx]			; bx = structure pointer, cx=keyw len
	add	cx,2			; skip count byte
	add	bx,cx			; point at 16 bit value field
	mov	bx,[bx]			; get value to bx for valtoa
subst14:cmp	taklev,maxtak		; room in take level?
	jb	subst15			; b = yes
	mov	dx,offset stkmsg	; out of work space msg
	mov	ah,prstr		; display error message
	int	dos
	jmp	subst17

					; \&char[..]
subst20:mov	ax,valtmp		; where <char> started
	mov	bx,ax
	cmp	byte ptr [bx+1],'['
	jne	subst12a

	sub	ax,2			; backup to "\&<char>["
	mov	cmrptr,ax		; write output where backslash was
	add	cmsptr,2		; point after "[" for index math
	call	bufreset		; resets cmwptr too
	push	si
	mov	si,cmsptr		; start of string after "["
	mov	cx,1024			; cmsiz ignores leading spaces
subst20a:cmp	byte ptr [si],' '	; remove leading spaces
	jne	subst20b
	inc	si
	loop	subst20a
subst20b:push	si			; save starting point
	mov	cx,1024			; assumed max string in [..]
	xor	bx,bx
	cld
subst20c:lodsb
	cmp	al,']'			; terminator?
	je	subst20e		; e = yes
	inc	bx			; count string chars
subst20d:loop	subst20c
subst20e:pop	si			; recover starting point
	push	si
	mov	domath_ptr,si		; ptr to string
	mov	domath_cnt,bx		; length of string
	call	domath			; string to binary in dx:ax
	pop	si
	mov	si,cmsptr		; points just after "\&<char>["
	mov	bl,[si-2]		; back up to <char>
	cmp	bl,'_'			; arg list \$_[list element]?
	jne	subst20g		; ne = no
	pop	si			; clean stack
	cmp	ax,9			; too large?
	ja	subst17			; a = yes, do nothing
	push	ax
	mov	ax,4+2			; want four bytes plus count
	call	malloc			; to seg in ax
	mov	es,ax
	pop	ax
	mov	word ptr es:[2],'%\'	; compose string \%<digit>
	add	al,'0'			; use index of 0..9
	xor	ah,ah
	mov	word ptr es:[4],ax	; null terminate
	mov	cx,3
	mov	word ptr es:[0],cx	; three bytes of text
	mov	ax,es			; setup for below
	jmp	short subst20h		; compose the macro

subst20g:and	bl,not 20h		; upper case it
	cmp	bl,'Z'			; last <char>
	ja	subst20f		; a = out of range
	sub	bl,'@'			; remove bias
	xor	bh,bh
	shl	bx,1			; address words
	mov	si,marray[bx]		; get segment of string storage
	or	si,si			; any?
	jz	subst20f		; z = none
	mov	es,si			; look at segment of array
	cmp	es:[0],ax		; number of elements vs index above
	jbe	subst20f		; be = out of range, quit
	mov	si,ax
	shl	si,1			; index words
	mov	ax,es:[si+2]		; get definition string segment to ax
	pop	si
	or	ax,ax			; any?
	jz	subst17			; z = no, empty
subst20h:mov	es,ax			; string seg
	mov	cx,es:[0]		; length of definition
	jcxz	subst17			; z = empty
	call	takopen_sub		; open take as text substitution
	jc	subst17			; c = cannot open
	mov	bx,takadr		; pointer to new Take structure
	mov	[bx].takbuf,es		; segment of Take buffer
	mov	[bx].takcnt,cx		; number of unread bytes
	jmp	subst17

subst20f:pop	si			; failure
	jmp	subst17

subst15:mov	subcnt,0		; clear match indicator
	call	takopen_sub		; open take as text substitution
	jc	subst17			; c = failed
	mov	cx,bx			; value command kind, save
	mov	ax,tbufsiz		; bytes of buffer space wanted
	call	malloc
	jc	subst17			; c = failed
	mov	bx,takadr		; point to structure
	or	[bx].takattr,take_malloc ; remember to dispose via takclos
	mov	[bx].takbuf,ax		; seg of buffer
	mov	es,ax			; ES:DI will be buffer pointer
	mov	di,[bx].takptr		; where to write next
	mov	[bx].takper,0		; expand macros
cmp subtype,'v'	; \v(..)?
je subst16b	; e = yes, don't expand macros within it
	cmp	subtype,'m'		; \m(..)?
	jne	subst16a		; ne = no
subst16b:
	mov	[bx].takper,1		; do not expand macros in \m(..)
subst16a:mov	bx,cx			; value command
	call	valtoa			; make text be an internal macro
	mov	bx,takadr
	mov	[bx].takcnt,di		; length
subst17:
	pop	dx
	mov	subtype,0
	pop	valtmp
	pop	cmsiz			; restore borrowed keyword parameters
	pop	cmsptr
	pop	cmptab
	pop	es
	pop	cx
	pop	bx
	stc				; carry = signal reread source
	ret
					; convert \number
subst30:cmp	ah,'?'			; asking for help?
	jne	subst30a		; ne = no
	mov	cmsiz,0			; no keyword to expand
	push	cmhlp			; save existing help
	mov	cmhlp,offset n1hlp	; our message
	call	cmkyhlp			; display help message
	pop	cmhlp			; restore old help
	stc				; buffer has been cleaned by cmkyhlp
	ret
subst30a:push	si
	mov	si,numtmp		; where \ starts
	mov	atoibyte,1		; convert only one character
	mov	cx,cmrptr
	sub	cx,numtmp		; byte count to examine
	mov	atoi_cnt,cx		; tell atoi the count
	call    atoi			; value to dx:ax
	mov	cmsflg,0		; clear space-seen flag
	jnc	subst31			; nc = converted a value
	cmp	atoi_err,4		; insufficient bytes to resolve
	je	subst30b		; e = yes, get more
	mov	cx,cmrptr		; replay complete failure
	sub	cx,numtmp		; where \ started
	add	replay_cnt,cx		; count to replay
	mov	si,numtmp
	mov	cmrptr,si		; replay from here
	mov	subcnt,0		; mismatch, clear match counter
	mov	subtype,0		; and substitution type 
	mov	endedbackslash,0	; general principles
subst30b:pop	si
	stc				; carry set to read more bytes
	ret
subst31:pop	si
	cmp	atoi_err,1		; success and terminated?
	jne	subst31a		; ne = no
	mov	ah,al			; ah now has value for app
	mov	subtype,0
	mov	subcnt,0
	inc	report_binary		; signal have number to report to app
	clc
	ret

subst31a:cmp	atoi_err,0		; success, can accept more data?
	jne	subst32			; ne = no
	stc				; c = return to read more data
	ret
subst32:mov	ah,al			; ah now has value for app
	mov	subtype,0
	mov	subcnt,0
	push	ax
	dec	cmrptr			; reread break byte
	mov	replay_cnt,1		; for non-\
	push	bx
	mov	bx,cmrptr		; last read byte
	mov	ah,[bx]			; get break byte
	pop	bx
	inc	report_binary		; signal have number to report to app
	cmp	ah,'\'			; substitution introducer?
	jne	subst34			; ne = no, pass it to app
	inc	cmrptr			; step over read byte
	mov	replay_cnt,0		; no replay
	mov	subcnt,1		; mark \ introducer as have been read
subst34:pop	ax
	clc
	ret
subst	endp

; Make an internal macro defined as the text for one of the value variables.
; Use incoming DX as trailing space suppression flag, if null.
valtoa	proc	near
	push	di			; save starting di
	push	dx			; save trailing space flag
	mov	word ptr es:[di],0	; fill buffer with sweet nothings
					; BX has index of variable
	cmp	bx,V_environ		; \$() Environment?
	jne	valtoa1			; ne = no
	mov	cx,envlen		; string length
	jcxz	valtoa0			; z = empty
	cmp	cx,tbufsiz-2		; greater than current buffer?
	jbe	valtoa0a		; be = no
	push	cx
	mov	ax,[bx].takbuf		; old buffer
	mov	es,ax			; new ES from above
	mov	ah,freemem		; free it
	int	dos
	mov	ax,cx			; bytes wanted
	call	malloc			; get more space
	mov	bx,takadr
	mov	[bx].takbuf,ax		; seg of macro def
	mov	ES,ax			; new ES
	or	[bx].takattr,take_malloc ; remember to dispose via takclos
	pop	cx
valtoa0a:
	push	si
	push	ds
	lds	si,envadr		; ds:si is source from Environment
	cld
	rep	movsb			; copy string
	pop	ds
	pop	si
valtoa0:jmp	valtoa90
	
valtoa1:cmp	bx,V_argc		; \v(argc)?
	jne	valtoa2			; ne = no
	call	wrtargc			; write argc
	jmp	valtoa90
valtoa2:cmp	bx,V_count		; \v(count)?
	jne	valtoa3			; ne = no
	call	wrtcnt			; write it
	jmp	valtoa90
valtoa3:cmp	bx,V_date		; \v(date)?
	jne	valtoa4
	call	wrtdate
	jmp	valtoa90
valtoa4:cmp	bx,V_errlev		; \v(errorlevel)?
	jne	valtoa5			; ne = no
	call	wrterr
	jmp	valtoa90
valtoa5:cmp	bx,V_dir		; \v(dir)?
	jne	valtoa6
	call	wrtdir
	jmp	valtoa90
valtoa6:cmp	bx,V_time		; \v(time)?
	jne	valtoa7
	call	wrttime
	jmp	valtoa90
valtoa7:cmp	bx,V_version		; \v(version)?
	jne	valtoa8			; ne = no
	mov	ax,version		; get version such as 300
	call	fdec2di			; convert binary to asciiz
	jmp	valtoa90
valtoa8:cmp	bx,V_platform		; \v(platform)?
	jne	valtoa9			; ne = no
	call	wrtplat			; get machine name, e.g. "IBM-PC"
	jmp	valtoa90
valtoa9:cmp	bx,V_system		; \v(system)?
	jne	valtoa10		; ne = no
	call	wrtsystem		; get "MS-DOS" string
	jmp	valtoa90
valtoa10:cmp	bx,V_kbd		; \v(keyboard)?
	jne	valtoa11		; ne = no
	call	wrtkbd			; 88 or 101 value
	jmp	valtoa90
valtoa11:cmp	bx,V_speed		; \v(speed)?
	jne	valtoa12		; ne = no
	push	di
	call	fgetbaud		; read baud rate from hardware
	pop	di
	mov	bx,portval
	mov	ax,[bx].baud
	cmp	al,byte ptr bdtab	; index versus number of table entries
	jb	valtoa11a		; b = index is in the table
	mov	si,offset cmunk-2	; unrecognized value, say "unknown"
	mov	bx,7			; length of string
	jmp	short valtoa11c
valtoa11a:mov	si,offset bdtab		; ascii rate table
	mov	cl,[si]			; number of entries
	inc	si			; point to an entry
valtoa11b:
	mov	bx,[si]			; length of text string
	cmp	ax,[si+bx+2]		; our index vs table entry index
	je	valtoa11c		; e = match
	add	si,bx			; skip text
	add	si,4			; skip count and index word
	loop	valtoa11b		; look again
	mov	si,offset cmunk-2	; unrecognized value, say "unknown"
	mov	bx,7			; length of string
valtoa11c:mov	cx,bx			; length of string
	add	si,2			; point at string
	rep	movsb			; copy string
	jmp	valtoa90

valtoa12:cmp	bx,V_program		; \v(program)?
	jne	valtoa13		; ne = no
	call	wrtprog			; get "MS-DOS_KERMIT" string
	jmp	valtoa90
valtoa13:cmp	bx,V_status		; \v(status)?
	jne	valtoa14		; ne = no
	call	wrtstat			; compose status string
	jmp	valtoa90
valtoa14:cmp	bx,V_ndate		; \v(ndate)?
	jne	valtoa15		; ne = no
	call	wrtndate
	jmp	valtoa90
valtoa15:cmp	bx,V_port		; \v(port)? or \v(line)?
	jne	valtoa16		; ne = no
	call	wrtport
	jmp	valtoa90
valtoa16:cmp	bx,V_terminal		; \v(terminal)?
	jne	valtoa17		; ne = no
	call	wrtterm
	jmp	valtoa90
valtoa17:
ifndef	no_tcp
	cmp	bx,V_session		; \v(session) (internal Telnet)?
	jne	valtoa18		; ne = no

	mov	ax,sescur		; get internal Telnet session ident
	inc	ax			; count from 1 for users (0 == none)
	call	fdec2di			; convert binary to asciiz
	jmp	valtoa90
endif	; no_tcp
valtoa18:cmp	bx,V_ntime		; \v(ntime) (seconds in day)?
	jne	valtoa19		; ne = no
	mov	ah,gettim		; get DOS time of day
	int	dos			; ch=hh, cl=mm, dh=ss, dl=0.01 sec
	mov	bx,60
	mov	al,ch			; hours
	mul	bl			; to minutes
	xor	ch,ch
	add	ax,cx			; plus minutes
	mov	cl,dh			; preserve seconds
	mul	bx			; need carry out to DX
	add	ax,cx			; add seconds
	adc	dx,0
	push	di
	push	es
	mov	di,ds
	mov	es,di
	mov	di,offset cmdbuf-30-cmdblen
	call	flnout			; 32 bit converter
	mov	dx,offset cmdbuf-30-cmdblen
	call	strlen
	mov	si,dx
	pop	es
	pop	di
	cld
	rep	movsb
	mov	word ptr [di],0020h	; space, null
	jmp	valtoa90

valtoa19:cmp	bx,V_dosver		; \v(dosversion)?
	jne	valtoa20		; ne = no
	mov	ax,dosnum		; DOS verson, major high, minor low
	push	ax
	xchg	ah,al
	xor	ah,ah
	call	fdec2di			; write major
	pop	ax
	xor	ah,ah
	cmp	al,10			; less than 10?
	ja	valtoa19a		; a = no
	mov	byte ptr es:[di],'0'	; use two digits for minor
	inc	di
valtoa19a:
	call	fdec2di			; write minor
	jmp	valtoa90
valtoa20:
ifndef	no_tcp
	cmp	bx,V_tcpip		; \v(tcp_status)?
	jne	valtoa21		; ne = no
					; SUCCESS	0
					; NO_DRIVER	1
					; NO_LOCAL_ADDRESS 2
					; BOOTP_FAILED	3
					; RARP_FAILED	4
					; BAD_SUBNET_MASK 5
					; SESSIONS_EXCEEDED 6
					; HOST_UNKNOWN	7
					; HOST_UNREACHABLE 8
					; CONNECTION_REJECTED 9
	mov	ax,tcp_status		; get tcp status, if any
	call	fdec2di			; write value
	jmp	valtoa90
endif	; no_tcp

valtoa21:cmp	bx,V_parity		; \v(parity)?
	jne	valtoa22		; ne = no
	mov	bx,portval
	mov	bl,[bx].parflg		; parity
	xor	bh,bh
	shl	bx,1			; address words
	cld
	mov	si,parmsgtab[bx]	; offset of parity name string
valtoa21a:lodsb
	stosb
	or	al,al			; end of string?
	jnz	valtoa21a		; nz = no
	mov	word ptr es:[di-1],0020h ; space, null
	jmp	valtoa90

valtoa22:cmp	bx,V_carrier		; \v(carrier)?
	jne	valtoa23		; ne = no
	mov	bl,flags.carrier	; carrier
	and	bl,1			; just one bit
	xor	bh,bh
	shl	bx,1			; address words
	cld
	mov	si,onoffmsgtab[bx]	; offset of carrier string
valtoa22a:lodsb
	stosb
	or	al,al			; end of string?
	jnz	valtoa22a		; nz = no
	mov	word ptr es:[di-1],0020h ; space, null
	jmp	valtoa90

valtoa23:cmp	bx,V_prompt		; \v(prompt)?
	jne	valtoa24		; ne = no
	push	si
	mov	si,prmptr		; current prompt raw text
	cld
valtoa23a:lodsb				; read a byte
	stosb				; store
	or	al,al			; end of string?
	jnz	valtoa23a		; z = no
	pop	si
	dec	di			; don't show trailing null
	mov	word ptr es:[di],0020h	; space, null
	jmp	valtoa90

valtoa24:cmp	bx,V_cps		; \v(cps)?
	jne	valtoa25		; ne = no
	push	di
	mov	di,offset decbuf+200	; must be in DS data seg
	call	shovarcps		; use worker in msssho.asm
	mov	si,offset decbuf+200	; copy this buffer to es:di buffer
	pop	di
	cld
	mov	cx,7			; limit loop
valtoa24a:lodsb				; read result
	or	al,al			; terminator?
	jz	valtoa24b		; z = yes, stop
	stosb
	loop	valtoa24a
valtoa24b:jmp	valtoa90

valtoa25:cmp	bx,V_space		; \v(space)?
	jne	valtoa26		; ne = no
	xor	cx,cx			; drive letter (null means current)
	call	fdskspace		; compute space, get letter into CL
	jnc	valtoa25a		; nc = success
	xor	ax,ax
	xor	dx,dx
valtoa25a:
	push	di
	push	es
	mov	di,ds
	mov	es,di
	mov	di,offset cmdbuf-30-cmdblen
	call	flnout
	mov	dx,offset cmdbuf-30-cmdblen
	call	strlen
	mov	si,dx
	pop	es
	pop	di
	cld
	rep	movsb
	mov	word ptr [di],0020h	; space, null
	jmp	valtoa90

valtoa26:cmp	bx,V_startup		; \v(startup)?
	jne	valtoa27		; ne = no
	push	si
	mov	si,offset startup	; startup directory string
	mov	dx,si
	call	strlen			; get length to cx
	rep	movsb			; copy string
	pop	si
	mov	word ptr es:[di],0020h	; space, null
	jmp	valtoa90

valtoa27:cmp	bx,V_console		; \v(console)?
	jne	valtoa28		; ne = no
	mov	ax,1a00h		; get ANSI.SYS installed state
	int	2fh
	mov	si,offset ansiword	; assume installed
	or	al,al			; installed?
	jnz	valtoa27a		; nz = yes
	mov	si,offset noneword	; say "NONE"
valtoa27a:lodsb				; read a byte
	stosb				; store a byte
	or	al,al			; at end of string?
	jnz	valtoa27a		; nz = no
	mov	word ptr es:[di-1],0020h ; space, null
	jmp	valtoa90

valtoa28:cmp	bx,V_monitor		; \v(monitor)?
	jne	valtoa29		; ne = no
	mov	si,offset colormsg	; assume color monitor
	cmp	crt_mode,7		; mono text
	jne	valtoa28a		; ne = no
	mov	si,offset monomsg	; say mono
valtoa28a:jmp	short valtoa27a		; copy material

valtoa29:cmp	bx,V_cmdlevel		; \v(cmdlevel)?
	jne	valtoa30		; ne = no
	mov	al,taklev		; take level
	xor	ah,ah
	call	fdec2di			; write value
	jmp	valtoa90

valtoa30:cmp	bx,V_input		; \v(input)?
	jne	valtoa31		; ne = no
	push	temp
	push	si
	push	DS
	push	es
	call	buflog			; get INPUT buffer pointers
	mov	ax,es			; seg of input buffer
	pop	es
	jcxz	valtoa30b		; z = empty
	cmp	cx,tbufsiz-2-1		; buffer plus null terminator
	jbe	valtoa30a		; be = enough space to hold text
	mov	cx,tbufsiz-2-1		; limit text
valtoa30a:mov	DS,ax			; ds:si is input buffer
	cld
	rep	movsb
	xor	al,al
	mov	es:[di],al		; null terminator
valtoa30b:pop	DS
	pop	si
	pop	temp
	jmp	valtoa90

valtoa31:cmp	bx,V_query		; \v(query)?
	jne	valtoa32		; ne = no
	mov	word ptr es:[di],0020h 	; space, null
	cmp	queryseg,0		; is there an malloc'd seg to use?
	je	valtoa90		; e = no
	push	es
	mov	si,queryseg
	mov	es,si
	mov	cx,es:[0]		; get length of string
	pop	es
	push	si
	cmp	cx,tbufsiz-2		; greater than current buffer?
	jbe	valtoa31a		; be = no
	push	cx
	mov	ax,[bx].takbuf		; old buffer
	mov	es,ax			; new ES from above
	mov	ah,freemem		; free it
	int	dos
	mov	ax,cx			; bytes wanted
	call	malloc			; get more space
	mov	bx,takadr
	mov	[bx].takbuf,ax		; seg of macro def
	mov	ES,ax			; new ES
	or	[bx].takattr,take_malloc ; remember to dispose via takclos
	pop	cx

valtoa31a:push	ds
	mov	si,queryseg		; get segment of query string
	mov	ds,si
	mov	si,2			; skip count word
	cld
	rep	movsb			; copy to es:di
	pop	ds
	pop	si
	jmp	valtoa90

valtoa32:cmp	bx,V_sysid		; \v(sysid)?
	jne	valtoa33		; ne = no
	mov	ax,'8U'			; always report U8
	stosw
	jmp	valtoa90

valtoa33:cmp	bx,V_charset		; \v(charset)?
	jne	valtoa34		; ne = no
	mov	ax,'PC'
	stosw				; CP prefix
	mov	ax,flags.chrset		; get current Code Page
	call	fdec2di
	jmp	valtoa90

valtoa34:cmp	bx,V_inpath		; \v(inpath)?
	jne	valtoa35		; ne = no
	mov	si,inpath_seg		; get segment of in_path string
	or	si,si			; anything there?
	jz	valtoa34b		; z = no
	push	ds
	mov	ds,si
	xor	si,si
	cld
	lodsw				; get count word
	mov	cx,ax
	cmp	cx,64			; keep it reasonable
	jbe	valtoa34a		; be = ok
	mov	cx,64
valtoa34a:rep	movsb			; copy to es:di
	dec	di			; don't include trailing null from env
	pop	ds
valtoa34b:jmp	valtoa90

valtoa35:cmp	bx,V_disk		; \v(disk)?
	jne	valtoa36		; ne = no
	mov	ah,gcurdsk		; get current disk
	int	dos
	add	al,'A'			; make 1 == A (not zero)
	cld
	stosb
	xor	al,al
	mov	es:[di],al
	jmp	valtoa90

valtoa36:cmp	bx,V_cmdfile		; \v(cmdfile)?
	jne	valtoa37		; ne = no
	mov	si,offset cmdfile	; path of last Take file
	mov	dx,si
	call	strlen
	cld
	rep	movsb
	jmp	valtoa90

valtoa37:cmp	bx,V_inidir		; \v(inidir)?
	jne	valtoa38		; ne = no
	mov	si,offset inidir	; path of mskermit.ini
	mov	dx,si
	call	strlen
	cld
	rep	movsb
	jmp	valtoa90

valtoa38:cmp	bx,V_instatus		; \v(instatus)?
	jne	valtoa39		; ne = no
	mov	ax,input_status		; special INPUT status word
	cmp	ax,0			; negative?
	jge	valtoa38a		; ge = no
	mov	byte ptr es:[di],'-'
	inc	di
	neg	ax
valtoa38a:call	fdec2di
	jmp	valtoa90

valtoa39:cmp	bx,V_minput		; \v(minput)?
	jne	valtoa40		; ne = no
	mov	ax,minpcnt		; get minput match count
	call	fdec2di			; convert to decimal
	jmp	valtoa90		; done

valtoa40:cmp	bx,V_return		; \v(return)?
	jne	valtoa41		; ne = no
	mov	si,offset retbuf	; <word count><string from RETURN>
	mov	cx,[si]			; get count word
	add	si,2			; point at string
	cld
	rep	movsb			; copy to variable buffer
	jmp	valtoa90		; done

valtoa41:cmp	bx,V_connection		; \v(connection)?
	jne	valtoa42		; ne = no
	mov	si,offset connmsg	; word "local"
	mov	dx,si
	call	strlen			; length to cx
	cld
	rep	movsb			; copy to variable buffer
	jmp	valtoa90		; done

valtoa42:cmp	bx,V_filespec		; \v(filespec)?
	jne	valtoa43		; ne = no
	mov	si,offset vfile		; last used file transfer name
	mov	dx,si
	call	strlen			; length to cx
	cld
	rep	movsb			; copy to variable buffer
	jmp	valtoa90		; done

valtoa43:cmp	bx,V_fsize		; \v(fsize)?
	jne	valtoa44		; ne = no
	mov	ax,word ptr lastfsize	; sent file, length dword
	mov	dx,word ptr lastfsize+2
valtoa43a:push	di
	push	es
	mov	di,ds
	mov	es,di
	mov	di,offset cmdbuf-30-cmdblen
	call	flnout
	mov	dx,offset cmdbuf-30-cmdblen
	call	strlen
	mov	si,dx
	pop	es
	pop	di
	cld
	rep	movsb
	mov	word ptr [di],0020h	; space, null
	jmp	valtoa90		; done

valtoa44:cmp	bx,V_crc16		; \v(crc16)?
	jne	valtoa45		; ne = no
	mov	ax,crcword		; accumlated CRC-16
	xor	dx,dx			; clear high word
	jmp	short valtoa43a		; common converter

valtoa45:cmp	bx,V_nday		; \v(nday)?
	je	valtoa45a		; e = yes
	cmp	bx,V_day		; \v(day)?
	jne	valtoa80		; ne = no
valtoa45a:
	mov	ah,getdate		; DOS date (cx= yyyy, dh= mm, dl= dd)
	int	dos
	sub	cx,1900			; make 1900 be zero
	cmp	dh,3			; month
	jge	valtoa45b		; ge = beyond Feb
	add	dh,9
	dec	cx			; modify year number
	jmp	short valtoa45c
valtoa45b:
	sub	dh,3
valtoa45c:
	push	bx			; save V_ kind
	mov	al,dl			; day
	xor	ah,ah
	mov	si,ax			; Julian day number, partial
	mov	al,dh			; modified month number
	mov	bx,153
	mul	bx			; 153 * month
	add	ax,2
	mov	bx,5
	div	bx
	add	si,ax			; (153 * m + 2) / 5 + d
	mov	ax,cx			; year since 1900
	mov	bx,1461
	mul	bx
	mov	bx,4
	div	bx
	xor	dx,dx			; clear remainder from division
	add	ax,si			; (1461 * y)/4 + (153 * m + 2)/5 + d
	add	ax,15078		; above plus 15078
	adc	dx,0			; carry out
	mov	bx,7			; modulo 7 setup
	div	bx			; above % 7
	mov	ax,dx			; remainder to ax, discard quotient
	add	ax,3			; plus 3
	xor	dx,dx
	div	bx			; mod 7 again
	mov	ax,dx			; ((above % 7) + 3) % 7) to ax
	pop	bx			; recover V_ kind
	cmp	bx,V_nday		; \v(nday)?
	jne	valtoa45d		; ne = no, must be V_(day)
	add	al,'0'			; add printable bias
	stosw				; ASCII day number + null
	dec	di			; don't count the null
	jmp	short valtoa90		; done
valtoa45d:				; need ASCII string
	mov	bl,3	
	mul	bl			; day number times three chars
	mov	bx,ax			; get 3*day number
	add	bx,offset day		; three char day string
	mov	ax,[bx]
	stosw				; first two bytes
	mov	al,[bx+2]
	xor	ah,ah
	stosw				; last byte and null
	dec	di			; don't count the null
	jmp	short valtoa90		; done

valtoa80:push	bx			; \m(macro_name)
	push	es
	mov	di,bx			; save seg of macro def
	mov	bx,takadr
	test	[bx].takattr,take_malloc ; buffer already allocated?
	jz	valtoa80a		; z = no
	push	es
	mov	ax,[bx].takbuf		; old buffer
	or	ax,ax			; if any allocated
	jz	valtoa80b		; z = none
	mov	es,ax
	mov	ah,freemem		; free it
	int	dos
valtoa80b:and	[bx].takattr,not take_malloc ; say no more freeing needed
	pop	es
valtoa80a:
	mov	[bx].takbuf,di		; seg of macro def
	mov	[bx].takptr,2		; offset of two
	mov	es,di
	mov	cx,es:[0]		; get length of string
	pop	es
	pop	bx
	pop	dx
	pop	di
	mov	di,cx			; report length in di
	clc
	ret
valtoa90:pop	dx			; trailing space flag
	or	dx,dx			; leave the spaces?
	jnz	valtoa91		; nz = yes
	cmp	word ptr es:[di-1],0020h ; trailing space?
	jne	valtoa91		; ne = no
	dec	di			; remove space
valtoa91:pop	ax			; saved starting di
	sub	di,ax			; di = length of the buffer contents
	clc
	ret
valtoa	endp

; Far callable version
fvaltoa	proc	far
	call	valtoa
	ret
fvaltoa	endp

; Make an internal macro defined as the text for one of the value variables.
; Use incoming DX as trailing space suppression flag, if null.
; BX has keyword value (table envtab)
; If these fail they consume their text quietly.
evaltoa	proc	near
	push	dx			; save trailing space flag
	push	si
	push	temp			; save work variable
	mov	al,comand.cmdonum
	push	ax
	mov	comand.cmdonum,0	; kill \number conversion
	call	evarg			; get argument array
	pop	ax
	mov	comand.cmdonum,al	; restore \number conversion state
	mov	ax,valtmp		; where '\fname' started
	sub	ax,2			; back over \f
	mov	cmwptr,ax		; where to write new output
        mov     cmrptr,ax               ; readjust read pointer too
	call	takopen_sub		; open take as text substitution
	jnc	evalt5c			; nc = success
evalt5b:jmp	evalt99			; fail
evalt5c:mov	bx,takadr		; Take structure
	mov	ax,tbufsiz		; bytes of buffer space wanted
	call	malloc
	jc	evalt5b			; c = failed
	mov	[bx].takbuf,ax		; seg of allocated buffer
	or	[bx].takattr,take_malloc ; remember to dispose via takclos
	mov	es,ax
	mov	word ptr es:[0],tbufsiz
	mov	di,[bx].takptr		; where to start writing
	mov	[bx].takcnt,0		; number of unread bytes
	mov	[bx].takper,0
	cmp	evaltype,F_contents	; \fcontents(macro)?
	je	evalt5d			; e = yes
	cmp	evaltype,F_definition	; \fdefinition(macro)?
	je	evalt5d			; e = yes
	cmp	evaltype,F_literal	; \fliteral(string)?
	jne	evalt5e			; ne = no
evalt5d:mov	[bx].takper,1		; treat macro names as literals

evalt5e:mov	bx,takadr
	mov	di,[bx].takptr		; destination for replacment text
	cmp	evaltype,F_length	; \flength(text)?
	jne	evalt6			; ne = no
	mov	ax,arglen		; length of variable name
	call	fdec2di			; convert to ASCII string
	mov	bx,takadr
	sub	di,[bx].takptr		; end minus start
	mov	[bx].takcnt,di		; string length
	jmp	evalt99

evalt6:	cmp	evaltype,F_upper	; \fupper(text)?
	je	evalt6a			; e = yes
	cmp	evaltype,F_lower	; \flower(text)?
	jne	evalt7			; ne = no
evalt6a:mov	si,argptr		; point to argument
	mov	cx,arglen		; length of string
	jcxz	evalt6e			; z = empty
	cld
evalt6b:lodsb				; read from parse buffer
	cmp	evaltype,F_lower	; to lower?
	ja	evalt6c			; a = no, upper
	call	tolowr			; move to lower case
	jmp	short evalt6d
evalt6c:call	toupr			; move to upper case
evalt6d:stosb				; write byte to Take buffer
	loop	evalt6b
evalt6e:mov	bx,takadr
	mov	cx,arglen		; argument length
	mov	[bx].takcnt,cx		; count entered bytes
	jmp	evalt99

evalt7:	cmp	evaltype,F_char		; \fcharacter(n)?
	jne	evalt8			; ne = no
	mov	si,argptr		; point at text of number
	mov	domath_ptr,si
	mov	ax,arglen
	mov	domath_cnt,ax
	call	domath
	jc	evalt7d			; c = failed
	cld
	stosb				; store single byte
	mov	bx,takadr
	mov	[bx].takcnt,1		; one byte as result
evalt7d:jmp	evalt99

evalt8:	cmp	evaltype,F_substr	; \fsubstr(text, n1, n2)?
	jne	evalt9			; ne = no
	xor	ax,ax
	mov	si,argptr[2]		; point to n1 string
	mov	domath_ptr,si
	mov	ax,arglen[2]
	mov	domath_cnt,ax
	call	domath
	jnc	evalt8g			; nc = got a number
evalt8f:xor	ax,ax
	xor	dx,dx
	jmp	short evalt8a
evalt8g:or	dx,dx			; number overflowed to high word?
	jnz	evalt8f			; nz = yes, reset number to zero
	or	ax,ax			; zero?
	jz	evalt8a			; z = yes
	dec	ax			; count from 0 internally
evalt8a:mov	si,argptr		; point at text
	add	si,ax			; point at text[n1]
	mov	cx,arglen		; length of 'text'
	sub	cx,ax			; bytes remaining in 'text'
	jle	evalt8d			; le = nothing left to extract
	push	si
	mov	si,argptr[4]		; point to n2 string
	mov	domath_ptr,si
	mov	ax,arglen[4]
	mov	domath_cnt,ax
	call	domath
	pop	si
	jnc	evalt8b			; nc = got a number
	mov	ax,arglen		; default to full string
	xor	dx,dx
evalt8b:or	dx,dx			; number overflowed to high word?
	jnz	evalt8d			; nz = yes
	cmp	cx,ax			; length available more than needed?
	jbe	evalt8c			; be = no
	mov	cx,ax			; use smaller n2
evalt8c:mov	bx,tbufsiz-2		; unused buffer capacity (tbufsiz-2)
	cmp	cx,bx			; n larger than buffer?
	jbe	evalt8e			; be = no
	mov	ax,cx			; remember amount wanted
	call	evmem			; get more memory, want CX bytes
	xchg	ax,cx			; now ax=amount available, cx=wanted
	cmp	cx,ax			; wanted > available?
	jbe	evalt8e			; be = no
	mov	cx,ax			; limit to available memory
evalt8e:mov	bx,takadr
	mov	[bx].takcnt,cx		; count of bytes
	cld
	rep	movsb			; copy bytes to Take buffer
evalt8d:jmp	evalt99

evalt9:	cmp	evaltype,F_right	; \fright(text, n)?
	jne	evalt10			; ne = no
	mov	si,argptr[2]		; point to n string
	mov	domath_ptr,si
	mov	ax,arglen[2]
	or	ax,ax			; empty field?
	jz	evalt9d			; z = yes, use whole string
	mov	domath_cnt,ax
	call	domath
	cmp	domath_cnt,0
	je	evalt9a			; e = consummed whole string
	mov	arglen,0		; force 0
evalt9d:mov	ax,arglen		; default to full string
	xor	dx,dx
evalt9a:or	dx,dx			; number overflowed to high word?
	jnz	evalt9c			; nz = yes
	mov	cx,arglen		; length of 'text'
	cmp	cx,ax			; length available more than needed?
	jbe	evalt9b			; be = no
	mov	cx,ax			; use smaller n
evalt9b:mov	si,argptr		; start of 'text'
	add	si,arglen		; point at last + 1 byte of 'text'
	sub	si,cx			; minus bytes to be copied
	mov	bx,takadr
	mov	[bx].takcnt,cx		; count of bytes
	cld
	rep	movsb			; copy bytes to Take buffer
evalt9c:jmp	evalt99

evalt10:cmp	evaltype,F_literal	; \fliteral(text)?
	jne	evalt11			; ne = no
	mov	si,argptr		; start of string
	mov	cx,arglen		; length of text (inc leading spaces)
	mov	bx,takadr
	mov	[bx].takcnt,cx		; count of bytes
	cld
	rep	movsb			; copy bytes to Take buffer
	jmp	evalt99

evalt11:cmp	evaltype,F_rpad		; \frpad(text, n, c)?
	jne	evalt12
	mov	si,argptr[2]		; get n
	mov	domath_ptr,si
	mov	ax,arglen[2]
	mov	domath_cnt,ax
	call	domath
	jc	evalt11d		; c = error
	or	dx,dx			; numeric overflow to high word?
	jne	evalt11d		; ne = yes
	mov	bx,takadr
	mov	cx,tbufsiz-2		; unused buffer capacity (tbufsiz-2)
	cmp	ax,cx			; n larger than buffer?
	jbe	evalt11a		; be = no
	call	evmem			; get more memory
	jc	evalt11d		; c = fail
	cmp	ax,cx			; enough?
	jbe	evalt11a		; be = yes
	mov	ax,cx
evalt11a:mov	cx,arglen		; length of text
	cmp	ax,cx			; field (n) shorter than text?
	jae	evalt11b		; ae = no, use full text
	mov	cx,ax			; copy just n of text
evalt11b:sub	ax,cx			; available minus used bytes
	mov	bx,takadr
	mov	[bx].takcnt,cx		; count of bytes
	mov	si,argptr		; text
	cld
	rep	movsb			; copy bytes to Take buffer
	mov	cx,ax			; padding bytes
	jcxz	evalt11d		; z = none
	add	[bx].takcnt,cx		; increase count of bytes
	mov	bx,argptr+4		; point to c
	mov	al,[bx]			; padding character, if any
	cmp	arglen+4,0		; any char given?
	jne	evalt11c		; ne = yes
	mov	al,' '			; else default to space
evalt11c:cld
	rep	stosb			; append byte to Take buffer
evalt11d:jmp	evalt99

evalt12:cmp	evaltype,F_lpad		; \flpad(text, n, c)?
	jne	evalt13
	push	si
	mov	si,argptr[2]		; get n
	mov	domath_ptr,si
	mov	ax,arglen[2]
	mov	domath_cnt,ax
	call	domath
	pop	si
	jc	evalt12e		; c = error
	or	dx,dx			; numeric overflow to high word?
	jne	evalt12e		; ne = yes
	mov	bx,takadr
	mov	cx,tbufsiz-2		; unused buffer capacity (tbufsiz-2)
	cmp	ax,cx			; n larger than buffer?
	jbe	evalt12a		; be = no
	call	evmem			; get more memory
	cmp	ax,cx			; wanted > available?
	jbe	evalt12a		; be = no
	mov	ax,cx			; limit text
evalt12a:sub	ax,arglen		; n - length of 'text'
	jns	evalt12b		; ns = no underflow
	xor	ax,ax			; else omit padding
evalt12b:mov	cx,ax			; padding count
	mov	[bx].takcnt,cx		; count of bytes
	mov	bx,argptr+4		; point to c
	mov	al,[bx]			; padding character, if any
	cmp	arglen+4,0		; any char given?
	jne	evalt12c		; ne = yes
	mov	al,' '			; default to space
evalt12c:cld
	rep	stosb			; copy byte to Take buffer
	mov	cx,arglen		; length of text
	mov	cx,tbufsiz-2		; buffer capacity
	mov	bx,takadr
	sub	cx,[bx].takcnt		; minus bytes written so far
	mov	ax,arglen		; length of 'text'
	cmp	ax,cx			; n larger than buffer?
	jbe	evalt12d		; be = no
	mov	ax,cx
evalt12d:mov	cx,ax			; append count
	mov	bx,takadr
	add	[bx].takcnt,cx		; increase count of bytes
	mov	si,argptr		; start of text
	cld
	rep	movsb			; append byte to Take buffer
evalt12e:jmp	evalt99

evalt13:cmp	evaltype,F_code		; \fcode(char)?
	jne	evalt14			; ne = no
	mov	bx,argptr		; point to char address
	mov	al,[bx]			; original char
	xor	ah,ah
	call	fdec2di			; convert to ASCII string, no '\'
	mov	bx,takadr		;   prefix
	sub	di,[bx].takptr		; end minus start
	mov	[bx].takcnt,di		; string length
	jmp	evalt99

evalt14:cmp	evaltype,F_definition	; \fdefinition(macro)?
	je	evalt14i		; e = yes
	cmp	evaltype,F_contents	; \fcontents(macro)
	jne	evalt15
evalt14i:cmp	arglen,0		; any name?
	jne	evalt14a		; e = yes
	jmp	evalt14x		; fail
evalt14a:mov	si,argptr		; trim trailing spaces from user name
	mov	cx,arglen		; length of raw user string
	mov	bx,si
	add	bx,cx
evalt14j:cmp	byte ptr [bx-1],' '	; trailing space?
	jne	evalt14k		; ne = no
	dec	arglen			; remove it
	dec	bx			; preceeding char
	loop	evalt14j
evalt14k:
	mov	si,offset mcctab	; table of macro names
	cld
	lodsb
	mov	cl,al			; number of macro entries
	xor	ch,ch
	jcxz	evalt14x		; z = none
evalt14b:push	cx			; save loop counter
	lodsw				; length of macro name
	mov	cx,arglen		; length of user's string
	cmp	ax,cx			; mac name shorter that user spec?
	jb	evalt14d		; b = yes, no match
	push	ax
	push	si			; save these around match test
	push	di
	mov	di,argptr		; user's string
evalt14c:mov	ah,[di]
	inc	di
	lodsb				; al = mac name char, ah = user char
	and	ax,not 2020h		; clear bits (uppercase chars)
	cmp	ah,al			; same?
	loope	evalt14c		; while equal, do more
	pop	di
	pop	si			; restore regs
	pop	ax
	je	evalt14e		; e = a match
evalt14d:add	si,ax			; point to next name, add name length
	add	si,2			;  and string pointer
	pop	cx			; recover loop counter
	loop	evalt14b		; one less macro to examine
evalt14x:jmp	evalt99

evalt14e:pop	cx			; pop loop counter above
	cmp	byte ptr[si],0		; name starts with null char?
	jne	evalt14f		; ne = no
	jmp	evalt99			; yes, TAKE file, ignore
evalt14f:mov	ax,[si-2]		; length of macro name
	add	si,ax			; skip over name
	push	es
	mov	es,[si]			; segment of string structure
	xor	si,si			; es:si = address of count + string
	mov	ax,es
	mov	cx,es:[si]		; length of string
	mov	arglen+2,cx		; save length here
	mov	argptr+2,ax		; save es of es:si here
	pop	es
	call	evmem			; get new memory, set new ES:DI
	cmp	cx,arglen+2		; enough to hold material?
	jae	evalt14h		; ae = yes
	mov	arglen+2,cx		; shrink string size too

evalt14h:push	ds
	mov	bx,takadr
	mov	cx,arglen+2		; length of string
	mov	[bx].takcnt,cx		; macro length
	mov	[bx].takptr,2		; offset of text in destination
	mov	ax,argptr+2		; seg of string
	mov	ds,ax
	mov	si,2			; offset of string
	cld
	rep	movsb			; copy string
	pop	ds
	jmp	evalt99

evalt15:cmp	evaltype,F_maximum	; \fmaximum(n1, n2)?
	je	evalt15a		; e = yes
	cmp	evaltype,F_minimum	; \fminimum(n1, n2)?
	jne	evalt16			; ne = no
evalt15a:push	si
	mov	si,argptr[0]		; point to n1 string
	mov	domath_ptr,si
	mov	ax,arglen[0]
	mov	domath_cnt,ax
	call	domath
	pop	si
	jc	evalt15x		; c = failure
	push	ax			; save result
	push	dx
	push	si
	mov	si,argptr[2]		; point to n2 string
	mov	domath_ptr,si
	mov	ax,arglen[2]
	mov	domath_cnt,ax
	call	domath
	pop	si
	pop	cx			; high first value
	pop	bx			; low first value
	jc	evalt15x		; c = failure
	mov	temp,0			; assume reporting n1, subscript 0
	cmp	cx,dx			; n1 > n2?
	jg	evalt15e		; g = yes
	jl	evalt15d		; l = no, but less than
	cmp	bx,ax			; low order n1 >= n2?
	jge	evalt15e		; ge = yes
evalt15d:mov	temp,2			; say n2 is larger
evalt15e:cmp	evaltype,F_maximum	; return max of the pair?
	je	evalt15f		; e = yes
	xor	temp,2			; change subscript
evalt15f:push	si
	mov	bx,temp			; get subscript of reportable
	mov	si,argptr[bx]
	mov	cx,arglen[bx]
	cld
	rep	movsb			; copy original string
	xor	al,al
	stosb				; and null terminate
	pop	si
	mov	bx,takadr
	sub	di,[bx].takptr		; bytes consumed
	mov	[bx].takcnt,di
evalt15x:jmp	evalt99

evalt16:cmp	evaltype,F_index	; \findex(pat, string, [offset])
	je	evalt16common
	cmp	evaltype,F_rindex	; \frindex(pat, string, [offset])
	jne	evalt17
evalt16common:				; used for \frindex too
	cmp	arglen+4,0		; optional offset given?
	je	evalt16a		; e = no, use userlevel 1
	push	si
	mov	si,argptr[4]		; evaluate optional offset
	mov	domath_ptr,si
	mov	ax,arglen[4]
	mov	domath_cnt,ax
	call	domath
	pop	si
	jnc	evalt16b		; nc = got a number
evalt16a:mov	ax,1			; default to one (user style)
	xor	dx,dx
evalt16b:or	dx,dx			; too large?
	jnz	evalt16x		; nz = too large, fail
	dec	ax			; offset from start (0 base it)
	mov	temp,ax			; remember offset
	cmp	evaltype,F_rindex	; \frindex?
	jne	evalt16g		; ne = no
	mov	cx,arglen+2		; length of string
	sub	cx,arglen		; minus length of pattern
	sub	cx,ax			; minus displacement from right
	mov	temp,cx			; new effective offset
	mov	ax,cx
evalt16g:
	push	es
	push	di
	mov	di,ds			; string is in DS seg
	mov	es,di
	mov	cx,arglen+2		; length of string
	sub	cx,arglen		; minus length of pattern
	cmp	ax,cx			; offset larger than this?
	jbe	evalt16c		; be = no
	mov	temp,-1			; to report zero
	jmp	short evalt16e		;  fail
evalt16c:mov	si,argptr		; pattern
	mov	di,argptr+2		; string
	add	di,temp			; plus offset
	mov	cx,arglen		; pattern length
	mov	ax,cx
	add	ax,temp			; plus offset
	cmp	ax,arglen+2		; more than string?
	jbe	evalt16d		; be = no, keep going
	mov	temp,-1			; to report zero
	jmp	short evalt16e		; a = no match
evalt16d:push	cx
	cld
	repe	cmpsb			; compare strings
	pop	cx
	je	evalt16e		; e = matched
	inc	temp			; move pattern right one place
	cmp	evaltype,F_rindex	; \frindex?
	jne	evalt16c		; ne = no
	sub	temp,2			; work to the left instead
	jmp	short evalt16c		; try again
evalt16e:pop	di
	pop	es
	mov	ax,temp			; report out number
	inc	ax			; show 0 as 1 to user
	mov	bx,takadr
	call	fdec2di			; binary to ASCIIZ
	mov	bx,takadr
	sub	di,[bx].takptr
	mov	[bx].takcnt,di		; length of ASCIIZ result
evalt16x:jmp	evalt99

evalt17:cmp	evaltype,F_repeat	; \frepeat(text,n)?
	jne	evalt18			; ne = no
	cmp	arglen+2,0		; number given?
	je	evalt17g		; e = no, fail
	mov	si,argptr[2]		; n
	mov	domath_ptr,si
	mov	ax,arglen[2]
	mov	domath_cnt,ax
	call	domath
	jc	evalt17g		; c = fail
	or	dx,dx			; number overflowed?
	jz	evalt17a		; z = no
	mov	ax,1			; default number
evalt17a:mov	arglen+2,ax		; save reasonable value here
	mul	arglen			; string length * repeats
	or	dx,dx			; overflowed (> 64KB)?
	jnz	evalt17b		; nz = yes
	cmp	ax,cmdblen		; more than parse buffer?
	jbe	evalt17c		; be = no
evalt17b:mov	ax,cmdblen		; should be plenty (1000)
evalt17c:mov	cx,ax			; bytes wanted
	call	evmem			; allocate memory 
	mov	dx,cx			; buffer length available
evalt17d:mov	cx,arglen		; length of text
	cmp	cx,dx			; length vs buffer capacity
	jbe	evalt17e		; be = capacity exceeds string
	mov	cx,dx			; chop string to fit
evalt17e:sub	dx,cx			; deduct amount done
	mov	si,argptr		; point at string
	cld
	rep	movsb
	dec	arglen+2		; repeat count
	cmp	arglen+2,0		; any more repeats to do?
	je	evalt17f		; e = no
	or	dx,dx			; any space left?
	jg	evalt17d		; g = yes
evalt17f:mov	bx,takadr
	sub	di,[bx].takptr		; end minus start
	mov	[bx].takcnt,di		; string length
evalt17g:jmp	evalt99

evalt18:cmp	evaltype,F_reverse	; \freverse(text)?
	jne	evalt19			; ne = no
	mov	cx,arglen		; length of string
	mov	si,argptr		; string
	add	di,cx
	dec	di			; last byte in output string
	mov	bx,takadr
	mov	[bx].takcnt,cx		; length of output to buffer
	jcxz	evalt18b		; z = empty string
evalt18a:cld
	lodsb				; read left
	std
	stosb				; write left, displaced, backward
	cld
	loop	evalt18a
evalt18b:jmp	evalt99

evalt19:cmp	evaltype,F_date		; \fdate(filename)?
	je	evalt19a		; e = yes
	cmp	evaltype,F_size		; \fsize(filename)?
	jne	evalt20			; ne = no
evalt19a:
	push	di
	mov	di,offset tmpbuf	; work buffer in this data seg
	mov	byte ptr [di],0		; terminator
	call	filedate		; get info
	mov	dx,offset tmpbuf
	call	strlen			; get length of results to CX
	pop	di
	mov	bx,takadr
	mov	[bx].takcnt,cx		; length of results
	mov	si,offset tmpbuf
	cld
	rep	movsb			; copy to Take buffer
evalt19b:jmp	evalt99

evalt20:cmp	evaltype,F_directories	; \fdirectories(filespec)?
	jne	evalt20a		; ne = no
	mov	findkind,2		; say directory search
	jmp	short evalt20d
evalt20a:cmp	evaltype,F_files	; \ffiles(filespec)?
	jne	evalt20b			; ne = no
	mov	findkind,1		; say file search
	jmp	short evalt20d
evalt20b:cmp	evaltype,F_rdirectories	; \frdirectories(filespec)?
	jne	evalt20c		; ne = no
	mov	findkind,2+4		; directory search+recursive
	jmp	evalt20d		; common worker
evalt20c:cmp	evaltype,F_rfiles	; \frfiles(filespec)?
	jne	evalt21			; ne = no
	mov	findkind,1+4		; file search+recursive

evalt20d:
	mov	dx,argptr		; filename
	mov	cx,arglen		; length of it
	call	rfprep			; prepare filespec for use below
	mov	filecnt,0		; file count
evalt20e:call	rgetfile		; get item from directory structure
	jnc	evalt20e		; found one, repeat til none
					; redo a findfirst for \fnextfile()
	mov	dx,argptr		; filename
	mov	cx,arglen		; length of it
	call	rfprep			; prepare filespec for \fnextfile()
	mov	[bx].filename,0		; clear name so do search for first
	mov	dx,offset buff		; restore default dta
	mov	ah,setdma		; set the dta address
	int	dos
	mov	ax,filecnt		; report file count
	call	fdec2di			; convert to ASCII string
	mov	bx,takadr
	sub	di,[bx].takptr		; end minus start
	mov	[bx].takcnt,di		; string length
	jmp	evalt99

evalt21:cmp	evaltype,F_nextfile	; \fnextfile()?
	jne	evalt24			; ne = no
	test	findkind,2+1		; find files or directories?
	jz	evalt21a		; z = neither, do nothing

	call	rgetfile		; find object in file store
	pushf				; preserve carry status
	mov	dx,offset buff		; point at dta
	mov	ah,setdma		; set the dta address
	int	dos
	popf
	jc	evalt21a		; c = failure
	mov	si,offset rpathname	; report path\filename
	mov	dx,si
	call	strlen			; length to CX for ev21wrk
	xor	ah,ah			; clear \ counter AH for ev32wrk
	call	ev21wrk			; write pretty bytes, count to dx
	push	ax			; save AH slash counter
	mov	temp,dx			; byte count
	mov	si,rfileptr 		; current filename from DOS
	lea	dx,[si].filename
	mov	si,dx			; for ev21wrk etc below
	call	strlen			; length of name
	pop	ax			; recover AH slash counter
	call	ev21wrk			; pretty write this part too
	add	dx,temp			; byte count
	xor	al,al			; null terminator
	stosb				; write it
	inc	dx
	mov	bx,takadr
	mov	[bx].takcnt,dx		; length of result
	jmp	evalt99
evalt21a:				; c = failure, no next
	mov	findkind,0		; failure means no next
	jmp	evalt99

; Ensure digits are protected by an even number of preceeding '\'
; Enter with ds:si as source string of count CX bytes, destination
; of es:di, report final byte count in DX. Enter with AH holding
; current count of '\' chars in a row.
ev21wrk proc near
	cld
	xor	dx,dx			; bytes written
	jcxz	ev21w5			; z = nothing to do
ev21w1:	lodsb				; read a byte
	cmp	al,'\'			; slash seen?
	jne	ev21w2			; ne = no
	inc	ah			; count slashes in a row
ev21w2:	test	ah,1			; odd slash count now?
	jz	ev21w4			; z = no, nothing to do
	cmp	al,'x'			; hex introducer?
	je	ev21w2a			; e = yes, consider numeric
	cmp	al,'X'
	je	ev21w2a
	cmp	al,'o'			; octal introducer
	je	ev21w2a
	cmp	al,'O'
	je	ev21w2a
	cmp	al,'d'			; decimal introducer
	je	ev21w2a
	cmp	al,'D'
	je	ev21w2a
	cmp	al,'0'			; digits?
	jb	ev21w3			; b = no
	cmp	al,'9'
	ja	ev21w3			; a = no
ev21w2a:test	ah,1			; odd number of slashes?
	jz	ev21w3			; z = no
	push	ax
	mov	al,'\'			; double slash
	stosb
	pop	ax
	inc	dx			; count byte written
ev21w3:	cmp	al,'\'			; slash?
	je	ev21w4			; e = yes
	xor	ah,ah			; clear slash count
ev21w4:	stosb				; store original byte
	inc	dx			; count byte written
	loop	ev21w1
ev21w5:	ret
ev21wrk endp

evalt24:cmp	evaltype,F_replace	; \freplace(source,pat,replacement)?
	jne	evalt25			; ne = no
	cmp	arglen+2,0		; arg2 omitted?
	jne	evalt24a		; ne = no
	mov	cx,arglen		; source length
	mov	si,argptr		; source
	jmp	evalt24g		; copy source to output

evalt24a:push	es			; provided Take buffer, save
	push	di
	mov	ax,seg decbuf		; use local temp buf
	mov	es,ax
	mov	di,offset decbuf	; as es:di
	mov	si,argptr		; make source ds:si
	mov	cx,arglen		; length of source
	cld
evalt24b:push	cx			; save source counter
	push	si			; save source pointer
	cmp	cx,arglen+2		; fewer source bytes than pattern?
	jb	evalt24e		; b = yes, no replacement possible
	mov	bx,argptr+2		; pattern
	mov	cx,arglen+2		; length of pattern

evalt24c:mov	ah,[bx]			; pattern byte
	cmp	[si],ah			; same as source byte?
	jne	evalt24e		; ne = no, no match
	inc	si			; next bytes to match
	inc	bx
	loop	evalt24c		; do all pattern bytes
	mov	si,argptr+4		; get replacement pattern
	mov	cx,arglen+4		; its length
	mov	ax,di			; starting offset in temp buffer
	sub	ax,offset decbuf	; minus start of buffer
	add	ax,cx			; count of bytes to be in buffer
	cmp	ax,decbuflen		; longer than buffer?
	jbe	evalt24d		; be = no overflow
	sub	ax,cx			; get back bytes already in buffer
	sub	ax,decbuflen
	neg	ax			; bytes available
	mov	cx,ax			; move just that many
evalt24d:rep	movsb			; copy to output (may be nothing)
	pop	si
	pop	cx
	add	si,arglen+2		; length of pattern
	sub	cx,arglen+2		; bytes left in source
	jmp	short evalt24f

evalt24e:pop	si			; mismatch comes here
	pop	cx
	movsb				; write source byte to output buffer
	dec	cx			; one less source byte
evalt24f:or	cx,cx			; qty of source bytes remaining
	jg	evalt24b		; g = more source bytes to examine
	sub	di,offset decbuf	; length of output material
	mov	cx,di
	mov	ax,cx			; save length in ax
	pop	di
	pop	es			; original Take buffer
	call	evmem			; allocate new Take buffer, len cx
	mov	si,offset decbuf
	mov	cx,ax			; length used in decbuf
evalt24g:cld
	rep	movsb			; copy decbuf to Take buffer
	mov	bx,takadr
	sub	di,[bx].takptr
	mov	[bx].takcnt,di		; length of ASCIIZ result
	jmp	evalt99

evalt25:cmp	evaltype,F_eval		; \feval(string)?
	jne	evalt26			; ne = no
	mov	ax,argptr
	mov	domath_ptr,ax
	mov	ax,arglen
	or	ax,ax
	jz	evalt25b		; z = no argument
	mov	domath_cnt,ax
	call	domath			; return value in DX:AX
	jc	evalt25b		; c = error, no value will be written
	push	di			; save string destination es:di
	mov	di,offset decbuf	; temp work space
	mov	word ptr [di],0		; clear it
	or	dx,dx			; is result negative?
	jns	evalt25a		; ns = no, positive or zero
	neg	dx			; flip sign
	neg	ax
	sbb	dx,0
	mov	byte ptr [di],'-'	; show minus sign
	inc	di

evalt25a:call	flnout			; convert DX:AX to ASCIIZ in DS:DI
	pop	di			; recover original di
	mov	dx,offset decbuf
	mov	si,dx			; save as source pointer too
	call	strlen			; get length of string to cx
	cld
	rep	movsb			; copy to final buffer
	mov	bx,takadr
	sub	di,[bx].takptr		; end minus start
	mov	[bx].takcnt,di		; string length
evalt25b:jmp	evalt99

evalt26:cmp	evaltype,F_verify	; \fverify(pattern,string,offset)?
	jne	evalt27			; ne = no
	cld
	push	es
	push	di
	mov	si,ds
	mov	es,si
	mov	di,argptr		; pattern pointer
	mov	si,argptr+4		; offset
	mov	ax,arglen+4		; length of offset string
	call	domath
	jc	evalt26b		; c = error
	mov	bx,ax			; offset
	mov	si,argptr+2		; string
	add	si,bx			; string plus offset
	mov	cx,arglen+2		; length of string
	sub	cx,bx			; minus offset
	jg	evalt26a		; g = have string left to compare
	mov	bx,-1			; error, report -1 for no string
	jmp	short evalt26b
evalt26a:push	di
	lodsb				; get a byte of string
	inc	bx			; count based 1 for users
	push	cx			; one less string byte
	mov	cx,arglen		; length of pattern
	repne	scasb			; scan for match
	pop	cx
	pop	di
	jne	evalt26b		; ne = mismatch
	loop	evalt26a		; next string char
	xor	bx,bx			; report 0 if all match
evalt26b:mov	ax,bx			; char position of first mismatch
	pop	di
	pop	es
	call	fdec2di			; convert to ASCII string
	mov	bx,takadr
	sub	di,[bx].takptr		; end minus start
	mov	[bx].takcnt,di		; string length
	jmp	evalt99

evalt27:cmp	evaltype,F_ipaddr	; \fipaddr(string, offset)?
	jne	evalt29			; ne = no
	mov	si,argptr+2		; offset
	mov	ax,arglen+2		; length of offset string
	mov	domath_ptr,si		; convert offset to binary
	mov	domath_cnt,ax
	call	domath			; failure means use zero
	add	argptr,ax
	sub	arglen,ax
evalt27a:mov	si,argptr		; scan string
	mov	cx,arglen
	cmp	cx,7			; enough bytes to qualify?
	jl	evalt27x		; l = no, quit
	cld
evalt27b:lodsb				; trim leading spaces
	sub	al,'0'			; remove ASCII bias
	cmp	al,9			; numeric?
	jbe	evalt27c		; be = yes
	loop	evalt27b
evalt27c:dec	si			; break char
	inc	cx			; byte count remaining
	mov	argptr,si		; remember start of real text
	mov	arglen,cx		; and its length
	call	evalt27w		; scan for digits
	jc	evalt27x		; c = fail
	cmp	byte ptr [si],'.'	; looking at dot now?
	jne	evalt27x		; ne = fail
	inc	si
	call	evalt27w		; scan for digits
	jc	evalt27x		; c = fail
	cmp	byte ptr [si],'.'	; looking at dot now?
	jne	evalt27x		; ne = fail
	inc	si
	call	evalt27w		; scan for digits
	jc	evalt27x		; c = fail
	cmp	byte ptr [si],'.'	; looking at dot now?
	jne	evalt27x		; ne = fail
	inc	si
	call	evalt27w		; scan for digits
	jc	evalt27x		; c = fail
	mov	al,[si]			; break byte
	sub	al,'0'			; remove ASCII bias
	cmp	al,9
	jbe	evalt27x		; be = is still numberic, fail
	mov	cx,si			; break postion
	sub	cx,argptr		; minus start
	jle	evalt27x		; le = problems, fail
	mov	si,argptr		; start
	rep	movsb			; copy string to destination
	mov	bx,takadr
	sub	di,[bx].takptr		; end minus start
	mov	[bx].takcnt,di		; string length
	jmp	evalt99

evalt27x:inc	argptr			; step to next source byte
	dec	arglen			; one less to examine
	cmp	arglen,7		; any string left?
	jge	evalt27a		; ge = yes, try again
	jmp	evalt99

evalt27w proc	near			; worker to read digits, check range
	mov	cx,3			; three digits
	xor	dx,dx			; value of digits
evalt27w1:
	mov	ax,dx
	mul	ten			; previous times ten to ax
	mov	dx,ax
	lodsb
	sub	al,'0'			; remove ASCII bias
	cmp	al,9			; validate decimal
	ja	evalt27w2		; a = no
	add	dl,al			; number so far
	jc	evalt27w3		; c = overflow, fail
	loop	evalt27w1		; while in digits
	inc	si			; inc to offset dec below
evalt27w2:
	dec	si			; back up to break byte
	cmp	cx,3			; must have at least one digit
	je	evalt27w3		; e = none, fail
	clc				; success, have digits
	ret
evalt27w3:
	stc				; fail
	ret
evalt27w endp

evalt29:cmp	evaltype,F_tod2secs	; \ftod2secs(hh:mm:ss)?
	jne	evalt30			; ne = no
	mov	si,argptr		; hh:mm:ss string
	mov	bx,arglen
	mov	byte ptr [si+bx],0	; terminate string
	call	tod2secs		; convert to ASCII long in es:di
	jc	evalt99			; c = failed to convert
	mov	bx,takadr
	sub	di,[bx].takptr		; end minus start
	mov	[bx].takcnt,di		; string length
	jmp	evalt99

evalt30:cmp	evaltype,F_chksum	; \fchecksum(string)?
	jne	evalt31
	mov	si,argptr		; string
	mov	cx,arglen
	xor	bx,bx			; running sum, low and high portions
	xor	dx,dx
	cld
evalt30a:lodsb
	add	bl,al			; accumulate checksum
	adc	bh,0			; with carry
	adc	dx,0
	loop	evalt30a
	mov	ax,bx
	push	di
	push	es
	mov	di,ds
	mov	es,di
	mov	di,offset argptr
	call	flnout			; 32 bit converter
	mov	dx,offset argptr
	call	strlen
	mov	si,dx
	pop	es
	pop	di
	cld
	rep	movsb
	mov	bx,takadr
	sub	di,[bx].takptr		; end minus start
	mov	[bx].takcnt,di		; string length
	jmp	evalt99

evalt31:cmp	evaltype,F_basename	; \fbasename(string)?
	jne	evalt99
	mov	dx,argptr		; string
	mov	cx,arglen
	mov	si,dx
	add	si,cx
	mov	byte ptr [si],0		; force null termination
	push	di
	mov	di,offset decbuf+100	; place for path part
	mov	si,offset decbuf	; place for filename part
	call	fparse			; split pieces
	pop	di
	mov	dx,si			; look only at filename
	call	strlen
	rep	movsb			; copy to result buffer
	mov	bx,takadr
	sub	di,[bx].takptr		; end minus start
	mov	[bx].takcnt,di		; string length
	jmp	evalt99

evalt99:pop	temp
	pop	si
	pop	dx			; trailing space flag
	clc				; success or fail, consume source
	ret
evaltoa	endp

; Worker for evaltoa. 
; Given start of string in DS:SI and string length in CMSIZ.
; Return pointers to up to three arguments (as offset of start of their
; non-white space) and the lengths of each argument field. Arrays argptr
; and arglen hold these 16 bit values.
; Bare commas separate arguments, curly braces and parentheses protect commas,
; curly braces protect strings, starting with a curly brace is considered to 
; mean use material within braces. A closing curly brace closes parens.
evarg	proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	temp
	mov	al,taklev
	xor	ah,ah
	mov	temp,ax
	xor	ax,ax
	mov	argptr,ax		; clear arg pointer list
	mov	argptr+2,ax
	mov	argptr+4,ax
	mov	arglen,ax		; clear arg length list
	mov	arglen+2,ax
	mov	arglen+4,ax
	xor	bx,bx			; index of argument
					; read start of argument
evarg10:mov	si,cmrptr		; last byte + 1 read
	xor	dx,dx			; paren and curly brace counters
	mov	argptr[bx],si		; where argument string starts
	mov	cmsiz,0			; argument length counter

evarg12:mov	cl,comand.cmper		; read next argument byte
	push	cx			; preserve comand.cmper around call
	push	temp			; preserve take level monitor
	push	evaltype		; preserve, reading may recurse
	push	bx			; preserve argument counter
	push	dx			; preserve curly brace counter
	push	cmsiz
	mov	cmsflg,0		; see leading spaces/tabs
	push	argptr			; save our working variables
	push	argptr+2
	push	argptr+4
	push	arglen
	push	arglen+2
	push	arglen+4
	cmp	evaltype,F_contents	; \fcontents(macro)?
	je	evarg13			; e = yes
	cmp	evaltype,F_literal	; \fliteral(string)?
	jne	evarg14			; ne = no
evarg13:mov	comand.cmper,1		; arg, treat macros as literals
evarg14:call	cmgtch			; recursively read a character into ah
	pop	arglen+4
	pop	arglen+2
	pop	arglen
	pop	argptr+4
	pop	argptr+2
	pop	argptr
	pop	cmsiz
	pop	dx
	pop	bx
	pop	evaltype
	pop	temp
	pop	cx
	mov	comand.cmper,cl		; restore macro expansion state
	pushf				; save carry flag from cmgtch
	inc	cmsiz			; count argument byte
	push	bx
	mov	bl,taklev		; current take level
	cmp	bl,byte ptr temp	; react to specials?
	pop	bx
	jbe	evarg15			; be = yes, else in macro/take
	popf				; clear stack of cmgtch carry status
	jmp	evarg12			; read another byte

evarg15:popf				; recover cmgtch carry status
	jnc	evarg50			; nc = non-terminator
	cmp	ah,' '			; just a space?
	jne	evarg17			; ne = no
	cmp	cmsiz,1			; is it a leading space?
	jne	evarg12			; ne = no, consider it to be data
	cmp	evaltype,F_literal	; \fliteral(string)?
	je	evarg12			; e = yes, keep leading spaces
	jmp	evarg10			; skip space, get first arg byte
	
evarg17:cmp	ah,'?'			; need help?
	jne	evarg20			; ne = no
	call	fcmdhlp			; compute cmhlp to proper string
	mov	cmsiz,0			; so help is with provided text
	call	cmkyhlp
	jmp	repars

evarg20:dec	cmsiz			; omit byte from count
	cmp	ah,escape		; ESC?
	jne	evarg22			; ne = no
	cmp	evaltype,F_contents	; \fcontents(macro)?
	je	evarg21			; e = yes
	cmp	evaltype,F_definition	; \fdefinition(macro)?
	jne	evarg22			; ne = no
evarg21:push	cmptab			; save working pointers
	push	cmsptr
	mov	cmptab,offset mcctab	; look at table of macro names
	mov	cx,argptr[bx]		; look at whole word todate
	mov	cmsptr,cx		; start of word
	push	bx
	call	cmkyesc			; do escape word completion
	pop	bx
	pop	cmsptr
	pop	cmptab
	xor	ah,ah			; in case no match
evarg22:call	bufreset		; reset cmwptr
	cmp	ah,escape		; escape?
	jne	evarg30			; ne = no
	push	ax
	push	dx
	mov	ah,conout		; ring the bell
	mov	dl,bell
	int	dos
	pop	dx
	pop	ax
	jmp	evarg12			; get next arg byte
evarg30:jmp	repars			; reparse command

evarg50:cmp	ah,braceop		; opening curly brace?
	jne	evarg52			; ne = no
	inc	dl			; count up curly brace
	jmp	evarg12			; get next argument byte
evarg52:cmp	ah,bracecl		; closing curly brace?
	jne	evarg60			; ne = no
	sub	dl,1			; count down curly braces
	jge	evarg54			; ge = no underflow
 	xor	dx,dx			; clamp at zero
evarg54:jmp	evarg12

evarg60:or	dl,dl			; within curly braces
	jnz	evarg3			; nz = yes, don't count parens there
	cmp	ah,'('			; opening paren?
	jne	evarg62			; ne = no
	inc	dh			; count up paren
	jmp	evarg12			; get next byte of argument

evarg62:cmp	ah,')'			; closing paren?
	jne	evarg3			; ne = no
	sub	dh,1			; count down closing paren
	jl	evarg64			; l = reached terminator
	jmp	evarg12			; get next byte of argument

evarg64:mov	cx,cmsiz
	dec	cx			; don't count closing paren
	mov	arglen[bx],cx
	cmp	evaltype,F_literal	; \fliteral(string)?
	je	evarg66			; e = yes, keep trailing spaces
	mov	si,argptr[bx]		; start of argument
	add	si,cx
	dec	si			; last byte of argument
	jcxz	evarg66			; z = no text to trim
evarg65:cmp	byte ptr [si],' '	; trailing space?
	jne	evarg66			; ne = no
	dec	si
	dec	arglen[bx]		; one less argument byte
	loop	evarg65
evarg66:jmp	evarg7			; ")" marks END of function

evarg3:	cmp	ah,','			; possible argument terminator?
	jne	evarg5			; ne = no
	or	dx,dx			; within paren or curly braces?
	jne	evarg5			; ne = yes, treat commas as data
	cmp	evaltype,F_literal	; doing \fliteral()?
	je	evarg5			; e = yes, commas are data
	cmp	evaltype,F_eval		; doing \feval()?
	je	evarg5			; e = yes, commas are data
	dec	cmsiz			; do not count comma
evarg4:	mov	cx,cmsiz
	cmp	bx,3*2			; done three args?
	jae	evarg4a			; ae = yes, add no more args
	mov	arglen[bx],cx		; mark argument length
	add	bx,2			; next arg array element
evarg4a:jmp	evarg10			; get next argument

evarg5:	jmp	evarg12			; get next byte in argument

evarg7:	pop	temp
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	clc
	ret
evarg	endp

; Reallocates more memory than provided in the default takopen 128 byte buffer.
; Enter with desired byte quantity in CX and a Take structure already
; present at takadr. Returns with new buffer length in CX, ES:DI pointing
; at buffer+2 ([bx].takbuf:[bx].takptr)
evmem	proc	near
	push	ax
	push	bx
	push	cx
	mov	bx,takadr
	mov	ax,[bx].takbuf		; segment of preallocated memory
	mov	bx,cx			; string length, in bytes
	add	bx,2+1+15		; count + null term + round up
	mov	cl,4
	shr	bx,cl			; convert to paragraphs (divide by 16)
	mov	cx,bx			; remember desired paragraphs
	mov	ah,alloc		; allocate a memory block
	int	dos			; ax=seg, bx=paragraphs
	jc	evmem3			; c = error, not enough memory
 	cmp	bx,cx			; obtained vs wanted
	jae	evmem2			; ae = enough
	push	bx
	mov	bx,takadr
	mov	cx,[bx].takcnt		; old unread-bytes
	shr	cx,1
	shr	cx,1
	shr	cx,1
	shr	cx,1			; to paragraphs
	pop	bx
	cmp	bx,cx			; more than we had originally?
	ja	evmem2			; a = yes, so use the new larger buff
	push	es
	mov	es,ax			; new allocated segment
	mov	ah,freemem		; free it
	int	dos
	pop	es
	jmp	short evmem3		; use original segment

evmem2:	mov	cl,4
	shl	bx,cl			; paragraphs to bytes
	mov	cx,bx			; return new bytes in CX
	sub	cx,2			; minus two for len field
	mov	es,ax			; set new segment
	mov	bx,takadr
	xchg	[bx].takbuf,ax		; new segment, swap with old seg
	or	ax,ax			; if any allocated
	jz	evmem2a			; z = none
	push	es
	mov	es,ax			; old allocated segment
	mov	ah,freemem		; free old segment
	int	dos
	pop	es
evmem2a:mov	di,2			; new offset
	mov	bx,takadr
	mov	[bx].takptr,di		; new offset
	mov	[bx].takcnt,0		; total buffer, unread bytes
	or	[bx].takattr,take_malloc ; malloc'd buffer to remove later
	pop	bx			; discard old cx, return new cx
	pop	bx
	pop	ax
	ret

evmem3:	pop	cx			; return original values
	pop	bx
	pop	ax
	ret
evmem	endp

; Worker for evaltoa. Sets cmhlp to help string matching evaltype
fcmdhlp	proc	near
	mov	ax,evaltype		; kind of \f command
	mov	bx,offset f1hlp		; number
	cmp	ax,F_char		; go through types
	je	fcmdh1			; e = matched
	cmp	ax,F_maximum
	je	fcmdh1
	cmp	ax,F_minimum
	je	fcmdh1
	mov	bx,offset f2hlp		; char
	cmp	ax,F_code
	je	fcmdh1
	mov	bx,offset f3hlp
	cmp	ax,F_contents
	je	fcmdh1
	cmp	ax,F_definition
	je	fcmdh1
	mov	bx,offset f8hlp
	cmp	ax,F_index
	je	fcmdh1
	mov	bx,offset f12hlp
	cmp	ax,F_lpad
	je	fcmdh1
	cmp	ax,F_rpad
	je	fcmdh1
	mov	bx,offset f15hlp
	cmp	ax,F_nextfile
	je	fcmdh1
	mov	bx,offset f16hlp
	cmp	ax,F_repeat
	je	fcmdh1
	mov	bx,offset f18hlp
	cmp	ax,F_right
	je	fcmdh1
	mov	bx,offset f20hlp
	cmp	ax,F_substr
	je	fcmdh1
	mov	bx,offset f22hlp
	cmp	ax,F_date
	je	fcmdh1
	cmp	ax,F_basename
	je	fcmdh1
	cmp	ax,F_size
	je	fcmdh1
	cmp	ax,F_files
	je	fcmdh1
	mov	bx,offset f25hlp
	cmp	ax,F_eval
	je	fcmdh1
	mov	bx,offset f8hlp
	cmp	ax,F_rindex
	je	fcmdh1
	mov	bx,offset f30hlp
	cmp	ax,F_chksum
	je	fcmdh1
	mov	bx,offset f9hlp		; default to text
fcmdh1:	mov	cmhlp,bx		; set help text pointer
	ret
fcmdhlp	endp

; Obtain file date/time or size.
; Incoming match pattern is in argptr (not ASCIIZ), length of arglen.
; Write results to ds:di, not es:di.
filedate proc	near
	mov	bx,argptr		; filename
	mov	dx,bx			; for file open
	add	bx,arglen		; length of it
	cmp	arglen,0		; empty argument?
	je	filed2			; e = yes
	mov	byte ptr [bx],0		; make it ASCIIZ
	push	dx
	mov	dx,offset buff		; use default dta
	mov	ah,setdma		; set the dta address
	int	dos
	pop	dx
	mov	cx,10h			; find dir and files
	mov	ah,first2		; DOS 2.0 search for first
	int	dos			; get file's characteristics
	jnc	filed1			; nc = success
	ret				; fail
filed1:	mov	bx,offset buff		; default dta
	jmp	short filed3
filed2:	mov	bx,rfileptr		; no filename, use last find info
	or	bx,bx			; any?
	jnz	filed3			; nz = yes
	mov	bx,offset buff		; revert to default dta
filed3:	cmp	evaltype,F_date		; want date/time stamp?
	je	filed5			; e = yes
	cmp	evaltype,F_size		; want file length?
	jne	filed4			; ne = no (probably \ffiles(..))
	mov	ax,[bx].mysizelo	; file size to dx:ax
	mov	dx,[bx].mysizehi
	call	flnout			; convert to ASCII
	mov	byte ptr [di],0		; terminate
filed4:	clc
	ret

filed5:	call	filetdate		; do the work
	clc
	ret
filedate endp

; Write file date and timestamp to ds:di, given DTA in ds:bx.
filetdate proc	far
	push	es			; time/date stamp yyyymmdd hh:mm:ss
	mov	ax,ds
	mov	es,ax
	xor	ah,ah
	mov	al,[bx+25]		; yyyyyyym from DOS via file open
	shr	al,1			; get year
	add	ax,1980			; add bias
	xor	dx,dx
	call	flnout			; put year (1990) in buffer
	mov	ax,[bx+24]		; yyyyyyyym mmmddddd  year+month+day
	shr	ax,1			; month to al
	xor	ah,ah
	mov	cl,4
	shr	al,cl			; month to low nibble
	mov	byte ptr[di],'0'	; leading digit
	inc	di
	cmp	al,9			; more than one digit?
	jbe	filetd1			; be = no
	mov	byte ptr[di-1],'1'	; new leading digit
	sub	al,10			; get remainder
filetd1:add	al,'0'			; to ascii
	stosb				; end of month
	mov	al,[bx+24]		; get day of month
	and	al,1fh			; select day bits
	xor	ah,ah
	mov	cl,10
	div	cl			; quot = al, rem = ah
	add	ax,'00'			; add ascii bias
	stosw				; leading digit and end of date
	mov	al,' '			; space separator
	stosb
	mov	al,[bx+23]		; hours  hhhhhmmm
	mov	cl,3
	shr	al,cl			; move to low nibble
	xor	ah,ah
	mov	cl,10
	div	cl			; quot = al, rem = ah
	add	ax,'00'			; add ascii bias
	stosw				; store hours
	mov	al,':'			; separator
	stosb
	mov	ax,[bx+22]		; get minutes: hhhhhmmm mmmsssss
	mov	cl,5
	shr	ax,cl			; minutes to low byte
	and	al,3fh			; six bits for minutes
	xor	ah,ah
	mov	cl,10
	div	cl
	add	ax,'00'			; add ascii bias
	stosw
	mov	al,':'			; separator
	stosb
	mov	al,[bx+22]		; get seconds (double secs really)
	and	al,1fh
	shl	al,1			; DOS counts by two sec increments
	xor	ah,ah
	mov	cl,10
	div	cl
	add	ax,'00'			; add ascii bias
	stosw
	mov	byte ptr [di],0		; terminate
	pop	es
	ret
filetdate endp

; Setup to find files or directories given in ds:dx, length in cx.
; Regularize path to always end in \, add .\ if necessary.
rfprep proc	far
	push	di
	mov	bx,dx			; filename
	add	bx,cx			; length of it
	mov	byte ptr [bx],0		; ensure ASCIIZ
	jcxz	rfprep2			; z = empty argument
	mov	ax,word ptr [bx-2]	; last two chars
	mov	cl,[bx-3]		; preceeding char
	cmp	ah,'*'			; ends in *?
	jne	rfprep5			; ne = no
	cmp	al,'.'			; .* extension given?
	je	rfprep5			; e = yes
	cmp	cl,'.'			; . given?
	je	rfprep5			; e = yes
	mov	word ptr [bx],'*.'	; force .* extension
	mov	byte ptr [bx+2],0
rfprep5:push	cx			; see if pattern is a directory
	push	dx
	mov	dx,offset buff		; default dta
	mov	ah,setdma
	int	dos
	pop	dx			; filename to ds:dx
	push	dx			; save again
	mov	cx,10h			; find dir and files
	mov	ah,first2		; DOS 2.0 search for first
	int	dos
	pop	dx
	pop	cx
	jc	rfprep1			; c = nothing found
	test	byte ptr buff+21,10h	; directory?
	jz	rfprep1			; z = not a directory
	cmp	byte ptr [bx-1],'*'	; ends in wild card?
	je	rfprep1			; e = yes, leave intact
	mov	word ptr [bx],0+'\'	; yes, ensure parsed as dir
	inc	bx
rfprep1:mov	al,byte ptr [bx-1]	; last byte, if any
	cmp	al,'.'			; path for this dir or above (.,..)?
	jne	rfprep2			; ne = no, use descriptor as-is
	mov	word ptr [bx],0+'\'	; append "\"

rfprep2:mov	di,offset rpathname	; path
	mov	si,offset rfilename	; filename
	call	fparse			; split source pattern from ds:dx
	cmp	rfilename,0		; any file pattern?
	jne	rfprep3			; ne = yes
	mov	word ptr rfilename,'.*' ; force wild card terminator
	mov	word ptr rfilename+2,0+'*'
rfprep3:push	dx
	mov	dx,offset rpathname	; path
	call	strlen
	mov	di,dx
	pop	dx
	add	di,cx
	or	cx,cx			; path present?
	jz	rfprep4			; z = no
	cmp	byte ptr [di-1],':'	; path ends as drive separator?
	je	rfprep4			; e = yes
	cmp	byte ptr [di-1],'\'	; ends in \?
	je	rfprep4			; e = yes
	mov	word ptr [di],0+'\'	; append trailing slash
rfprep4:pop	di
	mov	bx,offset fileio
	mov	rfileptr,bx		; point to fileio array for dta
	mov	[bx].filename,0		; clear name to do find first
	ret
rfprep	endp

; Find next item (file or directory), given dta in rfileptr.
; Return carry clear if found, else carry set
; Use filekind to allow recursion and to set kind of item desired.
; Rfileptr points to current dta (amongst array of fileio).
; Final name is in rfileptr.filename, path is in rpathname
rgetfile proc far
	mov	bx,rfileptr		; current dta pointer
	mov	dx,bx			; point at dta
	mov	ah,setdma		; set the dta address
	int	dos
rgfile1:cmp	[bx].filename,0		; filename established?
	jnz	rgfile5			; nz = yes, do search for next
	push	di
	mov	di,offset decbuf	; scratch buffer
	mov	si,offset rpathname	; path
	call	strcpy			; path to decbuf
	mov	si,offset rfilename	; filename pattern
	call	strcat			; append filename
	mov	dx,di			; search for first uses ds:dx
	pop	di
	xor	cx,cx			; find files only
	test	findkind,1		; want files only?
	jnz	rgfile2			; nz = yes
	mov	cx,10h			; directories and files
rgfile2:mov	ah,first2		; DOS 2.0 search for first
	int	dos			; get file's characteristics
	jc	rgfile6			; c = failed
					; separate files from directories
rgfile3:test	findkind,1		; want files only?
	jnz	rgfile4			; nz = yes, done
	test	byte ptr [bx]+21,10h	; directory?
	jz	rgfile5			; z = no, try again
	cmp	[bx].filename,'.'	; dot or dot-dot?
	je	rgfile5			; e = yes, ignore dots, search again
rgfile4:inc	filecnt			; file count
	clc				; success
	ret
					; search for next
rgfile5:mov	dx,bx			; dta pointer
	mov	ah,next2		; DOS 2.0 search for next
	int	dos
	jnc	rgfile3			; nc = success, found entry, filter

					; walk tree when out of items
rgfile6:test	findkind,4		; recursion allowed?
	jz	rgfile9			; z = no, done (failed)
	mov	[bx].filename,0		; clear found name, for find first
rgfile7:call	rnxtdir			; get next directory at this level
	jc	rgfile8			; c = failure, none, go up tree
	call	rsubdir			; step into this subdir
	jmp	short rgfile1		; search again
rgfile8:call	rprvdir			; go up one directory level, if any
	jnc	rgfile7			; nc = got next dir at new level up
rgfile9:stc				; c = failure
	ret
rgetfile endp

; Scan current dta for next directory. If rfileptr.filename is non-zero
;  do a search for next, else search for first.
; rpathname has entire pattern.
; Return carry clear on success with rfileptr.filename holding new
; dir component, else carry set.
; Reuse current dta.
rnxtdir proc	near
	mov	bx,rfileptr		; current dta
	cmp	byte ptr [bx].filename,0 ; any name pattern yet?
	jne	rnxtdir3		; ne = yes, use get next
	push	di
	mov	di,offset rpathname	; path
	mov	dx,di
	call	strlen
	add	di,cx			; last byte plus one
	mov	word ptr [di],'.*'	; wildcard pattern match for all dirs
	mov	word ptr [di+2],0+'*'
	mov	cx,10h			; find dir and files
	mov	ah,first2		; DOS 2.0 search for first
	int	dos
	mov	byte ptr [di],0		; remove the '*.*'
	pop	di
	jnc	rnxtdir2		; nc = success
	ret				; c = failed

rnxtdir2:test	byte ptr [bx]+21,10h	; directory?
	jz	rnxtdir3		; z = no, must be regular file
	cmp	[bx].filename,'.'	; dot or dot-dot?
	je	rnxtdir3		; e = yes, ignore, keep looking
	clc				; say success
	ret

rnxtdir3:mov	dx,bx			; dta pointer
	mov	ah,next2		; DOS 2.0 search for next
	int	dos
	jnc	rnxtdir2		; nc = success
	ret				; failure to find another
rnxtdir	endp

; Go up one directory level.
; Current dta needs to be removed. rpathname has current path.
; We need to strip off one "dir\" and pop the scan level.
; Returns carry clear, except carry set when already at top level.
rprvdir	proc	near
	cmp	rfileptr,offset fileio	; at top dir level now?
	ja	rprvdir1		; a = no
	stc				; say already at top level
	ret

rprvdir1:push	di
	mov	di,offset rpathname	; path
	mov	dx,di
	call	strlen			; length of path string
	jcxz	rprvdir3		; no path so far
	add	di,cx			; last path char+1
	dec	di			; last path char
	cmp	byte ptr [di],'\'	; ends in \ now?
	jne	rprvdir2		; ne = no
	mov	byte ptr [di],' '	; change to space for backscan
rprvdir2:cmp	byte ptr [di],'\'	; at path separator?
	je	rprvdir3		; e = yes
	cmp	byte ptr [di],':'	; drive letter colon?
	je	rprvdir3		; e = yes
	dec	di			; backup til separator
	loop	rprvdir2		; keep backing up
rprvdir3:mov	byte ptr [di+1],0	; terminate
	sub	rfileptr,size fileiost	; go up one dir level
	mov	dx,rfileptr
	mov	bx,dx
	mov	ah,setdma		; set the dta address
	int	dos
	pop	di
	clc
	ret
rprvdir	endp

; Step into subdirectory. [bx].filename as new dir, rpathname has current 
; path with \ ASCIIZ termination. Changes to new dta and clears .filename.
; Changes rpathname to contain new path addition. 
rsubdir	proc	near
	mov	bx,rfileptr
	push	di
	mov	di,offset rpathname	; current \ terminated path
	mov	dx,di
	call	strlen			; get length of this part
	mov	ax,cx			; length
	lea	si,[bx].filename	; get new directory component
	mov	dx,si
	call	strlen			; length of addition
	add	ax,cx			; combined length
	cmp	ax,64			; too long?
	jae	rsubdir2		; ae = yes
	call	strcat			; append si to end of di
	mov	dx,di
	call	strlen
	add 	di,cx
	mov	word ptr [di],0+'\'	; terminate with \
	pop	di
	jmp	short rsubdir1
rsubdir2:stc				; fail
	ret

rsubdir1:cmp	rfileptr,offset fileio + (maxdepth - 1) * size fileiost
	ja	rsubdir2		; a = will exceed max depth
	add	rfileptr,size fileiost	; size of structure
	mov	dx,rfileptr		; point at dta
	mov	ah,setdma		; set the dta address
	int	dos
	mov	bx,dx
	mov	[bx].filename,0		; clear filename field
	clc				; success
	ret
rsubdir	endp

; Set envadr to the string following the <variable=> keyword in the DOS
; Environment and set envlen to its length after removing leading and
; trailing whitespace.
; <variable> starts at ds:<valtmp>, of length cmsiz-1, and can be mixed case.
; Return carry set if can't find the <variable=> line in the Environment.
envvar	proc	near
	push	es
	mov	bx,valtmp		; start of variable name
	mov	cx,cmsiz		; length of variable name, w/o ')'
	or	cx,cx			; empty?
	jle	envvar3			; le = nothing to look for, fail
	push	bx
	push	cx
envvar1:mov	al,byte ptr [bx]	; scan variable name in our buffer
	cmp	al,'a'			; lower case
	jb	envvar2			; b = no
	cmp	al,'z'			; still in lower case range?
	ja	envvar2			; a = no
	and	al,not 20h		; convert to DOS's upper case
	mov	byte ptr [bx],al	; replace char
envvar2:inc	bx
	loop	envvar1
	pop	cx
	pop	bx			; find "<variable>=" in Environment
	call	fgetenv			; dx = offset in Environment of "="
	jnc	envvar4			; nc = success

	push	bx
	push	cx
envvar1a:mov	al,byte ptr [bx]	; scan variable name in our buffer
	cmp	al,'A'			; upper case
	jb	envvar2a		; b = no
	cmp	al,'Z'			; still in upper case range?
	ja	envvar2a		; a = no
	or	al,20h			; convert to DOS's lower case
	mov	byte ptr [bx],al	; replace char
envvar2a:inc	bx
	loop	envvar1a
	pop	cx
	pop	bx			; find "<variable>=" in Environment
	call	fgetenv			; dx = offset in Environment of "="
	jnc	envvar4			; nc = success

envvar3:pop	es			; no such variable
	stc				; c = failure
	ret
; dx has offset in Environment of char "="
; ds:valtmp is start of variable name, cmsiz is length + 1 of the name.
; Return seg:offset and length variables so we can copy from there in valtoa
envvar4:push	di
	push	si
	xor	ax,ax
	mov	word ptr envadr,ax	; offset in env of variable's string
	mov	word ptr envadr+2,ax	; seg of same
	mov	envlen,ax		; length of string
	mov	es,psp			; our Prog Seg Prefix segment
	mov	ax,es:word ptr[env]	; pick up Environment address
	mov	es,ax			; set es: to Environment segment
	mov	di,dx			; line scan pointer
	cmp	byte ptr es:[di],'='	; did we stop on this?
	jne	envvar5			; ne = no
	inc	di			; skip the "=" char
envvar5:mov	al,es:[di]		; scan over leading white space
	inc	di
	or	al,al			; end of line terminator?
	jz	envvarf			; z = yes, fail
	cmp	al,TAB			; HT?
	jne	envvar6			; ne = no
	mov	al,' '			; HT becomes a space
envvar6:cmp	al,' '			; white space?
	je	envvar5			; scan off white space
	dec	di			; backup to non-white char
	mov	word ptr envadr,di	; offset of string in Environment
	mov	word ptr envadr+2,es	; seg of string in Environment
	mov	si,di			; remember starting offset here
					; remove trailing spaces from string
	xor	al,al			; a null
	mov	cx,127			; max length to search
	cld
	repne	scasb			; skip over non-nulls
	dec	di			; backup to null
	dec	di			; backup to last string char
	mov	cx,di			; ending offset
	inc	cx			; count the char
	sub	cx,si			; minus starting offset yields length
	jcxz	envvar9			; z = empty string
envvar7:mov	al,es:[di]		; last char
	dec	di			; backup one char
	cmp	al,' '			; space?
	je	envvar8			; e = yes
	cmp	al,TAB			; HT?
	jne	envvar9			; ne = no, end of white space
envvar8:loop	envvar7			; keep looking
envvar9:mov	envlen,cx		; store the length
	clc				; say success
	jmp	short envvarx
envvarf:stc				; say failure
envvarx:pop	si
	pop	di
	pop	es
	ret
envvar	endp

; Worker for Remote Query System name in mssser.
; Enter with variable name in decbuf+6 et seq, name length byte in decbuf+5
; with ' ' bias.
fqryenv	proc	far
	mov	valtmp,offset decbuf+6	; start of variable name
	mov	cl,decbuf+5		; name length plus bias
	sub	cl,' '			; remove bias
	xor	ch,ch
	mov	cmsiz,cx		; name length
	call	envvar			; get address of environmental string
	jnc	fqryenv1		; nc = success
	xor	cx,cx			; failure
	ret

fqryenv1:mov	cx,envlen		; length of string in environment
	push	es
	push	ds
	lds	si,envadr		; pointer to string
	mov	di,seg encbuf		; destination buffer
	mov	es,di
	mov	di,offset encbuf
	cld
	rep	movsb			; copy string
	pop	ds
	pop	es
	mov	cx,envlen		; string length again
	ret
fqryenv	endp

; Read chars from Take file, keyboard, or redirected stdin. Edit and remove
; BS & DEL, Tab becomes space, act on Control-C, pass Control-U and Control-W.
; Do echoing unless comand.cmquiet is non-zero. Do semicolon comments in Take
; and indirect stdin files (\; means literal semicolon). Return char in AL.
CMGETC	proc	near			; Basic raw character reader
	mov	read_source,0		; assume direct reading
	mov	endedbackslash,0	; clear end of sub scan flag
cmget01:cmp	comand.cmdirect,0	; read directly?
	jne	cmget02			; ne = yes
	cmp	taklev,0		; in a Take file?
	jne	cmget1			; ne = yes, do Take reader section
cmget02:call	isdev			; is stdin a device or a file?
	jnc	cmget20			; nc = file (redirection of stdin)
	jmp	cmget10			; c = device, do separately

cmget20:call	iseof			; see if file is empty
	jc	cmget21			; c = EOF on disk file
	mov	ah,coninq		; read the char from file, not device
	int	dos
	cmp	al,cr			; is it a cr?
	je	cmget01			; yes, ignore and read next char
	cmp	al,ctlz			; Control-Z?
	je	cmget21			; e = yes, same as EOF here
	cmp	al,lf			; LF's end lines from disk files
	jne	cmget12			; ne = not LF, pass along as is
	mov	al,cr			; make LF a CR for this parser
	call	iseof			; see if this is the last char in file
	jnc	cmget12			; nc = not EOF, process new CR
cmget21:mov	flags.extflg,1		; EOF on disk file, set exit flag
	jmp	cmget12			; do echoing and return

cmget1:	push	bx			; read from Take file
	mov	bx,takadr		; offset of this Take structure
	mov	al,[bx].taktyp
	mov	read_source,al
	cmp	[bx].takcnt,0		; bytes remaining in Take buffer
	jne	cmget4			; ne = not empty
	cmp	al,take_file		; type of Take (file?)
	jne	cmget3			; ne = no (macro)
	call	takrd			; read another buffer
	cmp	[bx].takcnt,0		; anything in the buffer?
	jne	cmget4			; ne = yes
cmget3:	pop	bx			; clear stack
	jmp	short cmget5		; close the Take file

cmget4:	push	si			; read from Take non-empty buffer
	push	es
	mov	es,[bx].takbuf		; segment of Take buffer
	mov	si,[bx].takptr		; current offset in Take buffer
	mov	al,es:[si]		; read a char from Take buffer
	pop	es
	inc	si
	mov	[bx].takptr,si		; move buffer pointer
	pop	si
	dec	WORD PTR [bx].takcnt  	; decrease number of bytes remaining
	cmp	read_source,take_sub	; substitution macro?
	jne	cmget4b			; ne = no
	cmp	[bx].takcnt,0		; read last byte?
	jne	cmget4b			; ne = no
	cmp	al,'\'			; ended on a backsash?
	jne	cmget4b			; ne = no
	mov	endedbackslash,al	; setup break end of sub scan
cmget4b:pop	bx

	cmp	read_source,take_file	; kind of Take/macro, file?
	jne	cmget12			; ne = no, not a file
	cmp	al,LF			; LF?
	je	cmget01			; e = yes, ignore
	cmp	al,ctlz			; Control-Z?
	jne	cmget12			; ne = no, else ^Z = EOF

cmget5:	push	bx			; end of file on Take buffer
	mov	bx,takadr		; offset of this Take structure
	mov	ah,[bx].takattr		; save kind of autoCR
	pop	bx
	cmp	read_source,take_sub	; text subsititution?
	je	cmget5a			; e = yes, cannot keep open
	cmp	comand.cmkeep,0		; keep Take/macro open after eof?
	jne	cmget5b			; ne = yes
cmget5a:
	push	ax
	push	bx
	mov	bx,takadr
cmget5c:mov	al,[bx].takinvoke	; take level of last DO or command
	call	ftakclos		; close take file, saves reg ax
	mov	bx,takadr		; next Take
	test	[bx].takattr,take_autocr ; if macro needs special ending
	jnz	cmget5d			; nz = it does, do not autoclose here
	cmp	[bx].takcnt,0		; empty?
	jne	cmget5d			; ne = no, done closing
	cmp	taklev,0		; any Take levels left?
	je	cmget5d			; e = no
	cmp	taklev,al		; still in last DO?
	jae	cmget5c			; ae = yes, try closing again
cmget5d:pop	bx
	pop	ax

	test	ah,take_autocr		; add CR on EOF?
	jnz	cmget5b			; nz = yes
	jmp	cmgetc			; internal macros have no auto CR
cmget5b:mov	al,CR			; report CR as last char
	jmp	short cmget12
					; read from tty device
cmget10:mov	ah,coninq		; Get a char from device, not file
	int	dos			;  with no echoing
	or	al,al
	jnz	cmget11			; ignore null bytes of special keys
	int	dos			; read and discard scan code byte
	jmp	short cmget10		; try again
cmget11:cmp	al,LF			; LF?
	jne	cmget12			; ne = no
	mov	al,CR			; replace interactive LF with CR

cmget12:cmp	al,'C'and 1Fh		; Control-C?
	je	cmget14			; e = yes
	cmp	al,TAB			; tab is replaced by space
	jne	cmget13			; ne = not tab
	mov	al,' '
cmget13:ret				; normal exit, char is in AL

cmget14:cmp	in_showprompt,0		; Non-zero when in showprompt
	jne	cmget13			; ne = yes, no editing
	test	read_source,take_sub+take_macro	; substitution or macro?
	jnz	cmget13			; nz = yes, do not edit line
	mov	bracecnt,0
	mov	ah,prstr		; Control-C handler
	push	dx
	mov	dx,offset ctcmsg	; show Control-C
	int	dos
	pop	dx
	mov	flags.cxzflg,'C'	; tell others the news
	jmp	cmexit			; fail immediately via longjmp
cmgetc	endp

; Read chars from user (cmgetc). Detect terminators. Reads from buffer
; cmbuf. Set read pointer cmrptr to next free buffer byte if
; char is not a terminator: chars CR, LF, FF, '?' (returns carry set for
; terminators). Do ^U, ^W editing, convert FF to CR plus clear screen.
; Edit "-<cr>" as line continuation, "\-<cr>" as "-<end of line>".
; Return char in AH.
CMINBF	proc	near			; Buffer reader, final editor
	cmp	cmwptr,offset cmdbuf+size cmdbuf-3 ; max buffer size - 3
	jb	cminb1			; b = not full for writing
	mov	ah,conout		; almost full, notify user
	push	dx
	mov	dl,bell
	int	dos
	pop	dx
	cmp	cmrptr,offset cmdbuf+size cmdbuf ; reading beyond buffer?
	jb	cminb1			; b = no
cminb0:	mov	al,taklev		; current Take level
	or	al,al
	jz	cminb0a			; z = none open, exit parse error
	call	ftakclos		; close Take file
	jmp	short cminb0		; do all
cminb0a:mov	ah,prstr
	mov	dx,offset cmer09	; command too long
	int	dos
	jmp	prserr			; overflow = parse error

cminb1:	push	bx
	mov	bx,cmrptr		; read pointer
	mov	ah,[bx]			; get current command char while here
	cmp	bx,cmwptr		; do we need to read more?
	pop	bx			; no if cmrptr < cmwptr
	jb	cminb2			; b: cmrptr < cmwptr (have extra here)
	call	cmgetc			; no readahead, read another into al
	mov	ah,al			; keep char in 'ah'
	cmp	read_source,take_sub	; substitution?
	je	cminb1a			; e = yes
	cmp	cmrawptr,offset rawbuf+cmdblen ; overflow check on rawbuf
	ja	cminb0			; a = overflowed
	push	bx
	mov	bx,cmrawptr		; where raw writes go (inc remakes)
	mov	[bx],ah			; store byte
	inc	cmrawptr
	pop	bx

cminb1a:push	bx
	mov	bx,cmwptr		; get the pointer into the buffer
	mov	[bx],ah			; put it in the buffer
	inc	bx
	mov	cmwptr,bx		; inc write pointer
	pop	bx
	jmp	short cminb1		; call cmgetc until cmwptr >= cmrptr
					; Char to be delivered is in ah
cminb2:	cmp	in_showprompt,0		; Non-zero when in showprompt
	jne	cminb5			; ne = yes, no editing
	test	read_source,take_sub+take_macro	; substitution or macro?
	jnz	cminb4			; nz = yes, do not edit line
	cmp	ah,'W' and 1fh		; is it a ^W?
	jne	cminb3			; ne = no
	call	cntrlw			; kill the previous word
	jmp	repars			; need a new command scan (cleans stk)

cminb3:	cmp	ah,'U' and 1fh		; is it a ^U?
	jne	cminb3a			; ne = no
	mov	cmwptr,offset cmdbuf	; reset buffer write pointer
	mov	cmrptr,offset cmdbuf
	mov	cmrawptr,offset rawbuf	; clear raw buffer
	jmp	repars			; go start over (cleans stack)
					; BS and DEL
cminb3a:cmp	ah,DEL			; delete code?
	je	cminb3b			; e = yes
	cmp	ah,BS			; Backspace (a delete operator)?
	jne	cminb4			; ne = no
cminb3b:call	bufdel			; delete char from buffer
	jc	cminb3c			; c = did erasure
	jmp	cminbf			; no erasure, ignore BS, get more
cminb3c:jmp	repars			; could have deleted previous token

cminb4:	push	bx			; look for hyphen or \hyphen
	cmp	ah,CR			; check for hyphen line continuation
	jne	cminb4b			; ne = not end of line
	call	crprot			; protect CR?
	jnc	cminb4e			; nc = no
					; cmtxt {continued lines} section
	dec	cmwptr			; back over CR for both buffers
	dec	cmrptr
	mov	bx,cmwptr
	mov	ah,','			; replace CR with comma
	mov	[bx-1],ah
	mov	bx,cmrawptr
	mov	[bx-1],ah
	mov	bx,cmrptr
	mov	[bx],ah
					; deal with echoing
	cmp	comand.cmquiet,0	; quiet mode?
	jne	cminb4g			; yes, skip echoing
	cmp	comand.cmdirect,0	; direct reading?
	jne	cminb4f			; ne = yes, do echoing
	cmp	taklev,0		; in a take file?
	je	cminb4f			; e = no
	cmp	read_source,take_comand	; command reread macro?
	je	cminb4f			; e = yes, echo
	cmp	flags.takflg,0		; echo take file?
	je	cminb4g			; e = no
	cmp	read_source,take_sub	; don't echo string substitution
	je	cminb4g
cminb4f:
	push	ax
	push	dx
	mov	dl,ah
	mov	ah,conout		; echo comma to screen now
	int 	dos
	mov	ah,prstr		; and then visually break the line
	mov	dx,offset crlf
	int	dos
	pop	dx
	pop	ax
cminb4g:pop	bx
	clc				; returns ah = comma
	ret
					; start regular hyphenation part
cminb4e:mov	bx,cmwptr		; get the pointer into the buffer
	cmp	bx,offset cmdbuf+2	; do we have a previous char?
	jb	cminb4b			; b = no
	cmp	byte ptr[bx-2],'-'	; previous char was a hyphen?
	jne	cminb4b			; ne = no
	pop	bx
	sub	cmwptr,2		; back over -<cr> for both buffers
	sub	cmrawptr,2
	jmp	repars			; reparse what we now have
cminb4b:pop	bx
					; Echoing done here
	cmp	comand.cmquiet,0	; quiet mode?
	jne	cminb5			; yes, skip echoing
	cmp	comand.cmdirect,0	; direct reading?
	jne	cminb4a			; ne = yes, do echoing
	cmp	taklev,0		; in a take file?
	je	cminb4a			; e = no

	cmp	read_source,take_comand	; command reread macro?
	je	cminb4a			; e = yes, echo
	cmp	flags.takflg,0		; echo take file?
	je	cminb5			; e = no
	cmp	read_source,take_sub	; don't echo string substitution
	je	cminb5

cminb4a:push	ax			; save the char
	cmp	ah,' '			; printable?
	jae	cminb4c			; yes, no translation needed
	cmp	ah,CR			; this is printable
	je	cminb4c
	cmp	ah,LF
	je	cminb4c
	cmp	ah,ESCAPE		; escape?
	je	cminb4d			; do not echo this character
	push	ax			; show controls as caret char
	push	dx
	mov	dl,5eh			; caret
	mov	ah,conout
	int	dos
	pop	dx
	pop	ax
	add	ah,'A'-1		; make control code printable
cminb4c:push	dx
	mov	dl,ah
	mov	ah,conout
	int	dos			; echo it ourselves
	pop	dx
cminb4d:pop	ax			; and return char in ah

cminb5:	cmp	ah,CR			; carriage return?
	je	cminb6			; e = yes
	cmp	ah,LF			; line feed?
	je	cminb6
	cmp	ah,FF			; formfeed?
	jne	cminb7			; none of the above, report bare char
	call	fcmblnk			; FF: clear the screen and
	push	bx
	push	cx
	push	dx
	call	flocate			; Home the cursor
	mov	bx,cmwptr		; make the FF parse like a cr
	mov	byte ptr [bx-1],cr	; pretend a carriage return were typed
	pop	dx
	pop	cx
	pop	bx
cminb6: cmp	cmwptr,offset cmdbuf	; parsed any chars yet?
	jne	cminb7			; ne = yes
	cmp	comand.cmcr,0		; bare cr's allowed?
	jne	cminb7			; ne = yes
	jmp	prserr			; If not, just start over
cminb7:	clc
	ret
cminbf	endp

; Read chars from cminbf. Cmrptr points to next char to be read.
; Compresses repeated spaces if cmsflg is non-zero. Exit with cmrptr pointing
; at a terminator or otherwise at next free slot.
; Non-space then space acts as a terminator but cmrptr is incremented.
; Substitution variables, '\%x', and \numbers are detected and expanded.
; Return char in AH.
; If a \blah parse fails then report the \ to the caller and start over, 
; without echo, on the char following that \. Replay_skip does the \
; passage without calling subst, replay_cnt rereads bytes after it.
CMGTCH	proc	near			; return char in AH, from rescan buf
	cmp	replay_cnt,0		; starting a replay?
	je	cmgtc5			; e = no
	mov	replay_skip,1		; set latch to skip subst on 1st byte
cmgtc5:	cmp	in_reparse,0		; replaying material?
	je	cmgtc0			; e = no
	call	remake			; remake command line as macro

cmgtc0:	cmp	replay_cnt,0		; replay with no echo?
	jne	cmgtc1			; ne = yes, have in cmdbuf now
	call	cminbf			; get char from buffer or user
cmgtc1:	push	bx
	mov	bx,cmrptr		; get read pointer into the buffer
	mov	ah,[bx]			; read the next char
	inc	bx
	mov	cmrptr,bx		; where to read next time
	cmp	replay_cnt,0		; replaying?
	jne	cmgtc6			; ne = yes, don't take the branch
	cmp	bx,cmwptr		; still reading analyzed text?
cmgtc6:	pop	bx
	jb	cmgtc2			; b = yes, don't reexpand
	cmp	replay_skip,0		; replay latch set?
	je	cmgtc7			; e = no, re-read new bytes in subst
	mov	replay_skip,0 		; clear latch after the first re-read byte
	jmp	cmgtc2			; and skip subst on that first byte
	cmp	replay_cnt,0		; replaying?
	jne	cmgtc2			; ne = yes
cmgtc7:
	call	subst			; examine for text substitution
	jc	cmgtch			; c = reread input material
	cmp	report_binary,0		; report binary number directly?
	je	cmgtc2b			; e = no
	mov	report_binary,0		; clear flag
	clc				; value is in ah, non-terminator
	ret

cmgtc2:	push	bx
	mov	bx,replay_cnt		; count down replay bytes
	or	bx,bx	
	jz	cmgtc2a			; z = empty 
	dec	replay_cnt
cmgtc2a:pop	bx
cmgtc2b:cmp	ah,','			; comma?
	jne	cmgtc2c			; ne = no
	cmp	comand.cmcomma,0	; comma is space equivalent?
	je	cmgtc2c			; e = no
	mov	ah,' '			; convert comma to space
cmgtc2c:cmp	ah,' '			; space?
	jne	cmgtc3			; ne = no
	cmp	cmsiz,0			; started user data?
	je	cmgtc2d			; e = no, this is a leading space
	cmp	cmkind,cmline		; doing full lines of text?
	je	cmgtc3			; e = yes, retain all spaces
cmgtc2d:cmp	bracecnt,0		; are we within braces?
	jne	cmgtc3			; ne = yes, treat space as literal
	cmp	cmsflg,0		; space flag, was last char a space?
	jne	cmgtch			; ne = yes, get another char
	mov	cmsflg,0FFH		; set the space(s)-seen flag
	stc				; set carry for terminator
	ret				; return space as a terminator
cmgtc3: mov	cmsflg,0		; clear the space-seen flag
	cmp	ah,braceop		; opening brace?
	jne	cmgtc3b			; ne = no
	inc	bracecnt		; count it
	jmp	short cmgtc3c
cmgtc3b:cmp	ah,bracecl		; closing brace?
	jne	cmgtc3c			; ne = no
	sub	bracecnt,1		; count down and get a sign bit
	jns	cmgtc3c			; ns = no underflow
	mov	bracecnt,0		; catch underflows
					; terminators remain in buffer but
					;  are ready to be overwritten
cmgtc3c:test	read_source,take_sub	; substitution macro?
	jnz	cmgtc3d			; nz = yes, pass all bytes as data
	cmp	ah,escape		; Escape expander?
	jne	cmgtc3e			; ne = no
	cmp	read_source,0		; reading from keyboard directly?
	jne	cmgtc4			; ne = no, escape is regular char

cmgtc3e:cmp	ah,'?'			; is the user curious?
	jne	cmgtc3a			; ne = no
	cmp	taklev,0		; in a Take file?
	jne	cmgtc3d			; ne = yes, make query ordinary char
	je	cmgtc4
cmgtc3a:cmp	ah,CR			; these terminators?
	je	cmgtc4			; e = yes
	cmp	ah,LF
	je	cmgtc4
	cmp	ah,FF
	je	cmgtc4
	cmp	ah,ESCAPE
	je	cmgtc4
cmgtc3d:clc				; carry clear for non-terminator
	ret
cmgtc4:	dec	cmrptr			; point at terminating char
	stc				; set carry to say it is a terminator
	ret
cmgtch	endp

; Reset cmdbuf write pointer (cmwptr) to where the read pointer
; (cmrptr) is now. Discards material not yet read.
bufreset proc	near
	push	cmrptr			; where next visible char is read
	push	ax			; count removed curly braces
	push	si
	mov	si,cmrptr		; where to look
	mov	cx,cmwptr		; last place being removed
	xor	ah,ah			; get a null
	sub	cx,si			; length to examine
	jle	bufres3a		; le = nothing to scan
	cld
bufres1:lodsb
	cmp	al,braceop		; opening brace, counted already?
	jne	bufres2			; ne = no
	dec	bracecnt		; uncount it
	jmp	short bufres3
bufres2:cmp	al,bracecl		; closing brace, counted already?
	jne	bufres3			; jne = no
	inc	bracecnt		; uncount it
bufres3:loop	bufres1
bufres3a:cmp	bracecnt,ah		; negative?
	jge	bufres4			; ge = no
	mov	bracecnt,ah
bufres4:mov	word ptr [si],0		; terminate buffer
	pop	si
	pop	ax
	pop	cmwptr			; where new char goes in buffer
	ret
bufreset endp

; Delete character from screen and adjust buffer. Returns carry clear if
; no erasure, carry set otherwise.
bufdel	proc	near
	cmp	read_source,take_sub	; substitution macro?
	je	bufdel0			; e = yes, does not change cmrawptr
	cmp	cmrawptr,offset rawbuf	; anything written to base level buf?
	ja	bufdel7			; a = yes
	mov	cmrawptr,offset rawbuf	; safety
	mov	ax,offset cmdbuf
	mov	cmrptr,ax
	mov	cmwptr,ax
	clc				; do nothing
	ret
bufdel7:dec	cmrawptr		; backup one byte
	push	bx
	mov	bx,cmrawptr
	cmp	byte ptr [bx],BS	; last read was BackSpace?
	pop	bx
	jne	bufdel8			; ne = not BS
	dec	cmrawptr		; backup write pointer over BS too
bufdel8:cmp	cmrawptr,offset rawbuf	; sanity check, back too far?
	jae	bufdel9			; ae = not too far
	mov	cmrawptr,offset rawbuf	; reset to start of buffer
bufdel9:cmp	comand.cmdirect,0	; doing direct reading?
	jne	bufdel0			; ne = yes
	mov	ax,offset cmdbuf
	mov	cmwptr,ax		; reset normal parse buffer
	mov	cmrptr,ax
	mov	bx,ax
	mov	word ptr [bx],0		; terminate buffer
	mov	in_reparse,1		; say need to replay from rawbuf
	jmp	repars			; reparse command

bufdel0:cmp	cmrptr,offset cmdbuf	; at start of buffer now?
	jbe	bufdel5			; be = yes
	push	ax
	push	si
	mov	si,cmrptr
	mov	al,[si]
	dec	si
	xor	ah,ah			; get a null
	cmp	al,braceop		; opening brace, counted already?
	jne	bufdel1			; ne = no
	dec	bracecnt		; uncount it
	jmp	short bufdel2
bufdel1:cmp	al,bracecl		; closing brace?
	jne	bufdel2			; ne = no
	inc	bracecnt		; uncount it
bufdel2:cmp	bracecnt,ah		; negative?
	jge	bufdel3			; ge = no
	mov	bracecnt,ah
bufdel3:pop	si
	pop	ax
	mov	replay_cnt,0		; clear protected replay byte count
	dec	cmrptr			; remove previous char from buffer
	cmp	cmrptr,offset cmdbuf	; back too far?
	jae	bufdel4			; ae = no, material can be erased
	mov	cmrptr,offset cmdbuf	; set to start of buffer
	mov	bracecnt,ah		; ensure this is now cleared
bufdel5:call	bufreset		; reset buffer
	clc				; say no erasure
	ret
bufdel4:call	bufreset		; reset buffer
	stc				; say did erasure
	ret
bufdel	endp

; Remake the current command line, omitting substitution macro contents,
; as a macro (kind is comand, almost "macro"). Current command line is
; in rawbuf, with cmrawptr pointing next place to write.
; Closes currently active substitution macros.
remake	proc	near
	push	bx
	push	cx
	push	dx
	push	di
	mov	cmrptr,offset cmdbuf
	mov	cmwptr,offset cmdbuf	; clear work buffer
	mov	cx,cmrawptr		; where to write next
	mov	cmrawptr,offset rawbuf
	sub	cx,offset rawbuf	; length of string
	jle	remake3			; le = nothing to do
remake1:cmp	taklev,0		; in a take file?
	je	remake2			; e = no
	mov	bx,takadr
	cmp	[bx].taktyp,take_sub	; sub macro?
	jne	remake2			; ne = no
	push	cx
	call	ftakclos		; close sub macros
	pop	cx
	jmp	short remake1		; next victim
remake2:call	takopen_macro		; open take as macro (comand kind)
	mov	bx,takadr		; pointer to new Take structure
	mov	[bx].taktyp,take_comand ; that's us
	and	[bx].takattr,not take_autocr ; no CR at end of macro please
	mov	[bx].takcnt,cx		; number of unread bytes
	mov	[bx].takbuf,seg rawbuf	; segment of Take buffer
	mov	cx,offset rawbuf
	mov	[bx].takptr,cx 		; offset to read from
	mov	cmrawptr,cx
remake3:mov	in_reparse,0		; clear our flag
	mov	bracecnt,0
	mov	replay_cnt,0
	mov	comand.cmkeep,0
	pop	di
	pop	dx
	pop	cx
	pop	bx
	ret
remake endp

; Come here is user types ^W when during input. Remove word from buffer.
cntrlw	proc	near
	push	ax
	push	cx
	push	dx
	call	bufreset		; truncate buffer at cmrptr
	mov	si,cmwptr		; assumed source pointer
	mov	cx,cmrptr		; read pointer
	sub	cx,offset cmdbuf	; compute chars in buffer
	cmp	comand.cmdirect,0	; direct reading?
	jne	cntrl3			; ne = yes, only one buffer

	dec	cmrawptr		; back over ^W
	mov	si,cmrawptr		; use raw buf as source pointer
	mov	cx,si			; point at last written byte
	sub	cx,offset rawbuf	; count of bytes before ^W
	jle	ctlw2			; le = none
cntrl3:	clc				; say have not yet modified line
	jcxz	ctlw2			; z = nothing to do, exit no-carry
	push	es
	std				; scan backward
	mov	ax,ds
	mov	es,ax			; point to the data are
	mov	di,si			; looking from here
	dec	di
	mov	al,' '
	repe	scasb			; look for non-space
	je	ctlw1			; all spaces, nothing to do
	inc	di			; move back to non-space
	inc	cx
	repne	scasb			; look for a space
	jne	ctlw1			; no space, leave ptrs alone
	inc	di
	inc	cx			; skip back over space
ctlw1:	inc	di
	pop	es
	cld				; reset	direction flag
	mov	cmwptr,di		; update pointer
	cmp	comand.cmdirect,0	; direct reading?
	jne	ctlw2			; ne = yes, only one buffer
	inc	di			; leave a char for bufdel
	mov	cmrawptr,di		; setup delete initial byte of word
	call 	bufdel			; delete item, reparse
ctlw2:	pop	dx
	pop	cx
	pop	ax
	ret
cntrlw	endp

; returns carry set if CR is to be protected
; returns carry clear if CR is unprotected
crprot proc near			; cmtxt {continued lines} section
	cmp	comand.cmcnvkind,cmcnv_crprot	; braces span lines?
	jne	crprotx			; ne = no, do regular hyphenation
	cmp	cmkind,cmkey
	je	crprotx
	cmp	bracecnt,0		; are curly braces matched yet?
	je	crprotx			; e = yes, then this is ignorable
	stc				; CR needs protection
	ret
crprotx:clc
	ret
crprot	endp

; Jump to REPARS to do a rescan of the existing buffer.
; Jump to PRSERR on a parsing error (quits command, clears old read material)

PRSERR	PROC FAR
	mov	cmwptr,offset cmdbuf	; initialize write pointer
	mov	ah,prstr
	mov	dx,offset crlf		; leave old line, start a new one
	int	dos
	call	rprompt			; restore master prompt level
					; reparse current line
REPARS:	mov	cmrptr,offset cmdbuf	; reinit read pointer
	xor	ax,ax
	mov	cmsflg,0ffh		; strip leading spaces
	mov	subcnt,al		; clear substitution state variables
	mov	subtype,al
	mov	bracecnt,al
	call	optionclr		; clear parser options
	cmp	in_showprompt,al	; redoing the prompt itself?
	jne	prser3			; ne = yes, suppress display
	cmp	comand.cmdirect,al	; doing direct reading?
	jne	prser2			; ne = yes
	cmp	taklev,al		; in Take cmd?
	je	prser2			; e = no
	cmp	flags.takflg,al		; echo contents of Take file?
	je	prser3			; e = no
prser2:	call	fctlu			; clear display's line, reuse it
	mov	dx,comand.cmprmp	; display the asciiz prompt
	call	prtasz
prser3:	mov	bx,0ffffh		; returned keyword value
	mov	sp,comand.cmostp	; set new sp to old one
	jmp	dword ptr comand.cmrprs	; jump to just after the prompt call
PRSERR	ENDP

; Restore prompt material to that of the master prompt. This removes settings
; of local PROMPT calls so we can reprompt at the main Kermit level.
RPROMPT	proc	near
	push	ax			; Must preserve AX
	mov	replay_cnt,0
	mov	ax,mcmprmp		; address of prompt string
	or	ax,ax			; any address given yet?
	jz	rprompt1		; z = none, not inited yet
	mov	comand.cmprmp,ax	; set current address ptr
	mov	ax,word ptr mcmrprs	; offset of reparse address
	mov	word ptr comand.cmrprs,ax
	mov	ax,word ptr mcmrprs+2	; segment of reparse address
	mov	word ptr comand.cmrprs+2,ax
	mov	ax,mcmostp		; stack ptr at reparse time
	mov	comand.cmostp,ax
	mov	cmrawptr,offset rawbuf	; base/raw buffer write ptr, reset
	mov	in_reparse,0		; clear buffer remake flag
rprompt1:pop	ax
	ret
RPROMPT	endp

; Clear comand.* options to defaults
optionclr proc	near
	push	ax
	xor	ax,ax
	mov	comand.cmwhite,al	; clear whitespace flag
	mov	comand.cmper,al		; reset to variable recognition
	mov	comand.cmkeep,al	; do not keep Take file open
	mov	comand.impdo,al		; clear flag to prevent loops
	mov	comand.cmquiet,al	; permit echoing again
	mov	comand.cmblen,ax	; set user buffer length to unknown
	mov	comand.cmdonum,al	; defeat \number expansion
	mov	comand.cmcomma,al	; comma is not a space
	mov	comand.cmarray,al	; disallow sub in [..]
	mov	comand.cmcnvkind,cmcnv_none ; default is no conversion
	pop	ax
	ret
optionclr endp

; write \v(ARGC) contents to ds:di
wrtargc	proc	near
	xor	ax,ax
	cmp	taklev,0		; in a Take/Macro?
	je	wrtarg1			; e = no
	mov	bx,takadr		; current Take structure
	mov	ax,[bx].takargc		; get ARGC
wrtarg1:call	fdec2di			; write as ascii
	mov	word ptr es:[di],0020h	; space and null terminator
	ret
wrtargc	endp

; write \v(COUNT) text to ds:di
wrtcnt	proc	near
	xor	ax,ax
	cmp	taklev,0		; in a Take/Macro?
	je	wrtcnt1			; e = no
	mov	bx,takadr		; current Take structure
	mov	ax,[bx].takctr		; get COUNT
wrtcnt1:call	fdec2di			; write as ascii
	ret
wrtcnt	endp

; write \v(DATE) text to ds:di
wrtdate	proc	near
	push	cx
	push	dx
	mov	ah,getdate		; DOS date (cx= yyyy, dh= mm, dl= dd)
	int	dos
	xor	ah,ah
	mov	al,dl			; day
	call	wrtdat5
	mov	byte ptr es:[di],' '
	inc	di
	xor	bh,bh
	mov	bl,dh			; month
	dec	bx			; count from zero
	shl	bx,1			; count four byte groups
	shl	bx,1
	mov	ax,word ptr month[bx]
	stosw
	mov	ax,word ptr month[bx+2]
	stosw
	mov	ax,cx			; year
wrtdat3:call	wrtdat5
	mov	word ptr es:[di],0020h	; space and null terminator
	pop	dx
	pop	cx
	ret

wrtdat5:cmp	ax,10			; leading tens digit present?
	jae	wrtdat6			; ae = yes
	mov	byte ptr es:[di],'0'	; insert leading 0
	inc	di
wrtdat6:call	fdec2di			; write decimal asciiz to buffer
	ret

wrtdate	endp

; write \v(ERRORLEVEL) text to ds:di
wrterr	proc	near
	mov	al,errlev		; current Errorlevel
	xor	ah,ah
	call	fdec2di			; write as ascii
	mov	word ptr es:[di],0020h	; space and null terminator
	ret
wrterr	endp

; write \v(KEYBOARD) text to ds:di
wrtkbd	proc	near
	mov	ax,keyboard		; 88 or 101 keyboard keys
	call	fdec2di			; write as ascii
	mov	word ptr es:[di],0020h	; space and null terminator
	ret
wrtkbd	endp

; write \v(NDATE) text to ds:di
; where NDATE is YYYYMMDD
wrtndate proc	near
	mov	ah,getdate		; DOS date (cx= yyyy, dh= mm, dl= dd)
	int	dos
	push	dx			; save dx
	mov	ax,cx			; year
	call	fdec2di			; convert it
	pop	dx			; get mm:dd
	push	dx
	mov	al,dh			; months are next
	xor	ah,ah
	cmp	al,10			; less than 10?
	jae	wrtndat1		; ae = no
	mov	byte ptr es:[di],'0'	; leading 0
	inc	di
wrtndat1:call	fdec2di
	pop	dx
	mov	al,dl			; get days
	xor	ah,ah
	cmp	al,10			; less than 10?
	jae	wrtndat2		; ae = no
	mov	byte ptr es:[di],'0'	; leading 0
	inc	di
wrtndat2:call	fdec2di
	mov	word ptr es:[di],0020h	; space and null terminator
	ret
wrtndate endp

; write \v(DIRECTORY) text to es:di
wrtdir	proc	near
	push	si
	mov	ah,gcurdsk		; get current disk
	int	dos
	add	al,'A'			; make al = 0 == 'A'
	stosb
	mov	ax,'\:'
	stosw
	mov	si,di			; work buffer
	push	ds
	mov	cx,es
	mov	ds,cx
	mov	ah,gcd			; get current directory
	xor	dl,dl			; use current drive
	int	dos			; get ds:si = asciiz path (no drive)
	pop	ds
	mov	dx,si
	push	ds
	mov	cx,es
	mov	ds,cx
	call	strlen
	pop	ds
	add	di,cx
wrtdir1:mov	word ptr es:[di],0020h	; space and null terminator
	pop	si
	ret
wrtdir	endp

fwrtdir	proc	far
	call	wrtdir
	ret
fwrtdir	endp

; write \v(PLATFORM) text to ds:di
wrtplat	proc	near
	push	si
	mov	si,offset machnam	; machine name in sys dep file
	cld
wrtplat1:lodsb				; get a char
	cmp	al,'$'			; terminator?
	je	wrtplat2		; e = yes
	stosb				; store char
	jmp	short wrtplat1		; keep going
wrtplat2:mov	word ptr es:[di],0020h	; space and null terminator
	pop	si
	ret
wrtplat	endp

; write \v(PORT) text to ds:di
wrtport	proc	near
	push	bx
	push	si
	mov	al,flags.comflg		; get coms port indicator
	mov	bx,offset comptab	; table of comms ports
	mov	cl,[bx]			; number of entries
	xor	ch,ch
	inc	bx
wrtpor3:mov	dx,[bx]			; length of this entry
	mov	si,bx
	add	si,2			; points to entry text string
	add	si,dx			; point to qualifier
	cmp	[si],al			; our port?
	je	wrtpor4			; e = yes
	add	bx,[bx]			; add text length
	add	bx,4			; plus count and qualifier
	loop	wrtpor3			; next entry
	jmp	short wrtpor5		; no match, curious
wrtpor4:mov	si,bx			; point at entry
	add	si,2			; point at string
	mov	cx,[bx]			; length of string
	cld
	rep	movsb			; copy to DS:DI
wrtpor5:mov	word ptr es:[di],0020h	; space and null terminator
	pop	si
	pop	bx
	ret
wrtport	endp

; write \v(PROGRAM) text to ds:si
wrtprog	proc	near
	push	si
	mov	si,offset progm		; source string
	cld
wrtprg1:lodsb
	cmp	al,'$'			; terminator?
	je	wrtprg2			; e = yes
	stosb				; store the char
	jmp	short wrtprg1
wrtprg2:mov	word ptr es:[di],0020h	; space and null terminator
	pop	si
	ret
wrtprog	endp

; write \v(STATUS) text to ds:di
wrtstat	proc	near
	mov	ax,kstatus		; Kermit status word
	call	fdec2di
	mov	word ptr es:[di],0020h	; space and null terminator
	ret
wrtstat	endp

; write \v(SYSTEM) text to ds:di
wrtsystem proc	near
	push	si
	mov	si,offset system	; system string "MS-DOS", dollar sign
	cld
	jmp	wrtplat1		; use some common code
wrtsystem endp

; write \v(TIME) text to ds:di
wrttime	proc	near
	mov	ah,gettim		; DOS tod (ch=hh, cl=mm, dh=ss, dl=.s)
	int	dos
	push	dx			; save dx
	xor	ah,ah
	mov	al,ch			; Hours
	cmp	al,10			; leading digit?
	jae	wrttim1			; ae = yes
	mov	byte ptr es:[di],'0'	; make our own
	inc	di
wrttim1:call	fdec2di			; write decimal asciiz to buffer
	mov	byte ptr es:[di],':'
	inc	di
	xor	ah,ah
	mov	al,cl			; Minutes
	cmp	al,10			; leading digit?
	jae	wrttim2			; ae = yes
	mov	byte ptr es:[di],'0'	; make our own
	inc	di
wrttim2:call	fdec2di			; write decimal asciiz to buffer
	mov	byte ptr es:[di],':'
	inc	di
	pop	dx
	xor	ah,ah
	mov	al,dh			; Seconds
	cmp	al,10			; leading digit?
	jae	wrttim3			; ae = yes
	mov	byte ptr es:[di],'0'	; make our own
	inc	di
wrttim3:call	fdec2di			; write decimal asciiz to buffer
	mov	word ptr es:[di],0020h	; space and null terminator
	ret
wrttime	endp

; write \v(Version) text to ds:di
wrtver	proc	near
	mov	si,offset verident	; MS Kermit version string in mssker
	cld
wrtver1:lodsb
	stosb
	cmp	al,'$'			; end of string?
	jne	wrtver1			; ne = no, continue copying
	dec	di
	mov	word ptr es:[di],0020h	; space and null terminator
	ret
wrtver	endp

; write \v(TERMINAL) text to ds:di
wrtterm	proc	near
	mov	ax,flags.vtflg		; current terminal type
	mov	bx,offset termtb	; terminal type table msx...
	mov	cl,[bx]			; number of entries in our table
	xor	ch,ch
	inc	bx			; point to the data
wrtter1:mov	si,[bx]			; length of keyword
	cmp	ax,[bx+si+2]		; value fields match?
	je	wrtter2			; e = yes
	add	bx,si			; add word length
	add	bx,4			; skip count and value fields
	loop	wrtter1			; keep searching
	jmp	short wrtter4		; no match, use just a space
wrtter2:mov	cx,[bx]			; get length of counted string
	mov	si,bx
	add	si,2			; look at text
	cld
	rep	movsb
wrtter4:mov	word ptr es:[di],0020h	; space and null terminator
	ret
wrtterm	endp

fcmgtch	proc	far
	call	cmgtch
	ret
fcmgtch	endp

code1	ends

code	segment
	assume	cs:code

; Set master prompt level. Enter with DX = offset of prompt string
MPROMPT	proc	near
	mov	mcmprmp,dx		; offset of prompt string
	pop	ax			; get the return address
	mov	word ptr mcmrprs,ax 	; offset to go to on reparse
	mov	mcmostp,sp		; stack pointer at reparse time
	push	ax			; put it on the stack again
	mov	ax,cs			; our current code segment
	mov	word ptr mcmrprs+2,ax 	; segment of reparse address
	mov	comand.cmdirect,0	; read normally (vs force to kbd/file)
	mov	cmrawptr,offset rawbuf	; base/raw buffer write ptr, reset
	mov	cmwptr,offset cmdbuf
	mov	cmrptr,offset cmdbuf
MPROMPT	endp

; This routine prints the prompt and specifies the reparse address.
; Enter with pointer to prompt string in dx. 
PROMPT	PROC  NEAR
	xor	ax,ax			; get a zero
	xchg	al,comand.cmdirect	; set cmdirect to zero for showprompt
	xchg	ah,comand.cmper
	push	ax
	xor	al,al
	xchg	al,flags.takflg		; take echo flag, off in showprompt
	push	ax
	call	showprompt		; convert string with variables
	pop	ax
	xchg	al,flags.takflg		; restore take echo flag
	pop	ax
	mov	comand.cmdirect,al	; restore direct mode (if any)
	mov	comand.cmper,ah
	mov	comand.cmprmp,dx	; save the prompt
	pop	ax			; get the return address
	mov	word ptr comand.cmrprs,ax ; offset to go to on reparse
	mov	comand.cmostp,sp	; save for later restoration
	push	ax			; put it on the stack again
	mov	ax,cs			; our current code segment
	mov	word ptr comand.cmrprs+2,ax ; segment of reparse address
	mov	ax,offset cmdbuf
	mov	cmrptr,ax		; reset buffer read/write pointers
	mov	cmwptr,ax
	mov	cmrawptr,offset rawbuf
	mov	in_reparse,0
	xor	ax,ax
	mov	subcnt,al		; substitution variable state info
	mov	subtype,al
	mov	bracecnt,al
	mov	replay_cnt,ax
	mov	cmsiz,ax
	mov	comand.cmper,al		; allow substitutions
	mov	cmsflg,0ffh		; remove leading spaces
	cmp	comand.cmdirect,al	; doing direct reading?
	jne	promp1			; ne = yes
	cmp	flags.takflg,al		; look at Take flag, zero?
	jne	promp1			; ne=supposed to echo, skip this check
	cmp	taklev,al		; inside a take file?
	je	promp1			; e = no, keep going
	clc
	ret				; yes, return
promp1:	mov	ah,prstr
	mov	dx,offset crlf
	int	dos
	mov	dx,comand.cmprmp	; prompt pointer
	call	prtasz			; show asciiz prompt string
	clc
	ret
PROMPT	ENDP

; Convert ASCIIZ prompt string given in DS:DX to string in DS:comand.cmprmp
; with expansion of substitution variables. Final prompt is in DX and in
; comand.cmprmp = offset cmdbuf+cmdblen/2 (of a 1000 byte total buffer).
showprompt proc far
	cmp	in_showprompt,0		; doing this routine already?
	je	showp0			; e = no
	mov	dx,comand.cmprmp	; yes, return current prompt string
	ret
showp0:	mov	word ptr cmdbuf+cmdblen/2,0	; clear final prompt string
	mov	comand.cmprmp,offset cmdbuf+cmdblen/2 ; prompt pointer
	mov	si,dx			; raw prompt string ds:dx
	call	strlen			; get string length
	or	cx,cx			; empty?
	jnz	showp1			; nz = no
	ret				; return empty prompt string
showp1:	inc	cx			; include null in length
	mov	al,taklev		; entering taklev
	cmp	al,maxtak		; room in take level?
	jb	showp2			; b = yes
	mov	comand.cmprmp,dx	; original raw prompt offset
	ret				; return it

showp2:	push	ax			; save take level
	mov	si,offset cmdbuf	; reset parse buffer pointers
	mov	cmrptr,si
	mov	cmwptr,si
	mov	cmrawptr,offset rawbuf
	xor	ax,ax
	mov	subcnt,al		; clear substitution state variables
	mov	subtype,al
	mov	bracecnt,al
	call	takopen_sub		; open take as text substitution
	mov	bx,takadr		; address of take structure
	mov	ax,ds
	mov	[bx].takbuf,ax		; segment of Take buffer
	mov	[bx].takptr,dx 		; offset of beginning of def text
	mov	[bx].takcnt,cx		; # of chars in buffer (includes NUL)
	or	[bx].takattr,take_autocr ; imply CR at end of prompt
	mov	in_showprompt,1		; say making new prompt
	xor	ax,ax
	mov	cmsflg,al		; get all spaces
	mov	comand.cmper,al		; reset to variable recognition
	mov	comand.cmquiet,1	; no echo
	mov	comand.cmwhite,1	; leading white space is ok
	mov	comand.cmcr,1		; bare cr's allowed
	mov	comand.cmostp,sp	; set reprompt stack pointer here
	mov	comand.cmcnvkind,cmcnv_none ; default is no conversion
	mov	cmkind,cmword		; say getting a word, not a line
	mov	comand.cmdonum,0	; disable \number expansion
	mov	word ptr comand.cmrprs,offset showp3 ; offset for reparse
	mov	ax,cs			; our current code segment
	mov	word ptr comand.cmrprs+2,ax ; segment of reparse address

showp3:	mov	cmptab,offset cmdbuf+cmdblen/2 ; buffer for new string
	mov	comand.cmblen,(cmdblen/2)-100 ; length of our buffer (plenty)

showp4:	call	fcmgtch			; get a char
	jnc	showp5			; nc = non-terminator
	cmp	ah,' '			; space terminator?
	je	showp5			; e = yes
	inc	cmrptr			; 'read' other kinds of terminator
showp5:	mov	bx,cmptab		; pointer into destination array
	mov	[bx],ah			; put char into the buffer
	inc	bx
	xor	al,al
	mov	[bx],al			; insert null terminator
	mov	cmptab,bx
	cmp	bx,offset cmdbuf+cmdblen ; end of buffer?
	jae	showp6			; ae = end of buffer, terminate
	mov	cmsflg,0		; still get spaces
	or	ah,ah			; this terminator?
	jnz	showp4			; nz = no, keep reading

showp6:	pop	ax			; saved entering taklev
	cmp	al,taklev		; saved versus current taklev
	jae	showp7			; ae = nothing new to be removed
	push	ax			; save again for loop
	call	takclos			; close Take file
	jmp	showp6			; keep at it
showp7:	xor	ax,ax
	mov	comand.cmwhite,al	; clear leading whitespace flag
	mov	comand.cmblen,ax	; set user buffer length to unknown
	mov	comand.cmquiet,al	; enable echo
	mov	comand.cmcr,al		; bare cr's not allowed
	mov	comand.cmdonum,al	; disable \number expansion
	mov	in_showprompt,al	; done making new prompt
	mov	dx,offset cmdbuf+cmdblen/2 ; return in DX
	mov	comand.cmprmp,dx	 ; returned prompt pointer
	mov	subcnt,al
	mov	subtype,al
	ret
showprompt endp
code	ends

code1	segment
	assume	cs:code1

ISDEV	PROC	FAR			; Set carry if STDIN is non-disk
	push	ax
	push	bx
	push	dx
	xor	bx,bx			; handle 0 is stdin
	xor	al,al			; get device info
	mov	ah,ioctl
	int	dos
	rcl	dl,1			; put ISDEV bit into the carry bit
	pop	dx			; carry is set if device
	pop	bx
	pop	ax
	ret				; carry set if device
ISDEV	ENDP

ISEOF	PROC	FAR			; Set carry if STDIN is at EOF
	push	ax			;  but only if stdin is a non-device
	push	bx
	push	dx
	xor	bx,bx			; handle 0 is stdin
	xor	al,al			; get device info
	mov	ah,ioctl
	int	dos
	mov	ah,ioctl
	mov	al,6			; get handle input status, set al
	test	dl,80h			; bit set if handle is for a device
	jnz	iseof1			; nz = device, always ready (al != 0)
	int	dos
iseof1:	or	al,al			; EOF?
	pop	dx
	pop	bx
	pop	ax
	jnz	iseof2			; nz = no
	stc				; set carry for eof
	ret
iseof2:	clc				; clear carry for not-eof
	ret
ISEOF	ENDP

; Convert ascii characters in al and ah to lowercase.
; All registers are preserved except AX, of course.

TOLOWR PROC FAR
	cmp	ah,'A'			; less that cap A?
	jl	tolow1			; l = yes. leave untouched
	cmp	ah,'Z'+1		; more than cap Z?
	jns	tolow1			; ns = yes
	or	ah,20H			; convert to lowercase
tolow1:	cmp	al,'A'			; less that cap A?
	jl	tolow2			; l = yes. leave untouched
	cmp	al,'Z'+1		; more than cap Z?
	jns	tolow2			; ns = yes
	or	al,20H			; convert to lower case
tolow2:	ret
TOLOWR	endp

TOUPR PROC FAR
	cmp	ah,'a'			; less that lower A?
	jb	toup1			; l = yes. leave untouched
	cmp	ah,'z'			; more than lower Z?
	ja	toup1			; ns = yes
	and	ah,not 20H		; convert to upper case
toup1:	cmp	al,'a'			; less that lower A?
	jb	toup2			; l = yes. leave untouched
	cmp	al,'z'			; more than lower Z?
	ja	toup2			; ns = yes
	and	al,not 20H		; convert to upper case
toup2:	ret
TOUPR	endp

; Revise string in ds:si et seq. Expect incoming length to be in CX.
; Controlled by comand.cmcnvkind.
; Original string modified to replace bare commas with Carriage Returns.
; Top level braces removed, but only if the string begins with an 
; opening brace, and hence commas revealed are also converted to CR.
; Converted text has a forced null termination to assist callers of cmtxt
; which don't remember returned byte count.
; All registers preserved except CX (returned length).
unbrace	proc	far
	or	cx,cx			; count of zero or less?
	jg	unbrac1			; g = no, but could be huge
	ret
unbrac1:push	ax
	push	si			; src and dest are ds:si
	push	di
	mov	di,si			; si = source
	add	di,cx			; skip to end of line + 1
unbrac2:cmp	byte ptr [di-1],' '	; trailing space?
	jne	unbrac3			; ne = no
	dec	di			; backup another byte
	loop	unbrac2
unbrac3:cmp	byte ptr [si],braceop	; now opens with brace?
	jne	unbrac4			; ne = no, nothing to do
	cmp	byte ptr [di-1],bracecl	; ended on brace?
	jne	unbrac4			; ne = no, nothing to do
	mov	cx,di			; ending spot
	sub	cx,si			; minus start
	mov	di,si			; destination
	sub	cx,2			; minus opening and closing braces
	inc	si			; skip opening brace
	push	cx
	push	es
	mov	ax,ds
	mov	es,ax
	cld
	rep	movsb			; copy down text inside braces
	xor	al,al
	mov	bx,di			; report null in BX
	stosb				; forced null terminator
	pop	es
	pop	cx
unbrac4:pop	di
	pop	si
	pop	ax
	clc
	ret
unbrace	endp

; Parse control sequences and device control strings.
; Expect CSI, Escape [, or DCS lead-in characters to have been read.
; Puts numerical Parameters in array param (16 bits, count is nparam) and
;  a single letter Parameter in lparam, (Parameters are all ASCII column 3)
;  Intermediate characters in array inter (count is ninter), (ASCII column 2)
;  Final character in AL (ASCII columns 4-7).
; Invoke by setting state to offset atparse, set pardone to offset of
; procedure to jump to after reading Final char (0 means do just ret)
; and optionally setting parfail to address to jump to if parsing failure.
; When the Final char has been accepted this routine jumps to label held in
; pardone for final action. Before the Final char has been read successful
; operations return carry clear.
; Failure exits are carry set, and an optional jump through parfail (if 
; non-zero) or a return.

atparse	proc	near
	mov	bx,parstate		; get parsing state
	or	bx,bx			; have any state?
	jnz	atpars1			; nz = have a state
	call	atpclr			; do initialization
	mov	bx,parstate		; get initial state
atpars1:call	bx			; execute it
	jc	atpfail			; c = failure
	cmp	parstate,offset atpdone	; parsed final char?
	je	atpdone			; e = yes
	ret				; no, wait for another char

				; successful conclusion, final char is in AL
atpdone:mov	parstate,0		; reset parsing state
	cmp	pardone,0		; separate return address defined?
	jne	atpdon1			; ne = yes
	clc
	ret				; else just return
atpdon1:clc
	jmp	pardone			; jmp to supplied action routine

atpfail:mov	parstate,0		; failed, reset parser to normal state
	cmp	parfail,0		; jump address specified?
	je	atpfail1		; e = no
	jmp	parfail			; yes, exit this way
atpfail1:stc
	ret
					; parsing workers
atparm:	cmp	ninter,0		; Parameter, started intermediate yet?
	jne	atinter			; ne = yes, no more parameters
	cmp	al,';'			; argument separator?
	jne	atparm3			; ne = no
	mov	ax,nparam		; number of Parameters
	inc	ax			; say a new one
	cmp	ax,maxparam		; too many?
	jb	atparm2			; b = no, continue
	stc				; set carry to say failed
	ret				; too many, ignore remainder
atparm2:mov	nparam,ax		; say doing another Parameter
	clc
	ret

atparm3:mov	ah,al			; copy char
	and	ah,not 0fh		; ignore low nibble
	cmp	ah,30h			; column 3, row 0? (30h='0')
	jne	atparm6			; ne = no, check Intermediate/Final
	cmp	al,'9'			; digit?
	ja	atparm5			; a = no, check letter Parameters
	sub	al,'0'			; ascii to binary
	mov	bx,nparam		; current parameter number
	shl	bx,1			; convert to word index
	mov	cx,param[bx]		; current parameter value
	shl	cx,1			; multiply by 10.  2 * cl
	push	bx
	mov	bx,cx			; save 2 * cl
	shl	cx,1			; 4 * cl
	shl	cx,1			; 8 * cl
	add	cx,bx			; 10 * cl
	pop	bx
	add	cl,al			; add new digit
	adc	ch,0
	jnc	atparm4			; nc = no carry out (65K or below)
	mov	cx,0ffffh		; set to max value
atparm4:mov	param[bx],cx		; current Parameter value
	clc
	ret
					; check non-numeric Parameters
atparm5:cmp	al,'?'			; within column 3?
	ja	atfinal			; a = no, check Final char
	mov	lparam,al		; store non-numeric Parameter
	clc
	ret

atparm6:cmp	nparam,0		; started a parameter yet?
	jne	atparm7			; ne = yes
	cmp	param,0			; got anything for param[0]?
	je	atinter			; e = no
atparm7:inc	nparam			; yes, say finished with another

atinter:mov	parstate,offset atinter	; next state (intermediate)
	cmp	al,';'			; argument separator?
	jne	atinte1			; ne = no
	cmp	ninter,maxinter		; too many intermediates?
	jb	atinte2			; b = no, continue
	stc				; carry = failed
	ret				; too many, ignore remainder
atinte1:test	al,not 2fh		; column two = 20h - 2fh?
	jnz	atfinal			; nz = not an Intermediate, try Final
	cmp	ninter,maxinter		; too many intermediates?
	jb	atinte1a		; b = no, continue
	stc				; carry = failed
	ret				; too many, ignore remainder
atinte1a:mov	bx,ninter		; current Intermediate slot number
	mov	inter[bx],al		; current Intermediate value
atinte2:inc	ninter			; say doing another Intermediate
	clc
	ret

atfinal:cmp	al,40h			; Final character, range is 40h to 7fh
	jb	atfina1			; b = out of range
	cmp	al,7fh
	ja	atfina1			; a = out of range
	mov	parstate,offset atpdone	; next state is "done"
	clc				; success, final char is in AL
	ret
atfina1:stc				; c = failed
	ret
atparse	endp

; Clear Parameter, Intermediate arrays in preparation for parsing
atpclr	proc	near
	push	ax
	push	cx
	push	di
	push	es
	xor	ax,ax			; get a null
	mov	parstate,offset atparm	; init parser state
	mov	lparam,al		; clear letter Parameter
	mov	nparam,ax		; clear Parameter count
	mov	cx,maxparam		; number of Parameter slots
	mov	di,offset param		; Parameter slots
	push	ds
	pop	es			; use data segment for es:di below
	cld				; set direction forward
	rep	stosw			; clear the slots
	mov	ninter,ax		; clear Intermediate count
	mov	cx,maxinter		; number of Intermediate slots
	mov	di,offset inter		; Intermediate slots
	rep	stosb			; clear the slots
	pop	es
	pop	di
	pop	cx
	pop	ax
	ret
atpclr	endp

; Dispatch table processor. Enter with BX pointing at table of {char count,
; address of action routines, characters}. Jump to matching routine or return.
; Enter with AL holding received Final char.
atdispat proc near
	mov	cl,[bx]			; get table length from first byte
	xor	ch,ch
	mov	di,bx			; main table
	add	di,3			; point di at first char in table
	push	es
	push	ds
	pop	es			; use data segment for es:di below
	cld				; set direction forward
	repne	scasb			; find matching character
	pop	es
	je	atdisp2			; e = found a match, get action addr
	ret				; ignore escape sequence
atdisp2:sub	di,bx			; distance scanned in table
	sub	di,4			; skip count byte, address word, inc
	shl	di,1			; convert to word index
	inc	bx			; point to address of action routines
	mov	bx,[bx]			; get address of action table
	jmp	word ptr [bx+di]	; dispatch to the routine
atdispat endp
code1	ends
	end
