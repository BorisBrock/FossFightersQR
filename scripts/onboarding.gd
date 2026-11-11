extends Control
## The first screen: the table with its seats. Tapping a seat opens the editor for the hero
## sitting there, where cards choose the character and the class. The party is kept for the
## next run. Then the boss is chosen on the same screen: the seats and the party make way
## for the boss list, and the list for the chosen boss's overview, without a change of scene.

enum View { PARTY, EDITOR }
## What the screen shows: the table with the party, the boss list or a boss's overview.
enum Phase { TABLE, BOSSES, BOSS }

const CARD_ICON := preload("res://assets/onboarding/icons/card_scan.png")
const PEN_ICON := preload("res://assets/onboarding/icons/pen.png")
const ERROR_ICON := preload("res://assets/onboarding/icons/error.png")
## By path instead of class_name, so that they work before the editor has scanned them.
const BossSelection := preload("res://scripts/boss_selection.gd")
const BossOverview := preload("res://scripts/boss_overview.gd")
const FIGHT_SCENE := "res://boss_fight.tscn"
const FIGHT_FADE_SEC := 0.7
## How far the seats slide past the edge of the screen when the table makes way.
const SEAT_SLIDE := 260.0
const TABLE_OUT_SEC := 0.45
const TABLE_IN_SEC := 0.5
## How dark the table gets behind the boss screens.
const TABLE_DIM := 0.72
const TABLE_DIM_BOSSES := 0.5
## The settings and camera buttons are a little see-through.
const CORNER_BUTTON_ALPHA := 0.75
const CARDS_PATH := "res://cards/cards.json"
## A code seen this recently is taken to be still in view. It is what lets a player keep
## holding a card while the screen moves on, without that card counting for the next hero.
## The decoder reads a code in a still picture at least once per second.
const STILL_IN_VIEW_MSEC := 2000
## Two cards in view at once must not make the picture flip back and forth.
const SELECTION_DWELL_MSEC := 800
const DELETE_CONFIRM_SEC := 3.0
const TAKEN_NOTICE_SEC := 3.0
## Keeps the caret from pushing a name that just fits out of view.
const PARTY_NAME_SPARE_WIDTH := 6.0
const GOLD := Color(0.84, 0.65, 0.28)
const BRIGHT_GOLD := Color(0.98, 0.84, 0.5)
const ALERT := Color(0.92, 0.42, 0.32)

const TEXT := {
	"character": { "de": "Charakter", "en": "Character" },
	"class": { "de": "Klasse", "en": "Class" },
	"step_open": { "de": "noch offen", "en": "not yet" },
	"prompt_both": { "de": "Charakter- und Klassenkarte", "en": "Character and class card" },
	"prompt_character": { "de": "Deine Charakterkarte", "en": "Your character card" },
	"prompt_class": { "de": "Deine Klassenkarte", "en": "Your class card" },
	"hint_show": { "de": "Über die Kamera halten.", "en": "Hold it over the camera." },
	"prompt_name": { "de": "Wie heißt dein Held?", "en": "What is your hero called?" },
	"hint_name": { "de": "Tippe oben auf den Namen, oder würfle einen.", "en": "Type it at the top, or roll the dice." },
	"prompt_seat": { "de": "Wo sitzt du?", "en": "Where are you sitting?" },
	"hint_seat": { "de": "Tippe auf deinen Platz am Tisch.", "en": "Tap your place at the table." },
	"prompt_ready": { "de": "%s ist bereit!", "en": "%s is ready!" },
	"prompt_taken": { "de": "Schon vergeben", "en": "Already taken" },
	"prompt_problem": { "de": "Da klemmt etwas", "en": "Something went wrong" },
	"hint_edit": { "de": "Zeig eine andere Karte, oder tippe auf einen freien Platz, um dich umzusetzen.", "en": "Show another card, or tap a free seat to move there." },
	"taken": { "de": "%s ist schon vergeben, an %s.", "en": "%s is already taken by %s." },
	"camera_starting": { "de": "Die Kamera startet…", "en": "Starting the camera…" },
	"name_placeholder": { "de": "Dein Name", "en": "Your name" },
	"done": { "de": "Fertig", "en": "Done" },
	"delete": { "de": "Löschen", "en": "Delete" },
	"delete_confirm": { "de": "Sicher?", "en": "Really?" },
	"battle": { "de": "Los geht's!", "en": "Let's go!" },
	"party_hint": { "de": "Tippe auf deinen Platz am Tisch oder zeig deine Charakterkarte, um einen Helden anzulegen oder zu ändern.", "en": "Tap your place at the table or show your character card to create or change a hero." },
	"party_hint_full": { "de": "Tippe einen Helden an, um ihn zu ändern.", "en": "Tap a hero to change them." },
	"party_name_placeholder": { "de": "Name der Gruppe", "en": "Party name" },
}

