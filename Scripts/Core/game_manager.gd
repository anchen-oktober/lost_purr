extends Node

const PLAYER_NAME: String = "PlayerCat"
const LEVELS: Dictionary = {
	"village": {
		"path": "res://Scenes/Levels/Village.scn",
		"spawn": "SpawnFromVillage",
	},
	"park": {
		"path": "res://Scenes/Levels/Park.tscn",
		"spawn": "SpawnFromPark",
	},
	"city": {
		"path": "res://Scenes/Levels/City.tscn",
		"spawn": "SpawnFromCity",
	},
	"metro": {
		"path": "res://Scenes/Levels/Metro.tscn",
		"spawn": "SpawnFromCity",
	},
	"other_world": {
		"path": "res://Scenes/Levels/OtherWorld.tscn",
		"spawn": "SpawnFromMetro",
	},
}
const QUICK_TRAVEL_LEVELS: Dictionary = {
	KEY_1: {"level": "village", "spawn": "SpawnFromVillage"},
	KEY_2: {"level": "park", "spawn": "SpawnFromPark"},
	KEY_3: {"level": "city", "spawn": "SpawnFromCity"},
	KEY_4: {"level": "metro", "spawn": "SpawnFromCity"},
	KEY_5: {"level": "other_world", "spawn": "SpawnFromMetro"},
	KEY_KP_1: {"level": "village", "spawn": "SpawnFromVillage"},
	KEY_KP_2: {"level": "park", "spawn": "SpawnFromPark"},
	KEY_KP_3: {"level": "city", "spawn": "SpawnFromCity"},
	KEY_KP_4: {"level": "metro", "spawn": "SpawnFromCity"},
	KEY_KP_5: {"level": "other_world", "spawn": "SpawnFromMetro"},
}

var pending_spawn_name: String = ""
var player_state: Dictionary = {}
var fade_layer: CanvasLayer
var fade_rect: ColorRect
var is_quick_traveling: bool = false
var current_level_id: String = ""
var current_spawn_name: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_fade_overlay()

func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey:
		return

	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if is_quick_traveling or JournalManager.is_scene_input_blocked():
		return

	var destination: Dictionary = QUICK_TRAVEL_LEVELS.get(key_event.physical_keycode, {})
	if destination.is_empty():
		return

	get_viewport().set_input_as_handled()
	is_quick_traveling = true
	await jump_to_level(destination["level"], destination["spawn"])
	is_quick_traveling = false

func jump_to_level(level_id: String, spawn_name: String = "") -> void:
	await change_level(level_id, spawn_name)

func reload_current_level() -> void:
	if current_level_id == "":
		push_warning("No current level to reload.")
		return

	await change_level(current_level_id, current_spawn_name)

func change_level(level_id: String, spawn_name: String = "") -> void:
	if not LEVELS.has(level_id):
		push_error("Unknown level id: %s" % level_id)
		return

	print("Loading level: ", level_id)
	var level_data: Dictionary = LEVELS[level_id]
	var path: String = level_data["path"]
	var resolved_spawn_name: String = spawn_name
	if resolved_spawn_name == "":
		resolved_spawn_name = level_data["spawn"]

	if not ResourceLoader.exists(path):
		push_error("Level scene not found: %s" % path)
		return

	var scene_container: Node = _find_scene_container()
	if scene_container == null:
		current_level_id = level_id
		current_spawn_name = resolved_spawn_name
		await change_scene(path, resolved_spawn_name)
		return

	pending_spawn_name = resolved_spawn_name
	_store_player_state()
	await _fade_to(1.0, 0.35)
	_set_bootstrap_loading_visible(true)

	for child in scene_container.get_children():
		child.queue_free()
	await get_tree().process_frame

	var packed_scene: PackedScene = await _load_packed_scene(path)
	if packed_scene == null:
		push_error("Failed to load level: %s" % path)
		_set_bootstrap_loading_visible(false)
		await _fade_to(0.0, 0.25)
		return

	var level_instance: Node = packed_scene.instantiate()
	scene_container.add_child(level_instance)
	current_level_id = level_id
	current_spawn_name = resolved_spawn_name

	await get_tree().process_frame
	await get_tree().process_frame
	_apply_location_to_cat_vision(level_id)
	_restore_player_at_spawn()
	_set_bootstrap_loading_visible(false)
	await _fade_to(0.0, 0.35)

