	NAME	mssrcv
; File MSSRCV.ASM
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

	public	read2, read, rrinit, ackpak, nakpak, rstate, fdate, ftime

data 	segment
	extrn	encbuf:byte, decbuf:byte, fmtdsp:byte, flags:byte, trans:byte
	extrn	dtrans:byte, sstate:byte, diskio:byte, auxfile:byte
	extrn	maxtry:byte, fsta:word, errlev:byte, kstatus:word
	extrn	rpacket:byte, wrpmsg:byte, numpkt:word, windlow:byte
	extrn	charids:word, windflag:byte, denyflg:word, chkparflg:byte
	extrn	tfilsz:word, filtst:byte, rdbuf:byte
	extrn	ferbyte:byte, ferdate:byte, ferdisp:byte, fertype:byte
	extrn	ferchar:byte, fername:byte, ferunk:byte, termserver:byte
	extrn	k_rto:word, cwindow:byte, vfile:byte, streamok:byte

cemsg	db	'User intervention',0
erms11	db	'Not enough disk space for file',0
erms13	db	'Unable to send reply',0
erms14  db	'No response from the host',0
erms15	db	'Error. No buffers in receive routine',0
erms29	db	'Rejecting file: ',0
ifndef	nls_portuguese
infms1  db	cr,'           Receiving: In progress',cr,lf,'$'
else
infms1  db	cr,'               Receiving: In progress',cr,lf,'$'
endif	; nls_portuguese
infms3  db      'Completed',cr,lf,'$'
infms4  db      'Failed',cr,lf,'$'
infms6  db      'Interrupted',cr,lf,'$'
infms7	db	'Discarding $'
ender	db	bell,bell,'$'
crlf	db	cr,lf,'$'
badrcv	db	0		; local retry counter
filopn	db	0		; non-zero if disk file is open
ftime	db	0,0		; file time (defaults to 00:00:00)
fdate	db	0,0		; file date (defaults to 1 Jan 1980)
attrib	db	0		; attribute code causing file rejection
restart_flag db	0		; non-zero if remote requests file restart
rstate	db	0		; state of automata
permchrset dw	0		; permanent file character set holder
permflwflg db	0		; save file transfer set
dostream db	0		; non-zero to engage streaming mode
ten	dw	10
temp	dw	0
data	ends

data1	segment
filhlp2 db      ' Local path or filename or carriage return$'
data1	ends

code1	segment
	extrn bufclr:far, pakptr:far, bufrel:far, makebuf:far, chkwind:far
	extrn firstfree:far, getbuf:far, pakdup:far, rpar:far, winpr:far
	extrn rpack:far, spack:far, fcsrtype:far, prtasz:far, dskspace:far
	extrn logtransact:far, strlen:far, strcpy:far, streampr:far
code1	ends

code	segment
	extrn	gofil:near, comnd:near, cntretry:near, perpr:near
	extrn	serini:near, spar:near, lnout:near
	extrn	init:near, cxmsg:near, cxerr:near
	extrn	ptchr:near, ermsg:near
	extrn	stpos:near, rprpos:near, packlen:near, kbpr:near
	extrn	dodec:near, doenc:near, errpack:near, intmsg:near
	extrn	ihostr:near, begtim:near
	extrn	endtim:near, pktsize:near
	extrn	msgmsg:near, clrbuf:near, pcwait:far, goopen:near
	extrn	filekind:near, filecps:near

	assume  cs:code, ds:data, es:nothing

; Data structures comments.
; Received packet material is placed in buffers pointed at by [si].bufadr;
; SI is typically used as a pointer to a pktinfo packet structure.
; Sent packet material (typically ACK/NAKs) is placed in a standard packet
; structure named rpacket.
; Rpack and Spack expect a pointer in SI to the pktinfo structure for the
; packet.

; RECEIVE command
 
READ	PROC	NEAR		
	mov	dx,offset filhlp2	; help message
	mov	bx,offset auxfile	; local file name string
	mov	ah,cmword		; local override filename/path
	call	comnd		
	jc	read1a			; c = failure
	mov	ah,cmeol		; get a confirm
	call	comnd
	jc	read1a			; c = failure
	mov	rstate,'R'		; set state to receive initiate
	mov	flags.xflg,0
	call	serini			; initialize serial port
	jnc	read1b			; nc = success
	or	errlev,ksrecv		; set DOS error level
	or	fsta.xstatus,ksrecv	; set status, failed
	or	kstatus,ksrecv		; global status
	test	flags.remflg,dquiet	; quiet display mode?
	jnz	read1a			; nz = yes, don't write to screen
	mov	ah,prstr
	mov	dx,offset infms4	; Failed message
	int	dos
	stc
read1a:	ret				; return failure

read1b:	call	rrinit			; init variables for read
	call	clrbuf			; clear serial port buffer
	call	ihostr			; initialize the host
	cmp	flags.destflg,dest_screen ; destination is screen?
	je	read2			; e = yes
	mov	flags.xflg,0		; not writing to screen, yet
	call	init			; setup display form
	
					; Called by GET & SRVSND, display ok
READ2:	mov	kstatus,kssuc		; global status, success
	mov	windflag,0		; init windows in use display flag
	mov	numpkt,0		; set the number of packets to zero
	mov	badrcv,0		; local retry counter
	mov	fsta.pretry,0		; clear total retry counter
	mov	flags.cxzflg,0		; reset ^X/^Z flag
	mov	ax,flags.chrset		; permanent character set (Code Page)
	mov	permchrset,ax		; remember here around attributes ptks
	mov	al,flags.flwflg		; file warning flag
	mov	permflwflg,al		; save around file transfer set
	mov	si,offset auxfile
	mov	di,offset vfile
	call	strcpy			; copy name to \v(filename) buffer
	cmp	fmtdsp,0		; formatted display?
	je	read2a			; e = no
	call	stpos
	mov	ah,prstr		; Receiving in progress msg
	mov	dx,offset infms1
	int	dos
read2a:	jmp	dispatch
READ	ENDP

; Call the appropriate action routines for each state of the protocol machine.
; State is held in byte rstate. Enter at label dispatch.

dispatch proc	near			; dispatch on state variable rstate
	mov	dostream,0		; assume not doing streaming mode
	mov	ah,rstate		; get current state
	cmp	ah,'R'			; Receive initiate state?
	jne	dispat2			; ne = no
	cmp	termserver,1		; invoked from terminal emulator?
	jne	dispat1			; ne = no
	mov	windlow,0		; lowest acceptable packet number
	mov	trans.chklen,1		; Use 1 char for NAK packet
	mov	rpacket.seqnum,0
	call	nakpak			; send an initial NAK
	mov	fsta.nakscnt,0		; do not count this NAK stimulus
	inc	termserver		; say have responded to invokation
dispat1:call	rinit
	jmp	short dispatch

dispat2:cmp	ah,'F'			; File header receive state?
	jne	dispat3
	call	rfile			; receive file header
	jmp	short dispatch

dispat3:cmp	ah,'D'			; Data receive state?
	jne	dispat4
	call	rdata			; get data packets
	jmp	short dispatch

dispat4:cmp	ah,'Z'			; EOF?
	jne	dispat5
	call	reof			; do EOF wrapup
	jmp	short dispatch

