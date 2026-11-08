extends Control
## The first screen: the table with its seats. Tapping a seat opens the editor for the hero
## sitting there, where cards choose the character and the class. The party is kept for the
## next run.

enum View { PARTY, EDITOR }

const BOSS_SCENE := "res://boss_selection.tscn"
const CARDS_PATH := "res://cards/cards.json"
## A code seen this recently is taken to be still in view. It is what lets a player keep
## holding a card while the screen moves on, without that card counting for the next hero.
## The decoder reads a code in a still picture at least once per second.
const STILL_IN_VIEW_MSEC := 2000
## Two cards in view at once must not make the picture flip back and forth.
const SELECTION_DWELL_MSEC := 800
const DELETE_CONFIRM_SEC := 3.0
## How much bigger the tile of the current choice stays.
const TILE_SELECTED_SCALE := 1.08
const TAKEN_NOTICE_SEC := 3.0
## Keeps the caret from pushing a name that just fits out of view.
const PARTY_NAME_SPARE_WIDTH := 6.0
const GOLD := Color(0.98, 0.82, 0.48)
const CREAM := Color(0.95, 0.88, 0.74)
const FAINT := Color(0.6, 0.53, 0.42)
const TAKEN := Color(0.85, 0.5, 0.42)

const TEXT := {
	"hero": { "de": "Held %d", "en": "Hero %d" },
	"prompt_both": { "de": "Charakter- und Klassenkarte", "en": "Character and class card" },
	"prompt_character": { "de": "Deine Charakterkarte", "en": "Your character card" },
	"prompt_class": { "de": "Deine Klassenkarte", "en": "Your class card" },
	"hint_show": { "de": "Über die Kamera halten.", "en": "Hold it over the camera." },
	"hint_edit": { "de": "Zeig eine andere Karte, oder tippe auf einen freien Platz, um dich umzusetzen.", "en": "Show another card, or tap a free seat to move there." },
	"taken": { "de": "%s ist schon vergeben, an %s.", "en": "%s is already taken by %s." },
	"camera_starting": { "de": "Die Kamera startet…", "en": "Starting the camera…" },
	"name_placeholder": { "de": "Dein Name", "en": "Your name" },
	"cancel": { "de": "Abbrechen", "en": "Cancel" },
	"done": { "de": "Fertig", "en": "Done" },
	"delete": { "de": "Löschen", "en": "Delete" },
	"delete_confirm": { "de": "Sicher?", "en": "Really?" },
	"battle": { "de": "Zur Schlacht!", "en": "To Battle!" },
	"party_hint": { "de": "Tippe auf deinen Platz am Tisch, um einen Helden anzulegen oder zu ändern.", "en": "Tap your place at the table to create or change a hero." },
	"party_hint_full": { "de": "Tippe einen Helden an, um ihn zu ändern.", "en": "Tap a hero to change them." },
	"party_name_placeholder": { "de": "Name der Gruppe", "en": "Party name" },
}

## False when coming back from the boss list, as the logo was shown when the app started.
var show_splash := true
## Where the party is saved. Set before adding the scene to the tree to use another file.
var party_path := Party.SAVE_PATH
## Where the cards come from. Set before adding the scene to the tree to use another file.
var cards_path := CARDS_PATH

var _cards: CardDatabase
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
## Codes that have plinged and whose card waits for the pling to finish.
var _codes_confirming := {}
var _last_selection_msec := -SELECTION_DWELL_MSEC
var _tiles := {}
var _prompt_tween: Tween
var _reveal_tween: Tween
var _delete_armed := false
var _delete_timer: SceneTreeTimer
var _taken_notice := ""
var _taken_notice_until_msec := 0
var _party_name_font_size := 0

