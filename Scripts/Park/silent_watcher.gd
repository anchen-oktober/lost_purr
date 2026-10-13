extends Node3D
class_name SilentWatcher
@export var position_targets: Array[NodePath] = []
@export var detection_radius := 5.0
@export var move_after_hidden_seconds := 1.25
@export var fear_damage := 6.0
var _target_index := 0
var _hidden_for := 0.0
func _ready() -> void:
	add_to_group("silent")
	if not position_targets.is_empty():
		var target := get_node_or_null(position_targets[0]) as Node3D
		if target != null: global_transform = target.global_transform
func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var screen_position: Vector2 = camera.unproject_position(global_position)
	var on_screen: bool = not camera.is_position_behind(global_position) and screen_position.x >= 0.0 and screen_position.x <= get_viewport().size.x and screen_position.y >= 0.0 and screen_position.y <= get_viewport().size.y
	if on_screen: _hidden_for = 0.0; return
	_hidden_for += delta
	if _hidden_for >= move_after_hidden_seconds and position_targets.size() > 1:
		_hidden_for = 0.0; _target_index = (_target_index + 1) % position_targets.size()
		var target := get_node_or_null(position_targets[_target_index]) as Node3D
		if target != null: global_transform = target.global_transform
