class_name TomlParser
extends RefCounted
## Reads TOML, which Godot has no built-in support for. Covers what the game's data
## files use: tables, arrays of tables, dotted keys, all four string kinds, integers,
## floats, booleans, arrays and inline tables.
##
## Anything else (dates, hex numbers, inf, nan) and reopening a table that already
## exists are reported as errors, even though some of them are valid TOML.

var error := ""

var _text := ""
var _pos := 0
var _line := 1


## Returns the parsed document. On invalid input returns {} and sets [member error].
func parse(text: String) -> Dictionary:
	error = ""
	_text = text.replace("\r\n", "\n")
	_pos = 0
	_line = 1
	var root := {}
	var table := root
	while error.is_empty():
		_skip_blank()
		if _at_end():
			break
		if _peek() == "[":
			table = _parse_header(root)
		else:
			_parse_key_value(table)
		_expect_line_end()
	return root if error.is_empty() else {}


func _parse_header(root: Dictionary) -> Dictionary:
	var is_array := _text.substr(_pos, 2) == "[["
	_pos += 2 if is_array else 1
	var path := _parse_key()
	_skip_spaces()
	var closing := "]]" if is_array else "]"
	if not _consume(closing):
		_fail("expected '%s'" % closing)
		return root
	var parent := _walk(root, path.slice(0, -1))
	var key: String = path[-1]
	if is_array:
		if not parent.has(key):
			parent[key] = []
		if not parent[key] is Array:
			_fail("'%s' is not an array of tables" % key)
			return root
		var entry := {}
		parent[key].append(entry)
		return entry
	if parent.has(key):
		_fail("'%s' is defined twice" % key)
		return root
	var new_table := {}
	parent[key] = new_table
	return new_table


## Follows a path of tables, creating missing ones. An array of tables stands for its
## newest entry.
func _walk(table: Dictionary, path: Array) -> Dictionary:
	var current := table
	for key: String in path:
		if not current.has(key):
			current[key] = {}
		var next: Variant = current[key]
		if next is Array and not next.is_empty():
			next = next[-1]
		if not next is Dictionary:
			_fail("'%s' is not a table" % key)
			return {}
		current = next
	return current


func _parse_key_value(table: Dictionary) -> void:
	var path := _parse_key()
	_skip_spaces()
	if not _consume("="):
		_fail("expected '='")
		return
	_skip_spaces()
	var value: Variant = _parse_value()
	if not error.is_empty():
		return
	var parent := _walk(table, path.slice(0, -1))
	var key: String = path[-1]
	if error.is_empty() and parent.has(key):
		_fail("'%s' is defined twice" % key)
		return
	parent[key] = value


## Returns the parts of a possibly dotted key.
func _parse_key() -> Array:
	var parts := []
	while true:
		_skip_spaces()
		var quote := _peek()
		if quote == "\"" or quote == "'":
			parts.append(_parse_string())
		else:
			var start := _pos
			while not _at_end() and _is_bare_key_char(_peek()):
				_pos += 1
			if _pos == start:
				_fail("expected a key")
				return [""]
			parts.append(_text.substr(start, _pos - start))
		_skip_spaces()
		if not _consume("."):
			return parts
	return parts


func _is_bare_key_char(c: String) -> bool:
	return c == "_" or c == "-" or (c >= "0" and c <= "9") or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z")


func _parse_value() -> Variant:
	match _peek():
		"\"", "'":
			return _parse_string()
		"[":
			return _parse_array()
		"{":
			return _parse_inline_table()
	return _parse_scalar()


func _parse_scalar() -> Variant:
	var start := _pos
	while not _at_end() and not _peek() in [",", "]", "}", "\n", "#", " ", "\t"]:
		_pos += 1
	var token := _text.substr(start, _pos - start)
	if token == "true":
		return true
	if token == "false":
		return false
	var number := token.replace("_", "")
	if number.is_valid_int():
		return number.to_int()
	if number.is_valid_float():
		return number.to_float()
	_fail("unsupported value '%s'" % token)
	return null


func _parse_array() -> Array:
	var result := []
	_pos += 1
	while error.is_empty():
		_skip_blank()
		if _consume("]"):
			return result
		result.append(_parse_value())
		_skip_blank()
		if not _consume(",") and _peek() != "]":
			_fail("expected ',' or ']'")
	return result


func _parse_inline_table() -> Dictionary:
	var result := {}
	_pos += 1
	_skip_spaces()
	if _consume("}"):
		return result
	while error.is_empty():
		_parse_key_value(result)
		_skip_spaces()
		if _consume("}"):
			return result
		if not _consume(","):
			_fail("expected ',' or '}'")
	return result


func _parse_string() -> String:
	var quote := _peek()
	var is_basic := quote == "\""
	var delimiter := quote.repeat(3) if _text.substr(_pos, 3) == quote.repeat(3) else quote
	var is_multiline := delimiter.length() == 3
	_pos += delimiter.length()
	if is_multiline and _peek() == "\n":
		_pos += 1
		_line += 1
	var result := ""
	while not _at_end():
		if _consume(delimiter):
			return result
		var c := _peek()
		if c == "\n":
			if not is_multiline:
				break
			_line += 1
		if is_basic and c == "\\":
			_pos += 1
			result += _parse_escape()
			if not error.is_empty():
				return ""
			continue
		result += c
		_pos += 1
	_fail("unterminated string")
	return ""


func _parse_escape() -> String:
	var c := _peek()
	_pos += 1
	match c:
		"b":
			return "\b"
		"t":
			return "\t"
		"n":
			return "\n"
		"f":
			return "\f"
		"r":
			return "\r"
		"\"":
			return "\""
		"\\":
			return "\\"
		"u", "U":
			var digits := 4 if c == "u" else 8
			var hex := _text.substr(_pos, digits)
			if hex.length() == digits and hex.is_valid_hex_number():
				_pos += digits
				return String.chr(hex.hex_to_int())
		" ", "\t", "\n":
			# A backslash at the end of a line removes the line break and the indent after it.
			_pos -= 1
			_skip_blank_without_comments()
			return ""
	_fail("invalid escape sequence")
	return ""


func _skip_spaces() -> void:
	while _peek() == " " or _peek() == "\t":
		_pos += 1


func _skip_blank_without_comments() -> void:
	while _peek() in [" ", "\t", "\n"] and not _at_end():
		if _peek() == "\n":
			_line += 1
		_pos += 1


## Skips whitespace, line breaks and comments.
func _skip_blank() -> void:
	while not _at_end():
		_skip_blank_without_comments()
		if _peek() != "#":
			return
		while not _at_end() and _peek() != "\n":
			_pos += 1


func _expect_line_end() -> void:
	if not error.is_empty():
		return
	_skip_spaces()
	if _peek() == "#":
		return
	if not _at_end() and _peek() != "\n":
		_fail("expected a line break")


func _consume(expected: String) -> bool:
	if _text.substr(_pos, expected.length()) == expected:
		_pos += expected.length()
		return true
	return false


func _peek() -> String:
	return _text[_pos] if _pos < _text.length() else ""


func _at_end() -> bool:
	return _pos >= _text.length() or not error.is_empty()


func _fail(message: String) -> void:
	if error.is_empty():
		error = "line %d: %s" % [_line, message]
