class_name StarShardBase
extends Area2D

@export var speed: float = 300.0
@export var damage: float = 30.0
@export var burst_range: float = 120.0
@export var shard_count: int = 6

const SHARD_SCENE: PackedScene = preload("res://Assets/Scenes/Weapons/ArcaneBolt.tscn")

var direction: Vector2 = Vector2.RIGHT
var faction: String = "player"
var _has_burst: bool = false


func _ready() -> void:
    collision_layer = 0
    collision_mask = 12
    get_tree().create_timer(8.0).timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
    position += direction * speed * delta
    
    # Check if close enough to any enemy to burst
    if not _has_burst:
        _check_burst()


func _check_burst() -> void:
    var space_state = get_world_2d().direct_space_state
    if space_state == null:
        return
    
    var query = PhysicsShapeQueryParameters2D.new()
    var circle = CircleShape2D.new()
    circle.radius = burst_range
    query.shape = circle
    query.transform = Transform2D(0, global_position)
    query.collision_mask = 12
    query.collide_with_areas = true
    query.collide_with_bodies = false
    
    var results = space_state.intersect_shape(query)
    var enemy_nearby = false
    for result in results:
        var collider = result.collider
        var cf = collider.get("faction") if "faction" in collider else null
        if cf != null and str(cf).to_lower() == faction.to_lower():
            continue
        if collider.has_method("_apply_damage"):
            enemy_nearby = true
            break
    
    if enemy_nearby:
        _burst()


func _burst() -> void:
    _has_burst = true
    var root = get_tree().current_scene
    
    for i in range(shard_count):
        var angle = deg_to_rad(360.0 * i / shard_count)
        var shard = SHARD_SCENE.instantiate() as ArcaneBolt
        if not shard:
            continue
        root.add_child(shard)
        shard.global_position = global_position
        shard.direction = Vector2.RIGHT.rotated(angle)
        shard.damage = damage * 0.5
        shard.speed = 500.0
    
    queue_free()