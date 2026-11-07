class_name CardAbility
extends FightRule
## What a card does beyond its symbols, such as letting another hero play a card at once.
##
## Each ability is a script in scripts/abilities/, named after its id, which extends this
## one. A card names it in its "ability" field, and can pass it values through
## "ability_values", so that one script serves many cards: { "ability": "extra_turns",
## "ability_values": { "turns": 1 } }. See docs/cards.md.
##
## A new one is made each time the card is played. As a FightRule, it can stay in the
## fight for a while (Fight.add_rule) and step in at any moment of it.
##
## Character and class cards can have one too, for what a hero's level gives them. That
## one joins the fight at its start, for its hero (owner), and stays.

const SCRIPT_PATH := "res://scripts/abilities/%s.gd"

var id := ""
## From the card's ability_values.
var values := {}
var card: Card
## For the ability of a character or class card, what a hero's level gives them: that
## hero. It is in the fight from the start, as a rule (Fight.rules), so it steps in
## through the hooks of FightRule. null for the abilities of cards being played.
var owner: FightHero


## The ability for a card, or null if it has none. An ability that does not exist yet
## gives null with a warning, so that the card still does what its symbols say.
static func create(for_card: Card) -> CardAbility:
	if for_card.ability.is_empty():
		return null
	var path := SCRIPT_PATH % for_card.ability
	if not ResourceLoader.exists(path):
		push_warning("Card %s: no ability '%s' yet" % [for_card.qr, for_card.ability])
		return null
	var ability: CardAbility = load(path).new()
	ability.id = for_card.ability
	ability.values = for_card.ability_values
	ability.card = for_card
	return ability


func value(key: String, default: Variant) -> Variant:
	return values.get(key, default)


## Whether play is by the hero this ability is for (owner).
func is_mine(play: CardPlay) -> bool:
	return play != null and owner != null and play.hero == owner


## For messages: the title of its card.
func title() -> Dictionary:
	return card.title if card != null else {}


## Why the card cannot be played now, as the id of a message (see Messages), or "" if it
## can. The players see it briefly and the card is not played.
func can_play(_fight: Fight, _play: CardPlay) -> String:
	return ""


## Before the card's symbols take effect, after the rules have seen it (card_playing).
func before_effects(_fight: Fight, _play: CardPlay) -> void:
	pass


## After the card's symbols took effect.
func after_effects(_fight: Fight, _play: CardPlay) -> void:
	pass
