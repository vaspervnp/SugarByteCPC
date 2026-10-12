; hw.asm — Gate Array, CRTC, VSYNC, πληκτρολόγιο

; Mode 0, χωρίς ROM, η παλέτα του plan.md §2, οθόνη overscan 192x248 στο #8000.
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
        ld hl,crtc_tab          ; ο CRTC: overscan
.crtc   ld a,(hl)
        cp #FF
        jr z,.crtc_done
        ld b,#BC
        out (c),a
        inc hl
        ld a,(hl)
        inc hl
        inc b
        out (c),a
        jr .crtc
.crtc_done
        ld a,#C3                ; #0038: JP int_handler (IM 1)
        ld (#0038),a
        ld hl,int_handler
        ld (#0039),hl
        im 1
        ret

; Overscan 192x248 (cpcwiki, Programming:Overscan). R12 bits 2-3 = σελίδα
; 32 KB: η διεύθυνση κάνει κρατούμενο από το #8000 στο #C000. R13 = 16 words:
; η γραμμή χαρακτήρων 21 ξεκινά ακριβώς στο #C000, καμία δεν κόβεται στη μέση.
crtc_tab:
        db 0,63, 1,48, 2,50, 3,#8E, 4,38, 5,0, 6,31, 7,34, 9,7
        db 12,#2C, 13,16
        db #FF

; Τα χρώματα του Gate Array (| #40) για τα pens 0-15 και το περίγραμμα.
INK0    equ #54                 ; μαύρο
INK1    equ #4B                 ; άσπρο
INK2    equ #40                 ; γκρι
INK3    equ #44                 ; σκούρο μπλε
INK4    equ #53                 ; κυανό
INK5    equ #4C                 ; κόκκινο
INK6    equ #5C
INK7    equ #4E                 ; πορτοκαλί
INK8    equ #5E                 ; σκιά πορτοκαλί + κίτρινου
INK9    equ #4A                 ; κίτρινο
INK10   equ #52                 ; πράσινο
INK11   equ #56
INK12   equ #57                 ; μπλε
INK13   equ #55
INK14   equ #4D                 ; μωβ
INK15   equ #58
ink_tab:
        db INK0,INK1,INK2,INK3,INK4,INK5,INK6,INK7
        db INK8,INK9,INK10,INK11,INK12,INK13,INK14,INK15
        db INK0                 ; περίγραμμα

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
        di                      ; ο PSG είναι και του ήχου
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
        ei
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
        db 4,%01000000,J_MUSIC  ; M: μουσική ναι/όχι
        db 8,%00000100,J_ESC    ; ESC: κωδικός πίστας
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
