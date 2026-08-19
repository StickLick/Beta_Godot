extends Node2D

## Целевая прозрачность кронки конкретного дерева, когда игрок заходит под неё.
@export var fade_alpha: float = 0.35

## Скорость плавности перехода прозрачности.
@export var fade_speed: float = 8.0

## Минимальный размер зоны срабатывания вокруг дерева (расширяется под крупные кроны).
@export var zone_size: Vector2 = Vector2(70, 70)

## Оригинальные слои деревьев (порядок важен для z-отрисовки при ghost-копиях).
var _layers: Array[TileMapLayer] = []

## Каждое дерево: {cells_by_layer, zone, ghosts}
var _trees: Array[Dictionary] = []

var _active_tree: int = -1


func _ready() -> void:
	_collect_layers()
	_build_trees()


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var hit := _find_tree_at(player.global_position)

	if hit != _active_tree:
		if _active_tree != -1:
			_deactivate_tree(_active_tree)
		if hit != -1:
			_activate_tree(hit)
		_active_tree = hit

	# Плавная модуляция ghost-слоёв активного дерева.
	var k := 1.0 - exp(-fade_speed * delta)
	if _active_tree != -1:
		for ghost in _trees[_active_tree]["ghosts"]:
			ghost.modulate.a = lerp(ghost.modulate.a, fade_alpha, k)


func _collect_layers() -> void:
	_layers.clear()
	for child in get_children():
		# Ghost-копии добавляются в этот же контейнер и не должны собираться
		# как реальные слои при повторной инициализации.
		if child.name.begins_with("TreeFadeGhost_"):
			continue
		var layer := child as TileMapLayer
		if layer != null:
			_layers.append(layer)


## Собирает использованные клетки каждого слоя по отдельности и группирует их
## в связные кластеры (каждое дерево = кластер) внутри своего слоя.
## Кластеризация выполняется независимо для каждого слоя, потому что у слоёв
## разные transform (position/scale) — общая карта клеток дала бы неверные
## мировые координаты для слоёв с нестандартным transform.
func _build_trees() -> void:
	_trees.clear()
	if _layers.is_empty():
		return

	for li in _layers.size():
		var layer: TileMapLayer = _layers[li]

		# Карта клеток только этого слоя: координата -> данные тайла.
		var used: Dictionary = {}
		for cell in layer.get_used_cells():
			used[cell] = {
				"source": layer.get_cell_source_id(cell),
				"atlas": layer.get_cell_atlas_coords(cell),
				"alt": layer.get_cell_alternative_tile(cell),
			}

		# BFS-группировка соседних клеток в кластеры (8-связность).
		var visited: Dictionary = {}
		var clusters: Array = []
		for start in used:
			if visited.has(start):
				continue

			var cluster: Array = []
			var queue: Array = [start]
			visited[start] = true
			while not queue.is_empty():
				var c: Vector2i = queue.pop_back()
				cluster.append(c)
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						if dx == 0 and dy == 0:
							continue
						var n := c + Vector2i(dx, dy)
						if used.has(n) and not visited.has(n):
							visited[n] = true
							queue.append(n)

			clusters.append(cluster)

		# Слияние близких кластеров: у некоторых деревьев крона «дырявая»
		# или состоит из нескольких кусков с зазором в 1 тайл — это всё
		# одно дерево, и для него нужна единая зона срабатывания.
		var merged: Array = []
		for cluster in clusters:
			merged.append(cluster)

		var changed := true
		while changed:
			changed = false
			for i in range(merged.size()):
				for j in range(i + 1, merged.size()):
					if _clusters_touch(merged[i], merged[j]):
						merged[i].append_array(merged[j])
						merged.remove_at(j)
						changed = true
						break
				if changed:
					break

		for cluster in merged:
			_trees.append(_make_tree(cluster, used, layer, li))


## Два кластера считаются одним деревом, если между их клетками
## расстояние не больше одного тайла (дырявые кроны).
func _clusters_touch(a: Array, b: Array) -> bool:
	for ca in a:
		for cb in b:
			var d := Vector2i(abs(ca.x - cb.x), abs(ca.y - cb.y))
			if d.x <= 1 and d.y <= 1:
				return true
	return false


