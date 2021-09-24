	NAME	mssser
; File MSSSER.ASM
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

	public	bye, finish, remote, get, server, denyflg, srvtmo
	public	luser, lpass, queryseg, termserver, retrieve, reget

data	segment
	extrn	flags:byte, trans:byte, curdsk:byte, diskio:byte, auxfile:byte
	extrn	comand:byte, filtst:byte, maxtry:byte, dtrans:byte
	extrn	fmtdsp:byte, errlev:byte, fsta:word, kstatus:word
	extrn	rpacket:byte, encbuf:byte, decbuf:byte, sstate:byte
	extrn	rstate:byte, pktnum:byte, windlow:byte, takadr:word
	extrn	prmptr:word, chkparflg:byte, rdbuf:byte, mcctab:byte
	extrn	valtab:byte, echrcnt:word, dostemp:byte, k_rto:word
	extern	delfile_flag:byte, resend_flag:byte, vfile:byte
	extern	crcword:word, lastfsize:dword, sendkind:byte

scrser	equ	0209H		; place for server state display line
scrmsg	equ	0e16H		; place for Last message

remcmd	db	0		; Remote command to be executed
rempac	db	0		; Packet type: C (host) or G (generic)
remlen	db	0		; length of following text field

ermes6	db	'Filename too long for packet',0
erms37	db	' REGET requires SET FILE TYPE BINARY to be given$'
erms38	db	' REGET requires SET ATTRIBUTES ON to be given$'
cemsg	db	'User intervention',0
infms1	db	'Server mode: type C or Control-C to exit',cr,lf,'$'
infms2	db	cr,lf,'?More parameters are needed$'
infms3	db	'REMOTE command reply',0	; for transaction logging
infms4	db	'Help text',0			; filename for REM Help reply
infms5	db	'kermit.tmp',0			; filename for REM QUERY
remms1	db	' Unknown server command',0
remms2	db	' Invalid login information',0
remms3	db	' Kermit-MS Server ready',0
remms5	db	' File not found',0
remms6	db	' Command failed',0
remms7	db	' REMOTE LOGIN is required',0
remms8	db	' Command succeeded',0
remms9	db	' Command is Disabled',0
remms10	db	' Could not create work file',0
remms11	db	' Command too long for server',0
byemsg	db	' Goodbye!',0
whomsg	db	' Just this Server',0
spcmsg	db	' bytes available on drive '	; remote space responses
spcmsg1	db	' ',0
spcmsg2	db	' Drive '
spcmsg3	db	' : is not ready',0
user	db	' Username: ',0		; for Remote Login, asciiz
password db	' Password: ',0		; for Remote Login and Remote CD
account	db	' Account: ',0		; for Remote Login
slogin	db	0			; non-zero if successful local login
remlog	db	0			; rem login (1) vs rem logout (0)
luser	db	17 dup (0)		; local Username, case insenstitive
lpass	db	17 dup (0)		; local Password, case sensitive
delstr	db	'del ',0
dirstr	db	'dir ',0
queryseg dw	0			; seg of query response (0=none)
getkind	db	0			; 4 for recursive GET, else 0

crlf	db	cr,lf,'$'
emptymsg db	0			; empty asciiz msg
skertmp	dw	0			; REMOTE KERMIT work word
denyflg	dw	0+retflg		; bit field of denied commands
temp	dw	0
temp2	dw	0
cnt	dw	0
bufptr	dw	0
dsptmp	db	0			; temp to hold fmtdsp during serving
srvtmo	db	0			; idle NAK time, default is no NAKs
srvtime	db	0			; non-zero if timing Server residence
remfnm	db	' Remote Source File: ',0	; asciiz
lclfnm	db	' Local Destination File: ',0	; asciiz
tmpbuf	db	20 dup (0)
srvbuf	db	128 dup (0)		; place After tmpbuf, for status
termserver db	0			; 1 if Connect mode -> server
					; >1 if now servicing that invokation
savflg	flginfo	<>			; save area for flags.*
savflgl	equ	$-savflg		; length
savdtr	trinfo <>			; save area for dtrans.*
savdtrl equ	$-savdtr		; length
savtr	trinfo	<>			; save area for trans.*
savmaxtry db	0			; save area for maxtry

srvchr	db	'SRGIECKHJV'		; server cmd characters, use w/srvfun
srvfln	equ	$-srvchr		; length of table

srvfun	dw	srvsnd,srvrcv,srvgen,srvini,srverr,srvhos,srvker ; for srvchr
	dw	srvret,srvrget,srvrcvr

srvch2	db	'ACDEFHLMSTUVW'		; server commands, use with srvdsp
srvfl2	equ	$-srvch2

srvdsp	dw	srvpwd,srvcwd,srvdir,srvdel,srvfin,srvhlp,srvlog,srvmsg
	dw	srvset,srvtyp,srvspc,srvvcmd,srvwho


					; Answer from Server to REMOTE HELP
hlprem	db	cr,lf,'Kermit-MS Server commands:',lf
	db	cr,lf,'GET  filespec              '
	db	'REMOTE DIRECTORY filespec REMOTE PWD'
	db	cr,lf,'SEND filespec              '
	db	'REMOTE HELP  this text    REMOTE QUERY'
	db	cr,lf,'BYE, FINISH, REMOTE LOGOUT'
	db	'REMOTE HOST command       REMOTE SET command'
	db	cr,lf,'REMOTE ASSIGN/ASG variable '
	db	'REMOTE LOGIN name passwrd REMOTE SPACE drive-letter'
	db	cr,lf,'REMOTE CD/CWD directory    '
	db	'REMOTE MESSAGE 1-line msg REMOTE TYPE filespec'
	db	cr,lf,'REMOTE DELETE filespec     '
	db	'REMOTE PRINT filespec     REMOTE WHO'
	db	cr,lf
	db	0

remtab	db	19			; 19 entries
	mkeyw	'Assign',remasg
	mkeyw	'Asg',remasg
	mkeyw	'CD',remcwd
	mkeyw	'CWD',remcwd
	mkeyw	'Delete',remdel
	mkeyw	'Directory',remdir
	mkeyw	'Help',remhel
	mkeyw	'Host',remhos
	mkeyw	'Kermit',remker
	mkeyw	'Login',remlogin
	mkeyw	'Logout',remlogout
	mkeyw	'Message',remmsg
	mkeyw	'Print',remprn		; top of SEND procedure in msssen
	mkeyw	'PWD',rempwd
	mkeyw	'Query',remqry
	mkeyw	'Set',remset
	mkeyw	'Space',remdis
	mkeyw	'Type',remtyp
	mkeyw	'Who',remwho

qrytab	db	3				; REMOTE QUERY kind
	mkeyw	'User','G!'
	mkeyw	'Kermit','K!'
	mkeyw	'System','S!'

setval	dw	300,302,310			; answer REMOTE SET workers
	dw	400,401,402,403,404,405,406
setvlen	equ	($-setval)/2			; number of entries
setvec	dw	sftype,sfcoll,sfinc		; routines paralleling setval
	dw	sblkck,srpkt,srtmo,sretry,sstmo,sxfrch,swind

remstt1	db	9			; REMOTE SET top level table
	mkeyw	'Attributes',1
	mkeyw	'File',2
	mkeyw	'Incomplete',310
	mkeyw	'Block-check',400
	mkeyw	'Receive',3
	mkeyw	'Retry',403
	mkeyw	'Server',404
	mkeyw	'Transfer',405
	mkeyw	'Window-slots',406

remsat1	db	2			; REMOTE SET ATTRIBUTES
	mkeyw	'IN',0
	mkeyw	'OUT',100

remsat2	db	17			; REMOTE ATTRIBUTES {IN} item
					; REM ATT {OUT} item is 100 greater
	mkeyw	'All',132
	mkeyw	'Length',133
	mkeyw	'Type',134
	mkeyw	'Date',135
	mkeyw	'Creator',136
	mkeyw	'Account',137
	mkeyw	'Area',138
	mkeyw	'Block-size',139
	mkeyw	'Access',140
	mkeyw	'Encoding',141
	mkeyw	'Disposition',142
	mkeyw	'Protection',143
	mkeyw	'Gprotection',144
	mkeyw	'System-ID',145
	mkeyw	'Format',146
	mkeyw	'Sys-Info',147
	mkeyw	'Byte-count',148

remsfit	db	5			; REMOTE SET FILE
	mkeyw	'Type',300
	mkeyw	'Names',301
	mkeyw	'Collision',302
	mkeyw	'Replace',303
	mkeyw	'Incomplete',310

remsfty	db	2			; REMOTE SET FILE TYPE
	mkeyw	'Text',0
	mkeyw	'Binary',1

remsfna	db	2			; REMOTE SET FILE NAME
	mkeyw	'Converted',0
	mkeyw	'Literal',1

remsfco	db	7			; REMOTE SET FILE COLLISION
	mkeyw	'Append',3
	mkeyw	'Ask',5
	mkeyw	'Backup',2
	mkeyw	'Discard',4
	mkeyw	'Rename',0
	mkeyw	'Replace',1
	mkeyw	'Update',6

remsfre	db	2			; REMOTE SET FILE REPLACE
	mkeyw	'Preserve',0
	mkeyw	'Default',1

remsfin	db	2			; REMOTE SET FILE INCOMPLETE
	mkeyw	'Discard',0
	mkeyw	'Keep',1

remsrcv	db	2			; REMOTE SET RECEIVE
	mkeyw	'Packet-length',401
	mkeyw	'Timeout',402

remsxfr	db	2			; REMOTE SET TRANSFER
	mkeyw	'Character-set',405
	mkeyw	'Mode',410

sndswtab db	2			; Get /switches
	mkeyw	'/recursive',4
	mkeyw	'/nonrecursive',0

onoff	db	2			; ON, OFF table
	mkeyw	'off',0
	mkeyw	'on',1

modetab	db	2			; REMOTE SET TRANSFER MODE
	mkeyw	'Automatic',0
	mkeyw	'Manual',1

data	ends

data1	segment
inthlp	db	cr,lf,' Time-limit to remain in Server mode, seconds or'
	db	' specific hh:mm:ss (24h clock).'
	db	cr,lf,' SET TIMER ON to time.  Return for no time limit.$'
filmsg	db	' Remote filename, or press ENTER for prompts$'
filhlp	db	' File name to use locally$'
frem	db	' Name of file on remote system $'
genmsg	db	' Enter text to be sent to remote server $'
numhlp	db	' number$'
xfrhlp	db	' character set identifier string$'
rasghlp1 db	' name of variable on remote Kermit$'
rasghlp2 db	' value of variable on remote Kermit$'
remhlp	db	cr,lf,' Command    Action performed by the server Kermit'
	db	cr,lf,' -------    -------------------------------------'
	db	cr,lf,' Assign     variable-name   definition'
	db	cr,lf,' CD/CWD     change working directory'	; Answer to
	db	cr,lf,' Delete     a file'			; local
	db	cr,lf,' Directory  filespec'			; REM HELP
	db	cr,lf,' Help       show server''s remote help screen'
	db	cr,lf,' Host       command  (to remote operating system)'
	db	cr,lf,' Kermit     command  (to Kermit server)'
	db	cr,lf,' Login      name password  to a Kermit server'
	db	cr,lf,' Logout     exit remote Kermit (but keep remote host)'
	db	cr,lf,' Message    short one line message'
	db	cr,lf,' Print      local file  (on server''s printer)'
	db	cr,lf,' PWD        print working directory'
	db	cr,lf,' Query      ask User, Kermit, System variables'
	db	cr,lf,' Set        command  (modify server)'
	db	cr,lf,' Space      drive/directory'
	db	cr,lf,' Type       a file on this screen'
	db	cr,lf,' Who        user parameters$'
data1	ends

code1	segment
	extrn bufclr:far, pakptr:far, bufrel:far, makebuf:far, chkwind:far
	extrn firstfree:far, getbuf:far, pakdup:far, rpack:far, fcsrtype:far
	extrn fqryenv:far, fparse:far, strlen:far, strcpy:far,  prtscr:far
	extrn strcat:far, prtasz:far, dec2di:far, malloc:far,isfile:far
	extrn inptim:far, chktmo:far, cdsr:far, dskspace:far, sparmax:far
	extrn rpar:far
code1	ends

code	segment
	extrn comnd:near, init:near, serini:near, rrinit:near
	extrn read2:near, spar:near, intmsg:near
	extrn serhng:near, clrbuf:near, clearl:near
	extrn dodec: near, doenc:near, packlen:near, send10:near, errpack:near
	extrn pktsize:near, poscur:near, lnout:near, clrmod:near, ermsg:near
	extrn rprpos:near, crun:near, prompt:near, ihostr:near
	extrn pcwait:far, nvaltoa:near
	extrn nakpak:near, sndpak:near, response:near, dodecom:near
	extrn msgmsg:near, ackpak:near
	extrn takopen_macro:far, takclos:far, setcom:near
	extrn remprn:near

	assume	cs:code, ds:data, es:nothing

; Server command

SERVER	PROC	NEAR
	mov	ah,cmword		; get a word 
	mov	bx,offset srvbuf	; place to put text
	mov	dx,offset inthlp	; help message
	call	comnd			; get the pattern text
	jnc	serv1a			; nc = success
	ret				; failure
serv1a:	mov	ah,cmeol
	call	comnd
	jnc	serv1b			; nc = success
	ret
serv1b:	mov	srvtime,0		; assume not doing timed residence
	mov	si,offset srvbuf
	mov	al,[si]
	or	al,al			; any time given?
	jz	serv4			; z = no
	cmp	al,'0'			; numeric or colon?
	jb	serv2			; b = not proper time value
	cmp	al,':'			; this covers the desired range
	ja	serv2			; a = no proper time value
	call	inptim			; convert text to timeout tod
	jnc	serv3			; c = syntax errors in time
