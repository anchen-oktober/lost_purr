extends Node

signal cat_state_changed(state: int)

const OTHER_WORLD_LOCATION_ID: String = "OtherWorld"

enum CatState {
	NORMAL,
	CAT_VISION,
	DANGER,
}

@export var world_environment: WorldEnvironment
@export var cat_vision_music: AudioStreamPlayer
@export var transition_speed: float = 6.0
@export var revealed_group: String = "cat_vision_revealed"

@export var normal_background_color: Color = Color(0.36, 0.26, 0.18, 1.0)
@export var vision_background_color: Color = Color(0.055, 0.095, 0.1, 1.0)
@export var danger_background_color: Color = Color(0.16, 0.065, 0.055, 1.0)
@export var normal_ambient_color: Color = Color(0.98, 0.76, 0.48, 1.0)
@export var vision_ambient_color: Color = Color(0.2, 0.36, 0.33, 1.0)
@export var danger_ambient_color: Color = Color(0.58, 0.22, 0.18, 1.0)
@export var normal_ambient_energy: float = 1.35
@export var vision_ambient_energy: float = 0.65
@export var danger_ambient_energy: float = 0.72
@export var normal_fog_density: float = 0.0
@export var vision_fog_density: float = 0.018
@export var danger_fog_density: float = 0.012
@export var normal_volumetric_fog_density: float = 0.0
@export var vision_volumetric_fog_density: float = 0.02
@export var danger_volumetric_fog_density: float = 0.012
@export var normal_saturation: float = 1.0
@export var vision_saturation: float = 0.75
@export var danger_saturation: float = 0.82
@export var normal_brightness: float = 1.0
@export var vision_brightness: float = 0.9
@export var danger_brightness: float = 0.88
@export var normal_glow_intensity: float = 0.0
@export var vision_glow_intensity: float = 0.18
@export var danger_glow_intensity: float = 0.12
@export var cat_vision_music_min_volume_db: float = -80.0
@export var cat_vision_music_max_volume_db: float = -12.0

var vision_amount: float = 0.0
var danger_amount: float = 0.0
var is_cat_vision_enabled: bool = false
var is_cat_vision_forced: bool = false
var is_cat_critical: bool = false
var current_location_id: String = ""
var current_state: CatState = CatState.NORMAL
var _cat_vision_enabled_before_forced: bool = false

func _ready() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		if world_environment == null:
			world_environment = current_scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
		if cat_vision_music == null:
			cat_vision_music = current_scene.find_child("CatVisionMusic", true, false) as AudioStreamPlayer
	if cat_vision_music != null:
		cat_vision_music.volume_db = cat_vision_music_min_volume_db
		if not cat_vision_music.playing:
			cat_vision_music.play()

	_set_revealed_objects_visible(false)
	_apply_environment(0.0, 0.0)
	set_location(_detect_current_location_id())
	cat_state_changed.emit(current_state)

func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null:
		return
	if not key_event.pressed or key_event.echo:
		return
	if JournalManager.is_scene_input_blocked():
		return

	if key_event.physical_keycode == KEY_SHIFT or key_event.keycode == KEY_SHIFT:
		toggle_cat_vision()
		get_viewport().set_input_as_handled()
	elif key_event.physical_keycode == KEY_F1 or key_event.keycode == KEY_F1:
		set_cat_critical(not is_cat_critical)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_refresh_state()

	var vision_target: float = 1.0 if current_state == CatState.CAT_VISION else 0.0
	var danger_target: float = 1.0 if current_state == CatState.DANGER else 0.0
	var weight: float = 1.0 - exp(-transition_speed * delta)
	vision_amount = lerpf(vision_amount, vision_target, weight)
	danger_amount = lerpf(danger_amount, danger_target, weight)

	_apply_environment(vision_amount, danger_amount)
	_update_cat_vision_music(vision_amount)
	_update_revealed_objects(vision_amount)

func set_location(location_id: String) -> void:
	var next_location_id: String = _normalize_location_id(location_id)
	var was_forced: bool = is_cat_vision_forced
	current_location_id = next_location_id

	if current_location_id == OTHER_WORLD_LOCATION_ID:
		if not was_forced:
			_cat_vision_enabled_before_forced = is_cat_vision_enabled
		is_cat_vision_forced = true
		is_cat_vision_enabled = true
	elif was_forced:
		is_cat_vision_forced = false
		is_cat_vision_enabled = _cat_vision_enabled_before_forced
	else:
		is_cat_vision_forced = false

	_refresh_state()

func toggle_cat_vision() -> void:
	if is_cat_vision_forced:
		is_cat_vision_enabled = true
		_refresh_state()
		return

	is_cat_vision_enabled = not is_cat_vision_enabled
	_refresh_state()

