extends Control
## The first screen: each player chooses a character and a class by showing the matching
## cards to the camera, then taps where they sit. The party is kept for the next run.

enum View { PARTY, CHARACTER, CLASS, SEAT }

const GAME_SCENE := "res://main.tscn"
const CARDS_PATH := "res://cards/cards.json"
## A code seen this recently is taken to be still in view. It is what lets a player keep
## holding a card while the screen moves on, without that card counting for the next step.
## The decoder reads a code in a still picture at least once per second.
const STILL_IN_VIEW_MSEC := 2000
## Two cards in view at once must not make the picture flip back and forth.
const SELECTION_DWELL_MSEC := 800
const REMOVE_CONFIRM_SEC := 3.0
const TAKEN_NOTICE_SEC := 3.0
const GOLD := Color(0.98, 0.82, 0.48)
const CREAM := Color(0.95, 0.88, 0.74)
const FAINT := Color(0.6, 0.53, 0.42)
const TAKEN := Color(0.85, 0.5, 0.42)

const STEP_KEYS := {
	View.CHARACTER: "step_character",
	View.CLASS: "step_class",
	View.SEAT: "step_seat",
}

const TEXT := {
	"hero": { "de": "Held %d", "en": "Hero %d" },
	"step_character": { "de": "Charakter", "en": "Character" },
	"step_class": { "de": "Klasse", "en": "Class" },
	"step_seat": { "de": "Platz", "en": "Seat" },
	"prompt_character": { "de": "Halte deine Charakterkarte über die Kamera", "en": "Hold your character card over the camera" },
	"prompt_class": { "de": "Halte deine Klassenkarte über die Kamera", "en": "Hold your class card over the camera" },
	"prompt_seat": { "de": "Wo sitzt du?", "en": "Where are you sitting?" },
	"hint_seat": { "de": "Tippe am Bildschirmrand auf deinen Platz am Tisch.", "en": "Tap your place at the table, around the edge of the screen." },
	"hint_edit": { "de": "Zeig eine andere Karte oder tippe oben auf einen Schritt.", "en": "Show another card, or tap a step at the top to change it." },
	"taken": { "de": "%s ist schon vergeben, an %s.", "en": "%s is already taken by %s." },
	"camera_starting": { "de": "Die Kamera startet…", "en": "Starting the camera…" },
	"name_placeholder": { "de": "Dein Name", "en": "Your name" },
	"back": { "de": "Zurück", "en": "Back" },
	"next": { "de": "Weiter", "en": "Next" },
	"done": { "de": "Fertig", "en": "Done" },
	"remove": { "de": "Entfernen", "en": "Remove" },
	"remove_confirm": { "de": "Wirklich?", "en": "Really?" },
	"battle": { "de": "Zur Schlacht!", "en": "To Battle!" },
	"add_hero": { "de": "Held\nhinzufügen", "en": "Add\nhero" },
	"party_hint": { "de": "Tippe einen Helden an, um ihn zu ändern.", "en": "Tap a hero to change them." },
	"title": { "de": "Foss Fighters", "en": "Foss Fighters" },
}

## Where the party is saved. Set before adding the scene to the tree to use another file.
var party_path := Party.SAVE_PATH

var _cards := CardDatabase.load_file(CARDS_PATH)
var _party: Party
var _view := View.PARTY
var _draft := Party.Hero.new()
## The party's hero being changed, null while creating a new one.
var _editing: Party.Hero
var _name_is_suggested := false
var _camera_problem := ""
var _camera_running := false
var _code_seen_msec := {}
var _codes_to_ignore := {}
var _last_selection_msec := -SELECTION_DWELL_MSEC
var _tiles := {}
var _pips: Array[Dictionary] = []
var _prompt_tween: Tween
var _next_tween: Tween
var _reveal_tween: Tween
var _remove_armed := false
var _remove_timer: SceneTreeTimer
var _taken_notice := ""
var _taken_notice_until_msec := 0

