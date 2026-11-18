extends Node
class_name Chapter1QuestManager

enum QuestState {
	INACTIVE,
	ACTIVE,
	COMPLETED,
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

# Authored Chapter 1 trigger-to-event bindings.  The intro binding is included
# explicitly so every Village story trigger has a deterministic event.
const TRIGGER_EVENT_NAMES := {
	"TR_IntroCutscene": "Cutscene_Intro",
	"TR_CarTracks": "DIALOGUE_CarTracks",
	"TR_CarTracksCatVision": "Quest_02_InspectTracksWithCatVision",
	"TR_AuraTrailProgress": "hide_aura_hint",
	"TR_AnimalControlScene": "DIALOGUE_AnimalControl",
	"TR_ChaseEnd": "Quest_04_EscapeAnimalControl.complete",
	"TR_NeighborArea": "DIALOGUE_KindNeighbor_AfterPurr",
	"TR_OtherCatDialogue": "DIALOGUE_OtherCat",
	"TR_RoadStart": "Quest_07_CrossRoadToPark",
	"TR_RoadSafeIsland": "road_checkpoint",
	"TR_RoadEnd": "DIALOGUE_ChapterEnd",
}

var completed_or_started_events: Dictionary = {}
var quest_states: Dictionary = {}
var current_stage: String = ""

var _hint_manager: Node
var _dialogue_manager: Node
var _cat_vision_manager: Node
var _player: CharacterBody3D
var _chapter_root: Node
var _chase_active: bool = false
var _triggers: Dictionary = {}
var _markers: Dictionary = {}
var _road_checkpoint: Node3D = null
var _cat_vision_completed: bool = false
var _intro_played: bool = false
var _run_tutorial_completed: bool = false
var _jump_tutorial_completed: bool = false
var _chapter_finished: bool = false
var _last_story_trigger: String = ""

func _ready() -> void:
	_reset_chapter_state()
	for quest_id in QUEST_ORDER:
		quest_states[quest_id] = QuestState.INACTIVE
	_find_nodes()
	_configure_dialogues()
	_connect_helpers()
	_set_all_triggers_enabled(false)
	_set_road_cars_enabled(false)
	call_deferred("_start_intro")

func _reset_chapter_state() -> void:
	completed_or_started_events.clear()
	quest_states.clear()
	current_stage = ""
	_chase_active = false
	_road_checkpoint = null
	_cat_vision_completed = false
	_intro_played = false
	_run_tutorial_completed = false
	_jump_tutorial_completed = false
	_chapter_finished = false
	_last_story_trigger = ""
	if JournalManager.has_method("reset_chapter1_story"):
		JournalManager.call("reset_chapter1_story")

func _process(delta: float) -> void:
	if _chase_active:
		_update_chase(delta)

func _input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if is_quest_active("Quest_01_GoToCarTracks") and not _run_tutorial_completed and key_event.physical_keycode == KEY_SHIFT:
		_run_tutorial_completed = true
		complete_quest("Tutorial_01_Run")
		show_transient_hint("Бег помогает быстрее добираться до следа.", 2.5)
		print("[Chapter1Quest] tutorial=run result=completed")
	elif is_quest_active("Quest_04_EscapeAnimalControl") and not _jump_tutorial_completed and key_event.physical_keycode == KEY_SPACE:
		_jump_tutorial_completed = true
		complete_quest("Tutorial_03_Jump")
		show_transient_hint("Прыжок помогает преодолевать низкие препятствия.", 2.5)
		print("[Chapter1Quest] tutorial=jump result=completed")

func start_quest(quest_id: String) -> void:
	if quest_id == "":
		push_warning("Chapter1QuestManager.start_quest called with empty quest_id.")
		return
	if is_quest_active(quest_id) or get_quest_state(quest_id) == QuestState.COMPLETED:
		return

