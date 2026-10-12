; codes.asm — η πρόοδος με κωδικούς πίστας
;
; Κάθε πίστα έχει έναν κωδικό 4 ψηφίων (level_codes, από το tools/levels.py).
; Το HUD δείχνει πάντα τον κωδικό της τρέχουσας πίστας, και στη νίκη της
; επόμενης. ESC: εισαγωγή κωδικού — ←→ ψηφίο, ↑↓ αλλάζει, SPACE πάει στην
; πίστα, ESC ακυρώνει.

HUD_CODE_Y      equ 176

; A = πίστα: το λουκέτο και ο κωδικός της στο HUD.
hud_show_code:
        add a,a
        ld hl,level_codes
        call add_hl_a
        push hl
        ld a,HUD_CODE_Y
        ld (digit_y),a
        ld a,HUD_ICONS+4
        ld c,HUD_ICON_XB
        call draw_glyph
        pop hl
        ld b,2
        ld c,HUD_DIGIT_XB
        jp draw_bcd

; ESC από IDLE, OVER ή WIN: αρχίζει η εισαγωγή, από 0000.
start_code:
        ld a,(state)
        ld (code_prev),a
        xor a
        ld (code_pos),a
        ld (anim_k),a
        ld hl,code_dig
        ld b,4
.clr    ld (hl),a
        inc hl
        djnz .clr
        ld a,S_CODE
        ld (state),a
        ld hl,sfx_select
        call play_sfx
        jp draw_code_entry

st_code:
        ld hl,anim_k
        inc (hl)
        ld a,(joy_edge)
        and J_ESC
        jr nz,.cancel
        ld a,(joy_edge)
        and J_FIRE
        jr nz,.enter
        call get_dir
        or a
        jp z,draw_code_entry
        ld b,a
        ld a,(code_pos)
        bit 2,b                 ; J_LEFT
        jr z,.nleft
        dec a
.nleft  bit 3,b                 ; J_RIGHT
        jr z,.nright
        inc a
.nright and 3
        ld (code_pos),a
        ld hl,code_dig
        call add_hl_a
        ld a,(hl)
        bit 0,b                 ; J_UP: +1
        jr z,.nup
        inc a
        cp 10
        jr c,.nup
        xor a
.nup    bit 1,b                 ; J_DOWN: -1
        jr z,.ndown
        dec a
        jp p,.ndown
        ld a,9
.ndown  ld (hl),a
        xor a                   ; το ψηφίο φαίνεται αμέσως
        ld (anim_k),a
        jp draw_code_entry
.cancel ld a,(code_prev)
        ld (state),a
        or a                    ; S_IDLE: ο δείκτης ξανά
        ld a,(cursor)
        call z,mark_dirty
        ld a,(cur_level)
        jp hud_show_code
.enter  ld a,(code_dig)         ; τα 4 ψηφία σε 2 bytes BCD
        rlca
        rlca
        rlca
        rlca
        ld hl,code_dig+1
        or (hl)
        ld d,a
        inc hl
        ld a,(hl)
        rlca
        rlca
        rlca
        rlca
        inc hl
        or (hl)
        ld e,a
        ld hl,level_codes
        ld b,0
.find   ld a,(hl)
        inc hl
        cp d
        ld a,(hl)
        inc hl
        jr nz,.nfound
        cp e
        jr z,.found
.nfound inc b
        ld a,b
        cp NLEVELS
        jr c,.find
        ld hl,sfx_bad           ; κανένας τέτοιος κωδικός
        jp play_sfx
.found  ld a,b
        ld (cur_level),a
        pop hl                  ; έξω από το step_state: η πίστα από την αρχή
        jp game_new

; Τα 4 ψηφία· αυτό που αλλάζει αναβοσβήνει.
draw_code_entry:
        ld a,HUD_CODE_Y
        ld (digit_y),a
        ld c,HUD_DIGIT_XB
        ld hl,code_dig
        ld b,0
.dig    ld a,(code_pos)
        cp b
        jr nz,.show
        ld a,(anim_k)
        and 8
        jr z,.show
        push bc                 ; σβηστό: σκέτο φόντο
        push hl
        ld a,HUD_CODE_Y
        ld b,HUD_H
        ld de,HUD_W*256+PB_BLUE
        call fill_rect
        pop hl
        pop bc
        jr .next
.show   ld a,(hl)
        call draw_glyph
.next   inc hl
        inc c
        inc c
        inc b
        ld a,b
        cp 4
        jr c,.dig
        ret
