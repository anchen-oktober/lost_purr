extends Node
class_name Chapter1QuestManager

var completed_or_started_events: Dictionary = {}

var _hint_manager: Node
var _dialogue_manager: Node
var _cat_vision_manager: Node
var _player: CharacterBody3D
var _chapter_root: Node
var _chase_active: bool = false

func _ready() -> void:
	_find_nodes()
	_configure_dialogues()
	_connect_helpers()

func _process(delta: float) -> void:
	if _chase_active:
		_update_chase(delta)

func start_quest(quest_id: String) -> void:
	if quest_id == "":
		push_warning("Chapter1QuestManager.start_quest called with empty quest_id.")
		return
	if completed_or_started_events.has(quest_id):
		return

	completed_or_started_events[quest_id] = true
	match quest_id:
		"Cutscene_Intro":
			start_intro_cutscene()
		"Quest_01_GoToCarTracks":
			show_hint("Найди следы машины.")
		"Quest_02_CatVision", "Tutorial_02_CatVision", "Quest_02_InspectTracksWithCatVision":
			show_hint("Left Shift - кошачье зрение.")
		"Quest_03_FollowOwnerAura":
			show_hint("След виден только кошачьим зрением.")
		"Quest_04_AnimalControl", "Quest_04_EscapeAnimalControl":
			start_animal_control_chase()
		"Quest_04_AnimalControlEnd":
			stop_animal_control_chase()
			show_hint("Ты оторвался. Найди безопасный проход дальше.")
		"Quest_05_NeighborPurr", "Quest_045_PurrWithNeighbor":
			show_hint("R - мурчать.")
		"Dialogue_OtherCat", "Dialogue_01_OtherCat":
			start_dialogue("DIALOGUE_OtherCat")
		"Quest_07_RoadCrossing", "Quest_07_CrossRoadToPark":
			show_hint("Дождись зеленого света.")
		"Chapter1_End", "Chapter_01_End":
			finish_chapter()
		_:
			push_warning("Unknown Chapter1 quest_id: %s" % quest_id)

func show_hint(text: String, duration: float = 0.0) -> void:
	if _hint_manager != null and _hint_manager.has_method("show_hint"):
		_hint_manager.call("show_hint", text, duration)

func hide_hint() -> void:
	if _hint_manager != null and _hint_manager.has_method("hide_hint"):
		_hint_manager.call("hide_hint")

func show_context_hint(text: String) -> void:
	if _hint_manager != null and _hint_manager.has_method("show_context_hint"):
		_hint_manager.call("show_context_hint", text)

func hide_context_hint() -> void:
	if _hint_manager != null and _hint_manager.has_method("hide_context_hint"):
		_hint_manager.call("hide_context_hint")

func start_dialogue(dialogue_id: String) -> void:
	if dialogue_id == "":
		return
	if _dialogue_manager != null and _dialogue_manager.has_method("start_dialogue"):
		_dialogue_manager.call("start_dialogue", dialogue_id)

func start_intro_cutscene() -> void:
	start_dialogue("DIALOGUE_Intro")

func start_animal_control_chase() -> void:
	start_dialogue("DIALOGUE_AnimalControl")
	_chase_active = true
	show_hint("Убеги от службы отлова.", 3.0)
	if _cat_vision_manager != null and _cat_vision_manager.has_method("set_danger_active"):
		_cat_vision_manager.call("set_danger_active", true)

func stop_animal_control_chase() -> void:
	_chase_active = false
	if _cat_vision_manager != null and _cat_vision_manager.has_method("set_danger_active"):
		_cat_vision_manager.call("set_danger_active", false)

func finish_chapter() -> void:
	stop_animal_control_chase()
	hide_hint()
	start_dialogue("DIALOGUE_ChapterEnd")

func is_event_started(quest_id: String) -> bool:
	return completed_or_started_events.has(quest_id)

func get_quest_state(quest_id: String) -> int:
	return 1 if completed_or_started_events.has(quest_id) else 0

func is_quest_active(quest_id: String) -> bool:
	return completed_or_started_events.has(quest_id)

func complete_quest(quest_id: String) -> void:
	completed_or_started_events[quest_id] = true

func _find_nodes() -> void:
	var current_scene := get_tree().current_scene
	_chapter_root = _get_chapter_root()
	_hint_manager = _find_child_in_chapter_or_scene("TutorialHintManager")
	_dialogue_manager = _find_child_in_chapter_or_scene("DialogueManager")
	_player = current_scene.find_child("PlayerCat", true, false) as CharacterBody3D if current_scene != null else null
	_cat_vision_manager = current_scene.find_child("CatVisionManager", true, false) if current_scene != null else null

func _get_chapter_root() -> Node:
	var node: Node = self
	while node != null:
		if node.name == "Chapter1":
			return node
		node = node.get_parent()
	return self

