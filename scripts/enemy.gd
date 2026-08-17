extends CharacterBody2D
class_name Enemy

const XP_GEM_SCENE = preload("res://Assets/Scenes/Xp_gem.tscn")
# DISRUPTOR стреляет той же сценой стрелы, что и турели/лучники (PNG-стрела).
# Враг использует faction="enemy" → arrow.gd ставит collision_mask=2 (бьёт игрока/юнитов).
const ENEMY_ARROW_SCENE = preload("res://Assets/Scenes/Weapons/Arrow.tscn")
const DISRUPTOR_FRAMES := preload("res://Assets/SpriteFrames/red_archer_frames.tres")
const SWARMER_FRAMES := preload("res://Assets/SpriteFrames/red_pawn_frames.tres")
const BREAKER_FRAMES := preload("res://Assets/SpriteFrames/red_warrior_frames.tres")

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
# --- Обход препятствий: счётчик застревания и таймер «расталкивания» ---
var _stuck_frames: int = 0
var _unstick_timer: float = 0.0

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
        Archetype.SWARMER:
            speed = 160.0; xp_value = 5; scale = Vector2(0.8, 0.8)
            if animated_sprite:
                animated_sprite.sprite_frames = SWARMER_FRAMES
                animated_sprite.play("Run")
        Archetype.BREAKER:
            speed = 65.0; xp_value = 50; scale = Vector2(2.2, 2.2); modulate = Color.WHITE
            if animated_sprite:
                animated_sprite.sprite_frames = BREAKER_FRAMES
                animated_sprite.play("Run")
        Archetype.DISRUPTOR:
            speed = 130.0; xp_value = 35; scale = Vector2(1.1, 1.1); modulate = Color.WHITE
            if animated_sprite:
                animated_sprite.sprite_frames = DISRUPTOR_FRAMES
                animated_sprite.play("Run")

func _on_animation_finished() -> void:
    if animated_sprite.animation in ["Attack1", "Attack2"]:
        is_attacking = false; animated_sprite.play("Run")

func _physics_process(delta: float) -> void:
    if attack_cooldown_timer > 0: attack_cooldown_timer -= delta
    _update_target()
    if not target_node: return
    
    var dist = global_position.distance_to(target_node.global_position)
    var dir = (target_node.global_position - global_position).normalized()
    
    # --- ЛОГИКА РАЗДЕЛЕНИЯ (SEPARATION) ---
    var separation_vector = Vector2.ZERO
    var neighbors = get_tree().get_nodes_in_group("enemy")
    for enemy in neighbors:
        if enemy != self and is_instance_valid(enemy):
            var d = global_position.distance_to(enemy.global_position)
            if d < 40.0: # Радиус комфорта между врагами
                separation_vector -= (enemy.global_position - global_position).normalized() * (40.0 - d)
    
    var accel = 10.0
    if GameManager.get_meta("inertia_active"): accel = 0.8
    
    var move_dir = (dir + separation_vector * 0.5).normalized() # Смешиваем направление к цели и отталкивание
    
    if current_archetype == Archetype.DISRUPTOR:
        if dist < 280: move_dir = -dir; speed = 180.0
        elif dist > 400: move_dir = dir; speed = 130.0
        else: move_dir = Vector2.ZERO
    
    # --- ОБХОД ПРЕПЯТСТВИЙ (коррекция после move_and_slide прошлого кадра) ---
    # is_on_wall() отражает столкновение из конца прошлого кадра.
    # Если враг давит в препятствие — скользим вдоль стены (тангенциально),
    # вместо того чтобы стоять на месте и вечно давить в неё.
    var unstick_push := Vector2.ZERO
    if is_on_wall() and get_slide_collision_count() > 0 and move_dir.length() > 0.05:
        var wall_normal := get_wall_normal()
        var tangent := wall_normal.orthogonal()
        # Берём из двух направлений вдоль стены то, что ближе к текущему движению
        if tangent.dot(move_dir) < 0.0:
            tangent = -tangent
        var slid: Vector2 = move_dir.slide(wall_normal)
        if slid.length() < 0.15:
            # Почти перпендикулярно стене (или в углу) — фиксированная сторона обхода
            move_dir = tangent
        else:
            move_dir = slid.normalized()
        
        # Лёгкое «расталкивание»: если скорость прижата к нулю у стены несколько
        # кадров подряд — короткий боковой импульс вдоль стены, чтобы выйти из
        # мёртвой зоны (огибание углов) и продолжить преследование цели.
        if dist > 25.0 and velocity.length() < 30.0:
            _stuck_frames += 1
        else:
            _stuck_frames = 0
        if _stuck_frames >= 15:
            _unstick_timer = 0.6
            _stuck_frames = 0
        if _unstick_timer > 0.0:
            _unstick_timer -= delta
            unstick_push = tangent * 700.0
            if velocity.length() > 50.0:
                _unstick_timer = 0.0
    else:
        _stuck_frames = 0
        _unstick_timer = 0.0
    
    var final_speed = speed * GameManager.get_meta("enemy_stat_mult")
    
    # Плавная остановка у цели
    if dist < 25.0 and not GameManager.get_meta("inertia_active"):
        velocity = velocity.lerp(Vector2.ZERO, delta * 15.0)
    else:
        velocity = velocity.lerp(move_dir * final_speed, delta * accel)
    
    _apply_gravity_logic(delta)
    
    # BREAKER крупный (scale 2.2): физический радиус ~66px + шахта/здание ~25px →
    # он упирается на ~91px от центра цели. Range должен покрывать этот упор.
    var attack_range = 450.0 if current_archetype == Archetype.DISRUPTOR else (130.0 if current_archetype == Archetype.BREAKER else 65.0)
    if dist < attack_range and attack_cooldown_timer <= 0 and not is_attacking:
        _execute_attack()
    
    if not is_attacking and dist > 40.0:
        if abs(dir.x) > 0.1: animated_sprite.flip_h = (dir.x < 0)
        animated_sprite.play("Run" if velocity.length() > 20 else "Idle")
    
    if unstick_push != Vector2.ZERO:
        velocity += unstick_push * delta
    
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
        target_node = _find_closest_target(["player"]); return
    if GameManager.current_anomaly == "SEIZE":
        var seize_camps = get_tree().get_nodes_in_group("camps").filter(func(c): return is_instance_valid(c) and c.has_meta("is_seize_target") and c.get_meta("is_seize_target") == true)
        var seize_mines = get_tree().get_nodes_in_group("mines").filter(func(m): return is_instance_valid(m) and m.has_meta("is_seize_target") and m.get_meta("is_seize_target") == true)
        var seize_targets = seize_camps + seize_mines
        if not seize_targets.is_empty():
            var closest = seize_targets[0]; var min_d = global_position.distance_to(closest.global_position)
            for c in seize_targets:
                var d = global_position.distance_to(c.global_position); if d < min_d: min_d = d; closest = c
            target_node = closest; return
    if current_archetype == Archetype.BREAKER:
        var player_camps = get_tree().get_nodes_in_group("camps").filter(func(c): return is_instance_valid(c) and c.alignment == 1)
        var player_mines = get_tree().get_nodes_in_group("player_mines").filter(func(m): return is_instance_valid(m))
        var player_territories = player_camps + player_mines
        if not player_territories.is_empty():
            var closest = player_territories[0]; var min_d = global_position.distance_to(closest.global_position)
            for t in player_territories:
                var d = global_position.distance_to(t.global_position); if d < min_d: min_d = d; closest = t
            target_node = closest; return
    target_node = _find_closest_target(["player", "ally_units"])

