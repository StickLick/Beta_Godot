class_name HitboxComponent
extends Area2D

@export var damage: float = 10.0


func _ready() -> void:
	monitoring = false
	monitorable = true
	collision_layer = 2
	collision_mask = 0
