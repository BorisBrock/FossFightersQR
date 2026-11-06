class_name Fight
extends RefCounted
## What is going on in a boss fight: the boss, the round and its health. The boss fight
## scene shows it, and the boss's hooks can change it.
##
## The rules of a turn are not built yet. Only what the screen shows exists so far.

signal round_changed(round_number: int)
signal health_changed(health: int, max_health: int)
signal won

var boss: Boss
var difficulty: String
## Counts from 1.
var round_number := 0
var health := 0
var max_health := 0


func _init(fight_boss: Boss, fight_difficulty: String) -> void:
	boss = fight_boss
	difficulty = fight_difficulty
	max_health = boss.max_health(difficulty)
	health = max_health


func start() -> void:
	boss.fight_started(self)
	next_round()


func next_round() -> void:
	round_number += 1
	round_changed.emit(round_number)
	boss.round_started(self)


## Lets the boss decide how much of the attack hurts, then takes that off its health.
func attack(amount: int, kind := "attack") -> void:
	if health <= 0:
		return
	set_health(health - maxi(0, boss.damage_taken(self, amount, kind)))


func set_health(value: int) -> void:
	health = clampi(value, 0, max_health)
	health_changed.emit(health, max_health)
	if health == 0:
		won.emit()
