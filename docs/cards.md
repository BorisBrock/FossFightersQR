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

- **`symbols`:** what is printed on the card, each with a `type` (`attack`, `support`, `protection`, `heal`,
  `lightning`, `draw`, `poison`, `health_loss`, `direct_damage`, `take_from_pile`, `remove_from_game`, `special`) and a
  `strength`. Attacks and supports also
  have a `damage_type`: `melee`, `ranged` or `magic`. They take effect in their order on the card. `health_loss` is the
  red heart: the hero who plays the card loses that much health. `direct_damage` is the broken heart: that much damage
  goes straight to the boss's health, past its shields. `take_from_pile` (a deck with two arrows): the player takes that
  many cards of their choice from their draw pile, unlike `draw`, which takes the top ones. `remove_from_game` (a card
  ripped in half): the players are told to put the card away, and it cannot be played again in the fight, by anyone;
  give it strength `0`. `poison`: the boss gets that many poison tokens
  (`Fight.poison`), which stay for the fight and cost it 1 health each at the end of every round. `special` is the `*`: it only marks a
  card with a special effect, which its `ability` does; give it strength `0`. An attack whose strength the text
  decides, such as *Krawumm*'s, has strength `0`, and its ability sets it.
- **`ability`:** what the card does beyond its symbols, as the id of a script in `scripts/abilities/`, with
  `ability_values` for it. Left out for cards that only have symbols.
- **`uses_per_fight`:** how often each hero can use the card in a fight, such as a potion. Left out for no limit.
- **`tags`:** what kind of card it is, for rules that care, such as `totem` or `form` (the Soul Shaman's first totem
  each round gets a Lightning). Left out for none. Cards tagged `form`, the dryad's forms, lie by her character card
  like items: they never go to the play area and can be played again in the same round (`Card.stays_on_table()`).
- **`deck`:** cards of a race's or class's deck can only be played by the hero of that race or class. Cards of
  `items` can be used again in the same round.

A card without symbols or ability, such as *Pass*, uses up an action and does nothing else.

### How a card's effect is split

- **Symbols are data** and do the simple things: attack, support, protection, heal, draw, lightning and so on.
- **Everything else is code**, in an ability. One script serves every card with the same mechanic, its numbers coming
  from `ability_values` (`if_healthy` with `{ "draw": 2 }` or `{ "heal": 3 }`). An effect that only one card has gets
  a script of its own (`knightly_aid`). There is no rules language in the JSON: the card texts vary too much for one.

**Checks**, so that no card does less than it says without anyone noticing: `tools/validate_catalog.py` refuses an
attack or support of strength `0`, or a character or class card with an effect, that has no ability, and an ability
without its script. A card with the `special` symbol but no ability is not refused: the editor, and `tools/server.py`
when saving, give it the placeholder `todo` (`scripts/abilities/todo.gd`), which does nothing and warns when the card
is played, so that it can be recorded now and its ability written later. Search the catalog for `"todo"` to find
them. `tests/test_fight.gd` checks that every ability in the catalog loads.

### Abilities

