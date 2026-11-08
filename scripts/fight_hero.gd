class_name FightHero
extends RefCounted
## A hero in a fight: who it is, and what the app knows of them during it. Their health
## is on the real table, as are their cards and their status tokens.

var hero: Party.Hero
var name: String:
	get: return hero.name
var seat: int:
	get: return hero.seat

## The boss's attack against this hero this round, once planned. Protection lowers it.
var threat := 0
## What the attack does besides damage, as token -> count, such as { "poison": 1 }. An
## attack lowered to exactly 0 loses it.
var threat_effects := {}
## The kinds of action the screen shows, each as a sphere.
enum Action {
	## One of the turns every hero has each round.
	TURN,
	## An extra one, such as from Lightning or a Warhorse.
	BONUS,
	## An extra one with a limit on what can be played, such as the Lucky Charm's top card.
	LIMITED,
}

## Turns left in this round's action phase. Each turn is one action, plus Lightning.
var turns_left := 0
## How many of the turns this round are extra, such as from a Warhorse. They are taken
## last, so the last of turns_left are extra.
var extra_turns := 0
## Extra turns in the next round, such as from a Warhorse.
var bonus_turns := 0
## The actions this hero is playing right now, or may play right away, such as the turn
## they are taking and what Lightning gives them. The last one is played first.
var pending: Array[Action] = []
## The QR codes of the cards in the play area, which cannot be played again this round.
var played: Array[String] = []
## How often this hero used each card in the fight, by QR code, for cards with a limit.
var uses := {}
## The form the dryad has taken (dryad_form), such as "thorn", or empty for none. It stays
## until she takes another.
var form := ""
## For rules that need to remember something about a hero.
var notes := {}


func _init(party_hero: Party.Hero) -> void:
	hero = party_hero



## Every action this hero has left this round, as the screen shows them: those to play
## right now, then their turns, the extra ones last.
func actions() -> Array[Action]:
	var result: Array[Action] = pending.duplicate()
	result.reverse()
	var extra := clampi(extra_turns, 0, turns_left)
	for i in turns_left - extra:
		result.append(Action.TURN)
	for i in extra:
		result.append(Action.BONUS)
	return result


## Whether the next of turns_left is an extra one.
func next_turn_is_extra() -> bool:
	return turns_left > 0 and turns_left <= extra_turns
