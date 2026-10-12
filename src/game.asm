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
        ld a,7
        ld (ingr_odds),a
        ld a,BOARD_Y
        ld (clip_y),a
        ld a,#FF
        ld (sel),a
        ld a,3*COLS+3
        ld (cursor),a
        ld a,(cur_level)
        call load_level
        call fill_board
        call draw_frame
        call draw_board_all
        call hud_init
        ; S_IDLE == 0 από τον μηδενισμό

main_loop:
        call wait_vbl
        call read_input
        ld a,(joy_edge)
        and J_MUSIC
        call nz,toggle_music
        call render_dirty
        call step_state
        call hud_update
        jr main_loop

toggle_music:
        ld a,(mus_on)
        xor 1
        ld (mus_on),a
        ret

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
        dw st_idle, st_swap, st_swap, st_clear, st_fall, st_over, st_beam, st_win
        dw st_code, st_menu, st_scores, st_crush

; ---------------------------------------------------------------------------
; IDLE: ο δείκτης κινείται και αναβοσβήνει, το SPACE επιλέγει και ανταλλάσσει.
st_idle:
        ld a,(joy_edge)
        and J_ESC
        jp nz,menu_enter
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
        ld l,a                  ; σε κενό ή εμπόδιο: τίποτα
        ld h,board>>8
        ld a,(hl)
        cp EMPTY
        ret z
        ld a,(sel)
        cp #FF
        jr nz,.has_sel
        ld a,c                  ; πρώτη επιλογή
        ld (sel),a
        call mark_dirty
        ld hl,sfx_select
        jp play_sfx
.has_sel
        ld b,a
        cp c
        jr nz,.other
        ld a,#FF                ; ξανά στο ίδιο: ακύρωση
        ld (sel),a
        ld a,c
        call mark_dirty
        ld hl,sfx_select
        jp play_sfx
.other  call adjacent
        jr c,.swap
        ld a,c                  ; μακριά: η επιλογή μετακομίζει
        ld (sel),a
        call mark_dirty
        ld a,b
        call mark_dirty
        ld hl,sfx_select
        jp play_sfx
.swap   xor a
        ld (choc_broken),a
        ld a,b
        ld (swap_a),a
        ld a,c
        ld (swap_b),a
        ld a,#FF
        ld (sel),a
        xor a
        ld (anim_k),a
        ld a,S_SWAP
        ld (state),a
        ld hl,sfx_swap
        jp play_sfx

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
        call combo_swap
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
        ld hl,sfx_bad
        jp play_sfx
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
; Πρώτα οι δέσμες των ριγέ, αν υπάρχουν, μετά το σκάσιμο.
start_clear:
        xor a
        ld (anim_k),a
        ld hl,matched           ; πόσα σκάνε
        ld b,COLS*ROWS
        ld c,a
.count  ld a,(hl)
        or a
        jr z,.nc
        inc c
.nc     inc l
        djnz .count
        ld a,c
        ld (clear_n),a
        ld a,(nbeams)
        or a
        jr z,.pop
        ld a,S_BEAM
        ld (state),a
        ld hl,sfx_beam
        jp play_sfx
.pop    ld a,S_CLEAR
        ld (state),a
        jp play_clear_sfx

; BEAM: η δέσμη πάνω από τη γραμμή/κολόνα, χοντρή και μετά λεπτή, 2 καρέ η
; καθεμία· μετά ό,τι δεν σκάει κάτω από τη δέσμη (υλικά) ξαναζωγραφίζεται.
st_beam:
        ld hl,anim_k
        ld a,(hl)
        inc (hl)
        cp 4
        jr z,.restore
        bit 0,a
        ret nz
        rrca
        and 1
        ld (pop_ph),a
        ld e,0
.beam   ld a,(nbeams)
        cp e
        ret z
        ld hl,beams
        ld a,e
        call add_hl_a
        ld a,(hl)
        push de
        call beam_cells
        ld a,e
        ld (beam_step),a
        ld a,(pop_ph)
        add a,d
        ld (beam_fr),a
.cell   push bc
        ld a,(beam_fr)
        ld d,a
        ld a,c
        call draw_overlay
        pop bc
        ld a,(beam_step)
        add a,c
        ld c,a
        djnz .cell
        pop de
        inc e
        jr .beam
.restore
        ld e,0
.rbeam  ld a,(nbeams)
        cp e
        jr z,.done
        ld hl,beams
        ld a,e
        call add_hl_a
        ld a,(hl)
        push de
        call beam_cells
        ld a,e
        ld (beam_step),a
.rcell  push bc
        ld h,matched>>8
        ld a,c
        or matched&#FF
        ld l,a
        ld a,(hl)
        or a
        ld a,c
        call z,draw_cell
        pop bc
        ld a,(beam_step)
        add a,c
        ld c,a
        djnz .rcell
        pop de
        inc e
        jr .rbeam
.done   xor a
        ld (anim_k),a
        ld a,S_CLEAR
        ld (state),a
        jp play_clear_sfx

; A = δέσμη -> C = πρώτο κελί, E = βήμα, B = 8, D = καρέ επικάλυψης (πάχος 0)
beam_cells:
        ld b,8
        bit 7,a
        jr nz,.vert
        add a,a
        add a,a
        add a,a
        ld c,a
        ld e,1
        ld d,OVERLAY_BEAM_H
        ret
