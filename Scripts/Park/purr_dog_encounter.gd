extends Area3D
class_name PurrDogEncounter
@export var activation_radius := 4.0
@export var calm_duration := 10.0
@export var one_shot := true
@export var human_dialogue_id := ""
@export var dog_fear_zone: NodePath
@export var dog_bark_sound: AudioStream
var _player_inside := false
var _resolved := false
func _ready() -> void:
	body_entered.connect(_entered); body_exited.connect(_exited)
	CharacterJournalManager.purr_started.connect(_on_purr)
func _entered(body: Node3D) -> void:
	if body.name != "PlayerCat" or _resolved: return
	_player_inside = true
	if dog_bark_sound != null:
		var player := AudioStreamPlayer3D.new(); player.stream = dog_bark_sound; add_child(player); player.play()
func _exited(body: Node3D) -> void:
	if body.name == "PlayerCat": _player_inside = false
func _on_purr(_player: Node3D) -> void:
	if not _player_inside or _resolved: return
	_resolved = true
	var zone := get_node_or_null(dog_fear_zone)
	if zone != null: zone.set_deferred("monitoring", false)
	if journal_entry_id() != "": JournalManager.mark_park_event_triggered(journal_entry_id())
	if not one_shot:
		await get_tree().create_timer(calm_duration).timeout
		_resolved = false
		if zone != null: zone.set_deferred("monitoring", true)
func journal_entry_id() -> String: return "park_dog_calmed_" + name.to_snake_case()
