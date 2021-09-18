	NAME	mssset
; File MSSSET.ASM
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
 
	public	setcom, prmptr, dodef, setcpt, docom, stkadr, rdbuf, reset
	public	setrx, rxtable, srvdsa, srvena, mcctab, takclos, ask
	public	askq, assign, initibm, mccptr, setinpbuf, setrollb, npages
	public	xfchtab, xftyptab, com1port, com2port, com3port, com4port
	public	flotab, popcmd, domacptr, warntab, portirq, portfifo, dodecom
	public	xfertab1, xfertab2, xfertab3, rollwidth, setwidth, abftab
	public	localmac, getok, takeerror, macroerror, getc, dial, docnv
	public	takopen_sub, takopen_file, takopen_macro, _forinc, poplevel
	public	hide_assign, hide_define, declare, marray, forcmd, undefine
ifndef	no_tcp
	public	tcpaddress,tcpsubnet,tcpdomain,tcpgateway,tcpprimens
	public	tcpsecondns,tcphost,tcpbcast,tcpport,tcppdint,tcpttbuf
	public	tcpbtpserver,tcpnewline,tcpdebug,tcpmode,tcpmss
endif	; no_tcp

braceop	equ	7bh		; opening curly brace
bracecl	equ	7dh		; closing curly brace

maketab	MACRO			; Assembler Macro to make rxtable [jrd]
cnt = 0
	rept 256
	db	cnt		; initialize table to 0 .. 255
cnt = cnt + 1
	endm
	db	0		; table off (0) or on (1) indicator
ENDM

data 	segment
	extrn	comand:byte, flags:byte, trans:byte, takadr:word, taklev:byte
	extrn	portval:word, dtrans:byte, spause:word, machnam:byte
	extrn	filtst:byte, maxtry:byte, script:byte, denyflg:word
	extrn	sloghnd:word, ploghnd:word, tloghnd:word, cardet:byte
	extrn	decbuf:byte, kstatus:word, errlev:byte, srvtmo:byte
	extrn	luser:byte, lpass:byte, destab:byte, blktab:byte
	extrn	seoftab:byte, dmpname:byte, lsesnam:byte, lpktnam:byte
	extrn	ltranam:byte, incstb:byte, inactb:byte, rxoffmsg:byte
	extrn	rxonmsg:byte, scpbuflen:word, setchtab:byte
	extrn	prnname:byte, prnhand:word, outpace:word, apctrap:byte
	extrn	protlist:byte, rcvpathflg:byte, sndpathflg:byte
	extrn	fossilflag:byte, ifelse:byte, oldifelse:byte
	extrn	domath_ptr:word, domath_cnt:word, domath_msg:word
	extrn	streaming:byte

rxtable	equ THIS BYTE		; build 256 byte Translation Input table
	maketab			; table rxtable is used by Connect mode

kerm	db	'MS-Kermit>',0		; default ASCIIZ prompt
promptbuf db	80 dup (0),0		; buffer for new ASCIIZ prompt
rdbuf	db	cmdblen dup (?)		; work space; room for macro def
					;  and for Status display line
settemp db	100 dup (0)	; temp for hidemac/unhide
stflg	db	0		; Says if setting SEND or RECEIVE parameter
defkind	db	0		; 0 for ASSIGN, 1 for DEFINE
ermes1	db	cr,lf,'?Too many macro names$'
ermes2	db	cr,lf,bell,'?No room for Take file buffer or Macro definition'
	db	cr,lf,bell,'$'
ermes4	db	cr,lf,'?Too many active Take files and Macros',cr,lf, bell,'$'
ermes5	db	cr,lf,'?Not implemented$'
ermes6	db	cr,lf,'?More parameters are needed$'
ermes7	db	cr,lf,'?Cannot use RTS/CTS on non-UART ports$'
ermes8	db	cr,lf,'?Cannot use HARDWARE parity on non-UART ports$'
errcap	db	cr,lf,'?Unable to open that file$'
erropn	db	cr,lf,'?Log file is already open$'
badrx	db	cr,lf,'?Expected ON, OFF, or \nnn$'
escerr	db	cr,lf,'?Not a control code$'
takcerr	db	cr,lf,'?Note: command is valid only in Take files and Macros$'
dmpdefnam db	'Kermit.scn',0		; asciiz default screen dump filename
prndefnam db	'PRN',0			; asciiz default printer name
xfchbad	db	cr,lf,'Warning: forcing FILE CHARACTER-SET to CP866$'
xfchbad2 db	cr,lf,'Warning: forcing FILE CHARACTER-SET to Shift-JIS$'
xfchbad3 db	cr,lf,'Warning: forcing FILE CHARACTER-SET to CP862$'
setchmsg db	cr,lf,'Warning: forcing TRANSFER CHARACTER-SET to CYRILLIC$'
setchmsg2 db	cr,lf,'Warning: forcing TRANSFER CHARACTER-SET to'
	db	' Japanese-EUC$'
setchmsg3 db  cr,lf,'Warning: forcing TRANSFER CHARACTER-SET to HEBREW-ISO$'
badcntlmsg db	cr,lf,'?Number is not in range of 0..31, 128..159$'
getdef	db	'Please respond Yes or No ',0	; ASCII, used as prompt
crlf	db	cr,lf,'$'
space	db	' ',0

srvtab	db	2			; SET SERVER table
	mkeyw	'Login',1
	mkeyw	'Timeout',2

ifndef	no_network
settab	 db	64					; Set table
else
settab	 db	64 - 3					; Set table
endif	; no_network
	mkeyw	'Alarm',setalrm
	mkeyw	'Attributes',setatt
	mkeyw	'Baud',baudst
	mkeyw	'Bell',bellst
	mkeyw	'Block-check-type',blkset
	mkeyw	'Carrier',setcar
	mkeyw	'COM1',com1port
	mkeyw	'COM2',com2port
	mkeyw	'COM3',com3port
	mkeyw	'COM4',com4port
	mkeyw	'Control-character',cntlset
	mkeyw	'Count',takectr
	mkeyw	'Debug',debst
	mkeyw	'Default-disk',cwdir
	mkeyw	'Delay',setdely
	mkeyw	'Destination',desset
	mkeyw	'Display',disply
	mkeyw	'Dump',setdmp
	mkeyw	'Duplex',setdup
	mkeyw	'End-of-Line',eolset
	mkeyw	'EOF',seteof
	mkeyw	'Errorlevel',seterl
	mkeyw	'Escape-character',escset
	mkeyw	'Exit',setexitwarn
	mkeyw	'File',setfile
	mkeyw	'Flow-control',floset
	mkeyw	'Fossil',fosset
	mkeyw	'Handshake',hndset
	mkeyw	'Incomplete',abfset
	mkeyw	'Input',inpset
	mkeyw	'Key',setkey
	mkeyw	'Line',coms
	mkeyw	'Local-echo',lcal
	mkeyw	'Macro',setmacerr
	mkeyw	'Mode-line',modl
	mkeyw	'Modem',setmodem
ifndef	no_network
	mkeyw	'NetBios-name',setnbios
endif	; no_network
	mkeyw	'Output',setoutput
	mkeyw	'Parity',setpar
	mkeyw	'Port',coms
	mkeyw	'Printer',setprn
	mkeyw	'Prompt',promset
	mkeyw	'Receive',recset
	mkeyw	'Remote',remset
	mkeyw	'Repeat',repset
	mkeyw	'Retry',retryset
	mkeyw	'Rollback',setrollb
	mkeyw	'Send',sendset
	mkeyw	'Server',setsrv
	mkeyw	'Speed',baudst
	mkeyw	'Stop-bits',stopbit
	mkeyw	'Streaming',strmmode
	mkeyw	'Take',takset
ifndef	no_tcp
	mkeyw	'TCP/IP',tcpipset
	mkeyw	'Telnet',tcpipset
endif	; no_tcp
	mkeyw	'Terminal',vts
	mkeyw	'Timer',timset
	mkeyw	'Transfer',sxfer
	mkeyw	'xfer',sxfer		; hidden synonym
	mkeyw	'Translation',setrx
	mkeyw	'Transmit',setxmit
	mkeyw	'Unknown-character-set',unkchset
	mkeyw	'Warning',filwar
	mkeyw	'Windows',winset
 
setfitab db	6			; Set File command table
	mkeyw	'Character-Set',1
	mkeyw	'Collision',0
	mkeyw	'Display',3
	mkeyw	'Incomplete',4
	mkeyw	'Type',2
	mkeyw	'Warning',0

setrep	db	2			; SET REPEAT
	mkeyw	'Counts',0
	mkeyw	'Prefix',1

xfertab	db	5			; SET TRANSFER table
	mkeyw	'Character-set',0
	mkeyw	'CRC',4
	mkeyw	'Locking-shift',1
	mkeyw	'Mode',3
	mkeyw	'Translation',2

xfertab1 db	3			; SET TRANSFER LOCKING-SHIFT
	mkeyw	'Off',lock_disable
	mkeyw	'On',lock_enable
	mkeyw	'Forced',lock_force

xfertab2 db	2			; SET TRANSFER TRANSLATION
	mkeyw	'Readable',0
	mkeyw	'Invertible',1

xfertab3 db	2			; SET TRANSFER MODE
	mkeyw	'Automatic',1
	mkeyw	'Manual',0

xfchtab	db	6			; SET TRANSFER CHARACTER-SET
	mkeyw	'Transparent',xfr_xparent	; no translation
	mkeyw	'Latin1 ISO 8859-1',xfr_latin1	; ISO 8859-1, Latin-1
	mkeyw	'Latin2 ISO 8859-2',xfr_latin2	; ISO 8859-2, Latin-2
	mkeyw	'Hebrew ISO 8859-8',xfr_hebiso	; ISO 8859-8 Hebrew-ISO
	mkeyw	'Cyrillic ISO 8859-5',xfr_cyrillic; ISO 8859-5/Cyrillic, CP866
	mkeyw	'Japanese-EUC',xfr_japanese	; Japanese-EUC

xftyptab db	2			; SET FILE TYPE table
	mkeyw	'Binary',1		; Binary = as-is
	mkeyw	'Text',0		; Text = can change char sets

warntab	db	8			; File Warning table
	mkeyw	'Append',filecol_append		; append
	mkeyw	'Overwrite',filecol_overwrite	; overwrite
	mkeyw	'Rename',filecol_rename		; rename
	mkeyw	'Discard',filecol_discard	; discard
	mkeyw	'Update',filecol_update		; update (if incoming is newer)
	mkeyw	'No-supersede',filecol_discard	; discard
	mkeyw	'on (rename)',filecol_rename	; old form
	mkeyw	'off (overwrite)',filecol_overwrite ; old form

unkctab db	2			; unknown character-set disposition
	mkeyw	'Keep',0
	mkeyw	'Cancel',1

atttab	db	7			; SET ATTRIBUTES table
	mkeyw	'Off',00ffh		; all off
	mkeyw	'On',10ffh		; all on (high byte is on/off)
	mkeyw	'Character-set',attchr	; Character set
	mkeyw	'Date-Time',attdate	; Date and Time
	mkeyw	'Length',attlen		; Length
	mkeyw	'Type',atttype		; Type
	mkeyw	'System-id',attsys	; System

comtab	db	2			; table of COM ports
	mkeyw	'COM3',4		; offset of COM3 address
	mkeyw	'COM4',6		; offset of COM4 address

cntltab	db	2			; SET CONTROL table
	mkeyw	'Prefixed',0		; 0 = send with prefix
	mkeyw	'Unprefixed',1		; 1 = send as-is

stsrtb	db	10			; Number of options
	mkeyw	'Packet-length',srpack
	mkeyw	'Padchar',srpad
	mkeyw	'Padding',srnpd
	mkeyw	'Pause',srpaus
	mkeyw	'Start-of-packet',srsoh
	mkeyw	'Quote',srquo
	mkeyw	'End-of-packet',sreol
	mkeyw	'Timeout',srtim
	mkeyw	'Double-char',srdbl
	mkeyw	'Pathnames',srpath

ontab	db	2
	mkeyw	'off',0
	mkeyw	'on',1

outputtab db	1			; Set OUTPUT
	mkeyw	'PACING',setopace

distab	db	5 			; Set Display mode
	mkeyw	'7-bit',7		; controls bit d8bit in flags.remflg
	mkeyw	'8-bit',8		; sets d8bit
	mkeyw	'Quiet',dquiet		; values defined in header file
	mkeyw	'Regular',dregular
	mkeyw	'Serial',dserial

distab2	db	3			; for SET FILE DISPLAY
	mkeyw	'Quiet',dquiet		; values defined in header file
	mkeyw	'Regular',dregular
	mkeyw	'Serial',dserial

fossiltab db	1			; Fossil
	mkeyw	'disable-on-close',1

; If abort when receiving files, can keep what we have or discard
abftab	db	2
	mkeyw	'Discard',1
	mkeyw	'Keep',0

flotab	db	5
	mkeyw	'none',0
	mkeyw	'xon/xoff',1+2		; both directions
	mkeyw	'incoming-xon/xoff',2
	mkeyw	'outgoing-xon/xoff',1
	mkeyw	'RTS/CTS',4

FIFOtab	db	2
	mkeyw	'FIFO-disabled',0
	mkeyw	'FIFO-enabled',1

hndtab	db	8
	mkeyw	'none',0
	mkeyw	'bell',bell
	mkeyw	'cr',cr
	mkeyw	'esc',escape
	mkeyw	'lf',lf
	mkeyw	'xoff',xoff
	mkeyw	'xon',xon
	mkeyw	'code',0ffh		; allow general numerial code

duptab	db	2			; SET DUPLEX table
	mkeyw	'full',0
	mkeyw	'half',1

partab	db	6
	mkeyw	'none',PARNON
	mkeyw	'even',PAREVN
	mkeyw	'odd',PARODD
	mkeyw	'mark',PARMRK
	mkeyw	'space',PARSPC
	mkeyw	'HARDWARE',PARHARDWARE
parhwtab db	4			; for 9-bit bytes
	mkeyw	'even',PAREVNH
	mkeyw	'odd',PARODDH
	mkeyw	'mark',PARMRKH
	mkeyw	'space',PARSPCH

exittab	db	1			; EXIT table
	mkeyw	'warning',0

gettab	db	3			; GETOK dispatch table
	mkeyw	'Yes',kssuc		; success = yes
	mkeyw	'OK',kssuc		; ditto
	mkeyw	'No',ksgen		; general failure

inptab	db	5				; Scripts. Set Input
	mkeyw	'Case',inpcas			;[jrs]
	mkeyw	'Default-timeout',inptmo	;[jrs]
	mkeyw	'Echo',inpeco			;[jrs]
	mkeyw	'Filter-echo',infilt
	mkeyw	'Timeout-action',inpact		;[jrs]

resettab db	1
	mkeyw	'Clock',80h

macrotab db	1			; SET MACRO table
;;	mkeyw	'Echo',0
	mkeyw	'Error',1

pathtab	db	3			; SET SEND/RECEIVE PATHNAMES
	mkeyw	'off',0
	mkeyw	'relative',1
	mkeyw	'absolute',2

taketab	db	3			; SET TAKE table
	mkeyw	'Debug',2
	mkeyw	'Echo',0
	mkeyw	'Error',1

xmitab	db	4			; SET TRANSMIT table
	mkeyw	'Fill-empty-line',0
	mkeyw	'Line-Feeds-sent',1
	mkeyw	'Pause',3
	mkeyw	'Prompt',2

debtab	db	4			; Set Debug command
	mkeyw	'Off',0
	mkeyw	'On',logpkt+logses
	mkeyw	'Packets',logpkt
	mkeyw	'Session',logses

logtab	db	3			; LOG command
	mkeyw	'Packets',logpkt
	mkeyw	'Session',logses
	mkeyw	'Transactions',logtrn

srvdetab db	18			; Enable/Disable list for server
	mkeyw	'All',0ffffh
	mkeyw	'BYE',byeflg
	mkeyw	'CD',cwdflg
	mkeyw	'CWD',cwdflg
	mkeyw	'Define',defflg
	mkeyw	'Delete',delflg
	mkeyw	'Dir',dirflg
	mkeyw	'Finish',finflg
	mkeyw	'Get',getsflg
	mkeyw	'Host',hostflg
	mkeyw	'Kermit',kerflg
	mkeyw	'Login',pasflg
	mkeyw	'Print',prtflg
	mkeyw	'Retrieve',retflg
	mkeyw	'Query',qryflg
	mkeyw	'Send',sndflg
	mkeyw	'Space',0;;;spcflg	; obsolete, non-functional
	mkeyw	'Type',typflg

trnstab	db	2			; Set Translation table
	mkeyw	'Input',1
	mkeyw	'Keyboard',2

ifndef	no_tcp
tcptable db	14			; Telnet or TCP/IP command
	mkeyw	'address',1		; local Internet address
	mkeyw	'domain',2		; local domain string
	mkeyw	'broadcast',8		; broadcast of all 0's or all 1's
	mkeyw	'gateway',4		; gateway address
	mkeyw	'primary-nameserver',5	; name servers
	mkeyw	'secondary-nameserver',6
	mkeyw	'subnetmask',3		; our subnet mask
	mkeyw	'host',7		; host's IP name or IP number
	mkeyw	'Packet-Driver-interrupt',9
	mkeyw	'term-type',10		; Options term type
	mkeyw	'NewLine-mode',11 	; CR-NUL vs CRLF
	mkeyw	'mode',13		; NVT-ASCII or Binary
	mkeyw	'mss',14		; Max Segment Size
	mkeyw	'debug-Options',12	; debug Telnet Options

tcpmodetab db	2			; TCP/IP Mode
	mkeyw	'NVT-ASCII',0
	mkeyw	'Binary',1

tcpdbtab db	4			; TCP Debug modes
	mkeyw	'off',0
	mkeyw	'status',1
	mkeyw	'timing',2
	mkeyw	'on', 3

newlinetab db	3			; TCP/IP Newline mode
	mkeyw	'off',0
	mkeyw	'on',1
	mkeyw	'raw',2

domainbad db	cr,lf,'?Bad domain name, use is such as my.domain.name$'
addressbad db	cr,lf,'?string is too long$'
hostbad	db	cr,lf,'?Bad host, use IP name or IP number$'

tcpaddress db	'dhcp',(16-($-tcpaddress)) dup (0),0
tcpsubnet  db	'255.255.255.0',(16-($-tcpsubnet)) dup (0),0
tcpdomain  db	'unknown',(32-($-tcpdomain)) dup (0),0
tcpgateway db	'unknown',(32-($-tcpgateway)) dup (0),0
tcpprimens db	'unknown',(16-($-tcpprimens)) dup (0),0
tcpsecondns db	'unknown',(16-($-tcpsecondns)) dup (0),0
tcphost	db	(60 -($-tcphost)) dup (0),0
tcpbcast db	'255.255.255.255',(16-($-tcpbcast)) dup (0),0
tcpbtpserver db	17 dup (0)		; bootp server (response)
tcpport	dw	23			; TCP port
tcppdint dw	0			; Packet Driver interrupt
tcpttbuf db	32 dup (0),0		; term-type-override buffer
tcpnewline db	1			; NewLine-Mode (default is on)
tcpdebug db	0			; Options debugging (0 is off)
tcpmode db	0			; NVT-ASCII is 0, Binary is 1
tcpmss	dw	1460			; MSS
endif	; no_tcp

; MACRO DATA STRUCTURES mcctab
mcclen	equ	macmax*10		; length of mcctab
mcctab	db	0			; macro name table entries
	db	mcclen dup (0)		; room for macro structures
; END OF MACRO DATA STRUCTURES

ibmmac	db	'IBM '			; startup IBM macro definition + space
	db	'set timer on,set parity mark,set local-echo on,'
	db	'set handshake xon,set flow none,',0	; asciiz
dialmac	db	'__DIAL '			; "__DIAL "
	db	'asg \%9 \v(carrier),set carr off,'
	db	'output ATD\%1\%2\%3\%4\%5\%6\%7\%8\13,wait 90 CD,'
	db	'asg \%8 \v(status),set carr \%9,end \%8,',0	; asciiz

	even
prmptr	dw	kerm			; pointer to prompt
tempptr	dw	0			; pointer into work buffer
domacptr dw	0			; pointer to DO MAC string
min	dw	0 
max	dw	0 
numerr	dw	0
numhlp	dw	0
temp	dw	0
temp1	dw	0			; Temporary storage
temp2	dw	0			; Temporary storage
askecho db	0			; ask's echo control flag
deftemp	dw	0
stkadr	dw	0	; non-zero if replacement keyboard xlator present
mccptr	dw	mcctab 			; ptr to first free byte in mcctab
macptr	dw	0			; temp to hold segment of string
npages	dw	10 			; # of pages of scrolling on each side
rollwidth dw	0			; columns to roll back 80..207
portirq	db	4 dup (0)		; user specified IRQ's for COM1..4
portfifo db	4 dup (1)		; user specified FIFO for COM1..4
takeerror db	0			; Take Error (0 = off)
macroerror db	0			; Macro Error (0 = off)
marray	dw	27 dup (0)		; pointers to macro array mem areas
arraybad db	cr,lf,'? Array size is too large, 32000 max$'
hidetmp	db	0			; 0..9 binary for hide prefix

forstr1	db	'_forinc ',0 		; append 'variable step'
forstr2 db	' if not > ',0		; append 'variable end'
forstartptr dw	0
forendptr dw	0
forstepptr dw	0
forcmdsptr dw 0
forbadname db	cr,lf,'?Not a variable name$'
data	ends

data1	segment
askhlp1	db	'Variable name  then  prompt string$'
askhlp2	db	'Prompt string$'
askhlp3	db	'Enter a line of text$'
getokhlp db	'Optional prompt string$'
filhlp	db	' Output filename for the log$'
forhlp	db	cr,lf,'FOR variable initial final increment'
	db	' {command,command,...}$'
dishlp	db	cr,lf,' Quiet (no screen writing), Regular (normal),'
	db	' Serial (non-formatted screen)'
	db	cr,lf,' and/or 7-BIT (default) or 8-BIT wide characters.$'
exitwhlp db	cr,lf,' ON or OFF. Warn if sessions are active when exiting'
	db	' Kermit$'
