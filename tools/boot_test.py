#!/usr/bin/env python3
"""Φορτώνει τη δισκέτα σε πλήρη εξομοιωτή CPC 6128 (firmware, AMSDOS, FDC) και
ελέγχει ότι το παιχνίδι ξεκινάει: RUN"SUGAR, Mode 0, το μενού, SPACE στο PLAY,
ο δείκτης κινείται με τα βελάκια. Screenshots: boot_menu.png, boot.png.

  boot_test.py build/sugar.dsk --out build/shots

Ο εξομοιωτής είναι το CPCTools/cpcemu (floooh/chips)· το CPCEMU δείχνει αλλού.
"""
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CPCEMU = os.environ.get('CPCEMU', os.path.join(HERE, '..', '..', 'CPCTools', 'cpcemu'))
sys.path.insert(0, CPCEMU)
from cpc import CPC, KEY_RIGHT, KEY_SPACE  # noqa: E402


def load_symbols(path):
    syms = {}
    for line in open(path):
        parts = line.split()
        if len(parts) >= 2 and parts[1].startswith('#'):
            syms[parts[0].upper()] = int(parts[1][1:], 16)
    return syms


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('dsk')
    ap.add_argument('--sym', default='build/sugar.sym')
    ap.add_argument('--out', default='build/shots')
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    syms = load_symbols(args.sym)

    c = CPC()
    c.run_frames(120)
    c.insert_disc(args.dsk)
    c.type_text('RUN"SUGAR\n')
    c.run_frames(400)                       # φόρτωμα ~30 KB + πρώτο ζωγράφισμα

    fails = []
    if c.mode != 0:
        fails.append(f'mode {c.mode}, όχι 0')
    if c.read_ram(syms['STATE'], 1)[0] != 9:
        fails.append('δεν είναι στο μενού')
    c.screenshot(os.path.join(args.out, 'boot_menu.png'), aspect=True)
    c.key_down(KEY_SPACE)
    c.run_frames(3)
    c.key_up(KEY_SPACE)
    c.run_frames(30)
    if c.read_ram(syms['STATE'], 1)[0] != 0:
        fails.append('το PLAY δεν ξεκίνησε το παιχνίδι')
    cur = c.read_ram(syms['CURSOR'], 1)[0]
    c.key_down(KEY_RIGHT)
    c.run_frames(2)
    c.key_up(KEY_RIGHT)
    c.run_frames(10)
    cur2 = c.read_ram(syms['CURSOR'], 1)[0]
    if cur2 != cur + 1:
        fails.append(f'ο δείκτης δεν κινήθηκε: {cur} -> {cur2}')
    path = os.path.join(args.out, 'boot.png')
    c.screenshot(path, aspect=True)
    print(f'shot {path}')
    for f in fails:
        print('FAIL', f)
    if fails:
        sys.exit(1)
    print('ok   boot: Mode 0, μενού, PLAY, ο δείκτης κινείται')


if __name__ == '__main__':
    main()
