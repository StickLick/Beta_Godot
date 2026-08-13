class_name MagicStaff
extends BaseWeapon

const BOLT_SCENE: PackedScene = preload("res://Assets/Scenes/Weapons/ArcaneBolt.tscn")
const FAN_ANGLE: float = 10.0


func _weapon_ready() -> void:
    cooldown_timer.timeout.connect(_on_cooldown_timeout)
    cooldown_timer.start(attack_cooldown)


func _on_cooldown_timeout() -> void:
    var target = _get_closest_enemy()
    if target == null:
        cooldown_timer.start(0.15)
        return
    
    var dir = (target.global_position - global_position).normalized()
    var base_angle = atan2(dir.y, dir.x)
    var amount = player.projectile_amount if player else 1
    amount = max(1, amount)
    
    # Assign different targets if multiple bolts
    var enemies = _get_all_enemies_sorted()
    var target_count = enemies.size()
    
    for i in range(amount):
        var bolt_target: Node2D = target
        if target_count > 0:
            bolt_target = enemies[i % target_count]
        
        var angle: float
        if amount == 1:
            angle = base_angle
        else:
            var total_spread = float(amount - 1) * FAN_ANGLE
            var start_angle = base_angle - deg_to_rad(total_spread / 2.0)
            angle = start_angle + deg_to_rad(float(i) * FAN_ANGLE)
        
        _spawn_bolt(angle, bolt_target)
    
    cooldown_timer.start(attack_cooldown)


func _spawn_bolt(angle: float, target: Node2D) -> void:
    var bolt = BOLT_SCENE.instantiate() as ArcaneBolt
    if not bolt:
        return
    
    var root = get_tree().current_scene
    root.add_child(bolt)
    bolt.global_position = global_position
    bolt.direction = Vector2.RIGHT.rotated(angle)
    bolt.target = target
    bolt.damage = final_damage


func _get_closest_enemy() -> Area2D:
    var closest: Area2D = null
    var dist_sq: float = INF
    for area in detection_area.get_overlapping_areas():
        if area.has_method("_apply_damage") and area.get("faction") != "player":
            var d = global_position.distance_squared_to(area.global_position)
            if d < dist_sq:
                dist_sq = d
                closest = area
    return closest


func _get_all_enemies_sorted() -> Array[Area2D]:
    var enemies: Array[Area2D] = []
    for area in detection_area.get_overlapping_areas():
        if area.has_method("_apply_damage") and area.get("faction") != "player":
            enemies.append(area)
    # Sort by distance
    enemies.sort_custom(func(a, b): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
    return enemies
