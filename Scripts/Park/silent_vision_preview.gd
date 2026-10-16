@tool
extends Node3D

# Separate physics space makes collision shapes available to ray queries in the
# editor too; the editor's game physics space does not simulate scene bodies.
var _space: RID
var _bodies: Array[RID] = []

func rebuild(scene: Node, watcher: Node3D, mask: int) -> void:
	clear()
	_space = PhysicsServer3D.space_create()
	PhysicsServer3D.space_set_active(_space, true)
	for node in scene.find_children("*", "CollisionShape3D", true, false):
		var collision := node as CollisionShape3D
		var body := collision.get_parent() as PhysicsBody3D
		if collision.disabled or collision.shape == null or body == null:
			continue
		if watcher.is_ancestor_of(body) or body.has_method("apply_fear_damage") or body.collision_layer & mask == 0:
			continue
		var rid: RID = PhysicsServer3D.body_create()
		PhysicsServer3D.body_set_mode(rid, PhysicsServer3D.BODY_MODE_STATIC)
		PhysicsServer3D.body_set_collision_layer(rid, body.collision_layer)
		PhysicsServer3D.body_add_shape(rid, collision.shape.get_rid())
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, collision.global_transform)
		PhysicsServer3D.body_set_space(rid, _space)
		_bodies.append(rid)

func get_space_state() -> PhysicsDirectSpaceState3D:
	if not _space.is_valid():
		return null
	return PhysicsServer3D.space_get_direct_state(_space)

func clear() -> void:
	for body in _bodies:
		PhysicsServer3D.free_rid(body)
	_bodies.clear()
	if _space.is_valid():
		PhysicsServer3D.free_rid(_space)
		_space = RID()

func _exit_tree() -> void:
	clear()
