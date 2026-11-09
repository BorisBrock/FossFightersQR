# Choosing the boss

Two screens between the [onboarding](onboarding.md) and the fight: the boss list (`boss_selection.tscn`,
`scripts/boss_selection.gd`) and the boss overview (`boss_overview.tscn`, `scripts/boss_overview.gd`).

## Flow

*To Battle!* at the table leads to the boss list.

- **Boss list:** one entry per boss, a picture across the whole width with the boss's name and a tagline. Tapping one
  opens its overview. *Back* returns to the table, without the logo this time. The last boss chosen has a brighter
  frame.
- **Boss overview:** the name and tagline, a large picture, the story and a list of strategy hints. Below them, always
  in view, the difficulty: *Easy*, *Normal* or *Hard*, with one line explaining the choice. *Back* returns to the list,
  *Fight!* starts the fight.

Escape and the back button of a phone do the same as *Back*. With the settings open, they only close the settings.

The chosen boss and difficulty are in the autoload `Encounter` (`scripts/encounter.gd`), which is where the fight will
read them. They last while the app runs, so coming back shows the last choice again. They are not saved between runs.

*Fight!* leads to the [boss fight](boss_fight.md).

## Bosses and difficulties

Every boss is one script in `scripts/bosses/`, named after its id, which extends `Boss` (`scripts/boss.gd`).
`Boss` holds what all bosses share; a boss's script fills in its data in `_init()` and overrides hooks only for what
makes it special. `scripts/bosses.gd` lists the ids in the order the boss list shows them, and the difficulties.

```gdscript
extends Boss

func _init() -> void:
	title = { "de": "Der alte Moorschlund", "en": "Old Mirefang" }
	# ... the rest of its data ...
	health = 48
	ambience = Ambience.FIREFLIES

## Only what is special about this boss needs code.
func damage_taken(fight: Fight, amount: int, kind: String, play: CardPlay) -> int:
	return amount * 2 if kind == "magic" else amount
```

What a boss has:

