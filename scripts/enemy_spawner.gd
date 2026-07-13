extends Node2D

@export var enemy_scene: PackedScene = null
@export var spawn_radius: float = 600.0
@export var difficulty_controller: DifficultyController = null

var _spawn_timer: Timer

func _ready() -> void:
    if difficulty_controller == null:
        difficulty_controller = get_tree().root.find_child("DifficultyController", true, false)
        
    if difficulty_controller == null:
        push_error("EnemySpawner: DifficultyController NOT FOUND!")
        return
        
    _setup_timer()

func _setup_timer() -> void:
    _spawn_timer = Timer.new()
    _spawn_timer.wait_time = difficulty_controller.base_spawn_interval
    _spawn_timer.autostart = true
    _spawn_timer.one_shot = true
    _spawn_timer.timeout.connect(_on_spawn_timeout)
    add_child(_spawn_timer)

func _on_spawn_timeout() -> void:
    if not is_instance_valid(difficulty_controller):
        return

    var threat: float = difficulty_controller.get_final_threat_multiplier()
    var next_interval = difficulty_controller.get_spawn_interval(
        difficulty_controller.base_spawn_interval, 
        difficulty_controller.min_spawn_interval
    )
    _spawn_timer.wait_time = next_interval

    var spawn_count: int = difficulty_controller.get_spawn_count(1)

    for i in range(spawn_count):
        _spawn_enemy(threat)
        
    _spawn_timer.start()

func _spawn_enemy(threat: float) -> void:
    if enemy_scene == null:
        return

    var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
    if player == null:
        return

    var angle: float = randf() * TAU
    var spawn_offset: Vector2 = Vector2.from_angle(angle) * spawn_radius
    var target_position: Vector2 = player.position + spawn_offset

    var enemy_instance: Enemy = enemy_scene.instantiate() as Enemy
    enemy_instance.position = target_position
    add_child(enemy_instance)

    # Применяем множитель угрозы к статам
    if "health" in enemy_instance:
        enemy_instance.health_component.max_health *= threat
        enemy_instance.health_component.health = enemy_instance.health_component.max_health
    
    # МАСШТАБИРОВАНИЕ НАГРАДЫ: Базовые 10 * текущая угроза
    if "xp_value" in enemy_instance:
        enemy_instance.xp_value = int(10 * threat)
