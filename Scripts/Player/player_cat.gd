extends CharacterBody3D

const FearReturnPath = preload("res://Scripts/Player/fear_return_path.gd")

const TraumaRadiusVisualScript: Script = preload("res://Scripts/Trauma/trauma_radius_visual.gd")

signal fear_changed(fear: float, calmness: float, state: String, is_critical: bool)
signal trauma_avoidance_changed(is_active: bool, blocked_zone_name: String, radius_visible: bool)

@export var speed: float = 5.0
@export var hold_threshold: float = 0.2
@export var jump_velocity: float = 4.5
@export var gravity: float = 18.0
@export var max_fear: float = 100.0
@export var fear_per_scare: float = 25.0
@export var restore_quarter_amount: float = 25.0
@export var purr_restore_amount: float = 10.0
@export var purr_restore_cooldown: float = 3.0
@export var can_purr_restore: bool = true
@export var critical_recovery_delay: float = 0.35
@export_range(0.1, 30.0, 0.1) var trauma_block_radius: float = 4.0:
	set(value):
		trauma_block_radius = maxf(0.1, value)
		if is_instance_valid(temporary_trauma_radius):
			temporary_trauma_radius.call("set_radius", trauma_block_radius)
@export var flee_speed: float = 8.0
@export var hiding_recovery_rate: float = 25.0
@export var minimum_hiding_time: float = 1.0
@export var interaction_fallback_range: float = 4.0

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
var fear_recovery_phase: String = ""
var flee_path: PackedVector3Array = PackedVector3Array()
var flee_destination: Vector3
var flee_retry_left: float = 0.0
var hiding_time: float = 0.0
var _normal_billboard_scale: Vector3 = Vector3.ONE
var cat_vision_manager: Node
var positive_restore_block_time: float = 0.0
var purr_restore_cooldown_left: float = 0.0
var has_active_trauma_avoidance: bool = false
var current_trauma_zone: Node = null
var blocked_zone_name: String = "none"
var last_fear_source_position: Vector3
var temporary_trauma_radius: Node = null
var trauma_warning_cooldown: float = 0.0
var fallback_interactable: Node3D = null
var interaction_candidates: Array[Node3D] = []
var interaction_trigger_candidates: Array[Area3D] = []
var fallback_trigger: Area3D = null

func _ready() -> void:
	add_to_group("player")
	target_position = global_position
	level_start_transform = global_transform
	last_recovery_transform = level_start_transform
	last_fear_source_position = global_position
	call_deferred("_find_cat_vision_manager")
	call_deferred("_cache_interaction_candidates")
	_update_fear_state()
	var calm_manager: Node = get_node_or_null("/root/CatCalmManager")
	if calm_manager != null and calm_manager.has_method("register_player"):
		calm_manager.call("register_player", self)

func _input(event: InputEvent) -> void:
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
		elif event.physical_keycode == KEY_F7:
			# Debug/test recovery cheat.
			restore_fear_quarter()
			get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if positive_restore_block_time > 0.0:
		positive_restore_block_time = maxf(positive_restore_block_time - delta, 0.0)
	if purr_restore_cooldown_left > 0.0:
		purr_restore_cooldown_left = maxf(purr_restore_cooldown_left - delta, 0.0)
	if trauma_warning_cooldown > 0.0:
		trauma_warning_cooldown = maxf(trauma_warning_cooldown - delta, 0.0)

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	if not fear_recovery_phase.is_empty():
		_process_fear_recovery(delta)
		return

	if controls_locked or JournalManager.is_scene_input_blocked():
		mouse_down = false
		moving = false
		_stop_horizontal_movement()

	if controls_locked:
		move_and_slide()
		return

	_update_interaction_fallback()

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

	_move_with_trauma_boundary(delta)