remhlp	db	cr,lf,' OFF to show file transfer display,'
	db	' ON for quiet screen$'
macmsg	db	' Specify macro name followed by body of macro, on same line$'
prmmsg	db	cr,lf
	db    ' Enter new prompt string or press Enter to regain default prompt.'
	db	cr,lf,' Use \fchar(123) notation for special chars;'
	db	' Escape is \fchar(27).$'
rspathhlp db	cr,lf,' OFF removes pathnames during file transfer,'
	db	cr,lf,' RELATIVE includes path from current location'
	db	cr,lf,' ABSOLUTE includes path from root of drive$'
	
srxhlp1	db	cr,lf,' Enter   code for received byte   code for'
	db	' local byte ',cr,lf,' use ascii characters themselves or'
	db	cr,lf,' numerical equivalents of  \nnn  decimal'
	db	' or \Onnn  octal or \Xnnn  hexadecimal',cr,lf
	db	' or keywords  ON  or  OFF  (translation is initially off)'
	db	cr,lf,'$'

takchlp	db	cr,lf,'Value 0 to 65535 for COUNT in script IF COUNT command$'

nummsg1 db	cr,lf,'?Use a number between $'
nummsg2	db	' and $'
srvthlp	db	'seconds, 0-255, waiting for a transaction$'
unkchhlp db	cr,lf,' Disposition of files arriving with unknown'
	db	' character sets:',cr,lf,'  Keep (default), Cancel$'
winhelp	db	cr,lf,'Number of sliding window slots 1 (no windowing) to 32$'
eophlp	db	' Decimal number between 0 and 31$'
ctlhlp	db	' Decimal number between 0 and 31, 128 and 159$'
cntlhlp db	cr,lf,' PREFIXED <0..31, 128..159> protectively quotes this'
	db	' control code',cr,lf
	db	' UNPREFIXED <0..31, 128..159> sends control code as-is'
	db	cr,lf,' Use ALL to change all codes at once.$'
sohhlp	db	' Decimal number between 0 and 31.',cr,lf,' Special case:'
	db	' up to 126, but reduces strength of the protocol.$'
dmphlp	db	' Filename to hold screen dumps$'
prnhlp	db	' Filename for printer output (default is PRN)$'
prnerr	db	cr,lf,' Cannot open that name. Using default of PRN$'
erlhlp	db	' Decimal number between 0 and 255$'
pakerr	db	cr,lf,'?Choose a decimal number '
	db	'from 20 to 94 (normal) or to 9024 (long)$'
pakhlp	db	cr,lf,'Decimal number between 20 and 94 (normal) or '
	db	'9024 (long)$'
padhlp	db	cr,lf,' Decimal number between 0 and 31 or 127$'
pauhlp	db	' Decimal number between 0 and 65383 milliseconds$'
quohlp	db	' Decimal number between 33 and 126$'
retryhlp db	' Decimal number between 1 and 63$'
rollhlp	db	' Decimal number between 0 and 8000$'
dblhlp	db	' Decimal number between 0 and 255$'
stophlp	db	' Serial port stop bits, 1 (default) or 2$'
luserh	db	cr,lf,'Username Password from remote Kermit (0-16 chars each)$'
lpassh	db	cr,lf,'Password from remote Kermit (0-16 chars,'
	db	' spaces allowed)$'
prefhlp	db	cr,lf,' single char (def is ~) or number between 33-62 or'
	db	' 96-126$'
timhlp	db	' Decimal number between 0 and 94$'
delyhlp	db	' Delay seconds before sending file (0-63)$'
eschlp	db	cr,lf,'Press literal control keys (ex: Control ]) or'
	db	' enter in \nnn numerical form$'
hnd1hlp	db	cr,lf,'XON (\17), XOFF (\19), CR (\13), LF (\10), BELL (\7),'
	DB	' ESC (\27), NONE (\0)'
	db	cr,lf,' or "CODE" followed by decimal number$' 
intoms	db	'number of seconds to wait before timeout',cr,lf,'$'
loghlp	db	cr,lf
	db    ' PACKETS - during file transfers  (to default file PACKET.LOG)'
	db	cr,lf
	db    ' SESSION - during Connect mode   (to default file SESSION.LOG)'
	db	cr,lf
	db    ' TRANSACTIONS - files transfers (to default file TRANSACT.LOG)'
	db	cr,lf,'  followed by an optional filename for the log and'
	db	' optional',cr,lf,' '
loghlp2	db	' APPEND (default) or NEW$'
carhlp	db	cr,lf,' ON or OFF. Sense modem Carrier Detect and end'
	db	' connection if it drops.$'
comhlp	db	cr,lf,' Set port address, IRQ, and control UART FIFO.'
	db	cr,lf,' Address of the COM1 - COM4 port (ex: COM3 \x02f8 or'
	db	' COM4 \x02e8)$'
irqhlp	db	cr,lf,' IRQ of port (ex: \3)$'
fifohlp db	cr,lf,' FIFO-disable or FIFO-enable or press Enter key.'
	db	cr,lf,' FIFO-disable means bypass UART buffer$'
debhlp	db	cr,lf,' PACKETS - during file transfers'	; Debugging
	db	cr,lf,' SESSION - during Connect mode'
	db	cr,lf,' ON - both packets and session'
	db	cr,lf,' OFF - turns off all debugging$'
dialhlp	db	' Phone number to dial$'
dohlp	db	cr,lf,'definitions of variables (\%n), or press ENTER key$'
fossilhlp db	cr,lf,' OFF to leave Fossil active (default), ON to disable'
	db	' when done with port$'
sdshlp	db	cr,lf,'DISABLE or ENABLE access to selected Server commands:'
	db	cr,lf
	db	' BYE (includes LOGOUT), CD/CWD, DEFINE, DEL, DIR, FINISH,'
	db	' GET, HOST,',cr,lf
	db	' KERMIT, LOGIN, PRINT, QUERY, RETRIEVE, SEND, TYPE,'
	db	' and ALL.$'

xfchhlp	db	cr,lf,' Which character set to put on the wire during file'
	db	' transfers:',cr,lf
	db	'  TRANSPARENT (regular PC codes)',cr,lf
	db	'  LATIN1    (ISO 8859-1)',cr,lf
	db	'  LATIN2    (ISO 8859-2)',cr,lf
	db	'  HEBREW    (ISO 8859-8)',cr,lf
	db	'  CYRILLIC  (ISO 8859-5)',cr,lf
	db	'  JAPANESE-EUC$'
xferhlp1 db	cr,lf,' OFF: disable feature, ON: enable (default), FORCE:'
	db	' forced on$'
xfchhlp2 db	cr,lf,' READABLE: translate some/many characters to/from'
	db	' locally readable form (def).'
	db	cr,lf,' INVERTIBLE: use codes which can be copied back to the'
	db	' host in its form.$'
xferhlp3 db	cr,lf,'Automatic (Binary mode between like systems),'
	db	' manual (default)$'
xfilhlp	db	'NONE, SPACE, or filler character$'
xpmthlp db	'Host echo char acting as prompt, \1-\255$'
xpauhlp	db	'Millisec to pause between lines, 1 - 65000$'
opacehlp db	'Millisec to pause between OUTPUT bytes, 0 - 65000$'
pophlp	db	'Status value to be returned  msg, nothing if no new value$'
sethlp	db	cr,lf
	db	'  Alarm    sec from now or HH:MM:SS  '
	db	'  Mode-line         on/off'
	db	cr,lf
	db	'  Attributes packets on/off          '
	db	'  NetBios-name      (our local name)'
	db	cr,lf
	db	'  Bell    on/off    at end of xfers  '
	db	'  Output pacing (ms between bytes)  '
	db	cr,lf
	db	'  Block-check-type  checksum/CRC     '
	db	'  Parity    even/odd/mark/space/none'
	db	cr,lf
	db	'  Carrier  sense modem Carrier Detect'
	db	'  Port (or Line)    1/2/COM1/COM2/etc'
	db	cr,lf
	db	'  COM1 - COM4 port-address irq       '
	db	'  Printer filespec   for Connect mode'
	db	cr,lf
	db	'  Control prefixed/unprefixed  code  '
	db	'  Prompt  string   (new Kermit prompt)'
	db	cr,lf
	db	'  Count   number    a loop counter   '
	db	'  Receive parameter  many things'
	db	cr,lf
	db	'  Debug   on/off    display packets  '
	db	'  Repeat Counts (on/off)             '
	db	cr,lf
	db	'  Default-disk                       '
	db	'  Retry limit for packet send/receive'
	db	cr,lf
	db	'  Delay   secs  before Sending file  '
	db	'  Rollback, terminal screens'
	db	cr,lf
	db	'  Destination   Disk/Screen/Printer  '
	db	'  Send parameter    many things'
	db	cr,lf
	db	'  Display quiet/reg/serial show cnts?'
	db	'  Server parameter'
	db	cr,lf
	db	'  Dump filespec     screen to disk   '
	db      '  Speed or Baud     many speeds'	
	db	cr,lf
	db	'  Duplex            half or full     '
	db	'  Streaming         on/off'
	db	cr,lf
	db	'  EOF Ctrl-Z/NoCtrl-Z  ^Z ends file? '
	db	'  Stop-bits         always 1'
	db	cr,lf
	db 	'  End-of-line char  cr or whatever   '
	db	'  Take Echo or Error on/off' 
	db	cr,lf
	db	'  Errorlevel number   for DOS Batch  '
	db	'  TCP/IP or Telnet  parameters'
	db	cr,lf
	db      '  Escape-char  ^]   or whatever      '
	db	'  Terminal type and parameters'
	db	cr,lf
	db	'  Exit warning (if session active)   '
	db	'  Timer     on/off  time packet waiting'
	db	cr,lf
	db	'  File (Character-set, Type, Warning)'
	db	'  Translation in  Connect mode rcv''d char'
	db	cr,lf
	db	'  Flow-control  none xon/xoff rts/cts'
	db	'  Transfer Character-set (on wire) '
	db	cr,lf
	db	'  Handshake xon/xoff/cr/lf/bell/esc..'
	db	'  Transmit  parameters, for scripts'
	db	cr,lf
	db	'  Incomplete file   keep/discard     '
	db	'  Unknown-character-set (keep/cancel)'
	db	cr,lf
	db	'  Input timeout, etc  (for scripts)  '
	db	'  Warning   on/off  if file renamed'
	db	cr,lf
	db	'  Key         key-ident   definition '
	db	'  Windows  number of sliding window slots'
	db	cr,lf
	db	'  Local-echo        on/off'
	db	'$'

ifndef	no_tcp
hosthlp	db	cr,lf,'Internet name or number (ddd.ddd.ddd.ddd) of '
	db	'the remote machine$'
domainhlp db	cr,lf,'Name of your domain$'
subnethlp db	cr,lf,'Subnetmask, decimal ddd.ddd.ddd.ddd$'
addrhelp db	cr,lf,'Internet address, decimal ddd.ddd.ddd.ddd, of this'
	db	' machine or'
	db	cr,lf,' BOOTP, DHCP, RARP, or Telebit-PPP$'
iphelp	db	cr,lf,'Internet address, decimal ddd.ddd.ddd.ddd$'
tcppdinthlp db	cr,lf,'Interrupt on PC for Packet Driver, \x40 to \x7f'
	db	' or use 0 for automatic search,'
	db	cr,lf,' or ODI to use Novell''s ODI interface$'
tcpttyhlp db	cr,lf,' Telnet Options terminal identification override '
	db	'string.'
	db	cr,lf,' This does NOT modify the real terminal type.'
	db	' Press ENTER to remove this',cr,lf 
	db	' override and report the real terminal type.$'
tcpnlhlp db	cr,lf,' ON sends CR LF for each CR, OFF sends CR NUL,'
	db	' RAW sends just CR$'
tcpmsshlp db	cr,lf,' Maximum Segment Size, 16 to 1460 bytes$'
endif	; no_tcp
arrayhlp db	' \&<char>[size]   size of 0 undefines the array$'

data1	ends

code1	segment
	extrn	makebuf:far, domath:far, strlen:far, strcpy:far
	extrn	prtasz:far, decout:far, strcat:far, toupr:far
	extrn	isfile:far, malloc:far, dec2di:far, takrd:far
	assume 	cs:code1
code1	ends

code	segment
	extrn comnd:near, baudst:near, prompt:near, coms:near, cwdir:near
	extrn lnout:near, breakcmd:near
	extrn vts:near, setalrm:near, serrst:near
	extrn prnopen:near, pntflsh:near
ifndef	no_network
	extrn setnbios:near	; in MSXIBM, needs stub for other machines
endif	; no_network
	assume	cs:code, ds:data, es:nothing

; DO defined macro command
; DO macname variable variable   also defines variables \%1, \%2, ...\%9
DOCOM	PROC	NEAR
	mov	dx,offset mcctab	; table of macro defs
	xor	bx,bx			; help is table
	mov	ah,cmkey		; get key word (macro name)
	call	comnd			; get pointer to keyword structure
	jnc	docom1			; nc = success, bx = 16 bit data
	ret				; failure
DOCOM1:	mov	domacptr,bx		; segment of definition string
	mov	comand.cmquiet,0	; permit command echoing
	mov	bx,offset decbuf+2	; point to borrowed work buffer
docom1a:mov	dx,offset dohlp		; help
	mov	comand.cmblen,decbuflen ; length of analysis buffer
	mov	comand.cmdonum,1	; \number conversion allowed
	mov	ah,cmword
	call	comnd
	jnc	docom1b
	ret
docom1b:mov	si,bx			; terminating null
	sub	si,ax			; minus length
	mov	[si-2],ax		; store length in preceeding word
	add	bx,2			; leave a full word empty
	mov	word ptr [bx-2],0
	or	ax,ax			; any text?
	jnz	docom1a			; nz = got text, get more
	mov	ah,cmline		; read and discard rest of line
	mov	bx,offset rdbuf		; discard here
	xor	dx,dx			; no help
	call	comnd
	jnc	docom2			; nc = success
	ret

docom2:	inc	taklev			; prepare for being in Take below
	call	hidemac			; hide previous \%0..\%9 macros
	dec	taklev
	call	getname			; get name of this macro to rdbuf
	mov	cx,word ptr rdbuf	; length of "\%0 plus found name"
	call	dodecom			; define macro \%0 as macro name
	jc	docomx			; c = failure
	push	es
	mov	ax,domacptr		; macro definition string segment
	mov	es,ax			; string is in es:si
	xor	si,si			; point to count word
	call	docnv			; convert macro string in-place
	pop	es			; to lift top {} and do bare "," -> CR
	jc	docomx			; c = failure

	mov	max,1			; temp for counting 1 + number args
	mov	word ptr rdbuf+4,' 1'	; number of first variable
docom3:	mov	word ptr rdbuf,0	; clear length field, install \%x name
	mov	word ptr rdbuf+2,'%\'	; start with '\%1 '
	mov	word ptr rdbuf+6,0	; clear text field
	mov	tempptr,offset rdbuf+6	; pointer to location of found word
	xor	ch,ch			; make cx = 1 - 9
	mov	cl,rdbuf+4		; cx = word # of interest, for getwrd
	sub	cl,'0'			; remove ascii bias
	mov	si,offset decbuf+2	; source = work buffer (borrowed)
	call	getwrd			; get CX-th word from work buf (1-9)
	cmp	deftemp,0		; length of word, was it found?
	je	docom4			; e = no, end variable definition part
	add	deftemp,4		; count '\%n ' in command line length
	inc	max			; one more argument
	mov	cx,deftemp		; command length for dodecom
	call	dodecom			; add keyword+def using DEF MAC below
	jc	docomx			; c = failure
	inc	rdbuf+4			; inc number of variable in '\%n '
	cmp	rdbuf+4,'9'
	jbe	docom3			; do '1' through '9', if available

docom4:	call	takopen_macro		; create the DO the macro itself
	jc	docomx			; c = failure
	mov	bx,takadr		; point to current structure
	push	es
	mov	es,domacptr		; segment of macro definition string
	mov	[bx].takbuf,es		; remember in Take structure
	mov	cx,es:word ptr[0]	; length of definition string
	mov	si,cx
	cmp	byte ptr es:[si+2-1],CR	; terminates in CR?
	je	docom5			; e = yes
	mov	byte ptr es:[si+2],CR	; force CR termination
	; keeps open macro until after last command has executed, for \%digit
	inc	cx			; add CR to macro length
	mov	es:[0],cx		; update image too
docom5:	pop	es
	mov	[bx].takcnt,cx		; # of unread chars in buffer
	mov	cx,max			; 1 + number of arguments
	mov	[bx].takargc,cx
	mov	al,taklev		; Take level now
	mov	[bx].takinvoke,al	; remember take level of this DO
	clc				; success
	ret

docomx:	inc	taklev			; simulate Take closing
	mov	hidetmp,0		; unhide only \% args
	call	unhidemac		; recover hidden variables
       	dec	taklev
	stc				; say failure
	ret
DOCOM	ENDP

; Extract CX-th word (cx = 1-9) from buffer (SI). Enter with si = source
; string and tempptr pointing at destination. Returns deftemp (count) of
; transferred characters.
; All registers preserved.
getwrd	proc	near
	push	si
	push	di
	push	es
	push	cx			; save word counter (1-9)
getwr1:	mov	ax,[si-2]		; get length of word
	or	ax,ax
	jz	getwr2			; z = zero length, no word, quit
	dec	cx			; one less word
	or	cx,cx
	jz	getwr2			; z = at desired word
	add	si,ax			; step to next word (<cnt><text>)
	add	si,2			; point to text
	jmp	short getwr1
getwr2:	mov	deftemp,ax		; returned length of word
	mov	cx,ax			; length of word
	mov	di,tempptr		; where to store word/string
	push	ds
	pop	es			; set es to data segment
	cld
	rep	movsb			; copy bytes to destination
	xor	al,al
	stosb				; force null terminator
	pop	cx
	pop	es
	pop	di
	pop	si
	ret
getwrd	endp

; Get macro name, given the action pointer in domacptr.
; Return rdbuf as word:length that follows, then "\%0 macro-name"
getname proc	near
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	mov	dx,domacptr		; action word to be matched
	mov	bx,offset mcctab+1	; table of macro names, skip count
	mov	word ptr rdbuf,4	; name length and space
	mov	word ptr rdbuf+2,'%\'	; define '\%0 '
	mov	word ptr rdbuf+4,' 0'
	mov	cl,mcctab		; number of entries
	xor	ch,ch
	jcxz	getnam3			; z = empty table
getnam1:push	cx
	mov	cx,[bx]			; length of name
	mov	si,bx			; point at structure member
	add	si,2			; plus count
	add	si,cx			; plus length of name
	mov	ax,[si]			; get action word
	cmp	ax,dx			; correct action word?
	jne	getnam2			; ne = no
	push	es
	push	ds
	pop	es
	add	word ptr rdbuf,cx	; length of macro \%0 + name
	mov	di,offset rdbuf+6	; where to store text
	mov	si,bx
	add	si,2			; source of text
	cld
	rep	movsb			; copy name to rdbuf+6
	mov	byte ptr [di],0		; null terminator
	pop	es
	pop	cx
	jmp	short getnam3		; exit
getnam2:mov	ax,[bx]			; get length of name
	add	ax,4			; plus count and word pointer
	add	bx,ax			; point to next entry
	pop	cx
	loop	getnam1			; look at next entry
getnam3:pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	ret
getname	endp

; Local macro macro macro...  
; Hides existing macros of those names, if any
localmac proc	near
	cmp	taklev,0		; in a take file/macro?
	je	localmx			; e = no, quit
	mov	bx,offset rdbuf+2
	xor	dx,dx			; help
	mov	comand.cmper,1		; don't expand macro
	mov	ah,cmword		; get name of macro
	call	comnd
	jnc	localm1
localmx:mov	ah,cmeol		; get eol
	call	comnd
	ret
localm1:mov	word ptr rdbuf,ax	; save name length
	or	ax,ax			; empty (end of command)?
	jz	localmx			; z = yes, quit
	mov	bx,offset mcctab+1	; table of macro names, skip count
	xor	ch,ch
	mov	cl,mcctab		; number of entries
	jcxz	localmx			; z = empty table

localm2:mov	ax,word ptr rdbuf	; get user macro name length
	cmp	word ptr [bx],ax	; name length, same?
	jne	localm4			; ne = no, get next table entry
	push	cx			; compare names
	push	si
	push	di
	mov	cx,ax			; length of macro (either)
	mov	si,offset rdbuf+2	; user word
	mov	di,bx			; table word length
	add	di,2			; table word
localm3:mov	al,[si]
	mov	ah,[di]
	inc	si
	inc	di
	call	toupr			; upper case both
	cmp	al,ah			; same?
	loope	localm3			; e = yes
	je	short localm5		; e = fully matched
	pop	di
	pop	si
	pop	cx
localm4:mov	ax,[bx]			; get length of name
	add	ax,4			; plus count and word pointer
	add	bx,ax			; point to next entry
	loop	localm2			; look at next table entry
	jmp	localmac		; get next macro name

localm5:pop	di
	pop	si
	pop	cx
	mov	hidetmp,1		; hide locals
	call	hidewrk			; hide macro pointed to by bx
	jmp	localmac		; get next macro name
localmac endp


; DEFINE and ASSIGN macro commands
; Data structures comments. Macro name is stored in table mcctab as if we
; had used macro mkeyw, such as       mkeyw 'mymac',offset my_definition.
; In detail:	dw	length of name
;		db	'name'
;		dw	segment:0 of definition string
; Mcctab begins with a byte holding the number of macros in the table; one,
;  IBM, is established at assembly time. Mcctab is 10*macmax bytes long.
; Pointer mccptr holds the offset of the next free byte in mcctab.
; Definition strings are stored in individually allocated memory as
;		dw	length of definition string below
;		db	'definition string'
; A new definition is read into buffer rdbuf+2, where word rdbuf is reserved
;  to hold the length of the macro's name during intermediate processing.
; If the definition is absent then the macro is removed from the tables.
;
; ASSIGN is equivalent to DEFINE, except in the definition string substitution
; variable names are expanded to their definitions.
; DEFINE does not expand substitution variables.
; Both commands will remove a first level curly brace pair if, and only if,
; the definition begins and ends with them (trailing whitespace is allowed).
; HIDE_ASSIGN and HIDE_DEFINE are like ASSIGN and DEFINE except the
; destination name is expanded for substitution variables.
;
HIDE_ASSIGN	proc	near
	mov	defkind,2		; flag command as ASSIGN, vs DEFINE
	jmp	short dodefcom		; common code
