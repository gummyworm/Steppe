!to "caravan.prg",cbm
;******************************************************************************
;      ____  __   _____   __  __        __  __  ___     _
;     / __/ /  | |     | |  \ \ \      / / /  ||   \   | |
;    / /   /   | |   __| |   \ \ \    / / /   || |\ \  | |
;   / /   / /| | |   \   | |\ \ \ \  / / / /| || | \ \ | |
;  / /_  / / | | | |\ \  | | \ \ \ \/ / / / | || |  \ \| |
; /____//_/  |_| |_| \_\ |_|  \_\ \__/ /_/  |_||_|   \___|
;
;
;Bryce Wilson
;July 29, 2014
;******************************************************************************
;******************************************************************************
;CONSTANTS
;
DATA            = $1900            ; the start of the data
CODE            = $1001            ; the start of the code
CHARMEM         = $1c00            ; the start of UDG
SCREEN          = $1e00            ; the start of the screen
COLORMEM        = $9600            ; the start of color memory

START_LINE      = $20                     ; line to trigger raster interrupt on
LINES           = 261                     ; 312 for PAL
CYCLES_PER_LINE = 65                      ; 71 for PAL
TIMER_VALUE = LINES * CYCLES_PER_LINE - 2 ; timer value for stable raster int.

TERRAIN_START_LINE = START_LINE ; the first line of the terrain
SKY_COLOR = $03|$08             ; color to return to after drawing the terrain

SPR0            = CHARMEM       ; the location of the 1st sprite 
SPR1            = CHARMEM+60    ; the location of the 2nd sprite
SPR2            = CHARMEM+120   ; the location of the 3rd sprite

;******************************************************************************
;ZEROPAGE
;
vec0 =$a0
vec1 =$a2
vec2 =$a4
temp0=$f0
temp1=$f1
temp2=$f2
temp3=$f3
temp4=$f4
temp5=$f5
SpriteBuffer=$00
ShadowBuffer=$20

;******************************************************************************
*=DATA
joy_x !byte 0
joy_y !byte 0
joy_f !byte 0

Sprite0
!byte $00,$ff,$ff,$00
!byte $00,$ff,$ff,$00
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
!byte $00,$ff,$ff,$00
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
Sprite1
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
Sprite2
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff
!byte $ff,$ff,$ff,$ff

;******************************************************************************
*=CODE
!word $100b
!word 2014
!byte $9e
!text "4109",0
!word 0

init
        ;lda #$50
        ;sta $1e00
        ;lda #$00
        ;sta $9000
        ;lda #(26|$80)
        ;sta $9002
        lda #$04|$80    ; X columns, odd screen page ($1e00)
        sta $9002
        lda #$02<<1     ; X rows, 8x8 chars
        sta $9003
        lda #$ff        ; chars @ $1c000, screen @ $1e00
        sta $9005
    
        ; set up bitmap
        ldy #$01:ldx #$00
        stx $1e00:sty $9600
        inx:stx $1e04:sty $9601
        inx:stx $1e01:sty $9602
        inx:stx $1e05:sty $9603
        inx:stx $1e02:sty $9604
        inx:stx $1e06:sty $9605
        inx:stx $1e03:sty $9606
        inx:stx $1e07:sty $9607

        ldx #4*16
        lda #$00
-       sta $1c00,x
        dex
        bpl -
        ldx #$07
        ldy #$00
        jsr SpriteOn


    ; init the stable raster irq
    lda #$7f
    sta $912e       ; disable/ack interrupts
    sta $912d
    sta $911e       ; disable NMI's (restore key)
sync:
; sync with screen
    ldx #START_LINE ; wait until this raster (*2)