serv2:	stc				; failure
	ret

serv3:	mov	srvtime,1		; say doing timed residence
serv4:	or	flags.remflg,dserver	; signify we are a server now
	call	clrbuf			; clear serial port buffer of junk
	test	denyflg,pasflg		; Login required?
	jnz	serv4a			; nz = no
	or	denyflg,pasflg		; assume no login info required
	mov	al,luser		; check for user/password required
	or	al,lpass		; if both null then no checks
	jz	serv4a			; z = null, no name/pass required
	and	denyflg,not pasflg	; say need name/password
serv4a:	mov	dsptmp,0		; assume no formatted server display
	mov	al,dtrans.xchset	; reset Transmission char set
	mov	trans.xchset,al		;  to the current user default
	mov	al,dtrans.xtype		; ditto for File Type
	mov	trans.xtype,al
	mov	si,offset flags		; main flags structure
	mov	di,offset savflg	; save area
	mov	cx,savflgl		; length in bytes
	push	es
	push	ds
	pop	es
	cld
	rep	movsb			; save all of them
	mov	si,offset dtrans	; default transmission parameters
	mov	di,offset savdtr	; save area
	mov	cx,savdtrl		; length
	rep	movsb			; save all of them
	mov	si,offset trans		; active transmission paramters
	mov	di,offset savtr		; save area
	mov	cx,savdtrl		; same length
	rep	movsb
	mov	al,maxtry
	mov	savmaxtry,al
	pop	es
	mov	si,offset rpacket	; dummy packet
	mov	rpacket.datlen,0	; declare to be empty
	call	spar			; setup minimum operating conditions
	cmp	termserver,0		; invoked by terminal emulator?
	je	serv4b			; e = no
	mov	rpacket.seqnum,0
	call	nakpak			; NAK the packet, uses rpacket
	inc	termserver		; say reacting to request
serv4b:	test	flags.remflg,dquiet	; quiet display?
	jnz	serv9			; nz = yes
	mov	ah,prstr
	mov	dx,offset crlf
	int	dos
	test	flags.remflg,dserial 	; serial display?
	jnz	serv5			; nz = yes
	call	init			; init formatted display
	call	clrmod			; but no modeline yet
	mov	dl,fmtdsp
	mov	dsptmp,dl		; remember state of fmtdsp
	jmp	short serv9

serv5:	mov	ah,prstr
	mov	dx,offset infms1	; say now in server mode
	int	dos

					; TOP OF SERVER IDLE LOOP
serv9:	test	flags.remflg,dquiet+dserial ; quiet or serial display?
	jnz	serv10			; nz = yes, do not change screen
	mov	dx,scrmsg		; move cursor to Last message area
	add	dx,0100H	; look at line below (DOS does CR/LF first)
	call	poscur
	call	clearl			; and clear the line
	mov	dl,cr			; set cursor to left margin
	mov	ah,conout
	int	dos
serv10:	xor	ax,ax
	mov	flags.cxzflg,al		; clear ^X, ^Z, ^C seen flag
	mov	flags.xflg,al		; reset X packet flag
	mov	auxfile,al		; say no override filename
	mov	srvbuf,al		; work buffer, clear
	mov	al,dsptmp		; get our fmtdsp state
	mov	fmtdsp,al		; and restore it
	mov	trans.windo,1		; but only 1 window slot here
	mov	cx,drpsiz		; default receive pkt length (94)
	call	makebuf			; remake all buffers for new windowing
	call	packlen			; determine max packet length
	mov	dtrans.windo,31		; set max windowing abilities
	mov	trans.windo,31
	mov	trans.chklen,1		; checksum len = 1
	mov	pktnum,0		; pack number resets to 0
	mov	al,srvtmo		; use server mode timeout
	or	al,al			; is it zero?
	jz	serv10b			; z = yes, use regular timeout
	mov	trans.stime,al		; use this interval in the idle loop
serv10b:call	serini			; init serial line, just in case
	jnc	serv11			; nc = success
	jmp	serv20			; c = failure
serv11:	cmp	srvtime,0		; doing timed residence?
	je	serv12			; e = no
	call	chktmo			; check for time to exit Server mode
	jnc	serv12			; nc = ok
	jmp	serv20			; c = timeout, exit server mode

serv12:	mov	windlow,0		; reset windowing
	mov	pktnum,0		; packet number to be used
	call	getbuf			; get a buffer
	mov	chkparflg,1		; check for unexpected parity
	call	rpack			; receive a packet, si has buffer ptr
	mov	al,dtrans.stime		; get default timeout interval
	mov	trans.stime,al		; restore active timeout interval
	jc	serv13			; c = timeout, bad pkt, intervention
	mov	al,[si].seqnum		; sequence number received
	mov	rpacket.seqnum,al	; for our reply
	or	al,al			; must be sequence number of zero
	jnz	serv13			; nz = bad packet
	mov	ah,[si].pktype
	cmp	ah,'I'			; never "decode" S, I, and A packets
	je	serv17			; e = I packet
	cmp	ah,'S'
	je	serv17
	cmp	ah,'A'
	je	serv17
	call 	dodec			; decode packet to decbuf
	call	bufrel			; release the packet buffer
	cmp	termserver,0		; invoked from Connect mode?
	je	serv12a			; e = no
 	mov	termserver,-1		; signal exit after this command
serv12a:jmp	short serv17		; dispatch on packet type in ah

serv13:	cmp	flags.cxzflg,'C' 	; Control-C?
	je	serv20			; e = yes, exit server mode

serv14:	cmp	flags.cxzflg,'E'	; ^E protocol abort?
	jne	serv15			; ne = no
	call	bufclr			; clear all buffers
	mov	dx,offset cemsg	; user intervention message for error packet
	call	ermsg
	mov	bx,dx
	call	errpack			; send error message
	call	intmsg			; show interrupt msg for Control-C-E
	jmp	serv9

serv15:	cmp	[si].pktype,'T'		; packet type of time-out?
	jne	serv16			; ne = no
	cmp	termserver,0		; invoked from Connect mode?
	jne	serv20			; ne = yes, exit
	cmp	srvtime,0		; doing timed residence?
	je	serv15a			; e = no
	call	chktmo			; check for time to exit Server mode
	jc	serv20			; c = timeout, exit server mode
serv15a:cmp	srvtmo,0		; zero server pkt timeout?
	je	serv16			; e = yes, no NAKing
	mov	rpacket.seqnum,0
	call	nakpak			; NAK the packet, uses rpacket
serv16:	call	bufrel			; release the buffer
	jmp	serv9			; to top of idle loop

serv17:	cmp	[si].pktype,'N'		; received a NAK?
	je	serv18			; e = yes, ignore it
	push	es
	push	ds
	pop	es			; set es to data segment
	mov	di,offset srvchr	; server characters
	mov	cx,srvfln		; length of command set
	mov	al,ah			; packet type
	cld
	repne	scasb			; hunt for it
	pop	es
	je	serv19			; e = found that kind
	mov	dx,offset remms1	; say unknown server command
	call	ermsg
	mov	bx,dx
	call	errpack			; tell the other kermit
serv18:	jmp	serv9			; get another server command

serv19:	sub	di,offset srvchr+1	; find offset, +1 for pre-increment
	shl	di,1			; convert to word index
	call	srvfun[di]		; call the appropriate handler
	jc	serv20			; c = someone wanted to exit
	cmp	termserver,-1		; exit after Connect mode command?
	je	serv20			; e = yes
	jmp	serv9			; get another server command

serv20:	mov	di,offset flags		; main flags structure
	mov	si,offset savflg	; save area
	mov	cx,savflgl		; length in bytes
	push	es
	push	ds
	pop	es
	mov	al,flags.extflg		; leave server mode and Kermit flag
	mov	ah,flags.cxzflg		; interruption flag
	cld
	rep	movsb			; restore all of them
	mov	di,offset dtrans	; default transmission parameters
	mov	si,offset savdtr	; save area
	mov	cx,savdtrl		; length
	rep	movsb			; restore all of them
	mov	di,offset trans		; active transmission paramters
	mov	si,offset savtr		; save area
	mov	cx,savdtrl		; same length
	rep	movsb
	mov	flags.extflg,al		; set flag as current
	mov	al,savmaxtry
	mov	maxtry,al
	pop	es
	mov	al,1			; underline cursor
	call	fcsrtype		; set IBM-PC cursor to underline
	call	rprpos			; put prompt here
	and	flags.remflg,not dserver ; say not a server anymore
	mov	termserver,0		; clear invokation from Terminal
	clc
	ret
SERVER	ENDP

; commands executable while acting as a server

; Validate LOGIN status. Return carry set if login is ok, else
; send Error Packet saying Login is required (but has not been done) and
; return carry clear. Carry bit is this way because returning to the server
; idle loop with carry set exits the server mode.
logchk	proc	near
	test	denyflg,pasflg		; login required?
	jnz	logchk1			; nz = no (disabled)
	cmp	slogin,0		; logged in yet?
	jne	logchk1			; ne = yes
	mov	dx,offset remms7	; reply REMOTE LOGIN is required
	call	ermsg
	mov	bx,dx			; errpack works from bx
	mov	trans.chklen,1		; reply with 1 char checksum
	call	errpack
	clc				; say cannot proceed with command
	ret
logchk1:stc				; say can proceed with command
	ret
logchk	endp

; srvsnd - receives a file that a remote kermit is sending
srvsnd	proc	near
	call	logchk			; check login status
	jc	srvsnd1			; c = ok
	ret				; else have sent error packet
srvsnd1:call	init			; setup display form
	xor	ax,ax
	test	denyflg,sndflg		; command disabled?
	jz	srvsnd2			; z = no
	mov	al,'.'			; dot+nul forces use of current dir
srvsnd2:mov	word ptr auxfile,ax	; override name
	mov	rstate,'R'		; receive initiate state
	jmp	read2			; packet pointer is SI, still valid
srvsnd	endp

; srvrcv - send a file to a distant kermit and delete source (Retrieve)

srvret	proc	near
	test	denyflg,retflg		; Retrieve disallowed?
	jz	srvret1			; z = no, perform it
	mov	dx,offset remms9	; Command is Disabled
	call	ermsg
	mov	bx,dx			; errpack works from bx
	mov	trans.chklen,1		; reply with 1 char checksum
	call	errpack
	clc
	ret
srvret1:mov	delfile_flag,1		; delete files after sending
	jmp	srvrcv			; send file to remote client
srvret	endp

; srvrcv - send a file to a distant kermit

srvrcv	proc	near
	mov	temp,0			; signal send a file
	call	logchk			; check login status
	jc	srrcv1			; c = ok
	mov	delfile_flag,0		; failed, clear file deletion flag
	ret				; else have sent error packet
srrcv1:	mov	si,offset decbuf	; received filename, asciiz from dodec
	test	denyflg,getsflg		; command enabled?
	jz	srrcv2			; z = yes
	mov	dx,si			; source string, from other side
	mov	di,offset srvbuf	; local path
	mov	si,offset tmpbuf	; local filename
	call	fparse			; split string
srrcv2:	mov	di,offset diskio.string	; destination
	call	strcpy			; copy filename to diskio.string
	mov	auxfile,0		; no alias name
	mov	sstate,'S'		; set sending state
	mov	ax,temp
	mov	resend_flag,al		; send = 0, reget != 0
	mov	al,trans.xtype
	mov	trans.xtype,0		; text mode transfer
	push	ax
	push	crcword			; preserve CRC-16 word
	push	word ptr lastfsize	; and last sent file size
	push	word ptr lastfsize+2
	call	send10			; this should send it
	pop	word ptr lastfsize+2
	pop	word ptr lastfsize
	pop	crcword			; restore CRC-16 word
	pop	ax
	mov	trans.xtype,al
	ret
srvrcv	endp

; Respond to remote request of GET /RECURSIVE
srvrcvr	proc	near
	mov	sendkind,4		; say recursive send requested
	jmp	srvrcv			; do rest as regular GET
srvrcvr endp

srverr	proc	near			; incoming Error packet
	clc				; absorb and ignore
	ret
srverr	endp

; srvrget - send file to remote kermit in response to its reget command
srvrget proc	near
	mov	temp,1			; signal reget a file
	call	logchk			; check login status
	jc	srrcv1			; c = ok
	mov	delfile_flag,0		; failed, clear file deletion flag
	ret				; else have sent error packet
srvrget endp

; srvgen - G generic server command dispatcher
;
srvgen	proc	near
	call	bufrel			; release buffer
	mov	al,decbuf		; get first data character from pkt
	cmp	al,'I'			; LOGIN?
	jne	srvge1			; ne = no
	jmp	srvlogin		; yes
srvge1:	call	logchk			; check login status
	jc	srvge2			; c = ok
	ret				; else have sent error packet
srvge2:	push	es
	push	ds
	pop	es			; set es to data segment
	mov	di,offset srvch2	; command character list
	mov	cx,srvfl2		; length of command set
	cld
	repne	scasb			; hunt for it
	pop	es
	jne	srvgex			; ne = not found, complain
	sub	di,offset srvch2+1	; find offset, +1 for pre-increment
	shl	di,1			; convert to word index
	jmp	srvdsp[di]		; do the appropriate handler

srvgex:	mov	dx,offset remms1	; reply Unknown server command
	call	ermsg
	mov	bx,dx
	mov	trans.chklen,1		; reply with 1 char checksum
	call	errpack
	clc
	ret
srvgen	endp

