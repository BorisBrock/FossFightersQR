extends MenuScreen
## The end of a fight, won, lost or stopped: how it ended, and what the heroes and the boss
## did in it (Fight.stats). From top to bottom: the outcome over the boss, the team's
## numbers, the course of the fight as a chart, a row for each hero, and the way back to
## the table. Everything arrives one after the other, and the numbers count up.

const ONBOARDING_SCENE := "res://onboarding.tscn"
const GOLD := Color(0.98, 0.82, 0.48)
const CREAM := Color(0.95, 0.88, 0.74)
const FAINT := Color(0.72, 0.64, 0.5)
## The damage types, in the colours of their symbols on the cards (and their icons):
## melee crimson with a touch of pink, ranged yellow-orange, magic bright blue.
const TYPE_COLORS := {
	"melee": Color("#d6386a"),
	"ranged": Color("#f0a326"),
	"magic": Color("#3b9cf2"),
}
const TYPE_ICONS := {
	"melee": "res://assets/fight/icon_melee.svg",
	"ranged": "res://assets/fight/icon_ranged.svg",
	"magic": "res://assets/fight/icon_magic.svg",
}
const HEALTH_COLOR := Color("#c4922f")
const DAMAGE_COLOR := Color("#c8504a")
const ICONS := {
	"round": "res://assets/fight/icon_round.svg",
	"damage": "res://assets/fight/icon_damage.svg",
	"shield": "res://assets/fight/icon_shield.svg",
	"heal": "res://assets/fight/icon_heal.svg",
	"wound": "res://assets/fight/icon_wound.svg",
	"crown": "res://assets/fight/icon_crown.svg",
}
## How each outcome looks: the title's colour, the rays behind it, the boss and the
## particles.
const LOOKS := {
	FightStats.Outcome.WON: {
		"title": Color(0.98, 0.82, 0.48), "rays": Color(1.0, 0.8, 0.4), "rays_alpha": 0.55,
		"figure": Color(0.62, 0.58, 0.58, 0.6), "sparks": Color(1.0, 0.85, 0.45),
		"direction": Vector2(0, 1), "gravity": Vector2(0, 12), "area": Rect2(0.0, -0.02, 1.0, 0.0),
	},
	FightStats.Outcome.LOST: {
		"title": Color(1.0, 0.5, 0.42), "rays": Color(0.75, 0.12, 0.08), "rays_alpha": 0.5,
		"figure": Color(1.0, 0.62, 0.56, 0.8), "sparks": Color(1.0, 0.38, 0.22),
		"direction": Vector2(0, -1), "gravity": Vector2(0, -4), "area": Rect2(0.0, 1.02, 1.0, 0.0),
	},
	FightStats.Outcome.ABORTED: {
		"title": Color(0.78, 0.84, 0.95), "rays": Color(0.5, 0.6, 0.85), "rays_alpha": 0.0,
		"figure": Color(0.7, 0.74, 0.85, 0.5), "sparks": Color(0.75, 0.8, 0.95),
		"direction": Vector2(1, 0.1), "gravity": Vector2.ZERO, "area": Rect2(-0.05, 0.0, 0.0, 1.0),
	},
}
const TEXT := {
	"won": { "de": "Sieg!", "en": "Victory!" },
	"lost": { "de": "Niederlage", "en": "Defeat" },
	"aborted": { "de": "Rückzug", "en": "Retreat" },
	"won_line": { "de": "%s ist besiegt", "en": "%s is defeated" },
	"lost_line": { "de": "%s hat gesiegt", "en": "%s has won" },
	"aborted_line": { "de": "Der Kampf gegen %s wurde abgebrochen", "en": "The fight against %s was stopped" },
	"rounds": { "de": "Runden", "en": "Rounds" },
	"team_damage": { "de": "Schaden verursacht", "en": "Damage dealt" },
	"boss_damage": { "de": "Schaden erlitten", "en": "Damage taken" },
	"blocked": { "de": "Angriffe abgewehrt", "en": "Attacks blocked" },
	"course": { "de": "Verlauf des Kampfes", "en": "Course of the fight" },
	"best_round": { "de": "Beste Runde: %d", "en": "Best round: %d" },
	"health_legend": { "de": "Leben des Bosses", "en": "Boss health" },
	"damage_legend": { "de": "Schaden pro Runde", "en": "Damage per round" },
	"no_rounds": { "de": "Es wurde keine Runde gespielt.", "en": "No round was played." },
	"no_heroes": { "de": "Keine Helden am Tisch.", "en": "No heroes at the table." },
	"damage": { "de": "Schaden", "en": "damage" },
	"protection": { "de": "Schutz", "en": "protection" },
	"healing": { "de": "Heilung", "en": "healing" },
	"taken": { "de": "erlitten", "en": "taken" },
	"continue": { "de": "Zurück an den Tisch", "en": "Back to the table" },
}
## Titles for the heroes who did the most of something, in the order they are given out.
## Each hero gets one at most.
const AWARDS := [
	{ "stat": "damage", "title": { "de": "Bossbrecher", "en": "Boss Breaker" } },
	{ "stat": "protection", "title": { "de": "Schildwall", "en": "Shield Wall" } },
	{ "stat": "healing", "title": { "de": "Lebensspender", "en": "Life Giver" } },
	{ "stat": "damage_taken", "title": { "de": "Eisenhaut", "en": "Iron Hide" } },
	{ "stat": "best_card", "title": { "de": "Wuchtschlag", "en": "Heavy Hitter" } },
	{ "stat": "cards", "title": { "de": "Kartenkünstler", "en": "Card Sharp" } },
]
const PORTRAIT_SIZE := 84.0
## Taps on the button before this do nothing, so that a tap meant for the fight's last
## message does not skip the whole screen.
const CONTINUE_DELAY_SEC := 1.2

