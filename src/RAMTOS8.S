
;TOS  Ram loader
;Version for direct load at  27. July 2006.
;Added support for Swedish TOS 2.06 on March 9 2008.

; load  file immed.
;P. Putnik

;Recognises TOS 1.00 German,  US & (UK- ?? not tested)
;TOS 1.04 US & UK & German
;TOS 2.06 German
;TOS 2.06 US & UK
;'Super'TOS 2.06 UK patched
;TOS 2.06 Swedish

;Principle of work:

;We need to relocate all 4-byte (long) addresses
; inside ROM-TOS for new position in RAM
;It can be done with table containing all those addresses
;We need separate tables for every TOS version,  since diverse languages
;have diverse locations (addresses) of code and datas
;For supporting some 10 TOS versions 10 tables would take
; a lot of space

;but there is a way with much shorter tables:
;All addresses for relocating must be in ROM address range
;so we can seek by it: for instance if ROM is in range
;$E00000-$E3FFFF we can just look high word of address
; is it in range $E0 to $E3
;So will find all addresses to relocate
;But it will find some code,  datas too,  which are not absolute ROM addresses
;so we need to make tables containing those,  not to reloc addresses
;Such tables are much shorter
;Here they are at end of code with nonr1 - nonr11  labels
;Finding all those addresses is most of work when adding support for new
;TOS (language) version
;P. Putnik


begin:
    lea     stack(pc), sp

    ;First print message

    lea     titmes(pc), a0
    bsr     pmess

    ifeq _NO_SELECT_

    ;check command line
    moveq   #0, d2
    lea     begin-128(pc), a2
    move.b  (a2)+, d2
    tst.b   d2
    beq     search ;no command line

    ;pick filename and add extension img if missing
    cmp.b   #13, d2
    bge     search  ;ignore too long command line
    move.l  d2, d3

    ;search point
    move.l  a2, a3
    moveq   #8, d4
seapol:
    tst.b   (a2)
    beq.s   addext
    cmp.b   #13, (a2)
    beq.s   addext
    cmp.b   #'.', (a2)+
    dbeq    d4, seapol

    tst.w   d4
    bpl.s   gotext

addext:
    move.b  #'.', (a2)+
    move.b  #'I', (a2)+
    move.b  #'M', (a2)+
    move.b  #'G', (a2)+
    clr.b   (a2)

gotext:
    lea     -30(a3), a3  ;precompens. offset
    move.l  a3, dtas

    bsr     loadh

    tst.w   d0
    beq.s   which2

    cmp.w   #1, d0
    beq     notosf

    cmp.w   #2, d0
    beq     loaderr

which2:

    lea     founm(pc), a0
    bsr     pmess

    bsr     lookv           ; d0 will contain the entry number
    cmp.w   #13, d0
    beq     unsupi

    ;d0 holds TOS version number

    move.l  d0, -(sp)
    bsr     putfiln
    move.l  (sp)+, d0

    bra     getpp ;to load...
    endc

;Search for ROM images
search:
    ;First check is already installed
    pea     isins(pc)
    move.w  #38, -(sp)
    trap    #14
    addq.l  #6, sp

    tst.b   itisins
    bne     apex                    ;quit silently if already installed

    lea     searchm(pc), a0
    bsr     pmess

    ifeq _NO_SELECT_
    move.w  #0, -(sp)
    pea     fnam(pc)
    move.w  #78, -(sp)  ;Fsfirst
    trap    #1
    addq.l  #8, sp

    tst.w   d0
    bne     notosf

    ;Get address of DTA
    move.w  #$2f, -(sp)
    trap    #1
    addq.l  #2, sp

    ;store DTA address
    move.l  d0, dtas
    endc

    ;Load ROM TOS header,  first 32 byte
    bsr     loadh

    tst.w   d0
    beq.s   which
    cmp.w   #1, d0
    beq     notosf
    cmp.w   #2, d0
    beq     loaderr

