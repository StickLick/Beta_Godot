extends "res://scripts/unit.gd"
class_name PawnUnit

var banner_owner: Node2D = null

func _ready() -> void:
	super._ready()
	_attach_squad_ai()

func _on_death() -> void:
	if is_instance_valid(banner_owner) and banner_owner.has_method("_on_banner_unit_died"):
		banner_owner._on_banner_unit_died(self)
	super._on_death()

func _play_sequential_attack() -> void:
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