## The fight that ended. Without one, as when run from the editor, a made-up fight shows.
var fight: Fight
## Replaced by tests, so that they do not touch the real party.
var party_path := Party.SAVE_PATH
## By hero: the title they earned, or none.
var awards := {}

## Labels whose text depends on the language, with a Callable giving it.
var _texts: Array[Array] = []
var _chart: CourseChart
var _rows: Array[Control] = []
var _power_bars: Array[PowerBars] = []
var _tiles: Array[Control] = []
var _shown_msec := 0

@onready var _background: TextureRect = $Background
@onready var _rays: ColorRect = $Rays
@onready var _figure: TextureRect = $Figure
@onready var _sparks: CPUParticles2D = $Sparks
@onready var _header: Control = $Margin/Layout/Header
@onready var _title: Label = $Margin/Layout/Header/Title
@onready var _subtitle: Label = $Margin/Layout/Header/Subtitle
@onready var _tile_row: HBoxContainer = $Margin/Layout/Tiles
@onready var _course: PanelContainer = $Margin/Layout/Course
@onready var _heroes: PanelContainer = $Margin/Layout/Heroes
@onready var _continue: Button = $Margin/Layout/Continue
@onready var _fanfare: AudioStreamPlayer = $Fanfare


func _ready() -> void:
	super()
	if fight == null:
		fight = _example_fight()
	awards = _give_awards()
	_shown_msec = Time.get_ticks_msec()
	_show_scene()
	_make_header()
	_make_tiles()
	_make_course()
	_make_heroes()
	_add_text(_continue, func() -> String: return _t("continue"))
	_continue.pressed.connect(go_back)
	resized.connect(_place_sparks)
	_place_sparks()
	_refresh_text()
	_animate()


func _notification(what: int) -> void:
	super(what)
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_text()


## Back to the table, where the players can change heroes or fight again.
func go_back() -> void:
	if Time.get_ticks_msec() - _shown_msec < CONTINUE_DELAY_SEC * 1000:
		return
	var onboarding: Node = load(ONBOARDING_SCENE).instantiate()
	# The logo was shown when the app started.
	onboarding.show_splash = false
	leave_to(onboarding)


