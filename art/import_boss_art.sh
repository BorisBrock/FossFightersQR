#!/usr/bin/env bash
# Copies the boss pictures from a folder of finished artwork into the project, scaled down
# to what the screen needs. Requires ImageMagick 7.
# Usage: art/import_boss_art.sh ~/Downloads/Bosses
#
#   Boss<Name>.png        boss list and overview: landscape 4:3, cropped to 1024 x 768.
#                         The list crops it to a wide strip, so keep the face near the centre.
#   Figure<Name>.png      the boss in the fight: portrait, transparent around the boss,
#                         fitted into 768 x 1024 without cropping.
#   Background<Name>.png  behind the boss in the fight: portrait, cropped to 900 x 1600.
set -euo pipefail
src=$1
cd "$(dirname "$0")/../assets/bosses"
shopt -s nullglob

for file in "$src"/Boss*.png; do
	magick "$file" -alpha off -filter Lanczos -resize 1024x768^ -gravity center -extent 1024x768 -strip "$(basename "$file")"
done
for file in "$src"/Figure*.png; do
	magick "$file" -filter Lanczos -resize '768x1024>' -strip "$(basename "$file")"
done
for file in "$src"/Background*.png; do
	magick "$file" -alpha off -filter Lanczos -resize 900x1600^ -gravity center -extent 900x1600 -strip "$(basename "$file")"
done
