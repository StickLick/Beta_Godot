class_name HurtboxComponent
extends Area2D

@export var health_component: HealthComponent
@export var faction: String = "enemy" 
@export var invulnerability_duration: float = 0.1

var _is_invulnerable: bool = false

signal hit_received(damage: float)
signal crit_received(damage: float)

func _ready() -> void:
    monitorable = true
    monitoring = true

func _apply_damage(amount: float) -> void:
    if _is_invulnerable or not is_instance_valid(health_component):
        return
    
    if invulnerability_duration > 0:
        _is_invulnerable = true
        get_tree().create_timer(invulnerability_duration).timeout.connect(func(): _is_invulnerable = false)
    
    # Крит-ролл централизованно: hurtbox - единственная точка, через которую
    # проходят все источники урона игрока (хитбоксы, снаряды, прямые вызовы).
    # Крит действует только на урон по врагам; урон игроку/юнитам НЕ критует.
    var final_amount: float = amount
    var is_crit: bool = false
    if str(faction).to_lower() == "enemy":
        var player := get_tree().get_first_node_in_group("player") as Player
        if Player.roll_crit(player):
            is_crit = true
            final_amount = amount * player.crit_damage
    
    if health_component.has_method("take_damage"):
        health_component.take_damage(final_amount)
    elif "current_health" in health_component:
        health_component.current_health -= final_amount
        
    hit_received.emit(final_amount)
    if is_crit:
        crit_received.emit(final_amount)
