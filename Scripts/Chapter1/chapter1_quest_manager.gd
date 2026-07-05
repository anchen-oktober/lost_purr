extends Node
class_name Chapter1QuestManager

enum QuestState {
	INACTIVE,
	ACTIVE,
	COMPLETED,
	FAILED,
}

const QUEST_ORDER: Array[String] = [
	"Cutscene_Intro",
	"Quest_01_GoToCarTracks",
	"Tutorial_01_Run",
	"Quest_02_InspectTracksWithCatVision",
	"Tutorial_02_CatVision",
	"Quest_03_FollowOwnerAura",
	"Quest_04_EscapeAnimalControl",
	"Tutorial_03_Jump",
	"Quest_045_PurrWithNeighbor",
	"Quest_05_TalkToOtherCat",
	"Dialogue_01_OtherCat",
	"Quest_06_FollowTrailToRoad",
	"Quest_07_CrossRoadToPark",
	"Chapter_01_End",
]
const CHARACTER_ATTITUDE_FRIENDLY: int = 0

var quest_states: Dictionary = {}
var current_stage: String = ""
var _triggers: Dictionary = {}
var _markers: Dictionary = {}
var _chase_active: bool = false
var _road_checkpoint: Node3D = null
var _cat_vision_completed: bool = false
var _hint_manager: Node
var _dialogue_manager: Node
var _cat_vision_manager: Node
var _player: CharacterBody3D

func _ready() -> void:
	for quest_id in QUEST_ORDER:
		quest_states[quest_id] = QuestState.INACTIVE
	_find_nodes()
	_configure_dialogues()
	_connect_chapter_nodes()
	_set_all_triggers_enabled(false)
	call_deferred("_start_intro")

func _process(delta: float) -> void:
	if _chase_active:
		_update_chase(delta)

func get_quest_state(quest_id: String) -> int:
	return int(quest_states.get(quest_id, QuestState.INACTIVE))

func is_quest_active(quest_id: String) -> bool:
	return get_quest_state(quest_id) == QuestState.ACTIVE

func complete_quest(quest_id: String) -> void:
	if quest_states.get(quest_id, QuestState.INACTIVE) == QuestState.ACTIVE:
		quest_states[quest_id] = QuestState.COMPLETED

func _find_nodes() -> void:
	var current_scene := get_tree().current_scene
	_hint_manager = find_child("TutorialHintManager", true, false)
	_dialogue_manager = find_child("DialogueManager", true, false)
	_player = current_scene.find_child("PlayerCat", true, false) as CharacterBody3D if current_scene != null else null
	_cat_vision_manager = current_scene.find_child("CatVisionManager", true, false) if current_scene != null else null
	_collect_named_nodes(find_child("Markers", true, false), _markers)
	_collect_named_nodes(find_child("Triggers", true, false), _triggers)

func _collect_named_nodes(root: Node, target: Dictionary) -> void:
	if root == null:
		return
	for child in root.get_children():
		target[child.name] = child
		_collect_named_nodes(child, target)

func _connect_chapter_nodes() -> void:
	for trigger in _triggers.values():
		if trigger != null and trigger.has_signal("chapter_triggered"):
			trigger.chapter_triggered.connect(_on_chapter_triggered)
			trigger.player_entered_trigger.connect(_on_player_entered_trigger)
			trigger.player_exited_trigger.connect(_on_player_exited_trigger)

	for car in get_tree().get_nodes_in_group("chapter1_moving_cars"):
		if car.has_signal("player_hit_car"):
			car.connect("player_hit_car", _on_player_hit_car)

	if _dialogue_manager != null:
		_dialogue_manager.connect("dialogue_finished", _on_dialogue_finished)
	if _cat_vision_manager != null and _cat_vision_manager.has_signal("cat_state_changed"):
		_cat_vision_manager.connect("cat_state_changed", _on_cat_state_changed)

func _configure_dialogues() -> void:
	if _dialogue_manager == null:
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

func _start_intro() -> void:
	_activate_stage("Cutscene_Intro")
	if _dialogue_manager != null:
		_start_dialogue("DIALOGUE_Intro")
	else:
		_begin_car_tracks_quest()

func _activate_stage(stage_id: String) -> void:
	current_stage = stage_id
	if quest_states.has(stage_id) and quest_states[stage_id] == QuestState.INACTIVE:
		quest_states[stage_id] = QuestState.ACTIVE

func _set_trigger_enabled(trigger_name: String, is_enabled: bool) -> void:
	var trigger: Node = _triggers.get(trigger_name) as Node
	if trigger != null and trigger.has_method("set_trigger_enabled"):
		trigger.call("set_trigger_enabled", is_enabled)

func _set_all_triggers_enabled(is_enabled: bool) -> void:
	for trigger in _triggers.values():
		if trigger != null and trigger.has_method("set_trigger_enabled"):
			trigger.call("set_trigger_enabled", is_enabled)

