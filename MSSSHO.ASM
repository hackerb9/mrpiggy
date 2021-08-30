	name	msssho
; File MSSSHO.ASM
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
; Show & Status commands
; Edit history
; 12 Jan 1995 version 3.14
; Last edit
; 12 Jan 1995

	public	shorx, shomac, shcom, shfile, shlog, shpro, shscpt, shserv
	public	shterm, status, statc, stat0, srchkw, srchkww, srchkb, shmem
	public	destab, seoftab, blktab, dmpname, lsesnam, lpktnam
	public	ltranam, incstb, inactb, rxoffmsg, rxonmsg, lnout, lnouts
	public	shosta, begtim, endtim, fsta, ssta    ; statistics procedures
	public	rtmsg, rppos, stpos, rprpos, sppos, perpos, cxerr, frpos
	public	fmtdsp, ermsg, msgmsg, init, cxmsg, intmsg, kbpr, perpr
	public	winpr, windflag, pktsize, clrfln, oldkbt, oldper
	public  wrpmsg, prttab, pasz, shovar, prnname, filekind, filecps
	public	cntlsho, logtransact, shovarcps, sharray, streampr
	public	ferbyte, ferdate, ferdisp, fertype, ferchar, fername, ferunk

mcclen	equ	macmax*10
				; equates for screen positioning

ifndef	nls_portuguese
scrser	equ	0109H		; place for server state display line
scrfln	equ	0216H		; place for file name
scrkind equ	0316h		; Place for file kind
scrpath equ	0416h		; Place for current path
scrkb	equ	0516H		; Place for Kbytes transferred
scrper	equ	0616H		; Place for percentage transferred

scrst	equ	0816H		; Place for status
scrnp	equ	0a16H		; Place for number of packets
scrsz	equ	0b16h		; packet size
scrnrt  equ	0c16H		; Place for number of retries
screrr  equ	0d16H		; Place for error msgs
scrmsg	equ	0e16H		; Last message position
else
scrser	equ	0106H		; place for server state display line
scrfln	equ	0216H		; place for file name
scrkind equ	0316h		; Place for file kind
scrpath equ	0416h		; Place for current path
scrkb	equ	0516H		; Place for Kbytes transferred

scrper	equ	061aH		; Place for percentage transferred
scrst	equ	081aH		; Place for status
scrnp	equ	0a1aH		; Place for number of packets
scrsz	equ	0b1ah		; packet size
scrnrt  equ	0c1aH		; Place for number of retries
screrr  equ	0d1aH		; Place for error msgs
scrmsg	equ	0e1aH		; Last message position
endif	; nls_portuguese

scrsp	equ	0f00H		; Place for send packet
scrrp	equ	1300H		; Place for receive packet
scrrpr	equ	1700H		; Prompt when Kermit ends (does cr/lf)
braceop	equ	7bh		; opening curly brace
bracecl	equ	7dh		; closing curly brace

data	segment
	extrn	termtb:byte, comptab:byte, portval:word,dtrans:byte,rdbuf:byte
	extrn	trans:byte, curdsk:byte, flags:byte, maxtry:byte, comand:byte
	extrn	spause:word, taklev:byte, takadr:word, alrhms:byte, bdtab:byte
	extrn	denyflg:word, rxtable:byte, mcctab:byte, script:byte
	extrn	errlev:byte, luser:byte, srvtmo:byte, mccptr:word, thsep:byte
	extrn	scpbuflen:word, setchtab:byte, xfchtab:byte, xftyptab:byte
	extrn	tfilsz:word, diskio:byte, tloghnd:word, dosnum:word
	extrn	templp:byte, windused:byte, numpkt:word, verident:byte
	extrn	decbuf:byte, flotab:byte, warntab:byte, valtab:byte
	extrn	xfertab1:byte, xfertab2:byte, xfertab3:byte, outpace:word
	extrn	winusedmax:byte, protlist:byte, takeerror:byte,macroerror:byte
	extrn	abftab:byte, sndpathflg:byte, marray:word, rcvpathflg:byte
	extrn	domath_ptr:word, domath_cnt:word, lastfsize:dword
	extrn	crcword:word, streaming:byte, streamok:byte

crlf	db       cr,lf,'$'
eqs	db	' = $'
spaces	db	'    $'

outlin1 db	6 dup (' '),'$'
;;;	version appears here
ifndef	nls_portuguese
outlin2 db	cr,lf
        db      cr,lf,'           File name:'
	db	cr,lf,'           File type:'
	db	cr,lf,'        Current path:'
        db      cr,lf,'  KBytes transferred:'
        db      cr,lf
        db      cr,lf
        db      cr,lf,lf
        db      cr,lf,'   Number of packets:'
	db	cr,lf,'       Packet length:'
        db      cr,lf,'   Number of retries: 0'
        db      cr,lf,'          Last error:'
        db      cr,lf,'        Last message:'
        db      cr,lf,'$'

permsg	db	cr,' Percent transferred:$'
perscale db	': 0....1....2....3....4....5....6....7....8....9....10$'
lastper	db	0
cxzhlp	db	'X: cancel file, Z: cancel group, E: exit nicely,'
	db	' C: exit abruptly, Enter: retry$'
blanks	db	10 dup (' '),'$'
erword	db	cr,lf,'Error: $'
msword	db	cr,lf,'Message: $'
rtword	db	cr,lf,'Retry $'
cxzser	db	cr,lf,' Type X to cancel file, Z to cancel group,'
	db	cr,lf,' E to exit nicely, C to quit abruptly,'
	db	cr,lf,' or Enter to retry',cr,lf,'$'
windmsg	db	' Window slots in use:$'
windmsg2 db	' of $'
streammsg db	'           Streaming: Active$'
else

outlin2 db	cr,lf 
	db	cr,lf,'     Nome do arquivo:'
	db	cr,lf,'     Tipo do arquivo:'
	db	cr,lf,'      Percurso atual:' 
	db	cr,lf,' KBytes transferidos:'
	db	cr,lf
	db	cr,lf
	db	cr,lf,lf
	db	cr,lf,'   Quantidade de pacotes:'
	db	cr,lf,'       Tamanho do pacote:'
	db	cr,lf,'           Re-tentativas: 0'
	db	cr,lf,'             Ultimo erro:'
	db	cr,lf,'         Ultima mensagem:'
	db      cr,lf,'$'

permsg	db	cr,' Percentagem transferido:$'
perscale db	': 0....1....2....3....4....5....6....7....8....9....10$'
lastper	db	0
cxzhlp	db	'X: cancela arquivo, Z: cancela grupo, E: encerra elegantemente'
	db	' C: encerra abruptamente, Enter: re-tenta$'
blanks	db	10 dup (' '),'$'
erword	db	cr,lf,'Erro: $'
msword	db	cr,lf,'Messagem: $'
rtword	db	cr,lf,'Retenta $'
cxzser	db	cr,lf,' X cancela arquivo, Z cancela grupo,'
	db	cr,lf,' E cancela elegantemente, C encerra abruptamente,'
	db	cr,lf,' Enter  re-tenta',cr,lf,'$'
windmsg	db	'      Pacotes por janela:$'
windmsg2 db	' of $'
streammsg db	'           Streaming: active$'
endif	; nls_portuguese

windflag db	0		; flag to init windows msg, 0=none
oldwind	db	-1		; last windows in use value
oldper	dw	0		; old percentage
oldkbt	dw	0		; old KB transferred
wrpmsg	db	0		; non-zero if we wrote percent message
fmtdsp	db	0		; non-zero if formatted display in use
prepksz	dw	0		; previous packet size
onehun	dw	100
denom	dw	0
temp	dw	0
temp1	dw	0
shmcnt	dw	0
xfercps	dd	0
sixteen	dw	16

ifndef	nls_portuguese
infms1	db	'Server mode: type Control-C to exit',cr,lf,'$'
infms7	db	'File interrupt',cr,lf,'$'
infms8	db	'File group interrupt',cr,lf,'$'
infms9	db	'User ',5eh,'  interrupt',cr,lf,'$'
else
infms1	db	'SModo servidor: digte Control-C para encerrar',cr,lf,'$'
infms7	db	'Interrupcao de arquivo',cr,lf,'$'
infms8	db	'Interrupcao de grupo de arquivo',cr,lf,'$'
infms9	db	'Interrompido ',5eh,'  pelo usuario',cr,lf,'$'
endif	; nls_portuguese

partab	db	9
	mkeyw	'none (8-bit data) ',PARNON
	mkeyw	'even (7-bit data) ',PAREVN
	mkeyw	'odd (7-bit data) ',PARODD
	mkeyw	'mark (7-bit data) ',PARMRK
	mkeyw	'space (7-bit data) ',PARSPC
	mkeyw	'HARDWARE even (9-bit byte)',PAREVNH
	mkeyw	'HARDWARE odd (9-bit byte)',PARODDH
	mkeyw	'HARDWARE mark (9-bit byte)',PARMRKH
	mkeyw	'HARDWARE space (9-bit byte)',PARSPCH

destab	db	3
	mkeyw	'Disk',dest_disk
	mkeyw	'Printer',dest_printer
	mkeyw	'Screen',dest_screen

seoftab	db	2
	mkeyw	'Ctrl-Z',1
	mkeyw	'NoCtrl-Z',0

; What type of block check to use
blktab	db	4
	mkeyw	'1-char-checksum',1
	mkeyw	'2-char-checksum',2
	mkeyw	'3-char-CRC-CCITT',3
	mkeyw	'Blank-free-2','B'-'0'

modtab	db	3				; Mode line status
	mkeyw	'off',0
	mkeyw	'on',1
	mkeyw	'on (owned by host)',2

ontab	db	2
	mkeyw	'off',0
	mkeyw	'on',1

unkctab db	2			; unknown character-set disposition
	mkeyw	'keep',0
	mkeyw	'cancel',1

logsta	db	8			; Log Status table
	mkeyw	'off',logoff		; suspended or no logging
	mkeyw	'Packet',logpkt
	mkeyw	'Session',logses
	mkeyw	'Packet+Session',logpkt+logses
	mkeyw	'Transaction',logtrn
	mkeyw	'Packet+Transaction',logpkt+logtrn
	mkeyw	'Session+Transaction',logses+logtrn
	mkeyw	'Packet+Session+Transaction',logpkt+logses+logtrn

dissta	db	6			; Status of Display mode
	mkeyw	'Quiet, 7-bit',dquiet
	mkeyw	'Regular, 7-bit',dregular
	mkeyw	'Serial, 7-bit',dserial
	mkeyw	'Quiet, 8-bit',dquiet+d8bit
	mkeyw	'Regular, 8-bit',dregular+d8bit
	mkeyw	'Serial, 8-bit',dserial+d8bit

endistab db	2			; Server ENABLE/DISABLE status
	mkeyw	'enabled',0
	mkeyw	'disabled',1

inactb	db	2				; Set Input Timeout Action
	mkeyw	'Proceed',0			;[jrs]
	mkeyw	'Quit',1			;[jrs]

incstb	db	2				;[jrs] Set Input Case
	mkeyw	'Ignore',0
	mkeyw	'Observe',1

pathtab	db	3			; SET SEND/RECEIVE PATHNAMES
	mkeyw	'off',0
	mkeyw	'relative',1
	mkeyw	'absolute',2

				; Statistics data storage area
fsta	statinfo <>		; for last operation values
ssta	statinfo <>		; for session values
sflag	db	0		; flag for send (1) or receive (0)
				;   80h = begtim started

statmsg	db   cr,lf,lf,'                               Last Transfer         '
	db	' Entire Session'
	db	cr,lf,'   Item                      Sent       Rec''d       '
	db	' Sent       Rec''d',cr,lf,'$'
fchmsg	db	cr,lf,' File characters:    $'
spmsg	db	cr,lf,' Comms port chars:   $'
pktmsg	db	cr,lf,' Packets:            $'
nakmsg	db	cr,lf,' NAKs:               $'
retmsg	db	cr,lf,' Packet retries:     $'
timemsg	db   cr,lf,lf,' Protocol time, secs:$'
chpsmsg	db	cr,lf,' File characters/sec:$'
spedmsg	db	cr,lf,' Comms port bits/sec:$'
filemsg1 db	' File chars/sec: $'
filemsg2 db	'  Efficiency ($'
filemsg3 db	' b/s): $'
sndmsg	db	'Sent ',0
rcvmsg	db	'Recv ',0
kind_text db	'TEXT$'
kind_binary db	'BINARY$'
date	db	'00:00:00 00 Jan 1980, ',0
datelen	equ	$-date-1
atmsg	db	cr,lf,'  at '
atlen	equ	$-atmsg
fasmsg	db	' as '
faslen	equ	$-fasmsg
fsucmsg	db	'completed, ',0
fbadmsg	db	'failed, ',0
fintmsg	db	'interrupted',0
bytesmsg db	'bytes: ',0
streamstat db	' Streaming used$'
				; attributes msgs shared with msssen/mssrcv
ferbyte	db	'file_size',0		; '1' and '!'
ferdate db	'date/time',0		; '#'
ferdisp	db	'file_disposition:',0	; '+'
fertype	db	'file_type',0		; '"'
ferchar	db	'transfer_char-set',0	; '*'
fername	db	'filename_collision',0 	; '?'
ferunk	db	'unknown_reason',0	; other attributes
commamsg db	', '

months	db	'JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP'
	db	'OCT','NOV','DEC'
	even
tens	dd	1,10,100,1000,10000,100000,1000000,10000000,100000000
	dd	1000000000
tenslen	equ	($-tens) / 4	; number of double words in array tens
lnoutsep db	0		; non-zero to separate thousands in lnout
				; end statistics data area
sixty	dw	60
ten	dw	10

logmsg	db	'Kind         Default filename          Status$'
nologmsg db	'(not active)$'
lsesmsg	db	'Session       (Session.log)$'
lpktmsg	db	'Packets       (Packet.log)$'
ltramsg	db	'Transactions  (Transact.log)$'
dmpmsg	db	'Screen Dump, in Connect mode$'
dmpmsg2	db	'Dump screen: $'	; for general STATUS display
prnmsg	db	'Printer name, in Connect mode: $'
modst	db	'Mode-line: $'
locst	db	'Local echo: $'
duphlf	db	'Duplex: half$'
dupful	db	'Duplex: full$'
belon	db	'Ring bell after transfer$'
beloff	db	'No bell after transfer$'
vtemst	db	'Terminal type: $'		; terminal emulator
portst	db	'Communications port: $'
capmsg	db	'Logging: $'
eofmsg	db	'EOF mode: $'
flost	db	'No flow control used$'
floxmsg	db	'Flow control: xon/xoff $'
flost1	db	'Flow control: $'
handst	db	'Handshake character: $'
destst	db	'Destination: $'
xtypmsg	db	'File Type: $'
xchmsg	db	'Transfer char-set: $'
xchmsg1	db	'Transfer locking-shift: $'
xchmsg2	db	'Transfer translation: $'
xchmsg3 db	'Transfer mode sensing: $'
xcrcmsg	db	'Transfer CRC: $'
chmsg	db	'File char set: $'
unkmsg	db	'Unknown-char-set: $'
diskst	db	'Dir: $'
blokst	db	'Block check used: $'
sqcst	db	'Send control char prefix: $'
rqcst	db	'Receive control char prefix: $'
debon	db	'Debug: $'
flwon	db	'Collision (file name): $'
parmsg	db	'Parity: $'
abfst	db	'Incomplete file: $'
repst	db	'Repeat count char: $'
rptqena db	'  on',0			; Repeat count enable/disable
rptqdis db	'  off',0			; which much be ASCIIZ
sndmsg1	db	'Send Delay: $'
sndmsg2	db	' sec, Pause: $'
sndmsg3	db	' ms$'
msohst	db	'Start-of-Packet char S: ',5eh,'$'
meolst	db	'End-of-Packet char   S: ',5eh,'$'
msrec	db	'  R: ',5eh,'$'
msrecv	db	'  R: $'
tmost	db	'Timeout (seconds)    S: $'
stimst	db	'Send timeout (seconds): $'
rtimst	db	'Receive timeout (seconds): $'
spakst	db	'Send packet size (maximum): $'
rpakst	db	'Receive packet size (maximum): $'
spakst1	db	'Send packet size (current): $'
rpakst1	db	'Receive packet size (current): $'
snpdst	db	'Number of padding chars S: $'
spadst	db	'Padding char S: ',5eh,'$'
retrymsg db	'Retry send/receive packet limit: $'
swinst	db	'Sliding window slots (max): $'
strmmsg db	'Streaming: $'
dispst	db	'Display: $'
timmsg	db	'Timer: $'
srvmsg	db	'Timeout (sec) waiting for a transaction: $'
dblmsg	db	'Send double-char: $'
escmes	db	'Escape character: $'
exitmes	db	'Exit warning: $'
scpmsg	db	'Script commands Echo, If, Input, Minput, Output, Pause,'
	db	' Reinput,'
	db	cr,lf,'   Transmit, and Wait$'
