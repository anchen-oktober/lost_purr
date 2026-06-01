extends Node3D

var house_material: StandardMaterial3D
var roof_material: StandardMaterial3D
var window_material: StandardMaterial3D

func build() -> void:
	_clear_children()
	house_material = _material(Color(0.66, 0.57, 0.45, 1.0))
	roof_material = _material(Color(0.46, 0.22, 0.15, 1.0))
	window_material = _emissive_material(Color(1.0, 0.78, 0.36, 1.0), 2.25)

	var house_data: Array = [
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

	for index in range(house_data.size()):
		var item: Array = house_data[index]
		_add_house("House_%02d" % [index + 1], item[0], item[1], deg_to_rad(item[2]))

func _add_house(house_name: String, position: Vector3, size: Vector3, rotation_y: float) -> void:
	var house: StaticBody3D = StaticBody3D.new()
	house.name = house_name
	house.position = position
	house.rotation.y = rotation_y
	house.collision_layer = 3
	_add_scene_child(self, house)

	_add_box(house, "Walls", Vector3.ZERO, size, house_material)
	_add_box(house, "FlatRoof", Vector3(0, size.y, 0), Vector3(size.x + 0.35, 0.28, size.z + 0.35), roof_material)

	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	shape.position = Vector3(0, size.y * 0.5, 0)
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	_add_scene_child(house, shape)

	_add_box(house, "WarmWindowFront", Vector3(-size.x * 0.22, size.y * 0.45, -size.z * 0.5 - 0.03), Vector3(0.55, 0.55, 0.06), window_material)
	_add_box(house, "WarmWindowSide", Vector3(size.x * 0.5 + 0.03, size.y * 0.48, size.z * 0.12), Vector3(0.06, 0.5, 0.55), window_material)

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