@onready var _scanner: QrCameraScanner = $QrCameraScanner
@onready var _table: TextureRect = $Table
@onready var _embers: CPUParticles2D = $Embers
@onready var _seats: Array[Node] = $Seats.get_children()
@onready var _stage: Control = $Stage
@onready var _ornaments: Control = $Ornaments
@onready var _title: Label = $Stage/Margin/Layout/Header/Title
@onready var _pips_box: HBoxContainer = $Stage/Margin/Layout/Header/Pips
@onready var _party_hint: Label = $Stage/Margin/Layout/Header/PartyHint
@onready var _wizard: Control = $Stage/Margin/Layout/Views/Wizard
@onready var _party_view: Control = $Stage/Margin/Layout/Views/PartyView
@onready var _party_grid: GridContainer = $Stage/Margin/Layout/Views/PartyView/PartyGrid
@onready var _frame: Control = $Stage/Margin/Layout/Views/Wizard/CardArea/Frame
@onready var _rays: Control = $Stage/Margin/Layout/Views/Wizard/CardArea/Frame/Rays
@onready var _portrait: TextureRect = $Stage/Margin/Layout/Views/Wizard/CardArea/Frame/Portrait
@onready var _flash: Control = $Stage/Margin/Layout/Views/Wizard/CardArea/Frame/Flash
@onready var _scan_prompt: Control = $Stage/Margin/Layout/Views/Wizard/CardArea/Frame/ScanPrompt
@onready var _camera_view: TextureRect = $Stage/Margin/Layout/Views/Wizard/CardArea/Frame/ScanPrompt/CameraView
@onready var _card_icon: Control = $Stage/Margin/Layout/Views/Wizard/CardArea/Frame/ScanPrompt/CardIcon
@onready var _sweep: Control = $Stage/Margin/Layout/Views/Wizard/CardArea/Frame/ScanPrompt/Sweep
@onready var _badge: TextureRect = $Stage/Margin/Layout/Views/Wizard/CardArea/Frame/Badge
@onready var _prompt: Label = $Stage/Margin/Layout/Views/Wizard/Info/Prompt
@onready var _hint: Label = $Stage/Margin/Layout/Views/Wizard/Info/Hint
@onready var _name_row: Control = $Stage/Margin/Layout/Views/Wizard/Info/NameRow
@onready var _name_edit: LineEdit = $Stage/Margin/Layout/Views/Wizard/Info/NameRow/NameEdit
@onready var _dice: TextureButton = $Stage/Margin/Layout/Views/Wizard/Info/NameRow/Dice
@onready var _tiles_box: GridContainer = $Stage/Margin/Layout/Views/Wizard/Info/Tiles
@onready var _back: Button = $Stage/Margin/Layout/Footer/Back
@onready var _remove: Button = $Stage/Margin/Layout/Footer/Remove
@onready var _next: Button = $Stage/Margin/Layout/Footer/Next
@onready var _switch_camera: TextureButton = $SwitchCamera
@onready var _overlay: Control = $Overlay
@onready var _sparks: CPUParticles2D = $Sparks
@onready var _fade: ColorRect = $Fade
@onready var _reveal_sound: AudioStreamPlayer = $RevealSound
@onready var _seat_sound: AudioStreamPlayer = $SeatSound
@onready var _fanfare_sound: AudioStreamPlayer = $FanfareSound


func _ready() -> void:
	_party = Party.load_file(party_path)
	_portrait.material = PortraitMaterial.new(0.09, 0.012)
	_badge.material = PortraitMaterial.new(0.5, 0.05)

	_scanner.code_read.connect(_on_code_read)
	_scanner.camera_started.connect(_on_camera_started)
	_scanner.failed.connect(_on_scanner_failed)
	_switch_camera.pressed.connect(_on_switch_camera_pressed)
	_switch_camera.hide()

	_next.pressed.connect(_on_next_pressed)
	_back.pressed.connect(_on_back_pressed)
	_remove.pressed.connect(_on_remove_pressed)
	_dice.pressed.connect(_on_dice_pressed)
	_name_edit.text_changed.connect(_on_name_changed)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _name_edit.release_focus())
	_name_edit.max_length = Party.MAX_NAME_LENGTH
	_name_edit.placeholder_text = _t("name_placeholder")
	_back.text = _t("back")
	_title.text = _t("title")
	_party_hint.text = _t("party_hint")
	_name_row.modulate.a = 0.0
	_build_pips()
	for token: SeatToken in _seats:
		token.pressed.connect(_on_seat_pressed.bind(token.seat))

	resized.connect(_on_resized)
	_on_resized()
	_play_intro()
	if _party.heroes.is_empty():
		_start_new_hero()
	else:
		_show_view(View.PARTY)
	if not _cards.error.is_empty():
		_camera_problem = _cards.error
		_refresh_hint()


func _on_resized() -> void:
	_embers.position = Vector2(size.x / 2.0, size.y + 10.0)
	_embers.emission_rect_extents = Vector2(size.x / 2.0, 8.0)
	_stage.pivot_offset = _stage.size / 2.0
	_table.pivot_offset = size / 2.0


func _t(key: String) -> String:
	return CardDatabase.localized(TEXT[key], TranslationServer.get_locale())


func _title_of(option: Dictionary) -> String:
	return CardDatabase.localized(option.title, TranslationServer.get_locale())


# Camera --------------------------------------------------------------------------


func _on_camera_started() -> void:
	_camera_running = true
	_camera_problem = ""
	_show_camera_preview()
	_switch_camera.visible = _scanner.can_switch_camera()
	_switch_camera.disabled = false
	_refresh_hint()


