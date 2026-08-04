extends "res://scripts/unit.gd"
class_name PawnUnit

var banner_owner: Node2D = null

func _ready() -> void:
    super._ready()
    _attach_squad_ai()
    var spawn_vfx = get_node_or_null("SpawnBurst")
    if spawn_vfx:
        spawn_vfx.restart()
    get_tree().create_timer(1.0).timeout.connect(_force_damage_test)

func _force_damage_test() -> void:
    if is_instance_valid(health_component):
        health_component.take_damage(1.0)

func _on_damage_received(amount: float) -> void:
    super._on_damage_received(amount)
    var bar = get_node_or_null("HealthBar")
    if bar and is_instance_valid(health_component):
        bar.visible = health_component.current_health < health_component.max_health
        bar.max_value = health_component.max_health
        bar.value = health_component.current_health
    print("[DEBUG] Pawn hit! HP: ", health_component.current_health if is_instance_valid(health_component) else "N/A", " | Damage: ", amount)

func _on_death() -> void:
    if is_instance_valid(banner_owner) and banner_owner.has_method("_on_banner_unit_died"):
        banner_owner._on_banner_unit_died(self)
    super._on_death()

func _on_animation_finished() -> void:
    if animated_sprite.animation in ["Attack", "Attack1"]:
        is_attacking = false
        if animated_sprite.sprite_frames.has_animation("Run"):
            animated_sprite.play("Run")

func _play_sequential_attack(_target: Node2D = null, _banner: WarBanner = null) -> void:
    is_attacking = true
    if animated_sprite.sprite_frames.has_animation("Attack"):
        animated_sprite.play("Attack")
    elif animated_sprite.sprite_frames.has_animation("Attack1"):
        animated_sprite.play("Attack1")

func _attach_squad_ai() -> void:
    var ai_script = load("res://scripts/components/squad_behavior_component.gd")
    if ai_script:
        var ai_node: Node2D = Node2D.new()
        ai_node.set_script(ai_script)
        ai_node.name = "SquadAI"
        add_child(ai_node)
