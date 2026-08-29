extends Area3D
class_name Chapter1MovingCar

signal player_hit_car(player: Node)

@export var start_marker_path: NodePath
@export var end_marker_path: NodePath
@export var speed: float = 9.0
@export var wait_at_end: float = 0.6

var _start_marker: Node3D
var _end_marker: Node3D
var _wait_left: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_start_marker = get_node_or_null(start_marker_path) as Node3D
	_end_marker = get_node_or_null(end_marker_path) as Node3D
	if _start_marker != null:
		global_position = _start_marker.global_position

func _physics_process(delta: float) -> void:
	if _start_marker == null or _end_marker == null:
		return
	if _wait_left > 0.0:
		_wait_left -= delta
		return

	var target := _end_marker.global_position
	var next_position := global_position.move_toward(target, speed * delta)
	global_position = next_position
	if global_position.distance_to(target) <= 0.08:
		global_position = _start_marker.global_position
		_wait_left = wait_at_end

func _on_body_entered(body: Node3D) -> void:
	if body != null and body.name == "PlayerCat":
		player_hit_car.emit(body)
