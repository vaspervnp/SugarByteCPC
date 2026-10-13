#!/bin/bash
# Sugar Byte for Windows (run from WSL; `make windows`):
#   build/win/SugarByte.exe          one file: the launcher, with Caprice32 (the emulator),
#                                    its ROMs and the game's disc inside
#   build/win/SugarByte-win64.zip    that exe, the manuals, how to play, the licences
# The launcher (tools/windows/Launcher.cs) is compiled by the .NET Framework's csc.exe on the
# Windows side; Caprice32's Windows release is downloaded once into build/win/ (or copied
# from BuildDangerousCPC, which already has it). From BuildDangerousCPC/tools/mkwin.sh.
set -e
cd "$(dirname "$0")/.."
B=build/win
CAP_URL=https://github.com/ColinPitrat/caprice32/releases/download/latest/cap32-win64.zip
CAP_SIBLING=../BuildDangerousCPC/build/win/cap32-win64.zip
CSC=/mnt/c/Windows/Microsoft.NET/Framework64/v4.0.30319/csc.exe

mkdir -p $B
if [ ! -f $B/cap32-win64.zip ]; then
    if [ -f $CAP_SIBLING ]; then cp $CAP_SIBLING $B/; else curl -sfL -o $B/cap32-win64.zip $CAP_URL; fi
fi

# The payload: Caprice32 as released, set up for the game, and the disc
rm -rf $B/payload $B/payload.zip
mkdir -p $B/payload
unzip -q $B/cap32-win64.zip -d $B/payload
mv $B/payload/cap32-win64/* $B/payload/
rmdir $B/payload/cap32-win64
rm -rf $B/payload/resources/freedesktop $B/payload/resources/Info.plist
cp build/sugar.dsk $B/payload/sugar.dsk
mkdir -p $B/payload/screenshots $B/payload/snap     # where F3 / Shift+F3 save
cp tools/windows/README.txt $B/payload/SugarByte.txt
python3 - $B/payload/cap32.cfg <<'PY'
import re, sys
p = sys.argv[1]
cfg = open(p, encoding='latin-1').read()
for key, value in {
    'model': 2,                 # CPC6128: disc drive, RUN"SUGAR
    'scr_scale': 3,             # 1152x810 window: the overscan picture, three times
    'scr_fps': 0,               # no FPS counter over the game
    'scr_led': 0,
    'auto_pause': 1,            # pause while the window is in the background
}.items():
    cfg, n = re.subn(rf'^{key}=.*$', f'{key}={value}', cfg, flags=re.M)
    assert n == 1, key
open(p, 'w', encoding='latin-1').write(cfg)
PY
(cd $B/payload && zip -qr ../payload.zip .)

# The icon: the red candy, from the game's own sprite sheet (Mode 0: pixels twice as wide)
python3 - $B/icon.ico <<'PY'
import sys
from PIL import Image
sheet = Image.open('assets/sheets/candy_cpc_mode0_sheet.png').convert('RGBA')
candy = sheet.crop((0, 0, 12, 24)).resize((24, 24), Image.NEAREST)
px = candy.load()
for y in range(24):
    for x in range(24):
        if px[x, y][:3] == (0, 0, 0):
            px[x, y] = (0, 0, 0, 0)
candy.resize((240, 240), Image.NEAREST).crop((-8, -8, 248, 248)).save(
    sys.argv[1], sizes=[(16, 16), (32, 32), (48, 48), (256, 256)])
PY

# Compile on the Windows side (csc wants Windows paths, and local ones are safest)
WTMP=$(wslpath "$(cmd.exe /c 'echo %TEMP%' 2>/dev/null | tr -d '\r')")/sb-launcher
rm -rf "$WTMP"
mkdir -p "$WTMP"
cp tools/windows/Launcher.cs $B/payload.zip $B/icon.ico "$WTMP/"
(cd "$WTMP" && "$CSC" /nologo /optimize /target:winexe /out:SugarByte.exe \
    /win32icon:icon.ico /resource:payload.zip,payload.zip \
    /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll \
    /r:System.Windows.Forms.dll Launcher.cs | tr -d '\r')
cp "$WTMP/SugarByte.exe" $B/SugarByte.exe
rm -rf "$WTMP"

# The release zip
rm -rf $B/release $B/SugarByte-win64.zip
mkdir -p $B/release/SugarByte/licences
cp $B/SugarByte.exe tools/windows/README.txt docs/manual-en.pdf docs/manual-el.pdf $B/release/SugarByte/
cp $B/payload/COPYING.txt $B/release/SugarByte/licences/Caprice32-GPL.txt
cp $B/payload/licenses/* $B/release/SugarByte/licences/
(cd $B/release && zip -qr ../SugarByte-win64.zip SugarByte)
ls -l $B/SugarByte.exe $B/SugarByte-win64.zip
