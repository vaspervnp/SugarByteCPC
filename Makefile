RASM ?= rasm
IDSK ?= iDSK
PY   ?= python3
B    := build

SRC  := $(wildcard src/*.asm)

all: $(B)/sugar.dsk $(B)/sugar.cdt

$(B):
	mkdir -p $@

# Το rasm γράφει μόνο του το build/sugar.bin (save στο src/main.asm): #0100 ώς το
# τέλος των sprites, ένα κομμάτι.
$(B)/levels.asm: levels/levels.txt tools/levels.py | $(B)
	$(PY) tools/levels.py $< $@

VOICES := sugarbyte sweet delicious crush
$(B)/voice.bin $(B)/voice.asm: $(VOICES:%=voice/%.wav) tools/voice.py | $(B)
	$(PY) tools/voice.py $(B)/voice.bin $(B)/voice.asm $(foreach v,$(VOICES),$(v)=voice/$(v).wav)

$(B)/sugar.bin $(B)/sugar.sym: $(SRC) assets/sprites.asm $(B)/levels.asm $(B)/voice.bin | $(B)
	$(RASM) src/main.asm -os $(B)/sugar.sym -s -sl

# RUN"SUGAR — το AMSDOS βρίσκει πρώτα το SUGAR.BAS: η οθόνη REVIVE8BIT στο
# &C000, 10 δευτερόλεπτα ή SPACE, και μετά RUN"SUGAR.BIN (#0100). Το BASIC θέλει
# CR στο τέλος κάθε γραμμής, αλλιώς «Line too long».
$(B)/sugar.dsk: $(B)/sugar.bin src/sugar.bas assets/revive8b.scr
	rm -f $@
	$(PY) -c "import sys; open(sys.argv[2],'wb').write(open(sys.argv[1],'rb').read().replace(b'\n', b'\r\n'))" src/sugar.bas $(B)/sugar.bas
	$(IDSK) $@ -n
	$(IDSK) $@ -i $(B)/sugar.bas -t 0 -f
	$(IDSK) $@ -i assets/revive8b.scr -t 1 -c C000 -e C000 -f
	$(IDSK) $@ -i $(B)/sugar.bin -t 1 -c 0100 -e 0100 -f

# Η κασέτα: μόνο το SUGAR.BIN, χωρίς την οθόνη REVIVE8BIT. 2.000 baud,
# ~3,5 λεπτά. |TAPE (στο 6128) και RUN"".
$(B)/sugar.cdt: $(B)/sugar.bin tools/mkcdt.py
	$(PY) tools/mkcdt.py $(B)/sugar.bin $@ --name=SUGAR --load=0100

# Τα εγχειρίδια σε PDF (A5, σαν το βιβλιαράκι της θήκης). Θέλουν το fpdf2,
# γι' αυτό τα PDF είναι στο repo.
SHOTS := $(wildcard docs/*.png)
manuals: docs/manual-en.pdf docs/manual-el.pdf

docs/manual-en.pdf: manual.md $(SHOTS) tools/mkmanual.py
	$(PY) tools/mkmanual.py $< $@

docs/manual-el.pdf: manual.el.md $(SHOTS) tools/mkmanual.py
	$(PY) tools/mkmanual.py $< $@

# Windows: ένα .exe με το παιχνίδι και τον Caprice32 μέσα, και ένα zip για διανομή με
# τα εγχειρίδια (build/win/). Τρέχει από το WSL: το launcher το χτίζει ο csc.exe των Windows.
windows: $(B)/sugar.dsk docs/manual-en.pdf docs/manual-el.pdf
	tools/mkwin.sh

# Linux: το ίδιο, ένα αρχείο (σενάριο + tar.gz) με τον Caprice32 του snap και τις
# βιβλιοθήκες του, και ένα tar.gz για διανομή (build/linux/). Θέλει το snap caprice32.
linux: $(B)/sugar.dsk docs/manual-en.pdf docs/manual-el.pdf
	tools/mklinux.sh

# Headless σενάρια (tests/*.txt) στο tools/cpcrun.py· screenshots στο build/shots/.
test: $(B)/sugar.bin
	@set -e; for t in tests/*.txt; do \
	  echo "== $$t"; \
	  $(PY) tools/cpcrun.py $(B)/sugar.bin --sym $(B)/sugar.sym --script $$t --out $(B)/shots; \
	done

# Εκκίνηση από δισκέτα σε πραγματικό εξομοιωτή 6128 (CPCTools/cpcemu).
boot: $(B)/sugar.dsk
	$(PY) tools/boot_test.py $(B)/sugar.dsk --out $(B)/shots

clean:
	rm -rf $(B)

.PHONY: all test boot manuals windows linux clean
