extends Node
class_name WorldPressureManager

# Менеджер должен быть узлом в сцене, чтобы работать!

var current_pressure_level: float = 1.0

func _process(delta: float) -> void:
    # Плавный расчет давления на основе доминирования зон
    current_pressure_level = lerp(current_pressure_level, calculate_system_pressure(), delta * 0.1)

func calculate_system_pressure() -> float:
    var zones: Array[Node] = get_tree().get_nodes_in_group("zones")
    
    if zones.is_empty():
        return 1.0
        
    var total_dominance: float = 0.0
    for zone in zones:
        if "dominance" in zone:
            total_dominance += zone.dominance
            
    return total_dominance / float(zones.size())

## Множитель для сложности: чем выше давление зон, тем выше угроза.
func get_spawn_rate_multiplier() -> float:
    # Если давления нет (1.0), множитель 1.0. Если зоны захватили мир (5.0), сложность x5.
    return clamp(current_pressure_level, 1.0, 5.0)

func get_active_zone_count() -> int:
    return get_tree().get_nodes_in_group("zones").size()
