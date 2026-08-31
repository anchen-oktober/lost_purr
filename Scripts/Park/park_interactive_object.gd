extends Area3D
class_name ParkInteractiveObject

## Small reusable Park object. It deliberately uses JournalManager's existing E prompt
## instead of owning input or adding a second interaction framework.
signal interacted(interaction_id: String)

@export_category("Identity")
@export var interaction_id := ""
@export var interaction_text := "Inspect"
@export_multiline var cat_reaction := ""
@export var one_shot := true
@export var requires_cat_vision := false
@export var cat_vision_only_visible := false
@export_category("Outcome")
@export var set_park_flag := ""
@export var required_park_flag := ""
@export var calm_delta := 0.0
@export var optional_dialogue: Array[String] = []
@export var activate_nodes: Array[NodePath] = []
@export var deactivate_nodes: Array[NodePath] = []
@export_category("Editor")
@export var debug_gameplay_marker := true

var _player_inside := false
var _used := false

func _ready() -> void:
	add_to_group("park_gameplay")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_used = not interaction_id.is_empty() and JournalManager.is_park_event_triggered(interaction_id)
	if cat_vision_only_visible:
		add_to_group("cat_vision_revealed")
		set_cat_vision_amount(0.0)

func _process(_delta: float) -> void:
	if _player_inside and requires_cat_vision and not _is_cat_vision_active():
		JournalManager.clear_nearby_object(self)

func _on_body_entered(body: Node3D) -> void:
	if body.name != "PlayerCat": return
	_player_inside = true
	if _can_interact(): JournalManager.set_nearby_object(self)

func _on_body_exited(body: Node3D) -> void:
	if body.name != "PlayerCat": return
	_player_inside = false
	JournalManager.clear_nearby_object(self)

func interact() -> void:
	if not _can_interact(): return
	_used = true
	if not interaction_id.is_empty(): JournalManager.mark_park_event_triggered(interaction_id)
	if not set_park_flag.is_empty(): JournalManager.set_park_flag(set_park_flag)
	if not is_zero_approx(calm_delta):
		CatCalmManager.apply_calm_delta(calm_delta, interaction_id, "park_interaction", self)
	_set_linked_nodes(activate_nodes, true)
	_set_linked_nodes(deactivate_nodes, false)
	_show_reaction()
	interacted.emit(interaction_id)
	if one_shot: JournalManager.clear_nearby_object(self)

func set_cat_vision_amount(amount: float) -> void:
	if not cat_vision_only_visible: return
	visible = amount > 0.08
	monitoring = visible
	monitorable = visible

func _can_interact() -> bool:
	if one_shot and _used: return false
	if not required_park_flag.is_empty() and not JournalManager.get_park_flag(required_park_flag): return false
	return not requires_cat_vision or _is_cat_vision_active()

func is_interaction_available() -> bool:
	return _can_interact()

func _is_cat_vision_active() -> bool:
	var manager := get_tree().current_scene.find_child("CatVisionManager", true, false)
	return manager != null and manager.has_method("get_cat_state") and int(manager.call("get_cat_state")) == 1

func _set_linked_nodes(paths: Array[NodePath], is_active: bool) -> void:
	for path in paths:
		var node := get_node_or_null(path)
		if node != null:
			if node is Node3D:
				(node as Node3D).visible = is_active
			elif node is CanvasItem:
				(node as CanvasItem).visible = is_active
			if node is Area3D: (node as Area3D).monitoring = is_active

func _show_reaction() -> void:
	var lines: Array = []
	if not cat_reaction.is_empty(): lines.append({"speaker_name":"КОТ", "text":cat_reaction})
	for line in optional_dialogue:
		lines.append({"speaker_name":"", "text":line})
	if lines.is_empty(): return
	var dialogue := get_tree().current_scene.find_child("DialogueManager", true, false) as DialogueManager
	if dialogue == null:
		dialogue = DialogueManager.new()
		dialogue.name = "DialogueManager"
		get_tree().current_scene.add_child(dialogue)
	dialogue.set_dialogues({"park_" + interaction_id: lines})
	dialogue.start_dialogue("park_" + interaction_id)
