# The boss fight

The game itself: `boss_fight.tscn`, `scripts/boss_fight.gd`. It starts from *Fight!* on the boss overview, with the boss
and difficulty from `Encounter`.

*Status: only the screen exists. The rules of a turn are not built yet, and the scene has no camera yet, so the round
stays at 1 and the boss's health does not change.*

## What is on screen

Like the table in the [onboarding](onboarding.md), the screen is a map of the table. From back to front:

- **Background:** the boss's own picture, darker at the edges, with mist drifting over the ground and particles in the
  boss's colours (`assets/fight/background.gdshader`).
- **The boss:** large, in the middle. It moves gently while it waits: it breathes, hovers or sways, as its script says
  (`assets/fight/figure.gdshader`). The shader also has `flash` for lighting the boss up on a hit.
- **The heroes** at their seats, as on the table (`seats.tscn`, shared with the onboarding). Seats without a hero are
  hidden.
- **The banner** across the middle, between the seats, for short messages. `show_banner(text)` shows one for 3 s. At the
  start it announces the boss.
- **Messages** over the middle, large, each until the players confirm it with the check mark. They announce rounds and
  phases and say what happens. See [Messages](messages.md).
- **Top left:** give up. It asks first, then ends the fight and leads to the boss list.
- **Top right:** the settings.
- **Bottom left:** the round, from 1. **Bottom right:** the boss's health.

Escape and the back button of a phone ask to give up, too. With the question or the settings open, they only close it.

## How it fits together

- `Fight` (`scripts/fight.gd`) is the state of the fight: the boss, the difficulty, the round and the boss's health. The
  screen only shows it and follows its signals, so the rules can be built and tested in `Fight` without a screen.
- `Fight.tell(id, values)` shows a message to the players, from the rules or a boss's hooks. The text is in
  `messages/`, see [Messages](messages.md).
- What each boss does differently comes from its script in `scripts/bosses/`, through the hooks of `Boss`. See
  [Bosses and difficulties](bosses.md#bosses-and-difficulties).
- The screen extends `MenuScreen` for the fades and the back button. Its `go_back()` asks to give up instead of leaving.
- The question is a `ConfirmDialog` (`confirm_dialog.tscn`), which any screen can use. Dialogs join
  `MenuScreen.DIALOG_GROUP` while open, so that the back button is left to them.
- Icons for the fight are in `assets/fight/`.

## Battery

The background shader, the boss's movement and about 20 to 40 particles run all the time. The particles are cheap, and
the GPU is not where the power goes (see [Battery](qr_scanning.md#battery)), but measure again when the fight has its
camera.
