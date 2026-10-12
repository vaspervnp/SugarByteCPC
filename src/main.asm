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
        assert (keymap&#FF)+10 < 256 && (gap&#FF)+2*COLS < 256 && (spawn&#FF)+COLS < 256 && vars_end-vars_start < 256

        org CODE_ORG
start:
        di
        ld sp,STACK_TOP
        call hw_init
        call cls
        call build_tables
        call snd_init
        ei
        ld a,r                  ; σπόρος: ποτέ μηδέν
        ld l,a
        ld h,#A5
        ld (seed),hl
        jp game_new

        include "hw.asm"
        include "gfx.asm"
        include "board.asm"
        include "special.asm"
        include "cells.asm"
        include "ingred.asm"
        include "sound.asm"
        include "level.asm"
        include "codes.asm"
        include "../build/levels.asm"
NLEVELS_BCD     equ (NLEVELS/10)*16+NLEVELS-(NLEVELS/10)*10
        include "game.asm"
        include "hud.asm"
code_end:
        assert code_end <= SPRITES_ORG

        save "build/sugar.bin",start,sprites_end-start
