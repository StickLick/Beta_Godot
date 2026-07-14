extends CharacterBody2D
class_name Unit

@export var alignment: int = 1 # 1=Player, 2=Rival
var target: Node2D = null
var parent_camp: Node2D = null

@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent

func _ready() -> void:
    add_to_group("units")
    _update_visuals()
    var hp = get_node_or_null("HealthComponent")
    if hp: hp.health_depleted.connect(queue_free)

func _physics_process(delta: float) -> void:
    _find_target()
    if is_instance_valid(target):
        var dist = global_position.distance_to(target.global_position)
        if dist > 60:
            var dir = (target.global_position - global_position).normalized()
            velocity = dir * 160.0
            rotation = lerp_angle(rotation, dir.angle(), 10 * delta)
            move_and_slide()
        else:
            velocity = Vector2.ZERO

func _find_target() -> void:
    if is_instance_valid(target): return
    var pot = []
    for c in get_tree().get_nodes_in_group("camps"): 
        if c.alignment != alignment: pot.append(c)
    for e in get_tree().get_nodes_in_group("enemy"): 
        if alignment == 1: pot.append(e)
    if alignment == 2:
        var p = get_tree().get_first_node_in_group("player")
        if p: pot.append(p)
    
    var min_d = INF
    for p in pot:
        if is_instance_valid(p):
            var d = global_position.distance_to(p.global_position)
            if d < min_d: min_d = d; target = p

func flip_alignment(new_align: int) -> void:
    alignment = new_align; _update_visuals(); target = null

func _update_visuals() -> void:
    modulate = Color.CORNFLOWER_BLUE if alignment == 1 else Color.INDIAN_RED
    var f_name = "player" if alignment == 1 else "rival"
    if hitbox: hitbox.faction = f_name
    if hurtbox: hurtbox.faction = f_name
