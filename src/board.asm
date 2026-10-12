; board.asm — η λογική του ταμπλό: τυχαία, τριάδες, βαρύτητα (plan.md §8)

; xorshift 16-bit (7,9,8). A = τυχαίο byte. Δεν πειράζει τίποτα άλλο.
rand:
        push hl
        ld hl,(seed)
        ld a,h
        rra
        ld a,l
        rra
        xor h
        ld h,a
        ld a,l
        rra
        ld a,h
        rra
        xor l
        ld l,a
        xor h
        ld h,a
        ld (seed),hl
        pop hl
        ret

; A = τυχαίο χρώμα 0..ncolours-1. Πειράζει B.
rand_colour:
        call rand
        and 7
        ld b,a
        ld a,(ncolours)
        dec a
        cp b
        jr c,rand_colour
        ld a,b
        ret

; A = τιμή board[] -> A = χρώμα που ταιριάζει (0-5), ή >= 6 αν δεν ταιριάζει
; (κενό, βόμβα, υλικό). Δεν πειράζει τίποτα άλλο.
mcol:
        bit 5,a
        jr nz,.no
        and 7
        ret
.no     ld a,#FF
        ret

; Γεμίζει το ταμπλό χωρίς έτοιμες τριάδες και με τουλάχιστον μία κίνηση.
fill_board:
        ld hl,board
.cell   call rand_colour
        ld c,a
        ld a,l                  ; δύο ίδια αριστερά;
        and 7
        cp 2
        jr c,.above
        ld d,h
        ld e,l
        dec e
        ld a,(de)
        cp c
        jr nz,.above
        dec e
        ld a,(de)
        cp c
        jr z,.cell
.above  ld a,l                  ; δύο ίδια από πάνω;
        cp 2*COLS
        jr c,.ok
        ld d,h
        sub COLS
        ld e,a
        ld a,(de)
        cp c
        jr nz,.ok
        ld a,e
        sub COLS
        ld e,a
        ld a,(de)
        cp c
        jr z,.cell
.ok     ld (hl),c
        inc l
        ld a,l
        cp COLS*ROWS
        jr c,.cell
        call has_move
        jr nc,fill_board
        ret

; ---------------------------------------------------------------------------
; Ανίχνευση τριάδων (plan.md §8.1)

; Σημαδεύει στο matched[] ό,τι σκάει, σχεδιάζει τα ειδικά που γεννιούνται και
; πυροδοτεί όσα ειδικά σκάνε. A = πόσες σειρές βρέθηκαν, Z αν καμία.
find_matches:
        call clear_matched
        ld a,1                  ; οι γραμμές: bit 0
        ld (scan_bit),a
        ld hl,board
.rows   push hl
        ld c,1
        call scan_line
        pop hl
        ld a,l
        add a,COLS
        ld l,a
        cp COLS*ROWS
        jr c,.rows
        ld a,2                  ; οι κολόνες: bit 1
        ld (scan_bit),a
        ld l,0
.cols   push hl
        ld c,COLS
        call scan_line
        pop hl
        inc l
        ld a,l
        cp COLS
        jr c,.cols
        ld a,(nmatch)
        or a
        ret z
        call plan_specials
        call expand_specials
        ld a,(nmatch)
        or a
        ret

; matched[] = 0, και καμία σειρά, κανένα ειδικό στη σειρά για γέννηση.
clear_matched:
        ld hl,matched
        ld b,COLS*ROWS
        xor a
.clr    ld (hl),a
        inc l
        djnz .clr
        ld (nmatch),a
        ld (nruns),a
        ld (nspawn),a
        ret

; HL = πρώτο κελί, C = βήμα (1 γραμμή, 8 κολόνα). Σαρώνει 8 κελιά.
scan_line:
        ld a,(hl)
        call mcol
        ld d,a                  ; D = χρώμα της σειράς
        ld e,1                  ; E = μήκος
        ld b,7
.next   ld a,l
        add a,c
        ld l,a
        ld a,(hl)
        call mcol
        cp 6
        jr nc,.brk
        cp d
        jr nz,.brk
        inc e
        jr .loop
.brk    call end_run
        ld d,a
        ld e,1
