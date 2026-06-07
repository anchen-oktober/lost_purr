extends CanvasLayer

const NORMAL_STATE: int = 0

@export var normal_eye: Texture2D
@export var cat_vision_eye: Texture2D
@export var danger_eye: Texture2D

@onready var eye_texture: TextureRect = $EyeTexture

var cat_vision_manager: Node
var fade_tween: Tween

func _ready() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		cat_vision_manager = current_scene.find_child("CatVisionManager", true, false)

	if cat_vision_manager != null:
		cat_vision_manager.cat_state_changed.connect(_on_cat_state_changed)
		_on_cat_state_changed(int(cat_vision_manager.get_cat_state()))
	else:
		_on_cat_state_changed(NORMAL_STATE)

func _on_cat_state_changed(state: int) -> void:
	var next_texture: Texture2D = normal_eye
	if state == 1:
		next_texture = cat_vision_eye
	elif state == 2:
		next_texture = danger_eye

	if eye_texture.texture == next_texture:
		return

	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()

	eye_texture.modulate.a = 0.35
	eye_texture.texture = next_texture
	fade_tween = create_tween()
	fade_tween.set_trans(Tween.TRANS_SINE)
	fade_tween.set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(eye_texture, "modulate:a", 0.88, 0.2)
