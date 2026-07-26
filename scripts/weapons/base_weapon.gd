class_name BaseWeapon
extends Node2D

signal weapon_maxed(name: String)

@export_group("Identity")
@export var weapon_name: String = "Spear"
@export var is_evolution_version: bool = false 
var weapon_tag: String = ""  # устанавливается из Upgrade ресурса при спавне/эволюции (runtime)

@export_group("Stats")
@export var base_damage: float = 15.0
@export var attack_cooldown: float = 1.0:
    set(value):
        attack_cooldown = max(0.05, value)
        if is_instance_valid(cooldown_timer):
            cooldown_timer.wait_time = attack_cooldown

@export_group("Glitch Juice")
@export var max_attack_distance: float = 250.0 
@export var strike_duration: float = 0.05
@export var fade_duration: float = 0.25
@export var spear_visual_length: float = 120.0 

@onready var visual_pivot: Node2D = $VisualPivot
@onready var spear_visual: CanvasItem = _find_visual()

@onready var cooldown_timer: Timer = $CooldownTimer
@onready var detection_area: Area2D = $DetectionArea
@onready var hitbox: HitboxComponent = find_child("HitboxComponent", true)

var player: Player


func _ready() -> void:
    if "Wave" in name:
        _run_wave_logic()
    
    player = get_parent() as Player
    if not is_instance_valid(player):
        player = get_tree().get_first_node_in_group("player")
    
    # Устанавливаем weapon_tag для предустановленного в сцене оружия (Spear)
    if weapon_tag == "":
        weapon_tag = weapon_name
    
    _setup_physics_auto()
    _weapon_ready()
    
    if "Wave" in name:
        _run_wave_logic()
    
    print("[WEAPON INIT] ", weapon_name, " (tag=", weapon_tag, ")")
    print("   max_attack_distance=", max_attack_distance)
    print("   base_damage=", base_damage)
    print("   attack_cooldown=", attack_cooldown)
    if is_instance_valid(detection_area):
        var shape = detection_area.get_node_or_null("CollisionShape2D")
        if shape and shape.shape:
            print("   detection_radius=", shape.shape.radius)
    if is_instance_valid(hitbox):
        var shape = hitbox.get_node_or_null("CollisionShape2D")
        if shape and shape.shape:
            if shape.shape is CircleShape2D:
                print("   hitbox_radius=", shape.shape.radius)
            elif shape.shape is RectangleShape2D:
                print("   hitbox_size=", shape.shape.size)


# ── Виртуальные методы для переопределения в наследниках ──

func _weapon_ready() -> void:
    """Override in subclass for weapon-specific initialization."""
    pass


func _weapon_process(delta: float) -> void:
    """Override in subclass for per-frame logic (Aura animation, etc.)."""
    pass


# ── Общие методы ──

func _process(delta: float) -> void:
    _weapon_process(delta)


func on_modifier_applied() -> void:
    _setup_physics_auto()
    print("[WEAPON] ", weapon_name, " (tag=", weapon_tag, ") after modifier:")
    print("   max_attack_distance=", max_attack_distance)
    print("   base_damage=", base_damage)
    print("   attack_cooldown=", attack_cooldown)
    if is_instance_valid(detection_area):
        var shape = detection_area.get_node_or_null("CollisionShape2D")
        if shape and shape.shape:
            print("   detection_radius=", shape.shape.radius)
    if is_instance_valid(hitbox):
        var shape = hitbox.get_node_or_null("CollisionShape2D")
        if shape and shape.shape:
            if shape.shape is CircleShape2D:
                print("   hitbox_radius=", shape.shape.radius)
            elif shape.shape is RectangleShape2D:
                print("   hitbox_size=", shape.shape.size)


func _setup_physics_auto() -> void:
    if is_instance_valid(detection_area):
        var shape_node = detection_area.get_node_or_null("CollisionShape2D")
        if shape_node and shape_node.shape is CircleShape2D:
            shape_node.shape.radius = max_attack_distance + 30.0
    if is_instance_valid(hitbox):
        var shape_node = hitbox.get_node_or_null("CollisionShape2D")
        if shape_node:
            if shape_node.shape is RectangleShape2D:
                shape_node.shape.size = Vector2(max_attack_distance + 15.0, 50.0)
                shape_node.position.x = (max_attack_distance - 15.0) / 2.0
            elif shape_node.shape is CircleShape2D:
                shape_node.shape.radius = max_attack_distance


func _set_hitbox_active(active: bool) -> void:
    if is_instance_valid(hitbox):
        var shape = hitbox.get_node_or_null("CollisionShape2D")
        if shape:
            shape.set_deferred("disabled", !active)


func _find_visual() -> CanvasItem:
    var polygon = get_node_or_null("VisualPivot/Polygon2D")
    if polygon:
        return polygon

    var sprite = get_node_or_null("VisualPivot/Sprite2D")
    if sprite:
        return sprite

    return null


func _run_wave_logic() -> void:
    while true:
        scale = Vector2.ZERO
        modulate.a = 1.0
        var tw = create_tween().set_parallel(true)
        tw.tween_property(self, "scale", Vector2.ONE * 8.0, 1.2)
        tw.tween_property(self, "modulate:a", 0.0, 1.2)
        await tw.finished
        await get_tree().create_timer(0.4).timeout
