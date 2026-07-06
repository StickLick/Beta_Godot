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
	monitorable = false

	area_entered.connect(_on_area_entered)

	_invulnerability_timer = Timer.new()
	_invulnerability_timer.one_shot = true
	_invulnerability_timer.timeout.connect(_on_invulnerability_timeout)
	add_child(_invulnerability_timer)


func _on_area_entered(area: Area2D) -> void:
	var hitbox: HitboxComponent = area as HitboxComponent
	if not hitbox:
		return

	if _is_invulnerable:
		return

	if _factions_match(hitbox.faction, faction):
		return

	if hitbox.get_parent() == get_parent() or hitbox.owner == owner or hitbox.get_parent() == self:
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
		if not hitbox:
			continue

		if _factions_match(hitbox.faction, faction):
			continue

		if hitbox.get_parent() == get_parent() or hitbox.owner == owner or hitbox.get_parent() == self:
			continue

		_apply_damage(hitbox.damage)
		break


func _factions_match(faction_a: String, faction_b: String) -> bool:
	return faction_a.to_lower() == faction_b.to_lower()