.loop   djnz .next
        ld a,l                  ; ο φρουρός: ένα βήμα μετά το τέλος
        add a,c
        ld l,a
; E = μήκος σειράς που τελειώνει ακριβώς πριν το HL, C = βήμα.
; Αν είναι >= 3, σημαδεύει και μετράει. Δεν πειράζει τίποτα.
end_run:
        push af
        ld a,e
        cp 3
        jr c,.out
        push bc
        push de
        push hl
        ld b,e
.mark   ld a,l
        sub c
        ld l,a
        set 6,l                 ; matched = board | #40
        ld a,(scan_bit)
        or (hl)
        ld (hl),a
        res 6,l
        djnz .mark
        call record_run         ; L = το πρώτο κελί της σειράς
        ld hl,nmatch
        inc (hl)
        ld a,e                  ; πόντοι (plan.md §8.6)
        cp 4
        ld de,#0060
        jr c,.add
        ld de,#0120
        jr z,.add
        ld de,#0200
.add    call add_score_chain
        pop hl
        pop de
        pop bc
.out    pop af
        ret

; DE = πόντοι σε BCD, επί chain.
add_score_chain:
        ld a,(chain)
        ld b,a
.l      ld hl,score+2
        ld a,(hl)
        add a,e
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,d
        daa
        ld (hl),a
        dec hl
        ld a,(hl)
        adc a,0
        daa
        ld (hl),a
        djnz .l
        ld a,1
        ld (hud_dirty),a
        ret

; ---------------------------------------------------------------------------
; Αδιέξοδο (plan.md §8.5): υπάρχει έστω μία ανταλλαγή που φτιάχνει τριάδα;
; Carry αν ναι. Ελέγχει μόνο γύρω από τα δύο κελιά, όχι όλο το ταμπλό.
has_move:
        ld e,0
.cell   ld a,e
        and 7
        cp 7
        jr z,.down
        ld d,e
        inc d
        call try_swap
        ret c
.down   ld a,e
        cp COLS*(ROWS-1)
        jr nc,.next
        add a,COLS
        ld d,a
        call try_swap
        ret c
.next   inc e
        ld a,e
        cp COLS*ROWS
        jr c,.cell
        or a
        ret

; E, D = δύο γειτονικά κελιά. Carry αν η ανταλλαγή τους φτιάχνει τριάδα.
; Δεν πειράζει DE· το ταμπλό μένει όπως ήταν.
try_swap:
        ld h,board>>8
        ld l,e
        ld b,(hl)
        ld l,d
        ld c,(hl)
        ld a,b                  ; βόμβα δίπλα σε οτιδήποτε: κίνηση
        cp BOMB
        jr z,.bomb
        ld a,c
        cp BOMB
        jr z,.bomb
        ld (hl),b
        ld l,e
        ld (hl),c
        push bc
        ld a,e
        call line_at
        jr c,.undo
        ld a,d
        call line_at
.undo   pop bc
        ld h,board>>8
        ld l,e
        ld (hl),b
        ld l,d
        ld (hl),c
        ret
.bomb   scf
        ret

; A = κελί. Carry αν το candy του είναι μέρος τριάδας. Δεν πειράζει DE.
line_at:
        push de
        ld e,a
        ld h,board>>8
        ld l,a
        ld a,(hl)
        call mcol
        cp 6
        jr nc,.no
        ld c,a
        ld b,1
.left   ld a,l
        and 7
        jr z,.lend
        dec l
        ld a,(hl)
        call mcol
        cp c
        jr nz,.lend
        inc b
        jr .left
.lend   ld l,e
.right  ld a,l
        and 7
        cp 7
        jr z,.rend
        inc l
        ld a,(hl)
        call mcol
        cp c
        jr nz,.rend
        inc b
        jr .right
.rend   ld a,b
        cp 3
        jr nc,.yes
        ld b,1
        ld l,e
.up     ld a,l
        cp COLS
        jr c,.uend
        sub COLS
        ld l,a
        ld a,(hl)
        call mcol
        cp c
        jr nz,.uend
        inc b
        jr .up
.uend   ld l,e
.down   ld a,l
        cp COLS*(ROWS-1)
        jr nc,.dend
        add a,COLS
        ld l,a
        ld a,(hl)
        call mcol
        cp c
        jr nz,.dend
        inc b
        jr .down
