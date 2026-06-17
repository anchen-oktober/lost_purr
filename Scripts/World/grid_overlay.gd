@tool
extends Node3D

@export_category("Grid")
@export_range(8.0, 512.0, 1.0) var grid_size: float = 160.0:
	set(value):
		grid_size = value
		_queue_rebuild()
@export_range(0.25, 16.0, 0.25) var cell_size: float = 2.0:
	set(value):
		cell_size = value
		_queue_rebuild()
@export_range(-180.0, 180.0, 1.0) var grid_rotation_degrees: float = 45.0:
	set(value):
		grid_rotation_degrees = value
		_queue_rebuild()
@export var grid_color: Color = Color(0.74, 0.92, 1.0, 1.0):
	set(value):
		grid_color = value
		_queue_rebuild()
@export_range(0.0, 1.0, 0.01) var grid_opacity: float = 0.32:
	set(value):
		grid_opacity = value
		_queue_rebuild()
@export_range(-2.0, 5.0, 0.01) var grid_height: float = 0.08:
	set(value):
		grid_height = value
		_queue_rebuild()

@export_category("Editor")
@export var editor_only: bool = true
@export var visible_in_editor: bool = false:
	set(value):
		visible_in_editor = value
		_apply_visibility()
@export var start_visible_in_debug: bool = false

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var _is_grid_visible: bool = false
var _rebuild_queued: bool = false
var _was_toggle_key_pressed: bool = false


func _enter_tree() -> void:
	if _should_disable_for_build():
		_disable_grid()
		return

	set_process(Engine.is_editor_hint())
	set_process_input(false)
	_queue_rebuild()


func _ready() -> void:
	if _should_disable_for_build():
		_disable_grid()
		return

	set_process(Engine.is_editor_hint())
	set_process_input(false)
	_is_grid_visible = visible_in_editor if Engine.is_editor_hint() else start_visible_in_debug
	_queue_rebuild()
	_apply_visibility()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() or _should_disable_for_build():
		return

	var toggle_key_pressed: bool = Input.is_key_pressed(KEY_G)
	if toggle_key_pressed and not _was_toggle_key_pressed:
		visible_in_editor = not visible_in_editor
		_apply_visibility()
	_was_toggle_key_pressed = toggle_key_pressed


func toggle_grid() -> void:
	set_grid_visible(not _is_grid_visible)


func set_grid_visible(is_visible: bool) -> void:
	_is_grid_visible = is_visible
	_apply_visibility()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return

	_rebuild_queued = true
	call_deferred("_rebuild_grid")


func _rebuild_grid() -> void:
	_rebuild_queued = false

	if mesh_instance == null:
		mesh_instance = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_instance == null:
		return

	var mesh: ArrayMesh = ArrayMesh.new()
	var vertices: PackedVector3Array = PackedVector3Array()
	var half_size: float = grid_size * 0.5
	var safe_cell_size: float = maxf(cell_size, 0.01)
	var line_count: int = int(floor(grid_size / safe_cell_size))
	var start_index: int = -line_count
	var end_index: int = line_count

	for index: int in range(start_index, end_index + 1):
		var offset: float = float(index) * safe_cell_size
		vertices.append(Vector3(-half_size, grid_height, offset))
		vertices.append(Vector3(half_size, grid_height, offset))
		vertices.append(Vector3(offset, grid_height, -half_size))
		vertices.append(Vector3(offset, grid_height, half_size))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)

	mesh_instance.mesh = mesh
	mesh_instance.material_override = _create_grid_material()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.rotation.y = deg_to_rad(grid_rotation_degrees)
	_apply_visibility()


func _create_grid_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	var color: Color = grid_color
	color.a = grid_opacity
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _apply_visibility() -> void:
	if mesh_instance == null:
		mesh_instance = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_instance == null:
		return

	if _should_disable_for_build():
		mesh_instance.visible = false
		return

	mesh_instance.visible = visible_in_editor if Engine.is_editor_hint() else _is_grid_visible


func _should_disable_for_build() -> bool:
	return editor_only and not Engine.is_editor_hint()


func _disable_grid() -> void:
	set_process_input(false)
	if mesh_instance == null:
		mesh_instance = get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_instance != null:
		mesh_instance.visible = false
		mesh_instance.mesh = null
