class_name MessageBox
extends Control
## Shows messages (see Messages) large over the fight, one at a time, each until the
## players tap the check mark. That is how they confirm that they read it and did what it
## says. Messages that arrive meanwhile wait in line.
##
## A message that asks nothing of the players (Messages.is_auto) also closes by itself:
## a bar in the check mark runs down, for longer the more there is to read. Tapping the
## message stops it, for those who need more time, and it waits for the check mark again.
##
## A message that goes with an animation (Messages.is_animated), such as the boss planning
## its attacks, has no check mark and leaves the fight undimmed: the screen plays the
## animation when the message shows (shown) and closes it with finish().
##
## Messages show in the top half of the screen, clear of the heroes at the bottom.
##
## Above the body is the heading (Messages.heading): the message's title, or else the name
## of what it comes from, such as the card or class that heals, under a small line naming
## the hero (the kicker), and an ornament.

## A message was confirmed. The next one, if any, follows.
signal confirmed(id: String)
## The last message waiting was confirmed.
signal all_confirmed
## A message is now on screen, such as one whose animation the screen plays now.
signal shown(id: String)

const FADE_SEC := 0.2
## Taps this soon after a message appears do not count, so that a double tap does not
## close the next message, unread.
const CONFIRM_DELAY_SEC := 0.4
## How long a message that closes by itself stays: AUTO_SEC plus AUTO_SEC_PER_WORD for
## each word of it, as it is read out at the table, from AUTO_MIN_SEC to AUTO_MAX_SEC.
## Settings.message_time_factor() makes it longer, or turns it off.
const AUTO_SEC := 2.0
const AUTO_SEC_PER_WORD := 0.4
const AUTO_MIN_SEC := 4.0
const AUTO_MAX_SEC := 15.0
## The space beside a message, and beside one that goes with an animation.
const MARGIN := 28
const ANIMATED_MARGIN := 160
## Messages with a sound of their own (see Sfx), by id. The others play the box's own.
const SOUNDS := {
	"round_started": "round",
	"boss_attacks": "boss_attack",
	"phase_attack_blocked": "protect",
	"health_loss": "hurt",
	"heal": "heal",
	"boss_poison": "poison",
	"poison_burst": "poison",
	"shield_broken_poison": "shield_break",
	"mirefang_poison_shield": "poison",
	"mirefang_spit": "poison",
	"mirefang_surfaces": "boss_attack",
	"victory": "victory",
	"defeat": "defeat",
}

## What waits, oldest first, as [id, values]. The first one is on screen.
var queue: Array[Array] = []

var _hold_until := 0.0
var _tween: Tween
## The time the message on screen has left before it closes by itself, of
## _countdown_total. 0 if it does not, or no longer does.
var _countdown_left := 0.0
var _countdown_total := 0.0
var _default_sound: AudioStream

@onready var _dim: Control = $Dim
@onready var _margin: Control = $Margin
@onready var _panel: Control = $Margin/Panel
@onready var _header: Control = $Margin/Panel/Margin/Layout/Header
@onready var _kicker: RichTextLabel = $Margin/Panel/Margin/Layout/Header/Kicker
@onready var _title: RichTextLabel = $Margin/Panel/Margin/Layout/Header/Title
@onready var _body: RichTextLabel = $Margin/Panel/Margin/Layout/Body
@onready var _confirm: BaseButton = $Margin/Panel/Margin/Layout/Confirm
@onready var _countdown: Control = $Margin/Panel/Margin/Layout/Confirm/Countdown
@onready var _sound: AudioStreamPlayer = $Sound


func _ready() -> void:
	hide()
	_countdown.hide()
	_default_sound = _sound.stream
	_confirm.pressed.connect(confirm)


func _process(delta: float) -> void:
	if _countdown_left <= 0.0:
		return
	# Not while the players are busy with a dialog, such as the settings.
	if not get_tree().get_nodes_in_group(MenuScreen.DIALOG_GROUP).is_empty():
		return
	_countdown_left -= delta
	_countdown.scale.x = maxf(0.0, _countdown_left / _countdown_total)
	if _countdown_left <= 0.0:
		confirm()


