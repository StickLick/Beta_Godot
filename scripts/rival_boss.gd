extends CharacterBody2D
class_name RivalBoss

@export var speed: float = 140.0
@export var pulse_interval: float = 4.0
@export var boss_color: Color = Color(4.0, 0.2, 1.5) 

var damage_reduction: float = 0.0 
var _pulse_timer: float = 0.0
var is_dead: bool = false

@onready var line: Line2D = $Line2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent

var debug_label: Label

func _ready() -> void:
    add_to_group("enemy")
    modulate = boss_color
    scale = Vector2(4.0, 4.0)
    
    if line == null:
        line = Line2D.new()
        add_child(line)
    line.width = 15.0
    line.default_color = boss_color
    line.top_level = true 
    line.clear_points()

    # Подключение урона
    if is_instance_valid(hurtbox):
        hurtbox.faction = "enemy" 
        if not hurtbox.hit_received.is_connected(_on_hit_received):
            hurtbox.hit_received.connect(_on_hit_received)

    # Подключение смерти
    if is_instance_valid(health_component):
        if not health_component.health_depleted.is_connected(_on_death):
            health_component.health_depleted.connect(_on_death)

    _setup_debug_ui()

func _setup_debug_ui() -> void:
    debug_label = Label.new()
    add_child(debug_label)
    debug_label.position = Vector2(-40, -55)
    debug_label.scale = Vector2(0.4, 0.4)
    debug_label.add_theme_color_override("font_shadow_color", Color.BLACK)

func _physics_process(delta: float) -> void:
    if is_dead: return
    
    _update_defense_state()
    _move_logic(delta)
    _update_ui()
    
    _pulse_timer += delta
    if _pulse_timer >= pulse_interval:
        _pulse_timer = 0.0
        _execute_pulse()

func _update_ui() -> void:
    if is_instance_valid(debug_label) and is_instance_valid(health_component):
        var hp_text = "BOSS HP: %d" % int(health_component.current_health)
        var shield_pct = int(damage_reduction * 100)
        var sh_text = "SHIELD: %d%%" % shield_pct if shield_pct > 0 else "SHIELD: BROKEN"
        
        debug_label.text = hp_text + "\n" + sh_text
        debug_label.modulate = Color.CYAN if damage_reduction > 0 else Color.RED

func _update_defense_state() -> void:
    # Считаем количество живых лагерей соперника
    var rival_camps = get_tree().get_nodes_in_group("camps").filter(
        func(c): return is_instance_valid(c) and c.alignment == 2
    )
    
    var count = rival_camps.size()
    
    # Динамическая прогрессия щита
    if count == 0:
        damage_reduction = 0.0
        modulate = Color.WHITE
    elif count == 1:
        damage_reduction = 0.90 # 90%
        modulate = boss_color
    elif count == 2:
        damage_reduction = 0.95 # 95%
        modulate = boss_color * 1.2
    else:
        damage_reduction = 0.98 # 98% (почти неуязвим)
        modulate = boss_color * 1.5

func _move_logic(delta: float) -> void:
    var player = get_tree().get_first_node_in_group("player")
    if not player: return
    var dir = (player.global_position - global_position).normalized()
    velocity = velocity.move_toward(dir * speed, 600 * delta)
    move_and_slide()

func _execute_pulse() -> void:
    var rival_camps = get_tree().get_nodes_in_group("camps").filter(
        func(c): return is_instance_valid(c) and c.alignment == 2
    )
    if rival_camps.is_empty(): return
    var target = rival_camps.pick_random()
    _visualize_beam(target.global_position)
    if target.has_method("reinforce"):
        target.reinforce()

func _visualize_beam(target_pos: Vector2) -> void:
    line.clear_points()
    line.add_point(global_position)
    line.add_point(target_pos)
    var tween = create_tween()
    line.modulate.a = 1.0
    tween.tween_property(line, "width", 30.0, 0.1)
    tween.parallel().tween_property(line, "modulate:a", 0.0, 0.4).set_delay(0.1)
    tween.finished.connect(line.clear_points)

func _on_hit_received(base_damage: float) -> void:
    if damage_reduction > 0:
        var absorbed = base_damage * damage_reduction
        # Возвращаем поглощенный урон в HealthComponent
        health_component.current_health += absorbed
        # print("[BOSS] Shield active. Blocked: ", int(absorbed))

func _on_death() -> void:
    if is_dead: return
    is_dead = true
    print("--- VICTORY! RIVAL BOSS DESTROYED ---")
    
    # Эффект смерти
    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(self, "scale", Vector2.ZERO, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
    tween.tween_property(self, "modulate:a", 0.0, 0.8)
    tween.finished.connect(queue_free)
