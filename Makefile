# Makefile
# Written by Joe R. Doupnik, 1991
# Rejigged for GNU Make, jwasm, and Open Watcom by hackerb9, Sept 2021

# Usage:   make		
# 	  (compiles and compresses kermit.exe)

# Define subsystems to remove
#LITESUBSYSTEMS+=-Dno_graphics
#LITESUBSYSTEMS+=-Dno_terminal
#LITESUBSYSTEMS+=-Dno_tcp
#LITESUBSYSTEMS+=-Dno_network

### Set up compilation environment for Open Watcom compiler.
# Set the WATCOM environment variable if you wish to override these defaults.
export WATCOM ?= ${HOME}/ow2
export PATH += :${WATCOM}/bin
export INCLUDE ?= ${WATCOM}/h

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
# Define MSDOS so netlibc.c will use _ourdiv()
OWCCARGS+=-DMSDOS
# Remove debugging code to save about 20KB in .exe.
OWCCARGS+=-g0 -s
# Optimize (-O3 adds 2KB, -Os has no effect on size)
OWCCARGS+=-O3
# Allow optimizer to take multiple passes. (Has no effect on size)
OWCCARGS+=-frerun-optimizer
# MS Kermit 3.14 saved about 40K by using Microsoft's "PACKDATA".
# It doesn't seem to help with OWCC. 
# Note that changing these values makes the segment size smaller which
# is not necessarily safe! Pointers on large data structures can wrap around.
#OWCCARGS+=-Wl,'OPTION PACKCODE=16K'
#OWCCARGS+=-Wl,'OPTION PACKDATA=16K'

# Default to using owcc to compile C files
%.o : %.c
	owcc ${OWCCARGS} ${LITESUBSYSTEMS} -c $*.c


### JWASM args
# -Cx  Casemap=none. Preserve case of externals, required.
# -Zm  Use MASM v5.1 syntax. Don't need to qualify fields with structure names.
# -Zp1 pack structures on one byte boundaries (needed?)
# -q   Quiet: don't show statistics after assembling
# -e1000  show up to 1000 errors
%.o : %.asm
	jwasm -Cx -Zm -Zp1 -q -e1000 ${LITESUBSYSTEMS} $<


objects = commandparser.o communication.o filehandling.o main.o		\
	receive.o script.o send.o server.o setcommand.o showcommand.o	\
	terminalemulation.o ibmkeyboard.o graphics.o ibmspecificx.o	\
	ibmspecificy.o ibmspecificz.o telnetinterface.o pdi.o		\
	telnetdriver.o tcp.o ethsupport.o dns.o arp.o bootp.o icmp.o	\
	packetdriver.o netlibc.o netutil.o

### kermit.exe is the first and hence the implied target if none is specified.
# Compress kermit-uncompressed.exe file (from 300 KB to 152 KB).
kermit.exe:	kermit-uncompressed.exe
	upx -qq --8086 -o kermit.exe kermit-uncompressed.exe

# OWCC serves as a nicer frontend to WLINK's wacky directives file.
# Use -fd=directives.lnk if you wish to see the .LNK file owcc creates.
kermit-uncompressed.exe:	$(objects)
	owcc ${OWCCARGS} -o kermit-uncompressed.exe $^


### These are the dependency relations (.o depends on .asm/.c and .h):

commandparser.o communication.o filehandling.o main.o receive.o script.o send.o server.o setcommand.o showcommand.o terminalemulation.o ibmkeyboard.o graphics.o ibmspecificx.o ibmspecificy.o ibmspecificz.o :	symboldefs.h


# Files below are for TCP/IP support
telnetinterface.o:	symboldefs.h

telnetdriver.o tcp.o ethsupport.o dns.o arp.o bootp.o icmp.o packetdriver.o netlibc.o:	netlibc.h


### Helpful imaginary targets

.PHONY : clean
clean :
	rm kerm*.exe $(objects) *.err 2>/dev/null || true



# End of Kermit Makefile.
