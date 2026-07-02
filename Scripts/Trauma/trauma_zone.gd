extends Area3D
class_name TraumaZone

const TraumaRadiusVisualScript: Script = preload("res://Scripts/Trauma/trauma_radius_visual.gd")

@export var fear_damage: float = 100.0
@export var trauma_radius: float = 4.0
@export var use_collision_radius: bool = true
@export var damage_on_enter: bool = true
@export var can_damage_repeatedly: bool = false
@export var reset_damage_when_player_leaves: bool = true

var radius_visual: Node
var has_damaged_player: bool = false

func _ready() -> void:
	add_to_group("TraumaZone")
	_init_radius_visual()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func set_trauma_radius_visible(is_visible: bool) -> void:
	_init_radius_visual()
	radius_visual.call("set_trauma_radius_visible", is_visible)

func show_trauma_radius() -> void:
	set_trauma_radius_visible(true)

func hide_trauma_radius() -> void:
	set_trauma_radius_visible(false)

func pulse_trauma_radius_warning() -> void:
	_init_radius_visual()
	radius_visual.call("pulse_trauma_radius_warning")

func is_trauma_radius_visible() -> bool:
	return radius_visual != null and bool(radius_visual.call("is_radius_visible"))

func contains_world_position(world_position: Vector3) -> bool:
	var local_position: Vector3 = global_transform.affine_inverse() * world_position
	local_position.y = 0.0
	return local_position.length() <= get_trauma_radius()

func get_trauma_radius() -> float:
	if use_collision_radius:
		var collision_radius: float = _get_collision_radius()
		if collision_radius > 0.0:
			return collision_radius

	return trauma_radius

func _on_body_entered(body: Node3D) -> void:
	if body == null or body.name != "PlayerCat":
		return
	if not damage_on_enter or not body.has_method("apply_fear_damage"):
		return
	if has_damaged_player and not can_damage_repeatedly:
		return

	body.call("apply_fear_damage", fear_damage, self)
	has_damaged_player = true

func _on_body_exited(body: Node3D) -> void:
	if body == null or body.name != "PlayerCat":
		return

	if reset_damage_when_player_leaves:
		has_damaged_player = false

func _init_radius_visual() -> void:
	if radius_visual != null:
		radius_visual.call("set_radius", get_trauma_radius())
		return

	radius_visual = find_child("RadiusVisualRoot", true, false)
	if radius_visual == null:
		radius_visual = TraumaRadiusVisualScript.new()
		radius_visual.name = "RadiusVisualRoot"
		add_child(radius_visual)

	radius_visual.position = Vector3(0.0, 0.035, 0.0)
	radius_visual.call("set_radius", get_trauma_radius())
	radius_visual.call("set_trauma_radius_visible", false)

func _get_collision_radius() -> float:
	var shape_node: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null or shape_node.shape == null:
		return 0.0

	var shape: Shape3D = shape_node.shape
	if shape is SphereShape3D:
		return (shape as SphereShape3D).radius
	if shape is CylinderShape3D:
		return (shape as CylinderShape3D).radius
	if shape is CapsuleShape3D:
		return (shape as CapsuleShape3D).radius
	if shape is BoxShape3D:
		var size: Vector3 = (shape as BoxShape3D).size
		return maxf(size.x, size.z) * 0.5

	return 0.0
