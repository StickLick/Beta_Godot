extends Node
class_name OreGenerator
## Генерирует фиксированные рудные узлы на всей карте при старте.
## Использует rejection sampling для обеспечения минимальной дистанции между узлами.
## Визуалы OreNode настраиваются вручную через Inspector в сцене.

@export var ore_count: int = 8
@export var min_distance: float = 1600.0
@export var map_margin: float = 500.0
@export var max_placement_attempts: int = 500

const ORE_NODE_SCENE := preload("res://Assets/Scenes/OreNode.tscn")

var _map_rect: Rect2
var _placed_positions: Array[Vector2] = []


func _ready() -> void:
	_map_rect = GameManager.get_meta("map_rect", Rect2(-2000, -2000, 4000, 4000))
	call_deferred("_generate_ores")


func _generate_ores() -> void:
	_placed_positions.clear()

	for i in range(ore_count):
		var pos := _find_valid_position()
		if pos != Vector2.INF:
			_placed_positions.append(pos)
			_spawn_ore_node(pos, i)
		else:
			push_warning("OreGenerator: не удалось разместить узел %d после %d попыток" % [i, max_placement_attempts])

	print("[ORE] Размещено %d рудных узлов" % _placed_positions.size())


func _find_valid_position() -> Vector2:
	for attempt in range(max_placement_attempts):
		var pos := Vector2(
			randf_range(_map_rect.position.x + map_margin, _map_rect.end.x - map_margin),
			randf_range(_map_rect.position.y + map_margin, _map_rect.end.y - map_margin)
		)

		if _is_position_valid(pos):
			return pos

	return Vector2.INF


func _is_position_valid(pos: Vector2) -> bool:
	# Проверка минимальной дистанции между узлами (включительно: ровно min_distance тоже reject)
	for existing in _placed_positions:
		if pos.distance_to(existing) <= min_distance:
			return false

	# Проверка дистанции до игрока (чтобы не спавнилось прямо на нём)
	var player := get_tree().get_first_node_in_group("player")
	if player and pos.distance_to(player.global_position) < 400.0:
		return false

	return true


func _spawn_ore_node(pos: Vector2, index: int) -> void:
	var scene := get_tree().current_scene
	if not scene:
		return

	var ore := ORE_NODE_SCENE.instantiate()
	ore.name = "OreNode_%d" % index
	ore.global_position = pos

	scene.add_child(ore)
