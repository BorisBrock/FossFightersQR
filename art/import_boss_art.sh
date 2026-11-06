#!/usr/bin/env bash
# Copies the boss pictures from a folder of finished artwork into the project, scaled down
# to what the screen needs. Requires ImageMagick 7.
# Usage: art/import_boss_art.sh ~/Downloads/Bosses
#
# Pictures are landscape, 4:3. The boss list crops them to a wide strip around the middle,
# so keep the boss's face near the centre.
set -euo pipefail
src=$1
cd "$(dirname "$0")/../assets/bosses"

for file in "$src"/Boss*.png; do
	magick "$file" -alpha off -filter Lanczos -resize 1024x768^ -gravity center -extent 1024x768 -strip "$(basename "$file")"
done
