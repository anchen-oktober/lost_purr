extends Area3D
class_name LPSafePoint

@export var safe_point_id: String = ""
@export var restore_calm_on_use: float = 25.0
@export var is_current: bool = false
@export var restore_on_enter: bool = false

func _ready() -> void:
	add_to_group("LPSafePoint")
	body_entered.connect(_on_body_entered)

func make_current(body: Node = null) -> void:
	is_current = true
	var calm_manager: Node = get_node_or_null("/root/CatCalmManager")
	if calm_manager != null and calm_manager.has_method("set_last_safe_point"):
		calm_manager.call("set_last_safe_point", global_transform)

	if body != null and body.has_method("set_recovery_point"):
		body.call("set_recovery_point", global_transform, false)

func restore_after_panic() -> void:
	var calm_manager: Node = get_node_or_null("/root/CatCalmManager")
	if calm_manager != null and calm_manager.has_method("set_calm"):
		calm_manager.call("set_calm", restore_calm_on_use, safe_point_id, "safe_point_panic_restore", self)

func _on_body_entered(body: Node3D) -> void:
	if body == null or body.name != "PlayerCat":
		return

	make_current(body)
	if restore_on_enter:
		var calm_manager: Node = get_node_or_null("/root/CatCalmManager")
		if calm_manager != null and calm_manager.has_method("set_calm"):
			calm_manager.call("set_calm", restore_calm_on_use, safe_point_id, "safe_point_enter", self)
