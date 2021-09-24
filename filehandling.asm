	NAME	mssfil
; File MSSFIL.ASM
	include symboldefs.h
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
; 27 August 1992 version 3.13
; 6 Sept 1991 version 3.11
; 2 March 1991 version 3.10

	public	buff, gofil, ptchr, gtchr, getfil, gtnfil, doenc, dodec
	public	encbuf, decbuf, diskio, auxfile, fparse, prtasz, prtscr
	public	strlen, strcat, strcpy, tfilsz, templp, latin1, charids
	public	L1cp437, L1cp850, L1cp860, L1cp863, L1cp865, unique
	public	cplatin, goopen, latininv, protlist, jpnxtof, templf
	public	jpnftox, echrcnt, rcvpathflg, sndpathflg, atfile, atflag
	public	L5cp866, lccp866r, k8cp866r, k7cp866r, cp866koi7, cp866koi8
	public	cp866lci, crcword, lastfsize

SIchar	equ	0fh
SOchar	equ	0eh
DLE	equ	10h

data	segment
	extrn	flags:byte, trans:byte, dtrans:byte, denyflg:word,dosnum:word
	extrn	oldkbt:word, oldper:word, filtst:byte, rdbuf:byte, fsta:byte
	extrn	curdsk:byte, fdate:byte, ftime:byte, wrpmsg:byte
	extrn	rfileptr:word, findkind:byte, rpathname:byte, rfilename:byte
	extrn	sendkind:byte

ermes4  db	'Unable to make unique name',0
ermes9	db	'Printer not ready',0
erms12	db	'Unable to create file ',0
erms13	db	'Error writing output file',0
infms5  db	'Renaming file to $'
infms6	db	cr,lf,'?Unable to open file$'
asmsg	db	' as $'
crlf	db	cr,lf,'$'
printer	db	'PRN',0
screen	db	'CON',0
vacuum	db	'NUL',0
loadhlp	db	'filename$'
				; DOS special chars allowed in filenames
spchar2	db	'$', 26h, 23h, 40h, 21h, 25h, 27H, '(', ')', '-', 7bh, 7dh
	db	5fh, 5eh, 7eh, 60h
spc2len	equ	$-spchar2

textctl	db	cr,lf,tab,bell,ff,ctlz	; controls allowed in text files
textctlen equ	$-textctl
	even
filflg	db	0		; input buffer has data, if non-zero
rptct	db	1		; number of times it's repeated
dblbyte	db	0		; first of two bytes in a pair
dblbyteflg db	0		; non-zero if processing second byte of pair
DLEseen	db	0
shiftstate db	0		; locking shift (0 = unshifted, 80h = shifted)
decoutp	dw	0		; ptr to proc to dump decode output buffer
encinp	dw	0		; ptr to proc to refill encode input buffer
dchrcnt dw	0		; number of chars in the decode file buffer
echrcnt dw	0		; number of chars in the encode file buffer
dbufpnt dw	0		; position in file buffer, decoder
ebufpnt dw	0		; position in file buffer, encoder
crcword	dw	0		; CRC-16 accumulator
lastfsize dw	0,0		; size of last transferred file

	db	0		; this MUST directly preceed decbuf, jpnwrite
decbuf	db	decbuflen dup (0) ; decoding source buffer
	db	0		; safety for possible null terminator
encbuf	db	encbuflen dup (0) ; encoding source buffer
	db	0		; safety for possible null terminator
protlist db	32 dup (0) 	; list of protected control codes (if = 0)

tfilsz	dw	0,0		; bytes transferred (double word qty)
nmoflg	db	0		; have override filename, if non-zero
templp	db	65 dup (0)	; temp for local path part
templf	db	14 dup (0)	; temp for local filename part
temprp	db	65 dup (0)	; temp for remote path part
temprf	db	14 dup (0)	; temp for remote filename part
auxfile	db	65 dup (0)	; auxillary filename for general use
atfile	db	67 dup (0)	; at sign sending source file
atflag	db	0		; non-zero if using at sign file sending
diskio	filest	<>		; for ordinary file transfers
buff	db	buffsz dup (?)	; use as our Disk Transfer Area
unum	dw	0		; unique filename generation number
ifdef	no_terminal
rcvpathflg db	0		; remove(0)/retain(1) remote paths on RECEIVE
else
rcvpathflg db	1		; remove(0)/retain(1) remote paths on RECEIVE
endif	; no_terminal		  BBS flavor gets no receive pathnames
sndpathflg db	0		; remove(0)/retain(1) local paths on SEND
temp	dw	0
				; charids: table of transfer char-set idents
charids dw	7		; qty, pointers to char set idents
	dw	chtrans,chlatin1,chlatin2,chhebiso,chcyrill,chjapan,chjapanold
chtrans	db	1,'A'		; Transparent: char count, ident
chlatin1 db	6,'I6/100'	; Latin1: char count, ident
chlatin2 db	6,'I6/101'	; Latin2: char count, ident
chhebiso db	6,'I6/138'	; Hebrew-ISO: char count, ident
chcyrill db	6,'I6/144'	; Cyrillic: char count, ident
chjapan	db	9,'I14/87/13'	; Japanese-EUC: char count, ident (new)
chjapanold db	7,'I14/87E'	; Japanese-EUC: char count, ident (obsolete)
				; end of charids info
;loadtab	db	1		; LOAD command table
;	mkeyw	'Transfer-character-set',0
;
;filtab	macro
;	cnt = 128
;	rept	128			; 128 idenity entries
;	db	cnt			; initialize table to 128 .. 255
;	cnt = cnt + 1
;	endm
;endm
;
;userin	equ	this byte		; LOAD command
;	filtab				; init table to idenity
;namein	db	20 dup (0)		; name of the character set
;userout	equ	this byte
;	filtab				; init table to idenity
;nameout db	20 dup (0)		; name of the character set
;tblptr	dw	0			; LOAD command
;xlines	dw	0			; LOAD command
;linecnt dw	0			; LOAD command
;badvalue db	cr,lf,'?Bad value on line $'

cacheptr	dw 0
cachelen	dw 0
cacheseg	dw 0
data	ends

data1	segment
; Translation tables for byte codes 0a0h..0ffh to map ISO 8859-1 to Code Pages
; Codes 00h-1fh are 7-bit controls (C0), codes 20h..7eh are ASCII, 7fh DEL is
; considered to be a control code, 80h..9fh are 8-bit controls (C1).
; Each table is 96 translatable bytes followed by the table size (96), the
; ISO announcer ident ('A' and a null here); LATIN5/Cyrillic uses 'L'.
; The decimal tables are from Frank da Cruz working with the formal IBM docs.
					; from ISO 8859-1 Latin-1 to Code Page
						; to CP437 United States
L1cp437	db	80h,81h,82h,83h,   84h,85h,86h,87h	; column 8
	db	88h,89h,8ah,8bh,   8ch,8dh,8eh,8fh
	db	90h,91h,92h,93h,   94h,95h,96h,97h	; column 9
	db	98h,99h,9ah,9bh,   9ch,9dh,9eh,9fh
	db	20h,0adh,9bh,9ch,  0fh,9dh,7ch,15h	; column 10
	db	22h,40h,0a6h,0aeh, 0aah,0c4h,3fh,2dh
	db	0f8h,0f1h,0fdh,33h, 27h,0e6h,14h,0fah	; column 11
	db	2ch,31h,0a7h,0afh, 0ach,0abh,3fh,0a8h
	db	41h,41h,41h,41h,   8eh,8fh,92h,80h	; column 12
	db	45h,90h,45h,45h,   49h,49h,49h,49h
	db	44h,0a5h,4fh,4fh,  4fh,4fh,99h,58h	; column 13
	db	4fh,55h,55h,55h,   9ah,59h,3fh,0e1h
	db	85h,0a0h,83h,61h,  84h,86h,91h,87h	; column 14
	db	8ah,82h,88h,89h,   8dh,0a1h,8ch,8bh
	db	3fh,0a4h,95h,0a2h, 93h,6fh,94h,0f6h	; column 15
	db	6fh,97h,0a3h,96h,  81h,79h,3fh,98h
	db	96,'A',0			; 96 byte set, letter ident

						; to CP850 Multilingual
L1cp850	db	80h,81h,82h,83h,   84h,85h,86h,87h	; column 8
	db	88h,89h,8ah,8bh,   8ch,8dh,8eh,8fh
	db	90h,91h,92h,93h,   94h,95h,96h,97h	; column 9
	db	98h,99h,9ah,9bh,   9ch,9dh,9eh,9fh
	db	20h,0adh,0bdh,9ch,  0cfh,0beh,0ddh,0f5h	; column 10
	db	0f9h,0b8h,0a6h,0aeh, 0aah,0f0h,0a9h,0eeh
	db	0f8h,0f1h,0fdh,0fch, 0efh,0e6h,0f4h,0fah ; column 11
	db	0f7h,0fbh,0a7h,0afh, 0ach,0abh,0f3h,0a8h
	db	0b7h,0b5h,0b6h,0c7h, 8eh,8fh,92h,80h	; column 12
	db	0d4h,90h,0d2h,0d3h, 0deh,0d6h,0d7h,0d8h
	db	0d1h,0a5h,0e3h,0e0h, 0e2h,0e5h,99h,9eh	; column 13
	db	9dh,0ebh,0e9h,0eah, 9ah,0edh,0e8h,0e1h
	db	85h,0a0h,83h,0c6h,  84h,86h,91h,87h	; column 14
	db	8ah,82h,88h,89h,    8dh,0a1h,8ch,8bh
	db	0d0h,0a4h,95h,0a2h, 93h,0e4h,94h,0f6h	; column 15
	db	9bh,97h,0a3h,96h,   81h,0ech,0e7h,98h
	db	96,'A',0			; 96 byte set, letter ident

						; to CP860 Portugal
L1cp860	db	80h,81h,82h,83h,   84h,85h,86h,87h	; column 8
	db	88h,89h,8ah,8bh,   8ch,8dh,8eh,8fh
	db	90h,91h,92h,93h,   94h,95h,96h,97h	; column 9
	db	98h,99h,9ah,9bh,   9ch,9dh,9eh,9fh
	db	20h,0adh,9bh,9ch,  0fh,59h,7ch,15h	; column 10
	db	22h,40h,0a6h,0aeh, 0aah,0c4h,3fh,2dh
	db	0f8h,0f1h,0fdh,33h, 27h,0e6h,14h,0fah	; column 11
	db	2ch,31h,0a7h,0afh, 0ach,0abh,3fh,0a8h
	db	91h,86h,8fh,8eh,   41h,41h,41h,80h	; column 12
	db	92h,90h,89h,45h,   8bh,98h,49h,49h
	db	44h,0a5h,0a9h,9fh, 8ch,99h,4fh,58h	; column 13
	db	4fh,9dh,96h,55h,   9ah,59h,3fh,0e1h
	db	85h,0a0h,83h,84h,  61h,61h,61h,87h	; column 14
	db	8ah,82h,88h,65h,   8dh,0a1h,69h,69h
	db	3fh,0a4h,95h,0a2h, 93h,94h,6fh,0f6h	; column 15
	db	6fh,97h,0a3h,75h,  81h,79h,3fh,79h
	db	96,'A',0			; 96 byte set, letter ident

						; to CP861 Iceland
L1cp861	db	80h,0fch,82h,83h,  84h,85h,86h,87h	; column 8
	db	88h,89h,8ah,8bh,   8ch,8dh,8eh,8fh
	db	90h,91h,92h,93h,   94h,95h,96h,97h	; column 9
	db	98h,99h,9ah,9bh,   9ch,9dh,9eh,9fh
	db	20h,0adh,43h,9ch,  0fh,59h,7ch,15h	; column 10
	db	22h,3fh,0a6h,0aeh,  0aah,16h,3fh,2dh
	db	0f8h,0f1h,0fdh,33h, 27h,0e6h,14h,0fah	; column 11
	db	2ch,31h,3fh,0afh,  0ach,0abh,3fh,0a8h
	db	41h,0a4h,41h,41h,  8eh,8fh,92h,80h	; column 12
	db	45h,90h,45h,45h,   49h,0a5h,49h,49h
	db	8bh,4eh,4fh,0a6h,  4fh,4fh,99h,58h	; column 13
	db	9dh,55h,0a7h,55h,  9ah,97h,8dh,0e1h
	db	85h,0a0h,83h,61h,  84h,86h,91h,87h	; column 14
	db	8ah,82h,88h,89h,   69h,0a1h,69h,69h
	db	8ch,6eh,6fh,0a2h,  93h,6fh,94h,0f6h	; column 15
	db	9bh,75h,0a3h,96h,  81h,98h,95h,79h
	db	96,'A',0			; 96 byte set, letter ident

						; to CP863 Canada-French
L1cp863	db	80h,81h,82h,83h,   84h,85h,86h,87h	; column 8
	db	88h,89h,8ah,8bh,   8ch,8dh,8eh,8fh
	db	90h,91h,92h,93h,   94h,95h,96h,97h	; column 9
	db	98h,99h,9ah,9bh,   9ch,9dh,9eh,9fh
	db	20h,3fh,9bh,9ch,   98h,59h,0a0h,8fh	; column 10
	db	0a4h,40h,61h,0aeh, 0aah,0c4h,3fh,0a7h
	db	0f8h,0f1h,0fdh,0a6h, 0a1h,0e6h,86h,0fah	; column 11
	db	0a5h,31h,6fh,0afh, 0ach,0abh,0adh,3fh
	db	8eh,41h,84h,41h,   41h,41h,41h,80h	; column 12
	db	91h,90h,92h,94h,   49h,49h,0a8h,95h
	db	44h,4eh,4fh,4fh,   99h,4fh,4fh,58h	; column 13
	db	4fh,9dh,55h,9eh,   9ah,59h,3fh,0e1h
	db	85h,61h,83h,61h,   61h,61h,61h,87h	; column 14
	db	8ah,82h,88h,89h,   69h,69h,8ch,8bh
	db	3fh,6eh,6fh,0a2h,  93h,6fh,6fh,0f6h	; column 15
	db	6fh,97h,0a3h,96h,  81h,79h,3fh,79h
	db	96,'A',0			; 96 byte set, letter ident
						; to CP865 Norway
L1cp865	db	80h,81h,82h,83h,   84h,85h,86h,87h	; column 8
	db	88h,89h,8ah,8bh,   8ch,8dh,8eh,8fh
	db	90h,91h,92h,93h,   94h,95h,96h,97h	; column 9
	db	98h,99h,9ah,9bh,   9ch,9dh,9eh,9fh
	db	20h,0adh,3fh,9ch,  0afh,59h,7ch,15h	; column 10
	db	22h,40h,0a6h,0aeh, 0aah,0c4h,3fh,0c4h
	db	0f8h,0f1h,0fdh,33h, 27h,0e6h,14h,0fah	; column 11
	db	2ch,31h,0a7h,03fh, 0ach,0abh,3fh,0a8h
	db	41h,41h,41h,41h,   8eh,8fh,92h,80h	; column 12
	db	45h,90h,45h,45h,   49h,49h,49h,49h
	db	44h,0a5h,4fh,4fh,  4fh,4fh,99h,58h	; column 13
	db	9dh,55h,55h,55h,  9ah,59h,3fh,0e1h
	db	85h,0a0h,83h,61h,  84h,86h,91h,87h	; column 14
	db	8ah,82h,88h,89h,   8dh,0a1h,8ch,8bh
	db	3fh,0a4h,95h,0a2h, 93h,6fh,94h,0f6h	; column 15
	db	9bh,97h,0a3h,96h,  81h,79h,3fh,98h
	db	96,'A',0			; 96 byte set, letter ident
							; Latin2 to CP852
L2cp852	db 174,175,176,177,178,179,180,185,186,187,188,191,192,193,194,195
	db 196,197,200,201,202,203,204,205,206,217,218,219,220,223,240,254
	db 255,164,244,157,207,149,151,245,249,230,184,155,141,170,166,189
	db 248,165,242,136,239,150,152,243,247,231,173,156,171,241,167,190
	db 232,181,182,198,142,145,143,128,172,144,168,211,183,214,215,210
	db 209,227,213,224,226,138,153,158,252,222,233,235,154,237,221,225
	db 234,160,131,199,132,146,134,135,159,130,169,137,216,161,140,212
	db 208,228,229,162,147,139,148,246,253,133,163,251,129,236,238,250
	db	96,'B',0			; 96 byte set, letter ident

				; Hebrew-ISO to Code Page 862, GLeft
HIcp862	db 158,159,160,161,162,163,164,165,166,167,168,169,173,176,177,178
	db 179,180,181,182,183,184,185,186,187,188,189,190,191,192,193,194
	db 255,195,155,156,196,157,197,198,199,200,201,174,170,202,203,204
	db 248,241,253,206,207,230,208,249,209,210,246,175,172,171,211,212
	db 213,214,215,216,217,218,219,220,221,222,223,224,225,226,227,228
	db 229,231,232,233,234,235,236,237,238,239,240,242,243,244,245,205
	db 128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143
	db 144,145,146,147,148,149,150,151,152,153,154,247,250,251,252,254
	db	96,'H',0

							; Latin5 to CP866
L5cp866	db	80h,81h,82h,83h,   84h,85h,86h,87h	; column 8
	db	88h,89h,8ah,8bh,   8ch,8dh,8eh,8fh
	db	90h,91h,92h,93h,   94h,95h,96h,97h	; column 9
	db	98h,99h,9ah,9bh,   9ch,9dh,9eh,9fh
	db	0ffh,0f0h,3fh,3fh,  0f2h,53h,49h,4fh	; column 10
	db	4ah,3fh,3fh,48h,   4bh,2dh,0f6h,3fh
	db	80h,81h,82h,83h,   84h,85h,86h,87h	; column 11
	db	88h,89h,8ah,8bh,   8ch,8dh,8eh,8fh
	db	90h,91h,92h,93h,   94h,95h,96h,97h	; column 12
	db	98h,99h,9ah,9bh,   9ch,9dh,9eh,9fh
	db	0a0h,0a1h,0a2h,0a3h,0a4h,0a5h,0a6h,0a7h ; column 13
	db	0a8h,0a9h,0aah,0abh,0ach,0adh,0aeh,0afh
	db	0e0h,0e1h,0e2h,0e3h,0e4h,0e5h,0e6h,0e7h ; column 14
	db	0e8h,0e9h,0eah,0ebh,0ech,0edh,0eeh,0efh
	db	0fch,0f1h,3fh,3fh, 0f3h,73h,69h,0f5h	; column 15
	db	6ah,3fh,3fh,68h,   6bh,15h,0f7h,3fh
	db	96,'L',0			; 96 byte set, Latin5/Cyrillic

;yl143[]   /* Latin-1 to IBM Code Page 437 */
; Although the IBM CDRA does not include an official translation between CP437
; and ISO Latin Alphabet 1,it does include an official,invertible
; translation between CP437 and CP850 (page 196),and another from CP850 to
; Latin-1 (CP819) (page 153).  This translation was obtained with a two-step
; process based on those tables.

