	NAME	mssker
; File MSSKER.ASM
	include mssdef.h
; Edit history
; 20 Mar 1998 version 3.16
; Last edit
; 23 Apr 1999
;****************************** Version 3.16 ***************************** 
; KERMIT, Celtic for "free" 
;
; The name "Kermit" is a registered trade mark of Henson Associates, Inc.,
; used by permission.
;
;	MS-DOS Kermit Program Version 3.16  alpha, Feb 98
;	MS-DOS Kermit Program Version 3.15  15 Sept 97
;	MS-DOS Kermit Program Version 3.14, 18 Jan 95
;	MS-DOS Kermit Program Version 3.13, 8 July 93
;	MS-DOS Kermit Program Version 3.12, Feb 1992
;	MS-DOS Kermit Program Version 3.11, 6 Sept 1991
;	MS-DOS Kermit Program Version 3.10, 2 March 1991
;	MS-DOS Kermit Program Version 3.02, development for 3.10, 1990-91
;	MS-DOS Kermit Program Version 3.01, 20 March 1990
;	MS-DOS Kermit Program Version 3.00, 16 Jan 1990 
;	Kermit-MS Program Version 2.32, 11 Dec 1988 
;	Kermit-MS Program Version 2.31, 1 July 1988
;       Kermit-MS Program Version 2.30, 1 Jan 1988
;	Kermit-MS Program Version 2.29, 26 May 1986, plus later revisions.
;       Kermit-MS Program Version 2.27, December 6,1984
;       Kermit-MS Program Version 2.26, July 27, 1984
;       PC-Kermit Program Version 1.20, November 4, 1983
;       PC-Kermit Program Version 1.0, 1982
; 
;       Based on the Columbia University KERMIT Protocol.
; 
;	Copyright (C) 1982, 1999, Trustees of Columbia University in the 
;	City of New York.  The MS-DOS Kermit software may not be, in whole 
;	or in part, licensed or sold for profit as a software product itself,
;	nor may it be included in or distributed with commercial products
;	or otherwise distributed by commercial concerns to their clients 
;	or customers without written permission of the Office of Kermit 
;	Development and Distribution, Columbia University.  This copyright 
;	notice must not be removed, altered, or obscured.
;
;       Original Authors (versions 1.0 through 2.28):
;         Daphne Tzoar, Jeff Damens
;         Columbia University Center for Computing Activities
;         612 West 115th Street
;         New York, NY  10025
;
;       Present author (version 2.29, 2.30, 2.31, 2.32, 3.00, 3.01, 3.02,
;			3.10, 3.11, 3.12, 3.13, 3.14):
;         Joe R. Doupnik
;	  Dept of EE, and CASS
;	  Utah State University
;	  Logan, UT  84322, USA
;	  E-Mail: JRD@CC.USU.EDU (Internet), JRD@USU (BITNET)
; 
; Special thanks to Christine Gianone, Frank da Cruz, Bill Catchings, 
; Bernie Eiben, Vace Kundakci, Terry Kennedy, Jack Bryans, and many many
; others for their help and contributions.

	public	dosnum, curdsk, fpush, isfile, sbrk, crun, errlev
	public	takrd, takadr, taklev, filtst, maxtry, dskspace, thsep, tdfmt
	public	lclsusp, lclrest, lclexit, cwdir, kstatus, verident, cdsr
	public	spath, patched, getenv, psp, dosctty, patchid, retcmd
	public	tcptos, emsrbhandle, emsgshandle, apctrap, cboff, cbrestore
	public	startup, cmdfile, inidir, tmpbuf, malloc, dostemp
	public	breakcmd, xms, xmsrhandle, xmsghandle, xmsep

env	equ	2CH			; environment address in psp
cline	equ	80H			; offset in psp of command line
braceop	equ	7bh			; opening curly brace
bracecl	equ	7dh			; closing curly brace

_STACK	SEGMENT				; our stack
	dw	1500+1024 dup (0)		; for TCP code
	dw	200 dup(0)		; for main Kermit code
msfinal	label	word			; top of stack
_STACK	ENDS

data   segment
	extrn	buff:byte, comand:byte, flags:byte, trans:byte,	prmptr:word
	extrn	machnam:byte, decbuf:byte, rstate:byte, sstate:byte
	extrn	mcctab:byte, rdbuf:byte, takeerror:byte, macroerror:byte
	extrn	dos_bottom:byte, domath_ptr:word, domath_cnt:word
	extrn	domath_msg:word, oldifelse:byte, retbuf:byte

verident label	byte
	verdef
patchena db	'$patch level'
patchid	db	' 0 $'
copyright db	cr,lf
	db	'Copyright (C) Trustees of Columbia University 1982, 2000.'
	db	cr,lf,'$'
copyright2 db	cr,lf,lf
 db ' Copyright (C) 1982, 2000, Trustees of Columbia University in the'
 db	cr,lf
 db ' City of New York.  The MS-DOS Kermit software may not be, in whole' 
 db	cr,lf
 db ' or in part, licensed or sold for profit as a software product itself,'
 db	cr,lf
 db ' nor may it be included in or distributed with commercial products'
 db	cr,lf
 db ' or otherwise distributed by commercial concerns to their clients'
 db	cr,lf
 db ' or customers without written permission of the Office of Kermit' 
 db	cr,lf
 db ' Development and Distribution, Columbia University.  This copyright' 
 db	cr,lf
 db ' notice must not be removed, altered, or obscured.'
 db	cr,lf,'$'

hlpmsg	db 	cr,lf,'Type ? or HELP for help',cr,lf,'$'
crlf    db      cr,lf,'$'
patpmt	db	0
ermes1	db	cr,lf,'?More parameters are needed$'
ermes2	db	cr,lf,'?Unable to initialize memory$'
ermes3  db      cr,lf,'?Command canceled$'
ermes4	db	'?Unable to change directory',0			; asciiz
ermes5	db	cr,lf,'?Unable to complete initialization process$'
ermes6	db	cr,lf,'Ignoring patch file.'
	db	' Version number mismatch.',cr,lf,'$'
ermes7	db	cr,lf,'Patch file was not found',cr,lf,'$'
ermes8	db	cr,lf,'Fatal error in patch file! Please remove PATCH '
	db	'command.',cr,lf,'$'
erms30	db	cr,lf,'?Passed maximum nesting level for TAKE command$'
erms31	db	cr,lf,'?Cannot find Take-file: $'
erms34	db	cr,lf,'This program requires DOS 2.0 or above$'
erms37	db	cr,lf,'?Unable to execute command interpreter $'
erms38	db	cr,lf,' Not an 8250 UART at this COM port$'
erms39	db	cr,lf,' UART tests ok$'
badnam	db	cr,lf,'?No such file(s)$'

ifdef	no_graphics
nographics db	'  No graphics$'
endif	; no_graphics
ifdef	no_network
nonet	db	'  No network$'
else
ifdef	no_tcp
notcp	db	'  No tcp/ip$'
endif	; no_tcp
endif	; no_network

ifdef	no_terminal
noterm	db	'  No terminal$'
endif	; no_terminal

msgif	db	cr,lf,' IF extensions are ',0
msggraph db	cr,lf,' Graphics is ',0
msgtcpip db	cr,lf,' TCP/IP is ',0
msgnetwork db	cr,lf,' Network is ',0
msgterm	db	cr,lf,' Terminal emulation is ',0
msgnot	db	'not ',0
msgavail db	'available$',0
xms	xmsreq <>			; XMS request block
takepause db   ' Take debug, press a key to continue, Control-C to quit$'
data	ends

data1	segment
filmsg	db	' Filename$'
dskmsg	db	' disk drive letter or Return$'
pthmsg	db	' Name of new working directory and/or disk$'
runmsg	db	' program name and command line$'
pathlp	db	' optional path for file mskermit.pch$'
stophlp	db	' Status value to be returned  msg, nothing if no new value$'
setenvhlp db	' name=string  phrase to be put into DOS master environment$'

tophlp	db	cr,lf
	db	'  Ask, Askq (read keybd to variable) '
	db	'  Pause [secs], MPause/Msleep [millisec]'
	db	cr,lf
	db	'  APC text  send App Prog Cmd to host'
	db	'  Pop, End (exit current macro/Take file)'
	db	cr,lf
	db	'  Bye      (logout remote server)    '
	db	'  Push     (go to DOS, keep Kermit)'
	db	cr,lf
	db      '  C or Connect  (become a terminal)  '
        db      '  Quit     (leave Kermit)'
	db	cr,lf
	db	'  Check (graphics, tcp/ip, networks) '
        db      '  R or Receive  (opt local filename)'
	db	cr,lf
	db	'  Clear   (Input, comms recv buffer) '
	db	'  Read (line from a file to variable)'
	db	cr,lf
	db	'  Close    (logging and script file) '
	db	'  Reget    (get rest of a partial file)'
	db	cr,lf
	db	'  CLS (clear screen at command level)'
	db	'  Reinput  (script Input, reread buffer)'
	db	cr,lf
	db	'  CWD or CD  (change dir &/or disk)  '
	db	'  Remote   (prefix for commands)'
	db	cr,lf
	db	'  Decrement/Increment variable number'
	db	'  Replay   (file through term emulator)'
	db	cr,lf
	db	'  Define/Assign   (a command macro)  '
	db	'  Reset    (clock)'
	db	cr,lf
	db	'  Delete   (a file)                  '
	db	'  Retrieve (get files, delete source) '
	db	cr,lf
	db	'  Dial     (phone number)            '
	db	'  Return text (from macro to \v(return))'
	db	cr,lf		 
	db	'  Directory (filepsec)               '
	db	'  Run      (a program)'
	db	cr,lf
	db	'  Disable  (selected server commands)'
        db      '  S, Send, Resend, Psend  local new-name'
	db	cr,lf
	db	'  Echo text (show line on screen)    '
	db	'  Server [timeout] (become a server)'
	db	cr,lf
	db	'  Else     (follows IF statment)     '
        db      '  Set      (most things)'
	db	cr,lf
	db	'  Enable   (selected server commands)'
	db	'  Setenv   name=string to DOS environment'
	db	cr,lf
	db      '  EXIT     (leave Kermit)            '
	db	'  Show     (most things)'
	db	cr,lf
	db	'  Finish   (to remote server)        '
	db	'  Sleep time  (wait, no comms echos)'
	db	cr,lf
	db	'  For var start stop step {commands} '
	db	'  Space    (free on current disk)'
	db	cr,lf
	db	'  Get      (remote file opt new name)'
	db	'  Stop     (exit all Take files & macros)'
	db	cr,lf
	db	'  Getc  (read 1 byte from kbd to var)'
	db	'  Switch index {:label, cmds,...}'
	db	cr,lf
	db	'  GetOK    (get Yes, OK, No response)'
	db	'  Take     (commands from a file)'
	db	cr,lf
	db	'  Goto    (label, Take file or Macro)'
	db	'  Telnet host port  NEW or RESUME'
	db	cr,lf
	db	'  Hangup   (drop DTR, hang up phone) '
	db	'  Test COM1 ... COM4 (check for UART)'
	db	cr,lf
	db	'  If [not] <condition> <command>     '
	db	'  Transmit filespec [prompt] (raw upload)'
	db	cr,lf
	db	'  I or Input [timeout] text (scripts)'
	db	'  Type     (a file)'
	db	cr,lf
	db	'  INTRO  introduction to Kermit      '
	db	'  Version  (show version and copyright)'
	db	cr,lf
	db	'  Log (Packet, Session, Transaction) '
	db	'  Wait [timeout] on modem \cd \cts \dsr'
	db	cr,lf
	db	'  Mail     (file to host Mailer)     '
	db	'  While <condition> {commands}'
	db	cr,lf
	db	'  Minput   (Input with many patterns)'
	db	'  Write/Writeln  FILE or log file   text'
	db	cr,lf
	db	'  Move    (send files, delete source)'
	db	'  Undefine  (macro or array element)'
	db	cr,lf
	db	'  Open Read/Write/Append file        '
	db	'  Xecho string  (without leading cr/lf)'
	db	cr,lf
	db	'  Output text      (to comms channel)'
	db	'  Xif <condition> {cmds} ELSE {cmds}'
	db	'$'

qckhlp	db	cr,lf
	db	'MS-DOS Kermit 3.16, 31 Oct 2000, Copyright (C) 1982, 2000,'
	db	cr,lf
	db	'Trustees of Columbia University in the City of New York.'
	db	cr,lf,lf
	db	'Important commands (type the command, then press the'
	db	' Enter key):'
	db	cr,lf,lf
	db	'  INTRO    - For an introduction to MS-DOS Kermit.'
	db	cr,lf
	db	'  VERSION  - For version and copyright information.'
	db	cr,lf
	db	'  EXIT     - To leave MS-DOS Kermit.'
	db	cr,lf,lf

	db	'Press the question-mark (?) key for context-sensitive'
	db	' help'
	db	cr,lf
	db	'  at any point within a command.'
	db	cr,lf,lf

	db	'DOCUMENTATION:'
	db	cr,lf

	db	'  "Using MS-DOS Kermit" by Christine M. Gianone,'
	db	cr,lf
	db	'  Digital Press / Butterworth-Heinemann, 1992, ISBN'
	db	' 1-55558-082-3.'
	db	cr,lf
  	db	'  Please purchase this manual - it shows you how to use'
	db	' the software,'
	db	cr,lf
	db	'  it answers your questions, and its sales support the'
	db	' Kermit effort.'
	db	cr,lf
	db	'  To order, call +1 212 854-3703 or +1 800 366-2665.'
	db	cr,lf,lf
	
	db	'And see these files on your Kermit diskette for additional'
	db	' information:'
	db	cr,lf

	db	'  KERMIT.UPD - New features and updates.'
	db	cr,lf

	db	'  KERMIT.BWR - Hints and tips, troubleshooting information,'
	db	' etc.'
	db	cr,lf
	db	'  KERMIT.HLP - Concise descriptions of each command.'
	db	cr,lf,'$'

ifndef	no_terminal
intrhlp	db cr,lf
	db '                    Introduction to MS-DOS Kermit',cr,lf
	db 'o An MS-Kermit command is a line of words separated by spaces and'
	db ' ending with',cr,lf,'  a carriage return <the Enter key>.'
	db '  Example: SET SPEED 2400<Enter>',cr,lf
	db 'o Most words can be abbreviated and can be completed by pressing'
	db ' the Esc key.',cr,lf
	db '  Example: SET SPE 24<Enter>  or even  SET SPE<Esc> 24<Esc>'
	db '<Enter>',cr,lf
	db 'o Help (detailed, specific): press the "?" key where a word would'
	db ' appear.',cr,lf
	db 'o Edit lines using the Backspace key to delete characters,'
	db ' Control-W to delete',cr,lf
	db '  words, and Control-U to delete the line.  Control-C cancels the'
	db ' command.',cr,lf
	db 'o Frequently used MS-Kermit commands:',cr,lf
	db '  EXIT           Leave the Kermit program. QUIT does the same'
	db ' thing.',cr,lf
	db '  SET            PORT, PARITY, SPEED, TERMINAL and many other'
	db ' parameters.',cr,lf
	db '  SHOW           Display groups of important parameters.'
	db ' SHOW ? for categories.',cr,lf,lf
	db '  CONNECT        Establish a terminal connection to a remote'
	db ' system or a modem.',cr,lf
	db '  Control-'
		; labels where Connect mode escape printable goes (twice)
