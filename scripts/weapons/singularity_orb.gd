class_name SingularityOrb
extends Area2D

@export var speed: float = 120.0
@export var damage: float = 40.0
@export var pull_radius: float = 250.0
@export var pull_strength: float = 1500.0
@export var lifetime: float = 3.5

const EXPLOSION_SCENE: PackedScene = preload("res://Assets/Scenes/Effects/Explosion.tscn")

var direction: Vector2 = Vector2.RIGHT
var _spawned_time: float = 0.0


func _ready() -> void:
    collision_layer = 0
    collision_mask = 12  # enemy hurtbox layer
    get_tree().create_timer(lifetime + 1.0).timeout.connect(queue_free)  # safety
    _spawned_time = Time.get_ticks_msec() / 1000.0
    area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
    var elapsed = (Time.get_ticks_msec() / 1000.0) - _spawned_time
    
    # Move slowly
    position += direction * speed * delta
    
    # Gravity pull on enemies
    _apply_gravity_pull()
    
    # Explode after lifetime
    if elapsed >= lifetime:
        _on_collapse()
        return


func _apply_gravity_pull() -> void:
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
    for result in results:
        var collider = result.collider
        var cf = collider.get("faction") if "faction" in collider else null
        if cf != null and str(cf).to_lower() == "player":
            continue
        var parent = collider.get_parent()
        if parent and parent is CharacterBody2D:
            var pull_dir = (global_position - collider.global_position).normalized()
            parent.velocity += pull_dir * pull_strength * get_physics_process_delta_time()


func _on_area_entered(area: Area2D) -> void:
    if not area.has_method("_apply_damage"):
        return
    var target_f = area.get("faction")
    if target_f != null and str(target_f).to_lower() == "player":
        return
    area._apply_damage(damage * 0.5)  # tick damage on contact


func _on_collapse() -> void:
    # Massive AoE damage
    var space_state = get_world_2d().direct_space_state
    if space_state != null:
        var query = PhysicsShapeQueryParameters2D.new()
        var circle = CircleShape2D.new()
        circle.radius = pull_radius
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
                collider._apply_damage(damage)
    
    # Spawn explosion effect
    var explosion = EXPLOSION_SCENE.instantiate()
    if explosion:
        var root = get_tree().current_scene
        root.add_child(explosion)
        explosion.global_position = global_position
        var shockwave = explosion.get_node_or_null("Shockwave")
        if shockwave:
            shockwave.scale = Vector2.ZERO
            shockwave.modulate = Color.WHITE
            var tw = explosion.create_tween().set_parallel(true)
            tw.tween_property(shockwave, "scale", Vector2.ONE * 3.0, 0.4)
            tw.tween_property(shockwave, "modulate:a", 0.0, 0.4).from(1.0)
        var sparks = explosion.get_node_or_null("Sparks")
        if sparks:
            sparks.emitting = true
            sparks.amount = 30
        get_tree().create_timer(0.5).timeout.connect(explosion.queue_free)
    
    queue_free()