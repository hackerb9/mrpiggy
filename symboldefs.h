; File SYMBOLDEFS.H						-*- asm -*-
;	Copyright (C) 1982, 1999, Trustees of Columbia University in the 
;	City of New York.  The MS-DOS Kermit software may not be, in whole 
;	or in part, licensed or sold for profit as a software product itself,
;	nor may it be included in or distributed with commercial products
;	or otherwise distributed by commercial concerns to their clients 
;	or customers without written permission of the Office of Kermit 
;	Development and Distribution, Columbia University.  This copyright 
;	notice must not be removed, altered, or obscured.

;; MASM v6, use MASM 5.1 constructions (/Zm)	OPTION	M510
	.xlist			; suppress listing in program
	.sall			; don't list macro expansions
; define MS-DOS Kermit conditionals
; comment out line to re-enable functionality
;nls_portuguese	equ 1		; for Portuguese (Brazil) legends
;no_terminal	equ 1		; no terminal emulation (no Connect mode)
;no_graphics	equ 1		; no Tektronix and no Data General graphics
;no_network	equ 1		; no network support at all
;no_tcp		equ 1		; no internal TCP/IP stack

ifdef	no_network
no_tcp		equ 1		; tcp is a network channel
endif

ifdef	no_terminal		; implies no graphics
no_graphics	equ 1
endif	; no_terminal

; Below is for medium-lite (TCP but no terminal emulation)
;no_terminal	equ 1
;no_graphics	equ 1

; Note on conditionals: if defining no_graphics then omit file msgibm.asm.
; if defining no_network or no_tcp then omit files msn*.c, msn*.asm, msn*.h.
; if defining no_terminal then omit the above plus msuibm.asm and mszibm.asm.

version equ	316		; master version number
verdef	macro
	db	' MS-DOS Kermit: 3.16 Beta 10 + Mr. Piggy'
ifdef	nls_portuguese
	db	' Portuguese'
endif	; nls_portuguese
	db	' 14 April 2025'
	endm

BELL	EQU	07H
TAB 	EQU	09H
LF  	EQU	0AH
FF  	EQU	0CH
CR  	EQU	0DH
XON 	EQU	11H
XOFF	EQU	13H
ESCAPE 	EQU	1BH
DEL 	EQU	7FH
BS  	EQU	08H
CTLZ	EQU	1AH
SOH 	EQU	01H     ; Start of header char
SPC 	EQU	20H
SS2	equ	8eh
SS3	equ	8fh
DCS	equ	90h
CSI	equ	9bh
STCHR	equ	9ch

DOS 	EQU	21H

CONIN	EQU	01H
CONOUT	EQU	02H
LSTOUT	EQU	05H
DCONIO	EQU	06H
CONINQ	EQU	07H	; quiet console input
PRSTR	EQU	09H
CONSTAT	EQU	0BH
SELDSK	EQU	0EH	; Select disk
GCURDSK	EQU	19H	; Current disk
SETDMA	EQU	1AH
SETINTV	EQU	25H	; Set interrupt vector from ds:dx
GETDATE EQU	2AH	; Get date
GETTIM	EQU	2CH	; Get the time of day 
DOSVER	EQU	30H	; dos version #
GETINTV	EQU	35H	; get interrupt vector to es:bx
GSWITCH	EQU	37H	; undocumented get/set switch character
CHDIR	EQU	3BH	; change directory
CREAT2	EQU	3CH	; create
OPEN2	EQU	3DH	; open
CLOSE2	EQU	3EH	; close
READF2	EQU	3FH	; read
WRITE2	EQU	40H	; write
DEL2	EQU	41H	; delete
LSEEK	EQU	42H	; lseek
IOCTL	EQU	44H	; i/o control
GCD	EQU	47H	; get current directory
ALLOC	EQU	48H	; allocate memory
FREEMEM	EQU	49H	; free memory
SETBLK	EQU	4AH	; modify allocated memory map
EXEC	EQU	4BH	; execute task
FIRST2	EQU	4EH	; search for first
NEXT2	EQU	4FH	; search for next
fileattr equ	57h	; get/set file's date and time

PAREVN	EQU	00	; Even parity
PARMRK	EQU	01	; Mark parity
PARNON	EQU	02	; No parity.	
PARODD	EQU	03	; Odd parity
PARSPC	EQU	04	; Space parity
PARHARDWARE EQU	10h	; indicator of hardware parity
PAREVNH	EQU	PARHARDWARE+PAREVN ; hardware parity (9-bit bytes)
PARMRKH	EQU	PARHARDWARE+PARMRK
PARODDH EQU	PARHARDWARE+PARODD
PARSPCH	EQU	PARHARDWARE+PARSPC

