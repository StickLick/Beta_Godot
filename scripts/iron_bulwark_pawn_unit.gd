class_name IronBulwarkPawn
extends PawnUnit

const TANK_KNOCKBACK_FORCE: float = 400.0


func _ready() -> void:
    knockback_force = TANK_KNOCKBACK_FORCE
    always_knockback = true
    super._ready()