; cells.asm — τα ειδικά κελιά: ζελέ, γλάσο, σοκολάτα, γλυκόριζα (plan.md §3.3, §6)
;
; cell[]: bits 0-2 τύπος (C_*), 3-4 στρώματα γλάσου, 5-6 στρώματα ζελέ, 7 βρώμικο.
; Στα εμπόδια (γλάσο, σοκολάτα, γλυκόριζα) και στις τρύπες δεν κάθεται candy:
; board[] = EMPTY, και η βαρύτητα δεν περνάει από μέσα τους.

; C = κελί -> A = καρέ του cells_gfx. Πειράζει B, HL.
cell_frame:
        ld a,c
        or cell&#FF
        ld l,a
        ld h,cell>>8
        ld a,(hl)
        ld b,a
        and 7
        jr nz,.special
        ld a,b
        and JELLY_MASK
        jr z,.plain
        cp 2<<JELLY_SHIFT
        ld a,CELLS_JELLY+1
        ret z
        dec a
        ret
.plain  ld a,c                  ; σκακιέρα: (cx ^ cy) & 1
        rrca
        rrca
        rrca
        xor c
        and 1
        ret
.special
        cp C_HOLE
        ld a,CELLS_BOARD+2
        ret z
        ld a,b
        and 7
        cp C_ICING
        jr nz,.blocker
        ld a,b                  ; γλάσο: 3 στρώματα -> icing3 (καρέ 5) ...
        rrca
        rrca
        rrca
        and 3
        neg
        add a,CELLS_ICING+3
        ret
.blocker
        sub C_CHOCOLATE         ; 0 σοκολάτα, 1 γλυκόριζα
        add a,CELLS_BLOCKER
        ret

; C = κελί -> nb[0..3] οι τέσσερις γείτονες (#FF = έξω). Δεν πειράζει BC, DE.
neighbours:
        ld hl,nb
        ld a,c
        cp COLS
        ld a,#FF
        jr c,.up
        ld a,c
        sub COLS
.up     ld (hl),a
        inc hl
        ld a,c
        cp COLS*(ROWS-1)
        ld a,#FF
        jr nc,.down
        ld a,c
        add a,COLS
.down   ld (hl),a
        inc hl
        ld a,c
        and 7
        ld a,#FF
        jr z,.left
        ld a,c
        dec a
.left   ld (hl),a
        inc hl
        ld a,c
        and 7
        cp 7
        ld a,#FF
        jr z,.right
        ld a,c
        inc a
.right  ld (hl),a
        ret

; A = κελί -> NZ αν είναι εμπόδιο που σπάει (γλάσο, σοκολάτα, γλυκόριζα).
; Δεν πειράζει BC, DE, HL.
breakable:
        push hl
        or cell&#FF
        ld l,a
        ld h,cell>>8
        ld a,(hl)
        and 7
        cp C_ICING
        jr c,.no
        cp C_LICORICE+1
        jr nc,.no
        pop hl
        or a                    ; NZ
        ret
.no     pop hl
        xor a
        ret

; Μετά το RESOLVE: κάθε εμπόδιο δίπλα σε candy που σκάει παθαίνει ζημιά
; (matched = M_BLOCKER), μία φορά ανά κίνηση όσα candies κι αν σκάσουν δίπλα του.
mark_blocker_damage:
        ld c,0
.cell   ld h,matched>>8
        ld a,c
        or matched&#FF
        ld l,a
        ld a,(hl)
        and #FF-M_BLOCKER
        jr z,.next
        call neighbours
        ld de,nb
        ld b,4
.nb     ld a,(de)
        inc de
        cp #FF
        jr z,.nnb
        ld l,a
        call breakable
        jr z,.nnb
        ld a,l
        or matched&#FF
        ld l,a
        ld h,matched>>8
        set M_BLOCKER_BIT,(hl)
.nnb    djnz .nb
.next   inc c
        ld a,c
        cp COLS*ROWS
        jr c,.cell
        ret

; C = κελί που μόλις καθάρισε, A = matched[]: σπάει ένα στρώμα εμποδίου, ή
; ένα στρώμα ζελέ κάτω από candy που έσκασε (100 πόντοι). Δεν πειράζει C.
apply_damage:
        ld b,a
        ld a,c
        or cell&#FF
        ld l,a
        ld h,cell>>8
        ld a,b
        and M_BLOCKER
        jr z,.jelly
        ld a,(hl)
        and 7
        cp C_ICING
        jr nz,.gone
        ld a,(hl)               ; γλάσο: ένα στρώμα λιγότερο
        sub 1<<ICING_SHIFT
        ld (hl),a
        and ICING_MASK
        ret nz
.gone   cp C_CHOCOLATE
        jr nz,.clear
        ld a,1
        ld (choc_broken),a
.clear  ld a,(hl)               ; το εμπόδιο έφυγε: κανονικό κελί
        and #FF-7-ICING_MASK
        ld (hl),a
        ret
.jelly  ld a,(hl)
        and JELLY_MASK
        ret z
        ld a,(hl)
        sub 1<<JELLY_SHIFT
        ld (hl),a
        push bc
        ld de,#0100
        call add_score_chain
        pop bc
        ret

; Μετά από κίνηση που δεν έσπασε σοκολάτα: μία σοκολάτα τρώει ένα γειτονικό
; candy. Αρχίζει από τυχαίο κελί για να μην απλώνεται πάντα προς τα ίδια.
spread_chocolate:
        ld a,(choc_broken)
        or a
        ret nz
        call rand
        and 63
        ld c,a
        ld b,COLS*ROWS
.cell   push bc
        ld a,c
        or cell&#FF
        ld l,a
        ld h,cell>>8
        ld a,(hl)
        and 7
        cp C_CHOCOLATE
        jr nz,.next
        call neighbours
        ld de,nb
        ld b,4
.nb     ld a,(de)
        inc de
        cp #FF
        jr z,.nnb
        ld l,a
        ld h,board>>8
        ld a,(hl)
        cp EMPTY
        jr z,.nnb
        bit 5,a                 ; τα υλικά δεν τρώγονται
        jr nz,.nnb
        call blocked
        jr nz,.nnb
        ld (hl),EMPTY           ; φαγώθηκε
        set 7,l
        ld a,(hl)
        and #FF-7-ICING_MASK
        or C_CHOCOLATE
        ld (hl),a
        ld a,l
        and 63
        call mark_dirty
        pop bc
        ret
.nnb    djnz .nb
.next   pop bc
        inc c
        ld a,c
        and 63
        ld c,a
        djnz .cell
        ret

; Ένα ταμπλό επίδειξης ώσπου να έρθουν οι πίστες (βήμα 15): ζελέ στη μέση,
; γλάσο, σοκολάτα και γλυκόριζα στη βάση, όπου δεν φράζουν τίποτα από κάτω.
J1      equ 1<<JELLY_SHIFT
J2      equ 2<<JELLY_SHIFT
I3      equ C_ICING+(3<<ICING_SHIFT)
CH      equ C_CHOCOLATE
LI      equ C_LICORICE
demo_cells:
        db 0, 0, 0, 0, 0, 0, 0, 0
        db 0,J1,J1, 0, 0,J1,J1, 0
        db 0,J1,J2,J2,J2,J2,J1, 0
        db 0, 0,J2,J2,J2,J2, 0, 0
        db 0, 0, 0,J1,J1, 0, 0, 0
        db 0, 0, 0, 0, 0, 0, 0, 0
        db 0, 0, 0, 0, 0, 0, 0,LI
        db CH,0, 0,I3,I3, 0, 0,LI
