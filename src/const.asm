; const.asm — σταθερές του παιχνιδιού και ο χάρτης της μνήμης (plan.md §5)

; --- το ταμπλό --------------------------------------------------------------
BOARD_Y         equ 4           ; πρώτη γραμμή οθόνης του ταμπλό
CELL_WB         equ 6           ; bytes ανά γραμμή κελιού (12 pixels Mode 0)
CELL_H          equ 24          ; γραμμές ανά κελί
COLS            equ 8
ROWS            equ 8

EMPTY           equ 7           ; board[]: χρώμα 7 = κενό κελί
FORM_SHIFT      equ 3           ; board[] bits 3-4: η μορφή του candy

; --- το HUD ------------------------------------------------------------------
HUD_XB          equ 48          ; πρώτο byte του HUD (pixel 96)
HUD_ICON_XB     equ HUD_XB+1
HUD_DIGIT_XB    equ HUD_XB+5
HUD_SCORE_Y     equ 8
HUD_MOVES_Y     equ 22

; bytes Mode 0 με δύο ίδια (ή δύο δοσμένα) pixels
PB_BLACK        equ #00
PB_BLUE         equ #CC         ; pen 3 + pen 3
PB_GREY         equ #0C         ; pen 2 + pen 2
PB_GREY_BLUE    equ #4C         ; pen 2 αριστερά, pen 3 δεξιά

; --- ο χρόνος ----------------------------------------------------------------
DRAW_BUDGET     equ 4           ; βρώμικα κελιά το καρέ (ένα κελί με δείκτη ≈ 5 ms)
SWAP_FRAMES     equ 6           ; 1 byte ή 4 γραμμές το καρέ
FALL_STEPS      equ 3           ; ένα κελί πτώσης σε 3 βήματα των 8 γραμμών
FALL_STEP_Y     equ CELL_H/FALL_STEPS
REP_FIRST       equ 12          ; repeat του δείκτη: πρώτη επανάληψη
REP_NEXT        equ 3           ; ... και μετά
START_MOVES     equ #30         ; BCD

; --- η είσοδος ---------------------------------------------------------------
J_UP            equ 1
J_DOWN          equ 2
J_LEFT          equ 4
J_RIGHT         equ 8
J_FIRE          equ 16

; --- οι καταστάσεις (plan.md §7) ---------------------------------------------
S_IDLE         equ 0
S_SWAP         equ 1
S_UNSWAP       equ 2
S_CLEAR        equ 3
S_FALL         equ 4
S_OVER         equ 5

; --- η μνήμη -----------------------------------------------------------------
CODE_ORG        equ #0100
SPRITES_ORG     equ #4000
CELL_SCR        equ #7580       ; 64 words: η διεύθυνση οθόνης κάθε κελιού
LINE_LO         equ #7600       ; 200 bytes: χαμηλό byte της διεύθυνσης κάθε γραμμής
LINE_HI         equ #7700       ; 200 bytes: υψηλό byte
STACK_TOP       equ #C000
