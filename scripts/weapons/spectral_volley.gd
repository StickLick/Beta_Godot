class_name SpectralVolley
extends BaseWeapon

const ARROW_SCENE: PackedScene = preload("res://Assets/Scenes/Weapons/SpectralArrow.tscn")
const FAN_ANGLE: float = 12.0  # degrees between arrows in fan

@export var base_arrow_count: int = 3
@export var bounce_limit: int = 3
@export var bounce_radius: float = 200.0


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
    var amount = max(1, base_arrow_count)
    
    _fire_volley(base_angle, amount)
    cooldown_timer.start(attack_cooldown)


func _fire_volley(base_angle: float, amount: int) -> void:
    if amount == 1:
        _spawn_arrow(base_angle)
        return
    
    # Fan pattern: spread arrows symmetrically around base_angle
    var total_spread = float(amount - 1) * FAN_ANGLE
    var start_angle = base_angle - deg_to_rad(total_spread / 2.0)
    
    for i in range(amount):
        var angle = start_angle + deg_to_rad(float(i) * FAN_ANGLE)
        _spawn_arrow(angle)


func _spawn_arrow(angle: float) -> void:
    var arrow = ARROW_SCENE.instantiate() as SpectralArrow
    if not arrow:
        return
    
    var root = get_tree().current_scene
    root.add_child(arrow)
    arrow.global_position = global_position
    arrow.rotation = angle
    arrow.damage = final_damage
    arrow.bounce_limit = bounce_limit
    arrow.bounce_radius = bounce_radius


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
