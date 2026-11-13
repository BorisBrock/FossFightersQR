# Balancing

`tools/balance/simulate.gd` plays many fights against a boss with random parties and an AI for the players, and sums up
how they went. Its numbers show where to tune, such as the boss's health or its attacks. What the boss
should feel like is still for real players to decide.

    godot --headless -s tools/balance/simulate.gd -- --games 200
    godot --headless -s tools/balance/simulate.gd -- --players 2 --difficulty normal --set health=70 --log

It takes about 20 s for 100 fights at each player count (1 to 4) and difficulty, 1200 fights in all. `--help`
lists the options.

## How it works

- **The rules are the game's own.** The simulator runs the real `Fight`, the boss's script and the card abilities,
  headless. So a change to Mirefang or to a card shows up in the simulation, and there are no rules to keep in step.
- **It plays the table**, the part the app leaves to the players: each hero's draw pile, hand, discard pile and play
  area, their health and status tokens. It acts on the fight's messages as players would: drawing, healing, taking
  poison, applying poison at the end of the round, discarding down to the hand limit and drawing up to it. A hero at
  0 health loses the fight, as the rules say.
- **Parties are random:** 1 to 4 heroes, each race and class at most once. Each hero's deck is their race deck and
  class deck, plus one random loot card of each level from 1 to `--loot` (10), none twice in the party. The dryad's
  forms lie on the table, as do the base game's items (Heiltrank, Medizintasche, Trinkschlauch, …), unless
  `--no-items`. Players always have them, and they change the outcome a lot. `--level 5` or `8` gives the heroes the abilities of their
  higher character and class cards.
- **The AI plays the race** (`--ai planner`, the default). The heroes lose as soon as one of them is at 0, so
  health is worth a lot only where it keeps a hero alive until the boss is dead. Damage to the boss is worth the same
  all the time. Before each choice the AI estimates:
  - how many rounds the boss still needs, from the party's damage per round so far;
  - what this round costs each hero: the attack on them (lowered by Protection, its poison gone at 0), their poison
    tokens, fire, and the tail lash if it comes this round;
  - what each later round costs them, from the health they lost per round so far, plus their poison.

  From these it judges each hero's health against the rest of the fight. A hero who would fall this round makes saving
  them worth far more than any damage. A hero with health to spare gets little from more. Each card is worth its
  damage plus what that change does to the heroes. If the party can likely finish the boss this round, the AI goes all
  in on damage and ignores defence.

  The details:
  - **Lightning first.** A card with Lightning gives its action back, so it scores what it does plus the best card
    that action can play.
  - **Shields.** Damage into a shield counts only for what the party's other attacks and supports of that type can
    then get through this round: shields come back every round. It counts the poison of the poison shield and of the
    spit against it.
  - **Drawing** is worth a lot only for actions the hero has left and no good card for, and a little otherwise.
  - **Items.** It uses them for any gain at all, as they cost no card. It keeps a fight's last use of an item (the
    Heiltrank) for when it matters.
  - **Choices.** It aims Protection, heals and token removal at the hero they help most by the same judgement as the
    card's score. It gives a chosen hero's draw and extra action to the hero who has actions and no good cards for
    them.
  - **Unchanged from the older AI:** passing (below 0.5 it keeps its cards), what it keeps at the discard, who starts
    the round, Panic, and the abilities without a value of their own (a flat bonus for the special symbol). The
    Glücksbringer is still never used.

  `--ai greedy` is the older AI. It scores each card on its own, with fixed values for heal, draw, Lightning and
  poison. It aims Protection at the biggest attack and heals at the most hurt hero.

The AI still plays worse than good players: it does not plan a round ahead, and it does not choose its loot. Read
the results as a **comparison** between settings, not as the true chance to win. A change that moves the win rate
from 30 % to 60 % for the AI will make the fight easier for players too. Compare settings with the same AI.

### The planner against the older AI

Mirefang with its health as tuned for the older AI (25, 42, 60 and 88), with items, 400 fights per line, the same
seeds (November 2026):

| Heroes | Easy greedy → planner | Normal greedy → planner | Hard greedy → planner |
|--------|-----------------------|-------------------------|-----------------------|
| 1 | 83 → 95 % | 36 → 58 % | 3 → 14 % |
| 2 | 91 → 99 % | 39 → 77 % | 2 → 14 % |
| 3 | 95 → 100 % | 48 → 91 % | 5 → 33 % |
| 4 | 91 → 100 % | 40 → 96 % | 3 → 36 % |

