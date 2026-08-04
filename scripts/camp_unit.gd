extends "res://scripts/unit.gd"
class_name CampUnit

var parent_camp: Node = null

func _physics_process(delta: float) -> void:
    _find_target()
    var separation: Vector2 = _get_separation_velocity()
    if is_instance_valid(guard_target):
        var g_dist: float = global_position.distance_to(guard_target.global_position)
        var has_enemy: bool = is_instance_valid(target)
        var enemy_dist: float = INF
        if has_enemy:
            enemy_dist = global_position.distance_to(target.global_position)
        var is_follow_mode: bool = guard_target is Player
        if is_follow_mode:
            var speed_mult: float = _get_elastic_speed_mult(g_dist)
            if g_dist < follow_deadzone and not has_enemy:
                velocity = separation
                if not is_attacking and animated_sprite.animation != "Idle":
                    animated_sprite.play("Idle")
            elif has_enemy and enemy_dist < 60.0:
                velocity = separation
                if not is_attacking:
                    _play_sequential_attack()
                _attack_pulse_timer += delta
                if _attack_pulse_timer >= 0.8:
                    _attack_pulse_timer = 0.0
                    _toggle_hitbox()
            elif has_enemy:
                var dir: Vector2 = (target.global_position - global_position).normalized()
                velocity = (dir * speed * speed_mult + separation).normalized() * speed * speed_mult
                _update_run_anim(dir)
            elif g_dist >= follow_deadzone:
                var g_dir: Vector2 = (guard_target.global_position - global_position).normalized()
                velocity = (g_dir * speed * speed_mult + separation).normalized() * speed * speed_mult
                _update_run_anim(g_dir)
            else:
                velocity = separation
                if not is_attacking and animated_sprite.animation != "Idle":
                    animated_sprite.play("Idle")
        else:
            if g_dist > guard_radius:
                var g_dir: Vector2 = (guard_target.global_position - global_position).normalized()
                velocity = (g_dir * speed + separation).normalized() * speed
                _update_run_anim(g_dir)
            elif g_dist < 40.0 and not has_enemy:
                velocity = separation
                if not is_attacking and animated_sprite.animation != "Idle":
                    animated_sprite.play("Idle")
            elif has_enemy:
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
                    _update_run_anim(dir)
            elif g_dist >= 40.0:
                var g_dir: Vector2 = (guard_target.global_position - global_position).normalized()
                velocity = (g_dir * speed + separation).normalized() * speed
                _update_run_anim(g_dir)
            else:
                velocity = separation
                if not is_attacking and animated_sprite.animation != "Idle":
                    animated_sprite.play("Idle")
    elif is_instance_valid(target):
        var breaker: Node2D = _get_nearby_enemy_breaker()
        if breaker:
            target = breaker
        var dir: Vector2 = (target.global_position - global_position).normalized()
        var dist: float = global_position.distance_to(target.global_position)
        if dist < 60.0:
            velocity = Vector2.ZERO
            if not is_attacking:
                _play_sequential_attack()
            _attack_pulse_timer += delta
            if _attack_pulse_timer >= 0.8:
                _attack_pulse_timer = 0.0
                _toggle_hitbox()
        else:
            velocity = dir * speed
            _update_run_anim(dir)
    else:
        velocity = Vector2.ZERO
        if not is_attacking and animated_sprite.animation != "Idle":
            animated_sprite.play("Idle")
    super(delta)

func _play_sequential_attack(_target: Node2D = null, _banner: WarBanner = null) -> void:
    is_attacking = true
    var attacks: Array[String] = ["Attack1", "Attack2"]
    animated_sprite.play(attacks[attack_index])
    attack_index = (attack_index + 1) % 2

func _on_animation_finished() -> void:
    if animated_sprite.animation in ["Attack1", "Attack2"]:
        is_attacking = false
        if animated_sprite.sprite_frames.has_animation("Run"):
            animated_sprite.play("Run")

func _find_target() -> void:
    if is_instance_valid(target):
        return
    var potential: Array = []
    if alignment == 1:
        potential.append_array(get_tree().get_nodes_in_group("enemy"))
        for u in get_tree().get_nodes_in_group("units"):
            if u.alignment == 2:
                potential.append(u)
        for c in get_tree().get_nodes_in_group("camps"):
            if c.alignment == 2:
                potential.append(c)
    else:
        potential.append(get_tree().get_first_node_in_group("player"))
        for u in get_tree().get_nodes_in_group("units"):
            if u.alignment == 1:
                potential.append(u)
        for c in get_tree().get_nodes_in_group("camps"):
            if c.alignment == 1:
                potential.append(c)
    var breakers = potential.filter(func(t): return is_instance_valid(t) and t is Enemy and t.current_archetype == Enemy.Archetype.BREAKER)
    var final_list = breakers if not breakers.is_empty() else potential
    var min_d: float = INF
    for t in final_list:
        if is_instance_valid(t):
            var d: float = global_position.distance_to(t.global_position)
            if d < min_d:
                min_d = d
                target = t

func _get_nearby_enemy_breaker() -> Node2D:
    var enemies: Array = get_tree().get_nodes_in_group("enemy")
    for e in enemies:
        if is_instance_valid(e) and e is Enemy and e.current_archetype == Enemy.Archetype.BREAKER:
            if global_position.distance_to(e.global_position) < 400.0:
                return e
    return null
