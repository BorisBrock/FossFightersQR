#!/usr/bin/env bash
# Regenerates the project and launcher icons from art/FossFighters.png.
# Requires ImageMagick 7.
set -euo pipefail
cd "$(dirname "$0")/.."

src=art/FossFighters.png

# The artwork is a rounded square on opaque black: make those corners transparent.
rounded=$(mktemp --suffix=.png)
trap 'rm -f "$rounded"' EXIT
magick "$src" -alpha set -fuzz 2% -fill none \
	-draw "alpha 0,0 floodfill" -draw "alpha 1253,0 floodfill" \
	-draw "alpha 0,1253 floodfill" -draw "alpha 1253,1253 floodfill" \
	-channel A -blur 0x1.5 -level 50%,100% +channel \
	"$rounded"

# Project/window icon, also the legacy Android launcher icon.
magick "$rounded" -filter Lanczos -resize 512x512 -strip icon.png

# Android adaptive layers are 432px, of which launchers show the central 288px at
# most and may mask it to a circle. Shrink the artwork so that the title survives
# a circular mask, on a solid colour taken from the artwork's dark edge.
magick "$rounded" -filter Lanczos -resize 248x248 -background none -gravity center \
	-extent 432x432 -strip assets/icon_adaptive_foreground.png
magick -size 432x432 xc:'#130b23' -strip assets/icon_adaptive_background.png

# Themed icons: Godot ships its own logo here unless this layer is set. Uses the
# QR glyph from the artwork, as white on transparent.
magick "$src" -crop 276x266+490+380 +repage -colorspace Gray -blur 0x1 -threshold 72% \
	-filter Lanczos -resize 200x200 -threshold 50% -alpha copy -fill white -colorize 100 \
	-background none -gravity center -extent 432x432 -strip assets/icon_adaptive_monochrome.png
