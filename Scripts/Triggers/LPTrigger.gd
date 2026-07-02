extends Area3D
class_name LPTrigger

enum TriggerCategory {
	POSITIVE,
	NEGATIVE,
	NEUTRAL,
}

enum TriggerActivationType {
	ON_ENTER_AREA,
	ON_EXIT_AREA,
	ON_INTERACT_E,
	ON_CAT_VISION,
	ON_PURR,
	ON_LOOK_AT,
	ON_SCRIPTED_EVENT,
	ON_NPC_PROXIMITY,
	ON_SOUND_EVENT,
}

enum FeedbackType {
	NONE,
	WARM_LIGHT,
	COLD_NOISE,
	RED_DANGER,
	JOURNAL_NOTE,
	CAT_REACTION,
	CAMERA_SHAKE,
	HUD_CHANGE,
	SOUND_DISTORTION,
	PURR_FEEDBACK,
}

@export var trigger_id: String = ""
@export var trigger_name: String = ""
@export var trigger_category: TriggerCategory = TriggerCategory.NEUTRAL
@export var activation_type: TriggerActivationType = TriggerActivationType.ON_ENTER_AREA
@export var calm_delta: float = 0.0
@export var is_repeatable: bool = false
@export var cooldown: float = 0.0
@export var requires_interaction: bool = false
@export var requires_cat_vision: bool = false
@export var requires_purr: bool = false
@export var journal_entry_id: String = ""
@export var can_become_positive: bool = false
@export var can_become_negative: bool = false
@export var blocks_movement: bool = false
@export var creates_fear_zone: bool = false
@export var safe_point_id: String = ""
@export var location_tag: String = ""
@export var feedback_type: FeedbackType = FeedbackType.NONE
@export var is_periodic: bool = false
@export var periodic_interval: float = 1.0
@export var max_total_delta_per_enter: float = 0.0

var player_inside: bool = false
var has_activated: bool = false
var cooldown_left: float = 0.0
var periodic_time_left: float = 0.0
var total_delta_this_enter: float = 0.0
var player_ref: Node = null
var was_cat_vision_active: bool = false

func _ready() -> void:
	add_to_group("LPTrigger")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	periodic_time_left = periodic_interval

func _process(delta: float) -> void:
	if cooldown_left > 0.0:
		cooldown_left = maxf(cooldown_left - delta, 0.0)

	if player_inside and activation_type == TriggerActivationType.ON_CAT_VISION:
		var is_active: bool = _is_cat_vision_active()
		if is_active and not was_cat_vision_active:
			activate_trigger("cat_vision")
		was_cat_vision_active = is_active

	if player_inside and _uses_interaction() and requires_cat_vision:
		_update_prompt()

	if player_inside and is_periodic:
		periodic_time_left -= delta
		if periodic_time_left <= 0.0:
			periodic_time_left = maxf(periodic_interval, 0.05)
			_try_periodic_activation()

func _unhandled_input(event: InputEvent) -> void:
	if not player_inside:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return

	if key_event.physical_keycode == KEY_E and _uses_interaction():
		if activate_trigger("interact_e"):
			get_viewport().set_input_as_handled()
	elif key_event.physical_keycode == KEY_R and _uses_purr():
		if activate_trigger("purr"):
			get_viewport().set_input_as_handled()

func activate_trigger(reason: String = "scripted_event") -> bool:
	if not _can_activate():
		return false

	has_activated = true
	cooldown_left = cooldown
	_apply_calm_delta(reason)
	_unlock_journal_entry()
	_apply_safe_point()
	_apply_feedback(reason)
	return true

func _on_body_entered(body: Node3D) -> void:
	if body == null or body.name != "PlayerCat":
		return

	player_inside = true
	player_ref = body
	total_delta_this_enter = 0.0
	periodic_time_left = periodic_interval
	was_cat_vision_active = _is_cat_vision_active()
	_update_prompt()

	if activation_type == TriggerActivationType.ON_ENTER_AREA and not _uses_interaction() and not _uses_purr():
		activate_trigger("enter_area")
	elif activation_type == TriggerActivationType.ON_CAT_VISION and was_cat_vision_active:
		activate_trigger("cat_vision")

func _on_body_exited(body: Node3D) -> void:
	if body == null or body.name != "PlayerCat":
		return

	if activation_type == TriggerActivationType.ON_EXIT_AREA:
		activate_trigger("exit_area")

	player_inside = false
	player_ref = null
	total_delta_this_enter = 0.0
	_hide_prompt()

func _try_periodic_activation() -> void:
	if not _can_activate(false):
		return
	if max_total_delta_per_enter != 0.0:
		var next_total: float = total_delta_this_enter + calm_delta
		if calm_delta < 0.0 and next_total < max_total_delta_per_enter:
			return
		if calm_delta > 0.0 and next_total > max_total_delta_per_enter:
			return

	total_delta_this_enter += calm_delta
	_apply_calm_delta("periodic")
	_apply_feedback("periodic")

