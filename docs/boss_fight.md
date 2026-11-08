# The boss fight

The game itself: `boss_fight.tscn`, `scripts/boss_fight.gd`. It starts from *Fight!* on the boss overview, with the boss
and difficulty from `Encounter`.

*Status: the rules of the base game are built (see [How a fight goes](#how-a-fight-goes)), with the abilities of the
cards in the catalog and of the heroes' levels (see [Cards](cards.md#abilities)). The boss's @-abilities can be
prevented by cards, but none of the dummy bosses has one yet.*

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
  phases and say what happens. Those that ask nothing of the players close by themselves after a few seconds, unless
  a player taps them. See [Messages](messages.md).
- **Badges at the seats,** facing each hero: the boss's attack against them this round, with an icon for what it does
  besides (such as poison). They appear in the planning phase. The heroes' own status tokens are not shown: they are
  real tokens on the table.
- **Buffs:** what lasts a while, as small chips with icons and a value such as `+1`
  ([Buffs on screen](cards.md#buffs-on-screen)). Those for one hero, such as a Totem, are in their badge, which then
  shows outside the planning phase too; a hero with a totem token also has a turquoise glow around their portrait.
  Those for everyone, such as *Muttis Nachtisch* with the cards it still boosts, are at the top, between the buttons.
- **The boss's poison** at the bottom right, next to its health, once it has any (`Fight.poison_changed`).
- **The shields** at the bottom, below the boss: melee, ranged and magic, from the shield phase on. A broken shield is dimmed.
- **The prompt** above the table head, while the fight waits for the players: whose turn it is, or which hero to tap,
  with buttons for what cannot be done by tapping a hero or showing a card (*Pass*, *Skip*, choices). Below the
  prompt's text, short notes come and go, such as *This card is already in play this round*.
- **Hits:** the boss lights up and the damage rises from it.
- **Top left:** end the fight. It asks first: *We have lost* (a hero has fallen) ends the fight as lost, *Stop the
  fight* ends it without a result, *Keep fighting* closes the question.
- **Top right:** the settings.
- **Bottom left:** the round, from 1. **Bottom right:** the boss's health, which counts up as the boss appears.

Escape and the back button of a phone ask to end the fight, too. With the question or the settings open, they only close it.

## How a fight goes

The rules follow [the rule summary](game-rule-summary.md). The heroes' health and cards stay on the table: the app keeps
the boss's health and shields and the boss's attacks. The heroes' status tokens are real tokens, which the players put
on and take off themselves.

1. **Start:** the heroes appear at their seats, the boss appears, its health counts up, and it greets the heroes
   (`Boss.taunt`).
2. **Each round:** *Round n*, in one message with the planning, which closes by itself.
3. **Planning:** the boss plans an attack against each hero (`Boss.plan_attacks`), shown at their seat. Knowing
   them, the players tap the hero who starts. With one hero, nobody is asked.
4. **Shields:** the boss raises its shields (`Boss.raise_shields`). There is no message: a short *Shields* banner
   shows, the shields appear one after the other and count up to their values (`Fight.shields_raised`), and the
   next message waits until they are done.
5. **Actions:** curses are revealed, then the heroes take turns clockwise from the starter, three each. Each turn is one
   action: show a card, or *Pass*. Lightning gives another action within the same turn.
   Each hero's badge shows the actions they have left this round as spheres: **blue** for their three turns,
   **yellow** for extra ones (Lightning, a free card from another hero, a Warhorse's turn) and **red** for extra
   ones that allow only some cards (the Lucky Charm's top card). The one being played comes first and glows; extra
   turns are taken last.
6. **Attack:** the boss strikes each hero with what is left of its attack (`Boss.attack_hero`). One message lists
   every hit, a line per hero, with the tokens the hero takes for poison and the like. What rules do on a hit
   (`hero_struck`, `hero_hurt`) follows it.
7. **End of the round:** status, discard and draw (phases 5 to 7 of the rules) are one message, a line each, as the
   players do them together at the table: what poison and fire do, discarding, and drawing, with paralysis. What
   rules remind them of, such as a card not to discard (`round_end_started`), comes first.
8. **Then** the boss's poison hurts it, past its shields: 1 health per token, which rules can change
   (`FightRule.poison_damage`, such as the Toxikum). Its tokens stay for the whole fight.

Every phase but the shields is announced, and the fight goes on once the players have confirmed it, or it has closed
by itself. When the
boss's health reaches 0, the fight is won at once. The heroes' health is not in the app, so when a hero falls, the players say *We
have lost*. A rule can also end a fight as lost (`Fight.lose()`). After the message of victory or defeat, or right
away when the players stop the fight, the [game over screen](game_over.md) shows how it went.

**Cards:**

- A card counts when it is newly shown. One that stays in view, or comes back within 2 s, does not count again.
- A card already in play this round, one from another hero's race or class deck, and one used up for the fight
  (`uses_per_fight`) are refused with a note. Items (`deck: items`) and the dryad's forms (tag `form`) can be used again in the same round.
- Character and class cards are ignored, and so is every card while the fight is not asking for one.
- What the symbols do: **Attack** breaks the boss's shield of its damage type first, then hurts. **Support** does the
  same, but only after an attack of its type this round. **Protection** lowers the attack against a hero the players
  tap, and at exactly 0 its effects are gone too. **Direct damage** (the broken heart) hurts the boss past its shields. **Lightning** gives another action. **Heal**, **Draw**, **Take from draw pile** (the deck
  with two arrows) and **Health loss** (the red heart) tell the players what to do. **Remove from game** (the ripped
  card) tells them to put the card away, and refuses it for the rest of the fight. **Special** (the `*`) only marks a card with a special effect, which its ability does.
- The actions message reminds heroes with panic to play at random.

## How it fits together

- `Fight` (`scripts/fight.gd`) is the fight: its state and its rules. It runs by itself as a coroutine from `start()`
  and waits for the players when it needs them: until they have read its messages (`players_ready()`), and for answers
  to its `request`: a hero (`choose()`), a card (`scan()`, `pass_action()`) or one of some options
  (`choose_option()`). The screen only shows what goes on and passes on what the players do, so the rules are tested
  without a screen (`tests/test_fight.gd`).
- `FightHero` (`scripts/fight_hero.gd`) is a hero during a fight: the attack against them, their turns and the
  cards in their play area. `FightHero.actions()` lists the actions they have left, as `FightHero.Action` (`TURN`,
  `BONUS`, `LIMITED`): those reserved for right now (`pending`, filled by `play_actions()`, `take_action()` and
  Lightning through `Fight.give_actions()`), then their turns, the `extra_turns` last. `ActionSpheres`
  (`scripts/action_spheres.gd`) draws them on the badge. An ability that limits which cards may be played passes
  `"limited": true` to `play_actions()` or `take_action()`; one that gives turns this round raises `extra_turns`
  along with `turns_left`. `CardPlay` (`scripts/card_play.gd`) is a card being played, with what it will do.
- **Everything special is a `FightRule`** (`scripts/fight_rule.gd`): the boss, a card's ability, later the abilities
  heroes gain with their levels. The fight calls every rule's hooks at each moment of a round, such as `turn_started`,
  `card_playing` (to change or cancel a card) or `damage_taken`. A hook can wait for the players, for example
  `await fight.choose_hero(...)`, and the fight waits with it. A rule can join the fight for a while
  (`Fight.add_rule()`, for the round or for good). **When something new needs to step in at a moment that has no hook
  yet, add the hook to `FightRule`** with a default that does nothing, and call it from `Fight`.
- For rules, `Fight` offers what they need: `tell()`, `choose_hero()`, `choose_from()`, `confirm()` (yes or no, for
  what only the table knows, such as a hero's health), `play_actions()` and `take_action()` (a hero plays cards right
  now, without using a turn; `"only"` limits which), `deal_damage()`, `hurt_hero()`, `threaten()`, `protect()`,
  `redirect_attack()`, `strike()`, `set_shields()`, `boss_ability()`.
- The hooks of `FightRule`: the fight's moments (`round_started`, `attacks_planned`, `action_phase_started`, …), turns
  and cards (`turn_started`, `card_playing`, `card_played`, `attack_type_opened`, `hero_protected`), the boss and the
  heroes (`shield_broken`, `hero_struck`, `hero_hurt`, `boss_ability_used`) and values rules can change (`damage_taken`, `protection`,
  `support_without_attack`, `ignores_shield_effect`).
- `CardPlay` says what a card does and did: its `effects`, who its Heal and Draw are for (`targets`), and afterwards
  its `damage`, `shield_damage` and the heroes it `protected`.
- Card abilities are described in [Cards](cards.md#abilities).
- `Fight.tell(id, values)` shows a message to the players, from the rules or a boss's hooks. The text is in
  `messages/`, see [Messages](messages.md).
- What each boss does differently comes from its script in `scripts/bosses/`, through the hooks of `Boss`. See
  [Bosses and difficulties](bosses.md#bosses-and-difficulties).
- The screen extends `MenuScreen` for the fades and the back button. Its `go_back()` asks to end the fight instead of leaving.
- `Fight.stats` (`FightStats`, `scripts/fight_stats.gd`) records what happens for the game over screen: the outcome,
  each hero's damage, protection, healing and damage taken, the power of their symbols by damage type, and the boss's
  health and the damage round by round. `Fight` fills it in where things happen; a rule that does something worth
  counting, such as `heal_hero`, tells it too.
- The question is a `ConfirmDialog` (`confirm_dialog.tscn`), which any screen can use, with an optional third button
  (`extra_text`, `extra_confirmed`). Dialogs join
  `MenuScreen.DIALOG_GROUP` while open, so that the back button is left to them.
- Icons for the fight are in `assets/fight/`.

## Battery

The background shader, the boss's movement and about 20 to 40 particles run all the time. The particles are cheap, and
the GPU is not where the power goes (see [Battery](qr_scanning.md#battery)), but measure again when the fight has its
camera.
