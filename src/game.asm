; game.asm — ο βρόχος και η μηχανή καταστάσεων (plan.md §7)

game_new:
        ld hl,vars_start        ; όλες οι μεταβλητές στο μηδέν, εκτός από τον σπόρο
        ld de,(seed)
        push de
        ld b,vars_end-vars_start
        xor a
.clr    ld (hl),a
        inc hl
        djnz .clr
        ld hl,board
        ld b,0
.clr2   ld (hl),a
        inc hl
        djnz .clr2
        pop de
        ld (seed),de
        ld a,6
        ld (ncolours),a
        ld a,START_MOVES
        ld (moves),a
        ld a,#FF
        ld (sel),a
        ld a,3*COLS+3
        ld (cursor),a
        call fill_board
        call draw_board_all
        call hud_init
        ; S_IDLE == 0 από τον μηδενισμό

main_loop:
        call wait_vbl
        call read_input
        call render_dirty
        call step_state
        call hud_update
        jr main_loop

step_state:
        ld a,(state)
        add a,a
        ld hl,state_tab
        add a,l
        ld l,a
        jr nc,.nc
        inc h
.nc     ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        jp (hl)

state_tab:
        dw st_idle, st_swap, st_swap, st_clear, st_fall, st_over

; ---------------------------------------------------------------------------
; IDLE: ο δείκτης κινείται και αναβοσβήνει, το SPACE επιλέγει και ανταλλάσσει.
st_idle:
        ld hl,blink_t
        inc (hl)
        ld a,(hl)
        and 15
        jr nz,.move
        ld a,(cursor)
        call mark_dirty
.move   call get_dir
        or a
        jr z,.fire
        ld b,a
        ld a,(cursor)
        ld c,a
        bit 0,b                 ; J_UP
        jr z,.nup
        cp COLS
        jr c,.nup
        sub COLS
.nup    bit 1,b                 ; J_DOWN
        jr z,.ndown
        cp COLS*(ROWS-1)
        jr nc,.ndown
        add a,COLS
.ndown  ld d,a
        bit 2,b                 ; J_LEFT
        jr z,.nleft
        and 7
        jr z,.nleft
        dec d
.nleft  bit 3,b                 ; J_RIGHT
        jr z,.nright
        ld a,d
        and 7
        cp 7
        jr z,.nright
        inc d
.nright ld a,d
        cp c
        jr z,.fire
        ld (cursor),a
        call mark_dirty
        ld a,c
        call mark_dirty
        xor a                   ; ο δείκτης φαίνεται αμέσως μόλις κινηθεί
        ld (blink_t),a
.fire   ld a,(joy_edge)
        and J_FIRE
        ret z
        ld a,(cursor)
        ld c,a
        ld a,(sel)
        cp #FF
        jr nz,.has_sel
        ld a,c                  ; πρώτη επιλογή
        ld (sel),a
        jp mark_dirty
.has_sel
        ld b,a
        cp c
        jr nz,.other
        ld a,#FF                ; ξανά στο ίδιο: ακύρωση
        ld (sel),a
        ld a,c
        jp mark_dirty
.other  call adjacent
        jr c,.swap
        ld a,c                  ; μακριά: η επιλογή μετακομίζει
        ld (sel),a
        call mark_dirty
        ld a,b
        jp mark_dirty
.swap   ld a,b
        ld (swap_a),a
        ld a,c
        ld (swap_b),a
        ld a,#FF
        ld (sel),a
        xor a
        ld (anim_k),a
        ld a,S_SWAP
        ld (state),a
        ret

; B, C = δύο κελιά. Carry αν είναι γείτονες.
adjacent:
        ld a,c
        sub b
        cp COLS
        jr z,.yes
        cp -COLS
        jr z,.yes
        cp 1
        jr z,.right
        cp -1
        jr z,.left
        or a
        ret
.right  ld a,b
        and 7
        cp 7
        jr z,.no
        scf
        ret
.left   ld a,b
        and 7
        jr z,.no
.yes    scf
        ret
.no     or a
        ret

; ---------------------------------------------------------------------------
; SWAP / UNSWAP: τα δύο candies γλιστράνε το ένα στη θέση του άλλου.
st_swap:
        ld hl,anim_k
        inc (hl)
        call swap_draw
        ld a,(anim_k)
        cp SWAP_FRAMES
        ret c
        ld a,(swap_a)           ; ανταλλαγή στο board[]
        ld l,a
        ld h,board>>8
        ld a,(swap_b)
        ld e,a
        ld d,h
        ld a,(de)
        ld b,(hl)
        ld (hl),a
        ld a,b
        ld (de),a
        ld a,(state)
        cp S_UNSWAP
        jr z,.back
        ld a,1                  ; RESOLVE
        ld (chain),a
        call bomb_swap
        jr c,.valid
        call find_matches
        jr z,.invalid
.valid  ld a,(moves)
        sub 1
        daa
        ld (moves),a
        ld a,1
        ld (hud_dirty),a
        jp start_clear
.invalid
        xor a
        ld (anim_k),a
        ld a,S_UNSWAP
        ld (state),a
        ret
.back   ld a,S_IDLE
        ld (state),a
        ld a,(swap_a)
        call mark_dirty
        ld a,(swap_b)
        jp mark_dirty