func outcome() -> FightStats.Outcome:
	var how := fight.stats.outcome
	return FightStats.Outcome.ABORTED if how == FightStats.Outcome.NONE else how


func _t(key: String) -> String:
	return CardDatabase.localized(TEXT[key], TranslationServer.get_locale())


func _localized(text: Dictionary) -> String:
	return CardDatabase.localized(text, TranslationServer.get_locale())


func _add_text(control: Control, text: Callable) -> void:
	_texts.append([control, text])


func _refresh_text() -> void:
	for entry: Array in _texts:
		var control: Control = entry[0]
		if is_instance_valid(control):
			control.text = entry[1].call()
	if _chart != null:
		_chart.empty_text = _t("no_rounds")
		_chart.queue_redraw()


#region Building the screen
func _show_scene() -> void:
	var boss := fight.boss
	var look: Dictionary = LOOKS[outcome()]
	_background.texture = load(boss.background)
	(_background.material as ShaderMaterial).set_shader_parameter("mist_color", boss.mist_color)
	_figure.texture = load(boss.figure)
	_figure.self_modulate = look.figure
	(_rays.material as ShaderMaterial).set_shader_parameter("tint", look.rays)
	_rays.visible = look.rays_alpha > 0.0
	_sparks.direction = look.direction
	_sparks.gravity = look.gravity
	_sparks.spread = 25.0 if outcome() != FightStats.Outcome.ABORTED else 15.0
	_sparks.initial_velocity_min = 20.0
	_sparks.initial_velocity_max = 60.0
	_sparks.scale_amount_min = 0.15
	_sparks.scale_amount_max = 0.45
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.75, 1.0])
	var color: Color = look.sparks
	ramp.colors = PackedColorArray([Color(color, 0.0), Color(color, 0.85), Color(color, 0.5), Color(color, 0.0)])
	_sparks.color_ramp = ramp


func _place_sparks() -> void:
	var area: Rect2 = LOOKS[outcome()].area
	_sparks.position = (area.position + area.size / 2.0) * size
	_sparks.emission_rect_extents = (area.size * size / 2.0).max(Vector2(8, 8))


func _make_header() -> void:
	var look: Dictionary = LOOKS[outcome()]
	_title.add_theme_color_override("font_color", look.title)
	var key: String = { FightStats.Outcome.WON: "won", FightStats.Outcome.LOST: "lost", FightStats.Outcome.ABORTED: "aborted" }[outcome()]
	_add_text(_title, func() -> String: return _t(key))
	_add_text(_subtitle, func() -> String:
		var line := _t(key + "_line") % _localized(fight.boss.title)
		return "%s · %s" % [line, _localized(Bosses.DIFFICULTIES[fight.difficulty].title)])


func _make_tiles() -> void:
	var stats := fight.stats
	_tiles.append(_tile("round", stats.rounds, "", "rounds"))
	_tiles.append(_tile("damage", stats.team_damage(), "", "team_damage"))
	_tiles.append(_tile("wound", stats.boss_damage(), "", "boss_damage"))
	_tiles.append(_tile("shield", stats.attacks_blocked, "/%d" % stats.attacks, "blocked"))


func _tile(icon: String, value: int, suffix: String, caption: String) -> Control:
	var tile := PanelContainer.new()
	tile.add_theme_stylebox_override("panel", _plate(14.0, 10.0))
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(column)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	row.add_child(_icon(ICONS[icon], 34))
	var number := Label.new()
	number.name = "Value"
	number.theme_type_variation = &"Title"
	number.add_theme_font_size_override("font_size", 38)
	number.set_meta("value", value)
	number.set_meta("suffix", suffix)
	number.text = "0" + suffix
	row.add_child(number)
	var label := Label.new()
	label.theme_type_variation = &"Hint"
	label.add_theme_font_size_override("font_size", 17)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(label)
	_add_text(label, func() -> String: return _t(caption))
	_tile_row.add_child(tile)
	return tile