## Debug builds on a laptop show what the camera sees while waiting for a card, because
## unlike a device lying on the table, the camera needs aiming. It is mirrored, so that
## moving the card to the left also moves it to the left in the picture.
func _show_camera_preview() -> void:
	var preview := _scanner.get_preview_texture() if OS.is_debug_build() else null
	_camera_view.texture = preview
	_camera_view.visible = preview != null
	_card_icon.visible = preview == null


func _on_scanner_failed(reason: String) -> void:
	_camera_problem = reason
	_refresh_hint()


func _on_switch_camera_pressed() -> void:
	# Stays disabled until the other camera delivers, see scripts/main.gd.
	_switch_camera.disabled = true
	_scanner.switch_camera()


func _on_code_read(text: String, _corners: PackedVector2Array, _frame_size: Vector2i) -> void:
	var now := Time.get_ticks_msec()
	if now - _code_seen_msec.get(text, -STILL_IN_VIEW_MSEC) >= STILL_IN_VIEW_MSEC:
		_codes_to_ignore.erase(text)
	_code_seen_msec[text] = now
	if not _codes_to_ignore.has(text):
		_apply_card(_cards.find(text))


## Only cards that match the current step do anything, all others are ignored.
func _apply_card(card: Card) -> void:
	if card == null:
		return
	if _view == View.CHARACTER and HeroOptions.RACES.has(card.race):
		_select_race(card.race)
	elif _view == View.CLASS and HeroOptions.CLASSES.has(card.hero_class):
		_select_class(card.hero_class)


## A card that is still in view must first be taken away before it counts in a new step.
func _ignore_codes_in_view() -> void:
	var now := Time.get_ticks_msec()
	for code: String in _code_seen_msec:
		if now - _code_seen_msec[code] < STILL_IN_VIEW_MSEC:
			_codes_to_ignore[code] = true


func _may_change_selection() -> bool:
	var now := Time.get_ticks_msec()
	if now - _last_selection_msec < SELECTION_DWELL_MSEC:
		return false
	_last_selection_msec = now
	return true


# Choices -------------------------------------------------------------------------


func _select_race(race: String) -> void:
	var owner_hero := _party.hero_with_race(race, _editing)
	if owner_hero != null:
		_show_taken(race, HeroOptions.RACES[race], owner_hero)
		return
	if race == _draft.race or not _may_change_selection():
		return
	_clear_taken_notice()
	_draft.race = race
	if _draft.name.is_empty() or _name_is_suggested:
		_suggest_name()
	_refresh_tiles()
	_refresh_step_controls()
	_prompt.text = _title_of(HeroOptions.RACES[race]) + "!"
	_pop_control(_prompt)
	_reveal(load(HeroOptions.RACES[race].art))


func _select_class(hero_class: String) -> void:
	var owner_hero := _party.hero_with_class(hero_class, _editing)
	if owner_hero != null:
		_show_taken(hero_class, HeroOptions.CLASSES[hero_class], owner_hero)
		return
	if hero_class == _draft.hero_class or not _may_change_selection():
		return
	_clear_taken_notice()
	_draft.hero_class = hero_class
	_refresh_tiles()
	_refresh_step_controls()
	_prompt.text = _title_of(HeroOptions.CLASSES[hero_class]) + "!"
	_pop_control(_prompt)
	_reveal(load(HeroOptions.CLASSES[hero_class].art))


## Says why nothing happens. The camera reads a held card over and over, so the shake
## only plays when the notice is new.
func _show_taken(id: String, option: Dictionary, owner_hero: Party.Hero) -> void:
	var notice := _t("taken") % [_title_of(option), owner_hero.name]
	var now := Time.get_ticks_msec()
	if notice != _taken_notice or now >= _taken_notice_until_msec:
		if _tiles.has(id):
			_shake(_tiles[id])
	_taken_notice = notice
	_taken_notice_until_msec = now + int(TAKEN_NOTICE_SEC * 1000.0)
	_refresh_hint()
	get_tree().create_timer(TAKEN_NOTICE_SEC + 0.05).timeout.connect(_on_taken_notice_timeout)


func _on_taken_notice_timeout() -> void:
	if Time.get_ticks_msec() >= _taken_notice_until_msec:
		_clear_taken_notice()


func _clear_taken_notice() -> void:
	_taken_notice = ""
	_refresh_hint()


func _suggest_name() -> void:
	# The name just shown is left out too, so that rolling the dice always changes it.
	var taken := _party.names()
	taken.append(_draft.name)
	var suggestion := HeroOptions.suggest_name(_draft.race, taken)
	if suggestion.is_empty():
		suggestion = _draft.name
	_draft.name = suggestion
	_name_edit.text = suggestion
	_name_is_suggested = true


