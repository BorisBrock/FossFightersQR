#!/usr/bin/env bash
# Draws stand-in pictures for the dummy bosses in scripts/bosses.gd: a coloured glow with
# the boss's initial. Replace them with art/import_boss_art.sh. Requires ImageMagick 7.
set -euo pipefail
cd "$(dirname "$0")/../assets/bosses"
font=../onboarding/fonts/CinzelDecorative-Bold.ttf

# name, inner colour, outer colour, letter
while read -r name inner outer letter; do
	magick -size 1024x768 "radial-gradient:$inner-$outer" \
		-font "$font" -gravity center -pointsize 420 -fill '#00000066' -annotate +14+24 "$letter" \
		-fill '#f6d68acc' -annotate +0+0 "$letter" \
		-pointsize 34 -fill '#ffffff55' -gravity south -annotate +0+28 'PLACEHOLDER' \
		-depth 8 -strip "$name.png"
done <<'LIST'
BossMirefang #4f7a3a #0d1a0b M
BossAshwing #c4561d #2a0905 A
BossColossus #8a6a2e #15110a C
LIST
