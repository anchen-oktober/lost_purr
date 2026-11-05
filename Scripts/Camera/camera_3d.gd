extends Node3D

@export var target: Node3D
@export var min_zoom: float = 8.0
@export var max_zoom: float = 34.0
@export var zoom_step: float = 2.5
@export var zoom_smoothness: float = 10.0
@export var mouse_rotation_sensitivity: float = 0.0035
@export var third_person_distance: float = 6.5
@export var third_person_height: float = 2.6
@export var third_person_look_height: float = 0.85
@export var third_person_smoothness: float = 7.0
@export var third_person_turn_smoothness: float = 1.5
@export var third_person_auto_follow_movement: bool = false

@export_category("Dynamic follow camera")
## Enables the close-to-wide, over-the-shoulder camera on this instance.
## The two legacy cameras leave this disabled, so their behaviour is unchanged.
@export var dynamic_mode: bool = false
@export_range(1.5, 40.0, 0.1, "suffix:m") var min_distance: float = 2.6
@export_range(1.5, 40.0, 0.1, "suffix:m") var max_distance: float = 32.0
@export_range(1.5, 40.0, 0.1, "suffix:m") var cat_vision_max_distance: float = 29.0
@export_range(0.1, 10.0, 0.1, "suffix:m per scroll") var zoom_speed: float = 1.5
@export_range(0.1, 30.0, 0.1) var follow_smoothness: float = 9.0
@export_range(0.0001, 0.03, 0.0001) var mouse_sensitivity: float = 0.0035
@export_range(-89.0, 0.0, 1.0, "suffix:°") var min_vertical_angle: float = -35.0
@export_range(0.0, 89.0, 1.0, "suffix:°") var max_vertical_angle: float = 55.0
@export_range(0.1, 4.0, 0.05, "suffix:m") var pivot_height: float = 1.05
@export_range(0.0, 2.0, 0.05, "suffix:m") var shoulder_offset: float = 0.42
@export_range(0.0, 1.0, 0.01, "suffix:m") var collision_radius: float = 0.18
@export_range(0.0, 1.0, 0.01, "suffix:m") var collision_margin: float = 0.12
@export_flags_3d_physics var collision_mask: int = 1

enum CameraMode {
	ISOMETRIC,
	THIRD_PERSON,
}

var base_offset: Vector3
var current_zoom: float = 1.0
var target_zoom: float = 1.0
var yaw: float = 0.0
var is_rotating_with_mouse: bool = false
var camera_mode: CameraMode = CameraMode.ISOMETRIC
var pitch: float = deg_to_rad(12.0)
var current_distance: float = 8.0
var target_distance: float = 8.0
var _follow_position: Vector3

func _ready() -> void:
	base_offset = position
	if dynamic_mode and target != null:
		min_distance = minf(min_distance, max_distance)
		max_distance = maxf(min_distance, max_distance)
		current_distance = clampf(current_distance, min_distance, max_distance)
		target_distance = current_distance
		pitch = clampf(pitch, deg_to_rad(min_vertical_angle), deg_to_rad(max_vertical_angle))
		_follow_position = target.global_position + Vector3.UP * pivot_height
		_update_dynamic_camera(0.0, true)

func _input(event: InputEvent) -> void:
	if JournalManager.is_scene_input_blocked():
		is_rotating_with_mouse = false
		return
	if dynamic_mode:
		_input_dynamic_camera(event)
		return

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_C:
			_toggle_camera_mode()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event as InputEventMouseButton

		if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			is_rotating_with_mouse = mouse_button.pressed
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_change_zoom(-zoom_step)
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_change_zoom(zoom_step)
	elif event is InputEventMouseMotion and is_rotating_with_mouse:
		var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
		yaw -= mouse_motion.relative.x * mouse_rotation_sensitivity

func _physics_process(delta: float) -> void:
	if dynamic_mode:
		if target:
			_update_dynamic_camera(delta)
		return

	var zoom_weight: float = 1.0 - exp(-zoom_smoothness * delta)
	current_zoom = lerpf(current_zoom, target_zoom, zoom_weight)

	if target:
		if camera_mode == CameraMode.ISOMETRIC:
			_update_isometric_camera()
		else:
			_update_third_person_camera(delta)

func _change_zoom(amount: float) -> void:
	if camera_mode != CameraMode.ISOMETRIC:
		return

	var base_distance: float = base_offset.length()
	var target_distance: float = clampf(base_distance * target_zoom + amount, min_zoom, max_zoom)
	target_zoom = target_distance / base_distance

func _toggle_camera_mode() -> void:
	if camera_mode == CameraMode.ISOMETRIC:
		camera_mode = CameraMode.THIRD_PERSON
		is_rotating_with_mouse = false
	else:
		camera_mode = CameraMode.ISOMETRIC

