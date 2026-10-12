; gfx.asm — πίνακες διευθύνσεων και ρουτίνες blit (plan.md §4)

; LINE_LO/LINE_HI: η διεύθυνση κάθε γραμμής οθόνης. CELL_SCR: κάθε κελιού.
build_tables:
        ld hl,#C000
        ld de,LINE_LO
.line   ld a,l
        ld (de),a
        inc d
        ld a,h
        ld (de),a
        dec d
        call next_line_hl
        inc e
        ld a,e
        cp 200
        jr c,.line

        ld ix,CELL_SCR
        ld a,BOARD_Y
.row    push af
        call line_addr
        ld b,COLS
.col    ld (ix+0),l
        ld (ix+1),h
        inc ix
        inc ix
        ld de,CELL_WB
        add hl,de
        djnz .col
        pop af
        add a,CELL_H
        cp BOARD_Y+ROWS*CELL_H
        jr c,.row
        ret

; HL = διεύθυνση οθόνης -> η ίδια θέση στην επόμενη γραμμή
next_line_hl:
        ld a,h
        add a,8
        ld h,a
        ret nc
        ld a,l
        add a,#50
        ld l,a
        ld a,h
        adc a,#C0
        ld h,a
        ret

; A = γραμμή οθόνης -> HL = η διεύθυνσή της. Δεν πειράζει BC, DE.
line_addr:
        ld l,a
        ld h,LINE_LO>>8
        ld a,(hl)
        inc h
        ld h,(hl)
        ld l,a
        ret

; A = κελί 0-63 -> HL = η διεύθυνσή του στην οθόνη. Δεν πειράζει BC, DE.
cell_addr:
        add a,a
        add a,CELL_SCR&#FF
        ld l,a
        ld h,CELL_SCR>>8
        ld a,(hl)
        inc l
        ld h,(hl)
        ld l,a
        ret

; A = κελί -> C = byte στήλης, B = γραμμή οθόνης της πάνω αριστερής γωνίας
cell_xy:
        ld b,a
        and 7
        ld c,a
        add a,a
        add a,c
        add a,a
        ld c,a                  ; cx * 6
        ld a,b
        and #38                 ; cy * 8
        ld b,a
        add a,a
        add a,b                 ; cy * 24
        add a,BOARD_Y
        ld b,a
        ret

; HL = πίνακας από words, A = δείκτης -> DE = το word
ptr_lookup:
        add a,a
        add a,l
        ld l,a
        jr nc,.nc
        inc h
.nc     ld e,(hl)
        inc hl
        ld d,(hl)
        ret

; ---------------------------------------------------------------------------
; HL = οθόνη, DE = πηγή. Αδιαφανές 6 bytes x 24 γραμμές με LDI.
blit_cell:
        ex de,hl
        ld bc,CELL_WB*CELL_H
.row    push de                 ; το LDI προχωράει το DE: κράτα την αρχή
        ldi
        ldi
        ldi
        ldi
        ldi
        ldi
        pop de
        ld a,b
        or c
        ret z
        ld a,d
        add a,8
        ld d,a
        jr nc,.row
        ld a,e
        add a,#50
        ld e,a
        ld a,d
        adc a,#C0
        ld d,a
        jr .row

; HL = οθόνη, DE = πηγή. Αδιαφανές 2 bytes x 8 γραμμές (κελί HUD).
blit_hud:
        ex de,hl
        ld bc,HUD_SZ
.row    push de
        ldi
        ldi
        pop de
        ld a,b
        or c
        ret z
        ld a,d
        add a,8
        ld d,a
        jr nc,.row
        ld a,e
        add a,#50
        ld e,a
        ld a,d
        adc a,#C0
        ld d,a
        jr .row

; HL = οθόνη, DE = πηγή (mask,data πλεγμένα), A = γραμμές. 6 bytes δεδομένων.
; Διαβάζει την πηγή με POP: οι διακοπές είναι κλειστές σε όλο το παιχνίδι.
blit_masked:
        di                      ; το SP δείχνει στα δεδομένα: καμία διακοπή εδώ
        ld ixl,a
        ld (.sp+1),sp
        ex de,hl
        ld sp,hl
        ex de,hl
.row    ld d,h
        ld e,l
        repeat CELL_WB-1
        pop bc                  ; C = μάσκα, B = δεδομένα
        ld a,(de)
        and c
        or b
        ld (de),a
        inc de
        rend
        pop bc
        ld a,(de)
        and c
        or b
        ld (de),a
        ld a,h
        add a,8
        ld h,a
        jr nc,.next
        ld a,l
        add a,#50
        ld l,a
        ld a,h
        adc a,#C0
        ld h,a
.next   dec ixl
        jr nz,.row
.sp     ld sp,0
        ei
        ret

; A = γραμμή, B = γραμμές, C = πρώτο byte, D = πλάτος σε bytes, E = τιμή
fill_rect:
.row    push af
        call line_addr
        push bc
        ld b,0
        add hl,bc
        ld b,d
.x      ld (hl),e
        inc hl
        djnz .x
        pop bc
        pop af
        inc a
        djnz .row
        ret

; Σβήνει όλη την οθόνη.
cls:
        ld hl,#C000
        ld de,#C001
        ld bc,#3FFF
        ld (hl),0
        ldir
        ret

; ---------------------------------------------------------------------------
; Τα κομμάτια ενός κελιού

; A = κελί: το φόντο του (αδιαφανές — σβήνει ό,τι υπήρχε).
draw_bg:
        ld c,a
        call cell_addr
        push hl
        call cell_frame
        ld hl,cells_ptr
        call ptr_lookup
        pop hl
        jp blit_cell

