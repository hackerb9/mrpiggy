	NAME	MSNPDI
; File MSNPDI.ASM
; Packet Driver and ODI interface 
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
; Written by Joe R. Doupnik, Utah State University, Logan Utah 84322
;  jrd@cc.usu.edu, jrd@usu.Bitnet.
;
; Packet Driver reference:
; "PC/TCP Version 1.09 Packet Driver Specification", FTP Software, Inc.,
;  September-14-1989.
;
; ODI references:
; "Open Data-Link Interface Developer's Guide for DOS Network Layer Protocol 
;  Stacks", Novell Inc, document number 100-001218-001 (1992, but no printed 
;  date).
; "Open Data-Link Interface Developer's Guide for NetWare v3.1x Server 
;  Driver Protocol Stacks", Novell Inc, document number 100-001196-00, v1.0,
;  19 Sept 1991.
; "Open Data-Link Interface LAN Driver Developer's Guide for DOS", Novell Inc,
;  document number 107-000010-001, Revision i, 13 Nov 1990.
;
; C language interface presumes the Small memory model and Microsoft C.
; Assembler is MS MASM v6.
;
; These procedures interface between ODI or a Packet Driver and the main
; protocol stack to both send and receive packets. The upper levels provide
; and receive packets framed as Ethernet_II (Blue Book/DIX), and receive
; ARP information particular to the physical frames involved. Conversion of
; this internal form to the actual framing method on the wire is done by ODI.
; The receive buffer is external to this routine. Received packets are linked
; into the buffer on an order of arrival basis (and sized to fit). High level
; reception has to poll the receive buffer queue. Transmitted packets are 
; operated with a single external buffer, and sending blocks until the lower 
; level driver material is ready for us. Initialization, status, attachment, 
; and disengagment procedures are here.
; External int kpdint is used by pdinit() to select between Packet Driver
; and ODI interfaces. Call pdinit() to initialize the system, then call
; pdaccess() to register each desired frame TYPE, call pdclose() to release
; each frame TYPE.
; Packet senders call pkt_send() directly.
; Packet receivers examine the external packet buffer for packets.
; ARP information is returned in external ints arp_hardware (hardware ARP
; type code) and MAC_len (length of MAC address, in bytes). See table below
; for the possible pairs.
; Packet Driver usage is limited to Ethernet_II/DIX and SLIP. ODI usage is
; at least Ethernets, Token Ring, Arcnet, and others untested here.
; 
; Edit history
; 12 Jan 1995 version 3.14
; Last edit
; 23 Dec 1995
INCLUDE symboldefs.h
getintv		equ	35h		; DOS get interrupt vector to es:bx
dos		equ	21h
lf		equ	0ah
fopen		equ	3dh		; DOS file operations
fclose		equ	3eh
fread		equ	3fh

pdgetinfo	equ	1		; Packet Driver functions
pd_access 	equ	2
pd_release	equ	3
pd_send		equ	4
pd_get_address	equ	6
eaddr_len	equ	6		; length of an Ethernet address
IF_EII		equ	1		; Ethernet II interface type
IF_SLIP		equ	6		; SLIP interface type, RFC1055

link	struc				; receiver buffer link structure
	flag	db	0		; buffer use flag
	bufnum	db	0		; buffer write sequence number
	count	dw	0		; count of bytes to follow
link	ends
linksize equ	4			; bytes in link structure

; Novell ODI material, based on LSL v1.2.
; Most of these header structures were taken from Novell file ODI.INC,
; and parts have been tailored for Kermit. Information on the "new" item in
; the lookahead structure is compliments of Novell, private correspondence.

;  Event Control Block Structure
ECBstruct	struc
	nextlink	dd	0		; leave intact
	prevlink	dd	0		; leave intact
	status		dw	0		; general status
	esr		dd	0		; addr of event service routine
	stackid		dw	0		; protocol stack ident
	protid		db	6 dup (0)	; sending only
	boardnum	dw	0		; sending, MILD board number
	immaddr		db	6 dup (0)	; MAC destination address
	driverws	db	4 dup (0)	; their work space
	protocolws	dw	4 dup (0)	; our work space
	datalen		dw	0		; total length of sent buffer
	fragcount	dw	1		; number of buffer pieces
	frag1addr	dw	0,0		; seg:offset of first buffer
	frag1len	dw	0		; length of first buf frag
ECBstruct	ends				; 26 words

;  Look Ahead Structure
LookAheadStruc	struc
	LMediaHeaderPtr	dd	0		; pointer to MAC header
	LookAheadPtr	dd	0		; pointer to pkt Data
	LookAheadLen	dw	0		; length of pkt Data field
	LProtID		db	6 dup (0)	; protocol ident
	LBoardNum	dw	-1		; logical board of rcv'd pkt
	DataLookAheadDataSize dd 0	; new field, exists if bit 7 of the 
			; Driver's Configuration Table Mode Flags is set.
LookAheadStruc	ends

;  Rx Destination Address Type (First byte of ECB.DriverWS)
ECB_DIRECT		equ	00h		;Physical destination address
ECB_MULTICAST		equ	01h		;Multicast destination address
ECB_BROADCAST		equ	03h		;Broadcast destination address

;  System Error Code Definitions
LSLERR_OUT_OF_RESOURCES	equ	8001h
LSLERR_BAD_PARAMETER	equ	8002h
LSLERR_NO_MORE_ITEMS	equ	8003h
LSLERR_ITEM_NOT_PRESENT	equ	8004h
LSLERR_FAIL		equ	8005h
LSLERR_RX_OVERFLOW	equ	8006h
LSLERR_CANCELLED	equ	8007h
LSLERR_BAD_COMMAND	equ	8008h
LSLERR_DUPLICATE_ENTRY	equ	8009h
LSLERR_NO_SUCH_HANDLER	equ	800ah
LSLERR_NO_SUCH_DRIVER	equ	800bh

;  LSL MLID Services Function Codes
MLIDSUP_GET_ECB	       		equ	0
MLIDSUP_RETURN_ECB     		equ	1
MLIDSUP_DEFRAG_ECB	   	equ	2
MLIDSUP_SCHEDULE_AES_EVENT 	equ	3
MLIDSUP_CANCEL_AES_EVENT   	equ	4
MLIDSUP_GET_INTERVAL_MARKER	equ	5
MLIDSUP_DEREGISTER_MLID	   	equ	6  
MLIDSUP_HOLD_RECV_EVENT	   	equ	7  
MLIDSUP_START_CRITICAL_SECTION	equ	8  
MLIDSUP_END_CRITICAL_SECTION   	equ	9  
MLIDSUP_CRITICAL_SECTION_STATUS	equ	10 
MLIDSUP_SERVICE_EVENTS	      	equ	11
MLIDSUP_SEND_COMPLETE	      	equ	14 
MLIDSUP_ADD_PID			equ	15
MLIDSUP_GET_STACK_ECB		equ	16

;  LSL Protocol Stack Services Function Codes
PROTSUP_GET_ECB				equ	0
PROTSUP_RETURN_ECB			equ	1
PROTSUP_SCHEDULE_AES_EVENT 		equ	3
PROTSUP_CANCEL_EVENT			equ	4
PROTSUP_GET_INTERVAL_MARK		equ	5
PROTSUP_REGISTER_STACK			equ	6  
PROTSUP_DEREGISTER_STACK		equ	7  
PROTSUP_REGISTER_DEFAULT_STACK		equ	8  
PROTSUP_DEREGISTER_DEFAULT_STACK	equ	9  
PROTSUP_REGISTER_PRESCAN_STACK		equ	10 
PROTSUP_DEREGISTER_PRESCAN_STACK	equ	11 
PROTSUP_SEND_PACKET			equ	12 
PROTSUP_GET_PROTNUM_FROM_NAME		equ	16 
PROTSUP_GET_PID_PROTNUM_MLIDNUM		equ	17 
PROTSUP_GET_MLID_CTL_ENTRY		equ	18 
PROTSUP_GET_PROTO_CTL_ENTRY		equ	19 
PROTSUP_GET_LSL_STATS			equ	20 
PROTSUP_BIND_STACK_TO_MLID		equ	21 
PROTSUP_UNBIND_STACK_FROM_MLID		equ	22 
PROTSUP_ADD_PID				equ	23 
PROTSUP_RELINQUISH_CONTROL		equ	24 
PROTSUP_GET_LSL_CONFIG			equ	25

;  LSL General Services Function Codes
GENSERV_ALLOC_MEMORY		equ	0
GENSERV_FREE_MEMORY		equ	1
GENSERV_REALLOC_MEMORY		equ	2
GENSERV_MEMORY_STATISTICS	equ	3
GENSERV_ADD_MEMORY_TO_POOL	equ	4
GENSERV_ADD_GENERAL_SERVICE	equ	5
GENSERV_REMOVE_GENERAL_SERVICE	equ	6
GENSERV_GET_NETCFG_PATH		equ	7

;  LSL Configuration Table
LSLConfigurationStructure	struc
	LConfigTableMajorVer	db	1
	LConfigTableMinorVer	db	0
	LNumLSLRxBuffers	dd	0
	LRxBufferSize		dd	0	;Buffer size NOT including ECB struc size
	LMajorVersion		db	0
	LMinorVersion		db	0
	LConfigTableReserved	db	16 dup (0)
LSLConfigurationStructure	ends

;  MLID Control Commands
GET_MLID_CONFIGURATION		equ	0
GET_MLID_STATISTICS		equ	1
ADD_MULTICAST_ADDRESS		equ	2
DELETE_MULTICAST_ADDRESS	equ	3
MLID_SHUTDOWN			equ	5
MLID_RESET			equ	6
CREATE_CONNECTION		equ	7
REMOVE_CONNECTION		equ	8
SET_LOOK_AHEAD_SIZE		equ	9
DRIVER_POLL			equ	12