@onready var _scanner: QrCameraScanner = $QrCameraScanner
@onready var _table: TextureRect = $Table
@onready var _embers: CPUParticles2D = $Embers
@onready var _seats: Array[Node] = $Seats.get_children()
@onready var _stage: Control = $Stage
@onready var _ornaments: Control = $Ornaments
@onready var _party_name_edit: LineEdit = $Stage/Margin/Layout/Header/PartyName
@onready var _title: Label = $Stage/Margin/Layout/Header/Title
@onready var _party_hint: Label = $Stage/Margin/Layout/Header/PartyHint
@onready var _editor: Control = $Stage/Margin/Layout/Views/Editor
@onready var _party_view: Control = $Stage/Margin/Layout/Views/PartyView
@onready var _party_grid: GridContainer = $Stage/Margin/Layout/Views/PartyView/PartyGrid
@onready var _frame: Control = $Stage/Margin/Layout/Views/Editor/CardArea/Frame
@onready var _rays: Control = $Stage/Margin/Layout/Views/Editor/CardArea/Frame/Rays
@onready var _portrait: TextureRect = $Stage/Margin/Layout/Views/Editor/CardArea/Frame/Portrait
@onready var _flash: Control = $Stage/Margin/Layout/Views/Editor/CardArea/Frame/Flash
@onready var _scan_prompt: Control = $Stage/Margin/Layout/Views/Editor/CardArea/Frame/ScanPrompt
@onready var _camera_view: TextureRect = $Stage/Margin/Layout/Views/Editor/CardArea/Frame/ScanPrompt/CameraView
@onready var _card_icon: Control = $Stage/Margin/Layout/Views/Editor/CardArea/Frame/ScanPrompt/CardIcon
@onready var _sweep: Control = $Stage/Margin/Layout/Views/Editor/CardArea/Frame/ScanPrompt/Sweep
@onready var _badge: TextureRect = $Stage/Margin/Layout/Views/Editor/CardArea/Frame/Badge
@onready var _prompt: Label = $Stage/Margin/Layout/Views/Editor/Info/Prompt
@onready var _hint: Label = $Stage/Margin/Layout/Views/Editor/Info/Hint
@onready var _name_edit: LineEdit = $Stage/Margin/Layout/Views/Editor/Info/NameRow/NameEdit
@onready var _dice: TextureButton = $Stage/Margin/Layout/Views/Editor/Info/NameRow/Dice
@onready var _race_tiles: GridContainer = $Stage/Margin/Layout/Views/Editor/Info/RaceTiles
@onready var _class_tiles: GridContainer = $Stage/Margin/Layout/Views/Editor/Info/ClassTiles
@onready var _cancel: Button = $Stage/Margin/Layout/Footer/Cancel
@onready var _delete: Button = $Stage/Margin/Layout/Footer/Delete
@onready var _primary: Button = $Stage/Margin/Layout/Footer/Primary
@onready var _switch_camera: TextureButton = $SwitchCamera
@onready var _overlay: Control = $Overlay
@onready var _sparks: CPUParticles2D = $Sparks
@onready var _fade: ColorRect = $Fade
@onready var _splash: Splash = $Splash
@onready var _reveal_sound: AudioStreamPlayer = $RevealSound
@onready var _seat_sound: AudioStreamPlayer = $SeatSound
@onready var _fanfare_sound: AudioStreamPlayer = $FanfareSound
@onready var _pling: AudioStreamPlayer = $Pling


func _ready() -> void:
	_party = Party.load_file(party_path)
	_cards = CardDatabase.load_file(cards_path)
	_portrait.material = PortraitMaterial.new(0.09, 0.012)
	_badge.material = PortraitMaterial.new(0.5, 0.05)

	_scanner.code_read.connect(_on_code_read)
	_scanner.camera_started.connect(_on_camera_started)
	_scanner.failed.connect(_on_scanner_failed)
	_switch_camera.pressed.connect(_on_switch_camera_pressed)
	_switch_camera.hide()

	_primary.pressed.connect(_on_primary_pressed)
	_cancel.pressed.connect(_on_cancel_pressed)
	_delete.pressed.connect(_on_delete_pressed)
	_dice.pressed.connect(_on_dice_pressed)
	_name_edit.text_changed.connect(_on_name_changed)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _name_edit.release_focus())
	_name_edit.max_length = Party.MAX_NAME_LENGTH
	_name_edit.placeholder_text = _t("name_placeholder")
	_cancel.text = _t("cancel")
	_party_name_font_size = _party_name_edit.get_theme_font_size("font_size")
	_party_name_edit.max_length = Party.MAX_PARTY_NAME_LENGTH
	_party_name_edit.placeholder_text = _t("party_name_placeholder")
	_party_name_edit.text = _party.party_name
	_party_name_edit.text_changed.connect(_on_party_name_changed)
	_party_name_edit.text_submitted.connect(func(_text: String) -> void: _party_name_edit.release_focus())
	_party_name_edit.resized.connect(_fit_party_name)
	_fit_party_name()
	_fill_tiles()
	for token: SeatToken in _seats:
		token.pressed.connect(_on_seat_pressed.bind(token.seat))

	resized.connect(_on_resized)
	_on_resized()
	if show_splash:
		_splash.revealing.connect(_play_intro)
	else:
		_splash.queue_free()
		_play_intro()
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_language()


