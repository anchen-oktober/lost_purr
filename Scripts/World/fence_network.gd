@tool
extends Node3D

@export_category("Posts")
@export_range(0.5, 4.0, 0.1) var fence_height: float = 1.5
@export_range(0.05, 0.5, 0.01) var post_width: float = 0.16
@export_range(0.5, 5.0, 0.1) var post_spacing: float = 2.0

@export_category("Rails")
@export_range(1, 4, 1) var rail_count: int = 2
@export_range(0.04, 0.4, 0.01) var rail_thickness: float = 0.1
@export_range(0.04, 0.4, 0.01) var rail_depth: float = 0.09

@export_category("Pickets")
@export var pickets_enabled: bool = true
@export_range(0.05, 0.5, 0.01) var picket_width: float = 0.1
@export_range(0.05, 0.4, 0.01) var picket_depth: float = 0.07
@export_range(0.15, 1.5, 0.05) var picket_spacing: float = 0.42

@export_category("Appearance")
@export var wood_color: Color = Color(0.43, 0.28, 0.16, 1.0)
@export_range(0.0, 1.0, 0.01) var roughness: float = 0.95

@export_category("Collision")
@export var collision_enabled: bool = true
@export_range(0.05, 0.8, 0.01) var collision_depth: float = 0.22

@export_category("Quick Builder")
@export_range(1.0, 30.0, 0.5) var new_segment_length: float = 8.0
@export_tool_button("Add Fence Point", "Add") var add_point_action: Callable = add_point
@export_tool_button("Remove Last Point", "Remove") var remove_point_action: Callable = remove_last_point
@export_tool_button("Rebuild Fence", "Callable") var rebuild_action: Callable = rebuild

@export_category("Editor Display")
@export var auto_rebuild: bool = true
@export var show_point_numbers: bool = true

@onready var fence_points: Node3D = get_node_or_null("FencePoints") as Node3D
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
	fence_points = get_node_or_null("FencePoints") as Node3D
	if fence_points == null:
		return

	var points: Array[Node3D] = _get_points()
	var new_point: Marker3D = Marker3D.new()
	new_point.name = "FencePoint_%02d" % (points.size() + 1)

	if points.is_empty():
		new_point.position = Vector3.ZERO
	elif points.size() == 1:
		new_point.position = points[0].position + Vector3.FORWARD * new_segment_length
	else:
		var last_point: Node3D = points[points.size() - 1]
		var previous_point: Node3D = points[points.size() - 2]
		var direction: Vector3 = last_point.position - previous_point.position
		direction.y = 0.0
		if direction.length_squared() < 0.0001:
			direction = Vector3.FORWARD
		else:
			direction = direction.normalized()
		new_point.position = last_point.position + direction * new_segment_length

	fence_points.add_child(new_point)
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

	fence_points = get_node_or_null("FencePoints") as Node3D
	generated = get_node_or_null("Generated") as Node3D
	if fence_points == null or generated == null:
		return

	_rebuild_queued = false
	_clear_generated()

	var points: Array[Node3D] = _get_points()
	if points.size() < 2:
		_last_signature = _make_signature()
		return

	var wood_material: StandardMaterial3D = _create_material(wood_color, roughness)
	for index: int in range(points.size() - 1):
		_build_fence_span(points[index].position, points[index + 1].position, index, wood_material)

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
	if fence_points == null:
		fence_points = get_node_or_null("FencePoints") as Node3D
	if fence_points == null:
		return result

	for child: Node in fence_points.get_children():
		if child is Node3D:
			result.append(child as Node3D)
	return result


