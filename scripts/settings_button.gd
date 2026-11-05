extends BaseButton
## Opens the settings dialog. Any button can use this script, so it can look different
## from scene to scene.

const DIALOG := preload("res://settings_dialog.tscn")


func _ready() -> void:
	pressed.connect(func() -> void: add_child(DIALOG.instantiate()))
