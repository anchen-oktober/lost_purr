extends Control

@export var next_scene_path: String = "res://Scenes/UI/MainMenu.tscn"
@export var minimum_duration: float = 2.2
@export var fade_duration: float = 0.45

@onready var content: Control = $Content

func _ready() -> void:
	content.modulate.a = 0.0

	var intro_tween: Tween = create_tween()
	intro_tween.tween_property(content, "modulate:a", 1.0, fade_duration)
	await intro_tween.finished

	await get_tree().create_timer(minimum_duration).timeout

	var outro_tween: Tween = create_tween()
	outro_tween.tween_property(content, "modulate:a", 0.0, fade_duration)
	await outro_tween.finished

	get_tree().change_scene_to_file(next_scene_path)
