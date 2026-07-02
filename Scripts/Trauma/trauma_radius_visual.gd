extends Node3D
class_name TraumaRadiusVisual

@export var radius: float = 4.0
@export var fill_color: Color = Color(0.75, 0.02, 0.02, 0.28)
@export var border_color: Color = Color(1.0, 0.08, 0.04, 0.72)
@export var pulse_scale_amount: float = 0.025
@export var pulse_duration: float = 0.85

var fill_mesh_instance: MeshInstance3D
var border_mesh_instance: MeshInstance3D
var fill_material: StandardMaterial3D
var border_material: StandardMaterial3D
var pulse_tween: Tween
var warning_tween: Tween
var warning_cooldown: float = 0.0

func _ready() -> void:
	_build_visuals()
	visible = false

func _process(delta: float) -> void:
	if warning_cooldown > 0.0:
		warning_cooldown = maxf(warning_cooldown - delta, 0.0)

func set_radius(value: float) -> void:
	radius = maxf(value, 0.1)
	if is_inside_tree():
		_build_visuals()

func set_trauma_radius_visible(is_visible: bool) -> void:
	if visible == is_visible:
		return

	visible = is_visible
	if is_visible:
		_start_pulse()
	else:
		_stop_pulse()

func pulse_trauma_radius_warning() -> void:
	if not visible or warning_cooldown > 0.0:
		return

	warning_cooldown = 0.5
	if warning_tween != null and warning_tween.is_valid():
		warning_tween.kill()

	warning_tween = create_tween()
	warning_tween.set_trans(Tween.TRANS_SINE)
	warning_tween.set_ease(Tween.EASE_OUT)
	warning_tween.tween_property(self, "scale", Vector3.ONE * 1.08, 0.12)
	warning_tween.parallel().tween_property(fill_material, "albedo_color", Color(fill_color.r, fill_color.g, fill_color.b, 0.48), 0.12)
	warning_tween.parallel().tween_property(border_material, "albedo_color", Color(border_color.r, border_color.g, border_color.b, 0.95), 0.12)
	warning_tween.tween_property(self, "scale", Vector3.ONE, 0.24)
	warning_tween.parallel().tween_property(fill_material, "albedo_color", fill_color, 0.24)
	warning_tween.parallel().tween_property(border_material, "albedo_color", border_color, 0.24)

func is_radius_visible() -> bool:
	return visible

func _build_visuals() -> void:
	if fill_mesh_instance == null:
		fill_mesh_instance = MeshInstance3D.new()
		fill_mesh_instance.name = "RedFill"
		add_child(fill_mesh_instance)
	if border_mesh_instance == null:
		border_mesh_instance = MeshInstance3D.new()
		border_mesh_instance.name = "RedBorder"
		add_child(border_mesh_instance)

	fill_mesh_instance.mesh = _create_fill_mesh()
	border_mesh_instance.mesh = _create_ring_mesh(radius, maxf(radius * 0.035, 0.06))

	fill_material = _create_material(fill_color)
	border_material = _create_material(border_color)
	fill_mesh_instance.material_override = fill_material
	border_mesh_instance.material_override = border_material

func _create_fill_mesh() -> CylinderMesh:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.018
	mesh.radial_segments = 96
	mesh.rings = 1
	return mesh

func _create_ring_mesh(outer_radius: float, thickness: float) -> ArrayMesh:
	var inner_radius: float = maxf(outer_radius - thickness, 0.05)
	var vertices: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var segments: int = 128

	for index in range(segments):
		var angle: float = TAU * float(index) / float(segments)
		var direction: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		vertices.append(direction * outer_radius + Vector3(0.0, 0.02, 0.0))
		vertices.append(direction * inner_radius + Vector3(0.0, 0.02, 0.0))

	for index in range(segments):
		var next_index: int = (index + 1) % segments
		var outer_a: int = index * 2
		var inner_a: int = outer_a + 1
		var outer_b: int = next_index * 2
		var inner_b: int = outer_b + 1
		indices.append_array([outer_a, outer_b, inner_a, inner_a, outer_b, inner_b])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _create_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = false
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _start_pulse() -> void:
	_stop_pulse()
	scale = Vector3.ONE
	pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.set_trans(Tween.TRANS_SINE)
	pulse_tween.set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(self, "scale", Vector3.ONE * (1.0 + pulse_scale_amount), pulse_duration)
	pulse_tween.tween_property(self, "scale", Vector3.ONE * (1.0 - pulse_scale_amount * 0.45), pulse_duration)

func _stop_pulse() -> void:
	if pulse_tween != null and pulse_tween.is_valid():
		pulse_tween.kill()
	scale = Vector3.ONE
