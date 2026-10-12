; raster.asm — δύο παλέτες στην ίδια οθόνη, και ρίγες που κινούνται
;
; Ο Gate Array ζητάει διακοπή κάθε 52 γραμμές, έξι το καρέ, σε σταθερές θέσεις
; ως προς το VSYNC. Με R7 = 34 η εικόνα αρχίζει 40 γραμμές μετά την αρχή του
; VSYNC, άρα οι διακοπές πέφτουν στις γραμμές εικόνας:
;
;   ζώνη 0   -38   πάνω περιθώριο: η παλέτα του τίτλου (με το VSYNC αναμμένο)
;   ζώνη 1    14   μέσα στον τίτλο: περιμένει ώς τη γραμμή 30 και επαναφέρει την
;                  παλέτα του παιχνιδιού. Οι γραμμές 30-31 του τίτλου έχουν μόνο
;                  τα pens 0 και 3, που δεν αλλάζουν: η ραφή δεν φαίνεται
;   ζώνη 5   222   δύο γραμμές πριν το πόδι: άσπρο <-> κόκκινο κάθε 4 καρέ, και
;                  οι ρίγες του ζαχαρωτού μοιάζουν να τρέχουν
;
; Ο τίτλος παίρνει τα έξι χρώματα των candies σε κύκλο: τα γράμματα αλλάζουν
; χρώμα ένα-ένα, χωρίς να «κλέβουν» pens από το ταμπλό.

RASTER_WAIT_SPLIT equ 236       ; djnz των 4 µs: από τη γραμμή 14 στη 30
RASTER_WAIT_FOOT  equ 15        ; από τη γραμμή 222 στην 224
RASTER_ROT_FRAMES equ 8         ; καρέ ανά βήμα του κύκλου του τίτλου
RASTER_FOOT_FRAMES equ 4        ; καρέ ανά βήμα των ριγών

; IM 1, 300 Hz.
int_handler:
        push af
        push bc
        push de
        push hl
        ld b,#F5                ; VSYNC αναμμένο: η πρώτη διακοπή του καρέ
        in a,(c)
        rra
        jr nc,.zone
        xor a
        ld (int_zone),a
        call raster_top
        call sound_tick
        jr .out
.zone   ld hl,int_zone
        inc (hl)
        ld a,(hl)
        dec a
        jr nz,.not1
        call raster_split
        jr .out
.not1   cp 4
        call z,raster_foot
.out    pop hl
        pop de
        pop bc
        pop af
        ei
        ret

; Ζώνη 0: τα χρώματα του τίτλου, γυρισμένα κατά raster_rot.
raster_top:
        ld hl,raster_t
        inc (hl)
        ld a,(hl)
        and RASTER_FOOT_FRAMES-1
        jr nz,.nofoot
        ld a,(foot_phase)
        xor 1
        ld (foot_phase),a
.nofoot ld a,(hl)
        and RASTER_ROT_FRAMES-1
        jr nz,.same
        ld a,(raster_rot)
        inc a
        cp 6
        jr c,.rot
        xor a
.rot    ld (raster_rot),a
.same   ld hl,title_map         ; pen, βάση/σκιά, χρώμα — ×11
        ld b,11
.pen    push bc
        ld e,(hl)               ; E = pen
        inc hl
        ld d,(hl)               ; D = 0 βάση, 1 σκιά
        inc hl
        ld a,(raster_rot)
        add a,(hl)              ; το χρώμα που παίρνει τη θέση του
        inc hl
        cp 6
        jr c,.mod
        sub 6
.mod    add a,a
        add a,d
        push hl
        ld hl,col_inks
        call add_hl_a
        ld a,(hl)
        pop hl
        ld bc,#7F00
        out (c),e
        out (c),a
        pop bc
        djnz .pen
        ld bc,#7F01             ; το άσπρο, μετά το πόδι του προηγούμενου καρέ
        out (c),c
        ld a,INK1
        out (c),a
        ret

; Ζώνη 1: η παλέτα του παιχνιδιού, ακριβώς στη ραφή κάτω από τον τίτλο.
; Τα χρώματα φορτώνονται στους καταχωρητές (και στο δεύτερο σετ) πριν την
; αναμονή, ώστε η αλλαγή να κρατήσει ~9 µs το pen. Το B μένει #7F: ένα OUTI θα
; το μείωνε και θα έγραφε και στο PPI, στον εκτυπωτή, στις επεκτάσεις.
; Ο κώδικας του παιχνιδιού δεν χρησιμοποιεί το δεύτερο σετ (exx).
raster_split:
        exx
        ld bc,#7F09             ; pens 9-12
        ld de,INK9*256+INK10
        ld hl,INK11*256+INK12
        exx
        ld de,INK5*256+INK6     ; pens 5-8
        ld hl,INK7*256+INK8
        ld b,RASTER_WAIT_SPLIT
.w      djnz .w
        ld bc,#7F05
        out (c),c
        out (c),d
        inc c
        out (c),c
        out (c),e
        inc c
        out (c),c
        out (c),h
        inc c
        out (c),c
        out (c),l
        exx
        out (c),c
        out (c),d
        inc c
        out (c),c
        out (c),e
        inc c
        out (c),c
        out (c),h
        inc c
        out (c),c
        out (c),l
        exx
        ld c,13                 ; pens 13-15
        ld a,INK13
        out (c),c
        out (c),a
        inc c
        ld a,INK14
        out (c),c
        out (c),a
        inc c
        ld a,INK15
        out (c),c
        out (c),a
        ret

; Ζώνη 5: στο πόδι, άσπρο και κόκκινο ανάποδα κάθε δεύτερη φάση.
raster_foot:
        ld a,(foot_phase)
        or a
        ret z
        ld b,RASTER_WAIT_FOOT
.w      djnz .w
        ld bc,#7F01
        ld de,INK5*256+INK1
        out (c),c
        out (c),d
        ld c,5
        out (c),c
        out (c),e
        ret

; Τα χρώματα των candies: βάση και σκιά, με τη σειρά των κωδικών 0-5.
col_inks:
        db INK5,INK6, INK7,INK8, INK9,INK8, INK10,INK11, INK12,INK13, INK14,INK15

; Τα pens του τίτλου: pen, 0 βάση / 1 σκιά, χρώμα που έχει στο παιχνίδι.
title_map:
        db 5,0,0, 6,1,0, 7,0,1, 8,1,1, 9,0,2, 10,0,3
        db 11,1,3, 12,0,4, 13,1,4, 14,0,5, 15,1,5