intrhlp1 db '  C    (Control-'
intrhlp2 db ' '
	db '  followed by "C")  Return to MS-Kermit> prompt.',cr,lf,lf
	db '  SEND filename  Send the file(s) to Kermit on the other'
	db ' computer.',cr,lf
	db '  RECEIVE        Receive file(s), SEND them from Kermit on the'
	db ' other computer.',cr,lf
	db '  GET filename   Ask the remote Kermit server to send the file(s)'
	db ' to us.',cr,lf
	db '  FINISH         Shut down remote Kermit but stay logged into'
	db ' remote system.',cr,lf
	db '  BYE            FINISH and logout of remote system and exit'
	db ' local Kermit.',cr,lf
	db 'o Common startup sequence: SET SPEED 9600, CONNECT, login, start'
	db ' remote Kermit,',cr,lf
	db '  put it into Server mode, escape back with Control-C, transfer'
	db ' files with',cr,lf
	db '  SEND x.txt, GET b.txt, BYE.'

	db	cr,lf,lf
	db ' MS-DOS Kermit commands, a functional summary:'
	db	cr,lf
	db	cr,lf,' Local file management:         '
	db	'Kermit program management:'
	db	cr,lf,'   DIR    (list files)          '
	db	'  EXIT     (from Kermit, return to DOS)'
	db	cr,lf,'   CD     (change directory)    '
	db	'  QUIT     (same as EXIT)'
	db	cr,lf,'   DELETE (delete files)        '      
	db	'  TAKE     (execute Kermit commands from file)'
	db	cr,lf,'   RUN    (a DOS command)       '
	db	'  CLS      (clear screen)'
	db	cr,lf,'   TYPE   (display a file)      '
	db	'  PUSH     (enter DOS, EXIT returns to Kermit)'
	db	cr,lf,'   SPACE  (show disk space)     '
	db	'  Ctrl-C   (interrupt a command)'
	db	cr,lf
	db	cr,lf,' Communication settings:        '
	db	'Terminal emulation:'
	db	cr,lf,'   SET PORT, SET SPEED          '
	db	'  CONNECT  (begin terminal emulation)'
	db	cr,lf,'   SET PARITY                   '
	db	'  HANGUP   (close connection)'
	db	cr,lf,'   SET FLOW-CONTROL             '
	db	'  Alt-X    (return to MS-Kermit> prompt)'
	db	cr,lf,'   SET LOCAL-ECHO               '
	db	'  SET KEY  (key mapping)'
	db	cr,lf,'   SET ? to see others          '
	db	'  SET TERMINAL TYPE, BYTESIZE, other parameters'
	db	cr,lf,'   SHOW COMMUNICATIONS, MODEM   '
	db	'  SHOW TERMINAL, SHOW KEY'
	db	cr,lf
	db	cr,lf,' File transfer settings:        '
	db	cr,lf,'   SET FILE CHARACTER-SET name  '
	db	'  SET TRANSFER CHARACTER-SET'
	db	cr,lf,'   SET FILE TYPE TEXT, BINARY   '
	db	'  SET SEND or RECEIVE parameters'
	db	cr,lf,'   SET FILE ? to see others     '
	db	'  SET WINDOWS (sliding windows)'
	db	cr,lf,'   SHOW FILE                    '
	db	'  SHOW PROTOCOL, SHOW STATISTICS'
	db	cr,lf,lf
	db	cr,lf,' Kermit file transfer:           '
	db	'ASCII file transfer:'
	db	cr,lf,'   SEND files (to RECEIVE)      '
	db	'  LOG SESSION, CLOSE SESSION (download)'
	db	cr,lf,'   RECEIVE    (from SEND)       '
	db	'  TRANSMIT (upload)'
	db	cr,lf,'   MAIL files (to RECEIVE)      '
	db	'  SET TRANSMIT parameters'
	db	cr,lf
	db	cr,lf,' Using a Kermit server:         '
	db	'Being a kermit server:'
	db	cr,lf,'   GET files    (from server)   '
	db	'  SET SERVER TIMEOUT or LOGIN'
	db	cr,lf,'   SEND or MAIL   (to server)   '
	db	'  ENABLE or DISABLE features'
	db	cr,lf,'   REMOTE command (to server)   '
	db	'  SERVER'
	db	cr,lf,'   FINISH, LOGOUT, BYE          '
	db	'  SHOW SERVER'
	db	cr,lf
	db	cr,lf,' Script programming commands:   '
	db	cr,lf,'   INPUT, REINPUT secs text     '
	db	'  :label, GOTO label'
	db	cr,lf,'   OUTPUT text                  '
	db	'  IF [ NOT ] condition command'
	db	cr,lf,'   DECREMENT or INCREMENT variable number'
	db	cr,lf,'   ASK or ASKQ variable prompt  '
	db	'  OPEN READ (or WRITE or APPEND) file'
	db	cr,lf,'   DEFINE variable or macro     '
	db	'  READ variable-name'
	db	cr,lf,'   ASSIGN variable or macro     '
	db	'  WRITE file-designator text'
	db	cr,lf,'   [ DO ] macro arguments       '
	db	'  CLOSE READ or WRITE file or logfile'
	db	cr,lf,'   ECHO text                    '
	db	'  END or POP from macro or file'
	db	cr,lf,'   PAUSE time                   '
	db	'  STOP all macros and command files'
	db	cr,lf,'   SLEEP time  no comms sampling'
	db	'  WRITE file-designator text'
	db	cr,lf,'   WAIT time modem-signals      '
	db	'  SHOW VARIABLES, SHOW SCRIPTS, SHOW MACROS'
	db	cr,lf
	db ' Use "?" within comands for help on what fits that word.$'
endif	;; ifndef no_terminal

kpath	db	64 dup (0)		; Kermit's paths to Kermit files
data1	ends

data	segment

comtab  db	106 - 1			; COMND tables
	mkeyw	'APC',scapc
	mkeyw	'Asg',assign		; synonym
	mkeyw	'Ask',ask
	mkeyw	'Askq',askq
	mkeyw	'_assign',hide_assign	; hidden, expand destination name
	mkeyw	'Assign',assign
	mkeyw	'Break',breakcmd
	mkeyw	'Bye',bye
	mkeyw	'C',telnet
	mkeyw	'CD',cwdir
	mkeyw	'Clear',scclr
	mkeyw	'Close',clscpt
	mkeyw	'Check',check
	mkeyw	'Comment',comnt
	mkeyw	'Connect',telnet
	mkeyw	'Continue',continue
	mkeyw	'CLS',cls
	mkeyw	'CWD',cwdir
	mkeyw	'Declare',declare
	mkeyw	'_define',hide_define	; hidden, expand destination name
	mkeyw	'Define',dodef
	mkeyw	'Dec',decvar		; decrement vs declare resolver
	mkeyw	'Decrement',decvar
	mkeyw	'Delete',delete
	mkeyw	'Dial',dial
	mkeyw	'Directory',direct
	mkeyw	'Disable',srvdsa
	mkeyw	'Do',docom
	mkeyw	'Echo',scecho
	mkeyw	'Else',elsecmd
	mkeyw	'Enable',srvena
	mkeyw	'End',popcmd
	mkeyw	'Exit',exit
	mkeyw	'Finish',finish
	mkeyw	'_forinc',_forinc	; hidden, FOR statement incrementer
	mkeyw	'For',forcmd
	mkeyw	'Forward',sforward	; hidden "Forward" goto
	mkeyw	'Get',get
	mkeyw	'G',get			; hidden synomym for Get
	mkeyw	'Ge',get		; ditto
	mkeyw	'Getc',getc
	mkeyw	'Getok',getok
	mkeyw	'goto',sgoto
	mkeyw	'H',help
	mkeyw	'Hangup',dtrlow
	mkeyw	'Help',help
	mkeyw	'If',ifcmd
	mkeyw	'I',scinp
	mkeyw	'Increment',incvar
	mkeyw	'Input',scinp
	mkeyw	'INTRO',intro
	mkeyw	'Local',localmac
	mkeyw	'Log',setcpt
	mkeyw	'Mail',mail
	mkeyw	'Minput',scminput
	mkeyw	'Move',move
	mkeyw	'Mpause',scmpause
	mkeyw	'Msleep',scmpause
	mkeyw	'Open',vfopen
	mkeyw	'O',scout		; hidden synomym for OUTPUT
	mkeyw	'Output',scout
	mkeyw	'Pause',scpau
	mkeyw	'Pop',popcmd
	mkeyw	'Psend',psend
	mkeyw	'Push',dopush
	mkeyw	'Quit',exit
	mkeyw	'R',read
	mkeyw	'Read',vfread
	mkeyw	'Receive',read
	mkeyw	'Reget',reget
	mkeyw	'Reinput',screinp
	mkeyw	'Remote',remote
	mkeyw	'Replay',replay
	mkeyw	'Resend',resend
	mkeyw	'Reset',reset
	mkeyw	'Retrieve',retrieve
	mkeyw	'Return',retcmd
	mkeyw	'Run',run
	mkeyw	'S',send
	mkeyw	'Send',send
	mkeyw	'Server',server
	mkeyw	'Set',setcom
	mkeyw	'Setenv',setenv
	mkeyw	'Show',showcmd
	mkeyw	'Sleep',scsleep
	mkeyw	'Space',chkdsk
	mkeyw	'Statistics',shosta
	mkeyw	'Stay',stay
	mkeyw	'Stop',takeqit
	mkeyw	'Switch',switch
	mkeyw	'Take',take
	mkeyw	'Test',testcom
	mkeyw	'Transmit',scxmit
	mkeyw	'xmit',scxmit		; hidden synonym
	mkeyw	'Type',typec
	mkeyw	'Undefine',undefine
	mkeyw	'Version',prvers
	mkeyw	'Wait',scwait
	mkeyw	'While',whilecmd
	mkeyw	'Write',write
	mkeyw	'Writeln',writeln
	mkeyw	'Xecho',xecho
	mkeyw	'XIF',xifcmd
	mkeyw	':',comnt		; script labels, do not react
	mkeyw	'Patch',patch
	mkeyw	'Nopush',pushproc	; must be hidden


ifdef	no_network
shotab	db	19 - 2			; SHOW keyword
else
ifndef	no_tcp
shotab	db	19			; SHOW keyword
else
shotab	db	19 - 1			; SHOW keyword
endif	; no_tcp
endif	; no_network
	mkeyw	'array',sharray
	mkeyw	'Communications',shcom
	mkeyw	'Control-prefixing',cntlsho
	mkeyw	'File',shfile
	mkeyw	'Key',shokey
	mkeyw	'Logging',shlog
	mkeyw	'Macros',shomac
	mkeyw	'Memory',shmem
	mkeyw	'Modem',shomodem
ifndef	no_network
	mkeyw	'Network',shownet
endif	; no_network
	mkeyw	'Protocol',shpro
	mkeyw	'Scripts',shscpt
	mkeyw	'Server',shserv
ifndef	no_tcp
	mkeyw	'Sessions',sesdisp	; TCP/IP
endif	; no_tcp
	mkeyw	'Statistics',shosta
	mkeyw	'Status',status
	mkeyw	'Terminal',shterm
	mkeyw	'Translation',shorx
	mkeyw	'Variables',shovar
					; Kermit initing from Environment
nulprmpt db	0,0,0			; null prompt
initab	db	8			; Environment phrase dispatch table
	mkeyw	'INPUT-buffer-length',setinpbuf ; Script INPUT buffer length
	mkeyw	'Rollback',setrollb	; number of Terminal rollback screens
	mkeyw	'Width',setwidth	; columns in rollback buffer, def=80
	mkeyw	'COM1',com1port
	mkeyw	'COM2',com2port
	mkeyw	'COM3',com3port
	mkeyw	'COM4',com4port
	mkeyw	'Path',mkkpath

featab	db	5		; Compiled-in feature list for CHECK cmd
	mkeyw	'if',5
	mkeyw	'graphics',1
	mkeyw	'networks',3
	mkeyw	'tcp',2
	mkeyw	'terminals',4

chktab	db	4		; table of comm ports for TEST
	mkeyw	'COM1',1
	mkeyw	'COM2',2
	mkeyw	'COM3',3
	mkeyw	'COM4',4

patched	db	1		; 1 = enable patching; 0 = disable or done

	even
lclsusp	dw	0		; address of routine to call when going to DOS
lclrest	dw	0		; address of routine to call when returning
lclexit	dw	0		; address of routine to call when exiting
tcptos	dw	0		; top of stack for TCP code
ssave	dd	0		; Original SS:SP when doing Command.com
in3ad	dw	0,0		; Original break interrupt addresses
ceadr	dd	0		; DOS Critical Error interrupt address
orgcbrk	db	0		; original Control-Break Check state
psp	dw	0		; segment of Program Segment Prefix
exearg	dw	0		; segment addr of environment (filled in below)
	dd	0		; ptr to cmd line (filled in below)
	dw	5ch,0,6ch,0	; our def fcb's; segment filled in later
emsrbhandle dw	-1		; EMS rollback handle, -1 means invalid
emsgshandle dw	-1		; EMS graphics handle, -1 means invalid
xmsrhandle dw	0		; XMS rollback buffer handle, 0 = invalid
xmsghandle dw	0		; XMS graphics memory buffer handle
xmsep	dd	0		; XMS manager entry point, 0 = invalid
dosnum	dw	0		; dos version number, major=low, minor=high
dosctty	db	0		; !=0 if DOS attempts using our comms line
curdsk	db	0		; Current disk
origd	db	0		; Original disk
orgdir	db	64 dup (0)	; original directory on original disk
startup	db	64 dup (0)	; our startup directory
cmdfile db	64 dup (0)	; path and file of last TAKE
inidir	db	64 dup (0)	; mskermit.ini directory (ends on \)
taklev	db	0		; Take levels
takadr	dw	takstr-(size takinfo) ; Pointer into structure
takstr	db	(size takinfo) * maxtak dup(0)
cmdlinetake db	0		; non-zero if have DOS command line cmds
filtst	filest	<>		; file structure for procedure isfile
maxtry	db	defmxtry	; Retry limit for data packet send/rcv
ininm2	db	'MSKERMIT.INI',0 ; init file name

ifdef	nls_portuguese
ptchnam	db	'MSRP315.PCH',0	; Portuguese
else
ifdef	no_terminal
ifdef	no_network
ptchnam	db	'MSRL315.PCH',0	; MSK Lite
else
ptchnam	db	'MSRN315.PCH',0	; MSK medium-lite
endif
else

ifdef	no_network
ptchnam	db	'MSRM315.PCH',0	; MSK medium
else
ptchnam	db	'MSR315.PCH',0	; main patch file name (Version dependent)
endif
endif
endif

ptchnam2 db	'MSKERMIT.PCH',0 ; alternate patch file name
delcmd	db	' del ',0	; delete command
dircmd	db	' dir ',0	; directory command
typcmd	db	' type ',0	; type command
kerenv	db	'KERMIT=',0,0	; Kermit= environment variable, + 2 nulls
pthnam	db	'PATH='		; Path environment variable
pthlen	equ	$-pthnam	;  length of that string
pthadr	dw	0		; offset of PATH= string
dostempname db	'TEMP='		; DOS TEMP= enviroment string
dostempnlen equ $ - dostempname ; string length
dostemp db	' > ',60 dup (0) ; " > " contents of TEMP=  "\$kermit$.tmp"
tmpname db	'$kermit$.tmp',0 ;   path must start on dostemp+3

slashc	db	' /c '		; slashc Must directly preceed tmpbuf
tmpbuf	db	128 dup (0)	; temp space for file names and comments
cmspnam	db	'COMSPEC='	; Environment variable
cmsplen	equ	$-cmspnam
cmspbuf	db	'\command.com',30 dup (0) ; default name plus additional space
shellnam db	'SHELL='	; Environment variable
shellen	equ	$-shellnam
shellbuf db	40 dup (0)	; buffer for name
eexit	db	cr,'exit',cr
leexit	equ	$-eexit
onexit	db	8,0,'ON_EXIT',CR ; <length>on_exit macro name
onexlen	equ	$-onexit-2-1	 ; length of name
mfmsg	db	'?Not enough memory to run Kermit$'
mf7msg	db	'?Attempted to allocate a corrupted memory area$'
spcmsg	db	' bytes available on drive '
spcmsg1	db	' :',cr,lf,0
spcmsg2	db	cr,lf,' Drive '
spcmsg3	db	' : is not ready',0
moremsg	db	'... more, press a key to continue ...$'
errlev	db	0		; DOS errorlevel to be returned
kstatus	dw	0		; command execution status (0 = success)
thsep	db	0		; thousands separator
tdfmt	db	0		; date/time format code
totpar	dw	0
apctrap	db	0		; disable command if done via APC
pttemp	db	0		; Patch temp variable
temp	dw	0
tempptr dw	0
seekptr	dw	0,0		; pointer for lseek in takeread
nopush_flag db	0		; nz = stops push/run, keep hidden

segstr	db	'ABCDEFG'	; segment "names" for patcher
lsegstr	equ	$-segstr
	even
segtab	dw	code		; segment values for patcher
	dw	code1
	dw	code2
	dw	data
	dw	data1
	dw	_TEXT
	dw	dgroup
data   ends

code1	segment
	extrn	fparse:far, iseof:far, strlen:far, strcpy:far, prtscr:far
	extrn	strcat:far, prtasz:far, domath:far, decout:far, poplevel:far
	assume	cs:code1
code1	ends

code	segment
	extrn	reget:near, mail:near, shovar:near, scapc:near
	extrn	bye:near, telnet:near, finish:near, comnd:near, prompt:near
	extrn	read:near, remote:near, send:near, status:near, get:near
	extrn	serrst:near, setcom:near, dtrlow:near, cmblnk:near, getc:near
	extrn	clscpi:near, clscpt:near, scpini:near, setrollb:near
	extrn	dodef:near, setcpt:near, docom:near, shomodem:near
	extrn	server:near, lclini:near, shokey:near, shomac:near, shosta:near
	extrn	shserv:near, initibm:near, forcmd:near, _forinc:near
	extrn	shorx:near, lnout:near, lnouts:near, scminput:near
	extrn	scout:near,scinp:near,scpau:near,scecho:near,scclr:near
	extrn	scxmit:near, scwait:near, srvdsa:near, srvena:near
	extrn	shcom:near, shlog:near, shpro:near, shterm:near, shscpt:near
	extrn	shfile:near, takclos:far, ask:near, askq:near
	extrn	assign:near, sgoto:near, screinp:near, ifcmd:near, write:near
	extrn	setinpbuf:near, shmem:near, replay:near, xifcmd:near
	extrn	com1port:near, com2port:near, com3port:near
	extrn	com4port:near, popcmd:near, mprompt:near, locate:near
	extrn	vfopen:near, vfread:near, decvar:near, incvar:near
	extrn	setwidth:near, scmpause:near, whilecmd:near, reset:near
	extrn	getok:near, cntlsho:near, shownet:near, ctlu:near
	extrn	resend:near, psend:near, tstport:near, scsleep:near
	extrn	takopen_file:far, takopen_macro:far, sforward:near
	extrn	hide_assign:near, hide_define:near, dial:near, declare:near
	extrn	sharray:near, localmac:near, switch:near, move:near
	extrn	retrieve:near, undefine:near, xecho:near, writeln:near
