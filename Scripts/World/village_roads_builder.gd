@tool
extends Node3D

var road_material: StandardMaterial3D
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
	road_material = _material(Color(0.42, 0.4, 0.34, 1.0))

	_add_road("Road_01_MainStreet", Vector3(0, 0, 0), 58.0, 3.0, deg_to_rad(0))
	_add_road("Road_02_WestLane", Vector3(-17, 0, -1), 35.0, 2.6, deg_to_rad(90))
	_add_road("Road_03_EastLane", Vector3(17, 0, 1), 35.0, 2.6, deg_to_rad(90))
	_add_road("Road_04_NorthLane", Vector3(-5, 0, -14), 38.0, 2.4, deg_to_rad(90))
	_add_road("Road_05_SouthLane", Vector3(6, 0, 14), 36.0, 2.4, deg_to_rad(90))
	_add_road("Road_06_DiagonalWest", Vector3(-9, 0, -7), 25.0, 2.4, deg_to_rad(-28))
	_add_road("Road_07_DiagonalEast", Vector3(12, 0, 8), 29.0, 2.4, deg_to_rad(32))
	_add_road("Road_08_CatAlley", Vector3(-2, 0, 9), 21.0, 2.4, deg_to_rad(-38))

func _add_road(road_name: String, position: Vector3, length: float, width: float, rotation_y: float) -> void:
	var road: MeshInstance3D = MeshInstance3D.new()
	road.name = road_name
	road.position = position + Vector3(0, 0.015, 0)
	road.rotation.y = rotation_y
	road.mesh = BoxMesh.new()
	road.mesh.size = Vector3(width, 0.03, length)
	road.material_override = road_material
	_add_scene_child(self, road)

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
