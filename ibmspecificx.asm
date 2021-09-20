	NAME	msxibm
; File MSXIBM.ASM
; Kermit system dependent module for IBM-PC
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
	public	serini, serrst, clrbuf, outchr, coms, cardet
	public	dodel, ctlu, cmblnk, locate, prtchr, baudst, clearl
	public	getbaud, beep, shomodem, getmodem, mdmhand, shownet
	public	count, xofsnt, puthlp, putmod, clrmod, poscur, holdscr
	public	sendbr, sendbl, machnam, setktab, setkhlp, lclini, showkey
	public	ihosts, ihostr, dtrlow, serhng, comptab, pcwait, portval
	public	bdtab, dupflg, peekcom, tstport, fossil_port, fossilflag
	public	savexoff, savexlen, parmsk, flowon, flowoff, flowcnt
	public	isps55		; [HF] 940130 Japanese IBM PS/55 mode
	public	ps55mod		; [HF]940206 PS/55 mode line status (0:system)
	public	prtblk, sndblk
ifndef	no_network
	public	setnbios, ubhold, ubclose
endif	; no_network
ifndef	no_tcp
	public	tcpstart, tcp_status, sesdisp, seslist, sescur, winupdate
	public	tcpbtpkind, sestime
endif	; no_tcp

off	equ	0
bufon	equ	1		; buffer level xon/xoff on-state control flag
usron	equ	2		; user level xon/xoff on-state control flag

mntrgh	equ	bufsiz*3/4	; High point = 3/4 of buffer full
mntrgl	equ	bufsiz/4	; Low point = 1/4 buffer full
nbuflen	equ	512		; bytes in each network buffer (two of them)
				;  DEC-LAT requires 259 (256 + 3 extra)

BRKBIT	EQU	040H		; Send-break bit. 
TIMERCMD EQU	43h		; 8253/4 Timer chip command port
TIMER2DATA EQU	42h		; 8253/4 Timer 2 data port
PPI_PORT EQU	61h		; 8255 prog peripheral chip control port
VIDEO	EQU	10H		; Bios Video display software interrupt
RS232	EQU	14H		; Bios RS232 serial port s/ware interrupt

; constants used by serial port handler
MDMINP	EQU	1		; Input ready bit
MDMOVER	EQU	2		; Receiver overrun
				; 1200/75 baud split speed constants
cnt75b	equ	47721/3		; One bit of 75 baud at 1.193 Mhz clock
precomp	equ	cnt75b/8	; Precomp 12%, allows 3ms latency w 12% jitter

ifndef	no_tcp
_TEXT	segment
	extrn	ktcpopen:far, ktcpclose:far, ktcpswap:far, ktcpcom:far
_TEXT	ends
endif	; no_tcp

data 	segment
	extrn	flags:byte, trans:byte, ttyact:byte, comand:byte
	extrn	lclsusp:word, lclrest:word, lclexit:word, rxtable:byte
	extrn	rdbuf:byte, taklev:byte, scbattr:byte
	extrn	low_rgt:word, diskio:byte, crt_cols:byte
	extrn	dosnum:word, portirq:byte, portfifo:byte, dosctty:byte 
	extrn	tv_mode:byte, repflg:byte, decbuf:byte
	extrn	takadr:word, taklev:byte, vtinited:byte, kbdflg:byte
	extrn	yflags:byte,  apctrap:byte, protlist:byte
	extrn	vtcpage:word, kstatus:word
	extrn	domath_ptr:word, domath_cnt:word, domath_msg:word
ifndef	no_network
ifndef	no_tcp
	extrn	tcpnewline:byte
	extrn	tcpaddress:byte, tcpsubnet:byte, tcpdomain:byte
	extrn	tcpgateway:byte, tcpprimens:byte, tcpsecondns:byte
	extrn	tcphost:byte, tcpbcast:byte, tcpbtpserver:byte
	extrn	tcpport:word, tcppdint:word, tcpttbuf:byte
	extrn	tcpdebug:byte, tcpmode:byte, tcpmss:word
endif	; no_tcp
endif	; no_network
ifndef	no_terminal
	extrn	tekflg:byte, ftogmod:dword
endif	; no_terminal

; Modem information
mdminfo	struc
mddat	dw	03f8h		; data register, base address (03f8h)
mdiir	dw	03fah		; interrupt identification register (03fah)
mdstat	dw	03fdh		; line status register (03fdh)
mdcom	dw	03fbh		; line control register (03fbh)
mden	db	not (1 shl 4)	; mask to enable interrupt
mddis	db	(1 shl 4)	; mask to disable interrupt
mdmeoi	db	60h+4		; specific EOI
mdintv	dw	8+4		; saved interrupt vector (0ch is IRQ 4)
mdmintc	dw	20h		; interrupt controller control (20h or 0a0h)
mdfifo	db	0		; non-zero if UART is in FIFO mode
mdminfo	ends
modem	mdminfo <>

setktab	db	0		; superceded by msuibm code, return 0 here
setkhlp	db	'$'		; and add empty help string
holdscr	db	0		; Hold-Screen, non-zero to stop reading
savsci	dd	0		; old serial port interrupt vector
sav232	dd	0		; Original Bios Int 14H address, in Code seg
savirq	db	0		; Original Interrupt mask for IRQ
savier	db	0		; original UART Int enable bits (03f9)
savstat db	0		; orginal UART control reg  (03fch)
savlcr	db	0		; Original Line Control Reg (3fbh) contents
dupflg	db	0		; full (0) or half (1) duplex on port
quechar	db	0		; queued char for outchr (XOFF typically)
intkind	db	0		; cause of serial port interrupt
isps2	db	0		; non-zero if real IBM PS/2
isps55	db	0		; [HF] 940130 non-zero if Japanese PS/55 mode
ps55mod	db	0, 0		; [HF] 940202 PS/55 mode line at startup/curr.
reset_clock db	0		; toggle to reset time of day clock in serini
erms40	db	cr,lf,'?Warning: Unrecognized Speed',cr,lf,'$'
badbd	db	cr,lf,'Unimplemented speed$'
badprt	db	cr,lf,'?Warning: unknown address for port. Assuming \x0$'
biosmsg	db	cr,lf,'?Warning: unknown hardware for port.'
	db	' Using the Bios as BIOS$'
badirq	db	cr,lf,'?Warning: unable to verify IRQ. Assuming $'
msmsg1	db	cr,lf,'  Modem is not ready: DSR is off$'
msmsg2	db	cr,lf,'  Modem is ready:     DSR is on$'
msmsg3	db	cr,lf,'  no Carrier Detect:  CD  is off$'
msmsg4	db	cr,lf,'  Carrier Detect:     CD  is on$'
msmsg5	db	cr,lf,'  no Clear To Send:   CTS is off$'
msmsg6	db	cr,lf,'  Clear To Send:      CTS is on$'
msmsg7	db	cr,lf,'  Modem is not used by the Network$'
msmsg8	db	cr,lf,'  COM1 address:       Port \x$'
msmsg9	db	', IRQ $'
msmsg10	db	', 16550A UART FIFO$'
msmsg11	db	cr,lf,'  Fossil port: $'
msmsg12	db	', disable-on-close: off$'
msmsg13	db	', disable-on-close: on$'
msmsg14 db	', 1 stop bit$'
msmsg20 db	'  (Set Carrier is on)$'
msmsg21 db	'  (Set Carrier is off)$'
hngmsg	db	cr,lf,' The phone or network connection should have hung up'
	db	cr,lf,'$'

machnam	db	'IBM-PC$'
crlf	db	cr,lf,'$'
delstr  db	BS,BS,'  ',BS,BS,'$' 	; Delete string
clrlin  db	BS,BS,'  ',cr,'$'	; Clear line (just the cr part)
portin	db	-1		; Has comm port been initialized, -1=not used
nettype	dw	0		; kind of local area net (vendor bit field)
xofsnt	db	0		; Say if we sent an XOFF
xofrcv	db	0		; Say if we received an XOFF
pcwcnt	dw	800		; number of loops for 1 millisec in pcwait
temp	dw	0
temp2	dw	0
tempsci dw	0		; temp storage for serint
tempdum	dw	0		; temp storage for serdum
timeract db	0		; timer in use by a routine, flag
clomsg	db	' A communications session may be active;'
	db	' exit anyway [Yes/No]? ',0
clotab	db	2		; close net on exit table
	mkeyw	'yes',0
	mkeyw	'no',1


ifdef	no_network
comptab	db	25 - 12
else
ifdef	no_tcp
comptab	db	25 - 1			; communications port options
else
comptab	db	25			; communications port options
endif	; no_tcp
endif	; no_network

	mkeyw	'Bios1','0'+1		; '0' is to flag value as forced Bios
	mkeyw	'Bios2','0'+2
	mkeyw	'Bios3','0'+3
	mkeyw	'Bios4','0'+4
	mkeyw	'COM1',1		; these go straight to the hardware
	mkeyw	'COM2',2
	mkeyw	'COM3',3
	mkeyw	'COM4',4
	mkeyw	'1',1			; straight to the hardware
	mkeyw	'2',2
	mkeyw	'3',3
	mkeyw	'4',4
ifndef	no_network
	mkeyw	'3Com(BAPI)','C'	; 3Com BAPI interface
	mkeyw	'BWTCP','b'		; [JRS] Beame & Whiteside TCP
	mkeyw	'DECnet','D'		; DECnet-DOS LAT and CTERM
	mkeyw	'EBIOS','E'		; IBM/YALE EBIOS Int 14h interceptor
	mkeyw	'NetBios','N'		; Netbios
	mkeyw	'Novell(NASI)','W'	; Novell NetWare NASI/NACS
	mkeyw	'OpenNET','O'		; Intel OpenNET support (FGR)
	mkeyw	'SuperLAT','M'		; Meridian SuperLAT
ifndef	no_tcp
	mkeyw	'TCP/IP','t'		; Telnet, internal
endif	; no_tcp
	mkeyw	'TELAPI','T'		; Novell TELAPI
	mkeyw	'TES','I'		; TES, Interconnections Inc
	mkeyw	'UB-Net1','U'		; Ungermann Bass Net One
endif	; no_network
	mkeyw	'Fossil','F'		; Fossil
	mkeyw	'   ',0			; port is not present, for Status

; port structure:
; baud rate index, local echo, parity flag, if flow control active (both ways),
; if need handshake after pkts, default handshake char, flow control char pair
; half/full duplex, port ready, send, receive, close procedures
	; UART hardware
port1	prtinfo	<-1,0,defpar,3,0,defhand,1,floxon,0,0,uartsnd,uartrcv,serrst>
port2	prtinfo	<-1,0,defpar,3,0,defhand,1,floxon,0,0,uartsnd,uartrcv,serrst>
port3 	prtinfo	<-1,0,defpar,3,0,defhand,1,floxon,0,0,uartsnd,uartrcv,serrst>
port4	prtinfo	<-1,0,defpar,3,0,defhand,1,floxon,0,0,uartsnd,uartrcv,serrst>
	; IBM PC Bios and EBIOS
portb1	prtinfo	<-1,0,defpar,3,0,defhand,1,floxon,0,0,biossnd,biosrcv,serrst>
portb2	prtinfo	<-1,0,defpar,3,0,defhand,1,floxon,0,0,biossnd,biosrcv,serrst>
portb3 	prtinfo	<-1,0,defpar,3,0,defhand,1,floxon,0,0,biossnd,biosrcv,serrst>
portb4	prtinfo	<-1,0,defpar,3,0,defhand,1,floxon,0,0,biossnd,biosrcv,serrst>

portval	dw	port1			; Default is to use port 1

bdtab	db	21			; Baud rate table
	mkeyw	'45.5',0
	mkeyw	'50',1
	mkeyw	'75',2
	mkeyw	'110',3
	mkeyw	'134.5',4
	mkeyw	'150',5
	mkeyw	'300',6
	mkeyw	'600',7
	mkeyw	'1200',8
	mkeyw	'1800',9
	mkeyw	'2000',10
	mkeyw	'2400',11
	mkeyw	'4800',12
	mkeyw	'9600',13
	mkeyw	'14400',14
	mkeyw	'19200',15
	mkeyw	'28800',16
	mkeyw	'38400',17
	mkeyw	'57600',18
	mkeyw	'115200',19
	mkeyw	'75/1200',20	; split speed, use this index for Bsplit

Bsplit	equ	20		; 75/1200 baud, split-speed  [pslms]

; this table is indexed by the baud rate definitions given in bdtab.
; Unsupported baud rates should contain 0FFh.

bddat	label	word
	dw	9E4H		; 45.5 baud
	dw	900H		; 50 baud
	dw	600H		; 75 baud
	dw	417H		; 110 baud
	dw	359H		; 134.5 baud
	dw	300H		; 150 baud
	dw	180H		; 300 baud
	dw	0C0H		; 600 baud
	dw	60H		; 1200 baud
	dw	40H		; 1800 baud
	dw	3AH		; 2000 baud
	dw	30H		; 2400 baud
	dw	18H		; 4800 baud
	dw	0CH		; 9600 baud
	dw	08h		; 14400 baud
	dw	06H		; 19200 baud
	dw	04h		; 28800 baud
	dw	03H		; 38400 baud
	dw	02h		; 57600 baud
	dw	01h		; 115200 baud
	dw	5fh		; Split 75/1200, 1200+1.1 percent error
baudlen	equ	($-bddat)/2	; number of entries above

; this table is indexed by the baud rate definitions given in
; pcdefs.  Unsupported baud rates should contain FF.
; Bits are for Bios speed, no parity, 8 data bits.
clbddat   label   word
        dw      0FFH            ; 45.5 baud  -- Not supported
        dw      0FFH            ; 50 baud
        dw      0FFH            ; 75 baud
        dw      03H		; 110 baud
        dw      0FFH            ; 134.5 baud
        dw      23H		; 150 baud
        dw      43H		; 300 baud
        dw      63H		; 600 baud
        dw      83H		; 1200 baud
        dw      0ffH		; 1800 baud
        dw      0FFH		; 2000 baud
        dw      0a3H		; 2400 baud
        dw      0c3H		; 4800 baud
        dw      0e3H		; 9600 baud
        dw      0FFH		; 14400 baud
        dw      0FFH		; 19200 baud
        dw      0FFH		; 28800 baud
        dw      0FFH		; 38400 baud
	dw	0FFH		; 57600 baud
	dw	0FFH		; 115200 baud
	dw	0FFh		; Split 75/1200

defcom	dw	03f8h,02f8h,03e8h,02e8h	 ; default COMn port addresses

;;;;;;;;;;;;;; start of per session save area
	even
savexoff label	word
source	db	bufsiz+2 DUP(?)	; Buffer for data from port (+ 2 guard bytes)
srcpnt	dw	source		; Pointer in buffer
count	dw	0		; Number of chars in int buffer
cardet	db	0		; UART Carrier Detect (and network analogue)
parmsk	db	0ffh		; parity mask, 0ffh for no parity, 07fh with
flowoff	db	0		; flow-off char, Xoff or null (if no flow)
flowon	db	0		; flow-on char, Xon or null
flowcnt	db	0		; holds flowc (!= 0 using any flow control)
xmtcnt	dw	0		; occupancy in current output buffer
;;;xmtbufx	db	nbuflen+3 dup (0) ; external version of xmtbuf (dbl buffers)
xmtbufx	db	buffsz dup (0) ; external version of xmtbuf (dbl buffers)
	db	0,0		; required runon for CR NUL and IAC IAC

ifndef	no_network
ifndef	no_tcp
; TCP/IP Telnet internal
port_tn	prtinfo	<-1,0,defpar,3,0,defhand,1,floxon,0,0,ubsend,ubrecv,tcpclose>
else
port_tn	prtinfo	<-1,0,defpar,3,0,defhand,1,floxon,0,0,ubsend,ubrecv,ubclose>
endif	; no_tcp
endif	; no_network
savexlen dw	($-savexoff)
;;;;;;;;;;;;;;; end of per session save
tcp_status dw	0		; status from msntnd.c
					; SUCCESS	0
					; NO_DRIVER	1
					; NO_LOCAL_IP	2
					; NO_SESSION	3
					; NO_HOST	4
					; BAD_SUBNET_MASK 5
					; SESSIONS_EXCEEDED 6
					; HOST_UNKNOWN	7
					; HOST_UNREACHABLE 8
					; CONNECTION_REJECTED 9
tcpbtpkind db 0			; BOOT kind from msntni.asm
				; BOOT_FIXED	0
				; BOOT_BOOTP	1
				; BOOT_RARP	2
				; BOOT_DHCP	3

xmtbuf	db	nbuflen dup (0) ; network buffer for transmitter
rcvbuf	db	nbuflen+3 dup (0) ; network buffer for receiver

; variables for serial interrupt handler
mst	dw	03fdh		; Modem status address
mdat	dw	03f8h		; Modem data address
miir	dw	03fah		; modem interrupt ident register
mdeoi	db	20h		; End-of-Interrupt value
mdmhand	db	0		; Modem status register, current
mdintc	dw	20h		; interrupt control address

fossil_port  dw	0		; Fossil, port number 0..98
fossilflag   db	0		; Fossil, shut port when done if non-zero
fossil_portst equ 3		; Fossil, port status
fossil_init equ	4		; Fossil, init port in dx
fossil_done equ	5		; Fossil, release port in dx
fossil_dtr equ	6		; Fossil, DTR control
fossil_blkrd equ 18h		; Fossil, block read
fossil_blkwr equ 19h		; Fossil, block write
fossil_flow equ	0fh		; Fossil, set flow control method

ifndef	no_network
; Information structures for IBM Netbios compatible Local Area Networks
				; network constants
netint	equ	5ch		; Netbios interrupt
nadd	equ	30h		; Add name
ncall	equ	10h		; CALL, open a virtual circuit session
ncancel	equ	35h		; Cancel command in scb buffer
ndelete	equ	31h		; Delete Name
nhangup	equ	12h		; Hangup virtual circuit session
nlisten	equ	11h		; Listen for session caller
naustat	equ	33h		; Network Adapter Unit, get status of
nreceive equ	15h		; Receive on virtual circuit
nreset	equ	32h		; Reset NAU and tables
nsend	equ	14h		; Send on virtual circuit
nsestat	equ	34h		; Session, get status of
netbrk	equ	70h		; STARLAN Int 5bh send Break
nowait	equ	80h		; no-wait, command modifier
npending equ	0ffh		; Pending request
exnbios	equ	0400h		; Int 2ah exec netbios call, error retry

				; nettype word bits
netbios	equ	0001h		; NetBios
netone	equ	0002h		; Ungermann-Bass Net/One
decnet	equ	0004h		; DECnet CTERM
declat	equ	0008h		; DECnet LAT
bapi	equ	0010h		; 3Com BAPI
ebios	equ	0020h		; EBIOS, IBM and YALE
telapi	equ	0040h		; TELAPI, Novell
tes	equ	0080h		; TES, Interconnections Inc and Novell
tcpnet	equ	0100h		; TCP/IP (internal)
acsi	equ	0200h		; EBIOS, ACSI direct to NetBios pathway
bwtcp	equ	0400h		; [JRS] Beame & Whiteside TCP

;xncall	equ	74h		; [ohl] Net/One extended call function
netci	equ	6Bh		; [ohl] Net/One command interface interrupt,
				; [ohl]  used for the following functions:
nciwrit equ	0000h		; [ohl] Net/One write function
nciread equ	0100h		; [ohl] Net/One read function
ncistat equ	0700h		; [ohl] Net/One status function
ncicont equ	0600h		; [ohl] Net/One control function
ncibrk	equ	02h		; [ohl] Net/One code for a break
ncidis	equ	04h		; [ohl] Net/One code for disconnect
ncihld	equ	06h		; [ohl] code for placing a connection on hold
bapiint	equ	14h		; 3Com BAPI, interrupt (Bios replacment)
bapicon	equ	0a0h		; 3Com BAPI, connect to port
bapidisc equ	0a1h		; 3Com BAPI, disconnect
bapiwrit equ	0a4h		; 3Com BAPI, write block
bapiread equ	0a5h		; 3Com BAPI, read block
bapibrk	equ	0a6h		; 3Com BAPI, send short break
bapistat equ	0a7h		; 3Com BAPI, read status (# chars to be read)
bapihere equ	0afh		; 3Com BAPI, presence check
bapieecm equ	0b0h		; 3Com BAPI, enable/disable ECM char
bapiecm	equ	0b1h		; 3Com BAPI, trap Enter Command Mode char
bapiping equ	0b2h		; KERMIT BAPI extension, Telnet, Ping host
bapito_3270 equ 0b3h		; KERMIT BAPI extension, byte to 3270
bapinaws equ	0b4h		; KERMIT BAPI extension, send NAWS update

				;
telopen	equ	0e0h		; TELAPI xtelopen a connection
telclose equ	0e1h		; xtelclose a connection
telread	equ	0e2h		; xtelread char(s)
telwrite equ	0e3h		; xtelwrite chars
telioctl equ	0e4h		; xtelioctl, ioctl the port
telreset equ	0e5h		; xtelreset, reset the whole TELAPI package
telunload equ	0e6h		; xtelunload, unload TELAPI TSR
tellist	equ	0e7h		; xtellist, list current sessions and status
telattach equ	0e8h		; xtelattach, session to COM port # 0..3
telportosn equ	0e9h		; xtelportosn, return session id for port
telunreac equ	-51		; network is unreachable
telinuse equ	-56		; socket already in use
teltmo	equ	-60		; timeout on connection attempt
telrefuse equ	-61		; connection refused
teldwnhost equ	-64		; host is down
telunkhost equ	-67		; unknown host
telfull	equ	-301		; all sessions are in use
				; TELAPI messages and misc data
telmsg1	db	cr,lf,'?Badly constructed Internet address: $'
telmsg2	db	cr,lf,'?No connection. Status = -$'
telmsg51 db	cr,lf,'?Network is unreachable$'
telmsg56 db	cr,lf,'?Socket already in use$'
telmsg60 db	cr,lf,'?Timeout on connection attempt$'
telmsg61 db	cr,lf,'?Connection refused$'
telmsg64 db	cr,lf,'?Host is down$'
telmsg67 db	cr,lf,'?Unknown host$'
telmsg301 db	cr,lf,'?All sessions are in use$'
telhostid db	2 dup (0)	; TELAPI Telnet internal host session ident

IAC	equ	255		; B&W TCP/IP Telnet Options codes
DONT	equ	254
DO	equ	253
WONT	equ	252
WILL	equ	251
SB	equ	250
SE	equ	240
TELOPT_ECHO	equ 1
TELOPT_SGA	equ 3
TELOPT_STATUS	equ 5
TELOPT_TTYPE	equ 24
TELOPT_NAWS	equ 31
NTELOPTS	equ 24
sgaflg	db	0		; B&W TCP/IP, supress go ahead flag
option1 db	0		; B&W TCP/IP, Telnet Options byte1
option2	db	0		; B&W TCP/IP, Telnet Options byte1
optstate db	0		; B&W TCP/IP, Telnet Options state variable
bwtcpnam    db	'TCP-IP10',0	; [JRS] name of Beame & Whiteside TCP driver
bwhandle    dw	0		; [JRS] handle for Beame & Whiteside TCP driver
				;
testalk	equ	4		; TES invoke interactive cmd interpreter
tesbwrite equ	6		; TES block write
tesbread equ	7		; TES block read
tesinstal equ	0a0h		; TES installation/status report
teslist	equ	0a1h		; TES get list of sessions, with status	
tesgets	equ	0a2h		; TES get list of server names
tesnews	equ	0a3h		; TES start a new session
tesholds equ	0a4h		; TES hold currently active connection
tesresume equ	0a5h		; TES resume a session (1..9)
tesdrop	equ	0a6h		; TES drop a session
tesnexts equ	0a7h		; TES skip to next active session
tesexec	equ	0a8h		; TES send string to cmd interpreter
tesport	dw	0		; TES low byte = intercepted port
tesquiet db	'ACTION NONE',0 ; TES Stop command prompting
tesses	db	0		; TES session number (1..9 is legal)
tesname	db	50 dup (0)	; TES host name asciiz
teshelp	db	cr,lf,'?Host name or "*" to see available hosts'
	db	' or press ENTER to resume a connection$'
tesnlist db	cr,lf,'  Active TES hosts:$'
tesnhost db	cr,lf,'?No existing connection.'
	db	' Please select a host with  SET PORT TES host$'
latkind	db	0		; non-zero if using TES or Meridian LAT
DEC_LAT	equ	0		; for latkind
MTC_LAT	equ	2		; for latkind
TES_LAT	equ	1		; for latkind

;; pcnet values:	0	no network available at all
;;			1	network board reports itself as present
;;			2	and session is in progress
;; extrn byte pcnet is  defined in msster.

; NetBios (StarGROUP and Opennet)
port_nb	prtinfo	<-1,0,defpar,3,0,defhand,1,floxon,0,0,send,receive,nbclose>
; Ungermann Bass, 3ComBAPI, TELAPI
port_ub	prtinfo	<-1,0,defpar,3,0,defhand,1,floxon,0,0,ubsend,ubrecv,ubclose>
; DECnet LAT and CTERM and TES-LAT
port_dec prtinfo <-1,0,defpar,3,0,defhand,1,floxon,0,0,decsnd,decrcv,decclose>
; TES
port_tes prtinfo <-1,0,defpar,3,0,defhand,1,floxon,0,0,tessnd,tesrcv,tesclose>
endif	; no_network

scbst struc			; Session (Network) Control Block [PCnet comp]
	scb_cmd		db 0	; command code for Netbios Int 5ch
	scb_err		db 0	; error return or request is pending
	scb_vcid	db 0	; virtual circuit ident number
	scb_num		db 0	; local name-number
	scb_baddr	dw 0	; buffer address, offset
			dw data ;  and segment
	scb_length	dw 0	; length of buffer data
	scb_rname	db '*               ' ; remote name, 16 chars space
	scb_lname	db '                ' ; local name      filled 
			db 0	; Receive timeout (0.5 sec units), want 0
			db 0	; Send timeout (0.5 sec units), want 0
	scb_post	dw 0	; interrupt driven post address, offset
			dw code ;  and segment
			db 0	; LAN_num (adapter #), set to zero for STARLAN
	scb_done	db 0	; command complete status
				; the 14 bytes below are normally 'reserved'
				; STARLAN uses 5 for long/special call names
				;  together with STARLAN specific Int 5bh
	scb_vrname	dw 0,0	; Variable length call name ptr offset,segment
	scb_vrlen	db 0	; length of vrname
			db 9 dup (0)	; reserved
scbst	ends			; 64 bytes overall

ifndef	no_network
rcv	scbst	<,,,,rcvbuf,,length rcvbuf,,,,,rpost>; declare scb for rcvr
else
rcv	scbst	<,,,,rcvbuf,,length rcvbuf,,,,,> ; declare scb for rcvr
endif	; no_network

ifndef	no_network
xmt	scbst	<,,,,xmtbuf,,length xmtbuf,,,,,spost>;  for xmtr
lsn	scbst	<,,,,xmtbuf,,length xmtbuf,,,,,lpost>;  for server listen
can	scbst	<>				     ;  for cancels
					; DECnet material
decint	equ	69h			; CTERM interrupt
dpresent equ	100h			; CTERM Installation check
dsend	equ	101h			; CTERM send byte
dread	equ	102h			; CTERM read byte
dcstat	equ	103h			; CTERM status
ddstat	equ	104h			; CTERM Decnet status
dopen	equ	105h			; CTERM open session
dclose	equ	106h			; CTERM close session
dgetscb	equ	10ah			; CTERM get SCB size

latint	equ	6ah			; LAT interrupt
latsend equ	1			; LAT send byte
latread	equ	2			; LAT read byte
latstat	equ	3			; LAT status
latsendb equ	4			; LAT send block (v4)
latreadb equ	5			; LAT read block (v4)
latinfo	equ	6			; LAT get miscellaneous information
latsrv	equ	0d500h			; LAT get next service name
latopen	equ	0d0ffh			; LAT open
latclose equ	0d000h			; LAT close
latbreak equ	0d100h			; LAT send a BREAK
latscbget equ	0d800h			; LAT get SCB interior to LAT
latscbfree equ	0d801h			; LAT free SCB interior to LAT
latcpyems equ	0d900h			; LAT copy to/from SCB in EMS or not

decneth	dw	0			; CTERM session handle
decseg	dw	0			; segment of CTERM SCB memory block
lathand	dw	0			; LAT session handle, high byte = 0ffh
latseg	dw	0			; LAT SCB seg in our memory
latversion db	4			; LAT major version number
latscbptr dd	0,0,0			; LAT, pointer to SCB

lcbst	struc				; LAT control block structure V4
	service	db	17 dup (0)	; 0 service     (number is offset)
		db	10 dup (0)	; 17 node, for future use
	lat_pwd	dd	0		; 27 password buffer ptr
	pwd_len	db	0		; 31 length of the buffer
		db	22 dup (0)	; 32 reserved
	stopped	dd	0		; 54 session stopped post routine addr
	overflow dd	0		; 58 service table overflow post addr
	xnotify	dd	0		; 62 transmit post routine addr
	rnotify	dd	0		; 66 receive post routine addr
	sstatus	dw	0		; 70 session status
		db	270 dup (0)	; 72 reserved
	slotqty	db	2		; 342 number receive data slots
	slotused db	0		; 343 number occupied slots
	slotnr	db	0		; 344 index of next rcv slot to use
	slotcur	db	0		; 345 index of current rcv slot
	slotptr dw	0		; 346 ptr to first received char
	slottbl	dw	0		; 348 ptrs to bufs for slot 1
		dw	0		; 350 and for slot 2
	slotbf1 db	259 dup (0)	; 352 first receive buffer
	slotbf2 db	259 dup (0)	; 611 second receive buffer
lcbst	ends				; total of 870 bytes

latservice db	17 dup (0)		; LAT host name
latpwd	db	16 dup (0),0		; LAT password, terminator
decmsg1	db	cr,lf,'Cannot create DECnet session.$'
decmsg3	db	' DECnet Error $'
decmsg4	db	cr,lf,' CTERM ready$'
decmsg5	db	cr,lf,' LAT ready$'
decmsg6 db	cr,lf,' Unable to allocate LAT SCB, trying CTERM$'
				; end of DECnet and TES-LAT

pcnet	db	0		; Network is functioning
nambuf	db	65 dup (0)	; network long name storage (STARLAN)
newnambuf db	0		; non-zero if new entry into namebuf above
internet db	4 dup (0)	; TELAPI Internet address, binary
telses	dw	0		; TELAPI session number
telport dw	23		; TELAPI Telnet port (defaults to 23)
sposted	db	0		; send interlock, 0 if no send posted
rposted	db	0		; rcv interlock, 0 if no receive posted
lposted	db	0		; listen outstanding (if non-zero)
netdbfr	db	0		; non-zero if net board is double buffered
lnamestat db	0		; status of local name 0 = default,
				;  1 = specified by user, 2 = locked in
deflname db	'mskermit.K      ' ; default local name, 16 bytes
ivt1str	db	'iVT1',0	; FGR - OpenNet VT handshake string
inettyp	db	0		; FGR - network type 'N' or 'O'
nsbrk	dw	0		; net can send Break
starlan	db	0		; non-zero if StarLAN net
chkmsg1	db	cr,lf,'?Cannot construct a local Kermit name, error = $'
setnbad db	cr,lf,'?Local Kermit NetBIOS name is already fixed.$'
chkmsg2	db	cr,lf,lf,' Name $'
chkmsg3	db	' is already in use. Please enter another of',cr,lf
setnbhlp db	' 1 - 14 letters or numbers (or nothing to quit): $'
netmsg1	db	cr,lf,' Checking if our node name is unique ...$'
netmsg2	db	cr,lf,' The network is active, our name is $'
netmsg3 db	cr,lf,'  NetBios local name: $'
netmsg4	db	'  Remote host: $'
netmsg5 db	cr,lf,'  DECnet host: $'
netmsg6 db	cr,lf,'  TELAPI Internet host: $'
netmsg6a db	'  port: $'
netmsg7	db	cr,lf,'  TES host name: $'
netmsg9	db	cr,lf,'  SuperLAT name: $'
netmsg8	db	cr,lf,'  EBIOS server port name: $'
nonetmsg db	cr,lf,'?The network is not available$'
noname	db	cr,lf,'?No name exists for the remote host.$'
dnetsrv	db	cr,lf,' Available LAT service names:',cr,lf,'$'
ngodset	db	cr,lf,' Connecting to network node: $'
nbadset	db	bell,cr,lf,'?Cannot reach network node: $'
recmsg	db	cr,lf,'?Network receive failed, status = $'
sndmsg	db	cr,lf,'?Network send failed, status = $'
naskpmt	db	cr,lf,' A network session is active.',cr,lf
	db	' Enter RESUME to resume it or NEW to start a new session:',0
nettab	db	2
	mkeyw	'New',0
	mkeyw	'Resume',1

acnop	equ	80h			; ACSI nop
		; second byte: null (ignored)
acenable equ	81h			; ACSI raise modem leads
		; second byte: DTR=01h, RTS=02h
acdisable equ	82h			; ACSI drop all modem leads
		; second byte: null (ignored)
acbreak	equ	83h			; ACSI send a BREAK
		; second byte: null (ignored)
acsetmode equ	84h			; ACSI set port Mode (speed etc)
; second byte: speed=3bits, parity=2bits, stopbits=1bit, databits=2bits
acmodem	equ	85h			; ACSI return modem leads state
		; second byte: DCD=80h, RI=40h, DSR=20h, CTS=10h
acreqmodem equ	86h			; ACSI request modem leads state
		; second byte: DCD=80h, RI=40h, DSR=20h, CTS=10h
acdelay	equ	87h			; ACSI pause transmission
		; second byte: delay in hundreths of second
acpace	equ	88h			; ACSI set flow control or pacing
	; second byte: direction send=10h, recv=20h; if pacing send=1, recv=2
acsetxon equ	89h			; ACSI set XON pacing character
		; second byte: char to represent resume transmission
acsetxoff equ	8ah			; ACSI set XOFF pacing character
		; second byte: char to represent cease transmission
; ACSI general read character status:	BREAK detected=10h, framing error=08h,
;					parity error=04h, overrun=02h

ebbufset equ	0ffh			; EBIOS set buf mode (1=send, 2=rcv)
ebbufcnt equ	0fdh			; EBIOS get buf count (1=send, 2=rcv)
ebpace	equ	0feh			; EBIOS set pacing mode (80h=send)
ebrcv	equ	0fch			; EBIOS receive, no wait
ebsend	equ	1			; EBIOS send a char
ebmodem	equ	0fbh			; EBIOS set modem leads
ebbreak	equ	0fah			; EBIOS send a BREAK
ebcontrol equ	0f9h			; EBIOS regain control
ebredir equ	0f6h			; EBIOS do port redirection
ebquery	equ	0f5h			; EBIOS get redirection info
ebpresent equ	0f4h			; EBIOS presence check

ebport	dw	0			; EBIOS equivalent serial port 0..3
ebcoms	db	0,0			; adapter (port), path (80h=network)
	db	16 dup (0)		; Call name (host)
	db	16 dup (0)		; Listen name (null)
	db	16 dup (0)		; local name (null = use lan adapter)
	db	0			; unique name (1 = group name)
ebmsg2	db	cr,lf,'?No server port name is known,'
	db	' reenter the command with a name.$'
ebmsg3	db	cr,lf,'?Unable to contact that port. Error code=$'
ebiostab db	4			; EBIOS table of local port names
	mkeyw	'1',1
	mkeyw	'2',2
	mkeyw	'3',3
	mkeyw	'4',4

ifndef	no_tcp
tcpadrst db	cr,lf,'  tcp/ip address: $'	; TCP/IP status msgs
tcpsubst db	cr,lf,'  tcp/ip subnetmask: $'
tcpdomst db	cr,lf,'  tcp/ip domain: $'
tcpgatest db	cr,lf,'  tcp/ip gateway: $'
tcppnsst db	cr,lf,'  tcp/ip primary-nameserver: $'
tcpsnsst db	cr,lf,'  tcp/ip secondary-nameserver: $'
tcpbcstst db	cr,lf,'  tcp/ip broadcast: $'
tcphostst db	cr,lf,'  tcp/ip host: $'
tcpportst db	cr,lf,'  tcp/ip port: $'
tcpdebst db	cr,lf,'  tcp/ip debug-Options: $'
tcpbinst db	cr,lf,'  telnet mode: $'
tcppdintst db	',  Packet-Driver-interrupt: \x$'
tcppdnul db	' (search for it)$'
tcpodi	db	'   using ODI interface$'
tcpttyst db	cr,lf,'  telnet term-type: $'
tcpttynul db	'(report real terminal type)',0	; ASCIIZ
tcpnlst	db	cr,lf,'  telnet newline-mode: $' 
tcpnlmsg0 db	'off (CR->CR NUL)$'
tcpnlmsg1 db	'on (CR->CR LF)$'
tcpnlmsg2 db	'raw (CR->CR)$'
tcpdeboff db	'off$'
tcpdebstat db	'status$'
tcpdebtim db	'timing$'
tcpdebon db	'on$'
tcpmodemsg0 db	'NVT-ASCII$'
tcpmodemsg1 db	'Binary$'
tcpbtpbost db	'        from BOOTP host: $'
tcpbtpdhst db	'        from DHCP host: $'
tcpbtprast db	'        from RARP host: $'
tcpmssst db	cr,lf,'  tcp/ip mss: $'
endif	; no_tcp

badport	db	cr,lf,'?Port 25 is forbidden, sorry. Using 23 for Telnet.$'
maxsessions	equ	6		; max sessions, also in msntnd.c
seslist	db	maxsessions dup (-1) ; list of Telnet session idents, -1=dead
seshostlen equ	61			; length of host name, asciiz
sesname	db	maxsessions*seshostlen dup (0)	; host names, asciiz.
sesport	dw	maxsessions dup (23)	; Telnet ports
sestime db	maxsessions * 4 dup (0)	; start time dd, hh, mm, ss
sescur	dw	-1			; Current session (0..5)
sesheader db	cr,lf,'         status    session   port hostname$'
sesinact  db	cr,lf,'         inactive     $'
sesactive db	cr,lf,'         active       $'
curmsg	  db	cr,lf,'         current >    $'
curinact  db	cr,lf,'         inactive >   $'
sesnone	  db	cr,lf,' Error, all sessions are in use$'
sesnohost db	cr,lf,' Oops, no host name is available$'
seshelp	db	cr,lf,lf,' choices  R           return to active session'
	db	cr,lf,'          1..6        pick a new or existing session'
	db	cr,lf,'          N           start a new session (default)'
	db	cr,lf,'          Q	     quit this command'
	db	cr,lf
	db	cr,lf,'Choice> $'
endif	; no_network
data	ends

data1	segment
ifndef	no_network
nethlp	db	cr,lf,'  node name of remote system,'
	db	cr,lf,'  or press ENTER to use current name,'
	db	cr,lf,'  or press ENTER for server mode (NetBios only).$'
dnethlp	db	cr,lf,'  node name of remote system,'
	db	cr,lf,'  or press ENTER to use current name,'
	db	cr,lf,'  or  *  to see a list of LAT service names.$'
nethlp2	db	cr,lf,' Optional LAT password, if using a LAT connection$'
ebhlp	db	'Name of server port$'	
setnbhlp2 db	' 1 - 14 letters or numbers (or nothing to quit): $'
telhlp	db	'Internet address nnn.nnn.nnn.nnn$'
telhlp2	db	'Optional TCP port (default is 23)$'
ifndef	no_tcp
tcphlp	db	cr,lf,' Host Internet name  machine.domain  or'
	db	' Internet address  nnn.nnn.nnn.nnn'
	db	cr,lf,'  or  *  to become a Telnet server.'
	db	cr,lf,' Optional TCP port number and NEW or RESUME'
	db	' may follow the host name.$'
tcpporthlp db	cr,lf,' TCP port on host, 23 is Telnet, or'
tcpnewhlp db	cr,lf,' NEW session or RESUME current session$'
endif	; no_tcp
endif	; no_network
fossilhlp db	cr,lf,' Fossil port, 1..99. No Fossil checking is done!$'
hnghlp	db	cr,lf,' The modem control lines DTR and RTS for the current'
	db	' port are forced low (off)'
	db	cr,lf,' to hangup the phone. Normally, Kermit leaves them'
	db	' high (on) when it exits.',cr,lf
	db	' For networks, the active session is terminated.',cr,lf,'$'
data1	ends

code1	segment
	assume	cs:code1
	extrn	iseof:far, tolowr:far, strcat:far
	extern	atsclr:near, setpos:near, setatch:near
	extrn	strcpy:far, strlen:far, prtasz:far, prtscr:far
	extrn	valout:far, domath:far, decout:far
ifndef	no_tcp	
ifndef	no_terminal
	extern	termswapin:far, termswapdel:far, termswapout:far
endif	; no_terminal
endif	; no_tcp

fatsclr	proc	far
	call	atsclr
	ret
fatsclr	endp
fsetatch proc	far
	call	setatch
	ret
fsetatch endp
fsetpos	proc	far
	call	setpos
	ret
fsetpos	endp
code1	ends

code	segment
	extrn	comnd:near, prompt:near, dopar:near, lclyini:near
	extrn	crun:near
ifndef	no_terminal
	extrn	kbsusp:near, kbrest:near		; in msuibm.asm
endif	; no_terminal

	assume	cs:code, ds:data, es:nothing

foutchr	proc	far
	call	outchr
	ret
foutchr	endp
fdopar	proc	far
	call	dopar
	ret
fdopar	endp

; local initialization

lclini	proc	near
	call	pcwtst		; calibrate software timer
	call	pcwtst
	mov	flags.comflg,1	; assume COM1 for communications port
	call	model		; get model of IBM machine
	mov	lclsusp,offset suspend ; call this when suspending to DOS
	mov	lclrest,offset restore ; call this when returning from DOS
	mov	lclexit,offset finexit ; call this when exiting Kermit
	call	getcodep		; get Code Page ident
	call	lclyini		; let other modules initialize too...
	ret
lclini	endp

; Call these routines when suspending Kermit to go to DOS
suspend	proc	near
ifndef	no_terminal
	call	kbsusp		; DEC LK250 keyboard, set back to DOS mode
endif	; no_terminal
	cmp	flags.comflg,'t'; doing TCP?
	je	suspen1		; e = yes, don't touch port
	cmp	portin,0	; port initialized yet?
	jle	suspen1		; l = no, e = yes but inactive
	call	ihosts		; suspend the host
	mov	ax,20		; wait 20 millisec for port to finish
	call	pcwait
	call	serrst
suspen1:ret
suspend	endp

; Call these routines when returning to Kermit from DOS
restore	proc	near
	call	getcodep	; reset Code Page ident
ifndef	no_terminal
	call	kbrest		; DEC LK250 keyboard, set back to DEC mode
endif	; no_terminal
	cmp	flags.comflg,'t'; doing TCP?
	je	restor1		; e = yes, don't touch port
	cmp	portin,0	; port initialized yet?
	jl	restor1		; l = no
	call	serini		; reinit serial port
	call	ihostr		; resume the host
restor1:ret
restore	endp

; Call these routines when doing final exit of Kermit
finexit	proc	near
	cmp	flags.carrier,0 ; be concerned about CD?
	je	finex4		; e = no
	call	testcd		; update cardet byte
	test	cardet,80h	; is carrier detect still active?
	jnz	finex3		; nz = yes
finex4:	cmp	nettype,0	; any network connections open?
	je	finex2		; e = no, but go through the motions anyway
finex3:	cmp	flags.exitwarn,0 ; warn about active session?
	je	finex2		; e = no, just kill the sessions
	mov	dx,offset clomsg ; say connection going, ask for permission
	call	prompt
	mov	dx,offset clotab ; table of choices
	xor	bx,bx		; help
	mov	ah,cmkey	; get keyword
	call	comnd
	jc	finex5		; c = failure
	push	bx
	mov	ah,cmeol
	call	comnd
	pop	bx
	jnc	finex1		; nc = got good response
finex5:	ret			; return carry set to say don't close
finex1:	or	bx,bx		; ok to close
	jz	finex2		; e = yes
	stc			; carry set to say don't close
	ret
finex2:	call	serrst		; reset serial port
ifndef	no_network
	call	netclose	; close network connections
endif	; no_network
ifndef	no_terminal
	call	kbsusp		; DEC LK250 keyboard, set back to DOS mode
endif	; no_terminal
	clc			; return with permission to exit
	ret
finexit	endp

; The IBM PC's.
model	proc	near
	mov	isps2,0			; PS/2 present indicator
	push	es
	push	ax			; get IBM model code
	mov	al,byte ptr es:[0fffeh]	; get model id byte
	mov	ah,0ch			; AT and PS/2 configuration call
	xor	al,al
	int	15h			; IBM Bios
	jc	model4			; c = no information
	cmp	word ptr es:[bx+2],040fch ; PS/2 model 50?
	je	model3			; e = yes
	cmp	word ptr es:[bx+2],050fch ; PS/2 model 60?
	je	model3			; e = yes
	cmp	byte ptr es:[bx+2],0f8h ; PS/2 model 80?
	jne	model4			; ne = no
model3:	mov	isps2,1			; say real PS/2 for IRQ setting
model4:
;;; [HF] 940130 The following section checks Japanese PS/55 mode
;;; [HF] 940130 moved from dvtest in MSYIBM.ASM
	mov	isps55,0		; [HF] 940130 assume not PS/55
	push	ds
	mov	ax,ds			; preset es:si to start of data seg
	mov	es,ax			; as saftey factor after test
	xor	si,si
	mov	ax,6300h		; get Double Byte Char Set Lead Table
	int	dos			; returns ptr in ds:si
	mov	bx,ds			; cannot trust al as return status
	mov	es,bx
	pop	ds
	mov	ax,ds			; current DS
	cmp	ax,bx			; same seg?
	je	modelx			; e = yes, test failed
	cmp	word ptr es:[si],0	; see if both bytes are also zeros
	je	modelx			; z = test failed
	mov	isps55,1		; [HF] say Japanese PS/55 is active
	mov	ax,1402h		; [HF]940206 check the modeline status
	int	16h			; [HF]940206 Keyboard Bios
	mov	ps55mod,al		; [HF]940206 save it in current status
	mov	byte ptr ps55mod+1,al	; [HF]940206 and in startup status
modelx:	pop	ax
	pop	es
	ret
model	endp

; Get the currently active Code Page ident into flags.chrset. User defined
; table overrides DOS report.
getcodep proc	near
	cmp	flags.chrset,1		; user-defined table in use?
	je	getcod1			; e = yes
	cmp	flags.chrset,866	; forced CP866 in use?
	je	getcod1			; e = yes
	mov	flags.chrset,437	; find default global char set
	cmp	dosnum,0300h+30		; DOS version 3.30 or higher?
	jb	getcod1			; b = no, no Code Pages
	mov	ax,6601h		; get global Code Page
	int	dos			; bx=active Code Page, dx=boot CP
	jc	getcod1
	mov	flags.chrset,bx		; setup default SET FILE CHAR SET
	mov	vtcpage,bx		; set terminal Code Page too
getcod1:ret
getcodep endp

; show the definition of a key.  The terminal argument block (which contains
; the address and length of the definition tables) is passed in ax.
; Returns a string to print in AX, length of same in CX.
; Returns normally. Obsolete, name here for external reference only.
showkey	proc	near
	ret				; return
showkey	endp
code	ends

code1	segment
	assume	cs:code1

ifndef	no_tcp
ftcpstats proc	far			; TCP/IP status display
	mov	ah,prstr
	mov	dx,offset tcpadrst
	int	dos
	mov	dx,offset tcpaddress	; tcpaddress string
	call	prtasz
	mov	bx,offset tcpbtpserver
	cmp	byte ptr [bx],0		; bootp etc host?
	je	ftcpst4			; e = no
	mov	dx,offset tcpbtpbost	; show BOOTP title
	cmp	tcpbtpkind,1		; did BOOTP?
	je	ftcpst4a		; e = yes
	mov	dx,offset tcpbtpdhst	; show DHCP title
	cmp	tcpbtpkind,3		; did DHCP?
	je	ftcpst4a		; e = yes
	mov	dx,offset tcpbtprast	; show RARP title
ftcpst4a:int	dos
	mov	dx,bx			; show boot host IP
	call	prtasz
ftcpst4:mov	dx,offset tcpsubst
	int	dos
	mov	dx,offset tcpsubnet	; tcp subnetmask string
	call	prtasz
	mov	dx,offset tcpdomst
	int	dos
	mov	dx,offset tcpdomain	; tcp domain string
	call	prtasz
	mov	dx,offset tcpgatest
	int	dos
	mov	dx,offset tcpgateway	; tcp gateway string
	call	prtasz
	mov	dx,offset tcppnsst
	int	dos
	mov	dx,offset tcpprimens	; tcp primary nameserver 
	call	prtasz
	mov	dx,offset tcpsnsst
	int	dos
	mov	dx,offset tcpsecondns	; tcp secondary nameserver
	call	prtasz
	mov	dx,offset tcpbcstst
	int	dos
	mov	dx,offset tcpbcast	; tcp broadcast address
	call	prtasz
	mov	dx,offset tcpportst
	int	dos
	push	ax
	push	bx
	push	cx
	mov	bx,offset tcpport	; tcp port
	mov	ax,[bx]
	call	decout
	mov	ax,tcppdint		; Packet Driver interrupt
	cmp	ax,'DO'			; using ODI?
	jne	ftcpst3			; ne = no
	mov	ah,prstr
	mov	dx,offset tcpodi	; say using ODI interface
	int	dos
	jmp	short ftcpst1
ftcpst3:push	ax			; save value
	mov	ah,prstr
	mov	dx,offset tcppdintst
	int	dos
	pop	ax
	mov	cx,16
	push	ax
	call	valout			; show value as hex
	pop	ax
	or	ax,ax			; null?
	jnz	ftcpst1			; nz = no, just show value
	mov	ah,prstr
	mov	dx,offset tcppdnul	; show search msg
	int	dos
ftcpst1:pop	cx
	pop	bx
	pop	ax
	mov	dx,offset tcpttyst
	int	dos
	mov	dx,offset tcpttbuf	; tcp term-type override
	push	bx
	mov	bx,dx
	cmp	byte ptr [bx],0
	jne	ftcpst2
	mov	dx,offset tcpttynul	; alternate msg
ftcpst2:pop	bx
	call	prtasz
	mov	dx,offset tcpnlst	; newline mode msg
	int	dos
	push	bx
	mov	bl,tcpnewline		; tcpnewline value of 0 (off) or 1
	mov	dx,offset tcpnlmsg1	; assume on
	cmp	bl,1			; on?
	pop	bx
	je	ftcpst5			; e = yes
	mov	dx,offset tcpnlmsg0	; assume off
	jb	ftcpst5			; b = correct
	mov	dx,offset tcpnlmsg2	; then use raw
ftcpst5:
	mov	ah,prstr
	int	dos
	mov	dx,offset tcpbinst	; debug-option
	int	dos
	push	bx
	mov	bl,tcpmode		; tcpmode
	mov	dx,offset tcpmodemsg0	; assume NVT-ASCII
	or	bl,bl			; NVT?
	pop	bx
	jz	ftcpst6			; z = yes, NVT
	mov	dx,offset tcpmodemsg1	; say BINARY
ftcpst6:mov	ah,prstr
	int	dos
	mov	dx,offset tcpmssst	; MSS
	int	dos
	mov	ax,tcpmss
	call	decout			; show value
	mov	ah,prstr
	mov	dx,offset tcpdebst	; debug-option
	int	dos
	push	bx
	mov	bl,tcpdebug		; offset of tcpdebug
	mov	dx,offset tcpdeboff	; assume off
	or	bl,bl			; off?
	jz	ftcpst7			; e = yes
	mov	dx,offset tcpdebstat	; status
	cmp	bl,1
	je	ftcpst7			; e = yes
	mov	dx,offset tcpdebtim	; timing
	cmp	bl,2
	je	ftcpst7			; e = yes
	mov	dx,offset tcpdebon	; say on
ftcpst7:pop	bx
	mov	ah,prstr
	int	dos
	mov	dx,offset tcphostst
	int	dos
	mov	dx,offset tcphost	; tcp host IP ident string
	call	prtasz
	ret
ftcpstats endp
endif	; no_tcp
code1	ends

code	segment
	assume	cs:code

; SHOW MODEM, displays current status of lines DSR, CD, and CTS.
; Uses byte mdmhand, the modem line status register.
shomodem proc	near
	mov	ah,cmeol		; get a confirm
	call	comnd
	jnc	shomd1a			; nc = success
	ret
shomd1a:cmp	flags.comflg,'F'	; Fossil?
	je	shomd1b			; e = yes
	cmp	flags.comflg,'4'	; hardware or Bios?
	ja	shomd3c			; a = no, show nothing
shomd1b:mov	dx,offset msmsg7	; no modem status for network
	call	getmodem		; get modem status
	mov	mdmhand,al
	mov	ah,prstr
	mov	dx,offset msmsg1	; modem ready msg
	test	mdmhand,20h		; is DSR asserted?
	jz	shomd1			; z = no
	mov	dx,offset msmsg2	; say not asserted
shomd1:	int	dos
	mov	dx,offset msmsg3	; CD asserted msg
	test	mdmhand,80h		; CD asserted?
	jz	shomd2			; z = no
	mov	dx,offset msmsg4	; say not asserted
shomd2:	int	dos
	mov	dx,offset msmsg20	; CD sensitive
	cmp	flags.carrier,0		; be sensitive?
	jne	shomd2a			; ne = yes
	mov	dx,offset msmsg21	; CD insenstive
shomd2a:int	dos
	mov	dx,offset msmsg5	; CTS asserted msg
	test	mdmhand,10h		; CTS asserted?
	jz	shomd3			; z = no
	mov	dx,offset msmsg6	; say not asserted
shomd3:	mov	ah,prstr
	int	dos
	mov	al,flags.comflg
	cmp	al,'1'			; UART?
	jae	shomd3c			; ae = no
	add	al,'0'			; COMnumber
	mov	msmsg8+7,al		; stuff in msg
	mov	ah,prstr
	mov	dx,offset msmsg8	; show port base address
	int	dos
	mov	ax,modem.mddat		; port address
	mov	cx,16			; in hex
	call	valout
	mov	ah,prstr
	mov	dx,offset msmsg9	; and IRQ
	int	dos
	mov	ax,modem.mdintv		; interrupt vector
	mov	cl,al
	and	ax,7			; lower three bits of IRQ
	cmp	cl,60h			; using cascaded 8259?
	jb	shomd3a			; b = no
	add	ax,8			; say IRQ 8..15
shomd3a:call	decout			; output as decimal
	cmp	modem.mdfifo,0		; UART FIFO active?
	je	shomd3b			; e = no
	mov	dx,offset msmsg10	; FIFO msg
	mov	ah,prstr
	int	dos
shomd3b:mov	bx,portval
	mov	al,[bx].stopbits	; number of stop bits (1 or 2)
	add	al,'0'
	mov	msmsg14+2,al		; change the visible number
	mov	dx,offset msmsg14
	mov	ah,prstr
	int	dos
	clc
	ret
shomd3c:cmp	flags.comflg,'F'	; Fossil?
	jne	shomd4			; ne = no
	mov	ah,prstr
	mov	dx,offset msmsg11
	int	dos
	mov	ax,fossil_port
	inc	ax			; count from 1
	xor	dx,dx
	mov	cx,10			; decimal
	call	valout
	mov	ah,prstr
	mov	dx,offset msmsg12
	cmp	fossilflag,0		; do not close on done?
	je	shomd3d			; e = yes
	mov	dx,offset msmsg13
shomd3d:int	dos
shomd4:	clc
	ret
shomodem endp

; Show status of network connections
shownet	proc	near
	mov	ah,cmeol		; get a confirm
	call	comnd
	jnc	shonet0			; nc = success
	ret
shonet0:
ifndef	no_network
ifndef	no_tcp
	call	ftcpstats		; call TCP/IP FAR worker
endif	; no_tcp
	mov	dx,offset netmsg3	; local name
	mov	ah,prstr
	int	dos
	mov	cx,16
	mov	di,offset deflname	; default Netbios name
	call	prtscr
	cmp	rcv.scb_lname,' '	; have NetBios name yet?
	jbe	shonet1			; be = no, skip this part
	mov	ah,prstr
	mov	dx,offset netmsg4	; remote name
	int	dos
	mov	cx,16
	mov	di,offset rcv.scb_rname
	call	prtscr
shonet1:cmp	latservice,0		; DECnet name available?
	je	shonet3			; e = no
	mov	ah,prstr
	mov	dx,offset netmsg5
	cmp	latkind,DEC_LAT		; DEC_LAT?
	je	shonet2			; e = yes
	mov	dx,offset netmsg7	; TES heading
	cmp	latkind,TES_LAT		; TES_LAT?
	je	shonet2			; e = yes
	mov	dx,offset netmsg9	; Meridian SuperLAT
shonet2:int	dos
	mov	dx,offset latservice	; network host name, asciiz
	call	prtasz
shonet3:cmp	word ptr internet,0	; have TELAPI Internet address?
	je	shonet6			; e = no
	mov	ah,prstr
	mov	dx,offset netmsg6
	int	dos
	xor	bx,bx			; subscript
	mov	cx,4			; four fields
shonet4:mov	al,internet[bx]		; binary internet address
	xor	ah,ah
	call	decout
	cmp	cx,1			; doing last field?
	je	shonet5			; e = yes, no dot
	mov	dl,'.'
	mov	ah,conout
	int	dos
shonet5:inc	bx
	loop	shonet4
	mov	dx,offset netmsg6a	; port:
	mov	ah,prstr
	int	dos
	mov	ax,telport		; port
	call	decout

shonet6:cmp	tesname,0		; have TES name?
	je	shonet7			; e = no
	mov	ah,prstr
	mov	dx,offset netmsg7
	int	dos
	mov	dx,offset tesname	; node name
	call	prtasz			; show, asciiz
	clc
	ret
shonet7:cmp	ebcoms+2,0		; have an EBIOS name?
	je	shonet8			; e = no
	mov	ah,prstr
	mov	dx,offset netmsg8
	int	dos
	mov	cx,16
	mov	di,offset ebcoms+2	; host port, 16 chars space filled
	call	prtscr
shonet8:
endif	; no_network
	clc
	ret
shownet	endp

; Get modem status and set global byte mdmhand. Preserve all registers.
getmodem proc	near			; gets modem status upon request
	cmp	portin,1		; port active?
	je	getmod1			; e = yes
	mov	bl,flags.comflg		; pass current port ident
	cmp	bl,'4'			; above UART and Bios?
	ja	getmod1			; a = yes, do not start the port
	call	comstrt			; do SET PORT command now
	jnc	getmod1			; nc = success
	ret				; failed to set port
getmod1:xor	al,al			; assume nothing is on
	cmp	flags.comflg,'1'	; UART?
	jae	getmod2			; ae = no
	cmp	flags.comflg,0		; null port?
	je	getmodx			; e = yes, no status
	call	serini
	mov	dx,modem.mdstat		; hardware, line status reg
	inc	dx			; modem status reg
	in	al,dx
	push	ax
	call	serrst
	pop	ax
	jmp	short getmodx
getmod2:cmp	flags.comflg,'4'	; above Bios? (networks)
	ja	getmod3			; a = yes, no status
	mov	ah,3			; ask Bios for modem status into al
	push	dx
	xor	dh,dh
	mov	dl,flags.comflg		; get port id
	sub	dl,'1'			; remove ascii bias (BIOS1 -> 0)
	int	rs232
	pop	dx
	jmp	short getmodx

getmod3:
ifndef	no_network
	cmp	flags.comflg,'E'	; IBM EBIOS?
	jne	getmodx			; ne = no
	mov	ah,3			; get Bios style modem status
	push	dx
	mov	dx,ebport		; current EBIOS port
	int	rs232
	pop	dx
endif	; no_network
getmodx:xor	ah,ah			; return status in al
	clc
	ret
getmodem endp

; Clear the input buffer. This throws away all the characters in the
; serial interrupt buffer.  This is particularly important when
; talking to servers, since NAKs can accumulate in the buffer.
; Returns normally.

CLRBUF	PROC	NEAR
	mov	flags.cxzflg,0
	cmp	repflg,0		; REPLAY?
	je	clrbuf1			; e = no
	ret
clrbuf1:mov	ah,gswitch
	xor	al,al			; pick up switch character
	int	dos			; invokes DOS to see Control-C
	cmp	flags.cxzflg,'C'	; user typed Control-C?
	je	clrbuf2			; e = yes, quit now
	call	prtchr			; read from active comms port
	jnc	clrbuf1			; nc = got a char, continue til none
	mov	ax,100			; wait 100 ms
	call	pcwait
	call	prtchr			; read from active comms port
	jnc	clrbuf1			; nc = got a char, continue til none
clrbuf2:mov	flags.cxzflg,0
	clc
	ret
CLRBUF	ENDP

; Clear to the end of the current line.  Returns normally.
; Upgraded for Topview compatibility.
CLEARL	PROC	NEAR
	push	ax
	push	bx
	push	dx
	mov	ah,3			; Clear to end of line
	xor	bh,bh
	int	video			; Get current cursor position into dx
	mov	ax,dx			; Topview compatible clear line
	mov	bh,ah			; same row
	mov	bl,byte ptr low_rgt	; last column
	call	fatsclr			; clear from ax to bx, screen coord
	pop	dx
	pop	bx
	pop	ax
	ret
CLEARL	ENDP

; This routine blanks the screen.  Returns normally.
; Upgraded to Topview compatiblity.
CMBLNK	PROC	NEAR
	push	ax
	push	bx
	xor	ax,ax		; from screen loc 0,0
	mov	bx,low_rgt	; to end of text screen (lower right corner)
	cmp	isps55,0	; [HF] Japanese PS/55?
	je	cmblnk1		; [HF] e = no
	cmp	ps55mod,0	; [HF] can access modeline ?
	je	cmblnk2		; [HF] e = no, system uses it. Do not access
cmblnk1:inc	bh		; include status line
cmblnk2:call	fatsclr		; do Topview compatible clear, in msyibm
	pop	bx
	pop	ax
	ret
CMBLNK  ENDP

; Locate: homes the cursor.  Returns normally.

LOCATE  PROC	NEAR
	xor	dx,dx			; Go to top left corner of screen
	jmp	poscur
LOCATE  ENDP
 
; Position the cursor according to contents of DX:
; DH contains row, DL contains column.  Returns normally.
POSCUR	PROC	NEAR
	push	ax
	push	bx
	mov	ah,2			; Position cursor
	xor	bh,bh			; page 0
	int	video
	pop	bx
	pop	ax
	ret
POSCUR	ENDP

; Delete a character from the screen.  This works by printing
; backspaces and spaces.

DODEL	PROC	NEAR
	mov	ah,prstr
	mov	dx,offset delstr	; Erase character
	int	dos			
	ret
DODEL	ENDP

; Move the cursor to the left margin, then clear to end of line.

CTLU	PROC	NEAR
	mov	ah,prstr
	mov	dx,offset clrlin
	int	dos
	call	clearl
	ret
CTLU	ENDP


BEEP	PROC	NEAR
	mov	timeract,1	; say timer chip is being used here
	push	ax
	push	cx
	mov	al,10110110B	; Gen a short beep (long one losses data.)
	out	timercmd,al	; set Timer to mode 3
	mov	ax,1512		; divisor, for frequency
	out	timer2data,al	; send low byte first
	mov	al,ah
	out	timer2data,al
	in	al,ppi_port	; get 8255 Port B setting
	or	al,3		; turn on speaker and timer
	out	ppi_port,al	; start speaker and timer
	push	ax
	mov	ax,40		; 40 millisecond beep, calibrated time
	call	pcwait
	pop	ax
	in	al,ppi_port
	and	al,0fch		; turn off speaker and timer
	out	ppi_port,al
	pop	cx
	pop	ax
	mov	timeract,0	; say timer chip is no longer in use here
	clc
	ret
BEEP	ENDP 


; write a line in inverse video at the bottom of the screen...
; the line is passed in dx, terminated by a $.  Returns normally.
putmod	proc	near
	push	ax		; save regs
	push	bx
	push	cx
	push	dx
	push	si
	mov	si,dx		; preserve message
	mov	bl,scbattr	; screen attributes
	push	bx		; save scbattr
	and	bl,77h		; get colors, omit bright and blink
	rol	bl,1		; interchange fore and background
	rol	bl,1
	rol	bl,1
	rol	bl,1
	mov	scbattr,bl
	call	clrmod		; clear mode line to inverse video
	cmp	isps55,0	; [HF]940209 Japanese PS/55?
	je	putmo3		; [HF]940209 e = no
	push	ax		; [HF]940209
	mov	ax,1401h	; [HF]940209 disable system modeline
	mov	ps55mod,al	; [HF]940209 remember it
	int	16h		; [HF]940209
	pop	ax		; [HF]940209
putmo3:	mov	dx,low_rgt	; lower right corner
	inc	dh		;  of status line
	xor	dl,dl		; start on left
	mov	ah,scbattr	; inverse video attribute
	cld
putmo1:	lodsb			; get a byte
	cmp	al,'$'		; end of string?
	je	putmo2
	call	fsetatch	; write char and attribute
	inc	dl		; increment for next write
	cmp	dl,crt_cols	; beyond physical right border?
	jb	putmo1		; b = no
putmo2:	pop	bx
	mov	scbattr,bl
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
putmod	endp

; clear the mode line written by putmod.
clrmod	proc	near
	cmp	isps55,0		; [HF]940206 is Japanese PS/55?
	je	clrmod1			; [HF]940206 e = no, skip next proc.
	cmp	ps55mod,0		; [HF]940206 can we use modeline?
	jne	clrmod1			; [HF]940206 ne = yes, keep going
	push	ax			; [HF]940206 no, change the status
	mov	ax,1401h		; [HF]940208 access to modeline
	mov	ps55mod,al		; [HF]940208 change the status
	int	16h			; [HF]940208
	pop	ax			; [HF]940208
clrmod1:push	ax			; save regs
	push	bx
	mov	bx,low_rgt		; ending loc is lower right corner
	inc	bh			;  of status line
	mov	ah,bh
	xor	al,al			; column zero
	call	fatsclr			; clear this region
	cmp	isps55,0		; [HF]940206 is Japanese PS/55?
	je	clrmod2			; [HF]940206 e = no
	mov	ah,14h			; [HF]940206
	mov	al,byte ptr ps55mod+1	; [HF]940206 return to start value
	mov	ps55mod,al		; [HF]940206
	int	16h			; [HF]940206
clrmod2:pop	bx
	pop	ax
	ret
clrmod	endp

; put a help message on the screen.  This one uses reverse video...
; pass the message in ax, terminated by a null.
puthlp	proc	near
	push	bx		; save regs
	push	cx
	push	dx
	push	si
	push	ax		; preserve this
	cld
	mov	bl,scbattr	; screen attributes at Kermit init time
	and	bl,77h		; get colors, omit bright and blink
	rol	bl,1		; interchange fore and background
	rol	bl,1
	rol	bl,1
	rol	bl,1
	xor	bh,bh		; preset page 0
	mov	temp,bx		; temp = page 0, reverse video 

	mov	si,ax		; point to it
	mov	dh,1		; init counter
puthl1:	lodsb			; get a byte
	cmp	al,lf		; linefeed?
	jne	puthl2		; no, keep going
	inc	dh		; count it
	jmp	short puthl1	; and keep looping
puthl2:	or	al,al		; end of string?
	jnz	puthl1		; nz = no, keep going
	mov	ax,600h		; scroll to clear window
	xor	cx,cx		; from top left
	mov	dl,4fh		; to bottom right of needed piece
	mov	bh,bl		; inverse video
	int	video
	call	locate		; home cursor
	xor	bh,bh
	mov	bx,temp
	mov	cx,1		; one char at a time
	cld			; scan direction is forward
	pop	si		; point to string again
puthl3:	lodsb			; get a byte
	or	al,al		; end of string?
	jz	puthl4		; z = yes, stop
	push	si		; save around bios call
	cmp	al,' '		; printable?
	jb	puth21		; b = no
	mov	ah,9		; write char at current cursor position
	int	video		; do the Bios int 10h call
	inc	dl		; point to next column
	jmp	short puth23	; move cursor there
puth21:	cmp	al,cr		; carriage return?
	jne	puth22		; ne = no
	xor	dl,dl		; set to column zero
	jmp	short puth23
puth22:	cmp	al,lf		; line feed?
	jne	puth23
	inc	dh		; go to next line
puth23:	mov	ah,2		; set cursor position to dx
	int	video
	pop	si		; restore pointer
	jmp	short puthl3	; and keep going
puthl4:	mov	dh,byte ptr low_rgt+1	; go to last line
	inc	dh
	cmp	isps55,0	; [HF]940211 Japanese PS/55?
	je	puthl5		; [HF]940211 e = no
	cmp	ps55mod,0	; [HF]940211 system uses bottom line?
	jne	puthl5		; [HF]940211 ne = no
	dec	dh		; [HF]940211 do not touch bottom line
puthl5:	xor	dl,dl
	call	poscur		; position cursor
	pop	si
	pop	dx
	pop	cx
	pop	bx
	ret
puthlp	endp


; set the current port.  
; Note: serial port addresses are found by looking in memory at 40:00h and
; following three words for COM1..4, resp. All UARTS are assumed to follow
; std IBM addresses relative to 03f8h for COM1, and actual address are offset
; from value found in segment 40h. Global byte flags.comflg is 1,2,3,4 for
; COM1..4, and is 'N' for NetBios, etc.
; 'O' is for Intel Opennet Network (FGR)
; If address 02f8h is found in 40:00h then name COM1 is retained but COM2
;  addressing is used to access the UART and a notice is displayed. IRQ 3
; or IRQ 4 is sensed automatically for any COMx port.
COMS	PROC	NEAR
	mov	dx,offset comptab	; table of legal comms ports
	xor	bx,bx			; no extra help text
	mov	ah,cmkey		; parse key word
	call	comnd
	jnc	coms0a			; nc = success
	ret				; failure
coms0a:	cmp	bl,'4'			; networks?
	ja	coms0b			; a = yes
	mov	ah,cmeol		; non-network
	push	bx
	call	comnd			; get a confirm
	pop	bx
	jnc	coms0b			; nc = success
	ret				; failure
coms0b:	mov	reset_clock,1		; reset elapsed time clock

COMSTRT:mov	temp,bx			; port ident is in BL
	cmp	bl,'F'			; Fossil?
	jne	comst12			; ne = no
	jmp	comsf
comst12:

ifndef	no_network
	cmp	bl,'N'			; NetBios network?
	jne	comst2a			; ne = no
  	jmp	comsn			; yes, get another item for networks
comst2a:cmp	bl,'O'			; Opennet network?
  	jne	comst2			; ne = no
	jmp	comso			; yes, get another item for networks

comst2:	cmp	bl,'U'			; Ungermann Bass net?
	jne	comst3			; ne = no
	jmp	comsub
comst3:	cmp	bl,'D'			; DECnet?
	jne	comst4			; ne = no
	jmp	comsd			; do DECnet startup
comst4:	cmp	bl,'E'			; IBM EBIOS?
	jne	comst5			; ne = no
	test	nettype,acsi		; NetBios without EBIOS.COM?
	jz	comst4a			; z = no, using EBIOS.COM
	mov	inettyp,bl		; set type code
	jmp	comso2			; do NetBios setup
comst4a:jmp	comse			; do EBIOS checkup
comst5:	cmp	bl,'W'			; Novell NASI?
	jne	comst6			; ne = no
	jmp	comsub
comst6:	cmp	bl,'C'			; 3Com BAPI?
	jne	comst7			; ne = no
	jmp	comsbapi
comst7:	cmp	bl,'T'			; Novell TELAPI
	jne	comst8			; ne = no
	jmp	comstelapi
comst8:	cmp	bl,'I'			; TES?
	jne	comst9			; ne = no
	jmp	comsteslat
comst9:	cmp	bl,'t'			; Telnet, internal?
	jne	comst10			; ne = no
ifndef	no_tcp
	jmp	comstn
endif	; no_tcp
comst10:cmp	bl,'M'			; Meridian Superlat?
	jne	comst11			; ne = no
	jmp	comsmedlat

comst11:cmp	bl,'b'			; [JRS] Beame & Whiteside TCP?
	jne	coms1c			; ne = no
	jmp	comsbw			; setup BW connection
  					; stop sources of NetBios interrupts
coms1c:	call	nbclose			; close NetBios session now
endif	; no_network
	
coms2:	call	serrst			; close current comms port
	mov	al,byte ptr temp	; get COMx (1-4)
	mov	flags.comflg,al		; remember port ident
	cmp	al,'1'			; Bios?
	jb	coms2a			; b = no, hardware
	sub	al,'0'			; remove ascii bias for portinfo
coms2a:	dec	al
	xor	ah,ah			; count ports from 0
	push	bx			; set port structure
	mov	bx,type prtinfo		; size of each portinfo structure
	mul	bl			; times port number
	pop	bx			; restore register
	add	ax,offset port1		; plus start of COM1
	mov	portval,ax		; points to our current port struct
	cmp	flags.comflg,'1'	; Bios path?
	jb	coms4			; b = no, check hardware
	add	ax,offset portb1-offset port1 ; correct to use Bios ports
	mov	portval,ax
	mov	dl,flags.comflg
	sub	dl,'1'			; port, internal from 0
	xor	dh,dh			; clear for COMTCP in OS2
	mov	ah,3			; check port status, std Bios calls
	int	rs232			; Bios call
	and	al,80h			; get CD bit
	mov	cardet,al		; preserve as global
	clc
	ret

coms4: 	cmp	portin,-1		; serial port touched yet?
	jne	coms4a			; ne = yes, else avoid init looping
	mov	portin,0		; say serial port is being touched
coms4a:	push	es
	mov	ax,40h		; look at RS232_base [bx] in Bios area 40:00h
	mov	es,ax
	mov	bx,temp			; get desired port number 1..4
	xor	bh,bh
	dec	bl			; count com1 as bl = 0, etc
	shl	bx,1			; make bx a word index
	mov	ax,es:[bx]		; get modem base address into ax
	pop	es
	push	bx			; save this index
	or	ax,ax			; is address zero?
	jnz	comsc			; nz = no, have port address
	mov	ah,prstr
	mov	dx,offset badprt	; tell them what we are doing
	int	dos
	mov	ax,defcom[bx]		; get default COMn port address
	push	ax
	mov	cx,16			; base 16
	call	valout			; show port
	pop	ax
comsc:					; hardware tests
	mov	modem.mddat,ax	; set base address (also data address) 03f8h
	add	ax,2
	mov	modem.mdiir,ax		; interrupt identification reg 03fah
	inc	ax			; increment to command port 03fbh
	mov	modem.mdcom,ax		; set line control register address
	add	ax,2			; increment to status port 03fdh
	mov	modem.mdstat,ax		; set line-status port address
	call	chkport			; get type of UART support
	pop	bx			; recover port index
	jc	comsnu			; c = not a real 8250 class UART
	mov	ax,40h
	push	es
	mov	es,ax
	mov	ax,modem.mddat		; get COMn port address
	mov	es:[bx],ax		; force into seg 40h
	pop	es
	call	chkint			; find IRQ for the port
	jnc	comsc1			; nc = found, else error condition
	ret
comsc1:	call	getbaud			; update current baud info for port
	clc
	ret				; success

					; no UART
comsnu:	mov 	ah,prstr		; tell user about Bios pathway
	mov	dx,offset biosmsg
	int	dos
	mov	dl,byte ptr temp	; selected hardware port
	add	dl,'0'			; map to Bios
	mov	flags.comflg,dl
	mov	ah,conout		; say port number
	int	dos
	stc				; say error
	ret
ifndef	no_network
                                        ; Opennet Network support (FGR)
comso:	mov	inettyp,'O'		; remember OpenNet type network
	jmp	short comso2		; do generic network code
  					; NetBios Network support
comsn:	mov	inettyp,'N'		; remember Netbios type network
comso2:	mov	ah,cmword		; get a word (remote node name)
	mov	bx,offset decbuf	; work buffer
	mov	word ptr decbuf,0	; insert terminator
	mov	dx,offset nethlp	; help message
	call	comnd			; get the name, ignore errors
	mov	newnambuf,al		; save number of chars entered
	mov	ah,cmeol
	call	comnd			; get a confirm
	jc	comsn2			; c = failure
	; Enter here from EBIOS when EBIOS.COM is not installed. Use 'E'
	; and nettype subident of abios.
comsn3:	call	serrst			; reset serial port
	cmp	newnambuf,0		; any name given?
	je	comsn1			; e = no, use current name
	mov	si,offset decbuf
	mov	di,offset nambuf	; copy to here
	call	strcpy
comsn1:	call	chknet			; start network usage
	jc	comsn2			; c = failed
	cmp	pcnet,0			; is network alive (non-zero)?
	jne	comsn4			; ne = yes
comsn2:	stc
	ret				; failure

comsn4:	mov	portval,offset port_nb 	; set Network port structure address
	mov	port_nb.portrdy,1	; say the comms port is ready
	mov	al,inettyp		; FGR - get saved network type
	mov	flags.comflg,al		; set the Netbios port flag
	clc				; return success
	ret				; End NetBios

					; Ungermann-Bass terminal port [ohl +]
comsub:	push	bx			; save net type U or W
	mov     ah,cmeol
        call    comnd                   ; get a confirm
	jc	comsub0			; c = failure
	call    serrst			; reset serial port
        call    chkub                   ; check UB network presence
	pop	bx			; recover net type U or W
	jnc	comsub1			; nc = present
comsub0:ret				; return failure

comsub1:mov     portval,offset port_ub	; set Network port data structure addr
	mov	port_ub.portrdy,1	; say the comms port is ready
        mov     flags.comflg,bl		; set the comm port flag
	mov     pcnet,2                 ; network is present and active
        clc				; return success
        ret				; End Ungermann Bass / Novell NASI

comsmedlat:				; Meridian Superlat
	mov	latkind,MTC_LAT		; say Meridian
	jmp	short comsd1
					; TES_LAT
comsteslat:
	mov	latkind,TES_LAT		; say TES over LAT (vs DECnet)
	jmp	short comsd1		; common code
					; DECnet
comsd:	mov	latkind,DEC_LAT		; DECnet over LAT or CTERM

comsd1:	mov	ah,cmword		; get a word (remote node name)
	mov	bx,offset decbuf	; work buffer
	mov	word ptr decbuf,0	; insert terminator
	mov	dx,offset dnethlp	; help message
	call	comnd			; get the name
	mov	temp,ax			; save number of chars entered
	mov	ah,cmword		; get optional LAT service name
	mov	bx,offset decbuf+80	; work near end of this buffer
	mov	word ptr decbuf+80,0	; insert terminator
	mov	dx,offset nethlp2	; help message
	mov	comand.cmblen,16	; length of buffer (password = 16 chr)
	call	comnd			; get the name, ignore if absent
	mov	decbuf+79,al		; store byte count in name here
	mov	comand.cmblen,0		; length of buffer back to normal
	mov	ah,cmeol
	call	comnd			; get a confirm
	jnc	comsd3
	ret				; did not get a confirm
comsd3:	call	serrst			; close serial port now
	cmp	temp,0			; any node name?
	je	comsd8			; e = no, assume preestablished
 	cmp	decbuf,'*'		; just show LAT names?
	jne	comsd4			; ne = no
	call	far ptr chkdec		; see if network is available
	jc	comsd3a			; c = no, no net available
	and	nettype,not decnet	; remove CTERM indicator
	test	nettype,declat		; LAT type present?
	jz	comsd3a			; z = no
	call	latlst			; show LAT names
	and	nettype,not declat	; remove this indicator
	clc				; success but do not make connection
	ret

comsd3a:cmp	latkind,DEC_LAT		; doing DEC_LAT?
	je	comsd3b			; e = yes, DECnet
	mov	latkind,DEC_LAT		; not this method of TES
	jmp	comstes1		; try older TES method
comsd3b:mov	ah,prstr
	mov	dx,offset nonetmsg	; say net is not available
	int	dos
	clc
	ret
					; put name in uppercase, strip '::'
comsd4:	mov	si,offset decbuf	; the node name, make upper case
	mov	cx,temp			; length of node name
	add	si,cx			; and add '::' if absent
	push	ds
	pop	es
	cmp	byte ptr [si-1],':'	; ended on colon?
	jne	comsd5			; ne = no
	dec	cx			; remove it
	cmp	byte ptr [si-2],':'	; first colon present?
	jne	comsd5			; e = yes
	dec	cx			; remove it
comsd5:	mov	si,offset decbuf	; uppercase and copy name
	mov	di,offset latservice	; to this structure
	jcxz	comsd7a			; z = empty name
	cld
comsd6:	lodsb				; si = new node name
	cmp	al,'a'			; in lower case?
	jb	comsd7			; b = no
	cmp	al,'z'			; in lower case?
	ja	comsd7			; a = no
	and	al,not 20h		; convert to upper case
comsd7:	stosb
	loop	comsd6
comsd7a:mov	byte ptr [di],0		; terminate latservice name
	mov	si,offset decbuf+80	; LAT password
	mov	di,offset latpwd	; where it will reside
	mov	byte ptr [di],0		; clear password now
	call	strcpy			; copy it, asciiz
	mov	cl,decbuf+79		; length of name
	xor	ch,ch
	add	di,cx			; point to trailer
	sub	cx,16			; max chars in password
	jle	comsd8			; le = filled now, or no password
	mov	al,' '			; make it space filled
	push	ds
	pop	es
	rep	stosb			; fill in spaces
comsd8:	call	far ptr chkdec		; see if network is available
	jc	comsd3a			; c = no

	mov	ah,prstr
	test	nettype,decnet		; starting CTERM?
	jz	comsd9a			; z = no
	mov	dx,offset decmsg4	; assume CTERM
	int	dos
comsd9a:test	nettype,declat		; LAT too?
	jz	comsd9b			; z = no
	cmp	latkind,DEC_LAT		; DEC_LAT?
	jne	comsd9b			; ne = no, don't say LAT on screen
	mov	dx,offset decmsg5	; say LAT connection is ready
	int	dos
comsd9b:cmp	pcnet,2			; session active?
	jb	comsd10			; b = no, start a new one
	call	chknew			; session exists, Resume or start new?
	jc	comsd11			; c = resume
	call	decclose		; close current session
comsd10:mov     portval,offset port_dec ; set Network port data structure addr
	mov	al,'D'			; assume DECnet
	cmp	latkind,DEC_LAT		; DEC_LAT?
	je	comsd10b		; e = yes
	mov	al,'I'			; TES_LAT
comsd10a:cmp	latkind,MTC_LAT		; Meridian LAT?
	jne	comsd10b		; ne = no
	mov	al,'M'			; Meridian SuperLAT
comsd10b:mov	flags.comflg,al		; set the comm port flag
comsd11:clc
	ret				; end of DECnet


comsbapi:mov	ah,bapihere		; 3Com BAPI presence check
	xor	al,al
	mov	bx,0aaaah		; undocumented magic
	int	bapiint
	cmp	ax,0af01h		; signature
	jne	comsbap1		; ne = not present
	call	serrst			; close current port
	mov	ah,bapieecm		; disable Enter Command Mode char
	xor	al,al
	int	bapiint
	mov	portval,offset port_ub	; set Network port data structure addr
	mov	port_ub.portrdy,1	; say the comms port is ready
	or	nettype,bapi		; indentify network type
        mov     flags.comflg,'C'	; set the comm port flag
	mov     pcnet,2			; network is present and active
	clc				; success
	ret
comsbap1:mov	ah,prstr
	mov	dx,offset nonetmsg	; say no network
	int	dos
comsbap3:stc				; say failure
	ret				; end 3Com BAPI

comse:	mov	dx,offset ebiostab	; table of EBIOS ports
	xor	bx,bx
	mov	ah,cmkey
	call	comnd
	jnc	comse1			; nc = success
			; failure is ok, fails for GETBAUD etc calling comstrt
	mov	bx,ebport		; use current port
	inc	bx			; here count from 1
comse1:	push	bx
	mov	ah,cmword		; get a word (remote node name)
	mov	bx,offset decbuf	; work buffer
	mov	word ptr decbuf,0	; insert terminator
	mov	dx,offset ebhlp		; help message
	call	comnd			; get the name
	mov	ah,cmeol
	call	comnd			; get a confirm
	pop	bx
	jnc	comse7
	ret				; c = failure

comse7:	dec	bx			; count from 0
	mov	ebport,bx		; port number 0..3
	call	chkebios		; EBIOS presence check
	jnc	comse7a			; nc = success
	mov	inettyp,'E'		; try NetBios directly (ABIOS)
	mov	al,decbuf		; indicator of new host name
	mov	newnambuf,al		; set for NetBios routine
	or	nettype,acsi		; say doing special subset of NetBios
	jmp	comsn3			; setup NetBios connection

comse7a:push	es
	mov	bx,ds
	mov	es,bx
	mov	bx,offset ebcoms	; es:bx to ebcoms address
	mov	dx,ebport		; port number
	mov	cx,51			; number of bytes in ebcoms
	mov	ah,ebquery		; get redirection table info
	int	rs232
	mov	ebcoms,0		; query puts ebport in LANA, clear it
	cmp	decbuf,0		; any new name given?
	je	comse4			; e = no, presume name exists in EBIOS
	mov	si,offset decbuf	; user input
	mov	di,offset ebcoms+2	; where to store it
	mov	cx,16			; 16 char NetBios name
	cld
comse2:	lodsb				; get a new char
	or	al,al			; null terminator?
	jnz	comse3			; nz = no, use it
	mov	al,' '			; replace with space
	rep	stosb			; do remaining spots
	jmp	short comse3b		; carry on when done
comse3:	stosb				; store it
	loop	comse2

comse3b:call	setnbname		; setup local Netbios name
	jc	comse4			; c = failed
	mov	si,ds
	mov	es,si
	cld
	mov	ebcoms+2+16,0		; no Listen required, just a Call
	mov	cx,8
	mov	si,offset deflname	; our Netbios name
	mov	di,offset ebcoms+2+16+16
	rep	movsw
comse4:	mov	bx,offset ebcoms	; es:bx to ebcoms structure
	mov	ebcoms+1,80h		; force a network connection
	mov	ah,ebredir		; do redirection
	xor	al,al
	mov	dx,ebport
	int	rs232
	pop	es
	or	ax,ax			; status
	jz	comse5			; z is success

	push	ax
	mov	ah,prstr
	mov	dx,offset ebmsg3	; cannot open network
	int	dos
	pop	ax
	xchg	ah,al
	xor	ah,ah
	call	decout			; show error value
	stc
	ret
comse5:	cmp	ebcoms+2,' '		; do we have a name?
	ja	comse6			; a = yes
	mov	ah,prstr
	mov	dx,offset ebmsg2	; say bad command
	int	dos
	stc				; fail
	ret
comse6:	call	serrst			; reset previous port
	mov	bx,offset portb1	; use Bios data structure
	mov	ax,type prtinfo		; portinfo item size
	mov	cx,ebport		; actual port (0..3)
	mul	cl			; times port
	add	bx,ax			; new portb<n> offset
	mov	portval,bx
	mov	[bx].portrdy,1		; say the comms port is ready
	mov	[bx].sndproc,offset ebisnd ; send processor
	mov	[bx].rcvproc,offset ebircv ; receive processor
	mov	[bx].cloproc,offset ebiclose ; close processor
	or	nettype,ebios		; indentify network type
	mov	flags.comflg,'E'	; say EBIOS
	mov	pcnet,1
	clc				; success
	ret
comsex:	mov	dx,offset nonetmsg	; say network is not available
	mov	ah,prstr
	int	dos
comsex1:stc				; failure
	ret

comstelapi:				; Novell TELAPI
	mov	ah,cmword		; get a word (remote node name)
	mov	bx,offset decbuf	; work buffer
	mov	word ptr decbuf,0	; insert terminator
	mov	dx,offset telhlp	; help message
	call	comnd			; get the name
	jc	comstel9
	mov	bx,offset decbuf+80+2	; user text goes here
	mov	dx,offset telhlp2
	mov	ah,cmword		; get optional Telnet port
	call	comnd
	jc	comstel9
	mov	word ptr decbuf+80,ax	; store string length here
	mov	ah,cmeol
	call	comnd			; get a confirm
	jnc	comstel1		; nc = ok so far
comstel9:ret				; did not get a confirm
comstel1:cmp	decbuf,0		; got new address?
	jne	comstel2		; ne = yes
	cmp	word ptr internet,0	; have we a previous address?
	jne	comstel6		; ne = yes, use it instead
	jmp	short comstel5		; no address, say illegal
comstel2:
	mov	domath_ptr,offset decbuf+80+2 ; port number string
	mov	ax,word ptr decbuf+80	; length of string
	mov	domath_cnt,ax
	call	domath			; convert to number in ax
	jc	comstel11		; c = nothing convertable
	cmp	ax,25			; verboten?
	jne	comstel12		; ne = no
comstel11:mov	ax,23			; use default
comstel12:mov	telport,ax		; port number
	cmp	portin,0		; inited port yet?
	jl	comstel8		; l = no
	test	nettype,telapi		; already doing TELAPI?
	jz	comstel7		; z = no
	call	chknew			; ask Resume or New
	jc	comstel6		; c = Resume
comstel7:call	telapiclose		; close that connection
comstel8:xor	bx,bx			; convert Internet address to binary
	xor	dx,dx			; Internet field in dl, as a temp
	mov	word ptr internet,dx	; clear Internet address
	mov	word ptr internet+2,dx
	mov	si,offset decbuf	; fresh text
	cld

comstel3:lodsb				; get ascii digit
	cmp	al,'.'			; separator?
	jne	comstel4		; ne = no
	inc	bx			; next field
	cmp	bx,3			; beyond last field
	ja	comstel5		; a = yes, error
	jmp	short comstel3
comstel4:or	al,al			; end of information?
	jz	comstel6		; z = yes
	sub	al,'0'			; strip ascii bias
	cmp	al,9			; in digits?
	ja	comstel5		; a = no
	mov	dl,internet[bx]		; current field
	xor	dh,dh
	shl	dx,1			; times two
	push	dx			; save
	shl	dx,1			; times four
	shl	dx,1			; times eight
	pop	cx			; recover times two
	add	dx,cx			; plus two = times ten
	add	al,dl			; plus current digit
	mov	internet[bx],al		; save value
	jmp	short comstel3		; next character

comstel5:mov	ah,prstr		; say bad address construction
	mov	dx,offset telmsg1
	int	dos
	mov	dx,offset decbuf	; show address
	call	prtasz
	stc
	ret
comstel6:call	serrst			; end previous async session
	mov	portval,offset port_ub	; set Network port data structure addr
	mov	bx,portval
	mov	[bx].cloproc,offset telapiclose
	or	nettype,telapi		; indentify network type
        mov     flags.comflg,'T'	; set the comm port flag
	clc
	ret

comstes1:mov	cx,0ffffh		; old TES presence check
	mov	ah,tesinstal		; installation/status check
	call	tes_service
	jc	comstes2		; c = error of some kind
	cmp	ax,'TE'			; signature
	jne	comstes2		; ne = not present
	cmp	cx,0ffffh		; should change too
	jne	comstes3		; ne = present
comstes2:mov	ah,prstr
	mov	dx,offset nonetmsg	; say no network
	int	dos
	stc				; say failure
	ret
comstes3:mov	tesport,dx		; remember TES intercepted port
	call	serrst			; close current port
	mov	portval,offset port_tes ; set Network port data structure addr
	or	nettype,tes		; indentify network type
        mov     flags.comflg,'I'	; set the comm port flag
	mov	latkind,DEC_LAT		; not LAT kind
	cmp	decbuf,'*'		; was show-all entered?
	jne	comstes4		; ne = no
	jmp	teshosts		; show known TES hosts
comstes4:mov	ax,temp			; length of entered name
	or	al,tesname		; plus preexisting name, if any
	or	ax,ax			; anything present?
	jz	comstes9		; z = no name, find existing session
	cmp	decbuf,0		; anything to copy?
	je	comstes5		; e = no, use existing name
	call	tesclose		; close existing connection
	or	nettype,tes		; indentify network type
	mov	si,offset decbuf
	mov	di,offset tesname
	call	strcpy			; copy node name
comstes5:clc
	ret

comstes9:mov	tesses,1		; search for an active/held session
comstes10:call	tesstate		; get state of that session to AH
	test	ah,2			; active?
	jnz	comstes12		; nz = yes, use it
	inc	tesses			; next session
	cmp	tesses,9		; done all?
	jbe	comstes10		; be = no
	mov	tesses,1		; try for a held session
comstes11:call	tesstate		; get state of that session to AH
	test	ah,1			; on hold?
	jnz	comstes12		; nz = yes, use it
	inc	tesses			; next session
	cmp	tesses,9		; done all?
	jbe	comstes11		; be = no
	mov	tesses,0		; say no session
	mov	ah,prstr
	mov	dx,offset tesnhost	; give directions
	int	dos
	call	teshosts		; show known hosts
comstes12:ret

					; TCP/IP Telnet
comstn:
ifndef	no_tcp
	mov	ah,cmword		; get a word (remote node name)
	mov	comand.cmblen,60	; set 60 byte limit plus null
	mov	bx,offset decbuf+1	; work buffer, 1st byte = count
	mov	word ptr decbuf,0	; insert terminator
	mov	word ptr decbuf+80,0	; byte count of args
	mov	dx,offset tcphlp	; help message
	call	comnd			; get the name
	jc	comstnx
	or	al,al			; anything?
	jz	comstn1			; z = no
	mov	decbuf,al		; store byte count
	mov	ah,cmword		; get optional Port number
	mov	comand.cmblen,7		; set 7 byte limit plus null
	mov	bx,offset decbuf+81	; far from real node names
	mov	word ptr decbuf+80,0	; byte count of args, arg
	mov	dx,offset tcpporthlp
	call	comnd
	jc	comstnx
	mov	decbuf+80,al		; store arg byte count
	mov	bx,offset decbuf+82	; get optional NEW or RESUME
	add	bx,ax			; plus byte count of above
	mov	word ptr [bx],0		; clear count and inital byte
	inc	bx			; goes into decbuf[84]
	push	bx
	mov	ah,cmword		; get optional NEW/RESUME
	mov	comand.cmblen,7		; set 7 byte limit plus null
	mov	dx,offset tcpnewhlp
	call	comnd
	pop	bx
	jc	comstnx
	mov	[bx-1],al		; store arg byte count

comstn1:mov	ah,cmeol
	call	comnd			; get a confirm
	jnc	comstn2			; nc = ok so far
comstnx:mov	kstatus,ksgen		; global status for unsuccess
	ret				; did not get a confirm

comstn2:call	serrst			; close current comms port
	call	sesmgr			; SESSION MANAGER
	jnc	comstn3			; nc = start a session
	mov	kstatus,ksgen		; global status for unsuccess
	ret				; cannot allocate a session, fail
comstn3: mov	flags.comflg,'t'	; what we want, may not have yet
	mov	bx,offset port_tn	; set Network port data structure addr
	mov	[bx].floflg,0		; flow control kind, (none)
	mov	[bx].flowc,0		; flow control characters (none)
	mov 	portval,bx
        mov     nsbrk,1                 ; network BREAK supported
	clc
else
	stc
endif	; no_tcp
	ret
					; Beame & Whiteside TCP/IP
comsbw:	mov	ah,cmword		; get a word (remote node name)
	mov	bx,offset decbuf	; work buffer
	mov	decbuf+80+1,0
	mov	dx,offset telhlp	; help message
	call	comnd			; get the name
	jc	comsbw9			; c = failure, get eol
	mov	ah,cmword		; get optional port number
	mov	bx,offset decbuf+80+2	; storage spot
	mov	word ptr decbuf+80,0	; length of string
	mov	dx,offset telhlp2	; help for optional port
	mov	comand.cmcr,1		; bare CR's allowed
	call	comnd
	mov	word ptr decbuf+80,ax	; string length
comsbw9:mov	ah,cmeol
	call	comnd			; get a confirm
	jnc	comsbw1			; nc = ok so far
	mov	kstatus,ksgen		; global status for unsuccess
	ret				; did not get a confirm
comsbw1:cmp	decbuf,0		; got new address?
	jne	comsbw2			; ne = yes
	cmp	word ptr internet,0	; have we a previous address?
	je	comsbw5			; e = no address, say illegal
	jmp	comsbw6

comsbw2:mov	domath_ptr,offset decbuf+80+2 ; port string
	mov	ax,word ptr decbuf+80	; length
	mov	domath_cnt,ax
	call	domath			; convert to number in ax
	jc	comsbw2b		; c = nothing convertable
	cmp	ax,25			; verboten?
	jne	comsbw2c		; ne = no
comsbw2b:mov	ax,23			; use default
comsbw2c:mov	telport,ax		; port number

	cmp	portin,0		; inited port yet?
	jl	comsbw8			; l = no
	test	nettype,bwtcp		; [JRS] already doing BWTCP?
	jz	comsbw7			; [JRS] z = no
	call	chknew			; ask Resume or New
	jnc	comsbw7			; nc = New
	jmp	comsbw6
comsbw7:call	bwclose			; close current connection
comsbw8:xor	bx,bx			; convert Internet address to binary
	xor	dx,dx			; Internet field in dx, as a temp
	mov	word ptr internet,dx	; clear Internet address
	mov	word ptr internet+2,dx
	mov	si,offset decbuf	; fresh text
	cld
	cmp	byte ptr [si],'*'	; [JRS] telnet server mode?
	jne	comsbw3			; [JRS] ne = no, process IP address
	mov	word ptr internet,-1	; [JRS] bogus IP for server mode
	mov	word ptr internet+2,-1	; [JRS] bogus IP for server mode

comsbw6:call	serrst			; end previous async session
	push	bx
	mov	bx,offset port_tn
	mov	portval,bx
	mov	[bx].sndproc,offset bwsend ; [JRS] BW send routine
	mov	[bx].rcvproc,offset bwrecv ; [JRS] BW Receive routine
	mov	[bx].cloproc,offset bwclose ; [JRS] BW Close routine
	pop	bx
	or	nettype,bwtcp		; [JRS] set it to BW-TCP
        mov     flags.comflg,'b'	; [JRS] set the comm port flag
	clc
	ret

comsbw3:lodsb				; get ascii digit
	cmp	al,'.'			; separator?
	jne	comsbw4			; ne = no
	inc	bx			; next field
	cmp	bx,3			; beyond last field
	ja	comsbw5			; a = yes, error
	jmp	short comsbw3
comsbw4:or	al,al			; end of information?
	jz	comsbw6			; z = yes
	sub	al,'0'			; strip ascii bias
	cmp	al,9			; in digits?
	ja	comsbw5			; a = no
	mov	dl,internet[bx]		; current field
	xor	dh,dh
	shl	dx,1			; times two
	push	dx			; save
	shl	dx,1			; times four
	shl	dx,1			; times eight
	pop	cx			; recover times two
	add	dx,cx			; plus two = times ten
	add	al,dl			; plus current digit
	mov	internet[bx],al		; save value
	jmp	short comsbw3		; next character

comsbw5:mov	ah,prstr		; say bad address construction
	mov	dx,offset telmsg1
	int	dos
	mov	dx,offset decbuf	; show address
	call	prtasz
	stc
	ret
endif	; no_network
					; Fossil
comsf:	mov	ah,cmword		; get a word (remote node name)
	mov	bx,offset decbuf	; work buffer
	mov	word ptr decbuf,0	; insert terminator
	mov	dx,offset fossilhlp	; help message
	call	comnd			; get the port, optional
	push	ax			; string length
	mov	ah,cmeol
	call	comnd			; get a confirm
	pop	ax
	jnc	comsf2			; nc = ok so far
comsf1:	mov	kstatus,ksgen		; global status for unsuccess
	ret				; did not get a confirm
comsf2:	mov	domath_ptr,offset decbuf
	mov	domath_cnt,ax
	call	domath			; convert to number in ax
	jc	comsf4			; c = failure
	cmp	ax,99			; largest acceptable value
	ja	comsf4			; a = failure
	dec	ax			; count internally from 0 as F1
	js	comsf4			; sign = failure
	mov	fossil_port,ax		; Fossil port (Fossil1 is value 0)
	call	serrst			; end previous async session
	mov     flags.comflg,'F'	; set the comm port flag
	mov	portval,offset portb1
	mov	bx,portval
	mov	[bx].sndproc,offset fossnd
	mov	[bx].rcvproc,offset fosrcv
	mov	portin,0		; say port is selected
	clc
	ret
comsf4:	stc
	ret
COMS	ENDP

ifndef	no_network
teshosts proc	near			; TES, show list of hosts
	mov	ah,prstr
	mov	dx,offset tesnlist	; show list of hosts
	int	dos
	push	es
	push	si
	mov	ah,tesgets		; get TES known servers
	call	tes_service		; cx gets qty
	mov	dx,offset decbuf	; work buffer
	mov	word ptr decbuf,'  '	; item spacing
	xor	di,di			; line length counter
	or	cx,cx			; any servers?
	jnz	teshost1		; nz = some servers
	inc	cx			; say one for loop
	push	cx
	mov	word ptr decbuf+2,'ON'	; prefill with NONE
	mov	word ptr decbuf+4,'EN'
	mov	decbuf+6,0		; asciiz
	mov	cx,6			; length of "  NONE"
	jmp	short teshost3		; show NONE
teshost1:push	cx			; count of servers
	push	si			; save master list pointer
	push	di
	mov	si,es:[si]		; get offset of first name
	mov	di,dx			; decbuf
	add	di,2			; move into decbuf+2
teshost2:mov	al,es:[si]		; get name char
	inc	si
	mov	[di],al			; store name char
	inc	di
	or	al,al			; at end?
	jnz	teshost2		; nz = no
	pop	di
	pop	si			; master list of offsets
	add	si,2			; next item in list
	call	strlen			; get length of name w/spaces
	add	di,cx			; length of display line with name
	cmp	di,60			; time to break line?
	jbe	teshost3		; be = no
	push	dx
	mov	ah,prstr		; break the screen line
	mov	dx,offset crlf
	int	dos
	pop	dx
	xor	di,di			; say line is empty
teshost3:add	di,cx			; current line length
	call	prtasz			; show asciiz text at ds:dx
	pop	cx
	loop	teshost1		; do all entries
	pop	si
	pop	es
	ret
teshosts endp

; Perform TES function given in AH, but tell cmd interpreter to not prompt.
tes_service     proc    near
        push    ax
        push    si
        push    es
        mov     ax,ds
        mov     es,ax
	mov	si,offset tesquiet	; cmd to say no prompting
	xor	al,al			; no visible response please
	mov	ah,tesexec
        int     rs232
        pop     es
        pop     si
        pop     ax
	push	ds			; prevent corruption by TES
        int     rs232			; do the main request
	pop	ds
        ret
tes_service     endp

; TES - start or resume a TES connection
tesstrt	proc	near
	cmp	tesses,0		; session yet?
	jne	tesstr2			; ne = yes
	cmp	tesname,0		; have a node name?
	jne	tesstr1			; ne = yes
	jmp	tesstr4			; find an existing connection, if any

tesstr1:push	si
	mov	si,offset tesname	; node name
	mov	ah,tesnews		; make a new session
	call	tes_service
	pop	si
 	jmp	short tesstr4		; double check on transistions

					; have a session, live or held
tesstr2:call	tesstate		; get session status
	test	ah,2			; active or being made so?
	jnz	tesstr3			; nz = yes, connect to it
	test	ah,1			; session on hold or being made so?
	jz	tesstr1			; z = no, make a new one
	mov	ah,tesresume		; resume a session
	mov	al,tesses		; the session number
	call	tes_service
	shl	ah,1			; get status into carry bit
	jc	tesstr4			; c = problem, try to recover

tesstr3:cmp	tesname,0		; have name yet?
	je	tesstr4			; e = no, get it now
	mov	pcnet,2			; have an active session
	mov	port_tes.portrdy,1	; say port is ready
	clc
	ret

tesstr4:push	si			; find an active session number
	push	es
	mov	temp,0			; retry counter
	mov	tesses,1		; session number
tesstr5:mov	ah,teslist		; get TES session pointers
	call	tes_service		; CX gets quantity of ACTIVE sessions
tesstr6:mov	al,es:[si]		; get session status
	cmp	al,82h			; making a session now?
	je	tesstr7			; e = yes, good enough
	test	al,80h			; in transitional status?
	jz	tesstr6b		; z = no
	mov	ah,100
	call	pcwait			; wait 100 ms
	inc	temp
	cmp	temp,10
	ja	tesstr6a		; a = too many retries, quit
	jmp	short tesstr5		; nz = yes, go around again
tesstr6b:mov	temp,0			; clear retry counter
	test	al,2			; 0=inactive, 1=on hold, 2=active?
	jnz	tesstr7			; nz = active
	add	si,3			; skip status byte, name offset
	inc	tesses			; bump session number
	cmp	tesses,9		; done all?
	jbe	tesstr6			; be = no
tesstr6a:mov	tesses,0		; no active session
	mov	port_tes.portrdy,0	; say the comms port is not ready
	mov     pcnet,1			; network is present and inactive
	stc				; signal failure
	jmp	short tesstr8
					; set port ready, get host name
tesstr7:mov	port_tes.portrdy,1	; say the comms port is ready
	mov     pcnet,2			; network is present and active
	mov	di,offset tesname	; readback asciiz name
	mov	byte ptr [di],0		; clear the name field
	mov	si,es:[si+1]		; get name ptr offset
	or	si,si			; check for null pointer
	jz	tesstr6a		; z = no name, dead session
	mov	cx,49			; limit to 48 chars plus null
tesstr7a:mov	al,es:[si]		; get a char
	inc	si
	mov	[di],al			; store
	inc	di
	or	al,al			; null?
	jz	tesstr7b		; z = yes, stop here
	loop	tesstr7a		; keep going
tesstr7b:clc				; signal success
tesstr8:pop	es
	pop	si
	ret
tesstrt	endp

; TES. Return session status in AH for session in tesses. Destroys AX
tesstate proc	near
	push	cx
	push	si
	push	es
	mov	ah,teslist		; get session list
	call	tes_service
	mov	ah,0ffh			; set up no session status
	mov	al,tesses		; our session number, 1..9
	dec	al			; base on zero here
	mov	ah,al
	shl	ah,1
	add	al,ah
	xor	ah,ah			; times three
	add	si,ax			; point to session structure es:[si]
	mov	ah,es:[si]		; get session status byte
testat1:pop	es
	pop	si
	pop	cx
	ret
tesstate endp

; Start Novell TELAPI session. Internet address is already binary
telstrt	proc	near
	mov	dx,word ptr internet	; internet address, high part
	mov	cx,word ptr internet+2
	mov	bx,telport		; Telnet port (23 decimal)
	push	es
	push	si
	xor	si,si			; use TELAPI data structures, not ours
	mov	es,si			; es:si = Telnet state record, theirs
	mov	di,offset telhostid	; two byte host identifier in ds:di
	mov	ah,telopen		; open the connection
	int	rs232
	mov	telses,ax		; save TELAPI session number
	pop	si
	pop	es
	or	ax,ax			; get status returned in AX
	jns	telstr1			; ns = success
	cmp	ax,telinuse		; socket is already connected? (-56)
 	jne	telstr2			; ne = no, else attach to it
telstr1:mov	port_ub.portrdy,1	; say the comms port is ready
	mov     pcnet,2			; network is present and active
	or	nettype,telapi
	clc
	ret
					; failure message display section
telstr2:mov	dx,offset telmsg51	; network unreachable
	cmp	ax,telunreac		; correct?
	je	telstr3			; e = yes
	mov	dx,offset telmsg56	; socket in use
	cmp	ax,telinuse
	je	telstr3
	mov	dx,offset telmsg60	; timeout on connection attempt
	cmp	ax,teltmo
	je	telstr3
	mov	dx,offset telmsg61	; connection refused
	cmp	ax,telrefuse
	je	telstr3
	mov	dx,offset telmsg64	; host is down
	cmp	ax,teldwnhost
	je	telstr3
	mov	dx,offset telmsg67	; unknown host
	cmp	ax,telunkhost
	je	telstr3
	mov	dx,offset telmsg301	; no more space
	cmp	ax,telfull
	je	telstr3
	push	ax			; unknown error, show error value
	mov	dx,offset telmsg2
	mov	ah,prstr
	int	dos
	pop	ax
	neg	ax			; make positive number again
	call	decout			; show error value, for now
	jmp	short telstr4
telstr3:mov	ah,prstr
	int	dos			; show reason msg
telstr4:mov	ax,3000			; show for three seconds
	call	pcwait
	mov	port_ub.portrdy,0	; say port is not ready
	and	nettype,not telapi	; clear network use bit
	stc				; fail
	ret
telstrt	endp

; Start Beame & Whiteside TCP connecton.  IP address is already binary [JRS]
bwstart	proc	near			; [JRS]
	push	bx			; [JRS]
	push	cx			; [JRS]
	push	dx			; [JRS]
	mov	bx,bwhandle		; [JRS] check the file handle
	or	bx,bx			; [JRS] non-zero is open
	jnz	bwstrt1			; [JRS] nz = yes, just continue

	mov	ax,3d42h		; [JRS] open file shared read/write
	mov	dx,offset bwtcpnam	; [JRS] "TCP-IP10"
	int	dos
	jc	bwstrt2			; c = failed
	mov	bwhandle,ax		; [JRS] save file handle
	mov	bx,ax			; [JRS] copy handle
	mov	ax,4401h		; [JRS] io/ctl - set dev info
	xor	cx,cx			; [JRS]
	mov	dx,60h			; [JRS] data is raw
	int	dos			; [JRS]
	jc	bwstrt2			; c = failed
	mov	xmtbuf,0		; [JRS] set up port bind address
	push	es
	mov	ax,40h			; Bios work area
	mov	es,ax
	mov	ax,es:[6ch]		; low word of Bios tod tics
	pop	es
	mov	word ptr xmtbuf+1,ax	; local port
	mov	ax,4403h		; [JRS] write to device
	mov	bx,bwhandle		; [JRS] device handle
	mov	cx,3			; [JRS] length of data
	mov	dx,offset xmtbuf	; [JRS] data buffer
	int	dos			; [JRS]
	jc	bwstrt2			; c = failed

	mov	xmtbuf,1		; [JRS] set up IP bind address
	mov	dx,word ptr internet	; [JRS] internet address, high part
	mov	cx,word ptr internet+2	; [JRS]
	cmp	dx,-1			; [JRS] check for server addr -1
	jz	bwaccept		; [JRS] z = -1, do accept processing

	mov	word ptr xmtbuf+1,dx	; [JRS] store address in buffer
	mov	word ptr xmtbuf+3,cx	; [JRS]
	mov	ax,telport
	mov	word ptr xmtbuf+5,ax	; telnet port (23)
	mov	ax,4403h		; [JRS] write to device
	mov	bx,bwhandle		; [JRS]
	mov	cx,7			; [JRS]
	mov	dx,offset xmtbuf	; [JRS]
	int	dos			; [JRS]
	jc	bwstrt2			; c = failed

bwstrt0:mov	xmtbuf,6		; [JRS] set up for no read blocking
	mov	xmtbuf+1,1		; [JRS]	control string is \6\1
	mov	ax,4403h		; [JRS] write to device
	mov	bx,bwhandle		; [JRS]
	mov	cx,2			; [JRS]
	mov	dx,offset xmtbuf	; [JRS]
	int	dos			; [JRS]
	jc	bwstrt2			; c = failed

bwstrt1:pop	dx			; [JRS] restore registers
	pop	cx			; [JRS]
	pop	bx			; [JRS]
	mov	port_tn.portrdy,1	; [JRS] say the comms port is ready
	mov     pcnet,2			; [JRS] network is present and active
	or	nettype,bwtcp		; [JRS]
	mov	optstate,0		; init Options
	mov	sgaflg,0		; assume supresss go aheads in effect
	mov	option2,TELOPT_SGA
	mov	ah,DO
	call	bwsendiac		; say do supress go aheads
	clc
	ret
bwstrt2:call	bwclose			; [JRS] failure, close "file"
	pop	dx			; [JRS]
	pop	cx			; [JRS]
	pop	bx			; [JRS]
	stc				; c = failed
	ret

bwaccept:mov	xmtbuf,2		; [JRS] set port to accept calls
	mov	ax,4403h		; [JRS] write to device
	mov	bx,bwhandle		; [JRS]
	mov	cx,1			; [JRS]
	mov	dx,offset xmtbuf	; [JRS]
	int	dos			; [JRS]
	mov	ax,4402h		; [JRS] read from device
	mov	bx,bwhandle		; [JRS] device handle
	mov	cx,11			; [JRS] buffer length
	mov	dx,offset xmtbuf	; [JRS] buffer
	int	dos			; [JRS]
bwacpt1:cmp	xmtbuf,4		; [JRS] check response 0 < xmtbuf < 4
	jge	bwacpt2			; [JRS]	complete
	cmp	xmtbuf,0		; [JRS]
	je	bwacpt2			; [JRS]
					; [JRS] waiting for a connection
	mov	ax,4402h		; [JRS] read from device
	mov	bx,bwhandle		; [JRS]
	mov	cx,11			; [JRS]
	mov	dx,offset xmtbuf	; [JRS]
	int	dos			; [JRS]
	jmp	short bwacpt1		; [JRS] got look at response
bwacpt2:cmp	xmtbuf,0		; [JRS] check for response of zero
	je	bwstrt2			; [JRS] e=yes, fail
	jmp	bwstrt0			; [JRS] success, we have a call
bwstart	endp				; [JRS]
endif	; no_network
code	ends

code1	segment
	assume	cs:code1
ifndef	no_network
; Check for presence of DECNET. Host name is in latservice.
; Try LAT then try CTERM. Sets nettype for kind found.
; Return carry clear if success, or carry set if failure.
chkdec	proc	FAR
	cmp	pcnet,2			; net active now?
	jb	chkde2			; b = no
	cmp	lathand,0		; valid LAT handle?
	jne	chkde1			; ne = yes
	cmp	decneth,0		; valid LAT handle?
	je	chkde2			; e = invalid handle
chkde1:	clc
	ret				; return to active session

chkde2:	push	es
	and	nettype,not (declat+decnet) ; clear network type bits
	call	chklat			; check for LAT
	jc	chkde3			; c = not present
	mov	latversion,4		; assume DECnet version 4 or later
	xor	bx,bx
	mov	es,bx			; clear ES:BX for text below
	mov	ax,latscbget		; try getting SCB internal to LAT
	mov	dh,0ffh
	int	latint
	jc	chkde2a			; if this kind of failure
	or	ah,ah			; success?
	jnz	chkde2a			; nz = no, use v3 SCB in Kermit
	push	es
	push	bx
	mov	ax,latscbfree		; free the SCB
	int	latint
	pop	ax			; old ES
	pop	bx
	or	ax,bx			; returned address from ES:BX, null?
	jnz	chkde4			; nz = no, LAT has internal SCBs
chkde2a:mov	latversion,3		; DECnet version 3 style LAT
	jmp	short chkde4
					; now do CTERM too
chkde3:	mov	al,decint		; CTERM interrupt 69h
	mov	ah,35h			; get vector to es:bx
	int	dos
	mov	ax,es
	or	ax,ax			; undefined interrupt?
	jz	chkde4			; z = yes
	cmp	byte ptr es:[bx],0cfh	; points at IRET?
	je	chkde4			; e = yes
	mov	ax,dpresent		; CTERM installation call
	int	decint
	cmp	al,0ffh			; CTERM installed?
	jne	chkde4			; ne = no
	or	nettype,decnet		; kind of network is CTERM
chkde4:	pop	es
	test	nettype,declat+decnet	; any DEC network found?
	jz	chkde5			; z = no
	clc				; clear means yes
	ret
chkde5:	stc				; status is no net
	ret
chkdec	endp

; Check for LAT interrupt vector, return carry clear if found else carry set.
; Sets latkind to DEC_LAT, TES_LAT or MTC_LAT.
chklat	proc	near
	push	es
	mov	al,latint		; LAT interrupt 6Ah
	mov	ah,35h			; get vector to es:bx
	int	dos
	mov	ax,es
	or	ax,ax			; undefined interrupt?
	jz	chklat1			; z = yes
	cmp	byte ptr es:[bx],0cfh	; points at IRET?
	je	chklat1			; e = yes, not installed
	cmp	word ptr es:[bx-3],'AL'	; preceeding 3 bytes spell 'LAT'?
	jne	chklat1			; ne = no, so no LAT, try CTERM
	cmp	byte ptr es:[bx-1],'T'
	jne	chklat1			; ne = no, fail
	or	nettype,declat		; kind of network is LAT
	mov	latkind,TES_LAT		; assume TES LAT
	cmp	word ptr es:[bx-6],'ET'	; Interconnections Inc "TESLAT"?
	je	chklat2			; e = yes
	mov	latkind,MTC_LAT		; Meridian
	cmp	word ptr es:[bx-6],'TM'	; Meridian "MTCLAT"?
	je	chklat2			; e = yes
	mov	latkind,DEC_LAT		; say DEC's LAT
chklat2:pop	es
	clc				; success
	ret
chklat1:pop	es
	stc				; say failure
	ret
chklat	endp

; Start DECNET link. Host name is in latservice, nettype has LAT or CTERM
; kind bits. Return carry clear if success, or carry set if failure.
decstrt	proc	FAR
	cmp	pcnet,2			; net active now?
	jb	decst2			; b = no
	cmp	lathand,0		; invalid LAT handle?
	jne	decst1			; ne = no, have a connection
	cmp	decneth,0		; invalid CTERM handle?
	je	decst2			; e = yes, start the net
decst1:	mov	port_dec.portrdy,1	; say the comms port is ready
	mov	al,'D'			; assume DECnet port flag
	cmp	latkind,DEC_LAT		; DEC_LAT?
	je	decst1b			; e = yes
	mov	al,'I'			; TES-LAT
decst1a:cmp	latkind,TES_LAT		; TES-LAT?
	je	decst1b			; e = yes
	mov	al,'M'			; Meridian SuperLAT
decst1b:mov     flags.comflg,al		; set the comm port flag
	clc
	ret				; return to active session

decst2:	push	es			; used a lot here
	call	chkdec			; get net type
	jnc	decst3			; nc = have a CTERM or LAT kind
	jmp	decst16			; c = net not found

decst3:	cmp	latservice,0		; node name present?
	jne	decst4			; ne = yes
	mov	ah,prstr
	mov	dx,offset noname	; say host name is required
	int	dos
	pop	es
	stc				; fail
	ret

decst4:	test	nettype,declat		; LAT is available?
	jnz	decst6			; nz = yes
	jmp	decst13			; z = no, try CTERM

decst6:	cmp	word ptr latscbptr+2,0	; any segment allocated now?
	jne	decst8			; ne = yes, do not malloc one here
;	cmp	tv_mode,0		; running under Windows or DV?
;	je	decst6a			; e = no, ok to try local SCB
;	jmp	decst12b		; can't use local so no LAT today
decst6a:mov	bx,870+15		; size of LAT SCB, bytes, rounded up
	mov	cl,4
	shr	bx,cl			; bytes to paragraphs
	mov	temp,bx			; save requested paragraphs
	mov	ah,alloc		; allocate memory, ax gets segment
	int	dos			; bx gets # paragraphs allocated
	jnc	decst7			; nc = success
	jmp	decst13			; fail, go try CTERM
decst7:	mov	latseg,ax
	mov	word ptr latscbptr+2,ax	; remember seg of SCB
	mov	word ptr latscbptr+10,ax ; and on the "To:" side as well
	mov	es,ax
	xor	di,di			; es:di is destination
	xor	ax,ax			; get word of zeros
	mov	word ptr latscbptr+0,ax	; remember offset (0) of SCB
	mov	word ptr latscbptr+8,ax	;  as above
	mov	cx,bx			; paragraphs obtained
	shl	cx,1
	shl	cx,1
	shl	cx,1			; words
	cld
	rep	stosw			; clear the SCB
	cmp	temp,bx			; wanted vs allocated (bx) paragraphs
	jbe	decst5			; be = enough, setup structure
	jmp	decst12			; deallocate memory and try CTERM

decst5:	and	nettype,not declat	; presume failure
	cmp	latversion,4		; version 4?
	jb	decst8			; b = no, earlier, do our own SCB
	cmp	latpwd,0		; password given?
	jne	decst8			; ne = yes, must use our SCB
	mov	ax,latscbget		; get LAT interior SCB addr to es:bx
	mov	dh,0ffh
	int	latint
	or	ah,ah			; success?
	jnz	decst5a			; nz = no
	mov	ax,es
	mov	word ptr latscbptr+6,ax	; address of SCB within LAT
	mov	word ptr latscbptr+4,bx ;  offset part
	call	decfems			; copy EMS SCB to local SCB
	jmp	short decst9		; fill in local info

decst5a:mov	ah,prstr
	mov	dx,offset decmsg6	; say can't allocate LAT SCB
	int	dos
	jmp	decst13			; try CTERM

decst8:	les	bx,latscbptr		; allocate data buffers locally
	mov	es:[bx].slottbl,slotbf1	; offset of first buffer
	mov	es:[bx].slottbl+2,slotbf2 ; offset of second buffer
	mov	es:[bx].slotqty,2	; say two buffers

decst9:	les	di,latscbptr		; set es:di to local scb
	mov	si,offset latservice	; get host name
	mov	cx,17			; 17 bytes
	cld
	rep	movsb			; insert host name
	mov	ax,latopen		; open a LAT session
	mov	di,offset latpwd	; es:di optional asciiz LAT password
	cmp	byte ptr [di],0		; any name entered?
	je	decst10			; e = no
	and	al,0fh			; open as AX = 0d0fh if with password
decst10:mov	bx,word ptr latscbptr	; open needs es:bx == SCB
	cmp	latversion,4		; LAT version 4?
	jb	decst11			; b = no, use version 2
	mov	al,1			; v4 form
	push	ax
	mov	cx,ds
	mov	word ptr es:[bx].lat_pwd+2,cx ; set the pointer segment
	mov	word ptr es:[bx].lat_pwd,di  ; address of the password buffer
	mov	dx,di
	call	strlen			; password string length to cx
	mov	es:[bx].pwd_len,cl	; length of the password
	or	cx,cx			; is there a password?
	jnz	decst10a		; nz = yes
	mov	word ptr es:[bx].lat_pwd,cx ; no, clear fields
	mov	word ptr es:[bx].lat_pwd+2,cx
	mov	byte ptr es:[bx].pwd_len,cl
decst10a:call	dec2ems			; copy local SCB to one in EMS
	pop	ax

decst11:mov	dh,0ffh
	cmp	latversion,4		; version 4?
	jb	decst11a		; b = no, earlier, use our own SCB
	les	bx,latscbptr+4		; stuff in lat
decst11a:int	latint
	or	ah,ah			; status byte
	jnz	decst12			; nz = failure, clean up, try CTERM
	mov	dh,0ffh
	mov	lathand,dx		; handle returned in dl, 0ffh in dh
	or	nettype,declat		; say LAT session is active
	jmp	decst17			; finish startup info
					; LAT startup failure
decst12:mov	ax,latseg		; stored segment of memory block
	or	ax,ax			; did we use it?
	jz	decst12a		; z = no
	mov	es,ax			; allocated segment, unneed now
	mov	ah,freemem		; free it again
	int	dos
	jmp	short decst12b		; clear pointers
decst12a:cmp	word ptr latscbptr+2,0	; in use as LAT internal perhaps?
	je	decst12b		; e = no
	les	bx,latscbptr
	mov	ax,latscbfree		; free SCB internal to LAT
	int	latint
decst12b:xor	ax,ax
	mov	latseg,ax		; say not used
	mov	lathand,ax		; invalidate the handle
	mov	word ptr latscbptr+0,ax	; clear SCB pointer
	mov	word ptr latscbptr+2,ax
	and	nettype,not declat	; fall through to try CTERM

decst13:test	nettype,decnet		; is CTERM available?
	jz	decst16			; z = no
	and	nettype,not decnet	; presume failure
	mov	ax,decseg		; scb memory segment, if non-zero
	or	ax,ax			; allocated already?
	jnz	decst14			; nz = yes, segment is in ax
	mov	ax,dgetscb		; get CTERM SCB size
	int	decint
	add	ax,15			; round up byte count
	mov	cl,4
	shr	ax,cl			; bytes to paragraphs
	mov	bx,ax
	mov	temp,ax			; save requested paragraphs
	mov	ah,alloc		; allocate memory
	int	dos			; bx gets # paragraphs allocated
	jc	decst16			; c = failure
	mov	decseg,ax		; store address of memory block
	cmp	temp,bx			; wanted vs allocated paragraphs
	jb	decst15			; b = not enough, fail

decst14:mov	bx,offset latservice	; ds:bx = node name
	mov	es,ax			; ax holds scb segment
	xor	dx,dx			; es:dx = SCB address
	mov	ax,dopen		; open session
	int	decint
	cmp	ax,0			; > 0 means session handle, else error
	jle	decst15			; le = error
	mov	decneth,ax		; store handle
	or	nettype,decnet		; network type is DECnet
	jmp	short decst17		; success
					; CTERM startup failure
decst15:push	ax			; save error number in ax
	mov	ax,decseg		; allocated memory segment
	mov	es,ax
	mov	ah,freemem		; free allocated memory segment @ES
	int	dos			; free the block
	mov	decseg,0		; clear remembered segment address
	mov	ah,prstr
	mov	dx,offset decmsg1	; cannot create session
	int	dos
	mov	dx,offset decmsg3	; DEC Error #
	int	dos
	pop	ax			; recover error number (negative)
	neg	ax
	call	decout			; error number
	mov	decneth,0		; invalidate the handle
	and	nettype,not decnet

decst16:mov	pcnet,0			; no net
	mov	port_dec.portrdy,0	; port is not ready
	pop	es
	stc				; status is error
	ret
					; LAT or CTERM success
decst17:mov	pcnet,2			; say net is present and active
	mov	al,'D'			; assume DECnet
	cmp	latkind,DEC_LAT		; DECnet?
	je	decst18			; e = yes
	mov	al,'I'			; TES-LAT
	cmp	latkind,TES_LAT		; TES_LAT?
	je	decst18			; e = yes
	mov	al,'M'
decst18:mov     flags.comflg,al		; set the comm port flag
decst19:mov	port_dec.portrdy,1	; say the comms port is ready
	mov	ax,100			; wait 100 ms for DECnet to get ready
	call	pcwait			; FAR call
	pop	es
	clc
	ret
decstrt	endp

; Copy LAT scb from local SCB to one in EMS
dec2ems	proc	near
	cmp	latversion,4		; version 4?
	jb	dec2emsx		; b = no, earlier, do our own SCB
	push	ax
	push	bx
	push	cx
	push	dx
	push	es
	mov	ax,seg latscbptr	; seg where latscbptr is located
	mov	es,ax			; to es:bx
	mov	bx,offset latscbptr
	mov	ax,latcpyems		; copy from local to EMS
	mov	dh,0ffh			; signature
	mov	cx,31			; bytes needed from LAT structure
	int	latint			; copy local LAT info to EMS version
	pop	es
	pop	dx
	pop	cx
	pop	bx
	pop	ax
dec2emsx:ret
dec2ems	endp

; Copy LAT SCB from EMS to local SCB
decfems	proc	near
	cmp	latversion,4		; version 4?
	jb	decfemsx		; b = no, earlier, do our own SCB
	push	ax
	push	bx
	push	cx
	push	dx
	push	es
	mov	ax,seg latscbptr	; seg where latscbptr is located
	mov	es,ax			; to es:bx
	mov	bx,offset latscbptr+4	;local(0),LAT(4),local(8) in latscbptr
	mov	ax,latcpyems		; copy from EMS to local
	mov	dh,0ffh			; signature
	mov	cx,31			; just enough of LAT structure
	int	latint
	pop	es
	pop	dx
	pop	cx
	pop	bx
	pop	ax
decfemsx:ret
decfems	endp
endif	; no_network
code1	ends

code	segment
	assume	cs:code
ifndef	no_network
; Display list of LAT service names. Presumes LAT presence checks have passed
latlst	proc	near
	push	es
	push	bx
	mov	ah,prstr
	mov	dx,offset dnetsrv	; header
	int	dos
	push	ds
	pop	es
	mov	si,2			; chars in line counter
latlst1:mov	bx,offset decbuf+2 	; es:bx = temp buffer for a name
	mov	word ptr [bx-2],'  '	; indent
	mov	byte ptr [bx],0		; and a null terminator
	mov	ax,latsrv		; get next LAT service name
	mov	dh,0ffh
	int	latint
	or	ah,ah			; check status
	jnz	latlst2			; nz = done (no more names)
	mov	dx,offset decbuf	; name ptr is in es:bx (our buffer)
	call	prtasz			; show asciiz name
	call	strlen			; get current length
	add	si,cx			; count chars on this line
	cmp	si,60			; enough on line already?
	jbe	latlst1			; be = no
	mov	ah,prstr		; break the screen line
	mov	dx,offset crlf
	int	dos
	mov	si,2			; reset line count
	jmp	short latlst1		; do it again
latlst2:pop	bx
	pop	es
	ret
latlst	endp
endif	; no_network

; Check which Interrupt ReQuest line the port uses. Technique: allow interrupt
; on transmitter holding register empty, test for that condition first with
; IRQ 4 and then IRQ 3. Returns with IRQ values set and carry clear if success
; or carry set if failure. [jrd]
chkint	proc	near
	call	serrst
	mov	bl,flags.comflg		; port 1..4
	dec	bl
	xor	bh,bh
	mov	al,portirq[bx]		; pre-specified IRQ, if any
	or	al,al			; IRQ specified already?
	jnz	chkint20		; nz = yes
chkint10:test	flags.comflg,1		; COM1/3?
	jz	chkint13		; z = no, COM2/4
	cmp	flags.comflg,1		; COM1?
	je	chkint10a		; e = yes, try IRQ 4
	cmp	isps2,0			; IBM PS/2 Model 50 or above?
	jne	chkint11		; ne = yes, other COM2..4 try IRQ 3
chkint10a:call	chkint5			; test for IRQ 4
	jc	chkint11		; c = failed
	ret
chkint11:call	chkint6			; else try IRQ 3
	jnc	chkint12		; nc = success
	jmp	chkint7			; fall back on defaults
chkint12:ret				; carry clear for success

chkint13:call	chkint6			; test for IRQ 3
	jc	chkint14		; c = failed
	ret
chkint14:call	chkint5			; else try IRQ 4
	jnc	chkint15		; nc = success
	jmp	chkint7			; fall back on defaults
chkint15:ret				; carry clear for success

					; IRQ specified, in AL
chkint20:mov	di,sp			; do push sp test for XT vs 286 class
	push	sp			; XT pushes sp-2, 286's push old sp
	pop	cx			; recover pushed value, clean stack
	sub	di,cx			; non-zero if < 80286, no slave 8259
	cmp	al,2			; using IRQ 2?
	jne	chkint1			; ne = no
	or	di,di			; cascaded 8259?
	jnz	chkint1			; nz = no
	add	al,7			; map IRQ 2 to IRQ 9
chkint1:cmp	al,15			; larger than legal IRQ?
	ja	chkint2			; a = yes, fail
	or	di,di			; 286 or above (cascaded 8259)?
	jz	chkint3			; z = yes
	cmp	al,7			; larger than legal for single 8259?
	jbe	chkint3			; be = no
chkint2:stc				; fail
	ret
chkint3:mov	cl,al			; IRQ 0..15
	mov	bx,1
	shl	bx,cl			; bit position of IRQ 0..15
	or	bl,bh			; copy bit to bl
	mov	modem.mddis,bl		; mask to disable IRQ
	not	bl			; 0 means enable
	mov	modem.mden,bl		; mask to enable IRQ
	and	al,7			; IRQ, lower three bits
	mov	ah,al			; make a copy
	add	ah,60h			; specific EOI control code
	mov	modem.mdmeoi,ah		; specific EOI control command
	add	al,8			; IRQ 0 starts at Int 8
	xor	ah,ah
	mov	modem.mdintv,ax		; Interrupt number
	mov	modem.mdmintc,20h	; master 8259 control address
	or	bh,bh			; on cascaded 8259?
	jz	chkint4			; z = no
	or	modem.mdmintc,80h	; slave 8259 control address (0a0h)
	add	modem.mdintv,70h-8	; Interrupt number for IRQ 8..15
chkint4:clc
	ret

					; find IRQ 4 by usage test
chkint5:mov	modem.mddis,(1 shl 4)	; IRQ 4 test. mask to disable IRQ 4
	mov	modem.mden,not (1 shl 4); mask to enable IRQ 4
	mov	modem.mdmeoi,20h	; use general in case we guess wrong
	mov	modem.mdintv,8+4	; IRQ 4 interrupt vector (0ch)
	mov	modem.mdmintc,20h	; use master 8259 here
	call	inttest
	jc	chkint5a		; c = failed
	mov	modem.mdmeoi,60h+4	; use specific EOI for IRQ4 level
	mov	bl,flags.comflg		; port 1..4
	dec	bl
	xor	bh,bh
	mov	portirq[bx],4
	clc				; this setup worked
chkint5a:ret
					; IRQ 3 test
chkint6:mov	modem.mddis,(1 shl 3)	; mask to disable IRQ 3
	mov	modem.mden,not (1 shl 3); mask to enable IRQ 3
	mov	modem.mdmeoi,20h	; use general in case we guess wrong
	mov	modem.mdintv,8+3	; IRQ 3 interrupt vector
	call	inttest
	jc	chkint6a		; c = failed
	mov	modem.mdmeoi,60h+3	; use specific EOI for IRQ3 level
	mov	bl,flags.comflg		; port 1..4
	dec	bl
	xor	bh,bh
	mov	portirq[bx],3
	clc				; this setup worked
chkint6a:ret

					; auto test did not work
chkint7:mov	modem.mdmintc,20h	; use master 8259 Int controller
	cmp	flags.comflg,1		; COM1?
	je	chkint8			; e = yes, use IRQ 4
	cmp	isps2,0			; IBM PS/2 Model 50 or above?
	jne	chkint9			; ne = yes, other COMs use IRQ 3
	cmp	flags.comflg,3		; COM2, COM3, or COM4?
	jne	short chkint9		; ne = COM2 or COM4, use IRQ 3
chkint8:mov	modem.mdmeoi,60h+4	; use specific EOI for IRQ4 level
	mov	modem.mddis,(1 shl 4)	; IRQ 4 test. mask to disable IRQ 4
	mov	modem.mden,not (1 shl 4); mask to enable IRQ 4
	mov	modem.mdintv,8+4	; IRQ 4 interrupt vector (0ch)
	mov	bl,flags.comflg		; port 1..4
	dec	bl
	xor	bh,bh
	mov	ax,4			; IRQ
	mov	portirq[bx],al
	jmp	short chkint9a		; show message

chkint9:mov	modem.mdmeoi,60h+3	; use specific EOI for IRQ 3 level
	mov	modem.mddis,(1 shl 3)	; mask to disable IRQ 3
	mov	modem.mden,not (1 shl 3); mask to enable IRQ 3
	mov	modem.mdintv,8+3	; IRQ 3 interrupt vector
	mov	bl,flags.comflg		; port 1..4
	dec	bl
	xor	bh,bh
	mov	ax,3			; IRQ
	mov	portirq[bx],al
chkint9a:push	ax
	mov	ah,prstr
	mov	dx,offset badirq	; say assuming an IRQ
	int	dos
	pop	ax
	mov	cx,10			; decimal
	call	valout			; show IRQ
	clc
	ret

inttest:call	serini			; setup port for given IRQ
	jc	inttes2			; c = failure
	mov	dx,modem.mddat
	inc	dx			; interrupt enable reg (3f9h)
	cli
	mov	intkind,0		; clear interrupt cause
	mov	al,2			; set xmtr holding reg empty interrupt
	out	dx,al
	call	delay
	mov	al,2			; set xmtr holding reg empty interrupt
	out	dx,al			; again, because first may be missed
	sti
	call	delay			; wait one millisec for interrupt
	mov	al,intkind		; interrupt kind
	push	ax
	call	serrst			; reset port
	pop	ax
	test	al,2			; check cause of interrupt, ours?
	jz	inttes2			; z = no, test failed
	clc				; this setup worked
	ret
inttes2:stc				; failure
	ret
chkint	endp

; Test presently selected serial port for having a real 8250 UART.
; Return carry clear if 8250 present,
;  else carry set and flags.comflg in ascii digits for system Bios or
;  carry set for network.
; Method is to check UART's Interrupt Identification Register for high
; five bits being zero; IBM does it this way. Assumes port structure
; has been initialized with addresses of UART.	21 Feb 1987 [jrd]
; 29 May 1987 Add double check by reading Line Status Register. [jrd]

chkport	proc	near
	cmp	flags.comflg,4		; non-UART port?
	ja	chkporx			; a = yes
	cmp	flags.comflg,0		; undefined port?
	je	chkporx			; e = yes
	push	ax
	push	dx
	mov	dx,modem.mdiir		; UART Interrupt Ident reg (3FAh/2FAh)
	in	al,dx			; read UART's IIR
	test	al,30h			; are these bits set?
	jnz	chkpor1			; nz = yes, not an 8250/16450/16550A
	mov	dx,modem.mdstat		; line status register
	in	al,dx		     ; read to clear UART BI, FE, PE, OE bits
	call	delay
	in	al,dx			; these bits should be cleared
	test	al,8eh			; are they cleared?
	jnz	chkpor1			; nz = no, not an 8250/16450/16550A
	pop	dx
	pop	ax
	clc				; clear carry (say 8250/etc)
	ret
chkpor1:pop	dx
	pop	ax
	add	flags.comflg,'0'	; set Bios usage flag (ascii digit)
chkporx:stc				; set carry (say no 8250/etc)
	ret
chkport	endp

; Test serial hardware port given in BL (1..4). Return carry set if fail.
tstport	proc	near
	push	bx
	push	es
	mov	ax,40h		; look at RS232_base [bx] in Bios area 40:00h
	mov	es,ax
	xor	bh,bh
	dec	bl			; count com1 as bl = 0, etc
	shl	bx,1			; make bx a word index
	mov	ax,es:[bx]		; get modem base address into ax
	pop	es
	or	ax,ax			; is address zero?
	jnz	tstport1		; nz = no, have port address
	mov	ax,defcom[bx]		; get default COMn port address
tstport1:				; hardware tests
	push	modem.mdiir		; save these values
	push	modem.mdstat
	add	ax,2
	mov	modem.mdiir,ax		; interrupt identification reg 03fah
	add	ax,3			; increment to status port 03fdh
	mov	modem.mdstat,ax		; set line-status port address
	call	chkport			; get type of UART support
	pop	modem.mdstat
	pop	modem.mdiir
	pop	bx
	ret				; return with carry flag from chkport
tstport	endp

ifndef	no_network
; Check for presence of IBM EBIOS
; Returns carry clear if EBIOS present, else carry set
chkebios proc	near
	mov	dx,ebport		; port 0..3
	mov	ax,ebpresent*256+0ffh	; IBM EBIOS presence check
	int	rs232
	jc	chkebios1		; c = failure
	or	ax,ax			; returns ax = 0 if present
	jnz	chkebios1		; nz = not present
	clc
	ret
chkebios1:stc				; IBM EBIOS not present
	ret
chkebios endp
endif	; no_network

; Set the baud rate for the current port, based on the value
; in the portinfo structure.  Returns carry clear.

BAUDST	PROC	NEAR
	mov	dx,offset bdtab		; baud rate table, ascii
	xor	bx,bx			; help is the table itself
	mov	ah,cmkey		; get keyword
	call	comnd
	jc	baudst1			; c = failure
	push	bx			; save result
	mov	ah,cmeol		; get confirmation
	call	comnd
	pop	bx
	jc	baudst1			; c = failure
	call	dobaud			; use common code
	clc
baudst1:ret
BAUDST	ENDP

DOBAUD	PROC	NEAR
	cmp	portin,-1		; port used yet?
	jne	dobd3			; ne = yes, go get rate
	push	bx			; save rate index
	mov	bl,flags.comflg		; pass current port ident
	call	comstrt			; do SET PORT command now
	pop	bx
	jnc	dobd3			; nc = success
dobd4:	stc
	ret				; failure
dobd3:	push	bx			; save baud rate index
	mov	al,flags.comflg		; comms port
	cmp	al,'E'			; EBIOS?
	je	dobd5			; e = yes
	cmp	al,'4'			; UART or Bios?
	ja	dobd1			; a = no, networks
	call	chkport			; check port for real 8250 UART
dobd5:	pop	bx			; baud rate index
	push	bx			; check if new rate is valid
	mov	ax,bx
	shl	ax,1			; make a word index
	mov	bx,offset bddat		; start of table
	cmp	flags.comflg,'0'	; Bios?
	jb	dobd0a			; b = no, UART
	mov	bx,offset clbddat	; use Bios speed parameters
dobd0a:	add	bx,ax
	mov	ax,[bx]			; data to output to port
	cmp	al,0FFh			; unimplemented baud rate?
	jne	dobd0			; ne = no
	mov	ah,prstr
	mov	dx,offset badbd		; give an error message
	int	dos
	jmp	dobd1

dobd0:	pop	bx			; get baud rate index
	push	bx
	mov	si,portval
	mov	[si].baud,bx		; set the baud rate index
	mov	dl,flags.comflg		; get coms port (1..4, letters)
	cmp	dl,4			; running on a real uart?
	jbe	dobd2			; be = yes, the real thing
	cmp	dl,'E'			; EBIOS?
	je	dobd6			; e = yes
	cmp	dl,'4'			; Bios?
	ja	dobd1			; a = no, network
	or	dl,dl			; zero (undefined port)?
	jz	dobd1			; z = yes, just exit
	and	dl,7			; use lower three bits
	dec	dl			; count ports as 0..3 for Bios
	jmp	short dobd7
dobd6:
ifndef	no_network
	test	nettype,acsi		; using EBIOS.COM?
	jnz	dobd8			; nz = not using it
	mov	dx,ebport		; get EBIOS port (0..3)
endif	; no_network
dobd7:	xor	dh,dh
	xor	ah,ah			; set serial port
	int	rs232			; Bios: set the parameters
     	jmp	short dobd1		; and exit

ifndef	no_network
dobd8:	push	bx			; ACSI
	call	send			; send current buffer first
	pop	bx
	shl	bx,1			; index words
	mov	ax,clbddat[bx]		; Bios speed settings
	mov	word ptr xmtbufx,4	; four bytes in packet
	mov	ah,acsetmode		; ACSI set mode
	mov	word ptr xmtbufx+2,ax	; Mode setting
	call	send			; send speed update to host
	jmp	short dobd1		; exit
endif	; no_network

dobd2:	pushf
	cli				; interrupts off
	push	ax			; UART, remember value to output
	mov	dx,modem.mdcom		; LCR -- Initialize baud rate
	in	al,dx			; get it
	mov	bl,al			; make a copy
	or	ax,80H		; turn on DLAB bit to access divisor part
	out	dx,al
	mov	dx,modem.mddat
	pop	ax			; set the baud rate divisor
	out	dx,al
	inc	dx			; next address for high part
	mov	al,ah			; set high part of divisor
	out	dx,al
	mov	dx,modem.mdcom		; LCR again
	mov	al,bl			; get original setting from bl
	out	dx,al			; restore it
	popf				; restore interrupt state
dobd1:	pop	bx			; restore regs
	clc
	ret
DOBAUD	ENDP

; Get the current baud rate from the serial card and set it
; in the portinfo structure for the current port.  Returns normally.
; This is used during initialization.

GETBAUD	PROC	NEAR
	push	ax
	push	bx
	mov	bx,portval
	mov	al,flags.comflg
	cmp	al,4			; UART?
	ja	getb3			; a = no, Bios or Networks
	cmp	portin,-1		; port unused?
	jne	getbud			; ne = no, used, go get rate
	mov	bl,al			; pass current port ident
	call	comstrt			; do SET PORT command now
	jnc	getbud			; nc = success
getb3:	pop	bx
	pop	ax
	ret				; failure
getbud:	push	cx			; save some regs
	push	dx
	pushf
	cli				; interrupts off
	mov	dx,modem.mdcom	     ; get current Line Control Register value
	in	al,dx
	mov	bl,al			; save it
	or	ax,80H		      ; turn on to access baud rate generator
	out	dx,al
	mov	dx,modem.mddat		; Divisor latch
	inc	dx
	in	al,dx			; get high order byte
	mov	ah,al			; save here
	dec	dx
	in	al,dx			; get low order byte
	push	ax	
	mov	dx,modem.mdcom		; Line Control Register
	mov	al,bl			; restore old value
	out	dx,al
	pop	ax
	popf				; ints back to normal
	cmp	ax,0FFFFH		; if no port
	je	getb2			; e = no port, bus noise
	mov	bx,offset bddat		; find rate's offset into table
	xor	cl,cl			; keep track of index
getb0:	cmp	ax,[bx]			; observed vs table divisor
	je	getb1			; e = found a match
	inc	cl			; next table index
	cmp	cl,baudlen		; at the end of the list?
	jge	getb2			; ge = yes, quit
	add	bx,2			; next table entry
	jmp	short getb0
getb1:	xor	ch,ch
	mov	bx,portval
	mov	[bx].baud,cx		; set baud rate
getb2:	pop	dx			; restore regs
	pop	cx
	pop	bx
	pop	ax
	clc
	ret
GETBAUD	ENDP

; Examine incoming communications stream for a packet SOP character.
; Return CX= count of bytes starting at the SOP character (includes SOP)
; and carry clear. Return CX = 0 and carry set if SOP is not present.
; Destroys AL.
; Tells a fib about SOP present if using SET CARRIER on serial links
; and cardet says loss of carrier.
peekcom proc far
	cmp	flags.comflg,'F'	; Fossil?
	je	peekc8			; e = yes
	cmp	flags.comflg,4		; UART?
	ja	peekc9			; a = no
peekc8:	cmp	flags.carrier,0		; worry about Carrier Detect?
	je	peekc9			; e = no
	cmp	dupflg,0		; full duplex?
	jne	peekc9			; e = no, half
	test	cardet,1		; 1 = "CD was on, is now off"
	jz	peekc9			; z = no
	mov	flags.cxzflg,'C'	; simulate Control-C interrupt
	mov	cx,6			; lie that enough bytes to be read
	clc				; say enough for SOP
	ret				; so cardet is passed upward now

peekc9:	mov	cx,count		; qty in circular buffer
	cmp	cx,6			; basic NAK
	jb	peekc4			; b = two few chars, get more
	push	bx
	cli		; interrupts off, to keep srcpnt & count consistent
	mov	bx,srcpnt	    ; address of next available slot in buffer
	sub	bx,cx		    ; minus number of unread chars in buffer
	mov	ah,trans.rsoh
	cmp	bx,offset source	; located before start of buf?
	jae	peekc1			; ae = no
	add	bx,bufsiz		; else do arithmetic modulo bufsiz
peekc1:	mov	al,[bx]
	cmp	al,ah			; packet receive SOP?
	je	peekc3			; e = yes
	inc	bx
	cmp	bx,offset source+bufsiz ; beyond end of buffer?
	jb	peekc2			; b = no
	mov	bx,offset source	; wrap around
peekc2:	loop	peekc1			; keep looking
	sti
	pop	bx
	stc				; set carry for no SOP
	ret
peekc3:	sti				; interrupts back on now
	pop	bx
	inc	cx			; include SOP in count
	clc				; say SOP found
	ret				; CX has count remaining
	
peekc4:	push	bx			; read from port, add to buffer
	mov	bx,portval
	push	si			; used by packet routines
	call	[bx].rcvproc		; read routine
	pop	si
	jc	peekc7			; c = nothing available
	cmp	count,0			; something put in buffer?
	jne	peekc7			; ne = yes, go read from buffer
	mov	bx,srcpnt		; where next read would be
	inc	bx			; add to buffer
	cmp	bx,offset source+bufsiz	; pointing beyond end of buffer?
	jb	peekc5			; b = no
	mov	bx,offset source	; wrap pointer, modulo bufsiz
peekc5:	cli
	mov	[bx],al			; store byte
	mov	srcpnt,bx		; update pointer to next free slot
	inc	count
	cmp	count,bufsiz		; count more that buffer size?
	jbe	peekc6			; be = no
	mov	count,bufsiz		; limit to bufsiz (tells the truth)
peekc6:	sti
peekc7:	pop	bx
	cmp	count,6			; enough for basic NAK?
	jae	peekcom			; ae = yes, repeat examination
	xor	cx,cx			; return count of zero
	stc				; say no data
	ret
peekcom endp

; Get Char from	serial port buffer.
; returns carry set if no character available at port, otherwise
; returns carry clear with char in al, # of chars in buffer in dx.
prtchr  proc	near
	cmp	holdscr,0		; Holdscreen in effect?
	jne	prtch3			; ne = yes, do not read
	call	chkxon			; see if we need to send XON
	cmp	repflg,0		; REPLAY?
	je	prtch1			; e = no
	jmp	prtchrpl		; yes, do replay file reading
prtch1:	cmp	count,0			; is buffer empty?
	jne	prtch4			; ne = no, read from it
	push	bx
	mov	bx,portval
	call	[bx].rcvproc		; read routine
	pop	bx			; fall through to grab new char
	jc	prtch3			; c = nothing available
	cmp	count,0			; something put in buffer?
	jne	prtch4			; ne = yes, go read from buffer
prtch2:	inc	dx
	clc				; return single char already in AL
	ret
prtch3:	xor	dx,dx			; return count of zero
	stc				; say no data
	ret

prtch4:	push	si			; save si
	cli		; interrupts off, to keep srcpnt & count consistent
	mov	si,srcpnt	    ; address of next available slot in buffer
	sub	si,count	    ; minus number of unread chars in buffer
	cmp	si,offset source	; located before start of buf?
	jae	prtch5			; ae = no
	add	si,bufsiz		; else do arithmetic modulo bufsiz
prtch5:	lodsb				; get a character into al
	dec	count			; one less unread char now
	jnz	prtch6			; if still have bytes
	mov	srcpnt,offset source	; else reset read ptr to start too
prtch6:	sti				; interrupts back on now
	pop	si
	mov	dx,count		; return # of chars in buffer
	clc
	ret
prtchr  endp

; Move up to cx bytes from current buffer to destination es:bx
; Return quantity moved in cx, bytes remaining to be read in dx,
; and carry clear. Return cx = 0 and carry set if none.
; This reads only those bytes already in buffer ds:source, hence non-blocking.
prtblk	proc	far
	push	di
	push	si
	cmp	count,0		; buffer empty?
	jne	prtblk1		; ne = no
	xor	cx,cx		; say no bytes transferred
	xor	dx,dx
	stc
	jmp	short prtblk7	; exit

prtblk1:mov	di,bx		; destination offset to es:di
	mov	dx,cx		; dx holds request count
	CLI			; to prevent confusion from serial port ints
	mov	bx,srcpnt	; original values
	mov	cx,count
	STI			; we have the pointers now
	cmp	dx,cx		; want more than available?
	jbe	prtblk2		; be = no
	mov	dx,cx		; limit to available
prtblk2:push	dx		; save as returned byte count
	mov	si,bx		; where next byte would be written
	sub	si,cx		; minus bytes in buffer, yields first byte
	cmp	si,offset source ; before start of buffer?
	jge	prtblk3		; ge = no
	add	si,bufsiz	; wrap
				; si is offset where data start
prtblk3:mov	ax,offset source+bufsiz ; end of buffer + 1
	sub	ax,si		; space to end of buffer
	mov	cx,dx		; cx is amount to transfer in one go
	cmp	cx,ax		; wanted vs space at end of buffer
	jbe	prtblk4		; be = have all wanted without wrap
	mov	cx,ax		; reduce to space to end of buffer
prtblk4:sub	dx,cx		; deduct amount being moved now
	cld
	shr	cx,1		; get odd count to carry
	rep	movsw		; move words
	jnc	prtblk5		; nc = even count
	movsb			; move odd byte
prtblk5:cmp	dx,0		; bytes remining to move
	jle	prtblk6		; le = none
	mov	si,offset source ; start of buffer
	mov	cx,dx		; amount left to do
	shr	cx,1		; get odd count to carry
	rep	movsw		; move words
	jnc	prtblk6		; nc = even count
	movsb			; move odd byte
prtblk6:mov	bx,di		; update caller's write pointer es:bx
	xor	al,al
	stosb			; null terminator, not in count
	pop	cx		; returned byte count
	CLI
	sub	count,cx	; correct count by bytes extracted
	mov	dx,count	; return available bytes
	STI
	clc			; say success and have moved CX bytes
prtblk7:pop	si
	pop	di
	ret
prtblk	endp

uartrcv	proc	near			; UART receive
	cmp	flags.carrier,0		; worry about Carrier Detect?
	je	uartrcv1		; e = no
	cmp	dupflg,0		; full duplex?
	jne	uartrcv1		; e = no, half
	push	dx
	mov	dx,modem.mddat
	add	dx,6			; modem status reg 3feh
	in	al,dx			; 03feh, modem status reg
	pop	dx
	and	al,80h			; get CD bit
	jnz	uartrcv2		; nz = CD is on now
	test	cardet,80h		; previous CD state
	jz	uartrcv2		; z = was off
	mov	al,01h			; say was ON but is now OFF
	mov	flags.cxzflg,'C'	; simulate Control-C interrupt
uartrcv2:mov	cardet,al		; preserve as global
	cmp	al,1			; carrier dropped?
	jne	uartrcv1		; ne = no
	push	bx
	mov	bx,portval
	mov	[bx].portrdy,0		; say port is not ready
	pop	bx
	mov	kbdflg,'C'		; exit Connect mode
uartrcv1:stc				; say not returning char in al here
	ret				; interrupt driven so no work here
uartrcv	endp

biosrcv	proc	near			; Bios calls
	xor	dh,dh			; assume port 1, find current port
	mov	dl,flags.comflg		; get port number (1..4)
	or	dl,dl			; zero (no such port)?
	jz	biosrc1			; z = yes, don't access it
	and	dl,7			; use low three bits
	dec	dl			; address ports as 0..3 for Bios
	mov	ah,3			; check port status, std Bios calls
	int	rs232			; Bios call
	cmp	flags.carrier,0		; worry about Carrier Detect?
	je	biosrc4			; e = no
	and	al,80h			; get CD bit
	jnz	biosrc3			; nz = CD is on now
	test	cardet,80h		; previous CD state
	jz	biosrc4			; z = was off
	mov	al,01h			; say was ON but is now OFF
	mov	flags.cxzflg,'C'	; simulate Control-C interrupt
biosrc3:mov	cardet,al		; preserve as global

biosrc4:test	ah,mdminp		; data ready?
	jnz	biosrc2			; nz = yes, get one
biosrc1:cmp	flags.carrier,0		; worry about Carrier Detect?
	je	biosrc5			; e = no
	cmp	dupflg,0		; full duplex?
	jne	biosrc4			; e = no, half
	test	cardet,1		; 1 = "CD was on, is now off"
	jz	biosrc5			; z = no
	mov	flags.cxzflg,'C'	; simulate Control-C interrupt
	push	bx
	mov	bx,portval
	mov	[bx].portrdy,0
	pop	bx
	mov	kbdflg,'C'		; exit Connect mode
biosrc5:stc				; say not returning char in al here
	ret
biosrc2:mov	ah,2			; receive a char into al
	int	rs232			; Bios call
	test	ah,8ch			; timeout, framing error, parity error?
	jnz	biosrc1			; nz = error, no char
	jmp	short schrcv		; single char read post processor
biosrcv	endp

schrcv	proc	near			; single char read final filter	
	test	flowcnt,2		; using input XON/XOFF flow control?
	jz	schrcv3			; z = no
	mov	ah,al			; get copy of character
	and	ah,parmsk		; strip parity, if any, before testing
	cmp	ah,flowoff		; acting on XOFF?
	jne	schrcv2			; ne = no, go on
	cmp	xofsnt,0		; have we sent an outstanding XOFF?
	jne	schrcv1			; ne = yes, ignore (possible echo)
	mov	xofrcv,bufon		; set the flag saying XOFF received
schrcv1:stc				; say not returning char in al here
	ret
schrcv2:cmp	ah,flowon		; acting on XON?
	jne	schrcv3			; ne = no, go on
	mov	xofrcv,off		; clear the XOFF received flag
	xor	dx,dx
	stc
	ret				; no data to return
schrcv3:xor	ah,ah
	clc				; return char in al
	ret				; expect count=0
schrcv	endp

; Fossil block receive
fosrcv	proc	near
	mov	dx,fossil_port		; get port number (1..4)
	mov	ah,fossil_portst	; check port status, std Bios calls
	int	rs232			; Bios call
	cmp	flags.carrier,0		; care abour carrier?
	je	fosrcv4			; e = no
	and	al,80h			; get CD bit
	jnz	fosrcv3			; nz = CD is on now
	test	cardet,80h		; previous CD state
	jz	fosrcv4			; z = was off
	mov	al,01h			; say was ON but is now OFF
	mov	flags.cxzflg,'C'	; simulate Control-C interrupt
fosrcv3:mov	cardet,al		; preserve as global
fosrcv4:test	ah,mdminp		; data ready?
	jnz	fosrcv2			; nz = yes, get one
fosrcv1:cmp	flags.carrier,0		; worry about Carrier Detect?
	je	fosrcv5			; e = no
	cmp	dupflg,0		; full duplex?
	jne	fosrcv4			; e = no, half
	test	cardet,1		; 1 = "CD was on, is now off"
	jz	fosrcv5			; z = no
fosrcv6:call	serrst			; close port
	mov	kbdflg,'C'		; exit Connect mode
fosrcv5:stc				; say not returning char in al here
	ret
fosrcv2:push	es
	mov	ax,seg rcvbuf
	mov	es,ax
	mov	cx,nbuflen		; buffer length
	mov	di,offset rcvbuf
	mov	ah,fossil_blkrd		; receive block
	xor	al,al
	int	rs232			; Bios call
	pop	es
	or	ax,ax			; count received
	jz	fosrcv1			; z = no char
	cmp	ax,0ffffh		; error condition?
	je	fosrcv6			; e = yes, shut down port
	cmp	ax,fossil_blkrd*256	; complete no-op?
	je	fosrcv6			; e = yes
	mov	rcv.scb_length,ax	; count received
	mov	rcv.scb_baddr,di	; offset of receive buffer
	jmp	blkrcv			; block read post processor
fosrcv	endp

ifdef	no_terminal
					; REPLAY, read char from a file
prtchrpl proc	near
	stc
	ret
prtchrpl endp
endif	; no_terminal
ifndef	no_terminal
prtchrpl proc	near
	cmp	repflg,2		; at EOF already?
	jne	prtchrp1		; ne = no
	stc				; yes, return with no char
	ret
prtchrp1:push	bx
	push	cx
	xor	dx,dx
	test	xofsnt,usron		; user level xoff sent?
	jz	prtchrp2		; z = no
	pop	cx			; suppress reading here
	pop	bx
	stc				; say not returning char in al here
	ret
prtchrp2:test	tekflg,tek_active	; doing graphics mode?
	jnz	prtchrp3		; nz = yes, do not insert pauses
	in	al,ppi_port		; delay
	in	al,ppi_port
	in	al,ppi_port		; burn some bus cycles
	in	al,ppi_port		; because a 1 ms wait is too long
	in	al,ppi_port
prtchrp3:mov	ah,readf2
	mov	bx,diskio.handle	; file handle
	mov	cx,1			; read one char
	mov	dx,offset decbuf	; to this buffer
	int	dos
	jc	prtchrp4		; c = read failure
	cmp	ax,cx			; read the byte?
	jne	prtchrp4		; ne = no
	pop	cx
	pop	bx
	mov	al,decbuf		; get the char into al
	clc
	ret				; return it
prtchrp4:call	beep
	mov	ax,40			; wait 40 millisec
	call	pcwait
	call	beep
	mov	repflg,2		; say at EOF
	pop	cx
	pop	bx
	stc				; say not returning char in al here
	ret
prtchrpl endp
endif	; no_terminal

ifndef	no_network
ebircv	proc	near			; EBIOS calls
	mov	dx,ebport		; port 0..3
	mov	ah,ebrcv		; IBM EBIOS receive /no wait
	int	rs232			; does line check then char ready chk
	test	ah,8ch			; timeout, framing error, parity error?
	jnz	ebircv2			; nz = error, no char
	jmp	schrcv			; z = success, process char in AL
ebircv2:stc				; say not returning char in al here
	ret
ebircv	endp

; DECnet receive routine
DECRCV	PROC	NEAR
	test	nettype,declat		; LAT interface?
	jz	decrcv1			; z = not LAT
	mov	dx,lathand
	or	dx,dx			; invalid handle?
	jz	decrcv1			; z = yes, try CTERM

	mov	cx,bufsiz		; final receiver buffer length
	sub	cx,count		; minus occupancy
	cmp	cx,254			; too big for broken DEC LAT?
	jbe	decrcv5			; be = no
	mov	cx,254			; limit to byte sized length
decrcv5:push	es
	mov	ax,seg rcvbuf
	mov	es,ax			; es:bx will point to rcvbuf
	mov	bx,offset rcvbuf
	mov	ah,latreadb		; read a block to es:bx, max len cx
	mov	dx,lathand
	int	latint
	pop	es
	test	ah,80h			; ah is status
	jnz	decrcv6			; nz = error of some kind
	jcxz	decrcv6			; z = no received bytes, do status
	mov	rcv.scb_length,cx	; bytes received, setup blkrcv
	call	blkrcv			; process buffer
	stc				; say not returning char in al here
	ret

; non-SCB status check, slower and much safer
decrcv6:mov	ah,latstat		; get status
	mov	dx,lathand
	int	latint
	test	ah,4			; session not active?
	jnz	decrcv3			; nz = yes, no valid session
	stc				; say not returning char in al here
	ret
; end alterntive code
;	push	es
;	push 	bx
;	les	bx,latscbptr
;	test	es:[bx].sstatus,18h	; status: stop slot or circuit failure
;	pop	bx
;	pop	es
;	jnz	decrcv4			; nz = yes, no valid session
;	stc				; return no char
;	ret

decrcv1:test	nettype,decnet		; is CTERM active?
	jz	decrcv3			; z = no
	mov	dx,decneth		; handle
	or	dx,dx			; legal?
	jz	decrcv3			; z = no
	mov	ax,dcstat		; CTERM status
	int	decint
	test	ah,0c0h			; no session, DECnet error?
	jnz	decrcv3			; nz = yes, stop here
;	test	ah,1			; data available?
;	jz	decrcv4			; z = no
; data available test fails under flow control, maybe a Cterm bug.
	mov	ax,dread		; read char via CTERM
	int	decint
	test	ah,80h			; char received?
	jnz	decrcv4			; nz = no
decrcv2:jmp	schrcv			; use common completion code

decrcv3:call	decclose		; close connection
	test	flags.remflg,dserver	; server mode?
	jz	decrcv4			; z = no
	call	serini			; reinitialize it for new session
decrcv4:stc				; say not returning char in al here
	ret
DECRCV	ENDP

; NetBios Receive packet routine. If a new packet has been received unpack
; the data and request a new one with no-wait option. If a receive request is
; still outstanding just return with no new data.
; Return carry clear if success. If failure, reset serial port (Server mode
; reinits serial port). Return carry set. No entry setup needed.
RECEIVE PROC	NEAR			; receive network session pkt
	cmp	pcnet,1			; net ready yet?
	jbe	receiv3			; be = no, declare a broken session
	cmp	rposted,1		; is a request outstanding now?
	je	receiv4			; e = yes (1), don't do another
	jb	receiv1			; b = no (0), do one now
	call	receiv2			; have new pkt, unpack, do new recv
	jnc	receiv1			; nc = success
	ret				; else return carry set

receiv1:mov	rposted,1		; say posting a receive now
	mov	rcv.scb_length,nbuflen	; length of input buffer  
	mov	rcv.scb_cmd,nreceive+nowait   ; receive, no wait
	push	bx
	mov	bx,offset rcv		; setup pointer to scb
	call	nbsession
	pop	bx
	stc				; set carry to say no char yet
	ret				

receiv2:mov	al,rcv.scb_err		; returned status
	or	al,al			; success?
	jz	receiv5			; z = yes, get the data
	cmp	al,npending		; pending receive?
	je	receiv4			; e = yes
	cmp	al,6			; message incomplete?
	je	receiv5			; e = yes, get what we have anyway
	cmp	al,0bh			; receive cancelled?
	je	receiv3			; e = yes
	cmp	al,18h			; session ended abnormally?
	jbe	receiv3			; e = yes, b = other normal errors
	mov	ah,prstr
	mov	dx,offset recmsg	; give error message
	int	dos
	mov	al,rcv.scb_err		; get error code
	xor	ah,ah
	call	decout			; show error code
					; Error return
receiv3:mov	pcnet,1			; say session is broken
	call	serrst			; close the connection
	cmp	lposted,1		; Listen posted?
	je	receiv3a		; e = yes, stay alive
	cmp	xmt.scb_rname,'*'	; behaving as a Listner?
	je	receiv3a		; e = yes, stay alive
	test	flags.remflg,dserver	; server mode?
	jz	receiv4			; z = no
receiv3a:call	serini			; reinitialize it for new session
receiv4:stc				; say not returning char in al here
	ret
receiv5:mov	rposted,0		; clear interlock flag
	test	nettype,acsi		; ACSI?
	jnz	receiv6			; nz = yes
	jmp	blkrcv			; process block of data
receiv6:jmp	acsircv			; process special format block data
RECEIVE	ENDP
endif	; no_network

; Block receive transfer and flow control scan routine
; Enter with DS:rcv.scb_baddr pointing at source buffer (rcvbuf),
; and rcv.scb_length holding incoming byte count.
; Destroys reg BX
; Shared by NetBios, Novell, Opennet, Ungerman Bass, 3ComBAPI, TCP/IP, etc
blkrcv	proc	near
	push	cx			; new packet has been received
	push	dx			; copy contents to circ buf source
	push	si
	mov	dh,flowon
	mov	dl,flowoff
	mov	si,rcv.scb_baddr	; source of text
	mov	bx,srcpnt		; address of destination buffer slot
blkrcv6:mov	cx,rcv.scb_length	; get remaining returned byte count
	jcxz	blkrcv13		; z = nothing there
	mov	ax,offset source+bufsiz ; end of destination buffer+1
	sub	ax,bx			; space remaining at end of buffer
	jns	blkrcv7			; should never be negative
	neg	ax			; but if so invert
blkrcv7:cmp	ax,cx			; buffer ending vs incoming byte count
	jge	blkrcv8			; ge = enough for this pass
	mov	cx,ax			; limit this pass to end of the buffer
blkrcv8:sub	rcv.scb_length,cx	; deduct chars done in this pass
	add	count,cx		; add them to the count
	cld				; inner loop "block" transfer
	test	flowcnt,2		; doing input XON/XOFF flow control?
	jz	blkrcv20		; z = no
blkrcv9:lodsb				; get byte from rcvbuf to al
	mov	ah,al			; get copy of character
	and	ah,parmsk		; strip parity, if any, before testing
	cmp	ah,dl			; acting on Xoff?
	jne	blkrcv10		; ne = no
	cmp	xofsnt,0		; have we sent an XOFF?
	jne	blkrcv12		; ne = yes, ignore this XOFF char
	mov	xofrcv,bufon		; set flag saying buffer XOFF received
	dec	count			; uncount flow control
	jmp	short blkrcv12		;  and skip this character
blkrcv10:cmp	ah,dh			; acting on XON?
	jne	blkrcv11		; ne = no, go on
	mov	xofrcv,off		; clear the XOFF received flag
	dec	count			; uncount flow control
	jmp	short blkrcv12		;  and skip this character
blkrcv11:mov	[bx],al			; store new char in buffer "source"
	inc	bx
blkrcv12:loop	blkrcv9			; bottom of inner loop
	jmp	short blkrcv22

blkrcv20:push	es			; no flow control, just do copy
	push	di
	mov	ax,ds
	mov	es,ax
	mov	di,bx			; destination
	shr	cx,1			; prep for word moves
	jnc	blkrcv21		; nc = even number of bytes
	movsb
blkrcv21:rep	movsw			; do quick copy
	mov	bx,di			; update destination pointer
	pop	di
	pop	es
					; update buffer pointer for wrapping
blkrcv22:cmp	bx,offset source+bufsiz	; pointing beyond end of buffer?
	jb	blkrcv6			; b = no, do next pass
	mov	bx,offset source	; wrap pointer, modulo bufsiz
	jmp	short blkrcv6		; do next pass

blkrcv13:mov	srcpnt,bx		; update pointer to next free slot
	cmp	count,bufsiz		; count more that buffer size?
	jbe	blkrcv14		; be = no
	mov	count,bufsiz		; limit to bufsiz (tells the truth)
blkrcv14:pop	si
	pop	dx
	pop	cx
	stc				; say no char in al from us
	ret
blkrcv	endp

ifndef	no_network
; ACSI block receive transfer and flow control scan routine
; Enter with DS:rcv.scb_baddr pointing at source buffer (rcvbuf),
; and rcv.scb_length holding incoming byte count.
; Destroys regs AX and BX.
; Format of packet: int count of entire block, then [char, status] byte pairs
acsircv	proc	near
	push	cx			; new packet has been received
	push	dx			; copy contents to circ buf source
	push	si
	mov	dh,flowon
	mov	dl,flowoff
	mov	bx,srcpnt		; address of destination buffer slot
	mov	si,rcv.scb_baddr	; source of text
	cld
	lodsw				; get internal length word
	mov	cx,rcv.scb_length	; get block length
	mov	rcv.scb_length,0	; clear counter
	sub	cx,2			; data bytes remaining in block
	cmp	ax,cx			; internal vs external count
	jae	acsrcv1			; ae=internal is gt or equal to ext
	mov	cx,ax			; use shorter internal count
acsrcv1:shr	cx,1			; count words in block
	jcxz	acsrcv14		; z = nothing there

acsrcv9:lodsw				; get char+status bytes from rcvbuf
	test	ah,80h			; status, is it a command?
	jnz	acsrcv12		; nz = yes, ignore the pair
	test	flowcnt,2		; using input XON/XOFF flow control?
	jz	acsrcv11		; z = no
	mov	ah,al			; get copy of character
	and	ah,parmsk		; strip parity, if any, before testing
	cmp	ah,dl			; acting on Xoff?
	jne	acsrcv10		; ne = no
	cmp	xofsnt,0		; have we sent an XOFF?
	jne	acsrcv12		; ne = yes, ignore this XOFF char
	mov	xofrcv,bufon		; set flag saying buffer XOFF received
	jmp	short acsrcv12		;  and skip this character
acsrcv10:cmp	ah,dh			; acting on XON?
	jne	acsrcv11		; ne = no, go on
	mov	xofrcv,off		; clear the XOFF received flag
	jmp	short acsrcv12		;  and skip this character
acsrcv11:mov	[bx],al			; store new char in buffer "source"
	inc	bx
	inc	count			; add it to the count
	cmp	bx,offset source+bufsiz	; pointing beyond end of buffer?
	jb	acsrcv12		; b = no
	mov	bx,offset source	; wrap pointer, modulo bufsiz
acsrcv12:loop	acsrcv9

acsrcv13:mov	srcpnt,bx		; update pointer to next free slot
	cmp	count,bufsiz		; count more that buffer size?
	jbe	acsrcv14		; be = no
	mov	count,bufsiz		; limit to bufsiz (tells the truth)
acsrcv14:pop	si
	pop	dx
	pop	cx
	stc				; say no char in al from us
	ret
acsircv	endp

; NetBios Receive post processing interrupt routine.
; Sets rposted interlock flag
RPOST	PROC	NEAR		; NetBios receive post interrupt routine
	push	ds
	push	ax
	mov	ax,data			; reestablish data segment
	mov	ds,ax
	mov	rposted,2		; set interlock flag to completed
	pop	ax
	pop	ds
	iret				; return from interrupt
RPOST	endp

; TES block mode receive, uses blkrcv to process results
TESRCV	proc	near
	push	di
	push	cx
	push	dx
	push	es
	mov	ax,data
	mov	es,ax			; es:di will point to rcvbuf
	mov	di,offset rcvbuf
	mov	cx,nbuflen		; buffer length
	mov	dx,tesport		; operational port
	mov	ah,tesbread		; block read
	int	rs232
	jcxz	tesrcv1			; z = no characters read
	mov	rcv.scb_length,cx	; prepare for receive call
	call	blkrcv			; process rcvbuf
	jmp	short tesrcv2
tesrcv1:call	tesstate		; get session status to AH
	and	ah,7fh			; trim high bit (transition states)
	or	ah,ah			; session active?
	jnz	tesrcv2			; nz = yes, carry on
	call	tesclose		; close our end
tesrcv2:pop	es
	pop	dx
	pop	cx
	pop	di
	stc				; say not returning char in al here
	ret
TESRCV	endp

; Ungermann-Bass NETCI port receive characters routine.  Receive one or more
; characters.  Calls the blkrcv routine to transfer character to main source
; circular buffer.  Return carry clear if success.
; This is called only if buffer "source" is entirely empty, so we are free
; to adjust srcpnt and count items.
UBRECV	PROC	near
	push	cx
	push	es
	mov	ax,data
	mov	es,ax			; es:bx will point to rcvbuf
	mov	bx,offset rcvbuf
	mov	cx,nbuflen		; buffer length
ubrecv2:test	nettype,bapi+tcpnet	; 3Com BAPI or TCP Telnet interface?
	jz	ubrecv2a		; z = no
	mov	ah,bapiread
	xor	dh,dh			; session 0
ifndef	no_tcp
	test	nettype,tcpnet		; TCP/IP Telnet?
	jz	ubrecv2d		; z = no
	test	flowcnt,2		; doing input XON/XOFF flow control?
	jz	ubrcv2f			; z = no, use fast method
	call	ktcpcom			; Far call Telnet code
	jmp	short ubrecv2e		; regular slow method
ubrcv2f:mov	bx,offset source
	mov	cx,bufsiz-2		; go directly to source, no xon/xoff
	call	ktcpcom			; Far call Telnet code
	cmp	ah,3			; status, no session and above
	jae	short ubrecv2b		; ae = broken connection, terminate it
	mov	count,cx		; bytes transferred to empty buffer
	add	cx,offset source
	mov	srcpnt,cx		; where next read byte goes
	pop	es
	pop	cx
	stc				; say no char from us
	ret
endif	; no_tcp
ubrecv2d:int	bapiint

ubrecv2e:cmp	ah,3			; status, no session and above
	jb	ubrecv3			; b = no, successful?
	jmp	short ubrecv2b		; broken connection, terminate it

ubrecv2a:test	nettype,telapi		; Novell TELAPI?
	jz	ubrecv2c		; z = no, use Int 6Bh kind
	push	si
	push	bx
	mov	si,bx			; use es:si for buffer address
	mov	bx,telses		; session number
	mov	ah,telread
	int	rs232
	pop	bx
	pop	si
	xchg	ax,cx			; byte count returned in AX
	jcxz	ubrecv2b		; z = connection broken
	or	cx,cx
	jns	ubrecv3			; ns = no error
	cmp	cx,-35			; status of no data?
	jne	ubrecv2b		; ne = no
	xor	cx,cx			; mimic no data
	jmp	short ubrec1
ubrecv2b:call	ubclose
	jmp	short ubrec1

ubrecv2c:test	nettype,netone		; UB?
	jz	ubrec1			; z = no, do nothing
	mov	ax, nciread		; function 1 (receive) port 0	 [ohl]
	int	netci			; get characters		 [ohl]
ubrecv3:jcxz	ubrec1			; cx = z = nothing to do
	mov	rcv.scb_length,cx	; prepare for rpost call
	call	blkrcv			; process buffer
ubrec1:	pop	es
	pop	cx
	stc				; say not returning char in al here
	ret
UBRECV	ENDP

; Beame & Whiteside TCP receive routine [JRS]
bwrecv	proc	near			; [JRS]
	test	nettype,bwtcp		; active?
	jnz	bwrecv1			; nz = yes
	stc
	ret

bwrecv1:push	di			; [JRS] save the environment
	push	si			; [JRS]
	push	dx			; [JRS]
	push	cx			; [JRS]
	push	bx			; [JRS]
	mov	ah,readf2		; [JRS] read from "file"
	mov	bx,bwhandle		; [JRS] device handle
	or	bx,bx
	jz	bwrecv4			; z = invalid handle
	mov	cx,nbuflen-4		; number of bytes to read - safety
	mov	dx,offset rcvbuf	; [JRS] data buffer is DS:DX
	int	dos			; [JRS] ask dos to get it
	jc	bwrecv5			; [JRS] c = no data available
	mov	cx,ax			; [JRS] get the number of bytes read
	jcxz	bwrecv4			; [JRS] no chars read is a hangup
	cmp	ax,nbuflen-4		; check on sanity
	ja	bwrecv5			; a = error of some kind, ignore
	mov	si,offset rcvbuf
	call	bwtnopt			; do options scanning
	jmp	short bwrecv5
bwrecv4:call	bwclose			; read failed, quit
bwrecv5:pop	bx			; [JRS] restore environment
	pop	cx			; [JRS]
	pop	dx			; [JRS]
	pop	si			; [JRS]
	pop	di			; [JRS]
	stc				; [JRS] flag no characters read
	ret				; [JRS]
bwrecv	endp				; [JRS]

; Beame & Whiteside telnet options scanner and processor
; Enter with newly read material in ds:si, of length CX bytes
bwtnopt	proc	near
	or	cx,cx
	jle	bwtnopt1		; le = nothing to do
	cmp	optstate,0		; outside IAC string?
	je	bwtnopt2		; e = yes
	jmp	bwtnopt20		; do options
bwtnopt1:ret

bwtnopt2:push	cx
	push	es
	mov	ax,seg rcvbuf		; make es:di the receiver buffer
	mov	es,ax
	mov	di,si
	mov	al,IAC			; IAC
	cld
	repne	scasb			; look for IAC
	pop	es
	pop	cx
	mov	ax,di			; points one byte after break
	jne	bwtnopt3		; ne = no IAC
	dec	ax			; backup to IAC
bwtnopt3:sub	ax,si			; minus starting offset
	sub	cx,ax			; original count - <before IAC>
	mov	rcv.scb_length,ax	; data length before IAC
	mov	rcv.scb_baddr,si 	; source of text
	add	si,ax			; starting point for IAC
	or	ax,ax			; any leading text?
	jz	bwtnopt4		; z = nothing to block receive upon
	call	blkrcv			; dispose of it, saves si and cx
bwtnopt4:or	cx,cx			; bytes remaining in buffer
	jg	bwtnopt5		; if positive then si == IAC byte
	xor	cx,cx			; force zero
	ret
bwtnopt5:inc	si
	dec	cx			; skip IAC
	mov	optstate,2		; read two more chars
	jmp	bwtnopt			; repeat

bwtnopt20:cmp	optstate,2		; reading 1st char after IAC?
	jb	bwtnopt23		; b = no
	dec	cx			; read the char
	lodsb
	cmp	al,SB			; before legal options?
	jae	bwtnopt22		; ae = no
	inc	si			; recover char
	inc	cx
	mov	optstate,0		; clear Options machine
	jmp	bwtnopt			; continue

bwtnopt22:mov	option1,al		; save first Option byte
	mov	optstate,1		; get one more byte
	jmp	bwtnopt			; get the second Options byte

bwtnopt23:mov	optstate,0		; read second char after IAC
	dec	cx			; read the char
	lodsb
	mov	option2,al		; second options byte
	mov	ah,option1
	mov	bx,portval
	mov	bl,[bx].ecoflg		; echo status
					; decode options and respond
	cmp	al,TELOPT_ECHO		; Echo?
	jne	bwtnopt30		; ne = no
	cmp	ah,WILL			; remote host will echo?
	jne	bwtnopt26		; ne = no
	cmp	bl,0			; are we doing local echo?
	je	bwtnopt29		; e = no
	mov	ah,DO			; say please echo
	call	bwsendiac
	xor	bl,bl			; say we should not echo
	call	setecho			; set our echo state
	jmp	bwtnopt
bwtnopt26:cmp	ah,WONT			; remote host won't supply echo?
	jne	bwtnopt28		; ne = no
	cmp	bl,0			; are we doing local echo?
	jne	bwtnopt29		; ne = yes
	mov	ah,DONT
	call	bwsendiac
	mov	bl,lclecho		; do local echoing
	call	setecho			; set local echoing state
	jmp	bwtnopt

bwtnopt28:cmp	ah,DO			; remote host wants us to echo?
	jne	bwtnopt29		; ne = no
	mov	ah,WONT			; decline
	call	bwsendiac
bwtnopt29:jmp	bwtnopt

bwtnopt30:cmp	al,TELOPT_SGA		; SGA?
	jne	bwtnopt40		; ne = no
	cmp	ah,WONT			; host won't do SGAs?
	jne	bwtnopt33		; ne = no
	cmp	sgaflg,0		; our state is don't too?
	jne	bwtnopt35		; ne = yes
	inc	sgaflg			; change state
	mov	ah,DONT			; say please don't
	call	bwsendiac
	cmp	bl,0			; doing local echo?
	jne	bwtnopt35		; ne = yes
	mov	bl,lclecho		; change to local echoing
	call	setecho
	jmp	bwtnopt			; continue
bwtnopt33:cmp	ah,WILL			; host will use Go Aheads?
	jne	bwtnopt35		; ne = no
	cmp	sgaflg,0		; doing SGAs?
	jne	bwtnopt35		; ne = no
	mov	sgaflg,0		; change to doing them
	mov	ah,DO
	call	bwsendiac
bwtnopt35:jmp	bwtnopt

bwtnopt40:cmp	ah,WILL			; all other Options
	jne	bwtnopt41		; ne = no
	mov	ah,DONT			; say do not
	call	bwsendiac		; respond
	jmp	bwtnopt43		; continue
bwtnopt41:cmp	ah,DO
	jne	bwtnopt42
	mov	ah,WONT			; say we won't
	call	bwsendiac
	mov	ah,DONT			; and host should not either
	call	bwsendiac
	jmp	bwtnopt43		; continue
bwtnopt42:cmp	ah,DONT
	jne	bwtnopt43
	mov	ah,WONT			; say we won't
	call	bwsendiac
bwtnopt43:jmp	bwtnopt			; continue
bwtnopt endp

; Beame & Whiteside, send IAC byte1 byte2, where byte 1 is in AH
; and byte 2 is in option2
bwsendiac proc	near
	push	cx
	push	si
	push	ax
	mov	ah,IAC			; send IAC
	call	outchr
	pop	ax			; send command byte
	call	outchr
	mov	ah,option2		; send response byte
	call	outchr
	pop	si
	pop	cx
	ret
bwsendiac endp

; Update local-echo status from B&W Telnet Options negotiations
; Enter with BL = 0 or lclecho, to clear or set local-echo
setecho	proc	near
	and	yflags,not lclecho	; assume no local echo in emulator
	or	yflags,bl		; set terminal emulator
	push	si
	mov	si,portval
	mov	[si].ecoflg,bl		; set mainline SET echo flag
	pop	si
ifndef	no_terminal
	cmp	ttyact,0		; acting as a Terminal?
	je	setecho1		; e = no
	push	cx
	push	si
	call	dword ptr ftogmod	; toggle mode line
	call	dword ptr ftogmod	; and again
	pop	si
	pop	cx
endif	; no_terminal
setecho1:ret
setecho	endp
endif	; no_network

; Put the char in AH to the serial port, assumimg the port is active.
; Returns carry clear if success, else carry set.
; 16 May 1987 Add entry point OUTCH2 for non-flow controlled sending to
; prevent confusion of flow control logic at top of outchr; used by receiver
; buffer high/low water mark flow control code. [jrd]
outchr	proc	near
	cmp	quechar,0		; char queued for transmission?
	je	outch0			; e = no, no XOFF queued
	xchg	ah,quechar		; save current char
	cmp	ah,flowoff		; really XOFF?
	jne	outch0a			; ne = no
	mov	xofsnt,bufon	   	; we are senting XOFF at buffer level
outch0a:call	outch2			; send queued char (XOFF usually)
	xor	ah,ah			; replacement for queued char, none
	xchg	ah,quechar		; recover current char, send it
outch0:	test	flowcnt,1		; doing output XON/XOFF flow control?
	jz	outch2			; z = no, just continue
	cmp	ah,flowoff		; sending xoff?
	jne	outch1			; ne = no
	mov	xofsnt,usron		; indicate user level xoff being sent
	jmp	short outch1b
outch1:	and	xofsnt,not usron	; cancel user level xoff
	cmp	ah,flowon		; user sending xon?
	jne	outch1b			; ne = no
	mov	xofsnt,off	     ; say an xon has been sent (cancels xoff)
outch1b:cmp	xofrcv,off		; are we being held (xoff received)?
	je	outch2			; e = no - it's OK to go on
	push	cx			; save reg
	mov	ch,15			; 15 sec timeout interval
	xor	cl,cl			;  convert to 4 millsec increments

outch1a:cmp	xofrcv,off		; are we being held (xoff received)?
	je	outch1c			; e = no - it's OK to go on
	push	ax
	mov	ax,4			; 4 millisec wait loop
	call	pcwait
	pop	ax
	loop	outch1a			; and try it again
	mov	xofrcv,off		; timed out, force it off
	cmp	ttyact,0		; in Connect mode?
	je	outch1c			; e = no
	push	ax			; save char around the call
	call	beep			; let user know we are xoff-ed
	pop	ax			;  but are sending anyway
outch1c:pop	cx			; end of flow control section
		     ; OUTCH2 is entry point for sending without flow control
OUTCH2:	mov	al,ah			; Parity routine works on AL
	call	dopar			; Set parity appropriately
	mov	ah,al			; Don't overwrite character with status
	cmp	repflg,0		; doing REPLAY from a file?
	je	outch3			; e = no
	and	al,7fh			; strip parity
	cmp	al,'C'-40h		; Control-C? (to exit playback mode)
	je	outch2a			; e = yes, return failure
	clc				; return success, send nothing
	ret
outch2a:stc				; failure, to exit playback mode
	ret
outch3:	push	bx
	mov	bx,portval		; output char is in register AH
	call	[bx].sndproc		; output processing routine
	pop	bx
	ret
outchr	endp

uartsnd	proc	near			; UART send
	push	cx
	push	dx
	push	bx
	mov	bx,portval
	cmp	[bx].portrdy,0		; is port ready?
	pop	bx
	je	uartsn8			; e = no
	cmp	flags.carrier,0		; worry about carrier detect?
	je	uartsn9a		; e = no
	cmp	dupflg,0		; full duplex?
	jne	uartsn1			; ne = no, half
	mov	dx,modem.mddat
	add	dx,6			; modem status reg 3feh
	in	al,dx			; 03feh, modem status reg
	and	al,80h			; get CD bit
	jnz	uartsn9			; nz = CD is on now
	test	cardet,80h		; previous CD state
	jz	uartsn9			; z = was off
	mov	al,01h			; say was ON but is now OFF
	mov	flags.cxzflg,'C'	; simulate Control-C interrupt
uartsn9:mov	cardet,al		; preserve as global
	cmp	al,1			; carrier dropped?
	je	uartsn8			; e = yes, fail the operation

uartsn9a:test	flowcnt,4		; using RTS to control incoming chars?
	jz	uartsn3			; z = no
	mov	cx,8000			; ~10 seconds worth of waiting on CTS
	jmp	short uartsn2		; do CTS test/waiting
					; Half Duplex here
uartsn1:mov	dx,modem.mdstat		; 3fdh
	dec	dx
	in	al,dx			; modem control reg 3fch
	or	al,2			; assert RTS for hardware transmit
	push	ax
	in	al,ppi_port		; delay
	pop	ax
	mov	dx,modem.mdstat		; 3fdh, waste cycles here
	dec	dx			; 3fch
	out	dx,al
	add	dx,2			; modem status register 3feh
	in	al,ppi_port		; delay
	in	al,ppi_port		; delay
	in	al,dx			; get DSR status
	test	al,20h			; ignore CTS if DSR is not asserted
	jz	uartsn3			; z = DSR not asserted
	mov	cx,8000			; ~10 seconds worth of waiting on CTS
					; Half Duplex and RTS/CTS flow cont.
uartsn2:mov	dx,modem.mdstat		; 3fdh
	inc	dx			; 3feh
	in	al,dx			; wait on CTS (ah has output char)
	test	al,10h			; is CTS asserted? (dx = 3feh)
	jnz	uartsn3			; nz = yes
	push	ax			; preserve char in ah
	mov	ax,1			; wait one millisec
	call	pcwait
	pop	ax
	loop	uartsn2			; test again
	push	ax
	call	beep			; timeout, make non-fatal
	pop	ax			; continue to send the char
	cmp	dupflg,0		; half duplex?
	jne	uartsn8			; ne = yes, fail at this point
uartsn3:push	bx
	mov	bx,portval
	cmp	[bx].baud,Bsplit	; split-speed mode?
	pop	bx
	jne	uartsn4			; ne = no
	mov     al,ah                   ; [pslms]
        call    out75b			; do split speed sending at 75 baud
        pop     dx
        pop     cx
	ret				; out75b sets/clears carry bit

uartsn4:mov	cx,0ffffh		; try counter
uartsn4a:mov	dx,modem.mdstat		; get line status
	in	al,dx
	test	al,20H			; Transmitter (THRE) ready?
	jnz	uartsn5			; nz = yes
	in	al,ppi_port		; delay
	in	al,ppi_port		; delay
	in	al,ppi_port		; delay
	loop	uartsn4a
	jmp	short uartsn8		; Timeout
uartsn5:mov	al,ah			; Now send it out
	mov	dx,modem.mddat		; use a little time
	push	ax
	in	al,ppi_port		; delay
	pop	ax
	out	dx,al
	cmp	dupflg,0		; full duplex?
	je	uartsn7			; e = yes
		  			; half duplex
	cmp	al,trans.seol		; End of Line char?
	jne	uartsn7			; ne = no
	xor	cx,cx			; loop counter
uartsn6:mov	dx,modem.mdstat		; modem line status reg
	in	al,dx			; read transmitter shift reg empty bit
	push	ax
	in	al,ppi_port		; delay, wait for char to be sent
	in	al,ppi_port
	in	al,ppi_port
	in	al,ppi_port
	pop	ax
	test	al,40h			; is it empty?
	loopz	uartsn6			; z = no, not yet
	mov	dx,modem.mdstat
	dec	dx			; modem control reg 3fch
	in	al,dx
	and	al,not 2		; unassert RTS (half duplex turn)
	push	ax
	in	al,ppi_port		; delay
	pop	ax
	out	dx,al
uartsn7:pop	dx			; exit success
	pop	cx
	clc
	ret
uartsn8:call	beep
	mov	kbdflg,'C'		; exit connect mode
	pop	dx			; exit failure
	pop	cx
	stc
	ret
uartsnd	endp

biossnd	proc	near			; Bios send
	push	cx			; find current port
	mov	cx,5			; retry counter
	push	dx
	xor	dh,dh			; assume port 1
	mov	dl,flags.comflg		; get port number (1..4)
	or	dl,dl			; zero (no such port)?
	jz	biossn3			; z = yes, don't access it
	and	dl,7			; use lower three bits
	dec	dl			; address ports as 0..3 for Bios
	mov	al,ah			; now send it out
biossn2:push	ax			; save char
	mov	ah,1			; send char
	int	rs232			; bios send
	shl	ah,1			; set carry if failure
	pop	ax			; recover char
	jnc	biossn4			; nc = success
	push	ax
	mov	ax,60			; wait 60 ms
	call	pcwait			; this must preserve cx and dx
	pop	ax			; recover char
	loop	biossn2			; try again
biossn3:push	bx
	mov	bx,portval
	mov	[bx].portrdy,0		; say port is not ready
	pop	bx
	mov	kbdflg,'C'		; exit Connect mode
	stc				; fail through here
biossn4:pop	dx
	pop	cx
	ret				; c set = failure, else success
biossnd	endp

; Fossil block send
fossnd	proc	near
	mov	bx,xmtcnt		; count of chars in buffer
	mov	xmtbufx[bx],ah		; put char in buffer
	inc	xmtcnt			; count of items in this buffer
	and	ah,7fh			; strip parity
	cmp	xmtcnt,length xmtbuf	; is buffer full now?
	jae	fossnd2			; ae = buffer is full, send it now
	cmp	ah,trans.seol		; end of packet?
	je	fossnd2			; e = yes, send buffer
	test	flowcnt,1		; using output XON/XOFF flow control?
	jz	fossnd1			; z = no
	cmp	ah,flowon		; flow control?
	je	fossnd2			; e = yes, always expedite
	cmp	ah,flowoff		; ditto for flow off
	je	fossnd2
fossnd1:cmp	ttyact,0		; are we in Connect mode?
	jne	fossnd2			; ne = yes, send now
	clc				; e = no, wait for more before sending
	ret
fossnd2:push	es
	push	di
	mov	di,seg xmtbufx
	mov	es,di
	mov	di,offset xmtbufx
fossnd3:cmp	xmtcnt,0		; buffer count
	jle	fossnd4			; le = nothing to send
	mov	ah,fossil_blkwr		; Fossil send block
	xor	al,al
	mov	dx,fossil_port		; port
	mov	cx,xmtcnt		; count
	int	rs232			; block send
	jc	fossnd5			; c = error
	cmp	ax,0ffffh		; error condition?
	je	fossnd5			; e = yes
	cmp	ax,fossil_blkwr*256	; complete no-op?
	je	fossnd5			; e = yes
	add	di,ax			; move buffer pointer
	sub	xmtcnt,ax		; minus count sent
	jnz	fossnd3			; nz = have some more to send
fossnd4:pop	di
	pop	es
	clc
	ret
fossnd5:pop	di
	pop	es
	call	serrst			; close port
	mov	kbdflg,'C'		; exit Connect mode
	stc				; say not returning char in al here
	ret
fossnd	endp

ifndef	no_network
ebisnd	proc	near			; EBIOS block send
	mov	bx,xmtcnt		; count of chars in buffer
	mov	xmtbufx[bx],ah		; put char in buffer
	inc	xmtcnt			; count of items in this buffer
	and	ah,7fh			; strip parity
	cmp	xmtcnt,length xmtbuf	; is buffer full now?
	jae	ebisnd2			; ae = buffer is full, send it now
	cmp	ah,trans.seol		; end of packet?
	je	ebisnd2			; e = yes, send buffer
	test	flowcnt,1		; using output XON/XOFF flow control?
	jz	ebisnd1			; z = no
	cmp	ah,flowon		; flow control?
	je	ebisnd2			; e = yes, always expedite
	cmp	ah,flowoff		; ditto for flow off
	je	ebisnd2
ebisnd1:cmp	ttyact,0		; are we in Connect mode?
	jne	ebisnd2			; ne = yes, send now
	clc				; e = no, wait for more before sending
	ret
ebisnd2:push	si
	mov	si,offset xmtbufx
ebisnd3:cmp	xmtcnt,0		; buffer count
	jle	ebisnd4			; le = nothing to send
	cld
	lodsb				; read next byte from buffer
	push	si
	mov	ah,ebsend		; EBIOS send char in AL
	mov	dx,ebport		; port 0..3, do here to waste time
	int	rs232			; bios send
	pop	si
	shl	ah,1			; put status high bit into carry
	jc	ebisnd4			; c = failure
	dec	xmtcnt
	jmp	short ebisnd3
ebisnd4:pop	si
	ret				; c set = failure, else success
ebisnd	endp

decsnd	proc	near			; DECnet/LAT send processor
	test	nettype,declat		; LAT?
	jz	decsnd3			; z = no, use CTERM
decsnd1:mov	dx,lathand		; LAT handle
	or	dx,dx			; legal handle?
	jz	decsnd4			; z = invalid handle
	call	latblksnd		; send char in ah, and buffer
	jc	decsnd4			; c = failure
	ret

decsnd3:mov	dx,decneth		; DECnet, handle
	or	dx,dx			; legal handle?
	jz	decsnd4			; z = invalid handle
	mov	bl,ah			; CTERM char to be sent
	mov	ax,dsend		; send byte in bl
	int	decint
	rcl	ah,1			; status 80h bit, did char get sent?
	jc	decsnd4			; c = failure
	ret
decsnd4:call	decclose		; failure, close connection
	stc
	ret
decsnd	endp

; Special block sending routine for LAT (all vendors)
; DEC's LAT breaks if we send too much at one time, TES LAT breaks much
; more readily, and MTC LAT tolerates the longest bursts. None works
; without a breathing space between block sends which don't fully
; send the block. TES LAT does not support callbacks. We arbitarily
; limit a buffer to 78 bytes to survive the various LAT troubles on
; both ends of the link. Putting DEC's LAT v4.1 in expanded memory
; under DOS 6.2 and NetWare VLM 1.1 shells causes lockups.
; Variable "temp" is borrowed as a retry counter.
latblksnd proc	near
	mov	bx,xmtcnt		; count of chars in buffer
	mov	xmtbufx[bx],ah		; put char in buffer
	inc	xmtcnt			; count of items in this buffer
	cmp	xmtcnt,78		; is buffer full now?
	jae	latsnd2			; ae = buffer is full, send it now
	and	ah,7fh			; strip parity
	cmp	ah,trans.seol		; end of packet?
	je	latsnd2			; e = yes, send buffer
	test	flowcnt,1		; using output XON/XOFF flow control?
	jz	latsnd1			; z = no
	cmp	ah,flowon		; flow control?
	je	latsnd2			; e = yes, always expedite
	cmp	ah,flowoff		; ditto for flow off
	je	latsnd2
latsnd1:cmp	ttyact,0		; are we in Connect mode?
	jne	latsnd2			; ne = yes, send now
	xor	ah,ah
	clc				; e = no, wait for more before sending
	ret

latsnd2:push	bx
	mov	bx,offset xmtbufx
	mov	temp,0			; retry counter
	mov	temp2,10		; ms time wait when not enough space
	cmp	latkind,TES_LAT		; TES?
	jne	latsnd3			; ne = no
	mov	temp2,2*55		; slower for TES

latsnd3:cmp	xmtcnt,0		; buffer count
	jle	latsnd8			; le = nothing to send
	mov	dx,lathand
	mov	ah,latstat		; get status
	int	latint
	test	ah,4			; session is inactive?
	jz	latsnd5			; z = no
	pop	bx
	stc				; inactive, exit failure
	ret

latsnd5:mov	cx,xmtcnt		; amount to be sent
	cmp	cx,78			; apply limits to fragile LATs
	jbe	latsnd7			; be = in bounds
	mov	cx,78			; so they do not mess up
latsnd7:push	es
	push	bx
	mov	ax,seg xmtbufx
	mov	es,ax			; es:bx is send buffer
	mov	ah,latsendb		; send block
	mov	dx,lathand
	int	latint
	pop	bx
	pop	es
	add	bx,cx			; move to next new output byte
	sub	xmtcnt,cx		; deduct chars sent
	jle	latsnd8			; le = all done
	or	cx,cx			; any chars accepted?
	jnz	latsnd7a		; nz = yes
	inc	temp			; retry counter
	cmp	temp,10			; exhausted retries?
	jbe	latsnd7b		; be = no
	call	decclose		; failure, close connection
	pop	bx
	stc
	ret
latsnd7a:mov	temp,0			; reset retry counter 
latsnd7b:push	bx
	mov	ax,temp2		; retry timeout
	add	temp2,ax		; new timeout (longer)
	cmp	latkind,TES_LAT		; TES LAT?
	jne	latsnd7c		; ne = no
	add	ax,100			; slower for TES
latsnd7c:inc	ax			; zero avoidance
	call	pcwait			; pause
	call	decrcv			; do a receive to clear LAT driver
	pop	bx
	jmp	latsnd3			; continue sending remainder

latsnd8:pop	bx
	clc				; exit success
	ret
latblksnd endp
endif	; no_network

; Software uart that generates output rate of 75 baud independently of
; 8250 baudrate; use with V.23 split speed modems.
; This routine outputs a character in 8,<parity>,1 format only.
; To generate good bit timing, latency is to be kept low; now set for max
; 12% bit distortion and 1.2% speed deviation (about the same as the input
; stage of a HW-uart), which requires latency < 3ms (i e the same as 8250
;  requires for receive in 9600 baud)
; Creator Dan Norstedt 1987. Implemented 18 Feb 1988 by [pslms].
out75b	proc	near
	mov	timeract,1	; say we are allocating the timer chip
	push	cx
	push	dx
	xchg	ax,bx		; save char to output
	mov	bh,1		; prepare output char
	mov	cx,cnt75b	; maximum end count
out75b1:call    read_timer2	; save previous end count in CX, read timer
				;  test for timer still decrementing ?
        jb	out75b1		; b = yes, wait (for a maximum of 1 bit)
        mov	al,0b4h		; set up counter 2 to mode 2, load LSB+MSB
        out	timercmd,al	; set mode 2 = rate generator
        jmp	$+2
        mov	ax,(cnt75b*4+cnt75b*4+cnt75b*2-precomp) AND 0ffffh  ; set start point
        out	timer2data,al	; output LSB
        jmp	$+2
        xchg	cx,ax		; save value in CX for compare in READ_TIMER2
        mov	al,ch		; output MSB
        cli			; timer starts counting on next instr, make
        out	timer2data,al	;  sure it's not to far of from start bit
        in 	al,ppi_port	; get Port B contents
        jmp	$+2
        and	al,0fch		; mask speaker and gate 2 bits
        inc	ax
        out	ppi_port,al	; set speaker off and gate 2 on
        mov	al,-1
        out	timer2data,al	; set counter wraparound to 0FFFFH
        jmp	$+2
        out	timer2data,al
        mov	bp,(cnt75b*4+cnt75b*4+cnt75b) AND 0ffffh ; set timer value for next bit
        mov	dx,modem.mddat	; get com port address
        add	dx,3		; address of it's line control register
        in 	al,dx		; get port status
        jmp	$+2
out75b2:or	al,brkbit	; set line to space (by using break bit)
out75b3:out	dx,al		; once start bit is out, we may reenable
        sti			;  without getting extra jitter
out75b4:call	read_timer2
	jns	out75b5		; ns = timer doesn't seem to run
	cmp	ax,bp		; time for next bit?
	jns	out75b4		; ns = no, wait
	sub	bp,cnt75b	; yes, step time to next event
	in 	al,dx		; get line control register
	and	al,0bfh		; remove break bit
	shr	bx,1		; carry for mark bit, none for space
	jnc	out75b2		; nc = it was a space (we know BX is non-zero)
	jnz	out75b3		; mark, and not the last one
	jmp	$+2
	out	dx,al		; last, start to send stop bit
	pop	dx
	pop	cx
	mov	timeract,0	; say we are finished with the timer chip
	cmp	quechar,0	; any char queued to be sent?
	je	out75b6		; e = no
	call	outchr		; yes, send it now
out75b6:clc
	ret
out75b5:in	al,dx		; timer doesn't function properly,
	and	al,0bfh		;  restore com port and return error
	out	dx,al
	mov	timeract,0	; say we are finished with the timer chip
	pop	dx
	pop	cx
	stc
        ret
out75b	endp
     
read_timer2	proc	near
	mov     al,80h          ; Freeze timer 2
	out     timercmd,al
	jmp     $+2
	in      al,timer2data   ; Get LSB
	jmp     $+2
	mov     ah,al
	in      al,timer2data   ; Get MSB
	xchg    al,ah           ; Get LSB and MSB right
	cmp     ax,cx           ; Compare to previous sample
	mov     cx,ax           ; Replace previous sample with current
	ret
read_timer2 endp

ifndef	no_network
; NetBios Send packet routine. Send xmt scb with no-wait option. Waits
; up to 6 seconds for current Send to complete before emitting new Send.
; Failure to Send resets serial port (Server mode allows reiniting of serial
; port). Returns carry clear for success, carry set for failure.
; Enter with xmtcnt holding length of data in xmtbuf to be sent.
SEND	PROC	NEAR			; Network. Send session packet
	mov	bx,xmtcnt		; count of chars in buffer
	test	nettype,acsi		; ACSI?
	jz	send32			; z = no
	or	bx,bx			; at start of buffer?
	jnz	send31			; nz = no
	mov	bx,2			; include internal count word
	mov	word ptr xmtbufx,bx
	mov	xmtcnt,bx
send31:	mov	xmtbufx[bx+1],0		; status
	inc	xmtcnt
	add	word ptr xmtbufx,2	; internal count word
send32:
	mov	xmtbufx[bx],ah		; put char in buffer
	inc	xmtcnt			; count of items in this buffer
	and	ah,7fh			; strip parity
	cmp	xmtcnt,length xmtbuf	; is buffer full now?
	jae	send22			; ae = buffer is full, send it now
	test	nettype,acsi		; ACSI?
	jz	send33			; z = no
	cmp	xmtcnt,512		; ACSI has hard 512 byte limit
	jb	send33			; b = not full yet
	mov	xmtcnt,512		; limit buffer
	jmp	short send22		; send only this buffer
send33:	cmp	ah,trans.seol		; end of packet?
	je	send22			; e = yes, send buffer
	test	flowcnt,1		; using output XON/XOFF flow control?
	jz	send21			; z = no
	cmp	ah,flowon		; flow control?
	je	send22			; e = yes, always expedite
	cmp	ah,flowoff		; ditto for flow off
	je	send22
send21:cmp	ttyact,0		; are we in Connect mode?
	jne	send22			; ne = yes, send now
	clc				; e = no, wait for more before sending
	ret
send22:	cmp	pcnet,1			; network ready yet?
	ja	send0b			; a = net is operational
	je	send0c			; e = net but no session, fail
	jmp	send3b			; no net, fail
send0c:	jmp	send3			; net but no session
send0b:	cmp	sposted,0		; is a send outstanding now?
	je	send1			; e = no, go ahead
	push	cx			; Timed test for old send being done
	mov	ch,trans.rtime		; receive timeout other side wants
	mov	cl,80h			; plus half a second
	shl	cx,1			; sending timeout * 512
send0:	cmp	sposted,0		; is a send outstanding now?
	je	send0a			; e = no, clean up and do send
	push	cx			; save cx
	push	ax			; and ax
	mov	ax,2			; wait 2 milliseconds
	call	pcwait			;  between retests
	pop	ax
	pop	cx			; loop counter
	loop	send0			; repeat test
	pop	cx			; recover cx
	jmp	send3b			; get here on timeout, can't send
send0a:	pop	cx			; recover cx and proceed to send

send1:	cmp	xmtcnt,0		; number of items to send
	jne	send1a			; ne = some
	clc				; else don't send null packets
	ret
send1a:	push	cx			; save these regs
	push	si
	push	di
	push	es
	push	ds
	pop	es			; set es to data segment
	mov	si,offset xmtbufx	; external buffer
	mov	di,offset xmtbuf	; copy for network packets
	mov	cx,xmtcnt		; buffer length
	mov	xmt.scb_length,cx	; tell buffer length
	shr	cx,1			; divide by two (words), set carry
	jnc	send2			; nc = even number of bytes
	movsb				; do single move
send2:	rep	movsw			; copy the data
	pop	es
	pop	di
	pop	si
	pop	cx
	mov	xmtcnt,0		; say xmtbufx is available again
	mov	xmt.scb_cmd,nsend+nowait ; send, don't wait for completion
	mov	sposted,1		; say send posted
	mov	bx,offset xmt		; set pointer to scb
	call	nbsession
					; success or failure?
	cmp	xmt.scb_err,0		; good return?
	je	send4			; e = yes
	cmp	xmt.scb_err,npending	; pending?
	je	send4			; e = yes
	cmp	xmt.scb_err,18h		; session ended abnormally?
	jbe	send3			; e = yes, b = other normal errors
	push	ax
	push	dx			; another kind of error, show message
	mov	ah,prstr
	mov	dx,offset sndmsg	; say send failed
	int	dos
	mov	al,xmt.scb_err		; show error code
	call	decout
	pop	dx
	pop	ax
					; Error return
send3:	mov	pcnet,1			; say session is broken
	call	serrst			; reset serial port
	cmp	lposted,1		; Listen posted?
	je	receiv3a		; e = yes, stay alive
	cmp	xmt.scb_rname,'*'	; behaving as a Listner?
	je	receiv3a		; e = yes, stay alive
	cmp	lposted,1		; Listen posted?
	je	send3a			; e = yes, stay alive
	cmp	xmt.scb_rname,'*'	; behaving as a Listner?
	je	send3a			; e = yes, stay alive
	test	flags.remflg,dserver	; server mode?
	jz	send3b			; z = no
send3a:	call	nbclose			; Server: purge old NAKs etc
	call	serini			; reinitialize it for new session
send3b:	stc				; set carry for failure to send
	ret
send4:	clc
	ret
SEND	ENDP

; NetBios Send packet completion interrupt routine. At entry CS is our
; code segment, es:bx points to scb, netbios stack, interrupts are off.
SPOST	PROC	NEAR			; post routine for Send packets
	push	ds
	push	ax
	mov	ax,data
	mov	ds,ax
	mov	sposted,0		; clear send interlock
	pop	ax
	pop	ds
	iret
SPOST	ENDP	

; TES block send. Destroys BX
TESSND	proc	near
	mov	bx,xmtcnt		; count of chars in buffer
	mov	xmtbufx[bx],ah		; put char in buffer
	inc	xmtcnt			; count of items in this buffer
	and	ah,7fh			; strip parity
	cmp	xmtcnt,length xmtbuf	; is buffer full now?
	jae	tessen22		; ae = buffer is full, send it now
	cmp	ah,trans.seol		; end of packet?
	je	tessen22		; e = yes, send buffer
	test	flowcnt,1		; using output XON/XOFF flow control?
	jz	tessen21		; z = no
	cmp	ah,flowon		; flow control?
	je	tessen22		; e = yes, always expedite
	cmp	ah,flowoff		; ditto for flow off
	je	tessen22
tessen21:cmp	ttyact,0		; are we in Connect mode?
	jne	tessen22		; ne = yes, send now
	clc				; e = no, wait for more before sending
	ret

tessen22:push	ax
	push	cx
	push	dx
	push	di
	push	es
	mov	cx,xmtcnt		; number of chars
	jcxz	tessnd4			; don't send zero chars
	mov	di,offset xmtbufx	; buffer address in es:di
	mov	ax,data
	mov	es,ax
tessnd1:mov	temp,0			; retry counter
tessnd2:mov	ah,tesbwrite		; block write
	mov	dx,tesport		; operational port
	int	rs232
	or	ax,ax			; number of chars sent, zero?
	jnz	tessnd3			; nz = sent some
	mov	ax,10			; wait 10ms
	call	pcwait
	inc	temp			; count retry
	cmp	temp,5			; done all retries?
	jb	tessnd2			; b = no
	call	tesclose		; close sessioin, declare failure
	stc
	jmp	short tessnd5		; exit failure

tessnd3:cmp	ax,cx			; check that all characters were sent
	je	tessnd4			; e = yes
	add	di,ax			; point to remaining chars
	sub	cx,ax			; count of remaining characters
	mov	xmtcnt,cx		; need count in xmtcnt too
	jmp	short tessnd1		; try again to send
tessnd4:clc				; success, need failure case too
tessnd5:mov	xmtcnt,0
	pop	es
	pop	di
	pop	dx
	pop	cx
	pop	ax
	ret
TESSND	endp

; Block send routine shared by many networks.
; Enter with char to be sent in AH. Destroys BX.
ubsend	proc	near
	mov	bx,xmtcnt		; count of chars in buffer
	mov	xmtbufx[bx],ah		; put char in buffer
	inc	xmtcnt			; count of items in this buffer
	and	ah,parmsk		; strip parity
ifndef	no_tcp
	test	nettype,tcpnet		; TCP/IP Telnet?
	jz	ubsen24			; z = no
	cmp	ah,CR			; carriage return?
	jne	ubsen24			; ne = no
	cmp	xmtcnt,length xmtbufx	; is buffer full?
	jb	ubsen22			; b = no, else take special setps
	call	ubsen28			; send what we have now
ubsen22:cmp	ttyact,0		; in terminal emulation mode?
	je	ubsen22a		; e = no, use CR NUL
	cmp	tcpnewline,2		; newline is RAW?
	je	ubsen24			; e = yes, no special steps
	mov	bx,xmtcnt
	mov	al,LF			; CR -> CR/LF
	cmp	tcpnewline,0		; newline mode is off?
	jne	ubsend23		; ne = no, send CR/LF
	cmp	tcpmode,0		; NVT-ASCII? (binary is mode 1)
	jne	ubsen28			; ne = no, Binary, no CR NUL
ubsen22a:xor	al,al			; CR -> CR NUL
ubsend23:mov	xmtbufx[bx],al		; append this char
	inc	xmtcnt
	jmp	short ubsen28		; send buffer now
endif	; no_tcp

ubsen24:cmp	xmtcnt,length xmtbufx	; is buffer full now?
	jae	ubsen28			; ae = buffer is full, send it now
	cmp	ah,trans.seol		; end of packet?
	je	ubsen28			; e = yes, send buffer
	test	flowcnt,1		; using output XON/XOFF flow control?
	jz	ubsen25			; z = no
	cmp	ah,flowon		; flow control?
	je	ubsen28			; e = yes, always expedite
	cmp	ah,flowoff		; ditto for flow off
	je	ubsen28
ubsen25:cmp	ttyact,0		; are we in Connect mode?
	jne	ubsen28			; ne = yes, send now
	clc				; e = no, wait for more before sending
	ret
ubsen28:push	ax
	push	cx
	push	es
	mov	cx,xmtcnt		; number of chars
	or	cx,cx
	jnz	ubsen29			; nz = have something to send
	jmp	ubsend1			; z = nothing to send
ubsen29:mov	temp,200		; retry counter for can't send
	mov	bx,offset xmtbufx	; buffer address in es:bx
ubsend2:mov	ax,seg xmtbuf
	mov	es,ax
	test	nettype,bapi+tcpnet	; 3Com BAPI or TCP Telnet?
	jz	ubsend2a		; z = no
	mov	ah,bapiwrit		; 3Com block write
	xor	dh,dh			; session 0
ifndef	no_tcp
	test	nettype,tcpnet		; TCP/IP Telnet?
	jz	ubsend2d		; z = no
	push	bx
	call	ktcpcom			; Far call TCP/IP Telnet code
	pop	bx
	jmp	short ubsend2e
endif	; no_tcp
ubsend2d:int	bapiint
ubsend2e:cmp	ah,3			; status, no session and above
	jae	ubsend2b		; ae = no session and above, fail
	jmp	short ubsend3		; process data

ubsend2a:test	nettype,telapi		; Novell TELAPI?
	jz	ubsend2c		; z = no, Int 6Bh kind
	push	si
	push	bx			; preserve buffer offset
	mov	si,bx			; use es:si for buffer address
	mov	ah,telwrite
	mov	bx,telses		; session number
	int	rs232
	pop	bx
	pop	si
	mov	cx,ax			; TELAPI returns sent count in AX
	or	ax,ax			; error response (sign bit set)?
	jns	ubsend3			; ns = no error

ubsend2b:call	ubclose			; failure, close the connection
	pop	es
	pop	cx
	pop	ax
	stc				; failure
	ret

ubsend2c:test	nettype,netone		; UB?
	jz	ubsend1			; no, do nothing
	mov	ax, nciwrit		; write function, port 0	 [ohl]
	int	netci

ubsend3:cmp	cx,xmtcnt		; check that all characters sent [ohl]
	je	ubsend1			; e = yes			 [ohl]
	add	bx,cx			; point to remaining chars	 [ohl]
	sub	xmtcnt,cx		; count of remaining characters	 [ohl]
	cmp	count,0			; any bytes received?
	jne	ubsend3b		; ne = yes
	push	bx
	mov	bx,portval
	call	[bx].rcvproc		; read routine
	pop	bx			; fall through to grab new char
ubsend3b:cmp	flags.cxzflg,'C'	; user abort?
	je	ubsend3c		; e = yes
	test	nettype,tcpnet		; TCP/IP Telnet?
	jnz	ubsend3a		; nz = yes
	mov	ax,15			; 15 millisec pause between retries
	call	pcwait
	dec	temp			; retry counter
	jnz	ubsend3a		; nz = some retries remaining
ubsend3c:pop	es
	pop	cx
	pop	ax
	stc				; fail but do not close port
	ret

ubsend3a:mov	cx,xmtcnt		; need count in cx too
	jmp	ubsend2			; try again to send		 [ohl]
ubsend1:mov	xmtcnt,0
	pop	es
	pop	cx
	pop	ax
	clc				; success, need failure case too
	ret
ubsend	endp
code	ends

code1	segment
	assume cs:code1

; Send blocks of bytes
; Enter with pointer to data in es:bx, length cx bytes
sndblk	proc	far
	or	cx,cx			; any bytes?
	jnz	sndblk1			; nz = yes
	clc
	ret
sndblk1:cmp	flags.comflg,'t'	; internal Telnet?
	je	sndblk1a		; e = yes, send blocks
	call	sendone			; send one byte at a time
	ret
sndblk1a:
	push	bx
	mov	di,xmtcnt		; where next byte goes
	xor	al,al
	xchg	al,ttyact		; tty vs block mode, set to block
	push	ax			; save for exit
sndblk2:cmp	di,length xmtbufx	; is buffer full?
	jb	sndblk3			; b = no
	call	sndbwrt			; triggers send from ubsend
	jnc	sndblk3			; nc = success
	pop	ax
	xchg	al,ttyact
	pop	bx
	ret
sndblk3:mov	ah,es:[bx]		; read a source byte
	inc	bx
	mov	xmtbufx[di],ah		; store it in output buffer
	inc	di
	cmp	ah,trans.seol		; packet end of line?
	jne	sndblk4			; e = yes, flushes ubsend buffer
	call	sndbwrt			; write to ubsend
	jnc	sndblk7
	pop	ax
	xchg	al,ttyact
	pop	bx
	ret
sndblk4:cmp	ah,CR			; carriage return?
	jne	sndblk5			; ne = no
	xor	ah,ah			; NULL
	jmp	short sndblk6		; insert the null
sndblk5:cmp	ah,255			; IAC
	jne	sndblk7			; ne = no, else send it twice
sndblk6:mov	xmtbufx[di],ah		; send extra char
	inc	di
sndblk7:loop	sndblk2
	mov 	xmtcnt,di		; update pointer upon exit
	pop	ax
	xchg	al,ttyact
	pop	bx
	clc
	ret
sndblk	endp
code1	ends

code	segment
	assume cs:code
sndbwrt proc	far			; worker for sndblk
	dec	di			; last byte written in buffer
	mov	xmtcnt,di		; tell ubsend the count
	mov	ah,xmtbufx[di]		; redo it
	push	cx			; write buffer xmtbufx, xmtcnt bytes
	push	bx
	push	es
	mov	bx,portval		; port in use
	call	[bx].sndproc		; flush buffer routine
	pop	es
	pop	bx
	pop	cx
	mov	di,xmtcnt		; restore local pointer
	ret
sndbwrt	endp

; Send blocks of bytes, one byte at a time
; Enter with pointer to data in es:bx, length cx bytes
sendone	proc	far
	push	bx			; preserve bx of caller
	jcxz	sndone2			; z = nothing to send
sndone1:mov	ah,es:[bx]
	inc	bx
	push	bx
	push	cx
	push	es
	call	outchr			; send byte in ah
	pop	es
	pop	cx
	pop	bx
	jc	sndone2			; c = failure exit
	loop	sndone1
	clc				; success
sndone2:pop	bx
	ret
sendone	endp

; Invoke internal TCP/IP NAWS Telnet Option when screen size changes
winupdate proc	far
ifndef	no_tcp
	test	nettype,tcpnet		; TCP/IP Telnet?
	jz	winupda1		; z = no
	push	es
	mov	ax,seg xmtbuf
	mov	es,ax
	mov	bx,offset xmtbufx	; buffer address in es:bx
	xor	cx,cx			; no data bytes to send
	mov	ah,bapinaws		; window size update request
	call	ktcpcom			; Far call TCP/IP Telnet code
	pop	es
	cmp	ah,3			; status, no session and above
	jae	winupda2		; ae = no session and above, fail
endif 	; no_tcp
winupda1:clc				; success
	ret
winupda2:call	ubclose			; failure, close the connection
	stc				; failure
	ret
winupdate endp

; Block send routine for Beame & Whiteside TCP
; Enter with char to be sent in AH. Destroys BX. [JRS]
bwsend	proc	near
	test	nettype,bwtcp		; active?
	jnz	bwsend0			; nz = yes
	stc
	ret
bwsend0:mov	bx,xmtcnt		; [JRS] count of chars in buffer
	mov	xmtbufx[bx],ah		; [JRS] put char in buffer
	inc	xmtcnt			; [JRS] count of items in this buffer
	and	ah,7fh			; [JRS] strip parity
	cmp	ah,CR			; [JRS] carriage return?
	jne	bwsend1			; [JRS] ne = no
	inc	bx			; [JRS]
	xor	al,al			; CR -> CR NUL
ifndef	no_tcp
	cmp	tcpnewline,0		; newline mode is off?
	je	bwsend0a		; e = yes
	mov	al,LF			; CR -> CR/LF
endif	; no_tcp
bwsend0a:call	dopar			; [JRS] apply parity
	mov	xmtbufx[bx],al		; [JRS] append this char
	inc	xmtcnt			; [JRS]
	jmp	short bwsend2		; [JRS]

bwsend1:cmp	ttyact,0		; [JRS] are we in Connect mode?
	jne	bwsend2			; [JRS] ne = yes, send now
	cmp	xmtcnt,length xmtbuf-1	; [JRS] is buffer full? (room for lf)
	jb	bwsend3			; [JRS] b = no, else take special step
bwsend2:mov	ah,40h			; [JRS] write to device
	mov	bx,bwhandle		; [JRS] device handle
	mov	cx,xmtcnt		; [JRS] number of bytes to write
	mov	dx,offset xmtbufx	; [JRS] data buffer
	int	dos			; [JRS] ask dos to send it
	jc	bwsend4			; c = failed
	mov	xmtcnt,0		; [JRS] clear the buffer
bwsend3:clc				; [JRS] e = no, wait for more
	ret
bwsend4:call	bwclose			; failed to send, quit
	stc
	ret
bwsend	endp

; Dispatch prebuilt NetBios session scb, enter with bx pointing to scb.
; Returns status in al (and ah too). Allows STARLAN Int 2ah for netint.
NBSESSION PROC	NEAR	
	push	es			; save es around call
	mov	ax,ds
	mov	es,ax			; make es:bx point to scb in data seg
	mov	ax,exnbios		; funct 4 execute netbios, for Int 2ah
	int	netint			; use NetBios interrupt
	pop	es			; saved registers
	ret				; exit with status in ax
NBSESSION ENDP

ifndef	no_tcp
; Start a TCP/IP Telnet session. Set nettype if successful.
; Uses sescur to determine new (-1) or old (0..MAXSESSIONS-1) session.
; Returns carry clear if success, else carry set.
tcpstart proc	near
	mov	bx,sescur		; current session index for seslist
	or	bx,bx			; non-negative means active
	jns	tcpstar1		; ns = active
	mov	decbuf,0		; ensure cmd line is cleared too
	mov	decbuf+80,0
	mov	decbuf+82,0
	call	sesmgr			; init a fresh session
	jnc	tcpstar0		; nc = success
	mov	kstatus,ksgen		; global status for unsuccess
	ret				; carry = failure
tcpstar0:mov	sescur,bx		; get its index
	jmp	short tcpstar2		; start fresh session
tcpstar1:mov	al,seslist[bx]		; get the state value
	xor	ah,ah
	or	al,al			; is session active now?
	jns	tcpstar3		; ns = yes, else start fresh session

tcpstar2:mov	vtinited,0		; MSY terminal emulation
ifndef	no_terminal
	mov	tekflg,0		; clear all graphics mode material
endif	; no_terminal
	mov	reset_clock,1		; new session, set port clock trigger
	call	clrclock		; clear elapsed time clock
	call	ktcpopen		; open a new TCP connection
	jmp	short tcpstar4		; check status in AX

tcpstar3:call	ktcpswap		; switch to Telnet session in AL
tcpstar4:or	al,al			; Telnet status, successful?
	jns	tcpstar5		; ns = yes
	jmp	tcpclose		; fail, close this failed session

					; started/swapped sessions ok
tcpstar5:mov	bx,sescur		; current session, local basis
	or	bx,bx			; must be 0..5 to be usable
	js	tcpstar6		; s = not usable
	mov	seslist[bx],al		; update local session mgr with status
	push	ax
	push	si
	push	di
	mov	al,seshostlen		; length of name fields
	mul	bl			; times number of entries
	add	ax,offset sesname
	mov	si,ax			; name of current host
	mov	di,offset tcphost	; update main table
	call	strcpy
	push	bx
	shl	bx,1			; address words
	mov	ax,sesport[bx]		; port
	mov	tcpport,ax		; tcp port
	pop	bx
	pop	di
	pop	si
	pop	ax
	mov	pcnet,2			; net open and going
	or	nettype,tcpnet		; say a session is active (ses = BL)
	clc				; success
	ret
tcpstar6:stc
	mov	kstatus,ksgen		; global status for unsuccess
	ret				; carry = failure
tcpstart endp

; Close/shutdown/terminate a TCP/IP Telnet session. Sescur is session
; number, -1 closes all sessions and TCP/IP.
tcpclose proc	near
	mov	ax,sescur
	or	ax,ax			; close active (>=0) or all (-1)?
	js	tcpclo1			; s = all (-1)
	mov	bx,ax
ifndef	no_terminal
	call	termswapdel		; delete term save block for ses BX
endif	; no_terminal
	mov	al,-1			; session closed marker
	xchg	al,seslist[bx]		; get tcpident from local list to AL
	or	al,al			; is this Telnet session active?
	jns	tcpclo1			; ns = yes, close it
	mov	cx,maxsessions		; number session slots
tcpclo0:cmp	seslist[bx],0		; session status, active?
	jge	tcpclo3a		; ge = yes, make this the active one
	inc	bx
	cmp	bx,maxsessions		; time to wrap?
	jb	tcpclo0a		; b = no
	xor	bx,bx			; wrap around
tcpclo0a:loop	tcpclo0
	jmp	short tcpclo4		; no active sessions, quit

tcpclo1:call	ktcpclose		; AL = close this particular session
	or	al,al			; status from ktcpclose
	jns	tcpclo3			; ns = have ses, -1 = no more sessions
	call	ktcpclose		; close TCP/IP as a whole after last
	and	nettype,not tcpnet	; clear activity flag
	mov	cx,maxsessions		; clear all local table entries
	xor	bx,bx
tcpclo2:mov	seslist[bx],-1		; status is inactive
ifndef	no_terminal
	push	ax
	call	termswapdel		; delete terminal save block
	pop	ax
endif	; no_terminal
	inc	bx
	loop	tcpclo2
	
tcpclo3:
;;TEST	cmp	ttyact,0		; are we in Connect mode?
;;TEST	je	tcpclo3b		; e = no, let session be closed

	call	tcptoses		; convert next tcp ident AL to sescur

tcpclo3a:mov	sescur,bx		; next new session
	or	bx,bx			; closing last session?
	js	tcpclo4			; s = yes, no more sessions
ifndef	no_terminal
	call	termswapin		; swap in next session's emulator
endif	; no_terminal
tcpclo3b:mov	portin,0		; reset the serial port for reiniting
	mov	port_tn.portrdy,0	; say the comms port is not ready
	mov	kbdflg,' '		; stay in connect mode
	stc
	ret
tcpclo4:mov	al,-1			; -1 means all sessions and network
	call	ktcpclose		; close the network
	call	serrst			; close the port
	mov	pcnet,0			; say no network
	and	nettype,not tcpnet
	mov	kbdflg,'C'		; quit connect mode
	stc
	ret
tcpclose endp
endif	; no_TCP

; Make a NetBios virtual circuit Session, given preset scb's from proc chknet.
; For Server mode, does a Listen to '*', otherwise does a Call to indicated
; remote node. Updates vcid number in scb's. Shows success or fail msg.
; Updates network status byte pcnet to 2 if session is established.
; Does nothing if a session is active upon entry; otherwise, does a network
; hangup first to clear old session material from adapter board. This is
; the second procedure to call in initializing the network for usage.
; If success nettype is set to netbios and return is carry clear; else 
; if failure nbclose is called to clean up connections and remove the nettype
; bit and return is carry set.
SETNET	PROC	NEAR			; NetBios, make a connection
	cmp	lposted,1		; Listen pending?
	je	setne0			; e = yes, exit now
	cmp	pcnet,1			; session active?
	jbe	setne1			; be = no
	clc
setne0:	ret
					; No Session
setne1:	cmp	xmt.scb_rname,'*'	; wild card?
	je	setne1a			; e = yes, do a Listen
	test	flags.remflg,dserver	; Server mode?
	jz	setne2			; z = no, file xfer or Connect
					; Server mode, post a Listen (async)
setne1a:mov	lsn.scb_rname,'*'	; accept anyone
	mov	ax,500
	call	pcwait			; 0.5 sec wait
	or	nettype,netbios		; set net type
	mov	lposted,1		; set listen interlock flag
	mov	lsn.scb_cmd,nlisten+nowait ; do LISTEN command, no wait
	push	bx			; save reg
	mov	bx,offset lsn
	call	nbsession
	pop	bx
	mov	pcnet,2			; net ready, Listen is active
	clc
	ret
setne2:					; Non-server (Client) mode
	cmp	starlan,0		; STARLAN?
	je	setne2a			; e = no
	cmp	xmt.scb_vrlen,0		; yes, using long name support?
	je	setne2a			; e = no
	push	es			; save reg
	push	ds
	pop	es			; make es:bx point to xmt scb
	push	bx			; save reg
	mov	bx,offset xmt		; use xmt scb for the call
	mov	xmt.scb_cmd,ncall	; CALL_ISN, vrname + vrlen are ready
	int	5bh			; STARLAN CALL Int 5bh, wait
	pop	bx
	pop	es			; restore regs
	jmp	short setne3		; finish up

					; Regular Netbios Call
setne2a:cmp	flags.comflg,'O'	; Opennet network? (FGR)
	jne	setne2b			; ne = no
	mov	xmt.scb_rname+15,'v' ; fix name to use VT port under nameserver
	mov	rcv.scb_rname+15,'v'
setne2b:mov	xmt.scb_cmd,ncall	; CALL, wait for answer
	push	bx			; save reg
 	mov	bx,offset xmt		; setup scb pointer
	call	nbsession
	pop	bx			; restore register

setne3:					; common Call completion, show status
	test	xmt.scb_err,0ffh	; is there a non-zero return code?
	jnz	setne3a			; nz = yes, do bad return
	or	al,al			; check error return
	jnz	setne3b			; nz = bad connection
	jmp	short setne4		; good connection so far

					; We try twice to allow for R1, and R3
					; versions of the nameservers
setne3b:cmp	flags.comflg,'O'	; Opennet netnork? (FGR)
	jne	setne3a			; ne = no
	mov	xmt.scb_rname+15,' '	; try generic port under nameserver
	mov	rcv.scb_rname+15,' '
					; Regular Netbios Call
	mov	xmt.scb_cmd,ncall	; CALL, wait for answer
	mov	bx,offset xmt		; setup scb pointer
	call	nbsession

					; common Call completion, show status
	test	xmt.scb_err,0ffh	; is there a non-zero return code?
	jnz	setne3a			; nz = yes, do bad return
	or	al,al			; check error return
	jz	setne4			; z = good connection so far
setne3a:mov	dx,offset nbadset	; say can't reach remote node
	mov	ah,prstr
	int	dos
	call	saynode			; show remote host node name
	jmp	setne4c
					; keep results of Call (vcid)
setne4:	mov	al,xmt.scb_vcid		; local session number
	mov	rcv.scb_vcid,al		; for receiver too
	mov	can.scb_vcid,al		; for sending Breaks
	mov	pcnet,2			; say session has started

; Here is the real difference between Opennet and generic Netbios.
; The Opennet Virtual Terminal Services exchange a small handshake at connect
; time. After that it is just normal Netbios data transfer between the host
; and Kermit.
	cmp	flags.comflg,'O'	; Opennet netnork? (FGR)
	jne	setne4o			; ne = no
	push	si
	push	di
	mov	si,offset ivt1str	; protocol string "iVT1\0"
	mov	di,offset xmtbufx	; buffer
	call	strcpy			; copy asciiz string
	mov	xmtcnt,5		; length of asciiz string, for send
	pop	di
	pop	si
	call	send			; send signon packet
; Note to Opennet purists: this just sends the handshake string to the host
; system without checking for an appropriate response. Basically, I am just
; very willing to talk to ANY VT server, and do the host response checking
; (if desired) in a Kermit script file (so its optional).

setne4o:cmp	flags.comflg,'E'	; ACSI version of EBIOS?
	jne	setnet4p		; ne = no
	mov	word ptr xmtbufx,6	; internal word count
	mov	xmtcnt,6		; four bytes
	mov	word ptr xmtbufx+2,acenable*256+3 ; raise DTR and RTS
	mov	bx,portval
	mov	ax,[bx].baud		; get baud rate index
	cmp	al,0ffh			; unknown baud rate?
	jne	setnet4pa		; ne = no
	mov	ax,11			; 2400,n,8,1
	mov	[bx].baud,ax		; set index into port info structure
setnet4pa:shl	ax,1			; make a word index
	mov	bx,ax
	mov	ax,clbddat[bx]		; Bios style speed setting
	cmp	al,0ffh			; unimplemented baud rate?
	jne	setnet4pb		; ne = no
	mov	bx,portval		; set index into port info structure
	mov	[bx].baud,3		; 110 baud -> 19200 for ACSI
	mov	al,3			; default to 19200,n,8,1
setnet4pb:mov	ah,acsetmode		; ACSI cmd for Mode set
	mov	word ptr xmtbufx+4,ax	; Mode setting
	or	nettype,acsi		; set special net operation
	call	send
setnet4p:
	test	flags.remflg,dregular+dquiet ; regular or quiet display?
	jnz	setne4c			; nz = yes, show only no-connect msg
	mov	dx,offset ngodset	; say good connection
	mov	ah,prstr
	int	dos
	call	saynode			; show remote host name
setne4c:cmp	pcnet,1			; check connection again
	ja	setne5			; a = good so far
	call	nbclose			; shut down NetBios
	stc				; set carry for failure
	ret
setne5:	or	nettype,netbios		; set net type
	clc				; carry clear for success
	ret
SETNET	ENDP

saynode	proc	near		; display node name on screen, si=name ptr
	push	ax
	push	cx
	push	dx
	push	si
	mov	ah,conout
	mov	si,offset nambuf	; remote node string
	mov	cx,64			; up to 64 bytes long
saynod1:cld
	lodsb				; get remote node name char into al
	mov	dl,al
	int	dos			; display it
	cmp	al,' '			; was it a space?
	jbe	saynod2			; be = yes, quit here
	loop	saynod1			; do all chars
saynod2:mov	ah,prstr
	mov	dx,offset crlf
	int	dos
	pop	si
	pop	dx
	pop	cx
	pop	ax
	ret
saynode	endp

LPOST	PROC	FAR		; Interrupt Post routine for Listen call
	push	ds		; update vcid and calling node name in scb's
	push	cx	
	push	es
	push	si
	push	di
	mov	cx,seg lsn		; reestablish data segment
	mov	ds,cx
	mov	es,cx
	mov	si,offset lsn.scb_rname	; copy remote name to rcv and xmt scbs
	push	si
	mov	di,offset rcv.scb_rname
	mov	cx,8			; 16 byte field
	cld
	rep	movsw
	mov	cx,8
	pop	si
	push	si
	mov	di,offset xmt.scb_rname
	rep	movsw
	mov	cx,8
	pop	si
	mov	di,offset nambuf	; and to nambuf for display
	rep	movsw
	mov	cl,lsn.scb_vcid		; local session number
	mov	rcv.scb_vcid,cl
	mov	xmt.scb_vcid,cl
	mov	can.scb_vcid,cl
	mov	lposted,0		; clear interlock flag
	mov	pcnet,2			; say net ready due to a Listen
	pop	di
	pop	si
	pop	es
	pop	cx
	pop	ds
	iret				; return from interrupt
LPOST	ENDP

; Close all network connections
NETHANGUP PROC	NEAR		     ; disconnect network session, keep names
	call	ubclose			; close Ungermann Bass Int 6Bh class
	mov	xmtcnt,0
	call	decclose		; close DECnet connection
	call	telapiclose		; close Telapi session
ifndef	no_tcp
	mov	sescur,-1		; say close all sessions, stop TCP/IP
	call	tcpclose		; close internal TCP/IP sessions
endif	; no_tcp
	call	ebiclose		; close EBIOS session
	call	tesclose		; close TES session, ignore failures
	call	nbclose			; close NetBios and ACSI
	call	bwclose			; close BW TCP
	mov	portin,0		; reset the serial port for reiniting
	mov	kbdflg,'C'		; quit connect mode
	clc
	ret
NETHANGUP ENDP

; Close NetBios connection. Clears nettype of netbios
nbclose proc	near
	test	nettype,(netbios+acsi)	; NetBios or ACSI active?
	jz	nbclose2		; z = no
	cmp	pcnet,0			; network started?
	je	nbclose2		; e = no
	test	nettype,acsi		; ACSI?
	jz	nbclose1		; z = no
	mov	word ptr xmtbufx,4	; four bytes
	mov	word ptr xmtbufx+2,acdisable*256 ; drop all modem leads
	mov	xmtcnt,4		; four bytes
	call	send			; tell the server
	mov	ax,500			; wait 0.5 sec
	call	pcwait			; for pkt to reach host
nbclose1:push	bx			; NetBios network
	mov	bx,offset can 
	mov	can.scb_cmd,ncancel	; set cancel op code
	mov	can.scb_baddr,offset lsn ; cancel listens
	mov	lposted,0		; say no listen
	call	nbsession
	mov	can.scb_baddr,offset rcv ; cancel receives
	call	nbsession
	mov	rposted,0		; say no receives posted
	mov	can.scb_baddr,offset xmt ; cancel sends
	call	nbsession
	mov	sposted,0		; say no sends posted
	mov	xmtcnt,0		; reset output buffer counter
	mov	xmt.scb_cmd,nhangup	; hangup, and wait for completion
	mov	bx,offset xmt
	call	nbsession
	pop	bx
	and	nettype,not (netbios+acsi)
	mov	pcnet,1			; net but no connection
	mov	port_nb.portrdy,0	; say the comms port is not ready
	mov	portin,0
	mov	kbdflg,'C'		; quit connect mode
	stc
nbclose2:ret
nbclose endp

decclose proc	near
	test	nettype,declat		; DECnet LAT active?
	jz	decclos3		; z = no
	mov	dx,lathand		; LAT handle
	or	dx,dx			; invalid handle?
	jz	decclos2		; z = yes
	mov	ax,latclose
	int	latint
	mov	ax,latseg		; allocated memory segment
	or	ax,ax			; was it used?
	jz	decclos1		; z = no
	push	es
	mov	es,ax
	mov	ah,freemem		; free allocated memory segment @ES
	int	dos			; free the block
	pop	es
	mov	latseg,0		; clear remembered segment address
	mov	word ptr latscbptr+2,0	; clear this pointer (same as latseg)
decclos1:cmp	latversion,4		; version 4?
	jb	decclos2		; b = no
	push	es
	les	bx,latscbptr+4		; address of exterior SCB
	mov	dx,lathand
	mov	ax,latscbfree		; free SCB interior to LAT
	int	latint
	mov	word ptr latscbptr+2,0
	pop	es
decclos2:and	nettype,not declat	; remove net type bit
	mov	lathand,0		; invalidate the handle

decclos3:test	nettype,decnet		; DEC CTERM active?
	jz	decclos4		; z = no
	mov	dx,decneth		; DECnet CTERM handle
	or	dx,dx			; invalid handle?
	jz	decclos5		; z = yes
	mov	ax,dclose		; CTERM close
	int	decint
	mov	decneth,0		; invalidate the handle
	mov	ax,decseg		; allocated memory segment
	or	ax,ax			; ever used?
	jz	decclos4		; z = no
	mov	es,ax
	mov	ah,freemem		; free allocated memory segment @ES
	int	dos			; free the block
	mov	decseg,0		; clear remembered segment address
decclos4:and	nettype,not decnet	; remove net type bit
	mov	port_dec.portrdy,0	; say port is not ready
	mov	pcnet,0			; say no network
	mov	portin,0
	mov	kbdflg,'C'		; quit connect mode
	stc
decclos5:ret
decclose endp

telapiclose proc near
	test	nettype,telapi		; Novell TELAPI?
	jz	telapiclo1		; e = no
	mov	xmtcnt,0
	push	bx
	mov	bx,telses		; session number
	mov	ah,telclose		; close session
	int	rs232
	pop	bx
	and	nettype,not telapi	; remove active net type bit
	mov	portin,0
	mov	pcnet,1
	push	bx
	mov	bx,portval
	mov	[bx].portrdy,0		; say port is not ready
	pop	bx
	mov	kbdflg,'C'		; quit connect mode
	stc
telapiclo1:ret
telapiclose endp

; Close EBIOS communications link
ebiclose proc near
	test	nettype,ebios		; EBIOS?
	jz	ebiclos1		; z = no
	mov	dx,ebport		; EBIOS
	mov	ax,ebmodem*256+0	; reset outgoing DTR and RTS leads
	int	rs232
	push	es
	mov	bx,ds
	mov	es,bx
	mov	bx,offset ebcoms	; es:bx is parameter block ebcoms
	mov	ah,ebredir		; do redirect away from EBIOS
	mov	ebcoms+1,0		; set port to hardware
	int	rs232
	mov	dx,ebport		; port 0..3
	mov	bx,offset rcvbuf	; receive buffer for EBIOS
	xor	cx,cx			; set to zero to stop buffering
	mov	ax,ebbufset*256+2	; reset rcvr buffered mode
	int	rs232
	xor	cx,cx
	mov	bx,offset xmtbuf	; EBIOS transmitter work buffer
	mov	ax,ebbufset*256+1	; reset xmtr buffered mode
	int	rs232
	pop	es
	mov	bx,offset portb1	; use Bios data structure
	mov	ax,type prtinfo		; portinfo item size
	mul	dl			; times actual port (0..3)
	add	bx,ax			; new portb<n> offset
	mov	[bx].portrdy,0		; say port is not ready
	and 	nettype,not ebios
	mov	portin,0
	mov	kbdflg,'C'		; quit connect mode
	stc
ebiclos1:ret
ebiclose endp

; TES close session
tesclose proc	near
	test	nettype,tes		; TES?
	jz	tesclo3			; z = no
	mov	temp,0			; retry counter
	call	tesstate		; get session state to AH
	test	ah,2			; is this session active?
	jz	tesclo2			; z = no, but keep held sessions
	mov	ah,tesdrop		; drop a session
	mov	al,tesses		; the session
	call	tes_service
	or	ah,ah			; status
	jz	tesclo2			; z = success
	stc				; say failure
	ret
tesclo2:and	nettype,not tes		; successful hangup
	mov	tesses,0		; clear session
	mov	port_tes.portrdy,0	; say the comms port is not ready
	mov	pcnet,1			; say network but no session
	mov	portin,0
	mov	kbdflg,'C'		; quit connect mode
	stc
	ret
tesclo3:clc
	ret
tesclose endp

; Ungermann Bass. Do a disconnect from the current connection.
ubclose proc	near
	push	ax
	push	cx
	test	nettype,netone		; UB network has been activated?
	jz	ubclos4			; z = no
	mov	ax,ncistat		; get status			 [ohl]
	int	netci
 	or	ch,ch			; check if we have a connection	 [ohl]
	jz	ubclos2			; z = no			 [ohl]
	mov	ax,ncicont		; control function		 [ohl]
	mov	cx,ncidis		; say disconnect		 [ohl]
	int	netci
ubclos1:call	ubrecv			; read response from net cmdintpr[ohl]
	jnc	ubclos1			; continue till no chars	 [ohl]
	mov	ax,ncistat		; get status again
	int	netci
	or	ch,ch			; check if we have a connection
	jnz	ubclos3			; nz = yes, had more than one
ubclos2:and	nettype,not netone	; remove network type
	mov	pcnet,1			; net but no connection
	mov	port_ub.portrdy,0	; say the comms port is not ready
	mov	portin,0
	mov	kbdflg,'C'		; quit connect mode
	stc
ubclos3:mov	flags.cxzflg,'C'	; signal abort to file transfer code
	pop	cx
	pop	ax
	ret
ubclos4:test	nettype,bapi+tcpnet	; 3Com BAPI or TCP Telnet in use?
	jz	ubclos6			; z = no
	mov	ah,bapieecm		; control Enter Command Mode char
	mov	al,1			; enable it
ifndef	no_tcp
	test	nettype,tcpnet		; TCP/IP Telnet?
	jz	ubclos5			; z = no
	mov	bx,sescur		; current session
	mov	seslist[bx],-1		; say session is closed
	call	tcpclose		; tell Telnet manager about closure
	jmp	short ubclos3
endif	; no_tcp
ubclos5:int	bapiint
	and	nettype,not bapi	; remove BAPI bit
	jmp	short ubclos3
ubclos6:test	nettype,telapi		; Novell TELAPI Int 6Bh interface?
	jz	ubclos3			; z = no
	call	telapiclose
	jmp	short ubclos3
ubclose endp

; Ungermann Bass/Novell. Put current connection on Hold. Requires keyboard
; verb \knethold to activate. Should return to Connect mode to see NASI. [jrd]
ubhold	proc	near
	push	ax
	push	cx
	test	nettype,netone		; UB/Novell network active?
	jz	ubhold1			; z = no
	mov	ax,ncistat		; get link status
	int	netci
	or	ch,ch			; connection active?
	jz	ubhold1			; z = no
	mov	ax,ncicont		; control command
	mov	cl,ncihld		; place circuit on HOLD
	int	netci
	jmp	short ubhold3
ubhold1:test	nettype,bapi		; 3Com BAPI
	jz	ubhold2			; z = no
	mov	ah,bapiecm		; do Enter Command Mode char
ubhold1b:int	bapiint
	jmp	short ubhold3
ubhold2:test	nettype,tes		; TES?
	jz	ubhold3			; z = no
	mov	ah,testalk		; TES get command interpreter
	mov	dx,tesport		; "serial port"
	int	rs232
ubhold3:pop	cx
	pop	dx
	clc
	ret
ubhold	endp

; Beame & Whiteside TCP close session [JRS]
bwclose	proc	near			; [JRS]
	mov	bx,bwhandle		; [JRS] get file handle
	or	bx,bx			; [JRS] if zero, we're done
	jz	bwclos1			; [JRS] z= done
	mov	ah,close2		; [JRS] close device
	int	dos			; [JRS]
	mov	bwhandle,0		; [JRS] clear the handle value
bwclos1:and	nettype,not bwtcp
	mov	portin,0		; say serial port is closed
	mov	pcnet,0
	mov	port_tn.portrdy,0	; say port is not ready
	mov	kbdflg,'C'		; quit connect mode
	clc				; [JRS]	flag success
	ret
bwclose	endp

; Called when Kermit exits. Name passed to mssker by initialization lclini
; in word lclexit.
NETCLOSE PROC	NEAR			; close entire network connection
	call	nethangup		; close connections
	push	bx
	mov	bx,offset xmt
	cmp	xmt.scb_lname,' '	; any local name?
	je	netclo2			; e = none
	mov	xmt.scb_cmd,ndelete	; delete our local Kermit name
	call	nbsession		;  from net adapter board
	mov	xmt.scb_lname,' '	; clear name
netclo2:pop	bx
	mov	pcnet,0			; say no network
	mov	lnamestat,0		; local name not present, inactive
	mov	port_nb.portrdy,0	; say comms port is not ready
	and	nettype,not (netbios+acsi) ; remove network kind
netclo1:clc
	ret
NETCLOSE ENDP	

; Start connection process to network. Obtains Network board local name
; and appends '.K' to form Kermit's local name (removed when Kermit exits).
; If no local name is present then use name 'mskermit.K'.
; Sets local name in scb's for xmt, rcv, lsn. (Does not need DOS 3.x)
; Sets NETDONE pointer to procedure netclose for Kermit exit.
; Verifies existance of interrupt 5ch support, verifies vendor specific
; support for BREAK and other features, sets network type bit in nettype,
; sets BREAK support in nsbrk, hangsup old session if new node name given,
; fills in local and remote node names and name number in scbs (including ISN
; names for STARLAN), and sets network status byte pcnet to 0 (no net) or
; to 1 (net ready). This is the first procedure called to init network usage.
; Byte count of new host name is in temp from COMS.
chknet	proc	near
	cmp	flags.comflg,'U'	; Ungermann Bass network?
	jb	chknea			; b = no, (ae includes U and W)
	mov	pcnet,0			; force reactivation of UB net
chknea:	cmp	pcnet,2			; session active now?
	jb	chknec			; b = no
	cmp	newnambuf,0		; non-zero if new destination name
	je	chkneb			; e = none, resume old session
	call	chknew			; Resume current session?
	jnc	chkneb			; nc = no
chknex:	ret				; resume old one
chkneb:	jmp	chknet1			; skip presence tests

chknec:				; setup addresses and clear junk in scb's
	cmp	pcnet,0			; have we been here already?
	je	chkned			; e = no
	jmp	chknet1			; yes, skip init part
chkned:	mov	xmtcnt,0		; say buffer is empty
	mov	nsbrk,0			; assume no BREAK across network
	and	nettype,not netbios	; say no NetBios network yet
	mov	starlan,0		; no Starlan yet
	call	chknetbios		; is Netbios present?
	jc	chknet0			; c = not present
	or	nettype,netbios		; say have NetBios network
	call	chkstarlan		; is AT&T StarLAN present?
	jc	chknet1			; c = no
	inc	starlan			; say using STARLAN, have int 2ah
	mov	nsbrk,1			; network BREAK supported
	jmp	short chknet1

chknet0:mov	pcnet,0			; no network yet
	push	dx
	mov	ah,prstr
	mov	dx,offset nonetmsg	; say network is not available
	int	dos
	pop	dx
	stc				; set carry for failure
	ret				; and exit now

					; net ready to operate
chknet1:mov	port_nb.portrdy,1	; say the comms port is ready
	cmp	newnambuf,0		; non-zero if new destination name
	jne	chkne1e			; ne = new name given
	jmp	chknet2			; nothing, so leave names intact
chkne1e:cmp	pcnet,2			; is session active now?
	jb	chkne1d			; b = no
	call	nbclose			; close to clear old connection

chkne1d:push	si			; start fresh connection
	push	di
	push	es
	push	ds
	pop	es			; make es:di point to data segment
	cld
	mov	cx,8			; 16 bytes for a node name
	mov	ax,'  '			; first, fill with spaces
	mov	di,offset xmt.scb_rname ; remote name field, clear it
	rep	stosw
	cmp	starlan,0		; STARLAN?
	jne	chkne1b			; ne = no
					; begin STARLAN section	
	mov	xmt.scb_vrname,0	; STARLAN var length name ptr
	mov	xmt.scb_vrname+2,0	; segement of name	
	mov	xmt.scb_vrlen,0		; and its length
	mov	di,offset nambuf	; source of text
	mov	dx,di
	call	strlen			; length of new name to cx
	cmp	cx,16			; > 16 chars in remote node name?
	ja	chkne1a			; a = yes, too long for Netbios
	mov	al,'/'			; scan for slashes in name
	cld
	repne	scasb			; look for the slash
	jne	chkne1b		; ne = none, do regular Netbios name storage
chkne1a:				; STARLAN ISN long remote name support
	mov	dx,offset nambuf	; STARLAN var length name ptr
	mov	xmt.scb_vrname,dx	
	mov	xmt.scb_vrname+2,data	; segment of remote name
	call	strlen			; get name length again (in cx)
	mov	xmt.scb_vrlen,cl	; indicate its length
	jmp	short chkne1c		; copy blanks in remote name field
					; end STARLAN section

chkne1b:				; Regular Netbios form
	mov	si,offset nambuf	; source of text
	mov	dx,si
	call	strlen			; length to cx
	cmp	cx,16
	jbe	chkne1f			; be = in bounds
	mov	cx,16			; chop to 16 (prespace filled above)
chkne1f:mov	di,offset xmt.scb_rname ; destination is remote name
	rep	movsb			; copy text to transmitter's scb
chkne1c:mov	cx,8			; 8 words
	mov	si,offset xmt.scb_rname ; from here
	mov	di,offset rcv.scb_rname ; to receiver's scb also
	rep	movsw
	pop	es
	pop	di
	pop	si
	mov	newnambuf,0		; say new name is established now

chknet2:cmp	pcnet,0			; started net?
	je	chknet2c		; e = no
	clc
	ret				; else quit here
chknet2c:call	setnbname		; establish local Netbios name
	jnc	chknet9			; nc = success
	ret
chknet9:mov	pcnet,1			; network is present (but not active)
	mov	al,xmt.scb_num		; name number
	mov	rcv.scb_num,al
	mov	lsn.scb_num,al
	push	es
	push	si
	push	di
	mov	si,ds
	mov	es,si
	mov	si,offset xmt.scb_lname
	mov	di,offset rcv.scb_lname ; put in receiver scb too
	mov	cx,8
	rep	movsw
	mov	cx,8
	mov	si,offset xmt.scb_lname
	mov	di,offset lsn.scb_lname	; in Listen scb also
	rep	movsw
	pop	si
	pop	di
	pop	es
	clc
	ret
chknet	endp

; Service SET NETBIOS-NAME name   command at Kermit prompt level
setnbios	proc	near
	mov	bx,offset decbuf	; work buffer
	mov	dx,offset setnbhlp2	; help
	mov	ah,cmword		; get netbios name
	call	comnd
	jc	setnb3			; c = failure
	push	ax			; save char count
	mov	ah,cmeol		; get a confirmation
	call	comnd
	pop	ax
	jc	setnb3			; c = failure
	cmp	lnamestat,2		; is name fixed already?
	je	setnb2			; e = yes
	mov	cx,ax			; char count
	jcxz	setnb3			; z = enter no new name
	cmp	cx,16			; too long?
	jbe	setnb1			; be = no
	mov	cx,16			; truncate to 16 chars
setnb1:	mov	si,offset decbuf	; work buffer
	mov	di,offset deflname	; default name
	push	es
	mov	ax,ds
	mov	es,ax
	cld
	rep	movsb			; copy the name
	mov	al,' '			; pad with spaces
	mov	cx,offset deflname+16	; stopping place+1
	sub	cx,di			; number of spaces to write
	rep	stosb			; won't do anything if cx == 0
	pop	es
	mov	lnamestat,1		; say have new local name
	call	setnbname		; do the real NetBios resolution
	ret				; returns carry set or clear
setnb2:	mov	ah,prstr
	mov	dx,offset setnbad	; say name is fixed already
	int	dos
setnb3:	stc				; failure
	ret
setnbios endp

chknetbios proc	near			; Test for Netbios presence, IBM way
	push	es
	mov	ah,35h			; DOS get interrupt vector
	mov	al,netint		; the netbios vector
	int	dos			; returns vector in es:bx
	mov	ax,es
	or	ax,ax			; undefined interrupt?
	jz	chknb2			; z = yes
	cmp	byte ptr es:[bx],0cfh	; points at IRET?
	je	chknb2			; e = yes
	mov	xmt.scb_cmd,7fh ; presence test, 7fh is illegal command code
	mov	xmt.scb_err,0		; clear response field
	push	bx
	mov	bx,offset xmt		; address of the session control block
	call	nbsession		; execute operation
	pop	bx
	mov	al,xmt.scb_err		; get response
	cmp	al,3	  	  ; 'illegal function', so adapter is ready
	je	chknb1			; e = success
	or	al,al
	jnz	chknb2			; nz = not "good response" either
chknb1:	pop	es
	clc				; netbios is present
	ret
chknb2:	pop	es
	stc				; netbios is not present
	ret
chknetbios endp

chkstarlan proc near			; AT&T STARLAN board check
	push	es
	mov	ah,35h			; DOS get interrupt vector
	mov	al,2ah			; PC net vector 2ah
	int	dos			; returns vector in es:bx
	mov	ax,es
	or	ax,ax			; undefined interrupt?
	jz	chkstar1		; z = yes
	cmp	byte ptr es:[bx],0cfh	; points at IRET?
	je	chkstar1		; e = yes
	xor	ah,ah			; vendor installation check on int 2ah
	xor	al,al			; do error retry
	int	2ah			; session level interrupt
	cmp	ah,0ddh			; 0ddh = magic number, success?
	jne	chkstar1		; ne = no
					; Test for vector
	mov	ah,35h			; DOS get interrupt vector
	mov	al,5bh			; 5bh = STARLAN netbios ext'd vector
	int	dos			; returns vector in es:bx
	mov	ax,es
	or	ax,ax			; undefined interrupt?
	jz	chkstar1		; z = yes
	cmp	byte ptr es:[bx],0cfh	; points to IRET?
	je	chkstar1		; e = yes
	pop	es
	clc				; StarLAN is present
	ret
chkstar1:pop	es
	stc				; StarLAN is not present
	ret
chkstarlan endp

; Put a local name into the Netbios name table, ask user if conflicts.
setnbname proc	near
	cmp	lnamestat,2		; validiated local Netbios name?
	jb	setnbn1			; b = no
	ret				; else quit here
setnbn1:call	chknetbios		; Netbios presence check
	jnc	setnbn1a		; nc = present
	ret

setnbn1a:mov	ah,prstr
	mov	dx,offset netmsg1	; say checking node name
	int	dos
	push	word ptr xmt.scb_rname	; save first two bytes (user spec)
	mov	byte ptr xmt.scb_rname,'*' ; call to local name
	push	bx
	mov	xmt.scb_cmd,naustat	; get Network Adapter Unit status
	mov	bx,offset xmt
	call	nbsession
	pop	bx
	pop	word ptr xmt.scb_rname	; restore remote name first two bytes
setnbn2:push	es
	push	si
	push	di
	mov	si,ds
	mov	es,si
	cld
	mov	si,offset deflname	; use default local name
	mov	di,offset xmt.scb_lname ; where to put it in scb
	mov	cx,14			; 16 bytes minus extension of '.K'
	cld				; append extension of '.K' to loc name
setnbn5:cmp	byte ptr[si],' ' ; find first space (end of regular node name)
	jbe	setnbn6			; be = found one (or control code)
	movsb				; copy local name to scb
	loop	setnbn5			; continue though local name
setnbn6:cmp	word ptr [di-2],'K.'	; is extension '.K' present already?
	je	setnbn7			; e = yes, nothing to add
	cmp	word ptr [di-2],'k.'	; check lower case too
	je	setnbn7			; e = yes, nothing to add
	mov	word ptr [di],'K.'	; append our extension of '.K'
	add	di,2			; step over our new extension
	sub	cx,2
					; complete field with spaces
setnbn7:add	cx,2			; 15th and 16th chars
	mov	al,' '			; space as padding
	rep	stosb
	pop	di			; clean stack from work above
	pop	si
	pop	es

	push	bx			; Put our new local name in NAU
	mov	xmt.scb_cmd,nadd	; ADD NAME, wait
	mov	bx,offset xmt
	call	nbsession
	pop	bx
	mov	al,xmt.scb_err		; get error code
	or	al,al			; success?
	jnz	setnbn8			; nz = no
	jmp	setnbn12		; success
setnbn8:cmp	al,0dh			; duplicate name in local table?
	je	setnbn9			; e = yes
	cmp	al,16h			; name used elsewhere?
	je	setnbn9			; e = yes
	cmp	al,19h			; name conflict?
	je	setnbn9			; e = yes
	push	ax
	mov	ah,prstr		; another kind of error
	mov	dx,offset chkmsg1	; say can't construct local name
	int	dos
	pop	ax
	call	decout			; display it (in al)
	mov	ah,prstr
	mov	dx,offset crlf
	int	dos
	stc				; set carry for failure
	ret

setnbn9:mov	ah,prstr		; ask for another name
	mov	dx,offset chkmsg2	; prompt message
	int	dos
	mov	ah,conout		; show name itself
	push	si
	push	cx
	mov	cx,16			; 16 bytes in name field
	mov	si,offset xmt.scb_lname
setnbn10:lodsb				; get name char into al
	mov	dl,al
	int	dos
	mov	byte ptr[si-1],' '	; clear old name as we go
	loop	setnbn10
	pop	cx
	pop	si
	mov	ah,prstr
	mov	dx,offset chkmsg3	; rest of prompt
	int	dos

	mov	ah,0ah			; read buffered line from stdin
	mov	dx,offset xmtbuf+58	; where to put text (xmtbuf+60=text)
	mov	xmtbuf+58,15		; buf capacity, including cr at end
	mov	xmtbuf+59,0		; say text in buffer = none
	int	dos
	jc	setnbn11		; c = error
	cmp	xmtbuf+59,0		; any bytes read?
	je	setnbn11		; e = no, exit failure
	mov	ah,prstr		; say rechecking name
	mov	dx,offset netmsg1
	int	dos
	push	es
	mov	si,ds
	mov	es,si
	mov	si,offset xmtbuf+60	; where text went
	mov	di,offset deflname	; where local name is stored
	mov	cx,8
	cld
	rep	movsw			; copy 14 chars to deflname
	mov	byte ptr [di],0		; null terminator, to be safe
	pop	es
	mov	lnamestat,1		; say local name specified
	jmp	setnbn2			; go reinterpret name

setnbn11:stc				; set carry for failure
	ret

setnbn12:mov	dx,offset netmsg2	 ; say net is going
	mov	ah,prstr
	int	dos
	push	si
	push	di
	push	es
	mov	si,ds
	mov	es,si
	mov	si,offset xmt.scb_lname ; display our local name
	mov	di,offset deflname	; local Netbios name
	mov	ah,conout
	mov	cx,16
	cld
setnbn13:lodsb				; byte from si to al
	stosb				; and store in local Netbios name
	mov	dl,al
	int	dos			; display it
	loop	setnbn13
	pop	es
	pop	di
	pop	si
	mov	lnamestat,2		; say local name is fixed now
	mov	ah,prstr
	mov	dx,offset crlf		; add cr/lf
	int	dos
	clc				; carry clear for success
	ret
setnbname endp

; Network session exists. Tell user and ask for new node or Resume.
; Returns carry set if Resume response, else carry clear for New.
chknew	proc	near
	mov	ax,takadr		; we could be in a macro or Take file
	push	ax			; save Take address
	mov	al,taklev
	xor	ah,ah
	push	ax			; and Take level
	push	dx
	mov	dx,size takinfo		; bytes for each current Take
	mul	dx			; times number of active Take/macros
	pop	dx
	sub	takadr,ax		; clear Take address as if no
	mov	taklev,0		;  Take/macro were active so that

	mov	dx,offset naskpmt	; prompt for New or Resume
	call	prompt
	mov	dx,offset nettab	; table of answers
	xor	bx,bx			; help for the question
	mov	ah,cmkey		; get answer keyword
	mov	comand.cmcr,1		; allow bare CR's
	call	comnd
	mov	comand.cmcr,0		; dis-allow bare CR's
	jc	chknew1			; c = failure, means Resume
	push	bx
	mov	ah,cmeol		; get a confirm
	call	comnd
	pop	bx
	jc	chknew1			; c = failure, resume session
	or	bx,bx			; 0 for new?
	jz	chknew1			; z = yes, return carry clear
	stc				; set carry for resume
chknew1:pop	ax
	mov	taklev,al		; restore Take level
	pop	takadr			; restore Take address
	ret				; carry may be set
chknew	endp

;					; [ohl] ++++
; Verifies existance of interrupt 6Bh support, verifies vendor specific
; support for BREAK and other features, sets network type bit in nettype,
; sets BREAK support in nsbrk and sets network status byte pcnet to 0
; (no net) or to 1 (net ready). This is the first procedure called to
; init Ungermann-Bass NETCI terminal port network usage.
chkub  proc    near
	push    bx
        push    es                      ; Test for vector
        mov     ah,35h                  ; DOS get interrupt vector
        mov     al,6bh                  ; 6bh = Net/One command interpreter
					;  interface, with break support
        int     dos                     ; returns vector in es:bx
	mov	ax,es			; is vector in rom bios?
	or	ax,ax			; undefined vector?
	jz	chkub0			; z = yes
	cmp	byte ptr es:[bx],0cfh	; points at IRET?
	je	chkub0			; e = yes
;some	mov	al,0ffh			; test value (anything non-zero)
;emulators mov	ah,2			; function code for testing net board
;flunk	int	netci
;this	or	al,al			; al = 0 means board is ok
;test	jnz	chkub0			; nz = not ok
	pop	es
	pop	bx
        mov     nsbrk,1                 ; network BREAK supported
        or      nettype,netone		; say have Net/One
	clc				; return success
	ret

chkub0:	pop	es			; clean stack from above
	pop	bx
	push    ax
        push    dx
        mov     ah,prstr
        mov     dx,offset nonetmsg      ; say network is not available
        int     dos
        pop     dx
        pop     ax
        stc                             ; set carry for failure
        ret                             ; and exit now
chkub  endp

endif	; no_network

; local routine to see if we have to transmit an xon
chkxon	proc	near
	test	flowcnt,1+4		; doing output/RTS flow control?
	jz	chkxo1			; z = no, skip all this
	test	xofsnt,usron		; did user send an xoff?
	jnz	chkxo1			; nz = yes, don't contradict it here
	test	xofsnt,bufon		; have we sent a buffer level xoff?
	jz	chkxo1			; z = no, forget it
	cmp	count,mntrgl		; below (low water mark) trigger?
	jae	chkxo1			; no, forget it
	test	flowcnt,4		; using RTS/CTS kind?
	jz	chkxo2			; z = no
	cmp	flags.comflg,4		; using uart?
	ja	chkxo1			; a = no, ignore situation
	push	ax
	push	dx
	mov	dx,modem.mddat		; serial port base address
	add	dx,4			; increment to control register
	in	al,dx
	or	al,2			; assert RTS for flow-on
	push	ax
	in	al,ppi_port		; delay
	pop	ax
	out	dx,al
	and	xofsnt,off		; remember we've sent the "xon"
	pop	dx
	pop	ax
					; do software flow control too
chkxo2:	test	flowcnt,1		; using outgoing XON/XOFF kind?
	jz	chkxo1			; z = no
	mov	ah,flowon		; ah gets xon
	and	xofsnt,off		; remember we've sent the xon
	call	outch2		    ; send via non-flow controlled entry point
chkxo1:	ret
chkxon	endp

; IHOSTS - Initialize the host by sending XOFF, or equivalent.
; Requires that the port be initialized before hand.
; Do not send flow control if doing half duplex.

IHOSTS	PROC	NEAR
	push	ax		; save the registers
	push	bx
	push	cx
	push	dx
	mov	xofrcv,off	; clear old xoff received flag
	mov	xofsnt,off	; and old xoff sent flag
	cmp	portin,0	; is a comms port active?
	jle	ihosts1		; le = no
	mov	bx,portval
	test	flowcnt,4	; using CTS/RTS?
	jnz	ihosts2		; nz = yes
	mov	ah,byte ptr [bx].flowc ; put wait flow control char in ah
	or	ah,ah		; check for null char
	jz	ihosts1		; z = null, don't send it
	cmp	dupflg,0	; full duplex?
	jne	ihosts1		; ne = no, half
	call	outchr		; send it
	jmp	short ihosts1
ihosts2:cmp	flags.comflg,4		; using uart?
	ja	ihosts1			; a = no, ignore situation
	mov	dx,modem.mddat		; serial port base address
	add	dx,4			; increment to control register
	in	al,dx
	and	al,not 2		; clear RTS for flow-off
	push	ax
	in	al,ppi_port		; delay
	pop	ax
	out	dx,al
	or	xofsnt,bufon		; remember we've sent the "xoff"
ihosts1:pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
IHOSTS	ENDP

; IHOSTR - initialize the remote host for our reception of a file by
; sending the flow-on character (XON typically) to release any held
; data. Do not send flow control if doing half duplex.
IHOSTR	PROC	NEAR
	push	ax		; save regs
	push	bx
	push	cx
	mov	xofrcv,off	; clear old xoff received flag
	mov	xofsnt,off	; and old xoff sent flag
	cmp	portin,0	; is a comms port active?
	jle	ihostr1		; le = no
	mov	bx,portval
	test	flowcnt,4	; using CTS/RTS?
	jnz	ihostr2		; nz = yes
	mov	ah,byte ptr [bx].flowc+1; put go-ahead flow control char in ah
	or	ah,ah		; check for null char
	jz	ihostr1		; z = null, don't send it
	cmp	dupflg,0	; full duplex?
	jne	ihostr1		; ne = no, half
	call	outchr		; send it (release Host's output queue)
	jmp	short ihostr1
ihostr2:cmp	flags.comflg,4		; using uart?
	ja	ihostr1			; a = no, ignore situation
	push	dx
	mov	dx,modem.mddat		; serial port base address
	add	dx,4			; increment to control register
	in	al,dx
	or	al,2			; assert RTS for flow-on
	push	ax
	in	al,ppi_port		; delay
	pop	ax
	out	dx,al
	and	xofsnt,off		; remember we've sent the "xon"
	pop	dx
ihostr1:pop	cx
	pop	bx
	pop	ax
	ret
IHOSTR	ENDP

; Send a break out the current serial port.  Returns normally.
; Do both regular and long Break.
; Networks use flags.comflg so that more than one net can be active
SENDBR	PROC	NEAR
	push	cx		; Regular Break entry point
	mov	cx,275		; 275 milliseconds in regular Break
	call	sendbw		; call worker routine to do it
	pop	cx
	mov	flags.cxzflg,0	; clear in case Control-Break
	clc			; don't exit Connect mode
	ret
SENDBL:	push	cx		; Long Break entry point
	mov	cx,1800		; 1.8 second long break
	call	sendbw		; call worker routine to do it
	pop	cx
	mov	flags.cxzflg,0	; clear in case Control-Break
	clc			; don't exit Connect mode
	ret
				; worker - send Break for cx millisec
sendbw:	mov	al,flags.comflg	; get type of port
	cmp	al,4		; running on a UART or network?
	ja	sendbw2		; a = network
	push	dx		; UART BREAK
	mov	dx,modem.mdcom	; port address
	in	al,dx		; get current setting
	push	ax		; save setting on the stack
	or	al,brkbit	; set send-break bit(s)
	out	dx,al		; start the break
	mov	ax,cx		; # of ms to wait
	call	pcwait		; hold break for desired interval
	pop	ax		; restore Line Control Register
	out	dx,al		; stop the break
	pop	dx
	ret
sendbw2:
ifndef	no_network
	cmp	al,'N'		; is this a NetBios network port?
	jne	sendbw3		; ne = no
	cmp	starlan,0	; STARLAN: network break supported?
	jne	sendbw2a	; ne = no
	push	bx
	push	es		; save es around call
	push	ds
	pop	es		; make es:bx point to scb in data segment
	mov	bx,offset can	; use Cancel control block
	mov	can.scb_cmd,netbrk ; send net Break command
	int	5bh		; use network Break interrupt
	pop	es		; saved registers
	pop	bx
sendbw2a:ret

sendbw3:cmp	al,'E'			; EBIOS?
	jne	sendbw6			; ne = no
	test	nettype,acsi		; using EBIOS.COM?
	jnz	sendbw4			; nz = no
	push	ax
	push	dx
	mov	dx,ebport		; port 0..3
	mov	ah,ebbreak		; EBIOS send BREAK
	int	rs232			; bios send
	pop	dx
	pop	ax
	ret
sendbw4:call	send			; send current buffer first
	mov	word ptr xmtbufx,4	; four bytes in packet
	mov	word ptr xmtbufx+2,acbreak*256+0 ; BREAK cmd, null char
	call	send			; send the command
	ret

sendbw6:cmp	al,'U'			; UB NETCI or Novell NASI/NACS?
	je	sendbw6a		; e = yes
	cmp	al,'W'			; NASI/NACS?
	jne	sendbw7			; ne = no
sendbw6a:push	cx			; UB port send break		 [ohl]
	mov	ax,ncicont+0	; call control, use 0 for network port num
	mov	cl,ncibrk		; request break			 [ohl]
	int	netci		; Net/One command interface int. (6Bh)	 [ohl]
	pop	cx
	ret

sendbw7:cmp	al,'M'			; Meridian SuperLAT?
	je	sendbw7a		; e = yes
	cmp	al,'D'			; DECnet?
	jne	sendbw9			; ne = no
	test	nettype,declat		; LAT?
	jz	sendbw9			; z = no, CTERM cannot send a BREAK
sendbw7a:mov	ax,latbreak		; LAT BREAK command
	push	dx
	mov	dx,lathand		; LAT handle
	int	latint
	pop	dx
	ret

sendbw9:cmp	al,'C'			; 3Com BAPI or TCP Telnet?
	je	sendbw9a		; e = yes
	cmp	al,'t'
	jne	sendbw10		; ne = no
sendbw9a:mov	ah,bapibrk		; BAPI, send BREAK
	xor	dh,dh			; session id of 0 (external sessions)
ifndef	no_tcp
	cmp	al,'t'			; TCP/IP Telnet?
	jne	sendbw9b		; ne = no
	call	ktcpcom			; Far call TCP/IP Telnet code
	ret
endif	; no_tcp
sendbw9b:int	bapiint
	ret
sendbw10:cmp	al,'T'			; Novell TELAPI?
	jne	sendbw11		; ne = no
	mov	ah,255			; Telnet Interpret As Command char
	call	outchr			; send it
	mov	ah,244			; Telnet Interrupt Process char
	call	outchr			; send it
	ret
sendbw11:cmp	al,'I'			; TES?
	jne	sendbw12		; ne = no
	cmp	latkind,TES_LAT		; using LAT?
	jne	sendbw11a		; ne = no, older TES
	mov	ax,latbreak		; LAT BREAK command
	push	dx
	mov	dx,lathand		; LAT handle
	int	latint
	pop	dx
	ret
sendbw11a:mov	ah,testalk		; get command interpreter
	mov	dx,tesport
	int	rs232
	ret
sendbw12:mov	ax,8000h		; Artisoft Int 14h interceptor
	int	rs232			; presence check
	cmp	al,0ffh			; present?
	jne	sendbw13		; ne = no
	push	bx
	push	dx
	push	cx
	mov	dl,flags.comflg		; get type of port
	sub	dl,'4'			; Bios port
	xor	dh,dh
	push	es
	push	di
	mov	di,seg xmtbufx		; temp buf
	mov	es,di
	mov	di,offset xmtbufx
	mov	xmtbufx+37,7		; default to 9600 bps index value
	mov	ax,8007h		; Artisoft, Get_Redirected_Port
	int	rs232		;  info to es:di buffer (c set if failure)
	pop	di
	pop	es
	xor	bx,bx			; no parity (bh) one stop bit (bl)
	mov	cl,xmtbufx+37		; returned baud rate index
	mov	ch,3			; 8 data bits
	mov	ax,0400h	; extended init (4), set BREAK condition (0)
	int	rs232
	pop	cx
	mov	ax,cx			; # of ms to wait
	call	pcwait			; hold break for desired interval
	mov	dl,flags.comflg		; get type of port
	sub	dl,'4'			; Bios port
	xor	dh,dh
	xor	bx,bx			; no parity (bh) one stop bit (bl)
	mov	cl,xmtbufx+37		; returned baud rate index
	mov	ch,3			; 8 data bits
	mov	ax,0401h	; extended init (4), set no BREAK condition (1)
	int	rs232
	pop	dx
	pop	bx
sendbw13:ret
endif	; no_network
SENDBR	ENDP

; Initialization for using serial port.  This routine performs
; any initialization necessary for using the serial port, including
; setting up interrupt routines, setting buffer pointers, etc.
; Doing this twice in a row should be harmless (this version checks
; a flag and returns if initialization has already been done).
; SERRST below should restore any interrupt vectors that this changes.
;
; Revised slightly by Joe R. Doupnik 22 Dec 1985 to prevent interrupts
; being enabled until we're done, to stop interrupts from occurring when
; TX holding buffer becomes empty (a useless interrupt for us), and to
; shorten the time between enabling interrupts and our exit.
; Returns carry clear if success, else carry set.
; 9 July 1989 Add support for 16550/A 14 char receiver fifo.
SERINI	PROC	NEAR
	call	pcwtst			; recalibrate pcwait loop timer
	cmp	portin,0		; did we initialize port already?
	je	serin4			; e = yes
	jl	serin3			; l = no, not yet
	jmp	serin30			; yes, update flow and leave
serin3:	mov	bl,flags.comflg		; pass current port ident
	mov	portin,0		; say have been here once
	call	comstrt			; do SET PORT now
	jnc	serin4			; nc = success
	ret				; failed, exit now
serin4:	push	bx
	mov	bx,portval
	mov	bl,[bx].duplex		; get full/half duplex flag, local cpy
	mov	dupflg,bl
	pop	bx
	mov	cardet,0		; assume no Carrier is Detected
	cmp	flags.comflg,4		; UART?
	jbe	serin5			; be = yes, real thing
	jmp	serin8			; else try other port kinds

serin5:	push	bx
	push	es
	mov	dx,modem.mdmintc	; interrupt controller
	inc	dx			; look at interrupt mask
	in	al,dx			; get interrupt mask
	mov	savirq,al		; save state here for restoration
	or	al,modem.mddis		; inhibit our IRQ
	out	dx,al
	mov	al,byte ptr modem.mdintv ; desired interrupt vector
	mov	ah,35H			; Int 21H, function 35H = Get Vector
	int	dos			; get vector into es:bx
	mov	word ptr savsci,bx    ; save address offset of original vector
	mov	word ptr savsci+2,es 	;  and its segment
	mov	al,byte ptr modem.mdintv ; interrupt number for IRQ
	mov	dx,offset serint	; offset of our interrupt routine
	push	ds			; save ds around next DOS call
	mov	bx,seg serint		; compose full address of our routine
	mov	ds,bx			; segment is the code segment
	mov	ah,setintv		; set interrupt address from ds:dx
	int	dos
	pop	ds
	mov	al,rs232		; interrupt number for Bios serial port
	mov	ah,getintv		; get vector into es:bx
	int	dos
	mov	word ptr sav232,bx	; save offset
	mov	word ptr sav232+2,es	; save segment
	mov	dx,offset serdum	; offset of our interrupt routine
	push	ds			; save ds around next DOS call
	mov	bx,seg serdum		; compose full address of our routine
	mov	ds,bx			; segment is the code segment
	mov	ah,setintv		; set interrupt address from ds:dx
	int	dos
	pop	ds
	pop	es
	pop	bx
	mov	portin,1		; Remember port has been initialized
	mov	ax,modem.mdstat
	mov	mst,ax			; Use this address for status
	mov	ax,modem.mddat
	mov	mdat,ax			; Use this address for data
	mov	ax,modem.mdiir
	mov	miir,ax			; uart interrupt ident register
	mov	al,modem.mdmeoi
	mov	mdeoi,al		; Use to signify end-of-interrupt
	mov	ax,modem.mdmintc	; interrupt controller control addr
	mov	mdintc,ax		; 
	mov	dx,modem.mdstat		; uart line status register, 03fdh
	inc	dx
	in	al,dx			; 03feh, modem status reg
	mov	ah,80h+20h		; CD + DSR bits
	and	al,ah			; select bits
	cmp	al,ah			; test CD + DSR bits
	je	serin5c			; e = both are on, don't reset UART
	call	delay
	mov	dx,modem.mdcom
	inc	dx			; modem control register (3fch)
	mov	al,0fh			; set DTR, RTS, OUT1, OUT2
	out	dx,al
	call	delay
serin5c:mov	dx,modem.mdcom		; set up serial card Line Control Reg
	in	al,dx			; get present settings
	mov	savlcr,al		; save them for restoration
	call	delay			; Telepath with this delay removed
	mov	al,3			; 8 data bits. DLAB = 0
	mov	bx,portval
	test	[bx].parflg,PARHARDWARE	; using hardware parity?
	jz	serin5h			; z = no
	cmp	[bx].parflg,PAREVNH	; even parity?
	jne	serin5e			; ne = no
	or	al,18h
	jmp	short serin5h
serin5e:cmp	[bx].parflg,PARODDH	; odd parity?
	jne	serin5f			; ne = no
	or	al,08h
	jmp	short serin5h
serin5f:cmp	[bx].parflg,PARMRKH	; mark parity?
	jne	serin5g			; ne = no
	or	al,20h+18h		; set sticky parity bit (20h)
	jmp	short serin5h
serin5g:or	al,20h+08h		; space parity
serin5h:cmp	[bx].stopbits,1		; one stop bit?
	je	serin5d			; e = yes
	or	al,4			; set bit 2^2 to 1 for two stop bits
serin5d:out	dx,al
	call	delay			; Telepath fails if this is removed
	mov	dx,modem.mddat
	inc	dx			; int enable reg (03f9)
	in	al,dx
	mov	savier,al		; save for restoration
					; drain UART for broken SMC FDC37C665
					; UART emulation. Must be before 16550
					; testing.
serin5a:mov	dx,modem.mdstat		; UART line status reg
	in	al,dx
	call	delay
	test	al,1			; data ready?
	jz	serin5b			; z = no
	mov	dx,modem.mddat		; UART data register
	in	al,dx			; read the received character into al
	call	delay
	jmp	short serin5a		; end SMC broken
serin5b:
	mov	dx,modem.mdiir		; Interrupt Ident reg (03fah)
	in	al,dx			; read current setting
	call	delay			; Telepath fails if this is removed
	mov	al,087h	; 8 byte trigger (80), reset fifos (2/4), Rx fifo(1) 
	out	dx,al
	mov	modem.mdfifo,al		; assume FIFO is active
	call	delay			; Telepath fails if this is removed
	in	al,dx			; read back iir
	and	al,0c0h	; select BOTH fifo bits: 16550A vs 16550 (bad fifo)
	mov	bl,flags.comflg		; get current port ident (1..4)
	dec	bl			; count from 0
	and	bx,3			; stay sane
	cmp	portfifo[bx],0		; FIFO mode allowed?
	je	serin5i			; e = no, shut it off
	cmp	al,0c0h			; are both fifo enabled bits set?
	je 	serin6			; e = yes, rcvr fifo is ok (16550/A)
serin5i:call	delay			; Telepath fails if this is removed
	xor	al,al			; else turn off fifo mode (16550/etc)
	out	dx,al
	mov	modem.mdfifo,al		; say no FIFO
	call	delay
serin6:	mov	dx,modem.mddat	   ; data and command port, read and flush any	
	in	al,dx			; char in UART's receive buffer
	inc	dx		  	; interrupt enable register 3f9h
	call	delay			; Telepath fails if this is removed
	mov	al,1			; set up interrupt enable register
	out	dx,al			;  for Data Available only
	call	delay			; Telepath fails if this is removed
	add	dx,3		   	; modem control register 3fch
	in	al,dx			; read original
	mov	savstat,al		; save original
	mov	al,0bh		  	; assert DTR, RTS, not OUT1, and OUT2
	cmp	dupflg,0		; full duplex?
	je	serin7			; e = yes
	mov	al,9h			; assert DTR, not RTS, not OUT1, OUT2
serin7:	cli
	out	dx,al		  ; OUT2 high turns on interrupt driver chip
	mov	dx,modem.mdiir		; Interrupt Ident reg (03fah)
	in	al,dx			; read current setting
	mov	dx,mdintc		; interrupt controller cntl address
	inc	dx			; access OCW1, interrupt mask byte
	in	al,dx			; get 8259 interrupt mask
	and	al,modem.mden		; enable IRQ. (bit=0 means enable)
	out	dx,al			; rewrite interrupt mask byte
	sti
	jmp	serin30			; finish up

serin8:	mov	al,flags.comflg
	cmp	al,'F'			; Fossil?
	jne	serin8a			; ne = no
	mov	dx,fossil_port		; trust not the shabby shells
	mov	ah,fossil_init		; Fossil, init port in dx
	xor	bx,bx			; no Control-C nonsense
	int	rs232
	mov	ah,fossil_dtr		; Fossil, DTR control
	mov	al,1			; raise DTR
	mov	dx,fossil_port		; port to use
	int	rs232
	push	bx
	mov	bx,portval		; get port data structure
	mov	al,[bx].floflg		; flow control kind
	pop	bx
	or	al,al			; if flow of none
	jz	serin8c			; z = none
	cmp	al,2			; xon/xoff?
	jne	serin8b			; ne = no
	mov	al,5			; Fossil xon/xoff
	jmp	short serin8c
serin8b:mov	al,2			; RTS/CTS
serin8c:mov	ah,fossil_flow
	int	rs232			; set flow control
	jmp	serin30			; finish up

serin8a:
ifndef	no_network
	cmp	al,'N'			; NetBios?
	je	serin9			; e = yes
	cmp	al,'O'			; Opennet Network? (FGR)
	jne	serin11			; ne = no
serin9:	mov	port_nb.portrdy,0	; say port is not ready yet
	call	setnet			; setup network session and pcnet flag
	jc	serin10			; c = failed
	jmp	serin30			; nc = success
serin10:ret				; fail, carry set, leave portin at 0
serin11:cmp	al,'E'			; using EBIOS?
	jne	serin13			; ne = no
	test	nettype,acsi		; using EBIOS.COM?
	jnz	serin9			; nz = not using it
	mov	bx,offset ebcoms	; es:bx to ebcoms structure
	mov	ebcoms+1,80h		; force a network connection
	mov	ah,ebredir		; do redirection
	xor	al,al
	mov	dx,ebport
	int	rs232
	or	ax,ax
	jz	serin12			; ax = 0 is success
	stc				; fail
	ret
serin12:mov	dx,ebport		; port 0..3
	mov	bx,offset rcvbuf	; receive buffer for EBIOS
	push	es
	mov	ax,ds
	mov	es,ax			; set es:bx to the buffer address
	mov	cx,nbuflen		; set cx to buffer's length
	mov	ax,ebbufset*256+2	; set rcvr buffered mode
	int	rs232
	mov	cx,nbuflen
	mov	bx,offset xmtbuf	; EBIOS transmitter work buffer
	mov	ax,ebbufset*256+1	; set xmtr buffered mode
	int	rs232
	mov	ax,ebmodem*256+3	; set outgoing DTR and RTS modem leads
	int	rs232			;  and ignore incoming leads
	mov	pcnet,1
	pop	es
	jmp	serin30
serin13:cmp	al,'D'			; DECnet?
	jne	serin14			; ne = no
	call	decstrt			; reinit
	jnc	serin30			; nc = success
	ret				; fail, carry set, leave portin at 0
serin14:cmp	al,'T'			; Novell TELAPI?
	jne	serin15			; ne = no
	cmp	pcnet,2			; going already?
	je	serin30			; e = yes
	call	telstrt			; start Telnet session
	jnc	serin30			; nc = success
	call	telapiclose		; close session
	stc
	ret				; fail, leave portin at 0
serin15:cmp	al,'M'			; Meridian SuperLAT?
	je	serin15a		; e = yes
	cmp	al,'I'			; TES?
	jne	serin17			; ne = no
	cmp	latkind,TES_LAT		; using LAT?
	jne	serin16			; ne = no, older style
serin15a:call	decstrt			; reinit
	jnc	serin30			; nc = success
	ret				; fail, carry set, leave portin at 0
serin16:call	tesstrt			; start a TES session
	jnc	serin30			; nc = success
	mov	ax,2000			; pause 2 sec for any msg
	call	pcwait
	stc
	ret
serin17:
ifndef	no_tcp
	cmp	al,'t'			; TCP/IP?
	jne	serin18			; ne = no
	call	tcpstart		; start TCP connection
	jnc	serin30
	push	bx
	mov	bx,portval		; get port data structure
	mov	[bx].portrdy,0		; say the comms port is not ready
	mov	portin,0
	pop	bx
	stc
	ret				; fail
endif	; no_tcp
serin18:cmp	al,'U'			; Ungermann Bass?
	je	serin20			; e = yes
	cmp	al,'C'			; 3Com BAPI?
	je	serin20			; e = yes
serin19:cmp	al,'b'			; [JRS] Beame & Whiteside TCP
	jne	serin20			; [JRS] ne = no
	call	bwstart			; [JRS] start a Telnet session w/BWTCP
	jnc	serin30			; [JRS] nc = success
	ret				; [JRS]
serin20:mov	bl,al			; preset net type
	call	comstrt			; start net
	jnc	serin30
	ret				; c = failure
endif	; no_network

serin30:push	bx
	mov	bx,portval		; get port data structure
	mov	[bx].portrdy,1		; say the comms port is ready
	mov	parmsk,0ffh		; parity mask, assume parity is None
	cmp	[bx].parflg,parnon	; is it None?
	je	serin31			; e = yes
	mov	parmsk,07fh		; no, pass lower 7 bits as data
serin31:xor	ax,ax
	mov	al,[bx].floflg		; flow control kind
	mov	flowcnt,al		; save here for active use
	mov	ax,[bx].flowc		; get flow control chars
	pop	bx
	mov	flowoff,al		; xoff or null
	mov	flowon,ah		; xon or null
	mov	xofrcv,off		; clear xoff received flag
	call	testcd			; update cardet byte
	mov	quechar,0		; clear outchr queued flow control
	call	clrclock		; clear elapsed time clock if req'd
	mov	portin,1		; say initialized
	clc				; carry clear for success
	ret				; We're done
SERINI	ENDP

; Gateway 2000 Telepath internal modem extra delay routine
delay	proc	near
	push	ax
	mov	ax,1			; 1 millisecond
	call	pcwait
	pop	ax
	ret
delay	endp

; Set session start time of day, if starttime+3 or reset_clock are 
; non-zero. Forces both to zero afterward.
clrclock proc	near
	push	bx
	mov	bx,portval
	xor	ax,ax
	xchg	starttime[bx+3],al	; get and clear clock reset byte
	xchg	reset_clock,ah		; from set port command
	or	ax,ax			; reset clock?
	jz	clrclk2			; z = no
	mov	ah,gettim		; read DOS tod clock
	int	dos			; ch=hours, cl=minutes, dh=seconds
	mov	al,60
	mul	ch			; hours to minutes in ax
	add	al,cl			; plus minutes
	adc	ah,0
	mov	bl,dh			; save seconds in bx
	xor	bh,bh
	mov	cx,60
	mul	cx			; hh+mm to seconds in dx:ax
	add	ax,bx			; plus seconds
	adc	dx,0			; total seconds in dx:ax
	mov	bx,portval
	cmp	flags.comflg,'t'	; doing TCP/IP Telnet?
	je	clrclk1			; e = yes
	mov	word ptr starttime[bx],ax
	mov	word ptr starttime[bx+2],dx
	jmp	short clrclk2
clrclk1:
ifndef	no_terminal
ifndef	no_tcp
	mov	bx,sescur		; current session ident
	js	clrclk2			; s = invalid session
	shl	bx,1
	shl	bx,1			; quad bytes
	mov	word ptr sestime[bx],ax
	mov	word ptr sestime[bx+2],dx
endif	; no_tcp
endif	; no_terminal
clrclk2:pop	bx
	ret
clrclock endp

; Reset the serial port.  This is the opposite of serini.  Calling
; this twice without intervening calls to serini should be harmless.
; Moved push/pop es code to do quicker exit before interrupts enabled.
; Returns normally.
; 22 June 1986 Leave OUT1 low to avoid resetting Hayes 1200B's. [jrd]
; 21 Feb 1987 Add support for Bios calls [jrd]
; 17 May 1987 Redo for COM3/4 support [jrd]
; 9 July 1989 Accomodate 16550/A receiver fifo mode. [jrd]
SERRST	PROC	NEAR
	cmp	portin,0		; Reset already? 
	jg	srst3			; g = no
	clc
	ret				; e = yes, l=not used yet, just leave
srst3:	cmp	flags.comflg,'0'	; Bios or networks?
	jb	srst4			; b = no, real UART
	jmp	srst6			; finish up

srst4:	push	word ptr savsci		; save original interrupt owner
	push	word ptr savsci+2	; offset and segment
	mov	word ptr savsci,offset nulint ; redirect to our null routine
	mov	ax,seg nulint		; segment of null routine is code
	mov	word ptr savsci+2,ax
	xor	cx,cx			; loop counter
srst2:	mov	dx,modem.mdstat		; status register
	in	al,dx
	call	delay			; delay
        and     al,60h			; Shift Reg Empty & Holding Reg Empty
        cmp     al,60h			; are both set?
        loopne  srst2           	; ne = no, wait until so (or timeout)
	xor	al,al
	mov	dx,modem.mdiir		; modem Interrupt Ident reg (03fah)
	out	dx,al			; turn off FIFO mode
	call	delay
	dec	dx			; point at int enable reg 3f9h
	out	dx,al			; disable interrupts from this source
	call	delay			; delay, let stray ints occur now
	add	dx,2			; point at Line Control Register 3fbh
	mov	al,savlcr		; saved bit pattern
	and	al,not 80h		; force DLAB bit to 0
	out	dx,al			; restore line control state
	call	delay
		; clear modem's delta status bits and reassert DTR etc
	inc	dx		; increment to modem control register 3fch
	mov	al,savstat		; saved modem control reg (03fch)
	or	al,3			; ensure DTR and RTS are asserted
	cmp	dupflg,0		; full duplex?
	je	srst2a			; e = yes
	xor	cx,cx
	push	dx			; save dx around test below
srst2b:	mov	dx,modem.mdstat		; modem line status reg
	in	al,dx			; read transmitter shift reg empty bit
	call	delay
	test	al,40h			; is it empty?
	loopz	srst2b			; z = no, not yet
	pop	dx
	mov	al,savstat		; saved modem control reg
	or	al,1			; assert DTR
	and	al,not 2		; unassert RTS
srst2a:	out	dx,al			; restore modem control reg (03fch)
	call	delay		; pause, in case stray interrupt is generated
	add	dx,2			; modem status register 3feh
	in	al,dx			; clear status register by reading it
	mov	mdmhand,al		; save here for Show Modem
	cli				; Disable interrupts
	mov	dx,modem.mdmintc
	inc	dx
	in	al,dx			; Interrupt controller int mask
	or	al,modem.mddis		; inhibit our IRQ line
	push	ax
	in	al,ppi_port		; delay
	pop	ax
	out	dx,al
	sti
	pop	word ptr savsci+2	; recover original int owner's addr
	pop	word ptr savsci
					; replace original IRQ intrpt vector
	push	bx
	mov	al,byte ptr modem.mdintv ; vector number to do
	mov	dx,word ptr savsci 	; offset part
	push	ds
	mov	bx,word ptr savsci+2	; segment part
	mov	ds,bx			; ds:dx has interrupt vector
	mov	ah,setintv		; set interrupt vector
	int	dos			; replaced
	pop	ds
	mov	al,rs232	; Bios serial port interrupt vector to restore
	mov	dx,word ptr sav232	; offset part
	push	ds
	mov	bx,word ptr sav232+2	; segment part
	mov	ds,bx
	mov	ah,setintv		; set interrupt vector
	int	dos
	pop	ds
	pop	bx
	mov	ah,savirq		; saved Interrupt state
	and	ah,modem.mddis		; pick out our IRQ bit
	mov	dx,modem.mdmintc	; interrupt controller cntl address
	cli
	inc	dx
	in	al,dx			; get current intrpt controller state
	push	ax
	in	al,ppi_port		; delay
	pop	ax
	and	al,modem.mden		; set our bit to zero
	or	al,ah			; set previous state of our IRQ
	out	dx,al			; reset IRQ to original state
	sti
	mov	dx,modem.mddat		; base address, 03f8h
	inc	dx	      		; Interrupt Enable Reg (03f9h)
	mov	al,savier		; saved IER
	out	dx,al			; restore setting
	jmp	short srst9
					; non-UART processes
srst6:
ifndef	no_network
	cmp	pcnet,0			; a network active?
	je	srst8			; e = no
	cmp	flags.comflg,'O'	; Opennet network? (FGR)
	je      srst7			; e = yes
 	cmp	flags.comflg,'N'	; NetBios network?
  	jne	srst8			; ne = no
srst7:	cmp	rposted,0		; receive outstanding?
	je	srst8			; e = no
	mov	can.scb_baddr,offset rcv ; cancel receives
	push	bx
	mov	bx,offset can
	call	nbsession
	pop	bx
	mov	rposted,0		; clear interlock flag no matter what
	cmp	lposted,0		; Listen posted?
	jne	srst8			; ne = yes, don't post another
	call	nbclose			; shut down NetBIOS
endif	; no_network
srst8:	cmp	flags.comflg,'F'	; Fossil?
	jne	srst9			; ne = no
	cmp	fossilflag,0		; shut down port when done?
	je	srst9			; e = no
	mov	dx,fossil_port		; port
	mov	ah,fossil_done		; fossil, done with driver
	int	rs232
srst9:	mov	portin,0		; reset flag
	push	bx
	mov	bx,portval		; port data structure
	mov	[bx].portrdy,0		; say port is not ready
	pop	bx
	mov	quechar,0		; clear any outchr queued char
	clc
	ret
SERRST	ENDP
code	ends

code1	segment
	assume	cs:code1
; Null interrupt routine, to handle strays
nulint	proc	near
	push	ax
	push	dx
	push	ds
	mov	ax,data			; set data seg addressibility
	mov	ds,ax
	mov	al,mdeoi		; specific EOI
	mov	dx,mdintc		; interrupt controller control word
	out	dx,al
	test	dl,80h			; slave controller?
	jz	nulint1			; z = no
	mov	al,20h			; general EOI
	out	20h,al			; EOI to master 8259
nulint1:pop	ds
	pop	dx
	pop	ax
	iret
nulint	endp

; Dummy Interrupt 14H to defeat DOS interference with serial port when CTTY
; and Kermit use the port simultaneously. If ports differ then chain DOS to
; original Int 14H Bios code. Else return dummy status=ok reports and
; Backspace for Read, ignore char for Write.
; Entered with AH = function request, AL = char to be sent, DX = com port num
; CS is our code segment, DS is DOS's, SS is ours or DOS's, interrupts off.
; 25 June 1987 [jrd]
SERDUM	PROC	FAR
	push	ds			; preserve all registers
	push	ax
	mov	ax,seg data		; get our data segment
	mov	ds,ax
	mov	al,flags.comflg		; get port id (COM1 = 1, COM2 = 2)
	and	al,7			; use lower three bits
	dec	al			; DOS counts COM1 as 0, etc
	mov	dosctty,0		; assume DOS not using our comms line
	cmp	dl,al		; referencing same port as Kermit is using?
	pop	ax			; recover request parameters
	jne	serdu1			; ne = no, chain to Bios routine
	mov	dosctty,1		; say DOS is using our comms line
	pop	ds
	cmp	ah,1			; send char in al?
	jb	serdu3			; b = no, init, return dummy status=ok
	ja	serdu2			; a = no, other
	mov	ah,60h			; yes, set line status=ok in ah
	iret
serdu2:	cmp	ah,2			; receive char (and wait for it)?
	jne	serdu3			; ne = no, return dummy report
	mov	al,BS			; yes, return ascii BS to DOS
	xor	ah,ah			; ah = errors (none here)
	iret
serdu3:	mov	ax,60b0h		; dummy status report:xmtr empty, CD,
	iret				;  DSR, and CTS are on

serdu1:	pop	tempdum			; save old ds
	push	word ptr sav232+2	; push Bios int 14H handler segment
	push	word ptr sav232		; push Bios int 14H handler offset
	push	tempdum			; recover old ds
	pop	ds
	ret				; do a ret far (chain to Bios)
SERDUM	ENDP

; Serial port interrupt routine.  This is not accessible outside this
; module, handles serial port receiver interrupts.
; Revised on 22 May 1986, again 2 August 1986 to run at 38.4kb on PC's.
; Srcpnt holds offset, within buffer Source, where next rcv'd char goes.
; Count is number of chars now in buffer, and oldest char is srcpnt-count
; done modulo size of Source. All pointer management is handled here.
; Control-G char substituted for char(s) lost in overrun condition.
; Upgraded to read cause of interrupt from interrupt ident reg (accepts only
;  data ready), chain to old interrupt if source is not our device.
; 9 Feb 1988 Add storage of interrupt cause in intkind. [jrd]
; 9 July 1989 Add support for 16550/A 14 char receiver fifo.

SERINT  PROC  FAR
 	push	ax			; save registers
	push	dx			; 
	push	ds
	mov	ax,seg data
	mov	ds,ax			; address data segment
	mov	dx,miir			; modem interrupt ident reg
	in	al,dx			; get interrupt cause
	mov	intkind,al		; save cause here
	test	al,1		; interrupt available if this bit is zero
	jz	srintc			; z = interrupt is from our source
; temporary item to side step chaining for noisy buses and funny Bios'
;	push	ds			; preserve data seg addressibility
;	pushf				; call the old int handler
;	call	dword ptr savsci	;  via pseudo INT
;	pop	ds			; recover data seg
	and	intkind,not 4		; say not-data-ready, to exit below
srintc:	mov	al,mdeoi		; specific EOI
	mov	dx,mdintc		; interrupt controller control word
	out	dx,al
	test	dl,80h			; slave controller?
	jz	srintd			; z = no
	mov	al,22h			; specific EOI for IRQ 2 (cascade)
	out	20h,al			; EOI the master 8259
srintd:	test	intkind,4		; data ready?
	jnz	srint0a			; nz = yes, else ignore
srint0:	sti				; else turn on interrupts
	jmp	retint			;  and exit now (common jump point)

srint0a:mov	dx,mst			; asynch status	port
	in	al,dx
srint0b:cli				; no interrupts permitted here
	and	al,mdmover		; select overrun bit
	mov	ah,al			; save it for later
	mov	dx,mdat
	in	al,dx			; read the received character into al
	test	flowcnt,2		; incoming XON/XOFF flow control?
	jz	srint2			; z = no
	mov	dh,al		   	; dh = working copy. Check flow cntl
	and	dh,parmsk		; strip parity temporarily, if any
	cmp	dh,flowoff		; acting on Xoff?
	jne	srint1			; ne = no, go on
	cmp	xofsnt,0		; have we sent an outstanding XOFF?
	jne	srint4e			; ne = yes, ignore (possible echo)
	mov	xofrcv,bufon		; set the flag saying XOFF received
	jmp	short srint4e		;  and continue the loop
srint1:	cmp	dh,flowon		; acting on Xon?
	jne	srint2			; ne = no, go on
	mov	xofrcv,off		; clear the XOFF received flag
	jmp	short srint4e		;  and continue the loop
srint2:	push	bx			; save register
	or	ah,ah			; overrun?
	jz	srint2a			; z = no
	mov	ah,al			; yes, save present char
	mov	al,bell			; insert control-G for missing char 
srint2a:mov	bx,srcpnt		; address of buffer storage slot
	mov	byte ptr [bx],al       ; store the new char in buffer "source"
	inc	srcpnt			; point to next slot
	inc	bx
	cmp	bx,offset source + bufsiz ; beyond end of buffer?
	jb	srint3			; b = not past end
	mov	srcpnt,offset source 	; wrap buffer around
srint3:	cmp	count,bufsiz		; filled already?
	jae	srint4			; ae = yes
	inc	count			; no, add a char
srint4:	or	ah,ah			; anything in overrun storage?
	jz	srint4a			; z = no
	mov	al,ah			; recover any recent char from overrun
	xor	ah,ah			; clear overrun storage
	jmp	short srint2a		; yes, go store real second char
srint4a:pop	bx			; restore reg
srint4e:mov	dx,mst			; uart line status register, 03fdh
	in	al,dx			; get status
	test	al,1			; data ready?
	jnz	srint0b			; nz = yes, and preserve al
	sti			     ; ok to allow interrupts now, not before
	cmp	count,mntrgh		; past the high trigger point?
	jbe	retint			; be = no, we're within our limit
	test	xofsnt,bufon	    ; has an XOFF been sent by buffer control?
	jnz	retint			; nz = Yes
	test	flowcnt,4		; using RTS/CTS flow control?
	jz	srint4b			; z = no
	mov	dx,mst			; modem status port (03fdh)
	dec	dx			; modem control reg (03fch)
	in	al,dx
	and	al,not 2		; reset RTS bit
	push	ax
	in	al,ppi_port		; delay
	pop	ax
	out	dx,al			; tell the UART to drop RTS
	mov	xofsnt,bufon	   	; remember RTS reset at buffer level
	jmp	short retint

srint4b:test	flowcnt,1		; send outgoing XON/XOFF?
	jz	retint			; z = no
	mov	al,flowoff		; get the flow off char (XOFF or null)
	push	bx
	mov	bx,portval
	cmp	[bx].baud,Bsplit	; doing 75/1200 baud stuff?
	pop	bx
	jne	srint4c			; ne = no
	mov	quechar,al		; put char in outchr queue for sending
	cmp	timeract,0		; is timer being used at task level?
	jne	srint4d			; ne = yes, just queue the char
	mov	ah,al			; put char into ah
	call	foutchr			; send the char now, non-blocking
srint4d:jmp	short retint

srint4c:call	fdopar			; set parity appropriately
	mov	ah,al		       ; don't overwrite character with status
	push	cx			; save reg
	xor	cx,cx			; loop counter
srint5:	mov	dx,mst			; get port status
	in	al,dx
	test	al,20H			; transmitter ready?
	jnz	srint6			; nz = yes
	in	al,ppi_port		; delay
	in	al,ppi_port		; delay
	in	al,ppi_port		; delay
	loop	srint5			; else wait loop, cx times
	jmp	short srint7		; timeout
srint6:	mov	al,ah			; now send out the flow control char
	mov	dx,modem.mddat
	push	ax
	in	al,ppi_port		; delay
	pop	ax
	out	dx,al
	mov	xofsnt,bufon	   ; remember we sent an XOFF at buffer level
srint7:	pop	cx			; restore reg
retint:	pop	ds
	pop	dx
	pop	ax
	iret
SERINT	ENDP

; Update cardet byte for UART, Bios and Fossil ports
testcd	proc	far
	cmp	flags.carrier,0		; worry about carrier detect?
	je	testcdx			; e = no
	push	ax
	push	dx
	mov	al,flags.comflg
	cmp	al,4			; UART?
	jbe	testcd1			; e = yes
	cmp	al,'4'			; BIOS?
	je	testcd2			; e = yes
	cmp	al,'F'			; Fossil?
	je	testcd3			; e = yes
	pop	dx
	pop	ax
	jmp	short testcdx		; can't get CD for the rest
testcd1:mov	dx,modem.mddat		; UART
	add	dx,6			; modem status reg 3feh
	in	al,dx			; 03feh, modem status reg
	jmp	short testcd4
testcd2:mov	ah,3			; check port status, std Bios calls
	mov	dl,al			; port + bias
	sub	dl,'1'			; remove bias
	int	rs232			; Bios call
	jmp	short testcd4

testcd3:mov	dx,fossil_port		; get port number (1..4)
	mov	ah,fossil_portst	; check port status, std Bios calls
	int	rs232			; Bios call

testcd4:and	al,80h			; get CD bit
	jnz	testcd5			; nz = CD is on now
	test	cardet,80h		; previous CD state
	jz	testcd5			; z = was off, still is
	mov	al,01h			; say was ON but is now OFF
	mov	flags.cxzflg,'C'	; simulate Control-C interrupt
testcd5:mov	cardet,al		; preserve as global
	pop	dx
	pop	ax
testcdx:ret
testcd	endp
code1	ends

code	segment
	assume	cs:code

DTRLOW	PROC	NEAR		; Global proc to Hangup the Phone or Network
				; by making DTR and RTS low (phone).
	mov	ah,cmword	; allow text, to be able to display help
	mov	bx,offset rdbuf		; dummy buffer
	mov	dx,offset hnghlp	; help message
	call	comnd
	jc	dtrlow3			; c = failure
	mov	ah,cmeol
	call	comnd			; get a confirm
	jc	dtrlow3
	cmp	flags.comflg,'0'	; Bios?
	jb	dtrlow1			; b = no, UART
	cmp	flags.comflg,'4'	; Bios?
	jbe	dtrlow2			; be = yes, can't access modem lines
dtrlow1:call	serhng			; drop DTR and RTS
	cmp	taklev,0		; in a Take file or macro?
	jne	dtrlow2			; ne = yes, no message
	mov	ah,prstr		; give a nice message
	mov	dx,offset hngmsg
	int	dos
dtrlow2:clc				; success
dtrlow3:ret
DTRLOW	ENDP
 
; Hang up the Phone. Similar to SERRST except it just forces DTR and RTS low
; to terminate the connection. 29 March 1986 [jrd]
; 5 April 1987 Add 500 millisec wait with lines low before returning. [jrd]
; Calling this twice without intervening calls to serini should be harmless.
; If network then call session close procedure to hangup the session without
; losing local name information; serrst does this.
; Returns normally.

serhng	proc	near	; clear modem's delta status bits and lower DTR & RTS
	cmp	apctrap,0		; APC disable?
	je	shng1			; e = no
	stc				; fail
	ret
shng1:	call	serrst			; reset port so can be opened again
	cmp	flags.comflg,'F'	; Fossil?
	je	shng2			; e = yes
ifndef	no_network
	cmp	flags.comflg,4		; UART port?
	jbe	shng2			; be = yes
	push	bx
	mov	bx,portval
	call	[bx].cloproc		; close the active network session
	pop	bx
	clc
	ret
endif	; no_network

shng2:	call	serini			; energize, maybe for first time
	cmp	flags.comflg,'F'	; Fossil?
	jne	shng3			; ne = no
	push	ax
	push	dx
	mov	ah,fossil_dtr		; Fossil, DTR control
	xor	al,al			; lower DTR
	mov	dx,fossil_port		; port to use
	int	rs232
	call	serrst
	jmp	short shng4

shng3:	call	serrst			; back to sleep
	cli				; Disable interrupts
	push	ax
	push	dx
	mov	dx,modem.mddat		; serial port base address
	add	dx,4			; increment to control register
	mov	al,08h		       ; reassert OUT2, un-assert DTR,RTS,OUT1
	out	dx,al
	in	al,ppi_port		; delay
	add	dx,2			; increment to modem status register
	in	al,dx			; Clear Status reg by reading it
	sti				; Enable interrupts
shng4:	mov	ax,1000			; 1000 millisec, for pcwait
	call	pcwait		    ; keep lines low for at least 500 millisec
	pop	dx
	pop	ax
	clc
	ret
serhng	endp


; Compute number of iterations needed in procedure pcwait inner loop
; to do one millisecond delay increments. Uses Intel 8253/8254 timer chip
; (timer #2) to measure elapsed time assuming 1.193182 MHz clock.
; For IBM PC compatible machines.
pcwtst	proc	near
	push	cx
	mov	cx,10		; number of tests to perform
pcwtst1:call	pcwtst2		; do the test and new pcwcnt calculation
	loop	pcwtst1		; repeat several times for convergence
	pop	cx
	ret

pcwtst2:push	ax
	push	bx
	push	cx
	push	dx
	in	al,ppi_port	; 8255 chip port B, 61h
	and	al,0fch		; speaker off (bit 1), stop timer (bit 0)
	out	ppi_port,al	; do it
  ; 10 = timer 2, 11 = load low byte then high byte, 010 = mode 2, 0 = binary
	mov	al,10110100B	; command byte
	out	timercmd,al	; timer command port, 43h
	xor	al,al		; clear initial count for count-down
	out	timer2data,al	; low order byte of count preset, to port 42h
	out	timer2data,al	; high order byte, to the same place
	in	al,ppi_port	; get 8255 setting
	mov	dl,al		; remember it in dl
	and	al,0fch		; clear our control bits
	or	al,1	   	; start counter now (Gate = 1, speaker is off)
	out	ppi_port,al	; do it, OUT goes low
				; this is the test loop
	mov	ax,8		; wait 8 millisec
	call	pcwait		; call the software timer
				; end test loop
	mov	al,dl		; restore ppi port, stop timer
	out	ppi_port,al
	in	al,timer2data	; read count down value
	xchg	al,ah		; save low order byte
	in	al,timer2data	; get high order byte
	xchg	ah,al		; put in correct sequence
	neg	ax		; subtract from zero to get elapsed tics
	mov	bx,ax		; save observed tics
	mov	ax,pcwcnt	; current pcwcnt value
	; new pcwcnt= old pcwcnt * [1193(tics/ms) / (observed tics / loops)]
	mov	cx,8*1193
	mul	cx	
	or	bx,bx		; zero observed tics?
	jz	pcwtst3		; z = yes, divide by one
	cmp	dx,bx		; overflow?
	jb	pcwtst4		; b = not likely
	mov	ax,pcwcnt
	jmp	short pcwtst3	; bypass calculation
pcwtst4:div	bx		; divided by observed tics
pcwtst3:mov	pcwcnt,ax	; store quotient as new inner loop counter
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
pcwtst	endp

;; Wait for the # of milliseconds in ax, for non-IBM compatibles.
;; Thanks to Bernie Eiben for this one. Modified to use adjustable 
; inner loop counter (pcwcnt, adjusted by proc pcwtst) by [jrd].
pcwait	proc	FAR
	push	cx
	push	ds
	mov	cx,data
	mov	ds,cx
pcwai0:	mov	cx,pcwcnt	; inner loop counter for 1 ms
pcwai1:	push	ax
	in	al,PPI_PORT	; touch bus to deal with fast caches
	pop	ax
	sub	cx,1
	jnz	pcwai1
	dec	ax		; outer loop counter
	jnz	pcwai0		; wait another millisecond
	pop	ds
	pop	cx
	ret
pcwait	endp

ifndef	no_tcp
sesdisp	proc	near
	mov	ah,cmeol
	call	comnd
	jnc	sesdisp1
	ret
sesdisp1:call	fsesdisp		; located in seg code1
	ret
sesdisp	endp
endif

code	ends

code1	segment
	assume	cs:code1

ifndef	no_tcp
; TCP/IP Telnet session manager.
; Enter with SET PORT TCP/IP command line in buffer decbuf, 
; and <byte count> + <port number> + NUL + {NEW, RESUME} in decbuf+80
; Syntax of that line is
;   empty - resume current session, error return if none.
;   digit - start or resume session digit, with digit being a local number.
;   host  - ask if resume or new. If resume call ktcpswap, else tcpstart.
;    *    - server mode
; Returns sescur as index (0..maxsessions-1) for seslist action.
; Successful return is carry clear, else carry set. 

sesmgr	proc	far
ifndef	no_terminal
	push	bx
	mov	bx,sescur		; current session
	call	termswapout		; swap out current session's emulator
	pop	bx
endif	; no_terminal
	cmp	decbuf,1		; byte count, anything given?
	jb	sesmgr24		; b = no, use tcphost default
	ja	sesmgr40		; ja = yes, but more than one char
	mov	bl,decbuf+1		; get single char
	mov	al,bl
	and	al,not 20h		; upper case, for letters only
	jmp	short sesmgr13
	
sesmgr10:cmp	sescur,-1		; any session yet?
	je	sesmgr22		; e = no, use command line
	call	iseof			; are we at EOF, such as from disk?
	jc	sesmgr28		; c = yes, fail the command
	call	fsesdisp		; display the table for guidance, inc help
	mov	dx,offset seshelp
	mov	ah,prstr
	int	dos
	mov	flags.cxzflg,0		; clear Control-C flag
	mov	ax,0c0ah		; clear buffer and read line
	mov	decbuf+100,80		; length of our buffer
	mov	dx,offset decbuf+100	; start of buffer (len, cnt, data)
	int	dos
	cmp	flags.cxzflg,'C'	; Control-C entered?
	je	sesmgr28		; e = yes, quit
	mov	al,decbuf+101		; number of printables entered
	or	al,al			; need at least one
	jz	sesmgr15		; default is NEW
	mov	bl,decbuf+102		; get first byte
	mov	al,bl
	and	al,not 20h		; upper case, for letters only

sesmgr13:cmp	bl,'*'			; "*" for server mode?
	je	sesmgr40		; e = yes, use as host name
sesmgr13a:cmp	al,'R'			; RESUME current?
	jne	sesmgr14		; ne = no
	clc				; resume current session
	ret
sesmgr14:cmp	al,'Q'			; QUIT?
	je	sesmgr28		; e = yes, return failure
	cmp	al,'N'			; NEW?
	jne	sesmgr20		; ne = no

sesmgr15:mov	cx,maxsessions		; find an opening for NEW
	xor	bx,bx
sesmgr16:mov	al,seslist[bx]
	or	al,al			; session in use?
	jns	sesmgr18		; ns = yes
	mov	sescur,bx		; set current session ident
	jmp	short sesmgr22		; s = no
sesmgr18:inc	bx			; next slot
	loop	sesmgr16
	mov	dx,offset sesnone	; say no more sessions available
	mov	ah,prstr
	int	dos
	stc				; fail out
	ret
sesmgr20:xor	bh,bh			; ensure high byte is clear
	sub	bx,'1'			; assume digit 1..6, remove bias
	cmp	bx,6			; legal values are 0..5
	jae	sesmgr10		; ae = out of range
	mov	sescur,bx		; return slist index for action
	mov	al,bl
	mov	cx,seshostlen		; length of a table entry
	mul	cl			; skip to correct sesname
	cmp	decbuf,1		; host name given on command line?
	ja	sesmgr22		; a = yes, use it as host name
	mov	di,offset tcphost	; update active host name
	add	ax,offset sesname	; get host name from table
	mov	si,ax
	cmp	byte ptr [si],0		; any name present?
	jne	sesmgr20a		; ne = yes
	xchg	si,di			; use current name in tcphost
	jmp	short sesmgr26		; use existing tcpport too
sesmgr20a:push	bx
	shl	bx,1			; address words
	mov	ax,sesport[bx]
	mov	tcpport,ax		; set tcpport
	pop	bx
	jmp	short sesmgr26		; and switch terminal configuration

sesmgr22:push	bx
	mov	ax,tcpport		; tcp port
	mov	bx,sescur		; new session
	or	bx,bx			; negative, for no session?
	jns	sesmgr22a		; ns = not negative
	xor	bx,bx			; start session 0
	mov	sescur,bx
sesmgr22a:shl	bx,1			; address words
	mov	sesport[bx],ax		; port
	pop	bx
	mov	si,offset decbuf+1	; name of new host
	cmp	byte ptr [si-1],0	; byte count, anything given?
	je	sesmgr24		; e = no, use tcphost default
	mov	di,offset tcphost
	call	strcpy			; copy new host name

sesmgr24:mov	si,offset tcphost	; host name
	cmp	byte ptr [si],0		; is this empty too?
	je	sesmgr27		; e = yes, no host name, fail
	cmp	sescur,0		; inited current session ident?
	jge	sesmgr25		; ge = yes
	mov	sescur,0		; start with session 0
sesmgr25:mov	bx,sescur		; return slist index for action
	mov	al,bl
	mov	cx,seshostlen		; length of a table entry
	mul	cl			; skip to correct sesname
	add	ax,offset sesname	; destination table
	mov	di,ax
sesmgr26:call	strcpy
	push	bx
	mov	ax,tcpport
	mov	bx,sescur		; new session
	shl	bx,1
	mov	sesport[bx],ax
ifndef	no_terminal
	shr	bx,1
	call	termswapin		; swap in new session's emulator
endif	; no_terminal
	pop	bx
	clc
	ret
sesmgr27:mov	dx,offset sesnohost	; say have no host name 
	mov	ah,prstr
	int	dos
sesmgr28:mov	kstatus,ksgen		; command failure
	stc
	ret
					; user specified host name
					; see if name is already in use
sesmgr40:mov	si,offset decbuf+1	; user string
	mov	cl,[si-1]		; user string length
	xor	ch,ch
	cld
sesmgr41:lodsb				; read a byte
	call	tolowr			; to lower case
	mov	[si-1],al		; store letter
	loop	sesmgr41
	mov	si,offset decbuf+81	; optional port number
	mov	temp2,si		; where to expect New/Resume
	mov	al,[si-1]		; byte count
	xor	ah,ah
	mov	domath_cnt,ax		; for domath
	xor	ax,ax			; default port
	cmp	domath_cnt,0		; byte count, any port specified?
	je	sesmgr46		; e = no, use default
sesmgr44:
	mov	domath_ptr,si
	add	si,domath_cnt		; skip over field for next read
	mov	temp2,si		; where to expect New/Resume
	mov	domath_msg,1		; do not complain about letters
	call	domath			; convert to number in ax
	jnc	sesmgr45		; nc = decoded a port number
	sub	si,domath_cnt
	mov	temp2,si		; back up for New/Resume
	jmp	short sesmgr46

sesmgr45:or	ax,ax			; any port specified?
	jz	sesmgr46		; z = no, use 23
	cmp	ax,25			; this one?
	jne	sesmgr47		; ne = no
	mov	ah,prstr
	mov	dx,offset badport	; say bad port number
	int	dos
sesmgr46:mov	ax,23			; use official Telnet port
sesmgr47:mov	temp,ax			; remember port
	mov	cx,maxsessions
	xor	bx,bx			; session subscript, assummed
	mov	si,offset decbuf	; user len+string
	mov	di,offset sesname	; session list of host names
	cld
sesmgr42:push	cx
	push	si
	push	di
	push	es
	mov	cl,[si]			; length of user string
	xor	ch,ch
	inc	si			; skip user string count byte
	inc	cl			; include null termintors
	mov	ax,seg sesname
	mov	es,ax
	repe	cmpsb			; compare host names
	pop	es
	pop	di
	pop	si
	pop	cx
	jne	sesmgr43		; ne = no match, try next entry
	cmp	seslist[bx],0		; is session active?
	jl	sesmgr43		; l = no, ignore this entry
	shl	bx,1			; address words
	mov	ax,sesport[bx]		; current port
	shr	bx,1			; restore bx
	cmp	ax,temp			; specified port same?
	jne	sesmgr43		; ne = no, not a duplicate session
	mov	bx,temp2		; where to expect NEW/RESUME
	mov	bl,[bx]			; get first byte of NEW/RESUME
	or	bl,bl			; anything?
	jz	sesmgr10		; z = no, show menu and prompt
	mov	al,bl			; get byte
	and	al,not 20h		; to upper case, for letters only
	jmp	sesmgr13a		; decode letter

sesmgr43:add	di,seshostlen		; next entry in our table
	inc	bx			; next session subscript
	loop	sesmgr42
	mov	ax,temp
	mov	tcpport,ax		; set tcpport
	jmp	sesmgr15		; start a New session
sesmgr	endp

fsesdisp proc	far
	mov	ah,prstr
	mov	dx,offset sesheader
	int	dos
	push	bx
	xor	bx,bx			; number of sessions
sesdis1:mov	al,bl			; get our local counter
	mov	dl,seshostlen		; length of host name array row
	mul	dl
	add	ax,offset sesname	; asciiz host name
	mov	si,ax			; save host name pointer in cx
	cmp	byte ptr [si],0		; ever had a host name?
	jz	sesdis3			; z = no, don't display info
	mov	al,seslist[bx]		; get Telnet session number
	mov	dx,offset sesinact	; inactive msg
	or	al,al			; seslist status
	jns	sesdis4			; ns = active
	cmp	bx,sescur		; same as current?
	jne	sesdis2			; ne = no
	mov	dx,offset curinact	; say inactive but current
	jmp	short sesdis2

sesdis4:mov	dx,offset sesactive 	; active msg
	cmp	bx,sescur		; same as current?
	jne	sesdis2			; ne = no
	mov	dx,offset curmsg 	; current msg
sesdis2:mov	ah,prstr		; show status, ses #, host name
	int	dos
	mov	dl,bl			; count local session idents
	add	dl,'1'			; bias
	mov	ah,conout
	int	dos
	mov	dl,' '
	int	dos
	int	dos
	int	dos
	int	dos
	int	dos
	int	dos
	int	dos
	shl	bx,1			; address words
	mov	ax,sesport[bx]
	shr	bx,1			; restore bx
	call	decout
	mov	ah,conout
	mov	dl,' '
	int	dos
	int	dos
	mov	dx,si
	call	prtasz			; show host name
sesdis3:inc	bx			; next item
	cmp	bx,maxsessions		; done all?
	jb	sesdis1			; b = no
	pop	bx
	ret
fsesdisp endp

; Returns session ident in BX when given a Telnet ident in AL. Also updates
; tcphost from session table.
; Returns -1 if no correspondence
tcptoses proc	far
	push	ax
	push	cx
	mov	cx,maxsessions		; number session slots
	xor	bx,bx
tcptose1:mov	ah,seslist[bx]		; session status
	or	ah,ah			; active?
	js	tcptose2		; s = no
	cmp	ah,al			; same active session? 
	je	tcptose3		; e = yes, return BX
tcptose2:inc	bx
	loop	tcptose1
	mov	bx,-1			; return -1 for failure to find
	pop	cx
	pop	ax
	ret
tcptose3:push	si
	push	di
	mov	di,offset tcphost	; host name
	mov	al,bl
	mov	cx,seshostlen		; length of a table entry
	mul	cl			; skip to correct sesname
	add	ax,offset sesname	; source table
	mov	si,ax
	call	strcpy
	pop	di
	pop	si
	pop	cx
	pop	ax
	ret
tcptoses endp
endif	; no_tcp
code1	ends 
	end