; srvlog - respond to host's BYE and LOGOUT
srvlog	proc	near
	test	denyflg,byeflg		; BYE/LOGOUT enabled?
	jz	srvlog1			; z = yes
	call	srvfin			; do FIN part
	clc				; c clear = do not exit server
	ret
srvlog1:call	srvfin			; do FIN part
	mov	flags.extflg,1		; leave server mode and Kermit
	call	serhng			; hangup the phone and return
	mov	di,offset flags		; main flags structure
	mov	si,offset savflg	; save area
	mov	cx,savflgl		; length in bytes
	push	es
	push	ds
	pop	es
	mov	al,flags.extflg		; leave server mode and Kermit flag
	cld
	rep	movsb			; restore all of them
	mov	di,offset dtrans	; default transmission parameters
	mov	si,offset savdtr	; save area
	mov	cx,savdtrl		; length
	rep	movsb			; restore all of them
	mov	di,offset trans		; active transmission paramters
	mov	si,offset savtr		; save area
	mov	cx,savdtrl		; same length
	rep	movsb
	mov	flags.extflg,al		; make flag current
	mov	al,savmaxtry
	mov	maxtry,al
	pop	es
	stc				; carry set = exit server mode
	ret
srvlog	endp

; srvfin - respond to remote host's Fin command
srvfin	proc	near
	mov	slogin,0		; say not logged in anymore
	mov	si,offset byemsg	; add brief msg of goodbye
	mov	di,offset encbuf	; packet's data field
	call	strcpy			; copy msg to pkt
	mov	dx,si			; strlen works on dx
	call	strlen
	push	si
	mov	si,offset rpacket	; get a reply buffer
	call	doenc			; encode the reply in encbuf
	pop	si
	mov	trans.chklen,1		; reply with 1 char checksum
	call	ackpak
	mov	ax,100			; wait 0.1 sec for client to settle
	call	pcwait
	mov	si,offset rpacket	; dummy packet
	mov	rpacket.datlen,0	; declare to be empty
	call	spar			; setup minimum operating conditions
	test	denyflg,finflg		; command enabled?
	jz	srfin2			; z = yes
	clc				; stay in server mode
	ret
srfin2:	stc				; stc exits server mode
	ret
srvfin	endp

; srvcwd - handle other side's Remote CWD dirspec
srvcwd	proc	near
	mov	trans.chklen,1		; reply with 1 char checksum
	test	denyflg,cwdflg		; is command enabled?
	jz	srcwd1			; z = yes
	mov	dx,offset remms9	; say command is disabled
	call	ermsg			;  to us and
	mov	bx,dx
	call	errpack			;  to the other Kermit
	clc
	ret
srcwd1:	mov	si,offset decbuf+1	; point to byte count
	xor	bh,bh
	mov	bl,[si]
	sub	bl,' '			; remove ascii bias from byte count
	inc	si
	mov	word ptr[si+bx],0	; make ASCIIZ w/one extra null
	call	cdsr			; CD common sub-routine
	mov	si,dx			; returns msg in dx
	mov	di,offset encbuf	; put in encode buffer
	call	strcpy
	mov	dx,di
	call	strlen			; get its length to cx
	mov	si,offset rpacket	; use this packet for the reply
	call	doenc			; encode reply
	call	ackpak			; send ACK with data
	clc
	ret
srvcwd	endp

; srvpwd - handle other side's Remote PWD
srvpwd	proc	near
	mov	trans.chklen,1		; reply with 1 char checksum
	mov	si,offset decbuf	; result buffer
	mov	word ptr[si],0		; make ASCIIZ w/one extra null
	call	cdsr			; CD common sub-routine
	mov	si,dx			; returns msg in dx
	mov	di,offset encbuf	; put in encode buffer
	call	strcpy
	mov	dx,di
	call	strlen			; get its length to cx
	mov	si,offset rpacket	; use this packet for the reply
	call	doenc			; encode reply
	call	ackpak			; send ACK with data
	clc
	ret
srvpwd	endp

; srvtyp - handle other side's Remote Type filename request
; expects "data" to hold  Tcfilename   where c = # bytes in filename
srvtyp	proc	near
	cmp	decbuf+1,0		; any data in packet
	je	srtyp2			; e = no
	mov	cl,decbuf+1		; get the filename byte count
	sub	cl,' '			; ascii to numeric
	jle	srtyp2			; le = no filename or error in length
	xor	ch,ch			; set up counter
	mov	si,offset decbuf+2	; received filename, asciiz from rpack
	mov	di,si
	add	di,cx
	mov	byte ptr [di],0		; make string asciiz
	test	denyflg,typflg		; paths permitted?
	jz	srtyp1			; z = yes, else use just filename part
	mov	di,offset srvbuf	; local path
	mov	si,offset tmpbuf	; local filename
	mov	dx,offset decbuf+2	; local string
	call	fparse			; split string
srtyp1:	mov	di,offset diskio.string	; copy local filename to destination
	mov	ax,di			; pointer to filename, for isfile
	call	strcpy			; do the copy
	call	isfile			; does it exist?
	jnc	srtyp3			; nc = yes
srtyp2:	mov	si,offset remms5	; "File not found"
	mov	di,offset encbuf	; destination for message
	call	strcpy			; move the message
	mov	dx,di
	call	strlen			; length to cx
	mov	si,offset rpacket	; use this packet for reply
	call	doenc			; encode
	mov	trans.chklen,1		; reply with 1 char checksum
	call	ackpak			; send ACK with message
	clc
	ret

srtyp3:	mov	flags.xflg,1		; say use X packet rather than F pkt
	mov	auxfile,0		; no alias name
	mov	sstate,'S'		; remember state
	mov	resend_flag,al		; send = 0, reget != 0
	mov	al,trans.xtype
	mov	trans.xtype,0		; text mode transfer
	push	ax
	push	crcword			; preserve CRC-16 word
	push	word ptr lastfsize	; and last sent file size
	push	word ptr lastfsize+2
	call	send10			; this should send it
	pop	word ptr lastfsize+2
	pop	word ptr lastfsize
	pop	crcword			; restore CRC-16 word
	pop	ax
	mov	trans.xtype,al
	ret
srvtyp	endp

; srvdir - handle other side's Remote Dir filespec(optional) request
srvdir	proc	near
	mov	di,offset decbuf+2  	; received filespec, asciiz from rpack
	xor	cx,cx			; assume no data in packet
	mov	cl,decbuf+1		; get the filename byte count
	cmp	cl,' '			; byte count present and > 0?
	jg	srdir1			; g = yes
	mov	word ptr [di],0		; clear data field
	jmp	short srdir2		; 0 = no info in pkt
srdir1:	sub	cl,' '			; ascii to numeric
	add	di,cx			; step to end of filename, terminate
	mov	word ptr [di],0		; ensure string is asciiz
	mov	di,offset srvbuf	; local path
	mov	si,offset tmpbuf	; local filename
	mov	dx,offset decbuf+2	; local string
	call	fparse			; split string
	test	denyflg,dirflg		; paths permitted?
	jz	srdir2			; z = yes, else use just filename part
	mov	si,offset tmpbuf	; copy local filename to
	mov	di,offset decbuf+2	; final filename
	call	strcpy			; copy just filename to buffer
srdir2:	mov	cl,curdsk		; current drive number
	add	cl,'A'-1		; to letter
	cmp	decbuf+3,':'		; drive specified?
	jne	srdir3			; ne = no
	cmp	decbuf+2,0		; drive letter specified?
	je	srdir3			; e = no
	mov	cl,decbuf+2		; get drive letter
	and	cl,5fh			; convert to upper case
srdir3:	call	dskspace		; check if drive ready (drive => CL)
	jnc	srdir5			; nc = success (drive is ready)
	mov	spcmsg3,cl		; insert drive letter
	mov	si,offset spcmsg2	; say drive not ready
	mov	di,offset encbuf	; destination for message
	call	strcpy			; move the message
	mov	dx,di
	call	strlen			; length to cx
	mov	si,offset rpacket	; use this packet for reply
	call	doenc			; encode
	mov	trans.chklen,1		; reply with 1 char checksum
	call	ackpak			; send ACK with message
	clc
	ret

srdir5:	mov	di,offset srvbuf	; work area
	mov	si,offset dirstr	; prepend "dir "
	call	strcpy
	mov	si,offset decbuf+2	; directory spec, asciiz
	mov	di,offset srvbuf
	call	strcat

; srdir6 does common processing for both REM DIR & REM HOST
SRDIR6:	mov	si,di			; srvbuf
	mov	di,offset auxfile	; send-as name is command line
	call	strcpy
	mov	si,offset dostemp    ; add redirection tag " > $kermit$.tmp"
	mov	di,offset srvbuf
	call	strcat
	mov	si,offset srvbuf	; command pointer for crun
	call	crun
; fall thru!	jmp	srvtail			; send contents of temp file
srvdir	endp

; Send contents of dostemp+3 temporary file, or error packet if it does not
; exist.
srvtail	proc	near
	mov	si,offset dostemp+3	; get name of temp file
	mov	di,offset diskio.string	; destination
	call	strcpy			; copy it there
	mov	ax,di			; filename pointer for isfile
	call	isfile			; did we make the temp file?
	jnc	srvtai1			; nc = yes
	mov	dx,offset remms10	; "Could not create work file"
	mov	trans.chklen,1		; reply with 1 char checksum
	call	ermsg
	mov	bx,dx
	call	errpack			; send the error message
	clc
	ret
srvtai1:mov	flags.xflg,1		; say use X rather than F packet
	mov	sstate,'S'		; remember state
	push	crcword			; preserve CRC-16 word
	push	word ptr lastfsize	; and last sent file size
	push	word ptr lastfsize+2
	call	SEND10			; this should send it
	pop	word ptr lastfsize+2
	pop	word ptr lastfsize
	pop	crcword			; restore CRC-16 word
	mov	flags.xflg,0		; clear flag
	mov	dx,offset dostemp+3	; name of temp file
	mov	ah,del2			; delete the file
	int	dos
	clc
	ret				; return in any case
srvtail	endp

; srvdel - handle other side's request of Remote Del filespec
srvdel	proc	near
	test	denyflg,delflg		; command enabled?
	jz	srvdel4			; z = yes
	mov	dx,offset remms9	; else give a message
	mov	trans.chklen,1		; reply with 1 char checksum
	call	ermsg
	mov	bx,dx
	call	errpack			; back to local kermit
	clc
	ret

srvdel4:cmp	decbuf+1,0		; any data?
	je	srdel1			; e = no
	xor	bh,bh
	mov	bl,decbuf+1		; get the filename byte count
	sub	bl,' '			; ascii to numeric
	jle	srdel3			; le = nothing there
	mov	decbuf [bx+2],0		; plant terminator
	mov	ax,offset decbuf+2	; point to filespec
	call 	isfile			; is/are there any to delete?
	jc	srdel1			; c = there is none
	test	byte ptr filtst.dta+21,1EH ; attr bits: is file protected?
	jz	srdel2			; z = not protected
srdel1:	mov	si,offset remms5	; "File not found"
	mov	di,offset encbuf	; destination for message
	call	strcpy			; move the message
	mov	dx,di
	call	strlen			; length to cx
	mov	si,offset rpacket	; use this packet for reply
	call	doenc			; encode
	mov	trans.chklen,1		; reply with 1 char checksum
	call	ackpak			; send ACK with message
	clc
	ret

srdel2:	mov	di,offset encbuf	; work area
	mov	si,offset delstr	; prepend "del "
	call	strcpy
	mov	si,offset decbuf+2	; append incoming filespec
	call	strcat			; append to "del "
	mov	si,di			; set pointer for crun
	call	crun
srdel3:	mov	dx,offset encbuf	; where command lies
	call	strlen			; length to cx
	push	si
	mov	si,offset rpacket	; packet to use for reply
	call	doenc			; encode reply
	pop	si
	mov	trans.chklen,1		; reply with 1 char checksum
	call	ackpak
	clc
	ret
srvdel	endp

; srvlogin - handle other side's request of REMOTE LOGIN, USERNAME, PASSWORD

srvlogin proc	near
	mov	slogin,0		; say not logged in yet
	cmp	luser,0			; local username specified?
	je	srvlog9			; e = no, do no checking
	mov	cl,decbuf+1		; ascii byte count of username
	sub	cl,' '			; to binary
	jle	srvlog8a		; le = nothing there, do logout
	xor	ch,ch
	mov	si,offset decbuf+2	; source, username field
	mov	di,offset luser		; local username template
	push	cx
	mov	ax,cx			; external username length
	mov	dx,di
	call	strlen			; get length of local username
	cmp	ax,cx			; same lengths?
	pop	cx
	jne	srvlog8			; ne = not same length
	cld
srvlog2:lodsb				; remote char
	mov	ah,[di]			; local char
	inc	di
	or	ax,2020h		; lower case both
	cmp	ah,al			; same?
	jne	srvlog8			; ne = no, fail
	loop	srvlog2			; continue match
	cmp	lpass,0			; local password specified?
	je	srclog6			; e = no, don't check incoming p/w
	mov	cl,decbuf+1		; username length
	sub	cl,' '
	xor	ch,ch			; clear high byte
	mov	si,offset decbuf+2	; skip over username field
	add	si,cx			; password length byte
	mov	cl,[si]			; ascii count of password bytes
	sub	cl,' '			; to binary
	jc	srvlog8			; carry means no field
	inc	si			; start of password text
	mov	di,offset lpass		; local password text, case sensitive
	push	cx
	mov	ax,cx			; external password length
	mov	dx,di
	call	strlen			; length of local password
	cmp	ax,cx			; same?
	pop	cx
	je	srvlog5			; e = yes
	mov	byte ptr [si],20h	; corrupt external password
	jmp	short srvlog8		; fail
