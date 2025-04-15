# MR Piggy

<img src="README.md.d/mrpiggy.jpg" width="33%" align="right">

An experimental fork of [MS Kermit][msk] with the build system ported
to GNU make, jwasm, and Open Watcom C so that no proprietary software
is needed to compile. The resulting [executable][exe] is 16-bit (8086)
and can run on original IBM PC hardware or in an emulator such as
[dosbox](https://dosbox.com).

  [msk]: https://github.com/hackerb9/mskermit "MS Kermit source code"
  [exe]: https://github.com/hackerb9/mrpiggy/releases/download/v0.0.2/kermit.exe "kermit.exe"

<br clear=all>

# Compilation

If you have jwasm and owcc installed (see below), then you can create
a DOS executable of [kermit.exe][exe] by simply running 'make' on your
GNU/Linux box.

## Prerequisites

Compilation requires the [jwasm](https://github.com/tuxxi/masm-unix)
assembler and
[Open Watcom](https://github.com/open-watcom/open-watcom-v2/)
C compiler (owcc). GNU Make syntax is used in the Makefile.
[UPX](https://github.com/upx/upx) is used to compress kermit.exe
from 300KB to 150KB.

### Jwasm

I used tuxxi's [masm-unix](https://github.com/tuxxi/masm-unix) which
made compiling jwasm on GNU/Linux straight forward. 

<ul><details><summary>Cut and paste this into a command line to compile
and install jwasm:</summary>

```bash
    sudo apt install build-essential cmake
    git clone http://github.com/tuxxi/masm-unix
    cd masm_unix/src/JWasm
    cmake .  &&  make  &&  sudo cp -p jwasm /usr/local/bin/
```
</details></ul>

### Open Watcom C Compiler

#### Watcom Install
The Open Watcom v2 source code is overly large to download and git
times out, so I had to install a prebuilt copy. 

<ul><details>
<summary>Cut and paste these commands to install the Open Watcom v2 C compiler:</summary>

``` bash
cd
mkdir ow2
cd ow2
R=https://github.com/open-watcom/open-watcom-v2/releases
wget -O ow2.zip "$R"/download/Current-build/open-watcom-2_0-c-linux-x64
unzip ow2.zip
rm -r ow2.zip binnt binp binw rdos rh 
mv binl64 bin
cd bin
chmod +x $(file * | grep ELF | cut -f1 -d:)
mv vi weevil
```

<details><summary>32-bit binaries</summary>

Binaries are in `binl` instead of `binl64`; rename it to just `bin`.
If you don't have a binl directory, try changing `x64` to `x86` in the
wget line. 

``` bash
cd
mkdir ow2
cd ow2
R=https://github.com/open-watcom/open-watcom-v2/releases
wget -O ow2.zip "$R"/download/Current-build/open-watcom-2_0-c-linux-x86
unzip ow2.zip
rm -r ow2.zip binnt binp binw rdos rh 
mv binl bin
cd bin
chmod +x $(file * | grep ELF | cut -f1 -d:)
mv vi weevil
```
</details>

<details><summary>About weevil</summary>

Note that we've renamed the Watcom editor to `weevil` because calling
it `vi` on a UNIX system is silly. It is clearly the love-child of
Microsoft EDIT and [`ed`][ed] plus it's a bit buggy (try Ctrl+C), thus
"weevil". 
</details>

  [ed]: https://www.gnu.org/fun/jokes/ed-msg.en.html "“Ed is the standard text editor.”"

</details></ul>

#### Watcom Compiler Setup and Usage

The [Makefile](Makefile) already sets up everything needed for
compilation, presuming Watcom is installed in $HOME/ow2. To compile
just run:

```bash
make
```

However, if you want to use Watcom by hand, read on.

<ul><details>

To use the Watcom C compiler, you'll first need to setup the compilation
environment like so:

``` bash
export WATCOM=${HOME}/ow2
export PATH+=:${WATCOM}/bin
export INCLUDE=${WATCOM}/h
```

You can run that at the command line or add it to a Makefile. To
compile a program, you use the owcc command, like so:


``` bash
owcc  -bdos  -mcmodel=s  -o myprog.exe  myprog.c
```

You can then execute the .exe file in dosbox to test it out.

</details></ul>

### UPX

[UPX](https://github.com/upx/upx) can be installed with `apt install
upx-ucl`, for Debian GNU/Linux.

Uncompressed, the file `kermit.exe` takes up 300 KB, which leaves no
room for documentation or DOS on a 360 KB floppy disk. So, by default
the Makefile uses `upx` to compress the executable down to 150 KB. On
an IBM PC (8088 4.77MHz) compression adds a twelve second pause before
running and saves six seconds of floppy disk access. Of course, the
pause will be shorter for faster CPUs.

Or, if you have a large, fast drive, use the uncompressed executable,
`kermit-uncompressed.exe`.

## Todo

- [x] Get it to compile under GNU/Linux
- [x] Test the .EXE on an IBM PC
- [x] Reduce file size so it is more useful on retro-PCs (currently it
      is 322 KiB 
	- [X] Look into runtime DOS executable compressors. Do any exist
          that are Free Software?
	  - Surprisingly, Yes!
	  - Running `upx` on KERMIT.EXE cuts the size in half to 152 KB.
 	  - Noticeably slower start up time in emulation with DOSBOX.
	 - [X] Measure compressed start time on actual PC hardware. It
           might be faster than uncompressed due to floppy access.
		   (Nope! Saved six seconds of I/O and added twelve of CPU.)
 - [ ] Bundle with FreeDOS as a bootable 360KB disk image.
 - [ ] Maybe include the numerous miscellaneous supplementary files
       that came with the MS Kermit 3.14 distribution.
 - [ ] Configure Makefile to automatically add builddate to `symboldefs.h`.
 - [ ] Is there any benefit to using mTCP's network code instead of Kermit's?
 - [ ] Look into ways to reduce filesize that do not impact start up time
   <details>
  
	- Simple Methods
	  - [ ] Compiler, linker flags.
	  - [ ] Investigate: why is Open Watcom executable 50 KB larger than
            the one created by Microsoft tools in 1999. Is it Watcom's
            standard library?
	  - [ ] Check how Open Watcom's PACKDATA works.
		- Kermit 3.14 notes state that 40KB was saved by using
			PACKDATA option of LINK.EXE. That option exists in Open
			Watcom but produces no savings in file size.
   		- **WARNING!** I had thought PACKDATA was safe to experiment
			with, but I realized that since stack checking is
			disabled, a smaller segment size might cause pointers to
			wrap around!
	    - [ ] What is the max size of the data structures in Kermit?
   	- Complex Methods
	  - [ ] Conditional compilation
		- [ ] Add "Lite" versions (no NET, no GRAPHICS, neither) to Makefile.
		- [X] What existing subsystems does CHECK command identify?
			- IF: ???
			- Network: How does this differ from TCP?
			- TCP/IP: 
			- Graphics: Tek4010 & Sixel
			- Terminal: Terminal emulation. no_terminal implies no_graphics.
			- (nls_portuguese: Missing from check but exists as ifdef.)
		- [ ] Identify other large subsystems
			- [ ] serial port? script interpreter? H19 and other terms?
			- [ ] weird networks like IPX
		- [ ] Wrap them in #ifdef, same as Lite.
	  - [ ] Analyze algorithms and datastructures to trim for size.
	  - [ ] How large is Kermit's TCP/IP, DHCP, and DNS implementation? 
			Is [mTCP](http://www.brutman.com/mTCP/) smaller?
   </details>
