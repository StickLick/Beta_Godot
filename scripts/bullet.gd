extends Area2D

var speed = 750.0
var damage = 10.0
var faction = "player"

func _ready() -> void:
    var rect = ColorRect.new()
    rect.size = Vector2(6, 6)
    rect.position = Vector2(-3, -3)
    rect.color = Color.YELLOW
    add_child(rect)
    
    get_tree().create_timer(1.5).timeout.connect(queue_free)
    area_entered.connect(_on_hit)

func _physics_process(delta: float) -> void:
    position += Vector2.RIGHT.rotated(rotation) * speed * delta

func _on_hit(area: Area2D) -> void:
    if area.has_method("_apply_damage") and area.get("faction") != faction:
        area._apply_damage(damage)
        queue_free()
