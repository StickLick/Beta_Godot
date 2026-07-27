class_name SpectralArrow
extends Area2D

@export var speed: float = 550.0
@export var damage: float = 15.0
@export var bounce_limit: int = 3
@export var bounce_radius: float = 200.0

var faction: String = "player"
var _bounce_count: int = 0
var _hit_targets: Array[Node] = []


func _ready() -> void:
    collision_layer = 0
    collision_mask = 12  # enemy hurtbox layer
    get_tree().create_timer(5.0).timeout.connect(queue_free)
    area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
    position += Vector2.RIGHT.rotated(rotation) * speed * delta


func _on_area_entered(area: Area2D) -> void:
    if not area.has_method("_apply_damage"):
        return
    
    var target_f = area.get("faction")
    if target_f == null or str(target_f).to_lower() == faction.to_lower():
        return
    
    # Skip if already hit this target
    if area in _hit_targets:
        return
    
    # Direct damage
    area._apply_damage(damage)
    _hit_targets.append(area)
    _bounce_count += 1
    
    if _bounce_count >= bounce_limit:
        queue_free()
        return
    
    # Find next closest enemy for ricochet
    var next_target = _find_bounce_target()
    if next_target:
        var dir = (next_target.global_position - global_position).normalized()
        rotation = atan2(dir.y, dir.x)
    else:
        queue_free()


func _find_bounce_target() -> Area2D:
    var space_state = get_world_2d().direct_space_state
    if space_state == null:
        return null
    
    var query = PhysicsShapeQueryParameters2D.new()
    var circle = CircleShape2D.new()
    circle.radius = bounce_radius
    query.shape = circle
    query.transform = Transform2D(0, global_position)
    query.collision_mask = 12  # enemy layer
    query.collide_with_areas = true
    query.collide_with_bodies = false
    
    var results = space_state.intersect_shape(query)
    var closest: Area2D = null
    var closest_dist_sq: float = INF
    
    for result in results:
        var collider = result.collider
        if collider in _hit_targets:
            continue
        if not collider.has_method("_apply_damage"):
            continue
        var cf = collider.get("faction")
        if cf != null and str(cf).to_lower() == faction.to_lower():
            continue
        var d = global_position.distance_squared_to(collider.global_position)
        if d < closest_dist_sq:
            closest_dist_sq = d
            closest = collider
    
    return closest