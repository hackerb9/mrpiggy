	NAME	msssen
; File MSSSEN.ASM
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

	public	spar, rpar, nout, send, flags, trans, dtrans, packlen
	public	send10, mail, errpack, sstate, response, ackmsg
	public	pktnum, numpkt, cntretry, sndpak, sparmax, remprn, resend
	public	psend, move, delfile_flag, resend_flag, newfn, sendkind
	public	streaming, streamok

spmin	equ	20		; Minimum packet size
spmax	equ	94		; Maximum packet size

data 	segment
	extrn	fsta:word, auxfile:byte, encbuf:byte, decbuf:byte, maxtry:byte
	extrn	errlev:byte, kstatus:word, diskio:byte, rpacket:byte
	extrn	windflag:byte, rstate:byte, fmtdsp:byte, windlow:byte
	extrn	charids:word, portval:word, chkparflg:byte, maxbufparas:word
	extrn	protlist:byte, flowon:byte, flowoff:byte, rdbuf:byte
	extrn	ferbyte:byte, ferdate:byte, ferdisp:byte, fertype:byte
	extrn	ferchar:byte, fername:byte, ferunk:byte, tfilsz:dword
	extrn	cardet:byte, atflag:byte, atfile:byte, comand:byte
	extrn	domath_ptr:word, domath_cnt:word, k_rto:word, templp:byte
	extrn	templf:byte, vfile:byte

flags	flginfo	<>
trans	trinfo	<>		; negotiated trans information
dtrans	trinfo	<>		; default trans information
crlf	db	cr,lf,'$'
ender	db	bell,bell,'$'
cemsg	db	'User intervention',0
erms14  db	'No response from the host',0
erms15	db	'File not found',0
erms17	db	'Too many retries',0
erms24	db	'Unable to send packet',0
erms25	db	'Host does not support Kermit MAIL command',0
erms26	db	'File rejected by host ',0
erms27	db	'Error. No buffers in send routine',0
erms37	db	' RESEND requires SET FILE TYPE BINARY to be given$'
erms38	db	' RESEND requires SET ATTRIBUTES ON to be given$'
erms39	db	' RESEND capabilities are not negotiated',0
erms40	db	cr,lf,'? Not a decimal number$'
ifndef	nls_portuguese
infms1  db	cr,'             Sending: In progress',cr,lf,'$'
infms2  db	cr,'             Mailing: In progress',cr,lf,'$'
else
infms1  db	cr,'                 Sending: In progress',cr,lf,'$'
infms2  db	cr,'                 Mailing: In progress',cr,lf,'$'
endif	; nls_portuguese
infms3  db	'Completed',cr,lf,'$'
infms4  db	'Failed',cr,lf,'$'
infms5	db	'Remote name is ',0
remfnm	db	' Remote Destination File: ',0	; asciiz
lclfnm	db	' Local Source File: ',0	; asciiz
mailto	db	' To: ',0			; asciiz
mailflg	db	0		; 1 if Mail, 0 if Send command
resend_flag db	0		; file RESEND flag
sendkind db	0
streaming db	0		; non-zero when enabled stream negotiation
streamok db	0		; non-zero when negotiated streaming mode
delfile_flag	db	0	; non-zero to delete file after transfer
printpmt db	' Host printer parameters: ',0	; asciiz 
asmsg	db	' as ',0
sstate	db	0		; current automata state
pktnum	db	0		; packet number
sndcnt	db	0		; retry counter for sndpak, internal
filopn	db	0		; 1 if disk file is open for reading
tempseq	db	0		; target sequence number for responses
retry	db	0		; current retry threshold
	even
current_max dw	60		; current max D packet length
				; attribute procedures
attlist	dw	sat5t,sat1t,sat2t,sat3t,sat4t,sat6t,sat7t,sat99t,0
attptr	dw	0		; pointer to items in attlist
numpkt	dw	0		; number of packets for file group
temp	dw	0
temp4	dw	0
ninefive dw	95		; constant word for long packets

sndswtab db	2		; send /switches
	mkeyw	'/recursive',4
	mkeyw	'/nonrecursive',0

data	ends

data1	segment
filmsg	db	' Local Source File  or press ENTER for prompts$'
filhlp  db      ' A filename (possibly wild)$'
mailhlp	db	' Filename  mail-address  or press ENTER for prompts$'
mailtohlp db	' mail address (eg, user@host or host::user)$'
printhlp db	' Filename and any extra host''s printer paramters$'
printas	db	' host''s printer parameters, such as /COPIES=2/QUE=HPLJ$'
psndhlp db	' filename (for Partial Send) followed by',cr,lf
psndhlp2 db	' decimal number of bytes to skip before sending$'
data1	ends

code1	segment
	extrn bufclr:far, pakptr:far, bufrel:far, makebuf:far, chkwind:far
	extrn getbuf:far, rpack:far, spack:far, fcsrtype:far, peekreply:far
	extrn	logtransact:far, filetdate:far, decout:far, strcat:far
	extrn	strcpy:far, strlen:far, prtasz:far, domath:far, isfile:far
	extrn	krto:far, windgrow:far, windshrink:far, fparse:far
	extrn	getfil:far, gtnfil:far, streampr:far, winpr:far
code1	ends

code	segment
	extrn serini:near, comnd:near, init:near
	extrn gtchr:near, clrbuf:near, filekind:near
	extrn rprpos:near, cxerr:near
	extrn ermsg:near, rtmsg:near, cxmsg:near, stpos:near
	extrn doenc:near, dodec:near, lnout:near
	extrn prompt:near, intmsg:near, msgmsg:near
	extrn pktsize:near
	extrn pcwait:far, ihostr:near, begtim:near, endtim:near
	extrn filecps:near

	assume	cs:code, ds:data, es:nothing

; Data structures comments.
; Sent raw text material (typically rpar and filenames) is placed in encbuf,
; which may be encoded by doenc. doenc needs an output buffer provided as
; a pointer generated here via procedure buflist. encbuf is 512 bytes long.
; Sent packet material is placed in buffers pointed at by buflist. These
; buffers are subdivisions of one large buffer bufbuf (private to msscom).
; Proceedure makebuf does the subdivision and initialization of contents.
; Received material is directed to buffer rbuf which is part of structure
; rpacket; rbuf is 128 bytes long.
; Rpack and Spack expect a pointer in SI to the packet data field, done in a
; pktinfo format.

;	SEND filespec
;	MAIL filspec user@node
;	MOVE filespec
;	REMOTE PRINT filespec parameters
 
SEND	PROC	NEAR
	mov	mailflg,0		; Send command, not Mail command
	mov	temp,0
	mov	delfile_flag,0
	mov	resend_flag,0		; not resend/psend
	jmp	send1			; join common code

MAIL:	mov	mailflg,1		; set flag for Mail command vs Send
	mov	temp,1			; temp copy of mailflag
	mov	resend_flag,0		; not resend
	mov	delfile_flag,0
	jmp	send1

MOVE:	mov	mailflg,0		; Move command, delete file after sent
	mov	temp,0
	mov	resend_flag,0		; not resend/psend
	mov	delfile_flag,1		; delete file after successful send
	jmp	send1			; join common code

REMPRN:	mov	mailflg,2		; REMOTE PRINT entry point
	mov	temp,2
	mov	delfile_flag,0
	mov	resend_flag,0		; not resend
	jmp	short send1

RESEND:	mov	dx,offset erms37	; say use Binary mode
	cmp	dtrans.xtype,1		; in Binary mode?
	jne	resend2			; ne = no, a requirement
resend1:mov	dx,offset erms38	; say must use attributes
	cmp	flags.attflg,0		; allowed to do file attributes?
	je	resend2			; e = no

	mov	mailflg,0		; Send command, but REsend
	mov	temp,0
	mov	delfile_flag,0
	mov	resend_flag,1		; Resend
	jmp	short send1

resend2:mov	ah,prstr
	int	dos
	or	fsta.xstatus,kssend+ksgen ; set status, failed + cmd failure
	mov	kstatus,kssend+ksgen	; global status
	stc
	ret

PSEND:	mov	mailflg,0		; Send command, but Psend
	mov	temp,0
	mov	delfile_flag,0
	mov	resend_flag,2		; Psend

send1:	mov	auxfile,0		; clear send-as name (in case none)
	cmp	mailflg,0
	jne	send1a
	cmp	resend_flag,0
	jne	send1a
	mov	sendkind,0		; presume non-recursive sending
	mov	comand.cmswitch,1	; parse for optional /switch
	mov	comand.cmcr,1		; empty line allowed without error
	mov	ah,cmkey
	mov	dx,offset sndswtab	; switch table
	xor	bx,bx			; no help text
	call	comnd
	jc	send1a			; c = no switch
	mov	sendkind,bl
send1a:	cmp	flags.cxzflg,'C'	; user aborted command?
	jne	send1b			; ne = no
	stc
	ret
send1b:	mov	bx,offset diskio.string ; address of filename string
	mov	dx,offset filmsg	; help message
	cmp	mailflg,0		; Mail command?
	je	send2			; e = no
	mov	mailflg,0		; clear in case error exit
	mov	dx,offset mailhlp	; help message
	cmp	temp,2			; REMOTE PRINT?
	jne	send2			; ne = no
	mov	dx,offset printhlp	; help message
send2:	cmp	resend_flag,2		; Psend?
	jne	send2p
	mov	dx,offset psndhlp	; Psend help
send2p:	mov	ah,cmword		; get input file spec
	call	comnd
	jnc	send2a			; nc = success
	ret				; failure
send2a:	cmp	diskio.string,'#'	; first char a replacement for '?'?
	jne	send2b			; ne = no
	mov	diskio.string,'?'	; yes. Change '#' for '?'
send2b:	or	ax,ax			; any text given?
	jz	send3			; z = no, prompt
	cmp	temp,0			; Mail or REMOTE PRINT command?
	jne	send5			; ne = yes, require address etc
	cmp	resend_flag,2		; PSEND command?
	jne	send2c			; ne = no
	call	sendpsnd		; parse bytes to skip
	jnc	send2c			; nc = success
	mov	dx,offset erms40	; say not a decimal number
	jmp	resend2			; fail the command

send2c:	mov	bx,offset auxfile     	; send file under different name?
	mov	dx,offset filhlp	; help
	mov	ah,cmline		; allow embedded white space
	call	comnd
	jnc	send2d			; nc = success
	ret				; failure
send2d:	or	ax,ax			; byte count, any?
	jz	send2e			; z = none
	cmp	auxfile,'#'		; first char a replacement for '?'?
	jne	send2e			; ne = no
	mov	auxfile,'?'		; change '#' to '?'
send2e:	jmp	send6			; join common completion code

send3:	mov	dx,offset lclfnm	; prompt for local filename
	call	prompt
	mov	bx,offset diskio.string ; reload destination of user's text
	mov	dx,offset filhlp	; help
	mov	ah,cmword		; get filename
	call	comnd			; try again for a local filename
	jnc	send3a			; nc = success
	ret				; failure
send3a:	cmp	diskio.string,'#'	; first char a replacement for '?'?
	jne	send3b			; ne = no
	mov	diskio.string,'?'	; yes. Change '#' for '?'
send3b:	push	ax
	call	sendpsnd		; get byte count
	jnc	send3d			; nc = got a number
	pop	ax			; clean stack
	mov	dx,offset erms40	; say not a decimal number
	jmp	resend2			; fail the command

send3d:	mov	ah,cmeol		; get the terminating CR
	call	comnd
	pop	ax
	jnc	send3c			; nc = success
	ret				; failure
send3c:	or	ax,ax			; user's byte count
	jz	send3			; z = nothing was typed, get some

send4:	mov	dx,offset remfnm	; ask for remote name first
	cmp	temp,0			; Mail command?
	je	send4a			; e = no
	mov	dx,offset mailto	; ask for name@host
	cmp	temp,2			; REMOTE PRINT?
	jne	send4a			; ne = no
	mov	dx,offset printpmt	; ask for host print parameters
send4a:	call	prompt
send5:	mov	bx,offset auxfile     	; send file under different name?
	mov	dx,offset filhlp	; help
	cmp	temp,0			; Mail command?
	je	send5a			; e = no
	mov	dx,offset mailtohlp	; help
	cmp	temp,2			; REMOTE PRINT?
	jne	send5a			; ne = no
	mov	dx,offset printas	; help for printer parameters
send5a:	mov	ah,cmline		; allow embedded white space
	call	comnd
	jnc	send5b			; nc = success
	ret				; failure
send5b:	cmp	temp,2			; REM Print cmd?
	je	send6			; e = yes, allow no parameters
	or	ax,ax			; text entered?
	jz	send4			; z = no, get some

