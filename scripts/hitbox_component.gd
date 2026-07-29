class_name HitboxComponent
extends Area2D

@export var damage: float = 10.0
@export var faction: String = "player"

# ── Knockback Support (for War Banner Inspired state) ──
var knockback_force: float = 0.0          # 0 = no knockback
var knockback_origin: Vector2 = Vector2.ZERO  # Direction to push AWAY from

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
    deal_damage_to_area(area, damage, faction, knockback_force, knockback_origin)

static func deal_damage_to_area(area: Area2D, amount: float, attacker_faction: String, kb_force: float = 0.0, kb_origin: Vector2 = Vector2.ZERO) -> void:
    if area.has_method("_apply_damage"):
        var target_f = area.get("faction")
        if target_f != null and str(target_f).to_lower() != attacker_faction.to_lower():
            area._apply_damage(amount)
            
            # Apply knockback if enabled
            if kb_force > 0.0:
                var target_body: CharacterBody2D = area.get_parent() as CharacterBody2D
                if is_instance_valid(target_body):
                    var kb_dir: Vector2 = (target_body.global_position - kb_origin).normalized()
                    target_body.velocity += kb_dir * kb_force
