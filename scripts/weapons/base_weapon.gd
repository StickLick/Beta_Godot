class_name BaseWeapon
extends Node2D

# signal weapon_maxed(name: String)  # reserved for future use

@export_group("Identity")
@export var weapon_name: String = "Spear"
@export var is_evolution_version: bool = false 
var weapon_tag: String = ""

@export_group("Base Stats (Ingredients)")
@export var base_dmg: float = 15.0
@export var base_range: float = 250.0
@export var base_pierce: int = 1
@export var attack_cooldown: float = 1.0:
    set(value):
        attack_cooldown = max(0.05, value)
        if is_instance_valid(cooldown_timer):
            cooldown_timer.wait_time = attack_cooldown

# Runtime bonuses (modified by upgrades/passives)
var weapon_dmg_bonus: float = 0.0
var weapon_range_bonus: float = 0.0
var weapon_pierce_bonus: int = 0

# Computed Final Stats (Single Source of Truth)
var final_damage: float:
    get:
        var mult = player.damage_multiplier if is_instance_valid(player) else 1.0
        return (base_dmg + weapon_dmg_bonus) * mult

var final_range: float:
    get:
        var mult = player.radius_weapons if is_instance_valid(player) else 1.0
        return (base_range + weapon_range_bonus) * mult

var final_pierce: int:
    get: return int(base_pierce + weapon_pierce_bonus)

# Backward compatibility aliases (read-only — SSOT protection)
var base_damage: float:
    get: return base_dmg
var max_attack_distance: float:
    get: return final_range

@export_group("Glitch Juice")
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
    
    if weapon_tag == "":
        weapon_tag = weapon_name
    
    _setup_physics_auto()
    on_modifier_applied()
    _weapon_ready()
    
    if "Wave" in name:
        _run_wave_logic()


func _weapon_ready() -> void:
    pass


func _weapon_process(_delta: float) -> void:
    pass


func _on_effective_range_changed() -> void:
    pass


func _process(delta: float) -> void:
    _weapon_process(delta)


func on_modifier_applied() -> void:
    _setup_physics_auto()
    print("[SYNC] ", weapon_tag, " | Dist: ", final_range, " | Dmg: ", final_damage, " | Pierce: ", final_pierce)


func _setup_physics_auto() -> void:
    var eff_range = final_range
    if is_instance_valid(detection_area):
        var shape_node = detection_area.get_node_or_null("CollisionShape2D")
        if shape_node and shape_node.shape is CircleShape2D:
            shape_node.shape.radius = eff_range + 30.0
    if is_instance_valid(hitbox):
        var shape_node = hitbox.get_node_or_null("CollisionShape2D")
        if shape_node:
            if shape_node.shape is RectangleShape2D:
                shape_node.shape.size = Vector2(eff_range + 15.0, 50.0)
                shape_node.position.x = (eff_range - 15.0) / 2.0
            elif shape_node.shape is CircleShape2D:
                shape_node.shape.radius = eff_range
    _on_effective_range_changed()


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
