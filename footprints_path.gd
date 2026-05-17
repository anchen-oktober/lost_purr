extends Node3D

@export var max_alpha: float = 0.72
@export var max_emission: float = 1.6

var footprint_material: StandardMaterial3D

func _ready() -> void:
	add_to_group("cat_vision_revealed")
	_prepare_fade_material()
	set_cat_vision_amount(0.0)

func set_cat_vision_amount(amount: float) -> void:
	var fade_amount: float = clampf(amount, 0.0, 1.0)
	visible = fade_amount > 0.01

	if footprint_material == null:
		return

	var color: Color = footprint_material.albedo_color
	color.a = max_alpha * fade_amount
	footprint_material.albedo_color = color
	footprint_material.emission_energy_multiplier = max_emission * fade_amount

func _prepare_fade_material() -> void:
	var source_material: Material = null

	for child in get_children():
		if child is MeshInstance3D:
			var footprint: MeshInstance3D = child as MeshInstance3D
			source_material = footprint.get_surface_override_material(0)
			break

	if source_material == null:
		return

	footprint_material = source_material.duplicate() as StandardMaterial3D
	footprint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for child in get_children():
		if child is MeshInstance3D:
			var footprint: MeshInstance3D = child as MeshInstance3D
			footprint.set_surface_override_material(0, footprint_material)