iL1cp437 db 199,252,233,226,228,224,229,231,234,235,232,239,238,236,196,197
	db 201,230,198,244,246,242,251,249,255,214,220,162,163,165,215,159
	db 225,237,243,250,241,209,170,186,191,174,172,189,188,161,171,187
	db 155,156,157,144,151,193,194,192,169,135,128,131,133,248,216,147
	db 148,153,152,150,145,154,227,195,132,130,137,136,134,129,138,164
	db 240,208,202,203,200,158,205,206,207,149,146,141,140,166,204,139
	db 211,223,212,210,245,213,181,254,222,218,219,217,253,221,175,180
	db 173,177,143,190,20,21,247,184,176,168,183,185,179,178,142,160
	db 96,'A',0				; 96 byte set,letter ident

;yl185[]   /* Latin-1 to IBM Code Page 850 */
; This is IBM's official invertible translation.  Reference: IBM Character
; Data Representation Architecture (CDRA),Level 1, Registry, SC09-1291-00
; (1990), p.152.  (Note: Latin-1 is IBM Code Page 00819.)
iL1cp850 db 186,205,201,187,200,188,204,185,203,202,206,223,220,219,254,242
	db 179,196,218,191,192,217,195,180,194,193,197,176,177,178,213,159
	db 255,173,189,156,207,190,221,245,249,184,166,174,170,240,169,238
	db 248,241,253,252,239,230,244,250,247,251,167,175,172,171,243,168
	db 183,181,182,199,142,143,146,128,212,144,210,211,222,214,215,216
	db 209,165,227,224,226,229,153,158,157,235,233,234,154,237,232,225
	db 133,160,131,198,132,134,145,135,138,130,136,137,141,161,140,139
	db 208,164,149,162,147,228,148,246,155,151,163,150,129,236,231,152
	db 96,'A',0				; 96 byte set, letter ident

; invertable Latin-1 to CP861 
iL1cp861 db 199,252,233,226,228,224,229,231,234,235,232,239,238,236,196,197
	db 201,230,198,244,246,242,251,249,255,214,220,162,163,165,215,159
	db 225,237,243,250,241,209,170,186,191,174,172,189,188,161,171,187
	db 155,156,157,144,151,193,194,192,169,135,128,131,133,248,216,147
	db 148,164,152,150,145,154,227,195,132,130,137,136,134,165,138,164
	db 139,208,202,166,200,158,205,206,157,149,167,141,140,151,141,139
	db 211,223,212,210,245,213,181,254,222,218,219,217,253,221,175,180
	db 140,177,143,190, 20, 21,247,184,155,168,183,185,179,152,149,160
	db 96,'A',0				; 96 byte set, letter ident


; 128 byte translation tables from Code Pages to ISO 8859-1 Latin1 or Latin5
; For GRight only (high bit set).
							; from Code Page 437
cp437L1	db	0c7h,0fch,0e9h,0e2h,0e4h,0e0h,0e5h,0e7h ; column 8
	db	0eah,0ebh,0e8h,0efh,0eeh,0ech,0c4h,0c5h
	db	0c9h,0e6h,0c6h,0f4h,0f6h,0f2h,0fbh,0f9h ; column 9
	db	0ffh,0d6h,0dch,0a2h,0a3h,0a5h,3fh,3fh
	db	0e1h,0edh,0f3h,0fah,0f1h,0d1h,0aah,0bah ; column 10
	db	0bfh,3fh,0ach,0bdh, 0bch,0a1h,0abh,0bbh
	db	16 dup (3fh)				 ; column 11
	db	16 dup (3fh)				 ; column 12
	db	16 dup (3fh)				 ; column 13
	db	3fh,0dfh,4 dup (3fh),		0b5h,3fh ; column 14
	db	5 dup(3fh),		    0f8h,3fh,3fh
	db	3fh,0b1h,4 dup (3fh),		0f7h,3fh ; column 15
	db	0b0h,0b7h,0b7h,3fh,3fh,	    0b2h,3fh,3fh
							 ; from Code Page 850
cp850L1	db	0c7h,0fch,0e9h,0e2h,0e4h,0e0h,0e5h,0e7h ; column 8
	db	0eah,0ebh,0e8h,0efh,0eeh,0ech,0c4h,0c5h
	db	0c9h,0e6h,0c6h,0f4h,0f6h,0f2h,0fbh,0f9h ; column 9
	db	0ffh,0d6h,0dch,0f8h,0a3h,0d8h,0d7h,3fh
	db	0e1h,0edh,0f3h,0fah,0f1h,0d1h,0aah,0bah ; column 10
	db	0bfh,0aeh,0ach,0bdh,0bch,0a1h,0abh,0bbh
	db	5 dup (3fh),             0c1h,0c2h,0c0h ; column 11
	db	0a9h,4 dup (3fh),	  0a2h,0a5h,3fh
	db	6 dup (3fh),0e3h,0c3h,7 dup (3fh),0a4h	 ; column 12
	db	0f0h,0d0h,0cah,0cbh,0c8h,0b9h,0cdh,0ceh ; column 13
	db	0cfh, 4 dup (3fh),	   0a6h,0cch,3fh
	db	0d3h,0dfh,0d4h,0d2h, 0f5h,0d5h,0b5h,0feh ; column 14
	db	0deh,0dah,0dbh,0d9h, 0fdh,0ddh,0afh,0b4h
	db	0adh,0b1h,3dh,0beh,  0b6h,0a7h,0f7h,0b8h ; column 15
	db	0b0h,0a8h,0b7h,0b9h, 0b3h,0b2h,3fh,20h

							 ; from Code Page 860
cp860L1	db	0c7h,0fch,0e9h,0e2h, 0e3h,0e0h,0c1h,0e7h ; column 8
	db	0eah,0cah,0e8h,0cch, 0d4h,0ech,0c3h,0c2h
	db	0c9h,0c0h,0c8h,0f4h, 0f5h,0f2h,0dah,0f9h ; column 9
	db	0cdh,0d5h,0dch,0a2h, 0a3h,0d9h,3fh,0d3h
	db	0e1h,0edh,0f3h,0fah, 0f1h,0d1h,0aah,0bah ; column 10
	db	0bfh,0d2h,0ach,0bdh, 0bch,0a1h,0abh,0bbh
	db	16 dup (3fh)				 ; column 11
	db	16 dup (3fh)				 ; column 12
	db	16 dup (3fh)				 ; column 13
	db	3fh,0dfh, 4 dup (3fh),		0b5h,3fh ; column 14
	db	5 dup(3fh),		    0f8h,3fh,3fh
	db	3fh,0b1h, 4 dup (3fh),		0f7h,3fh ; column 15
	db	0b0h,0b7h,0b7h,3fh,  3fh,0b2h,3fh,3fh

							; from Code Page 861
cp861L1	db	0c7h,0fch,0e9h,0e2h, 0e4h,0e0h,0e5h,0e7h ; column 8
	db	0eah,0ebh,0e8h,0d0h, 0f0h,0deh,0c4h,0c5h
	db	0c9h,0e6h,0c6h,0f4h, 0f6h,0feh,0fbh,0ddh ; column 9
	db	0fdh,0d6h,0dch,0f8h, 0a3h,0d8h,3fh,3fh
	db	0e1h,0edh,0f3h,0fah, 0c1h,0cdh,0d3h,0dah ; column 10
	db	0bfh,3fh,0ach,0bdh,  0bch,0a1h,0abh,0bbh
	db	16 dup (3fh)				 ; column 11
	db	16 dup (3fh)				 ; column 12
	db	16 dup (3fh)				 ; column 13
	db	3fh,0dfh, 4 dup (3fh),		0b5h,3fh ; column 14
	db	5 dup(3fh),		    0f8h,3fh,3fh
	db	3fh,0b1h, 4 dup (3fh),		0f7h,3fh ; column 15
	db	0b0h,0b7h,0b7h,3fh,3fh,	    0b2h,3fh,3fh

							 ; from Code Page 863
cp863L1	db	0c7h,0fch,0e9h,0e2h, 0c2h,0e0h,0b6h,0e7h ; column 8
	db	0eah,0ebh,0e8h,0efh, 0eeh,3dh,0c0h,0a7h
	db	0c9h,0c8h,0cah,0f4h, 0cbh,0cfh,0fbh,0f9h ; column 9
	db	0a4h,0d4h,0dch,0a2h, 0a3h,0d9h,0dbh,3fh
	db	0a6h,0b4h,0f3h,0fah, 0a8h,0b8h,0b3h,0afh ; column 10
	db	0ceh,3fh,0ach,0bdh,  0bch,0beh,0abh,0bbh
	db	16 dup (3fh)				 ; column 11
	db	16 dup (3fh)				 ; column 12
	db	16 dup (3fh)				 ; column 13
	db	3fh,0dfh, 4 dup (3fh),		0b5h,3fh ; column 14
	db	5 dup(3fh),		    0f8h,3fh,3fh
	db	3fh,0b1h, 4 dup (3fh),		0f7h,3fh ; column 15
	db	0b0h,0b7h,0b7h,3fh,  3fh,0b2h,3fh,3fh
     							 ; from Code Page 865
cp865L1	db	0c7h,0fch,0e9h,0e2h, 0e4h,0e0h,0e5h,0e7h ; column 8
	db	0eah,0ebh,0e8h,0efh, 0eeh,0ech,0c4h,0c5h
	db	0c9h,0e6h,0c6h,0f4h, 0f6h,0f2h,0fbh,0f9h ; column 9
	db	0ffh,0d6h,0dch,0f8h, 0a3h,0d8h,3fh,3fh
	db	0e2h,0edh,0f3h,0fah, 0f1h,0d1h,0aah,0bah ; column 10
	db	0bfh,3fh,0ach,0bdh,  0bch,0a1h,0abh,0a4h
	db	16 dup (3fh)				 ; column 11
	db	16 dup (3fh)				 ; column 12
	db	16 dup (3fh)				 ; column 13
	db	3fh,0dfh, 4 dup (3fh),		0b5h,3fh ; column 14
	db	5 dup(3fh),		    0f8h,3fh,3fh
	db	3fh,0b1h, 4 dup (3fh),		0f7h,3fh ; column 15
	db	0b0h,0b7h,0b7h,3fh,  3fh,0b2h,3fh,3fh

					; from Code Page 852 to LATIN2
cp852L2	db 199,252,233,226,228,249,230,231,179,235,213,245,238,172,196,198
	db 201,197,229,244,246,165,181,166,182,214,220,171,187,163,215,232
	db 225,237,243,250,161,177,174,190,202,234,173,188,200,186,128,129
	db 130,131,132,133,134,193,194,204,170,135,136,137,138,175,191,139
	db 140,141,142,143,144,145,195,227,146,147,148,149,150,151,152,164
	db 240,208,207,203,239,210,205,206,236,153,154,155,156,222,217,157
	db 211,223,212,209,241,242,169,185,192,218,224,219,253,221,254,180
	db 158,189,178,183,162,167,247,184,176,168,255,251,216,248,159,160

					; Code Page 862 to Hebrew-ISO
cp862HI db 224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239
	db 240,241,242,243,244,245,246,247,248,249,250,162,163,165,128,129
	db 130,131,132,133,134,135,136,137,138,139,172,189,188,140,171,187
	db 141,142,143,144,145,146,147,148,149,150,151,152,153,154,155,156
	db 157,158,159,161,164,166,167,168,169,170,173,174,175,223,179,180
	db 182,184,185,190,191,192,193,194,195,196,197,198,199,200,201,202
	db 203,204,205,206,207,208,181,209,210,211,212,213,214,215,216,217
	db 218,177,219,220,221,222,186,251,176,183,252,253,254,178,255,160

					 ; from Code Page 866 to LATIN5
cp866L5	db	0b0h,0b1h,0b2h,0b3h, 0b4h,0b5h,0b6h,0b7h ; column 8
	db	0b8h,0b9h,0bah,0bbh, 0bch,0bdh,0beh,0bfh
	db	0c0h,0c1h,0c2h,0c3h, 0c4h,0c5h,0c6h,0c7h ; column 9
	db	0c8h,0c9h,0cah,0cbh, 0cch,0cdh,0ceh,0cfh
	db	0d0h,0d1h,0d2h,0d3h, 0d4h,0d5h,0d6h,0d7h ; column 10
	db	0d8h,0d9h,0dah,0dbh, 0dch,0ddh,0deh,0dfh
	db	16 dup (3fh)				 ; column 11
	db	16 dup (3fh)				 ; column 12
	db	16 dup (3fh)				 ; column 13
	db	0e0h,0e1h,0e2h,0e3h, 0e4h,0e5h,0e6h,0e7h ; column 14
	db	0e8h,0e9h,0eah,0ebh, 0ech,0edh,0eeh,0efh
	db	0a1h,0f1h,0a4h,0f4h, 0a7h,0f7h,0aeh,0feh ; column 15
	db	4 dup (3fh),	     0f0h,3fh,3fh,0a0h

;y43l1[]   /* IBM Code Page 437 to Latin-1 */
;  This table is the inverse of yl143[].
icp437L1 db 199,252,233,226,228,224,229,231,234,235,232,239,238,236,196,197
	db 201,230,198,244,246,242,251,249,255,214,220,162,163,165,215,159
	db 225,237,243,250,241,209,170,186,191,174,172,189,188,161,171,187
	db 155,156,157,144,151,193,194,192,169,135,128,131,133,248,216,147
	db 148,153,152,150,145,154,227,195,132,130,137,136,134,129,138,164
	db 240,208,202,203,200,158,205,206,207,149,146,141,140,166,204,139
	db 211,223,212,210,245,213,181,254,222,218,219,217,253,221,175,180
	db 173,177,143,190, 20, 21,247,184,176,168,183,185,179,178,142,160

;y85l1[]   /* IBM Code Page 850 to Latin-1 */
;  This is from IBM CDRA page 153.  It is the inverse of yl185[].
icp850L1 db 199,252,233,226,228,224,229,231,234,235,232,239,238,236,196,197
	db 201,230,198,244,246,242,251,249,255,214,220,248,163,216,215,159
	db 225,237,243,250,241,209,170,186,191,174,172,189,188,161,171,187
	db 155,156,157,144,151,193,194,192,169,135,128,131,133,162,165,147
	db 148,153,152,150,145,154,227,195,132,130,137,136,134,129,138,164
	db 240,208,202,203,200,158,205,206,207,149,146,141,140,166,204,139
	db 211,223,212,210,245,213,181,254,222,218,219,217,253,221,175,180
	db 173,177,143,190,182,167,247,184,176,168,183,185,179,178,142,160

;y86l1[]   /* IBM Code Page 861 to Latin-1 */
;  This table is the inverse of yl186[].
icp861L1 db 199,252,233,226,228,224,229,231,234,235,232,208,240,222,196,197
	db 201,230,198,244,246,254,251,221,253,214,220,248,163,216,215,159
	db 225,237,243,250,193,205,211,218,191,174,172,189,188,161,171,187
	db 155,156,157,144,151,193,194,192,169,135,128,131,133,248,216,147
	db 148,153,152,150,145,154,227,195,132,130,137,136,134,129,138,164
	db 240,208,202,203,200,158,205,206,207,149,146,141,140,166,204,139
	db 211,223,212,210,245,213,181,254,222,218,219,217,253,221,175,180
	db 173,177,143,190, 20, 21,247,184,176,168,183,185,179,178,142,160

UNK	equ	'?'

;Latin/Cyrillic -> CP866 Readable:
lccp866r db 196,179,192,217,191,218,195,193,180,194,197,176,177,178,211,216
	db 205,186,200,188,187,201,204,202,185,203,206,223,220,219,254,253
	db 255,240,132,131,242, 83, 73,244, 74,139,141,151,138, 45,246,135
	db 128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143
	db 144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159
	db 160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175
	db 224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239
	db 252,241,164,163,243,115,105,245,106,171,173,231,170,181,247,167

;Latin/Cyrillic -> CP866 Invertible:
lccp866i db 196,179,192,217,191,218,195,193,180,194,197,176,177,178,211,216
	db 205,186,200,188,187,201,204,202,185,203,206,223,220,219,254,253
	db 255,240,208,207,242,189,183,244,184,212,213,214,210,182,246,209
	db 128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143
	db 144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159
	db 160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175
	db 224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239
	db 252,241,221,215,243,199,190,245,198,249,250,251,248,181,247,222

;KOI8 to CP866 Readable:
k8cp866r db  128,129,130,131,132,133,134,135,136,137,138,139,140,141,142,143
	db  144,145,146,147,148,149,150,151,152,153,154,155,156,157,158,159
	db  UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK
	db  UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK
	db  238,160,161,230,164,165,228,163,229,168,169,170,171,172,173,174
	db  175,239,224,225,226,227,166,162,236,235,167,232,237,233,231,234
	db  158,128,129,150,132,133,148,131,149,136,137,138,139,140,141,142
	db  143,159,144,145,146,147,134,130,156,155,135,152,157,153,151,UNK

;KOI7 to CP866 Readable:
k7cp866r db   0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15
	 db  16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31
	 db  32, 33, 34, 35,253, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47
	 db  48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62,UNK
	 db  64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79
	 db  80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95
	 db 158,128,129,150,132,133,148,131,149,136,137,138,139,140,141,142
	 db 143,159,144,145,146,147,134,130,156,155,135,152,157,153,151,UNK

;CP866 Invertible -> Latin/Cyrillic:
cp866lci db 176,177,178,179,180,181,182,183,184,185,186,187,188,189,190,191
	db 192,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207
	db 208,209,210,211,212,213,214,215,216,217,218,219,220,221,222,223
	db 139,140,141,129,136,253,173,166,168,152,145,148,147,165,246,132
	db 130,135,137,134,128,138,248,245,146,149,151,153,150,144,154,163
	db 162,175,172,142,169,170,171,243,143,131,133,157,156,242,255,155
	db 224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239
	db 161,241,164,244,167,247,174,254,252,249,250,251,240,159,158,160

; CP866 to KOI7:
cp866koi7 db  97, 98,119,103,100,101,118,122,105,106,107,108,109,110,111,112
	db 114,115,116,117,102,104, 99,126,123,125, 39,121,120,124, 96,113
	db  97, 98,119,103,100,101,118,122,105,106,107,108,109,110,111,112
	db UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK
	db UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK
	db UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK
	db 114,115,116,117,102,104, 99,126,123,125, 39,121,120,124, 96,113
	db 101,101,UNK,UNK, 73, 73,117,117,UNK,UNK,UNK,UNK,UNK, 36,UNK, 32