sechmsg	db	'Input echoing: $'
sfiltmsg db	'Filter-echo: $'
scasmsg	db	'Case sensitivity: $'
stmo1msg db	'Timeout (seconds): $'
stmo2msg db	'Timeout-action: $'
sxfilmsg db	'Transmit fill-empty-line: $'
sxlfmsg db	'Transmit line-feeds-sent: $'
sxpmtmsg db	'Transmit prompt character: $'
sxpaumsg db	'Transmit pause (millisec): $'
stbufmsg db	'INPUT-buffer-length: $'
stinbmsg db	'INPUT-BUFFER follows:$'
opacemsg db	'Output Pacing (millisec): $'
takecmsg db	'Take echo: $'
takermsg db	'Take error: $'
macermsg db	'Macro error: $'
atton	db	'Attributes packets: $'
sachmsg	db	'  Character-set: $'
sadtmsg	db	'  Date-Time: $'
salnmsg	db	'  Length: $'
satymsg	db	'  Type: $'
baudrt	db	'Speed: $'
unrec	db	'unknown$'
kbdmsg	db	'Keyboard translation: $'
stcntmsg db	'Take/Macro COUNT: $'
stargmsg db	'Take/Macro ARGC: $'
nonemsg	db	'not active$'
sterlmsg db	'Errorlevel: $'
stalrmsg db	'Alarm time: $'
lusrmsg	db	'Login Username: $'
ssndmsg	db	'Send pathnames: $'
srcvmsg	db	'Receive pathnames: $'
servmsg	db	'Server commands available to remote user: $'
sdefmsg	db	'ASSIGN: $'
sbyemsg	db	'BYE:    $'
scwdmsg	db	'CD/CWD: $'
sdelmsg	db	'DELETE: $'
sdirmsg	db	'DIR:    $'
sfinmsg	db	'FINISH: $'
sgetmsg	db	'GET:    $'
shstmsg	db	'HOST:   $'
skermsg	db	'KERMIT: $'
slogmsg	db	'LOGIN:  $'
smsgmsg	db	'MESSAGE:$'
sprtmsg	db	'PRINT:  $'
sqrymsg	db	'QUERY:  $'
sretmsg	db	'RETRIEVE: $'
sspcmsg	db	'SPACE:  $'
stypmsg	db	'TYPE:   $'
stekmsg	db	'Term Tek4010 (auto-entry): $'
nonmsg	db	'none$'
onmsg	db	'on'
offmsg	db	'off'
moremsg	db	cr,lf,'-- More -- press space for more,'
	db	' q or Control-C to quit. $'
rxoffmsg db	cr,lf,'  Input Translation is off$'
rxonmsg	db	cr,lf,'  Input Translation is on$'

shormsg	db	cr,lf,'  Translation table of received byte codes while'
	db	' in CONNECT mode -'
	db	cr,lf,'  Format: [received byte (decimal) -> local byte'
	db	' (decimal)]',cr,lf,'$'
shopm1	db	' [\$'			; Show Translation material
shopm2	db	' -> \$'
shopm3	db	'] $'
shom9m1	db	cr,lf,' Free space (bytes) for names: $'
shom9m3	db	cr,lf,' No macro(s)$'
memmsg1	db	cr,lf,' DOS free memory (bytes):$'
memmsg2	db	cr,lf,' Total free bytes: $'
varstng	db	' \v($'
cntlmsg1 db	cr,lf,lf,' Unprefixed control codes (sent as-is without'
	db	' protective prefixing):',cr,lf,' $'
cntlmsg2 db	cr,lf,lf,' Prefixed control codes (includes 127, 255, and'
	db	' packet start/end):',cr,lf,' $'
prterr	db	'?Unrecognized value$'
lpktnam	db	'Packet.log',54 dup (0)	; default packet log filename
lsesnam	db	'Session.log',54 dup (0); default capture/session filename
ltranam	db	'Transact.log',52 dup (0); default transaction log filename
dmpname	db	'Kermit.scn',54 dup (0)	; file name for screen dumps
prnname	db	'PRN',61 dup (0)	; file name for printer
fsharr1	db	cr,lf,'Declared arrays:',cr,lf,'$'
fsharr2	db	']',cr,lf,'$'
	even
stent	struc			; structure for status information table sttab
sttyp	dw	?		; type (actually routine to call)
msg	dw	?		; message to print
val2	dw	?		; needed value: another message, or tbl addr
tstcel	dw	?		; address of cell to test, in data segment
basval	dw	0		; base value, if non-zero
stent	ends

sttab	stent	<baudprt>				; STATUS
	stent	<srchkww,vtemst,termtb,flags.vtflg>	; terminal emulator
	stent	<srchkw,portst,comptab,flags.comflg>
	stent	<srchkw,modst,modtab,flags.modflg>
	stent	<srchkw,parmsg,partab,parflg,portval>
	stent	<stlnum,spakst,,dtrans.slong>
	stent	<onoff,locst,,ecoflg,portval>
	stent	<stlnum,rpakst,,dtrans.rlong>
	stent	<srchkw,flost1,flotab,floflg,portval>
	stent	<prsar,msohst,msrec,trans.ssoh,trans.rsoh>
	stent	<prhnd>
	stent	<prsar,meolst,msrec,trans.seol,trans.reol>
	stent	<msg2,dupful,duphlf,duplex,portval>
	stent	<prsarv,tmost,msrecv,dtrans.stime,trans.rtime>
	stent	<drnum,diskst,,curdsk>
	stent	<stnum,retrymsg,,maxtry>
	stent	<srchkw,flwon,warntab,flags.flwflg>
	stent	<srchkw,blokst,blktab,dtrans.chklen>
	stent	<srchkw,destst,destab,flags.destflg>
	stent	<srchkw,capmsg,logsta,flags.capflg>
	stent	<srchkw,abfst,abftab,flags.abfflg>
	stent	<srchkw,debon,logsta,flags.debug>
	stent	<srchkw,dispst,dissta,flags.remflg>
	stent	<onoff,timmsg,,flags.timflg>
	stent	<onechr,escmes,,trans.escchr>
	stent	<srchkw,kbdmsg,ontab,flags.xltkbd>
;;;	stent	<vtstat>
	dw	0				; end of table

stcom	stent	<srchkw,portst,comptab,flags.comflg>	; SHOW COMMS
	stent	<baudprt>
	stent	<onoff,locst,,ecoflg,portval>
	stent	<srchkw,parmsg,partab,parflg,portval>
	stent	<prhnd>
	stent	<srchkw,flost1,flotab,floflg,portval>
	stent	<msg2,dupful,duphlf,duplex,portval>
	stent	<srchkw,dispst,dissta,flags.remflg>
	stent	<srchkw,debon,logsta,flags.debug>
	stent	<srchkw,exitmes,ontab,flags.exitwarn>
	dw	0

stfile	stent	<drnum,diskst,,curdsk>			; SHOW FILE
	stent	<srchkw,abfst,abftab,flags.abfflg>
	stent	<srchkw,destst,destab,flags.destflg>
	stent	<srchkw,flwon,warntab,flags.flwflg>
	stent	<srchkw,eofmsg,seoftab,flags.eofcz>
	stent	<srchkww,chmsg,setchtab,flags.chrset>
	stent	<srchkw,xtypmsg,xftyptab,dtrans.xtype>
	stent	<srchkw,xchmsg,xfchtab,dtrans.xchset>
	stent	<msg2,beloff,belon,flags.belflg>
	stent	<srchkw,xchmsg2,xfertab2,dtrans.xchri>
	stent	<stmsg,atton>
	stent	<srchkw,xchmsg1,xfertab1,dtrans.lshift>
	stent	<srchkb,sachmsg,ontab,attchr,flags.attflg>
	stent	<srchkw,unkmsg,unkctab,flags.unkchs>
	stent	<srchkb,sadtmsg,ontab,attdate,flags.attflg>
	stent	<stmsg,spaces>
	stent	<srchkb,salnmsg,ontab,attlen,flags.attflg>
	stent	<stmsg,spaces>
	stent	<srchkb,satymsg,ontab,atttype,flags.attflg>
	dw	0

stlog	stent	<stmsg,logmsg>				; SHOW LOG
	stent	<stmsg,lpktmsg>
	stent	<msg2b,nologmsg,lpktnam,logpkt,flags.capflg>
	stent	<stmsg,lsesmsg>
	stent	<msg2b,nologmsg,lsesnam,logses,flags.capflg>
	stent	<stmsg,ltramsg>
	stent	<msg2b,nologmsg,ltranam,logtrn,flags.capflg>
	stent	<stmsg,dmpmsg>
	stent	<stmsg,dmpname>
	stent	<stmsg,prnmsg>
	stent	<stmsg,prnname>
	dw	0

stpro	stent	<stlnum,spakst,,dtrans.slong>		; SHOW PROTOCOL
	stent	<stlnum,rpakst,,dtrans.rlong>
	stent	<stlnum,spakst1,,trans.slong>
	stent	<stlnum,rpakst1,,trans.rlong>
	stent	<stnum,stimst,,dtrans.stime>
	stent	<stnum,rtimst,,trans.rtime>
	stent	<onechr,sqcst,,dtrans.squote>
	stent	<onechr,rqcst,,trans.rquote>
	stent	<srchkw,ssndmsg,pathtab,sndpathflg>
	stent	<srchkw,srcvmsg,pathtab,rcvpathflg>
	stent	<prsar,msohst,msrec,trans.ssoh,trans.rsoh>
	stent	<prsarv,snpdst,msrecv,dtrans.spad,trans.rpad>
	stent	<prsar,meolst,msrec,trans.seol,trans.reol>
	stent	<prsar,spadst,msrec,dtrans.spadch,trans.rpadch>
	stent	<onechr,dblmsg,,dtrans.sdbl>
	stent	<rptstat,repst>
	stent	<prsnd,sndmsg1>
	stent	<srchkw,blokst,blktab,dtrans.chklen>
	stent	<stnum,retrymsg,,maxtry>
	stent	<stnum,swinst,,dtrans.windo>
	stent	<prhnd>
	stent	<srchkw,strmmsg,ontab,streaming>
	stent	<onoff,timmsg,,flags.timflg>
	stent	<srchkw,xtypmsg,xftyptab,dtrans.xtype>
	stent	<srchkw,capmsg,logsta,flags.capflg>
	stent	<srchkw,xtypmsg,xftyptab,dtrans.xtype>
	stent	<srchkw,debon,logsta,flags.debug>
	stent	<srchkww,chmsg,setchtab,flags.chrset>
	stent	<stmsg,atton>
	stent	<srchkw,xchmsg,xfchtab,dtrans.xchset>
	stent	<srchkb,sachmsg,ontab,attchr,flags.attflg>
	stent	<srchkw,xchmsg2,xfertab2,dtrans.xchri>
	stent	<srchkb,sadtmsg,ontab,attdate,flags.attflg>
	stent	<srchkw,xchmsg1,xfertab1,dtrans.lshift>
	stent	<srchkb,salnmsg,ontab,attlen,flags.attflg>
	stent	<srchkw,xchmsg3,xfertab3,dtrans.xmode>
	stent	<srchkb,satymsg,ontab,atttype,flags.attflg>
	stent	<srchkw,xcrcmsg,ontab,dtrans.xcrc>
	dw	0

stscpt	stent	<stmsg,scpmsg>				; SHOW SCRIPT
	stent	<onoff,sechmsg,,script.inecho>
	stent	<srchkw,scasmsg,incstb,script.incasv>
	stent	<onoff,sfiltmsg,,script.infilter>
	stent	<stalr,stalrmsg>
	stent	<srchkw,stmo2msg,inactb,script.inactv>
	stent	<stlnum,stmo1msg,,script.indfto>
	stent	<prfil>
	stent	<starg,stargmsg>
	stent	<onoff,sxlfmsg,,script.xmitlf>
	stent	<stcnt,stcntmsg>
	stent	<stlnum,sxpaumsg,,script.xmitpause>
	stent	<srchkw,takecmsg,ontab,flags.takflg>
	stent	<onechr,sxpmtmsg,,script.xmitpmt>
	stent	<srchkw,takermsg,ontab,takeerror>
	stent	<stlnum,opacemsg,,outpace>
	stent	<srchkw,macermsg,ontab,macroerror>
	stent	<stlnum,stbufmsg,,scpbuflen>
	stent	<stnum,sterlmsg,,errlev>
	stent	<stmsg,stinbmsg>
	stent	<stinbuf>
	dw	0

stserv	stent	<pasz,lusrmsg,offset luser>		; SHOW SERVER
	stent	<stmsg,servmsg>
	stent	<srchkb,sdefmsg,endistab,defflg,denyflg>
	stent	<srchkb,skermsg,endistab,kerflg,denyflg>
	stent	<srchkb,sbyemsg,endistab,byeflg,denyflg>
	stent	<srchkb,slogmsg,endistab,pasflg,denyflg>
	stent	<srchkb,scwdmsg,endistab,cwdflg,denyflg>
	stent	<srchkb,smsgmsg,endistab,sndflg,denyflg>
	stent	<srchkb,sdelmsg,endistab,delflg,denyflg>
	stent	<srchkb,sprtmsg,endistab,prtflg,denyflg>
	stent	<srchkb,sdirmsg,endistab,dirflg,denyflg>
	stent	<srchkb,sqrymsg,endistab,qryflg,denyflg>
	stent	<srchkb,sfinmsg,endistab,finflg,denyflg>
	stent	<srchkb,sretmsg,endistab,retflg,denyflg>
	stent	<srchkb,sgetmsg,endistab,getsflg,denyflg>
;; OLD	stent	<srchkb,sspcmsg,endistab,spcflg,denyflg>
	stent	<srchkb,stypmsg,endistab,typflg,denyflg>
	stent	<srchkb,shstmsg,endistab,hostflg,denyflg>
	dw	0
stserv2	stent	<stnum,srvmsg,,srvtmo>
	dw	0
ifndef	no_terminal
stterm	stent	<srchkww,vtemst,termtb,flags.vtflg>	; SHOW TERMINAL
	stent	<srchkw,dispst,dissta,flags.remflg>
	stent	<srchkw,modst,modtab,flags.modflg>
	stent	<onechr,escmes,,trans.escchr>
ifndef	no_graphics
	stent	<srchkb,stekmsg,endistab,tekxflg,denyflg>
endif	; no_graphics
	stent	<srchkw,kbdmsg,ontab,flags.xltkbd>
	stent	<vtstat>
	dw	0
endif	; no_terminal

shorxk	stent	<srchkw,kbdmsg,ontab,flags.xltkbd>
	stent	<stmsg,spaces>
	dw	0
data	ends

data1	segment
shmmsg	db	' name of macro, or press ENTER to see all$'
shvmsg	db	' name of \v(name) variable, or press ENTER to see all$'
data1	ends

code1	segment
	extrn	fwrtdir:far, fcsrtype:far, prtscr:far, strlen:far
	extrn	prtasz:far, dec2di:far, domath:far, decout:far
	extrn	buflog:far
code1	ends

code	segment
	extrn	comnd:near, locate:near
	extrn	getbaud:near, vtstat:near, shomodem:near, nvaltoa:near
	extrn	cmblnk:near, putmod:near, clrmod:near
	extrn	poscur:near, clearl:near, nout:near, dodec:near
ifndef	no_network
	extrn	shownet:near
endif	; no_network

	assume	cs:code, ds:data, es:nothing

flnout	proc	far
	call	lnout
	ret
flnout	endp
flnouts	proc	far
	call	lnouts
	ret
flnouts	endp
fnvaltoa proc	far
	call	nvaltoa
	ret
fnvaltoa endp
fclearl	proc	far
	call	clearl
	ret
fclearl	endp
fposcur	proc	far
	call	poscur
	ret
fposcur	endp
; Display asciiz message pointed to by DS:DX on Last error line
ERMSG	PROC	NEAR
	test	flags.remflg,dquiet	; quiet screen?
	jnz	ermsgx			; nz = yes
	push	si			; position cursor to Last Error line
	push	dx			; save preexisting message pointer
	test	flags.remflg,dserial	; serial mode display?
	jnz	erpo1			; nz = yes
	cmp	fmtdsp,0		; formatted display?
	jne	erpo2			; ne = yes
