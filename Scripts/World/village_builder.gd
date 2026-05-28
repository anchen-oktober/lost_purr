@tool
extends Node3D

var _rebuild_in_editor: bool = false

@export var rebuild_in_editor: bool:
	set(value):
		_rebuild_in_editor = false
		if Engine.is_editor_hint() and is_inside_tree():
			build_village()
	get:
		return _rebuild_in_editor

func _ready() -> void:
	build_village()

func build_village() -> void:
	for child in get_children():
		if child.has_method("build"):
			child.call("build")
