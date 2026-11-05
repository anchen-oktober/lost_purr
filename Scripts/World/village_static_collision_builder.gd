extends Node

## Builds the missing gameplay collision for the static Village geometry.
##
## The level contains hand-built meshes as well as generated fence scenes.  Keeping
## collision generation here means the boxes stay in sync with mesh edits without
## duplicating the level or baking thousands of hand-maintained sub-resources.

const GENERATED_COLLISION_META := &"village_generated_static_collision"

const BUILDING_ROOTS := [
	NodePath("../Blockout/Semi_detached"),
	NodePath("../Blockout/Terraced"),
]

const FENCE_ROOTS := [
	NodePath("../Blockout/Fence_Terraced"),
	NodePath("../Blockout/Fence_Semi_detached"),
]

const PROP_ROOTS := [
	NodePath("../Village/StreetLamps"),
	NodePath("../Village/Trees"),
	NodePath("../Village/Bushes"),
]


func _ready() -> void:
	# FenceNetwork rebuilds its visual meshes deferred, so wait until all scene
	# constructors have settled before inspecting the final node hierarchy.
	call_deferred("_build_collisions")


func _build_collisions() -> void:
	_disable_collisions_for_hidden_static_geometry()
	_add_building_collisions()
	_add_fence_collisions()
	_add_prop_collisions()


func _add_building_collisions() -> void:
	for root_path: NodePath in BUILDING_ROOTS:
		var root := get_node_or_null(root_path) as Node3D
		if root == null or not root.is_visible_in_tree():
			continue
		for mesh in _meshes_below(root):
			# The ground-floor mesh is the full footprint of each building.  It
			# gives one tight box per building instead of blocking window and roof
			# details as separate invisible obstacles.
			if mesh.name == &"1st_floor":
				_add_mesh_collision(mesh)


func _add_fence_collisions() -> void:
	for root_path: NodePath in FENCE_ROOTS:
		var root := get_node_or_null(root_path) as Node3D
		if root == null or not root.is_visible_in_tree():
			continue
		for mesh in _meshes_below(root):
			# Fence segments are already box meshes.  One collider per segment
			# preserves gates and gaps instead of bridging them with a large box.
			_add_mesh_collision(mesh)


func _add_prop_collisions() -> void:
	for root_path: NodePath in PROP_ROOTS:
		var root := get_node_or_null(root_path) as Node3D
		if root == null or not root.is_visible_in_tree():
			continue
		for mesh in _meshes_below(root):
			if _is_prop_collision_mesh(mesh):
				_add_mesh_collision(mesh)


func _is_prop_collision_mesh(mesh: MeshInstance3D) -> bool:
	var path := String(mesh.get_path())
	if path.contains("/StreetLamps/"):
		# The pole is the solid part at cat height; the light and trigger stay
		# non-physical so interaction behaviour remains unchanged.
		return mesh.name == &"Pole"
	if path.contains("/Trees/"):
		# The trunk blocks movement, while the crown remains purely visual.
		return mesh.name == &"Trunk"
	return path.contains("/Bushes/")


func _meshes_below(root: Node3D) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh != null and mesh.mesh != null and mesh.is_visible_in_tree():
			meshes.append(mesh)
	return meshes


func _add_mesh_collision(mesh: MeshInstance3D) -> void:
	if _has_static_collision(mesh):
		return

	var parent := mesh.get_parent() as Node3D
	if parent == null:
		return

	var bounds := mesh.get_aabb()
	if bounds.size.x <= 0.001 or bounds.size.y <= 0.001 or bounds.size.z <= 0.001:
		return

	var body := StaticBody3D.new()
	body.name = "StaticCollision_%s" % mesh.name
	body.transform = mesh.transform
	body.set_meta(GENERATED_COLLISION_META, true)
	# The occlusion system must fade every visual child of the same prop (walls,
	# roof, doors, tree crown), while leaving neighbouring houses untouched.
	body.set_meta("occlusion_visual_root_path", parent.get_path())

	var shape := BoxShape3D.new()
	shape.size = bounds.size
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	collision_shape.shape = shape
	collision_shape.position = bounds.get_center()
	collision_shape.set_meta(GENERATED_COLLISION_META, true)

	body.add_child(collision_shape)
	parent.add_child(body)


func _has_static_collision(node: Node) -> bool:
	var current: Node = node.get_parent()
	while current != null:
		if current is StaticBody3D:
			return true
		if current == self:
			break
		current = current.get_parent()
	return false


func _disable_collisions_for_hidden_static_geometry() -> void:
	var scene_root := get_parent()
	if scene_root == null:
		return
	for node in scene_root.find_children("*", "CollisionShape3D", true, false):
		var shape := node as CollisionShape3D
		if shape == null or not _has_static_collision(shape):
			continue
		if not shape.is_visible_in_tree():
			shape.set_deferred("disabled", true)
