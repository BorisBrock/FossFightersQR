# Sounds

All sound effects play on the **SFX** bus, so the volume in the [settings](settings.md) applies to them. The music has
a bus of its own.

The sounds are mono Ogg Vorbis (`.ogg`, quality 5), which Godot plays as is. To add a sound from elsewhere, convert
it like this:

    ffmpeg -i in.wav -ac 1 -c:a libvorbis -q:a 5 assets/sounds/<name>.ogg

## Loudness

The sounds come from different sources, so `tools/normalize_sounds.py` brings them to one loudness. Each sound
belongs to a tier, and every sound of a tier is equally loud: its loudest 400 ms (EBU R128 maximum momentary
loudness, as Godot plays it: mono on both speakers) are at the tier's target.

| Tier     | Target    | Sounds                                                                         |
|----------|-----------|--------------------------------------------------------------------------------|
| `event`  | -16 LUFS  | `boss_appears`, `boss_attack`, `victory`, `defeat`, `fanfare`, every `boss_*` sound |
| `effect` | -19 LUFS  | `hit`, `slash`, `slam`, `shield_break`, `shields_up`, `poison`, `protect`, `lightning`, `heal`, `hurt` |
| `volley` | -21 LUFS  | `magic_hit`, `arrow_hit`, `shield_block`, `tack`: they come in quick series and add up |
| `cue`    | -22 LUFS  | `turn`, `choose`, `seat`, `reveal`, `card_scanned`, `rejected`, `round`         |
| `ui`     | -26 LUFS  | `click`, `select`                                                               |

The tiers sit 15 to 20 LU above the music, which plays at about -34.5 LUFS with the default settings (the track
is mastered to -14.5 LUFS and starts 20 dB down, see [settings](settings.md)). So every player in the game plays
its sound at 0 dB: the mix is in the files. After adding or replacing a sound, add it to `TIERS` in the script if
it is new, and run

    python3 tools/normalize_sounds.py            # fixes the sounds that are off by more than 0.5 LU
    python3 tools/normalize_sounds.py --check    # only reports; exit code 1 if a sound is off

## The fight's sound effects

They are in `assets/sounds/`. The fight screen plays them through `Sfx` (`scripts/sfx.gd`), a node with a player per
sound. A sound added to the script also has to be added to `Sfx.NAMES`.

| Sound          | When                                                                                     |
|----------------|------------------------------------------------------------------------------------------|
| `turn`         | A hero has to play a card: their turn starts, or they get another action (Lightning, a free card). |
| `choose`       | The players have to choose: tap a hero (who starts, whom to protect or heal…) or a button. |
| `select`       | A hero who can be chosen, or a button of the prompt, is tapped.                          |
| `rejected`     | A card shown cannot be played now (any notice but Lightning's).                          |
| `lightning`    | Lightning gives another action.                                                          |
| `hit`          | Damage reaches the boss's health.                                                        |
| `shield_block` | A shield takes damage, or is lowered: once for each point it counts down.                |
| `shield_break` | A shield is brought to 0, as it bursts.                                                  |
| `magic_hit`    | A bolt of a magic attack splashes on the boss, at a slightly different pitch each time.  |
| `slash`        | A melee attack's blade slashes across the boss.                                          |
| `arrow_hit`    | An arrow of a ranged attack hits the boss, at a slightly different pitch each time.     |
| `shields_up`   | The boss raises its shields (not when it has none).                                      |
| `slam`         | A planned attack or a shield smashes onto the screen, as the screen shakes. Made with sox. |
| `tack`         | A number counts up a step: a planned attack or a rising shield, a little higher each step. Made with sox. |
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
| `victory`                              | `victory`      |
| `defeat`                               | `defeat`       |

## Boss sounds

A boss can have sounds of its own (`Boss.sounds`), which play instead of the usual ones. Each entry maps either the
name of a sound above (`Sfx` plays the boss's own instead) or a message id (the message box plays it instead of the
message's usual sound) to a file in `assets/sounds/`. Two names have no usual sound and only play if a boss has its
own: `boss_sinks` (it goes out of reach and sinks) and `boss_defeated` (it fades away, beaten).

Mirefang's sounds (`scripts/bosses/mirefang.gd`):

| Replaces                         | Sound                         | When                                               |
|----------------------------------|-------------------------------|----------------------------------------------------|
| `boss_appears`                   | `boss_mirefang_emerge`        | It rises at the start of the fight, and surfaces after a dive. |
| `boss_sinks`                     | `boss_mirefang_dive`          | It dives under the water.                          |
| `boss_defeated`                  | `boss_mirefang_death`         | It fades away, beaten.                             |
| message `boss_taunt`             | `boss_mirefang_hiss`          | Its taunt at the start ("Ssssso many little heroes …"). |
| message `boss_attacks`           | `boss_mirefang_attack`        | It attacks the heroes.                             |
| message `mirefang_surfaces`      | `boss_mirefang_lunge`         | It bursts out of the water at the marked hero.     |
| message `mirefang_spit`          | `boss_mirefang_spit`          | It spits venom on every hero.                      |
| message `mirefang_poison_shield` | `boss_mirefang_poison_shield` | A hero hits its poison shield.                     |
| message `mirefang_enraged`       | `boss_mirefang_enraged`       | It becomes enraged.                                |

## Other sounds

- `assets/sounds/click.ogg`: any button is pressed. The `ButtonSounds` autoload (`scripts/button_sounds.gd`)
  connects every button that enters the tree. A button whose press plays a sound of its own calls
  `ButtonSounds.silence(button)`: the fight's prompt buttons and seats (`select`) and the boss list's entries.
- `assets/sounds/card_scanned.ogg`: a card was read by the camera, everywhere cards are scanned.
- `assets/sounds/`: `reveal` (a message, and the onboarding's reveals), `seat` (a hero takes a seat, a boss
  is chosen, the volume preview), `fanfare` (the party is complete, the boss overview, a won fight's game over screen).
