class_name EnemySpawner
extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 2.0
@export var spawn_radius: float = 600.0

@onready var spawn_timer: Timer = $SpawnTimer


func _ready() -> void:
    spawn_timer.wait_time = spawn_interval
    spawn_timer.timeout.connect(_on_spawn_timer_timeout)
    spawn_timer.start()


func _on_spawn_timer_timeout() -> void:
    if enemy_scene == null:
        return

    var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
    if player == null:
        return

    var random_angle: float = randf() * TAU
    var spawn_offset: Vector2 = Vector2.RIGHT.rotated(random_angle) * spawn_radius
    var spawn_pos: Vector2 = player.global_position + spawn_offset

    var enemy: CharacterBody2D = enemy_scene.instantiate() as CharacterBody2D
    enemy.global_position = spawn_pos
    get_tree().current_scene.add_child(enemy)
