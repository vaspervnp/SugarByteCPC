; special.asm — τα ειδικά candies: πώς γεννιούνται, τι κάνουν (plan.md §8.2)

; HL += A
add_hl_a:
        add a,l
        ld l,a
        ret nc
        inc h
        ret

; L = πρώτο κελί, E = μήκος, C = βήμα: μπαίνει στο runs[]. Δεν πειράζει C, E.
record_run:
        ld a,(nruns)
        cp MAX_RUNS
        ret nc
        inc a
        ld (nruns),a
        dec a
        ld b,a
        add a,a
        add a,b
        ld d,l
        ld hl,runs
        call add_hl_a
        ld (hl),d
        inc hl
        ld (hl),e
        inc hl
        ld (hl),c
        ret

; A = κελί, E = τιμή board[]: θα γεννηθεί εκεί μετά το CLEAR.
; Δεν πειράζει BC, DE, HL, IX.
add_spawn:
        push hl
        push af
        ld a,(nspawn)
        cp MAX_SPAWN
        jr nc,.full
        inc a
        ld (nspawn),a
        dec a
        add a,a
        ld hl,spawns
        call add_hl_a
        pop af
        ld (hl),a
        inc hl
        ld (hl),e
        pop hl
        ret
.full   pop af
        pop hl
        ret

; ---------------------------------------------------------------------------
; Τι γεννιέται: 5 στη σειρά -> βόμβα, Γ ή Τ -> περιτύλιγμα, 4 -> ριγέ στη φορά
; του match. Με αυτή τη σειρά: ό,τι πήρε ήδη ένα κελί δεν δίνει δεύτερο ειδικό.
plan_specials:
        ld a,(nruns)
        or a
        ret z
        ld b,a
        ld ix,runs
.five   ld a,(ix+1)
        cp 5
        jr c,.n5
        push bc
        call run_consume
        call run_pick
        ld e,BOMB
        call add_spawn
        pop bc
.n5     inc ix
        inc ix
        inc ix
        djnz .five

        ld hl,matched           ; κελιά σε γραμμή ΚΑΙ κολόνα
.cross  ld a,(hl)
        and 7
        cp 3
        jr nz,.ncross
        set 2,(hl)
        res 6,l
        ld a,(hl)
        set 6,l
        call mcol
        or F_WRAPPED
        ld e,a
        ld a,l
        and 63
        call add_spawn
