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

*Status: the boss fight is not built yet, so* Fight! *leads to the old scanner test screen (`main.tscn`).*

## Bosses and difficulties

Both are defined in `scripts/bosses.gd`, in the order the list shows them. Each boss has an id, and:

- `title` and `tagline` for the list and the top of the overview,
- `story`, a few sentences,
- `hints`, as many as needed, each one short,
- `art`, the path of its picture.

All text needs a German and an English version (see [Adding text](settings.md#adding-text)).
`tests/test_bosses.gd` checks this for every boss and every difficulty.

**The three bosses there now (Old Mirefang, Ashwing, the Brass Colossus) are dummies** to build the screens with.
Replace them when the real bosses are designed. Their hints describe mechanics that do not exist yet.

## Artwork

The pictures are in `assets/bosses/`, named `Boss<Name>.png`. The ones there now are placeholders, made by
`art/make_boss_placeholders.sh`.

- **Format:** landscape, 4:3. `art/import_boss_art.sh <folder>` takes every `Boss*.png` from a folder and scales it to
  1024 x 768.
- **Keep the boss's face in the middle.** The list crops each picture to a wide strip around its centre, and the
  overview to a slightly less wide one. The bottom third of the strip in the list lies under the boss's name.
- A new boss needs its picture added to `scripts/bosses.gd` as `art`.

## How it fits together

Both screens extend `MenuScreen` (`scripts/menu_screen.gd`), which fades in from black and out to the next screen,
handles Escape and the back button of a phone, and lets tests catch the change of scene through `change_scene`. While
one of them is shown, the back button of a phone does not quit the app.

Going back to the table sets `show_splash = false` on the onboarding scene before it starts, so the logo only shows
when the app starts.