FLOXON	EQU	1113H	; Use XON/XOFF for flow control
FLONON	EQU	0	; Don't do flow control
DEFHAND	EQU	XON	; Use XON as default handshake

MODCD	EQU	80H	; MODEM CD handshake line status responses
MODCTS	EQU	10H	; MODEM CTS
MODDSR	EQU	20H	; MODEM DSR
MODRI	EQU	40H	; MODEM RI

			; flags.remflg byte definitions
DQUIET	EQU	1	; Display mode, suppress file xfer statistics
DREGULAR EQU	2	; Regular formatted screen display of statistics
DSERIAL	EQU	4	; Serial mode (non-formatted screen)
D8BIT	EQU	8	; Display chars as 8-bit vs 7-bit quantities
DSERVER	EQU	10H	; Server mode active, if this bit is set

MAXTAK	EQU	25	; Max number of TAKE's allowed
DEFMXTRY EQU	5	; default number of retries on a data packet (63 max)
			; Init packet gets three times this number of tries

DEFESC	EQU	1DH	; The default escape character (Control rt sq bracket)
DRPSIZ	EQU	94	; Default receive packet size, regular pkts
DSPSIZ	EQU	94	; Default send packet size, regular pkts
DSTIME	EQU	8	; Default send time out interval
DSQUOT	EQU	23H	; Default send (and receive) quote char
DQBIN	EQU	26H	; Default 8-bit prefix
DCHKLEN	EQU	1	; Default checksum length
DEFPAR	EQU	PARNON	; Default parity (none) 
DEFRPTQ EQU	7EH	; Default repeat quote

bufsiz	equ	1536	; size of serial port input buffer
buffsz	equ	512	; size of disk file i/o buffer (buff)
cmdblen	equ	1000	; length of command lines (sharing buffers)
cptsiz	equ	256	; size of session capture buffer
tbufsiz	equ	1000	; size of Take buffers
decbuflen equ	1024	; length of decode/work buffer
encbuflen equ	512	; length of encode buffer
maxwind equ	32	; max number of window slots
macmax	equ	160	; max number of macros

			; bit defs for flags.capflg (LOG command)
logoff	equ	0	; Off = no or suspended logging
logdeb	equ	1	; log debugging (not yet imp)
logpkt	equ	2	; log packets sent/received
logses	equ	4	; log connect mode session
logtrn	equ	8	; log (file) transaction

			; Attributes-allowed bits in flags.attflg 
attchr	equ	1	; File Character-set
attdate	equ	2	; File Date/Time
attlen	equ	4	; File Length
atttype	equ	8	; File Type
attsys	equ	16	; System-identification

xfr_xparent	equ	0	; transfer character set indices
xfr_latin1	equ	1	;  ref table charids in mssfil.asm
xfr_latin2	equ	2
xfr_hebiso	equ	3
xfr_cyrillic	equ	4
xfr_japanese	equ	5

lock_disable	equ	0	; transfer locking shift capability
lock_enable	equ	1
lock_force	equ	2

filecol_rename	equ	0	; File Collision actions for flags.flwflg
filecol_overwrite equ	1	; match with Rem Set File Collision codes
filecol_backup	equ	2
filecol_append	equ	3
filecol_discard	equ	4
filecol_ask	equ	5
filecol_update	equ	6

; Terminal emulator section

; Kinds of terminals available
ttgenrc equ	0			; no emulation done by Kermit
ttheath equ	1			; Heath-19
ttvt52	equ	2			; VT52
ttvt100	equ	4			; VT100
ttvt102	equ	8			; VT102
ttvt220	equ	10h			; VT220
ttvt320	equ	20h			; VT320
tttek	equ	40h			; Tektronix 4010
tthoney	equ	80h			; Honeywell VIP7809
ttpt200	equ	100h			; Prime PT200
ttd463	equ	200h			; Data General D463
ttd470	equ	400h			; Data General D470
ttwyse	equ	800h			; Wyse-50
ttd217	equ	1000h			; Data General D217 (D463 w/217 ident)
ttansi	equ	2000h			; Ansi.sys flavor (VT100 base)
TTTYPES equ	15			; Number of terminal types defined

; tekflg bits in byte
tek_active equ	1			; actively in graphics mode
tek_tek	equ	2			; Tek terminal
tek_dec	equ	4			; Tek submode of DEC terminals
tek_sg	equ	8			; special graphics mode

