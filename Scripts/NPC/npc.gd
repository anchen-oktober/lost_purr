extends CharacterBody3D

@export var id: String = "npc"
@export var character_name: String = "Stranger"
@export_enum("Human", "Cat", "Dog", "Bird", "Rat", "Shadow") var character_type: int = CharacterJournalManager.CharacterType.HUMAN
@export_enum("Friendly", "Neutral", "Hostile") var attitude: int = CharacterJournalManager.CharacterAttitude.NEUTRAL
@export var short_phrase: String = "Mrr?"
@export_multiline var dialogue: String = "They look at the cat and say nothing."
@export_multiline var description: String = "A quiet resident of this street."
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
	short_phrase = "Are you looking for him too?"
	dialogue = "The purr softens the silence. It feels like this resident trusts the cat a little more now."
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
	match character_type:
		CharacterJournalManager.CharacterType.CAT:
			return _get_cat_phrases()
		CharacterJournalManager.CharacterType.HUMAN:
			return _get_human_phrases()
		CharacterJournalManager.CharacterType.DOG:
			return _get_dog_phrases()
		CharacterJournalManager.CharacterType.BIRD:
			return _get_bird_phrases()
		CharacterJournalManager.CharacterType.RAT:
			return _get_rat_phrases()
		CharacterJournalManager.CharacterType.DEMON:
			return _get_shadow_phrases()
	return [short_phrase]

func _get_cat_phrases() -> Array[String]:
	match attitude:
		CharacterJournalManager.CharacterAttitude.FRIENDLY:
			return [
				"Are you looking for him too?",
				"I know the roofs. I know the doors.",
				"Stay close to the warm lights.",
			]
	return [
		short_phrase,
		"Mrr?",
		"The street smells wrong tonight.",
	]

func _get_human_phrases() -> Array[String]:
	match attitude:
		CharacterJournalManager.CharacterAttitude.FRIENDLY:
			return [
				"Are you looking for him too?",
				"I saw a strange light near the metro.",
				"Be careful.",
			]
		CharacterJournalManager.CharacterAttitude.HOSTILE:
			return [
				"Do not come closer.",
				"Go away.",
				"This street is not safe.",
			]
	return [
		short_phrase,
		"Leave me alone.",
		"I do not have time.",
	]

func _get_dog_phrases() -> Array[String]:
	match attitude:
		CharacterJournalManager.CharacterAttitude.FRIENDLY:
			return [
				"Woof.",
				"I remember that scent.",
				"Stay behind me.",
			]
		CharacterJournalManager.CharacterAttitude.HOSTILE:
			return [
				"Woof!",
				"Do not come closer!",
				"Mine. This gate is mine.",
			]
	return [
		"Woof?",
		"Something passed here.",
		"I smell rain and fear.",
	]

func _get_bird_phrases() -> Array[String]:
	match attitude:
		CharacterJournalManager.CharacterAttitude.HOSTILE:
			return [
				"Caw-caw-caw!",
				"Too close!",
				"Eyes below, eyes below!",
			]
	return [
		"Caw.",
		"I saw movement where there should be none.",
		"The rooftops know.",
	]

func _get_rat_phrases() -> Array[String]:
	match attitude:
		CharacterJournalManager.CharacterAttitude.HOSTILE:
			return [
				"Back off.",
				"No cats in the pipes.",
				"I said go away.",
			]
	return [
		short_phrase,
		"I know the way under the street.",
		"Do not ask me. Not here.",
	]

func _get_shadow_phrases() -> Array[String]:
	return [
		"Do not come closer.",
		"You heard that in another place.",
		"The light is mistaken.",
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
