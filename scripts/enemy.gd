extends CharacterBody2D
class_name Enemy

const XP_GEM_SCENE: PackedScene = preload("res://Assets/Scenes/Xp_gem.tscn")

@export var speed: float = 120.0
@export var xp_value: int = 10
@export var health_component: HealthComponent
@export var attack_delay: float = 1.0 

@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_attacking: bool = false
var attack_index: int = 0
var attack_cooldown_timer: float = 0.0

func _ready() -> void:
    add_to_group("enemy")
    
    if health_component == null: health_component = $HealthComponent
    if health_component: health_component.health_depleted.connect(_on_death)
    
    if hurtbox:
        hurtbox.hit_received.connect(func(_d): 
            var t = create_tween(); modulate = Color.RED
            t.tween_property(self, "modulate", Color.WHITE, 0.1))
        hurtbox.faction = "enemy"
    
    if hitbox: 
        hitbox.faction = "enemy"
        var shape = hitbox.get_node_or_null("CollisionShape2D")
        if shape: shape.disabled = true
    
    animated_sprite.animation_finished.connect(_on_animation_finished)
    animated_sprite.play("Run")

func _on_animation_finished() -> void:
    if animated_sprite.animation in ["Attack1", "Attack2"]:
        is_attacking = false
        animated_sprite.play("Run")

func _physics_process(delta: float) -> void:
    if attack_cooldown_timer > 0:
        attack_cooldown_timer -= delta
    
    var player = get_tree().get_first_node_in_group("player")
    
    if player:
        var dist = global_position.distance_to(player.global_position)
        var dir = (player.global_position - global_position).normalized()
        
        # 1. ЛОГИКА СКОРОСТИ
        var target_speed = speed
        if is_attacking:
            target_speed = speed * 0.8
            if dist < 20.0: target_speed = 0
        
        # 2. ПЛАВНОЕ ДВИЖЕНИЕ (Lerp)
        var acceleration = 15.0 if not is_attacking else 5.0
        velocity = velocity.lerp(dir * target_speed, delta * acceleration)
        
        # 3. ЛОГИКА АТАКИ
        if dist < 45.0:
            if not is_attacking and attack_cooldown_timer <= 0:
                _play_sequential_attack()
        
        # 4. ПОВОРОТ СПРАЙТА (Исправлено: добавлена проверка дистанции)
        # Если враг вплотную (dist < 15), мы не меняем направление, чтобы избежать дрожания
        if not is_attacking and dist > 15.0:
            if abs(dir.x) > 0.05:
                animated_sprite.flip_h = (dir.x < 0)
        
        # 5. АНИМАЦИЯ
        if not is_attacking:
            if animated_sprite.animation != "Run":
                animated_sprite.play("Run")
        
        move_and_slide()
    else:
        velocity = velocity.lerp(Vector2.ZERO, delta * 10)
        if not is_attacking and animated_sprite.animation != "Idle":
            animated_sprite.play("Idle")

func _play_sequential_attack() -> void:
    is_attacking = true
    attack_cooldown_timer = attack_delay
    
    _toggle_hitbox() 
    
    var attacks = ["Attack1", "Attack2"]
    var anim_name = attacks[attack_index]
    animated_sprite.play(anim_name)
    
    attack_index = (attack_index + 1) % 2

func _toggle_hitbox() -> void:
    if is_instance_valid(hitbox):
        var shape = hitbox.get_node_or_null("CollisionShape2D")
        if shape:
            shape.disabled = false
            await get_tree().create_timer(0.3).timeout 
            if is_instance_valid(shape):
                shape.disabled = true

func _on_death() -> void:
    var gem: XPGem = XP_GEM_SCENE.instantiate() as XPGem
    var rect = GameManager.get_meta("map_rect") if GameManager.has_meta("map_rect") else Rect2(-2000,-2000,4000,4000)
    var pos = global_position
    pos.x = clamp(pos.x, rect.position.x + 50, rect.end.x - 50)
    pos.y = clamp(pos.y, rect.position.y + 50, rect.end.y - 50)
    gem.global_position = pos
    gem.xp_amount = xp_value
    get_tree().current_scene.call_deferred("add_child", gem)
    call_deferred("queue_free")
