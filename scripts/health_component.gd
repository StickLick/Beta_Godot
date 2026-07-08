class_name HealthComponent
extends Node

@export var max_health: float = 100.0

var current_health: float

signal health_changed(current: float, max: float)
signal health_depleted


func _ready() -> void:
    current_health = max_health
    health_changed.emit(current_health, max_health)


func take_damage(amount: float) -> void:
    current_health = clampf(current_health - amount, 0.0, max_health)
    health_changed.emit(current_health, max_health)
    if current_health <= 0.0:
        health_depleted.emit()


func heal(amount: float) -> void:
    current_health = clampf(current_health + amount, 0.0, max_health)
    health_changed.emit(current_health, max_health)
    
func update_max_health(new_max: float) -> void:
    var diff = new_max - max_health # Разница между старым и новым максимумом
    max_health = new_max
    current_health += diff          # "Лечим" игрока на эту разницу
    current_health = clampf(current_health, 0.0, max_health)
    health_changed.emit(current_health, max_health)
