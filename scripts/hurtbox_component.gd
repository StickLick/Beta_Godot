class_name HurtboxComponent
extends Area2D

@export var health_component: HealthComponent
@export var faction: String = "player"
@export var invulnerability_duration: float = 0.5

var _is_invulnerable: bool = false

var _invulnerability_timer: Timer

signal hit_received(damage: float)


func _ready() -> void:
	monitoring = true
	monitorable = true
	collision_layer = 4
	collision_mask = 2

	area_entered.connect(_on_area_entered)

	_invulnerability_timer = Timer.new()
	_invulnerability_timer.one_shot = true
	_invulnerability_timer.timeout.connect(_on_invulnerability_timeout)
	add_child(_invulnerability_timer)


func _on_area_entered(area: Area2D) -> void:
	var hitbox: HitboxComponent = area as HitboxComponent
	if hitbox == null:
		return

	if _is_invulnerable:
		return

	if hitbox.faction == faction:
		return

	if hitbox.owner == owner:
		return

	_apply_damage(hitbox.damage)


func _apply_damage(amount: float) -> void:
	if health_component == null:
		return

	health_component.take_damage(amount)
	hit_received.emit(amount)
	_is_invulnerable = true
	_invulnerability_timer.start(invulnerability_duration)


func _on_invulnerability_timeout() -> void:
	_is_invulnerable = false

	for area: Area2D in get_overlapping_areas():
		var hitbox: HitboxComponent = area as HitboxComponent
		if hitbox != null and hitbox.faction != faction and hitbox.owner != owner:
			_apply_damage(hitbox.damage)
			break
