# Cards

The cards live in `cards/cards.json`. `cards/cards.schema.json` describes the format, and editors with JSON
support check the file against it through the `$schema` field.

The game reads the file at startup (`CardDatabase`) and turns each entry into a typed `Card`.

The Android export includes the file through `include_filter` in `export_presets.cfg` and leaves out the schema
through `exclude_filter`.

## Checks

The catalog editor's server refuses to save a catalog with problems. To check the file after editing it by hand:

    .venv/bin/python tools/validate_catalog.py

This covers the schema, unique QR codes and repeated JSON keys, which the schema cannot express. The game itself
only checks what it needs to run: fields that are required and have the right type, and unique QR codes.

## On screen

When a code is read, `scripts/main.gd` looks up its exact value in the `qr` fields:

- **Match:** the title, then QR code, deck and level, then the symbols, then the effect.
- **No match:** "Unknown card" and the value of the code.

Text uses the language from the settings, by default the device language, falling back to `de`, the language of the
printed cards.

If the file has a problem, the status line at the top says why. If the file cannot be read at all, every card
shows as unknown. A card that is invalid or repeats a QR code is skipped and shows as unknown, the others still
work.

To fill the file from physical cards, see [tools/README.md](../tools/README.md).

`title`, `effect`, `level` and `symbols` are left out for cards that do not have them.

## Playing cards

What the fight reads from a card (see [The boss fight](boss_fight.md#how-a-fight-goes) for what each does):

- **`symbols`:** each with a `type` (`attack`, `support`, `protection`, `heal`, `lightning`, `draw`) and a `strength`.
  Attacks and supports also have a `damage_type`: `melee`, `ranged` or `magic`. They take effect in their order on the
  card.
- **`ability`:** what the card does beyond its symbols, as the id of a script in `scripts/abilities/`, with
  `ability_values` for it. Left out for cards that only have symbols.
- **`uses_per_fight`:** how often each hero can use the card in a fight, such as a potion. Left out for no limit.
- **`deck`:** cards of a race's or class's deck can only be played by the hero of that race or class. Cards of
  `items` can be used again in the same round.

A card without symbols or ability, such as *Pass*, uses up an action and does nothing else.

### Abilities

Each is a script in `scripts/abilities/`, named after its id, extending `CardAbility` (`scripts/card_ability.gd`),
which is a `FightRule`. So an ability can do something when its card is played (`before_effects`, `after_effects`),
refuse the card (`can_play`), and stay in the fight to step in later (`Fight.add_rule()`), such as for the rest of the
round. The values come from the card, so one script serves many cards.

| Ability | Does | Values |
|---------|------|--------|
| `free_play` | Another hero may play cards right now, without using a turn. | `cards` (1) |
| `extra_turns` | The hero gets more turns, such as the Warhorse's 4th action. | `turns` (1), `now` (false: next round) |
| `lucky_charm` | The hero plays the top card of their draw pile, its lightning ignored. | |
| `remove_tokens` | The hero removes some of their tokens, choosing which. | `count` (2) |
| `heal_hero` | A hero of the players' choice heals, such as with a Healing Potion. | `amount` (8) |
| `empower` | A hero's cards get stronger until the end of the round, such as a Totem. | `bonus` (1), `type` (attack) |

For example, the Healing Potion:

```json
{ "qr": "…", "deck": "items", "ability": "heal_hero", "ability_values": { "amount": 8 }, "uses_per_fight": 1 }
```

A card naming an ability that does not exist yet still plays its symbols, with a warning. **Adding one:** write
`scripts/abilities/<id>.gd` and add it to the table above. If it needs a moment of the fight that has no hook yet, add
the hook to `FightRule` (see [The boss fight](boss_fight.md#how-it-fits-together)). Text for the players goes into
`messages/`, see [Messages](messages.md).

## Character and class cards

A `race` field makes a card a character card, a `hero_class` field makes it a class card. The
[onboarding](onboarding.md) only reacts to these. In the catalog editor, choose it under *Character or class card*.
