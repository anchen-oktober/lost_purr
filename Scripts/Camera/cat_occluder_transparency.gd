class_name CatOccluderTransparency
extends Node3D

## Fades whole objects that stand between the active camera and the cat.
## Materials are duplicated per MeshInstance3D and restored after the fade, so
## shared source materials and collision geometry are never modified.

const OCCLUDER_SHADER := preload("res://Shaders/cat_occluder_fade.gdshader")
const VISUAL_ROOT_META := &"occlusion_visual_root_path"

@export_category("Occluder transparency")
@export var target: Node3D
@export_range(0.1, 4.0, 0.01, "suffix:m") var target_height: float = 0.75
@export_range(0.0, 0.95, 0.01) var transparency_amount: float = 0.60
@export_range(0.1, 2.0, 0.05, "suffix:s") var fade_in_duration: float = 0.40
@export_range(0.1, 2.0, 0.05, "suffix:s") var fade_out_duration: float = 0.40
@export_range(0.01, 0.5, 0.01, "suffix:s") var check_interval: float = 0.05
@export_range(1, 16, 1) var max_occluders: int = 8
@export_flags_3d_physics var occluder_collision_mask: int = 2147483647

var _check_timer := 0.0
var _active_meshes: Dictionary = {}


func _ready() -> void:
	if target == null:
		target = get_parent_node_3d()


func _physics_process(delta: float) -> void:
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = check_interval
	_refresh_occluders()


func _process(delta: float) -> void:
	var ids: Array = _active_meshes.keys()
	for id: Variant in ids:
		var state: Dictionary = _active_meshes[id]
		var mesh := state.get("mesh") as MeshInstance3D
		if not is_instance_valid(mesh):
			_active_meshes.erase(id)
			continue

		var desired: float = 1.0 if state.get("wanted", false) else 0.0
		var duration := fade_in_duration if desired > float(state.get("amount", 0.0)) else fade_out_duration
		state["amount"] = move_toward(float(state.get("amount", 0.0)), desired, delta / maxf(duration, 0.001))
		_update_transparency_materials(state)

		if float(state["amount"]) <= 0.0 and desired <= 0.0:
			_restore_mesh_materials(state)
			_active_meshes.erase(id)
		else:
			_active_meshes[id] = state


func _exit_tree() -> void:
	for state: Dictionary in _active_meshes.values():
		_restore_mesh_materials(state)
	_active_meshes.clear()


func _refresh_occluders() -> void:
	for id: Variant in _active_meshes.keys():
		var state: Dictionary = _active_meshes[id]
		state["wanted"] = false
		_active_meshes[id] = state

	if target == null or occluder_collision_mask == 0:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var target_point := target.global_position + Vector3.UP * target_height
	var space_state := get_world_3d().direct_space_state
	var checked_colliders: Dictionary = {}

	var excluded := _get_target_collision_rids()
	for index: int in max_occluders:
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, target_point)
		query.collision_mask = occluder_collision_mask
		query.collide_with_areas = false
		query.collide_with_bodies = true
		query.exclude = excluded
		var hit := space_state.intersect_ray(query)
		if hit.is_empty():
			break

		var collider := hit.get("collider") as CollisionObject3D
		if collider == null:
			break
		excluded.append(collider.get_rid())
		var collider_id := collider.get_instance_id()
		if checked_colliders.has(collider_id):
			continue
		checked_colliders[collider_id] = true

		for mesh: MeshInstance3D in _find_visual_meshes(collider):
			_activate_mesh(mesh)


func _get_target_collision_rids() -> Array[RID]:
	var excluded: Array[RID] = []
	if target is CollisionObject3D:
		excluded.append((target as CollisionObject3D).get_rid())
	for node: Node in target.find_children("*", "CollisionObject3D", true, false):
		var collision_object := node as CollisionObject3D
		if collision_object != null:
			excluded.append(collision_object.get_rid())
	return excluded


