extends Area2D
class_name Camp

signal specialty_requested(camp_ref: Camp)

enum Alignment { NEUTRAL, PLAYER, RIVAL }
enum Specialty { NONE, INDUSTRY, MILITARY }

@export var alignment: Alignment = Alignment.NEUTRAL
@export var specialty: Specialty = Specialty.NONE
@export var current_level: int = 1:
    set(v): current_level = clamp(v, 1, 5)

@onready var sprite: Sprite2D = $Sprite
@export var level_textures: Array[Texture2D] = []
@onready var visual_shape: Polygon2D = $Polygon2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent

const UNIT_SCENE = preload("res://Assets/Scenes/Unit.tscn")
const BULLET_SCENE = preload("res://Assets/Scenes/Bullet.tscn")
const XP_GEM_SCENE = preload("res://Assets/Scenes/Xp_gem.tscn")

var capture_progress: float = 0.0
var active_units: Array[Node2D] = []
var _upgrade_progress: float = 0.0
var _timers = {"spawn": 0.0, "fire": 0.0, "prod": 0.0}
var unit_cap: int = 10
var _scale_tween: Tween

var is_under_attack: bool = false
var _attack_timer: float = 0.0
var _last_health: float = 0.0

const BASE_HEALTH: float = 8000.0 
const ARMOR_THRESHOLD: float = 20.0 
const SERIOUS_DAMAGE_THRESHOLD: float = 50.0 

func _ready() -> void:
    add_to_group("camps")
    z_index = 0
    
    # ИСПРАВЛЕНО: Используем именованные функции вместо лямбд
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)
    
    if is_instance_valid(health_component):
        health_component.max_health = BASE_HEALTH * current_level
        health_component.current_health = health_component.max_health
        _last_health = health_component.current_health
        if not health_component.health_depleted.is_connected(_on_health_depleted):
            health_component.health_depleted.connect(_on_health_depleted)
    
    _update_visuals()
    _apply_level_scale()

func _on_body_entered(body: Node2D) -> void:
    if body is Player:
        body.current_camp = self

func _on_body_exited(body: Node2D) -> void:
    if body is Player and body.current_camp == self:
        body.current_camp = null

func _process(delta: float) -> void:
    active_units = active_units.filter(func(u): return is_instance_valid(u))
    _handle_capture(delta)
    
    if is_instance_valid(health_component):
        if health_component.current_health < _last_health:
            if (_last_health - health_component.current_health) >= SERIOUS_DAMAGE_THRESHOLD:
                is_under_attack = true; _attack_timer = 4.0
        _last_health = health_component.current_health
    
    if _attack_timer > 0:
        _attack_timer -= delta
        if _attack_timer <= 0: is_under_attack = false
    
    if alignment != Alignment.NEUTRAL:
        _handle_tiers(delta)
        _process_auto_repair(delta)

func _process_auto_repair(delta: float) -> void:
    var has_enemies = false
    for b in get_overlapping_bodies(): if b is Enemy: has_enemies = true; break
    if not has_enemies and is_instance_valid(health_component):
        if health_component.current_health < health_component.max_health:
            health_component.current_health += (health_component.max_health * 0.01) * delta

func _apply_damage(amount: float) -> void:
    if amount < ARMOR_THRESHOLD: return 
    is_under_attack = true; _attack_timer = 4.0
    if alignment == Alignment.PLAYER:
        _upgrade_progress -= amount * 0.1
        var t = create_tween(); modulate = Color(2, 0.5, 0.5)
        t.tween_property(self, "modulate", Color.WHITE, 0.2)
        if _upgrade_progress < -500.0: _on_health_depleted()