send6:	mov	flags.xflg,0		; reset flag for normal file send[mtd]
	mov	sstate,0		; dummy state, must be illegal
	mov	ax,temp			; get temp mailflag
	mov	mailflg,al		; store in secure area for later
	mov	ah,trans.sdelay		; seconds to delay before sending
	shl	ah,1			; times 4*256 to get millisec
	shl	ah,1			;  for pcwait
	mov	al,1			; set low byte to 1 for no delay case
	call	pcwait			; wait number of millisec in ax	
SEND10:				; SEND10 is an entry point for REMote cmds
	mov	kstatus,kssuc		; global status, success
	mov	windflag,0		; init windows in use display flag
	mov	trans.windo,1		; one window slot before negotiations
	mov	cx,dspsiz		; default send pkt length (94)
	call	makebuf			; make some packet buffers
	call	clrbuf			; clear port buffer of old NAKs
	call	packlen			; compute packet length
	call	cxerr			; clear Last Error line
	call	cxmsg			; clear Last Message line
	mov	ax,offset diskio.string	; filename to send, can be wild
	mov	si,ax
	mov	di,offset vfile
	call	strcpy			; copy name to \v(filename) buffer
	cmp	diskio.string,'@'	; doing at-sign sending?
	jne	send10a			; ne = no
	inc	ax			; yes, skip the at-sign
send10a:call	isfile			; does file exist?
	jnc	send12			; carry reset = yes, file found
	cmp	sstate,'S'		; was this from a remote GET?
	jne	send11			; ne = no, print error and continue
	mov	dx,offset erms15	; file not found
	mov	trans.chklen,1		; send init checksum is always 1 char
	call	ermsg
	mov	bx,dx
	call	errpack			; go complain
	mov	sstate,'A'		; abort
	ret

send11:	mov	ah,prstr
	mov	dx,offset crlf
	int	dos
	mov	dx,offset erms15	; 'file not found'
	call	prtasz
	or	errlev,kssend		; set DOS error level
	or	fsta.xstatus,kssend	; set status
	mov	kstatus,kssend		; global status
	mov	mailflg,0		; clear Mail flag
	clc				; pretend successful completion
	ret

send12:	call	serini			; initialize serial port
	jnc	send13			; nc = success
	or	errlev,kssend		; say send failed
	or	fsta.xstatus,kssend	; set status
	mov	kstatus,kssend		; global status
	mov	dx,offset erms14	; no response from host
	call	ermsg			; show message
	stc				; return failure
	ret

send13:	xor	ax,ax
	mov	pktnum,al		; set the packet number to zero
	mov	fsta.pretry,ax 		; set the number of retries to zero
	mov	numpkt,ax		; number pkts send in this file group
	mov	flags.cxzflg,al
	mov	sstate,'S'		; set the state to send initiate
	mov	chkparflg,1		; check for unexpected parity
	call	ihostr			; initialize the host (clear NAKs)
	call	init			; clear screen and initialize buffers
	call	clrbuf			; clear serial port buffer of junk
	test	flags.remflg,dquiet+dserial ; quiet or serial display mode?
	jnz	send15			; nz = yes, suppress msgs
	call	stpos			; show status of file transfer
	mov	dx,offset infms1	; Sending in progress message
	cmp	mailflg,0		; Sending, vs Mailing?
	je	send14			; e = yes, sending
	mov	dx,offset infms2	; Mailing in progress message
send14:	mov	ah,prstr
	int	dos
send15:	mov	bx,offset diskio.string
	cmp	byte ptr [bx],'@'	; at-sign sending?
	jne	send16			; ne = no
	mov	si,bx			; get @filename
	mov	di,offset atfile+2	; destination worker
	call	strcpy			; copy name to holding place
	mov	word ptr atfile,0	; clear handle
	mov	atflag,1		; say doing atsign stuff
send16:	jmp	short dispatch		; sstate has initial state ('S')
SEND	ENDP

; worker for send to get Psend byte count after local filename
sendpsnd proc	near
	mov	dx,offset psndhlp2	; help
	mov	bx,offset rdbuf		; buffer
	mov	ah,cmword
	call	comnd
	jnc	sendps1
	ret
sendps1:mov	si,offset rdbuf
	mov	dx,si
	call	strlen
	jcxz	sendps3			; z = empty string (allowable)
	mov	domath_ptr,si
	mov	domath_cnt,cx
	call	domath			; convert numeric to binary
	jnc	sendps4			; nc = got a number
	ret				; c = failure to get a decimal number
sendps3:xor	dx,dx			; set number to zero
	xor	ax,ax
sendps4:mov	word ptr rdbuf+cmdblen-4,dx ; high word of lseek
	mov	word ptr rdbuf+cmdblen-2,ax ; low word of lseek
	clc
	ret
sendpsnd endp

dispatch proc	near			; Dispatch on state variable sstate
	mov	ah,sstate
	cmp	ah,'S'			; send initiate state?
	jne	dispat2			; ne = no
	call	sinit			; negotiate
	jmp	short dispatch

dispat2:cmp	ah,'F'			; file header state?
	jne	dispat3			; ne = no
	call	sfile			; send file header
	jmp	short dispatch

dispat3:cmp	ah,'a'			; send attributes state?
	jne	dispat4			; ne = no
	call	sattr			; send attributes
	jmp	short dispatch

dispat4:cmp	ah,'D'			; data send state?
	jne	dispat5			; ne = no
	call	sdata			; send data
	jmp	short dispatch

dispat5:cmp	ah,'Z'			; EOF state?
	jne	dispat6
	call	seof			; do EOF processing
	jmp	short dispatch

dispat6:cmp	ah,'B'			; end of file group state?
	jne	dispat7
	call	seot
	jmp	short dispatch

dispat7:cmp	ah,'E'			; user intervention ^C or ^E?
	jne	dispat8			; ne = no
	mov	bx,offset cemsg		; user intervention message
	call	errpack			; send error message
	call	intmsg			; show interrupt msg for Control-C-E

dispat8:push	ax    			; 'A' abort or 'C' completion
	pop	ax
	mov	mailflg,0		; clear Mail flag
	call	bufclr			; release all buffers
	mov	windlow,0
	mov	pktnum,0
	call	stpos			; show status of file transfer
	mov	dx,offset infms3	; Completed message
	cmp	sstate,'C'		; send complete state?
	je	dispat9			; e = yes, else failure
	mov	dx,offset infms4	; Failed message
	or	errlev,kssend		; say send failed
	or	fsta.xstatus,kssend	; set status
	mov	kstatus,kssend		; global status

dispat9:test	flags.remflg,dquiet+dserial ; quiet or serial display mode?
	jnz	dispa9a			; nz = yes, keep going
	mov	ah,prstr		; show completed/failed message
	int	dos
	mov	al,1			; underline cursor
	call	fcsrtype		; set IBM-PC cursor to underline
dispa9a:cmp	flags.cxzflg,0		; completed normally?
	je	dispa10			; e = yes
	or	errlev,kssend		; say send failed
	or	fsta.xstatus,kssend+ksuser ; set status, failed + intervention
	mov	kstatus,kssend+ksuser	; global status
dispa10:mov	ax,1		; tell statistics this was a send operation
	call	endtim			; stop statistics counter
	test	flags.remflg,dquiet	; quiet display mode?
	jnz	dispa13			; nz = yes, no talking
	call	filecps			; show file chars/sec
	call	intmsg			; show any interruption
	cmp	flags.belflg,0		; Bell desired?
	je	dispa13			; e = no
	mov	ah,prstr
	mov	dx,offset ender		; ring bells
	int	dos
dispa13:call	rprpos			; position cursor
	xor	al,al
	mov	flags.cxzflg,al		; clear flag for next command
	mov	auxfile,al		; clear send-as filename buffer
	mov	flags.xflg,al		; clear to-screen flag
	mov	diskio.string,al	; clear active filename buffer
	mov	fsta.xname,al		; clear statistics external name
	mov	resend_flag,al		; clear resend flag
	mov	delfile_flag,al		; clear delete file flag
	mov	atflag,al		; clear atfile sending
	mov	sendkind,al		; clear send recursive flag
	mov	decbuf,al		; clear these buffers
	mov	encbuf,al
	cmp	atfile,0		; atsign file still open?
	je	dispa14			; e = no
	mov	bx,word ptr atfile	; get handle
	mov	ah,close2
	int	dos
	mov	word ptr atfile,0	; clear handle
dispa14:
	clc
	ret				; return to main command parser
dispatch endp

; Enter with filespec in diskio.string, external name/mail address in auxfile

; Send Initiate packet
SINIT	PROC	NEAR
	mov	al,1			; say starting send operation
	mov	trans.windo,1		; one window slot before negotiations
	mov	cx,dspsiz		; default send pkt length (94)
	call	makebuf			; remake buffers for new windowing
	call	packlen			; compute packet length
	xor	ax,ax
	mov	windlow,al		; window lower border
	mov	pktnum,al		; sequence number to use
	mov	windflag,al		; windows in use display flag
	mov	al,dtrans.xchset	; reset Transmission char set
	mov	trans.xchset,al		;  to the current user default
	mov	al,dtrans.xtype		; ditto for File Type
	mov	trans.xtype,al
	call	getbuf			; get a buffer address into si
	call	sparmax			; set up our maximum capabilities
	call	rpar			; put them into the packet
	mov	trans.chklen,1		; Send init checksum is always 1 char
	mov	[si].pktype,'S'		; send-initiate packet
	call	sndpak			; send the packet
	jnc	sinit2			; nc = successful send
	ret				; failure, change state

sinit2:	mov	al,pktnum		; packet just sent
	mov	ah,maxtry		; normal retry threshold
	add	ah,ah
	add	ah,maxtry		; triple the normal threshold
	call	response		; get response
	jnc	sinit3			; nc = success
	ret

sinit3:	push	si			; ACK in window
	mov	si,offset rpacket	; point to packet for spar
	call	spar			; parse the received data
	pop	si
	cmp	streamok,0		; doing streaming?
	je	sinit3b			; e = no
	call	streampr		; put message on formatted screen
sinit3b:mov	cx,trans.slong		; negotiated send packet size
	call	makebuf			; remake buffers for new windowing
	call	packlen			; update max send packet size
	mov	pktnum,1		; next sequence number after 'S' pkts
	mov	windlow,1		; lowest acceptable sequence received
	cmp	mailflg,0		; non-zero to do Mail command
	je	sinit3a			; e = send, not mail command
	cmp	flags.attflg,0		; file attributes disabled?
	je	sinit5			; e = yes, so no Mail/Resend
	test	trans.capas,8		; can they do file attributes?
	jz	sinit5			; z = no, so cannot do Mail
	jmp	short sinit4
sinit3a:cmp	resend_flag,1		; doing resend?
	jne	sinit4			; ne = no
	cmp	flags.attflg,0		; file attributes disabled?
	je	sinit6			; e = yes, so no resend
	test	trans.capas,16		; can they do simple recovery?
	jz	sinit6			; z = no, so cannot do resend
	
sinit4:	call	getfil			; open the file
	jc	sinit4a			; c = error
	mov	filopn,1		; disk file is open
	mov	sstate,'F'		; set the state to file send
	ret

sinit4a:mov	dx,offset erms15	; file not found
	jmp	giveup			;  something is wrong, quit w/msgs
sinit5:	mov	dx,offset erms25	; say no Mail today
	jmp	giveup
sinit6:	mov	dx,offset erms39	; say no Resend
	jmp	giveup
SINIT	ENDP
 
; Send file header
; Enter with pktnum set for the next transmission, no buffer
 
SFILE	PROC	NEAR
	mov	al,1			; say starting send operation
	call	begtim			; start statistics
	cmp	filopn,1		; is file open already?
	je	sfile1			; e = yes
	call	bufrel			; release buffer for SI
	mov	dx,offset erms24	; cannot send packet
	jmp	giveup			; something is wrong, quit

sfile1:	mov	flags.cxzflg,0		; clear ^C, ^E, ^X, ^Z flag 
	call	getbuf			; get a packet buffer, address in si
	jnc	sfile2			; nc = got one
	mov	dx,offset erms27	; no buffers
	jmp	giveup			; tell both sides and fail

sfile2:	mov	dx,offset encbuf	; destination = encode source buffer
	call	strlen			; get length (w/o terminator) into cx
	call	doenc			; do encoding; length is in cx
	mov	[si].pktype,'F'		; File header packet
	cmp	flags.xflg,0		; REMOTE command? (goes to screen)
	je	sfile3			; e = no
	mov	[si].pktype,'X'		; use X rather than F for REMOTE cmds
sfile3:	call	sndpak			; send the packet
	jnc	sfile4			; nc = success
	ret

