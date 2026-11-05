class_name CardDatabase
extends RefCounted
## The playing cards from a JSON file (cards/cards.schema.json describes the format),
## looked up by the value of their QR code.

const SCHEMA_VERSION := 2
const FALLBACK_LOCALE := "de"

## Why the file or some of its cards could not be loaded, empty if everything loaded.
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


## Returns the card with this QR code, or null if there is none.
func find(qr: String) -> Card:
	return _cards_by_qr.get(qr)


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
	var json := JSON.new()
	if json.parse(text) != OK:
		# Godot counts the lines of JSON errors from 0.
		error = "line %d: %s" % [json.get_error_line() + 1, json.get_error_message()]
		return
	var document: Variant = json.data
	if not document is Dictionary or document.get("schema_version") != SCHEMA_VERSION:
		error = "Expected schema version %d" % SCHEMA_VERSION
		return
	var entries: Variant = document.get("cards")
	if not entries is Array:
		error = "No cards found"
		return
	# A bad card only costs that card, the status line reports it.
	var problems := PackedStringArray()
	for entry: Variant in entries:
		var card := Card.from_data(entry)
		if card == null:
			problems.append("Invalid card: %s" % entry)
		elif _cards_by_qr.has(card.qr):
			problems.append("QR code used by two cards: %s" % card.qr)
		else:
			_cards_by_qr[card.qr] = card
	if not problems.is_empty():
		error = "%d card(s) skipped. %s" % [problems.size(), problems[0]]