## Nothing of what is on screen may stay in the old language.
func _refresh_language() -> void:
	_name_edit.placeholder_text = _t("name_placeholder")
	_cancel.text = _t("cancel")
	_party_name_edit.placeholder_text = _t("party_name_placeholder")
	_fit_party_name()
	_taken_notice = ""
	_refresh_view()


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
	var came_into_view: bool = now - _code_seen_msec.get(text, -STILL_IN_VIEW_MSEC) >= STILL_IN_VIEW_MSEC
	_code_seen_msec[text] = now
	if came_into_view:
		_codes_to_ignore.erase(text)
		# Every card plings when it is read, so the player knows they can take it back.
		# What the card does comes after the pling.
		_pling.play()
		_codes_confirming[text] = true
		var wait := create_tween()
		wait.tween_interval(QrCameraScanner.CONFIRM_SEC)
		wait.tween_callback(_on_code_confirmed.bind(text))
	elif not _codes_confirming.has(text) and not _codes_to_ignore.has(text):
		_apply_card(_cards.find(text))


## The pling of a card read has rung. The screen may have moved on meanwhile, so the card
## may no longer count.
func _on_code_confirmed(text: String) -> void:
	_codes_confirming.erase(text)
	if not _codes_to_ignore.has(text):
		_apply_card(_cards.find(text))


## Only character and class cards do anything while editing, all others are ignored.
func _apply_card(card: Card) -> void:
	if card == null or _view != View.EDITOR:
		return
	if HeroOptions.RACES.has(card.race):
		_select_race(card.race, card.qr)
	elif HeroOptions.CLASSES.has(card.hero_class):
		_select_class(card.hero_class, card.qr)


## A card that is still in view must first be taken away before it counts for a new hero.
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


## card is the QR code of the character card shown, which says the hero's level. A tile
## tapped has none: it keeps the card of the race already chosen, or starts at level 1.
func _select_race(race: String, card := "") -> void:
	var owner_hero := _party.hero_with_race(race, _editing)
	if owner_hero != null:
		_show_taken(race, HeroOptions.RACES[race], owner_hero)
		return
	if race == _draft.race:
		# The same race at another level, such as a level 5 card, needs no new choice.
		if not card.is_empty():
			_draft.race_card = card
		return
	if not _may_change_selection():
		return
	_draft.race = race
	_draft.race_card = card
	if _draft.name.is_empty() or _name_is_suggested:
		_suggest_name()
	_show_new_choice(race)


## card as for _select_race().
func _select_class(hero_class: String, card := "") -> void:
	var owner_hero := _party.hero_with_class(hero_class, _editing)
	if owner_hero != null:
		_show_taken(hero_class, HeroOptions.CLASSES[hero_class], owner_hero)
		return
	if hero_class == _draft.hero_class:
		if not card.is_empty():
			_draft.class_card = card
		return
	if not _may_change_selection():
		return
	_draft.hero_class = hero_class
	_draft.class_card = card
	_show_new_choice(hero_class)


func _show_new_choice(id: String) -> void:
	_clear_taken_notice()
	_refresh_tiles()
	_pop_tile(id)
	_refresh_controls()
	_pop_control(_prompt)
	_reveal()


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
		_refresh_controls()


func _on_name_changed(text: String) -> void:
	_draft.name = text.strip_edges()
	_name_is_suggested = false
	_refresh_controls()


func _on_party_name_changed(text: String) -> void:
	_fit_party_name()
	var party_name := text.strip_edges()
	if party_name != _party.party_name:
		_party.party_name = party_name
		_party.save()