; CP866 to KOI8:
cp866koi8 db 225,226,247,231,228,229,246,250,233,234,235,236,237,238,239,240
	db 242,243,244,245,230,232,227,254,251,253,223,249,248,252,224,241
	db 193,194,215,199,196,197,214,218,201,202,203,204,205,206,207,208
	db UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK
	db UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK
	db UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK,UNK
	db 210,211,212,213,198,200,195,222,219,221,223,217,216,220,192,209
	db 229,197,UNK,UNK, 73,105,245,213,UNK,UNK,UNK,UNK,UNK, 36,UNK, 32
data1	ends

;  L/C = ISO Latin/Cyrillic
;  CP866R = Readable      <-- use this for terminal emulation
;  CP866I = Invertible    <-- use this for file transfer
;  KOI8   = "Old" KOI-8   <-- use this for terminal emulation
;  KOI7   = Short KOI     <-- use this for terminal emulation
;
;KOI8 and KOI7 are used only as terminal character sets, so they only
;need to be readable.  So since we aren't worried about keyboarding, we
;only need five tables:
;
; CP866I -> L/C    (for file transfer) 
; L/C    -> CP866I (for file transfer) 
; L/C    -> CP866R (terminal emulation)
; KOI8   -> CP866R (terminal emulation)
; KOI7   -> CP866R (terminal emulation)
;
; L/C   CP866R  CP866I   KOI8   KOI7    UNICODE 
;  0       0       0       0      0      0x0000 
;  1       1       1       1      1      0x0001 
;  2       2       2       2      2      0x0002 
;  3       3       3       3      3      0x0003 
;  4       4       4       4      4      0x0004 
;  5       5       5       5      5      0x0005 
;  6       6       6       6      6      0x0006 
;  7       7       7       7      7      0x0007 
;  8       8       8       8      8      0x0008 
;  9       9       9       9      9      0x0009 
; 10      10      10      10     10      0x000A 
; 11      11      11      11     11      0x000B 
; 12      12      12      12     12      0x000C 
; 13      13      13      13     13      0x000D 
; 14      14      14      14     14      0x000E 
; 15      15      15      15     15      0x000F 
; 16      16      16      16     16      0x0010 
; 17      17      17      17     17      0x0011 
; 18      18      18      18     18      0x0012 
; 19      19      19      19     19      0x0013 
; 20      20      20      20     20      0x0014 
; 21      21      21      21     21      0x0015 
; 22      22      22      22     22      0x0016 
; 23      23      23      23     23      0x0017 
; 24      24      24      24     24      0x0018 
; 25      25      25      25     25      0x0019 
; 26      26      26      26     26      0x001A 
; 27      27      27      27     27      0x001B 
; 28      28      28      28     28      0x001C 
; 29      29      29      29     29      0x001D 
; 30      30      30      30     30      0x001E 
; 31      31      31      31     31      0x001F 
; 32      32      32      32     32      0x0020    SPACE 
; 33      33      33      33     33      0x0021    EXCLAMATION MARK 
; 34      34      34      34     34      0x0022    QUOTATION MARK 
; 35      35      35      35     35      0x0023    NUMBER SIGN 
; 36      36      36      36     36      0x0024    DOLLAR SIGN 
; 37      37      37      37     37      0x0025    PERCENT SIGN 
; 38      38      38      38     38      0x0026    AMPERSAND 
; 39      39      39      39     39      0x0027    APOSTROPHE 
; 40      40      40      40     40      0x0028    LEFT PARENTHESIS 
; 41      41      41      41     41      0x0029    RIGHT PARENTHESIS 
; 42      42      42      42     42      0x002A    ASTERISK 
; 43      43      43      43     43      0x002B    PLUS SIGN 
; 44      44      44      44     44      0x002C    COMMA 
; 45      45      45      45     45      0x002D    HYPHEN, MINUS SIGN 
; 46      46      46      46     46      0x002E    PERIOD, FULL STOP 
; 47      47      47      47     47      0x002F    SOLIDUS, SLASH 
; 48      48      48      48     48      0x0030    DIGIT ZERO 
; 49      49      49      49     49      0x0031    DIGIT ONE 
; 50      50      50      50     50      0x0032    DIGIT TWO 
; 51      51      51      51     51      0x0033    DIGIT THREE 
; 52      52      52      52     52      0x0034    DIGIT FOUR 
; 53      53      53      53     53      0x0035    DIGIT FIVE 
; 54      54      54      54     54      0x0036    DIGIT SIX 
; 55      55      55      55     55      0x0037    DIGIT SEVEN 
; 56      56      56      56     56      0x0038    DIGIT EIGHT 
; 57      57      57      57     57      0x0039    DIGIT NINE 
; 58      58      58      58     58      0x003A    COLON 
; 59      59      59      59     59      0x003B    SEMICOLON 
; 60      60      60      60     60      0x003C    LEFT ANGLE BRACKET 
; 61      61      61      61     61      0x003D    EQUALS SIGN 
; 62      62      62      62     62      0x003E    RIGHT ANGLE BRACKET 
; 63      63      63      63     63      0x003F    QUESTION MARK 
; 64      64      64      64     64      0x0040    COMMERCIAL AT SIGN 
; 65      65      65      65     65      0x0041    CAPITAL LETTER A 
; 66      66      66      66     66      0x0042    CAPITAL LETTER B 
; 67      67      67      67     67      0x0043    CAPITAL LETTER C 
; 68      68      68      68     68      0x0044    CAPITAL LETTER D 
; 69      69      69      69     69      0x0045    CAPITAL LETTER E 
; 70      70      70      70     70      0x0046    CAPITAL LETTER F 
; 71      71      71      71     71      0x0047    CAPITAL LETTER G 
; 72      72      72      72     72      0x0048    CAPITAL LETTER H 
; 73      73      73      73     73      0x0049    CAPITAL LETTER I 
; 74      74      74      74     74      0x004A    CAPITAL LETTER J 
; 75      75      75      75     75      0x004B    CAPITAL LETTER K 
; 76      76      76      76     76      0x004C    CAPITAL LETTER L 
; 77      77      77      77     77      0x004D    CAPITAL LETTER M 
; 78      78      78      78     78      0x004E    CAPITAL LETTER N 
; 79      79      79      79     79      0x004F    CAPITAL LETTER O 
; 80      80      80      80     80      0x0050    CAPITAL LETTER P 
; 81      81      81      81     81      0x0051    CAPITAL LETTER Q 
; 82      82      82      82     82      0x0052    CAPITAL LETTER R 
; 83      83      83      83     83      0x0053    CAPITAL LETTER S 
; 84      84      84      84     84      0x0054    CAPITAL LETTER T 
; 85      85      85      85     85      0x0055    CAPITAL LETTER U 
; 86      86      86      86     86      0x0056    CAPITAL LETTER V 
; 87      87      87      87     87      0x0057    CAPITAL LETTER W 
; 88      88      88      88     88      0x0058    CAPITAL LETTER X 
; 89      89      89      89     89      0x0059    CAPITAL LETTER Y 
; 90      90      90      90     90      0x005A    CAPITAL LETTER Z 
; 91      91      91      91     91      0x005B    LEFT SQUARE BRACKET 
; 92      92      92      92     92      0x005C    REVERSE SOLIDUS, BACKSLASH 
; 93      93      93      93     93      0x005D    RIGHT SQUARE BRACKET 
; 94      94      94      94     94      0x005E    CIRCUMFLEX ACCENT 
; 95      95      95      95     95      0x005F    LOW LINE, UNDERLINE 
; 96      96      96      96     64      0x0060    GRAVE ACCENT 
; 97      97      97      97     65      0x0061    SMALL LETTER a 
; 98      98      98      98     66      0x0062    SMALL LETTER b 
; 99      99      99      99     67      0x0063    SMALL LETTER c 
;100     100     100     100     68      0x0064    SMALL LETTER d 
;101     101     101     101     69      0x0065    SMALL LETTER e 
;102     102     102     102     70      0x0066    SMALL LETTER f 
;103     103     103     103     71      0x0067    SMALL LETTER g 
;104     104     104     104     72      0x0068    SMALL LETTER h 
;105     105     105     105     73      0x0069    SMALL LETTER i 
;106     106     106     106     74      0x006A    SMALL LETTER j 
;107     107     107     107     75      0x006B    SMALL LETTER k 
;108     108     108     108     76      0x006C    SMALL LETTER l 
;109     109     109     109     77      0x006D    SMALL LETTER m 
;110     110     110     110     78      0x006E    SMALL LETTER n 
;111     111     111     111     79      0x006F    SMALL LETTER o 
;112     112     112     112     80      0x0070    SMALL LETTER p 
;113     113     113     113     81      0x0071    SMALL LETTER q 
;114     114     114     114     82      0x0072    SMALL LETTER r 
;115     115     115     115     83      0x0073    SMALL LETTER s 
;116     116     116     116     84      0x0074    SMALL LETTER t 
;117     117     117     117     85      0x0075    SMALL LETTER u 
;118     118     118     118     86      0x0076    SMALL LETTER v 
;119     119     119     119     87      0x0077    SMALL LETTER w 
;120     120     120     120     88      0x0078    SMALL LETTER x 
;121     121     121     121     89      0x0079    SMALL LETTER y 
;122     122     122     122     90      0x007A    SMALL LETTER z 
;123     123     123     123     91      0x007B    LEFT BRACE 
;124     124     124     124     92      0x007C    VERTICAL BAR 
;125     125     125     125     93      0x007D    RIGHT BRACE 
;126     126     126     126     94      0x007E    TILDE 
;127     127     127     127    127      0x00A0    RUBOUT, DELETE 
;128     196     196     128      0 
;129     179     179     129      1 
;130     192     192     130      2 
;131     217     217     131      3 
;132     191     191     132      4 
;133     218     218     133      5 
;134     195     195     134      6 
;135     193     193     135      7 
;136     180     180     136      8 
;137     194     194     137      9 
;138     197     197     138     10 
;139     176     176     139     11 
;140     177     177     140     12 
;141     178     178     141     13 
;142     211     211     142     14 
;143     216     216     143     15 
;144     205     205     144     16 
;145     186     186     145     17 
;146     200     200     146     18 
;147     188     188     147     19 
;148     187     187     148     20 
;149     201     201     149     21 
;150     204     204     150     22 
;151     202     202     151     23 
;152     185     185     152     24 
;153     203     203     153     25 
;154     206     206     154     26 
;155     223     223     155     27 
;156     220     220     156     28 
;157     219     219     157     29 
;158     254     254     158     30 
;159     253     253     159     31             
;160     255     255     UNK     32      0x0401    No-break space 
;161     240     240     229    101      0x0402    Cyrillic Io 
;162     132     208     UNK    UNK      0x0403    Serbocroation Dje 
;163     131     207     UNK    UNK      0x0404    Macedonian Gje 
;164     242     242     UNK    UNK      0x0405    Ukranian Ie 
;165      83     189     83      83      0x0406    Macedonian Dze 
;166      73     183      73     73      0x0407    Cyrillic I 
;167     244     244     73      73      0x0408    Ukranian Yi 
;168      74     184      74     74      0x0409    Cyrillic Je 
;169     139     212     UNK    UNK      0x040A    Cyrillic Lje 
;170     141     213     UNK    UNK      0x040B    Cyrillic Nje 
;171     151     214     UNK    UNK      0x040C    Serbocroation Chje 
;172     138     210     235    107      0x00AD    Macedonian Kje 
;173      45     182     UNK     45      0x040E    Soft hyphen 
;174     246     246     245    117      0x040F    Bielorussian Short U 
;175     135     209     UNK    UNK      0x0410    Cyrillic Dze 
;176     128     128     225     97      0x0411    Cyrillic A 
;177     129     129     226     98      0x0412    Cyrillic Be 
;178     130     130     247    119      0x0413    Cyrillic Ve 
;179     131     131     231    103      0x0414    Cyrillic Ghe 
;180     132     132     228    100      0x0415    Cyrillic De 
;181     133     133     229    101      0x0416    Cyrillic Ie 
;182     134     134     246    118      0x0417    Cyrillic Zhe 
;183     135     135     250    122      0x0418    Cyrillic Ze 
;184     136     136     233    105      0x0419    Cyrillic I 
;185     137     137     234    106      0x041A    Cyrillic Short I 
;186     138     138     235    107      0x041B    Cyrillic Ka 
;187     139     139     236    108      0x041C    Cyrillic El 
;188     140     140     237    109      0x041D    Cyrillic Em 
;189     141     141     238    110      0x041E    Cyrillic En 
;190     142     142     239    111      0x041F    Cyrillic O 
;191     143     143     240    112      0x0420    Cyrillic Pe 
;192     144     144     242    114      0x0421    Cyrillic Er 
;193     145     145     243    115      0x0422    Cyrillic Es 
;194     146     146     244    116      0x0423    Cyrillic Te 
;195     147     147     245    117      0x0424    Cyrillic U 
;196     148     148     230    102      0x0425    Cyrillic Ef 
;197     149     149     232    104      0x0426    Cyrillic Ha 
;198     150     150     227     99      0x0427    Cyrillic Tse 
;199     151     151     254    126      0x0428    Cyrillic Che 
;200     152     152     251    123      0x0429    Cyrillic Sha 
;201     153     153     253    125      0x042A    Cyrillic Shcha 
;202     154     154     255     39      0x042B    Cyrillic Hard Sign 
;203     155     155     249    121      0x042C    Cyrillic Yeri 
;204     156     156     248    120      0x042D    Cyrillic Soft Sign 
;205     157     157     252    124      0x042E    Cyrillic E 
;206     158     158     224     96      0x042F    Cyrillic Yu 
;207     159     159     241    113      0x0430    Cyrillic Ya 
;208     160     160     193     97      0x0431    Cyrillic a 
;209     161     161     194     98      0x0432    Cyrillic be 
;210     162     162     215    119      0x0433    Cyrillic ve 
;211     163     163     199    103      0x0434    Cyrillic ghe 
;212     164     164     196    100      0x0435    Cyrillic de 
;213     165     165     197    101      0x0436    Cyrillic ie 
;214     166     166     214    118      0x0437    Cyrillic zhe 
;215     167     167     218    122      0x0438    Cyrillic ze 
;216     168     168     201    105      0x0439    Cyrillic i 
;217     169     169     202    106      0x043A    Cyrillic Short i 
;218     170     170     203    107      0x043B    Cyrillic ka 
;219     171     171     204    108      0x043C    Cyrillic el 
;220     172     172     205    109      0x043D    Cyrillic em 
;221     173     173     206    110      0x043E    Cyrillic en 
;222     174     174     207    111      0x043F    Cyrillic o 
;223     175     175     208    112      0x0440    Cyrillic pe 
;224     224     224     210    114      0x0441    Cyrillic er 
;225     225     225     211    115      0x0442    Cyrillic es 
;226     226     226     212    116      0x0443    Cyrillic te 
;227     227     227     213    117      0x0444    Cyrillic u 
;228     228     228     198    102      0x0445    Cyrillic ef 
;229     229     229     200    104      0x0446    Cyrillic ha 
;230     230     230     195     99      0x0447    Cyrillic tse 
;231     231     231     222    126      0x0448    Cyrillic che 
;232     232     232     219    123      0x0449    Cyrillic sha 
;233     233     233     221    125      0x044A    Cyrillic shcha 
;234     234     234     223     39      0x044B    Cyrillic hard sign 
;235     235     235     217    121      0x044C    Cyrillic yeri 
;236     236     236     216    120      0x044D    Cyrillic soft sign 
;237     237     237     220    124      0x044E    Cyrillic e 
;238     238     238     192     96      0x044F    Cyrillic yu 
;239     239     239     209    113      0x2116    Cyrillic ya 
;240     252     252     UNK    UNK      0x0451    Number Acronym 
;241     241     241     197     10      0x0452    Cyrillic io 
;242     164     221     UNK    UNK      0x0453    Serbocroation dje 
;243     163     215     UNK    UNK      0x0454    Macedonian gje 
;244     243     243     UNK    UNK      0x0455    Ukranian ie 
;245     115     199     115     83      0x0456    Macedonian dze 
;246     105     190     105     73      0x0457    Cyrillic i 
;247     245     245     105     73      0x0458    Ukranian yi 
;248     106     198     106     74      0x0459    Cyrillic je 
;249     171     249     UNK    UNK      0x045A    Cyrillic lje 
;250     173     250     UNK    UNK      0x045B    Cyrillic nje 
;251     231     251     UNK    UNK      0x045C    Serbocroatian chje 
;252     170     248     203    107      0x00A7    Macedonian kje 
;253     181     181     UNK    UNK      0x045E    Paragraph sign 
;254     247     247     213    117      0x045F    Bielorussian short u 
;255     167     222     UNK    UNK                Cyrillic dze 

code1	segment
	extrn	isfile:far,decout:far, rfprep:far, rgetfile:far, newfn:near
extrn malloc:far
	assume	cs:code1
code1	ends

code	segment
	extrn	comnd:near
	extrn	ermsg:near,clrfln:far,frpos:near,kbpr:near,perpr:near

	assume  cs:code,ds:data,es:nothing

; Set DS:BX to the ISO Latin-1 table appropriate to the
; currently active Code Page. Defaults to CP437 if no CP found.
LATIN1	proc	near
	push	ax
	mov	ax,seg flags
	mov	DS,ax
	mov	ax,flags.chrset		; in segment data
	mov	bx,seg L1cp437
	mov	DS,bx			; set returned DS to table
	mov	bx,offset L1cp437	; assume CP437
	cmp	ax,437			; current Code Page is 437?
	je	latin1x			; e = yes
	mov	bx,offset L1cp850	; assume CP850
	cmp	ax,850			; current Code Page is 850?
	je	latin1x			; e = yes
	mov	bx,offset L1cp860	; assume CP860
	cmp	ax,860			; current Code Page is 860?
	je	latin1x			; e = yes
	mov	bx,offset L1cp861	; assume CP861
	cmp	ax,861			; current Code Page is 861?
	je	latin1x			; e = yes
	mov	bx,offset L2cp852	; assume CP852
	cmp	ax,852			; current Code Page is 852?
	je	latin1x			; e = yes
	mov	bx,offset HIcp862	; assume CP862
	cmp	ax,862			; current Code Page is 862?
	je	latin1x			; e = yes
	mov	bx,offset L1cp863	; assume CP863
	cmp	ax,863			; current Code Page is 863?
	je	latin1x			; e = yes
	mov	bx,offset L1cp865	; assume CP865
	cmp	ax,865			; current Code Page is 865?
	je	latin1x			; e = yes
	mov	bx,offset L5cp866	; assume CP866
	cmp	ax,866			; current Code Page is 866?
	je	latin1x			; e = yes
	mov	bx,offset L1cp437	; default to CP437
latin1x:pop	ax
	ret
LATIN1	endp

; Call after LATIN1. Revise DS:BX to point to invertible tables rather than
; readable translation tables. Does not change DS.
latininv proc	near
	push	ax
	push	ds
	mov	ax,seg trans
	mov	ds,ax
	cmp	trans.xchri,0		; readable (vs invertible)?
	pop	ds
	pop	ax
	je	latinvx			; e = yes, do nothing
	cmp	bx,offset L1cp437	; this table in use?
	jne	latinv1			; ne = no
	mov	bx,offset iL1cp437	; use invertible instead
	jmp	short latinvx
