#!/usr/bin/env python3
"""Headless Amstrad CPC harness for Sugar Byte (adapted from Build Dangerous).

Runs the game binary on a bare Z80 (no firmware/ROM), emulating only the hardware the
game touches: Gate Array (inks, mode, the 300 Hz IM 1 interrupt), CRTC registers,
PPI + PSG keyboard matrix and the VSYNC bit. Drives it from a script and saves screenshots (Mode 0 or 1) / checks variables.

  cpcrun.py build/sugar.bin --sym build/sugar.sym --script tests/smoke.txt --out build/shots

Script lines (';' starts a comment):
  run <frames> [key+key...]     hold keys (or none) for N frames
  shot <name>                   save <out>/<name>.png
  expect <addr> <value>         assert byte at addr == value (decimal or #hex)
  poke <addr> <value>           write a byte
  pokew <addr> <value>          write a word; value may be a symbol (e.g. a building to boot)
  until <addr> <value> [keys] [max]   run frames (holding keys, or - for none) until the
                                byte equals value; fails after max frames (default 3000)
  print <addr> [count]          print bytes (hex)
  board                         print the 8x8 board
  setboard <row0> ... <row7>    write the board (8 cells a row, see cell_value) and
                                queue every cell for redraw through the game's dirty list;
                                every cell becomes a plain one, no ingredient
                                will drop in unless the script pokes ingr_spawn,
                                and the level has no goal (lv_goal = G_ENDLESS)
  setcells <row0> ... <row7>    the cell types (one char a cell, see CELL_CHARS); the
                                board under blockers is emptied. Use after setboard.
  expectcells <row0> ... <row7> assert the cell types (? matches anything)
  countcells <char> <n>         assert how many cells are of that type
  expectboard <row0> ... <row7> assert the board (? matches anything, # anything not empty)
  psg <reg> <value>             assert a PSG (AY) register's current value
  psgon <reg>                   assert a PSG volume register is non-zero (something plays)

--wav <file> renders everything the PSG played to a WAV (a simple AY model: square tones,
LFSR noise, logarithmic volumes; no envelopes, which the game doesn't use).

<addr> is SYMBOL, SYMBOL+N, or *SYMBOL+N (N bytes past the pointer stored at SYMBOL).

Keys: up down left right fire esc mus (M) (keyboard) and jup jdown jleft jright jfire1 jfire2.
"""
import argparse
import os
import sys

import z80
from PIL import Image

FRAME_T = 79872         # 19968 us/frame at 4 T-states/us (ignores CPC wait-state stretching)
VSYNC_T = 2048          # 8 scanlines
SLICE_T = 64
INT_T = FRAME_T // 6     # Gate Array: διακοπή κάθε 52 γραμμές, 300 Hz

KEYS = {
    'up': (0, 0), 'right': (0, 1), 'down': (0, 2), 'left': (1, 0),
    'fire': (5, 7), 'esc': (8, 2), 'mus': (4, 6),
    'jup': (9, 0), 'jdown': (9, 1), 'jleft': (9, 2), 'jright': (9, 3),
    'jfire2': (9, 4), 'jfire1': (9, 5),
}

# Gate array hardware colour (0-31) -> RGB
HW_RGB = [
    (128, 128, 128), (128, 128, 128), (0, 255, 128), (255, 255, 128),
    (0, 0, 128), (255, 0, 128), (0, 128, 128), (255, 128, 128),
    (255, 0, 128), (255, 255, 128), (255, 255, 0), (255, 255, 255),
    (255, 0, 0), (255, 0, 255), (255, 128, 0), (255, 128, 255),
    (0, 0, 128), (0, 255, 128), (0, 255, 0), (0, 255, 255),
    (0, 0, 0), (0, 0, 255), (0, 128, 0), (0, 128, 255),
    (128, 0, 128), (128, 255, 128), (128, 255, 0), (128, 255, 255),
    (128, 0, 0), (128, 0, 255), (128, 128, 0), (128, 128, 255),
]


def load_symbols(path):
    syms = {}
    if path:
        for line in open(path):
            parts = line.split()
            if len(parts) >= 2 and parts[1].startswith('#'):
                syms[parts[0].upper()] = int(parts[1][1:], 16)
    return syms


