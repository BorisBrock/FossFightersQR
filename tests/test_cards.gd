extends SceneTree
## Card database checks.
## Run with: godot --headless -s tests/test_cards.gd

const EXPECTED_CHECKS := 28

var _failures := 0
var _checks_run := 0


func _initialize() -> void:
	_check_database()
	_check_localized()
	_check_bad_databases()
	_check(_checks_run == EXPECTED_CHECKS - 1, "all checks ran")
	print("test_cards: %s" % ("PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _check_database() -> void:
	var database := CardDatabase.load_file("res://tests/fixtures/cards.json")
	_check(database.error.is_empty(), "loads the fixture: '%s'" % database.error)
	_check(database.size() == 2, "has both cards")

	var full := database.find("FULL")
	_check(full != null and full.deck == "core", "finds a card by its QR code")
	_check(typeof(full.level) == TYPE_INT and full.level == 3, "reads the level as an integer")
	_check(full.symbols.size() == 2 and full.symbols[1].type == "support" and typeof(full.symbols[1].strength) == TYPE_INT and full.symbols[1].strength == 1, "reads symbols")
	_check(full.effect.get("de") == "Füge einem Ziel 3 Schaden zu.\nBrennt es, sagt es \"au\"", "reads a multi-line text ending in a quote")

	var minimal := database.find("MINIMAL")
	_check(minimal != null, "reads a card with only the required fields")
	_check(minimal.level == 0 and minimal.title.is_empty() and minimal.effect.is_empty() and minimal.symbols.is_empty(), "optional fields stay empty")
	_check(database.find("full") == null, "QR codes are case sensitive")
	_check(database.find("") == null, "an empty code matches nothing")

	var catalog := CardDatabase.load_file("res://cards/cards.json")
	_check(catalog.error.is_empty() and catalog.size() > 0, "loads the real catalog: '%s'" % catalog.error)


func _check_localized() -> void:
	var text := { "en": "english", "de": "deutsch", "pt-BR": "brasileiro" }
	_check(CardDatabase.localized(text, "en_US") == "english", "uses the language of a regional locale")
	_check(CardDatabase.localized(text, "de") == "deutsch", "uses a plain language")
	_check(CardDatabase.localized(text, "pt_BR") == "brasileiro", "prefers the exact region")
	_check(CardDatabase.localized(text, "fr_FR") == "deutsch", "falls back to German")


func _check_bad_databases() -> void:
	var version_error := _load_text("{\"schema_version\": 1, \"cards\": []}").error
	_check(version_error.contains("schema version"), "rejects another schema version: '%s'" % version_error)
	var syntax_error := _load_text("{\n\"cards\": [").error
	_check(syntax_error.begins_with("line 2:"), "reports the line of a syntax error: '%s'" % syntax_error)

	var cards := "{\"qr\": \"A\", \"deck\": \"core\"}, {\"qr\": \"A\", \"deck\": \"expansion1\"}, {\"qr\": \"B\", \"deck\": \"core\"}"
	var duplicate := _load_text("{\"schema_version\": 2, \"cards\": [%s]}" % cards)
	_check(duplicate.error.contains("two cards"), "reports a duplicate QR code: '%s'" % duplicate.error)
	_check(duplicate.size() == 2 and duplicate.find("A").deck == "core", "keeps the other cards")

	for bad: Variant in [
		"text",
		{ "deck": "core" },
		{ "qr": "A" },
		{ "qr": 1, "deck": "core" },
		{ "qr": "A", "deck": "core", "level": 1.5 },
		{ "qr": "A", "deck": "core", "title": "text" },
		{ "qr": "A", "deck": "core", "effect": { "de": 1 } },
		{ "qr": "A", "deck": "core", "symbols": [{ "type": "attack" }] },
	]:
		_check(Card.from_data(bad) == null, "rejects %s" % [bad])


func _load_text(text: String) -> CardDatabase:
	var path := "user://test_cards.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var database := CardDatabase.load_file(path)
	DirAccess.remove_absolute(path)
	return database


func _check(condition: bool, description: String) -> void:
	_checks_run += 1
	print(("  ok   " if condition else "  FAIL ") + description)
	if not condition:
		_failures += 1
