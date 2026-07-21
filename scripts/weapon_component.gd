class_name WeaponComponent
extends Node2D

signal weapon_maxed(name: String)

@export_group("Identity")
@export var weapon_name: String = "Spear"
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

func _ready() -> void:
    player = get_parent() as Player
    if not is_instance_valid(player):
        player = get_tree().get_first_node_in_group("player")
    
    _setup_physics_auto()
    
    if is_instance_valid(spear_mesh):
        spear_mesh.modulate.a = 0
        _update_shader(0.0, 0.0)
    
    _set_hitbox_active(false)
    cooldown_timer.timeout.connect(_on_cooldown_timeout)
    cooldown_timer.start(attack_cooldown)
    
    # Пример эволюции Аура -> Волна
    if "Wave" in name: _run_wave_logic()

func on_modifier_applied() -> void:
    # Здесь можно обновить визуал при изменении статов (напр. масштаб)
    pass

func _run_wave_logic() -> void:
    while true:
        scale = Vector2.ZERO; modulate.a = 1.0
        var tw = create_tween().set_parallel(true)
        tw.tween_property(self, "scale", Vector2.ONE * 8.0, 1.2)
        tw.tween_property(self, "modulate:a", 0.0, 1.2)
        await tw.finished
        await get_tree().create_timer(0.4).timeout

func _setup_physics_auto() -> void:
    if is_instance_valid(detection_area):
        var shape_node = detection_area.get_node_or_null("CollisionShape2D")
        if shape_node and shape_node.shape is CircleShape2D:
            shape_node.shape.radius = max_attack_distance + 30.0
    if is_instance_valid(hitbox):
        var shape_node = hitbox.get_node_or_null("CollisionShape2D")
        if shape_node and shape_node.shape is RectangleShape2D:
            shape_node.shape.size = Vector2(max_attack_distance + 15.0, 50.0)
            shape_node.position.x = (max_attack_distance - 15.0) / 2.0

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
    var stretch = 1.7 if is_evolution_version else 1.2
    var thickness = 1.2 if is_evolution_version else 1.0
    spear_mesh.position.x = target_dist - (spear_visual_length * stretch * 0.35)
    spear_mesh.scale = Vector2(stretch, thickness)
    spear_mesh.modulate.a = 1.0 
    if is_instance_valid(hitbox):
        hitbox.damage = base_damage * (player.get_final_damage_multiplier() if player else 1.0)
        _set_hitbox_active(true)
    _spawn_glitch_ghost()
    var tween = create_tween().set_parallel(true)
    tween.tween_method(_update_shader.bind(0.06), 0.0, 0.12 if is_evolution_version else 0.05, strike_duration)
    var fade = create_tween()
    fade.tween_interval(strike_duration)
    fade.tween_property(spear_mesh, "modulate:a", 0.0, fade_duration)
    fade.finished.connect(func():
        spear_mesh.position.x = 0
        _set_hitbox_active(false)
    )
    cooldown_timer.start(attack_cooldown)

func _spawn_glitch_ghost() -> void:
    var ghost = spear_mesh.duplicate() as Polygon2D
    ghost.polygon = spear_mesh.polygon
    ghost.material = null; ghost.modulate.a = 0.5 
    get_tree().current_scene.add_child(ghost)
    ghost.global_transform = spear_mesh.global_transform
    var gt = create_tween().set_parallel(false)
    ghost.color = Color.WHITE
    gt.tween_interval(0.03)
    gt.tween_property(ghost, "color", Color(0, 1, 1), 0.08)
    if is_evolution_version: gt.tween_property(ghost, "color", Color(1, 0, 1), 0.12)
    var linger = 0.5 if is_evolution_version else 0.3
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
