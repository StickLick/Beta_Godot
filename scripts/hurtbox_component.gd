class_name HurtboxComponent
extends Area2D

@export var health_component: HealthComponent
@export var faction: String = "enemy" 
@export var invulnerability_duration: float = 0.1

var _is_invulnerable: bool = false

signal hit_received(damage: float)

func _ready() -> void:
    monitorable = true
    monitoring = true

func _apply_damage(amount: float) -> void:
    if _is_invulnerable or not is_instance_valid(health_component):
        return
    
    if invulnerability_duration > 0:
        _is_invulnerable = true
        get_tree().create_timer(invulnerability_duration).timeout.connect(func(): _is_invulnerable = false)
    
    if health_component.has_method("take_damage"):
        health_component.take_damage(amount)
    elif "current_health" in health_component:
        health_component.current_health -= amount
        
    hit_received.emit(amount)
