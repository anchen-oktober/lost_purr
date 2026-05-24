extends Node

signal entries_changed

const SAVE_PATH: String = "user://memory_journal.json"

enum MemoryType {
	SMELL,
	TRACE,
	OBJECT,
	SYMBOL,
	PLACE,
	ANOMALY
}

const CATEGORY_NAMES: Dictionary = {
	MemoryType.SMELL: "Smells",
	MemoryType.TRACE: "Traces",
	MemoryType.OBJECT: "Objects",
	MemoryType.SYMBOL: "Symbols",
	MemoryType.PLACE: "Places",
	MemoryType.ANOMALY: "Anomalies",
}

const MEMORY_DEFINITIONS: Dictionary = {
	"old_tobacco_smell": {
		"title": "Old Tobacco Scent",
		"short_description": "A dry evening smell by an empty porch.",
		"full_description": "Old tobacco lingers near the porch. The human often sat here in the evenings. The scent has almost faded, but the cat still knows this place.",
		"category": MemoryType.SMELL,
	},
	"scratched_fence_trace": {
		"title": "Scratches on the Boards",
		"short_description": "Thin scratches run along the fence.",
		"full_description": "Fresh scratches remain on the old boards. They are too low for a human and too even to be accidental.",
		"category": MemoryType.TRACE,
	},
	"lost_key_object": {
		"title": "Rusty Key",
		"short_description": "A small key smells of rain and iron.",
		"full_description": "The rusty key lies in the dust, as if someone dropped it in a hurry. It opens nothing here, but the memory of a door becomes clearer.",
		"category": MemoryType.OBJECT,
	},
	"chalk_symbol": {
		"title": "Chalk Mark",
		"short_description": "A mark on the ground feels familiar only in the dark.",
		"full_description": "The chalk mark has nearly worn away. Its lines resemble a map of the district, but one alley is drawn where no alley ever was.",
		"category": MemoryType.SYMBOL,
	},
	"quiet_bench_place": {
		"title": "Empty Bench",
		"short_description": "Someone waited here for a long time.",
		"full_description": "The bench stands a little apart from the streetlamp. The wood still holds the warmth of unfamiliar hands, though the night has long gone cold.",
		"category": MemoryType.PLACE,
	},
	"cold_window_anomaly": {
		"title": "Cold Window",
		"short_description": "The window reflects a street that is not here.",
		"full_description": "The glass is colder than the air. In the reflection, another courtyard appears: dark, empty, and far too quiet.",
		"category": MemoryType.ANOMALY,
	},
	"raincoat_smell": {
		"title": "Wet Coat Scent",
		"short_description": "A heavy rain smell remains on the stone.",
		"full_description": "The smell of a wet coat clings to the edge of the path. Someone stood here for a long time, afraid to step into the lamplight.",
		"category": MemoryType.SMELL,
	},
	"spilled_milk_smell": {
		"title": "Sour Milk Scent",
		"short_description": "The porch smells of spilled milk.",
		"full_description": "A sour milk scent hides near the steps. The bowl has been empty for a long time, but the cat remembers when it was filled every evening.",
		"category": MemoryType.SMELL,
	},
	"tiny_paw_trace": {
		"title": "Tiny Pawprints",
		"short_description": "A chain of small prints slips between the houses.",
		"full_description": "Tiny prints cross the road and stop suddenly, as if whoever left them paused and looked up.",
		"category": MemoryType.TRACE,
	},
	"ash_footprint_trace": {
		"title": "Ashen Pawprint",
		"short_description": "A print on the ground looks like the shadow of a paw.",
		"full_description": "The ashen pawprint does not fade in the wind. It is colder than the ground around it and almost visible only from the corner of the eye.",
		"category": MemoryType.TRACE,
	},
	"cracked_cup_object": {
		"title": "Cracked Cup",
		"short_description": "A small cup sits by the wall.",
		"full_description": "The cracked cup has been placed carefully by the wall. There is no water inside, but a thin dark ring stains the bottom like old tea.",
		"category": MemoryType.OBJECT,
	},
	"bent_lantern_object": {
		"title": "Bent Lantern",
		"short_description": "The lantern shines lower than it should.",
		"full_description": "The bent lantern leans toward the road. Its light is warm, but tired, as if it has been trying to point at something for a long time.",
		"category": MemoryType.OBJECT,
	},
	"red_thread_object": {
		"title": "Red Thread",
		"short_description": "A thin thread is caught on a board.",
		"full_description": "The red thread is caught on an old board. It is too clean for this street and trails toward an empty yard.",
		"category": MemoryType.OBJECT,
	},
	"door_scratch_symbol": {
		"title": "Mark on the Door",
		"short_description": "An uneven sign is scratched into the door.",
		"full_description": "The mark on the door looks like a letter someone forgot to finish. The wood around the scratches has darkened as if after rain.",
		"category": MemoryType.SYMBOL,
	},
	"crooked_moon_symbol": {
		"title": "Crooked Moon",
		"short_description": "A thin arc is drawn on the stone.",
		"full_description": "The crooked moon is barely visible. If the cat looks too long, the arc seems to change shape.",
		"category": MemoryType.SYMBOL,
	},
	"warm_window_place": {
		"title": "Warm Window",
		"short_description": "The only window still holding light.",
		"full_description": "The warm window watches the empty street. Nothing moves behind it, but the cat feels a familiar calm.",
		"category": MemoryType.PLACE,
	},
	"narrow_alley_place": {
		"title": "Narrow Passage",
		"short_description": "A place where the city grows too quiet.",
		"full_description": "The narrow passage between houses swallows footsteps. Even the streetlamp shines more carefully here than on the road.",
		"category": MemoryType.PLACE,
	},
	"whispering_stone_anomaly": {
		"title": "Whispering Stone",
		"short_description": "The stone vibrates softly near the ground.",
		"full_description": "The whispering stone seems ordinary until the cat comes close. Something inside it sounds like a very distant staircase.",
		"category": MemoryType.ANOMALY,
	},
	"hidden_bell_anomaly": {
		"title": "Silent Bell",
		"short_description": "It appears only through Cat Vision.",
		"full_description": "A small bell hangs in the air with no string. It does not ring, but cold circles of silence spread from it.",
		"category": MemoryType.ANOMALY,
	},
	"blue_thread_trace": {
		"title": "Blue Thread",
		"short_description": "A trace visible only through a special gaze.",
		"full_description": "The blue thread stretches above the ground without touching the dust. It trembles when the cat looks at it for too long.",
		"category": MemoryType.TRACE,
	},
	"mirror_shard_object": {
		"title": "Mirror Shard",
		"short_description": "In ordinary light, it almost does not exist.",
		"full_description": "The mirror shard reflects not the houses, but an empty street after rain. For one moment, a hand appears in the reflection.",
		"category": MemoryType.OBJECT,
	},
	"cold_fishbone_symbol": {
		"title": "Fishbone Sign",
		"short_description": "A thin mark emerges on the road.",
		"full_description": "The fishbone is drawn in lines of cold light. It is not food and not a trail, more like a warning left for the cat.",
		"category": MemoryType.SYMBOL,
	},
	"empty_bowl_smell": {
		"title": "Empty Bowl Scent",
		"short_description": "An almost invisible smell of old care.",
		"full_description": "The smell of an empty bowl appears only through Cat Vision. It is warm and sad, like a place where someone waited for a long time.",
		"category": MemoryType.SMELL,
	},
	"memory_footprints_path": {
		"title": "Trail of Pawprints",
		"short_description": "The prints lead toward a quiet part of the street.",
		"full_description": "The trail appears only through Cat Vision. The prints move along the road with strange certainty, as if left by someone who knew exactly where to go.",
		"category": MemoryType.TRACE,
		"requires_cat_vision": true,
	},
}
var collected_entries: Dictionary = {}
var nearby_object: Node = null
var journal_ui: Node = null
var current_popup_requires_cat_vision: bool = false