which:
    bsr     lookv
    cmp.w   #13, d0
    beq     unsupi ;instead notosf

    ifeq _NO_SELECT_
    lea     ftosl(pc), a2
    move.w  d0, (a2)+  ;put in list
    move.l  a2, ftosp ;set  pointer

    bsr     putfiln

    ;look other IMG files,  max 9 total
    moveq   #0, d0

    lea     ftosl(pc), a2
    ext.l   d0
    asl.l   #1, d0
    add.l   d0, a2 ;selected TOS number here
    move.w  (a2), d0
    endc

;get parameter pointer
getpp:
    mulu    #32, d0
    lea     nam1-32(pc), a2 ;precompens.
    add.l   d0, a2 ;address

    move.l  a2, selpoint  ;store it

    pea     0.w
    move.w  #$20, -(sp)
    trap    #1 ;supervisor
    addq.w  #6, sp
    move.l  d0, -(sp)

;Check is yet installed
;    cmpi.l    #$54323036, $3F8.w ;tos206
;    beq.s    anyway
;    cmpi.l    #$54313030, $3F8.w ;tos100
;    beq.s  anyway
;    cmpi.l    #$54313034, $3F8.w ;tos104
;    bne.s    loadit

;anyway
;    moveq #0, d0  ;no error sign
;    bra suexit


loadit
    clr.w   -(sp)
    ifeq _NO_SELECT_
    move.l  selpoint(pc), -(sp)      ;selected filename
    else
    pea     fnam(pc)                ; filename
    endc
    move.w  #$3D, -(sp)              ; fopen
    trap    #1
    addq.w  #8, sp

    move.w  d0, handl                ; handle
    bmi     suerr


    move.l  selpoint(pc), a2
    move.l  18(a2), d2  ;selected TOS's length
    movea.l $42E.w, a6 ;phystop
    suba.l  d2, a6

    move.l  a6, newphy ;new phystop

    move.w  #$FFFF, -(sp) ;resol. stay
    movea.l a6, a5
    suba.l  #$8000, a5 ;better way
    move.l  a5, -(sp)
    move.l  a5, -(sp)
    move.w  #5, -(sp)
    trap    #14
    lea     $C(sp), sp

    pea     instm(pc) ;Install message
    move.w  #9, -(sp)
    trap    #1
    addq.w  #6, sp

    move.l  newphy(pc), -(sp)
    move.l  selpoint(pc), a2
    move.l  18(a2), d2  ;selected TOS's length
    move.l  d2, -(sp)
    move.w  handl(pc), -(sp)
    move.w  #$3F, -(sp)
    trap    #1
    lea     $C(sp), sp

    move.l  selpoint(pc), a2
    move.l  18(a2), d2  ;selected TOS's length

    cmp.l   d2, d0
    bne     suerr ;load error

    move.w  handl(pc), -(sp)
    move.w  #$3E, -(sp) ;fclose
    trap    #1
    addq.w  #4, sp

    move.l  newphy(pc), d0
    move.l  d0, a6

    move.l  a6, $42e.w ;now change phystop

    pea     relom(pc) ;relocating message
    move.w  #9, -(sp)
    trap    #1
    addq.w  #6, sp

    move.l  a6, d2
    swap    d2
    move.l  selpoint(pc), a2
    move.w  14(a2), d3  ;selected TOS's base high word
    move.w  16(a2), d4  ;end address high word
    move.l  18(a2), d5 ;length

    sub.w   d3, d2 ;phystop is always on round adress

    move.l  a6, a5
    move.l  a6, a4
    add.l   d5, a5 ;end adr.

    move.l  22(a2), a1 ;don't reloc table
    moveq   #0, d0

reloc:
    move.w  (a6), d1
    cmp.w   d3, d1
    blt.s   notrom
    cmp.w   d4, d1
    bge.s   notrom
    cmp.l   (a1), d0 ;no reloc if equ !
    beq.s   advnonr
    add.w   d2, d1
    move.w  d1, (a6)
    addq.l  #2, a6
    addq.l  #2, d0
