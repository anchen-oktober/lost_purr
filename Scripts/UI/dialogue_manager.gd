extends CanvasLayer
class_name DialogueManager

signal dialogue_finished(dialogue_id: String)

var dialogues: Dictionary = {}
var active_dialogue_id: String = ""
var active_lines: Array = []
var active_index: int = 0
var is_open: bool = false
var _panel: PanelContainer
var _speaker_label: Label
var _text_label: Label

func _ready() -> void:
	layer = 40
	_build_ui()
	hide()

func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return

	var advance := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance = true
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		advance = true

	if advance:
		next_line()
		get_viewport().set_input_as_handled()

func set_dialogues(next_dialogues: Dictionary) -> void:
	dialogues = next_dialogues

func start_dialogue(dialogue_id: String) -> void:
	if not dialogues.has(dialogue_id):
		push_warning("Dialogue not found: %s" % dialogue_id)
		return

	active_dialogue_id = dialogue_id
	active_lines = dialogues[dialogue_id]
	active_index = 0
	is_open = true
	show()
	_show_current_line()

func next_line() -> void:
	if not is_open:
		return

	active_index += 1
	if active_index >= active_lines.size():
		finish_dialogue()
	else:
		_show_current_line()

func finish_dialogue() -> void:
	var finished_id := active_dialogue_id
	active_dialogue_id = ""
	active_lines = []
	active_index = 0
	is_open = false
	hide()
	dialogue_finished.emit(finished_id)

func _show_current_line() -> void:
	if active_index < 0 or active_index >= active_lines.size():
		finish_dialogue()
		return

	var line: Dictionary = active_lines[active_index]
	_speaker_label.text = str(line.get("speaker_name", ""))
	_text_label.text = str(line.get("text", ""))
	var callback: Callable = line.get("optional_callback", Callable())
	if callback.is_valid():
		callback.call()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "DialoguePanel"
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 96.0
	_panel.offset_right = -96.0
	_panel.offset_top = -178.0
	_panel.offset_bottom = -42.0
	add_child(_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.025, 0.02, 0.72)
	style.border_color = Color(0.88, 0.78, 0.55, 0.18)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	_panel.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.name = "DialogueContent"
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)

	_speaker_label = Label.new()
	_speaker_label.name = "Speaker"
	_speaker_label.add_theme_font_size_override("font_size", 16)
	_speaker_label.add_theme_color_override("font_color", Color(0.96, 0.82, 0.52, 0.96))
	box.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.name = "Text"
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 19)
	_text_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.82, 0.96))
	box.add_child(_text_label)
