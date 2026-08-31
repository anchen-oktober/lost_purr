extends Area3D
class_name MemoryInteractable
@export var stage_id := ""
@export var controller: MemorySequenceController
@export var activation_sound: AudioStream
@export var error_sound: AudioStream
@export var interaction_enabled := true
func _ready() -> void:
	body_entered.connect(_entered); body_exited.connect(_exited)
func _entered(body: Node3D) -> void:
	if body.name == "PlayerCat": JournalManager.set_nearby_object(self)
func _exited(body: Node3D) -> void:
	if body.name == "PlayerCat": JournalManager.clear_nearby_object(self)
func interact() -> void:
	if not interaction_enabled: return
	if controller == null: return
	var stream := activation_sound if controller.try_fragment(stage_id) else error_sound
	if stream != null:
		var player := AudioStreamPlayer3D.new()
		player.stream = stream
		add_child(player)
		player.play()

func is_interaction_available() -> bool:
	return interaction_enabled
