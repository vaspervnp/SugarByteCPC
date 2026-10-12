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
        call cell_row
        jp hit_row
.col    ld a,c
        and 7
        jp hit_col
.wrap   ld a,1
        jp hit_area

; A = κελί -> A = γραμμή
cell_row:
        rrca
        rrca
        rrca
        and 7
        ret

; A = γραμμή (>= 8: τίποτα): χτυπάει όλη τη γραμμή. Δεν πειράζει C, DE, HL.
hit_row:
        cp ROWS
        ret nc
        add a,a
        add a,a
        add a,a
        ld b,COLS
.l      push af
        call hit_cell
        pop af
        inc a
        djnz .l
        ret

; A = κολόνα (>= 8: τίποτα): χτυπάει όλη την κολόνα. Δεν πειράζει C, DE, HL.
hit_col:
        cp COLS
        ret nc
        ld b,ROWS
.l      push af
        call hit_cell
        pop af
        add a,COLS
        djnz .l
        ret

; C = κέντρο, A = ακτίνα: χτυπάει το τετράγωνο (2A+1)x(2A+1), κομμένο στο ταμπλό.
hit_area:
        ld b,a
        ld a,c
        and 7
        sub b
        ld e,a                  ; E = πρώτη κολόνα (μπορεί < 0)
        ld a,c
        call cell_row
        sub b
        ld d,a                  ; D = πρώτη γραμμή (μπορεί < 0)
        ld a,b
        add a,a
        inc a
        ld b,a                  ; B = γραμμές που μένουν
        ld c,a                  ; C = πλευρά
.wy     push bc
        ld a,d
        cp ROWS
        jr nc,.ny
        ld b,c
        ld a,e
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
; Μετά την ανταλλαγή: αν πήρε μέρος βόμβα ή ήταν δύο ειδικά, ο συνδυασμός
; (plan.md §8.3). Carry αν έγινε κάτι, με το matched[] έτοιμο.
;
;   βόμβα + απλό          όλα τα candies εκείνου του χρώματος
;   βόμβα + ριγέ/περιτ.   όλα εκείνου του χρώματος γίνονται ριγέ/περιτ. και σκάνε
;   βόμβα + βόμβα         όλο το ταμπλό
;   ριγέ + ριγέ           γραμμή και κολόνα
;   ριγέ + περιτύλιγμα    σταυρός πάχους 3
;   περιτ. + περιτ.       5x5
combo_swap:
        ld h,board>>8
        ld a,(swap_a)
        ld l,a
        ld b,(hl)
        ld a,(swap_b)
        ld l,a
        ld c,(hl)
        ld a,b
        cp BOMB
        jr z,.bomb_a
        ld a,c
        cp BOMB
        jr z,.bomb_b
        ld a,b                  ; δύο ριγέ / περιτυλίγματα;
        call special_kind
        ret z
        ld d,a
        ld a,c
        call special_kind
        ret z
        ld e,a                  ; D, E = τα δύο είδη (1-3)
        push de
        call clear_matched
        call fire_both          ; τα ίδια σκάνε, χωρίς το δικό τους εφέ
        pop de
        ld a,(swap_b)
        ld c,a                  ; το κέντρο: εκεί που πήγε το candy του παίκτη
        ld a,d
        cp 3
        jr nz,.not_ww
        ld a,e
        cp 3
        jr nz,.cross
        ld a,2                  ; περιτύλιγμα + περιτύλιγμα
        call hit_area
        jp .done
.not_ww ld a,e
        cp 3
        jr z,.cross
        ld a,c                  ; ριγέ + ριγέ
        call cell_row
        call hit_row
        ld a,c
        and 7
        call hit_col
        jp .done
.cross  ld a,c                  ; ριγέ + περιτύλιγμα: 3 γραμμές, 3 κολόνες
        call cell_row
        dec a
        ld b,3
.rows   push af
        push bc
        call hit_row
        pop bc
        pop af
        inc a
        djnz .rows
        ld a,c
        and 7
        dec a
        ld b,3
.cols   push af
        push bc
        call hit_col
        pop bc
        pop af
        inc a
        djnz .cols
        jp .done

.bomb_b ld a,(swap_b)
        ld e,a
        ld a,b
        jr .bomb
.bomb_a ld a,(swap_a)
        ld e,a
        ld a,c
.bomb   ld d,a                  ; D = το άλλο, E = το κελί της βόμβας
        cp BOMB
        jr z,.ok
        call mcol
        cp 6
        ret nc                  ; βόμβα με υλικό: τίποτα (carry καθαρό)
.ok     push de
        call clear_matched
        pop de
        ld h,board>>8
        ld l,e
        set 6,l
        ld (hl),#81             ; η ίδια η βόμβα: σκάει, έχει ήδη πυροδοτηθεί
        ld hl,nmatch
        inc (hl)
        ld a,d
        cp BOMB
        jr z,.all
        call special_kind
        ld e,a                  ; E = είδος του άλλου (0 απλό)
        ld a,d
        call mcol
        ld d,a                  ; D = χρώμα
        ld a,e
        or a
        call nz,convert_colour
        call mark_colour
        jp .done
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

; Τα δύο κελιά της ανταλλαγής: σκάνε, και σημαδεύονται πυροδοτημένα.
fire_both:
        ld h,board>>8
        ld a,(swap_a)
        or matched&#FF
        ld l,a
        ld (hl),#81
        ld a,(swap_b)
        or matched&#FF
        ld l,a
        ld (hl),#81
        ld hl,nmatch
        inc (hl)
        ret

; D = χρώμα, E = είδος (1 ριγέ-οριζ., 2 ριγέ-κάθ., 3 περιτύλιγμα): κάθε candy
; αυτού του χρώματος γίνεται αυτό το ειδικό (τα ριγέ με τυχαία φορά).
convert_colour:
        ld c,0
.l      ld l,c
        ld h,board>>8
        ld a,(hl)
        call mcol
        cp d
        jr nz,.n
        ld a,e
        cp 3
        jr z,.form
        call rand               ; ριγέ: οριζόντιο ή κάθετο στην τύχη
        and 1
        inc a
.form   rlca
        rlca
        rlca
        or d
        ld (hl),a               ; φαίνεται στη λάμψη του CLEAR
.n      inc c
        ld a,c
        cp COLS*ROWS
        jr c,.l
        ret
