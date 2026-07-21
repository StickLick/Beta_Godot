class_name WeaponComponent
extends Node2D

signal weapon_maxed(name: String)

@export_group("Identity")
@export var weapon_name: String = "Spear"
@export var current_level: int = 1
@export var max_level: int = 8
@export var is_evolution_version: bool = false 

@export_group("Stats")
@export var base_damage: float = 15.0
@export var attack_cooldown: float = 1.0:
    set(value):
        attack_cooldown = max(0.05, value)
        if is_instance_valid(cooldown_timer):
            cooldown_timer.wait_time = attack_cooldown

@export_group("Glitch Juice")
@export var max_attack_distance: float = 250.0 
@export var strike_duration: float = 0.05
@export var fade_duration: float = 0.25
@export var spear_visual_length: float = 120.0 

@onready var visual_pivot: Node2D = $VisualPivot
@onready var spear_mesh: Polygon2D = $VisualPivot/Polygon2D 
@onready var cooldown_timer: Timer = $CooldownTimer
@onready var detection_area: Area2D = $DetectionArea
@onready var hitbox: HitboxComponent = find_child("HitboxComponent", true)

var player: Player
var is_evolved: bool = false

func _ready() -> void:
    player = get_parent() as Player
    if not is_instance_valid(player):
        player = get_tree().get_first_node_in_group("player")
    
    is_evolved = is_evolution_version or current_level >= 8
    _setup_physics_auto()
    
    if is_instance_valid(spear_mesh):
        spear_mesh.modulate.a = 0
        _update_shader(0.0, 0.0)
    
    _set_hitbox_active(false)
    cooldown_timer.timeout.connect(_on_cooldown_timeout)
    cooldown_timer.start(attack_cooldown)

func _setup_physics_auto() -> void:
    if is_instance_valid(detection_area):
        var shape_node = detection_area.get_node_or_null("CollisionShape2D")
        if shape_node and shape_node.shape is CircleShape2D:
            shape_node.shape.radius = max_attack_distance + 30.0
    
    if is_instance_valid(hitbox):
        var shape_node = hitbox.get_node_or_null("CollisionShape2D")
        if shape_node and shape_node.shape is RectangleShape2D:
            # ИСПРАВЛЕНИЕ: Заход назад всего на 15 пикселей для ближнего боя
            var reach_back = 15.0
            shape_node.shape.size.x = max_attack_distance + reach_back
            shape_node.position.x = (max_attack_distance - reach_back) / 2.0
            shape_node.shape.size.y = 50.0

func _on_cooldown_timeout() -> void:
    var target = _get_closest_target()
    if target == null:
        cooldown_timer.start(0.2); return

    var dist = global_position.distance_to(target.global_position)
    if dist <= max_attack_distance:
        visual_pivot.look_at(target.global_position)
        if is_instance_valid(player): player.play_attack_animation(target.global_position)
        _perform_glitch_strike(dist)
    else:
        cooldown_timer.start(0.1)

func _perform_glitch_strike(target_dist: float) -> void:
    if not is_instance_valid(spear_mesh): return
    
    var lunge = target_dist
    var stretch = 1.7 if is_evolved else 1.1
    var thickness = 1.2 if is_evolved else 1.0
    
    spear_mesh.position.x = target_dist - (spear_visual_length * stretch * 0.35)
    spear_mesh.scale = Vector2(stretch, thickness)
    spear_mesh.modulate.a = 1.0 
    
    var multiplier = player.get_final_damage_multiplier() if is_instance_valid(player) else 1.0
    if is_instance_valid(hitbox):
        hitbox.damage = base_damage * multiplier
        _set_hitbox_active(true)

    _spawn_glitch_ghost()

    var tween = create_tween().set_parallel(true)
    var strength = 0.12 if is_evolved else 0.05
    tween.tween_method(_update_shader.bind(0.06), 0.0, strength, strike_duration)
    
    var fade = create_tween()
    fade.tween_interval(strike_duration)
    fade.tween_property(spear_mesh, "modulate:a", 0.0, fade_duration)
    fade.parallel().tween_method(_update_shader.bind(0.0), strength, 0.0, fade_duration)
    
    fade.finished.connect(func():
        spear_mesh.position.x = 0
        _set_hitbox_active(false)
    )
    cooldown_timer.start(attack_cooldown)

func _spawn_glitch_ghost() -> void:
    var ghost = spear_mesh.duplicate() as Polygon2D
    ghost.polygon = spear_mesh.polygon
    ghost.material = null 
    ghost.modulate.a = 0.4 
    
    get_tree().current_scene.add_child(ghost)
    ghost.global_transform = spear_mesh.global_transform
    
    var gt = create_tween().set_parallel(false)
    ghost.color = Color.WHITE
    gt.tween_interval(0.03)
    gt.tween_property(ghost, "color", Color(0, 1, 1), 0.08)
    if is_evolved:
        gt.tween_property(ghost, "color", Color(1, 0, 1), 0.12)
    
    var linger = 0.45 if is_evolved else 0.25
    var final_fade = create_tween().set_parallel(true)
    final_fade.tween_property(ghost, "modulate:a", 0.0, linger)
    final_fade.tween_property(ghost, "scale:y", 0.01, linger)
    
    gt.finished.connect(ghost.queue_free)

func _update_shader(strength: float, split: float) -> void:
    if is_instance_valid(spear_mesh) and spear_mesh.material is ShaderMaterial:
        spear_mesh.material.set_shader_parameter("glitch_strength", strength)
        spear_mesh.material.set_shader_parameter("color_split", split)

func _get_closest_target() -> Area2D:
    var closest: Area2D = null
    var dist_sq: float = INF
    for area in detection_area.get_overlapping_areas():
        if area.has_method("_apply_damage") and area.get("faction") != "player":
            var d = global_position.distance_squared_to(area.global_position)
            if d < dist_sq: dist_sq = d; closest = area
    return closest

func _set_hitbox_active(active: bool) -> void:
    if is_instance_valid(hitbox):
        var shape = hitbox.get_node_or_null("CollisionShape2D")
        if shape: shape.set_deferred("disabled", !active)

func level_up() -> void:
    if current_level >= max_level: return
    current_level += 1
    if current_level in [2, 4, 6]: attack_cooldown *= 0.8
    if current_level in [3, 5, 7]: base_damage *= 1.2
    if current_level == max_level: 
        is_evolved = true
        weapon_maxed.emit(weapon_name)

func update_weapon_range(new_range_mult: float) -> void:
    if is_instance_valid(visual_pivot):
        visual_pivot.scale = Vector2.ONE * new_range_mult
