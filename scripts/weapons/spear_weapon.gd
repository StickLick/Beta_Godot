class_name SpearWeapon
extends BaseWeapon


func _weapon_ready() -> void:
    if is_instance_valid(spear_visual):
        spear_visual.modulate.a = 0
        _update_shader(0.0, 0.0)
    
    _set_hitbox_active(false)
    cooldown_timer.timeout.connect(_on_cooldown_timeout)
    cooldown_timer.start(attack_cooldown)


func _on_cooldown_timeout() -> void:
    var target = _get_closest_target()
    if target == null:
        cooldown_timer.start(0.2)
        return
    var dist = global_position.distance_to(target.global_position)
    if dist <= max_attack_distance:
        visual_pivot.look_at(target.global_position)
        if is_instance_valid(player):
            player.play_attack_animation(target.global_position)
        _perform_glitch_strike(dist)
    else:
        cooldown_timer.start(0.1)


func _perform_glitch_strike(target_dist: float) -> void:
    # Урон — выполняется ВСЕГДА, независимо от визуала
    if is_instance_valid(hitbox):
        hitbox.damage = final_damage
        _set_hitbox_active(true)
    SoundManager.play(SoundManager.shoot_spear_sound, SoundManager.shoot_spear_volume_db, SoundManager.shoot_spear_pitch * randf_range(0.96, 1.04))
    
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
    if not poly:
        return
    var ghost = poly.duplicate() as Polygon2D
    ghost.material = null
    ghost.modulate.a = 0.5 
    get_tree().current_scene.add_child(ghost)
    ghost.global_transform = spear_visual.global_transform
    var gt = create_tween().set_parallel(false)
    ghost.color = Color.WHITE
    gt.tween_interval(0.03)
    gt.tween_property(ghost, "color", Color(0, 1, 1), 0.08)
    if is_evolution_version:
        gt.tween_property(ghost, "color", Color(1, 0, 1), 0.12)
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
            if d < dist_sq:
                dist_sq = d
                closest = area
    return closest