func _build_fence_span(
	start: Vector3,
	end: Vector3,
	span_index: int,
	material: Material
) -> void:
	var flat_direction: Vector3 = end - start
	flat_direction.y = 0.0
	var length: float = flat_direction.length()
	if length <= 0.0001:
		return

	var direction: Vector3 = flat_direction / length
	var interval_count: int = maxi(1, ceili(length / post_spacing))
	var actual_spacing: float = length / float(interval_count)
	var span_root: Node3D = Node3D.new()
	span_root.name = "FenceSpan_%02d" % (span_index + 1)
	generated.add_child(span_root)

	for post_index: int in range(interval_count + 1):
		if span_index > 0 and post_index == 0:
			continue
		var distance: float = actual_spacing * float(post_index)
		var t: float = distance / length
		var ground_position: Vector3 = start.lerp(end, t)
		_add_box(
			span_root,
			"Post_%02d" % (post_index + 1),
			ground_position + Vector3.UP * fence_height * 0.5,
			Vector3(post_width, fence_height, post_width),
			material
		)

	for interval_index: int in range(interval_count):
		var interval_start: Vector3 = start + direction * (actual_spacing * float(interval_index))
		var interval_end: Vector3 = start + direction * (actual_spacing * float(interval_index + 1))
		var start_t: float = (actual_spacing * float(interval_index)) / length
		var end_t: float = (actual_spacing * float(interval_index + 1)) / length
		interval_start.y = lerpf(start.y, end.y, start_t)
		interval_end.y = lerpf(start.y, end.y, end_t)

		for rail_index: int in range(rail_count):
			var rail_ratio: float = float(rail_index + 1) / float(rail_count + 1)
			var rail_height: float = fence_height * rail_ratio
			_add_box_between(
				span_root,
				"Rail_%02d_%02d" % [interval_index + 1, rail_index + 1],
				interval_start + Vector3.UP * rail_height,
				interval_end + Vector3.UP * rail_height,
				rail_thickness,
				rail_depth,
				material
			)

		if pickets_enabled:
			_build_pickets(
				span_root,
				interval_start,
				interval_end,
				interval_index,
				material
			)

	if collision_enabled:
		_add_span_collision(span_root, start, end, span_index)


func _build_pickets(
	parent: Node3D,
	start: Vector3,
	end: Vector3,
	interval_index: int,
	material: Material
) -> void:
	var direction: Vector3 = end - start
	var length: float = direction.length()
	if length <= picket_spacing:
		return

	var count: int = maxi(1, floori(length / picket_spacing) - 1)
	for picket_index: int in range(1, count + 1):
		var t: float = float(picket_index) / float(count + 1)
		var position: Vector3 = start.lerp(end, t)
		_add_box(
			parent,
			"Picket_%02d_%02d" % [interval_index + 1, picket_index],
			position + Vector3.UP * fence_height * 0.46,
			Vector3(picket_width, fence_height * 0.92, picket_depth),
			material,
			atan2(direction.x, direction.z)
		)


func _add_span_collision(
	parent: Node3D,
	start: Vector3,
	end: Vector3,
	span_index: int
) -> void:
	var direction: Vector3 = end - start
	direction.y = 0.0
	var length: float = direction.length()
	if length <= 0.0001:
		return

	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Collision_%02d" % (span_index + 1)
	body.position = (start + end) * 0.5 + Vector3.UP * fence_height * 0.5
	body.rotation.y = atan2(direction.x, direction.z)

	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(collision_depth, fence_height, length)
	shape_node.shape = shape
	body.add_child(shape_node)
	parent.add_child(body)


func _add_box(
	parent: Node3D,
	node_name: String,
	position: Vector3,
	size: Vector3,
	material: Material,
	rotation_y: float = 0.0
) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	instance.rotation.y = rotation_y
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)


func _add_box_between(
	parent: Node3D,
	node_name: String,
	start: Vector3,
	end: Vector3,
	height: float,
	depth: float,
	material: Material
) -> void:
	var direction: Vector3 = end - start
	var length: float = direction.length()
	if length <= 0.0001:
		return

	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.transform = _segment_transform(start, end)
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(depth, height, length)
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)


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


func _create_material(color: Color, material_roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = material_roughness
	return material


func _add_point_number(position: Vector3, number: int) -> void:
	var label: Label3D = Label3D.new()
	label.name = "EditorNumber_%02d" % number
	label.position = position + Vector3.UP * (fence_height + 0.5)
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
	fence_points = get_node_or_null("FencePoints") as Node3D
	if fence_points == null:
		return "missing"

	var values: PackedStringArray = PackedStringArray([
		str(fence_height),
		str(post_width),
		str(post_spacing),
		str(rail_count),
		str(rail_thickness),
		str(rail_depth),
		str(pickets_enabled),
		str(picket_width),
		str(picket_depth),
		str(picket_spacing),
		str(wood_color),
		str(roughness),
		str(collision_enabled),
		str(collision_depth),
		str(show_point_numbers)
	])
	for child: Node in fence_points.get_children():
		if child is Node3D:
			var point: Node3D = child as Node3D
			values.append(str(point.transform))
	return "|".join(values)
