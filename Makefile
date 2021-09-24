# Makefile
# Written by Joe R. Doupnik, 1991
# Rejigged for GNU Make, jwasm, and Open Watcom by hackerb9, Sept 2021

######################################################################
# OBSOLETE
# File	MSVIBM.MAK						2 Feb 1991
# Make file for MS Kermit using Microsoft's Make v4 and later and NMK.
# Written by Joe R. Doupnik
# MASM v6 or above and Microsoft C v6 or v7 are required.
# If using MASM v6 execute this command file as
#	NMK /f <name of this file> kermit.exe
# or rename this file to be "makefile" and say
#	NMK kermit.exe.
# The final argument, kermit.exe, tells NMK which item to make.
# NMK is smaller than NMAKE; MASM.EXE (v6) provides v5 compatibility.
######################################################################

######################################################################
# OBSOLETE
# MSC CL switches:
#    /AS for small memory model (64KB code, everything else in 64KB DGROUP)
#    /Zp1 for pack structures on one byte boundaries.
#    /Gs to eliminate stack checking (optional, saves a little space & time).
# and the two switches below for MSC v7
#    /Zl to say no default library
#    /Of for p-code quoting (supposed to be the default, but is broken)
#    /nologo stops displaying MSC copyright notice on every compile
######################################################################
# OBSOLETE
# MASM v6 switch /mx means preserve case of externals, required.
# MASM v6 switch /Zm means use MASM v5.1 & earlier syntax. This switch is
# implied by running v6 of MASM.EXE rather than running ML directly.
######################################################################
# OBSOLETE
# The inference macros below call CL and MASM to create .o modules.
# .c.obj:
#  	cl /AS /Zp1 /Gs /W3 /Zl /Of /nologo -c $*.c
# .asm.obj:
#  	masm /mx $*.asm;
######################################################################


### Set up compilation environment for Open Watcom compiler
export WATCOM=${HOME}/open-watcom-2
export PATH+=:${WATCOM}/binl
export INCLUDE=${WATCOM}/h


### Testing: Maybe wcc compiler works better? Nope, no better than owcc.
# -q		Quiet: Don't show logo at startup
# -bt=DOS	Compile a DOS .exe file
# -bc		Application type "console"
# -0		16-bit 8086
# -ms		small memory model: 64K code, 64K data group
# -zp=1		pack structure members with alignment=1 byte
# -s		remove stack overflow checks; optional
# -ze		enable NEAR, FAR, EXPORT, etc
# -zl		remove default library information
# -ecc		Set calling convention to C (_underscore)
# -DMSDOS	define MSDOS so netlibc.c will use _ourdiv()
#
#%.o : %.c
#	wcc -q -bt=DOS -bc -0 -ms -zp=1 -s -ze -zl -ecc -DMSDOS $*.c


### Build up command line for owcc compiler
# Compile and link for a DOS .exe file
OWCCARGS+=-bdos
# 16-bit 8086
OWCCARGS+=-march=i86
# small memory model: 64K code, 64K data group		== /AS
OWCCARGS+=-mcmodel=s
# pack structures on one byte boundaries		== /Zp=1
OWCCARGS+=-fpack-struct=1
# no stack checking; optional optimization		== /Gs
OWCCARGS+=-fno-stack-check
# no default library					== /Zl
OWCCARGS+=-fnostdlib
# Set calling convention to C (_underscore)
OWCCARGS+=-mabi=cdecl
# define MSDOS so netlibc.c will use _ourdiv()
OWCCARGS+=-DMSDOS

%.o : %.c
	owcc ${OWCCARGS} -c $*.c


# Obsolete assembly method:	 masm /mx /Zm $*.asm;

### JWASM args
# -Cx  Casemap=none. Preserve case of externals, required.
# -Zm  Use MASM v5.1 syntax. Don't need to qualify fields with structure names.
# -ms  Small memory model
# -Zp1 pack structures on one byte boundaries
# -q   Quiet: don't show statistics after assembling
# -e1000  show up to 1000 errors
%.o : %.asm
	jwasm -Cx -Zm -ms -Zp1 -q -e1000 $<


objects = commandparser.o communication.o filehandling.o main.o		\
	receive.o script.o send.o server.o setcommand.o showcommand.o	\
	terminalemulation.o ibmkeyboard.o graphics.o ibmspecificx.o	\
	ibmspecificy.o ibmspecificz.o telnetinterface.o pdi.o		\
	telnetdriver.o tcp.o ethsupport.o dns.o arp.o bootp.o icmp.o	\
	packetdriver.o netlibc.o netutil.o

### kermit.exe is the first and hence the implied target if none is specified.
# OWCC serves as a nicer frontend to WLINK's wacky directives file.
# Use -fd=directives.lnk if you wish to see the .LNK file owcc creates.
kermit.exe:	$(objects)
	owcc -bdos -o kermit.exe $^


### OBSOLETE
# Here's how to link with wlink if we decide to go back to that.
#kermit.exe:	$(objects)
#	wlink  Option quiet  Name kermit.exe  System DOS  File { $^ }


### These are the dependency relations (.o depends on .asm/.c and .h):

commandparser.o communication.o filehandling.o main.o receive.o script.o send.o server.o setcommand.o showcommand.o terminalemulation.o ibmkeyboard.o graphics.o ibmspecificx.o ibmspecificy.o ibmspecificz.o :	symboldefs.h


# Files below are for TCP/IP support
telnetinterface.o:	symboldefs.h

telnetdriver.o tcp.o ethsupport.o dns.o arp.o bootp.o icmp.o packetdriver.o netlibc.o:	netlibc.h


### Helpful imaginary targets

.PHONY : clean
clean :
	rm kermit.exe $(objects) *.err 2>/dev/null || true



# End of Kermit Make file.
