class_name SkyArrow
extends Area2D

@export var speed: float = 800.0
@export var damage: float = 25.0
@export var aoe_radius: float = 120.0

const EXPLOSION_SCENE: PackedScene = preload("res://Assets/Scenes/Effects/Explosion.tscn")
const INDICATOR_SCENE: PackedScene = preload("res://Assets/Scenes/Effects/TargetIndicator.tscn")

var target_pos: Vector2 = Vector2.ZERO
var faction: String = "player"
var _impacted: bool = false


func _ready() -> void:
    collision_layer = 0
    collision_mask = 0  # no collision while falling
    get_tree().create_timer(8.0).timeout.connect(queue_free)
    
    # Set position AFTER being added to tree (parent sets .global_position)
    # Move to high above target
    global_position = target_pos + Vector2(0, -600)
    
    # Spawn indicator at target
    _spawn_indicator()
    
    print("[SKY ARROW] spawned at world pos: ", global_position, " targeting: ", target_pos)


func _spawn_indicator() -> void:
    var indicator = INDICATOR_SCENE.instantiate()
    if not indicator:
        print("[SKY ARROW] FAILED to instantiate indicator!")
        return
    
    var world_root = get_parent()
    if not world_root:
        world_root = get_tree().current_scene
    world_root.add_child(indicator)
    indicator.global_position = target_pos
    indicator.scale = Vector2.ZERO
    
    print("[SKY ARROW] spawned indicator at world pos: ", indicator.global_position)
    
    # Animate: expand to 1.0 then shrink to 0
    var tw = indicator.create_tween()
    tw.tween_property(indicator, "scale", Vector2.ONE * 1.2, 0.2)
    tw.tween_property(indicator, "modulate:a", 0.8, 0.0)
    tw.chain().tween_property(indicator, "scale", Vector2.ONE * 0.5, 0.2)
    tw.chain().tween_property(indicator, "modulate:a", 0.0, 0.05)
    tw.finished.connect(indicator.queue_free)


func _physics_process(delta: float) -> void:
    var current_global = global_position
    current_global.y += speed * delta
    global_position = current_global
    
    # Impact when reaching target Y
    if global_position.y >= target_pos.y and not _impacted:
        _impacted = true
        print("[SKY ARROW] IMPACT at world pos: ", global_position, " vs target: ", target_pos)
        _on_impact()


func _on_impact() -> void:
    # Explosion at world position
    _spawn_explosion()
    
    # AoE damage + knockback via physics query at target_pos
    var space_state = get_world_2d().direct_space_state
    if space_state != null:
        var query = PhysicsShapeQueryParameters2D.new()
        var circle = CircleShape2D.new()
        circle.radius = aoe_radius
        query.shape = circle
        query.transform = Transform2D(0, target_pos)
        query.collision_mask = 12  # enemy layer
        query.collide_with_areas = true
        query.collide_with_bodies = false
        var results = space_state.intersect_shape(query)
        for result in results:
            var collider = result.collider
            var target_f = collider.get("faction") if "faction" in collider else null
            if target_f != null and str(target_f).to_lower() == faction.to_lower():
                continue
            if collider.has_method("_apply_damage"):
                collider._apply_damage(damage)
            # Apply knockback to parent body
            var parent = collider.get_parent()
            if parent and parent is CharacterBody2D:
                var knockback_dir = (collider.global_position - target_pos).normalized()
                parent.velocity += knockback_dir * 300.0
    
    queue_free()


func _spawn_explosion() -> void:
    var explosion = EXPLOSION_SCENE.instantiate()
    if not explosion:
        return
    
    var world_root = get_parent()
    if not world_root:
        world_root = get_tree().current_scene
    world_root.add_child(explosion)
    explosion.global_position = target_pos
    
    var shockwave = explosion.get_node_or_null("Shockwave")
    if shockwave:
        shockwave.scale = Vector2.ZERO
        shockwave.modulate = Color.WHITE
        var tw = explosion.create_tween().set_parallel(true)
        tw.tween_property(shockwave, "scale", Vector2.ONE * 2.0, 0.25)
        tw.tween_property(shockwave, "modulate:a", 0.0, 0.25).from(1.0)
    
    var sparks = explosion.get_node_or_null("Sparks")
    if sparks:
        sparks.emitting = true
        sparks.amount = 20
    
    get_tree().create_timer(0.4).timeout.connect(explosion.queue_free)