@tool
extends MeshInstance3D
## Non-physical ground marker shared by every Chapter1Trigger.
## Boxes have no radius: show their circumscribed circle without changing the area.

const SEGMENTS: int = 96
const RINGS: int = 8
const GROUND_OFFSET: float = 0.04
const FILL_COLOR := Color(0.08, 0.38, 1.0, 0.24)
const EDGE_COLOR := Color(0.12, 0.48, 1.0, 0.65)

var radius: float = 0.0
var _signature: Array = []
var _terrain: Node3D
var _ground_surfaces: Array[MeshInstance3D] = []

func _ready() -> void:
	top_level = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.disable_fog = true
	material_override = material
	call_deferred("refresh")

func _process(_delta: float) -> void:
	# Also follows moving/scaled areas and edits to shared Shape3D resources.
	refresh()

func refresh() -> void:
	# A queued editor refresh may arrive after closing or reloading the scene.
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var area := get_parent() as Area3D
	if area == null or not area.is_inside_tree() or area.is_queued_for_deletion():
		return
	var signature: Array = []
	var shapes: Array[CollisionShape3D] = []
	for child in area.get_children():
		if child is CollisionShape3D and child.shape != null:
			shapes.append(child)
			signature.append([child.global_transform, child.shape.get_rid(), _shape_radius(child)])
	if signature == _signature:
		return
	_signature = signature
	if shapes.is_empty():
		mesh = null
		return
	var scene_root: Node = area
	while scene_root.get_parent() is Node3D:
		scene_root = scene_root.get_parent()
	if not is_instance_valid(_terrain):
		_terrain = scene_root.find_child("Terrain3D", true, false) as Node3D

	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	radius = 0.0
	# Usually one shape; multiple shapes each receive their own ground circle.
	for collision in shapes:
		var shape_radius := _shape_radius(collision)
		if shape_radius <= 0.0:
			continue
		radius = maxf(radius, shape_radius)
		var center := collision.global_position
		var fallback_y := area.global_position.y
		var query := PhysicsRayQueryParameters3D.create(center + Vector3.UP * 100.0, center + Vector3.DOWN * 200.0, area.collision_mask)
		var hit := area.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			fallback_y = hit.position.y
		_ground_surfaces.clear()
		_cache_ground_surfaces(scene_root, center, shape_radius, _ground_point(center, fallback_y).y - GROUND_OFFSET)
		var first := vertices.size()
		vertices.append(_ground_point(center, fallback_y))
		colors.append(FILL_COLOR)
		for ring in range(1, RINGS + 1):
			for segment in range(SEGMENTS):
				var angle := TAU * float(segment) / SEGMENTS
				var point := center + Vector3(cos(angle), 0.0, sin(angle)) * shape_radius * float(ring) / RINGS
				vertices.append(_ground_point(point, fallback_y))
				colors.append(EDGE_COLOR if ring == RINGS else FILL_COLOR)
		for segment in range(SEGMENTS):
			var next := (segment + 1) % SEGMENTS
			indices.append_array([first, first + 1 + segment, first + 1 + next])
			for ring in range(1, RINGS):
				var inner := first + 1 + (ring - 1) * SEGMENTS
				var outer := inner + SEGMENTS
				indices.append_array([inner + segment, outer + segment, outer + next, inner + segment, outer + next, inner + next])
	if vertices.is_empty():
		mesh = null
		return
	global_transform = Transform3D.IDENTITY
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var ground_mesh := ArrayMesh.new()
	ground_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = ground_mesh

func _shape_radius(collision: CollisionShape3D) -> float:
	var shape := collision.shape
	var world_scale := collision.global_basis.get_scale().abs()
	if shape is SphereShape3D or shape is CylinderShape3D or shape is CapsuleShape3D:
		return shape.radius * maxf(world_scale.x, world_scale.z)
	if shape is BoxShape3D:
		var result := 0.0
		for x in [-0.5, 0.5]:
			for y in [-0.5, 0.5]:
				for z in [-0.5, 0.5]:
					var corner: Vector3 = collision.global_basis * (shape.size * Vector3(x, y, z))
					result = maxf(result, Vector2(corner.x, corner.z).length())
		return result
	return 0.0

func _ground_point(point: Vector3, fallback_y: float) -> Vector3:
	var height := fallback_y
	if is_instance_valid(_terrain):
		var data: Object = _terrain.get("data")
		if data != null:
			var terrain_height: float = data.call("get_height", point)
			if is_finite(terrain_height):
				height = terrain_height
	# Village's road/sidewalk meshes sit above Terrain3D and have no colliders.
	# Project onto nearby low BoxMesh surfaces as well, keeping depth testing on
	# so the marker is still occluded by buildings and the cat.
	for surface in _ground_surfaces:
		if not is_instance_valid(surface):
			continue
		var start := Vector3(point.x, height + 1.0, point.z)
		var end := Vector3(point.x, height - 0.1, point.z)
		var hit: Variant = surface.mesh.get_aabb().intersects_segment(surface.to_local(start), surface.to_local(end))
		if hit is Vector3:
			height = maxf(height, (surface.global_transform * hit).y)
	return Vector3(point.x, height + GROUND_OFFSET, point.z)

func _cache_ground_surfaces(scene_root: Node, center: Vector3, circle_radius: float, ground_y: float) -> void:
	_ground_surfaces.clear()
	for node in scene_root.find_children("*", "MeshInstance3D", true, false):
		var surface := node as MeshInstance3D
		if not surface.is_visible_in_tree() or not surface.mesh is BoxMesh:
			continue
		var bounds: AABB = surface.global_transform * surface.mesh.get_aabb()
		if bounds.size.y > 1.2 or bounds.end.y <= ground_y or bounds.end.y > ground_y + 0.75:
			continue
		if bounds.position.x > center.x + circle_radius or bounds.end.x < center.x - circle_radius:
			continue
		if bounds.position.z > center.z + circle_radius or bounds.end.z < center.z - circle_radius:
			continue
		_ground_surfaces.append(surface)
