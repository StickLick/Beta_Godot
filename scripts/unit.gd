extends CharacterBody2D
class_name Unit

@export_group("Unit Settings")
@export var speed: float = 240.0
@export var alignment: int = 1 
@export var max_hp: float = 30.0

# ── Elastic Follow Positioning ──
@export var follow_ideal_min: float = 60.0    # Start slowing down
@export var follow_ideal_max: float = 100.0   # Target orbit radius
@export var follow_deadzone: float = 50.0     # Stop completely to prevent jitter
@export var follow_sprint_dist: float = 200.0 # Sprint to catch up when far
@export var separation_distance: float = 45.0 # Minimum distance between units
@export var separation_strength: float = 1.2  # How strongly units repel each other

var target: Node2D = null
var parent_camp: Node = null
var _attack_pulse_timer: float = 0.0

var is_attacking: bool = false
var attack_index: int = 0 

# War Banner support
var banner_owner: Node2D = null
var guard_target: Node2D = null
var guard_radius: float = 350.0  # banner radius + 50px soft boundary (for zone guard mode)
var is_inspired: bool = false     # War Cry inspired state

@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("units")
	if animated_sprite:
		animated_sprite.animation_finished.connect(_on_animation_finished)
		animated_sprite.play("Run")
	
	if is_instance_valid(health_component):
		health_component.max_health = max_hp
		health_component.current_health = max_hp
		if not health_component.health_depleted.is_connected(_on_death):
			health_component.health_depleted.connect(_on_death)
	
	_setup_physics_and_factions()
	_update_visuals()

func _on_death() -> void:
	if is_instance_valid(banner_owner) and banner_owner.has_method("_on_banner_unit_died"):
		banner_owner._on_banner_unit_died(self)
	queue_free()

func _on_animation_finished() -> void:
	if animated_sprite.animation in ["Attack1", "Attack2"]:
		is_attacking = false

func _setup_physics_and_factions() -> void:
	var f_name = "player" if alignment == 1 else "rival"
	if is_instance_valid(hitbox): 
		hitbox.faction = f_name
		hitbox.collision_mask = 8 if alignment == 1 else 2 
		
	if is_instance_valid(hurtbox): 
		hurtbox.faction = f_name
		hurtbox.collision_layer = 2 if alignment == 1 else 8

