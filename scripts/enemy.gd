extends CharacterBody2D

const XP_GEM_SCENE: PackedScene = preload("res://scenes/xp_gem.tscn")

@export var speed: float = 120.0
@export var health_component: HealthComponent


func _ready() -> void:
    if health_component == null:
        health_component = $HealthComponent as HealthComponent

    health_component.health_depleted.connect(_on_death)


func _physics_process(_delta: float) -> void:
    var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
    if player == null:
        velocity = Vector2.ZERO
        move_and_slide()
        return

    var direction: Vector2 = (player.global_position - global_position).normalized()
    velocity = direction * speed
    move_and_slide()


func _on_death() -> void:
    var gem: XPGem = XP_GEM_SCENE.instantiate() as XPGem
    gem.global_position = global_position
    get_tree().current_scene.call_deferred("add_child", gem)
    call_deferred("queue_free")
