class_name WeaponComponent
extends Node2D

signal weapon_maxed(name: String)

@export_group("Identity")
@export var weapon_name: String = "Spear"
@export var is_evolution_version: bool = false 
var weapon_tag: String = ""  # устанавливается из Upgrade ресурса при спавне/эволюции (runtime)

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
@onready var burst_particles: GPUParticles2D = get_node_or_null("VisualPivot/BurstParticles")
@onready var aura_field: CanvasItem = get_node_or_null("VisualPivot/AuraRing")

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
    
    # Устанавливаем weapon_tag для предустановленного в сцене оружия (Spear)
    if weapon_tag == "":
        weapon_tag = weapon_name
    
    _setup_physics_auto()
    
    if weapon_name == "Aura" or weapon_tag == "Aura_Evolved":
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
    
    print("[WEAPON INIT] ", weapon_name, " (tag=", weapon_tag, ")")
    print("   max_attack_distance=", max_attack_distance)
    print("   base_damage=", base_damage)
    print("   attack_cooldown=", attack_cooldown)
    if is_instance_valid(detection_area):
        var shape = detection_area.get_node_or_null("CollisionShape2D")
        if shape and shape.shape:
            print("   detection_radius=", shape.shape.radius)
    if is_instance_valid(hitbox):
        var shape = hitbox.get_node_or_null("CollisionShape2D")
        if shape and shape.shape:
            if shape.shape is CircleShape2D:
                print("   hitbox_radius=", shape.shape.radius)
            elif shape.shape is RectangleShape2D:
                print("   hitbox_size=", shape.shape.size)

func on_modifier_applied() -> void:
    _setup_physics_auto()
    print("[WEAPON] ", weapon_name, " (tag=", weapon_tag, ") after modifier:")
    print("   max_attack_distance=", max_attack_distance)
    print("   base_damage=", base_damage)
    print("   attack_cooldown=", attack_cooldown)
    if is_instance_valid(detection_area):
        var shape = detection_area.get_node_or_null("CollisionShape2D")
        if shape and shape.shape:
            print("   detection_radius=", shape.shape.radius)
    if is_instance_valid(hitbox):
        var shape = hitbox.get_node_or_null("CollisionShape2D")
        if shape and shape.shape:
            if shape.shape is CircleShape2D:
                print("   hitbox_radius=", shape.shape.radius)
            elif shape.shape is RectangleShape2D:
                print("   hitbox_size=", shape.shape.size)


# Aura damage tick timer
var _aura_damage_timer: float = 0.0
var _aura_base_scale: float = 1.0

# EvolvedAura burst timer
var _evo_burst_timer: float = 0.0
var _evo_next_interval: float = 2.5

# ── Aura visual animation ──
func _process(delta: float) -> void:
    if weapon_tag != "Aura" and weapon_tag != "Aura_Evolved":
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
    
    if is_instance_valid(aura_sprite):
        # Обычная Aura: Sprite2D с шейдером
        var t = Time.get_ticks_msec() / 1000.0
        var pulse = 1.0 + sin(t * 3.0) * 0.2
        aura_sprite.scale = Vector2.ONE * (_aura_base_scale * pulse)
        aura_sprite.modulate.a = 0.75 + sin(t * 2.5) * 0.25
        aura_sprite.rotation = sin(t * 0.5) * 0.05
    elif is_evolution_version:
        # EvolvedAuraWave: constant aura field + burst particles
        var t = Time.get_ticks_msec() / 1000.0
        var field_pulse = 1.0 + sin(t * 2.0) * 0.05
        
        # Animate aura ring: visual radius = hitbox radius
        if is_instance_valid(aura_field):
            var ring_scale = max_attack_distance / (230.0 * 0.45)
            aura_field.scale = Vector2.ONE * (ring_scale * field_pulse)
            aura_field.modulate.a = 0.2 + sin(t * 2.5) * 0.04
            aura_field.rotation += delta * 0.05
        
        visual_pivot.rotation += delta * 0.2
        
        # Random burst timer
        _evo_burst_timer += delta
        if _evo_burst_timer >= _evo_next_interval:
            _evo_burst_timer = 0.0
            _evo_next_interval = randf_range(2.0, 4.5)
            _trigger_pulse()

