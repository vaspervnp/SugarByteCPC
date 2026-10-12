; hud.asm — το πλαίσιο και το HUD, όπως το assets/preview/mockup_screen.png
;
; Όλα αδιαφανή: ψηφία και σύμβολα από το hud_gfx (4x8), κεφαλαία, χάρακας και
; μπάρα από το text_gfx (4x8), εικονίδια 8x16 από το icons_gfx, τίτλος και
; μπορντούρα από το menu.bin (plan.md §3.6, §4.5).

; --- οι θέσεις του HUD (bytes από το HUD_XB, γραμμές από το HUD_Y) ---------
HUD_SCORE_ICON_Y equ HUD_Y+6            ; βάζο + πόντοι
HUD_MOVES_ICON_Y equ HUD_Y+28           ; βέλη + κινήσεις, λουκέτο + κωδικός
HUD_TEXT_DY     equ 4                   ; το κείμενο δίπλα σε εικονίδιο 8x16
HUD_RULE1_Y     equ HUD_Y+48
HUD_GOAL_Y      equ HUD_Y+58            ; στόχοι: θέσεις των 30 γραμμών
HUD_GOAL_DY     equ 30
HUD_LEVEL_Y     equ HUD_GOAL_Y+2*HUD_GOAL_DY+8
HUD_RULE2_Y     equ HUD_Y+150
HUD_STARS_Y     equ HUD_Y+158
HUD_BAR_Y       equ HUD_Y+178
HUD_BAR_SEG     equ 13                  ; κομμάτια του σωλήνα ανάμεσα στα καπάκια

HUD_ICON_X      equ HUD_XB+1
HUD_NUM_X       equ HUD_XB+6
HUD_CODE_ICON_X equ HUD_XB+17
HUD_CODE_X      equ HUD_XB+22
HUD_GOAL_ICON_X equ HUD_XB+2
HUD_GOAL_NUM_X  equ HUD_XB+10

; ---------------------------------------------------------------------------
; Ο τίτλος, η μπορντούρα δεξιά-αριστερά και το πόδι (plan.md §4.5).
draw_frame:
        ld a,TITLE_Y
        call line_addr
        ld de,title_gfx
        ld bc,TITLE_W*256+TITLE_H
        call blit_opaque
        ld a,BOARD_Y            ; τα πλαϊνά: 8 πλακάκια το καθένα
.side   push af
        call line_addr
        push hl
        ld de,border_gfx+0*BORDER_SZ
        ld bc,BORDER_W*256+BORDER_H
        call blit_opaque
        pop hl
        ld de,RBORDER_XB
        add hl,de
        ld de,border_gfx+1*BORDER_SZ
        ld bc,BORDER_W*256+BORDER_H
        call blit_opaque
        pop af
        add a,BORDER_H
        cp FOOT_Y
        jr c,.side
        ld c,0                  ; το πόδι: γωνία, 10 πλακάκια, γωνία
.foot   ld a,FOOT_Y
        call line_addr
        ld b,0
        add hl,bc
        ld de,border_gfx+2*BORDER_SZ
        ld a,c
        or a
        jr z,.corner
        cp RBORDER_XB
        jr nz,.edge
.corner ld de,border_gfx+3*BORDER_SZ
.edge   push bc
        ld bc,BORDER_W*256+BORDER_H
        call blit_opaque
        pop bc
        ld a,c
        add a,BORDER_W
        ld c,a
        cp SCR_WB
        jr c,.foot
        ret

; HL = οθόνη, DE = πηγή, B = bytes ανά γραμμή, C = γραμμές. Αδιαφανές.
blit_opaque:
        ld a,b
        ld (.w+1),a
.row    push bc
        push hl
        ex de,hl
.w      ld bc,0
        ldir
        ex de,hl
        pop hl
        call next_line_hl
        pop bc
        dec c
        jr nz,.row
        ret

; A = εικονίδιο (ICON_*), C = byte, B = γραμμή: 8x16. Δεν πειράζει BC.
draw_icon:
        push bc
        add a,a                 ; * 64
        add a,a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        ld de,icons_gfx
        add hl,de
        ex de,hl
        ld a,b
        call line_addr
        ld b,0
        add hl,bc
        ld bc,ICONS_W*256+ICONS_H
        call blit_opaque
        pop bc
        ret

; ---------------------------------------------------------------------------
; Το HUD, μία φορά στην αρχή της πίστας.
hud_init:
        ld a,HUD_Y              ; φόντο
        ld b,ROWS*CELL_H
        ld c,HUD_XB
        ld de,HUD_WB*256+PB_BLUE
        call fill_rect
        ld a,HUD_Y              ; η ραφή με το ταμπλό
        ld b,ROWS*CELL_H
        ld c,HUD_XB
        ld de,#0100+PB_GREY_BLUE
        call fill_rect
        ld a,ICON_SCORE
        ld bc,HUD_SCORE_ICON_Y*256+HUD_ICON_X
        call draw_icon
        ld a,ICON_MOVES
        ld bc,HUD_MOVES_ICON_Y*256+HUD_ICON_X
        call draw_icon
        ld a,HUD_RULE1_Y
        call hud_rule
        ld a,HUD_RULE2_Y
        call hud_rule
        ld a,HUD_BAR_Y          ; τα καπάκια του σωλήνα
        ld (digit_y),a
        ld a,TEXT_BAR+0
        ld c,HUD_XB+2
        call draw_text_glyph
        ld a,TEXT_BAR+3
        ld c,HUD_XB+2+2*(HUD_BAR_SEG+1)
        call draw_text_glyph
        ld a,(cur_level)
        call hud_show_code
        call hud_goals_init
        ld a,1
        ld (hud_dirty),a
        ; fall through

