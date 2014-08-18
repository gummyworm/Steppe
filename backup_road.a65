
;******************************************************************************
!zone Road
;******************************************************************************
DrawRoad
;
    ldx #96
-   lda x_map,x
    and #$07
    tay
    lda fill_tab_l,y
.dst=*+1
    sta char,x
    dex
    bpl -
    rts

fill_tab_l !byte $01,$03,$07,$0f,$1f,$3f,$7f,$ff
fill_tab_r !byte $80,$c0,$e0,$f0,$f8,$fc,$fe,$ff
;******************************************************************************
CalcRoad
; 
.line = temp0
.ddx = temp1
    ; foreach line from bottom to top
    ldx #$00
.l0
    ; if z_map[line] < segment0.pos
    lda z_map,x
    cmp .seg0_pos
    tya
    bcs +
    ; DX = segment1.dx
    lda .seg1_dx
    bne .cont
    ; else DX = segment0.dx
+   lda .seg0_dx
    clc
    ; endif
.cont
    ; DDX += DX
    adc .ddx
    sta .ddx
    ; X += DDX
    adc x_tab,x
    ; x_map[line] = X
    sta x_tab,x
    inx 
    cpx #96
    bne .l0
    ; endforeach

; update segments
    dec seg_speed
    bne .done
    ; move up the segments
    inc seg0
    inc seg0
    inc seg1
    inc seg1
.done   
    rts

seg0    !byte 1 ; the upper segment
seg1    !byte 0 ; the bottom segment
; the countdown before segment motion
seg_speed !byte 0
; position in the map
seg_pos !byte 0
; this represents the track
segmap  !fill 40
; a map of the Z value for each scanline 
z_map   !fill 96
; a map of X-offsets for each line of the track
x_map   !fill 96


delay12 !byte $c9
delay11 !byte $c9
delay10 !byte $c9
delay9  !byte $c9
delay8  !byte $c9