func _find_child_in_chapter_or_scene(child_name: String) -> Node:
	if _chapter_root != null:
		var child := _chapter_root.find_child(child_name, true, false)
		if child != null:
			return child
	var current_scene := get_tree().current_scene
	return current_scene.find_child(child_name, true, false) if current_scene != null else null

func _connect_helpers() -> void:
	if _dialogue_manager != null and _dialogue_manager.has_signal("dialogue_finished"):
		if not _dialogue_manager.is_connected("dialogue_finished", _on_dialogue_finished):
			_dialogue_manager.connect("dialogue_finished", _on_dialogue_finished)

	for car in get_tree().get_nodes_in_group("chapter1_moving_cars"):
		if car.has_signal("player_hit_car") and not car.is_connected("player_hit_car", _on_player_hit_car):
			car.connect("player_hit_car", _on_player_hit_car)

func _configure_dialogues() -> void:
	if _dialogue_manager == null or not _dialogue_manager.has_method("set_dialogues"):
		return

	_dialogue_manager.call("set_dialogues", {
		"DIALOGUE_Intro": [
			{"speaker_name": "", "text": "Визг машины."},
			{"speaker_name": "", "text": "Кот поднимает заспанную мордочку."},
			{"speaker_name": "", "text": "За окном мелькает черный силуэт."},
			{"speaker_name": "", "text": "Занавески колышутся. Силуэт пропадает."},
			{"speaker_name": "", "text": "В комнате беспорядок."},
			{"speaker_name": "", "text": "Кот видит ауру хозяина на вещах - и рядом чужую, пугающую ауру."},
		],
		"DIALOGUE_CarTracks": [
			{"speaker_name": "", "text": "Кот чувствует запах хозяина."},
			{"speaker_name": "", "text": "Но рядом - другой след. Холодный. Пустой."},
		],
		"DIALOGUE_AnimalControl": [
			{"speaker_name": "", "text": "Во дворе стоит машина отлова."},
			{"speaker_name": "", "text": "Два человека разговаривают."},
			{"speaker_name": "Служба отлова", "text": "Эй! Вон еще один!"},
			{"speaker_name": "Служба отлова", "text": "Не дай ему уйти!"},
		],
		"DIALOGUE_KindNeighbor_BeforePurr": [
			{"speaker_name": "Соседка", "text": "Тебе сюда нельзя."},
			{"speaker_name": "Соседка", "text": "Иди домой, малыш."},
		],
		"DIALOGUE_KindNeighbor_AfterPurr": [
			{"speaker_name": "Соседка", "text": "Ладно... проходи."},
			{"speaker_name": "Соседка", "text": "Только осторожно."},
		],
		"DIALOGUE_OtherCat": [
			{"speaker_name": "Другой кот", "text": "Ты пахнешь домом. И страхом."},
			{"speaker_name": "Главный кот", "text": "Мой человек ушел. Я иду за ним."},
			{"speaker_name": "Другой кот", "text": "Люди редко уходят просто так. Когда они начинают пахнуть пустотой, за ними приходят Тихие."},
			{"speaker_name": "Главный кот", "text": "Тихие?"},
			{"speaker_name": "Другой кот", "text": "Смотри не ушами. Смотри тем, что помнит дорогу."},
			{"speaker_name": "Главный кот", "text": "Ты видел его след?"},
			{"speaker_name": "Другой кот", "text": "Видел. Он идет к дороге. А дальше - к большому шуму."},
		],
		"DIALOGUE_ChapterEnd": [
			{"speaker_name": "", "text": "За дорогой начинается парк."},
			{"speaker_name": "", "text": "След хозяина почти исчезает, но кот все еще чувствует его - где-то впереди."},
			{"speaker_name": "", "text": "Конец первой главы. Переход в парк будет добавлен позже."},
		],
	})

func _on_dialogue_finished(dialogue_id: String) -> void:
	completed_or_started_events[dialogue_id] = true

func _on_player_hit_car(player: Node) -> void:
	show_hint("Осторожно, машины!", 2.0)
	if player != null and player.has_method("apply_knockback"):
		player.call("apply_knockback", -player.global_transform.basis.z * 5.0)

func _update_chase(delta: float) -> void:
	if _player == null or _chapter_root == null:
		return
	_update_chase_for_node(_chapter_root, delta)

func _update_chase_for_node(node: Node, delta: float) -> void:
	if node == null:
		return
	if node.name.begins_with("NPC_AnimalControl") and node is Node3D:
		var npc := node as Node3D
		var target := _player.global_position
		npc.global_position = npc.global_position.move_toward(target, 2.4 * delta)
	for child in node.get_children():
		_update_chase_for_node(child, delta)