## Строит одно дерево из кластера клеток одного слоя: зона срабатывания
## в мировых координатах этого слоя и ghost-копия.
func _make_tree(cluster: Array, used: Dictionary, layer: TileMapLayer, layer_index: int) -> Dictionary:
	var tile_size: Vector2 = layer.tile_set.tile_size

	# Клетки кластера с данными тайлов (все принадлежат одному слою).
	var cells: Array = []
	for c in cluster:
		cells.append({
			"cell": c,
			"source": used[c]["source"],
			"atlas": used[c]["atlas"],
			"alt": used[c]["alt"],
		})

	# Мировой bounding box кластера — объединение мировых тайлов этого слоя.
	var bbox := Rect2()
	var first := true
	for c in cluster:
		var world_pos: Vector2 = layer.to_global(layer.map_to_local(c))
		var cell_rect := Rect2(world_pos, tile_size * layer.scale)
		if first:
			bbox = cell_rect
			first = false
		else:
			bbox = bbox.merge(cell_rect)

	# Зона: минимум zone_size, с запасом под крупные кроны.
	var zone_w := maxf(zone_size.x, bbox.size.x + 16.0)
	var zone_h := maxf(zone_size.y, bbox.size.y + 16.0)
	var zone := Rect2(bbox.get_center() - Vector2(zone_w, zone_h) * 0.5, Vector2(zone_w, zone_h))

	# Ghost-слой: полупрозрачная копия только этого дерева, без физики.
	# Копирует position/scale/z_index/tile_set с исходного слоя.
	var ghost := TileMapLayer.new()
	ghost.name = "TreeFadeGhost_%d_%d" % [_trees.size(), layer_index]
	ghost.tile_set = layer.tile_set
	ghost.collision_enabled = false
	ghost.y_sort_enabled = layer.y_sort_enabled
	ghost.z_index = layer.z_index
	ghost.position = layer.position
	ghost.scale = layer.scale
	ghost.modulate = Color(1.0, 1.0, 1.0, fade_alpha)
	ghost.visible = false
	for entry in cells:
		ghost.set_cell(entry["cell"], entry["source"], entry["atlas"], entry["alt"])
	add_child(ghost)

	# Клетки принадлежат одному слою с индексом layer_index.
	var cells_by_layer: Dictionary = {}
	cells_by_layer[layer_index] = cells

	return {
		"cells_by_layer": cells_by_layer,
		"zone": zone,
		"ghosts": [ghost],
	}


## Возвращает дерево под позицией. Если зоны нескольких деревьев пересекаются,
## выбирается то, чей центр ближе к игроку.
func _find_tree_at(pos: Vector2) -> int:
	var best := -1
	var best_dist := INF
	for i in _trees.size():
		var zone: Rect2 = _trees[i]["zone"]
		if zone.has_point(pos):
			var d := zone.get_center().distance_squared_to(pos)
			if d < best_dist:
				best_dist = d
				best = i
	return best


## Игрок зашёл под дерево: стираем его клетки из оригинального слоя
## (чтобы непрозрачные пиксели не перекрывали игрока) и показываем ghost.
func _activate_tree(i: int) -> void:
	var tree: Dictionary = _trees[i]
	for li in tree["cells_by_layer"]:
		for entry in tree["cells_by_layer"][li]:
			_layers[li].erase_cell(entry["cell"])
	for ghost in tree["ghosts"]:
		# Клетки оригинала стёрты — ghost берёт на себя и отрисовку, и физику.
		ghost.collision_enabled = true
		ghost.visible = true
		ghost.modulate.a = fade_alpha


## Игрок вышел из-под дерева: возвращаем клетки в оригинальный слой
## и прячем ghost.
func _deactivate_tree(i: int) -> void:
	var tree: Dictionary = _trees[i]
	for li in tree["cells_by_layer"]:
		for entry in tree["cells_by_layer"][li]:
			_layers[li].set_cell(entry["cell"], entry["source"], entry["atlas"], entry["alt"])
	for ghost in tree["ghosts"]:
		# Возвращаем клетки в оригинал — ghost больше не нужен.
		ghost.collision_enabled = false
		ghost.visible = false
		ghost.modulate.a = fade_alpha