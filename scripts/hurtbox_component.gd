class_name HurtboxComponent
extends Area2D

@export var health_component: HealthComponent
@export var invulnerability_duration: float = 0.5

var is_invulnerable: bool = false

var _invulnerability_timer: Timer

signal hit_received(damage: float)


func _ready() -> void:
	monitoring = true
	monitorable = true
	collision_layer = 4
	collision_mask = 2

	area_entered.connect(_on_area_entered)

	if health_component == null:
		health_component = _find_health_component()

	_invulnerability_timer = Timer.new()
	_invulnerability_timer.one_shot = true
	_invulnerability_timer.timeout.connect(_on_invulnerability_timeout)
	add_child(_invulnerability_timer)


func _on_area_entered(area: Area2D) -> void:
	if is_invulnerable:
		return

	if not area is HitboxComponent:
		return

	var hitbox: HitboxComponent = area as HitboxComponent

	if health_component == null:
		return

	health_component.take_damage(hitbox.damage)
	hit_received.emit(hitbox.damage)
	_start_invulnerability()


func _start_invulnerability() -> void:
	is_invulnerable = true
	_invulnerability_timer.start(invulnerability_duration)


func _on_invulnerability_timeout() -> void:
	is_invulnerable = false


func _find_health_component() -> HealthComponent:
	var parent: Node = get_parent()
	if parent == null:
		return null

	for child: Node in parent.get_children():
		if child is HealthComponent:
			return child as HealthComponent

	return null