func _on_health_depleted() -> void:
    is_under_attack = true; _attack_timer = 5.0
    if current_level > 1:
        current_level -= 1; _upgrade_progress = 0; _apply_level_scale(); _update_visuals()
        if is_instance_valid(health_component):
            health_component.max_health = BASE_HEALTH * current_level
            health_component.current_health = health_component.max_health
    else:
        if alignment == Alignment.PLAYER: _flip_to(Alignment.RIVAL)
        elif alignment == Alignment.RIVAL: _flip_to(Alignment.PLAYER)
        else: _flip_to(Alignment.NEUTRAL)

func reinforce() -> void:
    if is_instance_valid(health_component): health_component.current_health = min(health_component.current_health + 1000, health_component.max_health)
    if specialty == Specialty.INDUSTRY:
        for i in range(3): _spawn_gem()
    else:
        for i in range(2): if active_units.size() < unit_cap: _spawn_unit()
    var t = create_tween(); modulate = Color(3, 3, 3); t.tween_property(self, "modulate", Color.WHITE, 0.4)

func _handle_capture(delta: float) -> void:
    var invaders = 0; var p_inside = false; var p_ref = null
    for b in get_overlapping_bodies():
        if b is Player: p_inside = true; p_ref = b
        elif b is Unit and b.alignment != int(alignment): invaders += 1
    if invaders >= 2: is_under_attack = true; _attack_timer = 1.0
    if (p_inside or invaders > 0) and alignment != Alignment.PLAYER:
        var p_bonus = (p_ref.mass / 20.0) if p_inside else 0.0
        capture_progress += (8.0 + p_bonus + invaders * 4.0) / current_level * delta
        if capture_progress >= 100:
            if alignment == Alignment.RIVAL: GameManager.log_event("camp_destroyed")
            _flip_to(Alignment.PLAYER if p_inside else Alignment.RIVAL)
    elif capture_progress > 0: capture_progress = max(0, capture_progress - 5.0 * delta)

func _handle_tiers(delta: float) -> void:
    var prod_mult = GameManager.get_meta("prod_mult") if GameManager.has_meta("prod_mult") else 1.0
    var fire_rate = (1.6 - (current_level * 0.2)) * prod_mult
    if specialty == Specialty.MILITARY: fire_rate *= 0.4 
    _timers.fire += delta
    if _timers.fire >= fire_rate:
        _timers.fire = 0; _fire_at_enemy()
    if alignment == 1:
        var prod_interval = 6.0 * prod_mult
        if specialty == Specialty.INDUSTRY: prod_interval *= 0.3
        _timers.prod += delta
        if _timers.prod >= prod_interval:
            _timers.prod = 0; _spawn_gem()
    if current_level >= 2 and specialty != Specialty.INDUSTRY:
        var spawn_interval = 8.0 * prod_mult
        _timers.spawn += delta
        if _timers.spawn >= spawn_interval:
            _timers.spawn = 0; if active_units.size() < unit_cap: _spawn_unit()

func _spawn_unit() -> void:
    if not UNIT_SCENE: return
    var u = UNIT_SCENE.instantiate(); u.global_position = global_position + Vector2.from_angle(randf()*TAU) * 60
    u.alignment = int(alignment); u.parent_camp = self; get_tree().current_scene.add_child(u)
    active_units.append(u); GameManager.log_event("unit_spawned")

func _fire_at_enemy() -> void:
    if not BULLET_SCENE: return
    var targets = []; if alignment == 1:
        targets.append_array(get_tree().get_nodes_in_group("enemy"))
        var r_units = get_tree().get_nodes_in_group("units").filter(func(u): return u.alignment == 2)
        targets.append_array(r_units)
    else:
        targets.append(get_tree().get_first_node_in_group("player"))
        var b_units = get_tree().get_nodes_in_group("units").filter(func(u): return u.alignment == 1)
        targets.append_array(b_units)
    var priority_targets = targets.filter(func(t): return is_instance_valid(t) and t is Enemy and t.current_archetype == Enemy.Archetype.BREAKER)
    var final_targets = priority_targets if not priority_targets.is_empty() else targets
    var closest = null; var min_d = 650.0
    for t in final_targets:
        if is_instance_valid(t):
            var d = global_position.distance_to(t.global_position); if d < min_d: min_d = d; closest = t
    if closest:
        var b = BULLET_SCENE.instantiate()
        b.faction = "player" if alignment == 1 else "rival"
        b.global_position = global_position; b.look_at(closest.global_position)
        var base_dmg = 10.0 + (current_level * 5.0); if specialty == Specialty.MILITARY: base_dmg *= 2.0
        if "damage" in b: b.damage = base_dmg
        get_tree().current_scene.add_child(b)

