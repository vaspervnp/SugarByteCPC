#!/usr/bin/env python3
"""levels/levels.txt -> build/levels.asm (plan.md §11).

Μία πίστα: κεφαλίδα 10 bytes και τα 64 κελιά σε RLE.

    0     στόχος: 0 πόντοι, 1 ζελέ, 2 υλικά, 3 ζελέ + υλικά
    1-2   πόντοι για 1 αστέρι (και στόχος των "score"), BCD εκατοντάδες, MSB πρώτο
    3     κινήσεις, BCD
    4     χρώματα (4-6)
    5     υλικά, BCD
    6-7   πόντοι για 2 αστέρια
    8-9   πόντοι για 3 αστέρια
    ...   ζεύγη (πλήθος, cell[]) ώσπου να καλυφθούν 64 κελιά

Και οι κωδικοί των πιστών (level_codes, 2 bytes BCD η καθεμία, MSB πρώτο):
4 ψηφία από hash του αριθμού της πίστας, όλοι διαφορετικοί, κανένας 0000.

  levels.py levels/levels.txt build/levels.asm
"""
import hashlib
import sys

GOALS = {'score': 0, 'jelly': 1, 'ingredients': 2, 'jelly+ingredients': 3}
CELLS = {'.': 0x00, 'j': 0x20, 'J': 0x40, '1': 0x0A, '2': 0x12, '3': 0x1A,
         'c': 0x03, 'l': 0x04, 'o': 0x01}
BLOCKS = 'o123cl'


def bcd(n, digits):
    s = f"{n:0{digits}d}"
    if len(s) > digits:
        raise ValueError(f"{n} δεν χωράει σε {digits} ψηφία")
    return [int(s[i:i + 2], 16) for i in range(0, digits, 2)]


def hundreds(points):
    if points % 100:
        raise ValueError(f"{points}: οι πόντοι πάνε ανά εκατό")
    return bcd(points // 100, 4)


def parse(path):
    levels, cur, rows = [], None, None
    for n, raw in enumerate(open(path, encoding='utf-8'), 1):
        line = raw.split('#', 1)[0].rstrip()
        if not line:
            continue
        try:
            if rows is not None and len(rows) < 8:
                if len(line) != 8 or any(ch not in CELLS for ch in line):
                    raise ValueError(f"γραμμή κελιών: '{line}'")
                rows.append(line)
                continue
            key, *val = line.split()
            if key == 'level':
                cur = {'name': val[0], 'ingredients': 0}
                levels.append(cur)
                rows = None
            elif key == 'goal':
                cur['goal'] = GOALS[val[0]]
            elif key in ('moves', 'colours', 'ingredients'):
                cur[key] = int(val[0])
            elif key == 'stars':
                cur['stars'] = [int(v) for v in val]
            elif key == 'cells':
                rows = cur['cells'] = []
            else:
                raise ValueError(f"άγνωστο '{key}'")
        except (ValueError, KeyError, IndexError) as e:
            sys.exit(f"{path}:{n}: {e}")
    return levels


def check(lv):
    name = f"level {lv['name']}"
    for k in ('goal', 'moves', 'colours', 'stars', 'cells'):
        if k not in lv:
            sys.exit(f"{name}: λείπει το '{k}'")
    if len(lv['cells']) != 8:
        sys.exit(f"{name}: θέλει 8 γραμμές κελιών")
    if not 4 <= lv['colours'] <= 6:
        sys.exit(f"{name}: χρώματα 4-6")
    if len(lv['stars']) != 3 or lv['stars'] != sorted(lv['stars']):
        sys.exit(f"{name}: τρία αστέρια, σε αύξουσα σειρά")
    wants_ingr = lv['goal'] in (2, 3)
    if wants_ingr != (lv['ingredients'] > 0):
        sys.exit(f"{name}: τα υλικά και ο στόχος δεν συμφωνούν")
    if wants_ingr and all(ch in BLOCKS for ch in lv['cells'][7]):
        sys.exit(f"{name}: τα υλικά δεν έχουν από πού να βγουν")
    for x in range(8):
        col = ''.join(r[x] for r in lv['cells'])
        inner = col.strip('o')
        if 'o' in inner:
            sys.exit(f"{name}: τρύπα στη μέση της κολόνας {x} — τα candies δεν γλιστράνε "
                     "διαγώνια, ό,τι είναι από κάτω της δεν θα ξαναγέμιζε ποτέ")
    if lv['goal'] in (1, 3) and not any(ch in 'jJ' for r in lv['cells'] for ch in r):
        sys.exit(f"{name}: στόχος ζελέ χωρίς ζελέ")


def encode(lv):
    head = [lv['goal'], *hundreds(lv['stars'][0]), *bcd(lv['moves'], 2),
            lv['colours'], *bcd(lv['ingredients'], 2),
            *hundreds(lv['stars'][1]), *hundreds(lv['stars'][2])]
    cells = [CELLS[ch] for r in lv['cells'] for ch in r]
    rle, i = [], 0
    while i < 64:
        j = i
        while j < 64 and cells[j] == cells[i]:
            j += 1
        rle += [j - i, cells[i]]
        i = j
    return head + rle


def level_codes(n):
    codes, salt = [], 0
    for i in range(n):
        while True:
            h = hashlib.sha1(f"sugarbyte/{i + 1}/{salt}".encode()).digest()
            c = int.from_bytes(h[:4], 'big') % 10000
            salt += 1
            if c and c not in codes:
                break
        codes.append(c)
    return codes


def main():
    src, dst = sys.argv[1], sys.argv[2]
    levels = parse(src)
    out = [f"; ΠΑΡΑΓΕΤΑΙ από το tools/levels.py ({src}) — μην το πειράζεις.", '',
           f"NLEVELS equ {len(levels)}", '', 'levels_tab:']
    out += [f"        dw level_{i + 1}" for i in range(len(levels))]
    total = 0
    for i, lv in enumerate(levels):
        check(lv)
        data = encode(lv)
        total += len(data)
        out.append(f"level_{i + 1}:                ; {len(data)} bytes")
        for k in range(0, len(data), 16):
            out.append('        db ' + ','.join(f"#{b:02X}" for b in data[k:k + 16]))
    out.append('')
    out.append('level_codes:            ; ο κωδικός κάθε πίστας, 4 ψηφία BCD')
    for i, c in enumerate(level_codes(len(levels))):
        out.append(f"        db #{c // 100:02d},#{c % 100:02d}    ; πίστα {i + 1}: {c:04d}")
    open(dst, 'w').write('\n'.join(out) + '\n')
    print(f"{dst}: {len(levels)} πίστες, {total} bytes")


if __name__ == '__main__':
    main()
