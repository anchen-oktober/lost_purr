extends CharacterBody3D

signal fear_changed(fear: float, calmness: float, state: String, is_critical: bool)

@export var speed: float = 5.0
@export var hold_threshold: float = 0.2
@export var jump_velocity: float = 4.5
@export var gravity: float = 18.0
@export var max_fear: float = 100.0
@export var fear_per_scare: float = 25.0
@export var critical_recovery_delay: float = 0.35

var target_position: Vector3
var moving: bool = false
var mouse_down: bool = false
var hold_time: float = 0.0
var purr_tween: Tween
var fear: float = 0.0
var is_critical_fear: bool = false
var move_speed_multiplier: float = 1.0
var last_recovery_transform: Transform3D
var level_start_transform: Transform3D
var controls_locked: bool = false
var cat_vision_manager: Node

func _ready() -> void:
	target_position = global_position
	level_start_transform = global_transform
	last_recovery_transform = level_start_transform
	_find_cat_vision_manager()
	_update_fear_state()

func _unhandled_input(event: InputEvent) -> void:
	if controls_locked:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if JournalManager.is_scene_input_blocked():
			mouse_down = false
			moving = false
			_stop_horizontal_movement()
			return

		if event.pressed:
			mouse_down = true
			hold_time = 0.0
			update_target_from_mouse()
			moving = true
		else:
			mouse_down = false

			if hold_time >= hold_threshold:
				moving = false
				_stop_horizontal_movement()

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_SPACE and is_on_floor():
			velocity.y = jump_velocity
		elif event.physical_keycode == KEY_F6:
			# Debug/test scare input.
			apply_fear_damage(fear_per_scare)
			get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if controls_locked or JournalManager.is_scene_input_blocked():
		mouse_down = false
		moving = false
		_stop_horizontal_movement()

	if controls_locked:
		move_and_slide()
		return

	if mouse_down:
		hold_time += delta
		update_target_from_mouse()

	if moving:
		var direction: Vector3 = target_position - global_position
		direction.y = 0.0

		if direction.length() > 0.1:
			direction = direction.normalized()
			velocity.x = direction.x * speed * move_speed_multiplier
			velocity.z = direction.z * speed * move_speed_multiplier
		else:
			_stop_horizontal_movement()
			moving = false
	else:
		_stop_horizontal_movement()

	move_and_slide()

func update_target_from_mouse() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_direction: Vector3 = camera.project_ray_normal(mouse_pos)

	var ground_y: float = 0.0
	var distance: float = (ground_y - ray_origin.y) / ray_direction.y
	target_position = ray_origin + ray_direction * distance

func _stop_horizontal_movement() -> void:
	velocity.x = 0.0
	velocity.z = 0.0

func apply_fear_damage(amount: float) -> void:
	if is_critical_fear:
		return

	fear = clampf(fear + amount, 0.0, max_fear)
	_update_fear_state()

	if fear >= max_fear:
		_enter_critical_fear()

func recover_from_fear(amount: float = -1.0) -> void:
	if amount < 0.0:
		fear = 0.0
	else:
		fear = clampf(fear - amount, 0.0, max_fear)
	_update_fear_state()

func set_recovery_point(recovery_transform: Transform3D, restore_now: bool = true) -> void:
	last_recovery_transform = recovery_transform
	if restore_now:
		recover_from_fear()

func set_level_start_recovery_point(start_transform: Transform3D) -> void:
	level_start_transform = start_transform
	last_recovery_transform = level_start_transform

func get_calmness() -> float:
	return maxf(0.0, max_fear - fear)

func get_fear_state() -> String:
	if is_critical_fear or fear >= max_fear:
		return "Critical"

	var calmness: float = get_calmness()
	if calmness > 75.0:
		return "Calm"
	if calmness > 50.0:
		return "Uneasy"
	if calmness > 25.0:
		return "Scared"
	if calmness > 0.0:
		return "Panic"
	return "Critical"

func _update_fear_state() -> void:
	var calmness: float = get_calmness()
	if is_critical_fear:
		move_speed_multiplier = 0.0
	elif calmness > 75.0:
		move_speed_multiplier = 1.0
	elif calmness > 50.0:
		move_speed_multiplier = 0.85
	elif calmness > 25.0:
		move_speed_multiplier = 0.7
	elif calmness > 0.0:
		move_speed_multiplier = 0.55
	else:
		move_speed_multiplier = 0.0

	fear_changed.emit(fear, calmness, get_fear_state(), is_critical_fear)

func _enter_critical_fear() -> void:
	if is_critical_fear:
		return

	is_critical_fear = true
	controls_locked = true
	mouse_down = false
	moving = false
	target_position = global_position
	_stop_horizontal_movement()
	if cat_vision_manager != null and cat_vision_manager.has_method("set_cat_critical"):
		cat_vision_manager.call("set_cat_critical", true)
	_update_fear_state()
	await get_tree().create_timer(critical_recovery_delay).timeout
	_return_to_recovery_point()

func _return_to_recovery_point() -> void:
	var recovery_transform: Transform3D = last_recovery_transform
	if recovery_transform.origin == Vector3.ZERO:
		recovery_transform = level_start_transform

	global_transform = recovery_transform
	target_position = global_position
	velocity = Vector3.ZERO
	fear = 0.0
	is_critical_fear = false
	controls_locked = false
	if cat_vision_manager != null and cat_vision_manager.has_method("set_cat_critical"):
		cat_vision_manager.call("set_cat_critical", false)
	_update_fear_state()

func _find_cat_vision_manager() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		cat_vision_manager = current_scene.find_child("CatVisionManager", true, false)

func play_purr_effect() -> void:
	if purr_tween != null:
		purr_tween.kill()

	var cat_billboard: Sprite3D = get_node_or_null("CatBillboard") as Sprite3D
	var cat_light: OmniLight3D = get_node_or_null("CatTrackingLight") as OmniLight3D
	purr_tween = create_tween()
	purr_tween.set_parallel(true)

	if cat_billboard != null:
		cat_billboard.scale = Vector3.ONE
		purr_tween.tween_property(cat_billboard, "scale", Vector3(1.08, 1.08, 1.08), 0.28)
		purr_tween.chain().tween_property(cat_billboard, "scale", Vector3.ONE, 0.38)

	if cat_light != null:
		var base_energy: float = cat_light.light_energy
		purr_tween.tween_property(cat_light, "light_energy", base_energy + 0.35, 0.25)
		purr_tween.chain().tween_property(cat_light, "light_energy", base_energy, 0.55)
