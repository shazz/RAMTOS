
; TOS Ram loader: RAMTOS / SELTOS

; ---------------------------------------------------------------------
; Change log
; ---------------------------------------------------------------------

; Version for direct load at 27. July 2006.
; Added support for Swedish TOS 2.06 on March 9 2008.
; P. Putnik

; Cleaning, added support for French TOS 2.06 (12/2024)
; TOS 2.06 patched to remove CRC ROM check (01/2025)
; Improved SELTOS key pressed input (01/2025)
; Added support for French, Spanish, Swedish, Dutch TOS 1.04 (01/2025)
; Shazz / MJJ Prod

; ---------------------------------------------------------------------
; Info
; ---------------------------------------------------------------------

; Supports:
; - TOS 1.00 German, US, UK
; - TOS 1.04 US, UK, German, French, Spanish, Dutch
; - TOS 2.06 German, US, UK, Swedish, French
; - 'Super'TOS 2.06 UK patched

; Principle of work:
;
; We need to relocate all 4-byte (long) addresses inside ROM-TOS for new position in RAM
; It can be done with table containing all those addresses
; We need separate tables for every TOS version, since diverse languages
; have diverse locations (addresses) of code and datas
; For supporting some 10 TOS versions 10 tables would take a lot of space
;
; But there is a way with much shorter tables:
; All addresses for relocating must be in ROM address range
; so we can seek by it: for instance if ROM is in range
; $E00000-$E3FFFF we can just look high word of address is it in range $E0 to $E3
; So will find all addresses to relocate
; But it will find some code, data too, which are not absolute ROM addresses
; so we need to make tables containing those,  not to reloc addresses
; Such tables are much shorter
; Here they are at end of code with non_rel_tos100de - non_rel_tos100de1 labels
; Finding all those addresses is most of work when adding support for new
; TOS (language) version

; ---------------------------------------------------------------
; Constants
; ---------------------------------------------------------------

RESVALID                        equ $426                ; $000426|long |Validates resvector if $31415926                        |resvalid
RESVECTOR                       equ $42A                ; $00042A|long |Reset vector                                            |resvector
PHYSTOP                         equ $42E                ; $00042E|long |Physical top of RAM 0x100000 on 1MB ST                  |phystop
MEMTOP                          equ $436                ; $000436|long |End of TPA (user memory, 0x0f8000 on 1040)              |_memtop 
MEMVAL2                         equ $43A                ; $00043A|long |Validates memcntrl and memconf if $237698AA             |memval2
THEMD                           equ $48E                ; $00048E|long |Memory descriptor block                                 |themd
MEMVAL3                         equ $51A                ; $00051A|long |If $5555AAAA, reset                                     |memval3

MEMVAL3_VALID                   equ $5555aaaa

MAX_FILES                       equ 9
NOT_SUPPORTED                   equ 20
RESVECTOR_MAGIC                 equ $31415926           ; magic number to setup the reset vector
PARAMS_SIZE                     equ param2_tos104uk-param1_tos100de

PARAM_FILENAME_FIELD            equ 0
PARAM_BASE_ADDR_FIELD           equ 14
PARAM_END_ADDR_FIELD            equ 16
PARAM_LENGTH_FIELD              equ 18
PARAM_NON_RELOC_ADDR_FIELD      equ 22
PARAM_RESVEC_OFFSET_FIELD       equ 26
PARAM_INSTALL_SIGN_FIELD        equ 28
PARAM_CRC_START_OFFSET_FIELD    equ 32
PARAM_CRC_END_OFFSET_FIELD      equ 34

; ---------------------------------------------------------------
; Main program
; ---------------------------------------------------------------
begin:
    clr.l   -(sp)                       ; clear stack
    move.w  #32, -(sp)                  ; prepare for super mode
    trap    #1                          ; call gemdos
    addq.l  #6, sp                      ; clear up stack
    move.l  d0, -(sp)

    ifne _RAMTOS_
    lea     checking_message(pc), a0
    bsr     show_message

    ;Check is yet installed
    cmpi.l  #$54323036, $3F8.w          ; tos206
    beq     quit
    cmpi.l  #$54313030, $3F8.w          ; tos100
    beq     quit
    cmpi.l  #$54313034, $3F8.w          ; tos104
    beq     quit   
    endc

    lea     stack(pc), sp

    ;First print message
    lea     title_message(pc), a0
    bsr     show_message

    ifeq _RAMTOS_
    ;check command line
    moveq   #0, d2
    lea     begin-128(pc), a2
    move.b  (a2)+, d2
    tst.b   d2
    beq     search_tos_images           ;no command line

    ;pick filename and add extension img if missing
    cmp.b   #13, d2
    bge     search_tos_images           ;ignore too long command line
    move.l  d2, d3

    ;search point
    move.l  a2, a3
    moveq   #8, d4
.loop:
    tst.b   (a2)
    beq.s   .add_extension

    cmp.b   #13, (a2)
    beq.s   .add_extension

    cmp.b   #'.', (a2)+
    dbeq    d4, .loop

    tst.w   d4
    bpl.s   gotext