;  MLID Configuration Table Structure
MLIDConfigurationStructure	struc
	MSignature		db	'HardwareDriverMLID',8 dup (' ')
	MConfigTableMajorVer	db	1
	MConfigTableMinorVer	db	11
	MNodeAddress		db	6 dup (?)
	MModeFlags		dw	?
	MBoardNumber		dw	?
	MBoardInstance		dw	?
	MMaxPacketSize		dw	?
	MBestDataSize		dw	?
	MWorstDataSize		dw	?
	MCardLongName		dd	?
	MCardShortName		dd	?		; visible board name
	MFrameString		dd	?
	MReserved0		dw	0		;Must be set to 0
	MFrameID		dw	?
	MTransportTime		dw	?
	MRouteHandler		dd	?		;Only for Token-Ring
	MLookAheadSize		dw	?
	MLineSpeed		dw	?		;In Mbps or Kbps
	MReserved1		db	8 dup (0)	;Must be set to 0
	MMLIDMajorVer		db	?
	MMLIDMinorVer		db	?
	MFlags			dw	?
	MSendRetries		dw	?
	MLink			dd	?
	MSharingFlags		dw	?
	MSlot			dw	?
	MIOAddress1		dw	?
	MIORange1		dw	?
	MIOAddress2		dw 	?
	MIORange2		dw	?
	MMemoryAddress1		dd	?
	MMemorySize1		dw	?
	MMemoryAddress2		dd	?
	MMemorySize2		dw	?
	MIntLine1		db	?
	MIntLine2		db	?
	MDMALine1		db	?
	MDMALine2		db	?
MLIDConfigurationStructure	ends

;  MLID Config Table 'MFlags' bit definitions.
EISA	equ	01h			;EISA Bus
ISA 	equ	02h			;PC/AT Bus
MCA 	equ	04h			;PS/2 MCA Bus
Len_Info equ	40h			; pkt data length in lookahead info

;  MLID Config Table 'MModeFlags' bit definitions (no promiscuous mode).
MRealDriverBit		equ	0001h
MUsesDMABit		equ	0002h
MGuaranteedDeliveryBit	equ	0004h		;100% reliable on transmits
MMulticastBit		equ	0008h
MNeedsPollingBit	equ	0020h
MRawSendBit		equ	0040h

; Registered Stack structure, used during registration only
StackInfoStruc	struc
	StackNamePtr		dd	ip_string	; ptr to short name
	StackReceiveHandler	dd	ip_rcvr 	; rcv routine
	StackControlHandler	dd	pcontrol	; control routine
StackInfoStruc	ends

;  Protocol Control Commands
GET_STACK_CONFIGURATION		equ	0
GET_STACK_STATISTICS		equ	1
BIND_TO_MLID			equ	2
UNBIND_FROM_MLID		equ	3
INFORM_MLID_DEREGISTERED	equ	4

;  Protocol Configuration Table
ProtocolConfigStructure	struc
	PConfigTableMajorVer	db	1
	PConfigTableMinorVer	db	0
	PProtocolLongName	dd	plname
	PProtocolShortName	dd	psname		; "KERMIT"
	PProtocolMajorVer	db	3 		; MSK v3.15
	PProtocolMinorVer	db	15
	PConfigTableReserved	db	16 dup (0)
ProtocolConfigStructure	ends

;  Protocol Statistics Table
ProtocolStatStructure	struc
	PStatTableMajorVer	db	1
	PStatTableMinorVer	db	0
	PNumGenericCounters	dw	3		; just those below
	PValidCounterMask	dd	111b		; bitfield, 3 valids
	PTotalTxPackets		dw	2 dup (0)
	PTotalRxPackets		dw	2 dup (0)
	PIgnoredRxPackets	dw	2 dup (0)
	PNumCustomCounters	dw	0		; none
ProtocolStatStructure	ends

pinfo	struc				; per protocol local data for ecb
	pstack	dw	0		; StackID
	pprotid	db	6 dup (0)	; ProtID
	pboard	dw	0		; boardnum
pinfo	ends

_TEXT	SEGMENT  WORD PUBLIC 'CODE'
_TEXT	ENDS
_DATA	SEGMENT  WORD PUBLIC 'DATA'
_DATA	ENDS
CONST	SEGMENT  WORD PUBLIC 'CONST'
CONST	ENDS
_BSS	SEGMENT  WORD PUBLIC 'BSS'
_BSS	ENDS
DGROUP	GROUP	CONST, _BSS, _DATA
	ASSUME  CS: _TEXT, DS: DGROUP, SS: DGROUP, ES:NOTHING

_DATA      SEGMENT
	extrn	_pktbuf_wrote:word, _pktwnum:byte, _kpdint:word
	extrn	_eth_addr:byte, _arp_hardware:word, _MAC_len:word
	extrn	_mss:word, _tempip:byte, _kdebug:byte

pdsignature	db	'PKT DRVR'	; signature of a Packet Driver
pdslen		equ	$-pdsignature
if_type		dw	0		; interface type
if_class	db	0		; interface class
if_num		db	0		; interface number
if_func		db	0		; interface functionality
if_version	dw	0		; interface version
iptype		db	8,0		; IP packet type
iptypelen	equ	$-iptype	; length of type field for iptype
pktbufoff	dw	0		; offset of packet buffer
SLIPmac		dw	0,0,2		; fake SLIP dest Ethernet address
					; ODI material
useodi		db	0		; non-zero if using ODI for transport
lslsig		db	'LINKSUP$'	; LSL presence signature
lslsiglen	equ	$-lslsig
lslinit		dd	0		; LSL init entry point
					; LSL entry structure, do not separate
lslsupport	dd	0		; LSL protocol support API entry point
lslservice	dd	0		; LSL general services API entry point

mlidcont 	dd	0		; MLID Control entry point

ecbr_qty	equ	6;;4		; number of receive ECB's to allocate
maketab	MACRO				; macro to make receiver ecbs
cnt = 0
	rept ecbr_qty - 1
	ecbstruct <,,,odircmp>
cnt = cnt + 1
	endm
ENDM
ecbr		ecbstruct <,,,odircmp>	; first receiver ECB
		maketab			; make table of the other ecbr's
ecbx		ecbstruct <,,,odixcmp>	; one ECB for transmission
ecbr_busy	db 	ecbr_qty dup (0) ; our ecbr locks
ecbx_busy	db	0		; non-zero if ECBx owned by ODI
ecbr_num	dw	0		; temp to hold index of ecbr/ecbr_busy
rcvtype		dw	0		; temp, holds protocol TYPE for rcv
pconfig 	ProtocolConfigStructure <>	; as the name says
pstats		ProtocolStatStructure <>	; protocol statistics
registerstk 	StackInfoStruc <>	; bound stack setup structure
plname		db 13,'MS-DOS Kermit',0	; cnt, protocol stack long name, null
protword 	db 8,'PROTOCOL',0	; four NET.CFG keywords for Kermit
psname		db 6,'KERMIT',0		; cnt, protocol stack short name, null
bindword 	db 4,'BIND',0		; board to which to bind
myipword	db 4,'MYIP',0		; local IP from Telebit PPP driver
ip_type		equ	0008h		; Protocol TYPEs, big endian/net order
arp_type	equ	0608h
rarp_type	equ	3580h
ip_string 	db	2,'IP',0	; strings to match in NET.CFG file
arp_string	db	3,'ARP',0	;  to select pkt TYPEs
rarp_string	db	4,'RARP',0	;  RARP is optional
ip_stackid	pinfo	<>		; StackID, Protid, boardnum 
arp_stackid	pinfo	<>		;  for each protocol
rarp_stackid	pinfo	<>
bcast		db	6 dup (0ffh)	; Broadcast address, for reception
readnetcfg	db	0		; non-zero if have read NET.CFG
useboard	dw	-1		; board to be used, -1 = not inited
bdname		db	0,16 dup (0)	; length, 15 text, null, bound board
tells_len	db	0		; if MLID tells pkt len for lookahead
tempb		db	0
temp		dw	0
; parallel lists of NetWare ODI frame types, address lengths, ARP idents
frame_type	db	2,3,4,5,6,7, 9,10,11,14,15,16,23,27,28
num_frames	equ	($ - frame_type)
frame_adlen	db	6,6,6,6,6,6, 1,6, 6, 1, 6, 6, 6, 0, 0
hardware_type	db	1,6,6,6,6,12,4,6, 6, 7, 6, 6, 0, 0, 0

startttic dw	0		; my transmit timer storage spot
startrtic dw	0		; my receive timer storage spot
stoprtic dw	0
stopttic dw	0
tickind	 db	0		; 0 for receive, 1 for transmit
overhead dw	0		; timer measurement overhead
t0count	db	0
_DATA      ENDS

; ODI Frame types, frame strings, length (bytes) of a MAC level address:
; type	frame string	    MAC_len   hardware	comments
; 0	VIRTUAL_LAN		0	0	no MAC header used
; 1	LOCALTALK		6	11	Apple (Ether/Tokentalk is 802)
; 2	ETHERNET_II		6	1	Blue Book
; 3	ETHERNET_802.2		6	6	802.3 with 802.2 wrap
; 4	TOKEN-RING		6	4	802.5 with 802.2 wrap
; 5	ETHERNET_802.3		6	6	802.3 "raw", old Novell
; 6	802.4			6	6	Token Bus
; 7	NOVELL_PCN2	  	6	12	Novell's IBM PCnet2
; 8	GNET		  	6	4	Gateway, assumed TRN-like
; 9	PRONET-10		1 	4	Proteon TRN-like
; 10	ETHERNET_SNAP		6	1	802.3 with 802.2+SNAP
; 11	TOKEN-RING_SNAP		6	6	802.5 with 802.2+SNAP
; 12	LANPAC_II		6	?	Racore
; 13	ISDN			6	?	telco
; 14	NOVELL_RX-NET		1	7	Arcnet-like
; 15	IBM_PCN2_802.2		6	12	IBM PCnet2 with 802.2
; 16	IBM_PCN2_SNAP		6	12	IBM PCnet2,802.2+SNAP
; 17	OMNINET/4		?	?	Corvus
; 18	3270_COAXA		?	?	Harris
; 19	IP			?	?	tunneled
; 20	FDDI_802.2		6	?
; 21	IVDLAN_802.9		6	?	Commtex
; 22	DATACO_OSI		?	?	Dataco
; 23	FDDI_SNAP		6	6	802.7, with 802.2+SNAP
; 27	SLIP			0	0	SLIP, IP over serial link
; 28	PPP			0	0	PPP, IP over PPP serial link
;
;	  ARP hardware field, from RFC 1060
;     Type   Description                 
;     ----   -----------                
;	1    Ethernet (10Mb)
;	2    Experimental Ethernet (3Mb)
;	3    Amateur Radio AX.25
;	4    Proteon ProNET Token Ring
;	5    Chaos
;       6    IEEE 802 Networks
;       7    ARCNET
;       8    Hyperchannel
;       9    Lanstar
;      10    Autonet Short Address
;      11    LocalTalk
;      12    LocalNet (IBM PCNet or SYTEK LocalNET)

