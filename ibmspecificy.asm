	NAME msyibm
; File MSYIBM.ASM
	include symboldefs.h
;	Copyright (C) 1982, 1999, Trustees of Columbia University in the 
;	City of New York.  The MS-DOS Kermit software may not be, in whole 
;	or in part, licensed or sold for profit as a software product itself,
;	nor may it be included in or distributed with commercial products
;	or otherwise distributed by commercial concerns to their clients 
;	or customers without written permission of the Office of Kermit 
;	Development and Distribution, Columbia University.  This copyright 
;	notice must not be removed, altered, or obscured.
; Edit history
; 12 Jan 1995 version 3.14
; Last edit
; 12 Jan 1995

	public	lclyini, csrtype, fcsrtype, scrseg
	public	atsclr, trnmod, vtbell, vtroll, crt_lins, crt_cols
	public	vtemu, crt_mode, scbattr, refresh, low_rgt	; data
	public	setchtab, extattr, vtcpage, tv_mode, dos_bottom
	public	setpos, setatch, yflags, vtinited, useexp
	public	vts, vtstat, termtb, modbuf, qsetatch	; terminal emulation
	public	tv_segs, tv_sego

ifndef	no_terminal
	public	term, enqbuf
	public	chgdsp, vtclear, ftogmod, getatch, nextses,  setprot, clrprot
	public	prtbout, prtnout, vtscru, vtscrd, vclick, reset_color
	public	getbold, setbold, clrbold, getblink, setblink, clrblink
	public	getunder, setunder, clrunder, revideo, revscn, setcolor
	public	setrev, clrrev, frepaint, touchup, reversed_screen
			; action verb procedures for keyboard translator
	public	uparrw, dnarrw, rtarr, lfarr, pf1, pf2, pf3, pf4
	public	kp0, kp1, kp2, kp3, kp4, kp5, kp6, kp7, kp8, kp9
	public	kpminus, kpcoma, kpenter, kpdot, chrout, cstatus, cquit
	public	cquery, dmpscn,	vtans52, vtinit, dnwpg, upwpg, endwnd, homwnd
	public	upone, dnone, trnprs, dumpscr, modlin, snull, ignore_key
	public	klogon, klogof, cdos, chang, khold, product, termesc_flag
	public	vtksmac, vtkrmac, apcmacro, apcenable, vtenqenable
	public	decf6,decf7,decf8,decf9,decf10,decf11,decf12,decf13,decf14
	public	dechelp,decdo,decf17,decf18,decf19,decf20, udkclear
	public	decfind, decinsert, decremove, decselect, decprev
	public	decnext, setudk, extmacro, vtmacname, vtmaclen
	public	rtone, lfone, rtpage, lfpage, kbdcompose, kdebug
	public	dgkc1,dgkc2,dgkc3,dgkc4,dgkf1,dgkf2,dgkf3,dgkf4,dgkf5
	public	dgkf6,dgkf7,dgkf8,dgkf9,dgkf10,dgkf11,dgkf12,dgkf13
	public	dgkf14,dgkf15, dgpoint, dgnckey
	public	dgkSf1,dgkSf2,dgkSf3,dgkSf4,dgkSf5,dgkSf6,dgkSf7,dgkSf8
	public	dgkSf9,dgkSf10,dgkSf11,dgkSf12,dgkSf13,dgkSf14,dgkSf15
	public	udkf6, udkf7, udkf8, udkf9, udkf10, udkf11, udkf12, udkf13
	public	udkf14, udkf15, udkf16, udkf17, udkf18, udkf19, udkf20
	public	wykf1,wykf2,wykf3,wykf4,wykf5,wykf6,wykf7,wykf8
	public	wykf9,wykf10,wykf11,wykf12,wykf13,wykf14,wykf15,wykf16
	public	wykSf1,wykSf2,wykSf3,wykSf4,wykSf5,wykSf6,wykSf7,wykSf8
	public	wykSf9,wykSf10,wykSf11,wykSf12,wykSf13,wykSf14,wykSf15,wykSf16
	public	dgsettek, vtclrflg, tn_AYT, tn_IP, jpnxltkey, rcvmacro
	public	srvmacro, crdisp_mode
ifndef	no_tcp
	public	termswapout, termswapin, termswapdel, commbyte
	public	ses1, ses2, ses3, ses4, ses5, ses6
endif	; no_tcp
endif	; no_terminal

; some definitions
SIchar	equ	0fh
SOchar	equ	0eh
DGescape equ	1eh
CSI	equ	9bh
SS2	equ	8eh
SS3	equ	8fh
bapito_3270 equ 0b3h			; KERMIT BAPI extension, byte to 3270

; hardware
crt_status equ	3dah			; CGA crt status port
disp_enb equ	8			; CGA display enable bit
crtmset	equ	3D8H			; CGA CRT mode set port
screen	equ	10h			; Bios screen interrupt

att_protect	equ	01h		; protected	in vsatt
att_uline	equ	02h		; underscored	in vsatt
att_rev		equ	04h		; reversed video  in vsatt
att_bold	equ	08h		; bold		in main video word
att_blink	equ	80h		; blinking	in main video word

att_low_mask	equ	06H		; Various attribute-related equates
;;;att_normal	equ	07h
att_underline	equ	01H		; for mono monitors, in video word
ifndef	nls_portuguese

modfrm	struc				; format of mode (status) line
	db	'Esc:Alt-x help:Alt-h port:'
m_prt	db	20 dup (' ')
m_baud	db	6 dup (' ')
m_par	db	3 dup (' ')
	db	' echo:'
m_echo	db	3 dup (' ')
m_term	db	12 dup (' ')		; 12 bytes for term type
m_prn	db	3 dup (' ')		; show PRN when printer is on
m_comp	db	' '			; Compose indicator
	db	'$'			; terminator
modfrm	ends

else

modfrm	struc				; format of mode (status) line
	db	'Esc:Alt-X help:Alt-H porta:'
;	db	'Carac-Esc:   ajuda:   ? porta:'
;	db	'Carac-Esc:'		; do not write in last column
m_prt	db	19 dup (' ')
m_baud	db	6 dup (' ')
m_par	db	3 dup (' ')
	db	'  eco:'
m_echo	db	3 dup (' ')
m_term	db	12 dup (' ')		; 12 bytes for term type
m_prn	db	3 dup (' ')		; show PRN when printer is on
m_comp	db	' '			; Compose indicator
	db	'$'			; terminator
modfrm	ends
endif	; nls_portuguese

; structure for status information table sttab.
stent	struc
sttyp	dw	?		; type (actually routine to call)
msg	dw	?		; message to print
val2	dw	?		; needed value: another message, or tbl addr
tstcel	dw	?		; address of cell to test, in data segment
basval	dw	0		; base value, if non-zero
stent	ends


data	segment
	extrn	flags:byte, decbuf:byte, rdbuf:byte, xms:dword
	extrn	filtst:byte, dmpname:byte, kbdflg:byte, rxtable:byte
	extrn	trans:byte, comand:byte, kstatus:word, prnhand:word
	extrn	comptab:byte, dosnum:word, fossil_port:word, termserver:byte
ifndef	no_terminal
	extrn	anspflg:byte, scroll:byte, ttyact:byte
	extrn	mar_top:byte, mar_bot:byte, npages:word
	extrn	holdscr:byte, portval:word
	extrn	taklev:byte, takadr:word, mcctab:byte, dupflg:byte
	extrn	apctrap:byte, denyflg:word
	extrn	kbcodes:byte, repflg:byte
	extrn	param:word, nparam:word
	extrn	upss:byte, GRptr:word, G1set:byte, G2set:byte
	extrn	G3set:byte, cursor:word, linescroll:byte
	extrn	savezlen:word, savezoff:word
	extrn	savexoff:word, savexlen:word, savepoff:word
	extrn	saveplen:word, rollwidth:word, dgkbl:byte, apcstring:word
	extrn	blinkdis:byte, protectena:byte, dghscrdis:byte
	extrn	dgwindcomp:byte, att_normal:byte
	extrn	emsrbhandle:word, curattr:byte, saveuoff:word, saveulen:word
	extrn	dgd470mode:byte, tekflg:byte, xmsrhandle:word
	extrn	xmsghandle:word, xmsep:dword
	extrn	parmsk:byte, flowon:byte, flowoff:byte, flowcnt:byte
	extrn	isps55:byte		; [HF]940130 in MSXIBM.ASM
	extrn	ps55mod:byte		; [HF]940206 in MSXIBM.ASM
	extrn domath_ptr:word, domath_cnt:word, domath_msg:word
ifndef	no_graphics
	extrn	chcontrol:byte, softlist:word
	extrn	tekgraf:byte, tekcursor:byte, dgcross:byte, cursorst:byte
	extrn	savegoff:word, saveglen:word

endif	; no_graphics
ifndef	no_network
ifndef	no_tcp
	extrn	tcpnewline:byte
	extrn	seslist:byte, sescur:word, tcphost:byte, tcpmode:byte
	extrn	sestime:byte
endif	; no_tcp
endif	; no_network
endif	; no_terminal

inited	equ	08h			; been here before
prtscr	equ	1			; print screen pressed

; stuff for screen routines
;;;;;;;;;;;;;; start session save area
	even
saveyoff label	word
yflags	db	0			; status flags
vtemu	emulst	<>			; emulator flags
vtsave	db	7 dup (0)		; inuse/color/charset save around ANSI
belltype db	0			; 0 = aural bell, 1 = visual
scbattr db	?			; screen background attribute
savattr	db	?			; current emulator attributes
extattr	db	0			; extended scbattr
colunder db	0ffh			; underline color (0ffh = uninited)
vtclrflg db	0			; erase with scbattr(0) or curattr(1)
vtclkflg db	1			; status line clock (0=off)
reversed_screen db 0			; if whole screen has been reversed
crt_mode db	3			; video mode (typ 3, must be text)
					; keep crt_cols & crt_lins in order
crt_cols db	80			; number of screen columns (typ 80)
crt_lins db	24			; number of screen rows - 1 (typ 24)
dos_bottom db	24			; num of rows-1 at DOS level (typ 24)
low_rgt	dw	174fh			; lower right corner of text window
					; high = row address (typ 23)
					; low = column address (typ 79)
handhsc	db	0			; hand horizontal scroll
dosetcursor dw	-1			; place to set tekcursor, -1 = don't
vtinited db	0			; flag for emulator having been inited
vtclear	db	0			; nonzero to redo emulator screen
reset_color db	0			; reset color on CSI m
writemode db	0			; screen writing mode
vchgmode db	2			; video-change mode (0=enabled)
vtcpage	dw	437			; terminal code page
apcenable db	0			; enable APC macro (default is off)
vtenqenable db	0			; enable Answerback
saveflag	flginfo <>		; copy of flags array
ytermtype dw	0
ymodetype db	0
keypend dw	0			;[HF]940207 buffer for double byte code
keyj7st	dw	0			;[HF]940211 keyoutput status for JIS7
enqbuf	db	40 dup (0),0		; local enquiry string, asciiz
crdisp_mode db	0			; CR display mode
saveylen dw	($ - saveyoff)
;;;;;;;;;;;;;;;;; end of session save area


modbuf	modfrm	<>			; mode line buffer
argadr	dw	0			; address of arg blk
skip	dw	0
inemulator db	0			; non-zero if term emlator active
inwindows db	0			; non-zero if Windows is active
crlf	db	cr,lf,'$'
	even


ifndef	no_terminal

vid7id	db	'VEGA BIOS Code, '	; Video 7 Vega version string subset
vid7len	equ	$-vid7id		; length of string
vid7id2	db	'Video Seven BIOS Code, ' ; Video 7 VGA board
vid7len2 equ	$-vid7id2
atiwid	db	'ATI EGA Wonder Bios,'	; ATI EGA wonder version string subset
atilen	equ	$-atiwid		; length of string, inc terminator
atiwid2	db	'761295520'		; ATI signature #2
atilen2	equ	$-atiwid2
tsngid	db	'Tseng'			; Tseng Labs EVA (& Orchid Designer)
tsnglen	equ	$-tsngid
stbvid	db	'TVGA'			; STB VGA/EM (also Tseng TVGA)
stbvlen	equ	$-stbvid
stavid	db	'4000'			; STB VGA/EM Plus (Tesng 4000)
stavlen equ	$-stavid
evrxid  db      'Everex'                ; Everex Micro Enhancer Deluxe EGA
evrxlen equ     $-evrxid
evgid	db	'VGA EV673'		; Everex EVGA EV-673
evglen	equ	$-evgid
evvid	db	'EV-678'		; Everex Viewpoint EV-678
evvlen	equ	$-evvid
attvdc6	db	'003116'		; AT&T video board, at c000:35h
attvdlen equ	$-attvdc6
attvdc7	db	'C02000'		; AT&T video board, at e000:10h
pmega1	db	'28190-A1001'		; Paradise AutoSwitch EGA Mono String1
pmegal1 equ	$-pmega1		
p30id	db	'VGA'			; VGA Plus, Plus 16, Professional
p30ln	equ	$-p30id			;  and VGA1024 by Paradise
emsrollname db	'KERMIT  ',0		; 8 byte EMS region name, + safety
pageready dw	-1			; ems page currently active
cols80	db	'COLS80.BAT',0		; to 80 column mode batch file
cols132	db	'COLS132.BAT',0		; to 132 column mode batch file
xga_reg_base dw	-1			; PS/2 MCA I/O register base
emsname	db	'EMMXXXX0',0		; expanded memory manager dev name
jis7des	db	'B','B'		; [HF] 941016 JIS7 designators (Kanji/ASCII)
cpwarn	db	cr,lf
	db	'?Warning: Code Page CP866 is required but it is not active.$'
endif	; no_terminal

ega_mode db	0			; non-zero if IBM EGA is in use
tvhere	equ	0feh			; Topview active query
tvsynch	equ	0ffh			; Topview resynch request
tv_segs	dw	0			; Topview virtual screen, segment
tv_sego	dw	0			; and offset
tv_mode	db	0			; flag, 0 = no Topview or DESQview
vtcpumode db	0			; timeslice-release (0 = enabled)
vs_ptr	dd	0			; offset, segment of vscreen (dynamic)
vsat_ptr dd	0			; offset, segment of vs's attributes
; Note: (vswidth+1)/2 bytes of attributes/line, at two attributes/byte
vswidth	equ	207			; columns across DG virtual screen

; The following are used to turn the display back on (after scrolling etc.)
msets	db	2CH,28H,2DH,29H,2AH,2EH,1EH,29H
wysecurtab db	0bh,0ah,0ch,08h		; VT to Wyse-50 cursor converter
dgcurtab db	23,26,24,25		; ANSI to DG cursor converter
dgcrostab db	72,80,77,75		; DG cursor to PC scan for croshair

mtty	db	'  TTY   '		; no terminal type (mode line)
fairness dw	0
fairprn	dw	0
lincur	dw	?			; cursor type save area
dosattr	db	?			; screen attributes at init time
userbold db	0			; screen bold attribute at start up
dos_cols db	0			; screen width (crt_cols) at DOS

ifndef	no_terminal

oldsp	dw	0			; offset to longjmp to for i/o failure
ten	db	10			; byte constant for key defines
temp	dw	0			; scratch storage
temp2	dw	0			; scratch storage
endif	; no_terminal

ifndef	no_terminal

dmphand	dw	-1			; screen dump file handle
dumpsep	db	0ch,cr,lf		; screen image separators
dmperr	db	' Cannot open file to save screen to disk $'
memerr	db	cr,lf,'Not enough memory for terminal emulator$'
pntmsg	db	'Printer not ready, printing request skipped$'
; some static data for mode line
modmaster modfrm <>			; master template
unkbaud	db	'unkwn '		; must be 6 chars
baudn	db	' 45.5 ',' 50   ',' 75   ',' 110  ','134.5 ',' 150  ',' 300  '
	db	' 600  ',' 1200 ',' 1800 ',' 2000 ',' 2400 ',' 4800 ',' 9600 '
	db	'14400 ', '19200 ','28800 ', '38400 ','57.6K ','115 K '
	db	'75/12 '
baudnsiz  equ	21			; # of baud rates known (tbl size / 6)
repmsg	db	'REPLAY'		; REPLAY message for speed field
repmsgl	equ	$-repmsg
parnams	db	'7e1','7m1','8n1','7o1','7s1'
lclmsg	db	'loc'
remmsg	db	'rem'
portno	db	0
termesc_flag db 0			; SET TERM ESCAPE flag
endif	; no_terminal

; storage for multi-window stuff
slen	equ	24			; and length of text
crt_norm db	3			; video mode for normal screen
					
inipara	dw	0			; initial paragraphs of scroll memory
					;  also is number ems pages for same
refresh	db	0			; screen refresh (0=wait for retrace)
vtroll	db	0			; auto roll back allowed (0 = no)
useexp	db	0			; non-zero to use exp mem for rollback
vsbuff_inited db 0			; non-zero if inited screen buffers
setnoshow db	0			; quiet setatch flag
lastsec	db	-1			; seconds of last gettim call

ifndef	no_terminal
vtkrname db	'KEYBOARDR'		; a macro name, must be Upper Case
vtkrlen	equ	$-vtkrname
vtksname db	'KEYBOARDS'		; a macro name, must be Upper Case
vtkslen	equ	$-vtksname
prodname db	'PRODUCT'
vtplen	equ	$-prodname
vtsesname db	'SESSION'
vtsesnum db	'1'
vtseslen equ	$-vtsesname

vtmacname dw	vtkrname		; pointer to selected macro name
vtmaclen dw	vtkrlen
udkseg	dw	18 dup (0)		; segment of user definable key defs
	even				; screen rollback material
iniseg	dw	?			; (BDT) initial seg of scroll memory
ppl	dw	0			; (BDT) paragraphs per line
lcnt	dw	0			; (BDT) number of "filled" buffer lines
linef	dw	0			; (BDT) "first" filled line is here
linec	dw	0			; (BDT) "current" screen line number
linee	dw	0			; (BDT) total # of lines in the buffer
lmax	dw	0			; (BDT) max lines in buff (less 1 scrn)
lineems	dw	0			; lines per EMS 16KB page frame
xgatmp1	dw	0			; XGA display adapter work word pair
xgatmp2	dw	0

tsave	dw	6 dup (0)		; list of term swap paragraphs

					; DG SPCL three stroke Compose key
grab	dw	0			; zero if not grabbing output
grabbox	db	0,0			; store incoming pair of bytes
endif	; no_terminal

setchtab db	10			; Set File Character-Set table
	mkeyw	'CP437',437		; hardware default Code Page
	mkeyw	'CP850',850		; Multilingual CP
	mkeyw	'CP852',852		; Latin2 CP
	mkeyw	'CP860',860		; Portuguese CP
	mkeyw	'CP861',861		; Icelandic CP
	mkeyw	'CP862',862		; Hebrew CP
	mkeyw	'CP863',863		; French Canadian CP
	mkeyw	'CP865',865		; Norwegian CP
	mkeyw	'CP866',866		; Latin5/Cryillic CP
	mkeyw	'Shift-JIS',932		; Japanese Shift-JIS

ifdef	no_terminal
					; begin Terminal emulator data set
termtb	db	1			; entries for Status, not Set
	mkeyw	'none',ttgenrc

vttbl	db	0			; number of entries

endif	; no_terminal
ifndef	no_terminal
					; begin Terminal emulator data set
ifndef	no_graphics
termtb	db	tttypes			; entries for Status, not Set
else
termtb	db	tttypes - 1
endif
	mkeyw	'VT320',ttvt320
	mkeyw	'VT220',ttvt220
	mkeyw	'VT102',ttvt102
	mkeyw	'VT100',ttvt100
	mkeyw	'VT52',ttvt52
	mkeyw	'Honeywell VIP7809',tthoney
	mkeyw	'Heath-19',ttheath
ifndef	no_graphics
	mkeyw	'Tek4010',tttek
endif
	mkeyw	'PT200',ttpt200
	mkeyw	'D217',ttd217
	mkeyw	'D463',ttd463
	mkeyw	'D470',ttd470
	mkeyw	'Wyse50',ttwyse
	mkeyw	'Ansi-BBS',ttansi
	mkeyw	'none',ttgenrc

ifndef	no_graphics
vttbl	db	55			; number of entries
else
vttbl	db	55 - 2
endif	; no_graphics
	mkeyw	'Answerback',vtenqctl
	mkeyw	'APC-macro',apcctl
	mkeyw	'Arrow-keys',flg11
	mkeyw	'Autodownload',vtdownld
	mkeyw	'Character-set',vtchar
	mkeyw	'Clock',vtclock
	mkeyw	'Code-Page',vtcodepage
	mkeyw	'Compressed-text',flg14
	mkeyw	'Controls',flg9
	mkeyw	'CR-display',vtcrdisp
	mkeyw	'Cursor-style',flg7
	mkeyw	'Direction',flg4
	mkeyw	'Escape-character',termesc
	mkeyw	'Expanded-memory',expmemory
	mkeyw	'Horizontal-scroll',flg13
	mkeyw	'Keyclick',flg5
	mkeyw	'Keypad',flg10
	mkeyw	'Margin-bell',flg6
	mkeyw	'Newline',flg1
	mkeyw	'Reset',termreset
	mkeyw	'Screen-background',flg8
	mkeyw	'Video-writing',scrwrite
	mkeyw	'Video-change',scrchange
	mkeyw	'Tabstops',tabmod
	mkeyw	'Timeslice-release',vtcpu
	mkeyw	'Width',flg12
	mkeyw	'Wrap-lines',flg2

	mkeyw	'Bell',vtbeep
	mkeyw	'Bytesize',vtbyte
	mkeyw	'Clear-screen',vtcls
	mkeyw	'Color',vtcolor
	mkeyw	'Display',vtbyte	; syn for set display 7/8
	mkeyw	'Erase',vterase
ifndef	no_graphics
	mkeyw	'Graphics',vtgraph
	mkeyw	'Tek4010',vttyp40
endif	; no_graphics
	mkeyw	'Replay',replay
	mkeyw	'Rollback',vtrollbk
	mkeyw	'output-shift',vtshift
	mkeyw	'Underscore',vtucolor
	mkeyw	'UPSS',vtupss
	mkeyw	'Type',vttype		; SET TERM TYPE
	mkeyw	'None',vttyp0
	mkeyw	'Heath-19',vttyp1
	mkeyw	'VT52',vttyp2
	mkeyw	'VT100',vttyp4
	mkeyw	'VT102',vttyp8
	mkeyw	'VT220',vttyp10
	mkeyw	'VT320',vttyp20
	mkeyw	'Honeywell',vttyp80
	mkeyw	'PT200',vttyp100
	mkeyw	'D217',vttyp1000
	mkeyw	'D463',vttyp200
	mkeyw	'D470',vttyp400
	mkeyw	'Wyse50',vttyp800
	mkeyw	'ANSI',vttyp2000

ontab	db	2			; two entries
	mkeyw	'off',0
	mkeyw	'on',1

beltab	db	3			; bell type
	mkeyw	'audible',0
	mkeyw	'visual',1
	mkeyw	'none',2

clktab	db	3
	mkeyw	'Off',0
	mkeyw	'On',1
	mkeyw	'Elapsed-time',2

distab	db	2			; display
	mkeyw	'7-bit',0
	mkeyw	'8-bit',d8bit

erasetb	db	2			; erase
	mkeyw	'normal-background',0
	mkeyw	'current-color',1

scrtab	db	2			; screen attributes
	mkeyw	'normal',0
	mkeyw	'reverse',1

dirtab	db	2			; writing direction
	mkeyw	'left-to-right',0
	mkeyw	'right-to-left',1

writetab db	2			; writing
	mkeyw	'direct',0
	mkeyw	'Bios',1

curtab	db	2			; cursor attributes
	mkeyw	'block',0
	mkeyw	'underline',1

apctab	db	3			; three entries
	mkeyw	'off',0
	mkeyw	'on',1
	mkeyw	'unchecked',2
     
chatab	db	32			; National Replacement Character sets
	mkeyw	'ASCII',C_ASCII		; ASCII is default (0, no NRC)
	mkeyw	'British',C_UKNRC	; start NRC set (1-12)
	mkeyw	'Dutch',C_DUNRC
	mkeyw	'Finnish',C_FINRC
	mkeyw	'French',C_FRNRC
	mkeyw	'Fr-Canadian',C_FCNRC
	mkeyw	'German',C_DENRC
	mkeyw	'Hebrew-7',C_DHEBNRC
	mkeyw	'Italian',C_ITNRC
	mkeyw	'Norwegian/Danish',C_NONRC
	mkeyw	'Portuguese',C_PONRC
	mkeyw	'Spanish',C_SPNRC
	mkeyw	'Swedish',C_SENRC
	mkeyw	'Swiss',C_CHNRC		; end of NRC proper

	mkeyw	'Alternate-ROM',C_ALTROM ; Alternate-ROM character set
	mkeyw	'Transparent',C_XPARENT	; use native display adapter hardware
	mkeyw	'Latin1',C_LATIN1	; Latin-1 in GR
	mkeyw	'Latin2',C_LATIN2	; Latin-2 (will presume CP852)
	mkeyw	'Hebrew-ISO',C_HEBREWISO ; Hebrew-ISO (presumes CP862)
	mkeyw	'HP-Roman8',C_HPROMAN8	; HP-Roman8
	mkeyw	'DEC-MCS',C_DMULTINAT	; DEC Supplemental Graphics in GR
	mkeyw	'DEC-Technical',C_DECTECH
	mkeyw	'DEC-Special',C_DECSPEC
	mkeyw	'DG-International',C_DGINT
	mkeyw	'DG-Line-Drawing',C_DGLINE
	mkeyw	'DG-Word-Processing',C_DGWP
	mkeyw	'JIS-Kanji',C_JISKANJI	; [HF] JIS X 208, ISO(ECMA)#87
	mkeyw	'JIS-Katakana',C_JISKAT	; [HF] JIS X 201, ISO(ECMA)#13
	mkeyw	'JIS-Roman',C_JISROM	; [HF] JIS X 201, ISO(ECMA)#14
	mkeyw	'Cyrillic-ISO',C_CYRILLIC_ISO
	mkeyw	'KOI8',C_KOI8
	mkeyw	'Short-KOI',C_SHORT_KOI

upsstab	db	4
	mkeyw	'DEC-MCS','5%'			; DEC Supplemental Graphics
	mkeyw	'Latin1','A'			; Latin-1
	mkeyw	'Hebrew-7','4"'			; DEC Hebrew-7
	mkeyw	'Hebrew-ISO','H'		; Hebrew-ISO

sidetab	db	4			; SET TERM CHAR <char set> Gn
	mkeyw	'G0','0'
	mkeyw	'G1','1'
	mkeyw	'G2','2'
	mkeyw	'G3','3'

shifttab db	8			; SET TERM OUTPUT-SHIFT
	mkeyw	'none',0
	mkeyw	'automatic',8
	mkeyw	'SI/SO',1
	mkeyw	'SS2',2
	mkeyw	'SS3',4
	mkeyw	'JIS7-Kanji',(128+1)		; [HF]940211
	mkeyw	'EUC-Kanji',(128+2)		; [HF]940211
	mkeyw	'DEC-Kanji',(128+3)		; [HF]941012

jis7tab	db	6			;[HF]941014
	mkeyw	'JIS83-US','BB'		;[HF]941014
	mkeyw	'JIS83-Roman','JB'	;[HF]941014
	mkeyw	'JIS83-75Roman','HB'	;[HF]941014
	mkeyw	'JIS78-US','B@'		;[HF]941014
	mkeyw	'JIS78-Roman','J@'	;[HF]941014
	mkeyw	'JIS78-75Roman','H@'	;[HF]941014

enqtab	db	5			; set term enquire table
	mkeyw	'off',0
	mkeyw	'on',1
	mkeyw	'message',2
	mkeyw	'UNSAFE-MESSAGE',3
	mkeyw	'UNSAFE-MESSAGE ',4	; invisible to force spelled out

graftab	db	13
	mkeyw	'auto-sensing',0	; autosensing
	mkeyw	'CGA',1
	mkeyw	'EGA',2
	mkeyw	'VGA',3
	mkeyw	'VESA(800x600)',9
	mkeyw	'Hercules',4
	mkeyw	'ATT',5
	mkeyw	'WyseA(1280x800)',6	; Wyse-700 1280 x 800 mode
	mkeyw	'WyseH(1280x780)',7	; Wyse-700 1280 x 780 mode
	mkeyw	'WyseT(1024x780)',8	; Wyse-700 1024 x 780 mode
	mkeyw	'character-writing',101h
	mkeyw	'color',103h
	mkeyw	'cursor',102h

gchrtab	db	2			; set term graphics char-writing
	mkeyw	'opaque',1
	mkeyw	'transparent',0

disatab	db	2			; Tek disable/enable table
	mkeyw	'disabled',1		; video-change table
	mkeyw	'enabled',0

tabtab	db	2			; label says it all!
	mkeyw	'at',0FFH		; For setting tab stops
	mkeyw	'Clear',0		; For clearing tab stops
     
alltab	db	2			; more tab command decoding
	mkeyw	'all',0
	mkeyw	'at',1

cntltab	db	2			; 8-bit controls
	mkeyw	'7-bit',0
	mkeyw	'8-bit',1

kpamtab	db	2			; keypad, application
	mkeyw	'numeric',0
	mkeyw	'application',1

arrtab	db	2			; cursor keys, application
	mkeyw	'cursor',0
	mkeyw	'application',1

widtab	db	2
	mkeyw	'80-columns',0
	mkeyw	'132-columns',1

vchgtab db	3			; video-change
	mkeyw	'enabled',0
	mkeyw	'disabled',1
	mkeyw	'DOS-only',2

hstab	db	2			; horizontal scrolling
	mkeyw	'auto',0
	mkeyw	'manual',1

cmptab	db	2
	mkeyw	'graphics',0
	mkeyw	'text-132',1

emmtab	db	4
	mkeyw	'off',0
	mkeyw	'expanded',1
	mkeyw	'extended',2
	mkeyw	'on',3

termesctab db	2			; SET TERM ESCAPE
	mkeyw	'Enabled',0
	mkeyw	'Disabled',1

crdisptab db	2
	mkeyw	'normal',0
	mkeyw	'CRLF',1

colortb	db	0,4,2,6,1,5,3,7		; color reversed-bit setting bytes
clrset	db	0			; Temp for SET Term Tabstops xxx

erms41	db	cr,lf,'?More parameters are needed$'
tbserr	db	cr,lf,'?Column number is not in range 1 to screen width-1$'
colerr	db	cr,lf,'?Value not in range of 0, 1, 10, 30-37, or 40-47$'
vtwrap	db	'Term wrap-lines: $'
vtbellm	db	'Term margin-bell: $'
vtnewln db	'Term newline: $'
vtcur	db	'Term cursor-style: $'
vtcset	db	'Term character-set: $'
vtclik	db	'Term key-click: $'
vtscrn	db	'Term screen-background: $'
txtcolst1	db	'Term color (normal) f:3$'
colst2	db	' b:4$'
colst3	db	' rst:$'
undcolst1	db	'Term underscore color f:3$'
grcolst1	db	'Term graphics color   f:3$'
vtgraf	db	'Term graphics: $'
vtrolst	db	'Term rollback: $'
vtdir	db	'Term direction: $'
vtcntst	db	'Term controls: $'
vtkpst	db	'Term keypad: $'
vtarst	db	'Term arrow-keys: $'
vtbset	db	'Term bell: $'
vtgchst	db	'Term graph char: $'
vtwdst	db	'Term width: $'
vtupsst	db	'Term UPSS: $'
vtshftst db	'Term output-shift: $'
vthscst	db	'Term horizontal-scroll: $'
vtapcst	db	'Term APC-macro: $'
vtenqst db	'Term Answerback: $'
vtenqst2 db	'ab msg: '
vtenqst2_len equ $-vtenqst2
vtwrtst	db	'Term video-writing: $'
vtexpmst db	'Term expanded-memory: $'	
vtcpagest db	'Term Code-Page: $'
vtcmptst db	'Term compressed-text: $'
vtchgst	db	'Term video-change: $'
vtcpust	db	'Term timeslice-release: $'
vtclrst	db	'Term erase: $'
vtdnldst db	'Term autodownload: $'
vtcrdispst db	'Term CR-display: $'
							; terminal emulator
vtstbl	stent	<srchkw,vtenqst,ontab,vtenqenable>		; Answerback
	stent	<ansbkstat>
	stent	<srchkw,vtcset,chatab,vtemu.vtchset>		; char set
	stent	<srchkw,vtapcst,apctab,apcenable>		; APC-macro
	stent	<txtcolstat>					; colors
	stent	<srchkb,vtclik,ontab,vskeyclick,vtemu.vtflgop>	; keyclick
	stent	<undcolstat>					; colors
	stent	<srchkb,vtwrap,ontab,vswrap,vtemu.vtflgop>	; line wrap
ifndef	no_graphics
	stent	<grcolstat>					; colors
endif	; no_graphics
	stent	<srchkb,vtcntst,cntltab,vscntl,vtemu.vtflgop>	; controls
	stent	<srchkw,vtclrst,erasetb,vtclrflg>		; erase
	stent	<srchkb,vtbellm,ontab,vsmarginbell,vtemu.vtflgop>;margin bell
	stent	<srchkb,vtcur,curtab,vscursor,vtemu.vtflgop>	; cursor type
	stent	<srchkw,vtbset,beltab,belltype>			; bell
	stent	<srchkb,vtdir,dirtab,vswdir,vtemu.vtflgop>	; write direct
	stent	<srchkb,vtnewln,ontab,vsnewline,vtemu.vtflgop>	; newline
ifndef	no_graphics
	stent	<srchkw,vtgraf,graftab,tekgraf>			; graphics
endif	; no_graphics
	stent	<srchkw,vtrolst,ontab,vtroll>			; rollback
ifndef	no_graphics
	stent	<srchkw,vtgchst,gchrtab,chcontrol>		; chr cntrl
endif	; no_graphics
	stent	<srchkb,vtarst,arrtab,decckm,vtemu.vtflgop>	; arrow-keys
	stent	<srchkb,vtscrn,scrtab,vsscreen,vtemu.vtflgop>	; screen 
	stent	<srchkb,vtkpst,kpamtab,deckpam,vtemu.vtflgop>	; keypad
	stent	<srchkb,vtwdst,widtab,deccol,vtemu.vtflgop>	; width
	stent	<srchkww,vtupsst,upsstab,upss+1>		; UPSS
	stent	<srchkw,vtshftst,shifttab,flags.oshift>		; output-shift
	stent	<srchkb,vthscst,hstab,vshscroll,vtemu.vtflgop>	; Horz scroll
	stent	<srchkw,vtchgst,vchgtab,vchgmode>		; V change
	stent	<srchkw,vtexpmst,emmtab,useexp>			; exp mem
	stent	<srchkw,vtwrtst,writetab,writemode>		; Writing
	stent	<srchkww,vtcpagest,setchtab,vtcpage>		; Code-Page
	stent	<srchkb,vtcmptst,cmptab,vscompress,vtemu.vtflgop> ; compress
	stent	<srchkw,vtcpust,disatab,vtcpumode>		; timeslice
	stent	<srchkw,vtcrdispst,crdisptab,crdisp_mode>	; CR-display
	stent	<srchkw,vtdnldst,ontab,vtemu.vtdnld>		; autodownload
	stent	<tabstat>	; VT320 tab status - needs one whole line
	dw	0		; end of table

vtmacroptr	dd	vtmacro			; FAR pointer
ftogmod		dd	togmod			; FAR pointer
termlatch	db	0		; reentry block for session macros
rcvstring	db	9,0,'RECEIVE',CR,'C'
rcvstring_len	equ	$-rcvstring-2
srvstring	db	5,0,'SER',CR,'C'
srvstring_len	equ	$-srvstring-2
endif	; no_terminal
data	ends

ifndef	no_terminal
data1	segment
vthlp	db	' one of the following:',cr,lf
	db	'  TYPE of: None, ANSI, Heath-19, Honeywell VIP7809, Wyse50,'
	db	' VT52, VT100, VT102'
	db	cr,lf
	db	'   VT220, VT320 (default), Tek4010,'
	db 	' PT200 (Prime), D217, D463, D470 (Data Gen)'
	db	cr,lf
	db	'  Newline-mode    Cursor-style        Character-set'
	db 	cr,lf
	db	'  Keyclick        Margin-bell         Screen-background'
	db	' (normal, reverse)',cr,lf
	db '  Tabstops        Wrap (long lines)   Color (fore & background)'
	db	cr,lf,'  Answerback response (on or off, default is off)'
	db	cr,lf,'  APC-macro  (APC cmd from host invokes local cmds)' 
	db	cr,lf,'  Autodownload (on, off=default) kermit file xfers'
	db	cr,lf,'  Arrow-keys  cursor (normal) or application mode'
	db	cr,lf,'  Bell  audible or visual or none'
	db	cr,lf,'  Clear-screen  (clears old startup screen)'
	db	cr,lf,'  Clock (status line HH:MM) on or off, default is off'
	db	cr,lf,'  Code-Page (overrides default)'
	db	cr,lf,'  Compressed-text  Graphics or Text-132 (for D463/D470)'
	db	cr,lf,'  Controls 7-bit or 8-bit  (permits VT320 to send'
	db	' 8-bit control sequences (C1))'
	db	cr,lf,'  CR-display  normal or CR-LF'
	db	cr,lf,'  Direction Left-to-right or Right-to-left'
	db	' (screen writing direction)'
	db	cr,lf,'  Display or Bytesize 7-bit or 8-bit'
	db	cr,lf,'  Erase in normal bkground or in current char color'
	db	cr,lf,'  Expanded/extended-memory (rollback), default on'
	db	cr,lf,'  Graphics  (type of display adapter when in Tek4010'
	db	' mode, and char writing)'
	db	cr,lf,'  Horizontal scrolling, auto (default) or manual'
	db	cr,lf,'  Keypad numeric (normal) or application mode'
	db	cr,lf,'  Output-shift (prefix 8-bit data for 7-bit channel)'
	db	cr,lf,'  Reset, resets terminal emulation to startup defaults'
	db	cr,lf,'  Rollback  (undo screen roll back before writing new'
	db	' chars, default=off)'
	db	cr,lf,'  TEK ENABLE or DISABLE (activation by host command)'
	db	cr,lf,'  Timeslice-release (OS/2, DV, Windows, def: enabled)'
	db	cr,lf,'  Underscore Color (same syntax as SET TERM COLOR)'
	db	cr,lf,'  Width 80 or 132 columns, if the adapter can do it'
	db	cr,lf,'  Video-change, enable or disable 132 column switching'
	db	' or restrict to DOS-only'
	db	cr,lf,'  Video-writing, Direct or via Bios$'
clrhlp	db	' one of the following:'
	db	cr,lf,'  AT #s  (to set tabs at column #s)    or'
	db	' AT start-column:spacing'
	db	cr,lf,'  Clear AT #s (clears individual tabs) or'
	db	' AT start-column:spacing'
	db	cr,lf,'  Clear ALL  (to clear all tabstops)'
clrhlp2	db	cr,lf,'  Ex: Set term tab at 10, 20, 34        sets tabs'
	db	cr,lf,'  Ex: Set term tab at 1:8        sets tabs at 1, 9,'
	db	cr,lf,'  Ex: Set term tab clear at 9, 17, 65   clears tabs'
	db	cr,lf,'  Ex: Set term tab clear at 1:8  clears tabs at 1, 9,'
	db	' 17,...$'
colhlp	db	cr,lf,'  Set Term Color  value, value, value, ...'
	db	cr,lf,'   0 no-snow mode on an IBM CGA and white on black'
	db	cr,lf,'   1 for high intensity foreground'
	db	cr,lf,'  10 for fast CGA screen updating (may cause snow)'
	db	cr,lf,'  20 to restore normal colors after ESC [ 0 m'
	db	cr,lf,'  Foreground color (30-37) = 30 + sum of colors'
	db	cr,lf,'  Background color (40-47) = 40 + sum of colors'
	db	cr,lf,'    where colors are  1 = red, 2 = green, 4 = blue'
	db	cr,lf,'  Ex: 0, 1, 37, 44   IBM CGA(0), bright(1) white(37)'
	db	' chars on a blue(44) field'
	db	cr,lf,'  Attributes are applied in order of appearance.$'
upsshlp	db	' User Preferred Supplemental Set:'
	db	cr,lf, 'DEC-MCS, Latin-1, Hebrew-7, Hebrew-ISO$'
apchlp	db	cr,lf,'ON to allow APC cmd from host to invoke commands'
	db	cr,lf,'OFF to prevent all use of APC from the host'
	db	' (default)'
	db	cr,lf,'UNCHECKED to allow any command to be executed$'
dnldhlp db	cr,lf,'ON to act upon incoming Kermit file transfer packets'
	db	cr,lf,'OFF to prevent that action. Default is off$'
enqhlp	db	cr,lf,' ON to permit Answerback to Control-E Enquire request'
	db	' (default is OFF),'
	db	cr,lf,' MESSAGE text  to append local message to safe'
	db	' response prefix'
	db	cr,lf,' UNSAFE-MESSAGE text  to send message as-is, without'
	db	' prefix$'
enqhlp2	db	' string to send$'
expmhlp	db	cr,lf,' Use expanded or extended memory for screen rollback'
	db	' buffer,'
	db	cr,lf,' OFF, EXPANDED, EXTENDED, or ON (try expanded first)$'

; structures below: byte cnt of combos, dw input combo list, db output list
; using DG International or Latin1 codes for output.
grl1dgi db	48			; case and order insensitive
	dw	'++','AA','((','//','/<','^ ','(-','/^',')-','<<'
	dw	'0^','* ','+-','>>','SS','/U','2^','3^','C/','C|'
	dw	'L-','L=','Y-','Y=','SO','S!','S0','XO','X0','A-'
	dw	'CO','C0','PP','P!','.^','O-','12','!!','??','T-'
	dw	'TM','FF','<=','>=',',-','""',2727h,'RO'
grc1dgi db	'#', '@', '[', '\', '\', '^', '{', '|', '}', 0b1h
	db	0bch,0bch,0b6h,0b0h,0fch,0a3h,0a4h,0a5h,0a7h,0a7h
	db	0a8h,0a8h,0b5h,0b5h,0bbh,0bbh,0bbh,0a6h,0a6h,0a9h
	db	0adh,0adh,0b2h,0b2h,0b9h,0aah,0a2h,0abh,0ach,0afh
	db	0b3h,0b4h,0b7h,0b8h,0a1h,0bdh,0beh, 0aeh

grl1lat db	44			; case and order insensitive
	dw	'<<','0^','* ','+-','>>','SS','/U','2^','3^','C/'
	dw	'C|','L-','L=','Y-','Y=','SO','S!','S0','XO','X0'
	dw	'A-','CO','C0','PP','P!','.^','O-','12','!!','??'
	dw	'TM',',-','""',2727h,'RO','||','--','-^',',,','34'
	dw	'XX','-:','1^','14'
grc1lat db	0abh,0b0h,0b0h,0b1h,0bbh,0dfh,0b5h,0b2h,0b3h,0a2h
	db	0a2h,0a3h,0a3h,0a5h,0a5h,0a7h,0a7h,0a7h,0a4h,0a4h
	db	0aah,0a9h,0a9h,0b6h,0b6h,0b7h,0bah,0bdh,0a1h,0bfh
	db	0aeh,0ach,0a8h,0b4h, 0aeh,0a6h,0adh,0afh,0b8h,0beh
	db	0d7h,0f7h,0b9h,0bch

grl2dgi	db	25			; case sensitive, order insensitive
	dw	'''A','`A','^A','"A','~A','*A','''E','`E','^E','"E'
	dw	'''I','`I','^I','"I','~N','''O','`O','^O','"O','~O'
	dw	'''U','`U','^U','"U','"Y'
grc2dgi	db	0c0h, 0c1h,0c2h,0c3h,0c4h,0c5h,0c8h, 0c9h,0cah,0cbh
	db	0cch, 0cdh,0ceh,0cfh,0d0h, 0d1h,0d2h,0d4h,0d6h,0d5h
	db	0dah, 0d9h,0dbh,0dch,0ddh

grl2lat	db	25			; case sensitive, order insensitive
	dw	'''A','`A','^A','"A','~A','*A','''E','`E','^E','"E'
	dw	'''I','`I','^I','"I','~N','''O','`O','^O','"O','~O'
	dw	'''U','`U','^U','"U','''Y'
grc2lat	db	0c1h, 0c0h,0c2h,0c4h,0c3h,0c5h,0c9h, 0c8h,0cah,0cbh
	db	0cdh, 0cch,0ceh,0cfh,0d1h, 0d3h,0d2h,0d4h,0d6h,0d5h
	db	0dah, 0d9h,0dbh,0dch,0ddh

grl3dgi db	7			; case and order sensitive
	dw	'EO','AE',',C','/O','ae',',c','/o'
grc3dgi db	0d7h,0c6h,0c7h,0d6h,0e6h,0e7h,0f6h

grl3lat db	10+2			; case and order sensitive
; The last two, OE/oe dipthong, are for DEC MCS but added here for user help
	dw	'AE',',C','/O','HT','-D','ae',',c','/o','ht','-d'
	dw	'OE','oe'
grc3lat db	0c6h,0c7h,0d8h,0deh,0d0h,0e6h,0e7h,0f8h,0feh,0f0h
	db	0d7h,0f7h

			; CP852 Latin 2 codes in gr<l/c><1/2/3>lat2
grl1lat2 db	24			; case and order insensitive
	db	'%%','::','--','==',"''",'&&',',,','##','xx','..'
	db	'++','AA','aa','((','//','/<','))','(-','/^',')-'
	db	'^^','``','~~','""'
grc1lat2 db	0a2h,0a8h,0adh,0b2h,0b4h,0b7h,0b8h,0bdh,0d7h,0ffh
	db	'#','@','@','[','\','\',']','{','|','}'
	db	'^','`','~','"'

grl2lat2 db	83			; case sensitive, order insensitive
	db	'A=','L/','L&',"S'",'S&','S,','T&',"Z'",'Z&','Z.'
	db	'a=','l/','l&',"s'",'s&','s,','t&',"z'",'z&','z.'
	db   	"R'","A'",'A^','A%','A"',"L'","C'",'C,','C&',"E'"
	db	'E=','E"','E&',"I'",'I^','D&','D-',"N'",'N&',"O'"
	db	'O^','O#','O"','R&','U*',"U'",'U#','U"',"Y'",'T,'
	db	'ss',"r'","a'",'a^','a%','a"',"I'","c'",'c,','c&'
	db	"e'",'e=','e"','e&',"i'",'i^','d&','d-',"n'",'n&'
	db	"o'",'o^','o#','o"','r&','u*',"u'",'u#','u"',"y'"
	db	't,',".'",',.'
grc2lat2 db	0a1h,0a3h,0a5h,0a6h,0a9h,0aah,0abh,0ach,0aeh,0afh
	db	0b1h,0b3h,0b5h,0b6h,0b9h,0bah,0bbh,0bbh,0beh,0bfh
	db	0c0h,0c1h,0c2h,0c3h,0c4h,0c5h,0c6h,0c7h,0c8h,0c9h
	db	0cah,0cah,0cch,0d8h,0d9h,0dah,0dbh,0dch,0ddh,0deh
	db	0d4h,0d5h,0d6h,0fch,0deh,0e9h,0ebh,09ah,0edh,0ddh
	db	0dfh,0e0h,0e1h,0e2h,0e3h,0e4h,0e5h,0e6h,0e7h,0e8h
	db	0e9h,09ah,0ebh,0ech,0edh,0eeh,0efh,0f0h,0f1h,0f2h
	db	0f3h,0f4h,0f5h,0f6h,0f8h,0f9h,0fah,0fbh,0fch,0fdh
	db	0feh,"'", ','

grl3lat2 db	12			; case and order sensitive
	db	'XO','X0','xo','x0','SO','S!','S0','so','s!','s0'
	db	'0^','-:'
grc3lat2 db	0a4h,0a4h,0a4h,0a4h,0a7h,0a7h,0a7h,0a7h,0a7h,0a7h
	db	0b0h,0f7h


;[HF] 941012 Double-byte katakana code table
kanatbl	dw	2121h, 2123h, 2156h, 2157h, 2122h, 2126h, 2572h, 2521h	;[HF]
	dw	2523h, 2525h, 2527h, 2529h, 2563h, 2565h, 2567h, 2543h	;[HF]
	dw	213ch, 2522h, 2524h, 2526h, 2528h, 252ah, 252bh, 252dh	;[HF]
	dw	252fh, 2531h, 2533h, 2535h, 2537h, 2539h, 253bh, 253dh	;[HF]
	dw	253fh, 2541h, 2544h, 2546h, 2548h, 254ah, 254bh, 254ch	;[HF]
	dw	254dh, 254eh, 254fh, 2552h, 2555h, 2558h, 255bh, 255eh	;[HF]
	dw	255fh, 2560h, 2561h, 2562h, 2564h, 2566h, 2568h, 2569h	;[HF]
	dw	256ah, 256bh, 256ch, 256dh, 256fh, 2573h, 212bh, 212ch	;[HF]

data1	ends
						; end of Terminal data set
code1	segment
	extrn	ans52t:far, vsinit:near		; in mszibm
	extrn	anstty:near, ansini:near, ansrei:near	; in mszibm
	extrn	anskbi:near, ansdsl:near, chrdef:near	; in mszibm
	extrn	tabset:near, tabclr:near, dgnctoggle:far
	extrn	toupr:far, domath:far, cboff:far, cbrestore:far

	assume	cs:code1
fanskbi	proc	far
	call	anskbi				; in mszibm
	ret
fanskbi	endp
ftabset	proc	far
	call	tabset				; in mszibm
	ret
ftabset	endp
ftabclr	proc	far
	call	tabclr				; in mszibm
	ret
ftabclr	endp
fchrdef	proc	far
	call	chrdef
	ret
fchrdef	endp
code1	ends
endif	; no_terminal

ifndef	no_graphics
code2	segment
	extrn   tekini:far, tekemu:far, tekend:far, tekrint:far ;in msgibm
	extrn	ttxtchr:far, teksetcursor:far, tekremcursor:far
	extrn	croshair:far, dgcrossrpt:far
code2	ends
endif	; no_graphics

ifndef	no_tcp
_TEXT	segment
	extrn	ktcpcom:far
_TEXT	ends

_DATA	segment
commbyte db	0			; byte from msyibm to 3270 emulator
_DATA	ends
endif	; no_tcp

code1	segment
	extrn	strlen:far, strcpy:far, strcat:far, isfile:far
	extrn	dec2di:far
	assume	cs:code1
code1	ends

code	segment
	extrn	prtchr:near, outchr:near, pcwait:far
	extrn	clrmod:near, putmod:near, cmblnk:near, cptchr:near
	extrn	telnet:near, srchkww:near, jpnftox:near
	extrn	srchkb:near, srchkw:near, pasz:near
	extrn	prompt:near, comnd:near, statc:near, replay:near
	extrn	crun:near, serini:near, spath:near
	extrn	prttab:near, ctlu:near
	extrn	pntchr:near, pntflsh:near, serrst:near
ifndef	no_graphics
	extrn	tekgcptr:near, tekdmp:near
endif	; no_graphics
ifndef	no_network
	extrn	ubclose:near
endif	; no_network
ifndef	no_tcp
	extrn	tcpstart:near, winupdate:far
endif	; no_tcp
ifndef	no_terminal
	extrn	takopen_macro:far
	extrn	msuinit:near, keybd:near, kbhold:near	; in msuibm
endif	; no_terminal

	assume	cs:code, ds:data, es:nothing

ifdef	no_terminal
; do initialization local to this module
; Dynamically allocates 4000 bytes for screen save/restore buffer plus
;  320 to 38400 bytes for screen scroll back buffers. Tries to leave space
;  for Command.com before enlarging buffers.
lclyini	proc	near
	call	far ptr flclyini	; far call specifics
	ret
lclyini	endp
					; begin Terminal set & status code
; SET Term parameters, especially for use with VT100 emulator.
; VTS is called only by mssset to set terminal type and characteristics.
; Exit carry set for failure.
VTS	proc	near			; SET TERM whatever
	mov	ah,cmeol		; Clear-screen
	call	comnd
	ret
VTS	endp				; end of Set Term things

	      ; Terminal Status display, called within STAT0: in MSSSET
VTSTAT	proc	near			; enter with di within sttbuf, save bx
	jmp	statc			; status common code, in mssset
vtstat	endp

trnmod	proc	near
	ret
trnmod	endp
   					; Screen dump entry from keyboad xlat
dmpscn	proc	near			; dump screen to file
	stc
	ret
dmpscn	endp

endif	; no_terminal

ifndef	no_terminal

; do initialization local to this module
; Dynamically allocates 4000 bytes for screen save/restore buffer plus
;  320 to 38400 bytes for screen scroll back buffers. Tries to leave space
;  for Command.com before enlarging buffers.
lclyini	proc	near
	call	msuinit			; initialize keyboard module msuxxx
	call	far ptr flclyini	; far call specifics
	ret
lclyini	endp

					; begin Terminal set & status code
; SET Term parameters, especially for use with VT100 emulator.
; VTS is called only by mssset to set terminal type and characteristics.
; Exit carry set for failure.
VTS	proc	near			; SET TERM whatever
	mov	kstatus,kssuc		; success
	mov	ah,cmkey		; Parse another keyword
	mov	bx,offset vthlp		; Use this help
	mov	dx,offset vttbl		; Use this table
	call	comnd
	jnc	vset1			; nc = success
	ret				; failure
vset1:	call	bx			; dispatch to processing routine
	ret

vtcls:	mov	ah,cmeol		; Clear-screen
	call	comnd
	jc	vtclsx			; c = failure
	mov	vtclear,2		; set trigger for emulator clear scn
	clc				; success
vtclsx:	ret

vtclock:mov	ah,cmkey		; SET TERM CLOCK {ON | OFF | ELAPSED}
	xor	bx,bx
	mov	dx,offset clktab
	call	comnd
	jnc	vtclo1
	ret
vtclo1:	mov	vtclkflg,bl		; status line clock flag
	ret

vterase:mov	ah,cmkey		; SET TERM ERASE
	xor	bx,bx			; table is help
	mov	dx,offset erasetb	; use this table
	call	comnd
	jc	vterasex		; c = failure
	mov	vtclrflg,bl
vterasex:ret
					; SET TERM kind
vttyp0:	mov	bx,ttgenrc		; NONE
	jmp	vsett1
vttyp1:	mov	bx,ttheath		; Heath-19
	jmp	vsett1
vttyp2:	mov	bx,ttvt52		; VT52
	jmp	vsett1
vttyp4:	mov	bx,ttvt100		; VT100
	jmp	vsett1
vttyp8:	mov	bx,ttvt102		; VT102
	jmp	vsett1
vttyp10:mov	bx,ttvt220		; VT220
	jmp	vsett1
vttyp20:mov	bx,ttvt320		; VT320
	jmp	vsett1
vttyp40:mov	bx,tttek		; Tek
	jmp	vsett1
vttyp80:mov	bx,tthoney		; Honeywell VIP7809
	jmp	vsett1
vttyp100:mov	bx,ttpt200		; Prime PT200
	jmp	short vsett1
vttyp200:mov	bx,ttd463		; Data General D463
	jmp	short vsett1
vttyp400:mov	bx,ttd470		; Data General D470
	jmp	short vsett1
vttyp800:mov	bx,ttwyse		; Wyse-50
	jmp	short vsett1
vttyp1000:mov	bx,ttd217		; Data General D217
	jmp	short vsett1
vttyp2000:mov	bx,ttansi		; Ansi-BBS
	call	ansi_save		; save settings
	jmp	short vsett1
	
vttype:	mov	ah,cmkey		; SET TERM TYPE
	xor	bx,bx			; table is help
	mov	dx,offset termtb	; use this table
	call	comnd
	jnc	vsett1			; nc = success
	ret				; failure

vsett1:	mov	temp,bx			; save terminal type
	mov	vtemu.vtchop,-1		; say reinit char tables
	mov	temp2,-1		; assume no enable/disable Tek
	cmp	bx,ttansi		; going to be ANSI?
	je	vsett1a			; e = yes
	cmp	vtsave,0		; VT save area in use?
	je	vsett1a			; e = no
	mov	ax,word ptr vtsave+1	; get saved video and char set
	mov	vtemu.vtchset,al	; restore current char set
	mov	si,vtemu.att_ptr	; pointer to attributes
	mov	[si],ah			; restore current screen coloring
	mov	ax,word ptr vtsave+3
	mov	reset_color,al		; this too
	mov	savattr,ah
	mov	ax,word ptr vtsave+5
	mov	vtcpage,ax		; restore terminal Code Page
	mov	vtclear,1		; signal color change
	mov	vtsave,0		; save area is free
vsett1a:cmp	bx,tttek		; set term tek?
	jne	vsett2			; ne = no
	mov	dx,offset disatab	; disable/enable keyword table
	xor	bx,bx			; help is the table
	mov	comand.cmcr,1		; allow bare CR's
        mov	ah,cmkey		; get enable/disable keyword
	call	comnd
	mov	comand.cmcr,0		; no more bare CR's
	jc	vsett2			; c = no such keyword
ifndef	no_graphics
	mov	temp2,bx		; save enable/disable keyword value
	mov	bx,flags.vtflg		; get current terminal type
	mov	temp,bx			; and force it here
endif	; no_graphics

vsett2:	mov	ah,cmeol
	call	comnd			; get a confirm
	jc	vsettx			; c = failure
vsett3:	mov	bx,temp
	mov	flags.vtflg,bx		; Set the terminal emulation type
	call	ansi_save		; save if going to ANSI
	mov	tekflg,0		; clear graphics mode
	or	vtemu.vtflgst,vscompress+vshscroll ; set compress to text-132
	or	vtemu.vtflgop,vscompress+vshscroll
					; and horz scroll to manual
	cmp	bx,tttek		; adjusting Tek?
	je	vsett4			; e = yes
	test	bx,ttd463+ttd470+ttd217	; DG D463/470/217?
	jz	vsett6			; z = no
	and	vtemu.vtflgst,not (vshscroll) ; comp = graphics,
	and	vtemu.vtflgop,not (vshscroll) ; horz scroll = auto
vsett6:	cmp	temp2,-1		; just enable/disable tek?
	je	vsett5			; e = no
vsett4:
ifndef	no_graphics
	and	denyflg,not tekxflg	; enable Tek
	cmp	temp2,1			; ought we disable?
	jne	vsett5			; ne = no
endif	; no_graphics
	or	denyflg,tekxflg		; disable Tek
vsett5:	call	fchrdef			; make tables in mszibm.asm
	clc				; success
vsettx:	ret

; save coloring and character set around ANSI terminal type, worker
ansi_save proc	near
	cmp	flags.vtflg,ttansi	; are we ANSI now?
	jne	ansi_savex		; ne = no
	cmp	vtsave,0		; save area in use?
	jne	ansi_savex		; ne = yes
	mov	vtsave,1		; state that save area is in use
	mov	al,vtemu.vtchset	; get current char set
	mov	si,vtemu.att_ptr	; pointer to attributes
	mov	ah,[si]			; get current screen coloring
	mov	word ptr vtsave+1,ax	; save them
	mov	al,reset_color		; this too
	mov	ah,savattr
	mov	word ptr vtsave+3,ax
	mov	ax,437			; forced codepage is 437
	xchg	ax,vtcpage		; get old CP
	mov	word ptr vtsave+5,ax	; save old CP
	mov	reset_color,1		; reset colors with CSI m
	mov	byte ptr [si],07h	; dim white on black
	mov	savattr,07h
	mov	vtclear,1		; signal color change
	mov	vtemu.vtchset,15	; Transparent char set
	or	flags.remflg,d8bit	; set 8-bit display
ansi_savex:
	ret
ansi_save endp

vtchar: mov	ah,cmkey		; Set Term character set
	xor	bx,bx			; character set table for help 
	mov	temp,bx			; counter of trailing items
	mov	dx,offset chatab	; character set table
	call	comnd
	jc	vtcharx			; c = failure
	call	chkcp866		; check on CP866 requirements
	mov	decbuf,bl		; save here
	mov	ax,word ptr vtemu.vttable ; table of 4 overrides now
	mov	word ptr decbuf+1,ax	; copy them to temporary table
	mov	ax,word ptr vtemu.vttable+2
	mov	word ptr decbuf+3,ax
vtchar1:mov	comand.cmcr,1		; allow bare CR's
	mov	ah,cmkey
	xor	bx,bx
	mov	dx,offset sidetab	; read Gnumber item, if any
	call	comnd
	mov	comand.cmcr,0		; no bare CR's
	jc	vtchar2			; c = no match, get confirm
	inc	temp			; say have a trailing table number
	and	bx,3			; remove ASCII value encoding
	add	bx,offset decbuf+1	; address of slot to store info
	mov	al,decbuf		; set ident
	mov	[bx],al			; store table ident in G0..G3 slot
	jmp	short vtchar1		; repeat

; vtemu.vtchset:	changed to new set if no table trailers, else intact
; vtemu.vttable	db 4 dup(0ffh)	 char set numbers for G0..G3 as overrides,
;				use 0ffh to mean no override for table Gn
vtchar2:mov	ah,cmeol		; get EOL confirmation
	call	comnd
	jc	vtcharx			; c = failure, quit
	mov	vtemu.vtchop,-1		; say reinit char tables
	cmp	temp,0			; trailers (skip regular setup)?
	jne	vtchar3			; ne = yes
	mov	al,decbuf		; get character set
	mov	vtemu.vtchset,al	; set default character set
	clc
	ret
					; just overrides
vtchar3:mov	ax,word ptr decbuf+1	; first pair of char set idents
	mov	word ptr vtemu.vttable,ax
	mov	ax,word ptr decbuf+3	; second pair
	mov	word ptr vtemu.vttable+2,ax
	clc
vtcharx:ret

vtshift:mov	ah,cmkey		; Set Term Output-shift auto, none
	xor	bx,bx
	mov	dx,offset shifttab
	call	comnd
	jc	vtshifx			;[HF] c = failed
	cmp	bl,(128+1)		;[HF] JIS7-Kanji ?
	jne	vtshif3			;[HF] ne = no
	mov	temp2,bx		; save shift from above
	mov	temp,'BB'		;[HF] set default
	mov	comand.cmcr,1		;[HF] allow bare CR
	mov	ah,cmkey		;[HF] get Roman/ASCII set
	xor	bx,bx			;[HF]
	mov	dx,offset jis7tab	;[HF]
	call	comnd			;[HF]
	jc	vtshif2			;[HF] get confirm
	mov	temp,bx			;[HF] set value
vtshif2:mov	ah,cmeol		;[HF] get confirm
	call	comnd			;[HF]
	jc	vtshifx			;[HF]
	mov	bx,temp			;[HF] restore value
	mov	word ptr jis7des,bx	;[HF] set it
	mov	bx,temp2		; initial shift
	mov	flags.oshift,bl		; shift
	clc				;[HF]
	ret
vtshif3:push	bx
	mov	ah,cmeol
	call	comnd
	pop	bx
	jc	vtshifx
	mov	flags.oshift,bl		; shift
	clc
vtshifx:ret

vtrollbk:mov	ah,cmkey		; Set Term Roll On/Off, auto roll back
	xor	bx,bx			; Use on/off table as help
	mov	dx,offset ontab		; Use on/off table
	call	comnd
	jc	vtrollx			; c = failure
	push	bx
	mov	ah,cmeol		; get a confirm
	call	comnd
	pop	bx
	jc	vtrollx			; c = failure
	mov	vtroll,bl		; set roll state (0=no auto rollback)
	clc
vtrollx:ret

				     ; Set Term Color foreground, background
vtcolor:mov	bx,vtemu.att_ptr	; get address of attributes byte
	mov	bl,[bx]			; get attributes
	mov	decbuf,bl		; save in work temp
	mov	al,vtclear		; screen clear state
	mov	ah,refresh		; refresh state
	mov	word ptr decbuf+1,ax	; save here
	mov	al,reset_color		; reset color state
	mov	decbuf+3,al
	call	vsetcol			; get and analyze colors
	jc	vtcolo1			; c = failure
	mov	al,decbuf		; get current attributes
	mov	bx,vtemu.att_ptr	; get address of attributes byte
	mov	[bx],al			; store attributes
	mov	savattr,al		; saved emulator attributes

	and	al,att_bold		; pick up userbold preference
	mov	userbold,al

	mov	ax,word ptr decbuf+1
	mov	vtclear,al		; update these items
	mov	refresh,ah
	mov	al,decbuf+3
	mov	reset_color,al		; reset color state
	clc
vtcolo1:ret
					; setup color information
vsetcol:mov	ah,cmword		; get number(s) after set term color
	mov	dx,offset colhlp	; use this help
	mov	bx,offset rdbuf		; temp buffer
	mov	comand.cmcr,1		; allow bare c/r's
	mov	comand.cmcomma,1	; commas are equivalent to spaces
	call	comnd
	jc	vsetco2			; c = failure
	or	ax,ax			; text given?
	jz	vsetco1			; z = no
	mov	si,offset rdbuf		; si = string
	call	vsetco3			; analyze
	jmp	short vsetcol		; get more data
vsetco1:mov	ah,cmeol		; get end of line confirm
	call	comnd
vsetco2:ret				; c set if failure

vsetco3:mov	dx,si
	call	strlen			; get string count
	mov	domath_ptr,si
	mov	domath_cnt,cx
	call	domath
	mov	si,domath_ptr		; where to read next string byte
	cmp	domath_cnt,0
	jne	vsetco1			; ne = did not convert whole string
	or	ax,ax			; reset all? regular IBM CGA refresh
	jnz	vsetco4			; nz = no
	mov	word ptr decbuf+2,0	; slow screen refresh, no reset color
	mov	decbuf,07h		; clear all, set white on black
	mov	decbuf+1,2		; set trigger for emulator clear scrn
	jmp	short vsetcol

vsetco4:cmp	ax,1			; high intensity?
	jne	vsetco5			; e = no
	or	decbuf,08h		; set high intensity
	mov	decbuf+1,1		; set trigger for emulator keep screen
	jmp	short vsetcol

vsetco5:cmp	ax,10			; fast refresh?
	jne	vsetco5a		; ne = no
	mov	decbuf+2,1		; Fast screen refresh
	jmp	short vsetcol

vsetco5a:cmp	ax,20			; reset color upon CSI m?
	jne	vsetco6			; ne = no
	mov	decbuf+3,1		; reset color state is yes
	jmp	vsetcol

vsetco6:cmp	ax,30			; check range
	jb	vsetco8			; b = too small, complain
	cmp	ax,37
	ja	vsetco7			; 30-37 is foreground color
	sub	al,30			; remove foreground bias
	and	decbuf,not 07H		; clear foreground bits
	mov	bx,ax
	mov	al,colortb[bx]		; get reversed bit pattern
	or	decbuf,al		; load new bits
	mov	decbuf+1,2		; set trigger for emulator clear scn
	jmp	vsetcol

vsetco7:cmp	ax,40
	jb	vsetco8			; b = bad value
	cmp	ax,47			; compare as unsigned
	ja	vsetco8			; 40-47 is background
	sub	al,40			; remove background bias
	and	decbuf,not 70H		; clear background bits
	mov	bx,ax
	mov	al,colortb[bx]		; get reversed bit pattern
	mov	cl,4			; rotate 4 positions
	rol	al,cl
	or	decbuf,al		; load new bits
	mov	decbuf+1,2		; set trigger for emulator clear scn
	jmp	vsetcol

vsetco8:mov	ah,prstr		; not in range - complain and exit
	mov	dx,offset colerr
	int	dos
	mov	kstatus,ksgen		; general failure
	stc				; error
	ret
	     
vtucolor:mov	al,vtclear		; screen clear state
	mov	ah,refresh		; refresh state
	mov	word ptr decbuf+1,ax	; save here
	mov	al,scbattr
	mov	decbuf,al
	call	vsetcol			; get and analyze colors
	jc	vtucol1			; c = failure
	mov	al,decbuf		; get current attributes
	mov	colunder,al		; saved underlined color
	mov	ax,word ptr decbuf+1
	mov	vtclear,al		; update these items
	mov	refresh,ah
	clc
vtucol1:ret

ifndef	no_graphics
vtgraph:mov	ah,cmkey		; Set Term graphics
	xor	bx,bx			; Use graphics table as help
	mov	dx,offset graftab	; Use graphics table
	call	comnd
	jc	vtgrapx			; c = failure
	cmp	bx,100h			; in the special options area?
	ja	vtgrap1			; a = yes
	push	bx
	mov	ah,cmeol		; get a confirm
	call	comnd
	pop	bx
	jc	vtgrapx			; c = failure
	mov	tekgraf,bl		; set Tek graphics board type
	clc
vtgrapx:ret
vtgrap1:cmp	bx,101h			; character writing?
	jne	vtgrap2			; ne = no
	mov	ah,cmkey		; Set Term graphics char-writing
	xor	bx,bx			; no help
	mov	dx,offset gchrtab	; opaque/transparent table
	call	comnd
	jc	vtgrapx			; c = failure
	push	bx
	mov	ah,cmeol		; get a confirm
	call	comnd
	pop	bx
	jc	vtgrapx
	mov	chcontrol,bl		; set/reset opaque char control
	clc
	ret
vtgrap2:cmp	bx,102h			; cursor on/off?
	jne	vtgrap4			; ne = no
	mov	ah,cmkey		; Set Term graphics cursor on/off
	xor	bx,bx			; no help
	mov	dx,offset ontab		; on/off table
	call	comnd
	jc	vtgrapx			; c = failure
	push	bx
	mov	ah,cmeol		; get a confirm
	call	comnd
	pop	bx
	jc	vtgrapx
	mov	tekcursor,bl		; set Tek text cursor on/off
	clc
	ret

vtgrap4:cmp	bx,103h			; Color?
	jne	vtgrap6			; ne = no
	call	tekgcptr		; get pointer to active Tek color pal
	mov	al,[bx]			; get background attributes
	and	al,7			; discard intensity bit
	mov	cl,4
	shl	al,cl
	mov	ah,[bx+7]		; get foreground attributes
	or	al,ah
	mov	decbuf,al		; setup work temp for vsetcol
	push	bx			; save index
	call	vsetcol			; get and analyze colors
	pop	bx
	jnc	vtgrap5			; nc = ok
	ret
vtgrap5:mov	al,decbuf		; get current attributes
	mov	ah,al			; get background bits
	mov	cl,4
	shr	ah,cl			; just background here
	and	al,0fh			; just foreground here
	mov	[bx],ah			; store colpal[0] as background
	mov	[bx+7],al		; store colpal[7] as foreground
	clc				; success
vtgrap6:ret
endif	; no_graphics
	
vtbeep:	mov	ah,cmkey		; SET TERM BELL
	xor	bx,bx			; use table as help
	mov	dx,offset beltab	; use Bell table
	call	comnd
	jc	vtbeepx			; c = failure
	push	bx
	mov	ah,cmeol		; get a confirm
	call	comnd
	pop	bx
	jc	vtbeepx			; c = failure
	mov	belltype,bl		; set bell type
vtbeepx:ret				; return carry clear or set

					; SET TERM BYTESIZE {7-bit | 8-bit}
vtbyte:	mov	ah,cmkey		; SET TERM DISPLAY {7-bit | 8-bit}
	mov	dx,offset distab	; table
	xor	bx,bx			; help is table
	call	comnd
	jc	vtbytex			; c = failure
	push	bx
	mov	ah,cmeol		; get a confirm
	call	comnd
	pop	bx
	jc	vtbytex			; c = failure
	and	flags.remflg,not d8bit	; clear display 8-bit bit
	or	flags.remflg,bl		; set or clear the bit
vtbytex:ret

vtupss:	mov	ah,cmkey		; SET TERM UPSS
	mov	bx,offset upsshlp	; help
	mov	dx,offset upsstab	; UPSS table
	call	comnd			; get UPSS char set
	jc	vtupssx			; failure
	push	bx
	mov	ah,cmeol
	call	comnd
	pop	bx
	jc	vtupssx			; c = fail
	mov	al,96			; assume 96 byte set
	or	bh,bh			; one byte set identifier?
	jz	vtupss1			; z = yes
	mov	al,94			; a 94 byte set
vtupss1:mov	upss,al			; set length
	mov	word ptr upss+1,bx	; store set ident
	mov	vtemu.vtchop,-1		; clear operational char set to reinit
	clc
vtupssx:ret
	  				; SET TERM RESET
termreset:mov	vtinited,0		; say uninitialized
	clc
	ret

apcctl:	cmp	apctrap,0		; doing within an APC-macro?
	jne	apcctl1			; ne = yes, don't do it
	mov	ah,cmkey		; SET TERM APC-macro enable, disable
	mov	bx,offset apchlp	; help
	mov	dx,offset apctab	; APC table
	call	comnd
	jc	apcctl1			; failure
	push	bx
	mov	ah,cmeol
	call	comnd
	pop	bx
	jc	apcctl1			; c = fail
	mov	apcenable,bl		; enable flag
	clc
apcctl1:ret

vtdownld:mov	ah,cmkey		; AUTODOWNLOAD {ON, OFF}
	mov	bx,offset dnldhlp
	mov	dx,offset ontab
	call	comnd
	jc	vtdownldx
	mov	vtemu.vtdnld,bl		; status
	clc
vtdownldx:ret

vtenqctl:mov	ah,cmkey		; SET TERM Answerback {ON, OFF}
	mov	bx,offset enqhlp	; help
	mov	dx,offset enqtab	; on/off/message table
	call	comnd
	jc	vtenqctl1		; failure
	cmp	bl,2			; message?
	je	vtenqctl1		; e = yes
	cmp	bl,3			; unsafe-message?
	je	vtenqctl1		; e = yes
	push	bx			; else 0=off, 1=on
	mov	ah,cmeol
	call	comnd
	pop	bx
	jc	vtenqctlx		; c = fail
	mov	vtenqenable,bl		; enable (1) flag
	clc
	ret
vtenqctl1:
	mov	enqbuf,0		; presume save message
	cmp	bl,3			; unsafe?
	jne	vtenqctl2		; ne = no
	mov	enqbuf,1		; say unsafe
vtenqctl2:
	mov	dx,offset enqhlp2	; help
	mov	comand.cmdonum,1	; \number conversion allowed
	mov	comand.cmblen,length enqbuf-1 ; length of analysis buffer
	mov	bx,offset rdbuf		; temp response buffer
	mov	ah,cmline
	call	comnd
	jc	vtenqctlx		; c = failure
	mov	si,offset rdbuf		; temp response buffer
	mov	di,offset enqbuf+1	; enquire response buffer
	call	strcpy			; copy string, asciiz
	clc
vtenqctlx:ret

scrwrite:mov	ah,cmkey		; SET TERM SCREEN-WRITING
	xor	bx,bx			; help
	mov	dx,offset writetab	; screen table
	call	comnd
	jc	scrwritx		; failure
	push	bx
	mov	ah,cmeol
	call	comnd
	pop	bx
	jc	vtupssx			; c = fail
	mov	writemode,bl		; store writing mode
	clc
scrwritx:ret

scrchange:mov	ah,cmkey		; SET TERM VIDEO-CHANGE
	xor	bx,bx			; help
	mov	dx,offset vchgtab	; enable/disable/dos-only
	call	comnd
	jc	scrchangex		; failure
	push	bx
	mov	ah,cmeol
	call	comnd
	pop	bx
	jc	scrchangex		; c = fail
	mov	vchgmode,bl		; store video-change mode
	clc
scrchangex:ret


expmemory:mov	ah,cmkey		; EXPANDED-MEMORY {OFF, EXTENDED, EXP}
	mov	bx,offset expmhlp	; help
	mov	dx,offset emmtab	; emm choice table
	call	comnd
	jc	expmem2			; failure
	push	bx
	mov	ah,cmeol
	call	comnd
	pop	bx
	jc	expmem2			; c = fail
	cmp	useexp,bl		; changing kinds?
	je	expmem1			; e = no
	mov	vsbuff_inited,0		; say reinitialize buffer memory
	mov	useexp,bl		; enable (1) flag
expmem1:clc
expmem2:ret

vtcodepage:mov	ah,cmkey		; SET TERM CODE-PAGE
	xor	bx,bx			; help
	mov	dx,offset setchtab	; Code Page table
	call	comnd
	jc	vtcode1			; failure
	push	bx
	mov	ah,cmeol
	call	comnd
	pop	bx
	jc	vtcode1			; c = fail
	mov	vtcpage,bx		; new terminal Code Page
	mov	vtemu.vtchop,-1		; force change of working set
	clc
vtcode1:ret

vtcpu:	mov	ah,cmkey		; SET TERM Timeslice-release
	xor	bx,bx			; help
	mov	dx,offset disatab	; enable/disable
	call	comnd
	jc	vtcpux			; failure
	push	bx
	mov	ah,cmeol
	call	comnd
	pop	bx
	jc	vtcpux			; c = fail
	mov	vtcpumode,bl		; store timeslice release mode
	clc
vtcpux:	ret

vtcrdisp:mov	ah,cmkey
	xor	bx,bx
	mov	dx,offset crdisptab	; table
	call	comnd
	jc	vtcrdispx
	push	bx
	mov	ah,cmeol
	call	comnd
	pop	bx
	jc	vtcrdispx
	mov	crdisp_mode,bl
	clc
vtcrdispx:ret

termesc:mov	ah,cmkey		; SET TERM ESCAPE
	xor	bx,bx
	mov	dx,offset termesctab	; table
	call	comnd
	jc	termescx
	push	bx
	mov	ah,cmeol
	pop	bx
	jc	termescx
	mov	termesc_flag,bl
	clc
termescx:ret

; SET Term flags. These are the (near) equivalent of VT100 Setup mode values.
flg1:	mov	ax,vsnewline		; NEWLINE
	mov	dx,offset ontab
	jmp	short flgset
flg2:	mov	ax,vswrap		; WRAP
	mov	dx,offset ontab
	jmp	short flgset
flg4:	mov	ax,vswdir		; DIRECTION
	mov	dx,offset dirtab
	jmp	short flgset
flg5:	mov	ax,vskeyclick		; KEYCLICK
	mov	dx,offset ontab
	jmp	short flgset
flg6:	mov	ax,vsmarginbell		; MARGIN BELL
	mov	dx,offset ontab
	jmp	short flgset
flg7:	mov	ax,vscursor		; CURSOR
	mov	dx,offset curtab
	jmp	short flgset
flg8:	mov	ax,vsscreen		; SCREEN
	mov	dx,offset scrtab
	jmp	short flgset
flg9:	mov	ax,vscntl		; CONTROLS
	mov	dx,offset cntltab
	jmp	short flgset
flg10:	mov	ax,deckpam		; KEYPAD
	mov	dx,offset kpamtab
	jmp	short flgset
flg11:	mov	ax,decckm		; ARROW
	mov	dx,offset arrtab
	jmp	short flgset
flg12:	mov	ax,deccol		; WIDTH
	mov	dx,offset widtab
	jmp	short flgset
flg13:	mov	ax,vshscroll		; Horizontal scrolling
	mov	dx,offset hstab
	jmp	short flgset
flg14:	mov	ax,vscompress		; compressed text display
	mov	dx,offset cmptab
;;	jmp	short flgset

flgset:	push	ax			; save flag
	mov	ah,cmkey		; another keyword
	xor	bx,bx			; use default help, dx has table ptr
	call	comnd
	pop	ax			; recover index
	jc	flgse0			; c = failure
	push	ax
	push	bx			; save result of keyword
	mov	ah,cmeol		; get confirm
	call	comnd
	pop	bx
	pop	ax			; recover flag
	jc	flgse0			; c = failure
	or	bx,bx			; set or clear?
	jz	flgse1			; z = clear it
	or	vtemu.vtflgst,ax	; set the flag
	or	vtemu.vtflgop,ax	; in runtime flags too
flgse3:	test	ax,deccol		; modifying screen width?
	jz	flgse2			; z = no
	mov	al,crt_cols		; current width
	mov	dos_cols,al		; width to remember, for changes
flgse2:	clc				; success
flgse0:	ret     
flgse1: not	ax			; Complement
	and	vtemu.vtflgst,ax	; clear the indicated setup flag
	and	vtemu.vtflgop,ax	; clear the indicated runtime flag
	not	ax
	jmp	short flgse3		; test for screen change
     
;	SET Term Tabstops Clear ALL
;	SET Term Tabstops Clear AT n1, n2, ..., nx
;	SET Term Tabstops At n1, n2, ..., nx
     
tabmod:	mov	ah,cmkey		; parse keyword
	mov	bx,offset clrhlp	; help text
	mov	dx,offset tabtab	; table
	call	comnd
	jc	tabmo2			; c = failure
	mov	clrset,2		; 2 = code for set a tab
	or	bl,bl			; clear?
	jnz	tabmo4			; nz = no, SET. parse column number(s)
	mov	clrset,1		; code for clear at/all tab(s)
	mov	ah,cmkey		; CLEAR, parse ALL or AT
	mov	bx,offset clrhlp	; help text
	mov	dx,offset alltab	; parse ALL or AT
	call	comnd
	jc	tabmo2			; c = failure
	or	bx,bx			; ALL?
	jnz	tabmo4			; nz = AT, clear at specific places
	mov	ah,cmeol		; confirm the ALL
	call	comnd
	jc	tabmo2			; c = failure
	mov	cx,vswidth		; ALL, means clear all tab stops
tabmo1:	mov	dx,cx
	dec	dl			; column number, starting with 0
	mov	si,vtemu.vttbs		; the cold-start buffer
	call	ftabclr			; clear the tab
	loop	tabmo1			; do all columns
	mov	si,vtemu.vttbs
	mov	di,vtemu.vttbst		; and active buffer
	call	tabcpy			; update active tabs
	clc				; success
tabmo2:	ret				; a success/fail return point

tabmo4:	mov	si,vtemu.vttbs		; from the cold-start buffer
	mov	di,offset decbuf	; temp work buffer
	call	tabcpy			; make a working copy of the tabs
	mov	skip,0			; clear spacing-active flag
	mov	temp,0			; place where last tab was written
tabmo6:	mov	dx,offset clrhlp2	; tell them we want a column number
	mov	ah,cmword		; get line of text
	mov	bx,offset rdbuf		; temp buffer
	mov	comand.cmcomma,1	; commas are equivalent to spaces
	call	comnd
	jc	tabmo2			; c = failure
	or	ax,ax			; anything given?
	jnz	tabmo7			; nz = yes
	mov	ah,cmeol		; confirm end of line
	call	comnd
	jc	tabmo2			; failure
	mov	si,offset decbuf	; copy tabs from temp work buffer
	mov	di,vtemu.vttbs		; to the cold-start buffer
	call	tabcpy			; copy work to cold start
	mov	di,vtemu.vttbst		; and terminal emulator's active buf
	call	tabcpy
	clc
	ret

tbsbad:	mov	ah,prstr		; not in range - complain
	mov	dx,offset tbserr
	int	dos
	stc
	ret
     
tabmo7:	mov	si,offset rdbuf		; si = string
tabmo8:	mov	dx,si
	call	strlen			; get length of this word
	jcxz	tabmo6			; empty, get more user input
	mov	domath_ptr,si		; try for expression
	mov	domath_cnt,cx
	mov	domath_msg,1		; do not complain
	call	domath
	mov	si,domath_ptr		; where to read next string byte
	jnc	tabmo9			; got a value
	cmp	byte ptr [si],','	; comma syntax?
	jne	tabmo8a			; ne = no
	inc	si			; skip the comma and try next field
	jmp	short tabmo8
tabmo8a:cmp	byte ptr [si],':'	; spacing separator?
	jne	tbsbad			; ne = no, no number available
	inc	si			; skip colon, do start:space analysis
	inc	skip			; set spacing-active flag
	jmp	short tabmo8		; get another token

tabmo9:	cmp	skip,0			; want spacing value now?
	jne	tabmo11			; ne = yes, go do it
	mov	dx,ax			; column (1-vswidth style)
	dec	dx			; put column in range 0-131
	or	dx,dx			; check range (1-vswidth-->0-...)
	js	tbsbad			; s = too small. complain
	cmp	dl,vswidth-1		; more than the right most column?
	ja	tbsbad			; a = yes, quit
	mov	temp,dx			; remember last written position
	jmp	tabmo15			; and write this member

tabmo11:mov	dx,temp			; continue spacing analysis
	mov	skip,0			; clear spacing-active flag
	mov	cx,ax			; "space" value
	or	cx,cx			; zero spacing?
	jnz	tabmo12			; nz = no
	inc	cx			; don't get caught with zero spacing
tabmo12:cmp	dx,vswidth-1		; largest tab stop
	ja	tabmo8			; a = done largest tab stop
	mov	temp,dx			; remember last written tabstop
	push	si
	mov	si,offset decbuf	; the work buffer
	cmp	clrset,2		; set?
	jne	tabmo13			; ne = no, clear
	call	ftabset			; set tabstop in column DL
	jmp	short tabmo14
tabmo13:call	ftabclr			; clear tabstop in column DL
tabmo14:add	dx,cx			; new column value
	pop	si
	jmp	short tabmo12		; finish spacing loop

tabmo15:push	si			; individual tabstop
	mov	si,offset decbuf	; the work buffer
	cmp	clrset,2		; set?
	jne	tabmo16			; ne = no, clear
	call	ftabset			; set tabstop in column DL
	jmp	short tabmo17		; get next command value
tabmo16:call	ftabclr			; clear tabstop in column DL
tabmo17:pop	si
	jmp	tabmo8			; get next command value

VTS	endp				; end of Set Term things

	      ; Terminal Status display, called within STAT0: in MSSSET
VTSTAT	proc	near			; enter with di within sttbuf, save bx
	mov	bx,offset vtstbl	; table of things to show
	jmp	statc			; status common code, in mssset
vtstat	endp

txtcolstat proc	near			; text color status report
	push	si
	mov	si,offset txtcolst1
	mov	bx,vtemu.att_ptr	; pointer to attributes byte
	call	colstd			; report worker
	mov	si,offset colst3
txtcols1:lodsb
	cmp	al,'$'
	je	txtcols2
	stosb
	jmp	short txtcols1
txtcols2:mov	al,reset_color
	or	al,al			; resetting color after CSI [ m?
	jz	txtcols3		; z = no
	mov	al,'2'			; show as "20"
	stosb
txtcols3:mov	al,'0'
	stosb
	pop	si
	ret
txtcolstat endp

undcolstat proc	near			; underline color status report
	push	si
	mov	si,offset undcolst1
	mov	bx,offset colunder	; pointer to attributes byte
	call	colstd			; report worker
	pop	si
	ret
undcolstat endp

ifndef	no_graphics
grcolstat proc	near			; graphics color status report
	push	si
	mov	si,offset grcolst1
	call	tekgcptr		; get pointer to active Tek color pal
	call	colstd			; report worker
	pop	si
	ret
grcolstat endp
endif	; no_graphics

; enter with offset of initial msg in si and ptr to color codes in bx
colstd	proc	near			; worker for color status reports
	cld
colstd1:lodsb
	cmp	al,'$'			; end of string?
	je	colstd2			; e = yes
	stosb
	jmp	short colstd1
colstd2:mov	bl,byte ptr[bx]		; attributes
	xor	bh,bh
	push	bx
	and	bx,7			; get foreground set
	mov	al,colortb[bx]		; get reversed bit pattern
	add	al,'0'			; add ascii bias
	stosb
	pop	bx
	mov	si,offset colst2
colstd3:lodsb
	cmp	al,'$'
	je	colstd4
	stosb
	jmp	short colstd3
colstd4:mov	cl,4			; rotate 4 positions
	shr	bl,cl
	and	bx,7			; get background set
	mov	al,colortb[bx]		; get reversed bit pattern
	add	al,'0'			; add ascii bias
	stosb
	ret
colstd endp

tabstat proc	near			; worker,display tabs ruler for Status
	push	dx
	cld
	mov	al,cr
	stosb
	cmp	cl,10			; are we on a new line?
	jb	tabsta0			; b = no, do a lf now
	mov	al,lf
	stosb
tabsta0:xor	cl,cl			; column index
	xor	ax,ax			; ah = tens, al = units counter
tabsta1:mov	dl,'.'			; default position symbol
	inc	al
	cmp	al,10			; time to roll over?
	jb	tabsta2			; b = not yet
	xor	al,al			; modulo 10
	inc	ah
	mov	dl,ah			; display a tens-digit
	add	dl,'0'
	cmp	dl,'9'			; larger than 90?
	jbe	tabsta2			; be = no
	sub	dl,10			; roll over to 0, 1, etc
tabsta2:push	dx
	push	si
	mov	dl,cl			; column number, counted from 0
	mov	si,vtemu.vttbst		; the active buffer
	call	istabs			; is tab set here?
	pop	si
	pop	dx
	jnc	tabsta3			; nc = no
	mov	dl,'T'			; yes, display a 'T'
tabsta3:push	ax
	mov	al,dl
	stosb
	pop	ax
	inc	cl
	cmp	cl,byte ptr low_rgt	; done yet?
	jb	tabsta1			; b = not yet
	pop	dx
	ret
tabstat endp

; Returns carry set if column in DL is a tab stop, else carry clear.
; Enter with column number in DL (starts at column 0, max of vswidth-1)
; and tabstop buffer offset in SI.
istabs	proc	near
	push	bx
	push	cx
	mov	cl,dl			; column number (0 to swidth-1)
	and	cl,00000111b		; keep bit in byte (0-7)
	inc	cl			; map to 1-8
	mov	bl,dl			; column
	shr	bl,1			; bl / 8 to get byte
	shr	bl,1
	shr	bl,1
	xor	bh,bh			; clear high byte
	mov	bl,[si+bx]		; get a byte of tab bits
	ror	bl,cl			; rotate to put tab-set bit into carry
	pop	cx
	pop	bx
	ret
istabs	endp

ansbkstat proc	near
	mov	ax,di			; starting place
	push	ax
	mov	si,offset vtenqst2
	mov	cx,vtenqst2_len
	cld
	rep	movsb
	mov	si,offset enqbuf+1	; skip safe/unsafe byte
	mov	dx,si
	call	strlen			; append local string
	rep	movsb
	pop	ax
	mov	cx,di
	sub	cx,ax			; return space used
	ret
ansbkstat endp

filler	proc	near			; use space
	mov	cx,20
	mov	al,' '
	cld
	rep	stosb
	ret
filler	endp

; Jump here to exit Connect mode and execute macros 'KEYBOARDR' (vtkrmac) or
; 'KEYBOARDS' (vtksmac). Does nothing if macro does not exist.
; Preserves registers except ax. Returns to TELNET caller with 'C' in kbdflg.
vtkrmac	proc	near			; RESET macro
	mov	vtmacname,offset vtkrname ; select macro name
	mov	vtmaclen,vtkrlen	; and its length
	call	dword ptr vtmacroptr	; FAR pointer, finish in common code
	jc	vtkrmac1		; c = failure
	jmp	far ptr endcon		; end connect mode, do macro
vtkrmac1:ret
vtkrmac	endp

vtksmac	proc	near			; SET macro
	mov	vtmacname,offset vtksname
	mov	vtmaclen,vtkslen
	call	dword ptr vtmacroptr	; FAR pointer
	jc	vtksmac1		; c = failure
	jmp	far ptr endcon		; end connect mode, do macro
vtksmac1:ret
vtksmac	endp

; Invoked by keyboard translator when an unknown keyboard verb is used as
; a string definition, such as {\ktest}. Enter with vtmacname pointing to
; uppercased verb name, asciiz, and vtmaclen set to its length.
extmacro proc	near
	call	dword ptr vtmacroptr	; FAR pointer
	jc	extmac1			; c = failure
	jmp	far ptr endcon		; end connect mode, do macro
extmac1:mov	kbdflg,' '		; report ' ' to TERM's caller
	ret				; to resume Connect mode
extmacro endp

; Invokes macro PRODUCT with variables \%1..\%9
; defined as the ascii renditions of the control sequence numeric paramters
; param[0]..param[8], and sets script ARGC item to one greater than this.

product	proc	near
	call	far ptr prodwork	; FAR pointer
	jc	prodmac1		; c = failure
	jmp	far ptr endcon		; end connect mode, do macro
prodmac1:ret
product	endp

term	proc	near
	call	far ptr fterm
	ret
term	endp

fclrmod	proc	far
	call	clrmod
	ret
fclrmod	endp

fputmod	proc	far
	call	putmod
	ret
fputmod	endp

fcmblnk	proc	far
	call	cmblnk
	ret
fcmblnk	endp
fkbhold	proc	far
	call	kbhold
	ret
fkbhold	endp
fprtchr	proc	far
	call	prtchr
	ret
fprtchr	endp
fkeybd	proc	far
	call	keybd
	ret
fkeybd	endp
fpntflsh proc	far
	call	pntflsh
	ret
fpntflsh endp
fpntchr	proc	far
	call	pntchr
	ret
fpntchr	endp
foutchr	proc	far
	call	outchr
	ret
foutchr	endp
fspath	proc	far
	call	spath
	ret
fspath	endp
fcrun	proc	far
	call	crun
	ret
fcrun	endp
fserini	proc	far
	call	serini
	ret
fserini	endp
fctlu	proc	far				; [HF]940211
	call	ctlu				; [HF]940211
	ret					; [HF]940211
fctlu	endp					; [HF]940211
vtinit	proc	near
	call	fvtinit
	ret
vtinit	endp

rtone	proc	near
	call	frtone
	ret
rtone	endp

rtpage	proc	near
	call	frtpage
	ret
rtpage	endp

lfone	proc	near
	call	flfone
	ret
lfone	endp

lfpage	proc	near
	call	flfpage
	ret
lfpage	endp

homwnd	proc	near
	call	fhomwnd
	ret
homwnd	endp
endwnd	proc	near
	call	fendwnd
	ret
endwnd	endp
dnwpg	proc	near
	call	fdnwpg
	ret
dnwpg	endp
dnone	proc	near
	call	fdnone
	ret
dnone	endp
upwpg	proc	near
	call	fupwpg
	ret
upwpg	endp
upone	proc	near
	call	fupone
	ret
upone	endp
fcptchr	proc	far
	call	cptchr
	ret
fcptchr	endp
fserrst	proc	far
	call	serrst
	ret
fserrst	endp
ifndef	no_network
fubclose proc	far
	call	ubclose
	ret
fubclose endp
endif	; no_network
endif	; no_terminal
code	ends

code1	segment
	assume	cs:code1
					; Kermit startup time initialization
flclyini proc	far
	mov	ah,conout		; write a space to determine
	mov	dl,' '			; DOS's default cursor coloring
	int	dos
	call	getpcur			; get current cursor position into dx
	mov	lincur,cx		; save cursor type (scan line #'s)
	dec	dl			; backup to last char
	or	dl,dl
	jns	lclyin5			; ns = no problem
	xor	dl,dl			; else set cursor back to left margin
lclyin5:call	setpcur			; set the cursor
	call	getpcha			; read current attributes into AH
	mov	scbattr,ah		; save video attributes
	mov	savattr,ah		; and saved attributes
	mov	dosattr,ah		; and here too
	and	ah,att_bold		; select intensity bit
	mov	userbold,ah		; save bit for user Bold control
	mov	ega_mode,0		; assume no EGA
	mov	ax,1200H		; EGA: Bios alternate select
	mov	bl,10H			; Ask for EGA info
	mov	bh,0ffH			; Bad info, for testing
	mov	cl,0fH			; Reserved switch settings
	int	screen			; EGA, are you there?
	cmp	cl,0cH			; Test reserved switch settings
	jge	lclyin1			; ge = no EGA in use
	push	es
	mov	ax,40h			; check Bios 40:87h for ega being
	mov	es,ax			;  the active display adapter
	test	byte ptr es:[87h],8	; is ega active?
	pop	es
	jnz	lclyin1			; nz = no
	mov	ega_mode,1		; yes, set flag to say ega is active
	mov	crt_norm,3		; assume color monitor is attached
	or	bh,bh			; is color mode in effect?
	jz	lclyin1			; z = yes
	mov	crt_norm,7		; else use mode 7 for mono
lclyin1:call	scrseg			; test running in an Environment
	call	dvtest			; test for running under DESQview
	call	scrmod			; read video state, get crt_mode
	mov	dosetcursor,-1		; cursor position reminder, none
	mov	ax,low_rgt		; lower right corner of screen
	mov	al,crt_mode
	mov	crt_norm,al		; save as normal mode
	mov	ah,crt_cols
	mov	dos_cols,ah		; remember for exiting Connect mode
ifndef	no_terminal
	mov	keypend,0		; [HF]940207 clear double byte flag
	mov	keyj7st,0		; [HF]940211 clear keyoutput status
	mov	cursor,0		; initial cursor
	call	vsalloc			; allocate memory for virtual screen
	jnc	lclyin4			; nc = success
	mov	ah,prstr
	mov	dx,offset memerr	; say not enough memory to operate
	int	dos
	mov	flags.extflg,1		; set Kermit exit flag
	ret

lclyin4:call	vsinit			; init terminal emulator module MSZ
	mov	bx,vtemu.att_ptr	; attributes pointer
	mov	ah,dosattr		; startup video attributes
	and	ah,not att_bold		; emulation intensity to normal
	or	ah,userbold
	mov	[bx],ah			; set initial emulation attributes
	and	vtemu.vtflgst,not deccol ; assume 80 column screen
	and	vtemu.vtflgop,not deccol
	cmp	crt_cols,80		; screen cols now, wide screen?
	jbe	lclyin6			; be = no
	or	vtemu.vtflgst,deccol	; say using 132 columns screen
	or	vtemu.vtflgop,deccol
endif	; no_terminal
lclyin6:ret
flclyini endp

ifndef	no_terminal

; Allocate memory for virtual screen buffers vscreen and vsat.
; Return carry clear if success, else carry set. Removes older allocations.
vsalloc	proc	near
	call	vsalloc4		; free alloc'd memory, if any
	mov	al,crt_lins		; one minus number of screen rows
	inc	al
	mov	cl,vswidth		; virtual screen vscreen
	mul	cl			; lines time width, words for vscreen
	add	ax,ax			; need words
	add	ax,15			; round up
	mov	cl,4			; convert to paragraphs
	shr	ax,cl			; need words rather than bytes
	mov	cx,ax			; save total wanted paragraphs in cx
	mov	bx,ax			; ask for the memory
	mov	ah,alloc		; allocate memory
	int	dos			; bx has # free paragraphs
	mov	word ptr vs_ptr+2,ax	; seg of vsscreen (offset is zero)
	cmp	cx,bx			; got what we wanted
	jb	vsalloc5		; b = no
	push	es
	mov	es,ax
	xor	di,di
	shl	cx,1
	shl	cx,1
	shl	cx,1			; paragraphs to words
	mov	ah,scbattr
	mov	al,' '
	cld
	rep	stosw 			; clear the memory with def colors
	pop	es
	mov	al,crt_lins
	inc	al			; attributes (nibbles)
	mov	cl,vswidth		; lines time width, bytes for vsattr
	mul	cl
	add	ax,15			; round up
	mov	cl,4			; convert to paragraphs
	shr	ax,cl
	mov	cx,ax			; save total wanted paragraphs in cx
	mov	bx,ax			; ask for the memory
	mov	ah,alloc		; allocate the memory
	int	dos			; bx has # free paragraphs
	mov	word ptr vsat_ptr+2,ax	; seg of vsattr (offset is zero)
	cmp	cx,bx			; got what we wanted
	jb	vsalloc4		; b = no
	push	es
	mov	es,ax
	xor	di,di
	shl	cx,1
	shl	cx,1
	shl	cx,1
	shl	cx,1			; paragraphs to bytes
	xor	al,al
	rep	stosb 			; clear the memory with def extattr
	pop	es
	clc				; report success
	ret

vsalloc4:mov	ax,word ptr vsat_ptr+2	; seg of vsattr (offset is zero)
	or	ax,ax			; unused?
	jz	vsalloc5		; z = yes
	push	es
	mov	es,ax			; allocated segment
	mov	ah,freemem		; free it
	int	dos
	mov	word ptr vsat_ptr+2,0	; clear pointer too
	pop	es
vsalloc5:mov	ax,word ptr vs_ptr+2	; seg of vsscreen
	or	ax,ax			; unused?
	jz	vsalloc6		; z = yes
	push	es
	mov	es,ax			; allocated segment
	mov	ah,freemem		; free it
	int	dos
	mov	word ptr vs_ptr+2,0	; clear pointer too
	pop	es
vsalloc6:stc				; return failure
	ret
vsalloc	endp

; Allocate memory for screen rollback buffers.
; Return carry clear if success, else carry set to exit.
vsbuff	proc	near			; screen roll back buffers
	cmp	vsbuff_inited,0		; inited yet?
	je	vsbuff0			; e = no
	clc				; say success
	ret
vsbuff0:mov	vsbuff_inited,1		; say we are initializing
	cmp	emsrbhandle,-1		; valid EMS rollback handle?
	je	vsbuff20		; e = no
	mov	ah,emsrelease		; release pages
	mov	dx,emsrbhandle		; handle
	int	emsint
	mov	emsrbhandle,-1		; invalidate EMS rollback handle
	mov	iniseg,0		; and no segment for page frame
	jmp	short vsbuff21
vsbuff20:cmp	xmsrhandle,0		; using XMS?
	je	vsbuff20a		; e = no
	mov	dx,xmsrhandle		; handle for memory block
	mov	ah,xmsrelease		; release the memory block
	call	dword ptr xmsep		; xms handler entry point
	mov	xmsrhandle,0
	mov	dx,xmsghandle		; and the graphics area too
	mov	ah,xmsrelease		; release the memory block
	call	dword ptr xmsep		; xms handler entry point
	mov	xmsghandle,0
vsbuff20a:
	mov	ax,iniseg		; memory segment, window area
	or	ax,ax			; anything allocated?
	jz	vsbuff21		; z = no
	mov	es,ax
	mov	ah,freemem		; free regular memory segment
	int	dos
	mov	iniseg,0
vsbuff21:
	mov	bx,rollwidth		; columns to roll back
	or	bx,bx			; user override given?
	jnz	vsbuff1			; nz = yes, else physical screen
	mov	bl,crt_cols		; physical screen
	xor	bh,bh
	mov	rollwidth,bx		; set final roll width
vsbuff1:add	bx,7			; round up (cancel common times twos)
	mov	cl,3
	shr	bx,cl			; bytes/line to paragraphs/line
	mov	ppl,bx			; paragraphs/line


vsbuff11:				; expanded memory
	test	useexp,1		; use expanded memory?
	jz	vsbuff10		; z = no, try XMS
	mov	ah,open2		; file open
	xor	al,al			; 0 = open readonly
	mov	dx,offset emsname	; device name EMMXXXX0
	int	dos
	jc	vsbuff10		; can't open, no expanded memory
	push	ax			; save handle
	mov	bx,ax			; handle ax
	xor	al,al			; get device info
	mov	ah,ioctl
	int	dos
	pop	ax
	push	dx			; save status report in dx
	mov	dx,ax			; handle
	mov	ah,close2		; close device
	int	dos
	pop	dx			; recover status report
	rcl	dl,1			; put ISDEV bit into the carry bit
	jnc	vsbuff10		; nc = not a device
	mov	ax,sp			; do push sp test for XT vs AT/386
	push	sp			; XT pushes sp-2, AT's push old sp
	pop	cx			; recover pushed value, clean stack
	xor	ax,cx			; same?
	jne	vsbuff5			; ne = no, XT. Don't do Int 2fh
	mov	ax,xmspresent		; XMS presence test
	int	2fh
	cmp	al,80h			; present?
	jne	vsbuff10		; ne = no
	mov	ah,getintv		; get interrupt vector
	mov	al,emsint		; EMS interrupt 67h
	int	dos			; to es:bx
	mov	ax,es
	or	ax,bx			; check for null
	jz	vsbuff10		; z = interrupt not activated
	mov	ah,emsmgrstat		; LIM 3.2 manager status
	int	emsint
	or	ah,ah			; ok?
	jnz	vsbuff10		; nz = not ok
	mov	ax,1024			; 1024 paragraphs per ems 16KB page
	xor	dx,dx
	div	ppl			; divide by paragraphs per line
	mov	lineems,ax		; lines per ems page, remember
	mov	al,crt_lins		; lines-1 per physical screen
	xor	ah,ah
	mov	cx,npages		; number of roll back screens wanted
	inc	cx			; include current screen
	mul	cx			; times number screens
	div	lineems			; lines total / (lines/emspage)
	or	dx,dx			; remainder?
	jz	vsbuff2			; z = no
	inc	ax			; add page for fraction
vsbuff2:push	ax			;  ax is number of emspages
	mov	ah,emsgetnpgs		; get number pages free
	int	emsint			; to bx
	pop	ax
	or	bx,bx			; any pages free?
	jz	vsbuff10		; z = no, try XMS
	cmp	bx,ax			; enough?
	jb	vsbuff3			; b = less, use what we can get
	mov	bx,ax			; number of pages wanted
vsbuff3:mov	ah,emsalloc		; allocate bx pages
	int	emsint
	or	ah,ah			; successful?
	jnz	vsbuff10		; nz = no, failure
	mov	emsrbhandle,dx		; returned handle
	mov	ax,bx			; pages allocated
	mov	inipara,ax		; save for later resizing of buffers
	mov	ah,emsgetseg		; get segment of page frame
	int	emsint			;  to bx
	or	ah,ah			; status, success?
	jnz	vsbuff10		; nz = no, no expanded memory today
	mov	iniseg,bx		; save here
	mov	ah,emsgetver		; get EMS version number
	int	emsint			; to al (high=major, low=minor)
	cmp	al,40h			; at least LIM 4.0?
	jb	vsbuff4			; b = no, so no name for our area
	mov	si,offset emsrollname	; point to name for rollback area
	mov	di,offset emsrollname+6	; add digits
	mov	dx,emsrbhandle
	mov	ax,dx
	call	dec2di			; write to handle name
	mov	ax,emssetname		; set name for handle from ds:si
	int	emsint
	mov	useexp,1		; say using expanded
vsbuff4:jmp	vsbuff9

vsbuff10:				; XMS, try this first
	test	useexp,2		; use extended memory?
	jz	vsbuff5			; z = no, try conventional
	cmp	xmsrhandle,0		; have already allocated xms?
	je	vsbuff10a		; e = no
	mov	ah,xmsrelease		; release memory block
	mov	dx,xmsrhandle
	call	dword ptr xmsep		; release the memory
	jmp	short vsbuff10b
vsbuff10a:xor	bx,bx			; clear entry point response
	mov	es,bx
	mov	ax,xmsmanager		; get XMS manager entry point
	int	2fh			; to es:bx
	mov	word ptr xmsep,bx	; save entry point in xmsep
	mov	ax,es
	or	bx,ax			; is there an entry point returned?
	jz	vsbuff5			; z = no, use regular memory
	mov	word ptr xmsep+2,ax
vsbuff10b:mov	ax,ppl			; paragraphs / line
	mul	crt_lins		; times lines-1 on physical screen
	mov	cx,npages		; number of roll back screens wanted
	inc	cx			; include current screen
	mul	cx			; total number of paragraphs wanted
	mov	cx,6
vsbuff10c:shr	dl,1
	rcr	ah,1
	rcr	al,1			; get kilobytes to ax
	loop	vsbuff10c		; divide by 2^6
	mov	dx,ax			; KB wanted to dx
	push	dx
	mov	ah,xmsquery
	call	dword ptr xmsep		; get largest block KB into ax
	pop	dx
	cmp	dx,ax			; wanted KB vs available KB
	jbe	vsbuff10d		; be = have space
	mov	dx,ax			; else use space available
vsbuff10d:push	dx			; save KB request amount
	mov	ah,xmsalloc		; allocate block of dx KB
	call	dword ptr xmsep
	mov	xmsrhandle,dx		; returned XMS handle of block
	pop	dx			; recover KB request amount
	mov	cx,6			; convert dx KB to paragraphs in AX
	mov	ax,dx			; KB allocated to AX
	xor	dx,dx
vsbuff10e:shl	al,1			; convert KB to paragraphs
	rcl	ah,1
	loop	vsbuff10e		; times 2^6, yield paragarphs in ax
	mov	inipara,ax		; initial number of paragraphs
	mov	useexp,2		; say using extended
	jmp	vsbuff9			; end XMS

					; no ems, so use regular memory
vsbuff5:mov	useexp,0		; say no ems
	mov	bx,0ffffh		; ask for all of memory, to get size
	mov	ah,alloc		; allocate all of memory (must fail)
	int	dos			; bx has # free paragraphs
	mov	ax,bx			; ax has copy of number free paragraphs
	sub	bx,26000D/16		; space for Command.com copy #2
	jc	vsbuff7			; c = not enough for it
	mov	ax,ppl			; paragraphs / line
	mul	crt_lins		; times lines-1 on physical screen
	cmp	bx,ax			; minimum roll back space left over?
	jbe	vsbuff7			; be = not even that much
	mov	cx,npages		; number of roll back screens wanted
	inc	cx			; include current screen
	mul	cx			; total number of paragraphs wanted
	mov	cx,ax			; save in cx
	or	dx,dx			; want more than 1 MB of real memory?
	jz	vsbuff6			; e = no
	mov	cx,0ffffh		; set all of real memory
vsbuff6:cmp	bx,cx			; got vs wanted paras for roll back
	jbe	vsbuff8			; be = enough but not more than needed
	mov	bx,cx			; limit to our actual needs
	jmp	short vsbuff8		; ask for all we really want
vsbuff7:xor	bx,bx			; use no space at all
	mov	cx,bx			; remember this new request
vsbuff8:mov	ah,alloc
	int	dos
	mov	iniseg,ax		; (BDT) memory segment, window area
	mov	inipara,bx		; save for later resizing of buffers
	cmp	cx,bx			; paragraphs wanted vs delivered
	jae	vsbuff9			; ae = enough
	mov	ah,prstr
	mov	dx,offset memerr	; say not enough memory to operate
	int	dos
	stc				; carry set = fail
	ret
vsbuff9:call	bufadj 			; set roll back buffer parameters
	clc				; carry clear for success
	ret
vsbuff	endp

scrini	proc	far			; init screen stuff
	call	chkwindows		; check for Windows being active
	mov	al,crt_lins		; screen lines - 1 
	mov	ah,crt_mode		; preserve this too
	push	ax			; save
	call	scrmod			; get screen mode now
	mov	ax,100h			; assume 80 column mode, no-renter
	test	vtemu.vtflgop,deccol	; supposed to be in 80 col?
	jz	scrin5			; z = yes
	inc	al			; say want 132 cols
scrin5:	call	chgdsp			; set to 80/132 columns
	call	scrmod			; get crt_lins again
	pop	ax
	mov	crt_mode,ah		; restore in case in graphics now
	cmp	al,crt_lins		; changed?
	je	scrin2			; e = no
	mov	vtinited,0		; say must reinit emulator
	mov	cursor,0
	call	vsalloc			; reallocate virtual screen
	jnc	scrin2			; nc = success
	mov	ah,prstr
	mov	dx,offset memerr	; say not enough memory to operate
	int	dos
	mov	sp,oldsp
	ret				; must be Far return
	
scrin2:
scrin1:	mov	ah,savattr		; saved emulator attributes
	mov	scbattr,ah		; restore active value
	call	scrseg			; update screen segment tv_seg(s/o)
	call	getpcur			; get cursor position DX and type CX
	cmp	flags.vtflg,0		; emulating anything?
	jne	scrin4			; ne = yes
	mov	cursor,dx		; use physical cursor
scrin4:	mov	dx,cursor		; use old cursor, if any
	call	setpos			; set cursor position
	cmp	vtinited,inited		; inited emulator yet?
	je	scrin11			; e = yes, do reinit
	call	fvtinit			; init it now
	call	repaint			; repaint screen
	ret

scrin11:
ifndef	no_graphics
	cmp	flags.vtflg,tttek	; Tek mode?
	je	scrin12			; e = yes
	test	tekflg,tek_tek+tek_dec 	; Tek submode?
	jz	scrin14			; z = no
scrin12:call	tekini			; init graphics mode
	ret
endif	; no_graphics

scrin14:call	ansrei			; reinit the emulator
	call	repaint			; restore screen from vscreen
scrin15:ret
scrini	endp

chkwindows proc	near
	mov	inwindows,0		; presume not in Windows
	mov	ax,sp			; do push sp test for XT vs AT/386
	push	sp			; XT pushes sp-2, AT's push old sp
	pop	cx			; recover pushed value, clean stack
	xor	ax,cx			; same?
	jne	chkwin2			; ne = no, XT. Don't do Int 2fh
	mov	ax,1683h		; Windows 3, get current virt machine
	int	2fh
	cmp	ax,1683h		; virtual machine, if any
	je	chkwin2			; e = none
	mov	inwindows,1		; say in Windows
chkwin2:ret
chkwindows endp

; Initialize terminal emulators
fvtinit	proc	far
	mov	ax,apcstring		; seg of apcmacro memory area
	or	ax,ax			; empty?
	jz	vtini4			; z = yes
	mov	es,ax
	mov	ah,freemem
	int	dos			; free that memory
	mov	apcstring,0
vtini4:	mov	holdscr,0		; clear holdscreen
	mov	vtclear,0		; clear clear-screen indicator
	mov	keypend,0		; [HF]940207 clear double byte flag
	mov	keyj7st,0		; [HF]940211 clear keyoutput status
	call	fkbhold			; tell DEC LK250 the state, in msuibm
	or	vtinited,inited
	mov	dosetcursor,0		; cursor position reminder, none
	mov	bx,portval
	mov	dl,[bx].ecoflg		; local echo flag
	and	yflags,not lclecho
	or	yflags,dl
	mov	bx,argadr		; address of argument block
	mov	dl,[bx].baudb		; baud rate code in dl
	mov	dh,[bx].parity		; parity code in bits
	mov	cl,4			; 0-3 of dh
	shl	dh,cl
	or	dh,07H			; just say 7 data bits
	test	flags.remflg,d8bit	; eight bit display?
	jz	vtini1			; z = no
	inc	dh			; set low four bits to value 8
vtini1:	cmp	flags.vtflg,0		; doing emulation?
	je	vtini3			; e = no
	cmp	tekflg,tek_active+tek_tek ; Tek graphics mode?
	je	vtini2			; e = yes, do it's reinit
	cmp	tekflg,tek_active+tek_dec ; Tek graphics submode?
	je	vtini2			; e = yes, do it's reinit
	xor	ax,ax			; assume 80 col mode (al=0)
	test	vtemu.vtflgst,deccol	; want wide display?
	jz	vtini1a			; z = no
	inc	al			; set AL to 1 for set 132 col mode
vtini1a:call	chgdsp			; set screen width
	call	ansini			; call startup routine in mszibm
	cmp	flags.vtflg,tttek	; full Tek mode?
	jne	vtinix			; ne = no
	or	tekflg,tek_tek		; say tek mode
	jmp	short vtini2		; e = yes
vtinix:	clc
	ret
vtini2:
ifndef	no_graphics
	call	tekrint			; reinitialize Tek emulator
endif	; no_graphics
	clc
	ret
vtini3:	call	fcmblnk			; clear the screen
	clc
	ret
fvtinit	endp

argini	proc	near			; read passed arguments
	mov	bx,argadr		; base of argument block
	mov	al,[bx].flgs		; get flags
	and	al,capt+emheath+trnctl+lclecho+modoff
	mov	yflags,al		; mask for allowable and save
	mov	al,[bx].prt
	mov	portno,al		; update port number
	ret
argini	endp

fterm	proc	FAR			; terminal mode entry point
	mov	argadr,ax		; save argument ptr
	mov	oldsp,sp		; remember stack for i/o failure,
	mov	apctrap,0		; un-trap certain commands
ifndef	no_tcp
	cmp	flags.comflg,'t'	; doing internal Telnet?
	jne	fterm2			; ne = not Telnet
	cmp	termlatch,0		; have we been here for macro?
	jne	fterm2			; ne = yes, reset it and skip macro
	mov	termlatch,1		; arm reentry bypass
	mov	bx,sescur		; get session to bl
	call	vtsesmac		; this returns us to the Kermit prompt
	jc	fterm2			; c = no such macro
else
	jmp	short fterm2
endif	; no_tcp
fterm1:	call	fserrst			; shut down serial port now
	mov	kbdflg,'C' 		; say exit Connect mode
	ret				; return, to process macro

fterm2:	mov	termlatch,0		; disable bypass, enable macro again
	mov	handhsc,0		; cancel hand scrolling
	call	vsbuff			; allocate screen buffer memory
	jc	fterm1			; c = failure, quit now
	mov	grab,0			; clear Compose/Spcl output grabber
	call	argini			; init options from arg address
	mov	inemulator,1		; say in terminal emulator (local)
	call	scrini			; call screen setup
	or	kbcodes,80h		; set need-to-init flg for kbd xtlator
	mov	fairprn,0		; set printer buffer flush counter
lp:	call	fprtchr			; char at port?
	jnc	short lpinp		; nc = yes, go handle
ifndef	no_graphics
	cmp	tekflg,tek_active+tek_sg ; special graphics active?
	jne	lpcross			; ne = no, stay in idle loop
	mov	dx,dosetcursor		; preserved cursor position
	cmp	dx,-1			; should we set the cursor?
	je	lpcursor		; e = no
	call	teksetcursor		; set the cursor at dx
	mov	dosetcursor,-1		; turn off reminder

lpcursor:test	flags.vtflg,ttd463+ttd470+ttd217 ; doing DG emulation?
	jz	lpcross			; z = not DG
	cmp	dgcross,0		; is DG crosshair active?
	je	lpcross			; e = no
	xor	al,al			; feed it a null command, to do mouse
	call	croshair		; call Tek crosshair to read mouse
endif	; no_graphics

lpcross:cmp	repflg,0		; REPLAY?
	jne	lpkbd			; ne = yes
	push	bx
	mov	bx,portval		; port structure address
	cmp	[bx].portrdy,0		; is port ready for business?
	pop	bx
	jne	lpkbd			; ne = ready
	jmp	quit			; end the communications now
lpkbd:	mov	fairness,0		; say kbd was examined
	call	dvpause			; tell DESQview we are not busy
	inc	fairprn			; inc printer dump counter
	cmp	fairprn,100		; been here enough times now?
	jb	lpkbd1			; b = no
	call	fpntflsh		; flush printer buffer
	jnc	lpkbd0			; nc = success
	call	pntdead			; call bad printer notifier
lpkbd0:	mov	fairprn,0		; reset for next time
lpkbd1:	call	fkeybd			; call keyboard translator in msu
	jc	quit			; carry set = quit connect mode
	call	clkdsp			; display clock
	jmp	short lp		; and repeat idle loop

lpinp:	and	al,parmsk		; apply 8/7 bit parity mask
	call	outtty			; print on terminal
	inc	fairness		; say read port but not kbd, again
	cmp	fairness,100		; this many port reads before kbd?
	jb	lp			; b = no, read port again
	jmp	short lpkbd		; yes, let user have a chance too

quit:	mov	sp,oldsp		; recover startup stack pointer
					; TERM caller's return address is now
					; on the top of stack. A longjmp.
	mov	ah,scbattr		; current emulator attributes
	mov	savattr,ah		; save them here
	call	fpntflsh		; flush printer buffer
ifndef	no_graphics
	call    tekend			; cleanup Tektronix mode
endif	; no_graphics
	mov	inemulator,0		; say not in terminal emulator (local)
	mov	al,1
	call	csrtype			; turn on underline cursor
	mov	ah,dosattr		; attributes at init time
	mov	scbattr,ah		; background = original state
	call	fclrmod			; clear mode line with DOS attributes
	mov	ax,100h			; assume using 80 col screen
	cmp	dos_cols,80		; startup screen width
	jbe	quit1			; be = assume 80 columns
	inc	al			; say do 132 columns
quit1:
	push	vtemu.vtflgop
	or	vtemu.vtflgop,vscompress ; turn off compressed mode
	call	chgdsp			; reset display width to startup
	pop	vtemu.vtflgop
	call	scrmod			; update size info
					; for ega in non-standard # lines
	test	tv_mode,10h		; DV active?
	jnz	quit2			; nz = yes, it messes with the cursor
	cmp	ega_mode,0		; ega board active?
	je	quit2			; e = no
	cmp	byte ptr low_rgt+1,23	; is screen standard length?
	je	quit2			; e = yes, so regular cursor set is ok
	cmp	byte ptr low_rgt+1,24	; ANSI, is screen standard length?
	je	quit2			; e = yes, so regular cursor set is ok
	push	es			; turn off ega cursor emulation
	mov	ax,40h			; byte 40:87H is ega Info byte
	mov	es,ax
	push	es:[87h]		; save info byte around call
	or	byte ptr es:[87h],1	; set emulation off (low bit = 1)
	mov	cx,lincur		; cursor shape to set
	mov	ah,1			; set the shape
	int	screen			;   back to starting value
	pop	es:[87h]		; recover original Info byte
	pop	es			; and our work reg
	jmp	short quit3		; skip regular mode cursor setting
quit2:					; for regular sized screen
	mov	cx,lincur		; cursor type at startup
	mov	ah,1
	int	screen			; restore cursor type
quit3: 	mov	dh,byte ptr low_rgt+1	; bottom line -1
	xor	dl,dl			; left most column
	call	setpcur			; set cursor physical position
	mov	al,yflags
	mov	bx,argadr
	mov	[bx].flgs,al		; update flags in arg block
	call	dvpause			; tell DESQview we are not busy
	cmp	isps55,0		; [HF]940214 Japanese PS/55?
	je	quit4			; [HF]940214 e = no
	cmp	ps55mod,0		; [HF]940214 system modeline ?
	jne	quit4			; [HF]940214 ne = no
	push	ax			; [HF]940211
	push	dx			; [HF]940211
	mov	ah,prstr		; [HF]940211 we need newline for DOS
	mov	dx,offset crlf		; [HF]940211
	int	dos			; [HF]940211
	call	fctlu			; [HF]940211 clear new line
	pop	dx			; [HF]940211
	pop	ax			; [HF]940211
quit4:	ret
fterm	endp

; put the character in al to the screen
outtty	proc	near
	test	flags.remflg,d8bit	; keep 8 bits for displays?
	jnz	outtt1			; nz = yes, 8 bits if possible
	and	al,7fh			; remove high bit
outtt1:	cmp	flags.vtflg,0		; emulating a terminal?
	je	outnp10			; e = no
	cmp	vtroll,0		; auto roll back allowed?
	je	outem1			; e = no, leave screen as is
	test	tekflg,tek_active	; Tek mode active?
	jnz	outem1			; nz = yes, skip screen rolling
	push	ax			; (BDT) save this for a tad
	mov	ax,linec		; (BDT) are we at the buffer end?
	cmp	ax,lcnt
	pop	ax			; (BDT) restore the register
        je      outem1			; (BDT) e = yes
	push	ax			; (BDT) save AX again
	call	fendwnd			; do END to roll screen to end of buf
	pop	ax			; (BDT) restore the register
outem1:	test	tekflg,tek_active	; graphics mode active?
	jz	outem2			; z = no
	test	tekflg,tek_tek+tek_dec	; Tek submode active for input?
	jnz	outem3			; nz = yes, use Tek emulator
outem2:	call	anstty			; call terminal emulator, char in AL
	ret
outem3:
ifndef	no_graphics
	call	tekemu			; use Tek emulator and return
endif	; no_graphics
	ret
     					; use DOS for screen output
outnp10:test	flags.remflg,d8bit	; keep 8 bits for displays?
	jnz	outnp9			; nz = yes, 8 bits if possible
	and	al,7fh			; remove high bit
outnp9:	cmp	rxtable+256,0		; translation turned off?
	je	outnp7			; e = yes, no translation
	push	bx
	mov	bx,offset rxtable	; address of translate table
	xlatb				; new char is in al
	pop	bx
outnp7:	test	anspflg,prtscr		; should we be printing?
	jz	outnp8			; no, keep going
	call	fpntchr			; queue char for printer
	jnc	outnp8			; nc = successful print
	push	ax
	call	vtbell			; else make a noise and
	call	ftrnprs			;  turn off printing
	pop	ax
outnp8:	test	yflags,capt		; capturing output?
	jz	outnp6			; no, forget this part
	call	fcptchr			; give it captured character
outnp6:	test	yflags,trnctl		; debug? if so use Bios tty mode
	jz	outnp4			; z = no
	mov	ah,conout		; DOS screen write
	cmp	al,7fh			; Ascii Del char or greater?
	jb	outnp1			; b = no
	je	outnp0			; e = Del char
	push	ax			; save the char
	mov	dl,7eh			; output a tilde for 8th bit
	int	dos
	pop	ax			; restore char
	and	al,7fh			; strip high bit
outnp0:	cmp	al,7fh			; is char now a DEL?
	jne	outnp1			; ne = no
	and	al,3fH			; strip next highest bit (Del --> '?')
	jmp	outnp2			; send, preceded by caret
outnp1:	cmp	al,' '			; control char?
	jae	outnp3			; ae = no
	add	al,'A'-1		; make visible
outnp2:	push	ax			; save char
	mov	dl,5eh			; caret
	int	dos			; display it
	pop	ax			; recover the non-printable char
outnp3:	push	ax
	mov	dl,al
	int	dos
	pop	ax
	ret
outnp4:	cmp	al,bell			; bell (Control G)?
	jne	outnp5			; ne = no
	jmp	vtbell			; use short beep, avoid char loss
outnp5:	mov	dl,al			; write without intervention
	mov	ah,conout
	int	dos			; else let dos display char
	ret
outtty	endp
     
;[IU2] Here to output an unsigned 8-bit number (in al) to the port
; Used by terminal emulator escape sequence output.
     
prtnout proc	near
	jmp	short prtno2		; ensure at least a zero
     
prtno1: or	al,al
	jnz	prtno2			; nz = yes, do more digits
	ret				; no, return from recursive call
prtno2: xor	ah,ah			; clear previous remainder
	mov	bl,10			; output in base 10
	div	bl			; divide off a digit
	push	ax			; push remainder (in ah) on stack
	call	prtno1			; recurse
	pop	ax			; pop off a digit
	add	ah,'0'			; make it ASCII
	mov	al,ah			; send to port, in ah
	call	outprt
	jc	prtno3			; failure, end connection
	ret
prtno3:	jmp	far ptr endcon
prtnout endp

; Send the character in al out to the serial port; handle echoing.
; Can send an 8 bit char while displaying only 7 bits locally.
outprt	proc	near
	mov	ah,1			; say local echo is permitted
	jmp	short outprt0

prtbout:xor	ah,ah			; no local echo

outprt0:cmp	grab,0			; grabbing output?
	je	outprt0a		; e = no
	call	fgrabber		; yes, give it to the guy
	ret
outprt0a:test	al,80h			; high bit set?
	jz	outpr2			; z = no
	test	flags.vtflg,ttd463+ttd470+ttd217 ; Data General?
	jz	outprt4			; z = no
	test	flags.remflg,d8bit	; chop DG high bit?
	jnz	outpr2			; nz = no, send as-is
	and	al,7fh			; chop high bit
	jmp	short outpr1		; send with possible DG SI/SO brackets

outprt4:cmp	al,0a0h			; C1 area?
	jae	outpr1			; ae = no
	cmp	vtemu.vtchset,C_XPARENT	; TRANSPARENT?
	je	outpr2			; e = yes, pass as-is
	test	vtemu.vtflgop,vscntl	; sending 8-bit controls?
	jz	outprt5			; z = no, force use of 7-bit controls
	cmp	parmsk,7fh		; using parity?
	jne	outpr2			; ne = no, no need to force on that
outprt5:push	ax			; save char
	mov	al,Escape		; C1 as ESCAPE <char-40h>
	call	outpr2			; send ESCAPE
	pop	ax			; recover char
	sub	al,40h			; relocate the code
	jmp	short outpr2		; send the char
					; GRight printable characters
outpr1:	cmp	flags.vtflg,ttgenrc	; doing term type of NONE?
	je	outpr2			; e = yes, no tables (maybe SO/SI?)
	cmp	parmsk,7fh		; using parity?
	jne	outpr2			; ne = no, no shifts needed
	cmp	flags.oshift,0		; allowing shifts on output?
	je	outpr2			; e = no
	and	al,not 80h		; strip high bit
	test	flags.oshift,8		; Auto?
	jnz	outpr1a			; nz = yes
	test	flags.oshift,1		; force SI/SO?
	jnz	outpr8			; nz = yes
	jmp	short outpr1b		; else SS2/SS3
outpr1a:cmp	GRptr,offset G1set	; GR points to G1 char set?
	je	outpr8			; e = yes, use SO/char/SI
outpr1b:push	ax			; save char
	mov	al,Escape		; send SS2 as ESC N
	call	outpr2			; ESC N is Single Shift 2
	mov	al,'N'
	cmp	flags.oshift,4		; force SS3?
	jb	outpr7			; b = force SS2
	je	outpr1c			; e = force SS3
	cmp	GRptr,offset G2set	; GR points to G2 char set?
	je	outpr7			; e = yes, else use SS3 (ESC P)
outpr1c:inc	al			; use ESC P for Single Shift 3
outpr7:	call	outpr2
	pop	ax			; recover char
	jmp	short outpr2

outpr8:	push	ax			; save char
	mov	al,SOchar		; SO locking shift 1 for G1 to GL
	cmp	flags.vtflg,ttd463+ttd470+ttd217 ; D463/D470/D217?
	jz	outpr8a			; z = no
	mov	al,DGescape		; send SO as DG's  RS N
	call	outpr2
	mov	al,'N'
outpr8a:call	outpr2			; send it
	pop	ax
	push	ax			; preserve ah around call
	call	outpr2			; send real character (7 bit'd)
	pop	ax
	mov	al,SIchar		; shift back to normal
	test	flags.vtflg,ttd463+ttd470+ttd217 ; D463/D470/D217?
	jz	outpr2			; z = no
	mov	al,DGescape		; send SI as DG's  RS O
	call	outpr2
	mov	al,'O'

outpr2:	or	ah,ah			; local echo permitted?
	jz	outpr3			; z = no
	test	yflags,lclecho		; echoing ourselves?
	jz	outpr3			; z = no, forget it
	push	ax			; save char
	call	outtty			; display it
	pop	ax			; restore
ifndef	no_network
	cmp	al,CR			; sending CR?
	jne	outpr3			; ne = no
	cmp	flags.comflg,'t'	; doing Telnet?
	jne	outpr3			; ne = no
ifndef	no_tcp
	cmp	tcpnewline,1		; newline mode is on?
	ja	outpr3			; a = RAW, no extra LF
	je	outpr2a			; e = yes, send CR/LF (else NVT/Bin)
	cmp	tcpmode,0		; NVT-ASCII?
	jne	outpr3			; ne = no, Binary so no extra LF
endif	; no_tcp
outpr2a:push	ax
	mov	al,LF			; locally show LF which we will send
	call	outtty
	pop	ax
endif	; no_network
outpr3:	mov	ah,al			; this is where outchr expects it
	call	foutchr			; output to the port
	jc	outpr4			; c = failure
	ret
outpr4:	jmp	far ptr endcon		; failure, end connection
outprt	endp

fansdsl	proc	far
	call	ansdsl
	ret
fansdsl	endp

foutprt	proc	far
	call	outprt
	ret
foutprt	endp

; keyboard handler verbs come here to sidestep transparent mode ALT-nnn
outprt_key proc far
	test	al,80h			; high bit set?
	jz	outprt_key1		; z = no, send as-is
	cmp	al,0a0h			; C1 area?
	jae	outprt_key1		; ae = no, send as-is
	cmp	vtemu.vtchset,C_XPARENT	; TRANSPARENT?
	jne	outprt_key1		; ne = no
	push	ax			; 
	mov	al,Escape		; C1 as ESCAPE <char-40h>
	call	outprt			; send escape
	pop	ax
	sub	al,40h			; relocate the code
outprt_key1:
	call	outprt
	ret
outprt_key endp

fprtbout proc	far
	call	prtbout
	ret
fprtbout endp

fprtnout proc	far
	call	prtnout
	ret
fprtnout endp

; Product macro worker
prodwork proc	far
	push	si
	push	di
	push	es
	mov	ax,ds
	mov	es,ax
	mov	di,offset decbuf+2	; macro def buffer starts here
	mov	si,offset prodname	; pointer to macro name
	mov	cx,vtplen		; length of macro name
	cld
	rep	movsb			; copy to rdbuf+2
	mov	byte ptr [di],0		; null terminator
	mov	cx,nparam		; number of parameters
	cmp	cx,9			; more than 9?
	jle	produc1			; le = no
	mov	cx,9			; limit to 9
produc1:jcxz	produc3			; z = none
	xor	bx,bx			; parameter subscript
produc2:push	bx
	push	cx
	mov	al,' '			; and a space separator
	stosb
	shl	bx,1			; address words
	mov	ax,param[bx]		; get parameter to use as definition
	call	dec2di			; convert numerics to ascii string
	pop	cx
	pop	bx
	inc	bx
	loop	produc2
produc3:xor	al,al			; safety terminator
	mov	[di],al			; don't count in length
	mov	ax,di
	sub	ax,offset decbuf + 2	; compute length
	mov	vtmaclen,ax		; pass along to vtmacro
	mov	vtmacname,offset decbuf+2 ; say this is our macro text ptr
	pop	si
	pop	di
	pop	es
	jmp	short vtmacro
prodwork endp

;
; Reference	Macro structure for	db	number of entries (mac names)
;  is file	 table mcctab	   |->	dw	length of macroname
;  mssset.asm		each entry |-> 	db	'macroname'
;  where these			   |->	dw	segment:0 of definition string
;  are stored.					  (offset part is always 0)	
;		Definition string in 	db	length of <string with null>
;		 buffer macbuf	  	db	'string with trailing null'
;
vtmacro	proc	far			; common code for macros vtsmac,vtrmac
	push	bx			; and Product
	push	cx
	push	si
	push	di
	push	es
	mov	ax,ds
	mov	es,ax
	mov	di,offset decbuf+2	; macro def buffer starts here
	mov	si,vtmacname		; pointer to macro name
	mov	cx,vtmaclen		; length of macro name<sp/null>text
	mov	[di-2],cx		; counted string field
	cld
	rep	movsb			; copy to rdbuf
	mov	byte ptr [di],0		; null terminator
	mov	si,offset decbuf+2	; look for name-text separator
	mov	cx,vtmaclen
vtmac1:	lodsb
	cmp	al,' '			; space separator?
	je	vtmac1a			; e = yes, stop here
	or	al,al			; null terminator?
	jz	vtmac1a			; e = yes, stop here
	loop	vtmac1
	inc	si			; to do null length correctly
vtmac1a:sub	si,offset decbuf+2+1	; compute length of macro name
	mov	cx,si
	mov	vtmaclen,cx		; save a macro name length
					; check for existence of macro
	mov	bx,offset mcctab	; table of macro names
	mov	cl,[bx]			; number of names in table
	xor	ch,ch
	jcxz	vtmacx			; z = empty table, do nothing
	inc	bx			; point to length of first name
vtmac2:	mov	ax,[bx]			; length of this name
	cmp	ax,vtmaclen		; length same as desired keyword?
	jne	vtmac3			; ne = no, search again
	mov	si,bx
	add	si,2			; point at first char of name
	push	cx			; save name counter
	push	di			; save reg
	mov	cx,vtmaclen		; length of name
	mov	di,vtmacname		; point at desired macro name
	push	es			; save reg
	push	ds
	pop	es			; make es use data segment
	cld
	repe	cmpsb			; match strings
	pop	es			; need current si below
	pop	di			; recover saved regs
	pop	cx
	je	vtmac4			; e = matched
vtmac3:	add	bx,ax			; step to next name, add name length
	add	bx,4			; + count and def word ptr
	loop	vtmac2			; try next name
vtmacx:	pop	es
	pop	di
	pop	si			; no macro, return to Connect mode
	pop	cx
	pop	bx
	stc				; say failure
	ret

vtmac4:	call	takopen_macro		; open a macro
	mov	bx,takadr		; point to current macro structure
	mov	ax,ds			; segment of rdbuf
	mov	[bx].takbuf,ax		; segment of definition string struc
	mov	cx,word ptr decbuf	; length of count + string
	mov	[bx].takcnt,cx		; number of chars in definition
	mov	[bx].takargc,0		; our argument count
	mov	[bx].takptr,offset decbuf+2 ; where to read next command char
	pop	es
	pop	di
	pop	si
	pop	cx
	pop	bx
	clc				; say success, can exit connect mode
	ret
vtmacro	endp

; APC macro. Macro string (word count, string text) preset by mszibm.asm
; into seg apcstring offset 0.
apcmacro proc	near
	cmp	taklev,maxtak		; room in take level?
	jb	apcmac1			; b = yes
	stc				; fail
	ret
apcmac1:call	takopen_macro		; open macro
	mov	bx,takadr		; point to current macro structure
	mov	ax,apcstring		; segment of buffer
	mov	[bx].takbuf,ax		; segment of definition string struc
	mov	[bx].takcnt,cx		; number of chars in definition
	or	[bx].takattr,take_malloc; say have buffer to be removed
	cmp	apcenable,2		; enable all commands?
	je	apcmac2			; e = yes
	mov	apctrap,1		; trap certain commands
apcmac2:mov	apcstring,0		; takclos will delete the buffer
	jmp	far ptr endcon		; exit Connect mode cleanly
apcmacro endp

rcvmacro proc near
	call	takopen_macro		; open macro
	mov	bx,takadr		; point to current macro structure
	mov	ax,seg rcvstring	; segment of buffer
	mov	[bx].takbuf,ax		; segment of definition string struc
	mov	[bx].takptr,offset rcvstring+2
	mov	[bx].takcnt,rcvstring_len ; number of chars in definition
	mov	termserver,1		; say Connect mode started receive
	jmp	far ptr endcon		; exit Connect mode cleanly
rcvmacro endp

srvmacro proc near
	call	takopen_macro		; open macro
	mov	bx,takadr		; point to current macro structure
	mov	ax,seg srvstring	; segment of buffer
	mov	[bx].takbuf,ax		; segment of definition string struc
	mov	[bx].takptr,offset srvstring+2
	mov	[bx].takcnt,srvstring_len ; number of chars in definition
	mov	termserver,1		; say Connect mode started server
	jmp	far ptr endcon		; exit Connect mode cleanly
srvmacro endp

; Error recovery routine used when outchr reports unable to send character
;  or when vtmacro requests exiting Connect mode.
; Exit Connect mode cleanly, despite layers of intermediate calls.
endcon	proc	FAR
	mov	kbdflg,'C'		; report 'C' to TERM's caller
	mov	sp,oldsp		; recover startup stack pointer
					; TERM caller's return address is now
					; on the top of stack. A longjmp.
	jmp	quit			; exit Connect mode cleanly
endcon	endp

tabcpy	proc	far
	push	es			; worker copy routine
	push	si
	push	di
	mov	cx,ds
	mov	es,cx
	mov	cx,(vswidth+7)/8	; update all active tab stops
	cld
	rep	movsb
	pop	di
	pop	si
	pop	es
	clc				; success
	ret
tabcpy	endp

ifndef	no_terminal

; Issue warning that CP866 is needed but not loaded for Cyrillic char sets
chkcp866 proc	far
	cmp	bl,C_CYRILLIC_ISO	; these Cyrillic character sets?
	je	chkcp1			; e = yes
	cmp	bl,C_KOI8
	je	chkcp1
	cmp	bl,C_SHORT_KOI
	je	chkcp1
	ret
chkcp1:	cmp	vtcpage,866			; Code Page is CP866?
	je	chkcp2				; e = yes, no warning
	push	ax
	push	dx
	mov	ah,prstr
	mov	dx,offset cpwarn		; issue warning
	int	dos
	pop	dx
	pop	ax
chkcp2:	ret
chkcp866 endp
endif	; no_terminal

; Display HHMM on status line over the led dots
clkdsp	proc	far
	cmp	inemulator,0		; in terminal emulator?
	je	clkdsp1			; e = no, no mode line
	cmp	vtclkflg,0		; do not use clock
	je	clkdsp1			; e = correct, no clock
	cmp	inwindows,0		; in Windows?
;;;	jne	clkdsp1			; ne = yes, no clock
	cmp	flags.modflg,1		; mode line enabled and owned by us?
	jne	clkdsp1			; ne = no, don't touch it
	test	flags.vtflg,tttek	; Tek mode?
	jnz	clkdsp1			; nz = yes
	test	tekflg,tek_dec		; in Tek submode?
	jnz	clkdsp1			; nz = yes, no mode line changes
	test	yflags,modoff		; mode line off?
	jnz	clkdsp1			; nz = yes
	cmp	flags.vtflg,0		; emulating none?
	jne	clkdsp2			; ne = no
clkdsp1:ret
clkdsp2:push	ax
	push	bx
	push	cx
	push	dx
	push	es
	call	cboff			; turn off Control-Break sensing
	mov	ah,gettim		; read DOS tod clock
	int	dos			; ch=hours, cl=minutes, dh=seconds
	cmp	dh,lastsec		; compare with previous call
	mov	lastsec,dh		; remember last sec
	je	clkdsp9			; e = same, do nothing
	cmp	vtclkflg,1		; do regular time of day?
	je	clkdsp6			; e = yes
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
ifndef	no_tcp
	cmp	flags.comflg,'t'	; doing TCP/IP Telnet?
	je	clkdsp4			; e = yes
endif	; no_tcp
	sub	ax,word ptr starttime[bx]
	sbb	dx,word ptr starttime[bx+2]
	jns	clkdsp5			; ns = not wrapped
	add	ax,20864		; add one day
	adc	dx,1			; of 86400 seconds
	jmp	short clkdsp5
clkdsp4:
ifndef no_tcp
	mov	bx,sescur		; current session ident
	shl	bx,1
	shl	bx,1			; quad bytes
	sub	ax,word ptr sestime[bx]
	sbb	dx,word ptr sestime[bx+2]
	jns	clkdsp5			; ns = not wrapped
	add	ax,20864		; add one day
	adc	dx,1			; of 86400 seconds
endif	; no_tcp
clkdsp5:mov	cx,60*60		; convert seconds back to ch,cl,dh
	div	cx			; ax = quo = hours, dx = rem = secs
	mov	ch,al			; ch has hours
	mov	ax,dx			; remaining seconds to ax
	mov	cl,60
	div	cl			; al = quo = minutes, ah = secs
	mov	cl,al			; minutes
	xchg	dh,ah			; seconds to dh

clkdsp6:mov	ax,tv_segs		; screen segment
	mov	es,ax
	mov	al,crt_cols		; typically 80
	mul	crt_lins		; typically 24
	mov	bx,65+6			; led_col from mszibm.asm, dots
	sub	bl,handhsc		; minus hand scrolling left
	sbb	bh,0
	jc	clkdsp4			; c = off screen
	add	ax,bx
	shl	ax,1			; char cells
	mov	bx,ax

	mov	al,ch			; hours
	xor	ah,ah
	div	ten			; al = quo, ah=rem
	add	ax,'00'
	mov	es:[bx],al
	mov	es:[bx+2],ah
	mov	es:[bx+4],al
	mov	al,' '
	test	dh,1			; odd seconds?
	jnz	clkdsp8			; nz = yes, show blank
	mov	al,':'			; show colon
clkdsp8:mov	es:[bx+4],al
	mov	al,cl
	xor	ah,ah
	div	ten			; quo = al, rem = ah
	add	ax,'00'
	mov	es:[bx+6],al
	mov	es:[bx+8],ah
	push	di
	mov	di,bx			; es:di is start address
	add	di,9			; is now ending address
	mov	cx,5			; bytes changed
	call	scrsync			; sync virtual screen
	pop	di
clkdsp9:call	cbrestore		; restore Control-Break sensing
	pop	es
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
clkdsp	endp
code1	ends

code	segment
	assume	cs:code
;;; Action routines (verbs) for keyboard translator KEYBD in msuibm.
; These are invoked by a jump instruction. Return carry clear for normal
; processing, return carry set for invoking Quit (kbdflg has transfer char).
uparrw:	mov	al,'A'			; cursor keys
	jmp	short comarr
dnarrw:	mov	al,'B'
	jmp	short comarr
rtarr:	mov	al,'C'
	test	vtemu.vtflgop,vswdir	; writing left to right?
	jz	comarr			; z = yes
	mov	al,'D'			; reverse sense of keys
	jmp	short comarr
lfarr:	mov	al,'D'
	test	vtemu.vtflgop,vswdir	; writing left to right?
	jz	comarr			; z = yes
	mov	al,'C'			; reverse sense of keys

comarr:	test	flags.vtflg,ttwyse	; Wyse-50?
	jnz	comar7			; nz = yes
	test	flags.vtflg,ttd463+ttd470+ttd217 ; D463/D470/D217?
	jz	comar4			; z = no
	cmp	dgd470mode,0		; in D470 ANSI mode?
	je	comar6			; e = no
	push	ax			; these send ESC [ <letter>
	mov	al,escape
	call	foutprt
	mov	al,'['
	call 	foutprt			; pop ax is done by comar3
	jmp	short comar3		; send the letter
comar6:	sub	al,'A'			; translate to DG 463/470/217 form
ifndef	no_graphics
	cmp	tekflg,tek_active+tek_sg ; in special graphics mode?
	jne	comar5			; ne = no
	test	dgcross,1		; DG crosshair active?
	jz	comar5			; z = no
	test	dgcross,2		; DG crosshair active for keypad?
	jz	comar5			; z = no
	mov	bx,offset dgcrostab	; use scan code table instead
	xlatb
	call	croshair		; send AL to graphics to move cursor
	ret
endif	; no_graphics

comar5:	mov	bx,offset dgcurtab	; VT to DG cursor code table
	xlatb
	push	ax			; setup for comar3
	jmp	short comar3

comar7:	mov	bx,offset wysecurtab	; VT to Wyse-50 code table
	sub	al,'A'			; remove bias
	xlatb
	push	ax
	jmp	short comar3

comar4:	push	ax			; save final char
	mov	ttyact,0		; network, group chars for packet
	mov	al,Escape		; send the ESC
	test	vtemu.vtflgop,decanm	; ANSI mode?
	jz	comar1			; z = no
	mov	al,CSI			; CSI character
	test	vtemu.vtflgop,decckm	; cursor keys in application mode?
	jz	comar1			; z = no, in cursor mode
	mov	al,SS3			; SS3 character
comar1:	call	outprt_key		; send in 7 or 8 bit form, with echo
comar3: pop	ax			; recover final char
	mov	ttyact,1		; network, restore tty active flag
	call	foutprt
	ret

pf1:	mov	al,'P'			; keypad function keys PF1-4
	jmp	short compf
pf2:	mov	al,'Q'
	jmp	short compf
pf3:	mov	al,'R'
	jmp	short compf
pf4:	mov	al,'S'
compf:	push	ax			; save final char
	mov	ttyact,0		; network, group chars for packet
	mov	al,Escape		; send the ESC
	test	vtemu.vtflgop,decanm	; ansi mode?
	jz	short compf2		; z = no
	mov	al,SS3 			; SS3, ESC O
compf2:	call	outprt_key		; send 7 or 8 bit version
compf1: pop	ax			; get the saved char
	mov	ttyact,1		; network, restore tty active flag
	call	foutprt
	ret

ignore_key:				; key is to be ignored
	ret

kp0:	mov	al,'p'			; keypad numeric keys
	jmp	short comkp
kp1:	mov	al,'q'
	jmp	short comkp
kp2:	mov	al,'r'
	jmp	short comkp
kp3:	mov	al,'s'
	jmp	short comkp
kp4:	mov	al,'t'
	jmp	short comkp
kp5:	mov	al,'u'
	jmp	short comkp
kp6:	mov	al,'v'
	jmp	short comkp
kp7:	mov	al,'w'
	jmp	short comkp
kp8:	mov	al,'x'
	jmp	short comkp
kp9:	mov	al,'y'
	jmp	short comkp
kpminus:mov	al,'m'
	jmp	short comkp
kpcoma:	mov	al,'l'
	jmp	short comkp
kpenter:mov	al,'M'
	jmp	short comkp
kpdot:	mov	al,'n'
comkp:	test	vtemu.vtflgop,deckpam	; keypad application mode active?
	jnz	comkp1			; nz = yes, use escape sequences
	sub	al,40h			; deduct offset to numeric symbols
	push	ax			; save final char
	jmp	short comkp3		; and send that single char
comkp1:	push	ax
	mov	ttyact,0		; network, group chars for packet
	test	vtemu.vtflgop,decanm	; ANSI mode?
	jz	comkp2			; z = no
	mov	al,SS3			; SS3 character
	call	outprt_key		; send 7 or 8 bit version
	jmp	short comkp3
comkp2:	mov	al,escape		; output "ESC ?"
	call	foutprt
	mov	al,'?'
	call	foutprt
comkp3:	pop	ax			; recover final char
	mov	ttyact,1		; network, restore tty active flag
	call	foutprt			; send it
	ret

klogon	proc	near			; resume logging (if any)
	test	flags.capflg,logses	; session logging enabled?
	jz	klogn			; z = no, forget it
	push	bx
	mov	bx,argadr
	or	[bx].flgs,capt		; turn on capture flag
	pop	bx
	or	yflags,capt		; set local msy flag as well
klogn:	clc
	ret
klogon	endp

klogof	proc	near			; suspend logging (if any)
	push	bx
	mov	bx,argadr
	and	[bx].flgs,not capt	; stop capturing
	pop	bx
	and	yflags,not capt		; reset local msy flag as well
	clc
	ret
klogof	endp

kdebug	proc	near
	xor	flags.debug,logses	; toggle debugging
	xor	yflags,trnctl		; Debug mode local edition
	ret
kdebug	endp

snull	proc	near			; send a null byte
	xor	al,al			; the null
	call	fprtbout		; send without logging and local echo
	ret
snull	endp

khold:	xor	holdscr,1		; toggle Hold screen byte for msx
	call	kbhold			; tell DEC LK250 the hold kbd state
	clc				;  kbhold is in file msuibm.asm
	ret

tn_AYT:	mov	ah,255			; 'I' Telnet Are You There
	call	outchr			; send IAC (255) AYT (246)
	mov	ah,246
	call	outchr
	clc
	ret

tn_IP:	mov	ah,255			; 'I' Telnet Interrrupt Process
	call	outchr			; send IAC (255) IP (244)
	mov	ah,244
	call	outchr
	clc
	ret

; Data General "Fn" function keys
dgkf1:	mov	al,113			; F1 sends RS q
	jmp	dgkeyccom
dgkf2:	mov	al,114			; F2 sends RS r
	jmp	dgkeyccom
dgkf3:	mov	al,115			; F3 sends RS s
	jmp	dgkeyccom
dgkf4:	mov	al,116			; F4 sends RS t
	jmp	short dgkeyccom
dgkf5:	mov	al,117			; F5 sends RS u
	jmp	short dgkeyccom
dgkf6:	mov	al,118			; F6 sends RS v
	jmp	short dgkeyccom
dgkf7:	mov	al,119			; F7 sends RS w
	jmp	short dgkeyccom
dgkf8:	mov	al,120			; F8 sends RS x
	jmp	short dgkeyccom
dgkf9:	mov	al,121			; F9 sends RS y
	jmp	short dgkeyccom
dgkf10:	mov	al,122			; F10 sends RS z
	jmp	short dgkeyccom
dgkf11:	mov	al,123			; F11 sends RS {
	jmp	short dgkeyccom
dgkf12:	mov	al,124			; F12 sends RS |
	jmp	short dgkeyccom
dgkf13:	mov	al,125			; F13 sends RS }
	jmp	short dgkeyccom
dgkf14:	mov	al,126			; F14 sends RS ~
	jmp	short dgkeyccom
dgkf15:	mov	al,112			; F15 sends RS p
	jmp	short dgkeyccom
dgkSf1:	mov	al,'a'			; SF1 sends RS a
	jmp	short dgkeyccom
dgkSf2:	mov	al,'b'			; SF2 sends RS b
	jmp	short dgkeyccom
dgkSf3:	mov	al,'c'			; SF3 sends RS c
	jmp	short dgkeyccom
dgkSf4:	mov	al,'d'			; SF4 sends RS d
	jmp	short dgkeyccom
dgkSf5:	mov	al,'e'			; SF5 sends RS e
	jmp	short dgkeyccom
dgkSf6:	mov	al,'f'			; SF6 sends RS f
	jmp	short dgkeyccom
dgkSf7:	mov	al,'g'			; SF7 sends RS g
	jmp	short dgkeyccom
dgkSf8:	mov	al,'h'			; SF8 sends RS h
	jmp	short dgkeyccom
dgkSf9:	mov	al,'i'			; SF9 sends RS i
	jmp	short dgkeyccom
dgkSf10:mov	al,'j'			; SF10 sends RS j
	jmp	short dgkeyccom
dgkSf11:mov	al,'k'			; SF11 sends RS k
	jmp	short dgkeyccom
dgkSf12:mov	al,'l'			; SF12 sends RS l
	jmp	short dgkeyccom
dgkSf13:mov	al,'m'			; SF13 sends RS m
	jmp	short dgkeyccom
dgkSf14:mov	al,'n'			; SF14 sends RS n
	jmp	short dgkeyccom
dgkSf15:mov	al,'`'			; SF15 sends RS `
	jmp	short dgkeyccom


; Data General "C" keys C1..C4
dgkc1:	mov	al,92			; C1 sends RS \
	jmp	short dgkc5
dgkc2:	mov	al,93			; C2 sends RS ]
	jmp	short dgkc5
dgkc3:	mov	al,95			; C3 sends RS ^
	jmp	short dgkc5
dgkc4:	mov	al,96			; C4 sends RS _
dgkc5:	cmp	dgd470mode,0		; D470 ANSI mode active?
	je	dgkeyccom		; e = no
	add	al,40			; yes, bias, C1=132 et seq
dgkeyccom:				; common code
	mov	ttyact,0		; network, group chars for packet
	push	ax
	cmp	dgd470mode,0		; D470 ANSI mode active?
	je	dgkeyccom1		; e = no
	mov	al,ESCAPE		; send ESC [ 0<high><low> z
	call	fprtbout
	mov	al,'['
	call	fprtbout
	mov	al,'0'			; first byte, always "0"
	call	fprtbout
	pop	ax
	sub	al,112			; remove bias (to 0..23)
	mov	cl,10			; split into two bytes
	xor	ah,ah
	div	cl			; al = quotient, ah = remainder
	push	ax			; save remainder
	add	al,'0'			; send high part (0..2)
	call	fprtbout
	pop	ax
	xchg	ah,al
	add	al,'0'			; send low part (0..9)
	call	fprtbout
	mov	al,'z'			; terminator
	mov	ttyact,1		; network, restore tty active flag
	ret

dgkeyccom1:mov	al,DGescape		; send DG escape (RS)
	call	fprtbout		; with no echo
	pop	ax
	mov	ttyact,1		; network, restore tty active flag
	call	fprtbout		; send the second byte
	ret

; Keyboard "Compose" key to compose characters by the three stroke method
kbdcompose proc	near
	mov	grab,1			; say grabbing normal output
	call	togmod
	call	togmod			; update mode line
	ret
kbdcompose endp

; DG POINT (aka CMD CURSOR-TYPE)
dgpoint	proc	near
ifndef	no_graphics
	cmp	tekflg,tek_active+tek_sg ; special graphics mode?
	jne	dgpoint1		; ne = no, ignore cmd
	call	dgcrossrpt		; send crosshair report
endif	; no_graphics
dgpoint1:ret
dgpoint	endp

; DG N/C (normal, compressed font) key
dgnckey proc	near
	test	flags.vtflg,ttd463+ttd470+ttd217 ; D463/D470/D217?
	jz	dgnckey1		; z = no, ignore
	call	dgnctoggle		; toggle normal/compressed mode
dgnckey1:clc
	ret
dgnckey endp

; Compose char lookup and reemitter.
fgrabber proc	far
	push	bx
	mov	bx,grab			; count chars grabbed (want two)
	dec	bx			; first char becomes bx=0
	mov	grabbox[bx],al		; stuff char in short buffer
	cmp	bx,1			; got both chars?
	pop	bx
	jae	fgrab2			; ae = yes, go produce output
	inc	grab			; keep grabbing
	ret				; return for the second
					; process the byte pair
fgrab2:	mov	grab,0			; say done grabbing output
	push	dx			; compose new single char result
	push	di
	push	es
	mov	di,seg data1
	mov	es,di
	mov	di,offset grl1lat	; use Latin1 ptr
	cmp	vtcpage,852		; CP852?
	jne	fgrab2a			; ne = no
	mov	di,offset grl1lat2	; use Latin 2
fgrab2a:test	flags.vtflg,ttd463+ttd470+ttd217 ; D463/D470/D217?
	jz	fgrab3			; z = no
	cmp	dgkbl,16		; Latin1?
	je	fgrab3			; e = yes
	mov	di,offset grl1dgi	; get DG Internat ptr to structure
	cmp	dgkbl,20		; DG keyboard language, DG Internat?
	jne	fgrab15			; ne = no
fgrab3:	mov	ax,word ptr grabbox	; get pair of chars
	call	toupr			; convert AX to upper case
	call	match
	jnc	fgrab11			; nc = found
	xchg	ah,al
	call	match
	jnc	fgrab11			; nc = match

fgrab5:	mov	di,offset grl2lat	; use Latin1 ptr
	cmp	vtcpage,852		; CP852?
	jne	fgrab5a			; ne = no
	mov	di,offset grl2lat2	; use Latin 2
fgrab5a:test	flags.vtflg,ttd463+ttd470+ttd217 ; D463/D470/D217?
	jz	fgrab6			; z = no
	cmp	dgkbl,16		; Latin1?
	je	fgrab6			; e = yes
	mov	di,offset grl2dgi	; get DG Internat ptr to structure
	cmp	dgkbl,20		; DG keyboard language, DG Internat?
	jne	fgrab15			; ne = no
fgrab6:	mov	ax,word ptr grabbox
	mov	dx,ax
	cmp	vtcpage,852		; CP852?
	je	fgrab6a			; e = yes, use as-is
	call	toupr			; convert AX to upper case
fgrab6a:call	match
	jnc	fgrab7			; nc = found
	xchg	ah,al			; try reversed order
	xchg	dh,dl
	call	match
	jc	fgrab8			; c = not found
fgrab7:	cmp	vtcpage,852		; CP852?
	je	fgrab11			; e = yes, output as-is
	cmp	dl,'a'			; lower case char?
	jb	fgrab11			; b = no, upper case
	or	al,20h			; move to lower case output codes
	jmp	short fgrab11

fgrab8:	mov	di,offset grl3lat	; use Latin1 ptr
	cmp	vtcpage,852		; CP852?
	jne	fgrab8a			; ne = no
	mov	di,offset grl3lat2	; use Latin 2
fgrab8a:test	flags.vtflg,ttd463+ttd470+ttd217 ; D463/D470/D217?
	jz	fgrab9			; z = no
	cmp	dgkbl,16		; Latin1?
	je	fgrab9			; e = yes
	mov	di,offset grl3dgi	; get DG Internat ptr to structure
	cmp	dgkbl,20		; DG keyboard language, DG Internat?
	jne	fgrab15			; ne = no
fgrab9:	mov	ax,word ptr grabbox
	xchg	ah,al
	call	match			; look for matching combination
	jc	fgrab16			; c = failed
fgrab11:call	foutprt			; send it to the host
fgrab15:call	togmod
	call	togmod			; update mode line
	pop	es
	pop	di
	pop	dx
	ret

fgrab16:call	fvtbell			; mismatch, beep, cancel
	jmp	short fgrab15		;  finish up
fgrabber endp

					; worker for above
match	proc	near
	push	bx
	push	si
	push	di
	mov	cl,es:[di]		; get count of pairs
	xor	ch,ch
	inc	di
	mov	si,di			; start of char lists
	jcxz	match2			; nothing to look at
	mov	si,di			; remember where pairs start
	mov	bx,di
	add	bx,cx
	add	bx,cx			; output singles start here
	cld
	push	cx			; save counter
	repne	scasw			; look for a match
	pop	cx
	jne	match2			; ne = no match
	sub	di,2			; backup to match
	sub	di,si			; get item count
	shr	di,1			; count bytes
	mov	al,es:[bx+di]		; get new output char
	pop	di
	pop	si
	pop	bx
	clc				; say success
	ret
match2:	pop	di
	pop	si
	pop	bx
	stc				; say no match
	ret
match	endp

; DEC LK201 keyboard keys and "User Definable Keys" in VT3xx mode
decfind:mov	al,1			; Find
	jmp	dfkout
decinsert:mov	al,2			; Insert
	jmp	dfkout
decremove:mov	al,3			; Remove
	jmp	dfkout
decselect:mov	al,4			; Select
	jmp	dfkout
decprev:mov	al,5			; Previous screen
	jmp	dfkout
decnext:mov	al,6			; Next screen
	jmp	dfkout
decf6:	mov	al,17			; key ident for DEC F6
	jmp	dfkout			; process it
decf7:	mov	al,18			; key ident for DEC F7
	jmp	dfkout			; process it
decf8:	mov	al,19			; key ident for DEC F8
	jmp	dfkout			; process it
decf9:	mov	al,20			; key ident for DEC F9
	jmp	dfkout			; process it
decf10:	mov	al,21			; key ident for DEC F10
	jmp	dfkout			; process it
decf11:	mov	al,23			; key ident for DEC F11
	jmp	dfkout			; process it
decf12:	mov	al,24			; key ident for DEC F12
	jmp	dfkout			; process it
decf13:	mov	al,25			; key ident for DEC F13
	jmp	dfkout			; process it
decf14:	mov	al,26			; key ident for DEC F14
	jmp	dfkout			; process it
dechelp:mov	al,28			; key ident for DEC HELP
	jmp	dfkout			; process it
decdo:	mov	al,29			; key ident for DEC DO
	jmp	dfkout			; process it
decf17:	mov	al,31			; key ident for DEC F17
	jmp	dfkout			; process it
decf18:	mov	al,32			; key ident for DEC F18
	jmp	dfkout			; process it
decf19:	mov	al,33			; key ident for DEC F19
	jmp	dfkout			; process it
decf20:	mov	al,34			; key ident for DEC F20
	jmp	dfkout			; process it

; common worker to output contents of User Definable Key definition strings
; Enter with al = key ident (17 - 34)
dfkout	proc	near
	push	ax
	push	bx
	push	cx
	push	es
	mov	ttyact,0		; network, group chars for packet
	test	flags.vtflg,ttvt320+ttvt220 ; VT320/VT220?
	jnz	dfkout4			; nz = yes, else use VT100/VT52 default
	test	flags.vtflg,tttek	; Tek?
	jnz	dfkout4			; nz = yes, try this
	mov	ttyact,1		; network, restore tty active flag
	cmp	al,23			; F11 sends ESC
	jne	dfkou1			; ne = not F11
	mov	al,escape
	call	foutprt
	jmp	dfkoutx
dfkou1:	cmp	al,24			; F12 sends BS
	jne	dfkou2			; ne = not F12
	mov	al,BS
	call	foutprt
	jmp	dfkoutx
dfkou2:	cmp	al,25			; F13 sends LF
	jne	dfkoutx			; ne = not F13, ignore
	mov	al,LF
	call	foutprt
dfkou3:	jmp	dfkoutx

dfkout4:push	ax			; VT320, use default definitions
	mov	al,Escape		; char to send, CSI
	call	foutprt
	mov	al,'['
	call	foutprt			; send lead-in char in 7/8-bit form
	pop	ax
	call	fprtnout		; key ident (17-34) as ascii digits
	mov	al,7eh			; tilde terminator
	mov	ttyact,1		; network, restore tty active flag
	call	foutprt
dfkoutx:pop	es
	pop	cx
	pop	bx
	pop	ax
	clc
	ret
dfkout	endp

; User Definable Keys
udkf6:	mov	al,17			; key ident for DEC F6
	jmp	udkout			; process it
udkf7:	mov	al,18			; key ident for DEC F7
	jmp	udkout			; process it
udkf8:	mov	al,19			; key ident for DEC F8
	jmp	udkout			; process it
udkf9:	mov	al,20			; key ident for DEC F9
	jmp	udkout			; process it
udkf10:	mov	al,21			; key ident for DEC F10
	jmp	udkout			; process it
udkf11:	mov	al,23			; key ident for DEC F11
	jmp	udkout			; process it
udkf12:	mov	al,24			; key ident for DEC F12
	jmp	udkout			; process it
udkf13:	mov	al,25			; key ident for DEC F13
	jmp	udkout			; process it
udkf14:	mov	al,26			; key ident for DEC F14
	jmp	udkout			; process it
udkf15:	mov	al,28			; key ident for DEC HELP
	jmp	udkout			; process it
udkf16:	mov	al,29			; key ident for DEC DO
	jmp	udkout			; process it
udkf17:	mov	al,31			; key ident for DEC F17
	jmp	udkout			; process it
udkf18:	mov	al,32			; key ident for DEC F18
	jmp	udkout			; process it
udkf19:	mov	al,33			; key ident for DEC F19
	jmp	udkout			; process it
udkf20:	mov	al,34			; key ident for DEC F20
;	jmp	udkout			; process it

udkout	proc	near
	push	es
	mov	ttyact,0		; network, group chars for packet
	mov	bl,al			; VT3XX key ident, UDK style (17-34)
	sub	bl,17			; minus starting offset of 17
	xor	bh,bh
	cmp	bl,17			; out of range?
	ja	udkoutx			; a = yes, ignore
	shl	bx,1			; index words
	mov	bx,udkseg[bx]		; segment of definition
	or	bx,bx			; anything there?
	jz	udkoutx			; z = no
	mov	es,bx			; definition segment
	xor	bx,bx			;  and offset
	mov	cl,es:[bx]		; get string length byte
	xor	ch,ch			; use cx as a counter
	jcxz	udkoutx			; z = empty
udkou1:	inc	bx			; es:bx is now the string text
	mov	al,es:[bx]		; get a char
	push	bx
	push	cx
	push	es
	cmp	cx,1			; last byte
	jne	udkou2			; ne = not last byte
	mov	ttyact,1		; network, restore tty active flag
udkou2:	call	foutprt			; output
	pop	es
	pop	cx
	pop	bx
	loop	udkou1
udkoutx:pop	es
	clc
	ret
udkout	endp
					; Wyse-50 function keys F1..F16
wykf1:	mov	al,'@'			; Wyse F1
	jmp	short wykfcom
wykf2:	mov	al,'A'			; Wyse F2
	jmp	short wykfcom
wykf3:	mov	al,'B'
	jmp	short wykfcom
wykf4:	mov	al,'C'
	jmp	short wykfcom
wykf5:	mov	al,'D'
	jmp	short wykfcom
wykf6:	mov	al,'E'
	jmp	short wykfcom
wykf7:	mov	al,'F'
	jmp	short wykfcom
wykf8:	mov	al,'G'
	jmp	short wykfcom
wykf9:	mov	al,'H'
	jmp	short wykfcom
wykf10:	mov	al,'I'
	jmp	short wykfcom
wykf11:	mov	al,'J'
	jmp	short wykfcom
wykf12:	mov	al,'K'
	jmp	short wykfcom
wykf13:	mov	al,'L'
	jmp	short wykfcom
wykf14:	mov	al,'M'
	jmp	short wykfcom
wykf15:	mov	al,'N'
	jmp	short wykfcom
wykf16:	mov	al,'O'			; Wyse F16
	jmp	short wykfcom
					; Wyse-50 Shift function keys F1..F16
wykSf1:	mov	al,'`'			; Wyse Shift F1
	jmp	short wykfcom
wykSf2:	mov	al,'a'			; Wyse Shift F2
	jmp	short wykfcom
wykSf3:	mov	al,'b'
	jmp	short wykfcom
wykSf4:	mov	al,'c'
	jmp	short wykfcom
wykSf5:	mov	al,'d'
	jmp	short wykfcom
wykSf6:	mov	al,'e'
	jmp	short wykfcom
wykSf7:	mov	al,'f'
	jmp	short wykfcom
wykSf8:	mov	al,'g'
	jmp	short wykfcom
wykSf9:	mov	al,'h'
	jmp	short wykfcom
wykSf10:mov	al,'i'
	jmp	short wykfcom
wykSf11:mov	al,'j'
	jmp	short wykfcom
wykSf12:mov	al,'k'
	jmp	short wykfcom
wykSf13:mov	al,'l'
	jmp	short wykfcom
wykSf14:mov	al,'m'
	jmp	short wykfcom
wykSf15:mov	al,'n'
	jmp	short wykfcom
wykSf16:mov	al,'o'			; Wyse Shift F16

wykfcom:mov	ttyact,0		; network, group chars for packet
	push	ax			; save key code
	mov	al,1			; send SOH keycode CR
	call	foutprt
	pop	ax
	call	foutprt
	mov	al,CR
	mov	ttyact,1		; network, restore tty active flag
	call	foutprt
	ret

; Change Telnet sessions
ifndef	no_tcp
ses1	proc	near
	mov	bx,0
	mov	cx,1
	jmp	short nextses4
ses1	endp
ses2	proc	near
	mov	bx,1
	mov	cx,1
	jmp	short nextses4
ses2	endp
ses3	proc	near
	mov	bx,2
	mov	cx,1
	jmp	short nextses4
ses3	endp
ses4	proc	near
	mov	bx,3
	mov	cx,1
	jmp	short nextses4
ses4	endp
ses5	proc	near
	mov	bx,4
	mov	cx,1
	jmp	short nextses4
ses5	endp
ses6	proc	near
	mov	bx,5
	mov	cx,1
	jmp	short nextses4
ses6	endp
endif	; no tcp

nextses proc	near
ifndef	no_tcp
	cmp	flags.comflg,'t'	; doing Telnet?
	je	nextses1		; e = yes
	clc				; do not exit Connect mode
	ret
nextses1:mov	bx,sescur		; current session ident
	mov	cx,6			; sessions to consider
nextses3:inc	bx
	cmp	bx,6			; over the top yet
	jb	nextses4		; b = no
	xor	bx,bx			; wrap
nextses4:cmp	seslist[bx],0		; is this session active?
	jge	nextses5		; ge = yes
	loop	nextses3
	clc
	ret				; do nothing

nextses5:push	bx
	mov	bx,sescur		; old session
	call	termswapout		; save current terminal items
	pop	bx
	mov	sescur,bx		; next session, from above
	call	tcpstart		; start session, ident in bl
	mov	bx,sescur		; new session
	call	termswapin		; get data structures
	mov	kbdflg,' '		; return Connect mode
	stc				; but exit Connect mode now
else
	clc
endif	; no_tcp
	ret
nextses endp

vtsesmac  proc	far			; SESSION macro
	mov	vtmacname,offset vtsesname
	mov	al,bl			; session number
	add	al,'1'			; to ascii, from 1
	mov	vtsesnum,al		; to name
	mov	vtmaclen,vtseslen
	call	dword ptr vtmacroptr	; FAR pointer
	ret
vtsesmac endp

; Call from mszibm DG components to put system into DG special graphics mode,
; and thus to cause incoming material to be still sent to the text emulator.
; This also unshifts the screen (as seen on the status line) before starting
; graphics so the column 81 stuff comes out right.
dgsettek proc	far
ifndef	no_graphics
	cmp	tekflg,tek_active+tek_sg ; inited already?
	je	dgsettek3		; e = yes
	push	bx
	push	cx
	mov	cl,byte ptr low_rgt+1	; examine whole screen
	inc	cl			; lines in emulation part
	xor	ch,ch
	mov	bx,cx			; for status line
	xor	al,al
	xchg	al,linescroll[bx]	; status line scroll value
	or	al,al
	jz	dgsettek2		; z = no shift in effect
	xor	bx,bx			; start of screen
dgsettek1:sub	linescroll[bx],al	; unscroll by status line amount
	inc	bx			; next line
	loop	dgsettek1		; do all emulation lines
dgsettek2:pop	cx
	pop	bx
	or	tekflg,tek_sg		; set special graphics mode
	call	TEKINI			; go to Tektronix Emulator
endif	; no_graphics
dgsettek3:ret
dgsettek endp

;[HF]940206 jpnxltkey
;[HF]940207
;[HF]940206 Check if leading byte of Japanese double byte code
;[HF]940207 Range of Japanese second byte
;[HF]940207 ((AL >= 0x40) && (AL <= 0x7e))||((AL >= 0x80) && (AL <= 0xfc))
;[HF]940207
;[HF]940206 If not Japanese, clear carry and return.
;[HF]940207
jpnxltkey	proc	near		;[HF]940206
	cmp	keypend,0		;[HF]940207 Kanji second byte?
	jne	jpnxltk3		;[HF]940207 ne = yes, second byte
	call	iskanji1		;[HF]941010 Kanji leading byte ?
	jc	jpnxltk2		;[HF]941010 c = yes
	call	iskana			;[HF]941010 Katakana ?
	jnc	jpnxltk1		;[HF]941010 nc = no
	cmp	flags.oshift,(128+3)	;[HF]941012 DEC-Kanji ?
	je	jpnxltk1c		;[HF]941012 e = yes, use X208 Katakana
	cmp	flags.oshift,(128+2)	;[HF]941012 EUC-Kanji ?
	jne	jpnxltk1b		;[HF]941012 ne = no
	call	outkana			;[HF]941011 katakana output
	mov	keypend,0		;[HF]941011 no pending char
	stc				;[HF]941011 say, we have done
	ret				;[HF]941011
jpnxltk1b:				;[HF]941011
	cmp	flags.oshift,(128+1)	;[HF]941012 JIS7-Kanji ?
	jne	jpnxltk1a		;[HF]941012 ne = no
jpnxltk1c:				;[HF]941012
	call	dblkana			;[HF]941012 get double byte code
	or	ax,8080h		;[HF]941012 make it GR
	mov	keypend,ax		;[HF]941012
	jmp	jpnxltk5c		;[HF]941012
jpnxltk1:				;[HF]940207
	cmp	flags.oshift,(128+1)	;[HF]940211 JIS7?
	jne	jpnxltk1a		;[HF]940211 ne = no
	cmp	keyj7st,0		;[HF]940211 ASCII state?
	je	jpnxltk1a		;[HF]940211 e = yes
	push	ax			;[HF]940211
	mov	al,ESCAPE		;[HF]940211
	call	chrout			;[HF]940211
	mov	al,'('			;[HF]940211
	call	chrout			;[HF]940211
	mov	al,byte ptr jis7des+1	;[HF]940211
	call	chrout			;[HF]940211
	mov	keyj7st,0		;[HF]940211
	pop	ax			;[HF]940211
jpnxltk1a:				;[HF]940211
	mov	keypend,0		;[HF]940207 Clear second byte flag
	clc				;[HF]940206 tell that not Japanese
	ret				;[HF]940206
jpnxltk2:				;[HF]940206
	push	ax			;[HF]940207
	mov	ah,al			;[HF]940207
	xor	al,al			;[HF]940207
	mov	keypend,ax		;[HF]940207 save it for later use
	pop	ax			;[HF]940207
	stc				;[HF]940206 tell that Japanese
	ret				;[HF]940206
jpnxltk3:				;[HF]940207
	cmp	al,40h			;[HF]940207
	jb	jpnxltk4		;[HF]940207 not the second byte
	cmp	al,7eh			;[HF]940207
	jbe	jpnxltk5		;[HF]940207 Yes second byte
	cmp	al,80h			;[HF]940207
	jb	jpnxltk4		;[HF]940207 not the second byte
	cmp	al,0fch			;[HF]940207
	jbe	jpnxltk5		;[HF]940207 Yes second byte
jpnxltk4:				;[HF]940207
	jmp	jpnxltk1		;[HF]940211 treat as single byte char.
jpnxltk5:				;[HF]940207
	mov	byte ptr keypend,al	;[HF]940207 make double byte code
	mov	ax,keypend		;[HF]940207 Shift-JIS code
	call	jpnftox			;[HF]940207 translate to EUC(JIS-GR)
jpnxltk5c:				;[HF]941012
	cmp	flags.oshift,(128+1)	;[HF]940211 JIS7?
	je	jpnxltk5a		;[HF]940211 e = yes
	cmp	flags.oshift,(128+2)	;[HF]940214 EUC?
	je	jpnxltk5b		;[HF]940214 e = yes
	cmp	flags.oshift,(128+3)	;[HF]941012 DEC?
	je	jpnxltk5b		;[HF]941012 e = yes
	mov	ax,keypend		;[HF]940214 No. use Shift-JIS code
	jmp	short jpnxltk5b		;[HF]940211
jpnxltk5a:				;[HF]940211
	and	ax,7f7fh		;[HF]940211
	cmp	keyj7st,2		;[HF]940211 Kanji state?
	je	jpnxltk5b		;[HF]940211 e=yes, no shift
	push	ax			;[HF]940211
	mov	al,ESCAPE		;[HF]940211
	call	chrout			;[HF]940211
	mov	al,'$'			;[HF]940211
	call	chrout			;[HF]940211
	mov	al,byte ptr jis7des	;[HF]940211
	call	chrout			;[HF]940211
	mov	keyj7st,2		;[HF]940211
	pop	ax			;[HF]940211
jpnxltk5b:				;[HF]940211
	push	ax			;[HF]940214 save dble byte code
	mov	al,ah			;[HF]940207
	call	chrout			;[HF]940207 send leading byte
	pop	ax			;[HF]940214 remember dble byte code
	mov	ah,al			;[HF]940207
	call	chrout			;[HF]940207 send second byte
	mov	keypend,0		;[HF]940207 clear double byte flag
	stc				;[HF]940207 say no more char
	ret				;[HF]940207
jpnxltkey	endp			;[HF]940206

;[HF]941011 outkana
;[HF]941011
;[HF]941011 Output Shift-JIS katakana code in AL to com port.
outkana	proc	near			;[HF]941011
	push	ax			;[HF]941011 save AX
	push	bx			;[HF]941011 save BX
	cmp	flags.oshift,(128+1)	;[HF]941012 JIS7 ?
	je	outkan1			;[HF]941012 e = yes
	mov	bl,flags.oshift		;[HF]941011 save output-shift
	mov	flags.oshift,0		;[HF]941011 Do our own shift
	mov	bh,al			;[HF]941011 save AL
	mov	al,SS2			;[HF]941011 SS2
	call	chrout			;[HF]941011
	mov	al,bh			;[HF]941011 restore AL
	or	al,80h			;[HF]941011 8th bit On
	call	chrout			;[HF]941011
	jmp	outkanx			;[HF]941012
outkan1:cmp	keyj7st,1		;[HF]941012 already in katakana mode?
	je	outkan3			;[HF]941012 e = yes
	cmp	keyj7st,2		;[HF]941012 in kanji mode?
	jne	outkan2			;[HF]941012 ne = no
	mov 	bh,al			;[HF]941012 save AL
	mov	al,ESCAPE		;[HF]941012
	call	chrout			;[HF]941012
	mov	al,'('			;[HF]941012
	call	chrout			;[HF]941012
	mov	al,byte ptr jis7des+1	;[HF]941012
	call	chrout			;[HF]941012
outkan2:mov	al,SOchar		;[HF]941012 SO
	call	chrout			;[HF]941012
	mov	keyj7st,1		;[HF]941012
	mov	al,bh			;[HF]941012
outkan3:and	al,7fh			;[HF]941012 mask 8th bit
	call	chrout			;[HF]941012
outkanx:mov	flags.oshift,bl		;[HF]941011 restore output-shift
	pop	bx			;[HF]941011 restore BX
	pop	ax			;[HF]941011 restore AX
	ret				;[HF]941011
outkana	endp				;[HF]941011

;[HF]941012 dblkana
;[HF]941012
;[HF]941012 convert single byte katakana code to double byte code
;[HF]941012 Input: AL Katakana code in JIS
;[HF]941012 Outpt: AX Double byte JIS katakana code (AH first)
dblkana	proc	near			;[HF]941012
	push	es
	push	bx			;[HF]941012
	sub	ax,32			;[HF]941012
	and	ax,3fh			;[HF]941012
	mov	bx,seg kanatbl
	mov	es,bx
	mov	bx,offset kanatbl	;[HF]941012
	add	bx,ax			;[HF]941012
	add	bx,ax			;[HF]941012 word address
	mov	ax,es:[bx]		;[HF]941012
	pop	bx			;[HF]941012
	pop	es
	ret				;[HF]941012
dblkana	endp				;[HF]941012

;[HF]941010 iskana
;[HF]941010
;[HF]941010 Check if AL is Shift-JIS Katakana code or not.
;[HF]941010 If Katakana, program returns with carry set,
;[HF]941010 if not, carry clear.
;[HF]941010
;[HF]941010 Note: Shift-JIS Katakana is in the range
;[HF]941010 ((AL >= 0xa0) && (AL <= 0xdf))
;[HF]941010 where AL = 0xa0 is space
;[HF]941010
iskana	proc	near			;[HF]941010
	cmp	al,0a0h			;[HF]941010
	jb	iskanan			;[HF]941010 b = no
	cmp	al,0dfh			;[HF]941010
	ja	iskanan			;[HF]941010 a = no
	stc				;[HF]941010 yes, katakana
	jmp	short iskanax		;[HF]941010
iskanan:clc				;[HF]941010 no, not katakana
iskanax:ret				;[HF]941010
iskana	endp				;[HF]941010

;[HF]940207 Range of Shift-JIS Kanji leading byte
;[HF]940207 ((AL >= 0x81) && (AL <= 0x9f))||((AL >= 0xe0) && (AL <= 0xfc))
iskanji1	proc	near		;[HF]941010
	cmp	al,81h			;[HF]940207
	jb	iskan1n			;[HF]940207 b = No, not Kanji leading
	cmp	al,9fh			;[HF]940207
	jbe	iskan1y			;[HF]940207 Yes, Japanese leading byte
	cmp	al,0e0h			;[HF]940207
	jb	iskan1n			;[HF]940207 No, not Japanese
	cmp	al,0fch			;[HF]940207
	jbe	iskan1y			;[HF]940207 Yes, Japanese leading byte
iskan1n:clc				;[HF]941010
	jmp	short iskan1x		;[HF]941010
iskan1y:stc				;[HF]941010
iskan1x:ret				;[HF]941010
iskanji1	endp			;[HF]941010

code	ends

code1	segment
	assume	cs:code1

; Set (define) the DEC "User Definable Keys". Inserts text definitions for
; keyboard verbs \KdecF6 ...\KdecF14, \KdecHELP, \KdecDO, \KdecF17...\KdecF20.
; Enter with the DCS definition string as key-number/hex-chars. UDK key number
; is 17 for \KdecF6, et seq, the definition are pairs of hex digits converted
; here to a single byte per pair. The DCS definition string is pointed at by
; DS:SI, and the byte count is in CX.
; Example:  17/54657374204636   means key \KdecF6 sends string "Test F6"
setudk	proc	near
	push	ax
	push	bx
	push	cx
	push	si
	push	di
	push	es
	cld
	lodsb				; get key ident first byte
	sub	al,'0'			; ascii to binary
	mul	ten			; times 10
	xchg	ah,al			; to ah
	lodsb				; get key ident second byte
	sub	al,'0'			; ascii to binary
	add	al,ah			; plus high order part
	xor	ah,ah
	mov	bx,ax			; key ident, 17 - 34
	lodsb				; skip slash separator
	sub	cx,3			; three less bytes in the string
	jge	setudk0			; ge = had three or more bytes
	jmp	setudkx			; else error
setudk0:sub	bx,17			; remove key ident bias of 17
	cmp	bx,17			; out of range?
	ja	setudkx			; a = yes, ignore
	shl	bx,1			; index words
	cmp	udkseg[bx],0		; has a segment been allocated for it?
	je	setudk1			; e = no
	mov	ax,udkseg[bx]		; get segment to es
	mov	es,ax
	mov	ah,freemem		; deallocate old memory block, es:0
	int	dos
	mov	udkseg[bx],0		; clear table entry too
setudk1:and	cl,not 1		; force an even number of inputs
	jcxz	setudkx			; z = no definition, clear entry
	push	bx			; save index BX
	mov	bx,cx			; get string length
	shr	bx,1			; two hex digits per final byte
	add	bx,15+1			; round up plus length byte
	shr	bx,1			; convert to paragraphs
	shr	bx,1
	shr	bx,1
	shr	bx,1
	mov	di,bx			; remember request
	mov	ah,alloc		; allocate BX paragraphs
	int	dos
	jc	setudkx			; c = failure
	cmp	di,bx			; requested vs allocated
	pop	bx			; recover bx
	je	setudk2			; e = enough
	mov	ah,freemem		; return the memory, es is ptr
	int	dos
	jmp	short setudkx		; exit failure

setudk2:mov	es,ax			; segment of allocated memory
	mov	udkseg[bx],ax		; segment:0 of definition string
	xor	di,di
	cld
	mov	al,cl			; length of string
	shr	al,1			; two hex bytes per stored byte
	xor	ch,ch
	stosb				; store length byte
	jcxz	setudkx			; z = empty string
setukd3:lodsb				; get first hex digit
	dec	cx			; adjust count remaining
	or	al,20h			; to lower case
	cmp	al,'9'			; digit?
	jbe	setudk4			; be = yes
	sub	al,'a'-'9'-1		; hex letter to column three
setudk4:sub	al,'0'			; ascii to binary
	shl	al,1			; times 16
	shl	al,1
	shl	al,1
	shl	al,1
	mov	ah,al			; save in ah
	lodsb				; get second hex digit
	or	al,20h			; to lower case
	cmp	al,'9'			; digit?
	jbe	setudk5			; be = yes
	sub	al,'a'-'9'-1		; hex letter to column three
setudk5:sub	al,'0'			; ascii to binary
	add	al,ah			; join both parts
	stosb				; store final byte
	loop	setukd3
setudkx:pop	es
	pop	di
	pop	si
	pop	cx
	pop	bx
	pop	ax
	clc
	ret
setudk	endp

; Clear all User Definable Keys, deallocate memory for their definitions
udkclear proc	near
	push	ax
	push	bx
	push	cx
	push	es
	mov	cx,17			; 17 entries
	xor	bx,bx
udkcle1:mov	ax,udkseg[bx]		; segment of definition
	or	ax,ax			; segment defined?
	jz	udkcle2			; z = no, try next key
	mov	es,ax
	mov	udkseg[bx],0		; clear the entry
	mov	ah,freemem		; release the memory
	int	dos
udkcle2:add	bx,2			; word index
	loop	udkcle1			; do all
	pop	es
	pop	cx
	pop	bx
	pop	ax
	clc
	ret
udkclear endp

fsetpos	proc	far
	call	setpos
	ret
fsetpos	endp

frepaint proc	far
	call	repaint
	ret
frepaint endp
code1	ends

code	segment
	assume	cs:code
					; these commands invoke Quit
cdos:	mov	al,'P'			; Push to DOS
	jmp	short cmdcom
cstatus:mov	al,'S'			; Status
	jmp	short cmdcom
cquit:	mov	al,'C'			; Exit Connect mode
	jmp	short cmdcom
cquery:	mov	al,'?'			; Help
	jmp	short cmdcom
chang:	mov	al,'H'			; Hangup, drop DTR & RTS
	jmp	short cmdcom
cmdcom:	mov	kbdflg,al		; pass char to msster.asm via kbdflg
	stc				; signal that Quit is needed
	ret
					; general character out for emulator
chrout	proc	near
	cmp	flags.vtflg,0		; emulating?
	je	chrou5			; e = no
	call	fanskbi			; say we had keyboard input
	cmp	al,cr			; CR?
	jne	chrou5			; ne = no, just output it and return
	test	vtemu.vtflgop,anslnm	; ANSI new-line mode set?
	jz	chrou5			; z = no, just send the cr
	cmp	dupflg,0		; full duplex?
	je	chrou4			; e = yes
	cmp	al,trans.seol		; End of Line char?
	jne	chrou5			; ne = no
chrou4:	mov	ah,trans.seol		; save eol char
	push	ax			; save on stack
	mov	trans.seol,lf		; make LF the eol char
	call	foutprt			; output a carriage-return
	mov	al,lf			; followed by a line feed
	call	foutprt			; send the LF
	pop	ax
	mov	trans.seol,ah		; restore eol char
	ret
chrou5:	call	foutprt
	ret
chrout	endp

   					; Screen dump entry from keyboad xlat
dmpscn	proc	near			; dump screen to file
ifndef	no_graphics
	cmp	flags.vtflg,tttek	; doing Tektronix emulation?
	je	dmpscn2			; e = yes, use Tek emulator
	cmp	tekflg,tek_active+tek_dec ; emulation a Tektronix?
	jne	dmpscn1			; ne = no
dmpscn2:call	tekdmp			; near-call Tek screen dump utility
	clc
	ret
endif	; no_graphics

dmpscn1:call	dumpscr			; do buffer to file
	clc				; do not exit Connect mode
	ret
dmpscn	endp

; Save the screen to a buffer and then append buffer to a disk file. [jrd]
; Default filename is Kermit.scn; actual file can be a device too. Filename
; is determined by mssset and is passed as pointer dmpname.
; Dumpscr reads the screen image saved in vscreen.

dumpscr proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	mov	dmphand,-1		; preset illegal handle
	mov	dx,offset dmpname	; name of disk file, from mssset
	mov	ax,dx			; where isfile wants name ptr
	call	isfile			; what kind of file is this?
	jc	dmp5			; c = no such file, create it
	test	byte ptr filtst.dta+21,1fh ; file attributes, ok to write?
	jnz	dmp0			; nz = no.	
	mov	al,1			; writing
	mov	ah,open2		; open existing file
	int	dos
	jc	dmp0			; c = failure
	mov	dmphand,ax		; save file handle
	mov	bx,ax			; need handle here
	mov	cx,0ffffh		; setup file pointer
	mov	dx,-1			; and offset
	mov	al,2			; move to eof minus one byte
	mov	ah,lseek		; seek the end
	int	dos
	jmp	dmp1

dmp5:	test	filtst.fstat,80h	; access problem?
	jnz	dmp0			; nz = yes
	mov	ah,creat2		; file did not exist
	mov	cx,20h			; attributes, archive bit
	int	dos
	mov	dmphand,ax		; save file handle
	jnc	dmp1			; nc = ok

dmp0:	mov	ah,3			; get cursor position
	xor	bh,bh			; page 0
	int	screen
	push	dx			; save it
	mov	dh,byte ptr low_rgt+1	; go to status line
	inc	dh
	xor	dl,dl			; left most column
	mov	ah,2			; set cursor
	xor	bh,bh			; page 0
	int	screen
	mov	dx,offset dmperr	; say no can do
	mov	ah,prstr
	int	dos
	pop	dx			; get original cursor position
	mov	ah,2			; set cursor
	xor	bh,bh			; page 0
	int	screen
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	clc
	ret

dmp1:	mov	ah,ioctl		; is destination ready for output?
	mov	al,7			; test output status
	mov	bx,dmphand		; handle
	int	dos
	jc	dmp0			; c = error
	cmp	al,0ffh			; ready?
	jne	dmp0			; ne = not ready
	push	di			; read screen buffer, write lines
	push	si
	push	es
	mov	cl,byte ptr low_rgt+1	; number of lines - 2
	add	cl,2			; number of line on screen
	xor	ch,ch
	les	si,vs_ptr		; seg and offset of vscreen
	sub	si,vswidth*2		; prep for inc below
dmp2:	add	si,vswidth*2		; virtual screen width in bytes
	push	si
	push	cx			; save outer loop counter
	push	di
	mov	di,offset decbuf	; data segment memory
	mov	cl,byte ptr low_rgt	; number of columns on screen -1
	inc	cl
	xor	ch,ch
dmp3:	mov	ax,word ptr es:[si]	; read char + attribute
	or	al,al			; is it a null?
	jnz	dmp3c			; nz = no
	mov	al,' '			; replace null with space
dmp3c:	mov	byte ptr [di],al	; store just char, don't use es:
	inc	si			; update pointers
	inc	si
	inc	di
	loop	dmp3			; do for each column
	mov	cl,byte ptr low_rgt	; number of columns on screen - 1
	inc	cl
	xor	ch,ch
	push	es
	mov	ax,ds
	mov	es,ax			; set es to data segment for es:di
	mov	di,offset decbuf	; start of line
	add	di,cx			; plus length of line
	dec	di			; minus 1 equals end of line
	mov	al,' '			; thing to scan over
	std				; set scan backward
	repe	scasb			; scan until non-space
	cld				; set direction forward
	pop	es
	je	dmp3a			; e = all spaces
	inc	cx
	inc	di
dmp3a:	mov	word ptr [di+1],0A0Dh	; append cr/lf
	add	cx,2			; line count + cr/lf
	mov	dx,offset decbuf	; array to be written
	mov	bx,dmphand		; need file handle
	mov	ah,write2		; write the line
	int	dos
	pop	di
	pop	cx			; get line counter again
	pop	si			; screen offset
	jc	dmp3b			; c = error
	loop	dmp2			; do next line
dmp3b:	mov	dx,offset dumpsep	; put in formfeed/cr/lf
	mov	bx,dmphand		; need file handle
	mov	cx,3			; three bytes overall
	mov	ah,write2		; write them
	mov	bx,dmphand		; file handle
	int	dos
	mov	bx,dmphand		; need file handle
	mov	ah,close2		; close the file now
	int	dos
	pop	es
	pop	si
	pop	di
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	clc
	ret
dumpscr endp

togmod	proc	FAR
	call	trnmod			; FAR callable trnmod
	ret
togmod	endp

					; Toggle Mode Line
trnmod	proc	near
	cmp	inemulator,0		; in terminal emulator?
	je	trnm1			; e = no, no mode line
	cmp	flags.modflg,1		; mode line enabled and owned by us?
	jne	trnm1			; ne = no, don't touch it
	cmp	flags.vtflg,tttek	; Tek mode?
	je	trnm1			; e = yes
	test	tekflg,tek_dec		; in Tek submode?
	jnz	trnm1			; nz = yes, no mode line changes
	test	yflags,modoff		; mode line already off?
	jnz	trnm2			; nz = yes, go turn on
	or	yflags,modoff		; say modeline is toggled off
	cmp	flags.vtflg,0		; emulating none?
	jne	trnm0			; ne = no
	mov	lastsec,-1		; tickle tod clock
	push	dx
	call	fgetpcur		; get physical cursor
	mov	cursor,dx
	pop	dx
trnm0:	call	clrmod			; clear mode line
trnm1:	clc				; clear c bit so don't exit Connect
	ret
trnm2:	cmp	flags.vtflg,0		; emulating a terminal?
	jne	trnm3			; ne = yes
	push	dx			; scroll screen to save bottom line
	call	fgetpcur		; get physical cursor
	mov	cursor,dx
	mov	ah,prstr		; for terminal type none
	mov	dx,offset crlf
	int	dos
	pop	dx
trnm3:	call	modlin			; turn on modeline
	and	yflags,not modoff	; say modeline is not toggled off
	clc
	ret
trnmod	endp

modlin	proc	near
	cmp	isps55,0		; [HF]940206 Japanese PS/55 ?
	je	modl21			; [HF]940206 e = no
	cmp	ps55mod,0		; [HF]940206 can we use modeline?
	jne	modl21			; [HF]940206 ne = yes
	mov	ax,1401h		; [HF]940206 user uses the modeline
	mov	ps55mod,al		; [HF]940206 save current status
	int	16h			; [HF]940206 OK, now in our hands
modl21:	push	si
	push	di
	push	es
	mov	ax,ds
	mov	es,ax
	mov	si,offset modmaster	; master template
	mov	di,offset modbuf	; working copy
	mov	lastsec,-1		; tickle tod clock
	cld
modl20:	lodsb
	stosb
	cmp	al,'$'			; at end?
	jne	modl20			; ne = no
	mov	bx,argadr		; get argument block
	mov	al,[bx].baudb		; get baud bits
	mov	si,offset unkbaud	; assume unknown baud
	mov	cx,size m_baud		; length of baud space
	cmp	al,baudnsiz		; beyond end of table?
	jnb	modl2			; nb = yes, use default
	mul	cl
	xor	ah,ah
	add	ax,offset baudn
	mov	si,ax
modl2:	mov	di,offset modbuf.m_baud
	cld
	rep	movsb			; copy in baud rate
	mov	bx,portval
	mov	al,[bx].parflg		; get parity code
	and	al,3			; regular parity uses two bits
	mov	ah,al
	shl	al,1			; each is 3 bytes long
	add	al,ah
	xor	ah,ah
	add	ax,offset parnams	; names of parity settings
	mov	si,ax
	mov	cx,3			; each is 3 long
	mov	di,offset modbuf.m_par
	push	di
	rep	movsb
	pop	di
	test	[bx].parflg,PARHARDWARE	; using hardware parity?
	jz	modl2b			; z = no
	mov	al,'8'			; say 8 data bits
	stosb
	jmp	short modl2a

modl2b:	cmp	byte ptr [di],'8'	; any parity?
	jne	modl2a			; ne = yes, use existing '7'
	test	flags.remflg,d8bit	; 8 bit display?
	jnz	modl2a			; nz = yes
	mov	al,'7'
	stosb				; overwrite '8' with '7'
modl2a:	mov	si,offset remmsg	; assume remote echoing
	test	yflags,lclecho		; local echo on?
	jz	modl3			; z = no
	mov	si,offset lclmsg	; say echo is local
modl3:	mov	cx,3			; size of value
	mov	di,offset modbuf.m_echo
	rep	movsb
	mov	al,portno		; communications port
	cmp	al,' '			; binary (non-printable)?
	jae	modl4			; ae = no, ascii
	add	al,'0'			; convert to ascii
modl4:	mov	modbuf.m_prt,al		; fill in port number
	mov	al,portno
	cmp	repflg,0		; REPLAY?
	je	modl5			; e = no
	mov	si,offset repmsg	; say "REPLAY"
	mov	cx,repmsgl		; its length
	mov	di,offset modbuf.m_prt
	mov	al,' '			; start with a space
	stosb
	mov	dx,24			; space to be filled
	sub	dx,cx			; amount we will use here
	rep	movsb			; copy string
	mov	cx,dx
	rep	stosb			; flesh out with spaces
	jmp	modl10

modl5:	cmp	al,'4'			; in networks material?
	jbe	modl10			; be = no
ifndef	no_tcp
	cmp	flags.comflg,'t'	; doing TCP/IP Telnet?
	jne	modl5d			; ne = no
	mov	si,offset tcphost	; name of host
	mov	di,offset modbuf.m_prt - 5 ; overwrite "port:"
ifdef	nls_portuguese
	dec	di			; "porta:"
endif	; nls_portuguese

modl5c:	mov	ax,sescur		; ident of session
	add	al,'1'			; ascii, show as 1:nodename
	mov	ah,':'
	stosw				; store that much
	mov	cx,28			; bytes max
modl5a:	lodsb
	or	al,al 			; at null terminator?
	jz	modl5b			; z = yes
	stosb
	loop	modl5a
modl5b:	mov	al,' '			; fill out with spaces
	rep	stosb			; noop if cx == 0
	jmp	short modl5d		; done with tcp/ip 
endif	; no_tcp

modl5d:	mov	bx,offset comptab	; table of comms ports
	mov	cl,[bx]			; number of entries
	xor	ch,ch
	inc	bx
modl6:	mov	dx,[bx]			; length of this entry
	mov	si,bx
	add	si,2			; points to entry text string
	add	si,dx			; point to qualifier
	cmp	[si],al			; our port?
	je	modl7			; e = yes
	add	bx,[bx]			; add text length
	add	bx,4			; plus count and qualifier
	loop	modl6			; next entry
	jmp	short modl10		; no match, curious
modl7:	mov	si,bx			; point at entry
	add	si,2			; point at string
	mov	cx,[bx]			; length of string
	mov	di,offset modbuf.m_prt
	mov	al,' '			; start with a space
	stosb
	mov	dx,17			; space to be filled
ifdef	nls_portuguese
	dec	dx
endif	; nls_portuguese
	sub	dx,cx			; amount we will use here
	rep	movsb			; copy string

	cmp	flags.comflg,'F'	; Fossil?
	jne	modl9			; ne = no
	mov	al,'-'			; punctuation
	stosb
	mov	ax,fossil_port		; port
	inc	ax			; count from one to user
	push	dx			; preserve reg for below
	call	dec2di			; write port
	pop	dx
	sub	dx,2			; dash and digit
	add	di,2
	cmp	fossil_port,9		; two digits?
	jbe	modl9			; be = no
	dec	dx			; yes, one less slot
	inc	di

modl9:	mov	cx,dx
	mov	al,' '
	rep	stosb			; flesh out with spaces
modl10:	mov	cx,8			; blank out terminal id field
	mov	si,offset mtty		; assume no terminal emulation
	mov	di,offset modbuf.m_term ; destination
	rep	movsb			; copy it in
	mov	word ptr modbuf.m_prn,'  '; assume not printing the screen
	mov	modbuf.m_prn+2,' '
	test	anspflg,prtscr+2	; print the screen? (msz uses 1 & 2)
	jz	modl10a			; z = no
	mov	word ptr modbuf.m_prn,'RP' ; yes. display PRN at end of line
	mov	modbuf.m_prn+2,'N'
modl10a:mov	modbuf.m_comp,' '	; flag for not-compose
	cmp	grab,0			; doing Compose grabbing?
	je	modl11			; e = no
	mov	modbuf.m_comp,'C'	; flag for compose
modl11:	cmp	inemulator,0		; in terminal emulator now?
	jne	modl11a			; ne = yes
	pop	es			; do nothing
	pop	di
	pop	si
	ret
modl11a:push	dx
	cmp	flags.vtflg,0		; emulating?
	je	modl12			; e = no
	and	yflags,not modoff	; update local flags (mode line on)
	call	fansdsl			; get extras from emulator
modl12:	mov	dx,offset modbuf	; mode line image ptr for putmod
	call	putmod			; display mode line
	mov	dx,cursor		; restore active cursor position
	call	fsetpos			; set cursor
	pop	dx
	pop	es
	pop	di
	pop	si
	ret
modlin	endp

fmodlin	proc	far
	call	modlin
	ret
fmodlin	endp

; toggle between text and graphics modes
vtans52 proc	near
	cmp	flags.vtflg,0		; emulating?
	je	vtans52a		; e = no
	call	ans52t			; call MSZ toggle-it routine
	cmp	flags.vtflg,tttek	; Tek now?
	je	vtans52a		; e = yes
	test	tekflg,tek_tek+tek_dec+TEK_SG 	; Tek submode?
	jnz	vtans52a		; nz = yes
	call	scrini			; check on screen size changes
vtans52a:clc				; clear c bit so don't exit Connect
	ret
vtans52 endp

ftrnprs proc	far
	call	trnprs
	ret
ftrnprs	endp

trnprs	proc	near
	push	ax			; toggle ^ PrtSc screen to printer
	test	anspflg,prtscr		; are we currently printing?
	jnz	trnpr2			; nz = yes, its on and going off
	push	bx
	mov	bx,prnhand		; file handle for system printer
	mov	ah,ioctl
	mov	al,7			; get output status of printer
	int	dos
	pop	bx
	jc	trnpr1			; c = printer not ready
	cmp	al,0ffh			; Ready status?
	je	trnpr2			; e = Ready	
trnpr1:	call	fvtbell			; Not Ready, complain
;	pop	ax
;	stc				; say failure
;	ret				; and ignore request
trnpr2:	xor	anspflg,prtscr		; flip the flag
	test	yflags,modoff		; mode line off?
	jnz	trnpr3			; nz = yes
	call	fmodlin			; else rewrite mode line
trnpr3:	pop	ax
	clc				; return carry clear (don't quit)
	ret
trnprs	endp
code	ends

code1	segment
	assume	cs:code1

pntdead	proc	near			; display printer is inoperative msg
	push	ax
	test	yflags,modoff		; is mode line off?
	jnz	pntdea1			; nz = off, skip msg
	push	bx
	mov	dx,offset pntmsg	; say printer not ready
	call	fputmod			; write on mode line
	pop	bx
pntdea1:pop	ax
	stc				; say printer not ready
	ret
pntdead	endp

endif	; no_terminal

;;;;; General screen management routines for IBM PC

; computes screen location to ax, given row and col in [dh,dl], resp.

scrloc	proc	near
	push	cx
	mov	cl,crt_cols
	cmp	inemulator,0		; emulating?
	je	scrloc1			; e = no
	cmp	flags.vtflg,0		; emulating anything?
	je	scrloc1			; e = no
	mov	cl,vswidth
scrloc1:mov	al,dh			; get row
	mul	cl			; multiply by number of columns
	add	al,dl			; plus current column number
	adc	ah,0			; ripple carry
	shl	ax,1			; double for attributes
	pop	cx
	ret
scrloc	endp

; Routine to set cursor type.  Pass cursor type in al: 0,4 = No cursor,
; 1 = Underline cursor, 2 = Block cursor.   All cursors blink due to hardware.
; For EGA boards running in non-25 line mode the cursor emulation is turned
; off during cursor shape changing and restored afterward. It's another
; ega Feature. [jrd]
; Sense crt_mode 18h as Tseng Labs UltraPAK mono board in 132 column mode.
csrtype proc	near
	push	cx			; save the reg
	mov	cx,0F00H		; assume no cursor
	test	al,4			; no cursor?
	jz	csrtyp6			; z = no
	xor	al,al			; set type to invisible
csrtyp6:or	al,al			; no cursor?
	jz	csrty2			; z = yes, no cursor
	cmp	crt_mode,7		; B&W card?
	je	csrty3			; e = yes, different sizes
	cmp	crt_mode,18h		; Tseng UltraPAK mono board?
 	je	csrty3			; e = yes, use mono cursor
	mov	cx,0607H		; use CGA underline cursor
	cmp	al,2			; Block?
	jne	csrty2			; ne = no, set it now
csrty1: xor	ch,ch			; make cursor a block
csrty2:	cmp	ega_mode,0		; ega board active?
	je	csrty4			; e = no
	test	tv_mode,10h		; DV active?
	jnz	csrty4			; nz = yes, it messes with the cursor
	cmp	byte ptr low_rgt+1,23	; standard screen length?
	je	csrty4			; e = yes, use regular cursor setting
	cmp	byte ptr low_rgt+1,24	; ANSI, standard screen length?
	je	csrty4			; e = yes, use regular cursor setting
	push	es			; EGA. turn off cursor emulation
	mov	ax,40h			; 40:87h is ega Info byte
	mov	es,ax
	push	es:[87h]		; save Info byte around call
	or	byte ptr es:[87h],1	; set emulation off (low bit = 1)
	mov	ah,1			; video function for set cursor type
	int	screen
	pop	es:[87h]		; restore Info byte
	pop	es			;  and our work register
	pop	cx
	ret

csrty4:	push	ax
	mov	ah,1			; video function for set cursor type
	int	screen			; regular cursor shape setting
	pop	ax
csrty5:	pop	cx
	ret

csrty3: mov	cx,0B0CH		; assume B&W underline cursor
	cmp	al,2			; Block?
	jne	csrty2			; ne = no, set it now
	jmp	short csrty1		; make it a block
csrtype endp

fcsrtype proc	far
	call	csrtype
	ret
fcsrtype endp

; Get CRT mode - returns mode in variable crt_mode,
; updates crt_cols, and low_rgt.
; For EGA active it looks in Bios work memory 40:84H for number of rows
scrmod	proc	near
	push	ax
	push	dx
	mov	ah,0fh			; get current video state
	int	screen
	and	al,not 80h		; strip "preserve regen" bit 80h
	mov	crt_mode,al		; store CRT mode value
	mov	crt_cols,ah		; store # of cols
	mov	dl,ah			; # of cols again
	mov	dh,crt_lins		; and # of rows (constant from msster)
	cmp	tv_mode,0		; Topview active?
	je	scrmod2			; e = no
	test	tv_mode,20h		; Japanese DOS active?
	jnz	scrmod2			; nz = yes, do not do Int 15h
	push	cx
	push	bx
	mov	ah,12h			; TV, Get Object Length
	mov	bx,0901h		; object, BL = 01 = chars/line
	int	15h
	pop	ax			; chars/line from stack dword
	cmp	al,10			; keep things sane, chars per line
	ja	scrmod7			; a = might be sane
	pop	ax			; clean stack
	jmp	scrmod2			; wacko, ignore DV stuff

scrmod7:mov	crt_cols,al		; TV windowed screen columns
	pop	ax			; clear rest of dword from stack
	mov	ah,12h			; send
	mov	bx,1			; handle (0*256) + window (me, 1)
	int	15h
	pop	bx			; handle low word
	pop	bx			; handle high word to BX for next call
	mov	ax,1024h		; TV Get Virtual Screen Info
	int	15h			; can yield 8KB, yikes
scrmod1:cmp	cx,80*25*2		; get sanity for DV big DOS window
	jbe	scrmod1a		; be = reasonable size
	shr	cx,1			; reduce size
	jmp	short scrmod1		;  and try again
scrmod1a:mov	ax,cx			; CX is virtual screen size, bytes
	mov	bl,crt_cols		; divide by columns to get width
	shl	bl,1			; get words (char and attribute)
	div	bl			; al = lines, ah = fractions of line
	dec	al			; count this from zero like the Bios
	mov	crt_lins,al		; visible screen lines -1 (24)
	mov	dh,al
	mov	dl,crt_cols		; visible screen columns (80)
	pop	bx
	pop	cx
	jmp	short scrmod4

scrmod2:cmp	ega_mode,0		; ega active?
	je	scrmod4			; e = no
	push	es			; yes, permit different lengths
	mov	ax,40h			; refer to 40:84h for # ega rows
	mov	es,ax
	mov	ah,es:[84h]		; get number of rows - 1 (typ 24)
	cmp	ah,20			; less than 20 rows?
	jb	scrmod3			; b = yes, ignore this length
	cmp	ah,80			; more than 80 rows?
	ja	scrmod3			; a = yes, ignore this length
	mov	dh,ah			; use this length
	mov	dos_bottom,dh		; remember for DOS screen pager
ifndef	no_terminal
	cmp	flags.vtflg,ttansi	; ANSI?
	jne	scrmod2b		; ne = no
	inc	dh			; make mode line a regular text line
	mov	flags.modflg,2		; mode line enabled and owned by host
scrmod2b:cmp	isps55,0		; [HF]940206 is Japanese PS/55 ?
	je	scrmo2a			; [HF]940206 e = no
	cmp	ps55mod,0		; [HF]940206 can we use modeline?
	jne	scrmo2a			; [HF]940206 ne = yes
	inc	dh			; [HF]940206 no, add modeline
endif	; no_terminal
scrmo2a:mov	crt_lins,dh		; update our working constant
scrmod3:pop	es
scrmod4:dec	dl			; max text column, count from zero
	dec	dh			; max text row, count from zero
ifndef	no_terminal
	cmp	flags.vtflg,ttgenrc	; no terminal emulation
	je	scrmod6			; e = yes
	cmp	tekflg,tek_active+tek_sg ; doing special graphics?
	jne	scrmod4a		; ne = no
	mov	crt_cols,128		; VT style special graphics uses this
scrmod4a:
	cmp	crt_cols,80		; doing wide now?
	ja	scrmod5			; a = yes
	mov	dl,80-1			; assume 80 column width
	test	vtemu.vtflgop,deccol	; 132 column mode set?
	jz	scrmod6			; z = no
scrmod5:mov	dl,132-1		; set to 132 column mode

endif	; no_terminal

scrmod6:mov	low_rgt,dx		; save away window address
	pop	dx
	pop	ax
	ret
scrmod	endp

; Get screen segment. Returns screen segment in ax, and full address in es:di
scrseg	proc	near
	xor	di,di			; start at beginning of screen (0,0)
	mov	ax,0B800H		; video memory is here on color
	cmp	crt_mode,7		; normal color modes?
	jb	scrse1			; b = yes
	mov	ax,0B000H		; assume B&W card
	cmp	crt_mode,12		; 
	jb	scrse1
	cmp	crt_mode,18h		; Tseng UltraPAK mono in 132 col?
	je	scrse1			; e = yes, use seg B000H
	cmp	crt_mode,56h		; Paradise EGA Mono in 132x43 mode?
	je 	scrse1			; e = yes, use seg B000H
	cmp	crt_mode,57h		; Paradise EGA Mono in 132x25 mode?
	je	scrse1			; e = yes, use seg B000H
	mov	ax,0B800H		; video memory is here on color
	cmp	crt_mode,18		; end of ordinary 640x480 graphics
	ja	scrse1			; a = no, assume CGA segment
	mov	ax,0A000H		; graphics
scrse1:	mov	es,ax		; tell Topview our hardware address needs
	mov	tv_segs,es		; save our hardware screen address
	mov	tv_sego,di		; segment and offset form
	or	tv_mode,1		; assume we're running under Topview
	mov	ah,tvhere		; query Topview for its presence
	int	screen
	mov	ax,es			; get its new segment for screen work
	cmp	ax,tv_segs		; same as hardware?
	jne	scrse2			; ne = no, we are being mapped
	cmp	di,tv_sego		; check this too
	jne	scrse2		; ne = no too. Use TV's work buf as screen
	and	tv_mode,not 1		; else no Topview or no mapping
scrse2:	mov	tv_segs,es		; save segment
	mov	tv_sego,di		; and offset
	ret
scrseg	endp

; Synchronize a Topview provided virtual screen buffer with the image
; seen by the user. Requires cx = number of words written to screen
; (char & attribute bytes) and es:di = ENDING address of screen write.
; Changes ax and di. Skip operations for DESQview
scrsync proc	near
	cmp	tv_mode,0		; Topview mode active?
	je	scrsyn1			; e = no, skip Bios call below
	push	ax
	push	cx
	push	di
	sub	di,cx			; backup to start byte (cx = words)
	sub	di,cx			;  after storing words to screen
	mov	ah,tvsynch		; tell Topview we have changed screen
	int	screen			;  so user sees updated screen
	pop	di
	pop	cx
	pop	ax
scrsyn1:ret
scrsync endp

; The following two routines are used to turn off the display while we
; are reading or writing the screen in one of the color card modes.
; Turn screen off for (known) color card modes only. All regs preserved.
; Includes code for old procedure scrwait. 16 June 1987 [jrd]
scroff	proc	near
	cmp	ega_mode,0		; Extended Graphics Adapter in use?
	jne	scrofx			; ne = yes, no waiting
	cmp	tv_mode,0		; Topview mode?
	jne	scrofx			; ne = yes, no waiting
	cmp	crt_mode,7		; B&W card?
	jnb	scrofx			; nb = yes - just return
	cmp	refresh,0		; slow refresh?
	jne	scrofx			; ne = no wait
	push	ax			; save ax and dx
	push	dx
	mov	dx,crt_status		; CGA: Wait for vertical retrace
scrof1:	in	al,dx
	test	al,disp_enb		; display enabled?
	jnz	scrof1			; yes, keep waiting
scrof2:	in	al,dx
	test	al,disp_enb		; now wait for it to go off
	jz	scrof2			; so can have whole cycle
	mov	dx,crtmset		; output to CRT mode set port
	mov	al,25H			; this shuts down the display
	out	dx,al
	pop	dx			; restore regs
	pop	ax
scrofx: ret
scroff	endp


; Turn screen on for (known) color card modes only
; All registers are preserved.

scron	proc	near
	cmp	ega_mode,0		; Extended Graphics Adapter in use?
	jne	scronx			; ne = yes, no waiting
	cmp	tv_mode,0		; Topview mode?
	jne	scronx			; ne = yes, no waiting
	cmp	crt_mode,7		; B&W card?
	jnb	scronx			; nb = yes - just return
	cmp	refresh,0		; slow refresh?
	jne	scronx			; ne = no wait
	push	ax			; save ax, dx, and si
	push	dx
	push	si
	mov	al,crt_mode		; convert crt_mode to a word
	xor	ah,ah
	mov	si,ax			; get it in a usable register
	mov	al,msets[si]		; fetch the modeset byte
	mov	dx,crtmset		; this port
	out	dx,al			; flash it back on
	pop	si
	pop	dx
	pop	ax
scronx: ret
scron	endp

ifndef	no_terminal
; Determine screen roll back buffer parameters depending on current screen
; dimensions and available memory. Each rollback screen line has its own
; segment (lines start on segment boundaries for rollback). One full screen
; must be allocated to hold the current display, deduct this from lmax.

bufadj	proc	near
	push	bx
	push	cx
	push	dx
	mov	bx,rollwidth		; rollback line width
	add	bx,7			; (BDT) round up to paragraph boundary
	mov	cl,3			; (BDT) now convert to
	shr	bx,cl			; (BDT) paragraphs / line
	mov	ppl,bx			; (BDT) save this in buffer area
	xor	dx,dx			; high order dividend, clear it
	cmp	emsrbhandle,0		; using EMS?
	jle	bufadj2			; le = no (-1 means not used)
	mov	ax,1024			; 1024 paragraphs per ems 16KB page
	div	bx			; divide by paragraphs per line
	mov	lineems,ax		; lines per ems page, remember
	mul	inipara			; times number of ems pages
	jmp	short bufadj3		; ax has number of lines
					; conventional memory
bufadj2:mov	ax,inipara		; (BDT) compute the number of lines
	div	bx			; (BDT)  in the buffer

bufadj3:mov	lmax,ax			; max line capacity of the buffer
	mov	linee,ax		; (BDT) save as number of total lines
	or	ax,ax			; have any lines?
	jz	bufadj1			; z = no, no space at all
	xor	bh,bh			; (BDT) get lines / screen
	mov	bl,byte ptr low_rgt+1	; (BDT) rows on user/host screen
	inc	bx			; (BDT) adjust for counting from 0
	sub	lmax,bx			; minus master "current" screen
	jg	bufadj1			; g = have some rollback space
	mov	lmax,0			; say none
bufadj1:mov     lcnt,0                  ; (BDT) # of lines filled in buffer
	mov	linef,0			; (BDT) first filled in line
	mov	linec,0			; (BDT) last  filled in line
	pop	dx
	pop	cx
	pop	bx
	ret
bufadj	endp
endif	; no_terminal

; Test for DESQview in operation, set tv_mode bit 10h to non-zero if so.
dvtest	proc	near
	and	tv_mode,not 30h		; assume no DV and no Japanese DOS
ifndef	no_terminal
	cmp	isps55,0		; [HF] 940130 Japanese PS/55 ?
	je	dvtest4			; [HF] 940130 no
	or	tv_mode,30h		; [HF] 940205 say Japanese & DV
	ret				; [HF]  do not use Int 15h for Japan
endif	; no_terminal
dvtest4:xor	bx,bx			; for version number
	mov	cx,'DE'			; DV signature
	mov	dx,'SQ'
	mov	ax,2B01h		; DOS set date (with illegal value)
	int	dos
	cmp	al,0ffh			; DOS should say invalid if no DV
	je	dvtest2			; e = yes, invalid so no DV
	cmp	bx,2			; DV version 2.00?
	jne	dvtest1			; ne = no
	xchg	bh,bl			; get major version into bh
dvtest1:or	tv_mode,10h		; say using DV
dvtest2:ret
dvtest	endp

; Execute DESQview function call provided in BX.
dvcall	proc	near
	push	ax
	mov	ax,101ah		; switch to DV stack
	int	15h
	mov	ax,bx			; function to do
	int	15h
	mov	ax,1025h		; switch from DV stack
	int	15h
	pop	ax
	ret
dvcall	endp

; Call this to release the cpu during idle times
dvpause	proc	near
	cmp	vtcpumode,0		; timeslice-release enabled?
	jne	dvpaus2			; ne = no
	test	tv_mode,10h		; in DV?
	jz	dvpaus1			; z = no
	push	bx
	mov	bx,1000h		; say release control
	call	dvcall			; to DV
	pop	bx
dvpaus1:cmp	byte ptr dosnum+1,5	; DOS verson, major high, minor low
	jb	dvpaus2			; b = too old for this operation
	mov	ax,1680h		; release current virtual machine
	int	2fh			;  time slice (Windows, OS/2, DPMI)
dvpaus2:ret
dvpause	endp

; Screen clearing routine
; Call:	ax = coordinates of first screen location to be cleared.
;	bx = coordinates of last location to be cleared.
; Coord: ah = row [0-24], al = column [0-206]. Preserves all registers.

atsclr	proc	near
	cmp	ax,bx			; correct order?
	jbe	atsclr9			; be = yes
	xchg	ax,bx			; larger to bx
atsclr9:push	ax			; save regs 
	push	cx
	push	dx
	mov	dx,bx			; compute last screen offset from bx
	push	ax
	call	scrloc			; get screen start address in ax
	mov	cx,ax			; save it in cx for a minute
	pop	dx			; compute first screen offset in ax
	call	scrloc
	sub	cx,ax			; compute number of locs to clear
	add	cx,2			; +1 for span, +1 for round up
	sar	cx,1			; make byte count a word count
	jle	atscl3			; le = nothing to clear
	push	di			; save regs
	push	es			; save es
ifndef	no_terminal
	cmp	inemulator,0		; in terminal emulator now?
	je	atscl1			; e = no
	cmp	flags.vtflg,0		; emulating anything?
	je	atscl1			; e = no, using DOS
	les	di,vs_ptr		; es:di is virtual screen
	jmp	short atscl2
endif	; no_terminal
atscl1:	push	ax			; save displacement
	call	scroff			; turn screen off if color card
	call	scrseg			; get address of screen into es:di
	pop	ax
atscl2:	add	di,ax			; location in buffer
	mov	ah,scbattr		; use current screen background attr
	mov	al,' '			; use space for fill
	push	cx			; save word count for Topview
	cld
	rep	stosw			; copy to screen
	pop	cx			; recover word count
ifndef	no_terminal
	cmp	inemulator,0		; in terminal emulator now?
	je	atscl2a			; e = no
	cmp	flags.vtflg,0		; emulating anything?
	jne	atscl2b			; ne = yes
endif	; no_terminal
atscl2a:call	scron			; turn screen back on if color card
	call	scrsync			; synch Topview
atscl2b:pop	es
	pop	di
atscl3:	pop	dx
	pop	cx
	pop	ax			; back to regs at call time
ifndef	no_terminal
	cmp	inemulator,0		; in terminal emulator now?
	je	atscl6			; e = no
	cmp	flags.vtflg,0		; emulating anything?
	je	atscl6			; e = no, using DOS
	push	dx			; do extended attributes
	push	ax
	push	bx
	push	cx
	mov	dx,ax			; starting place
	mov	al,dh			; row
	mov	cl,vswidth		; row char cells
	mul	cl
	add	al,dl			; plus starting column
	adc	ah,0			; char cells to starting place
	mov	dx,ax			; save here
	mov	al,bh			; ending row
	mul	cl
	add	al,bl			; plus ending column
	adc	ah,0
	mov	bx,ax
	sub	bx,dx			; number of cells -1 to clear
	inc	bx
	mov	cx,bx			; cx = cells to clear
	xchg	bx,dx			; bx = start offset, dx=cells
	push	es
	push	di
	les	di,vsat_ptr		; where attributes are stored
	add	di,bx			; offset plus start byte
	xor	ax,ax
	cld
	shr	cx,1
	jnc	atscl4
	stosb
atscl4:	rep	stosw			; clear those bytes
;;;	mov	extattr,0		; and the extension byte too
	pop	di
	pop	es
	pop	cx
	pop	bx
	pop	ax
	mov	dl,ah			; first row
	mov	dh,bh			; last row
	call	touchup			; repaint this part of the screen
	pop	dx			; finish cleaning stack
endif	; no_terminal
atscl6:	ret
atsclr	endp

ifndef	no_terminal
; Screen-scrolling routines.
     
fhomwnd	proc	far			; "home" to start of the buffer
	mov	cl,byte ptr low_rgt+1	; save this many lines
	inc	cl			; full text screen
	xor	ch,ch
	call	putcirc			; save them
	mov	linec,0			; reset the current pointer
	call	getcirc			; now get the new screen
	clc
	ret
fhomwnd	endp
     
fendwnd	proc	far			; "end" to end of the buffer
	mov	cl,byte ptr low_rgt+1	; save this many lines
	inc	cl			; full text screen
	xor	ch,ch
	call	putcirc			; save them
	mov	ax,lcnt			; reset the current pointer
	mov	linec,ax		; save the results
	call	getcirc			; now get the new screen
	clc
	ret
fendwnd	endp
     
fdnwpg	proc	far			; scroll down 1 page
	mov	cl,byte ptr low_rgt+1	; save this many lines
	inc	cl			; full text screen
	xor	ch,ch
	call	putcirc			; save them
	mov	ax,linec		; reset the current pointer
	add	ax,cx
	cmp	ax,lcnt			; did we go past the end?
	jbe	dnwpg1			; be = no, we're OK
	mov	ax,lcnt			; yup, back up
dnwpg1:	mov	linec,ax		; save the results
	call	getcirc			; now get the new screen
	clc
	ret
fdnwpg	endp
     
fdnone	proc	far			; scroll down 1 line
	mov	cl,byte ptr low_rgt+1	; save this many lines
	inc	cl			; full text screen
	xor	ch,ch
	call	putcirc			; save them
	mov	ax,linec		; reset the current pointer
	inc	ax			;  to the next line
	cmp	ax,lcnt			; oops, did we go past the end?
	jbe	dnone1			; be = no, we're OK
	mov	ax,lcnt			; yup, back up
dnone1:	mov	linec,ax		; save the results
	call	getcirc			; now get the new screen
	clc
	ret
fdnone	endp
     
fupwpg	proc	far			; scroll up 1 page
	mov	cl,byte ptr low_rgt+1	; save this many lines
	inc	cl			; full text screen
	xor	ch,ch
	call	putcirc			; save a full screen
	mov	ax,linec		; reset the current pointer
	sub	ax,cx			;  to the previous page
	jge	upwpg1			; ge = not past end, we're OK
	xor	ax,ax			; stop at the beginning of the buffer
upwpg1:	mov	linec,ax		; line counter to use
	call	getcirc			; get the new screen
	clc
	ret
fupwpg	endp
     
fupone	proc	far			; scroll up 1 line
	mov	cl,byte ptr low_rgt+1	; save this many lines
	inc	cl			; full text screen
	xor	ch,ch
	call	putcirc			; save them
	mov	ax,linec		; reset the current pointer
	sub	ax,1			;  to the previous line
	jge	upone1			; ge = not past end, we're OK
	xor	ax,ax			; yup, back up
upone1:	mov	linec,ax		; save the results
	call	getcirc			; now get the new screen
	clc
	ret
fupone	endp

; Horizontal scrolling keyboard verbs
frtpage	proc	far
	mov	cx,20			; step size
	call	rtcommon
	ret
frtpage	endp

frtone	proc	far
	mov	cx,1
	call	rtcommon
	ret
frtone	endp

; Move screen to the right margin by CX columns
rtcommon proc	near
	push	bx
	mov	bl,byte ptr cursor+1	; current cursor row
	xor	bh,bh
	mov	al,linescroll[bx]	; horz scroll in effect for this line
	pop	bx
	add	al,handhsc 		; plus hand scrolling now present
	add	al,crt_cols		; right most char on visible screen
	adc	ah,0
	cmp	ax,vswidth		; too far already?
	ja	rtcomm2			; a = yes, do nothing
	sub	ax,vswidth		; available distance
	neg	ax
	cmp	ax,cx			; space vs desired scroll
	jbe	rtcomm1			; be = less than desired, use space
	mov	ax,cx			; enough room, use desired scroll
rtcomm1:add	handhsc,al		; indicate how much done by hand
	call	repaint
rtcomm2:clc
	ret
rtcommon endp

flfpage	proc	far
	mov	cx,20			; step size
	call	lfcommon
	ret
flfpage	endp

flfone	proc	far
	mov	cx,1			; step size
	call	lfcommon
	ret
flfone	endp

; Move screen toward left margin by CX columns
lfcommon proc	near
	push	bx
	mov	bl,byte ptr cursor+1	; current cursor row
	xor	bh,bh
	mov	al,linescroll[bx]	; horz scroll in effect for this line
	pop	bx
	add	al,handhsc		; available distance to move
	jz	lfcomm2			; z = no space to move
	sub	al,cl			; minus our desired jump
	jge	lfcomm1			; ge = no overscroll the wrong way
	add	cl,al			; reduce cx request by overage
lfcomm1:sub	handhsc,cl		; successful, new handhsc
	call	repaint
lfcomm2:clc
	ret
lfcommon endp

; Scrolling routines.  vtscru scrolls up, vtscrd scrolls down 'scroll'
; rows. Top lines are saved in the circular buffer before scrolling up.
; When running under an Environment control number of line positions moved
; to be less than scrolling region.
; All registers are preserved.
;
; Screen scroll up "scroll" lines (text moves up) for terminal emulator use.
     
vtscru	proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	mov	al,mar_bot		; compute size of scroll
	sub	al,mar_top
	inc	al			; lines in scrolling region
	mov	dl,scroll		; desired scroll
	xor	dh,dh
	cmp	dl,al			; scrolling more than needed?
	jbe	vtscru1			; be = no
	mov	dl,al			; limit scrolling
	mov	scroll,al
vtscru1:or	dl,dl
	jnz	vtscru2	
	jmp	vtscru9			; z = nothing to do

vtscru2:cmp	mar_top,0		; scrolling the top screen line?
	jne	vtscru5			; ne = no, do not save in roll back
	mov	cx,dx			; cx is how many lines
	call	putcirc			; put screen lines in circular buffer
	
	add	linec,cx		; (BDT) increment the current line
	mov	cx,linec		; new current line number
	sub	cx,lcnt			; minus # in buf = qty new lines added
	jc	vtscru3			; c = not extending buffer
	add	lcnt,cx			; (BDT) increment the line counter
vtscru3:mov	cx,lcnt			; (BDT) check: are we
	cmp	cx,lmax			; (BDT) beyond the end?
	jb	vtscru5			; (BDT) b = no
	sub	cx,lmax			; (BDT) compute overflow count
	add	linef,cx		; (BDT) adjust the "first" line
	mov	cx,linef		; (BDT) check: time to wrap?
	cmp	cx,linee		; (BDT) ...
	jb	vtscru4			; (BDT) b = no
	sub	cx,linee		; (BDT) yup
	mov	linef,cx		; (BDT) adjust it
vtscru4:mov	cx,lmax			; (BDT) get the maximum line count
	mov	lcnt,cx			; (BDT) reset the line counter
	mov	linec,cx		; (BDT) reset the current line

vtscru5:mov	di,word ptr vs_ptr	; offset of virtual screen
	mov	cl,vswidth
	mov	al,mar_top		; top line number (from 0)
	mul	cl			; times chars/line
	add	ax,ax			; char + attribute
	add	di,ax			; destination (mar_top)
	mov	al,dl			; number of lines to scroll
	mov	cl,vswidth
	mul	cl			; vswidth * total lines to scroll
	mov	bx,ax			; number of cells to clear
	add	ax,ax			; bytes
	mov	si,di
	add	si,ax			; src is that many bytes down screen
	mov	al,mar_bot		; lines in scrolling region
	sub	al,mar_top
	inc	al
	sub	al,dl			; minus scrolled portion
	mul	cl			; times words per line
	mov	cx,ax			; number of cells to copy
	mov	dh,scbattr		; need this for later (in seg data)
	push	cx			; save number of words for attribute
	push	es
	push	ds
	mov	ax,word ptr vs_ptr+2	; segment of vscreen
	mov	ds,ax
	mov	es,ax
	cld
	rep	movsw			; copy src to dest
	mov	cx,bx			; count of words to clear
	mov	ah,dh			; default attriubte
	mov	al,' '			; filler for clearing a line
	rep	stosw			; store after new src
	pop	ds
	pop	es
					; bx is number of words cleared
	mov	di,word ptr vsat_ptr	; offset of attributes
	mov	cl,vswidth		; char cells per attributes line
	mov	al,mar_top		; top line number (from 0)
	mul	cl			; times cells per line
	add	di,ax			; destination (mar_top)
	mov	si,di

	mov	al,dl			; number of lines to scroll
	mul	cl			; vswidth * total lines to scroll
	mov	bx,ax			; number of cells to clear
	add	si,bx			; src is that many bytes down screen
	pop	cx			; number of vscreen cells copied
	push	es
	push	ds
	mov	ax,word ptr vsat_ptr+2	; segment of vsatt
	mov	ds,ax
	mov	es,ax
	cld
	rep	movsb			; copy src to dest
	mov	cx,bx			; count of bytes to clear
	xor	al,al			; default attributes of none
	rep	stosb			; store after new src
	pop	ds
	pop	es
	cmp	writemode,0		; use direct screen writing?
	je	vscru5a			; e = yes
ifndef	no_graphics
	cmp	tekflg,tek_active+tek_sg ; special graphics mode?
	jne	vscru5b			; ne = no
endif	; no_graphics

vscru5a:cmp	tekflg,tek_active+tek_sg ; special graphics mode?
	jne	vtscru8			; ne = no
ifndef	no_graphics
	call	tekremcursor		; turn off text cursor
vscru5b:mov	dosetcursor,-1		; don't turn on automatically
	mov	al,' '			; write space
	mov	ah,scbattr		; in normal colors
	xor	dl,dl			; at mar_top, left margin
	mov	dh,mar_top		; to set normal text mode for the
	cmp	tekflg,tek_active+tek_sg ; special graphics mode?
	jne	vscru5d			; ne = no
	xor	cl,cl			; no extended attribute
	call	ttxtchr			; graphics adapter
endif	; no_graphics

vscru5d:mov	ax,0600h		; scroll up whole region
	mov	dh,mar_bot		; bottom row
	mov	dl,crt_cols
	cmp	isps55,0		; [HF]940216 Japanese PS/55?
	jne	vscru5e			; [HF]940216 ne=yes, allowed > 80cols.
	cmp	dl,80			; more than physical screen?
	jbe	vscru5e			; be = no
	cmp	dl,131			; really wide screen
	jae	vscru5e			; ae = yes
	mov	dl,80			; else 128 col fake text wide screen
vscru5e:dec	dl			; right most physical col for scroll
	mov	ch,mar_top		; top row of scrolling region
	xor	cl,cl			; left most column
	mov	bh,scbattr		; attributes
	mov	bl,dh
	sub	bl,ch			; region size - 1 line
	jz	vscru2b			; z = region is 1 line, do one scroll
	mov	al,scroll		; number of lines to scroll, from msz
vscru2a:cmp	al,bl			; want to scroll more that than?
	jbe	vscru2b			; be = no
	push	ax
	mov	al,bl			; limit to region - 1 for Windows
	int	screen			;  and do in parts
	pop	ax
	sub	al,bl			; al = amount yet to scroll
	jmp	short vscru2a		; do next part
vscru2b:int	screen			; scroll up that region
	mov	dx,cursor
	mov	dosetcursor,dx		; reminder of where to set cursor
	jmp	short vtscru9

vtscru8:mov	dh,mar_bot		; real text mode
	mov	dl,mar_top		; setup touchup, lines changed
	call	touchup			; touch up real screen
vtscru9:pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
vtscru	endp

; Screen-roll down. Move text down scroll lines, for terminal emulator only.
vtscrd	proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	bp
	push	es
	les	si,vs_ptr		; source is top line of virtual screen
	mov	al,mar_top		; top margin line (0..)
	mov	cl,vswidth		; chars across vscreen
	mul	cl
	add	ax,ax			; words to bytes
	add	si,ax			; offset of start of top line
	mov	bp,si			; remember top line for later
	mov	cl,mar_bot		; compute number of lines to move
	sub	cl,mar_top
	inc	cl			; qty of lines in region
	mov	ch,scroll
	cmp	ch,cl			; want to scroll more than region?
	jbe	vtscrd1			; be = no
	mov	ch,cl			; set scroll to whole region
	mov	scroll,ch		; remember for attributes
vtscrd1:sub	cl,ch	 		; less lines to be skipped
	mov	bl,ch			; save effective scroll for below
	mov	al,vswidth		; number of character cells
	mul	cl
	mov	cx,ax			; number of words in the movement
	dec	ax			; compute to end word
	add	ax,ax			; number of bytes
	add	si,ax			; go to the end
	mov	di,si
	mov	al,vswidth		; words in a line buffer
	mul	bl			; number of chars dest is below src
	mov	bx,ax			; save number of chars here for clear
	add	ax,ax			; number of bytes (char + attribute)
	add	di,ax			; destination offset
	push	ds
	mov	ax,es
	mov	ds,ax
	std
	rep	movsw			; copy down the lines
	cld
	pop	ds
	mov	di,bp			; fill top line in scrolling region
	mov	ah,scbattr
	mov	al,' '
	mov	cx,bx			; number of char cells to clear
	rep	stosw			; fill top line(s) with spaces
					; do extended attributes the same way
	les	si,vsat_ptr		; source of extended attributes
	mov	al,mar_top		; top margin line (0..)
	mov	cl,vswidth		; attribute cells/line
	mul	cl
	add	si,ax			; offset of start of top line
	mov	bp,si			; remember top line for later
	mov	cl,mar_bot		; compute number of lines to move
	sub	cl,mar_top
	inc	cl			; qty of lines in region
	mov	ch,scroll
	sub	cl,ch	 		; less lines to be skipped
	mov	bl,ch			; save effective scroll for below
	mov	al,vswidth		; number of attribute cells/line
	mul	cl
	mov	cx,ax			; number of bytes in the movement
	dec	ax			; compute to end byte
	add	si,ax			; go to the end
	mov	di,si
	mov	al,vswidth		; number of attribute cells/line
	mul	bl			; number of cells dest is below src
	mov	bx,ax			; save number of bytes here for clear
	add	di,ax			; destination offset
	push	ds
	mov	ax,es
	mov	ds,ax
	std
	rep	movsb			; copy down the lines
	cld
	pop	ds
	mov	di,bp			; fill top line in scrolling region
	xor	al,al			; null attributes for filler
	mov	cx,bx			; number of attributes bytes to clear
	rep	stosb			; fill top line(s) with spaces
	pop	es
	pop	bp
	cmp	writemode,0		; use direct screen writing?
	je	vscrd1			; e = yes
	cmp	tekflg,tek_active+tek_sg ; special graphics mode?
	jne	vscrd3a			; ne = no
vscrd1:
ifndef	no_graphics
	cmp	tekflg,tek_active+tek_sg ; special graphics mode?
	je	vscrd3			; e = yes
endif	; no_graphics
	mov	dl,mar_top		; setup touchup, lines changed
	mov	dh,mar_bot
	call	touchup			; touch up real screen
	jmp	short vscrd8

ifndef	no_graphics
vscrd3:	call	tekremcursor		; turn off text cursor
endif	; no_graphics
vscrd3a:mov	dosetcursor,-1		; don't turn on automatically
	mov	al,' '			; write space
	mov	ah,scbattr		; in normal colors
ifndef	no_graphics
	xor	dl,dl			; at mar_bot, left margin
	mov	dh,mar_bot		; to set normal text mode for the
	cmp	tekflg,tek_active+tek_sg ; special graphics mode?
	jne	vscrd3b			; ne = no
	xor	cl,cl			; no extended attribute
	call	ttxtchr			; graphics adapter
endif	; no_graphics
vscrd3b:mov	ax,0700h		; scroll down whole region
	mov	ch,mar_top		; top margin line
	xor	cl,cl			; left most column
	mov	dh,mar_bot		; bottom margin line
	mov	dl,crt_cols
	cmp	isps55,0		; [HF]940216 Japanese PS/55
	jne	vscrd3c			; [HF]940216 ne=yes, allowed > 80 cols
	cmp	dl,80			; more than physical screen?
	jbe	vscrd3c			; be = no
	cmp	dl,131			; really wide screen
	jae	vscrd3c			; ae = yes
	mov	dl,80			; else 128 col fake text wide screen
vscrd3c:dec	dl			; right most physical col for scroll
	mov	bh,scbattr		; attributes
	mov	bl,dh
	sub	bl,ch			; region size - 1 line
	jz	vscrd7 			; z = region is 1 line, do one scroll
	mov	al,scroll		; number of lines to scroll, from msz
vscrd7:	cmp	al,bl			; want to scroll more that than?
	jbe	vscrd2			; be = no
	push	ax
	mov	al,bl			; limit to region-1 for Windows
	int	screen			;  and do in parts
	pop	ax
	sub	al,bl			; get remainder
	jmp	short vscrd7		; do next part
vscrd2:	int	screen			; scroll it down
	mov	dx,cursor
	mov	dosetcursor,dx		; reminder of where to set cursor
vscrd8:	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
vtscrd	endp

; Put the top cx lines from the virtual screen in to the circular buffer
; starting at line index linec (counted from zero, modulo linee).
putcirc	proc	near
	jcxz	putcir6			; z = no lines to save
	cmp	lmax,0			; any buffer space?
	jne	putcir7			; ne = yes, have some
putcir6:ret
putcir7:push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	es
	cld
	mov	pageready,-1		; ems page number currently active
	mov	si,word ptr vs_ptr	; offset of screen buffer
	mov	bx,linef		; index of the first line
	add	bx,linec		; add the current line counter
	dec	bx
putcir1:inc	bx
	cmp	bx,linee		; at the end of the buffer now?
	jb	putcir2			; b = no
	sub	bx,linee		; backup to start of buffer
putcir2:mov	ax,bx			; line index
	cmp	emsrbhandle,0		; EMS in use?
	jg	putcir3			; g = yes
	cmp	xmsrhandle,0		; XMS rollback in use?
	je	putcir3			; e = no
	call	putxms			; do the put via xms
	jmp	short putcir4
putcir3:call	emsfixup		; do expanded memory conversion work
	mul	ppl			; times paragraphs per line
	add	ax,iniseg		; plus initial seg of buffer
	mov	es,ax			; now we have the segment pointer
	xor	di,di			; buffer offset is always 0
	push	cx			; save the number of lines
	mov	cx,rollwidth		; get the number of characters to move
	push	si			; save starting vscreen offset
	push	ds			; get the offset of the screen
	cld
	mov	ds,word ptr vs_ptr+2	; seg of vscreen
	rep	movsw			; move them
	pop	ds			; restore DS
	pop	si			; vscreen offset
	add	si,vswidth*2		; inc to next vscreen line
	pop	cx			; restore the line count
putcir4:loop	putcir1			; go back for more
	pop	es
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	clc
	ret
putcirc	endp

; Put CX lines into XMS based rollback buffer
putxms	proc	near
	mul	ppl			; line number times paragraphs/line
	push	cx
	mov	cx,4			; have paragraphs, want bytes
	xor	dx,dx
putxms1:shl	al,1
	rcl	ah,1
	rcl	dl,1			; get bytes to dx:ax
	loop	putxms1			; times 16
	pop	cx

	mov	word ptr xms.offset_dst,ax	; low order address
	mov	word ptr xms.offset_dst+2,dx	; high order
	mov	ax,rollwidth
	shl	ax,1				; times two
	mov	word ptr xms.xms_count,ax	; byte count
	mov	ax,word ptr vs_ptr+2 		; src seg
	mov	word ptr xms.offset_src+2,ax
	mov	word ptr xms.offset_src+0,si 	; low order
	mov	xms.handle_src,0		; source is local
	mov	ax,xmsrhandle 			; dest is rollback area
	mov	xms.handle_dst,ax
	push	si
	mov	si,offset xms		; ds:si is request block
	mov	ah,xmsmove
	call	dword ptr xmsep
	pop	si
	add	si,vswidth*2		; inc to next vscreen line
	ret
putxms	endp

; Get CX lines from the circular buffer, non destructively, starting at
; line index linec (counted from zero, modulo linee) and put them at
; the top of the virtual screen. Fewer lines are written if the buffer
; holds fewer than CX.
getcirc	proc	near
	or	cx,cx			; check on qty
	jnz	getcir0			; nz = some
	ret
getcir0:cmp	lmax,0			; any buffer space?
	jne	getcir5			; ne = yes, have some
	ret
getcir5:push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	es
	mov	pageready,-1		; ems page number currently active
	les	di,vs_ptr		; seg and offset of vscreen
	mov	bx,linef		; get the first line pointer
	add	bx,linec		; add the current line counter
	dec	bx
	cld
getcir1:inc	bx
	cmp	bx,linee		; at the end of the buffer now?
	jb	getcir2			; b = no
	sub	bx,linee		; backup to start of buffer
getcir2:mov	ax,bx			; line index

	cmp	emsrbhandle,0		; EMS in use?
	jg	getcir3			; g = yes
	cmp	xmsrhandle,0		; XMS rollback in use?
	je	getcir3			; e = no
	call	getxms			; get from XMS
	jmp	short getcir4
getcir3:call	emsfixup		; do expanded memory conversion work
	mul	ppl			; times paragraphs per line
	add	ax,iniseg		; plus initial seg of buffer
	xor	si,si			; initial offset is always 0
	push	cx			; save the number of lines
	mov	cx,rollwidth		; get the number of characters to move
	push	di			; save vscreen offset
	push	ds			; save DS for a tad
	mov	ds,ax			; now we have the segment pointer
	rep	movsw			; move them
	pop	ds			; restore DS
	pop	di			; recover vscreen offset
	add	di,vswidth*2		; next vscreen line
	pop	cx			; restore the line count
getcir4:
	loop	getcir1			; go back for more
	call	repaint			; repaint screen
	pop	es
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	clc
	ret
getcirc	endp

getxms	proc	near
	mul	ppl			; line number times paragraphs/line
	push	cx
	mov	cx,4			; have paragraphs, want bytes
	xor	dx,dx
getxms1:shl	al,1
	rcl	ah,1
	rcl	dl,1			; get bytes to dx:ax
	loop	getxms1			; times 16
	pop	cx
	mov	word ptr xms.offset_src,ax	; low order address
	mov	word ptr xms.offset_src+2,dx	; high order
	mov	ax,rollwidth
	shl	ax,1				; times two for words
	mov	word ptr xms.xms_count,ax	; byte count
	mov	ax,word ptr vs_ptr+2 		; dst seg
	mov	word ptr xms.offset_dst+2,ax
	mov	word ptr xms.offset_dst+0,di 	; low order
	mov	xms.handle_dst,0		; destination is local
	mov	ax,xmsrhandle 			; source is rollback area
	mov	xms.handle_src,ax 		; source is rollback area
	push	si
	mov	si,offset xms			; ds:si is request block
	mov	ah,xmsmove
	call	dword ptr xmsep
	pop	si
	add	di,vswidth*2			; next vscreen line
	ret
getxms	endp

; Convert rollback line number in AX to line number in ems page, and invoke 
; that page. Destroys dx, returns ax as line number in page.
emsfixup proc	near
	cmp	emsrbhandle,0		; EMS in use?
	jg	emsfix1			; g = yes (-1 is not in use)
	ret
emsfix1:xor	dx,dx
	div	lineems			; line number / lines per ems page
	push	bx
	mov	bx,ax			; quotient, page number
	mov	ax,dx			; remainder, line in page
	cmp	bx,pageready		; is this page now present?
	je	emsfix2			; e = yes
	mov	pageready,bx		; remember
	push	ax
	mov	ah,emsmapmem		; map logical page in bx
	xor	al,al			;  to physical page zero
	mov	dx,emsrbhandle		; our ems rollback handle
	int	emsint
	pop	ax			; return ax as line in page
emsfix2:pop	bx
	ret
emsfixup endp

; Repaint screen from the vscreen buffer
repaint	proc	near
	push	dx
	xor	dl,dl			; top row
	mov	dh,crt_lins		; physical screen rows-1, incl status
	cmp	isps55,0		; [HF]940209 Japanese PS/55?
	je	repain1			; [HF]940209 e = no
	cmp	ps55mod,0		; [HF]940209 system uses modeline?
	jne	repain1			; [HF]940209 ne = no
	dec	dh			; [HF]940209 yes, don't touch modeline
repain1:call	touchup
	pop	dx
	ret
repaint	endp

; Repaint part of screen from the vscreen buffer, with linescroll offset
; dh is bottom line number, dl is top line number (dh >= dl)
ftouchup proc	far
	call	touchup
	ret
ftouchup endp

touchup	proc	near			; get lines from virtual screen
	cmp	flags.vtflg,ttgenrc	; terminal type of none?
	jne	touch1			; ne = no
	ret
touch1:	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	es
	mov	cl,dh			; last row to change
	sub	cl,dl			; number of lines -1
	cmp	cl,crt_lins		; out of bounds value?
	jbe	touch1b			; be = no
	xor	cl,cl			; stay sane
touch1b:inc	cl			; number of lines to update
	xor	ch,ch
	cmp	tekflg,tek_active+tek_sg ; special graphics mode?
	je	touch1c			; e = yes, skip text screen update
	test	tekflg,tek_active	; other graphics mode?
	jnz	touch9			; nz = yes, no touchup

	call	scroff			; turn off text screen
	mov	es,tv_segs		; get the segment of the screen
	mov	di,tv_sego		; initial screen offset
touch1c:mov	al,crt_cols		; physical screen width
	mul	dl			; chars into physical screen
	add	ax,ax			; chars to bytes
	add	di,ax			; offset of start of phy update area
	mov	si,word ptr vs_ptr
	mov	al,vswidth		; chars per line
	mul	dl			; ax = bytes to first vscreen line
	add	ax,ax			; chars to bytes
	add	si,ax			; si = starting vscreen line offset
	mov	bl,dl			; top line number
	xor	bh,bh			; index for linescroll
	cld
	push	dx
	mov	dh,dl			; set row into dh, temporarily
touch2:	push	si			; save the current line pointer
	push	cx			; save the number of lines
	mov	cl,crt_cols		; get the number of characters to move
	xor	ch,ch
	xor	dl,dl
	mov	al,linescroll[bx]	; get horiz scroll for this line
	add	al,handhsc		; hand done shift, total to AL
	cbw				; sign extend
	or	ax,ax			; sane?
	jge	touch2c			; ge = yes
	xor	ax,ax			; remove negative overshifts
touch2c:add	si,ax			; offset into vscreen
	add	si,ax			; char cells to words

	mov	ah,dgwindcomp[bx]
	test	ah,2			; soft font?
	jz	touch2g			; z = no
ifndef	no_graphics
	cmp	tekflg,tek_active+tek_sg ; special graphics mode?
	je	touch2d			; e = yes
	push	ax
	call	dgsettek		; set special graphics mode now
	pop	ax
	jmp	short touch2d
endif	; no_graphics

touch2g:cmp	writemode,0		; use direct writing?
	je	touch2a			; e = yes
	cmp	tekflg,tek_active+tek_sg ; special graphics mode?
	je	touch2d			; e = yes
	call	tchbios			; Bios writing
	jmp	short touch4
touch2a:cmp	tekflg,tek_active+tek_sg ; special graphics mode?
	jne	touch3			; ne = no

touch2d:
ifndef	no_graphics
	push	bx
	mov	bl,al			; horizontal scroll for this line
	xor	bh,bh
	test	ah,1			; is this line compressed?
	jz	touch2e			; z = no
	mov	cl,128			; compressed, 5 dot chars, 128/line
touch2e:mov	al,vswidth
	mul	dh			; cells in previous rows
	add	al,dl			; cells across to this column
	adc	ah,0
	add	bx,ax			; cells from start of screen
touch2b:push	bx
	push	cx
	push	si
	push	es
	shl	bx,1			; address words
	les	si,vs_ptr		; main vscreen
	mov	ax,es:[si+bx]		; obtain char and attribute
	les	si,vsat_ptr		; extended attributes
	shr	bx,1			; count bytes, vs words above
	mov	cl,es:[bx+si]		; obtain extended attribute byte
	pop	es			; to get font indicator
	pop	si
	call	ttxtchr			; write character
	pop	cx
	pop	bx
	inc	dl			; next column
	inc	bx
	loop	touch2b
	pop	bx
	jmp	short touch4
endif	; no_graphics

touch3:	push	ds
	mov	ds,word ptr vs_ptr+2	; segment of vscreen
	rep	movsw			; from vscreen+hsc to real screen+0
	pop	ds

touch4:	pop	cx			; restore the line count
	pop	si			; restore the buffer counter
	inc	bx			; for next line
	add	si,vswidth*2		; point to next line
	inc	dh
	dec	cx
	jz	touch4a			; z = have done all lines
	jmp	touch2			; do more lines

touch4a:pop	dx
	mov	ah,byte ptr cursor+1	; row of cursor
	cmp	ah,dl			; cursor before this line?
	jb	touch5			; b = yes, skip cursor
	cmp	ah,dh			; cursor after this line?
	ja	touch5			; a = yes, skip cursor
ifndef	no_graphics
	mov	cursorst,0		; say cursor has been zapped off
endif	; no_graphics
	push	dx
	mov	dx,cursor
	mov	bl,dh			; get row
	xor	bh,bh
	sub	dl,linescroll[bx]	; deduct horiz scroll for this line
	sub	dl,handhsc		; hand done shift
	call	setpcur			; reset the cursor
	pop	dx

touch5:	cmp	tekflg,tek_active+tek_sg ; special graphics mode?
	je	touch9			; e = yes
	cmp	tv_mode,0h		; TV active?
	je	touch8			; e = no
	mov	cl,dh			; tell Topview/Desqview
	sub	cl,dl			; number of lines -1
	cmp	cl,crt_lins		; out of bounds value?
	jbe	touch7			; be = no
	xor	cl,cl			; stay sane
touch7:	inc	cl			; number of lines to update
	mov	al,crt_cols		; chars/line
	mul	cl
	mov	cx,ax			; cx = words changed
	call	scrsync			; synch Topview
touch8:	call	scron			; turn on the screen
touch9:	pop	es
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
touchup	endp

; Write screen via Bios. Enter with SI pointing at starting screen buffer
; offset, dh is current screen row, cx has chars to write across a line.

tchbios proc	near
	push	bx
	xor	bh,bh			; video page zero
	push	dx
	mov	ah,3
	int	screen
	mov	temp,dx			; save current cursor
	pop	dx
	mov	cl,crt_cols
	xor	ch,ch
	xor	dl,dl			; column zero
	cld
	push	ds
	mov	ds,word ptr vs_ptr+2	; source is virtual screen buffer
	add	di,cx			; move DI to match si movemen
	add	di,di			; word's worth

tchbios1:push	cx
	mov	ah,2			; set cursor position to dx
	int	screen
	lodsw				; char+attribute
	mov	bl,ah			; attribute
	mov	cx,1			; one char
	mov	ah,9			; write char at cursor position
	int	screen			; do the Bios Int 10h call
	inc	dl			; next column
	pop	cx
	loop	tchbios1
	pop	ds
	push	dx
	mov	dx,temp			; starting cursor position
	mov	ah,2			; set it back there
	int	screen
	pop	dx
	pop	bx
	ret
tchbios	endp

; Character write/read and cursor manipulation routines for terminal emulator
; All registers other than returned values are preserved.

; Read char and attributes under virtual cursor (DH = row, DL = column).
; Returns AL = character, AH = video attributes, CL = logical attribute bit
; pair.
getatch	proc	near
	push	bx
	push	si
	push	es
	mov	al,vswidth		; width of vscreen line
	mul	dh			; count down rows (0..)
	add	al,dl			; add column
	adc	ah,0
	add	ax,ax			; times two for char and attrib
	mov	bx,ax			; address subscript
	les	si,vs_ptr		; main vscreen
	mov	ax,es:[si+bx]		; obtain char and attribute

	les	si,vsat_ptr		; extended attributes
	shr	bx,1			; count bytes, vs words above
	mov	cl,es:[bx+si]		; obtain extended attribute byte
	pop	es
	pop	si
	pop	bx
	ret
getatch	endp
endif	; no_terminal

; Set virtual cursor postion
; DL = column, DH = row, both counted from 0,0 at upper left corner.
; If not displaced, handhsc = 0, then scroll left if virtual > crt_cols.
; If displaced, handhsc != 0, then scroll right if virtual < handhsc.
; For the D463/D470 only, set carry bit (for setatch) if the cursor is off
; the visible screen and horizontal scrolling is disabled.

setpos	proc	near
	push	ax
	push	bx
	push	cx
	push	dx			; save outside virtual cursor
	mov	cl,crt_cols		; physical screen width
	push	cx			; save here
ifndef	no_terminal
	cmp	inemulator,0		; emulating?
	je	setpos9			; e = no, no virtual screen
	cmp	tekflg,tek_active+tek_sg ; special graphics mode?
	jne	setpos1			; ne = no
	mov	bl,dh			; get row
	xor	bh,bh
	test	dgwindcomp[bx],1	; is this line compressed?
	jz	setpos1			; z = no
	mov	crt_cols,128		; compressed, 5 dot chars, 128/line
setpos1:mov	ch,vswidth		; leftmost legal margin (207)
	sub	ch,crt_cols		; minus screen physical width
	xor	cl,cl		; cl is flag for repainting needed (if != 0)
	xchg	handhsc,cl		; hand-done horiz scroll, clear it
	or	cl,cl			; need to undo it?
	jz	setpos2			; z = no
	call	repaint			; repaint screen without hand scroll
	xor	cl,cl			; remove repaint indicator
setpos2:mov	bl,dh			; current row
	xor	bh,bh
	mov	ah,linescroll[bx]	; current horz scroll
setpos3:mov	al,dl			; virtual column where we ought to be
	sub	al,ah			; virtual - already scrolled	
	jc	setpos4			; c = cursor off screen to the left
	cmp	al,crt_cols		; beyond right physical screen?
	jb	setpos5			; b = no, use this
	mov	cl,1			; say need repaint
	inc	ah			; scroll screen left one column
	jc	setpos3a		; c = over did it
	cmp	ah,ch			; going beyond largest scroll?
	jbe	setpos3			; be = no
setpos3a:mov	ah,ch			; yes, stay here
	jmp	short setpos5		; done, do real operation

setpos4:mov	cl,1			; say repaint needed
	mov	ah,dl			; reduce horz scroll

setpos5:or	cl,cl			; repaint needed?
	jnz	setpos5c		; ne = yes
	mov	bl,byte ptr low_rgt+1	; screen bottom
	inc	bl			; lines in emulation part
	xor	bh,bh
	cmp	linescroll[bx],ah	; status line, need to scroll?
	jbe	setpos8			; be = already scrolled properly
	mov	linescroll[bx],ah	; modify status line
	push	dx
	mov	dl,bl
	mov	dh,bl
	call	touchup			; redraw status line
	pop	dx
	jmp	short setpos8		; set cursor

setpos5c:test	flags.vtflg,ttd463+ttd470+ttd217 ; D463/D470/D217?
	jz	setpos5a		; z = no
	cmp	dghscrdis,0		; D463/D470 horz scroll disabled?
	je	setpos5a		; e = no, check auto vs manual
	stc				; c = do not show on real screen
	jmp	short setposx		; skip screen update

setpos5a:test	vtemu.vtflgop,vshscroll	; horizontal scrolling, manual?
	jnz	setpos9			; nz = yes manual, else auto

setpos5b:mov	bl,mar_top		; auto scrolling, top row
	xor	bh,bh
	mov	cl,mar_bot
	sub	cl,bl
	xor	ch,ch
	inc	cx			; lines in scrolling region
setpos6:cmp	linescroll[bx],ah	; any change?
	je	setpos7			; e = no
	mov	linescroll[bx],ah	; set scroll for this line
	push	dx
	mov	dl,bl
	mov	dh,bl
	call	touchup			; repaint this line
	pop	dx
setpos7:inc	bx
	loop	setpos6			; do all lines in window

setpos7a:push	ax			; now do status line
	push	si
	mov	cl,byte ptr low_rgt+1	; examine whole screen
	inc	cl			; lines in emulation part
	xor	ch,ch
	mov	bx,cx			; save for status line
	mov	si,offset linescroll
	mov	ah,[si]			; smallest horizontal shift found
	cld
setpos10:lodsb				; current line scroll to al
	cmp	al,ah			; smaller than smallest?
	ja	setpos11		; a = no
	mov	ah,al			; remember smallest
	or	ah,ah			; zero?
	jz	setpos11a		; can't get any smaller than this
setpos11:loop	setpos10
					; just status line
setpos11a:cmp	linescroll[bx],ah	; status line, need to scroll?
	je	setpos12		; e = already scrolled properly
	mov	linescroll[bx],ah	; modify status line
	push	dx
	mov	dl,bl
	mov	dh,bl
	call	touchup			; redraw status line
	pop	dx
setpos12:pop	si
	pop	ax
setpos8:sub	dl,ah			; virtual - horz scrolled column

endif	; no_terminal

setpos9:call	setpcur			; set physical cursor
	clc				; set status for ok to show
setposx:pop	cx
	mov	crt_cols,cl
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
setpos	endp

; Read physical cursor position
; DL = column, DH = row, both counted from 0,0 at upper left corner
; CX = cursor lines
getpcur	proc	near
	push	ax
	push	bx
	mov	ah,3			; get cursor position
	xor	bh,bh			; page 0
	int	screen
	pop	bx
	pop	ax
	ret
getpcur	endp

fgetpcur proc	far
	call	getpcur
	ret
fgetpcur endp

; Set physical cursor postion
; DL = column, DH = row, both counted from 0,0 at upper left corner
setpcur	proc	near
	push	dx
	cmp	dl,crt_cols		; out of bounds?
	jb	setpcur1		; b = ok
	cmp	dl,207			; off screen to left?
	jbe	setpcur0		; be = no
	xor	dl,dl			; put at column zero
	jmp	short setpcur1
setpcur0:mov	dl,crt_cols		; physical cols on screen
	dec	dl			; count from zero
setpcur1:
ifndef	no_terminal
	cmp	inemulator,0		; emulating?
	je	setpcur4		; e = no, no virtual screen
	cmp	tekflg,tek_active+tek_sg ; special graphics mode?
	jne	setpcur4		; ne = no
	push	ax
	push	es
	mov	ax,40h
	mov	es,ax
	mov	ax,es:[50h]		; current position
	mov	es:[50h],dx		; text page 0 cursor, keep it tracking
	cmp	ax,dx			; same?
	pop	es
	pop	ax
ifndef	no_graphics
	jne	setpcur2		; not same, draw cursor
	cmp	cursorst,0		; is cursor off now?
	jne	setpcur3		; ne = no, skip redrawing
setpcur2:
	mov	dosetcursor,dx		; reminder of where to set cursor
	call	tekremcursor		; ensure it's off
endif	; no_graphics
setpcur3:pop	dx
	ret
endif	; no_terminal

setpcur4:push	ax
	push	es
	mov	ax,40h
	mov	es,ax
	mov	ax,es:[50h]		; current position
	cmp	ax,dx			; same?
	pop	es
	jne	setpcur5		; ne = no
	pop	ax
	pop	dx
	ret
setpcur5:push	bx
	mov	ah,2			; set cursor
	xor	bh,bh			; page 0
	int	screen
	pop	bx
	pop	ax
	pop	dx
	ret
setpcur	endp

; Read char and attributes under physical cursor.
; Returns AL = character, AH = video attributes
getpcha	proc	near
	push	bx
	mov	ah,8			; read char and attributes
	xor	bh,bh			; page 0
	int	screen			; Bios video call
	pop	bx
	ret
getpcha	endp

; Write char and attribute to screen at cursor position, do not move cursor.
; AL = char, AH = video attribute, DL = column, DH = row, CL = logical 
; attribute bits. Does not update physical screen.
qsetatch proc	near
	mov	setnoshow,1		; turn off physical screen update
	jmp	setatch			; call with same args
qsetatch endp

; Write char and attribute to screen at cursor position, do not move cursor.
; AL = char, AH = video attribute, DL = column, DH = row, CL = logical 
; attribute bits. Turns off setnoshow at the end.

setatch	proc	near
	push	bx
	push	es
	push	cx			; save logical attribute
	push	ax			; save char and attribute
	cmp	setnoshow,0		; show on real screen?
	jne	setatc1			; ne = no, do just virtual screen
	push	cx
	call	setpos			; set cursor at dx location
	pop	cx
	jc	setatc1			; c = do not show character
	cmp	inemulator,0		; emulating a terminal now?
	je	setatc4			; e = no
ifndef	no_graphics
	cmp	flags.vtflg,tttek	; full Tek?
	je	setatc5			; e = yes
	cmp	tekflg,tek_active+tek_sg ; special graphics mode?
	jne	setatc4			; ne = no, text mode
setatc5:push	dx
	push	si
	push	di
	mov	bl,dh			; get row
	xor	bh,bh
	sub	dl,linescroll[bx] 	; deduct horizontal scroll
	call	ttxtchr			; display char in graphics mode
	pop	di
	pop	si
	pop	dx
	jmp	short setatc1
endif	; no_graphics
setatc4:
	mov	cx,1			; one char
	mov	bl,ah			; attribute
	xor	bh,bh			; page 0
	mov	ah,9			; write char, do not move cursor
	int	screen
setatc1:mov	setnoshow,0		; always reset this automatically
					; write same material to vscreen
	mov	al,vswidth		; width of vscreen line
	mul	dh			; count across rows (0..)
	xor	bh,bh
	mov	bl,dl			; get position
	add	bx,ax			; add column
	add	bx,bx			; times two for char and attrib
	pop	ax			; recover char and attribute
	pop	cx			; recover logical attribute
ifndef	no_terminal
	cmp	inemulator,0		; in terminal emulator?
	je	setatc2			; e = no, so no virtual screen
	push	di
	les	di,vs_ptr		; virtual screen
	mov	es:[di+bx],ax		; store char and attribute
	push	ax			; save ah attributes

	les	di,vsat_ptr		; attributes byte array
	shr	bx,1			; bytes, vs words above
	mov	es:[bx+di],cl		; set extended attributes
	pop	ax
	pop	di
endif	; no_terminal
setatc2:pop	es
	pop	bx
	ret
setatch	endp

ifndef	no_terminal
; Get bold video attribute bit
; Returns AH = bold attribute bit (0 if not bold)
getbold	proc	near
	and	ah,att_bold
	test	flags.vtflg,ttd463+ttd470+ttd217 ; D463/D470/D217?
	jnz	getbold1		; nz = yes
	xor	ah,userbold		; invert with user bold
getbold1:ret
getbold endp

; Set bold video attribute bit, current video attribute supplied in AH
setbold proc	near
	or	ah,att_bold
	cmp	colunder,0ffh		; uninited?
	je	setbold2		; e = yes, don't change here
	or	colunder,att_bold
setbold2:test	flags.vtflg,ttd463+ttd470+ttd217 ; D463/D470/D217?
	jnz	setbold1		; nz = yes
	xor	ah,userbold		; invert with user bold
	cmp	colunder,0ffh		; uninited?
	je	setbold1		; e = yes, don't change here
	push	ax
	mov	ah,userbold
	xor	colunder,ah
	pop	ax
setbold1:ret
setbold endp

; Clear bold video attribute bit, current video attribute supplied in AH
clrbold	proc	near
	and	ah,not att_bold
	cmp	colunder,0ffh		; uninited?
	je	clrbold2		; e = yes, don't change here
	and	colunder,not att_bold
clrbold2:test	flags.vtflg,ttd463+ttd470+ttd217 ; D463/D470/D217?
	jnz	clrbold1		; nz = yes
	xor	ah,userbold		; invert with user bold
	cmp	colunder,0ffh		; uninited?
	je	clrbold1		; e = yes, don't change here
	push	ax
	mov	ah,userbold
	or	colunder,ah
	pop	ax
clrbold1:ret
clrbold	endp

; Get blink video attribute bit
; Returns AH = blink attribute bit
getblink proc	near
	and	ah,att_blink
	ret
getblink endp

; Set blink video attribute bit, current video attribute supplied in AH
setblink proc	near
	or	ah,att_blink
	ret
setblink endp

; Clear blink video attribute bit, current video attribute supplied in AH
clrblink proc	near
	and	ah,not att_blink
	ret
clrblink endp

; Set extended attribute for protection in extattr and in CL.
setprot	proc	near			; set protected mode
	or	extattr,att_protect
	or	cl,att_protect		; and in cl
	ret
setprot	endp

; Clear extended attribute for protection in extattr and in CL.
clrprot	proc	near			; clear protected mode
	and	extattr,not att_protect
	and	cl,not att_protect
	ret
clrprot endp

; Get underline video attribute bit from extattr
; Returns CL = underline attribute bit
getunder proc	near
	mov	cl,extattr		; get extended attribute
	and	cl,att_uline		; return underline status bit
	ret
getunder endp

; Set underline video attribute bit, current video attribute supplied in AH
; and extended attributes in extattr. Returns new AH and extattr in CL.
setunder proc	near
	test	extattr,att_uline	; extended attributes, on already?
	jz	setund1			; z = no
	ret				; else do nothing
setund1:or	extattr,att_uline	; set underline attribute for MSZ
	or	cl,att_uline
	cmp	crt_mode,7		; monochrome display adapter mode?
	je	setund6			; e = yes
	cmp	colunder,0ffh		; uninited?
	je	setund10		; e = yes

	and	ah,att_blink		; preserve blink
	or	ah,colunder		; user specified underline coloring
	test	extattr,att_rev		; are we reversed per char?
	jz	setund8			; z = no
	call	revideo
setund8:cmp	reversed_screen,0	; whole screen reversed too?
	je	setund9			; e = no
	call	revideo
setund9:ret

setund10:push	bx
	push	dx
	mov	bh,al			; preserve possible char in al
	mov	dl,scbattr		; screen fill
	and	dl,70h			; background colors
	mov	bl,extattr		; extended attributes
	and	bl,att_rev		; per char reversed video
	mov	dh,ah			; current character attributes
	and	dh,not 77h		; blink/bold attributes only
	and	ah,77h			; colors only
	mov	al,ah
	shr	al,1
	shr	al,1
	shr	al,1
	shr	al,1			; background to lower nibble
	and	ah,7			; foreground only
	or	bl,bl			; reversed video attribute?
	jz	setund3			; z = no, normal
	xchg	ah,al			; real background color to al
setund3:xor	al,ah			; modify background
	or	dl,dl			; case of black background?
	jnz	setund4			; nz = no
	mov	al,ah
	dec	al
	and	al,7			; background goes to (foreground-1)/8
	or	al,al			; still black?
	jnz	setund4			; nz = no
	mov	al,7			; force non-black (white foreground)
setund4:shl	al,1			; background to high nibble
	shl	al,1
	shl	al,1
	shl	al,1
	or	ah,al			; or new background
	or	bl,bl			; per char reversal?
	jz	setund5			; z = no
	rol	ah,1			; yes, flip fore/background again
	rol	ah,1
	rol	ah,1
	rol	ah,1
setund5:or	ah,dh			; restore blink and bold
	pop	dx
	mov	al,bh			; restore possible char
	pop	bx
	ret
setund6:push	bx
	mov	bl,al			; preserve char in AL
	call	brkatt			; monochrome, break apart
	mov	ah,att_underline	; set mono underline coloring
	or	ah,al			; put back blink/bold
	test	extattr,att_rev		; are we reversed per char?
	jz	setund6a		; z = no
	call	revideo
setund6a:cmp	reversed_screen,0	; whole screen reversed too?
	je	setund6b		; e = no
	call	revideo
setund6b:mov	al,bl			; restore char in AL
	pop	bx
	ret
setunder endp

; Clear underline video attribute bit, current video attribute supplied in AH
; and extended attributes in extattr. Returns new AH and extattr in CL.
clrunder proc	near
	test	extattr,att_uline	; extended attributes, off already?
	jnz	clrund1			; nz = no
	ret				; else do nothing
clrund1:and	extattr,not att_uline	; clear underline attribute for MSZ
	and	cl,not att_uline
	cmp	crt_mode,7		; monochrome display adapter mode?
	je	clrund6			; e = yes, otherwise reverse video
	cmp	colunder,0ffh		; user spec underline inited?
	je	clrund10		; e = no
	and	ah,att_blink		; preserve blink
	or	ah,att_normal		; current normal coloring
	test	extattr,att_rev		; are we reversed per char?
	jz	clrund1a		; z = no
	call	revideo
clrund1a:cmp	reversed_screen,0	; whole screen reversed too?
	je	clrund1b		; e = no
	call	revideo
clrund1b:ret	
	
clrund6:push	bx
	mov	bl,al			; preserve char in al
	call	brkatt			; mono, break apart attributes
	mov	ah,07h			; set normal coloring
	or	ah,al			; reassemble attributes
	test	extattr,att_rev		; are we reversed per char?
	jz	clrund6a		; z = no
	call	revideo
clrund6a:cmp	reversed_screen,0	; whole screen reversed too?
	je	clrund6b		; e = no
	call	revideo
clrund6b:mov	al,bl			; restore char in AL
	pop	bx
	ret

clrund10:push	bx
	push	dx
	mov	bh,al			; save possible char in al
	xor	bl,bl
	mov	dl,scbattr		; screen fill
	and	dl,70h			; background colors
	mov	bl,extattr		; extended attributes
	and	bl,att_rev		; per char reversed video
	mov	dh,ah			; current char attributes
	and	dh,not 77h		; blink/bold attributes only
	and	ah,77h			; colors only
	mov	al,ah
	shr	al,1
	shr	al,1
	shr	al,1
	shr	al,1			; background to lower nibble
	and	ah,7			; foreground only
	or	bl,bl			; reversed video attribute?
	jz	clrund3			; z = no, normal
	xchg	ah,al			; real background color to al
clrund3:or	dl,dl			; case of black background?
	jz	clrund4			; z = yes, leave it black (empty)
	xor	al,ah
	shl	al,1			; background to high nibble
	shl	al,1
	shl	al,1
	shl	al,1
	or	ah,al			; or in new background
clrund4:or	bl,bl			; per char reversal?
	jz	clrund5			; z = no
	rol	ah,1			; yes, reverse nibbles again
	rol	ah,1
	rol	ah,1
	rol	ah,1
clrund5:or	ah,dh			; restore blink and bold
	pop	dx
	mov	al,bh			; restore possible char
	pop	bx
	ret	
clrunder endp
endif	; no_terminal

; Compute reversed video attributes, given displayables in AH and extended
; in extattr. Returns new attribute in AH and CL holding new extattr
setrev	proc	near
	test	extattr,att_rev		; reversed now?
	jnz	setrev2			; nz = yes
	call	revideo			; do reversal
	or	extattr,att_rev		; update extended attribute
	or	cl,att_rev
setrev2:ret
setrev	endp

; Compute un-reversed video attributes, given displayables in AH and extended
; in extattr. Returns new attribute in AH and CL holding new extattr
clrrev	proc	near
	test	extattr,att_rev		; reversed now?
	jz	clrrev1			; z = no
	call	revideo			; do reversal
	and	extattr,not att_rev	; update extended attribute
	and	cl,not att_rev		; update extended attribute
clrrev1:ret
clrrev	endp


; Compute reversed video attribute byte. Normally preserves blink/bold.
; Enter with AH = video attribute byte, returns new attribute byte in AH.
revideo	proc	near
	push	bx
	mov	bl,al			; preserve char in AL
	call	brkatt			; separate colors from blink/bold
	rol	ah,1			; reverse foreground & background
	rol	ah,1			; RGB bits
	rol	ah,1
	rol	ah,1
	cmp	crt_mode,7		; monochrome?
	jne	revideo1		; ne = no
	test	al,att_bold		; bold?
	jz	revideo1		; z = no
	test	ah,7			; black foreground now?
	jnz	revideo1		; nz = no, something to brighten
	and	al,not att_bold		; remove bolding
revideo1:or	ah,al			; reinsert bold/blink bits
	mov	al,bl			; restore char in AL
	pop	bx
	ret
revideo	endp

; This routine picks an attribute apart into its component "parts" - the
; base attribute for the screen and the "extras" - i.e., blink, intensity
; and underline.
; enter with	ah = a cursor attribute
; return	ah = base attribute for screen (07H normal, 70H reverse).
;		al = "extra" attributes
; Note that there is a complementary routine, addatt, for putting attributes
; back together.

brkatt:	mov	al,ah			; copy displayables
	and	al,(att_blink+att_bold)	; get modifiers
	and	ah,not (att_bold+att_blink) ; strip blink/bold, leave color
	ret

; This routine builds a cursor attribute given the base attribute for the
; screen background and the "extra" attributes we want (blink, etc.).
; enter with	ah = base attribute for background (07H or 70H)
;		al = "extra" attributes (89H for all three)
; return	ah = base combined with "extras".

addatt: or	ah,al			; OR the attributes
	ret

ifndef	no_terminal

; This routine is called when we want to reverse everything on the screen
; from normal to reverse video, or vice versa.	It is called only when
; the decscnm attribute is changed.
; Call:	no arguments.

revscn	proc	near
	push	ax
	push	bx
	push	cx
	push	dx
	xor	reversed_screen,1	; remember we did this
	mov	dh,byte ptr low_rgt+1	; compute last screen offset in ax
	inc	dh			; one more row to catch mode line
	mov	dl,vswidth		; logical screen buffer
	dec	dl			; and we count from 0
	call	scrloc			; get screen offset into ax
	mov	cx,ax			; save it in cx for a minute
	add	cx,2
	sar	cx,1			; in 16-bit words please
	push	di			; Save some more acs
	push	es
	les	di,vs_ptr		; seg and offset of vscreen
	cld
revsc1:	mov	ax,es:[di]		; fetch a word
	mov	bl,al			; save the character
	call	revideo			; get reversed video attributes (AH)
	mov	al,bl			; restore character
	stosw				; stuff into screen memory
	loop	revsc1			; loop for entire screen
	pop	es			; restore segment register
	pop	di			; and destination index
	pop	dx
	pop	cx
	pop	bx
	call	repaint
	pop	ax
	ret
revscn	endp

; Set coloring attributes.
; Enter with AH holding current video attribute byte,
; BL holding ANSI color code (30-37 or 40-47) where 30's are foreground,
; 40's are background. ANSI colors are 1 = red, 2 = green, 4 = blue.
; Return new attribute byte in AH.

setcolor proc	near
	test	extattr,att_rev		; normal video currently?
	jz	setcol0			; z = yes
	mov	al,ah			; make a copy
	and	ax,7788h		; strip bold,blink, keep both in al
	rol	ah,1			; get colors in right parts
	rol	ah,1			;  of ah = back, al = foreground
	rol	ah,1
	rol	ah,1
	call	setcol0			; set fore or background color
	rol	ah,1			; reverse coloring again
	rol	ah,1
	rol	ah,1
	rol	ah,1
	or	ah,al			; put back blink and bold
	ret

setcol0:cmp	bl,30			; ANSI color series?
	jb	setcol7			; b = no
	cmp	bl,37			; foreground set (30-37)?
	ja	setcol4			; a = no, try background set
	sub	bl,30			; take away the bias
	and	ah,not 07H		; clear foreground bits
	test	bl,1			; ANSI red?
	jz	setcol1			; z = no
	or	ah,4			; IBM red foreground bit
setcol1:test	bl,2			; ANSI & IBM green?
	jz	setcol2			; z = no
	or	ah,2			; IBM green foreground bit
setcol2:test	bl,4			; ANSI blue?
	jz	setcol3			; z = no
	or	ah,1			; IBM blue foreground bit
setcol3:ret

setcol4:cmp	bl,40			; background color set?
	jb	setcol7			; b = no
	cmp	bl,47			; background set is 40-47
	ja	setcol7			; nb = no, not a color command
	sub	bl,40			; take away the bias
	and	ah,not 70H		; clear background bits
	test	bl,1			; ANSI red?
	jz	setcol5			; z = no
	or	ah,40h			; IBM red background bit
setcol5:test	bl,2			; ANSI & IBM green?
	jz	setcol6			; z = no
	or	ah,20h			; IBM green background bit
setcol6:test	bl,4			; ANSI blue?
	jz	setcol7			; z = no
	or	ah,10h			; IBM blue background bit
setcol7:ret
setcolor endp

ifndef	no_tcp
; Save terminal emulator, session is in BX.
; Delete older save buffer for this session, so that compressed vscreen
; can be saved properly.
termswapout proc far
	cmp	bx,6			; legal session number?
	jb	termso0			; b = yes
	stc
	ret
termso0:push	ax
	push	bx
	push	cx
	push	si
	push	di
	shl	bx,1			; to words
	mov	temp,bx			; save session ident
	cmp	tsave[bx],0		; have a storage buffer?
	je	termso9			; ne = no, create one now
	shr	bx,1			; get original BL session indicator
	call	termswapdel		; delete old save area
	shl	bx,1			; restore word indexing
termso9:
ifndef	no_graphics
	mov	ax,31*2			; softlist, 31 words
else
	xor	ax,ax
endif	; no_graphics
	call	getvssize		; get size of vscreen, compressed
	add	ax,bx			; accumulate new from bx
	call	getvasize		; size of attributes
	add	bx,ax			; new total to bx
	add	bx,savexlen		; plus length of MSX save area
	add	bx,saveylen		; plus MSY save area
	add	bx,savezlen		; plus MSZ area
	add	bx,saveplen		; plus parser in MSSCMD
	add	bx,saveulen		; plus MSU area
ifndef	no_graphics
	add	bx,saveglen		; plus MSG area
endif	; no_graphics
	add	bx,15			; round up
	mov	cl,4
	shr	bx,cl			; convert to paragraphs
	mov	cx,bx			; save request in cx
	mov	ah,alloc		; please, more space
	int	dos			; paragraph to ax, num paras to bx
	cmp	bx,cx			; given vs wanted
	jae	termso1			; ae = got it
	pop	di
	pop	si
	pop	cx
	pop	bx
	pop	ax
	stc				; fail
	ret
termso1:
ifndef	no_graphics
	push	temp
	push	ax
	call	tekend			; exit graphics mode
	pop	ax
	pop	temp
endif	; no_graphics
	mov	bx,temp			; get 2 * session number (sescur)
	mov	tsave[bx],ax		; save starting paragraph

	push	es
	mov	es,ax			; save area is destination
	xor	di,di			; offset of save area
ifndef	no_graphics
	mov	si,seg softlist		; where softlist lives
	push	ds
	mov	ds,si
	mov	si,offset softlist
	mov	cx,31			; number of entries
	cld
	rep	movsw			; save segs of soft font in msgibm
	pop	ds
endif	; no_graphics

	push	es			; save tsave seg
	push	di			; save current dest ptr
	mov	cx,ds
	mov	es,cx
	mov	cx,size flginfo		; length of saved flags array
	mov	di,offset saveflag	; saved array
	mov	si,offset flags		; working array
	rep	movsb			; save
	pop	di			; tsave dest offset
	pop	es			; tsave seg

; virtual screen is saved as structure
; scr-len	dw	text screen length (typically 24 lines)
; with the items below repeated for each line (scr-len total lines)
; per-line	dw	saved chars on this line
;		dw	per-line dup (char & attribute)
; with the last saved char on each line being repeated to endofline on screen
	push	bx			; virtual screen saving
	mov	cl,crt_lins		; number of screen lines - 1
	inc	cl			; add status line to save block
	xor	ch,ch
	mov	ax,cx
	cld
	stosw				; store screen length as first word
	xor	bx,bx			; line counter
	mov	si,word ptr vs_ptr	; offset of vscreen
termso3:push	cx			; save line loop counter
	mov	cx,word ptr rdbuf[bx]	; get number of saveable chars on line
	mov	ax,cx			; store char count as first word
	stosw
	mov	ax,word ptr vs_ptr+2	; get vscreen segment
	push	si
	push	ds
	mov	ds,ax
	rep	movsw			; copy saveable chars
	pop	ds
	pop	si
	pop	cx			; recover line counter
	add	bx,2			; next line, get length info
	add	si,vswidth*2		; next line, offset of vscreen line
	loop	termso3
	pop	bx			; end of vscreen saving
					;
	push	bx			; virtual screen saving
	mov	cl,crt_lins		; number of screen lines - 1
	inc	cl			; do all lines
termso3b:xor	ch,ch
	mov	ax,cx
	cld
	stosw				; store screen length as first word
	xor	bx,bx			; line counter
	mov	si,word ptr vsat_ptr	; offset of vsattr
termso7:push	cx			; save line loop counter
	mov	cx,word ptr rdbuf[bx+120]; get num of saveable bytes on line
	mov	ax,cx			; store char count as first word
	stosw
	mov	ax,word ptr vsat_ptr+2	; get vsattr segment
	push	si
	push	ds
	mov	ds,ax
	shr	cx,1			; get odd byte count info
	jnc	termso7a		; nc = even count
	movsb
termso7a:rep	movsw			; copy saveable bytes
	pop	ds
	pop	si
	pop	cx			; recover line counter
	add	bx,2			; next line, get length info
	add	si,vswidth		; next line, offset of vsattr line
	loop	termso7
	pop	bx			; end of vsattr saving
					;
	mov	si,offset saveyoff	; offset of MSY save area
	mov	cx,saveylen		; length of MSY save area
	cld
	shr	cx,1			; even/odd?
	jnc	termso4			; nc = even
	movsb				; the odd byte
termso4:rep	movsw
	mov	si,offset savezoff	; offset of MSZ save area
	mov	cx,savezlen		; length of MSZ save area
	shr	cx,1
	jnc	termso5
	movsb
termso5:rep	movsw
	mov	si,offset savexoff	; offset of MSX save area
	mov	cx,savexlen		; length of MSX save area
	cld
	cli				; cautious about serial ints
	shr	cx,1			; even/odd?
	jnc	termso6			; nc = even
	movsb				; the odd byte
termso6:rep	movsw
	sti
	mov	si,offset savepoff	; offset of MSSCMD parser save area
	mov	cx,saveplen		; length of the area
	shr	cx,1
	jnc	termso6a
	movsb
termso6a:rep	movsw
	mov	si,offset saveuoff	; offset of MSUIBM kbd save area
	mov	cx,saveulen		; length of the area
	shr	cx,1
	jnc	termso6b
	movsb
termso6b:rep	movsw

ifndef	no_graphics
	mov	si,offset savegoff	; offset of MSG save area
	mov	cx,saveglen		; length of MSG save area
	shr	cx,1			; graphics mode exited above
	jnc	termso6c
	movsb
termso6c:rep	movsw
endif	; no_graphics
	pop	es
	mov	ax,100h			; assume using 80 col screen
	cmp	dos_cols,80		; startup screen width
	jbe	termso8			; be = assume 80 columns
	inc	al			; say do 132 columns
termso8:push	vtemu.vtflgop
	or	vtemu.vtflgop,vscompress ; turn off compressed mode
	call	chgdsp			; reset display width to startup
	pop	vtemu.vtflgop
	pop	di
	pop	si
	pop	cx
	pop	bx
	pop	ax
	clc
	ret
termswapout endp

; Restore terminal emulator, session is BX
; Delete save buffer after restoration.
termswapin proc	far
	cmp	bx,6			; valid session?
	jb	termsi0			; b = yes
	stc
	ret
termsi0:push	bx
	shl	bx,1			; to words
	cmp	tsave[bx],0		; have a storage buffer?
	pop	bx
	jne	termsi1			; ne = yes, use it
	mov	vtinited,0		; say not inited
	stc				; fail
	ret

termsi1:push	ax
	push	bx
	push	cx
	push	si
	push	di
	push	es			; virtual screen restore
ifndef	no_graphics
	test	tekflg,tek_active	; current graphics mode status
	jz	tswapin1a		; z = not in graphics mode
	push	bx
	call	tekend
	pop	bx
endif	; no_graphics
tswapin1a:
	shl	bx,1			; address words
	mov	ax,tsave[bx]		; starting paragraph for save area
	push	ds
	mov	ds,ax			; save area is source
	xor	si,si			; offset of save area
ifndef	no_graphics
	mov	di,seg softlist		; seg of destination
	mov	es,di
	mov	di,offset softlist
	mov	cx,31			; number of entries
	cld
	rep	movsw			; restore segs of soft font in msgibm
endif	; no_graphics
	pop	ds

	les	di,vs_ptr		; seg and offset of vscreen
	mov	ax,tsave[bx]		; starting paragraph of save area
	push	ds
	mov	ds,ax			; source segment is save area
	lodsw				; get screen length
	mov	cx,ax			; counter of vscreen lines to do
tswapi2:push	cx			; save line counter
	lodsw				; get count of saved chars of line
	dec	ax			; omit repeated char til next step
	mov	cx,ax			; count for saved char writes
	rep	movsw			; copy saved chars except last one
	mov	cx,vswidth		; total line width (chars)
	sub	cx,ax			; minus those done
	lodsw				; get last char (this repeats to end)
	rep	stosw			; repeat last char
	pop	cx			; recover line counter
	loop	tswapi2			; do all text lines (omit status)
	pop	ds			; restore DS, SI is ready for nxt grp
					; end of virtual screen restoration
					; attributes, vsatt, for vscreen
	les	di,vsat_ptr		; seg and offset of vsatt
	mov	ax,tsave[bx]		; starting paragraph of save area
	push	ds
	mov	ds,ax			; source segment is save area
	lodsw				; get screen length
	mov	cx,ax			; counter of vsattr lines to do
tswapi7:push	cx			; save line counter
	lodsw				; get count of saved bytes of line
	dec	ax			; omit repeated byte til next step
	mov	cx,ax			; count for saved byte writes
	shr	cx,1			; do odd byte copy
	jnc	tswapi7a		; nc = even count
	movsb
tswapi7a:rep	movsw			; copy saved bytes except last one
	mov	cx,vswidth		; total line width (bytes)
	sub	cx,ax			; minus those done
	lodsb				; get last byte (this repeats to end)
	rep	stosb			; repeat last byte
	pop	cx			; recover line counter
	loop	tswapi7			; do all text lines (omit status)
	pop	ds			; restore DS, SI is ready for nxt grp
					; end of virtual screen restoration

	mov	ax,ds			; regular data seg "data"
	mov	es,ax			; new data seg
	mov	di,offset saveyoff	; offset of MSY save area
	mov	cx,saveylen		; length of MSY save area
	mov	ax,tsave[bx]		; starting paragraph of save area
	push	ds
	mov	ds,ax			; source segment is save area
	cld
	shr	cx,1			; even/odd?
	jnc	termsi3			; nc = even
	movsb				; the odd byte
termsi3:rep	movsw
	mov	di,offset savezoff	; offset of MSZ save area
	mov	cx,es:savezlen		; length of MSZ save area
	shr	cx,1
	jnc	termsi4
	movsb
termsi4:rep	movsw
	mov	di,offset savexoff	; offset of MSX save area
	mov	cx,es:savexlen		; length of MSX save area
	cli				; cautious about serial ints
	shr	cx,1
	jnc	termsi5
	movsb
termsi5:rep	movsw
	sti
	mov	di,offset savepoff	; offset of MSSCMD parser area
	mov	cx,es:saveplen		; length
	shr	cx,1
	jnc	termsi6
	movsb
termsi6:rep	movsw
	mov	di,offset saveuoff	; offset of MSUIBM kbd area
	mov	cx,es:saveulen		; length
	shr	cx,1
	jnc	termsi6a
	movsb
termsi6a:rep	movsw

ifndef	no_graphics
	mov	di,offset savegoff	; offset of MSGIBM area
	mov	cx,es:saveglen		; length
	shr	cx,1
	jnc	termsi8
	movsb
termsi8:rep	movsw
endif	; no_graphics
	pop	ds
	mov	cx,ds
	mov	es,cx
	mov	cx,size flginfo		; length of saved flags array
	mov	si,offset saveflag	; saved array
	mov	di,offset flags		; working array
	rep	movsb			; restore
	mov	ah,savattr		; get saved coloring
	mov	scbattr,ah		; replace what DOS may have used
	and	tekflg,not tek_active	; say graphics is not active
	pop	es
	pop	di
	pop	si
	pop	cx
	pop	bx
	pop	ax
	call	termswapdel		; delete this saved area, BL=session
	clc
	ret
termswapin endp

; Remove saved terminal emulator buffers, BX is sescur (-1 means all)
termswapdel proc far
	cmp	bx,-1			; all?
	jne	tswapdw			; ne = no, just one
	mov	cx,6			; number of possible sessions
	push	bx
	xor	bx,bx			; session index
tswapd1:call	tswapdw			; delete bufs for this session (BX)
	inc	bx
	loop	tswapd1			; and all others
	pop	bx
	ret

tswapdw	proc	far			; worker within termswapdel
	push	ax			; delete session BX
	push	bx
	cmp	bx,5			; largest session
	ja	tswapd2			; a = illegal, ignore
	shl	bx,1			; to words
	xor	ax,ax			; clearing indicator
	xchg	ax,tsave[bx]		; paragraph of save area
	or	ax,ax			; anything there?
	jnz	tswapd3			; nz = yes
tswapd2:pop	bx
	pop	ax
	stc
	ret

tswapd3:
ifndef	no_graphics
	push	es
	push	ax			; save seg of save buffer
	push	cx
	mov	es,ax			; seg of save buffer
	xor	si,si			; offset in save area of softlist
	mov	cx,31			; number of entries
	cld
tswapd4:lodsw				; saved segs of soft font in msgibm
	or	ax,ax			; any seg defined?
	jz	tswapd5			; z = no
	push	es
	mov	es,ax			; set paragraph to es for DOS
	mov	ah,freemem
	int	dos
	pop	es
tswapd5:loop	tswapd4
	pop	cx
	pop	es			; recover seg of save buffer from AX
	mov	ah,freemem		; free the memory
	int	dos
	pop	es
endif	; no_graphics

	pop	bx
	pop	ax
	clc
	ret
tswapdw	endp

termswapdel endp

; Examine vscreen line by line. Count number of characters by excluding the
; trailing repetitions (keep first example) on each line, sum them. Add to 
; the sum a word per line to hold the count of such characters and one more 
; word to hold the screen length.
; Return the number of bytes in register bx for malloc-ing.
getvssize proc	near
	push	ax
	push	cx
	push	dx
	push	di
	push	es
	les	di,vs_ptr		; pointer to vscreen
	xor	bx,bx			; line counter
	mov	cl,crt_lins		; lines on screen - 1
	xor	ch,ch
	inc	cl			; add status line
	mov	dx,cx			; accumulated count <cnt, line>
	inc	dx			; count screen size word itself
	add	di,(vswidth - 1) * 2	; offset of last char on the line
getvssi1:push	cx			; save line counter
	mov	cx,vswidth-1		; chars on line - 1
	mov	ax,es:[di]		; get last char+attrib on the line
	push	di
	sub	di,2
	std				; scan backward
	repe	scasw			; scan while equal (trim trailing rpt)
	cld
	pop	di
	je	getvssi2		; e = ended on all same char
	inc	cx			; ne case gobbles extra char
getvssi2:inc	cx			; count the trailing char
	mov	word ptr rdbuf[bx],cx	; store number of words here
	add	dx,cx			; accumulate count of chars
	add	bx,2			; next line
	add	di,vswidth*2		; end of next line
	pop	cx			; line counter
	loop	getvssi1

	add	dx,dx			; chars to bytes accumulated
	mov	bx,dx			; return it in bx
	pop	es
	pop	di
	pop	dx
	pop	cx
	pop	ax
	ret
getvssize endp

; Examine vsattr line by line. Count number of attributes by excluding the
; trailing repetitions (keep first example) on each line, sum them. Add to 
; the sum a word per line to hold the count of such characters and one more 
; word to hold the screen length. Stores temp length indicator in
; words rdbuf+120 et seq (one word per line).
; Return the number of bytes in register bx for malloc-ing.
getvasize proc	near
	push	ax
	push	cx
	push	dx
	push	di
	push	es
	les	di,vsat_ptr		; pointer to vsattr
	xor	bx,bx			; line counter
	mov	cl,crt_lins		; lines on normal screen - 1
	inc	cl			; include status line
	xor	ch,ch
	mov	dx,cx			; accumulated count <cnt, line>
	inc	dx			; count screen size word itself
	add	dx,dx			; convert to bytes used
	add	di,vswidth - 1		; offset of last attrib on the line
getvasi1:push	cx			; save line counter
	mov	cx,vswidth -1		; bytes on line - 1
	mov	ax,es:[di]		; get last attribute byte on the line
	push	di
	dec	di
	std				; scan backward
	repe	scasb			; scan while equal (trim trailing rpt)
	cld
	pop	di
	je	getvasi2		; e = ended on all same byte
	inc	cx			; ne case gobbles extra byte
getvasi2:inc	cx			; count the trailing byte
	mov	word ptr rdbuf[bx+120],cx; store number of bytes here
	add	dx,cx			; accumulate count of bytes
	add	bx,2			; next line
	add	di,vswidth		; end of next line
	pop	cx			; line counter
	loop	getvasi1
	mov	bx,dx			; return bytes needed in bx
	pop	es
	pop	di
	pop	dx
	pop	cx
	pop	ax
	ret
getvasize endp
endif	; no_tcp

;
; CHKDSP - procedure to check for hardware support of 132 cols
;  Supported hardware:
;  ATI EGA and VGA Wonder
;  AT&T
;  Everex Viewpoint EV-659, FVGA-673, EV-678, Micro Enhancer Deluxe
;  IBM XGA
;  Paradise AutoSwitch EGA Mono, VGA Professional, VGA Plus, VGA Plus 16
;  STB VGA/EM (Tseng TVGA)
;  STB VGA/EM Plus (Tseng 4000), VGA/EM-16, VGA/EM-16 Plus
;  Tseng Labs EVA board w/132-col kit installed
;  Tseng Labs UltraPAK mono/Herc board w/132 column modes.
;  Tseng Labs ET4000 SVGA.
;  VESA compatible Bios'.
;  Video 7 Vega Deluxe w/ 132X25.COM driver installed and VGA board.
; The routine checks for the presence of a 132-column-capable adapter. If
; one is found its handler executes the desired mode setting and returns
; carry clear; it returns carry set otherwise.
; Adding new boards - place an identification string in the data segment,
; construct a mode setting routine and insert it in the call list below
; (setting 132 column mode is byte AL non-zero). Byte AH is non-zero to
; avoid saving old screen and running scrini; it is used to set the screen
; width when starting/exiting Connect mode
;
chgdsp	proc	near
ifndef	no_graphics
	or	al,al			; 80 column mode?
	jnz	chgdsg1			; nz = no, want 132 cols
	test	tekflg,tek_active	; graphics mode active?
	jz	chgdsp_start		; z = no
	push	ax
	push	dx
	call	tekend			; exit special graphics
	call	scrmod			; update video mode info
	pop	dx
	pop	ax
	jmp	short chgdsp_start	; set 80 col mode

chgdsg1:test	vtemu.vtflgop,vscompress ; allowed to use graphics for it?
	jnz	chgdsp_start		; nz = no, use 132 column text mode
	cmp	tekflg,tek_active+tek_sg ; special graphics mode active?
	je	chgdsg3			; e = yes, no change needed
	mov	cl,byte ptr low_rgt+1	; examine whole screen
	add	cl,2			; lines in emulation part + status
	xor	ch,ch
	xor	bx,bx
chgdsg2:or	dgwindcomp[bx],1	; set compressed mode flag non-zero
	inc	bx
	loop	chgdsg2
	call	dgsettek		; setup special graphics mode
chgdsg3:mov	byte ptr low_rgt,131	; 132 columns in special graphics
	mov	crt_cols,128		; but 128 physical columns
	ret
endif	; no_graphics

chgdsp_start:
	push	es			; save all we use
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	mov	temp,ax			; save set/reset flag from msz
	mov	ax,sp			; do push sp test for XT vs AT/386
	push	sp			; XT pushes sp-2, AT's push old sp
	pop	cx			; recover pushed value, clean stack
	xor	ax,cx			; same?
	jne	chgdspnw		; ne = no, XT. Don't do Int 2fh
	test	tv_mode,10h		; DESQview active?
	jz	chgdspndv		; z = no
	jmp	chgdsx1			; exit without screen change
chgdspndv:
	cmp	vchgmode,1		; change permissions, disabled?
	je	chgdspnw		; e = 1 = disabled
	mov	ax,1683h		; Windows 3, get current virt machine
	int	2fh
	cmp	ax,1683h		; virtual machine, if any
	je	chgdspok		; e = none
	cmp	vchgmode,2		; DOS-only (2)?
	jne	chgdspok		; ne = no
chgdspnw:jmp	chgdsx1			; exit without screen change
chgdspok:mov	ax,temp
	cmp	crt_cols,80		; are we narrow?
	jbe	chgds3			; be = narrow width now
	or	al,al			; resetting to narrow width?
	jz	chgds4			; z = yes, do it
	jmp	chgdsx1			; else we are there now
chgds3:	or	al,al			; resetting to narrow width?
	jnz	chgds4			; nz = no, setting to wide
	jmp	chgdsx1			; narrow width, we are there now
chgds4:	or	ah,ah			; are we connected now?
	jnz	chgds0			; nz = no, skip flow control etc
	mov	ah,flowoff		; get xoff
	or	ah,ah			; flow control?
	jz	chgds4a			; z = none
	call	foutchr			; send it
chgds4a:cmp	byte ptr temp+1,0	; exiting Connect mode?
	jne	chgds0			; ne = yes
	mov	ax,200			; wait 200 millisec before video tests
	call	pcwait			; so don't mix screen and port intrpts

chgds0:	call	ckteva			; try Tseng Labs EVA
	jnc	chgds1			; nc = found
	call	ckstbv			; try STB VEGA/EM
	jnc	chgds1			; nc = found
	call    ckv7vd			; try Video 7 EGA Deluxe and VGA
	jnc	chgds1			; nc = found
	call    ckatiw			; try ATI EGA Wonder
	jnc	chgds1			; nc = found
	call    ckevrx                  ; try Everex Micro Enhancer Deluxe
	jnc     chgds1                  ; nc = found
	call	ckevga			; try Everex EVGA-673
	jnc     chgds1                  ; nc = found
	call	ckatt			; ATT boards
	jnc	chgds1			; nc = found
	call	chkpa			; Paradise EGA/VGA boards
	jnc	chgds1			; nc = found
	call	chkvesa			; VESA compatibles
	jnc	chgds1			; nc = found
	call	ckxga			; IBM XGA
	jnc	chgds1			; nc = found
	mov	si,offset cols80	; name of 80 column file
	cmp	byte ptr temp,0		; setting 80 cols?
	je	chgdsx2			; e = yes
	mov	si,offset cols132	; use 132 column file
chgdsx2:mov	di,offset decbuf	; a temp buffer for path= usage
	call	strcpy
	mov	ax,di			; spath wants ptr in ax
	call	fspath
	jc	chgdsx			; c = file not found
	mov	si,ax			; crun wants ptr in si
	call	fcrun			; run the batch file, si = filespec
	call	fserini			; reengage serial port, mode changes
	mov	ax,0c06h		; clear kbd buffer and do function
	mov	dl,0ffh			; console input
	int	dos			; discard character(s)
					; Perform mode change
chgds1:	cmp	byte ptr temp+1,0	; do without serial port xon/xoff?
	jne	chgdsx1			; ne = yes
	cmp	flags.modflg,1		; is mode line enabled?
	jbe	chgdsx			; be = yes, and off or locally owned
	mov	flags.modflg,1		; remove foreign ownership
chgdsx:	mov	ah,flowon		; get flow-on byte
	or	ah,ah			; using flow control?
	jz	chgdsx1			; z = no
	call	foutchr			; send it
chgdsx1:mov	al,crt_lins		; previous conditions
	mov	ah,crt_cols
	push	ax
	call	scrmod			; pick up current screen size
	pop	ax
ifndef	no_tcp
	cmp	al,crt_lins		; screen size change?
	jne	chgdsx1a		; ne = yes
	cmp	ah,crt_cols
	je	chgdsx1b		; no
chgdsx1a:call	winupdate		; window update req for TCP/IP Telnet
chgdsx1b:
endif	; no_tcp
	pop	di			; restore what we saved
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	pop	es
	ret				; return to caller
     
; Individual tests for various 132-column boards
					; Tseng LABS EVA, UltraPAK, ET4000
ckteva: mov	ax,0c000h		; seg addr for EVA
	mov	es,ax			; set into es register
	mov	di,76h			; offset of board's string
	lea	si,tsngid		; validation string
	mov	cx,tsnglen		; length of validiation string
	cld
	repe	cmpsb			; compare strings
	je	ckteva2			; e = strings match
	mov	ax,4d00h		; check for UltraPAK mono driver
	int	screen
	cmp	ax,5aa5h		; driver signature?
 	jne	ckteva4			; ne = no
	mov	ax,7			; default to mono (7) for this board
	cmp	byte ptr temp,0		; setting 132 columns?
	je	ckteva1			; e = resetting to normal
	mov	ax,18h			; set to 132 cols (Set Mode 18H)
ckteva1:int	screen
	clc				; carry clear means success
	ret
					; an EVA board - check for 132 col kit
ckteva2:cmp	byte ptr es:099h,0	; check 132 col kit installed
	jne	catfnd			; ne = installed, do the mode change
ckteva3:stc				; indicate adapter not present
	ret				; and exit

ckteva4:mov	dx,03cdh		; ET4000 test
	in	al,dx			; Segment Select Register, get value
	push	ax
	xor	al,15h			; create test condition
	jmp	$+2
	jmp	$+2
	out	dx,al			; set condition
	jmp	$+2
	jmp	$+2
	mov	ah,al			; save condition
	in	al,dx			; get new condition
	jmp	$+2
	jmp	$+2
	cmp	ah,al			; did it work (same)?
	pop	ax
	out	dx,al			; restore original condition
	jne	ckteva3			; ne = no, ET4000 not present
	mov	ax,3			; default to cga 3
	cmp	byte ptr temp,0		; setting 132 columns?
	je	ckteva5			; e = resetting to normal
	mov	ax,23h			; set to 132 cols (Set Mode 23H)
ckteva5:int	screen
	clc
	ret
					;
ckstbv:	mov	ax,0c000h		; STB's VGA/EM, VGA/EM-16, EM-16 Plus
	mov	es,ax			;
	mov	di,70h			; where to look for signature
	lea	si,stbvid		; the signature
	mov	cx,stbvlen		;
	cld				;
	repe	cmpsb			; test
	je	catfnd			; e = found
	mov	di,70h			; where to look for signature
	lea	si,stavid		; the signature
	mov	cx,stavlen
	cld
	repe	cmpsb			; test
	je	catfnd			; e = found
	stc				; else say not there
	ret				;
					; ATI EGA Wonder
ckatiw:	mov	ax,0c000h		; seg addr for EGA Wonder
	mov	es,ax			; set into es register
	mov	di,012fh		; offset of message in ROM
	lea	si,atiwid		; offset of message here
	mov	cx,atilen		; length of validation string
	cld
	repe	cmpsb			; compare strings
	je	catfnd			; e = they match
	lea	si,atiwid2		; alternative signature
	mov	di,30h			; start at this offset
	mov	cx,atilen2		; alternative signature length
	mov	ax,es:[di]		; get first two bytes
	cmp	al,atiwid2		; string starts here?
 	je	ckatiw1			; e = yes
	inc	di			; try next location, just in case
	cmp	ah,atiwid2		; or here?
	je	ckatiw1			; e = yes
	stc				; strings differ
	ret
ckatiw1:repe	cmpsb			; check the whole string
	je	catfnd			; e = matches the whole thing
	stc				; fail on mismatch
	ret
catfnd:	mov	ax,0003h		; prepare to reset video mode
	cmp	byte ptr temp,0		; are we setting or resetting?
	je	catfnd1			; e is reset, exit
	mov	ax,0023h		; set to 132 cols (Set Mode 23H)
catfnd1:int	screen
	clc				; carry clear means success
	ret

chkpa:	mov	ax,0c000h		; load Paradise ROM BIOS address
	mov	es,ax
	mov	ax,0057h		; assume 132x25 mono display needed
	mov	di,0009h		; load EGA board identifier index
	lea	si,pmega1		; Paradise Autoswitch Mono ident
	mov	cx,pmegal1
	cld
	repe	cmpsb			; do identification strings match?
	je	chgpa2			; e = yes, check num of display lines
	mov	di,007dh		; no, load VGA board identifier index
	lea	si,p30id		; Paradise VGA, other flavors
	mov	cx,p30ln
	repe	cmpsb			; do identification strings match?
	je	chgpa1			; e = yes, check for color mode
	stc				; fail
	ret
chgpa1:	cmp	crt_norm,3		; is the "normal" screen in color?
	ja	chgpa2			; a = no, orig assumption is correct
	mov	ax,0055h		; assume 132x25 color required
chgpa2:	cmp	crt_lins,25		; is the "normal" screen 25 lines?
	jna	chgpa3			; na = yes, check num of cols needed
	dec	ax			; change assumption to 132x43
chgpa3:	cmp	byte ptr temp,0		; switching to a 132 column mode?
	jne	chgpa4			; ne = yes
	mov	al,crt_norm		; load "normal" display mode
chgpa4:	int	screen			; issue BIOS call to change display
	clc				; success
	ret
					; Video 7 Vega Deluxe
ckv7vd:	mov	ax,0c000h		; seg addr for Vega rom bios
	mov	es,ax			; set into es register
	mov	di,002ah		; offset of message in ROM
	lea	si,vid7id		; offset of message here
	mov	cx,vid7len
	cld
	repe	cmpsb			; compare strings
	je	cnv7fn1			; e = same
	mov	di,002ah		; offset of ident string
	mov	si,offset vid7id2	; Video 7 VGA board
	mov	cx,vid7len2
	repe	cmpsb
	je	cnv7fn2			; e = found
cnv7fx:	stc				; strings are different
	ret
					;
cnv7fn1:test	byte ptr es:[03ffeh],1	; is this a 'Deluxe' Vega?
	jz	cnv7fx			; z = nope, can't do it
	mov	ah,35h			; DOS Get Vector
	mov	al,10h			; Bios video interrupt
	int	dos			; get it into es:bx
	mov	di,bx			; es:bx is returned int 10h entry pnt
	sub	di,5ah			; back offset to msg in 132X25.COM
	lea	si,vid7id		; offset of validation message
	mov	cx,vid7len		; length of validation string
	cld
	repe	cmpsb			; Look for repeat of msg by 132X25.COM
	jne	cnv7fn2			; if different
	mov	al,crt_mode		; prepare to reset video mode
	xor	ah,ah
	cmp	byte ptr temp,0		; are we setting or resetting?
	je	cnv7fn2a		; e is reset
	mov	ax,0000h		; set to 132 cols (old 40x25)
cnv7fn1a:int	screen
	clc
	ret

cnv7fn2:mov	ax,6f00h		; check for VegaBios driver
	int	screen
	cmp	bx,'V7'			; Video 7 Bios presence response
	jne	cnv7fx			; ne = not there
	mov	ax,6f01h		; al gets monitor type (mono,color,ega)
	int	screen
	mov	bx,51h			; presume mono 132x25, page 0
	cmp	crt_lins,42		; 43 lines active?
	jb	cnv7fn2a		; b = no
	inc	bx			; use bx = 52h for 132x43
cnv7fn2a:
	cmp	al,10h			; analogue fixed freq (IBM 85xx)?
	je	cnv7fx			; e = yes, no 132 columns
	cmp	al,2			; 1 = mono, 2 = color, above = ega
	jb	cnv7fn3			; b = mono or unknown
	mov	bx,4fh			; presume med res color 132x25
	je	cnv7fn3			; e = med res color, al = 2
	mov	bx,41h			; ega high res 132x25, enhanced mons
	cmp	crt_lins,42		; 43 lines active?
	jb	cnv7fn3			; b = no
	inc	bx			; use bx = 42h for 132x43
cnv7fn3:mov	ax,6f05h		; set special mode found in bl
	cmp	byte ptr temp,0		; resetting to 80 column mode?
	jne	cnv7fn4			; ne = no, setting 132x25
	mov	al,crt_norm		; get normal mode
	xor	ah,ah			; set mode
	cmp	crt_lins,42		; 43 lines active?
	jb	cnv7fn4			; b = no
	mov	bl,40h			; use Video 7 mode 40h 80x43 for color
	mov	ax,6f05h		; and do special mode set
cnv7fn4:int	screen			; special mode is in bl
	mov	ax,0f00h		; a nop screen bios command
	int	screen
	clc
	ret

ckevrx: mov     ax,0c000h               ; seg addr for Everex EV-659
        mov     es,ax                   ; set into es register
        mov     di,0047h                ; offset of message in ROM
        lea     si,evrxid               ; offset of message here
        mov     cx,evrxlen              ; length of validation string
        cld
        repe    cmpsb                   ; compare strings
        jne     ckfnr2                  ; ne = strings differ
        mov     ah,crt_lins             ; we recognize either 44 or 25 rows
        cmp     ah,43                   ; equal to 44-1 rows?
        jne     ckfnr1                  ; ne = no
        mov     ax,0070h                ; Everex extended mode ident
        mov     bl,09h                  ; prepare to reset video mode to 80x44
        cmp     byte ptr temp,0         ; are we setting or resetting?
        je      ckfnr4                  ; e is reset, exit
        mov     bl,0bh                  ; 132x44
	int	screen
	clc
	ret
ckfnr1: cmp     ah,24                   ; equal to 25-1 rows?
	je	ckfnr3			; e = yes
ckfnr2:	stc				; return failure
	ret
ckfnr3:	mov     ax,0003h                ; prepare to reset video mode
        cmp     byte ptr temp,0         ; are we setting or resetting?
        je      ckfnr4                  ; e is reset, exit
        mov     ax,0070h                ; Everex extended mode ident
        mov     bl,0ah                  ; 132x25
ckfnr4:	int	screen
	clc
	ret
ckevga:	mov	ax,0c000h		; Everex FVGA-673, EV-678 rom segment
	mov	es,ax
	mov	di,76h			; offset in rom for board's id string
	lea	si,evgid		; id string
	mov	cx,evglen		; length of id string
	cld
	repe	cmpsb			; do they match?
	je	ckevg0			; e = yes
	mov	di,9dh			; offset in ROM for board's ID string
	lea	si,evvid		; ID string
	mov	cx,evvlen		; length of ID string
	cld
	repe	cmpsb			; do they match?
	jne	ckevg2			; ne = no
ckevg0:	mov	ax,3			; prepare to reset video mode
	cmp	byte ptr temp,0		; setting or resetting mode?
	je	ckevg1			; e = resetting, exit
	mov	ax,0070h		; mode for 132x25
	mov	bl,0ah			; Everex mode 0ah
ckevg1:	int	screen
	clc
	ret
ckevg2:	stc				; say board not found
	ret
					; AT&T EGA/VGA boards
ckatt:	mov	ax,0c000h		; seg of first signature
	mov	es,ax
	mov	si,offset attvdc6	; first pattern
	mov	di,35h			; test area
	cld
	mov	cx,attvdlen		; length
	repe	cmpsb
	je	ckatt2			; e = found
	mov	cx,attvdlen		; try second signature, same length
	mov	si,offset attvdc7
	mov	ax,0e000h		; seg of second signature
	mov	es,ax
	mov	di,10h			; test area
	repe	cmpsb
	je	ckatt2			; e = found
	stc				; not found
	ret
ckatt2:	mov	al,crt_norm		; old mode
	xor	ah,ah
	cmp	byte ptr temp,0		; resetting to 80 col?
	je	ckatt3			; e = yes
	mov	ax,0055h		; 132 cols, set mode 55h
ckatt3:	int	screen
	clc
	ret
					; VESA compatibles
chkvesa:mov	di,seg rdbuf		; es:di is buffer for results
	mov	es,di
	mov	di,offset rdbuf
	mov	ax,4f00h		; get SVGA information
	int	screen
	cmp	ax,4fh			; success?
	jne	chkvesax		; ne = no
	cmp	word ptr rdbuf,'EV'	; 'VESA'
	jne	chkvesax		; ne = no
	cmp	word ptr rdbuf+2,'AS'
	jne	chkvesax		; ne = no
	mov	ax,4f01h		; get mode info to es:di buffer
	mov	cx,109h			; 109h is 132x25 text
	int	screen
	cmp	ax,4fh			; success?
	jne	chkvesax		; ne = no
	mov	bx,3			; assume 80 columns
	cmp	byte ptr temp,0		; setting or resetting mode?
	je	chkvesa2		; e = resetting
	mov	bx,109h			; mode for 132x25
chkvesa2:mov	ax,4f02h		; set mode from bx
	int	screen
	cmp	ax,4fh			; success?
	jne	chkvesax		; ne = no
	clc				; say success
	ret
chkvesax:stc				; say failure
	ret

					; IBM XGA 132 columns
ckxga:	push	bp			; (old BIOSes are still around)
	push	ds			; set es to data segment
	pop	es
	mov	ax,1b00h		; get functionality table
	xor	bx,bx
	mov	di,offset decbuf	; es:di is 64 bytes of workspace
	int	screen
	cmp	al,1bh			; is this call supported?
	jne	ckxgax			; ne = no, fail
	les	bx,dword ptr decbuf	; get the address of the modes info
	test	byte ptr es:[bx+2],10h	; is mode 14h supported?
	jz	ckxman			; z = no, try manual method for now
	mov	ax,3			; assume resetting to mode 3, 80x25
	cmp	byte ptr temp,0		; setting 132 columns?
	je	ckxga1			; e = no, resetting to 80 columns
	mov	ax,14h			; invoke IBM XGA mode 14h, 132x25
ckxga1:	int	screen
ckxga2:	pop	bp
	clc				; say success
	ret
ckxgax:	pop	bp
	mov	xga_reg_base,-2		; flag saying no XGA Adapter found
	stc				; say failure
	ret

ckxman:	call	xgaman			; do tests/sets manually
	pop	bp
	jnc	ckxman1			; nc = success
	mov	xga_reg_base,-2		; flag saying no XGA Adapter found
ckxman1:ret
chgdsp	endp

; XGA mode setting via going to the hardware manually
; Code furnished by Bert Tyler, National Institue of Health

xgaman	proc	near
	cmp	xga_reg_base,-2		; has the XGA detector already failed?
	je	xgafail			; e = yes, fail again
	cmp	xga_reg_base,-1		; have we already found the XGA?
	je	xga_loc			; e = no
	jmp	xga_do1			; yes, process it
xga_loc:push	es
	mov	ah,35h			; DOS get interrupt vector
	mov	al,15h			; Int 15h
        int     dos                     ; returns vector in es:bx
	mov	ax,es			; segment part
	pop	es
	or	ax,ax			; undefined vector?
	jz	xgafail			; z = yes
	mov	dx,-1			; start with an invalid POS address
	mov	ax,0c400h		; look for POS base address
	int	15h			;  (Microchannel machines only)
	jc	xgafail			; c = error, not a MC machine
	mov	xgatmp1,dx		; save pos_base_address
	xor	cx,cx			; check all MCA slots & motherboard
	cmp	dx,-1			; do we have a good POS?
	jne	xga_lp1			; ne = yes, proceed with MCA checks
xgafail:stc				; fail
	ret

xga_lp1:cli				; no interrupts, please
	cmp	cx,0			; treat the motherboard differently?
	jne	xga_sk4			; ne = yes
	mov	al,0dfh			; enable the motherboard for setup
	mov	dx,94h
	out	dx,al
	jmp	short xga_sk5
xga_sk4:mov	ax,0c401h		; enable an MCA slot for setup
	mov	bx,cx			;  this slot
	int	15h
xga_sk5:mov	dx,xgatmp1		; get pos record for the slot
	in	ax,dx			;  ID
	mov	xgatmp2,ax
	add	dx,2			; compute IO Res Base
	in	al,dx			;  get POS data byte1
	and	ax,0eh			;  muck about with it to get reg base
	shl	ax,1
	shl	ax,1
	shl	ax,1
	add	ax,2100h
	mov	xga_reg_base,ax
	cmp	cx,0			; treat the motherboard differently?
	jne	xga_sk6			; ne = yes
	mov	al,0ffh			; enable the motherboard for normal
	out	094h,al
	jmp	short xga_sk7
xga_sk6:mov	ax,0c402h		; enable the MCA slot for normal
	mov	bx,cx			;  this slot
	int	15h
xga_sk7:sti				; interrupts on again

	mov	ax,xgatmp2		; is an XGA adapter on this slot?
	cmp	ax,08fd8h
	jae	xga_sk8			; ae = yes
	jmp	xga_lp2			; try another slot
xga_sk8:cmp	ax,08fdbh		; still within range?
	jbe	xga_sk9			; be = yes
	jmp	xga_lp2			; no, try another slot
xga_sk9:mov	dx,xga_reg_base		; is there a monitor on this slot?
	add	dx,0ah
	mov	al,052h
	out	dx,al
	mov	dx,xga_reg_base
	add	dx,0bh
	in	al,dx
	and	al,0fh
	cmp	al,0fh
	jne	xga_ska			; ne = yes
	jmp	xga_lp2			; no
xga_ska:mov	dx,xga_reg_base		; is this XGA in VGA mode?
	in	al,dx
	test	al,1
	jnz	xga_do1			; nz = yes, found it!

xga_lp2:inc	cx			; try another adapter?
	cmp	cx,9			; done all slots?
	ja	xga_no			; a = yes
	jmp	xga_lp1			; no, try another slot
xga_no:	jmp	xgafail			; fail

;	*finally* put the XGA into 132-column or 80-column mode

xga_do1:cmp	byte ptr temp,0		; setting 80-column mode?
	jne	xga_do2			; ne = no, 132 columns
	jmp	xga_do3			; do 80 column mode

					; 132-column mode routine
xga_do2:mov	dx,xga_reg_base		; (the manual doesn't explain...)
	add	dx,0ah
	mov	ax,1550h
	out	dx,ax
	mov	ax,1450h
	out	dx,ax
	mov	ax,0454h
	out	dx,ax
	mov	ax,1202h		; select 400 scan lines
	mov	bl,30h
	int	screen
	mov	ax,0+3			; set video mode 3
	int	screen

	mov	dx,xga_reg_base		; (the manual doesn't explain...)
	add	dx,0ah
	mov	al,50h
	out	dx,al
	inc	dx
	in	al,dx
	or	al,1
	out	dx,al

	mov	dx,xga_reg_base		; (the manual doesn't explain...)
	add	dx,0ah
	mov	al,50h
	out	dx,al
	inc	dx
	in	al,dx
	and	al,0fdh
	out	dx,al

	mov	dx,xga_reg_base		; (the manual doesn't explain...)
	add	dx,0ah
	mov	al,50h
	out	dx,al
	inc	dx
	in	al,dx
	and	al,0fch
	out	dx,al

	mov	dx,xga_reg_base		; (the manual doesn't explain...)
	mov	al,3
	out	dx,al

	mov	dx,xga_reg_base		; (the manual doesn't explain...)
	add	dx,0ah
	mov	ax,0154h
	out	dx,ax
	mov	ax,8070h
	out	dx,ax

	mov	dx,xga_reg_base		; (the manual doesn't explain...)
	add	dx,0ah
	mov	al,50h
	out	dx,al
	inc	dx
	in	al,dx
	and	al,0efh
	out	dx,al

	mov	dx,03d4h		; (the manual doesn't explain...)
	mov	ax,11h
	out	dx,al
	inc	dx
	in	al,dx
	and	al,7fh
	out	dx,al

	mov	dx,03d4h		; (the manual doesn't explain...)
	mov	ax,0
	out	dx,al
	inc	dx
	mov	ax,0a4h
	out	dx,al

	mov	dx,03d4h		; (the manual doesn't explain...)
	mov	ax,1
	out	dx,al
	inc	dx
	mov	ax,83h
	out	dx,al

	mov	dx,03d4h		; (the manual doesn't explain...)
	mov	ax,2
	out	dx,al
	inc	dx
	mov	ax,84h
	out	dx,al

	mov	dx,03d4h		; (the manual doesn't explain...)
	mov	ax,3
	out	dx,al
	inc	dx
	mov	ax,83h
	out	dx,al

	mov	dx,03d4h		; (the manual doesn't explain...)
	mov	ax,4
	out	dx,al
	inc	dx
	mov	ax,90h
	out	dx,al

	mov	dx,03d4h		; (the manual doesn't explain...)
	mov	ax,5
	out	dx,al
	inc	dx
	mov	ax,80h
	out	dx,al

	mov	dx,xga_reg_base		; (the manual doesn't explain...)
	add	dx,0ah
	mov	ax,0a31ah
	out	dx,ax
	mov	ax,001bh
	out	dx,ax

	mov	dx,03d4h		; (the manual doesn't explain...)
	mov	ax,13h
	out	dx,al
	inc	dx
	mov	ax,42h
	out	dx,al

	mov	dx,03d4h		; (the manual doesn't explain...)
	mov	al,11h
	out	dx,al
	inc	dx
	in	al,dx
	or	al,80h
	out	dx,al

	mov	dx,xga_reg_base		; (the manual doesn't explain...)
	add	dx,0ah
	mov	al,50h
	out	dx,al
	inc	dx
	in	al,dx
	or	al,3
	out	dx,al

	mov	dx,03c4h		; (the manual doesn't explain...)
	mov	ax,1
	out	dx,al
	inc	dx
	in	al,dx
	or	al,1
	out	dx,al

	mov	dx,03dah		; (the manual doesn't explain...)
	in	al,dx

	mov	dx,003c0h		; (the manual doesn't explain...)
	mov	al,13h
	out	dx,al
	xor	al,al
	out	dx,al
	mov	al,20h
	out	dx,al

	mov	ax,40h			; tell the BIOS we have 132 columns
	mov	es,ax
	mov	byte ptr es:[4ah],132	; set Bios screen width data area
	clc				; return success
	ret
		    			; Set 80 column mode
xga_do3:mov	dx,xga_reg_base		; (the manual doesn't explain...)
	add	dx,01h
	xor	al,al
	out	dx,al

	mov	dx,xga_reg_base		; (the manual doesn't explain...)
	add	dx,4
	xor	al,al
	out	dx,al

	mov	dx,xga_reg_base		; (the manual doesn't explain...)
	add	dx,5
	mov	al,0ffh
	out	dx,al

	mov	dx,xga_reg_base		; (the manual doesn't explain...)
	add	dx,0ah
	mov	ax,0ff64h
	out	dx,ax

	mov	dx,xga_reg_base		; (the manual doesn't explain...)
	add	dx,0ah
	mov	ax,1550h
	out	dx,ax

	mov	dx,xga_reg_base		; (the manual doesn't explain...)
	add	dx,0ah
	mov	ax,1450h
	out	dx,ax

	mov	dx,xga_reg_base		; (the manual doesn't explain...)
	add	dx,0ah
	mov	ax,0051h
	out	dx,ax

	mov	dx,xga_reg_base		; (the manual doesn't explain...)
	add	dx,0ah
	mov	ax,0454h
	out	dx,ax

	mov	dx,xga_reg_base		; (the manual doesn't explain...)
	add	dx,0ah
	mov	ax,7f70h
	out	dx,ax

	mov	dx,xga_reg_base		; (the manual doesn't explain...)
	add	dx,0ah
	mov	ax,202ah
	out	dx,ax

	mov	dx,xga_reg_base		; (the manual doesn't explain...)
;;	add	dx,00h
	mov	al,1
	out	dx,al

	mov	dx,03c3h		; (the manual doesn't explain...)
	mov	al,1
	out	dx,al

	mov	ax,1202h		; select 400 scan lines
	mov	bl,30h
	int	screen
	mov	ax,0+3			; set video mode 3
	int	screen
	clc				; return success
	ret
xgaman	endp

; Routine to do keyclick if flag is set, no arguments
vclick	proc	near
	test	vtemu.vtflgop,vskeyclick ; is keyclick flag on?
	jz	vclick1			; z = no, just return
	push	bx
	push	di
	mov	di,500			; 500 Hertz
	mov	bx,1			; For 1 millisecond
	call	vtsound			; Do it
	pop	di			; Restore the ACs
	pop	bx
vclick1:ret
vclick	endp
endif	; no_terminal

; Routine to do VT100-style bell, no arguments
fvtbell	proc	far
	call	vtbell
	ret
fvtbell	endp

vtbell	proc	near
	cmp	belltype,1		; visual bell?
	je	vtbell1			; e = yes
	ja	vtbell2			; a = no bell
	push	di			; audible bell
	push	bx
	mov	di,880			; 880 Hertz
	mov	bx,40			; For 40 ms
	call	vtsound			; Do it
	pop	bx
	pop	di
	ret
vtbell1:
ifndef	no_terminal
	call	revscn			; reverse screen
	push	ax
	mov	ax,40			; for 40 milliseconds
	call	pcwait
	pop	ax
	call	revscn			; put back
endif	; no_terminal
vtbell2:ret
vtbell	endp

; Routine to make noise of arbitrary frequency for arbitrary duration.
; Similar to routine (with typo removed) in "IBM PC Assembly Language:
; A Guide for Programmers", Leo J. Scanlon, 1983 Robert J. Brady Co.,
; Bowie, MD., page 270. Modified by J R Doupnik to use 0.1 millsec interval.
; Call:		di/	frequency in Hertz.
;		bx/	duration in 1 millisecond units
vtsound proc	near
	push	ax			; save regs
	push	cx
	push	dx
	mov	al,0B6H			; write timer mode register
	out	43H,al
	mov	dx,14H			; timer divisor is
	mov	ax,4F38H		; 1331000/frequency
	div	di
	out	42H,al			; write timer 2 count low byte
	mov	al,ah
	out	42H,al			; write timer 2 count high byte
	in	al,61H			; get current port B setting
	or	al,3			; turn speaker on
	out	61H,al
	mov	ax,bx			; number of milliseconds to wait
	call	pcwait			; do the calibrated wait
	in	al,61H			; get current port B setting
	and	al,0fch			; turn off speaker and timer
	out	61H,al
	pop	dx			; restore regs
	pop	cx
	pop	ax
	ret
vtsound endp
code1	ends
	end
