class_name SiegeCrossbow
extends BaseWeapon

const BOLT_SCENE: PackedScene = preload("res://Assets/Scenes/Weapons/SiegeBolt.tscn")

@export var pierce_limit: int = 3
@export var aoe_radius: float = 80.0


func _weapon_ready() -> void:
    cooldown_timer.timeout.connect(_on_cooldown_timeout)
    cooldown_timer.start(attack_cooldown)


func _on_cooldown_timeout() -> void:
    var target = _get_closest_enemy()
    if target == null:
        cooldown_timer.start(0.2)
        return
    
    var dir = (target.global_position - global_position).normalized()
    var angle = atan2(dir.y, dir.x)
    if is_instance_valid(player):
        player.play_attack_animation(target.global_position)
    _spawn_bolt(angle)
    cooldown_timer.start(attack_cooldown)


func _spawn_bolt(angle: float) -> void:
    var bolt = BOLT_SCENE.instantiate() as SiegeBolt
    if not bolt:
        return
    
    var root = get_tree().current_scene
    root.add_child(bolt)
    bolt.global_position = global_position
    bolt.rotation = angle
    bolt.damage = final_damage
    bolt.pierce_limit = final_pierce
    bolt.aoe_radius = aoe_radius


func _get_closest_enemy() -> Area2D:
    var closest: Area2D = null
    var dist_sq: float = INF
    for area in detection_area.get_overlapping_areas():
        if area.has_method("_apply_damage") and area.get("faction") != "player":
            var d = global_position.distance_squared_to(area.global_position)
            if d < dist_sq:
                dist_sq = d
                closest = area
    
    # Fallback: physics query for enemies right next to player
    if closest == null:
        var space_state = get_world_2d().direct_space_state
        if space_state != null:
            var query = PhysicsShapeQueryParameters2D.new()
            var circle = CircleShape2D.new()
            circle.radius = max_attack_distance
            query.shape = circle
            query.transform = Transform2D(0, global_position)
            query.collision_mask = 12  # enemy hurtbox layer
            query.collide_with_areas = true
            query.collide_with_bodies = false
            var results = space_state.intersect_shape(query)
            for result in results:
                var collider = result.collider
                if collider.has_method("_apply_damage") and collider.get("faction") != "player":
                    var d = global_position.distance_squared_to(collider.global_position)
                    if d < dist_sq:
                        dist_sq = d
                        closest = collider
    
    return closest
