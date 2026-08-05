class_name WarBannerIronBulwark
extends WarBanner

var tank_hp_mult: float = 2.0
var tank_knockback_force: float = 400.0


func _ready() -> void:
    unit_scene = preload("res://Assets/Scenes/IronBulwarkPawn.tscn")
    super._ready()


func apply_player_stats_to_units() -> void:
    super.apply_player_stats_to_units()
    if not is_instance_valid(player):
        return
    var hp_mult: float = player.max_health / PLAYER_BASE_HP
    for unit: Unit in _banner_units:
        if is_instance_valid(unit) and unit is IronBulwarkPawn:
            unit.knockback_force = tank_knockback_force
            unit.max_hp = BASE_UNIT_HP * hp_mult * tank_hp_mult
            if is_instance_valid(unit.health_component):
                unit.health_component.max_health = unit.max_hp
                unit.health_component.current_health = minf(
                    unit.health_component.current_health, unit.max_hp
                )