| Field | For |
|-------|-----|
| `title`, `tagline` | the list, the top of the overview, and the start of the fight |
| `story` | the overview, a few sentences |
| `hints` | the overview, as many as needed, each one short |
| `art`, `art_focus` | the picture in the list and the overview, and where its face is in it (0 to 1 of its width and height), which the crops keep near their middle (`PictureCrop`) |
| `figure`, `background` | the fight (see [Artwork](#artwork)) |
| `health` | its health on *Normal*. Each difficulty scales it by its `health_factor`. |
| `health_by_heroes` | its health on *Normal* with 1, 2, 3 and 4 heroes, instead of `health`. Empty for the same with any number. |
| `ambience`, `ambience_color` | the particles over the background: `EMBERS`, `FIREFLIES` or `DUST`, tinted |
| `mist_color` | the mist drifting over the ground of the background |
| `motion`, `motion_amount`, `motion_seconds` | how the boss moves while it waits: `BREATHE`, `HOVER`, `SWAY` or `SLITHER` (a wave running up its body, the head moving most) |
| `waterline` | for a boss rising from water: the bottom edge of its figure fades into it |
| `eyes`, `eye_color`, `eye_radius`, `eye_glow` | a glow over its eyes, which moves along with it: where they are in the figure (0 to 1 of its width and height), its colour, size in pixels of the picture and strength |
| `taunt` | what it says when the fight begins |
| `attack_min`, `attack_max` | its attack against each hero per round, on *Normal*. Each difficulty adds its `attack_bonus`. |
| `attack_by_heroes` | added to its attack with 1, 2, 3 and 4 heroes, or empty |
| `shields` | the shields it raises each round, such as `{ "melee": 2, "ranged": 2, "magic": 2 }` |
| `shield_by_heroes` | added to each shield with 1, 2, 3 and 4 heroes, or empty (`Boss.shields_for()`) |
| `away_message` | what the players are told when a card attacks it while it is out of reach (see below) |

`Boss` extends `FightRule` (`scripts/fight_rule.gd`), so a boss can step in at every moment of the fight that has a
hook there, such as `round_started`, `card_playing`, `damage_taken` or `boss_hurt` (for something that happens at half
health). Three hooks only the boss has, as they are its phases: `plan_attacks`, `raise_shields` and `attack_hero`, at
the end of `scripts/boss.gd`. Each hook has the default that a boss without special rules uses, and gets the `Fight`
(`scripts/fight.gd`) to read and change. A hook can wait for the players, for example to let them choose between tied
targets: `await fight.choose_hero(...)`. See [The boss fight](boss_fight.md#how-it-fits-together).

Besides these, `shield_hit` is for what a shield does besides absorbing damage, such as hurting whoever hits it.
Cards can let an attack ignore it (`FightRule.ignores_shield_effect`). A boss whose shields do that shows it by
overriding `shield_icon` to return `SHIELD_DARK`, or `SHIELD_POISON` for poisonous shields, instead of the plain
`SHIELD_NORMAL`.

A boss can change its look during the fight, such as its eyes turning red when enraged: it changes its fields and
emits `look_changed`, and the screen shows it anew.

A boss can **go out of reach**, such as under water: `fight.set_boss_away(true)`. Then damage and poison from cards
do not reach it, and the players are told once per card (`away_message`); the cards' other symbols still work. Its
own poison at the end of a round still hurts it. On screen, it sinks below the bottom edge of its picture and its
shields and attack types fade; `set_boss_away(false)` brings it back up with a splash.

**@-abilities** are the boss's own code, in any of its hooks. Before using one, a boss asks the fight, as cards can
prevent them:

```gdscript
func attack_hero(fight: Fight, hero: FightHero) -> void:
	if fight.round_number % 3 == 0 and await fight.boss_ability("tongue", 4, hero):
		hero.threat += 4
	await super(fight, hero)
```

`attack_hero` strikes through `fight.strike(hero)`. The fight tells the players of all of the boss's hits together,
once every hero is struck, and only then do the rules hear of them (`hero_struck`, `hero_hurt`).

`boss_ability(id, strength, target)` returns false if a card prevented it, and then tells the players by what.
`strength` is the number on the @; `target` is the hero it is against, or null for everyone.

**Add a hook for every new moment a boss could want to step in**, call it from `Fight`, and keep the default plain, so
that most bosses need no code at all.

`Bosses.create(id)` makes a new boss each time, so each fight gets its own and a boss can keep track of things, such as
a heat counter, in its own variables.

**Adding a boss:** write `scripts/bosses/<id>.gd`, add the id to `Bosses.IDS`, and add its three pictures.

All text needs a German and an English version (see [Adding text](settings.md#adding-text)).
`tests/test_bosses.gd` checks this, and the pictures, for every boss and every difficulty.

**Mirefang** is the only boss so far (see [below](#mirefang)).

## Mirefang

The first boss (`scripts/bosses/mirefang.gd`): a giant venomous serpent of an eerie swamp, *Moorzahn* in German.
- **The number of heroes** changes it, so that 1 to 4 heroes have about the same chance (found with the
  [balance simulator](balance.md)). Fewer heroes have fewer actions and fewer cards to protect, heal and remove poison,
  and each of them is bitten more often. On *Normal*:

  | Heroes | Health | Attacks | Poison per attack | Shields | Bite |
  |--------|--------|---------|-------------------|---------|------|
  | 1 | 40 | 2 to 5 | 1 | 1 | 6 + 1 poison |
  | 2 | 60 | 2 to 5 | 1 to 3 | 2 | 10 + 3 poison |
  | 3 | 80 | 2 to 5 | 1 to 3 | 3 | 15 + 3 poison |
  | 4 | 100 | 3 to 6 | 1 to 3 | 4 | 18 + 3 poison |

  The difficulty changes health and attacks as for every boss, and the bite as below. In the script:
  `health_by_heroes`, `attack_by_heroes`, `shield_by_heroes`, and its own `bite_by_heroes` (added to the bite's
  damage) and `poison_by_heroes` (added to the poison of its attacks and bite, never below 1).
- **Attacks:** 2 to 5 against each hero, each with 1 to 3 poison (with 3 heroes).
- **Shields:** 3 of each type every round (with 3 heroes). One of them, at random, is the **poison shield**: whoever hits it gets 1
  poison (`mirefang_poison_shield`). Cards that ignore a shield's effect ignore that too.
- **Dive:** when its health falls below 75 %, 50 % and 25 % (60, 40 and 20 on *Normal* with 3 heroes), it dives
  (`mirefang_dive`), each mark once. A hit past several marks makes it dive once only; the marks passed are gone.
  - It goes out of reach (`Fight.set_boss_away`): its shields are gone, and attacks and poison from cards do not reach
    it (`mirefang_out_of_reach`).
  - All its attacks are gone. Instead one hero, at random, is marked for its bite: 12 + 2 poison on *Easy*,
    15 + 3 on *Normal*, 18 + 3 on *Hard*, with 3 heroes. Protection lowers it as any attack.
  - Every hero gets an action more this round (a yellow orb) to prepare.
  - It dives right after the card that took it past the mark. Past a mark outside the action phase, such as by its
    own poison at the end of a round, it dives when the next action phase starts.
  - At the end of the action phase it surfaces (`mirefang_surfaces`), and in the attack phase it bites. The bite is an
    @-ability (`mirefang_bite`), which cards can prevent. Then the round ends as usual, and the next one starts with
    new shields and attacks.
- **Enraged:** surfacing below half its health, it is enraged for the rest of the fight (`mirefang_enraged`): +1 on
  its attacks and its shields, and its poison shield gives 2 poison. Its eyes glow red and it moves faster.
- **Venom spit:** a card that costs it 7 health or more makes it spit venom on every hero, 1 poison each
  (`mirefang_spit`), at most once a round. An @-ability of strength 1 (`mirefang_spit`). If the same card takes it
  past a mark, it spits first, then dives.
- **Tuning:** its numbers are variables at the top of its script, so that the [balance simulator](balance.md) can try
  others with `--set`.
- **Look:** it slithers (`Motion.SLITHER`), rises from the water (`waterline`) and its eyes glow (`eyes`, measured on
  `FigureMirefang.png`: set them again if the picture changes). The prompts are in
  [Artwork prompts](artwork_prompts.md#mirefang--the-serpent-of-the-rotmire).

## Artwork

The pictures are in `assets/bosses/`. The ones there now are placeholders, made by `art/make_boss_placeholders.sh`.
`art/import_boss_art.sh <folder>` takes the finished ones from a folder and scales them to size.

- **`Boss<Name>.png`, for the list and the overview:** landscape, 4:3, scaled to 1024 x 768. **Best keep the boss's face
  in the middle.** The list crops each picture to a wide strip around the face (`art_focus`, the centre by default),
  and the overview to a slightly less wide one. The bottom third of the strip in the list lies under the boss's name.
- **`Figure<Name>.png`, the boss in the fight:** portrait, about 3:4, transparent around the boss, at most 768 x 1024.
  It is fitted into most of the screen without cropping. Its bottom edge is where the boss stands: breathing and
  swaying keep it in place.
- **`Background<Name>.png`, behind the boss:** portrait, 9:16, scaled to 900 x 1600. Taller and wider screens crop
  it, so keep nothing important near the edges. The bottom fifth lies under the round and the health.

## How it fits together

Both screens extend `MenuScreen` (`scripts/menu_screen.gd`), which fades in from black and out to the next screen,
handles Escape and the back button of a phone, and lets tests catch the change of scene through `change_scene`. While
one of them is shown, the back button of a phone does not quit the app.

Going back to the table sets `show_splash = false` on the onboarding scene before it starts, so the logo only shows
when the app starts.