erpo1:	mov	ah,prstr
	mov	dx,offset erword	; put out word Error:
	int	dos
	jmp	short erpo3
erpo2:	mov	dx,screrr
	call	poscur
	call	clearl			; clear the line
erpo3:	pop	dx			; restore old pointer
	mov	si,dx			; string pointer
	mov	cx,10			; try ten items
	cld
ermsg1:	lodsb
	cmp	al,' '			; strip these leading spaces
	loope	ermsg1
	dec	si			; backup to non-space
	push	dx			; preserve caller's dx
	mov	dx,si
	call	prtasz			; display asciiz message
	pop	dx
	pop	si
ermsgx:	ret
ERMSG	ENDP

; Decode and display Message packet pointed to by SI.
MSGMSG	PROC	NEAR
	mov	decbuf,0		; clear output buffer for rem query
	call	dodec			; decode to decbuf, SI is pktinfo ptr
	test	flags.remflg,dquiet	; quiet screen?
	jnz	msgmsgx			; nz = yes
	cmp	[si].datlen,0		; anything present?
	je	msgmsgx			; e = no
	test	flags.remflg,dserial	; serial mode display?
	jnz	msgms1			; nz = yes
	cmp	fmtdsp,0		; formatted display?
	jne	msgms2			; ne = yes
	cmp	flags.xflg,0		; packet header seen?
	je	msgms2			; e = no
msgms1:	mov	ah,prstr
	mov	dx,offset msword	; put out word Message:
	int	dos
	jmp	short msgms3		; display the message
msgms2:	push	si
	mov	dx,scrmsg		; Last message line
	call	poscur
	call	clearl			; clear the line
	pop	si
msgms3:	mov	dx,offset decbuf	; final error message string, asciiz
	call	prtasz			; display asciiz message
msgmsgx:ret
MSGMSG	ENDP

; Show number of retries message

RTMSG	PROC 	NEAR
	test	flags.remflg,dquiet	; quiet display mode?
	jnz	rtmsx			; nz = yes
	test	flags.remflg,dserver	; in server mode?
	jnz	rtms0			; nz = yes
	cmp	flags.xflg,0		; receiving to screen?
	jne	rtmsx			; ne = yes
	cmp	fmtdsp,0		; formatted display?
	je	rtms1			; e = no, do as normal
rtms0:	test	flags.remflg,dserial	; serial mode display?
	jnz	rtms1			; nz = yes
	push	ax
	push	dx
	push	si
	mov	dx,scrnrt
	call	poscur
	call	clearl
	pop	si
	jmp	short rtms3
rtms1:	push	ax
	push	dx
	mov	dx,offset rtword	; display word Retry
	mov	ah,prstr
	int	dos
rtms3:	mov	ax,fsta.pretry		; number of retries
	call	decout			; write the number of group retries
	pop	dx
	pop	ax
rtmsx:	ret
RTMSG	ENDP

; Reassure user that we acknowledge his ^X/^Z

INTMSG	PROC	NEAR
	cmp	flags.cxzflg,0		; anything there?
	je	int1			; e = no
	test	flags.remflg,dserver	; server mode?
	jnz	int4			; nz = yes
	cmp	flags.xflg,0		; writing to screen?
	jne	int1			; ne = yes, nothing to do
int4:	test	flags.remflg,dquiet	; quiet screen?
	jnz	int1			; yes, suppress msg
	test	flags.remflg,dserial	; serial mode display?
	jz	int2			; z = no
	cmp	fmtdsp,0		; formatted screen?
	jne	int2			; ne = yes
	mov	dx,offset crlf		; output initial cr/lf
	mov	ah,prstr
	int	dos
	jmp	short int3		; display the message
int2:	mov	dx,scrmsg		; last message position
	call	poscur
	call	clearl
int3:	mov	dx,offset infms7	; File interrupted
	cmp	flags.cxzflg,'X'	; File interrupt? 
	je	int0			; e = yes
	mov	dx,offset infms8	; File group interrupted
	cmp	flags.cxzflg,'Z'	; correct?
	je	int0			; e = yes
	mov	dl,flags.cxzflg		; say Control ^letter interrupt
	mov	infms9+6,dl		; store interrupt code letter
	mov	dx,offset infms9
int0:   mov	ah,prstr
        int	dos
int1:	ret
INTMSG	ENDP

;  Clear Last error and Last message lines
cxerr:	mov	temp,0			; say last error line
	jmp	short cxcomm		; do common code

CXMSG	PROC	NEAR
	mov	temp,1			; say last message line

cxcomm:	test	flags.remflg,dserver	; server mode?
	jnz	cxm1			; nz = yes
	cmp	flags.xflg,0		; Writing to screen?
	jne	cxm0			; ne = yes
cxm1:	cmp	fmtdsp,0		; formatted display?
	je	cxm0			; e = no
	push	dx
	push 	si
	mov	dx,screrr		; Last Error postion
	cmp	temp,0			; do last error line?
	je	cxm2			; e = yes
	mov	dx,scrmsg		; Last Message position
cxm2:	call	poscur
	call	clearl
	pop	si
	pop	dx
cxm0:	ret
CXMSG	ENDP

;  Clear out the old filename on the screen. 

CLRFLN	PROC	FAR
	test	flags.remflg,dquiet 	; quiet display?
	jnz	clrflnx			; nz = yes
	test	flags.remflg,dserial	; serial display mode?
	jnz	clrfln1			; nz = yes, use just cr/lf
	cmp	fmtdsp,0		; formatted display?
	je	clrfln1			; e = no
	mov	dx,scrfln
	call	poscur
	call	clearl			; clear to end of line
	ret
clrfln1:push	ax			; for serial display, does cr/lf
	mov	ah,prstr
	mov	dx,offset crlf
	int	dos
	pop	ax
clrflnx:ret
CLRFLN	ENDP

			; display packet quantity and size, SI has pkt ptr
PKTSIZE	PROC	NEAR
	push	ax
	push	dx
	push	si
	cmp	fmtdsp,0		; formatted display?
	je	pktsiz2			; e = no, no display
	mov	ax,[si].datlen		; packet size (data part)
	cmp	trans.chklen,'B'-'0'	; this special case?
	jne	pktsiz4			; ne = no
	add	al,2			; special case is two byte chksum
	jmp	short pktsiz5
pktsiz4:add	al,trans.chklen		; plus checksum
pktsiz5:adc	ah,0
	cmp	ax,prepksz		; same as previous packet?
	je	pktsiz2			; e = yes, skip display of size
	push	ax
	mov	dx,scrsz		; position cursor
	call	poscur
	pop	ax
	mov	prepksz,ax		; remember new value
	add	ax,2			; plus SEQ, TYPE
	cmp	ax,94			; larger than Regular?
	jbe	pktsiz1			; be = no
	add	ax,3			; add Long Packet len and chksum
pktsiz1:call	decout			; show packet length
	mov	ah,prstr
	mov	dx,offset blanks	; spaces to clear old material
	int	dos
					; number of packets part
pktsiz2:test	flags.remflg,dquiet	; quiet screen?
	jnz	pktsiz3			; nz = yes
	call	nppos			; number of packets sent
	mov	ax,numpkt		; number of packets
	call	nout			; write the packet number
pktsiz3:pop	si
	pop	dx
	pop	ax
	ret
PKTSIZE	ENDP

; some random screen positioning functions, all near callable only
kbpos:	mov	dx,scrkb		; KBytes transferred
	cmp	fmtdsp,0		; formatted display?
	jne	setup2			; ne = yes
	ret				; else ignore postioning request
perpos:	mov	dx,scrper		; Percent transferred
	cmp	fmtdsp,0		; formatted display?
	jne	setup2			; ne = yes
	ret				; else ignore postioning request
frpos:	mov	dx,scrmsg		; say renamed file
	jmp	short setup2
stpos:	mov	dx,scrst		; status of file transfer
	jmp	short setup2
nppos:	mov	dx,scrnp		; Number of packets sent
	cmp	fmtdsp,0		; formatted display?
	jne	setup2			; ne = yes
	ret
rprpos:	test	flags.remflg,dserial+dquiet ; reprompt position
	jnz	rprpos1			; nz = no mode line for these
	cmp	fmtdsp,0		; formatted display?
	je	rprpos1			; e = no, so no mode line
	call	clrmod			; clear mode line
rprpos1:mov	dx,scrrpr		; Reprompt position
	call	setup2			; position cursor
	mov	fmtdsp,0		; turn off formatted display flag
	ret
sppos:	mov	dx,scrsp		; Debug Send packet location
	jmp	short setup1
rppos:	mov	dx,scrrp		; Debug Receive packet location
	jmp	short setup1
				; common service routines for positioning
setup1:	test	flags.remflg,dquiet+dserial; quiet or serial display mode?
	jnz	setupa			; nz = yes
	cmp	fmtdsp,0		; non-formatted display?
	je	setupa			; e = yes
	call	poscur
	ret
setup2:	test	flags.remflg,dquiet+dserial; quiet or serial display mode?
	jnz	setupa			; nz = yes
	cmp	fmtdsp,0		; non-formatted display?
	je	setupa			; e = yes
	call	poscur			; no
	call	clearl
	ret
setupa: test	flags.remflg,dquiet	; quiet mode?
	jnz	setupx			; nz = yes, do nothing
	push	ax			; display cr/lf and return
	push	dx
	mov	dx,offset crlf
	mov	ah,prstr
	int	dos
	pop	dx
	pop	ax
setupx:	ret

; Initialize formatted screen
 
INIT	PROC	NEAR
	mov	windflag,0		; init windows in use display flag
	test	flags.remflg,dquiet	; quiet display mode?
	jnz	init4			; nz = yes
	test	flags.remflg,dserver	; server mode?
	jnz	init1			; nz = yes
	cmp	flags.xflg,0		; destination is screen
	jne	init4			; ne = yes
init1:	test	flags.remflg,dserial	; serial mode display?
	jnz	init3			; nz = yes

	xor	al,al			; cursor off code is zero
	call	fcsrtype		; turn off PC cursor (IBM-PC dep)

	call	cmblnk			; clear the screen
	mov	dx,offset cxzhlp
	call	putmod			; write mode line
	mov	fmtdsp,1		; say doing formatted display
	test	flags.remflg,dserver	; server mode?
	jz	init2			; z = no
	mov	dx,scrser		; move cursor to top of screen
	call	poscur
	mov	ah,prstr
	mov	dx,offset infms1	; say now in server mode
	int	dos
init2:	call	locate
	mov	ah,prstr		; put statistics headers on the screen
	mov	dx,offset outlin1
	int	dos
	mov	dx,offset verident
	int	dos
	mov	dx,offset outlin2
	int	dos
	mov	wrpmsg,0		; haven't printed the messsage yet
	mov	prepksz,0		; set previous packet size to zero
	push	es
	mov	di,seg templp
	mov	es,di
	mov	di,offset templp	; 65 byte buffer from mssfil
	call	fwrtdir			; fill with drive:path
	pop	es
	mov	dx,scrpath
	call	poscur			; set cursor
	mov	dx,offset templp	; show string
	call	prtasz
	ret
init3:	mov	ah,prstr
	mov	dx,offset cxzser	; status line as a text string
	int	dos
init4:	mov	wrpmsg,1		; suppress display of percentage msg
	mov	fmtdsp,0		; say doing unformatted display
	ret
INIT	ENDP

; show number of Kilobytes transferred
; modifies ax
kbpr	proc	near
	test	flags.remflg,dquiet	; quiet display mode?
	jnz	kbpr1			; nz = yes, no printing
	push	bx
	mov	ax,tfilsz		; low order word
	mov	bx,tfilsz+2		; high order word
	add	ax,512			; round up, add half the denominator
	adc	bx,0
	rcr	bx,1			; divide double word by 1024,
	rcr	ax,1			; by dword shift right 10
	rcr	bx,1
	rcr	ax,1
	mov	al,ah
	mov	ah,bl			; ax has the result
	pop	bx
	cmp	ax,oldkbt		; is it the same?
	je	kbpr1			; yes, skip printing
	mov	oldkbt,ax		; save new # of kb
	push	ax
	mov	dx,scrkb
	call	poscur			; position the cursor
	pop	ax
	call	decout			; print number of KBytes transferred
	mov	ah,prstr
	mov	dx,offset blanks	; trim off old trailing junk
	int	dos
kbpr1:	ret
kbpr	endp	

; show percent transferred
; modifies ax
perpr	proc	near
	test	flags.remflg,dquiet	; quiet display mode?
	jz	perpr1			; z = no. allow printing
	ret				; skip printing in remote mode
perpr1:	cmp	diskio.sizehi,0		; high word of original file size > 0 ?
	jne	perpr3			; ne = yes, use big file code
	cmp	diskio.sizelo,0		; anything here at all?
	jne	perpr2			; ne = yes, use small file code
	mov	wrpmsg,0		; init flag, prime to clear display
	ret				; otherwise, quit now
perpr2:	push	cx			; case for files < 64 Kb
	push	dx
	mov	ax,diskio.sizelo	; original size (low word)
	mov	denom,ax
	mov	dx,tfilsz+2		;transferred size times 256 in [dx,ax]
	mov	ax,tfilsz
	mov	dh,dl			; whole value multiplied by 256
	mov	dl,ah
	mov	ah,al
	xor	al,al
	mov	cx,denom		; round up, add half the denominator
	shr	cx,1
	add	ax,cx
	adc	dx,0
	div	denom			; (256*xfer)/orig. ax = quo, dx = rem
	mul	onehun			; multiply quotient above by 100
	mov	al,ah			; divide result (ax) by 256
	xor	ah,ah			; percentage is in ax
	jmp	short perpr5		; finish in common code

perpr3:	cmp	byte ptr diskio.sizehi+1,0 ; file > 16MB? (> 3 bytes)
	jne	perpr4			; ne = yes, use biggest code
	push	cx			; case for file size > 64 KB (3 bytes)
	push	dx
	mov	ax,diskio.sizelo	; original file size low order word
	mov	al,ah			; divide by 256
	xor	ah,ah			; clear ah		
	mov	dx,diskio.sizehi	; high order word
	xchg	dh,dl			; divide by 256
	xor	dl,dl			; clear low bits
	or	ax,dx			; paste together the two parts into ax
	mov	denom,ax		; denom = original size divided by 512
	mov	dx,tfilsz+2		; high order word of transferred size
	mov	ax,tfilsz		; low order word
	mov	cx,denom		; round up, add half the denominator
	shr	cx,1
	add	ax,cx
	adc	dx,0
	div	denom			; xfer/(orig/256). ax=quot, dx=rem
	mul	onehun			; times 100 for 256*percentage, in ax
	mov	al,ah			; divide ax by 256
	xor	ah,ah
	jmp	short perpr5		; finish in common code

perpr4:	push	cx			; case for files > 16MB (> 3 bytes)
	push	dx
	mov	ax,tfilsz+2		; transferred size / 64K in [dx,ax]
	or	ax,ax			; anything showing yet?
	jz	perpr5			; z = no, return zero in AX
	xor	dh,dh
	mov	dl,ah
	mov	ah,al			; value multiplied by 256
	xor	al,al
	mov	cx,diskio.sizehi	; round up, add half the denominator
	shr	cx,1
	add	ax,cx
	adc	dx,0
	div	diskio.sizehi		; (256*xfer)/orig. ax = quo, dx = rem
	mul	onehun			; multiply quotient above by 100
	mov	al,ah			; divide result (ax) by 256
	xor	ah,ah			; percentage is in ax

perpr5:	cmp	ax,oldper		; same as it was before?
	je	perpr8			; yes, don't bother printing
	cmp	oldper,0		; inited yet?
	mov	oldper,ax		; remember this for next time
	jl	perpr5a			; l = needs reiniting of screen
	cmp	wrpmsg,0		; did we write the percentage message?
	jne	perpr6			; ne = yes, skip this part
perpr5a:push	ax
	call	perpos			; position cursor, clear line
	mov	dx,offset permsg
	mov	ah,prstr
	int	dos			; write out message
	mov	dx,scrper
	inc	dh			; next row
	push	dx
	xor	dl,dl
	call	setup2			; clear whole line
	pop	dx
	sub	dl,2			; backup two columns
	call	poscur			; set cursor
	mov	dx,offset perscale	; show thermometer numeric scale
	mov	ah,prstr
	int	dos
	xor	ax,ax
	call	perprwork		; write thermometer
	pop	ax
	mov	lastper,0		; last percentage done
	mov	wrpmsg,1		; init flag so we don't do it again
