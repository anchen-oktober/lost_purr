extends Area3D
class_name OldCrow
@export var exit_trigger: NodePath
@export var dialogue_id := "park_old_crow"
var _started := false
func _ready() -> void: body_entered.connect(_on_body_entered)
func _on_body_entered(body: Node3D) -> void:
	if body.name != "PlayerCat" or _started or JournalManager.get_park_flag("crow_conversation_completed"): return
	_started = true
	var dialogue := get_tree().current_scene.find_child("DialogueManager", true, false) as DialogueManager
	if dialogue == null: dialogue = DialogueManager.new(); dialogue.name = "DialogueManager"; get_tree().current_scene.add_child(dialogue)
	var lines: Array = [{"speaker_name":"ВОРОНА", "text":"Ты всё-таки дошёл."}, {"speaker_name":"ВОРОНА", "text":"Я видела твоего человека. Он прошёл через парк и всё время оглядывался."}]
	if not JournalManager.get_park_flag("playground_memory_completed"): lines.append({"speaker_name":"ВОРОНА", "text":"За ним шли те, кого люди обычно не замечают."})
	if not JournalManager.get_park_flag("other_world_memory_seen"): lines.append({"speaker_name":"ВОРОНА", "text":"И твой человек их видел. Он остановился у края леса, где пахло пустотой."})
	lines.append({"speaker_name":"ВОРОНА", "text":"Он ушёл к городу. Значит, ещё не поздно."})
	dialogue.set_dialogues({dialogue_id: lines}); dialogue.dialogue_finished.connect(_finish_dialogue, CONNECT_ONE_SHOT); dialogue.start_dialogue(dialogue_id)
func _finish_dialogue(_finished_id: String) -> void:
	JournalManager.set_park_flag("crow_conversation_completed"); JournalManager.set_park_flag("park_exit_opened")
	var exit_node := get_node_or_null(exit_trigger)
	if exit_node is Node3D: (exit_node as Node3D).visible = true
