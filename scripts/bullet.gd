extends Area2D

@export var speed: float = 750.0
@export var damage: float = 10.0 
var faction: String = "player" 

func _ready() -> void:
    var rect = ColorRect.new()
    rect.size = Vector2(6, 6)
    rect.position = Vector2(-3, -3)
    rect.color = Color.YELLOW
    add_child(rect)
    
    # АВТО-МАСКА: Синяя пуля ищет Слой 4 (враги), Красная ищет Слой 2 (игрок)
    collision_layer = 0
    collision_mask = 8 if faction.to_lower() == "player" else 2
    
    get_tree().create_timer(1.5).timeout.connect(queue_free)
    area_entered.connect(_on_hit)

func _physics_process(delta: float) -> void:
    position += Vector2.RIGHT.rotated(rotation) * speed * delta

func _on_hit(area: Area2D) -> void:
    if area.has_method("_apply_damage"):
        var target_f = area.get("faction")
        if target_f != null and str(target_f).to_lower() != faction.to_lower():
            area._apply_damage(damage)
            queue_free()