## Long names get smaller instead of being cut off, as the title has to fit between the seats.
func _fit_party_name() -> void:
	var edit := _party_name_edit
	var shown := edit.text if not edit.text.is_empty() else edit.placeholder_text
	var width := edit.get_theme_font("font").get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, _party_name_font_size).x
	var room := edit.size.x - edit.get_theme_stylebox("normal").get_minimum_size().x - edit.right_icon.get_width() - PARTY_NAME_SPARE_WIDTH
	var font_size := _party_name_font_size
	if width > room:
		font_size = maxi(int(_party_name_font_size * room / width), 1)
	edit.add_theme_font_size_override("font_size", font_size)


# Flow ----------------------------------------------------------------------------


func _start_new_hero(seat: int) -> void:
	_draft = Party.Hero.new()
	_draft.seat = seat
	_editing = null
	_open_editor()


func _start_editing(hero: Party.Hero) -> void:
	_draft = Party.Hero.new()
	_draft.copy_from(hero)
	_editing = hero
	_open_editor()


func _open_editor() -> void:
	_name_edit.text = _draft.name
	_name_is_suggested = false
	_show_view(View.EDITOR)
	var token: SeatToken = _seats[_draft.seat]
	token.pop()


func _on_primary_pressed() -> void:
	_name_edit.release_focus()
	if _view == View.PARTY:
		_start_battle()
	else:
		_finish_editing()


func _on_cancel_pressed() -> void:
	_name_edit.release_focus()
	_show_view(View.PARTY, -1.0)


func _on_delete_pressed() -> void:
	if not _delete_armed:
		_delete_armed = true
		_delete.text = _t("delete_confirm")
		_pop_control(_delete)
		_delete_timer = get_tree().create_timer(DELETE_CONFIRM_SEC)
		var timer := _delete_timer
		timer.timeout.connect(func() -> void:
			# Only the newest press may disarm, and it may have been answered already.
			if timer == _delete_timer:
				_disarm_delete())
		return
	_disarm_delete()
	_party.heroes.erase(_editing)
	_party.save()
	_show_view(View.PARTY, -1.0)


func _disarm_delete() -> void:
	_delete_armed = false
	_delete_timer = null
	_delete.text = _t("delete")


func _on_seat_pressed(seat: int) -> void:
	var hero := _party.hero_at(seat)
	if _view == View.EDITOR:
		if seat != _draft.seat and (hero == null or hero == _editing):
			_move_draft(seat)
	elif hero != null:
		_start_editing(hero)
	elif _party.heroes.size() < Party.MAX_HEROES:
		_start_new_hero(seat)


## Like every other change in the editor, this only counts once it is saved with Done.
func _move_draft(seat: int) -> void:
	_name_edit.release_focus()
	_draft.seat = seat
	_refresh_seats()
	var token: SeatToken = _seats[seat]
	token.pop()
	_seat_sound.play()


## Copies the choices into the party and saves it.
func _commit_draft() -> void:
	if _editing != null:
		_editing.copy_from(_draft)
	else:
		_party.heroes.append(_draft)
	_party.save()


## Saves the hero and sends their picture to the seat.
func _finish_editing() -> void:
	_commit_draft()
	# The draft may now be the party's hero, which a card read during the flight must not change.
	_view = View.PARTY
	_stop_reveal()
	var seat := _draft.seat
	var token: SeatToken = _seats[seat]
	# Input stays blocked for the flight, as the seats are about to change under it.
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	for other: SeatToken in _seats:
		other.set_mode(SeatToken.Mode.IDLE)
	_refresh_seat_pictures()
	token.show_hero(null)

	var flyer := TextureRect.new()
	flyer.texture = load(HeroOptions.RACES[_draft.race].art)
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
	_burst_sparks(_primary.global_position + _primary.size / 2.0)
	_fade.modulate.a = 0.0
	_fade.show()
	var fade := create_tween()
	fade.tween_interval(0.35)
	fade.tween_property(_fade, "modulate:a", 1.0, 0.7)
	await fade.finished
	get_tree().change_scene_to_file(BOSS_SCENE)


# Showing a view ------------------------------------------------------------------


