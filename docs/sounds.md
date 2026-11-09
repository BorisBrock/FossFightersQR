# Sounds

All sound effects play on the **SFX** bus, so the volume in the [settings](settings.md) applies to them. The music has
a bus of its own.

The sounds are mono Ogg Vorbis (`.ogg`, quality 5), which Godot plays as is. To add a sound from elsewhere, convert
it like this:

    ffmpeg -i in.wav -ac 1 -c:a libvorbis -q:a 5 assets/sounds/<name>.ogg

## The fight's sound effects

They are in `assets/sounds/`. The fight screen plays them through `Sfx` (`scripts/sfx.gd`), a node with a player per
sound. A sound added to the script also has to be added to `Sfx.NAMES`.

| Sound          | When                                                                                     |
|----------------|------------------------------------------------------------------------------------------|
| `turn`         | A hero has to play a card: their turn starts, or they get another action (Lightning, a free card). |
| `choose`       | The players have to choose: tap a hero (who starts, whom to protect or heal…) or a button. |
| `select`       | A hero who can be chosen, or a button of the prompt, is tapped.                          |
|                | Also each attack the boss plans pops up at a hero's seat.                                |
| `rejected`     | A card shown cannot be played now (any notice but Lightning's).                          |
| `lightning`    | Lightning gives another action.                                                          |
| `hit`          | Damage reaches the boss's health.                                                        |
| `shield_block` | A shield takes damage, or is lowered: once for each point it counts down.                |
| `shield_break` | A shield is brought to 0, as it bursts.                                                  |
| `magic_hit`    | A bolt of a magic attack splashes on the boss, at a slightly different pitch each time.  |
| `slash`        | A melee attack's blade slashes across the boss.                                          |
| `arrow_hit`    | An arrow of a ranged attack hits the boss, at a slightly different pitch each time.     |
| `shields_up`   | The boss raises its shields (not when it has none).                                      |
| `poison`       | The boss gets poison tokens; its poison hurts it at the end of a round. A planned attack that poisons pops up its poison token. |
| `protect`      | An attack against a hero is lowered in the action phase, or every attack was blocked.    |
| `boss_appears` | The boss appears at the start of the fight, or comes back up after being out of reach.   |

Some [messages](messages.md) have a sound of their own instead of the message box's usual one (`MessageBox.SOUNDS`):

| Message                                | Sound          |
|----------------------------------------|----------------|
| `round_started`                        | `round`        |
| `boss_attacks`                         | `boss_attack`  |
| `phase_attack_blocked`                 | `protect`      |
| `health_loss`                          | `hurt`         |
| `heal`                                 | `heal`         |
| `boss_poison`, `poison_burst`          | `poison`       |
| `shield_broken_poison`                 | `shield_break` |
| `mirefang_poison_shield`, `mirefang_spit` | `poison`    |
| `mirefang_surfaces`                    | `boss_attack`  |
| `victory`                              | `victory`      |
| `defeat`                               | `defeat`       |

## Other sounds

- `assets/sounds/click.ogg`: any button is pressed. The `ButtonSounds` autoload (`scripts/button_sounds.gd`)
  connects every button that enters the tree. A button whose press plays a sound of its own calls
  `ButtonSounds.silence(button)`: the fight's prompt buttons and seats (`select`) and the boss list's entries.
- `assets/sounds/card_scanned.ogg`: a card was read by the camera, everywhere cards are scanned.
- `assets/sounds/`: `reveal` (a message, and the onboarding's reveals), `seat` (a hero takes a seat, a boss
  is chosen, the volume preview), `fanfare` (the party is complete, the boss overview, a won fight's game over screen).
