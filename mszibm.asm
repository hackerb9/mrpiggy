	NAME	mszibm
; File MSZIBM.ASM
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
; Terminal emulator module for IBM PC's and compatibles. Emulates Heath-19,
; VT52, VT102, and VT320, Honeywell VIP7809, Prime PT200, DG D463 and D470,
; and Wyse-50. 
; Original version for VT100 done by James Harvey, Indiana Purdue Univ, for 
; MS Kermit 2.27. Taken from there by Joe Doupnik, Utah State Univ for 
; MS Kermit 2.29 et seq.
; Edit history
; 12 Jan 1995 version 3.14
; Last edit
; 12 Jan 1995

	public	anstty, ansini, ansrei, ansdsl, anskbi ; Entry points
	public	ans52t, vsinit, tabset, tabclr, tekflg
	public	mar_top, mar_bot, anspflg, scroll, cursor, curattr
	public	dnparam, dparam, dlparam, dninter, dinter, emubufc, emubuf
	public	emubufl, dcsstrf, upss, att_normal
	public	GRptr, G0set, G1set, G2set, G3set
	public	savezlen, savezoff, blinkdis, protectena, dghscrdis
	public	linescroll, xltkey, dgkbl, dgwindcomp, atctype, dgcross
	public	dgnctoggle, apcstring, dgd470mode, chrdef

public modeset, setptr, atrsm10, mkascii, mkaltrom, chrsetup
;
; DEC and VT are trademarks of Digital Equipment Corporation.
;
; Description of the global entry points and calls on external routines
; needed by this emulator.
;
; vsinit - start up routine called as Kermit initializes. Takes no arguments.
;	   Sets up address pointers to tabs, reads default terminal parameters
;	   reads current screen coloring. Examines and updates structure
;	   "vtemu." which is how mssset communicates changed information
;	   about many Set Term parameters; "flags." is a Kermit structure
;	   carrying the other Set Term parameters.
; anstty - starting point for displaying a character, delivered in AL.
;	   Returns when the display operation is completed and that may
;	   take many many instructions. All normal "characters received by
;	   the terminal" are provided by calling anstty with the char in AL.
; ansini - entry point to initialize the emulator. It requires information
;	   from msy in four registers: the Kermit terminal routine flags
;	   "yflags" (used mainly to sense debug mode and the mode line toggle)
;	   "low_rgt" (bh = row, bl = column of the lower right display corner)
;	   "lbaudtab" (index into baud rate table, for status reporting)
;	   "lpartab" (index into parity table, for status reporting)
;	   Ansini causes a full reset of the emulator, including screen 
;	   clearing and a beep. Ansini is also called by msy in response to
;	   sensing the Alt = key combination to fully reset the emulator.
; ansrei - entry point to reinitialize the emulator. Nearly the same as
;	   ansini except operating flags, tabs, etc are retained from the
;	   previous emulator session. Items which can be changed by Set Term
;	   are examined and updated. The msy flags "yflags" are needed.
;	   This is the warm-restart entry point used when connect mode
;	   is reentered gracefully. The screen is cleared only if the coloring
;	   has changed. The starting cursor location is whereever msy puts it.
; ansdsl - display "led" (status line) information. Invoked by msy when
;	   the mode line is constructed so the emulator can write the 
;	   terminal type and the VT100 led status lights when Connect mode
;	   is started. Requires "yflags" from msy to sense whether the mode
;	   line is to be shown.
; anskbi - a routine called by msy to notify the emulator that a character
;	   is available from the keyboard. No character is read, just flag
;	   ttkbi is set. This is actually used only to beep when the cursor
;	   goes beyond column 72 and the margin bell flag is on.
; ans52t - called by msy to change terminal types "on the fly" without
;	   fully updating all operating parameters and without losing setup
;	   information. Msy senses the Alt minus key and calls ans52t with
;	   no arguments. Ans52t cycles among terminal types.
; other modules in msy are called by this file to handle screen scrolling
;	   mode line on/off, output to the serial port (reports), screen
;	   particulars (location, cursor shape, blanking). The list is
;	   the set of code extrn procedures below; all are in file msy.
;
; data exchange is directly with msy to assist in scrolling (varaibles
;	   "mar_top", "mar_bot") and in sensing the non-connect
;	   mode screen coloring ("scbattr"). Screen coloring controlled by
;	   the emulator is not permitted to influence the non-connect mode
;	   screens whereas the emulator attempts to use the regular Kermit
;	   screen colors as defaults. The kind of terminal to emulate is
;	   held in word "flags.vtflg" which is set by Set Term and by this
;	   module for global information within Kermit.
;
; Many things have been added or modified since James Harvey donated this
;	   code to Columbia University for use in Kermit.              [jrd]
; Character sets in VT320 and VT102 modes:
;  ASCII ("B"/94)
;  ISO Latin-1 ("A"/96)
;  DEC UK-ASCII ("A"/94, available only in VT102 mode)
;  DEC Supplemental Graphics ("%5"/94),
;  DEC Technical Graphics (">"/94), an extension taken from the VT340,
;  DEC Special Graphics ("0"/94 and "2"/94)
;  ALT-ROM (Kermit specific, "1"/94/96)
;  DEC National Replacement Chars (all 12 sets)
;  Startup:
;   GL = G0 = G1 = ASCII (or ALT-ROM if selected by SET TERM CHAR ALT-ROM),
;   GR = G2 = G3 = ISO Latin-1.
;   When an NRC is selected by SET TERM CHAR <country> and enabled by
;   CSI ? 42 h the NRC table replaces G0..G3 at the time of selection. When
;   thus designated and selected incoming characters are forced to 7 bits and
;   8-bit Controls (outgoing) is turned off. No designation means no selection.
;  Selecting a character set with the wrong sized designator yields no action.
;
;  Startup in D463/D470 mode:
;   GL = G0 = ASCII
;   GR = G1 = Data General International if using 8-bit characters, else
;   GR = G1 = Data General Word Processing.
;
; References:
;  "PT200 Programmers Reference Guide", 1984, Prime Computer # DOC 8621-001P
;  "Video Terminal Model H19, Operation", 1979, Heath Company # 595-2284-05
;  "VT100 User's Guide", 2nd ed., Jan 1979, DEC # EK-VT100-UG
;  "Rainbow 100+/100B Terminal Emulation Manual", June 1984, DEC # QV069-GZ
;  "Installing and Using The VT320 Video Terminal", June 1987,
;	DEC # EK-VT320-UU-001
;  "VT320 Programmer Reference Manual", July 1987, DEC # EK-VT320-RM-001
;  "VT330/340 Programmer Ref Manual", 2nd ed, May 1988,
;    Vol 1: Text programming DEC # EK-VT3XX-TP-002
;    Vol 2: Graphics programming DEC # EK-VT3XX-GP-002
;  "Programming the Display Terminal: Models D217, D413, and D463", Data
;    General Corp, 014-00211-00, 1991.
;  "Installing and Operating Your D216E+, D217, D413, and D463 Display
;    Terminals", Data General Corp, 014-002057-01, 1991.
;  "Dasher D470C Color Display Terminal, Programmer's Reference Manual",
;    Data General Corp, 014-001015, 1984.
;  "WY-50 Display Terminal Quick-Reference Guide", Wyse Technology,
;    Wyse No. 88-021-01, 1983.
; ---------------------------------------------------------------------------

vswidth	equ	207			; cross correlate with msyibm
swidth  equ     207			; assumed max screen width
slen	equ	60			; assumed max screen length 
maxparam equ	10			; number of ESC and DCS Parameters
maxinter equ	10			; number of ESC and DCS Intermediates
gsize	equ	128			; character set storage size
					; anspflg bit field definitions:
; prtscr equ	1			; used in msyibm print screen toggle
vtautop	equ	1			; autoprint enabled (1)
vtcntp	equ	2			; controller print enabled (1)
vtextp	equ	4			; printer extent set (1)
vtffp	equ	10h			; form feed wanted at end of print (1)

h19l25	equ	1			; h19stat, line 25 enabled
h19alf	equ	2			; h19stat, auto cr/lf when cr seen
					; display save-info for dspstate
dsptype	equ	1			; main (0) or status line (1) flag
dspdecom equ	2			; remembered origin mode (1=on)

att_bold	equ	08h		; bold		in main video word
att_blink	equ	80h		; blinking	in main video word
att_protect	equ	01h		; protected	in vsatt
att_uline	equ	02h		; underscored	in vsatt
att_rev		equ	04h		; reversed video  in vsatt
;softfonts	are	top 5 bits of extended attributes

braceop	equ	7bh			; opening curly brace
bracecl	equ	7dh			; closing curly brace

; DEC emulator status flags (bits in words vtemu.vtflgst and vtemu.vtflgop)
;anslnm  equ	1H			; ANSI line feed/new line mode
;decawm  equ	2H			; DEC autowrap mode
;decscnm equ	80H			; DEC screen mode
;decckm  equ	200H			; DEC cursor keys mode
;deckpam equ	400H			; DEC keypad application mode
;decom   equ	800H			; DEC origin mode
;deccol	 equ	1000H			; DEC column mode (0=80 col)
;decanm  equ	2000H			; ANSI mode
;;dececho equ	4000H			; ANSI local echo on (1 = on)
     
; Terminal SETUP mode flags (joint with bits above, some name dups)
;vsnewline	equ	1H		; ANSI new line (0 = off)
;vswrap		equ	2H		; Line wrap around (0 = no wrap)
;vsnrcm		equ	4H		; National Rep Char set (0=none)
;vswdir		equ	8H		; Writing direction (0=left, 1 right)
;vskeyclick	equ	10H		; Keyclick (0 = off)
;vsmarginbell	equ	20H		; Margin bell (0 = off)
;vscursor	equ	40H		; Cursor (0 = block, 1 = underline)
;vsscreen	equ	80H		; Screen (0 = normal, 1 = rev. video)
;vscntl		equ	100h		; 8 or 7 bit controls (1 = 8-bit)
;vshscroll	equ	4000h		; horiz scroll (0=auto, 1=manual)
;vscompress	equ	8000h		; compressed text(0=graphics,1=132col)

;vsdefaults	equ	0+vscursor

; Kinds of terminals available
;ttgenrc	equ	0		; no emulation done by Kermit
;ttheath	equ	1		; Heath-19
;ttvt52		equ	2		; VT52
;ttvt100	equ	4		; VT100
;ttvt102	equ	8		; VT102
;ttvt220	equ	10h		; VT220
;ttvt320	equ	20h		; VT320
;tttek		equ	40h		; Tektronix 4010
;tthoney	equ	80h		; Honeywell VIP7809
;ttpt200	equ	100h		; Prime PT200
;ttd463		equ	200h		; Data General D463
;ttd470		equ	400h		; Data General D440
;ttwyse		equ	800h		; Wyse-50
;ttd217		equ	1000h		; Data General D217 (D463 w/217 ident)
;ttansi		equ	2000h		; Ansi.sys flavor (VT100 base)
;TTTYPES	equ	15		; Number of terminal types defined
;; tekflg bits in byte
;tek_active equ	1			; actively in graphics mode
;tek_tek equ	2			; Tek terminal
;tek_dec equ	4			; Tek submode of DEC terminals
;tek_sg	equ	8			; special graphics mode

;emulst	struc		; structure of vtemu.xxx for VTxxx emulator
;vtflgst dw	0	; DEC setup flags (from SET)
;vtflgop dw	0	; DEC runtime flags, like setup flags (here & STAT)
;vttbs	dw	0	; pointer to default tab stops, for SET
;vttbst	dw	0	; pointer to active tab stops, for STATUS
;vtchset db	1	; value of default character set (1=US-ascii)
;att_ptr dw	0	; pointer to normal & reverse video attributes
;emulst	ends
;;;;;;;;;;;;;;;;  end references ;;;;;;;;;;;;;;;;;;;;

data	segment
	extrn	vtemu:byte, scbattr:byte, flags:byte, yflags:byte
	extrn	crt_lins:byte, rxtable:byte, denyflg:word, low_rgt:word
	extrn	vtclear:byte, dosnum:word, apcenable:byte, trans:byte
	extrn	parstate:word, pardone:word, parfail:word, nparam:word
	extrn	param:word, lparam:byte, ninter:word, inter:byte, ttyact:byte
	extrn	L1cp437:byte, L1cp850:byte, L1cp860:byte, L1cp863:byte
	extrn	L1cp865:byte, L5cp866:byte, modbuf:byte, extattr:byte
	extrn	rdbuf:byte
	extrn	vtenqenable:byte, vtcpage:word, prnhand:word,reset_color:byte
	extrn	vtclrflg:byte, enqbuf:byte, crdisp_mode:byte
	extrn	isps55:byte		; [HF]940130 Japanese PS/55 mode
	extrn	ps55mod:byte		; [HF]940206 PS/55 modeline status
ifndef	no_graphics
	extern	softptr:word, chcontrol:byte
endif	; no_graphics

	even					; C0 7-bit control code table
ansc0	dw	5 dup (atign)			; NUL, SOH, STX, ETX, EOT
	dw	atenq,atign,vtbell,atbs,atht 	; ENQ, ACK, BEL, BS,  HT
	dw	atlf, atlf, atff, atcr,atls1	; LF,  VT,  FF,  CR,  SO
	dw	atls0, 4 dup (atign)		; SI,  DLE, DC1, DC2, DC3
	dw	4 dup (atign), atcan		; DC4, NAK, SYN, ETB, CAN
	dw	atign, atnrm, atesc,atign,atign	; EM,  SUB, ESC, FS,  GS
	dw	2 dup (atign)			; RS,  US

						; C1 8-bit control code table
ansc1	dw	4 dup (atign), atind		; ignore 4, IND
	dw	atnel,atign,atign,athts,atign	; NEL, SSA, ESA, HTS, HTJ
	dw	atign,atign,atign,atri, atss2	; VTS, PLD, PLU, RI,  SS2
	dw	atss3,atdcs,3 dup (atign)	; SS3, DCS, PU1, PU2, STS
	dw	atign,atign,protena,protdis,atign ; CCH, MW, SPA, EPA,ignore
	dw	atign,atign,atcsi,atgotst,atdcsnul; ignore 2, CSI, ST, OSC
	dw	atdcsnul, atapc			; PM,  APC

; Heath-19 mode escape follower table
h19esc	db	36			; number of entries
	dw	h19ejt			; address of action routines
	db	'<=>@A','BCDEF','GHIJK','LMNOY','Z[bjk','lnopq','rvwxy','z'

; Dispatch table for Heath-19 escape sequence table h19esc
	even
h19ejt	dw	h19sans, atkpam,  atkpnm,  entins,  atcuu	; '<=>@A'
	dw	atcud,   atcuf,   atcub,   h19clrs, v52sgm	; 'BCDEF'
	dw	chrdef,  atcup,   atri0,   ated,    atel	; 'GHIJK'
	dw	inslin,  dellin,  atdelc,  noins,   v52pos	; 'LMNOY'
	dw	decid,   h19csi,  h19esos, h19sc,   h19rc	; 'Z[bjk'
	dw	h19erl,  hrcup,   h19ero,  h19herv, h19hxrv	; 'lnopq'
	dw	atnorm,  h19wrap, h19nowrp,h19smod, h19cmod	; 'rvwxy'
	dw	atxreset					; 'z'

h19ans	db	21			; Heath-19 ANSI style escape sequences
	dw	h19jmp			; address of action routine table
	db	'ABCDH','JKLMP','fhlmn','pqrsu','z'

; Heath-19 action table for h19ans
	even
h19jmp	dw	atcuu, atcud, atcuf,  atcub,  atcup		; 'ABCDH'
	dw	h19ed, atel,  inslin, dellin, atdelc		; 'JKLMP'
	dw	atcup, atsm,  atrm,   atsgr,  rpcup		; 'fhlmn'
	dw	atign, atign, atign,  h19sc,  h19rc		; 'pqrsu'
	dw	atxreset					; 'z'

; VT52 compatibility mode escape follower table
v52esc	db	23			; number of entries
	dw	v52ejt			; address of action routines
	db	'78<=>', 'ABCDF', 'GHIJK', 'VWXYZ'
	db	']',5eh,5fh		; 5eh = caret, 5fh = underscore

; Dispatch for v52esc table
	even
v52ejt	dw	atsc,   atrc,   v52ans, atkpam, atkpnm		; '78<=>'
	dw	atcuu,  atcud,  atcuf,  atcub,  v52sgm		; 'ABCDF'
	dw	chrdef, atcup,  atri0,  ated,   atel		; 'GHIJK'
	dw	v52pl,  v52pcb, v52pce, v52pos, decid		; 'VWXYZ'
	dw	v52ps,  v52pcb, v52pce				; ']^_'

; Prime PT200 escape follower table
pt200esc db	38			; number of entries
	dw	p20ejt			; address of action routines
	db	'01234','5678<', '=>?AB', 'DEFGH', 'JMNOP'
	db	'Z[\]',5eh		; 5eh = caret
	db	5fh,'cno',7bh		; 5fh=underscore, 7bh=left curly brace
	db	7ch,7dh,7eh   ; 7ch=vert bar, 7dh=right curly brace, 7eh=tilde

; Dispatch for p20esc
	even
p20ejt	dw	atdgf0, atdgf1, atdgf0, atsdhl, atsdhl	 	; '01234'
	dw	4 dup (atsdhl), atdgfu				; '5678<'
	dw	atkpam, atnorm, p20ed, atdgfA, atdgfB	 	; '=>?AB'
	dw	atind,  atnel,  ats7c, ats8c,  athts		; 'DEFGH'
	dw	ated,   atri,   atss2, atss3,  atdcs		; 'JMNOP'
	dw	decid,  atcsi,  atgotst, 2 dup(atdcsnul)	; 'Z[\]^'
	dw	atdcsnul, atxreset,atls2, atls3, atpriv		; '_cno{'
	dw	atls3r, atls2r, atls1r				; '|}~'

; VT320/VT102/VT100/Honewell ANSI mode escape follower table
ansesc	db	52			; number of entries
	dw	ansejt			; address of action routines
	db	'01234','56789','<=>?@'
	db	'ABCDE','FGHIJ','KLMN','OPQRV'
	db	'WYZ[\',']',5eh,5fh	; 5eh = caret, 5fh=underscore
	db	60h,'c','fgno',7bh	; 7bh=left curly brace,  7ch=vert bar
	db	7ch,7dh,7eh		; 7dh=right curly brace, 7eh=tilde

; Dispatch for ansesc table
	even
ansejt	dw	atdgf0, atdgf1, atdgf0, atsdhl, atsdhl	 	; '01234'
	dw	4 dup (atsdhl), atdgnrc				; '56789'
	dw	atdgfu,atkpam, atdgft, atdgfq, atdgfB		; '<=>?@'
	dw	atdgfA,atdgfB, atdgnrc, atind0, atnel0	 	; 'ABCDE'
	dw	ats7c, ats8c, athts0, atdgfI, atdgfJ		; 'FGHIJ'
	dw	atdgnrc,atdgnrc,atri0, atss2			; 'KLMN'
	dw	atss3, atdcs0, atdgnrc, atdgnrc, dgpton		; 'OPQRV'
	dw	dgptoff, decid, atdgnrc, atcsi0, atgotst0	; 'WYZ[\'
	dw	2 dup (atdcsnul0),atapc, athoncls, atxreset	; ']^_`c'
	dw	atdgnrc,atdgnrc,atls2,atls3, atpriv		; 'fgno{'
	dw	atls3r, atls2r, atls1r				; '|}~'

; Final char table for VT320/VT102/VT100/Honeywell ANSI control sequences
anstab	db	40			; number of entries
	dw	ansjmp			; address of action routines
	db	'@ABCD','EFGHI','JKLMP', 'Xacde','fghil','mnpqr','uwxyz'
	db	7ch,7dh,7eh		; 7dh=right curly brace, 7eh=tilde
	db	'su'

; Dispatch for anstab table
	even
ansjmp	dw	ansich, atcuu,  atcud,  atcuf,  atcub		; '@ABCD'
	dw	atcnl,  atcpl,  atcha,  atcup,  atcht		; 'EFGHI'
	dw	ated,   atel,   inslin, dellin, atdelc		; 'JKLMP'
	dw	atech,  atcuf,  atda,   atcva,	atcud  		; 'Xacde'
	dw	atcup,  attbc,  atsm,   ansprt, atrm		; 'fghil'
	dw	atsgr,  atdsr,  decscl, decsca, atstbm		; 'mnpqr'
	dw	atrqtsr,atrqpsr,atreqt, atctst, atxreset	; 'uwxyz'
	dw	atscpp, atsasd, atssdt				; '|}~'
	dw	atsc						; 's'

; Final character table for Device Control Strings (DCS, ESC P)
dcstab	db	5			; number of entries
	dw	dcsjmp			; address of action routines
	db	'pqu',7bh,7ch		; 7bh = left curly brace

; Dispatch for dcstab table
	even
dcsjmp	dw	atcrqq, atcrq, atupss, atdcsnul, atudk		; 'pqu{|'
;;; DCS Ps $ p string ST   page 209 restore color palette

; Data General D463/D470 terminal section
dgescape equ	1eh				; DG escape char (RS)

	even				; DG C0 7-bit control code table
dgc0	dw	atign,dgprtfm,dgrevidoff,dgblkena,dgblkdis;NUL,SOH,STX,ETX,EOT
	dw	dgrwa,atign,vtbell,dgwinhome,atign  ; ENQ, ACK, BEL, BS,  HT
	dw	dglf, dgeol, dgewin, dgcr,dgblkon   ; LF,  VT,  FF,  CR,  SO
	dw	dgblkoff,dgwwa,dgprtwn,dgrollena,dgrolldis ;SI,DLE,DC1,DC2,DC3
	dw	dguson,dgusoff,dgrevidon,dgcuu,dgcuf ; DC4, NAK, SYN, ETB, CAN
	dw	dgcub, dgcud,atign,dgdimon,dgdimoff ; EM, SUB, ESC, FS, GS
	dw	dgesc, atign			    ; RS, US

; DG D463/D470 DG-escape (RS) follower table

dgesctab db	17			; number of entries
	dw	dgejt			; address of action routines
	db	'ABCDE','FGHIJ','KLMNO','PR'

; Dispatch for dgesctab table
	even
dgejt	dw	dgsfc, dgsbc, dgrmid, dgrevidon, dgrevidoff 	; 'ABCDE'
	dw	dgFSERIES, dgGSERIES, dgscrup, dgscrdn, dginsc	; 'FGHIJ'
	dw	dgdelc, dggline, atign, atls1, atls0		; 'KLMNO'
	dw	dgunix, dgRSERIES				; 'PR'

fltable	db	61				; RS F letter dispatch table
	dw	faction				; table of action routines
	db	'789;<', '>?ABC', 'DEFGH', 'IJKLM', 'NOPQR'
	db	'STUVW', 'XYZ[\', ']^_`a', 'bcdef', 'hikmq'
	db	'rstvw', 'xz{}~', '@'

; Dispatch for fltable table
	even
faction	dw	dgign2n, atign, dggrid, atign, atign		; '789;<'
	dw	dgalign, dgprt, atreset, dgsetw, dgsleft	; '>?ABC'
	dw	dgsright, dgescn, dgeeos, dgshome, dginsl	; 'DEFGH'
	dw	dgdell, dgnarrow, dgwide, dgpton, dgptoff	; 'IJKLM'
	dw	dgchatr, dgrhso, dgwsa, dgsct, dgdefch		; 'NOPQR'
	dw	dgscs, dgign1n, dg78bit, protena, protdis	; 'STUVW'
	dw	dgsetmar, dgsetamar, dgrnmar, dgilbm, dgdlbm	; 'XYZ[\'
	dw	dghsdis, dghsena, dgshcol, dgprt3a, atign	; ']^_`a'
	dw	dgrsa, dgscmap, dgrchr, dgresch, dgskl		; 'bcdef'
	dw	atign, atign, atnorm, atnorm, dgdchs 		; 'hikmq'
	dw	dgsclk, dgign1n, dgrss, dgrwc, dgrnmod		; 'rstvw'
	dw	dgppb, dgs25l, dgsmid, dgnscur, dgign2n		; 'xz{}~'
	dw	dgtoansi					; '@'

gltable	db	14				; RS G letter dispatch table
	dw	gaction				; table of action routines
	db	'018:>','?@ABC','HInp'

; Dispatch for gltable table
	even
gaction	dw	dggarc, dggbar, dggline, dggpoly, dggcloc	; '018:>'
	dw	dggrcl, dggcatt, dggcrst, dggcon, dggcoff	; '?@ABC'
	dw	dggctrk, atnorm, atnorm, dggsetp		; 'HInp'

rltable	db	6			; Data General D463/D470 RS R series
	dw	raction
	db	'@ABCD','E'

; Dispatch for rltable table
raction	dw	dgign2n, dgsps, dgsfield, dgspage, dgsdo	; '@ABCD'
	dw	dgdhdw						; 'E'

dgescftab db	34			; DG ESC.. Final escape follower tab
	dw	dgescfjmp		; address of action routines
	db	'01234','56789',':;<=>','?ABHI','JKL'
	db	'cDEMN','OPVW[','\'

dgescfjmp dw	23 dup (dgesc_ch)      ; '01234','56789',':;<=>','?ABHI','JKL'
	dw	dgesc_c,dgesc_D,dgesc_E,dgesc_M,atss2	; 'cDEMN'
	dw	atss3,atdcs0,dgesc_V,dgesc_W,atcsi0	; 'OPVW['
	dw	atgotst0				; '\'

dganstab db	28			; DG CSI .. Final  char dsptch
	dw	dgcjmp			; address of action routines
	db	'@ABCD','HJKLM','PSTfh','ilmnp','qrstu','vwx'

					; DG ANSI dispatch table
dgcjmp	dw	dgcsi_@,dgcsi_A,dgcsi_B,dgcsi_C,dgcsi_D	; '@ABCD'
	dw	dgcsi_f,ated,  atel,   dgcsi_L,dgcsi_M	; 'HJKLM'
	dw	atdelc,dgcsi_S,dgcsi_T,dgcsi_f,dgcsi_h	; 'PSTfh'
	dw	dgcsi_i,dgcsi_sl,atsgr,dgcsi_n,dgcsi_sp	; 'ilmnp'
	dw	dgcsi_q,dgcsi_r,dgcsi_ss,dgcsi_st,dgcsi_u ; 'qrstu'
	dw	dgcsi_v,dgcsi_w,dgcsi_x			; 'uwx'

dgdcstab db	6			; DG DCS dispatch table
	dw	dgdcsjmp
	db	'ABCDE','F'

dgdcsjmp dw	dgdefch,dggline,dggset2,dgsetw,dggpoly		; 'ABCDE'
	dw	dgdcs_F						; 'F'

				; Wyse-50 control codes
	even					; C0 7-bit control code table
wyc0	dw	5 dup (atign)			; NUL, SOH, STX, ETX, EOT
	dw	atenq,atign,vtbell,wycub,atht 	; ENQ, ACK, BEL, BS,  HT
	dw	atlf, wycup, dgcuf, atcr,atign	; LF,  VT,  FF,  CR,  SO
	dw	atign, atign, atign, wyprton, atign ; SI,  DLE, DC1, DC2, DC3
	dw	wyprtoff,3 dup (atign), wy_d2	; DC4, NAK, SYN, ETB, CAN
	dw	atign, wysub, wyesc,atign,atign	; EM,  SUB, ESC, FS,  GS
	dw	wyhome, atlf1			; RS,  US

				; Wyse-50 escape dispatch table
wyescf	db	50
	dw	wyejt				; table of action routines
	db	' !&',27h,'(',')*+,-','./012','89:;=','?ADEF'
	db	'GHIMN','OQRTV','WY`ab','dijqr','txyz{'

wyejt	dw	wyenq,wy_bang,protena,protdis,clrprot	; ' !&'('
	dw	setprot,wy_star,wy_star,wy_comma,wy_minus ; ')*+,-'
	dw	wy_dot,wy_slash,wytab0,athts,wytab2	; './012'
	dw	wy_8,wy_9,wysub,wysub,wy_equ		; '89:;='
	dw	wy_query,wy_A,atnorm,inslin,wy_F	; '?ADEF'
	dw	wy_G,wy_H,wy_I,wy_M,wy_N		; 'GHIMN'
	dw	wy_O,ansich,wy_R,atel0,wy_V		; 'OQRTV'
	dw	atdelc,ereos,wy_acc,wy_sa,wy_b		; 'WY`ab'
	dw	wy_d,atht,atri,wy_q,wy_sr		; 'dijqr'
	dw	atel0,wy_x,ereos,wy_z,wyhome		; 'txyz{'

;; Notes on char set idents
; Kermit ident	 	size	ident	comment			designator
;	0		94	'B',0	ASCII	 		"B"
;	1		94	'A',0	British NRC 		"A"
;	2		94	'4',0	Dutch NRC 		"4"
;	3		94	'5',0	Finnish	NRC (also "C")	"5"
;	4		94	'R',0	French NRC (also "f")	"R"
;	5		94	'9',0	French Canadian NRC 	"9"
;	6		94	'K',0	German NRC		"K"
;	7		94	'Y',0	Italian	NRC		"Y"
;	8		94	'`',0	Norwegian/Danish NRC	"`"
;	9		94	'%','6'	Portugese NRC ("L","g") "%6"
;	10		94	'Z',0	Spanish	NRC		"Z"
;	11		94	'7',0	Swedish	NRC		"7"
;	12		94	'=',0	Swiss NRC		"="
;	13		94	'=','%' DEC Hebrew NRC		"=%'
;	14		94	'1',0	Alt-ROM			"1"
;	15		96	'?',0	Transparent		"?"
;	16		96	'A',0	Latin1			"A"
;	17		94	'%','5'	DEC Multinat (Sup Gr) 	"%5"
;	18		94	'>',0	DEC Technical		">"
;	19		94	'0',0	DEC-Special  		"0","2"
;	20		94	'D','I' DG International	"DI"
; 	21		94	'D','L'	DG Line Drawing		"DL"
;	22		94	'D','W' DG Word Processing	"DW"
;	23		96	'B',0   Latin2			"B"
;	24		96	'H',0   Hebrew-ISO		"H"
;	25		94	'"','4' DEC Hebrew		""4"
;	26		94	'YW'	Wyse-50 graphics	"YW"
;	27		96	'H','P'	HP-Roman8		"HP"
;	28		96	'CI'  ISO 8859-5 Latin/Cyrillic "CI"
;	29		96	'CK'  KOI8-Cyrillic		"CK"
;	30		96	'CS'  Short-KOI Cyrillic	"CS"
;      100 - 131	94	'D','U' DG soft sets		"DU"
;      141 (128+13)	94	'I' JIS-Katanaka (JIS X 201)	"I"
;      142 (128+14)	94	'J' JIS-Roman (JIS X 201)	"J"
;      215 (128+87)	94	'B','$' JIS-Kanji (JIS X 208)	"B$"
;; End of notes

; Heath-19 special graphics characters to CP437. Use as offsets from caret
; (94D)
hgrtab	db	249, 17,179,196,197	; caret,underscore,accent grave,a,b
	db	191,217,192,218,241	; c,d,e,f,g
	db	 26,177,219, 25,220	; h,i,j,k,l
	db	220,223,223,223,222	; m,n,o,p,q
	db	 16,194,180,193,195	; r,s,t,u,v
	db	'X','/','\',223,220	; w,x,y,z,left curly brace
	db	221,222, 20		; vertical bar,right curly brace,tilde
hgrtabl	equ ($-hgrtab)

; Data General Line Drawing Character Set, based on CP437, starting in 10/0
dgldc	db	20h,0dah,0bfh,0c0h,0d9h,0c2h,0b4h,0c3h		; 2/0
	db	0c1h,0c5h,0b3h,0c4h,0c2h,0b4h,0c3h,0c1h
	db	0b3h,0c9h,0bbh,0c8h,0bch,0cbh,0b9h,0cch		; 3/0
	db	0cah,0ceh,0bah,0cdh,0c4h,0f6h,9bh,3fh
	db	3fh,3fh,3fh					; 4/0
dgldclen equ	($-dgldc)

; VT320/VT102 "Special graphics" set translation table for characters 95..126d
; when the special graphics set is selected. Some characters (98, 99, 100,
; 101, 104, 105, 111, 112, 114, 115, and 116) do not have exact equivalents
; in the available set on the IBM, so a close substitution is made.
; Table is indexed by ASCII char value minus 95 for chars 95..126d.
sgrtab	db	 32,  4,177, 26, 23,  27, 25,248,241, 21
	db	 18,217,191,218,192, 197,196,196,196,196
	db	196,195,180,193,194, 179,243,242,227,157
	db	156,250
sgrtabl	equ	$-sgrtab


	; DEC National Replacement Char sets, referenced to Latin1
nrclat	db	23h,40h,5bh,5ch,5dh,5eh		; 0, ASCII, "B", dispatch ref
	db	5fh,60h,7bh,7ch,7dh,7eh
	db	94,'B',0			; 94 byte set, letter pair
	db	0a3h,40h,5bh,5ch,5dh,5eh	; 1, British, "A"
	db	5fh,60h,7bh,7ch,7dh,7eh
	db	94,'A',0
	db	0a3h,0beh,0ffh,0bdh,7ch,5eh	; 2, Dutch, "4"
	db	5fh,60h,0a8h,66h,0bch,0b4h
	db	94,'4',0
	db	23h,40h,0c4h,0d6h,0c5h,0dch	; 3, Finnish, "5"
	db	5fh,0e9h,0e4h,0f6h,0e5h,0fch
	db	94,'5',0
	db	0a3h,0e0h,0b0h,0e7h,0a7h,5eh	; 4, French, "R"
	db	5fh,60h,0e9h,0f9h,0e8h,0fbh
	db	94,'R',0
	db	23h,0e0h,0e2h,0e7h,0eah,0eeh	; 5, French Canadian, "9"
	db	5fh,0f4h,0e9h,0f9h,0e8h,0f8h
	db	94,'9',0
	db	23h,0a7h,0c4h,0d6h,0dch,5eh	; 6, German, "K"
	db	5fh,60h,0e4h,0f6h,0fch,0dfh
	db	94,'K',0
	db	0a3h,0a7h,0b0h,0e7h,0e9h,5eh	; 7, Italian, "Y"
	db	5fh,97h,0e0h,0f2h,0e8h,0ech
	db	94,'Y',0
	db	23h,40h,0c6h,0d8h,0c5h,5eh	; 8, Norwegian/Danish, "`"
	db	5fh,60h,0e6h,0f8h,0e5h,7eh
	db	94,60h,0
	db	23h,40h,0c4h,0c7h,0d6h,5eh	; 9, Portugese, "%6"
	db	5fh,60h,0e4h,0e7h,0f6h,7eh
	db	94,'%','6'
	db	0a3h,0a7h,0a1h,0d1h,0bfh,5eh	; 10, Spanish, "Z"
	db	5fh,60h,0b0h,0f1h,0e7h,7eh
	db	94,'Z',0
	db	23h,0c9h,0c4h,0d6h,0c5h,0dch	; 11, Swedish, "7"
	db	5fh,0e9h,0e4h,0f6h,0e5h,0fch
	db	94,'7',0
	db	0f9h,0e0h,0e9h,0e7h,0eah,0eeh	; 12, Swiss, "="
	db	0e8h,0f4h,0e4h,0f6h,0fch,0fbh
	db	94,'=',0

nrcfinal db	'A45CRf9QKY`E6Z7H=Lg'		; NRC country letters
nrcflen	equ	$-nrcfinal			; "%6" "%=" done separately
nrcnum	db	1,2,3,3,4,4,5,5,6,7,8,8,8,10,11,11,12,9,9 
						; country numbers matching
						; nrcfinal letters

;NRC to DEC keyboard codes, North American (ASCII is nrckbd 1),+ALT-ROM+transp
nrckbd	db	1,2,8,6,14,4,7,9,13,16,15,12,11,1, 1,1,1,1,1,1,1
;NRC to DG keyboard codes, North American + ALT-ROM+transparent
nrcdgkbd db	19h,1ah,0,1dh,1bh,18h,1ch,17h,1fh,0,1eh,1dh,14h,19h, 19h,18h
	db	19h,19h,19h,19h,19h
; DG char set idents to Kermit set idents
; DG set values 0 1 2 3 4  5  6	7     8   9  0a  0b  0c  0d 0e  0f  hex
dgchtab	db	0,0,1,4,6,11,10,8,   12,100,100,100,100,100,20,100 ; decimal
;		10 11  12 13 14 15  16   17  18  19  1a  1b  1c 1d 1e 1f
	db	22,21,100,15,17,19,100, 100,100,100,100,100,100, 0,15,16
;		20h and above map to soft set filler 100
	db	100						; filler set

d470chr	db	'12345','6ABHK','L'		; D470 ANSI char idents
d470chrlen equ	($-d470chr)
mskchr	db	10,8,12,20,22, 21,1,0,3,6, 4	; Kermit char idents

; Device attributes response string. Make strings asciiz.
v32str	db	escape,'[?63;1;2;4;6;8;9;15;22c',0 ; VT320, level 3, 132 col, 
;printer, selective chars, Sixel graphics, UDkeys, NRC, DEC Tech Chars, color
v32sda	db	escape,'[>24;0;0c',0	; VT320 secondary DA response
v22str	db	escape,'[?62;1;2;4;6;8;9;15c',0; VT220, level 2, etc as above
v102str	db	escape,'[?6;0c',0	; VT102
v100str db	escape,'[?1;0c',0	; vanilla VT100
v52str	db	escape,'/Z',0		; VT100 in VT52 compatibility mode
h19str	db	escape,'/K',0		; Heath-19 (says plain VT52)
VIPstr	db	escape,'[8p  OT',03h,escape,'[y7813  P GC  A ',03h,0
VIPstrl	equ	$-VIPstr		; Honeywell MOD400 3.1 id for ESC [ y
ENQhstr	db	'7813  P GC  A',03h	; Honeywell MOD400 4.0 id string
ENQhstrl equ	$-ENQhstr
pt20str	db	escape,'! ~0 ~..6~C~2 ~$',0 ; Prime PT200
ENQstr	db	'MS-DOS-KERMIT'		; generic enquiry response
ENQstrl	equ	$-ENQstr
					; parity code translation table
partab	db	5,3,1,4,2		; even, mark, none, odd, space
lpartab equ	$-partab
parcode db	0			; parity code (0-4)
					; baud rate code translation table
; 45.5 - no VT100 code (call it 50),50,75,110,134.5,150,300,600,1200,
; 1800,2000,2400,4800,9600,19200,38400,57600,115200  extended beyond DEC
baudtab db	0,0,8,16,24,32,48,56,64,72,80,88,104,112,120,128,128,128,64,8
lbaudtab equ	$-baudtab-1	; last two are 1200/75 for split speeds
baudidx db	0			; index into baud rate table
datbits db	7			; number of databits (7 or 8)
wyse_grch db	0c2h,0c0h,0dah,0bfh,0c3h,0d9h,0b3h,0b2h ; Wyse-50 graphics
	db	0c5h,0b4h,0c4h,0b1h,0cdh,0c1h,0bah,0b0h	; chars (0..15) CP437

issoft	db	0			; 0=hard char set, else soft
apcstring dw	0			; segment of apcmacro memory

;;;;;;;;;;;;;;; start session save area
	even
savezoff label	word
ttstate dw	offset atnrm		; terminal automata state
ttstateST dw	offset atnorm		; state for action after ST seen
bracecount db	0			; count of curly braces in APC string
att_normal db	07H			; default normal screen coloring
oldterm	dw	0			; terminal type from previous entry
tekflg	db	0			; Tek mode active flag
old8bit	db	-1			; flags.remflg setting for D463/D470
iniflgs	dw	0			; status flags at entry time
modeset db	0			; temp for atsm/atrm
anspflg	db	0			; printer flag bits and definitions
h19stat	db	0			; H-19 extra status bits
h19ctyp	db	1			; H-19 cursor type (1=ul, 2=bk, 4=off)
h19cur	dw	0			; H-19 saved cursor position
insmod	db	0			; insert mode on (1) or off (0)
belcol	db	72			; column at which to ring margin bell
kbicsr	dw	0			; cursor when keyboard input typed
kbiflg	db	0			; set/reset for keyboard input
ttkbi	db	0			; flag for keyboard input seen
atescftab dw	ansesc			; offset of esc follower table
setptr	dw	0			; hold offset of designated char set
upss	db	96,'A',0,0		; User Preferred Supplemental Set
					; size, ident (Latin1)
; tab stops, stored here
tabs	db	(swidth+7)/8 dup (0)	; active tab stops, one column per bit
deftabs	db	(swidth+7)/8 dup (0)	; default (setup) tab stops
; byte per line, type of line: 0=normal, 1=double wide, 2=double high
linetype db	slen dup (0)		; single/double width chars for a line
linescroll db	slen dup (0)		; horizontal scroll for each line
oldscrn	dw	0			; old screen. hi=rows-1, low=cols-1

; Scrolling region - do not separate or change order of mar_top & mar_bot
mar_top db	0			; scrolling region top margin
mar_bot db	23			; scrolling region bottom margin
mar_left db	0			; left margin
mar_right db	vswidth-1		; right margin
savdgmar dw	0			; DG saved right/left margins
dspstate db	0			; display state (mode)line work byte
dspmsave dw	0			; saved main dsp scrolling margins
dspcstat dw	0			; saved cursor pos for status line
dspcmain dw	0			; saved cursor pos for main display
G0set	db	gsize+3+1 dup (0),0	; G0..G3 char set space
G1set	db	gsize+3+1 dup (0),1	; last byte is permanent set index
G2set	db	gsize+3+1 dup (0),2	;  and should never be changed
G3set	db	gsize+3+1 dup (0),3
xltkeytable db	gsize dup (0)		; keyboard translation table
doublebyte db	0			; [HF] 93/Nov/26 storage for dbl.char.
double2nd db	0			; [HF]
					; Start of save cursor material
savelist equ	this byte		; top of list of things to save
havesaved db	0			; if have saved anything
cursor	dw	0			; cursor position
savextattr db	0			; extended display attributes
curattr db	07h			; cursor attribute
svattr_index	equ $-savelist		; offset of saved cursor attribute
savscbattr db	1			; normal background attributes
atctype	db	1			; VTxxx cursor type (1=ul,2=bk,0/4=off)
savflgs dw	0			; saved flags for atsc/atrc
atwrap	db	0			; autowrap flag
atinvisible db	0			; invisible char attribute flag
decrlm	db	0			; host controlled right-left writing
GLptr	dw	0			; pointer to char set for GL
GRptr	dw	0			; pointer to char set for GR
SSptr	dw	0			; pointer to char set for single shift
Gsetid	db	4 dup (0)		; set numbers 0..24 of char set
lsavecu equ	$-savelist		; length of stuff to save
savecu	db	lsavecu dup (0)		; saved cursor, attr., charset, etc
					; End of save cursor material
	even				; Control sequence storage area
ansifinptr dw	anstab			; pointer to ANSI final char dispatch
dcstabptr dw	dcstab			; pointer to DCS dispatch table
dnparam	dw	0			; number of parameters for DCS
dparam	dw	maxparam dup (0)	; Parameters for DCS
dlparam	db	0			; a single letter Parameter for DCS
dninter	dw	0			; number of DCS intermediates
dinter	db	maxinter dup (0)	; Intermediates for DCS
dcsstrf	db	0			; Final char of DCS
dnldcnt dw	0			; autodownload, chars in emubuf
emubufc	dw	0			; count of chars in string buffer
emubuf	db	66 dup (0)		; emulator string storage buffer
	db	0			; safety for string overflow
emubufl	dw	$-emubuf		; length of emulator buffer
pktbuf	db	66 dup (0)		; Kermit packet recognizer buffer
	db	0
pktbufl	dw	$-pktbuf
pktlen	db	0			; autodownload, declared packet LEN
pkttype db	0			; autodownload, packet TYPE
pktchk	db	0			; autodownload, running pkt chksum
dgparmread dw	0			; DG count of parameters read
					; DG windows structure
dgwindcnt dw	1			; DG count of active windows
dgwindow dw	slen dup (0)		; DG window [mar_top,mar_bot]
dgwindcomp db	slen dup (0)		; DG window compress (0=80,1=132 cols,
					;  2 = line has soft font chars)
dgcaller dw	atnorm			; DG hex proc callback address
numdigits db	0			; DG hex digits remaining to be done
dgnum	dw	0			; DG numerical result
protectena db	0			; DG protected mode enabled (if != 0)
blinkdis db	0			; DG blink disabled
dgroll	db	1			; DG roll (0=disabled, 1=enabled)
dghscrdis db	0			; DG horz scroll disabled (if 1)
dgcursave dw	16 dup (0)		; DG cursor position named save area
dgctypesave db	16 dup (0)		; DG cursor type named save area
dgcross	db	0			; DG crosshair activity: 0=off, 1=on
					;   2 = track keypad, 4= track mouse
dg463fore db	0			; DG D463 Polygon fill foregnd color
dgaltid	dw	0			; DG alt term id from host (0=none)
dgkbl	db	0			; DG keyboard language
dgd470mode db	0			; DG nonzero if D470 in ANSI mode
dglinepat dw	0ffffh			; DG line drawing pattern
thisline db	0			; linetype for current line
scroll	db	1			; lines to scroll, temp worker
wyse_scroll db	0			; Wyse-50 scroll/noscroll mode flag
wyse_protattr dw 0			; Wyse-50 protected char attributes
					;  high byte=extattr, low=scbattr
savezlen dw	($-savezoff)		; length of z save area
;;;;;;;;;;;;;;;;; end of session save area

;note low_rgt	dw	0		; text screen dimensions
					; byte low_rgt = max column (79)
					; byte low_rgt+1 = max row (23)
led_col	equ	65			; column position for "LEDs" display
led_off equ	'.'			; "Off" LED
v320leds db	'VT320 ....'		; VT320 mode (all 10 characters)
v220leds db	'VT220 ....'		; VT220 mode
v102leds db	'VT102 ....'		; VT102 mode
v100leds db	'VT100 ....'		; VT100 mode
v52leds	db	'VT52      '		; VT52 mode
h19leds	db	'Heath-19  '		; Heath-19 mode
honeyleds db	'Honey ....'		; Honeywell VIP 7809
ansileds db	'ANSI  ....'		; ANSI-BBS
pt20leds db	'PT200 ....'		; Prime PT200
d470leds db	'D470      '		; D470 series from Data General
d470model db	'D470'			; D470 response for Read New Model ID
d463leds db	'D463      '		; D463 series from Data General
d463model db	'D463'			; D463 response for Read New Model ID
d217leds db	'D217      '		; D217 series from Data General
d217model db	'D217'			; D217 response for Read New Model ID
;;d413model db	'D413'			; D413 response for Read New Model ID
wyseleds db	'Wyse-50   '		; Wyse-50 mode
data	ends

data1	segment
	extrn lccp866r:byte, k8cp866r:byte, k7cp866r:byte
	extrn cp866koi7:byte, cp866koi8:byte, cp866lci:byte

; Translation tables for byte codes 0a0h..0ffh to map DEC Multinational
; Character Set (DEC Supplemental Graphic) to Code Pages.
; Codes 00h-1fh are 7-bit controls (C0), codes 20h..7eh are ASCII, 7fh DEL is
; considered to be a control code, 80h..9fh are 8-bit controls (C1).
; Each table is 128 translatable bytes followed by the table size (94) and the
; ISO announcer ident '%5'.

MNlatin	db	0a4h,0a6h,0ach,0adh,0aeh,0afh,0b4h	; Latin1 code points
	db	0beh,0d0h,0deh,0f0h,0feh,0ffh		; to MNlatin spaces


		   	; Dec Technical set to CP437, CP860, CP863, CP865
 			; Note: CP850 lacks the symbols so expect trash
dectech	db	32 dup (0)				; columns 8 and 9
	db	0h,0fbh,0dah,0c4h, 0f4h,0f5h,0b3h,0dah	; column 10
	db	0c0h,0bfh,0d9h,28h,28h,29h,29h,0b4h
	db	0c3h,3ch,3eh,5ch,  2fh,0bfh,0d9h,03eh	; column 11
	db	0a8h,20h,20h,20h,  0f3h,3dh,0f2h,3fh
	db	1eh,0ech,0ech,0f6h,1eh,1fh,0e8h,0e2h	; column 12
	db	0f7h,0f7h,0e9h,58h,3fh,1dh,1ah,0f0h
	db	0e3h,3fh,20h,0e4h, 20h,20h,0fbh,0eah	; column 13
	db	3fh,54h,3fh,3fh,   0efh,55h,5eh,76h
	db	0aah,0e0h,0e1h,78h,0ebh,0eeh,0edh,3fh	; column 14 
	db	6eh,69h,0e9h,6bh,  3fh,20h,76h,3fh
	db	0e3h,3fh,70h,0e5h, 0e7h,0a8h,9fh,77h	; column 15
	db	45h,76h,3fh,1bh,   18h,1ah,19h,7fh
	db	94,3eh,0			; 94 byte set, letter ident

				; Data General Word Processing to CP 437
dgwpcp437 db	20h,0dah,0c0h,0bfh, 0d9h,9fh,'~',8h	; column 10
	db	0e4h,0e4h,0f4h,0f5h, 0fbh,8h,0ech,8h
	db	'0','1',0fdh,'3', '4','5','6','7'	; column 11
	db	'8','9',8h,0c9h, 1bh,8h,1ah,0fah
	db	13h,0e0h,0e1h,8h, 0ebh,8h,8h,0fch	; column 12
	db	0e9h,8h,8h,8h, 0e6h,8h,0eeh,8h
	db	8h,8h,0e5h,0e7h, 8h,0edh,8h,8h		; column 13
	db	8h,0eah,1eh,14h, 4 dup (8h)
	db	0c3h,04h,010h,010h, 011h,1eh,1fh,9 dup (8h) ; column 14
	db	'0','1','2','3', '4','5','6','7'	; column 15
	db	'8','9',3fh,18h, 1ah,1bh,19h,20h
	db	94,'D','W'			; 94 byte set, letter idents
dgwplen	equ	$-dgwpcp437			; table size

			; Convert Data General International to Latin1.
			; DGI chars at these code points translate to the
			; value used as a code point in the Latin1 table.
			; Thus the second byte, 0ach, DGI not sign, in its
			; row 2 col 10 translates to Latin1 not sign in row 12
			; col 10. Columns 8 and 9 are C1 controls.
dgi2lat	db	0a0h,0ach,0bdh,0b5h, 0b2h,0b3h,0a4h,0a2h ; column 10
	db	0a3h,0aah,0bah,0a1h, 0bfh,0a9h,0aeh,3fh
	db	0bbh,0abh,0b6h,3fh,  3fh,0a5h,0b1h,3fh	 ; column 11
	db	3fh,0b7h,60h,0a7h,   0b0h,0a8h,0b4h,3fh
	db	0c1h,0c0h,0c2h,0c4h, 0c3h,0c5h,0c6h,0c7h ; column 12
	db	0c9h,0c8h,0cah,0cbh, 0cdh,0cch,0ceh,0cfh
	db	0d1h,0d3h,0d2h,0d4h, 0d6h,0d5h,0d8h,3fh	 ; column 13
	db	0dah,0d9h,0dbh,0dch, 0a0h,59h,0a0h,0a0h
	db	0e1h,0e0h,0e2h,0e4h, 0e3h,0e5h,0e6h,0e7h ; column 14
	db	0e9h,0e8h,0eah,0ebh, 0edh,0ech,0eeh,0efh
	db	0f1h,0f3h,0f2h,0f4h, 0f6h,0f5h,0f8h,3fh	 ; column 15
	db	0fah,0f9h,0fbh,0fch, 0dfh,0ffh,0a0h,0a0h
dgi2len	equ	$-dgi2lat

; yr8l1[]   /* Hewlett Packard Roman8 to Latin-1 */
;/* This is HP's official translation, straight from iconv */
;/* It is NOT invertible. */ omits columns 0..9
hr8L1	db 160,192,194,200,202,203,206,207,180, 96, 94,168,126,217,219,163
	db 175,221,253,176,199,231,209,241,161,191,164,163,165,167,102,162
	db 226,234,244,251,225,233,243,250,224,232,242,249,228,235,246,252
	db 197,238,216,198,229,237,248,230,196,236,214,220,201,239,223,212
	db 193,195,227,208,240,205,204,211,210,213,245, 83,115,218, 89,255
	db 222,254,183,181,182,190, 45,188,189,170,186,171, 42,187,177,160
hr8L1len equ $-hr8L1

; yr8l1[]   /* HP Roman8 to ISO Latin-1, Invertible */ omits cols 0..9
ihr8L1	db 160,192,194,200,202,203,206,207,180,166,169,168,172,217,219,173
	db 175,221,253,176,199,231,209,241,161,191,164,163,165,167,174,162
	db 226,234,244,251,225,233,243,250,224,232,242,249,228,235,246,252
	db 197,238,216,198,229,237,248,230,196,236,214,220,201,239,223,212
	db 193,195,227,208,240,205,204,211,210,213,245,178,179,218,184,255
	db 222,254,183,181,182,190,185,188,189,170,186,171,215,187,177,247
ihr8L1len equ $-ihr8L1


data1	ends

ifndef	no_graphics
code2	segment
	extrn	tekini:far, tekemu:far, tekend:far, teksetcursor:far
	extrn	dgline:far, dgbar:far, dgcrosson:far, dgcrossoff:far
	extrn	dgcrossrpt:far, dgsetcrloc:far, dgarc:far, dgpoly:far
	extrn	mksoftspace:far, clearsoft:far
code2	ends
endif	; no_graphics

code	segment
	extrn	cptchr:near, pntchr:near, pntchk:near, pntflsh:near
	extrn	modlin:near, latin1:near
	extrn	clrmod:near, latininv:near, trnprs:near
	extrn	dgsettek:far, vtksmac:near, vtkrmac:near, product:near
	extrn	jpnftox:near, jpnxtof:near	; [HF] 93/Nov/26

	assume	ds:data, es:nothing

fmodlin	proc	far
	call	modlin
	ret
fmodlin	endp

fclrmod	proc	far
	call	clrmod
	ret
fclrmod	endp

fcptchr	proc	far
	call	cptchr
	ret
fcptchr	endp

fpntchr	proc	far
	call	pntchr
	ret
fpntchr	endp

fpntchk	proc	far
	call	pntchk
	ret
fpntchk	endp

fpntflsh proc	far
	call	pntflsh
	ret
fpntflsh endp

ftrnprs	proc	far
	call	trnprs
	ret
ftrnprs	endp

fvtksmac proc	far
	call	vtksmac
	ret
fvtksmac endp

fvtkrmac proc	far
	call	vtkrmac
	ret
fvtkrmac endp

fproduct proc	far
	call	product
	ret
fproduct endp

flatin1	proc	far
	push	ax
	push	es
	push	flags.chrset
	push	ds
	mov	ax,seg flags
	mov	ds,ax
	mov	ax,ds:vtcpage		; get current terminal Code Page
	mov	ds:flags.chrset,ax	; tell file transfer part
	pop	ds
	call	latin1			; sets DS:BX
	call	latininv		; adjusts BX
	mov	ax,seg flags
	mov	es,ax
	pop	es:flags.chrset
	pop	es
	pop	ax
	ret
flatin1	endp

fjpnxtof proc	far			; [HF] 93/Nov/26
	call	jpnxtof			; [HF] 93/Nov/26
	ret				; [HF] 93/Nov/26
fjpnxtof endp				; [HF] 93/Nov/26
code	ends

code1	segment
	extrn	prtbout:near, prtnout:near, csrtype:near, atsclr:near
	extrn	vtscru:near, vtscrd:near, chgdsp:near
	extrn	setpos:near, setudk:near, udkclear:near, vtbell:near
	extrn	setatch:near, qsetatch:near, getatch:near
	extrn	revideo:near, getbold:near, setbold:near, clrbold:near
	extrn	getblink:near, setblink:near, clrblink:near, getunder:near
	extrn	setunder:near, clrunder:near, revscn:near, setcolor:near
	extrn	setrev:near, clrrev:near, dec2di:far
	extrn	atparse:near, atpclr:near, atdispat:near, apcmacro:near
	extrn	setprot:near, clrprot:near, frepaint:far, touchup:near
	extrn	rcvmacro:near, srvmacro:near
ifndef	no_graphics
	extrn	tekinq:near, tekpal:near, tekrpal:near
endif	; no_graphics

	assume	cs:code1, ds:data, es:nothing

; Terminal display routine. Call with character incoming character in AL

anstty	proc	near
	mov	dx,cursor		; some routines need cursor in dx
	mov	kbiflg,0		; clear old flag value
	test	yflags,trnctl		; Debug mode?
	jz	anstt1			; z = no
	jmp	atdeb			; yes, just translate control chars
anstt1:	cmp	ttkbi,0			; new keyboard input?
	je	anstt2			; e = no, just continue
	mov	kbiflg,1		; yes, set flag
	mov	kbicsr,dx		; save old cursor
	mov	ttkbi,0			; clear this flag

anstt2:	test	anspflg,vtcntp		; print controller on?
	jz	anstt4			; z = no
	test	flags.capflg,logses	; capturing output?
	jz	anstt3			; z = no, forget this part
	push	ax			; save char
	call	fcptchr			; give it captured character
	pop	ax			; restore character
anstt3:	jmp	ttstate			; print transparently

anstt4:	test	yflags,capt		; capturing output?
	jz	anstt4a			; z = no, forget this part
	call	fcptchr			; give it captured character
anstt4a:or	al,al			; NUL char?
	jnz	anstt5			; nz = no
	test	flags.vtflg,ttd463+ttd470+ttd217 ; DG D463/D470/D217 mode?
	jnz	anstt5			; nz = yes, must pass nulls
	test	flags.vtflg,ttwyse	; Wyse?
	jz	atign			; z = no, ignore it

anstt5:	cmp	vtemu.vtdnld,0		; autodownload disabled?
	je	anstt8			; e = yes
	cmp	al,trans.rsoh		; start of packet char?
	jne	anstt5c			; ne = no
	push	ax
	call	anstt5x			; flush current buffer
	pop	ax
	mov	dnldcnt,1		; say recording new packet
	mov	pktbuf,al		; store char for replay
	mov	pktchk,0		; initialize checksum
	ret
anstt5c:cmp	dnldcnt,0		; parsing?
	je	anstt8			; e = no
	mov	bx,dnldcnt
	mov	pktbuf[bx],al
	inc	dnldcnt			; count incoming bytes
	inc	bx
	cmp	bx,pktbufl		; packet too long?
	jae	anstt5x			; ae = too much, fail
	add	pktchk,al		; add to running checksum
	cmp	al,trans.reol		; premature EOL?
	je	anstt5x			; e = yes, fail
	cmp	dnldcnt,2		; LEN byte?
	jne	anstt5d			; ne = no
	cmp	al,' '+3		; minimal length packet?
	jbe	anstt5x			; be = no, fail
	push	ax
	sub	al,' '			; remove length ASCII bias
	mov	pktlen,al		; packet length
	pop	ax
	ret

anstt5d:cmp	dnldcnt,3		; SEQ?
	ja	anstt5e			; a = no
	cmp	al,' '			; SEQ of zero?
	jne	anstt5x			; ne = no, fail
	ret
anstt5e:cmp	dnldcnt,4		; TYPE?
	ja	anstt5g			; a = no
	mov	pkttype,al		; remember TYPE for macro call
	cmp	al,'S'			; TYPE of S?
	je	anstt5h			; e = yes, succeed
	cmp	al,'I'			; TYPE of I?
	jne	anstt5x			; ne = no, fail
	ret

anstt5g:mov	bl,pktlen		; reported packet length
	add	bl,2			; add SOP and LEN
	xor	bh,bh
	cmp	dnldcnt,bx		; count matches declared pkt length?
	jb	anstt5h			; b = no, not yet, keep looking
	ja	anstt5x			; a = went too far, fail
	mov	bl,pktchk		; running checksum, type 1
	sub	bl,al			; don't add checksum byte to ours
	xor	bh,bh
	shl	bx,1			; get top two bits into bh
	shl	bx,1
	shr	bl,1			; restore bl
	shr	bl,1
	add	bl,bh			; add in top two bits
	and	bl,03fh			; chop to lower six bits
	add	bl,' '			; add ASCII bias
	cmp	al,bl			; compare checksum bytes
	jne	anstt5x			; ne = no match, fail
	mov	dnldcnt,0		; declare replay buffer empty
	cmp	pkttype,'S'		; S packet?
	jne	anstt5i			; ne = no
	call	rcvmacro		; do packet Receive macro
anstt5h:ret
anstt5i:call	srvmacro		; do packet Server macro
	ret
anstt5x:mov	cx,dnldcnt		; bytes in buffer
	jcxz	anstt5z			; z = empty
	mov	bx,offset pktbuf	; buffer
anstt5y:push	cx
	push	bx
	mov	al,[bx]			; read old byte
	call	anstt8			; replay old byte (near call)
	pop	bx
	pop	cx
	inc	bx			; next buffer byte
	loop	anstt5y
anstt5z:mov	dnldcnt,0
	ret

					; Direct char to processor module
anstt8:	test	flags.vtflg,ttd463+ttd470+ttd217 ; DG D463/D470/D217 mode?
	jnz	anstt10			; nz = yes
	test	flags.vtflg,ttwyse	; Wyse?
	jnz	anstt20			; nz = yes
	cmp	vtemu.vtchset,13	; ASCII (0) or NRC's (1-13) active?
	ja	anstt8b			; a = no
	cmp	vtemu.vtchset,0		; ASCII?
	je	anstt8b			; e = yes
	and	al,7fh			; yes, NRCs force chars to 7-bits
anstt8b:test	al,not 9fh		; control chars (0-1fh, 80h-9fh)?
	jnz	anstt9			; nz = no
	cmp	al,20h			; C0 control code?
	jb	anstt8c			; b = yes
	cmp	vtemu.vtchset,15	; TRANSPARENT?
	je	anstt9			; e = yes, pass all others
anstt8c:jmp	atctrl			; dispatch on control code
anstt9:	jmp	ttstate			; dispatch according to state

					; DG D463/D470 terminal
anstt10:test	flags.remflg,d8bit	; use high bit?
	jnz	anstt11			; nz = yes
	and	al,7fh			; 7 bit terminal only
anstt11:test	anspflg,vtcntp		; controller (transparent) printing?
	jnz	anstt12			; nz = yes, go through filter routine
	cmp	dgd470mode,0		; ansi mode?
	jne	anstt13			; ne = yes
	test	al,not 9fh		; control chars (0-1fh, 80h-9fh)?
	jnz	anstt12			; nz = no, do according to state
	cmp	ttstate,offset atnrm	; normal text processing?
	jne	anstt12			; ne = no, pass controls to state
	jmp	dgctrl			; do DG controls
anstt12:jmp	ttstate			; process regularly
					; D470 ANSI mode operations
anstt13:test	al,not 9fh		; control chars (0-1fh, 80h-9fh)?
	jz	anstt14			; z = yes
	jmp	ttstate			; process regularly
anstt14:jmp	dgansctl		; do controls

anstt20:and	al,7fh			; Wyse, chop 8th bit
	cmp	ttstate,offset atnrm	; normal state?
	je	anstt21			; e = yes
	jmp	ttstate			; do state

anstt21:cmp	al,20h			; control code?
	jae	atnrm			; ae = no, process as text
	xor	ah,ah			; clear for word use below
	mov	di,ax			; use AL as a word index
	shl	di,1
	jmp	wyc0[di]		; dispatch on C0 control codes
anstty	endp

; [HF]940130 translation procedure for Japanese
; [HF]940130 Carry set if AL is leading byte of bouble byte char.
jpnxlat	proc	near			; [HF]940130
	cmp	al,DEL			;[HF] DEL?
	jne	jpnxlat4		;[HF] ne = no
	stc				;[HF] yes, just ignore
	ret				;[HF]
jpnxlat4:				;[HF]
	push	ax			;[HF] save Char
	mov	ax,[bx+gsize+1]		;[HF] get ident
	cmp	ax,'$B'			;[HF] JIS-Kanji?
	je	jpnxlat1		;[HF] e = yes
	jmp	short jpnxlat2		;[HF]
jpnxlat1:				;[HF]
	pop	ax			;[HF] restore char
	cmp	doublebyte,0		;[HF] Leading byte?
	jne	jpnxlat3		;[HF] ne = no
	mov	doublebyte,al		;[HF] yes save it
	stc				;[HF] dont display
	ret				;[HF]
jpnxlat3:				;[HF]
	mov	ah,doublebyte		;[HF] set leading byte
	call	fjpnxtof		;[HF] xlat to local code
	mov	doublebyte,al		;[HF] save 2nd byte
	mov	al,ah			;[HF] set leading byte
	clc				;[HF] display the char in AL
	ret				;[HF]
jpnxlat2:				;[HF] single byte char
	mov	doublebyte,0		;[HF]
	pop	ax			;[HF] restore char
	xlatb				;[HF]
	cmp	rxtable+256,0		;[HF] TRANSLATION INPUT turned off?
	je	jpnxlat5		;[HF] e = yes, use ISO mechanisms
	mov	bx,offset rxtable	;[HF] address of translate table
	mov	ah,al			;[HF] copy char
	xlatb				;[HF] new char is in al
jpnxlat5:				;[HF]
	clc				; [HF]940130 display it
	ret				; [HF]940130
jpnxlat	endp				; [HF]940130

atign:	ret				; something to be ignored

atnorm: mov	ttstate,offset atnrm	; reset state to "normal"
	mov	ttstateST,offset atnorm	; reset state for ST seen
	ret
		    
atnrm	proc	near			; Normal character (in AL) processor
	mov	issoft,0		; presume hard char set
	cmp	SSptr,0			; single shift needed?
	je	atnrm10    		; e = no
	and	al,not 80h		; strip high bit
	mov	bx,SSptr		; pointer to desired char set
	mov	SSptr,0			; clear single shift indicator
	jmp	short atnrm12		; process

atnrm10:test	al,80h			; high bit set for GRight?
	jnz	atnrm11			; nz = yes
	mov	bx,GLptr		; GL char set
	jmp	short atnrm11a		; process

atnrm11:and	al,not 80h		; strip high bit
	mov	bx,GRptr		; GR char set

atnrm11a:cmp	isps55,0		; [HF]940130 Japanese PS/55 ?
	je	atnrm12			; [HF]940130 e = no
	call	jpnxlat			; [HF]940130 yes, need special xlat
	jnc	atnrm14			; [HF]940130 nc = display the char
	clc				; [HF]940130 clear carry
	ret

atnrm12:mov	ch,byte ptr [bx+gsize+3] ; get hard/soft char set indicator
	or	ch,ch			; hard character set?
	jz	atnrm12a		; z = yes
ifndef	no_graphics
	mov	issoft,ch		; activate soft
	cmp	tekflg,tek_active+tek_sg ; inited already?
	je	atnrm12a		; e = yes
	push	ax
	push	bx
	call	dgsettek		; to graphics mode
	pop	bx
	pop	ax
endif	; no_graphics
atnrm12a:xlatb				; translate al to new char in al
atnrm13:cmp	rxtable+256,0		; TRANSLATION INPUT turned off?
	je	atnrm14			; e = yes, use ISO mechanisms
	mov	bx,offset rxtable	; address of translate table
	mov	ah,al			; copy char
	xlatb				; new char is in al
atnrm14:cmp	al,DEL			; ANSI Delete char?
	jne	atnrm15			; ne = no
	ret				; ignore DEL
atnrm15:cmp	atinvisible,0		; invisible char?
	je	atnrm2			; e = no, visible
	mov	al,' '			; invisible, write as space
					; use atdeb for debug simple tty dsp
atnrm2:	mov	dx,cursor		; get cursor virtual position
	push	bx
	mov	bl,dh			; get row
	xor	bh,bh
	mov	bl,linetype[bx]		; line width
	mov	thisline,bl		; save for current reference
	cmp	issoft,0		; soft font being used?
	je	atnrm2f			; e = no
	or	dgwindcomp[bx],2	; say soft font on this line
atnrm2f:pop	bx
	test	vtemu.vtflgop,decawm	; Autowrap active?
	jz	atnrm2a			; z = no
	mov	cl,mar_right		; logical right margin
	cmp	thisline,0		; single width line?
	je	atnrm2c			; e = yes, single
	test	flags.vtflg,ttd463+ttd470+ttd217 ; DG D463/D470/D217 mode?
	jnz	atnrm2c			; nz = yes, these double the margins
	shr	cl,1			; halve right column # for wide chars
atnrm2c:cmp     isps55,0                ; [HF]941103 Japanese PS/55 mode?
        je      atnrm2h                 ; [HF]941103 e = no
        cmp     doublebyte,0            ; [HF]940226 doublebyte char ?
        je      atnrm2h                 ; [HF]940226 e = no
        dec     cl                      ; [HF]940226 check one more space
        cmp     dl,cl                   ; [HF]940226 enough space?
        jbe     atnrm2a                 ; [HF]940226 be = yes
        inc     cl                      ; [HF]940226 restore right margin
        mov     dl,cl                   ; [HF]940226 set it to DL
        inc     dl                      ; [HF]940226 set beyond pos for wrap
        mov     atwrap,dh               ; [HF]940226 mark wrap
        inc     atwrap                  ; [HF]940226 to next line
atnrm2h:cmp     dl,cl                   ; want to write beyond right margin?
	jb	atnrm2a			; b = no
	cmp	atwrap,0		; autowrap pending?
	je	atnrm2a			; e = no
	test	anspflg,vtautop		; printing desired?
	jz	atnrm2a			; e = no
	push	dx
	push	ax			; save char
	mov	dh,atwrap		; get 1+last display line's row
	dec	dh			; up one line
	call	pntlin			; print line
	mov	al,LF			; terminate in LF
	call	fpntchr
	call	fpntflsh		; flush printer buffer
	pop	ax			; recover char in AL
	pop	dx
atnrm2a:push	ax			; save character
	cmp	protectena,0		; protected mode enabled?
	je	atnrm2d			; e = no
	call	getatch			; check for protected field
	test	cl,att_protect		; protected?
	jz	atnrm2d			; z = no
	test	flags.vtflg,ttd463+ttd470+ttd217 ; DG D463/D470/D217 mode?
	jz	atnrm2d			; z = no
	call	dgcuf			; do DG cursor right
	mov	dx,cursor
atnrm2d:cmp	decrlm,0		; host right-left mode active?
	je	atnrm2e			; e = no
	cmp	atwrap,0		; wrap pending?
	je	atnrm2e			; e = no
	mov	dl,mar_right
	inc	dl			; set to wrap in normal sense

atnrm2e:call	atscur			; set cursor physical position
	pop	ax
	cmp	insmod,0		; insert mode off?
	je	atnrm3			; e = yes
	push	ax
	call	inschr			; open a char space in this line
	cmp	doublebyte,0		; [HF] doublebyte display?
	jne	atnrm2g			; [HF] ne = yes
	cmp	thisline,0		; single width line?
	je	atnrm2b			; e = yes
atnrm2g:call	inschr			; open second space for double width
atnrm2b:pop	ax			; restore char
					; set cursor before writing char
atnrm3:	cmp	thisline,0		; check for double characteristic
	je	atnrm3a			; e = normal, not doubles
	shl	dl,1			; double the column number
atnrm3a:push	dx
	call	direction		; set dx to desired position
	mov	ah,curattr		; current attribute
	mov	cl,extattr		; extended attribute
	test	cl,att_protect		; protected?
	jz	atnrm3h			; z = no
	test	flags.vtflg,ttwyse	; Wyse-50?
	jz	atnrm3h			; z = no
	mov	ah,byte ptr wyse_protattr ; use Wyse protected char attributes
	mov	cl,byte ptr wyse_protattr+1
atnrm3h:mov	ch,issoft
	or	ch,ch			; soft font?
	jz	atnrm3d			; z = no
	sub	ch,100			; remove local bias (leaves 1..31)
	shl	ch,1
	shl	ch,1
	shl	ch,1			; move to upper 5 bits
 	and	cl,not 0f8h		; clear soft set bits
	or	cl,ch			; new extended attribute
atnrm3d:call	setatch			; write char (al) and attribute (ah)
	cmp	doublebyte,0		;[HF] doublebyte display?
	je	atnrm3g			;[HF] e = no
	pop	dx			;[HF]
	inc	dl			;[HF] next column
	mov	cursor,dx		;[HF] set cursor position
	push	dx			;[HF]
	call	direction		;[HF] set dx to desired position
	mov	al,doublebyte		;[HF] set 2nd byte
	mov	ah,curattr		;[HF] current attribute
	mov	cl,extattr		; extended attribute

	test	cl,att_protect		; protected?
	jz	atnrm3i			; z = no
	test	flags.vtflg,ttwyse	; Wyse-50?
	jz	atnrm3i			; z = no
	mov	ah,byte ptr wyse_protattr ; use Wyse protected char attributes
	mov	cl,byte ptr wyse_protattr+1
atnrm3i:
	mov	ch,issoft
	or	ch,ch			; soft font?
	jz	atnrm3f			; z = no
	sub	ch,100			; remove local bias (leaves 1..31)
	shl	ch,1
	shl	ch,1
	shl	ch,1			; move to upper 5 bits
 	and	cl,not 0f8h		; clear soft set bits
	or	cl,ch			; new extended attribute
atnrm3f:call	setatch			;[HF] write 2nd char and attrib.
	mov	doublebyte,0		;[HF] clear doublebyte ind
atnrm3g:mov	issoft,0
	pop	dx
	cmp	thisline,0		; check for double characteristic
	je	atnrm4			; e = normal, not doubles
	cmp	decrlm,0		; host writing direction active?
	je	atnrm3b			; e = no
	dec	dl			; next col
	jmp	short atnrm3c
atnrm3b:inc	dl			; next column
atnrm3c:push	dx
	call	direction		; set dx to desired position
	mov	ah,curattr		; current attribute
	mov	cl,extattr		; extended attribute
	test	cl,att_protect		; protected?
	jz	atnrm3j			; z = no
	test	flags.vtflg,ttwyse	; Wyse-50?
	jz	atnrm3j			; z = no
	mov	ah,byte ptr wyse_protattr ; use Wyse protected char attributes
	mov	cl,byte ptr wyse_protattr+1
atnrm3j:
	mov	al,' '			; use a space for doubling
	mov	ch,issoft
	or	ch,ch			; soft font?
	jz	atnrm3e			; z = no
	sub	ch,100			; remove local bias (leaves 1..31)
	shl	ch,1
	shl	ch,1
	shl	ch,1			; move to upper 5 bits
 	and	cl,not 0f8h		; clear soft set bits
	or	cl,ch			; new extended attribute
atnrm3e:call	setatch			; write char (al) and attribute (ah)
	pop	dx
	shr	dl,1			; keep "cursor" in single units

atnrm4:	test flags.vtflg,ttd463+ttd470+ttd217+ttheath+ttwyse; no wrap & scroll?
	jz	atnrm4d			; z = no
	jmp	dgcuf			; do DG cursor forward

atnrm4d:test	vtemu.vtflgop,decawm	; Autowrap active?
	jz	atnrm5			; z = no
	cmp	decrlm,0		; host writing left to right?
	je	atnrm4e			; e = no
	or	dl,dl			; wrote in left most col?
	jnz	atnrm5			; nz = no
	mov	dl,mar_right		; set next column to the right
	jmp	short atnrm4b		; do not move cursor now

atnrm4e:mov	cl,mar_right		; logical right margin
	cmp	thisline,0		; single width line?
	je	atnrm4a			; e = yes, single
	shr	cl,1			; halve right column # for wide chars
atnrm4a:cmp	dl,cl			; wrote in right-most column?
	jb	atnrm5			; b = no
	inc	dl			; say want to use next column
atnrm4b:mov	atwrap,dh		; turn on wrap flag with 1 + this row
	inc	atwrap			;  so 0 means no wrap pending
	test	flags.vtflg,ttheath	; H-19?
	jnz	atscur			; nz = yes, show wrap now
	mov	cursor,dx		; virtual cursor position
	ret				; exit without moving cursor from eol

atnrm5:	mov	dx,cursor		; restore cursor position
	cmp	decrlm,0		; host writing direction active?
	je	atnrm5a			; e = no
	or	dl,dl
	jz	atnrm5b
	dec	dl			; next column
	jmp	short atnrm5b
atnrm5a:inc	dl			; next column
atnrm5b:mov	atwrap,0		; say not about to wrap
;;	jmp	short atscur
atnrm	endp

atscur:	cmp	dl,mar_left		; left of left margin?
	jae	atscu1			; ae = no, continue
	mov	dl,mar_left		; set at left margin
atscu1:	mov	cl,mar_right		; copy logical margin; cl = right col
	push	bx
	mov	bl,dh			; get row
	xor 	bh,bh
	cmp	linetype [bx],0		; single width lines?
	pop	bx
	je	atscu1a			; e = yes, single width
	test	flags.vtflg,ttd463+ttd470+ttd217 ; DG D463/D470/D217 mode?
	jnz	atscu1a			; nz = yes, these double the margins
	shr	cl,1			; halve column # for double wides
atscu1a:cmp	dl,cl			; right of right margin?
	jbe	atscu3			; be = no, continue
	mov	dl,cl			; assume no autowrap
	test	vtemu.vtflgop,decawm	; Autowrap?
	jz	atscu3			; z = no
	mov	dl,mar_left		; set to left margin
	cmp	decrlm,0		; host right-left mode active?
	je	atscu1e			; e = no
	mov	dl,mar_right
atscu1e:cmp	dh,byte ptr low_rgt+1	; at bottom of screen?
	je	atscu1b			; e = yes
	cmp	dh,mar_bot		; at bottom of scrolling region?
	jl	atscu2			; l = no, bump cursor and continue
atscu1b:test	flags.vtflg,ttd463+ttd470+ttd217 ; DG D463/D470/D217 mode?
	jz	atscu1d			; z = no
	cmp	dgroll,0		; is DG roll enabled?
	jne	atscu1d			; ne = yes, do the scroll
	mov	dh,mar_top		; move to top of window
	jmp	short atscu3
atscu1d:mov	scroll,1		; scroll count = 1 line
	call	atscru			; scroll up
	dec	dh			; offset inc dh below
atscu2: inc	dh			; just bump it
atscu3: or	dh,dh			; constrain row to valid range
	jge	atscu4			; ge = non-negative row, ok
	xor	dh,dh
atscu4: cmp	dh,byte ptr low_rgt+1	; 25th line?
	jle	atsetcur		; le = no
	mov	dh,byte ptr low_rgt+1	; set to 24th line
	cmp	flags.vtflg,ttheath	; emulating a Heath-19?
        je      atscu4c                 ; [HF]940227 e = yes, Heath-19
        cmp     isps55,0                ; [HF]941103 Japanese PS/55 ?
        je      atscu4a                 ; [HF]941103 e = no
        cmp     flags.modflg,2          ; [HF]940227 mode line owned by host?
        jne     atsetcur                ; [HF]940227 ne = no, don't touch
        jmp     short atscu4a           ; [HF]940227 host wants to go to 25th
atscu4c:test    h19stat,h19l25          ; Heath 25th line enabled?
	jz	atsetcur		; z = no
atscu4a:inc	dh			; go to line 25 [hlk]
	test	yflags,modoff		; is mode line off?
	jnz	atscu4b			; nz = yes
	push	dx			; save cursor position
	call	fclrmod			; clear the line
	or	yflags,modoff		; now say it's off (owned by host)
	pop	dx
atscu4b:mov	flags.modflg,2		; say mode line is owned by host

atsetcur:cmp	dh,slen			; beyond last screen row we support?
	jbe	atsetcur0a		; be = no
	mov	dh,slen			; put on last row
atsetcur0a:cmp	dl,mar_right		; beyond right edge?
	jbe	atsetcur0b		; be = no
	mov	dl,mar_right		; limit to right edge
atsetcur0b:
	mov	cursor,dx		; set cursor and return
	push	dx
	mov	bl,dh			; get row
	xor	bh,bh			; clear high byte
	cmp	linetype[bx],0		; single width line?
	je	atsetcu1		; e = yes
	shl	dl,1			; double the column number
atsetcu1:call	direction		; set dx to desired position
	call	setpos			; set cursor physical position
	pop	dx
	test	vtemu.vtflgop,vsmarginbell; do we care about margin bell?
	jz	atsetcu2		; z = no, return if no margin bell
	cmp	kbiflg,0		; is keyboard input flag set?
	je	atsetcu2		; e = no, just return
	mov	bx,kbicsr		; cursor at previous keyboard input
	cmp	bh,dh			; same row as now?
	jne	atsetcu2		; ne = no, just return
	cmp	bl,belcol		; old cursor at or left of bell column?
	ja	atsetcu2		; a = no, just return
	cmp	dl,belcol		; new cursor past bell column?
	jbe	atsetcu2		; be = no, just return
	push	dx
	call	vtbell			; ring the bell
	pop	dx
atsetcu2:ret

; Control-character dispatcher
atctrl:	cmp	al,escape		; an escape sequence starting?
	je	atctrl1			; e = yes, don't print it
	cmp	al,CSI			; this kind of escape?
	je	atctrl1			; e = yes
	cmp	al,18h			; CAN (cancel)?
	je	atctrl6			; e = yes
	cmp	al,1ah			; SUB (treated as CAN)?
	je	atctrl6			; e = yes
	cmp	al,9ch			; ST?
	jne	atctrl5			; ne = no
	jmp	ttstateST
atctrl5:cmp	ttstate,offset atesc1	; state is second char of ST?
	jne	atctrl6			; ne = no
	jmp	ttstate			; go process second char
atctrl6:test	anspflg,vtcntp		; printing desired?
	jz	atctrl1			; z = no
	call	fpntchr			; print char in al
atctrl1:xor	ah,ah			; clear for word use below
	test	al,80h			; high bit set?
	jnz	atctrl2			; nz = yes
	mov	di,ax			; use AL as a word index
	shl	di,1
atctrl3:jmp	ansc0[di]		; dispatch on C0 control codes
atctrl2:and	al,not 80h		; strip high bit
	mov	di,ax			; use AL as a word index
	shl	di,1
	test	flags.vtflg,ttvt320+ttvt220 ; doing VT320/VT220?
	jz	atctrl3			; z = no, trim back to C0
atctrl4:jmp	ansc1[di]		; dispatch on C1 control codes

; Control code routines
atbs:	cmp	decrlm,0		; host writing direction active?
	jne	atbs2			; ne = yes
	or	dl,dl			; Backspace, too far?
	jz	atbs1			; z = at column 0 already
	dec	dl			; backup cursor
atbs1:	call	atccpc			; check range
	mov	atwrap,0		; cancel wrap pending
	jmp	atsetcur		; set cursor and return

atbs2:	cmp	dl,mar_right		; at right margin now?
	je	atbs1			; e = yes, stop
	inc	dl
	jmp	short atbs1

atht:	cmp	flags.vtflg,ttheath	; Horizontal Tab, Heath-19 mode?
	je	atht2			; e = yes, handle specially
	xor	ch,ch
	mov	cl,mar_right
	cmp	dl,cl			; at or beyond last column?
	jae	atht1a			; ae = yes check range, set cursor
atht1:	inc	dl			; tab always moves at least one column
	push	si
	mov	si,vtemu.vttbst		; active buffer
	call	istabs			; returns carry set if at a tabstop
	pop	si
	jc	atht1a			; c = at a tabstop
	loopz	atht1
atht1a:	call	atccpc			; check range
atht1b:	call	atsetcur		; set cursor and return
	ret

atht2:	mov	dx,cursor		; Heath-19. get cursor position
	add	dl,8			; tabs are every 8 columns
	and	dl,not 7		; do modulo 8
	cmp	dl,mar_right		; check against right edge
	jbe	atht3			; be = in range
	mov	dl,mar_right		; else go to right margin
atht3:	jmp	atht1b			; set cursor and return

atlf:	test	vtemu.vtflgop,anslnm	; Line Feed, New-line mode?
	jz	atlf2			; z = no, just move to next line down
atlf1:	mov	dl,mar_left		; move to left margin also
	cmp	decrlm,0		; host writing direction active?
	je	atlf2			; e = no
	mov	dl,mar_right
atlf2:	test	anspflg,vtautop		; printing desired?
	jz	atlf3			; e = no
	push	dx
	push	ax			; save char
	call	pntlin			; print current line
	pop	ax			; recover char in AL, print it too
	call	fpntchr
	call	fpntflsh		; flush printer buffer
	pop	dx
atlf3:	inc	dh			; index line down
	call	atccic			; check indexing
	test	flags.vtflg,ttwyse	; Wyse-50?
	jz	atlf4			; z = no, do the scroll if any
	cmp	protectena,0		; protected mode on?
	je	atlf4			; e = no, can scroll
	cmp	ax,offset atign		; scroll requested?
	je	atlf5			; e = no
	mov	dh,mar_top		; roll over to the top
	jmp	short atlf5
atlf4:	call	ax			; call scrolling routine
atlf5:	jmp	atsetcur		; set cursor

atcr: 	mov	dl,mar_left		; Carriage Return, go to left margin
	mov	atwrap,0		; cancel wrap pending
	cmp	decrlm,0		; host writing direction active?
	je	atcr2			; e = no
	mov	dl,mar_right
atcr2:	cmp	flags.vtflg,ttheath	; Heath-19?
	jne	atcr1			; ne = no
	test	h19stat,h19alf		; auto line feed on?
	jnz	atcr3			; nz = yes, do the LF part above
atcr1:	cmp	crdisp_mode,0		; CR-display is normal?
	jne	atlf3			; ne = no, do CR-LF
	jmp	atsetcur		; set cursor and return
atcr3:	test	anspflg,vtcntp		; print controller on?
	jnz	atcr3a			; nz = yes
	test	flags.capflg,logses	; capturing output?
	jz	atcr4			; z = no, forget this part
atcr3a:	push	dx			; save char
	mov	al,LF			; log the new LF after the CR
	call	fcptchr			; give it captured character
	pop	dx			; restore character
atcr4:	jmp	atlf2			; do CR-LF

atff:	cmp	flags.vtflg,ttansi	; ansi terminal?
	jne	atff2			; ne = no
	cmp	ttstate,offset atescf	; Form Feed, parsing escape sequence?
	je	atff1			; e = yes
	mov	ninter,0		; prepare for CSI 2 J simulation
	mov	lparam,0
	mov	param,2
	jmp	ated			; erase screen, home cursor

atff2:	cmp	ttstate,offset atescf	; Form Feed, parsing escape sequence?
	jne	atlf			; ne = no, do as line feed
atff1:	test	denyflg,tekxflg		; is auto Tek mode disabled?
	jnz	atlf			; nz = yes, treat as line feed
ifndef	no_graphics
	call	atsc			; save cursor and associated data
	mov	al,escape
	call	TEKEMU
	mov	al,FF
	call	TEKEMU			; feed to Tektronix Emulator, al=FF
	jmp	atnorm
else
	jmp	atlf
endif	; no_graphics

atcan:	mov	parstate,0		; CAN, clear esc seq parser
	jmp	atnorm

atenq:	mov	cx,ENQhstrl-1		; length of Honeywell string-1
	mov	si,offset ENQhstr	; ptr to string
	mov	ttyact,0		; start grouping for networks
	cmp	flags.vtflg,tthoney	; ENQ, Honeywell terminal?
	je	atenq1			; e = yes
	cmp	vtenqenable,0		; VTxxx response enabled?
	je	atenq4			; e = no
	cmp	enqbuf,0		; safe?
	jne	atenq1f			; ne = no, unsafe, no prefix
	mov	cx,ENQstrl		; length of string
	mov	si,offset ENQstr	; ptr to string
atenq1:	cld	
	lodsb				; get a byte
	push	cx			; save regs
	push	si
	call	prtbout			; send to port WITHOUT echo
	pop 	si
	pop	cx
	loop	atenq1			; loop for all characters
atenq1f:cmp	flags.vtflg,tthoney	; ENQ, Honeywell terminal?
	je	atenq3			; e = yes
	mov	rdbuf,' '
	mov	di,offset rdbuf		; place to work
	cmp	enqbuf,0		; safe message?
	jne	atenq1b			; ne = no, unsafe, no prefix
	inc	di			; start with space prefix
	mov	ax,version		; Kermit version
	call	dec2di
	mov	byte ptr [di],'_'	; _terminal name
	inc	di
	call	getled			; get terminal name to si
	mov	cx,8			; max of 8 bytes
atenq1a:lodsb				; read a byte
	cmp	al,' '			; still in visibles?
	jbe	atenq1b			; be = no
	mov	[di],al			; store
	inc	di
	loop	atenq1a			; do more

atenq1b:mov	si,offset enqbuf+1	; user postfix, asciiz
	cmp	byte ptr [si],0		; anything there?
	je	atenq1d			; e = no
	cmp	byte ptr [si-1],0	; safe message?
	jne	atenq1c			; ne = no, unsafe, no prefix
	mov	byte ptr [di],'_'	; separator
	inc	di
	dec	cx			; one less slot
atenq1c:lodsb
	or	al,al
	jz	atenq1d			; z = end of string
	cmp	enqbuf,0		; safe?
	jne	atenq1e			; ne = no, unsafe, use as-is
	cmp	al,' '			; control code?
	jae	atenq1e			; ae = no
	mov	al,'_'			; force in separator
atenq1e:mov	[di],al
	inc	di
	jmp	short atenq1c		; while there is text

atenq1d:mov	byte ptr [di],CR	; CR terminator
	inc	di
	mov	cx,di
	mov	si,offset rdbuf
	sub	cx,si
	dec	cx			; do all but last char in loop
atenq2:	lodsb
	push	cx			; save regs
	push	si
	call	prtbout			; send to port WITHOUT echo
	pop 	si
	pop	cx
	loop	atenq2
atenq3:	lodsb				; last char
	mov	ttstate, offset atnrm	; reset to normal and return
	mov	ttyact,1		; end group output for networks
	call	prtbout			; last byte trips the group trigger
atenq4:	ret

atesc:	cmp	ttstate,offset atdcsnul	; consuming a DCS?
	jne	atesc3			; ne = no
	mov	ttstate,offset atesc1	; stay here
	ret
atesc1:	cmp	al,'\'			; end of ST?
	je	atesc2			; e = yes
	jmp	atdcsnul		; continue to consume DCS
atesc2:	jmp	atgotst			; reset DCS processing

atesc3:	mov	ttstate,offset atescf	; ESC, next state is escape follower
	ret

; Respond to character following Escape, dispatch on that char
atescf:	call	atpclr			; clear parser argument list
	mov	dcstabptr,offset dcstab	; VT DCS dispatch table
	mov	atescftab,offset ansesc	; ANSI escape table, for atdispat
	mov	ansifinptr,offset anstab
	mov	cx,flags.vtflg
	test	cx,ttvt320+ttvt220+ttvt102+ttvt100+tthoney+ttansi ; VT320 etc?
	jnz	atescf2			; nz = yes
	mov	atescftab,offset v52esc ; VT52 escape table
	cmp	cx,ttvt52		; VT52?
	je	atescf1			; e = yes
	mov	atescftab,offset h19esc ; use Heath-19 table
	cmp	cx,ttheath		; Heath-19?
	je	atescf1			; e = yes
	mov	atescftab,offset pt200esc
	cmp	cx,ttpt200		; Prime PT200?
	je	atescf2			; e = yes
	mov	atescftab,offset dgescftab ; use D470 escape follower table
	mov	dcstabptr,offset dgdcstab ; DG DCS dispatch table
	mov	ansifinptr,offset dganstab 
	cmp	cx,ttd470		; D470?
	je	atescf2			; e = yes
	ret				; return on error
atescf1:mov	ttstate,offset atnrm	; reset state to "normal"
	mov	bx,atescftab		; get offset of escape follower table
	jmp	atdispat		; perform dispatch via table in BX

atescf2:test	al,not (2fh)		; in intermediates (column 2)?
	jnz	atescf1			; nz = no, dispatch on this char
	mov	ttstate,offset atescf2	; stay in this state til col 3 or more
	mov	bx,ninter		; number of intermediates
	cmp	bx,maxinter		; done enough already?
	jae	atescf3			; ae = yes, ignore the excess
	mov	inter[bx],al		; store this one
	inc	ninter			; one more
atescf3:ret				; get more input

					; CSI, char 9bh (ANSI CSI == ESC [)
atcsi0:	cmp	ninter,0		; any intermediates from ESC..[?
	je	atcsi			; e = no, else not this item
	jmp	atnorm			; reset state to "normal"
					; enter here with real CSI char
atcsi:	mov	ttstate,offset atparse	; next state is parse control seq
	mov	parfail,offset atnorm	; where to jmp if failure
	mov	pardone,offset atcsi1	; where to jmp when done
	jmp	atpclr			; clear parser parameters and return

atcsi1:	mov	bx,ansifinptr		; ANSI Final character table
	mov	ttstate,offset atnrm	; reset state to "normal"
	jmp	atdispat		; dispatch on character

h19csi:	test	vtemu.vtflgop,decanm	; Heath-19 "ESC [", is ANSI mode on?
	jnz	h19csi1			; nz = yes
	mov	ttstate,offset atnrm	; else ignore the "[" (kbd lock)
	ret
h19csi1:mov	ttstate,offset atparse	; H-19, ESC [ parser
	mov	pardone,offset h19csi2 	; where to jmp when done
	mov	parfail,offset atnorm	; where to jmp if failure
	ret				; get next char
h19csi2:mov	bx,offset h19ans	; H-19 ANSI Final character table
	mov	ttstate,offset atnrm	; reset state to "normal"
	jmp	atdispat		; dispatch on character

; Process Device Control Strings (DCS or ESC P lead-in chars, already read).
atdcs0:	cmp	ninter,0		; any intermediates?
	je	atdcs			; e = no, else not this item
	jmp	atnorm			; reset state to normal
					; enter here with real DCS char
atdcs:	mov	ttstate,offset atparse	; next state is parse control seq
	mov	pardone,offset atdcs1	; where to jmp when done
	mov	parfail,offset atdcsnul	; where to jmp if failure
	ret
atdcs1:	mov	dcsstrf,al		; record Final char
	mov	emubufc,0		; clear string count
	mov	cx,maxparam		; number of DCS parameters
	push	si			; copy these to the DCS area so that
	push	di			;  they are not lost when an ST is
	push	es			;  parsed (parser clears ESC items)
	push	ds
	pop	es
	mov	si,offset param		; ESC paramater storage area, numeric
	mov	di,offset dparam	; DCS parameter storage area, numeric
	cld
	rep	movsw			; copy set to DCS storage area
	mov	cl,lparam 		; copy letter Paramter
	mov	dlparam,cl
	mov	cx,maxinter		; number of intermediate characters
	mov	si,offset inter		; source
	mov	di,offset dinter	; destination
	rep	movsb
	mov	si,nparam		; number of parameters
	mov	dnparam,si
	mov	si,ninter
	mov	dninter,si		; number of intermediates
	pop	es
	pop	di
	pop	si
	mov	ttstateST,offset atnorm ; default ST completion state
	mov	emubufc,0		; clear processed string length
	mov	al,dcsstrf		; get DCS Final char
	mov	bx,dcstabptr		; DCS dispatch table
	call	atdispat		; go to DCS handler
	ret

; Process ST or ESC \  String Terminator.
atgotst0:cmp	ninter,0		; any intermediates in ESC..\?
	je	atgotst			; e = no, else not this item
	jmp	atnorm			; reset state to normal
					; enter here with real ST char
atgotst:jmp	ttstateST		; go to state for ST arrival

; Read and discard OSC (ESC ]), PM (ESC ^) control sequences
; through final ST (ESC \) terminator.
atdcsnul0:cmp	ninter,0		; any intermediates in ESC..\?
	je	atdcsnul		; e = no, else not this item
	ret
					; enter here with real ST char
atdcsnul:mov	dcsstrf,0		; simulate a null (dummy) Final char
	mov	emubufc,0		; clear string count
	mov	ttstate,offset atdcsnul	; keep coming here
	mov	ttstateST,offset atnorm	; where to go when ST has been seen
	ret				; consume chars

; Process Application Process Control string (APC or ESC _ lead-in chars,
; already read). Mallocs 1KB buffer, passes buffer to apcmacro for execution
; as a Take file. Curly braces protect comma command separators.
atapc:	cmp	ninter,0		; any intermediates?
	je	atapc0			; e = no, else not this item
	jmp	atnorm			; reset state to normal
					; enter here with real DCS char
atapc0:	mov	ax,apcstring		; old string buffer segment
	or	ax,ax			; used?
	jz	atapc1			; z = no
	push	es
	mov	es,ax
	mov	ah,freemem		; free that string memory
	int	dos
	pop	es
	mov	apcstring,0		; clear pointer
atapc1:	mov	bx,(1024+3+15)/16	; 1K buffer
	mov	cx,bx			; remember desired paragraphs
	mov	ah,alloc		; allocate a memory block
	int	dos
	jc	atapc2			; c = error, not enough memory
 	cmp	bx,cx			; obtained vs wanted
	jae	atapc3			; ae = enough
	push	es
	mov	es,ax			; allocated segment
	mov	ah,freemem		; free it again
	int	dos
	pop	es
atapc2:	jmp	atnorm			; fail

atapc3:	mov	apcstring,ax		; remember segment
	mov	bracecount,0		; count of curly braces in string
	mov	emubufc,0		; preset string buffer count
	mov	ttstate,offset atapc4	; next state is read string
	mov	ttstateST,offset atapc5	; where to go when ST has been seen
	ret
					; read bytes of APC string
atapc4:	mov	bx,emubufc		; count of buffer chars
	cmp	bx,1024			; too many?
	ja	atapc6			; a = yes, ignore string
	push	es
	mov	cx,apcstring		; segment of string buffer
	mov	es,cx
	cmp	al,braceop		; opening brace?
	jne	atapc4a			; ne = no
	inc	bracecount		; count up braces
atapc4a:cmp	al,bracecl		; closing brace?
	jne	atapc4b			; ne = no
	sub	bracecount,1		; count down braces
	jnc	atapc4b			; nc = not below zero
	mov	bracecount,0		; clamp to zero
atapc4b:cmp	al,','			; comma command separator?
	jne	atapc4c			; ne = no
	cmp	bracecount,0		; in curly braces?
	jne	atapc4c			; ne = yes, leave comma as comma
	mov	al,CR			; replace bare comma as CR
atapc4c:xor	ah,ah
	mov	es:[bx+2],ax		; store incoming byte + null
	pop	es
	inc	emubufc			; count bytes in buffer
	ret				; accumulate more bytes

atapc5:	mov	ax,apcstring		; get here upon ST for APC
	or	ax,ax			; string buffer in use?
	jz	atapc6			; z = no, quit
	mov	ttstate,offset atnrm	; reinit state before leaving
	mov	ttstateST,offset atnorm
	mov	bracecount,0		; count of curly braces in string
	cmp	apcenable,0		; is APCMACRO enabled?
	je	atapc6			; e = no, quit
	push	es
	mov	es,ax
	mov	bx,emubufc		; count of bytes in string
	mov	emubufc,0		; clear for later users
	mov	byte ptr es:[bx+2],CR	; append CR C to renter Connect mode
	mov	byte ptr es:[bx+2+1],'C'
	add	bx,2			; two more bytes in buffer
	mov	es:[0],bx		; length of string
	pop	es
	mov	cx,bx			; CX used to pass string length
	call	APCMACRO		; create and execute Take file
					; does not return if success
atapc6:	mov	ax,apcstring		; segment of string buffer
	or	ax,ax			; in use?
	jz	atapc7			; z = no
	mov	es,ax
	mov	ah,freemem		; free buffer
	int	dos
atapc7:	mov	apcstring,0		; clear buffer
	mov	emubufc,0		; clear string count
	mov	bracecount,0		; count of curly braces in string
	jmp	atnorm			; exit this sequence


; User Definable Key processor of DCS strings.
atudk:	cmp	dinter,0		; no intermediates?
	je	atudk1			; e = correct
	mov	ninter,0		; setup atdcsnul for proper form
	jmp	atdcsnul		; bad, consume the rest

atudk1:	cmp	dparam,1		; is initial Parameter Pc a 1?
	jae	atudk2			; ae = yes, clear only this key
	call	udkclear		; clear all UDKeys
	mov	dparam,1		; and turn off Parameter
atudk2:	mov	ttstate,offset atudk3	; next state is get a substring
	mov	ttstateST, offset atudk6 ; for when ST has been seen
	ret

atudk3:	cmp	al,';'			; string separator?
	je	atudk5			; e = yes, process string to-date
	mov	bx,emubufc		; count of chars in string buffer
	cmp	bx,emubufl		; too many?
	jae	atudk4			; ae = too many, ignore extras
	mov	emubuf[bx],al		; store the char
	inc	emubufc			; count it
atudk4:	ret
atudk5:	mov	si,offset emubuf	; address of string buffer is DS:SI
	mov	cx,emubufc		; count of buffer contents
	call	setudk			; insert string definition
	mov	emubufc,0		; clear string buffer
	ret
atudk6:	call	atudk5			; ST seen, process last string
	jmp	atnorm			; reset state to normal

; Call this routine to deliver Parameters in succession. Each call points to
; a Parameter as param[si], where si is maintained here. If there are no
; Parameters the effect is the same as one Parameter with a value of zero.
; Enter with di = offset of action routine to be called for each Parameter.
; cx, si, and di are preserved over the call to the action routine.

atreps	proc	near
	xor	si,si			; initialize parm index
	mov	cx,nparam		; number of Parameters
	or	cx,cx			; zero?
	jnz	atrep1			; nz = no
	inc	cx			; zero parms is same as 1
atrep1: push	cx			; save loop counter
	push	si			; save parameter index
	push	di			; save call vector
	call	DI			; call indicated routine
	pop	di			; restore registers
	pop	si
	pop	cx
	add	si,2			; advance to next parameter
	loop	atrep1			; loop for all
	ret
atreps	endp

					; Action routines
atind0:	cmp	ninter,0		; any intermediates?
	je	atind			; e = no, else not this item
	ret
atind:	inc	dh			; IND (index), move cursor down one
atind1: call	atccic			; check cursor position
	call	ax			; scroll if necessary
	jmp	atsetcur		; set cursor, etc. and return

atnel0:	cmp	ninter,0		; any intermediates from ESC..E?
	je	atnel			; e = no, else not this item
	jmp	atdgnrc			; try Nowegian/Danish NRC designator
					; enter here with real NEL char
atnel:	mov	dl,mar_left		; NEL, next line - sort of like CRLF
	inc	dh			; ... all in one command
	jmp	short atind1		; check cursor, etc., and return

atri0:	cmp	ninter,0		; any intermediates?
	je	atri			; e = no, else not this item
	ret
atri:	cmp	flags.vtflg,ttheath	; Heath-19?
	jne	atri1			; ne = no
	cmp	dh,byte ptr low_rgt+1	; on 25th line?
	jbe	atri1			; be = no
	ret				; no vertical for Heath on 25th line
atri1:	dec	dh			; RI, reverse index
	jmp	short atind1		; check cursor, etc., and return

					; HTS, horizontal tab set in this col
athts0:	cmp	ninter,0		; any intermediates from ESC..H?
	je	athts			; e = no, else not this item
        cmp     isps55,0                ; [HF] Japanese mode ?
        je      athts1                  ; [HF] e = no
        jmp     atdgfJ                  ; [HF] else possible old wrong JISRoman
athts1: jmp     atdgnrc                 ; try Swedish NRC designator
athts:	call	atccpc			; make column number valid
	mov	si,vtemu.vttbst		; active buffer
	jmp	tabset			; say set tab in this column (DL)

					; DECSC
atsc:	mov	si,offset savelist	; save cursor, attribute, char set etc
	mov	di,offset savecu	; place to save the stuff
	mov	cl,extattr		; extended attributes
	mov	savextattr,cl		; it's real storage is in msyibm
	mov	cl,scbattr
	mov	savscbattr,cl
	mov	havesaved,1		; say have saved something
	mov	cx,lsavecu		; length of save area
	push	es			; save es
	mov	ax,data			; seg of save area
	mov	es,ax			; set es to data segment
	cld
	shr	cx,1			; divide by two for word moves
	jnc	atsc1			; nc = even number of bytes
	movsb				; do the odd byte
atsc1:	rep	movsw			; save it
	pop	es
	mov	cx,vtemu.vtflgop	; save a copy of the flags
	mov	savflgs,cx
	ret
					; DECRC
atrc:	cmp	havesaved,0		; saved anything yet?
	jne	atrc1			; ne = yes
	ret
atrc1:	mov	si,offset savecu	; restore cursor, attributes, etc
	mov	di,offset savelist	; where stuff goes
	mov	cx,lsavecu		; length of save area
	push	es			; save es
	push	ds
	mov	ax,seg savecu		; seg of savecu storage
	mov	ds,ax
	mov	ax,seg savelist		; seg of regular storage
	mov	es,ax
	cld
	shr	cx,1			; divide by two for word moves
	jnc	atrc2			; nc = even number of bytes
	movsb				; do the odd byte
atrc2:	rep	movsw			; put the stuff back
	pop	ds
	pop	es
	mov	al,savextattr		; extended attributes
	mov	extattr,al
	mov	al,savscbattr
	mov	scbattr,al
	mov	ax,savflgs		; get saved flags
	xor	ax,vtemu.vtflgop	; exclusive-or with current flags
	mov	al,atctype		; get cursor shape
	call	csrtype			; restore it
atrc3:	mov	ax,vtemu.vtflgop	; reset flags in case called again
	and	ax, not(decckm+deckpam+decom)  ; remove old bits [dlk]
	and	savflgs,(decckm+deckpam+decom) ; remove all but new bits [dlk]
	or	ax,savflgs		; restore saved bits [dlk]
	or	vtemu.vtflgop,ax	; update these flags
	mov	savflgs,ax
	mov	bx,offset Gsetid	; restore character sets
	call	chrsetup		; go remake G0..G3
	mov	dx,cursor		; get cursor
	mov	kbiflg,0		; don't bother them with beeps here
	jmp	atsetcur		; set cursor

atkpam:	cmp	ninter,0		; any intermediates?
	jne	atkpam1			; ne = yes, not this item
	or	vtemu.vtflgop,deckpam	; turn on keypad applications mode
	ret
atkpam1:jmp	atdgnrc			; try Swiss NRC designator

atkpnm: and	vtemu.vtflgop,not deckpam ; turn off keypad applications mode
	ret				; (to numeric mode)

					; Privileged sequence, ignore it
atpriv:	cmp	ninter,0		; any intermediates?
	jne	atpriv1			; ne = yes, not this item
	mov	ttstate,offset atnorm	; ignore next char
atpriv1:ret				; and return to normal afterward

; ISO 2022 three byte Announcer Summary    <ESC> <space> <final char>
;Esc Sequence  7-Bit Environment          8-Bit Environment
;----------    ------------------------   ----------------------------------
;<ESC><SP>A    G0->GL                     G0->GL
;<ESC><SP>B    G0-(SI)->GL, G1-(SO)->GL   G0-(LS0)->GL, G1-(LS1)->GL
;<ESC><SP>C    (not used)                 G0->GL, G1->GR
;<ESC><SP>D    G0-(SI)->GL, G1-(SO)->GL   G0->GL, G1->GR
;<ESC><SP>E    Full preservation of shift functions in 7 & 8 bit environments
;<ESC><SP>F    C1 represented as <ESC>F   C1 represented as <ESC>F
;<ESC><SP>G    C1 represented as <ESC>F   C1 represented as 8-bit quantity
;<ESC><SP>H    All graphic character sets have 94 characters
;<ESC><SP>I    All graphic character sets have 94 or 96 characters
;<ESC><SP>J    In a 7 or 8 bit environment, a 7 bit code is used
;<ESC><SP>K    In an 8 bit environment, an 8 bit code is used
;<ESC><SP>L    Level 1 of ISO 4873 is used
;<ESC><SP>M    Level 2 of ISO 4873 is used
;<ESC><SP>N    Level 3 of ISO 4873 is used
;<ESC><SP>P    G0 is used in addition to any other sets:
;              G0 -(SI)-> GL              G0 -(LS0)-> GL
;<ESC><SP>R    G1 is used in addition to any other sets:
;              G1 -(SO)-> GL              G1 -(LS1)-> GL
;<ESC><SP>S    G1 is used in addition to any other sets:
;              G1 -(SO)-> GL              G1 -(LS1R)-> GR
;<ESC><SP>T    G2 is used in addition to any other sets:
;              G2 -(LS2)-> GL             G2 -(LS2)-> GL
;<ESC><SP>U    G2 is used in addition to any other sets:
;              G2 -(LS2)-> GL             G2 -(LS2R)-> GR
;<ESC><SP>V    G3 is used in addition to any other sets:
;              G3 -(LS2)-> GL             G3 -(LS3)-> GL
;<ESC><SP>W    G3 is used in addition to any other sets:
;              G3 -(LS2)-> GL             G3 -(LS3R)-> GR
;<ESC><SP>Z    G2 is used in addition to any other sets:
;              SS2 invokes a single character from G2
;<ESC><SP>[    G3 is used in addition to any other sets:
;              SS3 invokes a single character from G3
;
; ISO Escape Sequences for Alphabet Designation ("F" = Final char)
; Sequence     Function                                         Invoked By
;  <ESC>(F     assigns 94-character graphics set "F" to G0.     SI  or LS0
;  <ESC>)F     assigns 94-character graphics set "F" to G1.     SO  or LS1
;  <ESC>*F     assigns 94-character graphics set "F" to G2.     SS2 or LS2
;  <ESC>+F     assigns 94-character graphics set "F" to G3.     SS3 or LS3
;  <ESC>-F     assigns 96-character graphics set "F" to G1.     SO  or LS1
;  <ESC>.F     assigns 96-character graphics set "F" to G2.     SS2 or LS2
;  <ESC>/F     assigns 96-character graphics set "F" to G3.     SS3 or LS3
;  <ESC>$(F    assigns multibyte character set "F" to G0.       SI  or LS0
;  <ESC>$)F    assigns multibyte character set "F" to G1.       SO  or LS1
;  <ESC>$*F    assigns multibyte character set "F" to G2.       SS2 or LS2
;  <ESC>$+F    assigns multibyte character set "F" to G3.       SS3 or LS3
;     
; Designate character sets, AL has final character, inter has all preceeding.
;
;  <ESC> $ B       designate JIS X 208 code set (ISO(ECMA)#87) to G0 (old)
;  <ESC> $ <char> B  designates JIS X 208 code set (ISO(ECMA)#87)
;
;  The following sequences are for JIS C 6226-1978 code set (ISO(ECMA)#42), but
;  treated as the same as the above in this version of MS-Kermit, becuase that the
;  diffrence is quite small.
;
;  <ESC> $ @
;  <ESC> $ <char> @
;
;  <ESC> <char> J  designates JIS X 201 Roman code set (ISO(ECMA)#14)
;
;  Note: The ESC sequences for U.S. ASCII code set are treated as the same
;        as above because there is no fonts are available for U.S. ASCII .
;        The differences between U.S. ASCII and JIS X 201 Roman are only
;        backslash and tilde.
;
atdgfA:	call	atdgset			; 'A' ISO Latin-1, UK-ASCII
	jc	atdgfA1			; c = no matching pointer
	cmp	inter,'+'		; in the 94 byte set?
	ja	atdgfA2			; a = no, 96 'A' is Latin1
	mov	ax,flags.vtflg		; terminal type
	test	ax,ttvt320+ttvt220+ttvt102+ttvt100+tthoney+ttansi ; VTxxx?
	jz	atdgfA1			; z = no
	jmp	mkukascii		; make UK ASCII table
atdgfA1:ret

atdgfA2:jmp	mklatin1		; make Latin1 char set

atdgfA3:jmp	atdgnrc			; try British NRC

atdgfB:	cmp	inter,'$'		; [HF] 940130 multibyte set?
	je	atdgfB2			; [HF] 940130 e = yes
	call	atdgset			; 'B' ASCII, get setptr from inter
	jc	atdgfA1			; c = no matching pointer
	cmp	inter,'+'		; in the 94 byte set?
	ja	atdgfB1			; a = no, do Latin2
	jmp	mkascii			; make US ASCII set

atdgfB1:jmp	mklatin2		; make Latin2 ("B"/96)

atdgfB2:cmp	ninter,1		; [HF] any intermediates?
	jne	atdgfB3			; [HF] ne = yes we have
	mov	inter,'('		; [HF] implicit G0 /94
	jmp	short atdgfB4		; [HF]
atdgfB3:push	ax			; [HF]
	mov	al,inter[1]		; [HF]
	mov	inter,al		; [HF]
	mov	ninter,1		; [HF]
	pop	ax			; [HF]
atdgfB4:call	atdgset			; [HF]
	jc	atdgfA1			; [HF]
	jmp	mkjiskanji		; [HF]

;[HF] Japanese JIS-Katakana and JIS-Roman
;[HF]
atdgfI:	call	atdgset			; [HF] JIS-Katakana
	jc	atdgfI1			; [HF] c = no matching pointer
	cmp	inter,'+'		; [HF] in the 94 byte set?
	ja	atdgfI1			; [HF] a = no, just ignore
	mov	ax,flags.vtflg		; [HF] terminal type
	test	ax,ttvt320+ttvt220+ttvt102+ttvt100+tthoney ; [HF] VTxxx?
	jz	atdgfI1			; [HF] z = no
	jmp	mkjiskana		; [HF] make JIS Katakana table
atdgfI1:ret				; [HF]

atdgfJ:	call	atdgset			; [HF] JIS-Roman
	jc	atdgfJ1			; [HF] c = no matching pointer
	cmp	inter,'+'		; [HF] in the 94 byte set?
	ja	atdgfJ1			; [HF] a = no, just ignore
	test	ax,ttvt320+ttvt220+ttvt102+ttvt100+tthoney ; [HF] VTxxx?
	jz	atdgfJ1			; [HF] z = no
	jmp	mkascii			; [HF] treat as US ASCII
atdgfJ1:ret				; [HF]

atdgf0:	call	atdgset			; '0', '2', DEC Special Graphics
	jc	atdgfA1			; c = no matching pointer
	cmp	inter,'+'		; in the 94 byte set?
	ja	atdgfA1			; a = no, ignore
	jmp	mkdecspec		; init set to DEC Special Graphics

atdgf1:	call	atdgset			; '1' ALT-ROM
	jc	atdgf1b			; c = no matching pointer
	jmp	mkaltrom		; make ALT-ROM set

atdgf1b:
;	cmp	ninter,0		; ESC 1? (Special enter Tek mode)
;	jne	atdgf1c			; ne = some, not ESC 1
;	cmp	nparam,0
;	jne	atdgf1c			; ne = some, not ESC 1
;	jmp	atff1			; treat the same as ESC ^L
atdgf1c:ret

atdgft:	call	atdgset			; '>' Dec Technical Set
	jc	atdgft1			; c = no matching pointer
	cmp	inter,'+'		; in the 94 byte set?
	ja	atdgft1			; a = no
	jmp	mkdectech		; make DEC Tech set

atdgft1:cmp	ninter,0		; ESC > DECKNPNM set numeric keypad?
	jne	atdgft2			; ne = no
	and	vtemu.vtflgop,not deckpam ; turn off application keypad bit
atdgft2:ret				;  (to numeric)
					; '<' User Preferred Supplemental Set
atdgfu:	call	atdgset			; get set pointer
	jc	atdgfu2			; c = no matching pointer
	test	flags.vtflg,ttvt220	; in VT220 mode?
	jnz	atdgfu1b		; nz = yes, force DEC Supplemental
; DEC VT320's ignore the set size designator when picking UPSS sets here
	cmp	word ptr upss+1,0+'A'	; is ISO Latin-1 the preferred set?
	jne	atdgfu0a		; ne = no
	jmp	mklatin1		; make Latin1 set
atdgfu0a:cmp	word ptr upss+1,0+'H'	; is Hebrew-ISO preferred?
	jne	atdgfu1			; ne = no
	jmp	mklatin_Hebrew		; make Hebrew-ISO

atdgfu1:cmp	word ptr upss+1,'5%'	; DEC Supplemental Graphics?
	jne	atdgfu1a		; ne = no
atdgfu1b:jmp	mkdecmn			; make DEC Multinat/Supp Graphics
atdgfu1a:cmp	word ptr upss+1,'4"'	; DEC Hebrew?
	jne	atdgfu2
	jmp	mkdec_Hebrew		; make DEC Hebrew 
atdgfu2:ret

atdgfq:	call	atdgset			; '?' Transparent
	jc	atdgfu2			; c = no matching pointer
	jmp	mkxparent		; make transparent table

					; ESC <...> <1-8>  series
atsdhl:	cmp	ninter,1		; just one intermediate?
	jne	atsdh0			; ne = no
	cmp	inter,'#'		; this intermediate?
	jne	atdgnrc			; ne = no, try NRC char set designator
	cmp	al,'3'			; Double high lines. Top half?
	je	atsdh2			; e = yes
	cmp	al,'4'			; bottom half?
	je	atsdh2			; e = yes
	cmp	al,'5'			; restore line to single width?
	je	atsdh1			; e = yes
	cmp	al,'6'			; double width single height?
	je	atsdh2			; e = yes
	cmp	al,'8'			; screen alignment?
	je	atsdh8			; e = yes
atsdhx:	ret				; else ignore

atsdh1:	jmp	linesgl			; set line to single width
atsdh2:	jmp	linedbl			; expand the line to double width
atsdh8:	jmp	atalign			; do screen alignment

atsdh0:	cmp	ninter,0		; zero intermediates?
	jne	atdgf5			; ne = no, try for more
	cmp	al,'7'			; save cursor?
	jne	atsdh0a			; ne = no
	jmp	atsc			; do save cursor, ESC 7
atsdh0a:cmp	al,'8'			; restore cursor?
	jne	atsdh0b			; ne = no
	jmp	atrc			; do restore cursor, ESC 8
atsdh0b:ret

atdgf5:	cmp	ninter,2		; two intermediates?
	jne	atdgf5a			; ne = no, ignore remainder
	cmp	al,'6'			; '%6' NRC designator?
	je	atdgnrc			; e = yes, do that above
	cmp	al,'5'			; '%5' DEC Supplemental Graphic?
	jne	atdgf5a			; ne = no
	cmp	inter,'+'		; in the 94 byte set?
	ja	atdgf5a			; a = no, ignore
	cmp	inter[1],'%'		; '%5'?
	jne	atdgf5a			; ne = no
	mov	ninter,1		; help atdgset find our set
	call	atdgset			; get set pointer
	jc	atdgf5a			; c = no matching pointer
	jmp	mkdecmn			; make DEC Multinat/Supp Gr
atdgf5a:ret

; Enter with Final esc char in al, others in array inter. Setup Gn if success.
atdgnrc	proc	near			; check for NRC set designator
	cmp	ninter,0		; ESC Z?
	jne	atdgnr1			; ne = no
	cmp	al,'Z'			; the Z?
	jne	atdgnrx			; ne = not ESC Z
	jmp	atda			; process ident request
atdgnr1:cmp	inter,'+'		; in the 94 byte set?
	ja	atdgnrx			; a = no, ignore
	call	findctry		; find NRC country number in CX
	jc	atdgnrx			; c = not found, ignore
	mov	ninter,1		; help atdgset find our set
	call	atdgset			; check for Gn designator
	jc	atdgnrx			; c = not found
	jmp	mknrc			; make NRC set
atdgnrx:ret				; ignore
atdgnrc	endp

; Find NRC country number, putting it into CX, given Final char in AL and
; intermediates in array inter. Return carry set if not found.
findctry proc	near
	cmp	ninter,2		; second intermediate (%)?
	jb	findct1			; b = no
	ja	findct3			; a = three or more, no match
	mov	ah,inter+1		; get NRC intermediate
	cmp	ax,'%6'			; Portugese NRC?
	jne	findct4			; ne = no, try Hebrew
	mov	cx,9			; Portuguese NRC is number 9
	clc
	ret
findct4:cmp	ax,'%='			; Hebrew NRC?
	jne	findct3			; ne = no, fail
	mov	cx,13			; Hebrew NRC is number 13
	clc
	ret
findct1:cmp	ninter,0		; no intermediate?
	je	findct3			; e = yes, no designator, fail
	mov	cx,nrcflen		; number of NRC letters to consider
	cld
	push	di			; save regs
	push	es
	push	ds
	pop	es
	mov	di,offset nrcfinal	; list of NRC final chars
	repne	scasb			; look for a match
	pop	es			; recover reg
	jne	findct2			; ne = failed
	dec	di			; compenstate for auto-inc
	sub	di,offset nrcfinal	; get distance covered
	mov	cl,nrcnum[di]		; country number from parallel list
	xor	ch,ch			; return number in CX
	pop	di
	clc				; success
	ret
findct2:pop	di			; carry set = failure
findct3:stc
	ret
findctry endp

; Worker for atdgf routines. Return setptr looking at Gnset (n=0..3) and
; carry clear, based on ninter=1, inter = Gn designator. Carry set if fail.
; Modifies AL
atdgset	proc	near
	cmp	ninter,1		; one intermediate?
	jne	atdgsex			; ne = no, ignore
	mov	al,inter		; inter, from parser
	cmp	al,'('			; 94 char sets, designate G0?
	je	atdgse0			; e = yes
	cmp	al,')'			; G1?
	je	atdgse1
	cmp	al,'*'			; G2?
	je	atdgse2
	cmp	al,'+'			; G3?
	je	atdgse3
	cmp	al,'-'			; 96 char sets, designate G1?
	je	atdgse1
	cmp	al,'.'			; G2?
	je	atdgse2
	cmp	al,'/'			; G3?
	je	atdgse3
atdgsex:stc				; carry set for failure
	ret
atdgse0:mov	setptr,offset G0set	; designate G0 set
	clc
	ret
atdgse1:mov	setptr,offset G1set	; designate G1 set
	clc
	ret
atdgse2:mov	setptr,offset G2set	; designate G2 set
	clc
	ret
atdgse3:mov	setptr,offset G3set	; designate G3 set
	clc
	ret
atdgset endp
					; S7C1T/S8C1T select 7/8-bit controls
ats7c:	test	flags.vtflg,ttvt320+ttvt220 ; in VT320/VT220 mode?
	jz	atdgsex			; z = no, ignore command
	cmp	ninter,1		; one intermediate?
	jne	ats7ca			; ne = no
	cmp	inter,' '		; proper intermediate?
	jne	ats7ca			; ne = no
	and	vtemu.vtflgop,not vscntl ; turn off 8-bit controls bit
ats7ca:ret				; done

ats8c:	cmp	inter,' '		; proper intermediate?
	jne	ats8ca			; ne = no
	cmp	ninter,1		; just one?
	jne	ats8ca			; ne = no
	or	vtemu.vtflgop,vscntl	; turn on 8-bit controls bit
ats8ca:	ret

; Designate User Preferred Supplemental Set as
;  'A' ISO Latin-1  or '%','5' DEC Supplemental Graphics, or
;  'H' Hebrew-ISO,  or '"','4' DEC-Hebrew
; Store the selection letters in array upss for later use by ESC <char> '<'
atupss:	cmp	word ptr dinter,0+'!'	; "!u" proper intermediate?
	je	atupss0			; e = yes
	mov	ninter,0		; set up atdcsnul for proper form
	jmp	atdcsnul		; consume unknown command
atupss0:mov	ah,94			; assume 94 byte set
	cmp	dparam,1		; 96 byte char size indicator?
	jb	atupss1			; b = no, 94
	ja	atupss2			; a = illegal Parameter
	mov	ah,96			; say 96
atupss1:mov	upss,ah			; store char set size
	mov	ttstateST,offset atupss4; where to go when ST has been seen
	mov	emubufc,0		; clear buffer count
	mov	ttstate,offset atupss2	; next state is get string
	ret
atupss2:mov	bx,emubufc		; count of chars in string buffer
	cmp	bx,emubufl		; too many?
	jae	atupss3			; ae = too many, ignore extras
	mov	emubuf[bx],al		; store the char
	inc	emubufc			; count it
atupss3:ret
atupss4:mov	si,emubufc		; count of chars in string
	mov	emubuf[si],0		; terminate string in null
	mov	ax,word ptr emubuf	; copy two chars from string to
	mov	word ptr upss+1,ax	;  upss char set ident storage area
	mov	emubufc,0		; clear the string count
	ret

; Select/map character sets
atls0:	test	flags.vtflg,ttansi	; ANSI-BBS?
	jnz	atlsx			; nz = yes, avoid BBS stupidities
	mov	GLptr,offset G0set	; LS0,  map G0 char set into GLeft
	ret				; Control-O
atls1:	test	flags.vtflg,ttansi	; ANSI-BBS?
	jnz	atlsx			; nz = yes, avoid BBS stupidities
	mov	GLptr,offset G1set	; LS1,  map G1 char set into GLeft
	ret				; Control-N
atls1r:	cmp	ninter,0		; any intermediate chars?
	jne	atlsx			; ne = yes, not a Locking Shift
	mov	GRptr,offset G1set	; LS1R, map G1 char set into GRight
	ret
atss2:	cmp	ninter,0		; any intermediate chars?
	jne	atlsx			; ne = yes, not a Single Shift
	mov	SSptr,offset G2set	; SS2,  use G2 for next graphics only
	ret
atls2:	cmp	ninter,0		; any intermediate chars?
	jne	atlsx			; ne = yes, not a Locking Shift
	mov	GLptr,offset G2set	; LS2,  map G2 char set into GLeft
	ret
atls2r:	cmp	ninter,0		; any intermediate chars?
	jne	atlsx			; ne = yes, not a Locking Shift
	mov	GRptr,offset G2set	; LS2R, map G2 char set into GRight
	ret
atss3:	cmp	ninter,0		; any intermediate chars?
	jne	atlsx			; ne = yes, not a Single Shift
	mov	SSptr,offset G3set	; SS3,  use G3 for next graphics only
	ret
atls3:	cmp	ninter,0		; any intermediate chars?
	jne	atlsx			; ne = yes, not a Locking Shift
	mov	GLptr,offset G3set	; LS3,  map G3 char set into GLeft
	ret
atls3r:	cmp	ninter,0		; any intermediate chars?
	jne	atlsx			; ne = yes, not a Locking Shift
	mov	GRptr,offset G3set	; LS3R, map G3 char set into GRight
atlsx:	ret


; Routine to set default character set.
chrdef	proc	near
  	mov	GLptr,offset G0set	; map G0 set to GLeft
	mov	GRptr,offset G2set	; map G2 set to GRight
	mov	SSptr,0			; clear single shift
	mov	bx,offset emubuf	; temp table of char set idents
	mov	word ptr [bx],C_ASCII	; G0 and G1 to ASCII
	mov	al,vtemu.vtchset	; user specifed char set for GL
	mov	byte ptr [bx+2],al	; set G2 and G3 to user selected set
	mov	byte ptr [bx+3],al
	cmp	al,C_SHORT_KOI		; Short KOI?
	jne	chrdef0b		; ne = no
	mov	byte ptr [bx],al	; force into all sets, as if an NRC
	mov	byte ptr [bx+1],al
chrdef0b:test	flags.vtflg,ttvt320+ttvt220
	jnz	chrdef1			; nz = yes, 8-bit terminals
	mov	GRptr,offset G1set	; map G1 set to GRight
	mov	byte ptr [bx+1],C_DECTECH ; assume Dec Special Graphics in G1
	test	flags.vtflg,ttansi	; ANSI-BBS?
	jz	chrdef0a		; z = no
	mov	byte ptr [bx+1],C_XPARENT ; set TRANSPARENT
	jmp	short chrdef1
chrdef0a:test	flags.vtflg,ttwyse	; Wyse-50?
	jz	chrdef1			; z = no
	mov	byte ptr [bx+1],C_WYSEGR ; Wyse-50 graphics to G1

chrdef1:cmp     vtemu.vtchset,C_JISKANJI        ;[HF] JIS-Kanji?
        jne     chrdef1a                        ;[HF] ne = no
        mov     byte ptr [bx+2],C_JISKAT        ;[HF] G2 = JIS-Katakana
        mov     byte ptr [bx+3],al              ;[HF] G3 = JIS-Kanji
        mov     GRptr,offset G3set              ;[HF] GR = G3 (as VT382)
        jmp     short chrdef2                   ;[HF]
chrdef1a:test   vtemu.vtflgop,vsnrcm    ; doing National Replacement Chars?
	jz	chrdef2			; z = no
	mov	al,vtemu.vtchset	; get country number
	mov	dgkbl,al		; keyboard language
	cmp	al,C_DHEBNRC		; max NRC country
	ja	chrdef2			; a = out of bounds, ignore
	and	vtemu.vtflgop,not vscntl ; turn off 8-bit controls
	mov	ah,al			; country number 1..12
	mov	[bx],al			; set G0
	test	flags.vtflg,ttd463+ttd470+ttd217 ; DG D463/D470/D217 mode?
	jnz	chrdef2			; nz = yes, don't touch G1..G3 here
	mov	[bx+1],ah
	mov	word ptr [bx],ax	; same char set in G0..G3
	mov	word ptr [bx+2],ax

chrdef2:test	flags.vtflg,ttd463+ttd470+ttd217 ; DG D463/D470/D217 mode?
	jz	chrdef5			; z = no (should have all cases now)
	mov	al,C_DGINT		; D463/D470 DG International to G1
	test	flags.remflg,d8bit	; 8 bit mode?
	jnz	chrdef4			; nz = yes
chrdef3:mov	al,C_DGWP		; D463/D470 DG Word Processing to G1
chrdef4:mov	[bx+1],al		; D463/D470 G1 default
	mov	dgkbl,al		; DG keyboard language
	mov	vtemu.vtchset,al
	mov	ah,[bx]			; G0
	or	ah,ah			; using NRCs?
	jz	chrdef5			; z = no
	mov	dgkbl,ah		; yes, state NRC in use for kbd
	jmp	short chrdef5

chrdef5:call	chrsetup		; worker to setup G0..G3
					; do table of Gn overrides
	mov	bx,offset vtemu.vttable	; table of char set overrides
chrdef6:call    chrsetup                ; worker to setup G0..G3
	ret
chrdef	endp

; Load G0..G3 with character sets whose idents (0..24) are in byte array 
; pointed to by BX. Update Gsetid with those byte idents enroute.
chrsetup proc	near
	push	ninter			; preserve these
	mov	ch,inter
	push	cx			; save them
	mov	ninter,1		; one intermediate
	mov	inter,'('		; init inter for atdgset
	xor	cx,cx			; count sets from 0
chrset1:push	cx			; save loop counter
	push	bx
	call	atdgset			; get setptr = offset Gnset (n=0..3)
	mov	al,[bx]			; get char set ident from 4 byte list
	cmp	al,0ffh			; none?
	je	chrset90		; e = none
	mov	bx,cx			; update Gsetid table with set ident
	mov	Gsetid[bx],al
	cmp	al,C_ASCII		; ASCII (0)?
	jne	chrset13		; ne = no
	call	mkascii			; make ASCII
	jmp	chrset90

chrset13:cmp	al,C_DHEBNRC		; in NRC's?
	ja	chrset14      		; a = no
	mov	cl,al			; put country number in cx
	xor	ch,ch
	call	mknrc			; setup an NRC, using cx and setptr
	jmp	chrset90

chrset14:cmp	al,C_ALTROM		; want ALT-ROM?
	jne	chrset15		; ne = no
	call	mkaltrom		; do ALT-ROM setup
	jmp	chrset90

chrset15:cmp	al,C_XPARENT		; Transparent (15)?
	jne	chrset16		; ne = no
	call	mkxparent		; do Transparent setup
	jmp	chrset90

chrset16:cmp	al,C_LATIN1		; Latin1 (16)?
	jne	chrset17
	cmp	setptr,offset G0set	; want 96 byte set in G0?
	je	chrset90		; e = yes, can not do this
	call	mklatin1		; make Latin1
	jmp	chrset90

chrset17:cmp	al,C_DMULTINAT		; DEC-MCS (17)?
	jne	chrset18		; ne = no
	call	mkdecmn			; make DEC Supplement Graph (DEC-MCS)
	jmp	chrset90

chrset18:cmp	al,C_DECTECH		; DEC-Technical (18)?
	jne	chrset19		; ne = no
	call	mkdectech		; make DEC Technical
	jmp	chrset90

chrset19:cmp	al,C_DECSPEC		; DEC-Special-Graphics?
	jne	chrset20		; ne = no
	call	mkdecspec		; make DEC Special Graphics
	jmp	chrset90

chrset20:cmp	al,C_DGINT		; DG International?
	jne	chrset21		; ne = no
	call	mkdgint			; make DG International
	jmp	short chrset90

chrset21:cmp	al,C_DGLINE		; DG Line Drawing?
	jne	chrset22		; ne = no
	call	mkdgld			; make DG line drawing
	jmp	short chrset90

chrset22:cmp	al,C_DGWP		; DG Word Processing?
	jne	chrset23		; ne = no
	call	mkdgwp			; make DG Word Procssing
	jmp	short chrset90
	
chrset23:cmp	al,C_LATIN2		; Latin2/CP852?
	jne	chrset24		; ne = no
	call	mklatin2
	jmp	short chrset90

chrset24:cmp	al,C_HEBREWISO		; Hebrew-ISO (CP862)?
	jne	chrset26		; ne = no
	call	mklatin_hebrew
	jmp	short chrset90

chrset26:cmp	al,C_WYSEGR		; Wyse-50 graphics chars?
	jne	chrset27		; ne = no
	call	mkwyse
	jmp	short chrset90

chrset27:cmp	al,C_HPROMAN8		; HP-Roman8?
	jne	chrset28		; ne = no
	call	mkhpr8
	jmp	short chrset90

chrset28:cmp	al,C_CYRILLIC_ISO	; Cyrillic to CP866?
	jne	chrset29		; ne = no
	call	mkcyiso
	jmp	short chrset90

chrset29:cmp	al,C_KOI8		; Cyrillic KOI8 to CP866?
	jne	chrset30		; ne = no
	call	mkkoi8
	jmp	short chrset90

chrset30:cmp	al,C_SHORT_KOI		; Cyrillic Short-KOI to CP866?
	jne	chrsetj13		; ne = no
	call	mkkoi7
	jmp	short chrset90


chrsetj13:cmp   al,C_JISKAT             ; [HF] JIS-Katakana?
        jne     chrsetj87               ; [HF] ne = no
        call    mkjiskana               ; [HF]
        jmp     short chrset90          ; [HF]

chrsetj87:cmp	al,C_JISKANJI		; [HF] JIS-Kanji?
	jne	chrset100		; [HF] ne = no
	call	mkjiskanji		; [HF]
	jmp	short chrset90		; [HF]

chrset100:cmp	al,100+1		; possible DG soft set?
	jb	chrset90		; ne = no
	cmp	al,100+31		; in range of soft sets?
	ja	chrset90		; a = no
	test	flags.vtflg,ttd463+ttd470+ttd217 ; DG D463/D470/D217 mode?
	jz	chrset90		; z = no
	call	mkdgsoft		; do it (softset # + 100+1 is in al)

chrset90:pop	bx
	pop	cx
	inc	bx			; next byte of table
	inc	inter			; next set pointer
	inc	cx
	cmp	cx,4			; done all sets?
	jae	chrset92		; ae = yes
	jmp	chrset1			; b = no (counting sets as 0..3)
chrset92:pop	cx			; recover saved parsing items
	mov	inter,cl		; restore
	pop	ninter			; this too
	ret
chrsetup endp

; Make Data General International to Gn table. 
; Enter with destination in setptr
mkdgint	proc	near
	push	si
	push	di
	push	es
	mov	di,setptr
	mov	al,[di+gsize+3+1]	; get Gn number (0..3)
	xor	ah,ah
	mov	si,ax
	mov	Gsetid[si],C_DGINT	; store our char set ident
	mov	ax,ds
	mov	es,ax
	PUSH	DS
	call	flatin1		; get DS:BX to Code Page dependent Latin1
	mov	si,bx
	cld
	push	di
	mov	cx,gsize		; gsize chars
	rep	movsb			; copy appropriate Latin1 xlat table
	pop	di
	mov	cx,dgi2len		; number of new chars
	mov	si,offset dgi2lat	; source of chars to be translated
	add	di,20h			; where new chars start

mkdgin1:PUSH	DS
	mov	ax,seg dgi2lat
	mov	ds,ax
	lodsb				; read Latin1 code point from dgi2lat
	POP	DS
	cmp	al,80h			; "?" unknown indicator or ASCII?
	jb	mkdgin2			; b = yes, reproduce it literally
	sub	al,80h			; map down to indexable value
	xlatb				; translate through Latin1 table
mkdgin2:stosb				; store in active table
	loop	mkdgin1			; do all necessary
	POP	DS
	mov	di,setptr
	mov	byte ptr[di+gsize],94	; say this is a 94 byte set
	mov	word ptr[di+gsize+1],'ID' ; set ident code
	mov	byte ptr[di+gsize+3],0	; say hard char set
	pop	es
	pop	di
	pop	si
	call	invcopy			; create keyboard table by inversion
	ret
mkdgint	endp

; Make Data General line drawing graphics to Gn table. 
; Enter with destination in setptr
mkdgld	proc	near
	push	si
	push	di
	mov	di,setptr
	mov	al,[di+gsize+3+1]		; get Gn number (0..3)
	xor	ah,ah
	mov	si,ax
	mov	Gsetid[si],C_DGLINE		; store our char set ident
	mov	cx,gsize		; first fill with spaces
	mov	al,20h
	push	es
	push	ds
	pop	es
	push	di			; save starting location
	cld
	rep	stosb			; spaces
	pop	di
	add	di,20h			; where new chars start
	mov	si,offset dgldc		; replacement chars
	mov	cx,dgldclen		; number of new chars
	rep	movsb			; copy them to the table
	mov	di,setptr
	mov	byte ptr[di+gsize],94	; say this is a 94 byte set
	mov	word ptr[di+gsize+1],'LD' ; set ident code
	mov	byte ptr[di+gsize+3],0	; say hard char set
	pop	es
	pop	di
	pop	si
	call	invcopy			; create keyboard table by inversion
	ret
mkdgld	endp

; Make Data General word processing to Gn table. 
; Enter with destination in setptr
mkdgwp	proc	near
	push	si
	push	di
	mov	di,setptr
	mov	al,[di+gsize+3+1]		; get Gn number (0..3)
	xor	ah,ah
	mov	si,ax
	mov	Gsetid[si],C_DGWP	; store our char set ident
	mov	cx,gsize		; first fill with spaces
	mov	al,20h
	push	es
	push	ds
	pop	es
	push	di			; save starting location
	cld
	rep	stosb			; spaces
	pop	di
	add	di,20h			; where new chars start
	mov	si,offset dgwpcp437	; replacement chars
	mov	cx,dgwplen		; number of new chars
	push	ds
	mov	ax,seg dgwpcp437
	mov	ds,ax
	rep	movsb			; copy them to the table
	pop	ds
	mov	di,setptr
	mov	byte ptr[di+gsize],94	; say this is a 94 byte set
	mov	word ptr[di+gsize+1],'WD' ; set ident code
	mov	byte ptr[di+gsize+3],0	; say hard char set
	pop	es
	pop	di
	pop	si
	call	invcopy			; create keyboard table by inversion
	ret
mkdgwp	endp

; Make Data General soft set to Gn table. 
; Enter with destination in setptr, reg AL holding 100d + softset-20h+1
mkdgsoft proc	near
	push	ax
	call	mkascii
	pop	ax
ifndef	no_graphics
	push	ax
	call	mksoftspace		; create space for soft set, uses AL
	pop	ax
	jnc	mkdgsoft1		; nc = got the memory
	ret				; c = failed, use ASCII
endif	; no_graphics
mkdgsoft1:push	bx
	mov	bx,setptr
	mov	byte ptr[bx+gsize],94	; say this is a 94 byte set
	mov	word ptr[bx+gsize+1],'UD' ; set ident code
	mov	byte ptr[bx+gsize+3],al	; say hard char set (101..131)
	mov	bl,[bx+gsize+3+1]	; get Gn number (0..3)
	xor	bh,bh
	mov	Gsetid[bx],al		; store our char set ident
	pop	bx
	call	invcopy			; create keyboard table by inversion
	ret
mkdgsoft endp

; Make DEC Alt-ROM to Gn table.
; Enter with destination in setptr
mkaltrom proc	near
	call	mkascii			; init set to ASCII
	push	si
	push	di
	push	es
	push	ds
	pop	es			; point es at data segment
	mov	di,setptr
	mov	al,[di+gsize+3+1]	; get Gn number (0..3)
	xor	ah,ah
	mov	si,ax
	mov	Gsetid[si],C_ALTROM	; store our char set ident
	add	di,60h			; replace a..z with 20h + (a..z)
	mov	si,di			; special graphics table
	mov	cx,27			; number of chars to do (a..z)
	cld
decalt1:lodsb				; get a char
	add	al,20h			; map up by 20h
	stosb
	loop	decalt1
	mov	di,setptr
	mov	byte ptr[di+gsize],96	; say this is a 96 byte set
	mov	word ptr[di+gsize+1],0+'1' ; set ident code
	mov	byte ptr[di+gsize+3],0	; say hard char set
	pop	es
	pop	di
	pop	si
	call	invcopy			; create keyboard table by inversion
	ret
mkaltrom endp

; Make DEC special graphics to Gn table.
; Enter with destination in setptr
mkdecspec proc	near
	call	mkascii			; init set to ASCII
	push	si
	push	di
	mov	di,setptr
	mov	al,[di+gsize+3+1]	; get Gn number (0..3)
	xor	ah,ah
	mov	si,ax
	mov	Gsetid[si],C_DECSPEC	; store our char set ident
	add	di,95			; replace chars 95-126
	mov	si,offset sgrtab	; use DEC special graphics table
	mov	cx,sgrtabl		; table length
	test	flags.vtflg,ttheath	; Heath rather than VT?
	jz	mkdecsp1		; z = no
	mov	si,offset hgrtab	; use Heath table
	mov	cx,hgrtabl
	dec	di			; work from 94 rather than 95
mkdecsp1:push	es
	push	ds
	pop	es
	push	ds
	mov	ax,seg sgrtab
	mov	ds,ax
	cld
	rep	movsb			; replace chars with sgrtab items
	pop	ds
	mov	di,setptr
	mov	byte ptr[di+gsize],94	; say this is a 94 byte set
	mov	word ptr[di+gsize+1],0+'0' ; set ident code
	mov	byte ptr[di+gsize+3],0	; say hard char set
	pop	es
	pop	di
	pop	si
	call	invcopy			; create keyboard table by inversion
	clc
	ret
mkdecspec endp

; Make Dec Technical to Gn table
; Enter with destination in setptr
mkdectech proc	near
	push	si
	push	di
	mov	di,setptr
	mov	al,[di+gsize+3+1]	; get Gn number (0..3)
	xor	ah,ah
	mov	si,ax
	mov	Gsetid[si],C_DECTECH	; store our char set ident
	push	es
	push	ds
	pop	es
	cld
	mov	cx,gsize+3+1		; gsize chars plus three ident bytes
	mov	di,setptr		; destination
	mov	si,offset dectech	; source data
	push	ds
	mov	ax,seg dectech
	mov	ds,ax
	rep	movsb
	pop	ds
	pop	es
	mov	di,setptr
	mov	byte ptr[di+gsize],94	; say this is a 96 byte set
	mov	word ptr[di+gsize+1],0+'>' ; set ident code
	mov	byte ptr[di+gsize+3],0	; say hard char set
	pop	di
	pop	si
	call	invcopy			; create keyboard table by inversion
	clc
	ret
mkdectech endp

; Make Cyrillic_ISO to CP866
; Enter with destination in setptr
mkcyiso proc	near
	push	si
	push	di
	mov	di,setptr
	mov	al,[di+gsize+3+1]	; get Gn number (0..3)
	xor	ah,ah
	mov	si,ax
	mov	Gsetid[si],C_CYRILLIC_ISO ; store our char set ident
	push	es
	push	ds
	pop	es
	cld
	mov	cx,gsize+3+1		; gsize chars plus three ident bytes
	mov	di,setptr		; destination
	mov	si,offset lccp866r	; source data
	push	ds
	mov	ax,seg lccp866r
	mov	ds,ax
	rep	movsb
	pop	ds
	pop	es
	mov	di,setptr
	mov	byte ptr[di+gsize],96	; say this is a 96 byte set
	mov	word ptr[di+gsize+1],'CI' ; set ident code
	mov	byte ptr[di+gsize+3],0	; say hard char set
	push	es
	mov	cx,gsize
	mov	di,seg cp866lci
	mov	es,di
	mov	di,offset cp866lci
	call	tblcopy			; create keyboard table
	pop	es
	pop	di
	pop	si
	clc
	ret
mkcyiso endp

; Make Cyrillic KOI8 to CP866
; Enter with destination in setptr
mkkoi8 proc	near
	push	si
	push	di
	mov	di,setptr
	mov	al,[di+gsize+3+1]	; get Gn number (0..3)
	xor	ah,ah
	mov	si,ax
	mov	Gsetid[si],C_KOI8	; store our char set ident
	push	es
	push	ds
	pop	es
	cld
	mov	cx,gsize+3+1		; gsize chars plus three ident bytes
	mov	di,setptr		; destination
	mov	si,offset k8cp866r	; source data
	push	ds
	mov	ax,seg k8cp866r
	mov	ds,ax
	rep	movsb
	pop	ds
	pop	es
	mov	di,setptr
	mov	byte ptr[di+gsize],96	; say this is a 96 byte set
	mov	word ptr[di+gsize+1],'CK' ; set ident code
	mov	byte ptr[di+gsize+3],0	; say hard char set
	push	es
	mov	cx,gsize
	mov	di,seg cp866koi8
	mov	es,di
	mov	di,offset cp866koi8
	call	tblcopy			; create keyboard table
	pop	es
	pop	di
	pop	si
	clc
	ret
mkkoi8 endp

; Make Short-KOI (7 bit) to CP866
; Enter with destination in setptr
mkkoi7 proc	near
	push	si
	push	di
	mov	di,setptr
	mov	al,[di+gsize+3+1]	; get Gn number (0..3)
	xor	ah,ah
	mov	si,ax
	mov	Gsetid[si],C_SHORT_KOI	; store our char set ident
	push	es
	push	ds
	pop	es
	cld
	mov	cx,gsize+3+1		; gsize chars plus three ident bytes
	mov	di,setptr		; destination
	mov	si,offset k7cp866r	; source data
	push	ds
	mov	ax,seg k7cp866r
	mov	ds,ax
	rep	movsb
	pop	ds
	pop	es
	mov	di,setptr
	mov	byte ptr[di+gsize],94	; say this is a 94 byte set
	mov	word ptr[di+gsize+1],'CS' ; set ident code
	mov	byte ptr[di+gsize+3],0	; say hard char set
	push	es
	mov	cx,gsize
	mov	di,seg cp866koi7
	mov	es,di
	mov	di,offset cp866koi7
	call	tblcopy			; create keyboard table
	pop	es
	pop	di
	pop	si
	clc
	ret
mkkoi7 endp

; Make Heath-19 special graphics to Gn table. Enter with dest of setptr.

; Initialize a char set to ASCII values 0..127 and ident of 94/B
; Enter with setptr holding offset of G0set, G1set, G2set, or G3set char set
mkascii	proc	near
	push	ax
	push	cx
	push	di
	push	es
	mov	di,setptr		; char set to init (G0..G3)
	mov	al,[di+gsize+3+1]	; get Gn number (0..3)
	xor	ah,ah
	mov	si,ax
	mov	Gsetid[si],C_ASCII	; store our char set ident
	mov	cx,gsize		; number of bytes to do
	xor	al,al			; initial value
	push	ds
	pop	es			; set es to data segment
	cld
mkascii1:stosb				; copy value to char set table
	inc	al
	loop	mkascii1
	mov	di,setptr
	mov	byte ptr[di+gsize],94	; say this is a 94 byte set
	mov	word ptr[di+gsize+1],0+'B' ; set ident code to ASCII "B"
	mov	byte ptr[di+gsize+3],0	; say hard char set
	pop	es
	pop	di
	pop	cx
	pop	ax
	call	invcopy			; create keyboard table by inversion
	ret
mkascii	endp

; Make UK ASCII to table Gn
; Enter with destination in setptr
mkukascii proc	near
	call	mkascii			; make US ASCII table
	push	di
	mov	di,setptr		; get set pointer
	mov	al,[di+gsize+3+1]	; get Gn number (0..3)
	xor	ah,ah
	mov	si,ax
	mov	Gsetid[si],C_UKNRC	; store our char set ident
	mov	byte ptr[di+23h],156	; replace sharp 2/3 with Sterling sign
	mov	byte ptr[di+gsize],94	; say this is a 94 byte set
	mov	word ptr[di+gsize+1],0+'A' ; set ident code
	mov	byte ptr[di+gsize+3],0	; say hard char set
	pop	di
	call	invcopy			; create keyboard table by inversion
	ret
mkukascii endp

; Make DEC Multinational Char Set (DEC-MCS/DEC Supplemental Graphics)
; and put into Gn table indicated by AL = 0..3
; Enter with destination in setptr
mkdecmn	proc	near
	push	si
	push	di
	mov	di,setptr		; get set pointer
	mov	al,[di+gsize+3+1]	; get Gn number (0..3)
	xor	ah,ah
	mov	si,ax
	mov	Gsetid[si],C_DMULTINAT ; store our char set ident
	push	es
	mov	ax,seg G0set		; segment of Gn's
	mov	es,ax
	PUSH	DS
	call	flatin1			; get Latin1 to DS:BX
	mov	si,bx
	cld
	mov	cx,gsize+3+1		; gsize chars plus three ident bytes
	rep	movsb
	POP	DS
	mov	di,setptr
	mov	al,[di+24h]		; 10/4 Latin1 (currency) to
	mov	[di+28h],al		; 10/8 DEC-MCS
	mov	byte ptr [di+57h],3fh 	; 13/7 OE to ?
	mov	al,[di+7fh]		; 15/15 Latin1 (lower y umlate) to
	mov	[di+7dh],al		; 15/13 DEC-MCS
	mov	cx,13			; number of updates
	xor	bh,bh
	mov	ax,seg MNlatin
	mov	es,ax
	mov	si,offset MNlatin	; get update table
mkdecmn1:mov	bl,es:[si]		; get Latin1 code point to be changed
	and	bl,not 80h		; map down to 0..127 range
	mov	byte ptr [di+bx],20h	; store new value (space)
	inc	si
	loop	mkdecmn1
	pop	es
	mov	di,setptr
	mov	byte ptr[di+gsize],96	; say this is a 96 byte set
	mov	word ptr[di+gsize+1],'5%' ; set ident code
	mov	byte ptr[di+gsize+3],0	; say hard char set
	pop	di
	pop	si
	call	invcopy			; create keyboard table by inversion
	ret
mkdecmn	endp

;[HF] Put JIS Katakana char set (128..255) into Gn table.
;[HF] Enter with destination in setptr
mkjiskana proc	near
	call	mkascii			; init set to ASCII
	push	si
	push	di
	mov	di,setptr		; point at character set
	mov	al,[di+gsize+3+1]	; get Gn number (0..3)
	xor	ah,ah
	mov	si,ax
	mov	Gsetid[si],C_JISKAT	; store our char set ident
	add	di,33		;[HF]941227 start position
	mov	cx,63		;[HF]941227 number of chars to do (16 x 4 - 1)
	mov	al,(33+128)	;[HF]941227 start with 8th bit on
	cld
	push	es
	push	ds
	pop	es			; point es at data segment
mkjiskana2:stosb			; store codes 128..223
	inc	al
	loop	mkjiskana2
	mov	di,setptr
	mov	byte ptr[di+gsize],94	; say this is a 94 byte set
	mov	word ptr[di+gsize+1],0+'I' ; set ident code
	mov	byte ptr[di+gsize+3],0	; say hard char set
	pop	es
	pop	di
	pop	si
	call	invcopy			; create keyboard table by inversion
	ret
mkjiskana endp

; [HF] Construct JIS-Kanji table to Gn table.
; [HF] Enter with destination in setptr
; [HF] Actually, because the JIS-Kanji set is double byte charater set,
; [HF] this procedure simply sets only the ident code.
; [HF] Actual translation is done by (f)jpnxtof.
mkjiskanji proc	near
	push	si			; [HF]
	push	di			; [HF]
	mov	di,setptr		; [HF]
	mov	al,[di+gsize+3+1]	; [HF] get Gn number (0..3)
	xor	ah,ah			; [HF] clear high byte
	mov	si,ax			; [HF] set SI reg.
	mov	Gsetid[si],C_JISKANJI	; [HF] set our char set ident
	mov	byte ptr[di+gsize],94	; [HF] say this is 94 x 94 byte set
	mov	word ptr[di+gsize+1],'$B' ; [HF] set ident code
	pop	di			; [HF]
	pop	si			; [HF]
	call	invcopy			; create keyboard table by inversion
	ret				; [HF]
mkjiskanji endp

; Put transparent char set (128..255) into Gn table.
; Enter with destination in setptr
mkxparent proc	near
	call	mkascii			; init set to ASCII
	push	si
	push	di
	mov	di,setptr		; point at character set
	mov	al,[di+gsize+3+1]	; get Gn number (0..3)
	xor	ah,ah
	mov	si,ax
	mov	Gsetid[si],C_XPARENT	; store our char set ident
	mov	cx,gsize		; number of chars to do, 128
	cld
	mov	al,cl			; start with 128 char value
	push	es
	push	ds
	pop	es			; point es at data segment
mkxpar2:stosb				; store codes 128..255
	inc	al
	loop	mkxpar2
	mov	di,setptr
	mov	byte ptr[di+gsize],96	; say this is a 96 byte set
	mov	word ptr[di+gsize+1],0+'?' ; set ident code
	mov	byte ptr[di+gsize+3],0	; say hard char set
	pop	es
	pop	di
	pop	si
	call	invcopy			; create keyboard table by inversion
	ret
mkxparent endp

; Construct NRC table.
; Enter with destination in setptr
; and CX holding the desired country code (1..13).
mknrc	proc near
	call	mkascii			; init set to ASCII
	push	bx
	push	cx
	push	si
	push	di
	push	word ptr emubuf
	push	word ptr emubuf+2
	push	es
	mov	di,setptr
	mov	al,[di+gsize+3+1]	; get Gn number (0..3)
	xor	ah,ah
	mov	si,ax
	mov	Gsetid[si],cl		; store our char set ident
	mov	emubuf+2,cl		; local copy
	cmp	cl,13			; DEC Hebrew case?
	je	mknrc10			; e = yes
		; copy from NRC table (si) to set pointed at by di, cx chars
					;  plus 3 ident bytes at table end
	mov	word ptr emubuf,offset nrclat ; start of NRC to Latin1 table
	mov	ax,cx			; country code 1..12
	mov	bl,15			; 15 bytes per entry
	mul	bl			; distance down the table to country
	add	word ptr emubuf,ax	; point at country line
	mov	cx,12			; do 12 bytes of new chars
	push	ds
	pop	es
	cld
	PUSH	DS
	call	flatin1			; returns DS:BX = Latin1 to CPnnn
	xor	si,si
mknrc2:	mov	al,ES:nrclat[si]	; get code point to change
	xor	ah,ah
	mov	di,ES:setptr		; start of destination table
	mov	byte ptr ES:[di+gsize+3],0	; say hard char set
	add	di,ax			; destination of new char
	push	bx
	mov	bx,word ptr ES:emubuf	; ptr to country entries
	mov	al,ES:[bx+si]		; read char from NRC table
	pop	bx
	inc	si
	test	al,80h			; in GR Latin1 area?
	jz	mknrc3			; z = no, in ASCII GL area
	and	al,not 80h		; trim high bit for xlat
	xlatb	  			; translate through Latin1 Code Page
mknrc3:	stosb				; move replacement char from nrc list
	loop	mknrc2
	POP	DS

	mov	di,setptr
	test	flags.vtflg,ttd463+ttd470+ttd217 ; DG D463/D470/D217 mode?
	jz	mknrc8			; z = no
	mov	cl,emubuf+2		; country code again
	cmp	cl,3			; French NRC?
	jne	mknrc4			; ne = no
	mov	al,07fh			; apply DG French NRC patch
	jmp	short mknrc7
mknrc4:	cmp	cl,6			; Spanish NRC?
	jne	mknrc5			; ne = no
	mov	al,07fh			; apply DG Spanish NRC patch
	jmp	short mknrc7
mknrc5:	cmp	cl,7			; DG Danish/Norweigen NRC?
	jne	mknrc6			; ne = no
	mov	al,0fch			; apply DG Danish/Norweigen NRC patch
	jmp	short mknrc7
mknrc6:	cmp	cl,8			; Swiss NRC?
	jne	mknrc7			; ne = no
	mov	al,0e9h			; apply DG Swiss NRC patch
mknrc7:	and	al,not 80h
	xlatb				; push through Latin1 translation
	mov	[di+7fh],al		; new value
mknrc8:	add	di,gsize		; look at end of set, to id bytes
	movsb				; copy set size and two ident chars
	movsw
	jmp	short mknrc11

mknrc10:mov	vtcpage,862		; Hebrew NRC CP862
	mov	di,ds
	mov	es,di
	mov	di,setptr
	mov	byte ptr[di+gsize+3],0	; say hard char set
	add	di,6*16
	mov	cx,27			; number of characters
	PUSH	DS
	call	flatin1			; get SI appropriate for Code Page
	mov	si,bx			; point to Latin 1 for this code page
	add	si,6*16			; get Hebrew part of CP862
	cld
	rep	movsb
	POP	DS
mknrc11:pop	es
	pop	word ptr emubuf+2
	pop	word ptr emubuf
	pop	di
	pop	si
	pop	cx
	pop	bx
	call	invcopy			; create keyboard table by inversion
	ret
mknrc	endp
	
; Construct Latin1 table to Gn table.
; Enter with destination in setptr
mklatin1 proc	near
	push	si
	push	di
	mov	di,setptr		; destination
	mov	al,[di+gsize+3+1]	; get Gn number (0..3)
	xor	ah,ah
	mov	si,ax
	mov	Gsetid[si],C_LATIN1	; store our char set ident
	mov	cx,gsize		; bytes
	push	es
	push	ds
	pop	es
	PUSH	DS
	call	flatin1			; get DS:BX appropriate for Code Page
	mov	si,bx
	cld
	rep	movsb			; copy bytes
	POP	DS
	mov	di,setptr
	mov	byte ptr[di+gsize],96	; say this is a 96 byte set
	mov	word ptr[di+gsize+1],0+'A' ; set ident code
	mov	byte ptr[di+gsize+3],0	; say hard char set
	pop	es
	pop	di
	pop	si
	call	invcopy			; create keyboard table by inversion
	ret
mklatin1 endp

; Construct Latin2 table to Gn table.
; Enter with destination in setptr
mklatin2 proc	near
	push	si
	push	di
	mov	di,setptr		; destination
	mov	al,[di+gsize+3+1]	; get Gn number (0..3)
	xor	ah,ah
	mov	si,ax
	mov	Gsetid[si],C_LATIN2	; store our char set ident
	mov	vtcpage,852		; set emulator's CP to CP852
	mov	cx,gsize		; bytes
	push	es
	push	ds
	pop	es
	PUSH	DS
	call	flatin1			; get BX appropriate for Code Page
	mov	si,bx
	cld
	rep	movsb			; copy bytes
	POP	DS
	mov	di,setptr
	mov	byte ptr[di+gsize],96	; say this is a 96 byte set
	mov	word ptr[di+gsize+1],0+'B' ; set ident code
	mov	byte ptr[di+gsize+3],0	; say hard char set
	pop	es
	pop	di
	pop	si
	call	invcopy			; create keyboard table by inversion
	ret
mklatin2 endp

; Make DEC Hebrew (94) 8-bit Supplemental
; Same code points as Hebrew-ISO at this time
mkdec_Hebrew	proc	near
	call	mklatin_hebrew
	push	es
	push	ds
	pop	es
	mov	di,setptr
	mov	byte ptr[di+gsize],94	; say this is a 94 byte set
	mov	word ptr[di+gsize+1],'4"' ; set ident code
	pop	es
	call	invcopy			; create keyboard table by inversion
	ret
mkdec_Hebrew	endp

; Make Hebrew-ISO (96) 8-bit Supplemental to Gn pointer
; Enter with destination in setptr
; Presumes CP 862 is loaded
mklatin_Hebrew	proc	near
	push	si
	push	di
	mov	di,setptr		; destination
	mov	al,[di+gsize+3+1]	; get Gn number (0..3)
	xor	ah,ah
	mov	si,ax
	mov	Gsetid[si],C_HEBREWISO	; store our char set ident
	mov	cx,gsize		; bytes
	mov	vtcpage,862		; set emulator's CP to CP862
	push	es
	push	ds
	pop	es
	PUSH	DS
	call	flatin1			; get DS:BX appropriate for Code Page
	mov	si,bx
	cld
	rep	movsb			; copy bytes
	POP	DS
	mov	di,setptr
	mov	byte ptr[di+gsize],96	; say this is a 96 byte set
	mov	word ptr[di+gsize+1],0+'H' ; set ident code
	mov	byte ptr[di+gsize+3],0	; say hard char set
	pop	es
	pop	di
	pop	si
	call	invcopy			; create keyboard table by inversion
	ret
mklatin_Hebrew	endp


; Make HP-Roman8 to Gn table. 
; Enter with destination in setptr
mkhpr8	proc	near
	push	si
	push	di
	push	es
	mov	di,setptr
	mov	al,[di+gsize+3+1]	; get Gn number (0..3)
	xor	ah,ah
	mov	si,ax
	mov	Gsetid[si],C_HPROMAN8	; store our char set ident
	mov	ax,ds
	mov	es,ax
	PUSH	DS
	call	flatin1		; get DS:BX to Code Page dependent Latin1
	mov	si,bx
	cld
	push	di
	mov	cx,gsize		; gsize chars
	rep	movsb			; copy appropriate Latin1 xlat table
	pop	di
	add	di,20h			; where new chars start
	mov	cx,hr8L1len		; number of new chars
	mov	si,offset hr8L1	; source of chars to be translated
	push	DS
	mov	ax,seg trans
	mov	ds,ax
	cmp	trans.xchri,0		; readable (vs invertible)?
	pop	ds
	je	mkhpr81			; e = yes, do nothing
	mov	cx,ihr8L1len		; number of new chars
	mov	si,offset ihr8L1	; source of chars to be translated

mkhpr81:PUSH	DS
	mov	ax,seg ihr8L1		; same seg for readable and invertable
	mov	ds,ax
	lodsb				; read Latin1 code point from dgi2lat
	POP	DS
	cmp	al,80h			; "?" unknown indicator or ASCII?
	jb	mkhpr82			; b = yes, reproduce it literally
	sub	al,80h			; map down to indexable value
	xlatb				; translate through Latin1 table
mkhpr82:stosb				; store in active table
	loop	mkhpr81			; do all necessary
	POP	DS
	mov	di,setptr
	mov	byte ptr[di+gsize],96	; say this is a 96 byte set
	mov	word ptr[di+gsize+1],'HP' ; set ident code
	mov	byte ptr[di+gsize+3],0	; say hard char set
	pop	es
	pop	di
	pop	si
	call	invcopy			; create keyboard table by inversion
	ret
mkhpr8	endp

; Make Wyse-50 graphics character set. Enter with setptr ready.
mkwyse	proc	near
	push	si
	push	di
	push	es
	call	mkascii			; make US ASCII table
	mov	di,setptr		; get set pointer
	mov	byte ptr[di+gsize],94	; say this is a 94 byte set
	mov	word ptr[di+gsize+1],'YW' ; set ident code
	mov	byte ptr[di+gsize+3],0	; say hard char set
	mov	al,[di+gsize+3+1]	; get Gn number (0..3)
	xor	ah,ah
	mov	si,ax
	mov	Gsetid[si],C_WYSEGR	; store our char set ident
	mov	si,offset wyse_grch	; Wyse chars, from "0"
	mov	cx,16			; qty of them
	add	di,'0'			; index table
	cld
mkwyse1:lodsb				; read replacement byte
	mov	[di],al			; store new graphics char
	inc	di
	loop	mkwyse1
	pop	es
	pop	di
	pop	si
	call	invcopy			; create keyboard table by inversion
	ret
mkwyse	endp

; Get output byte in AL from keyboard raw reader and convert through active
; character set translation. Return final output byte in AL.
; Uses table xltkeytable for translation.
xltkey	proc	FAR
	cmp	al,80h			; regular ASCII key?
	jb	xltkey1			; b = yes, do not translate
	cmp	flags.xltkbd,0		; keyboard translation is off?
	jne	xltkey2			; ne = no
xltkey1:ret

xltkey2:push	bx
	mov	bx,offset xltkeytable	; translation table
	and	al,not 80h		; strip high bit to use as index
	xlatb				; table replaces high bit
	pop	bx
	ret
xltkey	endp

; Create keyboard translation table by inverse lookup of wire to screen
; table. Effective only if setptr equals GRptr.
invcopy	proc	near
	push	es
	push	ds
	pop	es
	push	di
	mov	di,setptr
	cmp	di,GRptr		; points to GR?
	jne	invcopy4		; ne = no, not our condition
	mov	si,offset xltkeytable	; output table
	mov	al,80h			; start here
	mov	cx,gsize		; loop counter
invcopy2:push	ax
	push	cx
	mov	di,GRptr		; high bit is where GR points
	mov	cx,gsize
	add	di,cx
	std
	repne	scasb			; scan looking for this code
	cld
	jne	invcopy3		; ne = not found
	inc	di			; backup to found code
	sub	di,GRptr		; minus start
	mov	ax,di
	or	al,80h			; put back high bit
	cmp	vtemu.vtchset,13	; ASCII (0) or NRC's (1-13) active?
	ja	invcopy3		; a = no
	cmp	vtemu.vtchset,0		; ASCII?
	je	invcopy3		; e = yes
	and	al,7fh			; yes, NRCs force chars to 7-bits
invcopy3:mov	[si],al			; want only lower byte
	pop	cx
	pop	ax
	inc	si
	inc	al
	loop	invcopy2
invcopy4:pop	di
	pop	es
	ret
invcopy	endp

; Copy table pointed to be es:di to xltkeytable, cx values.
; If es:di is NULL then create identity table, cx values.
tblcopy	proc	near
	push	si
	push	di
	push	es
	push	ds
	mov	si,setptr
	cmp	si,GRptr		; points to GR?
	jne	tblcopy3		; ne = no, not our condition
	mov	si,es
	mov	ax,seg xltkeytable
	mov	es,ax
	mov	ds,si
	mov	si,di
	mov	di,offset xltkeytable
	mov	ax,ds
	or	ax,si			; null pointer?
	jz	tblcopy1		; z = yes, create identity
	cld
	rep	movsb			; copy table
	jmp	short tblcopy3

tblcopy1:mov	al,80h			; create identity table 80h..cx+80h
tblcopy2:stosb
	inc	al
	loop	tblcopy2

tblcopy3:pop	ds
	pop	es
	pop	di
	pop	si
	ret
tblcopy	endp

; cursor movements
atcup:	test	dspstate,dsptype	; on VT320 status line?
	jz	atcup0			; z = no
	mov	param,0			; yes, do not change rows
atcup0:	mov	ax,param		; get row
	or	ah,ah			; too large?
	jz	atcup0a			; z = not too too large
	mov	al,200			; limit row
atcup0a:mov	dh,al			; temp row
	mov	ax,param+2		; get column
	or	ah,ah			; too large?
	jz	atcup0b			; z = not yet
	mov	al,mar_right		; limit column
	inc	al
atcup0b:mov	dl,al
	or	dh,dh			; zero row number?
	jz	atcup1			; z = yes, continue
	dec	dh			; normalize to 0,0 system
atcup1:	or	dl,dl			; ditto for column
	jz	atcup2
	dec	dl
atcup2:	test	vtemu.vtflgop,decom	; Origin mode?
	jz	atcup3			; z = no, skip this stuff
	add	dh,mar_top		; yes, it was relative to top margin
	jno	atcup2a			; if no overflow, continue
	mov	dh,byte ptr low_rgt+1	; otherwise just set to screen bottom
atcup2a:cmp	dh,mar_bot		; going below bottom margin?
	jbe	atcup3			; be = no
	mov	dh,mar_bot		; clip to bottom margin
atcup3:	mov	al,mar_right		; right margin
	cmp	dl,al			; too far to the right?
	jbe	atcup4			; ne = no
	mov	dl,al			; limit to right margin
atcup4:	mov	ah,byte ptr low_rgt+1	; last regular text line
	cmp	dh,ah			; going to 25th line?
	jbe	atcup7			; be = no
	cmp	flags.vtflg,ttheath	; emulating a Heath-19?
	je	atcup5			; e = yes
	mov	dh,ah			; VTxxx: clamp to bottom line
	jmp	short atcup7
atcup5:	inc	ah			; "25th" status line
	cmp	dh,ah			; going too far?
	ja	atcup6			; a = yes
	test	h19stat,h19l25		; Heath 25th mode line enabled?
	jnz	atcup8			; nz = yes
atcup6:	mov	dh,byte ptr cursor+1	; do not change rows
atcup7: call	atccpc			; check position
atcup8:	jmp	atsetcur		; set cursor position and return

atcuarg:mov	al,byte ptr param	; worker, get cursor movement argument
	or	al,al			; zero?
	jnz	atcua1			; nz = no
	inc	al			; default to one
atcua1: ret
					; cursor up
atcuu:	cmp	dh,byte ptr low_rgt+1	; on 25th line?
	jbe	atcuu1			; be = no
	cmp	flags.vtflg,ttansi	; emulating ANSI?
	je	atcuu1			; e = yes
	ret				; no vertical on 25th line
atcuu1:	call	atcuarg			; get cursor move up argument into al
	sub	dh,al			; compute new cursor position
	jnc	atcuu2			; nc = ok [dlk]
	xor	dh,dh			; overflow, restrict range. [dlk]
atcuu2:	call	atccic			; check indexing, ignore action in ax
	jmp	atsetcur		; set the cursor at its new position

atcud:	call	atcuarg			; cursor down
	cmp	dh,byte ptr low_rgt+1	; on 25th line now?
	jbe	atcud1			; be = no
	ret				; else leave it on status line
atcud1:	add	dh,al			; compute new cursor position
	jnc	atcud2			; nc = ok [dlk]
	mov	dh,byte ptr low_rgt+1	; default bottom [dlk]
atcud2:	call	atccic			; check indexing, ignore action in ax
	jmp	atsetcur		; set the cursor at its new position

					; Allow horiz movement on 25th line
atcuf:	call	atcuarg			; cursor forward
	add	dl,al			; compute new cursor position
	jnc	atcup3			; nc = no problem
	mov	dl,byte ptr low_rgt	; else set to right margin
	jmp	atcup3			; check/set cursor, return

atcub:	call	atcuarg			; cursor back
	sub	dl,al			; compute new cursor position
	jnc	atcub1			; nc = no problem
	xor	dl,dl			; else set to left margin
atcub1:	jmp	atcup3			; check/set cursor, return

atcha:	call	atcuarg			; absolute horizontal address
	mov	dl,al			; new column, counted from 1
	sub	dl,1			; column, count from 0 internally
	jns	atcha1			; ns = no problem
	xor	dl,dl			; else set to left margin
atcha1:	jmp	atcup3			; check/set cursor, return

atcht:	call	atcuarg			; move cursor forward # horiz tabs
	inc	dl			; next column
	mov	cl,al			; number of tabstops to locate
	xor	ch,ch
	mov	si,offset tabs		; active tabs buffer
atcht1:	cmp	dl,mar_right		; at end of line?
	jae	atcht2			; ae = yes, stop here
	call	istabs			; is dl column a tabstop?
	inc	dl			; try next column, preserves carry
	jnc	atcht1			; nc = no, find one
	loop	atcht1			; do cx tabstops
atcht2:	jmp	atcup3			; set cursor

atcva:	inc	dl			; count columns from 1 here
	mov	byte ptr param+2,dl	; set column in second parameter
	mov	param+3,0		; high byte
	jmp	atcup			; do absolute vertical positioning

atcnl:	call	atcuarg			; do # Next-Lines
	cmp	dh,byte ptr low_rgt+1	; on 25th line now?
	jbe	atcnl1			; be = no
	ret				; else leave it on status line
atcnl1:	mov	cl,al			; number to do
	xor	ch,ch
atcnl2:	push	cx
	inc	dh			; number to do
	mov	dl,mar_left
	call	atccic			; check cursor position
	call	ax			; scroll if necessary
	call	atsetcur		; set cursor, etc. and return
	pop	cx
	loop	atcnl2
	ret
atcpl:	call	atcuarg			; do # Previous-Lines
	cmp	dh,byte ptr low_rgt+1	; on 25th line now?
	jbe	atcpl1			; be = no
	ret				; else leave it on status line
atcpl1:	mov	cl,al			; number to do
	xor	ch,ch
	mov	dl,mar_left
atcpl2:	dec	dh			; do one line
	push	cx			; save counter
	call	atccic			; check cursor position
	call	ax			; scroll if necessary
	call	atsetcur		; set cursor
	pop	cx
	loop	atcpl2			; do cx times
	ret

; Screen erasure commands
					; Erase in display
ated:	cmp	ninter,0		; zero intermediates?
	je	ated0			; e = yes, else try protected mode
	ret

ated0:	cmp	lparam,0
	je	ated0a
	jmp	atedsel
ated0a:	cmp	param,0			; was arg zero?
	jne	ated1			; ne = no
	jmp	ereos			; do erase cursor to end of screen

ated1:	cmp	param,1			; was arg one?
	jne	ated2			; ne = no
	jmp	ersos			; do erase start of screen to cursor

ated2:	cmp	param,2			; was arg two?
	je	ated2a			; e = yes, erase entire screen
	ret				; else ignore
ated2a:	push	dx			; save dynamic cursor
	push	word ptr mar_top
	mov	mar_bot,dh
	mov	mar_top,0		; row of cursor
	inc	dh			; number of lines to scroll
	mov	scroll,dh
	call	atscru			; scroll them up before erasure
	pop	word ptr mar_top
	pop	dx
	call	ersos			; erase start of screen to cursor
	call	ereos			; erase cursor to end of screen
	cmp	flags.vtflg,ttansi	; ANSI-BBS terminal?
	je	ated2b			; e = yes, home the cursor
	ret
ated2b:	xor	dx,dx
	jmp	atsetcur

atedsel	proc	near			; DECSED selective erase in display
	cmp	lparam,'?'		; proper intermediate?
	jne	atedsel3		; ne = no
	mov	ax,param		; get parameter
	or	ax,ax			; 0?
	jnz	atedsel1		; nz = no
	mov	al,mar_top		; 0: erase cursor to end of screen
	mov	ah,mar_bot		; save margins
	push	ax
	mov	mar_top,dh		; use current row
	mov	ah,byte ptr low_rgt+1	; bottom screen row for text
	mov	mar_bot,ah
	call	erprot			; do protected mode erasure
	pop	ax
	mov	mar_top,al		; restore margins
	mov	mar_bot,ah
	jmp	short atedsel3
atedsel1:cmp	al,1			; 1? erase start of line to cursor
	jne	atedsel2		; ne = no
	mov	al,mar_top		; 1: erase start to cursor
	mov	ah,mar_bot		; save margins
	push	ax
	mov	al,mar_right
	mov	ah,dl			; save right margin and cursor col
	push	ax
	mov	mar_right,dl		; stop at current cursor
	mov	dl,mar_left		; start at this pseudo cursor
	mov	mar_top,dh		; use current row
	mov	mar_bot,dh
	call	erprot			; do protected mode erasure
	pop	ax
	mov	mar_right,al		; restore right margin
	mov	dl,ah			; restore cursor row
	pop	ax
	mov	mar_top,al		; restore margins
	mov	mar_bot,ah
	jmp	short atedsel3
atedsel2:cmp	al,2			; 2? erase whole screen
	jne	atedsel3		; ne = no
	mov	al,mar_top		; 2: erase whole screen
	mov	ah,mar_bot		; save margins
	push	ax
	mov	ah,mar_right
	mov	al,mar_left
	push	ax
	push	dx			; save cursor
	xor	dx,dx			; set to top left corner
	mov	mar_right,dl		; starting point
	mov	mar_top,dh
	mov	ax,low_rgt		; lower right corner of text area
	mov	mar_right,al		; end here
	mov	mar_bot,ah
	call	erprot			; do protected mode erasure
	pop	dx			; restore cursor
	pop	ax
	mov	mar_left,al
	mov	mar_right,ah
	pop	ax
	mov	mar_top,al		; restore margins
	mov	mar_bot,ah
atedsel3:ret
atedsel	endp


p20ed:	xor	dx,dx			; Prime PT200, set cursor to 0,0
	call	ereos			; erase cursor to end of screen
	jmp	atsetcur    		; put cursor at 0,0 and return

					; Erase in current line
atel:	cmp	ninter,0		; zero intermediates?
	je	atel0			; e = yes
	ret

atel0:	cmp	lparam,0		; letter parameter?
	je	atel0a
	jmp	atelsel			; try protected mode erasure
atel0a:	cmp	param,0			; was arg zero?
	jne	atel1			; ne = no
	mov	al,dl			; erase from cursor
	mov	bl,byte ptr low_rgt	;  to end of line, inclusive
	jmp	erinline		; do the erasure

atel1:	cmp	param,1			; was arg one?
	jne	atel2			; ne = no
	xor	al,al			; erase from start of line
	mov	bl,dl			;  to cursor, inclusive
	jmp	erinline		; do the erasure

atel2:	cmp	param,2			; was arg two?
	jne	atel3			; ne = no, ignore
	xor	al,al			; erase entire line
	mov	bl,byte ptr low_rgt
	jmp	erinline		; clear it
atel3:	ret


atelsel	proc	near			; DECSEL selective erase in line
	cmp	lparam,'?'		; proper intermediate?
	jne	atelsel3		; ne = no
	mov	ax,param		; get parameter
	or	ax,ax			; 0?
	jnz	atelsel1		; nz = no
	mov	al,mar_top		; 0: erase cursor to end of line
	mov	ah,mar_bot		; save margins
	push	ax
	mov	mar_top,dh		; use current row
	mov	mar_bot,dh
	call	erprot			; do protected mode erasure
	pop	ax
	mov	mar_top,al		; restore margins
	mov	mar_bot,ah
	ret
atelsel1:cmp	al,1			; 1? erase start of line to cursor
	jne	atelsel2		; ne = no
	mov	al,mar_top		; 1: erase start to cursor
	mov	ah,mar_bot		; save margins
	push	ax
	mov	al,mar_right
	mov	ah,dl			; save right margin and cursor col
	push	ax
	mov	mar_right,dl		; stop at current cursor
	mov	dl,mar_left		; start at this pseudo cursor
	mov	mar_top,dh		; use current row
	mov	mar_bot,dh
	call	erprot			; do protected mode erasure
	pop	ax
	mov	mar_right,al		; restore right margin
	mov	dl,ah			; restore cursor row
	pop	ax
	mov	mar_top,al		; restore margins
	mov	mar_bot,ah
	ret
atelsel2:cmp	al,2			; 2? erase whole line
	jne	atelsel3		; ne = no
	mov	al,mar_top		; 2: erase whole line
	mov	ah,mar_bot		; save margins
	push	ax
	mov	ah,dl			; save right margin and cursor col
	mov	al,mar_right
	push	ax
	mov	mar_right,dl		; stop at current cursor
	mov	dl,mar_left		; start at this pseudo cursor
	mov	mar_top,dh		; use current row
	mov	mar_bot,dh
	call	erprot			; do protected mode erasure
	pop	ax
	mov	mar_right,al		; restore right margin
	mov	dl,ah			; restore cursor row
	pop	ax
	mov	mar_top,al		; restore margins
	mov	mar_bot,ah
atelsel3:ret
atelsel	endp

					; ECH, erase chars in this line
atech:	mov	ax,dx			; get cursor position
	mov	bx,ax			; erase ax to bx
	cmp	byte ptr param,0	; 0 argument
	je	atech1			; e = yes
	dec	bl			; count from 1
atech1:	add	bl,byte ptr param	; number of characters
	jmp	erinline		; erase in this line


; Set Graphics Rendition commands (video attributes)

atsgr:	cmp	lparam,0		; any letter parameter?
	jne	atsgr0			; ne = yes, fail
	mov	ah,curattr		; get current cursor attribute
	mov	di,offset atsgr1	; routine to call
	call	atreps			; repeat for all parms
	mov	curattr,ah		; store new attribute byte
	test	flags.vtflg,ttwyse	; Wyse-50?
	jz	atsgr0a			; z = no
	mov	byte ptr wyse_protattr,ah ; Wyse-50 protected char attribute
atsgr0a:cmp     isps55,0                ; [HF]941103 Japanese PS/55 ?
	je      atsgr0                  ; [HF]941103 e = no
	mov     scbattr,ah              ; [HF]940225 and background also
atsgr0:	ret

atsgr1:	mov	bx,param[si]		; fetch an argument
	or	bl,bl			; 0, clear all attributes?
	jnz	atsgr2			; nz = no, do selectively below
	call	clrbold			; clear bold attribute
	call	clrblink		; clear blink attribute
	call	clrrev			; clear reverse video attribute
	call	clrunder		; clear underline attribute
	mov	atinvisible,0		; clear invisible attribute
	mov	cl,extattr
	and	cl,att_protect		; preserve protected attribute
	mov	extattr,cl		; clear extended attributes
	cmp	reset_color,0		; reset colors?
	je	atsgr1a			; e = no
	mov	ah,scbattr
atsgr1a:ret

atsgr2:	cmp	lparam,0		; letter parameter?
	jne	atsgr9			; ne = yes, go directly to colors
	cmp	bl,1			; 1, set bold?
	jne	atsgr2a			; ne = no
	jmp	setbold			; set bold attribute

atsgr2a:cmp	bl,2			; D470 / PT200 - 2, set dim?
	jne	atsgr3			; ne = no
	cmp	flags.vtflg,ttd470	; DG d470?
	je	atsgr2b			; e = yes
	cmp	flags.vtflg,ttpt200	; PT200 '2' = half intensity
	jne	atsgr3		  	; ne = no, do next attrib test
	jmp	setbold			; set half intensity

atsgr2b:mov	ah,scbattr		; D470, "set dim" get default coloring
	jmp	clrbold			; make it dim

atsgr3: cmp	bl,4			; 4, set underline?
	jne	atsgr4			; ne = no
	jmp	setunder		; set underline attribute

atsgr4: cmp	bl,5			; 5, set blink?
	jne	atsgr5			; ne = no
	jmp	setblink		; set blink attribute

atsgr5: cmp	bl,7			; 7, reverse video for chars?
	jne	atsgr5a			; ne = no, try coloring
	jmp	setrev			; set reversed video attribute (AH)

atsgr5a:cmp	bl,8			; 8, invisbile on?
	jne	atsgr6			; ne = no, try coloring
	mov	atinvisible,1		; set invisible coloring
	ret

atsgr6:	cmp	flags.vtflg,ttheath	; Heath-19?
	jne	atsgr9			; ne = no
	cmp	bl,10			; 10, enter graphics mode?
	jne	atsgr7			; ne = no
	push	ax			; save ah
	mov	al,'F'			; simulate final char of 'F'
	call	v52sgm			; do character setup like VT52
	pop	ax
	ret
atsgr7:	cmp	bl,11			; 11, exit graphics mode?
	jne	atsgr8			; ne = no, ignore
	push	ax			; save ah
	mov	al,'G'			; simulate final char of 'G'
	call	v52sgm			; do character setup like VT52
	pop	ax
atsgr8:	ret

atsgr9:	cmp	flags.vtflg,ttd470	; DG D470?
	je	atsgr15			; e = yes
	test	flags.vtflg,ttvt320+ttvt220 ; VT320/VT220?
	jz	atsgr14			; z = no, 22-27 are VT220/320 only
	cmp	bl,22			; 22, bold off?
	jne	atsgr10			; ne = no
	jmp	clrbold
atsgr10:cmp	bl,24			; 24, underline off?
	jne	atsgr11			; ne = no
	jmp	clrunder
atsgr11:cmp	bl,25			; 25, blinking off?
	jne	atsgr12			; ne = no
	jmp	clrblink
atsgr12:cmp	bl,27			; 27, reverse video off?
	jne	atsgr13			; ne = no
	jmp	clrrev			; clear reversed video attribute (AH)
atsgr13:cmp	bl,28			; 28, invisible off?
	jne	atsgr14			; ne = no
	mov	atinvisible,0		; clear invisible attribute
	ret
atsgr14:jmp	setcolor		; BL = color, AH = attribute byte


atsgr15:cmp	bl,30			; in foreground colors?
	jae	atsgr16			; ae = yes, make bold
	cmp	lparam,'<'		; DG dim code?
	jb	atsgr17			; b = no, do nothing
	call	clrbold			; assume dim
	mov	al,lparam
	sub	al,'<'+30h
	add	bl,al			; compose dim color
	jmp	setcolor

atsgr16:call	setbold			; then make it bold
	jmp	setcolor
atsgr17:ret

; Tabulation char commands
attbc:	call	atccpc			; make sure cursor is kosher
	cmp	ninter,0		; zero intermediates?
	je	attbc0			; e = yes, else quit
	ret
					; Tabstop set/clears
attbc0: cmp	param,0			; was argument zero?
	jne	attbc1			; ne = no
	push	si
	mov	si,vtemu.vttbst		; active buffer
	call	tabclr			; clear tabstop in column DL
	pop	si
	ret

attbc1: cmp	param,3			; was arg 3 (clear all tab stops)?
	je	attbc2			; e = yes
	ret				; else ignore
attbc2:	mov	cx,(swidth+7)/8		; get ready to zap swidth columns
	mov	di,offset tabs		; point to the tab stop table
	xor	al,al			; zero indicates no tab stop
	push	es			; save es
	push	ds
	pop	es			; use data segment for es:di below
	cld				; set direction forward
	rep	stosb			; clear all bits
	pop	es
	ret
					; set scrolling margins
atstbm:	test	dspstate,dsptype	; on status line?
	jnz	atstb3			; nz = yes, ignore this command
	mov	al,byte ptr param	; get the two line number args
	mov	ah,byte ptr param+2
	or	al,al			; was first zero?
	jnz	atstb1			; nz = no, continue
	inc	al			; default is one
atstb1: or	ah,ah			; was second zero?
	jnz	atstb2			; nz = no
	mov	ah,byte ptr low_rgt+1	; yes, default is last line on screen
	inc	ah
atstb2: dec	al			; normalize to 0,0 coordinate system
	dec	ah
	cmp	ah,al			; size of region at least two lines?
	jbe	atstb3			; be = no, indicate an error
	or	al,al			; check against screen limits
	jl	atstb3			; l = out of range
	cmp	ah,byte ptr low_rgt+1
	ja	atstb3			; a = too far down
	mov	mar_top,al		; set the limits
	mov	mar_bot,ah
	xor	dx,dx			; Home cursor
	jmp	atsetcur		; set cursor position and return
atstb3:	ret				; ignore bad requests

; Device attributes commands
atda:	cmp	param,0			; was argument zero?
	je	decid			; e = send the i.d. string
	ret				; no, only an echo
decid:	cmp	ninter,0		; any intermediates?
	je	decid1			; e = no, else not this item
	jmp	atdgnrc			; try Spanish NRC designator
decid1:	mov	ax,flags.vtflg		; get terminal ident type
	mov	cx,36			; assumed length of asciiz string
	mov	ttyact,0		; group output for networks
	mov	si,offset v32str	; VT320 ident string
	cmp	ax,ttvt320		; VT320?
	je	decid2			; e = yes
	mov	si,offset v22str
	cmp	ax,ttvt220		; VT220?
	je	decid2			; e = yes
	mov	si,offset v102str
	cmp	ax,ttvt102		; VT102?
	je	decid2			; e = yes
	mov	si,offset v100str
	cmp	ax,ttvt100		; VT100?
	je	decid2			; e = yes
	cmp	ax,ttansi		; ANSI-BBS?
	je	decid2			; e = yes
	cmp	ax,tthoney		; Honeywell?
	je	decid2			; e = yes
	mov	si,offset v52str
	cmp	ax,ttvt52		; VT52?
	je	decid2			; e = yes
	mov	si,offset h19str
	cmp	ax,ttheath		; Heath-19 mode?
	je	decid2			; e = yes
	mov	si,offset pt20str	; Prime PT200 string
decid2:	cmp	lparam,'>'		; this letter parameter?
	jne	decid3			; ne = no
	test	ax,ttvt320+ttvt220	; VT320/VT220 mode?
	jz	decid4			; z = no, ignore
	mov	si,offset v32sda	; Secondary DA response string
decid3:	cld
	lodsb				; read string
	or	al,al			; end of string?
	jz	decid4			; z = yes
	push	cx
	push	si
	cmp	byte ptr [si],0		; last byte to be sent?
	je	decid3a			; e = yes
	cmp	cx,1			; last possible byte?
	ja	decid3b			; a = no
decid3a:mov	ttyact,1		; finished grouping output for net
decid3b:call	prtbout			; send it to port with no local echo
	pop	si
	pop	cx
	loop	decid3			; do all characters
decid4:	mov	ttyact,1		; finished grouping output for net
	ret
					; Display LED's
atll:	mov	di,offset atleds	; get pointer to routine to call
	call	atreps			; repeat for selective parameters
	ret

atleds:	push	si			; set LED indicators
	call	getled			; set si to term type (led) string
	mov	di,si
	pop	si
	jc	atled2			; c = no leds 1..4, ignore
atled4:	cmp	param[si],0		; zero argument?
	jne	atled3			; ne = no, check further
	mov	al,led_off		; set all off
	mov	ah,al
	mov	[di+6],ax		; where dots go after name
	mov	[di+6+2],ax
atled1:	test	yflags,modoff		; mode line supposed to be off?
	jnz	atled2			; nz = yes
	push	dx
	call	fmodlin			; update status line
	pop	dx
atled2: ret
atled3: mov	ax,param[si]		; get the argument
	cmp	al,1			; must be 1 to 4
	jb	atled2			; b = out of range
	cmp	al,4
	ja	atled2			; a = out of range
	dec	ax			; zero base it
	push	di
	add	di,ax
	add	al,'1'			; add ascii offset for digit
	mov	[di+6],al 		; turn the "LED" on by storing digit
	pop	di
	jmp	short atled1		; update display and return

decsca	proc	near			; DEC Select Character Attributes
	cmp	ninter,1		; one intermediate?
	jne	atll			; no, try led routine
	cmp	inter,'"'		; CSI Pn " q ?
	jne	decsca2			; ne = no
	cmp	param,1			; 0, 2 mean protected mode goes off
	jne	decsca1			; ne = not 1, protected mode goes on
	call	setprot			; start protecting
	ret
decsca1:call	clrprot			; end protecting
decsca2:ret
decsca	endp


; Set/Reset mode commands
					; ESC [ ? xxx h/l Set/Reset series
atrm:	mov	modeset,0		; say we are resetting modes
	mov	di,offset atrsm		; Reset/Set modes
	call	atreps			; repeat for all parms
	test	vtemu.vtflgop,decanm	; did ansi mode get reset?
	jnz	atrm1			; nz = no, return
	cmp	flags.vtflg,ttheath	; were we a Heath-19?
	je	atrm0			; e = yes, don't change terminal types
	cmp	flags.vtflg,ttpt200	; were we a PT200?
	je	atrm0			; e = yes, don't change terminal types
	mov	flags.vtflg,ttvt52	; say VT52 now
atrm0:	call	chrdef			; set default char sets
	call	atsc			; save cursor status
	test	yflags,modoff		; mode line supposed to be off?
	jnz	atrm1			; nz = yes
	call	fmodlin			; update mode line
atrm1:	ret

atsm:	mov	modeset,1		; say we are setting modes
	mov	di,offset atrsm		; Reset/Set modes
	jmp	atreps			; repeat for all parms

atrsm:	mov	ax,param[si]		; pick up the argument
	cmp	lparam,'?'		; DEC private mode? ESC [ ?
	je	atrsm1			; e = yes, do DEC specific things
	cmp	lparam,'>'		; Heath-19 private mode? ESC [ >
	jne	atrsma			; ne = no
	jmp	htrsm1			; do Heath specific things
					; ANSI level
atrsma:	cmp	al,20			; 20, ANSI new-line mode?
	jne	atrsm0			; ne = no, try insert mode
	and	vtemu.vtflgop,not vsnewline ; assume resetting
	cmp	modeset,0		; resetting?
	je	atrsmb			; e = yes
	or	vtemu.vtflgop,vsnewline	; setting
atrsmb:	mov	ax,anslnm		; get the flag bit
	jmp	atrsflg			; set or reset it
atrsm0:	cmp	al,4			; toggle insert mode?
	jne	atrsmc			; ne = no
	mov	al,modeset		; set/reset insert mode
	mov	insmod,al		; store it
	ret
atrsmc:	cmp	al,12			; 12? Control local echo
	jne	atrsmx			; ne = no
	cmp	modeset,0		; resetting mode (ESC [ 12 l)?
	jne	atrsmc1			; ne = no
	or	yflags,lclecho		; (l) turn on local echoing
	jmp	short atrsmc2
atrsmc1:and	yflags,not lclecho	; (h) turn off local echoing
atrsmc2:test	yflags,modoff		; is mode line off?
	jnz	atrsmx			; nz = yes
	push	dx			; save cursor position
	call	fmodlin			; write mode line
	pop	dx
atrsmx:	ret
					; DEC specifics
atrsm1: cmp	al,1			; cursor keys mode?
	jne	atrsm2			; ne = no
	mov	ax,decckm		; get the bit
	jmp	atrsflg			; set or reset it and return

atrsm2: cmp	al,7			; Auto-wrap?
	jne	atrsm3			; ne = no
	and	vtemu.vtflgop,not vswrap ; assume resetting line wrap
	cmp	modeset,0		; resetting?
	je	atrsm2a			; e = yes
	or	vtemu.vtflgop,vswrap	; set the bit
atrsm2a:mov	ax,decawm		; get the bit
	jmp	atrsflg			; set or reset it and return

atrsm3: cmp	al,6			; Origin mode?
	jne	atrsm4			; ne = no
	jmp	atrsom			; change decom and return

atrsm4: cmp	al,5			; change the video?
	jne	atrsm5			; ne = no
	jmp	atrsscnm		; yes, change it if necessary

atrsm5: cmp	al,2			; Change VT52 compatibility mode?
	jne	atrsm6			; ne = no
	test	dspstate,dsptype	; on status line?
	jnz	atrsm5b			; nz = yes, ignore switch
	cmp	flags.vtflg,ttheath	; Heath-19 mode?
	jne	atrsm5a			; ne = no
	mov	modeset,0		; Heath  ESC [ ? 2 h  resets ANSI mode
atrsm5a:mov	ax,decanm		; get ansi mode flag
	call	atrsflg			; set or reset it
	test	yflags,modoff		; mode line supposed to be off?
	jnz	atrsm5b			; nz = yes
	push	dx			; save cursor position
	call	fmodlin			; write mode line
	pop	dx
atrsm5b:ret

atrsm6:	cmp	al,3			; 132/80 column mode change?
	jne	atrsm7			; ne = no
	mov	al,curattr		; save current video attributes
	mov	ah,extattr		; and extended attributes
	push	ax
	xor	ah,ah			; high byte: not exiting Connect mode
	and	vtemu.vtflgop,not deccol; assume mode is reset
	mov	al,modeset		; pass set/reset request to chgdsp
	or	al,al
	jz	atrsm6a			; z = set 80 columns
	or	vtemu.vtflgop,deccol	; assume it will work (tell msy)
atrsm6a:call	chgdsp			; call Change Display proc in msy
	and	vtemu.vtflgop,not deccol; assume mode is reset
	cmp	modeset,0		; want 80 cols?
	je	atrsm6n			; e = yes, else 132 cols
	cmp	byte ptr low_rgt,79
	jbe	atrsm6b
	or	vtemu.vtflgop,deccol	; set the status bit
	mov	byte ptr low_rgt,132-1	; screen capability
	jmp	short atrsm6e
atrsm6b:and	vtemu.vtflgst,not deccol; turn off setup 132 col bit too
atrsm6n:cmp	byte ptr low_rgt,79	; want 80 cols, is it wider?
	jbe	atrsm6e			; be = no
	mov	byte ptr low_rgt,79	; narrow down to 80 columns
atrsm6e:test	flags.vtflg,ttd463+ttd470+ttd217+ttwyse ; D463/D470 or Wyse?
	jnz	atrsm6f			; nz = yes, no reset for them
	CALL	ATRES2			; do partial reset of emulator
atrsm6f:pop	ax
	mov	curattr,al		; restore saved items
	mov	extattr,ah
	test	flags.vtflg,ttd463+ttd470+ttd217 ; DG D463/D470/D217 mode?
	jz	atrsm6g			; z = no
atrsm6h:call	frepaint		; repaint new screen
	ret				; D463/D470 gets no other changes
atrsm6g:mov	dx,low_rgt		; text lines (leave status line intact)
	mov	mar_top,0
	mov	mar_bot,dh		; reset scrolling region
	mov	dl,byte ptr low_rgt	; right margin
	mov	mar_right,dl
	mov	mar_left,0
	test	flags.vtflg,ttwyse 	; Wyse?
	jnz	atrsm6h			; nz = yes, leave cursor alone, repaint
	xor	dx,dx			; new cursor position is 0,0
	mov	cursor,dx
	jmp	atsetcur		; place it there and return

atrsm7:	cmp	al,18			; 18?  18 & 19 = printer support
	jne	atrsm8			; ne = no
	cmp	modeset,0		; resetting?
	jne	atrsm7a			; ne = no, setting
	and	anspflg,not vtffp	; no form feed after printing
	ret
atrsm7a:or	anspflg,vtffp		; use form feed after printing
	ret

atrsm8:	cmp	al,19			; 19, print region?
	jne	atrsm9			; ne = no
	cmp	modeset,0		; resetting?
	jne	atrsm8a			; ne = no, setting
	and	anspflg,not vtextp	; reset print region to scrolling reg
	ret
atrsm8a:or	anspflg,vtextp		; set print region to whole screen
	ret

atrsm9:	cmp	al,25			; ESC [ ? 25 h/l? cursor on/off
	jne	atrsm10			; ne = no
	mov	al,4			; assume cursor to be turned off (4)
	cmp	modeset,0		; resetting (invisible cursor)?
	je	atrsm9a			; e = yes
	mov	al,1			; assume underline (1)
	test	vtemu.vtflgop,vscursor	; underline?
	jnz	atrsm9a			; nz = yes
	inc	al			; block (2)
atrsm9a:mov	atctype,al		; save VTxxx cursor type here
	jmp	atsctyp			; set the cursor type

					; DECRLM (alt VT320 right/left write)
atrsm10:cmp	al,34			; ESC [ ? 34 h/l? Invoke special macro
	jne	atrsm10b		; ne = no
	and	vtemu.vtflgop,not vswdir; writing direction to normal
	and	vtemu.vtflgst,not vswdir; writing direction to normal
	cmp	modeset,0		; resetting?
	jne	atrsm10a		; ne = no, setting
	mov	decrlm,0		; writing direction to left to right
	ret
atrsm10a:mov	decrlm,1		; writing direction to right to left
	ret
					; DECHEBM (alt VT320 keyboard map)
atrsm10b:cmp	al,35			; ESC [ ? 35 h/l? Invoke special macro
	jne	atrsm10d		; ne = no
	cmp	modeset,0		; resetting?
	jne	atrsm10c		; ne = no, setting
	call	fvtkrmac		; perform on-line macro
	ret
					;  code is located in file msy
atrsm10c:call	fvtksmac		; do set macro
	ret

atrsm10d:cmp	al,36			; DECHEM Hebrew encoding mode?
	jne	atrsm11			; ne = no
	cmp	modeset,0		; resetting?
	jne	atrsm10e		; ne = no
	mov	al,13			; Hebrew NRC
	mov	ah,al			; GR = GL = 13
	or	vtemu.vtflgop,vsnrcm	; set NRC active bit
	or	vtemu.vtflgst,vsnrcm
	and	vtemu.vtflgop,not vscntl ; no 8-bit controls
	jmp	short atrsm10f
atrsm10e:mov	al,17			; DEC Multinational set (17)
	xor	ah,ah			; GLeft is ASCII (0)
	and	vtemu.vtflgop,not vsnrcm ; clear NRC active bit
	and	vtemu.vtflgst,not vsnrcm
atrsm10f:mov	vtemu.vtchset,al
	mov	bx,offset emubuf	; temp table of char set idents
	xchg	ah,al			; order correctly
	mov	[bx],ax			; char sets for G0..G3
	mov	[bx+2],ax
	call	chrsetup		; invoke NRC
	ret

atrsm11:cmp	al,38			; 38? Enter Tek sub-mode. VT340 seq
	jne	atrsm12			; ne = no
	cmp	modeset,1		; setting mode (ESC [ ? 38 h)?
	jne	atrsm12			; ne = no, ignore sequence
ifndef	no_graphics
	test	denyflg,tekxflg		; is auto Tek mode disabled?
	jnz	atrsm12			; nz = yes, just ignore command
	call	atsc			; save cursor and associated data
	xor	al,al			; enter with this received character
	call	TEKEMU			; go to Tektronix Emulator, al=null
	jmp	atnorm
endif	; no_graphics
atrsm12:cmp	al,42			; 42, use NRC 7-bit command?
	jne	atrsm15			; ne = no
	test	flags.vtflg,ttvt320+ttvt220 ; VT320/VT220 mode?
	jz	atrsm14			; z = no
	cmp	vtemu.vtchset,0		; ASCII?
	je	atrsm14			; e = yes, no NRC
	cmp	vtemu.vtchset,13	; highest NRC ident?
	ja	atrsm14			; a = not NRC
	cmp	modeset,0		; resetting?
	je	atrsm13			; e = yes
	or	vtemu.vtflgop,vsnrcm	; set NRC flag bit
	jmp	chrdef			; and set NRC characters
atrsm13:mov	ax,vtemu.vtflgop	; run time flags
	and	vtemu.vtflgop,not vsnrcm ; turn off NRC flag bit
	or	vtemu.vtflgop,vscntl	; turn on 8-bit controls
	jmp	chrdef
atrsm14:ret
atrsm15:cmp	al,66			; 66, keypad to applications mode?
	jne	atrsm16			; ne = no
	test	flags.vtflg,ttvt320+ttvt220 ; VT320/VT220 mode?
	jz	atrsm16			; z = no
	mov	ax,deckpam		; bit to control
	jmp	atrsflg			; control the flag and return
atrsm16:ret

; VT340  CSI number $ |   number is 0 or 80 for 80 cols, 132 for 132 columns
; DECSCPP, set columns per page
atscpp:	cmp	inter,'$'		; correct intermediate letter?
	jne	atscpp2			; ne = no, ignore
	cmp	ninter,1		; one intermediate?
	jne	atscpp2			; ne = no, ignore
	mov	modeset,1		; assume 132 columns wanted
	cmp	param,80		; 80 or 132 columns?
	ja	atscpp1			; a = 132 columns
	mov	modeset,0		; set to 80 columns
atscpp1:mov	al,3			; set up CSI ? 3 h/l command
	jmp	atrsm6			; process that command
atscpp2:ret

		; Heath-19  ESC [ > Ps h or l where Ps = 1, 4, 7, or 9
htrsm1:	cmp	al,1			; 25th line?
	jne	htrsm4			; ne = no
	and	h19stat,not h19l25	; clear 25th line bit
	cmp	modeset,0		; clearing?
	je	htrsm1a			; e = yes
	or	h19stat,h19l25		; set bit
	jmp	htrsmx			; we are done
htrsm1a:mov	ah,byte ptr low_rgt+1	; point to status (25th) line
	inc	ah			;  which is here
	xor	al,al			; from column 0
	mov	bh,ah			; to same line
	mov	bl,byte ptr low_rgt	; physical width
	call	vtsclr			; disabling status line clears it
	ret

htrsm4:	cmp	al,4			; 4, block/line cursor?
	jne	htrsm5			; ne = no
	and	h19ctyp,4		; save on/off bit (4)
	cmp	modeset,0		; reset?
	je	htrsm4a			; e = yes
	or	h19ctyp,2		; remember block kind here
	jmp	atsctyp
htrsm4a:or	h19ctyp,1		; remember underline kind here
	jmp	atsctyp
     
htrsm5: cmp     al,5                    ; 5, on/off cursor?
        jne     htrsm7                  ; ne = no
        cmp     modeset,0               ; on?
        je      htrsm5a                 ; e = yes
	or	h19ctyp,4		; remember off state in this bit
        jmp     atsctyp
htrsm5a:and	h19ctyp,not 4		; set cursor on
        jmp     atsctyp

htrsm7:	cmp	al,7			; 7, alternate application keypad?
	jne	htrsm8			; ne = no
	mov	ax,deckpam		; get keypad application mode bit
	jmp	atrsflg			; set or reset appl keypad mode

htrsm8:	cmp	al,8			; 8, received CR => CR/LF?
	jne	htrsm9
	and	h19stat,not h19alf	; clear autoline feed bit
	cmp	modeset,0		; resetting?
	je	htrsmx			; yes
	or	h19stat,h19alf		; turn on the mode
	ret

htrsm9:	cmp	al,9			; 9, auto newline mode? (add cr to lf)
	jne	htrsmx			; ne = no
	mov	ax,anslnm		; get the bit
	jmp	atrsflg			; set or reset newline mode
htrsmx:	ret				; ignore the code

atrsflg:cmp	modeset,0		; reset?
	je	atrsf1			; e = yes, reset it
	or	vtemu.vtflgop,ax	; set, OR in the flag
	test	ax,decanm		; changing ansi mode?
	jz	atrsfx			; z = no
	cmp	flags.vtflg,ttheath	; in Heath-19 mode?
	je	atrsfx			; e = yes, don't flip terminal kinds
	mov	ax,oldterm		; terminal type at startup
	mov	flags.vtflg,ax		; restore it
	ret
atrsf1: not	ax			; reset bit, complement
	and	vtemu.vtflgop,ax	; clear the bit
	not	ax			; recover the bit
	test	ax,decanm		; changing ansi mode?
	jz	atrsfx			; z = no
	cmp	flags.vtflg,ttheath	; in Heath-19 mode?
	je	atrsfx			; e = yes, don't flip terminal kinds
	mov	flags.vtflg,ttvt52	; say VT52 now
atrsfx:	ret
					; Set/Clear Origin mode
atrsom:	test	dspstate,dsptype	; on status line?
	jz	atrsom1			; z = no
	ret				; else ignore this command
atrsom1:cmp	modeset,0		; clearing DEC origin mode?
	jne	atrsom2			; ne = no, setting
	and	vtemu.vtflgop,not decom ; reset Origin mode
	xor	dx,dx			; go to the home position
	jmp	atsetcur		; set cursor and return
atrsom2:or	vtemu.vtflgop,decom	; set Origin mode
	mov	dx,cursor		; get the cursor
	xor	dl,dl			; go to right margin
	mov	dh,mar_top		; go to home of scrolling region
	jmp	atsetcur		; set the cursor and return

atrsscnm:cmp	modeset,0		; resetting?
	je	atrss1			; e = yes, reset
	test	vtemu.vtflgop,vsscreen	; setting, set already?
	jnz	atrss3			; nz = yes, don't do it again
	or	vtemu.vtflgop,vsscreen	; set and tell Status display
	jmp	short atrss2		; do it

atrss1: test	vtemu.vtflgop,vsscreen	; resetting, reset already?
	jz	atrss3			; z = yes, don't do it again
	and	vtemu.vtflgop,not vsscreen ; clear and tell Status
					; fall through to atrss2

; Note: This is also called from the stblmds initialization routine.
; Reverse video the entire screen, update scbattr and curattr to match.
atrss2:	push	ax
	mov	ah,scbattr		; current screen attributes
	call	revideo			; reverse them
	mov	scbattr,ah		; set screen background attribute
	mov	ah,curattr		; get current cursor attribute
	call	revideo			; reverse it
	mov	curattr,ah		; store it
	call	revscn			; reverse everything on the screen
	pop	ax
atrss3:	ret

					; Self tests DECTST
atctst:	cmp	inter,0			; any intermediate char?
	jne	atcts3			; ne = yes, not a selftest command
	cmp	param,2			; VT102 selftest?
	je	atcts1			; e = yes
	cmp	param,4			; VT320 selftest?
	jne	atcts6			; ne = no
atcts1:	test	dspstate,dsptype	; cursor is on status line?
	jz	atcts2			; z = no
	push	param			; save first parameter
	mov	ah,inter		;  and first intermediate char
	push	ax
	mov	param,0			; select main display
	mov	inter,'$'		; setup proper intermediate
	call	atssdt			; select status line of off
	call	atsasd			; select main display
	pop	ax
	pop	param			; restore parameter
	mov	inter,ah		;  and intermediate char
atcts2:	xor	al,al			; init test weight
	mov	di,offset atcts4	; routine to call
	call	atreps			; repeat for all parms
	test	al,80H			; reset?
	jz	atcts3			; z = no, return
	jmp	atreset			; reset everything
atcts3: ret

atcts4:	or	si,si			; initial arg?
	jz	atcts5			; z = yes, skip it (examined above)
	cmp	param[si],1		; power up test (0, 1) included?
	ja	atcts5			; a = no, ignore printer/comms/repeats
	or	al,80H			; say we want reset
atcts5: ret

atcts6:	cmp	nparam,0		; absence of parameters?
 	jne	atcts5			; ne = no, ignore sequence
	jmp	athoney			; try Honeywell ESC [ y  ident response

atalign	proc	near			; Align screen, fill screen with 'E's
	mov	al,'E'			; char to use as filler
	test	dspstate,dsptype	; is cursor on status line?
	jz	atalig1			; z = no
	ret				; yes, ignore the command
atalig1:cmp	flags.modflg,0		; is mode line off?
	je	atalig2			; e = yes
	and	yflags,not modoff	; say it's on
	mov	flags.modflg,1		;  and owned by us
atalig2:push	ax			; save displayed char
	push	vtemu.vtflgst		; save setup flags
	mov	ax,vtemu.vtflgop	; operational flags
	and	ax,deccol		; get 80/132 column indicator
	and	vtemu.vtflgst,not deccol ; clear for set below
	or	vtemu.vtflgst,ax	; set it so reset preserves it
	call	atreset			; clear system
	pop	vtemu.vtflgst		; recover setup flags
	or	vtemu.vtflgop,decawm	; set wrap
	mov	cl,byte ptr low_rgt	; number of columns-1
	inc	cl
	mov	al,byte ptr low_rgt+1	; number of rows-1
	inc	al
	mul	cl			; ax = number of chars on screen
	mov	cx,ax
	pop	ax			; recover displayed char in AL
	mov	emubuf,al		; keep it here while looping
atalig3:push	cx
	mov	al,emubuf		; write screen full of this char
	call	atnrm			; write the 'E' or whatever
	pop	cx
	loop	atalig3			; cx times
	ret
atalign	endp


; Reports
atreqt: cmp	param,1			; want report?
	jbe	atreq1			; be = yes
atreq0:	ret				; Gee, must have been an echo (> 1)

atreq1:	test	flags.vtflg,ttvt102+ttvt100+tthoney+ttansi ; VT102 etc?
	jz	atreq0			; z = no, ignore
	mov	ttyact,0		; group output for networks
	mov	al,Escape
	call	prtbout
	mov	al,'['
	call	prtbout
	mov	al,'3'			; we report only upon request
	cmp	param,0			; was argument a zero?
	jne	atreq1b			; ne = no
	mov	al,'2'			; yes
atreq1b:call	prtbout
	mov	al,';'			; separate
	call	prtbout
	mov	bl,parcode		; get the parity code
	xor	bh,bh
	mov	al,partab[bx]		; get VT100 parity code
	push	ax			; save parity code
	call	prtnout			; send number to the port
	mov	al,';'			; separate
	call	prtbout
	mov	al,'2'			; assume 7 data bits
	pop	bx			; get parity code into bl
	cmp	bl,1			; is parity none?
	jne	atreq2			; ne = no, so 7 data bits
	test	flags.remflg,d8bit	; 8 bit display?
	jz	atreq2			; z = no
	mov	al,'1'			; must be eight
atreq2: call	prtbout			; send it to the port
	mov	al,';'
	call	prtbout
	mov	bl,baudidx		; baud rate index
	xor	bh,bh
	mov	al,baudtab[bx]		; get DEC baud rate code
	push	ax
	call	prtnout			; sending speed index
	mov	al,';'
	call	prtbout
	pop	ax
	cmp	bl,lbaudtab-1		; using the split speed entry?
	jne	atreq2a			; ne = no
	mov	al,[bx+1]		; get trailing receive speed (75 baud)
atreq2a:call	prtnout			; receiving speed index
	mov	al,';'
	call	prtbout
	mov	al,'1'			; clock rate multiplier is always 1
	call	prtbout
	mov	al,';'
	call	prtbout
	mov	al,'0'			; Flags are always zero (no STP)
	call	prtbout
	mov	ttyact,1		; end group output for networks
	mov	al,'x'
	call	prtbout
	ret

					; Single Controls
; Note DEC manual incorrectly says DECSCL's do a hard rather than soft reset
decscl:	cmp	inter,'!'		; "CSI ! p" soft reset?
	jne	decsc0			; ne = no
	jmp	atsres			; do a soft reset

decsc0:	cmp	inter,'"'		; "CSI Psc; Ps1 " p"  operating level?
	je	decsc1			; e = yes
	cmp	inter,'$'		; "CSI Pn $ p"  DECRQM?
	jne	decsc0a			; ne = no, ignore others
	jmp	decsc5			; do isolated controls report
decsc0a:ret				; else ignore
decsc1:	cmp	param,61		; Psc, select VT100?
	jne	decsc2			; ne = no
	mov	flags.vtflg,ttvt102	; set VT102
	mov	oldterm,ttvt102		; and remember it
	and	vtemu.vtflgop,not vscntl ; turn off 8-bit controls
	mov	al,anspflg		; preserve screen print flag
	push	ax
	call	atsres			; do soft reset of emulator
	pop	ax
	mov	anspflg,al
	ret
decsc2:	cmp	param,62		; go to VT2xx level?
	jne	decsc3			; ne = no
	test	flags.vtflg,ttvt320+ttvt102 ; at VT300/VT102 level now?
	jnz	decsc3a			; nz = yes, don't change types
	mov	flags.vtflg,ttvt220	; set VT220 mode
	mov	oldterm,ttvt220
	jmp	short decsc3b		; finish up
	
decsc3:	cmp	param,63		; go to VT300 level?
	jne	decsc4			; ne = no
decsc3a:mov	flags.vtflg,ttvt320	; set VT320 mode
	mov	oldterm,ttvt320
decsc3b:cmp	param[2],2		; Ps1, range here is 0, 1, 2
	ja	decsc4			; a = out of range, ignore
	mov	al,anspflg		; preserve screen print flag
	push	ax
	call	atsres			; do soft reset of emulator
	pop	ax
	mov	anspflg,al
	and	vtemu.vtflgop,not vscntl ; turn off 8-bit controls
	cmp	param[2],1		; select 7-bit controls?
	je	decsc4			; e = yes, we have done so
	or	vtemu.vtflgop,vscntl	; turn on 8-bit controls
decsc4:	ret
       					; single controls report request
decsc5:	cmp	lparam,'?'		; want DEC Private modes?
	jne	decsc5a			; ne = no
	call	decscpre		; do standard prefix
	mov	al,'2'			; assume mode is reset
	call	decsc20			; do DEC Private mode report
	jmp	decscend		; do end of sequence
decsc5a:cmp	inter,0			; intermediate char?
	je	decsc5b			; e = no, ignore
	call	decscpre		; do standard prefix
	mov	al,'2'			; assume mode is reset
	call	decsc5c			; do ANSI report
	jmp	decscend		; do end of sequence
decsc5b:ret				; else return failure
					
decsc5c:mov	cx,param		; ANSI report:
	cmp	cx,2			; 2, Keyboard action?
	jne	decsc6			; ne = no
	ret
decsc6:	cmp	cx,3			; control representation?
	jne	decsc7			; ne = no
	ret				; say reset(acting on controls)
decsc7:	cmp	cx,4			; 4, Insert/Replace mode?
	jne	decsc8			; ne = no
	cmp	insmod,0		; insert mode off?
	je	decsc7a			; e = yes, off
	dec	al			; say is on
decsc7a:ret
decsc8:	cmp	cx,10			; 10, Horizontal editing?
	jne	decsc9			; ne = no
	mov	al,'4'			; permanently reset
	ret
decsc9:	cmp	cx,12			; 12, Send/Receive (local echo)?
	jne	decsc11			; ne = no
	test	yflags,lclecho		; echoing on?
	jz	decsc12			; z = no
	dec	al			; say set
	ret
decsc11:cmp	cx,20			; 20, new line mode?
	jne	decsc13			; ne = no
	test	vtemu.vtflgop,anslnm	; new line set?
	jz	decsc12			; z = no, reset
	dec	al			; say set
decsc12:ret
decsc13:mov	al,'0'			; say not recognized
	ret

		       			; DEC Private mode report
decsc20:mov	cx,param
	cmp	cx,1			; 1, cursor keys?
	jne	decsc22			; ne = no
	test	vtemu.vtflgop,decckm	; set?
	jz	decsc31			; z = no, reset
	dec	al
	ret
decsc22:cmp	cx,2			; 2, ANSI mode
	jne	decsc24			; ne = no
	test	vtemu.vtflgop,decanm	; set?
	jz	decsc31			; z = no, reset
	dec	al
	ret
decsc24:cmp	cx,3			; 3, column
	jne	decsc26			; ne = no
	test	vtemu.vtflgop,deccol	; 132 column mode set?
	jz	decsc31			; z = no, reset (80 columns)
	dec	al
	ret
decsc26:cmp	cx,4			; 4, scrolling mode
	je	decsc31			; e = yes always say reset (jump)
					;
	cmp	cx,5			; 5, screen
	jne	decsc28			; ne = no
	test	vtemu.vtflgop,decscnm	; set (light background)?
	jz	decsc31			; z = no, reset
	dec	al
	ret
decsc28:cmp	cx,6			; 6, Origin mode?
	jne	decsc30			; ne = no
	test	dspstate,dsptype	; on status line?
	jz	decsc29			; z = no, main display
	test	dspstate,dspdecom	; main display Origin mode set?
	jz	decsc31			; z = no, reset
	dec	al
	ret
decsc29:test	vtemu.vtflgop,decom	; Origin mode set?
	jz	decsc31			; z = no, reset
	dec	al
	ret
decsc30:cmp	cx,7			; 7, autowrap?
	jne	decsc32			; ne = no
	test	vtemu.vtflgop,decawm	; set?
	jz	decsc31			; z = no, reset
	dec	al
decsc31:ret				; common return point
decsc32:cmp	cx,8			; 8, autorepeat?
	jne	decsc34			; ne = no
	dec	al
	ret				; say set
decsc34:cmp	cx,18			; 18, print Form Feed?
	jne	decsc36			; ne = no
	test	anspflg,vtffp		; set?
	jz	decsc31			; z = no, reset
	dec	al
	ret
decsc36:cmp	cx,19			; 19, printer extent?
	jne	decsc38			; ne = no
	test	anspflg,vtextp		; set?
	jz	decsc31			; z = no, reset
	dec	al
	ret
decsc38:cmp	cx,25			; 25, text cursor enabled?
	jne	decsc40			; ne = no
	test	atctype,4		; 4 is off
	jnz	decsc31			; nz = off/disabled
	dec	al			; say enabled
	ret
decsc40:cmp	cx,42			; 42, NRC's
	jne	decsc42			; ne = no
	test	flags.vtflg,ttvt320+ttvt220 ; VT320/VT220?
	jz	decsc31			; z = no
	test	vtemu.vtflgop,vsnrcm	; NRC's active?
	jz	decsc31			; z = no
	dec	al			; say enabled
	ret
decsc42:cmp	cx,66			; 66, numeric keypad?
	jne	decsc44			; ne = no
	test	vtemu.vtflgop,deckpam	; set?
	jz	decsc31			; z = no, reset
	dec	al			; say set
	ret
decsc44:cmp	cx,68			; 68, keyboard usage?
	jne	decsc45			; ne = no
	mov	al,'4'			; say always typewriter mode
	ret
decsc45:mov	al,'0'			; say unknown kind
	ret

decscpre:mov	ttyact,0		; group output for networks
	mov	al,Escape		; do standard report beginning
	call	prtbout
	mov	al,'['
	call	prtbout
	mov	al,lparam		; with query mark
	or	al,al			; any letter param?
	jz	decscpre1		; z = no
	call	prtbout
decscpre1:
	mov	al,byte ptr param	; get parameter
	call	prtnout			; send the number
	mov	al,';'
	call	prtbout
	ret

decscend:call	prtbout			; do standard rpt end, send char in al
	mov	al,'$'
	call	prtbout
	mov	ttyact,1		; end group output for networks
	mov	al,'y'
	call	prtbout
	ret

; DEC style Soft Reset
; Note: graphics rendition is NOT changed by soft reset, DEC manual is wrong.
atsres	proc	near			; do soft reset of terminal
	test	dspstate,dsptype	; on status line?
	jz	atsres1			; z = no, on main display
	mov	param,0
	mov	inter,'$'		; setup entry for atsasd
	call	atsasd			; select main display
atsres1:and	vtemu.vtflgop,not(decawm+decckm+deckpam+decom) ; these go off
	mov	insmod,0		; insert mode off
	mov	mar_top,0		; reset scrolling margins
	mov	al,byte ptr low_rgt+1
	mov	mar_bot,al		; to full screen
	mov	anspflg,0		; clear printer flag
	mov	al,1			; restore cursor, assume underline (1)
	test	vtemu.vtflgop,vscursor	; underline?
	jnz	atsres2			; nz = yes
	inc	al			; block (2)
atsres2:mov	atctype,al		; save VTxxx cursor type here
	call	atsctyp			; set the cursor type
	push	cursor
	mov	cursor,0		; set save cursor to Home
	call	atsc			; save attributes
	pop	cursor			; restore active cursor
	call	chrdef			; set default character set
        cmp     isps55,0                ; [HF]941103 Japanese PS/55?
        je      atsres4                 ; [HF]941103 e = no
        cmp     flags.modflg,0          ; [HF]940227 mode line is off?
        je      atsres3                 ; [HF]940227 e = yes
        mov     flags.modflg,1          ; [HF]940227 mode line is owned by us
        jmp     short atsres5           ; [HF]941103
atsres4:test    yflags,modoff           ; mode line is to be off?
	jnz	atsres3			; nz = yes
atsres5:call	fmodlin			; rewrite mode line
atsres3:ret
atsres	endp
					; DECRQSS/DECRPSS Control Settings

					; Handle DCS ... q string ST
atcrq:	cmp	ninter,1		; one intermediate?
	je	atcrq1			; e = yes
	ja	atcrq0			; a = too many
	jmp	atcrqq			; none, do Sixel DCS params q...ST
atcrq0:	mov	ninter,0		; set up atdcsnul for proper form
	mov	ttstate,offset atdcsnul	; not understood, consume til ST
	ret

atcrq1:	cmp	inter,'$'		; correct intermediate?
	jne	atcrq0			; ne = no
	cmp	nparam,0		; and no parameters?
	jne	atcrq0			; ne = have some, not ours
	mov	ttstateST,offset atcrq4	; set state for ST arrival
	mov	ttstate,offset atcrq2	; next state gets string contents
	mov	emubufc,0		; clear buffer counter
	mov	word ptr emubuf,0	; empty start of buffer
	ret
atcrq2:	mov	bx,emubufc		; count of chars in string buffer
	cmp	bx,emubufl		; too many?
	jae	atcrq3			; ae = too many, ignore extras
	mov	emubuf[bx],al		; store the char
	inc	emubufc			; count it
atcrq3:	ret
					; here after ST has been seen
atcrq4:	cmp	emubufc,2		; max string chars we want
	jbe	atcrq4a			; be = ok
	jmp	atnorm			; a = too many, ignore
atcrq4a:mov	ax,word ptr emubuf	; get first two chars
	cmp	ax,'}$'			; select active display?
	jne	atcrq5			; ne = no
	jmp	atcrqd			; do the routine
atcrq5:	cmp	ax,'p"'			; set conformance level?
	jne	atcrq7			; ne = no
	jmp	atcrqp
atcrq7:	cmp	ax,'~$'			; set status line type
	jne	atcrq8
	jmp	atcrqt
atcrq8:	cmp	ax,'r'			; set top and bottom margins?
	jne	atcrq9
	jmp	atcrqr
atcrq9:	cmp	ax,'m'			; set graphic rendition?
	jne	atcrq10
	jmp	atcrqm
atcrq10:jmp	atcrqxx			; unknown command
					; DCS $ q  response routines
atcrqr:	call	atcrqbeg		; 'r', top/bottom margins
	test	dspstate,dsptype	; doing status line display?
	jz	atcrqr2			; z = no
	mov	al,byte ptr dspmsave	; get saved top margin
	inc	al
	call	prtnout
	mov	al,';'
	call	prtbout
	mov	al,byte ptr dspmsave+1	; get saved bottom margin
	jmp	short atcrqr3		; finish up
atcrqr2:mov	al,mar_top		; top margin
	inc	al			; move to 1,1 system
	call	prtnout
	mov	al,';'
	call	prtbout
	mov	al,mar_bot
atcrqr3:inc	al			; move to 1,1 system
	call	prtnout
	mov	al,'r'			; final char
	jmp	atcrqend		; do epilogue

atcrqm:	call	atcrqbeg		; 'm', graphics rendition
	mov	al,'0'			; say start with all attributes off
	call	prtbout
	call	getbold			; returns ah with bold attr or 0
	or	ah,ah			; bold set?
	jz	atcrqm2			; z = no
	mov	al,';'
	call	prtbout
	mov	al,'1'			; say bold is on
	call	prtbout
atcrqm2:call	getunder		; underline
	or	cl,cl			; underline on?
	jz	atcrqm3			; z = no, do next
	mov	al,';'
	call	prtbout
	mov	al,'4'			; say underlining is on
	call	prtbout
atcrqm3:mov	ah,scbattr
	call	getblink		; blinking
	or	ah,ah			; blinking on?
	jz	atcrqm4			; z = no
	mov	al,';'
	call	prtbout
	mov	al,'5'			; say blinking is on
	call	prtbout
atcrqm4:test	extattr,att_rev		; chars in reversed video?
	jz	atcrqm5			; z = no
	mov	al,';'
	call	prtbout
	mov	al,'7'			; say underlining is on
	call	prtbout
atcrqm5:mov	al,'m'			; final char
	jmp	atcrqend		; do epilogue

atcrqd:	call	atcrqbeg		; '$}', writing to screen/status line
	mov	al,'0'			; assume writing to main display
	test	dspstate,dsptype	; get type of display
	jz	atcrqd2			; z = main display
	inc	al			; say writing to mode line
atcrqd2:call	prtbout
	mov	al,'$'			; final chars
	call	prtbout
	mov	al,7dh			; right curly brace
	jmp	atcrqend		; do epilogue

atcrqt:	call	atcrqbeg		; '$~', status line
	mov	al,'0'			; assume mode line is off
	test	yflags,modoff		; is mode line off?
	jnz	atcrqt2			; nz = yes
	mov	al,'2'			; mode line is on and host writable
atcrqt2:call	prtbout
	mov	al,'c'			; final chars
	call	prtbout
	mov	al,7eh			; tilde
	jmp	atcrqend		; do epilogue
					; '"p' set conformance level
atcrqp:	cmp	oldterm,ttvt100		; main-mode terminal is VT100?
	je	atcrqp2			; e = yes
	cmp	oldterm,tthoney		; Honeywell?
	je	atcrqp2			; e = yes
	cmp	oldterm,ttansi		; ANSI-BBS?
	je	atcrqp2			; e = yes
	cmp	oldterm,ttvt102		; VT102?
	je	atcrqp2			; e = yes
	cmp	oldterm,ttvt320		; how about VT320?
	je	atcrqp2			; e = yes
	jmp	atcrqxx			; say invalid request
atcrqp2:mov	ttyact,0		; group output for networks
	mov	al,Escape		; '"p', conformance level
	call	prtbout
	mov	al,'P'			; DCS, ESC P
	call	prtbout
	mov	al,'0'			; valid request
	call	prtbout
	mov	al,'$'
	call	prtbout
	mov	al,61			; assume VT102
	cmp	oldterm,ttvt100		; VT100?
	je	atcrqp2a		; e = yes
	cmp	oldterm,tthoney		; Honeywell
	je	atcrqp2a		; e = yes
	cmp	oldterm,ttansi		; ANSI-BBS?
	je	atcrqp2a		; e = yes
	cmp	oldterm,ttvt102		; are we a VT102?
	jne	atcrqp3			; ne = no
atcrqp2a:call	prtnout
	jmp	short atcrqp5		; finish the report

atcrqp3:mov	al,63			; say VT320
	call	prtnout
	mov	al,';'
	call	prtbout
	mov	al,'2'			; assume 8-bit controls are on
	test	vtemu.vtflgop,vscntl	; 8-bit controls active?
	jnz	atcrqp4			; nz = yes
	mov	al,'1'			; else say only 7-bit controls
atcrqp4:call	prtbout
atcrqp5:mov	al,'"'			; final characters
	call	prtbout
	mov	al,'p'
	jmp	atcrqend		; do epilogue

atcrqbeg:mov	ttyact,0		; group output for networks
	mov	al,Escape		; report prologue
	call	prtbout
	mov	al,'P'			; DCS, ESC P
	call	prtbout
	mov	al,'0'			; valid request
	call	prtbout
	mov	al,'$'
	jmp	prtbout

atcrqend:call	prtbout			; report epilogue, al has char
	mov	ttyact,1		; end group output for networks
	mov	emubufc,0		; clear work buffer count
	mov	al,Escape
	call	prtbout
	mov	al,'\'			; string terminator ST (ESC \)
	jmp	prtbout

atcrqxx:mov	ttyact,0		; group output for networks
	mov	al,Escape		; report invalid request
	call	prtbout
	mov	al,'P'			; DCS, ESC P
	call	prtbout
	mov	al,'1'			; invalid request
	call	prtbout
	mov	al,'$'
	cmp	emubufc,1		; any first char?
	jb	atcrqend		; b = no
	call	prtbout
	mov	al,emubuf		; first string char
	cmp	emubufc,2		; two string chars?
	jne	atcrqend		; ne = no
	call	prtbout
	mov	al,emubuf+1		; second string char
	jmp	atcrqend		; do epilogue

					; DCS P1; P2; P3 <char> Sixel command
atcrqq:	cmp	dcsstrf,'q'		; final char of 'q'? Sixel draw
	je	atcrqq1			; e = yes
	cmp	dcsstrf,'p'		; 'p', restore palette?
	jne	atcrqq0			; ne = no
	cmp	dinter,'$'		; DCS 2 $ p?
	jne	atcrqq0			; ne = no
	cmp	param,2			; this too?
	jne	atcrqq1			; ne = no
ifndef	no_graphics
	call	tekinq			; get Tek screen state
	jmp	tekrcol			; restore palette
endif	; no_graphics

atcrqq0:mov	ninter,0		; setup atdcsnul for proper form
	jmp	atdcsnul		; consume unknown command

atcrqq1:test	denyflg,tekxflg		; is auto Tek mode disabled?
	jnz	atcrqq0			; nz = yes, consume
ifndef	no_graphics
	mov	di,offset emubuf	; temp buffer
	mov	byte ptr [di],escape	; do ESC ^L to erase screen
	inc	di
	mov	byte ptr [di],FF
	inc	di
	mov	byte ptr [di],escape	; start DCS
	inc	di
	mov	byte ptr [di],'P'
	inc	di
	mov	ax,dparam[0]		; get first parameter
	call	dec2di
	mov	byte ptr [di],';'
	inc	di
	mov	ax,dparam[2]		; get second parameter
	call	dec2di			; write ascii value
	mov	byte ptr [di],';'
	inc	di
	mov	ax,dparam[4]		; get third parameter
	call	dec2di			; write ascii value
	mov	al,dcsstrf
	mov	byte ptr [di],al	; final char
	mov	byte ptr [di+1],0	; terminator
	mov	di,offset emubuf
	mov	al,yflags		; get yflags
	and	al,capt			; save logging bit
	push	ax
	and	yflags,not capt		; turn off logging bit
atcrqq2:mov	al,[di]
	inc	di
	or	al,al			; at the end?
	jz	atcrqq3			; z = yes
	push	di
	call	tekemu			; feed Tek emulator this string
	pop	di
	jmp	short atcrqq2		; do another string member
atcrqq3:mov	chcontrol,1		; turn on full cell char writing
	pop	ax			; recover logging bit
	or	yflags,al		; restate logging bit
endif	; no_graphics
	jmp	atnorm

ifndef	no_graphics
; State machine to process DCS strings of type "p" (restore color palette)
; Enter with "p" char in AL.
tekrcol	proc	near
	mov	ttstate,offset tekrco1	; next state is get parameter
	mov	ttstateST,offset tekrcost ; go here on ST
	push	es
	push	ds
	pop	es
	mov	cx,5			; five words
	xor	ax,ax
	mov	di,offset param		; clear parameters Pc,Pu,Px,Py,Pz
	cld
	rep	stosw
	pop	es
	mov	nparam,0		; work on initial parameter first
	ret
tekrco1:push	bx
	mov	bx,nparam		; parameter number
	shl	bx,1			; make it a word index
	mov	cx,param[bx]		; accumulated parameter
	call	getdec			; accumulate decimal value
	mov	param[bx],cx		; remember accumulation
	pop	bx
	jnc	tekrcos1		; nc = got a digit char
	inc	nparam			; say have another complete parameter
	cmp	al,'/'			; this kind of separator?
	je	tekrco3			; e = yes, finish
	cmp	al,';'			; break char is separator?
	jne	tekrco4			; ne = no, decode current sequence
tekrco3:cmp	nparam,5		; have 5 params already?
	jb	tekrcos1		; n = no, continue reading
tekrco4:call	tekrpal			; process parameters in msgibm file
	jmp	tekrcol			; start over on next field

tekrcost:mov	ttstate,offset atnrm	; get here on ST
	mov	ttstateST,offset atnorm ; default ST completion state
	cmp	nparam,5		; enough parameters to finish cmd?
	jb	tekrcos1		; b = no, abandon it
	call	tekrpal			; update from last data item
tekrcos1:ret
tekrcol	endp
endif	; no_graphics

; Accumulate decimal value in CX using ascii char in al.
; Return with value in CX. Return carry clear if ended on a digit,
; return carry set and ascii char in al if ended on a non-digit.
getdec	proc	near
	cmp	al,'0'			; a number?
	jb	getdecx			; b = no, quit
	cmp	al,'9'
	ja	getdecx			; a = not a number, quit
	sub	al,'0'			; remove ascii bias
	xchg	cx,ax			; put char in cx, decimal value in ax
	push	dx			; save reg
	push	bx
	mov	bx,10
	mul	bx			; times ten for a new digit
	pop	bx
	pop	dx			; recover reg, ignore overflow
	add	al,cl			; add current digit
	adc	ah,0			; 16 bits worth
	xchg	ax,cx			; rpt cnt back to cx
	clc				; say found a digit
	ret
getdecx:stc				; say non-digit (in al)
	ret
getdec	endp
					; Device Status Reports
atdsr:	mov	di,offset atdsr1	; routine to call
	call	atreps			; do for all parms
	ret
					; DSR workers
atdsr1:	mov	ax,param[si]
	cmp	lparam,0		; any intermediate?
	jne	atdsr2			; ne = yes, an intermediate
	cmp	ax,5			; operating status report?
	je	rpstat			; e = yes
	cmp	ax,6			; cursor position report?
	je	rpcup			; e = yes
	ret
atdsr2:	cmp	lparam,'?'		; DEC mode queries for below?
	jne	atdsr3			; no, skip them
	cmp	ax,6			; VT340 cursor report?
	je	rpcup			; e = yes
	cmp	ax,15			; printer status report?
	je	rpstap			; e = yes
	cmp	ax,25			; UDK status?
	jne	atdsr3			; ne = no
	jmp	rpudk			; do udk status rpt
atdsr3:	cmp	ax,26			; keyboard type?
	jne	atdsr4			; ne = no
	jmp	rpkbd			; do keyboard type report
atdsr4:	cmp	ax,256			; WordPerfect Tek screen query?
	jne	atdsr5			; ne = no
ifndef	no_graphics
	jmp	tekrpt			; do Tek report
endif	; no_graphics
atdsr5:	ret				; must have been an echo

rpstat:	mov	ttyact,0		; group output for networks
	mov	al,Escape		; operating status query
	call	prtbout
	mov	al,'['
	call	prtbout
	mov	al,'0'			; tell them we think we are OK
	call	prtbout
	mov	ttyact,1		; end group output for networks
	mov	al,'n'
	call	prtbout
	ret

rpcup:	mov	ttyact,0		; group output for networks
	mov	al,Escape		; cursor position report
	call	prtbout
	mov	al,'['
	call	prtbout
	mov	al,byte ptr cursor+1	; get row
	inc	al			; map to origin at 1,1 system
	test	vtemu.vtflgop,decom	; Origin mode set?
	jz	rpcup1			; z = no
	sub	al,mar_top		; subtract off top margin
rpcup1: call	prtnout			; output the number
	mov	al,';'
	call	prtbout
	mov	al,byte ptr cursor	; column number
	inc	al			; map to origin at 1,1 system
	call	prtnout
	mov	ttyact,1		; end group output for networks
	mov	al,'R'			; final char
	call	prtbout
	ret

rpstap:	mov	ttyact,0		; group output for networks
	mov	al,Escape		; printer port query
	call	prtbout
	mov	al,'['
	call	prtbout
	mov	al,'?'			;  10 = printer ready, 13 = not ready
	call	prtbout
	mov	al,'1'
	call	prtbout
	mov	ah,ioctl		; get printer status, via DOS
	mov	al,7			; status for output
	push	bx
	mov	bx,4			; std handle for system printer
	int	dos
	pop	bx
	jc	rpstap1			; c = call failed
	cmp	al,0ffh			; code for Ready
	jne	rpstap1			; ne = not ready
	mov	al,'0'			; ready, send final digit
	jmp	short rpstap2
rpstap1:mov	al,'3'			; not ready, say printer disconnected
rpstap2:call	prtbout
	mov	ttyact,1		; end group output for networks
	mov	al,'n'			; final char of response
	call	prtbout
	ret

rpudk:	mov	ttyact,0		; group output for networks
	mov	al,Escape		; response to UDK locked query
	call	prtbout
	mov	al,'['
	call	prtbout
	mov	al,'?'
	call	prtbout
	mov	al,20			; say keys are unlocked (locked=21)
	call	prtnout
	mov	ttyact,1		; end group output for networks
	mov	al,'n'			; final char
	call	prtbout
	ret

rpkbd:	mov	ttyact,0		; group output for networks
	mov	al,Escape		; response to kbd type query
	call	prtbout
	mov	al,'['
	call	prtbout
	mov	al,'?'
	call	prtbout
	mov	al,27			; keyboard dialect follows
	call	prtnout
	mov	al,';'
	call	prtbout
	mov	bl,vtemu.vtchset	; get Kermit NRC code (0-13)
	xor	bh,bh
	mov	al,nrckbd[bx]		; get DEC keyboard code from table
	call	prtnout
	mov	ttyact,1		; end group output for networks
	mov	al,'n'
	call	prtbout
	ret

ifndef	no_graphics
tekrpt:	call	tekinq			; get Tek screen size and num colors
	push	cx			; screen colors
	push	bx			; screen width
	push	ax			; screen height
	mov	ttyact,0		; group output for networks
	mov	al,Escape		; response to Tek query
	call	prtbout
	mov	al,'['
	call	prtbout
	mov	al,'?'
	call	prtbout
	mov	di,offset emubuf	; working buffer
	mov	byte ptr [di],0		; insert terminator
	mov	ax,256			; first parameter
	call	dec2di			; write ascii digits
	mov	byte ptr [di],';'	; separator
	inc	di
	pop	ax			; get screen height
	call	dec2di
	mov	byte ptr [di],';'	; separator
	inc	di
	pop	ax			; get screen width
	call	dec2di
	mov	byte ptr [di],';'	; separator
	inc	di
	pop	ax			; get number screen color (0, 1 or 16)
	call	dec2di
	mov	byte ptr[di],'n'	; end of sequence
	inc	di
	mov	cx,di			; compute string length
	mov	di,offset emubuf
	sub	cx,di
tekrpt1:mov	al,[di]			; get a string char
	inc	di
	cmp	cx,1			; last char?
	ja	tekrpt2			; a = no
	mov	ttyact,1		; end group output for networks
tekrpt2:call	prtbout			; send it
	loop	tekrpt1
	ret
endif	; no_graphics

atrqtsr:cmp	flags.vtflg,ttheath	; Heath-19? ESC [ u
	jne	atrqts1			; ne = no
	cmp	nparam,0		; ought to have no parameters
	jne	atrqts2			; ne = oops, not H-19 command, ignore
	jmp	atrc			; H19, restore cursor pos and attrib
	
atrqts1:cmp	inter,'$'		; VT320 Terminal State Rpt DECRQTSR?
	jne	atrqts2			; ne = no
	cmp	param,1			; report required?
	je	atrqts4			; e = yes
	cmp	param,2			; VT340 color palette report?
	jne	atrqts1a		; ne = no
ifndef	no_graphics
	call	tekinq			; get Tek screen state
	call	tekpal			; do palette report in Tek emulator
endif	; no_graphics
atrqts1a:ret
atrqts2:cmp	inter,'&'		; DECRQUPSS, User preferred Supp Set?
	je	atrqts5			; e = yes
	cmp	ninter,0		; any intermediates?
	jne	atrqts3			; ne = yes
	jmp	atrc			; ANSI restore cursor ESC [ s
atrqts3:ret				; else ignore
atrqts4:mov	al,Escape		; Terminal state report
	call	prtbout
	mov	al,'P'			; DCS, ESC P
	call	prtbout
	mov	al,byte ptr param
	call	prtnout			; output as ascii digits, no echo
	mov	al,'$'
	call	prtbout			; output char, no echo
	mov	al,'s'			; Final char to main DCS part
	call	prtbout
	mov	al,Escape
	call	prtbout
	mov	al,'\'			; string terminator ST (ESC \)
	call	prtbout
	ret

atrqts5:mov	al,Escape		; User Preferred Supplemental Set
	call	prtbout
	mov	al,'P'			; DCS, ESC P
	call	prtbout			;  report
	mov	al,'0'			; assume 94 byte set
	cmp	upss,94			; 94 byte set?
	je	atrqts6			; e = yes
	inc	al			; change to 96 byte size
atrqts6:call	prtbout
	mov	al,'!'
	call	prtbout
	mov	al,'u'
	call	prtbout
	mov	al,upss+1		; first ident char
	call	prtbout
	mov	al,upss+2		; second char, if any
	or	al,al
	jz	atrqts7			; z = no second char
	call	prtbout
atrqts7:mov	al,Escape
	call	prtbout
	mov	al,'\'			; string terminator ST (ESC \)
	call	prtbout
	ret
					; Request Presentation State Report
atrqpsr:cmp	inter,'$'		; proper form?
	jne	atrqps1			; ne = no, ignore
	cmp	param,1			; cursor report?
	je	atrqps2			; e = yes
	cmp	param,2			; tabstop report?
	jne	atrqps1			; ne = no, ignore
	jmp	atrqps40		; do tabstop report
atrqps1:ret				; else ignore

atrqps2:mov	al,Escape		; cursor report, start
	call	prtbout
	mov	al,'P'			; DCS, ESC P
	call	prtbout
	mov	al,'1'
	call	prtbout
	mov	al,'$'
	call	prtbout
	mov	al,'u'
	call	prtbout
	mov	al,dh			; row of cursor
	inc	al			; count from 1,1
	call	prtnout			; output number
	mov	al,';'
	call	prtbout
	mov	al,dl			; column of cursor
	inc	al			; count from 1,1
	call	prtnout			; output number
	mov	al,';'
	call	prtbout
	mov	al,'1'			; video page, always 1 for VT320
	call	prtbout
	mov	al,';'
	call	prtbout
	mov	al,40h			; start bit field template
	test	extattr,att_rev		; reverse video char writing on?
	jz	atrqps3			; z = no
	or	al,8			; set the bit
atrqps3:call	getblink		; ah will be non-zero if blinking
	or	ah,ah			; blinking?
	jz	atrqps4			; z = no
	or	al,4			; set the bit
atrqps4:call	getunder		; ah will be non-zero if underlining
	or	cl,cl			; underlining?
	jz	atrqps5			; z = no
	or	al,2			; set the bit
atrqps5:call	getbold			; ax will be non-zero if bolding
	or	ah,ah			; bold?
	jz	atrqps6			; z = no
	or	al,1			; set the bit
atrqps6:call	prtbout
	mov	al,';'
	call	prtbout
	mov	al,40h			; Satt (Selective params)
	test	extattr,att_protect	; is char protected?
	jz	atrqps6a		; z = no
	or	al,1			; say char is protected
atrqps6a:call	prtbout			; output required skeleton
	mov	al,';'
	call	prtbout
	mov	al,40h			; Sflag (shift/wrap/origin mode)
	cmp	atwrap,0		; wrap pending?
	je	atrqps7			; e = no
	or	al,8			; set the bit
atrqps7:cmp	SSptr,offset G3set	; SS3: G3 mapped to GL for next char?
	jne	atrqps8			; ne = no
	or	al,4			; set the bit
atrqps8:cmp	SSptr,offset G2set	; SS2: G2 mapped to GL for next char?
	jne	atrqps9			; ne = no
	or	al,2			; set the bit
atrqps9:test	vtemu.vtflgop,decom	; Origin mode set?
	jz	atrqps10		; z = no
	or	al,1			; set the bit
atrqps10:call	prtbout
	mov	al,';'
	call	prtbout
	mov	al,'0'			; Pgl, say which set is in GL
	mov	si,GLptr		; setup for worker
	call	atrqps30		; worker returns proper al
	call	prtbout
	mov	al,';'
	call	prtbout
	mov	al,'0'			; Pgr, say which set is in GR
	mov	si,GRptr		; setup for worker
	call	atrqps30		; worker returns proper al
	call	prtbout
	mov	al,';'
	call	prtbout
	mov	al,40h			; Scss, char set size bit field
	call	atrqp15			; call worker to fill in al
	call	prtbout	
	mov	al,';'
	call	prtbout
	mov	bx,offset G0set		; Sdesig, get 1-2 letter ident
	call	atrqps20		; G0, let worker fill in response
	mov	bx,offset G1set
	call	atrqps20		; G1, let worker fill in response
	mov	bx,offset G2set
	call	atrqps20		; G2, let worker fill in response
	mov	bx,offset G3set
	call	atrqps20		; G3, let worker fill in response
	mov	al,Escape
	call	prtbout
	mov	al,'\'			; string terminator ST (ESC \)
	call	prtbout
	ret

; worker for Character set size reporting
atrqp15:cmp	G0set+gsize,96		; is G0 a 96 byte set?
	jne	atrqp16			; ne = no
	or	al,1			; say 96
atrqp16:cmp	G1set+gsize,96		; is G1 a 96 byte set?
	jne	atrqp17			; ne = no
	or	al,2			; say 96
atrqp17:cmp	G2set+gsize,96		; G2 set?
	jne	atrqp18
	or	al,4			; say 96
atrqp18:cmp	G3set+gsize,96		; G3 set?
	jne	atrqp19
	or	al,8			; say 96
atrqp19:ret				; return with al setup

; worker for Character set ident reporting at atrqps16: et seq
atrqps20:mov	al,[bx+gsize+1]		; Gn set pointer, first letter
	call	prtbout
	mov	al,[bx+gsize+2]		; second letter
	or	al,al			; is there one?
	jz	atrqps21		; z = no, nothing there
	call	prtbout
atrqps21:ret

; worker. Enter with SI holding GLptr or GRptr and al = '0'
; Returns al = '0' .. '3' to match set pointed at
atrqps30:cmp	si,offset G0set		; si points at G0?
	je	atrqps31		; e = yes
	inc	al			; try next set
	cmp	si,offset G1set		; si points at G1?
	je	atrqps31
	inc	al
	cmp	si,offset G2set		; si points at G2?
	je	atrqps31
	inc	al			; must be G3
atrqps31:ret

atrqps40:mov	al,Escape		; start tabstop report
	call	prtbout
	mov	al,'P'			; DCS, ESC P
	call	prtbout
	mov	al,'2'			; tabs
	call	prtbout
	mov	al,'$'
	call	prtbout
	mov	al,'u'
	call	prtbout
	mov	cl,mar_right		; right most column number
	inc	cl			; number of columns
	xor	ch,ch
	push	dx			; save dx
	xor	dx,dx			; dh for done one output, dl = column
	mov	si,offset tabs		; active tabs buffer
atrqps41:call	istabs			; tab inquiry routine, column is in dl
	jnc	atrqps43		; nc = no tab
	or	dh,dh			; sent one value already?
	je	atrqps42		; e = no, so no separator
	mov	al,';'			; separator (DEC used '/')
	call	prtbout
atrqps42:mov	al,dl			; get column
	inc	al			; count columns from 1 for host
	call	prtnout			; output the number
	inc	dh			; say sent a number
atrqps43:inc	dl			; next column, say sent one output
	loop	atrqps41		; do the rest
	pop	dx			; recover dx
	mov	al,Escape
	call	prtbout
	mov	al,'\'			; string terminator ST (ESC \)
	call	prtbout
	ret
	
; Process Restore Presentation Reports, for cursor and tab stops
; Uses bytes dinter+5 and dinter+6 as internal variables
atrp:	cmp	dinter,0+'$'		; correct intermediate?
	je	atrp1			; e = yes
	jmp	atcrqxx			; send back "illegal restore" response
atrp1:	cmp	dparam,1		; cursor info?
	je	atrp4			; e = yes
	mov	modeset,1		; say setting tabs
	call	atrpw			; call worker to do ascii to binary
	dec	dl			; count internally from col 0
	call	tabset			; set tab in column dl
atrp3:	mov	emubufc,0		; clear the string count
	ret
			  		; start cursor info report playback
atrp4:	cmp	dinter+5,0		; our internal counter in vacant byte
	jne	atrp5			; not initial byte
	inc	dinter+5		; point to next item next time
	call	atrpw			; ascii to binary worker
	xchg	dh,dl			; get row to correct byte
	mov	dl,byte ptr cursor+1	; get column
	jmp	atsetcur		; set the cursor
atrp5:	cmp	dinter+5,1		; column?
	jne	atrp6
	inc	dinter+5		; point to next item next time
	call	atrpw			; ascii to binary worker
	mov	dh,byte ptr cursor	; get row
	jmp	atsetcur		; set the cursor
atrp6:	cmp	dinter+5,2		; page?
	jne	atrp7
	inc	dinter+5		; omit page byte
	ret
atrp7:	cmp	dinter+5,3
	jne	atrp8
	inc	dinter+5		; Srend
	mov	al,emubuf		; string byte
	mov	ah,curattr		; attributes field
					; ought to clear attributes first
	test	al,1			; set bold?
	jz	atrp7a			; z = no
	call	setbold
atrp7a:	test	al,2			; set underline?
	jz	atrp7b			; z = no
	call	setunder
atrp7b:	test	al,4			; set blink?
	jz	atrp7c			; z = no
	call	setblink
atrp7c:	mov	curattr,ah		; attributes so far
	test	al,8			; set per char rev video?
	jz	atrp7d			; z = no
	call	setrev			; set reversed video
	mov	curattr,ah		; gather main attributes
atrp7d:	ret
atrp8:	cmp	dinter+5,4
	jne	atrp9
	inc	dinter+5		; Satt, skip it
	ret
atrp9:	cmp	dinter+5,5
	jne	atrp10
	inc	dinter+5
	mov	al,emubuf		; string byte
	mov	ah,al
	and	ah,8			; autowrap bit
	mov	atwrap,ah		; set it
	mov	SSptr,0			; say no single shift needed
	test	al,4			; SS3 bit?
	jz	atrp9a			; z = no
	mov	SSptr,offset G3set	; set the pointer
atrp9a:	test	al,2			; SS2 bit?
	jz	atrp9b			; z = no
	mov	SSptr,offset G2set	; set the pointer
atrp9b:	and	vtemu.vtflgop,not decom ; clear origin bit
	test	al,1			; origin mode?
	jz	atrp9c			; z = no
	or	vtemu.vtflgop,decom	; set origin mode
atrp9c:	ret
atrp10:	cmp	dinter+5,6		; Pgl
	jne	atrp11
	inc	dinter+5
	mov	al,emubuf		; string byte
	call	atrpw5			; call worker to setup bx with ptr
	mov	GLptr,bx
	ret
atrp11:	cmp	dinter+5,7		; Pgr
	jne	atrp12
	inc	dinter+5
	mov	al,emubuf		; string byte
	call	atrpw5			; call worker to setup bx with ptr
	mov	GRptr,bx
	ret
atrp12:	cmp	dinter+5,8		; Scss
	jne	atrp13			; ne = no
	inc	dinter+5
	mov	al,emubuf		; string byte
	and	al,0fh			; strip ascii bias
	mov	dinter+6,al		; save here for Sdesig byte, next
	ret
atrp13:	cmp	dinter+5,9		; Sdesig
	jne	atrp14
	inc	dinter+5
	mov	si,offset emubuf	; string
	xor	cx,cx			; init loop counter to 0
atrp13a:mov	al,'('			; assume G0 is 94 byte set
	add	al,cl			; plus loop index to get set pointer
	shr	dinter+6,1		; get set size bit
	jnc	atrp13b			; e = correct
	add	al,4			; map to 96 byte indicator
atrp13b:mov	inter,al		; store size byte as intermediate
	mov	ninter,1		; one char
	cld
atrp13c:lodsb				; next string byte
	test	al,not 2fh		; is there a second intermediate byte?
	jnz	atrp13d			; nz = no
	mov	inter+1,al		; store intermediate
	inc	ninter			; count them
	jmp	short atrp13c		; try again for a Final char
atrp13d:push	si
	push	cx
	mov	bx,offset ansesc	; table to use
	call	atdispat		; dispatch on final char to set ptr
	pop	cx
	pop	si
	inc	cx
	cmp	cx,3			; doing last one?
	jbe	atrp13a			; be = no, do all four
	ret
atrp14:	jmp	atcrqxx			; send back "illegal restore" response

					; worker, ascii string to decimal byte
atrpw:	mov	cx,emubufc		; length of this string
	jcxz	atrpw3			; nothing there
	mov	si,offset emubuf	; address of string
	xor	dl,dl			; init final value
	cld
atrpw2:	lodsb				; read a digit
	sub	al,'0'			; ascii to numeric
	jc	atrpw3			; c = trouble
	shl	dl,1			; previous contents times 10
	mov	dh,dl
	shl	dl,1
	shl	dl,1
	add	dl,dh
	add	dl,al			; plus new value
	loop	atrpw2			; do all digits
atrpw3:	ret
	   				; char set selector worker
atrpw5:	cmp	al,'0'			; bx gets G0set...G3set, based on AL
	jne	atrpw5a
	mov	bx,offset G0set
	ret
atrpw5a:cmp	al,'1'
	jne	atrpw5b
	mov	bx,offset G1set
	ret
atrpw5b:cmp	al,'2'
	jne	atrpw5c
	mov	bx,offset G2set
	ret
atrpw5c:mov	bx,offset G3set
	ret

; Select Active Display. When selecting the status line make new scrolling
; margins be just the status line and force on Origin mode. Save the regular
; margins and origin mode for restoration when regular display is re-selected.
; Also CSI Pn; Pn; Pn; Pn ~ invokes Lotus macro PRODUCT
atsasd	proc	near
	cmp	inter,'$'		; correct intermediate?
	jne	atsasd1			; ne = no
	cmp	param,1			; select which display
	jb	atsasd4			; b = select main display
	ja	atsasd1			; a = illegal value
	cmp	flags.modflg,2		; mode line host owned?
	jne	atsasd1			; ne = no, ignore command
	test	dspstate,dsptype	; was previous display = status line?
	jz	atsasd2			; z = no
atsasd1:ret				; else do nothing

atsasd2:push	word ptr mar_top	; save scrolling margins
	pop	dspmsave		; save scrolling margins
	or	dspstate,dsptype	; say status line is active
	mov	al,byte ptr low_rgt+1	; get last text line
	inc	al			; status line
	mov	mar_top,al
	mov	mar_bot,al		; new scrolling margins
	and	dspstate,not dspdecom	; clear remembered origin mode
	test	vtemu.vtflgop,decom	; was origin mode active?
	jz	atsasd3			; z = no
	or	dspstate,dspdecom	; remember origin mode was active
atsasd3:or	vtemu.vtflgop,decom	; set origin mode
	call	atsc			; save cursor material
	call	chrdef			; reinit char sets from master setup
	mov	dx,dspcstat		; get status line cursor
	mov	dh,mar_top		; set row
	jmp	atsetcur		; set cursor

atsasd4:test	dspstate,dsptype	; was previous display = status line?
	jnz	atsasd5			; nz = yes
	ret				; else do nothing	
atsasd5:push	dspmsave		; restore scrolling margins
	pop	word ptr mar_top
	and	vtemu.vtflgop,not decom	; clear origin mode bit
	test	dspstate,dspdecom	; was origin mode on for main screen?
	jz	atsasd6			; z = no
	or	vtemu.vtflgop,decom	; set it now
atsasd6:push	cursor			; get status line cursor position
	pop	dspcstat		; save it
	mov	dspstate,0		; say now doing main screen
	jmp	atrc			; restore cursor material
atsasd	endp

atssdt	proc	near			; Select Status Line Type, DECSSDT
	cmp	inter,'$'		; correct intermediate char?
	je	atssdt1			; e = yes
	cmp	ninter,0		; no intermediates?
	jne	atssdt0			; ne = no
	call	fproduct		; do PRODUCT macro
atssdt0:ret
atssdt1:test	dspstate,dsptype	; on mode line already?
	jnz	atssdt4			; nz = yes, cannot reselect now
	cmp	param,0			; turn off status line?
	jne	atssdt2			; ne = no
	push	dx			; save cursor position
	call	fclrmod			; clear the line
	pop	dx
	or	yflags,modoff		; now say it's off
	mov	flags.modflg,1		; say mode line is owned by us
	ret
atssdt2:cmp	param,1			; regular status line?
	jne	atssdt3			; ne = no
	push	dx
	call	fmodlin			; turn on regular mode line
	pop	dx
	and	yflags,not modoff	; and say it's on
	mov	flags.modflg,1		; say mode line is owned by us
	ret
atssdt3:cmp	param,2			; host writable?
	jne	atssdt4			; ne = no
	mov	flags.modflg,2		; say mode line is owned by host
atssdt4:ret
atssdt	endp

; VT52 compatibility mode routines.

; Return to ANSI mode.

v52ans: or	vtemu.vtflgop,decanm	; turn on ANSI flag
	mov	ax,oldterm		; terminal type at startup
	cmp	ax,ttvt52		; was VT52 the prev kind?
	jne	v52ans1			; ne = no
	mov	ax,ttvt320		; use VT320
v52ans1:mov	oldterm,ax
	mov	flags.vtflg,ax		; restore it
	call	chrdef			; set default char sets
	call	atsc			; save cursor status
	test	yflags,modoff		; mode line supposed to be off?
	jnz	v52ans2			; nz = yes
	call	fmodlin			; rewrite mode line
v52ans2:ret
	
; VT52 cursor positioning.

v52pos: mov	ttstate,offset v52pc1	; next state
	ret
v52pc1: sub	al,' '-1		; minus offset
	xor	ah,ah
	mov	param,ax		; stash it here
	mov	ttstate,offset v52pc2	; next state
	ret
v52pc2: sub	al,' '-1		; minus offset
	xor	ah,ah
	mov	param+2,ax		; stash here
	mov	ttstate,offset atnrm	; reset state to "normal"
	jmp	atcup			; position and return

; VT52 print controls

v52ps:	mov	param,0			; print screen
	mov	lparam,0
	jmp	ansprt			; simulate ESC [ 0 i
v52pl:	mov	param,1			; print line
	jmp	short v52pcom		; simulate ESC [ ? 1 i
v52pcb:	mov	param,5			; Enter printer controller on
	jmp	short v52pcom		; simulate ESC [ ? 5 i
v52pce:	mov	param,4			; Exit printer controller on
;	jmp	short v52pcom		; simulate ESC [ ? 4 i
v52pcom:mov	lparam,'?'		; simulate ESC [ ? <number> i
	jmp	ansprt			; process command

v52sgm:	mov	setptr,offset G0set	; enter/exit special graphics mode
	cmp	al,'F'			; enter VT52 graphics mode?
	jne	v52sgm1			; ne = no, exit and return to ASCII
	jmp	mkdecspec		; 'G' make DEC special graphics in G0
v52sgm1:jmp	mkascii			; make ASCII in G0

; Heath-19 special functions

h19sans:or	vtemu.vtflgop,decanm	; Turn on ANSI flag. ESC <
	jmp	chrdef			; set default char sets
					; clear screen and go home

h19ed:	cmp	param,0			; Erase cursor to end of screen?
	jne	h19ed2			; ne = no
	mov	ax,dx			; start at cursor
	mov	bx,low_rgt		; lower right corner
	cmp	bh,dh			; on status line?
	jae	h19ed1			; ae = no
	mov	bh,dh			; put end on status line
h19ed1:	call	vtsclr			; clear it
	ret
h19ed2:	cmp	param,1			; erase start of display to cursor?
	je	h19esos			; e = yes
	cmp	param,2			; erase entire screen?
	je	h19clrs			; e = yes
	ret				; else ignore

					; erase entire screen
h19clrs:cmp	dh,byte ptr low_rgt+1	; on status line?
	ja	h19erl			; a = yes, do just erase in line
	xor	dx,dx			; go to upper left corner
	call	atsetcur		; do it
	xor	ax,ax			; clear screen from (0,0)
	mov	bx,low_rgt		; to lower right corner
	call	vtsclr			; clear it
	ret

h19erl:	xor	al,al			; erase whole line
	mov	bl,byte ptr low_rgt	; physical width
	jmp	erinline		; erase whole line, cursor stays put

h19ero:	xor	al,al			; erase start of line to cursor
	mov	bl,dl
	jmp	erinline		; clear that part of line

					; erase start of screen to cursor
h19esos:cmp	dh,byte ptr low_rgt+1	; on status line?
	ja	h19ero			; a = yes, do just erase in line
	jmp	ersos			; do regular erase start of screen

h19wrap:or	vtemu.vtflgop,decawm	; turn on line wrapping
	ret
h19nowrp:and	vtemu.vtflgop,not decawm ; turn off line wrapping
	ret

h19herv:mov	ah,curattr		; get current cursor attribute
	mov	cl,extattr
	call	setrev			; ESC p set reversed video
	mov	curattr,ah		; store new attribute byte
	ret

h19hxrv:mov	ah,curattr		; get current cursor attribute
	mov	cl,extattr
	call	clrrev			; ESC q set normal video
	mov	curattr,ah		; store new attribute byte
	ret

h19sc:	mov	dx,cursor
	mov	h19cur,dx		; save cursor position
	ret

h19rc:	mov	dx,h19cur		; saved cursor position
	jmp	atsetcur			; set cursor and return

					; Heath-19 set mode "ESC x "
h19smod:mov	ttstate,offset hsmod	; setup to parse rest of seq
	ret
hsmod:	mov	modeset,1		; say set mode
	mov	ttstate,offset atnrm
	sub	al,'0'			; remove ascii bias
	jmp	htrsm1			; perform mode set

h19cmod:mov	ttstate,offset hcmod	; setup to parse rest of seq
	ret

hcmod:	mov	modeset,0		; say reset mode
	mov	ttstate,offset atnrm
	sub	al,'0'			; remove ascii bias
	jmp	htrsm1			; perform mode reset

hrcup:	mov	al,escape		; send "ESC Y row col" cursor report
	call	prtbout			; send with no local echo
	mov	al,'Y'
	call	prtbout
	mov	al,byte ptr cursor+1	; get row
	add	al,' '			; add ascii bias

	call	prtbout			; send it
	mov	al,byte ptr cursor	; get column
	add	al,' '			; add ascii bias
	call	prtbout			; and send it too
	ret

; Insert/Delete characters and lines
inslin	proc	near
	mov	ax,param		; insert line
	or	ax,ax			; any args?
	jne	insli1			; ne = yes
	inc	ax			; insert one line
insli1:	mov	scroll,al		; lines to scroll
	mov	dx,cursor		; current position
	cmp	dh,mar_bot		; below bottom margin?
	ja	insli3			; a = below bottom margin
	push	word ptr mar_top
	mov	mar_top,dh		; call present position the top
	call	atscrd			; scroll down
	pop	word ptr mar_top	; restore margins
	xor	dl,dl			; go to left margin
	test	flags.vtflg,ttd463+ttd470+ttd217 ; DG D463/D470/D217 mode?
	jz	insli2			; z = no
	jmp	dgsetcur		; DG set cursor with protection
insli2:	jmp	atsetcur		; reposition cursor and return
insli3: ret
inslin	endp

dellin	proc	near
	mov	ax,param		; delete line(s)
	or	ax,ax			; any args?
	jne	delli1			; ne = yes
	inc	ax			; insert one line
delli1:	mov	scroll,al		; line count
	mov	dx,cursor		; where we are presently
	cmp	dh,mar_bot		; at or below bottom margin?
	jae	delli3			; ae = yes, do not scroll
	push	word ptr mar_top	; save current scrolling margins
	mov	mar_top,dh		; temp top margin is here
	call	atscru			; scroll up
	pop	word ptr mar_top	; restore scrolling margins
	test	flags.vtflg,ttd463+ttd470+ttd217 ; DG D463/D470/D217 mode?
	jz	delli2			; z = no
	jmp	dgsetcur		; DG set cursor with protection
delli2:	jmp	atsetcur		; restore cursor
delli3: ret
dellin	endp

ansich	proc	near			; ANSI insert characters ESC [ Pn @
	mov	cx,param
	or	cx,cx			; any arguments?
	jne	ansic1			; ne = no, ignore
	inc	cx			; use one
ansic1:	push	bx			; use this as insert/delete flag
	mov	bh,1			; do an insert operation
ansic2:	call	insdel			; do common insert/delete code
	pop	bx
	ret
ansich	endp

inschr	proc	near			; insert open (space) char at cursor
	push	bx			; use this as insert/delete flag
	mov	bh,1			; do an insert operation
	mov	cx,1			; do one character
	call	insdel			; do common insert/delete code
	pop	bx
	ret
inschr	endp

atdelc	proc	near
	mov	cx,param		; Delete characters(s)
	or	cx,cx			; zero becomes one operation
	jnz	atdelc1
	inc	cx			; delete one char. Heath ESC N
atdelc1:push	bx			; use this as insert/delete flag
	mov	bh,-1			; do a delete operation
atdelc2:call	insdel			; do common insert/delete code
	pop	bx
	ret
atdelc	endp

					; Common code for insert/delete char
insdel	proc	near			; BH has insert/delete code
	mov	dx,cursor		; logical cursor
	cmp	decrlm,0		; host writing direction active?
	je	insdel11		; e = no
	call	hldirection
insdel11:
	push	bx
	mov	bl,dh			; row
	xor	bh,bh
	mov	bl,linetype[bx]
	mov	thisline,bl
	or	bl,bl			; single width line?
	pop	bx
	jz	insdel1			; z = yes
	add	dl,dl			; double the cursor column
	add	cx,cx			; double repeat count
	test	flags.vtflg,ttd463+ttd470+ttd217 ; DG D463/D470/D217 mode?
	jz	insdel1			; z = no
	shl	mar_right,1		; this one doubles the margins
insdel1:mov	bl,mar_right
	inc	bl			; number of screen columns
	sub	bl,dl			; width - cursor
	cmp	cl,bl			; skipping more than screen width?
	jbe	insdel2			; be = no
	mov	cl,bl			; limit to screen width please
insdel2:
; dh=logical cursor row, dl= logical cursor column, cx has repeat count
; bl = logical screen width - 1, bh = +1 for insert, -1 for delete chars.
	mov	bl,cl			; offset
	xor	ch,ch
	or	bh,bh			; ins or del?
	jl	insdel5			; l = delete
					; Insert processor
	mov	cl,mar_right		; right margin
	sub	cl,dl			; minus cursor location
	mov	dl,mar_right		; start at right margin
	jcxz	insdel7			; z = nothing to do
insdel4:push	cx
	push	dx
	sub	dl,bl			; back up by offset
	call	hldirection
	call	getatch			; read char from vscreen
	pop	dx
	push	dx
	call	hldirection
	call	qsetatch		; write it farther to the right
	pop	dx
	pop	cx
	dec	dl			; backup one column
	loop	insdel4
	jmp	short insdel7
		  			; Delete processor
insdel5:mov	cl,mar_right		; right margin
	sub	cl,dl			; minus starting position
	sub	cl,bl			; minus displacement (num deletes)
	inc	cl			; count column 0
insdel6:push	cx
	push	dx
	add	dl,bl			; look to right
	call	hldirection
	call	getatch			; read char from vscreen
	pop	dx
	push	dx
	call	hldirection
	call	qsetatch		; write it farther to the left
	pop	dx
	pop	cx
	inc	dl			; next column
	loop	insdel6

insdel7:mov	cl,bl			; fill count
	xor	ch,ch
	jcxz	insdel9			; z = empty
	mov	ah,scbattr		; get fill
	mov	al,' '
insdel8:push	cx
	xor	cl,cl			; extended attributes
	push	dx
	call	hldirection
	call	qsetatch		; write new char
	pop	dx
	inc	dl			; next column
	pop	cx
	loop	insdel8

insdel9:mov	dx,cursor		; logical cursor again
	push	cursor
	cmp	thisline,0		; is line already single width?
	je	insde10			; e = yes
	add	dl,dl			; move to double char cell
	test	flags.vtflg,ttd463+ttd470+ttd217 ; DG D463/D470/D217 mode?
	jz	insde10			; z = no
	shr	mar_right,1		; this one doubles the margins
insde10:call	atsetcur		; set it to current char
	mov	dl,dh			; rows to update
	call	touchup
	pop	cursor
	mov	dx,cursor		; in case we are called indirectly
	ret
insdel	endp

noins:	mov	insmod,0		; turn off insert mode
	ret

entins:	mov	insmod,0ffh		; enter insert mode
	ret

; Line type to/from single or double
linesgl	proc	near			; convert line to single width char
	push	ax
	push	bx
	push	cx
	push	dx
	mov	bx,dx			; cursor
	mov	bl,bh
	xor	bh,bh			; bx now holds row
	cmp	linetype [bx],0		; is line already single width?
	je	linsglx			; e = yes
	mov	linetype [bx],0		; say will be single now
	mov	dh,byte ptr cursor+1	; row
	xor	dl,dl			; start in column 0
	mov	cl,mar_right		; number of columns on screen - 1
	inc	cl
	shr	cl,1			; number of columns to do
	xor	ch,ch
	push	cx			; save around loop below
linsgl1:push	cx			; save loop counter
	push	dx
	shl	dl,1			; double column number
	call	direction		; set dx to desired position
	call	getatch			; read char (al) and attribute (ah)
	pop	dx			; logical attribute to cl
	push	dx
	call	direction		; set dx to desired position
	call	qsetatch		; write char (al) and attribute (ah)
	pop	dx			; and logical attribute is in cl
	inc	dl			; next column
	pop	cx
	loop	linsgl1
	pop	cx			; recover column counter
	mov	dl,cl
linsgl2:push	cx			; save counter
	push	dx
	call	direction		; set dx to desired position
	mov	ah,scbattr		; screen background
	xor	cl,cl			; extended attribute
	mov	al,' '
	call	qsetatch		; write char
	pop	dx
	pop	cx
	inc	dl			; next column
	loop	linsgl2			; repeat for all characters
	mov	dl,dh			; rows to touchup
	call	touchup
linsglx:pop	dx
	pop	cx
	pop	bx
	pop	ax
	push	cursor
	call	atsetcur		; set visible cursor
	pop	cursor
	ret
linesgl	endp

linedbl	proc	near			; convert line to double width char
	push	ax			; must reset physical cursor
	push	bx			; to same char as before expansion
	push	cx			; but does not modify variable cursor
	push	dx
	mov	bx,dx			; cursor
	mov	bl,bh
	xor	bh,bh			; bx now holds row
	cmp	linetype [bx],0		; is line single width?
	jne	lindblx			; ne = no. nothing to do
	mov	linetype [bx],1		; say will be double width now
	mov	cl,mar_right		; number of columns on the screen - 1
	inc	cl
	xor	ch,ch
	shr	cl,1			; number of items to do
	mov	dl,cl
	dec	dl
lindbl1:push	cx			; save loop counter
	push	dx
	call	direction		; set dx to desired position
	call	getatch			; read char (al) and attribute (ah)
	pop	dx			; extended attribute is in cl
	shl	dl,1			; double the column number
	push	dx
	call	direction		; set dx to desired position
	call	qsetatch		; write char and attribute
	pop	dx
	inc	dl			; move to second column of double
	push	dx
	call	direction		; set dx to desired position
	mov	al,' '			; space as filler
	call	qsetatch		; write that char
	pop	dx
	dec	dl
	shr	dl,1
	dec	dl
	pop	cx
	loop	lindbl1
	mov	dl,dh			; rows to touchup
	call	touchup
lindblx:pop	dx
	pop	cx
	pop	bx
	pop	ax
	push	cursor
	call	atsetcur		; set visible cursor
	pop	cursor
	ret
linedbl	endp

; Printer support routines
ansprt	proc near
	mov	di,offset ansprt0	; routine to process arguments
	call	atreps			; repeat for all parms
	ret

ansprt0:mov	ax,param[si]		; pick up the argument
	or	ax,ax			; 0 (print all/part of screen)?
	jnz	ansprt1			; nz = no
	cmp	ninter,0		; unwanted intermediates?
	jne	anspr4a			; ne = got one, illegal here
	call	fpntchk			; check printer
	call	pntext			; do whole screen or scrolling extent
	jmp	atsetcur		; reposition cursor and return

ansprt1:cmp	ax,1			; 1 (print current line)?
	jne	ansprt4			; ne = no
	call	fpntchk			; check for printer ready
	call	pntlin			; print current line
	mov	al,LF
	call	fpntchr
	call	fpntflsh		; flush printer buffer
	jmp	atsetcur		; reposition cursor and return

ansprt4:cmp	ax,4			; 4 (auto print disable)?
	jne	ansprt5			; ne = no
	cmp	lparam,'?'		; was it ESC [ ? 4 i
	jne	anspr4a			; ne = no, so it was ESC [ 4 i
	test	anspflg,vtautop		; check state of print flag
	jz	anspr4a			; z = off already
	or	anspflg,vtautop		; say auto-print enabled to toggle off
	call	ftrnprs			; toggle mode line PRN indicator
anspr4a:ret

ansprt5:cmp	ax,5			; 5 (auto print enable)?
	jne	ansprtx			; ne = no
	call	fpntchk			; check printer, ignore carry ret
	cmp	lparam,'?'		; was it ESC [ ? 5 i
	jne	anspr5a			; ne = no
	test	anspflg,vtautop		; is print already enabled?
	jnz	ansprtx			; nz = yes, leave trnprs intact
	and	anspflg,not vtautop	; say auto-print disabled to toggle on
	call	ftrnprs			; toggle on mode line PRN indicator
	ret
anspr5a:test	anspflg,vtcntp		; controller print already enabled?
	jnz	ansprtx			; nz = yes
	mov	emubufc,0		; clear string buffer
	and	anspflg,not vtautop	; clear single-char flag for toggling
	call	ftrnprs			; toggle on mode line PRN indicator
	jc	ansprtx			; c = printer not ready failure
	or	anspflg,vtcntp		; controller print enabled
	mov	ttstate,offset ansmc	; do transparent print
ansprtx:ret
ansprt	endp

; State machine active while Media Copy On (Print Controller ON). Copies all
; chars to the printer until and excluding Media Copy Off (ESC [ 4 i) or a
; repeated Media Copy On (ESC [ 5 i) has been received or the emulator reset.
; New char is in al.
ansmc	proc	near
	mov	ttstate,offset ansmc	; stay in this state
	cmp	al,ESCAPE		; start a new sequence?
	je	ansmc1			; e = yes
	cmp	al,CSI			; start a new sequence?
	je	ansmc0a			; e = yes
	mov	emubufc,0		; say no matched chars
	call	fpntchr			; print char in al, ignore errors
	ret
					; CSI seen
ansmc0a:call	ansmc5			; playback previous matches
	call	atpclr			; clear parser
	mov	pardone,offset ansmc4	; where to go when done
	mov	parfail,offset ansmc5	; where to go when fail, playback
	mov	ttstate,offset ansmc3	; get numeric arg
	mov	emubuf,CSI		; stuff CSI
	mov	emubufc,1
	ret
					; Escape seen
ansmc1:	call	ansmc5			; playback previous matches
	mov	ttstate,offset ansmc2	; get left square bracket
	mov	emubufc,1		; one char matched
	mov	emubuf,al		; store it
	ret

ansmc2:	cmp	al,'['			; left square bracket?
	je	ansmc2a			; e = yes
	cmp	al,ESCAPE		; ESC?
	je	ansmc1			; e = yes, start over
	cmp	al,CSI			; CSI?
	je	ansmc0a			; e = yes, start over
	call	ansmc5			; playback previous matches
	call	fpntchr			; print char in al, ignore errors
	ret

ansmc2a:inc	emubufc			; say matched "ESC ["
	mov	emubuf+1,al		; store left square brace
	call	atpclr			; clear parser
	mov	pardone,offset ansmc4	; where to go when done
	mov	parfail,offset ansmc4c	; where to go when fail, playback
	mov	ttstate,offset ansmc3	; get numeric arg
	ret
					; CSI or ESC [ seen
ansmc3:	cmp	al,ESCAPE		; ESC?
	je	ansmc1			; e = yes, start over
	cmp	al,CSI			; CSI?
	je	ansmc0a			; e = yes, start over
	inc	emubufc			; another char
	mov	bx,emubufc		; qty stored
	mov	emubuf[bx-1],al		; store it
	mov	ah,al			; check for C0 and C1 controls
	and	ah,not 80h
	cmp	ah,20h			; control range?
	jb	ansmc5			; b = yes, mismatch, playback
	jmp	atparse			; parse control sequence
					; parse succeeded, al has Final char
ansmc4:	cmp	al,'i'			; correct Final char?
	jne	ansmc5			; ne = no, playback previous matches
	cmp	lparam,0		; missing letter parameter?
	jne	ansmc5			; ne = no, mismatch
	cmp	ninter,0		; missing intermediates?
	jne	ansmc5			; ne = no, mismatch
	mov	cx,nparam		; number of parameters
	xor	bx,bx			; subscript
ansmc4a:mov	ax,param[bx]
	add	bx,2			; next param
	cmp	ax,4			; CSI 4 i  MC OFF?
	je	ansmc4b			; e = yes, stop printing
	loop	ansmc4a			; keep trying all parameters
	jmp	short ansmc7		; forget this one, start over

					; Media OFF found
ansmc4b:mov	ttstate,offset atnrm	; return to normal state
	call	fpntflsh		; flush printer buffer
	test	anspflg,vtcntp		; was printing active?
	jz	ansmc7			; z = no
	and	anspflg,not vtcntp	; yes, disable print controller
	call	ftrnprs			; toggle mode line PRN indicator
	ret
					; atparse exited failure, char in AL
ansmc4c:cmp	al,ESCAPE		; ESC?
	je	ansmc1			; e = yes, start over
	cmp	al,CSI			; CSI?
	je	ansmc0a			; e = yes, start over, else playback

					; playback emubufc matched chars
ansmc5:	mov	cx,emubufc		; matched char count
	jcxz	ansmc7			; z = none
	push	ax			; save current char in al
	push	si
	mov	si,offset emubuf	; matched sequence, cx chars worth
	cld
ansmc6:	lodsb				; get a char
	call	fpntchr			; print it, ignore errors
	loop	ansmc6			; do all matched chars
	pop	si
	pop	ax
	mov	emubufc,cx		; clear this counter
ansmc7:	mov	ttstate,offset ansmc	; reset state to the beginning
	ret
ansmc	endp

dgprt	proc	near			; RS F ? <char>	 DG Print routines
	mov	ttstate,offset dgprt1	; get the <char>
	ret
dgprt1:	mov	ttstate,offset atnrm	; reset state
	and	al,0fh
	cmp	al,0			; Simulprint off?
	jne	dgprt2			; ne = no
	mov	al,7			; reform to be VT autoprint off

dgprt2:	cmp	al,1			; Simulprint on?
	jne	dgprt3			; ne = no
	mov	al,8			; reform to be VT autoprint on

dgprt3:	cmp	al,3			; Print Pass Through on?
	jne	dgprt4			; ne = no
dgprt3a:				; RS F `   alternative to RS F ? 3
	test	anspflg,vtcntp		; controller print already enabled?
	jnz	dgprt7			; nz = yes
	and	anspflg,not vtautop	; clear single-char flag for toggling
	or	anspflg,vtcntp		; controller print enabled
	mov	emubufc,0		; clear string buffer
	mov	ttstate,offset dgmc	; do transparent print
	call	ftrnprs			; toggle on mode line PRN indicator
	ret

dgprt4:	cmp	al,8			; VT-style autoprint on?
	jne	dgprt5			; ne = no
	call	fpntchk			; check printer, ignore carry ret
	test	anspflg,vtautop		; is print already enabled?
	jnz	dgprt7			; nz = yes, leave trnprs intact
	and	anspflg,not vtautop	; say auto-print disabled to toggle on
	call	ftrnprs			; toggle on mode line PRN indicator
	ret

dgprt5:	cmp	al,7			; VT-style autoprint off?
	jne	dgprt6			; ne = no
	test	anspflg,vtautop		; check state of print flag
	jz	dgprt7			; z = off already
	or	anspflg,vtautop		; say auto-print enabled to toggle off
	call	ftrnprs			; toggle mode line PRN indicator
	ret

dgprt6:	cmp	al,':'			; Print Screen?
	jne	dgprt7			; ne = no
	mov	ah,mar_bot		; save margins
	mov	al,mar_top
	push	ax
	mov	mar_top,0		; set to full screen height
	mov	al,byte ptr low_rgt+1	; bottom text row
	mov	mar_bot,al
	push	cursor
	xor	dx,dx			; cursor to home
	call	dgprtwn			; print this window
	pop	cursor
	pop	ax
	mov	mar_top,al		; restore margins
	mov	mar_bot,ah
dgprt7:	ret
dgprt	endp

dgppb	proc	near			; RS F x <n> Printer Pass back to host
	mov	bx,offset dgppb1	; call back routine
	jmp	get1n			; setup consume one <n>
dgppb1:	mov	al,dgescape		; send RS R x 0  cannot set
	call	prtbout			; out, no echo
	mov	al,'R'
	call	prtbout
	mov	al,'x'
	call	prtbout
	mov	al,'0'			; say cannot set NRC printer mode
	call	prtbout
	ret
dgppb	endp

; State machine active while DG Simulprint is  On. Copies all chars to the 
; printer until and excluding Simulprint Off (RS F ? 0) has been received 
; or the emulator reset.
; New char is in al.
dgmc	proc	near
	mov	ttstate,offset dgmc	; stay in this state
	cmp	al,dgescape		; start a new sequence?
	je	dgmc1			; e = yes
	mov	emubufc,0		; say no matched chars
	call	fpntchr			; print char in al, ignore errors
	ret
					; RS seen
dgmc1:	call	ansmc5			; playback previous matches
	mov	ttstate,offset dgmc2	; get next char
	mov	emubufc,1		; one char matched
	mov	emubuf,al		; store it
	ret

dgmc2:	cmp	al,'F'			; 'F' part of RS F ? 2
	jne	dgmc7			; ne = no
	inc	emubufc			; say matched "RS F"
	mov	emubuf+1,al		; store it
	mov	ttstate,offset dgmc3	; get query char
	ret
					; RS F seen
dgmc3:	cmp	al,'?'			; 'F' part of RS F ? 2
	jne	dgmc4			; ne = no
	inc	emubufc			; say matched "RS F ?"
	mov	emubuf+1,al		; store it
	mov	ttstate,offset dgmc5	; get final char
	ret

dgmc4:	cmp	al,'a'			; RS F a  alternative?
	jne	dgmc7			; ne = no
	jmp	short dgmc8		; finish up

dgmc5:	and	al,0fh
	cmp	al,2			; RS F ? seen, correct final char?
	je	dgmc8			; e = yes
	
dgmc7:	call	ansmc5			; playback previous matches
	call	fpntchr			; print char in al, ignore errors
	mov	ttstate,offset dgmc	; start over
	ret

dgmc8:	mov	ttstate,offset atnrm	; return to normal state
	call	fpntflsh		; flush printer buffer
	test	anspflg,vtcntp		; was printing active?
	jz	dgmc9			; z = no
	and	anspflg,not vtcntp	; yes, disable print controller
	mov	al,6			; send Control-F to host
	call	prtbout			; output, no echo
	call	ftrnprs			; toggle mode line PRN indicator
dgmc9:	ret
dgmc	endp

pntlin	proc	near			; print whole line given by dx
	push	ax
	push	bx
	push	cx
	push	dx
	xor	ch,ch
	mov	cl,mar_right		; number of columns - 1
	mov	dl,cl			; Bios column counter, dh = row
	inc	cl			; actual line length, count it down
	test	vtemu.vtflgop,vswdir	; writing right to left?
	jnz	pntlin2			; nz = yes, do not trim spaces
	cmp	decrlm,0		; host writing direction active?
	jne	pntlin2			; ne = yes
pntlin1:push	cx
	call	getatch			; read char (al) and attribute (ah)
	pop	cx			;  and extended bit pair to cl
	cmp	al,' '			; is this a space?
	jne	pntlin2			; no, we have the end of the line
	dec	dl			; else move left one column
	loop	pntlin1			; and keep looking for non-space

pntlin2:jcxz	pntlin4			; z = empty line
	xor	dl,dl			; start in column 0, do cl chars
pntlin3:push	cx
	call	getatch			; read char (al) and attribute (ah)
	pop	cx
	inc	dl			; inc to next column
	call	fpntchr			; print the char (in al)
	jc	pntlin5			; c = printer error
	loop	pntlin3			; do cx columns
pntlin4:mov	al,cr			; add trailing cr for printer
	call	fpntchr
pntlin5:pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret				; C bit controlled by pntchr
pntlin	endp

pntext	proc	near			; print an extent of lines, depending
	push	ax			; on flag bit vtextp
	push	bx
	push	dx
	xor	dx,dx			; assume starting at top left
	mov	bx,low_rgt		;  and extending to lower right
	test	anspflg,vtextp		; full screen wanted?
	jnz	pntext1			; nz = yes, else scrolling region
	mov	dh,mar_top		; top of scrolling region
	mov	bh,mar_bot		; bottom of scrolling region
pntext1:call	pntlin			; print a line
	jc	pntext2			; c = printer error
	mov	al,LF
	call	fpntchr
	jc	pntext2
	inc	dh
	cmp	dh,bh			; done all requested lines?
	jbe	pntext1			; be = not yet, do another
	test	anspflg,vtffp		; form feed needed at end?
	jz	pntext2			; z = no
	mov	al,ff
	call	fpntchr			; print the form feed char
pntext2:pop	dx
	pop	bx
	pop	ax
	ret
pntext	endp

; Set cursor coordinate DL (row) with consideration for writing direction.
; Active only under local writing direction control
direction proc	near
	test	vtemu.vtflgop,vswdir	; writing left to right?
	jz	direct1			; z = yes, no changes needed
	sub	dl,mar_right		; right margin column number
	neg	dl			; make a positive value again
direct1:ret
direction endp

; Like direction, but functions if host writing direction decrlm is active
; as well as local control
hldirection proc near
	cmp	decrlm,0		; host mode inactive?
	jne	hldirect1		; ne = no, obey
	test	vtemu.vtflgop,vswdir	; writing left to right?
	jz	hldirect2		; z = yes, no changes needed
hldirect1:sub	dl,mar_right		; right margin column number
	neg	dl			; make a positive value again
hldirect2:ret
hldirection endp

; Erase from cursor (DX, inclusive) to end of screen
; sense double width/height
ereos	proc	near
	mov	ax,dx			; erase from cursor to end of screen
	or	dx,dx			; cursor at home position?
	jnz	ereos1			; nz = no
					; e = yes, roll screen before clear
	push	word ptr mar_top
	mov	al,byte ptr low_rgt+1	; bottom row number
	mov	mar_bot,al
	mov	mar_top,dh		; row of cursor
	inc	al			; number of lines to scroll
	mov	scroll,al
	call	atscru			; scroll them up before erasure
	pop	word ptr mar_top
					; removes double w/h lines too
	xor	ax,ax			; erase from here (home)
	mov	bx,low_rgt		; bh = bottom row number
	mov	cl,scbattr
	mov	ch,curattr
	push	cx
	cmp 	vtclrflg,0		; use scbattr?
	je	ereos0a			; e = yes
	mov	scbattr,ch		; use curattr
ereos0a:call	vtsclr			; clear screen
	pop	cx
	mov	scbattr,cl		; restore scbattr
	ret
ereos1:	push	dx			; save dx
	mov	bl,dh			; get row number
	xor	bh,bh
	cmp	linetype [bx],0		; single width line?
	je	ereos2			; e = yes
	shl	dl,1			; physical column is twice logical
ereos2:	or	dl,dl			; starting at left margin?
	je	ereos3			; e = yes, this goes to single width
	inc	bl			; else start on next line
ereos3:	cmp	bl,byte ptr low_rgt+1	; at the end of the screen?
	ja	ereos4			; a = yes, stop singling-up
	mov	byte ptr linetype [bx],0 ; set to single width
	inc	bx
	jmp	short ereos3		; loop, reset lines to end of screen
ereos4:	mov	ax,dx			; cursor
	pop	dx
	mov	bx,low_rgt		; erase from cursor to end of screen
	cmp	dh,bh			; on status line?
	jbe	ereos5			; be = no
	mov	bh,dh			; use status line
ereos5:	mov	cl,scbattr
	mov	ch,curattr
	push	cx
	cmp 	vtclrflg,0		; use scbattr?
	je	ereos5a			; e = yes
	mov	scbattr,ch		; use curattr
ereos5a:call	vtsclr			; clear it
	pop	cx
	mov	scbattr,cl		; restore scbattr
	ret
ereos	endp

; Erase from start of screen to cursor (inclusive), sense double width/height
ersos	proc	near
	xor	ax,ax			; erase from start of screen
					;  to cursor, inclusive
	xor	bx,bx			; start at top row (0)
ersos1:	cmp	bl,dh			; check rows from the top down
	jae	ersos2			; ae = at or below current line
	mov	byte ptr linetype [bx],0; set line to single width
	inc	bx			; inc row
	jmp	short ersos1		; look at next line
ersos2:	or	dl,dl			; at left margin of current line?
	jne	ersos3			; ne = no, leave line width intact
	mov	byte ptr linetype [bx],0 ; convert to single width	
ersos3:	mov	bl,dh			; get row number
	xor	bh,bh
	cmp	linetype [bx],0		; single width line?
	je	ersos4			; e = yes
	shl	dl,1			; physical column is twice logical
ersos4:	mov	bx,dx			; cursor position to bx
	mov	cl,scbattr
	mov	ch,curattr
	push	cx
	cmp 	vtclrflg,0		; use scbattr?
	je	ersos5			; e = yes
	mov	scbattr,ch		; use curattr
ersos5:	call	vtsclr			; clear it
	pop	cx
	mov	scbattr,cl		; restore scbattr
	ret
ersos	endp

; Erase in line, from column AL to column BL, in row DH
erinline proc	near
	mov	ah,dh			; set row
	mov	bh,dh
	mov	cl,byte ptr low_rgt	; screen width
	push	bx
	mov	bl,dh			; get row
	xor	bh,bh
	cmp	linetype [bx],0		; single width line?
	pop	bx			; pop does not affect flags
	pushf				; save a copy of the flags for al
	je	erinli1			; e = yes
	shl	bl,1			; physical column is twice logical
	jc	erinli2			; c = overflow
erinli1:cmp	bl,cl			; wider than the physical screen?
	jb	erinli3			; b = no, not wider than screen
erinli2:mov	bl,cl			; physical width
erinli3:popf				; recover copy of flags
	je	erinli4			; e = single width line
	shl	al,1
	jc	erinli5
erinli4:cmp	al,cl
	jb	erinli6
erinli5:mov	al,cl
erinli6:mov	cl,scbattr
	mov	ch,curattr
	push	cx
	cmp 	vtclrflg,0		; use scbattr?
	je	erinli7			; e = yes
	mov	scbattr,ch		; use curattr
erinli7:call	vtsclr			; clear it
	pop	cx
	mov	scbattr,cl		; restore scbattr
	ret
erinline endp

; General erasure command which skips over protected chars.
; Preset margins and cursor to obtain all three erasure kinds.
erprot	proc	near			; erase cursor to end of region
	mov	cursor,dx		; preserve cursor
erprot1:push	dx
	call	direction
	call	getatch			; read a char, get attributes
	pop	dx
	test	flags.vtflg,ttd463+ttd470+ttd217 ; DG D463/D470/D217 mode?
	jz	erprot6			; z = no
	cmp	protectena,0		; is protected mode enabled?
	je	erprot4			; e = no, erase all
erprot6:test	cl,att_protect		; protected?
	jnz	erprot2			; nz = yes, retain it
erprot4:xor	cl,cl			; clear extended attributes
	mov	ah,scbattr		; background attributes
	cmp 	vtclrflg,0		; use scbattr?
	je	eprot5			; e = yes
	mov	ah,curattr		; use current colors
eprot5:	mov	al,' '
	push	dx
	call	direction
	call	qsetatch		; quietly update char
	pop	dx
erprot2:inc	dl			; next column
	cmp	dl,mar_right		; did right margin?
	jbe	erprot1			; be = no
	mov	dl,mar_left		; rest to left margin
	inc	dh			; next line down
	cmp	dh,mar_bot		; did the last row?
	jbe	erprot1			; be = no
erprot3:mov	dl,byte ptr cursor+1	; starting line, dh is ending line
	mov	dh,mar_bot
	call	touchup			; repaint part of screen
	mov	dx,cursor
	ret
erprot	endp

; Clear screen from AX to BX, where AH = row, AL = column, ditto for BX.
; This routine accomodates right to left writing. BX >= AX.
vtsclr	proc	near
	cmp	ax,bx			; proper order?
	jbe	vtsclr7			; be = yes
	xchg	ax,bx			; reverse
vtsclr7:test	vtemu.vtflgop,vswdir	; writing left to right?
	jz	vtsclr4			; z = yes
	cmp	bh,ah			; same row?
	je	vtsclr2			; e = yes
	push	ax			; multiple lines
	push	bx			; save both coordinates
	mov	bl,mar_right
	mov	bh,ah			; pick just top line
	call	vtsclr2			; delete fraction of top line
	pop	bx			; recover ending position
	push	bx
	inc	ah			; omit top row, now done
	dec	bh			; omit last line, could be fractional
	cmp	bh,ah			; any whole lines remaining to delete?
	jb	vtsclr1			; b = no, finish up
	mov	bl,mar_right		; get right most physical column
	xor	al,al			; to end of line (on left)
	call	atsclr			; clear top line and whole remainders
vtsclr1:pop	bx			; setup for last line to be cleared
	push	bx			; get last row again
	xor	al,al			; start at logical left margin
	jmp	short vtsclr3		; ax and bx are already pushed

vtsclr2:push	ax			; erase single line, whole or part
	push	bx
vtsclr3:mov	ah,mar_right		; borrow reg ah (same as bh)
	sub	ah,bl			; reflect right to left
	mov	bl,ah
	or	bl,bl			; overflow?
	jns	vtsclr5			; ns = no, is ok
	xor	bl,bl			; limit to logical screen
vtsclr5:mov	ah,mar_right
	sub	ah,al
	mov	al,ah
	jns	vtsclr6
	mov	al,mar_right		; limit to logical screen
vtsclr6:mov	ah,bh			; restore ah
	xchg	al,bl			; reverse to get physical ax < bx
	call	atsclr			; erase part/all of single line
	pop	bx
	pop	ax
	ret
					; for writing left to right
vtsclr4:jmp	atsclr			; do normal erasure and return
vtsclr	endp

; routines supporting scrolling and double width/height chars
; scroll has number of lines to scroll
atscru	proc	near			; scroll screen up one line
	test	vtemu.vtflg,ttwyse	; Wyse-50?
	jz	atscru9			; z = no
	cmp	wyse_scroll,0		; ok to scroll?
	je	atscru9			; e = yes
	ret
atscru9:push	ax			; assumes dx holds cursor position
	push	bx			; returns with dx = old row, new col
	push	cx
	push	si
	xor	bh,bh
	mov	bl,mar_top		; top line to move
	xor	ch,ch
	mov	cl,scroll		; number of lines to move
	mov	al,mar_bot		; bottom line to scroll
	sub	al,bl			; number of lines minus 1
	inc	al			; number of lines
	cmp	al,cl			; scrolling region smaller than scroll?
	jge	atscru1			; ge = no, is ok
	mov	scroll,al		; limit to region
	cmp	al,1			; at least one line to scroll?
	jge	atscru1			; ge = yes
	mov	scroll,1		; no, force one
atscru1:mov	al,scroll
	mov	ah,byte ptr low_rgt+1	; last text line on screen
	inc	ah			; number of screen lines
	cmp	al,ah			; exceeds number of lines on screen?
	jbe	atscru8			; be = scrolling not more than that
	mov	al,ah			; limit to screen length
	mov	scroll,al
atscru8:xor	ah,ah
	mov	si,ax			; scroll interval
	mov	bl,mar_top
	mov	cl,mar_bot
	sub	cl,bl
	inc	cl			; number  of lines in region
	sub	cl,scroll		; cx = those needing movement
	cmp	cl,0
	jle	atscru3
atscru2:mov	al,linetype[bx+si]	; get old type
	mov	linetype[bx],al		; copy to new higher position
	mov	al,linescroll[bx+si]	; get horizontal scroll value
	mov	linescroll[bx],al	; copy too
	inc	bx
	loop	atscru2
atscru3:mov	bl,mar_bot		; set fresh lines to single attribute
	mov	cl,scroll		; number of fresh lines (qty scrolled)
	xor	ch,ch
atscru4:mov	linetype[bx],0
	mov	linescroll[bx],0
	dec	bx
	loop	atscru4			; clear old bottom lines
	mov	bl,dh			; get row of cursor
	xor	bh,bh
	cmp	linetype[bx],0		; single width?
	je	atscru5			; e = yes
	shr	dl,1			; reindex to single width columns
atscru5:pop	si
	pop	cx
	pop	bx
	pop	ax
	test	anspflg,vtcntp		; controller print active?
	jz	atscru6			; z = no, ok to change screen
	ret				;  else keep screen intact
atscru6:jmp	vtscru			; call & ret the msy scroll routine
atscru	endp

atscrd	proc	near			; scroll screen down scroll lines
	test	vtemu.vtflg,ttwyse	; Wyse-50?
	jz	atscrd7			; z = no
	cmp	wyse_scroll,0		; ok to scroll?
	je	atscrd7			; e = yes
	ret
atscrd7:push	ax			; assumes dx holds cursor position
	push	bx			; returns with dx = old row, new col
	push	cx
	push	si
	xor	ch,ch
	mov	cl,scroll		; number of lines to scroll
	xor	bh,bh
	mov	bl,mar_bot		; bottom line to move
	mov	al,bl
	xor	ah,ah
	sub	al,mar_top		; number of lines minus 1
	inc	al			; number of lines
	cmp	al,cl			; scrolling region smaller than scroll?
	jge	atscrd1			; ge = no, is ok
	mov	scroll,al		; limit to region
	cmp	al,1			; at least one line to scroll?
	jge	atscrd1			; ge = yes
	mov	scroll,1		; no, force one
atscrd1:mov	al,scroll
	mov	si,ax			; si = scroll
	mov	bl,dh			; get row of cursor
	xor	bh,bh			; make into an index
	sub	bl,scroll		; si + this bx will be new bottom line
	mov	cl,bl
	sub	cl,mar_top
	inc	cl
	cmp	cl,0
	jle	atscrd3
atscrd2:mov	al,linetype[bx]		; get old line's type
	mov	linetype[bx+si],al	; copy to new lower position
	mov	al,linescroll[bx]	; get per line horizontal scroll
	mov	linescroll[bx+si],al	; copy too
	dec	bx
	loop	atscrd2
atscrd3:mov	bl,mar_top		; start with this line
	xor	bh,bh
	mov	cl,scroll		; number of lines scrolled
	xor	ch,ch
atscrd4:mov	linetype[bx],0		; clear new top lines
	mov	linescroll[bx],0
	inc	bx
	loop	atscrd4
	mov	bl,dh			; get row of cursor
	xor	bh,bh
	cmp	linetype[bx],0		; single width?
	je	atscrd5			; e = yes
	shr	dl,1			; reindex to single width columns
atscrd5:pop	si
	pop	cx
	pop	bx
	pop	ax
	test	anspflg,vtcntp		; controller print active?
	jz	atscrd6			; z = no, ok to change screen
	ret				;  else keep screen intact
atscrd6:jmp	vtscrd			; call & ret the msy scroll routine
atscrd	endp

; Returns carry set if column in DL is a tab stop, else carry clear.
; Enter with column number in DL (starts at column 0, max of swidth-1)
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

; Modify (set/clear) a tabstop. Enter with DL holding column (0 to swidth-1)
; Set a tabstop into buffer pointed at by SI.
tabset	proc	near
	mov	modeset,1		; set a tabstop
	jmp	short modtabs
tabset	endp

; Clear a tabstop
tabclr	proc	near
	mov	modeset,0		; clear a tabstop
	jmp	short modtabs
tabclr	endp

; Worker for set/clear tabstop, si has pointer to tabstops array
modtabs:push	bx
	push	cx
	mov	cl,dl			; column number (0 to swidth-1)
	and	cl,00000111b		; keep bit in byte (0-7)
	mov	ch,1			; tab bit to change
	shl	ch,cl			; shift to bit-in-byte position
	mov	bl,dl			; column
	shr	bl,1			; bl / 8 to get byte
	shr	bl,1
	shr	bl,1
	xor	bh,bh			; clear high byte
	mov	cl,[si+bx]		; get byte of tabs bits
	not	ch			; invert bit marker to create hole
	and	cl,ch			; clear the tab bit
	not	ch			; recover setting pattern
	cmp	modeset,0		; clear the tab bit?
	jz	modtab1			; z = yes
	or	cl,ch			; set the tab bit
modtab1:mov	[si+bx],cl		; store tab byte
	pop	cx
	pop	bx
	ret

; This routine initializes the VT  setups at startup. It is called from
; procedure lclyini in module msyibm.
vsinit	proc	near
	mov	vtemu.vtflgst,vsdefaults ; Init to defaults in mssdef.h
	mov	vtemu.vtflgop,vsdefaults ; Init runtime state to setup items
	mov	savflgs,vsdefaults
	mov	iniflgs,vsdefaults
	xor	al,al
	mov	insmod,al		; turn off insert mode
	mov	atinvisible,al
	xor	dl,dl			; Column 1 has no tab stop
	mov	si,vtemu.vttbs		; from the cold-start buffer
	call	tabclr			; clear that tabstop
	push	es
	push	ds
	pop	es
	cld
	mov	al,1			; set tabs at columns 9, spaced by 8
	mov	cx,(swidth-1)/8		; bytes to do, at 8 bits/byte
	mov	di,offset deftabs+1	; starting byte for column 9 (1...)
	rep	stosb
	xor	al,al			; get a zero
	mov	cx,slen			; clear linetype array
	mov	di,offset linetype
	rep	stosb
	mov	cx,slen
	mov	di,offset linescroll	; clear horiz scroll per line
	rep	stosb
	pop	es
	mov	vtemu.vttbst,offset tabs ; addrs of active tabs for STATUS
	mov	vtemu.vttbs,offset deftabs  ; addrs of tabs for setup (SET)
	call	cpytabs			; copy default to active
	mov	vtemu.att_ptr,offset att_normal  ; ptr to video attributes
	mov	ah,byte ptr low_rgt	; right most column (counted from 0)
	sub	ah,8			; place marker 9 columns from margin
	mov	belcol,ah		; store column number to ring bell
        cmp     isps55,0                ; [HF]940221 Japanese PS/55?
        je      vsinix                  ; [HF]940221 e=no
        mov     vtemu.vtchset,C_JISKANJI ; [HF]940221 def = JIS-Kanji
vsinix: ret
vsinit	endp

; Initialization routine.
; Enter with dl = index for baud rate table
; dh = parity in bits 4-7, number of data bits in bits 0-3
ansini	proc	near
	mov	ax,vtemu.vtflgst	; setup flags
	mov	vtemu.vtflgop,ax
	mov	iniflgs,ax
	mov	savflgs,ax
	mov	ax,flags.vtflg		; get current terminal type
	cmp	ax,tttek		; non-text?
	je	ansin3			; e = yes
	mov	oldterm,ax		; remember it here for soft restarts
ansin3:	mov	anspflg,0		; clear printing flag
	mov	al,byte ptr low_rgt	; right most column (counted from 0)
	sub	al,8			; place marker 9 columns from margin
	mov	belcol,al		; store column number to ring bell
	cmp	dl,lbaudtab		; out of range index?
	jb	ansin1			; b = no, store it
	mov	dl,lbaudtab-2		; yes, make it the maximum (128)
ansin1: mov	baudidx,dl		; save baud rate index
	mov	al,dh			; get parity/number of databits
	and	al,0FH			; isolate number of databits
	mov	datbits,al		; save
	mov	cl,4
	shr	dh,cl			; isolate parity code
	cmp	dh,lpartab		; out of range code?
	jb	ansin2			; b = no, store it
	mov	dh,lpartab-1		; make it the maximum
ansin2: mov	parcode,dh		; save
	mov	cx,low_rgt
	mov	oldscrn,cx		; remember old screen dimensions
	jmp	atreset			; reset everything
ansini	endp

atxreset proc	near			; Reset via host command
	cmp	nparam,0		; need no Parameters, no Intermediates
	jne	atxres1			; ne = not a reset
	cmp	ninter,0		; any intermediates?
	je	atreset			; e = none, it is a reset
atxres1:ret				; ignore command
atxreset endp

atreset	proc	near			; Reset-everything routine
	test	flags.vtflg,ttd463+ttd470+ttd217 ; DG D463/D470/D217 mode?
	jnz	atres9			; nz = yes
ifndef	no_graphics
	test	tekflg,tek_sg 		; special graphics active?
	jz	atres9			; z = no
	call	tekend			; exit special graphics
endif	; no_graphics
atres9:	mov	ax,apcstring		; seg of apcmacro memory area
	or	ax,ax			; empty?
	jz	atres10			; z = yes
	mov	es,ax
	mov	ah,freemem
	int	dos			; free that memory
atres10:xor	ax,ax			; get a zero
	mov	apcstring,ax
	mov	bracecount,al		; APC-macro worker variables
	mov	cursor,ax		; cursor is at 0,0
	mov	h19cur,ax		; Heath-19 saved cursor
	mov	wyse_scroll,al		; Wyse-50, no-scroll mode to off
	mov	decrlm,al		; host writing direction to left-right
	mov	havesaved,al		; unmark saved cursor section
	mov	atinvisible,al		; clear invisible attribute
	mov	dspstate,al		; saved modeline state
	mov	al,1			; assume underline cursor
	test	vtemu.vtflgst,vscursor	; kind of cursor in setup
	jnz	atres0			; nz = underline
	inc	al			; else say block
atres0:	mov	atctype,al		; VTxxx cursor type
	call	udkclear		; clear User Definable Key contents
	push	vtemu.vtflgst		; setup flags
	pop	vtemu.vtflgop		; operational flags
	and	vtemu.vtflgop,not vscntl ; assume no 8-bit controls
	mov	ax,oldterm		; get terminal at entry time
	or	ax,ax			; inited yet? (initing Tek too)
	jnz	atres0a			; nz = yes
	mov	ax,ttvt320		; pretend initing VT320
	jmp	short atres0b
atres0a:mov	flags.vtflg,ax		; use it again
atres0b:test	ax,ttvt102+ttvt100+tthoney+ttpt200+ttansi ; VT100 class?
	jnz	atres1			; nz = yes, turn on ansi mode
	test	ax,ttvt320+ttvt220	; VT320/VT220?
	jz	atres1a			; z = no, no ansi, no 8-bit controls
	test	vtemu.vtflgst,vscntl	; want 8-bit controls?
	jz	atres1			; z = no
	or	vtemu.vtflgop,vscntl	; turn on 8-bit controls
atres1:	or	vtemu.vtflgop,decanm	; turn on ANSI mode
	or	vtemu.vtflgst,decanm	; and in permanent setup too

atres1a:mov	mar_top,0		; reset scrolling region
	mov	ax,low_rgt		; virtual screen lower right corner
	mov	mar_bot,ah		; logical bottom of screen
	test	flags.vtflg,ttd463+ttd470+ttd217 ; DG D463/D470/D217 mode?
	jz	atres1d			; z = no
ifndef	no_graphics
	call	clearsoft		; clear soft font storage, saves ax
endif	; no_graphics
	mov	al,79			; trim to 80 col screen
atres1d:mov	mar_right,al		; logical right edge of screen
	mov	mar_left,0		; DG left/right margins
	mov	old8bit,-1		; flags.remflg d8bit status, clear
	xor	al,al			; ax is top/bottom margin
	mov	dgwindow,ax		; init to first window to full screen
	mov	dgwindcnt,1		; DG window count, 1 = full screen
	mov	cx,slen
	xor	bx,bx
atres1i:mov	dgwindcomp[bx],al	; set lines to uncompressed, no soft
	inc	bx
	loop	atres1i
	xor	ax,ax
	mov	savdgmar,ax		; clear DG saved margins
	mov	protectena,al		; disable protected fields
	mov	blinkdis,al		; disable blink disable
	mov	dgroll,1		; DG roll enabled
	mov	dgaltid,ax		; DG alternate model id, clear it
	mov	dghscrdis,al		; DG horz scroll disable is disabled
	mov	cx,16
	xor	bx,bx
atres1e:mov	dgcursave[bx],ax	; clear DG cursor named save area
	add	bx,2
	loop	atres1e
	mov	cx,slen/2
	xor	bx,bx
atres1f:mov	word ptr linescroll[bx],ax ; clear DG per line horiz scroll
	add	bx,2
	loop	atres1f
	mov	dgnum,ax		; DG worker word, to be safe
ifndef	no_graphics
	call	dgcrossoff		; DG turn off crosshair
endif	; no_graphics
	mov	dgcross,al		; DG crosshair activity, off
	mov	dglinepat,0ffffh	; DG line pattern, default all dots
	mov	dgcaller,offset atign	; DG default callback, ignorance
	mov	numdigits,al		; more DG stuff
	mov	param[0],ax		; setup call to atleds
	mov	doublebyte,al		; Japanese doublebyte state values
	mov	double2nd,al
	mov	param[0],ax		; setup call to atleds
	xor	si,si
	call	atleds			; clear the LED indicators
	call	cpytabs			; initialize tab stops
 test flags.vtflg,ttvt320+ttvt220+ttvt102+ttvt100+tthoney+ttd463+ttd217+ttd470+ttansi
	jz	atres1c			; z = no
	mov	al,vtemu.vtchset	; setup char set
	cmp	al,1			; in range for NRCs?
	jb	atres1c			; b = no
	cmp	al,13			; highest NRC ident?
	ja	atres1c			; a = not NRC
	or	vtemu.vtflgop,vsnrcm	; set NRC flag bit to activate NRCs
atres1c:mov	vtemu.vtchop,al		; remember char set
	call	chrdef			; set default character sets
	call	vtbell			; ring bell like VT100
	cmp	flags.modflg,2		; mode line owned by host?
	jne	atres1h			; ne = no
	mov	flags.modflg,1		; say now owned by us
atres1h:xor	ax,ax			; not exiting connect mode, 80 col
	test	vtemu.vtflgst,deccol	; need 132 columns?
	jz	atres1g			; z = no, use 80 columns
	inc	al			; say set 132 column mode
atres1g:call	chgdsp			; call Change Display proc in msy
	and	vtemu.vtflgop,not deccol; assume mode is reset (80 cols)
	cmp	byte ptr low_rgt,79	; is screen narrow now?
	jbe	atres2			; be = yes
	or	vtemu.vtflgop,deccol	; set the status bit

					; ATRES2 used in 80/132 col resetting
ATRES2:	mov	cx,slen			; typically 24 but do max lines
	xor	di,di
	xor	al,al
atres3:	mov	linetype[di],al		; clear the linetype array to single
	mov	linescroll[di],al	; horizontal scroll per line
	inc	di
	loop	atres3
       	mov	ah,att_normal		; get present normal coloring
	test	vtemu.vtflgop,vsscreen	; want reverse video?
	jz	atres4			; z = no
	call	revideo			; reverse them
atres4:	mov	scbattr,ah		; set background attributes
	mov	curattr,ah		; and cursor attributes
	test	flags.vtflg,ttwyse	; Wyse-50?
	jz	atres4a			; z = no
	mov	byte ptr wyse_protattr,ah ; Wyse-50 protected char attributes
	mov	byte ptr wyse_protattr+1,att_protect
atres4a:
	mov	extattr,0		; no reverse video, no underline etc
	mov	dx,cursor		; get cursor
	call	atsetcur		; set cursor
	call	atsctyp			; set right cursor type
	xor	ax,ax			; starting location
	mov	bx,low_rgt		; ending location
	call	vtsclr			; clear the whole screen
	cmp	flags.modflg,1		; mode line on and owned by us?
	jne	atres5			; ne = no, leave it alone
	test	yflags,modoff		; mode line supposed to be off?
	jnz	atres5			; nz = yes
	push	dx
	call	fmodlin			; write normal mode line
	pop	dx
atres5:	test	flags.vtflg,ttd463+ttd470+ttd217 ; DG D463/D470/D217 mode?
	jz	atres6			; z = no
	or	vtemu.vtflgop,decawm	; Autowrap active
	or	vtemu.vtflgst,decawm	; Autowrap active
atres6:	call	atpclr			; clear parser work area
	xor	ax,ax
	mov	parstate,ax		; reset parser
	mov	emubufc,ax		; clear work buffer
	mov	atwrap,al		; clear wrap flag
	mov	SSptr,ax		; clear single shift flag
	mov	insmod,al		; reset insert mode
	mov	h19stat,al		; clear heath extended status byte
	mov	h19ctyp,1		; Heath-19 cursor to underline
	mov	anspflg,al		; clear printer flag
	call	atsc			; save cursor information
	jmp	atnorm			; set normal state
atreset	endp

; Re-initialization routine. Called when Term was called but screen was
; restored from a previously saved screen, etc.
ansrei	proc	near
	mov	dx,cursor
	call	atsctyp			; set cursor type [rbv]
	mov	ax,vtemu.vtflgst	; setup
	or	ax,vtemu.vtflgop	; operational
	test	ax,deccol		; want 80 columns?
	jnz	ansre2			; nz = no
	cmp	byte ptr low_rgt,79	; want 80 cols. Is active screen wider?
	jbe	ansre2			; be = no
	mov	byte ptr low_rgt,79	; narrow down to 80 columns
	and	vtemu.vtflgop,not deccol
ansre2:	jmp	stblmds			; check settable modes, set flags
ansrei	endp

; This routine checks to see whether any of the settable modes have changed
; (things that can be changed in both SETUP and by host commands), and
; changes those that need to be changed.  TMPFLAGS has the new VT100 setup
; flags, VTFLAGS has the old. This routine also updates VTFLAGS.
; Revised to allow MSY to reset scbattr when not in connect mode,
; to do "soft reset" if terminal type has changed, and to do a screen clear
; reset if the actual screen colors have changed.

stblmds proc	near
	mov	ax,flags.vtflg		; get current terminal type
	cmp	ax,tttek		; non-text?
	je	stblm10			; e = yes
	cmp	ax,oldterm		; same as before?
	je	stblm10			; e = yes, skip over soft reset
	mov	oldterm,ax		; remember current terminal type
	mov	insmod,0		; reset insert mode flag
	and	iniflgs,not vsnrcm	; turn off NRC bit from last time
	mov	mar_top,0		; reset top scrolling margin
	mov	al,byte ptr low_rgt+1	; and scrolling margin
	mov	mar_bot,al		; to last normal line on screen
	mov	ah,byte ptr low_rgt	; right most column (counted from 0)
	sub	ah,8			; place marker 9 columns from margin
	mov	belcol,ah		; store column number to ring bell
	push	es
	push	ds
	pop	es
	xor	al,al			; get a zero
	mov	di,offset linetype	; line type to single width chars
	mov	cx,slen			; screen length
	cld
	rep	stosb			; clear
	mov	di,offset linescroll	; line horizontal scroll to none
	mov	cx,slen
	rep	stosb
	pop	es
	and	vtemu.vtflgop,not decanm
 test	flags.vtflg,ttvt320+ttvt220+ttvt102+ttvt100+tthoney+ttpt200+ttansi
	jz	stblm10			; z = no, not ansi class
	or	vtemu.vtflgop,decanm	; set ansi flag bit
	or	vtemu.vtflgst,decanm	; and in permanent setup too

stblm10:test	flags.vtflg,ttd463+ttd470+ttd217 ; DG D463/D470/D217 mode?
	jz	stblm10a		; z = no
	mov	cx,slen-1		; emulation screen lines
	xor	al,al
	xor	bx,bx
stblm10b:or	al,dgwindcomp[bx]	; is any line compressed (!= 0)?
	inc	bx			; if so remember as non-zero
	loop	stblm10b
	or	al,al			; found any compressed/soft lines?
	jz	stblm10e		; z = no
	test	al,2			; any soft fonts in use?
	jnz	stblm10c		; nz = yes, force graphics mode
	test	vtemu.vtflgop,vscompress ; allowed to use graphics for it?
	jnz	stblm10d		; nz = no, use 132 column text mode
	test	tekflg,tek_active+tek_sg ; special graphics mode active?
	jnz	stblm10e		; nz = yes
stblm10c:
ifndef	no_graphics
	call	dgsettek		; setup special graphics mode
endif	; no_graphics
	jmp	short stblm10e
stblm10d:mov	al,3			; prep call on atrsm6, 132/80 col
	mov	modeset,1		; say want 132 columns
	call	atrsm6			; common worker
	cmp	byte ptr low_rgt,79
	jbe	stblm10c		; did not work, use graphics anyway
stblm10e:mov	al,flags.remflg		; get 7/8 bit configuration
	and	al,d8bit		; select the control bit
	cmp	old8bit,al		; changed?
	je	stblm10a		; e = no
	mov	old8bit,al		; save new state
	mov	vtemu.vtchop,-1		; force change below
stblm10a:mov	al,vtemu.vtchset	; setup character set
	cmp	al,vtemu.vtchop		; operational character set
	je	stblm3			; e = same, no changes needed
	mov	vtemu.vtchop,al		; remember this set
	and	vtemu.vtflgop,not vsnrcm ; clear NRC active bit
	and	vtemu.vtflgst,not vsnrcm
	cmp	al,1			; in range for NRC?
	jb	stblm11			; b = no
	cmp	al,13			; above NRCs?
	ja	stblm11			; a = yes
	or	vtemu.vtflgop,vsnrcm	; set NRC active bit
	or	vtemu.vtflgst,vsnrcm
	and	vtemu.vtflgop,not vscntl ; no 8-bit controls
stblm11:call	chrdef			; init char sets

stblm3:	test	vtemu.vtflgst,vswdir	; writing direction set?
	jz	stblm3c			; z = no
	mov	decrlm,0		; yes, suppress host indicator
stblm3c:mov	ax,iniflgs		; flags at last entry
	xor	ax,vtemu.vtflgst	; find which setup ones have changed
	test	ax,deccol		; screen width?
	jz	stblm3b			; z = no, don't touch it
	mov	ax,vtemu.vtflgst	; Setup bits
	and	ax,deccol		; select screen width
	and	vtemu.vtflgop,not deccol ; clear operational flag bit
	or	vtemu.vtflgop,ax	; set current width desired
	or	al,ah			; collapse all bits
	mov	modeset,al		; non-zero if 132 columns
	mov	al,3			; setup call to atrsm6
	call	atrsm6			; adjust display width

stblm3b:cmp	vtclear,1		; screen need updating?
	mov	vtclear,0		; preserves cpu status bits
	jb	stblm9			; b = no
	ja	stblm3a			; 2 or more means do a reset
	mov	ah,att_normal		; 1, get new normal attributes setting
	mov	scbattr,ah		; store new values
	test	flags.vtflg,ttwyse	; Wyse-50?
	jz	stblm3d			; z = no
	mov	byte ptr wyse_protattr,ah ; Wyse-50 protected char attributes
	mov	byte ptr wyse_protattr+1,att_protect
stblm3d:
	mov	curattr,ah
	jmp	short stblm9
stblm3a:mov	cursor,0		; reset cursor position
	jmp	atres2			; go to semi-reset

					; check on screen normal/reversed
stblm9:	mov	ax,iniflgs		; flags at last entry
	xor	ax,vtemu.vtflgst	; find which setup ones have changed
	test	ax,vsscreen		; screen background?
	jz	stblm8			; z = no, don't touch it
	test	vtemu.vtflgop,vsscreen	; reverse video flag set?
	jnz	stblm5			; nz = yes, do it
	and	vtemu.vtflgop,not vsscreen ; cleared (normal video)
	jmp	short stblm6		; reverse everything
stblm5: or	vtemu.vtflgop,vsscreen	; set (reverse video)
stblm6: call	atrss2			; reverse screen and cursor attribute
	mov	ah,scbattr		; reset saved attribute also
	mov	savecu+svattr_index,ah
stblm8:	cmp	flags.modflg,2		; mode line enabled and owned by host?
	je	stblm9a			; e = yes, leave it alone
	call	fclrmod			; clear the mode line
	test	yflags,modoff		; mode line supposed to be off?
	jnz	stblm9a			; nz = yes
	call	fmodlin			; write normal mode line
	and	yflags,not modoff	; say modeline is not toggled off
stblm9a:mov	dx,cursor		; logical cursor
	push	dx
	call	direction		; set cursor for writing direction
	call	setpos			; set the cursor physical position
	pop	dx
	push	vtemu.vtflgst
	pop	iniflgs			; remember setup flags at this entry
	call	frepaint
	ret
stblmds endp

; Routine called when something is typed on the keyboard

anskbi	proc	near
	mov	ttkbi,0FFH		; just set a flag
	ret
anskbi	endp


; This routine copies the new tab stops when they have changed.
; Copies all 132 columns.
cpytabs proc	near
	mov	cx,(swidth+7)/8		; number of bytes in screen width
	jcxz	cpytab1			; z = none to do
	mov	si,offset deftabs	; source is setup array
	mov	di,offset tabs		; destination is active array
	push	es			; save es
	push	ds
	pop	es			; set es to data segment
	cld
	rep	movsb			; do the copy
	pop	es			; recover es
cpytab1:ret
cpytabs endp

; Routine to toggle between text and Tek graphics modes. No arguments.
; Text terminal type remembered in byte OLDTERM.
ans52t	proc	FAR
	mov	ax,flags.vtflg
	cmp	ax,tttek		; in Tek mode now?
	je	ans52b			; e = yes, exit Tek mode
	test	tekflg,tek_active	; doing Tek sub mode?
	jnz	ans52b			; nz = yes
	test	ax,ttd463+ttd470+ttd217	; DG 463/D470/D217?
	jnz	ans52e			; nz = yes, go into DG graphics mode

ifndef	no_graphics
	test	denyflg,tekxflg		; is Tek mode disabled?
	jnz	ans52a			; nz = yes, disabled
	mov	oldterm,ax		; save text terminal type here
	call	atsc			; save cursor and associated data
	mov	flags.vtflg,tttek	; set Tek mode
	mov	tekflg,tek_tek		; not a sub mode
	call	tekini			; init Tek to switch screens
endif	; no_graphics
ans52a:	call	atnorm
	ret

ans52b:
ifndef	no_graphics
	call	tekend			; exit Tek graphics mode
endif	; no_graphics
	mov	ax,oldterm
	or	ax,ax			; inited yet?
	jnz	ans52c			; nz = yes
	mov	ax,ttvt320		; fall back for initing
ans52c:	mov	flags.vtflg,ax		; say text terminal now
	test	flags.vtflg,ttd463+ttd470+ttd217 ; DG D463/D470/D217?
	jnz	ans52f			; nz = yes, cursor is ok already
	call	atrc			; restore cursor etc
	call	atsc			; save cursor etc
ans52f:	mov	tekflg,0		; say not doing tek submode now
	mov	al,atctype
	call	atsctyp			; set correct cursor type
	test	yflags,modoff		; is mode line off?
	jnz	ans52d			; nz = yes
	push	dx			; save cursor position
	call	frepaint		; restore text screen
	call	fmodlin			; write mode line
	pop	dx
ans52d:	call	atnorm
	ret
					; DG D473 graphics mode entry
ans52e:	mov	oldterm,ax		; save text terminal type here
ifndef	no_graphics
	call	dgsettek		; switch to DG graphics
endif	; no_graphics
	jmp	short ans52d
ans52t	endp

;  Honeywell VIP 3.1 i.d. string [FD]
athoney proc	near
	cmp	flags.vtflg,tthoney	; Honeywell mode?
	jne	athone3			; ne = no, ignore
	mov	ttyact,0		; group for networks
	mov	cx,VIPstrl		; length of string
	mov	si,offset VIPstr	; ptr to string
	cld
athone1:lodsb				; get a byte
	push	cx			; save regs
	push	si
	call	prtbout			; print WITHOUT echo
	pop	si
	pop	cx
	cmp	cx,1			; last char?
	ja	athone2			; a = not yet
	mov	ttyact,1		; end of network grouping
athone2:loop	athone1			; loop for all characters
athone3:jmp	atnorm
athoney endp

athoncls proc	near			; Honeywell ESC accent  screen clear
	cmp	nparam,0		; absence of parameters?
	jne	athoncl1		; ne = no, fail
	cmp	ninter,0		; any intermediates?
	jne	athoncl2		; ne = yes, not this item
	cmp	flags.vtflg,tthoney	; doing Honeywell emulation?
	jne	athoncl1		; ne = no
	xor	dx,dx			; move cursor to Home position
	call	ereos			; erase to end of screen
	xor	dx,dx
	jmp	atsetcur		; set cursor and return
athoncl1:ret
athoncl2:jmp	atdgnrc			; try Norwegian/Danish NRC designation
athoncls endp

	; Data General D463/D470 support routines

					; Data General mode C0 control codes
dgctrl	proc	near
	test	anspflg,vtcntp		; printing desired?
	jz	dgctrl1			; z = no
	call	fpntchr			; print char in al
dgctrl1:and	ax,001fh		; clear for word use below
	mov	di,ax			; use AL as a word index
	shl	di,1
	jmp	dgc0[di]		; dispatch on DG C0 control codes
dgctrl	endp

; Control-character dispatcher for DG ANSI mode
dgansctl proc	near
	cmp	al,escape		; an escape sequence starting?
	jne	dgansctl1		; ne = no
	jmp	atesc
dgansctl1:cmp	al,CSI			; this kind of escape?
	jne	dgansctl2		; ne = no
	jmp	atcsi0
dgansctl2:cmp	al,9ch			; end of DCS?
	jne	dgansctl3		; ne = no
	jmp	atgotst			; terminate DCS
dgansctl3:cmp	ttstate,offset atdcsnul	; consuming a DCS?
	jne	dgansctl4		; ne = no
	ret				; consume
dgansctl4:cmp	ttstate,offset atesc1	; state is second char of ST?
	jne	dgansctl5		; ne = no
	jmp	ttstate			; go process second char
dgansctl5:test	anspflg,vtcntp		; printing desired?
	jz	dgansctl6		; z = no
	call	fpntchr			; print char in al
dgansctl6:cmp	al,BELL
	jne	dgansctl7
	jmp	vtbell			; beep
dgansctl7:cmp	al,BS
	jne	dgansctl8
	jmp	dgcub			; do DG Backspace
dgansctl8:cmp	al,LF
	je	dgansctl9		; e = yes
	cmp	al,FF
	jne	dgansctl10
dgansctl9:jmp	dglf			; do DG Line Feed
dgansctl10:ret
dgansctl endp

dgesc	proc	near			; Parse Data General RS commands
	mov	dgnum,0			; clear numerical result
	mov	ttstate,offset dgesc1	; set up to get next char
	ret
dgesc1:	mov	bx,offset dgesctab	; dispatch table
	mov	ttstate,offset atnrm	; reset state
	jmp	atdispat		; dispatch on char in AL
dgesc	endp

; Parse RS F/G <letter><DGnumber>(repeated)
; F/G has been read, letter is next
dgFSERIES:mov	ttstate,offset Fdisp	; dispatcher for incoming RS F
	ret
Fdisp:	mov	ttstate,offset atnrm	; normal state
	mov	bx,offset fltable	; table of letters
	jmp	atdispat		; dispatch to action routine

dgGSERIES:mov	ttstate,offset Gdisp	; dispatcher for incoming RS G
	ret
Gdisp:	mov	ttstate,offset atnrm	; normal state
	mov	bx,offset gltable	; table of letters
	jmp	atdispat		; dispatch to action routine

dgRSERIES:test	flags.vtflg,ttd463+ttd217 ; D463/D217?
	jz	dgnoR			; z = no
	mov	ttstate,offset Rdisp	; dispatcher for incoming RS R
	ret
dgnoR:	jmp	atnorm			; no RS R series in D470

Rdisp:	mov	ttstate,offset atnrm	; normal state
	mov	bx,offset rltable	; table of letters
	jmp	atdispat		; dispatch to action routine

; DG <n>,<nn>,<nnn> processors. Enter with BX holding callback address.
; Returns number in dgnum and resets state to atnrm.
					; get one DG numeric
get1n:	mov	ttstate,offset getnum	; worker routine
	mov	dgnum,0			; clear numerical result
	mov	numdigits,1		; wanted qty of digits
	mov	dgcaller,bx		; call back address
	ret
					; get two DG hex digits
get2n:	mov	ttstate,offset getnum	; worker routine
	mov	dgnum,0			; clear numerical result
	mov	numdigits,2		; wanted qty of digits
	mov	dgcaller,bx		; call back address
	ret
					; get three DG hex digits
get3n:	mov	ttstate,offset getnum	; worker routine
	mov	dgnum,0			; clear numerical result
	mov	numdigits,3		; wanted qty of digits
	mov	dgcaller,bx		; call back address
	ret

get3loc:mov	ttstate,offset getloc	; get three DG Location digits
	mov	dgnum,0
	mov	numdigits,3
	mov	dgcaller,bx
	ret

; get number from lower 5 bits of each byte
getdd:	mov	ttstate,offset get5num	; worker routine
	mov	dgnum,0			; clear numerical result
	mov	numdigits,2		; wanted qty of digits
	mov	dgcaller,bx		; call back address
	ret

getloc	proc	near
	or	al,al			; is it truely null (RS L cmd stuff)?
	jz	getloc3			; z = yes, exit now
	and	al,00011111b		; keep only five lower bits
	mov	cl,5
	mov	bx,dgnum
	shl	bx,cl
	or	bl,al
	mov	dgnum,bx
	dec	numdigits		; say one more digit done
	jz	getloc1			; z = have done all
	ret				; else stay in state getloc

getloc3:stc				; set carry to say ended on NULL
getloc1:call	atnorm			; set normal state
	mov	bx,dgcaller		; get callback address
	mov	dgcaller,offset atign	; reset default DG callback processor
	jmp	bx			; go to callback address
getloc	endp

; Return binary number in dgnum. When done it resets state to atnrm, 
; clears callback address. Note that this proc accepts ALL bytes and uses
; only the four lower bits, regardless of what the DG manuals suggest.
getnum	proc	near
	and	al,0fh			; keep lower four bits
	mov	cl,4
	mov	bx,dgnum		; get current value
	shl	bx,cl			; times 16
	or	bl,al			; add current digit
	mov	dgnum,bx		; keep result
	dec	numdigits		; say one more digit done
	jz	getnum2			; z = have done all digits
	ret				; else stay in this state
getnum2:call	atnorm			; set normal state
	mov	bx,dgcaller		; get callback address
	mov	dgcaller,offset atign	; reset default DG callback processor
	jmp	bx			; go to callback address
getnum	endp

; Return binary number in dgnum. When done it resets state to atnrm, 
; clears callback address. Note that this proc accepts ALL bytes and uses
; only the five lower bits, regardless of what the DG manuals suggest.
get5num	proc	near
	and	al,1fh			; keep lower five bits
	mov	cl,5
	mov	bx,dgnum		; get current value
	shl	bx,cl			; times 32
	add	bl,al			; add current digit
	adc	bh,0
	mov	dgnum,bx		; keep result
	dec	numdigits		; say one more digit done
	cmp	numdigits,0		; done all?
	jz	get5num2		; z = yes
	ret				; else stay in this state
get5num2:call	atnorm			; set normal state
	mov	bx,dgcaller		; get callback address
	mov	dgcaller,offset atign	; reset default DG callback processor
	jmp	bx			; go to callback address
get5num	endp

; Provide binary number in dgnum from ANSI params, simulating get<kinds>
; Enter with bx holding offset of main routine to call first.
; Return carry set when no more parameters
dec2getn proc	near
	mov	dgparmread,0		; parameter read
	call	bx			; call main routine

dec2getn1:cmp	ttstate,offset atnrm	; want to return to normal state?
	je	dec2getnx		; e = yes
	mov	bx,dgparmread		; number of parameters read
	cmp	bx,nparam		; read all parameters?
	jae	dec2getnx		; ae = yes
	shl	bx,1			; convert to word index
	mov	bx,param[bx]		; get parameter
	inc	dgparmread		; say have read it
	mov	dgnum,bx		; return value
	clc
	mov	bx,dgcaller
	call	bx
	jmp	short dec2getn1
dec2getnx:
	call	atnorm			; reset state
	mov	dgnum,0
	stc				; return carry set
	ret
dec2getn endp

out2n	proc	near			; send <nn> report from value in AL
	push	cx
	mov	ch,al			; preserve a copy
	mov	cl,4
	shr	al,cl			; get high nibble
	and	al,0fh
	add	al,'0'			; ascii bias
	call	prtbout
	mov	al,ch			; recover copy
	and	al,0fh			; get low nibble
	add	al,'0'
	call	prtbout
	pop	cx
	ret
out2n	endp

out2na	proc	near			; send <nn> report from value in AL
	push	cx
	mov	ch,al			; preserve a copy
	mov	cl,4
	shr	al,cl			; get high nibble
	and	al,0fh
	add	al,'@'			; ascii bias
	call	prtbout
	mov	al,ch			; recover copy
	and	al,0fh			; get low nibble
	add	al,'@'
	call	prtbout
	pop	cx
	ret
out2na	endp

dgign1n	proc	near			; ignore a <n> command
	mov	bx,offset atnorm	; ignore the <n>
	jmp	get1n
dgign1n	endp

dgign2n	proc	near			; ignore a <nn> command
	mov	bx,offset atnorm	; ignore the <nn>
	jmp	get2n
dgign2n	endp

dgprtfm	proc	near			; Control-A  DG print form
	mov	cursor,dx		; save cursor location
dgprtf1:mov	dl,mar_right		; start at right margin
	mov	cl,dl
	sub	cl,mar_left		; minus left
	inc	cl
	xor	ch,ch			; number of columns to do
dgprtf3:push	cx
	call	dgprta			; get char which would be printed
	pop	cx
	cmp	al,' '			; space?
	jne	dgprtf4			; ne = no, end scan here
	dec	dl			; scan backward another column
	loop	dgprtf3
dgprtf4:jcxz	dgprtf6			; z = empty line
	mov	dl,mar_left		; start at left margin
dgprtf5:push	cx
	push	dx
	call	dgprta			; get printable
	call	fpntchr			; print char in al
	pop	dx
	pop	cx
	jc	dgprtf7			; c = printer error
	inc	dl
	loop	dgprtf5			; do count

dgprtf6:mov	al,CR			; line terminator for printer
	push	dx
	call	fpntchr
	pop	dx
	jc	dgprtf7			; c = printer error
	mov	al,LF
	push	dx
	call	fpntchr
	pop	dx
	jc	dgprtf7			; c = printer error
	inc	dh			; next row down
	cmp	dh,mar_bot		; below window now?
	jbe	dgprtf1			; be = no
dgprtf7:mov	al,6			; Control-F to host when done
	call	prtbout			; output, no echo
	mov	dx,cursor
	ret
dgprtfm	endp

dgprta	proc	near			; worker, report printable char at dx
	call	getatch			; read char (al) and attribute (ah)
	cmp	protectena,0		; protected mode enabled?
	je	dgprta1			; e = no
	test	cl,att_protect		; protected mode?
	jnz	dgprta2			; nz = yes, use a space
	ret				; else use as-is
dgprta1:test	ah,att_bold		; bold?
	jnz	dgprta3			; nz = yes, use as-is
dgprta2:mov	al,' '			; replace with space
dgprta3:ret
dgprta	endp

dgprtwn	proc	near			; Control-Q  DG print window
	mov	cursor,dx		; save cursor location
dgprtw1:mov	dl,mar_right		; start at right margin
	mov	cl,dl
	sub	cl,mar_left
	inc	cl
	xor	ch,ch			; number of columns to do
dgprtw3:push	cx
	call	dgprtb			; get char which would be printed
	pop	cx
	cmp	al,' '			; space?
	jne	dgprtw4			; ne = no, end scan here
	dec	dl			; scan backward another column
	loop	dgprtw3
dgprtw4:jcxz	dgprtw6			; z = empty line
	mov	dl,mar_left		; start at left margin
dgprtw5:push	cx
	push	dx
	call	dgprtb			; get printable
	call	fpntchr			; print char in al
	pop	dx
	pop	cx
	jc	dgprtw7			; c = printer error
	inc	dl
	loop	dgprtw5			; do count
dgprtw6:mov	al,CR			; line terminator for printer
	push	dx
	call	fpntchr
	pop	dx
	jc	dgprtw7			; c = printer error
	mov	al,LF
	push	dx
	call	fpntchr
	pop	dx
	jc	dgprtw7			; c = printer error
	inc	dh			; next row down
	cmp	dh,mar_bot		; below window now?
	jbe	dgprtw1			; be = no
dgprtw7:mov	al,6			; Control-F to host when done
	call	prtbout			; output, no echo
	mov	dx,cursor
	ret
dgprtwn	endp

dgprtb	proc	near			; worker to yield printable char
	call	getatch			; read char (al) and attribute (ah)
	test	al,80h			; high bit set?
	jnz	dgprtb1			; nz = yes, use a space
	cmp	al,20h			; in printables?
	ja	dgprtb2			; a = yes
dgprtb1:mov	al,' '			; replace with space
dgprtb2:ret
dgprtb	endp

dgrevidon:mov	ah,curattr		; RS D  Control-V  reverse video on
	call	setrev			; reverse video on
	mov	curattr,ah		; store new attribute byte
	ret

dgrevidoff:mov	ah,curattr		; RS E  Control-B  reverse video off
	call	clrrev			; 2, reverse video off
	mov	curattr,ah		; store new attribute byte
	ret

dgblkena:mov	blinkdis,0		; Control-C  DG blink enable
	ret
dgblkdis:mov	blinkdis,1		; Control-D  DG blink disable
	ret

dgblkon	proc	near			; Control-N  DG Blink on
	cmp	blinkdis,0		; disabled?
	jne	dgblkon1		; ne = blink is disabled
	mov	ah,curattr		; get current cursor attribute
	call	setblink		; blink enable
	mov	curattr,ah		; store new attribute byte
dgblkon1:ret
dgblkon	endp

dgblkoff proc	near			; Control-O  DG Blink off
	mov	ah,curattr		; get current cursor attribute
	call	clrblink		;  blink disable
	mov	curattr,ah		; store new attribute byte
	ret
dgblkoff endp

dgwinhome proc near			; Control-H  DG window home
	mov	dl,mar_left		; want to skip protected chars too
	mov	dh,mar_top
	jmp	dgsetcur		; do protected mode positioning
dgwinhome endp

dguson	proc	near			; Control-T  DG underscoring on
	mov	ah,curattr		; get current cursor attribute
	call	setunder
	mov	curattr,ah		; store new attribute byte
	ret
dguson	endp

dgusoff	proc	near			; Control-U  DG underscoring off
	mov	ah,curattr		; get current cursor attribute
	call	clrunder
	mov	curattr,ah		; store new attribute byte
	ret
dgusoff	endp

dgdimon	proc	near			; Control-\  DG dim on
	mov	ah,curattr		; get current cursor attribute
	call	clrbold
	mov	curattr,ah		; store new attribute byte
	ret
dgdimon	endp

dgdimoff proc	near			; Control-]  DG dim off
	mov	ah,curattr		; get current cursor attribute
	call	setbold
	mov	curattr,ah		; store new attribute byte
	ret
dgdimoff endp

dgsfc	proc	near			; RS A <color>, set foreground color
	mov	ttstate,offset dgsfc1	; state to get next char
	ret
dgsfc1:	mov	ttstate,offset atnrm	; reset state
	test	flags.vtflg,ttd463+ttd217 ; D463/D217?
	jz	dgsfc2			; z = no, D470
	mov	ah,curattr		; current coloring
	test	al,0fh			; setting to background?
	jnz	dgsfc1a			; nz = no
	mov	cl,4
	rol	ah,cl			; get background coloring
dgsfc1a:and	ah,0fh			; keep foreground
	mov	dg463fore,ah		; polygon foreground coloring
	ret
dgsfc2:	cmp	al,100			; select ACM mode?
	je	dgsfc5			; ne = no
dgsfc3:	and	al,0fh			; keep lower 4 bits
	jz	dgsfc4			; z = black
	xor	al,8			; invert DG intensity bit
	jnz	dgsfc4
	or	al,8			; pick up dark grey as second except'n
dgsfc4:	mov	ah,curattr
	and	ah,not 0Fh		; remove foreground
	or	ah,al			; set new foreground
	mov	ah,scbattr
	and	ah,not 0Fh
	or	ah,al
	mov	curattr,ah		; save it
	mov	scbattr,ah
	ret
dgsfc5:	mov	ah,att_normal		; get normal background colors
	mov	scbattr,ah
	mov	curattr,ah		; set current to them
dgsfcx:	ret
dgsfc	endp

dgsbc	proc	near			; RS B <color>, set background color
	mov	ttstate,offset dgsbc1	; state to get next char
	ret
dgsbc1:	mov	ttstate,offset atnrm	; reset state
	test	flags.vtflg,ttd463+ttd217 ; D463/D217?
	jnz	dgsbcx			; nz = yes, ignore command
	cmp	al,100			; select ACM mode?
	je	dgsbc2			; e = yes
	and	al,0fh			; mask out all but IBM PC background
	jz	dgsbc3			; z = black
	and	al,7			; remove IBM PC blinking bit
	mov	cl,4
	shl	al,cl			; move bits to high nibble
dgsbc3:	mov	ah,curattr
	and	ah,0fh			; remove background
	or	ah,al			; set new background
	mov	curattr,ah		; save it
	mov	ah,scbattr
	and	ah,0fh			; remove background
	or	ah,al			; set new background
	mov	scbattr,ah		; save it
	ret
dgsbc2:	mov	ah,att_normal		; get normal background colors
	mov	scbattr,ah		; set current to them
	mov	curattr,ah		; set current to them
dgsbcx:	ret
dgsbc	endp

dgeol	proc	near			; Control-K DG erase cursor to eol
	mov	ax,dx			; cursor position
	mov	bx,ax
	mov	bl,mar_right		; end of line
	call	atsclr			; erase from ax to bx
	ret
dgeol	endp

dgtoansi proc	near			; RS F @  D470 mode to ANSI mode
	test	flags.vtflg,ttd470	; D470?
	jz	dgtoansi1		; z = no
	mov	dgd470mode,1		; say doing ANSI mode
dgtoansi1:ret
dgtoansi endp

dgeeos	proc	near			; RS F F  DG erase cursor to end/scrn
	jmp	erprot
dgeeos	endp

dgescn	proc	near			; RS F E  DG erase from 0,0 to eos
	xor	dh,dh
	mov	dl,mar_left		; left margin, top row
	call	dggetmar		; get margins for this window
	call	atsetcur		; set cursor
	mov	ah,curattr
	call	clrunder		; clear underline attribute
	call	clrblink		; clear blink
	call	setbold			; aka clear dim
	call	clrrev			; clear reverse video attribute
	mov	atinvisible,0		; clear invisible attribute
	mov	curattr,ah		; and cursor attributes
	mov	extattr,0		; clear extended attributes
	xor	ax,ax			; erase from 0,0
	mov	bh,byte ptr low_rgt+1	; to end of screen
	mov	bl,vswidth-1
	call	atsclr			; clear screen
	ret
dgescn	endp

dgewin	proc	near			; Control-L  DG erase window
	call	dgusoff			; underscore off		
	call	clrblink		; clear blink
	call	clrrev			; remove special video attributes
	mov	ah,mar_top		; from top line of window
	mov	bh,mar_bot		; to bottom line of window
	mov	al,mar_left		; left margin
	mov	bl,mar_right		; right margin
	cmp	savdgmar,0		; saved permanent margin?
	je	dgewin1			; e = no, mar_left/right are permanent
	mov	al,byte ptr savdgmar	; use permanent l/r margins
	mov	bl,byte ptr savdgmar+1
dgewin1:call	atsclr			; clear the area
	jmp	dgwinhome		; do DG window home
dgewin	endp

dgsleft	proc	near			; RS F C <nn>  DG Scroll Left
	mov	bx,offset dgslef1	; get <nn>
	jmp	get2n
dgslef1:mov	ax,dgnum		; qty columns to scroll
	jmp	dglrworker		; do common worker
dgsleft	endp

dgsright proc	near			; RS F D <nn>  DG Scroll Right
	mov	bx,offset dgsrig1	; get <nn>
	jmp	get2n
dgsrig1:mov	ax,dgnum
	neg	ax			; go right
	jmp	dglrworker		; do common worker
dgsright endp

; Worker to assist dgsleft/dgsright horizontal scroll. Enter with AX holding
; the additional scroll value, negative for scrolling left. Updates array
; linescroll.
dglrworker proc	near
	cmp	dghscrdis,0		; horiz scrolling disabled?
	je	dglrwor1		; e = no
	ret				; else ignore request
dglrwor1:mov	bl,mar_top		; do entire DG window
	xor	bh,bh
	mov	cl,mar_bot
	xor	ch,ch
	sub	cx,bx
	inc	cx			; number of lines in the window
	cmp	cl,byte ptr low_rgt+1	; includes whole screen?
	jbe	dglrwor2		; be = no
	inc	cx			; include status line

dglrwor2:push	cx
	mov	cl,linescroll[bx]	; get horz scroll value
	xor	ch,ch
	add	cx,ax			; accumulate scroll
	jge	dglrwor3		; ge = non-negative
	xor	cx,cx			; set to zero
dglrwor3:cmp	cx,127			; max scroll
	jbe	dglrwor4		; be = in limits
	mov	cl,127			; set to max left
dglrwor4:cmp	linescroll[bx],cl	; any change?
	je	dglrwor5		; e = no
	mov	linescroll[bx],cl	; set scroll
	push	dx
	mov	dl,bl
	mov	dh,bl			; start/stop line numbers
	call	touchup			; repaint just this line
	pop	dx
dglrwor5:inc	bx			; next line
	pop	cx
	loop	dglrwor2
	ret
dglrworker endp

dginsl	proc	near			; RS F H  DG Insert Line in window
	push	dx			; save cursor
	mov	param,0			; set up ANSI call
	call	inslin			; do insert line, can scroll
	pop	dx			; recover cursor
	jmp	atsetcur		; reset cursor
dginsl	endp

dgdell	proc	near			; RS F I  DG Delete Line in window
	mov	scroll,1		; line count
	push	word ptr mar_top	; save current scrolling margins
	mov	mar_top,dh		; temp top margin is here
	call	atscru			; scroll up
	pop	word ptr mar_top	; restore scrolling margins
	ret
dgdell	endp

dgnarrow proc	near			; RS F J  DG select normal spacing
	mov	cx,dgwindcnt		; number of windows
	xor	bx,bx
	jcxz	dgnarr3			; z = none
	inc	cx			; let implied last window be seen
dgnarr1:cmp	dh,byte ptr dgwindow[bx+1] ; look at window bottom edge
	jbe	dgnarr3			; be = cursor is in this window
	add	bx,2			; skip two margin bytes
	loop	dgnarr1			; next window
dgnarr2:ret

dgnarr3:mov	cx,dgwindow[bx]		; get mar_top and mar_bot (ch)
	push	cx			; save margins for touchup below
	mov	bl,cl			; mar_top
	xor	bh,bh
	sub	ch,cl			; mar_bot - mar_top = lines in win -1
	xchg	ch,cl
	xor	ch,ch
	inc	cx
	xor	ax,ax			; zero and make ah a changed flag
dgnarr4:mov	al,dgwindcomp[bx]
	and	dgwindcomp[bx],not 1	; set window to normal width
	and	al,1			; select width, ignore font
	or	ah,al			; remember if window line were wide
	inc	bx
	loop	dgnarr4			; do all lines in the window
	mov	cl,byte ptr low_rgt+1	; see if any screen lines are wide
	inc	cl			; text lines
	xor	ch,ch
	xor	bx,bx
	xor	al,al
dgnarr5:test	dgwindcomp[bx],1	; count wide lines
	jz	dgnarr6			; z = narrow
	inc	al
	jmp	short dgnarr7		; one wide line is enough to count
dgnarr6:inc	bx
	loop	dgnarr5

dgnarr7:pop	cx			; margins
	test	tekflg,tek_active+tek_sg ; special graphics mode active?
	jz	dgnarr8			; z = no
	or	ah,ah			; any line widths changed?
	jz	dgnarr7a		; z = no
	push	dx
	mov	dx,cx			; cx = saved margins 
	call	touchup			; dl, dh are start stop rows
	pop	dx
dgnarr7a:ret
dgnarr8:or	al,al			; count of wide lines
	jz	dgnarr9			; z = all are narrow, go to 80 cols
	ret				; leave screen as-is with wide line(s)
dgnarr9:mov	al,3			; prep call on atrsm6, 132/80 col
	mov	modeset,0		; say want 80 columns
	jmp	atrsm6			; common worker
dgnarrow endp

dgwide	proc	near			; RS F K  DG select compressed spacing
	mov	cx,dgwindcnt		; number of windows
	xor	bx,bx
	jcxz	dgwide3			; z = none, means one as whole screen
	inc	cx			; let implied last window be seen
dgwide1:cmp	dh,byte ptr dgwindow[bx+1] ; look at window bottom edge
	jbe	dgwide3			; be = cursor is in this window
	add	bx,2			; skip two margin bytes
	loop	dgwide1			; next window
dgwide2:ret

dgwide3:mov	cx,dgwindow[bx]		; get mar_top and mar_bot (ch)
	push	cx			; save them for touchup below
	mov	bl,cl			; mar_top
	xor	bh,bh
	sub	ch,cl			; mar_bot - mar_top = lines in win -1
	xchg	ch,cl
	xor	ch,ch
	inc	cx
	mov	ax,1			; al is set, ah is changed flag
dgwide5:mov	al,dgwindcomp[bx]
	or	dgwindcomp[bx],1	; set this line to wide width
	xor	al,1			; pick out width bit change
	or	ah,al			; accumulate changes
	inc	bx
	loop	dgwide5			; do all lines in the window
	pop	cx			; margins
ifndef	no_graphics
	test	ah,2			; soft fonts involved?
	jnz	dgwide5a		; nz = yes, force graphics mode
	test	tekflg,tek_active+tek_sg ; special graphics mode active?
	jnz	dgwide7			; nz = yes
	test	vtemu.vtflgop,vscompress ; allowed to use graphics for it?
	jnz	dgwide8			; nz = no, use 132 column text mode
dgwide5a:test	tekflg,tek_active+tek_sg ; special graphics mode active?
	jnz	dgwide7			; nz = yes
dgwide6:push	cx
	push	dx
	call	dgsettek		; setup special graphics mode
	pop	dx
	pop	cx
	ret
dgwide7:or	ah,ah			; any changes to width?
	jz	dgwide7a		; z = no
	push	dx
	mov	dx,cx			; saved margins
	call	touchup			; dl, dh are start stop rows
	pop	dx
dgwide7a:ret
endif	; no_graphics

dgwide8:mov	al,3			; prep call on atrsm6, 132/80 col
	mov	modeset,1		; say want 132 columns
	call	atrsm6			; common worker
ifndef	no_graphics
	cmp	byte ptr low_rgt,79
	jbe	dgwide6			; did not work, use graphics anyway
endif	; no_graphics
	ret
dgwide	endp

; Toggle Normal/Compressed modes from the keyboard.
dgnctoggle proc	far
	mov	dx,cursor		; get cursor
	mov	bl,dh			; get row
	xor	bh,bh
	test	dgwindcomp[bx],1	; normal mode?
	jz	dgnctog4		; z = yes, do compressed
	call	dgnarrow		; do normal
	ret
dgnctog4:call	dgwide			; do compressed
	ret
dgnctoggle endp

dginsc	proc	near			; RS J  DG Insert char
	mov	dx,cursor
	cmp	protectena,0		; protected mode enabled?
	jne	dginsc1			; ne = yes, find new right margin
	jmp	inschr			; do regular inschr
dginsc1:cmp	dl,mar_right		; at right margin?
	jae	dginsc2			; ae = yes
	call	dgcurpchk		; check for protected char
	jc	dginsc2			; c = protected
	inc	dl			; next column right
	jmp	short dginsc1		; continue scanning

dginsc2:mov	al,mar_right		; save right margin
	push	ax
	dec	dl			; do not include margin char
	mov	mar_right,dl
	mov	dx,cursor
	call	inschr			; insert char
	pop	ax
	mov	mar_right,al
	ret
dginsc	endp

dgdelc	proc	near			; RS K  DG Delete char
	mov	dx,cursor
	mov	param,0			; set up ANSI call for one char
	cmp	protectena,0		; protected mode enabled?
	jne	dgdelc1			; ne = yes, find new right margin
	jmp	atdelc			; do delete
dgdelc1:cmp	dl,mar_right		; at right margin?
	jae	dgdelc2			; ae = yes
	call	dgcurpchk		; check for protected char
	jc	dgdelc2			; c = protected
	inc	dl			; next column right
	jmp	short dgdelc1		; continue scanning

dgdelc2:mov	al,mar_right		; save right margin
	push	ax
	dec	dl			; do not include margin char
	mov	mar_right,dl
	mov	dx,cursor
	call	atdelc			; do delete
	pop	ax
	mov	mar_right,al
	ret
dgdelc	endp

dgilbm	proc	near			; RS F [ Insert line between margins
	mov	al,dghscrdis		; save horz scrolling disable flag
	push	ax			; save til the end
	mov	dghscrdis,1		; disable horz scrolling for this cmd
	mov	cursor,dx		; save this
	mov	dl,mar_left		; start at the left side
	mov	dh,mar_bot		; bottom of window
	or	dh,dh			; row zero?
	jz	dgilbm2			; z = yes, just clear the line

dgilbm1:dec	dh			; up one row
	call	getatch			; read a char
	inc	dh			; go down a row
	call	qsetatch		; write the char
	inc	dl			; next column
	cmp	dl,mar_right		; off end of row yet?
	jbe	dgilbm1			; be = no
	or	dh,dh			; finished top row?
	jz	dgilbm2			; z = yes
	dec	dh			; redo this one row up
	mov	dl,mar_left		; reset to left window margin
	cmp	dh,byte ptr cursor+1	; finished cursor row yet?
	jae	dgilbm1			; ae = no
dgilbm2:mov	dx,cursor		; clear line cursor was on
	mov	al,mar_left		; from left margin
	mov	bl,mar_right		; to right window margin
	call	erinline		; clear the window line
	mov	dl,dh
	mov	dh,mar_bot		; lines changed
	call	touchup			; redisplay the new material
	mov	dx,cursor
	pop	ax			; recover horz scroll disable flag
	mov	dghscrdis,al
	ret
dgilbm	endp

dgdlbm	proc	near			; RS F \ Delete line between margins
	mov	al,dghscrdis		; get horizontal scroll disable flag
	push	ax			; save til the end
	mov	dghscrdis,1		; disable horz scrolling for this cmd
	mov	cursor,dx		; save cursor position
	mov	dl,mar_left		; start at the left side
dgdlbm1:inc	dh			; down one row
	call	getatch			; read a char
	dec	dh			; go up a row
	call	qsetatch		; write the char
	inc	dl			; next column
	cmp	dl,mar_right		; off end of row yet?
	jbe	dgdlbm1			; be = no
	inc	dh			; redo this one row down
	mov	dl,mar_left		; reset to left window margin
	cmp	dh,mar_bot		; finished bottom row yet
	jbe	dgdlbm1			; be = no
	mov	dh,mar_bot		; clear last line in window
	mov	al,mar_left
	mov	bl,mar_right
	call	erinline		; clear the window line
	pop	ax			; recover horz scroll disable flag
	mov	dghscrdis,al
	mov	dx,cursor
	mov	dl,dh			; region changed
	mov	dh,mar_bot
	call	touchup
	ret
dgdlbm	endp

dgscs	proc	near			; RS F S <nn>  DG Select Char Set
	mov	bx,dgscs1		; setup for <nn> value
	jmp	get2n
dgscs1:	mov	bx,dgnum		; get DG char set idents
	cmp	bl,1fh			; last hard char set
	jbe	dgscs2			; be = in the hard sets
	cmp	bl,45h			; end of soft sets
	jbe	dgscs1a			; be = in range
	ret				; else ignore command
dgscs1a:add	bl,100-20h+1		; add local offset for chrsetup
	jmp	short dgscs4		; prep for chrsetup

dgscs2:	or	bl,bl			; use "keyboard language"?
	jnz	dgscs3			; nz = no
	mov	bl,vtemu.vtchset	; get setup char set
	cmp	bl,13			; top of the NRCs
	jbe	short dgscs4		;  as keyboard language
	xor	bx,bx			; default to ASCII
dgscs3:	mov	bl,dgchtab[bx]		; translate to Kermit idents
dgscs4:	cmp	GLptr,offset G0set	; are we shifted out?
	jne	dgscs5			; ne = yes, presume G1set
	mov	Gsetid,bl		; new set ident for G0
	jmp	short dgscs6
dgscs5:	mov	Gsetid+1,bl		; new set ident for G1
dgscs6:	mov	bx,offset Gsetid	; pass list of sets to setup
	jmp	chrsetup		; go make the new set
dgscs	endp

dgalign	proc	near			; RS F > char DG fill screen with char
	mov	ttstate,offset dgalig1	; get char
	ret
dgalig1:mov	ttstate,offset atnrm	; reset state
	jmp	atalig1			; do DEC alignment work, char in AL
dgalign	endp

dggrid	proc	near			; RS F 9 char DG fill screen with grid
	mov	al,'#'			; set grid char in standard place
	jmp	atalig1			; do DEC alignment work, char in AL
dggrid	endp

	
dgrolldis:mov	dgroll,0		; Control-S  DG roll disable
	ret

dgrollena:mov	dgroll,1		; Control-R  DG roll enable
	ret

dghsena:mov	dghscrdis,0		; RS F ^  DG horiz scroll enable
	mov	dx,cursor
	jmp	atsetcur		; set cursor to cause screen update

dghsdis:mov	dghscrdis,1		; RS F ]  DG horiz scroll disable
	ret

dgpton:	call	setprot			; RS F L  DG Protect on
	ret

dgptoff:call	clrprot			; RS F M  DG Protect off
	ret

protena:mov	protectena,1		; RS F V  DG Protect enable
	ret				; 
	
protdis:mov	protectena,0		; RS F W  DG Protect disable
	ret				; 

dg78bit	proc	near			; RS F U <n>  DG Select 7/8 bit ops
	mov	bx,dg78bit1		; get <n>
	jmp	get1n
dg78bit1:cmp	dgnum,1			; 0 is 7 bit, 1 is 8 bit
	ja	dg78bit3		; a = illegal value, ignore
	je	dg78bit2		; e = 1
	and	flags.remflg,not d8bit	; 7-bit, chop DG high bit
	ret
dg78bit2:or	flags.remflg,d8bit	; 8-bit
dg78bit3:ret
dg78bit	endp

dgdhdw	proc	near			; RS R E <n>  DG Double high/wide
	mov	bx,offset dgdhdw1
	jmp	get1n			; set up for <n> arg
dgdhdw1:mov	ax,dgnum		; get <nn> result
	or	ax,ax			; 2 and above are double highs
	jz	dgdhdw2
	mov	al,2			; map double highs to 2
	jmp	linedbl			; make line double width
dgdhdw2:jmp	linesgl			; make single width
dgdhdw	endp

dgs25l	proc				; RS F z <n>  DG go to/set status line
	mov	bx,offset dgs25l1	; prep for <n> mode value
	jmp	get1n
dgs25l1:mov	ax,dgnum		; get mode
	or	ax,ax			; 0, 25th line is status?
	jnz	dgs25l2			; nz = no
	mov	dspstate,0		; no longer on mode line
	mov	param,1			; turn on regular mode line
	call	atssdt1			; do main worker
	ret

dgs25l2:cmp	al,3			; blank the line?
	jne	dgs25l3			; ne = no
	jmp	atssdt1			; do main worker
	cmp	al,2			; use as ordinary text?
	jne	dgs25l3			; ne = no
	ret				; ignore this request
dgs25l3:cmp	al,1			; get msg for line?
	je	dgs25l4			; e = yes
	ret
dgs25l4:mov	bx,offset dgs25l5	; prep for <nn> text
	jmp	get2n
dgs25l5:mov	dspcmain,dx		; save cursor in special area
	mov	dspstate,dsptype	; say on status line
	mov	al,mar_left
	mov	ah,mar_right
	mov	dspmsave,ax		; save margins
	mov	mar_left,0		; set left to screen left
	call	fclrmod			; clear the line
	and	yflags,not modoff	; say modeline is not toggled off
	mov	flags.modflg,2		; say mode line is owned by host
	mov	dh,byte ptr low_rgt+1	; bottom text line
	inc	dh			; status line
	xor	dl,dl			; absolute left margin
	call	atsetcur		; set cursor
	cmp	dgnum,0			; number of chars of text
	je	dgs25l7			; e = none
	mov	ttstate,offset dgs25l6	; come here for text
	ret
dgs25l6:call	atnrm			; write the character
	dec	dgnum			; one less to do
	cmp	dgnum,0			; done?
	jle	dgs25l7			; le = yes
	ret				; stay on status line
dgs25l7:mov	ttstate,offset atnrm	; reset state
	mov	dx,dspcmain		; restore cursor
	mov	ax,dspmsave		; saved margins
	mov	mar_left,al
	mov	mar_right,ah
	mov	dspstate,0		; no longer on mode line
	jmp	atsetcur		; set cursor
dgs25l	endp

dgnscur	proc	near			; RS F } <n> <n> DG cursor named save
	mov	bx,offset dgnscu1	; get <n> memory cell (name, 0..15)
	jmp	get1n
dgnscu1:mov	ax,dgnum		; get cell number
	mov	word ptr emubuf,ax	; save here
	mov	bx,offset dgnscu2	; get <n> save (0) / restore (1)
	jmp	get1n
dgnscu2:mov	bx,word ptr emubuf	; get named subscript
	mov	ax,dgnum		; get op code
	cmp	ax,1			; save?
	jb	dgnscu3			; b = save
	ja	dgnscu4			; a = illegal, ignore
	mov	al,dgctypesave[bx]	; get cursor size/type
	mov	atctype,al		; active type
	call	csrtype			; set it
	mov	dx,dgcursave[bx]	; restore cursor position from storage
	jmp	dgsetcur		; set the cursor DG style
dgnscu3:mov	dgcursave[bx],dx	; save cursor
	mov	al,atctype		; get cursor type
	mov	dgctypesave[bx],al	; save
dgnscu4:ret
dgnscur	endp

dgsps	proc	near		     	; DG dual emulation set split screen
	mov	ttstate,offset dgsps1	; RS R A 0 <nn><n> or RS R A 1 <nn>
	ret
dgsps1:	mov	bx,offset atnrm		; setup to ignore command
	cmp	al,1			; 0 or 1 expected
	ja	dgsps3			; a = illegal, ignore
	je	dgsps2			; e = case 1 <nn>
	jmp	get3n			; case 0 <nn><n> as <nnn>
dgsps2:	jmp	get2n
dgsps3:	ret
dgsps	endp

dgdchs	proc	near			; RS F q <nn><nn> Dealloc Char Sets
	mov	bx,offset dgdchs1	; ignore for now
	jmp	get2n
dgdchs1:mov	bx,offset atnrm
	jmp	get2n
dgdchs	endp

dgdefch	proc	near			; RS F R <char> 10/12<nn>'s Def Char
	mov	ttstate,offset dgdefc1	; get char
	ret
dgdefc1:mov	emubufc,0		; set counter
	mov	emubuf,al		; char to be defined
	mov	cl,14			; video cell bytes per char (8x14)
	mul	cl			; ax = bytes to start of char
	mov	word ptr emubuf+1,ax	; save string distance
	mov	ax,10			; assume D470
	cmp	flags.vtflg,ttd470	; D470?
	je	dgdefc1a		; e = yes, uses 10 byte pairs
	mov	ax,12			; D463 uses 12 byte pairs
dgdefc1a:mov	word ptr emubuf+3,ax	; save string length
	jmp	dgdefc3			; setup to get data

dgdefc2:mov	ax,word ptr emubuf+1	; get char being defined
	add	ax,emubufc		; plus byte into string
	inc	emubufc			; count a <nn> pair
ifndef	no_graphics
	mov	bx,softptr		; seg of soft font
else
	xor	bx,bx
endif	; no_graphics
	or	bx,bx			; segment of soft font, defined?
	jz	dgdefc3			; z = no, do not store
	push	es
	mov	es,bx
	mov	bx,ax			; offset to byte
	mov	ax,dgnum		; get value
	cmp	emubuf+3,10		; for D470 (8 bits wide)?
	je	dgdefc2a		; e = yes
	shr	ax,1			; D463, 10 bits, chop right most too
dgdefc2a:mov	es:[bx],al		; store byte
	pop	es

dgdefc3:mov	ax,word ptr emubuf+3	; wanted string count
	cmp	emubufc,ax		; done all?
	jae	dgdefc6			; ae = yes
	mov	bx,offset dgdefc2	; get char byte pairs
	cmp	flags.vtflg,ttd470	; D470?
	je	dgdefc5			; e = yes, use get2nn
	jmp	getdd			; for D463, 5 bit values
dgdefc5:jmp	get2n			; for D470, 4 bit values

dgdefc6:
ifndef	no_graphics
	mov	bx,softptr		; segment of soft font, defined?
	or	bx,bx
	jz	dgdefc7			; z = no, do not store
;JMP DGDEFC7
	push	es			; repeat last row of dots
	push	di
	mov	es,bx
	mov	di,word ptr emubuf+1	; start plus char offset
	mov	cx,emubufc		; get current count
	add	di,cx			; point to last stored char+1
	sub	cx,14-1			; 14-1 dots high (omit last line)
	neg	cx			; positive number
	mov	al,es:[di-1]		; last stored char
	cmp	al,es:[di-2]		; same as previous (line drawing)?
	jne	dgdefc6a		; ne = no, do not extend cell
	cld
	rep	stosb
dgdefc6a:pop	di
	pop	es
endif	; no_graphics
dgdefc7:mov	emubufc,0		; clear counter
	jmp	atnorm			; reset state
dgdefch	endp

dgrchr	proc	near			; RS F d  DG Read Chars Remaining
	mov	al,dgescape		; response string
	call	prtbout
	mov	al,'o'
	call	prtbout
	mov	al,'9'
	call	prtbout
	mov	al,'0'			; high part of 10 bit count
;graphics
mov al,'_'
	call	prtbout
	mov	al,'0'			; low part of 10 bit count
;graphics
mov al,'_'
	call	prtbout
	ret
dgrchr	endp

dgresch	proc	near			; RS F e <n><n>  DG Reserve Character
	mov	bx,offset atnorm	; discard
	jmp	get2n
dgresch	endp

dgskl	proc	near			; RS F f <n>  DG Set Kbd Language
	mov	bx,offset dgskl1
	jmp	get1n			; get parameter
dgskl1:	mov	ax,dgnum		; 0=setup, 1=DG Int, 2=Latin1
	cmp	ax,2			; in range?
	ja	dgskl4			; a = no
	cmp	ax,1			; DG International?
	je	dgskl2			; e = yes
	ja	dgskl3			; a = no, Latin1
	mov	al,vtemu.vtchset	; get setup char set
	mov	dgkbl,al		; store keyboard language ident
	ret
dgskl2:	mov	dgkbl,20		; DG International
	ret
dgskl3:	mov	dgkbl,16		; Latin1
dgskl4:	ret
dgskl	endp

dgsdo	proc	near			; RS R B <n><n><n> Set Device Options
	mov	bx,offset dgsdo1	; get first <n>
	jmp	get1n
dgsdo1:	mov	bx,offset atnrm		; get second and third <n>'s
	jmp	get2n			; discard all
dgsdo	endp

dgsfield:mov	bx,offset dgsfie1	; RS F C <ss><rr>  Field attributes
	jmp	get2n			; get first <nn>
dgsfie1:mov	bx,offset atnrm		; discard proc
	jmp	get2n			; get second <nn>

dgspage:mov	bx,offset dgspag1	; RS F D <ss><rr>  Page attributes
	jmp	get2n			; get first <nn>
dgspag1:mov	bx,offset atnrm		; discard proc
	jmp	get2n			; get second <nn>

dgsetw	proc	near			; RS F B <nn><n>.. Set windows
	mov	dgwindcnt,0		; count of windows entries
	mov	emubuf+4,0		; normal(0)/compressed (!0) flag
dgsetw1:mov	bx,offset dgsetw2	; next processor
	jmp	get2n			; get a <nn> window length
dgsetw2:mov	ax,dgnum
	mov	word ptr emubuf,ax	; save around get1n work
	mov	bx,offset dgsetw2a	; get <n> 0/1, compressed mode
	jmp	get1n
dgsetw2a:mov	ax,dgnum
	mov	emubuf+4,al		; save copy for just this window
	mov	ax,word ptr emubuf	; <nn> length, 0 (end) to 24
	or	ax,ax			; end of set indicator?
	jnz	dgsetw2b		; nz = no
	mov	ax,24			; pseudo end
dgsetw2b:xchg	al,ah			; put row in ah
	mov	bx,dgwindcnt		; get subscript
	cmp	bx,24			; too many windows? (24 == DG limit)
	ja	dgsetw7			; a = yes, else accept data
	inc	bx
	mov	dgwindcnt,bx		; update counter (1 == one window)
	dec	bx
	shl	bx,1			; index words
	or	bx,bx			; initial window?
	jnz	dgsetw3			; nz = no
	xor	al,al			; start at 0,0
	jmp	short dgsetw4
dgsetw3:mov	al,byte ptr dgwindow[bx-1] ; previous ending line
	inc	al			; start this window down one line
dgsetw4:add	ah,al			; new mar_bot = new mar_top + skip
	dec	ah			; count lines from zero
	cmp	ah,byte ptr low_rgt+1	; bottom of displayable screen?
	jb	dgsetw5			; b = no
	mov	ah,byte ptr low_rgt+1	; clamp to that bottom
dgsetw5:mov	dgwindow[bx],ax		; save [al=mar_top,ah=mar_bot] pair
	mov	al,ah			; get current bottom
	mov	ah,byte ptr low_rgt+1	; last text line
	mov	dgwindow[bx+2],ax	; fill remaining space with next wind

	push	bx			; setup new margins, keep window ptr
	mov	dghscrdis,0		; horz scroll disable is disabled
	mov	cx,slen			; max screen length
	mov	al,mar_left
	xor	bx,bx
dgsetw6:mov	linescroll[bx],al	; horiz scroll left margin to edge
	inc	bx
	loop	dgsetw6
	pop	bx			; recover current line count in bx

	mov	al,emubuf+4		; get compressed/normal for this wind
	mov	dh,byte ptr dgwindow[bx+1]; set cursor to bottom row of window
	or	al,al			; to regular width?
	jnz	dgsetw7			; nz = no, to compressed
	call	dgnarrow		; to normal width
	jmp	short dgsetw8
dgsetw7:call	dgwide			; compress things

dgsetw8:mov	bx,dgwindcnt		; get window count
	or	bx,bx			; any windows (0 = no)
	jz	dgsetw9
	dec	bx			; count from 0
	shl	bx,1			; count words
	mov	al,byte ptr low_rgt+1	; last text line on screen (typ 23)
	cmp	byte ptr dgwindow[bx+1],al ; DG limit of 24 lines?
	jb	dgsetw1			; b = not reached yet, keep going

dgsetw9:call	dgshome			; do necessary DG Screen Home
	ret
dgsetw	endp

dgwwa	proc	near			; Control-P col row
	mov	ttstate,offset dgwwa1	; DG Write window address (win rel)
	ret				; get raw binary col
dgwwa1:	mov	emubuf,al		; save col
	mov	ttstate,offset dgwwa2	; get raw binary row
	ret
dgwwa2:	mov	ttstate,offset atnrm	; reset state
	cmp	al,127			; 127 means use current row
	je	dgwwa3			; e = yes
	add	al,mar_top		; relative to window top
	mov	dh,al			; set cursor row
dgwwa3:	xor	al,al			; get a zero
	xchg	al,emubuf		; get raw column, clear temp word
	cmp	al,127			; 127 means use current column
	je	dgwwa4			; e = yes
	add	al,mar_left		; add left margin
	mov	dl,al			; new cursor position
dgwwa4:	cmp	dh,mar_bot		; below bottom of window?
	jbe	dgwwa5			; be = no, in bounds
	mov	dh,mar_bot		; peg at bottom
dgwwa5:	cmp	dl,mar_right		; beyond right margin?
	jbe	dgwwa6			; be = no, in bounds
	mov	dl,mar_right		; peg at right
dgwwa6:	jmp	dgsetcur		; set cursor within window
dgwwa	endp

dgwsa	proc	near			; RS F P <nn><nn> Write screen address
	mov	bx,offset dgwsa1	; get <nn> col
	jmp	get2n
dgwsa1:	mov	ax,dgnum		; absolute column
	mov	ah,mar_right		; right most virtual column
	cmp	al,-1			; means same screen column?
	je	dgwsa2a			; e = yes
	cmp	al,ah			; beyond right screen limit?
	jbe	dgwsa2			; be = no
	mov	al,ah			; peg at the right
dgwsa2:	mov	byte ptr cursor,al	; column of cursor
dgwsa2a:mov	bx,offset dgwsa3	; get <nn> row
	jmp	get2n
dgwsa3:	mov	ax,dgnum		; get absolute row
	mov	ah,byte ptr low_rgt+1	; last text row
	cmp	al,-1			; means same screen row?
	je	dgwsa5			; e = yes
	cmp	al,ah			; below text screen?
	jbe	dgwsa4			; be = no
	mov	al,ah			; peg at the bottom
dgwsa4:	mov	byte ptr cursor+1,al	; new row
dgwsa5:	mov	dx,cursor
	call	dggetmar		; get margins for this dx
	add	dl,mar_left		; add left margin
	jmp	dgsetcur		; set cursor, protection included
dgwsa	endp

dgshome	proc	near			; RS F G  DG Screen Home
	xor	dh,dh			; absolute screen top
	call	dggetmar		; get margins for this dx
	mov	dl,mar_left		; go to left margin
	jmp	dgsetcur		; set the cursor
dgshome	endp

dgsetmar proc	near			; RS F X <nn> <nn> Set margins
	call	dggetmar		; get margins for this window row
	mov	bx,offset dgsetm1	; get <nn> left margin
	jmp	get2n
dgsetm1:mov	al,mar_left		; current left margin
	mov	emubuf,al
	mov	ax,dgnum		; get left margin info
	cmp	al,-1			; use current margin?
	je	dgsetm2			; e = yes
	mov	emubuf,al		; set left margin
dgsetm2:mov	bx,offset dgsetm3	; get right margin
	jmp	get2n
dgsetm3:mov	ax,dgnum		; get right margin info
	cmp	al,-1			; use current margin?
	jne	dgsetm4			; ne = no
	mov	al,vswidth-1		; use full screen
dgsetm4:cmp	al,vswidth-1		; check sanity
	ja	dgsetmx			; a = too large a right margin
	cmp	al,emubuf		; getting things on the wrong side?
	jb	dgsetmx			; b = yes (ok for left=right)
dgsetm5:cmp	emubuf,vswidth-1	; this side too
	jae	dgsetmx			; ae = too large
	mov	mar_right,al		; set right margin
	mov	al,emubuf		; new left
	mov	mar_left,al		; new left
	mov	byte ptr cursor,al	; set cursor to left margin
	mov	dx,cursor
	mov	emubuf,al		; preset args for dgschw1
	mov	al,mar_right
	mov	emubuf+1,al
	jmp	dgschw1			; try to show both margins, set cursor
dgsetmx:ret				; ignore command
dgsetmar endp

dgsetamar proc	near			; DG RS F Y <nn><nn><nn>
	cmp	savdgmar,0		; have we saved l/r margins?
	jne	dgsetam0		; ne = yes, don't save current
	mov	ah,mar_right		; save originals
	mov	al,mar_left
	mov	savdgmar,ax		; saved
dgsetam0:mov	bx,offset dgsetam1	; Set Alternate Margins
	jmp	get2n			; get cursor row
dgsetam1:mov	ax,dgnum		; cursor row wrt top margin
	mov	bl,dh			; row of cursor
	cmp	al,-1			; use current row?
	je	dgsetam2		; e = yes
	mov	bl,mar_top		; get row at top of this window
	add	bl,al			; new cursor row is mar_top + new
dgsetam2:cmp	bl,mar_bot		; below window?
	jbe	dgsetam3		; be = no
	mov	bl,mar_bot		; clamp to window bottom
dgsetam3:mov	emubuf,bl		; save cursor row
	mov	bx,offset dgsetam4	; get <nn> col of new left margin
	jmp	get2n
dgsetam4:mov	ax,dgnum
	mov	bl,byte ptr savdgmar	; get permanent left margin
	cmp	al,-1			; use current left margin?
	je	dgsetam5		; e = yes
	add	bl,al			; new left, wrt old left
dgsetam5:mov	word ptr emubuf+2,bx	; save left margin
	mov	bx,offset dgsetam6	; get <nn> right margin
	jmp	get2n
dgsetam6:mov	ax,dgnum
	mov	bl,byte ptr savdgmar+1	; current right margin
	cmp	al,-1			; use current right margin?
	je	dgsetam7		; e = yes
	mov	bl,al			; new relative right margin
	add	bl,mar_left		; relative to old left margin
	cmp	bl,byte ptr savdgmar+1	; exceeds old right_margin?
	jbe	dgsetam7		; be = no
	mov	bl,byte ptr savdgmar+1	; yes, use old right_margin
dgsetam7:cmp	bl,vswidth-1		; too far right?
	ja	dgsetam9		; a = yes, abandon the command
	mov	mar_right,bl		; alt right margin
	mov	al,emubuf+2		; get alt left margin
	mov	mar_left,al
	mov	dl,al			; cursor to left margin
	mov	dh,emubuf		; get row for cursor
	mov	dghscrdis,1		; horz scroll disabled (if 1)
	call	dgsetcur		; set cursor
dgsetam9:ret
dgsetamar endp

dgrnmar	proc	near			; RS F Z  DG Restore normal margins
	cmp	savdgmar,0		; anything saved?
	jz	dgrnma1			; z = no, do nothing
	xor	ax,ax			; get a null
	xchg	ax,savdgmar		; recover saved margins, clear saved
	mov	mar_left,al
	mov	mar_right,ah
dgrnma1:ret
dgrnmar	endp

; Worker. Given cursor in dx, set mar_top, mar_bot based on finding the 
; DG window for that cursor row.
dggetmar proc	near
	mov	cx,dgwindcnt		; number of windows
	xor	bx,bx
	jcxz	dggetma2		; z = none
	inc	cx			; let implied last window be seen
dggetma1:cmp	dh,byte ptr dgwindow[bx+1] ; look at window bottom edge
	jbe	dggetma3		; be = cursor is in this window
	add	bx,2			; skip two margin bytes
	loop	dggetma1		; next window
dggetma2:ret

dggetma3:mov	ax,dgwindow[bx]		; DG Window structure
	mov	mar_top,al
	mov	mar_bot,ah
	ret
dggetmar endp

; Worker. Given cursor in dx, and al=mar_top, ah=mar_bot
; store these margins in the window structure for that row, based on
; finding the DG window for that cursor row.
dgstoremar proc	near
	push	cx
	mov	cx,dgwindcnt		; number of windows
	xor	bx,bx
	jcxz	dgstore2		; z = none
dgstore1:cmp	dh,byte ptr dgwindow[bx+1] ; look at window bottom edge
	jbe	dgstore2		; be = cursor is in this window
	add	bx,2			; skip two margin bytes
	loop	dgstore1		; next window
	xor	bx,bx			; fail, use first window slot
dgstore2:pop	cx
	mov	dgwindow[bx],ax
	ret
dgstoremar endp

dgsmid	proc	near			; RS F { <nn><n> DG Set Model ID
	mov	bx,offset dgsmid1	; setup for <nn>
	jmp	get2n
dgsmid1:mov	ax,dgnum		; get new model id
	mov	byte ptr dgaltid,al	; save
	mov	bx,dgsmid2		; get graphics possible (1) bit
	jmp	get1n
dgsmid2:mov	ax,dgnum
	mov	byte ptr dgaltid+1,al
	ret
dgsmid	endp

dgscrup	proc	near			; DG  RS H
	mov	scroll,1
	call	atscru			; scroll up one line
	jmp	dgsetcur		; place according to protected mode
dgscrup endp

dgscrdn	proc	near			; DG  RS I
	mov	scroll,1
	call	atscrd			; scroll down one line
	jmp	dgsetcur		; place according to protected mode
dgscrdn	endp

dgcuu	proc	near			; Control-W  DG cursor up
dgcuu1:	cmp	dh,mar_top		; above the top margin?
	ja	dgcuu2			; a = not on top margin
	mov	dh,mar_bot		; roll to bottom margin
	inc	dh
dgcuu2:	dec	dh			; go up one row
	call	dgcurpchk		; do proteced mode check
	jc	dgcub1			; c = protected, do cursor back
	jmp	atsetcur		; set the cursor
dgcuu	endp

dgcud	proc	near			; Control-Z  DG cursor down
dgcud1:	cmp	dh,mar_bot		; below the bottom text line?
	jb	dgcud2			; b = no
	mov	dh,mar_top		; roll to top margin
	dec	dh
dgcud2:	inc	dh			; go down one row
	call	dgcurpchk		; check for protected cell
	jc	dgcuf1			; c = on protected cell, go forward
	jmp	dgsetcur		; set cursor
dgcud	endp

dgcuf	proc	near			; Control-X  DG cursor forward
	cmp	dl,mar_right		; test for about to wrap
	jb	dgcuf1			; b = not wrapping
	test	anspflg,vtautop		; printing desired?
	jz	dgcuf1			; e = no
	push	dx			; save cursor value
	call	pntlin			; print line current line
	mov	al,LF			; terminate in LF
	call	fpntchr
	call	fpntflsh		; flush printer buffer
	mov	atwrap,0
	pop	dx

dgcuf1:	cmp	dl,mar_right		; to right of right margin?
	jb	dgcuf5			; b = not on right margin
	mov	dl,mar_left		; go to left margin
	inc	dh			; and down one
	cmp	dh,mar_bot		; below bottom line now?
	jbe	dgcuf6			; be = no
	mov	dh,mar_bot		; stay on bottom line
	cmp	dgroll,0		; is roll mode disabled?
	jne	dgcuf3			; ne = no, do the scroll
	mov	dh,mar_top		; yes, wrap to top
	jmp	short dgcuf6
dgcuf3:	mov	scroll,1
	call	atsetcur		; set cursor before the scroll
	call	atscru			; scroll up one line
	ret
dgcuf5:	inc	dl			; go right one column
dgcuf6:	cmp	dx,cursor		; is this the same place?
	je	dgcuf7			; e = yes, stop here
	call	dgcurpchk		; check protection
	jc	dgcuf1			; c = stepped on protected cell
dgcuf7:	jmp	atsetcur		; set cursor
dgcuf	endp

dgcub	proc	near			; Control-Y  DG cursor left
dgcub1:	cmp	dl,mar_left		; to left of left margin?
	ja	dgcub2			; a = no
	mov	dl,mar_right		; go to right margin 
	jmp	dgcuu1			; and do a cursor up
dgcub2:	dec	dl			; go left one column
	call	dgcurpchk		; check protection
	jc	dgcub1			; c = stepped on protected cell
	jmp	atsetcur		; set real cursor and exit
dgcub	endp

dgcurpchk proc	near
	cmp	protectena,0		; protected mode enabled?
	je	dgcurpc1		; e = no
	push	dx
	push	bx
	mov	bl,dh			; row
	xor	bh,bh
	cmp	linetype[bx],0		; single width?
	pop	bx
	je	dgcurpc2		; e = yes
	shl	dl,1			; double cursor position
dgcurpc2:call	getatch			; read char under new cursor position
	pop	dx
	test	cl,att_protect		; protected?
	jz	dgcurpc1		; z = no, accept this position
	stc				; say stepping on protected char cell
	ret
dgcurpc1:clc				; say no other action needed
	ret
dgcurpchk endp

; Worker for cursor cmds. Skips protected fields, but remembers if we have
; come full circle and then does a cursor right from there. Enter with
; pre-motion cursor in "cursor", new desired position in dx.
dgsetcur proc	near
	call	dgcurpchk		; call protected cell checker
	jnc	dgsetcu1		; nc = ok, accept this position
	jmp	dgcuf1			; do cursor forward
dgsetcu1:mov	bl,dh			; get row
	xor	bh,bh
	cmp	dl,linescroll[bx]	; to left of visible screen?
	jae	dgsetcu2		; ae = no
	mov	emubuf,dl		; set desired left margin
	mov	cl,mar_right
	mov	emubuf+2,cl		; set desired right margin
	mov	cursor,dx		; preset for dgschw1
	jmp	dgschw1			; do Show Window to track cursor

dgsetcu2:jmp	atsetcur		; set real cursor and exit
dgsetcur endp

dglf	proc	near			; Control-J  DG New Line
	test	anspflg,vtautop		; printing desired?
	jz	dglf1			; e = no
	push	dx			; save cursor
	call	pntlin			; print line
	mov	al,LF			; terminate in LF
	call	fpntchr
	call	fpntflsh		; flush printer buffer
	mov	atwrap,0
	pop	dx
dglf1:	mov	dl,mar_left		; to left margin
	cmp	dh,mar_bot		; on bottom margin?
	jb	dglf3			; b = no
	cmp	dgroll,0		; is roll disabled
	je	dglf2			; e = yes, do home
	mov	bl,dh			; row
	xor	bh,bh
	mov	al,linescroll[bx]	; save current line scroll
	push	dx
	push	bx
	push	ax
	mov	scroll,1
	call	atscru			; do a scroll up by one line
	pop	ax
	pop	bx
	pop	dx
	mov	linescroll[bx],al	; set line scroll for new line
	jmp	dgsetcur		; set cursor, does show columns too

dglf2:	mov	dh,mar_top		; do window Home
	jmp	short dglf4
dglf3:	inc	dh			; down one row
dglf4:	jmp	dgsetcur		; set cursor wrt protected mode
dglf	endp

dgcr	proc	near			; DG Control-M
	mov	dl,mar_left		; go to left margin, same row
	jmp	dgsetcur		; set cursor, with protected mode
dgcr	endp

dgrmid	proc	near			; RS C  DG Read Model ID
	mov	al,dgescape		; resp RS o # <mm> <x> <y>
	call	prtbout
	mov	al,'o'
	call	prtbout
	mov	al,'#'
	call	prtbout
	mov	al,'5'			; 5 is DG D217
	test	flags.vtflg,ttd217	; D217?
	jnz	dgrmid6			; nz = yes
	mov	al,'6'			; 6 is DG D413/D463
	test	flags.vtflg,ttd470	; D470?
	jz	dgrmid6			; z = no
	mov	al,44			; 44 is DG D470
dgrmid6:cmp	byte ptr dgaltid,0	; alternate ID given?
	je	dgrmid1			; e = no
	mov	al,byte ptr dgaltid	; use alternate
dgrmid1:call	prtbout
	xor	al,al			; <x> byte, clear it
	test	flags.remflg,d8bit	; using 8 bits?
	jz	dgrmid2			; z = no
	or	al,10h			; say 8-bit mode
dgrmid2:push	ax
	mov	ah,ioctl		; get printer status, via DOS
	mov	al,7			; status for output
	push	bx
	mov	bx,4			; std handle for system printer
	int	dos
	pop	bx
	jnc	dgrmid3			; nc = call succeeded
	mov	al,0ffh
dgrmid3:cmp	al,0ffh			; code for Ready
	pop	ax
	jne	dgrmid4			; ne = not ready
	or	al,8			; say printer present
dgrmid4:or	al,40h
	call	prtbout			; send composite byte
	mov	bl,vtemu.vtchset	; get Kermit NRC code (0-13)
	xor	bh,bh
	mov	al,nrcdgkbd[bx]		; <y>, get DG keyboard code from table
	or	al,50h			; 01+kbd installed (no graphics)
	or	al,20h			; say have graphics
	cmp	byte ptr dgaltid,0	; alternate id given?
	je	dgrmid5			; e = no
	cmp	byte ptr dgaltid+1,0	; host wants to say no graphics?
	jne	dgrmid5			; ne = no, let things stand
	and	al,not 20h		; remove graphics bit
dgrmid5:call	prtbout
	ret
dgrmid	endp
					; D470 command, absent from D463's
dgscmap	proc	near			; RS F c <n><n><n><n> DG set color map
	mov	bx,offset dgscmap1	; get language ident
	jmp	get3n			; get three of the <n>'s
dgscmap1:mov	bx,offset dgscmap2	; get the fourth
	jmp	get1n
dgscmap2:ret
dgscmap	endp

dgshcol	proc	near			; RS F _ <nn><nn>  DG Show Columns
	mov	bx,offset dgshco1	; get left col to show
	jmp	get2n
dgshco1:mov	ax,dgnum		; left column to show, is dominant
	mov	cx,vswidth		; max columns in vscreen
	dec	cx			; max column ident
	sub	cl,byte ptr low_rgt	; visible display width - 1
	sbb	ch,0			; max left column showable
	cmp	ax,cx			; want further right than this?
	jbe	dgshco2			; be = no
	mov	ax,cx			; limit to max
dgshco2:mov	emubuf,al		; save max left col to show
	mov	bx,offset dgshco3	; get right col to show
	jmp	get2n
dgshco3:mov	ax,dgnum		; right col
	cmp	al,emubuf		; right less than left?
	jae	dgshco4			; ae = no
	ret				; else ignore command
dgshco4:mov	emubuf+1,al
	cmp	dghscrdis,0		; is horizontal scrolling disabled?
	je	dgschw1			; e = no
	ret				; disabled, ignore this command

; worker. emubuf=wanted visible left, emubuf+1=wanted visible right margin
dgschw1:mov	bl,mar_top		; get window top
	xor	bh,bh
	mov	cl,mar_bot
	sub	cl,bl
	inc	cl
	xor	ch,ch			; lines in window
	mov	al,emubuf+1		; desired right margin
	sub	al,emubuf		; minus desired left
	cmp	al,byte ptr low_rgt	; more than a screen's width?
	jbe	dgschw2			; be = no
	mov	al,emubuf		; desired left
	add	al,byte ptr low_rgt	; plus screen width
	mov	emubuf+1,al		; chop desired rm to give one screen

dgschw2:mov	al,linescroll[bx]	; get scroll now in effect
	cmp	emubuf,al		; is left margin to left of screen?
	jb	dgshw4			; b = yes, put it on screen
	je	dgshw8			; e = there now, do nothing
	mov	ah,emubuf+1		; right margin to use
	add	al,byte ptr low_rgt	; visible right edge
	cmp	al,ah			; visible vs wanted right edge
	jae	dgshw8			; ae = rm visible now, do nothing
	sub	ah,al			; distance right margin is invisible
	xchg	ah,al
	add	al,linescroll[bx]	; new shift plus current shift
	jmp	short dgshw5

dgshw4:	mov	al,emubuf		; new scroll
dgshw5:	mov	linescroll[bx],al	; horiz scroll for this line (window)
	inc	bx
	loop	dgshw5			; do all lines in this window
	mov	dx,cursor
	cmp	dl,al			; is cursor off to the left?
	jae	dgshw6			; ae = no
	mov	dl,al			; offset cursor too
dgshw6:	add	al,byte ptr low_rgt	; visible right edge
	cmp	dl,al			; cursor is on screen?
	jbe	dgshw7			; be = yes
	mov	dl,al			; move cursor to right edge
dgshw7:	push	dx
	mov	dl,mar_top		; region affected
	mov	dh,mar_bot
	call	touchup			; repaint based on new linescroll
	pop	dx
dgshw8:	jmp	dgsetcur		; set cursor, updates screen
dgshcol	endp

dgrnmod	proc	near			; RS F w  DG Read New Model ID
	mov	al,dgescape		; resp RS o w <c><s><r><n><res>
	call	prtbout
	mov	al,'o'
	call	prtbout
	mov	al,'w'
	call	prtbout
	mov	al,'1'			; <c> D217 terminal
	test	flags.vtflg,ttd217 ; DG D217?
	je	dgrnmod3		; e = yes
;	mov	al,'3'			; <c> D413 level graphics terminal
	mov	al,'8'			; <c> D470/D463 graphics terminal
dgrnmod3:call	prtbout
	mov	al,'0'			; <s> pair, 01 is D470/D463
	call	prtbout
	mov	al,'1'
	call	prtbout
	mov	al,'0'			; <r> rev level as <nn>
	call	prtbout			; report 00
	mov	al,'0'
	call	prtbout
	mov	cx,4
;;	mov	si,offset d413model	; 8 char name, all printables
	mov	si,offset d463model	; graphics term name, 8 printables
	test	flags.vtflg,ttd470	; D470?
	jz	dgrnmo1			; z = no
	mov	si,offset d470model
dgrnmo1:lodsb
	push	cx
	call	prtbout
	pop	cx
	loop	dgrnmo1
	mov	cx,4+4			; <reserved> four spaces
dgrnmo2:mov	al,' '
	push	cx
	call	prtbout
	pop	cx
	loop	dgrnmo2
	ret
dgrnmod	endp

dgunix	proc	near			; RS P @ <n>  DG Unix mode
	mov	ttstate,offset dgunix1	; setup to ignore @
	ret
dgunix1:mov	bx,offset atnrm		; consume the <n>
	jmp	get1n
dgunix	endp

dgsct	proc	near			; RS F Q <n>  DG Set Cursor Type
	mov	bx,offset dgsct1
	jmp	get1n			; get the <n> arg
dgsct1:	mov	ax,dgnum		; get cursor type
	or	al,al			; case 0, invisible/off?
	jnz	dgsct2			; nz = no
	call	csrtype			; set text cursor bits, keep kind
	or	atctype,4		; remember, is off
	jmp	short dgsct5

dgsct2:	cmp	al,2			; standard 1,2? (underline, block)
	jbe	dgsct4			; be = yes
	sub	al,5
	neg	al			; 5 - AL
	js	dgsct6			; s = out of range, ignore
	jnz	dgsct4			; nz = cases 3 and 4 (block, uline)
	mov	al,atctype		; case 5, use saved cursor type
	and	al,not 4		; remove invisible bit
dgsct4:	mov	atctype,al		; save text cursor type here
	push	ax
	or	vtemu.vtflgop,vscursor ; set to underlined
	test	al,2			; setting to block?
	jz	dgsct4a			; z = no, underline
	and	vtemu.vtflgop,not vscursor ; say block in status word
dgsct4a:call	csrtype			; set the cursor bits
	pop	ax
dgsct5:	test	tekflg,tek_active+tek_sg ; special graphics mode active?
	jz	dgsct6			; z = no
	mov	dx,cursor
ifndef	no_graphics
	call	teksetcursor		; set new cursor
endif	; no_graphics
dgsct6:	ret
dgsct	endp

dgchatr	proc	near			; RS F N <nnn><n><n> DG change attrib
	mov	bx,offset dgchat1	; get <nnn> qty chars to change
	jmp	get3n
dgchat1:mov	ax,dgnum		; qty chars to change
	mov	word ptr emubuf,ax	; save
	mov	bx,offset dgchat2	; get <n> set list
	jmp	get1n
dgchat2:mov	ax,dgnum		; bitfield for characteristics
	mov	emubuf+2,al		; save set list
	mov	bx,offset dgchat3	; get final <n> reset list
	jmp	get1n
dgchat3:mov	bl,byte ptr dgnum	; get reset list to BL
	mov	emubuf+3,bl		; save reset list
	mov	bh,emubuf+2		; set list
	and	bh,bl			; get toggle bits
	mov	emubuf+4,bh		; save toggle list here
	not	bh			; clear out bits processed here
	and	emubuf+2,bh		; update set list
	and	emubuf+3,bh		; update reset list
	mov	cursor,dx		; save cursor location

	mov	cx,word ptr emubuf	; qty of bytes to change, max
	or	cx,cx			; some count?
	jnz	dgchag4			; nz = something to do
	ret
dgchag4:mov	al,extattr		; preserve settable attributes
	mov	ah,scbattr
	push	ax
dgchag4a:push	cx			; save loop counter
	call	getatch			; get video in ah, extended att in cl
	mov	extattr,cl		; place extended where procs can see
	mov	emubuf+5,al		; save char
	call	dgchag10		; process this char
	mov	al,emubuf+5		; restore char
	call	qsetatch		; quietly update the char
	pop	cx
	inc	dl			; next column
	cmp	dl,mar_right		; at the right margin?
	jbe	dgchag5			; be = no, not yet
	mov	dl,mar_left		; wrap to left and next line
	inc	dh			; next line down
	cmp	dh,mar_bot		; below the window bottom?
	ja	dgchag6			; a = yes, all done
dgchag5:loop	dgchag4a		; do more chars
dgchag6:pop	ax
	mov	extattr,al		; restore setables
	mov	scbattr,ah
	mov	dl,byte ptr cursor+1	; dl = starting row, dh = ending row
	mov	dh,mar_bot
	call	touchup			; repaint part of screen
	mov	dx,cursor		; reset cursor location
	ret

; worker for dgchag			; do toggle mode
dgchag10:mov	bh,emubuf+4		; toggle list
	or	bh,bh			; any work?
	jz	dgchag20		; z = no
	test	bh,1			; blink?
	jz	dgchag11		; z = no
	xor	ah,att_blink		; xor blink
dgchag11:test	bh,2			; underscore?
	jz	dgchag13		; z = no
	test	cl,att_uline		; is it set now?
	jz	dgchag12		; z = no
	call	clrunder		; reset it
	jmp	short dgchag13
dgchag12:call	setunder		; set it
dgchag13:test	bh,4			; reverse video
	jz	dgchag15		; z = no
	test	cl,att_rev		; reversed now?
	jz	dgchag14		; z = no
	call	clrrev			; unreverse it
	jmp	short dgchag15
dgchag14:call	setrev			; reverse it
dgchag15:test	bh,8			; Dim
	jz	dgchag20
	xor	ah,att_bold
					; do set list from emubuf+2
dgchag20:mov	bh,emubuf+2		; get set list
	or	bh,bh			; any work?
	jz	dgchag30		; z = no
	test	bh,1			; blink?
	jz	dgchag21		; z = no
	call	setblink		; set blink
dgchag21:test	bh,2			; underscore?
	jz	dgchag22		; z = no
	call	setunder		; set underline
dgchag22:test	bh,4			; reverse video?
	jz	dgchag23		; z = no
	call	setrev			; set reverse video
dgchag23:test	bh,8			; dim?
	jz	dgchag30		; z = no
	call	clrbold			; set Dim
					; do reset list from emubuf+3
dgchag30:mov	bh,emubuf+3		; get reset list
	or	bh,bh			; any work?
	jz	dgchag34		; z = no
	test	bh,1			; blink?
	jz	dgchag31		; z = no
	call	clrblink		; clear blink
dgchag31:test	bh,2			; underscore?
	jz	dgchag32		; z = no
	call	clrunder		; clear underscore
dgchag32:test	bh,4			; reverse video?
	jz	dgchag33		; z = no
	call	clrrev
dgchag33:test	bh,8			; Dim?
	jz	dgchag34		; z = no
	call	setbold			; reset dim
dgchag34:ret				; end of callable worker
dgchatr	endp

dgsclk	proc	near			; RS r <n> <pos> <time> DG Set Clock
	mov	bx,offset dgsclk1	; set up to get <n><0000>
	jmp	get3n
dgsclk1:mov	bx,offset dgsclk2	; setup to get HH
	jmp	get1n
dgsclk2:mov	ttstate,offset dgsclk3	; setup to get ":"
	ret
dgsclk3:mov	bx,offset atnrm		; absorb final MM
	jmp	get1n
dgsclk	endp

dgrss	proc	near			; RS F t  DG Report Screen Size
	mov	al,dgescape		; resp RS o < <5 more items>
	call	prtbout
	mov	al,'o'
	call	prtbout
	mov	al,'<'
	call	prtbout
	mov	al,byte ptr low_rgt+1	; number of screen rows -1
	inc	al
	call	out2n			; first item
	mov	al,207			; number of screen cols (DG hard #)
	call	out2n			; second item
	mov	al,mar_bot
	sub	al,mar_top
	inc	al			; third item, num rows in window
	call	out2n
	mov	al,mar_right
	sub	al,mar_left
	inc	al			; fourth item, num cols in window
	call	out2n
	mov	al,01110000b		; fifth item, status
	call	prtbout
	ret
dgrss	endp

dgrhso	proc	near			; RS F O  DG Read Horz Scroll Offset
	mov	al,dgescape		; resp RS o : <nn>
	call	prtbout
	mov	al,'o'
	call	prtbout
	mov	al,':'
	call	prtbout
	mov	bl,dh			; get current row
	xor	bh,bh
	mov	al,linescroll[bx]	; get scroll value
	call	out2na
	ret
dgrhso	endp

dgrwa	proc	near			; Control-E  DG Read Window Address
	mov	al,1fh			; Response string Control-_ col row
	call	prtbout
	mov	al,dl			; col, raw binary
	call	prtbout
	mov	al,dh			; row, raw binary
	call	prtbout
	ret
dgrwa	endp

dgrsa	proc	near			; RS F b  DG Read Screen Address
	mov	al,dgescape		; resp RS o 8 <nn> <nn>
	call	prtbout
	mov	al,'o'
	call	prtbout
	mov	al,'8'
	call	prtbout
	mov	al,byte ptr cursor	; column
	call	out2na
	mov	al,byte ptr cursor+1	; row
	call	out2na
	ret
dgrsa	endp

dgrwc	proc	near			; RS F v <r1> <c1> <r2> <c2>
	mov	emubufc,0		; counter. DG Read Window Contents
dgrwc1:	mov	bx,offset dgrwc2
	jmp	get2n			; read <nn>
dgrwc2:	mov	bx,emubufc		; get counter
	inc	emubufc
	mov	ax,dgnum		; r1, c1, r2, or c2
	mov	emubuf[bx],al		; save here
	cmp	bx,3			; done all four?
	jb	dgrwc1			; b = no, get more
	mov	dh,emubuf		; starting row
	cmp	dh,emubuf+2		; versus ending row
	ja	dgrwc8			; a = fail if wrong order
dgrwc3:	mov	dl,emubuf+3		; ending column
	mov	cl,dl
	sub	cl,emubuf+1		; minus starting column
	jl	dgrwc8			; fail if wrong order
	inc	cl			; number of cells to examine
	xor	ch,ch

dgrwc4:	push	cx
	push	dx
	call	direction
	call	getatch			; read char into AL at cursor dx
	pop	dx
	pop	cx
	cmp	al,' '			; space?
	jne	dgrwc5			; found non-space
	dec	dl
	loop	dgrwc4
dgrwc5:	jcxz	dgrwc7			; z = only spaces on the line
	mov	dl,emubuf+1		; staring column
dgrwc6:	push	cx
	push	dx
	call	direction
	call	getatch			; get char and attribute
	call	prtbout			; send char in al
	pop	dx
	pop	cx
	inc	dl			; across the row
	loop	dgrwc6			; do all interesting cols
dgrwc7:	push	dx
	mov	al,CR			; send line terminators
	call	prtbout
	mov	al,LF
	call	prtbout
	pop	dx
	inc	dh			; next row down
	cmp	dh,emubuf+2		; beyond last row?
	jbe	dgrwc3			; be = no
	mov	dx,cursor
	mov	emubufc,0		; clear counter
dgrwc8:	ret
dgrwc	endp
		; Data General D463/D470 graphics commands

dggline	proc	near			; RS L and RS G 8  DG line drawing
	call	dgsettek		; setup special graphics mode
dggline1:mov	bx,offset dggline2	; get <NNN> x coord
	jmp	get3loc
dggline2:jc	dggline9		; c = read null terminator
	mov	ax,dgnum		; start x coord
	mov	word ptr emubuf+0,ax	; save here
	mov	word ptr emubuf+4,ax	; and here
	mov	bx,offset dggline3	; get <NNN> y coord
	jmp	get3loc
dggline3:jc	dggline9
	mov	ax,dgnum
	mov	word ptr emubuf+2,ax	; start y
	mov	word ptr emubuf+6,ax	; and here
dggline4:mov	bx,offset dggline5	; get <NNN> end x coord
	jmp	get3loc
dggline5:jc	dggline8		; c = ending on single coord, do a dot
	mov	ax,dgnum
	mov	word ptr emubuf+4,ax	; end x
	mov	bx,offset dggline6	; get <NNN> end y coord
	jmp	get3loc
dggline6:jc	dggline9		; c = null char
	mov	ax,dgnum		; end y
	mov	word ptr emubuf+6,ax
	call	dggline8		; plot line
	jmp	short dggline4		; continue gathering coord pairs

dggline8:				; worker called above
ifndef	no_graphics
	push	word ptr mar_top	; mar_top in low byte
	push	dglinepat		; line pattern
	push	word ptr emubuf+6	; end y
	push	word ptr emubuf+4	; end x
	push	word ptr emubuf+2	; start y
	push	word ptr emubuf+0	; start x
	call	dgline			; do the line
	add	sp,12			; clear the argument stack
	mov	ax,word ptr emubuf+4	; old end is new beginning
	mov	word ptr emubuf,ax
	mov	ax,word ptr emubuf+6
	mov	word ptr emubuf+2,ax
endif	; no_graphics
dggline9:ret
dggline	endp

dggarc	proc	near			; RS G 0  DG arc drawing
	mov	bx,offset dggarc1	; get <NNN> x coord
	jmp	get3loc
dggarc1:jc	dggarc9			; unexpected terminator
	mov	ax,dgnum		; x coord
	mov	word ptr emubuf,ax	; save here
	mov	bx,offset dggarc2	; get <NNN> y coord
	jmp	get3loc
dggarc2:jc	dggarc9
	mov	ax,dgnum
	mov	word ptr emubuf+2,ax
	mov	bx,offset dggarc3	; get <NNN> radius
	jmp	get3loc
dggarc3:jc	dggarc9
	mov	ax,dgnum
	mov	word ptr emubuf+4,ax
	mov	bx,offset dggarc4	; get <NNN> start angle
	jmp	get3loc
dggarc4:jc	dggarc9
	mov	ax,dgnum
	mov	word ptr emubuf+6,ax
	mov	bx,offset dggarc5	; get <NNN> end angle
	jmp	get3loc
dggarc5:
ifndef	no_graphics
	call	dgsettek		; setup graphics mode
	mov	al,mar_bot		; bottom margin in PC text lines
	xor	ah,ah
	push	ax
	mov	al,mar_top		; top margin in PC text lines
	push	ax
	push	dgnum			; end angle
	push	word ptr emubuf+6	; start angle
	push	word ptr emubuf+4	; radius
	push	word ptr emubuf+2	; start y
	push	word ptr emubuf+0	; start x
	call	dgarc			; draw the arc in msgibm
	add	sp,14			; clean stack
endif	; no_graphics
dggarc9:ret
dggarc	endp

dggbar	proc	near			; RS G 1  DG bar drawing
	call	dgsettek		; setup special graphics mode
	mov	bx,offset dggbar1	; get <NNN> x coord, lower left
	jmp	get3loc
dggbar1:jc	dggbar9			; c = unexpected terminator
	mov	ax,dgnum		; x coord
	mov	word ptr emubuf,ax	; save here
	mov	bx,offset dggbar2	; get <NNN> y coord
	jmp	get3loc
dggbar2:jc	dggbar9
	mov	ax,dgnum
	mov	word ptr emubuf+2,ax
	mov	bx,offset dggbar3	; get <NNN> width
	jmp	get3loc
dggbar3:jc	dggbar9
	mov	ax,dgnum
	mov	word ptr emubuf+4,ax
	mov	bx,offset dggbar4	; get <NNN> height
	jmp	get3loc
dggbar4:jc	dggbar9
	mov	ax,dgnum
	mov	word ptr emubuf+6,ax
	mov	bx,offset dggbar5	; get <n> foreground/background
	jmp	get1n
dggbar5:jc	dggbar9
ifndef	no_graphics
	xor	ah,ah
	mov	al,mar_bot
	push	ax
	mov	al,mar_top
	push	ax
	push	dgnum			; fore(1) or background (0) color
	push	word ptr emubuf+6	; height
	push	word ptr emubuf+4	; width
	push	word ptr emubuf+2	; start y lower left corner
	push	word ptr emubuf+0	; start x
	call	dgbar			; msgibm bar drawer
	add	sp,14			; clean stack
endif	; no_graphics
dggbar9:ret
dggbar	endp

dggpoly	proc	near			; RS G :  DG polygon fill drawing
	mov	word ptr rdbuf,0	; count argument pairs
dggpol1:mov	bx,offset dggpol2	; get <NNN> x coord
	jmp	get3loc
dggpol2:jc	dggpol4			; c = got null terminator
	mov	ax,dgnum		; x coord
	mov	word ptr emubuf,ax	; save here
	mov	bx,offset dggpol3	; get <NNN> y coord
	jmp	get3loc
dggpol3:jc	dggpol4
	mov	bx,word ptr rdbuf	; vertex index
	shl	bx,1			; count words
	shl	bx,1			; count pairs
	mov	cx,word ptr emubuf	; x coord
	mov	ax,dgnum		; y coord
	mov	word ptr rdbuf+2[bx],cx	; stuff x
	mov	word ptr rdbuf+2[bx+2],ax ; stuff y
	inc	word ptr rdbuf		; another vertex in list
	jmp	short dggpol1		; get another vertex
dggpol4:cmp	word ptr rdbuf,3	; minimum viable point count
	jb	dggpol6			; b = insufficient qty
	mov	bx,word ptr rdbuf	; vertex index
	shl	bx,1			; count words
	shl	bx,1			; count pairs
	mov	al,mar_top
	xor	ah,ah
	mov	word ptr rdbuf+2[bx],ax	; top margin, PC text lines
	mov	al,mar_bot
	mov	word ptr rdbuf+2[bx+2],ax ; bottom margin, PC text lines
	call	dgsettek		; setup special graphics mode
	mov	al,curattr		; save current coloring
	push	ax
	test	flags.vtflg,ttd463+ttd217 ; D463/D217?
	jz	dgpoly5			; z = no
	and	al,0f0h			; remove foreground
	or	al,dg463fore		; OR in D463 foreground color
	mov	curattr,al		; set drawing coloring
dgpoly5:
ifndef	no_graphics
	call	dgpoly			; call worker in msgibm
endif	; no_graphics
	pop	ax
	mov	curattr,al		; restore coloring
dggpol6:ret
dggpoly	endp

dggsetp	proc	near			; RS G p 1  DG Set Pattern
	mov	ttstate,offset dggset1	; setup to read the 1
	ret
dggset1:cmp	al,'1'			; correct?
	je	dggset2			; e = yes
dggsetx:jmp	atnorm			; fail and reset state
dggset2:mov	ttstate,offset dggset3	; setup to read <offset>
	mov	dglinepat,0		; init line pattern to all zeros
	call	dgsettek		; setup special graphics mode
	ret
dggset3:sub	al,'@'			; remove ASCII bias
	jc	dggset9			; c = failure
	and	al,1fh			; keep lower five bits
	xor	ah,ah
	mov	word ptr emubuf,ax	; save initial bit position
	mov	cl,al
	rcl	dglinepat,cl		; rotate initial pattern
	mov	ttstate,offset dggset4	; setup to read <n> 0/1 bit
	ret
dggset4:or	al,al			; null terminator?
	jz	dggset6			; z = yes
	and	al,0fh			; keep lower four bits of <n>
	cmp	al,1			; legal values are 0, 1, and other
	jbe	dggset5			; be = 0 or 1
	xor	al,al			; above 1 is made to be zero
dggset5:rcr	al,1
	rcr	dglinepat,1		; put into line pattern high bit
	inc	word ptr emubuf		; count bit added to pattern
	ret				; continue in state dggset4

dggset6:mov	cx,16			; bits in pattern
	sub	cx,word ptr emubuf	; get pattern bit count
	jle	dggset9			; le = rotated enough
	mov	ax,dglinepat		; pattern
	mov	bx,ax			; a copy
	mov	cx,word ptr emubuf	; pattern bit count
	mov	dx,16			; overall bits
dggset6a:sub	dx,cx			; minus original pattern
	jg	dggset7			; g = still have room to copy
	je	dggset8			; e = all done
	neg	dx
	mov	cx,dx			; else tag end
dggset7:ror	ax,cl			; rotate pattern to starting position
	or	ax,bx			; move in a copy
	jmp	short dggset6a

dggset8:mov	dglinepat,ax		; store line pattern
dggset9:jmp	atnorm
dggsetp	endp

dggrcl	proc	near			; RS G ? |  DG Read Cursor Location
	mov	ttstate,offset dggrcl1
	ret
dggrcl1:mov	ttstate,atnrm		; reset state
	cmp	al,'|'			; correct terminator?
	jne	dggrcl3			; ne = no
dggrcl2:
ifndef	no_graphics
	call	dgcrossrpt		; generate report in msgibm
endif	; no_graphics
dggrcl3:ret
dggrcl	endp

dggcon	proc	near			; RS G B  DG Cursor on
ifndef	no_graphics
	call	dgsettek		; setup special graphics mode
	call	dgcrosson		; turn on crosshair
endif	; no_grpahics
	ret
dggcon	endp

dggcoff	proc	near			; RS G C  DG Cursor off
ifndef	no_graphics
	call	dgcrossoff		; turn off crosshair
endif	; no_graphics
	ret
dggcoff	endp

dggcloc	proc	near			; RS G > | <NNN> <NNN> DG Cursor loc
	mov	ttstate,offset dggclo1	; get vertical bar
	ret
dggclo1:mov	ttstate,offset atnrm	; reset state
	cmp	al,'|'			; correct character?
	je	dggclo2			; e = yes
	ret
dggclo2:mov	bx,offset dggclo3	; get <nnn> x ordinate
	jmp	get3loc			; as 15 bit location argument
dggclo3:mov	ax,dgnum
	mov	word ptr emubuf,ax	; got x ordinate
	mov	bx,offset dggclo4	; get <nnn> y ordinate
	jmp	get3loc			; as 15 bit location argument
dggclo4:mov	bx,dgnum		; setup registers for call
	mov	ax,word ptr emubuf
ifndef	no_graphics
	call	dgsetcrloc		; setup crosshair location
endif	; no_graphics
	ret
dggcloc	endp

dggctrk	proc	near			; RS G H <n>  DG Cursor track
	mov	bx,offset dggctr1
	jmp	get1n
dggctr1:and	al,2+4			; pick out our trackables
	and	dgcross,not (2+4)	; preserve on/of bit (1)
	or	dgcross,al		; track keypad (2) and/or mouse (4)
	ret
dggctrk	endp

dggcatt	proc	near			; RS G @  DG graphics cursor attribute
	mov	al,dgescape
	call	prtbout
	mov	al,'o'
	call	prtbout
	mov	al,','
	call	prtbout
	mov	al,'0'			; say crosshair is off
	test	dgcross,1		; is it on?
	jz	dggcatt1		; z = no
	inc	al			; say '1' for on
dggcatt1:call	prtbout			; output <v1>
	mov	al,'0'			; <v2> is always 0 for not blinking
	call	prtbout
	mov	al,'1'			; <v3> is 1 for long crosshair, D463
	test	flags.vtflg,ttd470	; D470?
	jz	dggcatt2		; z = no
	dec	al			; <v3> is 0 for short crosshair, D470
dggcatt2:call	prtbout
	mov	al,dgcross		; get tracked devices
	and	al,2+4			; pick out just devices
	add	al,'0'			; bias
	call	prtbout			; output <v4>
	mov	al,CR			; terminal character
	call	prtbout
	ret
dggcatt	endp

dggcrst	proc	near			; RS G A  DG Cursor reset
ifndef	no_graphics
	call	dgcrossoff		; turn off crosshair
endif	; no_graphics
	mov	dgcross,0		; and no kind of tracking
	ret
dggcrst	endp

; D470 ANSI mode support routines

dgesc_ch proc	near			; ESC <Gn> <set> Select character set
	cmp	ninter,1		; just one intermediate?
	je	dgesc_ch2		; e = yes, designator
	cmp	inter+1,' '		; DRCB 1..16?
	je	dgesc_ch1		; e = yes
	cmp	inter+1,'!'		; DRCB 17..22?
	je	dgesc_ch1		; e = yes
	ret				; else ignore
dgesc_ch1:mov	bx,20h			; identify one soft set
	jmp	short dgesc_ch4

dgesc_ch2:cmp	al,'0'			; final char, use keyboard language?
	jne	dgesc_ch3		; ne = no, look it up
	xor	bh,bh
	mov	bl,vtemu.vtchset	; get setup char set
	cmp	bl,13			; top of the NRCs
	jbe	short dgesc_ch4		;  as keyboard language
	xor	bx,bx			; default to ASCII
	jmp	short dgesc_ch4
dgesc_ch3:xor	bx,bx			; look up set in table
	push	es
	mov	di,seg d470chr		; get translation table address
	mov	es,di
	mov	di,offset d470chr
	mov	cx,d470chrlen		; get table length
	cld
	repne	scasb			; look for match
	pop	es
	dec	di			; backup on match
	jne	dgesc_ch5		; ne = no match, ignore
	sub	di,offset d470chr	; compute index
	mov	bl,mskchr[di]		; get Kermit equivalent code
	xor	bh,bh
dgesc_ch4:				; bx holds Kermit set ident
	mov	al,inter		; get set designator
	sub	al,'('			; minus bias
	xor	ah,ah
	cmp	al,3			; range check 0..3
	ja	dgesc_ch5		; a = out of range
	mov	si,ax			; point at set id
	mov	Gsetid[si],bl		; indentify new set
	mov	bx,offset Gsetid	; tell chrset where to get info
	jmp	chrsetup		; create new set
dgesc_ch5:ret
dgesc_ch endp

dgesc_c	proc	near			; DG ESC c  reset terminal
	cmp	ninter,0		; any intermediates?
	jne	dgesc_c1		; ne = yes, not this command
	cmp	nparam,0		; no params too?
	jne	dgesc_c1		; ne = no, ignore
	jmp	atreset			; reset
dgesc_c1:ret
dgesc_c endp

dgesc_D	proc	near			; DG ESC D index
	cmp	ninter,0		; any intermediates?
	jne	dgesc_D5		; ne = yes, not this command
	test	anspflg,vtautop		; printing desired?
	jz	dgesc_D1		; e = no
	push	dx			; save cursor
	call	pntlin			; print line
	mov	al,LF			; terminate in LF
	call	fpntchr
	call	fpntflsh		; flush printer buffer
	mov	atwrap,0
	pop	dx
dgesc_D1:cmp	dh,mar_bot		; on bottom margin?
	jb	dgesc_D3		; b = no
	cmp	dgroll,0		; is roll disabled
	je	dgesc_D2		; e = yes, do home
	push	dx
	mov	scroll,1
	call	atscru			; do a scroll up by one line
	pop	dx
	jmp	dgsetcur		; set cursor, does show columns too

dgesc_D2:mov	dh,mar_top		; do window Home
	jmp	short dgesc_D4
dgesc_D3:inc	dh			; down one row
dgesc_D4:jmp	dgsetcur		; set cursor wrt protected mode
dgesc_D5:ret
dgesc_D endp

dgesc_E	proc	near			; DG ESC E next line
	cmp	ninter,0		; any intermediates?
	jne	dgesc_E1		; ne = yes, not this command
	jmp	dglf			; do line feed
dgesc_E1:ret
dgesc_E	endp

dgesc_M	proc	near			; DG ESC M reverse index
	cmp	ninter,0		; any intermediates?
	jne	dgesc_M3		; ne = yes, not this command
	test	anspflg,vtautop		; printing desired?
	jz	dgesc_M1		; e = no
	push	dx			; save cursor
	call	pntlin			; print line
	mov	al,LF			; terminate in LF
	call	fpntchr
	call	fpntflsh		; flush printer buffer
	mov	atwrap,0
	pop	dx
dgesc_M1:cmp	dh,mar_top		; on top margin?
	ja	dgesc_M2		; a = no
	cmp	dgroll,0		; is roll disabled
	je	dgesc_M3		; e = yes, do nothing
	push	dx
	mov	scroll,1
	call	atscrd			; do a scroll down by one line
	pop	dx
	jmp	dgsetcur		; set cursor, does show columns too
	
dgesc_M2:jmp	dgcuu			; do cursor up
dgesc_M3:ret
dgesc_M	endp


dgesc_V	proc	near			; DG ESC V start protected area
	cmp	ninter,0		; any intermediates?
	jne	dgesc_V1		; ne = yes, not this command
	call	setprot			; protect on
dgesc_V1:ret
dgesc_V endp

dgesc_W	proc	near			; DG ESC W end protected area
	cmp	ninter,0		; any intermediates?
	jne	dgesc_W1		; ne = yes, not this command
	call	clrprot			; protect off
dgesc_W1:ret
dgesc_W endp

dgcsi_@	proc	near			; DG CSI Pc @  ins chars, scroll left
	cmp	inter,' '		; see if ends in space
	je	dgcsi_@1		; e = yes
	mov	cx,param		; do cx chars
	or	cx,cx			; zero?
	jnz	dgcsi_@2		; nz = no
	inc	cx			; zero means one
dgcsi_@2:mov	bh,1			; insert operation
	jmp	insdel			; insert space
dgcsi_@1:mov	bx,offset dgsleft	; scroll left
	jmp	dec2getn		; convert param
dgcsi_@ endp

dgcsi_A	proc	near			; DC CSI Pc A cursor up, scroll right
	cmp	inter,' '		; see if ends in space
	je	dgcsi_A2		; e = yes
	mov	cx,param		; do cx chars
	or	cx,cx			; zero?
	jnz	dgcsi_A1		; nz = no
	inc	cx			; do once
dgcsi_A1:push	cx
	call	dgcuu			; cursor up
	pop	cx
	loop	dgcsi_A1
	ret
dgcsi_A2:mov	bx,offset dgsright	; scroll left
	jmp	dec2getn		; convert param
dgcsi_A endp

dgcsi_B	proc	near			; DC CSI Pc B cursor down
	mov	cx,param		; do cx chars
	or	cx,cx			; zero?
	jnz	dgcsi_B1		; nz = no
	inc	cx			; do once
dgcsi_B1:push	cx
	call	dgcud			; cursor down
	pop	cx
	loop	dgcsi_B1
	ret
dgcsi_B endp

dgcsi_C	proc	near			; DC CSI Pc C cursor forward
	mov	cx,param		; do cx chars
	or	cx,cx			; zero?
	jnz	dgcsi_C1		; nz = no
	inc	cx			; do once
dgcsi_C1:push	cx
	call	dgcuf			; cursor forward
	pop	cx
	loop	dgcsi_C1
	ret
dgcsi_C endp

dgcsi_D	proc	near			; DC CSI Pc D cursor back
	mov	cx,param		; do cx chars
	or	cx,cx			; zero?
	jnz	dgcsi_D1		; nz = no
	inc	cx			; do once
dgcsi_D1:push	cx
	call	dgcub			; cursor back
	pop	cx
	loop	dgcsi_D1
	ret
dgcsi_D endp

dgcsi_L	proc	near			; DG CSI Pc L  insert Pc lines
	push	dx			; save cursor
	call	inslin			; do insert line, can scroll
	pop	dx			; recover cursor
	jmp	atsetcur		; reset cursor
dgcsi_L endp

dgcsi_M	proc	near			; DG CSI Pc M  delete Pc lines
	push	dx			; save cursor
	call	dellin			; delete lines
	pop	dx
	jmp	atsetcur		; reset cursor
dgcsi_M	endp

dgcsi_S	proc	near			; DC CSI Pc S  scroll up
	mov	ax,param		; scroll count
	or	al,al			; zero?
	jnz	dgcsi_S1		; nz = no
	inc	al
dgcsi_S1:mov	scroll,al		; scroll amount
	call	atscru			; scroll up
	ret
dgcsi_S	endp

dgcsi_T	proc	near			; DC CSI Pc T  scroll down
	mov	ax,param		; scroll count
	or	al,al			; zero?
	jnz	dgcsi_T1		; nz = no
	inc	al
dgcsi_T1:mov	scroll,al		; scroll amount
	call	atscrd			; scroll down
	ret
dgcsi_T	endp

dgcsi_f	proc	near			; DG CSI row; col f
	mov	ax,param+2		; get column
	or	al,al			; zero now?
	jz	dgcsi_f1		; z = yes
	dec	al			; count from 0
dgcsi_f1:mov	emubuf,al		; column
	mov	ax,param		; get row
	or	al,al			; zero now?
	jz	dgcsi_f2		; z = yes
	dec	al			; count from 0
dgcsi_f2:jmp	dgwwa2			; do Control-P col row
dgcsi_f endp

dgcsi_h	proc	near			; DG CSI Pc; Pc h  set mode
	mov	modeset,1		; say setting modes
	cmp	lparam,'<'
	jne	dgcsi_h1
	mov	di,offset dgcsi_rsm	; set/reset routine
	call	atreps			; repeat for all parameters
dgcsi_h1:ret
dgcsi_h endp

dgcsi_i	proc	near			; DG CSI Pc i  media copy
	cmp	lparam,'<'		; CSI < 0 ?
	jne	dgcsi_i1		; ne = no
	ret				; ignore CSI <0
dgcsi_i1:mov	ax,param		; get parameter
	cmp	ax,4			; stop media copy?
	je	dgcsi_i2		; e = yes
	cmp	ax,5			; start media copy?
	je	dgcsi_i2		; e = yes
	or	ax,ax			; print window?
	je	dgcsi_i3		; e = yes
	ret				; ignore others
dgcsi_i2:jmp	ansmc			; do 4, 5 as ANSI transparent print
dgcsi_i3:mov	al,':'			; setup for window print
	jmp	dgprt6			; print window
dgcsi_i	endp

dgcsi_sl proc	near			; DG CSI Pc; Pc l  reset mode
	mov	modeset,0		; say resetting modes
	cmp	lparam,'<'		; this letter parameter?
	jne	dgcsi_sl1		; ne = no
	mov	di,offset dgcsi_rsm	; set/reset routine
	call	atreps			; repeat for all parameters
dgcsi_sl1:
	ret
dgcsi_sl endp

; Worker for set/reset routines. Invoke via atreps with modeset for set/reset
dgcsi_rsm proc	near
	mov	ax,param[si]		; get parameter
	mov	ah,modeset		; get set (1), reset (0) mode
	cmp	al,0			; roll mode?
	jne	dgcsi_rsm1		; ne = no
	mov	dgroll,ah		; roll mode
	ret
dgcsi_rsm1:cmp	al,1			; blink mode
	jne	dgcsi_rsm2		; ne = no
	neg	ah			; invert sense
	mov	blinkdis,ah		; blink disable
	ret
dgcsi_rsm2:cmp	al,2			; horizontal scroll?
	jne	dgcsi_rsm3		; ne = no
	neg	ah			; invert sense
	mov	dghscrdis,ah		; horizontal scroll disable
	ret
dgcsi_rsm3:cmp	al,3			; DG D470 ANSI mode?
	jne	dgcsi_rsm4		; ne = no
	mov	dgd470mode,ah		; set ANSI mode
	ret
dgcsi_rsm4:cmp	al,4			; forms mode?
	jne	dgcsi_rsm5		; ne = no
	ret
dgcsi_rsm5:cmp	al,5			; margins mode?
	jne	dgcsi_rsm6
	ret
dgcsi_rsm6:ret
dgcsi_rsm endp

dgcsi_n	proc	near			; DC CSI Pc n  device status report
	cmp	param,5			; send ready report?
	jne	dgcsi_n1		; ne = no
	mov	al,ESCAPE		; response is Esc [ 0 n
	call	prtbout			; meaning "ready"
	mov	al,'['
	call	prtbout
	mov	al,'0'
	call	prtbout
	mov	al,'n'
	call	prtbout
	ret
dgcsi_n1:cmp	param,6			; cursor position report?
	jne	dgcsi_n2		; ne = no
	mov	al,ESCAPE		; response is ESC [ row; col R
	call	prtbout
	mov	al,'['
	call	prtbout
	mov	al,byte ptr cursor+1	; get current row
	call	prtnout			; output number as decimal ASCII
	mov	al,';'
	call	prtbout
	mov	al,byte ptr cursor	; column
	call	prtnout
	mov	al,'R'
	call	prtbout
dgcsi_n2:ret
dgcsi_n	endp

dgcsi_sp proc	near			; DG CSI..p  draw bar or arc
	cmp	inter,' '		; ends on space?
	je	dgcsi_sp1		; e = yes, do draw arc
	mov	bx,offset dggbar	; draw bar
	jmp	dec2getn		; convert params to <loc> form
dgcsi_sp1:mov	bx,offset dggarc	; draw arc
	jmp	dec2getn		; convert params to <loc> form
dgcsi_sp endp

dgcsi_q	proc	near			; DG CSI Pc q  change attributes
	cmp	inter,' '		; read graphics cursor signature?
	je	dgcsi_q1		; e = yes
	mov	bx,offset dgchatr	; change attributes routine
	jmp	dec2getn		; convert args to DG <n> form
dgcsi_q1:				; similar to RS G ? |
ifndef	no_graphics
	call	dgcrossrpt		; do report via MSGIBM
endif	; no_graphics
	ret
dgcsi_q	endp

dgcsi_r	proc	near			; DG CSI <space> r  read cursor att
	mov	al,Escape		; response similar to RS G @
	call	prtbout
	mov	al,'['
	call	prtbout
	mov	al,'0'			; say crosshair is off
	test	dgcross,1		; is it on?
	jz	dgcsi_r1		; z = no
	inc	al			; say '1' for on
dgcsi_r1:call	prtbout			; output <v1>
	mov	al,';'
	call	prtbout
	mov	al,'0'			; <v2> is always 0 for not blinking
	call	prtbout
	mov	al,';'
	call	prtbout
	mov	al,'0'			; <v3> is 0 for short crosshair, D470
	call	prtbout
	mov	al,';'
	call	prtbout
	mov	al,dgcross		; get tracked devices
	and	al,2+4			; pick out just devices
	add	al,'0'			; bias
	call	prtbout			; output <v4>
	mov	al,'r'			; terminal character
	call	prtbout
	ret
dgcsi_r	endp

dgcsi_ss proc	near			; DG CSI Pc s read/reserve characters
	mov	ax,param		; get parameter
	or	ax,ax			; do report?
	jnz	dgcsi_ss2		; nz = no, reserve (do nothing here)
	mov	al,ESCAPE		; report is ESC [ <qty> s
	call	prtbout
	mov	al,'['
	call	prtbout
	mov	al,'2'			; say <qty> is 2000
	call	prtbout
	mov	cx,3
dgcsi_ss1:push	cx
	mov	al,'0'
	call	prtbout
	pop	cx
	loop	dgcsi_ss1
	mov	al,'s'			; terminator
	call	prtbout
dgcsi_ss2:ret
dgcsi_ss endp

dgcsi_st proc	near			; DG CSI Pc t  read offset/show cols
	cmp	inter,' '		; Write graphics cursor command?
	je	dgcsi_st3		; e = yes
	cmp	param,0			; read offset?
	jne	dgcsi_st1		; ne = no
	mov	al,ESCAPE		; response is Esc [ col t
	call	prtbout
	mov	al,'['
	call	prtbout
	mov	bl,dh			; get current row
	xor	bh,bh
	mov	al,linescroll[bx]	; get scroll value
	call	prtnout			; output number as decimal ASCII
	mov	al,'t'
	call	prtbout
	ret
dgcsi_st1:cmp	param,1			; show columns?
	jne	dgcsi_st2		; ne = no
	mov	ax,param+2		; remove initial param
	mov	param,ax
	mov	ax,param+4
	mov	param+2,ax
	mov	nparam,2		; setup for call
	mov	bx,offset dgshcol	; show columns, RS F _
	jmp	dec2getn		; perform the routine
dgcsi_st2:ret

dgcsi_st3:mov	ax,param		; x graphics coord
	mov	bx,param+2		; y graphics coord
ifndef	no_graphics
	call	dgsetcrloc		; set crosshairs to x,y
endif	; no_graphics
	ret
dgcsi_st endp

dgcsi_u	proc	near			; DG CSI Pc <space> u
	cmp	inter,' '		; ends on space
	je	dgcsi_u1		; e = yes, cursor off
	mov	inter,0
	mov	ninter,0		; best to clear these
	jmp	dgcsi_f			; it's cursor row, col
dgcsi_u1:jmp	dggcoff			; do RS G C  graphics cursor off
dgcsi_u	endp

dgcsi_v	proc	near			; DG CSI <space> v cursor on
	cmp	inter,' '		; proper form?
	jne	dgcsi_v1		; ne = no
	jmp	dggcon			; do RS G B  graphics cursor on
dgcsi_v1:ret
dgcsi_v	endp

dgcsi_w	proc	near			; DG CSI Pn; Pc w  set margins
	cmp	inter,' '		; graphics cursor reset indicator?
	jne	dgcsi_w4		; ne = no, must be margins
ifndef	no_graphics
	call	dgcrossoff		; turn off crosshair
endif	; no_graphics
	mov	dgcross,0		; and no kind of tracking
	ret
dgcsi_w4:mov	bx,param		; set margins
	mov	ax,param+2
	mov	param,ax
	mov	ax,param+4
	mov	param+2,ax		; remove leading param
	mov	ax,param+6
	mov	param+4,ax
	dec	nparam			; one less parameter
	cmp	bx,1			; set margins?
	je	dgcsi_w1		; e = 1 = yes, do draw arc
	ja	dgcsi_w2		; a = 2 = set alt margins
	jmp	dgrnmar			; 0 = restore normal margins
dgcsi_w1:mov	bx,offset dgsetmar	; set margins
	jmp	dec2getn		; convert params to <nn> form
dgcsi_w2:mov	bx,offset dgsetamar	; set alt margins
	jmp	dec2getn		; convert params to <nn> form
dgcsi_w endp

dgcsi_x	proc	near			; DG CSI Pc x   cursor track
	cmp	inter,' '		; proper form for cursor track?
	jne	dgcsi_x1		; ne = no
	mov	ax,param		; get arg
	and	al,2+4			; pick out our trackables
	and	dgcross,not (2+4)	; preserve on/of bit (1)
	or	dgcross,al		; track keypad (2) and/or mouse (4)
dgcsi_x1:				; like RS C  DG Read Model ID
	mov	al,escape		; resp ESC [ <mm> <x> <y>
	call	prtbout
	mov	al,'['
	call	prtbout
	mov	al,'5'			; 5 is DG D470 in ANSI mode
	call	prtbout
	mov	al,'4'			; 4 is DG D470
	call	prtbout
	mov	al,';'
	call	prtbout
	mov	al,'0'			; two bytes here
	call	prtbout
	mov	al,'0'
	test	flags.remflg,d8bit	; using 8 bits?
	jz	dgcsi_x2		; z = no
	or	al,2			; say 8-bit mode
dgcsi_x2:push	ax
	mov	ah,ioctl		; get printer status, via DOS
	mov	al,7			; status for output
	push	bx
	mov	bx,4			; std handle for system printer
	int	dos
	pop	bx
	jnc	dgcsi_x3		; nc = call succeeded
	mov	al,0ffh
dgcsi_x3:cmp	al,0ffh			; code for Ready
	pop	ax
	jne	dgcsi_x4		; ne = not ready
	or	al,1			; say printer present
dgcsi_x4:call	prtbout			; send composite byte
	mov	al,';'
	call	prtbout
	mov	al,'0'			; revision 0
	call	prtbout
	mov	al,';'
	call	prtbout
	mov	bl,vtemu.vtchset	; get Kermit NRC code (0-13)
	xor	bh,bh
	mov	al,nrcdgkbd[bx]		; get DG keyboard code from table
	call	prtnout
	mov	al,'x'
	call	prtbout
	ret
dgcsi_x	endp

dgdcs_F	proc	near			; DC DCS F ST  failure report
	mov	al,Escape		; report DCS F ST for no failure
	call	prtbout
	mov	al,'P'
	call	prtbout
	mov	al,'F'
	call	prtbout
	mov	al,Escape
	call	prtbout
	mov	al,'\'
	call	prtbout
	jmp	atnorm
dgdcs_F	endp

		; End of Data General specific routines

		; Start Wyse-50 specific routines

wyenq	proc	near			; Control E, ESC sp  inquire
	mov	al,'5'
	call	prtbout			; send 5 0 CR
	mov	al,'0'
	call	prtbout
	mov	al,CR
	call	prtbout
	ret
wyenq	endp

wycub	proc	near			; Control H  cursor left (back)
	sub	dl,1			; column, one to the left
	jns	wycub1			; ns = no wrap
	mov	dl,mar_right		; wrap left to right
	sub	dh,1			; up one row
	jns	wycub1			; ns = no wrap
	mov	dh,mar_bot		; wrap top to bottom
wycub1:	jmp	atsetcur		; set cursor
wycub	endp

wycup	proc	near			; Control K (VT) cursor up
	mov	dx,cursor
	sub	dh,1			; compute new cursor position
	jnc	wycu1			; nc = ok
	mov	dh,mar_bot		; overflow, wrap to last line
wycu1:	jmp	atscur			; set the cursor at its new position
wycup	endp

wysub	proc	near			; Control Z  erase all unprotected
					; also ESC ; and ESC :
	mov	dl,mar_left		; upper left corner
	mov	dh,mar_top
	call	erprot			; do protected erasure
	jmp	short wyhome		; home the cursor
wysub	endp

wyhome	proc	near			; Control ^  cursor home
	mov	dl,mar_left		; upper left corner
	mov	dh,mar_top
	jmp	atscur			; set cursor
wyhome	endp

wyprtoff proc	near			; Autoprint off
	test	anspflg,vtautop		; check state of print flag
	jz	wyprtof1		; z = off already
	or	anspflg,vtautop		; say auto-print enabled to toggle off
	call	ftrnprs			; toggle mode line PRN indicator
	and	anspflg,not (vtautop + vtcntp) ; clear all printing kinds
wyprtof1:ret
wyprtoff endp

wyprton	proc	near			; Autoprint on
	test	anspflg,vtautop		; is print already enabled?
	jnz	wyprton1		; nz = yes, leave trnprs intact
	and	anspflg,not vtautop	; say auto-print disabled to toggle on
	call	ftrnprs			; toggle on mode line PRN indicator
wyprton1:ret
wyprton	endp

wyesc	proc	near			; ESC processor, enter when ESC seen
	mov	ttstate,offset wyesc1	; come here for next char
	ret
wyesc1:	mov	param,0
	mov	param+2,0
	mov	lparam,0
	mov	bx,offset wyescf	; dispatch table
	mov	ttstate,offset atnrm	; reset state
	jmp	atdispat		; dispatch on char in AL
wyesc	endp

wytab0	proc	near			; ESC 0
	mov	param,3			; clear all tab stops
	jmp	attbc			; do it
wytab0	endp

wytab2	proc	near			; ESC 2
	mov	param,0			; clear this tab stop
	jmp	attbc			; do it
wytab2	endp

wy_bang	proc	near			; ESC ! attrib, set attribute on all
	mov	ttstate,offset wy_ban1	;  unprotected chars, clear chars
	mov	emubuf,0		; say ESC ! rather than ESC A 0
	ret
wy_ban1:xor	dx,dx			; home position
	mov	ttstate,offset atnrm	; reset state
	mov	bl,al			; save argument
	mov	ah,scbattr		; normal background
	mov	curattr,ah		; current attributes, update
	mov	extattr,0		; clear extended attributes
	test	bl,2			; set blink?
	jz	wy_ban2			; z = no
	test	bl,1			; and blank?
	jnz	wy_ban2			; nz = yes, ignore blink
	call	setblink
wy_ban2:test	bl,4			; set reverse video bit?
	jz	wy_ban3			; z = no
	call	setrev
wy_ban3:test	bl,8			; set underscore?
	jz	wy_ban4			; z = no
	call	setunder
wy_ban4:test	bl,40h			; dim?
	jz	wy_ban5			; z = no
	call	setbold
wy_ban5:mov	curattr,ah		; new attributes
	mov	extattr,cl
	mov	al,mar_right
	sub	al,mar_left
	inc	al			; width
	mov	cl,mar_bot
	sub	cl,mar_top
	inc	cl			; rows
	mul	cl
	mov	cx,ax			; number of character cells to do
	xor	dx,dx			; home position
wy_ban6:push	cx			; save loop counter
	call	getatch			; get video in ah, extended att in cl
	test	cl,att_protect		; protected?
	jnz	wy_ban7			; nz = yes, skip it
	mov	cl,extattr
	mov	ah,curattr
	cmp	emubuf,0		; erase char?
	jne	wy_ban6a		; ne = no
	mov	al,' '			; cleared character
wy_ban6a:call	qsetatch		; quietly update the char
wy_ban7:pop	cx
	inc	dl			; next column
	cmp	dl,mar_right		; at the right margin?
	jbe	wy_ban8			; be = no, not yet
	mov	dl,mar_left		; wrap to left and next line
	inc	dh			; next line down
	cmp	dh,mar_bot		; below the window bottom?
	ja	wy_ban9			; a = yes, all done
wy_ban8:loop	wy_ban6			; do more chars
wy_ban9:call	frepaint		; repaint screen
	xor	dx,dx			; home cursor
	cmp	emubuf,0		; erase char?
	je	wy_ban10		; e = yes
	mov	dx,cursor		; else replace cursor
wy_ban10:jmp	atsetcur		; restore cursor
wy_bang	endp

wy_dot	proc	near			; ESC . CODE   clr unprotected chars
	mov	ttstate,offset wy_dot1	;  of value code
	ret
wy_dot1:mov	ttstate,offset atnrm	; reset state
	mov	emubuf,al		; save char code
	mov	al,mar_right
	sub	al,mar_left
	inc	al			; width
	mov	cl,mar_bot
	sub	cl,mar_top
	inc	cl			; rows
	mul	cl
	mov	cx,ax			; number of character cells to do
wy_dot2:push	cx			; save loop counter
	call	getatch			; get video in ah, extended att in cl
	test	cl,att_protect		; protected?
	jnz	wy_dot3			; nz = yes, skip it
	cmp	al,emubuf		; same as code?
	jne	wy_dot3			; ne = no
	mov	al,' '			; char
	mov	ah,scbattr		; normal background
	xor	cl,cl			; clear extended attributes
	call	qsetatch		; quietly update the char
wy_dot3:pop	cx
	inc	dl			; next column
	cmp	dl,mar_right		; at the right margin?
	jbe	wy_dot4			; be = no, not yet
	mov	dl,mar_left		; wrap to left and next line
	inc	dh			; next line down
	cmp	dh,mar_bot		; below the window bottom?
	ja	wy_dot5			; a = yes, all done
wy_dot4:loop	wy_dot2			; do more chars
wy_dot5:call	frepaint		; repaint screen
	mov	dx,cursor		; reset cursor location
	ret
wy_dot	endp

wy_8	proc	near			; ESC 8 enter STX (2) code
	mov	al,2
	jmp	atnrm
wy_8	endp

wy_9	proc	near			; ESC 9 enter ETX (3) code
	mov	al,3
	jmp	atnrm
wy_9	endp

wy_slash proc	near			; ESC /  send txt seg and cursor
	mov	al,'0'			; text segment 0
	call	prtbout			; send
	jmp	wy_query		; send cursor position
wy_slash endp

wy_query proc	near			; ESC ?  send rc CR cursor report
	mov	al,byte ptr cursor+1	; row
	add	al,20h			; plus bias
	call	prtbout
	mov	al,byte ptr cursor	; column
	add	al,20h
	call	prtbout
	mov	al,CR			; terminator
	call	prtbout
	ret
wy_query endp

wy_sa	proc	near			; ESC a rr R ccc C  cursor to row,col
	mov	ttstate,offset wy_sa1	; get first row char
	ret
wy_sa1:	cmp	al,'R'			; field termination?
	je	wy_sa2			; yes
	push	ax
	mov	ax,param		; ASCII decimal to binary
	mov	cx,10
	imul	cx
	mov	param,ax
	pop	ax
	sub	al,'0'			; ccc, decimal col
	cbw
	add	param,ax
	ret				; stay in this state
wy_sa2:	mov	lparam,al		; save it
	mov	ttstate,offset wy_sa3	; get column
	ret
wy_sa3:	cmp	al,'C'			; field termination?
	je	wy_sa4			; e = yes
	push	ax
	mov	ax,param+2		; ASCII decimal to binary
	mov	cx,10
	imul	cx
	mov	param+2,ax
	pop	ax
	sub	al,'0'			; ccc, decimal col
	cbw
	add	param+2,ax
 	ret				; stay in this state
wy_sa4:	mov	ttstate,offset atnrm
	xor	ah,ah
	xchg	ah,lparam		; get the 'R', clear lparam
	cmp	ax,'RC'			; proper terminators?
	jne	wy_sax			; ne = no
	xor	ax,ax
	xor	bx,bx
	xchg	ax,param		; row
	xchg	bx,param+2		; column
	or	ax,ax			; zero now?
	jz	wy_sa5			; z = yes
	dec	ax			; count row from zero
wy_sa5:	or	bx,bx			; zero now?
	jz	wy_sa6			; z = yes
	dec	bx			; count column from zero
wy_sa6:	cmp	ax,24			; row, in bounds?
	ja	wy_sax			; a = no
	cmp	bx,132			; column, in bounds?
	ja	wy_sax			; a = no
	mov	dh,al			; row
	mov	dl,bl			; column
	jmp	atscur			; set cursor
wy_sax:	mov	param,0
	mov	param+2,0		; clear temps
	ret				; ignore command
wy_sa	endp

wy_equ	proc	near			; ESC = r c  cursor to row, col
	mov	ttstate,offset wy_equ1	; get row char
	ret
wy_equ1:sub	al,' '-1		; remove ASCII bias
	cbw				; grab sign
	mov	param,ax		; save as row
	mov	ttstate,offset wy_equ2
	ret
wy_equ2:sub	al,' '-1		; remove ASCII bias
	cbw
	mov	param+2,ax		; save as column
	mov	lparam,'R'		; setup R..C form
	mov	al,'C'
	jmp	wy_sa4			; parse completion as ESC a rr R ccc C
wy_equ	endp

wy_minus proc	near			; ESC - nrc  cursor to txt seg row col
	and	al,1			; n can be anything (despite manual)
	mov	ttstate,offset wy_equ	; parse rest as if ESC = r c
	ret
wy_minus endp

wy_star	proc	near			; ESC *   ESC + 
					; protect mode off, clear screen
	mov	protectena,0		; disable protect mode
	xor	dx,dx			; set cursor to home
	mov	cursor,dx
	jmp	ereos			; clear entire screen
wy_star	endp

wy_comma proc	near			; ESC ,  screen clear to prot'd spaces
	mov	protectena,0		; disable protect mode
	xor	dx,dx			; set cursor to home
	mov	cursor,dx
	mov	ah,scbattr		; normal background
	mov	al,' '			; space
	mov	cl,att_protect		; set protection bit
wy_comm1:call	setatch			; write cell
	inc	dl			; next column
	cmp	dl,mar_right		; beyond right edge?
	jbe	wy_comm1		; be = no
	xor	dl,dl			; left edge
	inc	dh			; next row
	cmp	dh,mar_bot		; below bottom?
	jbe	wy_comm1		; be = no
	xor	dx,dx			; top left corner
	jmp	atsetcur		; set cursor
wy_comma endp

wy_A	proc	near			; ESC A n attrib  set video attribs
	mov	ttstate,offset wy_A1	; get field code n
	ret
wy_A1:	cmp	al,'0'			; entire text display?
	jne	wy_A2			; ne = no, ignore after getting attrib
	mov	emubuf,1		; flag to wy_bang to not erase chars
	mov	ttstate,offset wy_ban1	; process attrib in ESC ! procedure
	ret
wy_A2:	mov	ttstate,offset atnorm	; ignore next byte, exit command
	ret
wy_A	endp

wy_F	proc	near			; ESC F text CR, to message area
	mov	ttstate,offset wy_F1
	ret
wy_F1:	cmp	al,CR			; end of string?
	jne	wy_F2			; ne = no, continue discarding bytes
	mov	ttstate,offset atnrm	; reset state
wy_F2:	ret
wy_F	endp

wy_G	proc	near			; ESC G n  set char attributes
	mov	ttstate,offset wy_G1	; get attribute code
	ret
wy_G1:	mov	ttstate,offset atnrm	; reset state
	mov	ah,curattr		; current attributes
	mov	bl,al			; get code
	cmp	bl,' '			; space code?
	je	wy_Gx			; e = yes, just ignore it
	cmp	bl,'0'			; range check for '0' et seq
	jb	wy_Gx			; b = out of range
	ja	wy_G2			; a = in range
	call	clrbold			; clear bold attribute
	call	clrblink		; clear blink attribute
	call	clrrev			; clear reverse video attribute
	call	clrunder		; clear underline attribute
	mov	atinvisible,0		; clear invisible attribute
	mov	extattr,0		; clear extended attributes
	jmp	short wy_Gx

wy_G2:	test	bl,2			; set blink?
	jz	wy_G3			; z = no
	test	bl,1			; and blank?
	jnz	wy_G3			; nz = yes, ignore blink
	push	bx
	call	setblink		; set blink
	pop	bx
wy_G3:	test	bl,4			; set reverse video bit?
	jz	wy_G4			; z = no
	push	bx
	call	setrev			; set reverse video
	pop	bx
wy_G4:	test	bl,8			; set underscore?
	jz	wy_G5			; z = no
	push	bx
	call	setunder		; set underline
	pop	bx
wy_G5:	cmp	bl,'p'			; dim?
	jb	wy_Gx			; b = no
	call	clrbold			; set dim
wy_Gx:	mov	curattr,ah		; store new attribute byte
;;;;;	mov	byte ptr wyse_protattr,ah ; Wyse-50 protected char attributes
;;;;;	mov	byte ptr wyse_protattr+1,att_protect
	mov	dx,cursor		; moves cursor left one column
	inc	dl
	jmp	atscur
wy_G	endp

wy_H	proc	near			; ESC H x  show graphics char
	mov	ttstate,offset wy_H1	; setup to read x
	ret
wy_H1:	mov	ttstate,offset atnrm	; reset state
	cmp	al,2			; STX (^B) enter graphics mode?
	jne	wy_H2			; ne = no
	jmp	atls1			; do LS1 to get graphics set

wy_H2:	cmp	al,3			; ETX (^C) exit graphics mode?
	jne	wy_H3			; ne = no
	jmp	atls0			; do LS0 to exit graphics mode

wy_H3:	mov	SSptr,offset G1set	; set Single Shift to G1 for graphics
	jmp	atnrm			; show code
wy_Hx:	ret
wy_H	endp

wy_I	proc	near			; ESC I  cursor back to previous tab
	xor	ch,ch
	cmp	cl,dl			; cursor column
	jcxz	wy_I3			; z = at left margin
wy_I1:	dec	dl			; tab always moves at least one column
	push	si
	mov	si,vtemu.vttbst		; active buffer
	call	istabs			; returns carry set if at a tabstop
	pop	si
	jc	wy_I2			; c = at a tabstop
	loop	wy_i1
wy_I2:	call	dgsetcur		; set cursor and return
wy_I3:	ret
wy_I	endp

wy_N	proc	near			; ESC N  turn on no-scroll mode
	mov	wyse_scroll,1
	ret
wy_N	endp

wy_O	proc	near			; ESC O  turn off no-scroll mode
	mov	wyse_scroll,0
	ret
wy_O	endp

wy_R	proc	near			; ESC R  delete line
	call	dellin
	xor	dl,dl			; cursor to left margin
	jmp	atsetcur		; set cursor
wy_R	endp

wy_V	proc	near			; ESC V  mark column as protected
	push	cursor			; remember starting cursor
	mov	dh,mar_top		; start with this row
	mov	cl,mar_bot
	sub	cl,mar_top
	inc	cl
	xor	ch,ch			; count of rows to touch
	call	direction		; set column in dl
wy_V1:	push	cx
	call	getatch			; get char to al, attrib to ah,cl
	or	cl,att_protect		; set protected attribute
	call	qsetatch		; quite writeback
	pop	cx
	inc	dh			; next row
	loop	wy_V1
	pop	cursor
	mov	dx,cursor
	jmp	atsetcur		; set cursor, just in case
wy_V	endp

wy_acc	proc	near			; ESC ` n  set screen features
	mov	ttstate,offset wy_acc1	; setup to read "n"
	ret
wy_acc1:mov	ttstate,offset atnrm	; reset state
	cmp	al,'0'			; 0, cursor off?
	jne	wy_acc2			; ne = no
	mov	al,4			; set cursor off code
	jmp	wy_acc7
wy_acc2:cmp	al,'1'			; 1, cursor on?
	jne	wy_acc3			; ne = no
	mov	al,atctype		; get cursor type
	jmp	wy_acc7
	ret
wy_acc3:cmp	al,'2'			; 2, block cursor?
	je	wy_acc4			; e = yes
	cmp	al,'5'			; blinking block?
	jne	wy_acc5			; ne = no
wy_acc4:mov	al,2			; block cursor code
	jmp	wy_acc7
wy_acc5:cmp	al,'3'			; 3, blinking line?
	je	wy_acc6			; e = yes
	cmp	al,'4'			; 4, steady line?
	jne	wy_acc8			; ne = no
wy_acc6:mov	al,1			; line code
wy_acc7:call	atsctyp			; set cursor type, remember it
	ret

wy_acc8:cmp	al,'A'			; normal protected char?
	jne	wy_acc9			; ne = no
	mov	cl,extattr		; running extended attribute
	push	cx
	mov	ah,curattr		; current attribute
	call	getblink		; save blinking attribute
	mov	al,ah			;  to al
	mov	ah,scbattr		; normal attribute
	or	ah,al			;  include blinking
	or	cl,att_protect		; set protected extended attrib
	and	cl,not att_uline+att_rev
	mov	extattr,cl
	call	setbold			; set bold
	mov	byte ptr wyse_protattr,ah ; store attribute to write
	mov	byte ptr wyse_protattr+1,cl
	call	wy_setp			; set attributes on protected chars
	pop	cx
	mov	extattr,cl		; restore extended attribute
	ret

wy_acc9:cmp	al,'6'			; reverse protected char?
	jne	wy_acc10		; ne = no
	mov	cl,extattr		; running extended attribute
	push	cx
	mov	ah,curattr		; current attribute
	call	getblink		; save blinking attribute
	mov	al,ah			;  to al
	mov	ah,scbattr		; normal attribute
	or	ah,al			;  include blinking
	or	cl,att_protect		; set protected extended attrib
	and	cl,not att_uline+att_rev
	mov	extattr,cl
	call	clrbold			; clear bold (set dim)
	call	setrev			; set reverse
	mov	byte ptr wyse_protattr,ah ; store attribute to write
	mov	byte ptr wyse_protattr+1,cl
	call	wy_setp			; set attributes on protected chars
	pop	cx
	mov	extattr,cl		; restore extended attribute
	ret

wy_acc10:cmp	al,'7'			; dim protected char?
	jne	wy_acc11		; ne = no
	mov	cl,extattr		; running extended attribute
	push	cx
	mov	ah,curattr		; current attribute
	call	getblink		; save blinking attribute
	mov	al,ah			;  to al
	mov	ah,scbattr		; normal attribute
	or	ah,al			;  include blinking
	or	cl,att_protect		; set protected extended attrib
	and	cl,not att_uline+att_rev
	mov	extattr,cl
	call	clrbold			; set dim
	mov	byte ptr wyse_protattr,ah ; store attribute to write
	mov	byte ptr wyse_protattr+1,cl
	call	wy_setp			; set attributes on protected chars
	pop	cx
	mov	extattr,cl		; restore extended attribute
	ret

wy_acc11:cmp	al,':'			; set 80 columns?
	jne	wy_acc12
	mov	al,3			; arg for columns set/reset
	mov	modeset,0		; reset condition
	jmp	atrsm6

wy_acc12:cmp	al,';'			; set 132 columns?
	jne	wy_acc14		; ne = no
	mov	al,3			; arg for columns
	mov	modeset,1		; set condition
	jmp	atrsm6			; do set/reset operation
wy_acc14:ret
wy_acc	endp

; worker for wy_acc. Set attributes of all protected characters. New
; attributes are in word wyse_protattr.
wy_setp	proc	near			; set protected char attributes
	push	cursor			; remember starting cursor
	mov	dh,mar_top		; start with this row
	mov	cl,mar_bot
	sub	cl,mar_top
	inc	cl
	xor	ch,ch			; count of rows to touch
	xor	dl,dl			; left physical column
wy_setp1:push	cx
	call	getatch			; get char to al, attrib to ah,cl
	test	cl,ATT_PROTECT		; protected?
	jz	wy_setp2		; z = no, do nothing
	mov	ah,byte ptr wyse_protattr ; "normal" attributes
	mov	cl,byte ptr wyse_protattr+1 ; extended, set protected
	call	setatch			; visible writeback
wy_setp2:pop	cx
	inc	dl
	cmp	dl,mar_right		; at right margin?
	jb	wy_setp1		; b = no, more on this row
	xor	dl,dl			; left column
	inc	dh			; next row
	loop	wy_setp1
	pop	cursor
	mov	dx,cursor
	jmp	atsetcur		; set cursor, just in case
wy_setp	endp


wy_M	proc	near			; ESC M  send to host char at cursor
	call	getatch			; get char to al
	call	prtbout			; send, no echo
	ret
wy_M	endp

wy_b	proc	near			; ESC b send cursor address to host
	mov	al,'0'			; three digits
	call	prtbout
	mov	al,byte ptr cursor+1	; get row
	inc	al			; count from 1
	cmp	al,10
	jae	wy_b1			; ae = have two digits
	push	ax
	mov	al,'0'			; second leadin
	call	prtbout
	pop	ax
wy_b1:	call	prtnout			; decimal ASCII
	mov	al,'R'			; report rr R ccc C
	call	prtbout
	mov	al,byte ptr cursor	; column
	inc	al			; count from 1
	cmp	al,100			; three digits again
	jae	wy_b2
	push	ax
	mov	al,'0'
	call	prtbout
	pop	ax
	cmp	al,10
	jae	wy_b2
	push	ax
	mov	al,'0'
	call	prtbout
	pop	ax
wy_b2:	call	prtnout
	mov	al,'C'			; terminator
	call	prtbout
	ret
wy_b	endp

wy_d	proc	near			; ESC d #, transparent print on
	mov	ttstate,offset wy_d1	; get sharp sign
	ret
wy_d1:	cmp	al,'#'			; proper terminator?
	je	wy_d2			; e = yes
	jmp	atnorm			; reset state

wy_d2:	mov	ttstate,offset wy_d3	; do transparent printing (Control-X)
	and	anspflg,not vtautop	; clear single-char flag for toggling
	call	ftrnprs			; toggle mode line PRN indicator
	jc	wy_d2a			; c = printer failure
	or	anspflg,vtcntp		; controller printing is on
wy_d2a:	ret

wy_d3:	cmp	al,'T'-40h		; Control-T to end printing?
	je	wy_d4			; e = yes
	call	fpntchr			; print char in al, ignore errors
	ret

wy_d4:	mov	ttstate,offset atnrm	; return to normal state
	call	fpntflsh		; flush printer buffer
	test	anspflg,vtcntp		; was printing active?
	jz	wy_d5			; z = no
	and	anspflg,not vtcntp	; yes, disable print controller
	call	ftrnprs			; toggle mode line PRN indicator
	and	anspflg,not (vtautop + vtcntp) ; clear all printing kinds
wy_d5:	ret
wy_d	endp

wy_q	proc	near			; ESC q   turn on insert mode
	mov	insmod,1
	ret
wy_q	endp

wy_sr	proc	near			; ESC r  turn off insert mode
	mov	insmod,0
	ret
wy_sr	endp

wy_x	proc	near			; ESC x n HSR  change display format
	mov	ttstate,offset wy_x1	; get argument n (0, 1)
	ret
wy_x1:	cmp	al,'1'			; 1, split screen?
	jne	wy_x2			; ne = no
	mov	ttstate,offset wy_x2	; get HSR screen split code
	ret
wy_x2:	
	mov	ttstate,offset atnrm	; reset state
	ret
wy_x	endp

wy_z	proc	near			; ESC z n aaaa CR  set msg to place
	mov	ttstate,offset wy_z1	; get argument n
	ret
wy_z1:	cmp	al,CR			; terminator?
	je	wy_z2			; e = yes
	cmp	al,DEL			; or shift terminator?
	je	wy_z2			; e = yes
	ret				; continue to consume bytes
wy_z2:	jmp	atnorm			; reset state, return
wy_z	endp

	; Wyse-50 end

; Display "LEDs" routine. yflags from MSYIBM is needed to know if the mode
; line is enabled. Display current state of "LEDs" on line 25.
ansdsl	proc	near			; display "LEDs"
	test	yflags,modoff		; mode line off?
	jnz	ansdsl2			; nz = yes, just return
	cmp	flags.modflg,1		; mode line on and owned by us?
	jne	ansdsl2			; ne = no, leave it intact
	mov	cx,10			; length of the array
	call	getled			; set si to string, c set if no leds
	push	es
	mov	di,ds
	mov	es,di
	mov	di,led_col+offset modbuf ; mode line buffer, our position
	cld
	rep	movsb
	pop	es
ansdsl2:ret
ansdsl	endp

; Return pointer to "led" display in si, set carry if terminal type does
; not have leds 1..4.
getled	proc	near
	mov	ax,flags.vtflg		; terminal type
	mov	si,offset v320leds	; VT320 ident
	cmp	ax,ttvt320		; VT320?
	je	getled2			; e = yes
	mov	si,offset v220leds	; VT220 ident
	cmp	ax,ttvt220		; VT220?
	je	getled2			; e = yes
	mov	si,offset v102leds	; VT102 ident
	cmp	ax,ttvt102		; VT102 mode?
	je	getled2			; e = yes
	mov	si,offset v100leds
	cmp	ax,ttvt100		; VT100?
	je	getled2			; e = yes
	mov	si,offset honeyleds
	cmp	ax,tthoney		; Honeywell?
	je	getled2			; e = yes
	mov	si,offset ansileds
	cmp	ax,ttansi		; ANSI-BBS?
	je	getled2			; e = yes
	mov	si,offset v52leds	; VT52 ident
	cmp	ax,ttvt52		; VT52?
	je	getled1			; e = yes, no leds
	mov	si,offset pt20leds
	cmp	ax,ttpt200		; Prime PT200?
	je	getled2			; e = yes
	mov	si,offset d217leds
	cmp	ax,ttd217		; DG D217?
	je	getled1			; e = yes, but no led dots
	mov	si,offset d463leds
	cmp	ax,ttd463		; DG D463?
	je	getled1			; e = yes, but no led dots
	mov	si,offset d470leds
	cmp	ax,ttd470		; DG D470?
	je	getled1			; e = yes, but no led dots
	mov	si,offset wyseleds
	cmp	ax,ttwyse		; Wyse-50?
	je	getled1			; e = yes
	mov	si,offset h19leds	; Heath-19 ident
getled1:stc				; c = set, does not have leds 1..4
	ret
getled2:clc				; c = clear, has leds 1..4
	ret
getled	endp

; This routine is called to adjust the cursor for the "indexing" like commands
; (e.g., index, reverse index, newline, etc.).	It contrains the cursor, and
; indicates if scrolling is necessary, and if so, in which direction.
;
; Call: cursor = "old" cursor position
;	dx =	 "new" cursor position
;
; Return: ax = pointer to scrolling routine to call (or to a ret)
;	  bx = "old" cursor position
;	  dx = "new" cursor position adjusted for screen limits or
;	       	scrolling region, depending on whether the original
;	       	cursor position was inside or outside the scrolling region.
;
; On the VT100, a scroll does not occur unless the original cursor position
; was on the top or bottom margin. This routine assumes that when decom is
; set the cursor position is set to the new origin, and that no other routine
; allows the cursor to be positioned outside the scrolling region as long
; as decom is set (which is the way a real VT100 works).  Note that for the
; normal case (no limited scrolling region defined) the margins are the same
; as the screen limits and scrolling occurs (as on a "normal" terminal) when
; an attempt is made to index off the screen. Preserves cx.

atccic	proc	near
	push	cx
	mov	cl,byte ptr low_rgt	; get right margin
	mov	bl,dh			; get row
	xor	bh,bh
	cmp	bl,crt_lins		; below screen?
	jae	atcci0			; ae = yes, use single width line
	cmp	linetype[bx],0		; single width chars?
	je	atcci0			; e = yes, single width
	shr	cl,1			; halve margin for double wides
atcci0:	mov	ax,offset atign		; assume no scrolling necessary
	mov	bx,cursor		; get old cursor
	test	flags.vtflg,ttd463+ttd470+ttd217 ; DG terminal?
	jz	atcci0a			; z = no
	mov	cl,mar_right
	cmp	dl,mar_left		; left of left margin?
	jae	atcci1			; ae = no
	mov	dl,mar_right		; fold to right
	dec	dh			; and go up
	jmp	short atcci1
atcci0a:cmp	dl,250			; left of left margin? (wide screen)
	jb	atcci1			; b = no, go check right
	xor	dl,dl			; set to left margin
atcci1:	cmp	dl,cl			; left of right margin
	jbe	atcci2			; be = yes, go check top
	mov	dl,cl			; set to right margin
	test	flags.vtflg,ttd463+ttd470+ttd217 ; DG terminal?
	jz	atcci2			; z = no
	mov	dl,mar_left		; to left margin
	inc	dh			; and down one
atcci2:	pop	cx
	cmp	bh,mar_top		; was old pos above scroll top margin?
	jb	atcci7			; b = yes
	cmp	dh,mar_top		; want to go above top margin?
	jge	atcci5			; ge = no
	test	flags.vtflg,ttd463+ttd470+ttd217 ; DG D463/D470/D217?
	jz	atcci3			; z = no
	mov	dh,mar_bot		; roll over to bottom margin
	ret
atcci3:	mov	scroll,1
	mov	ax,offset atscrd	; indicate scroll down required
	mov	dh,mar_top		; set to top margin
	ret

atcci5:	cmp	bh,mar_bot		; old position below bottom margin?
	ja	atcci7			; a = yes
	cmp	dh,mar_bot		; want to go below?
	jbe	atcci6			; be = no, nothing to worry about
	mov	scroll,1		; 1 line
	mov	ax,offset atscru	; indicate scroll up required
	mov	dh,mar_bot		; set to bottom margin
atcci6:	ret
atcci7:	jmp	short atccpc		; old pos was outside scrolling region
atccic	endp

; This routine is called to check the cursor position after any kind of cursor
; positioning command.	Note that cursor positioning does NOT cause scrolling
; on a VT100 (hence the need for a routine separate from this for "indexing".
; Call:	dx = "new" cursor position (modified cursor)
; Return: dx = "new" cursor position adjusted for screen limits (if
;		decom is reset), or scrolling region (if decom is set).
; Preserves ax, bx, and cx.

atccpc	proc	near
	push	bx			; save bx and cx
	push	cx
	mov	cx,low_rgt		; margins, cl = right margin
	mov	bl,dh			; get row
	xor	bh,bh
	cmp	linetype [bx],0		; single width line?
	je	atccp0			; e = yes, single width
	shr	cl,1			; halve right margin for double wides
atccp0:	test	flags.vtflg,ttd463+ttd470+ttd217 ; DG D463/D470/D217?
	jz	atccp0a			; z = no
	mov	cl,mar_right
	cmp	dl,mar_left		; left of margin?
	jae	atccp1			; ae = no
	mov	dl,mar_right		; go to right margin
	dec	dh			; do a cursor up
	jmp	short atccp1		; do a cursor up

atccp0a:cmp	dl,250			; to left of left margin?(wide screen)
	jb	atccp1			; b = no, go check right
	xor	dl,dl			; set to left margin
atccp1: cmp	dl,cl			; to right of right margin?
	jbe	atccp2			; be = yes, go check top
	mov	dl,cl			; set to right margin

	test	flags.vtflg,ttd463+ttd470+ttd217 ; DG D463/D470/D217?
	jz	atccp2			; z = no
	mov	dl,mar_left		; to left margin
	jmp	atlf			; do a LF operation now

atccp2:	pop	cx
	pop	bx
	test	vtemu.vtflgop,decom	; Origin mode set?
	jnz	atccp5			; nz = yes, stay in scrolling region
	or	dh,dh			; above top of screen?
	jns	atccp3			; ns = no, check bottom
	xor	dh,dh			; stop here
atccp3: cmp	dh,byte ptr low_rgt+1	; below bottom of screen?
	jbe	atccp4			; be = no, stay in margins
	mov	dh,byte ptr low_rgt+1	; stop at end of text screen
	cmp	flags.vtflg,ttheath	; Heath-19 mode?
	jne	atccp4			; ne = no
	test	h19stat,h19l25		; 25th line enabled?
	jnz	atccp4			; nz = yes
	inc	dh			; allow 25th line
atccp4:	ret

atccp5: cmp	dh,mar_top		; above top of scrolling region?
	jae	atccp6			; ae = no, check bottom
	mov	dh,mar_top		; yes, stop there
	test	flags.vtflg,ttd463+ttd470+ttd217 ; DG D463/D470/D217?
	jz	atccp6			; z = no
	mov	dh,mar_bot		; roll to bottom
	ret
atccp6: cmp	dh,mar_bot		; below bottom perhaps?
	jbe	atccp4			; be = no, return
	mov	dh,mar_bot		; yes, stop at the bottom margin
	test	flags.vtflg,ttd463+ttd470+ttd217 ; DG D463/D470/D217?
	jz	atccp7			; z = no
	mov	dh,mar_top		; roll to top
atccp7:	ret
atccpc	endp


; Routine to set cursor type (off, block, underline).
; 4 = do not show, but keep block/underline attributes.
; 2 = block, 1 = underline
atsctyp:cmp	flags.vtflg,ttheath	; Heath-19?
	jne	atsct1			; ne = no
	mov	al,h19ctyp		; get cursor kind and on/off bit
	test	al,4			; is cursor to be off?
	jz	atsct4			; z = no, al has kind
	xor	al,al			; turn off cursor
	jmp	short atsct4		; do it
atsct1:	test	atctype,4		; VTxxx cursor type, off?
	jnz	atsct3			; z = no
atsct2:	mov	al,1			; assume underline
	test	vtemu.vtflgop,vscursor	; block?
	jnz	atsct3			; nz = no, underline
	inc	al
atsct3:	mov	atctype,al		; save VTxxx cursor type here
atsct4:	call	csrtype			; set the cursor type
	ret

atdeb	proc	near			; Debug, display all chars in tty style
	test	yflags,capt		; capturing output?
	jz	atdeb3			; z = no, forget this part
	call	fcptchr			; give it captured character
atdeb3:	mov	bl,curattr		; save attribute
	push	bx
	push	word ptr mar_top	; save limited scrolling region
	push	ax			; save character for a second
	mov	ah,curattr		; get attribute
	call	clrblink		; clear blink attribute
	call	clrunder		; clear underline attribute
	mov	atinvisible,0		; clear invisible attribute
	mov	extattr,0		; extended attribute
	mov	curattr,ah		; store
	or	vtemu.vtflgop,decawm	; set autowrap temporarily
	mov	mar_top,0		; set scrolling region to entire page
	mov	al,byte ptr low_rgt+1
	mov	mar_bot,al
	pop	ax			; restore character
	mov	ah,al
	test	al,80h			; high bit set?
	jz	atdeb0			; z = not set
	push	ax			; save the character for a second
	mov	al,7eh			; output a tilde
	call	atnrm2
	pop	ax			; restore character
	and	al,7fh			; and remove high bit
atdeb0:	cmp	al,del			; DEL?
	je	atdeb1			; e = yes, output "^?"
	cmp	al,20h			; control character?
	jnb	atdeb2			; nb = no, just output char in al
atdeb1: push	ax			; save the character for a second
	mov	al,5eh			; output a caret
	call	atnrm2
	pop	ax			; restore character
	add	al,40h			; make ^letter (or ^? for DEL)
	and	al,7fh			; clear bit 7 (for DEL)
atdeb2:	push	ax
	call	atnrm2			; output translated character
	pop	ax
	cmp	ah,LF			; natural line break?
	jne	atdeb4			; ne = no
	call	atcr
	call	atlf
atdeb4:	pop	word ptr mar_top	; restore scrolling region,
	pop	bx			;  flags, and cursor attribute
	mov	curattr,bl
	ret
atdeb	endp
code1	ends
	end
