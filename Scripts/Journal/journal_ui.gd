extends CanvasLayer

var ui_blocker: Control
var prompt_label: Label
var popup_panel: PanelContainer
var popup_title: Label
var popup_text: Label
var journal_panel: PanelContainer
var tabs_box: VBoxContainer
var entries_list: ItemList
var detail_title: Label
var detail_category: Label
var icon_preview: TextureRect
var detail_text: RichTextLabel
var current_category: int = JournalManager.MemoryType.SMELL
var showing_characters: bool = false
var purr_label: Label
var quit_button: Button
var world_text_label: Label
var world_text_target: Node3D
var world_text_tween: Tween
var purr_target: Node3D
var popup_world_position: Vector3
var popup_has_world_position: bool = false
var prompt_target: Node3D
var prompt_text: String = ""

const POPUP_SIZE: Vector2 = Vector2(560.0, 220.0)
const JOURNAL_SIZE: Vector2 = Vector2(1060.0, 620.0)

func _ready() -> void:
	JournalManager.set_journal_ui(self)
	CharacterJournalManager.set_journal_ui(self)
	JournalManager.entries_changed.connect(refresh_entries)
	CharacterJournalManager.characters_changed.connect(refresh_entries)
	_build_ui()
	hide_prompt()
	close_journal()
	popup_panel.visible = false
	_refresh_ui_blocker()

func _process(_delta: float) -> void:
	_update_purr_label_position()
	_update_popup_position()
	_update_prompt_position()
	_update_world_text_position()
	_update_journal_position()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E and popup_panel != null and popup_panel.visible:
			close_memory_popup()
			get_viewport().set_input_as_handled()

func _update_purr_label_position() -> void:
	if purr_label == null or not purr_label.visible:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	if purr_target == null:
		purr_target = get_tree().current_scene.find_child("PlayerCat", true, false) as Node3D
	if purr_target == null:
		return

	purr_label.position = camera.unproject_position(purr_target.global_position + Vector3(0.0, 1.45, 0.0)) - Vector2(42.0, 18.0)

func show_prompt(text: String) -> void:
	prompt_text = text
	if _should_hide_prompt():
		prompt_label.visible = false
		return

	prompt_label.text = text
	prompt_label.visible = true

func show_prompt_for_node(text: String, target: Node3D) -> void:
	prompt_target = target
	show_prompt(text)
	_update_prompt_position()

func hide_prompt() -> void:
	prompt_label.visible = false
	prompt_target = null
	prompt_text = ""

func show_memory_popup(entry: Dictionary) -> void:
	popup_title.text = str(entry.get("title", "\u0417\u0430\u043F\u0438\u0441\u044C"))
	popup_text.text = str(entry.get("full_description", ""))
	_set_popup_world_position(entry)
	popup_panel.visible = true
	prompt_label.visible = false
	_update_popup_position()
	_refresh_ui_blocker()
	refresh_entries()

func show_character_popup(character_data: Dictionary) -> void:
	popup_title.text = str(character_data.get("character_name", "\u041F\u0435\u0440\u0441\u043E\u043D\u0430\u0436"))
	popup_text.text = str(character_data.get("short_phrase", "")) + "\n\n" + str(character_data.get("dialogue", ""))
	_set_popup_world_position(character_data)
	popup_panel.visible = true
	prompt_label.visible = false
	_update_popup_position()
	_refresh_ui_blocker()
	refresh_entries()

func show_purr_feedback(text: String) -> void:
	purr_label.text = text
	purr_label.visible = true
	var tween: Tween = create_tween()
	purr_label.modulate = Color(0.9, 0.96, 1.0, 1.0)
	tween.tween_property(purr_label, "modulate:a", 0.0, 1.2)
	tween.tween_callback(func() -> void: purr_label.visible = false)

func show_world_text_for_node(text: String, target: Node3D) -> void:
	if world_text_tween != null:
		world_text_tween.kill()

	world_text_target = target
	world_text_label.text = text
	world_text_label.visible = true
	prompt_label.visible = false
	world_text_label.modulate = Color(0.95, 0.9, 0.76, 1.0)
	_update_world_text_position()
	world_text_tween = create_tween()
	world_text_tween.tween_interval(1.6)
	world_text_tween.tween_property(world_text_label, "modulate:a", 0.0, 0.5)
	world_text_tween.tween_callback(func() -> void:
		world_text_label.visible = false
		world_text_target = null
		_restore_prompt_if_possible()
	)

