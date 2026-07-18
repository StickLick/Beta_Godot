extends CharacterBody2D
class_name RivalBoss

@export_group("Movement")
@export var base_speed: float = 140.0
@export var dash_speed_mult: float = 2.5

@export_group("Combat")
@export var pulse_interval: float = 4.0
@export var boss_color: Color = Color(4.0, 0.2, 1.5) 

var damage_reduction: float = 0.9
var _pulse_timer: float = 0.0
var _dash_timer: float = 0.0
var is_dead: bool = false
var is_dashing: bool = false
var desperation_phase: bool = false
var current_speed: float = 140.0

@onready var line: Line2D = $Line2D
@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent

var debug_label: Label

func _ready() -> void:
    add_to_group("enemy")
    add_to_group("rival_boss")
    modulate = boss_color
    scale = Vector2(4.5, 4.5)
    current_speed = base_speed
    
    if line == null:
        line = Line2D.new()
        add_child(line)
    line.width = 15.0
    line.default_color = boss_color
    line.top_level = true 
    line.clear_points()

    _setup_debug_ui()

    if is_instance_valid(hurtbox):
        hurtbox.faction = "enemy"
        if not hurtbox.hit_received.is_connected(_on_hit_received):
            hurtbox.hit_received.connect(_on_hit_received)
    
    if is_instance_valid(health_component):
        if not health_component.health_depleted.is_connected(_on_death):
            health_component.health_depleted.connect(_on_death)

func _setup_debug_ui() -> void:
    debug_label = Label.new(); add_child(debug_label)
    debug_label.position = Vector2(-40, -60); debug_label.scale = Vector2(0.4, 0.4)

func _physics_process(delta: float) -> void:
    if is_dead: return
    _update_defense_state()
    _move_logic(delta)
    _update_ui()
    _pulse_timer += delta
    if _pulse_timer >= pulse_interval:
        _pulse_timer = 0.0; _execute_pulse()

func _update_ui() -> void:
    if is_instance_valid(debug_label) and is_instance_valid(health_component):
        debug_label.text = "BOSS HP: %d\nSHIELD: %d%%" % [int(health_component.current_health), int(damage_reduction * 100)]
        debug_label.modulate = Color.CYAN if damage_reduction > 0 else Color.ORANGE_RED

func _update_defense_state() -> void:
    var rival_camps = get_tree().get_nodes_in_group("camps").filter(func(c): return is_instance_valid(c) and c.alignment == 2)
    if rival_camps.size() > 0:
        damage_reduction = 0.9; modulate = boss_color
    else:
        damage_reduction = 0.0
        if not desperation_phase:
            desperation_phase = true; current_speed = base_speed * 1.5; modulate = Color(5.0, 1.2, 0.0)
        _dash_timer += get_process_delta_time()
        if _dash_timer >= 4.0:
            _perform_dash(); _dash_timer = 0.0

func _perform_dash() -> void:
    is_dashing = true
    create_tween().tween_callback(func(): is_dashing = false).set_delay(1.0)

func _move_logic(delta: float) -> void:
    var player = get_tree().get_first_node_in_group("player")
    if not player: return
    var move_speed = current_speed
    if is_dashing: move_speed *= dash_speed_mult
    var dir = (player.global_position - global_position).normalized()
    velocity = velocity.move_toward(dir * move_speed, 800 * delta)
    move_and_slide()

func _execute_pulse() -> void:
    var rival_camps = get_tree().get_nodes_in_group("camps").filter(func(c): return is_instance_valid(c) and c.alignment == 2)
    if rival_camps.is_empty(): return
    var target = rival_camps.pick_random()
    _visualize_beam(target.global_position)
    if target.has_method("reinforce"): target.reinforce()

func _visualize_beam(target_pos: Vector2) -> void:
    if line == null: return
    line.clear_points(); line.add_point(global_position); line.add_point(target_pos)
    var tween = create_tween()
    line.modulate.a = 1.0; line.width = 25.0
    tween.tween_property(line, "width", 0.0, 0.5)
    tween.parallel().tween_property(line, "modulate:a", 0.0, 0.5)

func _on_hit_received(base_damage: float) -> void:
    if damage_reduction > 0: health_component.current_health += (base_damage * damage_reduction)

func _on_death() -> void:
    if is_dead: return
    is_dead = true; GameManager.stop_game()
    var cam = get_viewport().get_camera_2d()
    if cam and cam.has_method("death_zoom"): cam.death_zoom(global_position)
    var death_tween = create_tween()
    for i in range(8):
        death_tween.tween_property(self, "modulate", Color(10, 10, 10), 0.05)
        death_tween.tween_property(self, "modulate", Color.ORANGE_RED, 0.05)
    death_tween.tween_property(self, "scale", Vector2.ZERO, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
    death_tween.chain().tween_callback(func():
        var hud = get_tree().get_first_node_in_group("hud")
        if hud and hud.has_method("show_results"): hud.show_results()
        queue_free()
    )
