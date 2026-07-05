extends Node3D
class_name CatVisionReveal

@export var visible_only_in_cat_vision: bool = true
@export var normal_visibility: bool = false
@export var cat_vision_visibility: bool = true
@export var highlight_color: Color = Color(1.0, 0.76, 0.32, 0.85)
@export var reveal_sound: AudioStream
@export_enum("OwnerAura", "StrangeAura", "HiddenClue", "SilentShadowHint", "FalseTrail") var reveal_type: int = 0
@export var max_alpha: float = 0.7
@export var max_emission: float = 1.5
@export var max_light_energy: float = 0.85

var _materials: Array[StandardMaterial3D] = []
var _lights: Array[Light3D] = []
var _audio_player: AudioStreamPlayer3D
var _was_visible: bool = false

func _ready() -> void:
	add_to_group("cat_vision_revealed")
	_audio_player = get_node_or_null("RevealSound") as AudioStreamPlayer3D
	_prepare_targets(self)
	set_cat_vision_amount(0.0)

func set_cat_vision_amount(amount: float) -> void:
	var reveal_amount := clampf(amount, 0.0, 1.0)
	var is_revealed := reveal_amount > 0.08
	var should_be_visible := cat_vision_visibility if is_revealed else normal_visibility
	visible = should_be_visible

	if reveal_sound != null and is_revealed and not _was_visible and _audio_player != null:
		_audio_player.stream = reveal_sound
		_audio_player.play()
	_was_visible = is_revealed

	for material in _materials:
		var color := material.albedo_color
		color.a = max_alpha * reveal_amount if visible_only_in_cat_vision else lerpf(0.25, max_alpha, reveal_amount)
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = highlight_color
		material.emission_energy_multiplier = max_emission * reveal_amount

	for light in _lights:
		light.light_color = highlight_color
		light.light_energy = max_light_energy * reveal_amount

func _prepare_targets(root: Node) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			_prepare_mesh(child as MeshInstance3D)
		elif child is Light3D:
			_lights.append(child as Light3D)
		_prepare_targets(child)

func _prepare_mesh(mesh_instance: MeshInstance3D) -> void:
	var source_material := mesh_instance.get_surface_override_material(0)
	if source_material == null:
		source_material = StandardMaterial3D.new()

	var material := source_material.duplicate() as StandardMaterial3D
	if material == null:
		return

	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = highlight_color
	mesh_instance.set_surface_override_material(0, material)
	_materials.append(material)
