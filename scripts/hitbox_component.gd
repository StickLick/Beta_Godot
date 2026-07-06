class_name HitboxComponent
extends Area2D

@export var damage: float = 10.0
@export var faction: String = "player"


func _ready() -> void:
	monitoring = false
	monitorable = true
