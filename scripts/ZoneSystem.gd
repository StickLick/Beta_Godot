extends Node
class_name ZoneSystem

@export var zone_scene: PackedScene
@export var max_active_zones: int = 8
@export var spawn_interval: float = 3.0
@export var spawn_radius_min: float = 200.0
@export var spawn_radius_max: float = 500.0

@onready var pressure_manager: Node = get_node_or_null("/root/Main/WorldPressureManager")

var current_zones: Array[Area2D] = []
var spawn_timer: float = 0.0
const ZONE_TYPES: Array[String] = ["Acceleration", "Stabilization", "Pressure", "Flux"]

func _ready() -> void:
    # Используем call_deferred, чтобы избежать проблем при инициализации сцены
    call_deferred("_initial_spawn")

func _initial_spawn() -> void:
    var player: Node2D = get_tree().get_first_node_in_group("player")
    if not player: return
    
    # Безопасный спавн без бесконечного цикла
    for i in range(max_active_zones):
        _spawn_zone(player)

func _process(delta: float) -> void:
    _cleanup_destroyed_zones()
    _resolve_soft_influence_interactions(delta)
    
    var spawn_rate_mod: float = 1.0
    if pressure_manager and pressure_manager.has_method("get_spawn_rate_multiplier"):
        spawn_rate_mod = pressure_manager.get_spawn_rate_multiplier()
        
    spawn_timer += delta
    if spawn_timer >= (spawn_interval * spawn_rate_mod):
        spawn_timer = 0.0
        if current_zones.size() < max_active_zones:
            var player: Node2D = get_tree().get_first_node_in_group("player")
            if player:
                _spawn_zone(player)

func _spawn_zone(player: Node2D) -> void:
    if not zone_scene: return
    
    var zone: Area2D = zone_scene.instantiate() as Area2D
    var angle: float = randf() * TAU
    var dist: float = randf_range(spawn_radius_min, spawn_radius_max)
    zone.global_position = player.global_position + Vector2.from_angle(angle) * dist
    
    if "zone_type" in zone:
        zone.set("zone_type", ZONE_TYPES.pick_random())
    
    # Добавляем в корень сцены, чтобы зоны не зависели от движения ZoneSystem
    get_tree().current_scene.add_child(zone)
    current_zones.append(zone)

func _resolve_soft_influence_interactions(delta: float) -> void:
    # Оптимизированный цикл: проверяем только активные зоны
    for i in range(current_zones.size()):
        for j in range(i + 1, current_zones.size()):
            var z1: Area2D = current_zones[i]
            var z2: Area2D = current_zones[j]
            
            var dist: float = z1.global_position.distance_to(z2.global_position)
            var r1: float = z1.get("soft_influence_radius") if "soft_influence_radius" in z1 else 250.0
            var r2: float = z2.get("soft_influence_radius") if "soft_influence_radius" in z2 else 250.0
            
            if dist < (r1 + r2):
                _exchange_dominance(z1, z2, delta)

func _exchange_dominance(z1: Area2D, z2: Area2D, delta: float) -> void:
    var t1: String = z1.get("zone_type")
    var t2: String = z2.get("zone_type")
    var d1: float = z1.get("dominance")
    var d2: float = z2.get("dominance")
    var rate: float = 0.1 * delta
    
    # Логика "Камень-Ножницы-Бумага" для зон
    var z1_wins: bool = (t1 == "Acceleration" and t2 == "Pressure") or \
                        (t1 == "Pressure" and t2 == "Stabilization") or \
                        (t1 == "Stabilization" and t2 == "Flux") or \
                        (t1 == "Flux" and t2 == "Acceleration")
    
    if z1_wins:
        z1.set("dominance", clamp(d1 + rate, 0.5, 2.0))
        z2.set("dominance", clamp(d2 - rate, 0.5, 2.0))
    else:
        z1.set("dominance", clamp(d1 - rate, 0.5, 2.0))
        z2.set("dominance", clamp(d2 + rate, 0.5, 2.0))

func _cleanup_destroyed_zones() -> void:
    # Удаляем null-ссылки из массива
    current_zones = current_zones.filter(func(z): return is_instance_valid(z))
