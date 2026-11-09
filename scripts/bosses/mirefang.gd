extends Boss
## Mirefang, the first boss: a giant venomous serpent of the swamp. See docs/bosses.md#mirefang.
##
## - Every attack poisons.
## - Each round, one of its three shields is poisonous: whoever hits it is poisoned.
## - Below 75 %, 50 % and 25 % of its health, it dives: its shields and attacks are gone,
##   attacks cannot reach it, and one hero is marked for its bite. Every hero gets an
##   action more to prepare. At the end of the action phase it surfaces and bites.
## - From the dive below half its health on, it is enraged: stronger attacks and shields.
## - A card that costs it SPIT_DAMAGE health or more makes it spit venom on every hero,
##   once a round.

## It dives when its health falls below these parts of its health, each once. A hit past
## several of them makes it dive once only.
const DIVE_BELOW: Array[float] = [0.75, 0.5, 0.25]
## Its bite when it surfaces, by difficulty: damage and poison.
const BITE := {
	"easy": { "damage": 12, "poison": 2 },
	"normal": { "damage": 15, "poison": 3 },
	"hard": { "damage": 18, "poison": 3 },
}
## Surfacing below this part of its health, it is enraged.
const ENRAGED_BELOW := 0.5
## What enraged adds to its attacks and its shields, and its poison shield's poison.
const ENRAGED_BONUS := 1
## A card that costs it this much health makes it spit.
const SPIT_DAMAGE := 7
const SPIT_POISON := 1
const ENRAGED_EYES := Color(1.0, 0.18, 0.1)

## Every shield has this value, the poison shield too.
var shield_value := 3
## The poison of each attack, at random.
var poison_min := 1
var poison_max := 3
## Under water, until it surfaces at the end of the action phase.
var submerged := false
var enraged := false
## The damage type of this round's poison shield.
var poison_shield := ""

## How many of DIVE_BELOW it has passed.
var _passed := 0
## It has passed one of DIVE_BELOW and dives as soon as it can.
var _dive_due := false
## Whom it bites when it surfaces.
var _bitten: FightHero
var _spat_round := 0
## It has surfaced this round.
var _surfaced := false


func _init() -> void:
	title = { "de": "Moorzahn", "en": "Mirefang" }
	tagline = { "de": "Die Schlange im Faulmoor", "en": "The Serpent of the Rotmire" }
	story = {
		"de": "Unter dem schwarzen Wasser des Faulmoors lebt Moorzahn, eine Schlange so lang wie ein Fluss. Seine Zähne sind so groß wie Sensen, und ein Tropfen seines Gifts lässt einen Ochsen umfallen. Lange schlief er im Schlamm. Jetzt verschwinden Fischer, Boote und ganze Stege, und in den Nächten leuchten über dem Wasser zwei gelbe Augen.",
		"en": "Beneath the black water of the Rotmire lives a serpent as long as a river. Its fangs are as big as scythes, and a drop of its venom fells an ox. For a long time it slept in the mud. Now fishermen, boats and whole jetties vanish, and at night two yellow eyes glow above the water.",
	}
	hints = [
		{ "de": "Jeder Biss von Moorzahn vergiftet. Haltet Gegengift bereit.", "en": "Every bite of Mirefang poisons. Keep an antidote ready." },
		{ "de": "Einer seiner Schilde ist giftig. Wer ihn trifft, bekommt Gift ab.", "en": "One of its shields is poisonous. Whoever hits it is poisoned." },
		{ "de": "Verwundet taucht er ab und lauert. Schützt den, den er sich ausgesucht hat.", "en": "Wounded, it dives and lies in wait. Protect the one it has chosen." },
		{ "de": "Ein zu harter Schlag reizt ihn, Gift zu spucken.", "en": "Hit it too hard, and it spits venom." },
	]
	art = "res://assets/bosses/BossMirefang.png"
	figure = "res://assets/bosses/FigureMirefang.png"
	background = "res://assets/bosses/BackgroundMirefang.png"
	health = 80
	attack_min = 2
	attack_max = 5
	ambience = Ambience.FIREFLIES
	ambience_color = Color(0.75, 1.0, 0.45)
	mist_color = Color(0.45, 0.62, 0.42)
	motion = Motion.SLITHER
	motion_amount = 9.0
	motion_seconds = 6.5
	art_focus = Vector2(0.5, 0.3)
	eyes = [Vector2(0.414, 0.139), Vector2(0.655, 0.137)]
	eye_color = Color(1.0, 0.85, 0.25)
	eye_radius = 13.0
	eye_glow = 0.6
	waterline = true
	away_message = "mirefang_out_of_reach"
	sounds = {
		"boss_appears": "boss_mirefang_emerge",
		"boss_sinks": "boss_mirefang_dive",
		"boss_defeated": "boss_mirefang_death",
		"boss_taunt": "boss_mirefang_hiss",
		"boss_attacks": "boss_mirefang_attack",
		"mirefang_surfaces": "boss_mirefang_lunge",
		"mirefang_spit": "boss_mirefang_spit",
		"mirefang_poison_shield": "boss_mirefang_poison_shield",
		"mirefang_enraged": "boss_mirefang_enraged",
	}
	taunt = {
		"de": "Ssssso viele kleine Helden ... und ich bin ssso hungrig.",
		"en": "Ssssso many little heroes ... and I am ssso hungry.",
	}


