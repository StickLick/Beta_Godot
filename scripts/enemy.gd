extends CharacterBody2D
class_name Enemy

const XP_GEM_SCENE = preload("res://Assets/Scenes/Xp_gem.tscn")
const ENEMY_BULLET_SCENE = preload("res://Assets/Scenes/EnemyBullet.tscn")

enum Archetype { SWARMER, BREAKER, DISRUPTOR }
@export var current_archetype: Archetype = Archetype.SWARMER
@export var speed: float = 120.0
@export var xp_value: int = 10
@export var health_component: HealthComponent
@export var attack_delay: float = 1.2

@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_attacking: bool = false
var attack_index: int = 0
var attack_cooldown_timer: float = 0.0
var target_node: Node2D = null

func _ready() -> void:
    add_to_group("enemy")
    if health_component == null: health_component = $HealthComponent
    if health_component: health_component.health_depleted.connect(_on_death)
    if hurtbox:
        hurtbox.hit_received.connect(_on_hit_received)
        hurtbox.faction = "enemy"
        hurtbox.collision_layer = 8
    if hitbox: 
        hitbox.faction = "enemy"
        var shape = hitbox.get_node_or_null("CollisionShape2D")
        if shape: shape.disabled = true
    if animated_sprite:
        animated_sprite.animation_finished.connect(_on_animation_finished)
        animated_sprite.play("Run")
    setup_archetype(current_archetype)

func setup_archetype(type: Archetype) -> void:
    current_archetype = type
    match current_archetype:
        Archetype.SWARMER: speed = 160.0; xp_value = 5; scale = Vector2(0.8, 0.8)
        Archetype.BREAKER: speed = 65.0; xp_value = 50; scale = Vector2(2.2, 2.2); modulate = Color.DARK_RED
        Archetype.DISRUPTOR: speed = 130.0; xp_value = 35; scale = Vector2(1.1, 1.1); modulate = Color.MEDIUM_PURPLE
    if health_component: health_component.current_health = health_component.max_health

func _on_animation_finished() -> void:
    if animated_sprite.animation in ["Attack1", "Attack2"]:
        is_attacking = false; animated_sprite.play("Run")

func _physics_process(delta: float) -> void:
    if attack_cooldown_timer > 0: attack_cooldown_timer -= delta
    _update_target()
    if not target_node: return
    
    var dist = global_position.distance_to(target_node.global_position)
    var dir = (target_node.global_position - global_position).normalized()
    
    var accel = 10.0
    if GameManager.get_meta("inertia_active"): accel = 0.8
    
    var move_dir = dir
    if current_archetype == Archetype.DISRUPTOR:
        if dist < 280: move_dir = -dir; speed = 180.0
        elif dist > 400: move_dir = dir; speed = 130.0
        else: move_dir = Vector2.ZERO
    
    var final_speed = speed * GameManager.get_meta("enemy_stat_mult")
    if dist < 25.0 and not GameManager.get_meta("inertia_active"):
        velocity = velocity.lerp(Vector2.ZERO, delta * 15.0)
    else:
        velocity = velocity.lerp(move_dir * final_speed, delta * accel)
    
    _apply_gravity_logic(delta)
    
    var attack_range = 450.0 if current_archetype == Archetype.DISRUPTOR else 65.0
    if dist < attack_range and attack_cooldown_timer <= 0 and not is_attacking:
        _execute_attack()
    
    if not is_attacking and dist > 40.0:
        if abs(dir.x) > 0.1: animated_sprite.flip_h = (dir.x < 0)
        animated_sprite.play("Run" if velocity.length() > 20 else "Idle")
    move_and_slide()

