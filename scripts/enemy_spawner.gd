extends Node2D

@export var enemy_scene: PackedScene = null
@export var spawn_radius: float = 600.0
@export var difficulty_controller: Node = null

var _spawn_timer: Timer

func _ready() -> void:
    _setup_timer()

func _setup_timer() -> void:
    _spawn_timer = Timer.new()
    _spawn_timer.wait_time = difficulty_controller.base_spawn_interval
    _spawn_timer.autostart = true
    _spawn_timer.timeout.connect(_on_spawn_timeout)
    add_child(_spawn_timer)

func _on_spawn_timeout() -> void:
    if difficulty_controller == null:
        push_warning("DifficultyController not assigned. Falling back to default interval.")
        return

    # Update timer duration based on dynamic difficulty
    var scaled_interval = difficulty_controller.get_spawn_interval(
        difficulty_controller.base_spawn_interval, 
        difficulty_controller.min_spawn_interval
    )
    _spawn_timer.wait_time = scaled_interval
    _spawn_timer.start()

    # Get dynamically scaled spawn count (base is 1)
    var spawn_count: int = difficulty_controller.get_spawn_count(1)

    # Spawn each enemy individually with radial positioning
    for i in range(spawn_count):
        _spawn_enemy()
        
    # Блок для отладки баланса спавна
    var current_interval = difficulty_controller.get_spawn_interval(difficulty_controller.base_spawn_interval, difficulty_controller.min_spawn_interval)
    var current_count = difficulty_controller.get_spawn_count(1)
    var multiplier = difficulty_controller.get_multiplier()
    
    print("--- SPANW DEBUG ---")
    print("Time: ", GameManager.time_elapsed)
    print("Interval: ", current_interval)
    print("Count: ", current_count)
    print("Multiplier: ", multiplier)

func _spawn_enemy() -> void:
    if enemy_scene == null or difficulty_controller == null:
        return

    var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
    if player == null:
        return

    # Radial spawn logic (intact)
    var angle: float = randf() * TAU
    var spawn_offset: Vector2 = Vector2.from_angle(angle) * spawn_radius
    var target_position: Vector2 = player.position + spawn_offset

    var enemy_instance: Node2D = enemy_scene.instantiate() as Node2D
    enemy_instance.position = target_position
    add_child(enemy_instance)

    # Apply difficulty scaling to stats
    var multiplier: float = difficulty_controller.get_multiplier()
    if "health" in enemy_instance and "damage" in enemy_instance:
        enemy_instance.health *= multiplier
        enemy_instance.damage *= multiplier
