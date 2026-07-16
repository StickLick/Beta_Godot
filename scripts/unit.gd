extends CharacterBody2D
class_name Unit

@export var speed: float = 160.0
@export var alignment: int = 1 
@export var max_hp: float = 30.0

var target: Node2D = null
var parent_camp: Node2D = null
var _attack_pulse_timer: float = 0.0

@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
    add_to_group("units")
    
    # Запустить анимацию
    animated_sprite.play("Run")
    
    if is_instance_valid(health_component):
        health_component.max_health = max_hp
        health_component.current_health = max_hp
        if not health_component.health_depleted.is_connected(queue_free):
            health_component.health_depleted.connect(queue_free)
    
    _setup_factions()
    _update_visuals()

func _setup_factions() -> void:
    var f_name = "player" if alignment == 1 else "rival"
    if is_instance_valid(hitbox): hitbox.faction = f_name
    if is_instance_valid(hurtbox): hurtbox.faction = f_name

func _physics_process(delta: float) -> void:
    _find_target()
    
    if is_instance_valid(target):
        var dir = (target.global_position - global_position).normalized()
        var dist = global_position.distance_to(target.global_position)
        
        velocity = dir * speed
        
        # --- ИСПРАВЛЕНИЕ: Вместо rotation используем flip_h ---
        # Если юнит движется, меняем направление спрайта
        if dir.x != 0:
            animated_sprite.flip_h = (dir.x < 0)
        # ----------------------------------------------------
        
        move_and_slide()
        
        # ПУЛЬСАЦИЯ УРОНА
        if dist < 60.0:
            _attack_pulse_timer += delta
            if _attack_pulse_timer >= 0.8:
                _attack_pulse_timer = 0.0
                _toggle_hitbox()
    else:
        velocity = Vector2.ZERO

# Кратковременное выключение/включение хитбокса заставляет Godot пересчитать урон
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
    
    # Юниты игрока ищут мобов ("enemy") и красных ("alignment 2")
    if alignment == 1:
        for e in get_tree().get_nodes_in_group("enemy"): potential.append(e)
        for u in get_tree().get_nodes_in_group("units"): if u.alignment == 2: potential.append(u)
        for c in get_tree().get_nodes_in_group("camps"): if c.alignment == 2: potential.append(c)
    # Юниты соперника ищут игрока и синих ("alignment 1")
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
