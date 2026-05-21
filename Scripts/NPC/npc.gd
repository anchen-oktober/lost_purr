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
@export var patrol_enabled: bool = true
@export var patrol_radius: float = 4.0
@export var patrol_speed: float = 1.15
@export var patrol_wait_min: float = 1.2
@export var patrol_wait_max: float = 3.4
@export var random_phrases: Array[String] = []

var is_known: bool = false
var player_is_near: bool = false
var base_light_energy: float = 0.0
var pulse_time: float = 0.0
var spawn_position: Vector3
var patrol_target: Vector3
var patrol_wait_time: float = 0.0
var random: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var billboard: Sprite3D = $Billboard
@onready var interaction_area: Area3D = $InteractionArea
@onready var glow_light: OmniLight3D = $GlowLight
@onready var voice_player: AudioStreamPlayer3D = $VoicePlayer

func _ready() -> void:
	random.randomize()
	spawn_position = global_position
	patrol_target = global_position
	attitude = _validate_attitude(attitude)
	var saved_data: Dictionary = CharacterJournalManager.get_character(id)
	if not saved_data.is_empty():
		attitude = _validate_attitude(int(saved_data.get("attitude", attitude)))
		is_known = bool(saved_data.get("is_known", false))
	interaction_area.body_entered.connect(player_entered)
	interaction_area.body_exited.connect(player_exited)
	if icon != null:
		billboard.texture = icon
	base_light_energy = glow_light.light_energy
	glow_light.light_color = highlight_color
	highlight_off()
	_choose_new_patrol_target()

func _process(delta: float) -> void:
	if not player_is_near:
		return

	pulse_time += delta
	var pulse: float = 0.45 + sin(pulse_time * 2.0) * 0.2
	glow_light.light_energy = base_light_energy + pulse

func _physics_process(delta: float) -> void:
	if player_is_near or not patrol_enabled:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	if patrol_wait_time > 0.0:
		patrol_wait_time -= delta
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var direction: Vector3 = patrol_target - global_position
	direction.y = 0.0
	if direction.length() <= 0.18:
		velocity = Vector3.ZERO
		patrol_wait_time = random.randf_range(patrol_wait_min, patrol_wait_max)
		_choose_new_patrol_target()
		move_and_slide()
	else:
		direction = direction.normalized()
		velocity.x = direction.x * patrol_speed
		velocity.z = direction.z * patrol_speed
		move_and_slide()

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

func show_phrase() -> void:
	var phrase: String = _get_random_phrase()
	if CharacterJournalManager.journal_ui != null and CharacterJournalManager.journal_ui.has_method("show_world_text_for_node"):
		CharacterJournalManager.journal_ui.show_world_text_for_node(phrase, self)

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
	show_phrase()

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

func _choose_new_patrol_target() -> void:
	var angle: float = random.randf_range(0.0, TAU)
	var distance: float = random.randf_range(1.0, patrol_radius)
	patrol_target = spawn_position + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)

func _get_random_phrase() -> String:
	var phrases: Array[String] = random_phrases
	if phrases.is_empty():
		phrases = _get_default_phrases()
	if phrases.is_empty():
		return short_phrase

	var index: int = random.randi_range(0, phrases.size() - 1)
	return phrases[index]

func _get_default_phrases() -> Array[String]:
	match attitude:
		CharacterJournalManager.CharacterAttitude.FRIENDLY:
			return [
				"\u0422\u044B \u0442\u043E\u0436\u0435 \u0435\u0433\u043E \u0438\u0449\u0435\u0448\u044C?",
				"\u042F \u0432\u0438\u0434\u0435\u043B \u0441\u0442\u0440\u0430\u043D\u043D\u044B\u0439 \u0441\u0432\u0435\u0442 \u0443 \u043C\u0435\u0442\u0440\u043E.",
				"\u0411\u0443\u0434\u044C \u043E\u0441\u0442\u043E\u0440\u043E\u0436\u0435\u043D.",
			]
		CharacterJournalManager.CharacterAttitude.HOSTILE:
			return [
				"\u041D\u0435 \u043F\u043E\u0434\u0445\u043E\u0434\u0438.",
				"\u0413\u0430\u0432!",
				"\u041A\u0430\u0440-\u0440-\u0440!",
			]
	return [
		short_phrase,
		"\u041E\u0442\u0441\u0442\u0430\u043D\u044C.",
		"\u041C\u043D\u0435 \u043D\u0435\u043A\u043E\u0433\u0434\u0430.",
	]

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