.add_extension:
    move.b  #'.', (a2)+
    move.b  #'I', (a2)+
    move.b  #'M', (a2)+
    move.b  #'G', (a2)+
    clr.b   (a2)

; ---------------------------------------------------------------
; gotext
; ---------------------------------------------------------------
gotext:
    lea     -30(a3), a3                 ;precompens. offset
    move.l  a3, DTA

    bsr     load_rom

    tst.w   d0
    beq.s   which2

    cmp.w   #1, d0
    beq     show_image_not_found_msg

    cmp.w   #2, d0
    beq     show_loaderr_msg

; ---------------------------------------------------------------
;
; ---------------------------------------------------------------
which2:
    lea     found_message(pc), a0
    bsr     show_message

    bsr     find_version                ; d0 will contain the entry number
    cmp.w   #NOT_SUPPORTED, d0
    beq     show_unsupported_msg

    ;d0 holds TOS version number
    move.l  d0, -(sp)
    bsr     insert_filename
    move.l  (sp)+, d0

    bra     get_params                  ; to load...
    endc

; ---------------------------------------------------------------
; search_tos_images for ROM images
; ---------------------------------------------------------------
search_tos_images:

    ifeq _SELTOS_
    ;First check is already installed
    pea     check_installed(pc)
    move.w  #38, -(sp)
    trap    #14
    addq.l  #6, sp

    tst.b   is_installed
    bne     quit                        ; quit silently if already installed
    endc

    lea     search_message(pc), a0
    bsr     show_message

    ifeq _RAMTOS_
    move.w  #0, -(sp)
    pea     filename(pc)
    move.w  #78, -(sp)                  ; Fsfirst Fsfirst() searches the file/pathspec given
                                        ; for the first occurrence of a file or
                                        ; subdirectory with named attributes and if found,
                                        ; fill in the current DTA with that file’s information.
    trap    #1
    addq.l  #8, sp

    tst.w   d0
    bne     show_image_not_found_msg

    ;Get address of DTA
    ; typedef struct {
    ;     BYTE d_reserved[21];
    ;     BYTE d_attrib;
    ;     UWORD d_time;
    ;     UWORD d_date;
    ;     LONG d_length;
    ;     char d_fname[14];
    ; } DTA;
    move.w  #$2f, -(sp)                 ; Fgetdta() returns current DTA (Disk Transfer Address)
    trap    #1
    addq.l  #2, sp

    ;store DTA address
    move.l  d0, DTA
    endc

    ;Load ROM TOS header,  first 32 byte
    bsr     load_rom

    tst.w   d0
    beq.s   which

    cmp.w   #1, d0
    beq     show_image_not_found_msg

    cmp.w   #2, d0
    beq     show_loaderr_msg

; ---------------------------------------------------------------
;
; ---------------------------------------------------------------
which:
    ifeq _SELTOS_
    lea     found_message(pc),a0
    bsr     show_message
    endc

    bsr     find_version
    cmp.w   #NOT_SUPPORTED, d0
    beq     show_unsupported_msg        ; instead show_image_not_found_msg

    ifeq _RAMTOS_
    lea     TOS_list(pc), a2
    move.w  d0, (a2)+                   ; put in list
    move.l  a2, ftosp                   ; set  pointer

    bsr     insert_filename

    ifeq _SELTOS_
    move.w  #1, fscount

fsnext:
    move.w  #79, -(sp)                  ; fsnext
    trap    #1
    add.l   #2, sp

    tst.w   d0
    bmi     select

    bsr     load_rom

    tst.w   d0
    bne.s   check_next

    bsr     find_version
    cmp.w   #NOT_SUPPORTED, d0
    beq.s   check_next

    move.l  ftosp(pc), a2
    move.w  d0, (a2)+                   ; put in list
    move.l  a2, ftosp                   ; set  pointer
    addq.w  #1, fscount

    bsr     insert_filename

check_next:
    cmp.w   #MAX_FILES, fscount         ; is max. count reached ?
    bne.s   fsnext

select:
    move.w  fscount(pc), d3
    move.w  d3, d4                      ; save nb of TOS found
    add.w   #'0', d3                    ; convert to ASCII
    move.b  d3, selection2_message          
    lea     selection_message(pc), a0
    bsr     show_message                ; show message

    bsr     get_input_key               ; get key pressed in d0

    sub.b   #'1', d0                    ; get index value starting at ASCII 1
    bmi.s   select                      ; if less, wrong input

    cmp.b   d4, d0                      ; if more than nb if found TOS, wrong input
    bge.b   select

    else
    ;look other IMG files,  max 9 total
    moveq   #0, d0
    endc

    lea     TOS_list(pc), a2
    ext.l   d0
    asl.l   #1, d0
    add.l   d0, a2                      ; selected TOS number here
    move.w  (a2), d0
    endc