perpr6: push	ax
	mov	dx,scrper		; percentage top line
	inc	dh
	sub	dl,6			; below and to the left
	call	poscur			; position the cursor
	pop	ax
	cmp	ax,onehun		; > 100% ?
	jb	perpr7			; b = no, accept it
	mov	ax,onehun		; else just use 100
perpr7:	push	ax
	call	decout
	mov	dl,25h			; load a percent sign
	mov	ah,conout		; display the character
	int	dos
	pop	ax
	mov	cx,ax			; current percentage done
	xchg	al,lastper		; update last percentage done
	sub	cl,al			; minus previous percentage completed
	jle	perpr8			; le = no change
perpr7a:inc	ax			; write intervening percentages
	call	perprwork		; write thermometer
	loop	perpr7a			; do all steps
perpr8:	pop	dx
	pop	cx
	ret

perprwork:push	ax			; worker to display thermometer
	mov	dx,scrper
	inc	al			; ax is percentage done
	shr	al,1			; divide by two
	add	dl,al			; get column
	call	poscur			; position the cursor
	pop	ax
	push	ax
	mov	dl,0dch			; half block symbol (IBM-PCs)
	test	al,1
	jnz	perprw1			; nz = odd
	dec	dl			; full block symbol
perprw1:mov	ah,conout		; display the character
	int	dos
perprw2:pop	ax
	ret
perpr	endp

; Show file kind (text, binary) and character set, must preserve SI
filekind proc	near
	cmp	flags.xflg,0		; receiving to screen?
	jne	filekx			; ne = yes, skip displaying
	cmp	flags.destflg,dest_screen ; destination is screen?
	je	filekx			; e = yes
	test	flags.remflg,dregular	; regular display?
	jz	filekx			; z = no, no display
	cmp	fmtdsp,0		; formatted display?
	je	filekx			; e = no, no display here
	mov	dx,scrkind
	call	setup2			; clear to end of line
	mov	ah,prstr
	mov	dx,offset kind_text	; assume text
	cmp	trans.xtype,0		; text?
	je	filek1			; e = yes
	mov	dx,offset kind_binary	; say binary
filek1:	int	dos
	cmp	trans.xtype,0		; text?
	jne	filekx			; ne = no
	push	bx
	push	cx
	push	di
	test	sflag,1			; send operation?
	jnz	filek2			; nz = yes
	mov	al,trans.xchset		; transfer character set
	xor	ah,ah
	mov	bx,offset xfchtab	; transfer file character set table
	jmp	short filek3
filek2:	mov	bx,offset setchtab	; file character set table
	mov	ax,flags.chrset		; current char set (Code Page)
filek3:	call	filekwork
	jc	filek6			; no match
	push	di
	mov	ah,conout
	mov	dl,','			; say "text, "
	int	dos
	mov	dl,' '
	int	dos
	pop	di
	call	prtscr			; display cx counted string in ds:di

	test	sflag,1			; send operation?
	jnz	filek4			; nz = yes
	mov	bx,offset setchtab	; file character set table
	mov	ax,flags.chrset		; current char set (Code Page)
	jmp	short filek5
filek4:	mov	al,trans.xchset		; transfer character set
	xor	ah,ah
	mov	bx,offset xfchtab	; transfer file character set table
filek5:	call	filekwork
	jc	filek6			; no match
	push	di
	mov	ah,conout
	mov	dl,' '
	int	dos
	mov	dl,'t'
	int	dos
	mov	dl,'o'
	int	dos
	mov	dl,' '
	int	dos
	pop	di
	call	prtscr			; display cx counted string in ds:di
filek6:	pop	di
	pop	cx
	pop	bx
filekx:	ret
filekind endp

; Worker for filekind. Enter with BX = offset of keyword table, AX = value
; to be matched. Returns carry clear, DI = ptr to string, CX = string length,
; else returns carry set.
filekwork proc	near
	mov	cl,[bx]			; number of entries in our table
	inc	bx			; point to the data
filewk1:mov	di,[bx]			; length of keyword
	cmp	ax,[bx+di+2]		; value fields match?
	je	filewk2			; e = yes
	add	bx,di			; add word length
	add	bx,4			; skip count and value fields
	dec	cl			; more keywords to check?
	jnz	filewk1			; nz = yes, go to it
	stc				; say no match
	ret
filewk2:mov	cx,di			; string length
	mov	di,bx
	add	di,2			; transfer char set ident string
	clc				; say success
	ret
filekwork endp

; Show file characters/sec msg and value, use after calling endtim.
filecps	proc	near
	test	flags.remflg,dregular	; regular display?
	jz	filecpsx		; z = no, no display
	cmp	fmtdsp,0		; formatted display?
	je	filecpsx		; e = no, no display here
	cmp	flags.xflg,0		; receiving to screen?
	je	filecps1		; e = no
filecpsx:ret

filecps1:push	bx
	push	si
	mov	dx,scrper		; thermometer line
	inc	dh			; percentage scale line
	call	setup2			; set cursor, clear to eol
	mov	dx,offset filemsg1	; File chars per second
	mov	ah,prstr
	int	dos
	mov	bx,offset fsta		; last file structure
	test	sflag,2			; 0 for rcv, 2 for send
	jz	filecps2		; z = receive
	mov	ax,[bx].fsbyte		; file bytes sent, low
	mov	dx,[bx].fsbyte+2	;  high. [dx,ax] = total file bytes
	jmp	short filecps3
filecps2:mov	ax,[bx].frbyte		; file bytes received, low
	mov	dx,[bx].frbyte+2	; file bytes received, high
filecps3:call	far ptr fshowrk		; do worker
	mov	temp,ax			; file chars/sec
	mov	temp1,dx		; high word
	mov	cx,1
	call	far ptr fshoprt		; show result
	call	filebps			; get port speed to dx:ax
	jc	filecps8		; c = not a number
	push	ax			; comms bits/sec
	push	dx			; ditto, high part
	mov	dx,offset filemsg2	; Efficiency msg
	mov	ah,prstr
	int	dos
	mov	dx,offset rdbuf		; buffer with asciiz baud string
	call	prtasz
	mov	ah,prstr
	mov	dx,offset filemsg3
	int	dos
	mov	ax,temp1		; high order part of file chars/sec
	mov	cx,1000
	mul	cx			; times 100(%) * 10(bits/char)
	mov	bx,ax			; save low order part of product
	mov	ax,temp			; low order part of file chars/sec
	mul	cx
	add	dx,bx			; add high orders
	pop	cx			; high order part
	pop	bx			; comms b/s
filecps4:jcxz	filecps5		; z = no high order denominator part
	shr	cx,1			; divide bottom by 2
	rcr	bx,1
	shr	dx,1			; divide top by 2
	rcr	ax,1
	jmp	short filecps4		; do again if necessary
filecps5:mov	cx,bx			; set up for worker divide dx,ax / cx
	or	cx,cx
	jnz	filecps6		; avoid divide by zero
	inc	cx
filecps6:push	bx			; divide dx,ax by cx, results to dx,ax
	push	ax
	mov	ax,dx
	xor	dx,dx
	div	cx			; ax = high quo, dx = high rem
	mov	bx,ax			; save high quotient
	pop	ax
	div	cx		       ; bytes div seconds, ax = quo, dx = rem
	shl	dx,1			; prepare remainder for rounding test
	cmp	dx,cx			; round up?
	jb	filecps7		; b = no
	add	ax,1			; round up
	adc	bx,0			; ripple carry
filecps7:mov	dx,bx			; previous high quotient
	pop	bx			; 100 * file bps / (comms bits/sec)
	mov	cx,2			; field width
	call	far ptr fshoprt		; show efficiency
	mov	ah,conout
	mov	dl,'%'
	int	dos
filecps8:pop	si
	pop	bx
	ret
filecps	endp

; Worker to convert comms port bits/second to number in dx:ax
; Returns carry set if value is unkown
filebps	proc	near
	mov	bx,portval		; port pointer
	mov	ax,[bx].baud		; baud rate index to AX
	cmp	al,byte ptr bdtab	; index versus number of table entries
	jb	fileb1			; b = index is in the table
	stc				; say unknown
	ret
fileb1:	push	si
	mov	si,offset bdtab		; ascii rate table
	mov	cl,[si]			; number of entries
	inc	si			; point to an entry
fileb2:	mov	bx,[si]			; length of text string
	cmp	ax,[si+bx+2]		; our index vs table entry index
	je	fileb3			; e = match
	add	si,bx			; skip text
	add	si,4			; skip count and index word
	loop	fileb2			; look again
	pop	si
	stc				; say unknown
	ret

fileb3:	mov	cx,bx			; length of string
	push	cx			; save for domath below
	add	si,2			; point at string
	push	es
	push	di
	mov	bx,ds
	mov	es,bx
	mov	di,offset rdbuf		; work buffer
	cld
	rep	movsb			; copy string
	xor	al,al
	stosb				; asciiz
	pop	di
	pop	es
	pop	cx
	mov	domath_ptr,offset rdbuf
	mov	domath_cnt,cx
	call	domath			; convert to number in dx:ax
	pop	si
	ret
filebps	endp
code	ends

code1	segment
	assume	cs:code1
winpr	proc	far			; print number of active window slots
	push	ax
	mov	al,windused		; window slots in use
	cmp	al,winusedmax		; exceeds running max noted?
	jbe	winpr5			; be = no
	mov	winusedmax,al		; update max
winpr5:	pop	ax
	cmp	trans.windo,1		; windowing in use?
	jbe	winprx			; be = no, no message
	test	flags.remflg,dregular	; regular display?
	jz	winprx			; z = no, no display
	cmp	fmtdsp,0		; formatted display?
	je	winprx			; e = no, no display here
	test	flags.remflg,dserver	; server mode?
	jnz	winpr4			; nz = yes, writing to their screen
	cmp	flags.xflg,0		; receiving to screen?
	je	winpr4			; e = no
winprx:	ret
winpr4:	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	cmp	windflag,0		; have we written an initial value?
	jne	winpr1			; ne = yes
	mov	dx,scrnp		; position cursor
	dec	dh
	xor	dl,dl			; 0 = left most column for text
	call	fposcur
	call	fclearl			; clear the line
	mov	ah,prstr
	mov	dx,offset windmsg	; the text
	int	dos
	xor	al,al			; display an initial 0
	mov	oldwind,-1
	mov	windflag,1		; say have done the work
	jmp	short winpr2
winpr1:	mov	al,windused		; window slots in use
	cmp	al,oldwind		; same as before?
	je	winpr3			; e = yes, ignore
winpr2:	push	ax
	mov	dx,scrnp		; position cursor
	dec	dh
	call	fposcur
	call	fclearl
	pop	ax
	mov	oldwind,al		; remember last value
	xor	ah,ah
	call	decout			; display value
	mov	ah,prstr
	mov	dx,offset windmsg2	; ' of '
	int	dos
	mov	al,trans.windo		; number of window slots
	xor	ah,ah
	call	decout
winpr3:	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
winpr	endp

; Say Streaming: Active on formatted display
streampr proc	far
	test	flags.remflg,dregular	; regular display?
	jz	strmx			; z = no, no display
	cmp	fmtdsp,0		; formatted display?
	je	strmx			; e = no, no display here
	test	flags.remflg,dserver	; server mode?
	jnz	strm1			; nz = yes, writing to their screen
	cmp	flags.xflg,0		; receiving to screen?
	je	strm1			; e = no
strmx:	ret
strm1:	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	mov	dx,scrnp		; position cursor
	dec	dh
	xor	dl,dl			; 0 = left most column for text
	call	fposcur
	call	fclearl			; clear the line
	mov	ah,prstr
	mov	dx,offset streammsg	; the text
	int	dos
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
streampr endp

; Start recording of statistics for this operation. Enter with al = 0 for
; receive, al = 1 for send.
fbegtim	proc	FAR
	mov	crcword,0		; clear CRC-16 for last file
	mov	word ptr lastfsize,0	; clear size of last xfered file
	mov	word ptr lastfsize+2,0
	test	sflag,80h		; is this a duplicate call?
	jz	begtim1			; z = no
	ret				; else just return
begtim1:push	ax
	push	cx
	push	dx
	push	di
	push	es
	push	ds
	pop	es
	and	al,1
	mov	sflag,al		; save direction of xfer (1=send)
	xor	ax,ax		; clear statistics counters for this file
	mov	crcword,ax		; clear CRC-16 value of last group
	cld
	mov	di,offset fsta.prbyte	; start of the structure
	mov	cx,offset fsta.xstatus2 + 1 - offset fsta.prbyte ; end
	rep	stosb			; clear most of the structure
	pop	es
	pop	di
	mov	ah,getdate		; get current date, convert to ascii
	int	dos
	mov	date+9,'0'		; init day of month
begtim2:cmp	dl,10			; day of month. Ten or more days?
	jl	begtim3			; l = no
	sub	dl,10
	inc	date+9			; add up tens of days
	jmp	short begtim2		; repeat for higher order
begtim3:add	dl,'0'			; ascii bias
	mov	date+10,dl		; day units
	mov	dl,dh			; months (1-12)
	dec	dl			; start at zero to index table
	xor	dh,dh
	mov	di,dx			; months
	shl	di,1
	add	di,dx			; times three chars/month
	mov	al,months[di]		; get text string for month
	mov	date+12,al
	mov	ax,word ptr months[di+1]
	mov	word ptr date+13,ax
	mov	ax,cx			; year since 1980
	mov	dx,0
	mov	di,offset date+16	; destination
	call	flnout			; convert number to asciiz in buffer
	mov	date+20,','		; needed punctuation for log
					; start time
	mov	ah,gettim		; DOS time of day, convert to ascii
	int	dos
	push	cx
	push	dx
	call	timewrk			; convert to seconds.01 in dx,ax
	mov	fsta.btime,ax		; store ss.s   low word of seconds
	mov	fsta.btime+2,dx		;  high word of seconds
	pop	dx
	pop	cx
	mov	date,'0'		; init begin hours field
begtim4:cmp	ch,10			; ten or more hours?
	jl	begtim5			; l = no
	sub	ch,10
	inc	date			; add up tens of hours
	jmp	short begtim4		; repeat for twenties
begtim5:add	ch,'0'			; ascii bias
	mov	date+1,ch		; store units of hours
	mov	date+3,'0'		; minutes field
begtim6:cmp	cl,10			; ten or more minutes?
	jl	begtim7			; l = no
	sub	cl,10
	inc	date+3			; add up tens of minutes
	jmp	short begtim6		; repeat for higher orders
begtim7:add	cl,'0'			; ascii bias
	mov	date+4,cl		; store units of minutes
	mov	date+6,'0'		; seconds field
begtim8:cmp	dh,10			; ten or more seconds?
	jl	begtim9			; l = no
	sub	dh,10
	inc	date+6			; add up tens of seconds
	jmp	short begtim8		; repeat for higher orders
begtim9:add	dh,'0'			; ascii bias
	mov	date+7,dh
	or	sflag,80h		; say begtim has been run
	pop	dx
	pop	cx
	pop	ax
	ret
fbegtim	endp

; Take snapshot of statistics counters at end of an operation
; Enter with ax = 0 for a receive operation, ax = 1 for a send. [jrd]
fendtim	proc	FAR
	test	sflag,80h	; called more than once without calling begtim?
	jnz	endtim1			; nz = no, so do statistics snapshot
	ret				; yes, do nothing
endtim1:and	sflag,not (1)		; assume receive operation
	or	ax,ax			; send (ax > 0), receive (ax = 0) flag
	jz	endtim2			; z = receive opeation
	or	sflag,1			; say send operation
endtim2:push	ax
	push	cx
	push	dx
	mov	ah,gettim		; get DOS time of day
	int	dos			; ch=hh, cl=mm, dh=ss, dl= 0.01 sec
	call	timewrk			; convert to seconds.01 in dx,ax
	sub	al,byte ptr fsta.btime	; 0.01 sec field, wrapped?
	jnc	endtim2a		; nc = no
	add	al,100			; unwrap
	sub	ah,1			; borrow one second from end seconds
	sbb	dx,0
endtim2a:sub	ah,byte ptr fsta.btime+1 ; minus begin time, sec
	sbb	dx,fsta.btime+2
	jnc	endtim2b		; nc = no day straddling
	add	ah,128			; part of one day
	adc	dx,337			; rest of 86400 sec/day
