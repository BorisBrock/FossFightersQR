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
}

## Set from its file name by Bosses.
var id := ""

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
#endregion

#region Fight
## The boss itself, centred and large: portrait, transparent around it.
var figure := ""
## Behind the boss, covering the screen: portrait, 9:16.
var background := ""
## Health on normal difficulty. The difficulty scales it (Bosses.DIFFICULTIES).
var health := 40
var ambience := Ambience.EMBERS
var ambience_color := Color(1.0, 0.7, 0.35)
## The colour of the mist that drifts over the ground of the background.
var mist_color := Color(0.8, 0.8, 0.8)
var motion := Motion.BREATHE
## How far the boss moves, in pixels of its picture.
var motion_amount := 12.0
## How long one movement takes, back and forth.
var motion_seconds := 4.0
## What the boss says when the fight begins, { "de": …, "en": … }.
var taunt := {
	"de": "Muahaha! Ihr werdet alle untergehen!",
	"en": "Muahaha! You are all going to die!",
}
#endregion

#region Rules
## The range of its attack against each hero per round, on normal difficulty. The
## difficulty adds its attack_bonus (Bosses.DIFFICULTIES).
var attack_min := 2
var attack_max := 5
## The shields it raises each round, by damage type. A missing type gets no shield.
var shields := { "melee": 2, "ranged": 2, "magic": 2 }
#endregion


## The health the boss starts with on a difficulty.
func max_health(difficulty: String) -> int:
	return maxi(1, roundi(health * Bosses.DIFFICULTIES[difficulty].health_factor))


## The attack against one hero on a difficulty, before anything lowers it.
func attack_range(difficulty: String) -> Vector2i:
	var bonus: int = Bosses.DIFFICULTIES[difficulty].attack_bonus
	return Vector2i(maxi(0, attack_min + bonus), maxi(0, attack_max + bonus))


## What the boss tells comes with its name, such as its armour weakening an attack.
func message_source() -> Dictionary:
	return { "title": title }


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
	var attack := attack_range(fight.difficulty)
	for hero in fight.heroes:
		fight.threaten(hero, fight.rng.randi_range(attack.x, attack.y))


## Phase 2: raises the shields, through fight.set_shields(). By default the same each
## round, replacing what is left of the last ones.
func raise_shields(fight: Fight) -> void:
	fight.set_shields(shields)


## Phase 4: strikes one hero. By default with what is left of its planned attack.
func attack_hero(fight: Fight, hero: FightHero) -> void:
	await fight.strike(hero)


## The picture of its shield of kind, on which the screen shows the shield's value. A boss
## whose shields are special, such as thorny ones, can show its own.
func shield_icon(_kind: String) -> String:
	return "res://assets/fight/icon_boss_shield.svg"


## Its shield of kind absorbed amount damage from play (or null). What a shield does
## besides, such as hurting whoever hits it, goes here. Not called when a rule lets play
## ignore it (FightRule.ignores_shield_effect). By default a shield only absorbs.
func shield_hit(_fight: Fight, _kind: String, _amount: int, _play: CardPlay) -> void:
	pass
#endregion