ifndef	no_tcp
	extrn	sesdisp:near
endif	; no_tcp

        assume  cs:code, ds:data, ss:_stack, es:nothing
 
START	PROC	FAR
	mov	ax,data			; initialize DS
        mov	ds,ax
	mov	psp,es			; remember psp address
	mov	ah,dosver		; get DOS version number (word)
	int	dos
	xchg	ah,al			; major version to ah
	mov	dosnum,ax		; remember dos version
	cmp	ax,200h			; earlier than DOS 2.0?
	jge	start1			; ge = no
	mov	ah,prstr
	mov	dx,offset erms34	; complain
	int	dos
	push	psp			; set up exit for DOS 1
	xor	ax,ax			; and the IP
	push	ax			; make return addr of psp:0 for DOS 1
	ret				; and return far to exit now
start1:	call	memini			; initialize our memory usage
	mov	ah,setdma		; set disk transfer address
	mov	dx,offset buff
	int	dos
	call	far ptr setint		; ^C, DOS critical error interrupts
	mov	ah,gcurdsk		; get current disk
	int	dos
	inc	al			; make 1 == A (not zero)
	mov	curdsk,al
	mov	origd,al		; remember original disk we started on
	mov	si,offset orgdir     ; place for directory path w/o drive code
	add	al,'A'-1		; make al alphabetic disk drive again
	mov	[si],al			; put it into original path descriptor
	inc	si
	mov	byte ptr [si],':'	; add drive specifier too
	inc	si
	mov	byte ptr [si],'\'	; add root indicator as well
	inc	si
	mov	ah,gcd			; get current directory (path really)
	xor	dl,dl			; use current drive
	int	dos
	call	getpath			; get the path from the environment
	call	gettsep			; get thousands separator, t/date code
	mov	ah,gswitch
	xor	al,al			; pick up switch character
	int	dos
	mov	slashc+1,dl
	and	maxtry,3fh		; limit # packet retries
	mov	bx,4			; PRN handle for DOS
	mov	ah,ioctl
	mov	al,0			; get info to 
	int	dos
	or	dl,20h			; turn on binary mode
	xor	dh,dh
	mov	ah,ioctl
	mov	al,1			; set info
	int	dos
	call	getcsp			; get comspec from environment
	call	getssp			; get shellspec from environment
	call	getdostemp		; get DOS TEMP= string
	mov	dx,offset dostemp
	call	strlen			; length so far
	cmp	cx,3			; just ' > '?
	je	start1c			; e = yes, no TEMP= in environment
	mov	bx,dx			; string so far
	add	bx,cx			; last byte + 1
	cmp	byte ptr [bx-1],'\'	; ends on slash?
	je	start1c			; e = yes
	mov	word ptr [bx],'\'+0	; append slash and null terminator
start1c:mov	di,dx			; destination of dostemp
	mov	si,offset tmpname	; redirection filename
	call	strcat			; append

	call	getargv			; get directory where we started
	call	getparm			; read "KERMIT=" Environment line
	jc	start1b			; c = fatal error
	xor	cl,cl			; counter, starts at 0
start1a:mov	bx,offset kerenv+6	; append "<digit>="  to "KERMIT"
	mov	[bx],cl			; binary digit
	inc	cl
	add	byte ptr [bx],'0'	; to ascii
	mov	byte ptr [bx+1],'='	; append equals sign
	call	getparm			; read "KERMITn=" Environment line
	jc	start1b			; c = fatal error
	cmp	cl,9			; done all digits?
	jbe	start1a			; be = no
	call	scpini			; initialize script routines
	jc	start1b			; c = fatal error
	call	lclini			; do local initialization
	cmp	flags.extflg,0		; exit now?
	je	start2			; e = no
start1b:mov	ah,prstr		; announce our premature exit
	mov	dx,offset ermes5	; can't complete initialization
	int	dos
	jmp	krmend5			; quit immediately
start2:	mov	word ptr comand.cmrprs,offset krmend ; offset of reparse addr
	mov	ax,cs			; our current code segment
	mov	word ptr comand.cmrprs+2,ax ; segment of reparse address
	mov	comand.cmostp,sp	; save for reparse too
	call	gcmdlin			; read command line
	cmp	taklev,0		; in a Take file?
	jne	start3			; ne = yes, skip help msg
	mov	ah,prstr
	mov	dx,offset machnam	; display machine name
	int	dos
        mov	dx,offset verident	; display version header
        int	dos
	mov	dx,offset copyright	; display copyright notice
	int	dos
ifdef no_graphics
	mov	dx,offset nographics
	int	dos
endif
ifdef no_network
	mov	dx,offset nonet
	int	dos
else
ifdef no_tcp
	mov	dx,offset notcp
	int	dos
endif
endif
ifdef	no_terminal
	mov	dx,offset noterm
	int	dos
endif
ifdef no_graphics + no_tcp + no_network
	mov	dx,offset crlf
	int	dos
endif
	mov	dx,offset hlpmsg
	int	dos
start3:	mov	patchena,' '		; let patch level show
	call	serrst			; reset serial port (if active)
	call	initibm			; define IBM macro
	call	rdinit			; read kermit init file
	push	es
	mov	di,ds
	mov	es,di
	mov	di,offset inidir	; remember path to mskermit.ini
	mov	si,offset cmdfile	; last Take file path+name
	call	strcpy			; copy whole string
	mov	dx,di
	call	strlen			; length of complete path+filename
	add	di,cx			; last byte +1
	mov	al,'\'			; look for this separator
	std
	repne	scasb
	cld
	mov	byte ptr [di+2],0	; terminate after separator
	pop	es

 ; This is the main KERMIT loop.  It prompts for and gets the users commands

kermit:	mov	ax,ds
	mov	es,ax			; convenient safety measure
	mov	dx,prmptr		; get prompt string address
	call	mprompt          	; set master reparse address to here
	cmp	flags.cxzflg,'C'	; did someone want out?
	jne	kermt4			; ne = no
kermt2:	cmp	taklev,0		; are we in a Take file?
	je	kermt4			; e = no, ignore the signal
	call	takclos			; close take file, release buffer
	jmp	short kermt2		; close any other take files
kermt4:	mov	flags.cxzflg,0		; reset each time
	and	flags.remflg,not dserver ; turn off server mode bit
	cmp	dosctty,0		; is DOS using our comms line?
	je	kermt1			; e = no
	and	flags.remflg,not(dquiet+dregular+dserial)
	or	flags.remflg,dquiet	; set display to quiet mode
	call	serrst			; close port so CTTY can run
kermt1:	mov	dx,offset comtab
	mov	bx,offset tophlp
	cmp	flags.extflg,0		; exit flag set?
	jne	krmend			; ne = yes, jump to KRMEND
	mov	comand.cmcr,1		; allow bare CR's
        mov	ah,cmkey
	mov	comand.impdo,1		; allow implied "DO macro"
	call	comnd
	jc	kermt3			; c = failure
	mov	comand.impdo,0		; only on initial keyword, not here
	mov	comand.cmcr,0		; no more bare CR's
	push	bx
	mov	bx,takadr
	mov	al,taklev
	mov	[bx].takinvoke,al	; remember Take level of this cmd
	pop	bx
	call	bx              	; call the routine returned in BX
	jc	kermt3			; c = failure
	cmp	flags.extflg,0		; exit flag set?
	jne	krmend			; ne = yes, jump to KRMEND
	jmp	short kermt5		; do idle loop cleanup
 
kermt3:	cmp	flags.cxzflg,'C'	; got here via Control-C?
	jne	kermt7			; ne = no
	cmp	flags.extflg,0		; exit flag set?
	jne	kermt5			; ne = yes, skip msg, do cleanup
	mov	dx,offset ermes3	; say command not executed
	mov	ah,prstr		; print	the error message in dx
	int	dos
kermt5:	cmp	flags.cxzflg,'C'	; user Control-C abort?
	jne	kermt7			; ne = no, do normal operations
	cmp	taklev,0		; in a Take file?
	je	kermt7			; e = no		
	call	takclos			; close take file, release buffer
	jmp	short kermt5		; close any other take files
kermt7:	cmp	flags.extflg,0		; exit flag set?
	jne	krmend			; ne = yes, exit
	mov	bx,takadr
	mov	al,[bx].takinvoke	; take level at start of command parse
	cmp	al,taklev		; same?
	jne	kermt10			; ne = no, already closed
	mov	al,[bx].taktyp		; kind, file or macro
	cmp	al,take_file		; type of Take, file?
	jne	kermt8			; ne = no (macro)
	cmp	takeerror,0		; is Take Error off?
	jne	kermt9			; ne = no, close Take file
kermt8:	cmp	al,take_macro		; regular macro?
	jne	kermt10			; ne = no, leaves internal macro
	cmp	macroerror,0		; is Macro Error off?
	je	kermt10			; e = yes, error is not fatal
kermt9:	call	takclos			; close Take file or Macro
kermt10:jmp	kermit			; e = no, get next command
 
krmend:	mov	flags.cxzflg,0		; reset each time
	mov	flags.extflg,0
	call	far ptr exmacro		; find on_exit macro
	jc	krmend2			; c = not found
					; perform ON_EXIT macro
krmend1:cmp	taklev,0		; finished with macros?
	je	krmend2			; e = yes
	mov	dx,prmptr		; get prompt string address
	call	mprompt          	; set master reparse address to here
	cmp	taklev,0		; still in on_exit?
	je	krmend2			; e = no, exit to DOS
	mov	flags.cxzflg,0		; reset each time
	and	flags.remflg,not dserver ; turn off server mode bit
	mov	dx,offset comtab	; keyword table
	xor	bx,bx			; no help
        mov	ah,cmkey
	mov	comand.impdo,1		; allow implied "DO macro"
	mov	comand.cmcr,1		; allow bare CR's
	call	comnd
	jc	krmend2			; c = failure
	mov	comand.impdo,0		; only on initial keyword, not here
	call	bx			; call the routine returned in BX
	jnc	krmend1			; nc = success, keep doing commands
					; end of ON_EXIT macro processing
krmend2:cmp	taklev,0		; in a Take file?
	je	krmend3			; e = no		
	call	takclos			; close take file, release buffer
	jmp	short krmend2		; close any other take files
krmend3:mov	bx,lclexit		; addr of sys dependent exit routine
	or	bx,bx			; sys dependent routines want service?
	jz	krmend4			; z = no
	call	bx			; call it
	jnc	krmend4			; nc = close
	jmp	kermit			; c = do not close
krmend4:call	serrst			; just in case the port wasn't reset
	call	clscpi			; close log files
	call	far ptr emsclose	; close and return EMS memory
	mov	dl,origd		; original disk drive
	dec	dl			; want A == 0
	mov	ah,seldsk		; reset original disk just in case
	int	dos
	mov	dx,offset orgdir	; restore original directory
	mov	ah,chdir
	int	dos
	push	ds			; save ds around these DOS calls
	mov	ax,cs			; compose full address of ^C routine
	mov	ds,ax			; segment is the code segment
	mov	dx,offset in3ad		; restore Control-C interrupt vector
	mov	al,23H			; interrupt 23H
	mov	ah,setintv		; set interrupt vector
	int	dos			; ah, that's better
	mov	dx,offset ceadr		; DOS's Critical Error handler
	mov	al,24h			; interrupt 24h
	mov	ah,setintv		; do replacement (put it back)
	int	dos
	pop	ds
	call	cbrestore		; restore state of Control-Break Chk
krmend5:mov	ah,4cH			; terminate process
	mov	al,errlev		; return error level
	int	dos
	ret
START	ENDP

; This is the 'EXIT' command.  It leaves KERMIT and returns to DOS
 
EXIT	PROC	NEAR
	mov	bx,offset rdbuf
	xor	dx,dx			; no help
	mov	ah,cmline
	call	comnd
	jc	exit3
	or	ax,ax			; any bytes?
	jz	exit3			; z = no
	mov	dx,offset crlf
	mov	ah,prstr
	int	dos
	mov	dx,offset rdbuf
	call	prtasz			; display optional message
exit3:	mov	ah,cmeol
	call	comnd			; get a confirm
	jc	exit1			; c = failure
	mov	flags.extflg,1		; set the exit-Kermit flag
exit1:	cmp	taklev,0		; in a Take file?
	je	exit2			; e = no		
	call	takclos			; close take file, release buffer
	jmp	short exit1		; close any other take files
exit2:	clc
	ret
EXIT	ENDP

; Resume For/While at the foot of the interation loop
CONTINUE proc	near
	mov	temp,1			; marker for continue
	jmp	short break1
CONTINUE endp

; Abandon current For/While statement
BREAKCMD proc	near
	mov	temp,0			; marker for break

break1:	mov	al,taklev		; Take level
	or	al,al			; in take/macro?
	jz	breakx			; z = no
	mov	bx,takadr
break2:	test	[bx].takattr,take_while+take_switch ; for/while/switch macro?
	jnz	break3			; nz = yes
	sub	bx,size takinfo		; work backward
	dec	al
	jnz	break2			; nz = have some
	stc				; carry set to say for/while not
	ret				; found

break3:	cmp	temp,0			; Break?
	jne	break4			; ne = no, Continue
	push	ax			; save found take level
	call	takclos			; close for/while macro
	pop	ax
	mov	bx,takadr		; new take level
	cmp	taklev,al		; did all at that level and above?
	jae	break3			; ae = no
breakx:	clc
	ret
					; Continue
break4:	inc	al			; look above the for/while macro
	add	bx,size takinfo
	cmp	al,taklev		; above the current macros?
	ja	breakx			; a = yes, quit
	mov	[bx].takcnt,0		; exhaust the macro to end reading
	jmp	short break4
BREAKCMD endp

; Permit ELSE keyword right after failed IF statement
ELSECMD	proc	near
	cmp	oldifelse,0		; ELSE permitted after failed IF?
	je	elsecmd1		; e = no
	mov	oldifelse,0
	clc				; let cmd parser read rest as cmd
	ret
elsecmd1:
	mov	ah,cmline		; discard the line quietly
	mov	comand.cmblen,cmdblen	; set line capacity (length of rdbuf)
	mov	bx,offset rdbuf
	xor	dx,dx			; no help
	call	comnd
	clc
	ret
ELSECMD endp

; RETURN string   string is placed in buffer retbuf
RETCMD	proc	near
	mov	ah,cmline
	mov	bx,offset retbuf+2	; returned string
	mov	word ptr rdbuf,0
	xor	dx,dx
	call	comnd
	jnc	retcmd1
	ret
retcmd1:mov	word ptr retbuf,ax	; <count word> <returned string>
	call	poplevel		; do the pop
	ret
RETCMD	endp

; NOPUSH
PUSHPROC PROC	NEAR
	mov	ah,cmeol
	call	comnd
	jc	pushp1			; c = failure
	mov	nopush_flag,1		; set nopush condition
pushp1:	ret
PUSHPROC ENDP

code	ends

code1	segment
	assume	cs:code1

exmacro	proc	far			; perform on_exit() macro
	push	bx
	push	cx
	push	si
	mov	bx,offset mcctab	; table of macro names
	mov	cl,[bx]			; number of names in table
	xor	ch,ch
	jcxz	exmacx			; z = empty table, do nothing
	inc	bx			; point to length of first name
exmac2:	mov	ax,[bx]			; length of this name
	cmp	ax,onexlen		; length same as desired keyword?
	jne	exmac3			; ne = no, search again
	mov	si,bx
	add	si,2			; point at first char of name
	push	cx			; save name counter
	push	di			; save reg
	mov	cx,onexlen		; length of name
	mov	di,offset onexit+2	; point at desired macro name text
	push	es			; save reg
	push	ds
	pop	es			; make es use data segment
	cld
	repe	cmpsb			; match strings
	pop	es			; need current si below
	pop	di
	pop	cx			; recover saved regs
	jne	exmac3			; ne = no match
	mov	onexit+2,0		; change name to be invisible
	mov	byte ptr [bx+2],0	; change macro table name too
	jmp	short exmac4		; e = matched
exmac3:	add	bx,ax			; step to next name, add name length
	add	bx,4			; + count and def word ptr
	loop	exmac2			; try next name