data	segment
	extrn	tv_segs:word, tv_sego:word, crt_lins:byte
	extrn	crt_cols:byte
data	ends

code	segment
	extrn	pcwait:far
code	ends

_TEXT	segment

pktdrvr	proc	near			; Packet Driver interrupt invokation
PKTDRVI:int	60h		; Interrupt number, modified by startup code
	ret
pktdrvr	endp

; pdinit(&etheraddress)
; Initialize Packet Driver or ODI for use by this program. Stores Ethernet
; address (or MAC address). _kpdint is 0 to scan first for a Packet Driver
; interrupt and fall back to search for ODI, or is a number 40h..7fh to
; target only that PD interrupt, or is 'DO' to target only ODI. If a PD is
; used then _kpdint is modified to be the found interrupt value.
; A 6 byte MAC level address is returned for convenience, even for SLIP. 
; Returns 1 for success, 0 for failure.

	public	_pdinit
_pdinit	proc	near
	push	bp
	mov	bp,sp
	push	es
	push	si
	push	di
	push	ds
	mov	ax,DGROUP
	mov	ds,ax

	mov	al,_kdebug
	push	ax
	or	_kdebug,2		; turn on timing option
	cli				; compute timing overhead
	call	rstart
	call	rstop
	mov	ax,startrtic
	sub	ax,stoprtic
	jns	pdinit8
	neg	ax
pdinit8:mov	overhead,ax		; overhead, ticks
	in	al,40h		; 8254 timer channel T0, read LSB
	xchg	ah,al
	in	al,40h		; read MSB
	xchg	al,ah		; order properly
	mov	bx,ax
	mov	ax,1		; number of milliseconds to delay
	call	pcwait		; delay AX milliseconds
	mov	ax,1
	call	pcwait
	mov	ax,1
	call	pcwait
	mov	ax,1
	call	pcwait
	in	al,40h		; 8254 timer channel T0, read LSB
	xchg	ah,al
	in	al,40h		; read MSB
	xchg	al,ah		; order properly
	sti
	sub	ax,bx
	jns	pdinit9
	neg	ax
pdinit9:add	ax,500		; round up to 4+millisec
	xor	dx,dx
	mov	cx,1000		; micro to millisec
	div	cx
	shr	ax,1		; divide by four timings
	shr	ax,1		; get 1 or 2 for 1 millisec
	and	al,3		; keep only two lower bits
	mov	t0count,al	; remember for msnpdi.asm
	pop	ax			; recover debug setting
	mov	_kdebug,al
	mov	ax,[bp+4+0]		; get offset of pktbuf
	mov	pktbufoff,ax		; save locally
	cmp	_kpdint,'DO'		; special indicator to use ODI?
	je	short pdinit2		; e = yes, do ODI
	mov	cx,40h			; interrupt range
	cmp	_kpdint,0		; user value given for PD Int?
	je	pdinit1			; e = no
	mov	cx,_kpdint		; use it
	mov	_kpdint,0		; assume no user value
pdinit1:mov	ah,getintv		; get interrupt vector to es:bx
	mov	al,cl			; vector number
	int	dos
	mov	si,offset dgroup:pdsignature ; look for signature
	push	cx
	mov	cx,pdslen		; length of string
	mov	di,bx
	add	di,3			; sig starts 3 bytes from entry point
	cld
	repe	cmpsb			; compare bytes
	pop	cx
	je	pdinit3			; e = found a match
	cmp	_kpdint,0		; user value given?
	jne	pdinit2			; ne = yes, so fail
	inc	cx
	cmp	cx,80h			; at end of range?
	jna	pdinit1			; na = not yet, try another int
					; no Packet Driver found or use ODI
pdinit2:call	odichk			; see if ODI is available now
	jnc	pdinit6			; nc = yes
	cmp	_kpdint,'DO'		; special indicator to use ODI?
	jne	pdinit5			; ne = no, have tried Packet Drivers
	mov	_kpdint,0		; setup for Packet Driver test
	mov	cx,40h			; scan from this interrupt
	jmp	pdinit1
pdinit6:mov	useodi,1		; say using ODI
	mov	_kpdint,'DO'		; signal ODI via PD interrupt variable
	mov	if_class,1		; say Ethernet_II for internal work
	mov	di,[bp+4+2]		; get offset of user's buffer
	mov	cx,eaddr_len		; length of address provided
	mov	si,offset DGROUP:SLIPmac ; get fake Ethernet address
	cld				;  in case code wants it early
	push	ds
	pop	es
	push	di
	rep	movsb			; copy to user buffer
	mov	cx,ecbr_qty
	mov	di,offset DGROUP:ecbr_busy ; clear receive ecb busy flags
	xor	al,al
	rep	stosb
	mov	ecbx_busy,al		; and transmitter busy lock
	pop	di
	clc
pdinit5:jmp	pdret			; exit (carry set is failure)
 					; Packet Driver details
pdinit3:mov	byte ptr PKTDRVI+1,cl	; force in new PD interrupt, code mod
	mov	_kpdint,cx		; remember interrupt number
					; find Ethernet address
	mov	ah,pdgetinfo		; get Packet Driver information
	mov	al,0ffh
	xor	bx,bx			; optional handle
	push	ds			; this call changes ds and si
	push	si
	call	pktdrvr			; call the Packet Driver
	pop	si
	pop	ds
	jc	pdret			; c = failure
	mov	if_type,dx		; save details for access calls
	mov	if_class,ch
	mov	if_num,cl
	mov	if_func,al
	mov	if_version,bx
	mov	ah,pd_access		; access packets
	mov	al,ch			; Ethernet class
	mov	bx,dx			; type
	mov	dl,cl			; interface number
	mov	cx,iptypelen		; type length for iptype
	mov	si,offset dgroup:iptype	; address of TYPE
	mov	di,cs
	mov	es,di
	mov	di,offset pdrcvr	; ES:DI is our Packet Driver receiver
	call	pktdrvr
	jc	pdret			; c = failure
	mov	bx,ax			; put returned handle in BX
	mov	_arp_hardware,0001h	; Type 1 hardware, Ethernet
	mov	_MAC_len,6		; 6 bytes of MAC level address
	mov	ax,DGROUP		; our data segment
	mov	es,ax			; segment of Ethernet address buffer
	mov	di,[bp+4+2]		; get offset of user's buffer
	mov	cx,eaddr_len		; length of address wanted
	cmp	if_class,IF_SLIP	; interface class of SLIP?
	jne	pdinit4			; ne = no
	mov	si,offset DGROUP:SLIPmac ; get fake Ethernet address
	cld
	push	di			; save in case PD actually uses it
	rep	movsb			; copy to user buffer
	pop	di
	mov	_arp_hardware,0		; no hardware type
	mov	_MAC_len,0		; no MAC level address
	mov	_mss,1006-44		; set SLIP max frame size too
pdinit4:mov	ah,pd_get_address	; get the Ethernet address
	push	bx			; save handle
	call	pktdrvr			; get Ethernet address to es:di buf
	pop	bx
	pushf				; save carry flag
	jnc	pdinit7
	cmp	if_class,IF_SLIP	; interface class of SLIP?
	jne	pdinit7			; ne = no
	popf
	clc				; forgive error of SLIP8250 v11.x
	pushf
pdinit7:mov	ah,pd_release		; release this Type, bx has handle
	call	pktdrvr
	popf				; recover carry flag
pdret:	mov	ax,1			; return C status, 1 for success
	jnc	pdret1
	xor	ax,ax			; 0 for failure
pdret1:	pop	ds			; success
	pop	di
	pop	si
	pop	es
	mov	sp,bp			; restore stack
	pop	bp			; recover bp reg
	ret
_pdinit	endp

; int pdinfo(& int version, & int class, & int pdtype, & int number,
;  & int functionality)
; Get Packet Driver pedigree
	public	_pdinfo
_pdinfo	proc	near
	push	bp
	mov	bp,sp
	push	di
	push	cx
	push	bx
	push	ax			; save al for later use
	mov	di,[bp+4+0]
	mov	bx,if_version
	mov	[di],bx			; return version
	mov	al,if_class		; class
	xor	ah,ah
	mov	di,[bp+4+2]
	mov	[di],ax			; return as an int
	mov	di,[bp+4+4]
	mov	dx,if_type
	mov	[di],dx			; type
	mov	di,[bp+4+6]
	xor	ch,ch
	mov	cl,if_num
	mov	[di],cx			; interface number, as an int
	pop	ax			; recover al
	mov	di,[bp+4+8]
	xor	ah,ah
	mov	al,if_func
	mov	[di],ax			; functionality, as an int
	mov	ax,1			; C style exit status, 1 = success
	pop	bx
	pop	cx
	pop	di
	pop	bp
	ret
_pdinfo	endp

; int pdclose(int handle)
; Close a Packet Driver or ODI handle.
; Returns (in AX) 1 if successful, else 0.
	public	_pdclose
_pdclose	proc	near
	push	bp
	mov	bp,sp
	push	bx
	mov	bx,[bp+4+0]		; handle
	cmp	useodi,0		; using ODI?
	je	pdclos2			; e = no
	mov	ax,bx			; get handle
	call	odiunbind		; unbind from LSL and MLID
	jmp	short pdclos3

pdclos2:mov	ah,pd_release		; release_type
	call	pktdrvr

pdclos3:mov	ax,1			; assume success
	jnc	pdclos1			; nc = success
	xor	ax,ax			; 0 for failure
pdclos1:pop	bx
	pop	bp
	ret
_pdclose	endp

; int pdaccess(char *type, int typelen, int *handle)
; Register access for packet TYPE with the Packet Driver or ODI
; Provides a handle for the TYPE.
; Returns 1 for success, 0 for failure.
	public	_pdaccess
