extends CharacterBody3D

@export var speed := 5.0
@export var hold_threshold := 0.2

var target_position: Vector3
var moving := false
var mouse_down := false
var hold_time := 0.0

func _ready():
	target_position = global_position

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			mouse_down = true
			hold_time = 0.0
			update_target_from_mouse()
			moving = true
		else:
			mouse_down = false

			# Если это было удержание — останавливаемся
			if hold_time >= hold_threshold:
				moving = false
				velocity = Vector3.ZERO
			# Если это был короткий клик — продолжаем идти к точке

func _physics_process(delta):
	if mouse_down:
		hold_time += delta
		update_target_from_mouse()

	if moving:
		var direction = target_position - global_position
		direction.y = 0

		if direction.length() > 0.1:
			direction = direction.normalized()
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity = Vector3.ZERO
			moving = false
	else:
		velocity = Vector3.ZERO

	move_and_slide()

func update_target_from_mouse():
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return

	var mouse_pos = get_viewport().get_mouse_position()

	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)

	var ground_y = 0.0
	var distance = (ground_y - ray_origin.y) / ray_direction.y

	target_position = ray_origin + ray_direction * distance
