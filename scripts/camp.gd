extends Area2D
class_name Camp

enum Alignment { NEUTRAL, PLAYER, RIVAL }
enum Specialty { NONE, INDUSTRY, MILITARY }

@export var alignment: Alignment = Alignment.NEUTRAL
@export var specialty: Specialty = Specialty.NONE

@export var current_level: int = 1:
    set(v):
        current_level = clamp(v, 1, 5)

@onready var sprite: Sprite2D = $Sprite
@export var level_textures: Array[Texture2D] = []
@onready var visual_shape: Polygon2D = $Polygon2D

const UNIT_SCENE = preload("res://Assets/Scenes/Unit.tscn")
const BULLET_SCENE = preload("res://Assets/Scenes/Bullet.tscn")
const XP_GEM_SCENE = preload("res://Assets/Scenes/Xp_gem.tscn")

var capture_progress: float = 0.0
var active_units: Array[Node2D] = []
var _upgrade_progress: float = 0.0
var _timers = {"spawn": 0.0, "fire": 0.0, "prod": 0.0}
var unit_cap: int = 10

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
    if specialty == Specialty.INDUSTRY:
        for i in range(3): _spawn_gem()
    else:
        for i in range(2): if active_units.size() < unit_cap: _spawn_unit()
    
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
            if alignment == Alignment.RIVAL: GameManager.log_event("camp_destroyed")
            _flip_to(1 if p_inside else 2)
    elif capture_progress > 0:
        capture_progress = max(0, capture_progress - 5.0 * delta)

func _handle_tiers(delta: float) -> void:
    # Турель (Military стреляет в 2 раза быстрее)
    var fire_rate = 1.5
    if specialty == Specialty.MILITARY: fire_rate = 0.75
    
    _timers.fire += delta
    if _timers.fire >= fire_rate:
        _timers.fire = 0; _fire_at_enemy()
    
    # Производство ресурсов (Industry работает быстрее)
    if alignment == 1: # PLAYER
        var prod_interval = 6.0
        if specialty == Specialty.INDUSTRY: prod_interval = 2.4 # -60%
        
        _timers.prod += delta
        if _timers.prod >= prod_interval:
            _timers.prod = 0; _spawn_gem()
            
    # Спавн юнитов (Industry НЕ спавнит юнитов)
    if current_level >= 2 and specialty != Specialty.INDUSTRY:
        _timers.spawn += delta
        if _timers.spawn >= 8.0:
            _timers.spawn = 0
            if active_units.size() < unit_cap: _spawn_unit()

func _spawn_unit() -> void:
    if not UNIT_SCENE: return
    var u = UNIT_SCENE.instantiate()
    u.global_position = global_position + Vector2.from_angle(randf()*TAU) * 60
    u.alignment = int(alignment)
    u.parent_camp = self
    get_tree().current_scene.add_child(u)
    active_units.append(u)
    GameManager.log_event("unit_spawned")

func _fire_at_enemy() -> void:
    if not BULLET_SCENE: return
    var targets = get_tree().get_nodes_in_group("enemy") if alignment == 1 else [get_tree().get_first_node_in_group("player")]
    var closest = null
    var min_d = 500.0
    for t in targets:
        if is_instance_valid(t):
            var d = global_position.distance_to(t.global_position)
            if d < min_d: min_d = d; closest = t
    if closest:
        var b = BULLET_SCENE.instantiate()
        b.global_position = global_position
        b.look_at(closest.global_position)
        b.faction = "player" if alignment == 1 else "rival"
        get_tree().current_scene.add_child(b)

func _flip_to(new_align: int) -> void:
    alignment = new_align as Alignment
    current_level = 1
    specialty = Specialty.NONE
    capture_progress = 0
    unit_cap = 10
    _update_visuals()
    for u in active_units: if is_instance_valid(u): u.flip_alignment(new_align)
    var t = create_tween()
    t.tween_property(self, "scale", Vector2.ONE*1.4, 0.2)
    t.tween_property(self, "scale", Vector2.ONE, 0.2)
    _apply_level_scale()

func upgrade(amount: float) -> void:
    _upgrade_progress += amount
    if _upgrade_progress >= 100.0 * current_level and current_level < 5:
        _upgrade_progress = 0
        current_level += 1
        if current_level == 3: _auto_choose_specialty()
        _apply_level_scale()
        _update_visuals()
        _refresh_player_buffs()

func _auto_choose_specialty() -> void:
    if alignment == Alignment.PLAYER:
        var p = get_tree().get_first_node_in_group("player")
        specialty = Specialty.MILITARY if p.mass > 150 else Specialty.INDUSTRY
    else:
        specialty = Specialty.MILITARY if randf() > 0.5 else Specialty.INDUSTRY
    
    if specialty == Specialty.MILITARY: unit_cap = 15

func _apply_level_scale() -> void:
    var s = 1.0 + (current_level - 1) * 0.2
    create_tween().tween_property(self, "scale", Vector2.ONE * s, 0.5)
    if level_textures.size() >= current_level and is_instance_valid(sprite):
        sprite.texture = level_textures[current_level - 1]

func _update_visuals() -> void:
    var c = Color.GRAY
    if alignment == 1: 
        c = Color(0.1, 0.4, 0.8, 0.5)
        if specialty == Specialty.INDUSTRY: c = Color(1.0, 0.84, 0.0, 0.6) # Gold
        elif specialty == Specialty.MILITARY: c = Color(0.44, 0.5, 0.56, 0.7) # Steel
    elif alignment == 2: 
        c = Color(0.8, 0.1, 0.1, 0.5)
    if is_instance_valid(visual_shape): visual_shape.color = c

func _spawn_gem() -> void:
    if not XP_GEM_SCENE: return
    var g = XP_GEM_SCENE.instantiate()
    g.global_position = global_position + Vector2.from_angle(randf()*TAU)*70
    if specialty == Specialty.INDUSTRY: g.xp_amount = int(g.xp_amount * 2.5)
    get_tree().current_scene.add_child(g)

func _refresh_player_buffs() -> void:
    for b in get_overlapping_bodies():
        if b is Player and alignment == 1:
            b.apply_complex_camp_buffs({"speed": 0.1*current_level, "damage": 0.1*current_level, "stability": 0.2*current_level, "regen": 1.0*current_level})

func is_player_alignment() -> bool: return alignment == Alignment.PLAYER