class CPC:
    def __init__(self, binary, org, syms):
        self.m = z80.Z80Machine()
        self.m.set_memory_block(org, binary)
        self.m.pc = org
        self.m.sp = 0xBFF0
        self.org, self.end = org, org + len(binary)
        self.t = 0
        self.inks = [0x14] * 17
        self.pen = 0
        self.mode = 1
        self.crtc_sel = 0
        self.crtc = [0] * 32
        self.ppi_a = 0xFF
        self.ppi_c = 0
        self.psg_reg = 0
        self.psg = [0] * 16
        self.psg_log = []       # (T-state, register, value)
        self.matrix = [0xFF] * 10
        self.busy = []          # (loop no, T-states of work from vsync start to next wait_vbl)
        self.frame_no = 0
        self.at_wait = False
        self.booted = False
        self.wait_vbl = syms.get('WAIT_VBL')
        self.vsync_start_t = None
        self.last_vsync_read = 1
        self.int_pending = False
        self.ints = 0           # διακοπές που δέχτηκε ο Z80
        self.m.set_output_callback(self.on_out)
        self.m.set_input_callback(self.on_in)
        if self.wait_vbl is not None:
            self.m.set_breakpoint(self.wait_vbl)

    def vsync(self):
        return (self.t % FRAME_T) < VSYNC_T

    def on_out(self, addr, val):
        if not addr & 0x8000 and addr & 0x4000:             # Gate Array
            f = val >> 6
            if f == 0:
                self.pen = 16 if val & 0x10 else val & 0x0F
            elif f == 1:
                self.inks[self.pen] = val & 0x1F
            elif f == 2:
                self.mode = val & 3
        if not addr & 0x4000:                                # CRTC
            sub = (addr >> 8) & 3
            if sub == 0:
                self.crtc_sel = val & 31
            elif sub == 1:
                self.crtc[self.crtc_sel] = val
        if not addr & 0x0800:                                # PPI 8255
            port = (addr >> 8) & 3
            if port == 0:
                self.ppi_a = val
            elif port == 2:
                self.ppi_c = val
                if (val >> 6) == 3:
                    self.psg_reg = self.ppi_a & 0x0F
                elif (val >> 6) == 2:
                    self.psg[self.psg_reg] = self.ppi_a
                    self.psg_log.append((self.t + SLICE_T - self.m.ticks_to_stop, self.psg_reg, self.ppi_a))

    def on_in(self, addr):
        if not addr & 0x0800:
            port = (addr >> 8) & 3
            if port == 1:
                v = 1 if self.vsync() else 0
                if v and not self.last_vsync_read:      # the rising edge wait_vbl waits for
                    self.vsync_start_t = self.t
                self.last_vsync_read = v
                return 0x1E | v
            if port == 0 and (self.ppi_c >> 6) == 1 and self.psg_reg == 14:
                line = self.ppi_c & 0x0F
                return self.matrix[line] if line < 10 else 0xFF
        return 0xFF

    def set_keys(self, names):
        self.matrix = [0xFF] * 10
        for n in names:
            line, bit = KEYS[n]
            self.matrix[line] &= ~(1 << bit) & 0xFF

    def run_frames(self, n):
        """Run n game-loop iterations: stop when the game enters wait_vbl for the n-th time,
        so every frame's work is complete when a script inspects memory. Without a
        wait_vbl symbol, falls back to n * FRAME_T T-states."""
        target = self.t + n * FRAME_T
        loops = 0
        while (loops < n) if self.wait_vbl is not None else (self.t < target):
            if self.m.pc == self.wait_vbl and self.at_wait:
                self.m.clear_breakpoint(self.wait_vbl)      # step past the breakpoint
                self.m.ticks_to_stop = 1
                self.m.run()
                self.t += 4
                self.m.set_breakpoint(self.wait_vbl)
                self.at_wait = False
            self.m.ticks_to_stop = SLICE_T
            events = self.m.run()
            t0 = self.t
            self.t += SLICE_T - self.m.ticks_to_stop
            if self.t // INT_T != t0 // INT_T:
                self.int_pending = True     # ο Gate Array την κρατάει ώσπου να γίνει δεκτή
            # όχι πάνω στο breakpoint του wait_vbl: η επιστροφή θα το μετρούσε δεύτερη φορά
            if self.int_pending and self.m.pc != self.wait_vbl \
                    and self.m.on_handle_active_int():
                self.int_pending = False
                self.ints += 1
            pc = self.m.pc
            if pc == self.wait_vbl and events & z80.Z80Machine._BREAKPOINT_HIT:
                self.at_wait = True
                if not self.booted:     # first arrival = end of boot, not a game loop
                    self.booted = True
                    continue
                loops += 1
                if self.vsync_start_t is not None:
                    self.busy.append((self.frame_no, self.t - self.vsync_start_t))
                    self.vsync_start_t = None
                self.frame_no += 1
            if not (self.org <= pc < self.end or pc in (0x38, 0x39)):
                raise RuntimeError(f"PC escaped the program: #{pc:04X}")

    def peek(self, addr):
        return self.m.memory[addr]

    def poke(self, addr, value):
        self.m.memory[addr] = value

    def resolve(self, expr, syms):
        deref = expr.startswith('*')
        name, _, off = expr.lstrip('*').partition('+')
        addr = syms[name.upper()]
        if deref:
            addr = self.peek(addr) | (self.peek(addr + 1) << 8)
        return addr + (int(off) if off else 0)

    def screenshot(self, path):
        """640x400: each Mode 0 pixel 4x2, each Mode 1 pixel 2x2."""
        base = ((self.crtc[12] & 0x30) << 10) | ((self.crtc[12] & 0x03) << 9) | (self.crtc[13] << 1)
        img = Image.new('RGB', (640, 400))
        px = img.load()
        mem = self.m.memory
        for y in range(200):
            for xb in range(80):
                addr = (base & 0xC000) | ((base + (y >> 3) * 80 + xb) & 0x7FF) | ((y & 7) << 11)
                b = mem[addr]
                if self.mode == 0:
                    pens = [((b >> 7) & 1) | ((b >> 2) & 2) | ((b >> 3) & 4) | ((b << 2) & 8),
                            ((b >> 6) & 1) | ((b >> 1) & 2) | ((b >> 2) & 4) | ((b << 3) & 8)]
                else:
                    pens = [((b >> (7 - n)) & 1) | (((b >> (3 - n)) & 1) << 1) for n in range(4)]
                w = 8 // len(pens)
                for n, pen in enumerate(pens):
                    rgb = HW_RGB[self.inks[pen]]
                    for dx in range(w):
                        for dy in (0, 1):
                            px[xb * 8 + n * w + dx, y * 2 + dy] = rgb
        img.save(path)


