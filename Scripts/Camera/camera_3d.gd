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

func _ready() -> void:
	base_offset = position

func _unhandled_input(event: InputEvent) -> void:
	if JournalManager.is_scene_input_blocked():
		is_rotating_with_mouse = false
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
