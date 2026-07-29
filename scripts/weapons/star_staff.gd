class_name StarStaff
extends BaseWeapon

const SHARD_BASE_SCENE: PackedScene = preload("res://Assets/Scenes/Weapons/StarShardBase.tscn")


func _weapon_ready() -> void:
    cooldown_timer.timeout.connect(_on_cooldown_timeout)
    cooldown_timer.start(attack_cooldown)


func _on_cooldown_timeout() -> void:
    var target = _get_closest_enemy()
    if target == null:
        cooldown_timer.start(0.2)
        return
    
    var amount = player.projectile_amount if player else 1
    amount = max(1, amount)
    _spawn_shard_base(target, amount)
    cooldown_timer.start(attack_cooldown)


func _spawn_shard_base(enemy_target: Area2D, shard_count: int) -> void:
    var shard = SHARD_BASE_SCENE.instantiate() as StarShardBase
    if not shard:
        return
    
    # Predictive lead aim: target where the enemy will be, not where it is
    var enemy_vel = Vector2.ZERO
    var parent_node = enemy_target.get_parent()
    if parent_node and parent_node is CharacterBody2D:
        enemy_vel = parent_node.velocity
    
    var predicted_pos = enemy_target.global_position + enemy_vel * 0.5
    
    var root = get_tree().current_scene
    root.add_child(shard)
    shard.global_position = global_position
    shard.direction = (predicted_pos - global_position).normalized()
    shard.target_pos = predicted_pos
    shard.shard_count = 5 + shard_count
    shard.damage = final_damage


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