notrom
    addq.l  #2, a6
    addq.l  #2, d0
    cmp.l   a5, a6
    blt.s   reloc

    move.l  28(a2), $3F8.w  ;sign of install version 'check_de_100 - check_de_206'
    move.l  a4, $3FC.w

;Ensure restart of new TOS after reset with button (backside)
    move.l  #$31415926, $426.w

    move.w  26(a2), d2  ;reset entry offset
    ext.l   d2
    move.l  a4, a5
    add.l   d2, a5 ;point after resvector
    move.l  a5, $42a.w
    move.l  #$5555aaaa, $51a.w ;This is due TOS 1.00 !

    jmp     (a4) ;reset via ramtos!

advnonr:
    addq.l  #4, a1
    bra.s   notrom

suerr:
    lea     loaderrt(pc), a0
    bsr     pmess

;Back to user
suexit:
    move.w  #$20, -(sp)
    trap    #1
    addq.w  #6, sp

keywait:
    bsr.s   input

apex:
    pea     $4C0000
    trap    #1

loaderr:
    lea     loaderrt(pc), a0
    bra.s   prim

unsupi:
    lea     unsupm(pc), a0
    bra.s   prim

;image not found
notosf:
    lea    imnfm(pc), a0

prim:
    bsr.s   pmess
    bra.s   keywait

pmess:
    pea     (a0)
    move.w  #9, -(sp)
    trap    #1
    addq.w  #6, sp
    rts

input:
    move.w  #1, -(sp)
    trap    #1
    addq.l  #2, sp
    rts

;Detecting is already installed in supervisor
isins:
    cmp.l   #$31415926, $426.w
    seq     itisins
    rts

itisins:
    dc.w    0  ;flag

loadh:
    ifeq _NO_SELECT_
    move.l  dtas(pc), d1
    move.l  d1, a1
    lea     30(a1), a1
    endc

    clr.w   error
    clr.w   -(sp)
    ifeq _NO_SELECT_
    pea     (a1)
    else
    pea     fnam(pc)
    endc
    move.w  #$3D, -(sp) ;fopen
    trap    #1
    addq.w  #8, sp

    move.w  d0, handl ;handle
    bmi.s   tosimnf ;TOS.IMG not found

    pea     stack(pc)
    pea     32.w
    move.w  handl(pc), -(sp)
    move.w  #$3F, -(sp)
    trap    #1
    lea     $C(sp), sp

    cmp.l   #32, d0
    bne.s   hloaderr ;load error

    move.w  handl(pc), -(sp)
    move.w  #$3E, -(sp) ;fclose
    trap    #1
    addq.w  #4, sp

    moveq   #0, d0
    rts

tosimnf:
    moveq   #1, d0
    rts

hloaderr:
    moveq   #2, d0
    rts

 ;see which version is
lookv:
    lea     stack(pc), a1

    cmp.w   #$0100, 2(a1)
    beq.s   check_de_100

    cmp.w   #$0102, 2(a1)
    beq.s   check_fr_102

    cmp.w   #$0104, 2(a1)
    beq.s   check_uk_104

    cmp.w   #$0206, 2(a1)
    beq     check_de_206

notfs:
    moveq   #13, d0 ;not found supported
    rts

; ---------------------------------------------------------------
; TOS 1.00
; ---------------------------------------------------------------
check_de_100:
    cmp.w   #3, $1c(a1) ;is german
    bne.s   isuk100

    lea     t1m(pc), a0
    bsr     cmess
    moveq   #1, d0
    rts

isuk100:
    cmp.w   #7, $1c(a1) ;is UK
    bne.s   isus100

    lea     t8m(pc), a0
    bsr     cmess
    moveq   #8, d0
    rts

isus100:
    cmp.w   #0, $1c(a1) ;is US
    bne.s   notfs

    lea     t9m(pc), a0
    bsr     cmess
    moveq   #9, d0
    rts

; ---------------------------------------------------------------
; TOS 1.02
; ---------------------------------------------------------------
check_fr_102:
    bra notfs

