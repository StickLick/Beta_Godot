extends Area2D

@export var speed: float = 600.0
@export var damage: float = 5.0 
var direction: Vector2 = Vector2.ZERO
var faction: String = "enemy" 

func _ready() -> void:
    get_tree().create_timer(3.0).timeout.connect(queue_free)
    area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
    position += direction * speed * delta

func _on_area_entered(area: Area2D) -> void:
    if area.has_method("_apply_damage"):
        var target_f = area.get("faction")
        if target_f != null and target_f.to_lower() != faction.to_lower():
            area._apply_damage(damage)
            
            var p = area.get_parent()
            if is_instance_valid(p) and p.has_method("apply_disruptor_debuff"):
                p.apply_disruptor_debuff(2.0)
            queue_free()
