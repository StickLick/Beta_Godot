class_name ArcherPawnUnit
extends PawnUnit

const ARROW_SCENE: PackedScene = preload("res://Assets/Scenes/Weapons/Arrow.tscn")

func _ready() -> void:
    is_ranged = true
    attack_range = 380.0
    comfort_distance = 175.0
    super._ready()

func _play_sequential_attack(_target: Node2D = null, _banner: WarBanner = null) -> void:
    is_attacking = true
    if animated_sprite.sprite_frames.has_animation("Attack"):
        animated_sprite.play("Attack")
    elif animated_sprite.sprite_frames.has_animation("Attack1"):
        animated_sprite.play("Attack1")
    _fire_volley_at_target(_target, _banner)

func _fire_volley_at_target(target: Node2D, banner: WarBanner) -> void:
    if not is_instance_valid(target) or not ARROW_SCENE:
        return
    var dir_to_target = (target.global_position - global_position).normalized()
    var base_angle = atan2(dir_to_target.y, dir_to_target.x)
    var amount = _get_projectile_amount(banner)
    amount = maxi(1, amount)
    _fire_volley(base_angle, amount, banner)

# Archer pawn volley size is fixed, NOT derived from player.projectile_amount
# (that stat is Bow-only). Future scaling should come from Banner-specific
# weapon upgrades instead.
func _get_projectile_amount(banner: WarBanner) -> int:
    return 1

func _fire_volley(base_angle: float, amount: int, banner: WarBanner) -> void:
    if amount == 1:
        _spawn_arrow(base_angle, banner)
        return
    var total_spread = float(amount - 1) * 15.0
    var start_angle = base_angle - deg_to_rad(total_spread / 2.0)
    for i in range(amount):
        _spawn_arrow(start_angle + deg_to_rad(float(i) * 15.0), banner)

func _spawn_arrow(angle: float, banner: WarBanner) -> void:
    var arrow = ARROW_SCENE.instantiate() as Arrow
    if not arrow:
        return
    if is_instance_valid(banner):
        arrow.damage = banner.final_damage * 0.5
        arrow.pierce_limit = banner.final_pierce
    else:
        arrow.damage = 10.0
        arrow.pierce_limit = 1
    arrow.faction = "player"
    arrow.global_position = global_position
    arrow.rotation = angle
    get_tree().current_scene.add_child(arrow)
    SoundManager.play(SoundManager.shoot_bow_sound, SoundManager.shoot_bow_volume_db, SoundManager.shoot_bow_pitch * randf_range(0.96, 1.04))
