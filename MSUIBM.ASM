	NAME	msuibm
; File MSUIBM.ASM 
	include mssdef.h
;	Copyright (C) 1982, 1999, Trustees of Columbia University in the 
;	City of New York.  The MS-DOS Kermit software may not be, in whole 
;	or in part, licensed or sold for profit as a software product itself,
;	nor may it be included in or distributed with commercial products
;	or otherwise distributed by commercial concerns to their clients 
;	or customers without written permission of the Office of Kermit 
;	Development and Distribution, Columbia University.  This copyright 
;	notice must not be removed, altered, or obscured.
; Keyboard translator, by Joe R. Doupnik, Dec 1986
;  with contributions from David L. Knoell.
; Edit history
; 12 Jan 1995 version 3.14
; Last edit
; 12 Jan 1995

	public	keybd, dfkey, shkey, msuinit, kbcodes
	public	kbsusp, kbrest, kbhold		;** LK250 support for IBM-PCs
	public	saveuoff, saveulen

; some definitions
kbint	equ	16h			; IBM, Bios keyboard interrupt
shift	equ	200h			; IBM, synonym for right or left shift
control	equ	400h			; IBM, synonym for control shift
alt	equ	800h			; IBM, synonym for alt shift
enhanced equ	1000h			; IBM, enhanced keyboard code

rgt_shift equ	1			; IBM shift state bits
lft_shift equ	2
ctl_shift equ	4
alt_shift equ	8
numlock	  equ	20h

maxkeys	equ	350			; maximum number of key definitions
maxstng	equ	256			; maximum number of multi-char strings
stbuflen equ	2000			; length of string buffer (bytes)

verb	equ	8000h			; dirlist flag: use verb action table
strng	equ	4000h			; dirlist flag: use string action table
scan	equ	100h			; keycode flag: code is scan not ascii
braceop	equ	7bh			; opening curly brace
bracecl	equ	7dh			; closing curly brace

data	segment
	extrn taklev:byte, comand:byte, flags:byte, keyboard:word
	extrn shkadr:word, stkadr:word, trans:byte, ttyact:byte
						; system dependent references
	extrn vtemu:byte, holdscr:byte		; emulator data
	extrn vtmacname:word, vtmaclen:word	; external macro, in msyibm
	extrn isps55:byte	; [HF]940130 in MSXIBM.ASM
	extrn ps55mod:byte	; [HF]940206 in MSXIBM.ASM
	extrn domath_ptr:word, domath_cnt:word, termesc_flag:byte
;;;	System Independent local storage

crlf	db	cr,lf,'$'
dfaskky	db	cr,lf,' Push key to be defined: $'
dfaskdf	db	' Enter new definition: ',0		; asciiz for prompt
strbad	db	cr,lf,' Not enough space for new string',cr,lf,'$'
keyfull	db	cr,lf,' No more space to define keys',cr,lf,'$'
dfkoops	db	cr,lf,' Oops! That is Kermit',27h,'s Escape Char.'
	db	' Translation is not permitted.',cr,lf,'$'
shkmsg1	db	cr,lf,'Push key to be shown (? shows all): $'
shkmsg2	db	' decimal is defined as',cr,lf,'$'
shkmsg3	db	cr,lf,'... more, press a key to continue ...$'
kwarnmsg db	cr,lf,' Notice: this form of Set Key is obsolete$'

ascmsg	db	' Ascii char: $'
scanmsg	db	' Scan Code $'
strngmsg db	' String: $'
verbmsg	db	' Verb: $'
noxmsg	db	' Self, no translation.$'
fremsg	db	cr,lf,' Free space: $'
kyfrdef	db	' key and $'
stfrdef db	' string definitions, $'
stfrspc	db	' string characters.',cr,lf,'$'
	even

saveuoff label	word			; per session save area start
tranbuf	db	150 dup (?)		; 150 byte translator work buffer
	db	0			; guard for overflow by one
					; translation tables
keylist	dw	maxkeys dup (0)		; 16 bit keycodes, paralled by dirlist
dirlist	dw	maxkeys dup (0)		; director {v+s} + {index | new char}
sptable	dw	maxstng dup (0)		; list of asciiz string offsets
stbuf	dw	stbuflen dup (0)	; buffer for strings
strmax	dw	stbuf			; first free byte in stbuf
stringcnt dw	0			; qty of string chars to be processed
stringptr dw	0			; address of next string char
nkeys	dw	0			; number of actively defined keys
listptr	dw	0			; item number for keylist and dirlist
keycode	dw	0			; ascii/scan code for key
kbtemp	dw	0			; scratch storage for translator
brace	db	0			; brace detected flag byte
msutake	db	0			; if being run from take file or not
verblen	dw	0			; length of user's verb (work temp)
kwcnt	dw	0			; number of keywords (work temp)
dosflg	db	0
saveulen dw	($ - saveuoff)		; save area end

oldform	db	0			; old form Set Key, if non-zero
eleven	dw	11d			; [HF]940211
twelve	dw	12d
;;;	End System Independent Data Area


	; Aliaskey: keys having aliases - same ascii code but more than one
	; scan code, as on auxillary keypads. Use just scan codes with these.
	; Alternative use: force ascii keys to report out just scan codes.
	; Table format: high byte = scan code, low byte = ascii code. 
	; Contents are machine dependent.
aliaskey dw	(14*scan)+bs		; Backspace key [hi=scan, lo=ascii]
	dw	(55*scan)+'*'		; keypad asterisk
	dw	(74*scan)+'-'		; keypad minus
	dw	(78*scan)+'+'		; keypad plus
	dw	(71*scan)+'7'		; keypad numeric area
	dw	(72*scan)+'8'
	dw	(73*scan)+'9'
	dw	(75*scan)+'4'
	dw	(76*scan)+'5'
	dw	(77*scan)+'6'
	dw	(79*scan)+'1'
	dw	(80*scan)+'2'
	dw	(81*scan)+'3'
	dw	(82*scan)+'0'
	dw	(83*scan)+'.'
	dw	(83*scan)+','		; German keypad had comma vs dot
	dw	(15*scan)+tab
	dw	(28*scan)+cr		; typewriter Enter key
	dw	(28*scan)+lf		; typewriter Control-Enter
	dw	(57*scan)+' '		; space bar
	dw	(01*scan)+1bh		; Esc key
aliaslen equ	($-aliaskey) shr 1	; number of words in aliaskey table

ifndef	no_network
kverbs	db	163			; number of table entries below
else
ifndef	no_tcp
kverbs	db	163 - 3			; number of table entries below
else
kverbs	db	163 - 4			; number of table entries below
endif	; no_tcp
endif	; no_network
	mkeyw	'uparr',uparrw		; independent of ordering and case!
	mkeyw	'dnarr',dnarrw		; mkeyw 'name',procedure entry point
	mkeyw	'lfarr',lfarr
	mkeyw	'rtarr',rtarr
	mkeyw	'Gold',pf1
	mkeyw	'PF1',pf1
	mkeyw	'PF2',pf2
	mkeyw	'PF3',pf3
	mkeyw	'PF4',pf4
	mkeyw	'KP0',kp0
	mkeyw	'KP1',kp1
	mkeyw	'KP2',kp2
	mkeyw	'KP3',kp3
	mkeyw	'KP4',kp4
	mkeyw	'KP5',kp5
	mkeyw	'KP6',kp6
	mkeyw	'KP7',kp7
	mkeyw	'KP8',kp8
	mkeyw	'KP9',kp9
	mkeyw	'kpminus',kpminus
	mkeyw	'kpcoma',kpcoma
	mkeyw	'kpenter',kpenter
	mkeyw	'kpdot',kpdot
	mkeyw	'decF6',decf6
	mkeyw	'decF7',decf7
	mkeyw	'decF8',decf8
	mkeyw	'decF9',decf9
	mkeyw	'decF10',decf10
	mkeyw	'decF11',decf11
	mkeyw	'decF12',decf12
	mkeyw	'decF13',decf13
	mkeyw	'decF14',decf14
	mkeyw	'decHelp',dechelp
	mkeyw	'decDo',decdo
	mkeyw	'decF17',decf17
	mkeyw	'decF18',decf18
	mkeyw	'decF19',decf19
	mkeyw	'decF20',decf20
	mkeyw	'decFind',decfind
	mkeyw	'decInsert',decinsert
	mkeyw	'decRemove',decremove
	mkeyw	'decSelect',decselect
	mkeyw	'decPrev',decprev
	mkeyw	'decNext',decnext
	mkeyw	'udkF6',udkf6
	mkeyw	'udkF7',udkf7
	mkeyw	'udkF8',udkf8
	mkeyw	'udkF9',udkf9
	mkeyw	'udkF10',udkf10
	mkeyw	'udkF11',udkf11
	mkeyw	'udkF12',udkf12
	mkeyw	'udkF13',udkf13
	mkeyw	'udkF14',udkf14
	mkeyw	'udkF15',udkf15
	mkeyw	'udkF16',udkf16
	mkeyw	'udkF17',udkf17
	mkeyw	'udkF18',udkf18
	mkeyw	'udkF19',udkf19
	mkeyw	'udkF20',udkf20
	mkeyw	'Compose',kbdcompose
	mkeyw	'termtype',vtans52
	mkeyw	'reset',vtinit
	mkeyw	'holdscrn',khold
	mkeyw	'dnscn',dnwpg
	mkeyw	'upscn',upwpg
	mkeyw	'endscn',endwnd
	mkeyw	'homscn',homwnd
	mkeyw	'upone',upone
	mkeyw	'dnone',dnone
	mkeyw	'prtscn',trnprs
	mkeyw	'dump',dmpscn
	mkeyw	'modeline',trnmod
	mkeyw	'break',sendbr
	mkeyw	'lbreak',sendbl
	mkeyw	'hangup',chang
	mkeyw	'debug',kdebug
ifndef	no_network
	mkeyw	'nethold',ubhold
endif	; no_network
ifndef	no_tcp
	mkeyw	'tn_AYT',tn_AYT
	mkeyw	'tn_IP',tn_IP
	mkeyw	'nextsession',nextses
	mkeyw	'session1',ses1
	mkeyw	'session2',ses2
	mkeyw	'session3',ses3
	mkeyw	'session4',ses4
	mkeyw	'session5',ses5
	mkeyw	'session6',ses6
endif	; no_tcp
	mkeyw	'null',snull
	mkeyw	'logon',klogon
	mkeyw	'logoff',klogof
	mkeyw	'DOS',cdos
	mkeyw	'help',cquery
	mkeyw	'status',cstatus
	mkeyw	'exit',cquit
	mkeyw	'lfpage',lfpage
	mkeyw	'rtpage',rtpage
	mkeyw	'lfone',lfone
	mkeyw	'rtone',rtone
	mkeyw	'dgC1',dgkc1
	mkeyw	'dgC2',dgkc2
	mkeyw	'dgC3',dgkc3
	mkeyw	'dgC4',dgkc4
	mkeyw	'dgF1',dgkf1
	mkeyw	'dgF2',dgkf2
	mkeyw	'dgF3',dgkf3
	mkeyw	'dgF4',dgkf4
	mkeyw	'dgF5',dgkf5
	mkeyw	'dgF6',dgkf6
	mkeyw	'dgF7',dgkf7
	mkeyw	'dgF8',dgkf8
	mkeyw	'dgF9',dgkf9
	mkeyw	'dgF10',dgkf10
	mkeyw	'dgF11',dgkf11
	mkeyw	'dgF12',dgkf12
	mkeyw	'dgF13',dgkf13
	mkeyw	'dgF14',dgkf14
	mkeyw	'dgF15',dgkf15
	mkeyw	'dgSF1',dgkSf1
	mkeyw	'dgSF2',dgkSf2
	mkeyw	'dgSF3',dgkSf3
	mkeyw	'dgSF4',dgkSf4
	mkeyw	'dgSF5',dgkSf5
	mkeyw	'dgSF6',dgkSf6
	mkeyw	'dgSF7',dgkSf7
	mkeyw	'dgSF8',dgkSf8
	mkeyw	'dgSF9',dgkSf9
	mkeyw	'dgSF10',dgkSf10
	mkeyw	'dgSF11',dgkSf11
	mkeyw	'dgSF12',dgkSf12
	mkeyw	'dgSF13',dgkSf13
	mkeyw	'dgSF14',dgkSf14
	mkeyw	'dgSF15',dgkSf15
	mkeyw	'dgspcl',kbdcompose
	mkeyw	'dgpoint',dgpoint
	mkeyw	'dgnc',dgnckey
	mkeyw	'wyseF1',wykf1
	mkeyw	'wyseF2',wykf2
	mkeyw	'wyseF3',wykf3
	mkeyw	'wyseF4',wykf4
	mkeyw	'wyseF5',wykf5
	mkeyw	'wyseF6',wykf6
	mkeyw	'wyseF7',wykf7
	mkeyw	'wyseF8',wykf8
	mkeyw	'wyseF9',wykf9
	mkeyw	'wyseF10',wykf10
	mkeyw	'wyseF11',wykf11
	mkeyw	'wyseF12',wykf12
	mkeyw	'wyseF13',wykf13
	mkeyw	'wyseF14',wykf14
	mkeyw	'wyseF15',wykf15
	mkeyw	'wyseF16',wykf16
	mkeyw	'wyseSF1',wykSf1
	mkeyw	'wyseSF2',wykSf2
	mkeyw	'wyseSF3',wykSf3
	mkeyw	'wyseSF4',wykSf4
	mkeyw	'wyseSF5',wykSf5
	mkeyw	'wyseSF6',wykSf6
	mkeyw	'wyseSF7',wykSf7
	mkeyw	'wyseSF8',wykSf8
	mkeyw	'wyseSF9',wykSf9
	mkeyw	'wyseSF10',wykSf10
	mkeyw	'wyseSF11',wykSf11
	mkeyw	'wyseSF12',wykSf12
	mkeyw	'wyseSF13',wykSf13
	mkeyw	'wyseSF14',wykSf14
	mkeyw	'wyseSF15',wykSf15
	mkeyw	'wyseSF16',wykSf16
	mkeyw	'ignore',ignore_key
					; Initialization data.
