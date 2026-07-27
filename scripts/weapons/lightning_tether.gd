class_name LightningTether
extends Node2D

@export var damage_per_tick: float = 10.0
@export var tick_interval: float = 0.2
@export var jump_range: float = 200.0
@export var max_jumps: int = 2
@export var lifetime: float = 3.0

var player: Node2D
var chain_targets: Array[Node2D] = []
var _tick_acc: float = 0.0
var _line: Line2D
var _sparks: Array[GPUParticles2D] = []


func _ready() -> void:
    _line = Line2D.new()
    _line.width = 3.0
    _line.default_color = Color(0.2, 0.7, 1.0, 0.9)
    _line.joint_mode = Line2D.LINE_JOINT_ROUND
    _line.end_cap_mode = Line2D.LINE_CAP_ROUND
    add_child(_line)
    
    _build_chain()
    get_tree().create_timer(lifetime).timeout.connect(queue_free)


func _build_chain() -> void:
    chain_targets.clear()
    
    var origin: Node2D = player
    if not is_instance_valid(origin):
        queue_free()
        return
    
    var used_ids = []
    if is_instance_valid(player):
        used_ids.append(player.get_instance_id())
    
    for j in range(max_jumps + 1):  # max_jumps=2 means 3 enemies total
        var next_target = _find_nearest_enemy(origin.global_position, used_ids)
        if not next_target:
            break
        chain_targets.append(next_target)
        used_ids.append(next_target.get_instance_id())
        origin = next_target
        
        # Spawn spark at this enemy
        _spawn_sparks_at(next_target.global_position)
    
    if chain_targets.is_empty():
        queue_free()
        return
    
    # Initialize line points
    _update_line_points()


func _find_nearest_enemy(origin_pos: Vector2, exclude_ids: Array) -> Node2D:
    var space_state = get_world_2d().direct_space_state
    if space_state == null:
        return null
    
    var query = PhysicsShapeQueryParameters2D.new()
    var circle = CircleShape2D.new()
    circle.radius = jump_range
    query.shape = circle
    query.transform = Transform2D(0, origin_pos)
    query.collision_mask = 12
    query.collide_with_areas = true
    query.collide_with_bodies = false
    
    var results = space_state.intersect_shape(query)
    var closest: Node2D = null
    var closest_dist_sq: float = INF
    
    for result in results:
        var collider = result.collider
        if not collider.has_method("_apply_damage"):
            continue
        var cf = collider.get("faction") if "faction" in collider else null
        if cf != null and str(cf).to_lower() == "player":
            continue
        if collider.get_instance_id() in exclude_ids:
            continue
        var d = origin_pos.distance_squared_to(collider.global_position)
        if d < closest_dist_sq:
            closest_dist_sq = d
            closest = collider
    
    return closest


func _spawn_sparks_at(pos: Vector2) -> void:
    var sp = GPUParticles2D.new()
    sp.amount = 10
    sp.lifetime = 0.15
    sp.one_shot = false
    sp.explosiveness = 0.5
    sp.self_modulate = Color(0.3, 0.6, 1.0, 0.9)
    sp.global_position = pos
    add_child(sp)
    _sparks.append(sp)


func _physics_process(delta: float) -> void:
    if not is_instance_valid(player):
        queue_free()
        return
    
    # Prune dead targets and try to refill chain
    _repair_chain()
    
    if chain_targets.is_empty():
        queue_free()
        return
    
    _update_line_points()
    
    # Damage all targets in chain
    _tick_acc += delta
    while _tick_acc >= tick_interval:
        _tick_acc -= tick_interval
        for target in chain_targets:
            if is_instance_valid(target) and target.has_method("_apply_damage"):
                target._apply_damage(damage_per_tick)


func _repair_chain() -> void:
    var used_ids = [player.get_instance_id()] if is_instance_valid(player) else []
    
    for i in range(chain_targets.size()):
        var target = chain_targets[i]
        if not is_instance_valid(target) or not target.is_inside_tree():
            # Find replacement starting from previous node in chain
            var origin_pos = player.global_position if is_instance_valid(player) else global_position
            if i > 0 and is_instance_valid(chain_targets[i - 1]):
                origin_pos = chain_targets[i - 1].global_position
            
            var replacement = _find_nearest_enemy(origin_pos, used_ids)
            if replacement:
                chain_targets[i] = replacement
                _spawn_sparks_at(replacement.global_position)
            else:
                # No replacement — truncate chain
                chain_targets = chain_targets.slice(0, i)
                
                # Remove excess sparks
                while _sparks.size() > chain_targets.size():
                    var extra = _sparks.pop_back()
                    extra.queue_free()
                return
        else:
            used_ids.append(target.get_instance_id())
    
    # Remove extra sparks
    while _sparks.size() > chain_targets.size():
        var extra = _sparks.pop_back()
        extra.queue_free()


func _update_line_points() -> void:
    if not is_instance_valid(player):
        queue_free()
        return
    
    var points: PackedVector2Array = []
    points.append(player.global_position)
    
    var prev = player.global_position
    for target in chain_targets:
        if not is_instance_valid(target):
            continue
        var end = target.global_position
        
        # Electric jitter: insert a jittered midpoint
        var mid = (prev + end) / 2.0
        var jx = randf_range(-8, 8)
        var jy = randf_range(-8, 8)
        points.append(mid + Vector2(jx, jy))
        points.append(end)
        
        # Update spark position
        var s_idx = chain_targets.find(target)
        if s_idx >= 0 and s_idx < _sparks.size():
            _sparks[s_idx].global_position = end
        
        prev = end
    
    _line.points = points