func _update_isometric_camera() -> void:
	var rotated_offset: Vector3 = base_offset.rotated(Vector3.UP, yaw) * current_zoom
	global_position = target.global_position + rotated_offset
	look_at(target.global_position, Vector3.UP)

func _update_third_person_camera(delta: float) -> void:
	_update_third_person_yaw(delta)

	var rotated_back: Vector3 = Vector3(0.0, 0.0, third_person_distance).rotated(Vector3.UP, yaw)
	var desired_position: Vector3 = target.global_position + rotated_back + Vector3.UP * third_person_height
	var follow_weight: float = 1.0 - exp(-third_person_smoothness * delta)
	global_position = global_position.lerp(desired_position, follow_weight)
	look_at(target.global_position + Vector3.UP * third_person_look_height, Vector3.UP)

func _update_third_person_yaw(delta: float) -> void:
	if not third_person_auto_follow_movement or is_rotating_with_mouse:
		return

	var character_target: CharacterBody3D = target as CharacterBody3D
	if character_target == null:
		return

	var horizontal_velocity: Vector3 = character_target.velocity
	horizontal_velocity.y = 0.0
	if horizontal_velocity.length_squared() < 0.01:
		return

	var movement_direction: Vector3 = horizontal_velocity.normalized()
	var desired_yaw: float = atan2(-movement_direction.x, -movement_direction.z)
	var turn_weight: float = 1.0 - exp(-third_person_turn_smoothness * delta)
	yaw = lerp_angle(yaw, desired_yaw, turn_weight)


func update_camera_now() -> void:
	if target == null:
		return
	if dynamic_mode:
		_update_dynamic_camera(0.0, true)
	else:
		_update_isometric_camera()


func is_cat_vision_available() -> bool:
	# The wide end of this camera intentionally trades Cat Vision for a full
	# overview. Checking the target distance makes the restriction responsive
	# as soon as the player starts zooming back in.
	return not dynamic_mode or target_distance < minf(cat_vision_max_distance, max_distance)


func _input_dynamic_camera(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			is_rotating_with_mouse = mouse_button.pressed
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_distance = clampf(target_distance - zoom_speed, min_distance, max_distance)
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_distance = clampf(target_distance + zoom_speed, min_distance, max_distance)
	elif event is InputEventMouseMotion and is_rotating_with_mouse:
		var mouse_motion := event as InputEventMouseMotion
		yaw -= mouse_motion.relative.x * mouse_sensitivity
		pitch = clampf(
			pitch - mouse_motion.relative.y * mouse_sensitivity,
			deg_to_rad(min_vertical_angle),
			deg_to_rad(max_vertical_angle)
		)


func _update_dynamic_camera(delta: float, snap: bool = false) -> void:
	var desired_pivot := target.global_position + Vector3.UP * pivot_height
	var follow_weight := 1.0 if snap else 1.0 - exp(-follow_smoothness * delta)
	_follow_position = _follow_position.lerp(desired_pivot, follow_weight)
	var distance_weight := 1.0 if snap else 1.0 - exp(-follow_smoothness * delta)
	current_distance = lerpf(current_distance, target_distance, distance_weight)

	# The view direction is independent from the cat's heading.  At the close
	# limit the shoulder offset keeps part of the cat in frame instead of
	# becoming a first-person camera.
	var forward := Vector3(
		-sin(yaw) * cos(pitch),
		sin(pitch),
		-cos(yaw) * cos(pitch)
	).normalized()
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var desired_position := _follow_position - forward * current_distance + right * shoulder_offset
	desired_position = _resolve_dynamic_collision(_follow_position, desired_position)

	# Looking slightly ahead lets the player look upward while the cat remains
	# visible in the foreground, including at the minimum distance.
	var look_target := _follow_position + forward * maxf(1.2, current_distance * 0.35)
	global_position = desired_position
	look_at(look_target, Vector3.UP)


func _resolve_dynamic_collision(pivot: Vector3, desired_position: Vector3) -> Vector3:
	var motion := desired_position - pivot
	if motion.length_squared() <= 0.0001 or collision_radius <= 0.0:
		return desired_position

	var shape := SphereShape3D.new()
	shape.radius = collision_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, pivot)
	query.motion = motion
	query.collision_mask = collision_mask
	if target is CollisionObject3D:
		query.exclude = [target.get_rid()]
	var cast_result := get_world_3d().direct_space_state.cast_motion(query)
	if cast_result.size() < 2 or cast_result[0] >= 1.0:
		return desired_position

	var safe_fraction: float = maxf(0.0, cast_result[0] - collision_margin / motion.length())
	return pivot + motion * safe_fraction