; Ό,τι αλλάζει — μόνο όταν άλλαξε.
hud_update:
        ld a,(hud_dirty)
        or a
        ret z
        xor a
        ld (hud_dirty),a
        ld a,HUD_SCORE_ICON_Y+HUD_TEXT_DY
        ld (digit_y),a
        ld hl,score
        ld b,3
        ld c,HUD_NUM_X
        call draw_bcd
        ld a,HUD_MOVES_ICON_Y+HUD_TEXT_DY
        ld (digit_y),a
        ld hl,moves
        ld b,1
        ld c,HUD_NUM_X
        call draw_bcd
        call hud_goals_update
        call hud_stars
        jp hud_bar

; A = γραμμή: ο χάρακας από ζαχαρωτό σε όλο το πλάτος.
hud_rule:
        ld (digit_y),a
        ld c,HUD_XB+1
.l      ld a,TEXT_RULE
        call draw_text_glyph
        inc c
        inc c
        ld a,c
        cp HUD_XB+HUD_WB-1
        jr c,.l
        ret

; Τα τρία αστέρια: γεμάτα όσα κερδήθηκαν ώς τώρα.
hud_stars:
        call stars_now
        ld e,a
        ld c,HUD_XB+3
        ld b,3
.l      push bc
        ld a,ICON_STAR_ON
        dec e
        jp p,.on
        ld a,ICON_STAR_OFF
.on     ld b,HUD_STARS_Y
        push de
        call draw_icon
        pop de
        pop bc
        ld a,c
        add a,10
        ld c,a
        djnz .l
        ret

; Ο σωλήνας προόδου: γεμάτος ώς τους πόντους των 3 αστεριών.
hud_bar:
        call progress
        ld e,a
        ld a,HUD_BAR_Y
        ld (digit_y),a
        ld c,HUD_XB+4
        ld b,HUD_BAR_SEG
.l      ld a,TEXT_BAR+2         ; γεμάτο
        dec e
        jp p,.full
        ld a,TEXT_BAR+1         ; άδειο
.full   push de
        call draw_text_glyph
        pop de
        inc c
        inc c
        djnz .l
        ret

; -> A = κομμάτια του σωλήνα (0..13): πόντοι * 13 / πόντοι 3 αστεριών.
progress:
        ld hl,score             ; πόντοι / 100, δυαδικά
        call bcd4_bin
        push hl
        ld hl,lv_star3
        call bcd4_bin
        ex de,hl                ; DE = όριο 3 αστεριών
        pop hl                  ; HL = πόντοι
        or a
        sbc hl,de
        ld a,HUD_BAR_SEG
        ret nc                  ; έφτασε: γεμάτος
        add hl,de
        ld b,h                  ; HL = πόντοι * 13
        ld c,l
        add hl,hl
        add hl,bc
        add hl,hl
        add hl,hl
        add hl,bc
        ld b,h
        ld c,l                  ; BC = πόντοι * 13
        ld hl,0
        xor a
.l      add hl,de               ; κάθε κομμάτι = ένα ακόμα όριο/13
        push hl
        or a
        sbc hl,bc
        pop hl
        ret nc
        inc a
        jr .l

; HL = 2 bytes BCD (MSB πρώτο) -> HL = δυαδικό 0..9999
bcd4_bin:
        ld a,(hl)
        inc hl
        push hl
        call bcd2bin
        ld l,a                  ; * 100 = * 64 + * 32 + * 4
        ld h,0
        add hl,hl
        add hl,hl
        ld d,h
        ld e,l                  ; DE = * 4
        add hl,hl
        add hl,hl
        add hl,hl
        push hl                 ; * 32
        add hl,hl               ; * 64
        add hl,de
        pop de
        add hl,de
        ex de,hl
        pop hl
        ld a,(hl)
        call bcd2bin
        ld l,a
        ld h,0
        add hl,de
        ret

; ---------------------------------------------------------------------------
; Οι στόχοι της πίστας: ένα εικονίδιο ή candy και «× NN» ή ο στόχος πόντων.
; Κάτω τους, «LEVEL NN».
hud_goals_init:
        ld a,(lv_goal)
        or a
        jr nz,.notscore
        ld a,ICON_SCORE         ; πόντοι: το βάζο και ο στόχος «NNNN00»
        ld bc,(HUD_GOAL_Y+4)*256+HUD_GOAL_ICON_X
        call draw_icon
        ld a,HUD_GOAL_Y+8
        ld (digit_y),a
        ld hl,lv_star1
        ld b,2
        ld c,HUD_GOAL_NUM_X
        call draw_bcd
        xor a
        call draw_glyph
        inc c
        inc c
        xor a
        call draw_glyph
        jr .level
