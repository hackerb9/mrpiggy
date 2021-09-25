<img src="README.md.d/mrpiggy.jpg" width="33%" align="right">

# MR Piggy

An experimental fork of 
[MS Kermit](https://github.com/hackerb9/mskermit). Cross compiles for
MS-DOS on modern GNU/Linux systems using no proprietary software.
Executable is 16-bit (8086). Runs on original IBM PC hardware or in an
emulator such as [dosbox](https://dosbox.com).

# Compilation

If you have jwasm and owcc installed (see below), then you can compile
a 16-bit DOS executable of KERMIT.EXE by simply running 'make'. 

## Prerequisites

To compile, requires the [jwasm](https://github.com/tuxxi/masm-unix)
assembler and
[Open Watcom](https://github.com/open-watcom/open-watcom-v2/)
C compiler (owcc). 

### Jwasm

I used tuxxi's [masm-unix](https://github.com/tuxxi/masm-unix) which
made compiling jwasm on GNU/Linux straight forward. 

<details><summary>Cut and paste this into a command line to compile
and install jwasm:</summary>

```bash
    sudo apt install build-essential cmake
    git clone http://github.com/tuxxi/masm-unix
    cd masm_unix/src/JWasm
    cmake .  &&  make  &&  sudo cp -p jwasm /usr/local/bin/
```
</details>

### Open Watcom C Compiler

#### Install
The Open Watcom v2 source code is overly large to download and git
times out, so I had to install a prebuilt copy. 

<details>
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
Microsoft EDIT and `ed` plus it's a bit buggy (try Ctrl+C), thus
"weevil". 
</details>

</details>

#### Setup
<details>

To use the Watcom C compiler, you'll need to setup the compilation
environment like so:

``` bash
export WATCOM=${HOME}/ow2
export PATH+=${WATCOM}/bin
export INCLUDE=${WATCOM}/h
```

You can run that at the command line or add it to the Makefile. 
</details>

#### Usage
<details>

``` bash
owcc  -bdos  -mcmodel=s  -o myprog.exe  myprog.c
```

You can then execute the .exe file in dosbox to test it out.

</details>

## Todo

- [x] Get it to compile under GNU/Linux

- [ ] Trim it down to run on retro PCs
