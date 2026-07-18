extends CharacterBody2D
class_name Enemy

const XP_GEM_SCENE: PackedScene = preload("res://Assets/Scenes/Xp_gem.tscn")
const ENEMY_BULLET_SCENE: PackedScene = preload("res://Assets/Scenes/EnemyBullet.tscn")

enum Archetype { SWARMER, BREAKER, DISRUPTOR }

@export_group("Archetype Settings")
@export var current_archetype: Archetype = Archetype.SWARMER

@export_group("Stats")
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
        Archetype.SWARMER:
            speed = 160.0; xp_value = 5; scale = Vector2.ONE * 0.8
            if health_component: health_component.max_health = 15.0
        Archetype.BREAKER:
            speed = 65.0; xp_value = 50; scale = Vector2.ONE * 2.2
            modulate = Color.DARK_RED
            if health_component: health_component.max_health = 250.0
        Archetype.DISRUPTOR:
            speed = 130.0; xp_value = 35; scale = Vector2.ONE * 1.1
            modulate = Color.MEDIUM_PURPLE
            if health_component: health_component.max_health = 45.0
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
    var move_dir = dir
    var should_attack = false
    
    var reach = 130.0 if target_node is Camp else 55.0

    match current_archetype:
        Archetype.DISRUPTOR:
            if dist < 280: move_dir = -dir; speed = 180.0
            elif dist > 400: move_dir = dir; speed = 130.0
            else: move_dir = Vector2.ZERO
            if dist < 450 and attack_cooldown_timer <= 0: should_attack = true
        Archetype.BREAKER, Archetype.SWARMER:
            if dist < reach and attack_cooldown_timer <= 0: should_attack = true
    
    var target_vel = move_dir * speed
    if is_attacking: target_vel *= 0.3
    velocity = velocity.lerp(target_vel, delta * 8.0)
    if should_attack and not is_attacking: _execute_attack()
    if not is_attacking and dist > 10:
        if abs(dir.x) > 0.1: animated_sprite.flip_h = (dir.x < 0)
        animated_sprite.play("Run" if velocity.length() > 20 else "Idle")
    move_and_slide()

func _update_target() -> void:
    # ТОЛЬКО БРЕКЕР ИЩЕТ ЛАГЕРЯ
    if current_archetype == Archetype.BREAKER:
        var player_camps = get_tree().get_nodes_in_group("camps").filter(func(c): return c.alignment == 1)
        if not player_camps.is_empty():
            var closest = player_camps[0]
            var min_d = global_position.distance_to(closest.global_position)
            for camp in player_camps:
                var d = global_position.distance_to(camp.global_position)
                if d < min_d:
                    min_d = d
                    closest = camp
            target_node = closest
            return
            
    # ОСТАЛЬНЫЕ ВСЕГДА АТАКУЮТ ИГРОКА
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
    _toggle_hitbox() 
    var attacks = ["Attack1", "Attack2"]
    animated_sprite.play(attacks[attack_index])
    attack_index = (attack_index + 1) % 2

func _toggle_hitbox() -> void:
    if is_instance_valid(hitbox):
        var original_dmg = hitbox.damage
        if current_archetype == Archetype.BREAKER and target_node is Camp:
            hitbox.damage *= 12.0
        var shape = hitbox.get_node_or_null("CollisionShape2D")
        if shape:
            shape.disabled = false
            get_tree().create_timer(0.4).timeout.connect(func():
                if is_instance_valid(shape): shape.disabled = true
                hitbox.damage = original_dmg
            )

func _on_hit_received(_damage: float) -> void:
    var t = create_tween(); modulate = Color.RED
    t.tween_property(self, "modulate", Color.WHITE, 0.1)

func _on_death() -> void:
    var gem: XPGem = XP_GEM_SCENE.instantiate() as XPGem
    var rect = GameManager.get_meta("map_rect") if GameManager.has_meta("map_rect") else Rect2(-2000,-2000,4000,4000)
    var pos = global_position
    pos.x = clamp(pos.x, rect.position.x + 50, rect.end.x - 50)
    pos.y = clamp(pos.y, rect.position.y + 50, rect.end.y - 50)
    gem.global_position = pos; gem.xp_amount = xp_value
    get_tree().current_scene.call_deferred("add_child", gem)
    call_deferred("queue_free")