; ---------------------------------------------------------------
; TOS 1.04
; ---------------------------------------------------------------
check_uk_104:
    cmp.w #7, $1c(a1) ;is English
    bne.s check_us_104

    lea t2m(pc), a0
    bsr cmess
    moveq #2, d0
    rts

check_us_104:
    cmp.w   #0, $1c(a1)
    bne.s   isg104

    lea     t7m(pc), a0
    bsr     cmess
    moveq   #7, d0
    rts

isg104:
    cmp.w   #3, $1c(a1)
    bne.s   notfs

    lea     t10m(pc), a0
    bsr     cmess
    moveq   #10, d0
    rts

; ---------------------------------------------------------------
; TOS 2.06
; ---------------------------------------------------------------
check_de_206:
    cmp.w   #3, $1c(a1) ;is German
    bne.s   check_us_206

    lea     t3m(pc), a0
    bsr     cmess
    moveq   #3, d0
    rts

check_us_206:
    cmp.w   #7, $1c(a1)            ; shouldn't be 00 00 ?
    beq.s   ispat2

    ;Is US TOS 2.06
    cmp.w   #0, $1c(a1)
    bne.s   check_sw_206

    lea     t6m(pc), a0
    bsr     cmess
    moveq   #6, d0
    rts

; Is SW TOS 2.06
check_sw_206:
    cmp.w   #$0d, $1c(a1)
    bne.s   check_fr_206

    lea     t11m(pc), a0
    bsr     cmess
    moveq   #11, d0
    rts

; Is Fr TOS 2.06
check_fr_206:
    cmp.w   #$05, $1c(a1)
    bne     notfs

    lea     t12m(pc), a0
    bsr     cmess
    moveq   #12, d0
    rts

;further test needed for patched version

ispat2
    ifeq _NO_SELECT_
    move.l  dtas(pc), d1
    move.l  d1, a1
    lea     30(a1), a1
    endc

    clr.w   error
    clr.w   -(sp)

    ifeq _NO_SELECT_
    pea     (a1)
    else
    pea     fnam(pc)
    endc

    move.w  #$3D, -(sp) ;fopen
    trap    #1
    addq.w  #8, sp

    move.w  d0, handl ;handle
    bmi.s   ferr2 ;TOS.IMG not found


    clr.w   -(sp)
    move.w  handl(pc), -(sp)
    pea     $1e956
    move.w  #$42, -(sp)    ;Fseek
    trap    #1
    lea     $a(sp), sp

    pea     stack(pc)
    pea     2.w
    move.w  handl(pc), -(sp)
    move.w  #$3F, -(sp)
    trap    #1
    lea     $C(sp), sp

    cmp.l   #2, d0
    bne.s   ferr2 ;load error

    move.w  handl(pc), -(sp)
    move.w  #$3E, -(sp) ;fclose
    trap    #1
    addq.w  #4, sp


    cmp.w   #$00e0, stack ;is patched
    beq.s   t2ep

    lea     t4m(pc), a0
    bsr     cmess
    moveq   #4, d0
    rts

t2ep:
    lea     t5m(pc), a0
    bsr     cmess
    moveq   #5, d0
    rts

ferr2:
    bra     notfs  ;for now

cmess:
    lea     founc(pc), a2
    addq.w  #1, (a2)
    move.w  (a2), d2
    add.w   #'0', d2

    move.b  d2, founp+2

    move.l  a0, -(sp)

    lea     founp(pc), a0
    bsr     pmess

    move.l  (sp)+, a0
    bra     pmess

    ifeq _NO_SELECT_
;put filename to propr. TOS param. table
putfiln: 

    ext.l   d0
    mulu    #32, d0
    lea     nam1-32(pc), a2
    add.l   d0, a2
    move.l  dtas(pc), a1
    lea     30(a1), a1
    moveq   #13, d0

putnlop
    move.b  (a1)+, (a2)+
    dbf     d0, putnlop
    rts

    endc

newphy:
     ds.l   1

handl:    
    dc.w    0 ;place for handle

