class_name LightningTether
extends Node2D

@export var damage_per_tick: float = 10.0
@export var tick_rate: float = 0.15
@export var jump_range: float = 300.0
@export var lifetime: float = 2.0

var player: Node2D
var current_target: Node2D
var _tick_acc: float = 0.0
var _line: Line2D
var _sparks: GPUParticles2D


func _ready() -> void:
    _line = Line2D.new()
    _line.width = 3.0
    _line.default_color = Color(0.2, 0.7, 1.0, 0.9)
    _line.width_curve = Curve.new()
    _line.width_curve.add_point(Vector2(0, 0.3))
    _line.width_curve.add_point(Vector2(1, 0.8))
    add_child(_line)
    _line.add_point(Vector2.ZERO)
    _line.add_point(Vector2.ZERO)
    
    _sparks = GPUParticles2D.new()
    _sparks.amount = 15
    _sparks.lifetime = 0.2
    _sparks.one_shot = false
    _sparks.explosiveness = 0.5
    _sparks.self_modulate = Color(0.3, 0.6, 1.0, 0.9)
    add_child(_sparks)
    
    get_tree().create_timer(lifetime).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
    # Check target validity
    if not is_instance_valid(current_target) or not current_target.is_inside_tree():
        current_target = _find_jump_target()
        if not current_target:
            queue_free()
            return
    
    if not is_instance_valid(player) or not player.is_inside_tree():
        queue_free()
        return
    
    # Update line positions with jitter
    var start = player.global_position
    var end = current_target.global_position
    _line.set_point_position(0, start)
    _line.set_point_position(1, end)
    
    # Jitter
    var mid = (start + end) / 2.0
    var jitter_x = randf_range(-10, 10)
    var jitter_y = randf_range(-10, 10)
    _line.points = PackedVector2Array([start, mid + Vector2(jitter_x, jitter_y), end])
    
    # Spark particles at enemy position
    _sparks.global_position = end
    
    # Tick damage
    _tick_acc += delta
    while _tick_acc >= tick_rate:
        _tick_acc -= tick_rate
        if current_target.has_method("_apply_damage"):
            current_target._apply_damage(damage_per_tick)


func _find_jump_target() -> Node2D:
    var space_state = get_world_2d().direct_space_state
    if space_state == null:
        return null
    
    var query = PhysicsShapeQueryParameters2D.new()
    var circle = CircleShape2D.new()
    circle.radius = jump_range
    query.shape = circle
    query.transform = Transform2D(0, player.global_position if player else global_position)
    query.collision_mask = 12
    query.collide_with_areas = true
    query.collide_with_bodies = false
    
    var results = space_state.intersect_shape(query)
    var closest: Node2D = null
    var closest_dist_sq: float = INF
    
    for result in results:
        var collider = result.collider
        var cf = collider.get("faction") if "faction" in collider else null
        if cf != null and str(cf).to_lower() == "player":
            continue
        if not collider.has_method("_apply_damage"):
            continue
        var d = player.global_position.distance_squared_to(collider.global_position) if player else INF
        if d < closest_dist_sq:
            closest_dist_sq = d
            closest = collider
    
    return closest