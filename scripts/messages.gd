class_name Messages
extends RefCounted
## The messages that guide the players through a fight: instructions, notifications and
## reminders. Their text lives in messages/<language>.json, one file per language, and the
## game refers to each message by its id. See docs/messages.md for the format.
##
## A message has an optional title and a body. Both may contain:
## - placeholders such as {player}, filled in from the values the game passes,
## - BBCode, such as [b]bold[/b], [i]italic[/i] or [color=#ff0000]red[/color],
## - the styles below, such as [damage]5 damage[/damage],
## - symbols such as :poison:, drawn inline as an icon.

const FOLDER := "res://messages/"
## A language without a file, or a message missing from it, falls back to this.
const FALLBACK_LANGUAGE := CardDatabase.FALLBACK_LOCALE

## The icons that can be written as :name: in a message.
const SYMBOLS := {
	"health": "res://assets/fight/icon_health.svg",
	"round": "res://assets/fight/icon_round.svg",
	"damage": "res://assets/fight/icon_damage.svg",
	"poison": "res://assets/fight/icon_poison.svg",
	"card": "res://assets/fight/icon_card.svg",
	"dice": "res://assets/onboarding/icons/dice.svg",
}

## Tags for what comes up again and again, so that it looks the same in every message.
## Each is the BBCode it stands for, opening and closing.
const STYLES := {
	"player": ["[b][color=#ffd27a]", "[/color][/b]"],
	"boss": ["[b][color=#ff9a5c]", "[/color][/b]"],
	"damage": ["[b][color=#ff5a4a]", "[/color][/b]"],
	"heal": ["[b][color=#7fe07a]", "[/color][/b]"],
	"poison": ["[b][color=#b6e04a]", "[/color][/b]"],
}

static var _files := {}
static var _placeholder := _regex("\\{([a-z0-9_]+)\\}")
static var _symbol := _regex(":([a-z0-9_]+):")
static var _style := _regex("\\[(/?)([a-z_]+)\\]")


## The text of a message, ready for a RichTextLabel with BBCode on: { "title": …,
## "body": … }. The title is "" if the message has none. values fill in the placeholders,
## either as they are or, for a { "de": …, "en": … } dictionary, in the language shown.
## symbol_size is the height of the symbols in pixels, best about that of the text.
static func render(id: String, values := {}, locale := TranslationServer.get_locale(), symbol_size := 32) -> Dictionary:
	var entry := find(id, locale)
	if entry.is_empty():
		push_error("No message '%s'" % id)
		return { "title": "", "body": _escape(id) }
	return {
		"title": to_bbcode(entry.get("title", ""), values, locale, symbol_size),
		"body": to_bbcode(entry.body, values, locale, symbol_size),
	}


## The message as written in its file, in the language of locale or the fallback:
## { "body": … } and maybe "title". Empty if no language has it.
static func find(id: String, locale := TranslationServer.get_locale()) -> Dictionary:
	for language: String in [locale.split("_")[0], FALLBACK_LANGUAGE]:
		var messages := load_language(language)
		if messages.has(id):
			return messages[id]
	return {}


static func has(id: String) -> bool:
	return not find(id, FALLBACK_LANGUAGE).is_empty()


## Every message of a language by its id, with the body as one string. Empty if the
## language has no file. Files are read once.
static func load_language(language: String) -> Dictionary:
	if not _files.has(language):
		_files[language] = read_file(FOLDER + language + ".json")
	return _files[language]


## Forgets the files read, so that the next message reads them again.
static func reload() -> void:
	_files.clear()


## Reads one file of messages. Mistakes in it are reported and the message skipped.
static func read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_error("%s, line %d: %s" % [path, json.get_error_line() + 1, json.get_error_message()])
		return {}
	if not json.data is Dictionary:
		push_error("%s: expected an object of messages by id" % path)
		return {}
	var messages := {}
	for id: String in json.data:
		var entry: Variant = json.data[id]
		var problem := _problem(entry)
		if not problem.is_empty():
			push_error("%s, message '%s': %s" % [path, id, problem])
			continue
		var body: Variant = entry.body
		var message := { "body": "\n".join(body) if body is Array else body }
		if entry.has("title"):
			message.title = entry.title
		messages[id] = message
	return messages


## Turns the text of a message into BBCode: fills in the placeholders and replaces the
## styles and symbols. A placeholder without a value stays as it is, to be noticed.
static func to_bbcode(text: String, values := {}, locale := TranslationServer.get_locale(), symbol_size := 32) -> String:
	var result := ""
	var start := 0
	# Placeholders last and in one go, so that a value, such as a hero's name, is shown
	# as it is and never read as markup or as another placeholder.
	for found in _placeholder.search_all(text):
		result += _markup(text.substr(start, found.get_start() - start), symbol_size)
		var key := found.get_string(1)
		if values.has(key):
			var value: Variant = values[key]
			result += _escape(CardDatabase.localized(value, locale) if value is Dictionary else str(value))
		else:
			push_warning("Message placeholder {%s} has no value" % key)
			result += found.get_string()
		start = found.get_end()
	return result + _markup(text.substr(start), symbol_size)


## The names of the placeholders in a text, each once, in order.
static func placeholders(text: String) -> PackedStringArray:
	var names := PackedStringArray()
	for found in _placeholder.search_all(text):
		if not names.has(found.get_string(1)):
			names.append(found.get_string(1))
	return names


## The :names: in a text that look like symbols, known or not, each once.
static func symbols(text: String) -> PackedStringArray:
	var names := PackedStringArray()
	for found in _symbol.search_all(text):
		if not names.has(found.get_string(1)):
			names.append(found.get_string(1))
	return names


static func _markup(text: String, symbol_size: int) -> String:
	var result := ""
	var start := 0
	for found in _style.search_all(text):
		var style: Variant = STYLES.get(found.get_string(2))
		if style == null:
			continue
		result += text.substr(start, found.get_start() - start)
		result += style[1] if found.get_string(1) == "/" else style[0]
		start = found.get_end()
	text = result + text.substr(start)

	result = ""
	start = 0
	for found in _symbol.search_all(text):
		var path: Variant = SYMBOLS.get(found.get_string(1))
		if path == null:
			continue
		result += text.substr(start, found.get_start() - start)
		result += "[img=center width=%d height=%d]%s[/img]" % [symbol_size, symbol_size, path]
		start = found.get_end()
	return result + text.substr(start)


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")


static func _problem(entry: Variant) -> String:
	if not entry is Dictionary:
		return "expected an object with a body"
	var body: Variant = entry.get("body")
	var body_ok: bool = body is String or (body is Array and body.all(func(line: Variant) -> bool: return line is String))
	if not body_ok:
		return "the body has to be a text or a list of texts"
	if entry.has("title") and not entry.title is String:
		return "the title has to be a text"
	for key: String in entry:
		if key != "title" and key != "body":
			return "unknown field '%s'" % key
	return ""


static func _regex(pattern: String) -> RegEx:
	var regex := RegEx.new()
	regex.compile(pattern)
	return regex
