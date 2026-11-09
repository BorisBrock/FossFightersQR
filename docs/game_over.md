# Game over

The end of every fight: `game_over.tscn`, `scripts/game_over.gd`. It follows the [boss fight](boss_fight.md) when the
boss is defeated, when the players say *We have lost*, and when they stop the fight. *Back to the table* leads to the
[onboarding](onboarding.md), where the party can be changed before the next fight.

## What is on screen

From top to bottom, on the boss's own background:

- **The outcome:** *Victory!*, *Defeat* or *Retreat*, with the boss and the difficulty below. Behind it the boss: it
  sinks away when beaten and rises when it has won. Golden rays and falling sparks for a victory, red rays and rising
  embers for a defeat, drifting dust for a retreat. A victory plays the fanfare.
- **The team's numbers:** rounds played, damage dealt to the boss, damage the heroes took from the boss's attacks,
  and the boss's attacks blocked out of all its attacks.
- **The course of the fight:** the boss's health as a line, from the start and after each round, and the damage of
  each round as bars below it, on the same scale. The best round is named above.
- **A row per hero:** portrait and class crest, their damage, protection, healing and damage taken, and three bars for
  the power of their attack and support symbols by damage type (melee, ranged, magic). The bars of all heroes share a
  scale, so they can be compared. A hero who did the most of something, and more than everyone else, earns a title,
  such as *Boss Breaker* for damage or *Shield Wall* for protection, at most one each (`AWARDS`).
- **Back to the table.** Taps in the first 1.2 s do nothing, so that the tap that closed the fight's last message does
  not skip the screen.

Everything arrives one after the other: the outcome lands, the numbers count up, the chart draws itself, the heroes'
rows slide in and their bars grow.

The screen fits up to four heroes on a 720 × 1280 screen. The chart takes whatever height is left, so with fewer heroes
or a taller screen it simply grows.

## How it fits together

- The fight screen hands over its `Fight`, whose `stats` (`FightStats`, `scripts/fight_stats.gd`) has everything the
  screen shows. See [The boss fight](boss_fight.md#how-it-fits-together) for how it is filled in.
- Run on its own, as from the editor, the screen makes up a fight with the saved party, so it can be looked at without
  playing one.
- The chart, the power bars and the legend are drawn by small classes inside `game_over.gd`. The colours of the damage
  types were checked for colour blindness and contrast against the panels.
- The icons for healing, damage taken and titles are `icon_heal.png`, `icon_wound.png` and `icon_crown.png` in
  `assets/fight/`.
- Tests: `tests/test_fight.gd` for the statistics, `tests/test_boss_fight.tscn` for ending a fight and the screen.
