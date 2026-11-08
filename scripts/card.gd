class_name Card
extends RefCounted
## One playing card. cards/cards.schema.json describes the data it is made from.


class Symbol:
	## attack, support, protection, heal, lightning, draw, poison, health_loss, direct_damage or special.
	var type: String
	var strength: int
	## melee, ranged or magic for attacks and supports, empty for all others.
	var damage_type := ""


var qr: String
var deck: String
## 0 if the card has no level.
var level := 0
## Set on character cards, see [HeroOptions]. Empty on all other cards.
var race := ""
## Set on class cards, see [HeroOptions]. Empty on all other cards.
var hero_class := ""
## Text by language code, see [method CardDatabase.localized]. Empty if the card has none.
var title: Dictionary
var effect: Dictionary
var symbols: Array[Symbol] = []
## What the card does beyond its symbols: the id of a script in scripts/abilities/, or
## empty. ability_values are passed to it, see [CardAbility].
var ability := ""
var ability_values := {}
## How often each hero can use this card in a fight, such as a potion. 0 for no limit.
var uses_per_fight := 0
## What kind of card it is, for rules that care, such as "totem" or "form".
var tags: Array[String] = []


## Items stay with their hero and can be used again in the same round.
func is_item() -> bool:
	return deck == "items"


## Cards that lie on the table instead of being drawn and discarded, such as items and
## the dryad's forms: they never go to the play area, so they can be played again in the
## same round.
func stays_on_table() -> bool:
	return is_item() or "form" in tags


func has_symbol(type: String) -> bool:
	return symbols.any(func(symbol: Symbol) -> bool: return symbol.type == type)


## Returns the card for parsed JSON data, or null if a field is missing or has the wrong
## type. Allowed values such as the deck names are left to the schema: a card that gets
## past this check cannot break the game.
static func from_data(data: Variant) -> Card:
	if not data is Dictionary:
		return null
	var card := Card.new()
	var qr_value: Variant = data.get("qr")
	var deck_value: Variant = data.get("deck")
	var level_value: Variant = data.get("level", 0)
	var race_value: Variant = data.get("race", "")
	var hero_class_value: Variant = data.get("hero_class", "")
	var title_value: Variant = data.get("title", {})
	var effect_value: Variant = data.get("effect", {})
	var symbols_value: Variant = data.get("symbols", [])
	var ability_value: Variant = data.get("ability", "")
	var ability_values_value: Variant = data.get("ability_values", {})
	var uses_value: Variant = data.get("uses_per_fight", 0)
	var tags_value: Variant = data.get("tags", [])
	if not qr_value is String or qr_value.is_empty() or not deck_value is String:
		return null
	if not _is_integer(level_value) or not _is_text(title_value) or not _is_text(effect_value):
		return null
	if not symbols_value is Array or not race_value is String or not hero_class_value is String:
		return null
	if not ability_value is String or not ability_values_value is Dictionary or not _is_integer(uses_value):
		return null
	if not tags_value is Array or tags_value.any(func(tag: Variant) -> bool: return not tag is String):
		return null
	card.qr = qr_value
	card.deck = deck_value
	card.level = int(level_value)
	card.race = race_value
	card.hero_class = hero_class_value
	card.title = title_value
	card.effect = effect_value
	card.ability = ability_value
	card.ability_values = ability_values_value
	card.uses_per_fight = int(uses_value)
	card.tags.assign(tags_value)
	for entry: Variant in symbols_value:
		if not entry is Dictionary or not entry.get("type") is String or not _is_integer(entry.get("strength")):
			return null
		var symbol := Symbol.new()
		symbol.type = entry.type
		symbol.strength = int(entry.strength)
		var damage_type: Variant = entry.get("damage_type", "")
		if not damage_type is String:
			return null
		symbol.damage_type = damage_type
		card.symbols.append(symbol)
	return card


## Godot's JSON parser returns every number as a float.
static func _is_integer(value: Variant) -> bool:
	return (value is int or value is float) and value == floor(value)


static func _is_text(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for text: Variant in value.values():
		if not text is String:
			return false
	return true