; DEC emulator status flags (bits in words vtemu.vtflgst and vtemu.vtflgop)
anslnm  equ	1H			; ANSI line feed/new line mode
decawm  equ	2H			; DEC autowrap mode
decscnm equ	80H			; DEC screen mode
decckm  equ	200H			; DEC cursor keys mode
deckpam equ	400H			; DEC keypad application mode
decom   equ	800H			; DEC origin mode
deccol	equ	1000H			; DEC column mode (0=80 col)
decanm  equ	2000H			; ANSI mode
;dececho equ	4000H			; ANSI local echo on (1 = on)
     
; Terminal SETUP mode flags (joint with bits above, some name dups)
vsnewline	equ	1H		; ANSI new line (0 = off)
vswrap		equ	2H		; Line wrap around (0 = no wrap)
vsnrcm		equ	4H		; National Rep Char set (0=none)
vswdir		equ	8H		; Writing direction (0=left, 1 right)
vskeyclick	equ	10H		; Keyclick (0 = off)
vsmarginbell	equ	20H		; Margin bell (0 = off)
vscursor	equ	40H		; Cursor (0 = block, 1 = underline)
vsscreen	equ	80H		; Screen (0 = normal, 1 = rev. video)
vscntl		equ	100h		; 8 or 7 bit controls (1 = 8-bit)
vshscroll	equ	4000h		; horiz scroll (0=auto, 1=manual)
vscompress	equ	8000h		; compressed text(0=graphics,1=132col)

; VTxxx defaults for SETUP
; Note: Tab stops default to columns 9, 17, 25, 33, etc
;
; VSDEFAULTS holds Kermit startup time settings for the VT100 emulator
; Configure it by adding together names from the setup mode flags above
; to turn on features (they default to being off if not mentioned).
; Set the kind of terminal by placing a ttxxxx name in VTFLGS in the
; FLGINFO structure well below.

vsdefaults	equ	0+vscursor+vshscroll+vscompress	; default conditions

emulst	struc			; structure for terminal emulator global data
vtflgst	dw	0		; VTxxx setup flags
vtflgop	dw	0		; VTxxx runtime flags, like setup flags
vttbs	dw	0		; pointer to default tab stops 
vttbst	dw	0		; pointer to tab stops (both in mszibm)
vtchset	db	16		; value of default character set (16=Latin-1)
vtchop	db	16		; value of operational char set
att_ptr	dw	0		; pointer to video attributes: norm, rev
vttable db	4 dup (0ffh)	; char set number for G0..G3 overrides
vtdnld	db	1		; autodownload Kermit files (0 = off)
emulst	ends
; end of terminal emulator section

; Structure definitions

ifdef save_mem2			; define only for Xenix builds
save_mem equ	1		; for Xenix
endif

ifndef save_mem2		; for regular DOS builds
; Command parser information
cmdinfo	struc
cmrprs	dd 0		; offset,segment of where to jmp on reparsing
cmostp  dw 0		; place to remember stack pointer
cmblen	dw 0		; length of caller's cmtxt receiving buffer
cmprmp	dw 0		; address (ds:offset) of prompt
cmwhite	db 0		; non-zero to permit leading whitespace
cmcr	db 0		; non-zero to accept bare CR
cmper	db 0		; non-zero to allow literal backslash-percent in cmd
cmquiet	db 0		; non-zero for no echoing
cmkeep	db 0		; non-zero to keep Take/Macro open after EOF
impdo	db 0		; non-zero for keyword search failure to use DO cmd
cmdirect db 0		; non-zero to force reading from kbd/file, not Take.
cmdonum	db 0		; non-zero to allow \number -> byte expansion
cmcomma db 0		; non-zero to convert comma to space separator
cmcnvkind db 0		; see cmcnv_* for parser output filter kinds
cmarray	db 0		; non-zero to allow substitution in array brackets
cmswitch db 0		; non-zero to recoverably parse for /switch words
cmdinfo	ends

; Command parser equates
cmkey	equ	1	; parse a keyword
cmeol	equ	4	; parse a CR end of line character
cmline	equ	5	; parse line of text up to CR
cmword	equ	6	; parse an arbitrary word
cmcnv_none equ	0	; CR within curly braces is normal terminator
cmcnv_crprot equ 1	; allow CR within curly braces

endif

; equates for flags.destflg
dest_printer	equ 0
dest_disk	equ 1
dest_screen	equ 2
dest_memory	equ 4

