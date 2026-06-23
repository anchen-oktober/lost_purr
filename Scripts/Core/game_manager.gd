extends Node

const PLAYER_NAME: String = "PlayerCat"
const QUICK_TRAVEL_SCENES: Dictionary = {
	KEY_1: {
		"scene": "res://Scenes/World/Village.tscn",
		"spawn": "SpawnFromVillage",
	},
	KEY_2: {
		"scene": "res://Scenes/Levels/Park.tscn",
		"spawn": "SpawnFromPark",
	},
	KEY_3: {
		"scene": "res://Scenes/World/City.tscn",
		"spawn": "SpawnFromCity",
	},
	KEY_4: {
		"scene": "res://Scenes/World/OtherWorld.tscn",
		"spawn": "SpawnFromMetro",
	},
	KEY_KP_1: {
		"scene": "res://Scenes/World/Village.tscn",
		"spawn": "SpawnFromVillage",
	},
	KEY_KP_2: {
		"scene": "res://Scenes/Levels/Park.tscn",
		"spawn": "SpawnFromPark",
	},
	KEY_KP_3: {
		"scene": "res://Scenes/World/City.tscn",
		"spawn": "SpawnFromCity",
	},
	KEY_KP_4: {
		"scene": "res://Scenes/World/OtherWorld.tscn",
		"spawn": "SpawnFromMetro",
	},
}

var pending_spawn_name: String = ""
var player_state: Dictionary = {}
var fade_layer: CanvasLayer
var fade_rect: ColorRect
var is_quick_traveling: bool = false

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

	var destination: Dictionary = QUICK_TRAVEL_SCENES.get(key_event.physical_keycode, {})
	if destination.is_empty():
		return

	get_viewport().set_input_as_handled()
	is_quick_traveling = true
	await change_scene(destination["scene"], destination["spawn"])
	is_quick_traveling = false

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
	_restore_player_at_spawn()
	await _fade_to(0.0, 0.45)

func register_current_scene_player() -> void:
	_restore_player_at_spawn()

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

	pending_spawn_name = ""

func _find_player() -> CharacterBody3D:
	if get_tree().current_scene == null:
		return null

	return get_tree().current_scene.find_child(PLAYER_NAME, true, false) as CharacterBody3D

func _find_spawn(spawn_name: String) -> Marker3D:
	if get_tree().current_scene == null:
		return null

	return get_tree().current_scene.find_child(spawn_name, true, false) as Marker3D

func _create_fade_overlay() -> void:
	fade_layer = CanvasLayer.new()
	fade_layer.name = "SceneFadeLayer"
	fade_layer.layer = 100
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