dispat5:cmp	ah,'E'			; ^C or ^E abort?
	jne	dispat6			; ne = no
	mov	bx,offset cemsg		; user intervention message
	call	errpack			; send error message
	call	intmsg			; show interrupt msg for Control-C-E

					; Receive Complete state processor
dispat6:cmp	rstate,'C'		; completed normally?
	jne	dispat6a		; ne = no
	cmp	flags.cxzflg,0		; interrupted?
	je	dispat7			; e = no, ended normally
dispat6a:or	errlev,ksrecv		; set DOS error level
	or	fsta.xstatus,ksrecv+ksuser ; set status, failed + intervention
	or	kstatus,ksrecv+ksuser	; global status
dispat7:xor	ax,ax		; tell statistics this is a receive operation
	call	endtim			; stop file statistics accumulator
	call	filecps			; show file chars/sec
	call	bufclr			; release all buffers
	mov	windlow,0
	mov	ax,permchrset		; permanent character set (Code Page)
	mov	flags.chrset,ax		; restore external version
	mov	al,permflwflg		; saved around file transfer set
	mov	flags.flwflg,al		; restore file warning state
	cmp	rstate,'C'		; receive complete state?
	je	dispat8			; e = yes
	or	errlev,ksrecv		; Failed, set DOS error level
	or	fsta.xstatus,ksrecv	; set status, failed
	or	kstatus,ksrecv		; global status
	call	fileclose		; close output file
	call	filedel			; delete incomplete file

dispat8:cmp	flags.destflg,dest_screen ; receiving to screen?
	je	dispa11			; e = yes, nothing to clean up
	test	flags.remflg,dquiet	; quiet display mode?
	jnz	dispa11			; nz = yes, keep going
	test	flags.remflg,dserial	; serial display mode?
	jnz	dispa10a		; nz = yes, ring bell
	mov	al,1			; underline cursor
	call	fcsrtype		; set IBM-PC cursor to underline
	cmp	flags.xflg,0		; writing to the screen?
	jne	dispa11			; ne = yes
	call	stpos			; position cursor to status line
	mov	dx,offset infms3	; completed message
	cmp	rstate,'C'		; receive complete state?
	je	dispa10			; e = yes
	mov	dx,offset infms4	; failed message
	cmp	flags.cxzflg,0		; interrupted?
	je	dispa10			; e = no, ended normally
	mov	dx,offset infms6	; interrupted message
dispa10:mov	ah,prstr
	int	dos
dispa10a:cmp	flags.belflg,0		; bell desired?
	je	dispa11			; e = no
	mov	ah,prstr
	mov	dx,offset ender		; ring the bell
	int	dos
dispa11:call	rprpos			; put cursor at reprompt position
	mov	flags.cxzflg,0		; clear flag for next command
	mov	auxfile,0		; clear receive-as filename buffer
	mov	flags.xflg,0		; clear to-screen flag
	mov	diskio.string,0		; clear active filename buffer
	mov	fsta.xname,0		; clear statistics external name
	mov	termserver,0
	; do not clear decbuf; it is needed to see remote command response.
	mov	encbuf,0
	call	clrbuf			; drain comms channel of extra junk
	clc				; return to ultimate caller, success
	ret
dispatch endp

;	Receive routines
 
; Receive initiate packet (tolerates I E F M S X Y types)
RINIT	PROC	NEAR
	mov	ax,18			; 18.2 Bios ticks per second
	mul	trans.stime		; byte, seconds
	mov	k_rto,ax		; round trip timeout, Bios ticks
	mov	windlow,0		; lowest acceptable packet number
	mov	trans.chklen,1		; Use 1 char for init packet
	mov	chkparflg,1		; check for unexpected parity
	call	rcvpak			; get a packet
	jnc	rinit2			; nc = success
	ret

rinit2:	mov	ah,[si].pktype		; examine packet type
	cmp	ah,'S'			; Send initiate packet?
	je	rinit6			; e = yes, process 'S' packet
	cmp	ah,'M'			; Message packet?
	jne	rinit3			; ne = no
	call	msgmsg			; display message
	mov	trans.chklen,1		; send Init checksum is always 1 char
	call	ackpak0			; ack and release packet
	ret

rinit3:	cmp	ah,'I'			; unexpected 'I' packet?
	jne	rinit4			; e = yes, respond
	call	spar			; unexpected I packet, parse info
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
	call	ackpak			; send response
	pop	ax			; restore checksum length
	mov	dtrans.chklen,al	;  to negotiation value
	cmp	streamok,0		; doing streaming?
	je	rinit3a			; e = no
	call	streampr		; put message on formatted screen
rinit3a:ret				; stay in this state

rinit4:	cmp	ah,'F'			; File receive?
	je	rinit5			; e = yes
	cmp	ah,'X'			; File receive to screen?
	je	rinit5			; e = yes
	cmp	ah,'Y'			; ACK to a REMOTE command?
	jne	rinit4a			; ne = no
	call	msgmsg			; show any message in the ACK
	mov	rstate,'C'		; Completed state
	ret

rinit4a:call	bufrel			; release this packet buffer
	ret				;  and ignore it

rinit5:	mov	rstate,'F'		; File header receive state
	ret

					; 'S' packet received
rinit6:	call	spar			; negotiate parameters
	push	si
	mov	si,offset rpacket	; build response in this packet
	call	rpar			; report negotiated parameters
	pop	si
	mov	ah,trans.chklen		; negotiated checksum length
	push	ax			; save it
	mov	trans.chklen,1		; use 1 char for init packet reply
	mov	rstate,'F'		; set state to file header
	call	ackpak			; ack with negotiated data
	pop	ax			; recover working checksum
	mov	trans.chklen,ah
	mov	cx,trans.rlong		; negotiated length of received pkts
	call	makebuf			; remake buffering for new windowing
	call	packlen			; compute packet length
	cmp	streamok,0		; doing streaming?
	je	rinit7			; e = no
	call	streampr		; put message on formatted screen
rinit7:	ret				; stay in this state
	ret
RINIT	ENDP
 

; Receive file header (tolerates E F M X Z types)
 
RFILE	PROC	NEAR
	call	rcvpak			; receive next packet
	jnc	rfile1			; nc = success
	ret

rfile1: cmp	[si].pktype,'Z'		; EOF?
	jne	rfile2			; ne = no, try next type
	mov	rstate,'Z'		; change to EOF state, SI is valid pkt
	ret

rfile2: cmp	[si].pktype,'F'		; file header (F or X packet)?
	je	rfile3			; e = yes, 'F' pkt
	cmp	[si].pktype,'X'		; visual display header?
	jne	rfile5			; ne = neither one
	mov	flags.xflg,1		; 'X', say receiving to the screen

rfile3:	mov	filopn,0		; assume not writing to a disk file
	call	dodec			; decode packet
	call	cxmsg			; clear Last Message line
	xor	al,al			; say starting receive operation
	call	begtim			; start statistics gathering
	mov	al,dtrans.xchset	; reset Transmission char set
	mov	trans.xchset,al		;  to the current user default
	mov	ax,permchrset		; permanent character set (Code Page)
	mov	flags.chrset,ax		; active character set
	mov	si,offset decbuf
	mov	di,offset rdbuf+cmdblen-65 ; holding spot for original name
	call	strcpy			; copy to holding spot
	call	gofil			; open the output file
	jnc	rfile4			; nc = success
	jmp	giveup			; failure, dx has message pointer

