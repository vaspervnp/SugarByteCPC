#!/usr/bin/env python3
"""Build an Amstrad CPC .CDT (TZX) cassette image from a raw binary.

A portable pure-Python reimplementation of `2cdt`'s default mode (method 0:
2K firmware blocks, turbo-loading TZX 0x11 blocks) -- byte-for-byte identical
to 2cdt so the format is verifiably correct without shipping a C binary.
The output is a RUN"-able tape file, type binary.

  python3 tools/mkcdt.py build/sugar.bin build/sugar.cdt --name=SUGAR --load=0100

(From TerraCPC/tools/mkcdt.py, with --load: the address the file loads and
starts at, in hex.)
"""
import struct
import sys

BAUD = 2000
PILOT_PULSES = 2048 * 2          # CPC pilot tone length, in pulses
HEADER_SYNC = 0x2C               # firmware header-block sync byte
DATA_SYNC = 0x16                 # firmware data-block sync byte
CHUNK = 256                      # a firmware block is a run of 256-byte chunks
BLOCK = 2048                     # max useful data per firmware block
HDR_PAUSE_MS = 10                # pause after the header block
DATA_PAUSE_MS = 2500             # pause after each data block
INITIAL_PAUSE_MS = 3000          # leading silence


def crc16(data):
    """CRC-16/CCITT (poly 0x1021), init 0xFFFF -- exactly 2cdt's CRCupdate."""
    crc = 0xFFFF
    for b in data:
        aux = (crc ^ (b << 8)) & 0xFFFF
        for _ in range(8):
            if aux & 0x8000:
                aux = ((aux << 1) ^ 0x1021) & 0xFFFF
            else:
                aux = (aux << 1) & 0xFFFF
        crc = aux
    return crc


def turbo_block(sync, data, pause_ms):
    """One firmware block as a TZX 0x11 turbo-loading data block."""
    # CPC pulse lengths, in Spectrum (3.5MHz) T-states.  The firmware guide:
    # zero-half-period microseconds = 333333 / baud; *4 -> CPC (4MHz) T-states;
    # *0.875 (== 224/256, 3.5/4 MHz) -> Spectrum T-states.
    zero = (((333333 // BAUD) << 2) * 224) >> 8
    one = zero << 1

    # payload: sync byte, then each 256-byte chunk followed by its inverted CRC,
    # then an 8-byte 0xFF trailer (ensures the final pulse resolves).
    payload = bytearray([sync])
    n = (len(data) + CHUNK - 1) // CHUNK
    for i in range(n):
        chunk = bytearray(data[i * CHUNK:(i + 1) * CHUNK])
        chunk += b"\x00" * (CHUNK - len(chunk))
        c = crc16(chunk)
        payload += chunk
        payload.append((c >> 8) ^ 0xFF)
        payload.append((c & 0xFF) ^ 0xFF)
    payload += b"\xFF" * 8

    hdr = struct.pack("<HHHHHHBH", one, zero, zero, zero, one,
                      PILOT_PULSES, 8, pause_ms)          # pilot=one bit on CPC
    hdr += struct.pack("<I", len(payload))[:3]            # 24-bit data length
    return bytes([0x11]) + hdr + bytes(payload)


def tape_header(name, ftype, load, entry, total_len,
                block_no, first, last, block_len, location):
    h = bytearray(64)
    nm = name.upper().encode("ascii")[:16]
    h[0:len(nm)] = nm
    h[16] = block_no
    h[17] = 0xFF if last else 0x00
    h[18] = ftype
    h[19] = block_len & 0xFF
    h[20] = (block_len >> 8) & 0xFF
    h[21] = location & 0xFF
    h[22] = (location >> 8) & 0xFF
    h[23] = 0xFF if first else 0x00
    h[24] = total_len & 0xFF
    h[25] = (total_len >> 8) & 0xFF
    h[26] = entry & 0xFF
    h[27] = (entry >> 8) & 0xFF
    return bytes(h)


def build(binary, name="", load=0x1000, entry=0x1000, ftype=2):
    out = bytearray(b"ZXTape!\x1A\x01\x0A")               # TZX 1.10 header
    out += bytes([0x20]) + struct.pack("<H", INITIAL_PAUSE_MS)  # leading pause
    total = len(binary)
    off = 0
    block_no = 1
    location = load
    first = True
    while True:
        remaining = total - off
        blen = min(BLOCK, remaining)
        last = remaining <= BLOCK
        hdr = tape_header(name, ftype, load, entry, total,
                          block_no, first, last, blen, location)
        out += turbo_block(HEADER_SYNC, hdr, HDR_PAUSE_MS)
        out += turbo_block(DATA_SYNC, binary[off:off + blen], DATA_PAUSE_MS)
        first = False
        off += blen
        location += blen
        block_no += 1
        if off >= total:
            break
    return bytes(out)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    name, load = "", 0x1000
    for a in sys.argv[1:]:
        if a.startswith("--name="):
            name = a.split("=", 1)[1]
        if a.startswith("--load="):
            load = int(a.split("=", 1)[1], 16)
    if len(args) < 2:
        sys.exit("usage: mkcdt.py <in.bin> <out.cdt> [--name=NAME] [--load=HEX]")
    data = open(args[0], "rb").read()
    open(args[1], "wb").write(build(data, name=name, load=load, entry=load))
    print("mkcdt: %s -> %s (%d bytes, %d blocks)" %
          (args[0], args[1], len(data), (len(data) + BLOCK - 1) // BLOCK))


if __name__ == "__main__":
    main()
