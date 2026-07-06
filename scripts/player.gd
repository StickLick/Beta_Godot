extends CharacterBody2D

@export var max_speed: float = 250.0
@export var acceleration: float = 1800.0
@export var friction: float = 1500.0

@onready var health_component: HealthComponent = $HealthComponent


func _ready() -> void:
	health_component.health_depleted.connect(_on_death)

func _on_death() -> void:
	get_tree().reload_current_scene()


func _physics_process(delta: float) -> void:
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_vector != Vector2.ZERO:
		velocity = velocity.move_toward(input_vector * max_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
