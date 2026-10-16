; const.asm — σταθερές του παιχνιδιού και ο χάρτης της μνήμης (plan.md §5)

; --- η οθόνη: overscan 192x248 σε σελίδα 32 KB (plan.md §4.5) ----------------
;   y   0.. 31   ο τίτλος, 192x32
;   y  32..223   16 μπορντούρα | 96 ταμπλό | 64 HUD | 16 μπορντούρα
;   y 224..247   το πόδι, 192x24
SCR_WB          equ 96          ; bytes ανά γραμμή (R1 = 48)
SCR_H           equ 248         ; γραμμές (R6 = 31)
SCR_BASE        equ #8000+32    ; R12/R13 = #2C10: η γραμμή 21 αρχίζει ακριβώς στο #C000
TITLE_Y         equ 0
FOOT_Y          equ 224
BORDER_XB       equ 8           ; πλάτος της πλαϊνής μπορντούρας σε bytes
RBORDER_XB      equ SCR_WB-BORDER_XB    ; 88: η δεξιά μπορντούρα (bytes, όχι pixels)

; --- το ταμπλό --------------------------------------------------------------
BOARD_Y         equ 32          ; πρώτη γραμμή οθόνης του ταμπλό
BOARD_XB        equ BORDER_XB   ; πρώτο byte του ταμπλό
CELL_WB         equ 6           ; bytes ανά γραμμή κελιού (12 pixels Mode 0)
CELL_H          equ 24          ; γραμμές ανά κελί
COLS            equ 8
ROWS            equ 8

EMPTY           equ 7           ; board[]: χρώμα 7 = κενό κελί
BOMB            equ 6           ; board[]: χρώμα 6 = βόμβα χρώματος
INGREDIENT      equ #20         ; board[] bit 5: υλικό· bit 0: 0 κεράσι, 1 φουντούκι
G_SCORE         equ 0           ; στόχοι πίστας
G_JELLY         equ 1
G_INGREDIENTS   equ 2
G_BOTH          equ 3
G_ENDLESS       equ #FF         ; χωρίς στόχο (τα tests)
F_STRIPED_H     equ 1<<3        ; board[] bits 3-4: η μορφή
F_STRIPED_V     equ 2<<3
F_WRAPPED       equ 3<<3
MAX_RUNS        equ 24
MAX_LEVELS      equ 64          ; ο πίνακας best[]: 4 bytes η πίστα, 256 ανά δυσκολία
DIFFICULTIES    equ 3           ; EASY, MEDIUM, HARD

; cell[]: τύπος στα bits 0-2
C_NORMAL        equ 0
C_HOLE          equ 1
C_ICING         equ 2
C_CHOCOLATE     equ 3
C_LICORICE      equ 4
ICING_SHIFT     equ 3
ICING_MASK      equ 3<<ICING_SHIFT
JELLY_SHIFT     equ 5
JELLY_MASK      equ 3<<JELLY_SHIFT

; matched[]: bit 4 = εμπόδιο που παθαίνει ζημιά
M_BLOCKER_BIT   equ 4
M_BLOCKER       equ 1<<M_BLOCKER_BIT
MAX_SPAWN       equ 16
FORM_SHIFT      equ 3           ; board[] bits 3-4: η μορφή του candy

; --- το HUD ------------------------------------------------------------------
HUD_XB          equ BOARD_XB+48 ; πρώτο byte του HUD (pixel 112)
HUD_WB          equ 32          ; 64 pixels
HUD_Y           equ BOARD_Y

; τα εικονίδια 8x16 του icons_gfx (menu.bin)
ICON_SCORE      equ 0           ; βάζο
ICON_MOVES      equ 1           ; βέλη ανταλλαγής
ICON_TIME       equ 2           ; κλεψύδρα
ICON_GOAL       equ 3           ; γλειφιτζούρι
ICON_JELLY      equ 4
ICON_STAR_ON    equ 5
ICON_STAR_OFF   equ 6
ICON_LOCK       equ 7

; bytes Mode 0 με δύο ίδια (ή δύο δοσμένα) pixels
PB_BLACK        equ #00
PB_BLUE         equ #CC         ; pen 3 + pen 3
PB_GREY         equ #0C         ; pen 2 + pen 2
PB_GREY_BLUE    equ #4C         ; pen 2 αριστερά, pen 3 δεξιά
PB_WHITE        equ #C0         ; pen 1 + pen 1
PB_WHITE_L      equ #80         ; pen 1 αριστερά, pen 0 δεξιά

; --- ο χρόνος ----------------------------------------------------------------
DRAW_BUDGET     equ 4           ; βρώμικα κελιά το καρέ (ένα κελί με δείκτη ≈ 5 ms)
SWAP_FRAMES     equ 6           ; 1 byte ή 4 γραμμές το καρέ
FALL_STEPS      equ 2           ; ένα κελί πτώσης σε 2 βήματα των 12 γραμμών
FALL_STEP_Y     equ CELL_H/FALL_STEPS
HINT_WAIT       equ 250         ; 5 δευτερόλεπτα αδράνειας: η υπόδειξη
REP_FIRST       equ 12          ; repeat του δείκτη: πρώτη επανάληψη
REP_NEXT        equ 3           ; ... και μετά

; --- η είσοδος ---------------------------------------------------------------
J_UP            equ 1
J_DOWN          equ 2
J_LEFT          equ 4
J_RIGHT         equ 8
J_FIRE          equ 16
J_MUSIC         equ 32
J_ESC           equ 64

; --- οι καταστάσεις (plan.md §7) ---------------------------------------------
S_IDLE         equ 0
S_SWAP         equ 1
S_UNSWAP       equ 2
S_CLEAR        equ 3
S_FALL         equ 4
S_OVER         equ 5
S_BEAM         equ 6
S_WIN          equ 7
S_CODE         equ 8
S_MENU         equ 9
S_SCORES       equ 10
S_CRUSH        equ 11
S_SLIDE        equ 12           ; ένα candy γλιστράει διαγώνια
CRUSH_FRAMES   equ 5            ; καρέ ανά κίνηση που γίνεται ριγέ
MAX_BEAMS       equ 16
BIG_CLEAR       equ 24          ; πάνω από τόσα κελιά: σκάσιμο σε 2 φάσεις, όχι 4

; --- η μνήμη -----------------------------------------------------------------
CODE_ORG        equ #0100
SPRITES_ORG     equ #4000
CELL_SCR        equ #7580       ; 64 words: η διεύθυνση οθόνης κάθε κελιού
LINE_LO         equ #7600       ; 200 bytes: χαμηλό byte της διεύθυνσης κάθε γραμμής
LINE_HI         equ #7700       ; 200 bytes: υψηλό byte
VARS_ORG        equ #7800       ; οι μεταβλητές, κάτω από την οθόνη
STACK_TOP       equ #8000       ; η στοίβα ανεβαίνει από κάτω της
SCREEN          equ #8000       ; η οθόνη: #8000-#FFFF (με κενά στο #C3C0.. κάθε #800)