srvlog5:lodsb				; remote char
	mov	ah,[di]			; local char
	inc	di
	cmp	ah,al			; same?
	jne	srvlog8			; ne = no, fail
	loop	srvlog5			; do all chars
srclog6:mov	slogin,1		; declare user logged-in
	jmp	short srvlog9		; ACK with brief message

srvlog8:mov	si,offset remms2	; say invalid login information
	jmp	short srvlog10

srvlog8a:mov	si,offset byemsg	; say logging out (empty username)
	jmp	short srvlog10

srvlog9:mov	si,offset remms3	; welcome aboard message
	mov	slogin,1		; say logged in successfully
srvlog10:mov	di,offset encbuf	; copy to here
	call	strcpy
	mov	dx,di			; where command lies
	call	strlen			; length to cx
	push	si
	mov	si,offset rpacket	; packet to use for reply
	call	doenc			; encode reply
	pop	si
	mov	trans.chklen,1		; reply with 1 char checksum
	call	ackpak
	clc
	ret
srvlogin endp

; srvvcmd dispatch remote V generic commands from client
srvvcmd	proc	near
	cmp	word ptr decbuf+1,'Q!'	; Query?
	jne	srvvcmd1		; ne = no
	test	denyflg,qryflg		; command enabled?
	jz	srvqry			; z = yes
	mov	dx,offset remms9	; else give a message
	jmp	srvvcmd5

srvvcmd1:cmp	word ptr decbuf+1,'S!'	; Set/define?
	jne	srvvcmd2		; ne = no
	test	denyflg,defflg		; command enabled?
	jz	srvvcmd2		; z = yes
	mov	bx,offset remms9	; else give a message
	jmp	short srvvcmd5
srvvcmd2:jmp	srvdef			; do the set/define

srvvcmd3:mov	bx,offset remms1	; "Unknown server command"
srvvcmd5:mov	trans.chklen,1		; reply with 1 char checksum
	call	errpack			; send error message in ptr bx
	clc
	ret
srvvcmd	endp

; srvqry - query from remote client
; expect packet (decbuf) to hold  V<len 1>Q<len 1>{G,K,S}<len><name>
srvqry	proc	near
	push	es
	mov	si,seg encbuf
	mov	es,si
	cld
	mov	si,offset decbuf+3	; source buffer, skip V!Q
	lodsb
	cmp	al,'!'			; check syntax, one letter
	jne	srvqry10		; ne = fail
	lodsb				; letter
	mov	dl,al			; save letter around this work
	lodsb				; length
	sub	al,' '			; remove ASCII bias
	xor	ah,ah
	mov	cx,ax			; get length for copy
	cmp	dl,'G'			; User?
	jne	srvqry1			; ne = no
	call	srvqmac			; call worker for sub variables
	jmp	short srvqry3		; package the ACK

srvqry1:cmp	dl,'S'			; System?
	jne	srvqry2			; ne = no
	call	fqryenv			; query environment, in msscmd
	jmp	short srvqry3

srvqry2:cmp	dl,'K'			; Kermit?
	jne	srvqry10		; ne = no, fail
	call	srvqvar

srvqry3:mov	si,offset rpacket	; use this packet for reply
	mov	temp,cx			; preserve original length
	call	doenc			; encode, cx has length
	cmp	echrcnt,0		; did all fit within one packet?
	jne	srvqry4			; no, send as file
	mov	trans.chklen,1		; reply with 1 char checksum
	call	ackpak			; send ACK with message
	pop	es
	clc
	ret
srvqry4:mov	dx,offset dostemp+3	; use filename of $kermit$.tmp
	mov	ah,creat2		; create the file
	xor	cx,cx			; attributes r/w
	int	dos
	jc	srvqry5			; c = could not open
	mov	dx,offset encbuf	; source
	mov	cx,temp			; length
	mov	bx,ax			; handle
	mov	ah,write2		; write to file
	int	dos			; write the info
	mov	ah,close2	; close the file so we can reread it below
	int	dos
srvqry5:mov	si,offset infms5	; pseudo filename
	mov	di,offset auxfile	; send-as name
	call	strcpy			; copy it there
	jmp	srvtail			; send temporary file to remote screen

srvqry10:mov	bx,offset remms6	; "Command failed"
	mov	trans.chklen,1		; reply with 1 char checksum
	call	errpack			; send error message in ptr bx
	pop	es
	clc
	ret
srvqry	endp

; Worker for srvqry. Enter with macro name in decbuf+6
; and length in byte decbuf+5 (has ' ' bias).
; Return carry clear and macro definition in encbuf, length in CX,
; or fail with carry set.

srvqmac	proc	near
	mov	si,offset mcctab	; table of macro names
	cld
	lodsb
	mov	cl,al			; number of macro entries
	xor	ch,ch
	jcxz	srvmac9			; z = none
srvmac4:push	cx			; save loop counter
	lodsw				; length of macro name
	mov	cl,decbuf+5		; length of desired name
	sub	cl,' '			; remove ASCII bias
	xor	ch,ch
	cmp	ax,cx			; mac name shorter that user spec?
	jb	srvmac6			; b = yes, no match
	push	ax
	push	si			; save these around match test
	mov	di,offset decbuf+6	; user's string
srvmac5:mov	ah,[di]
	inc	di
	lodsb				; al = mac name char, ah = user char
	and	ax,not 2020h		; clear bits (uppercase chars)
	cmp	ah,al			; same?
	loope	srvmac5			; while equal, do more
	pop	si			; restore regs
	pop	ax
	je	srvmac7			; e = match
srvmac6:add	si,ax			; point to next name, add name length
	add	si,2			;  and string pointer
	pop	cx			; recover loop counter
	loop	srvmac4			; one less macro to examine
	jmp	short srvmac9		; send empty ACK

srvmac7:pop	cx			; interior loop counter
	cmp	byte ptr [si],0		; name starts with null char?
	jne	srvmac8			; ne = no
	xor	cx,cx			; length of result to zero
	jmp	srvmac9			; yes, TAKE file, ignore
srvmac8:mov	ax,seg encbuf		; buffer where encoder will operate
	mov	es,ax
	mov	di,offset encbuf
	mov	ax,[si-2]		; length of macro name
	add	si,ax			; skip over name
	push	DS
	mov	ds,[si]			; segment of string structure
	xor	si,si			; ds:si = address of count + string
	mov	cx,ds:[si]		; length of string
	mov	bx,cx			; save length over copy
	add	si,2			; si = offset of string text proper
	rep	movsb			; copy to encbuf
	pop	DS
	mov	cx,bx			; get length again
	clc
	ret
srvmac9:xor	cx,cx			; fail
	stc
	ret
srvqmac	endp


; Worker for srvqry. Enter with variable (\v(..)) name in decbuf+6
; and length in byte decbuf+5 (has ' ' bias).
; Return carry clear and macro definition in encbuf, length in CX,
; or fail with carry set.

srvqvar	proc	near
	mov	cl,decbuf+5		; length of user spec
	sub	cl,' '
	xor	ch,ch
	jcxz	srvqvar4		; z = empty user spec, fail
	mov	si,offset valtab	; table of variable names
	mov	di,offset encbuf	; output buffer
	cld
	lodsb
	mov	cl,al			; number of variable entries
	xor	ch,ch
	jcxz	srvqvar4		; z = none
srvqvar1:push	cx			; save loop counter
	mov	cl,decbuf+5		; length of user spec
	sub	cl,' '
	xor	ch,ch
	lodsw				; length of var name, incl ')'
	push	ax			; save length
	dec	ax			; omit ')'
	cmp	ax,cx			; var name shorter that user spec?
	pop	ax			; recover full length
	jb	srvqvar2a		; b = yes, no match
	push	ax
	push	si			; save these around match test
	mov	di,offset decbuf+6	; user's string
srvqvar2:mov	ah,[di]
	inc	di
	lodsb				; al = var name char, ah = user char
	and	ax,not 2020h		; clear bits (uppercase chars)
	cmp	ah,al			; same?
	loope	srvqvar2		; while equal, do more
	pop	si			; restore regs
	pop	ax
	je	srvqvar3		; e = found a match
srvqvar2a:add	si,ax			; point to next name, add name length
	add	si,2			; and string pointer
	pop	cx			; recover loop counter
	loop	srvqvar1		; one less macro to examine
	jmp	short srvqvar4		; no match, fail

srvqvar3:pop	cx			; interior loop counter
	mov	ax,[si-2]		; length of variable name
	add	si,ax			; skip over name
	mov	bx,[si]			; get result code to bx
	xor	dx,dx			; trim off trailing spaces
	push	es
	mov	di,seg encbuf
	mov	es,di
	mov	di,offset encbuf
	call	nvaltoa			; fill es:di with string
	pop	es
	jc	srvqvar4		; c = failure
	mov	cx,di			; di is string length
	clc
	ret

srvqvar4:xor	cx,cx			; say no match
	stc				; fail
	ret
srvqvar	endp

; srvdef - define local variable from remote client
; expect packet (decbuf) to hold  V<len 1>S<len><name><len><value>
; final <len> may be a space to say measure long length from pkt contents
srvdef	proc	near
	push	es
	mov	di,seg rdbuf
	mov	es,di
	cld
	mov	di,offset rdbuf+2	; work buffer
	mov	si,offset decbuf+3	; source buffer, skip over V!S
	lodsb				; length of name
	sub	al,' '			; remove ASCII bias
	xor	ah,ah
	mov	cx,ax			; get length for copy
	rep	movsb			; copy name
	mov	al,' '			; space separator on output
	stosb
	lodsb				; length of value
	sub	al,' '			; remove ASCII bias
	xor	ah,ah
	mov	cx,ax			; get length for copy
	or	ax,ax			; given as null (' ')?
	jnz	srvdef1			; nz = no, have length
	mov	dx,si			; compute length from packet
	call	strlen			; yields cx
srvdef1:rep	movsb			; copy value string
	mov	byte ptr es:[di],0	; null terminator
	sub	di,offset rdbuf+2	; length of destination material+2
	mov	cx,di			; length for dodecom, uses rdbuf
	call	dodecom			; define the macro
	jc	srvdef5			; c = failed
	xor	cx,cx			; length of ACK data, zero
	mov	si,offset rpacket	; use this packet for reply
	call	doenc			; encode
	mov	trans.chklen,1		; reply with 1 char checksum
	call	ackpak			; send ACK with message
	pop	es
	clc
	ret

srvdef5:mov	bx,offset remms6	; "Command failed"
	mov	trans.chklen,1		; reply with 1 char checksum
	call	errpack			; send error message in ptr bx
	pop	es
	clc
	ret
srvdef	endp

; srvspc - handle other side's request of Remote Space
; Enable/Disable portion has become obsolete, command is always enabled
srvspc	proc	near
;	test	denyflg,spcflg		; is command enabled?
;	jz	srspc1			; z = yes
;	mov	dx,offset remms9	; else give a message
;	mov	trans.chklen,1		; reply with 1 char checksum
;	call	ermsg
;	mov	bx,dx
;	call	errpack			; back to local kermit
;	clc
;	ret
srspc1:	xor	cl,cl			; use current drive
	cmp	decbuf+1,0		; any data?
	je	srspc2			; e = no
	mov	cl,decbuf+2		; get the drive letter
srspc2:	call	dskspace		; calculate space, get letter into CL
	jnc	srspc3			; nc = success
	mov	spcmsg3,cl		; insert drive letter
	mov	di,offset encbuf	; encoder buffer
	mov	si,offset spcmsg2	; give Drive not ready message
	call	strcpy
	jmp	short srspc4		; send it
srspc3:	mov	spcmsg1,cl		; insert drive letter
	mov	di,offset encbuf	; destination
	mov	word ptr[di],'  '	; space space
	add	di,2			; start number here
	call	lnout			; convert number to asciiz in [di]
	mov	si,offset spcmsg	; trailer of message
	call	strcat			; tack onto end of number part
srspc4:	mov	trans.chklen,1		; reply with 1 char checksum
	mov	dx,offset encbuf
	call	strlen			; get data size into cx for doenc
	mov	si,offset rpacket
	call	doenc			; encode
	call	pktsize			; report packet size
	call	ackpak
	clc
	ret
srvspc	endp

; srvwho - respond to remote host's WHO command.
srvwho	proc	near
	mov	si,offset whomsg	; add brief msg of just us chickens
	mov	di,offset encbuf	; encoder source field
	call	strcpy			; copy msg to pkt
	mov	dx,si			; strlen works on dx
	call	strlen
	mov	si,offset rpacket
	call	doenc			; encode reply, size is in cx
	mov	trans.chklen,1		; reply with 1 char checksum
	call	ackpak
	clc
	ret
srvwho	endp

; srvmsg - respond to remote host's Message (Send) command
;  show message on our screen.
srvmsg	proc	near
	cmp	decbuf,0		; any data in the packet?
	jbe	srvmsg2			; e = no, just ack the message 
	cmp	decbuf,'M'		; Message packet?
	jne	srvmsg2			; ne = no, ack and forget
	test	flags.remflg,dquiet+dserial ; quiet or serial display?
	jnz	srvmsg1			; nz = yes
	mov	dx,scrmsg		; move cursor to Last message area
	call	poscur
	call	clearl			; and clear the line
srvmsg1:xor	ch,ch
	mov	cl,decbuf+1		; data length
	sub	cl,' '			; remove ascii bias
	jle	srvmsg2			; le = nothing
	mov	di,offset decbuf+2	; main part of message
	call	prtscr			; display cx chars on the screen