func _make_course() -> void:
	var stats := fight.stats
	var margin := _margin(18, 14)
	_course.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	var heading := Label.new()
	heading.theme_type_variation = &"Heading"
	heading.add_theme_font_size_override("font_size", 25)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(heading)
	_add_text(heading, func() -> String: return _t("course"))
	if stats.best_round() > 0:
		var best := Label.new()
		best.theme_type_variation = &"Hint"
		best.add_theme_font_size_override("font_size", 19)
		best.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(best)
		_add_text(best, func() -> String: return _t("best_round") % stats.best_round())

	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 22)
	column.add_child(legend)
	legend.add_child(_legend_entry(LegendKey.Shape.LINE, HEALTH_COLOR, "health_legend"))
	legend.add_child(_legend_entry(LegendKey.Shape.BAR, DAMAGE_COLOR, "damage_legend"))

	_chart = CourseChart.new()
	_chart.health = stats.health_by_round
	_chart.damage = stats.damage_by_round
	_chart.max_health = maxi(1, stats.max_health)
	_chart.custom_minimum_size = Vector2(0, 130)
	_chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_chart)


func _legend_entry(shape: LegendKey.Shape, color: Color, key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var mark := LegendKey.new()
	mark.shape = shape
	mark.color = color
	mark.custom_minimum_size = Vector2(26, 18)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(mark)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", CREAM)
	row.add_child(label)
	_add_text(label, func() -> String: return _t(key))
	return row


func _make_heroes() -> void:
	var margin := _margin(16, 12)
	_heroes.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	margin.add_child(column)
	if fight.heroes.is_empty():
		var none := Label.new()
		none.theme_type_variation = &"Hint"
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(none)
		_add_text(none, func() -> String: return _t("no_heroes"))
		return
	var most_power := 1
	for hero in fight.heroes:
		for kind: String in Fight.DAMAGE_TYPES:
			most_power = maxi(most_power, fight.stats.of(hero).power.get(kind, 0))
	for i in fight.heroes.size():
		if i > 0:
			var line := ColorRect.new()
			line.color = Color(GOLD, 0.18)
			line.custom_minimum_size = Vector2(0, 1)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var spaced := MarginContainer.new()
			spaced.add_theme_constant_override("margin_top", 8)
			spaced.add_theme_constant_override("margin_bottom", 8)
			spaced.add_theme_constant_override("margin_left", PORTRAIT_SIZE + 14)
			spaced.add_child(line)
			column.add_child(spaced)
		var row := _hero_row(fight.heroes[i], most_power)
		column.add_child(row)
		_rows.append(row)


func _hero_row(hero: FightHero, most_power: int) -> Control:
	var stats := fight.stats.of(hero)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var portrait_box := Control.new()
	portrait_box.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait := TextureRect.new()
	portrait.texture = load(HeroOptions.RACES[hero.hero.race].art)
	portrait.material = PortraitMaterial.new(0.5, 0.05)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_box.add_child(portrait)
	var crest := TextureRect.new()
	crest.texture = load(HeroOptions.CLASSES[hero.hero.hero_class].art)
	crest.material = PortraitMaterial.new(0.5, 0.08)
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	crest.position = Vector2(PORTRAIT_SIZE - 32, PORTRAIT_SIZE - 32)
	crest.size = Vector2(36, 36)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_box.add_child(crest)
	row.add_child(portrait_box)

	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	middle.add_theme_constant_override("separation", 2)
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(middle)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(top)
	var hero_name := Label.new()
	hero_name.text = hero.name
	hero_name.theme_type_variation = &"Heading"
	hero_name.add_theme_font_size_override("font_size", 27)
	hero_name.clip_text = true
	hero_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hero_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(hero_name)
	if awards.has(hero):
		top.add_child(_award_chip(awards[hero]))
	var numbers := HBoxContainer.new()
	numbers.add_theme_constant_override("separation", 6)
	numbers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(numbers)
	numbers.add_child(_mini_stat("damage", stats.damage, "damage"))
	numbers.add_child(_mini_stat("shield", stats.protection, "protection"))
	numbers.add_child(_mini_stat("heal", stats.healing, "healing"))
	numbers.add_child(_mini_stat("wound", stats.damage_taken, "taken"))

	var bars := PowerBars.new()
	bars.power = stats.power
	bars.most = most_power
	bars.custom_minimum_size = Vector2(128, PORTRAIT_SIZE)
	bars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bars)
	_power_bars.append(bars)
	return row