; ---------------------------------------------------------------
; Get parameter table
; d0 = entry number
; ---------------------------------------------------------------
get_params:
    mulu    #PARAMS_SIZE, d0
    lea     param1_tos100de-PARAMS_SIZE(pc), a2  ; precompens.
    add.l   d0, a2                      ; address

    move.l  a2, selected_params         ; store it

    ifeq _SELTOS_
    ;Check is yet installed
    cmpi.l  #$54323036, $3F8.w ;tos206
    beq.s   anyway
    cmpi.l  #$54313030, $3F8.w ;tos100
    beq.s   anyway
    cmpi.l  #$54313034, $3F8.w ;tos104
    bne.s   load_tos_image

anyway:
    lea     anyway_message(pc),a0
	bsr     show_message

	bsr     get_input_key
	bclr    #5, d0                      ; upper case

	cmp.b   #'Y', d0
	beq.s   load_tos_image

	moveq   #0, d0                      ; no error sign
	bra     switch_user_mode
    endc

; ---------------------------------------------------------------
; load_tos_image
; ---------------------------------------------------------------
load_tos_image:
    clr.w   -(sp)

    ifeq _RAMTOS_
    move.l  selected_params(pc), -(sp)  ; selected filename entry
    else
    pea     filename(pc)                ; hardcoded filename
    endc

    move.w  #$3D, -(sp)                 ; fopen
    trap    #1
    addq.w  #8, sp

    move.w  d0, handle                  ; handle
    bmi     load_error

    move.l  selected_params(pc), a2
    move.l  PARAM_LENGTH_FIELD(a2), d2  ; selected TOS's length
    move.l  d2, required_space

    movea.l PHYSTOP.w, a6               ; phystop
    suba.l  d2, a6
    move.l  a6, new_phystop             ; new phystop

    movea.l MEMTOP.w, a6                ; memtop
    suba.l  d2, a6
    move.l  a6, new_memtop              ; new memtop

    move.w  #$FFFF, -(sp)               ; resol. stay
    movea.l a6, a5
    suba.l  #$8000, a5                  ; better way
    move.l  a5, -(sp)
    move.l  a5, -(sp)
    move.w  #5, -(sp)
    trap    #14
    lea     $C(sp), sp

    pea     loading_message(pc)         ; install message
    move.w  #9, -(sp)
    trap    #1
    addq.w  #6, sp

    move.l  new_phystop(pc), -(sp)
    move.l  selected_params(pc), a2
    move.l  PARAM_LENGTH_FIELD(a2), d2  ; selected TOS's length
    move.l  d2, -(sp)
    move.w  handle(pc), -(sp)
    move.w  #$3F, -(sp)                 ; Fread(handle, length, buf)
    trap    #1
    lea     $C(sp), sp

    move.l  selected_params(pc), a2
    move.l  PARAM_LENGTH_FIELD(a2), d2  ; selected TOS's length

    cmp.l   d2, d0
    bne     load_error                  ; load error

    move.w  handle(pc), -(sp)
    move.w  #$3E, -(sp)                 ; fclose
    trap    #1
    addq.w  #4, sp

    move.l  new_memtop(pc), d0
    move.l  d0, a6
    move.l  a6, MEMTOP.w                ; now change memtop

    move.l  required_space, d0
    sub.l   d0, THEMD+8.w                ; Change Gemdos first free memory block 0f 512 bytes
    ; themd
    ;    typedef struct md
    ;    {
    ;       struct md *m_link; /* pointer to next block $48e*/
    ;       VOIDP m_start; /* pointer to start of block $492*/
    ;   =>  LONG m_length; /* length of block $496 */
    ;       BASEPAGE *m_own; /* pointer to basepage of owner $49A*/
    ;    } MD;

    move.l  new_phystop(pc), d0
    move.l  d0, a6
    move.l  a6, PHYSTOP.w               ; now change phystop

    pea     relocating_message(pc)      ; relocating message
    move.w  #9, -(sp)
    trap    #1
    addq.w  #6, sp

    move.l  a6, d2
    swap    d2
    move.l  selected_params(pc), a2
    move.w  PARAM_BASE_ADDR_FIELD(a2), d3 ; selected TOS's base high word
    move.w  PARAM_END_ADDR_FIELD(a2), d4 ; end address high word
    move.l  PARAM_LENGTH_FIELD(a2), d5  ; length

    sub.w   d3, d2                      ; phystop is always on round adress

    move.l  a6, a5
    move.l  a6, a4
    add.l   d5, a5                      ; end adr.

    ; get no-reloc table address
    move.l  PARAM_NON_RELOC_ADDR_FIELD(a2), a1  
    moveq   #0, d0

; ---------------------------------------------------------------
; reloc all ROM addresses except no-reloc addresses
; ---------------------------------------------------------------
reloc_loop:
    move.w  (a6), d1

    cmp.w   d3, d1
    blt.s   not_in_rom

    cmp.w   d4, d1
    bge.s   not_in_rom

    cmp.l   (a1), d0                    ; no reloc if equals !
    beq.s   skip_not_relocated

    add.w   d2, d1
    move.w  d1, (a6)
    addq.l  #2, a6
    addq.l  #2, d0

