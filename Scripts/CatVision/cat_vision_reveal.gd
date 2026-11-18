extends Node3D
class_name CatVisionReveal

@export var visible_only_in_cat_vision: bool = true
@export var normal_visibility: bool = false
@export var cat_vision_visibility: bool = true
@export var highlight_color: Color = Color(1.0, 0.76, 0.32, 0.85)
@export var reveal_sound: AudioStream
@export_enum("OwnerAura", "StrangeAura", "HiddenClue", "SilentShadowHint", "FalseTrail") var reveal_type: int = 0
@export var max_alpha: float = 0.7
@export var max_emission: float = 1.5
@export var max_light_energy: float = 0.85

@export_category("Chapter 1 interaction")
@export var interaction_id: String = ""
@export var required_quest_id: String = ""
@export var interaction_radius: float = 2.5
@export var requires_cat_vision_for_interaction: bool = false
@export var one_shot_interaction: bool = true
@export var interaction_hint: String = "E — Исследовать"
@export_multiline var cat_vision_required_hint: String = "Удерживай Q, чтобы использовать кошачье зрение"

var _materials: Array[StandardMaterial3D] = []
var _lights: Array[Light3D] = []
var _audio_player: AudioStreamPlayer3D
var _was_visible: bool = false
var _interaction_area: Area3D
var _player_inside_interaction: bool = false
var _interaction_completed: bool = false
var _last_prompt: String = ""

func _ready() -> void:
	add_to_group("cat_vision_revealed")
	_audio_player = get_node_or_null("RevealSound") as AudioStreamPlayer3D
	_prepare_targets(self)
	set_cat_vision_amount(0.0)
	_ensure_interaction_area()

func _process(_delta: float) -> void:
	if interaction_id.is_empty() or _interaction_completed:
		return
	if _interaction_area != null and not _player_inside_interaction:
		for body in _interaction_area.get_overlapping_bodies():
			if _is_player(body):
				_on_interaction_body_entered(body as Node3D)
				break
	_refresh_interaction_prompt()

func set_cat_vision_amount(amount: float) -> void:
	var reveal_amount := clampf(amount, 0.0, 1.0)
	var is_revealed := reveal_amount > 0.08
	var should_be_visible := cat_vision_visibility if is_revealed else normal_visibility
	visible = should_be_visible

	if reveal_sound != null and is_revealed and not _was_visible and _audio_player != null:
		_audio_player.stream = reveal_sound
		_audio_player.play()
	_was_visible = is_revealed

	for material in _materials:
		var color := material.albedo_color
		color.a = max_alpha * reveal_amount if visible_only_in_cat_vision else lerpf(0.25, max_alpha, reveal_amount)
		material.albedo_color = color
		material.emission_enabled = true
		material.emission = highlight_color
		material.emission_energy_multiplier = max_emission * reveal_amount

	for light in _lights:
		light.light_color = highlight_color
		light.light_energy = max_light_energy * reveal_amount
	_refresh_interaction_prompt()

func interact() -> void:
	if not _can_offer_interaction():
		_print_interaction_blocked("the player is out of range or the required quest is not active")
		return
	if requires_cat_vision_for_interaction and not _is_cat_vision_active():
		_print_interaction_blocked("Cat Vision (Q) is not active")
		_show_story_hint(cat_vision_required_hint)
		return

	var quest_manager := _find_quest_manager()
	if quest_manager == null or not quest_manager.has_method("handle_quest_object_interaction"):
		_print_interaction_blocked("Chapter1QuestManager is unavailable")
		return

	print("[INTERACTION] %s: E pressed" % name)
	var was_handled := bool(quest_manager.call("handle_quest_object_interaction", interaction_id, self))
	if not was_handled:
		_print_interaction_blocked("story event rejected the interaction")
		return

	_interaction_completed = true
	JournalManager.clear_nearby_object(self)
	_last_prompt = ""
	if _interaction_area != null:
		_interaction_area.set_deferred("monitoring", false)
	print("[INTERACTION] %s: completed" % name)

func is_interaction_available() -> bool:
	return _can_offer_interaction()

func get_interaction_prompt() -> String:
	if requires_cat_vision_for_interaction and not _is_cat_vision_active():
		return cat_vision_required_hint
	return interaction_hint

func _ensure_interaction_area() -> void:
	if interaction_id.is_empty():
		return
	_interaction_area = Area3D.new()
	_interaction_area.name = "QuestInteractionArea"
	_interaction_area.collision_layer = 0
	_interaction_area.collision_mask = 1
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var sphere := SphereShape3D.new()
	sphere.radius = maxf(interaction_radius, 0.1)
	shape.shape = sphere
	_interaction_area.add_child(shape)
	add_child(_interaction_area)
	_interaction_area.body_entered.connect(_on_interaction_body_entered)
	_interaction_area.body_exited.connect(_on_interaction_body_exited)

func _on_interaction_body_entered(body: Node3D) -> void:
	if not _is_player(body):
		return
	_player_inside_interaction = true
	print("[INTERACTION] %s: in range" % name)
	_refresh_interaction_prompt()

func _on_interaction_body_exited(body: Node3D) -> void:
	if not _is_player(body):
		return
	_player_inside_interaction = false
	_last_prompt = ""
	JournalManager.clear_nearby_object(self)

func _refresh_interaction_prompt() -> void:
	if not _player_inside_interaction or not _can_offer_interaction():
		if JournalManager.nearby_object == self:
			JournalManager.clear_nearby_object(self)
		return
	var next_prompt := get_interaction_prompt()
	if next_prompt == _last_prompt and JournalManager.nearby_object == self:
		return
	_last_prompt = next_prompt
	JournalManager.set_nearby_object(self)
	_show_story_hint(next_prompt)

func _can_offer_interaction() -> bool:
	if interaction_id.is_empty() or (one_shot_interaction and _interaction_completed):
		return false
	if not _player_inside_interaction:
		return false
	if required_quest_id.is_empty():
		return true
	var quest_manager := _find_quest_manager()
	return quest_manager != null and quest_manager.has_method("is_quest_active") and bool(quest_manager.call("is_quest_active", required_quest_id))

func _is_cat_vision_active() -> bool:
	var manager := get_tree().current_scene.find_child("CatVisionManager", true, false) if get_tree().current_scene != null else null
	return manager != null and manager.has_method("get_cat_state") and int(manager.call("get_cat_state")) == 1

func _find_quest_manager() -> Node:
	var scene := get_tree().current_scene
	return scene.find_child("Chapter1QuestManager", true, false) if scene != null else null

func _show_story_hint(text: String) -> void:
	var quest_manager := _find_quest_manager()
	if quest_manager != null and quest_manager.has_method("show_context_hint"):
		quest_manager.call("show_context_hint", text)

func _print_interaction_blocked(reason: String) -> void:
	print("[INTERACTION] %s BLOCKED\nReason: %s" % [name, reason])

func _is_player(body: Node) -> bool:
	return body != null and (body.name == "PlayerCat" or body.is_in_group("player"))

func _prepare_targets(root: Node) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			_prepare_mesh(child as MeshInstance3D)
		elif child is Light3D:
			_lights.append(child as Light3D)
		_prepare_targets(child)

func _prepare_mesh(mesh_instance: MeshInstance3D) -> void:
	var source_material := mesh_instance.get_surface_override_material(0)
	if source_material == null:
		source_material = StandardMaterial3D.new()

	var material := source_material.duplicate() as StandardMaterial3D
	if material == null:
		return

	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = highlight_color
	mesh_instance.set_surface_override_material(0, material)
	_materials.append(material)
