extends Node
## Тесты прогрессии FortArcher от уровня форта (military_level).
## Проверяют:
##  - уровень 1 = базовые статы
##  - уровень 2/3 = рост урона, дальности, снижение кулдауна
##  - повторный set_fort_level мгновенно обновляет статы
##  - кулдаун не опускается ниже min_attack_cooldown

const FORT_ARCHER_SCRIPT := preload("res://scripts/fort_archer.gd")


## Создаёт чистый FortArcher вне дерева (без сцены ArcherPawn),
## только для проверки пересчёта статов.
func _make_fort_archer():
	var archer = FORT_ARCHER_SCRIPT.new()
	archer.base_damage = 10.0
	archer.base_range = 300.0
	archer.base_attack_cooldown = 1.0
	archer.damage_per_level = 5.0
	archer.range_per_level = 40.0
	archer.cooldown_reduction_per_level = 0.12
	archer.min_attack_cooldown = 0.3
	return archer


var _failures: Array = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)
		push_error("[FORT ARCHER TEST FAIL] " + msg)


func test_fort_level_scaling() -> void:
	_failures.clear()

	# Уровень 1 = базовые статы.
	var a1 = _make_fort_archer()
	a1.set_fort_level(1)
	_check(a1.fort_level == 1, "Lv.1: fort_level должен быть 1")
	_check(a1.turret_range == 300.0, "Lv.1: range = base_range (300)")
	_check(a1.turret_fire_interval == 1.0, "Lv.1: cooldown = base_attack_cooldown (1.0)")
	_check(a1._current_arrow_damage == 10.0, "Lv.1: damage = base_damage (10)")
	a1.free()

	# Уровень 2 = рост урона/дальности, снижение кулдауна.
	var a2 = _make_fort_archer()
	a2.set_fort_level(2)
	_check(a2.turret_range == 340.0, "Lv.2: range = 300 + 40 (340)")
	_check(a2._current_arrow_damage == 15.0, "Lv.2: damage = 10 + 5 (15)")
	_check(a2.turret_fire_interval == 0.88, "Lv.2: cooldown = 1.0 - 0.12 (0.88)")
	a2.free()

	# Уровень 3 = ещё сильнее.
	var a3 = _make_fort_archer()
	a3.set_fort_level(3)
	_check(a3.turret_range == 380.0, "Lv.3: range = 300 + 80 (380)")
	_check(a3._current_arrow_damage == 20.0, "Lv.3: damage = 10 + 10 (20)")
	_check(a3.turret_fire_interval == 0.76, "Lv.3: cooldown = 1.0 - 0.24 (0.76)")
	a3.free()

	# Повторный set_fort_level мгновенно обновляет статы (апгрейд форта).
	var a_up = _make_fort_archer()
	a_up.set_fort_level(1)
	a_up.set_fort_level(2)
	_check(a_up.turret_range == 340.0, "Повторный set_fort_level(2) мгновенно обновляет range")
	_check(a_up._current_arrow_damage == 15.0, "Повторный set_fort_level(2) мгновенно обновляет damage")
	_check(a_up.turret_fire_interval == 0.88, "Повторный set_fort_level(2) мгновенно обновляет cooldown")
	a_up.free()

	# Уровень 0 (форт не построен) → clamped до 1.
	var a0 = _make_fort_archer()
	a0.set_fort_level(0)
	_check(a0.fort_level == 1, "Lv.0: fort_level должен быть clamped до 1")
	_check(a0.turret_range == 300.0, "Lv.0: range = базовый")
	_check(a0._current_arrow_damage == 10.0, "Lv.0: damage = базовый")
	a0.free()

	# Кулдаун не ниже min_attack_cooldown.
	var a_high = _make_fort_archer()
	a_high.set_fort_level(50)
	_check(a_high.turret_fire_interval == 0.3, "Высокий уровень: cooldown не ниже min_attack_cooldown (0.3)")
	a_high.free()

	if _failures.is_empty():
		print("[FORT ARCHER TEST] PASSED: Lv.1 базовые статы, Lv.2/Lv.3 масштабирование, мгновенное обновление, clamp, cooldown floor")