## direction says where the new view slides in from: 1 is the right, -1 the left.
func _show_view(view: View, direction := 1.0) -> void:
	_view = view
	_stop_reveal()
	_taken_notice = ""
	_ignore_codes_in_view()
	_disarm_delete()
	_refresh_seats()

	var editing := view == View.EDITOR
	_editor.visible = editing
	_party_view.visible = not editing
	_party_hint.visible = not editing
	_party_name_edit.visible = not editing
	_title.visible = editing
	_refresh_view()

	var content: Control = _editor if editing else _party_view
	content.modulate.a = 0.0
	var slide := create_tween().set_parallel()
	slide.tween_method(_slide_content.bind(content), 36.0 * direction, 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide.tween_property(content, "modulate:a", 1.0, 0.25)


func _refresh_view() -> void:
	if _view == View.EDITOR:
		_title.text = _t("hero") % (_party.heroes.find(_editing) + 1 if _editing != null else _party.heroes.size() + 1)
		_refresh_pictures()
		_refresh_tiles()
	else:
		_build_party_view()
	_refresh_controls()


## Moves by the offsets, as setting the position of an anchored control would freeze
## whatever size it has at that moment, even when its contents need less later.
func _slide_content(x: float, content: Control) -> void:
	content.offset_left = x
	content.offset_right = x


func _refresh_pictures() -> void:
	_portrait.texture = load(HeroOptions.RACES[_draft.race].art) if not _draft.race.is_empty() else null
	_badge.texture = load(HeroOptions.CLASSES[_draft.hero_class].art) if not _draft.hero_class.is_empty() else null


func _refresh_controls() -> void:
	_refresh_hint()
	_refresh_seat_pictures()
	_refresh_prompt()
	_refresh_scan_prompt()
	var editing := _view == View.EDITOR
	# A name needs a race to be suggested from, typing one works at any time.
	_dice.disabled = _draft.race.is_empty()
	_dice.modulate.a = 0.35 if _dice.disabled else 1.0
	_cancel.visible = editing
	_delete.visible = editing and _editing != null
	_delete.text = _t("delete_confirm") if _delete_armed else _t("delete")
	_party_hint.text = _t("party_hint") if _party.heroes.size() < Party.MAX_HEROES else _t("party_hint_full")
	_primary.text = _t("done") if editing else _t("battle")
	if editing:
		_set_primary_shown(not _draft.race.is_empty() and not _draft.hero_class.is_empty() and not _draft.name.is_empty())
	else:
		_set_primary_shown(not _party.heroes.is_empty())


## Says what is still missing, or once nothing is, what was chosen.
func _refresh_prompt() -> void:
	var has_race := not _draft.race.is_empty()
	var has_class := not _draft.hero_class.is_empty()
	if has_race and has_class:
		_prompt.text = "%s · %s" % [_title_of(HeroOptions.RACES[_draft.race]), _title_of(HeroOptions.CLASSES[_draft.hero_class])]
	elif has_race:
		_prompt.text = _t("prompt_class")
	elif has_class:
		_prompt.text = _t("prompt_character")
	else:
		_prompt.text = _t("prompt_both")


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
	if not _camera_running:
		_hint.text = _t("camera_starting")
	elif _draft.race.is_empty() or _draft.hero_class.is_empty():
		_hint.text = _t("hint_show")
	else:
		_hint.text = _t("hint_edit")


func _set_primary_shown(shown: bool) -> void:
	_primary.disabled = not shown
	_primary.modulate.a = 1.0 if shown else 0.0


func _refresh_scan_prompt() -> void:
	var waiting := _view == View.EDITOR and (_draft.race.is_empty() or _draft.hero_class.is_empty())
	# The chosen character has to stay recognizable behind the camera picture.
	_camera_view.modulate.a = 0.55 if not _draft.race.is_empty() else 1.0
	if waiting == _scan_prompt.visible and (_prompt_tween != null) == waiting:
		return
	_scan_prompt.visible = waiting
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
		token.show_hero(_hero_shown_at(token.seat))


## While editing, the seats already show the hero as they would be saved.
func _hero_shown_at(seat: int) -> Party.Hero:
	var hero := _party.hero_at(seat)
	if _view != View.EDITOR:
		return hero
	if seat == _draft.seat:
		return _draft if not _draft.race.is_empty() and not _draft.hero_class.is_empty() else null
	return null if hero == _editing else hero


func _refresh_seats() -> void:
	_refresh_seat_pictures()
	var has_room := _party.heroes.size() < Party.MAX_HEROES
	for token: SeatToken in _seats:
		var mode := SeatToken.Mode.DIMMED
		var hero := _party.hero_at(token.seat)
		if _view == View.EDITOR:
			if token.seat == _draft.seat:
				mode = SeatToken.Mode.ACTIVE
			elif hero == null or hero == _editing:
				mode = SeatToken.Mode.QUIET_SELECTABLE
		elif has_room or hero != null:
			mode = SeatToken.Mode.SELECTABLE
		token.set_mode(mode)


# Choice tiles --------------------------------------------------------------------


func _fill_tiles() -> void:
	for id: String in HeroOptions.RACES:
		_tiles[id] = _make_tile(id, HeroOptions.RACES[id])
		_race_tiles.add_child(_tiles[id])
	for id: String in HeroOptions.CLASSES:
		_tiles[id] = _make_tile(id, HeroOptions.CLASSES[id])
		_class_tiles.add_child(_tiles[id])


func _make_tile(id: String, option: Dictionary) -> Control:
	var tile := Button.new()
	tile.flat = true
	tile.focus_mode = Control.FOCUS_NONE
	tile.custom_minimum_size = Vector2(124, 104)
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
	picture.position = Vector2(30, 2)
	picture.size = Vector2(64, 64)
	tile.add_child(picture)

	var caption := Label.new()
	caption.name = "Caption"
	caption.text = _title_of(option)
	caption.add_theme_font_size_override("font_size", 16)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.position = Vector2(0, 67)
	caption.size = Vector2(124, 36)
	tile.add_child(caption)
	return tile


func _on_tile_pressed(id: String) -> void:
	_last_selection_msec = -SELECTION_DWELL_MSEC
	if HeroOptions.RACES.has(id):
		_select_race(id)
	else:
		_select_class(id)


func _refresh_tiles() -> void:
	for id: String in _tiles:
		var is_race := HeroOptions.RACES.has(id)
		var tile: Button = _tiles[id]
		var picture: TextureRect = tile.get_node("Picture")
		var caption: Label = tile.get_node("Caption")
		var selected := _draft.race if is_race else _draft.hero_class
		var is_selected: bool = id == selected
		var owner_hero := _party.hero_with_race(id, _editing) if is_race else _party.hero_with_class(id, _editing)
		var material_of: ShaderMaterial = picture.material
		var faded := owner_hero != null or (not selected.is_empty() and not is_selected)
		material_of.set_shader_parameter("desaturate", 1.0 if owner_hero != null else (0.75 if faded else 0.0))
		material_of.set_shader_parameter("brightness", 0.3 if owner_hero != null else (0.55 if faded else 1.0))
		material_of.set_shader_parameter("ring_width", 0.07 if is_selected else 0.03)
		# Taken options name their owner, so everyone can see what is still free.
		var option: Dictionary = HeroOptions.RACES[id] if is_race else HeroOptions.CLASSES[id]
		caption.text = owner_hero.name if owner_hero != null else _title_of(option)
		var caption_color := CREAM
		if owner_hero != null:
			caption_color = TAKEN
		elif is_selected:
			caption_color = GOLD
		elif faded:
			caption_color = FAINT
		caption.add_theme_color_override("font_color", caption_color)
		tile.scale = Vector2(TILE_SELECTED_SCALE, TILE_SELECTED_SCALE) if is_selected else Vector2.ONE


func _pop_tile(id: String) -> void:
	var tile: Button = _tiles[id]
	tile.scale = Vector2(1.3, 1.3)
	var settled := Vector2(TILE_SELECTED_SCALE, TILE_SELECTED_SCALE)
	create_tween().tween_property(tile, "scale", settled, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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


## The frame turns like a card to show the choices, with a flash and sparks.
func _reveal() -> void:
	_reveal_sound.play()
	_stop_reveal()
	_frame.pivot_offset = _frame.size / 2.0
	_reveal_tween = create_tween()
	_reveal_tween.tween_property(_frame, "scale:x", 0.0, 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_reveal_tween.tween_callback(func() -> void:
		_refresh_pictures()
		_flash.modulate.a = 0.9
		_rays.modulate.a = 1.0
		_burst_sparks(_frame.global_position + _frame.size / 2.0))
	_reveal_tween.tween_property(_frame, "scale:x", 1.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reveal_tween.parallel().tween_property(_flash, "modulate:a", 0.0, 0.45)
	_reveal_tween.parallel().tween_property(_rays, "modulate:a", 0.0, 1.6).set_delay(0.3)


## A reveal still under way must not change the pictures of the view that comes next.
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