HIDE_ASSIGN	endp
HIDE_DEFINE	proc	near
	mov	defkind,3		; flag command as DEFINE, vs ASSIGN
	jmp	short dodefcom		; common code
HIDE_DEFINE	endp

ASSIGN	PROC	NEAR
	mov	defkind,0		; flag command as ASSIGN, vs DEFINE
	jmp	short dodefcom		; common code
ASSIGN	ENDP

UNDEFINE PROC	NEAR			; undefine variable or array
	mov	defkind,4		; bit 4 means undefine
	jmp	short dodefcom
UNDEFINE ENDP

DODEF	PROC	NEAR
	mov	defkind,1		; flag command as DEFINE, vs ASSIGN
DODEFCOM:
	test	defkind,2		; HIDE_assign/define?
	jnz	dodef0			; nz = yes, expand destination
	mov	comand.cmper,1		; do not react to '\%' in macro name
dodef0:	mov	ah,cmword
	mov	bx,offset rdbuf+2	; buffer for macro name
	mov	word ptr rdbuf,0
	mov	comand.cmarray,1	; allow sub in [..] of \&<char> arrays
	mov	comand.cmblen,length rdbuf-2 ; length of analysis buffer
	mov	dx,offset macmsg
	call	comnd			; get macro name
	jnc	dodef1			; nc = success
	ret				; failure
dodef1:	or	ax,ax			; null entry?
	jnz	dodef2			; nz = no
	mov	dx,offset ermes6	; more parameters needed
	jmp	reterr

dodef2:	mov	bx,offset rdbuf+2	; start of string
	cmp	word ptr [bx],'%\'	; \%<char> substitution variable?
	jne	dodef2b			; ne = no
	cmp	ax,2			; count, but missing <char>?
	ja	dodef2a			; a = no
	mov	byte ptr [bx+2],'_'	; slip in an underscore
dodef2a:mov	ax,3			; limit to \%<char>, one char name

dodef2b:test	defkind,4		; UNDEFINE?
	jz	dodef2c			; z = no
	add	bx,ax			; string length
	mov	word ptr [bx],0		; create double null for defarray
	mov	comand.cmcnvkind,cmcnv_crprot ; allow CR within {..}
	mov	ah,cmeol		; get eol, no definition string
	call	comnd
	jnc	dodef3			; nc = success
	ret
dodef2c:add	bx,ax			; point to string terminator
	mov	byte ptr [bx],' '	; replace null with space separator
	inc	bx			; where definition will start
	mov	ax,cmdblen		; length of rdbuf
	sub	ax,2			; skip initial count word
	add	ax,bx			; next byte goes to bx
	sub	ax,offset rdbuf+2	; amount of cmd line used
	mov	comand.cmblen,ax	; our new buffer length
	mov	al,defkind		; get ASSIGN/DEFINE flag
	and	al,1			; pick out source flag bit
	mov	comand.cmper,al		; react (ASSIGN) to '\%' in definition
	mov	comand.cmcnvkind,cmcnv_crprot ; allow CR within {..}
	mov	ah,cmline		; get a line of text
	mov	dx,offset macmsg	; help, bx is buffer offset
	call	comnd			; get macro definition text
	jnc	dodef3			; nc = success
	ret				; failure
dodef3:	mov	dx,offset rdbuf+2
	call	strlen			; length to cx
	jmp	short dodecom
DODEF	ENDP

; Make a macro table entry and allocate buffer space.
; Enter with rdbuf+2 et seq = <macro name><spaces><arg><spaces><arg> ...
; and CX = byte count of line, starting at rdbuf+2.
; Word rdbuf+0 computed here as length of keyword.
; Allocates memory based on analyzed size of command line, returns memory
; segment in macptr and in AX. Returns carry set if failure.
DODECOM	PROC	NEAR
	cmp	word ptr rdbuf+2,'&\'	; dealing with arrays?
	jne	dode1			; ne = no
	call	defarray		; yes, do it in segment code1
	ret
dode1:	push	si			; macro name in rdbuf+2 et seq
	push	di			; cmd line length in deftemp
	push	es
	push	ds			; address data segment
	pop	es
	push	deftemp
	mov	deftemp,cx		; cmd line len, cx = running counter
	mov	rdbuf,0			; number of chars in keyword so far
					; uppercase the keyword, look for end
	mov	si,offset rdbuf+2	; point at macro name itself
	xor	dx,dx			; a counter
	cld				; strings go forward
dode2:	lodsb				; get a byte
	cmp	al,'a'			; map lower case to upper
	jb	dode3
	cmp	al,'z'
	ja	dode3
	sub	al,'a'-'A'
	mov	[si-1],al		; uppercase if necessary
dode3:	inc	dx			; increment char count of keyword
	cmp	al,' '			; is this the break character?
	loopne	dode2			; no, loop thru rest of word
	jne	dode4			; ne = did not end with break char
	dec	dx			; yes, don't count in length
dode4:	mov	di,offset rdbuf		; point at mac name length
	mov	[di],dx			; insert length in rdbuf
	push	dx			; save length around call
	call	remtab			; remove any duplicate keyword
					; check for free space for keyword
	pop	ax			; keyword text length
	add	ax,4			; plus count and word pointer
	add	ax,mccptr		; add to free space pointer
	cmp	ax,offset mcctab+mcclen ; enough room for name?
	jb	dode5			; b = yes
	mov	dx,offset ermes1	; too many macro names
	pop	deftemp
	pop	es
	pop	di
	pop	si
	jmp	reterr
					; should be looking one byte after
					; space break char between name
					; and definition
dode5:	mov	dx,si			; definition string
	call	strlen			; get new length into cx
	jcxz	dode5c			; z = no definition, exit this routine
dode5a: mov	al,[si]			; read a definition byte
	cmp	al,','			; leading COMMA?
	je	dode5b			; e = yes, from {,cmd,cmd} stuff
	cmp	al,CR			; leading CR?
	je	dode5b			; e = yes, skip over it
	cmp	al,' '			; leading space?
	jne	dode6			; ne = no, have reached def text
dode5b:	inc	si			; inc pointer, count down qty
	loop	dode5a			; look again (note cx > 0 check above)
dode5c:	pop	deftemp			; exit point with no definition left
	pop	es
	pop	di
	pop	si
	clc
	ret

dode6:	mov	deftemp,cx		; remember definition length here
					; install new keyword
	jcxz	dode10			; z = no def (should not happen here)
	mov	ax,cx			; memory needed
	add	ax,2+1+1		; plus count word and CR and saftey
	call	malloc
	jc	dode12			; c = error, not enough memory
dode7:	mov	macptr,ax		; store new segment
	mov	es,ax			; segment of string
	xor	di,di			; offset of count word
	mov	cx,deftemp		; length of definition string
	mov	ax,cx
	cld
	stosw				; store length of string
	rep	movsb			; copy string
	mov	bx,offset mcctab	
	mov	dx,offset rdbuf		; count word + name string
	call	addtab
dode10:	mov	ax,macptr		; return buffer segment to caller
	pop	deftemp
	pop	es
	pop	di
	pop	si
	clc				; success
	ret
dode12:	pop	deftemp			; no memory, clean stack
	pop	es
	pop	di
	pop	si
	mov	dx,offset ermes2	; no room for definition
	mov	ah,prstr
	int	dos
	stc
	ret
DODECOM	ENDP

DECLARE	proc	near		; declare array \&<char @a..z>[size]
	mov	comand.cmper,1		; do not react to '\&' in macro name
	mov	comand.cmdonum,1	; \number conversion allowed
	mov	comand.cmarray,1	; allow sub in [..]
	mov	ah,cmline
	mov	bx,offset rdbuf+2	; buffer for macro name
	mov	comand.cmblen,length rdbuf-2 ; length of analysis buffer
	mov	dx,offset arrayhlp
	call	comnd			; get macro name
	jnc	ndecl1			; nc = success
	ret				; failure
ndecl1:	call	fdeclare		; call the far version
	ret
DECLARE endp

; ASK <variable or macro name> <prompt string>
; Defines indicated variable/macro with text from user at keyboard or pipe
; (but not from a Take/macro). Prompt string is required.
; ASKQ does the same, but does not echo user's response.
ASKQ	PROC	NEAR
	mov	askecho,1		; temp to flag as Quiet version
	mov	temp,0
	jmp	short ask0		; do common code
ASKQ	ENDP

GETC	PROC	NEAR
	mov	askecho,1
	mov	temp,1			; signal as getc
	jmp	short ask0		; do common code
GETC	ENDP

ASK	PROC	NEAR
	mov	askecho,0		; temp to flag as echoing version
	mov	temp,0
ask0:					; common code for ASK and ASKQ
	mov	bx,offset decbuf+2	; point to work buffer
	mov	word ptr decbuf,0
	mov	dx,offset askhlp1	; help
	mov	comand.cmper,1		; do not expand variable name
	mov	comand.cmarray,1	; allow sub in [..] of \&<char> arrays
	mov	ah,cmword		; get variable name
	call	comnd
	jnc	ask1			; nc = success
	ret				; failure
ask1:	or	ax,ax			; anything given?
	jnz	ask2			; nz = yes
	mov	dx,offset ermes6	; more parameters needed
	jmp	reterr

ask2:	cmp	word ptr decbuf+2,'%\'	; \%<char> substitution variable?
	jne	ask2b			; ne = no
	cmp	ax,2			; but missing <char>
	ja	ask2a			; a = no
	mov	decbuf+4,'_'		; slip in an underscore
ask2a:	mov	ax,3			; limit to a single char
ask2b:	mov	bx,offset decbuf+2	; start of name
	add	bx,ax			; plus length of variable name
	mov	word ptr [bx],0+' '	; put space+NULL separator after name
					; get ASK command prompt string
	mov	bx,offset decbuf+129	; borrowed buffer for prompt
	mov	dx,offset askhlp2
	mov	comand.cmblen,127	; our buffer length
	sub	comand.cmblen,ax	;  minus part used above
	mov	comand.cmdonum,1	; \number conversion allowed
	mov	comand.cmcr,1		; bare cr's allowed (empty prompt)
	mov	ah,cmline		; get prompt string
	call	comnd
	jnc	ask3			; nc = success
	ret				; failure
ask3:	push	ax
	mov	ah,cmeol
	call	comnd
	pop	ax
	jnc	ask4
	ret

	or	ax,ax			; anything given?
	jnz	ask4			; nz = yes
	mov	dx,offset ermes6	; more parameters needed
	jmp	reterr

ask4:	mov	bx,offset decbuf+129
	add	bx,ax
	mov	word ptr [bx],0020h	; printing terminator for prompt
	mov	comand.cmdirect,1	; say read directly from kbd/file
	mov	dx,offset decbuf+129	; converted prompt string, asciiz
 	call	prompt			; use our prompt
	mov	bx,offset rdbuf+129	; use this buffer for raw user input
	mov	word ptr [bx],0		; insert terminator
	mov	dl,askecho		; get echo/quiet flag
	mov	comand.cmquiet,dl	; 0 if echoing
	mov	dx,offset askhlp3	; help for user input
	mov	comand.cmdirect,1	; say read directly from kbd/file
	cmp	temp,1			; getc?
	jne	ask8			; ne = no
ask5:	mov	dl,0ffh
	mov	ah,dconio		; read console
	int	dos
	jz	ask5			; z = nothing there
	cmp	al,3			; Control-C?
	jne	ask6			; ne = no
	mov	flags.cxzflg,'C'	; return Control-C status to parser
	stc				; return error
	ret
ask6:	or	al,al			; scan code being returned?
	jnz	ask7			; nz = no, accept
	mov	ah,dconio		; read and discard second byte
	mov	dl,0ffh
	int	dos
	mov	ah,conout		; ring the bell
	mov	dl,bell
	int	dos
	jmp	short ask5		; else unknown, ignore

ask7:	xor	ah,ah			; null terminator
	cmp	al,'('			; function delimiters?
	je	ask7a			; e = yes
	cmp	al,')'
	je	ask7a			; e = yes
	cmp	al,'{'			; string delimiters?
	je	ask7a			; e = yes
	cmp	al,'}'
	je	ask7a			; e = yes
	cmp	al,DEL			; this control?
	je	ask7a			; e = yes
	cmp	al,' '			; senstive (controls + space)?
	ja	ask7b			; a = no
ask7a:	mov	rdbuf+129,'\'		; numeric form prefix
	mov	di,offset rdbuf+130
	call	dec2di			; convert to \decimal, asciiz
	clc
	jmp	short ask9
ask7b:	mov	word ptr rdbuf+129,ax	; byte and terminator
	clc
	jmp	short ask9		; process byte

ask8:	mov	ah,cmline		; read user's input string
	mov	comand.cmper,1		; do not expand variable names
	mov	comand.cmdonum,1	; \number conversion allowed
	call	comnd
ask9:	mov	comand.cmquiet,0	; permit echoing again
	mov	comand.cmdirect,0	; read normally again
	jnc	ask10			; nc = success
	ret				; Control-C, quit now
ask10:	mov	cx,ax			; length of entry
	mov	di,offset rdbuf+2
	mov	si,offset decbuf+2
	call	strcpy
	mov	dx,di
	call	strlen
	add	di,cx
	mov	si,offset rdbuf+129
	call	strcpy
 	mov	dx,offset rdbuf+2	; command buffer beginning
	call	strlen			; CX=len of <variable>< ><user string>
	call	DODECOM			; define the macro/variable and exit
	ret
ASK	ENDP

; GETOK <prompt>   displays prompt or default prompt, asks for affirmative
; user reply, returns success/fail status.
getok	proc	near
	mov	bx,offset rdbuf		; point to work buffer
	mov	dx,offset getokhlp
	mov	comand.cmblen,127	; our buffer length
	mov	comand.cmcr,1		; bare cr is ok
	mov	comand.cmdonum,1	; \number conversion allowed
	mov	ah,cmline		; get prompt string
	mov	comand.cmcr,0
	call	comnd
	jnc	getok1			; nc = success
	ret				; failure
getok1:	or	ax,ax			; anything given?
	jnz	getok2			; nz = yes
	mov	si,offset getdef	; default prompt
	mov	di,offset rdbuf
	call	strcpy			; paste in default prompt

getok2:	mov	si,offset rdbuf
	mov	dx,si
	call	strlen			; get length to cx
	mov	bx,cx
	mov	word ptr [si+bx],0020h	; printing terminator for prompt
getok3:	mov	dx,offset rdbuf		; converted prompt string, asciiz
	mov	comand.cmdirect,1	; force input from kbd/file
 	call	prompt			; use our prompt
	mov	flags.cxzflg,0		; clear Control-C indicator
	mov	dx,offset gettab	; use this table
	xor	bx,bx			; table is help
	mov	comand.cmcr,1		; null response permitted
	mov	ah,cmkey		; read user's input word
	call	comnd
	mov	comand.cmcr,0
	mov	comand.cmdirect,0	; end force input from kbd/file
	jnc	getok4			; nc = success
	cmp	flags.cxzflg,'C'	; did user type Control-C to quit?
	jne	short getok3		; ne = no, syntax failure, reprompt
	stc				; set carry flag again
	jmp	short getok5		; exit failure
getok4:	push	bx
	mov	comand.cmdirect,1	; force input from kbd/file
	mov	ah,cmeol		; get c/r confirmation
	call	comnd
	mov	comand.cmdirect,0	; end force input from kbd/file
	pop	bx			; recover keyword 16 bit value
getok5:	jnc	getok6			; nc = success
	mov	kstatus,ksgen		; failure
	ret				; Control-C, quit now
getok6:	mov	kstatus,bx		; return status
	ret
getok	endp

; FOR macro-name start end step {commands}
FORCMD	proc	near
	mov	kstatus,ksgen		; general command failure
	mov	ah,cmword		; macro name
	mov	bx,offset decbuf
	mov	dx,offset forhlp	; help
	mov	comand.cmper,1		; don't react to \%x variables
	call	comnd
	jnc	for1			; nc = success
forx:	mov	ah,cmeol		; consume and discard the rest
	call	comnd
	stc
	ret				; failure
for1:	cmp	word ptr decbuf,'%\'	; start of variable name?
	jne	for2			; ne = no
	cmp	ax,3			; only three chars in name?
	je	for3			; e = yes, we have \%<char>
for2:	mov	dx,offset forbadname
	mov	ah,prstr
	int	dos
	jmp	short forx
for3:	mov	bx,offset decbuf+4 	; where 'start' begins
	mov	forstartptr,bx 		; remember where 'start' begins
	mov	dx,offset forhlp
	mov	ah,cmword		; get 'start'
	call	comnd
	jc	forx			; c = failure
	mov	bx,forstartptr		; 'start'
	call	todigits		; convert to string of digits
	mov	dx,offset forhlp
	jc	forx			; c = failure
	inc	bx			; leave null terminator intact
	mov	forendptr,bx		; 'end' starts here
	mov	dx,offset forhlp
	mov	ah,cmword		; get 'end'
	call	comnd
	jc	forx			; c = failure
	mov	bx,forendptr		; 'end' string
	call	todigits		; convert to string of digits
	jc	forx			; c = failure
	inc	bx			; leave null terminator intact
	mov	forstepptr,bx		; 'step' starts here
	mov	dx,offset forhlp
	mov	ah,cmword		; get 'step'
	call	comnd
	jc	forx			; c = failure
	mov	bx,forstepptr
	mov	cl,[bx]			; get possible minus sign on step
	mov	byte ptr temp,cl	; save for bottom of this work
	call	todigits		; convert to string of digits
	jc	forx			; c = failure
	inc	bx			; leave null terminator intact
	mov	forcmdsptr,bx		; commands start here
	mov	dx,offset forhlp
	mov	comand.cmper,1		; don't react to \%x variables
	mov	comand.cmblen,cmdblen	; allow long lines
	mov	comand.cmcnvkind,cmcnv_crprot ; allow CR within {..}
	mov	ah,cmline		; get {commands}
	call	comnd
	jc	forx			; c = failure
; At this point decbuf looks like this:
; <string variable name><byte null><string end><byte null>
;  <string step><byte null><string commands><byte null>

for4:					; define variable<space><start>
	mov	si,offset decbuf	; start of variable name
	mov	di,offset rdbuf+2
	call	strcpy			; variable name
	mov	dx,di
	call	strlen			; length to cx for dodecom
	add	di,cx
	mov	byte ptr [di],' '	; space
	inc	di			; look at next byte
	push	di			; where number is formed
	mov	si,forstartptr
	call	strcpy			; copy start
	mov	dx,di
	call	strlen
	add	dx,cx			; point at terminating null
	mov	di,dx
	mov	word ptr [di],'-'	; minus, null
	mov	si,forstepptr		; step
	call	strcat			; append, have (start - step)
	pop	di

	mov	dx,di
	mov	domath_ptr,dx
	call	strlen
	mov	domath_cnt,cx
	call	domath			; math to dx:ax
	push	word ptr decbuf
	push 	word ptr decbuf+2	; preserve variable name \%c 
	call	lnout			; DX:AX to DS:DI as ASCII digits
	pop	word ptr decbuf+2	; retore variable around work
	pop	word ptr decbuf
	mov	dx,offset rdbuf+2	; buffer for dodecom
	call	strlen			; length to cx for dodecom
	call	dodecom			; define macro<space>start<null>
	mov	si,offset forstr1	; build composite command string
	mov	di,offset rdbuf+2	; starting at rdbuf+2
	call	strcpy			; 'forinc '
	mov	si,offset decbuf	; 'variable'
	call	strcat
	mov	si,offset space		; space null
	call	strcat
	mov	si,forstepptr		; 'step'
	call	strcat
	mov	si,offset forstr2	; cr,'if not > '
	call	strcat
	cmp	byte ptr temp,'-'	; negative step?
	jne	for4a			; ne = no
	mov	dx,offset rdbuf+2
	call	strlen
	add	dx,cx			; points at trailing null
	mov	si,dx
	mov	byte ptr [si-2],'<'	; reverse sense of test for neg step
for4a:	mov	si,offset decbuf	; 'variable'
	call	strcat
	mov	si,offset space		; space null
	call	strcat
	mov	si,forendptr		; 'end'
	call	strcat
	mov	si,offset space		; space null
	call	strcat
	mov	si,forcmdsptr		; 'commands'
	call	strcat

	mov	dx,offset rdbuf+2	; string is built at rdbuf+2
	call	strlen
	mov	ax,cx			;
	add	ax,2+1			; bytes needed plus ending CR
	call	malloc
	mov	es,ax			; seg
	mov	di,2			; start two bytes in
	mov	si,offset rdbuf+2
	push	cx
	cld
	rep	movsb			; copy from rdbuf+2 to malloc'd area
	pop	cx
	mov	al,CR
	stosb
	inc	cx			; count CR in macro
	call	takopen_macro		; open a macro
	mov	bx,takadr		; point to current macro structure
	mov	ax,es			; segment of definition
	mov	[bx].takbuf,ax		; segment of definition string struc
	mov	[bx].takcnt,cx		; number of chars in definition
	mov	es:[0],cx		; buffer usage, for rewinding
	mov	[bx].takargc,0		; our argument count
	mov	[bx].takptr,2		; offset to read next command char
	or	[bx].takattr,take_malloc ; free buffer when done
	or	[bx].takattr,take_while
	clc
	ret
FORCMD	endp

; Perform "inc variable step" from first two command line words
_forinc proc	near
	mov	ah,cmword		; read variable name
	mov	comand.cmper,1		; don't expand variable names here
	mov	bx,offset rdbuf+2	; buffer
	xor	dx,dx			; no help
	call	comnd
	jc	forincx			; c = failure
	
	mov	word ptr rdbuf,ax	; save length of macro name
	mov	si,offset mcctab	; table of macro names
	cld
	lodsb
	xor	ch,ch
	mov	cl,al			; number of macro entries
	or	al,al
	jnz	forinc4			; nz = have some
