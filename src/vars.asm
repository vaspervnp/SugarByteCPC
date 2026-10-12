; vars.asm — η κατάσταση του παιχνιδιού στο #B000 (δεν γράφεται στο αρχείο)
;
; Οι τέσσερις πίνακες των 64 κάθονται στη σελίδα #B0, ώστε ο δείκτης κελιού
; να είναι κατευθείαν το L: board = #B000+i, matched = board | #40,
; cell = board | #80, dirty_q = board | #C0.

        org #B000
        nocode
board           defs 64         ; τι κάθεται στο κελί (plan.md §6)
matched         defs 64         ; σκάει: bit 0 γραμμή, 1 κολόνα, 2 «δεσμευμένο»,
                                ; 3 το χτύπησε ειδικό, 4 εμπόδιο με ζημιά,
                                ; 7 έχει ήδη πυροδοτηθεί
cell            defs 64         ; τι είναι το κελί· bit 7 = βρώμικο
dirty_q         defs 64         ; δακτύλιος με τα βρώμικα κελιά

vars_start
dq_head         defs 1
dq_tail         defs 1
dq_n            defs 1
keymap          defs 10         ; οι 10 γραμμές του πληκτρολογίου (0 = πατημένο)
joy             defs 1          ; J_* που κρατιούνται τώρα
joy_prev        defs 1
joy_edge        defs 1          ; J_* που πατήθηκαν μόλις
rep_cnt         defs 1
state           defs 1
anim_k          defs 1          ; καρέ μέσα στο animation της κατάστασης
cursor          defs 1          ; κελί του δείκτη
sel             defs 1          ; επιλεγμένο κελί, #FF = κανένα
swap_a          defs 1
swap_b          defs 1
chain           defs 1          ; πολλαπλασιαστής αλυσίδας
nmatch          defs 1          ; σειρές που βρήκε το find_matches
moves           defs 1          ; BCD
score           defs 3          ; BCD, το πιο σημαντικό byte πρώτο
hud_dirty       defs 1
blink_t         defs 1
ncolours        defs 1
seed            defs 2
gap             defs COLS       ; ανά κολόνα: το χαμηλότερο κενό, #FF = κανένα
nextc           defs COLS       ; ανά κολόνα: το candy που μπαίνει από πάνω
segtop          defs COLS       ; ανά κολόνα: πρώτη γραμμή του τμήματος που πέφτει
fall_c0         defs 1
nb              defs 4          ; οι γείτονες ενός κελιού
choc_broken     defs 1          ; έσπασε σοκολάτα σε αυτή την κίνηση
scan_bit        defs 1          ; 1 = σάρωση γραμμών, 2 = κολονών
nruns           defs 1
runs            defs 3*MAX_RUNS ; πρώτο κελί, μήκος, βήμα
nspawn          defs 1
spawns          defs 2*MAX_SPAWN ; κελί, τιμή board[] του ειδικού που γεννιέται
sp_changed      defs 1
dc_i            defs 1          ; προσωρινά των ρουτινών σχεδίασης
pop_ph          defs 1
fall_y          defs 1
digit_y         defs 1
vars_end
        code