srvmsg2:mov	rpacket.datlen,0	; length
	mov	trans.chklen,1		; reply with 1 char checksum
	call	ackpak
	clc
	ret
srvmsg	endp


; srvhos - handle other side's request of REM Host command-line. [jrd]
; We execute the command with STDOUT redirected to $kermit$.tmp and then
; read and transmit that file to the other end. No such file results in
; returning just an error msg ACK packet
srvhos	proc	near
	call	logchk			; check login status
	jc	srvhos1			; c = ok
	ret				; else have sent error packet
srvhos1:test	denyflg,hostflg		; command enabled?
	jz	srvhos2			; z = yes
	mov	trans.chklen,1		; reply with 1 char checksum
	mov	dx,offset remms9	; else give a message
	call	ermsg
	mov	bx,dx
	call	errpack			; back to local kermit
	clc
	ret

srvhos2:mov	si,offset decbuf	; received filename, asciiz from dodec
	mov	di,offset srvbuf	; destination
	call	strcpy			; copy data to srvbuf
	jmp	SRDIR6			; do common completion code
srvhos	endp

; Respond to other side's request of Remote Help. Write & read $kermit$.tmp
srvhlp	proc	near
	mov	dx,offset dostemp+3	; use filename of $kermit$.tmp
	mov	ah,creat2		; create the file
	xor	cx,cx			; attributes r/w
	int	dos
	jc	srvhlp1			; c = could not open
	mov	dx,offset hlprem	; data to be sent, strlen uses dx
	call	strlen			; put string length in cx
	mov	bx,ax			; handle
	mov	ah,write2		; write to file
	int	dos			; write the info
	mov	ah,close2	; close the file so we can reread it below
	int	dos
srvhlp1:mov	si,offset infms4	; pseudo filename
	mov	di,offset auxfile	; send-as name
	call	strcpy			; copy it there
	jmp	srvtail			; send temporary file to remote screen
srvhlp	endp

; srvker - handle other side's request of REM Kermit command-line.
srvker	proc	near
	call	logchk			; check login status
	jc	srvker8			; c = ok
	ret				; else have sent error packet
srvker8:test	denyflg,kerflg		; command enabled?
	jz	srvker1			; z = yes
	mov	trans.chklen,1		; reply with 1 char checksum
	mov	dx,offset remms9	; else give a message
	call	ermsg
	mov	bx,dx
	call	errpack			; back to local kermit
	clc
	ret

srvker1:call	takopen_macro		; open a Take macro
	jc	srvker3			; c = failed to obtain Take space
	mov	dx,prmptr		; get prompt
	call	prompt          	; prompt user, set reparse address
	mov	bx,takadr		; pointer to Take structure
	mov	skertmp,bx		; remember it here for cleanup
	mov	dx,offset decbuf	; received command, asciiz
	call	strlen			; get length into cx
	mov	si,dx
srvker6:cmp	byte ptr [si],' '	; strip leading white space
	ja	srvker7			; a = non-white
	loop	srvker6			; continue
srvker7:cmp	cx,8			; need at least 8 chars "SET xx y"
	jb	srvker2			; b = too few, bad command
	mov	ax,[si]			; get first two characters
	or	ax,2020h		; lower case them
	cmp	ax,'es'			; start of "SET"?
	jne	srvker2			; ne = no, bad command
	mov	ax,[si+2]		; next two
	or	ax,2020h
	cmp	ax,' t'			; rest of "SET "?
	jne	srvker2			; ne = no, bad command
	add	si,4			; move to end of "SET "
	sub	cx,4
	mov	[bx].takcnt,cx		; number of bytes in command
	push	es
	mov	ax,[bx].takbuf		; segment of Take buffer
	mov	es,ax
	mov	di,2			; place here (skip buf length word)
	cld
	rep	movsb
	mov	al,CR
	stosb
	pop	es
	inc	[bx].takcnt		; number of bytes in command

	call	setcom
	jnc	srvker3			; nc = success
srvker2:mov	si,offset remms6	; "Command failed"
	jmp	short srvker4
srvker3:mov	si,offset remms8	; "Command succeeded"
srvker4:mov	di,offset encbuf	; destination for message
	call	strcpy			; move the message
	mov	dx,di
	call	strlen			; length to cx
	mov	si,offset rpacket	; use this packet for reply
	call	doenc			; encode
	mov	trans.chklen,1		; reply with 1 char checksum
	call	ackpak			; send ACK with message
	mov	ax,skertmp		; get old take address
	cmp	ax,takadr		; same (still in current Take)?
	jne	srvker5			; ne = no
	call	takclos			; close the Take file
srvker5:clc
	ret
srvker	endp

;  Command                                Code   Values
;  REMOTE SET ATTRIBUTES IN ALL            132   0 = OFF, 1 = ON
;  REMOTE SET ATTRIBUTES IN LENGTH         133   0 = OFF, 1 = ON
;  REMOTE SET ATTRIBUTES IN TYPE           134   0 = OFF, 1 = ON
;  REMOTE SET ATTRIBUTES IN DATE           135   0 = OFF, 1 = ON
;X  REMOTE SET ATTRIBUTES IN CREATOR        136   0 = OFF, 1 = ON
;X  REMOTE SET ATTRIBUTES IN ACCOUNT        137   0 = OFF, 1 = ON
;X  REMOTE SET ATTRIBUTES IN AREA           138   0 = OFF, 1 = ON
;X  REMOTE SET ATTRIBUTES IN BLOCK-SIZE     139   0 = OFF, 1 = ON
;X  REMOTE SET ATTRIBUTES IN ACCESS         140   0 = OFF, 1 = ON
;X  REMOTE SET ATTRIBUTES IN ENCODING       141   0 = OFF, 1 = ON
;X  REMOTE SET ATTRIBUTES IN DISPOSITION    142   0 = OFF, 1 = ON
;X  REMOTE SET ATTRIBUTES IN PROTECTION     143   0 = OFF, 1 = ON
;X  REMOTE SET ATTRIBUTES IN GPROTECTION    144   0 = OFF, 1 = ON
;X  REMOTE SET ATTRIBUTES IN SYSTEM-ID      145   0 = OFF, 1 = ON
;X  REMOTE SET ATTRIBUTES IN FORMAT         146   0 = OFF, 1 = ON
;X  REMOTE SET ATTRIBUTES IN SYS-INFO       147   0 = OFF, 1 = ON
;X  REMOTE SET ATTRIBUTES IN BYTE-COUNT     148   0 = OFF, 1 = ON
;
;  REMOTE SET ATTRIBUTES OUT ALL           232   0 = OFF, 1 = ON
;  REMOTE SET ATTRIBUTES OUT LENGTH        233   0 = OFF, 1 = ON
;  REMOTE SET ATTRIBUTES OUT TYPE          234   0 = OFF, 1 = ON
;  REMOTE SET ATTRIBUTES OUT DATE          235   0 = OFF, 1 = ON
;X  REMOTE SET ATTRIBUTES OUT CREATOR       236   0 = OFF, 1 = ON
;X  REMOTE SET ATTRIBUTES OUT ACCOUNT       237   0 = OFF, 1 = ON
;X  REMOTE SET ATTRIBUTES OUT AREA          238   0 = OFF, 1 = ON
;X  REMOTE SET ATTRIBUTES OUT BLOCK-SIZE    239   0 = OFF, 1 = ON
;X  REMOTE SET ATTRIBUTES OUT ACCESS        240   0 = OFF, 1 = ON
;X  REMOTE SET ATTRIBUTES OUT ENCODING      241   0 = OFF, 1 = ON
;X  REMOTE SET ATTRIBUTES OUT DISPOSITION   242   0 = OFF, 1 = ON
;X  REMOTE SET ATTRIBUTES OUT PROTECTION    243   0 = OFF, 1 = ON
;X  REMOTE SET ATTRIBUTES OUT GPROTECTION   244   0 = OFF, 1 = ON
;X  REMOTE SET ATTRIBUTES OUT SYSTEM-ID     245   0 = OFF, 1 = ON
;X  REMOTE SET ATTRIBUTES OUT FORMAT        246   0 = OFF, 1 = ON
;X  REMOTE SET ATTRIBUTES OUT SYS-INFO      247   0 = OFF, 1 = ON
;X  REMOTE SET ATTRIBUTES OUT BYTE-COUNT    248   0 = OFF, 1 = ON
;
;  REMOTE SET FILE TYPE                    300   0 = TEXT, 1 = BINARY
;X  REMOTE SET FILE NAMES                   301   0 = CONVERTED, 1 = LITERAL
;  REMOTE SET FILE COLLISION               302   0 = RENAME,  1 = REPLACE,
;                                                X 2 = BACKUP,  X 3 = APPEND,
;                                                4 = DISCARD, X  5 = ASK
;X  REMOTE SET FILE REPLACE                 303   0 = PRESERVE, 1 = DEFAULT
;  REMOTE SET INCOMPLETE                   310   0 = DISCARD, 1 = KEEP
;
;  REMOTE SET BLOCK-CHECK                  400   number (1, 2, or 3)
;  REMOTE SET RECEIVE PACKET-LENGTH        401   number (10-9024)
;  REMOTE SET RECEIVE TIMEOUT              402   number (any, 0 = no timeout)
;  REMOTE SET RETRY                        403   number (any, 0 = no limit)
;  REMOTE SET SERVER TIMEOUT               404   number (any, 0 = no timeout)
;  REMOTE SET TRANSFER CHARACTER-SET       405   Character Set Designator
;  REMOTE SET WINDOW-SLOTS                 406   number (1-31)
;
; Items marked with "X" are ignored by this server

; srvset - manage incoming REMOTE SET commands
; decode buffer looks like S<len1><value1><len2><value2>
srvset	proc	near
	mov	bufptr,offset decbuf+1	; received command data, asciiz
	call	srvswk			; worker to convert first value to ax
	jc	srvset3			; c = failure
	mov	temp,ax			; save first value here
	cmp	ax,132			; before known set?
	jb	srvset3			; b = yes, bad
	mov	di,offset sattr		; assume SET ATTRIBUTES
	cmp	ax,148			; still in range?
	jbe	srvset2			; be = yes
	cmp	ax,232			; before next range?
	jb	srvset1			; b = yes
	cmp	ax,248			; still in range?
	jbe	srvset2			; be = yes, get final value
srvset1:push	es			; do table lookup on other values
	push	ds
	pop	es
	mov	di,offset setval	; look up other codes in table
	mov	cx,setvlen
	cld
	repne	scasw
	pop	es
	mov	bx,offset remms1	; "Unknown server command", if needed
	jne	srvset3			; ne = no match, unknown command
	sub	di,offset setval+2	; get displacement
	mov	di,setvec[di]
srvset2:call	di			; call the action routine
	mov	bx,offset remms6	; "Command failed", if needed
	jc	srvset3			; c = failure
	mov	si,offset remms8	; "Command succeeded"
	mov	di,offset encbuf	; destination for message
	call	strcpy			; move the message
	mov	dx,di
	call	strlen			; length to cx
	mov	si,offset rpacket	; use this packet for reply
	call	doenc			; encode
	mov	trans.chklen,1		; reply with 1 char checksum
	call	ackpak			; send ACK with message
	clc
	ret
srvset3:mov	trans.chklen,1		; reply with 1 char checksum
	call	errpack			; send error message in ptr bx
	clc
	ret
srvset	endp

sattr	proc	near			; SET ATTRIBUTES IN/OUT ITEM ON/OFF
	mov	ax,temp			; get kind of attribute
	cmp	ax,200			; the OUT kind?
	jb	sattr1			; b = no, IN kind
	sub	ax,100			; merge to same thing
sattr1:	cmp	ax,132			; ALL?
	jne	sattr2			; be = ok
	mov	bl,0ffh			; all bits
	jmp	short sattr6
sattr2:	cmp	al,133			; Length?
	jne	sattr3			; ne = no
	mov	bl,attlen
	jmp	short sattr6
sattr3:	cmp	al,134			; Type
	jne	sattr4			; ne = no
	mov	bl,atttype
	jmp	short sattr6
sattr4:	cmp	bl,135			; Date?
	jne	sattr5			; ne = no, fail
	mov	bl,attdate
	jmp	short sattr6
sattr5:	stc				; fail
	ret
sattr6:	call	srvswk			; get second value to ax, 1 = on
	jc	sattr5			; c = failure
	or	ax,ax			; off?
	jnz	sattr7			; nz = no, on
	mov	al,flags.attflg		; current flags
	not	bl			; invert selected items
	and	al,bl			; turn off selected items
	mov	flags.attflg,al		; store the flags
	clc
	ret
sattr7:	cmp	ax,1			; on?
	jne	sattr5			; ne = no, fail
	or	flags.attflg,bl		; insert ON selected bits
	clc	
	ret
sattr	endp

sftype	proc	near			; SET FILE TYPE
	call	srvswk			; get second value to ax
	jc	sftypb			; c = failure
	cmp	al,1
	ja	sftypb			; a = bad
	mov	trans.xtype,al		; store transfer type
	mov	dtrans.xtype,al		; store transfer type
	clc
	ret
sftypb:	stc				; bad command
	ret
sftype	endp

sfcoll	proc	near			; SET FILE COLLISION
	call	srvswk			; get second value to ax
	jc	sfcollb			; c = failure
	cmp	ax,filecol_update	; 6, highest value
	ja	sfcollb			; a = bad
	cmp	ax,filecol_backup	; backup?
	je	sfcollb			; e = yes, bad command
;;;;;;	cmp	ax,filecol_append	; append?
;;;;;;	je	sfcollb			; e = yes, bad command
	mov	flags.flwflg,al		; set file collison state
	clc
	ret
sfcollb:stc				; bad command
	ret
