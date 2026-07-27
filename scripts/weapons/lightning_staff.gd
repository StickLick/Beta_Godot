class_name LightningStaff
extends BaseWeapon

@export var tether_count: int = 1


func _weapon_ready() -> void:
    cooldown_timer.timeout.connect(_on_cooldown_timeout)
    cooldown_timer.start(attack_cooldown)


func _on_cooldown_timeout() -> void:
    var enemies = _get_all_enemies_sorted()
    if enemies.is_empty():
        cooldown_timer.start(0.2)
        return
    
    var count = tether_count
    if player and player.get("projectile_amount"):
        count = max(1, tether_count + player.projectile_amount - 1)
    
    for i in range(min(count, enemies.size())):
        _spawn_tether(enemies[i])
    
    cooldown_timer.start(attack_cooldown)


func _spawn_tether(target: Node2D) -> void:
    var tether = LightningTether.new()
    tether.player = player if player else self
    tether.current_target = target
    tether.damage_per_tick = base_damage * 0.5 * (player.get_final_damage_multiplier() if player else 1.0)
    
    var root = get_tree().current_scene
    root.add_child(tether)


func _get_all_enemies_sorted() -> Array[Area2D]:
    var enemies: Array[Area2D] = []
    for area in detection_area.get_overlapping_areas():
        if area.has_method("_apply_damage") and area.get("faction") != "player":
            enemies.append(area)
    enemies.sort_custom(func(a, b): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
    return enemies