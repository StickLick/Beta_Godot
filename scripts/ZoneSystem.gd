extends Node
class_name ZoneSystem

@export var zone_scene: PackedScene
@export var camp_scene: PackedScene 
@export var max_active_zones: int = 4 # Резко уменьшили количество
@export var spawn_interval: float = 12.0 # Резко увеличили время появления

var current_zones: Array[Area2D] = []
var spawn_timer: float = 0.0
const ZONE_TYPES: Array[String] = ["Acceleration", "Stabilization", "Pressure", "Flux"]

func _process(delta: float) -> void:
    _cleanup_destroyed_zones()
    _resolve_interactions(delta)
    
    spawn_timer += delta
    if spawn_timer >= spawn_interval:
        spawn_timer = 0.0
        if current_zones.size() < max_active_zones:
            var player = get_tree().get_first_node_in_group("player")
            if player: _spawn_zone(player)

func _spawn_zone(player: Node2D = null) -> void:
    if not player: player = get_tree().get_first_node_in_group("player")
    if not player or not zone_scene: return
    
    var zone = zone_scene.instantiate()
    zone.zone_type = ZONE_TYPES.pick_random()
    
    var angle = randf() * TAU
    var dist = randf_range(400, 800) # Зоны спавнятся дальше
    zone.global_position = player.global_position + Vector2.from_angle(angle) * dist
    
    if zone.has_signal("evolved"):
        zone.evolved.connect(_on_zone_evolved.bind(zone))
        
    get_tree().current_scene.add_child(zone)
    current_zones.append(zone)

func _on_zone_evolved(pos: Vector2, _type: String, dom: float, zone_ref: Area2D) -> void:
    current_zones.erase(zone_ref)
    
    # ПРОВЕРКА: Если рядом (в радиусе 400) уже есть лагерь, не создаем новый
    var existing_camps = get_tree().get_nodes_in_group("camps")
    for camp in existing_camps:
        if is_instance_valid(camp) and camp.global_position.distance_to(pos) < 400.0:
            # Вместо создания нового, просто усиливаем существующий
            if camp.has_method("upgrade"):
                camp.upgrade(dom * 50.0) 
            return

    if not camp_scene: return
    var camp = camp_scene.instantiate() as Camp
    camp.global_position = pos
    
    var player = get_tree().get_first_node_in_group("player")
    # Лагерь станет вашим только если вы ДЕЙСТВИТЕЛЬНО рядом в момент фиксации
    if player and player.global_position.distance_to(pos) < 250.0:
        camp.alignment = Camp.Alignment.PLAYER
    else:
        camp.alignment = Camp.Alignment.RIVAL
        
    get_tree().current_scene.add_child(camp)

func _resolve_interactions(delta: float) -> void:
    for i in range(current_zones.size()):
        for j in range(i + 1, current_zones.size()):
            var z1 = current_zones[i]
            var z2 = current_zones[j]
            if not is_instance_valid(z1) or not is_instance_valid(z2): continue
            
            var dist = z1.global_position.distance_to(z2.global_position)
            if dist < (120.0 * z1.scale.x + 120.0 * z2.scale.x):
                _exchange_dominance(z1, z2, delta)

func _exchange_dominance(z1, z2, delta) -> void:
    var t1 = z1.zone_type
    var t2 = z2.zone_type
    var rate = 0.05 * delta # Скорость борьбы зон замедлена
    
    var z1_wins = (t1 == "Acceleration" and t2 == "Pressure") or \
                  (t1 == "Pressure" and t2 == "Stabilization") or \
                  (t1 == "Stabilization" and t2 == "Flux") or \
                  (t1 == "Flux" and t2 == "Acceleration")
    
    if z1_wins:
        z1.dominance += rate
        z2.dominance -= rate
    else:
        z1.dominance -= rate
        z2.dominance += rate

func _cleanup_destroyed_zones() -> void:
    current_zones = current_zones.filter(func(z): return is_instance_valid(z))
    
