extends Node

# Метрики для экрана итогов
var total_xp_collected: int = 0
var rival_camps_destroyed: int = 0
var units_spawned: int = 0
var time_elapsed: float = 0.0

var is_game_over: bool = false
var map_rect: Rect2 = Rect2(-2000, -2000, 4000, 4000)

func _process(delta: float) -> void:
    if not is_game_over:
        time_elapsed += delta

func log_event(type: String, value: Variant = 1) -> void:
    match type:
        "xp": total_xp_collected += int(value)
        "camp_destroyed": rival_camps_destroyed += int(value)
        "unit_spawned": units_spawned += int(value)

func stop_game() -> void:
    is_game_over = true
    print("[GAMEMANAGER] Match stopped.")

func reset_game() -> void:
    total_xp_collected = 0
    rival_camps_destroyed = 0
    units_spawned = 0
    time_elapsed = 0.0
    is_game_over = false
