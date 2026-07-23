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
@onready var spear_visual: CanvasItem = _find_visual()
@onready var aura_sprite: Sprite2D = get_node_or_null("VisualPivot/Sprite2D")

@onready var cooldown_timer: Timer = $CooldownTimer
@onready var detection_area: Area2D = $DetectionArea
@onready var hitbox: HitboxComponent = find_child("HitboxComponent", true)

var player: Player

func _ready() -> void:
    if "Wave" in name:
        _run_wave_logic()
    
    player = get_parent() as Player
    if not is_instance_valid(player):
        player = get_tree().get_first_node_in_group("player")
    
    _setup_physics_auto()
    
    if weapon_name == "Aura":
        _set_hitbox_active(true)
        if is_instance_valid(aura_sprite):
            aura_sprite.modulate = Color(0.4, 0.7, 1.0, 1.0)
            aura_sprite.scale = Vector2.ONE
            # Применяем радиальный шейдер для маскировки прямоугольника текстуры
            var aura_shader = load("res://Shaders/AuraRadial.gdshader")
            if aura_shader:
                aura_sprite.material = ShaderMaterial.new()
                aura_sprite.material.shader = aura_shader
        return
    
    if is_instance_valid(spear_visual):
        spear_visual.modulate.a = 0
        _update_shader(0.0, 0.0)
    
    _set_hitbox_active(false)
    cooldown_timer.timeout.connect(_on_cooldown_timeout)
    cooldown_timer.start(attack_cooldown)
    
    if "Wave" in name: _run_wave_logic()

func on_modifier_applied() -> void:
    pass


# Aura damage tick timer
var _aura_damage_timer: float = 0.0

# ── Aura visual animation ──
func _process(delta: float) -> void:
    if weapon_name != "Aura":
        return
    if not is_instance_valid(aura_sprite):
        return
    
    # Aura всегда в центре игрока — обнуляем смещение от спавна
    position = Vector2.ZERO
    
    # Периодический урон — проверка врагов внутри хитбокса
    _aura_damage_timer += delta
    if _aura_damage_timer >= 0.5:
        _aura_damage_timer = 0.0
        if is_instance_valid(hitbox):
            hitbox.damage = base_damage * (player.get_final_damage_multiplier() if player else 1.0)
            hitbox.check_hit()
    
    var t = Time.get_ticks_msec() / 1000.0
    
    # Усиленная пульсация — scale 0.8 → 1.2
    var pulse = 1.0 + sin(t * 3.0) * 0.2
    aura_sprite.scale = Vector2.ONE * pulse
    
    # Alpha от 0.5 до 1.0
    aura_sprite.modulate.a = 0.75 + sin(t * 2.5) * 0.25
    
    # Лёгкое вращение для динамики
    aura_sprite.rotation = sin(t * 0.5) * 0.05
    
    # Эволюция: дополнительный цветовой акцент
    if is_evolution_version:
        aura_sprite.modulate.r = 0.6 + sin(t * 2.0) * 0.2
        aura_sprite.modulate.g = 0.3 + sin(t * 2.5) * 0.15
        aura_sprite.modulate.b = 0.8 + sin(t * 3.0) * 0.2

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
    # Урон — выполняется ВСЕГДА, независимо от визуала
    if is_instance_valid(hitbox):
        hitbox.damage = base_damage * (player.get_final_damage_multiplier() if player else 1.0)
        _set_hitbox_active(true)
    
    # Визуал — только если есть canvas-элемент
    if is_instance_valid(spear_visual):
        var stretch = 1.7 if is_evolution_version else 1.2
        var thickness = 1.2 if is_evolution_version else 1.0
        spear_visual.position.x = target_dist - (spear_visual_length * stretch * 0.35)
        spear_visual.scale = Vector2(stretch, thickness)
        spear_visual.modulate.a = 1.0
        _spawn_glitch_ghost()
        _update_shader(0.06, 0.06 if is_evolution_version else 0.05)
    
    # Fade + выключение хитбокса
    var fade = create_tween()
    fade.tween_interval(strike_duration)
    if is_instance_valid(spear_visual):
        fade.tween_property(spear_visual, "modulate:a", 0.0, fade_duration)
    else:
        fade.tween_property(self, "modulate:a", 0.0, strike_duration)
    fade.finished.connect(func():
        if is_instance_valid(spear_visual):
            spear_visual.position.x = 0
        _set_hitbox_active(false)
    )
    cooldown_timer.start(attack_cooldown)

func _spawn_glitch_ghost() -> void:
    var poly = spear_visual as Polygon2D
    if not poly: return
    var ghost = poly.duplicate() as Polygon2D
    ghost.material = null; ghost.modulate.a = 0.5 
    get_tree().current_scene.add_child(ghost)
    ghost.global_transform = spear_visual.global_transform
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
    var poly = spear_visual as Polygon2D
    if poly and poly.material is ShaderMaterial:
        poly.material.set_shader_parameter("glitch_strength", strength)
        poly.material.set_shader_parameter("color_split", split)

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
        
func _find_visual() -> CanvasItem:
    var polygon = get_node_or_null("VisualPivot/Polygon2D")
    if polygon:
        return polygon

    var sprite = get_node_or_null("VisualPivot/Sprite2D")
    if sprite:
        return sprite

    return null
