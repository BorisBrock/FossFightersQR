# Artwork prompts

Prompts for the AI-generated artwork, kept for making more of it in the same style.

**Status:** everything below is final, except `icon_check` (the confirm button), which is still an SVG placeholder.
The icons, frames, buttons, controls, boss shields, action orbs, the arrow and the dryad's form portraits are imported with
`art/import_ui_art.sh <folder>` (see [Putting them in](#putting-them-in)), the bosses with `art/import_boss_art.sh`.

**Also final, not listed here:** the character portraits (`assets/onboarding/portraits/`), the class crests
(`assets/onboarding/crests/`), the table (`assets/onboarding/table.png`) and the logo (`art/FossFighters.png`, from
which `art/build_icons.sh` makes the app icons and the splash). The particle sprites in `assets/fight/particles/` are
Kenney's CC0 pack. They are white shapes that the code tints, so they stay as they are.

## Global style instruction

Put this in front of every prompt below:

> Fantasy game asset in the style of Hearthstone: hand-painted digital art, bold readable shapes, chunky stylised
> proportions, rich saturated colours, warm golden rim light, soft painterly shading with crisp clean outlines,
> polished AAA mobile card game look. Ornaments are burnished gold and bronze with small gems, worn just enough to feel
> handmade. Single subject, centred, fully inside the frame with a small margin on every side. **Fully transparent
> background (PNG with alpha channel), no backdrop, no floor, no vignette, no cast shadow on the ground, no glow
> spilling to the image edges.** No text, no letters, no numbers, no logo, no watermark, no signature.

Notes:

- **Exceptions to the transparent background:** the `Boss<Name>.png` and
  `Background<Name>.png` pictures are full scenes and must be opaque. Their prompts say so; drop the transparency
  sentence of the global style for them.
- If a generator cannot make real transparency, ask for "on a flat solid pure #00FF00 background" instead and remove it
  afterwards (for example `magick in.png -fuzz 12% -transparent '#00ff00' out.png`). Avoid green in those subjects'
  edges, or use magenta (#FF00FF) for green subjects such as the poison icon and Mirefang.
- **Resolutions:** *Generate* is what to ask the generator for (or the nearest size it offers in that aspect ratio).
  *Final* is the size of the file in the project; scale down with Lanczos. Small icons are generated large and scaled
  down, so their shapes must stay readable at 32 px: one clear silhouette, few details, strong contrast.

## Bosses

Folder: `assets/bosses/`. Import with `art/import_boss_art.sh <folder>`, which crops and scales them to the final size.
Details in [bosses.md](bosses.md#artwork).

### Mirefang — The Serpent of the Rotmire

A giant venomous swamp serpent, like a monstrous anaconda, with evil eyes and huge fangs. It rears up out of the black
water of an eerie swamp, dives under it and bursts out again (see [bosses.md](bosses.md#mirefang)). Ambience: green
fireflies.

What the fight does with the pictures, and so what they need:

- **The figure is animated as one picture:** a wave runs up its body with the head swaying most, it sinks below the
  **bottom edge of the picture, which is the waterline**, and its eyes get a glow drawn over them (yellow, red when
  enraged). So the body must **run out of the bottom edge** as if rising from the water, with no water, splash or
  reflection drawn there. It needs some empty space left and right for the swaying. The eyes must be clearly visible,
  both of them, facing the viewer.
- **The background has water where the snake rises:** the snake's bottom edge sits at about four fifths of the screen's
  height, in its middle.
- The snake is green, so a generator that cannot make transparency uses magenta (#FF00FF), not green (see the notes
  above).

**`BossMirefang.png`** — boss list and overview. Generate 1536 × 1152 (4:3), final 1024 × 768. **Opaque.**

> A gigantic venomous swamp serpent, like a monstrous anaconda, rearing its head out of black swamp water at night,
> dark olive-green scales with a pattern of black blotches and a pale yellowish belly, slime and torn water weeds
> hanging from its body, a heavy wedge-shaped head with bony brow ridges, two evil glowing yellow eyes with slit
> pupils, jaws wide open showing two huge curved fangs dripping with luminous green venom. Its coils loop in and out
> of the water around it. Dead crooked trees, hanging moss, a broken jetty and a sunken boat, thick fog on the water,
> sickly green fireflies, a pale moon behind the clouds. Eerie and menacing. The head exactly in the centre of the
> picture, framed head and upper body. Full scene, opaque background.

**`FigureMirefang.png`** — the boss in the fight. Generate 1024 × 1365 (3:4), final at most 768 × 1024.
**Transparent.**

> A gigantic venomous swamp serpent, like a monstrous anaconda, front view, rearing up tall like a cobra about to
> strike, its thick body rising straight up from the bottom edge of the image in a gentle S-curve. Dark olive-green
> scales with black blotches and a pale yellowish belly, slime and torn water weeds hanging from it, a heavy
> wedge-shaped head with bony brow ridges in the upper part of the image, facing the viewer, two evil yellow eyes with
> slit pupils, both clearly visible, jaws wide open showing two huge curved fangs dripping with luminous green venom.
> The body is cut off by the bottom edge of the image, as if it rises out of water: no water, no splash, no
> reflection, no ground. Empty space to the left and right of the body and above the head. Transparent background.

Instead of the margin on every side from the global style: a margin left, right and at the top, none at the bottom.

**`BackgroundMirefang.png`** — behind the boss. Generate 1080 × 1920 (9:16), final 900 × 1600. **Opaque.**

> An eerie fantasy swamp at night, seen from just above the water: still, black, oily water fills the lower half of
> the picture, from the far bank down to the bottom edge, with a wide open stretch of water in the centre, where a
> monster will rise at about four fifths of the picture's height. Around it crooked dead trees with hanging moss, rotting roots, a
> broken jetty and a half-sunken boat at the sides, bubbles and green slime on the water, thick fog lying on it, a pale
> moon behind clouds in a dark green-violet sky, sickly green fireflies. No creature, no characters. The centre is
> open and calm, the lower fifth is dark water, nothing important near the edges. Full scene, opaque background.

## Fight icons

Folder: `assets/fight/`. They are shown small: in the text of messages, on buff chips, on the fight screen and on the
game-over screen. **Generate 1024 × 1024, final 256 × 256 PNG**, unless noted. Each keeps the colour of today's
placeholder, so that players recognise it.

| File | Means | Prompt (after the global style) |
|------|-------|--------------------------------|
| `icon_melee.png` | melee attack | A square game icon tile with rounded corners and a thin silver rim, crimson-red enamel field, a steel broadsword pointing diagonally up. |
| `icon_ranged.png` | ranged attack | A game icon tile shaped as a triangle with rounded corners and a thick silver rim, glossy golden-yellow enamel field, three wooden arrows with steel heads and white fletching, bound together at the lower left and fanning out to the upper right. |
| `icon_magic.png` | magic attack | A round glowing magic orb of deep blue and cyan light with a white sparkle in the centre, swirling arcane energy, thin silver rim. |
| `icon_damage.png` | the heroes' damage | A gold-hilted sword striking down with a bright white impact burst at the tip. |
| `icon_claw.png` | the boss's attack | Three huge bone-white monster claws slashing diagonally, with dark red streaks. |
| `icon_health.png` | health | A glossy deep-pink ruby heart with a pale pink rim and a white highlight. |
| `icon_heal.png` | healing | A glowing mint-green healing cross with soft white light and small leaves. |
| `icon_wound.png` | damage taken | A torn dark crimson heart split by a jagged crack, a drop of blood falling. |
| `icon_protection.png` | protection | A knight's helmet of polished steel with gold trim, seen from the front. |
| `icon_lightning.png` | Lightning | A bright yellow-white lightning bolt with a soft golden glow. |
| `icon_fire.png` | fire status | A lively flame, orange at the base, yellow and white at the tip. |
| `icon_poison.png` | poison status | A bubbling glass vial of toxic green liquid with a dark green cork, a drip running down. |
| `icon_panic.png` | panic status | A pink-magenta swirl of dizziness with small stars, like a spinning daze. |
| `icon_paralysis.png` | paralysis status | A crystal of pale blue ice with frozen shards and frost around it. |
| `icon_totem.png` | Totem | A small carved wooden shaman totem pole with a turquoise glowing spirit face. |
| `icon_robot.png` | the goblin's battle robot | The head of a small goblin-made battle robot, riveted silver plates, yellow glowing eyes, a crooked antenna. |
| `icon_melee_support.png`, `icon_ranged_support.png`, `icon_magic_support.png` | support of that type | The icon of the attack type with a bold silver plus sign at its lower right. There is no single support icon: a support of any type shows all three, overlapping. |
| `icon_card.png` | a card | A single fantasy playing card seen from the back, cream parchment with a gold ornamental border, slightly tilted. |
| `icon_round.png` | the round | An hourglass with a gold frame and glowing blue sand. |
| `icon_crown.png` | title on the game-over screen | A gold crown with blue sapphires and a soft shine. |
| `icon_check.png` | confirm button | A bold golden check mark with a dark bronze outline. |
| `icon_give_up.png` | give up button | A tattered white flag on a short wooden pole. Pure white and light grey only. |
| `action_orb_blue.png`, `…_yellow`, `…_red`, `…_green` | a hero's actions left (blue turns, yellow extra, red limited; green is unused) | A round faceted gemstone orb in a dark metal rim with a white sparkle. Final 64 × 64. |

**`boss_shield_normal.png`, `boss_shield_skull.png`, `boss_shield_poison.png`** — the boss's shields on the fight
screen, which the code makes glow and break; their value is shown below them. Normal is plain iron, skull (imported as
`boss_shield_dark.png`) is for shields that do something besides absorbing, poison has a green drop on it
(`Boss.SHIELD_*`). Generate 1024 × 1110, final
fitted into 192 × 224.

> A heavy dark iron heater shield seen from the front, blackened riveted metal, a thin bronze rim, battle scratches,
> plain flat centre without emblem.

**`arrow.png`** — the arrows of a ranged attack, which fly at the boss and stick in it (`AttackEffects.Arrow`). The
code turns them along their path, so the arrow must lie flat and point right, and the code draws the light streak
behind it. Generate 1536 × 1024 (3:2), final fitted into 384 × 64.

> A single fantasy war arrow seen exactly from the side, lying perfectly horizontal and pointing to the right, filling
> the full width of the image. A dark polished wooden shaft with a faint grain and a thin gold-bronze band near each
> end. A broad, leaf-shaped steel broadhead with a bright sharp edge and a small gold collar where it meets the shaft.
> At the left end, three long ivory-white feather fletchings, with a pale gold nock. No motion blur, no speed lines,
> no glow, no trail: just the arrow, crisp and readable. Lots of empty space above and below it.

**The dryad's forms** — `assets/onboarding/portraits/CharacterDryadThorn.png`, `…Blossom.png`, `…Bark.png`: her
portrait while she has taken that form, in the style of the other character portraits. Final 640 × 640, opaque.

## Interface icons

**Generate 1024 × 1024, final 256 × 256 PNG.**

| File | Prompt (after the global style) |
|------|--------------------------------|
| `assets/icon_settings.png` | A gold cogwheel with a small sapphire in the middle. |
| `assets/icon_switch_camera.png` | A small brass-and-leather fantasy camera, like a magic lens box, with two curved golden arrows circling it. |
| `assets/onboarding/icons/dice.png` | A single ivory twenty-sided die with gold-inlaid pips, slightly tilted. Final 192 × 192. |
| `assets/onboarding/icons/pen.png` | A quill pen with a white feather and a gold nib, diagonal. Final 32 × 32, as a text field draws it at its pixel size. |

## Frames and ornaments

These are stretched or repeated by the code, so the shapes matter more than usual.

**`assets/onboarding/icons/card_scan.png`** — the frame that shows where to hold a card in front of the camera.
Generate 1024 × 1434 (5:7), final 400 × 560.

> An empty playing-card frame with rounded corners: an ornate gold filigree border with a small gem at each corner,
> and a completely empty transparent inside. Only the frame, nothing inside it.

**`assets/onboarding/icons/corner.png`** — the corner ornament of panels and messages. Generate 1024 × 1024, final
320 × 320.

> An ornamental gold filigree corner piece for the top left corner of a fantasy panel: two straight gold bars meeting in
> a rounded corner, with a curl and a small diamond-shaped gem at the corner. The bars run exactly along the top and
> left edges of the image; the rest is empty.

**`assets/fight/divider.png`** — the line between sections of a message. Generate 1536 × 120 (or wider), final
720 × 56.

> A thin horizontal gold divider line for a fantasy interface, tapering to points at both ends, with a small diamond
> gem in the centre and small curls beside it. Perfectly horizontal and symmetric.

## Buttons and controls

The buttons are nine-patch textures: the theme keeps the outer 20 px at the sides and 16 px at the top and bottom and
stretches the middle, so **the centre must be plain and even, and all the decoration must be in the border**. The
import script paints over the gem in the middle of the top and bottom edge, which would be stretched. Godot draws
the edges of a nine-patch, and the icons of toggles and sliders, at their pixel size, so these are imported at the
size they have on screen.

| File | Generate | Final | Prompt (after the global style) |
|------|----------|-------|--------------------------------|
| `button_primary.png` | 1536 × 928 | 132 × 58 | A rounded rectangular game button of polished gold with a bevelled raised edge and a darker bronze outline, plain smooth evenly lit face, no icon, viewed straight from the front. |
| `button_secondary.png` | 1536 × 928 | 132 × 58 | The same rounded rectangular game button in dark walnut wood with a thin gold rim, plain smooth face. |
| `button_danger.png` | 1536 × 928 | 132 × 58 | The same rounded rectangular game button in deep crimson enamel with a thin gold rim, plain smooth face. |
| `toggle_on.png` | 1536 × 850 | 76 × 37 | A pill-shaped fantasy toggle switch, gold frame, emerald-green glowing track, a round gold knob on the right side. |
| `toggle_off.png` | 1536 × 850 | 76 × 37 | The same pill-shaped toggle switch, gold frame, dark grey unlit track, a round dull bronze knob on the left side. |
| `slider_grabber.png` | 1024 × 1024 | 40 × 40 | A round gold slider knob with a small gem in the middle, seen from the front. |

All in `assets/onboarding/icons/`.

## Putting them in

- Put the generated PNGs in one folder, named as in the tables (`icon_shield.png` for the helmet,
  `character_dryad_<form>_form.png` for the dryad), and run `art/import_ui_art.sh <folder>`. It trims, scales and
  copies them; Godot imports them when the editor or a test starts.
- The scaled-down icons import with mipmaps on, and the project filters textures with mipmaps
  (`rendering/textures/canvas_textures/default_texture_filter`), as they are drawn much smaller than they are. A new
  icon needs `mipmaps/generate=true` in its `.import` file.
- Run `tests/run.sh` afterwards: the tests load these files.
