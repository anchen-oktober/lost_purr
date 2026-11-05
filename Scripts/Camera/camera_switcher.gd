extends Node3D

@export var target: Node3D
@export_range(0.0, 2.0, 0.05) var transition_duration: float = 0.4

@onready var new_camera: Camera3D = $Camera3D
@onready var old_camera: Camera3D = $OldCamera
@onready var dynamic_camera: Camera3D = $DynamicCamera
@onready var mode_label: Label = $CameraModeHUD/Label

var active_camera: Camera3D
var blend_camera: Camera3D
var transition_elapsed: float = 0.0
var transition_from: Transform3D
var transition_target_origin: Vector3
var transition_from_fov: float
var transition_from_near: float
var transition_from_far: float
var transitioning: bool = false

func _ready() -> void:
	# Each controller keeps its own zoom/yaw/settings and follows the cat, even
	# while hidden. Only this rig dispatches input, so C never reaches the
	# controller's original isometric/third-person shortcut.
	for camera: Camera3D in _cameras():
		camera.set("target", target)
		camera.set_process_input(false)
		camera.call("update_camera_now")
	blend_camera = Camera3D.new()
	blend_camera.name = "CameraTransition"
	add_child(blend_camera)
	active_camera = new_camera
	active_camera.make_current()
	_update_mode_label()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.physical_keycode == KEY_C:
		if event.pressed and not event.echo:
			toggle_camera()
		get_viewport().set_input_as_handled()
		return
	active_camera.call("_input", event)

func refresh_gameplay_camera() -> Camera3D:
	# Startup may validate the scene while the temporary blend camera is current,
	# or just after moving the player to a portal spawn.
	for camera: Camera3D in _cameras():
		camera.call("update_camera_now")
	return active_camera


func is_cat_vision_available() -> bool:
	if active_camera != dynamic_camera:
		return true
	return bool(dynamic_camera.call("is_cat_vision_available"))

func toggle_camera() -> void:
	var visible_camera: Camera3D = get_viewport().get_camera_3d()
	transition_from = visible_camera.global_transform
	transition_from_fov = visible_camera.fov
	transition_from_near = visible_camera.near
	transition_from_far = visible_camera.far
	transition_target_origin = target.global_position
	active_camera.set("is_rotating_with_mouse", false)
	var current_index := _cameras().find(active_camera)
	active_camera = _cameras()[(current_index + 1) % _cameras().size()]
	active_camera.set("is_rotating_with_mouse", Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))
	if target.has_method("preserve_camera_movement_target"):
		target.call("preserve_camera_movement_target")
	transition_elapsed = 0.0
	transitioning = transition_duration > 0.0
	if transitioning:
		blend_camera.global_transform = transition_from
		blend_camera.fov = transition_from_fov
		blend_camera.near = transition_from_near
		blend_camera.far = transition_from_far
		blend_camera.make_current()
	else:
		active_camera.make_current()
	_update_mode_label()

func _process(delta: float) -> void:
	if not transitioning:
		return
	transition_elapsed += delta
	var weight: float = smoothstep(0.0, 1.0, minf(transition_elapsed / transition_duration, 1.0))
	# Follow player displacement during the blend instead of lingering at the
	# place where C was pressed. Repeated C starts at the currently visible pose.
	var moving_from: Transform3D = transition_from
	moving_from.origin += target.global_position - transition_target_origin
	blend_camera.global_transform = moving_from.interpolate_with(active_camera.global_transform, weight)
	blend_camera.fov = lerpf(transition_from_fov, active_camera.fov, weight)
	blend_camera.near = lerpf(transition_from_near, active_camera.near, weight)
	blend_camera.far = lerpf(transition_from_far, active_camera.far, weight)
	if transition_elapsed >= transition_duration:
		transitioning = false
		active_camera.make_current()
		_update_mode_label()

func _update_mode_label() -> void:
	if active_camera == new_camera:
		mode_label.text = "New Camera  [C]"
	elif active_camera == old_camera:
		mode_label.text = "Old Camera  [C]"
	else:
		mode_label.text = "Dynamic Camera  [C]"


func _cameras() -> Array[Camera3D]:
	return [new_camera, old_camera, dynamic_camera]