exmacx:	pop	si			; no macro, fail
	pop	cx
	pop	bx
	stc				; say failure
	ret

exmac4:	call	takopen_macro		; open a macro
	jc	exmacx			; c = failed
	mov	bx,takadr		; point to current macro structure
	mov	ax,ds			; text is in our data seg
	mov	[bx].takbuf,ax		; seg of definition string struc
	mov	[bx].takptr,offset onexit+2 ; where to read next command char
	mov	[bx].takcnt,onexlen	; number of chars in definition
	mov	[bx].takargc,0		; store macro argument count
	pop	si
	pop	cx
	pop	bx
	clc				; say success
	ret
exmacro	endp

; Close and return EMS memory, uses emsrbhandle and emsgshandle
emsclose proc	far
	mov	ah,45h			; release handle and memory
	mov	dx,emsrbhandle		; handle
	or	dx,dx			; is handle valid (not -1)?
	jl	emsclose1		; l = no
	int	67h			; ems interrupt
emsclose1:mov	emsrbhandle,-1
	mov	ah,45h			; release handle and memory
	mov	dx,emsgshandle		; handle
	or	dx,dx			; is handle valid (not -1)?
	jl	emsclose2		; l = no
	int	67h			; ems interrupt
emsclose2:mov	emsgshandle,-1
	cmp	xmsrhandle,0		; XMS rollback handle, valid?
	je	emsclose3		; e = no
	mov	dx,xmsrhandle
	mov	ah,0ah			; XMS free block
	call	dword ptr xmsep		; XMS manager entry point
	mov	xmsrhandle,0
emsclose3:cmp	xmsghandle,0		; XMS graphics handle, valid?
	je	emsclose4		; e = no
	mov	dx,xmsghandle
	mov	ah,0ah			; XMS free block
	call	dword ptr xmsep		; XMS manager entry point
	mov	xmsghandle,0
emsclose4:ret
emsclose endp
code1	ends

code	segment
	assume	cs:code

; TAKE commands	from a file, and allow a path name
TAKE	PROC	NEAR
	mov	kstatus,kssuc		; global status, success
	cmp	taklev,maxtak		; at the limit?
	jl	take1			; l = no
	mov	ah,prstr
	mov	dx,offset erms30	; complain
	int	dos
	stc				; failure
	ret
take1:	mov	bx,offset tmpbuf	; work buffer
	mov	tmpbuf,0
	mov	dx,offset filmsg	; Help in case user types "?"
	mov	ah,cmword		; get file name
	call	comnd
	jc	take1a			; c = failure
	mov	ah,cmeol
	call	comnd
	jc	take1a			; c = failure
	mov	ax,offset tmpbuf	; point to name again
	cmp	tmpbuf,0		; empty filespec?
	jne	take2			; ne = no
	mov	ah,prstr
	mov	dx,offset ermes1	; say more parameters needed
	int	dos
	stc
take1a:	ret
					; TAKE2: enter with ax=filename ptr
TAKE2:	call	spath			; is it around?
	jc	take3			; no, go complain
	mov	dx,ax			; point to name from spath
	mov	ah,open2		; open file
	xor	al,al			; 0 = open for reading
	cmp	dosnum,300h		; at or above DOS 3?
	jb	take2a			; b = no, so no shared access
	or	al,40h			; open for reading, deny none
take2a:	push	dx
	int	dos
	pop	dx
	jnc	take4			; nc = opened ok, keep going
	mov	ax,dx			; recover filename pointer
take3:	push	ax
	mov	ah,prstr
	mov	dx,offset erms31
	int	dos
	pop	ax
	mov	dx,ax			; asciiz file name
	call	prtasz			; display it
	mov	cmdfile,0		; clear latest cmd file info
	mov	kstatus,kstake		; status, Take failed
	clc				; we've done all error displays
	ret
					; TAKE4: enter with ax=filename ptr
TAKE4:	push	dx			; save filename string
	push	ax			; save pointer
	call	takopen_file		; open take file
	pop	ax
	pop	dx
	jc	take6			; c = failure
	call	save_cmdfile		; save path+name of file from dx
	push	bx
	mov	bx,takadr		; get current frame ptr
	mov	[bx].takhnd,ax		; save file handle
	pop	bx
	cmp	flags.takflg,0		; echoing Take files?
	je	take5			; e = no
	mov	ah,prstr
	mov	dx,offset crlf
	int	dos
take5:	call	takrd			; get a buffer full of data
	clc				; success
take6:	ret
TAKE	ENDP

; TAKE-QUIT  (STOP)  Exit all Take files immediately but gracefully

TAKEQIT PROC	NEAR
	xor	ax,ax
	mov	errlev,al		; return value in ERRORLEVEL
	mov	kstatus,ax		; and in STATUS

	mov	ah,cmword		; get optional error value
	mov	bx,offset rdbuf
	mov	dx,offset stophlp	; help on numerical argument
	mov	comand.cmcr,1		; bare c/r's allowed
	call	comnd
	mov	comand.cmcr,0		; restore normal state
	jc	takqit3			; c = failure

	mov	ah,cmline		; get optional error msg
	mov	bx,offset rdbuf+100
	mov	dx,offset stophlp	; help on numerical argument
	mov	comand.cmcr,1		; bare c/r's allowed
	mov	comand.cmdonum,1	; \number conversion allowed
	call	comnd
	mov	comand.cmcr,0		; restore normal state
	jc	takqit3			; c = failure
	push	ax			; save string count
	mov	ah,cmeol		; confirm
	call	comnd
	pop	ax
	jc	takqit3
	mov	domath_ptr,offset rdbuf	; string
	mov	domath_cnt,ax		; string length
	call	domath			; convert to number in dx:ax
	cmp	domath_cnt,0
	jne	takqit2			; ne = did not convert whole word
	mov	errlev,al		; return value in ERRORLEVEL
	mov	kstatus,ax		; and in STATUS
	mov	si,offset rdbuf+100
takqit4:lodsb				; read a msg char
	or	al,al			; null terminator?
	jz	takqit2			; z = empty string
	cmp	al,' '			; leading white space?
	je	takqit4			; be = leading white space
	dec	si			; backup to non-white char
	mov	dx,offset crlf
	mov	ah,prstr
	int	dos
	mov	dx,si			; message pointer
	call	prtasz
takqit2:xor	ch,ch
	mov	cl,taklev		; number of Take levels active
	jcxz	takqit3			; z = none
	cmp	cmdlinetake,cl		; have DOS level command line?
	jae	takqit3			; ae = yes, don't close it here
	call	takclos			; close current Take file
	jmp	short takqit2		; repeat until all are closed
takqit3:clc				; success
	ret
TAKEQIT	ENDP

code	ends
code1	segment
	assume	cs:code1

TAKRD	PROC	FAR
	push	ax
	push	bx
	push	cx	
	push	dx
	push	di
	push	es
	push	temp
	mov	bx,takadr
	cmp	[bx].taktyp,take_file	; get type of take (file?)
	je	takrd0			; e = take file, not macro
	jmp	takrd30

takrd0:	xor	ax,ax
	mov	[bx].takcnt,ax		; number of bytes to be read
	mov	[bx].takptr,ax		; offset of first new character
	mov	temp,ax			; prime the disk reader
	mov	tempptr,offset tmpbuf + 1

takrd1:	mov	ax,[bx].takbuf		; segment of Take buffer
	mov	es,ax
	mov	cx,tbufsiz		; # of bytes to examine
	xor	dx,dx			; dl = 0 for store data (vs comments)
	xor	di,di			; offset in buffer where data starts

takrd2:	call	takrworker		; fill take buffer, return a byte
	jc	takrd30			; c = failure
	add	word ptr [bx].takseek,1
	adc	word ptr [bx].takseek+2,0 ; seek distance, bytes
	mov	bx,takadr
	cmp	al,TAB			; TAB?
	jne	takrd2a			; ne = no
	mov	al,' '			; convert to space
takrd2a:cmp	al,LF			; line terminator?
	je	takrd2			; e = yes, ignore it
	cmp	al,CR			; internal line terminator?
	je	takrd5			; e = yes, always write in buffer
	or	dl,dl			; store data (vs discard comments)?
	jnz	takrd2			; nz = no, discard, read comments
	cmp	al,';'			; start of comment indicator?
	jne	takrd5			; ne = no
	cmp	[bx].takcnt,0		; bytes examined in buffer, so far
	je	takrd4			; e = nothing, so no escape either
	mov	ah,byte ptr es:[di-1]	; preceeding char
	cmp	ah,'\'			; escaped?
	jne	takrd3			; ne = no
	dec	di			; overwrite '\' with ';'
	dec	[bx].takcnt
	dec	cx
	jmp	short takrd5

takrd3:	cmp	ah,' '			; whitespace precedessor?
	je	takrd4			; e = yes, ';' starts a comment
	cmp	ah,TAB			; this kind too?
	jne	takrd5			; ne = no, not a comment
takrd4:	mov	dl,1			; say start discarding comments
	jmp	short takrd2		; read more comments

takrd5:	cmp	al,' '			; space
	jne	takrd6			; ne = no
	cmp	[bx].takcnt,0		; anything in line buffer yet?
	je	takrd7			; e = no, omit leading space
takrd6:	inc	[bx].takcnt		; bytes accepted into buffer so far
	stosb				; store byte
	cmp	al,CR			; ending on CR?
	jne	takrd7			; ne = no
	or	dl,dl			; processing comment?
	jnz	takrd30			; nz = yes, CR ends comment line
	cmp	[bx].takcnt,1		; more than just CR?
	jbe	takrd30			; be = no
	cmp	byte ptr es:[di-2],'-'	; hyphenated line?
	jne	takrd30			; ne = no
	sub	[bx].takcnt,2		; remove '-' and CR from buffer
	sub	di,2			; back over both
	add	cx,2			; add back capacity
	xor	dl,dl			; end of comment
takrd7:	loop	takrd2

takrd30:mov	cx,[bx].takcnt		; trim trailing spaces. line count
	cmp	cx,1
	jbe	takrd34			; be = empty line or eof
	mov	di,cx
	dec	di			; count of 1 is only es:[0]
	cmp	byte ptr es:[di-1],' '	; ended on text?
	ja	takrd34			; a = yes, do not trim
	xor	di,di			; es:di(0) is buffer
	dec	cx			; back over final CR
	jcxz	takrd34			; z = only CR remained
	add	di,cx
	dec	di			; look at last byte - 1
	mov	al,' '			; scan for
	std
	repe	scasb
	cld
	jne	takrd32			; ne = does not over decrement
	dec	di
takrd32:inc	di
	inc	di
	mov	byte ptr es:[di],CR	; final CR goes here
	inc	di
	mov	[bx].takcnt,di		; new count
takrd34:pop	temp
	cmp	flags.takdeb,0		; single step?
	je	takrd37			; e = no
	mov	ah,prstr
	mov	dx,offset takepause
	int	dos
	mov	ah,0ch			; clear keyboard buffer
	mov	al,coninq		; quiet input
	int	dos
	cmp	al,3			; Control-C?
	je	takrd35			; e = yes
	or	al,al			; scan code?
	jne	takrd36			; ne = no
	mov	ah,coninq		; read the second byte
	int	dos
	or	al,al			; null for Control-Break?
	jne	takrd36			; ne = no
takrd35:mov	flags.cxzflg,'C'	; say want to exit now
takrd36:mov	ah,prstr
	mov	dx,offset crlf
	int	dos
takrd37:pop	es
	pop	di
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
TAKRD	ENDP

; Read one byte from disk file into al.
; Return carry set if failure
takrworker proc	near
	push	bx
	push	cx
	push	dx
	push	es
	cmp	temp,0			; bytes to be read from tmpbuf
	jne	takrwork1		; ne = have things in the buffer
	mov	bx,takadr
	mov	dx,word ptr [bx].takseek
	mov	cx,word ptr [bx].takseek+2
	mov	bx,[bx].takhnd		; bx = file handle
	mov	ah,lseek		; seek
	mov	al,0			; from start of file
	int	dos
	mov	temp,0			; bytes remaining unread
	mov	cx,length tmpbuf - 1	; # of bytes to read
	mov	dx,offset tmpbuf + 1	; ds:dx = buffer, skip count word
	mov	tempptr,dx		; where to read from tmpbuf next time
	mov	ah,readf2		; read file
	int	dos
	jc	takrwork2		; c = error, preserve ax
	mov	temp,ax			; returned byte count
	or	ax,ax
	jz	takrwork2		; z = nothing left

takrwork1:
	mov	bx,tempptr		; where to read a byte
	mov	al,[bx]			; read the byte
	inc	tempptr			; where to read next time
	dec	temp			; say another byte read
	clc
	jmp	short takrwork3		; succeed

takrwork2:stc				; fail
takrwork3:pop	es
	pop	dx
	pop	cx
	pop	bx
	ret
takrworker endp
code1	ends
code	segment
	assume	cs:code

; put mskermit.ini onto take stack if it exists.  Just like
; the take command, except it doesn't read a filename
rdinit	proc	near			; read Kermit init file
	mov	ax,offset ininm2	; default name to try
	cmp	decbuf,0		; alternate init file given?
	je	rdini1			; ne = no
	mov	ax,offset decbuf	; yes, use it
	call	spath			; is it around?
	jc	rdini2			; c = no
	call	take2			; let Take do error msgs
	clc				; force success
	ret
rdini1:	call	spath			; is it around?
	jc	rdini2			; c = no, ignore file
	mov	dx,ax			; point to name from spath
	mov	ah,open2		; open file
	xor	al,al			; 0 = open for reading
	cmp	dosnum,300h		; at or above DOS 3?
	jb	rdini1a			; b = no, so no shared access
	or	al,40h			; open for reading, deny none
rdini1a:int	dos
	jc	rdini2			; c = no ini file found, ignore
	call	take4			; use TAKE command to complete work
	clc				; ignore errors
rdini2:	ret
rdinit	endp

; Patcher.  Patch file, MSRxxx.PCH or MSKERMIT.PCH has the following format:

; 301 \Xxxxx	Text to display upon successful patch load
; ;301 for V3.01.  For xxxx, see below
; ; optional comment lines may appear anywhere after the 1st
; ; xxxx in 1st line = total paragraphs in memory image.  Use \X if hex.
; DS:xxxx xx xx		; optional comment.  DS (or CS) are case insensitive
; CS:xxxx xx xx xx	; locations must be 4 hex chars, contents must be 2
;
; The 1st xx is the original value of the 1st byte @seg:offset for comparison.
; A 00 value says don't compare.  Subsequent xx's are replacement bytes.
; CS & DS lines may be intermixed.  AS & BS segments may be used when some
; external module sets words aseg & bseg to a seg-base.
; This mechanism expects file msscmd.obj to be linked first.

PATCH	proc
	mov	bx,offset rdbuf		; optional path prefix
	mov	rdbuf,0
	mov	dx,offset pathlp
	mov	ah,cmword
	call	comnd
	jc	patch1
	mov	ah,cmeol
	call	comnd
	jc	patch1
	xor	ax,ax
	xchg	al,patched		; clear and test patched
	test	al,al
	jz	patch1			; z = disabled or done
	xchg	ah,flags.takflg		; clear take flag, don't echo patches
	mov	byte ptr temp,ah	; but save it
	call	ptchr
	mov	al,byte ptr temp	; restore take flag
	mov	flags.takflg,al
	jc	patch2			; c = NG
patch1:	ret

patch2:	mov	dx,offset ermes8	; Fatal error
	mov	ah,prstr
	int	dos
	jmp	krmend			; force exit

ptchr:	mov	dx,offset rdbuf		; optional path
	call	strlen			; get length, if any
	jcxz	ptchr1			; z = nothing
	mov	si,dx
	add	si,cx
	cmp	byte ptr [si-1],'\'	; ends with path specifier?
	je	ptchr1			; e = yes
	cmp	byte ptr [si-1],':'	; or a drive specifier?
	je	ptchr1			; e = yes
	mov	word ptr [si],'\'+0	; add '\' + null
ptchr1:	mov	di,offset rdbuf+66	; path goes here
	mov	si,offset rdbuf+140	; filename goes here, discard
	mov	byte ptr [di],0		; clear
	call	fparse			; split optional path
	mov	si,offset ptchnam	; add name of patch file
	call	strcat
	mov	ax,di			; setup filename pointer for rdini1
	call	rdini1		; let rdini try to find it & do take stuff
	jnc	ptch1			; nc = file msrxxx.pch was found
	mov	di,offset rdbuf+66	; path goes here
	mov	si,offset rdbuf+140	; filename goes here, discard
	mov	byte ptr [di],0		; clear
	mov	dx,offset rdbuf		; source string again
	call	fparse			; split optional path
	mov	si,offset ptchnam2	; try alternate name
	mov	byte ptr [di],0		; insert terminator
	call	strcat			
	mov	ax,di			; setup filename pointer for rdini1
	call	rdini1		; let rdini try to find it & do take stuff
	jnc	ptch1			; nc = file msrxxx.pch was found
	mov	dx,offset ermes7	; say file not found
	mov	ah,prstr
	int	dos
	clc
	ret