func open_journal() -> void:
	journal_panel.visible = true
	popup_panel.visible = false
	popup_has_world_position = false
	_update_journal_position()
	_refresh_ui_blocker()
	refresh_entries()

func close_journal() -> void:
	journal_panel.visible = false
	_refresh_ui_blocker()

func is_journal_open() -> bool:
	return journal_panel.visible

func close_memory_popup() -> void:
	popup_panel.visible = false
	popup_has_world_position = false
	_restore_prompt_if_possible()
	_refresh_ui_blocker()

func is_memory_popup_open() -> bool:
	return popup_panel.visible

func refresh_entries() -> void:
	if entries_list == null:
		return

	entries_list.clear()
	if showing_characters:
		_refresh_character_entries()
		return

	var entries: Array[Dictionary] = JournalManager.get_entries_for_category(current_category)
	for entry in entries:
		entries_list.add_item(str(entry.get("title", "\u0417\u0430\u043F\u0438\u0441\u044C")))

	if entries.is_empty():
		detail_title.text = "\u041F\u043E\u043A\u0430 \u043F\u0443\u0441\u0442\u043E"
		detail_category.text = JournalManager.get_category_name(current_category)
		icon_preview.texture = null
		detail_text.text = "\u0417\u0430\u043F\u0438\u0441\u0435\u0439 \u043F\u043E\u043A\u0430 \u043D\u0435\u0442."
	else:
		entries_list.select(0)
		_show_entry(entries[0])

func _build_ui() -> void:
	ui_blocker = Control.new()
	ui_blocker.name = "UIBlocker"
	ui_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_blocker.z_index = -100
	ui_blocker.visible = false
	add_child(ui_blocker)

	prompt_label = Label.new()
	prompt_label.name = "PromptLabel"
	prompt_label.text = "[E] \u041E\u0441\u043C\u043E\u0442\u0440\u0435\u0442\u044C"
	prompt_label.position = Vector2(32, 620)
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_label.z_index = 20
	prompt_label.add_theme_font_size_override("font_size", 22)
	add_child(prompt_label)

	purr_label = Label.new()
	purr_label.name = "PurrLabel"
	purr_label.text = "\u041C\u0440\u0440\u0440..."
	purr_label.position = Vector2(548, 360)
	purr_label.visible = false
	purr_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	purr_label.z_index = 20
	purr_label.add_theme_font_size_override("font_size", 30)
	add_child(purr_label)

	world_text_label = Label.new()
	world_text_label.name = "WorldTextLabel"
	world_text_label.visible = false
	world_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_text_label.z_index = 25
	world_text_label.add_theme_font_size_override("font_size", 23)
	add_child(world_text_label)

	quit_button = Button.new()
	quit_button.name = "QuitButton"
	quit_button.text = "\u0412\u044B\u0439\u0442\u0438"
	quit_button.position = Vector2(24, 24)
	quit_button.custom_minimum_size = Vector2(110, 42)
	quit_button.z_index = 30
	quit_button.pressed.connect(_quit_game)
	add_child(quit_button)

	popup_panel = _make_panel("MemoryPopup", Vector2(390, 430), POPUP_SIZE)
	var popup_box: VBoxContainer = VBoxContainer.new()
	popup_box.add_theme_constant_override("separation", 12)
	popup_panel.add_child(popup_box)

	popup_title = Label.new()
	popup_title.add_theme_font_size_override("font_size", 24)
	popup_box.add_child(popup_title)

	popup_text = Label.new()
	popup_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	popup_text.custom_minimum_size = Vector2(0, 92)
	popup_text.add_theme_font_size_override("font_size", 17)
	popup_box.add_child(popup_text)

	var popup_hint: Label = Label.new()
	popup_hint.text = "J - \u043E\u0442\u043A\u0440\u044B\u0442\u044C \u0436\u0443\u0440\u043D\u0430\u043B"
	popup_hint.modulate = Color(0.45, 0.34, 0.24, 1.0)
	popup_box.add_child(popup_hint)

	journal_panel = _make_panel("JournalPanel", Vector2.ZERO, JOURNAL_SIZE)
	var journal_root: HBoxContainer = HBoxContainer.new()
	journal_root.add_theme_constant_override("separation", 18)
	journal_panel.add_child(journal_root)

	tabs_box = VBoxContainer.new()
	tabs_box.custom_minimum_size = Vector2(180, 0)
	tabs_box.add_theme_constant_override("separation", 8)
	journal_root.add_child(tabs_box)
	_build_tabs()

	entries_list = ItemList.new()
	entries_list.custom_minimum_size = Vector2(260, 0)
	entries_list.item_selected.connect(_on_entry_selected)
	journal_root.add_child(entries_list)

	var detail_box: VBoxContainer = VBoxContainer.new()
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_theme_constant_override("separation", 10)
	journal_root.add_child(detail_box)

	detail_category = Label.new()
	detail_category.modulate = Color(0.48, 0.34, 0.24, 1.0)
	detail_box.add_child(detail_category)

	detail_title = Label.new()
	detail_title.add_theme_font_size_override("font_size", 28)
	detail_box.add_child(detail_title)

	icon_preview = TextureRect.new()
	icon_preview.custom_minimum_size = Vector2(180, 120)
	icon_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_box.add_child(icon_preview)

	detail_text = RichTextLabel.new()
	detail_text.fit_content = true
	detail_text.bbcode_enabled = false
	detail_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_box.add_child(detail_text)

	var close_hint: Label = Label.new()
	close_hint.text = "J - \u0437\u0430\u043A\u0440\u044B\u0442\u044C"
	close_hint.modulate = Color(0.48, 0.34, 0.24, 1.0)
	detail_box.add_child(close_hint)