forincx:mov	ah,cmeol		; kill rest of line
	mov	comand.cmcnvkind,cmcnv_crprot ; allow CR within {..}
	call	comnd
	stc
	ret
					; find variable
forinc4:push	cx			; save loop counter
	lodsw				; length of macro name to ax
	mov	cx,word ptr rdbuf	; length of user's string
	cmp	ax,cx			; variable name same as user spec?
	jne	forinc6			; ne = no, no match
	push	ax
	push	si			; save these around match test
	mov	di,offset rdbuf+2	; user's string
forinc5:mov	ah,[di]
	inc	di
	lodsb				; al = mac name char, ah = user char
	and	ax,not 2020h		; clear bits (uppercase chars)
	cmp	ah,al			; same?
	loope	forinc5			; while equal, do more
	pop	si			; restore regs
	pop	ax
	jne	forinc6			; ne = no match
	pop	cx			; remove loop counter
	jmp	short forinc7		; e = match
forinc6:add	si,ax			; point to next name, add name length
	add	si,2			;  and string pointer
	pop	cx			; recover loop counter
	loop	forinc4			; one less macro to examine
	jmp	forincx			; failed to locate

forinc7:mov	ax,[si-2]		; get length of variable string
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
forinc9:mov	al,es:[si]		; copy string to regular data segment
	mov	[di],al
	inc	si
	inc	di
	loop	forinc9
	pop	es

	mov	byte ptr [di],'+'
	inc	di
	push	di			; save place after '+'
	mov	bx,di			; optional step goes here

	mov	ah,cmword		; get step size, if any
	xor	dx,dx			; no help at this level
	call	comnd
	pop	di
	jc	forincx			; c = fail
					; now convert step size, if any
	or	ax,ax			; is length zero?
	jnz	forinc15		; nz = no, convert number to binary
	mov	word ptr [di],'1'	; put '1' where optional is missing

forinc15:
	mov	di,offset rdbuf+2	; user's variable name
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
	jne	forincx			; ne = no, fail
					; step size is in ax
	or	dx,dx			; is result negative?
	jns	forinc16		; ns = no, positive or zero
	neg	dx			; flip sign
	neg	ax
	sbb	dx,0
	mov	byte ptr [di],'-'	; show minus sign
	inc	di
forinc16:call	lnout			; binary to ascii decimal in ds:di
	mov	dx,offset rdbuf+2	; place of <var><space><value>
	call	strlen			; length to cx for dodecom
	call	dodecom			; re-define variable
	clc				; return to let rest of cmd execute
	ret				; as an IF statement
_forinc endp

; Convert numeric expression to string of digits as a replacement, asciiz.
; Enter with BX=start of expression, AX= length of expression.
; Returns BX=null at end of number and carry clear if success,
; or carry set and no change if failure
todigits proc	near
	mov	domath_ptr,bx		; source text
	mov	domath_cnt,ax		; length
	call	domath
	jnc	todigits1		; nc = converted value
	ret				; fail
todigits1:
	push	di
	mov	di,bx			; where to write
	or	dx,dx			; is result negative?
	jns	todigits2		; ns = no, positive or zero
	neg	dx			; flip sign
	neg	ax
	sbb	dx,0
	mov	byte ptr [di],'-'	; show minus sign
	inc	di
todigits2:
	call	lnout			; convert DX:AX to ASCIIZ in DS:DI
	mov	bx,di			; point to trailing null
	pop	di
	clc				; success
	ret
todigits endp

; Initialize macro IBM at Kermit startup time
initibm	proc	near
	mov	si,offset ibmmac	; text of IBM macro
	mov	di,offset rdbuf+2	; where command lines go
	call	strcpy			; copy it there
	mov	dx,di			; get length of command line
	call	strlen			; set cx to length, for dodecom
	call	dodecom			; now define the macro
	mov	rdbuf+2,0
	mov	si,offset dialmac
	mov	di,offset rdbuf+2
	call	strcpy
	mov	dx,di
	call	strlen
	inc	cx
	jmp	dodecom			; now define the macro
initibm	endp

; Open an text subsititution macro. No buffer is allocated.
takopen_sub	proc	far
	cmp	taklev,maxtak		; room in take level?
	jb	takosub1		; b = yes
	mov	dx,offset ermes4	; say too many Take files
	mov	ah,prstr		; display error message
	int	dos
	stc				; set carry for failure
	ret

takosub1:push	ax
	push	bx
	mov	bx,takadr		; previous take structure
	push	[bx].takargc		; stash argument count
	push	[bx].takctr		; stash COUNT
	add	takadr,size takinfo	; pointer to new Take structure
	inc	taklev
	mov	bx,takadr		; pointer to new Take structure
	pop	[bx].takctr		; copy in old count
	pop	[bx].takargc		; copy in old argc
	xor	ax,ax
	mov	[bx].takbuf,ax		; seg of memory block
	mov	[bx].takptr,2		; where to read first
	mov	[bx].takcnt,ax		; unread bytes in buffer
	mov	[bx].takper,al		; expand macros
	mov	[bx].takattr,al		; attribute, none
	mov	[bx].taktyp,take_sub	; kind is text substitution
	mov	[bx].takinvoke,0
	pop	bx
	pop	ax
	clc
	ret
takopen_sub	endp

; Open take structure for file input. Buffer of tbufsiz is preallocated
; and pointed to by takbuf:takptr.
takopen_file	proc	far
	call	takopen_sub		; do substitution macro busy work
	jnc	takofil1		; nc = success so far
	ret				; fail
takofil1:push	bx
	mov	bx,takadr
	mov	ax,tbufsiz		; size of buffer
	call	malloc
	jnc	takofil2		; nc = success
	pop	bx
	ret				; fail

takofil2:mov	[bx].takbuf,ax		; seg of allocated buffer
	mov	[bx].takattr,take_malloc ; remember so takclos will free it
	mov	[bx].taktyp,take_file	; disk file kind
	mov	[bx].takhnd,0		; file handle
	mov	word ptr [bx].takseek,0
	mov	word ptr [bx].takseek+2,0 ; seek distance, bytes
	or	[bx].takattr,take_autocr ; need auto CR at EOF
	mov	[bx].takinvoke,0
	pop	bx
	clc
	ret
takopen_file	endp

; Open an internal (macro) structure. No buffer is allocated.
; Return carry clear for success, carry set for failure.

takopen_macro	proc	far
	push	ax
	push	bx
	push	cx
	push	dx
	cmp	taklev,maxtak		; room in take level?
	jb	takoma1			; b = yes
	mov	dx,offset ermes4	; say too many Take files
	mov	ah,prstr		; display error message
	int	dos
	stc				; set carry for failure
	jmp	takoma2

takoma1:xor	ax,ax
	add	takadr,size takinfo	; pointer to new Take structure
	inc	taklev
	mov	bx,takadr		; pointer to new Take structure
	mov	[bx].takargc,ax		; clear
	mov	[bx].takctr,ax		; clear
	mov	[bx].takbuf,ax		; no segment of Take buffer
	mov	[bx].takcnt,ax		; number of unread bytes
	mov	[bx].takptr,2		; init pointer to definition itself
	mov	[bx].takper,al		; expand macros
	mov	[bx].takattr,take_autocr ; need auto CR at EOF
	mov	[bx].taktyp,take_macro	; macro
	mov	[bx].takinvoke,0
	clc				; carry clear for success
takoma2:pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
takopen_macro endp

; Close Take file. Enter at Take level to be closed.
; Closes disk file, pops Take level.

TAKCLOS	PROC	FAR
	cmp	taklev,0		; anything to close?
	jg	takclo1			; g = yes
	ret
takclo1:push	ax
	push	bx
	push	cx
	mov	bx,takadr
	test	[bx].takattr,take_malloc ; new malloc'd buffer in takbuf?
	jz	takclo2			; z = no
	mov	ax,[bx].takbuf
	push	es
	mov	es,ax			; seg of separately malloc'd buffer
	mov	ah,freemem		; free it
	int	dos
	pop	es
	and	[bx].takattr,not take_malloc ; no extra buffer to free
takclo2:mov	al,[bx].taktyp
	cmp	al,take_macro		; macro?
	je	takclo3			; e = yes
	cmp	al,take_file		; disk file?
	jne	takclo6			; ne = no, leaves sub and comand kinds
	mov	word ptr [bx].takseek,0	; disk file
	mov	word ptr [bx].takseek+2,0 ; seek distance, bytes
	mov	bx,[bx].takhnd		; get file handle
	mov	ah,close2		; close file
	int	dos

					; macros, remove argument array
takclo3:cmp	[bx].takargc,0		; any arguments to macro?
	je	takclo5			; e = no
	mov	word ptr settemp,3	; remove \%0..9 macros. length word
	mov	word ptr settemp+2,'%\'	; "\%digit"
	mov	settemp+4,'0'
takclo4:mov	di,offset settemp	; buffer remtab reads
	call	remtab			; remove macro
	inc	settemp+4		; next digit
	cmp	settemp+4,'9'		; done last?
	jbe	takclo4			; be = no
takclo5:mov	hidetmp,1		; unhide local
	call	unhidemac		; rename previous hidden macros
	mov	hidetmp,0		; unhide \% args
	call	unhidemac		; rename previous hidden macros

takclo6:mov	bx,takadr		; all kinds of Take
	xor	al,al			; get a null
	mov	[bx].taktyp,al		; clear to avoid confusion
	mov	[bx].takper,al		; macro expansion flag
	mov	[bx].takattr,al		; attributes
	dec	taklev			; pop macro Take level
	sub	takadr,size takinfo	; get previous Take's address
	pop	cx
	pop	bx
	pop	ax
	ret
TAKCLOS	ENDP

; POP/END command. Defend against command parser closing the Take/Macro at
; the end of file. Return optional trailing number in ERRORLEVEL (errlev).
POPCMD	proc	near
	mov	oldifelse,0		; don't permit ELSE after failed IF
	mov	ifelse,0
	mov	ah,cmword		; get optional error value and msg
	mov	bx,offset rdbuf+2
	mov	dx,offset pophlp	; help on numerical argument
	mov	comand.cmcr,1		; bare c/r's allowed
	call	comnd
	mov	word ptr rdbuf,ax	; save length here
	mov	comand.cmcr,0		; restore normal state
	jc	popcmdx			; c = failure
	mov	ah,cmline		; get optional error value and msg
	mov	bx,offset rdbuf+100
	mov	dx,offset pophlp	; help on numerical argument
	mov	comand.cmcr,1		; bare c/r's allowed
	mov	comand.cmdonum,1	; \number conversion allowed
	call	comnd
	mov	comand.cmcr,0		; restore normal state
	jc	popcmdx			; c = failure
	mov	domath_ptr,offset rdbuf+2
	mov	ax,word ptr rdbuf	; get length of string
	mov	domath_cnt,ax
	call	domath			; convert to number in ax
	jc	popcmd2			; c = not a number
	mov	errlev,al		; return value in ERRORLEVEL
	mov	kstatus,ax		; and in STATUS
	mov	si,offset rdbuf+100
popcmd1:lodsb				; read a msg char
	or	al,al			; null terminator?
	jz	popcmd2			; z = empty string
	cmp	al,' '			; leading white space?
	je	popcmd1			; be = leading white space
	dec	si			; backup to non-white char
	mov	dx,offset crlf
	mov	ah,prstr
	int	dos
	mov	dx,si			; message
	call	prtasz
popcmd2:call	poplevel		; do the pop
popcmdx:ret
POPCMD	endp

; Common Get keyword + Get Confirm sequence. Call with dx = keyword table,
; bx = help message offset. Returns result in BX. Modifies AX, BX.
; Returns carry clear if sucessful else carry set. Used in many places below.
keyend	proc	near
	mov	ah,cmkey
	call	comnd
	jnc	keyend1			; nc = success
	ret				; failure
keyend1:push	bx			; save returned results around call
	mov	ah,cmeol		; get c/r confirmation
	call	comnd
	pop	bx			; recover keyword 16 bit value
	ret				; return with carry from comnd
keyend	endp

srvdsa	proc	near			; DISABLE Server commands
	mov	dx,offset srvdetab
	mov	bx,offset sdshlp
	call	keyend
	jc	srvdsa1			; c = failure
	cmp	apctrap,0		; disable from APC
	jne	srvdsa1			; ne = yes
	or	denyflg,bx		; turn on bit (deny) for that item
srvdsa1:ret
srvdsa	endp

srvena	proc	near			; ENABLE Server commands
	mov	dx,offset srvdetab	; keyword table
	mov	bx,offset sdshlp	; help on keywords
	call	keyend
	jc	srvena1			; c = failure
	cmp	apctrap,0		; disable from APC
	jne	srvena1			; ne = yes
	not	bx			; invert bits
	and	denyflg,bx		; turn off (enable) selected item
srvena1:ret
srvena	endp

; DIAL arg list
; Invokes macro DIAL with args or, if not present, then macro "\0IAL"
; defined above, with args.
dial	proc	near
	mov	kstatus,kssuc		; assume success
	mov	word ptr decbuf,4	; length of our name
	mov	word ptr decbuf+2,'ID'	; prefix with "DIAL "
	mov	word ptr decbuf+4,'LA'
	call	dialcom			; look for macro "DIAL"
	jnc	dial1			; nc = found "DIAL"
	mov	si,offset dialmac	; default string "__DIAL"
	mov	di,offset decbuf+2	; destination
	push	es
	mov	ax,seg decbuf
	mov	es,ax
	mov	cx,6			; string length
	cld
	rep	movsb			; copy string
	pop	es
	mov	word ptr decbuf,6	; string length
	call	dialcom			; look for it
	jc	dialx			; c = failed, quit
dial1:	jmp	docom1			; DO macro with bx set for domacptr

dialx:	mov	kstatus,kstake		; Take file command failure
	stc				; fail
	ret
dial	endp

code	ends

code1	segment
	assume	cs:code1

; Worker for DIAL command. Find macro whose name is in offset decbuf+2
; and whose length is in word ptr decbuf.
; Return carry clear and macro seg in BX if success, else carry set.
dialcom	proc	far
	push	si
	push	di
	push	es
	mov	ax,ds
	mov	es,ax			; check for existence of macro
	mov	bx,offset mcctab	; table of macro names
	mov	cl,[bx]			; number of names in table
	xor	ch,ch
	jcxz	dialcx			; z = empty table, do nothing
	inc	bx			; point to length of first name
dialc2:	mov	ax,[bx]			; length of this name
	cmp	ax,word ptr decbuf	; length same as desired keyword?
	jne	dialc3			; ne = no, search again
	mov	si,bx
	add	si,2			; point at first char of macro name
	push	cx			; save name counter
	push	di			; save reg
	mov	cx,word ptr decbuf	; length of name
	mov	di,offset decbuf+2	; point at desired macro name
	push	es			; save reg
	push	ds
	pop	es			; make es use data segment
	cld
	repe	cmpsb			; match strings
	pop	es			; need current si below
	pop	di			; recover saved regs
	pop	cx
	jne	dialc3			; ne = not matched
	add	bx,ax			; length of name
	add	bx,2			; count + name, points at word ptr
	mov	bx,[bx]			; return word ptr in BX
	clc				; say success
	jmp	short dialcx		; and return
	
dialc3:	add	bx,ax			; step to next name, add name length
	add	bx,4			; + count and def word ptr
	loop	dialc2			; try next name
	stc				; say failure
dialcx:	pop	es
	pop	di
	pop	si			; no macro
	ret
dialcom	endp
code1	ends

code	segment
	assume	cs:code
; This is the SET command
; Called analyzers return carry clear for success, else carry set.
SETCOM	PROC	NEAR			; Dispatch all SET commands from here
	mov	kstatus,kssuc		; global status, success
	mov	dx,offset settab	; Parse a keyword from the set table
	mov	bx,offset sethlp
	mov	ah,cmkey
	call	comnd
	jc	setcom1			; c = failure
	jmp	bx			; execute analyzer routine
setcom1:ret
SETCOM	endp

SETATT	PROC	NEAR			; Set attributes on | off
	mov	dx,offset atttab
	xor	bx,bx
	mov	ah,cmkey
	call	comnd
	jc	setatt3			; c = failure
	mov	dx,bx			; hold results in dx
	cmp	dl,0ffh			; ON/OFF (all of them)?
	je	setatt1			; e = yes
	push	dx
	mov	dx,offset ontab		; get on/off state
	xor	bx,bx
	mov	ah,cmkey
	call	comnd
	pop	dx
	jc	setatt3			; c = failure
	mov	dh,bl			; store on/off state in dh
setatt1:push	dx
	mov	ah,cmeol
	call	comnd
	pop	dx
	jc	setatt3
	mov	al,flags.attflg		; current flags
	not	dl			; all but those affected
	and	al,dl			; turn off affected flags
	or	dh,dh			; off (dh = 0)?
	jz	setatt2			; z = yes
	not	dl			; affected flags back again as ones
	or	al,dl			; turn on affected flags
setatt2:mov	flags.attflg,al
setatt3:ret
SETATT	ENDP

; SET BAUD or SET SPEED
; See system dependent routine BAUDST in file MSXxxx.ASM

; SET BELL on or off

BELLST	PROC	NEAR
	mov	dx,offset ontab		; on/off table
	xor	bx,bx			; help
	call	keyend
	jc	bellst1			; c = failure
	mov	flags.belflg,bl
bellst1:ret
BELLST	ENDP

; SET BLOCK-CHECK

BLKSET	PROC	NEAR
	mov	dx,offset blktab	; table
	xor	bx,bx			; help, use table
	call	keyend
	jc	blkset1			; c = failure
	mov	dtrans.chklen,bl	; use this char as initial checksum
blkset1:ret
BLKSET	ENDP

; SET CARRIER {ON, OFF}
setcar	proc	near
	mov	dx,offset ontab		; table
	mov	bx,offset carhlp	; help, use table
	call	keyend
	jc	setcar1			; c = failure
	mov	flags.carrier,bl	; value
	mov	cardet,0		; clear carrier detect variable
	clc
setcar1:ret
setcar	endp

; Set port addresses for COM1 .. COM4 at Kermit initialization time via
; Environment. Called by command parser while doing Environment reading in
; mssker.asm and via SET COM1 .. SET COM4.
COM1PORT proc	near
	mov	bx,0			; offset of com1 port address
	jmp	short comport
COM1PORT endp
COM2PORT proc	near
	mov	bx,2			; offset of com2 port address
	jmp	short comport
COM2PORT endp
COM3PORT proc	near
	mov	bx,4			; offset of com3 port address
	jmp	short comport
COM3PORT endp

COM4PORT proc	near
	mov	bx,6			; offset of com4 port address
;;	jmp	comport
COM4PORT endp

COMPORT	proc	near			; worker for above
	push	bx			; save offset
	shr	bx,1			; address bytes 0..3
	mov	ah,portfifo[bx]		; save existing port values
	mov	al,portirq[bx]
	mov	temp2,ax		; worker word
	mov	bx,offset rdbuf
	mov	dx,offset comhlp
	mov	ah,cmword		; get port address number
	call	comnd
	jnc	compor3
	pop	bx			; fail
	ret
compor3:mov	numerr,0		; no error message
	mov	min,100h		; smallest number
	mov	max,0fff0h		; largest magnitude
	mov	numhlp,0		; help
	call	numwd			; parse this word
	jnc	compor4			; nc = success, value in ax
	pop	bx
	ret
compor4:mov	temp1,ax		; save port address
	mov	bx,offset rdbuf
	mov	dx,offset irqhlp
	mov	ah,cmword		; read IRQ
	call	comnd
	jnc	compor5
	pop	bx
	ret
compor5:
	push	ax
	push	bx
	mov	ah,cmkey
	mov	bx,offset fifohlp	; help
	mov	dx,offset FIFOtab	; action table
	mov	comand.cmcr,1		; null response permitted
	call	comnd
	jc	compor8			; c = nothing present
	mov	byte ptr temp2+1,bl	; save FIFO setting
compor8:pop	bx
	pop	ax

	push	ax
	mov	ah,cmeol		; get command confirmation
	call	comnd
	pop	ax
	jnc	compor5a		; nc = success
	ret
compor5a:or	ax,ax			; anything given?
	jz	compor7			; z = no
	mov	numhlp,0		; help
	mov	numerr,0		; no error message
	mov	min,2			; smallest number
	mov	max,15			; largest magnitude
	call	numwd			; parse this word
	jnc	compor6			; nc = success
	pop	bx
	ret
compor6:mov	byte ptr temp2,al	; save IRQ
compor7:pop	bx			; recover offset
	cmp	word ptr machnam,'BI'	; check for "IBM-PC"
	jne	compor1			; ne = not this name, fail
	cmp	word ptr machnam+2,'-M'
	jne	compor1
	cmp	word ptr machnam+4,'CP'
	jne	compor1
	push	es
	mov	al,flags.comflg		; current comms port
	dec	al			; count from 0, as per Bios
	shl	al,1			; double to use word index of Bios
	cmp	al,bl			; using this port now?
	jne	compor2			; ne = no
	call	serrst			; reset the port
compor2:mov	cx,40h			; segment 40h
	mov	es,cx
	mov	ax,temp1		; port address
	mov	es:[bx],ax		; set port address
	pop	es
	shr	bl,1			; coms port offset 0,2,4,6 to 0,1,2,3
	mov	ax,temp2		; FIFO and IRQ
	mov	portirq[bx],al		; IRQ
	mov	portfifo[bx],ah		; FIFO
	clc
compor1:ret
COMPORT	endp

; Set CONTROL PREFIXED <code>, CONTROL UNPREFIXED <code>, code can be ALL
cntlset	proc	near
	push	es
	mov	di,seg decbuf		; copy protlist to work buffer decbuf
	mov	es,di
	mov	si,offset protlist
	mov	di,offset decbuf
	mov	cx,32
	cld
	rep	movsb
	pop	es

	mov	dx,offset cntltab	; table
	mov	bx,offset cntlhlp	; help
	mov	ah,cmkey
	call	comnd
	jc	cntlsetx		; c = failure
	mov	rdbuf,bl		; save operation value