_pdaccess proc	near
	push	bp
	mov	bp,sp
	push	es
	push	si
	push	di
	push	ds
	push	es
	mov	ax,dgroup		; set up data segment addressibility
	mov	ds,ax
	mov	al,if_class		; interface class (frame)
	mov	bx,if_type		; interface type (vendor)
	mov	dl,if_num		; interface number (board number)
	xor	dh,dh
	mov	si,[bp+4+0]		; get offset of packet TYPE buffer
	mov	cx,[bp+4+2]		; typelen (length of buf contents)
	cmp	useodi,0		; using ODI?
	je	pdacc8			; e = no
	mov	ax,[si]			; provide TYPE
	call	odibind			; Bind to a virtual board
	jc	pdacc1			; c = fail, error code in AX
	jmp	short pdacc9		; store handle returned in AX

pdacc8:	cmp	if_class,IF_SLIP	; SLIP?
	jne	pdacc3			; ne = no
	xor	cx,cx			; TYPE len = 0 means accept all types
pdacc3:	mov	di,cs			; ES:DI is our Packet Driver receiver
	mov	es,di
	mov	di,offset pdrcvr	; local receiver
	mov	ah,pd_access		; set access
	call	pktdrvr
	jc	pdacc1			; c = failure
pdacc9:	mov	si,[bp+4+4]		; offset of handle
	mov	[si],ax			; return the handle
pdacc1:	mov	ax,1			; C level status, 1 = success
	jnc	pdacc2			; nc = success
	xor	ax,ax			; 0 = failure
pdacc2:	pop	es
	pop	ds
	pop	di
	pop	si
	pop	es
	pop	bp
	ret
_pdaccess endp

; int pkt_send(char *buffer, int length)
; returns 1 on success, 0 on failure
; Send a packet.
	public	_pkt_send
_pkt_send	proc	near
	push	bp
	mov	bp,sp
	push	es
	push	ds
	push	si
	push	di			; don't trust lower levels on regs
	push	cx
	push	dx
	mov	ax,DGROUP		; segment of outgoing buffer
	mov	ds,ax			;  will be DS:SI for Packet Driver
	cmp	useodi,0		; using ODI?
	je	pktsen5			; e =no, use PD
	call	_odi_busy		; is transmitter busy?
	or	ax,ax			; returned response
	jz	pktsen4			; z = not busy
	stc				; fail
	jmp	short pktsen1

pktsen4:mov	si,[bp+4+0]		; buffer's offset (seg is dgroup)
	mov	cx,[bp+4+2]		; buffer's length
	call	odixmt			; do LSL transmit with DS:SI and CX
	sti				; interrupts on (odixmt turns off)
	jc	pktsen1			; c = internal failure to send
	or	ax,ax			; LSL status
	jz	pktsen1			; z = success
	stc				; set carry for failure
	jmp	short pktsen1		; done (AX non-zero if error)
; Note that checking for transmission errors is not readily done with async
; sending, so we cross our fingers and hope for the best.
					;
					; Packet Driver sending
pktsen5:mov	si,[bp+4+0]		; buffer's offset (seg is dgroup)
	mov	cx,[bp+4+2]		; buffer's length
	mov	ah,pd_send		; send packet (buffer = ds:si)
	call	tstart			; start transmit timer
	call	pktdrvr			; invoke Packet Driver
	call	tstop			; stop transmit timer
					; common exit
pktsen1:mov	ax,1			; return C level success (1)
	jnc	pktsen2			; nc = success
	xor	ax,ax			; else C level failure (0)
pktsen2:pop	dx
	pop	cx
	pop	di
	pop	si
	pop	ds
	pop	es
     	pop	bp
	ret
_pkt_send endp

; int odi_busy(void)
; Return non-zero if ODI is unable to accept new transmission at this time.
	public _odi_busy
_odi_busy proc near
	xor	ax,ax			; prepare not-busy/false (0) response
	cmp	useodi,0		; using ODI?
	je	odi_bsx			; e = no, using Packet Driver
	mov	cx,3			; loop counter
odi_bs1:cmp	ecbx_busy,0		; is ODI transmit done yet?
	je	odi_bs2			; e = yes, else we can't touch it yet
	push	bx
	push	cx
	push	bp			; playing safe
	push	es
	mov	bx,PROTSUP_RELINQUISH_CONTROL
	call	lslsupport		; give time to LSL and MLID
	pop	es
	pop	bp
	pop	cx
	pop	bx
	loop	odi_bs1			; retry til ready or exhausted
odi_bs2:mov	al,ecbx_busy		; return 0 for not-busy
	xor	ah,ah
odi_bsx:ret
_odi_busy endp

; Our Packet Driver receiver, far called only by the Packet Driver and our
; local ODI code (odircvr and odircmp).
; Packet buffer linked list -
;	each link is	db flag		; 1 = free, 2 = in use, 4 = allocated
;					;  but not in use yet, 0 = end of buf,
;					;  8 = read but not freed.
;			db _pktwnum	; sequential number of pkt written
;			dw count	; length of data field
;			db count dup (?) ; the allocated data field
;	The head of the chain has a link like all others.
;	The end of the chain has a link with flag == 0 and count = -BUFISZE
;	to point to the beginning of the buffer (circular).
;	Packet buffer garbage collection is done after a buffer has been
;	transferred to us, and does so by relinking adjacent free blocks.
; _pktbuf_wrote is used to remember the link where the last write occurred
; and should be initialized to the tail link to point the next write to
; the beginning of the buffer.
; The Packet Driver and our ODI routines call this first with AX = 0 to 
; obtain a buffer pointer in ES:DI from us (0:0 if we refuse the pkt) with 
; CX = packet size, and again later with AX = 1 to post completion.

pdrcvr	proc	far			; Packet Driver receiver
	or	ax,ax			; kind of request (0, 1)
	jz	pdrcvr1			; z = first, get-a-buffer
	; Second upcall, packet has xfered, DS:SI set by caller to buffer
 	push	ds
	push	si
	push	cx
	push	bx
	push	ax			; assume DS:SI is one of our buffers
	mov	ax,DGROUP
	mov	ds,ax			; set ds to our data segment
	call	rstop			; stop receive timer
	or	si,si			; is it legal (from first upcall)?
	jz	pdrcvr11		; z = no, ignore this call
	sub	si,linksize		; backup to link info
	mov	cx,100			; number of trials to find space
	cmp	byte ptr [si].flag,4	; is this buffer allocated (4)?
	jne	pdrcvr8			; ne = no, do cleanups and quit
	mov	byte ptr [si].flag,2	; flag = 2 for buffer is now ready
	mov	si,pktbufoff 		; start of packet buffer
					; join contiguous free links
pdrcvr8:mov	al,[si].flag		; flags byte
	cmp	al,1			; is link free?
	jne	pdrcvr10		; ne = no, look for a free link
pdrcvr9:mov	bx,[si].count		; count (length) of this link
	mov	al,[bx+si+linksize].flag; flag of following link
	cmp	al,1 			; is next link free?
	jne	pdrcvr10		; ne = no, look for free link
	mov	ax,[bx+si+linksize].count ; count taken from next link
	add	ax,linksize		;  plus the next link's info field
	add	[si].count,ax		; add it to this count (merge links)
	loop	pdrcvr9			; re-examine this new longer link
	jmp	short pdrcvr11		; too many trials, abandon effort

pdrcvr10:or	al,al			; end of list?
	jz	pdrcvr11		; z = yes
	add	si,[si].count		; look at next link (add count)
	add	si,linksize		; and link info
	loop	pdrcvr8			; keep looking
pdrcvr11:pop	ax
	pop	bx
	pop	cx
	pop	si
	pop	ds
	ret

pdrcvr1:push	ds			; First upcall, provide buffer ptr
	push	dx			; return buffer in ES:SI
	mov	di,dgroup		; get local addressibility
	mov	ds,di
	mov	es,di			; packet buffer is in same group
	cmp	useodi,0		; using Packet Driver?
	jne	pdrcvr1a		; ne = no, ODI, has separate rstart
	call	rstart			; start receive timer
pdrcvr1a:mov	di,_pktbuf_wrote	; where last write occurred
	or	di,di			; NULL?
	jz	pdrcvr4			; z = yes, write nothing
	mov	dl,100			; retry counter, breaks endless loops
	cmp	[di].flag,1		; is this link free?
	je	pdrcvr5			; e = yes, use it

pdrcvr2:add	di,[di].count		; point at next link (add count and
	add	di,linksize		;  link overhead)
	dec	dl			; loop breaker count down
	jz	pdrcvr4			; z = in an endless loop, exit
	cmp	[di].flag,1		; is this link free (1)?
	je	pdrcvr5			; e = yes, setup storage
	cmp	di,_pktbuf_wrote 	; have we come full circle?
	jne	pdrcvr2			; ne = no, keep looking
pdrcvr4:pop	dx
	pop	ds			; failure or buffer not available (0)
	xor	ax,ax			; return what we received in ax
	xor	di,di			; return ES:DI as null to reject
	mov	es,di
	ret
					; this link is free
pdrcvr5:add	cx,2			; defense for 8/16 bit xfr mistakes
	mov	ax,[di].count		; length of available data space
	cmp	ax,cx			; cx is incoming size, enough space?
	jl	pdrcvr2			; l = no, go to next link
	mov	[di].flag,4		; mark link flag as being alloc'd (4)
	mov	dh,_pktwnum 		; write pkt sequencer number
	mov	[di].bufnum,dh		; store in buffer, permits out of
	inc	_pktwnum		;  temporal order deliveries
	mov	_pktbuf_wrote,di	; remember where we wrote last
	sub	ax,cx			; allocated minus incoming packet
	cmp	ax,60+linksize		; enough for new link and miminal pkt?
	jl	pdrcvr6			; l = not enough for next pkt
	mov	[di].count,cx		; update space really used
	push	di			; save this link pointer
	add	di,linksize		; plus current link info
	add	di,cx			; plus space used = new link point
	sub	ax,linksize		; available minus new link info
	mov	[di].flag,1		; mark new link as free (1)
	mov	[di].count,ax		; size of new free data area
	pop	di			; return to current link
pdrcvr6:add	di,linksize		; point at data portion
pdrcvr7:xor	ax,ax			; return what we received in ax
	pop	dx			; CX is size of requested buffer
	pop	ds			; ES:DI is the pkt buffer address
	ret
pdrcvr	endp

