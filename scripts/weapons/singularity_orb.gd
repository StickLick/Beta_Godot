class_name SingularityOrb
extends Area2D

@export var speed: float = 120.0
@export var damage: float = 40.0
@export var pull_radius: float = 12.5
@export var pull_strength: float = 2500.0
@export var lifetime: float = 3.5

const EXPLOSION_SCENE: PackedScene = preload("res://Assets/Scenes/Effects/Explosion.tscn")

var direction: Vector2 = Vector2.RIGHT
var _spawned_time: float = 0.0

# Vortex Lock: enemies "glued" to the orb
var _captured_bodies: Array[CharacterBody2D] = []
var _orb_velocity: Vector2 = Vector2.ZERO


func _ready() -> void:
    collision_layer = 0
    collision_mask = 12
    get_tree().create_timer(lifetime + 1.0).timeout.connect(queue_free)
    _spawned_time = Time.get_ticks_msec() / 1000.0
    area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
    var elapsed = (Time.get_ticks_msec() / 1000.0) - _spawned_time
    
    _orb_velocity = direction * speed
    position += _orb_velocity * delta
    _apply_vortex_lock(delta)
    
    if elapsed >= lifetime:
        _on_collapse()
        return


func _apply_vortex_lock(delta: float) -> void:
    var space_state = get_world_2d().direct_space_state
    if space_state == null:
        return
    
    var query = PhysicsShapeQueryParameters2D.new()
    var circle = CircleShape2D.new()
    circle.radius = pull_radius
    query.shape = circle
    query.transform = Transform2D(0, global_position)
    query.collision_mask = 12
    query.collide_with_areas = true
    query.collide_with_bodies = false
    
    var results = space_state.intersect_shape(query)
    
    # Reset capture list — rebuild each frame
    _captured_bodies.clear()
    
    for result in results:
        var collider = result.collider
        var cf = collider.get("faction") if "faction" in collider else null
        if cf != null and str(cf).to_lower() == "player":
            continue
        var parent = collider.get_parent()
        if not (parent and parent is CharacterBody2D):
            continue
        _captured_bodies.append(parent)
    
    # ── VORTEX LOCK with distance falloff ──
    # force = base_force * (1.0 - distance / pull_radius)
    var carry_speed = _orb_velocity * delta
    var lerp_factor = clamp(15.0 * delta, 0.0, 1.0)
    
    for body in _captured_bodies:
        if not is_instance_valid(body):
            continue
        
        var to_center = global_position - body.global_position
        var dist = to_center.length()
        
        # Distance-based falloff: strong near center, weak at edge
        var falloff = 1.0 - (dist / pull_radius)
        falloff = max(falloff, 0.1)  # minimum 10% even at max range
        
        # 1) Lerp position — sticky mud, not black hole (-85% from original)
        var effective_lerp = lerp_factor * falloff * 0.135
        body.global_position = body.global_position.lerp(global_position, effective_lerp)
        
        # 2) Carry velocity — barely noticeable (-85%)
        body.global_position += carry_speed * 0.06 * falloff
        
        # 3) Suppress velocity — enemies can walk out (-85%)
        body.velocity = body.velocity.lerp(_orb_velocity * 0.025 * falloff, 0.7 * delta)
        
        # 4) Mark captured flag for visual feedback
        body.set_meta("vortex_captured", true)


func _on_area_entered(area: Area2D) -> void:
    if not area.has_method("_apply_damage"):
        return
    var target_f = area.get("faction")
    if target_f != null and str(target_f).to_lower() == "player":
        return
    area._apply_damage(damage * 0.5)


func _on_collapse() -> void:
    # Release all captured enemies
    for body in _captured_bodies:
        if is_instance_valid(body):
            body.remove_meta("vortex_captured")
    _captured_bodies.clear()
    
    var space_state = get_world_2d().direct_space_state
    if space_state != null:
        var query = PhysicsShapeQueryParameters2D.new()
        var circle = CircleShape2D.new()
        circle.radius = pull_radius * 1.3
        query.shape = circle
        query.transform = Transform2D(0, global_position)
        query.collision_mask = 12
        query.collide_with_areas = true
        query.collide_with_bodies = false
        var results = space_state.intersect_shape(query)
        for result in results:
            var collider = result.collider
            var cf = collider.get("faction") if "faction" in collider else null
            if cf != null and str(cf).to_lower() == "player":
                continue
            if collider.has_method("_apply_damage"):
                collider._apply_damage(damage * 1.5)
    
    # ── VISUAL: Implosion → Explosion ──
    var explosion = EXPLOSION_SCENE.instantiate()
    if explosion:
        var root = get_tree().current_scene
        root.add_child(explosion)
        explosion.global_position = global_position
        
        var flash = explosion.get_node_or_null("Shockwave")
        if flash:
            flash.scale = Vector2.ONE * 2.0
            flash.modulate = Color(0.3, 0.1, 0.8, 0.9)
            var tw = explosion.create_tween().set_parallel(true)
            tw.tween_property(flash, "scale", Vector2.ZERO, 0.25)
            tw.tween_property(flash, "modulate:a", 1.0, 0.25).from(0.4)
            tw.chain().tween_property(flash, "scale", Vector2.ONE * 4.0, 0.35)
            tw.chain().tween_callback(func():
                var tw2 = explosion.create_tween().set_parallel(true)
                tw2.tween_property(flash, "modulate:a", 0.0, 0.3)
                tw2.tween_property(flash, "scale", Vector2.ONE * 6.0, 0.3)
            )
        
        var sparks = explosion.get_node_or_null("Sparks")
        if sparks:
            sparks.emitting = true
            sparks.amount = 50
            sparks.modulate = Color(0.7, 0.3, 1.0, 0.8)
        
        get_tree().create_timer(1.0).timeout.connect(explosion.queue_free)
    
    queue_free()