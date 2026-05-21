extends Area3D

@export var id: String = "memory_object"
@export var title: String = "\u041D\u0435\u0438\u0437\u0432\u0435\u0441\u0442\u043D\u043E\u0435 \u0432\u043E\u0441\u043F\u043E\u043C\u0438\u043D\u0430\u043D\u0438\u0435"
@export_multiline var short_description: String = "\u0422\u0438\u0445\u0430\u044F \u0441\u0442\u0440\u0430\u043D\u043D\u043E\u0441\u0442\u044C \u043D\u0430 \u043A\u0440\u0430\u044E \u0432\u043D\u0438\u043C\u0430\u043D\u0438\u044F."
@export_multiline var full_description: String = "\u041A\u043E\u0442 \u043E\u0441\u0442\u0430\u043D\u0430\u0432\u043B\u0438\u0432\u0430\u0435\u0442\u0441\u044F \u0438 \u043F\u0440\u0438\u0441\u043B\u0443\u0448\u0438\u0432\u0430\u0435\u0442\u0441\u044F. \u0417\u0434\u0435\u0441\u044C \u043E\u0441\u0442\u0430\u043B\u043E\u0441\u044C \u0447\u0442\u043E-\u0442\u043E \u0432\u0430\u0436\u043D\u043E\u0435."
@export_enum("\u0417\u0430\u043F\u0430\u0445", "\u0421\u043B\u0435\u0434", "\u041F\u0440\u0435\u0434\u043C\u0435\u0442", "\u0421\u0438\u043C\u0432\u043E\u043B", "\u041C\u0435\u0441\u0442\u043E", "\u0410\u043D\u043E\u043C\u0430\u043B\u0438\u044F") var category: int = 2
@export var icon: Texture2D
@export var highlight_color: Color = Color(1.0, 0.78, 0.42, 1.0)
@export var sound_effect: AudioStream

var is_collected: bool = false
var player_is_near: bool = false
var base_light_energy: float = 0.0
var pulse_time: float = 0.0
var cat_vision_amount: float = 1.0

@onready var visual: MeshInstance3D = $Visual
@onready var interaction_shape: CollisionShape3D = $CollisionShape3D
@onready var glow_light: OmniLight3D = $GlowLight
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

func _ready() -> void:
	body_entered.connect(player_entered)
	body_exited.connect(player_exited)
	_prepare_visual_material()
	is_collected = JournalManager.is_collected(id)
	base_light_energy = glow_light.light_energy
	glow_light.light_color = highlight_color
	_update_material(0.25)
	highlight_off()
	if is_in_group("cat_vision_revealed"):
		set_cat_vision_amount(0.0)

func _process(delta: float) -> void:
	if not player_is_near:
		return

	pulse_time += delta
	var pulse: float = 0.65 + sin(pulse_time * 2.4) * 0.25
	glow_light.light_energy = (base_light_energy + pulse) * cat_vision_amount
	_update_material((0.55 + pulse * 0.18) * cat_vision_amount)

func player_entered(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return

	player_is_near = true
	highlight_on()
	JournalManager.set_nearby_object(self)

func player_exited(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return

	player_is_near = false
	highlight_off()
	JournalManager.clear_nearby_object(self)

func interact() -> void:
	is_collected = true
	if sound_effect != null:
		audio_player.stream = sound_effect
		audio_player.play()

	JournalManager.collect_entry(_get_memory_data())

func highlight_on() -> void:
	pulse_time = 0.0
	glow_light.visible = true

func highlight_off() -> void:
	glow_light.light_energy = base_light_energy * cat_vision_amount
	_update_material(0.25 * cat_vision_amount)

func set_cat_vision_amount(amount: float) -> void:
	cat_vision_amount = clampf(amount, 0.0, 1.0)
	var is_revealed: bool = cat_vision_amount > 0.08
	visible = cat_vision_amount > 0.01
	monitoring = is_revealed
	monitorable = is_revealed
	interaction_shape.set_deferred("disabled", not is_revealed)

	if not is_revealed and player_is_near:
		force_hide_cat_vision_prompt()
	elif is_revealed and not player_is_near:
		_check_overlapping_player()

	if player_is_near:
		highlight_on()
	else:
		highlight_off()

func force_hide_cat_vision_prompt() -> void:
	player_is_near = false
	highlight_off()
	JournalManager.clear_nearby_object(self)

func _get_memory_data() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"short_description": short_description,
		"full_description": full_description,
		"category": category,
		"icon": icon.resource_path if icon != null else "",
		"is_collected": is_collected,
		"requires_cat_vision": is_in_group("cat_vision_revealed"),
		"world_position": {
			"x": global_position.x,
			"y": global_position.y,
			"z": global_position.z,
		},
		"highlight_color": highlight_color.to_html(),
		"sound_effect": sound_effect.resource_path if sound_effect != null else "",
	}

func _update_material(emission_energy: float) -> void:
	var material: StandardMaterial3D = visual.get_surface_override_material(0) as StandardMaterial3D
	if material == null:
		return

	material.emission = highlight_color
	material.emission_energy_multiplier = emission_energy
	if is_in_group("cat_vision_revealed"):
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var color: Color = material.albedo_color
		color.a = cat_vision_amount
		material.albedo_color = color

func _prepare_visual_material() -> void:
	var source_material: Material = visual.get_surface_override_material(0)
	if source_material == null:
		return

	var material: StandardMaterial3D = source_material.duplicate() as StandardMaterial3D
	if material == null:
		return

	visual.set_surface_override_material(0, material)

func _check_overlapping_player() -> void:
	for body in get_overlapping_bodies():
		if body is CharacterBody3D:
			player_entered(body)
			return