cntlse1:mov	ah,cmword		; get optional error value and msg
	mov	bx,offset rdbuf+1
	mov	dx,offset ctlhlp	; help on numerical argument
	call	comnd
	jc	cntlsetx		; c = failure
	mov	si,offset rdbuf+1	; skip operational value in rdbuf
	or	ax,ax			; anything given?
	jnz	cntlse2			; nz = yes
	mov	ah,cmeol		; confirm
	call	comnd
	jc	cntlsetx		; c = failure
	push	es			; copy work buffer decbuf to protlist
	mov	di,seg protlist
	mov	es,di
	mov	di,offset protlist
	mov	si,offset decbuf
	mov	cx,32
	cld
	rep	movsb
	pop	es
	clc
	ret

cntlse2:mov	al,[si]			; look for ALL
	or	al,al			; end of string?
	jz	cntlse1			; z = yes, get more user input
	cmp	al,','			; comma separator?
	jne	cntlse2a		; ne = no
	inc	si			; skip it
	jmp	short cntlse2
cntlse2a:or	al,20h			; to lower
	cmp	al,'a'			; a in ALL?
	je	cntlse8			; e = got ALL
cntlse3:mov	domath_ptr,si
	mov	domath_cnt,16
	call	domath			; convert to number in ax
	jc	cntlsety		; c = failure
	mov	si,domath_ptr		; next byte
	cmp	al,159			; out of range?
	ja	cntlsety		; a = yes
	cmp	al,128			; in 8-bit range?
	jae	cntlse4			; ae = yes
	cmp	al,31			; out of range?
	ja	cntlsety		; a = yes
cntlse4:mov	ah,rdbuf		; protected/unprotected pointer 0/1
	mov	bl,al			; char
	and	bl,not 80h		; strip high bit from index
	xor	bh,bh
	or	ah,ah			; protecting?
	jz	cntlse6			; z = yes
	mov	ah,1			; assume unprotecting 7-bit char
	and	al,80h			; get high bit
	jz	cntlse5			; z = no high bit
	mov	ah,80h			; set high bit flag
cntlse5:or	decbuf[bx],ah		; set unprotection bit
	jmp	cntlse2			; get more input

cntlse6:mov	ah,1			; assume protecting 7-bit char
	and	al,80h			; get high bit
	jz	cntlse7			; z = no high bit
	mov	ah,80h			; set high bit flag
cntlse7:not	ah			; invert bits
	and	decbuf[bx],ah		; clear the unprotection bit
	jmp	cntlse2			; get more input

cntlsetx:ret				; success or failure
					; process ALL
cntlse8:mov	cx,32
	xor	bx,bx
	mov	al,rdbuf		; get kind of operation
	or	al,al			; prefix (0)?
	je	cntlse9			; e = yes
	mov	al,81h			; unprefix all (7 and 8 bit)
cntlse9:mov	decbuf[bx],al		; set the state
	inc	bx
	loop	cntlse9			; do all
	jmp	cntlse1			; get more user input

cntlsety:mov	ah,cmeol		; confirm
	call	comnd
	mov	ah,prstr
	mov	dx,offset badcntlmsg	; say out of range
	int	dos
	stc
	ret
cntlset	endp

; SET COUNTER number	for script IF COUNTER number <command>
TAKECTR	PROC	NEAR
	mov	min,0			; get decimal char code
	mov	max,65535		; range is 0 to 65535 decimal
	mov	numhlp,offset takchlp	; help message
	mov	numerr,0		; error message
	call	num0			; convert number, return it in ax
	jc	takect2			; c = error
	push	ax			; save numerical code
	mov	ah,cmeol
	call	comnd			; get a confirm
	pop	ax			; recover ax
	jc	takect2			; c = failure
	cmp	taklev,0		; in a Take file?
	je	takect4			; e = no
	push	bx
	mov	bx,takadr
	mov	[bx].takctr,ax		; set COUNT value
	pop	bx
	clc				; success
takect2:ret
takect4:mov	dx,offset takcerr	; say must be in Take file
	jmp	reterr			; display msg and return carry clear
TAKECTR	ENDP

; RESET 
reset	proc	near
	mov	dx,offset resettab
	xor	bx,bx
	call	keyend
	jnc	reset1			; nc = success
	ret				; failure
reset1:	mov	al,bl			; reset clock
	mov	bx,portval
	mov	starttime[bx+3],bl	; remember in high byte
	ret
reset	endp

; SET DEBUG {OFF | ON | SESSSION | PACKETS}

DEBST	PROC       NEAR
	mov	dx,offset debtab
	mov	bx,offset debhlp
	call	keyend
	jnc	debst1			; nc = success
	ret				; failure
debst1:	or	flags.debug,bl		; set the mode, except for Off
	or	bx,bx			; OFF?
	jnz	debst2			; nz = no
	mov	flags.debug,bl		; set the DEBUG flags off
debst2:	clc				; success
	ret
DEBST	ENDP

; SET DESTINATION   of incoming files

DESSET	PROC	NEAR
	mov	dx,offset destab
	xor	bx,bx
	call	keyend
	jc	desset1			; c = failure
	mov	flags.destflg,bl	; set the destination flag
desset1:ret
DESSET	ENDP

; SET DEFAULT-DISK    for sending/receiving, etc
; See cwdir in file mssker

; SET DELAY seconds   Used only for SEND command in local mode
SETDELY	PROC	NEAR
	mov	min,0			; smallest acceptable value
	mov	max,63			; largest acceptable value
	mov	numhlp,offset delyhlp	; help message
	mov	numerr,0		; complaint message
	call	num0			; parse numerical input
	jc	setdly1			; c = error
	mov	trans.sdelay,al
setdly1:ret				; success or failure
SETDELY	ENDP

; SET DISPLAY Quiet/Regular/Serial/7-Bit/8-Bit (inverse of Set Remote on/off)
; Accepts two keywords in one command
disply	proc	near
	mov	ah,cmkey
	mov	dx,offset distab
	mov	bx,offset dishlp
	call	comnd
	jnc	displ0			; nc = success
	ret				; return failure
displ0:	mov	temp1,bx		; save parsed value
	mov	temp2,0ffffh		; assume no second keyword
	mov	comand.cmcr,1		; bare CR's are allowed
	mov	ah,cmkey		; parse for second keyword
	mov	dx,offset distab
	mov	bx,offset dishlp
	call	comnd
	jc	displ1			; no keyword
	mov	temp2,bx		; get key value
displ1:	mov	comand.cmcr,0		; bare CR's are not allowed
	mov	ah,cmeol
	call	comnd			; confirm
	jnc	displ2			; nc = success
	ret				; failure
displ2:	mov	ax,temp1		; examine first key value
	call	dispcom			; do common code
	mov	ax,temp2		; examine second key value

dispcom:or	ax,ax			; check range
	jle	dispc3			; le = not legal, ignore
	cmp	al,7			; 7-8 bit value?
	jge	dispc2			; ge = yes
	and	flags.remflg,not(dquiet+dregular+dserial)
	or	flags.remflg,al		; set display mode
	clc				; success
	ret				; check next key value
dispc2:	cmp	al,8			; set 8-bit wide display?
	ja	dispc3			; a = bad value
	and	flags.remflg,not d8bit	; assume want 7 bit mode
	cmp	al,7			; really want 7 bit mode?
	je	dispc3			; e = yes
	or	flags.remflg,d8bit	; set 8 bit flag
dispc3:	clc				; success
	ret				; end of display common code
disply	endp


; Set Dump filename  for saving screen images on disk.
; Puts filename in global string dmpname
setdmp	proc	near
	mov	bx,offset rdbuf		; work area
	mov 	dx,offset dmphlp	; help message
	mov	ah,cmword		; allow paths
	call	comnd
	jc	setdmp2			; c = failure
	mov	ah,cmeol
	call	comnd
	jc	setdmp2			; c = failure
	mov	dx,offset rdbuf		; assume we will use this text
	call	strlen			; filename given?
	mov	si,dx			; for strcpy
	or	cx,cx			; length of user's filename
	jg	setdmp1			; g = filename is given
	mov	si,offset dmpdefnam	; no name, use default instead
setdmp1:mov	di,offset dmpname	; copy to globally available loc
	call	strcpy
	clc
setdmp2:ret
setdmp	endp

; Set DUPLEX {FULL, HALF}
setdup	proc	near
	xor	bx,bx
	mov	dx,offset duptab
	call	keyend
	jc	setdup1			; c = failure
	mov	si,portval
	mov	[si].duplex,bl		; set value
	mov	[si].ecoflg,0		; turn off local echoing
	or	bl,bl			; full duplex?
	jz	setdup1			; z = yes
	mov	[si].floflg,0		; no flow control for half duplex
	mov	[si].ecoflg,1		; turn on local echoing
	call	serrst			; reset port so opening uses above
setdup1:ret
setdup	endp

; SET EOF

SETEOF	PROC	NEAR
	xor	bx,bx
	mov	dx,offset seoftab
	call	keyend
	jc	seteof1			; c = failure
	mov	flags.eofcz,bl		; set value
seteof1:ret
SETEOF	ENDP

; SET End-of-Packet char (for Sent packets)
; Archic, here for downward compatibility
EOLSET	PROC	NEAR
	mov	stflg,'S'		; set send/receive flag to Send
	jmp	sreol			; use Set Send/Rec routine do the work
EOLSET	ENDP

; SET ERRORLEVEL number
SETERL	PROC	NEAR
	mov	numhlp,offset erlhlp	; help
	mov	numerr,0		; error message
	mov	min,0			; smallest number
	mov	max,255			; largest magnitude
	call	num0			; parse numerical input
	jc	seterl1			; c = error
	mov	errlev,al		; store result
	clc
seterl1:ret
SETERL	ENDP

; SET ESCAPE character.
; Accept literal control codes and \### numbers. [jrd] 18 Oct 1987
ESCSET	PROC	NEAR
	mov	ah,cmword
	mov	bx,offset rdbuf		; work space
	mov	dx,offset eschlp	; help
	call	comnd
	jc	escse2			; c = failure
	or	ax,ax			; anything given?
	jnz	escse1			; nz = yes
	mov	dx,offset ermes6	; more parameters needed
	jmp	reterr
escse1:	push	ax			; save string length
	mov	ah,cmeol		; get a confirm
	call	comnd
	pop	ax
	jc	escse2			; c = failure
	mov	domath_ptr,offset rdbuf
	mov	domath_cnt,ax
	call	domath			; convert to number in ax
	cmp	ax,spc			; is it a control code?
	jae	escse3			; ae = no, complain
	or	ax,ax			; non-zero too?
	jz	escse3			; z = zero
	mov	trans.escchr,al		; save new escape char code
	clc
escse2:	ret
escse3:	mov	dx,offset escerr
	jmp	reterr
ESCSET	ENDP

; Set EXIT 
; SET WARNING {ON, OFF}
setexitwarn proc near
	mov	dx,offset exittab	; exit table
	xor	bx,bx
	mov	ah,cmkey
	call	comnd
	jc	setexit1
	or	bl,bl			; warning?
	jnz	setexit1		; nz = no
	mov	bx,offset exitwhlp	; warning help
	mov	dx,offset ontab
	call	keyend
	jc	setexit1		; c = failure
	mov	flags.exitwarn,bl	; set value
setexit1:ret
setexitwarn endp

; SET FILE {DISPLAY, WARNING, TYPE, CHARACTER-SET}
SETFILE	proc	near
	mov	dx,offset setfitab	; SET FILE table
	xor	bx,bx
	mov	ah,cmkey
	call	comnd
	jc	setfiy			; c = failure
	or	bl,bl			; Warning?
	jnz	setfi1			; nz = no
					; entry point for old SET WARNING
FILWAR:	mov	dx,offset warntab	; warning table, on, off, no-super
	xor	bx,bx
	call	keyend
	jc	setfiy			; c = failure
	mov	flags.flwflg,bl		; set the filewarning flag
setfiy:	ret

setfi1:	cmp	bl,1			; SET FILE CHARACTER-SET?
	jne	setfi2			; ne = no
	mov	dx,offset setchtab	; table of char sets
	xor	bx,bx
	call	keyend			; get the set id
	jc	setfiy			; c = error
	mov	flags.chrset,bx		; save the id
	cmp	bx,866			; setting CP866?
	jne	setfi1a			; ne = no
	cmp	dtrans.xchset,xfr_cyrillic ; using TRANSFER of Cryillic?
	je	setfi1a			; e = yes
	mov	dtrans.xchset,xfr_cyrillic ; force TRANSFER of Cyrillic
	mov	trans.xchset,xfr_cyrillic
	mov	ah,prstr
	mov	dx,offset setchmsg	; show warning
	int	dos
	clc
	ret
setfi1a:cmp	bx,932			; setting Shift-JIS?
	jne	setfi1b			; ne = no
	mov	dtrans.xchset,xfr_japanese ; force TRANSFER of Japanese-EUC
	mov	trans.xchset,xfr_japanese
	mov	ah,prstr
	mov	dx,offset setchmsg2	; show warning
	int	dos
	clc
	ret
setfi1b:cmp	bx,862			; setting CP862?
	jne	setfi1c			; ne = no
	mov	dtrans.xchset,xfr_hebiso ; force TRANSFER of Latin-Hebrew
	mov	trans.xchset,xfr_hebiso
	mov	ah,prstr
	mov	dx,offset setchmsg3	; show warning
	int	dos
setfi1c:clc
	ret

setfi2:	cmp	bl,2			; SET FILE TYPE?
	jne	setfi3			; ne = 3
	mov	dx,offset xftyptab	; table of types
	xor	bx,bx
	call	keyend
	jc	setfix			; c = error
	mov	dtrans.xtype,bl		; store transfer type
	mov	trans.xtype,bl		; store transfer type
	ret
setfi3:	cmp	bl,3			; SET FILE DISPLAY?
	jne	setfi4			; ne = no
	mov	dx,offset distab2	; table
	xor	bx,bx
	call	keyend
	jc	setfix			; c = failure
	and	flags.remflg,not(dquiet+dregular+dserial)
	or	flags.remflg,bl		; set display mode
	clc
setfix:	ret
setfi4:	cmp	bl,4			; SET FILE INCOMPLETE?
	jne	setfix			; ne = no
					; SET INCOMPLETE file disposition
ABFSET:	mov	dx,offset abftab
	xor	bx,bx
	call	keyend
	jc	abfset1			; c = failure
	mov	flags.abfflg,bl		; Set the aborted file flag
abfset1:ret
SETFILE	endp

; SET FLOW-CONTROL {NONE, XONXOFF, RTS/CTS}

FLOSET	PROC	NEAR
	mov	dx,offset flotab
  	xor	bx,bx
	call	keyend
	jc	floset3			; c = failure
	mov	si,portval
	mov	ax,floxon		; xon/xoff pair
	or	bx,bx			; any flow control?
	jz	floset1			; z = none
	test	bx,1+2			; using xon/xoff?
	jnz	floset2			; nz = xon/xoff
	cmp	flags.comflg,'F'
	je	floset1
	cmp	flags.comflg,4		; UART? (RTS/CTS case)
	ja	floset4			; a = no, error
floset1:xor	ax,ax			; clear chars for RTS/CTS and none
floset2:mov	[si].flowc,ax		; flow control values
	mov	[si].floflg,bl		; flow control kind
	clc
floset3:ret
floset4:mov	dx,offset ermes7	; error message
	jmp	reterr
FLOSET	ENDP

; SET FOSSIL CLOSE-ON-DONE
FOSSET	proc	near
	mov	dx,offset fossiltab
	xor	bx,bx
	mov	ah,cmkey
	call	comnd
	jc	fossetx			; c = failure
	mov	dx,offset ontab		; get on/off state
	mov	bx,offset fossilhlp
	mov	ah,cmkey
	call	comnd
	jnc	fosset1
	ret				; c = failure

fosset1:push	bx
	mov	ah,cmeol
	call	comnd
	pop	bx
	jc	fossetx			; failure
	mov	fossilflag,bl		; set flag
	clc
fossetx:ret
FOSSET	endp

; SET HANDSHAKE
; Add ability to accept general decimal code.
HNDSET	PROC	NEAR
	mov	dx,offset hndtab	; table to scan
	mov	bx,offset hnd1hlp	; help message
	mov	ah,cmkey
	call	comnd
	jc	hnd2			; c = failure
	cmp	bl,0ffh			; want a general char code?
	jne	hnd1			; ne = no
	mov	min,0			; get decimal char code
	mov	max,255			; range is 0 to 255 decimal
	mov	numhlp,offset erlhlp	; help msg
	mov	numerr,0		; error message
	call	num0			; convert number, return it in ax
	jc	hnd2			; c = error
	mov	bx,ax			; recover numerical code
hnd1:	push	bx			; handshake type
	mov	ah,cmeol
	call	comnd			; get a confirm
	pop	bx			; recover bx
	jc	hnd2			; c = failure
	mov	si,portval
	or	bl,bl			; setting handshake off?
	jz	hnd0			; z = yes
	mov	[si].hndflg,1		; turn on handshaking
	mov	[si].hands,bl		; use this char as the handshake
	clc				; success
	ret
hnd0:	mov	[si].hndflg,bl		; no handshaking
	clc				; success
hnd2:	ret
HNDSET	ENDP

;
; Set Input commands (default-timeout, timeout-action, case, echo)
; By Jim Strudevant [jrs]
INPSET	PROC	NEAR
	mov	ah,cmkey		; key word
	mov	dx,offset inptab	; from inputtable
	xor	bx,bx			; no hints
	call	comnd			; get the word
	jc	inpset1			; c = failure
	jmp	bx			; do the sub command
inpset1:ret
;
; Set Input Default-timeout in seconds
;
inptmo:	mov	numhlp,offset intoms	; help
	mov	numerr,0		; error message
	mov	min,0			; smallest number
	mov	max,-1			; largest magnitude
	call	num0			; parse numerical input
	jc	inptmo1			; c = error
	mov	script.indfto,ax	; store result
inptmo1:ret
;
; Set Input Timeout action (proceed or quit)
;
inpact:	mov	dx,offset inactb	; from this list
	xor	bx,bx			; no hints
	call	keyend			; get it
	jc	inpact1			; c = failure
	mov	script.inactv,bl	; save the action
inpact1:ret
;
; Set Input Echo on or off
;
inpeco:	mov	dx,offset ontab		; from this list
	xor	bx,bx			; no hints
	call	keyend			; get it
	jc	inpeco1			; c = failure
	mov	script.inecho,bl	; save the action
inpeco1:ret
;
; Set Input Case observe or ignore
;
inpcas:	mov	dx,offset incstb	; from this list
	xor	bx,bx			; no hints
	call	keyend			; get it
	jc	inpcas1			; c = failure
	mov	script.incasv,bl	; save the action
inpcas1:ret

infilt:	mov	dx,offset ontab		; filter input, table
	xor	bx,bx
	call	keyend
	jc	infilt1
	mov	script.infilter,bl
infilt1:ret
INPSET	ENDP

; Set length of script buffer for INPUT/REINPUT at Kermit initialization
; time via Environment. Called by command parser while doing Environment
; reading in mssker.asm. Do not call after Kermit has initialized.
SETINPBUF proc	near
	mov	scpbuflen,128		; store default buffer length
	mov	numhlp,0		; no help
	mov	numerr,0		; no error message
	mov	min,2			; smallest number (must be non-zero)
	mov	max,65535		; largest magnitude (16 bits worth)
	call	num0			; parse numerical input
	jc	setinpbx		; c = error
	mov	scpbuflen,ax		; store result
	clc
setinpbx:ret
SETINPBUF endp

; SET KEY
; Jumps to new Set Key routine
setkey	proc	near		
	cmp	stkadr,0	; keyboard translator present?
	je	setk4		; e = no, use this routine
	mov	bx,stkadr	; yes, get offset of procedure
	jmp	bx		; jump to keyboard translator
setk4:	mov	dx,offset ermes5
	jmp	reterr		; else print error message
setkey	endp

; SET LOCAL-ECHO {ON | OFF}
 
LCAL	PROC	NEAR
	mov	dx,offset ontab
	xor	bx,bx
	call	keyend
	jc	lcal1			; c = failure
	mov	si,portval
	mov	[si].ecoflg,bl		; Set the local echo flag
lcal1:	ret
LCAL	ENDP

; LOG  {PACKETS | SESSION | TRANSACTION} filename

setcpt	proc	near
	mov	dx,offset logtab	; kinds of logging
	mov	bx,offset loghlp	; help on kind of logging
	mov	ah,cmkey		; parse keyword
	call	comnd
	jnc	setcp20			; nc = success
	ret				; failure
setcp20:mov	numhlp,bx		; save the parsed value
	mov	bx,offset rdbuf		; holds the complete filename
	mov 	dx,offset filhlp	; ask for filename
	mov	ah,cmword		; allow paths
	call	comnd
	jnc	setcp21			; nc = success
	ret				; failure
setcp21:mov	bx,offset rdbuf+100	; optional APPEND or NEW keyword
	mov 	dx,offset loghlp2	; help with trailer keywords
	mov	ah,cmword		; allow paths
	call	comnd
	jnc	setcp21a		; nc = success
	ret				; failure
setcp21a:mov	ah,cmeol
	call	comnd			; get a confirm
	jnc	setcp22			; nc = success
	ret				; failure
setcp22:mov	bx,numhlp		; recover kind of logging
	mov	dx,offset rdbuf		; length of filename to cx
	call	strlen			; length of given filename
	test	bl,logpkt		; packet logging?
	jz	setcp2			; z = no, try others
	mov	dx,offset lpktnam	; filename
	jcxz	setcp1			; z = no filename given
	mov	si,offset rdbuf		; get new name
	mov	di,dx			; destination
	call	strcpy			; replace old name
setcp1:	cmp	ploghnd,-1		; packet log file already open?
	je	setcp6			; e = no, open it
	jmp	setcp16			; say file is open already

setcp2:	test	bl,logses		; session logging?
	jz	setcp4			; z = no, try others
	mov	dx,offset lsesnam	; use default name
	jcxz	setcp3			; z = no filename given
	mov	si,offset rdbuf		; get new name
	mov	di,dx			; destination
	call	strcpy			; replace old name
setcp3:	cmp	sloghnd,-1		; transaction file already open?
	je	setcp6			; e = no, open it
	jmp	setcp16			; say file is open already

