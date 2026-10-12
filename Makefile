RASM ?= rasm
IDSK ?= iDSK
PY   ?= python3
B    := build

SRC  := $(wildcard src/*.asm)

all: $(B)/sugar.dsk

$(B):
	mkdir -p $@

# Το rasm γράφει μόνο του το build/sugar.bin (save στο src/main.asm): #0100 ώς το
# τέλος των sprites, ένα κομμάτι.
$(B)/levels.asm: levels/levels.txt tools/levels.py | $(B)
	$(PY) tools/levels.py $< $@

$(B)/sugar.bin $(B)/sugar.sym: $(SRC) assets/sprites.asm $(B)/levels.asm | $(B)
	$(RASM) src/main.asm -os $(B)/sugar.sym -s -sl

# RUN"SUGAR — φορτώνει στο #0100 και ξεκινάει εκεί.
$(B)/sugar.dsk: $(B)/sugar.bin
	rm -f $@
	$(IDSK) $@ -n
	$(IDSK) $@ -i $(B)/sugar.bin -t 1 -c 0100 -e 0100

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

.PHONY: all test boot clean
