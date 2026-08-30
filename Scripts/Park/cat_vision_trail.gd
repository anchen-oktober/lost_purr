extends Node3D
class_name CatVisionTrail
enum TrailType { OWNER, FALSE }
@export var trail_type: TrailType = TrailType.OWNER
@export var visible_only_in_cat_vision := true
@export var active := true
@export var event_id := ""
@export var one_shot := false
@export var memory_audio: AudioStream
@export var memory_visual: PackedScene
@export var journal_entry_id := ""
func _ready() -> void:
	var manager := get_tree().current_scene.find_child("CatVisionManager", true, false)
	if manager != null and manager.has_signal("cat_state_changed"):
		manager.cat_state_changed.connect(_on_cat_state_changed)
		_on_cat_state_changed(int(manager.call("get_cat_state")))
func _on_cat_state_changed(state: int) -> void: visible = active and (not visible_only_in_cat_vision or state == 1)
