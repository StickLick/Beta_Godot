class_name ArcaneBolt
extends Area2D

@export var speed: float = 350.0
@export var damage: float = 15.0
@export var weave_frequency: float = 6.0
@export var weave_amplitude: float = 70.0
@export var steering_strength: float = 4.0
@export var retarget_radius: float = 500.0

var target: Node2D = null
var direction: Vector2 = Vector2.RIGHT
var faction: String = "player"
var _spawn_time: int = 0


func _ready() -> void:
    collision_layer = 0
    collision_mask = 12  # enemy hurtbox layer
    get_tree().create_timer(8.0).timeout.connect(queue_free)
    area_entered.connect(_on_area_entered)
    _spawn_time = Time.get_ticks_msec()


func _physics_process(delta: float) -> void:
    # If target died, find new closest enemy
    if not is_instance_valid(target):
        target = _find_new_target()
    
    # Steer toward target if exists
    var desired_dir = direction
    if is_instance_valid(target):
        desired_dir = (target.global_position - global_position).normalized()
    
    # Smooth rotation toward desired direction
    var current_angle = direction.angle()
    var desired_angle = desired_dir.angle()
    var angle_diff = wrapf(desired_angle - current_angle, -PI, PI)
    var max_turn = steering_strength * delta
    var turn = clamp(angle_diff, -max_turn, max_turn)
    var new_angle = current_angle + turn
    direction = Vector2.RIGHT.rotated(new_angle)
    
    # Movement with sine weave perpendicular to direction
    var elapsed = (Time.get_ticks_msec() - _spawn_time) / 1000.0
    var perpendicular = Vector2(-direction.y, direction.x)
    var weave = perpendicular * sin(elapsed * weave_frequency * TAU) * weave_amplitude
    
    var velocity = direction * speed + weave
    position += velocity * delta
    
    # Face the actual resultant velocity
    rotation = velocity.angle()


func _find_new_target() -> Node2D:
    var space_state = get_world_2d().direct_space_state
    if space_state == null:
        return null
    
    var query = PhysicsShapeQueryParameters2D.new()
    var circle = CircleShape2D.new()
    circle.radius = retarget_radius
    query.shape = circle
    query.transform = Transform2D(0, global_position)
    query.collision_mask = 12
    query.collide_with_areas = true
    query.collide_with_bodies = false
    
    var results = space_state.intersect_shape(query)
    var closest: Node2D = null
    var closest_dist_sq: float = INF
    
    for result in results:
        var collider = result.collider
        var cf = collider.get("faction") if "faction" in collider else null
        if cf != null and str(cf).to_lower() == faction.to_lower():
            continue
        var d = global_position.distance_squared_to(collider.global_position)
        if d < closest_dist_sq:
            closest_dist_sq = d
            closest = collider
    
    return closest


func _on_area_entered(area: Area2D) -> void:
    if not area.has_method("_apply_damage"):
        return
    
    var target_f = area.get("faction")
    if target_f != null and str(target_f).to_lower() == faction.to_lower():
        return
    
    area._apply_damage(damage)
    queue_free()