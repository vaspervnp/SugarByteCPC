; menu.asm — το μενού, όπως το assets/preview/mockup_menu.png
;
; Τίτλος και μπορντούρα (draw_frame), τέσσερα πιάτα, ο δείκτης αριστερά από το
; επιλεγμένο, μια σειρά από candies στο πόδι.
;
;   PLAY       η πίστα cur_level από την αρχή
;   LEVEL NN   SPACE: «CODE 0000» — ←→ ψηφίο, ↑↓ τιμή, SPACE δέχεται, ESC ακυρώνει
;   SOUND ON   SPACE: μουσική ναι/όχι
;   SCORES     οι καλύτεροι πόντοι και τα αστέρια κάθε πίστας

MENU_ITEMS      equ 4
MENU_Y0         equ 48              ; γραμμή του πρώτου πιάτου
MENU_STEP       equ 36
MENU_TILES      equ 6               ; πιάτο: αριστερό, 4 μέσης, δεξί
MENU_XB         equ 24              ; byte του πιάτου (pixel 48)
MENU_PLATE_WB   equ MENU_TILES*MENU_W
MENU_PTR_XB     equ MENU_XB-MENU_W-4    ; ο δείκτης (pixel 24)
MENU_CANDY_Y    equ MENU_Y0+(MENU_ITEMS-1)*MENU_STEP+MENU_H+4
MENU_CREDIT_Y   equ FOOT_Y-11       ; πάνω από το πόδι: εκεί οι ρίγες κινούνται με raster
MI_PLAY         equ 0
MI_LEVELS       equ 1
MI_SOUND        equ 2
MI_SCORES       equ 3

; Η εκκίνηση: όλες οι μεταβλητές (και η μόνιμη πρόοδος) στο μηδέν, και το μενού.
menu_start:
        ld hl,board
        ld de,board+1
        ld bc,snd_start-board-1
        ld (hl),0
        ldir
        ld a,BOARD_Y
        ld (clip_y),a
        ld (seed),hl            ; ό,τι να 'ναι, αρκεί να μην είναι 0
        ld a,r
        ld (seed),a
        call menu_enter
        ld hl,VOICE_SUGARBYTE
        ld de,VOICE_SUGARBYTE_LEN
        jp say

; Από την αρχή ή από το παιχνίδι (ESC): ζωγραφίζει όλη την οθόνη του μενού.
menu_enter:
        ld a,S_MENU
        ld (state),a
        xor a
        ld (anim_k),a
        ld a,BOARD_Y            ; το εσωτερικό μαύρο
        ld b,FOOT_Y-BOARD_Y
        ld c,BORDER_XB
        ld de,(SCR_WB-2*BORDER_XB)*256+PB_BLACK
        call fill_rect
        call draw_frame
        xor a
.plates push af
        call draw_plate
        pop af
        inc a
        cp MENU_ITEMS
        jr c,.plates
        ld c,0                  ; τα έξι χρώματα, πάνω στο πόδι
.candy  push bc
        ld a,c
        add a,a
        add a,a
        add a,c
        add a,a                 ; * 10 bytes
        add a,18
        ld b,c
        ld c,a
        ld a,b
        ld b,MENU_CANDY_Y
        call draw_candy_at
        pop bc
        inc c
        ld a,c
        cp 6
        jr c,.candy
        ld a,MENU_CREDIT_Y      ; οι υπογραφές
        ld (digit_y),a
        ld hl,txt_credit
        ld c,(SCR_WB-CREDIT_LEN*2)/2
        call draw_text
        jp draw_pointer

txt_credit:
        db "REVIVE8BIT - 2026 - VASPER",0
CREDIT_LEN      equ $-txt_credit-1

; A = επιλογή: το πιάτο της και η ετικέτα της.
draw_plate:
        ld (menu_tmp),a
        call menu_item_y
        call line_addr
        ld bc,MENU_XB
        add hl,bc
        ld b,0                  ; B = πλακάκι
.tile   push bc
        push hl
        ld de,menu_gfx+0*MENU_SZ        ; plate_m
        ld a,b
        or a
        jr nz,.notl
        ld de,menu_gfx+1*MENU_SZ        ; plate_l
.notl   cp MENU_TILES-1
        jr nz,.notr
        ld de,menu_gfx+2*MENU_SZ        ; plate_r
.notr   ld bc,MENU_W*256+MENU_H
        call blit_opaque
        pop hl
        ld bc,MENU_W
        add hl,bc
        pop bc
        inc b
        ld a,b
        cp MENU_TILES
        jr c,.tile
        ; η ετικέτα, στο κέντρο
        ld a,(menu_tmp)
        call menu_label         ; HL = κείμενο σε menu_buf
        push hl
        ld b,0                  ; μήκος