rfile4:	push	si
	push	di
	mov	si,offset decbuf	; local filename is here
	mov	di,offset encbuf	; destination is encoding buffer
	mov	byte ptr [di],' '	; leave space for protocol char
	inc	di			;  so other Kermits do not react
	call	strcpy			; copy it, to echo local name to host
	dec	di
	mov	dx,di
	call	strlen			; get length to cx for doenc
	mov	si,offset rpacket	; use this packet buffer
	call	doenc			; encode buffer, cx gets length
	pop	di
	pop	si
	call	ackpak			; ack the packet, with filename
	call	filekind		; report Text/Bin, char set
	mov	rstate,'D'		; set the state to data receive
	ret

rfile5:	mov	ah,[si].pktype		; get reponse packet type
	cmp	ah,'B'			; 'B' End Of Transmission?
	jne	rfile6			; ne = no
	mov	rstate,'C'		; set state to Complete
	jmp	ackpak0			; ack the packet

rfile6:	cmp	ah,'M'			; Message packet?
	jne	rfile7			; ne = no
	call	msgmsg			; display message
	jmp	ackpak0			; ack packet, stay in this state

rfile7:	call	bufrel			; release buffer
	ret				;  and ignore unknown packet
RFILE	ENDP

; Get file attributes from packet
; Recognize file size in bytes and kilobytes (used if bytes missing),
; file time and date. Reject Mail commands. Return carry clear for success,
; carry set for failure. If rejecting place reason code in byte attrib.

GETATT	PROC	NEAR
	mov	attrib,' '		; clear failing attribute code
	push	es
	les	bx,[si].datadr		; pointer to data field
getat0:	push	bx
	sub	bx,word ptr [si].datadr ; bx => length examined
	cmp	bx,[si].datlen		; more than supplied data?
	pop	bx
	jl	getat1			; l = not yet
	pop	es
	clc
	ret				; has carry clear for success

getat1:	mov	al,es:[bx]		; get attribute kind
	mov	attrib,al		; store for failure report

	cmp	al,'1'			; Byte length field?
	jne	getat2			; ne = no
	test	flags.attflg,attlen	; allowed to examine file length?
	jnz	getat1b			; nz = yes
getat1a:jmp	getatunk		; z = no, ignore
getat1b:inc	bx			; step to length of field byte
	call	getas			; get file size from packet
	jc	getat1a			; c = failed to decode properly
	call	spchk			; check available disk space
	jnc	getat0			; nc = have enough space for file
	pop	es
	ret				; return failure

getat2:	cmp	al,'!'			; Kilobyte length field?
	jne	getat3			; ne = no
	test	flags.attflg,attlen	; allowed to examine file length?
	jnz	getat2b			; nz = yes
getat2a:jmp	getatunk		; z = no, ignore
getat2b:inc	bx			; step to length of field byte
	call	getak			; get file size from packet
	jc	getat2a			; carry means decode rejected
	call	spchk			; check available disk space
	jnc	short getat0		; nc = have enough space
	pop	es
	ret				; return failure

getat3:	cmp	al,'#'			; date field?
	jne	getat4			; ne = no
	mov	word ptr ftime,0	; clear time and date fields
	mov	word ptr fdate,0
	test	flags.attflg,attdate	; allowed to update file date/time?
	jnz	getat3a			; nz = yes
	jmp	getatunk		; z = no, ignore
getat3a:inc	bx			; point at length of field
	call	getatd			; get file date
	jnc	short getat0
	pop	es
	ret				; return failure

getat4:	cmp	al,'+'			; Disposition?
	jne	getat5			; ne = no
	mov	ax,es:[bx+1]		; count byte, disposition byte
	cmp	ah,'M'			; Mail indicator?
	je	getat4d			; e = yes, fail
	cmp	ah,'P'			; REMOTE PRINT?
	jne	getat4b			; ne = no
	test	flags.remflg,dserver	; acting as a server now?
	jz	getat4a			; z = no
	test	denyflg,prtflg		; is this server command disabled?
	jnz	getat4d			; nz = yes, disabled
getat4a:mov	word ptr diskio.string,'RP'	; output to PRN
	mov	word ptr diskio.string+2,'N' 	; ignore options
	inc	bx			; step to data field
	sub	al,20h			; count byte bias removal
	xor	ah,ah
	add	bx,ax			; step to next attribute
	jmp	getat0

getat4b:cmp	ah,'R'			; Restart?
	jne	getat4c			; ne = no
	or	restart_flag,1		; say restarting
getat4c:jmp	getatunk		; ignore field

getat4d:stc				; set carry for failure
	pop	es
	ret

getat5:	cmp	al,'"'			; File Type?
	jne	getat6			; ne = no
       	test	flags.attflg,atttype	; allowed to examine file type?
	jnz	getat5a			; nz = yes
	jmp	getatunk		; z = no, ignore field
getat5a:inc	bx			; step to length of field byte
	xor	ch,ch
	mov	cl,es:[bx]		; get length
	inc	bx
	mov	ax,es:[bx]		; data
	sub	cl,20h			; remove ascii bias
	jc	getat5d			; c = error in length, fail
	add	bx,cx			; step to next field
	cmp	al,'A'			; Type letter (A, B, I), Ascii?
	jne	getat5b			; ne = no
	mov	trans.xtype,0		; say Ascii/Text file type
	jmp	getat0			; next item please
getat5b:cmp	al,'B'			; "B" Binary?
	jne	getat5d			; ne = no, fail
	cmp	cl,2			; full "B8"?
	jb	getat5c			; b = no, just "B"
	cmp	ah,'8'			; proper length?
	jne	getat5d			; ne = no
getat5c:mov	trans.xtype,1		; say Binary
	or	restart_flag,2		; restart, remember binary mode
	jmp	getat0			; next item please
getat5d:stc				; set carry for rejection
	pop	es
	ret

getat6:	cmp	al,'*'			; character set usage?
	jne	getat8			; ne = no
	test	flags.attflg,attchr	; allowed to examine char-set?
	jnz	getat6a			; nz = yes
getat6d:jmp	getatunk		; z = no, ignore

getat6a:inc	bx			; step to length field
	mov	cl,es:[bx]		; get length
	sub	cl,' '			; remove ascii bias
	js	getat6c			; c = length error, fail
	xor	ch,ch
	inc	bx			; first data byte
	mov	al,es:[bx]
	mov	trans.xchset,0		; assume Transparent Transfer char-set
	cmp	al,'A'			; Normal Transparent?
	jne	getat6b			; be = not Transparent
	add	bx,cx			; point to next attribute
	jmp	getat0
getat6b:cmp	al,'C'			; character set?
	je	getat7			; e = yes
getat6c:stc				; set carry for rejection
	pop	es
	ret
getat7:	push	di			; examine transfer character set
	push	si
	mov	di,bx			; point at first data character
	add	bx,cx			; point to next attribute
	push	bx			; save bx
	dec	cx			; deduct leading 'C' char from count
	inc	di			; skip the 'C'
	mov	bx,offset charids	; point to array of char set info
	mov	ax,[bx]			; number of members
	mov	temp,ax			; loop counter
	mov	trans.xchset,xfr_xparent ; assume xfer char set Transparent