func _find_visual_meshes(collider: CollisionObject3D) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if collider.has_meta(VISUAL_ROOT_META):
		var visual_root_path := collider.get_meta(VISUAL_ROOT_META) as NodePath
		var visual_root := get_node_or_null(visual_root_path)
		if visual_root != null:
			_collect_meshes_below(visual_root, meshes)
			return meshes

	# Hand-authored colliders commonly own a complete visual hierarchy (walls,
	# roof, doors, foliage etc.).  Every visual child fades together.
	_collect_meshes_below(collider, meshes)
	if not meshes.is_empty():
		return meshes

	# Generated Village colliders are siblings of their source mesh.  Limit this
	# to immediate children so a collider never changes an entire level branch.
	var parent := collider.get_parent()
	if parent != null:
		for child: Node in parent.get_children():
			if child is MeshInstance3D:
				_add_mesh_once(meshes, child as MeshInstance3D)
	return meshes


func _collect_meshes_below(root: Node, meshes: Array[MeshInstance3D]) -> void:
	if root is MeshInstance3D:
		_add_mesh_once(meshes, root as MeshInstance3D)
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		_add_mesh_once(meshes, node as MeshInstance3D)


func _add_mesh_once(meshes: Array[MeshInstance3D], mesh: MeshInstance3D) -> void:
	if mesh == null or mesh.mesh == null or mesh == target or target.is_ancestor_of(mesh):
		return
	if not meshes.has(mesh):
		meshes.append(mesh)


func _activate_mesh(mesh: MeshInstance3D) -> void:
	if mesh.mesh == null:
		return
	var id := mesh.get_instance_id()
	if _active_meshes.has(id):
		var existing: Dictionary = _active_meshes[id]
		existing["wanted"] = true
		_active_meshes[id] = existing
		return

	var original_surface_overrides: Array[Material] = []
	var fade_materials: Array[ShaderMaterial] = []
	var original_override := mesh.material_override
	for surface: int in mesh.mesh.get_surface_count():
		original_surface_overrides.append(mesh.get_surface_override_material(surface))
		var source := _get_effective_material(mesh, surface, original_override)
		var fade_material := _make_fade_material(source)
		fade_materials.append(fade_material)

	mesh.material_override = null
	for surface: int in fade_materials.size():
		mesh.set_surface_override_material(surface, fade_materials[surface])

	_active_meshes[id] = {
		"mesh": mesh,
		"wanted": true,
		"amount": 0.0,
		"original_material_override": original_override,
		"original_surface_overrides": original_surface_overrides,
		"fade_materials": fade_materials,
	}


func _get_effective_material(mesh: MeshInstance3D, surface: int, original_override: Material) -> Material:
	if original_override != null:
		return original_override
	var surface_override := mesh.get_surface_override_material(surface)
	if surface_override != null:
		return surface_override
	return mesh.mesh.surface_get_material(surface)


func _make_fade_material(source: Material) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = OCCLUDER_SHADER
	if source is StandardMaterial3D:
		var standard := source as StandardMaterial3D
		material.set_shader_parameter("albedo_color", standard.albedo_color)
		material.set_shader_parameter("albedo_texture", standard.albedo_texture)
		material.set_shader_parameter("use_albedo_texture", standard.albedo_texture != null)
		material.set_shader_parameter("metallic", standard.metallic)
		material.set_shader_parameter("roughness", standard.roughness)
		material.set_shader_parameter("specular", standard.metallic_specular)
		material.set_shader_parameter("emission_color", standard.emission)
		material.set_shader_parameter("emission_energy", standard.emission_energy_multiplier if standard.emission_enabled else 0.0)
		material.set_shader_parameter("normal_texture", standard.normal_texture)
		material.set_shader_parameter("use_normal_texture", standard.normal_texture != null)
		material.set_shader_parameter("normal_scale", standard.normal_scale)
	return material


func _update_transparency_materials(state: Dictionary) -> void:
	for material: ShaderMaterial in state["fade_materials"]:
		material.set_shader_parameter("fade_amount", state["amount"])
		material.set_shader_parameter("transparency_amount", transparency_amount)


func _restore_mesh_materials(state: Dictionary) -> void:
	var mesh := state.get("mesh") as MeshInstance3D
	if not is_instance_valid(mesh):
		return
	mesh.material_override = state.get("original_material_override") as Material
	var originals: Array = state.get("original_surface_overrides", [])
	for surface: int in originals.size():
		mesh.set_surface_override_material(surface, originals[surface] as Material)