func _apply_calm_delta(reason: String) -> void:
	if is_zero_approx(calm_delta):
		return

	var resolved_delta: float = calm_delta
	if trigger_category == TriggerCategory.NEGATIVE:
		resolved_delta = -absf(calm_delta)
	elif trigger_category == TriggerCategory.POSITIVE:
		resolved_delta = absf(calm_delta)

	var calm_manager: Node = get_node_or_null("/root/CatCalmManager")
	if calm_manager != null and calm_manager.has_method("apply_calm_delta"):
		calm_manager.call("apply_calm_delta", resolved_delta, _get_trigger_id(), reason, self if creates_fear_zone else null)
	elif player_ref != null:
		if resolved_delta < 0.0 and player_ref.has_method("apply_fear_damage"):
			player_ref.call("apply_fear_damage", absf(resolved_delta), self if creates_fear_zone else null)
		elif resolved_delta > 0.0 and player_ref.has_method("restore_fear"):
			player_ref.call("restore_fear", resolved_delta)

func _unlock_journal_entry() -> void:
	if journal_entry_id == "":
		return

	var journal_manager: Node = get_node_or_null("/root/JournalManager")
	if journal_manager != null and journal_manager.has_method("collect_entry"):
		journal_manager.call("collect_entry", {"id": journal_entry_id})
	else:
		print("Journal entry unlocked: ", journal_entry_id)

func _apply_safe_point() -> void:
	if safe_point_id == "" or player_ref == null:
		return

	var calm_manager: Node = get_node_or_null("/root/CatCalmManager")
	if calm_manager != null and calm_manager.has_method("set_last_safe_point"):
		calm_manager.call("set_last_safe_point", global_transform)
	elif player_ref.has_method("set_recovery_point"):
		player_ref.call("set_recovery_point", global_transform, false)

func _apply_feedback(reason: String) -> void:
	if feedback_type == FeedbackType.NONE:
		return

	print("LPTrigger feedback: %s | trigger_id: %s | reason: %s" % [
		_get_feedback_name(),
		_get_trigger_id(),
		reason,
	])

func _can_activate(check_cooldown: bool = true) -> bool:
	if requires_cat_vision and not _is_cat_vision_active():
		return false
	if has_activated and not is_repeatable:
		return false
	if check_cooldown and cooldown_left > 0.0:
		return false
	return true

func _uses_interaction() -> bool:
	return requires_interaction or activation_type == TriggerActivationType.ON_INTERACT_E

func _uses_purr() -> bool:
	return requires_purr or activation_type == TriggerActivationType.ON_PURR

func _is_cat_vision_active() -> bool:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return false

	var cat_vision_manager: Node = current_scene.find_child("CatVisionManager", true, false)
	if cat_vision_manager == null:
		return false

	if cat_vision_manager.has_method("get_cat_state"):
		return int(cat_vision_manager.call("get_cat_state")) == 1

	return bool(cat_vision_manager.get("is_cat_vision_enabled")) or bool(cat_vision_manager.get("is_cat_vision_forced"))

func _update_prompt() -> void:
	if not _uses_interaction():
		return
	if requires_cat_vision and not _is_cat_vision_active():
		_hide_prompt()
		return

	var journal_manager: Node = get_node_or_null("/root/JournalManager")
	if journal_manager == null:
		return

	var journal_ui: Node = journal_manager.get("journal_ui") as Node
	if journal_ui != null:
		var prompt: String = "[E] " + (trigger_name if trigger_name != "" else "Interact")
		if journal_ui.has_method("show_prompt_for_node"):
			journal_ui.call("show_prompt_for_node", prompt, self)
		elif journal_ui.has_method("show_prompt"):
			journal_ui.call("show_prompt", prompt)

func _hide_prompt() -> void:
	var journal_manager: Node = get_node_or_null("/root/JournalManager")
	if journal_manager == null:
		return

	var journal_ui: Node = journal_manager.get("journal_ui") as Node
	if journal_ui != null and journal_ui.has_method("hide_prompt"):
		journal_ui.call("hide_prompt")

func _get_trigger_id() -> String:
	if trigger_id != "":
		return trigger_id
	return name

func _get_feedback_name() -> String:
	match feedback_type:
		FeedbackType.WARM_LIGHT:
			return "WARM_LIGHT"
		FeedbackType.COLD_NOISE:
			return "COLD_NOISE"
		FeedbackType.RED_DANGER:
			return "RED_DANGER"
		FeedbackType.JOURNAL_NOTE:
			return "JOURNAL_NOTE"
		FeedbackType.CAT_REACTION:
			return "CAT_REACTION"
		FeedbackType.CAMERA_SHAKE:
			return "CAMERA_SHAKE"
		FeedbackType.HUD_CHANGE:
			return "HUD_CHANGE"
		FeedbackType.SOUND_DISTORTION:
			return "SOUND_DISTORTION"
		FeedbackType.PURR_FEEDBACK:
			return "PURR_FEEDBACK"
		_:
			return "NONE"