func _ready() -> void:
	load_progress()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if event.physical_keycode == KEY_SHIFT and not event.pressed:
			_close_cat_vision_prompt()
			get_viewport().set_input_as_handled()
			return

		if not event.pressed:
			return

		if event.physical_keycode == KEY_E:
			if journal_ui != null and journal_ui.is_memory_popup_open():
				_close_memory_popup()
				get_viewport().set_input_as_handled()
			elif nearby_object != null and (journal_ui == null or not journal_ui.is_journal_open()):
				nearby_object.interact()
				get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_J:
			_toggle_journal()
			get_viewport().set_input_as_handled()

func set_journal_ui(ui: Node) -> void:
	journal_ui = ui

func set_nearby_object(object: Node) -> void:
	nearby_object = object
	if journal_ui != null and object != null:
		if object is Node3D and journal_ui.has_method("show_prompt_for_node"):
			journal_ui.show_prompt_for_node("[E] Inspect", object)
		else:
			journal_ui.show_prompt("[E] Inspect")

func clear_nearby_object(object: Node) -> void:
	if nearby_object != object:
		return

	nearby_object = null
	if journal_ui != null:
		journal_ui.hide_prompt()

func collect_entry(entry: Dictionary) -> void:
	var entry_id: String = str(entry.get("id", ""))
	if entry_id.is_empty():
		return

	var normalized_entry: Dictionary = _normalize_entry(entry)
	var was_new: bool = not collected_entries.has(entry_id)
	normalized_entry["is_collected"] = true
	collected_entries[entry_id] = normalized_entry

	if was_new:
		save_progress()
		entries_changed.emit()

	if journal_ui != null:
		current_popup_requires_cat_vision = bool(normalized_entry.get("requires_cat_vision", false))
		journal_ui.show_memory_popup(normalized_entry)