endtim2b:mov	fsta.etime,ax		; elapsed time
	mov	fsta.etime+2,dx
	add	al,byte ptr ssta.etime 	; add to session time, 0.01 sec field
	cmp	al,100			; larger than 1 sec?
	jb	endtim2c		; b = no
	sub	al,100			; keep under 1 sec
	add	ah,1			; ripple carry seconds
	adc	dx,0
endtim2c:mov	byte ptr ssta.etime,al
	add	byte ptr ssta.etime+1,ah ; seconds low byte
	adc	ssta.etime+2,dx		; add to session time, high word
	mov	ax,fsta.pretry		; retries for last transfer
	add	ssta.pretry,ax		; retries for this session

	test	sflag,1			; completing a receive operation?
	jnz	endtim3			; nz = no, a send operation
	mov	ax,fsta.frbyte
	add	ssta.frbyte,ax		; session received file bytes, low word
	mov	ax,fsta.frbyte+2
	adc	ssta.frbyte+2,ax
	mov	ax,fsta.prbyte		; received pkt byte count
	add	ssta.prbyte,ax
	mov	ax,fsta.prbyte+2
	adc	ssta.prbyte+2,ax
	xor	ax,ax
	mov	fsta.psbyte,ax		; don't count reverse channel bytes
	mov	fsta.psbyte+2,ax
	jmp	short endtim4

endtim3:mov	ax,fsta.fsbyte		; file bytes sent
	add	ssta.fsbyte,ax		; session sent file bytes, low word
	mov	ax,fsta.fsbyte+2
	adc	ssta.fsbyte+2,ax
	mov	ax,fsta.psbyte		; sent pkt byte count
	add	ssta.psbyte,ax
	mov	ax,fsta.psbyte+2
	adc	ssta.psbyte+2,ax
	xor	ax,ax
	mov	fsta.prbyte,ax		; don't count reverse channel bytes
	mov	fsta.prbyte+2,ax

endtim4:mov	ax,fsta.nakrcnt 	; NAKs received for this file
	add	ssta.nakrcnt,ax 	; session received NAKs
	mov	ax,fsta.nakscnt 	; NAKs sent for this file
	add	ssta.nakscnt,ax 	; session sent NAKs
	mov	ax,fsta.prpkt		; received packet count
	add	ssta.prpkt,ax
	mov	ax,fsta.prpkt+2
	adc	ssta.prpkt+2,ax
	mov	ax,fsta.pspkt		; sent packet count
	add	ssta.pspkt,ax
	mov	ax,fsta.pspkt+2
	adc	ssta.pspkt+2,ax
	mov	al,sflag
	and	al,1			; pick out send/receive bit
	shl	al,1			; move bit up for file chars/sec
	mov	sflag,al		; say have done ending once already
	mov	fsta.xname,0		; clear statistics "as" name
	pop	dx
	pop	cx
	pop	ax
	ret
fendtim	endp

; Log receive/send transction. Expect sflag to be preset by call to begtim.
logtransact proc far			; do transaction logging
	cmp	tloghnd,0		; logging transaction? -1 = not opened
	jg	logtra5			; g = logging
	jmp	logtra12		; skip logging
logtra5:push	di			; kind of transaction
	push	bx			; save these registers
	mov	bx,tloghnd		; handle for transaction log
	mov	dx,offset rcvmsg	; assume receive message
	test	sflag,1			; 1 for send, 0 for receive
	jz	logtra6			; z = receive
	mov	dx,offset sndmsg	; send message
logtra6:call	strlen			; length of message to cx
	mov	ah,write2
	int	dos			; write kind of transfer
					; File names
	cmp	diskio.string,0		; local filename
	je	logtra9			; e = no filename
	test	sflag,1			; a send operation?
	jnz	logtra8			; nz = yes
					; Receive
	mov	dx,offset fsta.xname	; remote name
	call	strlen			; length to cx
	jcxz	logtra7			; no name
	mov	ah,write2
	int	dos
	mov	dx,offset diskio.string	; local name
	call	strlen			; length to cx
	mov	si,offset fsta.xname	; compare these two names
	mov	di,dx
	push	ds
	pop	es
	repe	cmpsb			; compare
	je	logtra9			; e = same, so no 'as' msg
	mov	dx,offset fasmsg	; give 'as' message
	mov	cx,faslen		; length
	mov	ah,write2
	int	dos
logtra7:mov	dx,offset diskio.string	; local name
	call	strlen			; get length
	mov	ah,write2		; write local name
	int	dos
	jmp	short logtra9

logtra8:mov	dx,offset diskio.string; templp	; Send. local name
	call	strlen
	mov	ah,write2
	int	dos
	cmp	fsta.xname,0		; using an alias?
	je	logtra9			; e = no
	mov	dx,offset fasmsg	; give 'as' message
	mov	cx,faslen
	mov	ah,write2
	int	dos
	mov	dx,offset fsta.xname	; get alias
	call	strlen
	mov	ah,write2
	int	dos
					; status of transfer
logtra9:mov	dx,offset atmsg		; say At
	mov	cx,atlen		; length
	mov	bx,tloghnd		; handle
	mov	ah,write2
	int	dos
	mov	dx,offset date		; write time and date field
	mov	cx,datelen		; length
	mov	ah,write2
	int	dos
	mov	dx,offset fsucmsg	; assume success message
	cmp	fsta.xstatus,kssuc	; 0 = completed successfully?
	je	logtra9c		; e = completed
	mov	dx,offset fbadmsg	; failed message
logtra9c:call	strlen
	mov	ah,write2
	int	dos
logtra9b:mov	al,fsta.xstatus2	; get file attributes reason byte
	or	al,al			; any transfer codes?
	jz	logtra10a		; z = no
	mov	dx,offset ferbyte	; assume file size
	cmp	al,'1'			; bytes
	je	logtra10		; e = yes
	cmp	al,'!'			; kilobytes
	je	logtra10		; e = yes
	mov	dx,offset ferdate	; assume file date/time
	cmp	al,'#'
	je	logtra10		; e = yes
	mov	dx,offset ferdisp	; assume file disposition
	cmp	al,'+'
	je	logtra10		; e = yes
	mov	dx,offset fertype	; assume file type
	cmp	al,'"'
	je	logtra10		; e = yes
	mov	dx,offset ferchar	; assume char set
	cmp	al,'*'
	je	logtra10		; e = yes
	mov	dx,offset fername
	cmp	al,'?'			; filename collision?
	je	logtra10		; e = yes
	mov	dx,offset ferunk	; assume unknown
	jmp	short logtra10
logtra9a:test	fsta.xstatus,ksuser	; user interrupted?
	jz	logtra10		; z = no
	mov	dx,offset fintmsg	; interrupted message
logtra10:call	strlen			; get length to cx
	mov	ah,write2
	int	dos
	mov	dx,offset commamsg	; ", "
	mov	cx,2
	mov	ah,write2
	int 	dos
logtra10a:mov	dx,offset bytesmsg	; "bytes: "
	call	strlen
	mov	ah,write2
	int	dos
					; file bytes transferred
	mov	ax,tfilsz		; file bytes, low word
	mov	dx,tfilsz+2		; high word
	mov	di,offset rdbuf		; work buffer
	call	flnouts			; transform to ascii
	mov	[di],0a0dh		; append cr/lf
	add	di,2			; count them
	mov	dx,offset rdbuf		; start of work buffer
	mov	cx,di			; next free byte
	sub	cx,dx			; compute length
	mov	ah,write2
	int	dos
	cmp	dosnum,300h+30		; DOS 3.30 or higher?
	jb	logtra11		; b = no
	mov	ah,68h			; Commit the file now
	int	dos
logtra11:pop	bx
	pop	di
logtra12:
	mov	ax,tfilsz		; low order word of transferred size
	mov	word ptr lastfsize,ax
	mov	ax,tfilsz+2		; high order word
	mov	word ptr lastfsize+2,ax
	xor	ax,ax
	mov	tfilsz,ax		; clear file size area
	mov	tfilsz+2,ax
	mov	fsta.xname,al		; clear statistics "as" name
	ret
logtransact endp

; Convert ch=hh, cl=mm, dh=ss, dl= .s to   dx,ah seconds and al 0.01 seconds
timewrk	proc	near
	push	bx
	mov	bl,dl			; save fractions of seconds
	push	bx
	mov	bl,dh			; clock seconds
	xor	bh,bh
	mov	al,ch			; get hours
	mov	ch,60
	mul	ch			; ax is minutes
	add	al,cl			; add clock minutes
	adc	ah,0
	mov	cx,60
	mul	cx			; minutes to seconds in dx,ax
	add	ax,bx			; add clock seconds
	adc	dx,0
	mov	dh,dl			; move up one byte for 0.01 field
	mov	dl,ah
	mov	ah,al
	pop	bx			; get old 0.01 field (was dl)
	mov	al,bl
	pop	bx
	ret
timewrk	endp

fshosta	proc	far			; STATISTICS display
	push	bx
	push	di
	mov	dx,offset statmsg	; header
	mov	ah,prstr
	int	dos
	mov	dx,offset fchmsg	; File characters msg
	mov	ah,prstr
	int	dos
	mov	di,offset ssta		; session structure
	mov	bx,offset fsta		; last file structure
	mov	ax,[bx].fsbyte		; last transfer file bytes sent
	mov	dx,[bx].fsbyte+2
	mov	cx,12			; field width
	call	shoprt			; show result
	mov	ax,[bx].frbyte		; last transfer file bytes received
	mov	dx,[bx].frbyte+2
	call	shoprt			; show result
	mov	ax,[di].fsbyte		; session file bytes sent
	mov	dx,[di].fsbyte+2
	call	shoprt			; show result
	mov	ax,[di].frbyte		; session file bytes received
	mov	dx,[di].frbyte+2
	call	shoprt			; show result

	mov	ah,prstr
	mov	dx,offset spmsg		; serial port material
	int	dos
	mov	ax,[bx].psbyte		; last transfer port bytes sent
	mov	dx,[bx].psbyte+2
	call	shoprt			; show result
	mov	ax,[bx].prbyte		; last transfer port bytes received
	mov	dx,[bx].prbyte+2
	call	shoprt			; show result
	mov	ax,[di].psbyte		; session port bytes sent
	mov	dx,[di].psbyte+2
	call	shoprt			; show result
	mov	ax,[di].prbyte		; session port bytes received
	mov	dx,[di].prbyte+2
	call	shoprt			; show result

	mov	dx,offset pktmsg	; packets material
	mov	ah,prstr
	int	dos
	mov	ax,[bx].pspkt		; last transfer packets sent
	mov	dx,[bx].pspkt+2
	call	shoprt			; show result
	mov	ax,[bx].prpkt		; last transfer packets received
	mov	dx,[bx].prpkt+2
	call	shoprt			; show result
	mov	ax,[di].pspkt		; session packets sent
	mov	dx,[di].pspkt+2
	call	shoprt			; show result
	mov	ax,[di].prpkt		; session packets received
	mov	dx,[di].prpkt+2
	call	shoprt			; show result

	mov	dx,offset nakmsg	; NAKs material
	mov	ah,prstr
	int	dos
	mov	ax,[bx].nakscnt		; last transfer NAKs sent
	xor	dx,dx
	call	shoprt
	mov	ax,[bx].nakrcnt		; last transfer NAKs received
	xor	dx,dx
	call	shoprt
	mov	ax,[di].nakscnt		; session NAKs sent
	xor	dx,dx
	call	shoprt
	mov	ax,[di].nakrcnt		; session NAKs received
	xor	dx,dx
	call	shoprt

	mov	dx,offset retmsg	; retries
	mov	ah,prstr
	int	dos
	mov	ax,[bx].pretry		; last transfer retry count
	xor	dx,dx
	mov	cx,18
	call	shoprt
	mov	ax,[di].pretry		; session retries
	xor	dx,dx
	mov	cx,24
	call	shoprt

	mov	ah,prstr
	mov	dx,offset crlf
	int	dos
	cmp	streamok,0		; if did not use streaming
	je	shostat1		; e = no streaming
	mov	dx,offset streamstat
	int 	dos
	jmp	shostat2
shostat1:mov	dx,offset windmsg	; Window slots used/negotiated
	int	dos
	mov	al,winusedmax		; max used
	xor	ah,ah
	xor	dx,dx
	mov	cx,16
	call	shoprt
	mov	ah,prstr
	mov	dx,offset windmsg2
	int	dos
	mov	al,trans.windo		; negotiated
	xor	ah,ah
	xor	dx,dx
	mov	cx,1
	call	shoprt

shostat2:mov	dx,offset timemsg	; elapsed time material
	mov	ah,prstr
	int	dos
	mov	cx,15			; field width
	call	shoetime		; show elapsed time as seconds.01
	xchg	bx,di			; put session into bx
	mov	cx,21			; field width
	call	shoetime		; show elapsed time as seconds.01
	xchg	bx,di			; unswap pointers

	mov	dx,offset chpsmsg	; File chars per second
	mov	ah,prstr
	int	dos
	mov	ax,[bx].frbyte		; file bytes received, low
	mov	dx,[bx].frbyte+2	; file bytes received, high
	add	ax,[bx].fsbyte		; file bytes sent, low
	adc	dx,[bx].fsbyte+2	;  high. [dx,ax] = total file bytes
	call	showrk			; do worker
	mov	cx,18
	call	shoprt			; show result
	xchg	bx,di			; swap session and last file pointers
	mov	ax,[bx].frbyte		; file bytes received, low
	mov	dx,[bx].frbyte+2	; file bytes received, high
	add	ax,[bx].fsbyte		; file bytes sent, low
	adc	dx,[bx].fsbyte+2	;  high. [dx,ax] = total file bytes
	call	showrk			; do worker
	xchg	bx,di			; unswap session and last file pointers
	mov	cx,24
	call	shoprt			; show result
		
	mov	dx,offset spedmsg	; speed material
	mov	ah,prstr
	int	dos
	mov	cx,18			; field width
	call	showbps			; do bps display
	mov	bx,offset ssta		; session
	mov	cx,24			; field width
	call	showbps			; do bps display
	mov	ah,prstr
	mov	dx,offset crlf
	int	dos
	pop	di
	pop	bx
	clc
	ret
fshosta	endp

; Worker for above. Display [BX].etime as seconds.01, field width in CX
shoetime proc	near
	mov	ax,[bx].etime		; elapsed time of last transfer
	mov	dx,[bx].etime+2
	mov	al,ah			; ignore fractions of seconds
	mov	ah,dl
	mov	dl,dh
	xor	dh,dh
	call	shoprt			; show result, cx has field width
	mov	ah,conout
	mov	dl,'.'
	int	dos
	cmp	byte ptr [bx].etime,9	; small qty of 0.01 sec units?
	ja	shoetim1		; a = no
	mov	dl,'0'
	int	dos
shoetim1:mov	al,byte ptr [bx].etime	; 0.01 sec units
	xor	ah,ah
	xor	dx,dx
	mov	cx,1
	call	shoprt
	ret
shoetime endp

; Worker for above
; Display baud rate as  10 * total port bytes / elapsed time
; BX has structure offset, CX has field width
showbps	proc	near
	mov	ax,[bx].prbyte		; port bytes received, low
	mov	dx,[bx].prbyte+2	; port bytes received, high
	add	ax,[bx].psbyte		; port bytes sent, low
	adc	dx,[bx].psbyte+2	;  high. [dx,ax] = total port bytes
	push	cx
	push	bx
	push	ax			; save low order part
	mov	cx,10
	mov	ax,dx			; high order part
	mul	cx			; high part times 10
	mov	bx,ax			; save low order result
	pop	ax
	mul	cx			; low times 10
	add	dx,bx			; add high parts
	pop	bx
	call	showrk			; do worker for bytes/sec
	pop	cx			; recover field width
	call	shoprt			; show result
	ret
showbps	endp

; Display SHOW STATISTICS line. Enter with dx,ax with long value, cx = width
fshoprt proc	far
	call	shoprt
	ret
fshoprt	endp

shoprt	proc	near
	push	di
	mov	di,offset rdbuf		; work space for output
	call	flnouts			; show long integer, with separator
	pop	di
	mov	dx,offset rdbuf
	push	bx
	push	cx
	push	dx
	mov	bx,cx			; field width
	call	strlen			; length of string in dx
	sub	bx,cx			; number of spaces necessary
	xchg	bx,cx
	jle	shoprt2			; le = no spaces
	mov	dl,' '
	mov	ah,conout
