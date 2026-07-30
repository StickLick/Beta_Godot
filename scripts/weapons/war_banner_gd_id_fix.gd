func _clean_dead_assignments() -> void:
	var safe_targets: Dictionary = {}
	for p_id: int in _pawn_targets.keys():
		var pawn_instance: Node = instance_from_id(p_id) as Node
		if not is_instance_valid(pawn_instance) or pawn_instance.is_queued_for_deletion():
			continue
		var t_id: int = _pawn_targets[p_id]
		var target_instance: Node = instance_from_id(t_id) as Node
		if not is_instance_valid(target_instance) or target_instance.is_queued_for_deletion():
			var pawn_unit: Unit = pawn_instance as Unit
			if pawn_unit:
				pawn_unit.target = null
				pawn_unit.is_attacking = false
			continue
		safe_targets[p_id] = t_id
	_pawn_targets = safe_targets

	var safe_offsets: Dictionary = {}
	for p_id: int in _formation_offsets.keys():
		var pawn_instance: Node = instance_from_id(p_id) as Node
		if is_instance_valid(pawn_instance) and not pawn_instance.is_queued_for_deletion():
			safe_offsets[p_id] = _formation_offsets[p_id]
	_formation_offsets = safe_offsets

	_banner_units = _banner_units.filter(func(u: Unit): return is_instance_valid(u) and not u.is_queued_for_deletion())


func _assign_targets() -> void:
	var free_pawns: Array[Unit] = []
	for pawn: Unit in _banner_units:
		if not is_instance_valid(pawn):
			continue
		var p_id: int = pawn.get_instance_id()
		if not _pawn_targets.has(p_id) or not is_instance_valid(instance_from_id(_pawn_targets[p_id])):
			free_pawns.append(pawn)
			pawn.target = null

	if free_pawns.is_empty():
		return

	var enemies_near_player: Array[Node2D] = _get_enemies_near_player()

	for enemy: Node2D in enemies_near_player:
		if not is_instance_valid(enemy):
			continue
		var enemy_id: int = enemy.get_instance_id()
		var current_attackers: int = 0
		for t_id: int in _pawn_targets.values():
			if t_id == enemy_id:
				current_attackers += 1
		var max_allowed: int = MAX_PAWNS_PER_BOSS if enemy.get_meta("is_boss", false) else MAX_PAWNS_PER_ENEMY
		var slots_available: int = max_allowed - current_attackers
		while slots_available > 0 and not free_pawns.is_empty():
			var pawn: Unit = free_pawns.pop_front()
			pawn.target = enemy
			_pawn_targets[pawn.get_instance_id()] = enemy_id
			slots_available -= 1


func _on_banner_unit_died(unit: Unit) -> void:
	var unit_id: int = unit.get_instance_id()
	_banner_units.erase(unit)
	_pawn_targets.erase(unit_id)
	_formation_offsets.erase(unit_id)

	if war_cry_triggered.is_connected(unit._on_war_cry):
		war_cry_triggered.disconnect(unit._on_war_cry)


func get_pawn_target(pawn: Unit) -> Node2D:
	var t_id: int = _pawn_targets.get(pawn.get_instance_id(), -1)
	if t_id == -1:
		return null
	return instance_from_id(t_id) as Node2D


func get_formation_offset(pawn: Unit) -> Vector2:
	return _formation_offsets.get(pawn.get_instance_id(), Vector2(80, 0))