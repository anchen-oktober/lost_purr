extends CanvasLayer

const NORMAL_STATE: int = 0
const CAT_VISION_STATE: int = 1
const CRITICAL_STATE: int = 2

@export var normal_eye: Texture2D
@export var cat_vision_eye: Texture2D
@export var panic_eye: Texture2D
@export var danger_eye: Texture2D
@export var debug_text_visible: bool = true

@onready var cat_eyes_indicator: TextureRect = $CatEyesIndicator
@onready var fear_debug_label: Label = $FearDebugLabel

var cat_vision_manager: Node
var player_cat: Node
var fade_tween: Tween
var current_cat_state: int = NORMAL_STATE
var current_fear: float = 0.0
var current_calmness: float = 100.0
var current_fear_state: String = "Calm"
var is_fear_critical: bool = false
var is_trauma_avoidance_active: bool = false
var blocked_zone_name: String = "none"
var is_blocked_zone_radius_visible: bool = false
var shake_time: float = 0.0
var eye_base_position: Vector2

func _ready() -> void:
	eye_base_position = cat_eyes_indicator.position
	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		cat_vision_manager = current_scene.find_child("CatVisionManager", true, false)
		player_cat = current_scene.find_child("PlayerCat", true, false)

	if cat_vision_manager != null:
		cat_vision_manager.cat_state_changed.connect(_on_cat_state_changed)
		_on_cat_state_changed(int(cat_vision_manager.get_cat_state()))
	else:
		_on_cat_state_changed(NORMAL_STATE)

	if player_cat != null and player_cat.has_signal("fear_changed"):
		player_cat.connect("fear_changed", _on_fear_changed)
		if player_cat.has_signal("trauma_avoidance_changed"):
			player_cat.connect("trauma_avoidance_changed", _on_trauma_avoidance_changed)
		if player_cat.has_method("get_calmness") and player_cat.has_method("get_fear_state"):
			_on_fear_changed(
				float(player_cat.get("fear")),
				float(player_cat.call("get_calmness")),
				String(player_cat.call("get_fear_state")),
				bool(player_cat.get("is_critical_fear"))
			)
		if player_cat.has_method("get_blocked_zone_name") and player_cat.has_method("is_blocked_zone_radius_visible"):
			_on_trauma_avoidance_changed(
				bool(player_cat.get("has_active_trauma_avoidance")),
				String(player_cat.call("get_blocked_zone_name")),
				bool(player_cat.call("is_blocked_zone_radius_visible"))
			)
	else:
		_update_fear_debug_text()

func _process(delta: float) -> void:
	if _should_shake_eye():
		shake_time += delta
		var shake_power: float = 1.0 if current_calmness > 25.0 else 2.0
		cat_eyes_indicator.position = eye_base_position + Vector2(
			randf_range(-shake_power, shake_power),
			randf_range(-shake_power * 0.75, shake_power * 0.75)
		)
	else:
		shake_time = 0.0
		cat_eyes_indicator.position = eye_base_position

func _on_cat_state_changed(state: int) -> void:
	current_cat_state = state
	update_cat_eyes_indicator()

func _on_fear_changed(fear: float, calmness: float, state: String, is_critical: bool) -> void:
	current_fear = fear
	current_calmness = calmness
	current_fear_state = state
	is_fear_critical = is_critical
	_update_fear_debug_text()
	update_cat_eyes_indicator()

func _on_trauma_avoidance_changed(is_active: bool, zone_name: String, radius_visible: bool) -> void:
	is_trauma_avoidance_active = is_active
	blocked_zone_name = zone_name
	is_blocked_zone_radius_visible = radius_visible
	_update_fear_debug_text()

func update_cat_eyes_indicator() -> void:
	var next_texture: Texture2D = normal_eye
	var next_modulate: Color = _get_fear_eye_modulate()
	if current_cat_state == CRITICAL_STATE or is_fear_critical:
		next_texture = danger_eye
	elif current_cat_state == CAT_VISION_STATE:
		next_texture = cat_vision_eye
		next_modulate = Color(1.0, 1.0, 1.0, 0.88)
	elif current_calmness <= 25.0 and current_calmness > 0.0 and panic_eye != null:
		next_texture = panic_eye

	if cat_eyes_indicator.texture == next_texture and _colors_are_close(cat_eyes_indicator.modulate, next_modulate):
		return

	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()

	cat_eyes_indicator.texture = next_texture
	cat_eyes_indicator.modulate = Color(next_modulate.r, next_modulate.g, next_modulate.b, 0.35)
	fade_tween = create_tween()
	fade_tween.set_trans(Tween.TRANS_SINE)
	fade_tween.set_ease(Tween.EASE_OUT)
	fade_tween.tween_property(cat_eyes_indicator, "modulate", next_modulate, 0.2)

func _get_fear_eye_modulate() -> Color:
	if current_calmness > 75.0:
		return Color(1.0, 1.0, 1.0, 0.88)
	if current_calmness > 50.0:
		return Color(0.82, 0.75, 0.68, 0.82)
	if current_calmness > 25.0:
		return Color(0.62, 0.55, 0.5, 0.78)
	if current_calmness > 0.0:
		return Color(1.0, 0.55, 0.5, 0.9)
	return Color(1.0, 1.0, 1.0, 0.9)

func _colors_are_close(a: Color, b: Color) -> bool:
	return (
		is_equal_approx(a.r, b.r)
		and is_equal_approx(a.g, b.g)
		and is_equal_approx(a.b, b.b)
		and is_equal_approx(a.a, b.a)
	)

func _should_shake_eye() -> bool:
	return current_cat_state != CAT_VISION_STATE and current_calmness <= 50.0 and current_calmness > 0.0 and not is_fear_critical

func _update_fear_debug_text() -> void:
	if fear_debug_label == null:
		return

	fear_debug_label.visible = debug_text_visible
	fear_debug_label.text = "Fear: %d / 100\nCalmness: %d%%\nState: %s\nTrauma Avoidance: %s\nBlocked Zone: %s\nBlocked Zone Radius Visible: %s" % [
		roundi(current_fear),
		roundi(current_calmness),
		current_fear_state,
		"ON" if is_trauma_avoidance_active else "OFF",
		blocked_zone_name,
		str(is_blocked_zone_radius_visible),
	]
