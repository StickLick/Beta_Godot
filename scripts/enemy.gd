extends CharacterBody2D
class_name Enemy

const XP_GEM_SCENE: PackedScene = preload("res://Assets/Scenes/Xp_gem.tscn")

@export_group("Stats")
@export var speed: float = 120.0
@export var xp_value: int = 10
@export var health_component: HealthComponent

@export_group("Crowd AI")
@export var separation_radius: float = 40.0
@export var separation_force: float = 300.0

@onready var hurtbox: HurtboxComponent = $HurtboxComponent

func _ready() -> void:
    add_to_group("enemy")
    
    if health_component == null:
        health_component = $HealthComponent as HealthComponent

    if health_component:
        health_component.health_depleted.connect(_on_death)
        
    # Подключение вспышки урона
    if hurtbox:
        hurtbox.hit_received.connect(_on_hit_received)

func _physics_process(_delta: float) -> void:
    var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
    if player == null:
        velocity = Vector2.ZERO
        move_and_slide()
        return

    # 1. Вектор движения к игроку
    var direction_to_player: Vector2 = (player.global_position - global_position).normalized()
    var target_velocity: Vector2 = direction_to_player * speed

    # 2. Логика расталкивания (Separation)
    var separation_vector: Vector2 = _calculate_separation()
    
    # Итоговая скорость
    velocity = target_velocity + (separation_vector * separation_force)
    move_and_slide()

func _calculate_separation() -> Vector2:
    var steer: Vector2 = Vector2.ZERO
    var neighbors: Array[Node] = get_tree().get_nodes_in_group("enemy")
    var count: int = 0
    
    for neighbor in neighbors:
        if neighbor == self or not is_instance_valid(neighbor):
            continue
            
        var distance: float = global_position.distance_to(neighbor.global_position)
        
        if distance < separation_radius and distance > 0:
            # Вектор "от соседа", обратно пропорциональный дистанции
            var diff: Vector2 = (global_position - neighbor.global_position).normalized()
            steer += diff / distance
            count += 1
            
    if count > 0:
        steer /= count
        
    return steer

func _on_hit_received(_damage: float) -> void:
    # Визуальный эффект мигания
    var tween = create_tween()
    modulate = Color.RED
    tween.tween_property(self, "modulate", Color.WHITE, 0.1)

func _on_death() -> void:
    var gem: XPGem = XP_GEM_SCENE.instantiate() as XPGem
    gem.global_position = global_position
    
    # Передаем масштабированный опыт кристаллу
    gem.xp_amount = xp_value
    
    get_tree().current_scene.call_deferred("add_child", gem)
    call_deferred("queue_free")
