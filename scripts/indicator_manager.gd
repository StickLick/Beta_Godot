extends Control

@export var indicator_scene: PackedScene = preload("res://Assets/Scenes/Indicator.tscn")
@export var pool_size: int = 20

var _indicator_pool: Array[Control] = []

func _ready() -> void:
    for child in get_children():
        child.queue_free()
    _indicator_pool.clear()
        
    for i in range(pool_size):
        var inst = indicator_scene.instantiate()
        inst.hide()
        add_child(inst)
        _indicator_pool.append(inst)

func _process(_delta: float) -> void:
    _update_indicators_logic()

func _update_indicators_logic() -> void:
    var cam = get_viewport().get_camera_2d()
    if not cam: return
    
    var screen_rect = get_viewport_rect()
    
    # 1. Собираем только критические цели
    var all_targets = []
    
    # ФИЛЬТР: Берем только лагеря игрока (Alignment 1)
    var player_camps = get_tree().get_nodes_in_group("camps").filter(
        func(c): return is_instance_valid(c) and c.alignment == 1
    )
    all_targets.append_array(player_camps)
    
    # Босс всегда виден
    var boss = get_tree().get_first_node_in_group("rival_boss")
    if boss: all_targets.append(boss)
    
    var off_screen_targets = []
    for t in all_targets:
        if not is_instance_valid(t) or t.is_queued_for_deletion(): continue
        if t in off_screen_targets: continue
        
        if not _is_on_screen(t, screen_rect):
            off_screen_targets.append(t)
    
    # 2. Скрываем пул
    for ind in _indicator_pool:
        ind.hide()
    
    # 3. Распределяем
    var count = min(off_screen_targets.size(), _indicator_pool.size())
    for i in range(count):
        var target = off_screen_targets[i]
        var indicator = _indicator_pool[i]
        
        indicator.setup(target)
        indicator.update_indicator(screen_rect)
        indicator.show()

func _is_on_screen(target: Node2D, rect: Rect2) -> bool:
    var screen_pos = target.get_global_transform_with_canvas().origin
    var margin = 60.0 
    var safe_rect = rect.grow(-margin)
    return safe_rect.has_point(screen_pos)
