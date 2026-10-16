@tool
extends Node3D

## Controls both the visible lamp and healing, including changes during play.
@export var light_enabled: bool = true:
	set(value):
		light_enabled = value
		_apply_light_state()
## Calmness (HP) restored per second while the cat is inside the light.
@export_range(0.0, 100.0, 0.1, "or_greater") var restore_per_second: float = 5.0
@export_range(0.1, 20.0, 0.1, "or_greater") var trigger_radius: float = 3.0:
	set(value):
		trigger_radius = maxf(value, 0.1)
		_update_trigger_radius()
@export var light_path: NodePath = ^"WarmGlow"
@export var head_path: NodePath = ^"LampHead"

var _head_materials: Array[StandardMaterial3D] = []
var _emission_enabled: Array[bool] = []

func _ready() -> void:
	refresh_lamp()
	set_physics_process(not Engine.is_editor_hint())

func refresh_lamp() -> void:
	_head_materials.clear()
	_emission_enabled.clear()
	# Materials are shared by many lamps: only change this lamp's copies.
	var head := get_node_or_null(head_path) as MeshInstance3D
	if head != null and head.mesh != null:
		for surface in range(head.mesh.get_surface_count()):
			var original := head.get_active_material(surface) as StandardMaterial3D
			if original == null:
				continue
			var material := original.duplicate() as StandardMaterial3D
			if head.material_override != null:
				head.material_override = material
			else:
				head.set_surface_override_material(surface, material)
			_head_materials.append(material)
			_emission_enabled.append(original.emission_enabled)
	_update_trigger_radius()
	_apply_light_state()

func _physics_process(delta: float) -> void:
	if not light_enabled or not is_visible_in_tree() or restore_per_second <= 0.0:
		return
	var area := get_node_or_null("TriggerArea") as Area3D
	if area == null:
		return
	for body in area.get_overlapping_bodies():
		if body.name != "PlayerCat" or not body.has_method("restore_fear"):
			continue
		if body.has_method("can_receive_positive_restore") and not body.call("can_receive_positive_restore"):
			continue
		# The player clamps restoration to its maximum calmness.
		body.call("restore_fear", maxf(restore_per_second, 0.0) * delta)

func _apply_light_state() -> void:
	var light := get_node_or_null(light_path) as Light3D
	if light != null:
		light.visible = light_enabled
	for index in range(_head_materials.size()):
		_head_materials[index].emission_enabled = light_enabled and _emission_enabled[index]

func _update_trigger_radius() -> void:
	var collision := get_node_or_null("TriggerArea/CollisionShape3D") as CollisionShape3D
	if collision == null:
		return
	# Keep each lamp's Inspector radius independent of shared scene resources.
	var shape := SphereShape3D.new()
	shape.radius = trigger_radius
	collision.shape = shape
