class_name FightStats
extends RefCounted
## What happened in a fight, for the game over screen: how it ended, and what each hero,
## the whole team and the boss did. The fight fills it in as it goes (Fight.stats).

enum Outcome {
	## The fight is still on.
	NONE,
	## The boss's health reached 0.
	WON,
	## A hero fell, or a rule ended the fight as lost.
	LOST,
	## The players stopped the fight before it was decided.
	ABORTED,
}


## What one hero did in the fight.
class HeroStats:
	## Damage that reached the boss's health.
	var damage := 0
	## Damage that broke the boss's shields instead.
	var shield_damage := 0
	var healing := 0
	## How much protection lowered the boss's attacks.
	var protection := 0
	## From the boss's attacks and from poison.
	var damage_taken := 0
	## Status tokens the boss's attacks gave them.
	var tokens_taken := 0
	var cards := 0
	var passes := 0
	## The strength of the attack and support symbols they played, by damage type.
	var power := { "melee": 0, "ranged": 0, "magic": 0 }
	## The most damage one of their cards did.
	var best_card := 0
	## Attacks against them that protection lowered to 0.
	var attacks_blocked := 0

	func total_power() -> int:
		var total := 0
		for kind: String in power:
			total += power[kind]
		return total


var outcome := Outcome.NONE
var rounds := 0
var max_health := 0
## The boss's health at the start, and at the end of each round. The last entry is the
## health when the fight ended, even in the middle of a round.
var health_by_round: Array[int] = []
## Damage dealt to the boss in each round, from round 1.
var damage_by_round: Array[int] = []
## Damage to the boss without a card behind it, such as from a boss's own rule.
var other_damage := 0
## Attacks the boss made against heroes, and those that were fully blocked.
var attacks := 0
var attacks_blocked := 0
## By FightHero.
var heroes := {}

var _planned := {}


func _init(fight_heroes: Array[FightHero] = [], boss_health := 0) -> void:
	max_health = boss_health
	health_by_round.append(boss_health)
	for hero in fight_heroes:
		heroes[hero] = HeroStats.new()


func of(hero: FightHero) -> HeroStats:
	if not heroes.has(hero):
		heroes[hero] = HeroStats.new()
	return heroes[hero]


#region Team and boss totals
func team_damage() -> int:
	var total := other_damage
	for stats: HeroStats in heroes.values():
		total += stats.damage
	return total


func team_shield_damage() -> int:
	return _sum(func(stats: HeroStats) -> int: return stats.shield_damage)


func team_healing() -> int:
	return _sum(func(stats: HeroStats) -> int: return stats.healing)


func team_protection() -> int:
	return _sum(func(stats: HeroStats) -> int: return stats.protection)


func team_cards() -> int:
	return _sum(func(stats: HeroStats) -> int: return stats.cards)


## What the boss did to the heroes: the damage of its attacks and of poison.
func boss_damage() -> int:
	return _sum(func(stats: HeroStats) -> int: return stats.damage_taken)


func boss_tokens() -> int:
	return _sum(func(stats: HeroStats) -> int: return stats.tokens_taken)


func best_round() -> int:
	var best := 0
	for damage in damage_by_round:
		best = maxi(best, damage)
	return best


func _sum(value: Callable) -> int:
	var total := 0
	for stats: HeroStats in heroes.values():
		total += value.call(stats)
	return total
#endregion


#region Filled in by the fight
func round_started(round_number: int) -> void:
	rounds = round_number
	while damage_by_round.size() < round_number:
		damage_by_round.append(0)


func round_ended(health: int) -> void:
	health_by_round.append(health)


func damage_dealt(dealt: int, absorbed: int, play: CardPlay) -> void:
	if rounds > 0 and dealt > 0:
		damage_by_round[rounds - 1] += dealt
	if play == null:
		other_damage += dealt
		return
	var stats := of(play.hero)
	stats.damage += dealt
	stats.shield_damage += absorbed


func power_played(hero: FightHero, kind: String, strength: int) -> void:
	var stats := of(hero)
	stats.power[kind] = stats.power.get(kind, 0) + strength


func card_played(play: CardPlay) -> void:
	var stats := of(play.hero)
	stats.cards += 1
	stats.best_card = maxi(stats.best_card, play.damage)


func passed(hero: FightHero) -> void:
	of(hero).passes += 1


func healed(hero: FightHero, amount: int) -> void:
	of(hero).healing += amount


func protected(hero: FightHero, amount: int) -> void:
	of(hero).protection += maxi(0, amount)


func attack_planned(hero: FightHero, amount: int) -> void:
	_planned[hero] = amount


## The attack phase has come to hero, with what is left of the attack against them.
func attack_resolved(hero: FightHero, threat: int) -> void:
	if _planned.get(hero, 0) <= 0:
		return
	attacks += 1
	if threat <= 0:
		attacks_blocked += 1
		of(hero).attacks_blocked += 1
	_planned.erase(hero)


func hero_hit(hero: FightHero, damage: int, tokens: int) -> void:
	var stats := of(hero)
	stats.damage_taken += maxi(0, damage)
	stats.tokens_taken += maxi(0, tokens)


func finished(how: Outcome, health: int) -> void:
	if outcome != Outcome.NONE:
		return
	outcome = how
	# The round the fight ended in counts, unless it ended right after one.
	if health_by_round.size() <= rounds:
		health_by_round.append(health)
#endregion