sfile4:	mov	al,pktnum		; want response for packet just sent
	mov	ah,maxtry		; retry threshold
	call	response		; get response
	jnc	sfile5			; nc = success (got an ACK)
	ret

sfile5:	call	ackmsg			; show any message in ACK
	inc	pktnum			; next pkt to send/rcv, from ackpak
	and	pktnum,3fh		; modulo 64
	call	filekind		; report file type, char set
	mov	current_max,60		; set current D packet length
	mov	ax,trans.maxdat		; negotiated max packet length
	cmp	ax,60			; starting D packet length
	jae	sfile5a			; larger
	mov	current_max,ax		; use smaller value
sfile5a:mov	sstate,'D'		; send data as the next state
	test	trans.capas,8		; can they do file attributes?
	jz	sfile6			; z = no, so cannot do attributes
	mov	sstate,'a'		; set file attributes as next state
sfile6:	ret				; return to do next state
SFILE	ENDP
 
; Send file attributes. Attributes: file size in bytes and kilobytes,
; file time and date, machine identification.
; Writes output to buffer encbuf.
SATTR	PROC	NEAR
	cmp	flags.attflg,0		; allowed to do file attributes?
	je	satt0			; e = no
	mov	attptr,offset attlist	; point at list of attributes procs
	test	trans.capas,8		; can we do file attributes?
	jnz	satt1			; nz = yes
satt0:	mov	sstate,'D'		; set the state to send-data
	ret

satt1:	mov	bx,attptr		; ptr to list of attributes procedures
	cmp	word ptr [bx],0		; at end of list?
	je	satt0			; e = yes, do next state
	call	getbuf			; get buffer for sending
	jnc	satt2			; nc = got one
	mov	dx,offset erms27	; no buffers
	jmp	giveup			; tell both sides and fail

satt2:	mov	di,offset encbuf	; address of a temp data buffer
	mov	byte ptr [di],0		; start with null terminator
	push	es			; save es around this work
	push	ds
	pop	es			; set es to data segment for es:di
	push	si
	mov	bx,attptr		; ptr to list of attributes routines
	mov	bx,[bx]			; de-reference one level
	call	bx			; do it
	pop	si
	pop	es
	mov	byte ptr [di],0		; insert null terminator in temp buf
	mov	dx,offset encbuf
	call	strlen			; get length of this attribute to CX
	cmp	cx,trans.maxdat		; longer than any packet?
	jbe	satt3			; be = no, proceed
	xor	cx,cx			; skip the attribute

satt3:	mov	ax,[si].datlen		; data length for packet, so far
	add	ax,cx			; plus, maybe, this contribution
	cmp	ax,trans.maxdat		; new info fits into packet?
	jg	satt4			; g = no, send what we have
	push	si			; preserve packet structure pointer
	push	es
	les	di,[si].datadr		; packet buffer beginning
	add	di,[si].datlen		; plus current contents
	add	[si].datlen,cx		; say adding this many bytes
	mov	si,offset encbuf	; temp buffer is source of new info
	cld				; packet buffer is destination
	rep	movsb			; copy new material to packet buffer
	pop	es
	pop	si
	add	attptr,2		; next attributes procedure address
	mov	bx,attptr
	cmp	word ptr [bx],0		; at end of list?
	jne	satt2			; ne = no, do next attribute proc
	cmp	[si].datlen,0		; any data to send?
	jne	satt4			; ne = yes
	call	bufrel			; release the unused buffer
	mov	sstate,'D'		; set the state to send-data
	ret

satt4:	call	sndatt			; send attributes packet, get response
	jc	satt5			; c = failure
	jmp	satt1			; get new buffer, do more attributes
satt5:	ret				; failure, change state

					; Send Attributes packet, local worker
sndatt:	mov	[si].pktype,'A'		; Attributes packet
	call	sndpak			; send the packet
	jnc	sndat1			; nc = success
	ret
sndat1:	mov	al,pktnum		; get response for packet just sent
	mov	ah,maxtry		; retry threshold
	call	response		; get response
	jnc	sndat2			; nc = success
	ret

sndat2:	inc	pktnum			; sent and ack'd, next seqnum to use
	and	pktnum,3fh
	cmp	rpacket.datlen,0	; any data in the ACK?
	je	sndat3			; e = no
	push	es
	les	bx,rpacket.datadr	; received data field
	mov	al,es:[bx]		; response
	inc	bx			; point to next field
	cmp	al,'N'			; are they refusing this file?
	pop	es
	je	sndat4			; e = yes, 'N' = refusing the file
sndat3:	cmp	resend_flag,1		; psend/resend?
	jb	sndat3b			; b = no
	je	sndat3c			; e = resend not psend
	xor	dx,dx			; Psend, get some zeros
	xor	ax,ax
	xchg	dx,word ptr rdbuf+cmdblen-4 ; lseek in this far
	xchg	ax,word ptr rdbuf+cmdblen-2 ; and clear this lseek
	jmp	short sndat3a
sndat3c:cmp	al,'1'			; ACK has remote file length?
	jne	sndat3b			; ne = no
	call	getas			; get file size from ACK to DX:AX
	cmp	dx,diskio.sizehi	; remote larger than local?
	jb	sndat3a			; b = remote is smaller (expected)
	ja	sndat3d			; a = remote larger, go to eof
	cmp	ax,diskio.sizelo	; low byte too large?
	jbe	sndat3a			; be = no
sndat3d:mov	dx,diskio.sizehi	; remote is larger, lseek to eof
	mov	ax,diskio.sizelo

sndat3a:mov	bx,diskio.handle	; file handle for seeking
	mov	word ptr tfilsz,ax	; statistics, start file bytes here
	mov	word ptr tfilsz+2,dx
	mov	cx,dx			; high order displacement
	mov	dx,ax			; low order part of displacement
	mov	ah,lseek		; seek
	xor	al,al			; from start of file
	int	dos
sndat3b:clc				; say success
	ret
					; display file refusal reason
sndat4:	or	fsta.xstatus,kssend+ksattrib ; set status, failed, attributes
	or	kstatus,kssend+ksattrib	; global status, failed, attributes
	mov	fsta.xstatus2,0ffh	; dummy "unknown" attribute code
	test	flags.remflg,dquiet	; quiet display?
	jnz	sndat4a			; nz = yes
	mov	dx,offset erms26	; say host rejected the file 
	call	ermsg
sndat4a:mov	cx,rpacket.datlen	; display all reasons
sndat5:	dec	cx			; next byte
	cmp	cx,0			; anything there?
	jle	sndat7			; b = no
	push	es
	mov	es,word ptr rpacket.datadr+2	; received data field seg
	mov	ah,es:[bx]		; reason code
	inc	bx			; point to next field
	pop	es
	mov	fsta.xstatus2,ah	; save attribute code for status
	mov	dx,offset ferbyte	; ah has reason code from above
	cmp	ah,'1'			; Byte count?
	je	sndat6			; e = yes
	cmp	ah,'!'			; Kilobyte count?
	je	sndat6
	mov	dx,offset ferdate
	cmp	ah,'#'			; Date and Time?
	jne	sndat5a			; ne = no
	mov	kstatus,kssuc		; remove error status, keep xstatus
	mov	fsta.xstatus,kssuc	; for transaction log
	mov	flags.cxzflg,0		; clear flag
	jmp	short sndat6
sndat5a:mov	dx,offset ferdisp
	cmp	ah,'+'			; Disposition?
	je	sndat6			; e = yes
	mov	dx,offset fertype
	cmp	ah,'"'			; File Type?
	je	sndat6
	mov	dx,offset ferchar
	cmp	ah,'*'			; Transfer Char-set?
	je	sndat6
	mov	dx,offset fername
	cmp	ah,'?'	       		; filename collision?
	je	sndat6			; e = yes
	mov	dx,offset ferunk	; unknown reason
sndat6:	test	flags.remflg,dquiet	; quiet display?
	jnz	sndat5			; nz = yes
	call	prtasz			; display reason
	jmp	sndat5			; do any other reasons
sndat7:	mov	sstate,'Z'		; send EOF
	stc
	ret

; Individual attribute routines. Each expects DI to point to a free storage
; byte in an output buffer and it updates DI to the next free byte. Expects
; ES to be pointing at the data segment. OK to clobber SI here.

sat1t:	test	flags.attflg,attlen	; can we send length attribute?
	jz	sat1tx			; z = no
	mov	si,di			; remember starting location
	mov	byte ptr [di],'1'	; file length (Bytes) specifier
	mov	dx,diskio.sizehi	; high word of length
	mov	ax,diskio.sizelo	; low word of length
	add	di,2
	call	lnout			; convert file length, write to [di++]
	mov	cx,di			; compute field length
	sub	cx,si
	sub	cx,2
	add	cl,32			; field length to ascii
	mov	[si+1],cl		; length. Done with File Size
sat1tx:	ret
					; Kilobyte attribute
sat2t:	test	flags.attflg,attlen	; can we send length attribute?
	jz	sat2tx			; z = no
	mov	byte ptr[di],'!'	; file length (Kilobytes) specifier
	inc	di
	mov	temp4,di		; remember place for count field
	inc	di			; data field
	mov	dx,diskio.sizehi	; high word of length, from file open
	mov	ax,diskio.sizelo	; low word of length
	add	ax,1023			; add 1023 to round up
	adc	dx,0
	mov	al,ah			; do divide by 1024 bytes
	mov	ah,dl
	mov	dl,dh			; divide by 256 part
	xor	dh,dh
	ror	dl,1			; low bit to carry flag
	rcr	ax,1			; divide by two, with carry in
	clc
	ror	dl,1			; low bit to carry flag
	rcr	ax,1			; divide by two, with carry in
	and 	dl,3fh			; keep low six bits
	call	lnout			; convert file length
	mov	cx,di			; compute field length
	sub	cx,temp4		; count field location
	add	cl,32-1			; field length to ascii
	push	di
	mov	di,temp4		; point at count field
	mov	[di],cl			; store field length
	pop	di			; Done with Kilobyte attribute
sat2tx:	ret

sat3t:	test	flags.attflg,attdate	; can we send file date and time?
	jnz	sat3t1			; nz = yes
	ret
sat3t1:	cld				; file Date and Time
	mov	al,'#'			; creation date/time specifier
	stosb				; and point at field length
	mov	al,17+32		; length of date/time field, to ascii
	stosb
	mov	bx,offset diskio.dta	; setup data pointer
	call	filetdate		; do the work
	ret

sat4t:	test	flags.attflg,attsys	; can we send system ident?
	jz	sat4t1			; z = no
	mov	ax,'".'			; machine indicator(.), 2 data bytes
	cld
	stosw
	mov	ax,'8U'			; U8 = Portable O/S, MSDOS
	stosw
sat4t1:	ret

sat5t:	cmp	mailflg,0		; Mailing or REMOTE PRINTing?
	jne	sat5t1			; ne = yes
	cmp	resend_flag,1		; Resend?
	jne	sat5ta			; ne = no
	mov	ax,'!+'			; say +!Resend
	stosw				; store and point to next field
	mov	al,'R'
	stosb
sat5ta:	ret

sat5t1:	mov	byte ptr [di],'+'	; Disposition specification
	inc	di
	mov	dx,offset auxfile	; user@host or print param field
	call	strlen			; get length into cl
	push	cx			; save address length
	inc	cl			; include disposition letter M or P
	add	cl,' '			; add ascii bias
	mov	[di],cl			; store in length field
	inc	di
	mov	byte ptr [di],'M'	; mail the file
	cmp	mailflg,2		; REMOTE PRINT?
	jne	sat5t2			; ne = no
	mov	byte ptr [di],'P'	; say disposition is Print
sat5t2:	inc	di
	pop	cx			; recover address length
	jcxz	sat5tx			; z = empty field
	mov	si,dx			; parameter field
	cld
	rep	movsb			; append address text to field
sat5tx:	ret

