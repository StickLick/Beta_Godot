extends Node

@export_group("Difficulty Configuration")
@export var base_spawn_interval: float = 2.0
@export var min_spawn_interval: float = 0.5

func _ready() -> void:
    if Engine.is_editor_hint():
        push_warning("DifficultyController is a runtime logic node and will not function in the editor preview.")

func get_multiplier() -> float:
    # Safely access the registered Autoload singleton
    if not GameManager is Object:
        push_error("GameManager autoload is missing or not properly configured. Difficulty calculations will default to 1.0.")
        return 1.0
        
    var game_time: float = GameManager.time_elapsed
    return 1.0 + (game_time / 60.0)

func get_spawn_interval(base_interval: float, min_interval: float) -> float:
    var multiplier: float = get_multiplier()
    var scaled_interval: float = base_interval / multiplier
    # Clamp the result to ensure it never drops below the minimum threshold
    return max(scaled_interval, min_interval)

func get_stat_multiplier() -> float:
    # Stat scaling uses the exact same difficulty curve as spawn rates
    return get_multiplier()
