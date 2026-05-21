@tool
extends Node3D

var _rebuild_in_editor := false

@export var rebuild_in_editor: bool:
	set(value):
		_rebuild_in_editor = false
		if Engine.is_editor_hint() and is_inside_tree():
			build_village()
	get:
		return _rebuild_in_editor

var ground_material: StandardMaterial3D
var road_material: StandardMaterial3D
var house_material: StandardMaterial3D
var roof_material: StandardMaterial3D
var window_material: StandardMaterial3D
var pole_material: StandardMaterial3D
var tree_material: StandardMaterial3D
var trunk_material: StandardMaterial3D

func _ready() -> void:
	build_village()

func build_village() -> void:
	for child in get_children():
		child.free()

	_create_materials()

	var roads := Node3D.new()
	roads.name = "Roads"
	add_child(roads)

	var houses := Node3D.new()
	houses.name = "Houses"
	add_child(houses)

	var lamps := Node3D.new()
	lamps.name = "StreetLamps"
	add_child(lamps)

	var trees := Node3D.new()
	trees.name = "Trees"
	add_child(trees)

	_add_road(roads, Vector3(0, 0, 0), 58.0, 3.0, deg_to_rad(0))
	_add_road(roads, Vector3(-17, 0, -1), 35.0, 2.6, deg_to_rad(90))
	_add_road(roads, Vector3(17, 0, 1), 35.0, 2.6, deg_to_rad(90))
	_add_road(roads, Vector3(-5, 0, -14), 38.0, 2.4, deg_to_rad(90))
	_add_road(roads, Vector3(6, 0, 14), 36.0, 2.4, deg_to_rad(90))
	_add_road(roads, Vector3(-9, 0, -7), 25.0, 2.4, deg_to_rad(-28))
	_add_road(roads, Vector3(12, 0, 8), 29.0, 2.4, deg_to_rad(32))
	_add_road(roads, Vector3(-2, 0, 9), 21.0, 2.4, deg_to_rad(-38))

	var house_data := [
		[Vector3(-24, 0, -20), Vector3(5.0, 2.5, 4.0), -18.0],
		[Vector3(-12, 0, -21), Vector3(4.0, 2.2, 3.5), 8.0],
		[Vector3(2, 0, -22), Vector3(4.3, 2.4, 3.8), -8.0],
		[Vector3(15, 0, -22), Vector3(5.3, 2.7, 4.2), 13.0],
		[Vector3(25, 0, -16), Vector3(4.0, 2.2, 3.4), -18.0],
		[Vector3(-25, 0, -6), Vector3(5.8, 2.8, 4.8), 10.0],
		[Vector3(-9, 0, -7), Vector3(4.6, 2.6, 3.7), -14.0],
		[Vector3(6, 0, -7), Vector3(5.2, 3.0, 4.5), 7.0],
		[Vector3(22, 0, -4), Vector3(6.0, 2.7, 4.5), -12.0],
		[Vector3(-20, 0, 8), Vector3(4.4, 2.3, 3.8), -20.0],
		[Vector3(-6, 0, 7), Vector3(5.0, 2.8, 4.0), 15.0],
		[Vector3(8, 0, 7), Vector3(4.2, 2.2, 3.5), -10.0],
		[Vector3(24, 0, 11), Vector3(5.8, 2.9, 4.4), 18.0],
		[Vector3(-25, 0, 22), Vector3(4.7, 2.5, 4.1), 16.0],
		[Vector3(-10, 0, 21), Vector3(4.2, 2.3, 3.6), -9.0],
		[Vector3(5, 0, 22), Vector3(4.6, 2.5, 3.8), 12.0],
		[Vector3(18, 0, 23), Vector3(4.2, 2.2, 3.6), -14.0],
	]

	for item in house_data:
		_add_house(houses, item[0], item[1], deg_to_rad(item[2]))

	var lamp_positions := [
		Vector3(-26, 0, -12), Vector3(-17, 0, -1), Vector3(-8, 0, -14),
		Vector3(0, 0, -2), Vector3(8, 0, -14), Vector3(17, 0, 0),
		Vector3(27, 0, -8), Vector3(-26, 0, 11), Vector3(-15, 0, 15),
		Vector3(-4, 0, 0), Vector3(6, 0, 13), Vector3(17, 0, 14),
		Vector3(28, 0, 9), Vector3(-2, 0, 26), Vector3(12, 0, 26)
	]

	for position in lamp_positions:
		_add_lamp(lamps, position)

	var tree_positions := [
		Vector3(-29, 0, -27), Vector3(-18, 0, -16), Vector3(-2, 0, -28),
		Vector3(11, 0, -17), Vector3(29, 0, -23), Vector3(-30, 0, 2),
		Vector3(-14, 0, 3), Vector3(13, 0, -5), Vector3(30, 0, 1),
		Vector3(-29, 0, 18), Vector3(-17, 0, 27), Vector3(0, 0, 16),
		Vector3(14, 0, 17), Vector3(29, 0, 25)
	]

	for i in range(tree_positions.size()):
		_add_tree(trees, tree_positions[i], 0.8 + float(i % 3) * 0.18)