func _apply_gravity_logic(delta: float) -> void:
    var wells = get_tree().get_nodes_in_group("gravity_well")
    for well in wells:
        var vec = well.global_position - global_position
        var d = vec.length()
        var active_radius = well.pull_radius
        if well.current_state == 1: active_radius = well.influence_radius
        if d < active_radius:
            var dir = vec.normalized()
            var f = clamp(1.1 - (d / active_radius), 0.2, 1.0)
            if well.current_state == 2:
                velocity -= dir * (well.push_strength * f * delta)
            else:
                var power = well.pull_strength
                if well.current_state == 1:
                    power *= 4.5
                    if d > well.pull_radius: power *= 0.8
                velocity += dir * (power * f * delta)

func _update_target() -> void:
    if GameManager.current_anomaly == "HUNT":
        target_node = get_tree().get_first_node_in_group("player"); return
    if GameManager.current_anomaly == "SEIZE":
        var seize_targets = get_tree().get_nodes_in_group("camps").filter(func(c): return is_instance_valid(c) and c.has_meta("is_seize_target") and c.get_meta("is_seize_target") == true)
        if not seize_targets.is_empty():
            var closest = seize_targets[0]; var min_d = global_position.distance_to(closest.global_position)
            for c in seize_targets:
                var d = global_position.distance_to(c.global_position); if d < min_d: min_d = d; closest = c
            target_node = closest; return
    if current_archetype == Archetype.BREAKER:
        var player_camps = get_tree().get_nodes_in_group("camps").filter(func(c): return is_instance_valid(c) and c.alignment == 1)
        if not player_camps.is_empty():
            var closest = player_camps[0]; var min_d = global_position.distance_to(closest.global_position)
            for camp in player_camps:
                var d = global_position.distance_to(camp.global_position); if d < min_d: min_d = d; closest = camp
            target_node = closest; return
    target_node = get_tree().get_first_node_in_group("player")

func _execute_attack() -> void:
    is_attacking = true; attack_cooldown_timer = attack_delay
    if current_archetype == Archetype.DISRUPTOR: _shoot()
    else: _play_sequential_melee()

func _shoot() -> void:
    if not ENEMY_BULLET_SCENE: return
    var bullet = ENEMY_BULLET_SCENE.instantiate()
    bullet.global_position = global_position
    bullet.direction = (target_node.global_position - global_position).normalized()
    get_tree().current_scene.add_child(bullet)
    animated_sprite.play("Attack1")

func _play_sequential_melee() -> void:
    # ИСПРАВЛЕНО: Безопасное переключение хитбокса
    _toggle_hitbox() 
    var attacks = ["Attack1", "Attack2"]
    animated_sprite.play(attacks[attack_index])
    attack_index = (attack_index + 1) % 2

func _toggle_hitbox() -> void:
    if is_instance_valid(hitbox):
        var original_dmg = hitbox.damage
        if current_archetype == Archetype.BREAKER and target_node is Camp: hitbox.damage *= 12.0
        var shape = hitbox.get_node_or_null("CollisionShape2D")
        if shape:
            shape.disabled = false
            hitbox.check_hit()
            # Используем таймер сцены для безопасности
            get_tree().create_timer(0.4).timeout.connect(_disable_shape.bind(shape, original_dmg))

func _disable_shape(shape: CollisionShape2D, dmg: float) -> void:
    if is_instance_valid(shape): shape.disabled = true
    if is_instance_valid(hitbox): hitbox.damage = dmg

func _on_hit_received(_damage: float) -> void:
    var t = create_tween(); modulate = Color.RED
    t.tween_property(self, "modulate", Color.WHITE, 0.1)

func _on_death() -> void:
    var gem: XPGem = XP_GEM_SCENE.instantiate() as XPGem
    var rect = GameManager.get_meta("map_rect") if GameManager.has_meta("map_rect") else Rect2(-2000,-2000,4000,4000)
    var pos = global_position
    pos.x = clamp(pos.x, rect.position.x + 50, rect.end.x - 50)
    pos.y = clamp(pos.y, rect.position.y + 50, rect.end.y - 50)
    gem.global_position = pos; gem.xp_amount = int(xp_value * GameManager.get_meta("xp_mult"))
    get_tree().current_scene.call_deferred("add_child", gem); queue_free()