getat7a:add	bx,2			; point to a member's address
	mov	si,[bx]			; point at member [length, string]
	cmp	cl,[si]			; string lengths the same?
	jne	getat7b			; ne = no, try the next member
	inc	si			; point at ident string
	cld
	push	cx			; save incoming count
	push	di			; save incoming string pointer
	repe	cmpsb			; compare cx characters
	pop	di
	pop	cx
	je	getat7d			; e = idents match
getat7b:inc	trans.xchset		; try next set
	dec	temp			; one less member to consider
	jnz	getat7a			; nz = more members to try
	pop	bx			; failure to find a match
	pop	si
	pop	di
	mov	trans.xchset,xfr_xparent; use Transparent for unknown char set
	cmp	flags.unkchs,0		; keep the file?
	je	getat7c			; e = yes, regardless of unk char set
	pop	es
	stc				; set carry for rejection
	ret
getat7c:clc
	jmp	getat0			; report success anyway

getat7d:pop	bx			; a match, use current trans.xchset
	pop	si
	pop	di
	cmp	trans.xchset,xfr_cyrillic ; using Transfer Char Set Cyrillic?
	jne	getat7e			; ne = no
	mov	flags.chrset,866	; force CP866 (required by Cyrillic)
	clc
	jmp	getat0
getat7e:cmp	trans.xchset,xfr_japanese ; using Trans Char Set Japanese-EUC?
	jne	getat7f			; ne = no
	mov	flags.chrset,932	; force Shift-JIS
	jmp	getat0			; success
getat7f:cmp	trans.xchset,xfr_latin2	; using Trans Char Set Latin-2?
	jne	getat7g			; ne = no
	mov	flags.chrset,852	; force CP852
	jmp	getat0			; success
getat7g:cmp	trans.xchset,xfr_hebiso	; using Hebrew-ISO?
	jne	getat7h			; ne = no
	mov	flags.chrset,862	; force CP862
getat7h:jmp	getat0

getat8:	cmp	al,'@'			; attribute count of zero?
	jne	getatunk		; ne = no
	inc	bx			; step to length field
	mov	al,es:[bx]		; length
	inc	bx			; set to data field
	cmp	al,' '			; End of Attributes code?
	jne	getatunk		; ne = no
	test	restart_flag,1		; has Restart been requested?
	jz	getat8b			; z = no
	test	restart_flag,2		; and Binary transfer requested?
	jnz	getat8b			; nz = yes, that's fine
	mov	attrib,'+'		; failure reason is disposition
getat8a:pop	es
	stc				; fail 
	ret
getat8b:clc				; success, end attributes analysis
	pop	es
	ret


					; workers for above
getatunk:inc	bx			; Unknown. Look at length field
	mov	al,es:[bx]
	sub	al,' '			; remove ascii bias
	xor	ah,ah
	inc	ax			; include length field byte
	add	bx,ax			; skip to next attribute
	jmp	getat0

					; Decode File length (Byte) field
getas:	mov	cl,es:[bx]		; length of file size field
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
	mov	diskio.sizelo,ax	; low order word
	mov	diskio.sizehi,dx	; high order word
	clc
	ret
getas3:	sub	bx,2			; backup to attribute kind
	stc				; fail the decode
	ret
					; Decode Kilobyte attribute worker
getak:	mov	ax,diskio.sizelo	; current filesize, low word
	add	ax,diskio.sizehi
	or	ax,ax			; zero if not used yet
	jz	getak1			; z = not used before
	dec	bx			; backup pointer to attribute kind
	stc				; set carry to ignore this field
	ret

getak1:	call	getas			; parse as if Byte field
	jnc	getak2			; nc = parsed ok
	ret				; c = failure
getak2:	mov	ax,diskio.sizelo	; get low word of size
	mov	dx,diskio.sizehi	; high word
	mov	dh,dl			; times 256
	mov	dl,ah
	mov	ah,al
	xor	al,al
	shl	dx,1			; times four to make times 1024
	shl	dx,1
	rol	ax,1			; two high bits of ah to al
	rol	ax,1
	and	al,3			; keep them
	or	dl,al			; insert into high word
	xor	al,al
	mov	diskio.sizehi,dx	; store high word
	mov	diskio.sizelo,ax	; store low word
	clc				; clear carry
	ret
					; File date and time worker
getatd:	mov	word ptr ftime,1	; two seconds past midnight
	mov	word ptr fdate,0
	mov	dl,es:[bx]		; field length
	xor	dh,dh
	sub	dl,' '			; remove ascii bias
	inc	bx			; next field
	add	dx,bx			; where next field begins
	mov	temp,dx			; save in temp
	cmp	byte ptr es:[bx+6],' '	; short form date (yymmdd)?
	je	getad1			; e = yes, get current century
	mov	dx,es:[bx]		; get century digits
	sub	dx,'00'			; subtract ascii bias
	mov	al,10
	mul	dl
	add	al,dh			; dh has units
	sub	al,19
	add	bx,2			; skip to year pair
	jmp	getad2

getad1:	mov	ah,getdate		; DOS date (cx= yyyy, dh= mm, dl= dd)
	int	dos
	mov	ax,cx
	xor	dx,dx
	div	ten
	xor	dx,dx
	div	ten			; truncate to centuries
	sub	al,19			; remove 19 bias, current century
getad2:	mul	ten			; al has centuries - 19
	mul	ten			; centuries equal 100 years
	mov	cl,al			; keep results in cl
	mov	dx,es:[bx]		; get year tens and units digits
	add	bx,2			; dl has tens, dh has units
	sub	dx,'00'			; remove ascii bias
	mov	ax,10
	mul	dl			; ax = high digit times ten
	add	al,dh			; units digit
	add	al,cl			; add centuries since 1900
	sub	ax,80			; remove rest of 1980 bias
	jns	getad2a			; ns = no sign = non-negative result
	xor	ax,ax			; don't store less than 1980
getad2a:cmp	ax,128			; beyond 2108? (1980 + 128)
	jb	getad2c			; b = no
	stc				; fail
	ret

getad2c:shl	al,1			; adjust for DOS bit format
	mov	fdate+1,al		; binary years after 1980
	mov	ax,es:[bx]		; get month digits
	add	bx,2
	sub	ax,'00'			; remove ascii bias
	or	al,al			; tens digit set?
	jz	getad2b			; z = no
	add	ah,10			; add to units digit
getad2b:cmp	ah,8			; high bit of month set?
	jb	getad3			; b = no
	or	fdate+1,1
	sub	ah,8			; and deduct it here
