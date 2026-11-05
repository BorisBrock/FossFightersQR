#!/usr/bin/env bash
# Copies the character portraits, class crests and table from a folder of finished artwork
# into the project, scaled down to what the screen needs. Requires ImageMagick 7.
# Usage: art/import_onboarding_art.sh ~/Downloads/Icon
set -euo pipefail
src=$1
cd "$(dirname "$0")/../assets/onboarding"

for name in CharacterHalfling CharacterDwarf CharacterElb CharacterTroll CharacterGoblin CharacterDryad; do
	magick "$src/$name.png" -alpha off -filter Lanczos -resize 640x640 -strip "portraits/$name.png"
done
for name in ClassPaladin ClassMagician ClassWarrior ClassThief ClassDruid ClassShaman; do
	magick "$src/$name.png" -alpha off -filter Lanczos -resize 640x640 -strip "crests/$name.png"
done
# The game is in portrait mode, so the table is turned to fill the screen.
magick "$src/Table.png" -rotate 90 -strip table.png