.len    ld a,(hl)
        or a
        jr z,.lend
        inc hl
        inc b
        jr .len
.lend   ld a,MENU_PLATE_WB      ; x = MENU_XB + (πλάτος - 2 * μήκος) / 2
        sub b
        sub b
        srl a
        add a,MENU_XB
        ld c,a
        ld a,(menu_tmp)
        call menu_item_y
        add a,8
        ld (digit_y),a
        pop hl
        jp draw_text

; A = επιλογή -> A = η γραμμή του πιάτου της
menu_item_y:
        ld b,a                  ; * 36
        add a,a
        add a,a
        add a,a
        add a,b
        add a,a
        add a,a
        add a,MENU_Y0
        ret
        assert MENU_STEP == 36

; A = επιλογή -> HL = η ετικέτα της (στο menu_buf αν αλλάζει)
menu_label:
        or a
        ld hl,txt_play
        ret z
        dec a
        jr z,.levels
        dec a
        jr z,.sound
        ld hl,txt_scores
        ret
.sound  ld hl,txt_sound_on
        ld a,(mus_on)
        or a
        ret nz
        ld hl,txt_sound_off
        ret
.levels ld a,(state)
        cp S_CODE
        jr z,.code
        ld hl,txt_level_nn      ; «LEVEL NN»
        ld de,menu_buf
        ld bc,6
        ldir
        ld a,(cur_level)
        inc a
        call bin2bcd
        call put_bcd_digits
        jr .end
.code   ld hl,txt_code          ; «CODE dddd» — το ψηφίο που αλλάζει αναβοσβήνει
        ld de,menu_buf
        ld bc,5
        ldir
        ld hl,code_dig
        ld b,0
.dig    ld a,(hl)
        add a,"0"
        ld c,a
        ld a,(code_pos)
        cp b
        jr nz,.show
        ld a,(anim_k)
        and 8
        jr z,.show
        ld c," "
.show   ld a,c
        ld (de),a
        inc de
        inc hl
        inc b
        ld a,b
        cp 4
        jr c,.dig
.end    xor a
        ld (de),a
        ld hl,menu_buf
        ret

; A = BCD -> δύο χαρακτήρες στο (DE)
put_bcd_digits:
        push af
        rrca
        rrca
        rrca
        rrca
        and 15
        add a,"0"
        ld (de),a
        inc de
        pop af
        and 15
        add a,"0"
        ld (de),a
        inc de
        ret

txt_play:       db "PLAY",0
txt_level_nn:   db "LEVEL "
txt_code:       db "CODE "
txt_sound_on:   db "SOUND ON",0
txt_sound_off:  db "SOUND OFF",0
txt_scores:     db "SCORES",0

; Ο δείκτης δίπλα στο επιλεγμένο, στη φάση του (οι ρίγες «τρέχουν»).
draw_pointer:
        ld a,(menu_sel)
        call menu_item_y
        call line_addr
        ld bc,MENU_PTR_XB
        add hl,bc
        ld de,menu_gfx+3*MENU_SZ        ; pointer1
        ld a,(anim_k)
        and 8
        jr z,.p1
        ld de,menu_gfx+4*MENU_SZ        ; pointer2
.p1     ld bc,MENU_W*256+MENU_H
        jp blit_opaque

; A = επιλογή: σβήνει τον δείκτη της
erase_pointer:
        call menu_item_y
        ld b,MENU_H
        ld c,MENU_PTR_XB
        ld de,MENU_W*256+PB_BLACK
        jp fill_rect

st_menu:
        ld hl,anim_k
        inc (hl)
        ld a,(hl)
        and 7
        call z,draw_pointer
        call get_dir
        and J_UP|J_DOWN
        jr z,.fire
        ld b,a
        ld a,(menu_sel)
        push bc
        push af
        call erase_pointer
        pop af
        pop bc
        bit 0,b
        jr z,.down
        dec a
        jp p,.set
        ld a,MENU_ITEMS-1
.down   bit 1,b
        jr z,.set
        inc a
        cp MENU_ITEMS
        jr c,.set
        xor a
.set    ld (menu_sel),a
        call draw_pointer
        ld hl,sfx_select
        call play_sfx
.fire   ld a,(joy_edge)
        and J_FIRE
        ret z
        ld a,(menu_sel)
        or a
        jr nz,.notplay
        ld a,(anim_k)           ; ο χρόνος στο μενού ανακατεύει τον σπόρο
        ld hl,seed
        xor (hl)
        ld (hl),a
        pop hl                  ; PLAY: έξω από το step_state, στο παιχνίδι
        jp game_new
.notplay
        dec a
        jr nz,.notlevels
        jp start_code           ; LEVELS: ο κωδικός
.notlevels
        dec a
        jr nz,scores_enter      ; SCORES
        call toggle_music       ; SOUND
        ld a,MI_SOUND
        jp draw_plate