func _flip_to(new_align: int) -> void:
    alignment = new_align as Alignment
    current_level = 1; specialty = Specialty.NONE; capture_progress = 0; _upgrade_progress = 0
    _update_visuals()
    if is_instance_valid(health_component):
        health_component.max_health = BASE_HEALTH; health_component.current_health = BASE_HEALTH; _last_health = BASE_HEALTH
    for u in active_units: if is_instance_valid(u): u.flip_alignment(new_align)
    _apply_level_scale()

func upgrade(amount: float) -> void:
    if current_level == 3 and specialty == Specialty.NONE:
        if alignment == 1: specialty_requested.emit(self)
        else: apply_specialty(2 if randf() > 0.5 else 1)
        return
    _upgrade_progress += amount
    if _upgrade_progress >= 150.0 * current_level and current_level < 5:
        _upgrade_progress = 0; current_level += 1
        if is_instance_valid(health_component):
            health_component.max_health = BASE_HEALTH * current_level
            health_component.current_health = health_component.max_health; _last_health = health_component.max_health
        _apply_level_scale(); _update_visuals(); _refresh_player_buffs()

func apply_specialty(type: int) -> void:
    specialty = type as Specialty; unit_cap = 15 if specialty == Specialty.MILITARY else 10
    if specialty == Specialty.INDUSTRY:
        for u in active_units: if is_instance_valid(u): u.queue_free()
        active_units.clear()
    _update_visuals(); _upgrade_progress = 0

func _apply_level_scale() -> void:
    if _scale_tween: _scale_tween.kill()
    var s = 1.0 + (current_level - 1) * 0.2
    _scale_tween = create_tween(); _scale_tween.tween_property(self, "scale", Vector2.ONE * s, 0.4).set_trans(Tween.TRANS_SINE)
    if level_textures.size() >= current_level and is_instance_valid(sprite): sprite.texture = level_textures[current_level - 1]

func _update_visuals() -> void:
    var c = Color(0.7, 0.7, 0.7, 0.6); var f = "enemy"
    if alignment == 1: 
        c = Color(0.2, 0.5, 1.0, 0.7); f = "player"
        if specialty == Specialty.INDUSTRY: c = Color(1.0, 0.8, 0.0, 0.8)
        elif specialty == Specialty.MILITARY: c = Color(0.4, 0.5, 0.6, 0.8)
    elif alignment == 2: 
        c = Color(1.0, 0.2, 0.2, 0.7); f = "rival"
    if is_instance_valid(visual_shape): visual_shape.color = c
    if is_instance_valid(hurtbox): 
        hurtbox.faction = f
        hurtbox.collision_layer = 2 if alignment == 1 else 8

func _spawn_gem() -> void:
    if not XP_GEM_SCENE: return
    var g = XP_GEM_SCENE.instantiate(); g.global_position = global_position + Vector2.from_angle(randf()*TAU)*70
    if specialty == Specialty.INDUSTRY: g.xp_amount = int(g.xp_amount * 3.5)
    get_tree().current_scene.add_child(g)

func _refresh_player_buffs() -> void:
    for b in get_overlapping_bodies():
        if b is Player and alignment == 1:
            b.apply_complex_camp_buffs({"speed": 0.1*current_level, "damage": 0.1*current_level, "stability": 0.2*current_level, "regen": 1.5*current_level})

func is_player_alignment() -> bool: return alignment == Alignment.PLAYER