; -------------------------------------------------------------
; Messages
; -------------------------------------------------------------
titmes:
    dc.b    13, 10, 'TOS loader by P. Putnik', 0
searchm:
    dc.b    13, 10, 'Searching ROM-TOS images...', 0
founm:
    dc.b    13, 10, 'Found:', 0

t1m:    dc.b 'TOS 1.00 German', 0
t2m     dc.b 'TOS 1.04 UK', 0
t3m     dc.b 'TOS 2.06 German', 0
t4m     dc.b 'TOS 2.06 UK', 0
t5m     dc.b 39, 'Super', 39, 'TOS 2.06 UK-patched', 0
t6m     dc.b 'TOS 2.06 US', 0
t7m     dc.b 'TOS 1.04 US', 0
t8m     dc.b 'TOS 1.00 UK', 0
t9m     dc.b 'TOS 1.00 US', 0
t10m    dc.b 'TOS 1.04 German', 0
t11m    dc.b 'TOS 2.06 Swedish', 0
t12m    dc.b 'TOS 2.06 French', 0

;Image file name
fnam:
    ifeq _NO_SELECT_
    dc.b    ';.IMG', 0
    else
    dc.b    'RTOS.IMG', 0
    endc

loaderrt:
    dc.b    13, 10, 'Error by loading!', 0

anywam:
    dc.b    13, 10, 'One ROM-TOS already installed.'
    dc.b    13, 10, 'Load anyway ? ', 0

;Install message
instm:
     dc.b   13, 10, 'Loading...', 0

;Relocating message
relom:
    dc.b    13, ' Relocating...', 0

;image not found message
imnfm:
    dc.b    13, 10, 'ROM-TOS image not found.', 0

unsupm:
    dc.b    13, 10, 'Unsupported (TOS) image file.', 0

    ifeq _NO_SELECT_
choosm:
    dc.b    13, 10, 13, 10, 'Choose which TOS to install  1-'
choosm2:
    dc.b    '1.', 0
    endc

founp:
    dc.b    13, 10, "x: ", 0
    even

founc:      dc.w 0
dtas:       ds.l 1
error:      ds.w 1
ftosp:      ds.l 1
fscount:    ds.w 1

; -------------------------------------------------------------
; parameter table for each TOS
; FileName-14 bytes
; Base address,  end address - just words for compare
; Length - long
; Nonreloc data address - long
; Offset after resetvector - word
; Install sign - long
; Total 32 bytes
; -------------------------------------------------------------

;German 1.00
nam1:
    ds.b    14             ;place for filename
    dc.w    $00FC, $00FF
    dc.l    $30000
    dc.l    nonr1
    dc.w    $74
    dc.l    $54313030

;UK 1.04
nam2
    ds.b    14
    dc.w    $00FC, $00FF
    dc.l    $30000
    dc.l    nonr2
    dc.w    $80
    dc.l    $54313034

;German 2.06
nam3:
    ds.b    14
    dc.w    $00E0, $00E4
    dc.l    $40000
    dc.l    nonr3
    dc.w    $7e
    dc.l    $54323036

;UK 2.06
nam4:
    ds.b    14
    dc.w    $00E0, $00E4
    dc.l    $40000
    dc.l    nonr4
    dc.w    $7e
    dc.l    $54323036

;UK supertos 2.06
nam5
    ds.b    14
    dc.w    $00E0, $00E4
    dc.l    $40000
    dc.l    nonr5
    dc.w    $7e
    dc.l    $54323036

;US 2.06
nam6
    ds.b    14
    dc.w    $00E0, $00E4
    dc.l    $40000
    dc.l    nonr4  ;same as UK TOS 2.06
    dc.w    $7e
    dc.l    $54323036

;US 1.04
nam7
    ds.b    14
    dc.w    $00FC, $00FF
    dc.l    $30000
    dc.l    nonr2  ;same as UK TOS 1.04 ???
    dc.w    $80
    dc.l    $54313034

;UK 1.00
nam8:
    ds.b    14  ;place for filename
    dc.w    $00FC, $00FF
    dc.l    $30000
    dc.l    nonr6
    dc.w    $74
    dc.l    $54313030

