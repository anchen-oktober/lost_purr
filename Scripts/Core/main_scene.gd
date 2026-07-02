extends Node3D

@export var start_level_id: String = "village"
@export var start_spawn_name: String = "SpawnFromVillage"

func _ready() -> void:
	print("MainScene ready")
	await get_tree().process_frame
	var level_container: Node = get_node_or_null("LevelContainer")
	if level_container != null and level_container.get_child_count() == 0:
		await GameManager.change_level(start_level_id, start_spawn_name)
