; voice.asm — φωνή από τον AY: «Sugar Byte!», «Sweet!», «Delicious!», «Sugar Crush!»
;
; Τα δείγματα (tools/voice.py) είναι 4-bit, δύο το byte, 5.500 το δευτερόλεπτο.
; Ο AY δεν έχει DAC: με τόνο και θόρυβο κλειστούς, η ένταση γίνεται το κύμα. Η
; κλίμακά του είναι λογαριθμική, γι' αυτό παίζουν και τα τρία κανάλια μαζί:
; κάθε δείγμα είναι μια τριάδα εντάσεων (voice_tri) με γραμμικό άθροισμα.
;
; Ζουν στα κενά της οθόνης overscan (#C3C0 + k * #800, 8 x 1.088 bytes). Το
; αρχείο τα φέρνει στο #8000, κάτω από τις μνήμες του AMSDOS, και το voice_init
; τα μεταφέρει στα κενά πριν σβηστεί η οθόνη.
;
; Το say κρατάει τη μηχανή όσο μιλάει (~0,5-1 s): η μουσική σωπαίνει, οι
; διακοπές μένουν ανοιχτές για τα raster.

VOICE_D1        equ 11          ; djnz ανάμεσα στο 1ο και το 2ο δείγμα του byte
VOICE_D2        equ 6           ; ... και μετά το 2ο, όπου ο βρόχος κοστίζει ήδη
HOLE_START      equ #C3C0       ; το πρώτο κενό της σελίδας #C000
HOLE_SKIP       equ #3C0        ; από το τέλος ενός κενού στην αρχή του επόμενου

; Από το #8000 στα κενά. Πριν από το πρώτο cls.
voice_init:
        ld hl,voice_load
        ld de,HOLE_START
        ld bc,VOICE_BYTES
.l      ld a,(hl)
        ld (de),a
        inc hl
        inc de
        ld a,d                  ; τέλος του κενού (#xx00 με D & 7 = 0)
        and 7
        or e
        jr nz,.n
        ex de,hl
        push bc
        ld bc,HOLE_SKIP
        add hl,bc
        pop bc
        ex de,hl
.n      dec bc
        ld a,b
        or c
        jr nz,.l
        ret

; HL = η φράση (VOICE_*), DE = το μήκος της (VOICE_*_LEN).
say:
        push hl
        push de
        ld a,1
        ld (speaking),a         ; ο sound_tick δεν αγγίζει τον PSG
        ld a,7                  ; μίκτης: τόνοι και θόρυβοι κλειστοί, port A είσοδος
        ld e,#3F
        call psg_write
        pop ix                  ; IX = bytes
        pop iy                  ; IY = δεδομένα
        ld c,#80                ; ο κωδικός «γράψε» του PSG
.byte   ld a,(iy+0)             ; το πάνω nibble
        rrca
        rrca
        rrca
        rrca
        call .sample
        ld b,VOICE_D1
.w1     djnz .w1
        ld a,(iy+0)             ; το κάτω
        call .sample
        inc iy
        ld a,iyh                ; τέλος του κενού: στο επόμενο
        and 7
        or iyl
        jr nz,.same
        ld de,HOLE_SKIP
        add iy,de
.same   dec ix
        ld a,ixh
        or ixl
        ld b,VOICE_D2
.w2     djnz .w2
        jr nz,.byte
        xor a
        ld (speaking),a         ; ο επόμενος sound_tick ξαναγράφει τα πάντα
        ret

; A = δείγμα (κάτω nibble): η τριάδα του στα κανάλια A, B, C. C = #80.
.sample and 15
        add a,a
        add a,a
        add a,voice_tri&#FF
        ld e,a
        ld d,voice_tri>>8
        ld hl,#C008             ; H = «διάλεξε», L = καταχωρητής 8 (ένταση A)
        repeat 3
        ld b,#F4
        out (c),l               ; ο καταχωρητής
        ld b,#F6
        out (c),h
        out (c),0
        ld a,(de)
        inc e
        ld b,#F4
        out (c),a               ; η ένταση
        ld b,#F6
        out (c),c
        out (c),0
        inc l
        rend
        ret

; Ο έπαινος στο τέλος μιας κίνησης: όσο πιο μακριά η αλυσίδα, τόσο πιο γλυκός.
; Το chain μετράει τα RESOLVE: 2 = καμία αλυσίδα.
say_praise:
        ld a,(chain)
        cp 6
        jr c,.sweet
        ld hl,VOICE_DELICIOUS
        ld de,VOICE_DELICIOUS_LEN
        jp say
.sweet  cp 4
        ret c
        ld hl,VOICE_SWEET
        ld de,VOICE_SWEET_LEN
        jp say

        include "../build/voice.asm"
        assert (voice_tri&#FF)+16*4 <= 256