setcp4:	test	bl,logtrn		; transaction logging?
	jz	setcp14			; z = no, error
	mov	dx,offset ltranam	; use default name
	jcxz	setcp5			; z = no filename given
	mov	si,offset rdbuf		; get new name
	mov	di,dx			; destination
	call	strcpy			; replace old name
setcp5:	cmp	tloghnd,-1		; transaction file already open?
	je	setcp6			; e = no, open it
	jmp	setcp16			; say file is open already

setcp6:	mov	ax,dx			; place for filename for isfile
	call	isfile			; does file exist already?
	jc	setcp7			; c = does not exist so use create
	test	byte ptr filtst.dta+21,1fh ; file attributes, ok to write?
	jnz	setcp14			; nz = no, use error exit	
	mov	ah,open2		; open existing file
	mov	al,1+1+20h		;  for writing and reading, deny write
	int	dos
	jc	setcp14			; if carry then error
	mov	bx,ax			; file handle for seeking
	xor	cx,cx			; high order displacement
	xor	dx,dx			; low order part of displacement
	mov	ah,lseek		; seek to EOF (to do appending)
	mov	al,2			; says to EOF
	int	dos
	mov	di,word ptr rdbuf+100	; trailing arg, get two letters
	and	di,not 2020h		; to upper case
	cmp	di,'EN'			; NEW?
	jne	setcp8			; ne = no
	mov	dx,offset rdbuf		; filename
	mov	ah,del2			; delete to create new file below
	int	dos

setcp7:	test	filtst.fstat,80h	; access problem?
	jnz	setcp14			; nz = yes, stop here
	mov	ah,creat2		; function is create
	mov	cx,20H			; turn on archive bit
	int	dos			; create the file, DOS 2.0
	jc	setcp14			; if carry bit set then error
	mov	bx,ax			; file handle

setcp8:	cmp	numhlp,logpkt		; packet logging?
	jne	setcp9			; ne = no
	mov	ploghnd,bx		; save transaction log handle here
	jmp	short setcp12
setcp9:	cmp	numhlp,logses		; session logging?
	jne	setcp10			; ne = no
	mov	sloghnd,bx		; save session log handle here
	jmp	short setcp12
setcp10:mov	tloghnd,bx		; save transaction log handle here

setcp12:mov	ax,numhlp		; kind of Logging
	or	flags.capflg,al		; accumulate kinds of logging
	clc				; success
	ret

setcp14:mov	dx,offset errcap	; give error message
	jmp	reterr			; and display it

setcp16:mov	ah,prstr		; file already open
	mov	dx,offset erropn
	int	dos
	clc				; return success
	ret
setcpt	endp
 
; SET MODE LINE

MODL	PROC	NEAR
	mov	dx,offset ontab		; parse an on or off
	xor	bx,bx			; no special help
	call	keyend
	jc	modl1			; c = failure
	mov	flags.modflg,bl		; set flag appropriately
modl1:	ret
MODL	ENDP

; SET OUTPUT commands
setoutput proc	near
	mov	dx,offset outputtab	; OUTPUT command table
	xor	bx,bx			; no special help
	mov	ah,cmkey
	call	comnd
	jc	setout1			; c = failure
	jmp	short setopace
setout1:ret	
setoutput endp

; Set OUTPUT Pacing <number millisec between chars>
setopace proc	near
	mov	numhlp,offset opacehlp	; help
	mov	numerr,0		; no error message
	mov	min,0			; smallest number
	mov	max,65535		; largest magnitude (16 bits worth)
	call	num0			; parse numerical input
	jc	setopac1		; c = error
	mov	outpace,ax		; store result
	clc
setopac1:ret
setopace endp

; Set Macro Error
setmacerr proc	near
	mov	dx,offset macrotab	; keyword
	xor	bx,bx
	mov	ah,cmkey
	call	comnd
	jnc	setmacer1
	ret				; failure
setmacer1:
	push	bx			; save first keyword ident
	mov	dx,offset ontab		; on/off table
	xor	bx,bx
	call	keyend
	pop	ax			; first keyword ident
	jnc	setmacer2		; nc = success
	ret
setmacer2:or	al,al			; "error" (0)?
	jz	setmacer3		; z = yes
	mov	macroerror,bl		; set error action flag
setmacer3:clc
	ret
setmacerr endp

; SET MODEM text    creates macro named _MODEM
setmodem proc	near
	mov	word ptr rdbuf+2,'m_'	; macro name "_modem"
	mov	word ptr rdbuf+4,'do'
	mov	word ptr rdbuf+6,'me'
	mov	rdbuf+8,' '		; separator
	mov	bx,offset rdbuf+9
	mov	ax,length rdbuf-9	; usable length of rdbuf
	add	ax,offset rdbuf		; ax = amount of buffer used
	mov	comand.cmblen,ax	; our new buffer length
	mov	comand.cmdonum,1	; \number conversion allowed
	mov	ah,cmline		; get a line of text
	mov	dx,offset askhlp3	; help, bx is buffer offset
	push	bx			; save starting offset
	call	comnd			; get macro definition text
	pop	bx
	jnc	setmod1			; nc = success
	ret				; failure
setmod1:mov	cx,bx
	sub	cx,offset rdbuf+2	; length of command line
	jmp	dodecom
setmodem endp

; SET PARITY
 
SETPAR	PROC	NEAR
	mov	dx,offset partab	; parity table
	xor	bx,bx
	mov	ah,cmkey
	call	comnd
	jnc	setp1			; nc = success
	ret
setp1:	mov	si,portval		; port structure
	mov	bh,[si].parflg		; current parity setting
	or	bh,bl			; merge hardware parity bits
	mov	byte ptr temp,bh	; save results around calls
	test	bl,PARHARDWARE		; using hardware parity?
	jz	setpt3			; z = no
	mov	dx,offset parhwtab	; hardware parity table
	xor	bx,bx
	mov	ah,cmkey
	call	comnd
	jnc	setpt2
	ret
setpt2:	cmp	flags.comflg,'4'	; physical serial port?
	jbe	setpt3			; be = yes
	mov	dx,offset ermes8	; say can't use Hardware on non-UART
	jmp	reterr

setpt3:	mov	ah,cmeol
	push	bx
	call	comnd
	pop	bx
	jnc	setpt4
	ret
setpt4:	mov	si,portval		; port structure
	mov	[si].parflg,bl		; store the parity flag
	test	byte ptr temp,PARHARDWARE ; used hardware before or now?
	jz	setpt5			; z = no
	call	serrst			; reset port for hardware reinit
setpt5:	clc
	ret
SETPAR	ENDP

; Set Print filename  for writing material to printers.
; Puts filename in global string prnname
setprn	proc	near
	mov	bx,offset rdbuf		; work area
	mov 	dx,offset prnhlp	; help message
	mov	ah,cmword		; allow paths
	call	comnd
	jc	setprn3			; c = failure
	mov	ah,cmeol
	call	comnd
	jc	setprn3			; c = failure
	mov	dx,offset rdbuf		; assume we will use this text
	call	strlen			; filename given?
	mov	si,dx			; for strcpy
	or	cx,cx			; length of user's filename
	jg	setprn1			; g = filename is given
	mov	si,offset prndefnam	; no name, use default instead
setprn1:mov	di,offset prnname	; copy to globally available loc
	call	strcpy
	cmp	prnhand,0		; handle already in use?
	jle	setprn2			; le = no
	call	pntflsh			; flush current buffer
	mov	bx,prnhand		; close the file now
	cmp	bx,4			; don't close DOS PRN
	je	setprn2			; e = already available
	mov	ah,close2
	int	dos
setprn2:call	prnopen			; open printer now, may set carry
	jnc	setprn3			; nc = success
	mov	ah,prstr
	push	ds
	mov	dx,seg prnerr
	mov	ds,dx
	mov	dx,offset prnerr	; say can't open the file
	int	dos
	pop	ds
	mov	si,offset prndefnam	; use default name as fallback
	mov	di,offset prnname	; copy to globally available loc
	call	strcpy
	mov	prnhand,4		; declare handle to be DOS PRN
setprn3:ret
setprn	endp

; SET PROMPT  Allow user to change the "Kermit-MS>" prompt
; {string} and \fchar(number) notation permitted to represent special chars.
; String will be made asciiz

PROMSET	PROC	NEAR
	mov	ah,cmline
	mov	bx,offset rdbuf		; read the prompt string
	mov	dx,offset prmmsg
	mov	comand.cmblen,length promptbuf -1 ; buffer length
	mov	comand.cmper,1		; do not allow variable substitutions
	call	comnd
	jc	prom2			; c = failure
	or	ax,ax			; prompt string?
	jnz	prom0			; nz = yes
	mov	ax,offset kerm		; no, restore default prompt
	jmp	short prom1
prom0:	mov	si,offset rdbuf		; source = new prompt string
	mov	di,offset promptbuf	; destination
	call	strcpy			; copy string to final buffer
	mov	bx,ax			; get byte count
	mov	promptbuf[bx],0		; insert null terminator
	mov	ax,offset promptbuf
prom1:	mov	prmptr,ax		; remember prompt buffer (old/new)
	clc				; success
prom2:	ret
PROMSET	ENDP

; SET SERVER {LOGIN username password | TIMEOUT}

SETSRV	PROC	NEAR
	mov	dx,offset srvtab	; set server table
	xor	bx,bx			; use table for help
	mov	ah,cmkey		; get keyword
	call	comnd
	jnc	setsrv1			; c = success
	ret
setsrv1:cmp	apctrap,0		; disable from APC?
	jne	setsrvx			; ne = yes
	cmp	bl,1			; Login?
	jne	setsrv2			; ne = no
	test	flags.remflg,dserver	; acting as a server now?
	jz	setsrv3			; z = no
	stc				; fail
	ret
setsrv3:mov	bx,offset rdbuf		; where to store local username
	mov	dx,offset luserh	; help
	mov	comand.cmblen,16	; buffer length
	mov	ah,cmword		; get username
	call	comnd
	jc	setsrvx
	mov	bx,offset rdbuf+30	; where to store local password
	mov	dx,offset lpassh	; help
	mov	comand.cmblen,16	; buffer length
	mov	comand.cmdonum,1	; \number conversion allowed
	mov	ah,cmline		; get password, allow spaces
	call	comnd
	jc	setsrvx
	mov	si,offset rdbuf		; only now do we transfer to the
	mov	di,offset luser		; active buffers
	call	strcpy
	mov	si,offset rdbuf+30
	mov	di,offset lpass
	call	strcpy
	clc
	ret

setsrv2:mov	min,0			; Timeout, smallest acceptable value
	mov	max,255			; largest acceptable value, one byte
	mov	numhlp,offset srvthlp	; help message
	mov	numerr,0		; complaint message
	call	num0			; parse numerical input
	jc	setsrvx			; c = error
	mov	srvtmo,al		; store timeout value
	clc				; success
setsrvx:ret
	
SETSRV	ENDP

; Set REPEAT COUNTS {ON, OFF}
repset	proc	near
	mov	dx,offset setrep	; repeat table
	xor	bx,bx
	mov	ah,cmkey
	call	comnd
	jnc	repset1
	ret
repset1:or	bx,bx			; which item (counts, prefix)
	jnz	repset4			; nz = prefix
	mov	dx,offset ontab		; on/off table
	xor	bx,bx			; use table for help
	call	keyend
	jnc	repset2			; nc = success
	ret
repset2:mov	dtrans.rptqenable,bl	; repeat quote char enable/disable
	ret
repset4:mov	ah,cmword		; get a character
	mov	bx,offset rdbuf
	mov	rdbuf,defrptq		; default repeat prefix char
	mov	dx,offset prefhlp
	call	comnd
	jc	repset5			; c = fail
	push	ax
	mov	ah,cmeol
	call	comnd
	pop	ax
	jc	repset5			; c = fail
	mov	domath_ptr,offset rdbuf
	mov	domath_cnt,ax
	mov	domath_msg,1		; no complaints
	call	domath			; convert numerics
	jc	repset6
	mov	rdbuf,al
repset6:mov	al,rdbuf		; get char
	call	prechk			; check range
	jc	repset5			; c = failed
	mov	dtrans.rptq,al		; set prefix
repset5:ret
repset	endp

; Check if prefix in AL is in the proper range: 33-62, 96-126. 
; Return carry clear if in range, else return carry set.
prechk	proc	near
	cmp	al,33
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
prechk	endp
; SET RETRY value. Changes the packet retry limit.

RETRYSET PROC	NEAR
	mov	min,1			; smallest acceptable value
	mov	max,63			; largest acceptable value
	mov	numhlp,offset retryhlp	; help message
	mov	numerr,0		; complaint message
	call	num0			; parse numerical input
	jc	retrys1			; c = error
	mov	maxtry,al
retrys1:ret
RETRYSET ENDP

; Set number of screens in terminal emulator rollback buffer at Kermit
; initialization time via Environment. Called by command parser while doing
; Environment reading in mssker.asm. Do not call after Kermit has initialized.
SETROLLB proc	near
	mov	numhlp,offset rollhlp	; help
	mov	numerr,0		; no error message
	mov	min,0			; smallest number
	mov	max,8000		; largest magnitude
	call	num0			; parse numerical input
	jc	setrol1			; c = error
	mov	npages,ax		; store result
	clc
setrol1:ret
SETROLLB endp

; Set width of rollback screens in terminal emulator rollback buffer at Kermit
; initialization time via Environment. Called by command parser while doing
; Environment reading in mssker.asm. Do not call after Kermit has initialized.
SETWIDTH proc	near
	mov	rollwidth,80		; default width of rolled screen
	mov	numhlp,0		; no help
	mov	numerr,0		; no error message
	mov	min,80			; smallest number
	mov	max,207			; largest magnitude (16 bits worth)
	call	num0			; parse numerical input
	jc	setwid1			; c = error
	mov	rollwidth,ax		; store result
	clc
setwid1:ret
SETWIDTH endp

; SET TAKE ECHO or TAKE ERROR on or off

TAKSET	PROC	NEAR
	mov	dx,offset taketab	; Parse a keyword
	xor	bx,bx			; no specific help
	mov	ah,cmkey
	call	comnd
	jnc	takset1
	ret				; failure
takset1:push	bx			; save command indicator
	mov	dx,offset ontab
	xor	bx,bx
	call	keyend
	pop	ax			; recover command indicator
	jnc	takset2
	ret				; failure
takset2:or	al,al			; Take Echo command?
	jnz	takset3			; nz = no
	mov	flags.takflg,bl
	clc
	ret
takset3:cmp	al,2			; Take debug command?
	jne	takset4			; ne = no
	mov	flags.takdeb,bl		; on/off table
	clc
	ret
takset4:mov	takeerror,bl		; Take Error command
	clc
	ret
TAKSET	ENDP

; SET TIMER     on or off during file transfer

TIMSET	PROC	NEAR
	mov	dx,offset ontab
	xor	bx,bx
	call	keyend
	jc	timset1			; c = failure
	mov	flags.timflg,bl
timset1:ret
TIMSET	ENDP

; SET WINDOW number of windows
WINSET	PROC	NEAR
	mov	min,1			; smallest acceptable value
	mov	max,maxwind		; largest acceptable value
	mov	numhlp,offset winhelp	; help message
	mov	numerr,0		; complaint message
	call	num0			; parse numerical input
	jc	winse5			; c = error
	mov	dtrans.windo,al		; store default window size
	mov	trans.windo,al		; and in active variable for makebuf
	clc				; success
winse5:	ret
WINSET	ENDP

; SET SEND parameters

SENDSET	PROC	NEAR
	mov	stflg,'S'		; Setting SEND parameter 
	mov	dx,offset stsrtb	; Parse a keyword
	xor	bx,bx			; no specific help
	mov	ah,cmkey
	call	comnd
	jc	sendset1		; c = failure
	jmp	bx			; do the action routine
sendset1:ret
SENDSET	ENDP

; SET RECEIVE parameters

recset:	mov	stflg,'R'		; Setting RECEIVE paramter
	mov	dx,offset stsrtb	; Parse a keyword
	xor	bx,bx			; no specific help
	mov	ah,cmkey
	call	comnd
	jc	recset1			; c = failure
	jmp	bx			; do the action routine
recset1:ret

remset	proc	near			; Set REMOTE ON/OFF
	mov	dx,offset ontab
	mov	bx,offset remhlp
	call	keyend
	jc	remset2			; c = failure
	and	flags.remflg,not (dquiet+dserial+dregular) ; no display bits
	or	bl,bl			; want off state? (same as regular)
	jz	remset1			; z = yes
	or	flags.remflg,dquiet	; else on = quiet display
	clc
	ret
remset1:or	flags.remflg,dregular	; off = regular display
	clc
remset2:ret
remset	endp


; SET Send and Receive End-of-Packet char

sreol	PROC	NEAR
	mov	min,0			; lowest acceptable value
	mov	max,1FH			; largest acceptable value
	mov	numhlp,offset eophlp	; help message
	mov	numerr,0		; error message address
	call	num0			; get numerical input
	jc	sreol3			; c = error
	cmp	stflg,'S'		; setting SEND paramter?
	je	sreol1			; e = yes
	mov	trans.reol,al
	mov	dtrans.reol,al
	jmp	short sreol2
sreol1:	mov	dtrans.seol,al
sreol2:	mov	ah,dtrans.seol
	mov	trans.seol,ah
	clc
sreol3:	ret
sreol	ENDP


; SET SEND and RECEIVE start-of-header

srsoh:	mov	min,0
	mov	max,7eh			; allow printables (control=normal)
	mov	numhlp,offset sohhlp	; reuse help message
	mov	numerr,0		; error message
	call	num0		; Common routine for parsing numerical input
	jc	srsoh2			; c = error
	cmp	stflg,'S'		; setting SEND paramter?
	je	srsoh1
	mov	trans.rsoh,al		; set Receive soh
	clc				; success
	ret
srsoh1:	mov	trans.ssoh,al		; set Send soh
	clc				; success
	ret
srsoh2:	ret

; SET Send Double-char

srdbl	PROC	NEAR
	mov	min,0			; lowest acceptable value
	mov	max,0ffh		; largest acceptable value
	mov	numhlp,offset dblhlp	; help
	mov	numerr,0		; error message address
	call	num0			; get numerical input
	jc	sreol3			; c = error
	cmp	stflg,'R'		; setting Receive paramter?
	je	srdbl1			; e = yes, no action
	mov	trans.sdbl,al		; store character to be doubled
	mov	dtrans.sdbl,al
	clc
srdbl1:	ret
srdbl	ENDP

; SET SEND and	RECEIVE TIMEOUT

srtim:	mov	min,0
	mov	max,94
	mov	numhlp,offset timhlp	; Reuse help message
	mov	numerr,0		; error message
	call	num0		; Common routine for parsing numerical input
	jc	srtim3			; c = error
	cmp	stflg,'S'		; Setting SEND paramter?
	je	srtim1
	mov	trans.rtime,al
	jmp	short srtim2
srtim1:	mov	dtrans.stime,al
srtim2:	mov	ah,dtrans.stime
	mov	trans.stime,ah
	clc
srtim3:	ret

; SET SEND and RECEIVE PACKET LENGTH
; dtrans items are real, trans items are just for SHOW information

srpack:	mov	min,20
	mov	max,9024
	mov	numhlp,offset pakhlp	; help
	mov	numerr,offset pakerr	; error message
	call	num0
	jnc	srpaks0			; nc = success
	ret				; failure
srpaks0:cmp	stflg,'S'		; setting send value?
	jne	srpakr			; ne = receive
	mov	dtrans.slong,ax		; set send max value
	mov	trans.slong,ax		; store current active length
	mov	dtrans.spsiz,dspsiz	; set regular 94 byte default
	mov	trans.spsiz,dspsiz	; ditto
	cmp	ax,dspsiz		; longer than regular packet?
	jae	srpaks1			; ae = yes
	mov	dtrans.spsiz,al		; shrink regular packet size too
	mov	trans.spsiz,al		; shrink regular packet size too
srpaks1:clc				; success
	ret

srpakr:	mov	dtrans.rlong,ax		; set receive max value
	mov	trans.rlong,ax		; store active length
	mov	dtrans.rpsiz,drpsiz	; set regular to default 94 bytes
	mov	trans.rpsiz,drpsiz
	mov	trans.rpsiz,drpsiz
	cmp	ax,drpsiz		; longer than a regular packet?
	jae	srpakr1			; ae = yes
	mov	dtrans.rpsiz,al		; shrink regular packet size too
	mov	trans.rpsiz,al
srpakr1:clc				; success
	ret


; SET SEND and RECEIVE number of padding characters

srnpd:	mov	min,0
	mov	max,94
	mov	numhlp,offset timhlp	; reuse help message
	mov	numerr,0		; error message
	call	num0			; Parse numerical input
	jc	srnpd3			; c = error
	cmp	stflg,'S'		; Setting SEND paramter?
	je	srnpd1			; e = yes
	mov	trans.rpad,al		; set Receive padding
	jmp	short srnpd2
srnpd1:	mov	dtrans.spad,al		; set default Send padding
srnpd2:	mov	al,dtrans.spad
	mov	trans.spad,al    	; update active array for I and S pkts
	clc
srnpd3:	ret

; SET SEND and RECEIVE padding character

srpad:	mov	min,0
	mov	max,127
	mov	numhlp,offset padhlp
	mov	numerr,offset padhlp
	call	num0			; parse numerical input
	jc	srpad4			; c = error
	cmp	ah,127			; this is allowed
	je	srpad1
	cmp	ah,32
	jb	srpad1			; between 0 and 31 is OK too
	mov	ah,prstr
	mov	dx,offset padhlp
	int	dos
srpad1:	cmp	stflg,'S'		; Send?
	je	srpad2			; e = yes, else Receive
	mov	trans.rpadch,al		; store receive pad char
	jmp	short srpad3
srpad2:	mov	dtrans.spadch,al	; store Send pad char
srpad3:	mov	ah,dtrans.spadch
	mov	trans.spadch,ah  	; update active array for I and S pkts
	clc				; success
srpad4:	ret

; SET SEND and	RECEIVE control character prefix

srquo:	mov	min,33
	mov	max,126
	mov	numhlp,offset quohlp	; help message
	mov	numerr,0		; error message
	call	num0			; Parse numerical input
	jc	srquo3			; c = error
	cmp	stflg,'S'		; Setting outgoing quote char?
	je	srquo1			; e = yes
	mov	trans.rquote,al		; set Receive quote char
	jmp	short srquo2