func _build_tabs() -> void:
	for category_value in JournalManager.CATEGORY_NAMES.keys():
		var category: int = int(category_value)
		var button: Button = Button.new()
		button.text = JournalManager.get_category_name(category)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select_category.bind(category))
		tabs_box.add_child(button)

	var characters_button: Button = Button.new()
	characters_button.text = "\u041F\u0435\u0440\u0441\u043E\u043D\u0430\u0436\u0438"
	characters_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	characters_button.pressed.connect(_select_characters)
	tabs_box.add_child(characters_button)

func _select_category(category: int) -> void:
	showing_characters = false
	current_category = category
	refresh_entries()

func _select_characters() -> void:
	showing_characters = true
	refresh_entries()

func _on_entry_selected(index: int) -> void:
	if showing_characters:
		var characters: Array[Dictionary] = CharacterJournalManager.get_known_characters()
		if index >= 0 and index < characters.size():
			_show_character(characters[index])
		return

	var entries: Array[Dictionary] = JournalManager.get_entries_for_category(current_category)
	if index >= 0 and index < entries.size():
		_show_entry(entries[index])

func _show_entry(entry: Dictionary) -> void:
	detail_title.text = str(entry.get("title", "\u0417\u0430\u043F\u0438\u0441\u044C"))
	detail_category.text = JournalManager.get_category_name(int(entry.get("category", current_category)))
	detail_text.text = str(entry.get("full_description", ""))

	var icon_path: String = str(entry.get("icon", ""))
	if icon_path.is_empty():
		icon_preview.texture = null
	else:
		icon_preview.texture = load(icon_path) as Texture2D

func _refresh_character_entries() -> void:
	var characters: Array[Dictionary] = CharacterJournalManager.get_known_characters()
	for character_data in characters:
		entries_list.add_item(str(character_data.get("character_name", "\u041F\u0435\u0440\u0441\u043E\u043D\u0430\u0436")))

	if characters.is_empty():
		detail_title.text = "\u041F\u043E\u043A\u0430 \u043F\u0443\u0441\u0442\u043E"
		detail_category.text = "\u041F\u0435\u0440\u0441\u043E\u043D\u0430\u0436\u0438"
		icon_preview.texture = null
		detail_text.text = "\u041A\u043E\u0442 \u043F\u043E\u043A\u0430 \u043D\u0438\u043A\u043E\u0433\u043E \u043D\u0435 \u0437\u0430\u043F\u043E\u043C\u043D\u0438\u043B."
	else:
		entries_list.select(0)
		_show_character(characters[0])

func _show_character(character_data: Dictionary) -> void:
	var character_type: int = int(character_data.get("character_type", CharacterJournalManager.CharacterType.HUMAN))
	var attitude: int = int(character_data.get("attitude", CharacterJournalManager.CharacterAttitude.NEUTRAL))
	detail_title.text = str(character_data.get("character_name", "\u041F\u0435\u0440\u0441\u043E\u043D\u0430\u0436"))
	detail_category.text = "\u0422\u0438\u043F: " + CharacterJournalManager.get_type_name(character_type) + "   \u041E\u0442\u043D\u043E\u0448\u0435\u043D\u0438\u0435: " + CharacterJournalManager.get_attitude_name(attitude)
	detail_text.text = str(character_data.get("description", "")) + "\n\n" + str(character_data.get("dialogue", ""))

	var portrait_path: String = str(character_data.get("portrait", ""))
	if portrait_path.is_empty():
		icon_preview.texture = null
	else:
		icon_preview.texture = load(portrait_path) as Texture2D

