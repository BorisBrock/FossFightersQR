# Artwork prompts

Prompts for replacing the remaining placeholder graphics with AI-generated artwork.

**Already final, not listed here:** the character portraits (`assets/onboarding/portraits/`), the class crests
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

- **Exceptions to the transparent background:** the three `Boss<Name>.png` pictures and the three
  `Background<Name>.png` pictures are full scenes and must be opaque. Their prompts say so; drop the transparency
  sentence of the global style for them.
- If a generator cannot make real transparency, ask for "on a flat solid pure #00FF00 background" instead and remove it
  afterwards (for example `magick in.png -fuzz 12% -transparent '#00ff00' out.png`). Avoid green in those subjects'
  edges, or use magenta (#FF00FF) for green subjects such as the poison icon and Old Mirefang.
- **Resolutions:** *Generate* is what to ask the generator for (or the nearest size it offers in that aspect ratio).
  *Final* is the size of the file in the project; scale down with Lanczos. Small icons are generated large and scaled
  down, so their shapes must stay readable at 32 px: one clear silhouette, few details, strong contrast.

## Bosses

Folder: `assets/bosses/`. Import with `art/import_boss_art.sh <folder>`, which crops and scales them to the final size.
Details in [bosses.md](bosses.md#artwork).

### Old Mirefang — Lord of the Sunken Marsh

A toad the size of a house that slept for a hundred years in the mud under the village of Crookbrook. Moves by slowly
breathing. Ambience: green fireflies.

**`BossMirefang.png`** — boss list and overview. Generate 1536 × 1152 (4:3), final 1024 × 768. **Opaque.**

> A gigantic ancient swamp toad rising from black marsh water at dusk, mossy warty olive-green skin crusted with mud,
> reeds and a sunken wooden bridge on its back, huge glowing yellow eyes, wide grinning maw with a long tongue curled
> at the lips, drool, lily pads and fireflies around it. Face exactly in the centre of the picture, framed head and
> shoulders. Atmospheric marsh background in misty green and teal, full scene, opaque background.

**`FigureMirefang.png`** — the boss in the fight. Generate 1024 × 1365 (3:4), final at most 768 × 1024. **Transparent.**

> Full body of a gigantic ancient swamp toad, front view, squatting heavily, mossy warty olive-green skin crusted with
> mud, reeds and a broken plank of a bridge stuck to its back, huge glowing yellow eyes, wide grinning maw, slime
> dripping, a few fireflies near its head. The toad fills most of the frame, its feet touching the bottom edge of the
> image. Transparent background.

**`BackgroundMirefang.png`** — behind the boss. Generate 1080 × 1920 (9:16), final 900 × 1600. **Opaque.**

> Empty fantasy swamp at dusk seen from the shore, misty sunken marsh with crooked dead trees, sunken huts and a
> half-drowned wooden bridge, still black water reflecting a green-violet sky, glowing fireflies, fog lying on the
> water. No creature, no characters. The centre is open and calm for a monster to stand in, the lower fifth is dark
> muddy ground, nothing important near the edges. Full scene, opaque background.

### Ashwing — The Ember Wyrm of Blackridge

The guardian of the Fire Mountains, burning every village since a thief stole its egg. Hovers in the air. Ambience:
embers.

**`BossAshwing.png`** — boss list and overview. Generate 1536 × 1152 (4:3), final 1024 × 768. **Opaque.**

> A furious ember wyrm, a lean dragon with soot-black scales cracked by glowing orange magma veins, wings spread with
> burning torn membranes, smoke and sparks streaming from its nostrils, molten eyes, roaring. Head exactly in the
> centre of the picture. Behind it a smoking volcanic ridge and a village burning far below, sky of ash and orange
> glow. Full scene, opaque background.

**`FigureAshwing.png`** — the boss in the fight. Generate 1024 × 1365 (3:4), final at most 768 × 1024.
**Transparent.**

> Full body of a furious ember wyrm hovering in the air, front view, wings spread wide and up, soot-black scales cracked
> by glowing orange magma veins, burning torn wing membranes, tail curling below, embers and thin smoke rising from it,
> molten eyes, jaws open. The dragon fills most of the frame and its tail tip reaches near the bottom edge.
> Transparent background.

**`BackgroundAshwing.png`** — behind the boss. Generate 1080 × 1920 (9:16), final 900 × 1600. **Opaque.**

> Empty volcanic mountain ridge at night, black basalt cliffs with rivers of glowing lava, a smoking crater, an
> empty scorched nest of a dragon on a ledge, sky full of ash clouds lit orange from below, drifting embers. No
> creature, no characters. The centre is open sky for a flying monster, the lower fifth is dark cracked rock, nothing
> important near the edges. Full scene, opaque background.

### The Brass Colossus — Engine of the Mad Tinker

A machine built by Master Gearwright to protect the city, which decided the city is safest with nobody in it. Heats up
every turn. Moves by swaying. Ambience: golden dust.

**`BossColossus.png`** — boss list and overview. Generate 1536 × 1152 (4:3), final 1024 × 768. **Opaque.**

> A towering clockwork colossus of riveted brass and copper, steampunk-fantasy golem with a furnace glowing red-orange
> in its chest, exposed gears and pistons at the joints, steam venting from its shoulders, a single glowing lens eye in
> a helmet-like head. Head exactly in the centre of the picture, framed head and chest. Behind it the rooftops of an
> empty medieval city in golden dusty light. Full scene, opaque background.

**`FigureColossus.png`** — the boss in the fight. Generate 1024 × 1365 (3:4), final at most 768 × 1024.
**Transparent.**

> Full body of a towering clockwork colossus, front view, standing firmly with heavy feet apart, riveted brass and
> copper plates, furnace glowing red-orange in its chest, exposed gears and pistons at the joints, steam venting from
> its shoulders, single glowing lens eye, huge hammer-like fists. The colossus fills most of the frame, its feet on the
> bottom edge of the image. Transparent background.

**`BackgroundColossus.png`** — behind the boss. Generate 1080 × 1920 (9:16), final 900 × 1600. **Opaque.**

> Empty town square of a deserted medieval fantasy city, cobblestones cracked by giant footprints, abandoned market
> stalls, a clock tower and a tinker's workshop with scattered cogs, golden dusty late-afternoon light, dust motes in
> the air. No creature, no characters. The centre is open for a giant to stand in, the lower fifth is cobblestones,
> nothing important near the edges. Full scene, opaque background.

## Fight icons

Folder: `assets/fight/`. They are shown small: in the text of messages, on buff chips, on the fight screen and on the
game-over screen. **Generate 1024 × 1024, final 256 × 256 PNG**, unless noted. Each keeps the colour of today's
placeholder, so that players recognise it.

| File | Means | Prompt (after the global style) |
|------|-------|--------------------------------|
| `icon_melee.png` | melee attack | A square game icon tile with rounded corners and a thin silver rim, crimson-red enamel field, a steel broadsword pointing diagonally up. |
| `icon_ranged.png` | ranged attack | A square game icon tile with rounded corners and a thin silver rim, amber-orange enamel field, a wooden bow with a nocked arrow pointing diagonally up. |
| `icon_magic.png` | magic attack | A round glowing magic orb of deep blue and cyan light with a white sparkle in the centre, swirling arcane energy, thin silver rim. |
| `icon_damage.png` | the heroes' damage | A gold-hilted sword striking down with a bright white impact burst at the tip. |
| `icon_claw.png` | the boss's attack | Three huge bone-white monster claws slashing diagonally, with dark red streaks. |
| `icon_health.png` | health | A glossy deep-pink ruby heart with a pale pink rim and a white highlight. |
| `icon_heal.png` | healing | A glowing mint-green healing cross with soft white light and small leaves. |
| `icon_wound.png` | damage taken | A torn dark crimson heart split by a jagged crack, a drop of blood falling. |
| `icon_shield.png` | protection | A kite shield of blue enamel with a pale steel rim and a small gold boss. |
| `icon_lightning.png` | Lightning | A bright yellow-white lightning bolt with a soft golden glow. |
| `icon_fire.png` | fire status | A lively flame, orange at the base, yellow and white at the tip. |
| `icon_poison.png` | poison status | A bubbling glass vial of toxic green liquid with a dark green cork, a drip running down. |
| `icon_panic.png` | panic status | A pink-magenta swirl of dizziness with small stars, like a spinning daze. |
| `icon_paralysis.png` | paralysis status | A crystal of pale blue ice with frozen shards and frost around it. |
| `icon_totem.png` | Totem | A small carved wooden shaman totem pole with a turquoise glowing spirit face. |
| `icon_robot.png` | the goblin's battle robot | The head of a small goblin-made battle robot, riveted silver plates, yellow glowing eyes, a crooked antenna. |
| `icon_support.png` | support | Two hands clasped together in a golden glow, warm amber colours. |
| `icon_card.png` | a card | A single fantasy playing card seen from the back, cream parchment with a gold ornamental border, slightly tilted. |
| `icon_round.png` | the round | An hourglass with a gold frame and glowing blue sand. |
| `icon_crown.png` | title on the game-over screen | A gold crown with blue sapphires and a soft shine. |
| `icon_check.png` | confirm button | A bold golden check mark with a dark bronze outline. |
| `icon_give_up.png` | give up button | A tattered white flag on a short wooden pole. Pure white and light grey only. |
| `icon_form_thorn.png` | dryad's thorn form | A curling thorny vine with sharp red-orange thorns. |
| `icon_form_blossom.png` | dryad's blossom form | An open pink blossom with a golden yellow centre. |
| `icon_form_bark.png` | dryad's bark form | A round piece of tough brown tree bark with a small fresh green sprout. |

**`icon_boss_shield.png`** — the boss's shields on the fight screen, which the code makes glow and break. Generate
1024 × 1110, final 192 × 208.

> A heavy dark iron heater shield seen from the front, blackened riveted metal, a thin bronze rim, battle scratches,
> plain flat centre without emblem.

## Interface icons

**Generate 1024 × 1024, final 256 × 256 PNG.**

| File | Prompt (after the global style) |
|------|--------------------------------|
| `assets/icon_settings.png` | A gold cogwheel with a small sapphire in the middle. |
| `assets/icon_switch_camera.png` | A small brass-and-leather fantasy camera, like a magic lens box, with two curved golden arrows circling it. |
| `assets/onboarding/icons/dice.png` | A single ivory twenty-sided die with gold-inlaid pips, slightly tilted. Final 192 × 192. |
| `assets/onboarding/icons/pen.png` | A quill pen with a white feather and a gold nib, diagonal. Final 64 × 64. |

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

The buttons are nine-patch textures: the code keeps the outer 16 px (18 px at the bottom) and stretches the middle, so
**the centre must be plain and even, and all the decoration must be in the border**. Generate wide and scale to the
final size; they are drawn at half size, so the margins in the theme have to be doubled to 32/36 px when the PNG
replaces the SVG.

| File | Generate | Final | Prompt (after the global style) |
|------|----------|-------|--------------------------------|
| `button_primary.png` | 1536 × 928 | 192 × 116 | A rounded rectangular game button of polished gold with a bevelled raised edge and a darker bronze outline, plain smooth evenly lit face, no icon, viewed straight from the front. |
| `button_secondary.png` | 1536 × 928 | 192 × 116 | The same rounded rectangular game button in dark walnut wood with a thin gold rim, plain smooth face. |
| `button_danger.png` | 1536 × 928 | 192 × 116 | The same rounded rectangular game button in deep crimson enamel with a thin gold rim, plain smooth face. |
| `toggle_on.png` | 1536 × 850 | 152 × 84 | A pill-shaped fantasy toggle switch, gold frame, emerald-green glowing track, a round gold knob on the right side. |
| `toggle_off.png` | 1536 × 850 | 152 × 84 | The same pill-shaped toggle switch, gold frame, dark grey unlit track, a round dull bronze knob on the left side. |
| `slider_grabber.png` | 1024 × 1024 | 80 × 80 | A round gold slider knob with a small gem in the middle, seen from the front. |

All in `assets/onboarding/icons/`.

## Putting them in

- Every icon above is an SVG today. A PNG has to be referenced by its new name: in `scripts/messages.gd`,
  `scripts/fight_buff.gd`, `scripts/boss_fight.gd`, `scripts/game_over.gd`, `scripts/seat_token.gd`, `scripts/boss.gd`
  and the `.tscn` files that load them (search for `.svg`). Then delete the SVG.
- Check that the PNGs import with mipmaps on, as they are scaled down a lot on small screens.
- Run `godot --headless -s tests/test_messages.gd`, `godot --headless -s tests/test_fight.gd` and
  `godot --headless res://tests/test_bosses.tscn` afterwards: they
  load these files.
