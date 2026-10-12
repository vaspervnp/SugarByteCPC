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
.cell   ld a,(hl)                ; τα υλικά μένουν στη θέση τους
        cp EMPTY
        jr z,.free
        bit 5,a
        ld c,a
        jr nz,.ok
.free   call blocked
        ld c,EMPTY
        jr nz,.ok
        call rand_colour
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
        call mark_blocker_damage
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
        ld a,b                  ; κενό ή εμπόδιο: δεν ανταλλάσσεται
        cp EMPTY
        ret z
        ld a,c
        cp EMPTY
        ret z
        ld a,b                  ; βόμβα δίπλα σε candy: κίνηση
        cp BOMB
        jr z,.bomb_b
        ld a,c
        cp BOMB
        jr z,.bomb_c
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
.bomb_b bit 5,c                 ; ... όχι δίπλα σε υλικό
        ret nz
        scf
        ret
.bomb_c bit 5,b
        ret nz
        scf
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
; Βαρύτητα (plan.md §8.4), ένα κελί τη φορά. Σε κάθε κολόνα: το χαμηλότερο
; κενό που μπορεί να γεμίσει, και το τμήμα από πάνω του ώς το πρώτο εμπόδιο
; (ή την κορυφή). Ό,τι είναι στο τμήμα κατεβαίνει μία θέση· αν το τμήμα αρχίζει
; στην κορυφή, μπαίνει καινούργιο candy. Τίποτα δεν περνάει από εμπόδιο.

; L = κελί -> NZ αν το κελί είναι εμπόδιο ή τρύπα. Δεν πειράζει HL.
blocked:
        set 7,l                 ; cell = board | #80
        ld a,(hl)
        res 7,l
        and 7
        ret

; gap[x] = γραμμή του κενού που γεμίζει (#FF = κανένα), segtop[x] = πρώτη
; γραμμή του τμήματος, nextc[x] = το candy που μπαίνει. NZ αν κάτι πέφτει.
fall_scan:
        ld c,0
        ld ixh,0
.col    ld d,ROWS-1             ; D = υποψήφιο κενό
.try    ld a,d
        add a,a
        add a,a
        add a,a
        add a,c
        ld l,a
        ld h,board>>8
        ld a,(hl)
        cp EMPTY
        jr nz,.up
        call blocked
        jr nz,.up
        ld e,d
.scan   dec e                   ; από πάνω: κενά ώς την κορυφή, ή ένα candy;
        jp m,.top
        ld a,l
        sub COLS
        ld l,a
        call blocked
        jr nz,.up               ; εμπόδιο πριν από candy: δεν γεμίζει
        ld a,(hl)
        cp EMPTY
        jr z,.scan
.seg    dec e                   ; βρέθηκε candy: πού αρχίζει το τμήμα;
        jp m,.top
        ld a,l
        sub COLS
        ld l,a
        call blocked
        jr z,.seg
        inc e
        ld a,e
        jr .store
.top    xor a
.store  ld hl,segtop
        ld b,a
        ld a,c
        call add_hl_a
        ld (hl),b
        ld ixh,1
        ld a,d
        jr .gap
.up     dec d
        jp p,.try
        ld a,#FF
.gap    ld hl,gap
        ld d,a                  ; D = το κενό (το rand_colour χαλάει το B)
        ld a,c
        call add_hl_a
        ld (hl),d
        ld hl,nextc
        ld a,c
        call add_hl_a
        call rand_colour
        ld (hl),a
        ld a,d                  ; γεμίζει από την κορυφή; ίσως υλικό
        cp #FF
        jr z,.nofill
        push hl
        ld hl,segtop
        ld a,c
        call add_hl_a
        ld a,(hl)
        pop hl
        or a
        call z,try_ingredient
.nofill inc c
        ld a,c
        cp COLS
        jr c,.col
        ld a,ixh
        or a
        ret

; A = βήμα 1..FALL_STEPS: ζωγραφίζει τα τμήματα που πέφτουν.
fall_draw:
        assert FALL_STEP_Y == 8
        add a,a
        add a,a
        add a,a
        ld (fall_y),a           ; πόσες γραμμές έχουν πέσει
        ld c,0
.col    ld hl,gap
        ld a,c
        call add_hl_a
        ld a,(hl)
        cp #FF
        jp z,.next
        push bc
        ld e,a                  ; E = το κενό
        ld hl,segtop
        ld a,c
        call add_hl_a
        ld d,(hl)               ; D = η κορυφή του τμήματος
        ld a,e
        sub d
        ld b,a                  ; B = πόσα κελιά πέφτουν
        ld a,d
        add a,a
        add a,a
        add a,a
        add a,c
        ld (fall_c0),a
        push bc
        push de
.bg     push af                 ; τα φόντα του τμήματος, μαζί με το κενό
        push bc
        call draw_bg
        pop bc
        pop af
        add a,COLS
        dec b
        jp p,.bg
        pop de
        pop bc
        ld a,(fall_c0)
.candy  dec b                   ; τα candies του τμήματος, μετατοπισμένα
        jp m,.new
        push af
        push bc
        push de
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
        pop de
        pop bc
        pop af
        add a,COLS
        jr .candy
.new    pop bc
        push bc
        ld a,d                  ; καινούργιο μόνο αν το τμήμα αρχίζει στην κορυφή
        or a
        jr nz,.done
        ld hl,nextc
        ld a,c
        call add_hl_a
        ld e,(hl)
        ld a,c
        call cell_xy            ; C = στήλη, B = BOARD_Y
        ld a,(fall_y)
        add a,b
        sub CELL_H              ; πάνω από το ταμπλό: κόβεται
        ld b,a
        ld a,e
        call draw_candy_at
.done   pop bc
.next   inc c
        ld a,c
        cp COLS
        jp c,.col
        ret

; Κάθε τμήμα που πέφτει κατεβαίνει μία θέση.
fall_commit:
        ld c,0
.col    ld hl,gap
        ld a,c
        call add_hl_a
        ld a,(hl)
        cp #FF
        jr z,.next
        ld e,a
        ld hl,segtop
        ld a,c
        call add_hl_a
        ld d,(hl)
        ld a,e
        sub d
        ld b,a                  ; B = πόσα κελιά πέφτουν
        ld a,e
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
        ld l,a
        ld e,(hl)               ; το από πάνω ...
        ld a,l
        add a,COLS
        ld l,a
        ld (hl),e               ; ... κατεβαίνει
        ld a,l
        sub COLS
        ld l,a
        jr .shift
.top    ld a,d                  ; η κορυφή του τμήματος: καινούργιο ή κενό
        or a
        ld a,EMPTY
        jr nz,.put
        push hl
        ld hl,nextc
        ld a,c
        call add_hl_a
        ld a,(hl)
        pop hl
.put    ld (hl),a
.next   inc c
        ld a,c
        cp COLS
        jr c,.col
        ret