def render_wav(log, end_t, path, rate=22050):
    """Play back PSG register writes through a simple AY-3-8912 model."""
    import array
    import wave
    cpu_hz, ay_hz = 4_000_000, 1_000_000
    vol = [0.0] + [2 ** ((v - 15) / 2) for v in range(1, 16)]
    regs = [0] * 16
    regs[7] = 0x3F
    phase = [0.0, 0.0, 0.0]
    noise_phase, lfsr, noise_bit = 0.0, 1, 1
    out = array.array('h')
    i, n_samples = 0, int(end_t / cpu_hz * rate)
    dc = 0.0
    for n in range(n_samples):
        t = n * cpu_hz / rate
        while i < len(log) and log[i][0] <= t:
            regs[log[i][1]] = log[i][2]
            i += 1
        np_ = (regs[6] & 31) or 1
        noise_phase += ay_hz / (16 * np_) / rate
        while noise_phase >= 1:
            noise_phase -= 1
            bit = (lfsr ^ (lfsr >> 3)) & 1
            lfsr = (lfsr >> 1) | (bit << 16)
            noise_bit = lfsr & 1
        acc = 0.0
        for ch in range(3):
            p = (regs[2 * ch] | (regs[2 * ch + 1] & 15) << 8) or 1
            phase[ch] = (phase[ch] + ay_hz / (16 * p) / rate) % 1.0
            tone_on = not (regs[7] >> ch) & 1
            noise_on = not (regs[7] >> (3 + ch)) & 1
            level = ((phase[ch] < 0.5) or not tone_on) and (noise_bit or not noise_on)
            if level and (tone_on or noise_on):
                acc += vol[regs[8 + ch] & 15]
        dc += (acc - dc) * 0.002            # take the DC offset out
        out.append(max(-32767, min(32767, int((acc - dc) * 12000))))
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(out.tobytes())


