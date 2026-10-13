extends Area3D
class_name ParkMemoryTrigger
signal memory_played(event_id: String)
@export var event_id := ""
@export var trigger_once := true
@export var require_cat_vision := false
@export var audio: AudioStream
@export var visual_memory_scene: PackedScene
@export var duration := 3.0
@export var journal_entry_id := ""
@export_multiline var journal_title := "A Fading Memory"
@export_multiline var journal_description := "A brief trace of the human remains here."
var _playing := false
func _ready() -> void: body_entered.connect(_on_body_entered)
func _on_body_entered(body: Node3D) -> void:
	if body.name == "PlayerCat": play_memory()
func play_memory() -> void:
	if _playing or (trigger_once and JournalManager.is_park_event_triggered(event_id)): return
	if require_cat_vision and not _is_cat_vision_active(): return
	_playing = true
	JournalManager.mark_park_event_triggered(event_id)
	if event_id.begins_with("park_owner_trail"):
		JournalManager.set_park_flag("owner_trail_discovered")
	if event_id == "park_other_world": JournalManager.set_park_flag("other_world_memory_seen")
	if audio != null:
		var player := AudioStreamPlayer3D.new(); player.stream = audio; add_child(player); player.play()
	if visual_memory_scene != null:
		var visual := visual_memory_scene.instantiate(); add_child(visual)
		await get_tree().create_timer(duration).timeout
		if is_instance_valid(visual): visual.queue_free()
	if not journal_entry_id.is_empty(): JournalManager.collect_entry({"id": journal_entry_id, "title": journal_title, "short_description": journal_description, "full_description": journal_description, "category": JournalManager.MemoryType.PLACE})
	memory_played.emit(event_id); _playing = false
func _is_cat_vision_active() -> bool:
	var manager := get_tree().current_scene.find_child("CatVisionManager", true, false)
	return manager != null and manager.has_method("get_cat_state") and int(manager.call("get_cat_state")) == 1