sfcoll	endp

sfinc	proc	near 			; SET INCOMPLETE, SET FILE INCOMPLETE
	call	srvswk			; get second value to ax
	jc	sfincb			; c = failure
	cmp	ax,1
	ja	sfincb			; a = bad
	xor	al,1			; invert from wire (wire discard = 0)
	mov	flags.abfflg,al		; discard incomplete files if al = 1
	clc
	ret
sfincb:	stc				; bad command
	ret
sfinc	endp

srtmo	proc	near			; SET RECEIVE TIMEOUT
	call	srvswk			; get second value to ax
	jnc	srtmo1			; nc = success
	ret
srtmo1:	cmp	ax,94			; above limit?
	jbe	srtmo2			; be = no
	mov	al,94
srtmo2:	mov	trans.rtime,al
	clc
	ret
srtmo	endp

sblkck	proc	near			; SET BLOCK-CHECK
	call	srvswk			; get second value to ax
	jnc	sblkck1			; nc = success
	ret				; fail
sblkck1:cmp	ax,3			; our limit
	jbe	sblkck2			; be = safe
	mov	ax,3			; set to max
sblkck2:or	ax,ax			; too small?
	jnz	sblkck3			; z = no
	inc	ax
sblkck3:mov	dtrans.chklen,al	; use this char as initial checksum
	clc
	ret
sblkck	endp

srpkt	proc	near 			; SET RECEIVE PACKET-LENGTH
	call	srvswk			; get second value to ax
	jnc	srpkt1			; nc = success
	ret
srpkt1:	cmp	ax,9024			; above limit?
	jbe	srpkt2			; be = no
	mov	ax,9024
srpkt2:	cmp	ax,20			; too small?
	jae	srpkt3			; ae = no
	mov	ax,20			; set minimum
srpkt3:	mov	dtrans.rlong,ax		; set long packet size
	mov	bl,dtrans.rpsiz		; regular packet size
	xor	bh,bh
	cmp	ax,bx			; is long packet shorter
	jae	srpkt4			; ae = no
	mov	dtrans.rpsiz,al		; set regular pkt length too
srpkt4:	clc
	ret
srpkt	endp

sretry	proc	near			; REMOTE SET RETRY
	call	srvswk			; get second value to ax
	jnc	sretry1			; nc = success
	ret				; fail
sretry1:cmp	ax,63			; our limit
	jbe	sretry2			; be = safe
	mov	ax,63			; set to max
sretry2:mov	maxtry,al		; set packet retry limit
	clc
	ret
sretry	endp

sstmo	proc	near			; SET SERVER TIMEOUT
	call	srvswk			; get second value to ax
	jnc	sstmo1			; nc = success
	ret
sstmo1:	cmp	ax,255
	jbe	sstmo2			; be = in range
	mov	al,255			; limit to max
sstmo2:	mov	srvtmo,al		; store timeout value
	clc
	ret
sstmo	endp

sxfrch	proc	near			; SET TRANSFER CHARACTER-SET string
	mov	bx,bufptr
	xor	ch,ch
	mov	cl,[bx]			; byte count of next field, if any
	sub	cl,' '			; remove ascii bias
	jnc	sxfrch1			; nc = is ok
	ret
sxfrch1:inc	bx			; look at character string
	cmp	byte ptr[bx],'A'	; A for Transparent?
	jne	sxfrch2
	cmp	cx,1			; just that char?
	jne	sxfrchb			; ne = no, fail
	mov	trans.xchset,0		; set transfer char set to Transparent
	clc
	ret
sxfrch2:cmp	cx,6			; "I2/100"?
	jne	sxfrchb			; ne = no, fail
	cmp	word ptr [bx],'2I'	; length is ok, check spelling
	jne	sxfrchb			; ne = failure
	cmp	word ptr [bx+2],'1/'
	jne	sxfrchb
	cmp	word ptr [bx+4],'00'
	jne	sxfrchb
	mov	trans.xchset,1		; set transfer char set to Latin1
	clc
	ret
sxfrchb:stc				; fail
	ret
sxfrch	endp

swind	proc	near			; SET WINDOW-SLOTS
	call	srvswk			; get second value to ax
	jnc	swind1			; nc = success
	ret
swind1:	cmp	ax,31			; max legal
	jbe	swind2			; be = in range
	mov	al,31			; limit to max
swind2:	or	ax,ax			; no windowing?
	jnz	swind3			; nz = no, not that way
	mov	ax,1			; local min size for no windowing
swind3:	mov	dtrans.windo,al		; store default window size
	clc
	ret
swind	endp

; Worker for srvset. Reads buffer pointed at by bufptr looking for 
; construction <length><numbers>. Returns carry clear and binary number
; in AX, else carry set and AX = -1. Bufptr is always updated.
srvswk	proc	near
	push	bx
	push	cx
	push	dx
	push	si
	mov	bx,bufptr
	xor	ch,ch
	mov	cl,[bx]			; byte count of next field, if any
	sub	cl,' '			; remove ascii bias
	jnc	srvswk1			; nc = is ok
	mov	ax,-1			; else say value is -1
	jmp	short srvswkx
srvswk1:inc	bx
	xor	si,si			; accumulated value
	mov	dl,10
srvswk2:mov	ax,si			; accumulated value
	mul	dl			; times 10
	mov	si,ax			; store
	xor	ah,ah
	mov	al,[bx]			; get a digit
	inc	bx
	sub	al,'0'			; remove ascii bias
	jnc	srvswk3			; nc = no
	mov	ax,-1			; say bad value
	jmp	short srvswkx		; and quit
srvswk3:add	si,ax			; accumulate new digit
	loop	srvswk2			; do all digits
	mov	ax,si			; return results in ax
	clc
srvswkx:mov	bufptr,bx		; remember where we read from decbuf
	pop	si
	pop	dx
	pop	cx
	pop	bx
	ret
srvswk	endp

; srvini - init parms based on 'I' init packet
srvini	proc	near
	call	spar			; parse info
	call	packlen
	mov	cx,trans.rlong		; max receiving pkt length to report
	call	makebuf			; remake buffers for new windowing
	push	si
	mov	si,offset rpacket
	call	rpar			; setup info about our reception
	pop	si
	mov	al,trans.chklen		; checksum length negotiated
	push	ax			; save around reply
	mov	trans.chklen,1		; reply with 1 char checksum
	call	ackpak
	pop	ax			; restore checksum length
	mov	dtrans.chklen,al	;  to negotiation value
	clc				; success
	ret
srvini	endp


; BYE command - tell remote KERSRV to logout & exit to DOS  

BYE	PROC	NEAR
	mov	ah,cmeol		; get a confirm
	call	comnd
	jnc	bye1			; nc = success
	ret				; failure
bye1:	mov	remcmd,'L'		; Logout command letter
	call	logo			; tell the host Kermit to logout
 	jc	bye2			; c = failed, do not exit
;;;	mov	flags.extflg,1		; set this Kermit's exit flag
	call	serhng			; hangup the phone
bye2:	clc
	ret
BYE	ENDP

; FINISH - tell	remote KERSRV to exit

FINISH	PROC	NEAR
	mov	ah,cmeol		; get a confirm
	call	comnd
	jnc	finish1			; nc = success
	ret				; failure
finish1:mov	remcmd,'F'		; Finish command letter
	call	logo
	clc
	ret
FINISH	ENDP

; Common routine for BYE, FINISH, REMOTE LOGOUT. Avoids sending I packet.
; Return carry clear for success, else carry set
LOGO	PROC	NEAR
	call	serini			; Initialize port
	jnc	logo1			; nc = success
	ret				; c = failure
logo1:	call	clrbuf			; clear serial port buffer
	call	ihostr			; initialize the host
	mov	trans.windo,1		; one window slot before negotiations
	mov	cx,dspsiz		; default send pkt length (94)
	call	makebuf			; set up packet buffers
	xor	ax,ax
	mov	diskio.string,al	; clear local filename for stats
	mov	pktnum,al		; packet number to be used
	mov	windlow,al		; reset windowing
	call	packlen			; get max packet length
	call	getbuf			; get buffer for sending
	mov	trans.chklen,1		; use one char for server functions
	mov	ah,remcmd		; get command letter ('L' or 'F')
	mov	encbuf,ah		; encode the command
	mov	cx,1			; one piece of data
	call	doenc			; do encoding
	mov	[si].pktype,'G'		; Generic command packet type
	mov	flags.xflg,1		; say receiving to screen
	call	sndpak			;  to suppress # pkts msg
	jc	logo3			; c = failure
	mov	al,[si].seqnum		; get response for this sequence num
	mov	ah,maxtry		; retry threshold
	call	response		; get response
	pushf
	mov	si,offset rpacket	; packet to look at
	cmp	[si].pktype,'E'		; Error packet?
	je	logo2			; e = yes, contents displayed already
	call	msgmsg			; show any message
logo2:	popf
logo3:	mov	flags.cxzflg,0		; clear these flags
	mov	flags.xflg,0
	ret				; exit with carry flag from response
LOGO	ENDP

; Get files from server, ask for them to be deleted at source afterward.
RETRIEVE PROC	NEAR
	mov	delfile_flag,1
	mov	temp,0
	mov	getkind,0		; non-recursive
	jmp	GET0
RETRIEVE ENDP

REGET	PROC	NEAR
	mov	dx,offset erms37	; say use Binary mode
	cmp	dtrans.xtype,1		; in Binary mode?
	jne	reget1			; ne = no, a requirement
	mov	dx,offset erms38	; say must use attributes
	cmp	flags.attflg,0		; allowed to do file attributes?
	je	reget1			; e = no
	mov	temp,1			; flag for internal RESEND state (1)
	mov	getkind,0		; non-recursive
	jmp	GET0
reget1:	mov	ah,prstr
	int	dos
	or	fsta.xstatus,kssend+ksgen ; set status, failed + cmd failure
	mov	kstatus,kssend+ksgen	; global status
	stc
	ret
REGET	ENDP

; GET command. Ask remote server to send the specified file(s)
; Queries for remote filename and optional local override path/filename
GET	PROC	NEAR
	mov	delfile_flag,0
	mov	temp,0
	mov	getkind,0		; assume non-recursive
	mov	comand.cmswitch,1	; parse for optional /switch
	mov	comand.cmcr,1		; empty line is ok
	mov	ah,cmkey
	mov	dx,offset sndswtab	; switch table
	xor	bx,bx			; no help text
	call	comnd
	jc	GET0			; c = no switch
	mov	getkind,bl		; remember switch value
			; GET0 is also used by REGET and RETRIEVE above
GET0:	mov	auxfile,0		; local name, clear for safety
	mov	flags.cxzflg,0		; no Control-C typed yet
	mov	bx,offset encbuf	; where to put text
	mov	dx,offset filmsg	; help
	mov	ah,cmword		; filename w/out embedded whitespace
	call	comnd
	jnc	get1			; nc = success
	ret				; failure 
get1:	mov	cnt,ax			; remember number of chars we read
	or	ax,ax			; read any chars?
	jnz	get4			; nz = yes, get optional local name
					; empty line, ask for file names
get2:	mov	dx,offset remfnm	; ask for remote name first
	call	prompt
	mov	bx,offset encbuf	; place for remote filename
    	mov	dx,offset frem		; help message
	mov	ah,cmline		; use this for embedded spaces
	call	comnd			; get a filename
	jnc	get3			; nc = success
	ret				; failure
get3:	mov	cnt,ax			; remember number of chars read
	or	ax,ax			; count of entered chars
	jz	get2			; z = none, try again
	mov	dx,offset lclfnm	; prompt for local filename
	call	prompt
get4:	mov	dx,offset filhlp
	mov	bx,offset auxfile	; complete local filename
	mov	ah,cmword		; get a word
	call	comnd
	jnc	get5			; nc = success
	ret				; failure
get5:	mov	ah,cmeol		; get confirmation
	call	comnd
	jnc	get6			; nc = success
	ret				; failure
get6:	cmp	auxfile,'#'		; is first char a replacement for '?'
	jne	get7			; ne = no
	mov	auxfile,'?'		; replace '#' by '?'
get7:	cmp	encbuf,'#'		; is first char a replacement for '?' ?
	jne	get8			; ne = no
	mov	encbuf,'?'		; replace '#' by '?'

get8:	call	rrinit			; get & clear buffers and counters
	mov	flags.xflg,1		; assume writing to screen
	cmp	flags.destflg,dest_screen ; receiving to screen?
	je	get8a			; e = yes, skip screen stuff
	mov	flags.xflg,0		; not writing to screen, yet
	call	init			; init (formatted) screen
get8a:	mov	kstatus,kssuc		; global status, success
	call	ipack			; Send Initialize, 'I', packet
	jnc	get8b			; nc = success, ok to fail 'I' pkt
	jmp	short get10		; failure

get8b:	mov	si,offset encbuf	; copy from here
	mov	di,offset fsta.xname	; to statistics remote name field
	call	strcpy
	mov	di,offset vfile
	call	strcpy			; for vfile in mssrcv
	mov	si,offset rpacket	; packet for response
	mov	cx,cnt			; get back remote filename size
	call	doenc			; encode data already in encbuf
	jnc	get9			; nc = success
	mov	dx,offset ermes6    	; filename is too long for pkt
	call	ermsg
	mov	bx,dx			; point to message, for errpack
	call	errpack			; tell the host we are quiting
	jmp	short get10		; data could not all fit into packet

get9:	mov	trans.chklen,1		; use one char for server functions
	mov	rpacket.pktype,'R'	; Receive init packet
	cmp	temp,0			; not a REGET?
	je	get9b			; e = correct
	mov	rpacket.pktype,'J'	; make this a REGET