latinv1:cmp	bx,offset L1cp850	; this table in use?
	jne	latinv2			; ne = no
	mov	bx,offset iL1cp850	; use invertible instead
	jmp	short latinvx
latinv2:cmp	bx,offset L1cp861	; this table?
	jne	latinvx			; ne = no
	mov	bx,offset iL1cp861	; use invertible instead
latinvx:ret
latininv endp

; Set DS:BX to the table for Code Page to ISO 8859-1 Latin1/Latin5
cplatin proc	near
	push	ax
	mov	ax,seg flags
	mov	DS,ax
	mov	ax,flags.chrset
	mov	bx,seg cp437L1
	mov	DS,bx			; set returned DS to table
	mov	bx,offset cp437L1	; assume CP437
	cmp	ax,437			; current Code Page is 437?
	je	cplatx			; e = yes
	mov	bx,offset cp850L1	; assume CP850
	cmp	ax,850			; current Code Page is 850?
	je	cplatx			; e = yes
	mov	bx,offset cp860L1	; assume CP860
	cmp	ax,860			; current Code Page is 860?
	je	cplatx			; e = yes
	mov	bx,offset cp861L1	; assume CP861
	cmp	ax,861			; current Code Page is 861?
	je	cplatx			; e = yes
	mov	bx,offset cp852L2	; assume CP852
	cmp	ax,852			; current Code Page is 852?
	je	cplatx			; e = yes
	mov	bx,offset cp862HI	; assume CP862
	cmp	ax,862			; current Code Page is 862?
	je	cplatx			; e = yes
	mov	bx,offset cp863L1	; assume CP863
	cmp	ax,863			; current Code Page is 863?
	je	cplatx			; e = yes
	mov	bx,offset cp865L1	; assume CP865
	cmp	ax,865			; current Code Page is 865?
	je	cplatx			; e = yes
	mov	bx,offset cp866L5	; assume CP866 for LATIN5
	cmp	ax,866			; corrent Code Page is 866?
	je	cplatx			; e = yes
	mov	bx,offset cp437L1	; default to CP437
cplatx:	pop	ax
	ret
cplatin endp

; Call after CPLATIN. Revise DS:BX to point to invertible tables rather than
; readable translation tables.
cpinvert proc	near
	push	ds
	push	ax
	mov	ax,seg trans
	mov	ds,ax
	cmp	trans.xchri,0		; readable (vs invertible)?
	pop	ax
	pop	ds
	je	cpinverx		; e = yes, do nothing
	cmp	bx,offset cp437L1	; this table in use?
	jne	cpinver1		; ne = no
	mov	bx,offset icp437L1	; use invertible instead
	ret
cpinver1:cmp	bx,offset cp850L1	; this table in use?
	jne	cpinver2		; ne = no
	mov	bx,offset icp850L1	; use invertible instead
	ret
cpinver2:cmp	bx,offset cp861L1	; this table in use?
	jne	cpinverx		; ne = no
	mov	bx,offset icp861L1	; use invertible instead
cpinverx:ret
cpinvert endp

; Output the chars in a packet, called only by receiver code.
; Enter with SI equal to pktinfo structure pointer.
PTCHR:	mov	decoutp,offset outbuf  ; routine to call when buffer gets full
	jmp	short decode


; Dodecoding.
; Decode packet to buffer decbuf. Overflow of decbuf yields error ???
; Modifies regs BX, CX.
; Enter with SI equal to pktinfo structure pointer.
dodec	proc	near
	push	ax			; save reg
	mov	ah,dblbyteflg		; preserve state
	mov	al,dblbyte
	push	ax
	mov	al,shiftstate
	mov	ah,DLEseen
	push	ax
	mov	dblbyteflg,0		; init decode as doubles
	mov	shiftstate,0		; init shift states
	mov	DLEseen,0		; init escape
	mov	decoutp,offset dnulr	; routine to dump buffer (null)
	call	decode
	pop	ax
	mov	shiftstate,al		; restore decoder state
	mov	DLEseen,ah
	pop	ax
	mov	dblbyteflg,ah
	mov	dblbyte,al
	push	bx
	mov	bx,dbufpnt		; next char position
	mov	byte ptr [bx],0		; null terminator
	pop	bx
 	pop	ax
	ret
dodec	endp

dnulr:	mov	dbufpnt,di 		; point off end of buffer
	stc				; fail if needs this
	ret				; dummy buffer emptier

; Enter with [si].datlen = length of data, [si].datadr = dw address of data,
; DECOUTP = pointer to routine which writes output buffer
; Returns DBUFPNT = pointer to output buffer address (offset part).
; Trans.lshift is non-zero if locking shift encoding is active.
; DLEseen is non-zero if a DLE char (Control-P) is decoded while locking shift
; is active; under these circumstances DLE escapes DLE, SI, and SO to be
; data characters. Under locking shift rules SO (Control-N) shifts high bit
; data to non-high bit data (and we thus reverse this); SI (Control-O)
; cancels SO.
; Dblbyteflg is non-zero if the first of a byte pair has been obtained while
; performing Japanese translation; dblbyte is the first byte of the pair.
; All packets are decoded except I, S, and A types.
; Flushes output buffer before returning.
; Returns carry clear if success, otherwise carry set
decode	proc	near
	push	si
	push	di
	push	es
	push	dx
	push	ds
	pop	es
	cld				; forward direction
	mov	dchrcnt,decbuflen	; size of output buffer
	mov	dbufpnt,offset decbuf ; decoded data placed here pending output
	mov	decbuf,0		; nothing written yet
	mov	cx,[si].datlen		; length of source buffer data
	les	si,[si].datadr		; source buffer address to es:[si]
	mov	di,dbufpnt		; destination of data
	mov	bl,trans.squote		; regular quote char
	xor	dh,dh			; assume no quote char
	cmp	trans.ebquot,'N'	; any 8-bit quoting?
	je	decod1			; e = no quoting
	cmp	trans.ebquot,'Y'	; or not doing it?
	je	decod1			; e = no need to quote
	mov	dh,trans.ebquot		; otherwise use 8-bit quote char

decod1:	mov	rptct,1			; reset repeat count
	or	cx,cx			; any more chars in source?
	jg	decod2			; g = yes
	jmp	decod6			; else, we're through
decod2:	mov	al,es:[si]		; pick up a char
	inc	si
	dec	cx			; count number left
	cmp	al,trans.rptq		; repeat quote char?
	jne	dcod2a			; ne = no, continue processing it
	mov	al,es:[si]		; get the size
	inc	si
	dec	cx			; modify buffer count
	sub	al,20H			; make count numeric
	mov	rptct,al		; remember how many repetitions
	mov	al,es:[si]		; get the char to repeat
	inc	si
	dec	cx			; modify buffer count

dcod2a:	xor	ah,ah			; assume no 8-bit quote char
	or	dh,dh			; using 8-bit quoting?
	jz	decod3			; z = no
	cmp	al,dh			; is this the 8-bit quot char?
	jne	decod3			; ne = no
	mov	al,es:[si]		; yes, get the real character
	inc	si
	dec	cx			; decrement # chars in packet
	mov	ah,80H			; turn on high bit
decod3:	cmp	al,bl			; quote char?
	jne	decod4			; ne = no, proceed
	mov	al,es:[si]		; get the quoted character
	inc	si
	dec	cx			; decrement # of chars in packet
	or	ah,al			; save parity (combine with prefix)
	and	ax,807fh		; only parity in ah, remove it in al
	cmp	al,bl			; quote char?
	je	decod4			; e = yes, just go write it out
	cmp	al,dh			; 8-bit quote char?
	je	decod4			; e = yes, just go write it out
	cmp	trans.rptq,0		; disabled repeat quoting?
	je	decod3a			; e = yes, disabled
	cmp	al,trans.rptq		; repeat quote character?
	je	decod4			; e = yes, just write it out
decod3a:cmp	al,3fh			; char less than '?' ?
	jb	decod4			; b = yes; leave it intact
	cmp	al,5fh			; char greater than '_' ?
	ja	decod4			; a = yes; leave it alone
	add	al,40H			; make it a control char again
	and	al,7FH			; modulo 128 (includes DEL)
decod4:	xor	ah,shiftstate		; modify high bit by shiftstate
        or	al,ah			; or in parity

	cmp	trans.lshift,lock_disable ; locking shift disabled?
	je	decod5			; e = yes
	mov	ah,al
	xor	ah,shiftstate		; adjust high bit by shift state
	cmp	ah,DLE			; DLE?
	jne	dcod4c			; ne = no
	cmp	DLEseen,0		; has DLE been escaped (by DLE)?
	je	dcod4b			; e = no, make this the escape
	mov	DLEseen,0		; unescape now
	jmp	short decod5		; process the literal DLE
					; handle repeat counted DLE's
dcod4b:	shr	rptct,1			; divide by two, carry has lsb
	rcl	DLEseen,1		; pickup carry bit if odd number
	jmp	short decod5		; write the DLE's

dcod4c:	cmp	DLEseen,0		; DLE prefix seen?
	mov	DLEseen,0		; clear it now too
	jne	decod5			; ne = yes, prefixed, do literal
	cmp	ah,SIchar		; SI?
	jne	dcod4d			; ne = no
	mov	shiftstate,0		; say exiting shifted state
	jmp	decod1			; nothing to write
dcod4d:	cmp	ah,SOchar		; SO?
	jne	decod5			; ne = no
	mov	shiftstate,80h		; say entering shifted state
	jmp	decod1			; nothing to write

decod5:	push	cx
	mov	cl,rptct		; repeat count
	xor	ch,ch
	or	cl,cl
	jle	decod5c			; le = nothing to do (94 max)
	cmp	cx,dchrcnt		; needed vs space available
	jbe	decod5a			; be = enough space for rptct chars
	mov	cx,dchrcnt		; insufficient space, do dchrcnt
decod5a:sub	rptct,cl		; reduce number left to be written
	sub	dchrcnt,cx		; reduce output free space
	pushf				; save sub status flags
	shr	cx,1
	jnc	decod5b			; nc = an even number
	mov	[di],al			; store the odd byte
	inc	di
	jcxz	decod5d			; z = nothing else to write
decod5b:mov	ah,al			; make a copy for word writes
	push	bx			; source is es:[si], dest is ds:[di]
	push	es			; save and swap ds and es
	push	ds
	mov	bx,es
	pop	es			; old ds to es
	push	ds			; restore
	mov	ds,bx			; old es to ds
	rep	stosw			; store cx words
	pop	ds
	pop	es
	pop	bx
decod5d:popf				; recover flags from sub dchrcnt,cx
	jg	decod5c			; g = space remaining in output buffer
	push	dx			; flush output buffer
	push	bx
	push	ax			; save the char
	push	es
	call	decoutp			; output the buffer
	pop	es
	pop	ax			; recover repeated char
	pop	bx
	pop	dx
	jc	decod7			; c = error if disk is full
	mov	di,dbufpnt
	pop	cx
	jmp	short decod5		; see if more chars need be written
decod5c:pop	cx			; recover main loop counter
	jmp	decod1			; get next source character
	
decod6:	mov	dbufpnt,di    		; flush buffer before exiting decode
	push	cx
	push	es
	call	decoutp			; flush output buffer before final ret
	pop	es

	test	flags.remflg,dserial+dquiet ; serial/quiet mode display?
	jnz	decod7			; nz = yes, skip kbyte and % displays
	cmp	decoutp,offset outbuf	; decoding to disk?
	jne	decod7			; ne = no
	cmp	flags.xflg,0		; receiving to screen?
	jne	decod7			; ne = yes
	call	kbpr			; display kilobytes done
	call	perpr			; display percentage done

decod7:	pop	cx
	pop	dx
	pop	es
	pop	di
	pop	si
	ret				; return successfully if carry clear
decode	endp

outbuf	proc	near			; output decbuf, reset bufpnt & chrcnt
	mov	cx,decbuflen		; get full size of buffer
	sub	cx,dchrcnt		; minus space remaining = # to write
	jg	outbu2			; g = something to do
	jmp	outbf1
outbu2:	mov	dx,offset decbuf	; address of buffer
	cmp	trans.xtype,1		; File Type Binary?
	je	outbu5			; e = yes, no translation
	cmp	flags.destflg,dest_disk	; disk destination?
	je	outbu5			; e = yes, DOS will do it
	cmp	flags.eofcz,0		; end on Control-Z?
	je	outbu5			; e = no
	push	cx			; else map Control-Z to space
	push	di
	mov	di,seg decbuf
	mov	es,di			; data to es
	mov	di,dx			; scan buffer es:di, cx chars worth
	mov	al,ctlz			; look for Control-Z
	cld
outbu3:	repne	scasb
	jne	outbu4			; ne = found no Control-Z's
	mov	byte ptr [di-1],' '	; replace Control-Z with space
	jcxz	outbu4			; z = examined all chars
	jmp	short outbu3		; until examined everything
outbu4:	pop	di
	pop	cx
					; Character set translation section
outbu5:	cmp	trans.xtype,1		; File Type Binary?
	je	outbu7			; e = yes, no translation
	cmp	trans.xchset,xfr_xparent ; Transfer Transparent?
	je	outbu7			; e = yes, no translation
	cmp	trans.xchset,xfr_japanese ; Japanese-EUC?
	jne	outbu5a			; ne = no
	call	jpnwrite		; do special decoding
	jmp	outbu7
outbu5a:push	cx
	push	di
	push	es
	PUSH	DS
	call	latin1			; set DS:BX to xfr char set to CP table
	call	latininv		; select invertable or readable set
	mov	di,seg decbuf
	mov	es,di
	mov	di,offset decbuf	; scan this buffer
	cld
outbu6:	mov	al,es:[di]		; get a char, keep pointer fixed
	test	al,80h			; GRight?
	jnz	outbu6a			; nz = yes
	cmp	bx,offset iL1cp437	; using invertable Latin1 to CP437?
	jne	outbu6c			; ne = no
	cmp	ah,127			; 127 goes to 28?
	jne	outbu6e			; ne = no
	mov	al,28			; 127 to 28
	jmp	short outbu6b
outbu6e:cmp	al,21			; special case?
	ja	outbu6b			; a = no
	cmp	al,20			; special case?
	jb	outbu6b			; b = no
	mov	ah,al
	mov	al,244			; 20 to 244
	cmp	ah,21			; special case?
	jne	outbu6b			; ne = no
	mov	al,245			; preset one answer
	je	outbu6b			; e = yes, 21 to 245
	mov	al,244			; 22 to 244
	jmp	short outbu6b
outbu6c:cmp	bx,offset iL1cp850	; using invertible Latin1 to CP850?
	jne	outbu6b			; ne = no
	cmp	al,26			; special case?
	jne	outbu6d			; ne = no
	mov	al,127			; 26 to 127
	jmp	outbu6b
outbu6d:cmp	al,127			; special case?
	jne	outbu6b			; ne = no
	mov	al,28			; 127 to 28
	jmp	short outbu6b
outbu6a:and	al,not 80h		; strip high bit
	xlatb				; translate via bx table
outbu6b:stosb				; store char
	loop	outbu6			; do all concerned
	POP	DS
	pop	es
	pop	di
	pop	cx

outbu7:	push	bx
	mov	bx,diskio.handle	; file handle
	or	bx,bx
	jle	outbf0			; le = illegal handle, fail
	mov	ah,write2		; write cx bytes from DS:DX
	int	dos
	pop	bx
	jc	outbf0			; c set means writing error
	cmp	trans.xcrc,0		; do transfer CRC?
	je	outbf7a			; e = no
	push	cx
	mov	cx,ax			; count to crc
	call	crc			; compute CRC-16
	pop	cx
outbf7a:cmp	ax,cx			; did we write all the bytes?
	je	outbf1			; e = yes
	push	bx
	mov	bx,offset decbuf
	add	bx,ax			; look at break character
	cmp	byte ptr [bx],ctlz	; ended on Control-Z?
	pop	bx
	je	outbf1			; e = yes, say no error

outbf0: mov	dx,offset erms13	; Error writing device
	cmp	flags.xflg,0		; writing to screen?
	jne	outbf0a			; ne = yes
	cmp	flags.destflg,dest_printer ; writing to printer?
	jne	outbf0a			; ne = no
	mov	dx,offset ermes9	; Printer not ready message
outbf0a:call	ermsg
	stc				; return failure
	ret

outbf1:	add	tfilsz,cx		; count received chars
	adc	tfilsz+2,0
	add	fsta.frbyte,cx
	adc	fsta.frbyte+2,0
	mov	dbufpnt,offset decbuf	; address for beginning
	mov	dchrcnt,decbuflen	; size of empty buffer
	clc				; return success
	ret
outbuf	endp

; Japanese file transfer section (Hirofumi Fujii, keibun@kek.ac.jp)
; Reread buffer decbuf to convert from transfer character set
; Japanese-EUC into Shift-JIS (Code Page 932). Double char translation state
; is maintained across file buffers. Init dblbyte to 0 before each new file.
; Returns registers
;    cx      number of bytes written in the buffer
;    dx      address of the output buffer
;            this points decbuf or decbuf-1, depending on dblbyteflg
; Output is otherwise written over the input. [rewritten by jrd]
jpnwrite proc	near			; [HF] write Japanese to file
	push	si			; decbuf is read/written
	push	di			; cx has incoming/outgoing byte count
	push	bx			; dblbyte has earlier first byte
	push	es			; dblbyteflg is state from prev call
	mov	dx,ds
	mov	es,dx
	cld				; restore state from previous call
	mov	dl,dblbyteflg		; state, non-zero if doing second byte
	mov	ah,dblbyte		;  and first byte from previous read
	mov	si,offset decbuf	; read/write this buffer
	mov	di,si			; set the address for write
	mov	bx,si			; save for computing output buf length
	or	dl,dl			; carry-in of a double byte char?
	jz	jpnwri1			; z = no
	dec	di			; start output one byte before decbuf
	dec	bx			; adjust the start address
jpnwri1:lodsb				; get a byte
	or	dl,dl			; processing 2nd byte of a pair?
	jnz	jpnwri3			; nz = yes, do second byte processor
					; first byte processor
	cmp	al,80h			; 8th bit on?
	jb	jpnwri5			; b = no, this is a single char
	cmp	al,8eh			; JIS X 0201 Katakana prefix?
	je	jpnwri2			; e = yes, is first of two chars
	cmp	al,0a1h			; JIS X 0208 Kanji ?
	jb	jpnwri5			; b = no, is single char
	cmp	al,0feh
	ja	jpnwri5			; a = no, is single char
jpnwri2:mov	ah,al			; save first of two chars
	mov	dl,1			; say need second char of pair
	jmp	short jpnwri6		; read second byte
					; process second char of two byte pair
