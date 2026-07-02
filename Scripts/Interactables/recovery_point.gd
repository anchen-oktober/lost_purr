extends Area3D

@export var restore_on_enter: bool = true
@export var restore_amount: float = -1.0

func _ready() -> void:
	add_to_group("RecoveryPoint")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body == null or body.name != "PlayerCat":
		return

	if body.has_method("set_recovery_point"):
		body.call("set_recovery_point", global_transform, restore_on_enter and restore_amount < 0.0)

	if restore_on_enter and restore_amount >= 0.0 and body.has_method("recover_from_fear"):
		body.call("recover_from_fear", restore_amount)
