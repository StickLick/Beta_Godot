extends CharacterBody2D
class_name Enemy

const XP_GEM_SCENE: PackedScene = preload("res://Assets/Scenes/Xp_gem.tscn")
@export var speed: float = 120.0
@export var xp_value: int = 10
@export var health_component: HealthComponent

@onready var hurtbox: HurtboxComponent = $HurtboxComponent

func _ready() -> void:
    add_to_group("enemy")
    if health_component == null: health_component = $HealthComponent
    if health_component: health_component.health_depleted.connect(_on_death)
    if hurtbox:
        hurtbox.hit_received.connect(func(_d): 
            var t = create_tween(); modulate = Color.RED
            t.tween_property(self, "modulate", Color.WHITE, 0.1))
        hurtbox.faction = "enemy"

func _physics_process(_delta: float) -> void:
    var player = get_tree().get_first_node_in_group("player")
    if player:
        var dir = (player.global_position - global_position).normalized()
        velocity = dir * speed
        move_and_slide()

func _on_death() -> void:
    var gem: XPGem = XP_GEM_SCENE.instantiate() as XPGem
    var rect = GameManager.get_meta("map_rect") if GameManager.has_meta("map_rect") else Rect2(-2000,-2000,4000,4000)
    var pos = global_position
    # Ограничение разлета гема
    pos.x = clamp(pos.x, rect.position.x + 50, rect.end.x - 50)
    pos.y = clamp(pos.y, rect.position.y + 50, rect.end.y - 50)
    gem.global_position = pos
    gem.xp_amount = xp_value
    get_tree().current_scene.call_deferred("add_child", gem)
    call_deferred("queue_free")
