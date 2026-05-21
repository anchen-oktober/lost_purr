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
	MemoryType.SMELL: "\u0417\u0430\u043F\u0430\u0445\u0438",
	MemoryType.TRACE: "\u0421\u043B\u0435\u0434\u044B",
	MemoryType.OBJECT: "\u041F\u0440\u0435\u0434\u043C\u0435\u0442\u044B",
	MemoryType.SYMBOL: "\u0421\u0438\u043C\u0432\u043E\u043B\u044B",
	MemoryType.PLACE: "\u041C\u0435\u0441\u0442\u0430",
	MemoryType.ANOMALY: "\u0410\u043D\u043E\u043C\u0430\u043B\u0438\u0438",
}

const MEMORY_DEFINITIONS: Dictionary = {
	"old_tobacco_smell": {
		"title": "\u0421\u0442\u0430\u0440\u044B\u0439 \u0437\u0430\u043F\u0430\u0445 \u0442\u0430\u0431\u0430\u043A\u0430",
		"short_description": "\u0421\u0443\u0445\u043E\u0439 \u0432\u0435\u0447\u0435\u0440\u043D\u0438\u0439 \u0437\u0430\u043F\u0430\u0445 \u0443 \u043F\u0443\u0441\u0442\u043E\u0433\u043E \u043A\u0440\u044B\u043B\u044C\u0446\u0430.",
		"full_description": "\u0421\u0442\u0430\u0440\u044B\u0439 \u0437\u0430\u043F\u0430\u0445 \u0442\u0430\u0431\u0430\u043A\u0430. \u0425\u043E\u0437\u044F\u0438\u043D \u0447\u0430\u0441\u0442\u043E \u0441\u0438\u0434\u0435\u043B \u0437\u0434\u0435\u0441\u044C \u043F\u043E \u0432\u0435\u0447\u0435\u0440\u0430\u043C. \u0417\u0430\u043F\u0430\u0445 \u043F\u043E\u0447\u0442\u0438 \u0438\u0441\u0447\u0435\u0437.",
		"category": MemoryType.SMELL,
	},
	"scratched_fence_trace": {
		"title": "\u0421\u043B\u0435\u0434\u044B \u043D\u0430 \u0434\u043E\u0441\u043A\u0430\u0445",
		"short_description": "\u0422\u043E\u043D\u043A\u0438\u0435 \u0446\u0430\u0440\u0430\u043F\u0438\u043D\u044B \u0443\u0445\u043E\u0434\u044F\u0442 \u0432\u0434\u043E\u043B\u044C \u0437\u0430\u0431\u043E\u0440\u0430.",
		"full_description": "\u041D\u0430 \u0441\u0442\u0430\u0440\u044B\u0445 \u0434\u043E\u0441\u043A\u0430\u0445 \u043E\u0441\u0442\u0430\u043B\u0438\u0441\u044C \u0441\u0432\u0435\u0436\u0438\u0435 \u0446\u0430\u0440\u0430\u043F\u0438\u043D\u044B. \u041E\u043D\u0438 \u0441\u043B\u0438\u0448\u043A\u043E\u043C \u043D\u0438\u0437\u043A\u043E \u0434\u043B\u044F \u0447\u0435\u043B\u043E\u0432\u0435\u043A\u0430.",
		"category": MemoryType.TRACE,
	},
	"lost_key_object": {
		"title": "\u0420\u0436\u0430\u0432\u044B\u0439 \u043A\u043B\u044E\u0447",
		"short_description": "\u041C\u0430\u043B\u0435\u043D\u044C\u043A\u0438\u0439 \u043A\u043B\u044E\u0447 \u043F\u0430\u0445\u043D\u0435\u0442 \u0434\u043E\u0436\u0434\u0435\u043C \u0438 \u0436\u0435\u043B\u0435\u0437\u043E\u043C.",
		"full_description": "\u0420\u0436\u0430\u0432\u044B\u0439 \u043A\u043B\u044E\u0447 \u043B\u0435\u0436\u0438\u0442 \u0432 \u043F\u044B\u043B\u0438, \u0431\u0443\u0434\u0442\u043E \u0435\u0433\u043E \u0431\u0440\u043E\u0441\u0438\u043B\u0438 \u0432\u043F\u043E\u043F\u044B\u0445\u0430\u0445.",
		"category": MemoryType.OBJECT,
	},
	"chalk_symbol": {
		"title": "\u041C\u0435\u043B\u043E\u0432\u043E\u0439 \u0437\u043D\u0430\u043A",
		"short_description": "\u0421\u0438\u043C\u0432\u043E\u043B \u043D\u0430 \u0437\u0435\u043C\u043B\u0435 \u043A\u0430\u0436\u0435\u0442\u0441\u044F \u0437\u043D\u0430\u043A\u043E\u043C\u044B\u043C \u0442\u043E\u043B\u044C\u043A\u043E \u0432 \u0442\u0435\u043C\u043D\u043E\u0442\u0435.",
		"full_description": "\u041C\u0435\u043B\u043E\u0432\u043E\u0439 \u0437\u043D\u0430\u043A \u043F\u043E\u0447\u0442\u0438 \u0441\u0442\u0435\u0440\u0441\u044F. \u0415\u0433\u043E \u043B\u0438\u043D\u0438\u0438 \u043D\u0430\u043F\u043E\u043C\u0438\u043D\u0430\u044E\u0442 \u043A\u0430\u0440\u0442\u0443 \u0440\u0430\u0439\u043E\u043D\u0430.",
		"category": MemoryType.SYMBOL,
	},
	"quiet_bench_place": {
		"title": "\u041F\u0443\u0441\u0442\u0430\u044F \u043B\u0430\u0432\u043E\u0447\u043A\u0430",
		"short_description": "\u0417\u0434\u0435\u0441\u044C \u043A\u0442\u043E-\u0442\u043E \u0434\u043E\u043B\u0433\u043E \u0436\u0434\u0430\u043B.",
		"full_description": "\u041B\u0430\u0432\u043E\u0447\u043A\u0430 \u0441\u0442\u043E\u0438\u0442 \u0447\u0443\u0442\u044C \u0432 \u0441\u0442\u043E\u0440\u043E\u043D\u0435 \u043E\u0442 \u0444\u043E\u043D\u0430\u0440\u044F. \u0414\u0435\u0440\u0435\u0432\u043E \u0445\u0440\u0430\u043D\u0438\u0442 \u0442\u0435\u043F\u043B\u043E.",
		"category": MemoryType.PLACE,
	},
	"cold_window_anomaly": {
		"title": "\u0425\u043E\u043B\u043E\u0434\u043D\u043E\u0435 \u043E\u043A\u043D\u043E",
		"short_description": "\u041E\u043A\u043D\u043E \u043E\u0442\u0440\u0430\u0436\u0430\u0435\u0442 \u0443\u043B\u0438\u0446\u0443, \u043A\u043E\u0442\u043E\u0440\u043E\u0439 \u0437\u0434\u0435\u0441\u044C \u043D\u0435\u0442.",
		"full_description": "\u0421\u0442\u0435\u043A\u043B\u043E \u0445\u043E\u043B\u043E\u0434\u043D\u0435\u0435 \u0432\u043E\u0437\u0434\u0443\u0445\u0430. \u0412 \u043E\u0442\u0440\u0430\u0436\u0435\u043D\u0438\u0438 \u0432\u0438\u0434\u0435\u043D \u0434\u0440\u0443\u0433\u043E\u0439 \u0434\u0432\u043E\u0440.",
		"category": MemoryType.ANOMALY,
	},
	"raincoat_smell": {
		"title": "Запах мокрого плаща",
		"short_description": "На камне остался тяжелый запах дождя.",
		"full_description": "Запах мокрого плаща держится у края дорожки. Кто-то стоял здесь долго, не решаясь войти под свет фонаря.",
		"category": MemoryType.SMELL,
	},
	"spilled_milk_smell": {
		"title": "Кислый запах молока",
		"short_description": "У крыльца пахнет пролитым молоком.",
		"full_description": "Кислый запах молока прячется у ступенек. Миска давно пустая, но кот помнит, что раньше ее ставили каждый вечер.",
		"category": MemoryType.SMELL,
	},
	"tiny_paw_trace": {
		"title": "Маленькие следы",
		"short_description": "Цепочка мелких отпечатков уходит между домами.",
		"full_description": "Маленькие следы пересекают дорогу и внезапно обрываются. Будто тот, кто их оставил, остановился и посмотрел наверх.",
		"category": MemoryType.TRACE,
	},
	"ash_footprint_trace": {
		"title": "Пепельный отпечаток",
		"short_description": "На земле лежит след, похожий на тень лапы.",
		"full_description": "Пепельный отпечаток не стирается ветром. Он холоднее земли вокруг и почти заметен только боковым зрением.",
		"category": MemoryType.TRACE,
	},
	"cracked_cup_object": {
		"title": "Треснувшая чашка",
		"short_description": "Маленькая чашка стоит у стены.",
		"full_description": "Треснувшая чашка аккуратно поставлена у стены. Внутри нет воды, но на дне темнеет тонкое кольцо, как след от старого чая.",
		"category": MemoryType.OBJECT,
	},
	"bent_lantern_object": {
		"title": "Погнутый фонарь",
		"short_description": "Фонарь светит ниже, чем должен.",
		"full_description": "Погнутый фонарь наклонился к дороге. Его свет теплый, но в нем есть усталая дрожь, будто он давно пытается что-то показать.",
		"category": MemoryType.OBJECT,
	},
	"red_thread_object": {
		"title": "Красная нить",
		"short_description": "Тонкая нить зацепилась за доску.",
		"full_description": "Красная нить зацепилась за старую доску. Она слишком чистая для этой улицы и тянется в сторону пустого двора.",
		"category": MemoryType.OBJECT,
	},
	"door_scratch_symbol": {
		"title": "Знак на двери",
		"short_description": "На двери выцарапан неровный знак.",
		"full_description": "Знак на двери похож на букву, которую забыли дописать. Дерево вокруг царапин потемнело, как после дождя.",
		"category": MemoryType.SYMBOL,
	},
	"crooked_moon_symbol": {
		"title": "Кривая луна",
		"short_description": "На камне нарисована тонкая дуга.",
		"full_description": "Кривая луна нарисована почти незаметно. Если смотреть долго, кажется, что дуга чуть меняет форму.",
		"category": MemoryType.SYMBOL,
	},
	"warm_window_place": {
		"title": "Теплое окно",
		"short_description": "Единственное окно, которое еще хранит свет.",
		"full_description": "Теплое окно смотрит на пустую улицу. За ним ничего не движется, но кот чувствует знакомое спокойствие.",
		"category": MemoryType.PLACE,
	},
	"narrow_alley_place": {
		"title": "Узкий проход",
		"short_description": "Место, где город становится слишком тихим.",
		"full_description": "Узкий проход между домами глушит шаги. Здесь даже фонарь светит осторожнее, чем на дороге.",
		"category": MemoryType.PLACE,
	},
	"whispering_stone_anomaly": {
		"title": "Шепчущий камень",
		"short_description": "Камень тихо вибрирует у земли.",
		"full_description": "Шепчущий камень кажется обычным, пока кот не подходит ближе. Внутри него будто звучит очень далекая лестница.",
		"category": MemoryType.ANOMALY,
	},
	"hidden_bell_anomaly": {
		"title": "Колокольчик без звука",
		"short_description": "Он появляется только в кошачьем зрении.",
		"full_description": "Маленький колокольчик висит в воздухе без веревки. Он не звенит, но от него расходятся холодные круги тишины.",
		"category": MemoryType.ANOMALY,
	},
	"blue_thread_trace": {
		"title": "Синяя нить",
		"short_description": "След, который виден только особым взглядом.",
		"full_description": "Синяя нить тянется поверх земли, не касаясь пыли. Она дрожит, когда кот смотрит слишком долго.",
		"category": MemoryType.TRACE,
	},
	"mirror_shard_object": {
		"title": "Осколок зеркала",
		"short_description": "В обычном свете его будто не существует.",
		"full_description": "Осколок зеркала отражает не дома, а пустую улицу после дождя. В отражении на миг видна чья-то рука.",
		"category": MemoryType.OBJECT,
	},
	"cold_fishbone_symbol": {
		"title": "Рыбья кость",
		"short_description": "Тонкий знак проступает на дороге.",
		"full_description": "Рыбья кость нарисована линиями холодного света. Это не еда и не след, скорее предупреждение, оставленное для кота.",
		"category": MemoryType.SYMBOL,
	},
	"empty_bowl_smell": {
		"title": "Запах пустой миски",
		"short_description": "Почти невидимый запах старой заботы.",
		"full_description": "Запах пустой миски появляется только в кошачьем зрении. Он теплый и грустный, как место, где кого-то долго ждали.",
		"category": MemoryType.SMELL,
	},
	"memory_footprints_path": {
		"title": "\u0426\u0435\u043F\u043E\u0447\u043A\u0430 \u0441\u043B\u0435\u0434\u043E\u0432",
		"short_description": "\u0421\u043B\u0435\u0434\u044B \u0432\u0435\u0434\u0443\u0442 \u043A \u0442\u0438\u0445\u043E\u0439 \u0447\u0430\u0441\u0442\u0438 \u0443\u043B\u0438\u0446\u044B.",
		"full_description": "\u0426\u0435\u043F\u043E\u0447\u043A\u0430 \u0441\u043B\u0435\u0434\u043E\u0432 \u043F\u0440\u043E\u0441\u0442\u0443\u043F\u0430\u0435\u0442 \u0442\u043E\u043B\u044C\u043A\u043E \u0432 \u043A\u043E\u0448\u0430\u0447\u044C\u0435\u043C \u0437\u0440\u0435\u043D\u0438\u0438. \u041E\u043D\u0438 \u0438\u0434\u0443\u0442 \u043F\u043E \u0434\u043E\u0440\u043E\u0433\u0435 \u0443\u0432\u0435\u0440\u0435\u043D\u043D\u043E, \u0431\u0443\u0434\u0442\u043E \u0438\u0445 \u043E\u0441\u0442\u0430\u0432\u0438\u043B \u0442\u043E\u0442, \u043A\u0442\u043E \u0437\u043D\u0430\u043B, \u043A\u0443\u0434\u0430 \u0438\u0434\u0442\u0438.",
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
			journal_ui.show_prompt_for_node("[E] \u041E\u0441\u043C\u043E\u0442\u0440\u0435\u0442\u044C", object)
		else:
			journal_ui.show_prompt("[E] \u041E\u0441\u043C\u043E\u0442\u0440\u0435\u0442\u044C")

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
			var entry_dictionary: Dictionary = entry as Dictionary
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
	return str(CATEGORY_NAMES.get(category, "\u0417\u0430\u043F\u0438\u0441\u044C"))

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
