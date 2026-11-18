@tool
extends Area3D
class_name Chapter1Trigger

const GroundVisual = preload("res://Scripts/Chapter1/story_trigger_ground_visual.gd")

signal chapter_triggered(trigger_id: String, reason: String, player: Node)
signal player_entered_trigger(trigger_id: String, player: Node)
signal player_exited_trigger(trigger_id: String, player: Node)

@export var trigger_id: String = ""
@export_enum("Enter", "Interact", "Purr", "CatVision", "Exit") var activation_type: int = 0
@export var context_hint: String = ""
@export var one_shot: bool = true
@export var enabled: bool = true
@export var requires_cat_vision: bool = false

var player_inside: bool = false
var player_ref: Node = null
var activated: bool = false
var _cat_vision_was_active: bool = false

func _ready() -> void:
	# This child only draws the zone; it never changes trigger collisions.
	if get_node_or_null("StoryTriggerGroundVisual") == null:
		var visual := GroundVisual.new()
		visual.name = "StoryTriggerGroundVisual"
		add_child(visual)
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	monitoring = enabled
	print("[TRIGGER] Ready: %s | monitoring=%s | layer=%s | mask=%s" % [_get_trigger_id(), monitoring, collision_layer, collision_mask])

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not enabled or not player_inside:
		return

	var is_active := _is_cat_vision_active()
	if activation_type == 3 and is_active and not _cat_vision_was_active:
		_try_activate("cat_vision")
	_cat_vision_was_active = is_active

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not enabled or not player_inside:
		return

	if event is not InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if activation_type == 1 and key_event.physical_keycode == KEY_E:
		if requires_cat_vision and not _is_cat_vision_active():
			_print_blocked("Cat Vision (Q) is not active")
			return
		if _try_activate("interact"):
			get_viewport().set_input_as_handled()
	elif activation_type == 2 and key_event.physical_keycode == KEY_R:
		if _try_activate("purr"):
			get_viewport().set_input_as_handled()

func set_trigger_enabled(is_enabled: bool) -> void:
	enabled = is_enabled
	set_deferred("monitoring", is_enabled)
	print("[TRIGGER] %s enabled=%s | monitoring=%s" % [_get_trigger_id(), is_enabled, is_enabled])
	if not is_enabled:
		player_inside = false
		player_ref = null
	else:
		call_deferred("_restore_player_overlap")

func reset_story_trigger() -> void:
	activated = false
	player_inside = false
	player_ref = null
	_cat_vision_was_active = false
	set_trigger_enabled(false)

func _restore_player_overlap() -> void:
	# `monitoring` is enabled deferred so wait for the next physics update before
	# querying overlaps.  This also covers a player who is already standing in a
	# newly enabled story zone.
	await get_tree().physics_frame
	if not enabled or player_inside:
		return
	for body in get_overlapping_bodies():
		if body is Node3D and body.name == "PlayerCat":
			_on_body_entered(body as Node3D)
			return

func _on_body_entered(body: Node3D) -> void:
	if not enabled or body == null or body.name != "PlayerCat":
		return

	print("[TRIGGER] Entered: %s" % _get_trigger_id())
	print("[TRIGGER] Player detected: true | activation=%s" % _activation_name())
	player_inside = true
	player_ref = body
	_cat_vision_was_active = _is_cat_vision_active()
	player_entered_trigger.emit(_get_trigger_id(), body)
	if activation_type == 0:
		_try_activate("enter")
	elif activation_type == 3 and _cat_vision_was_active:
		_try_activate("cat_vision")

func _on_body_exited(body: Node3D) -> void:
	if body == null or body != player_ref:
		return

	if activation_type == 4:
		_try_activate("exit")
	player_exited_trigger.emit(_get_trigger_id(), body)
	player_inside = false
	player_ref = null

func _try_activate(reason: String) -> bool:
	if not enabled:
		_print_blocked("trigger is disabled")
		return false
	if activated and one_shot:
		_print_blocked("one-shot trigger has already fired")
		return false
	if requires_cat_vision and not _is_cat_vision_active():
		_print_blocked("Cat Vision (Q) is not active")
		return false

	activated = true
	print("[TRIGGER] Conditions: passed | %s | reason=%s" % [_get_trigger_id(), reason])
	print("[TRIGGER] Event emitted: %s" % _get_trigger_id())
	chapter_triggered.emit(_get_trigger_id(), reason, player_ref)
	return true

func _print_blocked(reason: String) -> void:
	print("[TRIGGER] %s BLOCKED\nReason: %s" % [_get_trigger_id(), reason])

func _is_cat_vision_active() -> bool:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return false
	var manager := current_scene.find_child("CatVisionManager", true, false)
	if manager == null:
		return false
	if manager.has_method("get_cat_state"):
		return int(manager.call("get_cat_state")) == 1
	return false

func _get_trigger_id() -> String:
	return trigger_id if trigger_id != "" else name

func _activation_name() -> String:
	match activation_type:
		0:
			return "enter"
		1:
			return "interact"
		2:
			return "purr"
		3:
			return "cat_vision"
		4:
			return "exit"
	return "unknown"