func _award_chip(award: Dictionary) -> Control:
	var chip := PanelContainer.new()
	chip.name = "Award"
	var style := _plate(10.0, 2.0, 12)
	style.bg_color = Color(0.35, 0.22, 0.06, 0.9)
	chip.add_theme_stylebox_override("panel", style)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	row.add_child(_icon(ICONS.crown, 22))
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", GOLD)
	row.add_child(label)
	_add_text(label, func() -> String: return _localized(award.title))
	return chip


func _mini_stat(icon: String, value: int, caption: String) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", -4)
	column.custom_minimum_size = Vector2(84, 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if value == 0:
		column.modulate.a = 0.5
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	row.add_child(_icon(ICONS[icon], 24))
	var number := Label.new()
	number.name = "Value"
	number.theme_type_variation = &"Title"
	number.add_theme_font_size_override("font_size", 26)
	number.set_meta("value", value)
	number.set_meta("suffix", "")
	number.text = "0"
	row.add_child(number)
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", FAINT)
	column.add_child(label)
	_add_text(label, func() -> String: return _t(caption))
	return column


func _plate(horizontal: float, vertical: float, radius := 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.085, 0.05, 0.035, 0.84)
	style.border_color = Color(0.72, 0.54, 0.22, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style


func _margin(horizontal: int, vertical: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", horizontal)
	margin.add_theme_constant_override("margin_right", horizontal)
	margin.add_theme_constant_override("margin_top", vertical)
	margin.add_theme_constant_override("margin_bottom", vertical)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return margin


func _icon(path: String, icon_size: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = load(path)
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon
#endregion


## Who did the most of what. A title only goes to a hero who did some of it, and more
## than everyone else.
func _give_awards() -> Dictionary:
	var given := {}
	for award: Dictionary in AWARDS:
		var best: FightHero = null
		var best_value := 0
		var tied := false
		for hero in fight.heroes:
			var value: int = fight.stats.of(hero).get(award.stat)
			if value > best_value:
				best = hero
				best_value = value
				tied = false
			elif value == best_value and value > 0:
				tied = true
		if best != null and not tied and not given.has(best):
			given[best] = award
	return given


#region Animation
func _animate() -> void:
	var won := outcome() == FightStats.Outcome.WON
	# The outcome lands first.
	_title.scale = Vector2(2.2, 2.2)
	_title.modulate.a = 0.0
	var title := create_tween().set_parallel()
	title.tween_callback(func() -> void: _title.pivot_offset = _title.size / 2.0).set_delay(0.2)
	title.tween_property(_title, "scale", Vector2.ONE, 0.6).set_delay(0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	title.tween_property(_title, "modulate:a", 1.0, 0.3).set_delay(0.25)
	_appear(_subtitle, 0.7, Vector2(0, 14))
	if won:
		_fanfare.play.call_deferred()
	# The boss sinks away when beaten, and rises over the heroes when it won.
	var drift := 40.0 if won else -30.0
	_figure.modulate.a = 0.0
	var figure := create_tween().set_parallel()
	figure.tween_property(_figure, "modulate:a", 1.0, 1.2)
	for side: String in ["offset_top", "offset_bottom"]:
		figure.tween_property(_figure, side, _figure.get(side) + drift, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if _rays.visible:
		_rays.modulate.a = 0.0
		create_tween().tween_property(_rays, "modulate:a", LOOKS[outcome()].rays_alpha, 1.4).set_delay(0.2)

	for i in _tiles.size():
		var tile := _tiles[i]
		var delay := 1.0 + i * 0.12
		_pop_in(tile, delay)
		_count_up(tile.find_child("Value", true, false), delay + 0.1, 0.9)

	_appear(_course, 1.6, Vector2(0, 30))
	create_tween().tween_property(_chart, "progress", 1.0, 1.6).set_delay(1.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	for i in _rows.size():
		var row := _rows[i]
		var delay := 2.4 + i * 0.18
		_appear(row, delay, Vector2(60, 0))
		for value: Label in row.find_children("Value", "Label", true, false):
			_count_up(value, delay + 0.2, 0.8)
		create_tween().tween_property(_power_bars[i], "progress", 1.0, 0.8).set_delay(delay + 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var chip := row.find_child("Award", true, false) as Control
		if chip != null:
			_pop_in(chip, delay + 0.9)
	_appear(_heroes, 2.2, Vector2.ZERO)
	_appear(_continue, 2.6 + _rows.size() * 0.18, Vector2(0, 20))


## Fades control in, sliding from offset to where it belongs.
func _appear(control: Control, delay: float, offset: Vector2) -> void:
	control.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(control, "modulate:a", 1.0, 0.45).set_delay(delay)
	if offset != Vector2.ZERO:
		# Containers have placed their children by then, and leave them alone until
		# the screen changes size.
		tween.tween_callback(_slide_in.bind(control, offset)).set_delay(delay)


func _slide_in(control: Control, offset: Vector2) -> void:
	var end := control.position
	control.position = end + offset
	create_tween().tween_property(control, "position", end, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _pop_in(control: Control, delay: float) -> void:
	control.modulate.a = 0.0
	control.scale = Vector2(0.6, 0.6)
	var tween := create_tween().set_parallel()
	tween.tween_callback(func() -> void: control.pivot_offset = control.size / 2.0).set_delay(delay)
	tween.tween_property(control, "modulate:a", 1.0, 0.25).set_delay(delay)
	tween.tween_property(control, "scale", Vector2.ONE, 0.45).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _count_up(label: Label, delay: float, duration: float) -> void:
	if label == null:
		return
	var target: int = label.get_meta("value", 0)
	var suffix: String = label.get_meta("suffix", "")
	if target == 0:
		label.text = "0" + suffix
		return
	var tween := create_tween()
	tween.tween_method(func(value: float) -> void: label.text = str(roundi(value)) + suffix, 0.0, float(target), duration).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
#endregion


## A fight to show when the screen runs on its own, as from the editor.
func _example_fight() -> Fight:
	var party := Party.load_file(party_path)
	if party.heroes.is_empty():
		for entry: Array in [["Rosie", "halfling", "thief", 1], ["Borin", "dwarf", "warrior", 3], ["Ivy", "dryad", "druid", 5]]:
			var hero := Party.Hero.new()
			hero.name = entry[0]
			hero.race = entry[1]
			hero.hero_class = entry[2]
			hero.seat = entry[3]
			party.heroes.append(hero)
	var boss_id := Encounter.boss if Bosses.has(Encounter.boss) else Bosses.IDS[0]
	var example := Fight.new(Bosses.create(boss_id), Encounter.difficulty, party.heroes)
	var stats := example.stats
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var health := example.max_health
	var round_number := 0
	while health > 0:
		round_number += 1
		stats.round_started(round_number)
		for hero in example.heroes:
			var hero_stats := stats.of(hero)
			for kind: String in Fight.DAMAGE_TYPES:
				if rng.randf() < 0.5:
					stats.power_played(hero, kind, rng.randi_range(1, 4))
			var dealt := mini(health, rng.randi_range(0, 6))
			health -= dealt
			stats.damage_dealt(dealt, rng.randi_range(0, 2), CardPlay.new(hero, Card.new()))
			hero_stats.cards += 3
			hero_stats.best_card = maxi(hero_stats.best_card, dealt)
			if rng.randf() < 0.4:
				stats.protected(hero, rng.randi_range(1, 3))
			if rng.randf() < 0.3:
				stats.healed(hero, rng.randi_range(2, 5))
			stats.attack_planned(hero, 3)
			var left := rng.randi_range(0, 4)
			stats.attack_resolved(hero, left)
			stats.hero_hit(hero, left, 0)
			if health == 0:
				break
		if health > 0:
			stats.round_ended(health)
	example.health = health
	stats.finished(FightStats.Outcome.WON, health)
	return example


## The boss's health over the rounds as a line, with the damage of each round as bars
## below it, on the same scale.
class CourseChart extends Control:
	var health: Array[int] = []
	var damage: Array[int] = []
	var max_health := 1
	var empty_text := ""
	## How much of the chart is drawn, from 0 to 1.
	var progress := 0.0:
		set(value):
			progress = value
			queue_redraw()

	const AXIS := Color(0.95, 0.88, 0.74, 0.16)
	const LABEL := Color(0.82, 0.74, 0.6)
	const SURFACE := Color(0.085, 0.05, 0.035)
	const LEFT := 40.0
	const BOTTOM := 26.0
	const TOP := 16.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var font := get_theme_font("font", "Label")
		var font_size := 16
		var plot := Rect2(LEFT, TOP, maxf(1.0, size.x - LEFT - 10.0), maxf(1.0, size.y - TOP - BOTTOM))
		var rounds := damage.size()
		# Grid: the boss's full health, half and nothing.
		for share: float in [0.0, 0.5, 1.0]:
			var y := plot.end.y - share * plot.size.y
			draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), AXIS, 1.0)
			var text := str(roundi(max_health * share))
			draw_string(font, Vector2(0, y + 5), text, HORIZONTAL_ALIGNMENT_RIGHT, LEFT - 8, font_size, LABEL)
		if rounds == 0:
			draw_string(font, Vector2(plot.position.x, plot.get_center().y + 6), empty_text, HORIZONTAL_ALIGNMENT_CENTER, plot.size.x, 20, LABEL)
			return
		var step := plot.size.x / rounds
		var shown := progress * rounds
		var label_every := maxi(1, ceili(rounds / 12.0))
		# The damage of each round, as a bar in the middle of the round.
		var bar_width := clampf(step * 0.42, 6.0, 34.0)
		for i in rounds:
			var grown := clampf(shown - i, 0.0, 1.0)
			var center := plot.position.x + step * (i + 0.5)
			if i % label_every == 0:
				draw_string(font, Vector2(center - 20, plot.end.y + 20), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 40, font_size, LABEL)
			if damage[i] <= 0 or grown <= 0.0:
				continue
			var height := damage[i] / float(max_health) * plot.size.y * grown
			var bar := Rect2(center - bar_width / 2.0, plot.end.y - height, bar_width, height)
			_rounded_top(bar, DAMAGE_COLOR)
		# The boss's health: where it started and how it stood after each round.
		var points := PackedVector2Array()
		var count := mini(health.size(), rounds + 1)
		for i in count:
			var share := clampf(health[i] / float(max_health), 0.0, 1.0)
			points.append(Vector2(plot.position.x + step * i, plot.end.y - share * plot.size.y))
		var drawn := PackedVector2Array()
		for i in points.size():
			if i <= shown:
				drawn.append(points[i])
			elif i - 1 < shown:
				drawn.append(points[i - 1].lerp(points[i], shown - (i - 1)))
				break
		if drawn.size() >= 2:
			var area := drawn.duplicate()
			area.append(Vector2(drawn[-1].x, plot.end.y))
			area.append(Vector2(drawn[0].x, plot.end.y))
			draw_colored_polygon(area, Color(HEALTH_COLOR, 0.14))
			draw_polyline(drawn, HEALTH_COLOR, 3.0, true)
		for i in points.size():
			if i > shown:
				break
			draw_circle(points[i], 7.0, SURFACE)
			draw_circle(points[i], 5.0, HEALTH_COLOR)
		# Where the boss's health ended, labelled once it is drawn.
		if progress >= 1.0 and not points.is_empty():
			var last := points[-1]
			var text := str(health[count - 1])
			var above := last.y - 12.0 if last.y > plot.position.y + 24.0 else last.y + 26.0
			draw_string(font, Vector2(last.x - 60, above), text, HORIZONTAL_ALIGNMENT_RIGHT, 52, 20, Color(0.98, 0.82, 0.48))

	func _rounded_top(rect: Rect2, color: Color) -> void:
		var radius := minf(4.0, minf(rect.size.x / 2.0, rect.size.y))
		draw_rect(Rect2(rect.position.x, rect.position.y + radius, rect.size.x, rect.size.y - radius), color)
		draw_rect(Rect2(rect.position.x + radius, rect.position.y, rect.size.x - radius * 2.0, radius), color)
		draw_circle(rect.position + Vector2(radius, radius), radius, color)
		draw_circle(rect.position + Vector2(rect.size.x - radius, radius), radius, color)


## The strength of the attack and support symbols a hero played, by damage type, as three
## bars with their value above and the type's icon below. All heroes share a scale.
class PowerBars extends Control:
	var power := {}
	var most := 1
	var progress := 0.0:
		set(value):
			progress = value
			queue_redraw()

	const ICON := 24.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for kind in Fight.DAMAGE_TYPES:
			var icon := TextureRect.new()
			icon.texture = load(TYPE_ICONS[kind])
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(icon)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			var slot := size.x / Fight.DAMAGE_TYPES.size()
			for i in get_child_count():
				var icon := get_child(i) as Control
				icon.position = Vector2(slot * (i + 0.5) - ICON / 2.0, size.y - ICON)
				icon.size = Vector2(ICON, ICON)

	func _draw() -> void:
		var font := get_theme_font("font", "Label")
		var slot := size.x / Fight.DAMAGE_TYPES.size()
		var top := 20.0
		var bottom := size.y - ICON - 4.0
		draw_line(Vector2(4, bottom), Vector2(size.x - 4, bottom), Color(0.95, 0.88, 0.74, 0.2), 1.0)
		for i in Fight.DAMAGE_TYPES.size():
			var kind: String = Fight.DAMAGE_TYPES[i]
			var value: int = power.get(kind, 0)
			var center := slot * (i + 0.5)
			(get_child(i) as Control).modulate.a = 1.0 if value > 0 else 0.4
			var height := (bottom - top) * value / float(maxi(1, most)) * progress
			if value > 0:
				var width := 18.0
				var bar := Rect2(center - width / 2.0, bottom - height, width, height)
				var radius := minf(4.0, height)
				draw_rect(Rect2(bar.position.x, bar.position.y + radius, width, maxf(0.0, height - radius)), TYPE_COLORS[kind])
				draw_rect(Rect2(bar.position.x + radius, bar.position.y, width - radius * 2.0, radius), TYPE_COLORS[kind])
				draw_circle(bar.position + Vector2(radius, radius), radius, TYPE_COLORS[kind])
				draw_circle(bar.position + Vector2(width - radius, radius), radius, TYPE_COLORS[kind])
			var label_y := bottom - height - 4.0
			draw_string(font, Vector2(center - 20, label_y), str(roundi(value * progress)), HORIZONTAL_ALIGNMENT_CENTER, 40, 17, Color(0.95, 0.88, 0.74, 1.0 if value > 0 else 0.45))


## The small key in the chart's legend: a line with a dot, or a bar.
class LegendKey extends Control:
	enum Shape { LINE, BAR }
	var shape := Shape.LINE
	var color := Color.WHITE

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var middle := size.y / 2.0
		if shape == Shape.LINE:
			draw_line(Vector2(0, middle), Vector2(size.x, middle), color, 3.0, true)
			draw_circle(Vector2(size.x / 2.0, middle), 5.0, color)
		else:
			draw_rect(Rect2(size.x / 2.0 - 6.0, 2.0, 12.0, size.y - 2.0), color)