shoprt1:int	dos			; display the leading spaces
	loop	shoprt1
shoprt2:pop	dx
	pop	cx
	pop	bx
	call	prtasz			; display asciiz string
	ret
shoprt	endp

; Divide long number in dx,ax by [bx].elapsed time (seconds).
; Return result back in dx,ax
fshowrk proc	far
	call	showrk
	ret
fshowrk	endp

showrk	proc	near
	mov	cx,[bx].etime+1		; low word of sec in cx
	cmp	byte ptr [bx].etime+2,0	; high byte of sec zero (< 65536 sec)?
	jz	showrk1			; z = yes, ready for arithmetic
	push	ax			; else scale values, save byte count
	push	dx
	mov	ax,[bx].etime+1		; elapsed time for file, low word
	mov	dl,byte ptr [bx].etime+3 ;  high byte
	xor	dh,dh			;  ignoring fractions of second
	shr	ax,1			; divide seconds by two, low word
	ror	dx,1			; get low bit of high word
	and	dx,8000			; pick out just that bit
	or	ax,dx		; mask in that bit, new time in ax (dx = 0)
	mov	cx,ax			; save elapsed time (double-seconds)
	pop	dx			; get byte count again
	pop	ax
	shr	ax,1			; divide byte count by two also
	push	dx
	ror	dx,1			; rotate low bit to high position
	and	dx,8000h		; get low bit of high word
	or	ax,dx			; byte count divided by two, low word
	pop	dx
	shr	dx,1			; and high word
	jmp	short showrk2

showrk1:cmp	cx,30			; small amount of elapsed time?
	ja	showrk2			; a = no
	push	bx
	push	si
	mov	bx,100			; scale in the 0.01 sec part
	push	ax			; save low order top
	mov	ax,dx			; high order top
	mul	bx
	mov	si,ax			; low order result
	pop	ax
	mul	bx			; low order top
	add	dx,si			; dx,ax * 100 in dx,ax
	push	ax
	mov	ax,cx			; seconds
	mul	bl			; to units of 0.01 seconds
	mov	cx,ax
	pop	ax
	pop	si
	pop	bx
	add	cl,byte ptr [bx].etime	; 0.01 sec units
	adc	ch,0			; elapsed time seconds * 100
	or	cx,cx
	jnz	showrk2			; have a divisor
	inc	cx			; else make it 1 (0.01 sec)

showrk2:push	bx			; divide dx,ax by cx, results to dx,ax
	push	ax
	mov	ax,dx
	xor	dx,dx
	div	cx			; ax = high quo, dx = high rem
	mov	bx,ax			; save high quotient
	pop	ax
	div	cx		       ; bytes div seconds, ax = quo, dx = rem
	shl	dx,1			; remainder * 2
	cmp	dx,cx			; round up?
	jb	showrk3			; b = no
	add	ax,1			; round up
	adc	bx,0
showrk3:mov	dx,bx			; previous high quotient
	pop	bx
	ret
showrk	endp

fshomdef proc	FAR			; worker, show mac name and def
	push	ax			; call with si pointing at macro
	push	si			; name, word ptr [si-2] = length
	push	es
	cmp	byte ptr[si],0		; name starts with null char?
	jne	shomd1			; ne = no
	jmp	shomd9			; yes, TAKE file, ignore
shomd1:	call	shomdl			; do newline, check for more/exit
	jnc	shomd2			; nc = continue
	jmp	shomd9			; exit
shomd2:	mov	ah,conout
	mov	dl,' '			; add a space
	int	dos
	inc	bx
	inc	temp			; count displayed macros
	push	cx
	push	di
	mov	cx,[si-2]		; length of definition
	mov	di,si			; offset for printing
	call	prtscr			; print counted string
	pop	di
	pop	cx
	mov	ah,prstr
	mov	dx,offset eqs		; display equals sign
	int	dos
	mov	denom,1			; set flag to do "," to <cr>
	cmp	word ptr [si],'%\'	; substitution variable?
	jne	shomd2a			; ne = no
	mov	denom,0			; clear bare comma sensitivity flag
shomd2a:mov	ax,[si-2]		; length of macro name
	add	si,ax			; skip over name
	add	bx,ax			; count of chars on line
	add	bx,3			; plus " = "
	mov	es,[si]			; segment of string structure
	xor	si,si			; es:si = address of count + string
	mov	cx,es:[si]		; length of string
	jcxz	shomd9			; z = empty
	add	si,2			; si = offset of string text proper
shomd3:	mov	al,es:[si]		; get a byte into al
	inc	si
	call	shombrk			; examine for bare comma break
	cmp	al,' '			; control char?
	jae	shomd5			; ae = no
	cmp	al,cr			; carriage return?
	jne	shomd4			; ne = no
	cmp	cx,1			; more to show?
	je	shomd6			; e = no
	call	shomdl			; new line, check for continue or exit
	jc	shomd9			; c = exit
	mov	ah,conout		; show two spaces
	mov	dl,' '			; the spaces
	int	dos
	int	dos
	add	bx,2
	cmp	byte ptr es:[si],lf	; cr followed by linefeed?
	jne	short shomd6		; ne = no
	inc	si			; skip the leading lf
	dec	cx
	jmp	short shomd6
shomd4:	push	ax
	mov	ah,conout
	mov	dl,5eh			; caret
	int	dos
	pop	ax
	inc	bx
	add	al,'A'-1		; add offset to make printable letter
shomd5:	mov	ah,conout
	mov	dl,al			; display it
	int	dos
	inc	bx
shomd6:	cmp	bx,75			; time to break the line?
	jb	shomd8			; b = no
	cmp	bx,76			; at an absolute break point
	jae	shomd7			; ae = yes
	cmp	byte ptr es:[si],' '	; is next char a space?
	je	shomd8			; e = yes, show explicitly
shomd7:	mov	ah,conout		; display a line break hyphen
	mov	dl,'-'
	int	dos
	xor	bx,bx			; column counter
	cmp	cx,1			; done?
	je	fshova7			; e = yes
	call	shomdl			; check for screen full
	jc	shomd9			; c = exit now
shomd8:	loop	shomd3			; do whole string
shomd9:	pop	es
	pop	si
	pop	ax
	ret
      				; worker, do "more" and Control-C checking
shomdl	proc	near
	inc	temp1			; count lines displayed
	xor	bx,bx			; count of chars on the line
	cmp	temp1,24		; done a normal screens' worth?
	jb	shomdl3			; b = no
	mov	ah,prstr
	mov	dx,offset moremsg	; say more
	int	dos
	mov	temp1,0
	mov	flags.cxzflg,0		; clear flag so we can see Control-C
	mov	ah,0ch			; clear keyboard buffer
	mov	al,coninq		; quiet input
	int	dos
	cmp	al,3			; Control-C?
	je	shomdl1			; e = yes
	cmp	al,'q'			; q for quit?
	je	shomdl1			; e = yes
	cmp	al,'Q'			; Q for quit?
	je	shomdl1			; e = yes
	or	al,al			; scan code?
	jne	shomdl2			; ne = no
	mov	ah,coninq		; read the second byte
	int	dos
	or	al,al			; null for Control-Break?
	jne	shomdl2			; ne = no
shomdl1:mov	flags.cxzflg,'C'	; say want to exit now
shomdl2:push	cx
	push	es			; and read pointer
	push	si
	push	di
	mov	dl,cr			; move cursor to left margin
	mov	ah,conout
	int	dos
	call	fclearl			; clear display's line, reuse it
	pop	di
	pop	si
	pop	es
	pop	cx
	cmp	flags.cxzflg,0
	jne	shomdl4
	clc
	ret
shomdl3:mov	ah,prstr
	mov	dx,offset crlf
	int	dos
	clc
	ret
shomdl4:stc
	ret
shomdl	endp

; Examine char in al. If it is a bare comma and byte ptr denom is non-zero
; then return AL as CR
shombrk	proc	near
	push	dx
	mov	dx,denom		; dh=brace cnt, dl=1 for sensitivity
	cmp	al,'('			; consider this to be a brace
	jne	shombr2			; ne = no
	inc	dh			; count brace level
shombr2:cmp	al,')'
	jne	shombr4
	sub	dh,1			; count down brace level
	jns	shombr4			; ns = not below zero
	xor	dh,dh			; set brace level to zero
shombr4:mov	denom,dx		; store our brace state
	or	dh,dh			; inside braces?
	jnz	shombr5			; nz = yes
	cmp	al,','			; bare comma?
	jne	shombr5
	mov	al,CR
shombr5:pop	dx
	ret
shombrk	endp
fshomdef endp