func _on_dice_pressed() -> void:
	if not _draft.race.is_empty():
		_suggest_name()
		_pop_control(_name_edit)
		_refresh_step_controls()


func _on_name_changed(text: String) -> void:
	_draft.name = text.strip_edges()
	_name_is_suggested = false
	_refresh_step_controls()


# Flow ----------------------------------------------------------------------------


func _start_new_hero() -> void:
	_draft = Party.Hero.new()
	_editing = null
	_name_edit.text = ""
	_name_is_suggested = false
	_show_view(View.CHARACTER)


func _start_editing(hero: Party.Hero) -> void:
	_draft = Party.Hero.new()
	_draft.copy_from(hero)
	_editing = hero
	_name_edit.text = hero.name
	_name_is_suggested = false
	_show_view(View.CHARACTER)


func _on_next_pressed() -> void:
	_name_edit.release_focus()
	if _view == View.PARTY:
		_start_battle()
	elif _editing != null:
		# The hero is complete, so a change needs no walk through the other steps.
		_commit_draft()
		_show_view(View.PARTY)
	elif _view == View.CHARACTER:
		_show_view(View.CLASS)
	elif _view == View.CLASS:
		_show_view(View.SEAT)


func _on_back_pressed() -> void:
	_name_edit.release_focus()
	match _view:
		View.CHARACTER:
			if not _party.heroes.is_empty():
				_show_view(View.PARTY, -1.0)
		View.CLASS:
			_show_view(View.CHARACTER, -1.0)
		View.SEAT:
			_show_view(View.CLASS, -1.0)


## Whether this step can be opened yet: it needs the choices of the steps before it.
func _can_open(step: View) -> bool:
	match step:
		View.CLASS:
			return not _draft.race.is_empty()
		View.SEAT:
			return not _draft.race.is_empty() and not _draft.hero_class.is_empty()
	return true


func _on_pip_input(event: InputEvent, step: View) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if step != _view and _can_open(step):
		_name_edit.release_focus()
		_show_view(step, 1.0 if step > _view else -1.0)


func _on_remove_pressed() -> void:
	if not _remove_armed:
		_remove_armed = true
		_remove.text = _t("remove_confirm")
		_pop_control(_remove)
		_remove_timer = get_tree().create_timer(REMOVE_CONFIRM_SEC)
		var timer := _remove_timer
		timer.timeout.connect(func() -> void:
			# Only the newest press may disarm, and it may have been answered already.
			if timer == _remove_timer:
				_disarm_remove())
		return
	_disarm_remove()
	_party.heroes.erase(_editing)
	_party.save()
	if _party.heroes.is_empty():
		_start_new_hero()
	else:
		_show_view(View.PARTY, -1.0)


func _disarm_remove() -> void:
	_remove_armed = false
	_remove_timer = null
	_remove.text = _t("remove")


func _on_seat_pressed(seat: int) -> void:
	if _view == View.PARTY:
		var hero := _party.hero_at(seat)
		if hero != null:
			_start_editing(hero)
	elif _view == View.SEAT:
		_name_edit.release_focus()
		if _draft.name.is_empty():
			_suggest_name()
		_draft.seat = seat
		_seat_hero(seat)


## Copies the choices into the party and saves it.
func _commit_draft() -> void:
	if _editing != null:
		_editing.copy_from(_draft)
	else:
		_party.heroes.append(_draft)
	_party.save()


