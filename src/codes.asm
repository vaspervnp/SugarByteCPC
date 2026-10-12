; codes.asm — η πρόοδος με κωδικούς πίστας
;
; Κάθε πίστα έχει έναν κωδικό 4 ψηφίων: CODE_FIRST + πίστα * CODE_STEP, σε BCD
; mod 10.000 (tools/levels.py).
; Το HUD δείχνει πάντα τον κωδικό της τρέχουσας πίστας, και στη νίκη της
; επόμενης. Στο μενού, LEVELS: «CODE 0000» — ←→ ψηφίο, ↑↓ αλλάζει, SPACE
; δέχεται, ESC ακυρώνει.

; A = πίστα: το λουκέτο και ο κωδικός της στο HUD.
hud_show_code:
        call level_code
        ld hl,menu_buf
        ld (hl),d
        inc hl
        ld (hl),e
        dec hl
        push hl
        ld a,ICON_LOCK
        ld bc,HUD_MOVES_ICON_Y*256+HUD_CODE_ICON_X
        call draw_icon
        ld a,HUD_MOVES_ICON_Y+HUD_TEXT_DY
        ld (digit_y),a
        pop hl
        ld b,2
        ld c,HUD_CODE_X
        jp draw_bcd

; A = πίστα (από 0) -> DE = ο κωδικός της σε BCD. Πειράζει B.
level_code:
        ld de,CODE_FIRST
        or a
        ret z
        ld b,a
.add    ld a,e
        add a,CODE_STEP&#FF
        daa
        ld e,a
        ld a,d
        adc a,CODE_STEP>>8
        daa
        ld d,a
        djnz .add
        ret

; Από το μενού: η εισαγωγή αρχίζει από 0000, πάνω στο πιάτο LEVELS.
start_code:
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
        ld a,(hl)
        and 7
        call z,draw_code_entry  ; το ψηφίο αναβοσβήνει
        ld a,(joy_edge)
        and J_ESC
        jr nz,.cancel
        ld a,(joy_edge)
        and J_FIRE
        jr nz,.enter
        call get_dir
        or a
        ret z
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
.cancel ld a,S_MENU
        ld (state),a
        jp draw_code_entry
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
        ld c,0
.find   push de
        ld a,c
        call level_code
        pop hl
        ld a,h
        cp d
        jr nz,.nfound
        ld a,l
        cp e
        jr z,.found
.nfound ex de,hl
        inc c
        ld a,c
        cp NLEVELS
        jr c,.find
        ld hl,sfx_bad           ; κανένας τέτοιος κωδικός
        jp play_sfx
.found  ld a,c
        ld (cur_level),a
        ld a,S_MENU
        ld (state),a
        ld hl,sfx_collect
        call play_sfx
        ; fall through: το πιάτο ξαναγράφει «LEVEL NN»

; Το πιάτο LEVELS: «CODE dddd» όσο γράφεται ο κωδικός, αλλιώς «LEVEL NN».
draw_code_entry:
        ld a,MI_LEVELS
        jp draw_plate
