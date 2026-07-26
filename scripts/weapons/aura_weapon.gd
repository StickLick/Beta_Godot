class_name AuraWeapon
extends BaseWeapon

# Aura-specific visual nodes
@onready var aura_sprite: Sprite2D = get_node_or_null("VisualPivot/Sprite2D")
@onready var burst_particles: GPUParticles2D = get_node_or_null("VisualPivot/BurstParticles")
@onready var aura_field: CanvasItem = get_node_or_null("VisualPivot/AuraRing")

# Aura damage tick timer
var _aura_damage_timer: float = 0.0
var _aura_base_scale: float = 1.0

# EvolvedAura burst timer
var _evo_burst_timer: float = 0.0
var _evo_next_interval: float = 2.5


func _weapon_ready() -> void:
    _set_hitbox_active(true)
    if is_instance_valid(aura_sprite):
        aura_sprite.modulate = Color(0.4, 0.7, 1.0, 1.0)
        aura_sprite.scale = Vector2.ONE
        # Применяем радиальный шейдер для маскировки прямоугольника текстуры
        var aura_shader = load("res://Shaders/AuraRadial.gdshader")
        if aura_shader:
            aura_sprite.material = ShaderMaterial.new()
            aura_sprite.material.shader = aura_shader


func _setup_physics_auto() -> void:
    super._setup_physics_auto()
    # Синхронизируем визуал ауры с новым радиусом
    if is_instance_valid(hitbox):
        var shape_node = hitbox.get_node_or_null("CollisionShape2D")
        if shape_node and shape_node.shape is CircleShape2D:
            _aura_base_scale = max_attack_distance / 200.0
            if is_instance_valid(aura_sprite):
                aura_sprite.scale = Vector2.ONE * _aura_base_scale


# ── Aura visual animation ──
func _weapon_process(delta: float) -> void:
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