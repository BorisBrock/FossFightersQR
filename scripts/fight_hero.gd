class_name FightHero
extends RefCounted
## A hero in a fight: who it is, and what the app knows of them during it. Their health
## is on the real table, as are their cards.

## The status tokens a hero can have, see docs/game-rule-summary.md.
const TOKENS: Array[String] = ["poison", "panic", "paralysis", "fire"]

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
## Token -> count, kept until the end of the fight unless something removes them.
var tokens := {}
## Turns left in this round's action phase. Each turn is one action, plus Lightning.
var turns_left := 0
## Extra turns in the next round, such as from a Warhorse.
var bonus_turns := 0
## The QR codes of the cards in the play area, which cannot be played again this round.
var played: Array[String] = []
## How often this hero used each card in the fight, by QR code, for cards with a limit.
var uses := {}
## For rules that need to remember something about a hero.
var notes := {}


func _init(party_hero: Party.Hero) -> void:
	hero = party_hero


func token_count(token: String) -> int:
	return tokens.get(token, 0)


func add_tokens(token: String, count: int) -> void:
	tokens[token] = maxi(0, token_count(token) + count)
	if tokens[token] == 0:
		tokens.erase(token)


func has_tokens() -> bool:
	return not tokens.is_empty()