ptch1:	mov	al,taklev		; remember initial take level
	mov	pttemp,al		; when it changes it is EOF & done
	mov	comand.cmkeep,1		; keep Take open after eof
	mov	comand.cmcr,1		; bare cr's ok, to prevent prserr @EOF
	call	ptchrl			; read 1st line's 1st 'word'
	jc	ptch2			; c = trouble
	jz	ptch3			; z = EOF
	mov	si,offset tmpbuf+1
	mov	domath_cnt,4		; length of field
	mov	domath_ptr,si
	mov	domath_msg,1		; don't complain
	call	domath			; convert number to binary
	cmp	domath_cnt,0
	jne	ptch2			; ne = bad number, or none
	cmp	ax,version		; does it match this version?
	je	ptch4			; e = yes
ptch2:	mov	al,pttemp		; if take level has changed,
	xor	al,taklev		;  we're already out of patch file
	jnz	ptch3			; nz = change in take level
	call	takclos			; close patch file
ptch3:	mov	dx,offset ermes6
	mov	ah,prstr		; issue warning msg
	int	dos
	clc
	ret

ptch4:	mov	dx,offset tmpbuf+1
	call	ptchrw			; read 2nd "word", 1st line
	jc	ptch2			; c = NG
	mov	si,offset tmpbuf+1
	mov	domath_cnt,6		; arbitrary length
	mov	domath_ptr,si
	call	domath			; convert 2nd "magic number"
	cmp	domath_cnt,0
	jne	ptch2			; ne = bad number, or none
	cmp	ax,totpar	; is it the total paragraphs memini computed?
	jne	ptch2			; ne = no
	mov	bx,offset buff	; place to stash 1st lines patch/version msg
	xor	dx,dx			; help
	mov	ah,cmline		; read it
	call	comnd

ptch5:	call	ptchrl			; read CS:xxxx or DS:xxxx
	jc	ptch6
	jz	ptch7			; z = EOF
	cmp	ax,7			; were 7 chars read?
	jne	ptch6			; ne = no
	mov	si,offset tmpbuf+1
	and	word ptr[si],not 2020h	; convert to upper case
	cld
	lodsb				; get the seg char
	cmp	word ptr[si],':S' 	; S:, actually
	je	ptch8			; e = ok
ptch6:	stc				; error exit
	ret

ptch7:	test	flags.remflg,dquiet	; quiet display?
	jnz	ptch7a			; nz = yes, skip msg
	mov	ah,prstr
        mov	dx,offset verident	; display version header
        int	dos
ptch7a:	clc
	ret

ptch8:	push	ds
	pop	es
	mov	di,offset segstr
	mov	cx,lsegstr		; search for seg char in segstr
	repne	scasb
	jne	ptch6			; ne = not found
	sub	di,offset segstr+1	; distance spanned
	shl	di,1			; make a word index
	mov	bx,segtab[di]		; bx = seg-base
	or	bx,bx			; seg-base = 0, disabled for patching
	jz	ptch6			; z = 0, no patching
	mov	word ptr[si],'X\' 	; put '\X' in front for hex
	mov	domath_cnt,16		; arbitrary length
	mov	domath_ptr,si
	call	domath			; convert number to binary
	cmp	domath_cnt,0
	jne	ptch6			; ne = bad number, or none
	push	bx			; save seg being patched
	push	ax			; save location being patched
	mov	tmpbuf+64,0		; clear replacement byte count
ptch9:	mov	dx,offset tmpbuf+4
	call	ptchrw			; read replacement byte follwing '\X'
	jnc	ptch11			; nc = OK
ptch10:	pop	ax			; clean stack & error return
	pop	bx
	stc
	ret

ptch11:	or	ax,ax			; EOL?
	jnz	ptch13			; nz = no
	mov	si,offset tmpbuf+64
	cld
	lodsb				; replacement byte count
	cmp	al,2			; gotta be at least 2
	jb	ptch10			; b = too few
	xor	ch,ch
	mov	cl,al			; replacement count
	pop	di			; patch location
	pop	es			; patch segment
	lodsb				; al = comparison byte
	or	al,al			; key value to ignore comparison?
	jz	ptch12			; z = 0, yes
	cmp	byte ptr es:[di],al 	; do read check on memory image
	jne	ptch6			; ne = no match, fail now
ptch12:	dec	cx			; adjust for comparison byte
	rep	movsb			; make patch
	jmp	ptch5			; loop to read next line

ptch13:	cmp	al,2			; 2 chars req'd for replacement byte
	jne	ptch10			; ne = bad
	mov	domath_ptr,offset tmpbuf+2; convert it
	mov	domath_cnt,16		; arbitrary length
	call	domath			; convert number to binary
	cmp	domath_cnt,0
	jne	ptch10			; ne = bad number, or none
	mov	si,offset tmpbuf+64	; --> replacement byte counted string
	inc	byte ptr[si]		; bump count
	mov	bl,[si]
	xor	bh,bh
	mov	byte ptr[si+bx],al	; stash replacement byte
	jmp	short ptch9		; loop for next byte

ptchrl:	mov	dx,offset patpmt	; read 1st word, next line to tmpbuf+1
	call	prompt
	mov	dx,offset tmpbuf+1
	call	ptchrw
	jc	ptchrb			; c = NG
	push	dx
	mov	dl,pttemp		; old Take level
	xor	dl,taklev		; current Take level, changed
	pop	dx
	jz	ptchra			; z = no, not EOF
	xor	ax,ax			; set z flag for EOF
	ret

ptchra:	or	ax,ax			; empty or comment line?
	jz	ptchrl			; z = empty or comment, ignore
ptchrb:	ret

ptchrw:	push	dx
	mov	dl,pttemp		; old Take level
	xor	dl,taklev		; current Take level, changed?
	pop	dx
	jz	ptchrwa			; z = no, not EOF
	xor	ax,ax			; set z flag for EOF
	ret
ptchrwa:mov	ah,cmword
	mov	comand.cmper,1	; prohibit substitution variable expansion
	xor	bx,bx			; 'help' ptr
	xchg	bx,dx			; order for comnd
	call	comnd			; line length is in ax
	ret
PATCH	endp
code	ends
code1	segment
	assume	cs:code1

; Get command line into a Take macro buffer. Allow "-f filspec" to override
; normal mskermit.ini initialization filespec, allow command "stay" to
; suppress automatic exit to DOS at end of command line execution. [jrd]

gcmdlin	proc	far
	mov	cmdlinetake,0		; flag for DOS command line Take
	mov	word ptr decbuf,0	; storage for new init filename
	push	es
	cld
	mov	es,psp			; address psp
	xor	ch,ch
	mov	cl,es:byte ptr[cline]	; length of cmd line from DOS
	jcxz	gcmdl1			; z = empty line
	mov	si,cline+1		; point to actual line
gcmdl0:	cmp	byte ptr es:[si],' '	; skip over leading whitespace
	ja	gcmdl2			; a = non-whitespace
	inc	si
	loop	gcmdl0			; fall through on all whitespace
gcmdl1:	jmp	gcmdl14			; common exit jump point
gcmdl2:	inc	cx			; include DOS's c/r
	call	takopen_macro		; open take as macro
	mov	bx,takadr
	mov	ax,150			; space needed: DOS line + ",stay"
	call	malloc			; hope it works
	mov	[bx].takbuf,ax		; memory segment
	or	[bx].takattr,take_malloc ; remember to dispose via takclos
	mov	es,ax			; segment of buffer
        mov     di,2                    ; skip count word
	push	psp

	pop	DS			; DS = PSP
	xor	dx,dx			; clear brace count
gcmdl3:	or	cx,cx			; anything left?
	jle	gcmdl10			; le = no
	lodsb				; get a byte from PSP's command line
	dec	cx			; one less char in input string
	cmp	al,','			; comma?
	jne	gcmdl4			; no, keep going
	or	dx,dx			; inside braces?
	jnz	gcmdl9			; nz = yes, retain embedded commas
	mov	al,cr			; convert to cr
	jmp	short gcmdl9		; store it
gcmdl4:	call	bracechk		; check for curly braces
	jc	gcmdl9			; c = found and counted brace
	or	dx,dx			; outside braces?
	jnz	gcmdl9			; nz = no, ignore flag
	cmp	al,'-'			; starting a flag?
	jne	gcmdl9			; ne = no
	mov	ah,[si]			; get flag letter
	or	ah,20h			; convert to lower case
	cmp	ah,'f'			; 'f' for init file replacement?
	jne	gcmdl9			; ne = no
	inc	si			; accept flag letter
	dec	cx
gcmdl5:	or	cx,cx			; anything to read?
	jle	gcmdl10			; le = exhausted supply
	lodsb				; get filespec char from psp
	dec	cx			; one less char in source buffer
	cmp	al,' '			; in whitespace?
	jbe	gcmdl5			; be = yes, scan it off
	dec	si			; backup to real text
	inc	cx
					; copy filspec to buffer decbuf
	push	es			; save current destination pointer
	push	di			;  which is in es:di (Take buffer)
	mov	di,data			; set es:di to regular decbuf
	mov	es,di
	lea	di,decbuf		; where filespec part goes
	mov	word ptr es:[di],0	; plant safety terminator
gcmdl6:	lodsb				; get filespec char
	dec	cx			; one less available
	cmp	al,' '			; in printables?
	jbe	gcmdl7			; be = no, all done
	cmp	al,','			; comma command separator?
	je	gcmdl7			; e = yes, all done
	stosb				; store filespec char
	or	cx,cx			; any chars left?
	jg	short gcmdl6		; g = yes
gcmdl7:	mov	byte ptr es:[di],0	; end filespec on a null
	pop	di			; recover destination pointer es:di
	pop	es
gcmdl8:	or	cx,cx			; strip trailing whitespace
	jle	gcmdl10			; le = nothing left
	lodsb
	dec	cx
	cmp	al,' '			; white space?
	jbe	gcmdl8			; be = yes, strip it
	cmp	al,','			; at next command?
	je	gcmdl10			; e = yes, skip our own comma
	dec	si			; back up to reread the char
	inc	cx
	jmp	gcmdl3			; read more command text
					; end of flag analysis
gcmdl9:	stosb				; deposit most recent char
gcmdl10:or	cx,cx			; anything left to read?
	jg	gcmdl3			; g = yes, loop
					;
	mov	ax,data			; restore segment registers
	mov	DS,ax
	mov	si,[bx].takbuf		; get segment of Take buffer
	mov	es,si
	mov	si,2			; skip count word
	mov	cx,di			; current end pointer, (save di)
	sub	cx,si			; current ptr minus start offset
	mov	[bx].takcnt,cx		; chars in buffer so far
        mov     es:word ptr [0],cx      ; store count word
	xor	dx,dx			; brace count
	or	cx,cx
	jg	gcmdl11			; g = material at hand
	call	takclos			; empty take file
	jmp	short gcmdl14		; finish up
					; scan for command "stay"
gcmdl11:mov	ax,es:[si]		; get 2 bytes, cx and si are set above
	inc	si			; increment by only one char
	dec	cx
	call	bracechk		; check for braces
	jc	gcmdl12			; c = brace found
	cmp	al,' '			; separator?
	jbe	gcmdl12			; be = yes, keep looking
	cmp	al,',' 			; comma separator?
	je	gcmdl12			; e = yes
	or	dx,dx			; within braces?
	jnz	gcmdl12			; nz = yes, skip STAY search
	or	ax,2020h		; convert to lower case
	cmp	ax,'ts'			; first two letters of stay
	jne	gcmdl12			; ne = no match
	mov	ax,es:[si+1]		; next two letters (stay vs status)
	or	ax,2020h		; convert to lower case
	cmp	ax,'ya'			; same as our pattern?
	jne	gcmdl12			; ne = no match
	add	si,3			; char after "stay"
	sub	cx,3
					; check for separator or end of macro
	cmp	byte ptr es:[si],' '	; next char is a separator?
	jbe	gcmdl13			; be = yes, found correct match
	cmp	byte ptr es:[si],','	; or comma separator?
	je	gcmdl13			; e = yes
	or	cx,cx			; at end of macro?
	jle	gcmdl13			; yes, consider current match correct
gcmdl12:or	cx,cx			; done yet? ("stay" not found)
	jg	gcmdl11			; g = not yet, look some more
	mov	cmdlinetake,1		; remember doing DOS cmd line Take
	mov	si,offset eexit		; append command "exit"
	mov	cx,leexit		; length of string "exit"
	add	[bx].takcnt,cx
	rep	movsb			; copy it into the Take buffer
gcmdl13:mov     [bx].takptr,2           ; init buffer ptr
        mov     cx,[bx].takcnt          ; count of bytes in buffer
        mov     es:[0],cx               ; count of bytes in Take buffer
gcmdl14:pop	es
	ret
gcmdlin	endp

; Curly brace checker. Examine (and preserve) char in AL. Count up/down
; braces in dx because DS is unknown here
bracechk proc	near
	cmp	al,braceop		; opening brace?
	jne	bracech1		; ne = no
	inc	dx			; count up braces
	stc				; say brace seen
	ret
bracech1:cmp	al,bracecl		; closing brace
	jne	bracech3		; ne = no
	sub	dx,1			; count down with sign
	jns	bracech2		; ns = no underflow
	xor	dx,dx			; don't go below zero
bracech2:stc				; say brace detected
	ret
bracech3:clc				; say brace not found
	ret
bracechk endp
code1	ends
code	segment
	assume	cs:code

; Enter with ax pointing to file name.  Searches path for given file,
; returns with ax pointing to whole name, or carry set if file can't be found.
SPATH	proc	near
	call	isfile			; does it exist as it is?
	jc	spath0			; c = no, prepend path elements
	test	byte ptr filtst.dta+21,10H ; subdirectory name?
	jnz	spath0			; nz = yes, not desired file
	push	di
	mov	di,ax
	push	di
	push	ax
	mov	dx,di			; get string length
	call	strlen
	cld
	push	es
	mov	ax,ds
	mov	es,ax
	mov	al,'\'			; look for path separator
	repne	scasb			; scan es:di for separator
	pop	es
	pop	ax
	pop	di
	je	spath14			; e = found, use as-is
	cmp	byte ptr [di+1],':'	; drive already given?
	jne	spath10			; ne = no
spath14:pop	di
	clc
	ret				; path stuff is already in ax

spath10:push	bx
	mov	bx,[di]
	and	bx,not 2020h		; to upper
	cmp	bx,'UN'			; look for DOS 5 NUL
	jne	spath11			; ne = mismatch
	mov	bx,[di+2]
	and	bl,not 20h
	cmp	bx,'L'+0
spath11:pop	bx
	jne	spath12			; ne = mismatch
	pop	di
	clc
	ret

spath12:push	ax
	mov	di,offset decbuf+64	; where results will be returned
	mov	ah,gcurdsk		; get current disk
	int	dos
	inc	al			; make 1 == A (not zero)
	add	al,'A'-1		; make al alphabetic disk drive again
	mov	[di],al			; put it into original path descriptor
	inc	di
	mov	word ptr [di],'\:'	; add drive specifier too
	add	di,2
	push	si
	mov	si,di
	mov	ah,gcd			; get current directory (path really)
	xor	dl,dl			; use current drive
	int	dos
	pop	si
	push 	dx
	mov	dx,di			; find end of string
	call	strlen
	pop	dx
	add	di,cx			; step after path
	pop	ax
	push	si
	mov	dx,ax			; this is user's file name
	mov	si,offset decbuf+200	; filename goes here, temp
	push	di			; preserve di from above
	mov	di,offset decbuf+220	; far away, path, temp
	call	fparse			; get filename to ds:si
	pop	di
	cmp	byte ptr [di-1],2fh	; does path end with switch char?
	je	spath13			; yes, don't put one in
	cmp	byte ptr [di-1],5ch	; how about this one?
	je	spath13			; yes, don't put it in
	mov	byte ptr [di],5ch	; else add one
	inc	di
spath13:lodsb				; get filename character
	mov	byte ptr [di],al	; copy filename char to output buffer
	inc	di
	or	al,al			; end of string?
	jnz	spath13			; nz = no, copy rest of name
	pop	si			; restore postion in path string
	pop	di
	mov	ax,offset decbuf+64	; return results in ax
	clc
	ret

spath0:	push	es			; save es around work
	push	bx
	push	si
	push	di
	mov	bx,ax			; save filename pointer in bx
	mov	si,ax
	xor	dl,dl			; no '\' seen yet
	cld
spath1:	lodsb
	cmp	al,2fh			; contains fwd slash path characters?
	je	spath1a
	cmp	al,5ch			; or backslash?
	jne	spath2			; ne = no, keep going
spath1a:mov	dl,1			; remember we've seen them
spath2:	or	al,al
	jnz	spath1			; copy name in
	or	dl,dl			; look at flag
	jz	spath3			; no path, keep looking
	jmp	short spath9		; embedded path, fail

