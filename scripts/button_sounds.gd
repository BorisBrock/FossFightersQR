extends Node
## Every button in the game clicks when it is pressed (assets/sounds/click.ogg, on the SFX
## bus). A button that plays a sound of its own when pressed opts out with
## ButtonSounds.silence(button), so the two do not sound together.

const SOUND := "res://assets/sounds/click.ogg"
const SILENT := &"silent_press"

var _player := AudioStreamPlayer.new()


func _ready() -> void:
	_player.stream = load(SOUND)
	_player.bus = &"SFX"
	_player.max_polyphony = 3
	add_child(_player)
	get_tree().node_added.connect(_on_node_added)


## Keeps the click off a button whose press already has a sound.
static func silence(button: BaseButton) -> void:
	button.set_meta(SILENT, true)


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	# A button that leaves the tree and comes back is added again, but connected once.
	if button != null and not button.has_meta(&"clicks"):
		button.set_meta(&"clicks", true)
		button.pressed.connect(_on_pressed.bind(button))


func _on_pressed(button: BaseButton) -> void:
	if not button.has_meta(SILENT):
		_player.play()
