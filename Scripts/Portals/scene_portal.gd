extends Area3D

@export_file("*.tscn") var target_scene_path: String
@export var target_spawn_name: String = "SpawnFromVillage"
@export var prompt_text: String = "[E] Travel"

var player_inside: bool = false
var is_transitioning: bool = false
var prompt_layer: CanvasLayer
var prompt_label: Label

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_create_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if not player_inside or is_transitioning:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			_start_transition()
			get_viewport().set_input_as_handled()

func _on_body_entered(body: Node3D) -> void:
	if body.name != "PlayerCat":
		return

	player_inside = true
	_set_prompt_visible(true)

func _on_body_exited(body: Node3D) -> void:
	if body.name != "PlayerCat":
		return

	player_inside = false
	_set_prompt_visible(false)

func _start_transition() -> void:
	if target_scene_path == "":
		return

	is_transitioning = true
	_set_prompt_visible(false)
	await GameManager.change_scene(target_scene_path, target_spawn_name)
	is_transitioning = false

func _create_prompt() -> void:
	prompt_layer = CanvasLayer.new()
	prompt_layer.name = "PortalPromptLayer"
	prompt_layer.layer = 30
	add_child(prompt_layer)

	prompt_label = Label.new()
	prompt_label.name = "PortalPrompt"
	prompt_label.text = prompt_text
	prompt_label.visible = false
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 30)
	prompt_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.66, 1.0))
	prompt_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	prompt_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	prompt_label.offset_top = -120.0
	prompt_label.offset_bottom = -64.0
	prompt_layer.add_child(prompt_label)

func _set_prompt_visible(is_visible: bool) -> void:
	if prompt_label != null:
		prompt_label.visible = is_visible
