#!/usr/bin/env bash
# Copies the icons, frames, buttons, controls, boss shields, action orbs and the dryad's form
# portraits from a folder of finished artwork into the project, trimmed and scaled down to
# what the screen needs. Requires ImageMagick 7. See docs/artwork_prompts.md.
# Usage: art/import_ui_art.sh ~/Downloads/FossArtwork
#
# Godot draws theme icons (toggles, slider knob, the pen in a text field) and the edges of
# the nine-patch buttons at their pixel size, so those are made exactly as large as on
# screen. Everything else is drawn scaled and is made larger, with mipmaps.
set -euo pipefail
src=$(realpath "$1")
cd "$(dirname "$0")/.."

# The box around what is not (nearly) transparent. AI images have faint noise in the
# transparent parts, which a plain -trim would keep.
content() {
	magick "$1" -alpha extract -threshold 3% -format '%@' info:
}

# fit <source> <target> <width> <height>: trimmed, scaled to fit the box, aspect kept.
fit() {
	magick "$1" -crop "$(content "$1")" +repage -filter Lanczos -resize "$3x$4" -strip "$2"
}

# square <source> <target> <size>: trimmed, scaled to fit and centred on a square, so that
# icons all sit the same way in text and on chips.
square() {
	magick "$1" -crop "$(content "$1")" +repage -filter Lanczos -resize "$3x$3" \
		-background none -gravity center -extent "$3x$3" -strip "$2"
}

# Fight icons. icon_shield shows a helmet: in the game it is icon_protection.
for name in card claw crown damage fire give_up heal health lightning magic magic_support melee \
	melee_support panic paralysis poison ranged ranged_support robot round totem wound; do
	square "$src/icon_$name.png" "assets/fight/icon_$name.png" 256
done
square "$src/icon_shield.png" assets/fight/icon_protection.png 256

# A hero's actions left this round (ActionSpheres).
for color in blue green red yellow; do
	square "$src/action_orb_$color.png" "assets/fight/action_orb_$color.png" 64
done

# The boss's shields (Boss.shield_icon).
for kind in normal dark poison; do
	fit "$src/boss_shield_$kind.png" "assets/fight/boss_shield_$kind.png" 192 224
done

# The dryad's forms replace her portrait (HeroOptions.RACES.dryad.forms).
for form in thorn blossom bark; do
	magick "$src/character_dryad_${form}_form.png" -alpha off -filter Lanczos -resize 640x640 -strip \
		"assets/onboarding/portraits/CharacterDryad${form^}.png"
done

# Interface icons.
square "$src/icon_settings.png" assets/icon_settings.png 256
square "$src/icon_switch_camera.png" assets/icon_switch_camera.png 256
square "$src/dice.png" assets/onboarding/icons/dice.png 192
square "$src/pen.png" assets/onboarding/icons/pen.png 32

# Frames and ornaments.
fit "$src/card_scan.png" assets/onboarding/icons/card_scan.png 400 560
fit "$src/corner.png" assets/onboarding/icons/corner.png 320 320
fit "$src/divider.png" assets/fight/divider.png 720 120

# Buttons are nine-patches (see the theme): the gem in the middle of their top and bottom
# edge would be stretched, so it is painted over with the edge beside it.
for name in primary secondary danger; do
	art="$src/button_$name.png"
	strip=$(magick "$art" -format '180x%h+450+0' info:)
	tmp=$(mktemp --suffix=.png)
	magick "$art" -compose Copy \
		\( "$art" -crop "$strip" +repage \) -geometry +630+0 -composite \
		\( "$art" -crop "$strip" +repage \) -geometry +810+0 -composite "$tmp"
	fit "$tmp" "assets/onboarding/icons/button_$name.png" 400 58
	rm -f "$tmp"
done
fit "$src/toggle_on.png" assets/onboarding/icons/toggle_on.png 76 42
fit "$src/toggle_off.png" assets/onboarding/icons/toggle_off.png 76 42
square "$src/slider_grabber.png" assets/onboarding/icons/slider_grabber.png 40