The better the play, the more the party size matters. Aimed Protection, heals and token removal help a party more
than a hero alone, so the planner wins *Normal* 58 % alone but 96 % with 4. A hero alone still dies mostly of poison
and the tail lash, worn down. So Mirefang's health by the number of heroes was tuned again with the planner, see
[below](#the-number-of-heroes).

## Before trusting the numbers

A hero's start health and hand limit are the sums of the values printed on their level 1 character and class cards,
which are not in the catalog: `HeroOptions` (`scripts/hero_options.gd`) has them, as the fight's first message
lists each hero's hand limit too. `--health` and `--hand` set them for every hero instead.

At the end, the simulator lists the messages its table did not act on. If one shows up there, a card effect is
missing from the simulation: add it to `_on_message`, or to `READ_ONLY` if there is nothing for the table to do.

## The output

One line for each player count and difficulty:

| Column | Meaning |
|--------|---------|
| `win%` | fights won |
| `rnd(won)`, `rnd(lost)` | mean rounds of the fights won and lost |
| `boss%left` | mean health the boss had left when the heroes lost: how close they came |
| `margin` | mean health of the weakest hero at the end of a won fight, as a share of their start health: how close the boss came |
| `dives`, `enraged` | mean dives per fight, and the share of fights in which it was enraged |
| `spits`, `psh.hits` | venom spits and hits on the poison shield per fight |
| `maxpsn` | mean of the most poison tokens any hero had at once |
| `tblpsn` | mean of the most poison tokens on the table at once, all heroes together |
| `>box` | fights in which `tblpsn` was more than the game box has: 16 tokens, or `--tokens` |
| `hero dmg/round` | health each hero lost per round: from the boss's attacks, its bite, their poison tokens at the end of the round, and other things such as cards |
| `deaths` | the fights lost, by what took the hero to 0 |

Then how many rounds the fights lasted, won, lost or timed out: for each line, and for each number of heroes over all
difficulties (`all`). It lists the mean, the median, the range of the middle 80 % of fights (`10-90 %`), the shortest
and longest, and the share of fights over by round 3, 4, 5, 6, 7, 8 and 10. A fight that timed out counts with
`--max-rounds` + 1.

Below that, the win rate of the fights each race and class took part in, which shows a hero who is far stronger or
weaker than the rest. `--csv file.csv` writes one line per fight for a closer look in a spreadsheet, and `--log` prints
the first fight message by message.

## Tuning a boss

`--set key=value` changes a variable of the boss before each fight, the value as JSON. All of Boss's variables can be
set (`health`, `health_by_heroes`, `attack_min`, `attack_max`, `attack_by_heroes`, `shields`, `shield_by_heroes`), and
those of the boss's own script. Mirefang's tuning values are variables for this: `shield_value`, `shield_low`, `shield_high`, `poison_min`,
`poison_max`, `poison_by_heroes`, `dive_below`, `bite`, `bite_by_heroes`, `enraged_below`, `enraged_bonus`,
`spit_damage`, `spit_poison`, `tail` and `tail_every`. A boss with `health_by_heroes` ignores `health`.

    --set 'health_by_heroes=[40,60,80,100]' --set 'shield_by_heroes=[-2,-1,0,1]'
    --set shield_value=2
    --set 'dive_below=[0.66,0.33]'
    --set 'bite={"easy":{"damage":10,"poison":2},"normal":{"damage":12,"poison":2},"hard":{"damage":15,"poison":3}}'

The difficulties (`Bosses.DIFFICULTIES`) are changed in `scripts/bosses.gd`. Once the numbers look right, write them
into the boss's script.

The same `--seed` and options give the same fights, so two settings can be compared on the same parties and decks.
200 fights per line give a win rate to about ±7 percentage points; use more for small differences.

## The number of heroes

More heroes have more actions, more protection, healing and cards to remove poison, and a boss's bite or other
attack against one hero falls on each of them less often. So a boss's numbers change with the number of heroes
(`health_by_heroes`, `attack_by_heroes`, `shield_by_heroes`, see [Choosing the boss](bosses.md#bosses-and-difficulties)),
so that 1 to 4 heroes have about the same chance.

**Mirefang** (November 2026, hero level 1, 10 loot cards, at first without items, the older AI: `--ai greedy`), 3 heroes left as they were. Without the scaling,
with its 80 health for any number, the AI won on *Normal* 0 % alone, 9 % with 2, 53 % with 3 and 84 % with 4. A hero
alone mostly died of poison: their shields took most of their damage, the fight lasted long, and every bite was theirs.
Shields, poison and the bite matter as much as health: with 4 heroes, the fight is over in about 4 rounds and the dives
come at fixed parts of its health, so its health alone hardly changes the outcome. The values found
([Mirefang](bosses.md#mirefang)), 400 fights each:

| Heroes | Easy | Normal | Hard |
|--------|------|--------|------|
| 1 | 97 % | 60 % | 15 % |
| 2 | 94 % | 55 % | 16 % |
| 3 | 93 % | 56 % | 20 % |
| 4 | 87 % | 56 % | 24 % |

With another seed, *Normal* came out at 63, 54, 58 and 62 %.

**Then, with items** (Heiltrank, Medizintasche, Trinkschlauch, …, which players always have), the same values were
far too easy: the AI won *Normal* 56 % alone and 70 to 76 % with 2 to 4 heroes, and a player alone found the fight
easy, its attacks mostly blocked. So Mirefang got its **tail lash** (5 damage to every hero every second round on
*Normal*), its **venom spit** went from 7 damage to 5 and now hits only the hero who struck, and the attacks of a hero
alone went up by 1 (3 to 7). With items, 400 fights each:

| Heroes | Easy | Normal | Hard |
|--------|------|--------|------|
| 1 | 83 % | 36 % | 3 % |
| 2 | 91 % | 39 % | 2 % |
| 3 | 95 % | 48 % | 5 % |
| 4 | 91 % | 40 % | 3 % |

The AI plays worse than good players, so *Normal* at about 40 % for the AI should be a fair fight for people. *Hard*
is very hard for the AI: the lash comes more often in its longer fights. Even a lash of 4 on *Hard* gave only about
7 %, and none at all about 23 %. The lash counts under `other` in `hero dmg/round` and `deaths`.

**Then, with the planner** (November 2026). Its health matters much more than with the older AI. That AI with 4
heroes was done in about 4 rounds whatever the health, while the planner gets through the dives and its health
decides how long they last. Health alone was enough to even out the number of heroes; attacks, shields, bite and
poison stayed as they were. Aimed at about 50 % on *Normal*, as the planner plays better than the older AI but still
worse than good players. Health 28, 52, 82 and 120 (it was 25, 42, 60 and 88), 400 fights each, two seeds:

| Heroes | Easy | Normal | Hard |
|--------|------|--------|------|
| 1 | 92 / 89 % | 53 / 46 % | 7 / 6 % |
| 2 | 98 / 99 % | 51 / 49 % | 4 / 3 % |
| 3 | 98 / 99 % | 50 / 50 % | 1 / 3 % |
| 4 | 99 / 100 % | 49 / 52 % | 1 / 1 % |

*Easy* was nearly always won with 2 to 4 heroes, and *Hard* almost never.

**Then the difficulties** (November 2026), aimed at 80 to 90 % on *Easy* and 10 to 20 % on *Hard*. Mirefang's bite
and lash alone could not do it: what made the fight harder for a party made it harder still for a hero alone, who
gets every bite. Its health moves a party's chance a lot and a lone hero's hardly at all, so the difficulties'
`health_factor` (`Bosses.DIFFICULTIES`, for every boss) went from 0.75 to 1.0 on *Easy* and from 1.25 to 1.05 on
*Hard*. Mirefang's tail lash on *Hard* went from 6 to 5. 400 fights each, two seeds:

| Heroes | Easy | Normal | Hard |
|--------|------|--------|------|
| 1 | 81 / 81 % | 50 / 51 % | 21 / 19 % |
| 2 | 87 / 88 % | 49 / 51 % | 17 / 19 % |
| 3 | 88 / 88 % | 49 / 50 % | 17 / 20 % |
| 4 | 89 / 90 % | 51 / 53 % | 19 / 18 % |

Rounds until the fight ends, over all three difficulties:

| Heroes | Mean | Median | Middle 80 % | Over by round 6 |
|--------|------|--------|-------------|-----------------|
| 1 | 9.3 | 8 | 5 to 14 | 24 % |
| 2 | 6.0 | 6 | 4 to 8 | 73 % |
| 3 | 5.5 | 5 | 4 to 7 | 86 % |
| 4 | 5.5 | 6 | 4 to 7 | 86 % |

A hero alone fights about two thirds longer than a party, and longer still on *Easy* (mean 10): they deal less damage per
round, and heal and protect themselves much of the time. On *Easy*, 1 or 2 fights alone in 400 last 40 rounds.
