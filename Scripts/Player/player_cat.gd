extends CharacterBody3D

@export var speed: float = 5.0
@export var hold_threshold: float = 0.2
@export var jump_velocity: float = 4.5
@export var gravity: float = 18.0

var target_position: Vector3
var moving: bool = false
var mouse_down: bool = false
var hold_time: float = 0.0
var purr_tween: Tween

func _ready() -> void:
	target_position = global_position

func _unhandled_input(event: InputEvent) -> void:
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

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if JournalManager.is_scene_input_blocked():
		mouse_down = false
		moving = false
		_stop_horizontal_movement()

	if mouse_down:
		hold_time += delta
		update_target_from_mouse()

	if moving:
		var direction: Vector3 = target_position - global_position
		direction.y = 0.0

		if direction.length() > 0.1:
			direction = direction.normalized()
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
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