.notscore
        cp G_ENDLESS
        jr z,.level
        cp G_INGREDIENTS
        jr z,.ingr
        ld a,ICON_JELLY         ; ζελέ
        ld bc,(HUD_GOAL_Y+4)*256+HUD_GOAL_ICON_X
        call draw_icon
        ld a,HUD_GOAL_Y+8
        call hud_times
        ld a,(lv_goal)
        cp G_BOTH
        jr nz,.level
        ld a,HUD_GOAL_Y+HUD_GOAL_DY
        jr .cherry
.ingr   ld a,HUD_GOAL_Y
.cherry push af                 ; υλικά: ένα κεράσι
        call line_addr
        ld bc,HUD_GOAL_ICON_X
        add hl,bc
        ld a,CANDY_INGREDIENT
        push hl
        ld hl,candy_ptr
        call ptr_lookup
        pop hl
        ld a,CELL_H
        call blit_masked
        pop af
        add a,8
        call hud_times
.level  ld a,HUD_LEVEL_Y        ; LEVEL NN
        ld (digit_y),a
        ld hl,txt_level
        ld c,HUD_XB+4
        call draw_text
        inc c
        inc c
        ld a,(cur_level)
        inc a
        call bin2bcd
        ld (lv_number),a
        ld hl,lv_number
        ld b,1
        jp draw_bcd

txt_level:
        db "LEVEL",0

; A = γραμμή: «×» δίπλα στο εικονίδιο στόχου
hud_times:
        ld (digit_y),a
        ld a,HUD_SYMBOLS+2
        ld c,HUD_GOAL_NUM_X
        jp draw_glyph

hud_goals_update:
        ld a,(lv_goal)
        or a
        ret z
        cp G_ENDLESS
        ret z
        cp G_INGREDIENTS
        jr z,.ingr
        call count_jelly        ; ζελέ που μένουν
        call bin2bcd
        ld (lv_number),a
        ld a,HUD_GOAL_Y+8
        ld (digit_y),a
        ld hl,lv_number
        ld b,1
        ld c,HUD_GOAL_NUM_X+2
        call draw_bcd
        ld a,(lv_goal)
        cp G_BOTH
        ret nz
        ld a,HUD_GOAL_Y+HUD_GOAL_DY+8
        jr .ingr2
.ingr   ld a,HUD_GOAL_Y+8
.ingr2  ld (digit_y),a
        ld hl,ingr_left
        ld b,1
        ld c,HUD_GOAL_NUM_X+2
        jp draw_bcd

; ---------------------------------------------------------------------------
; Κείμενο 4x8

; HL = BCD, B = bytes, C = πρώτο byte οθόνης, digit_y = γραμμή.
; Το C μένει μετά το τελευταίο ψηφίο.
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

; HL = κείμενο με 0 στο τέλος (A-Z, 0-9, κενό, x / :), C = byte, digit_y.
; Το C μένει μετά τον τελευταίο χαρακτήρα.
draw_text:
.l      ld a,(hl)
        or a
        ret z
        inc hl
        push hl
        call draw_char
        pop hl
        inc c
        inc c
        jr .l

; A = χαρακτήρας, C = byte, digit_y = γραμμή. Δεν πειράζει BC.
draw_char:
        cp " "
        ret z
        ld e,HUD_SYMBOLS+2
        cp "x"
        jr z,.sym
        ld e,HUD_SYMBOLS+0
        cp ":"
        jr z,.sym
        ld e,HUD_SYMBOLS+1
        cp "/"
        jr z,.sym
        cp "-"
        jr z,.dash
        cp "A"
        jr nc,.letter
        sub "0"                 ; ψηφίο
        jr draw_glyph
.letter sub "A"                 ; κεφαλαίο
        jr draw_text_glyph
.sym    ld a,e
        jr draw_glyph
.dash   push bc                 ; η παύλα: δεν υπάρχει στα γραφικά, τρία pixels
        ld a,(digit_y)          ; άσπρα στη μέση των κεφαλαίων
        ld b,HUD_H
        ld de,HUD_W*256+PB_BLACK
        call fill_rect
        pop bc
        ld a,(digit_y)
        add a,4
        call line_addr
        ld b,0
        add hl,bc
        ld (hl),PB_WHITE
        inc hl
        ld (hl),PB_WHITE_L
        ret

; A = καρέ του text_gfx (TEXT_*), C = byte, digit_y. Δεν πειράζει BC, HL.
draw_text_glyph:
        push hl
        ld de,text_gfx
        jr glyph

; A = καρέ του hud_gfx, C = byte οθόνης, digit_y = γραμμή. Δεν πειράζει BC, HL.
draw_glyph:
        push hl
        ld de,hud_gfx
glyph   push bc
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,hl
        add hl,de
        ex de,hl
        ld a,(digit_y)
        call line_addr
        ld b,0
        add hl,bc
        call blit_hud
        pop bc
        pop hl
        ret
