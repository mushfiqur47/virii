
title   Display Registers
page    65,131
include struct.mac
;
; regdisp.asm
;
; Displays all the 8086 registers on the right side of the screen.
; The registers are sampled and displayed roughly 18 times per second.
; Toggle on and off by holding down both shift keys.
; To use with the monochromatic monitor, DISP_BUFFER should be equated
; to 0B000H.  In addition, the code in 'outchar' that is involved in
; waiting for horizontal retrace to write a character can be removed.
; This program is loaded into memory and stays resident.  It is activated by
; each clock tick (about 18/sec) and is a cpu hog (at least with the
; graphics monitor; about 40% of the cpu is consumed when using the
; graphics monitor due mainly to the busy waits used in writing to the
; screen).
;
; Installation:
;   masm regdisp;
;   link regdisp;       (should get 'No STACK segment' message)
;   exe2bin regdisp
;   copy regdisp.bin regdisp.com
;
DISP_BUFFER     equ     0B000H
LINE_SIZE       equ     19
ON      equ     049  ;   254 is alternate
OFF     equ     032  ;   250
RED     equ     4
GREEN   equ     2
BLUE    equ     1

xx      STRUC
    s_di    dw      ?
    s_si    dw      ?
    s_es    dw      ?
    s_ds    dw      ?
    s_dx    dw      ?
    s_cx    dw      ?
    s_bx    dw      ?
    s_ax    dw      ?
    s_sp    dw      ?
    s_bp    dw      ?
    s_pc    dw      ?
    s_cs    dw      ?
    s_fl    dw      ?
xx      ends

REGOUT  MACRO   LINE, REG_NAME, REG_VAL, ATT
.xlist
        mov     si,offset REG_NAME
        mov     di,160*LINE - LINE_SIZE*2
        mov     bh,ATT
        call    w_label
        mov     si,offset rptr
        mov     dx,REG_VAL
        call    w_bits
.list
        endm

ERASE   MACRO   LINE
.xlist
        mov     cx,LINE_SIZE
        mov     di,160*LINE - LINE_SIZE*2
rep     stosw
.list
        endm

abs     segment at 0
zero    proc    far
zero    endp
abs     ends

cseg    segment
        org     100H
        assume  cs:cseg
        assume  ds:cseg
start   proc    near
        jmp     initial
;
; data block for display

d_fl    db      'FL:'
d_si    db      'SI:'
d_di    db      'DI:'
d_ss    db      'SS:'
d_es    db      'ES:'
d_ds    db      'DS:'
d_sp    db      'SP:'
d_bp    db      'BP:'
d_dx    db      'DX:'
d_cx    db      'CX:'
d_bx    db      'BX:'
d_ax    db      'AX:'
display_cs  equ $
        db      'CS:'
display_pc  equ $
        db      'PC:'
rptr    db      RED,RED,RED,RED
        db      RED+GREEN,RED+GREEN,RED+GREEN,RED+GREEN
        db      RED,RED,RED,RED
        db      RED+GREEN,RED+GREEN,RED+GREEN,RED+GREEN
fts     db      0
display_flag db 0

intr    equ     $
        sti
        push    bp
        mov     bp,sp
        add     bp,8
        push    bp              ; contents of sp before interrupt
        push    ax
        push    bx
        push    cx
        push    dx
        push    ds
        push    es
        push    si
        push    di
        mov     bp,sp
        push    cs
        pop     ds                      ; address the data
;       mov     al,020H
;       out     020H,al
        cld
        mov     ax,40H                  ; BIOS data area
        mov     es,ax
        mov     cx,es:[17H]             ; KB_FLAG
        and     cl,11B
        xor     cl,11B
        .if     z                       ; left and right shift keys pressed
            cmp     fts,0
            jnz     once_already
            xor     display_flag,1          ; toggle the display flag
            .if     nz
                call    set_up
            .endif
            mov     fts,1                   ; set the flag
            jmp     once_already
        .endif
        mov     fts,0                   ; reset the flag
once_already:
        .ifs    display_flag,1
            jmp     exit
        .endif
testloc equ     $
        mov     ax,DISP_BUFFER          ; display buffer address
        mov     es,ax                   ; setup for STOSW

        REGOUT  1,display_pc,[bp].s_pc,BLUE
        REGOUT  2,display_cs,[bp].s_cs,BLUE+GREEN
        REGOUT  3,d_ss,ss,BLUE+GREEN
        REGOUT  4,d_es,[bp].s_es,BLUE+GREEN
        REGOUT  5,d_ds,[bp].s_ds,BLUE+GREEN
        REGOUT  6,d_sp,[bp].s_sp,RED
        REGOUT  7,d_bp,[bp].s_bp,RED
        REGOUT  8,d_si,[bp].s_si,GREEN
        REGOUT  9,d_di,[bp].s_di,GREEN
        REGOUT  10,d_ax,[bp].s_ax,BLUE+RED
        REGOUT  11,d_bx,[bp].s_bx,BLUE+RED
        REGOUT  12,d_cx,[bp].s_cx,BLUE+RED
        REGOUT  13,d_dx,[bp].s_dx,BLUE+RED
        REGOUT  14,d_fl,[bp].s_fl,BLUE

exit:   pop     di
        pop     si
        pop     es
        pop     ds
        pop     dx
        pop     cx
        pop     bx
        pop     ax
        pop     bp              ;dummy
        pop     bp
jmploc: jmp     zero
;
;
;   output character and attribute in bx to word at es:[di].  dx, ax are destroyed.
;   di is incremented by 2
outchar:
        push    dx
        mov     dx,03DAH
if disp_buffer-0b000H                   ; test for graphics buffer
        in      al,dx
        .ifc    al,8            ; if in the midst of vertical retrace, do the write
            .repeat
                in      al,dx       ; wait for partial horiz retrace to finish
                test    al,1
            .until  z
            .repeat
                in      al,dx       ; wait for start of horiz or vert retrace
                test    al,9
            .until  nz
        .endif
endif
        mov     ax,bx
        stosw
        pop     dx
        ret

w_label:
        mov     cx,3
        .repeat
            mov     bl,[si]
            call    outchar
            inc     si
        .until  loop
        ret

w_bits:
        mov     cx,16
        .repeat
            shl     dx,1
            .if     c
                mov     bl,ON
            .else
                mov     bl,OFF
            .endif
            mov     bh,[si]
            call    outchar
            inc     si
        .until  loop
        ret

set_up:
        mov     ax,DISP_BUFFER          ; display buffer address
        mov     es,ax
        mov     ax,700H+' '             ; blank out display buffer

        ERASE   1
        ERASE   2
        ERASE   3
        ERASE   4
        ERASE   5
        ERASE   6
        ERASE   7
        ERASE   8
        ERASE   9
        ERASE   10
        ERASE   11
        ERASE   12
        ERASE   13
        ERASE   14
        ret

initial:
        push    ds
        xor     ax,ax
        mov     ds,ax                   ; address interrupt vectors
        mov     si,ds:[20H]             ; pickup TIMER interrupt values
        mov     cx,ds:[22H]
        mov     ds,cx                   ; entry to interrupt code
        mov     bx,cs:testloc
        .if     <word ptr [si+testloc-intr]> e bx
            pop     ds
            int     20H                     ; exit
        .endif
        pop     ds
        mov     word ptr jmploc+1,si
        mov     word ptr jmploc+3,cx
        mov     dx,offset intr
        mov     ax,2508H                ; setup new timer call
        int     21H
        mov     dx,offset initial
        int     27H                     ; terminal and stay resident
start   endp
cseg    ends
        end     start


                                                                                           