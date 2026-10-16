@tool
extends Node3D
class_name SilentWatcher

@export_range(0.0, 20.0, 0.1) var movement_speed: float = 2.0
## Paths to stationary Marker3D nodes, relative to this watcher. Route loops.
@export var patrol_points: Array[NodePath] = []
## World-space radius around the placed position, used when no route is assigned.
@export_range(0.0, 30.0, 0.1) var patrol_radius: float = 3.0
@export_range(0.0, 30.0, 0.1) var wait_time: float = 1.25
@export_range(1.0, 360.0, 1.0) var view_angle: float = 45.0
@export_range(0.0, 100.0, 0.1) var view_distance: float = 8.0
## Fear added per second through the cat's existing fear mechanic.
@export_range(0.0, 100.0, 0.1) var fear_rate: float = 6.0
@export_range(0.1, 20.0, 0.1) var rotation_speed: float = 4.0
@export_flags_3d_physics var vision_mask: int = 1
@export var eye_height: float = 0.8
@export var cat_target_height: float = 0.2
@export var debug_enabled: bool = false
@export var follow_surface: bool = false
@export_range(0.0, 3.0, 0.05) var surface_offset: float = 0.9
@export_range(0.1, 2.0, 0.05) var body_radius: float = 0.4
@export_range(0.05, 2.0, 0.05) var max_step_height: float = 0.6
## Editor slice height relative to the watcher. In game the slice follows the cat's aim height.
@export var debug_target_height: float = 0.2
@export_range(16, 256, 1) var debug_segments: int = 96

const VisionPreview = preload("res://Scripts/Park/silent_vision_preview.gd")

var state: String = "Patrol"
var _target_index: int = 0
var _wait_left: float = 0.0
var _spawn_position: Vector3
var _wander_target: Vector3
var _random := RandomNumberGenerator.new()
var _cat: Node3D
var _debug_mesh: MeshInstance3D
var _debug_material: StandardMaterial3D
var _debug_label: Label3D
var _editor_preview: Node3D
var _debug_refresh: float = 0.0
var _body_shape := SphereShape3D.new()
var _surface_initialized: bool = false
var _terrain: Node3D
var _fear_debug_left: float = 0.0
var _was_detecting: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("silent")
	# Visibility never disables patrol, detection, collision, or fear.
	hide()
	_spawn_position = global_position
	_random.randomize()
	_pick_wander_target()
	# Start from the placed transform; never teleport to the first route marker.
	if not patrol_points.is_empty():
		var first := get_node_or_null(patrol_points[0]) as Node3D
		if first != null and global_position.distance_to(first.global_position) <= 0.05:
			_target_index = 1 % patrol_points.size()
			_wait_left = wait_time

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		_debug_refresh -= delta
		if _debug_refresh <= 0.0:
			_debug_refresh = 0.15
			_update_debug()
		return
	if follow_surface and not _surface_initialized:
		_initialize_surface()
	_patrol(delta)
	if not is_instance_valid(_cat):
		_cat = get_tree().get_first_node_in_group("player") as Node3D
	var detecting: bool = is_instance_valid(_cat) and can_see_cat(_cat)
	state = "Detecting" if detecting else "Patrol"
	var fear_before: float = float(_cat.get("fear")) if is_instance_valid(_cat) and _cat.has_method("apply_fear_damage") else 0.0
	if detecting and fear_rate > 0.0 and _cat.has_method("apply_fear_damage"):
		var calm_manager: Node = get_node_or_null("/root/CatCalmManager")
		if calm_manager != null and calm_manager.has_method("reduce_calm"):
			calm_manager.call("reduce_calm", fear_rate * delta, str(get_path()), "quiet_fov", self)
		else:
			_cat.call("apply_fear_damage", fear_rate * delta, self)
	_fear_debug_left = maxf(0.0, _fear_debug_left - delta)
	if debug_enabled and (detecting != _was_detecting or (detecting and _fear_debug_left <= 0.0)):
		var fear_after: float = float(_cat.get("fear")) if is_instance_valid(_cat) and _cat.has_method("apply_fear_damage") else fear_before
		print("[QuietEntity %s] CatDetected=%s FearBefore=%.3f FearAfter=%.3f FearRate=%.2f" % [get_path(), detecting, fear_before, fear_after, fear_rate])
		_fear_debug_left = 1.0
	_was_detecting = detecting
	_update_debug()

