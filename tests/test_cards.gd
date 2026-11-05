extends SceneTree
## Card database and TOML parser checks.
## Run with: godot --headless -s tests/test_cards.gd

const EXPECTED_CHECKS := 25

var _failures := 0
var _checks_run := 0


func _initialize() -> void:
	_check_database()
	_check_localized()
	_check_parser()
	_check_bad_databases()
	_check(_checks_run == EXPECTED_CHECKS - 1, "all checks ran")
	print("test_cards: %s" % ("PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _check_database() -> void:
	var database := CardDatabase.load_file("res://cards/cards.toml")
	_check(database.error.is_empty(), "loads cards.toml: '%s'" % database.error)
	_check(database.size() == 2, "has both cards")

	var fireball := database.find("CORE-001")
	_check(fireball.get("name") == "fireball", "finds a card by its QR code")
	_check(fireball.get("level") == 3, "reads the level")
	_check(fireball.get("symbols", []).size() == 2 and fireball.symbols[1] == { "type": "support", "strength": 1 }, "reads symbols")
	_check(fireball.get("effect", {}).get("en") == "Deal 3 damage to a target.\nIf it is burning, deal 5 instead.", "reads a multi-line effect")
	_check(fireball.get("effect", {}).get("de", "").begins_with("Füge"), "reads non-ASCII text")

	var herb := database.find("CORE-002")
	_check(herb.get("title", {}).get("de") == "Heilkraut", "reads a card with only the required fields")
	_check(not herb.has("level") and not herb.has("effect") and not herb.has("symbols"), "optional fields stay absent")
	_check(database.find("core-001").is_empty(), "QR codes are case sensitive")
	_check(database.find("").is_empty(), "an empty code matches nothing")


func _check_localized() -> void:
	var text := { "en": "english", "de": "deutsch", "pt-BR": "brasileiro" }
	_check(CardDatabase.localized(text, "de_DE") == "deutsch", "uses the language of a regional locale")
	_check(CardDatabase.localized(text, "de") == "deutsch", "uses a plain language")
	_check(CardDatabase.localized(text, "pt_BR") == "brasileiro", "prefers the exact region")
	_check(CardDatabase.localized(text, "fr_FR") == "english", "falls back to English")


func _check_parser() -> void:
	var parser := TomlParser.new()
	var parsed := parser.parse("""# comment
a = 1_000 # trailing
b = [1, 2.5, true, 'lit\\n', "t\\tab \\u00e4",]
c.d = { e = "f", g = [ { h = -1 } ] }
"quoted key" = \"\"\"
one \\
    two\"\"\"
[[t]]
x = 1
[t.sub]
y = 2
[[t]]
x = 3
""")
	_check(parser.error.is_empty(), "parses valid TOML: '%s'" % parser.error)
	_check(parsed == {
		"a": 1000,
		"b": [1, 2.5, true, "lit\\n", "t\tab ä"],
		"c": { "d": { "e": "f", "g": [{ "h": -1 }] } },
		"quoted key": "one two",
		"t": [{ "x": 1, "sub": { "y": 2 } }, { "x": 3 }],
	}, "produces the expected values: %s" % parsed)

	for broken: String in ["a = ", "a = 1\na = 2", "a = \"open", "a = 1 b = 2", "[x\ny = 1", "a = 2020-01-01"]:
		parser.parse(broken)
		_check(not parser.error.is_empty(), "rejects '%s': %s" % [broken.c_escape(), parser.error])


func _check_bad_databases() -> void:
	var path := "user://test_cards.toml"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("[[card]]\nqr = \"A\"\ntitle = { en = \"x\" }\n[[card]]\nqr = \"A\"\ntitle = { en = \"y\" }\n")
	file.close()
	var database := CardDatabase.load_file(path)
	DirAccess.remove_absolute(path)
	_check(database.error.contains("two cards"), "reports a duplicate QR code: '%s'" % database.error)


func _check(condition: bool, description: String) -> void:
	_checks_run += 1
	print(("  ok   " if condition else "  FAIL ") + description)
	if not condition:
		_failures += 1
