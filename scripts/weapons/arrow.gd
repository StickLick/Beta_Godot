class_name Arrow
extends Area2D

@export var speed: float = 600.0
@export var damage: float = 10.0
@export var pierce_limit: int = 1

var faction: String = "player"
var _pierced: int = 0


func _ready() -> void:
    collision_layer = 0
    collision_mask = 12  # enemy hurtbox layer (bit 2 + bit 3 = 4 + 8)
    get_tree().create_timer(5.0).timeout.connect(queue_free)
    area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
    position += Vector2.RIGHT.rotated(rotation) * speed * delta


func _on_area_entered(area: Area2D) -> void:
    if area.has_method("_apply_damage"):
        var target_f = area.get("faction")
        if target_f != null and str(target_f).to_lower() != faction.to_lower():
            area._apply_damage(damage)
            _pierced += 1
            if _pierced >= pierce_limit:
                queue_free()