func _on_chapter_triggered(trigger_id: String, reason: String, player: Node) -> void:
	match trigger_id:
		"TR_CarTracks":
			if is_quest_active("Quest_01_GoToCarTracks"):
				complete_quest("Quest_01_GoToCarTracks")
				if _dialogue_manager != null:
					_start_dialogue("DIALOGUE_CarTracks")
		"TR_CarTracksCatVision":
			if is_quest_active("Quest_02_InspectTracksWithCatVision"):
				_complete_cat_vision_tutorial()
		"TR_AuraTrailProgress":
			if is_quest_active("Quest_03_FollowOwnerAura"):
				_hide_hint()
		"TR_AnimalControlScene":
			if is_quest_active("Quest_03_FollowOwnerAura"):
				complete_quest("Quest_03_FollowOwnerAura")
				if _dialogue_manager != null:
					_start_dialogue("DIALOGUE_AnimalControl")
		"TR_ChaseEnd":
			if is_quest_active("Quest_04_EscapeAnimalControl"):
				_complete_chase()
		"TR_NeighborArea":
			if is_quest_active("Quest_045_PurrWithNeighbor") and reason == "purr":
				_complete_neighbor_purr()
		"TR_OtherCatDialogue":
			if is_quest_active("Quest_05_TalkToOtherCat"):
				complete_quest("Quest_05_TalkToOtherCat")
				_activate_stage("Dialogue_01_OtherCat")
				if _dialogue_manager != null:
					_start_dialogue("DIALOGUE_OtherCat")
		"TR_RoadStart":
			if is_quest_active("Quest_06_FollowTrailToRoad"):
				complete_quest("Quest_06_FollowTrailToRoad")
				_activate_stage("Quest_07_CrossRoadToPark")
				_road_checkpoint = _markers.get("M_RoadStart") as Node3D
				_show_hint("Дождись зеленого света.")
				_set_trigger_enabled("TR_RoadSafeIsland", true)
				_set_trigger_enabled("TR_RoadEnd", true)
		"TR_RoadSafeIsland":
			_road_checkpoint = _markers.get("M_RoadIsland") as Node3D
			_show_hint("Спрячься на островке безопасности.", 3.0)
		"TR_RoadEnd":
			if is_quest_active("Quest_07_CrossRoadToPark"):
				complete_quest("Quest_07_CrossRoadToPark")
				_activate_stage("Chapter_01_End")
				_hide_hint()
				if _dialogue_manager != null:
					_start_dialogue("DIALOGUE_ChapterEnd")

func _on_player_entered_trigger(trigger_id: String, _player_node: Node) -> void:
	var trigger: Node = _triggers.get(trigger_id) as Node
	if trigger != null and String(trigger.get("context_hint")) != "":
		_show_context_hint(String(trigger.get("context_hint")))

func _on_player_exited_trigger(_trigger_id: String, _player_node: Node) -> void:
	if _hint_manager != null:
		_hide_context_hint()

func _on_dialogue_finished(dialogue_id: String) -> void:
	match dialogue_id:
		"DIALOGUE_Intro":
			complete_quest("Cutscene_Intro")
			_begin_car_tracks_quest()
		"DIALOGUE_CarTracks":
			_begin_cat_vision_tutorial()
		"DIALOGUE_AnimalControl":
			_begin_chase()
		"DIALOGUE_KindNeighbor_AfterPurr":
			_begin_other_cat_quest()
		"DIALOGUE_OtherCat":
			complete_quest("Dialogue_01_OtherCat")
			_begin_road_trail_quest()
		"DIALOGUE_ChapterEnd":
			complete_quest("Chapter_01_End")

func _begin_car_tracks_quest() -> void:
	_activate_stage("Quest_01_GoToCarTracks")
	_show_hint("Найди следы машины.")
	_set_trigger_enabled("TR_CarTracks", true)

func _begin_cat_vision_tutorial() -> void:
	_activate_stage("Tutorial_01_Run")
	_show_hint("Удерживай ЛКМ, чтобы бежать.", 4.0)
	complete_quest("Tutorial_01_Run")
	_activate_stage("Quest_02_InspectTracksWithCatVision")
	_activate_stage("Tutorial_02_CatVision")
	_show_hint("Left Shift - кошачье зрение.")
	_set_trigger_enabled("TR_CarTracksCatVision", true)

func _complete_cat_vision_tutorial() -> void:
	if _cat_vision_completed:
		return
	_cat_vision_completed = true
	complete_quest("Quest_02_InspectTracksWithCatVision")
	complete_quest("Tutorial_02_CatVision")
	_hide_hint()
	_activate_stage("Quest_03_FollowOwnerAura")
	_show_hint("Иди за аурой, используя кошачье зрение.")
	_set_trigger_enabled("TR_AuraTrailProgress", true)
	_set_trigger_enabled("TR_AnimalControlScene", true)

