extends Area2D

@export var speed: float = 600.0
@export var damage: float = 5.0 
var direction: Vector2 = Vector2.ZERO

func _ready() -> void:
    get_tree().create_timer(3.0).timeout.connect(queue_free)
    
    # Настройка через код для гарантии (соответствует твоим слоям)
    collision_layer = 16 # Слой 5 (2^4)
    collision_mask = 2   # Слой 2 (2^1)
    monitoring = true
    
    if not area_entered.is_connected(_on_area_entered):
        area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
    position += direction * speed * delta

func _on_area_entered(area: Area2D) -> void:
    # Пуля ищет любой HurtboxComponent
    if area.has_method("_apply_damage"):
        # Проверяем фракцию (игрок или его постройки)
        if area.faction.to_lower() == "player":
            area._apply_damage(damage)
            
            # Эффект замедления только если попали в игрока
            var target = area.get_parent()
            if target is Player:
                target.apply_disruptor_debuff(2.0)
            
            queue_free()