func _make_panel(name: String, panel_position: Vector2, panel_size: Vector2) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = name
	panel.position = panel_position
	panel.size = panel_size
	panel.custom_minimum_size = panel_size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.z_index = 10
	panel.modulate = Color(0.98, 0.87, 0.68, 0.94)
	add_child(panel)
	return panel

func _set_popup_world_position(data: Dictionary) -> void:
	popup_has_world_position = false
	if not data.has("world_position"):
		return

	var world_position_data: Variant = data.get("world_position")
	if not world_position_data is Dictionary:
		return

	var world_position_dictionary: Dictionary = world_position_data as Dictionary
	popup_world_position = Vector3(
		float(world_position_dictionary.get("x", 0.0)),
		float(world_position_dictionary.get("y", 0.0)),
		float(world_position_dictionary.get("z", 0.0))
	)
	popup_has_world_position = true

func _update_popup_position() -> void:
	if popup_panel == null or not popup_panel.visible or not popup_has_world_position:
		return

	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var popup_size: Vector2 = POPUP_SIZE
	popup_panel.size = POPUP_SIZE

	var screen_position: Vector2 = camera.unproject_position(popup_world_position + Vector3(0.0, 1.2, 0.0))
	var desired_position: Vector2 = screen_position - popup_size * 0.5
	var margin: float = 24.0
	desired_position.x = clampf(desired_position.x, margin, maxf(margin, viewport_size.x - popup_size.x - margin))
	desired_position.y = clampf(desired_position.y, margin, maxf(margin, viewport_size.y - popup_size.y - margin))
	popup_panel.position = desired_position

func _update_prompt_position() -> void:
	if prompt_label == null or not prompt_label.visible or prompt_target == null:
		return

	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var prompt_size: Vector2 = prompt_label.size
	if prompt_size.x <= 1.0 or prompt_size.y <= 1.0:
		prompt_size = prompt_label.get_minimum_size()

	var screen_position: Vector2 = camera.unproject_position(prompt_target.global_position + Vector3(0.0, 1.1, 0.0))
	var desired_position: Vector2 = screen_position - Vector2(prompt_size.x * 0.5, prompt_size.y + 12.0)
	var margin: float = 18.0
	desired_position.x = clampf(desired_position.x, margin, maxf(margin, viewport_size.x - prompt_size.x - margin))
	desired_position.y = clampf(desired_position.y, margin, maxf(margin, viewport_size.y - prompt_size.y - margin))
	prompt_label.position = desired_position

func _update_world_text_position() -> void:
	if world_text_label == null or not world_text_label.visible or world_text_target == null:
		return

	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var text_size: Vector2 = world_text_label.size
	if text_size.x <= 1.0 or text_size.y <= 1.0:
		text_size = world_text_label.get_minimum_size()

	var screen_position: Vector2 = camera.unproject_position(world_text_target.global_position + Vector3(0.0, 1.65, 0.0))
	var desired_position: Vector2 = screen_position - Vector2(text_size.x * 0.5, text_size.y + 10.0)
	var margin: float = 18.0
	desired_position.x = clampf(desired_position.x, margin, maxf(margin, viewport_size.x - text_size.x - margin))
	desired_position.y = clampf(desired_position.y, margin, maxf(margin, viewport_size.y - text_size.y - margin))
	world_text_label.position = desired_position

func _quit_game() -> void:
	get_tree().quit()

func _should_hide_prompt() -> bool:
	var popup_is_open: bool = popup_panel != null and popup_panel.visible
	var world_text_is_open: bool = world_text_label != null and world_text_label.visible
	return popup_is_open or world_text_is_open

func _restore_prompt_if_possible() -> void:
	if prompt_label == null or prompt_target == null or prompt_text.is_empty() or _should_hide_prompt():
		return

	prompt_label.text = prompt_text
	prompt_label.visible = true
	_update_prompt_position()

func _update_journal_position() -> void:
	if journal_panel == null or not journal_panel.visible:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	journal_panel.size = JOURNAL_SIZE
	journal_panel.position = (viewport_size - JOURNAL_SIZE) * 0.5

func _refresh_ui_blocker() -> void:
	if ui_blocker == null or popup_panel == null or journal_panel == null:
		return

	ui_blocker.visible = popup_panel.visible or journal_panel.visible