srquo1:	mov	dtrans.squote,al	; set Send quote char
srquo2:	clc
srquo3:	ret

; SET SEND Pause number	of milliseconds

srpaus:	mov	min,0
	mov	max,65383
	mov	numhlp,offset pauhlp	; help
	mov	numerr,0
	call	num0			; Parse numerical input
	pushf				; save carry for error state
	cmp	stflg,'S'		; Setting SEND paramter?
	je	srpau0
	popf
	mov	dx,offset ermes5	; "Not implemented" msg
	jmp	reterr			; print error message
srpau0:	popf
	jc	srpau1			; c = error
	mov	spause,ax		; store value
srpau1:	ret

; SET SEND/RECEIVE PATHNAMES {off, relative, absolute}
srpath	proc	near
	mov	dx,offset pathtab
	mov	bx,offset rspathhlp
	call	keyend
	jc	srpath1
	cmp	stflg,'R'		; Setting RECEIVE paramter?
	jne	srpath1			; ne = no
	mov	rcvpathflg,bl		; update receive flag
	clc
	ret
srpath1:mov	sndpathflg,bl		; update send flag
	clc
srpath2:ret
srpath	endp

; Set stop-bits
stopbit	proc	near
	mov	min,1
	mov	max,2
	mov	numhlp,offset stophlp	; help
	mov	numerr,0
	call	num0			; Parse numerical input
	jnc	stopbit1
	ret				; c = failure
stopbit1:mov	bx,portval
	mov	[bx].stopbits,al	; stop bits
	clc
	ret	
stopbit	endp

; SET Streaming {on, off}
strmmode proc	near
	mov	dx,offset ontab
	xor	bx,bx
	call	keyend
	jnc	strmmod1
	ret
strmmod1:mov	streaming,bl		; update streaming flag
	ret
strmmode endp

; SET TCP/IP address nnn.nnn.nnn.nnn
; SET TCP/IP subnetmask nnn.nnn.nnn.nnn
; SET TCP/IP gateway nnn.nnn.nnn.nnn
; SET TCP/IP primary-nameserver nnn.nnn.nnn.nnn
; SET TCP/IP secondary-nameserver nnn.nnn.nnn.nnn
; SET TCP/IP domain string

ifndef	no_tcp
tcpipset proc	near
	mov	ah,cmkey		; get keyword
	mov	dx,offset tcptable	; table
	xor	bx,bx			; help
	call	comnd
	jnc	tcpse1
	ret
tcpse1:	mov	word ptr rdbuf,bx	; keyword index
	mov	comand.cmblen,17	; length of user's buffer
	cmp	bx,1			; local address?
	jne	tcpse1a			; ne = no
	mov	dx,offset addrhelp	; address help
	jmp	short tcpse4
tcpse1a:cmp	bx,2			; domain name?
	jne	tcpse2			; ne = no
	mov	dx,offset domainhlp	; domain help
	mov	comand.cmblen,32	; length of user's buffer
	jmp	short tcpse4
tcpse2:	cmp	bx,3			; subnet mask?
	jne	tcpse3			; ne = no
	mov	dx,offset subnethlp
	jmp	short tcpse4
tcpse3:	cmp	bx,7			; Host?
	jne	tcpse3a			; ne = no
	mov	dx,offset hosthlp
	mov	comand.cmblen,60	; length of user's buffer
	jmp	short tcpse4
tcpse3a:cmp	bx,9			; PD interrupt?
	jne	tcpse3b			; ne = no
	mov	dx,offset tcppdinthlp
	jmp	short tcpse4
tcpse3b:cmp	bx,10			; term type?
	jne	tcpse3c			; ne = no
	mov	dx,offset tcpttyhlp
	mov	comand.cmblen,32	; length of user's buffer
	jmp	short tcpse4
tcpse3c:cmp	bx,11			; newline mode?
	jne	tcpse3d			; ne = no
	jmp	tcpse13
tcpse3d:cmp	bx,12			; debug mode?
	jne	tcpse3e			; ne = no
	jmp	tcpse14
tcpse3e:cmp	bx,13			; binary/nvt mode?
	jne	tcpse3f			; ne = no
	jmp	tcpse15
tcpse3f:cmp	bx,14			; MSS?
	jne	tcpse3g			; ne = no
	jmp	tcpse16

tcpse3g:mov	dx,offset iphelp	; Internet number help
tcpse4:	mov	ah,cmword		; get a string
	mov	bx,offset rdbuf+2	; work buffer
	call	comnd
	jnc	tcpse5
	ret
tcpse5:	push	ax			; save string length in ax
	mov	ah,cmeol
	call	comnd
	pop	ax
	jnc	tcpse6
	ret
tcpse6:	mov	si,offset rdbuf+2	; user's string
	mov	bx,word ptr rdbuf	; comand kind
	cmp	bx,2			; domain?
	jne	tcpse8			; ne = no
	mov	di,offset tcpdomain
	cmp	ax,32			; exceeded 32 chars?
	jbe	tcpse7			; be = no
	mov	ah,prstr
	mov	dx,offset domainbad	; compain
	int	dos
	stc
	ret
tcpse7:	cmp	ax,32			; address oversized?
	jbe	tcpse9			; be = no
	mov	ah,prstr
	mov	dx,offset addressbad	; say bad address
	int	dos
	stc
	ret
tcpse8:	mov	di,offset tcpaddress
	cmp	bx,1			; local address?
	je	tcpse9			; e = yes
	mov	di,offset tcpsubnet
	cmp	bx,3			; subnet?
	je	tcpse9			; e = yes
	mov	di,offset tcpgateway
	cmp	bx,4			; gateway?
	je	tcpse9
	mov	di,offset tcpprimens
	cmp	bx,5			; primary-nameserver?
	je	tcpse9
	mov	di,offset tcpsecondns	; secondary-nameserer
	cmp	bx,6
	je	tcpse9
	mov	di,offset tcphost	; host name or number
	cmp	bx,7
	je	tcpse9
	mov	di,offset tcpbcast	; broadcast
tcpse9:	cmp	bx,9			; port or other?
	jae	tcpse10			; ae = yes
	call	strcpy
	clc
	ret
tcpse10:cmp	bx,9			; PD interrupt?
	jne	tcpse12			; ne = no
	mov	si,offset rdbuf+2
tcpse11:mov	ax,word ptr [si]
	and	ax,not 2020h		; to upper case
	cmp	ax,'DO'			; ODI?
	je	tcpse11a		; e = yes, use "DO"
	push	bx
	mov	domath_ptr,si
	mov	domath_cnt,16
	call	domath			; convert to number in ax
	pop	bx
tcpse11a:mov	tcppdint,ax
	clc
	ret
tcpse12:cmp	bx,10			; term-type string?
	jne	tcpse13			; ne = no
	mov	si,offset rdbuf+2
	mov	di,offset tcpttbuf	; copy string to holding place
	call	strcpy
	clc
	ret
tcpse13:cmp	bx,11			; newline mode?
	jne	tcpse14			; ne = no
	mov	dx,offset newlinetab	; newline table
	mov	bx,offset tcpnlhlp	; help
	call	keyend
	jc	tcpse20			; fail
	mov	tcpnewline,bl		; set mode
	clc
	ret
tcpse14:cmp	bx,12			; debug mode?
	jne	tcpse15			; ne = no
	mov	dx,offset tcpdbtab
	xor	bx,bx			; help
	call	keyend
	jc	tcpse20			; fail
	mov	tcpdebug,bl		; set mode
	clc
	ret
tcpse15:cmp	bx,13			; binary/nvt mode?
	jne	tcpse16			; ne = no
	mov	dx,offset tcpmodetab	; mode table
	xor	bx,bx			; help
	call	keyend
	jc	tcpse20
	mov	tcpmode,bl		; set mode
	clc
	ret
tcpse16:cmp	bx,14			; MSS?
	jne	tcpse20			; ne = no
	mov	numhlp,offset tcpmsshlp	; help
	mov	min,16			; get decimal value
	mov	max,1460		; range is 16 to 1460 decimal
	mov	numerr,0		; error message
	call	num0			; convert number, return it in ax
	jc	tcpse20			; c = error
	mov	tcpmss,ax		; MSS
	clc
	ret
tcpse20:stc				; fail
	ret
tcpipset endp
endif	; no_tcp

; SET TRANSFER  CHARACTER-SET {Latin1, Shift-JIS, Transparent}
; SET TRANSFER  TRANSLATION {Readable, Invertible}
; SET TRANSFER  MODE {Automatic, Manual}
sxfer	proc	near
	mov	dx,offset xfertab	; table of TRANSFER keywords
	xor	bx,bx
	mov	ah,cmkey		; get next keyword
	call	comnd
	jc	sxfer1			; c = error
	or	bl,bl			; Character-set?
	jnz	sxfer2			; nz = no
	mov	dx,offset xfchtab	; Character-set table
	mov	bx,offset xfchhlp	; help text
	call	keyend
	jc	sxfer1			; c = error
	mov	dtrans.xchset,bl	; store transfer char set ident
	mov	trans.xchset,bl		; store transfer char set ident
	cmp	bl,xfr_cyrillic		; Cyrillic?
	jne	sxfer9			; ne = no
	mov	ax,flags.chrset		; get current file character set
	mov	flags.chrset,866	; force CP866
	cmp	ax,866			; was CP866/LATIN5 File Character set?
	je	sxfer8			; e = yes
	mov	dx,offset xfchbad	; show warning message
	mov	ah,prstr
	int	dos
sxfer8:	clc
sxfer1:	ret
sxfer9:	cmp	bl,xfr_japanese		; Japanese-EUC?
	jne	sxfer10			; ne = no
	mov	ax,flags.chrset		; get current file character set
	mov	flags.chrset,932	; force Shift-JIS
	cmp	ax,932			; was Shift-JIS File Character set?
	je	sxfer8			; e = yes
	mov	dx,offset xfchbad2	; show warning message
	mov	ah,prstr
	int	dos
	clc
	ret
sxfer10:cmp	bl,xfr_hebiso		; Hebrew-ISO?
	jne	sxfer8			; ne = no
	mov	ax,flags.chrset		; get current file character set
	mov	flags.chrset,862	; force CP 862
	cmp	ax,862			; was CP862 the File Character set?
	je	sxfer8			; e = yes
	mov	dx,offset xfchbad3	; show warning message
	mov	ah,prstr
	int	dos
	clc
	ret

sxfer2:	cmp	bx,1			; LOCKING-SHIFT?
	jne	sxfer3			; ne = no
	mov	dx,offset xfertab1	; off, on, forced table
	mov	bx,offset xferhlp1
	call	keyend
	jc	sxfer1
	mov	dtrans.lshift,bl	; save state
	mov	trans.lshift,bl
	clc
	ret
sxfer3:	cmp	bx,2			; Translation table?
	jne	sxfer4			; ne = no
	mov	dx,offset xfertab2	; TRANSLATION table
	mov	bx,offset xfchhlp2	; help text
	call	keyend
	jc	sxfer1			; c = error
	mov	dtrans.xchri,bl		; store readable/invertible flag
	mov	trans.xchri,bl
	clc
	ret
sxfer4:	cmp	bx,3			; MODE?
	jne	sxfer5			; ne = no
	mov	dx,offset xfertab3	; MODE table
	mov	bx,offset xferhlp3	; help text
	call	keyend
	jc	sxfer1			; c = error
	mov	dtrans.xmode,bl		; store file transfer mode sensing
	mov	trans.xmode,bl
	clc
	ret

sxfer5:	cmp	bl,4			; CRC?
	jne	sxfer6			; ne = no
	mov	dx,offset ontab		; on/off table
	xor	bx,bx
	call	keyend
	jc	sxfer6			; c = error
	mov	dtrans.xcrc,bl		; store crc usage
	mov	trans.xcrc,bl
	clc
	ret
sxfer6:	stc				; fail
	ret
sxfer	endp

; SET TRANSLATION 		  Connect mode translate characters
; SET TRANSLATION INPUT {Original-byte New-byte | ON | OFF}
; SET TRANSLATION KEYBOARD {ON | OFF}, default is ON

SETRX	PROC	NEAR			; translate incoming serial port char
	mov	ah,cmkey
	mov	dx,offset trnstab	; direction table (just one entry)
	xor	bx,bx			; no help
	call	comnd
	jnc	setrx0			; nc = success
	ret				; failure
setrx0:	cmp	bx,2			; Keyboard?
	jne	setrx0b			; ne = no
	jmp	setr11			; do keyboard
setrx0b:mov	bx,offset rdbuf		; our work space
	mov	dx,offset srxhlp1	; first help message
	mov	ah,cmword		; parse a word
	call	comnd			; get incoming byte pattern
	jnc	setrx0a			; nc = success
	ret
setrx0a:or	ax,ax			; any text given?
	jz	setr6			; nz = no
	mov	temp,ax			; save byte count here
	mov	ax,word ptr rdbuf	; get first two characters
	or	ax,2020h		; convert upper to lower case
	cmp	ax,'fo'			; first part of word OFF?
	je	setr6			; e = yes, go analyze
	cmp	ax,'no'			; word ON?
	je	setr6			; e = yes, go do it
	mov	domath_ptr,offset rdbuf
	mov	domath_cnt,16
	mov	domath_msg,1		; stop messages
	call	domath			; convert to number in ax
	jnc	setr1			; nc = success	
	mov	ax,word ptr rdbuf
	cmp	temp,1			; just one character given?
;;;;;;;	jne	setr6			; ne = no, so bad code
setr1:	mov	min,ax			; save byte code here
	mov	bx,offset rdbuf		; our work space
	mov	dx,offset srxhlp1	; first help message
	mov	ah,cmword		; parse a word
	call	comnd			; get incoming byte pattern
	jnc	setr2			; nc = success
	ret				; failure
setr2:	or	ax,ax			; any text given?
	jz	setr6			; z = no
	mov	temp,ax			; save byte count here
	mov	domath_ptr,offset rdbuf
	mov	domath_cnt,ax
	mov	domath_msg,1		; stop messages
	call	domath			; convert to number in ax
	jnc	setr3			; nc = success
	mov	ax,word ptr rdbuf
	cmp	temp,1			; just one character given?
;;;;;	jne	setr6			; ne = no, so bad code or ON/OFF
setr3:	mov	max,ax			; save byte code here
	mov	ah,cmeol		; get a confirm
	call	comnd
	jnc	setr3a			; nc = success
	ret				; failure
setr3a:	mov	bx,min			; bl = incoming byte code
	xor	bh,bh
	mov	ax,max			; al = local (translated) byte code
	mov	rxtable [bx],al		; store in rx translate table
	clc				; success
	ret

setr6:	mov	ah,cmeol		; get a confirm
	call	comnd
	jnc	setr6a			; nc = success
	ret				; failure
setr6a:	mov	dx,offset badrx		; assume bad construction
	or	word ptr rdbuf,2020h	; convert to lower case
	or	rdbuf+2,20h		; first three chars
	cmp	word ptr rdbuf,'fo'	; key word OFF?
	jne	setr8			; ne = no
	cmp	rdbuf+2,'f'		; last letter of OFF?
	jne	setr8			; ne = no
	mov	rxtable+256,0		; OFF is status byte = zero
	mov	dx,offset rxoffmsg	; say translation is turned off
	jmp	short setr9
setr8:	cmp	word ptr rdbuf,'no'	; keyword ON?
	jne	setr9a			; ne = no, error
	mov	rxtable+256,1		; ON is status byte non-zero
	mov	dx,offset rxonmsg	; say translation is turned on
setr9:	cmp	taklev,0		; executing from a Take file?
	je	setr9a			; e = no
	cmp	flags.takflg,0		; echo contents of Take file?
	je	setr10			; e = no
setr9a:	mov	ah,prstr		; bad number message
	int	dos
setr10:	clc
	ret
setr11:	mov	ah,cmkey		; SET TRANSLATION KEYBOARD
	mov	dx,offset ontab		; on/off
	xor	bx,bx
	call	comnd
	jnc	setr12			; nc = success
	ret
setr12:	push	bx
	mov	ah,cmeol		; get a confirm
	call	comnd
	pop	bx
	jnc	setr13			; nc = success
	ret				; failure
setr13:	mov	flags.xltkbd,bl		; set keyboard translation on/off
	clc
	ret
SETRX	ENDP

; SET TRANSMIT {FILL, LF, Prompt} {ON, OFF, or value}
SETXMIT	proc	near
	mov	dx,offset xmitab	; TRANSMIT keyword table
	xor	bx,bx
	mov	ah,cmkey		; get keyword
	call	comnd
	jnc	setxmi1			; nc = success
	ret
setxmi1:cmp	bl,2			; SET TRANSMIT PROMPT?
	jne	setxmi2			; ne = no
	mov	ah,cmword
	mov	bx,offset rdbuf		; put answer here
	mov	dx,offset xpmthlp
	call	comnd
	jc	setxmi1d		; c = error
	push	ax			; save length
	mov	ah,cmeol		; get a confirm
	call	comnd
	pop	cx			; recover length to cx
	jc	setxmi1d		; c = failure
	mov	al,rdbuf
	cmp	cx,1			; a single char?
	je	setxmi1c		; e = yes, use it as the prompt char
	mov	domath_ptr,offset rdbuf
	mov	domath_cnt,cx
	call	domath			; convert to number in ax
	jc	setxmi1d		; c = no number, error
setxmi1c:mov	script.xmitpmt,al	; store new prompt value
setxmi1d:ret

setxmi2:cmp	bl,1			; LF?
	jne	setxmi3			; ne = no
	mov	dx,offset ontab		; on or off table
	xor	bx,bx
	call	keyend
	jc	setxmi2a		; c = failure
	mov	script.xmitlf,bl	; set the xmitlf flag
setxmi2a:ret

setxmi3:cmp	bl,0			; FILL?
	jne	setxmi8			; ne = no
	mov	ah,cmword		; FILL, get a word sized token
	mov	bx,offset rdbuf		; put it here
	mov	dx,offset xfilhlp	; help
	call	comnd
	jc	setxmix			; c = failure
	push	ax			; save length in ah
	mov	ah,cmeol		; get a confirm
	call	comnd
	pop	ax
	jc	setxmix			; c = failure
	cmp	ax,1			; just one character?
	ja	setxmi4			; a = no, there's more
	mov	al,rdbuf		; get the char
	mov	script.xmitfill,al	; store Fill char
	ret
setxmi4:mov	ax,word ptr rdbuf
	or	ax,2020h		; to lower
	cmp	ax,'on'			; "none"?
	jne	setxmi5			; ne = no
	mov	script.xmitfill,0	; no Filling
	ret
setxmi5:cmp	ax,'ps'			; "space"?
	jne	setxmi6			; ne = no
	mov	script.xmitfill,' '	; use space as filler
	ret
setxmi6:mov	domath_ptr,offset rdbuf
	mov	domath_cnt,17
	call	domath			; convert to number in ax
	jc	setxmix			; c = no number, error
	mov	script.xmitfill,al	; set the xmitfill flag
	ret
setxmi8:mov	ah,cmword		; PAUSE milliseconds
	mov	bx,offset rdbuf		; put answer here
	mov	dx,offset xpauhlp
	call	comnd
	jc	setxmix			; c = error
	push	ax			; save length
	mov	ah,cmeol		; get a confirm
	call	comnd
	pop	cx			; recover length to cx
	jc	setxmix			; c = failure
	mov	domath_ptr,offset rdbuf
	mov	domath_cnt,cx
	call	domath			; convert to number in ax
	jc	setxmix			; c = no number, error
	mov	script.xmitpause,ax	; set the xmitpause flag
setxmix:ret
SETXMIT	endp

; SET UNKNOWN-CHARACTER-SET {DISCARD, KEEP}, default is KEEP
unkchset proc	near
	mov	dx,offset unkctab	; keep/reject keyword table
	mov	bx,offset unkchhlp
	call	keyend
	jc	unkchx			; c = failure
	mov	flags.unkchs,bl		; 0 = keep, else reject
unkchx:	ret
unkchset endp

; Common routine for parsing numerical input
; Enter with numhlp = offset of help message, numerr = offset of optional
;  error message, min, max = allowable range of values.
; Returns value in ax, or does parse error return.
; Changes ax,bx,dx,si.			[jrd] 18 Oct 1987
num0:	mov	bx,offset rdbuf		; where to put text
	mov	dx,numhlp		; help text
	mov	ah,cmword		; get a word
	call	comnd
	push	ax			; save string count
	mov	ah,cmeol
	call	comnd			; Get a confirm
	pop	ax
	jc	num0x			; c = failure
	call	numwd
num0x:	ret
					; second entry point

; routine to print an error message, then exit without error status
; expects message in dx
reterr	proc	near
	mov	ah,prstr
	int	dos
	clc
	ret
reterr	endp

code	ends

code1	segment

; Add an entry to a keyword table
; enter with bx = table address, dx = ptr to new entry, macptr = string seg,
; mccptr = offset of free bytes in table mcctab.
; no check is made to see if the entry fits in the table.
addtab	proc	far
	push	cx
	push	si
	push	es
	push	bp
	cld
	mov	ax,ds
	mov	es,ax		; address data segment
	mov	bp,bx		; remember where macro name table starts
	mov	cl,[bx]		; pick up length of table
	xor	ch,ch
	inc	bx		; point to actual table
	jcxz	addta4		; cx = 0 if table is presently empty

addta1:	push	cx		; preserve count
	mov	si,dx		; point to entry
	lodsw			; get length of new entry
	mov	cx,[bx]		; and length of table entry
	cmp	ax,cx		; are they the same?
	lahf			; remember result of comparison
	jae	addta2		; is new smaller? ae = no, use table length
	mov	cx,ax		; else use length of new entry
addta2:	lea	di,[bx+2]	; point to actual keyword
	repe	cmpsb		; compare strings
	pop	cx		; restore count
	jb	addta4		; below, insert before this one
	jne	addta3		; not below or same, keep going
	sahf			; same. get back result of length comparison
	jb	addta4		; if new len is smaller, insert here
	jne	addta3		; if not same size, keep going
	mov	si,bx		; else this is where entry goes
	jmp	short addta6	; no insertion required
