extends Node3D

var tree_materials: Array[StandardMaterial3D] = []
var trunk_material: StandardMaterial3D

func build() -> void:
	_clear_children()
	tree_materials = [
		_material(Color(0.55, 0.43, 0.16, 1.0)),
		_material(Color(0.66, 0.34, 0.13, 1.0)),
		_material(Color(0.36, 0.44, 0.22, 1.0)),
		_material(Color(0.74, 0.52, 0.18, 1.0)),
	]
	trunk_material = _material(Color(0.39, 0.24, 0.14, 1.0))

	var tree_positions: Array[Vector3] = [
		Vector3(-29, 0, -27), Vector3(-18, 0, -16), Vector3(-2, 0, -28),
		Vector3(11, 0, -17), Vector3(29, 0, -23), Vector3(-30, 0, 2),
		Vector3(-14, 0, 3), Vector3(13, 0, -5), Vector3(30, 0, 1),
		Vector3(-29, 0, 18), Vector3(-17, 0, 27), Vector3(0, 0, 16),
		Vector3(14, 0, 17), Vector3(29, 0, 25)
	]

	for index in range(tree_positions.size()):
		_add_tree("PineTree_%02d" % [index + 1], tree_positions[index], 0.8 + float(index % 3) * 0.18, tree_materials[index % tree_materials.size()])

func _add_tree(tree_name: String, position: Vector3, scale_amount: float, tree_material: Material) -> void:
	var tree: Node3D = Node3D.new()
	tree.name = tree_name
	tree.position = position
	tree.scale = Vector3.ONE * scale_amount
	_add_scene_child(self, tree)

	var trunk: MeshInstance3D = MeshInstance3D.new()
	trunk.name = "Trunk"
	trunk.position = Vector3(0, 0.45, 0)
	var trunk_mesh: CylinderMesh = CylinderMesh.new()
	trunk_mesh.height = 0.9
	trunk_mesh.top_radius = 0.11
	trunk_mesh.bottom_radius = 0.14
	trunk_mesh.radial_segments = 7
	trunk.mesh = trunk_mesh
	trunk.material_override = trunk_material
	_add_scene_child(tree, trunk)

	var crown: MeshInstance3D = MeshInstance3D.new()
	crown.name = "Crown"
	crown.position = Vector3(0, 1.35, 0)
	var crown_mesh: CylinderMesh = CylinderMesh.new()
	crown_mesh.height = 1.8
	crown_mesh.top_radius = 0.05
	crown_mesh.bottom_radius = 0.75
	crown_mesh.radial_segments = 6
	crown.mesh = crown_mesh
	crown.material_override = tree_material
	_add_scene_child(tree, crown)

func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
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
