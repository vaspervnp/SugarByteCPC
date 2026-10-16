; Sugar Byte — match-3 για Amstrad CPC, Mode 0, 64 KB
;
;   rasm src/main.asm -os build/sugar.sym -s -sl   -> build/sugar.bin (#0100)
;
; Ο χάρτης της μνήμης είναι στο plan.md §5 και στο src/const.asm.

        include "const.asm"

        org SPRITES_ORG
        include "../assets/sprites.asm"
sprites_end:
        assert sprites_end <= CELL_SCR

        include "vars.asm"
        assert (board&#FF) == 0

        ; Οι πίστες: πάνω από τις μεταβλητές, κάτω από τη στοίβα.
        code
        org snd_end
        include "../build/levels.asm"
levels_end:
        assert levels_end <= STACK_TOP-256 && NLEVELS <= MAX_LEVELS
NLEVELS_BCD     equ floor(NLEVELS/10)*6+NLEVELS   ; το rasm διαιρεί με δεκαδικά
        assert (keymap&#FF)+10 < 256 && (gap&#FF)+2*COLS < 256 && (spawn&#FF)+COLS < 256 && vars_end-vars_start < 256

        org CODE_ORG
start:
        di
        ld sp,STACK_TOP
        call voice_init         ; πριν σβηστεί η οθόνη, που είναι και η πηγή της
        call hw_init
        call cls
        call build_tables
        call snd_init
        ei
        call cls
        call menu_start
        jp main_loop

        include "hw.asm"
        include "gfx.asm"
        include "board.asm"
        include "special.asm"
        include "cells.asm"
        include "ingred.asm"
        include "sound.asm"
        include "raster.asm"
        include "voice.asm"
        include "level.asm"
        include "codes.asm"
        include "menu.asm"
        include "hudgfx.asm"
        include "game.asm"
        include "hud.asm"

        ; Οι καλύτεροι πόντοι και αστέρια, ανά δυσκολία: 256 bytes η καθεμία, ώστε
        ; δυσκολία = +H. Μηδενικά στο αρχείο: η πρόοδος μιας συνεδρίας.
        align 256
best:   defs 4*MAX_LEVELS*DIFFICULTIES  ; best_ptr: +H ανά δυσκολία
        assert (best&#FF) == 0
code_end:
        assert code_end <= SPRITES_ORG

        ; Η φωνή: το αρχείο τη φέρνει στο #8000 (κάτω από το AMSDOS), το
        ; voice_init τη μεταφέρει στα κενά της οθόνης.
        org SCREEN
voice_load:
        incbin "../build/voice.bin"
voice_load_end:
        assert voice_load_end <= #A600

        save "build/sugar.bin",start,voice_load_end-start