;US 1.00
nam9:
    ds.b    14  ;place for filename
    dc.w    $00FC, $00FF
    dc.l    $30000
    dc.l    nonr6
    dc.w    $74
    dc.l    $54313030

;German 1.04
nam10:
    ds.b    14
    dc.w    $00FC, $00FF
    dc.l    $30000
    dc.l    nonr7
    dc.w    $80
    dc.l    $54313034

;Swedish 2.06
nam11:
    ds.b    14
    dc.w    $00E0, $00E4
    dc.l    $40000
    dc.l    nonr8
    dc.w    $7e
    dc.l    $54323036

;French 2.06
nam12
    ds.b    14                 ; FileName-14 bytes
    dc.w    $00E0, $00E4        ; Base address,  end address - just words for compare
    dc.l    $40000             ; Length - long,  265K
    dc.l    nonr9              ; Nonreloc data address - long
    dc.w    $7e                ; Offset after resetvector - word
    dc.l    $54323036          ; Install sign - long

;US 2.06
;           US 2.06         SW 2.06             UK 2.06         DE 2.06
;     ds.b  14
;     dc.w  $00E0, $00E4     $00E0, $00E4         $00E0, $00E4     $00E0, $00E4
;     dc.l  $40000          $40000              $40000          $40000
;     dc.l  nonr4           nonr8               nonr4           nonr3
;     dc.w  $7e             $7e                 $7e             $7e
;     dc.l  $54323036       $54323036           $54323036       $54323036

; -------------------------------------------------------------
; Non-relocating tables
; this are adresses which are not for reloc!
; -------------------------------------------------------------

;German TOS 1.00
nonr1:
    dc.l    $17c8
    dc.l    $17d8
    dc.l    $252e
    dc.l    $2566
    dc.l    $28e6
    dc.l    $2b9a
    dc.l    $85ba
    dc.l    $a8c8
    dc.l    $fbea
    dc.l    $126d2
    dc.l    $1347e
    dc.l    $135ba
    dc.l    $13bb6
    dc.l    $13d6c
    dc.l    $14616
    dc.l    $14716
    dc.l    $207dc
    dc.l    $20800
    dc.l    $20d3e
    dc.l    $2afbc
    dc.l    $2afc2
    dc.l    $2afca
    dc.l    $2be14
    dc.l    0

;uk tos 1.04
nonr2
    dc.l    $117e
    dc.l    $1514
    dc.l    $3bac
    dc.l    $3e04
    dc.l    $3eb2
    dc.l    $55ae
    dc.l    $610c
    dc.l    $8594
    dc.l    $88b4
    dc.l    $15c1c
    dc.l    $170d4
    dc.l    $17426
    dc.l    $18406
    dc.l    $1abc2
    dc.l    $251e8
    dc.l    $27298
    dc.l    $28898
    dc.l    $29644
    dc.l    $29780
    dc.l    $29b20
    dc.l    $29cd6
    dc.l    $2a580
    dc.l    $2a680
    dc.l    0 ;23 entry

;german tos 2.06
nonr3
    dc.l    $89a
    dc.l    $13d0
    dc.l    $1bca
    dc.l    $1d3a
    dc.l    $1d3e
    dc.l    $1df0
    dc.l    $1df6
    dc.l    $229c
    dc.l    $622c
    dc.l    $6bd0
    dc.l    $8da8
    dc.l    $8dca
    dc.l    $106c0
    dc.l    $13316
    dc.l    $15840
    dc.l    $17b4a
    dc.l    $18c5c
    dc.l    $190fc
    dc.l    $19274
    dc.l    $19d64
    dc.l    $1a96a
    dc.l    $1b244
    dc.l    $1c3fc
    dc.l    $1ca64
    dc.l    $1ccca
    dc.l    $1cd98
    dc.l    $1cfbe
    dc.l    $1d82a
    dc.l    $20854
    dc.l    $21210
    dc.l    $22bdc
    dc.l    $22bf8
    dc.l    $2416e
    dc.l    $265b8
    dc.l    $266a6
    dc.l    $27248
    dc.l    $2aa0c
    dc.l    $2b042
    dc.l    $2b802
    dc.l    $2b82a
    dc.l    $2ba18
    dc.l    $32842
    dc.l    $33598
    dc.l    $351c0
    dc.l    $3a2e2
    dc.l    $3a47c
    dc.l    $3a60a
    dc.l    $3a60e
    dc.l    $3b6ce
    dc.l    0

