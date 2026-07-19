class_name HitboxComponent
extends Area2D

@export var damage: float = 10.0
@export var faction: String = "player" 

func _ready() -> void:
    monitoring = true
    monitorable = false
    if not area_entered.is_connected(_on_area_entered):
        area_entered.connect(_on_area_entered)

# Проверка тех, кто уже внутри в момент взмаха
func check_hit() -> void:
    for area in get_overlapping_areas():
        _try_damage(area)

func _on_area_entered(area: Area2D) -> void:
    _try_damage(area)

func _try_damage(area: Area2D) -> void:
    if area.has_method("_apply_damage"):
        var target_f = area.get("faction")
        if target_f != null and str(target_f).to_lower() != faction.to_lower():
            area._apply_damage(damage)
