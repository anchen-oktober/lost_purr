extends Node3D
class_name CatVisionObject

@export var visible_in_normal: bool = false
@export var visible_in_cat_vision: bool = true

var _cat_vision_manager: Node

func _ready() -> void:
	add_to_group("cat_vision_objects")
	_cat_vision_manager = _find_cat_vision_manager()
	if _cat_vision_manager != null and _cat_vision_manager.has_signal("cat_state_changed"):
		_cat_vision_manager.connect("cat_state_changed", _on_cat_state_changed)
	_update_visibility()

func _on_cat_state_changed(_state: int) -> void:
	_update_visibility()

func _update_visibility() -> void:
	visible = visible_in_cat_vision if _is_cat_vision_active() else visible_in_normal

func _is_cat_vision_active() -> bool:
	if _cat_vision_manager == null:
		return false
	if _cat_vision_manager.has_method("get_cat_state"):
		return int(_cat_vision_manager.call("get_cat_state")) == 1
	return bool(_cat_vision_manager.get("is_cat_vision_enabled"))

func _find_cat_vision_manager() -> Node:
	var current_scene := get_tree().current_scene
	return current_scene.find_child("CatVisionManager", true, false) if current_scene != null else null