; Flags information
flginfo	struc
belflg	db 1		; Use bell
comflg	db 1		; Use COM1 by default
abfflg	db 0		; Keep incoming file if abort
debug	db 0		; Debugging mode (default off)
flwflg	db 0		; File warning (collision) flag (default rename)
extflg	db 0		; Exit flag (default off)
vtflg	dw ttvt320	; term emulation type, default
cxzflg	db 0		; ^X/^Z to interrupt file x-fer
xflg	db 0		; Seen "X" packet
eoflag	db 0		; EOF flag; non-zero on EOF
capflg	db 0		; On if capturing data
takdeb  db 0		; On if single stepping Take files
takflg	db 0		; On if echoing commands of TAKE file
timflg	db 1		; Say if are timing out or not
destflg	db 1		; Incoming files destination: disk or printer
eofcz	db 0		; ^Z signals eof if non-zero
remflg	db DREGULAR	; server (remote) mode plus display flag bits
modflg	db 1		; non-zero if mode line on
attflg	db 0ffh		; non-zero if file attributes packets are enabled
chrset	dw 0		; ident of file character set (437=hardware, CP437)
unkchs	db 0		; files w/unknown-character-set (0=keep, 1=cancel)
xltkbd	db 1		; keyboard character-set translation (1=on, 0=off)
oshift	db 0		; output-shift (1 = auto, 0 = none, default none)
exitwarn db 1		; exit warning if active session (0 = ignore)
carrier	db 0		; check Carrier Detect (0 = ignore)
flginfo	ends

