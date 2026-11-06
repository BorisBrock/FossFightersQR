class_name ConfirmDialog
extends CanvasLayer
## Asks once more before something that cannot be undone. Set the text before adding it
## to the tree. Anything but the confirm button cancels: the other button, a tap beside
## the dialog, Escape and the back button of a phone. With extra_text, a second way to go
## on shows above the two buttons, across the whole dialog.

signal confirmed
signal extra_confirmed

var title := ""
var message := ""
var confirm_text := ""
var cancel_text := ""
## Leave empty for no extra button.
var extra_text := ""

@onready var _dim: Control = $Dim
@onready var _title: Label = $Dim/Center/Panel/Margin/Layout/Title
@onready var _message: Label = $Dim/Center/Panel/Margin/Layout/Message
@onready var _cancel: Button = $Dim/Center/Panel/Margin/Layout/Buttons/Cancel
@onready var _confirm: Button = $Dim/Center/Panel/Margin/Layout/Buttons/Confirm
@onready var _extra: Button = $Dim/Center/Panel/Margin/Layout/Extra


func _ready() -> void:
	add_to_group(MenuScreen.DIALOG_GROUP)
	_title.text = title
	_message.text = message
	_confirm.text = confirm_text
	_cancel.text = cancel_text
	_extra.text = extra_text
	_extra.visible = not extra_text.is_empty()
	_extra.pressed.connect(_on_extra_pressed)
	_cancel.pressed.connect(close)
	_confirm.pressed.connect(_on_confirm_pressed)
	_dim.gui_input.connect(_on_dim_input)
	_dim.modulate.a = 0.0
	create_tween().tween_property(_dim, "modulate:a", 1.0, 0.15)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	queue_free()


func _on_confirm_pressed() -> void:
	confirmed.emit()
	close()


func _on_extra_pressed() -> void:
	extra_confirmed.emit()
	close()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
