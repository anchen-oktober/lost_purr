@tool
extends Node3D

@export_category("Pole")
@export_range(2.0, 12.0, 0.1) var pole_height: float = 5.5
@export_range(0.04, 0.5, 0.01) var pole_radius: float = 0.14
@export_range(0.5, 5.0, 0.1) var crossarm_width: float = 2.8
@export_range(0.05, 0.5, 0.01) var crossarm_thickness: float = 0.16
@export_range(0.1, 1.5, 0.05) var insulator_drop: float = 0.35

@export_category("Wires")
@export_range(1, 5, 1) var wire_count: int = 3
@export_range(0.2, 2.0, 0.05) var wire_spacing: float = 0.9
@export_range(0.0, 4.0, 0.05) var wire_sag: float = 0.75
@export_range(2, 24, 1) var segments_per_span: int = 10
@export_range(0.01, 0.12, 0.005) var wire_radius: float = 0.025

@export_category("Appearance")
@export var pole_color: Color = Color(0.22, 0.16, 0.11, 1.0)
@export var metal_color: Color = Color(0.18, 0.19, 0.18, 1.0)
@export var insulator_color: Color = Color(0.22, 0.32, 0.25, 1.0)
@export var wire_color: Color = Color(0.055, 0.06, 0.06, 1.0)

@export_category("Quick Builder")
@export_range(1.0, 30.0, 0.5) var new_span_length: float = 12.0
@export_tool_button("Add Pole", "Add") var add_pole_action: Callable = add_pole
@export_tool_button("Remove Last Pole", "Remove") var remove_pole_action: Callable = remove_last_pole
@export_tool_button("Rebuild Network", "Callable") var rebuild_action: Callable = rebuild

@export_category("Editor Display")
@export var auto_rebuild: bool = true
@export var show_pole_numbers: bool = true

@onready var pole_points: Node3D = get_node_or_null("PolePoints") as Node3D
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


func add_pole() -> void:
	pole_points = get_node_or_null("PolePoints") as Node3D
	if pole_points == null:
		return

	var points: Array[Node3D] = _get_pole_points()
	var new_point: Marker3D = Marker3D.new()
	new_point.name = "Pole_%02d" % (points.size() + 1)

	if points.is_empty():
		new_point.position = Vector3.ZERO
	elif points.size() == 1:
		new_point.position = points[0].position + Vector3.FORWARD * new_span_length
		new_point.rotation.y = points[0].rotation.y
	else:
		var last_point: Node3D = points[points.size() - 1]
		var previous_point: Node3D = points[points.size() - 2]
		var direction: Vector3 = last_point.position - previous_point.position
		direction.y = 0.0
		if direction.length_squared() < 0.0001:
			direction = Vector3.FORWARD
		else:
			direction = direction.normalized()
		new_point.position = last_point.position + direction * new_span_length
		new_point.rotation.y = last_point.rotation.y

	pole_points.add_child(new_point)
	_set_editor_owner(new_point)
	_queue_rebuild()


func remove_last_pole() -> void:
	var points: Array[Node3D] = _get_pole_points()
	if points.size() <= 2:
		return

	points[points.size() - 1].free()
	_queue_rebuild()


func rebuild() -> void:
	if not is_inside_tree():
		return

	pole_points = get_node_or_null("PolePoints") as Node3D
	generated = get_node_or_null("Generated") as Node3D
	if pole_points == null or generated == null:
		return

	_rebuild_queued = false
	_clear_generated()

	var points: Array[Node3D] = _get_pole_points()
	if points.is_empty():
		_last_signature = _make_signature()
		return

	var pole_material: StandardMaterial3D = _create_material(pole_color, 0.92)
	var metal_material: StandardMaterial3D = _create_material(metal_color, 0.68)
	var insulator_material: StandardMaterial3D = _create_material(insulator_color, 0.38)
	var wire_material: StandardMaterial3D = _create_material(wire_color, 0.48)

	for index: int in range(points.size()):
		_build_pole(points[index], index, pole_material, metal_material, insulator_material)

	for index: int in range(points.size() - 1):
		_build_span(points[index], points[index + 1], index, wire_material)

	_last_signature = _make_signature()


func _queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("rebuild")


func _get_pole_points() -> Array[Node3D]:
	var result: Array[Node3D] = []
	if pole_points == null:
		return result

	for child: Node in pole_points.get_children():
		if child is Node3D:
			result.append(child as Node3D)
	return result