jpnwri3:cmp	ah,8eh			; was first char JIS X 0201 Katakana?
	jne	jpnwri4			; ne = no
	or	al,80h			; make sure 8th bit is on
	jmp	short jpnwri5		; write one char
jpnwri4:call	jpnxtof			; xfer -> file char code conversion
	xchg	ah,al
	stosb				; write first byte
	xchg	ah,al			; and second byte
jpnwri5:stosb				; write a char
	xor	dl,dl			; clear multi-byte counter
jpnwri6:loop	jpnwri1
	mov	dblbyteflg,dl		; save state info
	mov	dblbyte,ah		; and the first byte of a pair
	sub	di,bx			; find number of chars written
	mov	cx,di			; return new count in CX
	mov	dx,bx			; return new buffer address for write
	pop	es			; can be decbuf - 1 if carry-in of dbl
	pop	bx
	pop	di
	pop	si
	clc
	ret
jpnwrite endp

; Transfer character code (EUC) to file character code (Shift-JIS) converter.
; input      AH: 1st byte of EUC code
;            AL: 2nd byte of EUC code
; output     AH: 1st byte of Shift-JIS code
;            AL: 2nd byte of Shift-JIS code
; From EUC to Shift-JIS
;   code1 = (EUC_code1 & 0x7f);
;   code2 = (EUC_code2 & 0x7f);
;   if( code1 & 1)
;     code2 += 0x1f;
;   else
;     code2 += 0x7d;
;   if( code2 >= 0x7f ) code2++;
;   code1 = ((code1 - 0x21) >> 1) + 0x81;
;   if( code1 > 0x9f ) code1 += 0x40;
;   [ fputc( code1, file ); fputc( code2, file ); ]
;
jpnxtof	proc	near
	and	ax,7f7fh		; mask both 8-th bits
	test	ah,1
	jz	jpnxtof1
	add	al,1fh
	jmp	short jpnxtof2
jpnxtof1:add	al,7dh
jpnxtof2:cmp	al,7fh
	jb	jpnxtof3
	inc	al
jpnxtof3:sub	ah,21h
	shr	ah,1
	add	ah,81h
	cmp	ah,9fh
	jbe	jpnxtof4
	add	ah,40h
jpnxtof4:ret
jpnxtof	endp

; Get chars from file, encode them to pktinfo structure pointed to by si
 
gtchr	proc	near
	mov	[si].datlen,0		; say no output data yet
	cmp	filflg,0		; is there anything in the buffer?
	jne	gtchr0			; ne = yes, use that material first
	call	inbuf			; do initial read from source
	jc	gtchr1			; c = no more chars, go return EOF
gtchr0:	mov	encinp,offset inbuf	; buffer refiller routine
	call	encode
	test	flags.remflg,dserial+dquiet ; serial/quiet display mode?
	jnz	gtchr2			; nz = yes, skip kbyte and % display
	push	si
	push 	ax
	call	kbpr			; show kilobytes sent
	call	perpr			; show percent sent
	pop	ax
	pop	si
	clc
gtchr2:	ret

gtchr1:	mov	[si].datlen,0		; report EOF
	mov	flags.eoflag,1		; say eof
	test	flags.remflg,dserial+dquiet ; serial/quiet display mode?
	jnz	gtchr3			; nz = yes, skip kbyte and % display
	push	si			; do here so 100% sent shows
	push 	ax
	call	kbpr			; show kilobytes sent
	call	perpr			; show percent sent
	pop	ax
	pop	si
gtchr3:stc				; return failure
	ret
gtchr	endp

