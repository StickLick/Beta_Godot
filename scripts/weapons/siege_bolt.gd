class_name SiegeBolt
extends Area2D

@export var speed: float = 350.0
@export var damage: float = 130.0
@export var pierce_limit: int = 3
@export var aoe_radius: float = 80.0
@export var aoe_damage_percent: float = 0.5

const EXPLOSION_SCENE: PackedScene = preload("res://Assets/Scenes/Effects/Explosion.tscn")

@onready var _tip: Marker2D = $Tip

var faction: String = "player"
var _pierced: int = 0


func _ready() -> void:
    collision_layer = 0
    collision_mask = 12  # enemy hurtbox layer (bits 2+3 = 4+8)
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
    
    # Direct hit damage
    area._apply_damage(damage)
    _pierced += 1
    
    # AoE explosion around the hit target
    _spawn_explosion()
    _trigger_aoe()
    
    if _pierced >= pierce_limit:
        queue_free()


func _spawn_explosion() -> void:
    var explosion = EXPLOSION_SCENE.instantiate()
    if not explosion:
        return
    
    var root = get_tree().current_scene
    root.add_child(explosion)
    explosion.global_position = _tip.global_position if is_instance_valid(_tip) else global_position + Vector2.RIGHT.rotated(rotation) * 30.0
    
    var shockwave = explosion.get_node_or_null("Shockwave")
    var sparks = explosion.get_node_or_null("Sparks")
    
    # Flash: quick white pulse, expand + fade (tween on explosion, not bolt)
    if shockwave:
        shockwave.scale = Vector2.ZERO
        shockwave.modulate = Color.WHITE
        var tw = explosion.create_tween().set_parallel(true)
        tw.tween_property(shockwave, "scale", Vector2.ONE * 1.5, 0.2)
        tw.tween_property(shockwave, "modulate:a", 0.0, 0.2).from(1.0)
        
        # Shader shockwave ring
        if shockwave.material is ShaderMaterial:
            var mat = shockwave.material as ShaderMaterial
            var tween2 = explosion.create_tween()
            tween2.tween_method(
                func(p: float): mat.set_shader_parameter("progress", p),
                0.0, 1.0, 0.2
            )
    
    if sparks:
        sparks.emitting = true
        sparks.amount = 15
        if sparks.process_material is ParticleProcessMaterial:
            var ppm = sparks.process_material as ParticleProcessMaterial
            ppm.scale_min = 2.0
            ppm.scale_max = 5.0
    
    # Cleanup after animation
    get_tree().create_timer(0.4).timeout.connect(explosion.queue_free)


func _trigger_aoe() -> void:
    var space_state = get_world_2d().direct_space_state
    if space_state == null:
        return
    
    var query = PhysicsShapeQueryParameters2D.new()
    var circle = CircleShape2D.new()
    circle.radius = aoe_radius
    query.shape = circle
    query.transform = Transform2D(0, global_position)
    query.collision_mask = 12  # enemy layer
    query.collide_with_areas = true
    query.collide_with_bodies = false
    
    var results = space_state.intersect_shape(query)
    var aoe_dmg = damage * aoe_damage_percent
    
    for result in results:
        var collider = result.collider
        var target_f = collider.get("faction") if "faction" in collider else null
        if target_f != null and str(target_f).to_lower() == faction.to_lower():
            continue
        if collider.has_method("_apply_damage"):
            collider._apply_damage(aoe_dmg)