get9b:	cmp	delfile_flag,0		; normal GET?
	je	get9a			; e = yes
	mov	rpacket.pktype,'H'	; Retrieve initiate
get9a:	cmp	getkind,4		; recursive?
	jne	get9c			; ne = no
	mov	rpacket.pktype,'V'	; recursive receive
get9c:	mov	si,offset rpacket
	call	sndpak			; send the packet, no ACK expected
	jc	get10			; c = failure to send packet
	mov	rstate,'R'		; Set the state to receive initiate
	jmp	READ2			; go join read code

get10:	call	bufclr			; total failures come here
	call	rprpos			; reset cursor for prompt
	or	errlev,ksrecv		; set DOS error level to cannot rcv
	or	fsta.xstatus,ksrecv	; set status
	mov	kstatus,ksrecv		; global status
	mov	flags.cxzflg,0		; clear flag for next command
	mov	auxfile,0		; clear send-as filename buffer
	mov	flags.xflg,0		; clear to-screen flag
	mov	al,1			; underline cursor
	call	fcsrtype		; set IBM-PC cursor to underline
	clc
	ret
GET	ENDP

;	This is the REMOTE command

REMOTE	PROC	NEAR
	mov	dx,offset remtab	; Parse keyword from the REMOTE table
	mov	bx,offset remhlp
	mov	ah,cmkey
	call	comnd
	jnc	remote1			; nc = success
	ret				; failure
remote1:push	crcword			; preserve CRC-16 around remotes
	push	word ptr lastfsize	; and last sent file size
	push	word ptr lastfsize+2
	call	bx			; do the appropriate routine
	pop	word ptr lastfsize+2
	pop	word ptr lastfsize
	pop	crcword			; restore CRC-16
	ret
REMOTE	ENDP

; REMSET - Execute a REMOTE SET command

REMSET	PROC	NEAR
	mov	rempac,'G'		; Packet type = generic
	mov	encbuf,'S'		; command type = Set
	mov	bufptr,offset encbuf+1	; place more pkt material here
	mov	ah,cmkey		; get keyword
	mov	dx,offset remstt1	; table of keywords
	xor	bx,bx			; help
	call	comnd
	jnc	remset1			; nc = success
	ret
remset1:cmp	bx,1			; Attributes?
	jne	remset5			; ne = no
	mov	dx,offset remsat1	; Attributes IN, OUT table
	xor	bx,bx			; help
	mov	ah,cmkey
	call	comnd
	jnc	remset2
	ret
remset2:mov	temp,bx			; save in out
	mov	dx,offset remsat2	; next attributes keyword table
	xor	bx,bx			; help
	mov	ah,cmkey
	call	comnd
	jnc	remset3
	ret
remset3:add	bx,temp			; save final value
	call	remwork
	mov	dx,offset onoff		; ON, OFF table
	xor	bx,bx			; help
	mov	ah,cmkey		; get on,off
	call	comnd
	jnc	remset4
	ret
remset4:jmp	remset17

remset5:cmp	bx,2			; REMOTE SET FILE?
	jne	remset14		; ne = no
	mov	dx,offset remsfit	; REM SET FILE table
	xor	bx,bx			; help
	mov	ah,cmkey
	call	comnd
	jnc	remset6
	ret
remset6:push	bx
	call	remwork			; write kind to buffer
	pop	bx
	cmp	bx,300			; TYPE?
	jne	remset8
	mov	dx,offset remsfty	; TYPE table
	xor	bx,bx
	mov	ah,cmkey
	call	comnd
	jnc	remset6a		; nc = success
	ret
remset6a:push	bx
	mov	ah,cmeol		; get a confirmation
	call	comnd
	pop	bx
	jnc	remset6b
	ret
remset6b:mov	dtrans.xtype,bl		; store transfer type
	mov	trans.xtype,bl		; store transfer type
	call	remwork			; write to buffer
	jmp	remset23

remset8:cmp	bx,301			; NAME?
	jne	remset10		; ne = no
	mov	dx,offset remsfna	; NAME table
	xor	bx,bx
	mov	ah,cmkey
	call	comnd
	jnc	remset17
	ret

remset10:cmp	bx,302			; COLLISION?
	jne	remset12		; ne = no
	mov	dx,offset remsfco	; COLLISION table
	xor	bx,bx
	mov	ah,cmkey
	call	comnd
	jnc	remset17
	ret

remset12:cmp	bx,303			; REPLACE?
	jne	remset13		; ne = no
	mov	dx,offset remsfre	; REPLACE table
	xor	bx,bx
	mov	ah,cmkey
	call	comnd
	jnc	remset17
	ret

remset13:cmp	bx,310			; INCOMPLETE?
	jne	remset13a		; ne = no
	mov	dx,offset remsfin	; INCOMPLETE table
	xor	bx,bx
	mov	ah,cmkey
	call	comnd
	jnc	remset17
remset13a:stc
	ret

remset14:cmp	bx,310			; REMOTE SET INCOMPLETE?
	jne	remset15		; ne = no
	push	bx
	call	remwork			; write main command
	pop	bx
	jmp	short remset13		; use above to complete the command

remset15:cmp	bx,3			; REMOTE SET RECEIVE?
	jne	remset18		; ne = no
	mov	dx,offset remsrcv	; RECEIVE table
	xor	bx,bx
	mov	ah,cmkey
	call	comnd
	jnc	remset19		; get value as text
remset16:stc
	ret

remset17:call	remwork			; write to buffer
	jmp	short remset22
					; text as last item commands
remset18:mov	temp,bx
	cmp	bx,405			; Transfer?
	jne	remset19		; ne = no, do common code
	mov	dx,offset remsxfr	; TRANSFER table
	xor	bx,bx
	mov	ah,cmkey
	call	comnd
	jnc	remset18a
	ret
remset18a:cmp	bx,410			; REMOTE SET TRANSFER MODE?
	jne	remset19		; ne = no
	mov	dx,offset modetab	; Mode table
	xor	bx,bx
	mov	ah,cmkey
	call	comnd
	jnc	remset17		; nc = ok, write value to buffer
	ret

remset19:call	remwork			; store command type
	mov	bx,bufptr		; store response as text
	inc	bx			; skip count byte
	mov	dx,offset numhlp
	cmp	temp,405		; Transfer character set needs string
	jne	remset20		; ne = not string
	mov	dx,offset xfrhlp	; use this help
remset20:mov	ah,cmword
	call	comnd
	jnc	remset21
	ret
remset21:mov	dx,bufptr		; field pointer
	inc	dx			; look at text
	call	strlen			; length to cx
	add	cx,' '			; compute byte count field
	mov	bx,bufptr
	mov	[bx],cl			; store byte count

remset22:mov	ah,cmeol		; get a confirmation
	call	comnd
	jnc	remset23
	ret
remset23:mov	dx,offset encbuf
	call	strlen			; get length
	mov	cnt,cx			; length for generic
	mov	flags.xflg,1		; response coming to screen
	jmp	genr9			; do the operation
REMSET	ENDP

; Remote Set worker. Enter with new numerical value in BX. Writes length
; and asciiz value to encbuf and increments buffer pointer bufptr.
remwork	proc	near
	mov	di,offset tmpbuf	; temp buffer
	mov	byte ptr [di],0		; clear it
	mov	ax,bx
	call	dec2di			; convert value to asciiz
	mov	dx,offset tmpbuf	; get length to cx
	mov	si,dx			; asciiz data source
	call	strlen
	push	cx			; save length
	mov	di,bufptr		; byte count field
	add	cl,' '			; to ascii
	mov	[di],cl			; store count byte
	inc	di
	pop	cx
	push	es
	push	ds
	pop	es
	cld
	rep	movsb			; copy asciiz data value
	pop	es
	mov	byte ptr [di],0		; insert null terminator
	mov	bufptr,di
	ret
remwork	endp

; In REM commands below, al = remcmd, ah = rempac, cl = remlen

; REMOTE ASSIGN name value
; Packet is GV<count of 1>S<count>name<count>value
REMASG	PROC	NEAR
	mov	encbuf,'V'		; V is set 
	mov	word ptr encbuf+1,'S!'	; S for system variable, len 1 (!)
	mov	encbuf+3,' '		; count of name string
	mov	bx,offset encbuf+4	; buffer for remote variable name
	mov	dx,offset rasghlp1	; add help later
	mov	comand.cmper,1		; do not react to '\%' in macro name
	mov	comand.cmblen,94	; max length encoded in one byte 
	mov	ah,cmword
	call	comnd
	jnc	remasg1			; nc = success
	ret				; failure
remasg1:add	encbuf+3,al		; length of variable
	mov	bx,offset encbuf+4	; buffer for 'value'
	add	bx,ax			; length of variable string
	mov	byte ptr [bx],' '	; empty second byte count
	push	bx
	inc	bx			; skip second byte count
	mov	ax,offset encbuf+512	; last byte + 1 in encbuf
	sub	ax,bx			; minus part already used
	mov	comand.cmblen,ax	; length of encbuf available
	mov	ah,cmline		; read definition string
	mov	dx,offset rasghlp2
	call	comnd
	pop	bx
	jnc	remasg2			; nc = success
	ret				; failure
remasg2:cmp	ax,94			; longer than fits in one byte?
	ja	remasg3			; ae = yes, use <count> of space
	add	[bx],al			; length of 'value'
remasg3:add	bx,ax			; step to end of string
	mov	byte ptr [bx+1],0	; null terminator
	mov	flags.xflg,1		; response coming to screen
	mov	rempac,'G'		; Generic Kermit command
	jmp	genr9			; send the packet after I exchange
REMASG	ENDP

; REMCWD - Change remote working directory

REMCWD	PROC	NEAR
	mov	ax,'GC'			; Packet type = generic
	xor	cl,cl			; no text required
	jmp	genric
REMCWD	ENDP

; REMDEL - Delete a remote file

REMDEL	PROC	NEAR
	mov	ax,'GE'			; Packet type = generic
	mov	cl,1			; text required
	jmp	genric
REMDEL	ENDP

; REMDIR - Do a directory

REMDIR	PROC	NEAR
	mov	ax,'GD'			; Packet type = generic
	xor	cl,cl			; no text required
	jmp	genric
REMDIR	ENDP

; REMDIS - Get disk usage on remote system

REMDIS	PROC	NEAR
	mov	ax,'GU'			; Packet type = generic, disk usage
	xor	cl,cl			; optional text permitted
	jmp	genric			; Execute generic Kermit command
REMDIS	ENDP


; REMHEL - Get help about remote commands

REMHEL	PROC	NEAR
	mov	ax,'GH'			; Packet type = generic, Help
	xor	cl,cl			; no text required
	jmp	genric			; Execute generic Kermit command
REMHEL	ENDP

; REMHOS - Execute a remote host command

REMHOS	PROC	NEAR
	mov	ax,'C '			; Packet type = remote command
	mov	cl,1			; text required
	jmp	genric
REMHOS	ENDP

; REMKER - Execute a remote Kermit command

REMKER	PROC	NEAR
	mov	ax,'K '			; Packet type = remote Kermit command
	mov	cl,1			; text required
	jmp	genric
REMKER	ENDP

; REMLOGIN - LOGIN [username [password [account]]]

REMLOGIN PROC	NEAR
	mov	ax,'GI'			; Packet type = generic
	xor	cl,cl			; no text required
	mov	remlog,1		; do prompts
	jmp	genric
REMLOGIN ENDP

; REMOTE LOGOUT - Logout of remote server and host, stay in this Kermit
REMLOGOUT PROC	NEAR
	mov	ax,'GI'			; Packet type = generic
	xor	cl,cl			; no text required
	mov	remlog,0		; skip prompts
	jmp	genric
	
	mov	remcmd,'L'		; Logout command letter
	call	logo			; perform without I packet
	clc
	ret
REMLOGOUT ENDP

; REMMSG - Send one line short message to remote screen.

REMMSG	proc	near
	mov	ax,'GM'
	mov	cl,1			; text required
	jmp	genric
REMMSG	endp

; REMPWD - print remote's working directory

REMPWD	PROC	NEAR
	mov	ah,cmeol
	call	comnd
	jnc	rempwd1
	ret
rempwd1:mov	ax,'GA'			; Packet type = generic
	xor	cl,cl			; no text required
	jmp	genric
REMPWD	ENDP

; REMQRY - Remote Query {Kermit | System | User} name
REMQRY	PROC	NEAR
	mov	dx,offset qrytab	; table of query types (K, S, G)
	xor	bx,bx			; help is table
	mov	ah,cmkey		; get key word
	call	comnd			; get pointer to keyword structure
	jnc	remqry1			; nc = success, bx = 16 bit data
	ret				; failure
remqry1:mov	encbuf,'V'		; V is set 
	mov	word ptr encbuf+1,'Q!'	; Q for query, len 1 (!)
	mov	word ptr encbuf+3,bx	; query count and letter
	mov	encbuf+5,0		; count of name string
	mov	bx,offset encbuf+6	; buffer for remote variable name
	mov	dx,offset rasghlp1	; help msg
	mov	ah,cmword
	call	comnd
	jnc	remqry2			; nc = success
	ret				; failure
remqry2:add	al,' '			; add ASCII bias
	mov	encbuf+5,al		; length of variable
	mov	ah,cmeol		; get c/r confirmation
	call	comnd
	jnc	remqry3
	ret
remqry3:mov	rempac,'G'		; Generic Kermit command
	mov	flags.xflg,1		; response coming to screen
	mov	kstatus,kssuc
	CALL	genr9			; send the packet after I exchange
	cmp	kstatus,kssuc		; success?
	je	remqry4			; e = yes
	mov	decbuf,0		; empty the definition
