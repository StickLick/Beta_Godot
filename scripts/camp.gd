extends Area2D
class_name Camp

enum Alignment { NEUTRAL, PLAYER, RIVAL }

@export_group("Camp Stats")
@export var alignment: Alignment = Alignment.NEUTRAL
@export var current_level: int = 1
@export var production_interval: float = 6.0

@onready var visual_shape: Polygon2D = $Polygon2D 
const XP_GEM_SCENE = preload("res://Assets/Scenes/Xp_gem.tscn")
var _upgrade_progress: float = 0.0
var _production_timer: float = 0.0

func _ready() -> void:
    add_to_group("camps")
    # ПРОВЕРЬТЕ: Сигналы должны быть подключены в инспекторе или здесь
    if not body_entered.is_connected(_on_body_entered):
        body_entered.connect(_on_body_entered)
    if not body_exited.is_connected(_on_body_exited):
        body_exited.connect(_on_body_exited)
        
    _update_visuals()
    _apply_level_scale()

func _process(delta: float) -> void:
    if alignment == Alignment.PLAYER:
        _process_production(delta)
    _resolve_camp_conflicts(delta)

func is_player_alignment() -> bool:
    return alignment == Alignment.PLAYER

func upgrade(mass_amount: float) -> void:
    _upgrade_progress += mass_amount
    var threshold = 100.0 * current_level 
    
    # ЕСЛИ МАССА ТРАТИТСЯ, ВЫ УВИДИТЕ ЭТО:
    print("[CAMP DEBUG] Receiving mass: ", mass_amount, " | Total: ", _upgrade_progress, "/", threshold)
    
    if _upgrade_progress >= threshold:
        _upgrade_progress = 0.0
        current_level += 1
        _apply_level_scale()
        print("[CAMP] !!! LEVEL UP: ", current_level, " !!!")

func _resolve_camp_conflicts(delta: float) -> void:
    var other_camps = get_tree().get_nodes_in_group("camps")
    for other in other_camps:
        if other == self or not is_instance_valid(other): continue
        var dist = global_position.distance_to(other.global_position)
        var my_radius = 150.0 * scale.x
        var other_radius = 150.0 * other.scale.x
        
        if dist < (my_radius + other_radius):
            if other.alignment == alignment: _merge_with(other)
            else: _fight_with(other, delta)

func _merge_with(other: Camp) -> void:
    if current_level >= other.current_level:
        upgrade(other.current_level * 50.0)
        other.queue_free()

func _fight_with(other: Camp, delta: float) -> void:
    var power_diff = float(current_level) / float(other.current_level)
    var damage = 20.0 * delta * power_diff
    other.reduce_progress(damage)
    if other.current_level <= 0:
        upgrade(20.0)
        other.queue_free()

func reduce_progress(amount: float) -> void:
    _upgrade_progress -= amount
    if _upgrade_progress < 0:
        current_level -= 1
        _upgrade_progress = 50.0
        _apply_level_scale()
        if current_level <= 0: queue_free()

func _process_production(delta: float) -> void:
    _production_timer += delta
    if _production_timer >= production_interval:
        _production_timer = 0.0
        _spawn_gem()

func _spawn_gem() -> void:
    if not is_inside_tree(): return
    var gem = XP_GEM_SCENE.instantiate()
    gem.global_position = global_position + Vector2.from_angle(randf() * TAU) * 70.0
    if "xp_amount" in gem: gem.xp_amount = 10 * current_level 
    get_tree().current_scene.add_child(gem)

func _apply_level_scale() -> void:
    var target_scale = Vector2.ONE * (1.0 + (current_level - 1) * 0.2)
    var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "scale", target_scale, 0.5)

func _update_visuals() -> void:
    if not is_instance_valid(visual_shape): return
    match alignment:
        Alignment.PLAYER: visual_shape.color = Color(0.1, 0.4, 0.8, 0.4)
        Alignment.RIVAL: visual_shape.color = Color(0.8, 0.1, 0.1, 0.4)
        Alignment.NEUTRAL: visual_shape.color = Color(0.3, 0.3, 0.3, 0.4)

func _on_body_entered(body: Node2D) -> void:
    if body is Player: 
        print("[CAMP INFO] Player entered camp area!") # ОБЯЗАТЕЛЬНО ПОЯВИТСЯ В КОНСОЛИ
        body.current_camp = self

func _on_body_exited(body: Node2D) -> void:
    if body is Player and body.current_camp == self: 
        print("[CAMP INFO] Player exited camp area!")
        body.current_camp = null
