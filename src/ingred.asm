; ingred.asm — τα υλικά: κεράσι και φουντούκι (plan.md §3.2, §6)
;
; board[] = INGREDIENT | 0 (κεράσι) ή | 1 (φουντούκι). Δεν ταιριάζουν, δεν
; σκάνε από ειδικά, δεν τα τρώει η σοκολάτα· πέφτουν με τη βαρύτητα και
; ανταλλάσσονται όπως τα candies. Όταν φτάσουν στη βάση, μαζεύονται.

; HL = nextc[x] μιας κολόνας που γεμίζει από την κορυφή: ίσως μπει υλικό αντί
; για candy. Ένα τη φορά στο ταμπλό· πιθανότητα 1 / (ingr_odds+1) σε κάθε γέμισμα.
; Δεν πειράζει HL, C.
try_ingredient:
        ld a,(ingr_spawn)
        or a
        ret z
        ld a,(ingr_board)
        or a
        ret nz
        call rand
        ld b,a
        ld a,(ingr_odds)
        and b
        ret nz
        ld a,(ingr_spawn)
        dec a
        ld (ingr_spawn),a
        ld a,1
        ld (ingr_board),a
        call rand
        and 1
        or INGREDIENT
        ld (hl),a
        ret

; Όσα υλικά κάθονται στη βάση φεύγουν: 1.000 πόντοι το καθένα.
; NZ αν μαζεύτηκε κάτι (άρα υπάρχει κενό να γεμίσει).
collect_ingredients:
        ld c,0
        ld l,COLS*(ROWS-1)
        ld h,board>>8
.cell   ld a,(hl)
        cp EMPTY
        jr z,.next
        bit 5,a
        jr z,.next
        ld (hl),EMPTY
        inc c
        push bc
        push hl
        ld a,(ingr_board)
        dec a
        ld (ingr_board),a
        ld a,(ingr_left)
        sub 1
        daa
        ld (ingr_left),a
        ld de,#1000
        call add_score_chain    ; και hud_dirty
        pop hl
        push hl
        ld a,l
        push af
        call draw_bg
        pop af
        ld d,OVERLAY_STAR+1     ; αστέρι ώσπου να το σκεπάσει η πτώση
        call draw_overlay
        pop hl
        pop bc
.next   inc l
        ld a,l
        cp COLS*ROWS
        jr c,.cell
        ld a,c
        or a
        ret z
        ld hl,sfx_collect
        call play_sfx
        or 1                    ; NZ
        ret

; Στο HUD: ένα κεράσι και «× NN» — πόσα υλικά μένουν να κατέβουν.
HUD_GOAL_Y      equ 42
hud_goal_init:
        ld a,HUD_GOAL_Y
        call line_addr
        ld bc,HUD_XB+2
        add hl,bc
        ld a,CANDY_INGREDIENT
        push hl
        ld hl,candy_ptr
        call ptr_lookup
        pop hl
        ld a,CELL_H
        call blit_masked
        ld a,HUD_GOAL_Y+8
        ld (digit_y),a
        ld a,HUD_SYMBOLS+2      ; ×
        ld c,HUD_XB+10
        jp draw_glyph

hud_goal_update:
        ld a,HUD_GOAL_Y+8
        ld (digit_y),a
        ld hl,ingr_left
        ld b,1
        ld c,HUD_XB+12
        jp draw_bcd