func _find_closest_target(groups: Array) -> Node2D:
    var candidates: Array[Node2D] = []
    for group_name in groups:
        for node in get_tree().get_nodes_in_group(group_name):
            if is_instance_valid(node) and node is Node2D:
                # Исключение только для защитников зданий (FortArcher):
                # враги не наводятся на них, а продолжают атаковать шахту/здание.
                # Обычные юниты (banner-арчер и др.) флага не имеют — остаются целями.
                if "is_fort_defender" in node and node.is_fort_defender:
                    continue
                candidates.append(node)
    if candidates.is_empty():
        return null
    var closest: Node2D = candidates[0]
    var min_d: float = global_position.distance_to(closest.global_position)
    for node in candidates:
        var d: float = global_position.distance_to(node.global_position)
        if d < min_d:
            min_d = d
            closest = node
    return closest

func _execute_attack() -> void:
    is_attacking = true; attack_cooldown_timer = attack_delay
    if current_archetype == Archetype.DISRUPTOR: _shoot()
    else: _play_sequential_melee()

func _shoot() -> void:
    if not ENEMY_ARROW_SCENE: return
    var arrow = ENEMY_ARROW_SCENE.instantiate() as Arrow
    if not arrow:
        return
    arrow.global_position = global_position
    # Стрела движется по rotation (Vector2.RIGHT.rotated(rotation)).
    arrow.rotation = (target_node.global_position - global_position).angle()
    arrow.faction = "enemy"
    arrow.damage = 5.0
    arrow.pierce_limit = 1
    get_tree().current_scene.add_child(arrow)
    animated_sprite.play("Attack1")

func _play_sequential_melee() -> void:
    _toggle_hitbox() 
    var attacks = ["Attack1", "Attack2"]
    var attack_name: String = attacks[attack_index]
    if not animated_sprite.sprite_frames.has_animation(attack_name):
        attack_name = "Attack1"
    animated_sprite.play(attack_name)
    attack_index = (attack_index + 1) % 2

func _toggle_hitbox() -> void:
    if is_instance_valid(hitbox):
        var original_dmg = hitbox.damage
        if current_archetype == Archetype.BREAKER and (target_node is Camp or target_node is Mine): hitbox.damage *= 5.0
        var shape = hitbox.get_node_or_null("CollisionShape2D")
        if shape:
            shape.disabled = false
            hitbox.check_hit()
            get_tree().create_timer(0.4).timeout.connect(_disable_shape.bind(shape, original_dmg))

func _disable_shape(shape: CollisionShape2D, dmg: float) -> void:
    if is_instance_valid(shape): shape.disabled = true
    if is_instance_valid(hitbox): hitbox.damage = dmg

func _on_hit_received(_damage: float) -> void:
    var t = create_tween(); modulate = Color.RED
    t.tween_property(self, "modulate", Color.WHITE, 0.1)

func _on_death() -> void:
    if GameManager.has_method("log_event"): GameManager.log_event("enemy_killed", 1)
    var gem: XPGem = XP_GEM_SCENE.instantiate() as XPGem
    var rect = GameManager.get_meta("map_rect") if GameManager.has_meta("map_rect") else Rect2(-2000,-2000,4000,4000)
    var pos = global_position
    pos.x = clamp(pos.x, rect.position.x + 50, rect.end.x - 50)
    pos.y = clamp(pos.y, rect.position.y + 50, rect.end.y - 50)
    gem.global_position = pos; gem.xp_amount = int(xp_value * GameManager.get_meta("xp_mult"))
    get_tree().current_scene.call_deferred("add_child", gem); queue_free()