not_in_rom:
    addq.l  #2, a6
    addq.l  #2, d0
    cmp.l   a5, a6
    blt.s   reloc_loop

    ; sign of install version 'check_de_100 - check_de_206'
    move.l  PARAM_INSTALL_SIGN_FIELD(a2), $3F8.w 
    move.l  a4, $3FC.w

    ; Ensure restart of new TOS after warm reset
    move.l  #RESVECTOR_MAGIC, RESVALID.w

    ; reset entry offset
    move.w  PARAM_RESVEC_OFFSET_FIELD(a2), d2  
    ext.l   d2
    move.l  a4, a5
    add.l   d2, a5                      ; point after resvector
    move.l  a5, RESVECTOR.w
    move.l  #MEMVAL3_VALID, MEMVAL3.w   ; This is due TOS 1.00 !

    ; ---------------------------------------------------------------
    ; Patch crc check
    ; ---------------------------------------------------------------

    ; get CRC offset routine start address    
    move.w  PARAM_CRC_START_OFFSET_FIELD(a2), d0  
    ; get crcok routine start offset
    move.w  PARAM_CRC_END_OFFSET_FIELD(a2), d1   
    beq.s   .no_crc                   ; if not 0
    move.l  a4, a0                    ; apply offset to TOS start
    adda.w  d0, a0
    move.w  #$6000, (a0)+             ; patch existing move.l #banksize,d7
    move.w  d1, (a0)+                 ; by bra.w crcok and nop
    move.w  #$4e71, (a0)+             ; ref: https://github.com/th-otto/tos3x/blob/master/bios/startup.S#L1750

.no_crc:

    ; attempt to change Reset vector: Initial PC   
    ; move.l  a4, a0
    ; adda.l  #$30, a0
    ; move.l  a0, $4.w                    ; now change reset to RAMTOS reset

    jmp     (a4)                        ; reset via ramtos!

skip_not_relocated:
    addq.l  #4, a1
    bra.s   not_in_rom

load_error:
    lea     load_err_message(pc), a0
    bsr     show_message

;Back to user
switch_user_mode:
    move.w  #$20, -(sp)
    trap    #1
    addq.w  #6, sp

keywait:
    bsr.s   get_input_key

quit:
    pea     $4C0000
    trap    #1

show_loaderr_msg:
    lea     load_err_message(pc), a0
    bra.s   print_and_wait

show_unsupported_msg:
    lea     unsupported_message(pc), a0
    bra.s   print_and_wait

show_image_not_found_msg:
    lea    not_found_message(pc), a0

print_and_wait:
    bsr.s   show_message
    bra.s   keywait

; ---------------------------------------------------------------
; Routines
; ---------------------------------------------------------------

; ---------------------------------------------------------------
; show_message
; a0 = message ptr
; ---------------------------------------------------------------
show_message:
    pea     (a0)
    move.w  #9, -(sp)
    trap    #1
    addq.w  #6, sp
    rts

; ---------------------------------------------------------------
; get_input_key
; ---------------------------------------------------------------
get_input_key:
    move.w  #1, -(sp)
    trap    #1
    addq.l  #2, sp
    rts

; ---------------------------------------------------------------
; check_installed
; Detecting is already installed in supervisor
; ---------------------------------------------------------------
check_installed:
    cmp.l   #RESVECTOR_MAGIC, RESVALID.w
    seq     is_installed
    rts

; ---------------------------------------------------------------
; load_rom
; ---------------------------------------------------------------
load_rom:
    ifeq _RAMTOS_
    move.l  DTA(pc), d1
    move.l  d1, a1
    lea     30(a1), a1
    endc

    clr.w   error
    clr.w   -(sp)
    ifeq _RAMTOS_
    pea     (a1)
    else
    pea     filename(pc)
    endc

    move.w  #$3D, -(sp)                 ; fopen
    trap    #1
    addq.w  #8, sp

    move.w  d0, handle                  ; handle
    bmi.s   tos_img_not_found           ; TOS.IMG not found

    pea     stack(pc)
    pea     32.w
    move.w  handle(pc), -(sp)
    move.w  #$3F, -(sp)
    trap    #1
    lea     $C(sp), sp

    cmp.l   #32, d0
    bne.s   tos_load_error              ; load error

    move.w  handle(pc), -(sp)
    move.w  #$3E, -(sp)                 ; fclose
    trap    #1
    addq.w  #4, sp

    moveq   #0, d0
    rts

; ---------------------------------------------------------------
; tos_img_not_found 
; ---------------------------------------------------------------
tos_img_not_found:
    moveq   #1, d0
    rts

; ---------------------------------------------------------------
; tos_load_error 
; ---------------------------------------------------------------
tos_load_error:
    moveq   #2, d0
    rts

; ---------------------------------------------------------------
; find_version
; see which version is 
; ---------------------------------------------------------------
find_version:
    lea     stack(pc), a1

    cmp.w   #$0100, 2(a1)
    beq.s   check_de_100

    cmp.w   #$0102, 2(a1)
    beq.s   check_fr_102

    cmp.w   #$0104, 2(a1)
    beq.s   check_uk_104

    cmp.w   #$0206, 2(a1)
    beq     check_tos_206

not_supported:
    moveq   #NOT_SUPPORTED, d0          ; not found supported
    rts