## False when coming back from a fight, as the logo was shown when the app started.
var show_splash := true
## Replaced by tests, which catch the fight instead of starting it.
var change_scene := func(next: Node) -> void: get_tree().change_scene_to_node(next)
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
var _prompt_tween: Tween
var _reveal_tween: Tween
var _delete_armed := false
var _delete_timer: SceneTreeTimer
var _taken_notice := ""
var _taken_notice_until_msec := 0
var _party_name_font_size := 0
var _name_font_size := 0
## What the message says, so that only a new message pops.
var _message_shown := ""
var _step_pulse: Tween
var _styles := {}
var _phase := Phase.TABLE
## The screen is moving on from one phase to the next. Taps and cards wait for it.
var _moving := false

@onready var _scanner: QrCameraScanner = $QrCameraScanner
@onready var _table: TextureRect = $Table
@onready var _embers: CPUParticles2D = $Embers
@onready var _seats: Array[Node] = $Seats.get_children()
@onready var _stage: Control = $Stage
@onready var _ornaments: Control = $Ornaments
@onready var _party_name_edit: LineEdit = $Stage/Margin/Layout/Header/PartyName
@onready var _name_row: Control = $Stage/Margin/Layout/Header/NameRow
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
@onready var _character_step: PanelContainer = $Stage/Margin/Layout/Views/Editor/Steps/CharacterStep
@onready var _class_step: PanelContainer = $Stage/Margin/Layout/Views/Editor/Steps/ClassStep
@onready var _message: PanelContainer = $Stage/Margin/Layout/Views/Editor/Message
@onready var _message_icon: TextureRect = $Stage/Margin/Layout/Views/Editor/Message/Row/Icon
@onready var _message_alert: TextureRect = $Stage/Margin/Layout/Views/Editor/Message/Row/Alert
@onready var _prompt: Label = $Stage/Margin/Layout/Views/Editor/Message/Row/Texts/Prompt
@onready var _hint: Label = $Stage/Margin/Layout/Views/Editor/Message/Row/Texts/Hint
@onready var _name_edit: LineEdit = $Stage/Margin/Layout/Header/NameRow/NameEdit
@onready var _dice: TextureButton = $Stage/Margin/Layout/Header/NameRow/Dice
@onready var _delete: Button = $Stage/Margin/Layout/Footer/Delete
@onready var _primary: Button = $Stage/Margin/Layout/Footer/Primary
@onready var _footer_spacer: Control = $Stage/Margin/Layout/Footer/Spacer
@onready var _switch_camera: TextureButton = $SwitchCamera
@onready var _settings: Control = $Settings
@onready var _seats_layer: Control = $Seats
@onready var _boss_selection: BossSelection = $BossSelection
@onready var _boss_overview: BossOverview = $BossOverview
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
	_build_status_styles()

	_scanner.code_read.connect(_on_code_read)
	_scanner.camera_started.connect(_on_camera_started)
	_scanner.failed.connect(_on_scanner_failed)
	_switch_camera.pressed.connect(_on_switch_camera_pressed)
	_switch_camera.hide()

	_primary.pressed.connect(_on_primary_pressed)
	_delete.pressed.connect(_on_delete_pressed)
	_dice.pressed.connect(_on_dice_pressed)
	_name_edit.text_changed.connect(_on_name_changed)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _name_edit.release_focus())
	_name_edit.max_length = Party.MAX_NAME_LENGTH
	_name_edit.placeholder_text = _t("name_placeholder")
	_name_font_size = _name_edit.get_theme_font_size("font_size")
	_name_edit.resized.connect(func() -> void: _fit_title(_name_edit, _name_font_size))
	_party_name_font_size = _party_name_edit.get_theme_font_size("font_size")
	_party_name_edit.max_length = Party.MAX_PARTY_NAME_LENGTH
	_refresh_party_name_placeholder()
	_party_name_edit.text = _party.party_name
	_party_name_edit.text_changed.connect(_on_party_name_changed)
	_party_name_edit.text_submitted.connect(func(_text: String) -> void: _party_name_edit.release_focus())
	_party_name_edit.focus_entered.connect(_refresh_party_name_placeholder)
	_party_name_edit.focus_exited.connect(_refresh_party_name_placeholder)
	_party_name_edit.resized.connect(func() -> void: _fit_title(_party_name_edit, _party_name_font_size))
	_fit_title(_party_name_edit, _party_name_font_size)
	for token: SeatToken in _seats:
		token.pressed.connect(_on_seat_pressed.bind(token.seat))
	_boss_selection.back_pressed.connect(_back_to_table)
	_boss_selection.chosen.connect(_show_boss)
	_boss_overview.back_pressed.connect(_back_to_bosses)
	_boss_overview.fight_pressed.connect(_start_fight)

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
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and not MenuScreen.is_dialog_open(get_tree()):
		_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if _phase != Phase.TABLE and event.is_action_pressed("ui_cancel") and not MenuScreen.is_dialog_open(get_tree()):
		get_viewport().set_input_as_handled()
		_go_back()