func _seat_hero(seat: int) -> void:
	_commit_draft()
	var token: SeatToken = _seats[seat]
	# Input stays blocked for the flight, as the seats are about to change under it.
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	for other: SeatToken in _seats:
		other.set_mode(SeatToken.Mode.IDLE)
	# The hero moves there now, and may be leaving another seat.
	_refresh_seat_pictures()
	token.show_hero(null)

	var flyer := TextureRect.new()
	flyer.texture = _portrait.texture
	flyer.material = PortraitMaterial.new(0.5, 0.04)
	flyer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flyer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	flyer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(flyer)
	flyer.size = _frame.size
	flyer.pivot_offset = flyer.size / 2.0
	flyer.global_position = _frame.global_position

	var end_scale: float = token.portrait_size().x / flyer.size.x
	var end_position: Vector2 = token.portrait_center() - flyer.size / 2.0
	var flight := create_tween().set_parallel()
	flight.tween_property(flyer, "global_position", end_position, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	flight.tween_property(flyer, "scale", Vector2(end_scale, end_scale), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	flight.tween_property(flyer, "rotation_degrees", token.facing_degrees, 0.6).set_trans(Tween.TRANS_SINE)
	await flight.finished

	flyer.queue_free()
	token.show_hero(_party.hero_at(seat))
	token.pop()
	_burst_sparks(token.portrait_center())
	_seat_sound.play()
	await get_tree().create_timer(0.45).timeout
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_show_view(View.PARTY)


func _start_battle() -> void:
	_fanfare_sound.play()
	_burst_sparks(_next.global_position + _next.size / 2.0)
	_fade.modulate.a = 0.0
	_fade.show()
	var fade := create_tween()
	fade.tween_interval(0.35)
	fade.tween_property(_fade, "modulate:a", 1.0, 0.7)
	await fade.finished
	get_tree().change_scene_to_file(GAME_SCENE)


# Showing a view ------------------------------------------------------------------


## direction says where the new view slides in from: 1 is the right, -1 the left.
func _show_view(view: View, direction := 1.0) -> void:
	_view = view
	_stop_reveal()
	_taken_notice = ""
	_ignore_codes_in_view()
	_disarm_remove()
	_refresh_seats()

	var in_wizard := view != View.PARTY
	_wizard.visible = in_wizard
	_party_view.visible = not in_wizard
	_pips_box.visible = in_wizard
	_party_hint.visible = not in_wizard
	if in_wizard:
		_title.text = _t("hero") % (_party.heroes.find(_editing) + 1 if _editing != null else _party.heroes.size() + 1)
		_title.theme_type_variation = &"Heading"
		_show_wizard_step()
	else:
		_title.text = _t("title")
		_title.theme_type_variation = &"Title"
		_build_party_view()
	_refresh_step_controls()
	_pop_current_pip()

	var content: Control = _wizard if in_wizard else _party_view
	content.modulate.a = 0.0
	var slide := create_tween().set_parallel()
	slide.tween_method(_slide_content.bind(content), 36.0 * direction, 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide.tween_property(content, "modulate:a", 1.0, 0.25)


## Moves by the offsets, as setting the position of an anchored control would freeze
## whatever size it has at that moment, even when its contents need less later.
func _slide_content(x: float, content: Control) -> void:
	content.offset_left = x
	content.offset_right = x


func _show_wizard_step() -> void:
	_fill_tiles()
	_refresh_tiles()
	match _view:
		View.CHARACTER:
			_portrait.texture = load(HeroOptions.RACES[_draft.race].art) if not _draft.race.is_empty() else null
			_badge.texture = null
			_prompt.text = _t("prompt_character")
		View.CLASS:
			_portrait.texture = load(HeroOptions.CLASSES[_draft.hero_class].art) if not _draft.hero_class.is_empty() else null
			_badge.texture = load(HeroOptions.RACES[_draft.race].art)
			_prompt.text = _t("prompt_class")
		View.SEAT:
			_portrait.texture = load(HeroOptions.RACES[_draft.race].art)
			_badge.texture = load(HeroOptions.CLASSES[_draft.hero_class].art)
			_prompt.text = _t("prompt_seat")
	_refresh_scan_prompt()


func _refresh_step_controls() -> void:
	_refresh_hint()
	_refresh_pips()
	_refresh_scan_prompt()
	_set_name_row_shown(_view != View.PARTY and not _draft.race.is_empty())
	_back.visible = _view != View.PARTY and (_view != View.CHARACTER or not _party.heroes.is_empty())
	_remove.visible = _view != View.PARTY and _editing != null
	_remove.text = _t("remove_confirm") if _remove_armed else _t("remove")

	var can_go_on := false
	var label := "done" if _editing != null else "next"
	match _view:
		View.PARTY:
			can_go_on = true
			label = "battle"
		View.CHARACTER:
			can_go_on = not _draft.race.is_empty() and not _draft.name.is_empty()
		View.CLASS:
			can_go_on = not _draft.hero_class.is_empty() and not _draft.name.is_empty()
		View.SEAT:
			# A new hero's seat is chosen by tapping it, so this only keeps an old one.
			can_go_on = _editing != null and not _draft.name.is_empty()
	_next.text = _t(label)
	_set_next_shown(can_go_on)


func _refresh_hint() -> void:
	if not _camera_problem.is_empty():
		_hint.text = _camera_problem
		_hint.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
		return
	if not _taken_notice.is_empty():
		_hint.text = _taken_notice
		_hint.add_theme_color_override("font_color", TAKEN)
		return
	_hint.remove_theme_color_override("font_color")
	match _view:
		View.SEAT:
			_hint.text = _t("hint_seat")
		View.CHARACTER when not _draft.race.is_empty():
			_hint.text = _t("hint_edit")
		View.CLASS when not _draft.hero_class.is_empty():
			_hint.text = _t("hint_edit")
		_:
			_hint.text = "" if _camera_running else _t("camera_starting")


func _set_name_row_shown(shown: bool) -> void:
	# Stays in the layout, so that the tiles do not jump when it appears.
	_name_edit.editable = shown
	_dice.disabled = not shown
	_name_row.mouse_filter = Control.MOUSE_FILTER_PASS if shown else Control.MOUSE_FILTER_IGNORE
	_name_edit.mouse_filter = Control.MOUSE_FILTER_STOP if shown else Control.MOUSE_FILTER_IGNORE
	_dice.mouse_filter = Control.MOUSE_FILTER_STOP if shown else Control.MOUSE_FILTER_IGNORE
	if shown != (_name_row.modulate.a > 0.5):
		create_tween().tween_property(_name_row, "modulate:a", 1.0 if shown else 0.0, 0.3)


func _set_next_shown(shown: bool) -> void:
	if _next_tween != null:
		_next_tween.kill()
		_next_tween = null
	_next.pivot_offset = _next.size / 2.0
	_next.disabled = not shown
	_next.modulate.a = 1.0 if shown else 0.0
	_next.scale = Vector2.ONE
	if shown:
		_next_tween = create_tween().set_loops()
		_next_tween.tween_property(_next, "scale", Vector2(1.05, 1.05), 0.6).set_trans(Tween.TRANS_SINE)
		_next_tween.tween_property(_next, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)


func _refresh_scan_prompt() -> void:
	var waiting := (_view == View.CHARACTER and _draft.race.is_empty()) or (_view == View.CLASS and _draft.hero_class.is_empty())
	if waiting == _scan_prompt.visible and (_prompt_tween != null) == waiting:
		return
	_scan_prompt.visible = waiting
	if _prompt_tween != null:
		_prompt_tween.kill()
		_prompt_tween = null
	if not waiting:
		return
	# A card hovers over the frame while a line of light sweeps it.
	var rest := -87.0
	_card_icon.offset_top = rest
	_card_icon.offset_bottom = rest + 174.0
	_prompt_tween = create_tween().set_loops().set_parallel()
	var bob := _prompt_tween.tween_method(_bob_card, 0.0, TAU, 2.2)
	bob.set_trans(Tween.TRANS_LINEAR)
	_prompt_tween.tween_method(_move_sweep, 0.1, 0.9, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _bob_card(angle: float) -> void:
	var offset := -87.0 + sin(angle) * 8.0
	_card_icon.offset_top = offset
	_card_icon.offset_bottom = offset + 174.0
	_card_icon.rotation_degrees = sin(angle + 1.0) * 2.5


func _move_sweep(at: float) -> void:
	_sweep.anchor_top = at
	_sweep.anchor_bottom = at
	_sweep.modulate.a = sin((at - 0.1) / 0.8 * PI)


func _refresh_seat_pictures() -> void:
	for token: SeatToken in _seats:
		token.show_hero(_party.hero_at(token.seat))


func _refresh_seats() -> void:
	_refresh_seat_pictures()
	for token: SeatToken in _seats:
		var hero := _party.hero_at(token.seat)
		var is_own := _editing != null and hero == _editing
		var mode := SeatToken.Mode.IDLE
		match _view:
			View.PARTY:
				mode = SeatToken.Mode.SELECTABLE if hero != null else SeatToken.Mode.DIMMED
			View.SEAT:
				mode = SeatToken.Mode.SELECTABLE if hero == null or is_own else SeatToken.Mode.DIMMED
			_:
				mode = SeatToken.Mode.DIMMED
		token.set_mode(mode)


# Step markers --------------------------------------------------------------------


func _build_pips() -> void:
	for step: View in [View.CHARACTER, View.CLASS, View.SEAT]:
		# Each step also shows what was chosen, and tapping it goes back there to change it.
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 0)
		column.mouse_filter = Control.MOUSE_FILTER_STOP
		column.gui_input.connect(_on_pip_input.bind(step))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(16, 16)
		holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var diamond := ColorRect.new()
		diamond.size = Vector2(10, 10)
		diamond.position = Vector2(3, 3)
		diamond.pivot_offset = Vector2(5, 5)
		diamond.rotation_degrees = 45.0
		diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(diamond)
		var label := Label.new()
		label.text = _t(STEP_KEYS[step])
		label.add_theme_font_size_override("font_size", 22)
		var value := Label.new()
		value.add_theme_font_size_override("font_size", 17)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(holder)
		row.add_child(label)
		column.add_child(row)
		column.add_child(value)
		_pips_box.add_child(column)
		_pips.append({ "step": step, "column": column, "diamond": diamond, "label": label, "value": value })


func _refresh_pips() -> void:
	for pip in _pips:
		var step: View = pip.step
		var reachable := _can_open(step)
		var color := FAINT
		if step == _view:
			color = GOLD
		elif reachable:
			color = CREAM
		pip.diamond.color = color
		pip.label.add_theme_color_override("font_color", color)
		pip.value.add_theme_color_override("font_color", color)
		pip.value.text = _chosen_text(step)
		pip.column.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if reachable and step != _view else Control.CURSOR_ARROW


func _chosen_text(step: View) -> String:
	if step == View.CHARACTER and not _draft.race.is_empty():
		return _title_of(HeroOptions.RACES[_draft.race])
	if step == View.CLASS and not _draft.hero_class.is_empty():
		return _title_of(HeroOptions.CLASSES[_draft.hero_class])
	return ""


func _pop_current_pip() -> void:
	for pip in _pips:
		if pip.step == _view:
			var diamond: Control = pip.diamond
			diamond.scale = Vector2(2.0, 2.0)
			create_tween().tween_property(diamond, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Choice tiles --------------------------------------------------------------------


func _fill_tiles() -> void:
	for child in _tiles_box.get_children():
		_tiles_box.remove_child(child)
		child.queue_free()
	_tiles.clear()
	var options: Dictionary = {}
	match _view:
		View.CHARACTER:
			options = HeroOptions.RACES
		View.CLASS:
			options = HeroOptions.CLASSES
	_tiles_box.visible = not options.is_empty()
	for id: String in options:
		_tiles[id] = _make_tile(id, options[id])
		_tiles_box.add_child(_tiles[id])


func _make_tile(id: String, option: Dictionary) -> Control:
	var tile := Button.new()
	tile.flat = true
	tile.focus_mode = Control.FOCUS_NONE
	tile.custom_minimum_size = Vector2(98, 126)
	# Choosing happens with the cards. Debug builds also allow a tap, for trying out the
	# screen without a camera or printed cards.
	if OS.is_debug_build():
		tile.pressed.connect(_on_tile_pressed.bind(id))
	else:
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.pivot_offset = tile.custom_minimum_size / 2.0

	var picture := TextureRect.new()
	picture.name = "Picture"
	picture.texture = load(option.art)
	picture.material = PortraitMaterial.new(0.14, 0.03)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.position = Vector2(8, 2)
	picture.size = Vector2(82, 82)
	tile.add_child(picture)

	var caption := Label.new()
	caption.name = "Caption"
	caption.text = _title_of(option)
	caption.add_theme_font_size_override("font_size", 16)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.position = Vector2(0, 85)
	caption.size = Vector2(98, 40)
	tile.add_child(caption)
	return tile


func _on_tile_pressed(id: String) -> void:
	_last_selection_msec = -SELECTION_DWELL_MSEC
	if _view == View.CHARACTER:
		_select_race(id)
	elif _view == View.CLASS:
		_select_class(id)


func _refresh_tiles() -> void:
	var selected := _draft.race if _view == View.CHARACTER else _draft.hero_class
	for id: String in _tiles:
		var tile: Button = _tiles[id]
		var picture: TextureRect = tile.get_node("Picture")
		var caption: Label = tile.get_node("Caption")
		var is_selected: bool = id == selected
		var owner_hero := _owner_of_option(id)
		var material_of: ShaderMaterial = picture.material
		var faded := owner_hero != null or (not selected.is_empty() and not is_selected)
		material_of.set_shader_parameter("desaturate", 1.0 if owner_hero != null else (0.75 if faded else 0.0))
		material_of.set_shader_parameter("brightness", 0.3 if owner_hero != null else (0.55 if faded else 1.0))
		material_of.set_shader_parameter("ring_width", 0.07 if is_selected else 0.03)
		# Taken options name their owner, so everyone can see what is still free.
		var option: Dictionary = HeroOptions.RACES[id] if _view == View.CHARACTER else HeroOptions.CLASSES[id]
		caption.text = owner_hero.name if owner_hero != null else _title_of(option)
		var caption_color := CREAM
		if owner_hero != null:
			caption_color = TAKEN
		elif is_selected:
			caption_color = GOLD
		elif faded:
			caption_color = FAINT
		caption.add_theme_color_override("font_color", caption_color)
		if is_selected:
			tile.scale = Vector2(1.3, 1.3)
			create_tween().tween_property(tile, "scale", Vector2(1.08, 1.08), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			tile.scale = Vector2.ONE


func _owner_of_option(id: String) -> Party.Hero:
	if _view == View.CHARACTER:
		return _party.hero_with_race(id, _editing)
	return _party.hero_with_class(id, _editing)


# Party view ----------------------------------------------------------------------


func _build_party_view() -> void:
	for child in _party_grid.get_children():
		_party_grid.remove_child(child)
		child.queue_free()
	var index := 0
	for hero in _party.heroes:
		var card := _make_hero_card(hero)
		_party_grid.add_child(card)
		_animate_card_in(card, index)
		index += 1
	if _party.heroes.size() < Party.MAX_HEROES:
		var add := Button.new()
		add.text = "+\n" + _t("add_hero")
		add.focus_mode = Control.FOCUS_NONE
		add.custom_minimum_size = Vector2(190, 246)
		add.pressed.connect(_start_new_hero)
		_party_grid.add_child(add)
		_animate_card_in(add, index)


func _make_hero_card(hero: Party.Hero) -> Control:
	var card := Button.new()
	card.flat = true
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(190, 268)
	card.pressed.connect(_start_editing.bind(hero))

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 176)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(holder)
	var portrait := _make_picture(load(HeroOptions.RACES[hero.race].art), PortraitMaterial.new(0.1, 0.02))
	portrait.position = Vector2(7, 0)
	portrait.size = Vector2(176, 176)
	holder.add_child(portrait)
	var crest := _make_picture(load(HeroOptions.CLASSES[hero.hero_class].art), PortraitMaterial.new(0.5, 0.06))
	crest.position = Vector2(127, 116)
	crest.size = Vector2(64, 64)
	holder.add_child(crest)

	box.add_child(_make_centered_label(hero.name, "Heading", 26))
	# On two lines, because the longest race and class names do not fit on one.
	var description := "%s\n%s" % [_title_of(HeroOptions.RACES[hero.race]), _title_of(HeroOptions.CLASSES[hero.hero_class])]
	box.add_child(_make_centered_label(description, "Hint", 17))
	return card


func _make_picture(texture: Texture2D, picture_material: Material) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.material = picture_material
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture


func _make_centered_label(text: String, variation: StringName, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _animate_card_in(card: Control, index: int) -> void:
	card.modulate.a = 0.0
	var appear := create_tween()
	appear.tween_interval(0.05 + index * 0.07)
	appear.tween_property(card, "modulate:a", 1.0, 0.25)


# Effects -------------------------------------------------------------------------


func _play_intro() -> void:
	_stage.scale = Vector2(0.92, 0.92)
	_stage.modulate.a = 0.0
	_ornaments.modulate.a = 0.0
	var intro := create_tween().set_parallel()
	intro.tween_property(_stage, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro.tween_property(_stage, "modulate:a", 1.0, 0.35)
	intro.tween_property(_ornaments, "modulate:a", 1.0, 0.5).set_delay(0.2)
	for i in _seats.size():
		var seat: Control = _seats[i]
		seat.scale = Vector2.ZERO
		intro.tween_property(seat, "scale", Vector2.ONE, 0.4).set_delay(0.1 + i * 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# The candlelit table drifts slowly closer and back.
	var drift := create_tween().set_loops()
	drift.tween_property(_table, "scale", Vector2(1.05, 1.05), 24.0).set_trans(Tween.TRANS_SINE)
	drift.tween_property(_table, "scale", Vector2.ONE, 24.0).set_trans(Tween.TRANS_SINE)


## The frame turns like a card to show the new picture, with a flash and sparks.
func _reveal(texture: Texture2D) -> void:
	_reveal_sound.play()
	_stop_reveal()
	_frame.pivot_offset = _frame.size / 2.0
	_reveal_tween = create_tween()
	_reveal_tween.tween_property(_frame, "scale:x", 0.0, 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_reveal_tween.tween_callback(func() -> void:
		_portrait.texture = texture
		_flash.modulate.a = 0.9
		_rays.modulate.a = 1.0
		_burst_sparks(_frame.global_position + _frame.size / 2.0))
	_reveal_tween.tween_property(_frame, "scale:x", 1.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reveal_tween.parallel().tween_property(_flash, "modulate:a", 0.0, 0.45)
	_reveal_tween.parallel().tween_property(_rays, "modulate:a", 0.0, 1.6).set_delay(0.3)


## A reveal still under way must not put its picture into the view that comes next.
func _stop_reveal() -> void:
	if _reveal_tween != null:
		_reveal_tween.kill()
		_reveal_tween = null
	_frame.scale = Vector2.ONE
	_flash.modulate.a = 0.0
	_rays.modulate.a = 0.0


func _burst_sparks(at: Vector2) -> void:
	_sparks.global_position = at
	_sparks.restart()


func _shake(control: Control) -> void:
	var home := control.rotation_degrees
	control.pivot_offset = control.size / 2.0
	var shake := create_tween()
	for angle: float in [-7.0, 7.0, -5.0, 5.0, 0.0]:
		shake.tween_property(control, "rotation_degrees", home + angle, 0.06)


func _pop_control(control: Control) -> void:
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2(1.12, 1.12)
	create_tween().tween_property(control, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
