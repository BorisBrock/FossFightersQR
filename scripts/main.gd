extends Node2D
## The game scene: scans for QR codes in the background and plays a sound and shows
## the matching card whenever one is read.

## How long a code's text stays up after the code was last seen.
const TEXT_DURATION_SEC := 5.0
## A code that stayed out of view this long plings again when it comes back. While
## a code stays in view, it plings only once.
const REPEAT_AFTER_ABSENCE_SEC := 2.0
const FADE_OUT_SEC := 0.3
const CARDS_PATH := "res://cards/cards.json"
const TEXT := {
	"camera_starting": { "de": "Die Kamera startet…", "en": "Starting camera…" },
	"show_code": { "de": "Halte einen QR-Code über die Kamera", "en": "Hold a QR code over the camera" },
	"cards_not_loaded": { "de": "Kartendatenbank nicht geladen: %s", "en": "Card database not loaded: %s" },
	"unknown_card": { "de": "Unbekannte Karte", "en": "Unknown card" },
	"level": { "de": "Stufe %d", "en": "Level %d" },
}
const SYMBOLS := {
	"attack": { "de": "Angriff", "en": "Attack" },
	"support": { "de": "Unterstützung", "en": "Support" },
	"heal": { "de": "Heilung", "en": "Heal" },
}

var _cards := CardDatabase.load_file(CARDS_PATH)
var _current_text := ""
var _has_current_text := false
var _last_seen_msec := 0
var _text_timer := 0.0
var _camera_running := false
var _camera_problem := ""

@onready var _scanner: QrCameraScanner = $QrCameraScanner
@onready var _result_panel: PanelContainer = $Hud/Result
@onready var _title_label: Label = $Hud/Result/Margin/Content/Title
@onready var _details_label: Label = $Hud/Result/Margin/Content/Details
@onready var _status_label: Label = $Hud/Status
@onready var _stats_label: Label = $Hud/Stats
@onready var _switch_camera: Button = $Hud/SwitchCamera
@onready var _pling: AudioStreamPlayer = $Pling


func _ready() -> void:
	_scanner.code_read.connect(_on_code_read)
	_scanner.camera_started.connect(_on_camera_started)
	_scanner.failed.connect(_on_scanner_failed)
	_switch_camera.pressed.connect(_on_switch_camera_pressed)
	_switch_camera.hide()
	_result_panel.hide()
	_stats_label.visible = OS.is_debug_build()
	_refresh_status()


func _process(delta: float) -> void:
	if _text_timer > 0.0:
		_text_timer -= delta
		_result_panel.modulate.a = clampf(_text_timer / FADE_OUT_SEC, 0.0, 1.0)
		if _text_timer <= 0.0:
			_result_panel.hide()
	if _stats_label.visible:
		var stats := _scanner.get_stats()
		if not stats.is_empty():
			_stats_label.text = "%d fps · %s · frames %d · decode %.0f / %.0f ms" % [
				Engine.get_frames_per_second(), "scanning" if stats.scene_active else "idle",
				stats.frames_decoded, stats.last_fast_ms, stats.last_rescue_ms,
			]


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_status()
		if _result_panel.visible:
			_show_card(_current_text)


func _t(key: String) -> String:
	return CardDatabase.localized(TEXT[key], TranslationServer.get_locale())


func _refresh_status() -> void:
	if not _camera_problem.is_empty():
		_status_label.text = _camera_problem
	elif not _camera_running:
		_status_label.text = _t("camera_starting")
	elif not _cards.error.is_empty():
		# Without this, every card would look unknown with no hint at the real problem.
		_status_label.text = _t("cards_not_loaded") % _cards.error
	else:
		_status_label.text = _t("show_code")


func _on_camera_started() -> void:
	_camera_running = true
	_camera_problem = ""
	_refresh_status()
	_switch_camera.visible = _scanner.can_switch_camera()
	_switch_camera.disabled = false


func _on_switch_camera_pressed() -> void:
	# Stays disabled until the other camera delivers, because cameras take a moment
	# to open and repeated presses would only queue up more of that.
	_switch_camera.disabled = true
	_scanner.switch_camera()


func _on_scanner_failed(reason: String) -> void:
	_camera_problem = reason
	_refresh_status()


func _on_code_read(text: String, _corners: PackedVector2Array, _frame_size: Vector2i) -> void:
	var now := Time.get_ticks_msec()
	var absent_sec := (now - _last_seen_msec) / 1000.0
	if not _has_current_text or text != _current_text or absent_sec >= REPEAT_AFTER_ABSENCE_SEC:
		_pling.play()
		print("QR code read: ", text)
	_has_current_text = true
	_current_text = text
	_last_seen_msec = now

	_show_card(text)
	_result_panel.modulate.a = 1.0
	_result_panel.show()
	_text_timer = TEXT_DURATION_SEC


func _show_card(qr: String) -> void:
	var card := _cards.find(qr)
	if card == null:
		_title_label.text = _t("unknown_card")
		_details_label.text = qr
		return
	var locale := TranslationServer.get_locale()
	_title_label.text = CardDatabase.localized(card.title, locale)

	var facts := PackedStringArray([card.qr, card.deck])
	if card.level > 0:
		facts.append(_t("level") % card.level)
	var lines := PackedStringArray([" · ".join(facts)])
	if not card.symbols.is_empty():
		var symbols := PackedStringArray()
		for symbol: Card.Symbol in card.symbols:
			var symbol_name: String = CardDatabase.localized(SYMBOLS[symbol.type], locale) if SYMBOLS.has(symbol.type) else symbol.type.capitalize()
			symbols.append("%s %d" % [symbol_name, symbol.strength])
		lines.append(" · ".join(symbols))
	if not card.effect.is_empty():
		lines.append(CardDatabase.localized(card.effect, locale))
	_details_label.text = "\n".join(lines)