; ---------------------------------------------------------------
; TOS 1.00
; ---------------------------------------------------------------
check_de_100:
    cmp.w   #3, $1c(a1)                 ; is german
    bne.s   check_uk_100

    lea     t1m(pc), a0
    bsr     show_found_TOS_msg
    moveq   #1, d0
    rts

check_uk_100:
    cmp.w   #7, $1c(a1) ;is UK
    bne.s   check_us_100

    lea     t8m(pc), a0
    bsr     show_found_TOS_msg
    moveq   #8, d0
    rts

check_us_100:
    cmp.w   #0, $1c(a1) ;is US
    bne.s   not_supported

    lea     t9m(pc), a0
    bsr     show_found_TOS_msg
    moveq   #9, d0
    rts

; ---------------------------------------------------------------
; TOS 1.02
; not supported yet
; ---------------------------------------------------------------
check_fr_102:
    bra not_supported

; ---------------------------------------------------------------
; TOS 1.04
; ---------------------------------------------------------------
check_uk_104:
    cmp.w   #7, $1c(a1)                 ;is English
    bne.s   check_us_104

    lea     t2m(pc), a0
    bsr     show_found_TOS_msg
    moveq   #2, d0
    rts

check_us_104:
    cmp.w   #0, $1c(a1)
    bne.s   check_de_104

    lea     t7m(pc), a0
    bsr     show_found_TOS_msg
    moveq   #7, d0
    rts

check_de_104:
    cmp.w   #3, $1c(a1)
    bne.s   check_fr_104

    lea     t10m(pc), a0
    bsr     show_found_TOS_msg
    moveq   #10, d0
    rts

check_fr_104:
    cmp.w   #5, $1c(a1)
    bne.s   check_es_104

    lea     t13m(pc), a0
    bsr     show_found_TOS_msg
    moveq   #13, d0
    rts

check_es_104:
    cmp.w   #9, $1c(a1)
    bne.s   check_sw_104

    lea     t14m(pc), a0
    bsr     show_found_TOS_msg
    moveq   #14, d0
    rts

; Swedish 1.04
check_sw_104:
    cmp.w   #$d, $1c(a1)
    bne.s   check_nl_104

    lea     t15m(pc), a0
    bsr     show_found_TOS_msg
    moveq   #15, d0
    rts

; Dutch 1.04
check_nl_104:
    cmp.w   #$1b, $1c(a1)
    bne     not_supported

    lea     t16m(pc), a0
    bsr     show_found_TOS_msg
    moveq   #16, d0
    rts

; ---------------------------------------------------------------
; Patched and original TOS 2.06
; ---------------------------------------------------------------
check_tos_206:
    cmp.w   #7, $1c(a1)                 
    beq.s   check_patchs

; German 2.06
check_de_206:
    cmp.w   #3, $1c(a1)                 
    bne.s   check_us_206

    lea     t3m(pc), a0
    bsr     show_found_TOS_msg
    moveq   #3, d0
    rts

; US 2.06
check_us_206:
    cmp.w   #0, $1c(a1)
    bne.s   check_sw_206

    lea     t6m(pc), a0
    bsr     show_found_TOS_msg
    moveq   #6, d0
    rts

; SW TOS 2.06
check_sw_206:
    cmp.w   #$0d, $1c(a1)
    bne.s   check_fr_206

    lea     t11m(pc), a0
    bsr     show_found_TOS_msg
    moveq   #11, d0
    rts

; Fr TOS 2.06
check_fr_206:
    cmp.w   #$05, $1c(a1)
    bne     not_supported

    lea     t12m(pc), a0
    bsr     show_found_TOS_msg
    moveq   #12, d0
    rts

; ---------------------------------------------------------------
; Further test needed for patched version
; ---------------------------------------------------------------
check_patchs:
    ifeq _RAMTOS_
    move.l  DTA(pc), d1
    move.l  d1, a1
    lea     30(a1), a1
    endc

    clr.w   error
    clr.w   -(sp)

    ifeq _RAMTOS_
    pea     (a1)
    else
    pea     filename(pc)
    endc

    move.w  #$3D, -(sp)                 ; fopen
    trap    #1
    addq.w  #8, sp

    move.w  d0, handle                  ; handle
    bmi.s   on_error                    ; TOS.IMG not found

    clr.w   -(sp)
    move.w  handle(pc), -(sp)
    pea     $1e956
    move.w  #$42, -(sp)                 ; Fseek
    trap    #1
    lea     $a(sp), sp

    pea     stack(pc)
    pea     2.w
    move.w  handle(pc), -(sp)
    move.w  #$3F, -(sp)
    trap    #1
    lea     $C(sp), sp

    cmp.l   #2, d0
    bne.s   on_error                    ; load error

    move.w  handle(pc), -(sp)
    move.w  #$3E, -(sp)                 ; fclose
    trap    #1
    addq.w  #4, sp

    cmp.w   #$00e0, stack               ; is patched
    beq.s   patched_TOS

    lea     t4m(pc), a0
    bsr     show_found_TOS_msg
    moveq   #4, d0
    rts

