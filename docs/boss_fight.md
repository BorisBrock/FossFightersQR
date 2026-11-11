# The boss fight

The game itself: `boss_fight.tscn`, `scripts/boss_fight.gd`. It starts from *Fight!* on the boss overview, with the boss
and difficulty from `Encounter`.

*Status: the rules of the base game are built (see [How a fight goes](#how-a-fight-goes)), with the abilities of the
cards in the catalog and of the heroes' levels (see [Cards](cards.md#abilities)). The boss's @-abilities can be
prevented by cards. The one boss so far is [Mirefang](bosses.md#mirefang).*

## What is on screen

Like the table in the [onboarding](onboarding.md), the screen is a map of the table. From back to front:

- **Background:** the boss's own picture, darker at the edges, with mist drifting over the ground and particles in the
  boss's colours (`assets/fight/background.gdshader`).
- **The boss:** large, in the middle. It moves gently while it waits: it breathes, hovers, sways or slithers, as its
  script says (`assets/fight/figure.gdshader`). Its eyes can glow (`Boss.eyes`). The shader also has `flash` for
  lighting the boss up on a hit, and `sink` for sinking it below the bottom edge of its picture, as into water. When
  the boss strikes, it rears back and lunges at the heroes. Out of reach (`Fight.boss_away`), it sinks with a splash,
  and its shields and attack types fade; coming back, it bursts up and lights up.
- **The heroes** at their seats, as on the table (`seats.tscn`, shared with the onboarding). Seats without a hero are
  hidden.
- **The banner** across the upper half, for short messages. `show_banner(text)` shows one for 3 s. At the
  start it announces the boss.
- **Messages** in the top half, large, each until the players confirm it with the check mark. They announce rounds and
  phases and say what happens. Those that ask nothing of the players close by themselves after a few seconds, unless
  a player taps them. See [Messages](messages.md).
- **Marks at the seats,** facing each hero: on the hero's left the boss's attack against them this round, on their
  right the tokens it gives besides (such as 1 poison), each with its count. They appear one hero after the other
  in the planning phase: the attack smashes in, shaking the screen, and counts up with a tack at each step. Above the portrait, a badge shows the actions the hero has left. The portraits are 1.6 times as
  large as at the table, without the class crest, and the marks have no frames. The heroes' own status
  tokens are not shown: they are real tokens on the table.
- **Choosing a hero:** the heroes the players can tap pulse, growing and shrinking a little, with a golden glow.
- **Buffs:** what lasts a while, as small chips with icons and a value such as `+1`
  ([Buffs on screen](cards.md#buffs-on-screen)). Those for one hero, such as a Totem, are in their badge, which then
  shows outside the planning phase too; a hero with a totem token also has a turquoise glow around their portrait.
  Those for everyone, such as *Muttis Nachtisch* with the cards it still boosts, are at the top, between the buttons.
- **The boss's poison** at the bottom right, above its health, once it has any (`Fight.poison_changed`).
- **The shields and attack types** above the hero at the bottom, from the shield phase on: a column each for melee,
  ranged and magic. On top the boss's shield (`Boss.shield_icon()`: `Boss.SHIELD_NORMAL` by default, so that a boss
  with special shields can show `SHIELD_DARK` or `SHIELD_POISON`; asked again each time the shields rise), its value below it; the two pulse, count and break
  together. Below that the attack type's icon: grey (same brightness, no colour) each round until a hero
  attacks with it (`Fight.attacked_changed`), then in colour, as supports of that type can now be played. Each column
  has a dark box behind it for readability, with the shield sitting on its top edge. A broken shield (or none raised)
  is gone, value and all, and its box collapses down onto the attack type's icon and fades; it grows back when the
  shield rises again.
- **The prompt** in the upper half, between the seats at the sides, in large type for small screens, while the fight waits for the players: whose turn it is, or which hero to tap,
  with buttons for what cannot be done by tapping a hero or showing a card (*Skip*, choices; a hero passes by showing a Pass card). Below the
  prompt's text, short notes come and go, such as *This card is already in play this round*.
- **The card's name** large over the boss, as a card is played (`Fight.card_started`). The fight waits a moment
  for it before the card takes effect.
- **Screen shake:** the whole screen shakes like in a small earthquake (`shake_screen()`) when a planned attack or a
  shield smashes in, when a shield breaks, and at the hits of a big attack (`BIG_ATTACK`, 5 or more) by a hero, or by
  the boss as it lunges.
- **Attacks:** a hero's attack plays a big effect over the boss, with a sound, before any number changes
  (`AttackEffects`, `scripts/attack_effects.gd`): for **magic**, four or five bolts fly in from the heroes around
  the table and splash on the boss in coloured rings, runes and sparks; for **melee**, a blade slashes across it,
  more often for stronger attacks, each slash crossing the last, leaving a glowing cut and sparks; for **ranged**, a
  volley of arrows from the bottom of the screen, each sticking in the boss with dust and splinters. Where they hit,
  from where, in which colours and how many vary each time. They are particles (`CPUParticles2D`) and sprites from
  `assets/fight/particles/` (the Kenney Particle Pack, CC0), and the boss lights up in their colour and shakes at
  each hit.
- **Hits,** step by step, each after the last (see [How a hit shows](#how-a-hit-shows)): the attack's effect, the
  shield counting down, the shield breaking, and the damage left rising from the boss as its health counts down.
- **Sounds:** what happens and what the players have to do, such as a hero's turn or choosing a hero, has a sound
  effect. See [Sounds](sounds.md).
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
2. **Each round:** *Round n* with a line from the boss (`Boss.round_text()`, another each round, in red), which
   closes by itself. The round counter shows the new round. *Round 1* also has everyone draw their starting hand:
   it lists each hero with their hand limit (`HeroOptions.hand_limit()`), reminds them that each paralysis token
   means one card less, and waits for the check mark.
3. **Planning:** *The boss is preparing its attacks*, in a message without a check mark. The boss plans an attack
   against each hero (`Boss.plan_attacks`). While the message shows, the attack smashes in at one seat after the
   other, shaking the screen, and counts up with a tack at each step; the tokens it gives besides pop up beside it.
   Then the message closes by itself.
4. **Shields:** the boss raises its shields (`Boss.raise_shields`). There is no message: a short *Shields* banner
   shows, the shields smash in one after the other, each shaking the screen, and count up to their values with a
   tack at each step (`Fight.shields_raised`), and the fight waits until they are done. Knowing the boss's attacks
   and shields, the players are told *It's your turn. Who starts this round?*, and the heroes' portraits pulse until
   they tap the one who starts. With one hero, nobody is asked.
5. **Actions:** from the second round on, curses are revealed first (*Curses*; in the first round nobody can have
   one). Then the heroes take turns clockwise from the starter, three each, each asked to play a card. Each turn is one
   action: show a card, or *Pass*. Lightning gives another action within the same turn.
   Each hero's badge shows the actions they have left this round as orbs: **blue** for their three turns,
   **yellow** for extra ones (Lightning, a free card from another hero, a Warhorse's turn) and **red** for extra
   ones that allow only some cards (the Lucky Charm's top card). The one being played comes first and glows; extra
   turns are taken last.
6. **Attack:** the boss strikes each hero with what is left of its attack (`Boss.attack_hero`). One message lists
   every hit, a line per hero, with the tokens the hero takes for poison and the like. What rules do on a hit
   (`hero_struck`, `hero_hurt`) follows it.
7. **End of the round:** status, discard and draw (phases 5 to 7 of the rules) are a short message each, as the
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
- A code that is no card in the catalog is refused with a note that shows its value, so that a card missing from the
  catalog can be found. Room cards (`deck: rooms`) are refused with *This card cannot be played now*.
- Character and class cards are ignored, and so is every card while the fight is not asking for one.
- What the symbols do: **Attack** breaks the boss's shield of its damage type first, then hurts. **Support** does the
  same, but only after an attack of its type this round. **Protection** lowers the attack against a hero the players
  tap, and at exactly 0 its effects are gone too. **Direct damage** (the broken heart) hurts the boss past its shields. **Lightning** gives another action. **Heal**, **Draw**, **Take from draw pile** (the deck
  with two arrows) and **Health loss** (the red heart) tell the players what to do. **Remove from game** (the ripped
  card) tells them to put the card away, and refuses it for the rest of the fight. **Special** (the `*`) only marks a card with a special effect, which its ability does.

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

## How a hit shows

A hit on the boss shows in steps, one after the other, slowly enough to follow (`_show_step()` in the screen):

1. **The attack:** its effect plays over the boss (`Fight.boss_attacked`, `AttackEffects.duration()`).
2. **The shield** of its type, if it takes any of it, grows and counts down a point at a time, with a clank and a
   spark each (`SHIELD_TICK_SEC`).
3. **The shield breaks,** if it is now at 0: it trembles and glows, bursts into shards of its picture with a ring
   of sparks, and then shows broken, grey and faint.
4. **The damage left** rises from the boss as a red number, and its health counts down.

Steps show the fight as it was when they were queued, so the screen keeps the boss's health and shields that it shows
(`_shown_health`, `_shown_shields`) apart from the fight's. Meanwhile the fight waits: `_run_steps()` holds it with
`Fight.hold_screen()` until the last step is done (`release_screen()`), as `Fight.until_read()` waits for the screen
as for messages. So the next hero is asked for a card only once the hit has shown. Messages wait too
(`MessageBox.hold()`), and the boss fades away when it is beaten only after the last hit.

Damage past the shields (the broken heart, the boss's poison) has no effect of its own: the number rises and the
health counts down. A shield lowered by an ability counts down and breaks the same way.

## Battery

The background shader, the boss's movement and about 20 to 40 particles run all the time. An attack's effect adds a
few hundred particles for a second or two. The particles are cheap, and
the GPU is not where the power goes (see [Battery](qr_scanning.md#battery)), but measure again when the fight has its
camera.