spath3:	call	skpath			; search kermit's path
	jnc	spath8a			; nc = located file
	mov	si,pthadr		; offset of PATH= string in environment
	mov	es,psp
	mov	di,es:word ptr[env]	; pick up environment segment
	mov	es,di
spath4:	cmp	byte ptr es:[si],0	; end of PATH= string?
	je	spath9			; e = yes, exit loop
	mov	di,offset decbuf+64	; place to put name
spath5:	mov	al,byte ptr es:[si]	; get a byte from environment string
	inc	si
	cmp	al,';'			; end of this part?
	je	spath7			; yes, break loop
	or	al,al			; maybe end of string?
	jnz	spath6			; nz = no, keep going
	dec	si			; back up to null for later rereading
	jmp	short spath7		; and break loop
spath6:	mov	byte ptr [di],al	; else stick in dest string
	inc	di
	jmp	short spath5		; and continue
spath7:	push	si			; save this ptr
	mov	si,bx			; this is user's file name
	cmp	byte ptr [di-1],2fh	; does path end with switch char?
	je	spath8			; yes, don't put one in
	cmp	byte ptr [di-1],5ch	; how about this one?
	je	spath8			; yes, don't put it in
	mov	byte ptr [di],5ch	; else add one
	inc	di
spath8:	lodsb				; get filename character
	mov	byte ptr [di],al	; copy filename char to output buffer
	inc	di
	or	al,al			; end of string?
	jnz	spath8			; nz = no, copy rest of name
	pop	si			; restore postion in path string
	mov	ax,offset decbuf+64
	call	isfile			; is it a file?
	jc	spath4			; c = no, keep looking
	test	byte ptr filtst.dta+21,10H ; subdirectory name?
	jnz	spath4			; nz = yes
spath8a:pop	di
	pop	si
	pop	bx
	pop	es
	clc
	ret				; return success (carry clear)
spath9:	mov	ax,bx			; restore original filename pointer
	pop	di			; restore regs
	pop	si
	pop	bx
	pop	es
	stc				; no file found
	ret
spath	endp

; Search Kermit's path for file. Return carry clear if found, else carry set.
; Worker for spath above.
skpath	proc	near
	mov	si,seg kpath		; Kermit's path string
	mov	es,si
	mov	si,offset kpath
	mov	di,offset decbuf+64	; place to put name
skpath1:mov	al,es:[si]		; get a byte from string
	inc	si
	cmp	al,';'			; end of this part?
	je	skpath3			; yes, break loop
	or	al,al			; maybe end of string?
	jnz	skpath2			; nz = no, keep going
	dec	si			; back up to null for later rereading
	jmp	short skpath3		; and break loop
skpath2:mov	byte ptr [di],al	; else stick in dest string
	inc	di
	jmp	short skpath1		; and continue
skpath3:cld
	mov	si,bx			; this is user's file name
	cmp	byte ptr [di-1],2fh	; does path end with switch char?
	je	skpath4			; yes, don't put one in
	cmp	byte ptr [di-1],5ch	; how about this one?
	je	skpath4			; yes, don't put it in
	mov	byte ptr [di],5ch	; else add one
	inc	di
skpath4:lodsb				; get filename character
	mov	byte ptr [di],al	; copy filename char to output buffer
	inc	di
	or	al,al			; end of string?
	jnz	skpath4			; nz = no, copy rest of name
	mov	ax,offset decbuf+64
	push	bx
	call	isfile			; is it a file?
	pop	bx
	jnc	skpath5			; nc = yes
	ret
skpath5:test	byte ptr filtst.dta+21,10H ; subdirectory name?
	jnz	skpath6			; nz = yes
	clc				; report file found (AX as offset)
	ret
skpath6:stc				; report failure
	ret
skpath	endp

; Put Kermit's Enviroment Path indicator into string kpath
mkkpath	proc	near
	mov	bx,offset rdbuf
	mov	word ptr rdbuf,0
	xor	dx,dx
	mov	comand.cmblen,64	; 64 bytes max
	mov	ah,cmword		; get a word, with semicolons
	call	comnd
	jnc	mkkpath1		; nc = success
	ret
mkkpath1:mov	cx,ax			; get string length
	push	si
	push	di
	push	es
	mov	si,offset rdbuf		; source
	mov	di,seg kpath		; storage spot
	mov	es,di
	mov	di,offset kpath
	cld
	rep	movsb			; copy
	mov	word ptr es:[di],0	; terminate
	pop	es
	pop	di
	pop	si
	ret
mkkpath	endp

; Put offset of PATH= string in pthadr
getpath	proc	near
	push	bx
	push	cx
	push	dx
	mov	bx,offset pthnam	; thing	to find
	mov	cx,pthlen		; length of it
	mov	pthadr,0		; init offset to zero
	call	getenv			; get environment value
	mov	pthadr,dx
	pop	dx
	pop	cx
	pop	bx
	ret
getpath	endp

; getcsp: copy COMSPEC= environment string into cmspbuf
; getssp: copy SHELL=   environment string into shellbuf
; getdostemp: copy TEMP= environment string into dostemp
getcsp	proc	near
	mov	bx,offset cmspnam	; find COMSPEC=
	mov	cx,cmsplen		; its length
	mov	di,offset cmspbuf	; where to store string
	jmp	short getccom		; do common worker

getssp:	mov	bx,offset shellnam	; find SHELL=
	mov	cx,shellen		; its length
	mov	di,offset shellbuf	; where to store string
	jmp	short getccom		; do common worker

getdostemp:mov	bx,offset dostempname	; fine TEMP=
	mov	cx,dostempnlen		; its length
	mov	di,offset dostemp+3	; where to store string

getccom:push	es
	call	getenv			; get environment offset into dx
	jc	getcs3			; c = not found
	mov	si,dx			; address of COMSPEC= string
	mov	es,psp
	mov	bx,es:word ptr[env]	; pick up environment address
	mov	es,bx
	push	ds			; save ds
	push	ds			; make ds point to environment seg
	push	es			; make es point to data segment
	pop	ds
	pop	es
	cld
getcs1:	lodsb				; get a byte from environment
	cmp	al,' '			; space or less?
	jg	getcs2			; g = no, keep copying
	xor	al,al			; terminate string on spaces etc
getcs2:	stosb				; store it in destination
	or	al,al			; at end of string yet?
	jnz	getcs1			; nz = no, keep copying
	pop	ds			; recover ds
getcs3:	pop	es
	ret
getcsp	endp

; Get Kermit parameters from the Environment. Parameters are commands like
; regular commands except they do not appear in the SET main table and are
; separated from one another by semicolons. They appear after KERMIT=.
; Do not allow Take/Macros to be created by any of these commands.
; On fatal error exits with carry set and flags.extflg = 1
getparm	proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	es
	mov	es,psp			; segment of our PSP
	mov	ax,es:word ptr[env]	; pick up environment address
	mov	es,ax
	mov	bx,offset kerenv	; Environment word to find, asciiz
	mov	dx,bx
	call	strlen			; length of its string to cx
	call	getenv			; return dx = offset in environment
	jnc	getpar1			; nc = success
	jmp	getpar9			; c = not found
getpar1:push	ds			; save regular DS
	push	dx			; push Environment offset, then seg
	push	es
	call	takopen_macro		; open Take buffer in macro space
	jnc	getpar2			; nc = success
getpar1a:mov	flags.extflg,1		; say exit now
	pop	es			; clean stack
	pop	dx
	pop	ds
	jmp	getparx			; exit with fatal error

getpar2:mov	ax,tbufsiz		; take buffer size (bytes)
	call	malloc			; get memory, seg returned in AX
	jc	getpar1a		; c = failed
	mov	bx,takadr		; bx = Take data structure
	mov	[bx].takbuf,ax		; segment of memory
	or	[bx].takattr,take_malloc ; remember to dispose via takclos
	mov	es,ax			; ES = segment of buffer
        mov     di,2                    ; skip count word field for es:di
	pop	ds			; pop Environment segment (was in ES)
	pop	si			;  and seg, DS:SI is now Environment
	xor	cx,cx			; line length counter
getpar3:lodsb				; read an Environment character
	or	al,al			; null (EOL)?
	jz	getpar5			; z = yes, stop here
	cmp	al,';'			; semicolon separator?
	jne	getpar4			; ne = no
	mov	al,CR			; replace semicolon with carriage ret
getpar4:stosb				; store char in Take buffer
	inc	cx			; count line length
	jmp	short getpar3		; get more text, until a null

getpar5:mov	al,CR			; terminate line, regardless
	stosb
	inc	cx			; count terminator
	pop	ds			; restore regular DS
	mov	[bx].takcnt,cx		; chars in Take/macro buffer
        mov     es:[0],cx               ; store count byte
        mov     [bx].takptr,2           ; init buffer read ptr to first char
	jcxz	getpar8			; z = nothing left, exit
					; parse each item as a command
getpar6:mov	comand.cmquiet,1	; no screen display
	mov	dx,offset nulprmpt	; set null prompt
	call	prompt
	cmp	flags.extflg,0		; exit flag set?
	jne	getpar8			; ne = yes, exit this routine now
	mov	dx,offset initab	; table of initialization routines
	xor	bx,bx			; no explict help text
	mov	comand.cmcr,1		; allow bare CR's
	mov	comand.impdo,0		; do not search Macro table
        mov	ah,cmkey		; match a keyword
	call	comnd
	jc	getpar7			; c = failure
	mov	comand.cmcr,0		; no more bare CR's
	call	bx			; call the routine returned in BX
					; ignore failures (carry bit set)
getpar7:cmp	taklev,0		; finished Take file?
	jle	getpar9			; le = yes
	cmp	flags.extflg,0		; exit flag set?
	je	getpar6			; e = no, finish all commands

getpar8:call	takclos			; close our take file, if open
getpar9:mov	flags.extflg,0		; do not leave this flag set
	clc				; clear for success
getparx:mov	comand.cmquiet,0	; regular screen echoing
	pop	es
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
getparm	endp

; Locate string variable in Environment
; bx = variable to find (usually including =), cx = length of variable name.
; Returns dx = offset within Environment of char following the name and
; carry clear, else carry set and dx unchanged.
getenv	proc	near
	push	ax
	push	cx
	push	si
	push	di
	push	es
	mov	es,psp
	mov	ax,es:word ptr[env]	; pick up environment address
	mov	es,ax
	xor	di,di			; start at offset 0 in segment
geten1:	cmp	es:byte ptr [di],0	; end of environment?
	je	geten3			; yes, forget it
	push	cx			; save counter
	push	di			; and offset
	mov	si,bx
	cld
	repe	cmpsb			; search for name
	pop	di
	pop	cx			; restore these
	je	geten2			; found it, break loop
getenv5:push	cx			; preserve again
	mov	cx,0ffffh		; bogus length
	xor	al,al			; 0 = marker to look for
	repne	scasb			; search for it
	pop	cx			; restore length
	jmp	short geten1		; loop thru rest of environment
geten2:	add	di,cx			; skip to definition
geten6:	mov	si,bx			; name
	add	si,cx			; length
	cmp	byte ptr [si-1],'='	; caller wanted '=' as last char?
	je	geten7			; e = yes, and we found it
	mov	al,es:[di]		; get next char
	cmp	al,'='			; at the equals sign?
	je	geten7			; e = yes
	inc	di			; point at next char
	cmp	al,' '			; white space?
	jbe	geten6			; be = yes, skip over this
	dec	di			; backup
	jmp	short getenv5		; not a match, keep looking
geten7:	mov	dx,di			; store offset of string
	clc				; carry clear for success
	jmp	short geten4
geten3:	stc				; carry set for failure
geten4:	pop	es
	pop	di
	pop	si
	pop	cx
	pop	ax
	ret
getenv	endp

; SETENV
; Put  "NAME=string" to the DOS master environment, uses undocumented Int 2Eh
setenv	proc	near
	mov	bx,offset decbuf+1	; borrowed buffer
	mov	word ptr [bx],'ES'
	mov	word ptr [bx+2],' T'	; preload "SET "
	add	bx,4			; where rest of text goes
	mov	dx,offset setenvhlp	; help
	mov	comand.cmblen,126 - 4	; max buffer length
	mov	ah,cmline		; get line of text
	call	comnd
	jnc	setenv1			; nc = success
	ret				; failure

setenv1:mov	bx,offset decbuf+1+4	; look after "SET " 
	add	bx,ax			; plus length of user string
	mov	word ptr [bx],CR	; terminate in CR NUL
	sub	bx,offset decbuf	; compute length
	mov	decbuf,bl		; <count byte><text>CR
	mov	ah,getintv		; does Int 2eh exist?
	mov	al,2eh
	int	dos
	jnc	setenv2			; nc = call succeeded
	ret
setenv2:cmp	byte ptr es:[bx],0cfh	; is an IRET?
	jne	setenv3			; no, assume vector exists
	stc
	ret
setenv3:push	si
	push	di
	push	bp
	cli
	mov	ax,ss			; save ss:sp
	mov	word ptr ssave+2,ax
	mov	word ptr ssave,sp
	sti
	cld
	mov	si,offset decbuf	; string pointer to ds:si
	int	2eh			; Command.com, do contents of ds:si
	mov	bx,data			; restore segment registers
	mov	ds,bx			; reset data segment
	mov	es,bx			; and extra segment
	cli
	mov	bx,word ptr ssave+2
	mov	ss,bx			; and stack segment
	mov	sp,word ptr ssave	; restore stack ptr
	sti
	pop	bp
	pop	di
	pop	si
	clc
	ret
setenv	endp

; Store drive:path\ of where Kermit was started into string startup
getargv	proc	near
	push	si
	push	di
	push	es
	mov	es,psp
	mov	ax,es:word ptr[env]	; pick up environment address
	mov	es,ax
	xor	di,di			; start at offset 0 in segment
	mov	cx,0ffffh		; bogus length
getargv1:xor	al,al			; 0 = marker to look for
	repne	scasb			; search for it
	cmp	es:byte ptr [di],0	; end of environment (double null)?
	jne	getargv1		; ne = no
	inc	di			; skip single null
	cmp	es:word ptr [di],1	; marker for argv[0]?
	jne	getargv5		; ne = no
	add	di,2			; skip word
	mov	si,offset startup	; startup string
	mov	cx,63			; max length of wanted string
getargv2:mov	al,es:[di]		; get char
	mov	[si],al			; store in startup string
	inc	si
	inc	di
	or	al,al			; null terminator?
	loopnz	getargv2		; nz = no
					; trim off filename part
	mov	cx,si
	sub	cx,offset startup
	dec	si
getargv3:cmp	byte ptr [si],':'	; back to drive terminator?
	jne	getargv3a		; ne = no
	mov	byte ptr [si+1],'\'	; make drive:\ syntax for root
	inc	si			; move over separators
	jmp	short getargv4		; done
getargv3a:cmp	byte ptr [si],'\'	; or path separator?
	je	getargv4		; e = yes
	dec	si			; backup
	loop	getargv3

getargv4:mov	byte ptr [si+1],0	; terminate string
getargv5:pop	es
	pop	di
	pop	si
	ret
getargv	endp

; Get thousands separator from DOS Country Information
gettsep	proc	near
	mov	ah,38h			; Get Country Information
	mov	dx,offset tmpbuf	; temp buffer
	int	dos
	mov	bx,7			; assume DOS 3+ position in buffer
	cmp	byte ptr dosnum+1,3	; DOS 3 or above?
	jae	gettse1			; ae = yes
	mov	bx,4			; for DOS 2.1
	cmp	dosnum,210h		; earlier than version 2.1?
	jae	gettse1			; ae = no
	mov	al,','			; use comma for old DOS's
gettse1:mov	al,tmpbuf[bx]		; get thousands separator char
	mov	thsep,al		; save it
	mov	al,tmpbuf		; get time/date format code
	mov	tdfmt,al		; save it
	ret
gettsep	endp

STAY	PROC	NEAR
	clc
	ret
STAY	ENDP

; CHECK <build features>, returns success if feature is present
CHECK	proc	near
	mov	kstatus,kssuc		; global status
	mov	ah,cmkey
	mov	dx,offset featab	; feature table
	xor	bx,bx			; table is help
	call	comnd
	jnc	check1			; nc = success
	mov	kstatus,ksgen		; general failure
	ret
check1:	push	bx
	mov	ah,cmeol
	call	comnd
	pop	bx
	jnc	check1a
	mov	kstatus,ksgen		; general failure
	ret
check1a:mov	di,offset tmpbuf
	cmp	bx,1			; graphics?
	jne	check2			; ne = no
	mov	si,offset msggraph
	call	strcpy
ifdef	no_graphics
	mov	kstatus,ksgen
	mov	si,offset msgnot
	call	strcat
endif
	jmp	short check6

check2:	cmp	bx,2			; tcp/ip?
	jne	check3			; ne = no
	mov	si,offset msgtcpip
	call	strcpy
