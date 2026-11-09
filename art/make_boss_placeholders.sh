#!/usr/bin/env bash
# Draws stand-in pictures for new bosses until their art is made: add a line for each
# below. Replace them with art/import_boss_art.sh. Requires ImageMagick 7.
#   Boss<Name>.png        the boss list and overview: a coloured glow with the initial
#   Figure<Name>.png      the boss in the fight: a silhouette on transparent ground
#   Background<Name>.png  behind the boss in the fight: sky, horizon and ground
set -euo pipefail
cd "$(dirname "$0")/../assets/bosses"
font=../onboarding/fonts/CinzelDecorative-Bold.ttf

# name, inner colour, outer colour, letter, sky colour, ground colour
while read -r name inner outer letter sky ground; do
	magick -size 1024x768 "radial-gradient:$inner-$outer" \
		-font "$font" -gravity center -pointsize 420 -fill '#00000066' -annotate +14+24 "$letter" \
		-fill '#f6d68acc' -annotate +0+0 "$letter" \
		-pointsize 34 -fill '#ffffff55' -gravity south -annotate +0+28 'PLACEHOLDER' \
		-depth 8 -strip "Boss$name.png"

	# A body, a head and two arms, filled with the boss's colours and outlined in gold.
	magick -size 768x1024 "radial-gradient:$inner-$outer" \
		\( -size 768x1024 xc:black -fill white \
			-draw 'ellipse 384 640 250 330 0 360' \
			-draw 'circle 384 250 384 105' \
			-draw 'roundrectangle 60 420 220 560 60 60' \
			-draw 'roundrectangle 548 420 708 560 60 60' \) \
		-alpha off -compose CopyOpacity -composite -compose Over \
		\( +clone -alpha extract -morphology EdgeOut Disk:6 -background '#f6d68a' -alpha shape \) -composite \
		-font "$font" -gravity center -pointsize 330 -fill '#00000055' -annotate +10+130 "$letter" \
		-fill '#f6d68add' -annotate +0+120 "$letter" \
		-pointsize 30 -fill '#ffffff88' -annotate +0+420 'PLACEHOLDER' \
		-depth 8 -strip "Figure$name.png"

	magick -size 900x1000 "gradient:$sky-$outer" \
		\( -size 900x600 "gradient:$ground-#000000" \) -append \
		-font "$font" -gravity south -pointsize 30 -fill '#ffffff44' -annotate +0+60 'PLACEHOLDER BACKGROUND' \
		-depth 8 -strip "Background$name.png"
done <<'LIST'
LIST