; Check for Windows enhanced mode. Return carry set if true, else carry clear.
chkwin proc	near
	push	es
	mov	ah,getintv		; check for valid Int 2Fh handler
	mov	al,2fh			; vector 2fh
	int	dos			; to es:bx
	mov	ax,es
	pop	es
	or	ax,bx			; check if vector exists
	jnz	chkwin2			; nz = yes
	stc
	ret

chkwin2:mov	ax,1683h		; Windows 3, get current virt machine
	int	2fh
	cmp	ax,1683h		; virtual machine, if any
	je	chkwin3			; e = no Windows, ok to proceed
	stc
	ret
chkwin3:clc				; not Windows enhanced mode
	ret
chkwin endp

; Begin Novell ODI support routines
; Note that while we use Ethernet_II (6 dest, 6 source, 2 TYPE bytes) to/from
; internal consumers the frame format to/from ODI is in the hands of ODI.
; Hopefully this will permit TCP/IP operation over all supported frame types.
; ARP/RARP packets are sized to the frame in use.
;
; Check for LSL presence, and if present then get entry points.
; Returns carry set if failure, else carry clear.
; This procedure is closely modeled upon the Novell example.
odichk	proc	near
	cmp	useodi,0		; already inited?
	je	odichk0			; e = no
	clc
	ret
odichk0:call	chkwin			; check for Windows enhanced mode
	jnc	odichk5			; nc = not, continue
	ret				; return failure
odichk5:push	es
	mov	ah,getintv		; get LSL via multiplexer interrupt
	mov	al,2fh			; vector 2fh
	int	dos			; to es:bx
	mov	ax,es
	or	ax,bx			; check if vector exists
	jnz	odichk1			; nz = yes
	pop	es
	stc
	ret

odichk1:mov	ax,0c000h		; look at multiplexer slots c0 et seq
	push	si
	push	di
odichk2:push	ax
	int	2fh
	cmp	al,0ffh			; is slot in use?
	pop	ax
	je	odichk4			; e = yes, check for LSL being there
odichk3:inc	ah			; next slot
	or	ah,ah			; wrapped?
	jnz	odichk2			; nz = no, keep looking
	pop	di
	pop	si
	pop	es
	stc				; not found, fail
	ret

odichk4:mov	di,si			; es:si should point to "LINKSUP$"
	mov	si,offset DGROUP:lslsig	; expected signature
	mov	cx,lslsiglen		; length
	cld
	repe	cmpsb			; check for signature
	jne	odichk3			; ne = no match, try next Int 2fh slot
	mov	word ptr lslinit,bx	; found entry, save init entry point
	mov	ax,es			;  returned in es:bx
	mov	word ptr lslinit+2,ax
	mov	ax,ds
	mov	es,ax			; get LSL main support/service addrs
	mov	si,offset DGROUP:lslsupport ; address of LSL entry point array
	mov	bx,2			; request support/service entry points
		; fills in far addresses of lslsupport and lslservice routines
	call	lslinit			; call LSL initialization routine
	pop	di
	pop	si
	pop	es
	clc				; success
	ret
odichk	endp

