; hw.asm — Gate Array, CRTC, VSYNC, πληκτρολόγιο

; Mode 0, χωρίς ROM, η παλέτα του plan.md §2, οθόνη στο #C000.
hw_init:
        ld bc,#7F8C             ; Mode 0, κάτω και πάνω ROM κλειστές
        out (c),c
        ld hl,ink_tab
        ld e,0
.ink    ld bc,#7F00
        out (c),e               ; διάλεξε pen (16 = περίγραμμα)
        ld a,(hl)
        out (c),a
        inc hl
        inc e
        ld a,e
        cp 17
        jr c,.ink
        ld bc,#BC0C             ; CRTC R12/R13: οθόνη στο #C000, offset 0
        out (c),c
        ld bc,#BD30
        out (c),c
        ld bc,#BC0D
        out (c),c
        ld bc,#BD00
        out (c),c
        ld hl,#C9FB             ; #0038: EI : RET, αν ποτέ ανοίξουν οι διακοπές
        ld (#0038),hl
        ret

; Τα χρώματα του Gate Array (| #40) για τα pens 0-15 και το περίγραμμα.
ink_tab:
        db #54,#4B,#40,#44,#53  ; μαύρο, άσπρο, γκρι, σκούρο μπλε, κυανό
        db #4C,#5C              ; κόκκινο
        db #4E,#5E              ; πορτοκαλί, σκιά πορτοκαλί+κίτρινου
        db #4A                  ; κίτρινο
        db #52,#56              ; πράσινο
        db #57,#55              ; μπλε
        db #4D,#58              ; μωβ
        db #54                  ; περίγραμμα

; Περιμένει την αρχή του επόμενου VSYNC. Ο βρόχος του παιχνιδιού ξεκινάει εδώ
; (το tools/cpcrun.py μετράει καρέ με breakpoint σε αυτή την ετικέτα).
wait_vbl:
        ld b,#F5
.in     in a,(c)                ; μέσα σε VSYNC: περίμενε να τελειώσει
        rra
        jr c,.in
.out    in a,(c)
        rra
        jr nc,.out
        ret

; Διαβάζει τις 10 γραμμές του πληκτρολογίου μέσω του PSG (reg 14) στο keymap.
read_matrix:
        ld bc,#F40E
        out (c),c
        ld bc,#F6C0             ; PSG: διάλεξε καταχωρητή
        out (c),c
        xor a
        out (c),a
        ld bc,#F792             ; PPI A: είσοδος
        out (c),c
        ld hl,keymap
        ld d,#40
.row    ld b,#F6
        out (c),d               ; PSG: διάβασε, γραμμή D & 15
        ld b,#F4
        in a,(c)
        ld (hl),a
        inc hl
        inc d
        ld a,d
        cp #4A
        jr c,.row
        ld bc,#F782             ; PPI A: έξοδος
        out (c),c
        ld bc,#F600
        out (c),c
        ret

; joy = ό,τι κρατιέται, joy_edge = ό,τι πατήθηκε σε αυτό το καρέ.
read_input:
        call read_matrix
        ld hl,input_map
        ld c,0
.key    ld a,(hl)
        cp #FF
        jr z,.done
        inc hl
        ld de,keymap
        add a,e
        ld e,a
        ld a,(de)
        and (hl)                ; 0 = πατημένο
        inc hl
        jr nz,.up
        ld a,c
        or (hl)
        ld c,a
.up     inc hl
        jr .key
.done   ld a,(joy)
        ld (joy_prev),a
        cpl
        and c
        ld (joy_edge),a
        ld a,c
        ld (joy),a
        ret

; γραμμή, bit, J_*
input_map:
        db 0,%00000001,J_UP     ; βελάκια
        db 0,%00000100,J_DOWN
        db 1,%00000001,J_LEFT
        db 0,%00000010,J_RIGHT
        db 5,%10000000,J_FIRE   ; SPACE
        db 9,%00000001,J_UP     ; joystick 0
        db 9,%00000010,J_DOWN
        db 9,%00000100,J_LEFT
        db 9,%00001000,J_RIGHT
        db 9,%00010000,J_FIRE
        db 9,%00100000,J_FIRE
        db #FF

; A = οι κατευθύνσεις που πρέπει να εκτελεστούν σε αυτό το καρέ: αμέσως στο
; πάτημα, μετά από REP_FIRST καρέ αν κρατιέται, και ύστερα κάθε REP_NEXT.
get_dir:
        ld a,(joy)
        and J_UP|J_DOWN|J_LEFT|J_RIGHT
        jr nz,.held
        ld (rep_cnt),a
        ret
.held   ld b,a
        ld a,(joy_edge)
        and J_UP|J_DOWN|J_LEFT|J_RIGHT
        jr z,.rep
        ld a,REP_FIRST
        ld (rep_cnt),a
        ld a,b
        ret
.rep    ld hl,rep_cnt
        dec (hl)
        ld a,0
        ret nz
        ld (hl),REP_NEXT
        ld a,b
        ret
