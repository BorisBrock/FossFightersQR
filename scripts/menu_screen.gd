class_name MenuScreen
extends Control
## What the screens after the table have in common: they fade in from
## black and out to the next screen, and Escape and the back button of a phone lead back
## to the screen before, as the Back button on screen does.

const FADE_SEC := 0.3
## Dialogs join this group while open, so that the back button of a phone and Escape are
## left to them.
const DIALOG_GROUP := &"dialog"

## Replaced by tests, which run a screen inside their own scene.
var change_scene := func(next: Node) -> void: get_tree().change_scene_to_node(next)

var _leaving := false

@onready var _fade: ColorRect = $Fade


func _enter_tree() -> void:
	get_tree().quit_on_go_back = false


func _exit_tree() -> void:
	get_tree().quit_on_go_back = true


## Subclasses have to call this with super().
func _ready() -> void:
	_fade.show()
	_fade.modulate.a = 1.0
	var fade := create_tween()
	fade.tween_property(_fade, "modulate:a", 0.0, FADE_SEC)
	fade.tween_callback(_fade.hide)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and not _dialog_open():
		go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _dialog_open():
		get_viewport().set_input_as_handled()
		go_back()


## Leads to the screen before. Every screen says where that is.
func go_back() -> void:
	pass


## Fades out and replaces this screen with next. Taps while fading do nothing.
func leave_to(next: Node, fade_sec := FADE_SEC) -> void:
	if _leaving:
		next.free()
		return
	_leaving = true
	_fade.show()
	_fade.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(_fade, "modulate:a", 1.0, fade_sec)
	await fade.finished
	change_scene.call(next)


## The back button of a phone, or Escape, should only close the dialog then.
## The screen hears the back button first, as notifications go from parents to children.
func _dialog_open() -> bool:
	return is_dialog_open(get_tree())


## For screens that are not a MenuScreen but handle the back button, too.
static func is_dialog_open(tree: SceneTree) -> bool:
	return tree.get_node_count_in_group(DIALOG_GROUP) > 0
