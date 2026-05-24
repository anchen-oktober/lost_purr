extends Control

@export var game_scene_path: String = "res://MainScene.tscn"

@onready var new_game_button: Button = $Root/Menu/NewGameButton
@onready var load_button: Button = $Root/Menu/LoadButton
@onready var settings_button: Button = $Root/Menu/SettingsButton
@onready var exit_button: Button = $Root/Menu/ExitButton

func _ready() -> void:
	_apply_button_style(new_game_button, true)
	_apply_button_style(load_button, false)
	_apply_button_style(settings_button, false)
	_apply_button_style(exit_button, true)

	new_game_button.pressed.connect(_start_new_game)
	exit_button.pressed.connect(_exit_game)
	load_button.disabled = true
	settings_button.disabled = true

func _start_new_game() -> void:
	get_tree().change_scene_to_file(game_scene_path)

func _exit_game() -> void:
	get_tree().quit()

func _apply_button_style(button: Button, is_enabled: bool) -> void:
	button.add_theme_color_override("font_color", Color(0.96, 0.88, 0.68, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.72, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.78, 0.64, 0.42, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.42, 0.36, 0.28, 1.0))
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_stylebox_override("normal", _make_button_style(Color(0.08, 0.07, 0.05, 0.78), Color(0.36, 0.30, 0.20, 0.75)))
	button.add_theme_stylebox_override("hover", _make_button_style(Color(0.16, 0.13, 0.09, 0.88), Color(0.64, 0.52, 0.32, 0.95)))
	button.add_theme_stylebox_override("pressed", _make_button_style(Color(0.05, 0.04, 0.03, 0.92), Color(0.86, 0.72, 0.42, 1.0)))
	button.add_theme_stylebox_override("disabled", _make_button_style(Color(0.05, 0.045, 0.035, 0.42), Color(0.18, 0.15, 0.11, 0.50)))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_enabled else Control.CURSOR_ARROW

func _make_button_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style
