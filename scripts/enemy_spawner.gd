extends Node2D

@export var enemy_scene: PackedScene = null
@export var spawn_radius: float = 600.0
@export var difficulty_controller: DifficultyController = null

var _spawn_timer: Timer

func _ready() -> void:
    if difficulty_controller == null:
        difficulty_controller = get_tree().root.find_child("DifficultyController", true, false)
    _setup_timer()

func _setup_timer() -> void:
    _spawn_timer = Timer.new()
    _spawn_timer.wait_time = 2.0
    _spawn_timer.autostart = true
    _spawn_timer.one_shot = true
    _spawn_timer.timeout.connect(_on_spawn_timeout)
    add_child(_spawn_timer)

func _on_spawn_timeout() -> void:
    if not is_instance_valid(difficulty_controller): return
    var threat = difficulty_controller.get_final_threat_multiplier()
    _spawn_timer.wait_time = difficulty_controller.get_spawn_interval(2.0, 0.5)
    var spawn_count = difficulty_controller.get_spawn_count(1)
    for i in range(spawn_count):
        _spawn_enemy(threat)
    _spawn_timer.start()

func _spawn_enemy(threat: float) -> void:
    var player = get_tree().get_first_node_in_group("player")
    if not player or not enemy_scene: return
    var rect = GameManager.get_meta("map_rect") if GameManager.has_meta("map_rect") else Rect2(-2000,-2000,4000,4000)
    var angle = randf() * TAU
    var spawn_pos = player.position + Vector2.from_angle(angle) * spawn_radius
    # Ограничение спавна
    spawn_pos.x = clamp(spawn_pos.x, rect.position.x + 150, rect.end.x - 150)
    spawn_pos.y = clamp(spawn_pos.y, rect.position.y + 150, rect.end.y - 150)
    
    var enemy = enemy_scene.instantiate()
    enemy.position = spawn_pos
    add_child(enemy)
    if "health_component" in enemy:
        enemy.health_component.max_health *= threat
        enemy.health_component.current_health = enemy.health_component.max_health
    if "xp_value" in enemy: enemy.xp_value = int(10 * threat)
