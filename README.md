## RAMTOS / SELTOS

### Introduction

RAMTOS and SELTOS are written by Pera Putnik and available as free and open source software. 
Please refer to this [page](https://atari.8bitchip.info/astopensw.php) for more information.

This branch is adding:
- Support for TOS 2.06 French
- Support for TOS 1.04 French, Dutch, Spanish and Swedish
- Support for TOS 1.00 French
- Single cleaned source code file for `RAMTOS`, `RAMTOSB` and `SELTOS` (using devpac defines)
- Removed CRC check for all supported TOS 2.06
- Python tool to identify potential non-reloc addresses and to match existing non-reloc addresses with other TOS versions.
- `MEMTOP` and `THEMD` patches
- `.ST` and `.MSA` floppy image generation to load TOS from floppy at boot

### Prerequisites

- Get `vasm` and copy `vasmm68k_mot` in `tools/`
- Get and copy `TOS206FR.IMG` in `TOS/`
- Copy `TOS206FR.IMG` as `RTOS.IMG` in the root directory for `RAMTOS8B`
- Install Python 3.12+ with `capstone` pip library to generate TOS non-reloc address candidates [Optional]

### Tools usage

1. non-reloc matcher

````bash
python tools/match_patchs.py --tos-version 1.04 --source-country de --target-country fr > map_fr_104.txt
````

2. non-reloc identifier

````bash
python tools/disa.py --tos-version 2.06 --country fr
````

3. Assembling RAMTOS / SELTOS

````bash
./build.sh
````

### Important note

RAMTOS / SELTOS is not as compatible as ROM-based TOS (in addtion to existing TOS versions incompatibilities) so don't expect most existing software to work as is.
Examples of applications which DON'T work:
- ACSI2STM Gemdrive driver
- Pera Putnik's Image Runner

### How does it work ?

From original README:

> Purpose of this program is making possible work with diverse versions of TOS without changing (EP)ROM's in machine. 1 MB of RAM is minimum requirement for use, because used TOS is placed in RAM, and it decreases available RAM for 192-256KB.
>
> Program supports following TOS versions:
> - TOS 1.00 US, UK and German
> - TOS 1.04 US, UK and German
> - TOS 2.06 US, UK , German, Swedish  and UK 'Supertos' .
>
> Instructions for SELTOS
>
> Program may be used in 3 ways:
> - 1: Drag and drop - just drag ROM image file on SELTOS.PRG. Program will outprint TOS version, and install it. This works only with TOS 2.06.
> - 2: If install from older TOS version, user may rename program to SELTOS.TTP, and after start enter desired ROM image name. If image has extension IMG, it is not necessary to type in extension.
> - 3: Select TOS from list - ROM images must be placed in same directory with program, and must have extension IMG . Name is irrelevant. After program start, it scans all files with IMG extension, and looks for supported versions.
> If it is found, program outprints version on screen, with number for further selection.
> Max. 9 files of supported TOS versions can be handled. After it, user should select which version want install with keys 1-9. Then program loads selected TOS, makes relocation and restarts computer. Installed version survives reset.
> 
> If you want uninstall it, press shift+alt+control+delete keys simultaneous. It works not with TOS 1.00. Of course turning off machine also 'uninstalls'.
> If user wants install other (or same) TOS, when one is already installed, program will warn about it, but allows installation.
> However, it is not recommended because previous installation remains in RAM, and decreases free memory.
> 
> Instructions for RAMTOS:
> 
> On request I made version which loads straight first supported TOS image in current DIR. It is RAMTOS7.PRG, and everything above except usage stays for.
> Of course you may run it from AUTO folder too.
> How to get ROM-TOS images: There is small program supplied with emulator Pacifist named 'DUMP_ROM.PRG', with which you may record ROM-TOS to disk.
> There are also many TOS versions downloadable on the WEB, but you should look self about it, because copyright status is not exactly clear for me. E.g. if I have Atari with German TOS 1.04, may I use US TOS 1.04 ?
> 
> Note: ROM_TOS image files must have adequate length:
> - TOS 1.00 and 1.04: 192KB or 196608 bytes.
> - TOS 2.06: 256KB or 262144 bytes.
> 
> This program is freeware.
> Pera Putnik,  March 13. 1999. Some additions in 2006, 2008

