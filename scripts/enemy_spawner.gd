extends Node2D

# Inspector-configurable exports
@export var enemy_scene: PackedScene = null
@export var spawn_radius: float = 600.0
@export var base_interval: float = 2.0
@export var min_interval: float = 0.5
@export var difficulty_controller: Node = null

var _spawn_timer: Timer

func _ready() -> void:
    # Initialize and configure the spawning timer
    _spawn_timer = Timer.new()
    _spawn_timer.wait_time = base_interval
    _spawn_timer.autostart = true
    _spawn_timer.timeout.connect(_on_spawn_timeout)
    add_child(_spawn_timer)

func _on_spawn_timeout() -> void:
    if difficulty_controller == null:
        push_warning("DifficultyController not assigned. Falling back to default interval.")
        return

    # Update timer duration based on dynamic difficulty
    var scaled_interval: float = difficulty_controller.get_spawn_interval(base_interval, min_interval)
    _spawn_timer.wait_time = scaled_interval
    _spawn_timer.start()
    
    _trigger_enemy_spawn()

func _trigger_enemy_spawn() -> void:
    if enemy_scene == null or difficulty_controller == null:
        return

    var player: Node2D = get_tree().get_first_node_in_group("player")
    if player == null:
        push_warning("Player node not found in group 'player'. Spawn aborted.")
        return

    # Calculate radial spawn position around the player
    var angle: float = randf() * TAU
    var spawn_offset: Vector2 = Vector2.from_angle(angle) * spawn_radius
    var target_position: Vector2 = player.position + spawn_offset

    # Instantiate, position, and parent the enemy
    var enemy_instance: Node2D = enemy_scene.instantiate() as Node2D
    enemy_instance.position = target_position
    add_child(enemy_instance)

    # Apply difficulty scaling to base stats
    var multiplier: float = difficulty_controller.get_multiplier()
    if "health" in enemy_instance and "damage" in enemy_instance:
        enemy_instance.health *= multiplier
        enemy_instance.damage *= multiplier
