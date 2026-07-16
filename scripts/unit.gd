extends CharacterBody2D
class_name Unit

@export var speed: float = 180.0
@export var alignment: int = 1 
@export var max_hp: float = 30.0

var target: Node2D = null
var parent_camp: Node2D = null
var _attack_pulse_timer: float = 0.0

# Переменные для анимации
var is_attacking: bool = false
var attack_index: int = 0 # Счётчик для последовательной атаки

@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
    add_to_group("units")
    
    # Подключаем сигнал окончания анимации
    animated_sprite.animation_finished.connect(_on_animation_finished)
    
    animated_sprite.play("Run")
    
    if is_instance_valid(health_component):
        health_component.max_health = max_hp
        health_component.current_health = max_hp
        if not health_component.health_depleted.is_connected(queue_free):
            health_component.health_depleted.connect(queue_free)
    
    _setup_factions()
    _update_visuals()

# --- СИГНАЛ ОКОНЧАНИЯ АНИМАЦИИ ---
func _on_animation_finished() -> void:
    # Если закончилась одна из атак, сбрасываем флаг
    if animated_sprite.animation in ["Attack1", "Attack2"]:
        is_attacking = false

func _setup_factions() -> void:
    var f_name = "player" if alignment == 1 else "rival"
    if is_instance_valid(hitbox): hitbox.faction = f_name
    if is_instance_valid(hurtbox): hurtbox.faction = f_name

func _physics_process(delta: float) -> void:
    _find_target()
    
    if is_instance_valid(target):
        var dir = (target.global_position - global_position).normalized()
        var dist = global_position.distance_to(target.global_position)
        
        # ЛОГИКА АТАКИ
        if dist < 60.0:
            velocity = Vector2.ZERO # Останавливаемся
            
            # Запускаем атаку, ТОЛЬКО если сейчас не атакуем
            if not is_attacking:
                _play_sequential_attack()
            
            # ПУЛЬСАЦИЯ УРОНА
            _attack_pulse_timer += delta
            if _attack_pulse_timer >= 0.8:
                _attack_pulse_timer = 0.0
                _toggle_hitbox()
        else:
            # ЛОГИКА ДВИЖЕНИЯ
            velocity = dir * speed
            
            # Бежим, только если не заняты атакой
            if not is_attacking:
                if animated_sprite.animation != "Run":
                    animated_sprite.play("Run")
                if dir.x != 0:
                    animated_sprite.flip_h = (dir.x < 0)
        
        move_and_slide()
    else:
        velocity = Vector2.ZERO
        if not is_attacking and animated_sprite.animation != "Idle":
            animated_sprite.play("Idle")

# Новая функция последовательной атаки
func _play_sequential_attack() -> void:
    is_attacking = true
    var attacks = ["Attack1", "Attack2"]
    
    # Выбираем анимацию по индексу
    var anim_name = attacks[attack_index]
    animated_sprite.play(anim_name)
    
    # Переключаем индекс: 0 -> 1 -> 0
    attack_index = (attack_index + 1) % 2

func _toggle_hitbox() -> void:
    if is_instance_valid(hitbox):
        var shape = hitbox.get_node_or_null("CollisionShape2D")
        if shape:
            shape.disabled = true
            await get_tree().create_timer(0.1).timeout
            shape.disabled = false

func _find_target() -> void:
    if is_instance_valid(target): return
    var potential = []
    
    if alignment == 1:
        for e in get_tree().get_nodes_in_group("enemy"): potential.append(e)
        for u in get_tree().get_nodes_in_group("units"): if u.alignment == 2: potential.append(u)
        for c in get_tree().get_nodes_in_group("camps"): if c.alignment == 2: potential.append(c)
    else:
        potential.append(get_tree().get_first_node_in_group("player"))
        for u in get_tree().get_nodes_in_group("units"): if u.alignment == 1: potential.append(u)
        for c in get_tree().get_nodes_in_group("camps"): if c.alignment == 1: potential.append(c)

    var min_d = INF
    for t in potential:
        if is_instance_valid(t):
            var d = global_position.distance_to(t.global_position)
            if d < min_d: min_d = d; target = t

func flip_alignment(new_align: int) -> void:
    alignment = new_align
    _setup_factions()
    _update_visuals()
    target = null

func _update_visuals() -> void:
    modulate = Color.CORNFLOWER_BLUE if alignment == 1 else Color.INDIAN_RED
