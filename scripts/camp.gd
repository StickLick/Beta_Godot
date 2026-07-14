extends Area2D
class_name Camp

enum Alignment { NEUTRAL, PLAYER, RIVAL }

@export_group("Camp Stats")
@export var alignment: Alignment = Alignment.NEUTRAL
@export var current_level: int = 1:
    set(v): current_level = clamp(v, 1, 5)
@export var unit_spawn_cooldown: float = 8.0

@onready var visual_shape: Polygon2D = $Polygon2D

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

func is_player_alignment() -> bool:
    return alignment == Alignment.PLAYER

func _handle_capture(delta: float) -> void:
    var player_inside = false
    var p_ref = null
    var invaders = 0
    
    for body in get_overlapping_bodies():
        if body is Player: 
            player_inside = true
            p_ref = body
        elif body is Unit and body.alignment != int(alignment):
            invaders += 1

    if (player_inside or invaders > 0) and alignment != Alignment.PLAYER:
        var p_bonus = (p_ref.mass / 25.0) if player_inside else 0.0
        capture_progress += (7.0 + p_bonus + invaders * 3.0) / current_level * delta
        if capture_progress >= 100:
            _flip_to(Alignment.PLAYER if player_inside else Alignment.RIVAL)
    elif capture_progress > 0:
        capture_progress = max(0, capture_progress - 5.0 * current_level * delta)

func _handle_tiers(delta: float) -> void:
    # ТУРЕЛЬ ТЕПЕРЬ С 1 УРОВНЯ
    _timers.fire += delta
    if _timers.fire >= 1.5:
        _timers.fire = 0
        _fire_at_enemy()

    # Гемы (только синий лагерь)
    if alignment == Alignment.PLAYER:
        _timers.prod += delta
        if _timers.prod >= 6.0:
            _timers.prod = 0; _spawn_gem()
    
    # Юниты со 2 уровня
    if current_level >= 2:
        _timers.spawn += delta
        if _timers.spawn >= unit_spawn_cooldown:
            _timers.spawn = 0
            if active_units.size() < 10: _spawn_unit()

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
    var targets = []
    
    if alignment == Alignment.PLAYER:
        targets.append_array(get_tree().get_nodes_in_group("enemy"))
        var r_units = get_tree().get_nodes_in_group("units").filter(func(u): return u.alignment == 2)
        targets.append_array(r_units)
    else:
        targets.append(get_tree().get_first_node_in_group("player"))
        var b_units = get_tree().get_nodes_in_group("units").filter(func(u): return u.alignment == 1)
        targets.append_array(b_units)
    
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
        if "faction" in b: b.faction = "player" if alignment == Alignment.PLAYER else "rival"
        get_tree().current_scene.add_child(b)

func _flip_to(new_alignment: Alignment) -> void:
    alignment = new_alignment
    current_level = 1
    capture_progress = 0
    _update_visuals()
    for u in active_units: if is_instance_valid(u): u.flip_alignment(int(alignment))
    var tween = create_tween()
    tween.tween_property(self, "scale", Vector2.ONE * 1.4, 0.2)
    tween.tween_property(self, "scale", Vector2.ONE, 0.2)

func upgrade(amount: float) -> void:
    _upgrade_progress += amount
    if _upgrade_progress >= 100.0 * current_level and current_level < 5:
        _upgrade_progress = 0
        current_level += 1
        _apply_level_scale()
        _refresh_player_buffs()

func _refresh_player_buffs() -> void:
    for b in get_overlapping_bodies():
        if b is Player and alignment == Alignment.PLAYER:
            b.apply_complex_camp_buffs({"speed": 0.1*current_level, "damage": 0.1*current_level, "stability": 0.2*current_level, "regen": 1.0*current_level})

func _apply_level_scale() -> void:
    var s = 1.0 + (current_level - 1) * 0.2
    create_tween().tween_property(self, "scale", Vector2.ONE * s, 0.5)

func _update_visuals() -> void:
    var c = Color.GRAY
    if alignment == Alignment.PLAYER: c = Color(0.1, 0.4, 0.8, 0.5)
    elif alignment == Alignment.RIVAL: c = Color(0.8, 0.1, 0.1, 0.5)
    if is_instance_valid(visual_shape): visual_shape.color = c

func _spawn_gem() -> void:
    if not XP_GEM_SCENE: return
    var g = XP_GEM_SCENE.instantiate()
    g.global_position = global_position + Vector2.from_angle(randf()*TAU)*70
    get_tree().current_scene.add_child(g)