; Τα δύο κελιά, με τα candies τους μετατοπισμένα κατά anim_k βήματα.
swap_draw:
        ld a,(swap_a)
        call draw_bg
        ld a,(swap_b)
        call draw_bg
        ld a,(swap_a)           ; βήμα: 1 byte ή 4 γραμμές ανά καρέ
        ld b,a
        ld a,(swap_b)
        sub b
        ld de,#0001             ; D = γραμμές, E = bytes
        cp 1
        jr z,.mul
        ld de,#00FF
        cp -1
        jr z,.mul
        ld de,#0400
        cp COLS
        jr z,.mul
        ld de,#FC00
.mul    ld a,(anim_k)
        ld b,a
        xor a
        ld c,a
.m      add a,d
        ld h,a
        ld a,c
        add a,e
        ld c,a
        ld a,h
        djnz .m
        ld d,a                  ; D, E = μετατόπιση γραμμών, bytes
        ld e,c
        ld a,(swap_a)
        call .one
        ld a,d                  ; το άλλο προς την αντίθετη μεριά
        neg
        ld d,a
        ld a,e
        neg
        ld e,a
        ld a,(swap_b)
.one    push de
        push af
        call cell_xy
        ld a,c
        add a,e
        ld c,a
        ld a,b
        add a,d
        ld b,a
        pop af
        ld l,a
        ld h,board>>8
        ld a,(hl)
        call draw_candy_at
        pop de
        ret

; ---------------------------------------------------------------------------
; CLEAR: τα σημαδεμένα σκάνε σε 4 φάσεις των 2 καρέ, μετά αδειάζουν.
start_clear:
        xor a
        ld (anim_k),a
        ld a,S_CLEAR
        ld (state),a
        ret

st_clear:
        ld hl,anim_k
        ld a,(hl)
        inc (hl)
        cp 8
        jr z,.empty
        bit 0,a
        ret nz
        rrca
        and 3
        ld (pop_ph),a
        ld c,0
.cell   ld h,matched>>8
        ld a,c
        or matched&#FF
        ld l,a
        ld a,(hl)
        or a
        jr z,.next
        push bc
        ld a,c
        call draw_bg
        pop bc
        push bc
        ld a,(pop_ph)
        or a
        jr nz,.nocandy
        ld a,c                  ; η λάμψη πάνω από το candy
        call draw_candy_cell
        pop bc
        push bc
.nocandy
        ld a,(pop_ph)
        add a,OVERLAY_POP
        ld d,a
        ld a,c
        call draw_overlay
        pop bc
.next   inc c
        ld a,c
        cp COLS*ROWS
        jr c,.cell
        ret
.empty  ld c,0
.cell2  ld h,matched>>8
        ld a,c
        or matched&#FF
        ld l,a
        ld a,(hl)
        or a
        jr z,.next2
        res 6,l
        ld (hl),EMPTY
        push bc
        ld a,c
        call draw_bg
        pop bc
.next2  inc c
        ld a,c
        cp COLS*ROWS
        jr c,.cell2
        ld a,(nspawn)           ; τα ειδικά που γεννήθηκαν
        or a
        jr z,start_fall
        ld b,a
        ld hl,spawns
.spawn  ld a,(hl)
        inc hl
        ld e,(hl)
        inc hl
        push hl
        push bc
        ld l,a
        ld h,board>>8
        ld (hl),e
        call draw_candy_cell
        pop bc
        pop hl
        djnz .spawn
        ; fall through

; ---------------------------------------------------------------------------
; FALL: ένα κελί τη φορά, σε FALL_STEPS καρέ, ώσπου να μη μείνει κενό.
start_fall:
        call fall_scan
        jr z,resolve_fall
        xor a
        ld (anim_k),a
        ld a,S_FALL
        ld (state),a
        ret

st_fall:
        ld hl,anim_k
        inc (hl)
        ld a,(hl)
        call fall_draw
        ld a,(anim_k)
        cp FALL_STEPS
        ret c
        call fall_commit
        jr start_fall

; Το ταμπλό ησύχασε: νέες τριάδες = αλυσίδα, αλλιώς πίσω στον παίκτη.
resolve_fall:
        ld hl,chain
        inc (hl)
        call find_matches
        jp nz,start_clear
        ld a,(moves)            ; SETTLE
        or a
        jr z,.over
        call has_move
        jr c,.idle
        call fill_board         ; αδιέξοδο: καινούργιο ταμπλό
        call draw_board_all
        call clear_dirty
.idle   ld a,S_IDLE
        ld (state),a
        ld a,(cursor)
        jp mark_dirty
.over   xor a
        ld (anim_k),a
        ld a,S_OVER
        ld (state),a
        ret

; ---------------------------------------------------------------------------
; OVER: οι κινήσεις τελείωσαν. Το περίγραμμα αναβοσβήνει· SPACE = ξανά.
st_over:
        ld hl,anim_k
        inc (hl)
        ld a,(hl)
        and 16
        ld a,#54                ; μαύρο
        jr z,.ink
        ld a,#44                ; σκούρο μπλε
.ink    ld bc,#7F10
        out (c),c
        out (c),a
        ld a,(joy_edge)
        and J_FIRE
        ret z
        ld a,#54
        out (c),a
        pop hl                  ; έξω από το step_state: καινούργιο παιχνίδι
        jp game_new