func _exit_tree() -> void:
	get_tree().quit_on_go_back = true


## Nothing of what is on screen may stay in the old language.
func _refresh_language() -> void:
	_name_edit.placeholder_text = _t("name_placeholder")
	_refresh_party_name_placeholder()
	_taken_notice = ""
	_refresh_view()


func _title_of(option: Dictionary) -> String:
	return CardDatabase.localized(option.title, TranslationServer.get_locale())


# Camera --------------------------------------------------------------------------


func _on_camera_started() -> void:
	_camera_running = true
	_camera_problem = ""
	_show_camera_preview()
	# The button is for aiming at cards, which only count at the table.
	_switch_camera.visible = _scanner.can_switch_camera() and _phase == Phase.TABLE
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


## Only character and class cards do anything, all others are ignored. At the table, one
## opens the editor (see _start_from_card).
func _apply_card(card: Card) -> void:
	# Cards only count at the table.
	if card == null or _phase != Phase.TABLE or _moving:
		return
	if _view == View.PARTY:
		_start_from_card(card)
		return
	if HeroOptions.RACES.has(card.race):
		_select_race(card.race, card.qr)
	elif HeroOptions.CLASSES.has(card.hero_class):
		_select_class(card.hero_class, card.qr)


## At the table, a character or class card no hero has yet opens the editor for a new hero
## with it, who chooses their seat last. A card of a hero already at the table does
## nothing: it may just be lying in view.
func _start_from_card(card: Card) -> void:
	# Not while a hero flies to their seat.
	if _overlay.mouse_filter == Control.MOUSE_FILTER_STOP:
		return
	if _party.heroes.size() >= Party.MAX_HEROES:
		return
	if HeroOptions.RACES.has(card.race):
		if _party.hero_with_race(card.race) != null:
			return
	elif HeroOptions.CLASSES.has(card.hero_class):
		if _party.hero_with_class(card.hero_class) != null:
			return
	else:
		return
	_start_new_hero(-1)
	_apply_card(card)


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


## card is the QR code of the character card shown, which says the hero's level. Without
## one, the card of the race already chosen is kept, or the hero starts at level 1.
func _select_race(race: String, card := "") -> void:
	var owner_hero := _party.hero_with_race(race, _editing)
	if owner_hero != null:
		_show_taken(HeroOptions.RACES[race], owner_hero)
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
	_show_new_choice(_character_step)


## card as for _select_race().
func _select_class(hero_class: String, card := "") -> void:
	var owner_hero := _party.hero_with_class(hero_class, _editing)
	if owner_hero != null:
		_show_taken(HeroOptions.CLASSES[hero_class], owner_hero)
		return
	if hero_class == _draft.hero_class:
		if not card.is_empty():
			_draft.class_card = card
		return
	if not _may_change_selection():
		return
	_draft.hero_class = hero_class
	_draft.class_card = card
	_show_new_choice(_class_step)