;uk and us tos 2.06
nonr4
    dc.l    $89a
    dc.l    $13d0
    dc.l    $1bca
    dc.l    $1d3a
    dc.l    $1d3e
    dc.l    $1df0
    dc.l    $1df6
    dc.l    $229c
    dc.l    $61d2
    dc.l    $6b76
    dc.l    $8d4e
    dc.l    $8d70
    dc.l    $10666
    dc.l    $132bc
    dc.l    $157e6
    dc.l    $17af0
    dc.l    $18c02
    dc.l    $190a2
    dc.l    $1921a
    dc.l    $19d0a
    dc.l    $1a910
    dc.l    $1b1ea
    dc.l    $1c3a2
    dc.l    $1ca0a
    dc.l    $1cc70
    dc.l    $1cd3e
    dc.l    $1cf64
    dc.l    $1d7d0
    dc.l    $207fa
    dc.l    $211b6
    dc.l    $22b82
    dc.l    $22b9e
    dc.l    $24114
    dc.l    $264b6 ;new entry
    dc.l    $26590
    dc.l    $265b8
    dc.l    $271ee
    dc.l    $2a9b2
    dc.l    $2afe8
    dc.l    $2b7ac
    dc.l    $2b7d8
    dc.l    $32812
    dc.l    $33568
    dc.l    $35190
    dc.l    $3a0a0 ;new entry
    dc.l    $3a23a
    dc.l    $3a3c8
    dc.l    $3a3cc
    dc.l    0 ;48 address

;uk 'super' tos 2.06
nonr5
    dc.l    $89a
    dc.l    $13d0
    dc.l    $1bca
    dc.l    $1d3a
    dc.l    $1d3e
    dc.l    $1df0
    dc.l    $1df6
    dc.l    $229c
    dc.l    $61d2
    dc.l    $6b76
    dc.l    $8d4e
    dc.l    $8d70
    dc.l    $10666
    dc.l    $132bc
    dc.l    $157e6
    dc.l    $17af0
    dc.l    $18c02
    dc.l    $190a2
    dc.l    $1921a
    dc.l    $19d0a
    dc.l    $1a910
    dc.l    $1b1ea
    dc.l    $1c3a2
    dc.l    $1ca0a
    dc.l    $1cc70
    dc.l    $1cd3e
    dc.l    $1cf64
    dc.l    $1e1aa
    dc.l    $1e956
    dc.l    $207fa
    dc.l    $211b6
    dc.l    $22b82
    dc.l    $22b9e
    dc.l    $24114
    dc.l    $264b6
    dc.l    $26590
    dc.l    $265b8
    dc.l    $271ee
    dc.l    $2afe8
    dc.l    $2b7ac
    dc.l    $2b7d8
    dc.l    $32812
    dc.l    $33568
    dc.l    $35190
    dc.l    $3a0a0
    dc.l    $3a23a
    dc.l    $3a3c8
    dc.l    $3a3cc
    dc.l    0 ;48 entry

;uk and us tos 1.00
nonr6
    dc.l    $17c8
    dc.l    $17d8
    dc.l    $252e
    dc.l    $2566
    dc.l    $28e6
    dc.l    $2b40
    dc.l    $8560
    dc.l    $a86e
    dc.l    $fb90
    dc.l    $12678
    dc.l    $13424
    dc.l    $13560
    dc.l    $13b5c
    dc.l    $13d12
    dc.l    $145bc
    dc.l    $146bc
    dc.l    $20b1a
    dc.l    $20b3e
    dc.l    $2107c
    dc.l    $2b308
    dc.l    $2b30e
    dc.l    $2b316
    dc.l    $2c160
    dc.l    0

