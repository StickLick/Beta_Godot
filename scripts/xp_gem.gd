class_name XPGem
extends Area2D

@export var xp_value: int = 10

var _player: Node2D = null
var _speed: float = 0.0
var _max_speed: float = 400.0
var _acceleration: float = 800.0


func attract(player_node: Node2D) -> void:
	_player = player_node


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return

	var direction: Vector2 = (_player.global_position - global_position).normalized()
	_speed = move_toward(_speed, _max_speed, _acceleration * delta)
	global_position += direction * _speed * delta

	if global_position.distance_to(_player.global_position) < 15.0:
		_player.collect_xp(xp_value)
		queue_free()