func get_entries_for_category(category: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry in collected_entries.values():
		if entry is Dictionary:
			var entry_dictionary: Dictionary = _normalize_entry(entry as Dictionary)
			if int(entry_dictionary.get("category", -1)) == category:
				result.append(entry_dictionary)
	return result

func is_collected(entry_id: String) -> bool:
	return collected_entries.has(entry_id)

func is_scene_input_blocked() -> bool:
	return journal_ui != null and (journal_ui.is_journal_open() or journal_ui.is_memory_popup_open())

func save_progress() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return

	file.store_string(JSON.stringify(collected_entries))

func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		collected_entries = parsed as Dictionary

func get_category_name(category: int) -> String:
	return str(CATEGORY_NAMES.get(category, "Entry"))

func _normalize_entry(entry: Dictionary) -> Dictionary:
	var normalized_entry: Dictionary = entry.duplicate(true)
	var entry_id: String = str(normalized_entry.get("id", ""))
	if MEMORY_DEFINITIONS.has(entry_id):
		var definition: Dictionary = MEMORY_DEFINITIONS[entry_id] as Dictionary
		for key in definition.keys():
			normalized_entry[key] = definition[key]
	return normalized_entry

func _toggle_journal() -> void:
	if journal_ui == null:
		return

	if journal_ui.is_journal_open():
		journal_ui.close_journal()
	else:
		current_popup_requires_cat_vision = false
		journal_ui.open_journal()

func _close_memory_popup() -> void:
	if journal_ui == null:
		return

	current_popup_requires_cat_vision = false
	journal_ui.close_memory_popup()

func _close_cat_vision_prompt() -> void:
	if nearby_object != null and nearby_object.is_in_group("cat_vision_revealed"):
		if nearby_object.has_method("force_hide_cat_vision_prompt"):
			nearby_object.call("force_hide_cat_vision_prompt")
		else:
			clear_nearby_object(nearby_object)

	if journal_ui != null and journal_ui.is_memory_popup_open() and current_popup_requires_cat_vision:
		_close_memory_popup()