getad3:	mov	cl,5
	shl	ah,cl			; normalize months bits
	mov	fdate,ah
	mov	dx,es:[bx]		; do day of the month
	add	bx,2			; dh has units, dl has tens digit
	sub	dx,'00'			; remove ascii bias
	mov	ax,10
	mul	dl			; ax = ten times tens digit
	add	al,dh			; plus units digit
	or	fdate,al
	cmp	bx,temp			; are we at the end of this field?
	jae	getad5			; ae = yes, prematurely
	inc	bx			; skip space separator
	mov	ax,10			; prepare for hours
	mov	dx,es:[bx]		; hh digits
	add	bx,2
	sub	dx,'00'			; remove ascii bias
	mul	dl			; 10*high digit of hours
	add	al,dh			; plus low digit of hours
	mov	cl,3			; normalize bits
	shl	al,cl
	mov	ftime+1,al		; store hours
	inc	bx			; skip colon
	mov	ax,10			; prepare for minutes
	mov	dx,es:[bx]		; mm digits
	add	bx,2
	sub	dx,'00'			; remove ascii bias
	mul	dl			; 10*high digit of minutes
	add	al,dh			; plus low digit of minutes
	xor	ah,ah
	mov	cl,5			; normalize bits
	shl	ax,cl
	or	ftime+1,ah		; high part of minutes
	mov	ftime,al		; low part of minutes
	cmp	bx,temp			; are we at the end of this field
	jae	getad5			; ae = yes, quit here
	inc	bx			; skip colon
	mov	ax,10			; prepare for seconds
	mov	dx,es:[bx]		; ss digits
	add	bx,2
	sub	dx,'00'			; remove ascii bias
	mul	dl			; 10*high digit of seconds
	add	al,dh			; plus low digit of seconds
	shr	al,1			; store as double-seconds for DOS
	or	ftime,al		; store seconds
getad5:	cmp	flags.flwflg,filecol_update ; updating?
	jne	getad6			; ne = no
	cmp	filopn,2		; file opened yet?
	je	getad6			; e = yes
	call	goopen			; open it now
	mov	filopn,2		; file is open (carry set for fail)
	mov	bx,temp			; point to next attribute
	ret
getad6:	mov	bx,temp			; point to next attribute
	clc				; success
	ret
GETATT	ENDP
 
; Receive data (tolerates A D E M Z types)
 
RDATA	PROC	NEAR
	call	rcvpak			; get next packet
	jnc	rdata1			; nc = success
	ret				; else return to do new state

rdata1:	mov	ah,[si].pktype		; check packet type
	cmp	ah,'D'			; Data packet?
	je	rdata3			; e = yes
	cmp	ah,'A'			; Attributes packet?
	je	rdata4			; e = yes
	cmp	ah,'M'			; Message packet?
	jne	rdat2			; ne = no
	call	msgmsg			; display message
	jmp	ackpak0			; ack the packet, stay in this state

rdat2:	cmp	ah,'Z'			; EOF packet?
	jne	rdat2a			; ne = no
	mov	rstate,'Z'		; next state is EOF, do not ack yet
	ret

rdat2a:	call	bufrel			; Unknown packet type, release buffer
	ret				;  and ignore it
					; D data packets
rdata3:	mov	fsta.xstatus,kssuc	; set status, success
	mov	kstatus,kssuc		; global status, success
	mov	al,streamok
	mov	dostream,al		; engage possible streaming mode
	test	restart_flag,1		; restart negotiations completed?
	jnz	rdat3c			; nz = no, give up
	cmp	filopn,2		; file opened yet?
	je	rdata3b			; e = yes
	call	goopen			; open it now
	jnc	rdata3a			; nc = success
	jmp	giveup			; failure, dx has message pointer
rdata3a:mov	filopn,2		; say file is open now
rdata3b:call	ptchr			; decode 'D' packet, output to file
	jc	rdat3c			; c = failure to write output
	jmp	ackpak0			; ack the packet, stay in this state

rdat3c:	mov	dx,offset erms11	; cannot store all the data
	jmp	giveup			; tell the other side

		     			; 'A' packet, analyze		
rdata4:	cmp	flags.flwflg,filecol_discard ; no-supersede existing file?
	jne	rdata4e			; ne = no
	cmp	flags.cxzflg,'X'	; file being refused from collision?
	jne	rdata4e			; ne = no
	mov	attrib,'?'		; say filename collision occured (?)
	mov	flags.cxzflg,0		; and clear this flag
	jmp	short rdata4c		; and refuse file via attributes too
	
rdata4e:call	getatt			; get file attributes from packet
	mov	cx,0			; reply length, assume 0/nothing
	jnc	rdat4b			; nc = success, attributes accepted
rdata4c:mov	cx,2			; 2 bytes, declining the file
	mov	encbuf,'N'		; decline the transfer
	mov	al,attrib		; get attribute causing rejection
	mov	encbuf+1,al		; report rejection reason to sender
	mov	fsta.xstatus2,al	; remember attributes reason
	cmp	al,'#'			; date/time?
	jne	rdata4g			; ne = no
	mov	flags.cxzflg,0		; don't say failure
	mov	kstatus,kssuc
	mov	fsta.xstatus,kssuc
	jmp	short rdata4f
rdata4g:or	fsta.xstatus,ksrecv+ksattrib ; set status, failed, attributes
	mov	kstatus,ksrecv+ksattrib	; global status, failed, attributes
rdata4f:test	flags.remflg,dquiet	; quiet display?
	jnz	rdat4b			; nz = yes
	push	si
	push	cx
	push	ax
	mov	dx,offset erms29	; say rejecting the file
	call	ermsg			; show rejecting file, then reason
	pop	ax
	mov	dx,offset ferbyte
	cmp	al,'1'			; Byte count?
	je	rdat4a			; e = yes
	cmp	al,'!'			; Kilobyte count?
	je	rdat4a			; e = yes
	mov	dx,offset ferdate
	cmp	al,'#'			; Date and Time?
	je	rdat4a			; e = yes
	mov	dx,offset ferdisp
	cmp	al,'+'			; Disposition?
	je	rdat4a			; e = yes
	mov	dx,offset fertype
	cmp	al,'"'			; File Type?
	je	rdat4a
	mov	dx,offset ferchar
	cmp	al,'*'			; Transfer Char-set?
	je	rdat4a
	mov	dx,offset fername
	cmp	al,'?'			; filename collision?
	je	rdat4a			; e = yes
	mov	dx,offset ferunk	; unknown reason
rdat4a:	call	prtasz			; display reason
	pop	cx
	pop	si
					; Restart check, multiple A pkts ok
rdat4b:	test	restart_flag,2		; Binary mode requested?
	jz	rdat6			; z = no
	test	restart_flag,1		; Restart and Binary requested?
	jz	rdat6			; z = no

rdat4d:	mov	cl,flags.flwflg		; Restart OK, save warning flag state
	push	cx			; reg ax is needed for DX:AX in goopen
	mov	flags.flwflg,filecol_append ; append to existing file
	mov	di,offset decbuf
	mov	byte ptr [di+64],0	; force in null terminator
	mov	si,offset rdbuf+cmdblen-65 ; holding spot for original name
	call	strcpy			; copy from holding spot
	push	diskio.sizelo
	push	diskio.sizehi
	call	gofil			; regularize name again
	pop	diskio.sizehi
	pop	diskio.sizelo
	call	goopen			; open the file, DX:AX gets length
	pop	cx			; recover file warning flag state
	mov	flags.flwflg,cl		; restore state
	jnc	rdat5			; nc = success
	jmp	giveup			; failure, dx has message pointer
