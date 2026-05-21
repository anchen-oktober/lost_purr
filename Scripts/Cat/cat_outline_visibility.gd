extends Sprite3D

@export var target: Node3D
@export var target_height: float = 0.9
@export var check_interval: float = 0.05
@export_flags_3d_physics var occluder_collision_mask: int = 2

var check_timer: float = 0.0

func _ready() -> void:
	visible = false
	if target == null:
		target = get_parent_node_3d()

func _physics_process(delta: float) -> void:
	check_timer -= delta
	if check_timer > 0.0:
		return

	check_timer = check_interval
	visible = _is_target_hidden()

func _is_target_hidden() -> bool:
	if target == null:
		return false

	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return false

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var target_point: Vector3 = target.global_position + Vector3.UP * target_height
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(camera.global_position, target_point)
	query.collision_mask = occluder_collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true

	if target is CollisionObject3D:
		var collision_target: CollisionObject3D = target as CollisionObject3D
		query.exclude = [collision_target.get_rid()]

	var hit: Dictionary = space_state.intersect_ray(query)
	return not hit.is_empty()
