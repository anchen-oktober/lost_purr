extends Area3D

@export var restore_on_enter: bool = true
@export var restore_amount: float = 25.0
@export var can_restore_repeatedly: bool = false
@export var reset_when_player_leaves: bool = true
@export var restore_cooldown: float = 0.0
@export var recovery_marker: Node3D

var has_restored: bool = false
var cooldown_left: float = 0.0

func _ready() -> void:
	add_to_group("RecoveryPoint")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if cooldown_left > 0.0:
		cooldown_left = maxf(cooldown_left - delta, 0.0)

func _on_body_entered(body: Node3D) -> void:
	if body == null or body.name != "PlayerCat":
		return

	if body.has_method("set_recovery_point"):
		body.call("set_recovery_point", _get_recovery_transform(), false)

	if not restore_on_enter or not body.has_method("restore_fear"):
		return

	if body.has_method("can_receive_positive_restore") and not body.call("can_receive_positive_restore"):
		return

	if has_restored and not can_restore_repeatedly:
		return
	if cooldown_left > 0.0:
		return

	body.call("restore_fear", restore_amount)
	has_restored = true
	cooldown_left = restore_cooldown

func _on_body_exited(body: Node3D) -> void:
	if body == null or body.name != "PlayerCat":
		return

	if reset_when_player_leaves:
		has_restored = false

func _get_recovery_transform() -> Transform3D:
	if recovery_marker != null:
		return recovery_marker.global_transform

	var marker: Marker3D = find_child("RecoveryMarker", true, false) as Marker3D
	if marker != null:
		return marker.global_transform

	return global_transform