rdat5:	mov	filopn,2		; say file is open now
	mov	restart_flag,0		; clear so first D pkt can proceed
	mov	tfilsz,ax		; count file chars
	mov	tfilsz+2,dx
	push	ax
	push	dx
	call	kbpr			; show transfer percentages
	call	perpr
	pop	dx
	pop	ax
	push	di
	mov	di,offset encbuf	; response buffer
	mov	byte ptr [di],'1'	; file length (Bytes) specifier
	add	di,2			; skip specifier and count bytes
	call	lnout			; convert file length, write to [di++]
	mov	cx,di			; compute field length
	sub	cx,offset encbuf	; total field for ACK
	mov	al,cl
	add	al,30			; (32-2) string length to ascii
	mov	encbuf+1,al		; length of file size string for doenc
	push	si
	push	es
	mov	si,offset encbuf
	mov	rpacket.datlen,cx	; size of data field
	les	di,rpacket.datadr
	cld
	rep	movsb			; copy to packet unencoded
	pop	es
	pop	si
	pop	di
	jmp	rcvpat2

rdat6:	push	si
	mov	si,offset rpacket	; encode to this packet
	call	doenc			; do encoding
	pop	si
rcvpat2:call	filekind		; report Text/Bin, char set
	jmp	ackpak			; ACK the attributes packet
rdata endp

; End of File processor (expects Z type to have been received elsewhere)
; Enter with packet pointer in SI to a 'Z' packet.
reof	proc	near			; 'Z' End of File packet
	cmp	flags.cxzflg,0		; interrupted?
	je	reof5			; e = no
	call	intmsg			; show interrupt msg on local screen
	or	errlev,ksrecv		; set DOS error level
	or	fsta.xstatus,ksrecv+ksuser ; set status, failed + intervention
	mov	kstatus,ksrecv+ksuser	; global status
	cmp	flags.cxzflg,'X'	; kill one file?
	jne	reof5			; ne = no
	mov	flags.cxzflg,0		; clear ^X so next file survives
					; common code for file closing
reof5:	call	dodec			; decode incoming packet to decbuf
	cmp	decbuf,'D'		; is the data "D" for discard?
	je	reof6			; e = yes, delete file
	cmp	filopn,2		; file opened yet?
	je	reof5b			; e = yes
	call	goopen			; open it now (zero length file)
	jnc	reof5a			; nc = success
	push	dx
	call	logtransact
	pop	dx
	jmp	giveup			; failure, dx has message pointer
reof5a:	mov	filopn,2		; say file is open now
reof5b:	call	fileclose		; close the file
	jmp	short reof7

reof6:	cmp	filopn,2		; is the file open?
	jne	reof7			; ne = no, declare success anyway
	call	fileclose		; close the file
	call	filedel			; delete file incomplete file
reof6a:	or	errlev,ksrecv		; set DOS error level
	or	fsta.xstatus,ksrecv+ksuser ; set status, failed + intervention
	mov	kstatus,ksrecv+ksuser	; global status

reof7:	mov	rstate,'F'
	call	ackpak0			; acknowledge the packet
	call	logtransact
	mov	diskio.string,0		; clear file name
	cmp	flags.cxzflg,'Z'	; stop file group?
	je	reof8			; e = yes
	mov	flags.cxzflg,0		; else clear it
reof8:	ret
reof	endp

; init variables for read
rrinit	proc	near
	mov	trans.windo,1		; one window slot before negotiations
	mov	cx,drpsiz		; default receive pkt length (94)
	call	makebuf			; construct & clear all buffer slots
	call	packlen			; compute packet length
	xor	ax,ax
	mov	numpkt,ax		; set the number of packets to zero
	mov	windlow,al		; starting sequence number of zero
	mov	fsta.pretry,ax		; set the number of retries to zero
	mov	filopn,al		; say no file opened yet
	mov	windflag,al		; windows in use init flag
	mov	fmtdsp,al		; no formatted display yet
	mov	diskio.string,al	; clear active filename buffer
	mov	fsta.xname,al		; clear statistics external name
	mov	restart_flag,al		; restart file xfer to no
	ret
rrinit	endp

; Deliver packets organized by sequence number.
; Delivers a packet pointer in SI whose sequence number matches windlow.
; If necessary a new packet is requested from the packet recognizer. Failures
; to receive are managed here and may generate NAKs. Updates formatted screen.
; Store packets which do not match windlow, process duplicates and strays.
; Error packet and ^C/^E interrupts are detected and managed here.
; Return success with carry clear and SI holding the packet structure address.
; Return failure with carry set, maybe with a new rstate.

rcvpak	proc	near
	mov	al,windlow		; sequence number we want
	call	pakptr			; find pkt pointer with this seqnum
	mov	si,bx			; the packet pointer
	jnc	rcvpa1a			; nc = got one, else read fresh pkt
	push	ax
	mov	al,trans.windo		; number of window slots negotiated
	mov	cwindow,al		; assign as receive window 
	pop	ax
	call	getbuf			; get a new buffer address into si
	jnc	rcvpa1			; nc = success
	mov	dx,offset erms15	; insufficient buffers
	jmp	giveup

rcvpa1:	call	winpr			; show window slots in use
	call	rpack			; receive a packet, si has buffer ptr
	jc	rcvpa2			; c = failure to receive, analyze
	inc	numpkt			; increment the number of packets
	cmp	flags.xflg,0		; receiving to screen?
	jne	rcvpa1a			; ne = yes, skip displaying
	cmp	flags.destflg,dest_screen ; destination is screen?
	je	rcvpa1a			; e = yes
	call	pktsize			; report packet qty and size
rcvpa1a:jmp	rcvpa6			; success, validate
; ------------------- failure to receive any packet -------------------------
					; Reception failed. What to do?
rcvpa2:	call	cntretry		; update retries, detect ^C, ^E
	jc	rcvpa2a			; c = exit now from ^C, ^E
	call	bufrel			; discard unused buffer
	inc	badrcv			; count receive retries
	cmp	dostream,0		; streaming mode negotiated?
	jne	rcvpa2b			; ne = yes, fail reception now
	mov	al,badrcv		; count # bad receptions in a row
	cmp	al,maxtry		; too many?
	jb	rcvpa4			; b = not yet, NAK intelligently
rcvpa2b:mov	dx,offset erms14	; no response from host
	jmp	giveup			; tell the other side

rcvpa2a:call	bufrel			; discard unwanted buffer
	stc				; set carry for failure
	ret				; move to Error state

					; do NAKing
rcvpa4:	mov	al,windlow		; Timeout or Crunched packet
	add	al,trans.windo		; find next slot after last good
	dec	al
	and 	al,3fh			; start at window high
	mov	ah,-1			; set a not-found marker
	mov	cl,trans.windo		; cx = number of slots to examine
	xor	ch,ch
rcvpa4a:call	pakptr			; sequence number (in AL) in use?
	jnc	rcvpa4b			; nc = yes, stop here
	mov	ah,al			; remember seqnum of highest vacancy
	dec	al			; work backward in sequence numbers
	and	al,3fh
	loop	rcvpa4a

rcvpa4b:mov	al,ah			; last-found empty slot (-1 = none)
	cmp	ah,-1			; found a vacant slot?
	jne	rcvpa4c			; ne = no, else use first free seqnum
	call	firstfree		; set AL to first open slot
	jc	rcvpa4d			; c = no free slots, an error
rcvpa4c:mov	rpacket.seqnum,al	; NAK this unused sequence number
	call	nakpak			; NAK using rpacket
	jc	rcvpa4d			; c = failure on sending operation
	stc				; rcv failure, stay in current state
	ret

rcvpa4d:mov	dx,offset erms13	; failure, cannot send reply
	jmp	giveup			; show msg, change states
