extends Area2D

enum ZoneType { ACCELERATION, STABILIZATION, PRESSURE, FLUX }
enum ZoneState { SPAWN, GROWTH, ACTIVE, DECAY, DESPAWN }

@export var zone_type: ZoneType = ZoneType.ACCELERATION
@export var effect_radius: float = 50.0
@export var soft_influence_radius: float = 100.0
@export var zone_mass: float = 10.0

var current_state: ZoneState = ZoneState.SPAWN
var growth_rate: float = 1.0
var absorb_rate: float = 0.5
var dominance: float = 100.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
    if collision_shape.shape is CircleShape2D:
        (collision_shape.shape as CircleShape2D).radius = effect_radius
    else:
        var circle_shape: CircleShape2D = CircleShape2D.new()
        circle_shape.radius = effect_radius
        collision_shape.shape = circle_shape

    var sprite_base_size: float = 64.0
    var scale_factor: float = (effect_radius * 2.0) / sprite_base_size
    sprite.scale = Vector2(scale_factor, scale_factor)
