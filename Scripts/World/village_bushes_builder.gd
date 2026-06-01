extends Node3D

var bush_materials: Array[StandardMaterial3D] = []

func build() -> void:
	_clear_children()
	bush_materials = [
		_material(Color(0.37, 0.44, 0.24, 1.0)),
		_material(Color(0.56, 0.34, 0.16, 1.0)),
		_material(Color(0.63, 0.46, 0.18, 1.0)),
	]

	var bush_data: Array = [
		[Vector3(-27, 0, -14), Vector3(1.0, 0.55, 0.8)],
		[Vector3(-21, 0, -2), Vector3(0.8, 0.5, 0.9)],
		[Vector3(-13, 0, -12), Vector3(0.9, 0.6, 0.7)],
		[Vector3(3, 0, -16), Vector3(0.8, 0.5, 0.8)],
		[Vector3(14, 0, -10), Vector3(1.1, 0.65, 0.9)],
		[Vector3(24, 0, -1), Vector3(0.85, 0.5, 0.8)],
		[Vector3(-24, 0, 14), Vector3(0.9, 0.6, 0.75)],
		[Vector3(-12, 0, 11), Vector3(1.0, 0.55, 0.85)],
		[Vector3(2, 0, 4), Vector3(0.8, 0.5, 0.75)],
		[Vector3(12, 0, 18), Vector3(1.1, 0.6, 0.85)],
		[Vector3(27, 0, 16), Vector3(0.9, 0.52, 0.9)],
		[Vector3(-5, 0, 28), Vector3(0.85, 0.5, 0.75)],
	]

	for index in range(bush_data.size()):
		var item: Array = bush_data[index]
		_add_bush("Bush_%02d" % [index + 1], item[0], item[1], bush_materials[index % bush_materials.size()])

func _add_bush(bush_name: String, position: Vector3, size: Vector3, bush_material: Material) -> void:
	var bush: MeshInstance3D = MeshInstance3D.new()
	bush.name = bush_name
	bush.position = position + Vector3(0, size.y * 0.5, 0)
	bush.mesh = SphereMesh.new()
	bush.mesh.radius = 0.5
	bush.mesh.height = 1.0
	bush.scale = size
	bush.material_override = bush_material
	_add_scene_child(self, bush)

func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
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