func _physics_process(delta: float) -> void:
	_find_target()
	var separation = _get_separation_velocity()
	
	# ── BANNER GUARD LOGIC ──
	if is_instance_valid(guard_target):
		var g_dist: float = global_position.distance_to(guard_target.global_position)
		var has_enemy: bool = is_instance_valid(target)
		var enemy_dist: float = INF
		if has_enemy:
			enemy_dist = global_position.distance_to(target.global_position)
		
		# Determine if this is FOLLOW mode (player) or GUARD mode (banner zone)
		var is_follow_mode: bool = guard_target is Player
		
		if is_follow_mode:
			# ── ELASTIC FOLLOW MODE (60-100px ring around player) ──
			var speed_mult: float = _get_elastic_speed_mult(g_dist)
			
			# Deadzone: if very close and no enemies, just idle with separation
			if g_dist < follow_deadzone and not has_enemy:
				velocity = separation
				move_and_slide()
				if not is_attacking and animated_sprite.animation != "Idle":
					animated_sprite.play("Idle")
				return
			
			# Combat priority: enemy nearby → attack
			if has_enemy and enemy_dist < 60.0:
				velocity = separation
				if not is_attacking:
					_play_sequential_attack()
				_attack_pulse_timer += delta
				if _attack_pulse_timer >= 0.8:
					_attack_pulse_timer = 0.0
					_toggle_hitbox()
				move_and_slide()
				return
			
			# Enemy farther away → run toward enemy (but still within elastic boundary)
			if has_enemy:
				var dir: Vector2 = (target.global_position - global_position).normalized()
				velocity = (dir * speed * speed_mult + separation).normalized() * speed * speed_mult
				if not is_attacking:
					if animated_sprite.animation != "Run":
						animated_sprite.play("Run")
					if dir.x != 0:
						animated_sprite.flip_h = (dir.x < 0)
				move_and_slide()
				return
			
			# No enemy, outside deadzone → elastic approach toward player
			if g_dist >= follow_deadzone:
				var g_dir: Vector2 = (guard_target.global_position - global_position).normalized()
				velocity = (g_dir * speed * speed_mult + separation).normalized() * speed * speed_mult
				if not is_attacking:
					if animated_sprite.animation != "Run":
						animated_sprite.play("Run")
					if g_dir.x != 0:
						animated_sprite.flip_h = (g_dir.x < 0)
				move_and_slide()
				return
			
			# FALLBACK
			velocity = separation
			move_and_slide()
			if not is_attacking and animated_sprite.animation != "Idle":
				animated_sprite.play("Idle")
			return
		
		else:
			# ── ZONE GUARD MODE (existing logic, guards banner zone) ──
			if g_dist > guard_radius:
				var g_dir: Vector2 = (guard_target.global_position - global_position).normalized()
				velocity = (g_dir * speed + separation).normalized() * speed
				if not is_attacking:
					if animated_sprite.animation != "Run":
						animated_sprite.play("Run")
					if g_dir.x != 0:
						animated_sprite.flip_h = (g_dir.x < 0)
				move_and_slide()
				return
			
			if g_dist < 40.0 and not has_enemy:
				velocity = separation
				move_and_slide()
				if not is_attacking and animated_sprite.animation != "Idle":
					animated_sprite.play("Idle")
				return
			
			if has_enemy:
				if enemy_dist < 60.0:
					velocity = separation
					if not is_attacking:
						_play_sequential_attack()
					_attack_pulse_timer += delta
					if _attack_pulse_timer >= 0.8:
						_attack_pulse_timer = 0.0
						_toggle_hitbox()
				else:
					var dir: Vector2 = (target.global_position - global_position).normalized()
					velocity = (dir * speed + separation).normalized() * speed
					if not is_attacking:
						if animated_sprite.animation != "Run":
							animated_sprite.play("Run")
						if dir.x != 0:
							animated_sprite.flip_h = (dir.x < 0)
				move_and_slide()
				return
			
			if g_dist >= 40.0:
				var g_dir: Vector2 = (guard_target.global_position - global_position).normalized()
				velocity = (g_dir * speed + separation).normalized() * speed
				if not is_attacking:
					if animated_sprite.animation != "Run":
						animated_sprite.play("Run")
					if g_dir.x != 0:
						animated_sprite.flip_h = (g_dir.x < 0)
				move_and_slide()
				return
			
			velocity = separation
			move_and_slide()
			if not is_attacking and animated_sprite.animation != "Idle":
				animated_sprite.play("Idle")
			return
	
	# ── REGULAR LOGIC (unchanged) ──
	if is_instance_valid(target):
		var breaker = _get_nearby_enemy_breaker()
		if breaker: target = breaker
		var dir = (target.global_position - global_position).normalized()
		var dist = global_position.distance_to(target.global_position)
		if dist < 60.0:
			velocity = Vector2.ZERO
			if not is_attacking: _play_sequential_attack()
			_attack_pulse_timer += delta
			if _attack_pulse_timer >= 0.8:
				_attack_pulse_timer = 0.0
				_toggle_hitbox()
		else:
			velocity = dir * speed
			if not is_attacking:
				if animated_sprite.animation != "Run": animated_sprite.play("Run")
				if dir.x != 0: animated_sprite.flip_h = (dir.x < 0)
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		if not is_attacking and animated_sprite.animation != "Idle": animated_sprite.play("Idle")