func _patrol(delta: float) -> void:
	if movement_speed <= 0.0:
		return
	if _wait_left > 0.0:
		_wait_left = maxf(0.0, _wait_left - delta)
		return
	var destination: Vector3
	if patrol_points.is_empty():
		if patrol_radius <= 0.0:
			return
		# Clamp an existing destination if the radius is reduced at runtime.
		var wander_offset: Vector3 = _wander_target - _spawn_position
		if wander_offset.length() > patrol_radius:
			_pick_wander_target()
		destination = _wander_target
	else:
		_target_index %= patrol_points.size()
		var target := get_node_or_null(patrol_points[_target_index]) as Node3D
		if target == null:
			_target_index = (_target_index + 1) % patrol_points.size()
			return
		destination = target.global_position
	if follow_surface:
		destination.y = global_position.y
	var offset: Vector3 = destination - global_position
	if offset.length() <= 0.05:
		if patrol_points.is_empty():
			_pick_wander_target()
		else:
			_target_index = (_target_index + 1) % patrol_points.size()
		_wait_left = wait_time
		return
	var flat := Vector3(offset.x, 0.0, offset.z)
	if flat.length_squared() > 0.0001:
		var desired_yaw: float = atan2(-flat.x, -flat.z)
		global_rotation.y = lerp_angle(global_rotation.y, desired_yaw, 1.0 - exp(-rotation_speed * delta))
	# Ease into each stop, with no overshoot even at low frame rates.
	var speed: float = minf(movement_speed, offset.length() * 3.0)
	var next_position: Vector3 = global_position.move_toward(destination, speed * delta)
	if follow_surface:
		var ground := _surface_at(next_position)
		if ground.is_empty() or ground.normal.y < 0.65 or absf(ground.position.y + surface_offset - global_position.y) > max_step_height:
			_retry_patrol()
			return
		next_position.y = ground.position.y + surface_offset
		_body_shape.radius = body_radius
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = _body_shape
		query.transform = Transform3D(Basis.IDENTITY, global_position)
		query.motion = next_position - global_position
		query.collision_mask = vision_mask
		query.exclude = _movement_exclusions()
		var travel: PackedFloat32Array = get_world_3d().direct_space_state.cast_motion(query)
		if travel[0] < 1.0:
			_retry_patrol()
			return
	global_position = next_position

func _initialize_surface() -> void:
	var ground := _surface_at(global_position)
	# A few authored placeholders overlap small terrain holes. Find the nearest
	# valid start inside their own patrol radius; never add a fake floor.
	if ground.is_empty() and patrol_points.is_empty():
		var radius: float = 0.5
		while radius <= patrol_radius and ground.is_empty():
			for i in range(16):
				var angle: float = TAU * float(i) / 16.0
				var candidate: Vector3 = _spawn_position + Vector3(cos(angle), 0.0, sin(angle)) * radius
				ground = _surface_at(candidate)
				if not ground.is_empty() and ground.normal.y >= 0.65:
					break
				ground = {}
			radius += 0.5
	if ground.is_empty():
		return
	global_position = ground.position + Vector3.UP * surface_offset
	_spawn_position.y = global_position.y
	_wander_target.y = global_position.y
	_surface_initialized = true

func _retry_patrol() -> void:
	if patrol_points.is_empty():
		_pick_wander_target()
	_wait_left = 0.25

func _movement_exclusions() -> Array[RID]:
	var excluded: Array[RID] = []
	for child in find_children("*", "CollisionObject3D", true, false):
		excluded.append((child as CollisionObject3D).get_rid())
	for player in get_tree().get_nodes_in_group("player"):
		if player is CollisionObject3D:
			excluded.append((player as CollisionObject3D).get_rid())
	return excluded

func _surface_at(point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP, point - Vector3.UP * 4.0, vision_mask)
	query.exclude = _movement_exclusions()
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit
	# Terrain3D streams physics collision near the player. Its height data is
	# available for distant patrols too, so off-screen watchers must use it.
	if not is_instance_valid(_terrain) and get_tree().current_scene != null:
		_terrain = get_tree().current_scene.find_child("Terrain3D", true, false) as Node3D
	if is_instance_valid(_terrain):
		var data: Object = _terrain.get("data")
		if data != null:
			var height: float = data.call("get_height", point)
			if is_finite(height):
				return {"position": Vector3(point.x, height, point.z), "normal": Vector3.UP}
	return {}


func _pick_wander_target() -> void:
	# Sample all directions: forcing the opposite side can trap a watcher at
	# the edge of a terrain hole or wall on every retry.
	for attempt in range(16):
		var angle: float = _random.randf_range(-PI, PI)
		var radius: float = _random.randf_range(0.5, 1.0) * patrol_radius
		_wander_target = _spawn_position + Vector3(cos(angle), 0.0, sin(angle)) * radius
		if global_position.distance_to(_wander_target) >= minf(0.75, patrol_radius * 0.5):
			break