func _trigger_pulse() -> void:
    if not is_instance_valid(burst_particles):
        return
    
    var mat = burst_particles.process_material as ParticleProcessMaterial
    if not mat:
        return
    
    var heavy = randf() < 0.15
    var angle: float
    var targeted: bool = false
    
    # Target selection: physics query for nearby enemies
    var closest_enemy: Node = null
    var closest_dist_sq: float = INF
    var space_state = get_world_2d().direct_space_state
    if space_state != null:
        var target_query = PhysicsShapeQueryParameters2D.new()
        var circle = CircleShape2D.new()
        circle.radius = max_attack_distance * 1.5
        target_query.shape = circle
        target_query.transform = Transform2D(0, global_position)
        target_query.collision_mask = 8
        target_query.collide_with_areas = true
        target_query.collide_with_bodies = false
        var nearby = space_state.intersect_shape(target_query)
        for result in nearby:
            var collider = result.collider
            if not is_instance_valid(collider):
                continue
            var collider_owner = collider.owner
            if not is_instance_valid(collider_owner):
                collider_owner = null
            if collider_owner == get_parent():
                continue
            if "player" in str(collider.name).to_lower():
                continue
            if is_instance_valid(collider_owner) and "player" in str(collider_owner.name).to_lower():
                continue
            if not collider.has_method("_apply_damage"):
                continue
            var d_sq: float = global_position.distance_squared_to(collider.global_position)
            if d_sq < closest_dist_sq:
                closest_dist_sq = d_sq
                closest_enemy = collider
    
    if closest_enemy != null and randf() < 0.70:
        var dir = (closest_enemy.global_position - global_position).normalized()
        angle = atan2(dir.y, dir.x)
        targeted = true
    else:
        angle = randf_range(0, TAU)
    
    # Move particle spawn point to visual ring edge + set direction outward
    var aura_radius = max_attack_distance
    burst_particles.position = Vector2.RIGHT.rotated(angle) * aura_radius
    mat.direction = Vector3(cos(angle), sin(angle), 0.0)
    
    # Randomize burst arc
    mat.spread = randf_range(30.0, 90.0) if not heavy else randf_range(60.0, 120.0)
    mat.initial_velocity_min = 400.0 if not heavy else 600.0
    mat.initial_velocity_max = 600.0 if not heavy else 900.0
    burst_particles.amount = randi_range(15, 30) if not heavy else randi_range(40, 60)
    burst_particles.restart()
    burst_particles.emitting = true
    
    # Burst damage: physics query in burst direction
    if space_state != null:
        var query = PhysicsShapeQueryParameters2D.new()
        var rect = RectangleShape2D.new()
        rect.size = Vector2(140, 100)
        query.shape = rect
        # Offset: start at ring edge + half length, extend outward
        var offset_dist = max_attack_distance + 60.0
        query.transform = Transform2D(angle, global_position + Vector2.RIGHT.rotated(angle) * offset_dist)
        query.collision_mask = 8  # enemy hurtbox layer 4
        query.collide_with_areas = true
        query.collide_with_bodies = false
        var results = space_state.intersect_shape(query)
        var burst_dmg = base_damage * 0.5
        var hit_count = 0
        for result in results:
            var collider = result.collider
            # Skip player's own hitbox
            var collider_faction = null
            if "faction" in collider:
                collider_faction = collider.faction
            if collider_faction != null and str(collider_faction).to_lower() == "player":
                continue
            var target: Node = null
            var owner = collider.get_parent()
            # Check collider itself
            if collider.has_method("_apply_damage"):
                target = collider
            elif is_instance_valid(owner):
                # Search siblings under same parent
                for child in owner.get_children():
                    if child.has_method("_apply_damage"):
                        target = child
                        break
            if target != null:
                HitboxComponent.deal_damage_to_area(target, burst_dmg, "player")
                hit_count += 1
        if targeted:
            print("BURST: TARGETED hit ", hit_count, " enemies")
        else:
            print("BURST: RANDOM hit ", hit_count, " enemies")

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
        if shape_node:
            if shape_node.shape is RectangleShape2D:
                shape_node.shape.size = Vector2(max_attack_distance + 15.0, 50.0)
                shape_node.position.x = (max_attack_distance - 15.0) / 2.0
            elif shape_node.shape is CircleShape2D:
                shape_node.shape.radius = max_attack_distance
                # Синхронизируем визуал ауры с новым радиусом
                _aura_base_scale = max_attack_distance / 200.0
                if is_instance_valid(aura_sprite):
                    aura_sprite.scale = Vector2.ONE * _aura_base_scale

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
