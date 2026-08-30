extends Area3D
class_name Chapter1MovingCar

signal player_hit_car(player: Node)

@export var start_marker_path: NodePath
@export var end_marker_path: NodePath
@export var use_local_points: bool = false
@export var start_position: Vector3 = Vector3.ZERO
@export var end_position: Vector3 = Vector3.ZERO
@export var speed: float = 9.0
@export var wait_at_end: float = 0.6

var _start_marker: Node3D
var _end_marker: Node3D
var _start_global_position: Vector3
var _end_global_position: Vector3
var _wait_left: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_start_marker = get_node_or_null(start_marker_path) as Node3D
	_end_marker = get_node_or_null(end_marker_path) as Node3D
	_refresh_points()
	if _start_marker != null:
		global_position = _start_marker.global_position
	elif use_local_points:
		global_position = _start_global_position

func _physics_process(delta: float) -> void:
	if not _has_points():
		return
	if _wait_left > 0.0:
		_wait_left -= delta
		return

	var target := _get_end_position()
	var next_position := global_position.move_toward(target, speed * delta)
	global_position = next_position
	if global_position.distance_to(target) <= 0.08:
		global_position = _get_start_position()
		_wait_left = wait_at_end

func _on_body_entered(body: Node3D) -> void:
	if body != null and body.name == "PlayerCat":
		player_hit_car.emit(body)

func _refresh_points() -> void:
	if _start_marker != null:
		_start_global_position = _start_marker.global_position
	elif use_local_points:
		_start_global_position = start_position
	else:
		_start_global_position = global_position

	if _end_marker != null:
		_end_global_position = _end_marker.global_position
	elif use_local_points:
		_end_global_position = end_position
	else:
		_end_global_position = global_position

func _has_points() -> bool:
	return _start_marker != null or _end_marker != null or use_local_points

func _get_start_position() -> Vector3:
	return _start_marker.global_position if _start_marker != null else _start_global_position

func _get_end_position() -> Vector3:
	return _end_marker.global_position if _end_marker != null else _end_global_position
