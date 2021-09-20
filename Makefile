# Makefile: Beginning to port this to GNU Make. Sept 2021

# File	MSVIBM.MAK						2 Feb 1991

# Make file for MS Kermit using Microsoft's Make v4 and later and NMK.
# Written by Joe R. Doupnik
#
# MASM v6 or above and Microsoft C v6 or v7 are required.
# If using MASM v6 execute this command file as
#	NMK /f <name of this file> kermit.exe
# or rename this file to be "makefile" and say  
#	NMK kermit.exe.
# The final argument, kermit.exe, tells NMK which item to make.
# NMK is smaller than NMAKE; MASM.EXE (v6) provides v5 compatibility.
#
# MASM v6 switch /mx means preserve case of externals, required.
# MASM v6 switch /Zm means use MASM v5.1 & earlier syntax. This switch is
# implied by running v6 of MASM.EXE rather than running ML directly.
# MSC CL switches:
#    /AS for small memory model (64KB code, everything else in 64KB DGROUP)
#    /Zp1 for pack structures on one byte boundaries.
#    /Gs to eliminate stack checking (optional, saves a little space & time).
# and the two switches below for MSC v7
#    /Zl to say no default library
#    /Of for p-code quoting (supposed to be the default, but is broken)
#    /nologo stops displaying MSC copyright notice on every compile
# The inference macros below call CL and MASM to create .o modules.

# Set up compilation environment for Open Watcom compiler
export WATCOM="${HOME}/open-watcom-2"
export PATH+="${WATCOM}/binl"
export INCLUDE="${WATCOM}/h"

%.o : %.c
	owcc -bdos -mcmodel=s -c $*.c
#	 /AS /Zp1 /Gs /W3 /Zl /Of /nologo -c $*.c


# -Zm MASM v5.1 SYNTAX (don't need to qualify fields with structure names) 
# -ms ? Small memory model?
# -Zp1 for pack structures on one byte boundaries
# -Cu means Casemap=all, (-Cp means Casemap=none )
# -nologo stops displaying JWASM copyright notice on every compile
# -e1000 show up to 1000 errors
# -W3
%.o : %.asm
	jwasm -Zm -ms -Zp1 -Cu -nologo -W3 -e1000 $< 


# kermit.exe is the first and hence the implied target if none is specified

objects = commandparser.o communication.o filehandling.o main.o		\
	receive.o script.o send.o server.o setcommand.o showcommand.o	\
	terminalemulation.o ibmkeyboard.o graphics.o ibmspecificx.o	\
	ibmspecificy.o ibmspecificz.o telnetinterface.o pdi.o		\
	telnetdriver.o tcp.o ethsupport.o dns.o arp.o bootp.o icmp.o	\
	packetdriver.o netlibc.o netutil.o


kermit.exe:	$(objects)
	bcc -L -o $@ $^

# These are the dependency relations (.o depends on .asm/.c and .h):

commandparser.o communication.o filehandling.o main.o receive.o script.o send.o server.o setcommand.o showcommand.o terminalemulation.o ibmkeyboard.o graphics.o ibmspecificx.o ibmspecificy.o ibmspecificz.o :	symboldefs.h


# Files below are for TCP/IP support


telnetinterface.o:	symboldefs.h


telnetdriver.o tcp.o ethsupport.o dns.o arp.o bootp.o icmp.o packetdriver.o netlibc.o:	netlibc.h



.PHONY : clean
clean :
	rm kermit.exe $(objects) 2>/dev/null || true



# End of Kermit Make file.
