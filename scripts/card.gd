class_name Card
extends RefCounted
## One playing card. cards/cards.schema.json describes the data it is made from.


class Symbol:
	var type: String
	var strength: int


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
	if not qr_value is String or qr_value.is_empty() or not deck_value is String:
		return null
	if not _is_integer(level_value) or not _is_text(title_value) or not _is_text(effect_value):
		return null
	if not symbols_value is Array or not race_value is String or not hero_class_value is String:
		return null
	card.qr = qr_value
	card.deck = deck_value
	card.level = int(level_value)
	card.race = race_value
	card.hero_class = hero_class_value
	card.title = title_value
	card.effect = effect_value
	for entry: Variant in symbols_value:
		if not entry is Dictionary or not entry.get("type") is String or not _is_integer(entry.get("strength")):
			return null
		var symbol := Symbol.new()
		symbol.type = entry.type
		symbol.strength = int(entry.strength)
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