ifndef save_mem2
; Transmission parameters
trinfo	struc
maxdat	dw 0		; Max packet size for send, word for long packets
chklen	db 1		; Number of characters in checksum
seol  	db cr		; Send EOL char
reol  	db cr		; Receive EOL char
ssoh  	db soh		; Send start-of-packet character
rsoh  	db soh		; Receive start-of-packet character
squote	db dsquot	; Send quote character
rquote	db dsquot	; Receive quote character
rptq	db 7eh		; Repeat quote character (tilde)
rptqenable db 1		; Repeat quote character enable (1)/disable(0)
spsiz 	db dspsiz	; Send (regular) packet size
rpsiz 	db drpsiz	; Receive (regular) packet size
stime 	db dstime	; Send timeout. (Don't timeout)
rtime 	db 5		; Receive timeout
sdelay	db 0		; Send delay time (sec) for just SEND command
spad  	db 0		; Send number of padding char
rpad  	db 0		; Receive number of padding char
spadch	db 0		; Send padding char
rpadch	db 0		; Receive padding char
ebquot	db 'Y'		; Send 8-bit quote character
escchr	db defesc	; Escape character
capas	db 2,0		; Capas bytes (just two for now)
windo	db 1		; number of window slots
rlong	dw drpsiz	; long pkt size we want to receive
slong	dw 9024		; long pkt size we could send (negotiated with host)
xchset	db 0		; transfer char set (0=hardware) on comms wire
xchri	db 0		; transfer char set readable (0) or invertible (1)
xtype	db 0		; file type for xfer (0=text,1=binary,etc)
sdbl	db 0		; char to be doubled when sending (if non-null)
lshift	db lock_enable	; locking shift (0=disable, 1=enable, 2=force on)
cpkind	db 0		; checkpoint availability
cpint	dd 0		; checkpoint interval
xmode	db 0		; binary/manual mode sensing (0=manual)
xcrc	db 0		; compute CRC for file set
trinfo	ends
endif

ifndef save_mem
pktinfo	struc
datadr	dd 0		; data field address (segment:offset)
datlen	dw 0		; length of data field in a packet
datsize	dw 0		; length of data field buffer
pktype	db 0		; packet type, a letter
seqnum	db 0		; packet SEQ number
ackdone	db 0		; zero if pkt not ack'ed yet
numtry	db 0		; number of tries on this packet
sndtime dd 0		; time packet sent, Bios clock ticks
pktinfo	ends
endif

filest	struc
dta	db 26 dup(0)	; DOS, 21 resev'd bytes, file attr, 2 each date & time
sizelo	dw 0		; DOS, file size double word
sizehi	dw 0
fname	db 13 dup(0)	; DOS, filename, asciiz, with dot. End of DOS section
handle	dw -1		; Kermit, file handle
string	db 64 dup(0)	; Kermit, filename string, including drive and path
fstat	db 0		; Kermit, status of Find First DOS call
fstat2	db 0		; zero for disk file, non-zero for device
filest	ends

takinfo	struc		; Take file structure
taktyp	db 0		; type: valid file, macro, text subsititution
takinvoke db 0		; taklev of previous DO or top level cmd parser
takhnd	dw 0		; file handle
takptr	dw 0		; pointer in buffer to next char to read
takbuf	dw 0		; segment of Take buffer, must be dd part of takptr
takcnt	dw 0		; number of unread bytes in buffer
takctr	dw 0		; COUNT variable for script program control
takargc	dw 0		; argument quantity count
takper	db 0		; comand.cmper (\... expansion) while in Take file
takseek dd 0		; lseek number bytes into disk file for Take Reading
takattr	db 0		; attributes bitfield
takinfo ends

; values for taktyp field
take_file	equ	1
take_macro	equ	2
take_sub	equ	4
take_comand	equ	8

; values for takattr field
take_malloc	equ	1
take_autocr	equ	2
take_switch	equ	4	; doing Switch
take_while	equ	8	; While or For loop or Switch
take_subwhile	equ	16	; worker from IF part of While/For
; malloc means new buffer malloc'd and segment is in .takbuf
; autocr means report out CR at End of File

; Port Information
prtinfo	struc
baud	dw 0		; Default baud rate
ecoflg	db 0		; Local echo flag (default off)
parflg	db 0		; Parity flag (default none)
floflg	db 0		; If need flow control
hndflg	db 0		; If need handshake during file transfer
hands	db 0		; Default handshake
stopbits db 1		; number of stop bits (1 or 2)
flowc	dw 0		; Do flow control with XON/XOFF
duplex	db 0		; Do full (0) or half (1) duplex comms
portrdy db 0		; Non-zero if comms port is still active
sndproc dw 0		; byte sending procedure
rcvproc dw 0		; byte receiving procedure
cloproc dw 0		; session close procedure
starttime db 4 dup (0)	; start time hh, mm, ss
prtinfo	ends

				; ENABLE/DISABLE bits for denyflg
cwdflg	equ	1		; deny remote cwd
delflg	equ	2		; deny remote del
dirflg	equ	4		; deny remote dir
hostflg	equ	8		; deny remote host
spcflg	equ	10H		; deny remote space (obsolete, non-functional)
byeflg	equ	10h		; deny bye (replaces deny remote space)
finflg	equ	20H		; deny fin, logo to server
getsflg	equ	40H		; deny paths in get cmds to server
sndflg	equ	80H		; deny paths in send cmds to server
typflg	equ	100H		; deny paths in type
pasflg	equ	200h		; username/password required
kerflg	equ	400h		; deny remote kermit
prtflg	equ	800h		; deny remote print
defflg	equ	1000h		; deny remote define
qryflg	equ	2000h		; deny remote query
retflg	equ	4000h		; deny retrieve (file deletion)
tekxflg	equ	8000h		; deny automatic Tektronix invokation

ifndef save_mem
statinfo struc			; statistics, basic information layout
prbyte	dw	2 dup (0)	; number of bytes received by port
psbyte	dw	2 dup (0)	; number of bytes sent to port
frbyte	dw	2 dup (0)	; bytes received
fsbyte	dw	2 dup (0)	; bytes sent
prpkt	dw	2 dup (0)	; number of packets received
pspkt	dw	2 dup (0)	; number of packets sent
nakrcnt	dw	0		; count of naks received
nakscnt	dw	0		; count of naks sent
btime	dw	2 dup (0)	; start time (seconds) of transfer
etime	dw	2 dup (0)	; elapsed time (seconds) of transfer
pretry	dw	0		; packet retries
xstatus	dw	0		; transfer status
xstatus2 db	0		; extended (file attribute) status
xname	db	64 dup (0)	; alias (send/receive as) filename
statinfo ends

endif

scptinfo struc			; scripts
inactv	db	0		; input action value (default proceed)
incasv	db	0		; input case  (default ignore)
indfto	dw	1		; input and pause timeout (def 1 sec)
inecho	db	1		; echo Input cmd text (0 = no)
infilter db	1		; filer control sequences from screen (0=no)
xmitfill db	0		; non-zero to TRANSMIT filler for blank line
xmitlf	db	0		; non-zero to TRANSMIT LF's
xmitpmt	db	lf		; default prompt for line acknowledgments
xmitpause dw	0		; millisec pause between lines
scptinfo ends

; definitions for terminal handler:
termarg	struc
flgs	db 0		; flags
prt	db 0		; port to use (0,1,etc)
captr	dw 0		; routine to call with captured data
baudb	db 0		; baud rate bits
parity	db 0		; parity
termarg	ends

; Character set identification bytes
C_ASCII		equ	0
C_UKNRC		equ	1
C_DUNRC		equ	2
C_FINRC		equ	3
C_FRNRC		equ	4
C_FCNRC		equ	5
C_DENRC		equ	6
C_ITNRC		equ	7
C_NONRC		equ	8
C_PONRC		equ	9
C_SPNRC		equ	10
C_SENRC		equ	11
C_CHNRC		equ	12
C_DHEBNRC	equ	13
C_ALTROM	equ	14
C_XPARENT	equ	15
C_LATIN1	equ	16
C_DMULTINAT	equ	17
C_DECTECH	equ	18
C_DECSPEC	equ	19
C_DGINT		equ	20
C_DGLINE	equ	21
C_DGWP		equ	22
C_LATIN2	equ	23
C_HEBREWISO	equ	24
C_DECHEBREW	equ	25
C_WYSEGR	equ	26
C_HPROMAN8	equ	27
C_CYRILLIC_ISO	equ	28
C_KOI8		equ	29
C_SHORT_KOI	equ	30
C_JISKAT	equ	141
C_JISROM	equ	142
C_JISKANJI	equ	215

; bits for flag byte
capt	equ 40h		; capture output
emheath	equ 20h		; emulate heath
trnctl	equ 08h		; translate controls (debug)
modoff	equ 04h		; mode line off
lclecho	equ 01h		; local echo

; bits for kstatus general Kermit status word
kssuc	equ	0000h	; success condition
kssend	equ	0001h	; send file failed
ksrecv	equ	0002h	; get/receive file failed
ksrem	equ	0004h	; Remote command failed
kstake	equ	0008h	; Take file failure
ksgen	equ	0010h	; general command failure
ksuser	equ	0080h	; user intervention (aka Control-C)
ksattrib equ	0100h	; file attributes file rejection

emsint	equ	67h			; EMS interrupt
xmspresent equ	4300h			; EMS presence check for XMS mgr
emsmgrstat equ	40h			; EMS get manager status
emsgetseg equ	41h			; EMS get segment of page frame
emsgetnpgs equ	42h			; EMS get number free pages
emsalloc equ	43h			; EMS get handle and allocate memory
emsmapmem equ	44h			; EMS map memory
emsrelease equ	45h			; EMS release mapped memory
emsgetver equ	46h			; EMS get version number
emssetname equ	5301h			; EMS LIM 4, set name
xmsmanager equ	4310h			; XMS get manager entry point
xmsquery equ	08h			; XMS query largest block available
xmsalloc equ	09h			; XMS allocate memory block
xmsrelease equ	0ah			; XMS free memory block
xmsmove	equ	0bh			; XMS move memory block

xmsreq struc				; XMS memory move request block
 xms_count  dd	0			; bytes to move, must be even
 handle_src dw	0			; source handle (0 = under 1MB)
 offset_src dd	0			; offset into source block, bytes
 handle_dst dw	0			; destination handle
 offset_dst dd	0			; offset into destination block, bytes
xmsreq	ends

mkeyw	macro	key,value	; widely used data structure
	local	keylen,start
start	equ	$		; remember start address of structure
	dw	keylen		; length of "key"
	db	key		; "key" itself
keylen	equ	$-(start+2)	; number of bytes in "key"
	dw	value		; action value
	endm
;
; Note well. The following segment references are in THIS file to provide
; the desired ordering of them in memory. To wit: lowest addresses for
; 'code', followed by 'data', and only then by 'stack'.
code	segment public 'kcode'
code	ends
code1	segment public 'kcode'
code1	ends
code2	segment public 'kcode'
code2	ends
data	segment public 'kdata'
data	ends
data1	segment public 'kdata'
data1	ends
_TEXT	SEGMENT  WORD PUBLIC 'CODE'
_TEXT	ENDS
_DATA	SEGMENT  WORD PUBLIC 'DATA'
_DATA	ENDS
CONST	SEGMENT  WORD PUBLIC 'CONST'
CONST	ENDS
_BSS	SEGMENT  WORD PUBLIC 'BSS'
_BSS	ENDS
_STACK	SEGMENT	WORD STACK 'STACK'
_STACK	ENDS
DGROUP	GROUP	CONST, _BSS, _DATA, _STACK
	.list
