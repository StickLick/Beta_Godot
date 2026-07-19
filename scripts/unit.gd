extends CharacterBody2D
class_name Unit

@export_group("Unit Settings")
@export var speed: float = 180.0
@export var alignment: int = 1 
@export var max_hp: float = 30.0

var target: Node2D = null
var parent_camp: Node2D = null
var _attack_pulse_timer: float = 0.0

var is_attacking: bool = false
var attack_index: int = 0 

@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
    add_to_group("units")
    if animated_sprite:
        animated_sprite.animation_finished.connect(_on_animation_finished)
        animated_sprite.play("Run")
    
    if is_instance_valid(health_component):
        health_component.max_health = max_hp
        health_component.current_health = max_hp
        if not health_component.health_depleted.is_connected(queue_free):
            health_component.health_depleted.connect(queue_free)
    
    _setup_physics_and_factions()
    _update_visuals()

func _on_animation_finished() -> void:
    if animated_sprite.animation in ["Attack1", "Attack2"]:
        is_attacking = false

func _setup_physics_and_factions() -> void:
    var f_name = "player" if alignment == 1 else "rival"
    if is_instance_valid(hitbox): 
        hitbox.faction = f_name
        hitbox.collision_mask = 8 if alignment == 1 else 2 
        
    if is_instance_valid(hurtbox): 
        hurtbox.faction = f_name
        hurtbox.collision_layer = 2 if alignment == 1 else 8

func _physics_process(delta: float) -> void:
    _find_target()
    if is_instance_valid(target):
        var breaker = _get_nearby_enemy_breaker()
        if breaker: target = breaker
        var dir = (target.global_position - global_position).normalized()
        var dist = global_position.distance_to(target.global_position)
        if dist < 60.0:
            velocity = Vector2.ZERO
            if not is_attacking: _play_sequential_attack()
            _attack_pulse_timer += delta
            if _attack_pulse_timer >= 0.8:
                _attack_pulse_timer = 0.0
                _toggle_hitbox()
        else:
            velocity = dir * speed
            if not is_attacking:
                if animated_sprite.animation != "Run": animated_sprite.play("Run")
                if dir.x != 0: animated_sprite.flip_h = (dir.x < 0)
        move_and_slide()
    else:
        velocity = Vector2.ZERO
        if not is_attacking and animated_sprite.animation != "Idle": animated_sprite.play("Idle")

func _play_sequential_attack() -> void:
    is_attacking = true
    var attacks = ["Attack1", "Attack2"]
    animated_sprite.play(attacks[attack_index])
    attack_index = (attack_index + 1) % 2

func _toggle_hitbox() -> void:
    if is_instance_valid(hitbox):
        var shape = hitbox.get_node_or_null("CollisionShape2D")
        if shape:
            shape.disabled = true
            hitbox.check_hit()
            get_tree().create_timer(0.1).timeout.connect(_enable_shape.bind(shape))

func _enable_shape(shape: CollisionShape2D) -> void:
    if is_instance_valid(shape): shape.disabled = false

func _find_target() -> void:
    if is_instance_valid(target): return
    var potential = []
    if alignment == 1:
        potential.append_array(get_tree().get_nodes_in_group("enemy"))
        for u in get_tree().get_nodes_in_group("units"): if u.alignment == 2: potential.append(u)
        for c in get_tree().get_nodes_in_group("camps"): if c.alignment == 2: potential.append(c)
    else:
        potential.append(get_tree().get_first_node_in_group("player"))
        for u in get_tree().get_nodes_in_group("units"): if u.alignment == 1: potential.append(u)
        for c in get_tree().get_nodes_in_group("camps"): if c.alignment == 1: potential.append(c)
    var breakers = potential.filter(func(t): return is_instance_valid(t) and t is Enemy and t.current_archetype == Enemy.Archetype.BREAKER)
    var final_list = breakers if not breakers.is_empty() else potential
    var min_d = INF
    for t in final_list:
        if is_instance_valid(t):
            var d = global_position.distance_to(t.global_position); if d < min_d: min_d = d; target = t

func _get_nearby_enemy_breaker() -> Node2D:
    var enemies = get_tree().get_nodes_in_group("enemy")
    for e in enemies:
        if is_instance_valid(e) and e is Enemy and e.current_archetype == Enemy.Archetype.BREAKER:
            if global_position.distance_to(e.global_position) < 400.0: return e
    return null

func flip_alignment(new_align: int) -> void:
    alignment = new_align; _setup_physics_and_factions(); _update_visuals(); target = null

func _update_visuals() -> void:
    modulate = Color.CORNFLOWER_BLUE if alignment == 1 else Color.INDIAN_RED
