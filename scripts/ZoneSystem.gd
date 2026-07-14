extends Node
class_name ZoneSystem

@export var zone_scene: PackedScene
@export var camp_scene: PackedScene 
@export var max_active_zones: int = 4
@export var spawn_interval: float = 12.0

var current_zones: Array[Area2D] = []
var spawn_timer: float = 0.0

func _process(delta: float) -> void:
    current_zones = current_zones.filter(func(z): return is_instance_valid(z))
    spawn_timer += delta
    if spawn_timer >= spawn_interval:
        spawn_timer = 0.0
        if current_zones.size() < max_active_zones: _spawn_zone()

func _spawn_zone() -> void:
    var player = get_tree().get_first_node_in_group("player")
    if not player or not zone_scene: return
    var rect = GameManager.get_meta("map_rect") if GameManager.has_meta("map_rect") else Rect2(-2000,-2000,4000,4000)
    var spawn_pos = player.global_position + Vector2.from_angle(randf()*TAU) * randf_range(400, 800)
    # Ограничение спавна зоны
    spawn_pos.x = clamp(spawn_pos.x, rect.position.x + 300, rect.end.x - 300)
    spawn_pos.y = clamp(spawn_pos.y, rect.position.y + 300, rect.end.y - 300)
    
    var zone = zone_scene.instantiate()
    zone.global_position = spawn_pos
    if zone.has_signal("evolved"): zone.evolved.connect(_on_zone_evolved.bind(zone))
    get_tree().current_scene.add_child(zone)
    current_zones.append(zone)

func _on_zone_evolved(pos: Vector2, _type: String, dom: float, zone_ref: Area2D) -> void:
    current_zones.erase(zone_ref)
    var existing = get_tree().get_nodes_in_group("camps")
    for c in existing:
        if c.global_position.distance_to(pos) < 400:
            if c.has_method("upgrade"): c.upgrade(dom * 50); return
    if not camp_scene: return
    var camp = camp_scene.instantiate()
    camp.global_position = pos
    var player = get_tree().get_first_node_in_group("player")
    camp.alignment = 1 if (player and player.global_position.distance_to(pos) < 300) else 2
    get_tree().current_scene.add_child(camp)