## A tap on the message, not on its check mark, stops it from closing by itself.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and is_counting_down():
		stop_countdown()
		accept_event()


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


## Whether the message on screen is about to close by itself.
func is_counting_down() -> bool:
	return _countdown_left > 0.0


## Seconds until the message on screen closes by itself, 0 if it does not.
func countdown_left() -> float:
	return maxf(0.0, _countdown_left)


## The message on screen waits for the check mark, rather than closing by itself.
func stop_countdown() -> void:
	_countdown_left = 0.0
	_countdown.hide()


## How long a message with this text, as shown, stays before it closes by itself.
static func auto_seconds(text: String) -> float:
	var words := text.split(" ", false).size()
	return clampf(AUTO_SEC + AUTO_SEC_PER_WORD * words, AUTO_MIN_SEC, AUTO_MAX_SEC) * Settings.message_time_factor()


## Keeps messages back for a while, such as while the fight is introduced.
func hold(seconds: float) -> void:
	_hold_until = maxf(_hold_until, _now() + seconds)


## Closes the message on screen if it is id, even before it could be confirmed: for a
## message that goes with an animation, once the animation is done.
func finish(id: String) -> void:
	if current() != id:
		return
	_confirm.disabled = false
	confirm()


## Closes the message on screen, as the check mark does.
func confirm() -> void:
	if not is_showing() or _confirm.disabled:
		return
	stop_countdown()
	var id: String = queue.pop_front()[0]
	confirmed.emit(id)
	if is_showing():
		_show_first()
	else:
		_fade_out()
		all_confirmed.emit()


func _show_first() -> void:
	_stop_tween()
	stop_countdown()
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
	_tween.tween_callback(_on_ready_to_confirm).set_delay(CONFIRM_DELAY_SEC)
	_play_sound(current())
	shown.emit(current())


## The message is in view and can be confirmed. One that asks nothing of the players
## starts running down.
func _on_ready_to_confirm() -> void:
	_confirm.disabled = false
	if _confirm.is_visible_in_tree():
		_confirm.pivot_offset = _confirm.size / 2.0
		var pulse := create_tween()
		pulse.tween_property(_confirm, "scale", Vector2(1.08, 1.08), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		pulse.tween_property(_confirm, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not Messages.is_auto(current()) or Messages.is_animated(current()):
		return
	var text := _body.get_parsed_text()
	if _header.visible:
		text = _kicker.get_parsed_text() + " " + _title.get_parsed_text() + " " + text
	var seconds := auto_seconds(text.replace("\n", " "))
	if seconds > 0.0:
		_countdown_total = seconds
		_countdown_left = seconds
		_countdown.scale.x = 1.0
		_countdown.show()


func _play_sound(id: String) -> void:
	_sound.stream = Sfx.stream(SOUNDS[id]) if SOUNDS.has(id) else _default_sound
	_sound.play()


func _refresh_text() -> void:
	var locale := TranslationServer.get_locale()
	var text := Messages.render(queue[0][0], queue[0][1], locale, _symbol_size(_body))
	# The title is larger, and so are its symbols.
	var heading := Messages.heading(queue[0][0], queue[0][1], locale, _symbol_size(_title))
	_title.text = "[center]%s[/center]" % heading.title
	_kicker.text = "[center]%s[/center]" % heading.kicker
	_kicker.visible = not heading.kicker.is_empty()
	_header.visible = not heading.title.is_empty()
	_body.text = "[center]%s[/center]" % text.body
	var animated := Messages.is_animated(queue[0][0])
	_confirm.visible = not animated
	_dim.visible = not animated
	# What happens meanwhile is at the seats, so the message leaves those at the sides clear.
	for side in ["margin_left", "margin_right"]:
		_margin.add_theme_constant_override(side, ANIMATED_MARGIN if animated else MARGIN)


func _fade_out() -> void:
	_stop_tween()
	stop_countdown()
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