; ---------------------------------------------------------------
; patched_TOS
; for UK SuperTOS
; ---------------------------------------------------------------
patched_TOS:
    lea     t5m(pc), a0
    bsr     show_found_TOS_msg
    moveq   #5, d0
    rts

; ---------------------------------------------------------------
; on_error
; ---------------------------------------------------------------
on_error:
    bra     not_supported               ; for now

; ---------------------------------------------------------------
; show_found_TOS_msg
; a0 = TOS name message
; ---------------------------------------------------------------
show_found_TOS_msg:
    lea     founc(pc), a2
    addq.w  #1, (a2)
    move.w  (a2), d2
    add.w   #'0', d2

    move.b  d2, founp+2

    move.l  a0, -(sp)               ; save a0

    lea     founp(pc), a0
    bsr     show_message

    move.l  (sp)+, a0               ; restore a0
    bra     show_message

; ---------------------------------------------------------------
; put filename to propr. TOS param. table
; ---------------------------------------------------------------
    ifeq _RAMTOS_
insert_filename:

    ext.l   d0
    mulu    #PARAMS_SIZE, d0
    lea     param1_tos100de-PARAMS_SIZE(pc), a2
    add.l   d0, a2
    move.l  DTA(pc), a1
    lea     30(a1), a1
    moveq   #13, d0

.loop
    move.b  (a1)+, (a2)+
    dbf     d0, .loop
    rts

    endc

; -------------------------------------------------------------
; Messages
; -------------------------------------------------------------
checking_message:
    dc.b    $1b,$45, 'Checking if installed... ', 0

title_message:
    dc.b    $0d,$0a, 'RAMTOS/SELTOS v8 by P. Putnik & Shazz',$0d,$0a,0

search_message:
    dc.b    $0d,$0a, 'Searching ROM-TOS images... ', 0

found_message:
    dc.b    'found:', 0

t1m:    dc.b 'TOS 1.00 German', 0
t8m     dc.b 'TOS 1.00 UK', 0
t9m     dc.b 'TOS 1.00 US', 0
t2m     dc.b 'TOS 1.04 UK', 0
t7m     dc.b 'TOS 1.04 US', 0

t10m    dc.b 'TOS 1.04 German', 0
t13m    dc.b 'TOS 1.04 French', 0
t14m    dc.b 'TOS 1.04 Spanish', 0
t15m    dc.b 'TOS 1.04 Swedish', 0
t16m    dc.b 'TOS 1.04 Dutch', 0

t3m     dc.b 'TOS 2.06 German', 0
t4m     dc.b 'TOS 2.06 UK', 0
t6m     dc.b 'TOS 2.06 US', 0
t11m    dc.b 'TOS 2.06 Swedish', 0
t12m    dc.b 'TOS 2.06 French', 0
t5m     dc.b 39, 'Super', 39, 'TOS 2.06 UK-patched', 0

;Image file name
filename:
    ifeq _RAMTOS_
    dc.b    "*.IMG", 0
    else
    dc.b    "RTOS.IMG", 0
    endc

load_err_message:
    dc.b    $0d,$0a, 'Error while loading!', 0

anyway_message:
    dc.b    $0d,$0a, 'RAMTOS already installed.'
    dc.b    $0d,$0a, 'Load anyway ? ', 0

;Install message
loading_message:
    dc.b    $1b,$45, 'Loading... ', 0

;Relocating message
relocating_message:
    dc.b   'relocating...', 0

;image not found message
not_found_message:
    dc.b    $0d,$0a, 'TOS image not found.', 0

unsupported_message:
    dc.b    $0d,$0a, 'Unsupported TOS image file.', 0

    ifeq _RAMTOS_
selection_message:
    dc.b    $0d,$0a,$0d,$0a, 'select TOS to install  1-'
selection2_message:
    dc.b    '1:', 0
    endc

; -------------------------------------------------------------
; Variables
; -------------------------------------------------------------
founp:
    dc.b    $0d,$0a, "x: ", 0
    even

founc:      dc.w 0
DTA:        ds.l 1
error:      ds.w 1
ftosp:      ds.l 1
fscount:    ds.w 1

is_installed:
    dc.w    0                       ; flag, set to 1 if RAMTOS already installed

handle:
    dc.w    0           

; -------------------------------------------------------------
; parameter table for each TOS
; FileName-14 bytes
; Base address,  end address - just words for compare
; Length - long
; Nonreloc data address - long
; Offset after resetvector - word
; Install sign - long
; crc check start routine offset
; crc check end routine offset
; Total 36 bytes
; -------------------------------------------------------------

;German 1.00
param1_tos100de:
    ds.b    14
    dc.w    $00FC, $00FF
    dc.l    $30000
    dc.l    non_rel_tos100de
    dc.w    $74
    dc.l    $54313030
    dc.w    0
    dc.w    0

;UK 1.04
param2_tos104uk
    ds.b    14
    dc.w    $00FC, $00FF
    dc.l    $30000
    dc.l    non_rel_tos104uk_us
    dc.w    $80
    dc.l    $54313034
    dc.w    0
    dc.w    0