; ---------------------------------------------------------------------------
; SCORES: σελίδες των 20 πιστών σε δύο στήλες — πίστα, καλύτεροι πόντοι,
; αστέρια. ←→ αλλάζει σελίδα, SPACE / ESC πίσω στο μενού.
SCORES_Y0       equ BOARD_Y+16
SCORES_DY       equ 18
SCORES_PER_PAGE equ 20
SCORES_PAGES    equ floor((NLEVELS+SCORES_PER_PAGE-1)/SCORES_PER_PAGE)   ; το rasm διαιρεί με δεκαδικά
        assert SCORES_PAGES <= 9
scores_enter:
        xor a
        ld (scores_pg),a
        ld a,S_SCORES
        ld (state),a
scores_draw:
        ld a,BOARD_Y
        ld b,FOOT_Y-BOARD_Y
        ld c,BORDER_XB
        ld de,(SCR_WB-2*BORDER_XB)*256+PB_BLACK
        call fill_rect
        call draw_frame         ; καθαρό πόδι, χωρίς τα candies του μενού
        ld hl,txt_scores        ; «SCORES 1/3»
        ld de,menu_buf
        ld bc,6
        ldir
        ex de,hl
        ld (hl),' '
        inc hl
        ld a,(scores_pg)
        add a,'1'
        ld (hl),a
        inc hl
        ld (hl),'/'
        inc hl
        ld (hl),SCORES_PAGES+'0'
        inc hl
        ld (hl),0
        ld a,BOARD_Y+4
        ld (digit_y),a
        ld hl,menu_buf
        ld c,(SCR_WB-10*2)/2
        call draw_text
        call .first             ; A = η πρώτη πίστα της σελίδας
.lv     ld (menu_tmp),a
        ld b,a
        call .first
        ld e,a
        ld a,b
        sub e                   ; A = θέση στη σελίδα, 0-19
        ld c,BORDER_XB+4        ; στήλη και γραμμή
        cp 10
        jr c,.col
        sub 10
        ld c,BORDER_XB+4+40
.col    ld e,a
        add a,a
        add a,a
        add a,a
        add a,e
        add a,a                 ; * 18
        add a,SCORES_Y0
        ld (digit_y),a
        ld a,(menu_tmp)         ; «NN»
        inc a
        call bin2bcd
        ld (menu_buf),a
        ld hl,menu_buf
        ld b,1
        call draw_bcd
        inc c
        inc c
        ld a,(menu_tmp)         ; οι πόντοι
        add a,a
        add a,a
        ld hl,best
        call add_hl_a
        ld b,3
        call draw_bcd           ; HL μένει στα αστέρια
        ld e,(hl)               ; τα αστέρια, μικρά
        ld b,3
.star   ld a,HUD_ICONS+1
        dec e
        jp p,.on
        ld a,HUD_ICONS+2
.on     inc c
        push de
        call draw_glyph
        pop de
        inc c
        djnz .star
        call .first
        add a,SCORES_PER_PAGE-1
        ld b,a
        ld a,(menu_tmp)
        cp b                    ; η τελευταία της σελίδας
        ret z
        inc a
        cp NLEVELS
        jr c,.lv
        ret
.first  ld a,(scores_pg)        ; * 20
        add a,a
        add a,a
        ld e,a
        add a,a
        add a,a
        add a,e
        ret

st_scores:
        ld a,(joy_edge)
        and J_FIRE|J_ESC
        jp nz,menu_enter
        call get_dir
        ld b,a
        ld a,(scores_pg)
        ld c,a
        bit 2,b                 ; J_LEFT
        jr z,.nleft
        or a
        jr z,.nleft
        dec a
.nleft  bit 3,b                 ; J_RIGHT
        jr z,.nright
        cp SCORES_PAGES-1
        jr nc,.nright
        inc a
.nright cp c
        ret z
        ld (scores_pg),a
        jp scores_draw

; ---------------------------------------------------------------------------
; Στη νίκη: οι πόντοι και τα αστέρια της πίστας, αν είναι οι καλύτεροι ώς τώρα.
record_best:
        ld a,(cur_level)
        add a,a
        add a,a
        ld hl,best
        call add_hl_a
        push hl
        ld de,score             ; BCD, MSB πρώτο: σύγκριση byte-byte
        ld b,3
.cmp    ld a,(de)
        cp (hl)
        jr c,.stars             ; μικρότεροι
        jr nz,.copy             ; μεγαλύτεροι
        inc de
        inc hl
        djnz .cmp
        jr .stars
.copy   pop hl
        push hl
        ld de,score
        ex de,hl
        ld bc,3
        ldir
.stars  pop hl
        inc hl
        inc hl
        inc hl
        ld a,(win_n)
        cp (hl)
        ret c
        ld (hl),a
        ret
