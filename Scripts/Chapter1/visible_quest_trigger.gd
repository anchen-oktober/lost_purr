@tool
extends Area3D
class_name VisibleQuestTrigger

@export var quest_id: String = ""
@export var trigger_once: bool = true
@export var only_player: bool = true
@export var show_hint_on_enter: bool = false
@export var hint_text: String = ""
@export var start_dialogue: bool = false
@export var dialogue_id: String = ""
@export var require_cat_vision: bool = false
@export var activate_objects: Array[NodePath] = []
@export var deactivate_objects: Array[NodePath] = []

@export var zone_size: Vector3 = Vector3(3.0, 2.0, 3.0):
	set(value):
		zone_size = value.max(Vector3(0.1, 0.1, 0.1))
		_refresh_editor_shape()
@export var debug_color: Color = Color(1.0, 0.78, 0.16, 0.32):
	set(value):
		debug_color = value
		_refresh_debug_material()
@export var hide_debug_in_game: bool = true

var _activated: bool = false
var _collision_shape: CollisionShape3D
var _debug_mesh: MeshInstance3D

func _ready() -> void:
	_ensure_visual_children()
	_refresh_editor_shape()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)
		if _debug_mesh != null and hide_debug_in_game:
			_debug_mesh.visible = false

func set_trigger_enabled(is_enabled: bool) -> void:
	monitoring = is_enabled
	monitorable = is_enabled
	if _collision_shape != null:
		_collision_shape.disabled = not is_enabled

func _on_body_entered(body: Node3D) -> void:
	if _activated and trigger_once:
		return
	if only_player and not _is_player(body):
		return
	if require_cat_vision and not _is_cat_vision_active():
		return

	_run_trigger()

func _on_body_exited(body: Node3D) -> void:
	if only_player and not _is_player(body):
		return

	var manager := _find_quest_manager()
	if manager != null and manager.has_method("hide_context_hint"):
		manager.call("hide_context_hint")

func _run_trigger() -> void:
	_activated = true
	_apply_object_visibility(activate_objects, true)
	_apply_object_visibility(deactivate_objects, false)

	var manager := _find_quest_manager()
	if manager != null:
		if quest_id != "" and manager.has_method("start_quest"):
			manager.call("start_quest", quest_id)
		if show_hint_on_enter and hint_text != "" and manager.has_method("show_hint"):
			manager.call("show_hint", hint_text)
		if start_dialogue:
			var target_dialogue := dialogue_id if dialogue_id != "" else quest_id
			if target_dialogue != "" and manager.has_method("start_dialogue"):
				manager.call("start_dialogue", target_dialogue)
	else:
		push_warning("%s cannot find Chapter1QuestManager." % name)

	if trigger_once:
		set_trigger_enabled(false)

func _apply_object_visibility(paths: Array[NodePath], is_visible: bool) -> void:
	for path in paths:
		var node := get_node_or_null(path)
		if node == null:
			push_warning("%s has missing NodePath: %s" % [name, path])
			continue
		if node is CanvasItem or node is Node3D:
			node.visible = is_visible
		node.process_mode = Node.PROCESS_MODE_INHERIT if is_visible else Node.PROCESS_MODE_DISABLED

func _is_player(body: Node) -> bool:
	if body == null:
		return false
	return body.name == "PlayerCat" or body.is_in_group("player") or body.is_in_group("Player")

func _is_cat_vision_active() -> bool:
	var current_scene := get_tree().current_scene
	var manager := current_scene.find_child("CatVisionManager", true, false) if current_scene != null else null
	if manager == null:
		return false
	if manager.has_method("get_cat_state"):
		return int(manager.call("get_cat_state")) == 1
	return bool(manager.get("is_cat_vision_enabled"))

func _find_quest_manager() -> Node:
	var node: Node = self
	while node != null:
		var manager := node.find_child("Chapter1QuestManager", true, false)
		if manager != null:
			return manager
		node = node.get_parent()

	var current_scene := get_tree().current_scene
	return current_scene.find_child("Chapter1QuestManager", true, false) if current_scene != null else null

func _ensure_visual_children() -> void:
	_collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if _collision_shape == null:
		_collision_shape = CollisionShape3D.new()
		_collision_shape.name = "CollisionShape3D"
		add_child(_collision_shape)
		if owner != null:
			_collision_shape.owner = owner
	if _collision_shape.shape == null:
		_collision_shape.shape = BoxShape3D.new()

	_debug_mesh = get_node_or_null("DebugMesh") as MeshInstance3D
	if _debug_mesh == null:
		_debug_mesh = MeshInstance3D.new()
		_debug_mesh.name = "DebugMesh"
		add_child(_debug_mesh)
		if owner != null:
			_debug_mesh.owner = owner
	if _debug_mesh.mesh == null:
		_debug_mesh.mesh = BoxMesh.new()

func _refresh_editor_shape() -> void:
	if not is_inside_tree() and _collision_shape == null:
		return
	_ensure_visual_children()
	var box_shape := _collision_shape.shape as BoxShape3D
	if box_shape != null:
		box_shape.size = zone_size
	var box_mesh := _debug_mesh.mesh as BoxMesh
	if box_mesh != null:
		box_mesh.size = zone_size
	_refresh_debug_material()

func _refresh_debug_material() -> void:
	if _debug_mesh == null:
		return
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = debug_color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	_debug_mesh.material_override = material
