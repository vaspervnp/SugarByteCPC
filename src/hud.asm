; hud.asm — το πλαίσιο δεξιά: πόντοι, κινήσεις (plan.md §9.3)

; Το πλαίσιο, μία φορά στην αρχή.
hud_init:
        xor a                   ; φόντο
        ld b,200
        ld c,HUD_XB
        ld de,(80-HUD_XB)*256+PB_BLUE
        call fill_rect
        xor a                   ; η ραφή με το ταμπλό
        ld b,200
        ld c,HUD_XB
        ld de,#0100+PB_GREY_BLUE
        call fill_rect
        ld a,2                  ; πάνω και κάτω γραμμή
        ld b,1
        ld c,HUD_XB
        ld de,(80-HUD_XB)*256+PB_GREY
        call fill_rect
        ld a,197
        ld b,1
        ld c,HUD_XB
        ld de,(80-HUD_XB)*256+PB_GREY
        call fill_rect
        ld a,36                 ; χωρίστρα κάτω από πόντους/κινήσεις
        ld b,1
        ld c,HUD_XB+2
        ld de,(80-HUD_XB-4)*256+PB_GREY
        call fill_rect

        ld a,HUD_SCORE_Y
        ld (digit_y),a
        ld a,HUD_ICONS+1        ; αστέρι: πόντοι
        ld c,HUD_ICON_XB
        call draw_glyph
        ld a,HUD_MOVES_Y
        ld (digit_y),a
        ld a,HUD_ICONS+0        ; βέλη: κινήσεις
        ld c,HUD_ICON_XB
        call draw_glyph
        call hud_goal_init
        ld a,1
        ld (hud_dirty),a
        ; fall through

; Τα ψηφία, μόνο όταν άλλαξαν.
hud_update:
        ld a,(hud_dirty)
        or a
        ret z
        xor a
        ld (hud_dirty),a
        call hud_goal_update
        ld a,HUD_SCORE_Y
        ld (digit_y),a
        ld hl,score
        ld b,3
        ld c,HUD_DIGIT_XB
        call draw_bcd
        ld a,HUD_MOVES_Y
        ld (digit_y),a
        ld hl,moves
        ld b,1
        ld c,HUD_DIGIT_XB
        ; fall through

; HL = BCD, B = bytes, C = πρώτο byte οθόνης, digit_y = γραμμή
draw_bcd:
.l      ld a,(hl)
        rrca
        rrca
        rrca
        rrca
        and 15
        call draw_glyph
        inc c
        inc c
        ld a,(hl)
        and 15
        call draw_glyph
        inc c
        inc c
        inc hl
        djnz .l
        ret

; A = καρέ του hud_gfx, C = byte οθόνης, digit_y = γραμμή. Δεν πειράζει BC, HL.
draw_glyph:
        push bc
        push hl
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,hud_gfx
        add hl,de
        ex de,hl
        ld a,(digit_y)
        call line_addr
        ld b,0
        add hl,bc
        call blit_hud
        pop hl
        pop bc
        ret