func _move_with_trauma_boundary(delta: float) -> void:
	var previous: Vector3 = global_position
	if has_active_trauma_avoidance:
		var center := Vector2(last_fear_source_position.x, last_fear_source_position.z)
		var from := Vector2(previous.x, previous.z)
		var to := from + Vector2(velocity.x, velocity.z) * delta
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(center, from, to)
		var radius: float = trauma_block_radius + 0.45
		if closest.distance_to(center) < radius and (from.distance_to(center) >= radius or to.distance_to(center) < from.distance_to(center)):
			_stop_horizontal_movement()
			moving = false
			target_position = global_position
			_pulse_active_trauma_warning()
	move_and_slide()
	if has_active_trauma_avoidance:
		var old_distance := Vector2(previous.x - last_fear_source_position.x, previous.z - last_fear_source_position.z).length()
		var new_distance := Vector2(global_position.x - last_fear_source_position.x, global_position.z - last_fear_source_position.z).length()
		if new_distance < trauma_block_radius + 0.45 and new_distance < old_distance:
			global_position.x = previous.x
			global_position.z = previous.z
			_stop_horizontal_movement()

func _update_interaction_fallback() -> void:
	if interaction_candidates.is_empty():
		_cache_interaction_candidates()

	var closest_interactable: Node3D = null
	var closest_distance: float = interaction_fallback_range
	for candidate in interaction_candidates:
		if not is_instance_valid(candidate):
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if distance <= closest_distance:
			closest_interactable = candidate
			closest_distance = distance

	if closest_interactable != fallback_interactable:
		if fallback_interactable != null:
			JournalManager.clear_nearby_object(fallback_interactable)
		fallback_interactable = closest_interactable
		if fallback_interactable != null:
			JournalManager.set_nearby_object(fallback_interactable)
	_update_interaction_trigger_fallback()

func _update_interaction_trigger_fallback() -> void:
	var closest_trigger: Area3D = null
	var closest_distance: float = interaction_fallback_range
	for trigger in interaction_trigger_candidates:
		if not is_instance_valid(trigger):
			continue
		var distance := global_position.distance_to(trigger.global_position)
		if distance <= closest_distance:
			closest_trigger = trigger
			closest_distance = distance

	if closest_trigger == fallback_trigger:
		return
	if fallback_trigger != null and is_instance_valid(fallback_trigger):
		fallback_trigger.call("_on_body_exited", self)
	fallback_trigger = closest_trigger
	if fallback_trigger != null:
		fallback_trigger.call("_on_body_entered", self)

func _cache_interaction_candidates() -> void:
	interaction_candidates.clear()
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	for node in current_scene.find_children("*", "Node3D", true, false):
		if node.has_method("interact") and node is Node3D:
			if node.has_method("is_interaction_available") and not bool(node.call("is_interaction_available")):
				continue
			interaction_candidates.append(node as Node3D)
		if node is Area3D and node.is_in_group("LPTrigger"):
			interaction_trigger_candidates.append(node as Area3D)

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

	if _is_position_blocked_by_trauma(target_position):
		mouse_down = false
		moving = false
		target_position = global_position
		_stop_horizontal_movement()
		_pulse_active_trauma_warning()

func _stop_horizontal_movement() -> void:
	velocity.x = 0.0
	velocity.z = 0.0

func apply_fear_damage(amount: float, source_node: Node = null) -> void:
	if is_critical_fear or amount <= 0.0:
		return

	# Continuous danger suspends passive healing through the existing recovery gate.
	positive_restore_block_time = maxf(positive_restore_block_time, 0.25)
	fear = clampf(fear + amount, 0.0, max_fear)
	_update_fear_state()

	if fear >= max_fear:
		_enter_critical_fear(source_node)

func restore_fear(amount: float) -> void:
	fear = clampf(fear - amount, 0.0, max_fear)
	_update_fear_state()

func restore_fear_quarter() -> void:
	restore_fear(restore_quarter_amount)

func restore_fear_by_purr() -> bool:
	if not can_purr_restore or is_critical_fear or purr_restore_cooldown_left > 0.0:
		return false

	restore_fear(purr_restore_amount)
	purr_restore_cooldown_left = purr_restore_cooldown
	return true

