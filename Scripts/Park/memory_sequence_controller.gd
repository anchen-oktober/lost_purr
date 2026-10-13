extends Node
class_name MemorySequenceController
signal fragment_accepted(stage_id: String)
signal sequence_reset
signal sequence_completed
@export var sequence: Array[String] = ["swing", "carousel", "slide"]
@export var completion_flag := "playground_memory_completed"
@export var journal_entry_id := "park_playground_memory"
var index := 0
func _ready() -> void:
	if JournalManager.get_park_flag(completion_flag): index = sequence.size()
func try_fragment(stage_id: String) -> bool:
	if index >= sequence.size(): return true
	if stage_id == sequence[index]:
		index += 1; fragment_accepted.emit(stage_id)
		if index == sequence.size(): JournalManager.set_park_flag(completion_flag); JournalManager.collect_entry({"id": journal_entry_id}); sequence_completed.emit()
		return true
	index = 0; sequence_reset.emit(); return false
