class_name PortraitMaterial
extends ShaderMaterial
## Rounds off a picture and puts a metal ring around it. See portrait.gdshader.

const SHADER := preload("res://assets/onboarding/shaders/portrait.gdshader")


func _init(corner := 0.5, ring_width := 0.03) -> void:
	shader = SHADER
	set_shader_parameter("corner", corner)
	set_shader_parameter("ring_width", ring_width)
