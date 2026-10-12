; sound.asm — ο ήχος: AY-3-8912 μέσω του PPI (plan.md §10)
;
; Τρέχει στη διακοπή των 300 Hz του Gate Array, μία φορά στις έξι (50 Hz),
; ώστε το τέμπο να μένει σταθερό όσο κι αν κρατάει η σχεδίαση ενός καρέ.
; Κανάλια A + B: μουσική (μελωδία, μπάσο). Κανάλι C: εφέ.

; --- οι νότες: περίοδος AY = 1 MHz / (16 x συχνότητα) ---------------------
REST    equ 1                   ; σιωπή· 0 = η νότα κρατάει
N_C2    equ 2
N_Cs2   equ 3
N_D2    equ 4
N_Ds2   equ 5
N_E2    equ 6
N_F2    equ 7
N_Fs2   equ 8
N_G2    equ 9
N_Gs2   equ 10
N_A2    equ 11
N_As2   equ 12
N_B2    equ 13
N_C3    equ 14
N_Cs3   equ 15
N_D3    equ 16
N_Ds3   equ 17
N_E3    equ 18
N_F3    equ 19
N_Fs3   equ 20
N_G3    equ 21
N_Gs3   equ 22
N_A3    equ 23
N_As3   equ 24
N_B3    equ 25
N_C4    equ 26
N_Cs4   equ 27
N_D4    equ 28
N_Ds4   equ 29
N_E4    equ 30
N_F4    equ 31
N_Fs4   equ 32
N_G4    equ 33
N_Gs4   equ 34
N_A4    equ 35
N_As4   equ 36
N_B4    equ 37
N_C5    equ 38
N_Cs5   equ 39
N_D5    equ 40
N_Ds5   equ 41
N_E5    equ 42
N_F5    equ 43
N_Fs5   equ 44
N_G5    equ 45
N_Gs5   equ 46
N_A5    equ 47
N_As5   equ 48
N_B5    equ 49
N_C6    equ 50
N_Cs6   equ 51
N_D6    equ 52
N_Ds6   equ 53
N_E6    equ 54
N_F6    equ 55
N_Fs6   equ 56
N_G6    equ 57
N_Gs6   equ 58
N_A6    equ 59
N_As6   equ 60
N_B6    equ 61
N_C7    equ 62

note_tab:                       ; από N_C2 = 2
        dw 956,902,851,804,758,716,676,638,602,568,536,506
        dw 478,451,426,402,379,358,338,319,301,284,268,253
        dw 239,225,213,201,190,179,169,159,150,142,134,127
        dw 119,113,106,100,95,89,84,80,75,71,67,63
        dw 60,56,53,50,47,45,42,40,38,36,34,32
        dw 30

MUS_SPEED       equ 8           ; καρέ ανά όγδοο (≈ 94 BPM)
MEL_VOL         equ 12          ; μελωδία: ξεκινάει εδώ, πέφτει ώς MEL_FLOOR
MEL_FLOOR       equ 8
BASS_VOL        equ 11
BASS_FLOOR      equ 6

; Ένα όγδοο τη γραμμή: μελωδία, μπάσο. #FF = από την αρχή.
music:
        db N_C5,N_C3
        db N_E5,0
        db N_G5,N_G3
        db N_E5,0
        db N_C6,N_C3
        db N_G5,0
        db N_E5,N_G3
        db N_G5,0

        db N_A4,N_F2
        db N_C5,0
        db N_F5,N_C3
        db N_C5,0
        db N_A5,N_F2
        db N_F5,0
        db N_C5,N_C3
        db N_F5,0

        db N_G4,N_G2
        db N_B4,0
        db N_D5,N_D3
        db N_G5,0
        db N_F5,N_G2
        db N_D5,0
        db N_B4,N_D3
        db N_D5,0

        db N_C5,N_C3
        db N_E5,0
        db N_G5,N_G2
        db N_C6,0
        db N_G5,N_C3
        db 0,0
        db REST,REST
        db REST,0

        db N_E5,N_C3
        db 0,0
        db N_G5,N_G3
        db 0,0
        db N_A5,N_A2
        db N_G5,0
        db N_E5,N_E3
        db N_C5,0

        db N_D5,N_D3
        db 0,0
        db N_F5,N_A3
        db 0,0
        db N_A5,N_F2
        db N_G5,0
        db N_F5,N_C3
        db N_D5,0

        db N_E5,N_C3
        db N_G5,0
        db N_C6,N_G2
        db N_G5,0
        db N_F5,N_F2
        db N_A5,0
        db N_D6,N_C3
        db N_A5,0

        db N_G5,N_G2
        db N_F5,0
        db N_E5,N_B2
        db N_D5,0
        db N_C5,N_C3
        db 0,0
        db REST,REST
        db REST,0

        db #FF

