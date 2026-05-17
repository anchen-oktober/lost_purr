extends Node3D

@export var target: Node3D
@export var min_zoom := 8.0
@export var max_zoom := 34.0
@export var zoom_step := 2.5
@export var zoom_smoothness := 10.0
@export var keyboard_rotation_speed := 1.8
@export var mouse_rotation_sensitivity := 0.006

var base_offset: Vector3
var current_zoom: float = 1.0
var target_zoom: float = 1.0
var yaw: float = 0.0
var is_rotating_with_mouse := false

func _ready() -> void:
	base_offset = position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton

		if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			is_rotating_with_mouse = mouse_button.pressed
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_change_zoom(-zoom_step)
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_change_zoom(zoom_step)
	elif event is InputEventMouseMotion and is_rotating_with_mouse:
		var mouse_motion := event as InputEventMouseMotion
		yaw -= mouse_motion.relative.x * mouse_rotation_sensitivity

func _process(delta: float) -> void:
	var keyboard_rotation: float = 0.0
	if Input.is_physical_key_pressed(KEY_Q):
		keyboard_rotation += 1.0
	if Input.is_physical_key_pressed(KEY_E):
		keyboard_rotation -= 1.0

	yaw += keyboard_rotation * keyboard_rotation_speed * delta
	var zoom_weight: float = 1.0 - exp(-zoom_smoothness * delta)
	current_zoom = lerpf(current_zoom, target_zoom, zoom_weight)

	if target:
		var rotated_offset: Vector3 = base_offset.rotated(Vector3.UP, yaw) * current_zoom
		global_position = target.global_position + rotated_offset
		look_at(target.global_position, Vector3.UP)

func _change_zoom(amount: float) -> void:
	var base_distance: float = base_offset.length()
	var target_distance: float = clampf(base_distance * target_zoom + amount, min_zoom, max_zoom)
	target_zoom = target_distance / base_distance