func _begin_chase() -> void:
	_activate_stage("Quest_04_EscapeAnimalControl")
	_activate_stage("Tutorial_03_Jump")
	_show_hint("Пробел - прыгнуть.")
	_chase_active = true
	_set_trigger_enabled("TR_ChaseEnd", true)
	var chase_start := _markers.get("M_ChaseStart") as Node3D
	if chase_start != null and _player != null and _player.has_method("set_recovery_point"):
		_player.call("set_recovery_point", chase_start.global_transform, false)

func _complete_chase() -> void:
	_chase_active = false
	complete_quest("Quest_04_EscapeAnimalControl")
	complete_quest("Tutorial_03_Jump")
	_hide_hint()
	_activate_stage("Quest_045_PurrWithNeighbor")
	_show_hint("R - мурчать.")
	_set_trigger_enabled("TR_NeighborArea", true)
	if _dialogue_manager != null:
		_start_dialogue("DIALOGUE_KindNeighbor_BeforePurr")

func _complete_neighbor_purr() -> void:
	complete_quest("Quest_045_PurrWithNeighbor")
	_hide_hint()
	if _player != null and _player.has_method("play_purr_effect"):
		_player.call("play_purr_effect")
	var neighbor := find_child("NPC_KindNeighbor", true, false)
	if neighbor != null and neighbor.has_method("change_attitude"):
		neighbor.call("change_attitude", CHARACTER_ATTITUDE_FRIENDLY)
	if _dialogue_manager != null:
		_start_dialogue("DIALOGUE_KindNeighbor_AfterPurr")
	else:
		_begin_other_cat_quest()

func _begin_other_cat_quest() -> void:
	_activate_stage("Quest_05_TalkToOtherCat")
	_show_hint("E - поговорить.")
	_set_trigger_enabled("TR_OtherCatDialogue", true)

func _begin_road_trail_quest() -> void:
	_activate_stage("Quest_06_FollowTrailToRoad")
	_show_hint("След ведет к дороге.")
	_set_trigger_enabled("TR_RoadStart", true)

func _on_cat_state_changed(state: int) -> void:
	if is_quest_active("Quest_03_FollowOwnerAura") and int(state) != 1:
		_show_hint("След виден только кошачьим зрением.", 3.0)

func _update_chase(delta: float) -> void:
	if _player == null:
		return

	for npc_name in ["NPC_AnimalControl_01", "NPC_AnimalControl_02"]:
		var npc := find_child(npc_name, true, false) as Node3D
		if npc == null:
			continue
		var direction := _player.global_position - npc.global_position
		direction.y = 0.0
		var distance := direction.length()
		if distance <= 1.1:
			_reset_to_chase_start()
			return
		if distance > 0.08:
			npc.global_position += direction.normalized() * 2.2 * delta

func _reset_to_chase_start() -> void:
	var chase_start := _markers.get("M_ChaseStart") as Node3D
	if chase_start == null or _player == null:
		return

	_player.global_transform = chase_start.global_transform
	_player.velocity = Vector3.ZERO
	_player.set("target_position", _player.global_position)
	_player.set("moving", false)
	_player.set("mouse_down", false)
	_show_hint("Убеги от службы отлова.", 3.0)

func _on_player_hit_car(player: Node) -> void:
	if player == null:
		return
	var checkpoint := _road_checkpoint
	if checkpoint == null:
		checkpoint = _markers.get("M_RoadStart") as Node3D
	if checkpoint == null:
		return
	(player as Node3D).global_transform = checkpoint.global_transform
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	player.set("target_position", (player as Node3D).global_position)
	player.set("moving", false)
	player.set("mouse_down", false)
	_show_hint("Дождись зеленого света.", 3.0)

func _show_hint(text: String, duration: float = 0.0) -> void:
	if _hint_manager != null and _hint_manager.has_method("show_hint"):
		_hint_manager.call("show_hint", text, duration)

func _hide_hint() -> void:
	if _hint_manager != null and _hint_manager.has_method("hide_hint"):
		_hint_manager.call("hide_hint")

func _show_context_hint(text: String) -> void:
	if _hint_manager != null and _hint_manager.has_method("show_context_hint"):
		_hint_manager.call("show_context_hint", text)

func _hide_context_hint() -> void:
	if _hint_manager != null and _hint_manager.has_method("hide_context_hint"):
		_hint_manager.call("hide_context_hint")

func _start_dialogue(dialogue_id: String) -> void:
	if _dialogue_manager != null and _dialogue_manager.has_method("start_dialogue"):
		_dialogue_manager.call("start_dialogue", dialogue_id)