func can_receive_positive_restore() -> bool:
	return positive_restore_block_time <= 0.0 and not is_critical_fear

func recover_from_fear(amount: float = -1.0) -> void:
	if amount < 0.0:
		restore_fear(max_fear)
	else:
		restore_fear(amount)

func set_recovery_point(recovery_transform: Transform3D, restore_now: bool = false) -> void:
	last_recovery_transform = recovery_transform
	if restore_now:
		restore_fear_quarter()

func set_level_start_recovery_point(start_transform: Transform3D) -> void:
	level_start_transform = start_transform
	last_recovery_transform = level_start_transform

func get_calmness() -> float:
	return maxf(0.0, max_fear - fear)

func get_fear_state() -> String:
	if fear_recovery_phase == "Hiding":
		return "Hiding"
	if is_critical_fear or fear >= max_fear:
		return "Critical"

	var calmness: float = get_calmness()
	if calmness > 75.0:
		return "Calm"
	if calmness > 50.0:
		return "Uneasy"
	if calmness >= 25.0:
		return "Scared"
	if calmness > 0.0:
		return "Panic"
	return "Critical"

func get_blocked_zone_name() -> String:
	return blocked_zone_name

func is_blocked_zone_radius_visible() -> bool:
	if not has_active_trauma_avoidance:
		return false
	if current_trauma_zone != null and current_trauma_zone.has_method("is_trauma_radius_visible"):
		return bool(current_trauma_zone.call("is_trauma_radius_visible"))
	return temporary_trauma_radius != null and bool(temporary_trauma_radius.call("is_radius_visible"))

func _update_fear_state() -> void:
	var calmness: float = get_calmness()
	if is_critical_fear:
		move_speed_multiplier = 0.0
	elif calmness > 75.0:
		move_speed_multiplier = 1.0
	elif calmness > 50.0:
		move_speed_multiplier = 0.85
	elif calmness >= 25.0:
		move_speed_multiplier = 0.7
	elif calmness > 0.0:
		move_speed_multiplier = 0.55
	else:
		move_speed_multiplier = 0.0

	fear_changed.emit(fear, calmness, get_fear_state(), is_critical_fear)

func _enter_critical_fear(_source_node: Node = null) -> void:
	if is_critical_fear:
		return
	last_fear_source_position = global_position
	_activate_trauma_avoidance(null)
	is_critical_fear = true
	controls_locked = true
	fear_recovery_phase = "Fleeing"
	mouse_down = false
	moving = false
	flee_destination = last_recovery_transform.origin
	flee_path = FearReturnPath.build(self, flee_destination)
	flee_retry_left = 1.0
	if is_instance_valid(cat_vision_manager):
		cat_vision_manager.call("set_cat_critical", true)
	_update_fear_state()
	print("[Fear] Fleeing to SafePoint ", flee_destination)

func _process_fear_recovery(delta: float) -> void:
	mouse_down = false
	moving = false
	if fear_recovery_phase == "Fleeing":
		var remaining := Vector2(global_position.x - flee_destination.x, global_position.z - flee_destination.z)
		if remaining.length() <= 0.25 and absf(global_position.y - flee_destination.y) < 1.0:
			_return_to_recovery_point()
			return
		while not flee_path.is_empty() and Vector2(flee_path[0].x - global_position.x, flee_path[0].z - global_position.z).length() <= 0.25:
			flee_path.remove_at(0)
		flee_retry_left -= delta
		if (flee_path.is_empty() or get_position_delta().length() < 0.005) and flee_retry_left <= 0.0:
			flee_path = FearReturnPath.build(self, flee_destination)
			flee_retry_left = 1.0
		_stop_horizontal_movement()
		if not flee_path.is_empty():
			var direction: Vector3 = flee_path[0] - global_position
			direction.y = 0.0
			var movement: Vector3 = direction.normalized() * minf(flee_speed, direction.length() / delta)
			velocity.x = movement.x
			velocity.z = movement.z
		move_and_slide()
	elif fear_recovery_phase == "Hiding":
		_stop_horizontal_movement()
		move_and_slide()
		hiding_time += delta
		restore_fear(maxf(hiding_recovery_rate, 0.1) * delta)
		if fear <= 0.0 and hiding_time >= minimum_hiding_time:
			fear_recovery_phase = ""
			is_critical_fear = false
			controls_locked = false
			target_position = global_position
			var billboard := get_node_or_null("CatBillboard") as Sprite3D
			if billboard != null: billboard.scale = _normal_billboard_scale
			_update_fear_state()
			print("[Fear] Recovered; player control restored")

