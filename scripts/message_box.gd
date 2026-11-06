class_name MessageBox
extends Control
## Shows messages (see Messages) large over the fight, one at a time, each until the
## players tap the check mark. That is how they confirm that they read it and did what it
## says. Messages that arrive meanwhile wait in line.

## A message was confirmed. The next one, if any, follows.
signal confirmed(id: String)
## The last message waiting was confirmed.
signal all_confirmed

const FADE_SEC := 0.2
## Taps this soon after a message appears do not count, so that a double tap does not
## close the next message, unread.
const CONFIRM_DELAY_SEC := 0.4

## What waits, oldest first, as [id, values]. The first one is on screen.
var queue: Array[Array] = []

var _hold_until := 0.0
var _tween: Tween

@onready var _panel: Control = $Margin/Panel
@onready var _title: RichTextLabel = $Margin/Panel/Margin/Layout/Title
@onready var _body: RichTextLabel = $Margin/Panel/Margin/Layout/Body
@onready var _confirm: BaseButton = $Margin/Panel/Margin/Layout/Confirm
@onready var _sound: AudioStreamPlayer = $Sound


func _ready() -> void:
	hide()
	_confirm.pressed.connect(confirm)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and is_showing():
		_refresh_text()


## Shows a message now, or after the ones already waiting. values fill in its
## placeholders, as in Messages.render.
func tell(id: String, values := {}) -> void:
	queue.append([id, values])
	if queue.size() == 1:
		_show_first()


## Whether a message is on screen, or about to be.
func is_showing() -> bool:
	return not queue.is_empty()


## The id of the message on screen, or "".
func current() -> String:
	return queue[0][0] if is_showing() else ""


## Keeps messages back for a while, such as while the fight is introduced.
func hold(seconds: float) -> void:
	_hold_until = maxf(_hold_until, _now() + seconds)


## Closes the message on screen, as the check mark does.
func confirm() -> void:
	if not is_showing() or _confirm.disabled:
		return
	var id: String = queue.pop_front()[0]
	confirmed.emit(id)
	if is_showing():
		_show_first()
	else:
		_fade_out()
		all_confirmed.emit()


func _show_first() -> void:
	_stop_tween()
	_confirm.disabled = true
	var wait := _hold_until - _now()
	if wait > 0.0:
		hide()
		_tween = create_tween()
		_tween.tween_interval(wait)
		_tween.tween_callback(_show_first)
		return
	_refresh_text()
	var already_open := visible and modulate.a > 0.0
	show()
	_panel.pivot_offset = _panel.size / 2.0
	_tween = create_tween().set_parallel()
	if already_open:
		_panel.modulate.a = 0.0
		_tween.tween_property(_panel, "modulate:a", 1.0, FADE_SEC)
	else:
		modulate.a = 0.0
		_panel.modulate.a = 1.0
		_panel.scale = Vector2(0.9, 0.9)
		_tween.tween_property(self, "modulate:a", 1.0, FADE_SEC)
		_tween.tween_property(_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func() -> void: _confirm.disabled = false).set_delay(CONFIRM_DELAY_SEC)
	_sound.play()


func _refresh_text() -> void:
	var locale := TranslationServer.get_locale()
	var text := Messages.render(queue[0][0], queue[0][1], locale, _symbol_size(_body))
	# The title is larger, and so are its symbols.
	var title := Messages.to_bbcode(Messages.find(queue[0][0], locale).get("title", ""), queue[0][1], locale, _symbol_size(_title))
	_title.text = "[center]%s[/center]" % title
	_title.visible = not text.title.is_empty()
	_body.text = "[center]%s[/center]" % text.body


func _fade_out() -> void:
	_stop_tween()
	_confirm.disabled = true
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SEC)
	_tween.tween_callback(hide)


## Symbols as tall as the text around them, a little larger.
func _symbol_size(label: RichTextLabel) -> int:
	return roundi(label.get_theme_font_size("normal_font_size") * 1.15)


func _stop_tween() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