func can_see_cat(cat: Node3D) -> bool:
	var eye: Vector3 = global_position + Vector3.UP * eye_height
	var aim: Vector3 = cat.global_position + Vector3.UP * cat_target_height
	var offset: Vector3 = aim - eye
	if offset.length() > view_distance:
		return false
	var flat := Vector3(offset.x, 0.0, offset.z)
	var forward: Vector3 = -global_basis.z
	forward.y = 0.0
	# Keep the angle test even at touching distance behind the watcher.
	if flat.length_squared() > 0.0 and forward.normalized().dot(flat.normalized()) < cos(deg_to_rad(view_angle * 0.5)):
		return false
	var hit: Dictionary = _vision_hit(eye, aim, get_world_3d().direct_space_state)
	return hit.is_empty() or hit["collider"] == cat or cat.is_ancestor_of(hit["collider"])

func _vision_hit(from: Vector3, to: Vector3, space: PhysicsDirectSpaceState3D) -> Dictionary:
	if space == null or from.is_equal_approx(to):
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, to, vision_mask)
	var excluded: Array[RID] = []
	for child in find_children("*", "CollisionObject3D", true, false):
		excluded.append((child as CollisionObject3D).get_rid())
	# The cat is the target, not a wall; it must not cut a hole in the debug cone.
	if is_instance_valid(_cat) and _cat is CollisionObject3D:
		excluded.append((_cat as CollisionObject3D).get_rid())
	query.exclude = excluded
	query.hit_from_inside = true
	return space.intersect_ray(query)

## World-space boundary of a horizontal slice of the actual detection volume.
func get_debug_boundary(space: PhysicsDirectSpaceState3D) -> PackedVector3Array:
	var eye: Vector3 = global_position + Vector3.UP * eye_height
	var height: float = global_position.y + debug_target_height
	if not Engine.is_editor_hint() and is_instance_valid(_cat):
		height = _cat.global_position.y + cat_target_height
	var vertical_distance: float = height - eye.y
	var reach: float = sqrt(maxf(0.0, view_distance * view_distance - vertical_distance * vertical_distance))
	var forward: Vector3 = -global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var points := PackedVector3Array()
	var half_angle: float = deg_to_rad(view_angle * 0.5)
	for i in range(debug_segments + 1):
		var angle: float = lerpf(-half_angle, half_angle, float(i) / debug_segments)
		var direction: Vector3 = forward.rotated(Vector3.UP, angle)
		var end: Vector3 = Vector3(eye.x, height, eye.z) + direction * reach
		var hit: Dictionary = _vision_hit(eye, end, space)
		if not hit.is_empty():
			# Project the blocker onto the displayed slice.
			end = hit["position"]
			end.y = height
		points.append(end)
	return points
func _update_debug() -> void:
	if not debug_enabled:
		if is_instance_valid(_debug_mesh):
			_debug_mesh.hide()
			_debug_label.hide()
		if is_instance_valid(_editor_preview):
			_editor_preview.clear()
		return
	if not is_instance_valid(_debug_mesh):
		_debug_mesh = MeshInstance3D.new()
		_debug_mesh.name = "VisionDebug"
		_debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_debug_mesh)
		_debug_material = StandardMaterial3D.new()
		_debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_debug_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_debug_label = Label3D.new()
		_debug_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_debug_label.font_size = 40
		add_child(_debug_label)
	_debug_mesh.show()
	_debug_label.show()
	_debug_label.position.y = eye_height + 1.0
	_debug_label.text = "Patrol" if Engine.is_editor_hint() else state
	var color := Color.ORANGE_RED if state == "Detecting" else Color.CYAN
	_debug_material.albedo_color = Color(color, 0.28)
	_debug_label.modulate = color
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if Engine.is_editor_hint():
		if not is_instance_valid(_editor_preview):
			_editor_preview = VisionPreview.new()
			add_child(_editor_preview)
		var scene: Node = get_tree().edited_scene_root
		if scene != null:
			_editor_preview.rebuild(scene, self, vision_mask)
		space = _editor_preview.get_space_state()
	var boundary: PackedVector3Array = get_debug_boundary(space)
	var origin: Vector3 = to_local(Vector3(global_position.x, boundary[0].y, global_position.z))
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _debug_material)
	for i in range(1, boundary.size()):
		mesh.surface_add_vertex(origin)
		mesh.surface_add_vertex(to_local(boundary[i - 1]))
		mesh.surface_add_vertex(to_local(boundary[i]))
	mesh.surface_end()
	# Opaque outline makes the exact angle and clipped edge easy to read.
	var outline := StandardMaterial3D.new()
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.albedo_color = color
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, outline)
	mesh.surface_add_vertex(origin)
	for point in boundary:
		mesh.surface_add_vertex(to_local(point))
	mesh.surface_add_vertex(origin)
	mesh.surface_end()
	_debug_mesh.mesh = mesh