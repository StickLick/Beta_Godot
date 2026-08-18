class_name AuraWeapon
extends BaseWeapon

@onready var aura_sprite: Sprite2D = get_node_or_null("VisualPivot/Sprite2D")
@onready var burst_particles: GPUParticles2D = get_node_or_null("VisualPivot/BurstParticles")
@onready var aura_field: CanvasItem = get_node_or_null("VisualPivot/AuraRing")

var _aura_damage_timer: float = 0.0
var _aura_base_scale: float = 1.0
var _tex_radius: float = 230.0

var _evo_burst_timer: float = 0.0
var _evo_next_interval: float = 2.5


func _weapon_ready() -> void:
    _set_hitbox_active(true)
    if is_evolution_version:
        _tex_radius = 115.0
    if is_instance_valid(aura_sprite):
        aura_sprite.modulate = Color(0.4, 0.7, 1.0, 1.0)
        aura_sprite.scale = Vector2.ONE
        var aura_shader = load("res://Shaders/AuraRadial.gdshader")
        if aura_shader:
            aura_sprite.material = ShaderMaterial.new()
            aura_sprite.material.shader = aura_shader


func _on_effective_range_changed() -> void:
    _sync_aura_visual()


func _sync_aura_visual() -> void:
    var scale_val = final_range / _tex_radius
    if is_instance_valid(aura_sprite) and not is_evolution_version:
        _aura_base_scale = scale_val
    elif is_evolution_version and is_instance_valid(aura_field):
        var ring_scale = final_range / (_tex_radius * 0.45)
        aura_field.scale = Vector2.ONE * ring_scale


func _setup_physics_auto() -> void:
    super._setup_physics_auto()
    _sync_aura_visual()


func _weapon_process(delta: float) -> void:
    if weapon_tag != "Aura" and weapon_tag != "Aura_Evolved":
        return
    # Визуальный центр героя (AnimatedSprite2D в Player.tscn) смещён на (-8, -13)
    # от origin Player (0,0). Аура центруется на этот визуал, а не на origin-ноду.
    position = Vector2(-8, -13)
    _aura_damage_timer += delta
    if _aura_damage_timer >= 0.5:
        _aura_damage_timer = 0.0
        if is_instance_valid(hitbox):
            hitbox.damage = final_damage
            hitbox.check_hit()
    if is_instance_valid(aura_sprite) and not is_evolution_version:
        var t = Time.get_ticks_msec() / 1000.0
        var pulse = 1.0 + sin(t * 3.0) * 0.2
        aura_sprite.scale = Vector2.ONE * (_aura_base_scale * pulse)
        aura_sprite.modulate.a = 0.75 + sin(t * 2.5) * 0.25
        aura_sprite.rotation = sin(t * 0.5) * 0.05
    elif is_evolution_version:
        var t = Time.get_ticks_msec() / 1000.0
        var field_pulse = 1.0 + sin(t * 2.0) * 0.05
        if is_instance_valid(aura_field):
            var ring_scale = final_range / (_tex_radius * 0.45)
            aura_field.scale = Vector2.ONE * (ring_scale * field_pulse)
            aura_field.modulate.a = 0.2 + sin(t * 2.5) * 0.04
            aura_field.rotation += delta * 0.05
        visual_pivot.rotation += delta * 0.2
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
    var space_state = get_world_2d().direct_space_state
    var closest_enemy: Node = null
    var closest_dist_sq: float = INF
    if space_state != null:
        var target_query = PhysicsShapeQueryParameters2D.new()
        var circle = CircleShape2D.new()
        circle.radius = final_range * 1.5
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
            var co = collider.owner
            if not is_instance_valid(co):
                co = null
            if co == get_parent():
                continue
            if "player" in str(collider.name).to_lower():
                continue
            if is_instance_valid(co) and "player" in str(co.name).to_lower():
                continue
            if not collider.has_method("_apply_damage"):
                continue
            var d_sq: float = global_position.distance_squared_to(collider.global_position)
            if d_sq < closest_dist_sq:
                closest_dist_sq = d_sq
                closest_enemy = collider
    if closest_enemy != null and randf() < 0.70:
        var dir_vect = (closest_enemy.global_position - global_position).normalized()
        angle = atan2(dir_vect.y, dir_vect.x)
    else:
        angle = randf_range(0, TAU)
    var aura_radius = final_range
    burst_particles.position = Vector2.RIGHT.rotated(angle) * aura_radius
    mat.direction = Vector3(cos(angle), sin(angle), 0.0)
    mat.spread = randf_range(30.0, 90.0) if not heavy else randf_range(60.0, 120.0)
    mat.initial_velocity_min = 400.0 if not heavy else 600.0
    mat.initial_velocity_max = 600.0 if not heavy else 900.0
    burst_particles.amount = randi_range(15, 30) if not heavy else randi_range(40, 60)
    burst_particles.restart()
    burst_particles.emitting = true
    SoundManager.play(SoundManager.shoot_magic_sound, SoundManager.shoot_magic_volume_db, SoundManager.shoot_magic_pitch * randf_range(0.96, 1.04))
    if space_state != null:
        var query = PhysicsShapeQueryParameters2D.new()
        var rect = RectangleShape2D.new()
        rect.size = Vector2(140, 100)
        query.shape = rect
        var offset_dist = final_range + 60.0
        query.transform = Transform2D(angle, global_position + Vector2.RIGHT.rotated(angle) * offset_dist)
        query.collision_mask = 8
        query.collide_with_areas = true
        query.collide_with_bodies = false
        var results = space_state.intersect_shape(query)
        var burst_dmg = final_damage * 0.5
        for result in results:
            var collider = result.collider
            var collider_faction = null
            if "faction" in collider:
                collider_faction = collider.faction
            if collider_faction != null and str(collider_faction).to_lower() == "player":
                continue
            var hit_target: Node = null
            var parent_node = collider.get_parent()
            if collider.has_method("_apply_damage"):
                hit_target = collider
            elif is_instance_valid(parent_node):
                for child in parent_node.get_children():
                    if child.has_method("_apply_damage"):
                        hit_target = child
                        break
            if hit_target != null:
                HitboxComponent.deal_damage_to_area(hit_target, burst_dmg, "player")