kbdinlst equ	this byte     ; Kermit IBM initialization time keyboard setup
	mkeyw	'\kgold',scan+59	; F1	mkeyw 'definition',keycode
	mkeyw	'\kpf2',scan+60		; F2
	mkeyw	'\kpf3',scan+61		; F3
	mkeyw	'\kpf4',scan+62		; F4
	mkeyw	'\kkp0',scan+shift+90	; VT100 keypad numeric area, SF7
	mkeyw	'\kkp1',scan+shift+86	; SF3
	mkeyw	'\kkp2',scan+shift+87	; SF4
	mkeyw	'\kkp3',scan+shift+88	; SF5
	mkeyw	'\kkp4',scan+67		; F9
	mkeyw	'\kkp5',scan+68		; F10
	mkeyw	'\kkp6',scan+shift+84	; SF1
	mkeyw	'\kkp7',scan+63		; F5
	mkeyw	'\kkp8',scan+64		; F6
	mkeyw	'\kkp9',scan+65		; F7
	mkeyw	'\kkpenter',scan+shift+89 ; SF6
	mkeyw	'\kkpcoma',scan+shift+85  ; SF2
	mkeyw	'\kkpminus',scan+66	; F8
	mkeyw	'\kkpdot',scan+shift+91	; SF8
	mkeyw	'\kuparr',scan+72	; VT100 cursor keys (arrows)
	mkeyw	'\kdnarr',scan+80
	mkeyw	'\klfarr',scan+75
	mkeyw	'\krtarr',scan+77
	mkeyw	'\kupscn',scan+73	; PgUp  Kermit screen roll back keys
	mkeyw	'\kdnscn',scan+81	; PgDn
	mkeyw	'\khomscn',scan+71	; Home
	mkeyw	'\kendscn',scan+79	; End
	mkeyw	'\kupone',scan+control+132 ; Ctrl PgUp	one line scrolls
	mkeyw	'\kdnone',scan+control+118 ; Ctrl PgDn
	mkeyw	'\kuparr',scan+enhanced+72 ; Enhanced kbd duplicate keys
	mkeyw	'\kdnarr',scan+enhanced+80
	mkeyw	'\klfarr',scan+enhanced+75
	mkeyw	'\krtarr',scan+enhanced+77
	mkeyw	'\kupscn',scan+enhanced+73 ; PgUp Kermit screen roll back keys
	mkeyw	'\kdnscn',scan+enhanced+81 ; PgDn
	mkeyw	'\khomscn',scan+enhanced+71 ; Home
	mkeyw	'\kendscn',scan+enhanced+79	; End
	mkeyw	'\kupone',scan+control+enhanced+132 ;Ctrl PgUp one line scroll
	mkeyw	'\kdnone',scan+control+enhanced+118 ; Ctrl PgDn
	mkeyw	'\kmodeline',scan+74	; Kermit toggle mode line  Keypad -
	mkeyw	'\ktermtype',scan+alt+130 ; Kermit toggle terminal type  Alt -
	mkeyw	'\kreset',scan+alt+131	; Kermit reset terminal  Alt =
	mkeyw	'\kreset',scan+alt+19	; ALT r for reset too
	mkeyw	'\kdebug',scan+alt+32	; ALT d for debug
	mkeyw	'\kprtscn',scan+control+114 ; Kermit toggle prn scrn  Ctrl *
	mkeyw	'\kdump',scan+control+117 ; Kermit Dump Screen  Ctrl End
	mkeyw	'*',scan+55		; keypad asterisk
	mkeyw	'*',scan+enhanced+55	; Enhanced kbd keypad asterisk
	mkeyw	'+',scan+78		; keypad plus
	mkeyw	'.',scan+shift+83	; IBM numeric keypad
	mkeyw	'0',scan+shift+82
	mkeyw	'1',scan+shift+79
	mkeyw	'2',scan+shift+80
	mkeyw	'3',scan+shift+81
	mkeyw	'4',scan+shift+75
	mkeyw	'5',scan+shift+76
	mkeyw	'6',scan+shift+77
	mkeyw	'7',scan+shift+71
	mkeyw	'8',scan+shift+72
	mkeyw	'9',scan+shift+73
	mkeyw	' ',scan+57		; space bar yields space
	mkeyw	' ',scan+shift+57	; Shift + space bar
	mkeyw	'\0',scan+control+57	; Control-space bar yields nul
	mkeyw	'\0',scan+control+shift+57; Shift Control-space bar
	mkeyw	tab,scan+15		; regular Tab key, made special
	mkeyw	cr,scan+28		; typewriter Enter key
	mkeyw	cr,scan+enhanced+cr	; Enhanced kbd grey Enter key
	mkeyw	lf,scan+control+28	; Control-Enter
	mkeyw	lf,scan+enhanced+control+lf ; Enhanced grey Control Enter
	mkeyw	'/',scan+enhanced+'/'	; Enhanced kbd grey foward slash
	mkeyw	'\0',scan+control+3	; Control at-sign sends null
	mkeyw	'\0',scan+control+shift+3 ; Control Shift at-sign sends null
	mkeyw	'\x7f',scan+83		; Del key sends DEL
	mkeyw	'\x7f',scan+enhanced+83 ; Enhanced duplicate DEL sends DEL
	mkeyw	'\x7f',scan+14		; Backspace key sends DEL
	mkeyw	'\x1b',scan+01		; Esc key sends ESC
	mkeyw	'\kexit',scan+alt+45	; Exit connect mode  Alt X
	mkeyw	'\kstatus',scan+alt+31	; Connect mode status  Alt S
	mkeyw	'\kbreak',scan+alt+48	; Send a Break  Alt B
	mkeyw	'\kbreak',scan+control+0; Control-Break sends a Break too
	mkeyw	'\khelp',scan+alt+35	; Connect mode drop down menu  Alt H
	mkeyw	'\kcompose',scan+alt+46	; ALT C is compose
ifndef	no_tcp
	mkeyw	'\knextsession',scan+alt+49	; nextses is Alt N
	mkeyw	'\knethold',scan+alt+44	; ALT Z is nethold
endif	; no_tcp
	dw	0		; end of table marker

					;** LK250 support begin
kb250lst equ	this byte     		; Extensions for DEC LK250 keyboard
	mkeyw	escape,scan+104		; Compose maps to ESC
        mkeyw   '\x7f',scan+14          ; Backspace key sends DEL
        mkeyw   bs,scan+shift+14        ; Shift-Backspace key sends BS
	mkeyw	cr,scan+28		; Return key sends CR
	mkeyw	lf,scan+shift+28	; Shift-Return sends LF
	mkeyw	tab,scan+15		; Tab sends TAB
	mkeyw	' ',scan+57		; space bar yields space
	mkeyw	' ',scan+shift+57	; Shift + space bar
	mkeyw	'\0',scan+control+57	; Control-space bar yields nul
	mkeyw	'\0',scan+control+shift+57; Shift Control-space bar
					; the top-row function keys
	mkeyw	'\kholdscrn',scan+59	; DEC Hold
	mkeyw	'\kprtscn',scan+60	; DEC Print Screen
;;;;	mkeyw	'{\{kstatus}\{kexit}}',scan+61	; DEC Set-Up
	mkeyw	'\kbreak',scan+63	; DEC Break
	mkeyw	'\kdecF6',scan+64	; DEC F6
	mkeyw	'\kdecF7',scan+65	; DEC F7
	mkeyw	'\kdecF8',scan+66	; DEC F8
	mkeyw	'\kdecF9',scan+67	; DEC F9
	mkeyw	'\kdecF10',scan+68	; DEC F10
	mkeyw	'\kdecF11',scan+95	; DEC F11
	mkeyw	'\kdecF12',scan+96	; DEC F12
	mkeyw	'\kdecF13',scan+97	; DEC F13
	mkeyw	'\kdecF14',scan+98	; DEC F14
	mkeyw	'\kdecHelp',scan+99	; DEC Help
	mkeyw	'\kdecDo',scan+100	; DEC DO
	mkeyw	'\kdecF17',scan+101	; DEC F17
	mkeyw	'\kdecF18',scan+102	; DEC F18
	mkeyw	'\kdecF19',scan+103	; DEC F19
	mkeyw	'\kdecF20',scan+84	; DEC F20
					; the cursor/select cluster
	mkeyw	'\kdecFind',scan+85	; DEC Find
	mkeyw	'\kdecInsert',scan+86	; DEC Insert Here
	mkeyw	'\kdecRemove',scan+87	; DEC Remove
	mkeyw	'\kdecSelect',scan+88	; DEC Select
	mkeyw	'\kdecPrev',scan+89	; DEC Prev
	mkeyw	'\kdecNext',scan+90	; DEC Next
	mkeyw	'\kuparr',scan+91	; up arrow
	mkeyw	'\klfarr',scan+92	; left arrow
	mkeyw	'\krtarr',scan+93	; right arrow
	mkeyw	'\kdnarr',scan+94	; down arrow
					; the DEC editing keypad
	mkeyw	'\kgold',scan+106	; F1
	mkeyw	'\kpf2',scan+107	; F2
	mkeyw	'\kpf3',scan+108	; F3
	mkeyw	'\kpf4',scan+109	; F4
	mkeyw	'\kkp7',scan+shift+71	; KP7
	mkeyw	'\kkp8',scan+shift+72	; KP8
	mkeyw	'\kkp9',scan+shift+73	; KP9
	mkeyw	'\kkpminus',scan+74	; KP-
	mkeyw	'\kkp4',scan+shift+75	; KP4
	mkeyw	'\kkp5',scan+shift+76	; KP5
	mkeyw	'\kkp6',scan+shift+77	; KP6
	mkeyw	'\kkpcoma',scan+78	; KP,
	mkeyw	'\kkp1',scan+shift+79	; KP1
	mkeyw	'\kkp2',scan+shift+80	; KP2
	mkeyw	'\kkp3',scan+shift+81	; KP3
	mkeyw	'\kkpenter',scan+105	; keypad enter
	mkeyw	'\kkpenter',scan+shift+105 ; keypad enter
	mkeyw	'\kkp0',scan+shift+82	; KP0
	mkeyw	'\kkpdot',scan+shift+83	; KP.
					; some useful Kermit keys
        mkeyw   '\kupscn',scan+alt+89   ; PgUp  Kermit screen roll back keys
        mkeyw   '\kdnscn',scan+alt+90   ; PgDn
        mkeyw   '\khomscn',scan+alt+85  ; Home
        mkeyw   '\kendscn',scan+alt+88  ; End
        mkeyw   '\kupone',scan+control+89 ; Ctrl PgUp  one line scrolls
        mkeyw   '\kdnone',scan+control+90 ; Ctrl PgDn
        mkeyw   '\kexit',scan+alt+45    ; Exit connect mode  Alt X
        mkeyw   '\kstatus',scan+alt+31  ; Connect mode status  Alt S
        mkeyw   '\kbreak',scan+alt+48   ; Send a Break  Alt B
        mkeyw   '\kbreak',scan+control+108 ; Control-Break sends a Break too
        mkeyw   '\khelp',scan+alt+35    ; Connect mode drop down menu  Alt H
        mkeyw   '\ktermtype',scan+alt+130 ; Kermit toggle terminal type  Alt -
        mkeyw   '\kreset',scan+alt+131  ; Kermit reset terminal  Alt =
        mkeyw   '\kprtscn',scan+control+109 ; Kermit toggle prn scrn  Ctrl *
        mkeyw   '\kdump',scan+control+88 ; Kermit Dump Screen  Ctrl End
	dw	0			; end of table marker