addta3:	mov	ax,[bx]		; length of keyword
	add	bx,ax		; skip this entry
	add	bx,4		; length word and 16 bit value
	loop	addta1		; and keep looking
addta4:	mov	si,bx		; this is first location to move
	mov	di,bx
	inc	ds:byte ptr [bp] ; remember we're adding one
	jcxz	addta6		; z = no more entries, forget this stuff
addta5:	mov	bx,[di]		; get length
	lea	di,[bx+di+4]	; end is origin + length + 4 for len, value
	loop	addta5		; loop thru remaining keywords
	mov	cx,di
	sub	cx,si		; compute # of bytes to move
	push	si		; preserve loc for new entry
	mov	si,di		; first to move is last
	dec	si		; minus one
	mov	di,dx		; new entry
	mov	bx,[di]		; get length
	lea	di,[bx+si+4]	; dest is source + length of new + 4
	std			; move backward
	rep	movsb		; move the table down (compress it)
	cld			; put flag back
	pop	si
addta6:	mov	di,si		; this is where new entry goes
	mov	si,dx		; this is where it comes from
	mov	cx,[si]		; length of name
	add	cx,2		; include count byte
	add	mccptr,cx	; update free space pointer: cnt+name
	rep	movsb		; insert new entry
	mov	ax,macptr	; and string address
	stosw
	add	mccptr,2	; plus string address
	pop	bp
	pop	es
	pop	si
	pop	cx
	ret
addtab	endp

; If new keyword matches an existing one then remove existing keyword,
; its string definition, compress tables mcctab and macbuf, readjust string
; pointers for each macro name, reduce number of macro table entries by one.
; Enter with DI pointing at length word of mac name (followed by mac name).
; Otherwise, exit with no changes.  13 June 1987 [jrd]
remtab	proc	far
	push	ax
	push	bx
	push	cx
	push	si
	push	di
	push	temp			; preserve
	mov	bx,offset mcctab+1	; table of macro keywords
	mov	temp,0			; temp = current keyword
	cmp	byte ptr mcctab,0	; any macros defined?
	jne	remta1			; ne = yes
	jmp	remtax			; else exit now
remta1:					; match table keyword and text word
	mov	si,di			; pointer to user's cnt+name
	mov	cx,[si]			; length of user's macro name
	jcxz	remtax			; empty macro name to remove
	add	si,2			; point to new macro name
	cmp	cx,[bx]			; compare length vs table keyword
	jne	remta4			; ne = not equal lengths, try another
	push	si			; lengths match, how about spelling?
	push	bx
	add	bx,2			; point at start of keyword
remta2:	mov	ah,[bx]			; keyword char
	mov	al,[si]			; new text char
	cmp	al,ah			; test characters
	jne	remta3			; ne = no match
	inc 	si			; move to next char
	inc	bx
	loop	remta2			; loop through entire length
remta3:	pop	bx
	pop	si
	jcxz	remta6			; z: cx = 0, exit with match;
					;  else select next keyword
remta4:	inc	temp			; number of keyword to test next
	mov	cx,temp
	cmp	cl,mcctab		; all done? Recall, temp starts at 0
	jb	remta5			; b = not yet
	jmp	remtax			; exhausted search, unsuccessfully
remta5:	mov	ax,[bx]			; cnt (keyword length from macro)
	add	ax,4			; skip count and word pointer
	add	bx,ax			; bx = start of next keyword slot
	jmp	short remta1		; do another comparison
					; new name already present as a macro
remta6:	cld				; clear macro string and macro name
	push	ds
	pop	es			; set es to data segment
	mov	temp,bx			; save ptr to found keyword
	mov	ax,[bx]			; cnt (keyword length of macro)
	add	ax,2			; skip cnt
	add	bx,ax			; point to string segment field
	add	ax,2			; count segment field bytes
	sub	mccptr,ax		; readjust free space ptr for names
	push	bx
	push	es
	mov	es,[bx]			; segment of string
	mov	ax,ds			; check for being in our data segment
	cmp	ax,[bx]			; same as our data seg?
	je	remta7			; e = yes, don't free that
	mov	ah,freemem		; free that memory block
	int	dos
remta7:	pop	es
	pop	bx
					; clear keyword table mcctab
	add	bx,2			; compute source = next keyword
	mov	si,bx			; address of next keyword
	mov	di,temp			; address of found keyword
	mov	cx,offset mcctab+mcclen ; address of buffer end
	sub	cx,si			; amount to move
	jcxz	remtax			; cx = 0 means none
	rep	movsb			; move down keywords (deletes current)
	dec	mcctab			; one less keyword
remtax:	pop	temp			; recover temp variable
	pop	di
	pop	si
	pop	cx
	pop	bx
	pop	ax
	ret
remtab	endp

; Renames macros \%0..\%9 by changing the first two characters of the name
; to be <null><taklev>. Used to preserve old \%n macros and not show them.
; Return carry set if nothing is hidden.
hidemac proc	far
	push	bx
	push	cx
	push	temp
	mov	hidetmp,0		; use binary 0 prefix
	mov	byte ptr temp,'0'	; start with this \%0 name
hidema1:mov	bx,offset mcctab+1	; table of macro names, skip count
	mov	cl,mcctab		; number of entries
	xor	ch,ch
	jcxz	hidema6			; z = empty table

hidema2:cmp	word ptr [bx],3		; name length, do three byte names
	jne	hidema3			; ne = not three chars
	cmp	word ptr [bx+2],'%\'	; starts with correct prefix?
	jne	hidema3			; ne = no
	mov	al,byte ptr [bx+4]	; third char of name
	cmp	al,byte ptr temp	; matches name?
	je	hidema4			; e = yes
hidema3:mov	ax,[bx]			; get length of name
	add	ax,4			; plus count and word pointer
	add	bx,ax			; point to next entry
	loop	hidema2
	jmp	short hidema5
hidema4:call	hidewrk			; call worker to hide macro
hidema5:inc	byte ptr temp
	cmp	byte ptr temp,'9'	; all done?
	jbe	hidema1			; be = no
hidema6:pop	temp
	pop	cx
	pop	bx
	ret
hidemac	endp

; Hide existing macro. Enter with BX pointing to entry slot in mcctab,
; uses settemp as temp workspace.
; Used by hidemac and localmac. 
hidewrk	proc	far
	push	bx
	push	cx
	push	si
	push	di
	mov	di,bx			; need di for remtab
	mov	ax,[bx]			; original count word
	mov	cx,ax
	add	ax,2			; plus new prefix
	mov	si,offset settemp
	mov	[si],ax			; len = old length plus <null><level>
	xor	al,al			; prepare new prefix
	mov	al,hidetmp		;  use 0..9 binary
	mov	ah,taklev		; of <null><taklev>
	mov	[si+2],ax		; new prefix
	add	si,4			; count and prefix
hidewr1:mov	al,[bx+2]		; copy old name after prefix
	mov	[si],al
	inc	bx
	inc	si
	loop	hidewr1

      	mov	bx,di
	mov	ax,[bx]			; length of name
	add	ax,2			; plus name length count word
	add	bx,ax			; point at definition segment
	mov	ax,1			; smallest allocation
	call	malloc			; allocate space as dummy definition
	mov	cx,[bx]			; seg of original def to CX
	mov	[bx],ax			; seg of dummy def replaces it
	call	remtab			; remove macro, di is pointer
	mov	macptr,cx		; tell addtab definition segment
	mov	bx,offset mcctab 	; macro name table
	mov	dx,offset settemp	; new name
	call	addtab		; create new entry for <null><digit><oldname>
	pop	di
	pop	si
	pop	cx
	pop	bx
	mov	hidetmp,0
	ret
hidewrk	endp

; Removes all current \%0..\%9 macros and renames <null><taklev> macros by
; removing the first two characters of the names of form <null><taklev>foo.
; Used to recover old \%n macros from hidemac and locals from Local.
unhidemac proc	far
	push	bx
	push	cx
	push	dx
	push	di     			; do rename of <null><taklev>foo
unhide1:mov	di,offset mcctab+1	; table of macro names, skip count
	mov	cl,mcctab		; number of entries
	xor	ch,ch
	jcxz	unhide5			; z = empty table
	xor	dl,dl			; dx = macro prefix to examine
	mov	dh,taklev		; di => length word, name string
	mov	dl,hidetmp

unhide2:cmp	word ptr [di+2],dx	; starts with <0/1><taklev> prefix?
	jne	unhide4			; ne = no
	mov	bx,di
	mov	cx,[bx]			; length of definition
	sub	cx,2			; skip prefix bytes
	push	si
	mov	si,offset settemp	; destination work buffer
	mov	[si],cx 		; new length
	add	si,2			; have stored count word
	add	bx,2+2			; skip count word and prefix
unhide3:mov	al,[bx]
	mov	[si],al			; copy name to temp array
	inc	si
	inc	bx
	loop	unhide3
	pop	si
	mov	bx,di
	add	bx,[bx]			; skip macro name
	add	bx,2			; and count word
	mov	cx,[bx]			; cx is now seg of definition
	mov	ax,1			; minimal allocation of one byte
	call	malloc			; create dummy def
	mov	[bx],ax			; write new dummy def segment
	call	remtab			; remove prefixed name, DI is ptr
	mov	di,offset settemp	; shortened name
	call	remtab			; remove unprefixed macro, DI is ptr
	mov	bx,offset mcctab	; mac table
	mov	dx,offset settemp	; name string
	mov	macptr,cx		; segment of definition
	call	addtab			; add to table
	jmp	unhide1

unhide4:mov	ax,[di]			; get length of name
	add	ax,4			; plus count and word pointer
	add	di,ax			; point to next entry
	loop	unhide2			; look at next entry
unhide5:pop	di
	pop	dx
	pop	cx
	pop	bx
	ret
unhidemac endp

numwd	proc	far			; worker
	mov	domath_ptr,offset rdbuf
	mov	domath_cnt,ax
	call	domath			; convert to number in ax
	jc	num0er			; c = no number, error
	cmp	ax,max			; largest permitted value
	ja	num0er			; a = error
	cmp	ax,min			; smallest permitted value
	jb	num0er			; b = error
	clc
	ret				; return value in ax

num0er:	mov	dx,numerr		; comand-specific error message, if any
	or	dx,dx			; was any given?
	jz	num0e1			; z = no, use generic msg
	push	ds
	mov	ax,seg data1		; where help lives
	mov	ds,ax
	mov	ah,prstr
	int	dos			; show given error message
	pop	ds
	jmp	short num0e2
num0e1:	mov	dx,offset nummsg1	; get address of numeric error message
	push	ds
	mov	ax,seg data1
	mov	ds,ax
	mov	ah,prstr
	int	dos
	pop	ds
	mov	ax,min			; smallest permitted number
	call	decout			; display decimal number in ax
	mov	ah,prstr
	push	ds
	mov	dx,seg nummsg2
	mov	ds,dx
	mov	dx,offset nummsg2	; "and"
	int	dos
	pop	ds
	mov	ax,max			; largest permitted number
	call	decout
	mov	ah,prstr
	mov	dx,offset crlf
	int	dos
num0e2:	stc
	ret
numwd	endp

; Worker for POP/END and RETURN.
; Pop take levels (via takclo) through tails of For/While, back to the
; take level of the last DO or prompt command.
POPLEVEL proc	far
	cmp	taklev,0		; in a Take/macro?
	je	poplevx			; e = no
	mov	bx,takadr
	mov	al,[bx].takinvoke	; take level of last DO or command
	mov	ah,[bx].takattr		; attributes
	cmp	taklev,al		; Take level now versus last DO
	jb	poplevx			; b = have exited macro already
	push	ax
	call	takclos			; close current Macro/Take
	pop	ax
	test	ah,take_while+take_subwhile ; closed While/For/Switch?
	jz	poplevx			; z = no
	mov	bx,takadr
	test	[bx].takattr,take_while+take_subwhile ; for/while macro?
	jnz	poplevel		; nz = yes, exit for/while too
poplevx:clc
	ret
POPLEVEL endp

FDECLARE	proc	far		; declare array \&<char @a..z>[size]
	or	ax,ax			; null entry?
	jnz	decl2
	stc				; fail
	ret
decl2:	cmp	rdbuf[3],'&'		; syntax checking
	jne	declf			; ne = fail
	cmp	rdbuf[5],'['		; size bracket?
	jne	declf			; ne = no, fail
	and	rdbuf[4],not 20h	; to upper case
	mov	al,rdbuf[4]		; array name
	cmp	al,'A'			; range check
	jb	declf
	cmp	al,'Z'
	ja	declf
	mov	si,offset rdbuf[6]	; point at size number
	xor	ah,ah
	mov	cx,128			; limit scan
decl3:	lodsb
	cmp	al,']'			; closing bracket?
	je	decl4			; e = yes
	inc	ah			; count byte
	loop	decl3			; keep looking
	jmp	declf			; fail if got here
decl4:	xor	al,al
	xchg	ah,al
	sub	si,ax			; point at start of number
	dec	si
	mov	domath_ptr,si
	mov	domath_cnt,ax
	call	domath			; convert to number in ax
	jnc	decl5			; nc = success, value is in DX:AX
	ret				; fail
decl5:	or	dx,dx			; too large a value?
	jnz	decl5a			; nz = yes
	cmp	ax,32000		; 32000 max
	jbe	decl5b			; be = in range
decl5a:	mov	dx,offset arraybad	; say too large
	mov	ah,prstr
	int	dos
	jmp	declf			; fail
decl5b:	mov	bl,rdbuf[4]
	sub	bl,'@'			; remove bias
	js	declf			; s = sign, failure
	xor	bh,bh			; preserve bx til end of proc
	shl	bx,1			; address words
	call	decl20			; call remover
	cmp	ax,0			; index of zero to clear the array?
	je	decl6			; e = yes, done
	inc	ax			; create one more than [value]
	call	decl10			; call creator
decl6:	ret
declf:	stc				; failure
	ret

decl20	proc	near			; remove array
	push	ax			; save size in ax
	push	es
	mov	si,marray[bx]		; get segment of array's definition
	or	si,si			; anything present?
	jz	decl23			; no, no need to undefine anything
	mov	es,si
	mov	cx,es:[0]		; get number of elements
	jcxz	decl23			; z = none, unlikely
	xor	si,si			; count word (number of elements)
decl21:	add	si,2			; point to slot holding string seg
	mov	ax,es:[si]		; get string seg
	or	ax,ax			; null?
	jz	decl22			; z = yes, ignore
	mov	word ptr es:[si],0	; clear string seg pointer
	push	es
	mov	es,ax			; segment
	mov	ah,freemem		; free the memory
	int	dos
	pop	es
decl22:	loop	decl21
	xor	ax,ax			; get a zero
	xchg	ax,marray[bx]		; clear array seg storage pointer
	mov	es,ax
	mov	ah,freemem		; free storage pointer memory
	int	dos
decl23:	pop	es
	pop	ax
	clc				; end removing array
	ret
decl20	endp

decl10	proc	near			; creator
	push	ax			; save ax
	inc	ax			; number of elements plus one size int
	shl	ax,1			; count bytes for malloc
	call	malloc			; get seg of memory to ax
	pop	cx			; array size (was in ax)
	jc	decl12			; c = failed
	mov	marray[bx],ax		; remember storage area
	push	es
	push	di
	mov	es,ax			; segment of new memory
	mov	es:[0],cx		; write size of array as 1st word
	mov	di,2			; offset of string seg pointers
	xor	ax,ax
	cld
	rep	stosw			; clear the array
	pop	di
	pop	es
	clc
decl12:	ret				; can return carry set from failure
decl10	endp
FDECLARE endp

; define contents of array element. Command line is in rdbuf+2 as
; \&<char>[index] definition, from dodef. Length of line is in cx.

defarray proc	far
	cmp	rdbuf[3],'&'		; syntax checking
	jne	defarf			; ne = fail
	cmp	rdbuf[5],'['		; size bracket?
	jne	defarf			; ne = no, fail
	and	rdbuf[4],not 20h	; to upper case
	mov	al,rdbuf[4]		; array name
	cmp	al,'A'			; range check
	jb	defarf
	cmp	al,'Z'
	ja	defarf
	mov	si,offset rdbuf[6]	; point at size number
	xor	ah,ah
	cld
defar3:	lodsb
	cmp	al,']'			; closing bracket?
	je	defar4			; e = yes
	inc	ah			; count byte
	loop	defar3			; keep looking
	jmp	defarf			; fail if got here
defar4:	xor	al,al			; cx has chars remaining in cmd line
	xchg	ah,al
	mov	di,si			; save di as start of definition space
	sub	si,ax			; point at start of number
	dec	si
	mov	domath_ptr,si
	mov	domath_cnt,ax
	call	domath			; do string to binary dx:ax
	jnc	defar5			; nc = success, value is in DX:AX
	ret				; fail
defar5:	mov	temp,ax			; save index value
	mov	bl,rdbuf[4]		; get array name letter
	sub	bl,'@'			; remove bias
	xor	bh,bh			; preserve bx til end of proc
	shl	bx,1			; address words

defar6:	call	defar_rem		; clear current definition, if any
	inc	di			; skip space between name and def
	mov	dx,di			; for strlen
	call	strlen			; length of definition
	jcxz	defar7			; z = no definition, done
	mov	si,marray[bx]		; segment of array
	or	si,si			; if any
	jz	defar7			; z = none
	push	es
	mov	es,si
	mov	si,temp			; array index
	shl	si,1			; index words
	mov	ax,es:[0]		; get array size
	shl	ax,1			; in words
	cmp	si,ax			; index versus size
	ja	defar8			; a = out of bounds, ignore
	mov	ax,cx			; bytes needed
	add	ax,2+2			; starts with byte count and elem 0
	call	malloc			; get the space
	jc	defar8			; c = failed
	mov	es:[si+2],ax		; remember segment of string def
	mov	es,ax			; string definition seg
	mov	es:[0],cx		; length of string
	mov	si,di			; start of string text
	mov	di,2			; destination
	cld
	rep	movsb			; copy to malloc'd space
	pop	es
defar7:	clc				; success
	ret
defar8:	pop	es
defarf:	mov	kstatus,ksgen		; general command failure
	stc				; failure exit
	ret

; Remove string definition. Enter with BX holding array name index, and
; TEMP holding array index.
defar_rem proc	near			; remove definition of array element
	push	ax			; undefining string within array
	push	si
	push	es
	mov	ax,marray[bx]		; current array seg
	or	ax,ax			; if any
	jz	defar_rem1		; z = none
	mov	si,temp			; index value
	shl	si,1			; index words
	mov	es,ax
	mov	ax,es:[0]		; get array size
	shl	ax,1			; in words
	cmp	si,ax			; index versus size
	ja	defar_rem1		; a = out of bounds, ignore
	xor	ax,ax			; get a zero
	xchg	ax,es:[si+2]		; get string's segment to ax, clr ref
	or	ax,ax			; anything there?
	jz	defar_rem1		; z = no
	mov	es,ax			; seg to es for DOS
	mov	ah,freemem		; free string space
	int	dos
defar_rem1:
	pop	es
	pop	si
	pop	ax
	ret
defar_rem endp

defarray endp

; Revise string in ES:SI et seq. Expect incoming length to be in CX.
; Original string modified to replace bare commas with Carriage Returns.
; Top level braces removed, but only if the string begins with an 
; opening brace, and hence commas revealed are also converted to CR.
; A null is forced at the end of the string.
; All registers preserved except CX (returned length).
docnv	proc	far
	push	ax
	push	bx
	push	dx
	push	si			; src domacptr:0,2
	push	di
	xor	bx,bx			; brace count (bl), paren (bh)
	mov	dl,braceop		; opening brace (we count them up)
	mov	dh,bracecl		; closing brace (we count them down)
	mov	cx,es:[si]		; get string length
	or	cx,cx
	jnz	docnv1			; nz = non-empty string
	pop	di
	pop	si
	pop	dx
	pop	bx
	pop	ax
	ret
docnv1:	add	si,2			; where text starts
	mov	di,si			; si = source
	cld
	mov	ah,es:[si]		; record opening char
docnv2:	mov	al,es:[si]		; read a char
	cmp	al,dl			; opening brace?
	jne	docnv3			; ne = no
	inc	bl			; count brace level
	cmp	bl,1			; first level?
	jne	docnv7			; ne = no, write intact
	or	bh,bh			; in parens?
	jnz	docnv7			; nz = yes, don't replace
	cmp	ah,dl			; started with opening brace?
	jne	docnv7			; ne = no, don't replace brace
	jmp	short docnv8		; skip opening brace
docnv3:	cmp	al,dh			; closing brace?
	jne	docnv4			; ne = no
	dec	bl			; count down
	or	bl,bl			; still within braces?
	jg	docnv7			; g = yes, write intact
	xor	bx,bx			; found brace match, reset to zero
	cmp	ah,dl			; started with opening brace?
	jne	docnv7			; ne = no, write brace
	jmp	short docnv8		; omit the brace
docnv4:	cmp	al,'('			; opening paren?
	jne	docnv5			; ne = no
	inc	bh			; count paren level
	jmp	short docnv7
docnv5:	cmp	al,')'			; closing paren?
	jne	docnv6			; ne = no
	dec	bh
	cmp	bh,0			; below 0?
	jg	docnv7			; g = no, still in paren
	xor	bh,bh			; in case underrun, reset to zero
	jmp	docnv7			; matching paren
docnv6:	cmp	al,','			; comma?
	jne	docnv7			; ne = no
	or	bh,bh			; in paren clause?
	jnz	docnv7			; nz = yes, treat comma as literal
	cmp	bl,0;;1			; in braced clause?
	ja	docnv7			; a = yes, treat comma as literal
	mov	al,CR			; replace bare comma with CR
docnv7:	mov	es:[di],al
	inc	di			; next destination byte
docnv8:	inc	si			; next input byte
	loop	docnv2			; do more
docnv9:	mov	cx,di			; ending place + 1
	pop	di
	pop	si			; start of buffer
	sub	cx,si
	sub	cx,2			; minus count word
	mov	es:[si],cx		; string length
	pop	dx
	pop	bx
	pop	ax
	clc
	ret
docnv	endp

code1	ends
	end
