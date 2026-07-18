extends Node2D

@export var enemy_scene: PackedScene = null
@export var spawn_radius: float = 750.0
@export var difficulty_controller: DifficultyController = null

var _spawn_timer: Timer

func _ready() -> void:
    if difficulty_controller == null:
        difficulty_controller = get_tree().root.find_child("DifficultyController", true, false)
    _setup_timer()

func _setup_timer() -> void:
    _spawn_timer = Timer.new()
    _spawn_timer.wait_time = 4.0 # Увеличена начальная пауза
    _spawn_timer.autostart = true
    _spawn_timer.one_shot = true
    _spawn_timer.timeout.connect(_on_spawn_timeout)
    add_child(_spawn_timer)

func _on_spawn_timeout() -> void:
    if not is_instance_valid(difficulty_controller): return
    
    var threat = difficulty_controller.get_final_threat_multiplier()
    _spawn_timer.wait_time = difficulty_controller.get_spawn_interval(4.0, 1.0)
    
    # СНИЖЕНИЕ СЛОЖНОСТИ: множитель 0.4 вместо 0.6 (меньше врагов в волне)
    var spawn_count = int(ceil(difficulty_controller.get_spawn_count(1) * 0.4))
    
    for i in range(spawn_count):
        _spawn_logic(threat)
        
    _spawn_timer.start()

func _spawn_logic(threat: float) -> void:
    var archetype = _get_random_archetype()
    var player = get_tree().get_first_node_in_group("player")
    if not is_instance_valid(player): return

    var spawn_center = player.global_position
    
    if archetype == Enemy.Archetype.BREAKER:
        var player_camps = get_tree().get_nodes_in_group("camps").filter(func(c): return is_instance_valid(c) and c.alignment == 1)
        if not player_camps.is_empty():
            spawn_center = player_camps.pick_random().global_position
    
    if archetype == Enemy.Archetype.SWARMER and randf() < 0.12:
        for i in range(3): # Уменьшено количество в группе
            _spawn_enemy(threat, archetype, spawn_center, Vector2(randf_range(-60, 60), randf_range(-60, 60)))
    else:
        _spawn_enemy(threat, archetype, spawn_center)

func _spawn_enemy(threat: float, type: Enemy.Archetype, center_pos: Vector2, offset: Vector2 = Vector2.ZERO) -> void:
    if not enemy_scene: return
    var angle = randf() * TAU
    var spawn_pos = center_pos + Vector2.from_angle(angle) * spawn_radius + offset
    var rect = GameManager.get_meta("map_rect") if GameManager.has_meta("map_rect") else Rect2(-2000,-2000,4000,4000)
    spawn_pos.x = clamp(spawn_pos.x, rect.position.x + 150, rect.end.x - 150)
    spawn_pos.y = clamp(spawn_pos.y, rect.position.y + 150, rect.end.y - 150)

    var enemy = enemy_scene.instantiate() as Enemy
    enemy.position = spawn_pos
    add_child(enemy)
    enemy.setup_archetype(type)
    
    if is_instance_valid(enemy.health_component):
        # СНИЖЕНИЕ СЛОЖНОСТИ: враги слабее на 20%
        enemy.health_component.max_health *= (threat * 0.7)
        enemy.health_component.current_health = enemy.health_component.max_health

func _get_random_archetype() -> Enemy.Archetype:
    var time = GameManager.time_elapsed
    var roll = randf() * 100.0
    if time < 180.0:
        if roll < 98: return Enemy.Archetype.SWARMER
        return Enemy.Archetype.BREAKER # Брекеры стали еще реже в начале
    elif time < 420.0:
        if roll < 65: return Enemy.Archetype.SWARMER
        if roll < 90: return Enemy.Archetype.BREAKER
        return Enemy.Archetype.DISRUPTOR
    else:
        if roll < 40: return Enemy.Archetype.SWARMER
        if roll < 70: return Enemy.Archetype.BREAKER
        return Enemy.Archetype.DISRUPTOR