func _create_materials() -> void:
	ground_material = _material(Color(0.18, 0.2, 0.19, 1.0))
	road_material = _material(Color(0.42, 0.4, 0.34, 1.0))
	house_material = _material(Color(0.47, 0.48, 0.43, 1.0))
	roof_material = _material(Color(0.32, 0.33, 0.31, 1.0))
	window_material = _emissive_material(Color(1.0, 0.86, 0.42, 1.0), 1.9)
	pole_material = _material(Color(0.24, 0.21, 0.18, 1.0))
	tree_material = _material(Color(0.28, 0.35, 0.27, 1.0))
	trunk_material = _material(Color(0.27, 0.2, 0.14, 1.0))

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

func _add_road(parent: Node3D, position: Vector3, length: float, width: float, rotation_y: float) -> void:
	var road := MeshInstance3D.new()
	road.name = "Road"
	road.position = position + Vector3(0, 0.015, 0)
	road.rotation.y = rotation_y
	road.mesh = BoxMesh.new()
	road.mesh.size = Vector3(width, 0.03, length)
	road.material_override = road_material
	parent.add_child(road)

func _add_house(parent: Node3D, position: Vector3, size: Vector3, rotation_y: float) -> void:
	var house := StaticBody3D.new()
	house.name = "House"
	house.position = position
	house.rotation.y = rotation_y
	house.collision_layer = 3
	parent.add_child(house)

	_add_box(house, "Walls", Vector3.ZERO, size, house_material)
	_add_box(house, "FlatRoof", Vector3(0, size.y, 0), Vector3(size.x + 0.35, 0.28, size.z + 0.35), roof_material)

	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	shape.position = Vector3(0, size.y * 0.5, 0)
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	house.add_child(shape)

	_add_box(house, "WarmWindowFront", Vector3(-size.x * 0.22, size.y * 0.45, -size.z * 0.5 - 0.03), Vector3(0.55, 0.55, 0.06), window_material)
	_add_box(house, "WarmWindowSide", Vector3(size.x * 0.5 + 0.03, size.y * 0.48, size.z * 0.12), Vector3(0.06, 0.5, 0.55), window_material)

func _add_lamp(parent: Node3D, position: Vector3) -> void:
	var lamp := Node3D.new()
	lamp.name = "StreetLamp"
	lamp.position = position
	parent.add_child(lamp)

	var pole := MeshInstance3D.new()
	pole.name = "Pole"
	pole.position = Vector3(0, 1.05, 0)
	var pole_mesh := CylinderMesh.new()
	pole_mesh.height = 2.1
	pole_mesh.top_radius = 0.055
	pole_mesh.bottom_radius = 0.075
	pole_mesh.radial_segments = 8
	pole.mesh = pole_mesh
	pole.material_override = pole_material
	lamp.add_child(pole)

	_add_box(lamp, "LampHead", Vector3(0, 2.08, 0), Vector3(0.42, 0.25, 0.42), window_material)

	var light := OmniLight3D.new()
	light.name = "WarmGlow"
	light.position = Vector3(0, 2.1, 0)
	light.light_color = Color(1.0, 0.82, 0.46, 1.0)
	light.light_energy = 2.2
	light.omni_range = 8.5
	light.shadow_enabled = true
	lamp.add_child(light)

func _add_tree(parent: Node3D, position: Vector3, scale_amount: float) -> void:
	var tree := Node3D.new()
	tree.name = "PineTree"
	tree.position = position
	tree.scale = Vector3.ONE * scale_amount
	parent.add_child(tree)

	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	trunk.position = Vector3(0, 0.45, 0)
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.height = 0.9
	trunk_mesh.top_radius = 0.11
	trunk_mesh.bottom_radius = 0.14
	trunk_mesh.radial_segments = 7
	trunk.mesh = trunk_mesh
	trunk.material_override = trunk_material
	tree.add_child(trunk)

	var crown := MeshInstance3D.new()
	crown.name = "Crown"
	crown.position = Vector3(0, 1.35, 0)
	var crown_mesh := CylinderMesh.new()
	crown_mesh.height = 1.8
	crown_mesh.top_radius = 0.05
	crown_mesh.bottom_radius = 0.75
	crown_mesh.radial_segments = 6
	crown.mesh = crown_mesh
	crown.material_override = tree_material
	tree.add_child(crown)

func _add_box(parent: Node3D, name: String, base_position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var box := MeshInstance3D.new()
	box.name = name
	box.position = base_position + Vector3(0, size.y * 0.5, 0)
	box.mesh = BoxMesh.new()
	box.mesh.size = size
	box.material_override = material
	parent.add_child(box)
	return box
