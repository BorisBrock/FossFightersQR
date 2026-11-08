# Messages

During the [boss fight](boss_fight.md), the game guides the players with messages: instructions (*all players now draw
their cards*), notifications (*the boss bites Sonja*) and reminders. A message shows large over the fight, with a
check mark below it. Tapping the check mark confirms that the players have read it and done what it says.

## How it looks

- An optional **title** in the title font, and a **body**, both centred on a dark panel. The fight is dimmed behind it.
- The round, the boss's health, *end the fight* and the settings stay in view and can still be used.
- The check mark closes a message. Taps for 0.4 s after a message appears do not count, so that a double tap
  does not close the next message unread.
- **A message that asks nothing of the players closes by itself** (`"auto": true`, see below), such as the boss's
  taunt or a card's effect that shows on screen anyway. A bar in the check mark runs down: 2 s plus 0.4 s per word, at
  least 4 s and at most 15 s, as messages are read out at the table. The check mark closes it at once. **Tapping the
  message stops the bar**, and the message waits for the check mark like any other. The bar also stops while a
  dialog is open, such as the settings, where the players can make messages stay longer (*Slowly*, 1.75 times as
  long) or never close by themselves.
- A message that asks the players to do something (draw, heal, lose health, take tokens, discard) always waits for the
  check mark, as confirming it says that they did it.
- Messages that arrive while one is shown wait in line and follow one after another.
- At the start of a fight, messages wait until the boss has been introduced.
- Changing the language in the settings changes the message on screen at once.

## Writing messages

Messages are in `messages/`, one file per language, named after it: `de.json`, `en.json`. **A new language only needs a
new file**, such as `fr.json`. A language without a file, and a message missing from a file, falls back to German, as
the rest of the app does.

Each message has an id, by which the game shows it, a `body`, if it needs one a `title`, and `"auto": true` if it
asks nothing of the players, so that it closes by itself:

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
	},
	"example_shield_lowered": {
		"body": "The shield of [boss]{boss}[/boss] goes down by [damage]{amount}[/damage].",
		"auto": true
	}
}
```

- **The body** is one text, or a list of texts, which become one line each.
- **Ids** are lowercase with `_`. For a message of only one boss, start it with the boss's id: `mirefang_dive`.
- **`auto`** is the same in every language. Mark a message only if the players have nothing to do on the table
  when they read it: what is told only once must not slip by while they are busy.
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
  | `:melee:`, `:ranged:`, `:magic:` | `assets/fight/icon_melee.svg` and so on |
  | `:shield:`, `:lightning:` | `assets/fight/icon_shield.svg`, `assets/fight/icon_lightning.svg` |
  | `:fire:`, `:panic:`, `:paralysis:` | `assets/fight/icon_fire.svg` and so on |
  | `:totem:` | `assets/fight/icon_totem.svg` |

Keep messages short. They have to be read out at a table, and a long one does not fit the screen.

`tests/test_messages.gd` checks the files: that every language has every message, with the same placeholders, that
every symbol and style exists and that every tag is closed. Run it after changing them.

The messages starting with `example_` show what the format can do, for the tests. The fight does not use them.

Besides the messages the players confirm, the files hold the short texts of the fight that need no confirming, in the
same format: what the fight asks for (`prompt_…`), notes that come and go (`notice_…`) and the labels of buttons
(`option_…`, plain text only). Messages starting with `part_` are lines of other messages, see below.

## Showing a message

From the rules in `Fight`, or from a boss's hooks, which get the fight:

```gdscript
fight.tell("mirefang_bite", { "boss": fight.boss.title, "player": hero.name })
```

Values are shown as they are, never read as formatting, so a hero called `[b]Bo` stays `[b]Bo`. A value can also be
`{ "de": …, "en": … }`, as the boss's title is, which is shown in the language on screen. A placeholder without a value
stays as it is, with a warning, to be noticed.

A value can also be a list of **parts**, each `[id, values]` of another message, whose bodies are filled in one per
line. That is how one message tells of several heroes, such as the boss's attack:

```gdscript
tell("boss_attacks", { "boss": boss.title, "hits": [
	["part_hit", { "player": "Rosie", "damage": 4 }],
	["part_hit_with_tokens", { "player": "Sonja", "damage": 3, "tokens": token_text({ "poison": 1 }) }],
] })
```

The fight screen shows what `Fight.tell()` sends, through `BossFight.show_message()`, which the screen can also call
itself. The fight waits until every message so far is confirmed before it goes on, see
[The boss fight](boss_fight.md#how-it-fits-together).

## How it fits together

- `Messages` (`scripts/messages.gd`) reads the files, once each, and turns a message into BBCode: styles and symbols
  first, then the placeholders, in one go. `SYMBOLS` and `STYLES` are there too: **a new symbol or style is one line
  there**, plus its row in the tables above.
- `MessageBox` (`scripts/message_box.gd`, `message_box.tscn`) is the panel in the fight. `tell()` queues a message,
  `confirmed(id)` says that the players confirmed one and `all_confirmed` that none is left. `hold()` keeps messages
  back for a while. A message that closes by itself is confirmed by the box, as if the check mark was tapped, so the
  fight cannot tell the difference. `Messages.is_auto(id)` says which do, `MessageBox.auto_seconds()` for how long,
  and `Settings.message_time` holds the players' choice.
- The box lies between the seats and the HUD in `boss_fight.tscn`, so that the HUD stays usable. Dialogs, such as
  giving up, are above it.
- Italics are Almendra, slanted by a `FontVariation`, as the font has no italic of its own.
- When `MessageBox.all_confirmed` fires, the screen calls `Fight.players_ready()`, and the fight goes on.
