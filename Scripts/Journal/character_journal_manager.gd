extends Node

signal characters_changed

const SAVE_PATH: String = "user://character_journal.json"

enum CharacterAttitude {
	FRIENDLY,
	NEUTRAL,
	HOSTILE
}

enum CharacterType {
	HUMAN,
	CAT,
	DOG,
	BIRD,
	RAT,
	DEMON
}

const TYPE_NAMES: Dictionary = {
	CharacterType.HUMAN: "Human",
	CharacterType.CAT: "Cat",
	CharacterType.DOG: "Dog",
	CharacterType.BIRD: "Bird",
	CharacterType.RAT: "Rat",
	CharacterType.DEMON: "Shadow",
}

const ATTITUDE_NAMES: Dictionary = {
	CharacterAttitude.FRIENDLY: "Friendly",
	CharacterAttitude.NEUTRAL: "Neutral",
	CharacterAttitude.HOSTILE: "Hostile",
}

var known_characters: Dictionary = {}
var nearby_npc: Node = null
var journal_ui: Node = null

func _ready() -> void:
	load_progress()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	if event.physical_keycode == KEY_E and nearby_npc != null:
		nearby_npc.interact()
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_R:
		_try_purr()
		get_viewport().set_input_as_handled()

func set_journal_ui(ui: Node) -> void:
	journal_ui = ui

func set_nearby_npc(npc: Node) -> void:
	nearby_npc = npc
	register_character(npc.get_character_data())
	if journal_ui != null:
		if npc is Node3D and journal_ui.has_method("show_prompt_for_node"):
			journal_ui.show_prompt_for_node("[E] Interact", npc)
		else:
			journal_ui.show_prompt("[E] Interact")

func clear_nearby_npc(npc: Node) -> void:
	if nearby_npc != npc:
		return

	nearby_npc = null
	if journal_ui != null:
		journal_ui.hide_prompt()

func register_character(character_data: Dictionary) -> void:
	var character_id: String = str(character_data.get("id", ""))
	if character_id.is_empty():
		return

	var normalized_data: Dictionary = character_data.duplicate(true)
	normalized_data["is_known"] = true
	known_characters[character_id] = normalized_data
	save_progress()
	characters_changed.emit()

func update_character_attitude(character_id: String, attitude: int) -> void:
	if not known_characters.has(character_id):
		return

	var character_data: Dictionary = known_characters[character_id] as Dictionary
	character_data["attitude"] = attitude
	character_data["is_friendly"] = attitude == CharacterAttitude.FRIENDLY
	known_characters[character_id] = character_data
	save_progress()
	characters_changed.emit()

func get_known_characters() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for character in known_characters.values():
		if character is Dictionary:
			result.append(character as Dictionary)
	return result

func get_character(character_id: String) -> Dictionary:
	if known_characters.has(character_id) and known_characters[character_id] is Dictionary:
		return known_characters[character_id] as Dictionary
	return {}

func get_type_name(character_type: int) -> String:
	return str(TYPE_NAMES.get(character_type, "Unknown"))

func get_attitude_name(attitude: int) -> String:
	return str(ATTITUDE_NAMES.get(attitude, "Neutral"))

func save_progress() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return

	file.store_string(JSON.stringify(known_characters))

func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		known_characters = parsed as Dictionary

func _try_purr() -> void:
	if journal_ui != null:
		journal_ui.show_purr_feedback("Prrrr...")

	var player: Node = get_tree().current_scene.find_child("PlayerCat", true, false)
	if player != null and player.has_method("play_purr_effect"):
		player.call("play_purr_effect")

	if nearby_npc != null:
		nearby_npc.receive_purr()
