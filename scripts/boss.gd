class_name Boss
extends FightRule
## One boss. What all bosses have in common lives here: the text for the menus, the
## pictures, how the fight looks and the rules every boss follows.
##
## Each boss is a script in scripts/bosses/ that extends this one. It fills in its data in
## _init() and overrides hooks for whatever makes it special: the boss's own ones below,
## and those of every rule in FightRule. A boss with no special rules overrides nothing
## but _init(). See docs/bosses.md.

## The drifting particles over the background. All are tinted with ambience_color.
enum Ambience {
	## Rising from the bottom, like sparks from a fire.
	EMBERS,
	## Floating everywhere and fading in and out.
	FIREFLIES,
	## Drifting slowly across the screen.
	DUST,
}

## How the boss moves while it waits, anchored at its feet.
enum Motion {
	## Grows a little taller and back, like taking deep breaths.
	BREATHE,
	## Floats up and down, for anything with wings.
	HOVER,
	## Leans from side to side.
	SWAY,
	## A wave runs up its body, the head moving most, like a rearing snake.
	SLITHER,
}

## The pictures of shields, see shield_icon(): plain iron ones that only absorb damage,
## dark ones that do something besides, and poisonous ones.
const SHIELD_NORMAL := "res://assets/fight/boss_shield_normal.png"
const SHIELD_DARK := "res://assets/fight/boss_shield_dark.png"
const SHIELD_POISON := "res://assets/fight/boss_shield_poison.png"

## Set from its file name by Bosses.
var id := ""

## The boss's look changed during the fight, such as its eyes or how fast it moves: the
## screen shows it anew.
signal look_changed

#region Menus
## For the boss list, the overview and the fight. All text is { "de": …, "en": … }.
var title := {}
var tagline := {}
## A few sentences for the overview.
var story := {}
## Short strategy hints for the overview, as many as needed.
var hints: Array[Dictionary] = []
## The picture in the boss list and the overview: landscape, 4:3.
var art := ""
## Where its face is in art, as parts of its width and height. The list and the overview
## crop the picture to a strip, keeping this as near the middle as they can.
var art_focus := Vector2(0.5, 0.5)
#endregion

#region Fight
## The boss itself, centred and large: portrait, transparent around it.
var figure := ""
## Behind the boss, covering the screen: portrait, 9:16.
var background := ""
## Health on normal difficulty. The difficulty scales it (Bosses.DIFFICULTIES).
var health := 40
## Health on normal difficulty with 1, 2, 3 and 4 heroes, instead of health, as more
## heroes have more actions, protection and healing. Empty: health for any number.
var health_by_heroes: Array[int] = []
var ambience := Ambience.EMBERS
var ambience_color := Color(1.0, 0.7, 0.35)
## The colour of the mist that drifts over the ground of the background.
var mist_color := Color(0.8, 0.8, 0.8)
var motion := Motion.BREATHE
## How far the boss moves, in pixels of its picture.
var motion_amount := 12.0
## How long one movement takes, back and forth.
var motion_seconds := 4.0
## Where its eyes are in the figure, as parts of the picture's width and height (0 to 1),
## for a glow that moves along with it. Empty for none.
var eyes: Array[Vector2] = []
## The glow of its eyes: colour, radius in pixels of the picture, and strength (0 for none).
var eye_color := Color(1.0, 0.85, 0.3)
var eye_radius := 14.0
var eye_glow := 0.0
## For a boss that rises from water: the bottom edge of its figure fades into it.
var waterline := false
## What the boss says when the fight begins, { "de": …, "en": … }.
var taunt := {
	"de": "Muahaha! Ihr werdet alle untergehen!",
	"en": "Muahaha! You are all going to die!",
}
## A line for the start of each round, one after the other, beginning again after the
## last: the boss's mood or what it does, each { "de": …, "en": … }. See round_text().
var round_texts: Array[Dictionary] = [
	{ "de": "Der Boden bebt. Der Kampf geht weiter!", "en": "The ground trembles. The fight goes on!" },
	{ "de": "Euer Gegner mustert euch mit kaltem Blick.", "en": "Your enemy eyes you coldly." },
	{ "de": "Ein Grollen erfüllt die Luft.", "en": "A rumble fills the air." },
	{ "de": "Haltet stand, Helden!", "en": "Stand firm, heroes!" },
]
## Its own sounds (assets/sounds/<name>.ogg) instead of the fight's usual ones: by the
## name of the sound it replaces (see Sfx.NAMES), or by a message id for the sound of
## that message. Two have no usual sound and play only if a boss has its own:
## "boss_sinks" (it goes out of reach) and "boss_defeated" (it fades away, beaten).
## See docs/sounds.md#boss-sounds.
var sounds := {}
#endregion