; Bind a protocol TYPE to an ODI virtual board.
; Enter with TYPE (big endian/network order) in AX.
; Packet reception begins immediately upon a successful bind.
; Uses NET.CFG if information is available.
; Obtain StackID (our ident to the LSL), ProtID (ident of LSL's decoder),
; and boardnumber (the logical board), then bind to start reception. Do for
; one of our protocols.
; Returns PD handle (TYPE) in AX and carry clear upon success, else carry set.
odibind proc	near
	push	ax
	push	bx
	push	si
	push	di
	push	es
	mov	bx,DGROUP
	mov	es,bx
	cmp	ax,ip_type			; IP, 0x0008h?
	jne	odibind1			; ne = no
	mov	ax,offset DGROUP:ip_string	; put IP string in request
	mov	bx,offset ip_rcvr		; set address of receiver esr
	mov	di,offset DGROUP:ip_stackid	; set address of stackid struc
	jmp	short odibind3

odibind1:cmp	ax,arp_type			; ARP, 0x0608?
	jne	odibind2			; ne = no
	mov	ax,offset DGROUP:arp_string
	mov	bx,offset arp_rcvr
	mov	di,offset DGROUP:arp_stackid
	jmp	short odibind3

odibind2:cmp	ax,rarp_type			; RARP, 0x3580?
	je	odibind2a			; e = yes
	jmp	odibindx			; ne = no, fail
odibind2a:mov	ax,offset DGROUP:rarp_string
	mov	bx,offset rarp_rcvr
	mov	di,offset DGROUP:rarp_stackid

odibind3:mov	word ptr registerstk.StackNamePtr,ax ; insert ptr to string
	mov	word ptr registerstk.StackReceiveHandler,bx  ; setup esr addr

; Note: to use Prescan or Default registrations delete StackNamePtr & StackID.
; StackID is not used with these latter methods, and their reception begins
; at registration rather than at bind (so this area would be redesigned).
	mov	bx,PROTSUP_REGISTER_STACK ; register the protocol by name
	mov	si,offset DGROUP:registerstk ; registration form pointer
	push	di			; save ptr to xxx_stackid storage
	call	lslsupport		; call LSL with the address in es:si
	pop	di
	jz	odibind3a		; z = success
	jmp	odibindx		; nz = failure
odibind3a:mov	[di].pstack,bx		; save returned StackID (LSL's handle
					;  for our protocol stack)
	cmp	readnetcfg,0		; have read NET.CFG for BIND info?
	jne	odibind4		; ne = yes
	mov	useboard,-1		; clear board-to-use word
	call	getbind			; find Kermit's bind board in NET.CFG
	inc	readnetcfg		; say have read the file
	cmp	word ptr bdname,256*'#'+2 ; is board name #<digit>?
	jne	odibind4		; ne = no, assume regular driver name
	mov	al,bdname+2		; get ascii digit
	sub	al,'1'			; remove ascii bias (external=1 based)
	xor	ah,ah			;  but we are zero based internally
	cmp	al,8			; arbitrary limit of 8 boards
	ja	odibind4		; a = out of range, ignore value
	mov	useboard,ax		; and make this the board number
	mov	bdname,0		; and don't use bdname as a name
odibind4:mov	[di].pboard,0		; assume board zero to start loop
	mov	ax,useboard		; board to be used, if any
	or	ax,ax			; boards 0 and up are legal
	jl	odibind5		; l = no board found yet, search
	mov	[di].pboard,ax		; specify board, get ProtID

odibind5:mov	bx,PROTSUP_GET_MLID_CTL_ENTRY	; get MLID control entry
	mov	ax,[di].pboard		; for this board
	push	di
	call	lslsupport		; call LSL for the address to es:si
	pop	di
	mov	word ptr mlidcont,si
	mov	word ptr mlidcont+2,es	; MLID control routine
	jz	odibind7		; z=success, have a board to work with
	cmp	ax,LSLERR_NO_MORE_ITEMS ; out of items?
	je	odibind5a		; e = yes, no more boards
  	cmp	ax,LSLERR_ITEM_NOT_PRESENT ; other boards may exist?
	je	odibind7		; e = yes
odibind5a:jmp	odibindx		; fail

odibind7:mov	bx,PROTSUP_GET_PID_PROTNUM_MLIDNUM ; get ProtID from StackID
	mov	ax,[di].pstack		; StackID
	mov	cx,[di].pboard		;  and assumed board number
	mov	si,dgroup
	mov	es,si			; set es:di to the ProtID buffer
	lea	si,[di].pprotid		;  in our storage slot per protocol
	push	di
	call	lslsupport		; ask LSL for the ProtID string
	pop	di			;  to that 6-byte buffer
	jz	odibind9		; z = success, found a recognizer
	cmp	useboard,0		; has a board been pre-identified?
	jge	odibind5a		; ge = yes, so the matchup failed
	inc	[di].pboard		; next board
	jmp	short odibind5		; keep looking for a board

odibind9:mov	bx,GET_MLID_CONFIGURATION ; get MLID config ptr to es:si
	mov	ax,[di].pboard
	call	mlidcont		; call MLID control routine
	jnz	odibindx		; nz = failure
	cmp	bdname,0		; was a board name bound via BIND?
	je	odibin10		; e = no, don't check on it
	push	es			; save pointer to MLID config table
	push	di
	push	si
	les	di,es:[si].MCardShortName ; get short name of this board
	lea	si,bdname		; desired board name string
	mov	cl,bdname		; length of desired board name
	inc	cl			; include length byte
	xor	ch,ch
	cld
	repe	cmpsb			; compare  len,string  for both
	pop	si
	pop	di
	pop	es
	je	odibin10		; e = found desired board
	inc	[di].pboard		; try next board
	jmp	short odibind5		; keep looking for the desired board

odibin10:mov	ax,[di].pboard		; get current board number
	mov	useboard,ax		; remember for next protocol
	mov	ax,es:[si].MWorstDataSize ; max header, leaving this size
	sub	ax,20+20		; minus IP and TCP headers
	mov	_mss,ax			; set new operational value
	mov	bx,es:[si].MFrameID	; frame ident, for get_hwd
	call	get_hwd			; get hardware specifics
	push	es
	push	si			; save config pointer
	lea	si,es:[si].MNodeAddress	; point to address in config struct
	push	ds			; save ds
	push	di
	mov	di,offset DGROUP:_eth_addr; where our MAC address is stored
	mov	ax,ds
	mov	cx,es
	mov	es,ax
	mov	ds,cx
	cld
	mov	cx,6			; MAC address length, bytes, fixed
	rep	movsb			; copy MAC address to global array
	pop	di
	pop	ds
	pop	si			; recover configuration table pointer
	pop	es
	mov	tells_len,0		; presume no lookahead data length
	test	es:[si].MFlags,Len_Info	; capas bit for length provided (new)
	jz	odibin12		; z = does not provide
	inc	tells_len		; say provides length

odibin12:mov	bx,PROTSUP_BIND_STACK_TO_MLID	; Bind stack to MLID
	mov	ax,[di].pstack		; StackID
	mov	cx,[di].pboard		; board number
	call	lslsupport		; bind our protocol stack to board
	jnz	odibindx		; nz = failure
	pop	es			; received packets can interrupt now
	pop	di
	pop	si
	pop	bx
	pop	ax
	clc
	ret
odibindx:pop	es
	pop	di
	pop	si
	pop	bx
	pop	ax
	stc				; say failure
	ret
odibind endp

; Worker for odibind. Find NET.CFG, extract name of board driver from pair of
; lines reading as below (Protocol must be in column 1, bind must be indented)
; Protocol Kermit			Kermit's main section header
;   bind  <board_driver_name>		indented, without the <> signs
;or
; Protocol Kermit
;   bind #<digit>			selects DOS driver load order (from 1)
;
; Examples -
; Protocol Kermit
;   bind exos
;or
; Protocol Kermit
;   bind #2
;			and elsewhere there is the board driver section:
; Link Driver exos
;
; If found put the board driver name in array bdname, as length byte, string,
; then a null. If not found make length byte bdname be zero. We treat NET.CFG
; as case insensitive.
; Unless we use the special Kermit section then LSL will assign to us the
; first board loaded by DOS supporting the frame kind of our protocol.
; Link Driver section line "Protocol name type frame"  simply associates a
; frame kind with the name and type, but not with a board. L.D. section line
; frame <frame kind> attaches that frame kind to the board, if it fits.
; Kermit uses "name" in the above line to pinpoint a protocol, not a board.
; Add keyword MYIP to obtain a dynamically assigned IP value from Telebit's
; ODI PPP driver. The user must say "Set TCP Address Telebit-PPP" for this
; to have effect.
getbind	proc	near
	mov	bdname,0		; clear board name length
	mov	_tempip,0		; clear dynamic IP string count
	push	ds
	mov	bx,GENSERV_GET_NETCFG_PATH ; get fully formed NET.CFG name
	call	lslservice		;  from LSL general services to ds:dx
	jz	getbin1			; z = success
	pop	ds			; fail
	ret
getbin1:mov	ah,fopen		; open file NET.CFG
	mov	al,40h			;  for reading, deny none
	int	dos			; returns file handle in ax
	pop	ds
	mov	temp,ax			; save handle for getbyte
	jnc	getbin2			; nc = success
	ret				; carry set for failure

getbin2:mov	bx,1			; subscript, at start of a line

getbin3:call	getbyte			; read a byte, uppercased
	jnc	getbin4			; nc = success
	ret				; c = end of file
getbin4:cmp	protword[bx],al		; compare to "PROTOCOL"
	jne	getbin5			; ne = failure, scan for end of line
	inc	bx
	cmp	bl,protword		; length, matched all bytes?
	jbe	getbin3			; be = no, match more
	jmp	short getbin6		; ae = yes, next phrase
	ret				; fail out 

getbin5:cmp	al,LF			; end of a line?
	je	getbin2			; e = yes, scan for PROTOCOL again
	call	getbyte
	jnc	getbin5			; keep consuming line material
	ret				; fail out at end of file
					; Short Name following "PROTOCOL"
getbin6:call	getbyte			; get separator char, discard
	jnc	getbin7
	ret				; c = eof
getbin7:call	getbyte			; read short name of protocol
	jnc	getbin7a		; nc = text
	ret				; return on eof
getbin7a:cmp	al,' '			; white space?
	jbe	getbin7			; be = yes, stay in this state
	mov	bx,1			; subscript
getbin8:cmp	psname[bx],al		; compare to our protocol short name
	jne	getbin5			; ne = failure, scan for end of line
	cmp	bl,psname		; matched all bytes?
	jae	getbin9			; ae = yes, next phrase
	inc	bx
	call	getbyte			; get next byte to match
	jnc	getbin8			; nc = not eof yet
	ret

getbin9:call	getbyte			; go to next line, enforce whitespace
	jc	getbin20		; c = eof
	cmp	al,LF			; end of a line?
	jne	getbin9			; ne = no, scan for end of line
	call	getbyte			; look for whitespace
	jc	getbin20		; c = eof
	cmp	al,'#'			; comment line?
	je	getbin9			; e = yes, get next line
	cmp	al,';'			; comment line?
	je	getbin9			; e = yes, get next line
	cmp	al,' '			; required whitespace?
	ja	getbin5			; a = no, start over

getbin10:call	getbyte			; look for keyword "BIND"
	jc	getbin20
	cmp	al,' '			; white space?
	jbe	getbin10		; be = yes, stay in this state
	mov	bx,1			; subscript
	cmp	al,'M'			; M for MYIP?
	je	getbin30		; e = yes
	cmp	al,'B'			; B for BIND?
	jne	getbin9			; ne = no, next line

getbin12:cmp	bdname,0		; have bind name yet?
	je	getbin13		; e = no
	jmp	getbin9			; else get next line
getbin13:cmp	bindword[bx],al		; compare to "BIND"
	jne	getbin9
	cmp	bl,bindword		; matched all bytes?
	jae	getbin14		; ae = yes, next phrase
	call	getbyte
	jc	getbin20		; c = eof
	inc	bx
	jmp	short getbin13		; keep reading

getbin14:call	getbyte			; skip white space before board name
	jc	getbin20			
	cmp	al,' '			; white space?
	jbe	getbin14		; be = yes, skip it

getbin15:mov	bl,bdname		; board name, length byte, starts at 0
	xor	bh,bh
	inc	bl
	mov	bdname,bl		; update length of board driver name
	xor	ah,ah			; get a null
	mov	word ptr bdname[bx],ax	; store as board short name,null
	cmp	bx,15			; legal limit on short name?
	jbe	getbin16		; be = ok
	mov	bdname,ah		; illegal, clear board name length
	jmp	getbin9			; get next line
getbin16:call	getbyte
	jc	getbin20		; reached eof, is ok
       	cmp	al,' '			; usable text?
	ja	getbin15		; a = yes, else stop storing name
	jmp	getbin9			; get next line

getbin20:ret
	
getbin30:cmp	_tempip,0		; have IP word already?
	je	getbin31		; e = no
	jmp	getbin9			; get new line

getbin31:cmp	myipword[bx],al		; compare to "MYIP"
	jne	getbin9			; ne = failure, start over
	cmp	bl,myipword		; matched all bytes?
	jb	getbin32		; b = no
	jmp	short getbin33

getbin32:call	getbyte
	jc	getbin20		; c = eof
	inc	bx
	jmp	getbin31		; keep reading

getbin33:call	getbyte			; skip white space before IP address
	jc	getbin20			
	cmp	al,' '			; white space?
	jbe	getbin33		; be = yes, skip it

getbin34:mov	bl,_tempip		; our IP, length byte, starts at 0
	xor	bh,bh
	inc	bl
	mov	_tempip,bl		; update length of IP string
	xor	ah,ah			; get a null
	mov	word ptr _tempip[bx],ax	; store as IP, null
	cmp	bx,15			; legal limit on IP?
	jbe	getbin35		; be = ok
	mov	_tempip+1,ah		; illegal, clear IP
	jmp	getbin9			; and quit
getbin35:call	getbyte
	jc	getbin36		; reached eof, is ok
       	cmp	al,' '			; usable text?
	ja	getbin34		; a = yes, else stop storing name
	jmp	getbin9			; get next line
getbin36:ret	
getbind	endp

; Worker for getbind. Delivers one byte per call from NET.CFG, upper cased.
; Returns carry set and NET.CFG file closed at end of file.
; Temp has NET.CFG file handle, tempb is our one byte buffer for disk i/o.
getbyte	proc	near
	mov	dx,offset tempb		; ds:dx points to start of buffer
	mov	ah,fread		; read from file to buffer
	mov	cx,1			; this many bytes
	push	bx
	mov	bx,temp			; get file handle
	int	dos
	pop	bx
	jc	getbyt2			; c = failure
	cmp	ax,1			; got the single byte?
	jb	getbyt2			; b = no, failure
	mov	al,tempb		; return read byte
	cmp	al,'z'			; in lower case range?
	ja	getbyt1			; a = no
	cmp	al,'a'			; in lower case range?
	jb	getbyt1			; b = no
	and	al,not 20h		; lower to upper case
getbyt1:clc				; carry clear for success
	ret				; return char in AL
getbyt2:push	bx
	mov	bx,temp			; file handle
	mov	ah,fclose		; close the file
	int	dos
	pop	bx
	stc				; say EOF or other failure
 	ret
getbyte	endp

; Worker for odibind.
; Enter with BX holding Novell frame type from the MLID configuration table. 
; Set _arp_hardware and _MAC_len and return BX holding _MAC_len value, else 
; if frame is not supported return BX = 0. These two values are needed by the
; ARP functions. This list searching method is to accomodate the ever 
; expanding quantity of frame types appearing with ODI; we deal with those we
; understand (sic).
get_hwd	proc	near
	push	es
	push	di
	mov	ax,DGROUP
	mov	es,ax
	mov	al,bl			; get frame value (MLID config)
	xor	bx,bx			; prepare no-match return value
	mov	di,offset frame_type	; list to search
	mov	cx,num_frames		; number of elements in the list
	cld
	repne	scasb			; byte search
	jne	get_hwd1		; ne = no match, fail
	sub	di,offset frame_type+1	; make di be an index along the list
	mov	al,hardware_type[di]	; ARP/RARP hardware type ident
	xor	ah,ah			; return in local (host) order
	mov	_arp_hardware,ax	; hardware type for ARP/RARP pkts
	mov	bl,frame_adlen[di]	; array of MAC lengths for frame types
	xor	bh,bh
	mov	_MAC_len,bx		; save MAC address length (1..6 bytes)
	pop	di
	pop	es
	ret
get_hwd1:mov	_arp_hardware,bx	; hardware type 0 for ARP/RARP pkts
	mov	_MAC_len,bx		; save MAC address length (0 bytes)
	pop	di
	pop	es
	ret				; return _MAC_len in BX
get_hwd	endp

; Unbind a protocol TYPE from an ODI virtual board
; Enter with protocol TYPE (net order) in AX, return carry set if failure.
; The TYPE is used as our handle to the application.
; Prescan and Default methods call lslsupport with the board number in AX 
; rather than StackID and use matching PROTSUP_DEREGISTER_* code.
odiunbind proc	near
	cmp	ax,ip_type		; IP, 0x0008h?
	jne	odiunb1			; ne = no
	mov	ax,ip_stackid.pstack	; StackID
	jmp	short odiunb3

odiunb1:cmp	ax,arp_type		; ARP, 0x0608?
	jne	odiunb2			; ne = no
	mov	ax,arp_stackid.pstack
	jmp	short odiunb3

odiunb2:cmp	ax,rarp_type		; RARP, 0x3580?
	jne	odiunb4			; ne = no
	mov	ax,rarp_stackid.pstack

odiunb3:mov	bx,PROTSUP_DEREGISTER_STACK ; deregister stack (StackID in AX)
	call	lslsupport		; stops reception now
	jnz	odiunb4			; nz = failure
	clc				; success
	ret
odiunb4:stc				; failure
	ret
odiunbind endp

; ODI receive interrupt handler, for use only by the LSL.
; Called with DS:DI pointing to lookahead structure, interrupts are off.
; Returns ES:SI pointing at ECB, AX = 0 if we want pkt, AX = 8001h if decline.
; There are three of these, one each for IP, ARP, and RARP. All have the
; same calling convention and all jump to odircv to do the real work. 
; The length of the arriving packet is available if the MLID supports the
; new (mid-May 1992) capability, our "tells_len"; otherwise we make an
; intelligent guess based on the protocol header. These entry points can be 
; called multiple times before receive-completion, and likely will be, so we
; use several ecb's to accept requests.
ip_rcvr	proc	far
	push	bx
	push	cx
	push	di
	push	ds
	mov	cx,ds			; DS:DI from LSL
	mov	es,cx			; use ES for LSL items
	mov	ax,DGROUP		; set DS to our data segment
	mov	ds,ax
	call	rstart			; start timer
	push	es
	push	si
	cmp	tells_len,0		; have data length available?
	je	ip_rec1			; e = no
	les	si,es:[di].DataLookAheadDataSize ; ptr to what it says
	mov	cx,word ptr es:[si]	; get length of data field
	add	cx,4			; for overzealous board transfers
	pop	si
	pop	es
	jmp	far ptr odircv

ip_rec1:les	si,es:[di].LookAheadPtr	; point at data lookahead ptr
	mov	cx,word ptr es:[si+2]	; IP pkt header, length word
	cmp	byte ptr es:[si],45h	; validate IP pkt kind (ver/hlen)?
	pop	si
	pop	es
	jne	ip_rcvr1		; ne = invalid, decline
	xchg	ch,cl			; net to local order
	add	cx,14+2			; our MAC level addressing + 2 safety
ip_rec2:mov	ax,ip_stackid.pstack	; StackID for ecb structure
	mov	rcvtype,ip_type		; store protocol TYPE int
	jmp	odircv

ip_rcvr1:add	pstats.PIgnoredRxPackets,1 ; update ODI statistics counter
	adc	pstats.PIgnoredRxPackets+2,0
	mov	ax,LSLERR_OUT_OF_RESOURCES ; decline the packet
	or	ax,ax			; set Z flag to match AX
	pop	ds
	pop	di
	pop	cx
	pop	bx
	ret
ip_rcvr	endp

; RARP protocol receive service routine, similar to ip_rcvr.
rarp_rcvr proc	far
	push	bx
	push	cx
	push	di
	push	ds
	mov	cx,ds			; DS:SI from LSL
	mov	es,cx
	mov	ax,DGROUP		; set DS to our data segment
	mov	ds,ax
	mov	ax,rarp_stackid.pstack	; StackID for ecb structure
	mov	rcvtype,rarp_type	; store protocol TYPE int
	jmp	short arp_common	; do ARP/RARP common code
rarp_rcvr endp

; ARP protocol receive service routine, similar to ip_rcvr.
arp_rcvr proc	far
	push	bx
	push	cx
	push	di
	push	ds
	mov	cx,ds			; DS:SI from LSL
	mov	es,cx
	mov	ax,DGROUP		; set DS to our data segment
	mov	ds,ax
	mov	ax,arp_stackid.pstack	; StackID for ecb structure
	mov	rcvtype,arp_type	; store protocol TYPE int

arp_common:				; common code for ARP/RARP
	push	es
	push	si
	cmp	tells_len,0		; have data length available?
	je	arp_com1		; e = no
	les	si,es:[di].DataLookAheadDataSize ; ptr to what it says
	mov	cx,word ptr es:[si]	; get length of data field
	add	cx,4			; for overzealous board transfers
	pop	si
	pop	es
	jmp	short odircv

arp_com1:les	si,es:[di].LookAheadPtr	; point at lookahead ptr for Data
	mov	cx,word ptr es:[si+4]	; ARP/RARP pkt header, length bytes
	add	cl,ch			; add HA and IP address lengths
	xor	ch,ch
	add	cl,cl			; for host and target
	adc	ch,0
	add	cx,8			; plus ARP/RARP main header
	cmp	word ptr es:[si+2],ip_type ; ARP/RARP Protocol type of IP?
	pop	si
	pop	es
	jne	ip_rcvr1		; ne = invalid, decline
	; fall through to odircv
arp_rcvr endp

; General worker for ip_rcvr, arp_rcvr, rarp_rcvr. These are invoked by the
; LSL when their kind of packet arrives. This module creates the ECB and
; dispatches it to the LSL. Operating at LSL interrupt level.
; ES:DI is ptr to ODI Lookahead structure, DS is our data seg (DGROUP).
; AX is stackid for invoked protocol kind, CX is (guessed) pkt length overall.
; Rcvtype is the current invoked protocol TYPE (0008h is IP etc).
; When done store in the ecb's protocolws array:
;	dw	protocol TYPE (0008h for IP etc)
;	dw	subscript of this ecbr item (for use by odircmp)
;	dw	<unused>,<unused>
; Return ES:SI as pointer to a free ecb and AX = 0 to accept pkt, else
; return AX = 8001h to decline pkt (and to ignore ES:SI). Set Z flag to
; match AX value.
odircv	proc	far
	add	pstats.PtotalRxPackets,1 ; update ODI statistics counter
	adc	pstats.PtotalRxPackets+2,0
	push	ax
	push	cx
	mov	cx,ecbr_qty		; number of receive ecb's
	xor	bx,bx			; find a free ecb for this packet
	mov	ax,offset DGROUP:ecbr	; start of receive ecbs
odircv8:cmp	ecbr_busy[bx],0		; is this ECB free?
	jne	odircv9			; ne = no, try next
	mov	ecbr_num,bx		; remember index for end of proc
	mov	bx,ax			; offset of free ecb
	pop	cx
	pop	ax
	jmp	short odircv2		; use ds:[bx] for address of ecb
odircv9:inc	bx			; next byte in busy array
	add	ax,size ecbstruct	; size of an ecb
	loop	odircv8
	pop	cx			; failed to find a free ecbr
	pop	ax

odircv1:add	pstats.PIgnoredRxPackets,1 ; update ODI statistics counter
	adc	pstats.PIgnoredRxPackets+2,0
	mov	ax,LSLERR_OUT_OF_RESOURCES ; decline the packet
	or	ax,ax			; set Z flag for ODI
	pop	ds
	pop	di
	pop	cx
	pop	bx
	ret
					; ds:[bx] is ptr to a free ecbr
odircv2:mov	[bx].stackid,ax		; StackID from odircv entry points
	mov	ax,es:[di].LBoardNum	; boardnum from ProtocolID lookahead
	mov	[bx].boardnum,ax	; store in ecbr
	mov	ax,rcvtype		; get TYPE from odircv entry points
	mov	word ptr [bx].protocolws,ax	; save TYPE for odircmp
	mov	ax,ecbr_num		; ecbr index
	mov	word ptr [bx].protocolws+2,ax	; save index for odircmp
	cmp	cx,46			; min packet for Ethernet + 4 spare
	jae	odircv3			; ae = no padding needed here
	mov	cx,46			; padded min pkt plus 4 spare bytes
odircv3:push	bx			; get a buffer of length CX bytes
	xor	ax,ax			; set AX = 0 for PD "get buf" call
	call	pdrcvr			; use PD buffer allocator code
	pop	bx			; ES:DI = buffer pointer, CX = length
	mov	ax,es
	or	ax,di			; check for refused pkt (es:di = NULL)
	jz	odircv1			; z = pkt refused (no buffer space)
	add	di,6+6+2		; skip our MAC header for ecb use
	sub	cx,6+6+2		; less same length for MLID
	mov	[bx].frag1addr,di	; offset of buffer which MLID sees
	mov	ax,es
	mov	[bx].frag1addr+2,ax	; seg of buffer
	mov	[bx].datalen,cx		; length of buffer for MLID/LSL use
	mov	[bx].frag1len,cx	; ditto
	mov	ax,DGROUP		; segment of our ecb's
	mov	es,ax
	mov	si,bx			; return ES:SI pointing to ECB
	mov	bx,ecbr_num		; get ecbr index
	mov	ecbr_busy[bx],1		; mark this ecbr as busy
	pop	ds
	pop	di
	pop	cx
	pop	bx
	xor	ax,ax			; return AX = 0 to accept
	ret
odircv	endp

; ODI receive-complete call-back routine for use only by the LSL.
; Enter with ES:SI pointing at ECB, interrupts are off.
; Returns nothing.
; There is no guarantee that this routine will be called in the sequence
; which packets arrived, so we carry the bookkeeping in the delivered ECB:
; TYPE is for Ethernet_II struct results, ecbr_busy is don't-touch interlock.
; Note that we have to construct our own "destination" MAC address.
; es:[si].status is 0 (success), 8006h (buffer overrun), 8007h (canceled).
; StackID field is from LSL, and it's 0ffffh if using Prescan, and undefined
; if using Default. The manual says LSL, but not MLID, calls are ok in here.
odircmp	proc	far
	push	ds
	push	ax
	push	bx
	push	cx
	mov	ax,DGROUP
	mov	ds,ax			; set ds to our data segment
	cmp	es:[si].frag1addr+2,0	; segment of pkt being confirmed
	je	odircmp6		; e = illegal, ignore this call
	cmp	es:[si].status,0 	; check ECB status for failure
	je	odircmp1		; e = success
	mov	es:[si].protocolws,0	; write TYPE of 0 to permit queueing
odircmp1:push	di			; put dest,src,TYPE into pkt buffer
	push	es
	push	si			; save ecbr's si
	mov	cl,byte ptr es:[si].driverws ; kind of destination, from LSL
	mov	di,es:[si].frag1addr	; start of our pkt buffer + 6+6+2
	sub	di,6+6+2		; back to start, for our MAC header
	push	ds			; WATCH this, presumes ES == DS!
	pop	es			; set ES to DS (where pkt buffer is)
	mov	si,offset DGROUP:_eth_addr ; our hardware address
	cmp	cl,ECB_BROADCAST 	; a broadcast?
	jne	odircmp2		; ne = no, use our address
	mov	si,offset DGROUP:bcast	; fill with all 1's
odircmp2:mov	cx,3			; 6 byte addresses to our application
	cld
 	rep	movsw			; store source address in pkt buffer
	pop	si			; recover ecb si
	push	si			; save it again
	mov	ax,es:[si].protocolws 	; get TYPE, from odircv
	lea	si,es:[si].immaddr	; offset to MAC address of sender
	mov	cx,3			; three words worth, garbage and all
	rep	movsw			; copy to packet buffer
	stosw				; and write TYPE to packet buffer
	pop	si
	pop	es
	pop	di
	mov	cx,es:[si].datalen	; length of data field from ecb
	add	cx,6+6+2		; plus space for dest,src,TYPE
	push	es			; save ecb's es:si
	push	si
	mov	si,es:[si].frag1addr	; offset of pkt being confirmed
	sub	si,6+6+2		; adj to beginning, for our MAC header
	mov	ax,1			; set AX = 1 for buffer done call
	call	pdrcvr			; do post processing of buffer
	pop	si
	pop	es
	xor	ax,ax
	mov	es:[si].frag1addr+2,ax	; clear pkt buffer pointer (seg)
	mov	es:[si].protocolws,ax 	; clear packet TYPE
	mov	bx,es:[si].protocolws+2	; point to ecb index
	mov	ecbr_busy[bx],al	; say this ecb is free now
odircmp6:
	call	rstop			; stop receive timer
	pop	cx
	pop	bx
	pop	ax
	pop	ds
	ret
odircmp	endp

; ODI transmission routine
; Enter with ds:si pointing at full Ethernet_II packet, cx = length (bytes)
; Once sent the ecb belongs to ODI until the xmt-complete routine is called.
odixmt	proc	near
	push	si
	push	di
	push	es
	mov	ax,ds
	mov	es,ax
	mov	ax,cx			; overall Ethernet_II length
	sub	ax,6+6+2		; omit our MAC header
	jc	odixmt6			; c = failure, abandon
	mov	ecbx.datalen,ax		; setup ECB overall data
	mov	ecbx.frag1len,ax	; and fragment length

	mov	cx,3			; three words of dest MAC address
	mov	di,offset DGROUP:ecbx.immaddr	; destination address in ecb
	rep	movsw			; copy destination MAC address
	add	si,6			; skip source Ethernet address
	lodsw				; get protocol TYPE, move it to AX
	mov	ecbx.frag1addr,si	; offset of packet data
	mov	si,ds
	mov	ecbx.frag1addr+2,si	; segment of packet data

; Note: Prescan and Default methods use Raw Send: put 0ffffh in StackID
; and include the full frame header in the data field. Check MLID 
; configuration word ModeFlags, MRawSendBit, for Raw Send capability.

	cmp	ax,ip_type		; IP, 0x0008h?
	jne	odixmt1			; ne = no
	mov	si,offset DGROUP:ip_stackid
	jmp	short odixmt3

odixmt1:cmp	ax,arp_type		; ARP, 0x0608?
	jne	odixmt2			; ne = no
	mov	si,offset DGROUP:arp_stackid
	jmp	short odixmt3

odixmt2:cmp	ax,rarp_type		; RARP, 0x3580?
	jne	odixmt6			; ne = error, do not send
	mov	si,offset DGROUP:rarp_stackid

odixmt3:mov	cx,5			; stackid, protid, boardnum
	mov	di,offset DGROUP:ecbx.stackid	; get stack ident area
	rep	movsw			; copy to ecbx

	mov	ecbx_busy,1		; set ECBx busy flag to busy state
	add	pstats.PtotalTxPackets,1 ; update ODI statistics counter
	adc	pstats.PtotalTxPackets+2,0

	mov	si,offset DGROUP:ecbx	; set es:si to ECB
	mov	bx,PROTSUP_SEND_PACKET	; send it
	call	tstart			; start transmit timer
	call	lslsupport		; call LSL with ecbx ptr in es:si
	call	tstop			; stop transmit timer
	clc				; success so far, ints are still off
odixmt6:pop	es
	pop	di
	pop	si
	ret
odixmt	endp

; ODI transmission-complete processor, for use only by the LSL.
; Returns nothing. Unlocks ECB busy flag.
odixcmp	proc	far
	push	ds
	push	ax
	mov	ax,DGROUP		; set addressibility
	mov	ds,ax
	mov	ecbx_busy,0		; set ECB busy flag to not-busy
	pop	ax
	pop	ds
	ret
odixcmp	endp

; ODI Protocol (that's us) Control routine, required, called from outside.
; In principle we should have one of these for each protocol (IP, ARP, RARP)
; by putting a different StackControlHandler address in registerstk, but I 
; doubt that anyone is that interested in such detailed counts.
; Return AX clear, Z flag set, and ES:SI as table pointer if success, else
; return AX with error code and Z flag clear.
pcontrol proc	far
	cmp	bx,GET_STACK_CONFIGURATION ; get stack configuration?
	jne	pcont1			; ne = no
	mov	si,DGROUP
	mov	es,si			; es:si points to configuration table
	mov	si,offset DGROUP:pconfig; the table
	xor	ax,ax			; set Z flag
	ret
pcont1:	cmp	bx,GET_STACK_STATISTICS	; get stack statistics?
	jne	pcont2			; ne = no
	mov	si,DGROUP
	mov	es,si			; es:si points to statistics table
	mov	si,offset DGROUP:pstats	; the table
	xor	ax,ax			; set Z flag
	ret
pcont2:	mov	ax,LSLERR_OUT_OF_RESOURCES ; other functions, report error
	or	ax,ax			; clear Z flag
	ret
pcontrol endp

; timer support routines
rstart	proc	near
	pushf
	test	_kdebug,2		; DEBUG_TIMING?
	jz	rstart1
	push	ax
	in	al,40h		; 8254 timer channel T0, read LSB
	xchg	ah,al
	in	al,40h		; read MSB
	xchg	al,ah		; order properly
	mov	startrtic,ax
	pop	ax
rstart1:popf
	ret
rstart	endp

rstop	proc	near
	pushf
	test	_kdebug,2		; DEBUG_TIMING?
	jz	rstop1
	push	ax
	in	al,40h		; 8254 timer channel T0, read LSB
	xchg	ah,al
	in	al,40h		; read MSB
	xchg	al,ah		; order properly
	mov	stoprtic,ax
	pop	ax
rstop1:	popf
	ret
rstop	endp

tstart	proc	near
	pushf
	test	_kdebug,2		; DEBUG_TIMING?
	jz	tstart1
	push	ax
	in	al,40h		; 8254 timer channel T0, read LSB
	xchg	ah,al
	in	al,40h		; read MSB
	xchg	al,ah		; order properly
	mov	startttic,ax
	pop	ax
tstart1:popf
	ret
tstart	endp

tstop	proc	near
	pushf
	test	_kdebug,2		; DEBUG_TIMING?
	jz	tstop1
	push 	ax
	in	al,40h		; 8254 timer channel T0, read LSB
	xchg	ah,al
	in	al,40h		; read MSB
	xchg	al,ah		; order properly
	sti			; for odixmt
	mov	stopttic,ax
	call	showtime	; display timing results (microseconds)
	pop	ax
tstop1:	popf
	ret
tstop	endp

showtime proc	near
	push	es
	push	di
	push	bx
	mov	bx,data
	mov	es,bx
	mov	al,es:crt_cols			; screen columns
	mul	es:crt_lins			; screen lines
	mov	bx,ax
	add	bx,40				; column 40
	shl	bx,1
	mov	di,es:tv_sego			; current screen offset
	add	bx,di
	mov	di,es:tv_segs			; current screen segment
	mov	es,di
	mov	ax,startrtic
	sub	ax,stoprtic
	jns	showti1
	neg	ax
showti1:sub	ax,overhead
	mov	di,bx
	call	decout
	mov	byte ptr es:[di],'R'

	mov	ax,startttic
	sub	ax,stopttic
	jns	showti2
	neg	ax
showti2:sub	ax,overhead
	mov	di,bx
	add	di,5*2
	call	decout
	mov	byte ptr es:[di],'T'
	pop	bx
	pop	di
	pop	es
	ret
showtime endp

decout	proc	near		; display decimal number in ax
	push	cx
	push	dx
	mov	byte ptr es:[di],' '	; clear screen of old info
	mov	byte ptr es:[di+2],' '
	mov	byte ptr es:[di+4],' '
	mov	byte ptr es:[di+6],' '
	mov	byte ptr es:[di+8],' '
	test	ax,8000h		; negative?
	jz	decout1			; z = no
	neg	ax
	mov	byte ptr es:[di],'-'	; minus sign
	inc	di
	inc	di
decout1:mov	cl,t0count		; timer chip T0 count factor
	mov	dx,2000
	shr	dx,cl		; t0count compensation (by 1 or 2 shifts)
	mul	dx
	mov	cx,1193
	div	cx
	mov	cx,10			; set the numeric base
	call	mvalout			; convert and output value
	pop	dx
	pop	cx
	ret
decout	endp

mvalout	proc	near		; output number in ax using base in cx
				; corrupts ax and dx
	xor	dx,dx		; clear high word of numerator
	div	cx		; (ax / cx), remainder = dx, quotient = ax
	push	dx		; save remainder for outputting later
	or	ax,ax		; any quotient left?
	jz	mvalout1	; z = no
	call	mvalout		; yes, recurse
mvalout1:pop	dx		; get remainder
	add	dl,'0'		; make digit printable
	cmp	dl,'9'		; above 9?
	jbe	mvalout2	; be = no
	add	dl,'A'-1-'9'	; use 'A'--'F' for values above 9
mvalout2:mov	es:[di],dl
	inc	di
	inc	di
	ret
mvalout	endp
_TEXT	ends
        end

