extends Node3D

@export var max_alpha: float = 0.72
@export var max_emission: float = 1.6
@export var id: String = "memory_footprints_path"
@export var title: String = "\u0426\u0435\u043F\u043E\u0447\u043A\u0430 \u0441\u043B\u0435\u0434\u043E\u0432"
@export_multiline var short_description: String = "\u0421\u043B\u0435\u0434\u044B \u0432\u0435\u0434\u0443\u0442 \u043A \u0442\u0438\u0445\u043E\u0439 \u0447\u0430\u0441\u0442\u0438 \u0443\u043B\u0438\u0446\u044B."
@export_multiline var full_description: String = "\u0426\u0435\u043F\u043E\u0447\u043A\u0430 \u0441\u043B\u0435\u0434\u043E\u0432 \u043F\u0440\u043E\u0441\u0442\u0443\u043F\u0430\u0435\u0442 \u0442\u043E\u043B\u044C\u043A\u043E \u0432 \u043A\u043E\u0448\u0430\u0447\u044C\u0435\u043C \u0437\u0440\u0435\u043D\u0438\u0438. \u041E\u043D\u0438 \u0438\u0434\u0443\u0442 \u043F\u043E \u0434\u043E\u0440\u043E\u0433\u0435 \u0443\u0432\u0435\u0440\u0435\u043D\u043D\u043E, \u0431\u0443\u0434\u0442\u043E \u0438\u0445 \u043E\u0441\u0442\u0430\u0432\u0438\u043B \u0442\u043E\u0442, \u043A\u0442\u043E \u0437\u043D\u0430\u043B, \u043A\u0443\u0434\u0430 \u0438\u0434\u0442\u0438."

var footprint_material: StandardMaterial3D
var player_is_near: bool = false
var is_collected: bool = false
var cat_vision_amount: float = 0.0

@onready var interact_area: Area3D = get_node_or_null("InteractArea") as Area3D
@onready var interaction_shape: CollisionShape3D = get_node_or_null("InteractArea/CollisionShape3D") as CollisionShape3D

func _ready() -> void:
	add_to_group("cat_vision_revealed")
	if interact_area != null:
		interact_area.body_entered.connect(player_entered)
		interact_area.body_exited.connect(player_exited)
	is_collected = JournalManager.is_collected(id)
	_prepare_fade_material()
	set_cat_vision_amount(0.0)

func set_cat_vision_amount(amount: float) -> void:
	cat_vision_amount = clampf(amount, 0.0, 1.0)
	var is_revealed: bool = cat_vision_amount > 0.08
	visible = cat_vision_amount > 0.01
	if interact_area != null:
		interact_area.monitoring = is_revealed
		interact_area.monitorable = is_revealed
	if interaction_shape != null:
		interaction_shape.set_deferred("disabled", not is_revealed)

	if footprint_material == null:
		return

	var color: Color = footprint_material.albedo_color
	color.a = max_alpha * cat_vision_amount
	footprint_material.albedo_color = color
	footprint_material.emission_energy_multiplier = max_emission * cat_vision_amount

	if not is_revealed and player_is_near:
		force_hide_cat_vision_prompt()
	elif is_revealed and not player_is_near:
		_check_overlapping_player()

func player_entered(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return

	player_is_near = true
	JournalManager.set_nearby_object(self)

func player_exited(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return

	force_hide_cat_vision_prompt()

func interact() -> void:
	is_collected = true
	JournalManager.collect_entry(_get_memory_data())

func force_hide_cat_vision_prompt() -> void:
	player_is_near = false
	JournalManager.clear_nearby_object(self)

func _prepare_fade_material() -> void:
	var source_material: Material = null

	for child in get_children():
		if child is MeshInstance3D:
			var footprint: MeshInstance3D = child as MeshInstance3D
			source_material = footprint.get_surface_override_material(0)
			break

	if source_material == null:
		return

	footprint_material = source_material.duplicate() as StandardMaterial3D
	footprint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	for child in get_children():
		if child is MeshInstance3D:
			var footprint: MeshInstance3D = child as MeshInstance3D
			footprint.set_surface_override_material(0, footprint_material)

func _get_memory_data() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"short_description": short_description,
		"full_description": full_description,
		"category": JournalManager.MemoryType.TRACE,
		"icon": "",
		"is_collected": is_collected,
		"requires_cat_vision": true,
		"world_position": {
			"x": global_position.x,
			"y": global_position.y,
			"z": global_position.z,
		},
		"highlight_color": Color(0.35, 1.0, 0.82, 1.0).to_html(),
		"sound_effect": "",
	}

func _check_overlapping_player() -> void:
	if interact_area == null:
		return

	for body: Node3D in interact_area.get_overlapping_bodies():
		if body is CharacterBody3D:
			player_entered(body)
			return
