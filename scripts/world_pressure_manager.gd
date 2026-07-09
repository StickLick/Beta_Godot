extends Node
class_name WorldPressureManager

# --- Конфигурация ---
@export var base_spawn_interval: float = 5.0
@export var pressure_growth_rate: float = 0.0166 # Увеличение давления в секунду (1.0 за минуту)

# --- Состояние ---
var current_pressure_level: float = 1.0
var _elapsed_time: float = 0.0

func _process(delta: float) -> void:
    # Линейное увеличение давления со временем
    _elapsed_time += delta
    current_pressure_level = 1.0 + (_elapsed_time * pressure_growth_rate)

# Интерфейс для ZoneSystem
func get_spawn_rate_multiplier() -> float:
    # Чем выше давление, тем чаще спавнятся зоны (интервал уменьшается)
    return clamp(1.0 / current_pressure_level, 0.2, 1.0)

func get_zone_intensity_multiplier() -> float:
    # Чем выше давление, тем сильнее влияние зон
    return clamp(current_pressure_level, 1.0, 3.0)

# Возвращает словарь для быстрой интеграции в ZoneSystem
func get_system_scaling() -> Dictionary:
    return {
        "spawn_rate": get_spawn_rate_multiplier(),
        "intensity": get_zone_intensity_multiplier()
    }