Each is a script in `scripts/abilities/`, named after its id, extending `CardAbility` (`scripts/card_ability.gd`),
which is a `FightRule`. So an ability can do something when its card is played (`before_effects`, which can change the
card's effects, and `after_effects`, which sees what they did), refuse the card (`can_play`), and stay in the fight to
step in later (`Fight.add_rule()`), such as for the rest of the round. The values come from the card, so one script
serves many cards.

| Ability | Does | Values | Cards |
|---------|------|--------|-------|
| `free_play` | Another hero may play cards right now, without using a turn. | `cards` (1) | |
| `extra_turns` | The hero gets more turns, such as the Warhorse's 4th action. | `turns` (1), `now` (false: next round) | |
| `lucky_charm` | The hero plays the top card of their draw pile, its lightning ignored. | | Glücksbringer |
| `remove_tokens` | Tells a hero to remove some of their tokens from the table, then with `every_hero` each hero that many more. | `count` (2), `choose` (false: the hero who plays it), `every_hero` (0) | Gardehelm, Borax’ Kriegshammer, Medizintasche, Elixier der Sorglosigkeit |
| `heal_hero` | A hero of the players' choice heals, such as with a Healing Potion. | `amount` (8) | Heiltrank |
| `empower` | A hero's cards get stronger until the end of the round, such as a Totem. | `bonus` (1), `type` (attack) | |
| `attack_by_round` | The attack is as strong as the round. | `type` (attack) | Krawumm, Runenstein |
| `attack_by_threat` | The attack is as strong as the boss's attack against the hero; from `threshold` damage on, the hero loses `health_loss`. | `threshold`, `health_loss` | Rune der Rache |
| `if_healthy` | Asks whether the hero has `health` or more; if so, they heal, draw or remove tokens. | `health` (15), `heal`, `draw`, `remove_tokens` | Schulterramme, Omas Helm, Knochenkeule |
| `for_chosen_hero` | The card's Heal and Draw are for a hero of the players' choice, who with `action` then acts at once. | `action` (false) | Krötensmoothie, Horn des Häuptlings, Anspornen, Energiesog, Himmelsrune |
| `every_hero` | The card's Heal and Draw are for every hero. | | Rune des Königs |
| `clear_attack_effects` | Attacks the card's Protection lowered lose their extra effects. | | Rauchbombe, Geweihte Schulterplatten |
| `knightly_aid` | The hero's attack is gone; an attack against another hero goes to them instead. | | Ritterlicher Beistand |
| `raven_curse` | The card lies by the hero; the players may discard it to prevent an @-ability against them. | | Fluch des Raben |
| `anti_boss` | Prevents the boss's next @-ability up to `strength`. | `strength` (5) | Anti-Boss-3000 |
| `build_robot` | The hero builds a battle robot, for `battle_robot`. | | (the goblin's robot cards) |
| `ignore_shield_effects` | The card's attacks do not set off what the boss's shields do besides absorbing. | | Arkanfalter |
| `search_pile` | The hero plays a card from their draw pile, which is then out of the game, and shuffles it. | | Magmahorn |
| `toxin` | From now on, each of the boss's poison tokens costs it `damage` health more at the end of the round. | `damage` (1) | Toxikum |
| `bonus_per_symbol` | The card's effects of `symbol` are stronger for each card with that symbol the hero played this round. | `symbol` (support), `bonus` (2) | Geisterwolf, Zeitschnitter |
| `next_card` | The next card played, by anyone, gets a Lightning, takes effect twice or gets `bonus` more on those effects, if it has an effect of `symbol` (for attacks and supports, of `damage_type`). | `symbol` (attack), `damage_type` (ranged), `then` (`lightning`, `repeat` or `boost`), `bonus` (2) | Lichtpfeile, Stachelbola, Schwelende Keule, Drachenschuppe, Astrale Linse, Kettenblitz |
| `delayed_attack` | The card's attacks only take effect at the start of the hero's first turn next round. | | Bombling |
| `threat_hurts_boss` | The boss loses what is left of its attack against the heroes the card protected. | | Schleimiger Helm |
| `halve_attack` | The attack against a hero of the players' choice is halved, rounded down, and loses its extra effect. | | Kultistenkette |
| `remove_curse` | Tells the players to discard an active curse of a hero. | | Fluchbrecher |
| `use_item` | The hero uses an item at once. | | Lianenschlange |
| `card_to_pile` | Tells the hero to put `count` other hand cards on their draw pile first. | `count` (1) | Pestbote |
| `play_top_cards` | A hero of the players' choice plays the top `cards` cards of their draw pile. | `cards` (3) | Wunderlampe, Improvisieren |
| `only_for` | Only a hero of `race` or `hero_class` can use the card, for items (other cards go by their deck). | `race`, `hero_class` | Opas Glasauge |
| `not_here` | The card is not used in the app and is refused with a note, such as the items for one boss of the board game. | | Fackel, Machete |
| `repeat_last_attack` | The last card with an attack played in the fight, by anyone, takes effect once more. | | Amulett der Zeit |
| `play_discard_or_top` | The hero plays a card from their discard pile or the top card of their draw pile, which is then out of the game. | | Deja-Vu |
| `random_strength` | The strength of each of the card's effects of `type` is rolled from `min` to `max`. Give them strength `0`. | `type` (attack), `min` (1), `max` (3) | Meteoritenschauer |
| `lower_shield` | A shield of the players' choice goes down by `amount`, without its effect; nothing beyond the shield reaches the boss. | `amount` (7) | Explosivkristall |
| `shield_break_damage` | If the card's attack breaks a shield, the boss loses `damage` health at once. | `damage` (3) | Kristallorb |
| `poison_on_attack` | For the rest of the fight, the boss gets `poison` poison each time its attack strikes a hero of the players' choice with `threshold` or more. With `remove_card`, the card is then out of the game. | `threshold` (4), `poison` (1), `remove_card` (false) | Krone des Prinzen |
| `dryad_form` | The dryad takes a form, which she keeps until she takes another (`FightHero.form`), and her seat shows it. `thorn`: her attacks and supports +1. `blossom`: she heals 3 each time her attack or support costs the boss health. `bark`: her Protection +1. Refused while she already has that form. | `form` (`thorn`, `blossom`, `bark`) | Stachelform, Blütenform, Borkenform |
| `weaken_next_round` | Next round, every attack of the boss is `amount` lower. With `chosen_hero`, the card's Heal and Draw are for a hero of the players' choice. | `amount` (3), `chosen_hero` (false) | Magische Eruption |

A card that takes effect once more (`Fight.play_again()`) or later is a replay (`CardPlay.replay`): the rules and its
ability see it again, but it does not count as played a second time. Lightning on a card played again gives actions
only to the hero who made it happen. `Fight.history` has every card played in the fight, for abilities that look back.

For example, the Healing Potion:

```json
{ "qr": "…", "deck": "items", "ability": "heal_hero", "ability_values": { "amount": 8 }, "uses_per_fight": 1 }
```

The app does not know the heroes' health, their hands or their tokens: they are on the table. An ability that depends
on them asks the players (`Fight.confirm()`, `Fight.choose_hero()`), and one that changes them tells the players.

A card naming an ability that does not exist yet still plays its symbols, with a warning. **Adding one:** write
`scripts/abilities/<id>.gd` and add it to the table above. If it needs a moment of the fight that has no hook yet, add
the hook to `FightRule` (see [The boss fight](boss_fight.md#how-it-fits-together)). Text for the players goes into
`messages/`, see [Messages](messages.md).

### Hero levels

Character and class cards of a higher level (5, 8) have an `ability` too: what the level gives the hero. The hero
keeps the card they showed during the [onboarding](onboarding.md), and when a fight starts, the ability joins it as a
rule for that hero (`CardAbility.owner`, `is_mine(play)`) and stays to the end. It steps in through the hooks of
`FightRule`, such as `card_playing` or `shield_broken`.

| Ability | Does | Values | Cards |
|---------|------|--------|-------|
| `first_gets_lightning` | Each round, the hero's first card with `symbol` or `tag` gets a Lightning. | `symbol`, `tag` | Hochdruide (protection), Seelenschamane (totem), Dryaden-Urgewalt (form) |
| `heal_on_first_attack` | The hero heals when they play the first attack of a type in a round. | `amount` (3) | Himmelspaladin |
| `draw_when_hurt` | The hero may draw when they lose health. | `count` (1) | Erzmagier |
| `support_bonus_after_attack` | The hero's supports hit harder after their own attack of that type this round. | `bonus` (2) | Elfen-Bewahrerin |
| `shield_breaker` | Breaking a shield costs the boss health at once. | `damage` (4) | Halbling-Glücksmeisterin |
| `battle_robot` | While the hero's robot works (asked each round), their attacks are stronger. | `bonus` (2) | Goblin-Genie |
| `play_top_on_first_hit` | The first hit with an attack in the hero's turn plays the top card of their deck, or an item. | | Troll-Häuptling |
| `act_on_full_block` | A Protection lowering an attack to 0 lets the hero play an attack card or an item at once. | | Zwergen-Schatzhüter |
| `free_supports` | The hero's supports need no attack before them. | | Schurkenkönig |
| `ignore_first_shield_effect` | The hero's first attack each round ignores what the shields do besides absorbing. | | Elitekrieger |

## Character and class cards

A `race` field makes a card a character card, a `hero_class` field makes it a class card. The
[onboarding](onboarding.md) only reacts to these. In the catalog editor, choose it under *Character or class card*.