; ------------------------- received a packet ------------------------------
			; remove duplicates, validate sequence number
rcvpa6:	mov	badrcv,0		; clear retry counter
	cmp	[si].pktype,'E'		; Error packet? Accept w/any seqnum
	jne	rcvpa6a			; ne = no
	call	error			; display message, change states
	stc
	ret
rcvpa6a:mov	al,[si].seqnum		; this packet's sequence number
	mov	rpacket.seqnum,al	; save here for reply
	call	pakdup			; set ah to number of copies
	cmp	ah,1			; more than one copy?
	jbe	rcvpa7			; be = no, just one
	call	bufrel			; discard duplicate
	mov	al,rpacket.seqnum	; recover current sequence number
	call	pakptr			; get packet pointer for original
	mov	si,bx			; should not fail if pakdup works ok
	jnc	rcvpa7			; nc = ok, work on the original again
	ret				; say failure, stay in current state

rcvpa7:	call	chkwind			; validate sequence number (cx=status)
	jc	rcvpa7b			; c = outside current window
	mov	al,[si].seqnum		; get sequence number again
	cmp	al,windlow		; is it the desired sequence number?
	jne	rcvpa7a			; ne = no, do not change states yet
	clc
	ret				; return success, SI has packet ptr

rcvpa7a:stc				; not desired pkt, stay in this state
	ret				; do not increment retry counter here

rcvpa7b:or	cx,cx			; inside previous window?
	jg	rcvpa7c			; g = outside any window, ignore it
	mov	al,[si].pktype		; get packet Type
	cmp	al,'I'			; let 'I' and 'S' pkts be reported
	je	rcvpa7d			; even if in previous window, to
	cmp	al,'S'			; accomodate lost ack w/data
	je	rcvpa7d
	cmp	al,'Y'			; maybe our ACK echoed?
	je	rcvpa7c			; e = yes, discard
	cmp	al,'N'			; or our NAK echoed?
	je	rcvpa7c			; e = yes, discard
	call	ackpak0			; previous window, ack and ignore it
	stc				; rcv failure, stay in current state
	ret

rcvpa7c:call	bufrel			; ignore packet outside of any window
	stc				; rcv failure, stay in current state
	ret

rcvpa7d:mov	rstate,'R'		; redo initialization when 'I'/'S'
	stc				;  are observed, keep current pkt
	ret
rcvpak	endp

; Send ACK packet. Enter with rpacket data field set up.
; ACKPAK sends ack with data, ACKPAK0 sends ack without data.
ackpak	proc	near			; send an ACK packet
	cmp	rpacket.datlen,0	; really just no data?
	jne	ackpa2			; ne = no, send prepared ACK packet

ackpak0:mov	rpacket.datlen,0	; no data
	cmp	flags.cxzflg,0		; user interruption?
	je	ackpa2			; e = no
	push	cx			; yes, send the interrupt character
	push	si
	mov	si,offset rpacket
	mov	cl,flags.cxzflg		; send this so host knows about ^X/^Z
	mov	encbuf,cl		; put datum into the encode buffer
	mov	cx,1			; data size of 1 byte
	call	doenc			; encode, char count is in cx
	pop	si
	pop	cx
ackpa2:	mov	rpacket.pktype,'Y'	; ack packet
	mov	rpacket.numtry,0
ackpa3:	cmp	flags.cxzflg,0		; user interruption?
	jne	ackpa3b			; ne = yes
	cmp	dostream,0		; streaming mode negotiated?
	jne	ackpa4			; ne = yes, simulate succesful send
ackpa3b:push	si
	mov	si,offset rpacket
	call	spack			; send the packet
	pop	si
	jnc	ackpa4			; nc = success
	cmp	flags.cxzflg,'C'	; Control-C abort?
	je	ackpa3a			; e = yes, quit now
	cmp	flags.cxzflg,'E'	; Control-E abort?
	je	ackpa3a			; e = yes, quit now
	push	ax			; send failure, retry
	mov	ax,100			; 0.1 sec
	call	pcwait			; small wait between retries
	inc	rpacket.numtry
	mov	al,rpacket.numtry
	cmp	al,maxtry		; exceeded retry limit?
	pop	ax
	jbe	ackpa3			; be = ok to try again
	mov	sstate,'A'		; set states to abort
	mov	rstate,'A'
	mov	rpacket.numtry,0
	mov	dx,offset erms13	; unable to send reply
	jmp	giveup
ackpa3a:stc				; set carry for failure
	ret

ackpa4:
	cmp	dostream,0		; streaming mode negotiated?
	je	ackpa4a			; e = no
	mov	flags.cxzflg,0		; so we don't repeat CXZ ACK send
ackpa4a:mov	al,rpacket.seqnum	; success
	mov	rpacket.datlen,0	; clear old contents
	call	pakptr			; acking an active buffer?
	jc	ackpa5			; c = no such seqnum, stray ack
	push	si
	mov	si,bx			; packet pointer from pakptr
	call	bufrel			; release ack'ed packet
	pop	si
	mov	rpacket.numtry,0
	cmp	al,windlow		; acking window low?
	jne	ackpa5			; ne = no
	mov	al,windlow		; yes, rotate the window
	inc	al
	and	al,3fh
	mov	windlow,al
ackpa5:	clc
	ret
ackpak	endp

; Send a NAK. Uses rpacket structure.
NAKPAK	proc	near
	mov	rpacket.numtry,0
nakpa2:	push	si
	mov	si,offset rpacket
	mov	[si].datlen,0		; no data
	inc	fsta.nakscnt		; count NAKs sent
        mov	[si].pktype,'N'		; NAK that packet
	cmp	dostream,0		; streaming mode negotiated?
	je	nakpa2a			; e = no, send the packet
	clc				; simulate successful send
	jmp	short nakpa2b		;  do not send NAK
nakpa2a:call	spack
nakpa2b:pop	si
	jc	nakpa3			; c = failure
	mov	rpacket.numtry,0
	clc
	ret				; return success

nakpa3:	cmp	flags.cxzflg,'C'	; Control-C abort?
	je	nakpa3a			; e = yes, quit now
	cmp	flags.cxzflg,'E'	; Control-E abort?
	je	nakpa3a			; e = yes, quit now
	push	ax			; send failure, retry
	mov	ax,100			; wait 0.1 second
	call	pcwait
	inc	rpacket.numtry		; count attempts to respond
	mov	al,rpacket.numtry
	cmp	al,maxtry		; tried enough times?
	pop	ax
	jbe	nakpa2			; be = ok to try again
	mov	sstate,'A'		; set states to abort
	mov	rstate,'A'
	mov	rpacket.numtry,0
	mov	dx,offset erms13	; unable to send reply
	jmp	giveup
nakpa3a:stc
	ret				; return failure
NAKPAK	ENDP

; Close, but do not delete, output file. Update file attributes,
; add Control-Z or Control-L, if needed.
fileclose proc	near
	cmp	filopn,0		; is a file open?
	jne	filec0			; ne = yes
	ret