.ncross inc l
        ld a,l
        cp (matched&#FF)+COLS*ROWS
        jr c,.cross

        ld a,(nruns)
        ld b,a
        ld ix,runs
.four   ld a,(ix+1)
        cp 4
        jr nz,.n4
        push bc
        call run_clean
        jr nz,.skip4
        call run_pick
        push af
        ld l,(ix+0)
        ld h,board>>8
        ld a,(hl)
        call mcol
        ld e,a
        ld a,(ix+2)
        cp 1
        ld a,F_STRIPED_H
        jr z,.horiz
        ld a,F_STRIPED_V
.horiz  or e
        ld e,a
        pop af
        call add_spawn
.skip4  pop bc
.n4     inc ix
        inc ix
        inc ix
        djnz .four
        ret

; IX = σειρά: σημαδεύει τα κελιά της «δεσμευμένα» (bit 2).
run_consume:
        ld l,(ix+0)
        ld b,(ix+1)
        ld c,(ix+2)
        ld h,matched>>8
.l      set 6,l
        set 2,(hl)
        res 6,l
        ld a,l
        add a,c
        ld l,a
        djnz .l
        ret

; IX = σειρά -> NZ αν κάποιο κελί της είναι δεσμευμένο ή διασταύρωση.
run_clean:
        ld l,(ix+0)
        ld b,(ix+1)
        ld c,(ix+2)
        ld h,matched>>8
.l      set 6,l
        ld a,(hl)
        res 6,l
        bit 2,a
        ret nz
        and 3
        cp 3
        jr z,.cross
        ld a,l
        add a,c
        ld l,a
        djnz .l
        xor a
        ret
.cross  or a
        ret

; IX = σειρά -> A = το κελί όπου γεννιέται το ειδικό: εκεί που μπήκε το candy
; του παίκτη, αν η σειρά βγήκε από ανταλλαγή· αλλιώς στη μέση.
run_pick:
        ld a,(chain)
        dec a
        jr nz,.mid
        ld l,(ix+0)
        ld b,(ix+1)
        ld c,(ix+2)
.l      ld a,(swap_b)
        cp l
        jr z,.got
        ld a,(swap_a)
        cp l
        jr z,.got
        ld a,l
        add a,c
        ld l,a
        djnz .l
.mid    ld a,(ix+1)
        srl a
        ld b,a
        ld a,(ix+0)
.m      add a,(ix+2)
        djnz .m
        ret
.got    ld a,l
        ret

; ---------------------------------------------------------------------------
; Όσα ειδικά σκάνε πυροδοτούνται, και όσα χτυπήσουν αυτά επίσης, ώσπου να μη
; μείνει κανένα.
expand_specials:
.pass   xor a
        ld (sp_changed),a
        ld c,0
.cell   ld h,board>>8
        ld a,c
        or matched&#FF
        ld l,a
        ld a,(hl)
        or a
        jr z,.next
        bit 7,a
        jr nz,.next
        res 6,l
        ld a,(hl)
        call special_kind
        jr z,.next
        set 6,l
        set 7,(hl)
        ld (sp_changed),a
        push bc
        call fire_special
        pop bc
.next   inc c
        ld a,c
        cp COLS*ROWS
        jr c,.cell
        ld a,(sp_changed)
        or a
        jr nz,.pass
        ret

; A = τιμή board[] -> A = 1 ριγέ-οριζ., 2 ριγέ-κάθ., 3 περιτύλιγμα, 4 βόμβα,
; 0 και Z αν δεν είναι ειδικό.
special_kind:
        bit 5,a
        jr nz,.none
        cp BOMB
        jr z,.bomb
        and 3<<FORM_SHIFT
        rrca
        rrca
        rrca
        ret
.bomb   ld a,4
        or a
        ret
.none   xor a
        ret

; A = είδος (special_kind), C = κελί.
fire_special:
        dec a
        jr z,.row
        dec a
        jr z,.col
        dec a
        jr z,.wrap
        call rand_colour        ; βόμβα που τη χτύπησε άλλο: ένα τυχαίο χρώμα
        ld d,a
        jp mark_colour
.row    ld a,c
        and #38
        ld b,COLS
.rl     push af
        call hit_cell
        pop af
        inc a
        djnz .rl
        ret
.col    ld a,c
        and 7
        ld b,ROWS
.cl     push af
        call hit_cell
        pop af
        add a,COLS
        djnz .cl
        ret
.wrap   ld a,c                  ; 3x3 γύρω από το κελί
        and 7
        ld e,a
        ld a,c
        rrca
        rrca
        rrca
        and 7
        dec a
        ld d,a                  ; D = πρώτη γραμμή (μπορεί -1)
        ld b,3
.wy     push bc
        ld a,d
        cp ROWS
        jr nc,.ny
        ld b,3
        ld a,e
        dec a
.wx     cp COLS
        jr nc,.nx
        push af
        ld l,a
        ld a,d
        add a,a
        add a,a
        add a,a
        add a,l
        call hit_cell
        pop af
.nx     inc a
        djnz .wx
.ny     pop bc
        inc d
        djnz .wy
        ret

; D = χρώμα: χτυπάει κάθε candy αυτού του χρώματος.
mark_colour:
        ld c,0
.l      ld l,c
        ld h,board>>8
        ld a,(hl)
        call mcol
        cp d
        jr nz,.n
        ld a,c
        call hit_cell
.n      inc c
        ld a,c
        cp COLS*ROWS
        jr c,.l
        ret

; A = κελί που το χτύπησε ειδικό: σκάει κι αυτό, 60 πόντοι.
; Δεν πειράζει BC, DE, HL.
hit_cell:
        push hl
        ld l,a
        ld h,board>>8
        ld a,(hl)
        cp EMPTY
        jr z,.out
        bit 5,a                 ; τα υλικά δεν σκάνε
        jr nz,.out
        set 6,l
        ld a,(hl)
        or a
        jr nz,.out
        ld (hl),8
        push bc
        push de
        ld de,#0060
        call add_score_chain
        pop de
        pop bc
.out    pop hl
        ret

; ---------------------------------------------------------------------------
; Μετά την ανταλλαγή: αν πήρε μέρος βόμβα, σκάνε όλα τα candies του χρώματος
; του άλλου (δύο βόμβες: όλο το ταμπλό). Carry αν έγινε, με το matched[] έτοιμο.
bomb_swap:
        ld h,board>>8
        ld a,(swap_a)
        ld l,a
        ld b,(hl)
        ld a,(swap_b)
        ld l,a
        ld c,(hl)
        ld a,b
        cp BOMB
        jr z,.at_a
        ld a,c
        cp BOMB
        jr z,.at_b
        or a
        ret
.at_b   ld a,(swap_b)
        ld e,a
        ld a,b
        jr .go
.at_a   ld a,(swap_a)
        ld e,a
        ld a,c
.go     cp BOMB
        jr z,.ok
        ld d,a
        call mcol
        cp 6
        ret nc                  ; βόμβα με υλικό: τίποτα (carry καθαρό)
        ld a,d
.ok     push af
        push de
        call clear_matched
        pop de
        ld h,board>>8
        ld l,e
        set 6,l
        ld (hl),#81             ; η ίδια η βόμβα: σκάει, έχει ήδη πυροδοτηθεί
        ld hl,nmatch
        inc (hl)
        pop af
        cp BOMB
        jr z,.all
        call mcol
        ld d,a
        call mark_colour
        jr .done
.all    ld c,0
.al     ld a,c
        call hit_cell
        inc c
        ld a,c
        cp COLS*ROWS
        jr c,.al
.done   call expand_specials
        scf
        ret
