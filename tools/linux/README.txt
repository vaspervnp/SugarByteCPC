SUGAR BYTE - for Linux
REVIVE8BIT - 2026 - VASPER

An Amstrad CPC match-3 game, with the emulator that runs it included.

TO PLAY
  Run ./SugarByte (or double-click it, if your file manager runs programs). Nothing is
  installed: the first time, it unpacks the emulator and the game to
  ~/.local/share/SugarByte (about 15 MB), then starts. The REVIVE8BIT screen comes first
  (10 seconds, or press SPACE), then the game loads.

  If it won't start, make it executable first: chmod +x SugarByte

  Needs a 64-bit PC Linux with glibc 2.38 or newer: Ubuntu 24.04, Debian 13, Fedora 39,
  or newer (any current Arch, openSUSE Tumbleweed, Mint 22...), with X11 or Wayland.

KEYS
  Cursor keys        move the cursor
  SPACE              pick up a candy, swap it with the one next to it
  M                  music on / off
  ESC                back to the menu
  A joystick works too.

  On the menu: LEVEL, then SPACE, to type a level code. Level 1 is 4721.

  F1 opens the emulator's menu, F2 switches to full screen, F10 quits.

The manual: manual-en.pdf (English), manual-el.pdf (Greek).

THE EMULATOR
  Caprice32 4.6.0, https://github.com/ColinPitrat/caprice32 - free software under the GNU
  GPL, version 2 (licences/Caprice32-GPL.txt); its source code is at that address. It
  includes the Amstrad CPC system ROMs, which Amstrad allows to be distributed with
  emulators. It comes with the libraries it needs (SDL2, FreeType, libpng, libsamplerate,
  libdecor, Brotli, bzip2, the GCC C++ runtime); their licences are in licences/.
