extends RefCounted

## Physical route used by PlayerCat's critical-fear recovery.
static func build(cat: CharacterBody3D, destination: Vector3) -> PackedVector3Array:
	var start: Vector3 = cat.global_position
	var spacing: float = maxf(1.0, start.distance_to(destination) / 64.0)
	var minimum := Vector2(minf(start.x, destination.x) - 8.0, minf(start.z, destination.z) - 8.0)
	var maximum := Vector2(maxf(start.x, destination.x) + 8.0, maxf(start.z, destination.z) + 8.0)
	var width: int = ceili((maximum.x - minimum.x) / spacing) + 1
	var depth: int = ceili((maximum.y - minimum.y) / spacing) + 1
	var graph := AStar3D.new()
	var cells: Dictionary = {}
	var space := cat.get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = 0.44
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = cat.collision_mask
	query.exclude = [cat.get_rid()]
	var terrain: Node = cat.get_tree().current_scene.find_child("Terrain3D", true, false)
	for x in range(width):
		for z in range(depth):
			var point := Vector3(minimum.x + x * spacing, maxf(start.y, destination.y) + 2.0, minimum.y + z * spacing)
			var ray := PhysicsRayQueryParameters3D.create(point, point - Vector3.UP * 12.0, cat.collision_mask, [cat.get_rid()])
			var hit: Dictionary = space.intersect_ray(ray)
			if hit.is_empty() and terrain != null:
				var data: Object = terrain.get("data")
				if data != null:
					var height: float = data.call("get_height", point)
					if is_finite(height): hit = {"position": Vector3(point.x, height, point.z), "normal": Vector3.UP}
			if hit.is_empty() or hit.normal.y < 0.65: continue
			point = hit.position + Vector3.UP * 0.5
			query.transform = Transform3D(Basis.IDENTITY, point)
			query.motion = Vector3.ZERO
			if not space.intersect_shape(query, 1).is_empty(): continue
			var id: int = x * depth + z
			graph.add_point(id, point)
			cells[Vector2i(x, z)] = id
	for cell: Vector2i in cells:
		var id: int = cells[cell]
		for offset in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
			var other: Vector2i = cell + offset
			if not cells.has(other): continue
			var next: int = cells[other]
			var from: Vector3 = graph.get_point_position(id)
			var to: Vector3 = graph.get_point_position(next)
			if absf(from.y - to.y) > 0.6: continue
			query.transform = Transform3D(Basis.IDENTITY, from)
			query.motion = to - from
			var travel: PackedFloat32Array = space.cast_motion(query)
			if travel[0] >= 0.99: graph.connect_points(id, next)
	if graph.get_point_count() == 0: return PackedVector3Array()
	var first: int = graph.get_closest_point(start)
	var last: int = graph.get_closest_point(destination)
	if graph.get_point_position(last).distance_to(destination) > spacing * 1.5:
		return PackedVector3Array()
	var path: PackedVector3Array = graph.get_point_path(first, last)
	if not path.is_empty(): path.append(destination)
	return path