got250	db	0			;** LK250 present if non-zero
kbd250	db	0			; enable use of LK250 if non-zero
lk250msg db	cr,lf,'?LK250 keyboard external driver is not active.$'
					;** LK250 support end
kbcodes	dw	80h			; keyboard read codes, 80h=not inited
data	ends

data1	segment
dfhelp1	db    cr,lf,' Enter key',27h,'s identification as a character',cr,lf
	db	'  or as its numerical equivalent \{b##} of ascii',cr,lf
	db	'  or as its scan code \{b##}'
	db	cr,lf,'  or as SCAN followed by its scan code',cr,lf
	db	'    where b is O for octal, X for hex, or D for decimal'
	db	' (default).',cr,lf,'    Braces {} are optional.'
	db	cr,lf,'    Follow the identification with the new definition.'
	db	cr,lf,' or CLEAR to restore initial key settings'
	db	cr,lf,' or ON (default) for Bios i/o or OFF to use DOS i/o'
	db	cr,lf,' or LK to use the DEC LK250 keyboard.$' ;IBM
;;;	System Dependent Data Area
;	edit dfhelp2 to include nice list of verbs for this system.
dfhelp2 db	cr,lf,' Enter either  \Kverb  for a Kermit action verb',cr,lf
	db	' or a replacement string  (single byte binary numbers are'
	db	' \{b##})',cr,lf,' or push Return to undefine a key, ^C to'
	db	' retain current definition.'
	db	cr,lf,' Braces {} are optional, and strings maybe enclosed in'
	db	' them.',cr,lf,' Strings may not begin with the character'
	db	' combinations of  \k  or  \{k',cr,lf
	db	'    (start with a { brace instead).',cr,lf,lf
	db	' Verbs are as follows. Keys (arrows and keypad):',cr,lf
	db   '   uparr, dnarr, lfarr, rtarr, kpminus, kpcoma, kpdot, kpenter,'
	db	cr,lf
	db   '   Gold (same as PF1), PF1, PF2, PF3, PF4, kp0, ... kp9'
	db	cr,lf,'   decFind, decInsert, decRemove, decSelect, decPrev,'
	db	' decNext'
	db	cr,lf,'   decF6, ...decF14, decHelp, decDO, decF17, ...decF20'
	db	cr,lf,'   Compose (same as dgSPCL)'
	db	cr,lf,'   User Definable Keys udkF6, ...udkF20'
	db	cr,lf,'   Data General dgC1..dgC4, dgF1..dgF15, dgSF1..dgSf15,'
	db	cr,lf,'   dgPoint, dgSPCL, dgNC'
	db	cr,lf,'   Wyse-50 function keys wyseF1..wyseF16, wyseSF1..'
	db	'wyseSF16'
	db	cr,lf,' Kermit screen control and actions:',cr,lf
	db   '   upscn, dnscn, homscn, endscn, upone, dnone (vertical '
	db	'scrolling),'
	db	cr,lf
	db   '   lfpage, lfone, rtpage, rtone (horizontal scrolling)'
	db	cr,lf
	db   '   logoff, logon, termtype, reset, holdscrn, modeline, break,'
	db   ' debug,'
	db	cr,lf
	db   '   lbreak, nethold, nextsession, prtscn, dump, hangup, null'
	db   ' (send one),'
	db	cr,lf
ifndef	no_tcp
	db   '   session1, ..session6 (selects Telnet session number 1..6)'
	db	cr,lf
endif	; no_tcp
	db   '   tn_AYT, tn_IP, DOS, help, ignore, status, exit'
	db	cr,lf,'$'

data1	ends
;			Documentation
;Translating a key:
;   The translator is called to obtain keyboard input; it sends characters to
; the serial port through standard controlled echo procedures or invokes
; named procedures. It returns carry clear when its operation is completed
; for normal actions and carry set when Connect mode must be exited. When
; Connect mode is exited the just read char should be passed in Kbdflg 
; to msster.asm for invoking actions such as Status, send a break,
; quit connect mode; system dependent procedure Term is responsible for this. 
;
;  Principal procedures are -
;	msuinit		Initializes keyboard translator in this file when
;			Kermit first begins. Installs dfkey and shkey as the
;			procedures used for Set Key and Show Key. Sys Indep.
;			Called from msx or msy init procs. System Independent.
;	keybd		Performs the translation, outputs chars to the serial
;			port or invokes a Kermit action routine. Sys Indep.
;	dfkey		Defines a key's translation. Reads command line
;			via Kermit's command parser comnd. System Independent.
;	shkey		Shows translation of a key. Requests user to push
;			selected key. System Independent.
;
;	kbdinit		optional. Initializes the translation tables when
;			Kermit starts up. Called by msuinit. System Dependent.
;	getkey		Performs the keyboard read and returns results in
;			a standardized system independent format. Sys Depend.
;	postkey		called by active translator after obtaining a keycode.
;			Used to provide extra local actions (keyclick) only
;			in Connect mode (not during Set/Show key commands).
;			Called by keybd. System dependent.
; Supporting system independent procedures are -
; shkfre (show string free space), tstkeyw (finds user's keyword in the verb
; table), insertst (insert string in buffer), remstr (delete string in buffer).
;
;   System dependent procedure Getkey reads a keycode (usually via a Bios
; call). On IBM compatible machines this yields <ah=scan code, al=ascii>
; for ordinary keys, or <ah=scan code, al=0> for special keys such as F1,
; or <ah=0, al=###> when Alt### is used.
; For any system, the canonical output form is the key's code in Keycode.
; Place the ascii code (or scan code if none) in byte Keycode and ancillary
; info (shift states plus marker bit for scan codes) in byte Keycode + 1.
; 
;   Table Aliaskey is a list of scan code/ascii codes for keys which appear
; more than once on a keyboard. This list is examined to distinguish such
; aliased keys (those on an auxillary keypad) from an ordinary ascii key,
; and the aliased key is then referenced by its scan code rather than by
; the ordinary ascii code. Aliaskey is machine and keyboard dependent.
;
;    Procedure Keybd calls Getkey for the Keycode, checks list of translatable
; keys Keylist, and then either sends an ascii string (one or more characters)
; or invokes a Kermit action verb. List Dirlist indicates what kind of 
; translation to do. Keybd is system independent but may contain system
; dependent special actions such as echoing keyclicks. Keybd calls system
; dependent procedure Postkey just after calling getkey so local actions
; such as keyclicks can be activated only during Connect mode operations.
;
;    Keylist is a packed but unordered list of 16 bit keycodes which need
; translation. The lower order byte holds a key code (ascii char or scan code)
; while the high byte holds a scan code marker bit (0 if ascii code in low
; byte) plus any ancillary keyboard information such as Control/Shift/Alt/Meta
; keys being held down; these are of use in Show Key presentations.
;    Dirlist parallels Keylist to provide the kind of translation, verb or
; string, in the two highest bits with the other bits holding either
; a single new replacement character or the item number in lists of verbs
; or strings. If neither verb nor strng type bits are set in a dirlist
; word then the translation is a single new character held in the lower
; eight bits of that dirlist word.
;
;    The number of key translations is assembly constant Maxkeys (def 128).
;    The maximum number of strings is assembly constant Maxstngs (def 64).
;    The maximum number of verbs is 256 and is set by building table Kverbs.
;
;   For verbs, use the Item number from the Director table Dirlist to select
; a procedure offset from the structured list Kverbs and jump to that offset.
; Most verb procedures return carry clear to stay within Connect mode.
; Verbs requiring exiting Connect mode return carry set and may set byte
; Kbdflg to a char code which will be read by msster.asm for activating a
; transient Kermit action such as send a break (Kbdflg = 'b').
; Kbdflg is stored in msster.asm (as zero initially, meaning ignore it).
; Action verb procedures are normally located in a system dependent file.
;
;   For multi-char strings, use Item number from Director table Dirlist to
; select a pointer to a string. The list of string pointers is Sptable
; (string pointer table) which holds the offset in the data segment of the
; strings stored in buffer Stbuf. In stbuf strings are held as: one byte of
; length of following text and then the text itself (permits embedded nulls).
;  Use Chrout to send each string character, and finally return from Keybd
; with carry clear.
;
;   For single character replacements obtain the new character from the lower
; order byte of Director table Dirlist. If the character is Kermit's present
; escape character return from Keybd carry set to leave connect mode.
; Otherwise, send the character via Chrout and return from Keybd carry clear.

; Keylist table format:
;    7 bits   1 bit   8 bits
; +----------+----+------------+ scan bit = 1 if key's code is non-ascii
; | aux info |scan| key's code | aux info = system dependent, used only to
; +----------+----+------------+            help identify key
;
; Dirlist table format		  v s	meaning
;   1   1      14 bits   	  0 0	copy out one byte translation
; +---+---+--------------------+  1 0	copy out multi-char string number Item
; | v | s | item # or new char |  0 1	do action verb number Item
; +---+---+--------------------+  1 1	(not used)
;
; Table kverbs is organized by macro mkeyw as -
;	kverbs	db	number of table entries
;	(each entry is in the form below:)
;		dw	number of bytes in verbname
;		db	'verbname'		variable length
;		dw	value			offset of procedure
;
;
;   Dfkey defines a key to be itself (undefines it) or a single replacement
; character or a character string or a Kermit action verb. Dfkey requires
; a command line so that it may be invoked by Take files but can be forced
; to prompt an interactive user to push a key. Syntax is discussed below.
; Note that redefined keys have their old definitions cleared so that
; old string space is reclaimed automatically.
;
;   Shkey displays a key's definition and the user is asked to push the
; selected key. The free space for strings is always shown afterward. See
; below for syntax.
;
;   Kbdinit is an optional routine called when Kermit starts up. It fills in
; the translation tables with desirable default values to save having to
; use long mskermit.ini files. The default values are stored in a structured
; table similar to (but not the same as) Dfkey's command lines; the keycode
; values are preset by hand to 16 bit numbers.

