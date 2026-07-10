extends Node

# WorldPressureManager.gd
# Manages global system pressure based on active ZoneSystem dominance.

var current_pressure_level: float = 1.0

func _process(delta: float) -> void:
    current_pressure_level = lerp(current_pressure_level, calculate_system_pressure(), delta * 0.1)

## Calculates current pressure based on the average dominance of all active zones.
func calculate_system_pressure() -> float:
    var zones: Array[Node] = get_tree().get_nodes_in_group("zones")
    
    if zones.is_empty():
        return 1.0
        
    var total_dominance: float = 0.0
    for zone in zones:
        # Ensure the zone node has a 'dominance' property
        if "dominance" in zone:
            total_dominance += zone.dominance
            
    return total_dominance / float(zones.size())

## Returns a multiplier for spawn intensity. 
## Higher pressure reduces spawn frequency to maintain systemic stability.
func get_spawn_rate_multiplier() -> float:
    return clamp(1.0 / (current_pressure_level + 0.5), 0.2, 1.0)

## Returns the current count of active zones to adjust spawn intensity.
func get_active_zone_count() -> int:
    return get_tree().get_nodes_in_group("zones").size()