func set_cat_vision_enabled(is_enabled: bool) -> void:
	if is_cat_vision_forced and not is_enabled:
		is_cat_vision_enabled = true
	else:
		is_cat_vision_enabled = is_enabled
	_refresh_state()

func set_cat_critical(value: bool) -> void:
	is_cat_critical = value
	_refresh_state()

func set_danger_active(is_active: bool) -> void:
	set_cat_critical(is_active)

func get_cat_state() -> int:
	return current_state

func _refresh_state() -> void:
	var next_state: CatState = CatState.NORMAL
	if is_cat_vision_forced:
		is_cat_vision_enabled = true

	if is_cat_critical:
		next_state = CatState.DANGER
	elif is_cat_vision_enabled:
		next_state = CatState.CAT_VISION

	if next_state == current_state:
		return

	current_state = next_state
	cat_state_changed.emit(current_state)

func _detect_current_location_id() -> String:
	var scene_root: Node = _find_scene_root()
	if scene_root == null:
		return ""

	return scene_root.name

func _find_scene_root() -> Node:
	if get_tree().current_scene == null:
		return null

	var level_container: Node = get_tree().current_scene.get_node_or_null("LevelContainer")
	if level_container != null:
		var node: Node = self
		while node != null and node.get_parent() != level_container:
			node = node.get_parent()
		if node != null:
			return node

	return get_tree().current_scene

func _normalize_location_id(location_id: String) -> String:
	match location_id:
		"other_world", "OtherWorld":
			return OTHER_WORLD_LOCATION_ID
		"village", "Village":
			return "Village"
		"park", "Park":
			return "Park"
		"city", "City":
			return "City"
		"metro", "Metro":
			return "Metro"
		_:
			return location_id

func _apply_environment(vision: float, danger: float) -> void:
	if world_environment == null or world_environment.environment == null:
		return

	var environment: Environment = world_environment.environment
	var background_color: Color = normal_background_color.lerp(vision_background_color, vision)
	var ambient_color: Color = normal_ambient_color.lerp(vision_ambient_color, vision)
	var ambient_energy: float = lerpf(normal_ambient_energy, vision_ambient_energy, vision)
	var fog_color: Color = Color(0.42, 0.43, 0.43, 1.0).lerp(Color(0.16, 0.36, 0.34, 1.0), vision)
	var fog_density: float = lerpf(normal_fog_density, vision_fog_density, vision)
	var volumetric_density: float = lerpf(
		normal_volumetric_fog_density,
		vision_volumetric_fog_density,
		vision
	)
	var saturation: float = lerpf(normal_saturation, vision_saturation, vision)
	var brightness: float = lerpf(normal_brightness, vision_brightness, vision)
	var glow_intensity: float = lerpf(normal_glow_intensity, vision_glow_intensity, vision)

	environment.background_color = background_color.lerp(danger_background_color, danger)
	environment.ambient_light_color = ambient_color.lerp(danger_ambient_color, danger)
	environment.ambient_light_energy = lerpf(ambient_energy, danger_ambient_energy, danger)
	environment.fog_enabled = maxf(vision, danger) > 0.01
	environment.fog_light_color = fog_color.lerp(Color(0.38, 0.13, 0.11, 1.0), danger)
	environment.fog_density = lerpf(fog_density, danger_fog_density, danger)
	environment.volumetric_fog_enabled = maxf(vision, danger) > 0.01
	environment.volumetric_fog_density = lerpf(
		volumetric_density,
		danger_volumetric_fog_density,
		danger
	)

	environment.adjustment_enabled = true
	environment.adjustment_saturation = lerpf(saturation, danger_saturation, danger)
	environment.adjustment_brightness = lerpf(brightness, danger_brightness, danger)

	environment.glow_enabled = maxf(vision, danger) > 0.02
	environment.glow_intensity = lerpf(glow_intensity, danger_glow_intensity, danger)

func _set_revealed_objects_visible(is_visible: bool) -> void:
	_update_revealed_objects(1.0 if is_visible else 0.0)

func _update_revealed_objects(amount: float) -> void:
	for node in get_tree().get_nodes_in_group(revealed_group):
		if node.has_method("set_cat_vision_amount"):
			node.call("set_cat_vision_amount", amount)
		elif node is Node3D:
			var node_3d: Node3D = node as Node3D
			node_3d.visible = amount > 0.08

func _update_cat_vision_music(amount: float) -> void:
	if cat_vision_music == null:
		return

	cat_vision_music.volume_db = lerpf(cat_vision_music_min_volume_db, cat_vision_music_max_volume_db, amount)