-   cpx $9004
    bne -           ; inaccuracy is 7 clocks at here (processor is 2-9 cycles
                    ; after $9004 change
    ldy #$09
    bit $24
-   ldx $9004
    txa
    bit $24

    bit $24
    ldx #21
    
    dex
    bne *-1         ; spend some time (so the whole loop will be 2 raster lines)
    cmp $9004       
    bcs *+2
    dey
    bne -
; 6 cycles have passed since last $9004 change we are now on line 2*(START_LINE+9)

timers:
; initialize the timers
    lda #$40        ; enable timer A free run on both VIAs
    sta $911b
    sta $912b

    lda #<TIMER_VALUE
    ldx #>TIMER_VALUE
    sta $9116       ; load the timer low byte latches
    sta $9126

    ldy #$06        ; delay to get effect @ right spot
    dey
    bne *-1
    bit $24
    
    stx $9125       ; start IRQ timer A
                    ; 6560-101: 65 cycles from $9004 change
                    ; 6561-101: 77 cycles from $9004 change

    ldy #10         ; spend some time (1+5*9+4 = 55 cycles)
    dey             ; before starting the reference timer
    bne *-1
    stx $9115       ; start the reference timer
pointers:
    lda #<irq       ; set the raster IRQ routine pointer
    sta $0314
    lda #>irq
    sta $0315
    lda #$c0
    sta $912e       ; enable timer A underflow interrupts


main_loop
        lda #$0a
        cmp $9004
        bne *-3
        lda #$08
        sta scroll_stride
read_joy
        lda #$00
        sta $9113
        lda #$7f
        sta $9122
        lda $9111
        sta temp0

        lda #$04
        bit temp0       ; up?
        bne +
        ldx #5          ; double stride
        stx scroll_stride
+       asl
        bit temp0       ; down?
        bne +
        ldx #2          ; slow stride
        stx scroll_stride
+       asl
        bit temp0       ; left?
        bne +
        dec joy_x
+       asl
        and temp0       ; fire?
        sta joy_f
        bit $9120       ; right?
        bpl +
        inc joy_x
+       jmp main_loop


;******************************************************************************
delayx
; delay for 6 to 50 cycles
; jsr delayx + (delay_cycles
;
!fill   (50-8),$c9
delay7  !byte $24
delay6  nop
delay4  sta $900f
        rts

!align 255,0
;******************************************************************************
!zone IRQ
irq
.sky = temp0
        lda $9114   ; get the NMI timer A

        cmp #$08    ; are we more than 7 cycles ahead of time?
        bcc +
        pha         ; yes, spend 8 extra cycles
        pla
        and #$07    ; and reset high bit
+       cmp #$04
        bcc +
        bit $24     ; waste 4 cycles
        and #$03
+       cmp #$02    ; spend the rest of the cycles
        bcs *+2
        bcs *+2
        lsr
        bcs *+2     ; now it has taken 82 cycles from the beginnig of the IRQ

        ;need to spend 28 cycles to get to start of line 
        lda ground_color2 ; 4
        sta ground_col2   ; 4
        lda ground_color1 ;4
        sta ground_col1   ; 4
        lda #(sky_delays-sky_colors-1)          ; 2
        sta .sky          ; 3
        nop

; foreach raster line
do_line
line_count=*+1
        ldx sky_delays  ; 4
line_color=*+1
        lda #$44|$08    ; 2
        sta $900f       ; 4

        ; burn (65 * (line_count-1) - (65 - 33)) cycles
        ; there needs to be 65*x cycles between each $900f write
        dex             ; 2
        bmi +           ; 3/2
-       ldy #10         ; 2 + 9*5 + 4 = 51
        dey
        bne *-1
        lda $9004       ; 4
        bmi .done       ; 2
        bit $00         ; 3
        dex             ; 2
        bpl -           ; 3/2
        nop             ; 2
+       
        ; we now have burned 65x + 5 cycles since the last $900f write
        ; 65 - 5 = 60 cylces left til next $900f write

        ; 15 cycles of delay
        pha:pla
        nop:nop:nop

        ; 31 cycles
        inc line_count  ; 6

        ldx .sky        ; 3 are we drawing the sky?
        beq .update_ground     ; 3/2
.update_sky
        lda sky_colors,x ; 4
        bit $00         ; 3
        dec .sky        ; 5
        bpl .update_col ; 3
.update_ground       
ground_col1=*+1
        ldx #$77        ; 2
ground_col2=*+1
        lda #$55        ; 2
        sta ground_col1 ; 4
        stx ground_col2 ; 4
        nop             ; 2
.update_col 
        sta line_color  ; 4

        lda $9004       ; 4
        bpl do_line     ; 3

; update the delay values to produce a scrolling effect
.done
        lda #$10 ;joy_y
        sta $9001
        lda #<sky_delays
        sta line_count

        lda scroll_stride
        beq .quit
        dec .scroll_speed
        bne .quit
        lda #$00
scroll_speed=*+1
        lda #1
        sta .scroll_speed
        ldx scroll_entry
        inc delay_tab,x
        txa
        cpx #delay_tab_len
        bcc +

        lda scroll_start
        inc scroll_start
        bcs ++

+       adc scroll_stride
++      sta scroll_entry
        bpl +
        lda #delay_tab_len
        bne ++
+       cmp #delay_tab_len
        bcc .quit
        lda #$00
++      sta scroll_entry
        ldx #delay_tab_len-1
-       lda delay_tab-1,x
        sta delay_tab,x
        dex
        bpl -
        inx
        stx delay_tab
        lda ground_color1
        ldx ground_color2
        sta ground_color2
        stx ground_color1
.quit
        lda $9004
        bmi *-3
        lda #SKY_COLOR
        sta $900f
        sta line_color
        jmp $eabf

; if !0, scroll the background
scroll_start    !byte 0
scroll_stride   !byte 0
.scroll_speed   !byte 1
scroll_entry    !byte 0

!align 255,0

; color table for each line of the sky
sky_colors
!byte $00
!byte $04
!byte $03
!byte $01
!byte $03
!byte $01
!byte $03
!byte $01
!byte $03
!byte $01
!byte $03
!byte $01
!byte $03
!byte $01
!byte $03
!byte $01
!byte $03
!byte $01
!byte $03
!byte $01

; delay table for each line of the sky
sky_delays
!byte $04,$02,$0f,$01,$06,$01,$01,$01,$01,$00,$02,$00,$01,$02,$00,$01,$00,$00,$00,$00

; a table for how long (in lines) to display the corresponding color
delay_tab
!byte 0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2,2,3,3,3,3,3,3,3,3,3
delay_tab_len = *-delay_tab

;a table for the line colors at each background line
ground_color1 !byte $77|$08
ground_color2 !byte $55|$08

weapon_x !byte 0
weapon_y !byte 0

;a table for the weapon colors at each scanline of the weapon
weapon_tab
!byte $77|$08
!byte $77|$08
!byte $
; a table for how long (cycles) to display each line 
weapon_tab_len
!byte 2

;******************************************************************************
GenerateShadow
        ; clear sprite/shadow buffer
        lda #$00
        ldy #64
-       sta SpriteBuffer,y
        dey
        bpl -

        ldx #15
        ldy #15
; double a line of the sprite
.doublesprite
; double the MSB
--      lda #$10
        sta temp1
-       lda test_sprite,y
        and temp1
        beq .unfilled2
.filled2
        sec
        ror SpriteBuffer+16,x
        sec
        ror SpriteBuffer+16,x
        sec
        ror ShadowBuffer+16,x
        sec
        ror ShadowBuffer+16,x
        bne +
.unfilled2
        clc
        ror SpriteBuffer+16,x
        ror SpriteBuffer+16,x
        ror ShadowBuffer+16,x
        ror ShadowBuffer+16,x
+       asl temp1
        bne -
;double the LSB
--      lda #$08
        sta temp1
-       lda test_sprite,y
        and temp1
        beq .unfilled
.filled sec
        rol SpriteBuffer,x
        sec
        rol SpriteBuffer,x
        sec
        rol ShadowBuffer,x
        sec
        rol ShadowBuffer,x
        bne +
.unfilled
        clc
        rol SpriteBuffer,x
        rol SpriteBuffer,x
        rol ShadowBuffer,x
        rol ShadowBuffer,x
        bpl +
+       lsr temp1
        bne -
; next data
        dey
        dex
        bpl .doublesprite
        rts

test_sprite
!byte $f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0
!byte $f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0
!byte $f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0
!byte $f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0
!byte $f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0

;******************************************************************************
PlotMC
;plots a multicolor point on the bitmap
;.X: the X coordinate of the plot
;.Y: the Y coordinate of the plot
;.A: the color to plot (<COLOR_BORDER, <COLOR_CHAR, <COLOR_AUX)
        sta .tab
        txa
        asl 
        asl
        rol temp0+1
        asl
        rol temp0+1
        sta temp0
        txa
        and #$03
        tax
        lda (temp0),y
        and .mask_tab,x
.tab=*+2
        ora .tab,x
        sta (temp0),y
        rts
.mask_tab
!byte $c0,$30,$0c,$03
.mc_tab
COLOR_BORDER = *
!byte $40,$10,$40,$10   ; %01 table
COLOR_CHAR = *
!byte $80,$20,$08,$02   ; %10 table
COLOR_AUX = *
!byte $c0,$30,$0c,$03   ; %11 table

;******************************************************************************
!zone SpriteDrawing
SpriteOn
;
.next       = temp0
.scroll     = temp3
.prev       = temp4
.cnt        = temp5
.next_buff  = $00
SPRITE_BM   = $1c00
        ; scroll = (7 - (X & 7))
        txa
        and #$07
        cmp #$07
        beq .pre
        sta .scroll
        asl                     ; * 3
        clc
        adc .scroll
        tax

        ; replace "LSR:ROR ZP,X" with "JMP .blit"
        lda #$4c                ; JMP
        sta .shsmc,x
        lda #<.put      
        sta .shsmc+1,x
        lda #>.put
        sta .shsmc+2,x
.pre
        ; setup src and dst vectors
        ldx #<Sprite0
        ldy #>Sprite0
        stx .src
        sty .src+1
        ldx #<SPRITE_BM
        ldy #>SPRITE_BM
        stx .dst
        sty .dst+1

        ; clear next buffer (TODO: better way?)
        ldy #15
        lda #$00
-       sta .next_buff,y
        dey
        bpl -

        lda #$00
        ldy #$04

        ; blit loop
.blit   ldx #15         ; sprite_w_times_h

.l0     lda .next_buff,x
        sta .prev
        ; get a row of pixels and shift them
.src=*+1:lda $0000,x
.shsmc  lsr
        ror .next_buff,x
        lsr
        ror .next_buff,x
        lsr
        ror .next_buff,x
        lsr
        ror .next_buff,x
        lsr
        ror .next_buff,x
        lsr
        ror .next_buff,x
        lsr
        ror .next_buff,x

        ; copy to sprite bitmap
.put    ora .prev
.dst=*+1:sta $0000,x
        dex
        bpl .l0

        ; update vectors
        lda .src
        adc #16
        sta .src
        lda .dst
        adc #16
        sta .dst

        ; if (--.Y != 0) loop
        dey
        bne .blit

        ; restore smc
        ldx .scroll
        lda #$4a                ; LSR
        sta .shsmc,x
        lda #$76                ; ROR ZPG,X
        sta .shsmc+1,x
        lda #.next_buff
        sta .shsmc+2,x
        
        ; done
        rts