sat6t:	test	flags.attflg,atttype	; can we send File Type attribute?
	jz	sat6tx			; z = no
	mov	al,'"'			; File Type attribute (")
	cld
	stosb
	cmp	trans.xtype,0		; Text?
	jne	sat6t1			; ne = no, likely Binary
	mov	al,3+20h		; three bytes follow
	stosb
	mov	al,'A'			; A for ascii
	stosb
	mov	ax,'JM'			; using Control-M and Control-J
	stosw				; as line delimiters
	ret
sat6t1:	mov	al,2+20h		; two bytes follow
	stosb
	mov	ax,'8B'			; "B8" = Binary, 8-bit byte literals
	stosw
sat6tx:	ret

sat7t:	test	flags.attflg,attchr	; Character-set allowed?
	jz	sat7tx			; z = no
	cmp	trans.xtype,1		; Binary?
	je	sat7tx			; e = yes, no char-set stuff
	mov	al,'*'			; Encoding strategy
	cld
	stosb
	mov	al,1+20h		; length following, say one char
	stosb
	mov	al,'A'			; assume normal Transparent
	stosb
	cmp	dtrans.xchset,xfr_xparent ; is it transparent?
	je	sat7tx			; e = yes
	mov	al,'C'			; say transfer char-set encoding
	dec	di			; replace 'A' with 'C'
	stosb
	push	bx
	mov	bl,dtrans.xchset	; get def char set index
	xor	bh,bh
	shl	bx,1			; count words
	mov	bx,charids[bx+2]	; bx points at set [length, string]
	mov	al,[bx]			; get length of ident string
	mov	cl,al			; copy to loop counter
	xor	ch,ch
	inc	al			; add 'C' in attribute
	add	al,20h			; length of string + ascii bias
	mov	byte ptr [di-2],al	; length of attribute
	push	si
	mov	si,bx			; ident string length byte
	inc	si			; text of ident string
	cld
	rep	movsb			; copy to destination
	pop	si
	pop	bx
sat7tx:	ret

sat99t:	mov	word ptr [di],' @'	; End of Attributes ("@ " in pkt)
	add	di,2			; must be last attribute sent
	ret

getas:	push	es
	les	bx,rpacket.datadr	; received data field
	inc	bx			; skip "1"
	mov	cl,es:[bx]		; length of file size field
	inc	bx			; point at file size data
	sub	cl,' '			; remove ascii bias
	xor	ch,ch
	xor	ax,ax			; current length, bytes
	xor	dx,dx
	jcxz	getas3			; z = empty field
getas2:	push	cx
	shl	dx,1			; high word of size, times two
	mov	di,dx			; save
	shl	dx,1
	shl	dx,1			; times 8
	add	dx,di			; yields dx * 10
	mov	di,dx			; save dx
	xor	dx,dx
	mov	cx,10			; also clears ch
	mul	cx			; scale up previous result in ax
	mov	cl,es:[bx]		; get a digit
	inc	bx
	sub	cl,'0'			; remove ascii bias
	add	ax,cx			; add to current length
	adc	dx,0			; extend result to dx
	add	dx,di			; plus old high part
	pop	cx
	loop	getas2
getas3:	pop	es
	clc
	ret

SATTR	ENDP

;	Send data
; Send main body of file, 'D' state

SDATA	PROC	NEAR
	cmp	flags.cxzflg,0		; interrupted?
	je	sdata1			; e = no
	mov	sstate,'Z'		; declare EOF, analyze interrupt there
	ret

sdata1:	call	getbuf			; get a buffer for sending
	jnc	sdata2			; nc = success
	mov	al,windlow		; earliest sequence number sent
	mov	ah,maxtry		; retry threshold
	jmp	response		; can't send, try getting responses

sdata2:	mov	[si].pktype,'D'		; send Data packet
	push	trans.maxdat		; negotiated max packet length
	mov	ax,current_max		; running max
	mov	trans.maxdat,ax		; for encoder
	call	gtchr			; fill buffer from file and encode
	pop	trans.maxdat		; recover negotiated max pkt
	jc	sdata3			; c = failure (no data/EOF, other)
	cmp	[si].datlen,0		; read any data?
	je	sdata3			; e = end of data, send 'Z' for EOF
	call	sndpak			; send the packet
	inc	pktnum			; next sequence number to send
	and	pktnum,3fh		; modulo 64
sdata2a:call	peekresponse		; look for responses between pkts
	jnc	sdata2a			; nc = got a response, get another
	clc				; return successful
	ret

sdata3:	call	bufrel			; release unused buffer
	mov	sstate,'Z'		; at End of File, change to EOF state
	ret
SDATA	ENDP

; Send EOF, 'Z' state
SEOF	PROC	NEAR
	call	getbuf			; get a buffer for EOF packet
	jnc	seof1			; nc = got one, send 'Z' packet
	mov	al,pktnum		; seqnum of next packet to be used
	dec	al			; back up to last used
	and	al,3fh			;  sequence number of last sent pkt
	mov	ah,maxtry		; retry threshold
	jmp	response		; get responses to earlier packets

seof1:	xor	cx,cx			; assume no data
	cmp	flags.cxzflg,0		; interrupted?
	je	seof3			; e = no, send normal EOF packet
	call	intmsg			; say interrupted
	mov	encbuf,'D'		; Use "D" for discard
	mov	cx,1			; set data size to 1
	or	errlev,kssend		; say send failed
	or	fsta.xstatus,kssend+ksuser ; set status, failed + intervention
	mov	kstatus,kssend+ksuser	; global status
seof3:	call	doenc			; encode the packet (cx = count)
	mov	[si].pktype,'Z'		; EOF packet
	call	sndpak			; send the packet
	jnc	seof6			; nc = success
	ret

seof6:	mov	al,[si].seqnum		; packet just sent
	mov	ah,maxtry		; retry threshold
	call	response		; get reponse
	jnc	seof7			; nc = success
	ret

seof7:	call	ackmsg			; ACK, get/show any embedded message
	inc	pktnum			; next sequence number to send
	and	pktnum,3fh		; modulo 64
					; Heuristic: ACK to 'Z' implies
	mov	al,windlow		;  ACKs to all previous packets
	mov	ah,pktnum		; loop limit, next packet
seof8:	cmp	al,ah			; done all "previous" packets?
	je	seof8b			; e = yes
	call	pakptr			; access packet for seqnum in AL
	jc	seof8a			; c = not in use
	mov	si,bx			; point to it
	call	bufrel			; release old buffer (synthetic ACK)
seof8a:	inc	al			; next slot
	and	al,3fh
	jmp	short seof8
seof8b:					; end of Heuristic
	mov	al,pktnum
	mov	windlow,al		; update windlow to next use
	mov	ah,close2		; close file
	mov	bx,diskio.handle	; file handle
	int	dos
					; MOVE/RETRIEVE
	cmp	delfile_flag,0		; delete file after transfer
	je	seof8c			; e = no
	mov	dx,offset diskio.string	; original file spec (may be wild)
	mov	di,offset templp	; place for path part
	mov	si,offset templf	; place for filename part
	call	fparse			; split them
	mov	si,offset diskio.fname	; current filename from DOS
	call	strcat			; (di)= local path + diskio.fname
	mov	dx,di
	mov	ah,del2			; delete the file
	int	dos

seof8c:	mov	filopn,0		; no files open
	call	logtransact		; log transaction
	cmp	flags.cxzflg,0		; interrupted?
	je	seof9			; e = no
	or	errlev,kssend		; say send failed
	or	fsta.xstatus,kssend+ksuser ; set status, failed + intervention
	mov	kstatus,kssend+ksuser	; global status
	cmp	flags.cxzflg,'Z'	; Control-Z seen?
	jne	seof9			; ne = no
	mov	flags.cxzflg,0		; clear the Control-Z
	mov	auxfile,0		; clear send-as/mail-address buffer
	mov	sstate,'B'		; file group complete state
	ret
seof9:	cmp	flags.cxzflg,0		; interrupted?
	je	seof10			; e = no
	cmp	flags.cxzflg,'X'	; was Control-X signaled?
	je	seof10			; e = yes
	mov	sstate,'E' 		; not ^X/^Z, must be ^C/^E
	ret
seof10:	mov	flags.cxzflg,0		; clear the Control-X
	cmp	mailflg,0		; mail?
	jne	seof11			; e = yes, retain address in auxfile
	mov	auxfile,0		; clear send-as name
seof11:	call	GTNFIL			; get the next file
	jc	seof12			; c = no more files, do end of group
	mov	filopn,1		; file opened by gtnfil
	mov	sstate,'F'		; set state to file header send
	ret
seof12:	mov	sstate,'B'		; set state to file group completed
	ret
SEOF	ENDP
 
 
; Send EOT
 
SEOT	PROC	NEAR
	call	getbuf			; get a buffer for sending
	jnc	seot1			; nc = got one
	mov	al,pktnum		; next sequence number to use
	dec	al			; back up to last used
	and	al,3fh			; get response to what was just sent
	mov	ah,maxtry		; retry threshold
	jmp	response		; get response, stay in this state

seot1:	mov	[si].pktype,'B'		; End of Session packet
	call	sndpak			; send the packet
	jnc	seot2			; nc = sucess
	ret
seot2:	mov	al,pktnum		; sequence number just sent
	mov	ah,maxtry		; retry threshold
	call	response		; get a response to it
	jnc	seot3			; nc = success
	ret
seot3:	call	ackmsg			; get/show any embedded message
	inc	pktnum			; next sequence number to use
	and	pktnum,3fh		; modulo 64
	mov	sstate,'C'		; set state to file completed
	ret
SEOT	ENDP

; Look for a returned response, but don't block on packet reader timeouts
; while waiting for a packet to start. Either reads and processes the packet
; or changes state on quit signal or does nothing. Returns carry set if
; no packet or error state, else returns what "response" does.
peekresponse proc near
	push	si			; preserve regular packet pointer
	mov	si,offset rpacket	; address of receive packet structure
	call	peekreply		; see if there is a reply
	pop	si
	jc	peekres1		; c = no packet
	mov	tempseq,-1		; target sequence number, -1=any
	mov	al,maxtry		; retry threshold
	mov	retry,al
	jmp	resp4			; nc = have packet, go analyze

peekres1:cmp	flags.cxzflg,'C'	; Control-C typed?
	je	peekres2		; e = yes, quit
	cmp	flags.cxzflg,'E'	; Control-E typed?
	jne	peekres3		; ne = no
peekres2:mov	sstate,'E'		; change to Error state
peekres3:stc				; return saying no packet
	ret
peekresponse endp

; Get response to seqnum in AL, retry AH times if necessary.
; Success: return carry clear and response data in rpacket
; Failure: return carry set and new state in sstate, will send Error packet
; Changes AX, BX, CX
response proc	near
	mov	tempseq,al		; target sequence number
	mov	retry,ah		; retry threshold
	mov	rpacket.numtry,0	; no receive retries yet
resp1:	cmp	streamok,0		; negotiated streaming?
	je	resp1a			; e = no
	cmp	sstate,'D'		; in Data state?
	je	resp8			; e = yes, no ACK/NAKs
resp1a:	mov	ah,rpacket.numtry	; number of attempts in this routine
	cmp	ah,retry		; done enough?
	ja	resp3			; yes, feign a timeout
	push	si			; preserve regular packet pointer
	mov	si,offset rpacket	; address of receive packet structure
	call	rpack			; get a packet
	pop	si
	jnc	resp4			; nc = success
	cmp	flags.cxzflg,'C'	; Control-C typed?
	je	resp2			; e = yes, quit
	cmp	flags.cxzflg,'E'	; Control-E typed?
	jne	resp3			; ne = no
resp2:	mov	sstate,'E'		; change to Error state
	stc				; return failure
	ret

resp3:	cmp	tempseq,-1		; just shopping (accept any, no retry)?
	jne	resp3e			; ne = no
	stc				; say failed to receive, don't retry
	ret
resp3e:	inc	rpacket.numtry		; no packet received, resend oldest
	shl	k_rto,1			; double timeout
	cmp	k_rto,60 * 18 * 3	; limit to 3 min
	jbe	resp3e1			; be = within limits
	mov	k_rto,60 * 18 * 3	; at limit
resp3e1:call	shrink			; shrink new packet size
	mov	al,windlow		; get oldest sequence number
resp3a:	call	pakptr			; get packet pointer to seqnum in AL
	jnc	resp3b			; nc = ok, sequence number is in use
	clc				; packet not in use, simulate success
	ret

resp3b:	push	si			; resend oldest packet
	dec	numpkt			; a retry is not a new packet sent
	mov	si,bx			; packet pointer, from pakptr
	call	windshrink
	call	cntretry		; count retries, sense ^C/^E
	jnc	resp3c			; nc = ok to continue
	pop	si			; clean stack
	ret				; ^C/^E encountered, change states

resp3c:	mov	al,[si].numtry		; times this packet was retried
	cmp	al,retry		; reached the limit?
	jbe	resp3d			; be = no, can do more sends
	pop	si			; clean stack
	mov	dx,offset erms17	; to many retries
	jmp	giveup			; abort with msgs to local and remote

resp3d:	mov	rpacket.numtry,0
	call	sndpak			; resend the packet
	pop	si			; clean stack
	jnc	resp1			; nc = success, retry getting response
	ret
				; this point is also called by peekresponse
RESP4:	call	acknak			; got packet, get kind of response
	jnc	resp4c			; nc = no abort in progress
	ret				; return carry set
resp4c:	cmp	streamok,0		; negotiated streaming?
	je	resp4d			; e = no
	cmp	sstate,'D'		; in Data state?
	jne	resp4d			; ne = no
	cmp	al,1			; NAK in window?
	je	resp4f			; e = yes, quit
	cmp	al,3			; NAK out of window?
	jne	resp8			; ne = no, ignore packet
resp4f:	mov	sstate,'E'		; error state, quit
	stc
	ret

resp4d:	or	al,al			; ACK in window?
	jz	resp8			; z = yes
	cmp	al,1			; NAK in window?
	je	resp6			; e = yes, repeat pkt
	cmp	al,3			; NAK out of window?
	je	resp5			; e = yes, repeat packet
	cmp	al,4			; ACK to inactive packet?
	jne	resp4e			; ne = no
;;
	jmp	resp1			; old ACK, ignore it
; the above is to accomodate "book Kermits", not a good strategy, but...
;;	inc	rpacket.numtry		; count tries on reception
;;	jmp	resp1			; e = yes, retry reception
resp4e:	cmp	al,5			; NAK to inactive packet?
	jne	resp4a			; ne = no, leaves "other" types
	jmp	resp1			; ignore NAK, try again
					; other packet types
resp4a:	cmp	rpacket.pktype,'M'	; Message packet?
	jne	resp4b			; ne = no
	push	si
	mov	si,offset rpacket
	call	msgmsg			; display it and discard
	pop	si
	jmp	resp1			; retry getting an ACK

resp4b:	jmp	resp1			; Unknown packet type, ignore it

resp5:	cmp	trans.windo,1		; is windowing off?
	je	resp5a			; e = yes, use old heuristic
	call	shrink			; shrink new packet size

	call	nakout			; NAK rcvd outside window, resend all
	inc	rpacket.numtry		; count this as an internal retry
	jmp	resp1			; get more responses
	
resp5a:	mov	al,rpacket.seqnum	; NAK rcvd outside window, say NAK is
	dec	al			;  ACK for preceeding pkt to satisfy
	and	al,3fh			;  non-windowing Kermits
	mov	rpacket.seqnum,al	; force seqnum to preceed this NAK
	mov	rpacket.pktype,'Y'	; force packet to look like an ACK
	jmp	short resp4		; reanalyze our status

resp6:	mov	al,rpacket.seqnum	; single sequence number being NAK'd
	inc	rpacket.numtry		; count this as an internal retry
	call	shrink			; shrink new packet size
	jmp	resp3a			; repeat that packet

					; ACK in window
resp8:	call	grow			; grow new packet size
	cmp	streamok,0		; negotiated streaming?
	je	resp8c			; e = no
	cmp	sstate,'D'		; in Data state?
	jne	resp8c			; ne = no
	mov	tempseq,-1		; wanted sequence number, any
resp8c:	mov	al,windlow		; try to purge all ack'd packets
	call	pakptr			; get buffer pointer for it into BX
	jc	resp8a			; c = buffer not in use
	cmp	streamok,0		; negotiated streaming?
	je	resp8d			; e = no
	cmp	sstate,'D'		; in Data state?
	jne	resp8d			; ne = no
	mov	[bx].ackdone,1		; simulate ACK
resp8d:	cmp	[bx].ackdone,0		; ack'd yet?
	je	resp8a			; e = no, stop here
	mov	si,bx
	call	bufrel			; ack'd active buffer, release si
	inc	al			; rotate window
	and	al,3fh
	mov	windlow,al
	cmp	streamok,0		; negotiated streaming?
	je	resp8			; e = no
	cmp	sstate,'D'		; in Data state?
	je	resp8b			; e = yes, no ACK/NAKs
	jmp	short resp8		; keep purging

resp8a:	mov	al,tempseq		; check for our desired seqnum
	mov	rpacket.numtry,0
	cmp	al,-1			; do not check for match?
	je	resp8b			; e = yes
	cmp	al,rpacket.seqnum	; is this the desired object?
	je	resp8b			; e = yes
	jmp	resp1			; no, read another response
resp8b:	call	windgrow		; grow window size
	clc				; return success
	ret
response endp

; Send packet, with retries
; Enter with SI pointing to packet structure. Success returns carry clear.
; Failure, after retries, returns carry set and perhaps a new sstate.
sndpak	proc	near			
	inc	numpkt			; number packets sent
	call	pktsize			; report packet qty and size
	mov	sndcnt,0		; send retry counter, internal
	cmp	[si].pktype,'I'		; do not show windows for I/S
	je	sndpa3
	cmp	[si].pktype,'S'
	je	sndpa3
	call	winpr			; show windows in use

sndpa3:	call	spack			; send the packet
	jc	sndpa4			; nc = failure
	ret				; return success

sndpa4:	cmp	cardet,1	; Carrier detect, was on and is now off?
	je	sndpa5			; e = yes, fail without retries
	push	ax			; failure, do several retries
	mov	ax,100			; wait 0.1 seconds
	call	pcwait
	call	cntretry		; show retries on screen
	inc	sndcnt			; internal retry counter
	mov	al,sndcnt
	cmp	al,maxtry		; reached retry limit?
	pop	ax
	jbe	sndpa3			; be = no, can do more retries
sndpa5:	mov	dx,offset erms24	; cannot send packet
	jmp	giveup			; set carry, change state
sndpak	endp

; Check the packet rpacket for an ACK, NAK, or other.
; Returns in CX:
; 0 for ACK to active packet (marks buffer as ACK'd, may rotate window)
; 1 for NAK to active packet
; 2 for an unknown packet type
; 3 for NAK outside the window
; 4 for other ACKs (out of window, to inactive packet)
; 5 for NAKs in window to inactive packets.
; Timeout packet (type 'T') is regarded as a NAK out of the window.
; Marks pkts ACK'd but clears packets only when they rotate below the window.
; Uses registers AX ,BX, and CX.
ACKNAK	PROC	NEAR
	mov	al,rpacket.seqnum	; this packet's sequence number
	mov	ah,rpacket.pktype	; and packet type
	cmp	ah,'Y'			; ack packet?
	jne	ackna2			; ne = no
	call	ackdata			; get control data, for any seq number
	jnc	ackna0			; nc = no protocol command
	ret				; return carry set on protocol abort
ackna0:	call	pakptr			; is it for an active buffer?
	jnc	ackna1			; nc = yes
	mov	al,4			; say ACK for inactive pkt
	clc
	ret
ackna1:	mov	[bx].ackdone,1		; say packet has been acked
	cmp	[bx].numtry,0		; repeated?
	jne	ackna1a			; ne = yes, don't time events
	push	si
	mov	si,bx			; works with si as pkt ptr
	call	krto			; compute updated round trip timeout
	pop	si
ackna1a:cmp	al,windlow		; ok to rotate window?
	jne	ackna1b			; ne = no
	inc	windlow			; rotate window one slot
	and	windlow,3fh
	push	si			; save pointer
	mov	si,bx			; packet pointer from pakptr
	call	bufrel			; release buffer for SI
	pop	si
ackna1b:xor	al,al			; ack'd ok
	clc
	ret
					; not an ACK
ackna2:	cmp	ah,'N'			; NAK?
	je	ackna3			; e = yes
	cmp	ah,'T'			; Timeout?
	je	ackna3a			; e = yes, same as NAK out of window
	cmp	rpacket.pktype,'E'	; Error packet?
	jne	ackna2a			; ne = no
	call	error			; protocol abort, sets carry
	ret				; return carry set
ackna2a:mov	al,2			; else say unknown type
	clc
	ret

ackna3:	inc	fsta.nakrcnt		; count received NAK for statistics
	push	si
	mov	si,offset rpacket
	call	chkwind			; check if seqnum is in window
	pop	si
	jcxz	ackna3b			; z = in window
ackna3a:mov	al,3			; say NAK out of window
	clc
	ret

ackna3b:push	bx			; NAK in window, is pkt still active?
	call	pakptr			; seqnum for an active packet?
	pop	bx
	jc	ackna4			; c = no, ignore NAK as "dead NAK" 
	mov	al,1			; say NAK for active packet
	clc
	ret

ackna4:	mov	al,5			; dead NAKs
	clc
	ret
ACKNAK	ENDP

; Find protocol control byte in ACKs and change state if found
; Packet is in rpacket structure
; Returns carry clear of no control, else carry set
ackdata	proc	near
	cmp	sstate,'F'		; in file header state?
	je	ackdat3			; e = yes, no protocol char
	push	es
	les	bx,rpacket.datadr	; look for data in the ACK
	mov	ah,es:[bx]
	pop	es
	cmp	ah,'C'			; Control-C message?
	je	ackdat1			; e = yes
	cmp	ah,'X'			; quit this file?
	je	ackdat1			; e = yes
	cmp	ah,'Z'			; quit this file group?
	jne	ackdat3
ackdat1:mov	flags.cxzflg,ah		; store here
	mov	sstate,'Z'		; move to end of file state
	mov	rstate,'Z'
ackdat2:stc
	ret
ackdat3:clc
	ret
ackdata	endp

nakout	proc	near			; NAK out of window, resend all pkts
	mov	al,windlow		; start here
	mov	ah,al
	add	ah,trans.windo
	and	ah,3fh			; top of window+1
nakout1:call	pakptr			; get pkt pointer for seqnum in al
	jc	nakout4			; c = slot not in use
	mov	si,bx			; bx is packet pointer from pakptr
	cmp	[si].ackdone,0		; has packet has been acked?
	jne	nakout4			; ne = yes
	cmp	al,windlow		; count retries only for windlow
	jne	nakout2			; ne = not windlow
	call	windshrink		; shrink window
	call	cntretry		; count retries
	jc	nakout3			; c = quit now
	mov	cl,[si].numtry
	cmp	cl,retry		; reached the limit yet?
	ja	nakout3			; a = yes, quit
nakout2:push	ax
	call	pktsize			; report packet size
	call	sndpak			; resend the packet
	pop	ax
	jmp	short nakout4		; do next packet

nakout3:mov	dx,offset erms17	; error exit, too many retries
	jmp	giveup

nakout4:inc	al			; next sequence number
	and	al,3fh
	cmp	al,ah			; sent all packets?
	jne	nakout1			; ne = no, repeat more packets
	ret				; return to do another data send
nakout	endp

cntretry proc	near			; count retries, sense user exit
	cmp	flags.cxzflg,'C'	; user wants abrupt exit?
	je	cntre2			; e = yes
	cmp	flags.cxzflg,'E'	; Error type exit?
	je	cntre2			; e = yes
	inc	fsta.pretry		; increment the number of retries
	inc	[si].numtry		; for this packet too
	test	flags.remflg,dserver	; server mode?
	jnz	cntre3			; nz = yes, writing to their screen
	cmp	flags.xflg,1		; writing to screen?
	je	cntre1			; e = yes, skip this
cntre3:	cmp	fmtdsp,0		; formatted display?
	je	cntre1			; e = no
	call	rtmsg			; display retries
cntre1:	clc
	ret
cntre2:	mov	sstate,'E'		; abort, shared by send and receive
	mov	rstate,'E'		; abort
	stc
	ret
cntretry endp

; Display message in ACK's to F and D packets. Requires a leading protocol
; char for D packets and expects message to be encoded.
ackmsg	proc near
	test	flags.remflg,dquiet	; quiet display mode?
	jnz	ackmsgx			; nz = yes, don't write to screen
	cmp	rpacket.datlen,0	; any embedded message?
	je	ackmsgx			; e = no
	cmp	sstate,'F'		; file header state?
	je	ackmsg1			; e = yes, no leading protocol char
	cmp	rpacket.datlen,1	; D packet, skip protocol char
	je	ackmsgx			; e = no displayable information
ackmsg1:push	si
	push	ax
	push	dx
	call	cxmsg			; clear message space in warning area
	mov	word ptr decbuf,0	; clear two bytes
	mov	si,offset rpacket	; source address
	call	dodec			; decode message, including X/Z/other
	mov	dx,offset decbuf+1	; decoded data
	cmp	sstate,'F'		; file header state?
	jne	ackmsg3			; ne = no
	push	dx
	mov	dx,offset infms5	; give a leader msg
	call	prtasz
	pop	dx
	dec	dx			; start with first message char
ackmsg2:mov	bx,dx
	cmp	byte ptr [bx],' '	; space?
	jne	ackmsg3			; ne = no
	inc	dx			; next msg char
	jmp	short ackmsg2		; continue stripping off spaces
ackmsg3:call	prtasz			; display message
	mov	ah,prstr
	mov	dx,offset crlf
	int	dos
	pop	dx
	pop	ax
	pop	si
ackmsgx:mov	rpacket.datlen,0
	ret
ackmsg	endp

; Shrink transmitted D packets by 1/2 to accomodate comms failures
shrink	proc	near
	push	ax
	mov	ax,current_max		; current max packet length
	shr	ax,1			; divide by two
	cmp	ax,40			; too small?
	jae	shrink1			; ae = no
	mov	ax,40			; smallest size
shrink1:mov	current_max,ax		; new max packet length
	pop	ax
	ret
shrink	endp

; Enlarge transmitted D packets by factor of 2 to recover from comms failures
grow	proc	near
	push	ax
	mov	ax,current_max		; current max packet length
	shl	ax,1			; 2 * current max
	cmp	ax,trans.maxdat		; max negotiated
	jbe	grow1			; be = not exceeded
	mov	ax,trans.maxdat		; limit to negotiated
grow1:	mov	current_max,ax
	pop	ax
	ret
grow	endp

code	ends

code1	segment
	assume	cs:code1

; This routine sets up the data for the response to an Init packet
; trans.rxxx are items which have been negotiated.
; Lines marked ;M energize the second CAPAS byte. Leave them as comments
; because earlier versions of MS Kermit (and C Kermit) are confused by it
; (failed to decode bit saying second CAPAS byte follows and thus lose sync).
; Enter with SI = pktinfo pointer
; Returns [si].datlen = length of data field, with packet buffer filled in.
RPAR	PROC	FAR
	push	ax
	push	dx
	push	di
	push	es
	cld
	xor	dh,dh
	mov	dl,trans.spsiz	; Maximum send packet size for Regular pkts. 
	sub	dx,2			; minus Sequence, Type
	sub	dl,trans.chklen		; and minus Checksum chars
	sbb	dh,0			; dx is space remaining in packet

	les	di,[si].datadr		; data field address to es:di
	mov	al,trans.rpsiz		; receive packet size
	add	al,' '			; add a space to make it printable
	stosb				; 1, put it in the packet
	mov	al,trans.rtime		; receive packet time out
	add	al,' '
	stosb				; 2
	mov	al,trans.rpad		; number of padding chars
	add	al,' '
	stosb				; 3
	mov	al,trans.rpadch		; padding char
	add	al,40h			; Uncontrol it
	and	al,7FH
	stosb				; 4
	mov	al,trans.reol		; EOL char
	add	al,' '
	stosb				; 5
	mov	al,trans.rquote		; quote char
	stosb				; 6
	mov	al,trans.ebquot		; 8-bit quote char
	stosb				; 7
	mov	al,trans.chklen		; Length of checksum
	add	al,'0'			; make into a real digit
	stosb				; 8
	mov	al,' '			; send a blank for repeat quote
	cmp	dtrans.rptqenable,0	; repeat quote char disabled?
	je	rpar0			; e = yes
	cmp	trans.rptq,0		; disabled from negotiations?
	je	rpar0			; e = yes
	mov	al,trans.rptq		; repeat quote char
rpar0:	stosb				; 9
	sub	dx,9			; bytes consumed in packet
	cmp	dx,1			; next field width
	jle	rparx			; le = out of space
			; Bit Number    Value     Meaning
			;    #1          32        Locking shifts
			;    #2          16        level-1 recovery
			;    #3           8        Attribute packets
			;    #4           4        Sliding windows
			;    #5           2        Long packets
			;    #6           1        Continuation marker

	mov	al,2			; CAPAS, bit#5 = can do long packets
	cmp	flags.attflg,0		; allowing attributes packets?
	je	rpar1			; e = no
	or	al,8			; bit #3, can do file attributes
rpar1:	or	al,4			; bit #4 can do windows
	cmp	dtrans.lshift,lock_disable ; locking shift disabled?
	je	rpar2			; e = yes
	or	al,20h			; set locking shift cap (bit #1)
rpar2:	or	al,10h			; set simple minded recovery (bit #1)
	add	al,20h			; apply tochar() to byte
;M	or	al,1			; say second CAPAS byte follows
	stosb				; 10
	dec	dx
	cmp	dx,1
	jle	rparx			; le = out of space

					; additional CAPAS go in here
;M	mov	al,20h+20h	; Allow M (message) pkts, (#6, bit5)
;M	stosb				; 11
	dec	dx
	cmp	dx,1			; packet space remaining
	jle	rparx			; le = out of space
	mov	al,trans.windo		; number of active window slots (1-31)
	add	al,20h			; apply tochar()
	stosb
	dec	dx
	cmp	dx,6			; packet space remaining
	jle	rparx			; le = out of space
	push	dx			; save reg
	mov	ax,trans.rlong		; longest packet which we can receive
	xor	dx,dx			; clear extended part for division
	div	ninefive		; divide by 95. quo = ax, rem = dx
	add	al,20h			; apply tochar() to quotient
	stosb
	add	dl,20h			; apply tochar() to remainder
	mov	al,dl
	pop	dx			; restore regs
	stosb
	mov	al,0			; trans.chkpnt
	add	al,20h
	stosb
	mov	al,'_'			; dummy for nothing
	stosb
	stosb
	stosb
	sub	dx,6			; packet space remaining
	jle	rparx			; le = out of space
;The layout of the (unencoded) WHATAMI field is:
;    Bit 5     Bit 4           Bit 3      Bit 2    Bit 1    Bit 0
;  +--------+---------------+-----------+--------+--------+--------+
;  |     1  | clear channel | streaming | FNAMES | FMODE  | SERVER |
;  +--------+---------------+-----------+--------+--------+--------+
	mov	al,20h+32		; WHATAMI field is valid, + bias
	cmp	streaming,0		; enabled streaming negotiation?
	je	rpar2a			; e = no
	or	al,8			; bit-3 on for streaming protocol
rpar2a:	or	al,4			; say want filenames converted
	cmp	trans.xtype,1		; file type binary?
	jne	rpar3			; ne = no
	or	al,2			; say in we are binary mode
rpar3:	test	flags.remflg,dserver	; server mode?
	jz	rpar4			; z = no
	or	al,1			; say we are in server mode
rpar4:	stosb				; to packet
	dec	dx
	cmp	dx,3			; packet space remaining
	jle	rparx			; le = out of space
	mov	ax,'0!'			; SYSID, len=1 (1), id=anonymous (0)
	cmp	dtrans.xmode,0		; manual file xfer mode determination?
	je	rpar5			; e = yes, send anon for ignore sysid
	mov	al,'"'			; SYSID, length of two (")
	stosb
	dec	dx
	mov	ax,'8U'			; U8 = Portable O/S (U), MSDOS (8)
rpar5:	stosw				; capas+9 is machine ident
	sub	dx,2

rparx:	sub	di,word ptr [si].datadr	; end minus beginning = length
	mov	[si].datlen,di		; length of rpar data in packet
	pop	es
	pop	di
	pop	dx
	pop	ax
	ret
RPAR	ENDP

; Set maximum capabilities
; dtrans are the defaults (which the user can modify), trans are negotiated
; and active values.
SPARMAX	PROC	FAR
	push	ax
	mov	al,dtrans.spsiz		; [1] regular packet size MAXL
	mov	trans.spsiz,al
	mov	al,dtrans.stime		; [2] send timeout value TIME
	mov	trans.rtime,al
	mov	al,dtrans.spad		; [3] send padding count NPAD
	mov	trans.spad,al
	mov	al,dtrans.spadch	; [4] send padding character PADC
	mov	trans.spadch,al
	mov	al,dtrans.seol		; [5] EOL character EOL
	mov	trans.seol,al
	mov	al,dtrans.squote	; [6] control quote character QCTL
	mov	trans.squote,al
	push	bx			; [7] 8-bit quote character QBIN
	mov	bx,portval
	mov	ah,[bx].parflg		; get our parity flag
	pop	bx
	mov	al,'Y'			; will quote upon request
	cmp	dtrans.lshift,lock_force ; locking shift forced?
	jne	spmax1			; ne = no
	mov	al,'N'			; ignore 8-bit quote
	jmp	short spmax1a		; for any parity
spmax1:	cmp	ah,parnon		; parity of none?
	je	spmax1a			; e = yes, reset 8 bit quote character
	mov	al,dqbin		; we want quoting, active
spmax1a:mov	trans.ebquot,al		; save quoting state
	mov	dtrans.ebquot,al
	mov	al,dtrans.chklen	; [8] initial checksum type CHKT
	mov	trans.chklen,al
	mov	al,dtrans.rptq		; [9] repeat prefix character REPT
	cmp	dtrans.rptqenable,0	; disabled?
	jne	spmax1b			; ne = no, enabled
	xor	al,al
spmax1b:mov	trans.rptq,al
	mov	al,16+8+4+2		; [10] capas bitmap CAPAS
	cmp	dtrans.lshift,lock_disable ; locking shift disabled?
	je	spmax2			; e = yes
	or	al,32			; locking shift capability
spmax2:	mov	trans.capas,al		; [10] capas bitmap CAPAS
	mov	trans.capas+1,20h	; [11] CAPAS+1, Message pkts
	mov	al,dtrans.windo		; [12] window size WINDO
	mov	trans.windo,al
	mov	ax,dtrans.slong		; [13-14] long packet send length,
	mov	trans.slong,ax		;  MAXLX1 and MAXLX2
					;
	mov	al,dtrans.rpsiz		; max regular packet we can receive
	mov	trans.rpsiz,al		;  for window of one slot
	mov	ax,dtrans.rlong		; max long packet we can receive
	mov	trans.rlong,ax		;  for window of one slot
	mov	al,dtrans.xtype		; file TYPE (TEXT, BINARY)
	mov	trans.xtype,al
	pop	ax
	ret
SPARMAX	ENDP
code1	ends

code	segment
	assume	cs:code
; This routine reads in all the send init packet information
; Enter with SI = pktinfo address, [si].datlen = packet length
; All regs preserved except AX. 
; dtrans.xxx are the default parameters if the other side says nothing
; trans.sxxx are the active negotiated parameters we will use.
SPAR	PROC	NEAR
	push	es
	push	ax			; set min defaults for no host data
	mov	trans.spsiz,80		; [1] regular packet size MAXL
	mov	al,dtrans.stime		; get user selected stime
	mov	trans.stime,al		; [2] send timeout value TIME
	mov	trans.spad,0		; [3] send padding count NPAD
	mov	al,dtrans.spadch	; [4] send padding character PADC
	mov	trans.spadch,al
	mov	trans.seol,CR		; [5] EOL character EOL
	mov	trans.squote,'#'	; [6] control quote character QCTL
	push	bx			; [7] 8-bit quote character QBIN
	mov	bx,portval		; current port settings
	mov	ah,[bx].parflg		; get our parity flag
	pop	bx
	mov	al,'Y'			; say will quote upon request
	cmp	dtrans.lshift,lock_force ; locking shift forced?
	jne	spar0a			; ne = no
	mov	al,'N'			; ignore 8-bit quotes
	jmp	short spar0b		; regardless of parity
spar0a:	cmp	ah,parnon		; parity of none?
	je	spar0b			; e = yes
	mov	al,dqbin		; we want quoting, active
spar0b:	mov	trans.ebquot,al		; use proper quote char
	mov	dtrans.ebquot,al
	mov	trans.chklen,1		; [8] initial checksum type CHKT
	xor	ax,ax
	mov	trans.rptq,al		; [9] repeat prefix character REPT
	mov	trans.capas,al		; [10-11] capas bitmap CAPAS
	mov	trans.capas+1,al
	mov	trans.lshift,lock_disable ; init locking shift to disabled
	mov	trans.windo,1		; [12] window size WINDO
	mov	al,trans.spsiz
	mov	trans.slong,ax		; [13-14] long packet send length,
					;  MAXLX1 and MAXLX2
	mov	trans.cpkind,al		; checkpoint availability, clear
	mov	word ptr trans.cpint,ax ; checkpoint interval, clear
	mov	word ptr trans.cpint+2,ax
	mov	streamok,0		; presume no streaming
					; start negotiations
	push	si			; pktinfo structure pointer
	mov	ax,[si].datlen		; length of received data
	mov	ah,al			; number of args is now in ah
	les	si,[si].datadr		; es:si is pointer to received data
	cld
	or	ah,ah			; [1] MAXL  any data?
	jg	spar1a			; g = yes
	jmp	sparx1
spar1a:	mov	al,es:[si]		; get the max regular packet size
	inc	si
	dec	ah			; ah = bytes remaining to be examined
	sub	al,' '			; subtract ascii bias
	jnc	spar1b			; c = old C Kermit error
	mov	al,spmax
spar1b:	cmp	al,dtrans.spsiz		; user limit is less?
	jbe	spar1c			; be = no
	mov	al,dtrans.spsiz		; replace with our lower limit
spar1c:	cmp	al,spmin		; below the minimum?
	jge	spar1d			; ge = no
	mov	al,spmin
spar1d:	cmp	al,spmax		; or above the maximum?
	jle	spar1e			; le = no
	mov	al,spmax
spar1e:	mov	trans.spsiz,al		; save it
	push	ax
	xor	ah,ah			; set long packet to regular size
	mov	trans.slong,ax
	pop	ax

	or	ah,ah			; [2] TIME  more data?
	jg	spar2a			; g = yes
	jmp	sparx1
spar2a:	mov	al,es:[si]		; get the timeout value
	inc	si
	dec	ah
	sub	al,' '			; subtract a space
	jge	spar2b			; must be non-negative
	xor	al,al			; negative, so use zero
spar2b:	cmp	al,trans.rtime		; same as other side's timeout
	jne	spar2c			; ne = no
	inc	al			; yes, but make it a little different
spar2c:	cmp	dtrans.stime,dstime	; is current value the default?
	je	spar2d			; e = yes, else user value overrides
	mov	al,dtrans.stime		; get user selected stime
spar2d:	mov	trans.stime,al		; save it
					;
	or	ah,ah			; [3] NPAD  more data?
	jg	spar3a			; g = yes
	jmp	sparx1
spar3a:	mov	al,es:[si]		; get the number of padding chars
	inc	si
	dec	ah
	sub	al,' '
	jge	spar3b			; must be non-negative
	xor	al,al
spar3b:	mov	trans.spad,al		; number of padding chars to send
					;
	or	ah,ah			; [4] PADC  more data?
	jg	spar4a			; g = yes
	jmp	sparx1
spar4a:	mov	al,es:[si]		; get the padding char
	inc	si
	dec	ah
	add	al,40h			; remove ascii bias
	and	al,7FH
	cmp	al,del			; Delete?
	je	spar4b			; e = yes, then it's OK
	cmp	al,31			; control char?
	jbe	spar4b			; be = yes, then OK
	xor	al,al			; no, use null
spar4b:	mov	trans.spadch,al
					;
	or	ah,ah			; [5] EOL  more data?
	jg	spar5a			; g = yes
	jmp	sparx1
spar5a:	mov	al,es:[si]		; get the EOL char
	inc	si
	dec	ah
	sub	al,' '
	cmp	al,31			; control char?
	jbe	spar5b			; le = yes, then use it
	mov	al,cr			; else use the default
spar5b:	mov	trans.seol,al		; EOL char to be used
					;
	or	ah,ah			; [6] QCTL  more data?
	jg	spar6a			; g = yes
	jmp	sparx1
spar6a:	mov	al,es:[si]		; get the quote char
	inc	si
	dec	ah
	cmp	al,' '			; less than a space?
	jge	spar6b			; ge = no
	mov	al,dsquot		; yes, use default
spar6b:	cmp	al,7eh			; must also be less than a tilde
	jbe	spar6c			; be = is ok
	mov	al,dsquot		; else use default
spar6c:	mov	trans.squote,al
					;
	or	ah,ah			; [7] QBIN  more data?
	jg	spar7a			; g = yes
	jmp	sparx1
spar7a:	mov	al,es:[si]		; get other side's 8-bit quote request
	inc	si
	dec	ah
	call	doquo			; and set quote char
					;
	or	ah,ah			; [8] CHKT  more data?
	jg	spar8a			; a = yes
	jmp	sparx1
spar8a:	mov	al,es:[si]		; get other side's checksum length
	inc	si
	dec	ah
	call	dochk			; determine what size to use
					;
	or	ah,ah			; [9] REPT  more data?
	jg	spar9a			; g = yes
	jmp	sparx1
spar9a:	mov	al,es:[si]		; get other side's repeat count prefix
	inc	si
	dec	ah
	call	dorpt			; negotiate prefix into trans.rptq
					;
	or	ah,ah			; [10] CAPAS  more data?
	jg	spar10a			; g = yes
	jmp	sparx1
spar10a:mov	al,es:[si]		; get CAPAS bitmap from other side
	inc	si
	dec	ah
			; Bit Number    Value     Meaning
			;    #1          32        Locking shifts
			;    #2          16        level-1 recovery
			;    #3           8        Attribute packets
			;    #4           4        Sliding windows
			;    #5           2        Long packets
			;    #6           1        Continuation marker

	and	al,not (1)		; remove least significant bit
	sub	al,20h			; apply unchar()
	mov	trans.capas,al		; store result in active byte
	test	al,20h			; locking shift proposed?
	jz	spar11			; z = no
	cmp	dtrans.lshift,lock_enable ; have we enabled its negotiation?
	jb	spar11			; b = no, (0) disabled
	ja	spar10b			; a = (2) forced
	mov	al,trans.ebquot		; get negotiated 8-bit quote char
	cmp	al,'N'			; did 8-bit quote negotiation fail?
	je	spar11			; e = yes, no locking shift agreement
	cmp	al,'Y'			; did 8-bit quote negotiation fail?
	je	spar11			; e = yes, no locking shift agreement
	mov	trans.lshift,lock_enable ; set state of locking shift
	jmp	short spar11
spar10b:mov	trans.ebquot,'N'	; ignore 8-bit quote prefix
	mov	trans.lshift,lock_force	; and activate working copy

spar11:	or	ah,ah			; [11] CAPAS+  more data?
	jg	spar11a			; g = yes
	jmp	sparx1
spar11a:test	byte ptr es:[si-1],1	; is CAPAS byte continued to another?
	jz	spar12			; z = no
	mov	al,es:[si]		; get 2nd CAPAS bitmap from other side
	inc	si
	dec	ah			; [12] second CAPAS
	and	al,not (1)		; remove least significant bit
	sub	al,20h			; apply unchar(). Store nothing
	mov	trans.capas+1,al	; keep second CAPAS byte

spar11c:or	ah,ah			; [12] CAPAS++  more data?
	jg	spar11d			; g = yes
	jmp	sparx1
spar11d:test	byte ptr es:[si-1],1	; is CAPAS byte continued to another?
	jz	spar12			; z = no
	mov	al,es:[si]		; 3rd et seq CAPAS bitmaps
	inc	si
	dec	ah			; [13] third CAPAS byte
	and	al,not (1)		; remove least significant bit
	sub	al,20h			; apply unchar(). Store nothing
	jmp	short spar11c		; seek more CAPAS bytes
					;
spar12:	or	ah,ah			; [12/14] WINDO  more data?
	jg	spar12a			; g = yes
	jmp	sparx1			; exit spar
spar12a:mov	al,es:[si]		; get other side's window size
	inc	si
	dec	ah
	sub	al,20h			; apply unchar()
	call	dewind			; negotiate window size
					;
	cmp	ah,2			; [13-14/] MAXL (long packet needs 2)
	jge	spar13a			; ge = enough data to look at
	push	ax			; make long same size as regular
	xor	ah,ah
	mov	al,trans.spsiz		; normal packet size
	mov	trans.slong,ax		; assume not using long packets
	pop	ax			; recover ah
	jmp	sparx1			; do final checks on packet length
spar13a:test	trans.capas,2		; do they have long packet capability?
	jnz	spar13b			; nz = yes
	add	si,2
	sub	ah,2
	jmp	spar15			; no, skip following l-pkt len fields

spar13b:mov	al,es:[si]		; long pkt length, high order byte
	inc	si
	dec	ah
	push	ax			; save ah
	sub	al,20h			; apply unchar()
	xor	ah,ah
	mul	ninefive		; times 95 to dx (high), ax (low)
	mov	trans.slong,ax		; store high order part
	pop	ax
	dec	ah			; reading another byte
	push	ax
	mov	al,es:[si]		; long pkt length, low order byte
	inc	si
	sub	al,20h			; apply unchar()
	xor	ah,ah
	add	ax,trans.slong		; plus high order part
	mov	trans.slong,ax		; store it
	or	ax,ax			; if result is 0 then use regular pkts
	jnz	spar13c			; non-zero, use what they want
	mov	al,trans.spsiz		; else default to regular packet size
	xor	ah,ah
	mov	trans.slong,ax	;  and ignore the CAPAS bit (no def 500 bytes)
spar13c:cmp	ax,dtrans.slong		; longer than we want to do?
	jbe	spar13d			; be = no
	mov	ax,dtrans.slong		; limit to our longest sending size
	mov	trans.slong,ax		; and use it
spar13d:push	dx
	mov	dl,trans.spsiz		; regular pkt length
	xor	dh,dh
	cmp	ax,dx			; long pkt shorter than regular?
	jae	spar13f			; ae = no
	cmp	al,spmin		; below the minimum allowed length?
	jae	spar13e			; ae = yes
	mov	al,spmin		; drop down to minimum
	mov	trans.slong,ax		; update long pkt too
spar13e:mov	trans.spsiz,al		; use small long packet length
spar13f:pop	dx
	pop	ax			; recover ah

spar15:	cmp	ah,4			; [15-18/] CHKPNT, requires 4 bytes
	jl	sparx1			; l = insufficient data
	sub	ah,4			; deduct bytes about to be read
	push	ax
	mov	al,es:[si]		; get CHKPNT byte
	sub	al,20h			; remove ASCII bias
	inc	si
	call	cp_negotiate		; perform negotiations
	mov	cx,3			; get interval, three bytes
spar15a:mov	ax,word ptr trans.cpint+2 ; high order part of interval
	mov	bx,95			; times 95
	mul	bx
	push	ax			; save low order part of result
	mov	ax,word ptr trans.cpint ; low order part of interval
	mul	bx			; times 95
	pop	bx			; old low order part of high order
	add	dx,bx			; accmulate
	push	ax
	mov	al,es:[si]		; read new byte
	sub	al,20h			; remove ASCII bias
	xor	ah,ah
	mov	bx,95
	div	bl			; modulo 95
	mov	bl,al
	pop	ax
	inc	si
	add	ax,bx
	adc	dx,0
	mov	word ptr trans.cpint,ax ; chkint * 95
	mov	word ptr trans.cpint+2,dx
	loop	spar15a
	cmp	dx,13			; is result too large (857374)?
	jb	spar15c			; b = no, in range
	ja	spar15b			; a = bad
	cmp	ax,5406			; dx=13, max low part
	jbe	spar15c			; be = in range
spar15b:xor	ax,ax			; failure on size
	mov	trans.cpkind,al
	mov	word ptr trans.cpint,ax
	mov	word ptr trans.cpint+2,ax
spar15c:pop	ax

spar19:	or	ah,ah			; more data?
	jg	spar19a			; g = yes
	jmp	sparx1			; exit spar

spar19a:mov	al,es:[si]		; [19] get other side's WHATAMI
	inc	si
	dec	ah
	sub	al,32			; apply unchar()
	test	al,20h			; is "bit 5" set as per protocol?
	jz	spar20			; z = no, ignore this byte
	cmp	streaming,0		; streaming negotiation permitted?
	je	spar19b			; e = no, ignore bit-3
	test	al,8			; other side wants stream mode?
	jz	spar19b			; z = no
	mov	streamok,1		; say will do streaming

spar19b:test	flags.remflg,dserver	; are we a server?
	jz	spar20			; z = no, ignore this field
	mov	trans.xtype,0		; set file type text
	mov	dtrans.xtype,0		; set file type text
	test	al,2			; do binary mode?
	jz	spar20			; z = no, text mode
	mov	trans.xtype,1		; set file type binary
	mov	dtrans.xtype,1		; set file type binary

spar20:	or	ah,ah			; more data?
	jg	spar20a			; g = yes
	jmp	sparx1			; exit spar
spar20a:mov	al,es:[si]		; [20] get other side's SYSID
	inc	si			; one byte of biased count then ident
	dec	ah
	sub	al,' '			; remove ASCII bias to get count
	cmp	al,2			; fits our two byte length?
	jne	spar20b			; ne = no
	cmp	word ptr es:[si],'8U'	; fits our system ident (U8) too?
	jne	spar20b			; ne = no
	cmp	dtrans.xmode,0		; manual file xfer mode determination?
	je	spar20b			; e = yes
	mov	trans.xtype,1		; set file type binary
spar20b:push	cx
	mov	cl,al
	xor	ch,ch
	add	si,cx			; step beyond system ident field
	sub	ah,cl
	pop	cx
					; Windowing can further shrink pkts
sparx1:	push	cx			; final packet size negotiations
	push	dx
	mov	ax,maxbufparas		; our max buffer size, paragraphs
	mov	cl,trans.windo		; number of active window slots
	cmp	streamok,0		; negotiated streaming mode?
	je	sparx1a			; e = no
	mov	cl,1
	mov	trans.windo,cl		; streaming means no windowing
sparx1a:xor	ch,ch
	sub	ax,cx			; minus null byte and rounding/slot
	jcxz	sparx2			; 0 means 1, for safety here
	xor	dx,dx			; whole buffer / # window slots
	div	cx			; ax = longest windowed pkt possible
					; transmitter packet size
sparx2:	cmp	ax,(9024/16)		; longest packet, in paragraphs
	jbe	sparx2a			; be = less than eq longest
	mov	ax,(9024/16)
sparx2a:mov	cl,4			; convert to bytes
	shl	ax,cl			; ax has bytes per buffer
	cmp	ax,trans.slong		; our slots can be longer than theirs?
	ja	sparx2b			; a = yes, use their shorter length
	mov	trans.slong,ax		; no, use our shorter length
sparx2b:mov	cl,trans.spsiz		; current regular pkt size
	xor	ch,ch
	cmp	cx,ax			; is regular longer than window slot?
	jbe	sparx3			; be = no
	mov	trans.spsiz,al		; shrink regular to windowed size
					; receiver packet size
sparx3:	cmp	ax,dtrans.rlong		; slot shorter than longest allowed?
	jae	sparx5			; ae = no
	mov	trans.rlong,ax		; long size we want to receive
	mov	cl,dtrans.rpsiz		; regular packet size user limit
	xor	ch,ch
	cmp	cx,ax			; is regular longer than window too?
	jbe	sparx4			; be = no
	mov	cl,al			; shrink regular to windowed size
sparx4:	mov	trans.rpsiz,cl		; regular size we want

sparx5:	push	bx			; list of protected control codes
	xor	bh,bh
	mov	bl,flowon		; flow control
	or	bl,bl			; any?
	jz	sparx6			; z = none
	and	protlist[bx],not 1	; if active
	mov	bl,flowoff
	and	protlist[bx],not 1
sparx6:	pop	bx

	pop	dx
	pop	cx
	pop	si			; saved at start of spar
	pop	ax
	pop	es
	ret
SPAR	ENDP
 
; Set 8-bit quote character based on my capabilities and the other
; Kermit's request. Quote if one side says Y and the other a legal char
; or if both sides say the same legal char. Enter with AL = their quote char
DOQUO	PROC	NEAR
	cmp	dtrans.lshift,lock_force ; forcing locking shift?
	je	dq3			; e = yes, ignore 8-bit quoting
	cmp	dtrans.ebquot,'N'	; we refuse to do 8-bit quoting?
	je	dq3			; e = yes, do not quote
	cmp	al,'N'			; 'N' = they refuse quoting?
	je	dq3			; e = yes, do not quote
	cmp	dtrans.ebquot,'Y'	; can we do it if requested?
	je	dq2			; e = yes, use their char in al
	cmp	al,'Y'			; 'Y' = they can quote if req'd?
	jne	dq1			; ne = no, use their particular char
	mov	al,dtrans.ebquot	; we want to use a particular char
	call	prechk			;  and they said 'Y', check ours
	jc	dq3			; c = ours is out of range, no quoting
dq1:	cmp	al,dtrans.ebquot	; active quote vs ours, must match
	jne	dq3			; ne = mismatch, no quoting
dq2:	mov	trans.ebquot,al		; get active char, ours or theirs
	cmp	al,'Y'
	je	dq4	
	call	prechk			; in range 33-62, 96-126?
	jc	dq3			; c = out of range, do not quote
dq4:	cmp	al,trans.rquote		; same prefix as control-quote?
	je	dq3			; e = yes, don't do 8-bit quote
	cmp	al,trans.squote		; same prefix control-quote?
	je	dq3			; this is illegal too
	mov	trans.ebquot,al		; remember what we decided on
	ret
dq3:	mov	trans.ebquot,'N'	; quoting will not be done
	ret
DOQUO	ENDP
 
; Check if prefix in AL is in the proper range: 33-62, 96-126. 
; Return carry clear if in range, else return carry set.
prechk:	cmp	al,33
	jb	prechk2			; b = out of range
	cmp	al,62
	jbe	prechk1			; be = in range 33-62
	cmp	al,96
	jb	prechk2			; b = out of range
	cmp	al,126
	ja	prechk2			; a = out of range 96-126
prechk1:clc				; carry clear for in range
	ret
prechk2:stc				; carry set for out of range
	ret

; Set checksum length. AL holds their checksum request.
dochk:	cmp	al,'1'			; Must be '1', '2', '3', or 'B'
	jb	doc1			; b = not '1' to '3'
	cmp	al,'3'
	jbe	doc2			; be = ok
	cmp	al,'B'			; special non-blank 2 byte?
	je	doc2			; e = yes
doc1:	mov	al,'1'			; else use default of '1'
doc2:	sub	al,'0'			; remove ascii bias
	mov	trans.chklen,al		; other side's request is do-able here
	ret

; Set repeat count quote character.  The one used must be different than
; the control and eight-bit quote characters.  Also, both sides must 
; use the same character
dorpt:	mov	trans.rptq,0		; assume will not repeat prefix
	call	prechk			; is it in the valid range?
	jnc	dorpt1			; nc = in range
	ret				; don't use their value 
dorpt1:	cmp	dtrans.rptqenable,0	; disabled
	je	dorpt2			; e = yes
	cmp	al,trans.squote		; same as the control quote char?
	je	dorpt2			; e = yes, that's illegal, no repeats
	cmp	al,trans.rquote		; this too?
	je	dorpt2			; e = no good either
	cmp	al,trans.ebquot		; same as eight bit quote char?
	je	dorpt2			; e = yes, illegal too, no repeats
	cmp	al,dtrans.rptq		; both sides using same char?
	jne	dorpt2			; ne = no, that's no good either
	mov	trans.rptq,al		; use repeat quote char now
dorpt2:	ret

					; negotiate window size in al
dewind:	cmp	al,dtrans.windo		; their (al) vs our max window size
	jbe	dewind1			; be = they want less than we can do
	mov	al,dtrans.windo		; limit to our max size
dewind1:or	al,al
	jnz	dewind2
	inc	al			; use 1 if 0
dewind2:mov	trans.windo,al		; store active window size
	ret

; Negotiate checkpointing availability, host value is in al as binary
cp_negotiate proc near
	; fill in details
	ret
cp_negotiate endp

; Set the maximum send data packet size; modified for long packets
PACKLEN	PROC	NEAR
	push	ax
	xor	ah,ah
	mov	al,trans.spsiz	; Maximum send packet size for Regular pkts. 
	cmp	ax,trans.slong		; negotiated long packet max size
	jae	packle1			; ae = use regular packets
	mov	ax,trans.slong		; else use long kind
	sub	ax,3			; minus extended count & checksum
	cmp	ax,(95*94-1-2)		; longer than Long?
	jle	packle1			; le = no, Long will do
	dec	ax			; minus one more for extra long count
packle1:sub	ax,2			; minus Sequence, Type
	cmp	trans.chklen,'B'-'0'	; special 'B'?
	jne	packle2			; ne = no
	sub	al,2			; 'B' is two byte kind
	jmp	short packle3
packle2:sub	al,trans.chklen		; and minus Checksum chars
packle3:sbb	ah,0			; borrow propagate
	cmp	trans.ebquot,'N'	; doing 8-bit Quoting?
	je	packle4			; e = no, so we've got our size
	cmp	trans.ebquot,'Y'
	je	packle4			; e = not doing it in this case either
	dec	ax			; another 1 for 8th-bit Quoting. 
packle4:cmp	trans.rptq,0		; doing repeat character Quoting?
	je	packle5			; e = no, so that's all for now
	dec	ax			; minus repeat prefix
	dec	ax			;  and repeat count
packle5:dec	ax		    ; for last char might being a control code
	cmp	trans.lshift,lock_disable ; locking shift disabled?
	je	packle6			; e = yes
	dec	dx			; allow prefixing of SI/SO
packle6:mov	trans.maxdat,ax		; save max length for data field
	pop	ax
	ret
PACKLEN	ENDP

 ; Print the number in AX on the screen in decimal rather that hex

NOUT 	PROC	NEAR
	test	flags.remflg,dserver	; server mode?
	jnz	nout2			; nz = yes, writing to their screen
	cmp	flags.xflg,0		; receiving to screen?
	jne	nout1			; ne = yes
nout2:	test	flags.remflg,dserial 	; serial display mode?
	jnz	pnout		    ; nz = use "dot and plus" for serial mode
	test	flags.remflg,dquiet	; quiet display mode?
	jnz	nout1			; nz = yes. Don't write to screen
	call	decout			; call standard decimal output routine
nout1:	ret

pnout:	or	ax,ax			; display packet in serial display mode
	jz	pnoutx			; z = nothing to display
	push	ax			; for serial mode display
	push	cx
	push	dx			; output .........+.........+  etc
	xor	dx,dx			; extended numerator
	mov	cx,10
	div	cx			; number/10. (AX=quo, DX=rem)
	or	dx,dx			; remainder non-zero?
	jnz	pnout1			; nz = yes
	mov	dl,'+'			; symbol plus for tens
	jmp	short pnout2		; display it
pnout1:	mov	dl,'.'			; symbol for between tens
pnout2:	mov	ah,conout		; output to console
	int	dos
	pop	dx
	pop	cx
	pop	ax
pnoutx:	ret
NOUT	ENDP

; Decode and display Error packet message. 
ERROR	PROC	NEAR
	mov	sstate,'A'		; Set the state to abort
	push	si
	mov	si,offset rpacket	; source address
	call	dodec			; decode to decbuf
	mov	dx,offset decbuf	; where msg got decoded, asciiz
	call	ermsg			; display string
	pop	si
	stc				; set carry for failure state
	ret
ERROR	ENDP

; General routine for sending an error packet.  Register BX should
; point to the text of the message being sent in the packet

ERRPACK	PROC	NEAR
	push	cx
	push	di
	mov	di,offset encbuf	; Where to put the message
	xor	cx,cx
errpa1:	mov	al,[bx]
	inc	bx
	cmp	al,'$'			; at end of message?
	je	errpa2			; e = terminator
	or	al,al			; this kind of terminator too?
	jz	errpa2			; z = terminator
	inc	cx			; count number of chars in msg
	mov	[di],al			; copy message
	inc	di
	jmp	short errpa1
errpa2:	push	si
	mov	si,offset rpacket	; use response buffer
	mov	al,pktnum
	mov	rpacket.seqnum,al
	call	doenc
	call	pktsize			; report packet size
	mov	rpacket.pktype,'E'	; send an error packet
	call	spack
	mov	rpacket.datlen,0	; clear response buffer
	pop	si
	pop	di
	pop	cx
	ret
ERRPACK	ENDP

; Enter with dx pointing to asciiz error message to be sent
giveup	proc near
	call	bufclr			; release all buffers
	call	ermsg			; position cursor, display asciiz msg
	mov	bx,dx
	call	errpack			; send error packet
	xor	ax,ax
	mov	auxfile,al		; clear send-as/mail-to buffer
	mov	mailflg,al		; clear Mail flag
	cmp	filopn,al		; disk files open?
	je	giveu2			; e = no so don't do a close
	mov	ah,close2		; close file
	push	bx
	mov	bx,diskio.handle	; file handle
	int	dos
	pop	bx
	mov	filopn,0		; say file is closed now
giveu2:	mov	sstate,'A'		; abort state
	or	errlev,kssend		; set DOS error level
	or	fsta.xstatus,kssend	; set status
	mov	kstatus,kssend		; global status
	stc				; set carry for failure status
	ret
giveup	endp
code	ends 
code1	segment
	assume cs:code1

; newfn	-- move replacement name from buffer auxfile to buffer encbuf

newfn	proc	near
	push	si
	push	di
	cmp	auxfile,0		; sending file under different name?
	je	newfn4			; e = no, so don't give new name
	mov	si,offset auxfile	; source field
	mov	di,offset fsta.xname	; statistics external name area
	call	strcpy
	test	flags.remflg,dquiet	; quiet display mode?
	jnz	newfn2			; nz = yes, do not write to screen
	mov	dx,offset asmsg		; display ' as '
	cmp	mailflg,0		; mail?
	je	newfn1			; e = no
	mov	dx,offset mailto	; display ' To: '
newfn1:	call	prtasz			; display asciiz msg
	cmp	mailflg,0		; mail?
	je	newfn2			; e = no
	mov	dx,offset auxfile	; get name
	call	prtasz			; display asciiz string
	jmp	short newfn4		; don't replace filename
newfn2:	mov	si,offset auxfile	; external name
	mov	di,offset encbuf
	call	strcpy			; put into encoder buffer
	test	flags.remflg,dquiet    ; quiet display mode (should we print)?
	jnz	newfn5			; nz = yes
	mov	dx,si
	call	prtasz			; display external name
newfn4:	test	flags.remflg,dserial	; serial display mode?
	jz	newfn5			; z = no
	mov	dx,offset crlf		; start with cr/lf for serial display
	mov	ah,prstr
	int	dos
newfn5:	pop	di
	pop	si
	ret
newfn	endp
code1	ends
	end
