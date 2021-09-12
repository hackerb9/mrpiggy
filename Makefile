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
# The inference macros below call CL and MASM to create .obj modules.

.c.obj:
 	cl /AS /Zp1 /Gs /W3 /Zl /Of /nologo -c $*.c

.asm.obj:
 	masm /mx $*.asm;

# kermit.exe is the first and hence the implied target if none is specified

kermit.exe:	msscmd.obj msscom.obj mssfil.obj mssker.obj mssrcv.obj\
		mssscp.obj msssen.obj mssser.obj mssset.obj msssho.obj\
		msster.obj msuibm.obj msgibm.obj msxibm.obj msyibm.obj\
		mszibm.obj msntni.obj msnpdi.obj msntnd.obj msntcp.obj\
 		msnsed.obj msndns.obj msnarp.obj msnbtp.obj msnicm.obj\
		msnpkt.obj msnlib.obj msnut1.obj
	LINK @ker.lnk

# These are the dependency relations (.obj depends on .asm/.c and .h):

msscmd.obj:	msscmd.asm mssdef.h

msscom.obj:	msscom.asm mssdef.h

mssfil.obj:	mssfil.asm mssdef.h

mssker.obj:	mssker.asm mssdef.h

mssrcv.obj:	mssrcv.asm mssdef.h

mssscp.obj:	mssscp.asm mssdef.h

msssen.obj:	msssen.asm mssdef.h

mssser.obj:	mssser.asm mssdef.h

mssset.obj:	mssset.asm mssdef.h

msssho.obj:	msssho.asm mssdef.h

msster.obj:	msster.asm mssdef.h

msuibm.obj:	msuibm.asm mssdef.h

msgibm.obj:	msgibm.asm mssdef.h

msxibm.obj:	msxibm.asm mssdef.h

msyibm.obj:	msyibm.asm mssdef.h

mszibm.obj:	mszibm.asm mssdef.h

# Files below are for TCP/IP support

msntni.obj:	msntni.asm mssdef.h

msnpdi.obj:	msnpdi.asm

msnut1.obj:	msnut1.asm

msntnd.obj:	msntnd.c msntcp.h msnlib.h

msntcp.obj:	msntcp.c msntcp.h msnlib.h

msnsed.obj:	msnsed.c msntcp.h msnlib.h

msndns.obj:	msndns.c msntcp.h msnlib.h

msnarp.obj:	msnarp.c msntcp.h msnlib.h

msnbtp.obj:	msnbtp.c msntcp.h msnlib.h

msnicm.obj:	msnicm.c msntcp.h msnlib.h

msnpkt.obj:	msnpkt.c msntcp.h msnlib.h

msnlib.obj:	msnlib.c msnlib.h

# Do the items above when Kermit.exe is rebuilt. Notice the use of a command
# file for Link because the list of object files is too long for one line.
# A sample command file ker.lnk is:
# msscmd+msscom+mssfil+mssker+mssrcv+mssscp+msssen+mssser+
# mssset+msssho+msster+msgibm+msuibm+msxibm+msyibm+mszibm+
# msntni+msnpdi+msntnd+msntcp+msnsed+msndns+msnarp+msnbtp+
# msnicm+msnpkt+msnlib+msnut1
# Kermit/nodefaultlib;
#
# End of Kermit Make file.
