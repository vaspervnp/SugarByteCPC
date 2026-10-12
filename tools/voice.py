#!/usr/bin/env python3
"""voice/*.wav -> build/voice.bin + build/voice.asm: φωνή 4-bit για τον AY.

Ο AY δεν έχει DAC· έχει όμως καταχωρητή έντασης 4 bits ανά κανάλι, με τόνο
και θόρυβο κλειστούς. Γράφοντας εκεί ~5.500 φορές το δευτερόλεπτο, η ένταση
γίνεται το ίδιο το κύμα. Η κλίμακα του AY είναι λογαριθμική (~3 dB το σκαλί):
ένα κύμα γύρω από τη μέση της θα έπαιρνε 2-3 στάθμες. Γι' αυτό τα τρία κανάλια
παίζουν μαζί, και κάθε τιμή 0-15 του δείγματος είναι μια ΤΡΙΑΔΑ εντάσεων
(voice_tri) με άθροισμα σε ίσες, γραμμικές αποστάσεις: PCM 4-bit.

Δύο δείγματα το byte, το πρώτο στο πάνω nibble. Τα δεδομένα μπαίνουν στα κενά
της οθόνης overscan: 8 κομμάτια των 1.088 bytes, στο #C3C0 + k * #800. Το
voice.asm δίνει για κάθε φράση τη διεύθυνση της αρχής της στα κενά και το
μήκος της σε bytes.

  voice.py build/voice.bin build/voice.asm sugarbyte=voice/sugarbyte.wav ...
"""
import array
import subprocess
import sys

RATE = 5500
TARGET_RMS = 0.4
HOLE0, HOLE_STEP, HOLE_SIZE, HOLES = 0xC3C0, 0x800, 1088, 8

# Η ένταση του AY ανά στάθμη, κανονικοποιημένη (μετρήσεις του AY-3-8910).
AY_LEVELS = [0.0, 0.0137, 0.0205, 0.0291, 0.0423, 0.0618, 0.0847, 0.1369,
             0.1691, 0.2647, 0.3527, 0.4499, 0.5704, 0.6873, 0.8482, 1.0]


def load(path):
    """Mono, RATE Hz, ζώνη ομιλίας, κανονικοποιημένο στο [-1, 1]."""
    raw = subprocess.run(
        ['ffmpeg', '-loglevel', 'error', '-i', path,
         '-af', f'highpass=f=150,lowpass=f={RATE // 2 - 200},acompressor=threshold=0.1:ratio=4',
         '-ac', '1', '-ar', str(RATE), '-f', 's16le', '-'],
        check=True, capture_output=True).stdout
    s = array.array('h', raw)
    # Δυνατά, με βάση τη μέση ισχύ και όχι την κορυφή: η ομιλία έχει σπάνιες
    # κορυφές, και με 16 στάθμες ό,τι μείνει χαμηλά χάνεται. Οι κορυφές κόβονται.
    rms = max(1.0, (sum(v * v for v in s) / len(s)) ** 0.5)
    gain = TARGET_RMS / rms
    return [max(-1.0, min(1.0, v * gain)) for v in s]


def triplets():
    """16 τριάδες (A, B, C) με άθροισμα εντάσεων όσο πιο κοντά στο k/15 * 3."""
    combos = [(a, b, c) for a in range(16) for b in range(a, 16) for c in range(b, 16)]
    out = []
    for k in range(16):
        want = k / 15 * 3
        out.append(min(combos, key=lambda t: abs(sum(AY_LEVELS[x] for x in t) - want)))
    return out


def level(v):
    return max(0, min(15, round((v * 0.98 + 1) / 2 * 15)))


def hole_addr(offset):
    k, o = divmod(offset, HOLE_SIZE)
    return HOLE0 + k * HOLE_STEP + o


def main():
    out_bin, out_asm, *items = sys.argv[1:]
    blob, out = bytearray(), [
        f"; ΠΑΡΑΓΕΤΑΙ από το tools/voice.py — μην το πειράζεις.", '',
        f"VOICE_RATE      equ {RATE}"]
    for item in items:
        name, path = item.split('=', 1)
        lv = [level(v) for v in load(path)]
        if len(lv) % 2:
            lv.append(lv[-1])
        start = len(blob)
        blob += bytes((lv[i] << 4) | lv[i + 1] for i in range(0, len(lv), 2))
        size = len(blob) - start
        out.append(f"VOICE_{name.upper():<10} equ #{hole_addr(start):04X}   ; "
                   f"{len(lv) / RATE:.2f} s")
        out.append(f"VOICE_{name.upper()}_LEN equ {size}")
    if len(blob) > HOLE_SIZE * HOLES:
        sys.exit(f"η φωνή θέλει {len(blob)} bytes, τα κενά της οθόνης είναι {HOLE_SIZE * HOLES}")
    out.append(f"VOICE_BYTES     equ {len(blob)}")
    out += ['', '; δείγμα 0-15 -> εντάσεις των καναλιών A, B, C (και ένα κενό: 4 bytes)',
            'voice_tri:']
    for t in triplets():
        lin = sum(AY_LEVELS[x] for x in t)
        out.append(f"        db {t[0]:2d},{t[1]:2d},{t[2]:2d},0   ; {lin:.3f}")
    open(out_bin, 'wb').write(blob)
    open(out_asm, 'w').write('\n'.join(out) + '\n')
    print(f"{out_bin}: {len(blob)} bytes από τα {HOLE_SIZE * HOLES} των κενών της οθόνης")


if __name__ == '__main__':
    main()
