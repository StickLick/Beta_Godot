class_name HitboxComponent
extends Area2D

@export var damage: float = 10.0:
    set(value):
        damage = value
        print("DEBUG: Hitbox изменил урон на: ", value)
@export var faction: String = "player"


func _ready() -> void:
    monitoring = false
    monitorable = true

    var parent_name: String = get_parent().name if get_parent() != null else "unknown"

    if collision_layer == 0:
        print(
            "[HITBOX ERROR] Hitbox on node '" + parent_name + "' has no collision layer set in Inspector!"
        )

    if faction == "":
        print(
            "[HITBOX WARNING] Hitbox on node '" + parent_name + "' has an empty faction!"
        )