;Defining a key:
; Command is SET KEY <key ident><whitespace><definition>
;
; <key ident> is
;		a single ordinary ascii char or
;		the numerical equivalent of an ascii char or
;		a Scan Code written as a number or
;		keyword SCAN followed by a number.
;		?	Displays help message.
;	Numbers and Binary codes are of the form
;		\123	a decimal number
;		\o456	an octal number		base letters o, d, x can be
;		\d213	a decimal number	upper or lower case
;		\x0d	a hex number
;		\{b###}  braces around above material following slash.
;
; <whitespace> is one or more spaces and or tabs.
;
; <definition> is
;	missing altogether which "undefines" a key.
;	\Kverb		for a Kermit action verb; upper or lower case K is ok
;	\{Kverb}	ditto. Verb is the name of an action verb.
;	text		a string with allowed embedded whitespace and embedded
;			binary chars as above. This kind of string may not
;			commence with sequences \K or \{K; use braces below.
;	{text}		string confined to material within but excluding
;			the braces. Note, where the number of opening braces
;			exceeds the number of closing braces the end of line
;			terminates the string: {ab{}{{c}d ==> ab{}{{c}d
;			but  {ab}{{c}d ==> ab.
;	?		Displays help message and lists all action verbs.
;
;	If Set Key is given interactively, as opposed to within a Take
;	file, the system will prompt for inputs if none is on the command
;	line. The response to Push key to be defined cannot be edited.
;
;	Text which reduces to a single replacement character is put into a
;	table separate from the multi-character strings (maxstng of these).
;	A key may be translated into any single 8 bit code.
;	
;	Comments can follow a Kermit action verb or a braced string; no
;	semicolon is required since all are stripped out by the Take file
;	reader before the defining text is seen by SET KEY.
;
;	The current Kermit escape character cannot be translated without
;	subtrafuge.
;
;	Examples:
;		Set Key q z
;				makes key q send character z
;		Set Key \7 \27[0m
;				makes key Control G send the four byte
;				string  ESC [ 0 m
;		Set Key q
;				undefines key q so it sends itself (q) again.
;		Set Key \2349 \kexit
;				defines IBM Alt-X to invoke the leave connect
;				mode verb "exit" (Kermit's escape-char ^] C).
;		Set Key \x0c Login \{x0d}myname\{x0d}mypass\x0d
;				defines Control L to send the string
;				Login <cr>myname<cr>mypass<cr>
;
; Alternative Set Key syntax for backward compatibility with previous versions
;	The same forms as above except the key identification number must
;	be decimal and must Not have a leading backslash. Example:
;	Set Key Scan 59 This is the F1 key
;
;	If the definition is omitted it may be placed on the following line;
;	if that line is also empty the key is undefined (defined as Self).
;	A warning message about obsolete syntax will be given followed by
;	the key's modern numerical value and new definition. Only "special"
;	keys (those not producing ascii codes) are compatible with this
;	translator.
;
;Showing a key:
; Command is SHOW KEY <cr>
; System prompts user to press a key and shows the definition plus the
; free space for strings. Query response results in showing all definitions.
;			End Documentation

code1	segment
	extrn	vclick:near, udkclear:near		; in msyibm
	extrn	xltkey:far				; in mszibm
	extrn	iseof:far, strlen:far, prtscr:far	; in mssfil
	extrn	domath:far, decout:far			; in msster
	assume	cs:code1

fudkclear proc	far
	call	udkclear
	ret
fudkclear endp

fvclick	proc	far
	call	vclick
	ret
fvclick	endp

code1	ends

code	segment
		; system independent external items
	extrn	comnd:near, prompt:near, cnvlin:near	; in msscmd
		; system dependent external items
	extrn	beep:near, khold:near
		; these are system dependent action verbs, in msxibm & msyibm 
	extrn	uparrw:near, dnarrw:near, rtarr:near, lfarr:near
	extrn	pf1:near, pf2:near, pf3:near, pf4:near,	kp0:near, kp1:near
	extrn	kp2:near, kp3:near, kp4:near, kp5:near, kp6:near, kp7:near
	extrn	kp8:near, kp9:near, kpminus:near, kpcoma:near, kpenter:near
	extrn	kpdot:near, decf6:near, decf7:near, decf8:near, decf9:near
	extrn	decf10:near, decf11:near, decf12:near, decf13:near
	extrn	decf14:near, dechelp:near, decdo:near, decf17:near
	extrn	decf18:near, decf19:near, decf20:near
	extrn	decfind:near, decinsert:near, decremove:near
	extrn	decselect:near, decprev:near, decnext:near, ignore_key:near
	extrn	udkf6:near, udkf7:near, udkf8:near, udkf9:near, udkf10:near
	extrn	udkf11:near,udkf12:near,udkf13:near,udkf14:near,udkf15:near
	extrn	udkf16:near,udkf17:near,udkf18:near,udkf19:near,udkf20:near
	extrn	chrout:near, cstatus:near, cquit:near, cquery:near
	extrn	vtans52:near, vtinit:near, dnwpg:near, upwpg:near
	extrn	endwnd:near, homwnd:near, upone:near, dnone:near, trnprs:near
	extrn	trnmod:near, sendbr:near, sendbl:near, dmpscn:near, snull:near
	extrn	chang:near, klogon:near, klogof:near, cdos:near
	extrn	lfpage:near, rtpage:near, lfone:near, rtone:near, kdebug:near
	extrn	extmacro:near
	extrn	dgkc1:near,dgkc2:near,dgkc3:near,dgkc4:near,dgkf1:near
	extrn	dgkf2:near,dgkf3:near,dgkf4:near,dgkf5:near,dgkf6:near
	extrn	dgkf7:near,dgkf8:near,dgkf9:near,dgkf10:near,dgkf11:near
	extrn	dgkf12:near,dgkf13:near,dgkf14:near,dgkf15:near
	extrn	dgkSf1:near,dgkSf2:near,dgkSf3:near,dgkSf4:near,dgkSf5:near
	extrn	dgkSf6:near,dgkSf7:near,dgkSf8:near,dgkSf9:near,dgkSf10:near
	extrn	dgkSf11:near,dgkSf12:near,dgkSf13:near,dgkSf14:near
	extrn	dgkSf15:near,dgpoint:near, dgnckey:near, kbdcompose:near
	extrn	wykf1:near,wykf2:near,wykf3:near,wykf4:near,wykf5:near
	extrn	wykf6:near,wykf7:near,wykf8:near,wykf9:near,wykf10:near
	extrn	wykf11:near,wykf12:near,wykf13:near,wykf14:near,wykf15:near
	extrn	wykf16:near
	extrn	wykSf1:near,wykSf2:near,wykSf3:near,wykSf4:near,wykSf5:near
	extrn	wykSf6:near,wykSf7:near,wykSf8:near,wykSf9:near,wykSf10:near
	extrn	wykSf11:near,wykSf12:near,wykSf13:near,wykSf14:near
	extrn	wykSf15:near, wykSf16:near
	extrn	jpnxltkey:near
ifndef	no_network
	extrn	ubhold:near
ifndef	no_tcp
	extrn	nextses:near, tn_AYT:near, tn_IP:near
	extrn	ses1:near,ses2:near,ses3:near,ses4:near,ses5:near,ses6:near
endif	; no_tcp
endif	; no_network

	assume	cs:code, ds:data, es:data

; Begin system independent Keyboard Translator code

; MSUINIT performs Kermit startup initialization for this file.
; Note, shkadr and stkadr are pointers tested by Set/Show Key calls. If they
; are not initialized here then the older Set/Show Key procedures are called.
MSUINIT	PROC	NEAR			; call from msx/msy init code
	call	kbdinit			; optional: init translator tables
	mov	shkadr,offset shkey	; declare keyboard translator present
	mov	stkadr,offset dfkey	; via Show and Set Key proc addresses
	ret
MSUINIT	ENDP

; Call Keybd to read a keyboard char (just returns carry clear if none) and
; 1) send the replacement string (or original char if not translated)
;    out the serial port, or
; 2) execute a Kermit action verb.
; Returns carry set if Connect mode is to be exited, else carry clear.
; Modifies registers ax and bx. 
KEYBD	PROC	NEAR			; active translator
	mov	ttyact,1		; doing single char output
	cmp	stringcnt,0		; any leftover string chars?
	je	keybd0			; e = no
	jmp	keyst2			; yes, finish string
keybd0:	call	getkey			; read keyboard
	jnc	keybd1			; nc = data available
	jmp	keybdx			; else just return carry clear
keybd1:	call	postkey			; call system dependent post processor
	cmp	nkeys,0			; is number of keys defined = 0?
	jz	keybd3			; z = none defined
	push	di			; search keylist for this keycode
	push	cx			; save some registers	
	push	es
	mov	di,offset keylist	; list of defined keycode words
	mov	ax,keycode		; present keycode
	mov	cx,nkeys		; number of words to examine
	push	ds
	pop	es			; make es:di point to data segment
	cld
	repne	scasw			; find keycode in list
	pop	es			; restore regs
	pop	cx
	je	keybd1b			; e = found, work with present di
	pop	di			; restore original di
	test	keycode,scan		; is this a scan code?
	jz	keybd3			; z = no, it's ascii, use al as char
	call	beep			; say key is a dead one
	clc
	ret				; and exit with no action

keybd1b:sub	di,2			; correct for auto increment
	sub	di,offset keylist	; subtract start of list ==> listptr
	mov	ax,dirlist[di]		; ax = contents of director word
	pop	di			; restore original di
					; dispatch on Director code
	test	ax,verb			; verb only?
	jnz	keyvb			; e = yes
	test	ax,strng		; multi-char string only?
	jnz	keyst			; e = yes, else single char & no xlat.
					;
					; do single CHAR output (char in al)
keybd3:	cmp	termesc_flag,0		; is escaping allowed?
	jne	keybd3c			; ne = no, skip recognition
	cmp	al,trans.escchr		; Kermit's escape char?
	je	keybd3a			; e = yes, handle separately
keybd3c:cmp	isps55,0		; [HF]940206 Japanese PS/55?
	je	keybd3b			; [HF]940206 e = no
	call	jpnxltkey		; [HF]940206 check Jpn.dble byte char
	jnc	keybd3b			; [HF]940206 nc = no Jpn
	clc				; [HF]940206 return sccess
	ret				; [HF]940206
keybd3b:call	xltkey			; do character set translation
	call	chrout			; transmit the char
	clc				; return success
	ret
keybd3a:stc				; set carry for jump to Quit
	ret

keyvb:	and	ax,not(verb+strng)	; VERB (ax=index, remove type bits)
	mov	bx,offset kverbs	; start of verb table
	cmp	al,byte ptr [bx]	; index > number of entries?
	jae	keybdx			; ae = illegal, indices start at 0
	inc	bx			; bx points to first entry
	push	cx			; save reg
	mov	cx,ax			; save the index in cx
	inc 	cx			; counter, indices start at 0
keyvb1:	mov	ax,[bx]			; cnt value
	add	ax,4			; skip text and value word
	add	bx,ax			; look at next slot
	loop	keyvb1			; walk to correct slot
	sub	bx,2			; backup to value field
	pop	cx			; restore reg
	mov	bx,[bx]			; get value field of this slot
	or	bx,bx			; jump address defined?
	jz	keybdx			; z = no, skip the action
	jmp	bx			; perform the function

keyst:	and	ax,not(verb+strng)	; STRING (ax=index, remove type bits)
	shl	ax,1			; convert to word index
	push	si			; save working reg
	mov	si,ax			; word subscript in table
	mov	si,sptable[si]		; memory offset of selected string
	xor	cx,cx			; init string length to null
	or	si,si			; is there a string pointer present?
	jz	keyst1			; z = no, skip operation
	cld				; scan forward
	mov	cx,[si]			; get string length
	add	si,2
keyst1:	mov	stringcnt,cx
	mov	stringptr,si
	pop	si
	jcxz	keybdx			; z = null length

keyst2:	push	si
	mov	si,stringptr		; pointer to next string char
	cld
	lodsb				; get new string char into al
	pop	si
	dec	stringcnt		; string chars remaining
	inc	stringptr
	call	keysv			; scan for embedded verbs
	jc	keyst4			; c = not found, al has string char
	jmp	bx			; perform the verb (bx = address)
keyst4:	call	xltkey			; do character set translation
	cmp	stringcnt,0		; last character?
	je	keyst5			; e = yes, stop grouping for nets
	mov	ttyact,0		; group output for networks
keyst5:	jmp	chrout			; send out the char in al

keybdx:	clc				; return success (nothing to do)
	ret
KEYBD	ENDP

; Scan for keyboard verbs embedded in outgoing string. If found update
; string pointer and count to just beyond the verb and return action routine
; address in bx with carry clear. If failure return carry set and no change.
; Can invoke external procedure EXTMACRO if the verb is not known here.

keysv	proc	near
	push	ax
	push	si
	push	di
	cmp	al,'\'			; escape?
	jne	keysv7			; ne = no
	mov	cx,stringcnt		; chars remaining
	mov	si,stringptr		; address of next char to read
	mov	brace,0			; assume not using braces
	cmp	byte ptr [si],braceop	; starts with \{?
	jne	keysv1			; ne = no
	inc	si			; skip the opening brace
	dec	cx
	mov	brace,bracecl		; expect closing brace
keysv1:	cmp	byte ptr [si],'K'	; starts with \{K or \K?
	je	keysv2			; e = yes
	cmp	byte ptr [si],'k'	; starts as \{k or \k?
	jne	keysv7			; ne = no, then it's a string
keysv2:	inc	si			; yes, skip the K too
	dec	cx
	mov	di,offset tranbuf	; copy verb name to this work buffer
	xor	ax,ax
	mov	[di],ax			; init the buffer to empty
keysv3:	cld
	jcxz	keysv4			; z = no more string chars
	lodsb				; scan til closing brace or w/s or end
	dec	cx
	cmp	al,brace		; closing brace?
	je	keysv4			; e = yes
	cmp	al,'\'			; another item starting?
	jne	keysv3a			; ne = no
	cmp	brace,0			; need to end on a brace?
	jne	keysv4			; ne = yes, backing up done below
	dec	si			; back up to break position
	inc	cx
	jmp	short keysv4		; process current substring

keysv3a:cmp	al,spc			; white space or control char?
	jbe	keysv3			; be = yes
	mov	[di],ax			; copy to tranbuf and terminate
	inc	di
	jmp	short keysv3
keysv4:	push	si			; save input reading position
	mov	si,offset tranbuf	; where verb starts (needs si)
	call	tstkeyw			; find keyword, bx = action routine
	pop	si
	jnc	keysv4a			; nc = found the verb
	call	keysv8			; invoke EXTMACRO worker for unknown
	jc	keysv7			; carry = no verb to operate upon
keysv4a:cmp	brace,0			; need to end on a brace?
	je	keysv6			; e = no
	dec	si			; break position
	inc	cx
	cld
keysv5:	jcxz	keysv6			; z = no more string characters
	lodsb				; read string char
	dec	cx
	cmp	al,brace		; the brace?
	jne	keysv5			; ne = no, repeat until it is found
keysv6:	mov	stringptr,si		; where we finished+1
	mov	stringcnt,cx		; new count of remaining chars
	pop	di
	pop	si			; original si, starting place
	pop	ax			; original ax
	clc
	ret
keysv7:	pop	di			; verb not found
	pop	si
	pop	ax
	stc
	ret
; Worker. Unknown verb name as string {\kverb} or {\k{verb}}. Use EXTMACRO
; procedure (in msyibm typically), point to verb name with vtmacname, length
; of it in byte vtmaclen, address of EXTMACRO to BX. Upper case the verb.
; Enter with tranbuf holding the verb, asciiz, without \K and braces.
; Returns BX set to EXTMACRO proc, vtmacname pointing to verb (uppercased)
; and vtmaclen holding the length of verb.
keysv8:	mov	bx,offset extmacro	; use this external macro pointer
	mov	vtmacname,offset tranbuf; select extmacro procedure address
	mov	dx,offset tranbuf	; point to name for extmacro
	push	cx
	call	strlen			; get its length
	mov	vtmaclen,cx		; length for extmacro
	jcxz	keysv11			; z = none
	push	si			; convert verb name to upper case
	mov	si,dx			; verb, without leading \K stuff
	cld
keysv9:	lodsb				; read a name byte
	cmp	al,'a'			; before lower case?
	jb	keysv10			; e = yes
	cmp	al,'z'			; above lower case?
	ja	keysv10			; a = yes
	and	al,not 20h		; convert to upper case
	mov	[si-1],al		; put it back
keysv10:loop	keysv9			; do all bytes, asciiz
	pop	si
	pop	cx
	clc				; carry clear = ready to execute
	ret
keysv11:stc				; carry set = no verb, do nothing
	pop	cx
	ret
keysv	endp

; SET KEY - define a key   (procedure dfkey)
; SET KEY <key ident><whitespace><new meaning>
; Call from Kermit level. Returns carry set if failure.
;  
DFKEY	PROC	NEAR			; define a key as a verb or a string
	mov	keycode,0		; clear keycode
	mov	oldform,0		; say no old form Set Key yet
	or	byte ptr kbcodes,80h	; say kbcodes not-initiated
	mov	bx,offset tranbuf	; our work space
	mov	word ptr tranbuf,0	; insert terminator
	mov	dx,offset dfhelp1	; first help message
	mov	ah,cmword		; parse a word
	call	comnd			; get key code or original ascii char
	jnc	dfkey9
	ret
dfkey9:	mov	cl,taklev		; reading from Take file
	mov	msutake,cl		; save here
	or	ax,ax			; any text given?
	jnz	dfkey12			; nz = yes, so don't consider prompts
					; interactive key request
	cmp	taklev,0		; in a Take file?
	je	dfkey10			; e = no, prompt for keystroke
	jmp	dfkey0			;  else say bad syntax
dfkey10:mov	ah,prstr
	mov	dx,offset dfaskky	; ask for key to be pressed
	int	dos
dfkey11:call	getkey			; read key ident from keyboard
	jc	dfkey11			; c = no response, wait for keystroke
	mov	ah,prstr		; display cr/lf
	mov	dx,offset crlf
	int	dos
	call	shkey0			; show current definition (in SHKEY)
	jmp	dfkey1e			; prompt for and process definition

dfkey12:				; Look for word SCAN and ignore it
	mov	dx,word ptr tranbuf	; get first two characters
	or	dx,2020h		; map upper to lower case
	cmp	dx,'cs'			; first two letters of word "scan"?
	je	dfkey			; e = yes, skip the word
	cmp	dx,'lc'			; first two letters of word "clear"?
	je	dfkey15			; e = yes, reinit keyboard [2.31]
	cmp	dx,'fo'			; first two letters of "off"
	je	dfkey13			; e = yes, use DOS keyboard calls
	cmp	dx,'no'			; first two letters of "on"
	je	dfkey13			; e = yes, use standard kbd calls
	cmp	dx,'kl'			; first two letters of "lk" (LK250)?
	je	dfkey13			; e = yes
	cmp	ax,1			; number of characters received
	jbe	dfkey12a		; be = stay here
	jmp	dfkey1			; a = more than one, decode
dfkey12a:mov	ah,byte ptr tranbuf	; get the single char
	mov	byte ptr keycode,ah	; store as ascii keycode
	jmp	dfkey1b			; go get definition
dfkey13:push	dx			; save command letters
	mov	ah,cmeol		; get end of line confirmation
	call	comnd
	pop	dx
	jnc	dfkey14			; nc = success
	ret
dfkey14:mov	al,0ffh			; set DOS keyboard read flag
	cmp	dx,'fo'			; first two letters of "off"
	je	dfkey14a		; e = yes, use DOS keyboard calls
	xor	al,al			; clear DOS keyboard read flag
	cmp	dx,'no'			; first two letters of "on"
	je	dfkey14a		; e = yes, use standard kbd calls
	mov	ah,dosflg		; get current flag
	mov	dosflg,1		; engage for chk250 test
	push	ax
	call	chk250			; see if LK250 driver is present
	pop	ax
	mov	al,ah			; recover current setting
	cmp	got250,0		; did we find the driver?
	je	dfkey14a		; e = no
	call	kbrest			; and activiate it if so
	mov	al,1			; say LK250
dfkey14a:mov	dosflg,al		; store new keyboard flag
	ret

dfkey15:mov	ah,cmeol
	call	comnd			; confirm request before proceeding
	jnc	dfkeyc			; nc = success
	ret				; failure

dfkey0:	push	ds
	mov	dx,seg dfhelp1		; in seg data1
	mov	ds,dx
	mov	dx,offset dfhelp1	; say bad definition command
	mov	ah,prstr
	int	dos
	pop	ds
	stc				; failure
	ret

dfkeyc:					; CLEAR key defs, restore startup defs
	mov	cx,maxkeys		; size of keycode tables
	push	es			; save register
	push	ds
	pop	es			; make es point to data segment
	xor	ax,ax			; null, value to be stored
	mov	di,offset dirlist	; director table
	cld
	rep	stosw			; clear it
	mov	cx,maxkeys
	mov	di,offset keylist	; keycode table
	rep	stosw			; clear it
	mov	cx,maxstng
	mov	di,offset sptable	; string pointer table
	rep	stosw			; clear it
	pop	es			; recover register
	mov	strmax,offset stbuf	; clear string buffer, free space ptr
	mov	stbuf,0			; first element of buffer 
	mov	nkeys,0			; clear number of defined keys
	call	msuinit			; restore startup definitions
	clc				; success
	ret
					; Multi-char key identification
dfkey1:	mov	si,offset tranbuf	; point to key ident text
	cmp	byte ptr [si],'0'	; is first character numeric?
	jb	dfkey1a			; b = no
	cmp	byte ptr [si],'9'	; in numbers?
	ja	dfkey1a			; a = no
	mov	keycode,scan		; setup keycode for scan value
	mov	dx,si			; get length of string in cx
	call	strlen
	push	ds
	pop	es			; make es point to data segment
	push	si
	add	si,cx			; point at string terminator
	mov	di,si
	inc	di			; place to store string (1 byte later)
	inc	cx			; include null terminator
	std				; work backward
	rep	movsb			; move string one place later
	cld
	pop	si
	mov	byte ptr [si],'\'	; make ascii digits into \nnn form
	mov	oldform,0ffh		; set old form flag
	mov	dx,offset kwarnmsg	; tell user this is old form
	mov	ah,prstr
	int	dos
dfkey1a:mov	domath_ptr,si		; string
	push	dx
	mov	dx,si
	call	strlen			; get its length
	pop	dx
	mov	domath_cnt,cx
	call	domath			; convert numeric to binary in dx:ax
	jc	dfkey0			; c = no number converted
	or	keycode,ax		; store in keycode

dfkey1b:				; Get Definition proper
	test	oldform,0ffh		; old form Set Key active?
	jz	dfkey1f			; z = no
	mov	bx,offset tranbuf	; get new definition on main cmd line
	mov	dx,offset dfhelp2	; help for definition of key
	mov	comand.cmdonum,1	; \number conversion allowed
	mov	ah,cmline		; read rest of line into tranbuf
	call	comnd			; allow null definitions
	mov	cx,ax			; carry count in cx
	or	ax,ax			; char count zero?
	jz	dfkey1e			; z = zero, prompt for definition
	jmp	dfkey2			; process definition

dfkey1e:mov	ah,prstr
	mov	dx,offset crlf
	int	dos
	mov	dx,offset dfaskdf	; prompt for definition string
 	call	prompt			; Kermit prompt routine
	mov	comand.cmcr,1		; permit bare carriage returns
dfkey1f:mov	bx,offset tranbuf	; get new definition
	mov	dx,offset dfhelp2	; help for definition of key
	mov	comand.cmwhite,1	; allow leading whitespace
	mov	comand.cmdonum,1	; \number conversion allowed
	mov	comand.cmblen,length tranbuf
	mov	ah,cmline		; read rest of line into tranbuf
	call	comnd
	jc	dfkey1x			; exit now on ^C from user
	mov	cx,ax			; line count
	cmp	comand.cmcr,0		; prompting for definition?
	je	dfkey1g			; e = no, trim leading whitespace
	mov	comand.cmcr,0		; turn off allowance for bare c/r's
	jmp	dfkey2			; interactive, allow leading whitespace
dfkey1x:ret				; failure exit

dfkey1g:push	ax			; save count
	mov	ah,cmeol		; get a confirm
	call	comnd
	pop	cx			; string length
	jc	dfkey1x			; none so declare parse error
	
dfkey2:					; Examine translation
	mov	al,trans.escchr		; current escape char (port dependent)
	cmp	al,byte ptr keycode	; is this Kermit's escape char?
	jne	dfkey2a			; ne = no
	test	keycode,scan		; see if scan code
	jnz	dfkey2a			; nz = scan, so not ascii esc char
	mov	dx,offset dfkoops	; Oops! msg
	mov	ah,prstr		; complain and don't redefine
	int	dos
	stc				; failure
	ret

dfkey2a:push	di			; get a director code for this key
	push	cx	
	mov	di,offset keylist	; list of keycodes
	mov	cx,nkeys		; number currently defined
	mov	ax,keycode		; present keycode
	jcxz	dfkey2b			; cx = 0 means none defined yet
	cld
	push	ds
	pop	es
	repne	scasw			; is current keycode in the list?
	jne	dfkey2b			; ne = not in list
	sub	di,2			; correct for auto increment
	sub	di,offset keylist
	mov	listptr,di		; list pointer for existing definition
	pop	cx
	pop	di
	jmp	dfkey3			; go process definition

dfkey2b:pop	cx			; key not currently defined so
	pop	di			;  make a new director entry for it
	mov	bx,nkeys		; number of keys previously defined
	cmp	bx,maxkeys		; enough space?
	jae	dfkey2c			; ae = no, complain
	shl	bx,1			; count words
	mov	listptr,bx		; index into word list
	mov	ax,keycode		; get key's code
	mov	keylist[bx],ax		; store it in list of keycodes
	mov	dirlist[bx],0		; clear the new director entry
	inc	nkeys			; new number of keys
	jmp	dfkey3			; go process definition

dfkey2c:mov	dx,offset keyfull	; say key space is full already
	mov	ah,prstr
	int	dos
	stc				; failure
	ret

; listptr has element number in keylist or dirlist; keycode has key's code.

; Parse new definition. First look for Kermit verbs as a line beginning
; as \K or \{K. Otherwise, consider the line to be a string.
; In any case, update the Director table for the new definition.

dfkey3:	mov	brace,0			; assume not using braces
	mov	si,offset tranbuf	; start of definition text
	cmp	byte ptr [si],'\'	; starts with escape char?
	jne	dfkey5			; ne = no, so we have a string
	inc	si			; skip the backslash
	cmp	byte ptr [si],braceop	; starts with \{?
	jne	dfkey3a			; ne = no
	inc	si			; skip the opening brace
	mov	brace,bracecl		; expect closing brace
dfkey3a:cmp	byte ptr [si],'K'	; starts with \{K or \K?
	je	dfkey3b			; e = yes
	cmp	byte ptr [si],'k'	; starts as \{k or \k?
	jne	dfkey5			; ne = no, then it's a string
dfkey3b:inc	si			; yes, skip the K too
					; Kermit action VERBS
	push	si			; save verb name start address
dfkey4:	cld
	lodsb				; scan til closing brace or w/s or end
	or	al,al			; premature end?
	jz	dfkey4b			; z = yes, accept without brace
	cmp	al,braceop		; another opening brace?
	jne	dfkey4a			; ne = no
	pop	si			; clean stack
	jmp	short dfkey5		; it's a string
dfkey4a:cmp	al,'\'			; another object starting up?
	jne	dfkey4d			; ne = no
	pop	si			; clean stack
	jmp	short dfkey5		; it's a string
dfkey4d:cmp	al,brace		; closing brace?
	jne	dfkey4			; ne = no, not yet
	cmp	byte ptr [si],0		; closing brace terminates text?
	je	dfkey4b			; e = yes, it's a verb
	pop	si			; clean stack
	jmp	short dfkey5		; it's a string
dfkey4b:pop	si			; recover start address
	call	tstkeyw			; find keyword, kw # returned in kbtemp
	jc	dfkey5			; c = not found, assume \kmacro.
	call	remstr			; clear old string, if string
	mov	ax,kbtemp		; save keyword number
	and	ax,not(verb+strng)	; clear verb / string field
	or	ax,verb			; set verb ident
	mov	si,listptr
	mov	dirlist[si],ax		; store info in Director table
	jmp	dfkey7			; show results and return success

; Here we are left with the definition string; si points to its start, and
; its length is in cx. Null length strings mean define key as Self, one
; byte means define as character, else as a string.
					; STRING definitions
dfkey5:	push	cx			; cx = length of definition string
	call	remstr			; first, clear old string, if any
	pop	cx
	mov	si,offset tranbuf	; provide address of new string
	mov	di,si
	call	cnvlin			; convert numbers, cx gets line length
	mov	si,offset tranbuf	; provide address of new string
	cmp	cx,1			; just zero or one byte to do?
	jbe	dfkey6			; e = yes, do as a char
	call	insertst		; insert new string, returns reg cx.
	jc	dfkey5h			; c = could not do insert
	mov	si,listptr		; cx has type and string number
	mov	dirlist[si],cx		; update Director table from insertst
	jmp	dfkey7			; show results and return success

dfkey5h:mov	dx,offset strbad	; display complaint
	mov	ah,prstr
	int	dos
	stc				; failure
	ret

		; define SINGLE CHAR replacement or CLEAR a key definition.
		; cx has char count 1 (normal) or 0 (to undefine the key).
dfkey6:	jcxz	dfkey6c			; z = cx= 0, clear definition
	mov	al,byte ptr [si]	; get first byte from definition
	xor	ah,ah			; set the type bits to Char
	mov	si,listptr
	mov	dirlist[si],ax		; store type and key's new code
	jmp	dfkey7			; return success

dfkey6c:push	si			; clear a definition,
	push	di			; listptr points to current def
	mov	si,listptr		; starting address to clear
	add	si,offset dirlist
	mov	di,si			; destination
	add	si,2			; source is next word
	mov	cx,nkeys		; current number of keys defined
	add	cx,cx			; double for listptr being words
	sub	cx,listptr		; cx = number of words to move
	shr	cx,1			; convert to actual number of moves
	jcxz	dfkey6d			; z = none, just remove last word
	push	es
	push	ds
	pop	es			; make es:di point to data segment
	cld
	push	cx			; save cx
	rep	movsw			; move down higher list items
	pop	cx
	mov	si,listptr		; do keylist too, same way
	add	si,offset keylist
	mov	di,si
	add	si,2
	rep	movsw
	pop	es
dfkey6d:mov	si,nkeys		; clear old highest list element
	shl	si,1			; address words
	mov	dirlist[si],0		; null the element
	mov	keylist[si],0		; null the element
	dec	nkeys			; say one less key defined now
	pop	di			; restore saved registers
	pop	si

dfkey7:	mov	ah,msutake		; Finish up. In a Take file?
	or	ah,taklev		; or even directly
	or	ah,ah
	jz	dfkey7a			; z = no
	cmp	flags.takflg,0		; echo Take commands?
	je	dfkey7b			; e = no
dfkey7a:mov	ah,prstr		; display cr/lf
	mov	dx,offset crlf
	int	dos
	call	shkey0			; show new definition (in SHKEY)
	call	shkfre			; show free string space
dfkey7b:clc				; return success
	ret
DFKEY	ENDP

; SHOW KEY <cr> command. Call from Kermit level. Vectored here by SHOW
; command. Replaces obsolete procedure in msx---.
; Prompts for a key and shows that key's (or all if ? entered) keycode,
; definition, and the key definition free space remaining.

SHKEY	PROC	NEAR			; Show key's definition command
	mov	ah,cmeol		; get a confirm
	call	comnd			; ignore any additional text
	push	bx
	mov	dx,offset shkmsg1	; ask for original key
	mov	ah,prstr
	int	dos
	or	byte ptr kbcodes,80h	; say kbcodes not-initiated
shky0:	call	getkey			; read keyboard, output to keycode
	jc	shky0			; wait for a key (c = nothing there)
	cmp	byte ptr keycode,'?'	; query for all keys?
	jne	shky0a			; ne = no, not a query
	test	keycode,scan		; is this a scan code, vs ascii query?
	jz	shky0c			; z = no Scan, so it is a query

shky0a:	mov	ah,prstr		; show single key. Setup display
	mov	dx,offset crlf
	int	dos
	call	shkey0			; show just one key
shky0b:	call	shkfre			; show free string space
	jmp	shkeyx			; exit

shky0c:	mov	cx,nkeys		; Show all keys. nkeys = number defined
	jcxz	shky0b			; z = none to show
	mov	si,offset keylist	; list of definitions
	push	si			; save pointer
shky1:	pop	si			; recover pointer
	cld
	lodsw				; get a keycode
	push	si			; save pointer
	push	cx			; save counter
	mov	keycode,ax		; save new keycode
	mov	ah,prstr
	mov	dx,offset crlf
	int	dos
	call	shkey0			; show this keycode

	pop	cx			; pause between screens, recover cntr
	push	cx			; save it again
	dec	cx			; number yet to be shown
	jcxz	shky1b			; z = have now shown all of them
	mov	ax,nkeys		; number of defined keys
	sub	ax,cx			; minus number yet to be displayed
	xor	dx,dx			; clear extended numerator
	cmp	isps55,0		;[HF]940211 Japanese PS/55?
	je	shky1d			;[HF]940211 e = no
	cmp	ps55mod,0		;[HF]940211 is system modeline active?
	jne	shky1d			;[HF]940211 ne = no
	div	eleven			;[HF]940211 yes, actvie screen is 23
	jmp	short shky1e		;[HF]940211
shky1d:	div	twelve			; two lines per definition display
shky1e:	or	dx,dx			; remainder zero (12 defs shown)?
	jnz	shky1b			; nz = no, not yet so keep going
	mov	ah,prstr
	mov	dx,offset shkmsg3	; "push any key to continue" msg
	int	dos
shky1a:	mov	ah,0bh			; check console, check ^C
	int	dos
	cmp	flags.cxzflg,'C'	; a ^C?
	je	shky1b			; e = yes, quit
	or	al,al
	jz	shky1a			; z = nothing
	call	getkey			; get any key
	jc	shky1a			; c = nothing at keyboard yet, wait
shky1b:	pop	cx			; resume loop
	cmp	flags.cxzflg,'C'	; a ^C?
	je	shky1c			; e = yes, quit
	loop	shky1
shky1c:	pop	si			; clean stack
	call	shkfre			; show free string space
	jmp	shkeyx			; exit

		; show key worker routine, called from above
					; SHKEY0 called by DFKEY just above
SHKEY0:	test	keycode,scan		; scan code?
	jz	shkey1			; z = no, regular ascii

					; SCAN codes
	mov	dx,offset scanmsg	; say Scan Code:
	mov	ah,prstr
	int	dos
	mov	ah,conout
	mov	dl,'\'			; add backslash before number
	int	dos
	mov	ax,keycode		; get key's code again
	call	decout			; display 16 bit decimal keycode
	jmp	shkey2			; go get definition

shkey1:	mov	dx,offset ascmsg	; say ASCII CHAR
	mov	ah,prstr
	int	dos
	mov	dl,byte ptr keycode	; get ascii code (al part of input)
	mov	ah,conout
	cmp	dl,spc			; control code?
	jae	shkey1a			; ae = no
	push	dx			; save char
	mov	dl,5eh			; show caret first
	int	dos
	pop	dx
	add	dl,'A'-1		; ascii bias
shkey1a:cmp	dl,del			; DEL?
	jne	shkey1b			; ne = no
	mov	dl,'D'			; spell out DEL
	int	dos
	mov	dl,'E'
	int	dos
	mov	dl,'L'
shkey1b:int	dos
	mov	dl,spc			; add a couple of spaces
	int	dos
	int	dos
	mov	dl,'\'			; add backslash before number
	int	dos
	mov	ax,keycode		; show 16 bit keycode in decimal
	call	decout			; and go get definiton

					; Display defintion
shkey2:	mov	dx,offset shkmsg2	; intermediate part of reply
	mov	ah,prstr		; " is defined as "
	int	dos
	push	di			; get a director code for this key
	push	cx	
	mov	di,offset keylist	; list of keycodes
	mov	cx,nkeys		; number currently defined
	jcxz	shkey2a			; z = none
	mov	ax,keycode		; present keycode
	push	ds
	pop	es			; use data segment for es:di
	cld
	repne	scasw			; is current keycode in the list?
	jne	shkey2a			; ne = not in list
	sub	di,2			; correct for auto increment
	sub	di,offset keylist
	mov	listptr,di		; list pointer for existing definition
	pop	cx
	pop	di
	jmp	shkey3			; go process definition

shkey2a:pop	cx
	pop	di
	mov	dx,offset noxmsg	; say Self (no translation)
	mov	ah,prstr
	int	dos
	ret				; return to main show key loop

shkey3:					; translations, get kind of.
	mov	si,listptr
	test	dirlist[si],verb	; defined as verb?
	jnz	shkey6			; nz = yes, go do that one
	test	dirlist[si],strng	; defined as string?
	jz	shkey3a			; z = no
	jmp	shkey8			; yes, do string display
shkey3a:
	mov	dx,offset ascmsg	; CHAR. say 'Ascii char:'
	mov	ah,prstr
	int	dos
	mov	ax,dirlist [si]		; get type and char
	mov	dl,al			; put char here for display
	push	ax			; save here too
	mov	ah,conout
	cmp	dl,spc			; control code?
	jae	shkey4			; ae = no
	push	dx
	mov	dl,5eh			; show caret
	int	dos
	pop	dx
	add	dl,'A'-1		; add ascii bias
shkey4:	cmp	dl,del			; DEL?
	jne	shkey4a			; ne = no
	mov	dl,'D'			; spell out DEL
	int	dos
	mov	dl,'E'
	int	dos
	mov	dl,'L'
shkey4a:int	dos
	mov	dl,spc			; add a couple of spaces
	mov	ah,conout
	int	dos
	int	dos
	mov	dl,'\'			; add backslash before number
	int	dos
	pop	ax			; recover char
	xor	ah,ah			; clear high byte
	call	decout			; show decimal value
	ret				; return to main show key loop

shkey6:	mov	ah,prstr		; VERB
	mov	dx,offset verbmsg	; say 'verb'
	int	dos
	mov	si,listptr		; get verb index from director
	mov	dx,dirlist[si]
	and	dx,not(verb+strng)	; remove type bits, leaves verb number
	mov	bx,offset kverbs	; table of verbs & actions
	mov	al,byte ptr [bx]	; number of keywords
	xor	ah,ah
	dec	ax
	mov	kwcnt,ax		; save number of last one here
	cmp	dx,ax			; asking for more than we have?
	ja	shkeyx			; a = yes, exit bad
	inc	bx			; point to first slot
	xor	cx,cx			; current slot number
shkey6b:cmp	cx,dx			; this slot?
	je	shkey6c			; e = yes, print the text part
	ja	shkeyx			; a = beyond, exit bad
	mov	ax,[bx]			; get cnt (keyword length)
	add	ax,4			; skip count and two byte value
	add	bx,ax			; bx = start of next keyword slot
	inc	cx			; current keyword number
	jmp	short shkey6b		; try another
shkey6c:push	cx
	mov	cx,[bx]			; length of definition
	add	bx,2			; look at text field
	mov	di,bx			; offset for printing
	call	prtscr			; print counted string
	mov	ah,conout
	mov	dl,spc			; add a couple of spaces
	int	dos
	int	dos
	mov	dl,'\'			; show verb name as \Kverb
	int	dos
	mov	dl,'K'
	int	dos
	call	prtscr			; print counted string, again
	pop	cx
	ret				; return to main show key loop

shkey8:	mov	ah,prstr		; STRING
	mov	dx,offset strngmsg	; say String:
	int	dos
	mov	si,listptr		; get index from director
	mov	bx,dirlist[si]
	and	bx,not(verb+strng)	; remove type bits
	shl	bx,1			; index words
	mov	si,sptable[bx]		; table of string offsets
	mov	cx,word ptr [si]	; get string length
	add	si,2			; point to string text
	mov	ah,conout
shkey8a:cld
	lodsb				; get a byte
	cmp	al,127			; DEL?
	je	shkey8c			; e = yes
	cmp	al,spc			; control code?
	jae	shkey8b			; ae = no
shkey8c:push	ax
	mov	dl,5eh			; show caret first
	int	dos
	pop	ax
	add	al,40h			; convert to printable for display
	and	al,7fh
shkey8b:mov	dl,al
	int	dos			; display it
	loop	shkey8a			; do another
	ret				; return to main show key loop
	
shkeyx:	pop	bx			; restore reg
	clc				; return success
	ret
SHKEY	ENDP

;;;	keyboard translator local support procedures, system independent

; Tstkeyw checks text word pointed to by si against table of keywords (pointed
; to by kverbs, made by mkeyw macro); returns in bx either action value or 0.
; Returns in kbtemp the number of the keyword and carry clear, or if failure
; returns kbtemp zero and carry set.
; Keyword structure is:	 	dw	cnt	(length of string 'word')
; 				db	'word'	(keyword string)
; 				dw	value	(value returned in bx)
; Make these with macro mkeyw such as   mkeyw 'test',15   with the list of
; such keywords headed by a byte giving the number of keywords in the list.
tstkeyw	proc	near
	push	ax
	push	cx
	push	si
	mov	verblen,0		; verblen will hold verb length
	push	si			; save user's verb pointer
tstkw1:	cld
	lodsb				; get a verb character
	cmp	al,spc			; verbs are all non-spaces and above
	jbe	tstkw2			; be = done (space or control char)
	cmp	word ptr [si-1],'}'	; closing brace?
	je	tstkw2			; e = yes, exclude as terminator
	inc	verblen			; count verb length
	jmp	short tstkw1		; printable char, look for more
tstkw2:	pop	si			; pointer to verb
	mov	bx,offset kverbs	; table of Kermit verb keywords
	mov	al,byte ptr [bx]	; number of keywords
	xor	ah,ah
	mov	kwcnt,ax		; save number of keywords here
	inc	bx			; point bx to first slot
	mov	kbtemp,0		; remember which keyword

tstkw3:					; match table keyword and text word
	mov	cx,verblen		; length of user's verb
	cmp	[bx],cx			; compare length vs table keyword
	jne	tstkw4			; ne = not equal lengths, try another
	push	si			; lengths match, how about spelling?
	push	bx
	add	bx,2			; point at start of keyword
tstkw3a:mov	ah,byte ptr [bx]	; keyword char
	mov	al,byte ptr [si]	; text char
	cmp	ah,'A'
	jb	tstkw3b			; b = control chars
	cmp	ah,'Z'
	ja	tstkw3b			; a = not upper case alpha
	add	ah,'a'-'A'		; convert upper case to lower case
tstkw3b:cmp	al,'A'
	jb	tstkw3c
	cmp	al,'Z'
	ja	tstkw3c
	add	al,'a'-'A'		; convert upper case to lower case
tstkw3c:cmp	al,ah			; test characters
	jne	tstkw3d			; ne = no match
	inc 	si			; move to next char
	inc	bx
	loop	tstkw3a			; loop through entire length
tstkw3d:pop	bx
	pop	si
	jcxz	tstkw5			; z: cx = 0, exit with match;
					;  else select next keyword
tstkw4:	inc	kbtemp			; number of keyword to test next
	mov	cx,kbtemp
	cmp	cx,kwcnt		; all done? Recall kbtemp starts at 0
	jae	tstkwx			;ae = exhausted search, unsuccessfully
	mov	ax,[bx]			; cnt (keyword length from macro)
	add	ax,4			; skip over count and two byte value
	add	bx,ax			; bx = start of next keyword slot
	jmp	tstkw3			; do another comparison

tstkw5:					; get action pointer
	mov	ax,[bx]			; cnt (keyword length from macro)
	add	ax,2			; skip over count
	add	bx,ax			; now bx points to dispatch value
	mov	bx,[bx]			; bx holds dispatch value
	clc				; carry clear for success
	jmp	short tstkwxx		; exit
	ret
tstkwx:	xor	bx,bx			; exit when no match
	mov	kbtemp,bx		; make verb number be zero too
	stc				; carry set for failure
tstkwxx:pop	si
	pop	cx
	pop	ax
	ret
tstkeyw	endp

; Insert asciiz string pointed to by si into string buffer stbuf.
; Reg cx has string length upon entry.
; Success: returns offset of first free byte (strmax) in string buffer stbuf,
; cx = type and Index of new string, and carry clear.
; Failure = carry set.
insertst proc	near
	push	bx
	push	dx
	push	si
	push	di
	push	kbtemp		; save this variable too
	mov	dx,cx		; save length of incoming string in dx
	mov	bx,offset sptable ; table of string offsets
	mov	kbtemp,0	; slot number
	mov	cx,maxstng	; number of entries, find an empty slot
insert1:cmp	word ptr[bx],0	; slot empty?
	je	insert2		; e = yes
	inc	kbtemp		; remember slot number
	add	bx,2		; look at next slot
	loop	insert1		; keep looking
	jmp	short insert4	; get here if no empty slots
insert2:			; see if stbuf has sufficient space
	mov	cx,dx		; length of new string to cx
	mov	di,strmax	; offset of first free byte in stbuf
	add	di,cx		; di = address where this string would end
	cmp	di,offset stbuf+stbuflen ; beyond end of buffer?
	jae	insert4		; ae = yes, not enough room
	mov	di,strmax	; point to first free slot in stbuf
	mov	[bx],di		; fill slot with address offset of buffer
	push	es
	push	ds
	pop	es		; point es:di to data segment
	cld
	mov	[di],cx		; length of text for new string
	add	di,2		; move to next storage slot
	rep	movsb		; copy string text
	pop	es
	mov	strmax,di	; offset of next free byte
	mov	cx,kbtemp	; return new slot number with Director Index
	and	cx,not(strng+verb) ; clear type bits
	or	cx,strng	; say type is multi-char string
	clc			; say success
	jmp	short insertx	; exit
insert4:stc			; say no-can-do
insertx:pop	kbtemp
	pop	di
	pop	si
	pop	dx
	pop	bx
	ret
insertst endp

; Remove (delete) string. Enter with listptr preset for director entry.
; Acts only on existing multi-char strings; recovers freed space.
; All registers preserved.
remstr	proc	near		
	push	si
	mov	si,listptr		; list pointer
	test	dirlist[si],strng	; multi-char string?
	pop	si
	jnz	remst1			; nz = a multi-char string
	ret				; else do nothing
remst1:	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	mov	si,listptr
	mov	ax,dirlist[si] 		; Director table entry
	and	ax,not(strng+verb) ; clear type bits, leave string's pointer
	mov	dirlist[si],0		; clear Director table entry
	shl	ax,1			; index words not bytes
	mov	si,offset sptable 	; list of string offsets in stbuf
	add	si,ax			; plus index = current slot
	mov	bx,[si]			; get offset of string to be deleted
	mov	dx,bx			; save in dx for later
	mov	cx,[bx]			; get length of subject string
	add	cx,2			; length word too, cx has whole length
	sub	strmax,cx	; count space to be freed (adj end-of-buf ptr)
	mov	word ptr [si],0	; clear sptable of subject string address
	push	cx			; save length of purged string
	push	di			; save di
	push	si
	push	es			; save es
	push	ds
	pop	es		; setup es:di to be ds:offset of string
	mov	di,dx		; destination = start address of purged string
	mov	si,dx		; source = start address of purged string
	add	si,cx		;  plus string length of purged string.
	mov	cx,offset stbuf+stbuflen ; 1 + address of buffer end
	sub	cx,si			; 1 + number of bytes to move
	dec	cx			; number of bytes to move
	jcxz	remst2			; z = none
	cld				; direction is forward
	rep	movsb			; move down preserved strings
remst2:	pop	es			; restore regs
	pop	di
	pop	si
	pop	ax		; recover length of purged string (was in cx)
	mov	bx,offset sptable 	; string pointer table
	mov	cx,maxstng		; max mumber of entries
remst4:	cmp	[bx],dx		; does this entry occur before purged string?
	jbe	remst5		; be = before or equal, so leave it alone
	sub	[bx],ax		; recompute address (remove old string space)
remst5:	add	bx,2			; look at next list entry
	loop	remst4			; do all entries in sptable
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
remstr	endp

shkfre	proc	near			; show free key & string defs & space
	push	ax			; preserves all registers.
	push	bx
	push	cx
	push	dx
	push	kbtemp
	mov	dx,offset fremsg
	mov	ah,prstr
	int	dos
	mov	ax,maxkeys		; max number of key defs
	sub	ax,nkeys		; number currently used
	call	decout			; show the value
	mov	ah,prstr
	mov	dx,offset kyfrdef	; give key defs msg
	int	dos
	mov	bx,offset sptable	; table of string pointers
	mov	cx,maxstng		; number of pointers
	mov	kbtemp,0		; number free
shkfr1:	cmp	word ptr [bx],0		; slot empty?
	jne	shkfr2			; ne = no
	inc	kbtemp			; count free defs
shkfr2:	add	bx,2			; look at next slot
	loop	shkfr1			; do all of them
	mov	ax,kbtemp		; number of free defs
	call	decout			; display
	mov	dx,offset stfrdef	; say free string defs
	mov	ah,prstr
	int	dos
	mov	ax,offset stbuf+stbuflen ; 1 + last byte in stbuf
	sub	ax,strmax		; offset of last free byte in stbuf
	call	decout
	mov	dx,offset stfrspc	; give free space part of msg
	mov	ah,prstr
	int	dos
	pop	kbtemp
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
shkfre	endp

; Initialize the keyboard tables at Kermit startup time. Optional procedure.
; Requires kbdinlst to be configured with mkeyw macro in the form
;	mkeyw	'definition',keytype*256+keycode
; keytype is 0 for scan codes and non-zero for ascii.
; Returns normally.
kbdinit	proc 	near			; read keyword kbdinlst and setup
	or	byte ptr kbcodes,80h	; say kbcodes not-initiated
	push	ds			;  initial keyboard assignments.
	pop	es			; set es:di to data segment
	inc	taklev			; pretend that we are in Take file
	call	chk250			;** LK250 support begin
	cmp	got250,1		;** is it installed?
	jne	kbdini0			;** ne = no
	call	kbrest			;** else initialize to DEC mode
	mov	si,offset kb250lst	;** load extensions
	jmp	short kbdini1		;** LK250 support end
kbdini0:mov     si,offset kbdinlst      ; start of list of definitions
kbdini1:mov	cx,[si]			; cnt field (keyword length of macro)
	jcxz	kbdinix			; z = null cnt field = end of list
	add	si,2			; look at text field
	mov	di,offset tranbuf	; where defkey expects text
	push	cx
	cld
	rep	movsb			; copy cx chars to tranbuf
	pop	cx
	mov	byte ptr [di],0		; insert null terminator
	mov	ax,word ptr [si]	; get value field
	mov	keycode,ax		; set key ident value
	push	si
	call	dfkey2			; put dfkey to work
	pop	si
	add	si,2			; point to next entry
	jmp	kbdini1			; keep working
kbdinix:dec	taklev			; reset Take file level
	call	fudkclear		; clear User Definable Keys
	mov	cx,40h			; segment 40h
	mov	es,cx
	mov	cl,byte ptr es:[96h]	; kbd_flag_3, Enhanced keyboard area
	test	cl,10h			; select Enhanced kbd presence bit
	jz	kbdinx1			; z = regular (88)
	mov	keyboard,101		; 101 = enhanced kbd
kbdinx1:ret
kbdinit	endp
;;;	End of System Independent Procedures

;;;	Begin System Dependent Procedures

; Read keyboard. System dependent.
; Return carry set if nothing at keyboard.
; If char present return carry clear with key's code in Keycode.
; If key is ascii put that in the low byte of Keycode and clear bit Scan in
; the high byte; otherwise, put the scan code in the lower byte and set bit
; Scan in the high byte.
; Bit Scan is set if key is not an ascii code.
; Two methods are used: Bios reading for Set Key ON, and DOS reading for
; Set Key OFF. DOS scan codes are coerced to Bios values as much as possible.
; Modifies register ax.
getkey	proc	near
	mov	keycode,0		; clear old keycode
	cmp	dosflg,0ffh		; do DOS keyboard reading?
	je	getky7			; e = yes, DOS
	jmp	getky6			; do full Bios form
					; ;;;;;;;; D O S ;;;;;;;;;;
getky7:	test	byte ptr kbcodes,80h	; kbcodes initiated?		[dan]
	jz	getky5			; z = yes			[dan]
	and	byte ptr kbcodes,not 80h ; say kbcodes initiated
getky5:	call	iseof			; is stdin at eof?
	jnc	getky5k			; nc = not eof, get more
 	mov	al,trans.escchr		; Kermit's escape char
	mov	byte ptr keycode,al	; save ascii char
	clc				;  to get out gracefully at EOF
	ret				; and exit

getky5k:mov	dl,0ffh			; DOS read operation
	mov	ah,dconio		; from stdin
	int	dos
	jnz	getky5a			; nz = char available
	stc				; carry set = nothing available
	ret				; exit on no char
getky5a:or	al,al			; scan code precursor?
	jz	getky5d			; z = yes
	cmp	al,16			; Control P?
	jne	getky5b			; ne = no
	mov	al,114			; force Control PrtSc scan code
	jmp	short getky5e		; process as scan code
getky5b:cmp	al,BS			; backspace key?
	jne	getky5c			; ne = no
	mov	al,14			; force scan code for BS key
	jmp	short getky5e		; process as scan code
getky5c:mov	byte ptr keycode,al	; save ascii char
	clc				; carry clear = got a char
	ret				; and exit

getky5d:mov	dl,0ffh			; read second byte (actual scan code)
	mov	ah,dconio		; read via DOS
	int	dos
	jnz	getky5e			; nz = got a char
	stc				; none, declare bad read
	ret
					; Check and modify to Bios scan codes
getky5e:mov	byte ptr keycode,al	; save char code
	cmp	al,1			; Alt escape
	je	getkya			; set Alt bit
	cmp	al,16			; back tab
	jb	getky5g			; these remain unchanged
	cmp	al,50			; start of meta keys
	jb	getkya			; b = set Alt bit
	cmp	al,84			; Shift F1
	jb	getky5g			; b = no change
	cmp	al,94			; Control F1
	jb	getkys			; set Shift bit
	cmp	al,104			; Alt F1
	jb	getkyc			; set Control bit
	cmp	al,114			; Control PrtSc
	jb	getkya			; set Alt bit
	cmp	al,120			; Alt top rank
	jb	getkyc			; set Control bit
	cmp	al,132			; Control PgUp
	jb	getkya			; set Alt bit
	je	getkyc			; set Control bit
	cmp	al,135			; Shift F11, for Enhanced keyboard
	jb	getky5g			; no change
	cmp	al,137			; Control F11
	jb	getkys			; set Shift bit
	cmp	al,139			; Alt F11
	jb	getky5c			; set Control bit
	cmp	al,141			; Control Up
	jb	getkya			; set Alt bit
	cmp	al,151			; Alt Home
	jb	getkyc			; set Control bit
	jmp	short getkya		; set Alt bit
getkyc:	or	keycode,control		; set Control bit
	jmp	short getky5g
getkys:	or	keycode,shift		; set Shift bit
	jmp	short getky5g
getkya:	or	keycode,alt		; set Alt bit
getky5g:or	keycode,scan		; ensure scan bit is set
	clc				; report we have a scan keycode
	ret				; and exit

					; ;;;;;;;;;; B I O S ;;;;;;;;;;;;;
getky6:					; full BIOS keyboard reading
	test	byte ptr kbcodes,80h	; kbcodes initiated?		[dan]
	jz	getky6a			; z = yes			[dan]
	mov	kbcodes,0001h		; low byte = status, high = read char
	push	cx			; save registers
	push	es
	mov	cx,40h			; segment 40h
	mov	es,cx
	mov	cl,byte ptr es:[96h]	; kbd_flag_3, Enhanced keyboard area
	and	cl,10h			; select Enhanced kbd presence bit
	mov	ch,cl			; copy, for both status and read
	or	kbcodes,cx		; 0 = regular kbd, 10h = enhanced kbd
	pop	es
	pop	cx

getky6a:mov	ah,byte ptr kbcodes	; anything at keyboard?
	xor	al,al
	int	kbint			; Bios keyboard interrupt
	jnz	getky1			; nz = char available
	cmp	ax,240			; Bios "special ascii code" 0f0h?
	je	getky1			; e = yes, Bios makes error, is a key
	stc				; carry set = nothing available
	ret	 			; exit on no char available
getky1:	mov	ah,byte ptr kbcodes+1	; read, no echo, wait til done
	int	kbint			; ==> ah = scan code, al = char value
	cmp	ah,0			; keycode entered by ALT ###?
	je	getky1c			; e = yes, not enhanced
	cmp	ah,0e0h			; Enhanced kbd Enter, fwd slash keys?
	jne	getky1b			; ne = no
	xchg	ah,al			; interchange scan and ascii fields
getky1b:cmp	al,0E0h			; enhanced key hidden code?
	jne	getky1c			; ne = no
	mov	byte ptr keycode,ah	; retain scan code, surpress 0e0h
	or	keycode,scan+enhanced	; set scan and enhanced idents
	mov	ah,2			; use regular keyboard op code here
	int	kbint			; get current shift state
	mov	bl,al			; copy for a moment
	and	bl,rgt_shift		; mask out all but right shift
	shl	bl,1			; move right shift to left shift pos
	or	al,bl			; collapse shift bits
	and	al,(lft_shift + alt_shift + ctl_shift)
	or	byte ptr keycode+1,al	; store in type field of keycode
	clc				; say have a keystroke
	jmp	getkyx			; Enhanced kbd end. Skip other tests

getky1c:push	cx
	mov	cx,aliaslen		; number of aliased keys
	or	cx,cx
	pop	cx
	jz	getky2			; z = none
	push	di			; check key (ax) for aliases
	push	cx
	push	es
	push	ds
	pop	es			; make es:di refer to data segment
	mov	di,offset aliaskey	; list of aliased keys
	mov	cx,aliaslen		; number of entries
	cld
	repne	scasw			; look for a match
	pop	es
	pop	cx
	pop	di
	jne	getky2			; ne = not there
	xor	al,al			; force use of scan code (in ah)
getky2:	or	al,al			; scan code being returned?
	jnz	getky3			; nz = no
	mov	byte ptr keycode,ah	; store scan code for gsh
	push	ax
	push	bx
	call	gsh			; get modified shift state
	or	byte ptr keycode+1,al	; store in type field of keycode
	pop	bx
	pop	ax
	xchg	ah,al			; put scan code in al
	or	keycode,scan		; set scan flag (vs ascii)
getky3:	mov	byte ptr keycode,al	; return key's code (usually ascii)
	clc				; carry clear = got a char
getkyx:	ret
getkey	endp


; get shift state into al.  We care about only shift, ctl, and alt keys.
; right shift is collapsed into left shift. NumLock offsets Shift on keypad
; white keys.
gsh	proc	near
	mov	ah,2
	int	kbint			; get current shift state
	mov	bl,al			; copy for a moment
	and	bl,rgt_shift		; mask out all but right shift
	shl	bl,1			; move right shift to left shift pos
	or	al,bl			; collapse shift bits
	cmp	byte ptr keycode,71	; below numeric key pad?
	jb	gsh1			; b = yes
	cmp	byte ptr keycode,83	; above numeric key pad?
	ja	gsh1			; a = yes
	cmp	byte ptr keycode,74	; grey - key ?
	je	gsh1			; e = yes
	cmp	byte ptr keycode,78	; grey + key
	je	gsh1			; e = yes
	test	al,numlock		; numlock set?
	jz	gsh1			; z = no
	xor	al,lft_shift		; numlock offsets shift and vice versa
gsh1:	and	al,(lft_shift + alt_shift + ctl_shift)
	ret
gsh	endp


; Do any local processing after reading a key during active translation
; Avoids same actions if a key is being defined or shown.
postkey	proc	near
					; Key Click code for VT102 emulator
	cmp	flags.vtflg,0		; emulating? (0 = no)
	je	postke1			; e = extra clicks not available
	test	vtemu.vtflgst,vskeyclick ; flags from SET TERM
	jz	postke1			; z = extra clicks not wanted
	call	fvclick			; click, what else?
postke1:ret
postkey	endp
					;** start of LK250 stuff
kbrest	proc	near			; set LK250 to DEC mode
	cmp	got250,1		; LK250 present?
	jne	kbrest1			; ne = no
	push	es			; save reg
	mov	ax,40h			; point to low memory
	mov	es,ax
	or	byte ptr es:[17h],20h	; ensure Num Lock is on
	and	byte ptr es:[17h],0efh	;  and Scroll is off
	pop	es			; restore our [DS]
	mov	ax,5001h		; issue set mode DEC to keyboard
	int	15h
kbrest1:ret
kbrest	endp

kbsusp	proc	near			; set LK250 to DOS mode
	cmp	got250,1		; LK250 present?
	jne	kbsusp1			; ne = no
	mov	ax,5000h		; unload extensions
	int	15h
kbsusp1:ret
kbsusp	endp

kbhold	proc	near
	cmp	got250,1		; LK250 present?
	jne	kbhold1			; ne = no
	mov	ax,5002h		; issue SET LEDS
	mov	bl,0edh
	int	15h
	mov	ax,5002h
	mov	bl,holdscr		; get the hold state
	or	bl,2			; OR in Num Lock
	int	15h
kbhold1:ret
kbhold	endp				;** end of LK250 stuff

code	ends
code1	segment
	assume	cs:code1
					; LK250 stuff
chk250	proc	far			; presence test for DEC LK250 keyboard
	mov	got250,0		; assume no LK250 keyboard
	cmp	dosflg,1		; use LK250?
	jne	chk250x			; ne = no
	mov	ax,sp			; do push sp test for XT vs AT/386
	push	sp			; XT pushes sp-2, AT's push old sp
	pop	cx			; recover pushed value, clean stack
	xor	ax,cx			; same?
	jne	chk250a			; ne = no, XT. Don't do Int 15h
	mov	ax,5000h		; see if the keyboard is loaded
	int	15h			; look for DOS->DEC mode driver
	cmp	ax,1234h		; find marker 1234h
	jne	chk250a			; ne = marker not present, no driver
	mov	got250,1		; else say we have an LK250
	mov	keyboard,250		; global Variable
chk250x:ret
chk250a:mov	ah,prstr
	mov	dx,offset lk250msg	; say driver not active
	int	dos
	ret
chk250	endp
code1	ends
	end
