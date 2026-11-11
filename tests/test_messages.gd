extends SceneTree
## The message files in messages/ and how a message is turned into text for the screen.
## Run with: godot --headless -s tests/test_messages.gd

const EXPECTED_CHECKS := 33
const BAD_PATH := "user://test_messages_bad.json"
## Tags a message may use besides Messages.STYLES. Each has to be closed again.
const BBCODE_TAGS := ["b", "i", "u", "s", "color", "font_size", "bgcolor", "outline_color", "outline_size"]

var _failures := 0
var _checks_run := 0


func _initialize() -> void:
	_check_files()
	_check_render()
	_check_bad_file()
	_check(_checks_run == EXPECTED_CHECKS - 1, "all checks ran: %d" % _checks_run)
	print("test_messages: %s" % ("PASSED" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


## Every language has every message, with the same placeholders, and nothing in them that
## the screen would show as it is.
func _check_files() -> void:
	var languages := PackedStringArray()
	for file in DirAccess.get_files_at(Messages.FOLDER):
		if file.get_extension() == "json":
			languages.append(file.get_basename())
	_check(languages.has("de") and languages.has("en"), "there are messages in German and English: %s" % ", ".join(languages))
	var fallback := Messages.load_language(Messages.FALLBACK_LANGUAGE)
	_check(fallback.has("round_started"), "the fight's own messages are there")

	var problems: Array[String] = []
	for language in languages:
		var path := Messages.FOLDER + language + ".json"
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var messages := Messages.load_language(language)
		if messages.size() != raw.size():
			problems.append("%s: %d messages could not be read" % [path, raw.size() - messages.size()])
		for id: String in fallback:
			if not messages.has(id):
				problems.append("%s: '%s' is missing" % [language, id])
		for id: String in messages:
			var message: Dictionary = messages[id]
			var text := _all_text(message)
			if not fallback.has(id):
				problems.append("%s: '%s' is not in %s" % [language, id, Messages.FALLBACK_LANGUAGE])
			elif _sorted(Messages.placeholders(text)) != _sorted(Messages.placeholders(_all_text(fallback[id]))):
				problems.append("%s: '%s' has other placeholders than in %s" % [language, id, Messages.FALLBACK_LANGUAGE])
			elif message.get("auto", false) != fallback[id].get("auto", false):
				problems.append("%s: '%s' closes by itself in one language but not in another" % [language, id])
			if message.body.strip_edges().is_empty():
				problems.append("%s: '%s' has no body" % [language, id])
			if message.has("title") and message.title.strip_edges().is_empty():
				problems.append("%s: '%s' has an empty title, leave it out instead" % [language, id])
			for symbol in Messages.symbols(text):
				if not Messages.SYMBOLS.has(symbol):
					problems.append("%s: '%s' has an unknown symbol :%s:" % [language, id, symbol])
			var tag_problem := _tag_problem(text)
			if not tag_problem.is_empty():
				problems.append("%s: '%s' %s" % [language, id, tag_problem])
	_check(problems.is_empty(), "the message files are complete and well formed%s" % "".join(problems.map(func(p: String) -> String: return "\n         " + p)))

	var missing := Messages.SYMBOLS.values().filter(func(path: String) -> bool: return not ResourceLoader.exists(path))
	_check(missing.is_empty(), "every symbol has its icon: %s" % ", ".join(missing))


func _check_render() -> void:
	var render := Messages.to_bbcode
	_check(render.call("Hit {player} for {damage}.", { "player": "Sonja", "damage": 5 }) == "Hit Sonja for 5.", "fills in placeholders, also numbers")
	_check(render.call("{player} and {player}", { "player": "Bo" }) == "Bo and Bo", "fills in a placeholder used twice")
	_check(render.call("{boss}", { "boss": { "de": "Kröte", "en": "Toad" } }, "en") == "Toad", "fills in text in the language shown")
	_check(render.call("Hit {player}.") == "Hit {player}.", "leaves a placeholder without a value as it is")
	_check(render.call("{a}", { "a": "[b]x[/b] {b} :health:", "b": "no" }) == "[lb]b]x[lb]/b] {b} :health:", "shows a value as it is, never as markup")
	_check(render.call("[damage]5[/damage]") == "%s5%s" % Messages.STYLES.damage, "replaces styles")
	_check(render.call("[b][i]x[/i][/b] [color=red]y[/color]") == "[b][i]x[/i][/b] [color=red]y[/color]", "keeps BBCode")
	_check(render.call("lose 1 :health:!", {}, "en", 40) == "lose 1 [img width=40 height=40]%s[/img]!" % Messages.SYMBOLS.health, "draws symbols at the size asked for")
	_check(render.call("at 10:30:00 :nothing:") == "at 10:30:00 :nothing:", "leaves colons that are no symbol alone")

	var parts := [["part_hit", { "player": "[b]Bo", "damage": 3 }], ["part_hit", { "player": "Sonja", "damage": 1 }]]
	var lines: PackedStringArray = render.call("{boss}:\n{hits}", { "boss": "Toad", "hits": parts }, "en").split("\n")
	_check(lines.size() == 3 and lines[1].begins_with(Messages.STYLES.player[0] + "[lb]b]Bo") and "Sonja" in lines[2], "fills in a list of parts, one line each, their values shown as they are")

	# Numbers read from JSON are floats, even when written as 1: they must never show as 1.0.
	var from_json: Dictionary = JSON.parse_string("{ \"count\": 1, \"damage\": 12 }")
	_check(render.call("Draw {count} cards, take {damage}.", from_json) == "Draw 1 cards, take 12.", "shows numbers read from JSON as whole numbers")
	_check(render.call("{a} {b} {c}", { "a": 2.0, "b": -3.0, "c": 0.0 }) == "2 -3 0", "shows floats as whole numbers")
	var float_parts := [["part_hit", { "player": "Bo", "damage": 3.0 }]]
	var part_text: String = render.call("{hits}", { "hits": float_parts }, "en")
	_check("3" in part_text and not "3.0" in part_text, "shows floats in parts as whole numbers: %s" % part_text)

	var values := { "round": 3, "boss": "Toad" }
	var round := Messages.render("round_started", values, "en")
	_check(round.title == "Round 3" and not round.body.is_empty(), "renders a message by its id")
	_check(Messages.render("round_started", values, "de_AT").title == "Runde 3", "in the language of the locale")
	_check(Messages.render("round_started", values, "fr_FR").title == "Runde 3", "and in German for a language without messages")
	_check(Messages.is_auto("boss_taunt") and Messages.is_auto("round_started") and not Messages.is_auto("first_round") and not Messages.is_auto("round_end_status") and not Messages.is_auto("no_such_message"), "knows which messages close by themselves")
	_check(Messages.render("example_reminder", {}, "en").title == "", "a message may have no title")
	_check(Messages.has("round_started") and not Messages.has("no_such_message"), "knows which messages there are")
	var card := { "title": { "de": "Himmelspaladin", "en": "Celestial Paladin" }, "hero": "[b]Rosie" }
	_check(Messages.heading("example_reminder", {}, "en") == { "title": "", "kicker": "" }, "a message without a title or source has no heading")
	_check(Messages.heading("example_reminder", { "source": card }, "de") == { "title": "Himmelspaladin", "kicker": "[lb]b]Rosie" }, "one without a title takes the name of its source, its hero above, as they are")
	_check(Messages.heading("victory", { "source": { "title": { "en": "Old Mirefang" } } }, "en") == { "title": "Victory!", "kicker": "Old Mirefang" }, "one with a title keeps it, its source above")
	_check(Messages.heading("victory", { "source": card }, "en").kicker == "[lb]b]Rosie · Celestial Paladin", "with its hero")


func _check_bad_file() -> void:
	var file := FileAccess.open(BAD_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"good": { "title": "T", "body": ["one", "two"] },
		"no_body": { "title": "T" },
		"number_body": { "body": 5 },
		"typo": { "body": "x", "titel": "T" },
		"not_an_object": "x",
		"auto": { "body": "x", "auto": true },
		"bad_auto": { "body": "x", "auto": "yes" },
	}))
	file.close()
	var messages := Messages.read_file(BAD_PATH)
	_check(messages.size() == 2 and messages.has("good") and messages.has("auto"), "skips messages with mistakes: %s" % ", ".join(messages.keys()))
	_check(messages.auto.auto and not messages.good.has("auto"), "reads which close by themselves")
	_check(messages.good.body == "one\ntwo", "joins a body of several lines")
	_check(Messages.read_file("user://no_such_file.json").is_empty(), "a missing file has no messages")
	file = FileAccess.open(BAD_PATH, FileAccess.WRITE)
	file.store_string("{ \"broken\": ")
	file.close()
	_check(Messages.read_file(BAD_PATH).is_empty(), "a broken file has no messages")
	DirAccess.remove_absolute(BAD_PATH)


## Other languages may put the placeholders in another order.
func _sorted(names: PackedStringArray) -> PackedStringArray:
	names.sort()
	return names


func _all_text(message: Dictionary) -> String:
	return message.get("title", "") + "\n" + message.body


## Every tag opened is closed, in order, so that nothing spills into the next words.
func _tag_problem(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("\\[(/?)([a-z_]+)(=[^\\]]*)?\\]")
	var open: Array[String] = []
	for found in regex.search_all(text):
		var tag := found.get_string(2)
		if not Messages.STYLES.has(tag) and not BBCODE_TAGS.has(tag):
			return "has an unknown tag [%s]" % tag
		if found.get_string(1).is_empty():
			open.append(tag)
		elif open.is_empty() or open.pop_back() != tag:
			return "closes [%s] out of order" % tag
	return "" if open.is_empty() else "never closes [%s]" % open[-1]


func _check(condition: bool, description: String) -> void:
	_checks_run += 1
	print(("  ok   " if condition else "  FAIL ") + description)
	if not condition:
		_failures += 1