fshovar	proc	FAR			; worker for SHOW VARIABLE, SHOVAR
	cmp	word ptr rdbuf,'v\'	; did user say \v(name)?
	jne	fshova2			; ne = no
	mov	di,offset rdbuf		; start plus count
	mov	si,di
	add	si,3			; remove \v(
	mov	cx,shmcnt		; length of user spec
	sub	cx,3
	mov	shmcnt,cx		; remember "variable)" part
	jle	fshova1			; le = nothing left
	inc	cx			; include null in the move
	mov	ax,ds
	mov	es,ax
	cld
	rep	movsb			; copy down
	mov	si,offset rdbuf
	add	si,shmcnt
	cmp	byte ptr [si-1],')'	; did user say ')'?
	jne	fshova2			; ne = no
	mov	byte ptr [si-1],0	; remove it
	dec	shmcnt
	jmp	short fshova2
fshova1:mov	shmcnt,0		; make user entry empty
fshova2:mov	si,offset valtab	; table of variable names
	cld
	lodsb
	mov	cl,al			; number of variable entries
	xor	ch,ch
	jcxz	fshova7			; z = none
	mov	temp1,0			; line counter
fshova3:push	cx			; save loop counter
	lodsw				; length of var name, incl ')'
	mov	cx,shmcnt		; length of user's string
	jcxz	fshova5			; show all names
	push	ax			; save length
	dec	ax			; omit ')'
	cmp	ax,cx			; var name shorter that user spec?
	pop	ax			; recover full length
	jb	fshova6			; b = yes, no match
	push	ax
	push	si			; save these around match test
	mov	di,offset rdbuf		; user's string
fshova4:mov	ah,[di]
	inc	di
	lodsb				; al = var name char, ah = user char
	and	ax,not 2020h		; clear bits (uppercase chars)
	cmp	ah,al			; same?
	loope	fshova4			; while equal, do more
	pop	si			; restore regs
	pop	ax
	jne	fshova6			; ne = no match
fshova5:call	fshova8			; show this name
	add	si,ax			; point to next name, add name length
	add	si,2			; and string pointer
	pop	cx			; recover loop counter
	cmp	cx,1			; last item?
	je	fshova6a		; e = yes
	call	shomdl			; "more" processor
	jc	fshova7			; c = exit now
	jmp	short fshova6a
fshova6:add	si,ax			; point to next name, add name length
	add	si,2			; and string pointer
	pop	cx			; recover loop counter
fshova6a:loop	fshova3			; one less macro to examine
fshova7:mov	flags.cxzflg,0		; clear flag before exiting
	ret

fshova8	proc	near			; worker for above
	push	ax
	mov	ah,prstr
	mov	dx,offset varstng	; put out " \v("
	int	dos
	push	si
	push	cx
	mov	cx,[si-2]		; length of name
fshova9:mov	dl,[si]			; get a variable character
	inc	si			; prep for next char
	mov	ah,conout
	int	dos
	loop	fshova9			; do the count
	mov	dl,' '			; display " = "
	int	dos
	mov	dl,'='
	int	dos
	mov	dl,' '
	int	dos
	mov	bx,[si]			; get result code to bx
	xor	dx,dx			; trim off trailing spaces
	push	es
	mov	di,seg decbuf
	mov	es,di
	mov	di,offset decbuf
	call	fnvaltoa		; fill es:di with string
	pop	es
	jc	fshova10		; c = failure
	mov	cx,di			; di is string length
	mov	di,offset decbuf	; string text (skips count word)
	call	prtscr			; display counted string
fshova10:pop	cx
	pop	si
	pop	ax
	ret
fshova8	endp				; end of worker
fshovar	endp

; Stuff string ds:di with last file transfer char/sec ascii string.
; called by show variable code in msscmd.asm
shovarcps proc	near
	xor	ax,ax
	mov	bx,offset fsta		; last file structure
	test	sflag,2			; 0 for rcv, 2 for send
	jz	shovarcp1		; z = receive
	mov	ax,[bx].fsbyte		; file bytes sent, low
	mov	dx,[bx].fsbyte+2	;  high. [dx,ax] = total file bytes
	jmp	short shovarcp2
shovarcp1:mov	ax,[bx].frbyte		; file bytes received, low
	mov	dx,[bx].frbyte+2	; file bytes received, high
shovarcp2:call	showrk			; do worker
	call	flnout			; show long integer, with separator
	ret
shovarcps endp

; show macro arrays, far worker for sharray
fsharray proc	far
	mov	ah,prstr
	mov	dx,offset fsharr1	; herald
	int	dos
	xor	bx,bx	     		; walk down array list
	mov	cx,25			; number of possible arrays
fshar1:	mov	ax,marray[bx]		; get seg of array element
	or	ax,ax			; any?
	jz	fshar2			; z = no
	push	ax
	mov	ah,conout
	mov	dl,' '
	int	dos
	mov	dl,'\'
	int	dos
	mov	dl,'&'
	int	dos
	mov	dl,bl			; array index (words)
	shr	dl,1			; bytes
	add	dl,'@'+20h		; bias to lower case
	int	dos
	mov	dl,'['
	int	dos
	pop	ax			; recover segment
	push	es
	mov	es,ax			; seg of it
	mov	ax,es:[0]		; get number of array elements
	pop	es
	call	decout			; display array size
	mov	ah,prstr
	mov	dx,offset fsharr2	; ']' end of line
	int	dos
fshar2:	add	bx,2			; next array slot
	loop	fshar1			; do all
	ret
fsharray endp

code1	ends

code	segment
	assume cs:code

; Show array
sharray	proc	near
	call	fsharray		; call the far proc above
	ret
sharray	endp

; SHOW TRANSLATE-RECEIVE
; Display characters being changed for Connect mode serial receive translator

SHORX	PROC	NEAR			; show translate table of incoming
					; chars, only those changed
	mov	ah,cmeol		; get a confirm
	call	comnd
	jnc	shorx0a			; nc = success
	ret				; failure
shorx0a:
	mov	ah,prstr
	mov	dx,offset crlf
	int	dos
	mov	bx,offset shorxk	; show keyboard translation
	xor	cx,cx
	call	statc
	mov	ah,prstr
	mov	dx,offset rxoffmsg	; assume translation is off
	cmp	rxtable+256,0		; is translation off?
	je	shorx0			; e = yes
	mov	dx,offset rxonmsg	; say translation is on
shorx0:	int	dos
	mov	dx,offset shormsg	; give title line
	int	dos
	xor	cx,cx			; formatted line counter
	xor	bx,bx			; entry subscript
shorx1:	cmp	rxtable[bx],bl		; entry same as normal?
	je	shorx2			; e = yes, skip it
	call	shorprt			; display the entry
shorx2:	inc	bx			; next entry
	cmp	bx,255			; done all entries yet?
	jbe	shorx1			; be = not yet
	mov	ah,prstr
	mov	dx,offset crlf		; end with cr/lf
	int	dos
	clc				; success
	ret
					; worker routine
shorprt:cmp	cx,4			; done five entries for this line?
	jb	shorpr1			; b = no
	mov	ah,prstr
	mov	dx,offset crlf		; break line now
	int	dos
	xor	cx,cx
shorpr1:mov	ah,prstr
	mov	dx,offset shopm1	; start of display
	int	dos
	xor	ah,ah
	mov	al,bl			; original byte code
	call	decout			; display its value
	mov	ah,prstr
	mov	dx,offset shopm2	; intermediate part of display
	int	dos
	xor	ah,ah
	mov	al,rxtable[bx]		; new byte code
	call	decout			; display its value
	mov	ah,prstr
	mov	dx,offset shopm3	; last part of display
	int	dos
	inc	cx			; count item displayed
	ret
SHORX	ENDP

; SHOW MACRO [macro name]

SHOMAC	PROC	NEAR
	mov	ah,cmword
	mov	bx,offset rdbuf
	mov	dx,offset shmmsg
	mov	comand.cmper,1		; don't react to \%x variables
	call	comnd
	jnc	shoma1a			; nc = success
	ret				; failure
shoma1a:mov	shmcnt,ax		; save length of user spec
	mov	ah,cmeol
	call	comnd
	jnc	shoma1b			; nc = success
	ret				; failure
shoma1b:mov	si,offset mcctab	; table of macro names
	cld
	lodsb
	mov	cl,al			; number of macro entries
	xor	ch,ch
	jcxz	shom6			; z = none
	mov	temp,0			; count of macros displayed
	mov	temp1,0			; lines displayed, for more message
shom2:	push	cx			; save loop counter
	lodsw				; length of macro name
	mov	cx,shmcnt		; length of user's string
	jcxz	shom4			; show all names
	cmp	ax,cx			; mac name shorter that user spec?
	jb	shom5			; b = yes, no match
	push	ax
	push	si			; save these around match test
	mov	di,offset rdbuf		; user's string
shom3:	mov	ah,[di]
	inc	di
	lodsb				; al = mac name char, ah = user char
	and	ax,not 2020h		; clear bits (uppercase chars)
	cmp	ah,al			; same?
	loope	shom3			; while equal, do more
	pop	si			; restore regs
	pop	ax
	jne	shom5			; ne = no match
shom4:	call	fshomdef		; show this name (FAR)
shom5:	add	si,ax			; point to next name, add name length
	add	si,2			;  and string pointer
	pop	cx			; recover loop counter
	cmp	flags.cxzflg,0		; does user wish to stop now?
	jne	shom5a			; ne = yes
	loop	shom2			; one less macro to examine
shom5a:	mov	flags.cxzflg,0		; clear flag before exiting
	cmp	temp,0			; did we show any macros?
	jne	shom7			; ne = yes
shom6:	mov	ah,prstr
	mov	dx,offset shom9m3	; no entries found
	int	dos
shom7:	mov	ah,prstr		; Summary line
	mov	dx,offset shom9m1	; free space: name entries
	int	dos
	mov	ax,offset mcctab+mcclen
	sub	ax,mccptr		; compute # of free name bytes
	call	decout
	clc				; success
	ret
SHOMAC	ENDP

SHCOM	PROC	NEAR			; Show Comm
	mov	ah,cmeol
	call	comnd			; get a confirm
	jc	shcom1			; c = failure
	mov	dx,offset crlf
	mov	ah,prstr
	int	dos			; print a crlf
	mov	bx,offset stcom		; table of items to be shown
	xor	cx,cx
	call	statc			; finish in common code
	call	shomodem
ifndef	no_network
	call	shownet
endif	; no_network
	clc
shcom1:	ret
SHCOM	ENDP

SHFILE	PROC	NEAR			; Show File
	mov	ah,cmeol
	call	comnd			; get a confirm
	jnc	shfile1			; nc = success
	ret				; failure
shfile1:mov	dx,offset crlf
	mov	ah,prstr
	int	dos			; print a crlf
	mov	bx,offset stfile	; table of items to be shown
	xor	cx,cx
	jmp	statc			; finish in common code
SHFILE	ENDP

SHLOG	PROC	NEAR			; Show Log
	mov	ah,cmeol
	call	comnd			; get a confirm
	jnc	shlog1			; nc = success
	ret				; failure
shlog1:	mov	dx,offset crlf
	mov	ah,prstr
	int	dos			; print a crlf
	mov	bx,offset stlog		; table of items to be shown
	xor	cx,cx
	jmp	statc			; finish in common code
SHLOG	ENDP

SHMEM	PROC	NEAR			; Show (free) Memory.   Recursive!
	mov	ah,cmeol
	call	comnd			; get a confirm
	jnc	shmem1			; nc = success
	ret				; failure
shmem1:	mov	ah,prstr
	mov	dx,offset memmsg1	; header message
	int	dos
	mov	word ptr rdbuf,'  '	; two spaces
	mov	rdbuf+2,0		; safety null terminator
	mov	di,offset rdbuf+1	; look at first space
	mov	temp,0			; total free memory
	mov	temp1,0			;  and high word thereof
	push	es			; save es
	call	shmem4			; allocate memory, recursively
	mov	dx,offset rdbuf		; output buffer
	call	prtasz			; show pieces
	mov	dx,offset memmsg2	; trailer
	mov	ah,prstr
	int	dos
	mov	di,offset rdbuf		; setup buffer for lnout
	mov	rdbuf,0
	mov	ax,temp			; total free space
	mov	dx,temp1
	call	lnouts			; 32 bit to decimal ascii in di
	mov	dx,offset rdbuf		;  with thousands separator
	call	prtasz
	pop	es
	ret
					; worker routine
shmem4:	mov	bx,0ffffh		; allocate all memory (must fail)
	mov	ah,alloc		; DOS memory allocator
	int	dos			; returns available paragraphs in bx
	jnc	shmem6			; nc = got it all (not very likely)
	or	bx,bx			; bx = # paragraphs alloc'd. Anything?
	jz	shmem5			; z = no
	mov	ah,alloc		; consume qty now given in bx
	int	dos
	jnc	shmem6			; nc = got the fragment
shmem5:	ret
shmem6:	push	ax			; save allocation segment
	mov	ax,bx			; convert paragraphs
	mul	sixteen			;  to bytes in dx:ax
	add	temp,ax			; running total
	adc	temp1,dx		;  32 bits
	cmp	byte ptr [di],0		; starting on a null?
	jne	shmem7			; ne = no, skip punctuation
	mov	byte ptr [di],'+'	; plus punctuation
	inc	di
shmem7:	call	lnouts			; long number to decimal in buffer di
	call	shmem4			; recurse
	pop	es			; recover allocation segment
	mov	ah,freemem		; free the allocation
	int	dos
	ret
SHMEM	ENDP

shnet	PROC	NEAR			; Show network
	mov	ah,cmeol
	call	comnd			; get a confirm
	jc	shnet1			; c = failure
	mov	dx,offset crlf
	mov	ah,prstr
	int	dos			; print a crlf
	mov	bx,offset stcom		; table of items to be shown
	xor	cx,cx
	call	statc			; finish in common code
ifndef	no_network
	call	shownet
endif	; no_network
	clc
shnet1:	ret
SHnet	ENDP

SHPRO	PROC	NEAR			; Show Protocol
	mov	ah,cmeol
	call	comnd			; get a confirm
	jnc	shpro1			; nc = success
	ret				; failure
shpro1:	mov	dx,offset crlf
	mov	ah,prstr
	int	dos			; print a crlf
	mov	bx,offset stpro		; table of items to be shown
	xor	cx,cx
	jmp	statc			; finish in common code
SHPRO	ENDP

SHSCPT	PROC	NEAR			; Show Script
	mov	ah,cmeol
	call	comnd			; get a confirm
	jnc	shscpt1			; nc = success
	ret				; failure
shscpt1:mov	dx,offset crlf
	mov	ah,prstr
	int	dos			; print a crlf
	mov	bx,offset stscpt	; table of items to be shown
	xor	cx,cx
	jmp	statc			; finish in common code
SHSCPT	ENDP

SHSERV	PROC	NEAR			; Show Server
	mov	ah,cmeol
	call	comnd			; get a confirm
	jnc	shserv1			; nc = success
	ret				; failure
shserv1:mov	dx,offset crlf
	mov	ah,prstr
	int	dos			; print a crlf
	mov	bx,offset stserv2	; do timeout item
	xor	cx,cx
	call	statc
	mov	dx,offset crlf
	mov	ah,prstr
	int	dos
	mov	bx,offset stserv	; table of items to be shown
	jmp	statc			; finish in common code
SHSERV	ENDP

SHTERM	PROC	NEAR			; Show Terminal
	mov	ah,cmeol
	call	comnd			; get a confirm
	jnc	shterm1			; nc = success
	ret				; failure
shterm1:mov	dx,offset crlf
	mov	ah,prstr
	int	dos			; print a crlf
ifdef	no_terminal
	ret				; cut short the display
else
	mov	bx,offset stterm	; table of items to be shown
	xor	cx,cx
	jmp	statc			; use common code
endif	; no_terminal
SHTERM	ENDP

; SHOW VAR of kind \v(name)
SHOVAR	proc	near
	mov	ah,cmword
	mov	bx,offset rdbuf
	mov	dx,offset shvmsg
	mov	comand.cmper,1		; don't react to \%x variables
	call	comnd
	jnc	shovar1			; nc = success
	ret				; failure
shovar1:mov	shmcnt,ax		; save length of user spec
	mov	ah,cmeol
	call	comnd
	jnc	shovar2			; nc = success
	ret				; failure
shovar2:mov	ah,prstr
	mov	dx,offset crlf
	int	dos
	call	fshovar			; call FAR worker
	ret
SHOVAR	endp

begtim	proc	near
	call	fbegtim			; call the real FAR routine
	ret
begtim	endp
endtim	proc	near
	call	fendtim			; call the real FAR routine
	ret
endtim	endp

; SHOW STATISTICS command. Displays last operation and session statistics
shosta	proc	near			; show file transfer statistics
	mov	ah,cmeol		; confirm with carriage return
	call	comnd
	jnc	shosta1
	ret				; failure
shosta1:xor	ax,ax
	call	endtim			; update statistics, just in case
	call	fshosta			; do a far call to worker
	ret
shosta	endp

; STATUS command
 
STATUS	PROC	NEAR
	mov	ah,cmeol
	call	comnd			; get a confirm
	jnc	stat0a			; nc = success
	ret				; failure
stat0a:	mov	dx,offset crlf
	mov	ah,prstr
	int	dos			; print a crlf
					; STAT0 is an external ref (in msster)
STAT0:	call	cmblnk			; clear the screen
	call	locate			; home the cursor
	mov	bx,offset sttab		; table to control printing
	xor	cx,cx			; column counter
					; STATC is external ref in msx
STATC:	cmp	word ptr [bx],0		; end of table?
	je	statx			; e = yes
	cld				; string direction is forward
	push	ds
	pop	es
	mov	di,offset rdbuf		; point to destination buffer
	mov	byte ptr[di],spc	; start with two spaces
	inc	di
	mov	byte ptr[di],spc
	inc	di
	push	cx			; save column number
	push	bx
	call	[bx].sttyp		; call appropriate routine
	pop	bx
	pop	cx
	sub	di,offset rdbuf		; number of bytes used
	add	cx,di			; new line col count
	push	cx			; save col number around print
	mov	cx,di			; how much to print now
	mov	di,offset rdbuf		; source text
	cmp	cx,2			; nothing besides our two spaces?
	jbe	stat5			; e = yes, forget it
	call	prtscr			; print counted string
stat5:	pop	cx
	add	bx,size stent		; look at next entry
	cmp	word ptr [bx],0		; at end of table?
	je	statx			; e = yes
	cmp	cx,38			; place for second display?
	jbe	stat2			; be = only half full
	mov	dx,offset crlf		; over half full. send cr/lf
	mov	ah,prstr
	int	dos
	xor	cx,cx			; say line is empty now
	jmp	statc
stat2:	mov	ax,cx
	mov	cx,38			; where we want to be next time
	sub	cx,ax			; compute number of filler spaces
	or	cx,cx
	jle	stat4			; nothing to do
	mov	ah,conout
	mov	dl,' '
stat3:	int	dos			; fill with spaces
	loop	stat3			; do cx times
stat4:	mov	cx,38			; current column number
	jmp	statc			; and do it
statx:	clc
	ret
STATUS	ENDP

; handler routines for status
; all are called with di/ destination buffer, bx/ stat ptr. They can change
; any register except es:, must update di to the end of the buffer.


; Copy dollar sign terminated string to buffer pointed at by preset di.
stmsg	proc	near
	push	ds
	pop	es		; ensure es points to data segment
	mov	si,[bx].msg	; get message address
stms1:	lodsb			; get a byte
	stosb			; drop it off
	or	al,al		; ending on null?
	jz	stms2		; z = yes
	cmp	al,'$'		; end of message?
	jne	stms1		; no, keep going
stms2:	dec	di		; else back up ptr
	ret
stmsg	endp

; get address of test value in stent. Returns address in si
stval	proc	near
	mov	si,[bx].basval	; get base value
	or	si,si		; any there?
	jz	stva1		; z = no, keep going
	mov	si,[si]		; yes, use as base address
stva1:	add	si,[bx].tstcel	; add offset of test cell
	ret			; and return it
stval	endp

; print a single character
onechr	proc	near
	call	stmsg		; copy message part first
	call	stval		; pick up test value address
	mov	al,[si]		; this is char to print
	cmp	al,7fh		; in graphics region?
	jb	onech2		; b = no
	mov	byte ptr [di],'\' ; do in \numerical form
	inc	di
	xor	ah,ah		; clear high byte
	jmp	outnum		; do number part
onech2:	cmp	al,' '		; printable?
	jae	onech1		; yes, keep going
	add	al,64		; make printable
	mov	byte ptr [di],5eh	; caret
	inc	di		; note ctrl char
onech1:	stosb			; drop char off
	ret
onechr	endp

; numeric field
stnum	proc	near		; for 8 bit numbers
	call	stmsg		; copy message
	call	stval		; pick up value address
	mov	al,[si]		; get value
	xor	ah,ah		; high order is 0
	jmp	outnum		; put number into buffer
stnum	endp

stlnum	proc	near		; for 16 bit numbers
	call	stmsg		; copy message
	call	stval		; pick up value address
	mov	ax,[si]		; get value
	jmp	outnum		; put number into buffer
stlnum	endp

; translate the number in ax
outnum	proc	near
	xor	dx,dx
	mov	bx,10
	div	bx		; divide to get digit
	push	dx		; save remainder digit
	or	ax,ax		; test quotient
	jz	outnu1		; zero, no more of number
	call	outnum		; else call for rest of number
outnu1:	pop	ax		; get digit back
	add	al,'0'		; make printable
	stosb			; drop it off
	ret
outnum	endp

; on/off field
onoff	proc	near
	call	stmsg		; copy message
	call	stval		; get value cell
	mov	al,[si]
	mov	si,offset onmsg
	mov	cx,2		; assume 2-byte 'ON' message
	or	al,al		; test value
	jnz	onof1		; on, have right msg
	mov	si,offset offmsg
	mov	cx,3
onof1:	cld
	push	ds
	pop	es
	rep	movsb		; copy right message in
	ret
onoff	endp

; print first message if false, second if true
msg2	proc	near
	call	stval		; get value cell
	mov	al,[si]
	mov	si,[bx].msg	; assume off
	or	al,al		; is it?
	jz	msg21		; yes, continue
	mov	si,[bx].val2	; else use alternate message
msg21:	jmp	stms1		; handle copy and return
msg2	endp

; print first message if false, second if true, uses bit in byte for value
msg2b	proc	near
	call	stbval		; get bit value cell
	mov	si,[bx].msg	; assume off
	or	al,al		; is it?
	jz	msg2b1		; yes, continue
	mov	si,[bx].val2	; else use alternate message
msg2b1:	jmp	stms1		; handle copy and return
msg2b	endp

; search a keyword table for a word value, print that value
srchkww	proc	near
	call	stmsg		; copy the first message
	call	stval
	mov	ax,[si]		; get value to hunt for
	mov	bx,[bx].val2	; this is table address
	jmp	prttab		; and look in table
srchkww	endp

; search a keyword table for a byte value, print that value
srchkw	proc	near
	call	stmsg		; first print message
	call	stval
	mov	al,[si]		; get value to hunt for
	xor	ah,ah		; high order is 0
	mov	bx,[bx].val2	; this is table address
	jmp	prttab		; and look in table
srchkw	endp

; search a keyword table for a bit value, print that value
srchkb	proc	near
	call	stmsg			; first print message
	call	stbval			; get bit set or reset
	mov	bx,[bx].val2		; this is table address
	jmp	prttab			; and look in table
srchkb	endp

; get address of test value in stent.  Returns address in si.
stbval	proc	near
	mov	si,[bx].basval		; get address of test value
	or	si,si			; any there?
	jz	stbva1			; z = no, quit with no match
	mov	ax,[si]			; get value
	test	ax,[bx].tstcel 		; bit test value against data word
	jz	stbva1			; z = they don't match
	mov	ax,1			;  match
	ret
stbva1:	xor	ax,ax			; no match
	ret				; and return it
stbval	endp


; Print the drive name
drnum	proc	near
	call	stmsg		; copy message part first
	call	stval		; pick up test value address
	mov	ah,gcurdsk	; Get current disk
	int	dos
	inc	al		; We want 1 == A (not zero)
	mov	curdsk,al
	add	al,'@'		; Make it printable
	cld
	push	ds
	pop	es
	stosb
	mov	word ptr [di],'\:'
	add	di,2		; end with a colon and backslash
	mov	byte ptr [di],0	; terminate in case drive is not ready
	xor	dl,dl		; get current drive
	mov	ah,gcd		; get current directory
	mov	si,di		; current working buffer position
	int	dos
	push	cx
	push	dx
	mov	dx,di		; directory string
	call	strlen		; length of path part to cx
	cmp	cx,26		; too long to show the whole thing?
	jbe	drnum3		; be = is ok, show the whole path
	push	di		; scan backward for last backslash
	mov	al,'\'		; thing to search for
	std			; backward
	mov	di,si		; start of buffer
	add	di,cx		; length of string
	repne	scasb		; scan backward for a backslash
	jcxz	drnum2		; should not happen, but then again 
	repne	scasb		; do again for second to last path part
drnum2:	cld			; reset direction flag
	dec	di		; move di two places preceding backslash
	mov	[di],'--'	; insert a missing path indicator
	dec	di
	mov	byte ptr [di],'-'
	mov	si,di		; we will show just this part
	pop	di		; recover main status pointer
drnum3:	pop	dx
	pop	cx
	
drnum4:	lodsb			; copy until null terminator
	stosb
	or	al,al		; end of string?
	jnz	drnum4		; nz = no
	dec	di		; offset inc of stosb
	ret
drnum	endp


; Print the screen-dump filename [jrd]

pasz	proc	near
	call	stmsg		; copy message part
	mov	si,[bx].val2	; address of asciiz string
	push	ds
	pop	es
	cld
pasz1:	lodsb			; get a byte
	or	al,al		; at end yet?
	jz	pasz2		; z = yes
	stosb			; store in buffer
	jmp	short pasz1	; keep storing non-null chars
pasz2:	ret
pasz	endp

; Repeat quote status presenter
rptstat	proc	near
	call	stmsg			; copy message part
	mov	al,dtrans.rptq		; repeat quote char
	stosb				; char
	mov	si,offset rptqena	; assume enabled
	cmp	dtrans.rptqenable,0	; enabled/disabled byte
	jne	rptstat1		; ne = no
	mov	si,offset rptqdis	; say disabled
rptstat1:lodsb				; read byte
	stosb				; store byte
	or	al,al
	jnz	rptstat1		; til done
	ret
rptstat	endp

; Display unprotected control characters
cntlsho	proc	near
	mov	ah,cmeol
	call	comnd
	jc	cntlsho1		; c = failure
	mov	ah,prstr
	mov	dx,offset cntlmsg1 	; first msg
	int	dos
	mov	temp,0			; show unprotected
	mov	dx,1			; do 7-bit unprotected forms
	call	cntlwk			; call worker
	mov	ah,prstr
	mov	dx,offset crlf
	int	dos
	mov	ah,conout
	mov	dl,' '
	int 	dos
	mov	dx,8080h		; do 8-bit unprotected forms
	call	cntlwk

	mov	ah,prstr
	mov	dx,offset cntlmsg2 	; protected msg
	int	dos
	mov	dx,1			; do 7-bit unprotected forms
	mov	temp,1			; show protected
	call	cntlwk			; call worker
	mov	ah,prstr
	mov	dx,offset crlf
	int	dos
	mov	ah,conout
	mov	dl,' '
	int 	dos
	mov	dx,8080h		; do 8-bit unprotected forms
	call	cntlwk
	clc
cntlsho1:ret
cntlsho endp
code	ends

code1	segment
	assume	cs:code1

; worker for cntlsho to display prefixed and not code values
cntlwk	proc	far
	mov	cx,32
	xor	bx,bx
	xor	si,si			; items per line counter
cntlwk1:cmp	temp,0			; doing unprotected?
	je	cntlwk4			; e = yes
	cmp	bl,trans.ssoh		; packet start of header?
	je	cntlwk5			; e = yes, always prefixed
	cmp	bl,trans.seol		; packet end of line?
	je	cntlwk5			; e = yes, always prefixed
	test	protlist[bx],dl		; unprotected?
	jz	cntlwk5			; z = no
	jmp	short cntlwk2		; skip unprotected

cntlwk4:cmp	bl,trans.ssoh		; packet start of header?
	je	cntlwk2			; e = yes, always prefixed
	cmp	bl,trans.seol		; packet end of line?
	je	cntlwk2			; e = yes, always prefixed
	test	protlist[bx],dl		; unprotected?
	jz	cntlwk2			; z = no
cntlwk5:mov	ax,bx
	add	al,dh			; add possible 128 offset
	push	dx
	call	decout
	mov	ah,conout		; show space
	mov	dl,' '
	int	dos
	pop	dx
	inc	si			; count item displayed
cntlwk2:inc	bx
	cmp	si,17			; done plenty for one line?
	jb	cntlwk3			; b = no
	push	dx
	mov	ah,prstr
	mov	dx,offset crlf
	int	dos
	mov	ah,conout
	mov	dl,' '
	int	dos
	pop	dx
	xor	si,si
cntlwk3:loop	cntlwk1
	cmp	temp,0			; showing prefixed?
	je	cntlwk6			; e = no
	xor	ah,ah
	mov	al,127			; always prefixed
	add	al,dh			; high bit
	call	decout
cntlwk6:ret
cntlwk	endp
code1	ends

code	segment
	assume cs:code

; Display Send and Receive chars
prsar	proc	near
	call 	stmsg		; display leadin part of message
	push	ds
	pop	es
	cld
	mov	si,[bx].tstcel	; get address of first item
	mov	al,[si]
	cmp	al,7fh		; DEL code?
	jne	prsar1		; ne = no
	mov	ax,'1\'		; say \127
	cmp	byte ptr [di-1],5eh ; caret present in msg?
	jne	prsar5		; ne = no
	dec	di		; remove "^"
prsar5:	stosw
	mov	ax,'72'
	stosw
	jmp	short prsar2
prsar1:	dec	di		; remove "^"
	cmp	al,20h		; printable now?
	jae	prsar7		; ae = yes
	inc	di		; restore "^"
	add	al,40H		; make it printable
prsar7:	stosb
prsar2:	mov	si,[bx].val2	; get address of second msg
	call	stms1		; add that
	mov	si,[bx].basval	; second value's address
	mov	al,[si]		; second value
	cmp	al,7fh		; DEL code?
	jne	prsar3		; ne = no
	mov	ax,'1\'		; say \127
	cmp	byte ptr [di-1],5eh ; caret present in msg?
	jne	prsar6		; ne = no
	dec	di		; remove "^"
prsar6:	stosw
	mov	ax,'72'
	stosw
	ret
prsar3:	dec	di		; remove "^"
	cmp	al,20h		; printable now?
	jae	prsar3a		; ae = yes
	inc	di		; restore "^"
	add	al,40H		; make it printable
prsar3a:stosb
	ret
prsar	endp

; Display Send and Receive char value
prsarv	proc	near
	call 	stmsg		; display leadin part of message
	mov	si,[bx].tstcel	; get address of first item
	mov	al,[si]
	xor	ah,ah
	push	bx
	call	outnum
	pop	bx
	mov	si,[bx].val2	; get address of second msg
	call	stms1		; add that
	mov	si,[bx].basval	; second value's address
	mov	al,[si]		; second value
	xor	ah,ah
	jmp	outnum
prsarv	endp


; print Send Delay and Pause
prsnd	proc	near
	call	stmsg		; display leadin part of msg
	mov	al,trans.sdelay	; Send Delay (sec)
	xor	ah,ah
	call	outnum
	mov	si,offset sndmsg2 ; second part of msg
	call	stms1		; add that
	mov	ax,spause	; Send Pause (millisec) 
	call	outnum
	mov	si,offset sndmsg3 ; last part of msg
	jmp	stms1		; add it too
prsnd	endp

; Print the handshake
prhnd:	mov	si,offset handst	; copy in initial message
	call	stms1
	mov	si,offset nonmsg	; assume no handshake
	mov	bx,portval
	cmp	[bx].hndflg,0		; Is handshaking in effect?
	jne	prh0			; ne = yes, show what we're using
	jmp	stms1			; no, say so and return
prh0:	mov	al,[bx].hands		; handshake char
	xor	ah,ah
	call	outnum			; show handshake as decimal number
	ret

; Print the Transmit Fill char
prfil:	mov	si,offset sxfilmsg	; copy in initial message
	call	stms1
	mov	si,offset nonmsg	; assume no handshake
	mov	al,script.xmitfill	; filling char
	or	al,al			; is filling in effect?
	jnz	prfil1			; nz = yes, print what we're using
	jmp	stms1			; no, say so and return
prfil1:	push	ds
	pop	es
	cld
	cmp	al,20h			; printable already?
	ja	prfil2			; a = yes
	push	ax
	mov	al,5eh			; control char
	stosb
	pop	ax
	add	al,40H			; make printable
	stosb				; put in buffer
	ret				; and return
prfil2:	cmp	al,126			; in ordinary printable range?
	ja	prfil3			; a = no
	stosb				; store in buffer
	ret
prfil3:	mov	byte ptr [di],'\'	; show as \number
	inc	di
	xor	ah,ah
	jmp	outnum			; do rest of number

; Print value from table.  BX is address of table, AX is value of variable
; Copy value of table text entry to output buffer (di), given the address
; of the table in bx and the value to compare against table values in al.
prttab	proc	near
	push	cx			; save column count
	mov	cl,[bx]			; number of entries in our table
	inc	bx			; point to the data
prtta1:	mov	si,[bx]			; length of keyword
	cmp	ax,[bx+si+2]		; value fields match?
	je	prtta2			; e = yes
	add	bx,si			; add word length
	add	bx,4			; skip count and value fields
	dec	cl			; more keywords to check?
	jnz	prtta1			; nz = yes, go to it
	pop	cx
	mov	si,offset prterr
	jmp	stms1			; copy dollar terminated string
prtta2:	push	es
	push	ds
	pop	es		; ensure es points to data segment
	mov	cx,[bx]		; get length of counted string
	push	cx		; save
	mov	si,bx
	add	si,2		; look at text
	cld
	rep	movsb
	pop	ax
	pop	es
	pop	cx		; original cx
	add	cx,ax		; advance column count, return di advanced
	ret
prttab	endp

; Display port speed

BAUDPRT	PROC	 NEAR
	mov	si,offset baudrt	; "Speed: "
	call	stms1			; display that part
	push	di
	push	cx
	call	getbaud			; read baud rate first
	pop	cx
	pop	di
	mov	bx,portval
	mov	ax,[bx].baud
	cmp	al,byte ptr bdtab	; number of table entries
	jb	bdprt5			; b = in table
	mov	si,offset unrec		; say unrecognized value
	jmp	stms1			; display text and return
bdprt5:	mov	bx,offset bdtab		; show ascii rate from table
	jmp	prttab
BAUDPRT	ENDP

; display Take/Macro COUNT
stcnt	proc	near
	call	stmsg			; display leadin part of msg
	cmp	taklev,0		; in a Take file or macro?
	jne	stcnt1			; ne = yes
	mov	si,offset nonemsg	; say none
	jmp	stms1
stcnt1:	push	bx
	mov	bx,takadr		; current Take structure
	mov	ax,[bx].takctr		; get COUNT
	pop	bx
	jmp	outnum
stcnt	endp

; display Take/Macro ARGC
starg	proc	near
	call	stmsg			; display leadin part of msg
	cmp	taklev,0		; in a Take file or macro?
	jne	starg1			; ne = yes
	mov	si,offset nonemsg	; say none
	jmp	stms1
starg1:	push	bx
	mov	bx,takadr		; current Take structure
	mov	ax,[bx].takargc		; get ARGC
	pop	bx
	jmp	outnum
starg	endp

; ALARM time
stalr	proc	near
	call	stmsg			; display leading part of msg
	push	bx			; preserve register
	xor	bx,bx			; position index
	push	ds
	pop	es
	cld
stalr1:	push	bx			; save around calls
	cmp	alrhms[bx],10		; two digits?
	jae	stalr2			; ae = yes
	mov	al,'0'
	stosb				; show leading zero
stalr2:	mov	al,alrhms[bx]		; show time component
	xor	ah,ah
	call	outnum
	pop	bx			; recover index
	inc	bx
	cmp	bx,3			; done all fields?
	jae	stalr3			; ae = yes
	mov	al,':'
	stosb
	jmp	short stalr1		; do next field
stalr3:	pop	bx
	ret
stalr	endp

; show INPUT buffer
stinbuf	proc	near
	push	si
	push	di
	push	es
	mov	di,offset rdbuf
	mov	byte ptr [di],cr	; start on the margin
	inc	di
	push	di
	call	buflog			; get INPUT buffer pointers
	pop	di
	mov	bx,cx			; length of buffer (and max offset)
	jcxz	stinb5			; z = empty
stinb1:	mov	al,es:[si]		; extract a buffer char into al
	inc	si			; move pointer to next byte
	test	al,80h			; high bit set?
	jz	stinb2			; z = no
	mov	byte ptr [di],'~'	; yes, show a tilde
	inc	di
stinb2:	and	al,7fh			; strip eighth bit
	cmp	al,' '			; control code?
	jae	stinb3			; ae = no
	mov	byte ptr [di],'^'	; yes, show caret
	inc	di
	or	al,40h			; convert char to upper case letter
stinb3:	mov	[di],al
	inc	di			; where to write next byte
	cmp	di,offset rdbuf+78	; line full?
	jb	stinb4			; b = no, have more room
	mov	word ptr [di],0a0dh	; add cr/lf
	mov	byte ptr [di+2],0
	mov	dx,offset rdbuf
	mov	di,dx
	call	prtasz
stinb4:	loop	stinb1
stinb5:	mov	word ptr [di],0a0dh	; add cr/lf
	mov	byte ptr [di+2],0
	mov	dx,offset rdbuf		; reset to start of our local buffer
	mov	di,dx
	call	prtasz
	pop	es
	pop	di
	pop	si
	xor	cx,cx
	ret
stinbuf	endp

; LNOUT - Table driven unsigned long integer (32 bit) display
; Register dx holds high order word and ax holds low order word of unsigned
; long integer to be stored in decimal. Storage area is given by DS:[DI]
; DI is incremented for each storage, null terminated.
; Table TENS holds set of double word values of ten raised to powers 0 to 9
; TENSLEN holds the number of these double words
; All registers preserved.	8 March 1987 [jrd]

lnouts	proc	near			; do lnout with thousands separator
	push	ax
	mov	al,thsep		; get thousands separator
	mov	lnoutsep,al		; tell lnout to use it
	pop	ax
	call	lnout			; compute value to di
	mov	lnoutsep,0		; clear for future callers
	ret
lnouts	endp

lnout	proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	xor	si,si		; flag to say start printing (no leading 0's)
	mov	cx,tenslen	; number of table entries
lnout1:	push	cx		; save loop counter
	mov	bx,cx		; index into tens double word table
	dec	bx		; index starts at zero
	add	bx,bx
	add	bx,bx		; bx times four (double words to bytes)
	xor	cx,cx		; cx is now a counter of subtractions

lnout2:	cmp	dx,word ptr tens[bx+2]  ; pattern 10**(bx/4), high order part
	jb	lnout4		; b = present number is less than pattern
	ja	lnout3		; a = present number is larger than pattern
	cmp	ax,word ptr tens[bx] ; high words match, how about lows
	jb	lnout4		; b = present number is smaller than pattern
lnout3:	sub	ax,word ptr tens[bx]	; subtract low order words
	sbb	dx,word ptr tens[bx+2]	; subtract high order words, w/borrow
	inc	cl		; count number of subtractions
	inc	si		; flag to indicate printing needed
	jmp	short lnout2	; try again to deduct present test pattern

lnout4:	or	bx,bx		; doing least significant digit?
	jz	lnout5		; z = yes, always print this one
	or	si,si		; should we print?
	jz	lnout6		; z = no, not yet
lnout5:	add	cl,'0'		; get number of subtractions
	mov	[di],cx		; store it (ch is still zero), asciiz
	inc	di
	cmp	bx,9*4		; places for thousands separator?
	je	lnout5a		; e = yes
	cmp	bx,6*4
	je	lnout5a
	cmp	bx,3*4
	jne	lnout6		; ne = no
lnout5a:mov	cl,lnoutsep	; get thousands separator
	xor	ch,ch
	jcxz	lnout6		; z = none
 	mov	word ptr [di],cx
	inc	di
lnout6:	pop	cx		; recover loop counter
	loop	lnout1
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
lnout	endp 

code	ends
	end
