extends Node
class_name MazeSequenceController
signal maze_completed
@export var maze_id := "park_maze"
@export var sequence_length := 4
@export var reset_on_wrong_path := true
var progress := 0
func _ready() -> void:
	if JournalManager.get_park_flag("maze_completed"): progress = sequence_length
func enter_marker(marker_index: int) -> void:
	if progress >= sequence_length: return
	if marker_index == progress:
		progress += 1
		if progress == sequence_length: JournalManager.set_park_flag("maze_completed"); maze_completed.emit()
	elif reset_on_wrong_path: progress = 0