.vert   and 7
        ld c,a
        ld e,COLS
        ld d,OVERLAY_BEAM_V
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
        jr z,.go                ; πολλά μαζί: μόνο λάμψη και σκόνη
        cp 3
        jr z,.go
        ld a,(clear_n)
        cp BIG_CLEAR
        ret nc
.go     ld c,0
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
        ld a,(pop_ph)           ; εκεί που γεννιέται ειδικό: αστέρι
        or a
        call nz,spawn_star
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
        call apply_damage       ; ζελέ από κάτω, ή εμπόδιο που σπάει
        pop bc
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
        call collect_ingredients
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
        call goal_met           ; SETTLE
        jr c,.win
        ld a,(moves)
        or a
        jr z,.over
        call spread_chocolate
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
        ld hl,sfx_over
        jp play_sfx
.win    ld a,(moves)            ; κινήσεις περίσσεψαν: πρώτα το Sugar Crush
        or a
        jp nz,start_crush
        xor a
        ld (anim_k),a
        ld a,S_WIN
        ld (state),a
        call draw_win_stars
        call record_best
        ld a,(cur_level)        ; ο κωδικός της επόμενης πίστας
        inc a
        cp NLEVELS
        jr c,.code
        xor a
.code   call hud_show_code
        ld hl,sfx_win
        jp play_sfx

; ---------------------------------------------------------------------------
; WIN: ο στόχος επιτεύχθηκε. Τα αστέρια στο ταμπλό· SPACE = η επόμενη πίστα.
st_win:
        ld a,(joy_edge)
        and J_ESC
        jp nz,menu_enter
        ld a,(joy_edge)
        and J_FIRE
        ret z
        ld a,(cur_level)
        inc a
        cp NLEVELS
        jr c,.next
        xor a                   ; μετά την τελευταία, από την αρχή
.next   ld (cur_level),a
        pop hl                  ; έξω από το step_state
        jp game_new

; ---------------------------------------------------------------------------
; OVER: οι κινήσεις τελείωσαν. Το περίγραμμα αναβοσβήνει· SPACE = η ίδια πίστα ξανά.
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
        and J_ESC
        jr z,.noesc
        ld a,#54                ; περίγραμμα μαύρο: στο μενού
        out (c),a
        jp menu_enter
.noesc  ld a,(joy_edge)
        and J_FIRE
        ret z
        ld a,#54
        out (c),a
        pop hl                  ; έξω από το step_state: καινούργιο παιχνίδι
        jp game_new

; ---------------------------------------------------------------------------
; SUGAR CRUSH: ο στόχος επιτεύχθηκε με κινήσεις που περίσσεψαν. Κάθε κίνηση
; γίνεται ένα ριγέ σε τυχαίο απλό candy· μετά σκάνε όλα τα ειδικά του ταμπλού
; μαζί, και οι αλυσίδες τους μετράνε κανονικά. Όταν το ταμπλό ησυχάσει, οι
; κινήσεις είναι 0 και ακολουθεί η νίκη.
start_crush:
        xor a
        ld (anim_k),a
        ld a,S_CRUSH
        ld (state),a
        ld hl,sfx_win
        jp play_sfx

st_crush:
        ld hl,anim_k
        ld a,(hl)
        inc (hl)
        or a
        ret z                   ; το πρώτο καρέ: μόνο η φανφάρα
        cp CRUSH_FRAMES
        ret c
        ld (hl),1
        ld a,(moves)
        or a
        jr z,crush_fire
        sub 1
        daa
        ld (moves),a
        ld a,1
        ld (hud_dirty),a
        call rand               ; ένα τυχαίο απλό candy γίνεται ριγέ
        and 63
        ld c,a
        ld b,COLS*ROWS
.find   ld l,c
        ld h,board>>8
        ld a,(hl)
        cp 6                    ; απλό: χρώμα 0-5, καμία μορφή, όχι υλικό
        jr c,.got
        ld a,c
        inc a
        and 63
        ld c,a
        djnz .find
        jr crush_fire           ; δεν έμεινε κανένα απλό
.got    ld b,a
        call rand
        and 1
        ld a,F_STRIPED_H
        jr z,.h
        ld a,F_STRIPED_V
.h      or b
        ld (hl),a
        ld a,c
        call mark_dirty
        ld hl,sfx_select
        jp play_sfx

; Όλα τα ειδικά του ταμπλού σκάνε μαζί.
crush_fire:
        call clear_matched
        ld a,1
        ld (chain),a
        ld c,0
.cell   ld l,c
        ld h,board>>8
        ld a,(hl)
        call special_kind
        jr z,.next
        set 6,l
        ld (hl),1
        ld hl,nmatch
        inc (hl)
.next   inc c
        ld a,c
        cp COLS*ROWS
        jr c,.cell
        ld a,(nmatch)
        or a
        jr z,.done
        call expand_specials
        call mark_blocker_damage
        jp start_clear
.done   jp resolve_fall         ; τίποτα να σκάσει: κατευθείαν στη νίκη

