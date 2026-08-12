extends Node
## Тест OreGenerator: многократный прогон rejection-sampling.
## Проверяет: попарные дистанции >= min_distance, радиус исключения игрока 400.

const ORE_SCRIPT := preload("res://scripts/ore_generator.gd")
const MIN_DIST := 1600.0
const PLAYER_RADIUS := 400.0
const RUNS := 20


func test_ore_distribution() -> void:
	var failures: Array = []
	var player_pos := Vector2(0, 0)

	var gen := Node.new()
	gen.set_script(ORE_SCRIPT)
	gen.ore_count = 8
	gen.min_distance = MIN_DIST
	gen.map_margin = 500.0
	gen.max_placement_attempts = 500
	gen._map_rect = Rect2(-3000, -3000, 6000, 6000)

	for run in range(RUNS):
		gen._placed_positions.clear()
		var placed: Array[Vector2] = []

		for i in range(gen.ore_count):
			var pos: Vector2 = gen._find_valid_position()
			if pos == Vector2.INF:
				failures.append("run %d: node %d not placed" % [run, i])
				continue
			gen._placed_positions.append(pos)
			placed.append(pos)

		for a in range(placed.size()):
			for b in range(a + 1, placed.size()):
				var d := placed[a].distance_to(placed[b])
				if d <= MIN_DIST:
					failures.append("run %d: pair %d-%d dist=%.1f <= %.1f" % [run, a, b, d, MIN_DIST])

		for p in placed:
			var dp := p.distance_to(player_pos)
			if dp < PLAYER_RADIUS:
				failures.append("run %d: node too close to player %.1f" % [run, dp])

	if not failures.is_empty():
		for f in failures:
			push_error("[ORE TEST FAIL] " + f)
		return

	print("[ORE TEST] PASSED: %d runs, all pairs > %.1f, player radius %.0f respected" % [RUNS, MIN_DIST, PLAYER_RADIUS])