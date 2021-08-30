# mskermit
<img src="README.md.d/localremote.jpg" align="right" width="25%" alt="Greg Ulrich's diagram of Kermit connecting to a remote host from the Kermit Book (circa 1987)">

MS Kermit: the famous MS-DOS terminal emulator &amp; file transfer program of the 1980s and 1990s.

## Original source

This repository is for the unmodified source code of the MS-DOS
version from the Kermit project. It is not expected to ever change.
The intention is that this can be a forking off point for
retro-computing enthusiasts who woud like to get the code compiling
again and update it.

## Sidenote about versions

The repository is based on [http://www.columbia.edu/kermit/ftp/archives/msk316src.zip](http://www.columbia.edu/kermit/ftp/archives/msk316src.zip), which describes the source code like so:

> MS-DOS Kermit runs on the IBM PC and compatibles with MS-DOS, PC-DOS, or DR-DOS, or under Microsoft Windows 3.11 or earlier. Separate versions were created for the following non-IBM compatible PCs: ACT Apricot, DEC Rainbow, DECmate-II and -III, GRiD Compass II, Heath/Zenith-100, HP Portable Plus, HP-110, HP-150, Intel 300 Series with iRMX-86 or iRMX-286, Macintosh with AST286 board, NEC APC, NEC APC III, NEC PC9801, Olivetti M24 PC, Sanyo 550 MBC, Seequa Chameleon, TI Professional, Victor/Sirius 1, and the Wang PC/APC. 

[kermitproject.org](https://kermitproject.org/archive.html#mskermit)'s
archives offer both
[.tar](http://www.columbia.edu/kermit/ftp/archives/mskermit.tar.gz) and
[.zip](http://www.columbia.edu/kermit/ftp/archives/msk316src.zip)
versions of this source code. Unfortunately, they are very different.
The tar has a lot of extra files, but seems to be for Kermit 3.14. The
zip contains the Kermit 3.16 source code but nothing else.

netlab1.net has confusing source code for Kermit, it offers several
versions:

* netlab's 3.16 beta 10: Files are same as kermitproject.org's 3.16 (1999)
* netlab's "3.16"      : Files are same as 3.15 (1997) except MSSDEF.H
* netlab's SOURCE      : same as above (3.15 except MSSDEF.H)