; --- τα εφέ: καρέ των 4 bytes — περίοδος (0 = χωρίς τόνο), ένταση, θόρυβος
; (0 = χωρίς). Τελειώνει με ένταση #FF.
sfx_select:
        dw 120
        db 12,0
        dw 90
        db 10,0
        db 0,0,#FF,0
sfx_swap:
        dw 320
        db 11,0
        dw 260
        db 11,0
        dw 210
        db 10,0
        dw 170
        db 8,0
        db 0,0,#FF,0
sfx_bad:
        dw 500
        db 13,0
        dw 560
        db 12,0
        dw 630
        db 11,0
        dw 700
        db 10,0
        dw 800
        db 8,0
        dw 900
        db 6,0
        db 0,0,#FF,0
sfx_beam:
        repeat 10,n
        dw 40+n*6
        db 15-n,3
        rend
        db 0,0,#FF,0
sfx_wrap:
        repeat 12,n
        dw 0
        db 16-n,8+n
        rend
        db 0,0,#FF,0
sfx_bomb:
        repeat 15,n
        dw 600+n*40
        db 15-n/2,12+n
        rend
        db 0,0,#FF,0
sfx_collect:                    ; C6 E6 G6 C7, 3 καρέ η καθεμία
        repeat 3
        dw 60
        db 13,0
        rend
        repeat 3
        dw 48
        db 13,0
        rend
        repeat 3
        dw 40
        db 13,0
        rend
        repeat 6,n
        dw 30
        db 14-n,0
        rend
        db 0,0,#FF,0
sfx_over:                       ; G4 E4 C4, κατεβαίνοντας
        repeat 8,n
        dw 159
        db 13-n/2,0
        rend
        repeat 8,n
        dw 190
        db 12-n/2,0
        rend
        repeat 16,n
        dw 239
        db 12-n*3/4,0
        rend
        db 0,0,#FF,0

; Το σκάσιμο: ένα «ποπ» που ανεβαίνει, ψηλότερα σε κάθε βαθμίδα της αλυσίδας.
pop_tab:
        dw 200,178,159,142,126,112

; ---------------------------------------------------------------------------
; Ο player

snd_init:
        ld hl,snd_start
        ld b,snd_end-snd_start
        xor a
.clr    ld (hl),a
        inc hl
        djnz .clr
        ld hl,music
        ld (mus_ptr),hl
        ld a,1
        ld (mus_wait),a
        ld (mus_on),a
        ld a,6
        ld (int_div),a
        ld a,#38
        ld (psg_shadow+7),a
        ret

; IM 1, 300 Hz. Ο ήχος μία φορά στις έξι.
int_handler:
        push af
        push bc
        push de
        push hl
        ld hl,int_div
        dec (hl)
        jr nz,.out
        ld (hl),6
        call sound_tick
.out    pop hl
        pop de
        pop bc
        pop af
        ei
        ret

sound_tick:
        call music_tick
        call sfx_tick
        ld hl,psg_shadow        ; οι καταχωρητές 0-10 στον PSG
        xor a
.w      ld e,(hl)
        call psg_write
        inc hl
        inc a
        cp 11
        jr c,.w
        ret

; A = καταχωρητής, E = τιμή. Δεν πειράζει A, HL.
psg_write:
        ld b,#F4
        out (c),a
        ld bc,#F6C0             ; διάλεξε καταχωρητή
        out (c),c
        ld bc,#F600
        out (c),c
        ld b,#F4
        out (c),e
        ld bc,#F680             ; γράψε
        out (c),c
        ld bc,#F600
        out (c),c
        ret

music_tick:
        ld a,(mus_on)
        or a
        jr nz,.on
        ld (psg_shadow+8),a
        ld (psg_shadow+9),a
        ret
.on     ld hl,mus_wait
        dec (hl)
        jr nz,.decay
        ld (hl),MUS_SPEED
        ld hl,(mus_ptr)
        ld a,(hl)
        cp #FF
        jr nz,.row
        ld hl,music
        ld a,(hl)
