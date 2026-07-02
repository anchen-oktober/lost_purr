extends Area3D
class_name LPFearZone

const TraumaRadiusVisualScript: Script = preload("res://Scripts/Trauma/trauma_radius_visual.gd")

@export var fear_zone_id: String = ""
@export var required_calm_to_enter: float = 100.0
@export var radius: float = 3.0
@export var is_story_required: bool = false
@export var show_red_radius: bool = true

var radius_visual: Node = null

func _ready() -> void:
	add_to_group("LPFearZone")
	_init_radius_visual()
	set_fear_zone_active(show_red_radius)

func set_fear_zone_active(is_active: bool) -> void:
	_init_radius_visual()
	radius_visual.call("set_trauma_radius_visible", is_active and show_red_radius)

func pulse_fear_zone_warning() -> void:
	_init_radius_visual()
	radius_visual.call("pulse_trauma_radius_warning")

func can_player_enter() -> bool:
	var calm_manager: Node = get_node_or_null("/root/CatCalmManager")
	if calm_manager == null or not calm_manager.has_method("get_calm"):
		return true
	return float(calm_manager.call("get_calm")) >= required_calm_to_enter

func contains_world_position(world_position: Vector3) -> bool:
	var local_position: Vector3 = global_transform.affine_inverse() * world_position
	local_position.y = 0.0
	return local_position.length() <= radius

func _init_radius_visual() -> void:
	if radius_visual != null:
		radius_visual.call("set_radius", radius)
		return

	radius_visual = find_child("RadiusVisualRoot", true, false)
	if radius_visual == null:
		radius_visual = TraumaRadiusVisualScript.new()
		radius_visual.name = "RadiusVisualRoot"
		add_child(radius_visual)

	radius_visual.position = Vector3(0.0, 0.035, 0.0)
	radius_visual.call("set_radius", radius)