;German 2.06
param3_tos206de:
    ds.b    14
    dc.w    $00E0, $00E4
    dc.l    $40000
    dc.l    non_rel_tos206de
    dc.w    $7e
    dc.l    $54323036
    dc.w    $7fa
    dc.w    $98

;UK 2.06
param4_tos206uk:
    ds.b    14
    dc.w    $00E0, $00E4
    dc.l    $40000
    dc.l    non_rel_tos206us_uk
    dc.w    $7e
    dc.l    $54323036
    dc.w    $7fa
    dc.w    $98

;UK supertos 2.06
param5_tos206uk_super
    ds.b    14
    dc.w    $00E0, $00E4
    dc.l    $40000
    dc.l    non_rel_tos206uk_super
    dc.w    $7e
    dc.l    $54323036
    dc.w    $7fa
    dc.w    $98

;US 2.06
param6_tos206us
    ds.b    14
    dc.w    $00E0, $00E4
    dc.l    $40000
    dc.l    non_rel_tos206us_uk  ;same as UK TOS 2.06
    dc.w    $7e
    dc.l    $54323036
    dc.w    $7fa
    dc.w    $98

;US 1.04
param7_tos104us
    ds.b    14
    dc.w    $00FC, $00FF
    dc.l    $30000
    dc.l    non_rel_tos104uk_us  ;same as UK TOS 1.04 ???
    dc.w    $80
    dc.l    $54313034
    dc.w    0
    dc.w    0

;UK 1.00
param8_tos100uk:
    ds.b    14  ;place for filename
    dc.w    $00FC, $00FF
    dc.l    $30000
    dc.l    non_rel_tos100us_uk
    dc.w    $74
    dc.l    $54313030
    dc.w    0
    dc.w    0

;US 1.00
param9_tos100us:
    ds.b    14  ;place for filename
    dc.w    $00FC, $00FF
    dc.l    $30000
    dc.l    non_rel_tos100us_uk
    dc.w    $74
    dc.l    $54313030
    dc.w    0
    dc.w    0

;German 1.04
param10_tos104de:
    ds.b    14
    dc.w    $00FC, $00FF
    dc.l    $30000
    dc.l    non_rel_tos104de
    dc.w    $80
    dc.l    $54313034
    dc.w    0
    dc.w    0

;Swedish 2.06
param11_tos206sw:
    ds.b    14
    dc.w    $00E0, $00E4
    dc.l    $40000
    dc.l    non_rel_tos206sw
    dc.w    $7e
    dc.l    $54323036
    dc.w    $7fa
    dc.w    $98

;French 2.06
param12_tos206fr
    ds.b    14                 ; FileName-14 bytes
    dc.w    $00E0, $00E4       ; Base address,  end address - just words for compare
    dc.l    $40000             ; Length - long,  265K
    dc.l    non_rel_tos206fr   ; Nonreloc data address - long
    dc.w    $7e                ; Offset after resetvector - word
    dc.l    $54323036          ; Install sign - long
    dc.w    $7fa               ; crc start routine offset
    dc.w    $98                ; crcok start routine offset

; French 1.04
param13_tos104fr
    ds.b    14
    dc.w    $00FC, $00FF
    dc.l    $30000
    dc.l    non_rel_tos104fr
    dc.w    $80
    dc.l    $54313034
    dc.w    0
    dc.w    0

; Spanish 1.04
param14_tos104es
    ds.b    14
    dc.w    $00FC, $00FF
    dc.l    $30000
    dc.l    non_rel_tos104es
    dc.w    $80
    dc.l    $54313034
    dc.w    0
    dc.w    0

; Swedish 1.04
param15_tos104sw
    ds.b    14
    dc.w    $00FC, $00FF
    dc.l    $30000
    dc.l    non_rel_tos104sw
    dc.w    $80
    dc.l    $54313034
    dc.w    0
    dc.w    0

; Dutch 1.04
param16_tos104nl
    ds.b    14
    dc.w    $00FC, $00FF
    dc.l    $30000
    dc.l    non_rel_tos104nl
    dc.w    $80
    dc.l    $54313034
    dc.w    0
    dc.w    0

; -------------------------------------------------------------
; Non-relocating tables
; this are adresses which are not for reloc!
; -------------------------------------------------------------

;German TOS 1.00
non_rel_tos100de:
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

;uk and us tos 1.00
non_rel_tos100us_uk
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

;uk tos 1.04
non_rel_tos104uk_us
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

;german tos 1.04
non_rel_tos104de
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