#region Rules
## The range of its attack against each hero per round, on normal difficulty. The
## difficulty adds its attack_bonus (Bosses.DIFFICULTIES).
var attack_min := 2
var attack_max := 5
## Added to the attack against each hero with 1, 2, 3 and 4 heroes. Empty: nothing.
var attack_by_heroes: Array[int] = []
## The shields it raises each round, by damage type. A missing type gets no shield.
var shields := { "melee": 2, "ranged": 2, "magic": 2 }
## Added to each of its shields with 1, 2, 3 and 4 heroes, as fewer heroes have fewer
## actions to break them. Empty: nothing. Not below 0.
var shield_by_heroes: Array[int] = []
## The message (see Messages) when a card attacks it while it is out of reach
## (Fight.set_boss_away), with {boss}.
var away_message := "boss_away_missed"
#endregion


## The health the boss starts with on a difficulty, against that many heroes.
func max_health(difficulty: String, heroes := Party.MAX_HEROES) -> int:
	var base: int = by_heroes(health_by_heroes, heroes, health)
	return maxi(1, roundi(base * Bosses.DIFFICULTIES[difficulty].health_factor))


## The attack against one hero on a difficulty, against that many heroes, before
## anything lowers it.
func attack_range(difficulty: String, heroes := Party.MAX_HEROES) -> Vector2i:
	var bonus: int = Bosses.DIFFICULTIES[difficulty].attack_bonus + by_heroes(attack_by_heroes, heroes)
	return Vector2i(maxi(0, attack_min + bonus), maxi(0, attack_max + bonus))


## The value of values (for 1, 2, 3 and 4 heroes) for that many heroes, or fallback if
## values is empty, such as health_by_heroes.
static func by_heroes(values: Array[int], heroes: int, fallback := 0) -> int:
	if values.is_empty():
		return fallback
	return values[clampi(heroes, 1, values.size()) - 1]


## Its shields this round: shields, with shield_by_heroes.
func shields_for(fight: Fight) -> Dictionary:
	var bonus := by_heroes(shield_by_heroes, fight.heroes.size())
	var result := {}
	for kind: String in shields:
		result[kind] = maxi(0, shields[kind] + bonus)
	return result


## The line for the start of round round_number (from 1), from round_texts.
func round_text(round_number: int) -> Dictionary:
	if round_texts.is_empty():
		return {}
	return round_texts[(maxi(1, round_number) - 1) % round_texts.size()]


## What the boss tells comes with its name, such as its armour weakening an attack.
func message_source() -> Dictionary:
	return { "title": title, "boss": true }


#region The boss's own hooks
# Only the boss has these, as they are what it does in its phases. The defaults are what a
# boss without special rules does. Each may wait for the players, as all hooks may (see
# FightRule). The hooks every rule has are in FightRule.
#
# Its @-abilities are its own code too: before using one, a boss asks
# `if await fight.boss_ability("id", strength, target):`, as cards can prevent them.

## Phase 1: decides the attack against each hero, through fight.threaten(). By default
## each hero gets a random attack from attack_range().
func plan_attacks(fight: Fight) -> void:
	var attack := attack_range(fight.difficulty, fight.heroes.size())
	for hero in fight.heroes:
		fight.threaten(hero, fight.rng.randi_range(attack.x, attack.y))


## Phase 2: raises the shields, through fight.set_shields(). By default the same each
## round, replacing what is left of the last ones.
func raise_shields(fight: Fight) -> void:
	fight.set_shields(shields_for(fight))


## Phase 4: strikes one hero. By default with what is left of its planned attack.
func attack_hero(fight: Fight, hero: FightHero) -> void:
	await fight.strike(hero)


## The picture of its shield of kind, above the shield's value on the screen. A boss whose
## shields do something besides absorbing (shield_hit) shows that with SHIELD_DARK, or
## SHIELD_POISON for poisonous ones.
func shield_icon(_kind: String) -> String:
	return SHIELD_NORMAL


## Its shield of kind absorbed amount damage from play (or null). What a shield does
## besides, such as hurting whoever hits it, goes here. Not called when a rule lets play
## ignore it (FightRule.ignores_shield_effect). By default a shield only absorbs.
func shield_hit(_fight: Fight, _kind: String, _amount: int, _play: CardPlay) -> void:
	pass
#endregion
