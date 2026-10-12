10 REM SUGAR BYTE - loader: the REVIVE8BIT screen, then the game on
20 REM SPACE or after ten seconds, whichever comes first.
30 MODE 0:BORDER 0
40 REM The sixteen inks of the picture - assets/revive8b.txt.
50 INK 0,0:INK 1,13:INK 2,26:INK 3,15
60 INK 4,25:INK 5,10:INK 6,3:INK 7,1
70 INK 8,11:INK 9,23:INK 10,6:INK 11,24
80 INK 12,20:INK 13,16:INK 14,12:INK 15,4
90 LOAD"REVIVE8B.SCR",&C000
100 REM TIME counts three hundred to the second; SPACE is key 47.
110 t=TIME+3000
120 IF INKEY(47)<>-1 THEN 140
130 IF TIME<t THEN 120
140 RUN"SUGAR.BIN"