func _return_to_recovery_point() -> void:
	# Arrival starts hiding; no teleport and no immediate control restoration.
	fear_recovery_phase = "Hiding"
	hiding_time = 0.0
	target_position = global_position
	velocity = Vector3.ZERO
	var billboard := get_node_or_null("CatBillboard") as Sprite3D
	if billboard != null:
		_normal_billboard_scale = billboard.scale
		billboard.scale = _normal_billboard_scale * Vector3(1.0, 0.6, 1.0)
	if is_instance_valid(cat_vision_manager):
		cat_vision_manager.call("set_cat_critical", false)
	_update_fear_state()
	print("[Fear] Arrived at SafePoint; hiding and recovering")

func _activate_trauma_avoidance(_source_node: Node) -> void:
	_clear_trauma_avoidance()
	has_active_trauma_avoidance = true
	current_trauma_zone = null
	blocked_zone_name = "last_fright"
	_show_temporary_trauma_radius()
	_emit_trauma_avoidance_changed()

func _clear_trauma_avoidance() -> void:
	if current_trauma_zone != null and current_trauma_zone.has_method("set_trauma_radius_visible"):
		current_trauma_zone.call("set_trauma_radius_visible", false)

	if temporary_trauma_radius != null:
		temporary_trauma_radius.call("set_trauma_radius_visible", false)
		temporary_trauma_radius.queue_free()
		temporary_trauma_radius = null

	has_active_trauma_avoidance = false
	current_trauma_zone = null
	blocked_zone_name = "none"
	_emit_trauma_avoidance_changed()

func _show_temporary_trauma_radius() -> void:
	temporary_trauma_radius = TraumaRadiusVisualScript.new()
	temporary_trauma_radius.name = "TemporaryTraumaRadius"
	get_tree().current_scene.add_child(temporary_trauma_radius)
	temporary_trauma_radius.global_position = Vector3(last_fear_source_position.x, last_fear_source_position.y - 0.4, last_fear_source_position.z)
	temporary_trauma_radius.call("set_radius", trauma_block_radius)
	temporary_trauma_radius.call("set_trauma_radius_visible", true)

func _is_position_blocked_by_trauma(world_position: Vector3) -> bool:
	if not has_active_trauma_avoidance:
		return false

	if current_trauma_zone != null and current_trauma_zone.has_method("contains_world_position"):
		return bool(current_trauma_zone.call("contains_world_position", world_position))

	var flat_position: Vector3 = Vector3(world_position.x, 0.0, world_position.z)
	var flat_source: Vector3 = Vector3(last_fear_source_position.x, 0.0, last_fear_source_position.z)
	return flat_position.distance_to(flat_source) <= trauma_block_radius

func _pulse_active_trauma_warning() -> void:
	if trauma_warning_cooldown > 0.0:
		return

	trauma_warning_cooldown = 0.5
	if current_trauma_zone != null and current_trauma_zone.has_method("pulse_trauma_radius_warning"):
		current_trauma_zone.call("pulse_trauma_radius_warning")
	elif temporary_trauma_radius != null:
		temporary_trauma_radius.call("pulse_trauma_radius_warning")

func _emit_trauma_avoidance_changed() -> void:
	trauma_avoidance_changed.emit(has_active_trauma_avoidance, blocked_zone_name, is_blocked_zone_radius_visible())

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