filec0:	cmp	flags.xflg,0		; receiving to screen?
	jne	filec2			; ne = yes
	cmp	flags.destflg,dest_disk ; destination is disk?
	jne	filec1			; ne = no
	cmp	flags.eofcz,0		; should we write a ^Z?
	je	filec1			; e = no, keep going
	cmp	trans.xtype,0		; text mode tranfer?
	jne	filec2			; ne = no, binary, no ^Z
	push	si
	mov	rpacket.datlen,1	; one byte to decode and write
	push	es
	les	si,rpacket.datadr	; source buffer address
	mov	byte ptr es:[si],'Z'-40h ; put Control-Z in buffer
	pop	es
	mov	si,offset rpacket	; address for decoder
	call	ptchr			; decode and write to output
	pop	si
filec1:	cmp	flags.destflg,dest_printer ; file destination is printer?
	jne	filec2			; ne = no, skip next part
	push	si
	mov	rpacket.datlen,1	; one byte to decode and write
	push	es
	les	si,rpacket.datadr	; source buffer address
	mov	byte ptr es:[si],'L'-40h ; put Control-L (FF) in buffer
	pop	es
	mov	si,offset rpacket	; address for decoder
	call	ptchr			; decode and write to output
	pop	si
filec2:	mov	ah,write2		; write to file
	xor	cx,cx			; write 0 bytes to truncate length
	mov	bx,diskio.handle	; file handle
	or	bx,bx			; valid handle?
	jl	filec5			; l = no
	int	dos
	xor	al,al			; get device info
	mov	ah,ioctl
	int	dos
	test	dl,80h			; bit set if handle is for a device
	jnz	filec4			; nz = non-disk, no file attributes
					; do file attributes and close
	mov	cx,word ptr ftime	; new time
	mov	dx,word ptr fdate	; new date
	mov	word ptr fdate,0
	mov	word ptr ftime,0	; clear current time/date attributes
	or	dx,dx			; any date?
	jz	filec4			; z = no attributes to set
	or	cx,cx			; time set as null?
	jnz	filec3			; nz = no
	inc	cl			; two seconds past midnight
filec3:	mov	ah,fileattr		; set file date/time attributes
	mov	al,1			; set, not get
	mov	bx,diskio.handle	; file handle
	int	dos			; end of file attributes
filec4:	mov	bx,diskio.handle	; file handle
	push	dx			; save dx
	mov	ah,close2		; close file
	int	dos
	pop	dx
	mov	diskio.handle,-1
	mov	filopn,0		; say file is closed
filec5:	ret
fileclose endp

; Delete file whose asciiz name is in diskio.string
filedel	proc	near
	cmp	flags.flwflg,filecol_update ; update an existing file?
	je	filede2			; e = yes
	mov	dx,offset diskio.string	; file name, asciiz
	xor	ax,ax
	cmp	diskio.string,al	; filename present?
	je	filede2			; e = no
	cmp	flags.abfflg,al		; keep incomplete file?
	je	filede2			; e = yes
	test	flags.remflg,dquiet	; quiet display?
	jnz	filede1			; nz = yes
	cmp	flags.xflg,al		; receiving to screen?
	jne	filede1			; ne = yes, no message
	push	dx
	call	cxmsg			; clear Last message line
	mov	dx,offset infms7	; saying Discarding file
	mov	ah,prstr
	int	dos
	pop	dx
	call	prtasz			; show filename
filede1:mov	ah,del2			; delete the file
	int	dos
filede2:ret
filedel	endp

; Error exit. Enter with dx pointing to asciiz error message.
; Sends 'E' Error packet and shows message on screen. Changes state to 'A'.
; Always returns with carry set.
giveup	proc	near
	cmp	flags.destflg,dest_screen ; receiving to the screen?
	je	giveu1			; e = yes, no formatted display
	call	ermsg			; show msg on error line
giveu1:	mov	bx,dx			; set bx to error message
	call	errpack			; send error packet just in case
	mov	rstate,'A'		; change the state to abort
	stc				; set carry
	ret
giveup	endp

; ERROR sets abort state, positions the cursor and displays the Error message.
 
ERROR	PROC	NEAR
	mov	rstate,'A'		; set state to abort
	call	dodec			; decode to decbuf
	mov	dx,offset decbuf	; where msg got decoded, asciiz
	call	ermsg			; show string
	stc				; set carry for failure state
	ret
ERROR	ENDP

; Called by GETATT in receiver code to verify sufficient disk space.
; Gets file path from diskio.string setup in mssfil, remote size in diskio
; from getatt, and whether a disk file or not via ioctl on the file handle.
; Returns carry clear if enough space.
spchk	proc	near			; check for enough disk space
	push	ax
	push	bx
	push	cx
	push	dx
	cmp	filtst.fstat2,0		; disk file?
	jne	spchk5b			; ne = no, always enough space
	mov	ah,gcurdsk		; get current disk
	int	dos
	add	al,'A'			; make 0 == A
	mov	cl,al			; assume this drive
	mov	dx,word ptr diskio.string ; filename used in open
	cmp	dh,':'			; drive letter given?
	jne	spchk1			; ne = no
	mov	cl,dl			; get the letter
	and	cl,not 20h		; convert to upper case
spchk1:	call	dskspace		; calculate space into dx:ax
	jc	spchk6			; c = error
	cmp	restart_flag,0		; doing a restart?
	jne	spchk1a			; ne = yes (pretend file removal)
	cmp	flags.flwflg,filecol_update ; updating?
	je	spchk1a			; e = yes, file will be removed
	cmp	flags.flwflg,filecol_overwrite	; overwrite existing file?
	jne	spchk1b			; ne = no, file will be kept
spchk1a:add	ax,diskio.sizelo	; add size of file to be removed
	adc	dx,diskio.sizehi	;  to current disk space
spchk1b:push	ax			; save low word of bytes
	push	dx			; save high word, dx:ax
	mov	dx,diskio.sizehi	; high word of file size dx:ax
	mov	ax,diskio.sizelo	; low word
	cmp	trans.xtype,1		; binary transfer?
	je	spchk5a			; e = yes, do not inflate file size
	mov	cx,dx			; copy size long word to cx:bx
	mov	bx,ax
	shr	bx,1			; divide long word by two
	shr	cx,1
	jnc	spchk2			; nc = no carry down
	or	bx,8000h		; get carry down
spchk2:	shr	bx,1			; divide by two again
	shr	cx,1
	jnc	spchk3
	or	bx,8000h		; get carry down
spchk3:	shr	bx,1			; divide long word by two
	shr	cx,1
	jnc	spchk4			; nc = no carry down
	or	bx,8000h		; get carry down
spchk4:	shr	bx,1			; divide long word by two
	shr	cx,1
	jnc	spchk4a			; nc = no carry down
	or	bx,8000h		; get carry down
spchk4a:shr	bx,1			; divide long word by two
	shr	cx,1
	jnc	spchk4b			; nc = no carry down
	or	bx,8000h		; get carry down
spchk4b:shr	bx,1			; divide long word by two
	shr	cx,1
	jnc	spchk5			; nc = no carry down
	or	bx,8000h		; get carry down
spchk5:	add	ax,bx			; form dx:ax = (65/64) * dx:ax
	adc	dx,cx
spchk5a:pop	cx			; high word of disk space
	pop	bx			; low word
	sub	bx,ax			; minus inflated file size, low word
	sbb	cx,dx			;  and high word
	js	spchk6			; s = not enough space for file
spchk5b:clc
	jmp	short spchk7		; enough space
spchk6:	stc				; indicate failure
spchk7:	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
spchk	endp

code	ends
	end