; french 104
non_rel_tos104fr:
    dc.l    $117e               ; => $117e,  move.b  #$fe, (a2)+ [known in some TOS]
    dc.l    $1514               ; => $1414, bsr.w  $fc1612 [known in some TOS]
    dc.l    $3a4c               ; => $3a4c, and.b  #$fd, d0 [known in some TOS]
    dc.l    $3f2a               ; => $3f0c, beq.w  $fc4028 [new!]
    dc.l    $5626               ; => $5608, bra.w  $fc5724 [new!]
    dc.l    $6184               ; => $6166, bra.w  $fc6280 [new!]
    dc.l    $860c               ; => $85ee, bne.w  $fc870a [new!]
    dc.l    $892c               ; => $890e, add.l  #$fe, d6 [new!]
    dc.l    $15c94              ; => $15c76
    dc.l    $1714c              ; => $1712e
    dc.l    $1749e              ; => $17480
    dc.l    $18456              ; => $18438
    dc.l    $1ac12              ; => $1abf4
    dc.l    $25238              ; => $2521a
    dc.l    $272ec              ; => $272ca
    dc.l    $288e8              ; => $288ca
    dc.l    $29694              ; => $29676
    dc.l    $297d0              ; => $297b2
    dc.l    $29b70              ; => $29b52
    dc.l    $29d26              ; => $29d08
    dc.l    $2a5d0              ; => $2a5b2
    dc.l    $2a6d0              ; => $2a6b2
    dc.l    $2a6ce              ; manually added
    dc.l    $2ec00              ; manually added
    dc.l    0

; swedish 104
non_rel_tos104sw:
    dc.l    $117e               ; => $117e,  move.b  #$fe, (a2)+ [known in some TOS]
    dc.l    $1514               ; => $1414, bsr.w  $fc1612 [known in some TOS]
    dc.l    $3f2a               ; => $3f0c, beq.w  $fc4028 [new!]
    dc.l    $5626               ; => $5608, bra.w  $fc5724 [new!]
    dc.l    $6184               ; => $6166, bra.w  $fc6280 [new!]
    dc.l    $860c               ; => $85ee, bne.w  $fc870a [new!]
    dc.l    $892c               ; => $890e, add.l  #$fe, d6 [new!]
    dc.l    $15c94              ; => $15c76
    dc.l    $1714c              ; => $1712e
    dc.l    $1749e              ; => $17480
    dc.l    $18456              ; => $18438
    dc.l    $1ac12              ; => $1abf4
    dc.l    $25238              ; => $2521a
    dc.l    $272ec              ; => $272ca
    dc.l    $288e8              ; => $288ca
    dc.l    $29694              ; => $29676
    dc.l    $297d0              ; => $297b2
    dc.l    $29b70              ; => $29b52
    dc.l    $29d26              ; => $29d08
    dc.l    $2a5d0              ; => $2a5b2
    dc.l    $2a6d0              ; => $2a6b2
    dc.l    $2a6ce              ; manually added
    dc.l    $2ea1e              ; manually added
    dc.l    0

; Spanish 1.04
non_rel_tos104es:
    dc.l    $117e               ; => $117e 
    dc.l    $1514               ; => $1514
    dc.l    $3a4c               ; => $3a4c
    dc.l    $3f38               ; => $3f2a
    dc.l    $5634               ; => $5626
    dc.l    $6192               ; => $6184
    dc.l    $861a               ; => $860c
    dc.l    $893a               ; => $892c
    dc.l    $15ca2              ; => $15c94
    dc.l    $1715a              ; => $1714c
    dc.l    $174aa              ; => $1749e
    dc.l    $18464              ; => $18456
    dc.l    $1ac20              ; => $1ac12
    dc.l    $2538a              ; => $25238
    dc.l    $272fa              ; => $272ec
    dc.l    $288f6              ; => $288e8
    dc.l    $296a2              ; => $29694
    dc.l    $297de              ; => $297d0
    dc.l    $297de              ; => $29b70
    dc.l    $29d34              ; => $29d26
    dc.l    $2a5de              ; => $2a5d0
    dc.l    $2a6de              ; => $2a6d0
    dc.l    $2a6dc              ; => $2a6ce
    dc.l    $2eb8c              ; => $2ec00
    dc.l    0    

; Dutch TOS 1.04
non_rel_tos104nl:
    dc.l    $117e
    dc.l    $1514
    dc.l    $3a4c
    dc.l    $3eb2 ; manually added $3f2a fr, looks ok
    dc.l    $55ae
    dc.l    $610c
    dc.l    $8594
    dc.l    $88b4 ; manually added $892c f, looks ok
    dc.l    $15c18
    dc.l    $170d0 ; manually added $1714c fr, looks ok
    dc.l    $17422 ; manually added $1749e fr
    dc.l    $18402
    dc.l    $1abbe
    dc.l    $25328
    dc.l    $27298
    dc.l    $28894
    dc.l    $29640
    dc.l    $2977c
    dc.l    $29b1c
    dc.l    $29cd2
    dc.l    $2a57c
    dc.l    $2a67a
    dc.l    $2a67c
    dc.l    $2eab4

;uk and us tos 2.06
non_rel_tos206us_uk
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
non_rel_tos206uk_super:
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

;swedish tos 2.06
non_rel_tos206sw:
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

;german tos 2.06
non_rel_tos206de
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

; french 206
non_rel_tos206fr:
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

new_phystop:
    ds.l   1

new_memtop:
    ds.l   1

required_space:
    ds.l   1

selected_params
    ds.l    1

    ifeq _RAMTOS_
TOS_list:
    ds.w    MAX_FILES       ; max MAX_FILES (9) TOS in list
    endc

    ds.b    500             ;place for stack

stack:
    ds.b    485000          ;place for load & screen & decomp
