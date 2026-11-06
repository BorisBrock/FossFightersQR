# Choosing the boss

Two screens between the [onboarding](onboarding.md) and the fight: the boss list (`boss_selection.tscn`,
`scripts/boss_selection.gd`) and the boss overview (`boss_overview.tscn`, `scripts/boss_overview.gd`).

## Flow

*To Battle!* at the table leads to the boss list.

- **Boss list:** one entry per boss, a picture across the whole width with the boss's name and a tagline. Tapping one
  opens its overview. *Back* returns to the table, without the logo this time. The last boss chosen has a brighter
  frame.
- **Boss overview:** the name and tagline, a large picture, the story and a list of strategy hints. Below them, always
  in view, the difficulty: *Easy*, *Normal* or *Hard*, with one line explaining the choice. *Back* returns to the list,
  *Fight!* starts the fight.

Escape and the back button of a phone do the same as *Back*. With the settings open, they only close the settings.

The chosen boss and difficulty are in the autoload `Encounter` (`scripts/encounter.gd`), which is where the fight will
read them. They last while the app runs, so coming back shows the last choice again. They are not saved between runs.

*Fight!* leads to the [boss fight](boss_fight.md).

## Bosses and difficulties

Every boss is one script in `scripts/bosses/`, named after its id, which extends `Boss` (`scripts/boss.gd`).
`Boss` holds what all bosses share; a boss's script fills in its data in `_init()` and overrides hooks only for what
makes it special. `scripts/bosses.gd` lists the ids in the order the boss list shows them, and the difficulties.

```gdscript
extends Boss

func _init() -> void:
	title = { "de": "Der alte Moorschlund", "en": "Old Mirefang" }
	# ... the rest of its data ...
	health = 48
	ambience = Ambience.FIREFLIES

## Only what is special about this boss needs code.
func damage_taken(fight: Fight, amount: int, kind: String) -> int:
	return amount * 2 if kind == "fire" else amount
```

What a boss has:

| Field | For |
|-------|-----|
| `title`, `tagline` | the list, the top of the overview, and the start of the fight |
| `story` | the overview, a few sentences |
| `hints` | the overview, as many as needed, each one short |
| `art` | the picture in the list and the overview |
| `figure`, `background` | the fight (see [Artwork](#artwork)) |
| `health` | its health on *Normal*. Each difficulty scales it by its `health_factor`. |
| `ambience`, `ambience_color` | the particles over the background: `EMBERS`, `FIREFLIES` or `DUST`, tinted |
| `mist_color` | the mist drifting over the ground of the background |
| `motion`, `motion_amount`, `motion_seconds` | how the boss moves while it waits: `BREATHE`, `HOVER` or `SWAY` |

The hooks are listed at the end of `scripts/boss.gd`, each with the default that a boss without special rules uses:
`fight_started`, `round_started` and `damage_taken` so far. Each gets the `Fight` (`scripts/fight.gd`), which holds the
round and the boss's health, so a hook can read and change them. **When the game rules are built, add a hook to
`Boss` for every moment a boss could want to step in**, call it from `Fight`, and keep the default plain, so that most
bosses need no code at all.

`Bosses.create(id)` makes a new boss each time, so each fight gets its own and a boss can keep track of things, such as
a heat counter, in its own variables.

**Adding a boss:** write `scripts/bosses/<id>.gd`, add the id to `Bosses.IDS`, and add its three pictures.

All text needs a German and an English version (see [Adding text](settings.md#adding-text)).
`tests/test_bosses.gd` checks this, and the pictures, for every boss and every difficulty.

**The three bosses there now (Old Mirefang, Ashwing, the Brass Colossus) are dummies** to build the screens with.
Replace them when the real bosses are designed. Their hints describe mechanics that do not exist yet, apart from the
colossus's armour, which halves ordinary attacks as an example of a hook.

## Artwork

The pictures are in `assets/bosses/`. The ones there now are placeholders, made by `art/make_boss_placeholders.sh`.
`art/import_boss_art.sh <folder>` takes the finished ones from a folder and scales them to size.

- **`Boss<Name>.png`, for the list and the overview:** landscape, 4:3, scaled to 1024 x 768. **Keep the boss's face in
  the middle.** The list crops each picture to a wide strip around its centre, and the overview to a slightly less
  wide one. The bottom third of the strip in the list lies under the boss's name.
- **`Figure<Name>.png`, the boss in the fight:** portrait, about 3:4, transparent around the boss, at most 768 x 1024.
  It is fitted into most of the screen without cropping. Its bottom edge is where the boss stands: breathing and
  swaying keep it in place.
- **`Background<Name>.png`, behind the boss:** portrait, 9:16, scaled to 900 x 1600. Taller and wider screens crop
  it, so keep nothing important near the edges. The bottom fifth lies under the round and the health.

## How it fits together

Both screens extend `MenuScreen` (`scripts/menu_screen.gd`), which fades in from black and out to the next screen,
handles Escape and the back button of a phone, and lets tests catch the change of scene through `change_scene`. While
one of them is shown, the back button of a phone does not quit the app.

Going back to the table sets `show_splash = false` on the onboarding scene before it starts, so the logo only shows
when the app starts.