# Ένας χαρακτήρας ανά κελί του board[]: 0-5 απλό, A-F ριγέ-οριζ., a-f ριγέ-κάθ.,
# u-z περιτύλιγμα, * βόμβα, k κεράσι, n φουντούκι, . κενό.
def cell_value(ch):
    if ch == '.':
        return 7
    if ch == '*':
        return 6
    if ch in 'kn':
        return 0x20 + (ch == 'n')
    for base, form in (('0', 0), ('A', 8), ('a', 16), ('u', 24)):
        if 0 <= ord(ch) - ord(base) < 6:
            return form + ord(ch) - ord(base)
    raise ValueError(f"unknown board cell '{ch}'")


def cell_char(v):
    if v == 7:
        return '.'
    if v == 6:
        return '*'
    if v in (0x20, 0x21):
        return 'kn'[v & 1]
    return chr(ord('0Aau'[v >> 3]) + (v & 7)) if v < 32 else f"<{v:x}>"


# Ένας χαρακτήρας ανά cell[]: . κανονικό, j/J ζελέ 1/2, 1-3 γλάσο, c σοκολάτα,
# l γλυκόριζα, o τρύπα.
CELL_CHARS = {'.': 0x00, 'j': 0x20, 'J': 0x40, '1': 0x0A, '2': 0x12, '3': 0x1A,
              'c': 0x03, 'l': 0x04, 'o': 0x01}


