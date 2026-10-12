; level.asm — οι πίστες, οι στόχοι και τα αστέρια (plan.md §11)
;
; Τα δεδομένα είναι στο build/levels.asm, από το levels/levels.txt.

; A = πίστα (από 0): κεφαλίδα στις μεταβλητές, κελιά στο cell[].
load_level:
        add a,a
        ld hl,levels_tab
        call add_hl_a
        ld a,(hl)
        inc hl
        ld h,(hl)
        ld l,a
        ld de,lv_goal           ; οι 10 bytes της κεφαλίδας, με τη σειρά τους
        ld bc,LEVEL_HEAD
        ldir
        ld de,cell              ; RLE: (πλήθος, τιμή)
.rle    ld b,(hl)
        inc hl
        ld a,(hl)
        inc hl
.run    ld (de),a
        inc e
        djnz .run
        ld a,e
        cp (cell&#FF)+COLS*ROWS
        jr c,.rle
        ld a,(lv_colours)
        ld (ncolours),a
        ld a,(lv_moves)
        ld (moves),a
        ld a,(lv_ingr)
        ld (ingr_left),a
        call bcd2bin
        ld (ingr_spawn),a
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