	completed_or_started_events[quest_id] = true
	_activate_stage(quest_id)
	match quest_id:
		"Cutscene_Intro":
			start_intro_cutscene()
		"Quest_01_GoToCarTracks":
			show_hint("Найди следы машины.")
		"Quest_02_CatVision", "Tutorial_02_CatVision", "Quest_02_InspectTracksWithCatVision":
			show_hint("Q (удерживать) — кошачье зрение.")
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

func show_transient_hint(text: String, duration: float = 3.0) -> void:
	if _hint_manager != null and _hint_manager.has_method("show_transient_hint"):
		_hint_manager.call("show_transient_hint", text, duration)

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
	_play_intro_cutscene()

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
	return int(quest_states.get(quest_id, QuestState.INACTIVE))

func is_quest_active(quest_id: String) -> bool:
	return get_quest_state(quest_id) == QuestState.ACTIVE

func complete_quest(quest_id: String) -> void:
	if quest_states.has(quest_id):
		quest_states[quest_id] = QuestState.COMPLETED
	completed_or_started_events[quest_id] = true
	if JournalManager.has_method("record_chapter1_quest"):
		JournalManager.call("record_chapter1_quest", quest_id, "completed")
	print("[QUEST] Completed: %s" % quest_id)

func _find_nodes() -> void:
	var current_scene := get_tree().current_scene
	_chapter_root = _get_chapter_root()
	_hint_manager = _find_child_in_chapter_or_scene("TutorialHintManager")
	_dialogue_manager = _find_child_in_chapter_or_scene("DialogueManager")
	_player = current_scene.find_child("PlayerCat", true, false) as CharacterBody3D if current_scene != null else null
	_cat_vision_manager = current_scene.find_child("CatVisionManager", true, false) if current_scene != null else null
	_collect_chapter_references(_chapter_root)

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

	for trigger in _triggers.values():
		if trigger == null or not trigger.has_signal("chapter_triggered"):
			continue
		if not trigger.is_connected("chapter_triggered", _on_chapter_triggered):
			trigger.connect("chapter_triggered", _on_chapter_triggered)
		if not trigger.is_connected("player_entered_trigger", _on_player_entered_trigger):
			trigger.connect("player_entered_trigger", _on_player_entered_trigger)
		if not trigger.is_connected("player_exited_trigger", _on_player_exited_trigger):
			trigger.connect("player_exited_trigger", _on_player_exited_trigger)
		var trigger_id := String(trigger.get("trigger_id"))
		if not TRIGGER_EVENT_NAMES.has(trigger_id):
			push_warning("[Chapter1Trigger] %s has no assigned story event." % trigger.name)