func _build_pole(
	point: Node3D,
	index: int,
	pole_material: Material,
	metal_material: Material,
	insulator_material: Material
) -> void:
	var pole_root: Node3D = Node3D.new()
	pole_root.name = "Pole_%02d" % (index + 1)
	pole_root.position = point.position
	pole_root.rotation.y = point.rotation.y
	generated.add_child(pole_root)

	_add_cylinder(
		pole_root,
		"Post",
		Vector3(0.0, pole_height * 0.5, 0.0),
		pole_height,
		pole_radius,
		pole_material
	)

	var arm_y: float = pole_height - 0.22
	_add_box(
		pole_root,
		"Crossarm",
		Vector3(0.0, arm_y, 0.0),
		Vector3(crossarm_width, crossarm_thickness, crossarm_thickness * 1.35),
		metal_material
	)

	var offsets: PackedFloat32Array = _wire_offsets()
	for wire_index: int in range(offsets.size()):
		var offset: float = offsets[wire_index]
		_add_cylinder(
			pole_root,
			"Insulator_%02d" % (wire_index + 1),
			Vector3(offset, arm_y - insulator_drop * 0.5, 0.0),
			insulator_drop,
			crossarm_thickness * 0.42,
			insulator_material
		)

	if Engine.is_editor_hint() and show_pole_numbers:
		_add_pole_number(pole_root, index + 1)


func _build_span(
	start_point: Node3D,
	end_point: Node3D,
	span_index: int,
	wire_material: Material
) -> void:
	var span_root: Node3D = Node3D.new()
	span_root.name = "Span_%02d" % (span_index + 1)
	generated.add_child(span_root)

	var offsets: PackedFloat32Array = _wire_offsets()
	for wire_index: int in range(offsets.size()):
		var start_anchor: Vector3 = _wire_anchor(start_point, offsets[wire_index])
		var end_anchor: Vector3 = _wire_anchor(end_point, offsets[wire_index])
		var previous: Vector3 = start_anchor

		for segment_index: int in range(1, segments_per_span + 1):
			var t: float = float(segment_index) / float(segments_per_span)
			var current: Vector3 = start_anchor.lerp(end_anchor, t)
			current.y -= wire_sag * 4.0 * t * (1.0 - t)
			_add_cylinder_between(
				span_root,
				"Wire_%02d_%02d" % [wire_index + 1, segment_index],
				previous,
				current,
				wire_radius,
				wire_material
			)
			previous = current


func _wire_anchor(point: Node3D, lateral_offset: float) -> Vector3:
	var lateral_axis: Vector3 = point.transform.basis.x.normalized()
	return point.position + lateral_axis * lateral_offset + Vector3.UP * (
		pole_height - 0.22 - insulator_drop
	)


func _wire_offsets() -> PackedFloat32Array:
	var offsets: PackedFloat32Array = PackedFloat32Array()
	var center: float = float(wire_count - 1) * 0.5
	for index: int in range(wire_count):
		offsets.append((float(index) - center) * wire_spacing)
	return offsets


func _add_box(
	parent: Node3D,
	node_name: String,
	local_position: Vector3,
	size: Vector3,
	material: Material
) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.position = local_position
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)


func _add_cylinder(
	parent: Node3D,
	node_name: String,
	local_position: Vector3,
	height: float,
	radius: float,
	material: Material
) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.position = local_position
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.height = height
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.radial_segments = 10
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)


func _add_cylinder_between(
	parent: Node3D,
	node_name: String,
	start: Vector3,
	end: Vector3,
	radius: float,
	material: Material
) -> void:
	var direction: Vector3 = end - start
	var length: float = direction.length()
	if length <= 0.0001:
		return

	var y_axis: Vector3 = direction / length
	var helper_axis: Vector3 = Vector3.FORWARD
	if abs(y_axis.dot(helper_axis)) > 0.98:
		helper_axis = Vector3.RIGHT
	var x_axis: Vector3 = helper_axis.cross(y_axis).normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()

	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.transform = Transform3D(
		Basis(x_axis, y_axis, z_axis),
		(start + end) * 0.5
	)
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.height = length
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.radial_segments = 6
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)


func _create_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _add_pole_number(parent: Node3D, number: int) -> void:
	var label: Label3D = Label3D.new()
	label.name = "EditorNumber"
	label.position = Vector3(0.0, pole_height + 0.65, 0.0)
	label.text = str(number)
	label.font_size = 42
	label.pixel_size = 0.006
	label.modulate = Color(1.0, 0.76, 0.28, 1.0)
	label.outline_modulate = Color(0.08, 0.055, 0.025, 1.0)
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)


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
	pole_points = get_node_or_null("PolePoints") as Node3D
	if pole_points == null:
		return "missing"

	var values: PackedStringArray = PackedStringArray([
		str(pole_height),
		str(pole_radius),
		str(crossarm_width),
		str(crossarm_thickness),
		str(insulator_drop),
		str(wire_count),
		str(wire_spacing),
		str(wire_sag),
		str(segments_per_span),
		str(wire_radius),
		str(pole_color),
		str(metal_color),
		str(insulator_color),
		str(wire_color),
		str(show_pole_numbers)
	])
	for child: Node in pole_points.get_children():
		if child is Node3D:
			var point: Node3D = child as Node3D
			values.append(str(point.transform))
	return "|".join(values)
