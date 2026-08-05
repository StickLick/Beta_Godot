class_name WarBannerArcher
extends WarBanner

var archer_attack_range: float = 380.0
var archer_attack_speed: float = 1.0

const MAX_ARCHER_ATTACK_SPEED: float = 3.0


func _ready() -> void:
    unit_scene = preload("res://Assets/Scenes/ArcherPawn.tscn")
    super._ready()
    if leash_visual:
        leash_visual.visible = false


func apply_player_stats_to_units() -> void:
    super.apply_player_stats_to_units()
    if not is_instance_valid(player):
        return
    var range_mult: float = player.radius_weapons
    var speed_clamped: float = minf(archer_attack_speed, MAX_ARCHER_ATTACK_SPEED)
    for unit: Unit in _banner_units:
        if is_instance_valid(unit) and unit is ArcherPawnUnit:
            unit.attack_range = archer_attack_range * range_mult
            if is_instance_valid(unit.animated_sprite):
                unit.animated_sprite.speed_scale = speed_clamped