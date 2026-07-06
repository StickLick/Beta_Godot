extends CharacterBody2D

@export var max_speed: float = 250.0
@export var acceleration: float = 1800.0
@export var friction: float = 1500.0

@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent
@onready var polygon: Polygon2D = $Polygon2D


func _ready() -> void:
    add_to_group("player")
    health_component.health_depleted.connect(_on_death)
    hurtbox_component.hit_received.connect(_on_hit_received)

func _on_death() -> void:
    get_tree().reload_current_scene()


func _on_hit_received(damage: float) -> void:
    print("Player took %.1f damage" % damage)
    _flash_damage()


func _flash_damage() -> void:
    polygon.modulate = Color.RED
    var tween: Tween = create_tween()
    tween.tween_property(polygon, "modulate", Color.WHITE, 0.15)


func _physics_process(delta: float) -> void:
    var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")

    if input_vector != Vector2.ZERO:
        velocity = velocity.move_toward(input_vector * max_speed, acceleration * delta)
    else:
        velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

    move_and_slide()