def parse_value(v, cpc, syms):
    """#hex, decimal, or a symbol (its address)."""
    if v.startswith('#'):
        return int(v[1:], 16)
    if v.lstrip('-').isdigit():
        return int(v)
    return cpc.resolve(v, syms)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('binary')
    ap.add_argument('--org', default='0100')
    ap.add_argument('--sym')
    ap.add_argument('--script')
    ap.add_argument('--out', default='build/shots')
    ap.add_argument('--frames', type=int, default=50, help='frames to run when no script')
    ap.add_argument('--wav', help='render what the PSG played to this WAV file')
    args = ap.parse_args()

    syms = load_symbols(args.sym)
    cpc = CPC(open(args.binary, 'rb').read(), int(args.org, 16), syms)
    os.makedirs(args.out, exist_ok=True)

    steps = []
    if args.script:
        for raw in open(args.script):
            line = raw.split(';', 1)[0].strip()
            if line:
                steps.append(line.split())
    else:
        steps = [['run', str(args.frames)], ['shot', 'final']]

    failures = 0
    for st in steps:
        cmd = st[0]
        if cmd == 'run':
            keys = st[2].split('+') if len(st) > 2 and st[2] != '-' else []
            cpc.set_keys(keys)
            cpc.run_frames(int(st[1]))
        elif cmd == 'shot':
            path = os.path.join(args.out, st[1] + '.png')
            cpc.screenshot(path)
            print(f"shot {path}")
        elif cmd == 'until':
            addr = cpc.resolve(st[1], syms)
            want = parse_value(st[2], cpc, syms)
            rest = st[3:]
            keys = rest[0].split('+') if rest and rest[0] != '-' else []
            limit = int(rest[1]) if len(rest) > 1 else 3000
            cpc.set_keys(keys)
            n = 0
            while cpc.peek(addr) != want and n < limit:
                cpc.run_frames(1)
                n += 1
            if cpc.peek(addr) != want:
                failures += 1
                print(f"FAIL {' '.join(st)}: got {cpc.peek(addr)} after {n} frames")
                break
        elif cmd == 'setboard':
            b = syms['BOARD']
            for i, ch in enumerate(''.join(st[1:9])):
                cpc.poke(b + i, cell_value(ch))
                cpc.poke(syms['CELL'] + i, 0x80)
                cpc.poke(syms['DIRTY_Q'] + i, i)
            cpc.poke(syms['DQ_HEAD'], 0)
            cpc.poke(syms['DQ_TAIL'], 0)
            cpc.poke(syms['DQ_N'], 64)
            cpc.poke(syms['INGR_SPAWN'], 0)         # κανένα υλικό στην τύχη
            cpc.poke(syms['LV_GOAL'], 0xFF)         # καμία νίκη: G_ENDLESS
            cpc.poke(syms['INGR_BOARD'], sum((cpc.peek(b + i) & 0x27) in (0x20, 0x21) for i in range(64)))
        elif cmd == 'setcells':
            for i, ch in enumerate(''.join(st[1:9])):
                v = CELL_CHARS[ch]
                cpc.poke(syms['CELL'] + i, v | 0x80)
                if v & 7:
                    cpc.poke(syms['BOARD'] + i, 7)
        elif cmd == 'expectcells':
            inv = {v: k for k, v in CELL_CHARS.items()}
            want = ''.join(st[1:9])
            got = ''.join(inv.get(cpc.peek(syms['CELL'] + i) & 0x7F, '?') for i in range(64))
            ok = all(w in ('?', g) for w, g in zip(want, got))
            failures += not ok
            print(f"{'ok  ' if ok else 'FAIL'} cells" + ('' if ok else
                  '\n  got      ' + ' '.join(got[i:i + 8] for i in range(0, 64, 8)) +
                  '\n  expected ' + ' '.join(want[i:i + 8] for i in range(0, 64, 8))))
        elif cmd == 'countcells':
            v = CELL_CHARS[st[1]]
            got = sum((cpc.peek(syms['CELL'] + i) & 0x7F) == v for i in range(64))
            ok = got == int(st[2])
            failures += not ok
            print(f"{'ok  ' if ok else 'FAIL'} cells '{st[1]}' = {got} (expected {st[2]})")
        elif cmd == 'expectboard':
            b = syms['BOARD']
            want = ''.join(st[1:9])
            got = ''.join(cell_char(cpc.peek(b + i)) for i in range(64))
            ok = all(w in ('?', g) or (w == '#' and g != '.') for w, g in zip(want, got))
            failures += not ok
            print(f"{'ok  ' if ok else 'FAIL'} board" + ('' if ok else
                  '\n  got      ' + ' '.join(got[i:i + 8] for i in range(0, 64, 8)) +
                  '\n  expected ' + ' '.join(want[i:i + 8] for i in range(0, 64, 8))))
        elif cmd == 'board':
            b = syms['BOARD']
            for y in range(8):
                print('  ' + ' '.join(cell_char(cpc.peek(b + y * 8 + x)) for x in range(8)))
        elif cmd in ('psg', 'psgon'):
            reg = int(st[1])
            got = cpc.psg[reg]
            ok = got == int(st[2]) if cmd == 'psg' else (got & 15) != 0
            failures += not ok
            print(f"{'ok  ' if ok else 'FAIL'} psg {reg} = {got}" + (f" (expected {st[2]})" if cmd == 'psg' else " (expected sound)"))
        elif cmd == 'print':
            addr = cpc.resolve(st[1], syms)
            count = int(st[2]) if len(st) > 2 else 1
            print(f"{st[1]}: " + ' '.join(f"{cpc.peek(addr + i):02x}" for i in range(count)))
        elif cmd in ('expect', 'poke', 'pokew'):
            value = parse_value(st[2], cpc, syms)
            addr = cpc.resolve(st[1], syms)
            if cmd == 'poke':
                cpc.poke(addr, value)
                continue
            if cmd == 'pokew':
                cpc.poke(addr, value & 0xFF)
                cpc.poke(addr + 1, value >> 8)
                continue
            got = cpc.peek(addr)
            ok = got == value
            failures += not ok
            print(f"{'ok  ' if ok else 'FAIL'} {st[1]} = {got} (expected {value})")
        else:
            sys.exit(f"unknown script command: {cmd}")

    if args.wav:
        render_wav(cpc.psg_log, cpc.t, args.wav)
        print(f"wav {args.wav}: {cpc.t / 4e6:.1f} s, {len(cpc.psg_log)} PSG writes")
    if cpc.busy:
        frame, worst = max(cpc.busy, key=lambda b: b[1])
        over = [f for f, t in cpc.busy if t > FRAME_T]
        print(f"frames: {len(cpc.busy)}, worst per-frame work: {worst} T in loop {frame} "
              f"({100 * worst / FRAME_T:.0f}% of a 50Hz frame, before wait states)"
              + (f"; over budget in loops {over}" if over else ""))
    if failures:
        sys.exit(f"{failures} expectation(s) failed")


if __name__ == '__main__':
    main()
