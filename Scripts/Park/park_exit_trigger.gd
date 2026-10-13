extends "res://Scripts/Portals/scene_portal.gd"
class_name ParkExitTrigger
@export var required_flag := "park_exit_opened"
func _on_body_entered(body: Node3D) -> void:
	if JournalManager.get_park_flag(required_flag): super._on_body_entered(body)