	if _cat_vision_manager != null and _cat_vision_manager.has_signal("cat_state_changed"):
		if not _cat_vision_manager.is_connected("cat_state_changed", _on_cat_state_changed):
			_cat_vision_manager.connect("cat_state_changed", _on_cat_state_changed)

func _collect_chapter_references(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		if child.name.begins_with("M_"):
			_markers[child.name] = child
		if child.has_signal("chapter_triggered"):
			_triggers[child.name] = child
		_collect_chapter_references(child)

func _set_trigger_enabled(trigger_name: String, is_enabled: bool) -> void:
	var trigger := _triggers.get(trigger_name) as Node
	if trigger != null and trigger.has_method("set_trigger_enabled"):
		trigger.call("set_trigger_enabled", is_enabled)

func _set_all_triggers_enabled(is_enabled: bool) -> void:
	for trigger in _triggers.values():
		if not is_enabled and trigger != null and trigger.has_method("reset_story_trigger"):
			trigger.call("reset_story_trigger")
		elif trigger != null and trigger.has_method("set_trigger_enabled"):
			trigger.call("set_trigger_enabled", is_enabled)

func _configure_dialogues() -> void:
	if _dialogue_manager == null or not _dialogue_manager.has_method("set_dialogues"):
		return

	_dialogue_manager.call("set_dialogues", {
		"DIALOGUE_CarTracks": [
			{"speaker_name": "", "text": "Знакомый запах… Хозяин был здесь."},
			{"speaker_name": "", "text": "Но что это рядом?.."},
		],
		"DIALOGUE_AnimalControl": [
			{"speaker_name": "Служба отлова", "text": "Опять вырвался! Куда он делся?"},
			{"speaker_name": "Служба отлова", "text": "Да брось, потом поймаем."},
			{"speaker_name": "Служба отлова", "text": "Эй! Вон ещё один!"},
			{"speaker_name": "Служба отлова", "text": "Лови его!"},
		],
		"DIALOGUE_KindNeighbor_BeforePurr": [
			{"speaker_name": "Соседка", "text": "Тебе сюда нельзя."},
			{"speaker_name": "Соседка", "text": "Иди домой, малыш."},
		],
		"DIALOGUE_KindNeighbor_AfterPurr": [
			{"speaker_name": "Соседка", "text": "Ах ты маленький…"},
			{"speaker_name": "Соседка", "text": "Ладно, проходи."},
			{"speaker_name": "Соседка", "text": "Только осторожно."},
		],
		"DIALOGUE_OtherCat": [
			{"speaker_name": "Дворовый кот", "text": "Эй, это ты отвлёк тех людей? Спасибо. Ещё немного — и меня бы поймали."},
			{"speaker_name": "Главный кот", "text": "Я просто убегал."},
			{"speaker_name": "Дворовый кот", "text": "Ну, иногда этого достаточно. А ты здесь раньше не появлялся. Что ищешь?"},
			{"speaker_name": "Главный кот", "text": "Своего человека. Я нашёл его след. Но рядом было что-то чужое."},
			{"speaker_name": "Дворовый кот", "text": "Чужое?.. Тогда слушай внимательно."},
			{"speaker_name": "Дворовый кот", "text": "Когда люди начинают пахнуть пустотой… за ними приходят Тихие."},
			{"speaker_name": "Главный кот", "text": "Тихие?"},
			{"speaker_name": "Дворовый кот", "text": "Те, кого люди не видят. Они всегда рядом, просто обычно не подходят так близко."},
			{"speaker_name": "Главный кот", "text": "Они забрали моего человека?"},
			{"speaker_name": "Дворовый кот", "text": "Не знаю. Но я видел, куда тянется эта темнота. Туда — к дороге."},
			{"speaker_name": "Дворовый кот", "text": "Смотри внимательно. Не только под лапы. И не позволяй им тебя заметить."},
		],
		"DIALOGUE_ChapterEnd": [
			{"speaker_name": "", "text": "Он прошёл здесь…"},
			{"speaker_name": "", "text": "Нужно найти его."},
		],
	})

func _start_intro() -> void:
	# VillageStartup validates the direct-scene launch on its deferred call.
	# Begin the playable cutscene on the following frame so the intentional
	# temporary control lock is never mistaken for a broken player controller.
	await get_tree().process_frame
	var intro_trigger := _triggers.get("TR_IntroCutscene") as Node
	if intro_trigger != null:
		intro_trigger.call("set_trigger_enabled", true)
		intro_trigger.call("_try_activate", "scene_start")
	else:
		push_warning("[Chapter1Quest] TR_IntroCutscene is missing; beginning Chapter 1 directly.")
		_play_intro_cutscene()

func _activate_stage(stage_id: String) -> void:
	current_stage = stage_id
	if quest_states.has(stage_id) and quest_states[stage_id] == QuestState.INACTIVE:
		quest_states[stage_id] = QuestState.ACTIVE
		if JournalManager.has_method("record_chapter1_quest"):
			JournalManager.call("record_chapter1_quest", stage_id, "active")
		print("[QUEST] Started: %s" % stage_id)
	print("[QUEST] Active: %s | last_trigger=%s" % [current_stage, _last_story_trigger])

func _play_intro_cutscene() -> void:
	if _intro_played:
		return
	_intro_played = true
	_activate_stage("Cutscene_Intro")
	_set_player_controls_locked(true)
	show_transient_hint("Визг тормозов. Удар.", 1.8)
	await get_tree().create_timer(1.9).timeout
	show_transient_hint("За окном мелькнул высокий чёрный силуэт.", 2.2)
	await get_tree().create_timer(2.3).timeout
	show_transient_hint("На вещах хозяина проступает знакомая синяя аура.", 2.3)
	if _cat_vision_manager != null and _cat_vision_manager.has_method("set_cat_vision_enabled"):
		_cat_vision_manager.call("set_cat_vision_enabled", true)
	await get_tree().create_timer(2.4).timeout
	if _cat_vision_manager != null and _cat_vision_manager.has_method("set_cat_vision_enabled"):
		_cat_vision_manager.call("set_cat_vision_enabled", false)
	show_transient_hint("В углу что-то маленькое прячется в тени.", 2.0)
	await get_tree().create_timer(2.1).timeout
	complete_quest("Cutscene_Intro")
	_set_player_controls_locked(false)
	_begin_car_tracks_quest()
	print("[Chapter1Quest] intro result=completed; quest_1_started")

func _set_player_controls_locked(is_locked: bool) -> void:
	if _player == null:
		return
	_player.set("controls_locked", is_locked)
	if is_locked:
		_player.set("moving", false)
		_player.set("mouse_down", false)

func _on_chapter_triggered(trigger_id: String, reason: String, _player_node: Node) -> void:
	_last_story_trigger = trigger_id
	var event_name := String(TRIGGER_EVENT_NAMES.get(trigger_id, ""))
	if event_name == "":
		push_warning("[Chapter1Trigger] %s activated, but no story event is assigned." % trigger_id)
		return

	print("[Chapter1Trigger] trigger=%s event=%s reason=%s" % [trigger_id, event_name, reason])
	print("[TRIGGER] Event: %s | source=%s" % [event_name, trigger_id])
	match trigger_id:
		"TR_IntroCutscene":
			_play_intro_cutscene()
		"TR_CarTracks":
			if is_quest_active("Quest_01_GoToCarTracks"):
				complete_quest("Quest_01_GoToCarTracks")
				_begin_cat_vision_tutorial()
				print("[Chapter1Trigger] trigger=%s result=quest_2_started" % trigger_id)
			else:
				_print_inactive_result(trigger_id, "Quest_01_GoToCarTracks")
		"TR_CarTracksCatVision":
			print("[TRIGGER] %s BLOCKED\nReason: inspect OBJ_CarTracks with Q + E instead." % trigger_id)
		"TR_AuraTrailProgress":
			if is_quest_active("Quest_03_FollowOwnerAura"):
				hide_hint()
				print("[Chapter1Trigger] trigger=%s result=hint_hidden" % trigger_id)
			else:
				_print_inactive_result(trigger_id, "Quest_03_FollowOwnerAura")
		"TR_AnimalControlScene":
			if is_quest_active("Quest_03_FollowOwnerAura"):
				complete_quest("Quest_03_FollowOwnerAura")
				start_dialogue("DIALOGUE_AnimalControl")
				print("[Chapter1Trigger] trigger=%s result=dialogue_started" % trigger_id)
			else:
				_print_inactive_result(trigger_id, "Quest_03_FollowOwnerAura")
		"TR_ChaseEnd":
			if is_quest_active("Quest_04_EscapeAnimalControl"):
				_complete_chase()
				print("[Chapter1Trigger] trigger=%s result=chase_completed" % trigger_id)
			else:
				_print_inactive_result(trigger_id, "Quest_04_EscapeAnimalControl")
		"TR_NeighborArea":
			if is_quest_active("Quest_045_PurrWithNeighbor") and reason == "purr":
				_complete_neighbor_purr()
				print("[Chapter1Trigger] trigger=%s result=neighbor_purr_completed" % trigger_id)
			else:
				_print_inactive_result(trigger_id, "Quest_045_PurrWithNeighbor")
		"TR_OtherCatDialogue":
			if is_quest_active("Quest_05_TalkToOtherCat"):
				complete_quest("Quest_05_TalkToOtherCat")
				_activate_stage("Dialogue_01_OtherCat")
				start_dialogue("DIALOGUE_OtherCat")
				print("[Chapter1Trigger] trigger=%s result=dialogue_started" % trigger_id)
			else:
				_print_inactive_result(trigger_id, "Quest_05_TalkToOtherCat")
		"TR_RoadStart":
			if is_quest_active("Quest_06_FollowTrailToRoad"):
				complete_quest("Quest_06_FollowTrailToRoad")
				_activate_stage("Quest_07_CrossRoadToPark")
				_road_checkpoint = _markers.get("M_RoadStart") as Node3D
				show_hint("Дождись зеленого света.")
				_set_road_cars_enabled(true)
				_set_trigger_enabled("TR_RoadSafeIsland", true)
				_set_trigger_enabled("TR_RoadEnd", true)
				print("[Chapter1Trigger] trigger=%s result=road_crossing_started" % trigger_id)
			else:
				_print_inactive_result(trigger_id, "Quest_06_FollowTrailToRoad")
		"TR_RoadSafeIsland":
			_road_checkpoint = _markers.get("M_RoadIsland") as Node3D
			show_hint("Спрячься на островке безопасности.", 3.0)
			print("[Chapter1Trigger] trigger=%s result=checkpoint_updated" % trigger_id)
		"TR_RoadEnd":
			if is_quest_active("Quest_07_CrossRoadToPark"):
				complete_quest("Quest_07_CrossRoadToPark")
				_activate_stage("Chapter_01_End")
				hide_hint()
				start_dialogue("DIALOGUE_ChapterEnd")
				print("[Chapter1Trigger] trigger=%s result=chapter_end_dialogue_started" % trigger_id)
			else:
				_print_inactive_result(trigger_id, "Quest_07_CrossRoadToPark")

func _print_inactive_result(trigger_id: String, required_stage: String) -> void:
	print("[TRIGGER] %s BLOCKED\nReason: active quest is %s; expected %s" % [trigger_id, current_stage, required_stage])

func _on_player_entered_trigger(trigger_id: String, _player_node: Node) -> void:
	var trigger := _triggers.get(trigger_id) as Node
	if trigger != null and String(trigger.get("context_hint")) != "":
		show_context_hint(String(trigger.get("context_hint")))

func _on_player_exited_trigger(_trigger_id: String, _player_node: Node) -> void:
	hide_context_hint()

func _on_dialogue_finished(dialogue_id: String) -> void:
	completed_or_started_events[dialogue_id] = true
	match dialogue_id:
		"DIALOGUE_CarTracks":
			_begin_aura_quest()
		"DIALOGUE_AnimalControl":
			_begin_chase()
		"DIALOGUE_KindNeighbor_AfterPurr":
			_begin_other_cat_quest()
		"DIALOGUE_OtherCat":
			complete_quest("Dialogue_01_OtherCat")
			_collect_chapter1_journal(["chapter1_the_quiet"])
			_begin_road_trail_quest()
		"DIALOGUE_ChapterEnd":
			complete_quest("Chapter_01_End")
			_finish_chapter_transition()

func _begin_car_tracks_quest() -> void:
	_activate_stage("Quest_01_GoToCarTracks")
	show_hint("Найти следы шин")
	show_transient_hint("Удерживай Shift, чтобы бежать", 4.0)
	_set_trigger_enabled("TR_CarTracks", true)

func _begin_cat_vision_tutorial() -> void:
	_activate_stage("Quest_02_InspectTracksWithCatVision")
	_activate_stage("Tutorial_02_CatVision")
	show_hint("Изучить следы шин с помощью кошачьего зрения")
	show_transient_hint("Удерживай Q, чтобы использовать кошачье зрение", 4.0)
	# The old blue zone is only a visual guide now.  Quest 2 is completed by
	# interacting with the actual OBJ_CarTracks object while Q is held.
	_set_trigger_enabled("TR_CarTracksCatVision", false)

func handle_quest_object_interaction(interaction_id: String, source: Node) -> bool:
	if interaction_id != "chapter1_car_tracks":
		print("[INTERACTION] %s BLOCKED\nReason: unknown Chapter 1 interaction." % interaction_id)
		return false
	if not is_quest_active("Quest_02_InspectTracksWithCatVision"):
		print("[INTERACTION] %s BLOCKED\nReason: Quest 2 is not active." % interaction_id)
		return false
	if _cat_vision_manager == null or int(_cat_vision_manager.call("get_cat_state")) != 1:
		show_context_hint("Удерживай Q, чтобы использовать кошачье зрение")
		print("[INTERACTION] %s BLOCKED\nReason: Cat Vision (Q) is not active." % interaction_id)
		return false

	print("[INTERACTION] %s: investigating %s" % [interaction_id, source.name])
	print("[CLUE] OwnerAura discovered")
	print("[CLUE] StrangeAura discovered")
	_collect_chapter1_journal(["chapter1_car_tracks", "chapter1_owner_aura", "chapter1_strange_aura"])
	print("[JOURNAL] Clues added")
	complete_quest("Quest_02_InspectTracksWithCatVision")
	complete_quest("Tutorial_02_CatVision")
	hide_context_hint()
	start_dialogue("DIALOGUE_CarTracks")
	return true

func _collect_chapter1_journal(entry_ids: Array[String]) -> void:
	var entries: Array[Dictionary] = []
	for entry_id in entry_ids:
		entries.append({"id": entry_id})
	if JournalManager.has_method("collect_entries"):
		JournalManager.call("collect_entries", entries)
	else:
		for entry in entries:
			JournalManager.collect_entry(entry)

func _begin_aura_quest() -> void:
	if _cat_vision_completed:
		return
	_cat_vision_completed = true
	hide_hint()
	_activate_stage("Quest_03_FollowOwnerAura")
	show_hint("Идти по следу хозяина")
	show_transient_hint("След хозяина продолжается дальше", 3.5)
	_set_trigger_enabled("TR_AuraTrailProgress", true)
	_set_trigger_enabled("TR_AnimalControlScene", true)

func _begin_chase() -> void:
	_activate_stage("Quest_04_EscapeAnimalControl")
	_activate_stage("Tutorial_03_Jump")
	show_hint("Убежать от службы отлова")
	show_transient_hint("Нажми Space, чтобы прыгнуть", 4.0)
	_chase_active = true
	if _cat_vision_manager != null and _cat_vision_manager.has_method("set_danger_active"):
		_cat_vision_manager.call("set_danger_active", true)
	_set_trigger_enabled("TR_ChaseEnd", true)
	var chase_start := _markers.get("M_ChaseStart") as Node3D
	if chase_start != null and _player != null and _player.has_method("set_recovery_point"):
		_player.call("set_recovery_point", chase_start.global_transform, false)

func _complete_chase() -> void:
	_chase_active = false
	if _cat_vision_manager != null and _cat_vision_manager.has_method("set_danger_active"):
		_cat_vision_manager.call("set_danger_active", false)
	complete_quest("Quest_04_EscapeAnimalControl")
	complete_quest("Tutorial_03_Jump")
	hide_hint()
	_activate_stage("Quest_045_PurrWithNeighbor")
	show_hint("Найти способ пройти дальше")
	show_transient_hint("Нажми R, чтобы мурчать", 4.0)
	_set_trigger_enabled("TR_NeighborArea", true)
	start_dialogue("DIALOGUE_KindNeighbor_BeforePurr")

func _complete_neighbor_purr() -> void:
	complete_quest("Quest_045_PurrWithNeighbor")
	hide_hint()
	if _player != null and _player.has_method("play_purr_effect"):
		_player.call("play_purr_effect")
	var neighbor := _chapter_root.find_child("NPC_KindNeighbor", true, false) if _chapter_root != null else null
	if neighbor != null and neighbor.has_method("change_attitude"):
		neighbor.call("change_attitude", 0)
	_open_neighbor_gate()
	start_dialogue("DIALOGUE_KindNeighbor_AfterPurr")

func _open_neighbor_gate() -> void:
	if _chapter_root == null:
		return
	var gate := _chapter_root.find_child("BLK_NeighborGate", true, false) as StaticBody3D
	if gate == null:
		push_warning("[Chapter1Quest] BLK_NeighborGate is missing; continuing without a gate change.")
		return
	var collision := gate.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", true)
	gate.visible = false
	print("[Chapter1Quest] neighbor_gate result=opened")

func _begin_other_cat_quest() -> void:
	_activate_stage("Quest_05_TalkToOtherCat")
	show_hint("Поговорить с другим котом")
	_set_trigger_enabled("TR_OtherCatDialogue", true)

func _begin_road_trail_quest() -> void:
	_activate_stage("Quest_06_FollowTrailToRoad")
	show_hint("Продолжить идти по следу хозяина")
	_set_trigger_enabled("TR_RoadStart", true)

func _on_cat_state_changed(state: int) -> void:
	if is_quest_active("Quest_03_FollowOwnerAura") and state != 1:
		show_transient_hint("Используй кошачье зрение, чтобы найти след", 3.0)
	elif is_quest_active("Quest_06_FollowTrailToRoad") and state != 1:
		show_transient_hint("След почти исчез. Попробуй кошачье зрение.", 3.0)

func _on_player_hit_car(player: Node) -> void:
	if not is_quest_active("Quest_07_CrossRoadToPark") or player == null:
		return
	show_transient_hint("Осторожно, машины! Вернись к безопасной стороне.", 3.0)
	var checkpoint := _road_checkpoint
	if checkpoint == null:
		checkpoint = _markers.get("M_RoadStart") as Node3D
	if checkpoint != null and player is Node3D:
		(player as Node3D).global_transform = checkpoint.global_transform
		player.set("target_position", checkpoint.global_position)
		player.set("moving", false)
		player.set("mouse_down", false)
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO

func _set_road_cars_enabled(is_enabled: bool) -> void:
	for car in get_tree().get_nodes_in_group("chapter1_moving_cars"):
		if car != null:
			car.set_physics_process(is_enabled)
			car.set_deferred("monitoring", is_enabled)

func _finish_chapter_transition() -> void:
	if _chapter_finished:
		return
	_chapter_finished = true
	stop_animal_control_chase()
	_set_road_cars_enabled(false)
	show_transient_hint("Глава 1 завершена. След ведёт в парк.", 3.0)
	print("[Chapter1Quest] chapter_1 result=completed")
	if ResourceLoader.exists("res://Scenes/Levels/Park.tscn"):
		await get_tree().create_timer(1.0).timeout
		await GameManager.change_level("park", "SpawnFromVillage")

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
