class_name Sfx
extends Node
## Short sound effects by name, from assets/sounds/<name>.ogg, on the SFX bus, so the
## settings' volume applies. Which event plays which is in docs/sounds.md.
##
## Each sound has its own player, so different sounds overlap, and the same one can
## overlap itself a few times, as hits that follow quickly do.

const FOLDER := "res://assets/sounds/"
const NAMES: Array[String] = [
	"turn", "choose", "select", "rejected", "lightning", "hit", "shield_block",
	"shield_break", "shields_up", "poison", "protect", "round", "boss_attack", "hurt",
	"heal", "victory", "defeat", "boss_appears", "magic_hit", "arrow_hit", "slash",
]
## Enough for a volley of arrows or bolts of magic, whose hits follow closely.
const POLYPHONY := 6

var _players := {}
## A boss's own sounds, by the name of the sound they replace (Boss.sounds).
var _overrides := {}


func _ready() -> void:
	# Loaded up front, so that the first time a sound plays it does not stutter.
	for sound in NAMES:
		_add_player(sound)


## A boss's own sounds play instead of the usual ones: { usual name: own name }, all
## loaded up front. Message ids among the keys do no harm: no sound has their name. A
## name that is not in NAMES (such as "boss_sinks") plays only if it is overridden.
func override(sounds: Dictionary) -> void:
	for sound: String in sounds:
		var own: String = sounds[sound]
		if not _players.has(own) and ResourceLoader.exists(FOLDER + own + ".ogg"):
			_add_player(own)
		_overrides[sound] = own


## Whether play(sound) plays something.
func has(sound: String) -> bool:
	return _players.has(_overrides.get(sound, sound))


## pitch varies a sound that plays again and again, such as the hits of a volley.
func play(sound: String, pitch := 1.0) -> void:
	var player: AudioStreamPlayer = _players.get(_overrides.get(sound, sound))
	if player == null:
		push_warning("Unknown sound '%s'" % sound)
		return
	player.pitch_scale = pitch
	player.play()


func _add_player(sound: String) -> void:
	var player := AudioStreamPlayer.new()
	player.name = sound.to_pascal_case()
	player.stream = stream(sound)
	player.bus = &"SFX"
	player.max_polyphony = POLYPHONY
	add_child(player)
	_players[sound] = player


## The stream of a sound, for players of their own, such as the message box's.
static func stream(sound: String) -> AudioStream:
	return load(FOLDER + sound + ".ogg")
