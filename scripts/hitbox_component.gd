class_name HitboxComponent
extends Area2D

@export var damage: float = 10.0:
    set(value):
        damage = value
@export var faction: String = "player"


func _ready() -> void:
    monitoring = false
    monitorable = true

    var parent_name: String = get_parent().name if get_parent() != null else "unknown"