; Kermit encoding rules:
; Prefix codes per se are sent as <control prefix, #><data byte>
; C0 and C1 control codes are prefixed by <control prefix, #><data byte>
; 8th bit set prefixing is <8th bit prefix, &><composite byte>
;  where composite byte is <control prefix><data byte>
; Run length encoding is <rle prefix, ~><count><composite byte>
;  where composite byte is <8th bit prefix><control prefix><data byte>
; So far the maximum transmitted size of any raw byte is three bytes, 
; and a run of them is six bytes.
;
; Locking shifts, applies only if locking shifts have been negotiated.
; Data whose lower seven bits are DLE, SI, SO data are sent as other C0/C1
; codes, but they are preceeded by DLE. Such pairs of control codes are
; subject to control code prefixing (#) and 8th bit prefixing (&); runs
; of them are preceeded by the <rle prefix><count> byte pair.
; Control SO locks on implication of 8th bit set on all following data,
; and that data is sent without the 8th bit set.
; Control SI unlocks SO shift.
; DLE, SI, and SO shift controls are sent as bare control codes, unencoded.
; A single shift operation is used when appropriate to change the state
;  of implied 8th bit value (set or reset). The 8th bit prefix character
;  is used as a prefix to denote: change the 8th bit from the current state
;  to the opposite value for the following data byte only.
;
;The Control Prefix
;   For transparency on serial communication links that are sensitive to
;   control characters, the file sender precedes each C0 and C1 control with
;   the control prefix, normally "#" (ASCII 35), and then encodes the control
;   character itself by "exclusive-ORing" it with 64 decimal (i.e. inverting
;   bit 6) to produce a character in the printable ASCII range.  For example,
;   Control-C (ASCII 3) becomes "#C" (3 XOR 64 = 67, which is the ASCII code
;   for the letter C).  Similarly, NUL becomes "#@", Control-A becomes "#A",
;   Control-Z becomes "#Z", Escape becomes "#[", and DEL becomes "#?".  The
;   receiver decodes by discarding the prefix and XORing the character with
;   64 again.  For example, in "#C", C = ASCII 67, and 67 XOR 64 = 3 =
;   Control-C.  Control prefixing is mandatory.  The control prefix is also
;   used for quoting prefix characters that occur in the data itself; see
;   "The Prefix Quote" below.
;
;The 8th-bit Prefix
;   When one or both of the two Kermit programs knows that the connection
;   between them is not transparent to the 8th bit (e.g. because the Kermit
;   PARITY variable is not NONE, or because the program always operates that
;   way), a feature called "8th-bit prefixing" is used if the two Kermit
;   programs negotiate an agreement to do so.  The 8th-bit prefix is Kermit's
;   single shift, normally the ampersand character "&" (ASCII 38).  When the
;   file sender encounters an 8-bit character, it inserts the "&" prefix in
;   front of it, and then inserts the data character itself with its 8th bit
;   set to 0.  If the data character is a control character, it is inserted
;   after the 8th-bit prefix in control-prefixed form.  Examples: an "A" with
;   its 8th bit set to 1 ("<1>A") becomes "&A"; a Control-A with its 8th bit
;   set to 1 ("<1><SOH>") becomes "&#A".
;
;The Repeat-Count Prefix
;   The repeat-count prefix provides a simple form of data compression.  It
;   is used only when both Kermit programs support this feature and agree to
;   use it.  This prefix, normally tilde "~" (ASCII 126), precedes a repeat
;   count, which can range from 0 to 94.  The repeat count is encoded as a
;   printable ASCII character in the range SP (32) - tilde (126) by adding
;   32.  For example, a series of 36 G's would be encoded as "~DG" (D = ASCII
;   68 - 32 = 36).  The repeat-count prefix applies to the following prefixed
;   sequence, which may be a single character ("~DG"), an 8th-bit prefixed
;   character ("~D&G" = 36 Control-G characters with their 8th bits set to
;   1), a control-prefixed character ("~D#M" = 36 Control-M's), or an
;   8th-bit-and-control-prefixed character ("~~&#Z" = 94 Control-Z's with
;   their 8th bits set to 1).
;
;The Prefix Quote
;   The control prefix, normally "#", is also used to quote the control
;   prefix itself if it occurs in the data: "##", meaning that the "#"
;   character should be taken literally.  If 8th-bit prefixing is in effect,
;   the control prefix also quotes the 8th-bit prefix: "#&", so "#&D" stands
;   for "&D" rather than "<1>D".  If repeat count prefixing is in effect, the
;   control prefix is also used to quote the repeat count prefix: "#~", so
;   "#~CG" stands for "~CG" rather than 35 "G" characters.  So the complete
;   meaning of the "#" prefix is: if the value of the following character is
;   77, 64-95, 192-223 or 205, the prefixed character is to be XORed with 64,
;   otherwise it is to be taken literally.  The prefix quote can also be used
;   harmlessly to quote 8th-bit or repeat-count prefixing characters even
;   when these types of prefixing are not in effect.
;
;  Examples, using notation of <high bit><lower 7 bits>:
;
;  Original data stream
;  <0>A<0>B<0>C<1>D<1>E<1>F<1>G<1>H<1>I<0>J<0>K<0>L<0>M  (13 characters)
;  would be transmitted like this with single shifts:
;  &A&B&C&D&E&F&G&H&I&J&K&L&M                            (26 characters)
; and like this with locking shifts:
;   ABC<SO>DEFGHI<SI>JKLM                                 (15 characters)
; On an 8-bit connection, of course, this string of characters can be
; transmitted as-is, with no overhead at all.
;
; Now suppose we have the following character sequence:
;  <1>A<1>B<1>C<0>D<1>E<1>F<1>G<0>H<1>I<1>J<1>K<0>L<1>M  (13 characters)
; Several isolated 7-bit characters are found in the middle of a long run
; of 8-bit characters. Using locking shifts alone, this would be encoded as:
; <SO>ABC<SI>D<SO>EFG<SI>H<SO>IJK<SI>L<SO>M              (20 characters)
; But using a combination of locking and single shifts, it can be encoded more
; compactly, as in this example, in which "&" is the single-shift character:
; <SO>ABC&DEFG&HIJK&LM                                   (17 characters)
;
;

; Do encoding.
; Enter with CX = data size, source of data is encbuf, si is pktinfo ptr.
; Writes output to area pointed to by [si].datadr.
; Returns char count in cx and [si].datlen with carry clear if success,
; else carry set if overflow.
; SI is preserved
doenc:	clc
	jcxz	doen0			; cx = 0 means nothing to encode
	mov	ah,dblbyteflg		; preserve state
	mov	al,dblbyte
	push	ax
	mov	al,shiftstate		; locking shift state
	mov	ah,DLEseen		; DLE state
	push	ax			; save
	mov	dblbyteflg,0		; init encode as doubles
	mov	shiftstate,0		; init shift states
	mov	DLEseen,0
	mov	echrcnt,cx		; number of bytes of source data
	mov	ebufpnt,offset encbuf	; source of data
	mov	encinp,offset nulref	; null routine for refilling buffer
	call	encode			; make a packet with size in AX
	mov	cx,ax
	pop	ax			; restore state
	mov	shiftstate,al
	mov	DLEseen,ah
	pop	ax
	mov	dblbyteflg,ah
	mov	dblbyte,al
doen0:	ret

nulref:	mov	echrcnt,0		; no data to return
	stc
	ret

; encode - writes data portion of kermit packet into [[si].datadr].
; expects encinp to contain the address of a routine to refill the buffer,
; chrcnt to be the # of chars in the buffer, trans.maxdat to contain
; the maximum size of the data packet, ebufpnt to contain a pointer to
; the source of the characters, and [si].datadr to be output address.
; Trans.lshift is non-zero if locking shift encoding is active.
; While locking shift is active DLE escapes DLE, SI, and SO to be
; data characters. Under locking shift rules SO (Control-N) shifts high bit
; data to non-high bit data; SI (Control-O) cancels SO. Shiftstate is
; 0 for non-shifted state, 80h for shifted state.
; Dblbyteflg is non-zero if the first of a byte pair has been obtained while
; performing Japanese translation; dblbyte is the first byte of the pair.
; Returns: AX = the number of characters actually written to the buffer
; All packets except I, S, and A types are encoded.
; Packet space is precomputed allowing for prefixes other than locking shifts.
; Returns carry clear for success, carry set otherwise.

encode	proc	near
	push	es
	push	si			; save caller's si
	mov	cx,trans.maxdat		; maximum packet size
	cmp	cx,[si].datsize		; buffer capacity of this slot
	jbe	encod1			; be = not overflowing slot
	mov	cx,[si].datsize		; use smaller pkt buffer
encod1:	les	di,[si].datadr		; address of output buffer to es:[di]
	mov	temp,di			; remember output buffer start address
	mov	si,ebufpnt		; pointer into source buffer
	mov	dl,trans.rquote		; send quote char
	xor	dh,dh			; assume no 8-bit quoting
	mov	al,trans.ebquot		; 8-bit quote
	cmp	al,'N'			; refusing 8-bit quoting?
	je	encod10			; e = yes
	cmp	al,'Y'			; or can but won't?
	je	encod10			; e = yes, else specific char
	mov	dh,0ffh			; remember we have to do 8-bit quotes
					; top of read loop
encod10:or	cx,cx			; any space left in output buffer?
	jg	encod11			; g = yes
	mov	ax,di			; current output location
	sub	ax,temp			; minus start of buffer, ret cnt in AX
	mov	ebufpnt,si		; update pointer into source buffer
	pop	si			; restore caller's si
	pop	es
	mov	[si].datlen,ax
	clc				; success
	ret

encod11:cmp	echrcnt,0		; any data in buffer?
	jg	encod20			; g = yes, skip over buffer refill
	push	es
	call	encinp			; get another buffer full
	pop	es
	jnc	encod14			; nc = success

encod12:pop	si			; restore user's si
	sub	di,temp			; minus start of buffer
	or	di,di			; buffer empty?
	jz	encod13			; z = yes
	mov	ax,di			; report size encoded
	mov	[si].datlen,ax
	pop	es
	clc				; success
	ret				; return success
encod13:xor	ax,ax			; empty buffer
        mov	flags.eoflag,1		; set eof flag
	mov	filflg,al		; nothing in input buffer
	mov	[si].datlen,ax
	pop	es
	stc				; failure
	ret				; return failure

encod14:mov	si,ebufpnt		; update position in source buffer
	cmp	echrcnt,0 		; any characters returned?
	je	encod12			; e = none, assume eof

encod20:cld				; forward direction
	lodsb
	dec	echrcnt			; decrement input count
	mov	ah,al
	and	ah,80h			; keep high bit in ah
	mov	rptct,1			; say have one copy of this char
	cmp	al,'Z'-40H		; is this a control-Z?
	jne	encd30			; ne = no, skip eof-processing
	cmp	flags.eofcz,0       	; is a Control-Z an end of file?
	je	encd30			; e = no
	cmp	trans.xtype,1		; file type binary?
	je	encd30			; e = yes, send as is
	mov	flags.eoflag,1		; yes, set eof flag
	mov	filflg,0		; say no more source data in buffer
	mov	echrcnt,0		; ditto
	jmp	short encod12		; set character count and return

					; analyze current char (al)
encd30:	cmp	echrcnt,0		; doing the last character?
	jle	encod40			; le = yes, there is no next character
	or	cx,cx			; space for repeat group in output?
	jle	encod40a		; le = no, not enough for rpt prefix
	cmp	al,[si]			; this is char the same as the next?
	jne	encod40			; no, do this char independently
	cmp	trans.rptq,0		; repeat prefixing disabled?
	je	encod40			; e = yes
	push	cx			; scan for repeats in input buffer
	push	bx
	mov	cx,echrcnt		; count of bytes left in input buf
	inc	cx			; will reread current byte
	cmp	cx,94			; max prefix of 94
	jbe	encod31			; be = ok, else limit scan to 94
	mov	cx,94
encod31:xor	bx,bx			; count of copies of this char in buf
encod32:inc	bx
	cmp	[si+bx-1],al		; new [si+bx-1] same as current (al)?
	loope	encod32			; e = yes, do all of interest
	cmp	bx,3			; enough repeats to use prefix?
	jae	encod33			; ae = yes
	mov	bx,1			; say do one char
encod33:mov	rptct,bl		; bl is qty repeated overall
	dec	bx			; bx = number of extra chars (>1)
	add	si,bx			; move forward by repeat group
	sub	echrcnt,bx		; adjust input buffer counter too
	pop	bx
	pop	cx

					; test for locking shift applicability
encod40:cmp	cx,2			; space left for prefixed lock?
	jb	encod50			; b = no, not enough for prefix
	cmp	trans.lshift,lock_disable ; locking shifts disabled?
	je	encod50			; e = yes, skip this material
	cmp	ah,shiftstate		; change of high bit status?
	jne	encod41			; ne = yes
encod40a:jmp	encod50			; no, stay in same lock state
					; change of high bit
encod41:mov	bx,echrcnt		; count chars remaining to be read
	add	bl,rptct		; add repeat count
	adc	bh,0
	cmp	bx,4			; at least 4 more chars to examine?
	jb	encod50			; b = no, not worth a lock change
	cmp	rptct,4			; enough repeats to take short cut?
	jae	encod43			; ae = plenty of repeats
	push	ax			; look for change of shift state
	push	cx
	push	si
	mov	cl,rptct		; repeat count
	xor	ch,ch
	dec	cx			; count is one for no repeats
	sub	si,cx			; back up over repeated chars
	mov	cx,4			; look ahead 4 chars
encod42:lodsb				; read ahead
	and	al,80h			; pick out high bit
	cmp	al,ah			; high bit the same?
	loope	encod42			; loop while same
	pop	si
	pop	cx
	pop	ax
	jne	encod50			; ne = differ, don't change lock
					; change locking shift state
encod43:mov	es:[di],dl		; insert quote char (#)
	inc	di			; adjust output buffer pointer
	dec	cx
	push	ax
	mov	ah,shiftstate		; get current shift state
	xor	ah,80h			; toggle shift state
	mov	shiftstate,ah		; remember it
	mov	al,SIchar+40h		; assume going into unshifted state
	or	ah,ah			; to unshifted state now?
	jz	encod44			; z = yes, go to unshifted state
	mov	al,SOchar+40h		; say go to shifted state
encod44:stosb				; put lock char into packet
	dec	cx
	pop	ax			; recover current character
					; end of locking shift tests

encod50:or	dh,dh			; doing 8-bit quoting?
	jz	encod60			; z = no, forget this
	cmp	trans.lshift,lock_disable ; locking shift disabled?
	je	encod57			; e = yes
	cmp	ah,shiftstate		; different than current shift state?
	jne	encod58			; ne = yes, specials will be prefixed
	push	ax			; save char (stripped of high bit)
	and	al,7fh			; consider high bit controls too
	cmp	al,SIchar		; SI (Control-O)?
	je	encod53			; e = yes
	cmp	al,SOchar		; SO (Control-N)?
	je	encod53			; e = yes
	cmp	al,DLE			; DLE (Control-P)?
	jne	encod54			; ne = no
encod53:mov	al,dl			; stuff a quote (#)
	stosb
	dec	cx
	mov	al,DLE + 40h		; then a DLE prefix (P)
	stosb
	dec	cx			; account for it in buffer size
encod54:pop	ax			; exit with original char in AL
	jmp	short encod60		; no 8-bit prefixing needed here

encod57:cmp	ah,shiftstate		; different than current shift state?
	je	encod60			; e = no, don't send quoted form
encod58:cmp	rptct,1			; doing repeats?
	jbe	encod59			; be = no
	cmp	trans.rptq,0		; disabled?
	je	encod59			; e = yes
	push	ax			; do repeat prefixing - save data
	mov	al,trans.rptq		; insert repeat prefix char
	stosb
	dec	cx			; account for it in buffer size
	mov	al,rptct		; get the repeat count
	add	al,20h			; make it printable
	stosb				; insert into buffer
	dec	cx
	pop	ax			; get back the actual character
encod59:mov	bl,trans.ebquot		; get 8-bit quote char
	mov	es:[di],bl		; put in packet
	inc	di
	dec	cx			; decrement # of chars left
	jmp	short encod60b
					; common prefix testing section
encod60:cmp	rptct,1			; doing repeats?
	jbe	encod60b		; be = no
	cmp	trans.rptq,0		; repeat quoting disabled?
	je	encod60b		; e = yes, disabled
	push	ax			; do repeat prefixing - save data
	mov	al,trans.rptq		; insert repeat prefix char
	stosb
	dec	cx			; account for it in buffer size
	mov	al,rptct		; get the repeat count
	add	al,20h			; make it printable
	stosb				; insert into buffer
	dec	cx
	pop	ax			; get back the actual character

encod60b:and	al,7fh			; turn off 8th bit in character
	cmp	al,' '			; compare to a space
	jae	encod61			; ae = not a control code
	cmp	al,trans.ssoh		; always prefix this item
	je	encod64
	cmp	al,trans.seol		; always prefix this item
	je	encod64
	push	bx			; check for unprefixed selections
	mov	bl,al			; as 1=7-bit, 80h=8-bit, 81h=both
	xor	bh,bh
	mov	bl,protlist[bx]		; get 8 and 7 bit encoding rules
	or	bl,bl			; anything being excepted from prefix?
	jz	encod60a		; z = no
	test	bl,ah			; 8-bit unprefixed?
	jnz	encod60a		; nz = yes
	cmp	ah,80h			; is it a 7-bit char in reality?
	je	encod60a		; e = no (prefix it)
	and	bl,1			; text 7 bit unprefixed
encod60a:pop	bx
	jz	encod64			; z = char needs quoting
	jmp	short encod67		; store char as-is
encod61:cmp	al,DEL			; delete?
	je	encod64			; e = yes, go quote it
	cmp	al,dl			; quote char?
	je	encod65			; e = yes, go add it
	or	dh,dh			; doing 8-bit quoting?
	jz	encod62			; z = no, don't translate it
	cmp	al,trans.ebquot		; 8-bit quote char?
	je	encod65			; e = yes, just output with quote
encod62:cmp	trans.rptq,0		; repeat prefixing disabled?
	je	encod67			; e = yes, don't check for quote char
	cmp	al,trans.rptq		; repeat quote character?
	je	encod65			; e = yes, then quote it
	jmp	short encod67		; else don't quote it
					; control code section
encod64:xor	al,40h			; control char, uncontrollify
encod65:mov	es:[di],dl		; insert control quote char
	inc	di
	dec	cx
encod67:or	al,ah			; restore high bit, if stripped
	or	dh,dh			; doing eight bit quoting?
	jz	encod68			; z = no, retain high bit
	and	al,not 80h		; strip high bit
encod68:stosb
	dec	cx			; decrement output buffer counter
	jmp	encod10			; get fresh input
encode	endp 

; Fill encode source buffer, report KB and percentage done.
; Return carry clear for success
; modifies ax
inbuf	proc	near
	cmp	flags.eoflag,0		; reached the end?
	je	inbuf0			; e = no
	stc				; return failure
	ret
inbuf0:	push	dx
	push	bx
	push	cx
	mov	bx,diskio.handle	; get file handle
	mov	cx,buffsz		; record size
	mov	dx,offset buff		; buffer
	mov	ebufpnt,dx		; buffer pointer
	cmp	trans.xtype,1		; [HF3] File type binary?
	je	inbuf0a			; [HF3] e = yes, no translation
	cmp	trans.xchset,xfr_japanese ; Japanese-EUC?
	jne	inbuf0a			; ne = no
	shr	cx,1			; allow for double char encoding
	mov	dx,offset rdbuf		; use this as source buffer
inbuf0a:mov	ah,readf2		; read a record
	call	readcache		; use internal cache
;;;	int	dos			;  if not using internal cache
	jnc	inbuf7			; nc = no error
	mov	flags.cxzflg,'X'	; error, set ^X flag
 	jmp	short inbuf1		; and truncate the file here
inbuf7:	push	cx
	mov	cx,ax			; count for crc
	call	crc			; compute CRC-16
	pop	cx
	or	ax,ax			; any bytes read?
	jnz	inbuf2			; nz = yes (the number read)
inbuf1:	mov	flags.eoflag,1		; set End-of-File
	mov	filflg,0		; buffer empty
	mov	echrcnt,0		; zero bytes left in buffer
	pop	cx
	pop	bx
	pop	dx
	stc				; failure
	ret

inbuf2:	cmp	trans.xtype,1		;[HF]941012 type binary ?
	je	inbuf3			;[HF]941012 e = yes
	cmp	trans.xchset,xfr_japanese ; Japanese-EUC?
	jne	inbuf3			; ne = no
	call	jpnread			; revise buffer for Japanese chars
inbuf3:	add	tfilsz,ax		; total the # bytes transferred so far
	adc	tfilsz+2,0		; it's a double word
	mov	echrcnt,ax		; number of chars read from file
	add	fsta.fsbyte,ax
	adc	fsta.fsbyte+2,0
	mov	filflg,1		; buffer not empty
					; Character set translation section
	cmp	trans.xtype,1		; File Type Binary?
	je	inbuf6			; e = yes, no translation
	cmp	trans.xchset,xfr_xparent ; Transparent transfer char set?
	je	inbuf6			; e = yes, no translation
	cmp	trans.xchset,xfr_japanese ; Japanese-EUC?
	je	inbuf6			; e = yes, processed already
	push	ax			; save buffer count
	mov	cx,ax			; loop counter
	push	di
	push	es
	PUSH	DS
	call	cplatin			; set DS:BX to CP to Xfr chr table
	call	cpinvert		; check readable vs invertible set
	mov	di,seg buff
	mov	es,di
	mov	di,offset buff		; scan this buffer
	cld
inbuf4:	mov	al,es:[di]		; get a char, keep pointer fixed
	cmp	bx,offset icp437L1	; invertible CP 437 to Latin1?
	jne	inbuf4b			; ne = no
	mov	ah,al
	cmp	ah,127			; special case?
	jne	inbuf4d			; ne = no
	mov	al,26			; 127 to 26
	jmp	short inbuf5
inbuf4d:cmp	al,20			; range for special cases?
	jb	inbuf5			; b = no
	cmp	al,21
	ja	inbuf5			; a = no
	mov	al,167
	je	inbuf5			; 21 to 167
	mov	al,182
	jmp	short inbuf5		; 20 to 182
inbuf4b:cmp	bx,offset icp850L1	; invertible CP 850 to Latin1?
	jne	inbuf4a			; ne = no
	cmp	al,28			; special case?
	jne	inbuf4c			; ne = no
	mov	al,127			; 28 to 127
	jmp	short inbuf5
inbuf4c:cmp	al,127			; special case?
	jne	inbuf4a
	mov	al,26			; 127 to 26
inbuf4a:test	al,80h			; GRight?
	jz	inbuf5			; z = no
	and	al,not 80h		; strip high bit
	xlatb				; translate via bx table
inbuf5:	stosb				; store char
	loop	inbuf4			; do all concerned
	POP	DS
	pop	es
	pop	di
	pop	ax
inbuf6:	pop	cx
	pop	bx
	pop	dx
	clc				; success
	ret
inbuf	endp
code	ends

code1	segment
	assume cs:code1

; An automatic disk read cache
cachesize equ 8192
readcache	proc	far
	cmp	cacheseg,0		; have cache buffer?
	jne	readc1			; ne = yes
	mov	cacheptr,0		; offset of zero in cache
	mov	cachelen,0		; bytes of data in cache
	mov	ax,cachesize		; cache size, bytes
	call	malloc
	mov	cacheseg,ax		; seg of cache
	jnc	readc1			; nc = success
	mov	cacheseg,0		; failed
	stc
	ret

readc1:	cmp	filflg,0		; should cache be empty?
	je	readc2			; e = yes, read from disk
	cmp	cachelen,0		; bytes in cache
	jne	readc4			; ne = have some cached bytes
readc2:	mov	bx,diskio.handle	; get file handle
	mov	cx,cachesize		; number of bytes wanted
	push	ds
	mov	ax,cacheseg
	mov	ds,ax			; destination is ds:dx
	xor	dx,dx			; offset zero
	mov	ah,readf2		; read a record
	int	dos
	pop	ds
	jnc	readc3			; nc = success, ax has byte count
	push	es			; read failure
	mov	ax,cacheseg
	mov	es,ax			; seg of separately malloc'd buffer
	mov	ah,freemem		; free it
	int	dos
	pop	es
	xor	ax,ax
	mov	cacheseg,ax
	stc
	ret				; return error

readc3:	mov	cacheptr,0		; read from start
	mov	cachelen,ax		; bytes now in cache
	or	ax,ax			; end of file (ax = 0)?
	jnz	readc4			; nz = no
	push	es
	mov	ax,cacheseg
	mov	es,ax			; seg of separately malloc'd buffer
	mov	ah,freemem		; free it
	int	dos
	pop	es
	mov	cacheseg,0
	xor	ax,ax			; report ax 0 and carry clear for EOF
	clc
	ret				; return empty

readc4:	mov	cx,cachelen		; bytes in cache
	cmp	cx,buffsz		; larger than buff?
	jbe	readc5			; be = no
	mov	cx,buffsz		; use smaller size
readc5:	push	cx
	push	si
	push	di
	push	es
	push	ds
	mov	si,ds
	mov	es,si
	mov	di,offset buff		; es:di is destination es:buff
	mov	si,cacheptr		; ds:si is source cacheseg:cacheptr
	mov	ax,cacheseg
	mov	ds,ax
	cld
	shr	cx,1
	rep	movsw			; do words
	jnc	readc6			; nc = even byte count
	movsb				; do odd byte
readc6:	pop	ds
	pop	es
	pop	di
	pop	si
	pop	cx
	add	cacheptr,cx		; where to read next
	sub	cachelen,cx		; bytes remaining
	mov	ax,cx			; return ax to caller
	clc
	ret
readcache endp
code1	ends

code	segment
	assume cs:code

; Japanese file transfer section (Hirofumi Fujii, keibun@kek.ac.jp)
; Read buffer rdbuf to convert from file character set Shift-JIS (Code Page 
; 932) to transfer character set Japanese-EUC. Double char translation state
; is maintained across file buffers. Init dblbyte to 0 before each new file.
; Output is written to buff, with byte count in register AX. The output
; could be twice the size of the input. [rewritten by jrd]
jpnread	proc	near			; [HF] read Japanese from file
	push	si
	push	di
	push	es
	mov	cx,ax			; number of chars in source buffer
	mov	ax,ds
	mov	es,ax
	mov	dl,dblbyteflg		; get state info from previous call
	mov	ah,dblbyte		;  first byte too
	mov	si,offset rdbuf		; read from here
	mov	di,offset buff		; write to here (avoids overwrites)
	cld
jpnrea1:lodsb				; get a byte
	or	dl,dl			; doing first byte?
	jnz	jpnread3		; nz = no, second of a pair
	cmp	al,81h			; is it Kanji?
	jb	jpnrea5			; b = no
	cmp	al,0fch
	ja	jpnrea5			; a = no
	cmp	al,9fh
	jbe	jpnrea2			; be = yes
	cmp	al,0e0h
	jb	jpnrea5			; b = no
jpnrea2:mov	ah,al			; AL is first byte of Kanji, save it
	mov	dl,1			; say ready to do second byte next
	jmp	short jpnrea8		; continue loop

jpnread3:cmp	al,40h			; is second byte Kanji?
	jb	jpnrea6			; b = no
	cmp	al,0fch
	ja	jpnrea6			; a = no
	cmp	al,7eh
	jbe	jpnrea4			; be = yes
	cmp	al,80h
	jb	jpnrea6			; b = no
jpnrea4:call	jpnftox			; convert to xfer char code
	jmp	short jpnrea6		; write the pair

jpnrea5:cmp	al,0a1h			; Katakana?
	jb	jpnrea7			; b = no
	cmp	al,0dfh
	ja	jpnrea7			; a = no
	mov	ah,8eh			; set Katakana prefix
jpnrea6:xchg	ah,al			; write two bytes
	stosb				; store first byte
	xchg	ah,al			; get second byte into AL again
jpnrea7:stosb				; store a byte
	xor	dl,dl			; say all bytes have been written
jpnrea8:loop	jpnrea1
	mov	dblbyteflg,dl		; save state info
	mov	dblbyte,ah		; and first char of a pair
	sub	di,offset buff		; compute number of bytes written
	mov	ax,di			; report new count in AX
	pop	es
	pop	di
	pop	si
	ret
jpnread	endp

; File character code (Shift-JIS) to xfer character code (EUC) converter.
; From Shift-JIS to EUC
;   if( code1 <= 0x9f )
;     code1 -= 0x71;
;   else
;     code1 -= 0xb1;
;   code1 = code1 * 2 + 1;
;   if( code2 > 0x7f ) code2 -= 1;
;   if( code2 >= 0x9e ){
;     code2 -= 0x7d;
;     code1 += 1;
;   } else
;     code2 -= 0x1f;
;   EUC_code1 = (code1 | 0x80);
;   EUC_code2 = (code2 | 0x80);
;   [ fputc( EUC_code1, packet ); fputc( EUC_code2, packet ); ]
;
jpnftox	proc	near
	cmp	ah,9fh
	ja	jpnftox1
	sub	ah,71h
	jmp	short jpnftox2
jpnftox1:sub	ah,0b1h
jpnftox2:shl	ah,1
	inc	ah
	cmp	al,7fh
	jbe	jpnftox3
	dec	al
jpnftox3:cmp	al,9eh
	jb	jpnftox4
	sub	al,7dh
	inc	ah
	jmp	jpnftox5
jpnftox4:sub	al,1fh
jpnftox5:or	ax,8080h
	ret
jpnftox	endp

; Calculate the CRC of the string whose address is in DS:DX, length CX bytes.
; Returns the CRC in crcword.  Destroys CX.
; The CRC is based on the SDLC polynomial: x**16 + x**12 + x**5 + 1.
; Original by Edgar Butt  28 Oct 1987 [ebb].
crc	proc	near
	push	ax
	push	bx
	push	dx
	mov	bx,dx			; point to buffer in ds:dx
	mov	dx,crcword		; accumulated CRC-16
	jcxz	crc1
crc0:	push	cx
	mov	ah,[bx]			; get the next char of the string
        inc	bx
        xor	dl,ah			; XOR input with lo order byte of CRC
        mov	ah,dl			; copy it
	mov	cl,4			; load shift count
        shl	ah,cl			; shift copy
        xor	ah,dl			; XOR to get quotient byte in ah
        mov	dl,dh			; high byte of CRC becomes low byte
        mov	dh,ah			; initialize high byte with quotient
        xor	al,al
        shr	ax,cl			; shift quotient byte
        xor	dl,ah			; XOR (part of) it with CRC
        shr	ax,1			; shift it again
        xor	dx,ax			; XOR it again to finish up
	pop	cx
	loop	crc0
crc1:   mov	crcword,dx		; accumulated CRC
	pop	dx
	pop	bx
	pop	ax
	ret
crc	endp
code	ends

code1	segment
	assume cs:code1

; GETFIL, called only by send code
; Enter with raw filename pattern in diskio.string
; Returns carry clear if success, else carry set
getfil	proc	far
	mov	dblbyteflg,0		; clear encoder state variable
	mov	shiftstate,0		; locking shift state
	mov	DLEseen,0		; escape state
	mov	filflg,0		; say nothing is in the buffer
	mov	flags.eoflag,0		; not the end of file
	cmp	atflag,0		; at sign file list?
	je	getfil2			; e = no
			; get a filename to diskio.string from file atfile+2
	call	readatfile
	jnc	getfil2			; nc = success
	ret				; else return carry set for failure
getfil2:mov	al,1			; 1 = get files by rgetfile
	or	al,sendkind		; recursive bit (4) from send routine
	mov	findkind,al		; kind of operation to do
	mov	dx,offset diskio.string ; filename string (may be wild)
	cmp	sndpathflg,2		; use absolute path?
	jne	getfil2c		; ne = no
	mov	decbuf,0		; build buffer, clear it
	xor	al,al			; mapped drive letter (0 = current)
	mov	ah,gcurdsk		; get current disk
	int	dos
	inc	al			; make 1 == drive A (not zero)
	mov	si,dx			; supplied text string
	cmp	byte ptr [si+1],':'	; drive letter?
	jne	getfil2a		; ne = no
	mov	ax,[si]			; get drive letter:
	mov	word ptr decbuf,ax	; start build buffer
	and	al,not 20h		; to upper case
	sub	al,'A'-1		; map A = 1 etc
	add	si,2			; skip letter:
getfil2a:cmp	byte ptr [si],'\'	; root indicator present?
	je	getfil2b		; e = yes, done with prefix
	push	si
	mov	si,offset decbuf	; build buffer
	mov	ah,al			; drive index (A = 1)
	add	ah,'A'-1		; to ASCII
	mov	[si],ah			; store letter
	mov	word ptr [si+1],'\:'	; append :\ for rooting
	add	si,3			; skip over drive:\
	mov	ah,gcd			; get current directory
	mov	dl,al			; get drive letter indicator
	int	dos			; get ds:si = asciiz path (no drive)
	mov	di,offset decbuf
	mov	word ptr temp,0+'\'	; \ termination
	mov	si,offset temp
	call	strcat			; append termination, ASCIIZ
	pop	si
getfil2b:mov	di,offset decbuf	; build buffer
	call	strcat			; append current path components
	mov	dx,offset diskio.string ; filename string (may have wild cards)
	mov	si,offset decbuf	; move from decbuf to diskio.string
	mov	di,dx
	call	strcpy			; move all to diskio.string in ds:dx
getfil2c:call	strlen			; length of path\filename to CX
	call	rfprep			; setup to search for items, ds:dx
	call	rgetfile		; get filename from disk
	pushf				; save c flag
	mov	ah,setdma		; reset dta address
	mov	dx,offset buff		; restore dta
	int	dos
	popf				; restore status of search for first
	jnc	getfi1			; nc = ok so far
	ret				; else take error exit
getfi1:	jmp	getfcom			; do common code
getfil	endp


; GTNFIL called by send code to get next file.
; Returns carry clear for success, carry set for failure.
gtnfil	proc	far
	xor	al,al
	mov	dblbyteflg,al		; clear encoder state variable
	mov	shiftstate,al		; locking shift state
	mov	DLEseen,al		; escape state
	mov	auxfile,al		; clear override name
	cmp	flags.cxzflg,'Z'	; Did we have a ^Z?
	jne	gtnfi1			; ne = no, else done sending files
	stc				; carry set for failure
	ret				; take failure exit

gtnfi1:	mov	filflg,al		; nothing in the DMA
	mov	flags.eoflag,al		; not the end of file
	call	rgetfile		; get next file
	pushf				; save carry flag
	mov	ah,setdma		; restore dta
	mov	dx,offset buff
	int	dos
	popf				; recover carry flag
	jnc	getfcom			; nc = success, do common code
	cmp	atflag,0		; at sign file list?
	jne	getfil			; ne = yes
	stc
	ret				; carry	set means no more files found
gtnfil	endp
					; worker for getfil, gtnfil
getfcom	proc	far
	push	si
	push	di
	mov	si,rfileptr		; pointer to search dta
	mov	di,offset diskio.dta	; global dta for this code
	mov	cx,43			; bytes in a dta
	push	es
	cld
	mov	ax,ds
	mov	es,ax
	rep	movsb			; copy work dta to diskio
	pop	es
	mov	di,offset encbuf	; name to send to host (no path)
	mov	byte ptr [di],0
	cmp	sndpathflg,0		; include SEND PATH?
	je	getfco4			; e = no
	cmp	auxfile,0		; already have an override name?
	jne	getfco4			; ne = yes
	mov	si,offset rpathname	; path
	cmp	byte ptr [si+1],':'	; drive present?
	jne	getfco5			; ne = no
	add	si,2			; skip drive letter
getfco5:cmp	sndpathflg,2		; use absolute path?
	je	getfco6			; e = yes
	cmp	byte ptr [si],'\'	; has leading \?
	jne	getfco6			; ne = no
	inc	si			; skip leading \
getfco6:call	strcpy
getfco4:mov	si,offset diskio.fname	; where workers see filename
	call	strcat			; append found filename
	mov	si,offset encbuf	; fwdslash uses si
	call	fwdslash		; convert slashes to forward kind
	test	flags.remflg,dquiet	; quiet display?
	jnz	getfco1			; e = yes, do not display filename
	call	clrfln			; position cursor & blank out the line
	mov	dx,offset encbuf	; name host sees
	call	prtasz
getfco1:call	newfn			; update encbuf with "send as" name
	mov	si,offset rpathname	; actual path
	mov	di,offset diskio.string	; work buffer
	call	strcpy
	mov	si,offset diskio.fname	; plus found filename
	call	strcat
	mov	dx,di			; ds:dx is filename to open
	mov	ah,open2		; file open
	xor	al,al			; 0 = open readonly
	cmp	dosnum,300h		; at or above DOS 3?
	jb	getfco2			; b = no, so no shared access
	or	al,40h			; open readonly, deny none
getfco2:int	dos
	jc	getfco3			; c = failed to open the file
	mov	diskio.handle,ax	; save file handle
	xor	ax,ax
	mov	tfilsz,ax		; set bytes sent to zero
	mov	tfilsz+2,ax
	mov	ax,-1			; get a minus one
	mov	oldkbt,ax
	mov	oldper,ax
	clc				; carry clear for success
getfco3:pop	si
	pop	di
	ret
getfcom	endp

; Read line from file in atfile+2, return unpadded ASCIIZ string to
; diskio.string.
; Return carry clear if success, else carry set.
readatfile proc	near
	cmp	word ptr atfile,0	; file handle, open?
	jne	reada3			; ne = is open, do a read line
	mov	dx,offset atfile+3	; get filename, skip handle and @
	mov	di,dx
	mov	cx,64			; max length of a filename.
reada1:	cmp	byte ptr [di],' '	; whitespace or control code?
	jbe	reada2			; be = yes, found termination
	inc	di			; else look at next char
	loop	reada1			; limit search
reada2:	mov	byte ptr [di],0		; make asciiz
	mov	ah,open2		; DOS 2 open file
	xor	al,al			; open for reading
	int	dos
	mov	word ptr atfile,ax	; store file handle
	jnc	reada3			; nc = open ok, read from file
	mov	word ptr atfile,0	; say file is closed
	ret				; carry set for fail

reada3:	mov	bx,word ptr atfile	; file handle
	mov	cx,63			; # of bytes to read
	mov	di,offset diskio.string	; destination
	mov	ah,ioctl		; ioctl, is this the console device?
	xor	al,al			; get device info
	int	dos
	and	dl,81h			; ISDEV and ISCIN bits needed together
	cmp	dl,81h			; Console input device?
	jne	reada5			; ne = no, use regular file i/o
reada4:	mov	ah,coninq		; read console, no echo
	int	dos
	cmp	al,CR			; end of the line yet?
	je	reada4b			; e = yes
	cmp	al,' '			; whitespace?
	je	reada4			; e = yes
	cmp	al,TAB
	je	reada4
	cmp	al,'C'-40h		; Control-C?
	jne	reada4a			; ne = no
	stc
	ret				; return failure
reada4a:mov	[di],al
	inc	di
	loop	reada4			; keep reading
reada4b:mov	byte ptr [di],0		; insert terminator
	jmp	short reada6		; finish up

reada5:	mov	dx,di			; destination ptr
	push	cx
	push	es
	mov	cx,seg diskio
	mov	es,cx
	mov	cx,1			; one byte
	mov	byte ptr [di],0		; insert null terminator, clears line
	mov	ah,readf2		; DOS 2 read from file
	int	dos
	pop	es
	pop	cx
	or	ax,ax			; bytes read, zero?
	je	reada6			; e = yes, exit reading
	mov	al,[di]			; byte just read
	cmp	al,' '			; white space?
	je	reada5			; e = yes, skip
	cmp	al,TAB			; white space?
	je	reada5			; e = yes, skip
	cmp	al,','			; comma separator?
	je	reada5a			; e = yes
	cmp	al,CR			; first part of line terminator?
	je	reada5			; e = yes, skip
	cmp	al,LF			; end of the line yet?
	je	reada5a			; e = yes
	inc	di			; where to write next time
	loop	reada5			; keep reading
reada5a:mov	byte ptr [di],0		; insert terminator
	cmp	diskio.string,0		; empty field?
	jne	reada6			; ne = no
	jmp	readatfile		; start over

reada6:	cmp	diskio.string,0		; anything present?
	jne	reada7			; ne = yes
	mov	bx,word ptr atfile	; file handle
	mov	ah,close2		; close file (wanted just one line)
	int	dos
	mov	word ptr atfile,0	; clear handle
	mov	atflag,0
	stc				; say EOF
	ret
reada7:	clc				; say success
	ret
readatfile endp
code1	ends

code	segment
	assume cs:code

; Get the file name from the data portion of the F packet or from locally
; specified override filename (in auxfile), displays the filename, does any
; manipulation of the filename necessary, including changing the name to
; prevent collisions. Returns carry clear for success. Failures return
; carry set with dx pointing at error message text.
; Called by file receive module in mssrcv.asm.
 
gofil	proc	near
	mov	si,offset decbuf	; filename in packet
	call	bakslash		; convert / to \
	mov	di,offset diskio.string
	call	strcpy			; copy pkt filename to diskio.string
	mov	di,offset fsta.xname	; statistics external filespec area
	call	strcpy			; record external name
	cmp	rcvpathflg,0		; RECEIVE PATHNAMES enabled?
	jne	gofil0c			; ne = yes
	cmp	auxfile,0		; in use already?
	jne	gofil0c			; ne = yes
	mov	auxfile,'.'		; dot+nul forces use of current dir
	mov	auxfile+1,0
	jmp	short gofil0d

gofil0c:cmp	auxfile,0		; have override name?
	jne	gofil1			; ne = yes
gofil0d:cmp	flags.xflg,0		; receiving to screen?
	jne	gofil0a			; ne = yes, filename becomes CON
	cmp	flags.destflg,dest_disk	; destination is disk?
	je	gofil1			; e = yes
	mov	di,offset printer	; assume PRN is local file name
	jb	gofil0b			; b = yes
gofil0a:mov	di,offset screen	; use CON (screen) as local file name
	mov	flags.xflg,1		; say receiving to screen
gofil0b:xchg	di,si			; di --> decbuf, si --> file name
	call	strcpy			; put local name (si) into decbuf
	mov	nmoflg,1		; say that we have a replacement name
	jmp	gofil9			; final filename is now in 'decbuf'

gofil1:	xor	ax,ax
	mov	nmoflg,al		; assume no override name
	cmp	auxfile,al		; overriding name from other side?
	jne	gofi1e			; ne = yes
	jmp	gofil4			; e = no, get the other end's filename
gofi1e:	mov	nmoflg,1		; say using an override name
	mov	ax,offset auxfile	; get local override filename
	cmp	word ptr auxfile+1,003ah; colon+null?(primative drive spec A:)
	je	gofil3		; e = yes, skip screwy DOS response (No Path)
	cmp	word ptr auxfile,'..'	; parent directory?
	jne	gofi1g			; ne = no
	cmp	word ptr auxfile+1,002eh ; dot dot + null?
	je	gofi1b			; e = yes, process as directory
gofi1g:	cmp	word ptr auxfile,002eh	; dot + null (current dir)?
	je	gofi1b			; e = yes, process as directory
	call	isfile			; does it exist?
	jnc	gofi1f			; nc = file exists
	test	filtst.fstat,80h	; serious error?
	jz	gofil3			; z = no, just no such file
	jmp	gofi18a			; else quit here
gofi1f:	test	byte ptr filtst.dta+21,10H ; subdirectory name?
	jnz	gofi1b			; nz = yes
	cmp	filtst.fname,2eh	; directory name?
	je	gofi1b			; e = yes, process as directory
	cmp	auxfile+2,5ch		; a root directory like b:\?
	jne	gofi1d		    ; ne = no. (DOS is not helpful with roots)
	cmp	auxfile+3,0		; and is it terminated in a null?
	je	gofi1b			; e = yes, so it is a root spec
gofi1d:	test	byte ptr filtst.dta+21,0fh   ; r/o, hidden, system, vol label?
	jz	gofil3			; z = no
 	jmp	gofi18a		       ; yes. Complain and don't transfer file
gofi1b:	mov	dx,offset auxfile	; auxfile is a (sub)directory name
	call	strlen			; get its length w/o terminator
	jcxz	gofil2			; zero length
	dec	cx			; examine last char
	push	bx			; save bx
	mov	bx,cx
	add	bx,dx
	cmp	byte ptr [bx],5ch	; ends in backslash?
	je	gofil2			; e = yes
	cmp	byte ptr [bx],2fh	; maybe forward slash?
	je	gofil2			; e = yes
	mov	byte ptr [bx + 1],5ch	; no slash yet. use backslash
	mov	byte ptr [bx + 2],0	; plant new terminator
gofil2:	pop	bx

gofil3:	mov	di,offset templp	; local path
	mov	si,offset templf	; local filename
	mov	dx,offset auxfile	; local string
	call	fparse			; split local string
	mov	di,offset temprp	; remote path
	mov	si,offset temprf	; remote file
	mov	dx,offset decbuf	; remote string
	mov	decbuf+64,0		; force filename to be <= 64 chars
	call	fparse			; split remote string
	test	flags.remflg,dserver	; running in Server mode?
	jz	gofi3c			; z = no
	test	denyflg,sndflg		; is Deny Send mode in operation?
	jz	gofi3c			; z = no
	mov	temprp,0		; DENY, means remove remote path
gofi3c:	mov	si,offset templp	; copy local path to
	mov	di,offset decbuf	;  final filename
	call	strcpy			; do the copy
	mov	si,offset templf	; assume using local file name
	cmp	byte ptr templf,0	; local file name given?
	jne	gofi3b			; ne = yes
	mov	si,offset temprf	; else use remote file name
gofi3b:	call	strcat			; append path and filename again
					; offset decbuf holds the new filename
					;
				; recheck legality of filename in 'decbuf'
gofil4:	mov	decbuf+64,0		; guard against long filenames
	mov	di,offset temprp	; remote path
	mov	si,offset temprf	; remote file
	mov	dx,offset decbuf	; remote string
	call	strlen			; get original size
	push	cx			; remember it
	call	fparse			; further massage filename

	cmp	rcvpathflg,1		; receive relative etc pathnames?
	je	gofil21			; e = relative
	ja	gofil22			; a = absolute
	mov	byte ptr [di],0		; remove remote path for no path
	jmp	short gofil23
gofil21:cmp	byte ptr [di],'\'	; rooted path when relative wanted?
	jne	gofil22			; ne = no
	inc	di			; skip leading '\'
gofil22:call	mkpath			; make path from ds:di path string
gofil23:push	si			; put pieces back together
	call	verfil			; verify each char in temprf string
	mov	si,di			; get path part first
	mov	di,dx			; set destination to decbuf
	call	strcpy			; copy in path part
	pop	si			; recover (new) filename

	cmp	byte ptr [si],'.'	; does filename part start with a dot?
	jne	gofil5			; ne = no
	push	di			; save regs
	push	si
	mov	di,offset rdbuf		; a work area
	mov	byte ptr [di],'X'	; start name with letter X
	inc	di
	call	strcpy			; copy rest of filename
	mov	di,si
	mov	si,offset rdbuf      ; copy new name back to original location
	call	strcpy
	pop	si			; restore regs
	pop	di	
gofil5:	call	strcat			; append it
	call	strlen			; see if we chopped out something
	pop	si		    ; get original length (from push cx above)
	cmp	cx,si			; same size?
	je	gofil9			; e = yes
	mov	nmoflg,1		; say that we have a replacement name
				; filename is now in 'decbuf', all converted
gofil9:	test	flags.remflg,dquiet	; quiet display mode?
	jnz	gofi10			; nz = yes, don't print it
	test	flags.remflg,dserial	; serial display mode?
	jz	gofi9a			; z = no
	mov	ah,prstr
	mov	dx,offset crlf		; display cr/lf
	int	dos
gofi9a:	call	prtfn			; show packet filename
	cmp	nmoflg,0		; using local override name?
	je	gofil9b			; e = no
	cmp	flags.xflg,0		; receiving to screen? (X versus F)
	jne	gofil9b			; ne = yes
	mov	ah,prstr
	mov	dx,offset asmsg		; print " as "
	int	dos
	mov	dx,offset decbuf	; plus the local filename
	call	prtasz			; print asciiz string
gofil9b:mov	ah,flags.remflg		; display a following cr/lf?
	and	ah,dserial		; for serial display mode
	or	ah,flags.xflg		; receiving to screen
	jz	gofi10			; z = neither, no cr/lf
	mov	ah,prstr		; finish the line with cr/lf
	mov	dx,offset crlf
	int	dos
gofi10:	mov	filtst.fstat2,0		; 0 = assume is a disk file
	mov	ah,open2
	xor	al,al			; open readonly
	cmp	dosnum,300h		; above DOS 2?
	jb	gofi10a			; b = no, so no shared access
	or	al,40h			; open for reading, deny none
gofi10a:mov	dx,offset decbuf	; the filename
	int	dos
	jc	gofi16			; c = cannot open so just proceed
	mov	bx,ax			; file handle
	mov	ah,ioctl
	xor	al,al			; 0 = get info
	int	dos
	mov	ah,close2		; close it
	int	dos
	mov	ax,offset decbuf	; point to filename again
	and	dl,80h			; ISDEV bit
	mov	filtst.fstat2,dl	; 0 = disk file, else device
	test	dl,80h			; ISDEV bit set?
	jz	gofi11			; z = no, not a device
	jmp	gofi16			; device, use name as given
gofi11:	cmp	flags.flwflg,filecol_discard	; no-supersede existing file?
	jne	gofi12			; ne = no (i.e., do a rename)
	cmp	flags.flwflg,filecol_update ; updating?
	je	gofi16			; e = yes, delay opening
	cmp	flags.flwflg,filecol_overwrite	; overwrite existing file?
	je	gofi16			; e = yes

gofi11a:mov	flags.cxzflg,'X'	; say stop this file
	mov	word ptr decbuf,'UN'
	mov	decbuf+2,'L'		; file name of NUL
	mov	decbuf+3,0		; asciiz
	jmp	short gofi13
gofi12:	cmp	flags.flwflg,filecol_rename ; rename existing file?
	jne	gofi16			; ne = no
	mov	ax,offset decbuf	; point to filename again
	call	unique			; generate unique name
	jc	gofi14			; could not generate a unique name
	test	flags.remflg,dquiet	; quiet display mode?
	jnz	gofi13			; nz = yes, skip printing
	push	ax			; save unique name again
	call	frpos			; position cursor
	mov	ah,prstr	   	; say we are renaming the file
	mov	dx,offset infms5
	int	dos
	pop	ax			; get name back into ax again
	push	ax			; save around these calls
	mov	dx,ax			; print current filename
	call	prtasz			; display filename
	pop	ax			; pointer to name, again
gofi13:	jmp	short gofi16		; and go handle file
 
gofi14:	mov	dx,offset ermes4
	call	ermsg
	stc				; failure, dx has msg pointer
	ret
 
gofi16:	mov	si,offset decbuf	; pointer to (maybe new) name
	mov	di,offset diskio.string	; filename, used in open
	call	strcpy	 		; copy name to diskio.string
	xor	ax,ax
	mov	diskio.sizehi,ax	; original file size is unknown
	mov	diskio.sizelo,ax	; double word
	mov	tfilsz,ax		; set bytes received to zero
	mov	tfilsz+2,ax
	mov	ax,-1			; get a minus one
	mov	oldkbt,ax
	mov	oldper,ax
	mov	wrpmsg,al
	clc				; finished composing filename
	ret				; in diskio.string

gofi18a:mov	si,ax	 		; pointer to local override name
	mov	di,offset diskio.string	; filename, used in open
	call	strcpy	 		; copy name to diskio.string
					; fall	through to gofi18
gofi18:	test	flags.remflg,dquiet	; quiet display mode?
	jnz	gofi19			; nz = yes, don't try printing
	mov	dx,offset erms12	; unable to create file
	call	ermsg
	push	dx
	mov	dx,offset diskio.string	; print offending name
	call	prtasz			; display filename
	pop	dx
gofi19:	stc				; failure, dx has msg pointer
	ret
gofil	endp

; Open file for writing with name in diskio.string
goopen	proc	near
	xor	ax,ax
	mov	dblbyteflg,al		; clear decoder state variable
	mov	shiftstate,al		; locking shift state
	mov	DLEseen,al		; escape state
	mov	tfilsz,ax		; set bytes received to zero
	mov	tfilsz+2,ax
	mov	ax,-1			; get a minus one
	mov	oldkbt,ax
	mov	oldper,ax

	cmp	diskio.handle,-1	; is handle unused?
	je	goopen5			; e = yes
	mov	dx,diskio.handle	; close the file now
	mov	ah,close2
	int	dos
	mov	diskio.handle,-1	; clear handle of previous usage
goopen5:mov	ax,offset diskio.string	; filename, asciiz
	call	isfile		; check for read-only/system/vol-label/dir
	jc	goopen1			; c = file does not exist
	test	byte ptr filtst.dta+21,1fh	; the no-no file attributes
	jnz	gofi18			; nz = do not write over one of these
	jmp	short goopen2		; open existing

goopen1:test	filtst.fstat,80h	; access problem?
	jnz	gofi18			; nz = yes, quit here
	mov	dx,offset diskio.string	; filename, asciiz
	mov	ah,creat2		; create file
	xor	cx,cx			; 0 = attributes bits
	int	dos
	jc	goopen2			; c = did not work, try regular open
	mov	diskio.handle,ax	; save file handle here
	xor	dx,dx			; file size, high word
	xor	ax,ax			; low word
	clc				; carry clear for success
	ret
goopen2:test	byte ptr filtst.dta+21,1bh	; r/o, hidden, volume label?
	jnz	gofi18			; we won't touch these
	mov	dx,offset diskio.string	; filename, asciiz
	mov	ah,open2	       ; open existing file (usually a device)
	mov	al,1+1			; open for writing
	int	dos
	jc	gofi18			; carry set means can't open
	mov	diskio.handle,ax	; file handle
	cmp	flags.flwflg,filecol_update ; updating?
	jne	goopen2c		; ne = no
	mov	ah,fileattr		; get file date/time attributes
	xor	al,al			; get, not set
	mov	bx,diskio.handle	; file handle
	int	dos			; dx=date, cx=time
	cmp	dx,word ptr fdate	; date is earlier than our file?
	ja	goopen2a		; a = yes, skip file
	jb	goopen2c		; b = incoming date is later
	cmp	cx,word ptr ftime	; same date, how about time
	jb	goopen2c		; b = later time, get the file
goopen2a:mov	dx,diskio.handle	; file handle
	mov	ah,close2		; close it
	int	dos
	mov	flags.cxzflg,'X'	; say stop this file
	mov	ah,open2
	mov	al,1			; open for writing
	cmp	dosnum,300h		; above DOS 2?
	jb	goopen2b		; b = no, so no shared access
	or	al,40h			; open for reading, deny none
goopen2b:mov	dx,offset vacuum	; NUL as a filename
	int	dos
	mov	diskio.handle,ax	; file handle
	stc				; carry set for failure
	ret

goopen2c:cmp	flags.flwflg,filecol_append ; append to existing file?
	je	goopen3			; e = yes
	clc				; carry clear for success
	ret
goopen3:mov	bx,diskio.handle	; file handle for seeking
	xor	cx,cx			; high order displacement
	xor	dx,dx			; low order part of displacement
	mov	ah,lseek		; seek to EOF (to do appending)
	mov	al,2			; says to EOF
	int	dos
	ret				; return DX:AX as new file pointer
goopen	endp

; Given incoming filename in 'decbuf'.  Verify that each char is legal
; (if not change it to an "X"), force max of three chars after a period (dot)
; Source is at ds:si (si is changed here).

VERFIL	PROC	FAR
	push	es			; verify each char in 'data'
	push	cx
	push	ds
	pop	es
	push	bx
	xor	bx,bx			; bl = have dot, bh = 8 char count
	cld
verfi1:	lodsb				; get a byte of name from si
	and	al,7fH			; strip any eighth bit
	jz	verfi5			; z = end of name
	cmp	al,'.'			; a dot?
	jne	verfi2			; ne = no
	cmp	bl,0			; have one dot already?
	jne	verfi3			; ne = yes, change to X
	mov	byte ptr [si+3],0    ; forceably end filename after 3 char ext
	mov	bl,1			; say have a dot now
	jmp	short verfi4		; continue
verfi2:	or	bl,bl			; have read a dot?
	jnz	verfi2a			; nz = yes
	inc	bh			; count base
	cmp	bh,8			; done all base bytes?
	ja	verfi1			; a = yes, discard excess
verfi2a:cmp	al,3ah			; colon?
	je	verfi4
	cmp	al,5ch			; backslash path separator?
	je	verfi4
	cmp	al,2fh			; or forward slash?
	je	verfi4
	cmp	al,'0'
	jb	verfi3			; see if it's a legal char < '0'
	cmp	al,'9'
	jbe	verfi4			; it's between 0-9 so it's OK
	cmp	al,'A'
	jb	verfi3			; check for a legal punctuation char
	cmp	al,'Z'
	jbe	verfi4			; it's A-Z so it's OK
	cmp	al,'a'
	jb	verfi3			; check for a legal punctuation char
	cmp	al,'z'
	ja	verfi3
	and	al,5FH			; it's a-z, capitalize
	jmp	short verfi4		; continue with no change

verfi3:	push	di			; special char. Is it on the list?
	mov	di,offset spchar2	; list of acceptable special chars
	mov	cx,spc2len
	cld
	repne	scasb			; search string for input char
	pop	di
	je	verfi4			; e = in table, return it
	mov	al,'X'			; else illegal, replace with "X"
	mov	nmoflg,1		; say we have a replacement filename
verfi4:	mov	[si-1],al		; update name
	jmp	short verfi1		; loop thru rest of name
verfi5:	mov	byte ptr[si-1],0	; make sure it's null terminated
	pop	bx
	pop	cx
	pop	es
	ret
VERFIL	ENDP

; find a unique filename.
; Enter with a pointer to a (null-terminated) filename in ax
; Return with same pointer but with a new name (or old if failure)
; Success = carry clear; failure = carry set
; The idea is to pad out the main name part (8 chars) with ascii zeros and
; then change the last chars successively to a 1, 2, etc. until
; a unique name is found. All registers are preserved
; Make empty main name fields start with letter X, not digit 0
unique	proc	near
	push	bx
	push	cx
	push	dx
	push	si
	push	di
	push	es
	push	ax			; save address of source string
	mov	dx,ds			; make es use ds segment
	mov	es,dx
	mov	dx,ax			; point at original filename string
	mov	di,offset templp	; place for path
	mov	si,offset templf	; place for filename
	call	fparse			; separate path (di) and filename (si)
	mov	dx,di			; point at path part
	call	strlen			; put length in cx
	mov	si,ax			; point to original string
	add	si,cx			; point to filename part
	mov	di,offset templf	; destination is temporary location
	xor	cx,cx			; a counter
	cld				; set direction to be forward
uniq1:	lodsb				; get a byte
	cmp	al,'.'			; have a dot?
	je	uniq2			; e = yes
	or	al,al			; maybe	null at end?
	jnz	uniq3			; nz = no, continue loop

uniq2:	cmp	cl,8			; have we copied any chars before dot?
	jge	uniq3			; ge = all 8
	mov	byte ptr [di],'0'	; avoid clobbers; pad with 0's
	or	cl,cl			; first char of filename?
	jnz	uniq2a			; nz = no
	mov	byte ptr [di],'X'	; start name with letter X, not 0
uniq2a:	inc	di			; and count the output chars
	inc	cl			; and this counter too
	jmp	short uniq2		; continue until filled 8 slots
uniq3:	inc	cl			; cl = # char in destination
	stosb				; store the char
	or	al,al			; null at end?
	jnz	uniq1			; nz = no, continue copying

	mov	templf+7,'1'		; put '1' in last name char
	mov	unum,1			; start with this generation digit

uniq4:	mov	di,offset rdbuf		; build a temporary full filename
	mov	si,offset templp	; path part
	call	strcpy			; copy that much
	mov	si,offset templf	; get rebuilt filename part
	call	strcat			; paste that to the end
	mov	ax,offset rdbuf		; point to full name
	call	isfile			; does it exist?
	jc	uniq6			; c = no, succeed now

	inc	unum			; move to next generation
	mov	di,offset templf+7	; point to last name char
	mov	cx,7			; max # of digits to play with
	mov	bx,10			; divisor (16 bits)
	mov	ax,unum			; low order part of generation #
uniq5:	xor	dx,dx			; high order part of generation #
	div	bx			; compute digit (unum / 10)
	add	dl,'0'			; make remainder part printable
	mov	[di],dl			; put into right place
	or	ax,ax			; any more to do? (quotient nonzero)
	jz	uniq4			; z = no, try this name
	dec	di			; else decrement char position
	loop	uniq5			;   and keep making a number
	stc				; failure: set carry, keep old name
	jmp	short uniq7		;   and exit

uniq6:	pop	di			; address of original filename
	push	ax			; save for exit clean up
	mov	si,offset rdbuf
	call	strcpy			; copy new filename over old
	clc				; success: clear carry flag
uniq7:	pop	ax
	pop	es
	pop	di
	pop	si
	pop	dx
	pop	cx
	pop	bx
	ret
unique	endp
code	ends 

code1	segment
	assume cs:code1	

; strlen -- computes the length, excluding the terminator, of an asciiz
;	string. Input: ds:dx = address of the string
;		Output: cx = the byte count
;	All registers except cx are preserved
;
STRLEN	PROC	FAR
	push	di
	push	es
	push	ax
	mov	ax,ds			; use proper segment address
	mov	es,ax
	mov	di,dx
	mov	cx,0ffffh		; large byte count
	cld				; set direction to be forward
	xor	al,al			; item sought is a null
	repne	scasb			; search for it
	add	cx,2			; add for -1 and auto dec in scasb
	neg	cx		      ; convert to count, excluding terminator
	pop	ax
	pop	es
	pop	di
	ret
STRLEN	ENDP

; strcat -- concatenates asciiz string 2 to the end of asciiz string 1
;	offset of string 1 is expected to be in ds:di. input & output
;	offset of string 2 is expected to be in ds:si. input only (unchanged)
;	Preserves all registers. No error returns, returns normally via ret
;
STRCAT	PROC	FAR
	push	di			; save work registers
	push	si
	push	es
	push	dx
	push	cx
	push	ax
	mov	ax,ds			; get data segment value
	mov	es,ax			; set es to ds for implied es:di usage
	mov	dx,di
	call	strlen		; get length (w/o terminator) of dest string
	add	di,cx			; address of first terminator
	mov	dx,si			; start offset of source string
	call	strlen			; find its length too (in cx)
	inc	cx			; include its terminator in the count
	cld
	rep	movsb		; copy source string to end of output string
	pop	ax
	pop	cx
	pop	dx
	pop	es
	pop	si
	pop	di
	ret
STRCAT	ENDP

; strcpy -- copies asciiz string pointed to by ds:si into area pointed to by
;	ds:di. Returns via ret. All registers are preserved
;
STRCPY	PROC	FAR
	cmp	si,di			; same place?
	jne	strcpy1			; ne = no
	ret				; having done nothing
strcpy1:mov	byte ptr [di],0		; clear destination string
	call	strcat			; let strcat do the real work
	ret
STRCPY	ENDP

; fparse -- separate the drive:path part from the filename.ext part of an
;	asciiz string. Characters separating parts are  \ or / or :
;	Inputs:	asciiz input full filename string offset in ds:dx
;		asciiz path offset in ds:di
;		asciiz filename offset in ds:si
;	Outputs: the above strings in the indicated spots
;	Strategy is simple. Reverse scan input string until one of the
;	three separators is encountered and then cleave at that point
;	Simple filename construction restrictions added 30 Dec 1985;
;	to wit: mainname limited to 8 chars or less,
;	extension field limited to 3 chars or less and is found by searching
;	for first occurence of a dot in the filename field. Thus the whole
;	filename part is restricted to 12 (8+dot+3) chars plus a null
;	All registers are preserved. Return is always via ret
;	(Microsoft should have written this for DOS 2.x et seq.)

FPARSE	PROC	FAR
	push	cx			; local counter
	push	ax			; local work area
	push	es			; implied segment register for di
	push	di			; offset of path part of output
	push	si			; offset of file name part of output
	mov	ax,ds			; get data segment value
	mov	es,ax			; set es to ds for implied es:di usage
	mov	byte ptr [si],0		; clear outputs
	mov	byte ptr [di],0

	push	si			; save original file name address
	mov	si,dx			; get original string address
	call	strcpy			; copy string to original di
	call	strlen			; find length (w/o terminator), in cx
	mov	si,di			; address of string start
	add	si,cx
	dec	si			; si = address of last non-null char
	jcxz	fpars5			; if null skip the path scan
					; now find last path char, if any
					; start at the end of input string
	std	 			; set direction to be backward
fpars4:	lodsb	 			; get a byte (dec's si afterward)
	cmp	al,5ch			; is it a backslash ('\')? 
	je	fpars6  		; e = yes
	cmp	al,2fh			; or forward slash ('/')?
	je	fpars6  		; e = yes
	cmp	al,3ah			; or even the drive terminator colon?
	je	fpars6			; e = yes
	loop	fpars4 			; else keep looking until cx == 0
		  			; si is at beginning of file name
fpars5:	dec	si			; dec for inc below
fpars6:	inc	si
	inc	si			; si now points at first filename char
					; cx holds number of path chars
					; get original file name address (si)
	pop	di			; and make it place to copy filename
	cld				; reset direction to be forward
	mov	ax,si			; ax holds filename address for awhile
	push	dx
	mov	dx,si			; strlen wants string pointer in dx
	call	strlen			; get length of filename part into cx
	pop	dx
	jcxz	fpar7a			; any chars to look at? z = no
fpars7:	cmp	byte ptr [si],'.'	; look for a dot in filename
	je	fpars8			; e = found one
	inc	si			; look at next filename char
	loop	fpars7			; keep looking until cx = zero
fpar7a:	mov	si,ax			; no dot. recover starting address
	mov	byte ptr [si+8],0	; forcably truncate mainname to 8 char
	call	strcpy			; copy this part to filename field
	jmp	short fparsx		;  and exit
fpars8: mov	byte ptr [si+4],0   ; plant terminator after dot + 3 ext chars
	mov	cx,si
	sub	cx,ax		; cx now = number of chars in mainname field
	cmp	cx,9			; more than 8?
	jb	fpars9			; b = no, we're safe
	mov	cx,8		     ; limit ourselves to 8 chars in mainname
fpars9: push	si		     ; remember address of dot and extension
	mov	si,ax			; point to start of input filename
	rep	movsb			; copy cx chars from si to di (output)
	mov	byte ptr [di],0		; plant terminator where dot goes
	pop	si			; source = dot and extension address
	call	strcat		; append the dot & ext to the filename field
fparsx: mov	si,ax		; recover start of filename in input string
	mov	byte ptr [si],0		; terminate path field
	pop	si
	pop	di
	pop	es
	pop	ax
	pop	cx
	ret
FPARSE	ENDP	

; Print filename in offset diskio.string.
PRTFN	PROC	FAR
	test	flags.remflg,dquiet	; quiet display mode?
	jnz	prtfn1			; nz = yes, don't display filename
	push	ax			; saves for messy clrfln routine
	push	bx
	push	dx
	call	clrfln			; position cursor & blank out the line
	mov	dx,offset diskio.string
	call	prtasz
	pop	dx
	pop	bx
	pop	ax
prtfn1:	ret
PRTFN	ENDP


; Print string to screen from offset ds:di for # bytes given in cx,
; regardless of $'s.  All registers are preserved.

PRTSCR	PROC	FAR
	jcxz	prtscr4			; cx = zero means nothing to show
	push	ax
	push	bx
	push	dx
	mov	dx,di			; source ptr for DOS
	cmp	flags.eofcz,0		; end on Control-Z?
	jne	prtscr3			; ne = yes, let DOS do it
	push	cx			; else map Control-Z to space
	push	di
	push	es
	push	ds
	pop	es			; data to es
	mov	al,ctlz			; look for Control-Z
	cld				; scan buffer es:di, cx chars worth
prtscr1:repne	scasb
	jne	prtscr2			; ne = found no Control-Z's
	mov	byte ptr [di-1],' '	; replace Control-Z with space
	jcxz	prtscr2			; z = examined all chars
	jmp	short prtscr1		; until examined everything
prtscr2:pop	es
	pop	di
	pop	cx
prtscr3:mov	bx,1			; stdout file handle
	mov	ah,write2
	int	dos
	pop	dx
	pop	bx
	pop	ax
prtscr4:ret
PRTSCR	ENDP

; Print to screen asciiz string given in ds:dx. Everything preserved.
PRTASZ	PROC	FAR
	push	cx
	push	di
	call	strlen			; get length of asciiz string
	mov	di,dx			; where prtscr looks
	call	prtscr			; print counted string
	pop	di
	pop	cx
	ret
PRTASZ	ENDP

; Convert \ in string at ds:si to forward slash. Preserve all but AX.
fwdslash proc	far
	push	si
	push	di
	push	es
	cld
	mov	ax,ds
	mov	es,ax
	mov	di,si
fwds1:	lodsb
	cmp	al,'\'			; backslash?
	jne	fwds2			; ne = no
	mov	al,'/'			; forward slash
fwds2:	stosb
	or	al,al			; end of string?
	loopnz	fwds1			; loop while string
	pop	es
	pop	di
	pop	si
	ret
fwdslash endp

; Convert / in string at ds:si to back slash. Preserve all but AX.
bakslash proc	far
	push	si
	push	di
	push	es
	cld
	mov	ax,ds
	mov	es,ax
	mov	di,si
baks1:	lodsb
	cmp	al,'/'			; forward slash?
	jne	baks2			; ne = no
	mov	al,'\'			; back slash
baks2:	stosb
	or	al,al			; end of string?
	loopnz	baks1			; loop while string
	pop	es
	pop	di
	pop	si
	ret
bakslash endp

; Create directories for path string in ds:di
; Omit elements starting with a dot
mkpath	proc	far
	push	bx
	push	dx
	push	si
	push	di
	push	es
	mov	si,ds
	mov	es,si
	cld
	mov	si,di
	mov	dx,di
	mov	bx,dx		;start of current element
mkp1:	lodsb
	or	al,al
	jz	mkp4		; z = end of string
	cmp	al,'/'		; forward slash?
	jne	mkp1a		; ne = no
	mov	al,'\'		; convert to backslash
mkp1a:	cmp	al,'\'		; path separator?
	je	mkp2		; e = yes
	stosb
	jmp	short mkp1
mkp2:	mov	byte ptr [di],0 ; terminator
	cmp	byte ptr [bx],'.' ; element starts with dot?
	jne	mkp3		; ne = no
	mov	di,bx		; overwrite it
	mov	byte ptr [di],0	; nullify it
	jmp	short mkp1	; get next path element

mkp3:	push	si
	mov	si,bx		; si to start of this element
	call	verfil		; mung string
	mov	di,si		; where to write next
	pop	si
	mov	ah,39h		; mkdir from ds:dx
	int	dos
	dec	di
	mov	al,'\'		; put back separator
	stosb
	mov	bx,di		; where next element starts
	jmp	short mkp1
mkp4:	pop	es
	pop	di
	pop	si
	pop	dx
	pop	bx
	ret
mkpath	endp
code1	ends 
	end
