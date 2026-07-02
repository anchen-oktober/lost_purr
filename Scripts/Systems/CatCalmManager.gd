extends Node

signal calm_changed(old_value: float, new_value: float)
signal calm_state_changed(new_state: String)
signal panic_started(reason_trigger_id: String)
signal panic_finished()

enum CalmState {
	CALM,
	UNEASY,
	SCARED,
	CRITICAL,
	PANIC,
}

var current_calm: float = 100.0
var current_state: int = CalmState.CALM
var player_cat: Node = null
var last_trigger_id: String = ""
var pending_reason: String = ""
var pending_trigger_id: String = ""

func _ready() -> void:
	call_deferred("_find_player")

func register_player(player: Node) -> void:
	player_cat = player
	if player_cat != null and player_cat.has_signal("fear_changed") and not player_cat.is_connected("fear_changed", _on_player_fear_changed):
		player_cat.connect("fear_changed", _on_player_fear_changed)
	_sync_from_player("register_player", "system")

func apply_calm_delta(delta: float, trigger_id: String = "", reason: String = "", source_node: Node = null) -> void:
	_find_player()
	var old_value: float = current_calm
	var next_value: float = clampf(current_calm + delta, 0.0, 100.0)
	last_trigger_id = trigger_id
	pending_trigger_id = trigger_id
	pending_reason = reason

	if player_cat != null:
		var fear_delta: float = current_calm - next_value
		if fear_delta > 0.0 and player_cat.has_method("apply_fear_damage"):
			player_cat.call("apply_fear_damage", fear_delta, source_node)
		elif fear_delta < 0.0 and player_cat.has_method("restore_fear"):
			player_cat.call("restore_fear", absf(fear_delta))
	else:
		_set_calm_without_player(next_value, trigger_id, reason)

	if player_cat == null:
		_log_calm_change(old_value, current_calm, trigger_id, reason)

func set_calm(value: float, trigger_id: String = "", reason: String = "", source_node: Node = null) -> void:
	apply_calm_delta(clampf(value, 0.0, 100.0) - current_calm, trigger_id, reason, source_node)

func restore_calm(amount: float, trigger_id: String = "", reason: String = "", source_node: Node = null) -> void:
	apply_calm_delta(absf(amount), trigger_id, reason, source_node)

func reduce_calm(amount: float, trigger_id: String = "", reason: String = "", source_node: Node = null) -> void:
	apply_calm_delta(-absf(amount), trigger_id, reason, source_node)

func get_calm() -> float:
	_find_player()
	return current_calm

func get_calm_state() -> String:
	return _get_state_name(current_state)

func set_last_safe_point(recovery_transform: Transform3D) -> void:
	_find_player()
	if player_cat != null and player_cat.has_method("set_recovery_point"):
		player_cat.call("set_recovery_point", recovery_transform, false)

func _on_player_fear_changed(_fear: float, calmness: float, _state: String, is_critical: bool) -> void:
	var old_value: float = current_calm
	current_calm = clampf(calmness, 0.0, 100.0)
	var old_state: int = current_state
	current_state = _get_state_for_calm(current_calm, is_critical)

	if not is_equal_approx(old_value, current_calm):
		calm_changed.emit(old_value, current_calm)
		_log_calm_change(old_value, current_calm, pending_trigger_id, pending_reason)
		pending_trigger_id = ""
		pending_reason = ""
	if old_state != current_state:
		calm_state_changed.emit(_get_state_name(current_state))
		if current_state == CalmState.PANIC:
			panic_started.emit(last_trigger_id)
		elif old_state == CalmState.PANIC:
			panic_finished.emit()

func _sync_from_player(trigger_id: String, reason: String) -> void:
	if player_cat == null or not player_cat.has_method("get_calmness"):
		return

	var old_value: float = current_calm
	current_calm = clampf(float(player_cat.call("get_calmness")), 0.0, 100.0)
	current_state = _get_state_for_calm(current_calm, bool(player_cat.get("is_critical_fear")))
	_log_calm_change(old_value, current_calm, trigger_id, reason)

func _set_calm_without_player(value: float, trigger_id: String, reason: String) -> void:
	var old_value: float = current_calm
	current_calm = clampf(value, 0.0, 100.0)
	var old_state: int = current_state
	current_state = _get_state_for_calm(current_calm, false)
	calm_changed.emit(old_value, current_calm)
	if old_state != current_state:
		calm_state_changed.emit(_get_state_name(current_state))
	_log_calm_change(old_value, current_calm, trigger_id, reason)

func _find_player() -> void:
	if player_cat != null:
		return
	if get_tree().current_scene == null:
		return
	var player: Node = get_tree().current_scene.find_child("PlayerCat", true, false)
	if player != null:
		register_player(player)

func _get_state_for_calm(value: float, is_critical: bool) -> int:
	if value <= 0.0 or is_critical:
		return CalmState.PANIC
	if value <= 25.0:
		return CalmState.CRITICAL
	if value <= 50.0:
		return CalmState.SCARED
	if value <= 75.0:
		return CalmState.UNEASY
	return CalmState.CALM

func _get_state_name(state: int) -> String:
	match state:
		CalmState.CALM:
			return "CALM"
		CalmState.UNEASY:
			return "UNEASY"
		CalmState.SCARED:
			return "SCARED"
		CalmState.CRITICAL:
			return "CRITICAL"
		CalmState.PANIC:
			return "PANIC"
		_:
			return "UNKNOWN"

func _log_calm_change(old_value: float, new_value: float, trigger_id: String, reason: String) -> void:
	if is_equal_approx(old_value, new_value):
		return
	print("Calm changed: %.1f -> %.1f | reason: %s | trigger_id: %s" % [
		old_value,
		new_value,
		reason if reason != "" else "unspecified",
		trigger_id if trigger_id != "" else "none",
	])
