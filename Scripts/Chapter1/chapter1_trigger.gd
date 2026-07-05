extends Area3D
class_name Chapter1Trigger

signal chapter_triggered(trigger_id: String, reason: String, player: Node)
signal player_entered_trigger(trigger_id: String, player: Node)
signal player_exited_trigger(trigger_id: String, player: Node)

@export var trigger_id: String = ""
@export_enum("Enter", "Interact", "Purr", "CatVision", "Exit") var activation_type: int = 0
@export var context_hint: String = ""
@export var one_shot: bool = true
@export var enabled: bool = true

var player_inside: bool = false
var player_ref: Node = null
var activated: bool = false
var _cat_vision_was_active: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	monitoring = enabled

func _process(_delta: float) -> void:
	if not enabled or not player_inside or activation_type != 3:
		return

	var is_active := _is_cat_vision_active()
	if is_active and not _cat_vision_was_active:
		_try_activate("cat_vision")
	_cat_vision_was_active = is_active

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or not player_inside:
		return

	if event is not InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if activation_type == 1 and key_event.physical_keycode == KEY_E:
		if _try_activate("interact"):
			get_viewport().set_input_as_handled()
	elif activation_type == 2 and key_event.physical_keycode == KEY_R:
		if _try_activate("purr"):
			get_viewport().set_input_as_handled()

func set_trigger_enabled(is_enabled: bool) -> void:
	enabled = is_enabled
	set_deferred("monitoring", is_enabled)
	if not is_enabled:
		player_inside = false
		player_ref = null

func _on_body_entered(body: Node3D) -> void:
	if not enabled or body == null or body.name != "PlayerCat":
		return

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
	if not enabled or (activated and one_shot):
		return false

	activated = true
	chapter_triggered.emit(_get_trigger_id(), reason, player_ref)
	return true

func _is_cat_vision_active() -> bool:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return false
	var manager := current_scene.find_child("CatVisionManager", true, false)
	if manager == null:
		return false
	if manager.has_method("get_cat_state"):
		return int(manager.call("get_cat_state")) == 1
	return bool(manager.get("is_cat_vision_enabled"))

func _get_trigger_id() -> String:
	return trigger_id if trigger_id != "" else name
