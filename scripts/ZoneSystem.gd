extends Node

class_name ZoneSystem

@export var zone_scene: PackedScene
@export var max_active_zones: int = 5
@export var spawn_interval: float = 3.0
@export var spawn_radius_min: float = 200.0
@export var spawn_radius_max: float = 500.0

var current_zones: Array[Area2D] = []
var spawn_timer: float = 0.0

@onready var player_node: Player = get_parent().find_child("Player") as Player


func _ready() -> void:
    if player_node == null:
        push_error("ZoneSystem: Player node not found.")
        set_process(false)
        return

    while current_zones.size() < max_active_zones:
        _spawn_zone()


func _process(delta: float) -> void:
    spawn_timer += delta

    if spawn_timer >= spawn_interval and current_zones.size() < max_active_zones:
        _spawn_zone()
        spawn_timer = 0.0


func _spawn_zone() -> void:
    if zone_scene == null:
        push_error("ZoneSystem: zone_scene is not assigned.")
        return

    var zone_instance: Node = zone_scene.instantiate()
    if not zone_instance is Area2D:
        push_error("ZoneSystem: zone_scene root must be an Area2D.")
        zone_instance.queue_free()
        return

    var zone: Area2D = zone_instance as Area2D
    
    var distance: float = randf_range(spawn_radius_min, spawn_radius_max)
    var angle: float = randf() * TAU
    zone.global_position = player_node.global_position + Vector2.from_angle(angle) * distance

    add_child(zone)
    current_zones.append(zone)

    # Использование .bind(zone) для передачи ссылки на конкретный экземпляр зоны
    zone.body_entered.connect(_on_zone_body_entered.bind(zone))
    zone.body_exited.connect(_on_zone_body_exited.bind(zone))

func _on_zone_body_entered(body: Node2D, zone: Area2D) -> void:
    if body is CharacterBody2D and body.has_method("_on_zone_entered"):
        body._on_zone_entered(zone)

func _on_zone_body_exited(body: Node2D, zone: Area2D) -> void:
    if body is CharacterBody2D and body.has_method("_on_zone_exited"):
        body._on_zone_exited(zone)