.row    inc hl
        ld e,(hl)
        inc hl
        ld (mus_ptr),hl
        push de
        ld hl,psg_shadow+0
        ld de,psg_shadow+8
        ld c,MEL_VOL
        call start_note
        pop de
        ld a,e
        ld hl,psg_shadow+2
        ld de,psg_shadow+9
        ld c,BASS_VOL
        jp start_note
.decay  ld a,(hl)               ; κάθε δεύτερο καρέ, ένα σκαλί πιο σιγά
        and 1
        ret nz
        ld hl,psg_shadow+8
        ld a,(hl)
        cp MEL_FLOOR+1
        jr c,.bass
        dec (hl)
.bass   inc hl
        ld a,(hl)
        cp BASS_FLOOR+1
        ret c
        dec (hl)
        ret

; A = νότα (0 κρατάει, REST σιωπή), HL = καταχωρητής περιόδου, DE = έντασης,
; C = αρχική ένταση.
start_note:
        or a
        ret z
        cp REST
        jr nz,.play
        xor a
        ld (de),a
        ret
.play   push hl
        sub 2
        add a,a
        ld hl,note_tab
        call add_hl_a
        ld a,(hl)
        inc hl
        ld b,(hl)
        pop hl
        ld (hl),a
        inc hl
        ld (hl),b
        ld a,c
        ld (de),a
        ret

sfx_tick:
        ld hl,(sfx_ptr)
        ld a,h
        or l
        jr z,.silent
        ld a,(sfx_pop)
        or a
        jr nz,.pop
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        inc hl
        ld c,(hl)
        inc hl
        cp #FF
        jr z,.end
        ld (sfx_ptr),hl
.set    ld (psg_shadow+10),a    ; DE = περίοδος, A = ένταση, C = θόρυβος
        ld (psg_shadow+4),de
        ld a,c
        ld (psg_shadow+6),a
        ld b,#38                ; μίκτης: τόνοι ανοιχτοί, θόρυβοι κλειστοί, port A είσοδος
        ld a,d
        or e
        jr nz,.tone
        set 2,b
.tone   ld a,c
        or a
        jr z,.mix
        res 5,b
.mix    ld a,b
        ld (psg_shadow+7),a
        ret
.pop    dec a
        ld (sfx_pop),a
        jr z,.end
        ld hl,(pop_per)         ; η περίοδος πέφτει 1/8 το καρέ: ο τόνος ανεβαίνει
        ld d,h
        ld e,l
        srl d
        rr e
        srl d
        rr e
        srl d
        rr e
        or a
        sbc hl,de
        ld (pop_per),hl
        ex de,hl
        ld a,(sfx_pop)
        add a,a
        add a,a
        cp 15
        jr c,.pv
        ld a,15
.pv     ld c,0
        jr .set
.end    ld hl,0
        ld (sfx_ptr),hl
        xor a
        ld (sfx_pop),a
.silent xor a
        ld (psg_shadow+10),a
        ld a,#38
        ld (psg_shadow+7),a
        ret

; HL = εφέ: παίζει στο κανάλι C, στη θέση όποιου έπαιζε.
play_sfx:
        di
        ld (sfx_ptr),hl
        xor a
        ld (sfx_pop),a
        ei
        ret

; Το σκάσιμο, με το ύψος της βαθμίδας της αλυσίδας.
play_pop:
        ld a,(chain)
        or a
        jr nz,.c
        inc a
.c      cp 7
        jr c,.ok
        ld a,6
.ok     dec a
        add a,a
        ld hl,pop_tab
        call add_hl_a
        ld e,(hl)
        inc hl
        ld d,(hl)
        di
        ld (pop_per),de
        ld a,8
        ld (sfx_pop),a
        ld hl,1                 ; όχι μηδέν: «παίζει κάτι»
        ld (sfx_ptr),hl
        ei
        ret

; Το εφέ του σκασίματος που ξεκινάει: βόμβα αν σκάνε πολλά, έκρηξη αν σκάει
; περιτύλιγμα, αλλιώς ποπ.
play_clear_sfx:
        ld a,(clear_n)
        cp BIG_CLEAR
        ld hl,sfx_bomb
        jr nc,play_sfx
        ld a,(boom)
        or a
        ld hl,sfx_wrap
        jr nz,play_sfx
        jr play_pop
