extends Node
## Loads every script and scene of the project and fails if one of them does not compile or load.
## Catches errors in code no test runs. Runs as a scene, because the scripts use the autoloads:
## godot --headless res://tests/check_project.tscn

const SKIP_DIRS := ["res://.godot", "res://addons", "res://native", "res://android"]

var _failures := 0
var _checked := 0


func _ready() -> void:
	_check_dir("res://")
	print("check_project: %d files, %s" % [_checked, "PASSED" if _failures == 0 else "%d FAILED" % _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check_dir(dir_path: String) -> void:
	for skip: String in SKIP_DIRS:
		if dir_path.trim_suffix("/") == skip:
			return
	for file: String in DirAccess.get_files_at(dir_path):
		var path := dir_path.path_join(file)
		if file.ends_with(".gd"):
			_check_script(path)
		elif file.ends_with(".tscn"):
			_check_scene(path)
	for sub: String in DirAccess.get_directories_at(dir_path):
		if not FileAccess.file_exists(dir_path.path_join(sub).path_join(".gdignore")):
			_check_dir(dir_path.path_join(sub))


func _check_script(path: String) -> void:
	if path == get_script().resource_path:
		return
	_checked += 1
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		_fail(path, "does not compile")


func _check_scene(path: String) -> void:
	_checked += 1
	var scene := load(path) as PackedScene
	if scene == null or not scene.can_instantiate():
		_fail(path, "does not load")


func _fail(path: String, what: String) -> void:
	_failures += 1
	printerr("FAIL  %s %s" % [path, what])