remqry4:push	es
	mov	ax,queryseg		; malloc'd memory yet?
	or	ax,ax
	jz	remqry5			; z = no
	mov	es,ax
	mov	ah,freemem		; free it
	int	dos
	mov	queryseg,0		; no segment

remqry5:mov	si,offset decbuf	; decoded response, we hope
	mov	dx,si			; get length
	call	strlen
	mov	ax,cx			; bytes in string
	add	ax,2			; plus count word
	call	malloc			; malloc space (ax bytes)
	jnc	remqry6			; nc = got the memory
	xor	cx,cx			; return cx = 0
	mov	queryseg,cx
	pop	es
	stc				; fail right now
	ret
remqry6:mov	queryseg,ax		; seg to store into
	mov	es,ax
	xor	di,di			; offset of zero
	cld
	mov	ax,cx			; store length word first
	stosw
	rep	movsb			; copy to output buffer
	pop	es
	clc
	ret
REMQRY	ENDP

; REMTYP - Type a remote file

REMTYP	PROC	NEAR
	mov	ax,'GT'			; Packet type = generic, Type file
	mov	cl,1			; text required
	jmp	short genric
REMTYP	ENDP

; REMWHO - ask for list of remote logged on users

REMWHO	proc	near
	mov	ax,'GW'
	xor	cl,cl			; optional text permitted
	jmp	short genric
REMWHO	endp

; GENRIC - Send a generic command to a remote Kermit server
; remlen = 0: no additional text, or additional text is optional
; remlen = 1: additional text is required
GENRIC	PROC	NEAR
	mov	remcmd,al		; stash cmd info in real memory
	mov	rempac,ah		; packet type
	mov	remlen,cl		; text required flag
	mov	si,offset infms3	; dummy filename for transaction log
	mov	di,offset diskio.string	; where such names go
	call	strcpy			; move the name
	mov	bx,offset encbuf	; where to put text
	mov	temp,bx			; where field starts
	cmp	rempac,'C'		; Remote Host command? 
	je	genr2			; e = yes, no counted string(s)
	cmp	rempac,'K'		; Remote Kermit command?
	je	genr2			; e = yes, no counted string(s)
genr1:	mov	ah,remcmd		; get command letter
	mov	[bx],ah			; store in buffer
	add	bx,2			; leave room for count byte
	mov	temp,bx			; point at data field
genr2:	mov	ah,cmword		; get trailing optional password
	mov	dx,offset genmsg	; help message
	cmp	remcmd,'C'		; Remote Change Working Directory?
	je	genr2a			; e = yes, get optional password
	mov	ah,cmline		; get a line text
genr2a:	call	comnd
	jnc	genr3			; nc = success
	ret				; failure
genr3:	mov	cnt,ax			; size
	call	genredir		; act on any ">filespec" redirection
	add	temp,ax			; point to next field
	cmp	rempac,'C'		; Remote Host command?
	je	genr4			; e = yes, no counted string(s)
	cmp	rempac,'K'		; Remote Kermit command?
	je	genr4			; e = yes, no counted string(s)
	mov	encbuf+1,al		; size of first field
	add	encbuf+1,32		; do tochar function
	inc	temp			; include count byte
genr4:	cmp	al,remlen		; got necessary command text?
	jae	genr5			; ae = yes
	cmp	remlen,0		; is text optional?
	je	genr5			; e = yes, continue without it
genr4a:	mov	dx,offset infms2	; say need more info
	mov	ah,prstr
	int	dos
	or	errlev,ksgen		; say cannot receive
	or	fsta.xstatus,ksgen	; set status failed
	mov	kstatus,ksgen		; global status
	clc
	ret

genr5:	mov	flags.xflg,1		; output coming to screen
	cmp	remcmd,'I'		; Remote Login command?
	je	genr6			; e = yes
	cmp	remcmd,'C'		; Remote Change Working Directory?
	je	genr7a			; e = yes, get optional password
	jmp	short genr8		; neither so no extra prompts here

genr6:	cmp	remlog,0		; skip prompts (REM LOGOUT)?
	je	genr8			; e = yes
	cmp	cnt,0			; have username etc already?
	je	genr6a			; e = no
	call	genupwd			; parse username etc
	jmp	short genr8		; send formatted contents
genr6a:	mov	dx,offset user		; prompt for username
 	call	prompt
	mov	bx,offset encbuf+1	; skip command letter
	mov	temp,bx			; start of field
	call	input			; read text
	jc	genr8			; c = none
	mov	temp,bx			; point to next data field

genr7:	mov	dx,offset password	; get optional password
	call	prompt
genr7a:	mov	bx,temp			; where to put the password
	cmp	byte ptr [bx-1],0	; extra null?
	jne	genr7b			; ne = no
	dec	bx			; backup to overwrite it
	dec	temp
genr7b:	mov	comand.cmquiet,1	; turn on quiet mode
	call	input			; read in the password
	mov	comand.cmquiet,0	; turn off quiet mode
	jc	genr8			; c = no text, do not add field
	mov	temp,bx			; point to next data field
					;
	cmp	remcmd,'I'		; Remote Login command?
	jne	genr8			; ne = no
	cmp	remlog,0		; skip prompts (REM LOGOUT)?
	je	genr8			; e = yes
	mov	dx,offset account	; get optional account ident
	call	prompt
	mov	bx,temp			; where this field starts
	call	input			; read text
genr8:	mov	remlog,0		; clear rem login/out distinguisher
	cmp	flags.cxzflg,'C'	; Control-C entered?
	jne	genr9			; ne = no
	stc
	ret				; return failure

GENR9:	mov	kstatus,kssuc		; global status
	call	ipack			; Send Init parameters
	jc	genr11			; c = failure
	mov	trans.chklen,1		; use 1 char for server functions
	mov	fsta.pretry,0		; no retries yet
	mov	pktnum,0
	cmp	flags.cxzflg,'C'	; did the user type a ^C?
	jne	genr10			; ne = no
	stc
	ret				; return in error state

genr10:	push	si
	mov	dx,offset encbuf	; source buffer
	call	strlen			; length of data
	call	getbuf			; get a buffer address into si
	mov	ah,rempac		; packet type
	mov	[si].pktype,ah
	call	doenc			; encode data
	mov	trans.chklen,1		; use block check 1 to server
	cmp	echrcnt,0		; did all the data fit?
	je	genr10a			; e = yes
	pop	si			; fail, send E pkt, post local msg
	mov	dx,offset remms11	; say command is too long
	call	ermsg			;  to us and
	mov	bx,dx
	call	errpack			;  to the other Kermit
	jmp	short genr11		; fail out

genr10a:call	sndpak			; send the Generic command packet
	pop	si
	jc	genr11			; c = failure
	mov	rstate,'R'		; next state is Receive Initiate
	push	crcword			; preserve CRC-16 word
	push	word ptr lastfsize	; and last sent file size
	push	word ptr lastfsize+2
	call	READ2			; file receiver does the rest
	pop	word ptr lastfsize+2
	pop	word ptr lastfsize
	pop	crcword
	ret
genr11:	mov	flags.xflg,0		; reset screen output flag
	xor	ax,ax			; tell statistics this was a read
	or	errlev,ksrem	     ; DOS error level, failure of REMote cmd
	mov	fsta.xstatus,ksrem	; set status
	mov	kstatus,ksrem		; global status
	clc
	ret
GENRIC	ENDP

; Extract ">filespec" redirection at end of command line. If found put
; filespec in auxfile as new output name.
genredir proc	near
	mov	cx,cnt			; chars on command line
	jcxz	genred3			; z = none
	mov	di,temp			; buffer, after prologue
	add	di,cx			; end of buffer+1
	dec	di			; last byte of string
	push	ax
	push	es
	mov	ax,ds
	mov	es,ax
	mov	al,'>'			; redirection symbol
	std				; scan backward
	repne	scasb			; found '>'?
	cld
	pop	es
	pop	ax
	jne	genred3			; ne = no
	inc	di			; look at '>'
	mov	byte ptr[di],0		; insert terminator
	mov	ax,cx			; new count length
	mov	cnt,cx			; remember here too
genred1:inc	di			; look at optional filename
	or	di,di			; terminator?
	jz	genred2			; z = yes
	cmp	byte ptr [di],' '	; remove lead-in puncutation
	jbe	genred1			; be = punctuation, go until text
genred2:mov	si,di
	mov	di,offset auxfile	; new output name goes here
	call	strcpy
genred3:ret
genredir endp

; Parse a single command line into username, password, account in counted
; string style, for REM LOGIN. Enter with BX pointing at the next new
; byte to store a command character and CNT holding the current line length.
; Returns a completely formatted line, asciiz. Use {..} to surround items
; with embedded spaces.
genupwd	proc	near
	push	ax
	push	bx
	push	es
	mov	ax,ds
	mov	es,ax
	sub	bx,cnt			; next item minus count of items
	mov	si,bx			; where text starts
	dec	bx			; point at count byte
	mov	cx,3			; three fields possible
genupw1:push	cx
	mov	cx,cnt			; number of text chars to examine
	call	genup10			; get first field
	mov	cnt,cx			; update remaining count
	or	cx,cx			; get remaining count
	pop	cx			; recover loop counter
	jz	genupw2			; z means empty remainder
	loop	genupw1			; try to do three fields
genupw2:pop	es
	pop	bx
	pop	ax
	ret

; Worker. Enter with bx=offset of count byte, si=offset of start of text,
;  cx=chars remaining in input string.
; Exit with bx=offset of next count byte, si=offset of where new text is
; to be read, cx=chars remaining in input string.
genup10:mov	byte ptr [bx],' '	; clear count byte to zero + space
	mov	di,si			; work on text part
	mov	al,' '			; skip whitespace
	cld
	repe	scasb
	je	genup12			; e = nothing present
	dec	di			; back up to non-white char
	inc	cx			; correct count
	mov	si,di			; si = where non-white text starts
	mov	di,bx			; count byte
	inc	di			; where text goes
	mov	ah,' '			; assume this is the break char
	cmp	byte ptr [si],'{'	; field starts with brace?
	jne	genup11			; ne = no
	mov	ah,'}'			; use this break char
	inc	si			; skip over leading brace
	dec	cx			; one less char to consider
genup11:lodsb				; get a char
	cmp	al,ah			; break char yet?
	je	genup12			; e = yes
	or	al,al			; end of text?
	jz	genup12			; z = yes
	stosb				; store char without leading padding
	inc	byte ptr [bx]		; count chars stored in this field
	loop	genup11			; continue
genup12:mov	bx,di			; where to store next count byte
	mov	byte ptr [di],0		; null terminator
	ret
genupwd	endp
	
; Send	"I" packet with transmission parameters

IPACK	PROC	NEAR
	call	serini			; initialize serial port
	jnc	ipack1
	ret				; c = failure
ipack1:	call	ihostr			; initialize the host
	call	clrbuf			; clear serial port buffer
	call	sparmax			; set up our maximum capabilites
	mov	trans.windo,1		; no windows yet
	mov	cx,dspsiz		; default send pkt length (94)
	call	makebuf			; remake buffers
	xor	ax,ax
	mov	rpacket.numtry,al	; number of receive retries
	mov	fsta.pretry,ax		; no retries
	mov	pktnum,al		; packet number 0
	mov	windlow,al		; reset windowing
	call	packlen			; compute packet length
	call	getbuf			; get buffer for sending
	call	rpar			; store them in the packet
	mov	trans.chklen,1		; one char for server function
	mov	ax,18			; 18.2 Bios ticks per second
	mul	trans.stime		; byte, seconds
	mov	k_rto,ax		; round trip timeout, Bios ticks
	mov	[si].pktype,'I'		; "I" packet
	call	sndpak			; send the packet
	jnc	ipack2			; nc = success
	ret				; return failure
ipack2:	mov	al,[si].seqnum
	mov	ah,maxtry		; retry threshold
	add	ah,ah
	add	ah,maxtry		; triple the normal retries
	mov	chkparflg,1		; check for unexpected parity
	call	response		; get response
	jnc	ipack3			; nc = success
	call	bufclr			; clear all
	cmp	rpacket.pktype,'E'	; was it an Error pkt response?
	je	ipack4			; e = yes, this is forgivable
	stc				; carry set for failure
	ret				; return failure

ipack3:	cmp	rpacket.pktype,'Y'	; ACK response?
	jne	ipack4			; ne = no
	push	si
	mov	si,offset rpacket	; packet address
	call	spar			; read in the data
	pop	si
	call	packlen			; get max send packet size
	mov	cx,trans.rlong		; max receiving pkt length to report
	call	makebuf			; remake buffers for new windowing
ipack4:	cmp	rpacket.pktype,'E'	; was it an Error pkt response?
	jne	ipack5			; ne = no
	mov	dx,offset emptymsg	; clear last error line
	call	ermsg			; do it
ipack5:	clc
	ret				; return success
IPACK	ENDP

; Returns BX the updated pointer to the input buffer
;	  input buffer = <ascii data length count byte>textstring
; return carry clear if have text, else carry set for none
INPUT	PROC	NEAR
	mov	temp2,bx		; where to put byte count
	inc	bx			; start text after count byte
	xor	dx,dx			; help, none
	mov	ah,cmline		; get text with embedded whitespace
	call	comnd
	jnc	input1			; nc = success
	mov	bx,temp2		; empty field, restore pointer
	ret				; failure
input1:	push	bx
	mov	bx,temp2
	add	al,' '			; convert byte count to ascii
	mov	[bx],al			; store count byte
	pop	bx			; return pointer to next free byte
	clc				; say have bytes
	ret
INPUT	ENDP

code	ends
	end
