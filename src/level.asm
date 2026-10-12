; level.asm — οι πίστες, οι στόχοι και τα αστέρια (plan.md §11)
;
; Τα δεδομένα είναι στο build/levels.asm, από το levels/levels.txt.

; A = πίστα (από 0): κεφαλίδα στις μεταβλητές, κελιά στο cell[]. Οι πίστες δεν
; έχουν πίνακα διευθύνσεων: αποκωδικοποιούνται όλες με τη σειρά ώς τη ζητούμενη.
load_level:
        ld b,a
        inc b
        ld hl,levels
.lv     push bc
        call decode_level
        pop bc
        djnz .lv
        ld a,(lv_colours)
        ld (ncolours),a
        ld a,(lv_moves)
        ld (moves),a
        ld a,(lv_ingr)
        ld (ingr_left),a
        call bcd2bin
        ld (ingr_spawn),a
        ret

; HL = πίστα (tools/levels.py) -> HL = η επόμενη.
decode_level:
        ld a,(hl)               ; σημαίες
        inc hl
        ld c,a
        and 3
        ld (lv_goal),a
        ld a,c
        rrca
        rrca
        and 3
        add a,4
        ld (lv_colours),a
        ld a,(hl)
        inc hl
        ld (lv_moves),a
        xor a
        bit 1,c                 ; υλικά μόνο αν τα ζητάει ο στόχος
        jr z,.noingr
        ld a,(hl)
        inc hl
.noingr ld (lv_ingr),a
        ld de,lv_star1
        call .star
        ld de,lv_star2
        call .star
        ld de,lv_star3
        call .star
        ld e,0                  ; E = κελί του ρεύματος
.run    ld a,(hl)               ; είδος << 4 | μήκος - 1
        inc hl
        push hl
        ld b,a
        rrca
        rrca
        rrca
        rrca
        and 15
        ld hl,cell_kinds
        call add_hl_a
        ld d,(hl)               ; D = τιμή cell[]
        ld a,b
        and 15
        inc a
        ld b,a
        ld h,cell>>8
.put    ld a,e
        bit 4,c
        jr z,.plain
        and #FC                 ; καθρέφτης: γραμμή * 8 + κολόνα, και το είδωλο
        add a,a
        ld l,a
        ld a,e
        and 3
        or l
        or cell&#FF
        ld l,a
        ld (hl),d
        xor 7
.plain  or cell&#FF
        ld l,a
        ld (hl),d
        inc e
        djnz .put
        pop hl
        ld a,e
        bit 4,c
        jr z,.n64
        add a,a
.n64    cp COLS*ROWS
        jr c,.run
        ret
; DE = όριο αστεριού: (HL) * 500 πόντοι -> BCD εκατοντάδες, MSB πρώτο.
.star   ld b,(hl)
        inc hl
        push hl
        ld hl,0
.five   ld a,l
        add a,5
        daa
        ld l,a
        ld a,h
        adc a,0
        daa
        ld h,a
        djnz .five
        ex de,hl
        ld (hl),d
        inc hl
        ld (hl),e
        pop hl
        ret

; A = BCD -> A = δυαδικό
bcd2bin:
        push bc
        ld b,a
        and #F0
        rrca                    ; δεκάδες * 8
        ld c,a
        rrca
        rrca                    ; δεκάδες * 2
        add a,c
        ld c,a
        ld a,b
        and #0F
        add a,c
        pop bc
        ret

; A = δυαδικό 0-99 -> A = BCD
bin2bcd:
        push bc
        ld b,0
.ten    cp 10
        jr c,.done
        sub 10
        inc b
        jr .ten
.done   ld c,a
        ld a,b
        rlca
        rlca
        rlca
        rlca
        or c
        pop bc
        ret

; -> A = κελιά με ζελέ που μένουν
count_jelly:
        ld hl,cell
        ld bc,COLS*ROWS*256     ; B = 64, C = 0
.l      ld a,(hl)
        and JELLY_MASK
        jr z,.n
        inc c
.n      inc l
        djnz .l
        ld a,c
        ret

; HL = όριο πόντων σε BCD εκατοντάδες (MSB πρώτο) -> carry αν δεν το φτάσαμε.
score_below:
        ld a,(score)            ; score / 100 = τα δύο πρώτα bytes
        cp (hl)
        ret nz
        inc hl
        ld a,(score+1)
        cp (hl)
        ret

; -> A = αστέρια που κερδήθηκαν ώς τώρα με τους πόντους (0-3)
stars_now:
        ld c,0
        ld hl,lv_star1
        call score_below
        jr c,.done
        inc c
        ld hl,lv_star2
        call score_below
        jr c,.done
        inc c
        ld hl,lv_star3
        call score_below
        jr c,.done
        inc c
.done   ld a,c
        ret

; Carry αν ο στόχος της πίστας επιτεύχθηκε.
goal_met:
        ld a,(lv_goal)
        cp G_ENDLESS
        jr z,.no
        or a
        jr nz,.jelly
        ld hl,lv_star1          ; πόντοι
        call score_below
        ccf
        ret
.jelly  cp G_INGREDIENTS
        jr z,.ingr
        call count_jelly
        or a
        jr nz,.no
        ld a,(lv_goal)
        cp G_JELLY
        scf
        ret z
.ingr   ld a,(ingr_left)
        or a
        scf
        ret z
.no     or a
        ret

; Στο τέλος της πίστας: τρία αστέρια στη μέση του ταμπλό, μεγάλα όσα κερδήθηκαν.
draw_win_stars:
        call stars_now
        or a
        jr nz,.some
        inc a                   ; ο στόχος επιτεύχθηκε: τουλάχιστον ένα
.some   ld (win_n),a
        ld c,0
.star   push bc
        ld a,c
        add a,3*COLS+2
        call draw_bg
        pop bc
        push bc
        ld a,(win_n)            ; το i-οστό είναι μεγάλο αν i < αστέρια
        dec a
        cp c
        ld d,OVERLAY_STAR+1
        jr nc,.big
        ld d,OVERLAY_STAR
.big    ld a,c
        add a,3*COLS+2
        call draw_overlay
        pop bc
        inc c
        ld a,c
        cp 3
        jr c,.star
        ret
