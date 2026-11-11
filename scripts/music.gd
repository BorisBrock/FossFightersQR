extends AudioStreamPlayer
## The music, an autoload that plays on through scene changes. The tavern track plays in the
## menus, the swamp loop during a boss fight (see BossFight).

const TAVERN: AudioStream = preload("res://assets/music/boss_fighters.mp3")
const SWAMP: AudioStream = preload("res://assets/sounds/loop_swamp.ogg")
## How loud each track plays. The tavern track is mastered to -14.5 LUFS. The swamp loop is
## a quiet mono recording (about -43 LUFS as played on both speakers), so it gets 28.5 dB
## more to sound as loud: its peaks stay below 0 dBFS even at full music volume.
const VOLUMES_DB := { TAVERN: -8.0, SWAMP: 20.5 }


## Switches to the tavern track, from its start, unless it plays already.
func play_tavern() -> void:
	_switch_to(TAVERN)


## Switches to the swamp loop of the boss fight, unless it plays already.
func play_fight() -> void:
	_switch_to(SWAMP)


func _switch_to(track: AudioStream) -> void:
	if stream == track and playing:
		return
	stream = track
	volume_db = VOLUMES_DB[track]
	play()