## step is the one that shows the new choice.
func _show_new_choice(step: Control) -> void:
	_clear_taken_notice()
	_refresh_controls()
	_pop_control(step)
	_reveal()


## Says why nothing happens. The camera reads a held card over and over, so the shake
## only plays when the notice is new.
func _show_taken(option: Dictionary, owner_hero: Party.Hero) -> void:
	var notice := _t("taken") % [_title_of(option), owner_hero.name]
	var now := Time.get_ticks_msec()
	if notice != _taken_notice or now >= _taken_notice_until_msec:
		_shake(_frame)
		_shake(_message, 3.0)
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
	_fit_title(_name_edit, _name_font_size)
	_name_is_suggested = true


func _on_dice_pressed() -> void:
	if not _draft.race.is_empty():
		_suggest_name()
		_pop_control(_name_edit)
		_refresh_controls()


func _on_name_changed(text: String) -> void:
	_fit_title(_name_edit, _name_font_size)
	_draft.name = text.strip_edges()
	_name_is_suggested = false
	_refresh_controls()


func _on_party_name_changed(text: String) -> void:
	_fit_title(_party_name_edit, _party_name_font_size)
	var party_name := text.strip_edges()
	if party_name != _party.party_name:
		_party.party_name = party_name
		_party.save()


## The placeholder is only a hint: it makes way as soon as the name is being typed.
func _refresh_party_name_placeholder() -> void:
	_party_name_edit.placeholder_text = "" if _party_name_edit.has_focus() else _t("party_name_placeholder")
	_fit_title(_party_name_edit, _party_name_font_size)


## Long names get smaller instead of being cut off, as the title has to fit between the seats.
## Both the party's name and the hero's name are titles.
func _fit_title(edit: LineEdit, full_size: int) -> void:
	var shown := edit.text if not edit.text.is_empty() else edit.placeholder_text
	var width := edit.get_theme_font("font").get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, full_size).x
	var room := edit.size.x - edit.get_theme_stylebox("normal").get_minimum_size().x - edit.right_icon.get_width() - PARTY_NAME_SPARE_WIDTH
	var font_size := full_size
	if width > room:
		font_size = maxi(int(full_size * room / width), 1)
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
	_message_shown = ""
	_show_view(View.EDITOR)
	# A hero started from a card has no seat yet.
	if _draft.seat >= 0:
		var token: SeatToken = _seats[_draft.seat]
		token.pop()


func _on_primary_pressed() -> void:
	_name_edit.release_focus()
	if _view == View.PARTY:
		_to_bosses()
	else:
		_finish_editing()


## The panel and the seats take their own taps, so a tap that gets here was on the
## table around them.
func _gui_input(event: InputEvent) -> void:
	var tap := event as InputEventMouseButton
	if tap != null and tap.pressed and tap.button_index == MOUSE_BUTTON_LEFT and _view == View.EDITOR:
		accept_event()
		ButtonSounds.click()
		_cancel_editing()


## Leaves the editor without saving.
func _cancel_editing() -> void:
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
	_refresh_controls()
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


# Choosing the boss --------------------------------------------------------------


## Moves on from the table to the boss list.
func _to_bosses() -> void:
	if _moving or _phase != Phase.TABLE:
		return
	_fanfare_sound.play()
	_burst_sparks(_primary.global_position + _primary.size / 2.0)
	_begin_move(Phase.BOSSES)
	await _leave_table()
	await _boss_selection.play_in()
	_end_move()


## The picture of the chosen boss flies on from the list into its overview, while the
## rest of the list makes way.
func _show_boss(id: String) -> void:
	if _moving:
		return
	_begin_move(Phase.BOSS)
	_boss_overview.show_boss(id)
	var from := _boss_selection.entry_rect(id)
	_boss_selection.play_out_without(id)
	await _boss_overview.play_in(from)
	_end_move()


func _back_to_bosses() -> void:
	if _moving:
		return
	_begin_move(Phase.BOSSES)
	await _boss_overview.play_out()
	await _boss_selection.play_in()
	_end_move()


func _back_to_table() -> void:
	if _moving:
		return
	_begin_move(Phase.TABLE)
	await _boss_selection.play_out()
	await _return_to_table()
	_end_move()


