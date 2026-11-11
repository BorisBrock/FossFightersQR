# Balancing

`tools/balance/simulate.gd` plays many fights against a boss with random parties and a very simple AI, and sums up
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
  forms lie on the table, as do the items with `--items`. `--level 5` or `8` gives the heroes the abilities of their
  higher character and class cards.
- **The AI is greedy.** On each action it scores every card it could play and plays the best one: damage that gets
  past the shields, less for damage to a shield, nothing for an attack while the boss is under water, a minus for
  hitting the poison shield, a bonus for opening a damage type a support in someone's hand needs. Protection is
  worth what it blocks, more for blocking the attack's poison too and when the attack would take the hero to 0. Heal,
  draw, Lightning and poison have small fixed values. With nothing worth at least 0.5, it passes and keeps its cards.
  Protection goes to the most dangerous attack, heals to the most hurt hero, and the hero with the strongest card
  starts the round.

The AI plays worse than good players: it does not plan a round ahead or save cards for the bite. Read the results as a
**comparison** between settings, not as the true chance to win. A change that moves the win rate from 30 % to 60 % for
the AI will make the fight easier for players too.

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

Below that, the win rate of the fights each race and class took part in, which shows a hero who is far stronger or
weaker than the rest. `--csv file.csv` writes one line per fight for a closer look in a spreadsheet, and `--log` prints
the first fight message by message.

## Tuning a boss

`--set key=value` changes a variable of the boss before each fight, the value as JSON. All of Boss's variables can be
set (`health`, `health_by_heroes`, `attack_min`, `attack_max`, `attack_by_heroes`, `shields`, `shield_by_heroes`), and
those of the boss's own script. Mirefang's tuning values are variables for this: `shield_value`, `shield_low`, `shield_high`, `poison_min`,
`poison_max`, `poison_by_heroes`, `dive_below`, `bite`, `bite_by_heroes`, `enraged_below`, `enraged_bonus`,
`spit_damage` and `spit_poison`. A boss with `health_by_heroes` ignores `health`.

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

**Mirefang** (November 2026, hero level 1, 10 loot cards, no items), 3 heroes left as they were. Without the scaling,
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
