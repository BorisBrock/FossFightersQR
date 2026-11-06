# Messages

During the [boss fight](boss_fight.md), the game guides the players with messages: instructions (*all players now draw
their cards*), notifications (*the boss bites Sonja*) and reminders. A message shows large over the fight, with a
check mark below it. Tapping the check mark confirms that the players have read it and done what it says.

## How it looks

- An optional **title** in the title font, and a **body**, both centred on a dark panel. The fight is dimmed behind it.
- The round, the boss's health, *give up* and the settings stay in view and can still be used.
- Only the check mark closes a message. Taps for 0.4 s after a message appears do not count, so that a double tap
  does not close the next message unread.
- Messages that arrive while one is shown wait in line and follow one after another.
- At the start of a fight, messages wait until the boss has been introduced.
- Changing the language in the settings changes the message on screen at once.

## Writing messages

Messages are in `messages/`, one file per language, named after it: `de.json`, `en.json`. **A new language only needs a
new file**, such as `fr.json`. A language without a file, and a message missing from a file, falls back to German, as
the rest of the app does.

Each message has an id, by which the game shows it, a `body` and, if it needs one, a `title`:

```json
{
	"example_venomous_bite": {
		"title": "Venomous Bite",
		"body": [
			"[boss]{boss}[/boss] bites [player]{player}[/player], dealing [damage]{damage} damage[/damage] :damage:.",
			"[player]{player}[/player] also takes [poison]{poison} poison markers[/poison] :poison:."
		]
	},
	"example_reminder": {
		"body": "[i]Remember:[/i] poisoned heroes lose [damage]1[/damage] :health: at the end of each round."
	}
}
```

- **The body** is one text, or a list of texts, which become one line each.
- **Ids** are lowercase with `_`. For a message of only one boss, start it with the boss's id: `mirefang_dive`.
- **Placeholders** such as `{player}` are filled in by the game. Each language has to use the same ones, in any order.
  The id and the placeholders are what the code relies on, so change them only together with the code.
- **Formatting** is BBCode, as Godot's `RichTextLabel` reads it: `[b]bold[/b]`, `[i]italic[/i]`, `[u]underlined[/u]`,
  `[color=#ff8040]coloured[/color]` or `[color=red]…[/color]`, `[font_size=48]larger[/font_size]`.
- **Styles** keep what comes up again and again looking the same everywhere. Prefer them to colours of your own:

  | Style | For |
  |-------|-----|
  | `[player]…[/player]` | heroes and players |
  | `[boss]…[/boss]` | the boss |
  | `[damage]…[/damage]` | damage and losses |
  | `[heal]…[/heal]` | healing and gains |
  | `[poison]…[/poison]` | poison |

- **Symbols** are written `:name:` and drawn inline, as tall as the text:

  | Symbol | Icon |
  |--------|------|
  | `:health:` | `assets/fight/icon_health.svg` |
  | `:round:` | `assets/fight/icon_round.svg` |
  | `:damage:` | `assets/fight/icon_damage.svg` |
  | `:poison:` | `assets/fight/icon_poison.svg` |
  | `:card:` | `assets/fight/icon_card.svg` |
  | `:dice:` | `assets/onboarding/icons/dice.svg` |

Keep messages short. They have to be read out at a table, and a long one does not fit the screen.

`tests/test_messages.gd` checks the files: that every language has every message, with the same placeholders, that
every symbol and style exists and that every tag is closed. Run it after changing them.

The messages starting with `example_` show what the format can do. They are not used yet: replace them when the rules
are built.

## Showing a message

From the rules in `Fight`, or from a boss's hooks, which get the fight:

```gdscript
fight.tell("example_venomous_bite", { "boss": fight.boss.title, "player": hero.name, "damage": 5, "poison": 2 })
```

Values are shown as they are, never read as formatting, so a hero called `[b]Bo` stays `[b]Bo`. A value can also be
`{ "de": …, "en": … }`, as the boss's title is, which is shown in the language on screen. A placeholder without a value
stays as it is, with a warning, to be noticed.

The fight screen shows what `Fight.tell()` sends, through `BossFight.show_message()`, which the screen can also call
itself. So far, the fight announces each round (`round_started`).

## How it fits together

- `Messages` (`scripts/messages.gd`) reads the files, once each, and turns a message into BBCode: styles and symbols
  first, then the placeholders, in one go. `SYMBOLS` and `STYLES` are there too: **a new symbol or style is one line
  there**, plus its row in the tables above.
- `MessageBox` (`scripts/message_box.gd`, `message_box.tscn`) is the panel in the fight. `tell()` queues a message,
  `confirmed(id)` says that the players confirmed one and `all_confirmed` that none is left. `hold()` keeps messages
  back for a while.
- The box lies between the seats and the HUD in `boss_fight.tscn`, so that the HUD stays usable. Dialogs, such as
  giving up, are above it.
- Italics are Almendra, slanted by a `FontVariation`, as the font has no italic of its own.
- The rules of a turn will need to wait for the players at times. `MessageBox.confirmed` and `all_confirmed` are
  there for that.
