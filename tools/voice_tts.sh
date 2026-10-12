#!/usr/bin/env bash
#
# Οι φράσεις του voice/ από τη φωνή των Windows (SAPI, «Microsoft David»),
# μέσα από το WSL. Δεν τρέχει στο build: τα voice/*.wav είναι στο repo.
#
#   tools/voice_tts.sh
set -euo pipefail
cd "$(dirname "$0")/.."
PS=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe
TMP="$(mktemp -d)"
W="$(wslpath -w "$TMP")"
"$PS" -NoProfile -Command "Add-Type -AssemblyName System.Speech;
  \$s = New-Object System.Speech.Synthesis.SpeechSynthesizer;
  foreach (\$p in @(@('sugarbyte','Sugar Byte!',0), @('sweet','Sweet!',-1),
                    @('crush','Sugar Crush!',0), @('delicious','Delicious!',0))) {
    \$s.Rate = \$p[2]; \$s.SetOutputToWaveFile('$W\\' + \$p[0] + '.wav'); \$s.Speak(\$p[1]) }
  \$s.Dispose()"
for f in sugarbyte sweet crush delicious; do
  ffmpeg -loglevel error -y -i "$TMP/$f.wav" \
    -af "silenceremove=start_periods=1:start_threshold=-40dB:stop_periods=1:stop_threshold=-40dB:stop_duration=0.15" \
    -ac 1 -ar 16000 -c:a pcm_s16le "voice/$f.wav"
done
rm -rf "$TMP"