func _get_separation_velocity() -> Vector2:
	var sep: Vector2 = Vector2.ZERO
	var friends: Array = get_tree().get_nodes_in_group("units")
	for friend in friends:
		if friend == self or not is_instance_valid(friend):
			continue
		if "alignment" in friend and friend.alignment != alignment:
			continue
		var d: float = global_position.distance_to(friend.global_position)
		if d < separation_distance and d > 0.01:
			sep -= (friend.global_position - global_position).normalized() * (separation_distance - d) * separation_strength
	return sep


func _play_sequential_attack() -> void:
	is_attacking = true
	var attacks = ["Attack1", "Attack2"]
	animated_sprite.play(attacks[attack_index])
	attack_index = (attack_index + 1) % 2

func _toggle_hitbox() -> void:
	if is_instance_valid(hitbox):
		var shape: CollisionShape2D = hitbox.get_node_or_null("CollisionShape2D")
		if shape:
			shape.disabled = true
			
			# During War Cry inspired state, apply knockback to hit enemies
			if is_inspired and is_instance_valid(guard_target):
				hitbox.knockback_force = 150.0
				hitbox.knockback_origin = guard_target.global_position
			else:
				hitbox.knockback_force = 0.0
			
			hitbox.check_hit()
			get_tree().create_timer(0.1).timeout.connect(_enable_shape.bind(shape))

func _enable_shape(shape: CollisionShape2D) -> void:
	if is_instance_valid(shape): shape.disabled = false

func _find_target() -> void:
	if is_instance_valid(target): return
	var potential = []
	if alignment == 1:
		potential.append_array(get_tree().get_nodes_in_group("enemy"))
		for u in get_tree().get_nodes_in_group("units"): if u.alignment == 2: potential.append(u)
		for c in get_tree().get_nodes_in_group("camps"): if c.alignment == 2: potential.append(c)
	else:
		potential.append(get_tree().get_first_node_in_group("player"))
		for u in get_tree().get_nodes_in_group("units"): if u.alignment == 1: potential.append(u)
		for c in get_tree().get_nodes_in_group("camps"): if c.alignment == 1: potential.append(c)
	var breakers = potential.filter(func(t): return is_instance_valid(t) and t is Enemy and t.current_archetype == Enemy.Archetype.BREAKER)
	var final_list = breakers if not breakers.is_empty() else potential
	var min_d = INF
	for t in final_list:
		if is_instance_valid(t):
			var d = global_position.distance_to(t.global_position); if d < min_d: min_d = d; target = t

func _get_nearby_enemy_breaker() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if is_instance_valid(e) and e is Enemy and e.current_archetype == Enemy.Archetype.BREAKER:
			if global_position.distance_to(e.global_position) < 400.0: return e
	return null

func _get_elastic_speed_mult(dist: float) -> float:
	# Elastic speed curve for follow mode:
	#   < 50px (deadzone)  → 0.0  (stop)
	#   50-60px             → 0.2  (very slow creep)
	#   60-100px            → smooth lerp from 0.2 to 1.0
	#   100-200px           → 1.0  (normal speed)
	#   > 200px             → 1.5  (sprint to catch up)
	if dist < follow_deadzone:
		return 0.0
	elif dist < follow_ideal_min:
		return lerpf(0.2, 0.5, inverse_lerp(follow_deadzone, follow_ideal_min, dist))
	elif dist < follow_ideal_max:
		return lerpf(0.5, 1.0, inverse_lerp(follow_ideal_min, follow_ideal_max, dist))
	elif dist < follow_sprint_dist:
		return 1.0
	else:
		return 1.5


# ── War Cry Signal Handler ──
func _on_war_cry(is_active: bool) -> void:
	is_inspired = is_active
	if is_active:
		modulate = Color(1.0, 0.84, 0.0, 1.0)  # Gold
	else:
		_update_visuals()  # Restore normal faction color


func flip_alignment(new_align: int) -> void:
	alignment = new_align; _setup_physics_and_factions(); _update_visuals(); target = null

func _update_visuals() -> void:
	modulate = Color.CORNFLOWER_BLUE if alignment == 1 else Color.INDIAN_RED