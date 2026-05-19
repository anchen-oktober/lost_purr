extends CharacterBody3D

@export var id: String = "npc"
@export var character_name: String = "\u041D\u0435\u0437\u043D\u0430\u043A\u043E\u043C\u0435\u0446"
@export_enum("\u0427\u0435\u043B\u043E\u0432\u0435\u043A", "\u041A\u043E\u0442", "\u0421\u043E\u0431\u0430\u043A\u0430", "\u041F\u0442\u0438\u0446\u0430", "\u041A\u0440\u044B\u0441\u0430", "\u0422\u0435\u043D\u044C") var character_type: int = CharacterJournalManager.CharacterType.HUMAN
@export_enum("Friendly", "Neutral", "Hostile") var attitude: int = CharacterJournalManager.CharacterAttitude.NEUTRAL
@export var short_phrase: String = "\u041C\u0440\u0440?"
@export_multiline var dialogue: String = "\u041E\u043D \u0441\u043C\u043E\u0442\u0440\u0438\u0442 \u043D\u0430 \u043A\u043E\u0442\u0430 \u0438 \u043C\u043E\u043B\u0447\u0438\u0442."
@export_multiline var description: String = "\u0422\u0438\u0445\u0438\u0439 \u0436\u0438\u0442\u0435\u043B\u044C \u044D\u0442\u043E\u0439 \u0443\u043B\u0438\u0446\u044B."
@export var icon: Texture2D
@export var voice_sound: AudioStream
@export var can_be_purred: bool = true
@export var highlight_color: Color = Color(0.85, 0.95, 1.0, 1.0)

var is_known: bool = false
var player_is_near: bool = false
var base_light_energy: float = 0.0
var pulse_time: float = 0.0

@onready var visual: MeshInstance3D = $Visual
@onready var interaction_area: Area3D = $InteractionArea
@onready var glow_light: OmniLight3D = $GlowLight
@onready var voice_player: AudioStreamPlayer3D = $VoicePlayer

func _ready() -> void:
	attitude = _validate_attitude(attitude)
	var saved_data: Dictionary = CharacterJournalManager.get_character(id)
	if not saved_data.is_empty():
		attitude = _validate_attitude(int(saved_data.get("attitude", attitude)))
		is_known = bool(saved_data.get("is_known", false))
	interaction_area.body_entered.connect(player_entered)
	interaction_area.body_exited.connect(player_exited)
	_prepare_visual_material()
	base_light_energy = glow_light.light_energy
	glow_light.light_color = highlight_color
	highlight_off()

func _process(delta: float) -> void:
	if not player_is_near:
		return

	pulse_time += delta
	var pulse: float = 0.45 + sin(pulse_time * 2.0) * 0.2
	glow_light.light_energy = base_light_energy + pulse
	_update_material(0.25 + pulse * 0.14)

func player_entered(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return

	player_is_near = true
	highlight_on()
	CharacterJournalManager.set_nearby_npc(self)

func player_exited(body: Node3D) -> void:
	if not body is CharacterBody3D:
		return

	player_is_near = false
	highlight_off()
	CharacterJournalManager.clear_nearby_npc(self)

func interact() -> void:
	is_known = true
	CharacterJournalManager.register_character(get_character_data())
	show_phrase()
	start_dialogue()

func show_phrase() -> void:
	if voice_sound != null:
		voice_player.stream = voice_sound
		voice_player.play()

func start_dialogue() -> void:
	if CharacterJournalManager.journal_ui != null:
		CharacterJournalManager.journal_ui.show_character_popup(get_character_data())

func change_attitude(new_attitude: int) -> void:
	attitude = _validate_attitude(new_attitude)
	CharacterJournalManager.update_character_attitude(id, attitude)

func receive_purr() -> void:
	if not can_be_purred:
		return
	if attitude != CharacterJournalManager.CharacterAttitude.NEUTRAL:
		return
	if character_type != CharacterJournalManager.CharacterType.CAT and character_type != CharacterJournalManager.CharacterType.HUMAN:
		return

	change_attitude(CharacterJournalManager.CharacterAttitude.FRIENDLY)
	short_phrase = "\u0422\u044B \u0442\u043E\u0436\u0435 \u0435\u0433\u043E \u0438\u0449\u0435\u0448\u044C?"
	dialogue = "\u041C\u0443\u0440\u0447\u0430\u043D\u0438\u0435 \u0434\u0435\u043B\u0430\u0435\u0442 \u0442\u0438\u0448\u0438\u043D\u0443 \u043C\u044F\u0433\u0447\u0435. \u041A\u0430\u0436\u0435\u0442\u0441\u044F, \u044D\u0442\u043E\u0442 \u0436\u0438\u0442\u0435\u043B\u044C \u0442\u0435\u043F\u0435\u0440\u044C \u0434\u043E\u0432\u0435\u0440\u044F\u0435\u0442 \u043A\u043E\u0442\u0443."
	CharacterJournalManager.register_character(get_character_data())
	start_dialogue()

func get_character_data() -> Dictionary:
	return {
		"id": id,
		"character_name": character_name,
		"character_type": character_type,
		"attitude": attitude,
		"short_phrase": short_phrase,
		"dialogue": dialogue,
		"description": description,
		"portrait": icon.resource_path if icon != null else "",
		"icon": icon.resource_path if icon != null else "",
		"is_known": true,
		"is_friendly": attitude == CharacterJournalManager.CharacterAttitude.FRIENDLY,
		"world_position": {
			"x": global_position.x,
			"y": global_position.y,
			"z": global_position.z,
		},
		"voice_sound": voice_sound.resource_path if voice_sound != null else "",
		"can_be_purred": can_be_purred,
	}

func highlight_on() -> void:
	pulse_time = 0.0
	glow_light.visible = true

func highlight_off() -> void:
	glow_light.light_energy = base_light_energy
	_update_material(0.18)

func _validate_attitude(value: int) -> int:
	match character_type:
		CharacterJournalManager.CharacterType.CAT:
			if value == CharacterJournalManager.CharacterAttitude.HOSTILE:
				return CharacterJournalManager.CharacterAttitude.NEUTRAL
		CharacterJournalManager.CharacterType.BIRD, CharacterJournalManager.CharacterType.RAT:
			if value == CharacterJournalManager.CharacterAttitude.FRIENDLY:
				return CharacterJournalManager.CharacterAttitude.NEUTRAL
		CharacterJournalManager.CharacterType.DEMON:
			return CharacterJournalManager.CharacterAttitude.HOSTILE
	return value

func _prepare_visual_material() -> void:
	var source_material: Material = visual.get_surface_override_material(0)
	if source_material == null:
		return

	var material: StandardMaterial3D = source_material.duplicate() as StandardMaterial3D
	if material == null:
		return

	visual.set_surface_override_material(0, material)
	_update_material(0.18)

func _update_material(emission_energy: float) -> void:
	var material: StandardMaterial3D = visual.get_surface_override_material(0) as StandardMaterial3D
	if material == null:
		return

	material.emission = highlight_color
	material.emission_energy_multiplier = emission_energy
