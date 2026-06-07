@tool
extends Node3D

@export_category("Road")
@export_range(0.5, 12.0, 0.1) var road_width: float = 3.2
@export_range(0.02, 0.5, 0.01) var road_thickness: float = 0.12
@export var road_color: Color = Color(0.47, 0.37, 0.28, 1.0)
@export_range(0.0, 1.0, 0.01) var road_roughness: float = 0.92

@export_category("Center Marking")
@export var center_marking_enabled: bool = false
@export_range(0.02, 0.25, 0.01) var marking_height: float = 0.04
@export_range(0.03, 0.5, 0.01) var marking_width: float = 0.12
@export_range(0.5, 5.0, 0.1) var marking_length: float = 1.8
@export_range(0.2, 5.0, 0.1) var marking_gap: float = 1.2
@export var marking_color: Color = Color(0.9, 0.76, 0.43, 0.8)

@export_category("Quick Builder")
@export_range(1.0, 30.0, 0.5) var new_segment_length: float = 10.0
@export_tool_button("Add Road Point", "Add") var add_point_action: Callable = add_point
@export_tool_button("Remove Last Point", "Remove") var remove_point_action: Callable = remove_last_point
@export_tool_button("Rebuild Road", "Callable") var rebuild_action: Callable = rebuild

@export_category("Editor Display")
@export var auto_rebuild: bool = true
@export var show_point_numbers: bool = true

@onready var path_points: Node3D = get_node_or_null("PathPoints") as Node3D
@onready var generated: Node3D = get_node_or_null("Generated") as Node3D

var _last_signature: String = ""
var _rebuild_queued: bool = false


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		set_process(true)
		_queue_rebuild()


func _ready() -> void:
	set_process(Engine.is_editor_hint())
	_queue_rebuild()


func _process(_delta: float) -> void:
	if not auto_rebuild:
		return

	var signature: String = _make_signature()
	if signature != _last_signature:
		_queue_rebuild()


func add_point() -> void:
	path_points = get_node_or_null("PathPoints") as Node3D
	if path_points == null:
		return

	var points: Array[Node3D] = _get_points()
	var new_point: Marker3D = Marker3D.new()
	new_point.name = "RoadPoint_%02d" % (points.size() + 1)

	if points.is_empty():
		new_point.position = Vector3.ZERO
	elif points.size() == 1:
		new_point.position = points[0].position + Vector3.FORWARD * new_segment_length
	else:
		var last_point: Node3D = points[points.size() - 1]
		var previous_point: Node3D = points[points.size() - 2]
		var direction: Vector3 = last_point.position - previous_point.position
		if direction.length_squared() < 0.0001:
			direction = Vector3.FORWARD
		else:
			direction = direction.normalized()
		new_point.position = last_point.position + direction * new_segment_length

	path_points.add_child(new_point)
	_set_editor_owner(new_point)
	_queue_rebuild()


func remove_last_point() -> void:
	var points: Array[Node3D] = _get_points()
	if points.size() <= 2:
		return

	points[points.size() - 1].free()
	_queue_rebuild()


func rebuild() -> void:
	if not is_inside_tree():
		return

	path_points = get_node_or_null("PathPoints") as Node3D
	generated = get_node_or_null("Generated") as Node3D
	if path_points == null or generated == null:
		return

	_rebuild_queued = false
	_clear_generated()

	var points: Array[Node3D] = _get_points()
	if points.size() < 2:
		_last_signature = _make_signature()
		return

	var road_material: StandardMaterial3D = _create_material(road_color, road_roughness)
	var marking_material: StandardMaterial3D = _create_material(marking_color, 0.7)

	for index: int in range(points.size() - 1):
		_build_road_segment(points[index].position, points[index + 1].position, index, road_material)
		if center_marking_enabled:
			_build_markings(points[index].position, points[index + 1].position, index, marking_material)

	if Engine.is_editor_hint() and show_point_numbers:
		for index: int in range(points.size()):
			_add_point_number(points[index].position, index + 1)

	_last_signature = _make_signature()


