#class_name WeaponComponent
#extends Node2D
#
#const SWING_SCALE_UP_DURATION: float = 0.1
#
#@export var base_damage: float = 15.0
#
## Добавлен сеттер для корректного обновления таймера при улучшении
#@export var attack_cooldown: float = 1.0:
    #set(value):
        #var old_val = attack_cooldown
        ## Не даем кулдауну стать слишком маленьким или нулевым
        #attack_cooldown = max(0.05, value)
        #if is_instance_valid(cooldown_timer):
            #cooldown_timer.wait_time = attack_cooldown
        #print("[DEBUG] Attack Cooldown Upgrade: %.2f -> %.2f" % [old_val, attack_cooldown])
#
#@export var rotation_offset_degrees: float = 0.0
#
#@onready var detection_area: Area2D = $DetectionArea
#@onready var cooldown_timer: Timer = $CooldownTimer
#@onready var visual_pivot: Node2D = $VisualPivot
#@onready var hitbox: HitboxComponent = $VisualPivot/HitboxComponent
#
#var player: Node2D
#
#func _ready() -> void:
    #await get_tree().process_frame
    #player = get_tree().get_first_node_in_group("player")
#
    ## Инициализация таймера текущим значением
    #cooldown_timer.wait_time = attack_cooldown
    #cooldown_timer.timeout.connect(_on_cooldown_timeout)
#
    #hitbox.faction = "player"
#
    #var hitbox_shape: CollisionShape2D = hitbox.get_node("CollisionShape2D") as CollisionShape2D
    #hitbox_shape.disabled = true
    #visual_pivot.scale = Vector2.ZERO
#
    #detection_area.monitoring = true
    #detection_area.collision_mask = 4
#
    #if player and "radius_weapons" in player:
        #update_weapon_range(player.radius_weapons)
#
    #cooldown_timer.start()
#
#func update_weapon_range(new_multiplier: float) -> void:
    #if not is_instance_valid(detection_area) or not is_instance_valid(hitbox):
        #return
        #
    #var detection_shape = detection_area.get_node_or_null("CollisionShape2D")
    #if detection_shape:
        #detection_shape.scale = Vector2.ONE * new_multiplier
    #
    #var hitbox_shape = hitbox.get_node_or_null("CollisionShape2D")
    #if hitbox_shape:
        #hitbox_shape.scale = Vector2.ONE * new_multiplier
#
#func _get_closest_target() -> HurtboxComponent:
    #var closest_target: HurtboxComponent = null
    #var closest_distance_sq: float = INF
#
    #for area: Area2D in detection_area.get_overlapping_areas():
        #var hurtbox: HurtboxComponent = area as HurtboxComponent
        #if hurtbox == null or hurtbox.faction != "enemy":
            #continue
#
        #var distance_sq: float = global_position.distance_squared_to(hurtbox.global_position)
        #if distance_sq < closest_distance_sq:
            #closest_distance_sq = distance_sq
            #closest_target = hurtbox
#
    #return closest_target
#
#func _on_cooldown_timeout() -> void:
    #var target: HurtboxComponent = _get_closest_target()
    #if target == null:
        #cooldown_timer.start()
        #return
#
    #visual_pivot.look_at(target.global_position)
    #visual_pivot.rotation += deg_to_rad(rotation_offset_degrees)
    #_perform_swing()
#
#func _perform_swing() -> void:
    #if not is_instance_valid(player):
        #player = get_tree().get_first_node_in_group("player")
    #
    #var multiplier: float = 1.0
    #if player and "damage_multiplier" in player:
        #multiplier = player.damage_multiplier
    #
    #hitbox.damage = base_damage * multiplier
#
    #var hitbox_shape: CollisionShape2D = hitbox.get_node("CollisionShape2D") as CollisionShape2D
    #hitbox_shape.disabled = false
    #visual_pivot.scale = Vector2.ZERO
#
    #var tween: Tween = create_tween().set_parallel(true)
    #tween.tween_property(visual_pivot, "scale", Vector2(1.8, 1.8), SWING_SCALE_UP_DURATION)
    #tween.chain().tween_property(visual_pivot, "scale", Vector2.ZERO, SWING_SCALE_UP_DURATION)
    #tween.chain().tween_callback(_on_swing_finished)
#
#func _on_swing_finished() -> void:
    #if is_instance_valid(hitbox):
        #var hitbox_shape: CollisionShape2D = hitbox.get_node("CollisionShape2D") as CollisionShape2D
        #hitbox_shape.disabled = true
    #cooldown_timer.start()