ifdef	no_tcp
	mov	kstatus,ksgen
	mov	si,offset msgnot
	call	strcat
endif
	jmp	short check6

check3:	cmp	bx,3			; networks?
	jne	check4			; ne = no
	mov	si,offset msgnetwork
	call	strcpy
ifdef	no_network
	mov	kstatus,ksgen
	mov	si,offset msgnot
	call	strcat
endif
	jmp	short check6

check4:	cmp	bx,4			; terminals?
	jne	check5			; ne = no
	mov	si,offset msgterm	; terminals
	call	strcpy
ifdef	no_terminal
	mov	kstatus,ksgen
	mov	si,offset msgnot
	call	strcat
endif
	jmp	short check6

check5:	mov	si,offset msgif		; IF statements
	call	strcpy

check6:	mov	si,offset msgavail
	call	strcat
	cmp	taklev,0		; at top level?
	jne	checkx			; ne = no, be quiet
	mov	dx,offset tmpbuf	; show msg
	mov	ah,prstr
	int	dos
checkx:	ret				; return status
CHECK	endp

TESTCOM	proc	near
	mov	kstatus,kssuc		; global status
	mov	ah,cmkey
	mov	dx,offset chktab	; check comm port table
	xor	bx,bx			; table is help
	call	comnd
	jnc	testc1			; nc = success
	mov	kstatus,ksgen		; general failure
	ret
testc1:	mov	al,flags.comflg		; save current comms port flag
	push	ax
	mov	flags.comflg,bl		; port number, 1..4
	call	tstport			; see if real UART, carry set if not
	pop	ax
	mov	flags.comflg,al		; restore flag
	mov	dx,offset erms39	; say UART
	jnc	testc2			; nc = real UART
	mov	dx,offset erms38	; say non-UART
	mov	kstatus,ksgen		; set failure state for non-UART
testc2:	cmp	taklev,0		; in a Take file or macro?
	je	testc3			; e = no, display
	cmp	flags.takflg,0		; Take echo off?
	je	testc4			; e = yes, do not display
testc3:	mov	ah,prstr
	int	dos
testc4:	ret
TESTCOM endp

CLS	proc	near			; Clear command level screen
	mov	ah,cmeol		; get a confirmation
	call	comnd
	jc	cls1			; c = failure
	call	cmblnk			; blank the screen
	call	locate			; put cursor at home position
cls1:	ret
CLS	endp

COMNT	PROC	NEAR			; COMMENT command
	mov	ah,cmline
	mov	bx,offset tmpbuf
	xor	dx,dx			; help
	call	comnd
	jc	comnt1
	mov	ah,cmeol
	call	comnd
comnt1:	ret
COMNT	ENDP

; change working directory
cwdir	proc	near
	mov	kstatus,kssuc		; global status
	mov	ah,cmword
	mov	bx,offset tmpbuf
	mov	dx,offset pthmsg
	mov	word ptr tmpbuf,0
	call	comnd			; get drive/dir spec, if any
	mov	ah,cmeol
	call	comnd
	jnc	cwd1
	ret				; c = failure
cwd1:	mov	si,offset tmpbuf	; cdsr wants drive/path ptr in si
	call	cdsr			; common CD sub-routine
	jnc	cwd2			; nc = success
	mov	kstatus,ksgen		; global status for unsuccess
cwd2:	cmp	taklev,0		; in a Take file or macro?
	je	cwd3			; e = no, do echo
	cmp	flags.takflg,0		; ok to echo?
	je	cwd4			; e = no
cwd3:	push	dx
	mov	dx,offset crlf		; msgs from cdsr don't include this
	mov	ah,prstr		; so let's do it now
	int	dos
	pop	dx
	call	prtasz			; output current drive/path or err msg
cwd4:	clc
	ret
cwdir	endp

; Erase specified file(s). Add protection of ignore hidden, subdir, volume
; label and system files. 9 Jan 86 [jrd]
DELETE	PROC	NEAR			; includes paths and "?*" wildcards
	mov	kstatus,kssuc		; global status
	mov	si,offset delcmd	; del command
	mov	di,offset tmpbuf
	call	strcpy
	mov	dx,offset tmpbuf
	call	strlen			; get its length
	add	di,cx			; point at terminator
	mov	temp,di			; remember starting spot
	mov	ah,cmline		; get a line
	mov	bx,di			; where to place the file spec
	mov	dx,offset filmsg	; help message
	call	comnd
	jc	delet0			; c = failure
	push	ax
	mov	ah,cmeol
	call	comnd
	pop	ax
	jc	delet0
	cmp	apctrap,0		; disable from APC
	jne	delet0			; ne = yes
	or	ax,ax			; anything given?
	jnz	delet1			; nz = yes
	mov	ah,prstr
	mov	dx,offset ermes1	; say need something
	int	dos
	clc				; say success
delet0:	mov	kstatus,ksgen		; global status
	ret

delet1:	mov	si,offset tmpbuf	; source
	mov	di,temp			; start of filespec
	xor	cl,cl			; disk drive letter
	cmp	byte ptr [di+1],':'	; drive specified?
	jne	delet2			; ne = no
	mov	cl,[di]			; get drive letter
delet2:	call	dskspace		; compute space, get letter into CL
	jnc	delet3			; nc = success
	mov	spcmsg3,cl		; put drive letter in msg
	mov	dx,offset spcmsg2	; error message
	call	prtasz
	mov	kstatus,ksgen		; global status
	clc
	ret				; and ignore this command
delet3:	mov	si,offset tmpbuf	; del cmd
	jmp	crun			; join run cmd from there
DELETE	ENDP

; Space <optional drive letter>

CHKDSK	PROC	NEAR			; Space command
	mov	kstatus,kssuc		; global status
	mov	bx,offset tmpbuf	; buffer
	mov	tmpbuf,0		; init to null
	mov	dx,offset dskmsg	; help message
	mov	ah,cmword		; get optional drive letter
	call	comnd			; ignore errors
	mov	ah,cmeol
	call	comnd
	jnc	chkdsk1			; nc = success
	ret				; failure
chkdsk1:mov	cl,tmpbuf		; set drive letter
	call	dskspace		; compute space, get letter into CL
	jnc	chkdsk2			; nc = success
	and	cl,5fh			; to upper case
	mov	spcmsg3,cl		; insert drive letter
	mov	dx,offset spcmsg2	; say drive not ready
	call	prtasz
	mov	kstatus,ksgen		; global status
	clc
	ret
	
chkdsk2:mov	spcmsg1,cl		; insert drive letter
	mov	di,offset tmpbuf	; work space for lnout
	mov	word ptr[di],0a0dh	; cr/lf
	mov	word ptr[di+2],'  '	; add two spaces
	add	di,4
	call	lnouts			; use thousands separator
	mov	si,offset spcmsg
	call	strcat			; add text to end of message
	mov	dx,offset tmpbuf
	call	prtasz			; print asciiz string
	clc
	ret
CHKDSK	ENDP


; Get directory	listing
DIRECT	PROC	NEAR
	mov	kstatus,kssuc		; global status
	mov	si,offset dircmd	; dir command
	mov	di,offset tmpbuf
	call	strcpy
	mov	dx,offset tmpbuf
	call	strlen			; get its length
	add	di,cx			; point at terminator
	mov	temp,cx			; remember length
	mov	ah,cmline		; parse with cmline to allow switches
	mov	bx,di			; next available byte
	mov	dx,offset filmsg	; help message 
	call	comnd
	jnc	direct1			; nc = success
direct0:mov	kstatus,ksgen		; global status
	ret				; failure
direct1:mov	ah,cmeol
	call	comnd
	jc	direct0
	mov	word ptr [bx],0		; plant terminator
	mov	si,offset tmpbuf
	push	si
	add	si,temp			; user's text after ' dir '
	mov	cl,curdsk		; current drive number ('A'=1)
	add	cl,'A'-1		; make a letter
	cmp	byte ptr [si+1],':'	; drive specified?
	jne	direct2			; ne = no, use current drive
	mov	cl,[si]			; get drive letter from buffer
direct2:call	dskspace		; check for drive ready
	pop	si
	jnc	direct3			; nc = drive ready
	mov	spcmsg3,cl		; insert letter
	mov	dx,offset spcmsg2	; say drive is not ready
	call	prtasz
	mov	kstatus,ksgen		; global status
	stc
	ret
direct3:jmp	crun			; join run cmd from there
DIRECT	ENDP

; This is the 'HELP' command.  It gives a list of the commands
; And INTRO command
INTRO	proc	near
	mov	kstatus,kssuc		; global status
	mov	ah,cmeol
	call	comnd			; get a confirm
	jnc	intro1			; nc = success
	ret				; failure
intro1:
ifdef	no_terminal
	ret
else
	push	es
	mov	ax,seg intrhlp		; all Intro text is in data1
	mov	es,ax
	mov	al,trans.escchr		; Connect mode escape char
	cmp	al,' '			; printable now?
	jae	intro2			; ae = yes
	add	al,40h			; make control visible
intro2:	mov	si,offset intrhlp1
	mov	es:[si],al
	mov	si,offset intrhlp2
	mov	es:[si],al
	mov	si,offset intrhlp	; Intro text in seg data1
	xor	bx,bx			; line counter
	cld
 	jmp	short help2		; common tail
endif	; ifdef no_terminal
INTRO	endp

HELP	PROC	NEAR
	mov	kstatus,kssuc		; global status
	mov	ah,cmeol
	call	comnd			; get a confirm
	jnc	help1			; nc = success
	ret				; failure
help1:	mov	si,offset qckhlp	; help text in seg data1
	xor	bx,bx			; line counter
	push	es
	mov	ax,seg qckhlp		; all help text is in data1
	mov	es,ax
	cld

HELP2:	mov	al,es:[si]		; read a help msg byte
	inc	si
	cmp	al,'$'			; end of message?
	je	help3			; e = yes, stop
	mov	ah,conout
	mov	dl,al
	int	dos			; display byte
	cmp	dl,LF			; line break?
	jne	help2			; ne = no
	inc	bl			; count line
	cmp	bl,dos_bottom		; (24) time for a more msg?
	jbe	help2			; be = not yet
	xor	bl,bl			; reset line count
	call	iseof			; are we at EOF, such as from disk?
	jc	help2			; c = yes, ignore more msg
	push	es
	push	si
	mov	ah,prstr
	mov	dx,offset moremsg	; "... more..." msg
	int	dos
	pop	si
	pop	es
	mov	ah,coninq		; read the char from file, not device
	int	dos
	cmp	al,3			; a ^C?
	je	short help3		; e = yes, stop the display
	cmp	al,'?'			; query?
	je	helpquery		; e = yes
	push	bx			; save line counter
	push	es			; and read pointer
	push	si
	call	ctlu			; clear display's line, reuse it
	pop	si
	pop	es
	pop	bx
	jmp	short help2		; continue
help3:	pop	es
	clc
	ret

helpquery:pop	es
	mov	ah,prstr		; show help summary screen
	mov	dx,offset crlf		; a few blank lines
	int	dos
	int	dos
	int	dos
	push	ds
	mov	dx,seg tophlp
	mov	ds,dx
	mov	dx,offset tophlp	; show usual cryptic help
	int	dos
	pop	ds
	clc
	ret
HELP	ENDP

; the version command - print our version number
prvers	proc	near
	mov	kstatus,kssuc		; global status
	mov	ah,cmeol
	call	comnd
	jc	prvers1			; c = failure
	mov	ah,prstr
	mov	dx,offset crlf
	int	dos
	mov	ah,prstr
	mov	dx,offset machnam	; display machine name
	int	dos
	mov	ah,prstr		; display the version header
	mov	dx,offset verident
	int	dos
	mov	ah,prstr
	mov	dx,offset copyright2	; full copyright notice
	int	dos
	clc
prvers1:ret
prvers	endp

; SHOW command dispatcher
showcmd	proc	near
	mov	ah,cmkey
	mov	dx,offset shotab
	xor	bx,bx			; no canned help
	call	comnd
	jc	showc1			; c = failure
	jmp	bx			; execute the handler
showc1:	ret				; failure
showcmd	endp

; the type command - type out a file
typec	proc	near
	mov	kstatus,kssuc		; global status
	mov	si,offset typcmd	; type command
	mov	di,offset tmpbuf
	call	strcpy
	mov	dx,offset tmpbuf
	call	strlen			; get its length
	add	di,cx			; point at terminator
	mov	temp,di			; save place for later
	mov	ah,cmline		; parse with cmline, allows | more
	mov	bx,di			; next available byte
	mov	dx,offset filmsg	; In case user wants help
	call	comnd
	jc	typec1			; c = failure
	push	ax
	mov	ah,cmeol
	call	comnd
	pop	ax
	jc	typec1
	or	ax,ax			; any text given?
	jnz	typec2			; nz = yes
	mov	ah,prstr
	mov	dx,offset ermes1	; say need more info
	int	dos
	mov	kstatus,ksgen		; global status
	clc
typec1:	ret
typec2:	mov	byte ptr [bx],0		; plant terminator
	mov	si,temp			; start of filespec
	xor	cl,cl			; say local drive
	cmp	byte ptr [si+1],':'	; drive given?
	jne	typec3			; ne = no
	mov	cl,[si]			; get drive letter
typec3:	call	dskspace		; check for drive ready
	jnc	typec4
	mov	spcmsg3,cl		; put drive letter in msg
	mov	dx,offset spcmsg2	; error message
	call	prtasz
	mov	kstatus,ksgen		; global status
	clc
	ret				; and ignore this command
typec4:	mov	si,offset tmpbuf
	jmp	short crun		; join run cmd from there
typec	endp

; PUSH to DOS (run another copy of Command.com or equiv)
; entry fpush (fast push...) pushes without waiting for a confirm
dopush	proc	near
	mov	ah,cmeol
	call	comnd
	jnc	fpush			; nc = success
	ret				; failure
fpush:	cmp	nopush_flag,0		; pushing allowed?
	jne	fpush1			; ne = no
	mov	si,offset tmpbuf	; a dummy buffer
	mov	byte ptr [si],0		; plant terminator
	mov	dx,offset cmspbuf	; always use command.com
	cmp	shellbuf,0		; SHELL= present?
	je	crun4			; e = no, use COMSPEC= name
	mov	dx,offset shellbuf	; use SHELL= name
	jmp	short crun4		; go run it
fpush1:	stc				; fail
	ret
dopush	endp

; Run a program from within Kermit
RUN	PROC	NEAR
	mov	ah,cmline		; get program name and any arguments
	mov	bx,offset tmpbuf	; place for user's text
	mov	dx,offset runmsg	; In case user wants help
	call	comnd
	jnc	run1			; nc = success
	ret				; failure
run1:	cmp	apctrap,0		; disable from APC
	jne	run3			; ne = yes, fail
	cmp	nopush_flag,0		; pushing disabled?
	jne	run3			; ne = yes, fail
	or	ax,ax			; byte count
	jnz	run2			; nz = have program name
	mov	ah,prstr		; else complain
	mov	dx,offset ermes1	; need more info
	int	dos
	clc
	ret
run2:	mov	si,offset tmpbuf	; source of text
	jmp	short crun

run3:	stc				; failure exit
	ret
RUN	ENDP

; crun - run an arbitrary program.
; Enter with ordinary ASCIIZ command in SI (such as Dir *.asm)
; Append a c/r and a null terminator and then ask command.com to do it
; Set errlev with DOS errorlevel from subprocess.
CRUN	proc	near
	mov	ah,prstr		; output crlf before executing comnd
	mov	dx,offset crlf		; [lba]
	int	dos
	mov	di,offset tmpbuf	; where to put full command line text
	cmp	si,di			; same place?
	je	crun1			; e = yes, don't copy ourself
	call	strcpy			; si holds source text
crun1:	mov	si,offset slashc	; DOS command begins with slashc area
	mov	dx,offset slashc+1	; si points to /c part of command line
	call	strlen			; get its length into cx
	push	bx
	mov	bx,dx
	add	bx,cx
	mov	byte ptr [bx],cr	; end string with a c/r for dos
	mov	byte ptr [bx+1],0	; and terminate
	pop	bx
	mov	[si],cl			; put length of argument here
	mov	dx,offset cmspbuf	; always use command.com
crun4:	mov	exearg+2,si		; pointer to argument string
	mov	exearg+4,ds		; segment of same
	cmp	lclsusp,0		; sys dependent routine to call
	je	crun5			; e = none
	mov	bx,lclsusp		; address to call
	push	dx			; preserve name in dx
	call	bx			; call sys dependent suspend routine
	pop	dx
