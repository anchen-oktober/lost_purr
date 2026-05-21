extends Node3D

@export var max_alpha: float = 0.62
@export var max_emission: float = 1.8
@export var max_light_energy: float = 0.8

var fade_materials: Array[StandardMaterial3D] = []
var fade_lights: Array[Light3D] = []

func _ready() -> void:
	add_to_group("cat_vision_revealed")
	_prepare_fade_targets()
	set_cat_vision_amount(0.0)

func set_cat_vision_amount(amount: float) -> void:
	var fade_amount: float = clampf(amount, 0.0, 1.0)
	visible = fade_amount > 0.01

	for material in fade_materials:
		var color: Color = material.albedo_color
		color.a = max_alpha * fade_amount
		material.albedo_color = color
		material.emission_energy_multiplier = max_emission * fade_amount

	for light in fade_lights:
		light.light_energy = max_light_energy * fade_amount

func _prepare_fade_targets() -> void:
	fade_materials.clear()
	fade_lights.clear()

	for child in get_children():
		if child is MeshInstance3D:
			var mesh_instance: MeshInstance3D = child as MeshInstance3D
			_prepare_mesh_material(mesh_instance)
		elif child is Light3D:
			var light: Light3D = child as Light3D
			fade_lights.append(light)

func _prepare_mesh_material(mesh_instance: MeshInstance3D) -> void:
	var source_material: Material = mesh_instance.get_surface_override_material(0)
	if source_material == null:
		return

	var material: StandardMaterial3D = source_material.duplicate() as StandardMaterial3D
	if material == null:
		return

	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.set_surface_override_material(0, material)
	fade_materials.append(material)