func change_scene(scene_path: String, spawn_name: String) -> void:
	pending_spawn_name = spawn_name
	_store_player_state()
	await _fade_to(1.0, 0.45)

	var error: int = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_warning("Could not change scene to %s" % scene_path)
		await _fade_to(0.0, 0.25)
		return

	await get_tree().process_frame
	await get_tree().process_frame
	_apply_location_to_cat_vision(current_level_id)
	_restore_player_at_spawn()
	await _fade_to(0.0, 0.45)

func register_current_scene_player() -> void:
	_apply_location_to_cat_vision(current_level_id)
	_restore_player_at_spawn()

func _apply_location_to_cat_vision(level_id: String) -> void:
	if get_tree().current_scene == null:
		return

	var cat_vision_manager: Node = get_tree().current_scene.find_child("CatVisionManager", true, false)
	if cat_vision_manager == null or not cat_vision_manager.has_method("set_location"):
		return

	cat_vision_manager.call("set_location", _get_location_id(level_id))

func _get_location_id(level_id: String) -> String:
	match level_id:
		"other_world":
			return "OtherWorld"
		"village":
			return "Village"
		"park":
			return "Park"
		"city":
			return "City"
		"metro":
			return "Metro"
		_:
			return level_id

func _load_packed_scene(path: String) -> PackedScene:
	var request_error: int = ResourceLoader.load_threaded_request(path)
	if request_error != OK:
		return load(path) as PackedScene

	var progress: Array = []
	var status: int = ResourceLoader.load_threaded_get_status(path, progress)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(path, progress)

	if status != ResourceLoader.THREAD_LOAD_LOADED:
		return null

	return ResourceLoader.load_threaded_get(path) as PackedScene

func _store_player_state() -> void:
	var player: CharacterBody3D = _find_player()
	if player == null:
		return

	player_state["velocity"] = player.velocity

func _restore_player_at_spawn() -> void:
	var player: CharacterBody3D = _find_player()
	if player == null:
		return

	if pending_spawn_name != "":
		var spawn: Marker3D = _find_spawn(pending_spawn_name)
		if spawn != null:
			player.global_position = spawn.global_position
			player.set("target_position", spawn.global_position)
			player.set("moving", false)
			player.set("mouse_down", false)
			player.velocity = Vector3.ZERO

	if player.has_method("set_level_start_recovery_point"):
		player.call("set_level_start_recovery_point", player.global_transform)

	pending_spawn_name = ""

func _find_player() -> CharacterBody3D:
	if get_tree().current_scene == null:
		return null

	return get_tree().current_scene.find_child(PLAYER_NAME, true, false) as CharacterBody3D

func _find_spawn(spawn_name: String) -> Marker3D:
	if get_tree().current_scene == null:
		return null

	return get_tree().current_scene.find_child(spawn_name, true, false) as Marker3D

func _find_scene_container() -> Node:
	if get_tree().current_scene == null:
		return null

	var level_container: Node = get_tree().current_scene.get_node_or_null("LevelContainer")
	if level_container != null:
		return level_container

	return get_tree().current_scene.get_node_or_null("SceneContainer")

func _set_bootstrap_loading_visible(is_visible: bool) -> void:
	if get_tree().current_scene == null:
		return

	var loading_layer: CanvasLayer = get_tree().current_scene.get_node_or_null("LoadingLayer") as CanvasLayer
	if loading_layer != null:
		loading_layer.visible = is_visible

func _create_fade_overlay() -> void:
	fade_layer = CanvasLayer.new()
	fade_layer.name = "SceneFadeLayer"
	fade_layer.layer = 101
	fade_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(fade_layer)

	fade_rect = ColorRect.new()
	fade_rect.name = "Fade"
	fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(fade_rect)

func _fade_to(alpha: float, duration: float) -> void:
	if fade_rect == null:
		return

	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(fade_rect, "color", Color(0.0, 0.0, 0.0, alpha), duration)
	await tween.finished
