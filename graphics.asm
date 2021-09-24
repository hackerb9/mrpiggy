 	Name msgibm
; File MSGIBM.ASM
	include mssdef.h
;	Copyright (C) 1982, 1999, Trustees of Columbia University in the 
;	City of New York.  The MS-DOS Kermit software may not be, in whole 
;	or in part, licensed or sold for profit as a software product itself,
;	nor may it be included in or distributed with commercial products
;	or otherwise distributed by commercial concerns to their clients 
;	or customers without written permission of the Office of Kermit 
;	Development and Distribution, Columbia University.  This copyright 
;	notice must not be removed, altered, or obscured.
; Tektronix emulator for use with MS Kermit/IBM.
; Edit history:
; 5 Dec 1996 version 3.15
; Last edit 5 Dec 1996
;==============================================================================
; Original version for TI Pro computers by
; 12-Dec-84  Joe Smith, CSM Computing Center, Golden CO 80401
; adapted to IBM PC June 1987 by	Brian Holley,
;					Faculty of Economics and Politics
;					University of Cambridge, England
;					Email: BJH6@UK.AC.CAM.PHX
; Upgraded and integrated into MS Kermit 2.30 by Joe Doupnik, Utah State Univ.
;
;		   Description of Tektronix commands
;
; ESC CONTROL-E (ENQ) requests a status report
; ESC FORMFEED erases the screen.
; ESC CONTROL-X turns on bypass mode (ignore incoming characters).
; ESC CONTROL-Z turns on the crosshairs (not on 4006 or 4025)
; ESC 2  exit Tek submode for text mode (ignore if doing full Tek)
; ESC ? is replaced by DEL code, to assist line plots with 7 bit systems.
; ESC [ Pn ; Pn m  set screen colors. Pn = 30 + sum of colors for foregnd,
;  40 + sum of colors for background, Pn = 0 sets b/w, Pn = 1 for high
;  intensity. Colors are red = 1, green = 2, blue = 4.
; ESC [ ? 3 8 l  exits Tek mode and returns to host text terminal type
;  (VT102 if none defined yet). This is an extension from DEC VT340's.
; ESC [ ? 256 n  invokes a screen size report, for Word Perfect. Report is
;   ESC [ ? 256; height; width; num colors n   where num colors is 0, 1 or
;   16; report ESC [ ? 24; 80; 0 n  for pure text mono systems.
; ESC @  through  ESC M  sets default fill pattern as below (1=@...).
; ESC Z  report terminal type (as VT320)
; ESC [ 2; 2 $ u  host request color palette report.
; ESC / xhome;yhome;xwidth;yheight x   		draw an empty rectangle
; ESC / xhome;yhome;xwidth;yheight;pattern y   fill rectangle with pattern
; ESC / xhome;yhome;xwidth;yheight;pattern z   fill rect with pattern+border
;  where x/yhome is the lower left Tek corner, xwidth and yheight are the
;  Tek width and height. All values are decimal numbers.
;  Patterns 0:use default, 1:solid, 2:grey, 3:left to right slant, 4:right to
;  left slant, 5:horizontal lines, 6:vertical lines, 7:slanted cross-hatch,
;  8:vertical cross-hatch, 9:checkerboard; 10:dotted, 11:horiz herringbone,
;  12:vertical herringbone,13 and above:border without fill. All are tiling
;  8x8 pixel patterns.
; ESC / param a, ... ESC / param c  set user definable line drawing pattern
;  to 16 bit value of param; plot as lsb first.
; ESC / 2 h or l,  ESC / 9 h or l. h is set, l is reset, 2 is destructive
;  space and 9 is destructive backspace. Defaults are reset.
; ESC x  ESC y  ESC z   selects one of these user definable patterns above.
; ESC P  P1; P2; P3 q string ESC \		a Sixel Graphics command
;   P1 and P3 ignored, P2 = 0 or 2 means draw 0 bits in background, 1 means
;	skip them.
;   string is
;     sixel chars (3fh..7eh, lower 6 bits+3fh, displayed lsb at the top)
;     ! Pn sixel char	    where Pn is a repeat count
;     " Pan; Pad; Ph; Pv    raster attributes (all ignored for now)
;     # Pc; Pu; Px; Py; Pz  coloring as follows
;	Pc is color palette, 0-255  (note, only 0..15 are predefined)
;	Pu is color units, 1=HLS, 2=RGB
;	For Hue Lightness Saturation:
;		Px = Hue angle, 0-360 degrees. The colors are mapped around
;		the color wheel in 60 degree segments as Hues:
;		0-29 deg = blue, 30-89 = magenta (blue + red), 90-149 = red,
;		150-209 = yellow (red + green), 210-269 = green,
;		270-329 = cyan (green + blue), 330-359 = blue.
;		Py = Lightness, 0-100%, Pz = Saturation, 0-100%
;		  Lightness	Sat = 51-100	Sat = 11-50	 Sat = 0-10
;		  86-100	bold white	bold white	 bold white
;		  71-85		bold hue	bold white	 bold white
;		  57-70		bold hue	grey (dim white) grey
;		  43-56		bold hue	dim hue		 black
;		  29-42		dim hue		grey		 grey
;		  14-28		dim hue		black		 black
;		   0-13 	black		black		 black
;		Note that Py = Pz = 50 gives the widest spectrum.
;	For RGB: Px = red, 0-100%, Py = green, 0-100%, Pz = blue, 0-100%
;		If any color exceeds 50% then the bold bit is turned on for
;		the ensemble (IBM ega display adapter constraint for RGBi).
;
;	Palette registers can be selected by the substring
;		# Pc	followed by a non-numeric char other than ";"
;			and Pc is the palette register, 0-255.
;
;     $  (dollar sign )     meaning go to left margin
;     -  (minus) 	    meaning go to left margin 6 dots down.
;   This command yields one or more sets of 6 vertically arranged dots. They
;   are placed starting at the top and left side of the current text cell.
;   Escape sequences are permitted within string and occur without disruption.
; CONTROL-] (GS) turns on plot mode, the first move will be with beam off.
; CONTROL-^ (RS) turns on incremental plot mode. RS space means move pen up
;  RS P means move pen down, following letters: A, E, D, F, B, J, H, I mean
;  move right, right and up, up, left and up, left, left and down, down, and
;  right and down, respectively. Ex: RS <space> J J J  means move three Tek
;  positions left and down with the pen up (invisibly).
; CONTROL-UNDERLINE (US) turns off plot mode, as does CR (for all but 4025).
; CONTROL-X switches from TEKTRONIX sub mode to NORMAL alpha mode but is
;  ignored if we are emulating a full Tek terminal rather than a sub mode
;  of DEC or Heath.
; FF erases screen.
; ESC letter, where letter is accent grave (`) a..e, sets the line drawing
;   pattern until reset to solid lines (same as escape accent) by command or
;   a terminal reset.
; 
;	ENQ = Control E
;	ESC = Control [ (left square bracket)
;	FF = Control L
;	FS = Control \ (backslash)
;	GS = Control ] (right square bracket)
;	RS = Control ^ (caret)
;	US = Control _ (underscore)
;
; The plot commands are characters which specify the absolute position to move
; the beam.  All moves except the one immediately after the GS character
; (Control-]) are with a visible trace.
;
; For 4010-like devices - The positions are from 0 to 1023 for both X and Y,
; although only 0 to 780 are visible for Y due to screen geometry.  The screen
; is 10.23 by 7.80 inches, and coordinates are sent as 1 to 4 characters.
;
; For 4014-like devices - The positions are from 0 to 4096, but each movement
; is a multiple of 4 positions unless the high-resolution LSBXY are sent.  This
; makes it compatible with the 4010 in that a full sized plot fills the screen.
;
; HIX,HIY = High-order 5 bits of position
; LOX,LOY = Middle-order 5 bits of position
; LSBXY	  = Low-order 2 bits of X + low-order 2 bits of Y (4014 mode)
;
; Hi Y	  Lo Y	  Hi X	  LSBXY	  Characters sent (Lo-X always sent)
; ----	  ----	  ----	  -----	  ----------------------------------
; Same	  Same	  Same	  Same				 Lo-X
; Same	  Same	  Same	  Diff		LSB, Lo-Y,	 Lo-X	4014
; Same	  Same	  Diff	  Same		     Lo-Y, Hi-X, Lo-X
; Same	  Same	  Diff	  Diff		LSB, Lo-Y, Hi-X, Lo-X	4014
; Same	  Diff	  Same	  Same		     Lo-Y,	 Lo-X
; Same	  Diff	  Same	  Diff		LSB, Lo-Y,	 Lo-X	4014
; Same	  Diff	  Diff	  Same		     Lo-Y, Hi-X, Lo-X
; Same	  Diff	  Diff	  Diff		LSB, Lo-Y, Hi-X, Lo-X	4014
; Diff	  Same	  Same	  Same	  Hi-Y,			 Lo-X
; Diff	  Same	  Same	  Diff	  Hi-Y, LSB, Lo-Y,	 Lo-X	4014
; Diff	  Same	  Diff	  Same	  Hi-Y,	     Lo-Y, Hi-X, Lo-X
; Diff	  Same	  Diff	  Diff	  Hi-Y, LSB, Lo-Y, Hi-X, Lo-X	4014
; Diff	  Diff	  Same	  Same	  Hi-Y,	     Lo-Y,	 Lo-X
; Diff	  Diff	  Same	  Diff	  Hi-Y, LSB, Lo-Y,	 Lo-X	4014
; Diff	  Diff	  Diff	  Same	  Hi-y,	     Lo-Y, Hi-X, Lo-X
; Diff	  Diff	  Diff	  Diff	  Hi-y, LSB, Lo-Y, Hi-X, Lo-X	4014
; Offset for byte:		  20h	60h  60h   20h	 40h
;
; Note that LO-Y must be sent if HI-X has changed so that the TEKTRONIX knows
; the HI-X byte (in the range of 20h-3fh) is HI-X and not HI-Y.	 LO-Y must
; also be sent if LSBXY has changed, so that the 4010 will ignore LSBXY and
; accept LO-Y.	The LSBXY byte is 60h + MARGIN*10h + LSBY*4 + LSBX. (MARGIN=0)
;
;
;
; External variable tekflg and calls to tekini, tekemu, tekesc, tekcls:
; Byte TEKFLG is non-zero when the Tek emulator is active; it is set by the
; startup code in tekini and is maintained in mszibm. Internal variable
; inited remembers if we have a graphics screen saved, etc.
; TEKINI must be called when entering the emulator to establish the graphics
; screen mode and to calculate the screen dimensions.
; TEKRINT reinitialize complete emulator.
; TEKESC is called from say mszibm.asm to invoke Tek emulation when the
; external procedures have detected an Escape Control-L sequence. An implicit
; initialization is done if necessary.
; TEKEMU is the normal entry point to pass a received character to the emulator.
; It too will do an implicit initialization, if required.
; TEKCLS clears the graphics screen, but only if the emulator is active.
; The emulator remains active during Connect mode Help, Status, and other
; interrupts which do not change the terminal type.

     
	public	tekemu,tekini,tekrint,tekend,tekgraf ; Terminal emulation
    	public	tekdmp, tekinq, tekpal, tekrpal	; used by mszibm file
	public	chcontrol, tekcursor, tekgcptr		; used by msyibm file
	public	ttxtchr, dgline, dgbar, teksetcursor, tekremcursor
	public	cursorst, croshair, dgcrosson, dgcrossoff, dgcrossrpt
	public	dgsetcrloc, dgarc, dgpoly, savegoff, saveglen, cspb2
	public	softlist, softptr, mksoftspace, clearsoft

ENQ	equ	05h			; ^E ENQ for TEK enquiries
CAN	equ	18h			; ^X to return to ANSI mode
ESCZ	equ	1Ah			; SUB, ESC-^Z triggers crosshairs
VT	equ	0Bh			; ^K go up one line
CR	equ	0Dh
FlSep	equ	1Ch			; ^\ for point plot mode
GrpSp	equ	1Dh			; ^] draw line (1st move is invisible)
RS	equ	1Eh	       		; ^^ for incremental line plot mode
US	equ	1Fh			; ^_ (underscore) returns to text mode
accent	equ	60h			; accent grave

txtmode	equ	4			; text mode for TEKTRONIX status
maxtekx equ	1024			; horizontal and
maxteky equ	780			; vertical resolution of TEK 4010
     
screen	equ	10h			; IBM Bios screen call
     
uparr	equ	72			; DOS scan codes for arrow keys
dnarr	equ	80
lftarr	equ	75
rgtarr	equ	77
homscn	equ	71			; DOS home screen scan code
shuparr	equ	'8'			; ascii codes for shifted arrows
shdnarr	equ	'2'
shlftarr equ	'4'
shrgtarr equ	'6'
mouse	equ	33h			; Microsoft mouse interrupt
msread	equ	3			; mouse, read status and position
mswrite	equ	4			; mouse, set position
mshoriz	equ	7			; mouse, set min/max horizontal motion
msvert	equ	8			; mouse, set min/max vertical motion
msgetbf	equ	21			; mouse, get state buffer size
msgetst	equ	22			; mouse, get mouse state to buffer
mssetst	equ	23			; mouse, set mouse state from buffer
msreset	equ	33			; mouse, software reset

					; Graph_mode for different systems:
cga	equ	6			; highest resolution mode for CGA
mono	equ	7			; real monochrome display adapter
colorega equ	14			; Low-res mode, color EGA
monoega equ	15			; mono ega needs mode 15
ega	equ	16			; Hi-res mode - EGA
olivetti equ	72			; Olivetti's Hi-res - 50 lines text
toshiba	equ	74h			; Toshiba T3100, like Olivetti
vaxmate	equ	0D0h			; DEC VAXmate II, like Olivetti
wyse700 equ	0D3h			; Wyse-700 1280 * 400
hercules equ	255			; pseudo mode for Hercules graphics
; Note: IBM VGA modes 17 & 18, 640 by 480, can be used by setting "ega" above
; to 17 or 18 and modifying ybot to be 479 and ymult to be 48 at label tekin5.
; The code will scale everything appropriately for the new screen size, but
; there will be insufficient memory to retain the entire graphics image.
; Manual override SET TERMINAL GRAPHICS VGA accomplishes these two steps.
;
; Note: WYSE-700 mode 1024 * 780 and 1280 * 800 can be set only by
; manual override SET TERMINAL GRAPHICS WYSET or WYSEA, respectively.
; No automatic sensing for Wyse.

;; tekflg bits in byte
;tek_active equ	1			; actively in graphics mode
;tek_tek equ	2			; Tek terminal
;tek_dec equ	4			; Tek submode of DEC terminals
;tek_sg	equ	8			; special graphics mode

segega	equ	0a000h			; segments of display memory, EGA,VGA
segcga	equ	0b800h			; CGA, AT&T/Olivetti and relatives
seghga	equ	0b000h			; HGA
segmono	equ	0b000h			; Monochrome
segwyse equ	0a000h			; wyse-700, both banks start from here
					; Wyse equates:
wystoff equ	03ddh			; set bank start offset
wystseg equ	03deh			; set bank start base
wymode	equ	03dfh			; register to select mode & bank
wybeven equ	0c8h			; mask for R/W even bank
wybodd	equ	0cbh			; mask for R/W odd bank

					; Hercules equates:
index	equ	03b4h			; 6845 index register
cntrl	equ	03b8h			; Display mode control port
hstatus	equ	03bah			; status port
scrn_on equ	8			; bit to turn screen on
grph	equ	2			; graphics mode
text	equ	20h			; text mode
config	equ	03bfh			; configuration port
genable equ	1+2			; enable graphics (1) on two pages (2) 
rgbbold	equ	80			; nor/bold threshold for RGB intensity
hiy	equ	1			; codes for Tek graphics components
loy	equ	2
hix	equ	4
lox	equ	3
; maxparam and maxinter must agree with the prime equ's in file mszibm.asm
maxparam equ	10			; number of ESC and DCS Parameters
maxinter equ	10			; number of ESC and DCS Intermediates

					; Pixel basic operation codes
pixor	equ	1			; write as foreground OR current dot
pixbak	equ	2			; write as absolute background color
pixxor	equ	4			; write as foreground XOR current dot 
pixfor	equ	8			; write absolute foreground color


data	segment
	extrn	flags:byte, rxtable:byte, vtemu:byte, vtcpage:word
	extrn	tv_mode:byte, yflags:byte, low_rgt:byte, tekflg:byte
	extrn	param:word, nparam:word, inter:byte, ninter:word, lparam:byte
	extrn	parstate:word, pardone:word, parfail:word
	extrn	dnparam:word, dparam:word, dlparam:byte, dninter:word
	extrn	dinter:byte, dcsstrf:byte, emubufc:word, emubuf:byte
	extrn	emubufl:word, ttyact:byte, vtclear:byte
	extrn	dgwindcomp:byte, atctype:byte, dgcross:byte, scbattr:byte
	extrn	rdbuf:byte, decbuf:byte, curattr:byte, dosnum:word
	extrn	parmsk:byte, flowon:byte, flowoff:byte, flowcnt:byte
	extrn	emsrbhandle:word, emsgshandle:word, dgd470mode:byte
	extrn	xms:dword, xmsghandle:word, xmsep:word, useexp:byte

; required for Hercules screen handling
     
gtable	db	35h,2dh,2eh,7		; bytes for 6845 controller
	db	5bh,2,57h,57h		; - graphics mode
	db	2,3,0,0
     
ttable	db	61h,50h,52h,0fh		; bytes for 6845 controller
	db	19h,6,19h,19h		; - text mode
	db	2,0dh,0bh,0ch

attlogo	db	'OLIVETTI'		; Olivetti M24/28, AT&T 6300 rom id
attllen	equ	$-attlogo		; length
toshlogo db	'  TT33110000  TTOOSSHHIIBBAA' ; Toshiba T3100 logo
toshlen	equ	$-toshlogo		; length
declogo	db	'Copyright Digital Equipment Corp' ; DEC VAXmate
declen	equ	$-declogo
dumpname db	'TEKPLT.TIF',0		; dump name
dumplen	equ	$-dumpname
dhandle	dw	-1			; dump file handle
emsgsname db	'KERMIT  ',0		; 8 byte EMS region name, + safety
emsseg	dw	0			; segment of ems memory
emsbytes dw	0			; pixel bytes in ems storage
emspage	dw	0			; desired EMS page, used by XMS procs
sixteenk dw	4000h			; 16K, for XMS multiplications

;;;;;;;;;;;;;;; start session save area
	even
savegoff label	word

ttstate	dw	tektxt			; state machine control pointer
prestate dw	0			; previous state, across interruptions
visible db	0			; 0 to move, 1 to draw a line
tek_hiy dw	0			; Y coordinate in Tektronix mode
tek_loy db	0
tek_hix dw	0			; X coordinate in Tektronix mode
tek_lox db	0
tek_lsb db	0			; Low-order 2 bits of X + low Y
					;	(4014 mode)
status	db	0
lastc	db	0			; last x/y coord fragment seen	   
bnkchan db	0			; a flag so we can select which bank
					; to write in Wyse 1280*800 mode
colpal	db	0,9,0ch,0ah		; VT340 color palette table, IRGB
	db	0dh,0bh,0eh,7, 8,1,4,2, 5,3,6,0fh ; 16 bytes, active table
	db	256-($-colpal) dup (0)	; to make 256 entries overall
coldef	db	0,9,0ch,0ah, 0dh,0bh,0eh,7, 8,1,4,2, 5,3,6,0fh ; color def
mondef	db	0,7 dup (0fh), 8 dup (7) ; monochrome default "colors"
havepal	db	0			; 1 if have selected palette
masktab db	80h,40h,20h,10h,8,4,2,1 ; quicker than calculations!
					; dashed line patterns
linetab	dw	0ffffh			; ESC accent	11111111 11111111
	dw	0aaaah			; ESC a		10101010 10101010
	dw	0f0f0h			; ESC b		11110000 11110000
	dw	0fafah			; ESC c		11111010 11111010
	dw	0ffcch			; ESC d		11111111 11001100
	dw	0fc92h			; ESC e		11111100 10010010
	dw	0ffffh			; ESC x	user defined
	dw	0ffffh			; ESC y user defined
	dw	0ffffh			; ESC z user defined
linepat	dw	0ffffh			; active line pattern, from above
ginlpsave dw	0			; saved linepat while in GIN mode

tekid	db	escape,'[?63;1;2;4;8;9;15c',0; VT320, level 3, etc
;End of init data

	even
xmult	dw	1			; scaling factor for x is
xdiv	dw	1			;     xmult/xdiv
ymult	dw	1			; scaling factor for y is
ydiv	dw	1			;     ymult/ydiv
xmax	dw	640-8			;
ybot	dw	350-1			;
x_coord dw	0			; Tek text char X coordinate
y_coord dw	0			; Tek text char Y coordinate
xcursor	dw	0			; PC x_coord of text cursor symbol
ycursor	dw	0			; PC y_coord of text cursor symbol
save_xcor dw	0			; save with save-screen
save_ycor dw	0			; ditto
xcross	dw	0			; crosshair coordinates
ycross	dw	0
xcenter	dw	0			; center of screen
ycenter	dw	0			; center of screen
crossactive db	0			; non-zero if crosshair is active
tekcursor db	1			; show text cursor (non-zero)
cursorst db	0			; cursor state (non-zero is displayed)
oldx	dw	0			; Tek coordinates of last point
oldy	dw	767			;  initially top left
scalex	dw	0			; PC coord for scaled x value
scaley	dw	0			;  for scaled y value
rectx1	dw	0			; Rectangle PC x lower left corner
recty1	dw	0			; Rectangle PC y lower left corner
rectx2	dw	0			; Rectangle PC x width
recty2	dw	0			; Rectangle PC y height
angle	dw	0,0			; arc worker area
dgxmax	dw	640-1			; DG 470
dgymax	dw	480-1
;dgxmax	dw	800-1			; DG 463
;dgymax	dw	576-1

numlines dw	0			; number of lines to fill
charhgt	dw	8			; scan lines per character
charwidth dw	8			; dots across character cell
fontlptr dd	font			; pointer to high bit clear char fonts
fontrptr dd	font			; pointer to high bit set char fonts
softptr	dw	0			; seg of active soft font
softlist dw	31 dup (0)		; malloc'd space for soft char sets

dotbuf	db	16 dup (0)		; buffer to hold char dot pattern
fontfile db	'EGA.CPI',0		; DOS Code Page file, ASCIIZ
havefont dw	0			; holds Code Page if have GRight font

curcharw dw	8			; char width of cursor font
curgcol dw	0			; last used colors of cursor
					; area fill material
fill	db	0			; current fill byte pattern
fillptr	dw	filpat1			; pointer to current fill pattern
fillist	dw	filpat1,filpat2,filpat3,filpat4,filpat5,filpat6,filpat7
	dw	filpat8,filpat9,filpat10,filpat11,filpat12,filpat13
	dw	filpat14
numfil	equ	($-fillist)/2		; number of fill patterns
	; fill patterns, 8 bits wide, first byte is at top of PC screen
	; 8 bytes per pattern for 8 scan line repetition
filpat1	db	8 dup (0ffh)		; solid fill
filpat2	db	4 dup (0aah, 55h)	; grey (alternating dots)
filpat3	db	80h,01h,02h,04h, 08h,10h,20h,40h ; right to left slant up
filpat4	db	80h,40h,20h,10h, 08h,04h,02h,01h ; left to right slant up
filpat5 db	2 dup (0,0,0aah,0)	; horizontal lines
filpat6	db	8 dup (44h)		; vertical lines
filpat7	db	80h,41h,22h,14h, 08h,14h,22h,41h   ; slanted crosshatch
filpat8	db	2 dup (0aah,80h,80h,80h)  ; vertical crosshatch
filpat9	db	4 dup (0f0h), 4 dup (0fh) ; checkerboard
filpat10 db	4 dup (44h, 11h)	; dots
filpat11 db	2 dup (10h,28h,44h,82h)	; horizontal herringbone
filpat12 db	80h,40h,20h,10h,08h,10h,20h,40h ; vertical herringbone
filpat13 db	8 dup (0ffh)		; first user definable fill
filpat14 db	8 dup (0ffh)		; second user definable fill
					; end of area fill material
defcurpat db	0ffh,6 dup (81h),0ffh	; 8x8 def Tek cursor
dgcurupat db	11 dup (0),0ffh,0ffh,0,0; D463/470 cursor underline pattern
dgcurbpat db	0,12 dup (0ffh),0	; D463/470 cursor block pattern
dgctype	db	0			; D463/470 last written cursor type
curmode	db	0			; screen mode before graphics
tekgraf	db	0		; Tek graphics board selection (def=auto)
				; local variables for LINE plotting routine
graph_mode db	0			; graphics video mode, default is none
inited	db	0			; non-zero if inited (retains page)
tekident db	0			; Tek ident request flag
gpage	db	0			; display adapter graphics page
gfcol	db	15			; graphics foreground color
gbcol	db	0			; graphics background color
tfcol	db	0			; temp foreground color
tbcol	db	0			; temp background color
colortb	db	0,4,2,6,1,5,3,7		; color reversed-bit setting bytes
ccode	db	pixfor			; temp for holding plot color code
bypass	db	0			; GIN mode bypass condition (0=off)
esctype	db	0			; first char after ESCAPE char
bscontrol db	0			; non-zero for destructive BS
spcontrol db	0			; non-zero for destructive SPACE
chcontrol db	0			; char-writing, 1=opaque,0=transparent
	even
putc	dw	mputc			; ptr to plot a character routine
psetup	dw	psetupm			; ptr to plot setup routine
pincy	dw	pincym			; ptr to inc y routine
plotptr	dw	pltmon			; ptr to dot plot routine
gfplot	dw	bpltmon			; ptr to area-fill plot routine
segscn	dw	0b800h			; actual screen segment to use
linelen	dw	0			; offset increment between scan lines
temp	dw	0

saveglen dw	($-savegoff)		; length of z save area
;;;;;;;;;;;;;;;;; end of session save area

ten	dw	10			; word 10 for multiplying
mousebuf dw	0			; segment of mouse save buffer
	even

; TIFF version 5.0 data fields
; Reference: Aldus/Microsoft Technical Memorandum dated 8/8/88
					; TIFF data item size indicators
uchar	equ	1			; unsigned byte
ascii	equ	2			; asciiz string byte
integer	equ	3			; 16 bit unsigned integer
long	equ	4			; 32 bit unsigned integer
rational equ	5			; 32 bit numerator, 32 bit denominator

entry	struc				; 12 byte image file directory entries
	dw	?			; tag
	dw	integer			; type, of data item
entcnt	dd	1			; length, count of data items
entval	dw	0			; long value or long offset to value
	dw	0
entry	ends
	
	even				; TIFF 5.0,  8 byte header
header	dw	4949h			; 'll', low byte stored first
	dw	42			; TIFF identification, 42 decimal
	dw	nentry-header,0		; long offset to image file directory
					; Image File Directory
nentry	dw	entrycnt		; number of entries to follow
					; 12-byte directory entries
newsub	entry	<0feh,long>		; new subfield type
iwidth	entry	<100h,integer>		; image width,  integer for WP 5
ilength entry	<101h,integer>		; image length, integer for WP 5
bps	entry	<102h,,,4> 		; bits per sample, 4=iRGB, 1=B/W
comp	entry	<103h,,,1>		; compression, none
photo 	entry	<106h,,,3>		; photometric interpret, palette 
strip 	entry	<111h,long,25,stripoff-header> ; offset to long strip offsets
spp	entry	<115h,,,1>		; samples/pixel, 1
rps	entry	<116h,long,1,25>	; long rows per strip
sbc	entry	<117h,integer,25,stripbc-header> ; offset to strip byte counts
xres	entry	<11ah,rational,1,xresval-header> ; x axis resolution
yres	entry	<11bh,rational,1,yresval-header> ; y axis resolution
resunit entry	<128h,integer,1,1>	; resolution unit, no absolute units
soft	entry	<131h,ascii,proglen,prog-header> ; software ident
stamp	entry	<132h,ascii,dtlen,dandt-header>  ; date and time stamp
cmap	entry	<140h,integer,3*16,colmap-header> ; palette color map
entrycnt equ	($-nentry-2+11)/12	; compute number of entries for nentry
	dd	0			; long offset of next directory (none)
					; supporting data pointed at above
prog	db	'MS Kermit 300',0	; originating program, asciiz
proglen equ	$-prog
dandt	db	'1989:12:25 00:00:01',0	; date and time format
dtlen	equ	$-dandt
xresval dw	0,0,1,0			; two double words (top / bottom)
yresval dw	0,0,1,0			; two double words (top / bottom)
stripoff dd	25 dup (0)		; long file offset for each strip
stripbc dw	25 dup (0)		; integer byte count for each strip
; color map for red, green, blue; index by IRGB bits from ega sample
none equ 0
dim  equ 4000h
norm equ 8000h
bold equ 0ffffh
; dim  black,blue,green,cyan, red,magenta,yellow/brown,white
; bold black,blue,green,cyan, red,magenta,yellow,white
colmap	dw	none, none, none, none, norm, norm, norm, norm+dim ; dim red
	dw	norm, none, none, none, bold, bold, bold, bold	; bold red
	dw	none, none, norm, norm, none, none, dim,  norm+dim ; dim green
	dw	norm, none, bold, bold, none, none, bold, bold	; bold green
	dw	none, norm, none, norm, none, norm, none, norm+dim ; dim blue
	dw	norm, bold, none, bold, none, bold, none, bold	; bold blue
tifflen equ	$-header 		; length of header + directory + info
pixdata equ	$	  		; pixel data start here on disk
					; end of TIFF information

esctab	db	43			; table of ESC <char> dispatches
	dw	escjmp			; address of table for action routines
	db	ENQ,FF,CAN,CTLZ,'/'			; ^E,^L,^X,^Z,/
	db	'@ABCD','EFGHI','JKLM'
	db	3fh,'PZ[\'				; '?PZ[\'
	db	60h,'abcde','fghij','klmno','xyz'	; accent, a..o,x,y,z

; Dispatch for esctab table
	even
escjmp	dw	tekenq, tekcls,tekcan, tekgin,tekeseq	; ^E,^L,^X,^Z,/
	dw	14 dup (tekfill)			; '@ABCDEFGHIJKLM'
	dw	tekqury,tekeseq,sendid,tekeseq,tekgotst ; '?PZ[\'
	dw	19 dup (teklpat)			; accent, a..o,x,y,z

; Final char table for ANSI escape sequences
anstab	db	21			; number of entries
	dw	ansjmp			; address of action routines
	db	'@ABCD','EFGHJ','KXade','fhlmn','u'

; Dispatch for anstab table
	even
ansjmp	dw	ansich, atcuu,   atcud,   atcuf,  atcub		; '@ABCD'
	dw	atcnl,  atcpl,   atcha,   atcup,  ated		; 'EFGHJ'
	dw	atel,   atech,   atcuf,   atcva,  atcud		; 'KXade'
	dw	atcup,  escexit, escexit, tekcol, tekrid	; 'fhlmn'
	dw	tekprpt						; 'u'
data	ends

data1	segment

; 8*8 font for Hercules and such, CGA, and EGA
; - allows 43 lines, and 80 (90 for Hercules) chars per line.
; all printing (?) characters from <space> to <del> - two characters per line
; 8 bits per scan line, top line given first, 8 scan lines.	
font	db	0,0,0,0,0,0,0,0,	       18h,18h,18h,18h,18h,0,18h,0
	db	6ch,6ch,6ch,0,0,0,0,0,	       36h,36h,7fh,36h,7fh,36h,36h,0
	db	0ch,3fh,68h,3eh,0bh,7eh,18h,0, 60h,66h,0ch,18h,30h,66h,06h,0
	db	38h,6ch,6ch,38h,6dh,66h,3bh,0, 0ch,18h,30h,0,0,0,0,0
	db	0ch,18h,30h,30h,30h,18h,0ch,0, 30h,18h,0ch,0ch,0ch,18h,30h,0
	db	0,18h,7eh,3ch,7eh,18h,0,0,     0,18h,18h,7eh,18h,18h,0,0
	db	0,0,0,0,0,18h,18h,30h,	       0,0,0,7eh,0,0,0,0
	db	0,0,0,0,0,18h,18h,0,	       0,06h,0ch,18h,30h,60h,0,0
	db	3ch,66h,6eh,7eh,76h,66h,3ch,0, 18h,38h,18h,18h,18h,18h,7eh,0
	db	3ch,66h,06h,0ch,18h,30h,7eh,0, 3ch,66h,06h,1ch,06h,66h,3ch,0
	db	0ch,1ch,3ch,6ch,7eh,0ch,0ch,0, 7eh,60h,7ch,06h,06h,66h,3ch,0
	db	1ch,30h,60h,7ch,66h,66h,3ch,0, 7eh,06h,0ch,18h,30h,30h,30h,0
	db	3ch,66h,66h,3ch,66h,66h,3ch,0, 3ch,66h,66h,3eh,06h,0ch,38h,0
	db	0,0,18h,18h,0,18h,18h,0,       0,0,18h,18h,0,18h,18h,30h
	db	0ch,18h,30h,60h,30h,18h,0ch,   0,0,0,7eh,0,7eh,0,0,0
	db	30h,18h,0ch,06h,0ch,18h,30h,   0,3ch,66h,0ch,18h,18h,0,18h,0
	db	3ch,66h,6eh,6ah,6eh,60h,3ch,   0,3ch,66h,66h,7eh,66h,66h,66h,0
	db	7ch,66h,66h,7ch,66h,66h,7ch,   0,3ch,66h,60h,60h,60h,66h,3ch,0
	db	78h,6ch,66h,66h,66h,6ch,78h,   0,7eh,60h,60h,7ch,60h,60h,7eh,0
	db	7eh,60h,60h,7ch,60h,60h,60h,   0,3ch,66h,60h,6eh,66h,66h,3ch,0
	db	66h,66h,66h,7eh,66h,66h,66h,   0,7eh,18h,18h,18h,18h,18h,7eh,0
	db	3eh,0ch,0ch,0ch,0ch,6ch,38h,   0,66h,6ch,78h,70h,78h,6ch,66h,0
	db	60h,60h,60h,60h,60h,60h,7eh,   0,63h,77h,7fh,6bh,6bh,63h,63h,0
	db	66h,66h,76h,7eh,6eh,66h,66h,   0,3ch,66h,66h,66h,66h,66h,3ch,0
	db	7ch,66h,66h,7ch,60h,60h,60h,   0,3ch,66h,66h,66h,6ah,6ch,36h,0
	db	7ch,66h,66h,7ch,6ch,66h,66h,   0,3ch,66h,60h,3ch,06h,66h,3ch,0
	db	7eh,18h,18h,18h,18h,18h,18h,   0,66h,66h,66h,66h,66h,66h,3ch,0
	db	66h,66h,66h,66h,66h,3ch,18h,   0,63h,63h,6bh,6bh,7fh,77h,63h,0
	db	66h,66h,3ch,18h,3ch,66h,66h,   0,66h,66h,66h,3ch,18h,18h,18h,0
	db	7eh,06h,0ch,18h,30h,60h,7eh,   0,7ch,60h,60h,60h,60h,60h,7ch,0
	db	0,60h,30h,18h,0ch,06h,0,0,     3eh,06h,06h,06h,06h,06h,3eh,0
	db	18h,3ch,66h,42h,0,0,0,0,       0,0,0,0,0,0,0,0ffh
	db	30h,18h,0ch,0,0,0,0,0,	       0,0,3ch,06h,3eh,66h,3eh,0
	db	60h,60h,7ch,66h,66h,66h,7ch,0, 0,0,3ch,66h,60h,66h,3ch,0
	db	06h,06h,3eh,66h,66h,66h,3eh,0, 0,0,3ch,66h,7eh,60h,3ch,0
	db	0eh,18h,18h,3ch,18h,18h,18h,0, 0,0,3eh,66h,66h,3eh,06h,3ch
	db	60h,60h,7ch,66h,66h,66h,66h,0, 18h,0,38h,18h,18h,18h,3ch,0
	db	18h,0,38h,18h,18h,18h,18h,70h, 60h,60h,66h,6ch,78h,6ch,66h,0
	db	38h,18h,18h,18h,18h,18h,3ch,0, 0,0,76h,7fh,6bh,6bh,63h,0
	db	0,0,7ch,66h,66h,66h,66h,0,     0,0,3ch,66h,66h,66h,3ch,0
	db	0,0,7ch,66h,66h,7ch,60h,60h,0, 0,3eh,66h,66h,3eh,06h,07h
	db	0,0,6ch,76h,60h,60h,60h,0,     0,0,3eh,60h,3ch,06h,7ch,0
	db	30h,30h,7ch,30h,30h,30h,1ch,0, 0,0,66h,66h,66h,66h,3eh,0
	db	0,0,66h,66h,66h,3ch,18h,0,     0,0,63h,6bh,6bh,7fh,36h,0
	db	0,0,66h,3ch,18h,3ch,66h,0,     0,0,66h,66h,66h,3eh,06h,3ch
	db	0,0,7eh,0ch,18h,30h,7eh,0,     0ch,18h,18h,70h,18h,18h,0ch,0
	db	18h,18h,18h,0,18h,18h,18h,0,   30h,18h,18h,0eh,18h,18h,30h,0
	db	31h,6bh,46h,0,0,0,0,0,	       0ffh,6 dup (81h),0ffh
	; note, the last 8 bytes comprise the text cursor symbol pattern

	; 5x14 font cell, space is on the left, 4 dot descender region
fivedot	db	14 dup (0)					; 0 null
	db	0,0,0,70h,88h,0d8h,88h,0d8h,0a8h,70h,0,0,0,0	; 1 happy face
	db	0,0,0,70h,0f8h,0a8h,0f8h,0a8h,0d8h,70h,0,0,0,0	; 2 happy face
	db	0,0,0,0d8h,4 dup (0f8h),70h,20h,0,0,0,0		; 3 heart
	db	0,0,0,20h,70h,0f8h,0f8h,70h,70h,20h,0,0,0,0	; 4 diamond
	db	0,0,0,70h,20h,0a8h,0f8h,0a8h,20h,20h,0,0,0,0	; 5 club
	db	0,0,0,20h,70h,0f8h,0f8h,0a8h,20h,20h,0,0,0,0	; 6 spade
	db	4 dup (0),20h,70h,70h,70h,20h,5 dup (0)		; 7 dot
	db	5 dup (0f8h),0d8h,98h,98h,0d8h,5 dup (0f8h)	; 8 floppy
	db	4 dup (0),20h,50h,98h,98h,50h,20h,0,0,0,0	; 9 circle
	db	4 dup (0f8h),0d8h,0a8h,70h,70h,0a8h,0d8h,4 dup (0f8h) ; 10
	db	0,0,0,18h,8,20h,50h,98h,50h,20h,0,0,0,0		; 11 male
	db	5 dup (0),20h,50h,98h,50h,20h,20h,70h,20h,0	; 12 female
	db	0,0,0,30h,28h,20h,20h,20h,0e0h,0c0h,0,0,0,0	; 13 note
	db	0,0,0,40h,70h,50h,70h,50h,0d0h,0d0h,30h,30h,0,0	; 14 notes
	db	0,0,20h,98h,20h,70h,70h,20h,98h,20h,0,0,0,0	; 15 sun
	db	0,0,0,40h,60h,70h,78h,70h,60h,40h,0,0,0,0	; 16 rt arrow
	db	0,0,0,8,18h,38h,78h,38h,18h,8,0,0,0,0		; 17 lft arrow
	db	0,20h,50h,98h,20h,20h,20h,98h,50h,20h,0,0,0,0	; 18 t/b arrow
	db	0,0,6 dup (50h),0,50h,0,0,0,0			; 19 dbl bang
	db	0,0,0,78h,0a8h,0a8h,68h,28h,28h,28h,0,0,0,0	; 20 paragraph
	db	0,20h,50h,40h,20h,50h,20h,10h,50h,20h,0,0,0,0 	; 21 section
	db	5 dup (0),70h,70h,7 dup (0)			; 22 bar
	db	0,20h,50h,98h,20h,20h,20h,98h,50,20h,0,0f8h,0,0	; 23 arrow,bar
	db	0,20h,50h,98h,6 dup (20h),0,0,0,0		; 24 up arrow
	db	0,0,5 dup (20h),98h,50h,20h,0,0,0,0		; 25 dn arrow
	db	0,0,0,20h,10h,0e8h,10h,20h,6 dup (0)		; 26 rt arrow
	db	0,0,0,20h,40h,0b8h,40h,20h,6 dup (0)		; 27 lf arrow
	db	5 dup (0),40h,40h,78h,6 dup (0)			; 28
	db	4 dup (0),50h,98h,50h,7 dup (0)			; 29
	db	4 dup (0),20h,70h,0f8h,7 dup (0)		; 30 up triang
	db	4 dup (0),0f8h,70h,20h,7 dup (0)		; 31 dn traing
	db	14 dup (0)					; space
	db	0,0,20h,20h,20h,20h,20h,0,20h,0,0,0,0,0		; !
	db	0,0,50h,50h,50h,9 dup (0)			; "
	db	0,0,50h,50h,0f8h,50h,50h,0f8h,50h,50h,0,0,0,0 	; #
	db	0,20h,30h,60h,40h,60h,30h,30h,60h,20h,0,0,0,0 	; $
	db	0,0,0c0h,0c8h,10h,20h,40h,98h,18h,0,0,0,0,0	; %
	db	0,20h,50h,70h,20h,68h,90h,90h,90h,68h,0,0,0,0	; &
	db	0,0,20h,20h,20h,9 dup (0)			; '
	db	0,0,10h,20h,40h,40h,40h,40h,20h,10h,0,0,0,0	; (
	db	0,0,40h,20h,10h,10h,10h,10h,20h,40h,0,0,0,0	; )
	db	0,0,0,20h,0a8h,70h,70h,70h,0a8h,20h,0,0,0,0	; *
	db	0,0,20h,20h,20h,0f8h,20h,20h,20h,0,0,0,0,0	; +
	db	8 dup (0),10h,10h,10h,20h,0,0			; ,
	db	5 dup (0),70h,8 dup (0)				; -
	db	8 dup (0),20h,20h,0,0,0,0			; .
	db	0,0,0,0,08h,10h,20h,40h,80h,5 dup (0)		; /
	db	0,0,78h,48h,48h,58h,68h,48h,48h,78h,0,0,0,0	; 0
	db	0,0,20h,60h,5 dup (20h),70h,0,0,0,0		; 1
	db	0,0,70h,50h,10h,30h,60h,40h,40h,70h,0,0,0,0	; 2
	db	0,0,70h,50h,10h,30h,10h,10h,50h,70h,0,0,0,0	; 3
	db	0,0,10h,30h,30h,50h,50h,78h,10h,10h,0,0,0,0	; 4
	db	0,0,70h,40h,40h,70h,10h,10h,50h,70h,0,0,0,0	; 5
	db	0,0,70h,50h,40h,40h,70h,50h,50h,70h,0,0,0,0	; 6
	db	0,0,70h,10h,10h,10h,20h,20h,40h,40h,0,0,0,0	; 7
	db	0,0,70h,50h,50h,70h,50h,50h,50h,70h,0,0,0,0	; 8
	db	0,0,70h,50h,50h,70h,10h,10h,50h,70h,0,0,0,0	; 9
	db	0,0,0,20h,20h,0,0,20h,20h,5 dup (0)		; :
	db	5 dup (0),20h,20h,0,0,20h,20h,40h,0,0		; ;
	db	0,0,08h,10h,20h,40h,20h,10h,08h,5 dup(0)	; <
	db	0,0,0,0,70h,0,70h,7 dup (0)			; =
	db	0,0,40h,20h,10h,08h,10h,20h,40h,5 dup (0)	; >
	db	0,0,70h,50h,10h,30h,20h,20h,0,20h,0,0,0,0	; ?
	db	0,0,0,78h,88h,0b8h,0a8h,0b8h,80h,70h,0,0,0,0	; @
	db	0,0,30h,48h,48h,48h,78h,48h,48h,48h,0,0,0,0	; A
	db	0,0,70h,48h,48h,70h,50h,48h,48h,70h,0,0,0,0	; B
	db	0,0,30h,48h,4 dup (40h),48h,30h,0,0,0,0		; C
	db	0,0,70h,48h,4 dup (48h),48h,70h,0,0,0,0		; D
	db	0,0,78h,40h,40h,70h,40h,40h,40h,78h,0,0,0,0	; E
	db	0,0,78h,40h,40h,70h,40h,40h,40h,40h,0,0,0,0	; F
	db	0,0,30h,48h,40h,40h,58h,48h,48h,38h,0,0,0,0	; G
	db	0,0,48h,48h,48h,78h,48h,48h,48h,48h,0,0,0,0	; H
	db	0,0,70h,6 dup (20h),70h,0,0,0,0			; I
	db	0,0,38h,10h,10h,10h,10h,50h,50h,070h,0,0,0,0	; J
	db	0,0,48h,48h,50h,60h,60h,50h,50h,48h,0,0,0,0	; K
	db	0,0,7 dup (40h),70h,0,0,0,0			; L
	db	0,0,48h,78h,78h,5 dup (48h),0,0,0,0 		; M
	db	0,0,48h,48h,48h,68h,58h,48h,48h,48h,0,0,0,0	; N
	db	0,0,30h,6 dup (48h),30h,0,0,0,0			; O
	db	0,0,70h,48h,48h,48h,70h,40h,40h,40h,0,0,0,0	; P
	db	0,0,30h,48h,48h,48h,48h,58h,58h,30h,10h,0,0,0	; Q
	db	0,0,70h,48h,48h,70h,50h,50h,48h,48h,0,0,0,0	; R
	db	0,0,30h,50h,40h,60h,30h,10h,50h,60h,0,0,0,0	; S
	db	0,0,0f8h,7 dup (20h),0,0,0,0			; T
	db	0,0,7 dup (48h),78h,0,0,0,0			; U
	db	0,0,6 dup (48h),30h,30h,0,0,0,0			; V
	db	0,0,5 dup (48h),78h,78h,48h,0,0,0,0 		; W
	db	0,0,50h,50h,50h,20h,20h,50h,50h,50h,0,0,0,0	; X
	db	0,0,88h,88h,50h,50h,20h,20h,20h,20h,0,0,0,0	; Y
	db	0,0,78h,08h,10h,10h,20h,20h,40h,78h,0,0,0,0	; Z
	db	0,0,70h,6 dup (40h),70h,0,0,0,0			; [
	db	0,0,0,0,80h,40h,20h,10h,08h,5 dup (0)		; \
	db	0,0,70h,6 dup (10h),70h,0,0,0,0			; ]
	db	0,0,20h,50h,88h,9 dup (0)			; ^
	db	10 dup (0),0f8h,0,0,0				; _
	db	0,0,40h,60h,10h,9 dup (0)			; `
	db	5 dup (0),70h,10h,70h,50h,78h,0,0,0,0		; a
	db	0,0,40h,40h,40h,70h,50h,50h,50h,70h,0,0,0,0	; b
	db	5 dup (0),70h,50h,40h,50h,70h,0,0,0,0		; c
	db	0,0,10h,10h,10h,70h,50h,50h,50h,70h,0,0,0,0	; d
	db	5 dup (0),70h,50h,70h,40h,70h,0,0,0,0		; e
	db	0,0,30h,20h,20h,70h,20h,20h,20h,20h,0,0,0,0	; f
	db	5 dup (0),70h,50h,50h,70h,10h,50h,70h,0,0	; g
	db	0,0,40h,40h,40h,70h,50h,50h,50h,50h,0,0,0,0	; h
	db	0,0,0,20h,0,60h,20h,20h,20h,70h,0,0,0,0		; i
	db	0,0,0,10h,0,30h,10h,10h,10h,50h,70h,0,0,0	; j
	db	0,0,40h,40h,40h,48h,50h,60h,50h,48h,0,0,0,0	; k
	db	0,0,60h,6 dup (20h),70h,0,0,0,0			; l
	db	5 dup (0),0d8h,0f8h,0a8h,88h,88h,0,0,0,0	; m
	db	5 dup (0),0f0h,4 dup (50h),0,0,0,0		; n
	db	5 dup (0),70h,50h,50h,50h,70h,0,0,0,0		; o
	db	5 dup (0),70h,50h,50h,50h,70h,40h,40h,0,0	; p
	db	5 dup (0),70h,50h,50h,50h,70h,10h,10h,0,0	; q
	db	5 dup (0),58h,60h,40h,40h,40h,0,0,0,0		; r
	db	5 dup (0),30h,40h,20h,10h,60h,0,0,0,0		; s
	db	0,0,20h,20h,20h,70h,20h,20h,20h,30h,0,0,0,0	; t
	db	5 dup (0),4 dup (50h),70h,0,0,0,0		; u
	db	5 dup (0),50h,50h,50h,20h,20h,0,0,0,0		; v
	db	5 dup (0),88h,0a8h,0a8h,0a8h,50h,0,0,0,0	; w
	db	5 dup (0),88h,50h,20h,50h,88h,0,0,0,0		; x
	db	5 dup (0),4 dup (50h),30h,10h,70h,0,0		; y
	db	5 dup (0), 70h,10h,20h,40h,70h,0,0,0,0		; z
	db	0,0,0,30h,20h,20h,60h,20h,20h,30h,0,0,0,0	; {
	db	0,0,8 dup (20h),0,0,0,0				; |
	db	0,0,0,60h,20h,20h,30h,20h,20h,60h,0,0,0,0	; }
	db	0,0,0,40h,0a8h,10h,8 dup (0)			; ~
	db	0,0,0,20h,50h,98h,98h,98h,0f8h,5 dup (0)	; 127 DEL

							; begin CP437 GRight
gr437	db	0,0,30h,48h,40h,40h,40h,40h,48h,30h,10h,70h,0,0	; Cedillia
	db	0,0,48h,0,0,4 dup (48h),78h,0,0,0,0		; u umlate
	db	0,0,10h,20h,0,70h,50h,70h,40h,70h,0,0,0,0	; e accent
	db	0,0,20h,50h,0,70h,10h,70h,50h,78h,0,0,0,0	; a caret
	db	0,0,0,50h,0,70h,10h,70h,50h,78h,0,0,0,0		; a umlate
	db	0,0,40h,20h,0,70h,10h,70h,50h,78h,0,0,0,0	; a accent
	db	0,20h,50h,20h,0,70h,10h,70h,50h,78h,0,0,0,0	; a ring
	db	5 dup (0),70h,50h,40h,50h,70h,20h,60h,0,0	; cedillia
	db	0,0,20h,50h,0,70h,50h,70h,40h,70h,0,0,0,0	; e caret
	db	0,0,0,50h,0,70h,50h,70h,40h,70h,0,0,0,0		; e umlate
	db	0,0,40h,20h,0,70h,50h,70h,40h,70h,0,0,0,0	; e accent
	db	0,0,0,50h,0,60h,20h,20h,20h,70h,0,0,0,0		; i umlate
	db	0,0,20h,50h,0,60h,20h,20h,20h,70h,0,0,0,0	; i caret
	db	0,0,40h,20h,0,60h,20h,20h,20h,70h,0,0,0,0	; i accent
	db	0,28h,0,30h,48h,48h,78h,48h,48h,48h,0,0,0,0	; A umlate
	db	10h,28h,10h,30h,48h,48h,78h,48h,48h,48h,0,0,0,0	; A ring

	db	10h,20h,0,78h,40h,40h,70h,40h,40h,78h,0,0,0,0	; E accent
	db	5 dup (0),78h,0a8h,0b8h,0d0h,0b8h,0,0,0,0	; ae
	db	0,0,78h,0a0h,0a0h,0b0h,0a0h,0e0h,0a0h,0b8h,0,0,0,0 ; AE
	db	0,0,20h,50h,0,70h,50h,50h,50h,70h,0,0,0,0	; o caret
	db	0,0,0,50h,0,70h,50h,50h,50h,70h,0,0,0,0		; o umlate
	db	0,0,40h,20h,0,70h,50h,50h,50h,70h,0,0,0,0	; o accent
	db	0,0,20h,50h,0,50h,50h,50h,50h,70h,0,0,0,0	; u caret
	db	0,0,40h,20h,0,50h,50h,50h,50h,70h,0,0,0,0	; u accent
	db	0,0,0,50h,0,4 dup (50h),30h,10h,70h,0,0		; y umlate
	db	0,28h,0,30h,5 dup (48h),30h,0,0,0,0		; O umlate
	db	0,28h,0,6 dup (48h),78h,0,0,0,0			; U umlate
	db	0,20h,20h,70h,50h,40h,50h,70h,20h,20h,0,0,0,0	; cent sign
	db	0,30h,28h,20h,20h,70h,20h,20h,40h,78h,0,0,0,0	; Sterling
	db	0,0,88h,88h,50h,20h,70h,20h,70h,20h,0,0,0,0	; Yen
	db	0,0,0e0h,90h,90h,0e0h,80h,90h,0b8h,90h,18h,0,0,0 ; Piaster
	db	0,10h,28h,20h,20h,70h,20h,20h,0c0h,40h,0,0,0,0	; Florin

	db	0,0,10h,20h,0,70h,10h,70h,50h,78h,0,0,0,0	; a accent
	db	0,0,20h,40h,0,60h,20h,20h,20h,70h,0,0,0,0	; i accent
	db	0,0,10h,20h,0,70h,50h,50h,50h,70h,0,0,0,0	; o accent
	db	0,0,10h,20h,0,50h,50h,50h,50h,70h,0,0,0,0	; u accent
	db	0,0,28h,50h,0,60h,50h,50h,50h,50h,0,0,0,0	; n tilde
	db	0,28h,50h,0,48h,48h,68h,58h,48h,48h,0,0,0,0	; N tilde
	db	0,70h,50h,78h,0,78h,8 dup (0)			; male ord
	db	0,70h,50h,70h,0,78h,8 dup (0)			; female ord
	db	0,0,10h,0,10h,10h,20h,40h,48h,30h,0,0,0,0	; inv query
	db	5 dup (0),78h,40h,40h,6 dup (0)			; inv not
	db	5 dup (0),78h,8,8,6 dup (0)			; not
	db	40h,40h,48h,50h,20h,78h,88h,18h,20h,38h,0,0,0,0	; one half
	db	40h,40h,48h,50h,28h,58h,0a8h,48h,78h,10h,0,0,0,0 ; one quarter
	db	0,0,0,20h,0,5 dup (20h),0,0,0,0			; inv bang
	db	0,0,0,0,28h,50h,0a0h,50h,28h,0,0,0,0,0		; left chevron
	db	0,0,0,0,0a0h,50h,28h,50h,0a0h,0,0,0,0,0		; rgt chevron

	db	90h,48h,20h,90h,48h,20h,90h,48h,20h,90h,48h,20h,90h,48h
	db	0a8h,50h,0a8h,50h,0a8h,50h,0a8h,50h,0a8h,50h,0a8h,50h,0a8h,50h
	db	48h,0a0h,20h,48h,0a0h,20h,48h,0a0h,20h,48h,0a0h,20h,48h,0a0h
	db	14 dup (30h)
	db	5 dup (30h),0f0h,8 dup (30h)
	db	4 dup (30h),0f0h,30h,30h,0f0h,6 dup (30h)
	db	6 dup (50h),0d0h,7 dup (50h)
	db	6 dup (0),0f0h,7 dup (50h)
	db	4 dup (0),0f0h,30h,30h,0f0h,6 dup (30h)
	db	4 dup (50h),0d0h,50h,50h,0d0h,6 dup (50h)
	db	14 dup (50h)					; 186
	db	4 dup (0),0f0h,10h,10h,0d0h,6 dup (50h)
	db	4 dup (50h),0d0h,10h,10h,0f0h,6 dup (0)
	db	5 dup (50h),0f0h,8 dup (0)
	db	4 dup (30h),0f0h,30h,30h,0f0h,6 dup (0)
	db	4 dup (0),0f0h,9 dup (30h)

	db	5 dup (30h),038h,8 dup (0)			; 192
	db	5 dup (30h),0f8h,8 dup (0)
	db	5 dup (0),0f8h,8 dup (30h)
	db	5 dup (30h),38h,8 dup (30h)
	db	5 dup (0),0f8h,8 dup (0)			; 196
	db	5 dup (30h),0f8h,8 dup (30h)
	db	4 dup (30h),38h,30h,30h,38h,6 dup (30h)
	db	5 dup (50h),58h,8 dup (50h)
	db	4 dup (50h),58h,40h,40h,48h,6 dup (0)
	db	4 dup (0),78h,40h,40h,58h,6 dup (50h)
	db	4 dup (50h),58h,40h,40h,48h,6 dup (0)
	db	4 dup (0),0f0h,0,0,0d8h,6 dup (50h)		; 202
	db	4 dup (50h),58h,40h,40h,58h,6 dup (50h)
	db	4 dup (0),0f8h,0,0,0f8h,6 dup (0)		; 205
	db	4 dup (50h),0d8h,0,0,0d8h,6 dup (50h)
	db	5 dup (30h),0f8h,0,0f8h,6 dup (0)

	db	5 dup (50h),0f8h,8 dup (0)
	db	4 dup (0),0f8h,0,0,0f8h,6 dup (30h)
	db	5 dup (0),0f8h,8 dup (50h)
	db	5 dup (50h),0f8h,8 dup (0)
	db	4 dup (30h),38h,30h,30h,38h,6 dup (0)
	db	4 dup (0),38h,30h,30h,38h,6 dup (30h)		; 213
	db	5 dup (0),78h,8 dup (50h)
	db	5 dup (50h),0d8h,8 dup (50h)
	db	4 dup (30h),0f8h,0,0,0f8h,6 dup (30h)
	db	5 dup (30h),0f0h,8 dup (0)
	db	5 dup (0),38h,8 dup (30h)			; 218
	db	14 dup (0f8h)
	db	7 dup (0),7 dup (0f8h)
	db	14 dup (0e0h)
	db	7 dup (0f8h),7 dup (0)
	db	14 dup (38h)

	db	0,0,0,60h,98h,90h,90h,90h,98h,60h,0,0,0,0	; Alpha
	db	0,0,0,0,70h,48h,70h,48h,48h,70h,40h,40h,20h,0 	; Beta
	db	0,0,78h,48h,6 dup (40h),0,0,0,0			; Gamma
	db	0,0,0,0,0f8h,5 dup (50h),0,0,0,0		; Pi
	db	0,0,78h,48h,20h,10h,10h,20h,48h,78h,0,0,0,0	; Sigma
	db	0,0,0,0,78h,90h,90h,90h,90h,60h,0,0,0,0		; sigma
	db	5 dup (0),4 dup (48h),78h,40h,40h,80h,0		; mu
	db	0,0,0,50h,0a8h,20h,20h,20h,20h,10h,0,0,0,0	; tau
	db	0,0,0f8h,20h,70h,98h,98h,70h,20h,0f8h,0,0,0,0	; Phi
	db	0,0,30h,48h,48h,78h,48h,48h,48h,30h,0,0,0,0	; Theta
	db	0,0,70h,4 dup (90h),50h,50h,0d8h,0,0,0,0	; Omega
	db	0,0,70h,48h,20h,50h,98h,98h,98h,70h,0,0,0,0	; delta
	db	4 dup (0),50h,98h,98h,98h,98h,50h,0,0,0,0	; infinity
	db	0,0,30h,48h,48h,58h,68h,48h,0c8h,30h,0,0,0,0	; phi
	db	0,0,18h,20h,40h,78h,40h,40h,20h,18h,0,0,0,0	; epsilon
	db	0,0,0,30h,6 dup (48h),0,0,0,0			; intersect

	db	0,0,0,70h,0,70h,0,70h,6 dup (0)			; defined
	db	0,0,20h,20h,70h,20h,20h,0,70h,5 dup (0)		; +/-
	db	0,40h,20h,10h,8,10h,20h,40h,0,78h,0,0,0,0	; geq
	db	0,8,10h,20h,40h,20h,10h,8,0,78h,0,0,0,0		; leq
	db	0,0,30h,48h,48h,40h,40h,20h,20h,5 dup (10h)	; integral top
	db	4 dup (10h),5 dup (8),48h,48h,30h,0,0		; integral bot
	db	4 dup (0),10h,0,78h,0,10h,5 dup (0)		; divide
	db	4 dup (0),28h,50h,0,28h,50h,5 dup (0)		; approx equ
	db	4 dup (0),30h,48h,48h,30h,6 dup (0)		; open circle
	db	4 dup (0),30h,78h,78h,30h,6 dup (0)		; closed circ
	db	4 dup (0),30h,78h,78h,30h,6 dup (0)		; bullet
	db	0,0,18h,4 dup (10h),0d0h,30h,10h,0,0,0,0	; sqrt
	db	0,10h,68h,48h,48h,48h,8 dup (0)			; super n
	db	0,20h,50h,10h,20h,40h,70h,7 dup (0)		; super 2
	db	4 dup (0),5 dup (30h),5 dup (0)			; square
	db	14 dup (0)					; 255, empty

							; begin CP850 GRight
gr850	db	0,0,30h,48h,40h,40h,40h,40h,48h,30h,10h,70h,0,0	; Cedillia
	db	0,0,48h,0,0,4 dup (48h),78h,0,0,0,0		; u umlate
	db	0,0,10h,20h,0,70h,50h,70h,40h,70h,0,0,0,0	; e accent
	db	0,0,20h,50h,0,70h,10h,70h,50h,78h,0,0,0,0	; a caret
	db	0,0,0,50h,0,70h,10h,70h,50h,78h,0,0,0,0		; a umlate
	db	0,0,40h,20h,0,70h,10h,70h,50h,78h,0,0,0,0	; a accent
	db	0,20h,50h,20h,0,70h,10h,70h,50h,78h,0,0,0,0	; a ring
	db	5 dup (0),70h,50h,40h,50h,70h,20h,60h,0,0	; cedillia
	db	0,0,20h,50h,0,70h,50h,70h,40h,70h,0,0,0,0	; e caret
	db	0,0,0,50h,0,70h,50h,70h,40h,70h,0,0,0,0		; e umlate
	db	0,0,40h,20h,0,70h,50h,70h,40h,70h,0,0,0,0	; e accent
	db	0,0,0,50h,0,60h,20h,20h,20h,70h,0,0,0,0		; i umlate
	db	0,0,20h,50h,0,60h,20h,20h,20h,70h,0,0,0,0	; i caret
	db	0,0,40h,20h,0,60h,20h,20h,20h,70h,0,0,0,0	; i accent
	db	0,28h,0,30h,48h,48h,78h,48h,48h,48h,0,0,0,0	; A umlate
	db	10h,28h,10h,30h,48h,48h,78h,48h,48h,48h,0,0,0,0	; A ring
	
	db	10h,20h,0,78h,40h,40h,70h,40h,40h,78h,0,0,0,0	; E accent
	db	5 dup (0),78h,0a8h,0b8h,0d0h,0b8h,0,0,0,0	; ae
	db	0,0,78h,0a0h,0a0h,0b0h,0a0h,0e0h,0a0h,0b8h,0,0,0,0 ; AE
	db	0,0,20h,50h,0,70h,50h,50h,50h,70h,0,0,0,0	; o caret
	db	0,0,0,50h,0,70h,50h,50h,50h,70h,0,0,0,0		; o umlate
	db	0,0,40h,20h,0,70h,50h,50h,50h,70h,0,0,0,0	; o accent
	db	0,0,20h,50h,0,50h,50h,50h,50h,70h,0,0,0,0	; u caret
	db	0,0,40h,20h,0,50h,50h,50h,50h,70h,0,0,0,0	; u accent
	db	0,0,0,50h,0,4 dup (50h),30h,10h,70h,0,0		; y umlate
	db	0,28h,0,30h,5 dup (48h),30h,0,0,0,0		; O umlate
	db	0,28h,0,6 dup (48h),78h,0,0,0,0			; U umlate
	db	4 dup (0),8h,78h,58h,48h,68h,78h,80h,0,0,0	; o slash
	db	0,30h,28h,20h,20h,70h,20h,20h,40h,78h,0,0,0,0	; Sterling
	db	0,0,0,38h,48h,58h,48h,68h,48h,0b0h,0,0,0,0	; O slash
	db	0,0,0,88h,50h,20h,50h,88h,0,0,0,0,0,0 		; times (x)
	db	0,10h,28h,20h,20h,70h,20h,20h,0c0h,40h,0,0,0,0	; Florin

	db	0,0,10h,20h,0,70h,10h,70h,50h,78h,0,0,0,0	; a accent
	db	0,0,20h,40h,0,60h,20h,20h,20h,70h,0,0,0,0	; i accent
	db	0,0,10h,20h,0,70h,50h,50h,50h,70h,0,0,0,0	; o accent
	db	0,0,10h,20h,0,50h,50h,50h,50h,70h,0,0,0,0	; u accent
	db	0,0,28h,50h,0,60h,50h,50h,50h,50h,0,0,0,0	; n tilde
	db	0,28h,50h,0,48h,48h,68h,58h,48h,48h,0,0,0,0	; N tilde
	db	0,70h,50h,78h,0,78h,8 dup (0)			; male ord
	db	0,70h,50h,70h,0,78h,8 dup (0)			; female ord
	db	0,0,10h,0,10h,10h,20h,40h,48h,30h,0,0,0,0	; inv query
	db	0,0,70h,88h,0f8h,0d8h,0f8h,0d0h,70h,5 dup (0)	; registered
	db	5 dup (0),78h,8,8,6 dup (0)			; not
	db	40h,40h,48h,50h,20h,78h,88h,18h,20h,38h,0,0,0,0	; one half
	db	40h,40h,48h,50h,28h,58h,0a8h,48h,78h,10h,0,0,0,0 ; one quarter
	db	0,0,0,20h,0,5 dup (20h),0,0,0,0			; inv bang
	db	0,0,0,0,28h,50h,0a0h,50h,28h,0,0,0,0,0		; left chevron
	db	0,0,0,0,0a0h,50h,28h,50h,0a0h,0,0,0,0,0		; rgt chevron

	db	90h,48h,20h,90h,48h,20h,90h,48h,20h,90h,48h,20h,90h,48h
	db	0a8h,50h,0a8h,50h,0a8h,50h,0a8h,50h,0a8h,50h,0a8h,50h,0a8h,50h
	db	48h,0a0h,20h,48h,0a0h,20h,48h,0a0h,20h,48h,0a0h,20h,48h,0a0h
	db	14 dup (30h)
	db	5 dup (30h),0f0h,8 dup (30h)
	db	10h,20h,0,30h,48h,48h,78h,48h,48h,48h,4 dup (0)	; A acute
	db	10h,28h,0,30h,48h,48h,78h,48h,48h,48h,4 dup (0)	; A caret
	db	20h,10h,0,30h,48h,48h,78h,48h,48h,48h,4 dup (0)	; A grave
	db	0,70h,88h,0a8h,0d8h,0a8h,0d8h,0a8h,88h,70h,4 dup (0);copyright
	db	4 dup (50h),0d0h,50h,50h,0d0h,6 dup (50h)
	db	14 dup (50h)					; 184
	db	4 dup (0),0f0h,10h,10h,0d0h,6 dup (50h)
	db	4 dup (50h),0d0h,10h,10h,0f0h,6 dup (0)
	db	0,20h,20h,70h,50h,40h,50h,70h,20h,20h,0,0,0,0	; cent sign
	db	0,0,88h,88h,50h,20h,70h,20h,70h,20h,0,0,0,0	; Yen
	db	4 dup (0),0f0h,9 dup (30h)

	db	5 dup (30h),0f0h,8 dup (0)
	db	5 dup (30h),0f8h,8 dup (0)
	db	5 dup (0),0f8h,8 dup (30h)
	db	5 dup (30h),38h,8 dup (30h)
	db	5 dup (0),0f8h,8 dup (0)			; 196
	db	5 dup (30h),0f8h,8 dup (30h)
	db	0,0,28h,50h,0,70h,10h,70h,50h,78h,0,0,0,0	; a tilde
	db	28h,50h,0,30h,48h,48h,78h,48h,48h,48h,0,0,0,0	; A tilde
	db	4 dup (50h),58h,40h,40h,48h,6 dup (0)
	db	4 dup (0),78h,40h,40h,58h,6 dup (50h)
	db	4 dup (50h),58h,40h,40h,48h,6 dup (0)
	db	4 dup (0),0f0h,0,0,0d8h,6 dup (50h)		; 202
	db	4 dup (50h),58h,40h,40h,58h,6 dup (50h)
	db	4 dup (0),0f8h,0,0,0f8h,6 dup (0)		; 205
	db	4 dup (50h),0d8h,0,0,0d8h,6 dup (50h)
	db	0,88h,0,70h,88h,88h,88h,70h,0,88h,4 dup (0)	; sun/currency

	db	0,0,10h,60h,60h,90h,28h,48h,48h,30h,4 dup (0)	; Icelandic d
	db	0,0,70h,50h,48h,0e8h,48h,48h,50h,70h,0,0,0,0	; Icelandic D
	db	20h,50h,0,78h,40h,40h,70h,40h,40h,78h,0,0,0,0	; E caret
	db	0,28h,0,78h,40h,40h,70h,40h,40h,78h,0,0,0,0	; E umlate
	db	20h,10h,0,78h,40h,40h,70h,40h,40h,78h,0,0,0,0	; E accent
	db	3 dup (0),20h,60h,20h,20h,20h,70h,5 dup (0)	; numeral 1
	db	28h,50h,0,70h,5 dup (20h),70h,0,0,0,0		; I tilde
	db	20h,50h,0,70h,5 dup (20h),70h,0,0,0,0		; I caret
	db	0,50h,0,70h,5 dup (20h),70h,0,0,0,0		; I umlate
	db	5 dup (30h),0f0h,8 dup (0)
	db	5 dup (0),38h,8 dup (30h)			; 218
	db	14 dup (0f8h)
	db	7 dup (0),7 dup (0f8h)
	db	0,4 dup (20h),0,4 dup (20h),0,0,0,0		; v bkn bar
	db	20h,10h,0,70h,5 dup (20h),70h,0,0,0,0		; I grave
	db	14 dup (38h)

	db	10h,20h,0,30h,48h,48h,48h,48h,48h,30h,0,0,0,0	; O acute
	db	0,0,0,0,70h,48h,70h,48h,48h,70h,40h,40h,20h,0 	; Beta
	db	10h,28h,0,30h,48h,48h,48h,48h,48h,30h,0,0,0,0	; O caret
	db	20h,10h,0,30h,48h,48h,48h,48h,48h,30h,0,0,0,0	; O grave
	db	0,0,28h,50h,0,70h,50h,50h,50h,70,0,0,0,0	; o tilde
	db	28h,50h,0,30h,48h,48h,48h,48h,48h,30h,0,0,0,0	; O tilde
	db	5 dup (0),4 dup (48h),78h,40h,40h,80h,0		; mu
	db	0,0,40h,40h,40h,70h,88h,88h,70h,40h,40h,0,0,0	; Icelandic p
	db	0,0,40h,40h,70h,48h,48h,48h,70h,40h,40h,0,0,0	; Icelandic P
	db	10h,20h,0,6 dup (48h),78h,0,0,0,0		; U acute
	db	10h,28h,0,6 dup (48h),78h,0,0,0,0		; U caret
	db	20h,10h,0,6 dup (48h),78h,0,0,0,0		; U grave
	db	0,10h,20h,0,0,4 dup (50h),30h,10h,70h,0,0	; y acute
	db	10h,20h,0,88h,88h,50h,20h,20h,20h,20h,0,0,0,0	; Y acute
	db	5 dup (0),70h,8 dup (0)				; minus sign
	db	0,0,0,10h,20h,40h,8 dup (0)			; acute

	db	5 dup (0),70h,8 dup (0)				; minus sign
	db	0,0,20h,20h,70h,20h,20h,0,70h,5 dup (0)		; +/-
	db	4 dup (0),70h,0,70h,7 dup (0)			; equals
	db	0,0c0h,20h,40h,28h,0dh,28h,0d8h,0a8h,48h,78h,8,8,0 ; 3/4
	db	0,0,78h,0e8h,0e8h,68h,4 dup (28h),4 dup (0)	; Paragraph
	db	0,0,30h,40h,20h,70h,50h,50h,20h,10h,60h,0,0	; section
	db	4 dup (0),10h,0,78h,0,10h,5 dup (0)		; divide
	db	6 dup (0),18h,18h,60h,5 dup (0)			; cedilla
	db	4 dup (0),30h,48h,48h,30h,6 dup (0)		; open circle
	db	4 dup (0),50h,50h,8 dup (0)			; diaerese
	db	4 dup (0),30h,78h,78h,30h,6 dup (0)		; closed circle
	db	3 dup (0),20h,60h,20h,20h,20h,70h,5 dup (0)	; numeral 1
	db	0,70h,10h,30h,10h,10h,70h,7 dup (0)		; super 3
	db	0,20h,50h,10h,20h,40h,70h,7 dup (0)		; super 2
	db	4 dup (0),5 dup (30h),5 dup (0)			; square
	db	14 dup (0FH)					; 255, empty

		; 256 * sin(x), 0..89 degrees in steps of 1 degree
sin	db	0,4,8,13,17,22,26,31,35,40,44,48,53,57,61,66,70,74,79,83,87
	db	91,95,100,104,108,112,116,120,124,128,131,135,139,143,146,150
	db	154,157,161,164,167,171,174,177,181,184,187,190,193,196,198
	db	201,204,207,209,212,214,217,219,221,223,226,228,230,232,233
	db	235,237,238,240,242,243,244,246,247,248,249,250,251,252,252
	db	253,254,254,255,255,255,255,255

data1	ends

code1	segment
	extrn	iseof:far, dec2di:far
	assume	cs:code1
code1	ends

code	segment					; main body code segment
	extrn	outchr:near, beep:near, cmblnk:near
	extrn	cptchr:near, clrbuf:near, unique:near
	extrn	pcwait:far, spath:near

	assume	cs:code, ds:data, es:nothing

; These far routines are called by the Tek emulator; they are here to provide
; a bridge to the main code segment near procedures.
     
; Procedures for calling to the main body of MS Kermit. Most are FAR and
; must be in in code segment named code, not in code2.

outmodem proc	far			; send Tek char out serial port
	push	ax
	mov	ah,al
	call	outchr			; outchr works from ah
	cmp	flags.comflg,'D'	; doing DECnet
	je	outmodem1		; e = yes, protect LAT
	cmp	flags.comflg,'I'	; doing TES?
	jne	outmodem2		; ne = no, no protection needed
outmodem1:mov	ax,50			; 50 millsecond pause
	call	pcwait
outmodem2:pop	ax
	ret
outmodem ENDP

tekbeep	proc	far			; sound a beep from Tek mode
	call	beep
	ret
tekbeep	endp

tcmblnk	proc	far			; blank the screen from Tek mode
	call	cmblnk
	ret
tcmblnk	endp

tcptchr	proc	far			; call session logger while in Tek
	call	cptchr			;  mode
	ret
tcptchr	endp

tunique	proc	far			; reach to real unique name procedure
	call	unique			;  while in Tek mode
	ret
tunique	endp

; Return in BX the offset of the master color palette table. Used by SET TERM
; GRAPHICS COLOR <color value> to obtain foreground and background colors
; in palette slots 7 and 0, resp.
tekgcptr proc	near
	mov	tekident,1		; say this is an ident request
	call	far ptr tekini		; do init steps to get screen sizes
	mov	bx,offset mondef	; default monochrome colors
	cmp	plotptr,offset pltcga	; using CGA style graphics?
	je	tekgcpt1		; e = yes
	cmp	graph_mode,mono		; pure mono text system?
	je	tekgcpt1		; e = yes
	cmp	graph_mode,monoega	; ega, but monochrome?
	je	tekgcpt1		; e = no
	mov	bx,offset coldef	; return offset of color palette
tekgcpt1:mov	havepal,0		; say don't have a palette setup
	mov	tekident,0
	mov	inited,0
	ret
tekgcptr endp

; These routines can be called by either the main body or from within Tek
; mode.
tekdmp	proc	near			; Tek screen dump routine
	call	far ptr dump		; callable from main body
	clc
	ret
tekdmp	endp

fspath	proc	far
	call	spath
	ret
fspath	endp
code	ends

code1	segment
	extrn	scrseg:near, atparse:near, frepaint:far, ans52t:far
	assume	cs:code1

; Return screen info for Tek screen report: ax=screen height, bx=width,
; cx=number of colors (0=none for pure text, 1=b/w, 16=ega)
tekinq	proc	near
	mov	tekident,1		; say this is an ident request
	call	far ptr tekini		; do init steps to get screen sizes
	mov	ax,ybot			; lowest screen line
	inc	ax			; screen height, in lines
	mov	bx,xmax
	add	bx,8			; screen width, in dots
	cmp	graph_mode,mono		; pure text mono (no graphics at all)?
	jne	tekinq1			; ne = no
	mov	ax,24			; bottom screen line
	mov	bx,80			; screen width
	xor	cx,cx			; pure mono, say 0 colors
	jmp	short tekinq2
tekinq1:mov	cx,1			; say b/w screen
	cmp	plotptr,offset pltcga	; using CGA style graphics?
	je	tekinq2			; e = yes
	cmp	graph_mode,monoega	; monochrome monitor on ega?
	je	tekinq2			; e = yes
	mov	cx,16			; say 16 colors
tekinq2:mov	tekident,0
	ret
tekinq	endp

tparstart proc	far			; start escape sequence parser
	mov	parstate,0		; set to initialize automatically
	mov	pardone,offset tpardone	; jmp to this when completed
	mov	parfail,0		; no failure case jump
	ret
tparstart endp

tparser	proc	far
	call	atparse			; reach to real parser
	ret
tparser	endp

tpardone proc	near			; called by real parser
	call	far ptr xpardone
	ret
tpardone endp

tekpal	proc	near			; do palette report tekrpt
	call	far ptr tekrpt		; callable from main body
	ret
tekpal	endp

tekrpal	proc	near			; restore color palette
	call	far ptr tekxco4		; callable from main body
	ret
tekrpal endp

tscrseg	proc	far			; get video segment while in Tek mode
	call	scrseg
	ret
tscrseg	endp

code1	ends				; main body code segment

; Code segment code2 is allocated to Tektronix emulation
code2	segment				; supplementary code segment

	assume	cs:code2, ds:data, es:nothing

cspb2	db	256	dup (0)		; code2 segment patch buffer

tekxco4	proc	FAR			; call local tekgco4, return far
	call	tekgco4
	ret
tekxco4	endp

; Initialise TEK mode by setting high resolution screen, etc
tekini	proc	far
	push	ax			; do presence tests
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	es
	cmp	tekident,0		; just identifying?
	jne	tekin0			; ne = yes
	mov	al,flowoff
	or	al,al			; able to do xoff?
	jz	tekin0			; z = no
	call	outmodem		; tell host xoff while we change modes
tekin0:	test	tekflg,tek_active	; active now?
	jnz	tekin2			; nz = yes
	cmp	inited,0		; inited yet?
	jne	tekin2			; ne = yes, use existing coloring
	mov	ax,linetab		; get default line pattern
	mov	linepat,ax		; init active line pattern
	mov	fillptr,offset filpat1	; init active fill pointer
	cmp	havepal,0		; have a color palette yet?
	jne	tekin0a			; ne = yes
	mov	bx,vtemu.att_ptr	; emulator screen color ptr
	mov	al,[bx]
	mov	gfcol,al		; save foreground color
	and	gfcol,0fh		; save just foreground bits
	and	al,70h			; select background color, no bold
	mov	cl,4
	shr	al,cl			; get background colors
	mov	gbcol,al		; set graphics background color
tekin0a:mov	ah,15			; get current screen mode
	int	screen
	and	al,not 80h		; strip "preserve regen" bit 80h
	cmp	al,mono			; mono text mode (7)?
	je	tekin1			; e = yes
	cmp	tekident,0		; doing an ident request?
	jne	tekin2			; ne = yes, don't mess with screen
tekin1:	mov	curmode,al		; save mode here
	mov	ah,3			; get cursor position
	xor	bh,bh			; page 0
	int	screen

					; Presence tests.
tekin2:	mov	graph_mode,cga		; Color. Assume CGA
	mov	segscn,segcga		; assume cga screen segment
	mov	gpage,0			; graphics page 0 but no page 1
	mov	word ptr fontlptr,offset font	; offset of in-built 8x8 font
	mov	word ptr fontlptr+2,seg font	; segment
	cmp	word ptr fontrptr+2,0	; have a GRight now?
	jne	tekin2e			; ne = yes
	mov	word ptr fontrptr+2,seg font	; no high bit set font
	mov	word ptr fontrptr,offset font
tekin2e:mov	charhgt,8		; 8 scan lines/char
	mov	charwidth,8		; 8 dots across each char
	mov	putc,offset gputc	; CGA character display routine
	mov	gfplot,offset bpltcga	; CGA area fill routine
	mov	psetup,offset psetupc	; CGA plot setup routine
	mov	plotptr,offset pltcga	; CGA dot plot routine
	mov	pincy,offset pincyc	; CGA inc y routine
	mov	xmult,5			; CGA. Scale TEK to PC by 640/1024
	mov	xdiv,8			;  so that 0-1023 converts to 0-639
	mov	ax,640			
	sub	ax,charwidth
	mov	xmax,ax			; x-coord of rightmost character
	mov	ymult,10		; vertical scale for IBM is 200/780
	mov	ydiv,39			;
	mov	ybot,199		; Bottom of screen is Y=199
	mov	al,tekgraf		; user video board specification
	or	al,al			; auto-sensing?
	jnz	tekin2d			; nz = no
	jmp	tekin2c			; yes (default)
tekin2d:cmp	al,1			; user wants CGA?
	jne	tekin2a			; ne = no
	jmp	tekin13			; do CGA
tekin2a:cmp	al,4			; user wants Hercules?
	jne	tekin2b			; ne = no
	jmp	tekin8			; do Hercules
tekin2b:cmp	al,5			; user wants AT&T style?
	jne	tekinwy			; ne = no
	jmp	tekin7			; do AT&T kind
					; Wyse-700
tekinwy:cmp	al,8			; user wants Wyse-700 1024*780 ?
	jne	tekinw0			; ne = no
	call	chkwyse			; presence test
	jc	tekinwf			; c = failed
	jmp	short tekinw2		;
tekinw0:cmp	al,7			; user wants Wyse-700 1280*780 ?
	jne	tekinw1			; ne = no
	call	chkwyse			; presence test
	jc	tekinwf			; c = failed
	mov	ax,1280		
	sub	ax,charwidth
	mov	xmax,ax			; x-coord of rightmost character
	mov	ybot,779		; Bottom of screen is Y=800
	mov	xmult,10		; Wyse. Scale TEK to PC by 1280/1024
	mov	xdiv,8			;  so that 0-1023 converts to 0-1279
	mov	ymult,1			; vertical scale is 780/780
	mov	ydiv,1			;
	jmp	short tekinw2		;
tekinwf:jmp	tekin2c			; failure jump point
tekinw1:cmp	al,6			; user wants Wyse-700 1280*800 ?
	jne	tekin2c			; no = no
	call	chkwyse			; presence test
	jc	tekinwf			; c = failed
	mov	ax,1280			
	sub	ax,charwidth
	mov	xmax,ax			; x-coord of rightmost character
	mov	ybot,799		; Bottom of screen is Y=800
	mov	xmult,10		; Wyse. Scale TEK to PC by 1280/1024
	mov	xdiv,8			;  so that 0-1023 converts to 0-1279
	mov	ymult,40		; vertical scale for IBM is 800/780
	mov	ydiv,39			;  so scale those 20 pixels more
tekinw2:mov	graph_mode,wyse700	; Assume Wyse Graphics
	mov	segscn,segwyse		; assume wyse screen segment
	mov	gpage,0			; only one graphics page 0
	mov	putc,offset gputc	; CGA character display routine
	mov	psetup,offset psetupw	; Wyse plot setup routine
	mov	plotptr,offset pltcga	; CGA dot plot routine
	mov	pincy,offset pincyw	; Wyse inc y routine
	jmp	tekin13			; do Wyse
					; do auto-sensing of display board
					; test for EGA
tekin2c:mov	ax,1200H		; EGA: Bios alternate select
	mov	bl,10H		      	; Ask for EGA info
	mov	bh,0ffH			; Bad info, for testing
	mov	cl,0fH			; Reserved switch settings
	int	screen			; EGA, are you there?
	and	cl,0fh			; four lower switches
	cmp	cl,0cH			; Test reserved switch settings
	jb	tekin3			; b = ega present
	jmp	tekin7			; else no EGA, check other adapters

tekin3:	mov	ax,40h			; check Bios 40:87h for ega being
	mov	es,ax			;  the active display adapter
	test	byte ptr es:[87h],8	; is ega active?
	jz	tekin3a			; z = yes
	jmp	tekin7			; ega is inactive, check others
tekin3a:cmp	bl,1			; is there 128KB on ega board?
	jb	tekin4			; b = less, so no screen saves
	mov	gpage,1			; >=128 KB, use two graphics pages
tekin4:	mov	graph_mode,ega		; assume high resolution color
	cmp	cl,3			; high resolution color?
	je	tekin5			; e = yes
	cmp	cl,9			; high resolution color?
	je	tekin5			; e = yes
	mov	graph_mode,monoega	; assume mono monitor on ega board
	test	bh,1			; ega mono mode in effect?
 	jnz	tekin5			; nz = yes
	mov	graph_mode,colorega	; say ordinary cga on ega board, 64KB
	mov	gpage,1			; is enough memory with 200 scan lines
	jmp	short tekin5a		; use current cga parameters
tekin5:	mov	ybot,349		; text screen bottom is 349 on EGA
	mov	ymult,35		;
	mov	ydiv,78			; scale y by 350/780
tekin5a:mov	segscn,segega		; use ega screen segment
	mov	psetup,offset psetupe	; plot setup routine
	mov	plotptr,offset pltega	; ega dot plot routine
	mov	gfplot,offset bpltega	; ega area fill routine
	mov	pincy,offset pincye	; inc y routine
	mov	putc,offset gputc	; character display routine
	test	tekflg,tek_sg		; special graphics?
	jz	tekin5d			; z = no, use Tek 8x8 font
	mov	bh,2			; 8x14 ROM double dot (EGA, 640x350)
	mov	charhgt,14		; 8x14 dots
	mov	ax,1130h		; char generator routines, info req
	int	screen			; returns es:bp, cx, and dl (rows)
	mov	word ptr fontlptr,bp	; offset of GLeft font table
	mov	ax,es
	mov	word ptr fontlptr+2,ax	; segment of font table
	mov	cx,vtcpage		; terminal emulation code page
	cmp	cx,437			; using CP437?
	je	tekin5b			; e = yes, then have the font
	cmp	havefont,cx		; do we have this font?
	je	tekin5d			; e = yes
	mov	havefont,cx		; set rememberance flag, even if bad
	push	ax			; save hardware pointer
	push	bp
	call	getfont			; try to get new GRight font for CP
	pop	bp
	pop	ax
	jnc	tekin5d			; nc = success
tekin5b:mov	word ptr fontrptr+2,ax	; segment of hardware font table
	add	bp,128*14
	mov	word ptr fontrptr,bp	; offset of GRight part
tekin5d:jmp	tekin13			; end of EGA part, do VGA tests below

tekin7:	mov	ax,0fc00h		; Olivetti/AT&T 6300, check rom id
	mov	es,ax
	xor	di,di			; start here
	mov	graph_mode,olivetti	; Olivetti
	mov	cx,attllen		; length of logo
	mov	si,offset ATTLOGO	; master string
	repe	cmpsb			; do a match
	je	tekin7c			; e = a match
	mov	di,0050h		; look here too
	mov	si,offset ATTLOGO
	mov	cx,attllen
	repe	cmpsb
	je	tekin7c			; e = a match
	mov	di,2014h		; and look here
	mov	si,offset ATTLOGO
	mov	cx,attllen
	repe	cmpsb			; do a match
	je	tekin7c			; e = a match, else try other types
tekin7a:mov	graph_mode,toshiba
	mov	ax,0f000h		; Check for Toshiba T3100, rom scan
	mov	es,ax
	mov	di,0014h		; start here
	mov	si,offset TOSHLOGO	; master string
	mov	cx,toshlen		; length
	repe	cmpsb			; do a match
	je	tekin7c			; e = a match, else try other types
tekin7b:mov	graph_mode,vaxmate	; DEC VAXmate II
	mov	ax,0f000h		; Check for VAXmate II rom signature
	mov	es,ax
	mov	di,0e000h		; start here
	mov	si,offset DECLOGO	; master string
	mov	cx,declen		; length
	repe	cmpsb			; do a match
	jne	tekin7d			; ne = mismatch, try other types

					; Olivetti/AT&T, Toshiba, VAXmate
tekin7c:mov	gpage,0			; only page 0 with 640 by 400 mode
	mov	segscn,segcga		; use cga screen segment (0b800h)
	mov	psetup,offset psetupo	; plot setup routine
	mov	plotptr,offset pltcga	; cga dot plot routine
	mov	gfplot,offset bpltcga	; area fill plot routine
	mov	pincy,offset pincyh	; inc y routine (Herc style addresses)
	mov	putc,offset gputc	; character display routine
	mov	ybot,399		; bottom of screen is y = 399
	mov	ymult,20		; vertical scale = 400/780
	mov	ydiv,39			; same as cga setup
	jmp	tekin13

tekin7d:cmp	curmode,mono		; mono text mode?
	je	tekin8			; e = yes
	jmp	tekin11			; ne = no, try cga
					; test for Hercules
tekin8:	cmp	tv_mode,1		; Environment active?
	jne	tekin8a			; ne = no, ok to test for Hercules
	jmp	tekin10			; don't do Herc mode, do Mono
tekin8a:mov	dx,hstatus		; Herc status port
	in	al,dx			; read it
	mov	bl,al			; save here
	and	bl,80h			; remember retrace bit
	mov	cx,0ffffh		; do many times (for fast machines)
tekin8b:mov	dx,hstatus		; check status port
	in	al,dx
	and	al,80h			; select bit
	jmp	$+2			; use a little time
	cmp	bl,al			; did it change?
	loope	tekin8b			; test again if not
	je	tekin10			; e = no change in bit, not Herc
	mov	graph_mode,hercules	; say have Herc board
	mov	segscn,seghga		; assume hga screen segment
	mov	putc,offset gputc	; character display routine
	mov	gfplot,offset bpltcga	; area fill plot routine
	mov	psetup,offset psetuph	; plot setup routine to use
	mov	plotptr,offset pltcga	; use cga dot plot routine for Herc
	mov	pincy,offset pincyh	; inc y routine
	mov	xmult,45		; Scale TEK to Hercules by 720/1024
	mov	xdiv,64			;  so that 0-1023 converts to 0-719
	mov	ax,720			
	sub	ax,charwidth
	mov	xmax,ax			; x-coord of rightmost character
	mov	ymult,87		; vertical scale for Hercules is
	mov	ydiv,195		;  348/780
	mov	ybot,347		; bottom of screen is y = 347
	mov	ax,seghga		; segment of Herc video display
	mov	es,ax
	mov	al,es:[8000h]		; read original contents, page 1
	not	byte ptr es:[8000h]	; write new pattern
	mov	ah,es:[8000h]		; read back
	not	byte ptr es:[8000h]	; restore original contents
	not	ah			; invert this too
	cmp	ah,al			; same (memory present?)
	jne	tekin9			; ne = not same, no memory there
	mov	gpage,1			; say two pages of display memory
tekin9:	jmp	tekin13
					; set to MONO
tekin10:mov	graph_mode,mono		; force monochrome adapter text
	mov	segscn,segmono		; assume mono screen segment
	call	tscrseg			; Environments: get virtual screen
	mov	segscn,ax		;  seg returned in ax and es:di
	mov	gpage,0
	mov	putc,offset mputc	; character display routine
	mov	psetup,offset psetupm	; plot setup routine to use
	mov	gfplot,offset bpltmon	; area fill plot routine
	mov	plotptr,offset pltmon	; use hga dot plot routine
	mov	pincy,offset pincym	; inc y routine
	mov	xmult,5			; Scale TEK to mono by 640/1024
	mov	xdiv,8			;  so that 0-1023 converts to 0-639
	mov	ax,640			
	sub	ax,charwidth
	mov	xmax,ax			; x-coord of rightmost character
	mov	ymult,10		; vertical scale for mono is 200/780
	mov	ydiv,39
	mov	ybot,200		; bottom of screen is y = 200 for Bios
	jmp	tekin13			; Uses TEXT mode, for safety

					; test for CGA
tekin11:mov	graph_mode,cga		; set CGA high resolution graphics
	mov	segscn,segcga		; CGA screen segment
	jmp	tekin13

					; Set Graphics mode
tekin13:cmp	tekident,0		; just identifying?
	je	tekin13b		; e = no
	jmp	tekin16			; ne = yes
tekin13b:cmp	graph_mode,wyse700	; Wyse ?
	jne	tekin13a		; ne = no
	call	wygraf			; set Wyse graphics mode, clear regen
	jmp	tekin16			; restore screen
tekin13a:cmp	graph_mode,hercules	; Hercules?
	jne	tekin14			; ne = no
	call	hgraf			; set Herc graphics mode, clear regen
	or	tekflg,tek_active	; say becoming active
	jmp	tekin16			; restore screen
tekin14:xor	ah,ah			; set screen mode
	mov	al,graph_mode		;  to this screen mode
	test	flags.vtflg,ttd463+ttd470+ttd217 ; D463/D470/D217?
	jnz	tekin14a		; nz = yes, use EGA modes
	cmp	tekgraf,3		; user wants "VGA" modes (640x480)?
	jne	tekin14a		; ne = no
	push	ax
	mov	ax,1a00h		; VGA, read display config code
	int	screen
	pop	ax
	cmp	bl,0bh			; MCGA mono?
	jne	tekin14b		; ne = no
	mov	al,monoega
	mov	graph_mode,al
	jmp	short tekin14c
tekin14b:cmp	bl,0ch			; MCGA color?
	jne	tekin14d		; ne = no
	mov	al,ega
	mov	graph_mode,al
tekin14c:mov	ydiv,78			; scale y by 350/780
	mov	segscn,segega		; use ega screen segment
	mov	psetup,offset psetupe	; plot setup routine
	mov	plotptr,offset pltcga	; ega dot plot routine
	mov	gfplot,offset bpltcga	; ega area fill routine
	mov	pincy,offset pincye	; inc y routine
	mov	putc,offset gputc	; character display routine
tekin14d:cmp	al,monoega		; yes, allow high resolution stuff?
	jb	tekin14a		; b = no
	cmp	al,ega			; ditto
	ja	tekin14a		; a = no
	add	al,2			; use modes 17(b/w) and 18(10)(color)
	mov	ybot,479		; text screen bottom is 479 on VGA
	mov	ymult,48
tekin14a:cmp	tekident,0		; just identifying screen size etc?
	jne	tekin16			; ne = yes, do not invoke graphics
	cmp	gpage,0			; only page 0 available?
	je	tekin15			; e = yes, and watch for Bios errors
	cmp	inited,0		; first time through?
	je	tekin15			; e = yes, clear the page of old junk
	test	tekflg,tek_sg		; special graphics
	jnz	tekin15			; nz = yes, always repaints
	or	al,80h			; save regen buffer (save area too)

tekin15:cmp	tekgraf,9		; user wanted VESA(800x600)?
	jne	tekin15a		; ne = no
	push	ax			; save mode already in al
	mov	di,seg decbuf		; temp buffer
	mov	es,di
	mov	di,offset decbuf
	mov	cx,102h			; VESA 800x600 16 color mode
	mov	ax,4f01h		; VESA, return VESA mode (cx) info
	int	screen			; to es:di buffer
	cmp	ax,004fh		; success?
	pop	ax
	jne	tekin15b		; ne = no
	test	decbuf,2		; optional data present?
	jz	tekin15b		; z = no
	cmp	decbuf+1bh,3		; linear addressing?
	je	tekin15c		; e = yes

tekin15b:mov	ah,al			; previous mode to ah
	mov	al,6ah			; VGA extended, 800x600, mode 6ah
	and	ah,80h			; regen preservation bit
	or	al,ah			; new mode is in reg al
	xor	ah,ah
	jmp	short tekin15d		; complete setup and mode change
	
tekin15c:mov	bx,102h			; VESA 800x600
	and	al,80h			; isolate reg preservation bit
	or	bh,al			; bx bit 8000h is preservation bit
	mov	ax,4f02h		; VESA set display mode (in bx)

tekin15d:mov	xmax,800-8		; x-coord of rightmost character
	mov	xmult,25		; Scale TEK to PC by 800/1024
	mov	xdiv,32			;  so that 0-799 converts to 0-1023
	mov	ybot,600-1		; bottom of screen is Y=600
	mov	ymult,10		; scale y by 600/780
	mov	ydiv,13			;
	mov	gpage,1			; graphics pages, say have some
					; END VESA modes

tekin15a:int	screen			; Bios Set Mode.
	mov	ax,40h			; DOS 4 GRAPHICS.COM may see high bit
	mov	es,ax			;  and be confused. Clear it from Bios
	and	byte ptr es:[49h],7fh	;  word area for some clones
	or	tekflg,tek_active	; say becoming active
	mov	dgxmax,640-1		; D470 color
	mov	dgymax,480-1
	test	flags.vtflg,ttd463+ttd470+ttd217 ; D463/D470/D217?
	jz	tekin16			; z = no
	or	tekflg,tek_sg		; say special graphics mode
	cmp	flags.vtflg,ttd470	; correct guess?
	je	tekin16			; e = yes
	mov	dgxmax,800-1		; D463 monochrome
	mov	dgymax,576-1

tekin16:cmp	tekident,0		; just identifying?
	jne	tekin16a		; ne = yes
	cmp	inited,0		; inited yet?
	jne	tekin19			; ne = yes, restore screen
	mov	ttstate,offset tektxt	; do displayable text
	mov	prestate,offset tektxt	; set a previous state of text
	mov	inited,1		; say we have initialized
	jmp	short tekin16b		; and init the color palette
tekin16a:mov	si,offset colpal	; active color palette
	cmp	havepal,0		; have a color palette yet?
	jne	tekin17			; yes, use active palette
tekin16b:mov	si,offset mondef	; default monochrome colors
	cmp	plotptr,offset pltcga	; using CGA style graphics?
	je	tekin17			; e = yes
	cmp	graph_mode,mono		; pure mono text system?
	je	tekin17			; e = yes
	cmp	graph_mode,monoega	; ega, but monochrome?
	je	tekin17			; e = yes
	mov	si,offset coldef	; use color palette
tekin17:mov	havepal,1		; say have a color palette
	mov	al,[si+7]		; foreground color = palette 7
	mov	gfcol,al
	mov	al,[si]			; background color = palette 0
	mov	gbcol,al
	mov	cx,16
	mov	di,offset colpal	; VT340 active color palette
	push	es
	push	ds
	pop	es
	cld
	rep	movsb			; reinit palette entries
	pop	es
	call	fixcolor		; correct color mapping for some bds
	mov	al,gfcol
	mov	tfcol,al		; remember current coloring
	mov	al,gbcol
	mov	tbcol,al
	cmp	tekident,0		; just identifying?
	jne	tekin21			; ne = yes
	test	tekflg,tek_sg		; special graphics active?
	jnz	tekin20			; nz = yes
	call	tekcls			; clear screen, for ega coloring
	jmp	short tekin20

tekin19:cmp	vtclear,0		; clear screen?
	je	tekin19a		; e = no
	call	tekcls			; clear screen, use existing colors
	mov	vtclear,0
	jmp	short tekin20
tekin19a:test	flags.vtflg,ttd463+ttd470+ttd217 ; D463/D470/D217?
	jnz	tekin19b		; nz = yes
	test	tekflg,tek_sg		; special graphics active?
	jnz	tekin19b		; nz = yes
	call	tekrest			; restore old graphics screen
	mov	ax,save_xcor		; and saved cursor
	mov	x_coord,ax
	mov	ax,save_ycor
	mov	y_coord,ax
tekin19b:mov	al,tfcol		; and coloring
	mov	gfcol,al
	mov	al,tbcol
	mov	gbcol,al
	
tekin20:cmp	tekident,0		; just identifying screen size etc?
	jne	tekin21			; ne = yes, do not invoke graphics
	test	tekflg,tek_sg		; special graphics?
	jz	tekin20a		; z = no
	test	flags.vtflg,ttd463+ttd470+ttd217 ; D463/D470/D217?
	jz	tekin20a		; z = no
	mov	al,scbattr		; get default colors
	mov	cl,4
	shr	al,cl			; get background color bits
	mov	gbcol,al		; set the for screen clearing
	call	tekcls			; clear screen for nice repainting
	test	dgcross,1		; is crosshair to be active?
	jz	tekin20b		; z = no
	call	crossini
tekin20b:call	frepaint		; repaint screen
tekin20a:mov	ax,250
	call	pcwait			; 250 ms wait for display adapter
	mov	al,flowon		; get flowon control byte
	or	al,al			; able to send xon?
	jz	tekin20d		; z = no
	call	outmodem		; tell host xon
tekin20d:test	flags.vtflg,ttd463+ttd470+ttd217 ; D463/D470/D217?
	jnz	tekin21			; nz = yes
	test	tekflg,tek_sg		; special graphics?
	jnz	tekin21			; nz = yes
	mov	cx,seg font		; use Tek 8x8 font for non-DG work
	mov	word ptr fontlptr+2,cx
	mov	word ptr fontrptr+2,cx	; no high bit set font
	mov	cx,offset font
	mov 	word ptr fontlptr,cx
	mov	word ptr fontrptr,cx
	call	setcursor		; set the cursor

tekin21:mov	al,chcontrol		; opaque/transparent char writing
	mov	bscontrol,al		; set destructive BS control
	mov	spcontrol,al		; set destructive SPACE control
	mov	tekident,0
	mov	bypass,0		; clear Bypass flag
	clc				; clear carry for success
	pop	es
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
tekini	endp

TEKRINT proc	far			; Tek reinitialization entry point
	call	far ptr tekend		; exit cleanly if already in Tek mode
	xor	ax,ax			; get a null
	mov	inited,al		; do complete reinitialization
	mov	xcenter,ax		; forget center of screen
	mov	ycenter,ax
	mov	x_coord,ax
	mov	y_coord,ax
	mov	vtclear,1		; clear the screen
	call	tekini
	ret
TEKRINT	endp

; End TEK emulation, recover previous screen
TEKEND	proc	far
	mov	ttstate,offset tektxt	; set an initial state
	mov	prestate,offset tektxt	; and a previous state
	test	tekflg,tek_active	; running as a Tek terminal now?
	jnz	teknd1			; nz = yes
	ret				; else return as is
teknd1:	call	remcursor		; remove text cursor, if any
	call	crossfin		; clean up crosshair activity
	test	tekflg,tek_sg		; special graphics?
	jnz	teknd1a			; nz = yes, do not save screen
	call	teksave			; save graphics screen to page 1
	mov	ax,x_coord		; save cursor location too
	mov	save_xcor,ax
	mov	ax,y_coord
	mov	save_ycor,ax
teknd1a:cmp	graph_mode,hercules	; Hercules?
	jne	teknd2			; ne = no
	call	htext			; yes then set up Hercules text mode
teknd2:	call	mousexit		; restore mouse state, if any
	xor	ah,ah			; set video mode
	mov	al,curmode		; restore previous screen mode
	int	screen			; revert to text screen mode
	mov	lastc,0
	mov	bypass,0		; reset bypass condition
	mov	visible,0		; next move is invisible
	test	tekflg,tek_sg		; were doing special graphics?
	jz	teknd3			; z = no
	mov	inited,0		; yes, reinit next time
teknd3:	and	tekflg,not (tek_active+tek_sg)	; say we are inactive
	clc
	ret
TEKEND	ENDP

; Save EGA/VGA register and Bios info in array egadata.
; Returns carry clear if done, else carry set

;Terminal emulation. Enter with received character in AL.
TEKEMU	proc	far			; main emulator
	call	tektt			; local emulator routine
	ret
TEKEMU	endp

tektt	proc	near
	test	tekflg,tek_active	; running as a Tek device?
	jnz	tektt1			; nz = yes
	push	ax
	call	tekini			; init now
	pop	ax
	or	tekflg,tek_dec		; setup Tek submode of DEC terminal
	mov	ttstate,offset tektxt	; initial state
	mov	prestate,offset tektxt	; set a previous state of text
	jnc	tektt1			; nc = succeeded
	ret				; else failed to init, just return
tektt1:	test	al,80h			; high bit set?
	jz	tektt1a			; z = no
	cmp	al,9fh			; in range for C1 controls?
	ja	tektt1a			; a = no
	push	ax			; save the char
	mov	al,escape		; make 7-bit control version
	call	tektt2			; act on escape
	pop	ax
	sub	al,40h			; get second char of 7-bit control

tektt1a:and	al,7fh			; force Tek chars to be 7 bits
	or	al,al			; NUL char?
	jnz	tektt2			; nz = no
	ret				; yes, ignore it (before logging)
tektt2:	test	yflags,capt		; capturing output?
	jz	tektt4			; z = no, forget this part
	push	ax			; save char
	call	tcptchr			; give it captured character
	pop	ax			; restore character and keep going
tektt4:	test	yflags,trnctl		; debug? if so use tty mode
	jz	tektt5			; z = no
	cmp	al,DEL			; DEL char?
	jne	tektt4a			; ne = no
	mov	al,5eh			; make DEL a caret query mark
	call	outscrn
	mov	al,3fh			; the query mark
	call	outscrn
	ret
tektt4a:cmp	al,' '			; control char?
	jae	tektt4b			; ae = no
	push	ax
	mov	al,5eh			; caret
	call	outscrn
	pop	ax
	add	al,'A'-1		; make char printable
tektt4b:call	outscrn
	ret

tektt5:	cmp	bypass,0		; Bypass mode off?
	jne	tektt5a			; ne = no, on, ignore all incoming
	call	ttstate			; do current state
	ret
tektt5a:cmp	al,' '			; incoming control code?
	jae	tektt5b			; ae = no
	mov	bypass,0		; turn off bypass
	call	ttstate			; act on it
tektt5b:ret
tektt	endp
     
TEKTXT	proc	near			; Dispatch on text characters
	mov	ttstate,offset tektxt	; this is our state
	push	ax
	call	setcursor		; show text cursor
	pop	ax
	cmp	al,DEL			; RUBOUT?
	jne	tektx1			; ne = no
	mov	al,bs			; make BS
	jmp	short tektx7
tektx1:	cmp	al,CR			; carriage return (^M)?
	je	tektx7			; e = yes
	cmp	al,LF			; line feed (^J)?
	je	tektx7			; e = yes
	cmp	al,FF			; form feed (^L)?
	jne	tektx4			; ne = no
;	call	tekcls			; clear the screen
	ret
tektx4:	cmp	al,VT			; vertical tab (^K)?
	je	tektx7
	cmp	al,bell			; bell (^G)?
	jne	tektx5			; ne = no
	call	tekbeep
	ret
tektx5:	cmp	al,tab			; horizontal tab (^I)?
	je	tektx7			; e = yes
	cmp	al,BS			; backspace (^H)?
	je	tektx7			; e = yes
	cmp	al,' '			; control char?
	jae	tektx7			; ae = no
	jmp	tekctl			; process control char
tektx7:	call	outscrn			; output character to the screen
tektx8:	ret
TEKTXT	endp


tekctl	proc	near			; Control characters:
	cmp	al,GrpSp			; Line plot command?
	jne	tekctl1			; ne = no
	mov	visible,0		; next move is invisible
	and	status,not txtmode	; set status report byte
	mov	ttstate,offset tekline	; expect coordinates next
	call	remcursor		; remove text cursor
	ret
tekctl1:cmp	al,RS			; Incremental dot command?
	jne	tekctl2			; ne = no
	and	status,not txtmode	; set status report
	mov	ttstate,offset tekrlin	; expect pen command next
	call	remcursor		; remove text cursor
	ret
tekctl2:cmp	al,FlSep			; Point plot command?
	jne	tekctl3			; ne = no
	mov	visible,0		; next move is invisible
	and	status,not txtmode	; set status report byte
	mov	ttstate,offset tekpnt
	call	remcursor		; remove text cursor
	ret
tekctl3:cmp	al,US			; assert text mode? [bjh]
	jne	tekctl4			; ne = no
	or	status,txtmode		; set status report byte
	mov	ttstate,offset tektxt	; go to TEKTXT next time
	mov	visible,0		; next move is invisible
	call	setcursor		; restore text cursor
	ret
tekctl4:cmp	al,ESCAPE		; Escape?
	jne	tekctl5			; ne = no
	call	remcursor		; remove text cursor
	or	status,txtmode		; set status report byte
	cmp	ttstate,offset tekesc	; already in escape state?
	je	tekctl7			; e = yes, nest no further
	push	ttstate			; current state
	pop	prestate		; save here as previous state
	mov	ttstate,offset tekesc	; next state parses escapes
	ret

tekctl5:cmp	al,CAN			; Control X? (exits Tek sub mode)
	jne	tekctl7			; ne = no, stay in current state
	mov	ttstate,offset tektxt	; back to text mode
	mov	bypass,1		; turn on bypass mode
	cmp	flags.vtflg,tttek	; main Tek emulator?
	je	tekctl6			; e = yes, ignore the ^X
	call	tekend			; else exit sub mode
	and	tekflg,not tek_dec	; returning to text emulator
	mov	visible,0		; next move is invisible
	call	frepaint		; regenerate text screen
tekctl6:mov	prestate,offset tektxt	; make previous state text
tekctl7:ret
tekctl	endp

TEKESC	proc	near			; Process ESC <following text>
	mov	ninter,0		; initialize parsing
	mov	ttstate,offset tekesc	; in case get here from msz file
	cmp	inited,0		; inited yet? (msz call)
	jne	tekesc1			; ne = yes
	call	tekini			; init now
	mov	prestate,offset tektxt	; set a previous state of text
	jnc	tekesc1			; nc = succeeded
	ret				; else failed to init, just return
	
tekesc1:cmp	al,20h			; in intermediates, column 2?
	jb	tekesc3			; b = no
	cmp	al,2fh
	ja	tekesc3			; a = no
	mov	ttstate,offset tekesc1	; stay in this state while intermeds
	mov	bx,ninter		; number of intermediates
	cmp	bx,maxinter		; done enough already?
	jae	tekesc2			; ae = yes, ignore the excess
	mov	inter[bx],al		; store this one
	inc	ninter			; one more
	cmp	inter,'/'		; HDS2000/3000 Final char?
	je	tekesc3			; e = yes, process specially like '['
tekesc2:ret				; get more input
	
					; Final char is in AL, dispatch on it
tekesc3:mov	ttstate,offset tektxt	; set new state
	mov	esctype,al		; save kind of escape sequence
	mov	bx,offset esctab	; ESC dispatch table
	call	atdispat		; dispatch on AL
	ret
TEKESC	endp	

tekeseq	proc	near			; process Escape and Device Contrl seq
	call	tparstart		; init escape sequence parser
	mov	ttstate,offset escparse	; do parsing next
	ret
tekeseq	endp

; State for gathering text to feed escape sequence parser
escparse proc	near
	cmp	al,' '			; embedded control code?
	jb	escpar2			; b = yes, process now
	call	tparser			; far call, to call real parser
	jnc	escpar1			; nc = success
	push	prestate		; recover previous state
	pop	ttstate
	stc
escpar1:ret
escpar2:call	tekctl			; process embedded control code
	push	prestate		; get previous state
	pop	ttstate			; restore it
	ret
escparse endp

; Escape sequence parser completion routine
; AL has Final character of escape sequence
XPARDONE PROC	FAR			; called by tpardone when done
	cmp	esctype,'['		; ansi escape sequence (ESC [)?
	jne	xpardo3			; ne = no
	mov	bx,offset anstab	; ANSI ESC [ table
	call	atdispat		; dispatch on Final char in AL
	jmp	short xpardo5

xpardo3:cmp	esctype,'/'		; HDS escape sequence (ESC /)?
	jne	xpardo4			; ne = no
	call	hdsesc			; analyze
	jmp	short xpardo5

xpardo4:cmp	esctype,'P'		; DCS introducer?
	jne	xpardo5			; ne = no
	call	tekdcs			; grab parameters etc, prep strings
	ret

xpardo5:push	prestate		; recover previous state
	pop	ttstate
	ret
XPARDONE ENDP
				; ESC <char> action routines
				; exit each by putting prestate into ttstate

tekenq	proc	near			; ESC-^E Enquiry for cursor position
	mov	bypass,1		; set bypass mode
	call	sendstat		; send status
	push	prestate		; get previous state
	pop	ttstate			; restore it
	ret
tekenq	endp

tekcan	proc	near			; ESC ^X
	push	prestate		; get previous state
	pop	ttstate			; restore it
	jmp	tekctl			; process in controls section
tekcan	endp

tekgin	proc	near			; ESC-^Z Enter GIN mode
	cmp	graph_mode,mono		; Monochrome text mode?
	je	tekgin1			; e = yes, no crosshairs in text mode
	mov	bypass,1		; turn on GIN mode bypass conditon
	call	crossini		; preset crosshairs
tekgin3:call	far ptr croshair	; activate the cross-hairs
	jnc	tekgin3			; loop until exit is signaled
	call	crossfin		; clean up
	jmp	short tekgin2
tekgin1:call	tekbeep			; tell the user we are unhappy
tekgin2:push	prestate		; get previous state
	pop	ttstate			; restore it
	ret
tekgin	endp

tektwo	proc	near			; ESC 2 (Exit Tek mode)
	mov	al,CAN			; force Control-X
	jmp	tekcan			; process there as ESC ^X
tektwo	endp

tekqury	proc	near			; query mark (ESC ? means DEL)
	mov	al,DEL			; replace with DEL code
	push	prestate		; get previous state
	pop	ttstate			; restore it
	ret
tekqury	endp

tekfill	proc	near			; Fill series ESC @ .. ESC M
	sub	al,'@'			; remove bias
	mov	bl,al
	xor	bh,bh
	shl	bx,1			; make a word index
	mov	bx,fillist[bx]		; get pointer to the pattern from list
	mov	fillptr,bx		; assign this pattern pointer
	push	prestate		; get previous state
	pop	ttstate			; restore it
	ret
tekfill	endp

teklpat	proc	near			; ESC accent grave line pattern series
	cmp	al,'g'			; accent ... lowercase g?
	jbe	teklpa2			; be = yes
	cmp	al,'o'			; bold patterns ESC h..ESC o?
	ja	teklpa1			; a = no
	sub	al,'h'-accent		; map bold to normal
	jmp	short teklpa2
teklpa1:sub	al,'x'-'f'		; user sets,map x to f, y to g, z to h
teklpa2:push	bx
	mov	bl,al
	sub	bl,accent		; remove bias
	cmp	bl,8			; nine patterns, ignore others
	jbe	teklpa3			; be = ok, make others accent, solid
	xor	bl,bl			; solid pattern
teklpa3:xor	bh,bh
	shl	bx,1			; make this a word index
	mov	bx,linetab[bx]		; get line pattern word
	mov	linepat,bx		; save in active word
	pop	bx			; return to previous mode
	push	prestate		; get previous state
	pop	ttstate			; restore it
	ret
teklpat	endp

; Detect exit Tek submode command ESC [ ? 38 l  from VT340's
escexit	proc	near
	cmp	lparam,'?'		; possible "ESC [ ? 38 l"?
	jne	escex2			; ne = no
	cmp	nparam,1		; just one numeric parameter?
	jne	escex2			; ne = no
	cmp	al,'l'			; ESC [ ? Pn l?
	jne	escex2			; ne = no
	cmp	param,38		; correct value?
	jne	escex2			; ne = no
	cmp	flags.vtflg,tttek	; are we a full Tek terminal now?
	je	escex1			; e = yes, stay that way
	call	ans52t			; toggle back to text mode
	ret
escex1:	mov	ttstate,offset tektxt
	mov	al,CAN			; simulate arrival of Control-X
	jmp	tektxt			; process char as text
escex2:	ret
escexit	endp

; Human Data Systems 2000/3000 style escape sequences (ESC / params Final)
; Final character is in AL
hdsesc	proc	near
	cmp	al,'x'			; draw an empty rectangle?
	jne	hdsesc0			; ne = no
	call	rectdraw
	jmp	short hdsesc2a
hdsesc0:cmp	al,'y'			; draw a filled rectangle?
	jne	hdsesc1			; ne = no
	call	rectfil			;do xhome,yhome,xwidth,yheight,pattern
	jmp	short hdsesc2a
hdsesc1:cmp	al,'z'			; draw and fill rectangle?
	jne	hdsesc2			; ne = no
	call	rectfil			; do fill before border
	call	rectdraw		; do border
	jmp	short hdsesc2a
hdsesc2:cmp	ninter,0		; any intermediates?
	jne	hdsesc2a		; ne = yes, failure
	cmp	lparam,0		; letter parameter?
	jne	hdsesc2a		; ne = yes, failure
	cmp	nparam,1		; just zero or one numeric parameter?
	ja	hdsesc9			; a = no
	cmp	al,'a'			; user defined pattern?
	jb	hdsesc3			; b = no
	cmp	al,'c'
	ja	hdsesc3			; a = no
	sub	al,'a'			; 'a' is first of three user patterns
	xor	ah,ah			;  store as 'f,g,h' in the series
	mov	bx,ax
	shl	bx,1			; make a word index
	mov	ax,param[0]		; get the 16-bit pattern
	mov	linetab[bx+12],ax	; store in user defined pattern
hdsesc2a:push	prestate		; get previous state
	pop	ttstate			; restore it
	ret

hdsesc3:cmp	al,'d'			; "Data Level" (pixel ops)?
	jne	hdsesc4			; ne = no
	mov	cx,param		; get the parameter value
	mov	al,pixfor		; assume foreground only ESC / 0 d
	cmp	cl,1			; something else?
	jb	hdsesc3a		; b = no
	mov	al,pixbak		; assume background only ESC / 1 d
	cmp	cl,2			; something else?
	jb	hdsesc3a		; b = no
	mov	al,pixxor		; assume XOR  ESC / 2 d
	cmp	cl,3			; something else?
	jb	hdsesc3a		; b = no
	ja	hdsesc3b		; a = unknown, ignore
	mov	al,pixfor+pixbak	; write both absolute  ESC / 3 d
hdsesc3a:mov	ccode,al		; use as pixel op coding
hdsesc3b:push	prestate		; get previous state
	pop	ttstate			; restore it
	ret

hdsesc4:cmp	al,'h'			; set space, backspace control?
	je	hdsesc4a		; e = yes
	cmp	al,'l'			; reset space, backspace control?
	jne	hdsesc9			; ne = no
	xor	ah,ah			; say resetting
	jmp	short hdsesc5
hdsesc4a:mov	ah,1			; say setting
hdsesc5:cmp	param,2			; space control?
	jne	hdsesc5a		; ne = no
	mov	spcontrol,ah		; reset (0) or set destructive SPACE
	push	prestate		; get previous state
	pop	ttstate			; restore it
	ret
hdsesc5a:cmp	param,9			; destructive backspace?
	jne	hdsesc13		; ne = no
	mov	bscontrol,ah		; reset (0) or set destructive BS

hdsesc9:cmp	al,'C'			; user defined fill pattern #1?
	jne	hdsesc10		; ne = no
	mov	di,offset filpat13	; storage area for user pattern #1
	jmp	short hdsesc11
hdsesc10:cmp	al,'D'			; user defined fill pattern #2?
	jne	hdsesc11		; ne = no
	mov	di,offset filpat14	; storage area for user pattern #2
hdsesc11:mov	cx,8			; do 8 paramters
	xor	bx,bx
hdsesc12:mov	ax,param[bx]		; copy 8 bit fill pattern
	mov	[di],al			; to array
	add	bx,2
	inc	di
	loop	hdsesc12
hdsesc13:push	prestate		; get previous state
	pop	ttstate			; restore it
	ret
hdsesc	endp

; Analyze ESC [ Pn ; Pn m  color command	
; where Pn = 30-37 foreground color, 40-47 background color, ANSI standard
; Enter with escape sequence already parsed.
TEKCOL	proc	near
	push	si
	cld
	mov	al,gfcol		; update these in case error
	mov	tfcol,al
	mov	al,gbcol
	mov	tbcol,al
	mov	si,offset param		; parameters from parser
	mov	cx,nparam		; number of parameters
tekco1:	jcxz	tekco5			; z = none left
	lodsw				; parameter to ax
	dec	cx
	or	ax,ax			; 0, remove intensity, set b/w?
	jnz	tekco2			; nz = no
	mov	tfcol,7			; regular white
	mov	tbcol,0			;  on black
	jmp	short tekco1

tekco2:	cmp	ax,1			; intensity bit?
	jne	tekco3			; ne = no
	or	tfcol,8			; set foreground intensity
	jmp	short tekco1
	
tekco3:	cmp	ax,30			; foreground series?
	jb	tekco1			; b = no
	cmp	ax,37
	ja	tekco4			; a = no
	sub	ax,30			; remove bias
	push	bx
	mov	bl,al
	xor	bh,bh
	mov	al,byte ptr colortb[bx]	; reverse coloring
	pop	bx
	and	tfcol,not (7)		; retain intensity bit
	or	tfcol,al		; remember foreground color
	jmp	short tekco1

tekco4:	cmp	ax,40
	jb	tekco1
	cmp	ax,47			; legal value?
	ja	tekco1			; a = no
	sub	al,40
	push	bx
	mov	bl,al
	xor	bh,bh
	mov	al,byte ptr colortb[bx]	; reverse coloring
	pop	bx
	mov	tbcol,al		; remember background color
	jmp	short tekco1

tekco5:	cmp	ninter,0		; intermediates?
	jne	tekco7			; ne = yes, no go
	cmp	lparam,0		; letter parameter?
	jne	tekco7			; ne = yes, no go
	cmp	nparam,0		; number of ansi arguments, zero?
	ja	tekco6			; a = no, got some
	mov	tbcol,0			; none is same as 0, set b/w
	mov	tfcol,7
tekco6:	mov	al,tbcol		; success, store coloring
	mov	gbcol,al		; set background color
	mov	al,tfcol
	mov	gfcol,al		; set foreground color
	call	fixcolor		; do special ega corrections
	mov	al,gfcol		; update these in case error
	mov	tfcol,al
	mov	colpal[7],al		; foreground goes here
	mov	al,gbcol
	mov	tbcol,al
	mov	colpal[0],al		; background goes here
tekco7:	pop	si
	clc
	ret
TEKCOL	endp

; Revise screen color codes for ega boards with mono displays and limited
; memory.
fixcolor proc	near
	cmp	graph_mode,ega		; one of these ega modes?
	je	fixcol6			; e = yes
	cmp	graph_mode,colorega
	je	fixcol6
	cmp	graph_mode,monoega
	je	fixcol6
	cmp	plotptr,offset pltcga	; using CGA style graphics?
	jne	fixcol5			; ne = no
	and	gfcol,7			; strip intensity
	jmp	short fixcol6		; keep colors different
fixcol5:ret				; else ignore color corrections
fixcol6:mov	ah,gfcol
	mov	al,gbcol
	cmp	plotptr,offset pltcga	; CGA style?
	jne	fixcol8			; ne = no
	or	ah,ah			; bright foreground?
	jnz	fixcol7			; nz = yes
	mov	al,1			; make background illuminated
	jmp	short fixcol3
fixcol7:xor	al,al			; force background to dark
fixcol8:cmp	graph_mode,monoega	; monochrome ega display?
	jne	fixcol3			; ne = no
	test	al,7			; bright backgound?
	jnz	fixcol1			; nz = yes
	mov	ah,1			; normal foreground
	test	gfcol,8			; intensity on?
	jz	fixcol1			; z = no
	mov	ah,5			; say bright foreground
fixcol1:test	al,7			; black backgound?
	jz	fixcol2			; z = yes
	mov	al,1			; regular video
fixcol2:cmp	ah,al			; same color in both?
	jne	fixcol3			; ne = no
	mov	ah,1			; make foreground regular
	xor	al,al			;  and background black
fixcol3:mov	gfcol,ah
	mov	gbcol,al
	cmp	gpage,0			; minimal memory (64KB mono and ega)?
	ja	fixcol4			; a = no, enough, else strange mapping
	mov	al,gfcol		; fix coloring to map planes C0 to C1
	and	al,5			; and C2 to C3 (as 0, 3, 0Ch, or 0Fh)
	mov	ah,al			; make a copy
	shl	ah,1			; duplicate planes C0, C2 in C1, C3
	or	al,ah			; merge the bits
	mov	gfcol,al		; store proper foreground color
	mov	al,gbcol		; repeat for background color
	and	al,5
	mov	ah,al
	shl	ah,1
	or	al,ah
	mov	gbcol,al
fixcol4:ret
fixcolor endp

tekrid	proc	near			; report Tek screen parameters
	cmp	lparam,'?'		; possible "ESC [ ? 38 l"?
	jne	tekridx			; ne = no
	cmp	nparam,1		; just one numeric parameter?
	jne	tekridx			; ne = no
	cmp	param,256		; correct value?
	je	tekrid1			; e = yes
tekridx:ret
tekrid1:push	es			; as ESC [ ? 256; height; len; #col n
	push	ds
	pop	es
	cld
	mov	di,offset rdbuf		; a temp buffer
	mov	al,escape		; report
	stosb
	mov	al,'['
	stosb
	mov	al,'?'
	stosb
	mov	ax,256
	call	dec2di			; write ascii digits
	mov	al,';'
	stosb
	mov	ax,ybot			; do height
	inc	ax
	cmp	graph_mode,mono		; pure mono text system?
	jne	tekrid7a		; ne = no
	mov	ax,24
tekrid7a:call	dec2di
	mov	al,';'			; separator
	stosb
	mov	ax,xmax			; width
	add	ax,8			; in dots
	cmp	graph_mode,mono		; pure mono text system?
	jne	tekrid7b		; ne = no
	mov	ax,80
tekrid7b:call	dec2di
	mov	al,';'			; separator
	stosb
	mov	al,'1'			; screen colors, assume 1
	stosb
	cmp	plotptr,offset pltcga	; using CGA style graphics?
	je	tekrid4			; e = yes
	cmp	graph_mode,monoega	; monochrome monitor on ega?
	je	tekrid4			; e = yes
	cmp	graph_mode,mono		; pure mono text system?
	jne	tekrid3
	mov	byte ptr [di-1],'0'	; say zero colors
	jmp	short tekrid4
tekrid3:mov	al,'6'
	stosb				; say 16
tekrid4:mov	al,'n'			; end of string
	stosb
	call	outstrng		; send the string
	pop	es
	ret
tekrid	endp

tekprpt	proc	near
	cmp	nparam,1		; one or more numeric parameters?
	jb	tekrprx			; b = no
	cmp	param,2			; "CSI 2 $ u"?
	jne	tekrprx			; ne = no
	cmp	inter,'$'		; correct Intermediate?
	jne	tekrprx			; ne = no
	call	far ptr tekrpt		; invoke the palette report generator
tekrprx:ret
tekprpt	endp

tekrpt	proc	FAR			; report VT340 color palette
	push	es			; DECRQTSR(request), DECCTR(response)
	push	ds
	pop	es
	push	di
	push	bx
	cld
	mov	di,offset rdbuf		; a temp buffer
	mov	al,escape		; report
	stosb
	cmp	plotptr,offset pltcga	; using CGA style graphics?
	je	tekrpt9			; e = yes
	cmp	graph_mode,mono		; pure mono text system?
	je	tekrpt9			; e = yes
	cmp	graph_mode,monoega	; monochrome monitor on ega?
	jne	tekrpt10		; ne = no
tekrpt9:mov	ax,'0P'			; b/w systems report DCS 0 $ s ST
	stosw
	mov	ax,'s$'
	stosw
	call	outstrng
	jmp	tekrpt8

tekrpt10:mov	ax,'2P'			; color systems report DCS 2 $ s...ST
	stosw
	mov	ax,'s$'
	stosw				; "ESC [ 2 $ s"
	call	outstrng		; output this string
	mov	cx,16			; number of palette registers to do
	xor	bx,bx			; begin with color palette 0
tekrpt1:push	bx			; save palette index
	push	cx			; save loop counter
	mov	di,offset rdbuf		; buffer
	mov	ax,bx			; palette number
	call	dec2di			; palette register, to buffer
	mov	ax,'2;'			; ";2;" means sending RGB values
	stosw
	mov	al,';'
	stosb
	call	outstrng		; output this string
	mov	di,offset rdbuf		; a temp buffer
	mov	ah,colpal[bx]		; get palette iRGB
	mov	al,rgbbold/4		; assume dark red for bold black
	cmp	ah,8			; bold black?
	je	tekrpt2			; e = yes
	xor	al,al
	test	ah,4			; red?
	jz	tekrpt2			; z = no
	mov	al,rgbbold/2		; say red, 40%
	test	ah,8			; bold?
	jz	tekrpt2			; z = no
	mov	al,rgbbold		; more if bold
tekrpt2:push	ax
	xor	ah,ah			; clear high byte
	call	dec2di			; store red
	pop	ax
	mov	al,';'			; separator
	stosb
	call	outstrng		; output this string
	mov	di,offset rdbuf		; a temp buffer
	mov	al,rgbbold/4		; assume dark green for bold black
	cmp	ah,8			; bold black?
	je	tekrpt4			; e = yes
	xor	al,al
	test	ah,2			; green?
	jz	tekrpt4			; z = no
	mov	al,rgbbold/2		; say green, 40%
	test	ah,8			; bold?
	jz	tekrpt4			; z = no
	mov	al,rgbbold		; more if bold
tekrpt4:push	ax
	xor	ah,ah			; clear high byte
	call	dec2di			; store green
	pop	ax
	mov	al,';'			; separator
	stosb
	call	outstrng		; output this string
	mov	di,offset rdbuf		; a temp buffer
	mov	al,rgbbold/4		; assume dark blue for bold black
	cmp	ah,8			; bold black?
	je	tekrpt6			; e = yes
	xor	al,al
	test	ah,1			; blue?
	jz	tekrpt6			; z = no
	mov	al,rgbbold/2		; say blue, 40%
	test	ah,8			; bold?
	jz	tekrpt6			; z = no
	mov	al,rgbbold		; more if bold
tekrpt6:xor	ah,ah			; clear high byte
	call	dec2di			; store blue
	pop	cx			; recover loop counter
	cmp	cx,1			; doing last item?
	je	tekrpt7			; e = yes, do not send another "/"
	mov	al,'/'			; separator
	stosb
tekrpt7:push	cx
	call	outstrng		; output this string
	pop	cx
	pop	bx			; recover palette index
	inc	bx			; ready for next palette
	dec	cx
	jz	tekrpt8			; z = done
	jmp	tekrpt1			; do all palettes
tekrpt8:mov	al,escape		; DCS terminator ST
	call	outmodem
	mov	al,'\'
	call	outmodem
	pop	bx
	pop	di
	pop	es
	ret
tekrpt	endp

; Output string in rdbuf. Enter with di pointing at last byte+1. Return
; with di at the same place.
outstrng proc	near
	mov	ttyact,0		; group output for network
	push	ax
	push	bx
	push	cx
	mov	cx,di			; compute length
	mov	di,offset rdbuf		; start of buffer
	sub	cx,di			; start of buffer
	jle	outstn3			; le = nothing to do
outstn1:mov	al,[di]
	inc	di
	cmp	cx,1			; last character?
	ja	outstn2			; a = no
	mov	ttyact,1		; end group output for network
outstn2:call	outmodem		; send the byte
	loop	outstn1			; do the string
outstn3:pop	cx
	pop	bx
	pop	ax
	ret
outstrng endp

; Process Device Control Strings (DCS or ESC P lead-in chars, parameters,
; and Final character already read). Prepare to gather strings.
tekdcs	proc	near
	mov	dcsstrf,al		; record Final char
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
	cmp	dcsstrf,'q'		; Sixel Graphics?
	jne	tekdcs3			; ne = no
	mov	ttstate,offset tekgets	; get string as next state
	mov	al,chcontrol		; opaque/transparent char writing
	or	al,al			; is it being set?
	jz	tekdcs2			; z = no, do not force condition
	mov	bscontrol,al		; set destructive BS control
	mov	spcontrol,al		; set destructive SPACE control
tekdcs2:ret
tekdcs3:cmp	dcsstrf,'p'		; restore color palette (DCS 2 $ p)?
	jne	tekdcs1			; ne = no
	cmp	nparam,1		; just one parameter?
	jne	tekdcs1			; ne = no
	cmp	param,2			; correct parameter?
	jne	tekdcs1			; ne = no
	cmp	dinter,'$'		; correct intermediate?
	jne	tekdcs1			; ne = no
	mov	ttstate,offset tekrcol	; get color report as next state
	ret
tekdcs1:mov	ttstate,offset tekdcsnul ; consume unknown DCS
	ret
tekdcs	endp

; Read and discard OSC (ESC ]), PM (ESC ^), APC (ESC _) control sequences
; through final ST (ESC \) terminator.
tekdcsnul proc	near
	mov	dcsstrf,0		; simulate a null (dummy) Final char
	cmp	al,20h			; control char?
	jae	tekdcsnu1		; ae = no, skip
	jmp	tekctl			; do control char
tekdcsnu1:ret
tekdcsnul endp

; State machine to process DCS strings of type "p" (restore color palette)
; Enter with "p" char in AL. Callable from outside this file via tekrpal.
tekrcol	proc	near
	mov	ttstate,offset tekrco1	; next state is get parameter
	push	ax			; save character
	push	es
	push	ds
	pop	es
	push	di
	mov	cx,5			; five words
	xor	ax,ax
	mov	di,offset param		; clear parameters Pc,Pu,Px,Py,Pz
	cld
	rep	stosw
	pop	di
	pop	es
	mov	nparam,0		; work on initial parameter first
	pop	ax
tekrco1:cmp	al,escape		; escape, as in ESC \?
	je	tekrcost		; e = yes, finish command
	cmp	al,' '			; control code?
	jb	tekrco5			; b = yes, ignore it
	push	bx
	mov	bx,nparam		; parameter number
	shl	bx,1			; make it a word index
	mov	cx,param[bx]		; accumulated parameter
	call	getdec			; accumulate decimal value
	mov	param[bx],cx		; remember accumulation
	pop	bx
	jnc	tekrco5			; nc = got a digit char
	inc	nparam			; say have another complete parameter
	cmp	al,'/'			; this kind of separator?
	je	tekrco3			; e = yes, finish
	cmp	al,';'			; break char is separator?
	jne	tekrco4			; ne = no, decode current sequence
tekrco3:cmp	nparam,5		; have 5 params already?
	jb	tekrco5			; n = no, continue reading
tekrco4:call	tekgco4			; process parameters in msgibm file
	mov	ttstate,offset tekrcol	; next state is get parameter
tekrco5:ret				; start over on next field

tekrcost:				; get here on ST
	cmp	nparam,5		; enough parameters to finish cmd?
	jb	tekrcos1		; b = no, abandon it
	call	tekgco4			; update from last data item
	mov	al,escape
tekrcos1:jmp	tekctl
tekrcol	endp

; State machine to process DCS strings of type "q" (Sixel Command and Data)
; Enter with new char in AL.
tekgets	proc	near
	mov	ttstate,offset tekgets	; set state to ourselves
	mov	nparam,0		; say no pending control sequences
	cmp	al,20h			; control character?
	jae	tekgsch			; ae = no, analyze
	jmp	tekctl			; do control char
					; single sixel char state
tekgsch:cmp	al,3fh			; legal sixel data char?
	jb	tekgrpt			; b = no, try repeated char
	mov	cx,1			; repeat count of 1
	jmp	sixplt			; plot the six dots

tekgrpt:cmp	al,'!'			; repeated char?
	jne	tekgera			; ne = no
	mov	ttstate,offset tekgrpt0	; next state is get repeat parameter
	mov	param,0
	mov	nparam,0
	ret

tekgrpt0:cmp	al,' '			; control char?
	jae	tekgrpt1		; ae = no
	jmp	tekctl			; process control char
tekgrpt1:mov	cx,param		; first param is used here
	call	getdec			; accumulate repeat count to cx
	mov	param,cx		; retain current count
	jc	tekgrpt2		; c = ended on non-numeric
	ret				; get more characters
tekgrpt2:cmp	al,3fh			; break char, is it a sixel datum?
	jb	tekgrpt3		; b = no, it is illegal, quit
	call	sixplt			; plot cx versions of the six bits
	mov	ttstate,offset tekgets	; return to sixel idle state
	ret
tekgrpt3:jmp	short tekgets		; reprocess break character

tekgera:cmp	al,22h			; double quote raster attribute?
	jne	tekgco			; ne = no, try color
	mov	param,0			; clear parameters, Pan
	mov	param[2],0		; Pad
	mov	param[4],0		; Ph
	mov	param[6],0		; Pv
	mov	nparam,0		; work on initial parameter first
	mov	ttstate,offset tekgra1	; next state is get parameter
	ret
tekgra1:cmp	al,' '			; control char?
	jb	tekgra2			; b = yes, finish this work first
	push	bx
	mov	bx,nparam		; parameter number
	shl	bx,1			; make it a word index
	mov	cx,param[bx]		; accumulated parameter
	call	getdec			; accumulate decimal value into cx
	mov	param[bx],cx		; remember accumulation
	pop	bx
	jc	tekgra2			; c = failure to get a digit char
	ret
tekgra2:inc	nparam			; say have another complete parameter
	cmp	nparam,4		; got all four params Pan,Pad,Ph,Pv?
	je	tekgra4			; e = yes
	cmp	al,';'			; break char is separator?
	jne	tekgra3			; ne = no, quit now
	ret				; get more characters
tekgra3:jmp	tekgets			; restart with the break char

tekgra4:;;; perform raster attributes work here
	mov	ttstate,offset tekgets
	ret

tekgco:	cmp	al,'#'			; color introducer?
	je	tekgco0			; e = yes
	jmp	tekgcr			; ne = no
tekgco0:mov	ttstate,offset tekgco1	; next state is get parameter
	push	es
	push	ds
	pop	es
	push	di
	mov	cx,5			; five words
	xor	ax,ax
	mov	di,offset param		; clear parameters Pc,Pu,Px,Py,Pz
	cld
	rep	stosw
	pop	di
	pop	es
	mov	nparam,0		; work on initial parameter first
	ret
tekgco1:cmp	al,' '			; control char?
	jb	tekgco2			; b = yes, finish this work first
	push	bx
	mov	bx,nparam		; parameter number
	shl	bx,1			; make it a word index
	mov	cx,param[bx]		; accumulated parameter
	call	getdec			; accumulate decimal value
	mov	param[bx],cx		; remember accumulation
	pop	bx
	jc	tekgco2			; c = failure to get a digit char
	ret
tekgco2:inc	nparam			; say have another complete parameter
	cmp	al,';'			; break char is separator?
	jne	tekgco3			; ne = no, decode current sequence
	cmp	nparam,5		; have 5 params already?
	jae	tekgco3			; ae = yes, process them now
	ret				;  else get more parameters
tekgco3:cmp	nparam,1		; just one parameter?
	je	tekgco3a		; e = yes, select from palette
	jb	tekgco3b		; b = none, reprocess as sixel
	call	tekgco4			; process parameters
	mov	nparam,0		; clear parameters
	jmp	tekgets			; reprocess char as sixel

tekgco3a:push	bx			; select color from palette
	mov	bx,param[0]		; get color number
	xor	bh,bh			; make 0-255
	mov	bl,colpal[bx]		; get color from palette
	mov	gfcol,bl		; set active foreground color
	pop	bx
	push	ax			; save char in al
	call	fixcolor		; fix color too, if req'd
	pop	ax
tekgco3b:mov	nparam,0		; clear parameters
	jmp	tekgets			; reprocess char as sixel

					; set IRGB/HLS color to color palette
tekgco4:cmp	param[2],2		; Pu (1-2), wanted RBG?
	je	tekgco4b		; e = yes
	cmp	param[2],1		; Pu, wanted HLS?
	jne	tekgco4a		; ne = no
	jmp	tekgco9			; do HLS scheme
tekgco4a:mov	nparam,0		; clear parameters
	ret				; return without doing work
tekgco4b:push	ax			; iRGB, save break char in al
	mov	ax,param[4]		; red
	mov	bx,param[6]		; green
	mov	dx,param[8]		; blue
	xor	cx,cx			; cl has final color index, 0-15
	or	ch,al
	or	ch,bl
	or	ch,dl			; any color?
	jcxz	tekgco7			; z = no, use cl = 0 black
	cmp	ax,rgbbold		; setting red bold?
	jae	tekgco4c		; ae = yes
	cmp	bx,rgbbold		; setting green bold?
	jae	tekgco4c		; ae = yes
	cmp	dx,rgbbold		; setting blue bold?
	jb	tekgco4d		; b = no
tekgco4c:mov	cl,8			; set the bold bit
	jmp	tekgco4e		; do hues
tekgco4d:cmp	ax,rgbbold/2		; all in dim intensities?
	jae	tekgco4e		; ae = no
	cmp	bx,rgbbold/2		; green?
	jae	tekgco4e		; ae = no
	cmp	dx,rgbbold/2		; blue
	jae	tekgco4e		; ae = no
	mov	cl,8			; use bold black (dark grey)
	jmp	tekgco7
tekgco4e:or	ax,ax			; Hues, any red?
	jz	tekgco5			; z = no
	or	cl,4			; set red bit
	cmp	ax,rgbbold/2		; dim?
	jae	tekgco5			; ae = no
	test	cl,8			; doing bold?
	jz	tekgco5			; z = no
	xor	cl,4			; clear dim red
tekgco5:or	bx,bx			; any green?
	jz	tekgco6			; z = no
	or	cl,2			; set green bit
	cmp	bx,rgbbold/2		; dim?
	jae	tekgco6			; ae = no
	test	cl,8			; doing bold?
	jz	tekgco6			; z = no
	xor	cl,2			; clear dim green
tekgco6:or	dx,dx			; any blue?
	jz	tekgco7			; z = no
	or	cl,1			; set blue bit
	cmp	dx,rgbbold/2		; dim?
	jae	tekgco7			; ae = no
	test	cl,8			; doing bold?
	jz	tekgco7			; z = no
	xor	cl,1			; clear dim blue
tekgco7:push	bx
	mov	bx,param[0]		; Pc, color palette being defined
	xor	bh,bh			; make 0-255
	mov	colpal[bx],cl		; store color code in palette
	pop	bx
	mov	gfcol,cl		; set active foreground color
	mov	nparam,0		; say done with this sequence
	pop	ax			; recover break char in al
	ret

					; Hue, Lightness, Saturation
tekgco9:push	ax			; save break char
	xor	cl,cl			; assummed color of black
	mov	ax,param[4]		; Px, Hue, 60 degree slices
	push	cx
	mov	cx,360			; do modulo 360
	xor	dx,dx			; clear high order numerator
	div	cx			; dx has remainder
	pop	cx
	mov	ax,dx			; put remainder in ax
	cmp	ax,30			; blue?
	jae	tekgco10		; ae = no
	or	cl,1			; blue
	jmp	short tekgco15
tekgco10:cmp	ax,90			; magenta?
	jae	tekgco11		; ae = no
	or	cl,1+4			; magenta = blue + red
	jmp	short tekgco15
tekgco11:cmp	ax,150			; red?
	jae	tekgco12		; ae = no
	or	cl,4			; red
	jmp	short tekgco15
tekgco12:cmp	ax,210			; yellow?
	jae	tekgco13		; ae = no
	or	cl,4+2			; yellow = reg + green
	jmp	short tekgco15
tekgco13:cmp	ax,270			; cyan?
	jae	tekgco14		; ae = no
	or	cl,2+1			; cyan = green+blue
	jmp	short tekgco15
tekgco14:or	cl,1			; blue

tekgco15:mov	ax,param[6]		; Py, Lightness
	mov	dx,param[8]		; Pz, Saturation
	cmp	ax,86			; lightness is max?
	jb	tekgco16		; b = no
	mov	cl,0fh			; greater than 85% means bold white
	jmp	short tekgco22
tekgco16:cmp	ax,71			; high lightness?
	jb	tekgco17		; b = not that light
	or	cl,8			; turn on bold bit
	cmp	dx,51			; saturated?
	jae	tekgco22		; ae = yes
	mov	cl,0fh			; low saturation yields bold white
	jmp	short tekgco22
tekgco17:cmp	ax,57			; central coloring, upper?
	jb	tekgco18		; b = no
	or	cl,8			; turn on bold bit
	cmp	dx,51			; saturated?
	jae	tekgco22		; ae = yes, use bold colors
	mov	cl,7			; s < 50 is dim white
	cmp	dx,11			; saturated less than 11%
	jae	tekgco22		; ae = no
	xor	cl,cl			; s < 11 is black here
	jmp	short tekgco22
tekgco18:cmp	ax,43			; dim colors, upper?
	jb	tekgco19		; b = no
	or	cl,8			; turn on bold bit
	cmp	dx,51			; saturated?
	jae	tekgco22		; ae = yes, use bold colors
	and	cl,not 8		; use dim colors
	jmp	short tekgco22
tekgco19:cmp	ax,29			; dim colors, lower?
	jb	tekgco20		; b = no
	cmp	dx,51			; saturated?
	jae	tekgco22		; ae = yes
	mov	cl,7			; use dim white
	jmp	short tekgco22
tekgco20:cmp	ax,14			; dark colors?
	jb	tekgco21		; b = no
	cmp	dx,51			; saturated?
	jae	tekgco22		; ae = yes
tekgco21:xor	cl,cl			; use black
tekgco22:push	bx
	mov	bx,param[0]		; Pc, color palette being defined
	xor	bh,bh			; get palette 0-255
	mov	colpal[bx],cl		; store color code in palette
	pop	bx
	mov	gfcol,cl		; set active foreground color
	mov	nparam,0		; say done with this sequence
	pop	ax			; recover break char
	ret

tekgcr:	cmp	al,'$'			; graphics carriage return?
	jne	tekgnl			; ne = no
	mov	x_coord,0		; go to left margin, no line feed
	ret
tekgnl:	cmp	al,'-'			; graphics new line?
	jne	tekgunk			; ne = no
	mov	x_coord,0		; go to left margin, no line feed
	mov	ax,y_coord		; bottom of char cell
	add	ax,6			; go down 6 dots
	cmp	ax,ybot			; wrapping below bottom?
	jbe	tekgnl1			; be = no
	mov	ax,ybot			; stop at bottom (leaves 2 dots free!)
tekgnl1:mov	y_coord,ax
	ret
tekgunk:mov	ttstate,offset tekgets	; unknown char
	cmp	al,' '			; control char?
	jae	tekgun1			; ae = no
	jmp	tektxt			; process control char
tekgun1:ret				; ignore the unknown char
tekgets	endp

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
	mul	ten			; times ten for a new digit
	pop	dx			; recover reg, ignore overflow
	add	al,cl			; add current digit
	adc	ah,0			; 16 bits worth
	xchg	ax,cx			; rpt cnt back to cx
	clc				; say found a digit
	ret
getdecx:stc				; say non-digit (in al)
	ret
getdec	endp

; Display lower six bits of AL in a column, a sixel datum. Do CX times.
; Location is PC text cursor, x_coord, y_coord, with least significant bit
; at the top (at y_coord-8). Increments x_coord by one for each interation
; but stops at right margin and does not change y_coord. If dparam[2], P2,
; is 1 then color pattern 0 bits in current background, else skip them.
sixplt	proc	near
	or	cx,cx			; repeat count present?
	jnz	sixplt1			; nz = yes
	ret
sixplt1:push	ax
	push	bx
	push	linepat			; save line pattern
	sub	al,3fh			; remove ascii bias from sixel char
	xor	ah,ah
	mov	linepat,ax		; our dot pattern in lower 6 bits
	mov	di,y_coord		; text bottom cell line
	sub	di,charhgt		; go to top of charhgt high char cell
	jnc	sixplt2			; nc = no wrap over top
	xor	di,di			; limit to screen top
sixplt2:mov	bx,di			; bx = ending y
	add	bx,5			; plus our six dots (goes down screen)
	cmp	bx,ybot			; wrapping below bottom?
	jbe	sixplt3			; be = no
	mov	bx,ybot			; stop at bottom
sixplt3:mov	ax,x_coord		; left edge of text cell
	mov	si,ax			; si=starting, ax=ending PC x coord
	add	xmax,7			; refer to right edge, not right char
	push	es			; set up for dot plotting, save regs
	push	si
	push	di
	push	dx
	push	bp
	mov	dl,ccode		; existing pixel op code
	push	dx			; save ccode around line drawing
	mov	ccode,pixor		; set OR pixel op for use by plot()
	cmp	gfcol,0			; all black dots?
	jne	sixplt3a		; ne = no
	mov	ccode,pixfor		; yes, force overwriting to nulls
sixplt3a:push	cx
	call	psetup			; setup display and es:di and es:si
	pop	cx
					; start sixel repeat loop
sixplt4:push	cx			; save sixel repeat count
	push	di			; save y starting screen address
	mov	bp,linepat		; store active line pattern word in BP
	mov	cx,6			; six dots per sixel
					; start six dot loop
sixplt5:push	cx			; save dot count
	mov	cl,pixFor		; assume foreground coloring
;;;;	test	bp,1			; bit to be plotted, is it a 1?
;;;;	jnz	sixplt6			; nz = yes, plot in foreground color
;;;;	cmp	dparam[2],1		; P2 = 1, skip over 0's?
;;;;	je	sixplt6			; e = yes
;;;;	mov	cl,pixbak		; use background write pixel op
;;;;	or	bp,1			; set pattern bit so we see a pixel
sixplt6:mov	ccode,cl		; desired pixel op
	call	plotptr			; plot a dot if it is a 1
	call	pincy			; next dot down the screen (di)
	pop	cx			; recover dot counter
	loop	sixplt5			; do each of 6 dots
					;
	pop	di			; recover starting y screen coord
	pop	cx			; recover repeat count
	cmp	ax,xmax			; off right edge?
	jae	sixplt8			; ae = yes
	inc	ax			; move right one pixel
	inc	si			; start and stop x's
sixplt8:loop	sixplt4			; repeat sixel cx times
	pop	dx
	mov	ccode,dl		; recover main color code
	pop	bp
	pop	dx
	pop	di
	pop	si
	pop	es
	mov	x_coord,ax		; new text starting x coord
	sub	xmax,7			; restore to right most char cell
	pop	linepat			; restore normal line pattern
	pop	bx
	pop	ax
	ret
sixplt	endp

; Process ST or ESC \  String Terminator.
tekgotst proc	near
	mov	dcsstrf,0		; clear DCS Final char
	mov	nparam,0
	mov	ninter,0
	mov	al,colpal[7]		; reset foreground to palette 7
	mov	gfcol,al
	mov	al,colpal[0]		; and background to palette 0
	mov	gbcol,al
	call	fixcolor		; and fix up coloring, if req'd
	mov	prestate,offset tektxt	; reset state of emulator to normal
	mov	ttstate,offset tektxt
	call	setcursor		; restore text cursor
	ret
tekgotst endp

TEKLINE	proc	near			; GrpSp line drawing
	cmp	al,' '			; control char?
	jae	teklin3			; ae = no
	cmp	al,CR			; exit drawing on CR,LF,RS,US,FlSep,CAN
	je	teklin2			; e = yes, a cr
	cmp	al,LF			; these terminate line drawing cmds
	je	teklin2
	cmp	al,FlSep			; <FlSep>
	je	teklin2
	cmp	al,GrpSp			; <GrpSp>
	je	teklin2
	cmp	al,RS			; <RS>
	je	teklin2
	cmp	al,US			; <US>
	je	teklin2
	cmp	al,CAN			; and <CAN>
	je	teklin2			; BUT ignore other control chars
	cmp	al,escape		; escape?
	je	teklin1			; e = yes, come back to this state
	ret				; ignore stray control char
teklin1:jmp	tekctl			; process control char
teklin2:mov	lastc,0			; clear last drawing coordinate flag
	mov	visible,0		; invisible again
	jmp	tektxt			; process char under text mode

teklin3:call	tekxyc			; parse coordinates from input bytes
	jc	teklin4			; c = done, do the plotting
	ret				; nc = not done yet
teklin4:mov	cl,visible		; get moveto or drawto variable
	call	tekdraw			; move that point
	mov	visible,1		; say next time we draw
	ret
TEKLINE	endp
	
TEKPNT	proc	near			; FlSep plot single point
	cmp	al,' '			; control char?
	jae	tekpnt3			; ae = no
	cmp	al,CR			; exit drawing on CR,LF,RS,US,FlSep,CAN
	je	tekpnt2			; e = yes, a cr
	cmp	al,LF 			; these terminate line drawing cmds
	je	tekpnt2
	cmp	al,FlSep			; <FlSep>
	je	tekpnt2
	cmp	al,GrpSp			; <GrpSp>
	je	tekpnt2
	cmp	al,RS			; <RS>
	je	tekpnt2
	cmp	al,US			; <US>
	je	tekpnt2
	cmp	al,CAN			; and <CAN>
	je	tekpnt2			; BUT ignore other control chars
	cmp	al,escape		; escape?
	je	tekpnt1			; e = yes
	clc
	ret				; ignore stray control char
tekpnt1:jmp	tekctl			; process control char
tekpnt2:mov	lastc,0			; clear last drawing coordinate flag
	mov	visible,0		; invisible again
	jmp	tektxt			; process char under text mode

tekpnt3:call	tekxyc			; parse coordinates
	jc	tekpnt4			; c = done, do the plotting
	ret				; nc = not done yet
tekpnt4:xor	cl,cl			; do not draw
	call	tekdraw			; move to the point
	mov	ax,si			; copy starting point to end point
	mov	bx,di			; ax,bx,si,di are in PC coordinates
	mov	cl,1			; make plot visible
	call	line			; draw the dot
	mov	visible,0		; return to invisibility
	clc
	ret
TEKPNT	endp

; Decode graphics x,y components. Returns carry set to say have all
; components for a line, else carry clear. Understands 4014 lsb extensions.
; Permits embedded escape sequences.
TEKXYC	proc	near
	cmp	al,40h
	jb	tekgh2			; 20-3F are HIX or HIY
	cmp	al,60h			; 40-5F are LOX (causes beam movement)
	jb	tekgh4			; 60-7F are LOY
					; extract low-order 5 bits of Y coord
	mov	ah,tek_loy		; copy previous LOY to MSB (4014)
	mov	tek_lsb,ah
	and	al,1Fh			; LOY is 5 bits
	mov	tek_loy,al
	cmp	lastc,loy		; 2nd LOY in a row?
	je	tekgh1			; e = yes, then LSB is valid
	mov	tek_lsb,0		; 1st one, clear LSB
tekgh1:	mov	lastc,loy		; LOY seen, expect HIX (instead of HIY)
tekgh0:	clc				; c clear = not completed yet
	ret
tekghx:	mov	ttstate,offset tektxt	; go to TEKTXT next time
	mov	lastc,0			; clear last drawing coordinate flag
	or	status,txtmode		; set text mode in status byte
	clc				; carry clear means done
	ret

		; Extract high-order 5 bits (X or Y, depending on lastc)
tekgh2: and	ax,1Fh			; just 5 bits
	mov	cl,5
	shl	ax,cl			; shift over 5 bits
	cmp	lastc,loy		; was last coordinate a low-y?
	je	tekgh3			; e = yes, parse hix
	mov	tek_hiy,ax		; this byte has HIY
	mov	lastc,hiy
	clc
	ret
tekgh3: mov	tek_hix,ax		; this byte has HIX
	mov	lastc,hix
	clc
	ret
tekgh4: and	al,1Fh			; just 5 bits
	mov	tek_lox,al
	mov	lastc,lox
	mov	ax,tek_hix		; combine HIX*32
	or	al,tek_lox		;  with LOX
	mov	bx,tek_hiy		; same for Y
	or	bl,tek_loy
	stc				; set c to say completed operation
	ret
TEKXYC	endp

TEKRLIN	proc	near			; RS relative line drawing
	cmp	al,' '			; control char?
	jae	tekrli1			; ae = no
	jmp	tektxt			; process control char
tekrli1:cmp	al,' '			; pen up command?
	jne	tekrli2			; ne = no, try pen down
	mov	visible,0		; do invisible movements
	jmp	short tekrli3		; do the command
tekrli2:cmp	al,'P'			; pen down command?
	jne	tekrli4			; ne = no, return to text mode
	mov	visible,1		; set visible moves

tekrli3:mov	ax,x_coord		; PC x coordinate of pen
	mov	bx,y_coord		;    y coordinate
	call	pctotek			; get current pen position in Tek coor
	xor	cl,cl			; invisible, moveto
	call	tekdraw			; move that point, set oldx and oldy
	mov	ttstate,offset tekinc	; next get incremental movement cmds
	ret

tekrli4:mov	visible,0		; bad char, reset visibility
	mov	ttstate,offset tektxt	; assume text
tekrli5:jmp	ttstate			; deal with bad char
TEKRLIN	endp
					; interpret RS inc plot command byte
TEKINC	proc	near			; get movement character and do cmd
	cmp	al,' '			; control char?
	jae	tekinc1			; ae = no
	jmp	tektxt			; process control char
tekinc1:mov	bx,oldx
	mov	cx,oldy
	test	al,1			; 'A', 'E', 'I'?  Do by bit fields
	jz	tekinc2			; z = no
	inc	bx			; adjust beam position
tekinc2:test	al,2			; 'B', 'F', 'J'?
	jz	tekinc4
	dec	bx
tekinc4:test	al,4			; 'D', 'E', 'F'?
	jz	tekinc8			; z = no
	inc	cx
tekinc8:test	al,8			; 'H', 'I', 'J'?
	jz	tekinc9
	dec	cx
tekinc9:cmp	bx,0			; too far left?
	jge	tekinc10		; ge = no
	xor	bx,bx			; else stop at the left margin
tekinc10:cmp	bx,maxtekx-1		; too far left?
	jle	tekinc11		; le = no
	mov	bx,maxtekx-1		; else stop that the left margin
tekinc11:cmp	cx,maxteky-1		; above the top?
	jle	tekinc12		; le = not above the top
	mov	cx,maxteky-1		; else stop at the top
tekinc12:cmp	cx,0			; below bottom?
	jge	tekinc13		; ge = not below bottom
	xor	cx,cx			; else stop at the bottom
tekinc13:mov	ax,bx			; ax is vector x end point
	mov	oldx,bx
	mov	bx,cx			; bx is vector y end point
	mov	oldy,cx
	mov	cl,visible
	jmp	tekdraw			; move/draw to that point
tekincb:mov	visible,0
	jmp	tektxt			; reparse the bad char
TEKINC	endp
	

crossini proc	near			; set crosshairs for initial screen
	cmp	crossactive,0		; inited already?
	je	crossin1		; e = no
	ret
crossin1:mov	ax,xmax			; right margin minus 7 dots
	add	ax,7			; right most dot
	shr	ax,1			; central position
	mov	bx,ybot			; last scan line
	shr	bx,1
	cmp	ax,xcenter		; same as previous call?
	jne	crossin2		; ne = no, recenter
	cmp	bx,ycenter		; same as previous call?
	je	crossin3		; e = yes, don't recenter crosshairs
crossin2:
	mov	xcenter,ax		; remember center coord
	mov	ycenter,bx		; remember center coord
	mov	xcross,ax		; save PC coord for crosshair
	mov	ycross,bx
crossin3:				; Mouse setup
	mov	mousebuf,0		; assume no active mouse driver
	mov	al,mouse		; mouse interrupt 33h
	mov	ah,35h			; get vector for mouse driver
	int	dos
	mov	ax,es
	cmp	ax,0f000h		; in ROM Bios?
	jae	crosin4			; ae = yes
	or	ax,bx			; check for no vector at all
	jz	crosin4			; z = none
	cmp	byte ptr es:[bx],0cfh	; is this an IRET instruction?
	je	crosin4			; e = yes, not our driver
	mov	ax,msgetbf		; get state buffer size (bytes) to BX
	int	mouse
	add	bx,15			; round up to next paragraph
	shr	bx,1
	shr	bx,1
	shr	bx,1
	shr	bx,1			; bytes to paragraphs
	mov	ah,alloc		; allocate memory
	int	dos
	jc	crosin4			; c = failed
	mov	mousebuf,ax		; save seg of the mouse status buffer
	mov	es,ax
	xor	dx,dx			; buffer address to es:dx
	mov	ax,msgetst		; get mouse state info
	int	mouse
	jnc	crosin2			; nc = presumed success
	call	mousefree		; return mouse save buffer
	jmp	short crosin4
crosin2:xor	cx,cx			; minimum horizontal/vertical motion
	mov	dx,xmax			; right most char
	add	dx,7			; right most dot (counted from 0)
	mov	ax,mshoriz		; set min/max horizontal motion
	int	mouse
	mov	dx,ybot			; max y (counted from 0)
	mov	ax,msvert		; set min/max vertical motion
	int	mouse

crosin4:mov	ax,linepat		; save line drawing pattern
	mov	ginlpsave,ax		; save it here
	mov	linepat,0ffffh		; reset line type to solid
	cmp	tekflg,tek_active+tek_sg; in DG special graphics mode?
	jne	crosin5			; e = yes, DG uses left bottom corner
	or	dgcross,1		; say crosshair is activiated
	and	dgcross,not 8		; and not invisible
	mov	xcross,0		; left side
	mov	ax,ybot
	sub	ax,charhgt		; skip status line
	mov	ycross,ax		; bottom
crosin5:call	crosdrawh		; draw initial crosshairs
	call	crosdrawv
	call	setmouse		; set mouse there too
	mov	crossactive,1		; say we are active
	ret
crossini endp

crossfin proc	near
	cmp	crossactive,0		; is crosshair material active?
	je	crossfin1		; e = no
	mov	crossactive,0
	call	crosdrawh		; erase crosshairs
	call	crosdrawv
	call	mousefree		; return mouse save buffer
	mov	ax,ginlpsave
	mov	linepat,ax		; restore line pattern
	mov	ttstate,offset tektxt	; go to TEKTXT next time
	mov	lastc,0			; clear last drawing coordinate flag
	or	status,txtmode		; set text mode in status byte
crossfin1:ret
crossfin endp

; Routine to trigger the crosshairs, wait for a key to be struck, and send
; the typed char (if printable ascii) plus four Tek encoded x,y position
; coordinates and then a carriage return.
; ax, cx, xcross, ycross operate in PC coordinates.
; For DG special graphics enter with scan code in AL
CROSHAIR PROC FAR
	cmp	tekflg,tek_active+tek_sg; in DG special graphics mode?
	jne	crosha1a		; ne = no, try regular Tek GIN mode
	test	dgcross,8		; should be on but has been removed?
	jz	crosha5			; z = no, cross is visible
	push	ax
	call	crosdrawv		; show vertical line
	call	crosdrawh
	pop	ax
	and	dgcross, not 8		; say cross is visible again
crosha5:test	dgcross,2		; track keyboard?
	jz	crosha1			; z = no, try mouse
	or	al,al			; anything in keyboard trapping buf?
	jnz	crosha4b		; process it as if key scan code
crosha1:test	dgcross,4		; track mouse?
	jnz	short crosha1c		; nz = yes, try the mouse
	jmp	croshaexit		; neither, do nothing
crosha1a:
	call	iseof			; is stdin at EOF?
	jc	crosha2			; c = yes, exit this mode now
	mov	dl,0ffh
	mov	ah,dconio		; read console
	int	dos
	jnz	crosha4			; nz = have char in AL
crosha1c:
	cmp	mousebuf,0		; is mouse driver active?
	je	croshaexit		; e = no
	mov	ax,msread		; mouse, read status and position
	int	mouse
	push	bx			; save button press information
	cmp	cx,xcross		; moved in x direction?
	je	crosm1			; e = no
	push	dx			; save mouse y
	call	crosdrawv		; erase vertical line
	call	crosdrawh
	mov	xcross,cx		; new position
	call	crosdrawv		; draw new vertical line
	call	crosdrawh
	pop	dx
crosm1:	cmp	dx,ycross		; moved in y direction?
	je	crosm2			; e = no
	call	crosdrawh		; erase horizontal line
	test	dgcross,1		; is DG crosshair active?
	jz	crosm3			; z = no
	call	crosdrawv
	mov	ax,ybot
	sub	ax,charhgt		; avoid status line
	cmp	dx,ax			; too far down?
	jbe	crosm3			; be = no
	mov	dx,ax			; stop here
crosm3:	mov	ycross,dx
	call	crosdrawh		; draw new horizontal line
	test	dgcross,1		; is DG crosshair active?
	jz	crosm3a			; z = no
	call	crosdrawv
crosm3a:call	setmouse		; set mouse there too
crosm2:	pop	bx
	test	bx,7			; mouse, was a button pressed?
	jz	croshaexit		; z = no
	cmp	tekflg,tek_active+tek_sg ; DG special graphics mode?
	je	crosm4			; e = yes, do POINT command
	mov	al,CR			; simulate a CR
	jmp	short crosha4
crosm4:	cmp	bl,1			; left button? (rt button is 2)
	je	crosm5			; e = yes
	cmp	dgd470mode,0		; D470 ANSI mode?
	jne	crosm4a			; ne = yes
	mov	al,RS			; send DG F1 code RS q for EXECUTE
	call	outmodem
	mov	al,'q'
	call	outmodem
	clc
	ret
crosm4a:mov	al,ESCAPE		; send ESC [ 001 z for DG F1
	call	outmodem
	mov	al,'['
	call	outmodem
	mov	al,'0'
	call	outmodem
	mov	al,'0'
	call	outmodem
	mov	al,'1'
	call	outmodem
	mov	al,'z'
	call	outmodem
	clc
	ret
crosm5:	call	dgcrossrpt		; send DG POINT command
croshaexit:clc				; c clear means not done yet
	ret

crosha4:or	al,al			; ascii or scan code returned
	jnz	arrow5			; nz = ascii char returned
	call	iseof			; is stdin at EOF?
	jc	crosha2			; c = yes, exit this mode now
	mov	ah,coninq		; read scan code
	int	dos
crosha4b:
	or	al,al			; Control-Break?
	jnz	crosha3			; nz = no, something else
crosha2:call	crosdrawh		; erase crosshairs
	call	crosdrawv
	mov	ax,ginlpsave
	mov	linepat,ax		; restore line pattern
	ret				; exit crosshairs mode

crosha3:cmp	al,homscn		; is it 'home'?
	jne	arrow1			; ne = no, try other keys
	call	crosdrawh		; erase crosshairs
	call	crosdrawv
	mov	ax,xmax			; right margin
	add	ax,7
	shr	ax,1			; central position
	mov	xcross,ax		; save PC coord for crosshair
	mov	ax,ybot			; last scan line
	shr	ax,1
	mov	ycross,ax		; this is the center of the screen
	call	crosdrawh		; draw home'd crosshairs
	call	crosdrawv
	call	setmouse		; set mouse there too
	jmp	croshaexit

arrow1:	cmp	al,lftarr		; left arrow?
	jne	arrow2			; ne = no
	mov	cx,-1			; left shift
	jmp	short xkeys
arrow2:	cmp	al,rgtarr		; right arrow?
	jne	arrow3			; ne = no
	mov	cx,1			; right shift
	jmp	short xkeys
arrow3:	cmp	al,uparr		; up arrow?
	jne	arrow4			; ne = no
	mov	cx,-1			; up shift
	jmp	short vertkey
arrow4:	cmp	al,dnarr		; down arrow?
	jne	badkey			; ne = no, ignore it
	mov	cx,1	      		; down shift
	jmp	short vertkey

badkey:	call	tekbeep			; tell user we don't understand
	jmp	croshaexit		; keep going

					; Shifted keys yield ascii keycodes
arrow5:	cmp	al,'C' and 1fh		; Control-C?
	je	crosha2			; e = yes, exit crosshairs mode now
	cmp	al,shlftarr		; shifted left arrow?
	jne	arrow6			; ne = no
	mov	cx,-10			; big left shift
	jmp	short xkeys
arrow6:	cmp	al,shrgtarr		; shifted right arrow?
	jne	arrow7			; ne = no
	mov	cx,10			; big right shift
	jmp	short xkeys
arrow7:	cmp	al,shuparr		; shifted up arrow?
	jne	arrow8			; ne = no
	mov	cx,-10			; big up shift
	jmp	short vertkey
arrow8:	cmp	al,shdnarr		; shifted down arrow?
	jne	charkey			; ne = no, send this key as is
	mov	cx,10			; big down shift
	jmp	short vertkey

xkeys:	call	crosdrawv		; erase vertical line
	call	crosdrawh
	add	cx,xcross		; add increment
	jns	noxc			; gone too far negative?
	xor	cx,cx			; s = yes, make it 0
noxc:	mov	ax,xmax
	add	ax,7			; right most dot
	cmp	cx,ax			; too far right?
	jb	xdraw9			; b = no
	mov	cx,ax			; yes, make it the right
xdraw9: mov	xcross,cx		; new x value for cross hairs
	call	crosdrawv		; draw new vertical line
	call	crosdrawh

	call	setmouse		; set mouse there too
	jmp	croshaexit
     
vertkey:call	crosdrawh		; erase horizontal line
	call	crosdrawv
	add	cx,ycross		; adjust cx
	jns	noyc			; gone negative?
	xor	cx,cx			; s = yes then make 0
noyc:	test	dgcross,1		; is DG crosshair active?
	jz	noyc2			; z = no
	push	ax
	mov	ax,ybot
	sub	ax,charhgt		; avoid status line
	cmp	cx,ax			; too far down?
	jbe	noyc1			; be = no
	mov	cx,ax			; stop here
noyc1:	pop	ax

noyc2:	cmp	cx,ybot			; too high?
	jb	yok			; b = no
	mov	cx,ybot			; make it maximum
yok:	mov	ycross,cx		; save new y crosshair
	call	crosdrawh		; draw new vertical line
	call	crosdrawv
	call	setmouse		; set mouse there too
	jmp	croshaexit
     
charkey:call	outmodem		; send the break character
	mov	ax,xcross		; set beam to xcross,ycross
	mov	bx,ycross		; must convert to Tek coordinates
	call	pctotek			; scale from PC screen coord to Tek
	push	ax			; save around drawing
	push	bx
	xor	cx,cx			; just a move
	call	tekdraw			; moveto ax,bx in Tek coord
	pop	bx			; recover Tek y
	pop	ax			; recover Tek x
	call	sendpos			; send position report to host
	call	crossfin		; finish up
	STC				; set carry to say end of GIN mode
	ret
CROSHAIR ENDP
     
; draw vertical crosshair line at x = xcross, xor with picture
crosdrawv proc near
	push	bp
	push	x_coord
	push	y_coord
	mov	al,ccode		; save current pixel op
	push	ax
	push	cx
	mov	si,xcross		; move to x= xcross
	mov	ax,si			; ending x coord
	xor	di,di			; starting y coord
	mov	bx,ybot			; bottom y coord
	test	dgcross,1		; DG cursor?
	jz	crosdrawv2		; z = no
	sub	bx,charhgt		; omit status line
	test	flags.vtflg,ttd470	; D470 short cursor
	jz	crosdrawv2		; z = no, use D463 large cursor
	mov	cx,charhgt
	shr	cx,1			; half a cell
	mov	di,ycross		; D470 start at top of char cell
	mov	bx,di
	sub	bx,cx
	jnc	crosdrawv1		; nc = in bounds
	xor	bx,bx			; clip at top
crosdrawv1:
	add	di,cx			; down half a cell
	mov	cx,ybot
	sub	cx,charhgt		; omit status line
	dec	cx
	cmp	di,cx			; too far down?
	jbe	crosdrawv2		; be = no
	mov	di,cx			; clip at bottom
crosdrawv2:mov	cl,pixxor		; xor pixels
	call	line			; draw vertical
	pop	cx
	pop	ax			; recover current pixel op
	mov	ccode,al		; restore it
	pop	y_coord
	pop	x_coord
	pop	bp
	ret
crosdrawv endp

; draw horizontal crosshair line at y = ycross, xor with picture
crosdrawh proc near
	push	bp
	push	x_coord
	push	y_coord
	mov	al,ccode		; save current pixel op
	push	ax
	push	cx
	mov	di,ycross		; set y = ycross
	mov	bx,di			; ending y
	xor	si,si			; starting x
	mov	ax,xmax
	add	ax,7
	test	dgcross,1		; DG cross?
	jz	crosdrawh1		; z = no
	test	flags.vtflg,ttd470	; D470 short cursor
	jz	crosdrawh1		; z = no, use D463 large cursor
	mov	si,xcross		; start x
	mov	ax,si
	sub	si,7
	add	ax,7			; width
crosdrawh1:
	mov	cl,pixxor		; set XOR code
	call	line			; draw to (xcross+12, ycross)
	pop	cx
	pop	ax			; recover current pixel op
	mov	ccode,al		; restore it
	pop	y_coord
	pop	x_coord
	pop	bp
	ret
crosdrawh endp
		  
; Set mouse cursor position to xcross,ycross. Ignored if no active mouse.
setmouse proc	near
	cmp	mousebuf,0		; is mouse driver is active?
	je	setmou1			; e = no
	mov	cx,xcross
	mov	dx,ycross
	mov	ax,mswrite		; set mouse position
	int	mouse
setmou1:ret
setmouse endp

; Return DOS memory allocated as mouse status buffer
mousefree proc	near
	push	es
	mov	ax,mousebuf		; seg of mouse save buffer
	mov	es,ax			; allocated segment
	mov	ah,freemem		; free it
	int	dos
	mov	mousebuf,0		; clear mouse presence too
	pop	es
	ret
mousefree endp

; Return mouse state and free state save buffer
mousexit proc	near
	mov	ax,mousebuf		; segment of state save buffer
	or	ax,ax			; is mouse driver active?
	jz	mousex1			; z = no
	push	es
	mov	es,ax
	xor	dx,dx			; address is in es:dx
	mov	ax,mssetst		; set mouse driver state from buffer
	int	mouse
	pop	es
	call	mousefree		; return memory to DOS
mousex1:ret
mousexit endp

; SENDPOS sends position of cross-hairs to the host.
; ax has Tek X and bx has Tek Y coord of center of crosshair	 
SENDPOS PROC NEAR
	push	bx			; preserve register
	call	sendxy			; send x coord
	pop	ax
	call	sendxy			; send y coord
	mov	al,cr			; follow up with cr
	call	outmodem
	ret
SENDPOS ENDP

; SENDXY sends value of ax as Tek encoded bytes
; ax is in Tek coordinates     
SENDXY	PROC	NEAR
	shl	ax,1
	shl	ax,1			; move all but lower 5 bits to ah
	shl	ax,1
	shr	al,1
	shr	al,1			; move low five bits to low 5 bits
	shr	al,1
	or	ah,20h			; make it a printing char as per TEK
	xchg	al,ah			; send high 5 bits first
	call	outmodem
	xchg	al,ah			; then low five bits
	or	al,20h
	call	outmodem
	xchg	ah,al			; al is first sent byte
	ret
SENDXY	ENDP
     
     
SENDID	PROC NEAR			; pretend VT340
	mov	bx,offset tekid		; VT320 identification string
sndid1: mov	al,[bx]			; get char from sequence
	or	al,al			; end of sequence?
	jz	sndid0			; z = yes, return
	call	outmodem		; send it out the port
	inc	bx
	jmp	sndid1
sndid0:	ret
SENDID	ENDP
     
; SENDSTAT - send status and cursor position to host
     
SENDSTAT PROC NEAR
	mov	al,STATUS		; get tek status
	or	al,20h			; make it printable
	call	OUTMODEM		; and send it
	mov	ax,oldx			; now send x coordinate (oldx is Tek)
	call	SENDXY
	mov	ax,oldy			; and y coordinate (oldy is Tek coord)
	call	SENDXY
	mov	al,cr			; end with a cr
	call	OUTMODEM
	ret
SENDSTAT ENDP
     

; Convert X and Y from PC coordinates to Tek coordinates. AX = X, BX = Y
; for both input and output.
pctotek	proc	near
	mul	xdiv			; scale from PC screen coord to Tek
	div	xmult
	xchg	bx,ax			; save Tek x coord in bx
	neg	ax			; y axis. Turn upside down for Tek
	add	ax,ybot
	mul	ydiv			; scale y from PC screen coord to Tek
	div	ymult
	xchg	ax,bx			; ax has X, bx has Y in Tek coords
	ret
pctotek	endp

; Routine to output character in AL to the screen.

OUTSCRN PROC NEAR			; put one character to the screen
	cmp	rxtable+256,0		; translation turned off?
	je	outscr2			; e = yes, no translation
	push	bx
	mov	bx,offset rxtable	; address of translate table
	xlatb				; new char is in al
	and	al,7fh			; retain only lower seven bits
	pop	bx

outscr2:mov	ah,ccode		; assume transparent chars
	push	ax			; save ccode
	mov	ccode,pixfor		; write in foreground
	cmp	chcontrol,0		; transparent char writing?
	je	outscr3			; e = yes
	or	ccode,pixbak		; write background dots too
outscr3:call	remcursor		; remove text cursor symbol
	cmp	al,' '			; printable?
	ja	outscr6			; a = yes
	je	outscr5			; e = space
outscr4:call	putctrl			; handle controls at putctrl
	jmp	short outscr9
outscr5:cmp	spcontrol,0		; destructive space?
	jne	outscr6			; ne = yes, do actual writing
	cmp	chcontrol,0		; write transparently?
	jne	outscr6			; ne = no, opaque, draw the char
	call	testfull		; check on full screen
	call	incx			; move to next char position
	jmp	short outscr9

outscr6:call	testfull		; check for full screen
	sub	al,' '			; Tek chars are biased to start at ' '
	call	putc			; routine to draw characters
outscr9:call	setcursor		; draw text cursor symbol
	pop	ax			; recover ccode
	mov	ccode,ah
	ret
OUTSCRN ENDP

; Display char in AL, normal attributes in AH, extended in CL, 
; text screen cursor at DX 
ttxtchr proc	far
	push	cx
	push	dx
	push	word ptr fontlptr
	push	word ptr fontlptr+2
	push	word ptr fontrptr
	push	word ptr fontrptr+2
	mov	bl,dh			; get line row
	xor	bh,bh
	mov	charwidth,8		; use regular width font
	test	dgwindcomp[bx],1	; regular width chars?
	jz	ttxtchr1		; z = yes
	cmp	plotptr,offset pltega	; ega dot plot routine?
	jne	ttxtchr1		; no, use 8 wide
	mov	charwidth,5		; use compressed font
	mov	word ptr fontlptr,offset fivedot
	mov	word ptr fontlptr+2,seg fivedot
	mov	word ptr fontrptr+2,seg fivedot
	mov	word ptr fontrptr,offset gr437
	cmp	vtcpage,437		; using CP437?
	je	ttxtchr1      		; e = yes, use GR437 slim font
	mov	word ptr fontrptr,offset gr850 ; GR850 slim font
ttxtchr1:test	cl,0f8h			; soft font?
	jz	ttxtchr1a		; z = no
	push	bx
	shr	cl,1				; remove nonsoft attribute
	shr	cl,1
	shr	cl,1				; extract char set ident
	dec	cl				; count soft fonts from zero
	cmp	cl,30				; in range?
	ja	ttxtchr1b			; a = no
	shl	cl,1				; convert to word index
	mov	bl,cl
	xor	bh,bh
	mov	bx,softlist[bx]			; list of segs for fonts
	or	bx,bx				; segment defined?
	jz	ttxtchr1b			; z = no
	mov	word ptr fontrptr+2,bx		; update font pointer
	mov	word ptr fontlptr+2,bx		; segments
	xor	bx,bx
	mov	word ptr fontrptr,bx		; offset is 0 for malloc'd
	mov	word ptr fontlptr,bx
ttxtchr1b:
	mov	charwidth,8
	pop	bx
ttxtchr1a:
	mov	ccode,pixfor+pixbak
	mov	gfcol,ah		; foreground color
	and	gfcol,0fh		; lower four bits
	cmp	plotptr,offset pltega	; ega dot plot routine?
	je	ttxtchr2		; e = yes
	xor	ah,ah			; no background on monochrome systems
	and	al,7fh			; no high bit
	sub	al,' '			; font begins with space
	jnc	ttxtchr2		; nc = not a control
	xor	al,al			; omit controls
ttxtchr2:mov	cl,4
	shr	ah,cl
	and	ah,0fh
	mov	gbcol,ah		; background color
	push	ax
	mov	ax,charwidth
	mul	dl			; compute scan column
	mov	cx,xmax
	add	cx,8			; right most dot
	sub	cx,charwidth		; right most char cell
	cmp	cx,ax			; char still on screen?
	jc	ttxtchr2a		; c = out of range
	mov	x_coord,ax
ttxtchr2a:pop	ax
	jc	ttxtchr5		; c = out of range
	push	ax
	mov	ax,charhgt
	inc	dh			; count text lines from 1
	mul	dh			; compute scan row
	dec	ax			; count scan lines from zero
	mov	y_coord,ax
	pop	ax
	mov	cursorst,0		; say cursor is off (is overwritten)
	test	dgcross,1		; is cross hair on?
	jz	ttxtchr3		; z = no
	test	dgcross,8		; is cross hair invisible?
	jnz	ttxtchr3		; nz = yes
	push	es
	push	si
	push	dx
	push	ax
	call	crosdrawh		; remove present crosshairs
	call	crosdrawv
	or	dgcross,8		; say cross is on but invisible
	pop	ax
	pop	dx
	pop	si
	pop	es
ttxtchr3:call	putc		; draw the char, cursor done separately later
ttxtchr5:pop	word ptr fontrptr+2
	pop	word ptr fontrptr
	pop	word ptr fontlptr+2
	pop	word ptr fontlptr
	pop	dx
	pop	cx
	ret
ttxtchr endp

; Allocate space for a soft character set (128 * 14 = 1792 bytes).
; Enter with AL holding set number, 101..131. Put segment of memory in
; array softlist, softptr holding same, and return carry clear.
; Fail with carry set.
mksoftspace proc far
	push	bx
	mov	bl,al			; get set ident
	sub	bl,101			; count this from zero
	cmp	bl,30			; highest set subscript
	jbe	mksofts1		; be = in range
	pop	bx
	stc				; carry for failure
	ret
mksofts1:xor	bh,bh
	shl	bx,1			; count words
	mov	ax,softlist[bx]		; segment
	or	ax,ax			; segment, allocated yet?
	jz	mksofts2		; z = no, do so now
	mov	softptr,ax		; point at the existing area
	pop	bx
	clc
	ret
mksofts2:push	bx			; save softlist index
	mov	bx,(128*14)/16		; paragraphs wanted, 128*14 bytes
	mov	ah,alloc		; allocate memory
	int	dos
	pop	bx
	jnc	mksofts3		; nc = success
	pop	bx
	ret				; return carry set for failure
mksofts3:mov	softlist[bx],ax		; save segment
	mov	softptr,ax		; point at new segment
	push	es
	push	di
	mov	es,ax			; segment
	xor	di,di			; offset
	cld
	mov	cx,128*14/2		; words
	xor	ax,ax
	rep	stosw			; clear the space
	pop	di
	pop	es
	pop	bx
	clc
	ret
mksoftspace endp

; Free memory allocated by mksoftspace, preserve ax
clearsoft proc	far
	push	ax
	push	si
	push	es
	mov	cx,31			; number of soft fonts
	mov	si,offset softlist
clearsoft1:
	xor	ax,ax
	xchg	ax,[si]			; get seg of soft font, clear word
	add	si,2			; for next word
	or	ax,ax			; allocated?
	jz	clearsoft2		; z = no
	mov	es,ax
	mov	ah,freemem		; free that memory
	int	dos
clearsoft2:
	loop	clearsoft1
	pop	es
	pop	si
	pop	ax
	ret
clearsoft endp

; Test if screen is full. If full sound beep, wait for any keyboard input
; (skip kbd reading if stdin is redirected).
testfull proc	near
	push	ax
	mov	ax,x_coord
	cmp	ax,xmax			; at end of the line?
	jbe	testfu1			; be = no
	mov	x_coord,0		; wrap to next line
	mov	ax,charhgt
	add	y_coord,ax		; next row
testfu1:mov	ax,ybot			; get last scan line
	inc	ax			; number of scan lines
	cmp	ax,y_coord		; minus where char bottom needs to go
	jae	testfu3			; ae = enough space for char
	call	tekbeep			; tell the user we are waiting
	call	iseof			; EOF on redirected stdin?
	jc	testfu2			; c = yes, proceed anyway
	mov	ah,coninq		; read keyboad via DOS
	int	dos			; wait for keystroke
	or	al,al			; scan code being returned?
	jne	testfu2			; ne = no
	mov	ah,coninq		; clear away scan code too
	int	dos
testfu2:call	tekcls			; clear the screen
	mov	x_coord,0
	mov	y_coord,0
testfu3:pop	ax			; recover current character
	ret
testfull endp

; Draw text cursor symbol by xor-ing. Sets xcursor,ycursor to symbol position.
teksetcursor proc FAR
	call	remcursor		; remove old cursor
	test	atctype,4		; is cursor to be invisible?
	jz	teksetcur1		; z = no
	ret
teksetcur1:
	push	ax
	mov	ax,charhgt
	inc	dh			; count text rows from 1
	mul	dh			; compute scan row
	dec	dh			; restore DX
	dec	ax			; count scan rows from 0
	mov	y_coord,ax
	push	bx
	mov	bl,dh			; get line row
	xor	bh,bh
	mov	ax,8			; use regular width font
	cmp	dgwindcomp[bx],0	; regular width chars?
	pop	bx
	je	teksetcur3		; e = yes
	cmp	plotptr,offset pltega	; ega dot plot routine?
	jne	teksetcur3		; no, use 8 wide
	mov	ax,5			; use compressed font
teksetcur3:
	mov	charwidth,ax
	mul	dl			; compute scan column
	push	cx
	mov	cx,xmax
	add	cx,8
	sub	cx,charwidth
	cmp	ax,cx
	jbe	teksetcur4		; be = in range
	mov	ax,cx
teksetcur4:pop	cx
	mov	x_coord,ax
	pop	ax
	call	setcursor
	ret
teksetcursor endp

setcursor proc	near
	cmp	tekcursor,0		; suppress cursor?
	je	setcurs0		; e = yes
	cmp	cursorst,0		; is cursor off now?
	jne	setcurs0		; ne = no
	cmp	putc,offset mputc	; pure mono character display routine?
	jne	setcurs1		; ne = no
setcurs0:ret				; no cursor for pure mono
setcurs1:push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	es
	mov	bh,gbcol
	mov	bl,gfcol
	push	bx
	mov	bh,ccode		; current drawing code, save it
	push	bx			; save ccode
	push	x_coord			; save current operating point (PC)
	push	y_coord
	mov	ax,x_coord		; where cursor symbol starts, X axis
	mov	bx,xmax
	add	bx,8			; real screen width
	sub	bx,charwidth		; where last char could go
	cmp	ax,bx			; beyond last character position?
	jbe	setcurs2		; be = no
	mov	ax,bx			; yes, stop at last, for wrapping
setcurs2:mov	xcursor,ax		; remember where we drew symbol
	mov	x_coord,ax		; set this for drawing the symbol
	mov	ax,y_coord
	mov	ycursor,ax
	push	word ptr fontlptr	; save active font GLeft pointer
	push	word ptr fontlptr+2
	mov	ax,charwidth
	mov	curcharw,ax		; current cursor width
	mov	ax,seg defcurpat	; default Tek cursor pattern, seg
	mov	word ptr fontlptr+2,ax	; point to us
	mov	ax,offset defcurpat 	; default Tek cursor pattern
	xor	bl,bl			; initial (and only char in font)
	test	tekflg,tek_sg		; special graphics?
	jz	setcurs4		; z = no, use default
	call	dgsetcol
	and	al,0fh			; retain foreground dots
	mov	gfcol,al		; set foreground coloring
	mov	cl,atctype		; active cursor type
	mov	dgctype,cl		; type of cursor being written
	xor	ch,ch
	jcxz	setcurs5		; z = nothing to do
	and	cl,3			; visible cursor kinds, two bits
	mov	ax,offset dgcurbpat	; block pattern
	cmp	cl,1			; underline?
	ja	setcurs3		; a = no, block
	mov	ax,offset dgcurupat	; use DG cursor underline pattern
setcurs3:cmp	plotptr,offset pltega	; ega dot plot routine?
	je	setcurs4		; e = yes, else CGA style
	add	ax,5			; use lower lines of 14L pattern
setcurs4:mov	word ptr fontlptr,ax	; set offset of pattern
	mov	al,gfcol		; get foreground coloring
	xor	ah,ah
	mov	gbcol,ah		; no change to background
	mov	curgcol,ax		; save it for cursor removal
	mov	ccode,pixxor		; xor with foreground coloring
	mov	al,bl			; symbol code to draw, first in font
	call	putc			; routine to draw characters
setcurs5:
	pop	word ptr fontlptr+2
	pop	word ptr fontlptr
	pop	y_coord
	pop	x_coord
	pop	bx			; recover ccode
	mov	ccode,bh
	mov	cursorst,1		; say cursor is on
	pop	bx
	mov	gbcol,bh
	mov	gfcol,bl
	pop	es
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
setcursor endp

; Remove text cursor symbol by xor-ing with itself. Xcursor, ycursor is the
; PC coord of the cursor symbol.
tekremcursor proc FAR
	call	remcursor
	ret
tekremcursor endp

remcursor proc	near
	cmp	tekcursor,0		; suppress cursor?
	je	remcurs0		; e = yes
	cmp	cursorst,0		; is cursor off now?
	je	remcurs0		; e = yes
	cmp	putc,offset mputc	; pure mono character display routine?
	jne	remcurs1		; ne = no
remcurs0:ret				; no cursor for pure mono
remcurs1:push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	es
	mov	bh,gbcol
	mov	bl,gfcol
	push	bx
	mov	bh,ccode		; current drawing code, save it
	push	bx			; save ccode
	push	x_coord			; save current operating point (PC)
	push	y_coord
	mov	ax,xcursor		; where last cursor was written
	mov	x_coord,ax		; setup for xor writing to remove it
	mov	ax,ycursor
	mov	y_coord,ax
	push	word ptr fontlptr
	push	word ptr fontlptr+2
	push	charwidth
	mov	ah,gbcol
	mov	al,gfcol
	push	ax
	mov	ax,curcharw		; get old cursor char width
	mov	charwidth,ax
	mov	ax,curgcol		; get old cursor colors
	mov	gfcol,al		; set it for removal
	mov	ax,seg defcurpat
	mov	word ptr fontlptr+2,ax	; point to our data segment
	mov	ax,offset defcurpat 	; default cursor pattern
	xor	bl,bl			; initial (and only char in font)
	test	tekflg,tek_sg		; special graphics?
	jz	remcurs4		; z = no, use default
	mov	cl,dgctype		; last used emulation cursor type
	and	cl,3			; keep just two lower bits
	xchg	dgctype,cl		; update cursor type
	xor	ch,ch
	jcxz	remcurs5		; z = nothing to do
	mov	ax,offset dgcurbpat	; use block pattern
	cmp	cl,2			; last used cursor type
	je	remcurs3		; 0/4 is no cursor, 1=uline, 2=block
	mov	ax,offset dgcurupat	; use DG cursor underline pattern
remcurs3:cmp	plotptr,offset pltega	; ega dot plot routine?
	je	remcurs4		; e = yes, else CGA 8x8 style
	add	ax,5			; use lower scan lines for mono
remcurs4:mov	word ptr fontlptr,ax
	mov	ccode,pixxor		; xor with foreground coloring
	mov	gbcol,0			; no change to background
	mov	al,bl			; character from font
	call	putc			; routine to draw characters
remcurs5:
	pop	ax
	mov	gbcol,ah
	mov	gfcol,al
	pop	charwidth
	pop	word ptr fontlptr+2
	pop	word ptr fontlptr
	pop	y_coord
	pop	x_coord
	pop	bx			; recover ccode
	mov	ccode,bh
	mov	cursorst,0		; say cursor is off
	pop	bx
	mov	gbcol,bh
	mov	gfcol,bl
	pop	es
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
remcursor endp
      
; TEKCLS routine to clear the screen.
; Entry point tekcls1 clears screen without resetting current point.	 
TEKCLS	PROC	NEAR
	test	tekflg,tek_active	; Tek mode active yet?
	jnz	tekcls0			; nz = yes
	ret				; else ignore this call
tekcls0:mov	x_coord,0		; starting text coordinates
	mov	y_coord,0
	mov	oldx,0			; assumed cursor starting location
	mov	oldy,maxteky		;  top right corner (Tek coord)
	mov	scalex,0		; clear last plotted point (PC coord)
	mov	scaley,0
	mov	lastc,0			; last parsed x,y coordinate
	mov	visible,0		; make lines invisible
	mov	bypass,0		; clear bypass condition
	mov	ttstate,offset tektxt	; do displayable text
	mov	prestate,offset tektxt
tekcls1:push	ax			; save registers
	push	cx
	mov	bl,ccode		; save pixel op code
	push	bx
	cmp	graph_mode,hercules	; Hercules?
	jne	tekclsw			; ne = no
	call	hgraf			; set Hercules board to Graphics mode
	jmp	tekcls7

tekclsw:cmp	graph_mode,wyse700	; Wyse 700?
	jne	tekcls2			; ne = no
	call	wygraf			; set board to Graphics mode & cls
	jmp	tekcls7

tekcls2:xor	di,di			; point to start of screen, di=row
	mov	ccode,pixbak		; write in background
	call	psetup			; setup graphics routine and es:di
	mov	cx,4000h		; CGA, 200 lines times 80 bytes worth
	cmp	graph_mode,cga		; cga?
	je	tekcls3			; e = yes
	mov	cx,8000h		; Olivetti, 400 lines times 80 bytes
	cmp	graph_mode,olivetti	; AT&T-Olivetti?
	je	tekcls3			; e = yes
	cmp	graph_mode,toshiba	; Toshiba?
	je	tekcls3			; e = yes
	cmp	graph_mode,vaxmate	; VAXmate?
	jne	tekcls4			; ne = no
tekcls3:cld				; clear screen directly of text stuff
	xor	ax,ax
	test	gbcol,7			; background is dark?
	jz	tekcls3a		; z = yes
	mov	ax,0ffffh		; light, set all pixels
tekcls3a:shr	cx,1			; do words
	rep	stosw			; clear the words
	jmp	short tekcls7

tekcls4:cmp	graph_mode,ega		; EGA?
	je	tekcls5			; e = yes
	cmp	graph_mode,monoega	; EGA with mono display?
	je	tekcls5			; e = yes
	cmp	graph_mode,colorega	; EGA with medium resolution monitor?
	je	tekcls5			; e = yes
	jmp	short tekcls6		; else use Bios

tekcls5:				; EGA clear screen quickly
	mov	ax,0ff08h		; set all 8 bits to be changed
	call	ega_gc			; set bit mask register accordingly
	mov	ax,0003h		; data rotate reg, write unmodified
	call	ega_gc			; 
	mov	cx,ybot			; last scan line
	inc	cx			; number of scan lines
	mov	ax,xmax			; line length - 8 dots
	add	ax,8			; nominal char width
	shr	ax,1			; divide by 8 bits / byte
	shr	ax,1
	shr	ax,1
	shr	ax,1			; divide by two bytes / word
	mul	cx
	mov	cx,ax			; cx = number of words to clear
	push	cx
	cmp	tekflg,tek_active+tek_sg; in special graphics mode?
	jne	tekcls5a		; ne = no, try regular Tek GIN mode
	test	flags.vtflg,ttd463+ttd470+ttd217 ; D463/D470/D217?
	jz	tekcls5a		; z = no
	call	dgsetcol
	jmp	short tekcls5b
tekcls5a:call	fixcolor		; fix colors first, if req'd
tekcls5b:pop	cx
	mov	al,gbcol		; select background colour
	mov	ah,al			; copy for word stores
	cld
	rep	stosw			; write backgound color
	jmp	short tekcls7

tekcls6:push	es			; clear screen by scrolling up
	call	tcmblnk			; clear screen, for Environments
	pop	es

tekcls7:xor	si,si			; starting x  (in case screen is
	xor	di,di			; starting y	cleared by user)
	pop	bx
	mov	ccode,bl		; restore pixel op code
	mov	xcursor,0		; position of text cursor symbol
	mov	ycursor,0
	mov	cursorst,0		; cursor has been erased
	call	setcursor		; draw text cursor symbol
	pop	cx
	pop	ax
	ret
TEKCLS	ENDP
     
; Routine to draw a line on the screen, using TEKTRONIX coordinates.
; X coordinate in AX, 0=left edge of screen, 1023=right edge of screen.
; Y coordinate in BX, 0=bottom of screen, 779=top of screen.
; CL=0 - invisible move, else draw in foreground colors
     
TEKDRAW PROC NEAR
	mov	si,scalex		; get old x already scaled
	mov	di,scaley		; get old y already scaled
	call	scale 			; scale new end point to PC coords
	or	cl,cl			; invisible drawing?
	jz	moveto			; z = just move, skip draw part
	mov	cl,pixfor		; draw in foreground color
	call	LINE			; draw the line
moveto:	mov	x_coord,ax		; update text coordinates to match
	mov	y_coord,bx		;  last drawn point
	ret
TEKDRAW ENDP
     
; Scale TEKTRONIX coordinates to the currently defined screen coordinates
; AX holds X axis, BX holds Y axis. Both are changed from Tektronix coord
; to PC coordinates by this procedure.
SCALE	PROC	NEAR
	push	dx
	push	si
	cmp	ax,1023			; limit x axis
	jbe	scale1			; be = not out of bounds
	mov	ax,1023
scale1:	cmp	bx,779			; limit y axix
	jbe	scale2			; be = not out of bounds
	mov	bx,779
scale2:	mov	oldx,ax			; save current Tek x for next draw
	mov	oldy,bx			; save current Tek y for next draw
	mul	xmult			; scale x-coord
	mov	si,xdiv			; get the divisor
	shr	si,1			; halve it
	add	ax,si			; add in - to round to nearest integer
	adc	dx,0
	div	xdiv
	push	ax
	mov	ax,bx
	mul	ymult			; scale y-coord
	mov	si,ydiv			; get divisor
	shr	si,1			; halve it
	add	ax,si			; add in - to round to nearest integer
	adc	dx,0
	div	ydiv
	mov	bx,ybot
	sub	bx,ax			; put new Y in right reg
	jns	scale3			; ns = not too far
	xor	bx,bx
scale3:	pop	ax			; put new X in right reg
	mov	scalex,ax		; save scaled values
	mov	scaley,bx
	pop	si
	pop	dx
	ret
SCALE	ENDP
      
; LINE	Subroutine to plot a line with endpoints in AX,BX and SI,DI.
;	fast line drawing routine for the IBM PC
;
; Registers at CALL
; -----------------
; SI=Start X coord, all in PC coordinates
; DI=Start Y coord
; AX=End X coord
; BX=End Y coord
; CCODE=CL=pixel operation code
; LINEPAT=BP= line drawing pattern (is changed here by rotation)
; registers are all unchanged
     
LINE	PROC	NEAR
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	es
	mov	bp,linepat		; store active line pattern word in BP
	mov	dl,ccode		; existing pixel op code
	push	dx			; save around line drawing
	mov	ccode,cl	; save color code in ccode for use by plot()
			; first get coord to achieve increasing x; deltax >= 0
	sub	ax,si			; deltax = x2 - x1
	jge	line1			; ge = going to the right, as desired
	neg	ax			; make deltax non-negative
	sub	si,ax			; swap the x coordinates
	xchg	bx,di			; swap the y coordinates too
				; second, compute deltay. ax = deltax, si = x1
line1:	sub	bx,di			; deltay = y2 - y1
	call	psetup			; setup display adapter for plotting
					;  and setup es:di to screen memory
  ; Choose algorithm based on |deltay| < |deltax| (use shallow) else steep.
  ; We arrange matters such that both deltas are non-negative.
	or	bx,bx			; deltay
	jge	line2			; ge = non-negative
	neg	linelen
	neg	bx			; make non-negative
line2:	cmp	bx,ax			; |deltay| versus |deltax|
	jbe	shallow			; be = do shallow algorithm
	jmp	steep			; else do steep algorithm

	; shallow algorithm, move along x, di=y1, bx=deltay, si=x1, ax=deltax
shallow:add	bx,bx			; bx = 2*deltay
	mov	cx,ax			; cx = number of steps (deltax here)
	inc	cx			; loop dec's cx before testing
	mov	dx,bx			; dx holds error
	sub	dx,ax			; error = 2*deltay - deltax
	add	ax,ax			; ax = 2*|deltax|
shal1:	call	plotptr			; Plot(x,y)
	or	dx,dx
	jle	shal2			; le =	 error <= 0
	call	pincy			; increment y by one scan line
	sub	dx,ax			; error = error - 2*deltax
shal2:	add	dx,bx			; error = error + 2*deltay
	inc	si			; x = next dot right
	loop	shal1
	jmp	short plotex

	; steep algorithm, move along y, di=y1, bx=deltay, si=x1, ax=deltax
steep:	add	ax,ax			; ax = 2*deltax
	mov	dx,ax			; dx holds error
	sub	dx,bx			; error = 2*deltax (ax) - deltay (bx)
	mov	cx,bx			; cx = number of steps (deltay here)
	inc	cx			; loop dec's cx before testing
	add	bx,bx			; bx = 2*|deltay|
stee1:	call	plotptr			; Plot(x,y) x = ax, y = di
	or	dx,dx
	jle	stee2			; le  error <= 0
	inc	si			; x = next dot right
	sub	dx,bx			; error = error - 2*deltay
stee2:	add	dx,ax			; error = error + 2*deltax
	call	pincy			; increment y
	loop	stee1
;;;	jmp	plotex

plotex:	pop	dx			; dl has orginal pixel op
	mov	ccode,dl		; restore it
	pop	es
	pop	di
	pop	si
	pop	dx			; restore the world
	pop	cx
	pop	bx
	pop	ax
	ret
LINE	ENDP

; Draw a rectangle.
;  lower left corner: x = param[0], y = param[2], Tek coordinates
;  distance: dx = param[4], dy = param[6], Tek coordinates, all positive
rectdraw proc	near
	push	x_coord
	push	y_coord
	mov	ax,param[0]		; lower left corner is start, x part
	mov	bx,param[2]		; y part
	push	ax			; x0
	push	bx			; y0
	xor	cl,cl			; moveto
	call	tekdraw
	pop	bx
	pop	ax
	add	bx,param[6]		; y0 + dy
	mov	cl,1			; draw x0,y0  to  x0,y0+dy
	push	ax
	push	bx
	call	tekdraw
	pop	bx
	pop	ax
	add	ax,param[4]		; x0+dx
	mov	cl,1			; draw x0,y0+dy  to  x0+dx,y0+dy
	push	ax
	call	tekdraw
	pop	ax
	mov	bx,param[2]		; y0
	push	bx
	mov	cl,1
	call	tekdraw
	pop	bx
	mov	ax,param[0]		; x0
	mov	cl,1
	call	tekdraw			; complete the box
	pop	y_coord
	pop	x_coord
	ret
rectdraw endp

; Fill a rectangle with a given pattern.
;  lower left corner: x = param[0], y = param[2], Tek coordinates
;  distance: dx = param[4], dy = param[6], Tek coordinates, all positive
;  fill pattern = param[8]
rectfil	proc	near
	push	oldx
	push	oldy			; save regular point/line old coords
	mov	ax,param		; get Tek X coord of lower left corner
	mov	bx,param[2]		; get Tek Y coord
	call	scale			; convert to PC in ax,bx, scalex/y
	mov	rectx1,ax		; lower left corner in PC coords
	mov	recty1,bx
	mov	ax,param		; convert ending points, start Tek X
	add	ax,param[4]		; Tek X + DX
	mov	bx,param[2]		; start Tek Y
	add	bx,param[6]		; Tek Y + DY
	call	scale
	pop	oldy
	pop	oldx
	mov	rectx2,ax		; upper right corner PC X coord
	mov	recty2,bx		; upper right corner PC Y coord
	mov	si,rectx1		; starting x PC coord to si
	mov	di,recty2		; starting y PC coord to di
	mov	cx,recty1		; plotting from top down on screen
	sub	cx,bx			; cx = # scan lines - 1
	mov	numlines,cx		; remember here
	mov	bx,param[8]		; fill pattern number
	or	bx,bx			; zero?
	jz	rectfi1			; z = yes, use current pointer
	cmp	bx,numfil		; pattern number is too large?
	ja	rectfi1			; a = yes, use current pointer
	dec	bx			; count internally from 0
	shl	bx,1			; make this a word pointer
	mov	bx,fillist[bx]		; get pointer to pattern
	mov	fillptr,bx		; remember it here
rectfi1:mov	cx,rectx2		; ending x coord
	sub	cx,rectx1		; number of horizontal pixels - 1
	inc	cx			; number of horizontal pixels
	call	psetup			; set up dsp and di to screen offset
			; di points to whole byte, do bits in byte in gfplot
rectfi2:push	bx
 	mov	bx,recty1		; lower screen y (larger value)
	sub	bx,numlines		; alignment: global screen sync
	and	bx,7			; modulo 8
	add	bx,fillptr		; offset of fill pattern start
	mov	bl,[bx]			; pattern byte
	mov	fill,bl			; save here for gfplot
	pop	bx
	call	gfplot			; line fill routine
	call	pincy			; next line
	dec	numlines
	jns	rectfi2			; ns = more to do
	ret
rectfil	endp

; Data General D463/D470/D217 plotting routines

; RS G B turn on DG crosshairs
dgcrosson proc	far
	test	dgcross,1		; on now?
	jnz	dgcroson1		; nz = yes
	call	crossini		; init crosshair routine
	or	dgcross,1		; say crosshairs are on
dgcroson1:ret
dgcrosson endp

; RS G C turn off DG crosshairs
dgcrossoff proc far
	test	dgcross,1		; off now?
	jz	dgcrosof2		; z = yes
	test	dgcross,8		; on but invisible?
	jz	dgcrosof1		; z = no
	call	crosdrawh		; restore crosshairs
	call	crosdrawv
dgcrosof1:call	crossfin		; finish crosshair routine & exit
	and	dgcross,not 1+8		; say crosshair is deactiviated
dgcrosof2:ret
dgcrossoff endp

; Set DG crosshairs to DG locations x (ax) and y (bx)
dgsetcrloc proc	far
	test	dgcross,1		; is cross hair on?
	jz	dgsetcr1		; z = no
	test	dgcross,8		; is cross hair invisible?
	jnz	dgsetcr1		; nz = yes
	push	ax			; save arguments
	push	bx
	call	crosdrawh		; remove present crosshairs
	call	crosdrawv
	pop	bx
	pop	ax
dgsetcr1:cmp	ax,dgxmax		; DG x max, exceeded?
	jb	dgsetcr2		; b = in range
	mov	ax,dgxmax		; else set to max
	dec	ax
dgsetcr2:mov	si,ax
	call	dg2pcx			; convert DG to PC x in SI
	mov	xcross,si
	mov	di,bx
	call	dg2pcy			; convert DG to PC y in DI
	sub	di,ybot
	add	di,charhgt
	neg	di			; reflect top to bottom
	mov	ycross,di
	test	dgcross,1		; is crosshair on?
	jz	dgsetcr4		; z = no
	call	setmouse		; set the mouse there too
	call	crosdrawh		; draw crosshairs
	call	crosdrawv
	and	dgcross,not 8		; say cross is visible
dgsetcr4:ret
dgsetcrloc endp

; Data General D463/D470/D217  RS G ? |  report crosshair location
dgcrossrpt proc	far
	test	flags.vtflg,ttd470	; D470?
	jz	dgcrossrpt1		; z = not D470
	cmp	dgd470mode,0		; ansi mode?
	jne	dgcrossrpt2		; ne = yes, do ansi report
dgcrossrpt1:
	mov	al,RS			; report RS O |  <nnnnn> <nnnnn><CR>
	call	outmodem
	mov	al,'o'			; must be lower case, manual is wrong
	call	outmodem
	mov	al,'|'
	call	outmodem
	mov	al,' '			; space separator
	call	outmodem
	mov	ax,xcross		; x PC coordinate
	mov	cx,dgxmax		; DG max X
	mul	cx
	mov	cx,xmax			; max PC x coordinate
	add	cx,7			; account for char width effect
	div	cx			; use quotient in AX
	call	out5digit		; output 5 digit ASCII result
	mov	al,' '			; space separator
	call	outmodem
	mov	ax,ybot
	sub	ax,charhgt
	mov	cx,ax			; save PC screen height
	sub	ax,ycross		; PC coordinates from bottom
	mul	dgymax			; DG max y
	div	cx			; use quotient in AX
	call	out5digit		; output 5 digit ASCII result
	mov	al,CR			; terminal character
	call	outmodem
	ret
dgcrossrpt2:
	mov	al,ESCAPE
	call	outmodem
	mov	al,'['
	call	outmodem
	mov	ax,xcross		; x PC coordinate
	mov	cx,dgxmax		; DG max X
	mul	cx
	mov	cx,xmax			; max PC x coordinate
	add	cx,7			; account for char width effect
	div	cx			; use quotient in AX
	call	out5digit
	mov	al,';'
	call	outmodem
	mov	ax,ybot
	sub	ax,charhgt
	mov	cx,ax			; save PC screen height
	sub	ax,ycross		; PC coordinates from bottom
	mul	dgymax			; DG max y
	div	cx			; use quotient in AX
	call	out5digit		; output 5 digit ASCII result
	mov	al,'q'			; terminal character
	call	outmodem
	ret
dgcrossrpt endp

; send 5 digit ASCII number (zero filled on the left) found in AX
out5digit proc near
	push	di
	mov	di,offset stripbc	; use this as temp buffer
	mov	word ptr [di],'00'
	mov	word ptr [di+2],'00'
	inc	di			; first digit is always 0
	cmp	ax,1000
	jae	out5d2
	inc	di
	cmp	ax,100
	jae	out5d2
	inc	di
	cmp	ax,10
	jae	out5d2
	inc	di
out5d2:	call	dec2di			; convert and write to di
	mov	di,offset stripbc
	mov	cx,5
out5d4:	mov	al,[di]
	push	cx
	push	di
	call	outmodem
	pop	di
	pop	cx
	inc	di
	loop	out5d4
	pop	di
	ret
out5digit endp

; Set Data General coloring for graphics fore/background, gfcol and gbcol,
; by breaking apart the "curattr" from text mode.
dgsetcol proc	near
	push	ax
	push	cx
	mov	al,curattr
	mov	ah,al			; copy it
	and	al,0fh			; isolate foreground color
	mov	gfcol,al		; set it
	mov	cl,4
	and	ah,70h
	shr	ah,cl			; get to background field
	cmp	plotptr,offset pltega	; ega dot plot routine?
	je	dgsetco2		; e = yes
	cmp	ah,al			; same color for fore/back?
	jne	dgsetco1		; ne = no
	mov	gfcol,0			; set foreground to black
	jmp	short dgsetco2
dgsetco1:xor	ah,ah			; set background to black
dgsetco2:mov	gbcol,ah		; set it
	pop	cx
	pop	ax
	ret
dgsetcol endp

dgline	proc	far 			; (x,y,x,y,pattern,mar_bot+mar_top)
	push	bp
	mov	bp,sp			; C calling convention
	push	es
	push	si
	push	di
	push	dx
	push	linepat
	mov	al,gfcol		; current screen background
	mov	ah,gbcol
	push	ax
	test	dgcross,1		; is cross hair on?
	jz	dgline1			; z = no
	test	dgcross,8		; is cross hair invisible?
	jnz	dgline1			; nz = yes
	call	crosdrawh		; remove present crosshairs
	call	crosdrawv
	or	dgcross,8		; say cross is invisible
dgline1:call	dgsetcol		; get current coloring

	mov	di,[bp+6+6]		; end y, DG coordinates
	call	dg2pcy			; scale to PC y in di
	add	di,charhgt
	sub	di,ybot
	neg	di			; PC end y, top to bottom flip
	mov	bx,di			; PC end y in BX

	mov	di,[bp+6+2]		; start y, DG coordinates
	call	dg2pcy			; scale to PC y in di
	add	di,charhgt
	sub	di,ybot
	neg	di			; start y, top to bottom flip

	mov	si,[bp+6+4]		; end DG X
	call	dg2pcx			; convert to PC x in SI
	mov	ax,si			; AX is end x

	mov	si,[bp+6+0]		; start x
	call	dg2pcx			; convert to PC x in SI

	mov	cl,pixfor+pixbak	; do all dots
	push	[bp+6+8]		; line pattern
	pop	linepat			; set it
	call	line			; draw the line
	pop	ax
	mov	gfcol,al
	mov	gbcol,ah
	pop	linepat
	pop	dx
	pop	di
	pop	si
	pop	es
	pop	bp
	ret
dgline	endp

dgbar	proc	far ; (startx,starty,width,height,code, mar_top, mar_bot)
	push	bp
	mov	bp,sp			; C calling convention
	push	es
	push	si
	push	di
	push	dx
	mov	ah,gbcol
	mov	al,gfcol
	push	ax

	mov	ax,charhgt		; current char height
	mov	dx,[bp+6+10]		; dx = mar_top
	mul	dl			; dots to top of mar_top line
	mov	yresval,ax		; top margin line
	mov	ax,charhgt		; current char height
	mov	dx,[bp+6+12]		; dx = mar_bot
	mul	dl			; dots to bot of mar_bot line
	add	ax,charhgt		; dots to bottom of mar_bot line
	mov	yresval+2,ax		; bottom margin line

	mov	si,[bp+6+0]		; DG start x
	add	si,[bp+6+4]		; DG x width
	call	dg2pcx			; convert to PC x in SI
	mov	ax,xmax
	add	ax,7			; right most dot
	cmp	si,ax			; out of bounds?
	jbe	dgbar1			; be = no
	mov	si,ax			; clip to right margin
dgbar1:	mov	rectx2,si		; PC end/right x in rectx2

	mov	si,[bp+6+0]		; DG start x
	call	dg2pcx			; convert to PC x in SI
	mov	rectx1,si		; PC start/left x in rectx1

	mov	di,[bp+6+2]		; start y, DG coordinates
	add	di,[bp+6+6]		; plus DG height
	call	dg2pcy			; convert to PC y in DI
	add	di,charhgt
	sub	di,ybot
	neg	di			; top to bottom flip
	cmp	di,yresval		; above top margin line?
	jae	dgbar2			; ae = no
	mov	di,yresval
dgbar2:	mov	recty2,di		; PC end/top y in recty2

	mov	di,[bp+6+2]		; start y, DG coordinates
	call	dg2pcy			; convert to PC y in DI
	add	di,charhgt
	sub	di,ybot
	neg	di			; top to bottom flip
	cmp	di,yresval+2		; below bottom margin?
	jbe	dgbar3			; be = no
	mov	di,yresval+2		; clip to bottom margin
dgbar3:	mov	recty1,di		; PC start/bot y in recty1
	call	remcursor		; remove text cursor
	test	dgcross,1		; is cross hair on?
	jz	dgbar4			; z = no
	test	dgcross,8		; is cross hair visible?
	jnz	dgbar4			; nz = no
	call	crosdrawh		; remove present crosshairs
	call	crosdrawv
	or	dgcross,8		; say cross is invisible
dgbar4:	mov	si,rectx1		; left x PC coord to si
	mov	di,recty2		; top y PC coord to di
	mov	cx,recty1		; plotting from top down on screen
	sub	cx,di			; cx = # scan lines - 1
	inc	cx
	mov	numlines,cx		; remember here
	call	dgsetcol
	mov	ccode,pixfor		; write in foreground color
	cmp	byte ptr [bp+6+8],0	; color, 0=background, 1=foreground
	jne	dgbar5			; ne = foreground
	mov	ccode,pixbak		; write in background color
dgbar5:	mov	cx,rectx2		; ending x coord
	sub	cx,rectx1		; number of horizontal pixels - 1
	inc	cx			; number of horizontal pixels
	call	psetup			; set up dsp and di to screen offset
			; di points to whole byte, do bits in byte in gfplot
	mov	fill,0ffh
dgbar6:	call	gfplot			; line fill routine, uses CX
	call	pincy			; next line
	dec	numlines
	cmp	numlines,0		; done all lines?
	jg	dgbar6			; g = still lines to do
	pop	ax
	mov	gbcol,ah
	mov	gfcol,al
	pop	dx
	pop	di
	pop	si
	pop	es
	pop	bp
	ret
dgbar	endp

dgarc	proc	far ;dgarc(center x, center y, radius, start angle, end angle,
;				mar_top, mar_bot)
	push	bp
	mov	bp,sp
	mov	al,gfcol
	mov	ah,gbcol
	push	ax
	push	si
	push	di
	push	es
	call	remcursor		; remove text cursor
	call	dgsetcol
	mov	si,[bp+6+0]		; x center
	call	dg2pcx			; x center in PC units in SI
	inc	si			; plus one dot safety on PC screen
	mov	scalex,si		; store here

	mov	di,[bp+6+2]		; y center
	call	dg2pcy			; y center in PC units in DI
	mov	scaley,di		; store here

	mov	ax,[bp+6+6]		; start angle for CCW motion
	xor	dx,dx
	mov	cx,360
	div	cx			; start angle in ax, modulo 360
	mov	angle,dx		; actual start angle, mod 360

	mov	ax,[bp+6+8]		; end angle for CCW motion
	mov	bx,[bp+6+6]		; start angle
	mov	cx,bx
	add	cx,ax
	cmp	cx,720			; more than one circle?
	jb	dgarc1			; b = no
	mov	ax,cx			; make end angle much larger than strt
	cmp	ax,bx			; less than starting angle?
	jae	dgarc1			; ae = no
	add	ax,360			; add one rev
dgarc1:	cmp	ax,angle		; starting angle
	jae	dgarc2			; ae = angle <= angle+2, is ok
	cmp	angle,360		; special case?
	je	dgarc2			; e = yes
	xchg	ax,angle		; make angle <= angle+2
dgarc2:	mov	angle+2,ax		; ending angle

	mov	ax,charhgt		; current char height
	mov	dx,[bp+6+10]		; dx = mar_top
	mul	dl			; dots to top of mar_top line
	mov	yresval,ax		; top margin line
	mov	ax,charhgt		; current char height
	mov	dx,[bp+6+12]		; dx = mar_bot
	mul	dl			; dots to bot of mar_bot line
	add	ax,charhgt		; dots to bottom of mar_bot line
	mov	yresval+2,ax		; bottom margin line
	test	dgcross,1		; is cross hair on?
	jz	dgarc3			; z = no
	test	dgcross,8		; is cross hair invisible?
	jnz	dgarc3			; nz = yes
	call	crosdrawh		; remove present crosshairs
	call	crosdrawv
	or	dgcross,8		; say cross is invisible
dgarc3:
	mov	dl,ccode		; existing pixel op code
	push	dx			; save around line drawing
	push	linepat
	mov	si,[bp+6+4]		; radius
	mov	di,si
	call	dg2pcx			; x axis
	mov	yresval+4,si		; save radius in PC x units
	call	dg2pcy
	mov	yresval+6,di		; save radius in PC y units
	call	dg2pcx

	mov	bx,angle		; start angle
	call	dgasin			; convert point to SI,DI DG coord
	call	dg2pcy			; and to PC y coordinate
	add	di,scaley		; add center
	sub	di,ybot
	add	di,charhgt
	neg	di
	mov	recty1,di		; y1 in virtual units

	add	si,scalex		; add center to PC x coord
	mov	rectx1,si		; x1 in virtual units
	mov	linepat,0ffffh
	mov	bx,angle		; start angle

dgarc4:	inc	bx			; step angle
	cmp	bx,angle+2		; done yet?
	jbe	dgarc5			; be = no
	mov	bx,angle+2		; end angle
dgarc5:	mov	angle,bx		; new start
	call	dgasin			; convert BX point to SI,DI PC coord
	add	di,scaley		; add center
	sub	di,ybot			; flip top to bottom
	add	di,charhgt
	neg	di
	mov	recty2,di		; y2 in PC units
	add	si,scalex		; add center
	mov	rectx2,si		; x2 in PC units

	mov	si,rectx1
	mov	di,recty1		; start x,y
	mov	ax,rectx2	
	mov	bx,recty2		; end x,y
	cmp	di,yresval		; is start above top margin?
	jb	dgarc6			; b = yes, no plot
	cmp	bx,yresval		; and end point?
	jb	dgarc6			; b = yes, no plot
	cmp	di,yresval+2		; is start below bottom margin?
	ja	dgarc6			; a = yes, no plot
	cmp	bx,yresval+2		; end point?
	ja	dgarc6			; a = yes, no plot
	mov	cl,pixfor
	call	line			; draw line segment
dgarc6:	mov	ax,rectx2		; shift end to start
	mov	rectx1,ax
	mov	ax,recty2
	mov	recty1,ax
	mov	bx,angle		; start angle
	cmp	bx,angle+2		; done to end angle yet?
	jb	dgarc4			; b = no
	pop	linepat
	pop	dx			; save around line drawing
	mov	ccode,dl		; existing pixel op code
	pop	es
	pop	di
	pop	si
	pop	ax
	mov	gfcol,al
	mov	gbcol,ah
	pop	bp
	ret
dgarc	endp

; Provide x,y coordinates in DG address frame, given radius and angle (deg,
; ccw from the positve x axis). X is in SI, Y is in DI.
; Radius is in yresval+4 for x and yresval+6 for y, angle is in bx.
dgasin	proc	near			; x = r cos(theta), y = r sin(x)
	push	ax
	push	bx
	push	cx
	push	dx
	push	es
	mov	cx,seg sin		; sine lookup table, 90/64 deg steps
	mov	es,cx
	mov	ax,bx
	mov	cx,360
	push	dx
	xor	dx,dx
	div	cx			; remove extra 360's
	mov	bx,dx			; keep remainder
	pop	dx			; bx now has angle mod 360
					; do quadrants
	xor	si,si			; assume right side
	xor	di,di			; and top
	cmp	bx,180			; left or right?
	jbe	dgasin1			; be = right
	mov	di,-1			; remember to flip sign
	sub	bx,360
	neg	bx
dgasin1:cmp	bx,90			; top or bottom
	jbe	dgasin2			; be = top
	mov	si,-1			; say bottom
	sub	bx,180			; flip
	neg	bx
dgasin2:cmp	bx,90			; at the upper limit?
	jne	dgsin2a			; ne = no
	mov	ax,256			; set 16 bit value
	jmp	short dgsin2b
dgsin2a:mov	al,es:sin[bx]		; 256 times sine
	xor	ah,ah
dgsin2b:push	dx
	mul	yresval+6		; times radius in y reference frame
	mov	al,ah
	mov	ah,dl			; divide by 256
	pop	dx
	or	di,di			; need a sign change?
	jz	dgasin3			; z = no
	neg	ax			; flip it
dgasin3:mov	di,ax
	
	sub	bx,90			; bx is an index by now
	neg	bx			; 90 - theta for cos
	cmp	bx,90			; at the limit?
	jne	dgsin3a			; ne = no
	mov	ax,256			; set 16 bit value
	jmp	short dgsin3b
dgsin3a:mov	al,es:sin[bx]		; 256 times cosine
	xor	ah,ah
dgsin3b:mul	yresval+4		; radius in x reference frame
	mov	al,ah
	mov	ah,dl			; divide by 256
	or	si,si			; need a sign change?
	jz	dgasin4			; z = no
	neg	ax
dgasin4:mov	si,ax
	pop	es
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
dgasin	endp

; Convert DG X coordinate in SI to PC screen coordinate in SI
dg2pcx	proc	near
	push	ax
	push	cx
	push	dx
	mov	ax,si
	mov	cx,xmax			; PC screen width - 8 dots
	add	cx,7			; right most dot
	imul	cx
	mov	cx,dgxmax		; DG width
	idiv	cx			; AX gets PC dots across
	mov	si,ax
	pop	dx
	pop	cx
	pop	ax
	ret
dg2pcx	endp

; Convert DG Y coordinate in DI to PC screen coordinate in DI
dg2pcy	proc	near
	push	ax
	push	cx
	push	dx
	mov	ax,di
	mov	cx,ybot			; PC screen height
	sub	cx,charhgt		; minus status line
	imul	cx
	mov	cx,dgymax		; DG height
	idiv	cx
	mov	di,ax			; ax has PC dots y dots
	pop	dx
	pop	cx
	pop	ax
	ret
dg2pcy	endp

; Fill non-intersecting polygon whose vertices are specified as x,y word 
; pairs in rdbuf+2. Word rdbuf has count of the pairs. Closure is implied. 
; Coordinates are DG. Permit up to 255 vertices. PC text lines mar_top
; and mar_bot are in the last two words of rdbuf+2.
dgpoly	proc	far
	push	linepat			; save existing line pattern
	push	si
	push	di
	mov	al,gfcol
	mov	ah,gbcol
	push	ax
	call	remcursor		; remove text cursor
	test	dgcross,1		; is cross hair on?
	jz	dgpoly1			; z = no
	test	dgcross,8		; is cross hair invisible?
	jnz	dgpoly1			; nz = yes
	call	crosdrawh		; remove present crosshairs
	call	crosdrawv
	or	dgcross,8		; say cross is invisible
dgpoly1:call	dgsetcol		; set coloring
	mov	bx,offset rdbuf		; list: count, pairs of x,y
	mov	cx,[bx]			; get pair count
	add	bx,2			; start of x,y word pairs
	mov	ax,ybot			; largest PC y value
	mov	recty1,ax		; smallest PC y
	mov	recty2,0		; largest PC y
dgpoly2:mov	si,[bx]			; get DG x
	call	dg2pcx			; convert to PC x coord
	mov	[bx],si			; write back to list
	add	bx,2
	mov	di,[bx]			; get DG y
	cmp	di,dgymax		; too tall?
	jbe	dgpoly2a		; be = no
	mov	di,dgymax		; clip to top
dgpoly2a:call	dg2pcy			; convert to PC y coord
	sub	di,ybot
	add	di,charhgt
	neg	di			; invert for PC coord
	mov	[bx],di			; write back to list
	cmp	di,recty1		; smaller?
	jae	dgpoly3			; ae = no
	mov	recty1,di		; smallest PC y
dgpoly3:cmp	di,recty2		; larger?
	jbe	dgpoly4			; be = no
	mov	recty2,di		; largest PC y
dgpoly4:add	bx,2
	loop	dgpoly2			; do entire list
					; top/bottom margin clipping
	mov	ax,charhgt		; current char height
	mov	dx,[bx]			; dx = mar_top
	mul	dl			; dots to top of mar_top line
	cmp	ax,recty1		; is top margin higher (less)?
	jbe	dgpoly4a		; be = yes, no top clipping
	mov	recty1,ax		; clip to top margin
dgpoly4a:mov	ax,charhgt		; current char height
	mov	dx,[bx+2]		; dx = mar_bot
	mul	dl			; dots to bot of mar_bot line
	add	ax,charhgt		; dots to bottom of mar_bot line
	dec	ax
	cmp	ax,recty2		; is bot margin lower (more)?
	jae	dgpoly4b		; ae = yes, no bottom clipping
	mov	recty2,ax		; clip to bottom margin
dgpoly4b:mov	si,word ptr rdbuf+2	; get start of list
	mov	di,word ptr rdbuf+4
	mov	[bx],si			; close the polygon
	mov	[bx+2],di

	mov	di,recty1		; starting scan line, smallest PC y
	mov	linepat,0ffffh		; solid lines
dgpoly5:call	dginter			; make list of intersections to decbuf
	cmp	word ptr decbuf,2	; any elements to be sorted/plotted?
	jb	dgpoly7			; b = no
	call	dgsort			; sort x list in decbuf
	mov	bx,offset decbuf+2
dgpoly6:mov	si,[bx]			; start x
	mov	ax,[bx+2] 		; end x
	mov	cx,xmax			; right edge clipping test
	add	cx,7			; last dot to the right
	cmp	ax,cx			; offscreen to the right?
	jbe	dgpoly6a		; be = no
	mov	ax,cx			; clip to right edge
dgpoly6a:cmp	si,cx			; this edge too?
	jbe	dgpoly6b		; be = in bounds
	mov	si,cx
dgpoly6b:add	bx,4			; two words processed from list
	sub	word ptr decbuf,2	; two x elements taken care of
	cmp	si,ax			; same place?
	je	dgpoly6c		; e = yes
	push	bx
	push	di			; save reg
	mov	bx,di			; end y, start y is in di
	mov	cl,pixfor		; do just foreground dots
	call	line			; draw the line
	pop	di
	pop	bx
dgpoly6c:cmp	word ptr decbuf,2	; done all?
	jge	dgpoly6			; ge = no, do reset of list
dgpoly7:inc	di			; next scan line
	cmp	di,recty2		; at end of figure?
	jbe	dgpoly5			; be = no, do more scan lines
	pop	ax
	mov	gfcol,al
	mov	gbcol,ah
	pop	di
	pop	si
	pop	linepat			; restore line pattern
	ret
dgpoly	endp

; Provide PC x coordinate of intersections of a line with logical scan line 
; DI. List of x,y pairs (nodes) is in rdbuf+2 et seq, count of them in rdbuf
; Writes x intersections to words in decbuf+2 et seq, count in decbuf.
dginter proc	near
	push	dx
	mov	si,offset decbuf+2	; final x list
	mov	word ptr decbuf,0	; number detected for this scan line
	mov	bx,offset rdbuf+2	; index into x,y array
	mov	cx,[bx-2]		; count of nodes (3 or more)
dginter1:push	cx			; see if line crosses this scan line
	mov	ax,[bx+2] 		; y[index]
	mov	cx,[bx+2+4]		; y[index+1]
	cmp	ax,cx
	jbe	dginter2		; be = ax is higher or same on screen
	xchg	ax,cx			; make ax smaller than cx

dginter2:cmp	di,ax	 		; yscan vs y[index]
	jb	dginter7		; b = above this scan line
	cmp	di,cx	 		; yscan vs y[index+1]
	ja	dginter7		; a = below this line
	mov	ax,di			; yscan
	sub	ax,[bx+2] 		; ax = yscan - y[index]
	or	ax,ax
	jnz	dginter5		; nz = not at a starting node
	push	ax
	mov	ax,[bx+2] 		; current y[index]
	cmp	bx,offset rdbuf+2+2	; list start (wrap back situation)?
	jae	dginter3		; ae = no
	push	bx
	mov	bx,word ptr rdbuf	; count of x,y pairs
	shl	bx,1
	shl	bx,1			; count pairs
	sub	ax,word ptr (rdbuf+2)[bx-2] ; y[0] - y[maxindex-1]
	pop	bx
	jmp	short dginter4
dginter3:sub	ax,[bx-2] 		; y[index] - y[index-1]
dginter4:mov	cx,[bx+2+4] 		; y[index+1]
	sub	cx,[bx+2] 		; cx = delta y = y[index+1] - y[index]
	xor	ax,cx			; compare with above slope
	pop	ax
	jns	dginter7		; ns = same sign, do not count node

dginter5:or	ax,ax			; yscan - y[index]
	jz	dginter6		; z = at node, don't interpolate
	mov	cx,[bx+4] 		; x[index+1]
	sub	cx,[bx]			; delta x = x[index+1] - x[index]
	imul	cx
	mov	cx,[bx+2+4] 		; y[index+1]
	sub	cx,[bx+2] 		; cx = delta y = y[index+1] - y[index]
	idiv	cx
dginter6:add	ax,[bx]			; plus x[index]
	mov	[si],ax			; store in decbuf
	add	si,2
	inc	word ptr decbuf		; say counted a node
dginter7:pop	cx
	add	bx,4			; next x,y pair
	loop	dginter1
	pop	dx
	ret
dginter endp

; Sort array of words decbuf, count then list of elements
dgsort	proc	near
	push	dx
	push	si
	push	di
	mov	si,offset decbuf	; count + list
	mov	cx,[si]			; count of items in list
	dec	cx
	jcxz	dgsort5	
	add	si,2			; point to first element
	mov	dx,si			; offset of first element
	add	dx,cx			; plus count of elements
	add	dx,cx			; offset of last element
dgsort1:mov	di,si			; first element
	add	di,2			; next element
dgsort2:mov	ax,[di]			; next x
	cmp	ax,[si]			; current x
	jae	dgsort3			; ae = next is larger than current x
	xchg	ax,[si]			; interchange elements
	xchg	ax,[di]
dgsort3:add	di,2
	cmp	di,dx			; finished last element?
	jbe	dgsort2			; be = no
	add	si,2			; next element of outer loop
	loop	dgsort1
dgsort5:pop	di
	pop	si
	pop	dx
	ret
dgsort	endp

;;;;;;; EGA plot support routines
psetupe	proc	near			; EGA setup for plotting
	push	ax
	mov	ax,xmax			; line length - 8 dots
	add	ax,8			; plus nominal char width
	shr	ax,1			; divide by 8 dots per byte
	shr	ax,1
	shr	ax,1
	mov	linelen,ax
	mov	ax,segscn		; set es to screen memory segment
	mov	es,ax
	mov	ax,0205h		; mode: write mode 2
	call	ega_gc
	mov	ax,0003h		; assume writing bits directly
	test	ccode,pixfor+pixbak	; direct foreground/background write?
	jnz	psete2			; nz = yes
	mov	ax,1003h		; assume OR
	test	ccode,pixor		; OR?
	jnz	psete2			; nz = yes
	mov	ax,1803h		; assume XOR
	test	ccode,pixxor		; inverting bits?
	jnz	psete2			; nz = yes
	mov	ax,0803h		; then use AND
psete2:	call	ega_gc			; set controller
	mov	ax,linelen		; compute starting point in regen buff
	mul	di
	mov	di,ax			; di = di * 80
	pop	ax
	ret
psetupe	endp

pincye	proc	near			; EGA inc y
	add	di,linelen		; includes sign of deltay
	ret
pincye	endp

pltega	proc	near		; EGA plot(x,y). x is in si, y is in di
	ror	bp,1			; rotate line pattern
	jc	pltega1			; c = a 1 bit to be plotted
	cmp	ccode,pixfor+pixbak	; plot both 1's and 0's?
	je	pltega1			; e = yes
	ret				; else ignore the 0 bit
pltega1:push	bx
	push	si
	push	di
	mov	bx,xmax
	add	bx,7			; last right dot
	cmp	si,bx			; going out of bounds?
	ja	pltega3			; a = yes, omit the dot plot
	mov	bx,si			; want si/8 for bytes along line
	shr	si,1
	shr	si,1
	shr	si,1
	add	di,si			; starting point in regen buffer
	and	bx,0007h		; leave lower 3 bits for bit in byte
	mov	bh,masktab[bx]		; 0-7 into bit mask in byte, x pos
	mov	bl,ccode		; get line type code
	cmp	bl,pixfor+pixbak	; plot both 1's and 0's?
	jne	pltega2			; ne = no
	mov	bl,pixfor		; use foreground for ones
	test	bp,80h			; bit is a one?
	jnz	pltega2			; nz = yes
	mov	bl,pixbak		; use background for zeros
pltega2:call	ega_plt
pltega3:pop	di
	pop	si
	pop	bx
	ret
pltega	endp

;; Plot bit pattern in "fill" as 8 horizontal pixels, starting at x,y (si,di)
; and continuing across the line for cx pixels. psetupe has been called.
bpltega	proc	near		; EGA plot(x,y). x is in si, y is in di
	push	bx
	push	cx
	push	si
	push	di
	mov	bx,si			; want si/8 for bytes along line
	shr	si,1
	shr	si,1
	shr	si,1
	add	di,si			; starting byte in regen buffer
					; di = offset in regen buffer
	and	bl,7			; get bit in byte (di = byte aligned)
	jz	bplteg1			; z = aligned already
	xchg	bl,cl			; get shift to cl, low count to bl
	mov	bh,fill			; 8-bit fill pattern
	mov	al,bh			; get complement of pattern too
	not	al
	shl	bh,cl			; trim cl bits from the left
	shr	bh,cl
	shl	al,cl			; trim them from the right edge
	shr	al,cl			; restore pattern
	xchg	cl,bl			; put count back in cx
	add	cl,bl			; add bits taken care of
	adc	ch,0
	jmp	short bplteg2		; do this partial byte now

bplteg1:mov	bh,fill			; fill pattern
	mov	al,bh			; make inverted pattern
	not	al
	cmp	cx,8			; do all 8 bits?
	jae	bplteg2			; ae = yes
	push	cx			; final byte fixup
	sub	cl,8			; cl = - (number of bits to omit)
	neg	cl			; cl = number of bits to omit
	mov	al,bh			; get complement of pattern too
	not	al
	shr	bh,cl			; trim them from the right edge
	shl	bh,cl			; restore pattern
	shr	al,cl			; trim them from the right edge
	shl	al,cl			; restore pattern
	pop	cx
bplteg2:push	ax
	cmp	ccode,pixfor+pixbak	; do both fore and background?
	jne	bplteg2a		; ne = no
	push	bx
	mov	bh,al			; get complemented pattern
	mov	bl,pixbak		; write background
	call	ega_plt
	pop	bx
bplteg2a:mov	bl,ccode		; get line type code
	call	ega_plt
bplteg3:pop	ax
	inc	di			; next byte right
	sub	cx,8			; did these
	cmp	cx,0			; anything left to do?
	jg	bplteg1			; a = yes, repeat
	pop	di
	pop	si
	pop	cx
	pop	bx
	ret
bpltega	endp

;;;;;;;; CGA plot support routines
; The CGA graphics memory mapping in mode 6 (640 by 200) is 8 dots per byte,
; left most dot in the high bit, 80 bytes per scan line, scan line segments
; alternating between 0b800h (even lines 0, 2, ...) and 0ba00h (odd lines).
psetupc	proc	near			; CGA setup for plotting
	push	ax
	push	cx
	mov	linelen,80		; 80 bytes per scan line
	mov	cx,segscn
	mov	es,cx
	mov	cx,di			; save copy of di, start y line
					; compute starting point in regen buff
	shr	di,1			; half the lines in each bank
	mov	ax,80			; 80 bytes per line
	mul	di
	mov	di,ax			; di = di * 80 / 2
	test	cx,1			; even or odd line
	jz	psetc1			; z = even
	add	di,2000h		; offset to odd bank (seg 0ba00h)
psetc1:	and	di,3fffh
	pop	cx
	pop	ax
	ret
psetupc	endp

pincyc	proc	near			; CGA inc y
	cmp	linelen,0		; increasing or decreasing y?
	jl	pinyc2			; l = decreasing
	cmp	di,2000h		; in upper bank now?
	jb	pinyc1			; b = no, in lower bank
	add	di,linelen		; add a line
pinyc1:	add	di,2000h		; switch banks
	and	di,3fffh		; roll over address
	ret
pinyc2:	cmp	di,2000h		; in upper bank now?
	jae	pinyc4			; ae = yes
	add	di,linelen		; subtract a line
pinyc4:	add	di,2000h		; switch banks
	and	di,3fffh		; roll over address
	ret
pincyc	endp

pltcga	proc	near		; CGA plot(x,y). x is in si, y is in di
	ror	bp,1			; rotate line pattern
	jc	pltcg6			; c = 1 bit to be plotted
	cmp	ccode,pixfor+pixbak	; plot both 1's and 0's?
	je	pltcg6			; e = yes
	ret
pltcg6:	push	bx		; used for HGA and Wyse plots also.
	push	si
	push	di
	mov	bx,xmax
	add	bx,7			; last right dot
	cmp	si,bx			; going out of bounds?
	ja	pltcg3			; a = yes, omit the dot plot
	mov	bx,si			; want si/8 for bytes along line
	shr	si,1
	shr	si,1
	shr	si,1
	add	di,si			; starting point in regen buffer
	and	bx,0007h		; leave lower 3 bits for bit in byte
					; di = offset in regen buffer
	mov	bh,masktab[bx]		; 0-7 into bit mask in byte. x position
	mov	bl,ccode		; get line type code
	cmp	bl,pixfor+pixbak	; plot both 1's and 0's?
	jne	pltcg7			; ne = no
	mov	bl,pixfor		; use foreground for ones
	test	bp,80h			; bit is a one?
	jnz	pltcg7			; nz = yes
	mov	bl,pixbak		; use background for zeros
pltcg7:
	test	bl,pixfor+pixor		; draw in foreground color or OR?
	jz	pltcg1			; z = no
	test	bl,pixor		; OR?
	jnz	pltcg5			; nz = yes
	test	gfcol,7			; is foreground dark?
	jz	pltcg4			; z = yes, punch a hole
pltcg5:	or	es:[di],bh		; drawn
	jmp	short pltcg3
pltcg1:	test	bl,pixbak		; draw in background (erase)?
	jz	pltcg2			; z = no
	test	gbcol,7			; is background light?
	jnz	pltcg5			; nz = yes
pltcg4:	not	bh			; invert the bit
	and	es:[di],bh		; erase the dot
	jmp	short pltcg3
pltcg2:	xor	es:[di],bh		; xor in this color
pltcg3:	pop	di
	pop	si
	pop	bx
	ret
pltcga	endp

; Plot bit pattern in fill as 8 horizontal pixels, starting at x,y (si,di)
; and continuing across the line for cx pixels. psetupc has been called.
bpltcga	proc	near		; CGA plot(x,y). x is in si, y is in di
	push	bx		; used for HGA and Wyse plots also.
	push	cx
	push	si
	push	di
	mov	bx,si			; want si/8 for bytes along line
	shr	si,1
	shr	si,1
	shr	si,1
	add	di,si			; starting byte in regen buffer
					; di = offset in regen buffer
	and	bl,7			; get bit in byte (di = byte aligned)
	jz	bpltcg5			; z = aligned already
	xchg	bl,cl			; get shift to cl, low count to bl
	mov	bh,fill			; 8-bit fill pattern
	shl	bh,cl			; trim cl bits from the left
	shr	bh,cl
	push	cx
	mov	al,0ffh			; 1's are original bits to be saved
	sub	cl,8			; max field width is 8 bits
	neg	cl			; 8-number of bits trimmed from left
	shl	al,cl			; al now holds save-field bit pattern
	pop	cx
	xchg	cl,bl			; put count back in cx
	add	cl,bl			; add bits taken care of
	adc	ch,0
	jmp	short bpltcg4		; do this partial byte now

bpltcg5:mov	bh,fill			; fill pattern
	xor	al,al			; assume saving no bits
	cmp	cx,8			; do all 8 bits?
	jae	bpltcg4			; ae = yes
	push	cx			; final byte fixup
	mov	al,0ffh			; 1's are original bits to be saved
	shl	al,cl
	shr	al,cl			; al now holds save-field bit pattern
	sub	cl,8			; cl = - (number of bits to omit)
	neg	cl			; cl = number of bits to omit
	shr	bh,cl			; trim them from the right edge
	shl	bh,cl			; restore pattern
	pop	cx
bpltcg4:mov	bl,ccode		; get line type code
	cmp	bl,pixfor+pixbak	; set both fore and background?
	jne	bpltcg9			; ne = no
	test	gfcol,7			; is foreground dark?
	jnz	bpltcg8			; nz = no
	not	bh			; invert the bit pattern
	or	bh,al			; set bits to be saved
	sub	bh,al			; trim off saved bits from this field
bpltcg8:mov	ah,es:[di]		; get contents of memory cell
	and	ah,al			; preserve bit field given by al
	or	bh,ah			; mask in saved bits
	mov	es:[di],bh		; write the byte
	jmp	short bpltcg3		; done
bpltcg9:test	bl,pixfor+pixor		; draw in foreground?
	jz	bpltcg1			; z = no
	test	bl,pixor		; OR?
	jnz	bpltcg7			; nz = yes
	test	gfcol,7			; is foreground dark?
	jz	bpltcg6			; z = yes, punch a hole
bpltcg7:or	es:[di],bh		; drawn
	jmp	short bpltcg3
bpltcg1:test	bl,pixbak		; draw as background (erase)?
	jz	bpltcg2			; z= do not draw as background (erase)
	test	gbcol,7			; is background light?
	jz	bpltcg6			; z = no
	or	es:[di],bh		; drawn
	jmp	short bpltcg3
bpltcg6:not	bh
	and	es:[di],bh		; erase background dots (0's)
	jmp	short bpltcg3
bpltcg2:xor	es:[di],bh		; xor with these dots
bpltcg3:inc	di			; next byte right
	sub	cx,8			; did these
	cmp	cx,0			; anything left to do?
	jg	bpltcg5			; a = yes, repeat
	pop	di
	pop	si
	pop	cx
	pop	bx
	ret
bpltcga	endp

;;;;;;; Wyse-700 plot support routines
; The Wyse graphics memory map in mode 0D3h (1280 by 800) is 8 dots per byte,
; left most dot in the high bit, 160 bytes per scan line, scan line segments
; sequence as 0a000h even lines, and same for odd lines
psetupw proc	near			; Wyse setup for plotting
	push	ax
	push	cx
	push	dx
	mov	linelen,160		; for y going down screen by incy
	mov	ax,segscn		; base segment of display memory
	mov	es,ax
	mov	cx,di			; save copy of di, start y line
					; compute starting point in regen buff
	shr	di,1			; half the lines in each bank
	mov	ax,160
	mul	di
	mov	di,ax			; di = di * 160 / 2
	mov	dx,wymode
	shr	cx,1			; compute bank from 1 lsb of line num
	jnc	psetw2			; nc = it is in bank 0 (0b000h)
	mov	ax,wybodd		; select odd bank
	out	dx,al
	jmp	short psetw3
psetw2: mov	ax,wybeven		; select even bank
	out	dx,al
psetw3: mov	bnkchan, al		; bank has changed
	pop	dx
	pop	cx
	pop	ax
	ret
psetupw endp

;
; Wyse-700 has two banks. Line 0, 2, 4 ... are in bank 0, and 1, 3, 5 ... are
; in bank 1. Lines 0 and 1 have same addresses, lines 2 and 3 have same
; addresses etc. We have to change bank every time Y changes but we
; have to count new address only after two Y-value changes. Variable
; bnkchan is a flag for us to know into which bank to write.
;
pincyw	proc	near			; Wyse inc y, step offset of line
	push	ax
	push	dx
	mov	dx,wymode		; Wyse conrol register
	mov	al,wybeven		;
	cmp	bnkchan,wybeven		; was last write into even bank ?
	jne	pincywe			; ne = no
	mov	al,wybodd		; yes, set ready for odd bank
	out	dx,al			;
	mov	bnkchan,al		; set to odd
	jmp	short pincywo
pincywe:mov	al,wybeven		; set ready foe even bank
	out	dx,al			; select it
	mov	bnkchan,al		; set to odd
pincywo:cmp	linelen,0		; increasing y?
	jg	pinyw2			; g = yes
	cmp	al,wybeven		; from high (1) to low (0) bank ?
	je	pinyw4			; e = yes
	add	di,linelen		; no, add a line
	jmp	short pinyw4
pinyw2: cmp	al,wybodd		; from low (0) to high (1) bank ?
	je	pinyw4			; e = yes
	add	di,linelen		; no, add a line
pinyw4: and	di,0ffffh		; roll over address
	pop	dx
	pop	ax
	ret
pincyw	endp

;;;;;;; HGA plot support routines
; The HGA graphics memory mapping in mode 255 (720 by 348) is 8 dots per byte,
; left most dot in the high bit, 90 bytes per scan line, scan line segments
; sequence as 0b000h, 0b200h, 0b400h, 0b800h for lines 0-3 and repeat 90 bytes
; higher for the rest.
psetuph	proc	near			; HGA setup for plotting
	push	ax
	push	cx
	mov	linelen,90		; for y going down screen by incy
	mov	ax,segscn		; base segment of display memory
	mov	es,ax
	mov	cx,di			; save copy of di, start y line
					; compute starting point in regen buff
	shr	di,1			; quarter the lines in each bank
	shr	di,1
	mov	ax,90
	mul	di
	mov	di,ax			; di = di * 90 / 4
	and	cx,3			; compute bank from 2 lsb of line num
	jcxz	pseth2			; z means it is in bank 0 (0b000h)
pseth1:	add	di,2000h		; add offset for each bank
	loop	pseth1			; do cx times
pseth2:	pop	cx
	pop	ax
	ret
psetuph	endp

pincyh	proc	near			; HGA inc y, step offset of line
	cmp	linelen,0		; increasing y?
	jg	pinyh2			; g = yes
	cmp	di,2000h		; in lowest for four banks?
	ja	pinyh1			; a = no
	add	di,linelen		; yes, add a line
pinyh1:	add	di,6000h		; move back by adding a lot
	and	di,7fffh		; roll over address
	ret
pinyh2:	cmp	di,6000h		; in top most bank?
	jb	pinyh4			; b = no
	add	di,linelen		; yes, first add a line
pinyh4:	add	di,2000h		; switch to next bank
	and	di,7fffh		; roll over address
	ret
pincyh	endp

;;;;;;; AT&T-Olivetti, Toshiba, VAXmate Graphics Adapter plot support routines
; The graphics memory mapping in 640 by 400 mode is 8 dots per byte,
; left most dot in the high bit, 80 bytes per scan line, scan line segments
; sequence as 0b800h, 0ba00h, 0bc00h, 0be00h for lines 0-3 and repeat 80 bytes
; higher for the rest. Use Hercules line incrementing (inc y) and CGA dot
; writing. This is a monographic display.
psetupo	proc	near			; setup for plotting
	push	ax
	push	cx
	mov	linelen,80		; for y going down screen by incy
	mov	ax,segscn		; base segment of display memory
	mov	es,ax
	mov	cx,di			; save copy of di, start y line
					; compute starting point in regen buff
	shr	di,1			; quarter the lines in each bank
	shr	di,1
	mov	ax,80
	mul	di
	mov	di,ax			; di = di * 80 / 4
	and	cx,3			; compute bank from 2 lsb of line num
	jcxz	pseto2			; z means it is in bank 0 (0b800h)
pseto1:	add	di,2000h		; add offset for each bank
	loop	pseto1			; do cx times
pseto2:	pop	cx
	pop	ax
	ret
psetupo	endp

;;;;;;;; Monochrome, simulate dots with text char
psetupm	proc	near
	mov	linelen,1		; 80 characters but one line
	ret
psetupm	endp

pltmon	proc	near			; Monochrome dot plot
	mov	x_coord,si		; put dot at row=di, col=si, PC Coord
	mov	y_coord,di
	push	ax
	mov	al,'+'-' '		; our dot character
	call	mputc			; display text char
	pop	ax
	ret
pltmon	endp

; Plot bit pattern in fill as 8 horizontal pixels, starting at x,y (si,di)
; and continuing across the line for cx pixels. Destroys CX.
bpltmon	proc	near		; Mono plot(x,y). x is in si, y is in di
	jmp	pltmon		; a dummy for the present
bpltmon	endp

pincym	proc	near			; Monochrome inc y
	add	di,linelen		; includes sign
	ret
pincym	endp

; GPUTC - a routine to send text characters from font to true graphics boards
; such as EGA, Hercules or CGA. Char is in al. Drawing routine ptr is gcplot.
gputc	proc	near
	push	bx			; first save some registers
	push	cx
	push	es
	push	di
 	mov	bl,al			; now BL has char to be displayed
	xor	bh,bh
					; set board mode
	mov	di,y_coord		; get current y coord (char bottom)
	inc	di
	sub	di,charhgt		; start charlines-1 lines higher
	jnc	gputc3			; nc = ok
	mov	di,charhgt
	dec	di
	mov	y_coord,di		; reset scan line indicator
	xor	di,di			; move up to first line
gputc3:	call	psetup	; enter with di=line number, sets es:di to start of
			; line in regen buffer and sets byte-wide plot mode
	mov	si,x_coord		; si has x-axis in PC screen coord
	mov	cx,charhgt		; bytes (scan lines) to transfer
	call	gcplot			; call character plot routine
	call	incx			; move to next char position
	pop	di
	pop	es
	pop	cx
	pop	bx
	ret
gputc	endp

putctrl	proc	near			; CONTROL CHARS = cursor movement
	cmp	al,FF			; formfeed?
 	jne	putct0			; ne = no
	jmp	TEKCLS			; FF clears the screen

putct0:	cmp	al,BS			; BS? sends (logical) cursor back one
	jne	putct2			; ne = no, try next
	mov	ax,charwidth		; char width
	sub	x_coord,ax		; delete charwidth dots (move left)
	jnc	putct1			; nc = ok
	mov	x_coord,0		; limit to left margin
putct1:	cmp	bscontrol,0		; non-destructive backspace?
	je	putctx			; e = yes
	push	x_coord			; destructive backspace
	mov	al,' '			; a space to be written
	call	gputc			; write it
	pop	x_coord			; restore cursor
	ret

putct2:	cmp	al,TAB			; tabs move forward one char position
	jne	putct4			; ne = not a tab
;;;	OR	X_COORD,7*8
	jmp	incx			; let incx move cursor right one col

putct4:	cmp	al,CR			; <CR> means go to beginning of line
	jne	putct5
	mov	x_coord,0		; zero the x coordinate
	ret

putct5:	cmp	al,LF			; <LF> means go down 8 pixels (1 line)
	jne	putct7			; ne = not LF
	mov	ax,charhgt
	add	y_coord,ax		; border managed by outscrn and incx
	ret

putct7:	cmp	al,VT			; <VT> move up screen 1 line (8 pixels)
	jne	putctx
	mov	ax,charhgt		; character height
	sub	y_coord,ax		; subtract one line (charhgt pixels)
	jnc	putctx			; nc = space left
	mov	y_coord,ax		; else set to top of screen
putctx:	ret
putctrl	endp

mputc	proc	near			; MONO put char in AL via Bios
	push	bx			; updates x_coord,y_coord with
	push	cx			; new cursor position
	push	dx
	xor	ah,ah			; marker for cursor setting not needed

mputc1:	push	ax			; save char and marker
	mov	cl,3			; char cell is 8 x 8 dots
	mov	ax,x_coord		; get resulting cursor PC positions
	shr	ax,cl
	mov	dl,al			; column
	mov	ax,y_coord
	inc	ax
	sub	ax,charhgt		; minus (charhgt-1) dots
	jnc	mputc2			; nc = non-negative
	mov	ax,charhgt		; else start at the top
	inc	ax
	mov	y_coord,ax		; here too
mputc2:	shr	ax,cl
	mov	dh,al			; row
	mov	ah,2			; set cursor to x_coord,y_coord
	xor	bh,bh			; page 0
	int	screen
	pop	ax
	or	ah,ah			; write a char in al?
	jnz	mputcx			; nz = no
	mov	ah,09h			; write char at cursor postion
	mov	cx,1			; just one char
	xor	bh,bh			; page 0
	mov	bl,gfcol		; foreground coloring
	int	screen
	inc	dl			; next column
	mov	ah,2			; set real cursor ahead of last char
	int	screen
	call	incx			; move logical cursor
mputcx:	pop	dx
	pop	cx
	pop	bx
	ret
mputc	endp

incx	proc	near			; move the logical cursor right
	mov	ax,xmax
	add	ax,8
	sub	ax,charwidth		; last column+1
	cmp	ax,x_coord		; beyond right most column?
	jae	incx1			; ae = no
	mov	x_coord,ax		; set up for wrap
	ret
incx1:	mov	ax,charwidth
	add	x_coord,ax		; shift the (logical) cursor right
	ret				;  one character cell
incx	endp

; Character plot routine. Enter with BL holding char code
; cx = number of bytes in char font, es:di = screen memory. Worker for gputc.
; ccode: pixbak=plot in backgrd colors, pixfor=foregrd, pixxor=xor with screen
gcplot	proc	near
	mov	al,ccode		; save original ccode and fill pattern
	mov	ah,fill
	push	ax

	push	cx
	push	ds
	push	es
	push	si
	push	di
	mov	di,seg dotbuf		; destination buffer for font dots
	mov	es,di
	mov	di,offset dotbuf
	xor	bh,bh
	test	bl,80h			; high bit set?
	jz	gcplot1			; z = no
	lds	si,fontrptr		; use GRight font set
	and	bl,not 80h		; strip high bit now
	jmp	short gcplot2
gcplot1:lds	si,fontlptr		; use GLeft font set
gcplot2:mov	ax,cx			; char height (bytes per char)
	mul	bl			; bytes into table for char in bl
	add	si,ax			; offset into font by char
	cld
	rep	movsb			; copy font dots to dotbuf
	pop	di
	pop	si
	pop	es
	pop	ds
	pop	cx
	xor	bx,bx			; index into dotbuf
gcplot3:push	bx
	push	cx
	mov	al,dotbuf[bx]		; get 8 bits from font
	mov	cx,si			; x-axis in PC screen coordinates
	and	cl,0111b		; bit in byte across the screen
	ror	al,cl			; rotate pattern for gfplot filling
	mov	cx,charwidth		; do charwidth bits on the line
	mov	fill,al			; use "fill" as fill pattern
	call	gfplot			; fill a scan line for cx bits
	call	pincy			; next scan line (linelen is preset)
	pop	cx
	pop	bx
	inc	bx			; next byte of char pattern
	loop	gcplot3
	pop	ax
	mov	ccode,al		; recover variables
	mov	fill,ah
	ret
gcplot	endp

; routines to manipulate ega graphics controller and mode register
; command code in al, value in ah - destroys al and dx
     
ega_gc	proc	near			; ega graphics controller
	mov	dx,3ceh
	out	dx,al			; output command code
	inc	dx			; dx is now data port
	mov	al,ah			; get value to al
	out	dx,al			; output value
	ret
ega_gc	endp
ega_md	proc	near			; ega mode controller
	mov	dx,3c4h
	out	dx,al			; output command code
	inc	dx			; dx is now data port
	mov	al,ah			; get value to al
	out	dx,al			; output value
	ret
ega_md endp
     
; Plot eight pixels using an EGA board
; Enter with ES:[DI] pointing to screen address of byte,
; bh has pattern of bits to be set, bl has attributes:
;  pixbak = draw in background color, pixfor = draw in foreground color,
;  pixor = OR with foreground color, pixxor = XOR with foreground color.
; registers preserved
; Note: this function operates on 8 pixels. One bits in bh select pixels to
; be changed, bl determines which color planes will be affected for every
; selected pixel.
ega_plt proc	near
	push	ax
	push	dx
	mov	dx,3ceh			; (ega_gc) unprotect the bit positions
	mov	al,8			; command to set bit mask register
	out	dx,al			; output command code
	inc	dx			; dx is now data port
	mov	al,bh			; get pixels to be modified (1's)
	out	dx,al			; output value (end of ega_gc)
	pop	dx

	mov	ah,gfcol		; foreground color bit planes
ega1:	test	bl,pixfor+pixor		; write foreground or OR?
	jnz	ega3			; nz = yes
	mov	ah,gbcol		; background color bit planes
	test	bl,pixbak		; write in background coloring?
	jnz	ega3			; nz = yes
	mov	ah,0fh			; xor, touch each bit plane
ega3:	mov	al,es:[di]		; latch byte
	mov	es:[di],ah		; merge with untouched bits
	pop	ax
	ret
ega_plt endp

; Presence test for Wyse-700: info in B000h and B800h are supposed to be equal
chkwyse	proc	near
	push	es
	push	ds
	mov	ax,0b800h		; CGA segment
	mov	es,ax
	mov	ax,0b000h		; Mono segment
	mov	ds,ax
	mov	ch,byte ptr es:[0]	; CGA seg
	mov	cl,byte ptr ds:[0]	; Mono seg
	push	cx			; save original contents
	mov	byte ptr ds:[0],ch	; copy CGA to Mono
	cmp	byte ptr ds:[0],ch	; if different then not Wyse
	jne	chkwys1			; ne = not Wyse
	not	byte ptr es:[0]		; change CGA contents
	not	ch			; and original pattern
	cmp	ch,byte ptr ds:[0]	; if different then not Wyse
	jne	chkwys1			; ne = not Wyse
	pop	cx
	mov	byte ptr es:[0],ch	; restore CGA
	mov	byte ptr ds:[0],cl	; restore Mono
	pop	ds
	pop	es
	clc
	ret

chkwys1:pop	cx
	mov	byte ptr es:[0],ch	; restore CGA
	mov	byte ptr ds:[0],cl	; restore Mono
	pop	ds
	pop	es
	stc
	ret
chkwyse	endp
;
; routine to set Wyse-700 board to graphics mode - 1280 * 800 & cls
;
WYGRAF	PROC	NEAR
	push	ax
	push	bx			; save used registers
	push	cx
	push	dx
	push	di
	xor	al,al
	mov	dx,wystoff		; map video memory offset to zero
	out	dx,al			;
	mov	dx,wystseg		; map video memory segment to zero
	out	dx,al			;
	mov	ax,segwyse		; set es to Wyse start segment
	mov	es,ax			;
	mov	al,wybeven		; graph mode - even bank
	mov	dx,wymode		; Wyse mode control register
	out	dx,al			; select even bank
	cld
	xor	ax,ax			; zero ax
	xor	di,di			; start from zero
	mov	cx,0ffffh		; clear 10000h bytes, whole even bank
	rep	stosb			; store blanking char in whole screen
	mov	al,wybodd		; graph mode - odd bank
	mov	dx,wymode		; select it
	out	dx,al			;
	xor	ax,ax			; zero ax
	xor	di,di			;
	mov	cx,0ffffh		; clear 10000h bytes, whole odd bank
	rep	stosb			; store blanking char in whole screen
	mov	bnkchan, 0		; assume bank 0
	pop	di			; restore regs
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
WYGRAF	ENDP

; routine to set Hercules card to graphics mode - both pages are enabled
     
HGRAF	PROC	NEAR
	push	ax
	push	bx			; save used registers
	push	cx
	push	si
	mov	al,grph			; graph mode
	lea	si,gtable		;  requires graphics table
	xor	bx,bx
	mov	cx,4000h		; clear 4000h words
	test	gbcol,7			; any (light) background color bits?
	jz	hgraf1			; z = no, we are ok
	dec	bx			; light background, set all the bits
hgraf1:	call	setmd			; and set the mode
	pop	si
	pop	cx
	pop	bx
	pop	ax
	ret
HGRAF	ENDP
     
; set Hercules card to text mode
HTEXT	PROC	NEAR
	push	ax
	push	bx
	push	cx
	push	si
	mov	al,text			; text mode
	lea	si,ttable		; requires text table
	mov	bx,0720h		; blank value (space, white on black)
	mov	cx,2000			; whole screen to clear (80*25)
	call	setmd			; set the mode
	pop	si
	pop	cx
	pop	bx
	pop	ax
	ret
HTEXT	ENDP
     
; Hercules mode set - called from HTEXT and HGRAF
SETMD	PROC	NEAR
	push	dx
	push	ax
	mov	dx,config		; configuration port
	mov	al,genable		; allow graphics mode to be set
	out	dx,al
	pop	ax
	push	ax
	push	cx			; save count
	mov	dx,cntrl		; control port
	out	dx,al			; set to text or graphics
	mov	dx,index		; send 12 bytes from table to 6845
	mov	cx,12			; number of registers to load
	xor	ah,ah			; start with register 0 of 6845
	cld
setmd1:	jmp	$+2			; small pause for hardware
	mov	al,ah			; ah is counter
	out	dx,al			; set register
	inc	dx			; point to data port
	lodsb				; get next byte in table
	jmp	$+2			; small pause for hardware
	out	dx,al			; and send to 6845
	inc	ah			; next register
	dec	dx			; point to register port
	loop	setmd1			; and continue 'til cx=0
	pop	cx			; recover count
	cld
	push	di
	push	es
	mov	ax,segscn		; start of screen
	mov	es,ax
	xor	di,di
	mov	ax,bx			; get blanking character
	rep	stosw			; store blanking char in whole screen
	pop	es
	pop	di
	mov	dx,cntrl		; now to re-enable screen
	pop	ax			; get mode
	or	al,scrn_on		; enable screen
	out	dx,al
	pop	dx
	ret
SETMD	ENDP
     
teksave	proc	near		; saves graphics screen from page 0 to page 1
	mov	temp,1		; say saving from video to storage
	push	si
	push	di
	cmp	gpage,0		; only graphics page 0 on display board?
	je	teksavx		; e = yes, no saving possible here
	mov	si,segscn	; segment (!) of current screen
	cmp	graph_mode,ega
	je	teksav1
	cmp	graph_mode,monoega
	je	teksav1
	cmp	graph_mode,colorega
	je	teksav1
	cmp	graph_mode,hercules
	je	teksav2
	jmp	short teksavx	; else nothing
teksav1:mov	di,segega+800h	; EGA page 1 screen segment
	call	egasr		; call common save/restore code
	jmp	short teksavx
teksav2:mov	di,seghga+800h	; Hercules page 1 screen segment
	call	hgasr		; call common save/restore code
teksavx:pop	di
	pop	si
	ret
teksave	endp

tekrest	proc	near		; restores graphics screen in page 1 to page 0
	mov	temp,-1		; say restoring storage to video
	push	si
	push	di
	cmp	gpage,0		; only graphics page 0 on display board?
 	jne	tekres0		; ne = no, more so work to do here
	call	tekcls1		;  else clear the screen to color it
	jmp	short tekresx	;  and exit
tekres0:mov	di,segscn	; segment (!) of new graphics screen
	cmp	graph_mode,ega
	je	tekres1
	cmp	graph_mode,monoega
	je	tekres1
	cmp	graph_mode,colorega
	je	tekres1
	cmp	graph_mode,hercules
	je	tekres2
	jmp	short tekresx	; else nothing
tekres1:mov	si,segega+800h	; segment of EGA page 1
	call	egasr		; call common save/restore code
	jmp	short tekresx
tekres2:mov	si,seghga+800h	; segment of Hercules page 1
	call	hgasr		; call common save/restore code
tekresx:pop	di
	pop	si
	ret
tekrest	endp

egasr	proc	near		; common code for Tek ega save/restore ops
	push	ax
	push	cx
	push	dx
	mov	ax,0f00h	; enable 4 plane set/resets
	call	ega_gc		; set controller
	mov	ax,0f01h	; enable Set/Reset register
	call	ega_gc
	mov	ax,0f02h	; set color compare register for 4 planes
	call	ega_gc
	mov	ax,0905h	; set mode reg: write latches, read mode
	call	ega_gc
	mov	ax,0ff02h	; enable all planes
	call	ega_md
	mov	cx,ybot		; last scan line
	inc	cx		; number of scan lines
	mov	ax,80		; bytes per scan line
	mul	cx
	mov	cx,ax
	push	es		; save es
	push	ds		; save ds
	call	gsems		; try to store to/from extended/expanded mem
	jnc	egasr1		; nc = success
	mov	es,di		; destination, set es to video memory
	mov	ds,si		; source, set ds to video memory
	xor	si,si		; clear offset fields
	xor	di,di
	cld			; byte moves for ega adaptor
	rep	movsb		; copy from page (ds:si) to page (es:di)
egasr1:	pop	ds		; recover ds
	pop	es		; and other registers
	call	gcreset		; reset controller
	pop	dx
	pop	cx
	pop	ax
	ret
egasr	endp

; Transfer video to/from EMS memory for EGA/VGA boards
; SI is source seg, DI is dest seg, CX is pixel count, temp > 0 for saving
; to ems, temp < 0 for saving to video memory.
; Return carry set if failure, else carry clear
gsems	proc	near
	cmp	temp,0			; is this a save operation?
	jge	gsems0			; ge = yes
	cmp	emsgshandle,0		; EMS handle available?
	jge	gsems4			; ge = yes
	cmp	xmsghandle,0		; XMS handle available?
	jne	gsems4			; ne = yes
	stc
	ret				; fail
gsems0:	test	useexp,1		; use Expanded memory?
	jnz	gsems1			; nz = yes
	test	useexp,2		; use extended memory?
	jnz	gsems0a			; nz = yes
	stc
	ret
gsems0a:cmp	emsrbhandle,0		; have rollback in expanded memory?
	jg	gsems1			; g = yes, so use expanded here too
	call	xmssetup		; try XMS 
	jnc	gsems4			; nc = success
	ret				; else use video memory
gsems1:	mov	ah,emsrelease		; release handle and memory
	mov	dx,emsgshandle		; handle
	or	dx,dx			; is handle valid (>= 0)?
	jl	gsems1a			; l = no
	int	emsint			; ems interrupt
gsems1a:mov	emsgshandle,-1
	mov	emsbytes,cx		; remember qty pixel bytes
	mov	ax,cx
	xor	dx,dx
	shl	ax,1			; times 4 for planes per pixel
	shl	ax,1
	rcl	dx,1
	div	sixteenk		; divide by 16KB per page
	or	dx,dx			; remainder?
	jz	gsems1c			; z = no
	inc	ax			; one more page
gsems1c:mov	cx,ax			; save desired page count
	mov	ah,emsgetnpgs		; get number 16KB pages free
	int	emsint			; to bx
	cmp	bx,cx			; ((640x480/8)*4)=153,6400B = 10 pages
	jae	gsems2			; ae = have enough space
gsems1b:mov	emsbytes,0
	call	gcreset			; reset controller
	call	tekcls			; clear screen
	clc				; fake success with fresh screen
	ret
gsems2:	mov	bx,cx			; number of pages wanted
	mov	ah,emsalloc		; allocate bx pages
	int	emsint
	or	ah,ah			; successful?
	jnz	gsems1b			; nz = no, fail

	mov	emsgshandle,dx		; returned handle
	mov	ah,emsgetseg		; get segment of page frame
	int	emsint			;  to bx
	mov	emsseg,bx		; save here
	mov	ah,emsgetver		; get EMS version number
	int	emsint			; to al (high=major, low=minor)
	cmp	al,40h			; at least LIM 4.0?
	jb	gsems4			; b = no, so no name for our area
	push	si
	push	di
	mov	si,offset emsgsname	; point to name for graphics area
	mov	di,offset emsgsname+6	; add digits
	mov	ax,emsgshandle
	call	dec2di			; write to handle name
	mov	byte ptr [di],' '	; must end in a space
	mov	dx,emsgshandle
	mov	ax,emssetname		; set name for handle from ds:si
	int	emsint
	pop	di
	pop	si

gsems4:	call	gcreset			; reset controller
	mov 	ax,0005h 		; read mode 0, write mode 0
	call	ega_gc
	cmp	temp,0			; get direction of saving/restoring
	jl	gsems7			; l = restore (storage to video)
					; Save (video to ems/xms)
	cmp	emsgshandle,0		; using EMS?
	jg	gsems4b			; g = yes
	cmp	xmsghandle,0		; using XMS?
	je	gsems4c;;;b			; e = no
	call	videotoxms		; use XMS copy instead
	clc
	ret
gsems4c:stc
	ret
gsems4b:xor	bx,bx			; page 0
	call	getpage			; get EMS page bx, return size in dx
	mov	ax,emsseg		; get ems segment
	mov	es,ax			; set destination
	xor	di,di			; start of page frame
	mov	ax,segscn		; segment of video screen
	mov	ds,ax			; save (video to storage)
	mov	cx,4			; plane loop
	
gsems4a:push	cx			; save plane counter
	call	selplane		; select plane in cl (1..4)
	xor	si,si			; start of video buffer
	push	ds
	mov	cx,seg emsbytes		; segment to useful place
	mov	ds,cx
	mov	cx,emsbytes		; pixel counter
	pop	ds

gsems5:	mov	ax,cx			; save total byte count
	cmp	cx,dx			; larger than one page?
	jbe	gsems6			; be = no
	mov	cx,dx			; one page
gsems6:	sub	ax,cx			; ax is bytes remaining to do
	sub	dx,cx			; bytes to be used in EMS page
	cld
	rep	movsb			; video to ems page
	mov	cx,ax			; pixels to do
	or	dx,dx			; EMS bytes left in page?
	jnz	gsems6a			; nz = yes
	inc	bx			; next ems page
	call	getpage
	xor	di,di			; start of page
gsems6a:inc	cx			; inc for loop dec below
	loop	gsems5			; do all pixels

	pop	cx			; recover plane counter
	loop	gsems4a			; do next plane
	clc
	ret
					; copy from ems to video
gsems7:	push	ds
	mov	ax,segscn		; segment of video screen
	mov	es,ax
	mov	ax,seg xms		; using EMS?
	mov	ds,ax
	cmp	emsgshandle,0		; using EMS?
	pop	ds
	jg	gsems7b			; g = yes
	call	xmstovideo		; use XMS copy instead
	jmp	short gsems10		; free the memory block

					; use EMS
gsems7b:mov	ax,seg emsseg
	mov	ds,ax
	mov	ax,emsseg		; get ems segment
	mov	ds,ax			; set EMS source segment
	xor	bx,bx			; page
	call	getpage			; get EMS page bx
	xor	si,si			; start of frame buffer
	mov	cx,4			; plane counter

gsems7a:push	cx			; save plane counter
	call	selplane		; select plane in cl (1..4)
	push	ds
	mov	cx,seg emsbytes
	mov	ds,cx
	mov	cx,emsbytes		; pixel counter
	mov	ax,segscn		; segment of video screen
	mov	es,ax
	xor	di,di			; start of video buffer
	pop	ds

gsems8:	mov	ax,cx			; save total byte count
	cmp	cx,dx			; larger than this page can hold?
	jbe	gsems9			; be = no
	mov	cx,dx			; use value available
gsems9:	sub	ax,cx			; ax is bytes remaining to do
	sub	dx,cx			; bytes to be used in EMS page
	cld
	rep	movsb			; EMS page to video
	mov	cx,ax			; pixels to do
	or	dx,dx			; EMS bytes left in page?
	jnz	gsems9a			; nz = yes
	inc	bx			; next ems page
	call	getpage
	xor	si,si			; start of page
gsems9a:inc	cx			; inc for loop dec below
	loop	gsems8			; do all pixels

	pop	cx			; recover plane counter
	loop	gsems7a			; do next plane

gsems10:				; free expanded/extended memory block
	mov	dx,seg xms
	mov	ds,dx			; ds is restored after return
	mov	dx,xmsghandle		; XMS handle
	or	dx,dx			; valid handle?
	jz	gsems11			; z = no
	mov	ah,xmsrelease		; release the memory block
	call	dword ptr xmsep		; xms handler entry point
gsems11:mov	xmsghandle,0		; invalidate the handle
	mov	dx,emsgshandle		; ems handle
	or	dx,dx			; is handle valid (>= 0)?
	jl	gsems12			; l = no
	mov	ah,emsrelease		; release handle and memory
	int	emsint			; ems interrupt
gsems12:mov	emsgshandle,-1
	mov	emsbytes,0
	clc
	ret
gsems	endp

; Get EMS logical page BX into EMS physical page 0
; Returns in DX the number of free bytes (16KB). Modifies AX
getpage	proc	near
	push	ds
	mov	ax,seg emsgshandle
	mov	ds,ax
	mov	emspage,bx		; save globally for XMS simulation
	mov	ah,emsmapmem		; map logical page in bx
	xor	al,al			;  to physical page zero
	mov	dx,emsgshandle
	int	emsint
	mov	dx,sixteenk		; 16KB in this page
	pop	ds
	ret
getpage	endp

; Copy emsbytes bytes from XMS TO esgscn:0 (meaning from XMS to Video memory)
xmstovideo proc near
	push	ds
	push	ax
	mov	ax,seg xms			; data segment
	mov	ds,ax				; get data segment right
	mov	ax,emsbytes			; bytes to move
	mov	word ptr xms.xms_count,ax	; byte count
	mov	word ptr xms.xms_count+2,0
	mov	word ptr xms.offset_src+2,0	; source address
	mov	word ptr xms.offset_src+0,0 	; low order
	mov	ax,xmsghandle 			; source is XMS
	mov	xms.handle_src,ax
	mov	xms.handle_dst,0		; dest is below 1MB
	mov	ax,segscn			; video graphics segment
	mov	word ptr xms.offset_dst+2,ax	; high order
	mov	si,offset xms			; ds:si is request block
	mov	cx,4				; four video planes
xmstov1:mov	word ptr xms.offset_dst,0	; low order address
	call	selplane			; select plane in cl (1..4)
	mov	ah,xmsmove
	call	dword ptr xmsep
	mov	ax,emsbytes			; byte count
	add	word ptr xms.offset_src+0,ax 	; low order
	adc	word ptr xms.offset_src+2,0	; source address
	loop	xmstov1				; next video plane (of four)
	pop	ax
	pop	ds
	ret
xmstovideo endp

; Copy emsbytes bytes from esgscn:0 to XMS (meaning from Video memory to XMS)
videotoxms proc near
	push	ds
	push	ax
	mov	ax,seg xms
	mov	ds,ax				; get data segment right
	mov	word ptr xms.offset_dst+2,0	; dest high order
	mov	word ptr xms.offset_dst+0,0 	; low order
	mov	ax,xmsghandle 			; dest is XMS
	mov	xms.handle_dst,ax
	mov	xms.handle_src,0		; src is below 1MB
	mov	word ptr xms.offset_src,0	; low order address
	mov	ax,segscn			; source is screen seg
	mov	word ptr xms.offset_src+2,ax	; high order
	mov	si,offset xms			; ds:si is request block
	mov	cx,4				; four video planes
videoxms1:
	mov	ax,emsbytes			; bytes per plane
	mov	word ptr xms.xms_count,ax	; byte count
	mov	word ptr xms.xms_count+2,0
	call	selplane			; select plane in cl (1..4)
	mov	ah,xmsmove
	call	dword ptr xmsep
	mov	ax,emsbytes			; bytes per plane
	add	word ptr xms.offset_dst+0,ax 	; low order
	adc	word ptr xms.offset_dst+2,0	; dest high order
	loop	videoxms1			; do next plane (of four)
	pop	ax
	pop	ds
	ret
videotoxms endp

xmssetup proc	near
	mov	emsbytes,cx		; remember qty pixel bytes
	mov	dx,xmsghandle		; handle for memory block
	or	dx,dx			; valid handle?
	jz	xmsset1			; z = no
	mov	ah,xmsrelease		; release the memory block
	call	dword ptr xmsep		; xms handler entry point
xmsset1:mov	xmsghandle,0		; invalidate the handle
	mov	dx,emsbytes		; bytes requested
	add	dx,1023			; round up to next KB
	mov	dl,dh			; divide by 256
	xor	dh,dh
	mov	ax,dx			; save request amount in ax
	push	dx
	mov	ah,xmsquery
	call	dword ptr xmsep		; get largest block KB into ax
	pop	dx
	cmp	dx,ax			; wanted KB vs available KB
	jbe	xmsset2			; be = have space
	stc				; fail
	ret

xmsset2:mov	ah,xmsalloc		; allocate block of dx KB
	call	dword ptr xmsep		; XMS manager entry point
	mov	xmsghandle,dx		; returned XMS handle of block
	cmp	ax,1			; success?
	je	xmsset3			; e = yes
	mov	emsbytes,0
	stc				; fail
	ret
xmsset3:clc				; success
	ret
xmssetup endp

; Select EGA video plane in cl (1..4) for r/w
selplane proc	near
	push	cx
	push	dx
	dec	cl			; count planes as 0..3
	and	cl,3			; range bound (planes 0..3)
	mov	ah,cl			; binary value for read map select
	mov	al,4			; read map select register
	call	ega_gc			; set read map plane
	mov	ah,1			; convert to plane number
	shl	ah,cl			; convert plane number to bit position
	mov	al,2			; map mask register
	call	ega_md			; select plane for writing
	pop	dx
	pop	cx
	ret
selplane endp

; Reset EGA board prior to video<->ems copying
gcreset proc	near
	push	ax
	push	dx
	mov	ax,0ff08h	; bit mask reg to all 8 bits
	call	ega_gc
	mov	ax,0003h	; direct write
	call	ega_gc			
	mov	ax,0004h	; read map select to map 0
	call	ega_gc
	mov	ax,0000h	; set/reset latches
	call	ega_gc
	mov	ax,0001h	; set/reset enable, disable
	call	ega_gc
	mov	ax,0f02h	; enable all planes for write
	call	ega_md
	pop	dx
	pop	ax
	ret
gcreset endp

hgasr	proc	near		; Hercules save restore screen
	push	cx
	mov	cx,4000h	; number of words to move
	push	es		; save es
	push	ds		; save ds
	mov	es,di		; destination, set es to video memory
	mov	ds,si		; source, set ds to video memory
	xor	si,si		; clear offset fields
	xor	di,di
	cld
	rep	movsw		; copy from page [si] to page [di]
	pop	ds		; recover ds
	pop	es		; and other registers
	pop	cx
	ret
hgasr	endp

dump	proc	FAR			; Write screen as TIFF v5.0 file
	push	ax
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	call	remcursor		; remove the cursor from the screen
	mov	si,offset dumpname	; name of dump file
	mov	di,offset rdbuf		; destination
	push	es
	push	ds
	pop	es
	mov	cx,dumplen		; length of dump name
	cld
	rep	movsb			; copy it, asciiz
	pop	es
	mov	ax,offset rdbuf		; address to ax for unique
	call	tunique			; get unique name into ax
	mov	dx,ax			; ds:dx is asciiz filename
	xor	cx,cx			; normal attributes
	mov	ah,creat2		; create the file
	int	dos
	jc	dmp3			; c = failure
dmp1:	mov	dhandle,ax		; file handle
	call	dmpdate			; do time stamp
	cmp	plotptr,offset pltcga	; using CGA style graphics?
	jne	dmp2			; ne = no
	call	cgadmp			; do CGA style dump routine
	jmp	short dmp3
dmp2:	call	egadmp
dmp3:	jnc	dmp5			; nc = successful dump
	mov	cx,4
dmp4:	push	cx
	call	tekbeep			; make a noise
	mov	ax,250			; wait 250ms
	call	pcwait
	pop	cx
	loop	dmp4			; four beeps
dmp5:	mov	cursorst,1		; pretend cursor was on
	call	remcursor		; restore the cursor to the screen
	mov	cursorst,1		; say it is on
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	pop	ax
	ret
dump	endp

; CGA TIFF 5.0 screen-to-file dump routine
cgadmp	proc	near
	push	es			; do the bookkeeping math first
	mov	bps.entval,1		; bits/sample, mono
	mov	photo.entval,1		; mono, one bit after the other
	mov	word ptr cmap.entcnt,0	; no palette color map entries
	mov	ax,xmax			; image width - 8 pixels
	add	ax,8			; plus 8, for pixels per line
	mov	iwidth.entval,ax	; store in directory
	mov	xresval,ax		; x resolution
	mov	xresval+2,0		; high order part
	mov	ax,ybot			; lines per screen - 1
	inc	ax			; lines per screen
	mov	ilength.entval,ax	; image length, scan lines
	mov	yresval,ax		; y resolution
	mov	yresval+2,0		; high order part
	mov	cx,25			; try dividing into this many strips
cgadmp5:xor	dx,dx			; image pixels
	mov	ax,yresval		; number of scan lines
	div	cx			; try dividing into 25 strips,ax=quo
	or	dx,dx			; did we get null remainder?
	loopnz	cgadmp5			; nz = no, try again with fewer strips
	inc	cx			; inc for dec by loop, cx = # strips
	mov	word ptr strip.entcnt,cx ; store number of strips
	mov	word ptr sbc.entcnt,cx	; store number of strip byte counts
	mov	rps.entval,ax		; rows per strip
	push	cx
	mov	cx,iwidth.entval	; dots per line (row)
	shr	cx,1			; get bytes/row
	shr	cx,1
	shr	cx,1
	mul	cx			; rows/strip * bytes/row = bytes/strip
	pop	cx
	push	cx			; save strip count for loop below
	push	ds			; ax = bytes per strip
	pop	es			; es:di to our data segment
	mov	di,offset stripbc	; where to write strip byte counts
	cld
	rep	stosw			; write ax as bytes/strip, cx times
	pop	cx			
	mov	dx,ax			; bytes/strip = increment, put here
	mov	di,offset stripoff	; where we write
	mov	ax,offset pixdata-offset header ; where first strip starts
cgadmp4:stosw				; write strip file offset
	mov	word ptr [di],0		; high order part
	add	di,2			; next double word
	add	ax,dx			; next file strip offset
	loop	cgadmp4			; do all strip offsets
					; file i/o starts here
	mov	bx,dhandle		; dump's file handle
	mov	dx,offset header	; write TIFF header and directory
	mov	cx,tifflen		; length of header plus directory
	mov	ah,write2
	int	dos
	jc	cgadmp2			; c = failure
	xor	di,di			; start at y = top
	call	psetup			; setup cga and di
	mov	cx,ybot			; number of scan lines-1
	inc	cx			; number of scan lines
cgadmp1:push	cx
	mov	cx,iwidth.entval	; dots per line (row)
	shr	cx,1			; get bytes/row
	shr	cx,1
	shr	cx,1			; line length, bytes
	mov	dx,di			; offset in screen buffer
	mov	bx,dhandle		; file handle
	push	ds
	mov	ax,segscn		; screen seg
	mov	ds,ax
	mov	ah,write2		; write directly from screen memory
	int	dos
	pop	ds
	jc	cgadmp2			; c = failure
	call	pincy			; next line down, y = y + 1
	pop	cx
	loop	cgadmp1			; do all scan lines
cgadmp2:mov	ah,close2		; close the file
	int	dos
	mov	dhandle,-1		; set handle to unused
	pop	es
	ret
cgadmp	endp

; EGA TIFF 5.0 screen-to-file dump routine
egadmp	proc	near
	push	es			; do the bookkeeping math first
	mov	bps.entval,4		; bits/sample, iRGB
	mov	photo.entval,3		; photo interp, palette
	mov	word ptr cmap.entcnt,3*16 ; palette color map entries
	mov	ax,xmax			; image width - 8 pixels
	add	ax,8			; plus 8, for pixels per line
	mov	iwidth.entval,ax	; store in directory
	mov	xresval,ax		; x resolution
	mov	xresval+2,0		; high order part
	mov	ax,ybot			; lines per screen - 1
	inc	ax			; lines per screen
	mov	ilength.entval,ax	; image length, scan lines
	mov	yresval,ax		; y resolution
	mov	yresval+2,0		; high order part
	mov	cx,25			; try dividing into this many strips
egadmp10:xor	dx,dx			; image pixels
	mov	ax,yresval		; number of scan lines
	div	cx			; try dividing into 25 strips, ax=quo
	or	dx,dx			; did we get null remainder?
	loopnz	egadmp10		; nz = no, try again with fewer strips
	inc	cx			; inc for dec by loop, cx = # strips
	mov	word ptr strip.entcnt,cx ; store number of strips
	mov	word ptr sbc.entcnt,cx	; store number of strip byte counts
	mov	rps.entval,ax		; rows per strip
	shl	ax,1
	shl	ax,1			; times 4 bits / pixel
	push	cx
	mov	cx,iwidth.entval	; dots per line (row)
	shr	cx,1			; get bytes/row
	shr	cx,1
	shr	cx,1
	mul	cx			; rows/strip * bytes/row = bytes/strip
	pop	cx
	push	cx			; save strip count for loop below
	push	ds			; ax = bytes per strip
	pop	es			; es:di to our data segment
	mov	di,offset stripbc	; where to write strip byte counts
	cld
	rep	stosw			; write ax as bytes/strip, cx times
	pop	cx			
	mov	dx,ax			; bytes/strip = increment, put here
	mov	di,offset stripoff	; where we write
	mov	ax,offset pixdata-offset header ; where first strip starts
	xor	bx,bx
egadmp11:stosw				; write strip file offset
	mov	es:[di],bx		; high order part
	add	di,2			; next double word
	add	ax,dx			; next file strip offset
	adc	bx,0
	loop	egadmp11		; do all strip offsets
					; screen to file i/o starts here
	mov	bx,dhandle		; dump's file handle
	mov	dx,offset header	; write TIFF header and directory
	mov	cx,tifflen		; length of header plus directory
	mov	ah,write2
	int	dos
	jnc	egadmp12
	jmp	egadmp9			; c = failure
egadmp12:
	xor	di,di			; start at y = top
	call	psetup			; setup adapter and es:di
	xor	di,di
	mov	bx,offset rdbuf		; set buffer address
	mov	cx,ybot			; number of scan lines-1
	inc	cx			; number of scan lines
egadmp1:push	cx			; save scan line counter
	mov	cx,iwidth.entval	; dots per line (row)
	shr	cx,1			; get bytes/row
	shr	cx,1
	shr	cx,1			; 8*dots across the screen (640)
egadmp2:push	cx			; save counter of inner loops
	mov	cx,4			; number of planes to do
	mov	word ptr [bx],0		; clear the four bytes for this loop
	mov	word ptr [bx+2],0
egadmp3:push	cx			; save plane counter
	push	bx			; don't advance buffer pointer here
	mov	dx,3ceh			; (ega_gc)
	mov	al,4			; command to select read map register
	out	dx,al			; output command code
	inc	dx			; dx is now data port
	mov	al,cl			; do planes 3(I), then 2(R),1(G),0(B)
	dec	al			; cx is one higher than plane
	out	dx,al			; output value (end of ega_gc)
	mov	al,es:[di]		; latch byte
					; got 8 bits from a plane
	mov	cx,4			; do this for four output bytes
egadmp4:mov	ah,[bx]			; eventually iRGB in each nibble
	shl	al,1			; get left most pixel bit in plane
	jnc	egadmp5
	or	ah,8			; set high nibble least sig bit
egadmp5:shl	al,1			; odd numbered pixel
 	rcl	ah,1			; set low nibble least sig bit if c
	mov	[bx],ah
	inc	bx			; next byte
	loop	egadmp4			; do all four bytes

	pop	bx
	pop	cx			; restore plane counter
	loop	egadmp3			; do all planes

	inc	di			; next screen memory address
	add	bx,4			; just did four bytes
	cmp	bx,offset rdbuf+80	; at end of 80 bytes?
	jb	egadmp6			; b = no
	call	egadmpw			; write the buffer
	mov	bx,offset rdbuf		; reset buffer address
	jnc	egadmp6			; nc = success
	pop	cx			; clean stack
	pop	cx
	jmp	egadmp9			; error

egadmp6:pop	cx			; recover bytes per line counter
	loop	egadmp2			; next group across scan line
	pop	cx			; recover scan line counter
	loop	egadmp1			; do next scan line
	call	egadmpw			; flush the buffer for last scan line
egadmp9:mov	ah,close2		; close the file
	mov	bx,dhandle
	int	dos
	mov	dhandle,-1		; set handle to unused
	xor	di,di
	call	psetup
	pop	es
	ret
	   				; local worker
egadmpw:push	bx			; write tempbuf from start to [bx-1]
	push	cx
	mov	dx,offset rdbuf		; work buffer
	mov	cx,bx			; buffer pointer to next free byte
	sub	cx,dx			; buffer size to write
	cmp	cx,0
	jle	egadmpw1		; le = nothing to write
	mov	bx,dhandle		; file handle
	mov	ah,write2		; write cx bytes from rdbuf
	int	dos
	jc	egadmpw2		; c = error
	cmp	ax,cx			; wrote all?
	jne	egadmpw2		; ne = no
egadmpw1:clc				; clc
	pop	cx
	pop	bx
	ret
egadmpw2:stc				; carry set for failure
	pop	cx
	pop	bx
	ret
egadmp	endp

; Worker. Write Kermit version and current date and time in TIFF header
dmpdate	proc	near
	mov	di,offset prog+10	; place for version in prog field
	mov	ax,version		; Kermit version
	call	dec2di			; write the version
	mov	ah,getdate		; DOS date (cx= yyyy, dh= mm, dl= dd)
	int	dos
	mov	di,offset dandt		; where to write
	mov	ax,cx			; get yyyy
	push	dx
	call	dec2di			; write to buffer
	pop	dx
	mov	byte ptr [di],':'
	inc	di
	mov	al,dh			; mm
	cmp	al,10			; leading digit?
	jae	dmpdat1			; ae = yes
	mov	byte ptr [di],'0'	; make our own
	inc	di
dmpdat1:xor	ah,ah
	push	dx
	call	dec2di
	mov	byte ptr [di],':'
	pop	dx
	inc	di
	mov	al,dl			; dd
	cmp	al,10			; leading digit?
	jae	dmpdat2			; ae = yes
	mov	byte ptr [di],'0'	; make our own
	inc	di
dmpdat2:xor	ah,ah
	call	dec2di
	mov	byte ptr [di],' '
	inc	di
	mov	ah,gettim		; DOS tod (ch=hh, cl=mm, dh=ss, dl=.s)
	int	dos
	push	dx			; save dx
	xor	ah,ah
	mov	al,ch			; Hours
	cmp	al,10			; leading digit?
	jae	dmpdat3			; ae = yes
	mov	byte ptr [di],'0'	; make our own
	inc	di
dmpdat3:push	cx
	call	dec2di			; write decimal asciiz to buffer
	pop	cx
	mov	byte ptr [di],':'
	inc	di
	xor	ah,ah
	mov	al,cl			; Minutes
	cmp	al,10			; leading digit?
	jae	dmpdat4			; ae = yes
	mov	byte ptr [di],'0'	; make our own
	inc	di
dmpdat4:call	dec2di			; write decimal asciiz to buffer
	mov	byte ptr [di],':'
	inc	di
	pop	dx
	xor	ah,ah
	mov	al,dh			; Seconds
	cmp	al,10			; leading digit?
	jae	dmpdat5			; ae = yes
	mov	byte ptr [di],'0'	; make our own
	inc	di
dmpdat5:call	dec2di			; write decimal asciiz to buffer
	inc	di
	ret
dmpdate	endp

; Read 8x14 GRight font for current Code Page from DOS file EGA.CPI to 
; array fontgright. Returns carry set if failed.
getfont proc	near
	mov	ax,offset fontfile	; EGA.CPI filename
	call	fspath			; search path for it
	jnc	getfont1		; nc = found, ax has full path
	ret				; not found, fail
getfont1:mov	dx,ax			; point to name from spath
	mov	ah,open2		; open file
	xor	al,al			; 0 = open for reading
	cmp	dosnum,300h		; at or above DOS 3?
	jb	getfont2		; b = no, so no shared access
	or	al,40h			; open for reading, deny none
getfont2:int	dos
	jnc	getfont3		; nc = success
	ret				; failure

getfont3:mov	temp,ax			; file handle
	mov	bx,ax			; handle
	mov	cx,23			; read "head" information, 23 bytes
	mov	dx,offset stripoff	; ds:dx = temp work buffer
	mov	ah,readf2		; read file
	int	dos
	jnc	getfont4		; nc = successful read
getfont3a:jmp	getfont12		; fail

getfont4:cmp	byte ptr stripoff,0ffh	; file signature
	jne	getfont3a		; ne = not a CPI file internally
	mov	dx,word ptr stripoff[19] ; offset of word "info"
	mov	cx,word ptr stripoff[21] ; high order part
	mov	ah,lseek
	xor	al,al			; seek from BOF
	int	dos
	mov	cx,2			; read a word
	mov	dx,offset stripoff
	mov	ah,readf2
	int	dos
	mov	di,word ptr stripoff	; number of Code Page entities

getfont6:mov	bx,temp			; handle
	mov	cx,128			; buffer with font info
	mov	dx,offset stripoff
	mov	ah,readf2
	int	dos
	cmp	word ptr stripoff[8],'GE' ; "EGA"?
	jne	getfont7		; ne = no, keep looking
	mov	dx,vtcpage		; current Code Page
	cmp	word ptr stripoff[16],dx ; Code Page ident, same?
	je	getfont8		; e = yes
getfont7:mov	dx,word ptr stripoff[2] ; ptr to next CP entry
	mov	cx,word ptr stripoff[4] ; high order part
	mov	bx,temp			; file handle for seeking
	mov	ah,lseek
	xor	al,al			; seek from BOF
	int	dos
	dec	di			; one less Code Page
	cmp	di,0			; done all?
	jg	getfont6		; g = no, get next header
	stc				; failed to find CP material
	jmp	getfont12		; fail
					; found CP section, find fonts
getfont8:mov	dx,word ptr stripoff[24]  ; offset of fonts data
	mov	cx,word ptr stripoff[26]  ; high order part
	mov	ah,lseek
	xor	al,al			; seek from BOF
	int	dos
	mov	bx,temp			; handle
	mov	cx,6			; read font's "dathead"
	mov	dx,offset stripoff
	mov	ah,readf2
	int	dos
	mov	di,word ptr stripoff[2] ; number of fonts in this CP item

getfont9:mov	bx,temp			; handle
	mov	cx,6			; read fonthead: hgt,width,0,0,# chars
	mov	dx,offset stripoff
	mov	ah,readf2
	int	dos
	mov	ax,word ptr stripoff	; cell height (low byte)
	push	ax			; save for test below
	mov	cl,ah			; cell width (typically 8)
	mul	cl			; number of bytes per char
	mul	word ptr stripoff[4]	; number chars in table=bits to skip
	mov	cx,8			; divide by 8 for bytes, hope is ok
	div	cx
	xor	cx,cx			; high part, for lseek
	mov	dx,ax			; low part (whole bytes)
	pop	ax
	cmp	ax,8*256+14 		; is this font 14x8?
	je	getfont10		; e = yes, that is what we want
	mov	bx,temp			; handle
	mov	ah,lseek
	mov	al,1			; seek from current position
	int	dos
	dec	di			; one less font in this CP section
	cmp	di,0			; done all?
	jg	getfont9		; g = no
	stc
	jmp	short getfont12		; fail
					; read the 8x14 patterns
getfont10:mov	dx,128*14		; bytes in GLeft patterns (128 chars)
	xor	cx,cx
	mov	bx,temp			; handle
	mov	ah,lseek
	mov	al,1			; seek from current position
	int	dos
					; malloc memory for font table
	mov	bx,(128*14)/16		; paragraphs for 128*14 bytes
	mov	cx,bx			; remember desired paragraphs
	mov	ah,alloc		; allocate a memory block
	int	dos
	jc	getfont12		; c = error, not enough memory
 	cmp	bx,cx			; obtained vs wanted
	jae	getfont11		; ae = enough
	mov	es,ax			; allocated segment
	mov	ah,freemem		; free it
	int	dos
	jmp	short getfont12		; quit here

getfont11:mov	word ptr fontrptr+2,ax	; address of allocated memory
	mov	word ptr fontrptr,0	; offset is zero
	mov	cx,128*14		; bytes in GRight patterns
	mov	bx,temp			; handle
	push	ds
	mov	ds,ax
	xor	dx,dx			; ds:dx is buffer, from malloc
	mov	ah,readf2
	int	dos
	pop	ds
	jnc	getfont12		; nc = success
	mov	ax,word ptr fontrptr+2	; get segment
	mov	es,ax			; allocated segment
	mov	ah,freemem		; free it
	int	dos
	stc				; say failure
getfont12:pushf				; save carry bit
	mov	bx,temp			; handle
	mov	ah,close2		; close file
	int	dos
	popf
	ret
getfont endp

; Dispatch table processor. Enter with BX pointing at table of {char count,
; address of action routines, characters}. Jump to matching routine or return.
; Enter with AL holding received Final char.
atdispat proc near
	mov	cl,[bx]			; get table length from first byte
	xor	ch,ch
	mov	di,bx			; main table
	add	di,3			; point di at first char in table
	push	es
	push	ds
	pop	es			; use data segment for es:di below
	cld				; set direction forward
	repne	scasb			; find matching character
	pop	es
	je	atdisp2			; e = found a match, get action addr
	cmp	al,' '			; control char?
	jb	atdisp1			; b = yes
	ret				; ignore escape sequence
atdisp1:jmp	tekctl			; process control char
atdisp2:sub	di,bx			; distance scanned in table
	sub	di,4			; skip count byte, address word, inc
	shl	di,1			; convert to word index
	inc	bx			; point to address of action routines
	mov	bx,[bx]			; get address of action table
	jmp	word ptr [bx+di]	; dispatch to the routine
atdispat endp

ansich	proc	near			; insert Pn spaces at and after cursor
	mov	cx,param		; get Pn
	or	cx,cx
	jnz	ansich1			; got a value
	inc	cx			; zero means one
ansich1:push	x_coord
	push	y_coord
	and	x_coord,not 7		; modulo 8x8 cells
	mov	ax,xmax			; start of last cell
	sub	ax,x_coord		; start of current cell
	shr	ax,1			; divide by 8 dots per char
	shr	ax,1
	shr	ax,1
	cmp	ax,cx			; want more spaces than are on line?
	jae	ansich2			; ae = no
	mov	cx,ax			; clip to right margin
	jcxz	ansich3			; z = nothing to do
ansich2:push	cx
	mov	al,' '			; a space
	call	putc			; write to screen
	pop	cx
	loop	ansich2			; do them
ansich3:pop	x_coord
	pop	y_coord
	call	remcursor		; remove text cursor symbol
	call	setcursor		; draw cursor at new location
	ret
ansich	endp
					; scaled by text screen height
atcuu	proc	near			; cursor up Pn lines
	cmp	param,0			; empty arg?
	jne	atcuu1			; got a value
	inc	param			; zero means one
atcuu1:	mov	ax,y_coord		; where we are now
	add	ax,4			; round up a smidge
	mov	cl,byte ptr low_rgt+1	; highest text line
	xor	ch,ch
	mul	cx			; proportion
	xor	dx,dx
	mov	cx,ybot			; highest scan line
	div	cx			; end, estimate currren text line
	sub	ax,param
	inc	ax			; count lines from 1 again
	mov	param,ax		; new text row
	jmp	atcva			; do as absolute
atcuu	endp

					; scaled by text screen height
atcud	proc	near			; cursor down Pn lines
	cmp	param,0			; get Pn
	jne	atcud1			; ne = got a value
	inc	param			; zero means one
atcud1:	mov	ax,y_coord		; where we are now
	add	ax,4			; round up a smidge
	mov	cl,byte ptr low_rgt+1	; highest text line
	xor	ch,ch
	mul	cx			; proportion
	xor	dx,dx
	mov	cx,ybot			; highest scan line
	div	cx			; end, estimate currren text line
	inc	ax			; count lines from 1 again
	add	param,ax		; new text row
	jmp	atcva			; do as absolute
atcud	endp

atcuf	proc	near			; cursor forward Pn columns
	mov	ax,param		; get Pn
	or	ax,ax
	jnz	atcuf1			; got a value
	inc	ax			; zero means one
atcuf1:	shl	ax,1			; times 8 dots per char cell
	shl	ax,1
	shl	ax,1			; Tek columns worth
	and	x_coord,not 7		; modulo 8x8 cells
	add	x_coord,ax		; forward to absolute column
	mov	ax,xmax
	cmp	x_coord,ax		; beyond right most cell?
	jbe	atcuf2			; be = no
	mov	x_coord,ax		; limit to right
atcuf2:	call	remcursor		; remove text cursor symbol
	call	setcursor		; draw cursor at new location
	ret
atcuf	endp

atcub	proc	near			; cursor left/back Pn columns
	mov	ax,param		; get Pn
	or	ax,ax
	jnz	atcub1			; got a value
	inc	ax			; zero means one
atcub1:	shl	ax,1
	shl	ax,1
	shl	ax,1			; times 8 dots per cell
	and	x_coord,not 7		; modulo 8x8 cells
	mov	cx,xmax
	cmp	x_coord,cx		; beyond last col (wrap pending)?
	jbe	atcub3			; be = no
	mov	x_coord,cx		; set to last col
atcub3:	sub	x_coord,ax		; back up
	jnc	atcub2			; nc = ok
	mov	x_coord,0		; stop in column zero
atcub2:	call	remcursor		; remove text cursor symbol
	call	setcursor		; draw cursor at new location
	ret
atcub	endp

atcnl	proc	near			; do Pn cr/lf's
	mov	x_coord,0		; to left margin
	jmp	atcud			; do the cursor downs
atcnl	endp

atcpl	proc	near			; do Pn cursor ups
	jmp	atcuu			; do the cursor ups
atcpl	endp

					; scaled by text screen width
atcha	proc	near			; cursor to absolute column
	and	x_coord,not 7		; modulo 8x8 cells
	mov	ax,param		; get Pn
	or	ax,ax
	jz	atcha1			; z = zero already
	dec	param			; count columns from 0
	mov	ax,xmax			; number of Tek dots/row
	mul	param			; times columns they want
	mov	cl,byte ptr low_rgt	; number of last text column
	xor	ch,ch
	xor	dx,dx
	div	cx			; scale to ~80 column screen
	cmp	ax,xmax			; too far?
	jbe	atcha1			; be = no
	mov	ax,xmax			; right most column
atcha1:	mov	x_coord,ax
	call	remcursor		; remove text cursor symbol
	call	setcursor		; draw cursor at new location
	ret
atcha	endp
					; scaled by text screen height
atcva	proc	near			; cursor to absolute row
	dec	param			; count from 0
	mov	ax,param		; desired text row
	or	ax,ax			; zero or now -1?
	jg	atcva1			; g = no, further down
	mov	ax,7			; bottom of top text cell
	jmp	short atcva2
atcva1:	mov	ax,ybot
	inc	ax			; number of scan lines on screen
;;;;	and	ax,not 7		; whole 8x8 char cells
	mul	param			; times row they want
	mov	cl,byte ptr low_rgt+1	; number of last text line (0..23)
	xor	ch,ch
	xor	dx,dx
	div	cx			; scale to ~24 line screen 
	mov	cx,ybot
;;;;	and	cx,not 7		; whole 8x8 char cells
	cmp	ax,cx			; too far?
	jbe	atcva2			; be = no
	mov	ax,cx
atcva2:	mov	y_coord,ax		; go to that line
	call	remcursor		; remove text cursor symbol
	call	setcursor		; draw cursor at new location
	ret
atcva	endp
	
atcup	proc	near			; cursor to absolute row, column
	call	atcva			; process param[0] as absolute row
	push	param[2]		; column
	pop	param
	jmp	atcha			; process param[2] as absolute column
atcup	endp

ated	proc	near			; erase display
	mov	al,spcontrol		; preserve space control
	mov	rdbuf,al		; save here
	mov	spcontrol,1		; turn on destructive space
	push	x_coord
	push	y_coord			; save cursor
	cmp	param,0			; cursor to end of screen?
	je	ated1			; e = yes
	cmp	param,1			; start of screen to cursor?
	je	ated3			; e = yes
	cmp	param,2			; entire screen?
	je	ated5			; e = yes
	ret				; else ignore

ated1:	mov	param,0			; cursor to end of this line
	call	atel			; erase cursor to end of line
	add	y_coord,8		; look at next line
	mov	ax,ybot
	cmp	y_coord,ax		; are we at the end now?
	ja	ated6			; a = yes
	mov	x_coord,0		; start of line is here
	jmp	ated1			; do through last line

ated3:	and	y_coord,not 7		; modulo 8x8 char cells
	mov	cx,y_coord		; start of screen to cursor
	shr	cx,1			; char lines at 8 dots/char
	shr	cx,1
	shr	cx,1
	dec	cx			; omit current line= # whole lines
	or	cx,cx			; any whole lines?
	jle	ated3b			; le = no
	mov	y_coord,7		; start at the top line
ated3a:	push	cx
	mov	param,2			; entire line
	call	atel			; erase entire line
	add	y_coord,8		; next line
	pop	cx
	loop	ated3a
ated3b:	mov	param,1			; start of line to cursor
	call	atel			; erase to cursor on this (last) line
	jmp	short ated6

ated5:	call	tekcls			; erase whole screen

ated6:	mov	al,rdbuf		; spacing control
	mov	spcontrol,al
	pop	y_coord
	pop	x_coord
	call	remcursor		; remove last cursor
	call	setcursor		; set cursor to original position
	ret
ated	endp

atech	proc	near			; erase Pn chars from cursor to eol
	mov	al,spcontrol		; preserve space control
	mov	rdbuf,al		; save here
	mov	spcontrol,1		; turn on destructive space
	push	x_coord
	push	y_coord			; save cursor
	mov	cx,x_coord
	and	cx,not 7		; modulo 8x8 cells
	mov	ax,xmax
	sub	ax,cx			; number of chars remaining on line
	shr	ax,1
	shr	ax,1
	shr	ax,1
	inc	ax			; count cursor cell
	mov	cx,param		; how many chars to erase
	or	cx,cx
	jz	atech1			; z = zero, use one
	inc	cx
atech1:	cmp	ax,cx			; want more than line length?
	jae	atech2			; ae = no
	mov	cx,ax			; clip at right margin
	or	cx,cx
	jle	atech3			; le = nothing to do
atech2:	push	cx
	mov	al,' '
	call	outscrn			; write spaces
	pop	cx
	loop	atech2
atech3:	mov	al,rdbuf		; spacing control
	mov	spcontrol,al
	pop	y_coord
	pop	x_coord
	call	remcursor		; remove last cursor
	call	setcursor		; set cursor to original position
	ret
atech	endp

atel	proc	near			; erase on this line
	call	remcursor		; remove cursor
	push	x_coord
	push	y_coord
	cmp	param,0			; cursor to end of line?
	je	atel1			; e = yes
	cmp	param,1			; start of line to cursor?
	je	atel3			; e = yes
	cmp	param,2			; whole line?
	jne	atel5			; ne = no, fail
	mov	x_coord,0		; erase entire line

atel1:	mov	cx,xmax			; cursor to end of line
	mov	ax,x_coord
	and	ax,not 7		; modulo 8x8 cells
	sub	cx,ax
	shr	cx,1
	shr	cx,1
	shr	cx,1			; 8 dots/char
	inc	cx			; count the cursor cell
	or	cx,cx
	jle	atel5			; le = do nothing
	mov	al,spcontrol		; preserve space control
	mov	rdbuf,al		; save here
	mov	spcontrol,1		; turn on destructive space
atel2:	push	cx			; start of line to cursor
	mov	al,' '
	call	outscrn
	pop	cx
	loop	atel2
	mov	al,rdbuf		; space control
	mov	spcontrol,al		; restored
atel5:	pop	y_coord
	pop	x_coord
	call	remcursor		; remove last cursor
	call	setcursor		; set cursor to original position
	ret
atel3:	mov	cx,x_coord		; start of line to cursor
	shr	cx,1
	shr	cx,1
	shr	cx,1
	inc	cx			; count cursor cell
	mov	x_coord,0		; go to start of line
	jmp	atel2			; do the loops
atel	endp
code2	ends
	end