; A = τιμή board[], C = byte στήλης, B = γραμμή οθόνης (κάτω από BOARD_Y
; σημαίνει πάνω από το ταμπλό: κόβεται, για τα candies που μπαίνουν).
draw_candy_at:
        call candy_frame
        ret c
        ld hl,candy_ptr
        call ptr_lookup
; DE = πηγή με μάσκα 12x24, C = byte στήλης, B = γραμμή οθόνης (με κόψιμο)
draw_masked_at:
        ld a,b
        sub BOARD_Y
        cp 200
        jr c,.whole
        neg                     ; γραμμές πάνω από το ταμπλό
        cp CELL_H
        ret nc
        push bc
        ld b,a
        ld l,a
        ld h,0
        add hl,hl
        add hl,hl
        ld a,b
        ld b,h
        ld c,l
        add hl,hl
        add hl,bc               ; 12 bytes ανά γραμμή πηγής
        add hl,de
        ex de,hl
        pop bc
        ld b,a
        ld a,CELL_H
        sub b
        ld b,BOARD_Y
        jr .go
.whole  ld a,CELL_H
.go     push af
        ld a,b
        call line_addr
        ld b,0
        add hl,bc
        pop af
        jp blit_masked

; A = τιμή board[] -> A = καρέ του candy_gfx· carry αν δεν ζωγραφίζεται τίποτα.
candy_frame:
        cp EMPTY
        scf
        ret z
        bit 5,a
        jr nz,.ingredient
        push bc
        ld b,a
        and 7
        cp 6
        jr z,.bomb
        ld c,a                  ; χρώμα
        ld a,b
        rrca
        rrca
        rrca
        and 3                   ; μορφή
        ld b,a
        add a,a
        add a,b
        add a,a                 ; μορφή * 6
        add a,c
        pop bc
        ret
.bomb   pop bc
        ld a,CANDY_BOMB
        or a
        ret
.ingredient
        and 1
        add a,CANDY_INGREDIENT
        ret

; A = κελί: το candy του στη θέση του
draw_candy_cell:
        push af
        call cell_xy
        pop af
        ld l,a
        ld h,board>>8
        ld a,(hl)
        jp draw_candy_at

; A = κελί, D = καρέ επικάλυψης
draw_overlay:
        call cell_addr
        ld a,d
        push hl
        ld hl,overlay_ptr
        call ptr_lookup
        pop hl
        ld a,CELL_H
        jp blit_masked

; A = κελί: φόντο, candy, και δείκτης ή επιλογή αν είναι εκεί.
draw_cell:
        ld (dc_i),a
        call draw_bg
        ld a,(dc_i)
        call draw_candy_cell
        ld a,(dc_i)
        ld c,a
        ld a,(sel)
        cp c
        ld d,OVERLAY_CURSOR+1   ; η επιλογή: κυανή, σταθερή
        jr z,.over
        ld a,(state)
        cp S_IDLE
        ret nz
        ld a,(cursor)
        cp c
        ret nz
        ld a,(blink_t)
        and 16
        ret nz
        ld d,OVERLAY_CURSOR     ; ο δείκτης: άσπρος, αναβοσβήνει
.over   ld a,c
        jp draw_overlay

; Όλο το ταμπλό — μόνο στην αρχή (≈ 10 καρέ).
draw_board_all:
        xor a
.l      push af
        call draw_cell
        pop af
        inc a
        cp COLS*ROWS
        jr c,.l
        ret

; ---------------------------------------------------------------------------
; Η λίστα των βρώμικων (plan.md §9.1)

; A = κελί: θα ξαναζωγραφιστεί. Δεν πειράζει BC, DE.
mark_dirty:
        push hl
        push af
        or cell&#FF
        ld l,a
        ld h,cell>>8
        bit 7,(hl)
        jr nz,.already
        set 7,(hl)
        ld hl,dq_n
        inc (hl)
        ld a,(dq_tail)
        ld l,a
        inc a
        and 63
        ld (dq_tail),a
        ld a,l
        or dirty_q&#FF
        ld l,a
        ld h,dirty_q>>8
        pop af
        ld (hl),a
        pop hl
        ret
.already
        pop af
        pop hl
        ret

; Ζωγραφίζει ώς DRAW_BUDGET κελιά από τη λίστα.
render_dirty:
        ld b,DRAW_BUDGET
.l      ld a,(dq_n)
        or a
        ret z
        dec a
        ld (dq_n),a
        ld a,(dq_head)
        ld l,a
        inc a
        and 63
        ld (dq_head),a
        ld a,l
        or dirty_q&#FF
        ld l,a
        ld h,dirty_q>>8
        ld a,(hl)
        or cell&#FF
        ld l,a
        res 7,(hl)
        and 63
        push bc
        call draw_cell
        pop bc
        djnz .l
        ret

; Αδειάζει τη λίστα χωρίς να ζωγραφίσει (μετά από ολόκληρο ταμπλό).
clear_dirty:
        xor a
        ld (dq_n),a
        ld (dq_head),a
        ld (dq_tail),a
        ld hl,cell
        ld b,COLS*ROWS
.l      res 7,(hl)
        inc l
        djnz .l
        ret

; ---------------------------------------------------------------------------
; Η διεύθυνση κάθε καρέ: <set>_gfx + καρέ * <SET>_SZ
candy_ptr:
        repeat 27,n
        dw candy_gfx+(n-1)*CANDY_SZ
        rend
cells_ptr:
        repeat 10,n
        dw cells_gfx+(n-1)*CELLS_SZ
        rend
overlay_ptr:
        repeat 14,n
        dw overlay_gfx+(n-1)*OVERLAY_SZ
        rend
        assert CANDY_N == 27 && CELLS_N == 10 && OVERLAY_N == 14
