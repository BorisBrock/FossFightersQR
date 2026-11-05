class_name CardDatabase
extends RefCounted
## The playing cards from a TOML file (cards/cards.schema.json describes the format),
## looked up by the value of their QR code.

const FALLBACK_LOCALE := "en"

## Why loading failed, empty if it worked.
var error := ""

var _cards_by_qr := {}


static func load_file(path: String) -> CardDatabase:
	var database := CardDatabase.new()
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		database.error = "Cannot read %s" % path
	else:
		database._read(text)
	if not database.error.is_empty():
		push_error("Card database: ", database.error)
	return database


## Returns the card with this QR code, or {} if there is none.
func find(qr: String) -> Dictionary:
	return _cards_by_qr.get(qr, {})


func size() -> int:
	return _cards_by_qr.size()


## Picks the text for a locale such as "de_DE": the exact match, then the language,
## then the fallback.
static func localized(text: Dictionary, locale: String) -> String:
	var parts := locale.split("_")
	var language := parts[0]
	var regional := "%s-%s" % [language, parts[-1]]
	return text.get(regional, text.get(language, text.get(FALLBACK_LOCALE, "")))


func _read(text: String) -> void:
	var parser := TomlParser.new()
	var document := parser.parse(text)
	if not parser.error.is_empty():
		error = parser.error
		return
	var cards: Variant = document.get("card")
	if not cards is Array:
		error = "No cards found"
		return
	for card: Dictionary in cards:
		var qr: Variant = card.get("qr")
		if not qr is String or not card.get("title") is Dictionary:
			error = "Card without qr or title: %s" % card
			return
		if _cards_by_qr.has(qr):
			error = "QR code used by two cards: %s" % qr
			return
		_cards_by_qr[qr] = card
