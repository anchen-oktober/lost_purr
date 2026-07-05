extends CanvasLayer
class_name TutorialHintManager

var _hint_label: Label
var _context_label: Label
var _hint_timer: Timer
var _seen_hints: Dictionary = {}

func _ready() -> void:
	layer = 35
	_build_ui()

func show_hint(text: String, duration: float = 0.0) -> void:
	if text == "" or _seen_hints.has(text):
		return

	_seen_hints[text] = true
	_hint_label.text = text
	_hint_label.visible = true
	if duration > 0.0:
		_hint_timer.start(duration)
	else:
		_hint_timer.stop()

func hide_hint() -> void:
	_hint_timer.stop()
	_hint_label.visible = false

func show_context_hint(text: String) -> void:
	if text == "":
		return

	_context_label.text = text
	_context_label.visible = true

func hide_context_hint() -> void:
	_context_label.visible = false

func _build_ui() -> void:
	_hint_label = _make_label("HintLabel")
	_hint_label.offset_bottom = -58.0
	add_child(_hint_label)

	_context_label = _make_label("ContextHintLabel")
	_context_label.offset_bottom = -102.0
	add_child(_context_label)

	_hint_timer = Timer.new()
	_hint_timer.name = "HintTimer"
	_hint_timer.one_shot = true
	_hint_timer.timeout.connect(hide_hint)
	add_child(_hint_timer)

func _make_label(node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.visible = false
	label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	label.offset_left = 160.0
	label.offset_right = -160.0
	label.offset_top = -96.0
	label.offset_bottom = -58.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.88, 0.84, 0.75, 0.9))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label
