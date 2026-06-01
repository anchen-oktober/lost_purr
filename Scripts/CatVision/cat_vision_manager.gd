extends Node

@export var world_environment: WorldEnvironment
@export var cat_vision_music: AudioStreamPlayer
@export var transition_speed: float = 6.0
@export var revealed_group: String = "cat_vision_revealed"

@export var normal_background_color: Color = Color(0.36, 0.26, 0.18, 1.0)
@export var vision_background_color: Color = Color(0.055, 0.095, 0.1, 1.0)
@export var normal_ambient_color: Color = Color(0.98, 0.76, 0.48, 1.0)
@export var vision_ambient_color: Color = Color(0.2, 0.36, 0.33, 1.0)
@export var normal_ambient_energy: float = 1.35
@export var vision_ambient_energy: float = 0.65
@export var normal_fog_density: float = 0.0
@export var vision_fog_density: float = 0.018
@export var normal_volumetric_fog_density: float = 0.0
@export var vision_volumetric_fog_density: float = 0.02
@export var normal_saturation: float = 1.0
@export var vision_saturation: float = 0.75
@export var normal_brightness: float = 1.0
@export var vision_brightness: float = 0.9
@export var normal_glow_intensity: float = 0.0
@export var vision_glow_intensity: float = 0.18
@export var cat_vision_music_min_volume_db: float = -80.0
@export var cat_vision_music_max_volume_db: float = -12.0

var vision_amount: float = 0.0
var cat_vision_active: bool = false

func _ready() -> void:
	if world_environment == null:
		world_environment = get_tree().current_scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if cat_vision_music == null:
		cat_vision_music = get_tree().current_scene.find_child("CatVisionMusic", true, false) as AudioStreamPlayer
	if cat_vision_music != null:
		cat_vision_music.volume_db = cat_vision_music_min_volume_db
		if not cat_vision_music.playing:
			cat_vision_music.play()

	_set_revealed_objects_visible(false)
	_apply_environment(0.0)

func _process(delta: float) -> void:
	cat_vision_active = Input.is_physical_key_pressed(KEY_SHIFT)

	var target_amount: float = 1.0 if cat_vision_active else 0.0
	var weight: float = 1.0 - exp(-transition_speed * delta)
	vision_amount = lerpf(vision_amount, target_amount, weight)

	_apply_environment(vision_amount)
	_update_cat_vision_music(vision_amount)
	_update_revealed_objects(vision_amount)

func _apply_environment(amount: float) -> void:
	if world_environment == null or world_environment.environment == null:
		return

	var environment: Environment = world_environment.environment
	environment.background_color = normal_background_color.lerp(vision_background_color, amount)
	environment.ambient_light_color = normal_ambient_color.lerp(vision_ambient_color, amount)
	environment.ambient_light_energy = lerpf(normal_ambient_energy, vision_ambient_energy, amount)
	environment.fog_enabled = amount > 0.01
	environment.fog_light_color = Color(0.42, 0.43, 0.43, 1.0).lerp(Color(0.16, 0.36, 0.34, 1.0), amount)
	environment.fog_density = lerpf(normal_fog_density, vision_fog_density, amount)
	environment.volumetric_fog_enabled = amount > 0.01
	environment.volumetric_fog_density = lerpf(normal_volumetric_fog_density, vision_volumetric_fog_density, amount)

	environment.adjustment_enabled = true
	environment.adjustment_saturation = lerpf(normal_saturation, vision_saturation, amount)
	environment.adjustment_brightness = lerpf(normal_brightness, vision_brightness, amount)

	environment.glow_enabled = amount > 0.02
	environment.glow_intensity = lerpf(normal_glow_intensity, vision_glow_intensity, amount)

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
