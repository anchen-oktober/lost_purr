extends Node3D

func _ready() -> void:
	call_deferred("_register_direct_launch")

func _register_direct_launch() -> void:
	# MainScene already initializes levels through change_level. F6 must do the same.
	if get_tree().current_scene == self:
		GameManager.register_current_scene_player()
