extends Node

@export_group("Difficulty Configuration")
@export var base_spawn_interval: float = 2.0
@export var min_spawn_interval: float = 0.5
@export var count_growth_rate: float = 0.1
@export var growth_factor: float = 60.0 

func _ready() -> void:
    if Engine.is_editor_hint():
        push_warning("DifficultyController is a runtime logic node and will not function in the editor preview.")

func get_multiplier() -> float:
    if not GameManager is Object:
        push_error("GameManager autoload missing. Difficulty defaults to 1.0x.")
        return 1.0
    # Теперь мы используем переменную, которая появится в Инспекторе
    return 1.0 + (GameManager.time_elapsed / growth_factor) 

func get_spawn_interval(base_interval: float, min_interval: float) -> float:
    var multiplier: float = get_multiplier()
    return max(base_interval / multiplier, min_interval)

func get_stat_multiplier() -> float:
    return get_multiplier()

func get_spawn_count(base_count: int) -> int:
    if not GameManager is Object:
        push_error("GameManager autoload missing. Spawn count defaults to base value.")
        return base_count
    
    var time_elapsed: float = GameManager.time_elapsed
    var raw_value: float = float(base_count) * (1.0 + time_elapsed * count_growth_rate)
    
    return int(ceil(raw_value))