## Escape and the back button of a phone lead back a step, as Back does. At the table,
## the back button of a phone quits the app.
func _go_back() -> void:
	if _moving:
		return
	match _phase:
		Phase.BOSSES:
			_boss_selection.request_back()
		Phase.BOSS:
			_boss_overview.request_back()


## Taps wait until the next phase is shown.
func _begin_move(phase: Phase) -> void:
	_moving = true
	_phase = phase
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().quit_on_go_back = false


func _end_move() -> void:
	_moving = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().quit_on_go_back = _phase == Phase.TABLE


## Fight! leaves the screen at last, for the boss fight.
func _start_fight() -> void:
	if _moving:
		return
	_begin_move(Phase.BOSS)
	_fade.modulate.a = 0.0
	_fade.show()
	var fade := create_tween()
	fade.tween_property(_fade, "modulate:a", 1.0, FIGHT_FADE_SEC)
	await fade.finished
	change_scene.call(load(FIGHT_SCENE).instantiate())


## The seats slide off the edges they sit at, and the party sinks back into the table.
func _leave_table() -> void:
	_party_name_edit.release_focus()
	for token: SeatToken in _seats:
		token.set_mode(SeatToken.Mode.IDLE)
	var away := create_tween().set_parallel()
	for i in _seats.size():
		var token: SeatToken = _seats[i]
		away.tween_method(_slide_seat.bind(token), 0.0, 1.0, TABLE_OUT_SEC).set_delay(i * 0.03).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	away.tween_property(_stage, "scale", Vector2(0.9, 0.9), TABLE_OUT_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	away.tween_property(_stage, "modulate:a", 0.0, TABLE_OUT_SEC * 0.8).set_delay(TABLE_OUT_SEC * 0.2)
	away.tween_property(_ornaments, "modulate:a", 0.0, TABLE_OUT_SEC * 0.6)
	away.tween_property(_settings, "modulate:a", 0.0, TABLE_OUT_SEC * 0.6)
	away.tween_property(_switch_camera, "modulate:a", 0.0, TABLE_OUT_SEC * 0.6)
	away.tween_property(_table.material, "shader_parameter/dim", TABLE_DIM_BOSSES, TABLE_OUT_SEC * 1.5)
	await away.finished
	for control: Control in [_seats_layer, _stage, _ornaments, _settings, _switch_camera]:
		control.hide()


## The way back: the seats slide in again, and the party comes up.
func _return_to_table() -> void:
	for control: Control in [_seats_layer, _stage, _ornaments, _settings]:
		control.show()
	_switch_camera.visible = _camera_running and _scanner.can_switch_camera()
	# A card held up meanwhile must first be taken away.
	_ignore_codes_in_view()
	_refresh_seats()
	var back := create_tween().set_parallel()
	for i in _seats.size():
		var token: SeatToken = _seats[i]
		back.tween_method(_slide_seat.bind(token), 1.0, 0.0, TABLE_IN_SEC).set_delay(i * 0.03).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	back.tween_property(_stage, "scale", Vector2.ONE, TABLE_IN_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	back.tween_property(_stage, "modulate:a", 1.0, TABLE_IN_SEC * 0.7)
	back.tween_property(_ornaments, "modulate:a", 1.0, TABLE_IN_SEC).set_delay(TABLE_IN_SEC * 0.3)
	back.tween_property(_settings, "modulate:a", CORNER_BUTTON_ALPHA, TABLE_IN_SEC)
	back.tween_property(_switch_camera, "modulate:a", CORNER_BUTTON_ALPHA, TABLE_IN_SEC)
	back.tween_property(_table.material, "shader_parameter/dim", TABLE_DIM, TABLE_IN_SEC * 1.5)
	await back.finished


## away is how far along the way out the seat is: 0 at its place, 1 past the edge of the
## screen. Moves by the offsets, which keep the seat anchored to its edge.
func _slide_seat(away: float, token: SeatToken) -> void:
	if not token.has_meta(&"home"):
		token.set_meta(&"home", Vector4(token.offset_left, token.offset_top, token.offset_right, token.offset_bottom))
	var home: Vector4 = token.get_meta(&"home")
	# A seat faces the edge it is at: 0 degrees the bottom, 90 the left, -90 the right.
	var shift := Vector2.DOWN.rotated(deg_to_rad(token.facing_degrees)) * SEAT_SLIDE * away
	token.offset_left = home.x + shift.x
	token.offset_top = home.y + shift.y
	token.offset_right = home.z + shift.x
	token.offset_bottom = home.w + shift.y


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
	_name_row.visible = editing
	_refresh_view()

	var content: Control = _editor if editing else _party_view
	content.modulate.a = 0.0
	var slide := create_tween().set_parallel()
	slide.tween_method(_slide_content.bind(content), 36.0 * direction, 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	slide.tween_property(content, "modulate:a", 1.0, 0.25)


func _refresh_view() -> void:
	if _view == View.EDITOR:
		_fit_title(_name_edit, _name_font_size)
		_refresh_pictures()
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
	_refresh_steps()
	_refresh_hint()
	_refresh_seat_pictures()
	_refresh_scan_prompt()
	var editing := _view == View.EDITOR
	# A name needs a race to be suggested from, typing one works at any time.
	_dice.disabled = _draft.race.is_empty()
	_dice.modulate.a = 0.35 if _dice.disabled else 1.0
	# In the editor, "Delete" and "Done" share the width in equal halves, and "Done" stays
	# on the right even for a new hero, where the spacer keeps the place of "Delete".
	# Alone, "Let's go!" sits centered.
	_delete.visible = editing and _editing != null
	_footer_spacer.visible = editing and _editing == null
	_primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL if editing else Control.SIZE_SHRINK_CENTER
	_delete.text = _t("delete_confirm") if _delete_armed else _t("delete")
	_party_hint.text = _t("party_hint") if _party.heroes.size() < Party.MAX_HEROES else _t("party_hint_full")
	_primary.text = _t("done") if editing else _t("battle")
	if editing:
		_set_primary_shown(not _draft.race.is_empty() and not _draft.hero_class.is_empty() and not _draft.name.is_empty() and _draft.seat >= 0)
	else:
		_set_primary_shown(not _party.heroes.is_empty())


# Status --------------------------------------------------------------------------


func _build_status_styles() -> void:
	_styles.step_open = _make_box(Color(0.04, 0.025, 0.015, 0.55), Color(GOLD, 0.3), 2)
	_styles.step_done = _make_box(Color(0.13, 0.08, 0.035, 0.9), GOLD, 2)
	_styles.step_done.shadow_color = Color(BRIGHT_GOLD, 0.18)
	_styles.step_done.shadow_size = 8
	_styles.message = _make_box(Color(0.04, 0.025, 0.015, 0.65), Color(GOLD, 0.45), 1, 6)
	_styles.ready = _make_box(Color(0.14, 0.09, 0.03, 0.9), BRIGHT_GOLD, 2, 6)
	_styles.ready.shadow_color = Color(BRIGHT_GOLD, 0.25)
	_styles.ready.shadow_size = 12
	_styles.alert = _make_box(Color(0.22, 0.06, 0.04, 0.9), ALERT, 2, 6)
	_message_alert.texture = ERROR_ICON
	for step: Control in [_character_step, _class_step]:
		step.get_node("Row/Thumb/Picture").material = PortraitMaterial.new(0.5, 0.06)


## accent is the width of the bar on the left that marks a message.
func _make_box(bg: Color, border: Color, border_width: int, accent := 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.border_width_left = maxi(border_width, accent)
	box.set_corner_radius_all(14)
	box.content_margin_left = 8.0 + accent
	box.content_margin_right = 8.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	return box


## The two cards a hero needs, each showing what it chose or that it is still open.
func _refresh_steps() -> void:
	var race: Dictionary = HeroOptions.RACES.get(_draft.race, {})
	var hero_class: Dictionary = HeroOptions.CLASSES.get(_draft.hero_class, {})
	_refresh_step(_character_step, _t("character"), race)
	_refresh_step(_class_step, _t("class"), hero_class)
	var open := _view == View.EDITOR and (race.is_empty() or hero_class.is_empty())
	if open == (_step_pulse != null):
		return
	if _step_pulse != null:
		_step_pulse.kill()
		_step_pulse = null
	if open:
		_step_pulse = create_tween().set_loops()
		_step_pulse.tween_method(_pulse_open_steps, 0.0, TAU, 1.6)


func _refresh_step(step: Control, caption: String, option: Dictionary) -> void:
	var chosen := not option.is_empty()
	var picture: TextureRect = step.get_node("Row/Thumb/Picture")
	var value: Label = step.get_node("Row/Texts/Value")
	(step.get_node("Row/Texts/Caption") as Label).text = caption
	(step.get_node("Row/Thumb/Placeholder") as Control).visible = not chosen
	picture.texture = load(option.art) if chosen else null
	value.text = _title_of(option) if chosen else _t("step_open")
	value.modulate = Color.WHITE if chosen else Color(1, 1, 1, 0.45)
	step.add_theme_stylebox_override("panel", _styles.step_done if chosen else _styles.step_open)


## The card icon of a step still open breathes, to show what is still needed.
func _pulse_open_steps(angle: float) -> void:
	for step: Control in [_character_step, _class_step]:
		var placeholder: Control = step.get_node("Row/Thumb/Placeholder")
		placeholder.modulate.a = 0.55 + 0.35 * sin(angle)


## Says what to do next, or what went wrong. A problem takes the place of the
## instructions, in red, until it is gone.
func _refresh_hint() -> void:
	var has_race := not _draft.race.is_empty()
	var has_class := not _draft.hero_class.is_empty()
	var style := "message"
	var icon: Texture2D = CARD_ICON
	if not _camera_problem.is_empty():
		style = "alert"
		_prompt.text = _t("prompt_problem")
		_hint.text = _camera_problem
	elif not _taken_notice.is_empty():
		style = "alert"
		_prompt.text = _t("prompt_taken")
		_hint.text = _taken_notice
	elif not has_race or not has_class:
		if has_race:
			_prompt.text = _t("prompt_class")
		elif has_class:
			_prompt.text = _t("prompt_character")
		else:
			_prompt.text = _t("prompt_both")
		_hint.text = _t("hint_show") if _camera_running else _t("camera_starting")
	elif _draft.name.is_empty():
		icon = PEN_ICON
		_prompt.text = _t("prompt_name")
		_hint.text = _t("hint_name")
	elif _draft.seat < 0:
		icon = null
		_prompt.text = _t("prompt_seat")
		_hint.text = _t("hint_seat")
	else:
		style = "ready"
		icon = null
		_prompt.text = _t("prompt_ready") % _draft.name
		_hint.text = _t("hint_edit")
	var alert := style == "alert"
	_message.add_theme_stylebox_override("panel", _styles[style])
	_message_alert.visible = alert
	_message_icon.texture = icon
	_message_icon.visible = not alert and icon != null
	if alert:
		_prompt.add_theme_color_override("font_color", Color(1.0, 0.72, 0.62))
		_hint.add_theme_color_override("font_color", Color(1.0, 0.86, 0.8))
	else:
		_prompt.remove_theme_color_override("font_color")
		_hint.remove_theme_color_override("font_color")
	# A new step pops the message, but typing the name, which changes it with every
	# letter, must not make it jump. Problems shake instead, see _show_taken().
	var shown := style + _hint.text
	if shown != _message_shown and not _message_shown.is_empty() and not alert and _view == View.EDITOR:
		_pop_control(_message, 1.04)
	_message_shown = shown


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
				# A hero without a seat yet calls for one.
				mode = SeatToken.Mode.SELECTABLE if _draft.seat < 0 else SeatToken.Mode.QUIET_SELECTABLE
		elif has_room or hero != null:
			mode = SeatToken.Mode.SELECTABLE
		token.set_mode(mode)


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


## degrees is how far it turns at first.
func _shake(control: Control, degrees := 7.0) -> void:
	var home := control.rotation_degrees
	control.pivot_offset = control.size / 2.0
	var shake := create_tween()
	for factor: float in [-1.0, 1.0, -0.7, 0.7, 0.0]:
		shake.tween_property(control, "rotation_degrees", home + degrees * factor, 0.06)


func _pop_control(control: Control, amount := 1.12) -> void:
	control.pivot_offset = control.size / 2.0
	control.scale = Vector2(amount, amount)
	create_tween().tween_property(control, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