.dend   ld a,b
        cp 3
        jr nc,.yes
.no     pop de
        or a
        ret
.yes    pop de
        scf
        ret

; ---------------------------------------------------------------------------
; Βαρύτητα (plan.md §8.4), ένα κελί τη φορά: σε κάθε κολόνα με κενό, ό,τι
; είναι πάνω από το χαμηλότερο κενό κατεβαίνει μία θέση και ένα καινούργιο
; candy μπαίνει από την κορυφή.

; gap[x] = γραμμή του χαμηλότερου κενού (#FF = καμία), nextc[x] = το candy που
; μπαίνει. NZ αν κάποια κολόνα πέφτει.
fall_scan:
        ld de,gap
        ld c,0
        ld ixh,0
.col    ld h,board>>8
        ld a,c
        add a,COLS*(ROWS-1)
        ld l,a
.up     ld a,(hl)
        cp EMPTY
        jr z,.found
        ld a,l
        sub COLS
        ld l,a
        jr nc,.up
        ld a,#FF
        jr .store
.found  ld ixh,1
        ld a,l
        rrca
        rrca
        rrca
        and 7
.store  ld (de),a
        push de
        ld a,e
        add a,COLS
        ld e,a                  ; nextc = gap + COLS
        call rand_colour
        ld (de),a
        pop de
        inc de
        inc c
        ld a,c
        cp COLS
        jr c,.col
        ld a,ixh
        or a
        ret

; A = βήμα 1..FALL_STEPS: ζωγραφίζει τις κολόνες που πέφτουν.
fall_draw:
        assert FALL_STEP_Y == 8
        add a,a
        add a,a
        add a,a
        ld (fall_y),a           ; πόσες γραμμές έχουν πέσει
        ld c,0
.col    ld hl,gap
        ld a,c
        add a,l
        ld l,a
        ld a,(hl)
        cp #FF
        jr z,.next
        push bc
        ; τα φόντα από την κορυφή ώς το κενό
        ld b,a                  ; B = γραμμή του κενού
        ld a,c                  ; A = κελί
.bg     push af
        push bc
        call draw_bg
        pop bc
        pop af
        add a,COLS
        dec b
        jp p,.bg
        pop bc
        push bc
        ; τα candies πάνω από το κενό, μετατοπισμένα
        ld hl,gap
        ld a,c
        add a,l
        ld l,a
        ld b,(hl)               ; πόσα candies πέφτουν
        ld a,c                  ; κελί
.candy  dec b
        jp m,.new
        push af
        push bc
        ld l,a
        ld h,board>>8
        push hl
        call cell_xy
        ld a,(fall_y)
        add a,b
        ld b,a
        pop hl
        ld a,(hl)
        call draw_candy_at
        pop bc
        pop af
        add a,COLS
        jr .candy
.new    ; το καινούργιο, πάνω από την κορυφή και κομμένο
        pop bc
        push bc
        ld hl,nextc
        ld a,c
        add a,l
        ld l,a
        ld e,(hl)
        ld a,c
        call cell_xy            ; C = στήλη, B = BOARD_Y
        ld a,(fall_y)
        add a,b
        sub CELL_H
        ld b,a
        ld a,e
        call draw_candy_at
        pop bc
.next   inc c
        ld a,c
        cp COLS
        jr c,.col
        ret

; Κάθε κολόνα που πέφτει κατεβαίνει μία θέση· το nextc μπαίνει στην κορυφή.
fall_commit:
        ld c,0
.col    ld hl,gap
        ld a,c
        add a,l
        ld l,a
        ld a,(hl)
        cp #FF
        jr z,.next
        ld b,a                  ; γραμμή του κενού
        add a,a
        add a,a
        add a,a
        add a,c
        ld l,a
        ld h,board>>8           ; HL = το κενό
.shift  dec b
        jp m,.top
        ld a,l
        sub COLS
        ld e,a
        ld d,h
        ld a,(de)
        ld (hl),a
        ld l,e
        jr .shift
.top    ld de,nextc
        ld a,c
        add a,e
        ld e,a
        ld a,(de)
        ld (hl),a
.next   inc c
        ld a,c
        cp COLS
        jr c,.col
        ret
