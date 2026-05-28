@tool
extends Node3D

var pole_material: StandardMaterial3D
var light_material: StandardMaterial3D
var _rebuild_in_editor: bool = false

@export var rebuild_in_editor: bool:
	set(value):
		_rebuild_in_editor = false
		if Engine.is_editor_hint() and is_inside_tree():
			build()
	get:
		return _rebuild_in_editor

func _ready() -> void:
	build()

func build() -> void:
	_clear_children()
	pole_material = _material(Color(0.24, 0.21, 0.18, 1.0))
	light_material = _emissive_material(Color(1.0, 0.86, 0.42, 1.0), 1.9)

	var lamp_positions: Array[Vector3] = [
		Vector3(-26, 0, -12), Vector3(-17, 0, -1), Vector3(-8, 0, -14),
		Vector3(0, 0, -2), Vector3(8, 0, -14), Vector3(17, 0, 0),
		Vector3(27, 0, -8), Vector3(-26, 0, 11), Vector3(-15, 0, 15),
		Vector3(-4, 0, 0), Vector3(6, 0, 13), Vector3(17, 0, 14),
		Vector3(28, 0, 9), Vector3(-2, 0, 26), Vector3(12, 0, 26)
	]

	for index in range(lamp_positions.size()):
		_add_lamp("StreetLamp_%02d" % [index + 1], lamp_positions[index])

func _add_lamp(lamp_name: String, position: Vector3) -> void:
	var lamp: Node3D = Node3D.new()
	lamp.name = lamp_name
	lamp.position = position
	_add_scene_child(self, lamp)

	var pole: MeshInstance3D = MeshInstance3D.new()
	pole.name = "Pole"
	pole.position = Vector3(0, 1.05, 0)
	var pole_mesh: CylinderMesh = CylinderMesh.new()
	pole_mesh.height = 2.1
	pole_mesh.top_radius = 0.055
	pole_mesh.bottom_radius = 0.075
	pole_mesh.radial_segments = 8
	pole.mesh = pole_mesh
	pole.material_override = pole_material
	_add_scene_child(lamp, pole)

	_add_box(lamp, "LampHead", Vector3(0, 2.08, 0), Vector3(0.42, 0.25, 0.42), light_material)

	var light: OmniLight3D = OmniLight3D.new()
	light.name = "WarmGlow"
	light.position = Vector3(0, 2.1, 0)
	light.light_color = Color(1.0, 0.82, 0.46, 1.0)
	light.light_energy = 2.2
	light.omni_range = 8.5
	light.shadow_enabled = true
	_add_scene_child(lamp, light)

func _add_box(parent: Node3D, name: String, base_position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var box: MeshInstance3D = MeshInstance3D.new()
	box.name = name
	box.position = base_position + Vector3(0, size.y * 0.5, 0)
	box.mesh = BoxMesh.new()
	box.mesh.size = size
	box.material_override = material
	_add_scene_child(parent, box)
	return box

func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = _material(color)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

func _clear_children() -> void:
	for child in get_children():
		child.free()

func _add_scene_child(parent: Node, child: Node) -> void:
	parent.add_child(child)
	if Engine.is_editor_hint() and is_inside_tree():
		var scene_root: Node = get_tree().edited_scene_root
		if scene_root != null:
			child.owner = scene_root
