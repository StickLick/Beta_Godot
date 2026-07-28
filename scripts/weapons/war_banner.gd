class_name WarBanner
extends BaseWeapon

@export var max_banner_units: int = 2
@export var banner_duration: float = 8.0
@export var spawn_range: float = 80.0

const UNIT_SCENE: PackedScene = preload("res://Assets/Scenes/Unit.tscn")
const BANNER_ZONE_SCENE: PackedScene = preload("res://Assets/Scenes/Weapons/BannerZone.tscn")

var _banner_units: Array[Unit] = []
var _active_banner: BannerZone = null
var _has_deployed_banner: bool = false


func _weapon_ready() -> void:
    cooldown_timer.timeout.connect(_on_cooldown_timeout)
    cooldown_timer.start(attack_cooldown)


func _on_cooldown_timeout() -> void:
    if not is_instance_valid(player):
        cooldown_timer.start(0.5)
        return
    
    # Clean dead units
    _banner_units = _banner_units.filter(func(u): return is_instance_valid(u))
    
    if not _has_deployed_banner and _banner_units.size() < max_banner_units:
        # Spawn a new unit following the player
        _spawn_banner_unit()
        cooldown_timer.start(attack_cooldown)
    elif not _has_deployed_banner:
        # Units are full — deploy the banner
        _deploy_banner()
        cooldown_timer.start(attack_cooldown + banner_duration)
    else:
        # Banner is active — maintain units
        for i in range(max_banner_units - _banner_units.size()):
            _spawn_banner_unit()
        cooldown_timer.start(attack_cooldown)


func _spawn_banner_unit() -> void:
    if not UNIT_SCENE:
        return
    
    var unit = UNIT_SCENE.instantiate() as Unit
    if not unit:
        return
    
    var root = get_tree().current_scene
    root.add_child(unit)
    
    # Position near the player
    unit.global_position = player.global_position + Vector2.from_angle(randf() * TAU) * spawn_range
    unit.alignment = 1
    unit.banner_owner = self
    
    # Follow the player initially
    unit.guard_target = player
    
    _banner_units.append(unit)


func _deploy_banner() -> void:
    if not BANNER_ZONE_SCENE or not is_instance_valid(player):
        return
    
    var banner = BANNER_ZONE_SCENE.instantiate() as BannerZone
    if not banner:
        return
    
    var root = get_tree().current_scene
    root.add_child(banner)
    banner.global_position = player.global_position
    banner.banner_owner = self
    banner.duration = banner_duration
    
    _active_banner = banner
    _has_deployed_banner = true
    
    # All units switch to guarding the banner
    for unit in _banner_units:
        if is_instance_valid(unit):
            unit.guard_target = banner


func _on_banner_unit_died(unit: Unit) -> void:
    _banner_units.erase(unit)


func _on_banner_zone_expired() -> void:
    _active_banner = null
    _has_deployed_banner = false
    
    # Units return to follow the player
    for unit in _banner_units:
        if is_instance_valid(unit):
            unit.guard_target = player