func _queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("rebuild")


func _get_points() -> Array[Node3D]:
	var result: Array[Node3D] = []
	if path_points == null:
		path_points = get_node_or_null("PathPoints") as Node3D
	if path_points == null:
		return result

	for child: Node in path_points.get_children():
		if child is Node3D:
			result.append(child as Node3D)
	return result


func _build_road_segment(
	start: Vector3,
	end: Vector3,
	index: int,
	material: Material
) -> void:
	var direction: Vector3 = end - start
	var length: float = direction.length()
	if length <= 0.0001:
		return

	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = "RoadSegment_%02d" % (index + 1)
	instance.transform = _segment_transform(start, end)

	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(road_width, road_thickness, length + road_width * 0.12)
	instance.mesh = mesh
	instance.material_override = material
	generated.add_child(instance)


func _build_markings(
	start: Vector3,
	end: Vector3,
	segment_index: int,
	material: Material
) -> void:
	var direction: Vector3 = end - start
	var length: float = direction.length()
	if length <= 0.0001:
		return

	var step: float = marking_length + marking_gap
	var distance: float = marking_length * 0.5
	var marking_index: int = 1
	while distance < length:
		var actual_length: float = minf(marking_length, length - distance + marking_length * 0.5)
		var t: float = distance / length
		var center: Vector3 = start.lerp(end, t)
		center.y += road_thickness * 0.5 + marking_height * 0.5

		var half_length: float = actual_length * 0.5
		var unit_direction: Vector3 = direction / length
		var dash_start: Vector3 = center - unit_direction * half_length
		var dash_end: Vector3 = center + unit_direction * half_length

		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.name = "Marking_%02d_%02d" % [segment_index + 1, marking_index]
		instance.transform = _segment_transform(dash_start, dash_end)

		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(marking_width, marking_height, actual_length)
		instance.mesh = mesh
		instance.material_override = material
		generated.add_child(instance)

		distance += step
		marking_index += 1


func _segment_transform(start: Vector3, end: Vector3) -> Transform3D:
	var direction: Vector3 = end - start
	var z_axis: Vector3 = direction.normalized()
	var x_axis: Vector3 = Vector3.UP.cross(z_axis)
	if x_axis.length_squared() < 0.0001:
		x_axis = Vector3.RIGHT
	else:
		x_axis = x_axis.normalized()
	var y_axis: Vector3 = z_axis.cross(x_axis).normalized()
	return Transform3D(Basis(x_axis, y_axis, z_axis), (start + end) * 0.5)


func _create_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _add_point_number(position: Vector3, number: int) -> void:
	var label: Label3D = Label3D.new()
	label.name = "EditorNumber_%02d" % number
	label.position = position + Vector3.UP * 0.65
	label.text = str(number)
	label.font_size = 42
	label.pixel_size = 0.006
	label.modulate = Color(0.98, 0.73, 0.3, 1.0)
	label.outline_modulate = Color(0.08, 0.055, 0.025, 1.0)
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	generated.add_child(label)


func _set_editor_owner(node: Node) -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return

	var scene_root: Node = get_tree().edited_scene_root
	if scene_root != null:
		node.owner = scene_root


func _clear_generated() -> void:
	if generated == null:
		return
	for child: Node in generated.get_children():
		child.free()


func _make_signature() -> String:
	path_points = get_node_or_null("PathPoints") as Node3D
	if path_points == null:
		return "missing"

	var values: PackedStringArray = PackedStringArray([
		str(road_width),
		str(road_thickness),
		str(road_color),
		str(road_roughness),
		str(center_marking_enabled),
		str(marking_height),
		str(marking_width),
		str(marking_length),
		str(marking_gap),
		str(marking_color),
		str(show_point_numbers)
	])
	for child: Node in path_points.get_children():
		if child is Node3D:
			var point: Node3D = child as Node3D
			values.append(str(point.transform))
	return "|".join(values)
