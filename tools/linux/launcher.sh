#!/bin/sh
# Sugar Byte for Linux: one file with the game and an Amstrad CPC emulator in it.
#
# Behind this script is a tar.gz (tools/mklinux.sh): Caprice32, the libraries it needs, its
# ROMs and the game's disc. On the first run it is unpacked to
# ~/.local/share/SugarByte/<hash> - nothing is installed, and a new version unpacks beside
# the old one - then Caprice32 starts with the disc in drive A and types RUN"SUGAR.
# Arguments are passed on to Caprice32 (e.g. -a "..." to type something else, which
# replaces RUN"SUGAR). The Linux twin of tools/windows/Launcher.cs.
set -e
HASH=@HASH@
DIR="${XDG_DATA_HOME:-$HOME/.local/share}/SugarByte/$HASH"
if [ ! -f "$DIR/.unpacked" ]; then
    rm -rf "$DIR"                      # a half-finished earlier attempt
    mkdir -p "$DIR"
    skip=$(awk '/^__PAYLOAD__$/ { print NR + 1; exit }' "$0")
    tail -n +"$skip" "$0" | tar -xzf - -C "$DIR"
    # the config's paths: the folder it was unpacked to (& and | escaped for sed)
    esc=$(printf '%s' "$DIR" | sed 's/[&|\\]/\\&/g')
    sed -i "s|@DIR@|$esc|g" "$DIR/cap32.cfg"
    touch "$DIR/.unpacked"
fi
cd "$DIR"
case " $* " in
    *" -a "*) ;;
    *) set -- -a 'run"sugar' "$@" ;;
esac
LD_LIBRARY_PATH="$DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    exec "$DIR/cap32" --cfg_file="$DIR/cap32.cfg" "$@" "$DIR/sugar.dsk"
exit 1
__PAYLOAD__
