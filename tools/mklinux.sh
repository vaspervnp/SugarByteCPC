#!/bin/bash
# Sugar Byte for Linux (`make linux`):
#   build/linux/SugarByte                    one file: a launcher script with Caprice32,
#                                            its libraries, its ROMs and the disc behind it
#   build/linux/SugarByte-linux-x64.tar.gz   that file, the manuals, how to play, the licences
# Caprice32 has no Linux release of its own: the binary, its resources and ROMs, and the
# libraries a desktop may lack come from the caprice32 snap (4.6.0, built on core24) and
# from core24 itself, so it needs glibc 2.38+. The Linux twin of tools/mkwin.sh.
set -e
cd "$(dirname "$0")/.."
B=build/linux
SNAP=/snap/caprice32/current
CORE=/snap/core24/current
[ -x $SNAP/usr/bin/cap32 ] || { echo "mklinux: needs the caprice32 snap (snap install caprice32)"; exit 1; }

# The payload: Caprice32 as the snap has it, set up for the game, and the disc
rm -rf $B/payload
mkdir -p $B/payload/lib $B/payload/screenshots $B/payload/snap $B/payload/licences
cp $SNAP/usr/bin/cap32 $B/payload/
cp -r $SNAP/usr/bin/rom $SNAP/usr/bin/resources $B/payload/
rm -rf $B/payload/resources/freedesktop $B/payload/resources/Info.plist
for l in libSDL2-2.0.so.0 libfreetype.so.6 libsamplerate.so.0 libdecor-0.so.0; do
    cp -L $SNAP/usr/lib/x86_64-linux-gnu/$l $B/payload/lib/
done
for l in libpng16.so.16 libbrotlidec.so.1 libbrotlicommon.so.1 libbz2.so.1.0 \
         libstdc++.so.6 libgcc_s.so.1; do
    cp -L $CORE/usr/lib/x86_64-linux-gnu/$l $B/payload/lib/
done
# libdecor draws the window frame on Wayland through a plugin of its own
[ -d $SNAP/usr/lib/x86_64-linux-gnu/libdecor ] && cp -r $SNAP/usr/lib/x86_64-linux-gnu/libdecor $B/payload/lib/
for d in libsdl2-2.0-0 libfreetype6 libsamplerate0 libdecor-0-0; do
    cp $SNAP/usr/share/doc/$d/copyright $B/payload/licences/$d.txt
done
for d in libpng16-16t64 libbrotli1 libbz2-1.0 libstdc++6; do
    cp $CORE/usr/share/doc/$d/copyright $B/payload/licences/$d.txt
done
# The GPL, from Caprice32's own Windows release (build/win/, or BuildDangerousCPC's)
CAPZIP=build/win/cap32-win64.zip
[ -f $CAPZIP ] || CAPZIP=../BuildDangerousCPC/build/win/cap32-win64.zip
unzip -p $CAPZIP cap32-win64/COPYING.txt > $B/payload/licences/Caprice32-GPL.txt
cp build/sugar.dsk $B/payload/sugar.dsk
cp tools/linux/README.txt $B/payload/SugarByte.txt
python3 - $HOME/snap/caprice32/current/etc/cap32.cfg $B/payload/cap32.cfg <<'PY'
import re, sys
cfg = open(sys.argv[1], encoding='latin-1').read()
for key, value in {
    'model': 2,                 # CPC6128: disc drive, RUN"SUGAR
    'scr_scale': 3,             # 1152x810 window: the overscan picture, three times
    'scr_fps': 0,               # no FPS counter over the game
    'scr_led': 0,
    'auto_pause': 1,            # pause while the window is in the background
    # Empty would not do: on Linux, 4.6 falls back to the path it was built in. @DIR@
    # becomes the folder the launcher unpacks to.
    'resources_path': '@DIR@/resources', 'rom_path': '@DIR@/rom', 'cart_path': '@DIR@',
    'snap_path': '@DIR@/snap', 'dsk_path': '@DIR@', 'tape_path': '@DIR@',
    'sdump_dir': '@DIR@/screenshots', 'printer_file': '@DIR@/printer.dat',
}.items():
    cfg, n = re.subn(rf'^{key}=.*$', f'{key}={value}', cfg, flags=re.M)
    assert n == 1, key
assert '/home/' not in cfg and '/snap/' not in cfg, 'a path of this machine is left'
open(sys.argv[2], 'w', encoding='latin-1').write(cfg)
PY
tar -czf $B/payload.tar.gz -C $B/payload --owner=0 --group=0 .

# The launcher, with the payload behind it
HASH=$(sha1sum $B/payload.tar.gz | cut -c1-12)
sed "s/@HASH@/$HASH/" tools/linux/launcher.sh > $B/SugarByte
cat $B/payload.tar.gz >> $B/SugarByte
chmod +x $B/SugarByte

# The release
rm -rf $B/release $B/SugarByte-linux-x64.tar.gz
mkdir -p $B/release/SugarByte
cp $B/SugarByte tools/linux/README.txt docs/manual-en.pdf docs/manual-el.pdf $B/release/SugarByte/
cp -r $B/payload/licences $B/release/SugarByte/
tar -czf $B/SugarByte-linux-x64.tar.gz -C $B/release --owner=0 --group=0 SugarByte
ls -l $B/SugarByte $B/SugarByte-linux-x64.tar.gz
