extends Node
class_name DifficultyController

@export_group("References")
@export var pressure_manager: WorldPressureManager = null

@export_group("Difficulty Configuration")
@export var base_spawn_interval: float = 2.0
@export var min_spawn_interval: float = 0.5
@export var count_growth_rate: float = 0.1
@export var growth_factor: float = 60.0 # Секунд до роста сложности на +1.0

func _ready() -> void:
    # Авто-поиск менеджера, если он не перетащен в инспектор
    if pressure_manager == null:
        pressure_manager = get_tree().root.find_child("PressureManager", true, false) as WorldPressureManager

## Множитель только от времени
func get_time_multiplier() -> float:
    if not GameManager is Object:
        return 1.0
    return 1.0 + (GameManager.time_elapsed / growth_factor) 

## ОБЪЕДИНЕННЫЙ МНОЖИТЕЛЬ (Уровень угрозы)
func get_final_threat_multiplier() -> float:
    var time_mult = get_time_multiplier()
    var pressure_mult = 1.0
    
    if is_instance_valid(pressure_manager):
        pressure_mult = pressure_manager.get_spawn_rate_multiplier()
        
    return time_mult * pressure_mult

## Интервал спавна (уменьшается с ростом угрозы)
func get_spawn_interval(base_interval: float, min_interval: float) -> float:
    var threat: float = get_final_threat_multiplier()
    return max(base_interval / threat, min_interval)

## Количество врагов (растет с ростом угрозы)
func get_spawn_count(base_count: int) -> int:
    var threat: float = get_final_threat_multiplier()
    # Базовое количество * множитель угрозы * небольшой коэф. времени
    var raw_value: float = float(base_count) * threat
    return int(ceil(raw_value))

# Для обратной совместимости
func get_multiplier() -> float:
    return get_final_threat_multiplier()