class_name WeaponComponent
extends Node2D

const SWING_SCALE_UP_DURATION: float = 0.1

@export var base_damage: float = 15.0

@export var attack_cooldown: float = 1.0:
    set(value):
        var old_val = attack_cooldown
        attack_cooldown = max(0.05, value)
        if is_instance_valid(cooldown_timer):
            cooldown_timer.wait_time = attack_cooldown
        print("[DEBUG] Attack Cooldown Upgrade: %.2f -> %.2f" % [old_val, attack_cooldown])

@export var rotation_offset_degrees: float = 0.0

@onready var detection_area: Area2D = $DetectionArea
@onready var cooldown_timer: Timer = $CooldownTimer
@onready var visual_pivot: Node2D = $VisualPivot
@onready var hitbox: HitboxComponent = $VisualPivot/HitboxComponent

var player: Node2D

func _ready() -> void:
    await get_tree().process_frame
    player = get_tree().get_first_node_in_group("player")

    cooldown_timer.wait_time = attack_cooldown
    cooldown_timer.timeout.connect(_on_cooldown_timeout)

    hitbox.faction = "player"

    var hitbox_shape: CollisionShape2D = hitbox.get_node("CollisionShape2D") as CollisionShape2D
    hitbox_shape.disabled = true
    visual_pivot.scale = Vector2.ZERO

    detection_area.monitoring = true
    detection_area.collision_mask = 4 # Это Слой 3

    if player and "radius_weapons" in player:
        update_weapon_range(player.radius_weapons)

    cooldown_timer.start()

func update_weapon_range(new_multiplier: float) -> void:
    if not is_instance_valid(detection_area) or not is_instance_valid(hitbox):
        return
    var detection_shape = detection_area.get_node_or_null("CollisionShape2D")
    if detection_shape:
        detection_shape.scale = Vector2.ONE * new_multiplier
    var hitbox_shape = hitbox.get_node_or_null("CollisionShape2D")
    if hitbox_shape:
        hitbox_shape.scale = Vector2.ONE * new_multiplier

func _get_closest_target() -> HurtboxComponent:
    var closest_target: HurtboxComponent = null
    var closest_distance_sq: float = INF

    for area: Area2D in detection_area.get_overlapping_areas():
        var hurtbox: HurtboxComponent = area as HurtboxComponent
        
        # ВОТ ЗДЕСЬ БЫЛА ПРОБЛЕМА:
        # Раньше было только != "enemy". Теперь мы разрешаем бить и "enemy", и "rival".
        if hurtbox == null or (hurtbox.faction != "enemy" and hurtbox.faction != "rival"):
            continue

        var distance_sq: float = global_position.distance_squared_to(hurtbox.global_position)
        if distance_sq < closest_distance_sq:
            closest_distance_sq = distance_sq
            closest_target = hurtbox

    return closest_target

func _on_cooldown_timeout() -> void:
    var target: HurtboxComponent = _get_closest_target()
    if target == null:
        cooldown_timer.start()
        return

    visual_pivot.look_at(target.global_position)
    visual_pivot.rotation += deg_to_rad(rotation_offset_degrees)
    _perform_swing()

func _perform_swing() -> void:
    if not is_instance_valid(player):
        player = get_tree().get_first_node_in_group("player")
    
    var multiplier: float = 1.0
    if player and "damage_multiplier" in player:
        multiplier = player.damage_multiplier
    
    hitbox.damage = base_damage * multiplier

    var hitbox_shape: CollisionShape2D = hitbox.get_node("CollisionShape2D") as CollisionShape2D
    hitbox_shape.disabled = false
    visual_pivot.scale = Vector2.ZERO

    var tween: Tween = create_tween().set_parallel(true)
    tween.tween_property(visual_pivot, "scale", Vector2(1.8, 1.8), SWING_SCALE_UP_DURATION)
    tween.chain().tween_property(visual_pivot, "scale", Vector2.ZERO, SWING_SCALE_UP_DURATION)
    tween.chain().tween_callback(_on_swing_finished)

func _on_swing_finished() -> void:
    if is_instance_valid(hitbox):
        var hitbox_shape: CollisionShape2D = hitbox.get_node("CollisionShape2D") as CollisionShape2D
        hitbox_shape.disabled = true
    cooldown_timer.start()
