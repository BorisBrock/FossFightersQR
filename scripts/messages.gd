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
##
## A message marked "auto" asks nothing of the players, so it closes by itself after a
## while (see MessageBox). One marked "animation" goes with an animation on screen, which
## closes it. Any other waits until the players confirm it.

const FOLDER := "res://messages/"
## A language without a file, or a message missing from it, falls back to this.
const FALLBACK_LANGUAGE := CardDatabase.FALLBACK_LOCALE

## The icons that can be written as :name: in a message.
const SYMBOLS := {
	"health": "res://assets/fight/icon_health.png",
	"round": "res://assets/fight/icon_round.png",
	"damage": "res://assets/fight/icon_damage.png",
	"claw": "res://assets/fight/icon_claw.png",
	"poison": "res://assets/fight/icon_poison.png",
	"card": "res://assets/fight/icon_card.png",
	"dice": "res://assets/onboarding/icons/dice.png",
	"melee": "res://assets/fight/icon_melee.png",
	"ranged": "res://assets/fight/icon_ranged.png",
	"magic": "res://assets/fight/icon_magic.png",
	"melee_support": "res://assets/fight/icon_melee_support.png",
	"ranged_support": "res://assets/fight/icon_ranged_support.png",
	"magic_support": "res://assets/fight/icon_magic_support.png",
	"protection": "res://assets/fight/icon_protection.png",
	"lightning": "res://assets/fight/icon_lightning.png",
	"fire": "res://assets/fight/icon_fire.png",
	"panic": "res://assets/fight/icon_panic.png",
	"paralysis": "res://assets/fight/icon_paralysis.png",
	"totem": "res://assets/fight/icon_totem.png",
}

## Tags for what comes up again and again, so that it looks the same in every message.
## Each is the BBCode it stands for, opening and closing.
const STYLES := {
	"player": ["[b][color=#ffd27a]", "[/color][/b]"],
	"boss": ["[b][color=#ff9a5c]", "[/color][/b]"],
	"damage": ["[b][color=#ff5a4a]", "[/color][/b]"],
	"heal": ["[b][color=#7fe07a]", "[/color][/b]"],
	"poison": ["[b][color=#b6e04a]", "[/color][/b]"],
	## What the boss says, such as its taunt: in its own voice, apart from the instructions.
	"taunt": ["[i][color=#ff8070]", "[/color][/i]"],
}

static var _files := {}
static var _placeholder := _regex("\\{([a-z0-9_]+)\\}")
static var _symbol := _regex(":([a-z0-9_]+):")
static var _style := _regex("\\[(/?)([a-z_]+)\\]")


## The text of a message, ready for a RichTextLabel with BBCode on: { "title": …,
## "body": … }. The title is "" if the message has none. values fill in the placeholders,
## either as they are or, for a { "de": …, "en": … } dictionary, in the language shown.
## A value can also be a list of parts, each [id, values] of another message, whose
## bodies are filled in one per line, such as one line per hero.
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


## The heading of a message, as BBCode: { "title": …, "kicker": … }, each "" if it has
## none. The kicker is the small line above the title that says where the message comes
## from, from values.source (see Fight.source()): { "title": …, "hero": … }.
## - A message with a title of its own keeps it, and the kicker names the source, such as
##   the boss whose armour weakens an attack, with its hero, if any.
## - A message without one, such as a heal, takes the source's name as its title, such as
##   the card or class that heals, and the kicker names its hero.
static func heading(id: String, values := {}, locale := TranslationServer.get_locale(), symbol_size := 32) -> Dictionary:
	var title := to_bbcode(find(id, locale).get("title", ""), values, locale, symbol_size)
	var source: Variant = values.get("source", {})
	if not source is Dictionary:
		source = {}
	var hero := _escape(_text_of(source.get("hero", ""), locale))
	var from := _escape(_text_of(source.get("title", ""), locale))
	if title.is_empty():
		return { "title": from, "kicker": hero if not from.is_empty() else "" }
	var names := PackedStringArray([hero, from])
	return { "title": title, "kicker": " · ".join(Array(names).filter(func(name: String) -> bool: return not name.is_empty())) }


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


## Whether the message closes by itself, as it asks nothing of the players. The same in
## every language, so it is read from the fallback.
static func is_auto(id: String) -> bool:
	return find(id, FALLBACK_LANGUAGE).get("auto", false)


## Whether the message goes with an animation on screen, such as the boss planning its
## attacks: it has no check mark, and the screen closes it once the animation is done
## (MessageBox.finish()).
static func is_animated(id: String) -> bool:
	return find(id, FALLBACK_LANGUAGE).get("animation", false)


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
		for flag: String in ["auto", "animation"]:
			if entry.get(flag, false):
				message[flag] = true
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
			if value is Array:
				result += _parts(value, locale, symbol_size)
			else:
				result += _escape(_text_of(value, locale))
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
		result += "[img width=%d height=%d]%s[/img]" % [symbol_size, symbol_size, path]
		start = found.get_end()
	return result + text.substr(start)


## Each part, [id, values] of a message, as the BBCode of its body, one per line.
static func _parts(parts: Array, locale: String, symbol_size: int) -> String:
	var lines := PackedStringArray()
	for part: Variant in parts:
		if not part is Array or part.size() != 2 or not part[0] is String or not part[1] is Dictionary:
			push_error("A message part has to be [id, values], not %s" % [part])
			continue
		var entry := find(part[0], locale)
		if entry.is_empty():
			push_error("No message '%s'" % part[0])
			lines.append(_escape(part[0]))
		else:
			lines.append(to_bbcode(entry.body, part[1], locale, symbol_size))
	return "\n".join(lines)


## A placeholder's value as text. Numbers are always shown as whole numbers: a value read
## from JSON is a float even when it is written as 1, and would show as "1.0".
static func _text_of(value: Variant, locale: String) -> String:
	if value is Dictionary:
		return CardDatabase.localized(value, locale)
	if value is float:
		if not is_equal_approx(value, roundf(value)):
			push_warning("Message value %s is no whole number, rounded" % value)
		return str(roundi(value))
	return str(value)


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
	if entry.has("animation") and not entry.animation is bool:
		return "animation has to be true or false"
	if entry.has("auto") and not entry.auto is bool:
		return "auto has to be true or false"
	for key: String in entry:
		if not key in ["title", "body", "auto", "animation"]:
			return "unknown field '%s'" % key
	return ""


static func _regex(pattern: String) -> RegEx:
	var regex := RegEx.new()
	regex.compile(pattern)
	return regex
