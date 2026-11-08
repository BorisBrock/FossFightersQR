class_name Sfx
extends Node
## Short sound effects by name, from assets/sounds/<name>.wav, on the SFX bus, so the
## settings' volume applies. The sounds are made by tools/make_sounds.py; which event
## plays which is in docs/sounds.md.
##
## Each sound has its own player, so different sounds overlap, and the same one can
## overlap itself a few times, as hits that follow quickly do.

const FOLDER := "res://assets/sounds/"
const NAMES: Array[String] = [
	"turn", "choose", "select", "rejected", "lightning", "hit", "shield_block",
	"shield_break", "shields_up", "poison", "protect", "round", "boss_attack", "hurt",
	"heal", "victory", "defeat", "boss_appears",
]
const POLYPHONY := 3

var _players := {}


func _ready() -> void:
	# Loaded up front, so that the first time a sound plays it does not stutter.
	for sound in NAMES:
		var player := AudioStreamPlayer.new()
		player.name = sound.to_pascal_case()
		player.stream = stream(sound)
		player.bus = &"SFX"
		player.max_polyphony = POLYPHONY
		add_child(player)
		_players[sound] = player


func play(sound: String) -> void:
	var player: AudioStreamPlayer = _players.get(sound)
	if player == null:
		push_warning("Unknown sound '%s'" % sound)
		return
	player.play()


## The stream of a sound, for players of their own, such as the message box's.
static func stream(sound: String) -> AudioStream:
	return load(FOLDER + sound + ".wav")
