class_name LightningStaff
extends BaseWeapon

@export var max_jumps: int = 2


func _weapon_ready() -> void:
    cooldown_timer.timeout.connect(_on_cooldown_timeout)
    cooldown_timer.start(attack_cooldown)


func _on_cooldown_timeout() -> void:
    var enemies = _get_all_enemies_sorted()
    if enemies.is_empty():
        cooldown_timer.start(0.2)
        return
    
    _spawn_tether()
    cooldown_timer.start(attack_cooldown)


func _spawn_tether() -> void:
    var tether = LightningTether.new()
    if is_instance_valid(player):
        tether.player = player
        tether.damage_per_tick = base_damage * 0.5 * player.get_final_damage_multiplier()
    else:
        tether.player = self
        tether.damage_per_tick = base_damage * 0.5
    tether.max_jumps = max_jumps
    tether.jump_range = 200.0
    
    var root = get_tree().current_scene
    root.add_child(tether)


func _get_all_enemies_sorted() -> Array[Area2D]:
    var enemies: Array[Area2D] = []
    for area in detection_area.get_overlapping_areas():
        if area.has_method("_apply_damage") and area.get("faction") != "player":
            enemies.append(area)
    enemies.sort_custom(func(a, b): return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position))
    return enemies