;german tos 1.04
nonr7
    dc.l    $117e
    dc.l    $1514
    dc.l    $3a4c
    dc.l    $3f0c
    dc.l    $5608
    dc.l    $6166
    dc.l    $85ee
    dc.l    $890e
    dc.l    $15c76
    dc.l    $1712e
    dc.l    $17480
    dc.l    $18438
    dc.l    $1abf4
    dc.l    $2521a
    dc.l    $272ca
    dc.l    $288ca
    dc.l    $29676
    dc.l    $297b2
    dc.l    $29b52
    dc.l    $29d08
    dc.l    $2a5b2
    dc.l    $2a6b2
    dc.l    $2ec00
    dc.l    0 ;23 entry

;swedish tos 2.06
nonr8
    dc.l    $89a
    dc.l    $13d0
    dc.l    $1bca
    dc.l    $1d3a
    dc.l    $1d3e
    dc.l    $1df0
    dc.l    $1df6
    dc.l    $229c
    dc.l    $624a
    dc.l    $6bee ; <-
    dc.l    $8dc6
    dc.l    $8de8 ; <-
    dc.l    $106de
    dc.l    $13334
    dc.l    $1585e
    dc.l    $17b68
    dc.l    $18c7a
    dc.l    $1911a
    dc.l    $19292
    dc.l    $19d82
    dc.l    $1a988
    dc.l    $1b262
    dc.l    $1c41a
    dc.l    $1ca82
    dc.l    $1cce8
    dc.l    $1cdb6
    dc.l    $1cfdc
    dc.l    $1d848
    dc.l    $20872
    dc.l    $2122e
    dc.l    $22bfa
    dc.l    $22c16
    dc.l    $2418c
    dc.l    $265d6
    dc.l    $266c4
    dc.l    $27266
    dc.l    $2aa2a
    dc.l    $2b060
    dc.l    $2b824
    dc.l    $2b850
    dc.l    $32860
    dc.l    $335b6
    dc.l    $351de
    dc.l    $3a364
    dc.l    $3a4fe
    dc.l    $3a68c
    dc.l    $3a690
    dc.l    $3b750
    dc.l    0

; french 206
nonr9:
    dc.l    $89a
    dc.l    $13d0
    dc.l    $1bca
    dc.l    $1d3a
    dc.l    $1d3e
    dc.l    $1df0
    dc.l    $1df6
    dc.l    $229c
    dc.l    $624a
    dc.l    $6bee
    dc.l    $8dc6
    dc.l    $8de8
    dc.l    $106de
    dc.l    $13334
    dc.l    $1585e
    dc.l    $17b68
    dc.l    $18c7a
    dc.l    $1911a
    dc.l    $19292
    dc.l    $19d82
    dc.l    $1a988
    dc.l    $1b262
    dc.l    $1c41a
    dc.l    $1ca82
    dc.l    $1cce8
    dc.l    $1cdb6
    dc.l    $1cfdc
    dc.l    $1d848
    dc.l    $20872
    dc.l    $2122e
    dc.l    $22bfa
    dc.l    $22c16
    dc.l    $2418c
    dc.l    $265d6
    dc.l    $266c4
    dc.l    $27266
    dc.l    $2aa2a
    dc.l    $2b060
    dc.l    $2b824
    dc.l    $2b850
    dc.l    $32860
    dc.l    $335b6
    dc.l    $351de
    dc.l    $3a364
    dc.l    $3a4fe
    dc.l    $3a68c
    dc.l    $3a690
    dc.l    $3b750
    dc.l    0

; -------------------------------------------------------------
; bss
; -------------------------------------------------------------

   section bss

selpoint
    ds.l    1

    ifeq _NO_SELECT_
ftosl:
    ds.w    9      ;max 9 TOS in list
    endc

    ds.b    500    ;place for stack

stack:
    ds.b    485000 ;place for load & screen & decomp

