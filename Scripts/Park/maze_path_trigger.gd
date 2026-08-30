extends Area3D
class_name MazePathTrigger
@export var maze_id := "park_maze"
@export var sequence_index := 0
@export var controller: MazeSequenceController
func _ready() -> void:
	body_entered.connect(_entered)
func _entered(body: Node3D) -> void:
	if body.name == "PlayerCat" and controller != null: controller.enter_marker(sequence_index)