## Every attack poisons, the stronger ones not more than the others.
func plan_attacks(fight: Fight) -> void:
	var attack := attack_range(fight.difficulty)
	var bonus := ENRAGED_BONUS if enraged else 0
	for hero in fight.heroes:
		fight.threaten(hero, fight.rng.randi_range(attack.x, attack.y) + bonus,
			{ "poison": fight.rng.randi_range(poison_min, poison_max) })


## Three shields of the same value, one of them poisonous, chosen at random each round.
func raise_shields(fight: Fight) -> void:
	poison_shield = Fight.DAMAGE_TYPES[fight.rng.randi() % Fight.DAMAGE_TYPES.size()]
	var value := shield_value + (ENRAGED_BONUS if enraged else 0)
	fight.set_shields({ "melee": value, "ranged": value, "magic": value })


func shield_icon(kind: String) -> String:
	return SHIELD_POISON if kind == poison_shield else SHIELD_NORMAL


## Whoever hits the poison shield is poisoned.
func shield_hit(fight: Fight, kind: String, _amount: int, play: CardPlay) -> void:
	if kind != poison_shield or play == null:
		return
	var poison := 1 + (ENRAGED_BONUS if enraged else 0)
	fight.tell("mirefang_poison_shield", { "player": play.hero.name, "poison": poison })


## Passing one of DIVE_BELOW, it dives once it can: after the card that did it, or when
## the next action phase starts, such as after its own poison at the end of a round.
func boss_hurt(fight: Fight, _old: int, new: int) -> void:
	while _passed < DIVE_BELOW.size() and new < fight.max_health * DIVE_BELOW[_passed]:
		_passed += 1
		_dive_due = new > 0


func card_played(fight: Fight, play: CardPlay) -> void:
	if play.damage >= SPIT_DAMAGE and _spat_round != fight.round_number:
		_spat_round = fight.round_number
		if await fight.boss_ability("mirefang_spit", SPIT_POISON):
			fight.tell("mirefang_spit", { "boss": title, "poison": SPIT_POISON })
			await fight.until_read()
	if _dive_due and fight.phase == Fight.Phase.ACTION:
		await _dive(fight)


func action_phase_started(fight: Fight) -> void:
	if _dive_due:
		await _dive(fight)


## Under water, its shields and attacks are gone, and it marks one hero for its bite.
## Every hero gets an action more to prepare.
func _dive(fight: Fight) -> void:
	_dive_due = false
	if submerged or fight.over or fight.heroes.is_empty():
		return
	submerged = true
	fight.set_boss_away(true)
	fight.set_shields({})
	for hero in fight.heroes:
		fight.threaten(hero, 0)
	_bitten = fight.heroes[fight.rng.randi() % fight.heroes.size()]
	var bite: Dictionary = BITE.get(fight.difficulty, BITE.normal)
	fight.threaten(_bitten, bite.damage, { "poison": bite.poison })
	for hero in fight.heroes:
		hero.turns_left += 1
		hero.extra_turns += 1
		fight.hero_changed.emit(hero)
	fight.tell("mirefang_dive", { "boss": title, "player": _bitten.name, "damage": bite.damage, "poison": bite.poison })
	await fight.until_read()


## It surfaces at the end of the action phase, to bite in the attack phase.
func action_phase_ended(fight: Fight) -> void:
	if not submerged:
		return
	submerged = false
	_surfaced = true
	fight.set_boss_away(false)
	fight.tell("mirefang_surfaces", { "boss": title, "player": _bitten.name if _bitten != null else "" })
	await fight.until_read()


## The bite of a dive is an @-ability, which cards can prevent.
func attack_hero(fight: Fight, hero: FightHero) -> void:
	if hero == _bitten:
		_bitten = null
		if hero.threat > 0 and not await fight.boss_ability("mirefang_bite", hero.threat, hero):
			return
	await super(fight, hero)


## Surfacing below half its health, it is enraged for the rest of the fight.
func attack_phase_ended(fight: Fight) -> void:
	var surfaced := _surfaced
	_surfaced = false
	if enraged or not surfaced or fight.health >= fight.max_health * ENRAGED_BELOW:
		return
	enraged = true
	eye_color = ENRAGED_EYES
	eye_glow = 1.0
	eye_radius = 16.0
	motion_seconds = 4.5
	motion_amount = 12.0
	look_changed.emit()
	fight.tell("mirefang_enraged", { "boss": title })
	await fight.until_read()
