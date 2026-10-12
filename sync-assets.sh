#!/usr/bin/env bash
#
# Τραβάει τα γραφικά από το repo CPCArt στο assets/.
#
#   ./sync-assets.sh              αντιγράφει ό,τι υπάρχει ήδη χτισμένο
#   ./sync-assets.sh --regen      τρέχει πρώτα τη γεννήτρια στο CPCArt
#   CPCART=/αλλού ./sync-assets.sh
#
# Τα assets είναι ΠΑΡΑΓΟΜΕΝΑ. Μην τα επεξεργάζεσαι εδώ — το επόμενο sync τα σβήνει.

set -euo pipefail

CPCART="${CPCART:-$HOME/repos/CPCArt}"
SRC="$CPCART/sugarbyte"
DST="$(cd "$(dirname "$0")" && pwd)/assets"
REGEN=0

for arg in "$@"; do
  case "$arg" in
    --regen) REGEN=1 ;;
    -h|--help) sed -n '2,8p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "άγνωστη επιλογή: $arg" >&2; exit 2 ;;
  esac
done

[ -d "$SRC" ] || { echo "δεν βρέθηκε το $SRC — όρισε CPCART" >&2; exit 1; }

if [ "$REGEN" = 1 ]; then
  echo "== ξαναχτίζω στο CPCArt =="
  (cd "$SRC" && python3 src/make_all.py)
fi

BIN="$SRC/sprites.bin"
[ -f "$BIN" ] || { echo "λείπει το $BIN — τρέξε με --regen" >&2; exit 1; }

# Αν πειράχτηκε η γεννήτρια μετά το τελευταίο build, το αντίγραφο θα ήταν παλιό.
if [ -n "$(find "$SRC/src" -type f -newer "$BIN" -not -path '*/__pycache__/*' \
           -print -quit 2>/dev/null)" ]; then
  echo "ΠΡΟΣΟΧΗ: το src/ της γεννήτριας είναι νεότερο από το build." >&2
  echo "Τρέξε με --regen." >&2
  exit 1
fi

echo "== αντιγράφω =="
rm -rf "$DST/aseprite" "$DST/preview" "$DST/sheets"
mkdir -p "$DST/aseprite" "$DST/preview" "$DST/sheets"
cp "$SRC"/sprites.bin "$SRC"/sprites.asm \
   "$SRC"/menu.bin "$SRC"/menu.asm \
   "$SRC"/sprites_map.txt "$SRC"/palette.gpl "$SRC"/manifest.json "$DST/"
cp "$SRC"/*.aseprite "$DST/aseprite/"
cp "$SRC"/*_sheet.png "$SRC"/*_sheet.json "$DST/sheets/"
cp "$SRC"/preview_*.png "$SRC"/mockup_*.png "$DST/preview/"

REV="$(git -C "$CPCART" rev-parse --short HEAD)"
DIRTY=""
# --porcelain και όχι "diff --quiet": το diff δεν βλέπει αρχεία εκτός ευρετηρίου,
# και ένα ολόκληρο sugarbyte/ που δεν έχει γίνει ακόμα add θα περνούσε για καθαρό.
[ -z "$(git -C "$CPCART" status --porcelain -- sugarbyte)" ] || DIRTY=" (με ακοινοποίητες αλλαγές)"
echo "από CPCArt@$REV$DIRTY" > "$DST/.source"

echo "== έτοιμο =="
echo "sprites.bin: $(stat -c%s "$DST/sprites.bin") bytes, από CPCArt@$REV$DIRTY"