crun5:	push	dx			; preserve name in dx
	call	serrst			; reset serial port (if active)
	call	cbrestore		; restore state of Control-Break Chk
	pop	dx
	mov	es,psp			; point to psp again
	mov	exearg+8,es		; segment of psp, use our def fcb's
	mov	exearg+12,es		; segment of psp, ditto, for fcb 2
	mov	ax,es:word ptr [env]	; get environment ptr
	mov	exearg,ax		; put into argument block
	mov	ax,ds
	mov	es,ax			; put es segment back
	mov	bx,offset exearg	; es:bx points to exec parameter block
	mov	ax,ss			; save ss:sp
	mov	word ptr ssave+2,ax
	mov	word ptr ssave,sp
	xor	al,al			; 0 = load and execute (DX has name)
	mov	ah,exec
	int	dos			; go run command.com
	mov	bx,data			; restore segment registers
	mov	ds,bx			; reset data segment
	mov	es,bx			; and extra segment
	cli
	mov	bx,word ptr ssave+2
	mov	ss,bx			; and stack segment
	mov	sp,word ptr ssave	; restore stack ptr
	sti
	jnc	crun9			; nc = no error
	mov	ah,prstr		; failure, complain
	mov	dx,offset erms37
	int	dos
	mov	dx,offset cmspbuf	; path\name of command.com
	call	prtasz			; asciiz
	mov	kstatus,ksgen		; global status
crun9:	mov	ah,setdma		; restore dma buffer pointer
	mov	dx,offset buff
	int	dos			; restore dma address!!
	call	cboff			; turn off DOS BREAK check
	cmp	lclrest,0		; sys dependent routine to call?
	je	crun10			; e = none
	mov	bx,lclrest		; get routine's address
	call	bx			; call sys dependent restore routine
crun10:	clc
	ret
CRUN	ENDP
code	ends

code1	segment
	assume	cs:code1 

; Write path and filename of current Take file to buffer cmdfile. 
; Enter with current working filename offset in register dx.
save_cmdfile	proc far
	push	ax
	push	dx
	push	es
	mov	di,ds
	mov	es,di
	mov	di,offset cmdfile	; destination
	mov	si,dx			; source path
	mov	ax,[si]
	cmp	ah,':'			; drive specified?
	jne	save_c1			; ne = no
	and	al,not 20h		; upper case the drive letter
	add	si,2			; next byte to read
	jmp	short save_c2
save_c1:mov	al,curdsk		; current drive letter
	add	al,'A'-1		; number back to letter
	mov	ah,':'			; and letter
save_c2:cld
	stosw				; write to output
	xor	al,al
	mov	[di],al			; terminate
	cmp	byte ptr [si],'\'	; rooted path?
	je	save_c3			; e = yes
	mov	al,'\'			; get root indicator
	stosb				; write to output
	mov	dl,cmdfile		; get upper case drive letter
	sub	dl,'A'-1		; A = 1
	push	si
	mov	si,di			; gcd writes to si
	mov	ah,gcd			; get current directory (path really)
	int	dos
	mov	dx,si
	call	strlen
	add	di,cx
	pop	si
	jcxz	save_c3			; z = no directory, have \ already
	mov	al,'\'			; path separator
	stosb
	mov	byte ptr [di],0		; terminator
save_c3:call	strcpy			; copy rest of string
	pop	es
	pop	dx
	pop	ax
	ret
save_cmdfile	endp

; Replace Int 23h and Int 24h with our own handlers
; Revised to ask DOS for original interrupt vector contents, as suggested by
; Jack Bryans. 9 Jan 1986 jrd
; Modified again 30 August 1986 [jrd]
SETINT	PROC	FAR
	push	es			; save registers
	mov	al,23H			; desired interrupt vector (^C)
	mov	ah,getintv		; Int 21H, function 35H = Get Vector
	int	dos			; get vector in es:bx
	mov	in3ad,bx		; save offset of original vector
	mov	in3ad+2,es		;   and its segment
	mov	al,24h			; DOS critical error, Int 24h
	mov	ah,getintv
	int	dos
	mov	word ptr ceadr,bx	; DOS's Critical Error handler, offset
	mov	word ptr ceadr+2,es	;  and segment address
	push	ds			; save ds around next DOS calls
	mov	ax,seg intbrk		; compose full address of ^C routine
	mov	ds,ax			; segment is the code segment
	mov	dx,offset intbrk	;   and offset is intbrk
	mov	al,23H			; on ^C, goto intbrk
	mov	ah,setintv		; set interrupt address from ds:dx
	int	dos
	mov	dx,offset dosce		; replacement Critical Error handler
	mov	al,24h			; interrupt 24h
	mov	ah,setintv		; replace it
	int	dos
	pop	ds
	mov	ax,3300h		; get state of Control-Break Check
	int	dos
	mov	orgcbrk,dl		; save state here
	pop	es
	ret
SETINT	ENDP

; Control Break, Interrupt 23h replacement
; Always return with a Continue (vs Abort) condition since Kermit will cope
; with failures. [jrd]
intbrk:	push	ax
	push	ds	
	mov	ax,data			; get Kermit's data segment
	mov	ds,ax
	mov	flags.cxzflg,'C'	; say we saw a ^C
	mov	rstate,'E'
	mov	sstate,'E'
	pop	ds
	pop	ax
	iret			   ; return to caller in a Continue condition

; Kermit's DOS Critical Error Handler, Int 24h. [jrd]
; Needed to avoid aborting Kermit with the serial port interrupt active and
; the Control Break interrupt redirected. See the DOS Tech Ref Manual for
; a start on this material; it is neither complete nor entirely accurate
; The stack is the Kermit's stack, the data segment is unknown, interrupts
; are off, and the code segment is Kermit's. Note: some implementations of
; MS DOS may leave us in DOS's stack. Called by a DOS Int 21h function
dosce:	test	ah,80h		; block device (disk drive)?
	jnz	dosce1		; nz = no; serial device, memory, etc
	mov	al,3		; tell DOS to Fail the Int 21h call
	iret			; return to DOS
dosce1:	add	sp,6		; pop IP, CS, Flags regs, from DOS's Int 24h
	pop	ax		; restore original callers regs existing
	pop	bx		;  just before doing Int 21h call
	pop	cx
	pop	dx
	pop	si
	pop	di
	pop	bp
	pop	ds
	pop	es		
	mov	al,0ffh		; signal failure (usually) the DOS 1.x way
	push	bp		; Kermit's IP, CS, and Flags are on the stack
	mov	bp,sp		;  all ready for an iret, but first a word ..
	or	word ptr[bp+8],1 ; set carry bit, signals failure DOS 2+ way
	pop	bp		; this avoids seeing the Interrupt flag bit
	iret			; return to user, simulate return from Int 21h

; Set DOS' Control-Break Check to off
cboff	proc	far
	push	ax
	push	dx
	mov	ax,3301h		; set Control-Break Chk state
	xor	dl,dl			; set state to off
	int	dos
	pop	dx
	pop	ax
	ret
cboff	endp

; Restore DOS's Control-Break Check to startup value
cbrestore proc	far
	push	ax
	push	dx
	mov	ax,3301h		; set Control-Break Chk state
	mov	dl,orgcbrk		; restore state to startup value
	int	dos
	pop	dx
	pop	ax
	ret
cbrestore endp


; CDSR processes both CD & REM CD.  Entered with si --> drive/path, it returns
; dx --> ASCIIZ current drive/path, w/carry clear, if successful, or error msg
; w/carry set, if not.
CDSR	PROC	FAR
	mov	kstatus,kssuc		; global status
	xor	cx,cx			; 0 for default drive, if none
	cmp	byte ptr[si],ch		; any drive/path?
	je	cdsr4			; e = no, format current drive/path
	cmp	byte ptr[si+1],':'	; is drive specified?
	jne	cdsr1			; ne = no
	mov	cl,[si]			; drive letter
;	cmp	byte ptr[si+2],ch	; any path?
;	jne	cdsr1			; ne = yes
;	mov	word ptr[si+2],'.'	; append dot+null as path to kludge DOS
cdsr1:	call	dskspace		; test for drive, spec'd by cl, ready
	jnc	cdsr2			; nc = ready
	mov	spcmsg3,cl		; insert drive letter ret'd by dskspace
	mov	dx,offset spcmsg2+2	; in err msg.  dx --> msg w/o cr,lf
	mov	kstatus,ksgen		; global status
	ret				; carry is set

cdsr2:	push	cx			; save drive letter part
	mov	dx,si
cdsr2a:	call	strlen
	mov	bx,cx			; look at last char+1
	dec	bx			; last byte
	cmp	cx,1			; if any bytes
	jbe	cdsr2b			; be = enough for 1 char
	cmp	byte ptr [si+bx],'\'	; ends on backslash?
	jne	cdsr2b			; ne = no
	cmp	byte ptr [si+bx-1],':'	; ends as ":\"?
	je	cdsr2b			; e = yes, leave intact for roots
	mov	byte ptr [si+bx],0	; trim trailing backslash
	jmp	short cdsr2a		; keep trimming
cdsr2b:	pop	cx			; restore drive letter
	mov	dl,cl			; uc drive letter ret'd by dskspace
	sub	dl,'A'			; A = 0 for seldsk
	mov	ah,seldsk
	int	dos
	inc	dl			; A = 1 for curdsk
	mov	curdsk,dl
	mov	dx,si			; where chdir wants it
	cmp	byte ptr [si+1],':'	; drive specified?
	jne	cdsr3			; ne = no, just path
	add	dx,2			; skip "drive:"
	cmp	byte ptr [si+2],0	; any path?
	je	cdsr4			; e = no
cdsr3:	mov	ah,chdir
	int	dos
	jnc	cdsr4			; nc = success
	mov	dx,offset ermes4	; ret carry set, dx --> err msg
	ret

cdsr4:	push	si			; use caller's buffer for cur dr/path
	mov	ax,':@'			; al = 'A' - 1, ah = ':'
	add	al,curdsk		; al = drive letter
	mov	[si],ax			; stash drive:
	inc	si
	inc	si
	mov	byte ptr[si],'\'	; add \
	inc	si
	mov	ah,gcd			; gcd fills in path as ASCIIZ
	xor	dl,dl			; use current drive
	int	dos
	pop	dx			; return caller's buffer pointer in dx
	clc
	ret
CDSR	ENDP
; Compute disk free space (bytes) into long word dx:ax.
; Enter with disk LETTER in CL (use null if current disk).
; Returns uppercase drive letter in CL.
; Returns carry set if drive access error. Changes AX, DX.

DSKSPACE PROC	FAR
	mov	dl,cl			; desired disk letter, or null
	or	dl,dl			; use current disk?
	jnz	dskspa1			; nz = no
	mov	ah,gcurdsk		; get current disk
	int	dos
	add	al,'A'			; make 0 ==> A
	mov	dl,al
dskspa1:and	dl,5fh			; convert to upper case
	mov	cl,dl			; return upper case drive letter in CL
	sub	dl,'A'-1		; 'A' is 1, etc
	push	bx
	push	cx
	mov	ah,36h			; get disk free space, ax=sect/cluster
	int	dos			; bx=clusters free, cx=bytes/sector
	cmp	ax,0ffffh		; error response?
	jne	dskspa2			; ne = no
	pop	cx
	pop	bx
	stc				; return error
	ret
dskspa2:mul	bx			; sectors/cluster * clusters = sectors
	mov	bx,dx			; save high word of sectors (> 64K)
	mul	cx			; bytes = sectors * bytes/sector
	push	ax			; save low word of bytes
	mov	ax,bx			; recall sectors high word
	mov	bx,dx			; save current bytes high word
	mul	cx			; high word sectors * bytes/sector
	add	ax,bx			; new high bytes + old high bytes
	mov	dx,ax			; store high word in dx
	pop	ax			; space is in dx:ax as a long word
	pop	cx
	pop	bx
	clc
	ret
DSKSPACE ENDP

; Enter with ds:ax pointing at asciiz filename string
; Returns carry set if the file pointed to by ax does not exist, else reset
; Returns status byte, fstat, with DOS status and high bit set if major error
; Does a search-for-first to permit paths and wild cards
; Examines All kinds of files (ordinary, subdirs, vol labels, system,
;  and hidden). Upgraded to All kinds on 27 Dec 1985. Revised 30 Aug 86 [jrd]
; All registers are preserved
ISFILE	PROC	FAR
	push	bx
	push	ax
	mov	bx,ax
	mov	ax,[bx]
	or	al,al			; is string empty?
	jnz	isfil5			; nz = no
	pop	ax
	pop	bx
	stc				; return failure
	ret
isfil5:	and	ax,not 2020h		; to upper
	cmp	ax,'UN'			; look for DOS 5 NUL
	jne	isfil4			; ne = mismatch
	mov	ax,[bx+2]
	and	al,not 20h
	cmp	ax,'L'+0
	jne	isfil4			; ne = mismatch
	pop	ax
	pop	bx
	clc				; say success
	ret
isfil4:	pop	ax
	pop	bx
	push	dx			; save regs
	push	cx
	push	ax
	mov	byte ptr filtst.dta+21,0 ; clear old attribute bits
	mov	byte ptr filtst.fname,0	; clear any old filenames
	mov	filtst.fstat,0		; clear status byte
	mov 	cx,3fH			; look at all kinds of files
	mov	dx,offset filtst.dta	; own own temporary dta
	mov	ah,setdma		; set to new dta
	int	dos
	pop	dx			; get ax (filename string ptr)
	push	dx			; save it again
	mov	ah,first2		; search for first
	int	dos
	pushf				; save flags
	push	ax			; save result in ax
	mov	dx,offset buff		; reset dma
	mov	ah,setdma
	int	dos
	pop	ax
	popf				; recover flags
	jnc	isfil1			; nc = file found
	mov	filtst.fstat,al		; record DOS status
	cmp	al,2			; just "File Not Found"?
	je	isfil2			; e = yes
	cmp	al,3			; "Path not found"?
	je	isfil2			; e = yes
	cmp	al,18			; "No more files"?
	je	isfil2			; e = yes
	or	filtst.fstat,80h	; set high bit for more serious error
	jmp	short isfil2	
isfil1:	cmp	byte ptr filtst.fname,0	; did DOS fill in a name?
	je	isfil2			; z = no, fail
	clc
	jmp	short isfil3
isfil2:	stc				; else set carry flag bit
isfil3:	pop	ax
	pop	cx
	pop	dx
	ret				; DOS sets carry if file not found
ISFILE	ENDP


; Allocate memory.  Passed a memory size in ax, allocates that many
; bytes (actually rounds up to a paragraph) and returns its SEGMENT in ax
; The memory is NOT initialized.  Written by [jrd] to allow memory to
; be allocated anywhere in the 1MB address space
malloc	proc	far
	push	bx
	push	cx
	mov	bx,ax			; bytes wanted
	add	bx,15			; round up
	mov	cl,4
	shr	bx,cl			; convert to # of paragraphs
	mov	cx,bx			; remember quantity wanted
	mov	ah,alloc		; DOS memory allocator
	int	dos
	jc	mallocx			; c = fatal
	cmp	cx,bx			; paragraphs wanted vs delivered
	jae	mallocx			; ae = enough
	push	es
	mov	es,ax
	mov	ah,freemem		; free the memory
	int	dos
	pop	es
	stc				; fail
mallocx:pop	cx
	pop	bx
	ret				; and return segment in ax
malloc	endp
code1	ends

code	segment
	assume	cs:code

; initialize memory usage by returning to DOS anything past the end of kermit
memini	proc	near
	push	es
	mov	bx,_TEXT
	sub	bx,psp
	mov	totpar,bx		; save for patcher's magic number
	mov	es,psp			; address psp segment again
	mov	bx,offset msfinal + 15	; end of pgm + roundup
	mov	cl,4
	shr	bx,cl			; compute # of paragraphs in last seg
	mov	ax,_STACK		; last segment
	sub	ax,psp			; minus beginning
	add	bx,ax			; # of paragraphs occupied
	mov	ah,setblk
	int	dos
	pop	es
	jnc	memin1
	mov	dx,offset ermes2
	mov	ah,prstr
	int	dos			; complain
	jmp	krmend			; exit Kermit now
memin1:	pop	dx			; save return address here
	mov	ax,_STACK		; move SS down to DGROUP, adj SP
	sub	ax,DGROUP		; paragraphs to move
	mov	cl,4			; convert to bytes
	shl	ax,cl
	mov	bx,SP			; current SP offset
	add	bx,ax			; new SP, same memory cell
	mov	ax,bx
	sub	ax,400			; top 400 bytes = Kermit
	mov	tcptos,ax		; report this as TCP's top of stack
	mov	ax,DGROUP		; new SS
	cli
	mov	SS,ax
	mov	SP,bx			; whew!
	sti
	push	dx			; push return address
	clc
	ret
memini	endp

sbrk	proc	near			; K & R, please forgive us
	call	malloc			; allocate memory
	jc	sbrkx			; c = failed
	ret				; success
sbrkx:	mov	dx,offset mfmsg		; assume not enough memory (ax = 8)
	cmp	ax,7			; corrupted memory (ax = 7)?
	jne	sbrkx1			; ne = no
	mov	dx,offset mf7msg	; corrupted memory found
sbrkx1:	mov	ah,prstr
	int	dos
	jmp	krmend			; exit Kermit now
sbrk	endp
code 	ends
	end	start
