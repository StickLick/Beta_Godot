extends Area2D
class_name Camp

enum Alignment { NEUTRAL, PLAYER, RIVAL }
@export var alignment: Alignment = Alignment.NEUTRAL

@export var current_level: int = 1:
    set(v):
        current_level = clamp(v, 1, 5)

# Ссылки на узлы и ресурсы
@onready var sprite: Sprite2D = $Sprite
@export var level_textures: Array[Texture2D] = []
@onready var visual_shape: Polygon2D = $Polygon2D # Оставь, если нужно для подсветки

const UNIT_SCENE = preload("res://Assets/Scenes/Unit.tscn")
const BULLET_SCENE = preload("res://Assets/Scenes/Bullet.tscn")
const XP_GEM_SCENE = preload("res://Assets/Scenes/Xp_gem.tscn")

var capture_progress: float = 0.0
var active_units: Array[Node2D] = []
var _upgrade_progress: float = 0.0
var _timers = {"spawn": 0.0, "fire": 0.0, "prod": 0.0}

func _ready() -> void:
    add_to_group("camps")
    
    body_entered.connect(func(b): if b is Player: b.current_camp = self)
    body_exited.connect(func(b): if b is Player and b.current_camp == self: b.current_camp = null)
    
    _update_visuals()
    _apply_level_scale()

func _process(delta: float) -> void:
    active_units = active_units.filter(func(u): return is_instance_valid(u))
    _handle_capture(delta)
    if alignment != Alignment.NEUTRAL:
        _handle_tiers(delta)

func reinforce() -> void:
    _upgrade_progress = min(_upgrade_progress + 60.0, 100.0 * current_level)
    for i in range(2):
        if active_units.size() < 10:
            _spawn_unit()
    var t = create_tween()
    var old = modulate
    modulate = Color(2.5, 2.5, 2.5)
    t.tween_property(self, "modulate", old, 0.4)

func _handle_capture(delta: float) -> void:
    var p_inside = false
    var p_ref = null
    var invaders = 0
    for b in get_overlapping_bodies():
        if b is Player: 
            p_inside = true
            p_ref = b
        elif b is Unit and b.alignment != int(alignment):
            invaders += 1
            
    if (p_inside or invaders > 0) and alignment != Alignment.PLAYER:
        var p_bonus = (p_ref.mass / 25.0) if p_inside else 0.0
        capture_progress += (7.0 + p_bonus + invaders * 3.0) / current_level * delta
        if capture_progress >= 100:
            _flip_to(1 if p_inside else 2)
    elif capture_progress > 0:
        capture_progress = max(0, capture_progress - 5.0 * delta)

func _handle_tiers(delta: float) -> void:
    _timers.fire += delta
    if _timers.fire >= 1.5:
        _timers.fire = 0
        _fire_at_enemy()
    
    if alignment == 1: # PLAYER
        _timers.prod += delta
        if _timers.prod >= 6.0:
            _timers.prod = 0
            _spawn_gem()
            
    if current_level >= 2:
        _timers.spawn += delta
        if _timers.spawn >= 8.0:
            _timers.spawn = 0
            if active_units.size() < 10:
                _spawn_unit()

func _spawn_unit() -> void:
    if not UNIT_SCENE: return
    var u = UNIT_SCENE.instantiate()
    u.global_position = global_position + Vector2.from_angle(randf()*TAU) * 60
    u.alignment = int(alignment)
    u.parent_camp = self
    get_tree().current_scene.add_child(u)
    active_units.append(u)

func _fire_at_enemy() -> void:
    if not BULLET_SCENE: return
    var targets = get_tree().get_nodes_in_group("enemy") if alignment == 1 else [get_tree().get_first_node_in_group("player")]
    var closest = null
    var min_d = 500.0
    for t in targets:
        if is_instance_valid(t):
            var d = global_position.distance_to(t.global_position)
            if d < min_d:
                min_d = d
                closest = t
    if closest:
        var b = BULLET_SCENE.instantiate()
        b.global_position = global_position
        b.look_at(closest.global_position)
        b.faction = "player" if alignment == 1 else "rival"
        get_tree().current_scene.add_child(b)

func _flip_to(new_align: int) -> void:
    alignment = new_align as Alignment
    current_level = 1
    capture_progress = 0
    _update_visuals()
    for u in active_units:
        if is_instance_valid(u): u.flip_alignment(new_align)
    var t = create_tween()
    t.tween_property(self, "scale", Vector2.ONE*1.4, 0.2)
    t.tween_property(self, "scale", Vector2.ONE, 0.2)
    _apply_level_scale()

func upgrade(amount: float) -> void:
    _upgrade_progress += amount
    if _upgrade_progress >= 100.0 * current_level and current_level < 5:
        _upgrade_progress = 0
        current_level += 1
        _apply_level_scale()

func _apply_level_scale() -> void:
    # 1. Масштаб
    var s = 1.0 + (current_level - 1) * 0.2
    create_tween().tween_property(self, "scale", Vector2.ONE * s, 0.5)
    
    # 2. Смена текстуры (берем из массива по индексу level - 1)
    if level_textures.size() >= current_level:
        sprite.texture = level_textures[current_level - 1]

func _update_visuals() -> void:
    var c = Color.GRAY
    if alignment == 1: c = Color(0.1, 0.4, 0.8, 0.5)
    elif alignment == 2: c = Color(0.8, 0.1, 0.1, 0.5)
    if is_instance_valid(visual_shape):
        visual_shape.color = c

func _spawn_gem() -> void:
    if not XP_GEM_SCENE: return
    var g = XP_GEM_SCENE.instantiate()
    g.global_position = global_position + Vector2.from_angle(randf()*TAU)*70
    get_tree().current_scene.add_child(g)
