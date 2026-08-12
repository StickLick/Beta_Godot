extends Node
## GachaManager — автозагрузка: логика слот-машины фрагментов.
## Поток: start_spin() → (continue_spin() x N) → settle_spin().
## GachaManager — единственный источник истины для текущего индекса реала.
## Валюту списывает каждый шаг. Фрагменты выдаются ТОЛЬКО при settle_spin().
## Провал продолжения: фрагменты НЕ выдаются, возвращается 35% ВСЕЙ потраченной в попытке валюты.
## Логика полностью отделена от UI.

const GACHA_DATA := preload("res://scripts/gacha_data.gd")
## Ключ в SaveManager для хранения активной (незавершённой) сессии Slot-Luck.
## Сессия сохраняется на диске, чтобы закрытие приложения/устройства не теряло
## потраченную валюту и накопленные символы. Источник истины — сохранённая сессия, не UI.
const SESSION_SAVE_KEY: String = "slotluck_session"


func _meta() -> Node:
	return get_node_or_null("/root/MetaProgress")


func _save() -> Node:
	return get_node_or_null("/root/SaveManager")


## Текущая серия удачи (для UI).
func get_luck_streak() -> int:
	var sm := _save()
	if not sm:
		return 0
	return int(sm.get_value("luck_streak", 0))


## Стоимость первого спина.
func get_first_cost() -> int:
	return GACHA_DATA.SPIN_COSTS[0]


## Стоимость продолжения на реал с индексом reel_index (0-based).
func get_continue_cost(reel_index: int) -> int:
	if reel_index < 0 or reel_index >= GACHA_DATA.REEL_COUNT:
		return -1
	return GACHA_DATA.SPIN_COSTS[reel_index]


## Начать спин: крутится 1-й реал (всегда успех, провала нет).
## Возвращает состояние спина. Сохраняет сессию на диск (источник истины).
func start_spin() -> Dictionary:
	# Нельзя начать новый спин, пока не завершена активная сессия (анти-эксплойт).
	if has_active_session():
		return { "error": "session_active" }

	var meta := _meta()
	if meta == null or not meta.can_afford(get_first_cost()):
		return { "error": "not_enough_currency" }

	if not meta.spend_currency(get_first_cost()):
		return { "error": "not_enough_currency" }

	var state := _new_session()
	state["total_spent"] = get_first_cost()
	state["reward_granted"] = false
	_spin_reel(state, 0)
	_save_session(state)
	return _result_payload(state)


## Есть ли активная (незавершённая) сессия на диске.
func has_active_session() -> bool:
	var sm := _save()
	if not sm:
		return false
	var saved: Variant = sm.get_value(SESSION_SAVE_KEY, {})
	return typeof(saved) == TYPE_DICTIONARY and not saved.is_empty()


## Загрузить сохранённую сессию (для восстановления после закрытия приложения).
func load_session() -> Dictionary:
	var sm := _save()
	if not sm:
		return {}
	var saved: Variant = sm.get_value(SESSION_SAVE_KEY, {})
	if typeof(saved) != TYPE_DICTIONARY:
		return {}
	return saved.duplicate(true)


## Полностью очистить сохранённую сессию (после финального действия).
func clear_session() -> void:
	var sm := _save()
	if sm:
		sm.set_value(SESSION_SAVE_KEY, {})


## Сохранить текущее состояние сессии на диск (источник истины).
func _save_session(state: Dictionary) -> void:
	var sm := _save()
	if sm:
		sm.set_value(SESSION_SAVE_KEY, state.duplicate(true))


## Продолжить спин: платит стоимость следующего реала и крутит его.
## Индекс следующего реала берётся ТОЛЬКО из state (GachaManager — источник истины).
func continue_spin(state: Dictionary) -> Dictionary:
	if state.get("finished", false):
		return _error_payload("already_finished", state)

	var reel_index: int = int(state.get("next_reel", 0))
	if reel_index <= 0 or reel_index >= GACHA_DATA.REEL_COUNT:
		return _error_payload("invalid_reel", state)

	var meta := _meta()
	var cost: int = get_continue_cost(reel_index)
	if meta == null or not meta.can_afford(cost):
		return {
			"error": "not_enough_currency",
			"state": state,
		}
	if not meta.spend_currency(cost):
		return {
			"error": "not_enough_currency",
			"state": state,
		}

	# Накопленная сумма за текущую попытку (включая этот шаг).
	state["total_spent"] = int(state.get("total_spent", 0)) + cost

	# Результат продолжения.
	var failed: bool = randf() < GACHA_DATA.FAIL_CHANCES[reel_index]
	if failed:
		state["finished"] = true
		state["failed"] = true
		state["fail_reel"] = reel_index
		var compensation: int = int(round(int(state["total_spent"]) * GACHA_DATA.CONTINUE_COMPENSATION_PCT))
		state["compensation"] = compensation
		state["compensation_granted"] = false
		# Провал: фрагменты НЕ выдаются. Просто помечаем сессию завершённой.
		state["settled"] = true
		state["rewards"] = {}
		state["bonuses"] = {}
		state["rarity"] = "none"
	else:
		_spin_reel(state, reel_index)

	# Сохраняем состояние после КАЖДОГО шага (источник истины на диске).
	_save_session(state)
	return _result_payload(state)


## Забрать награду/компенсацию: выдаёт фрагменты и завершает спин.
## Компенсация при провале выдаётся ТОЛЬКО здесь (по нажатию кнопки в UI),
## иначе игрок не увидел бы момент её начисления.
## Сессия очищается ТОЛЬКО после финального действия (анти-дубль: повторное нажатие
## не может выдать награду/компенсацию повторно).
func settle_spin(state: Dictionary) -> Dictionary:
	_grant_pending_compensation(state)
	_finish_session(state)
	clear_session()
	state["session_settled"] = true
	return _result_payload(state)


## Внутреннее состояние новой сессии.
func _new_session() -> Dictionary:
	return {
		"spins": [],           # [{rarity, color, content_id, fragments}]
		"rewards": {},         # content_id -> fragments
		"color_counts": {},    # rarity -> кол-во символов
		"next_reel": 0,        # индекс следующего реала (0-based). GachaManager — источник истины.
		"finished": false,
		"failed": false,
		"fail_reel": -1,
		"compensation": 0,
		"compensation_granted": false,
		"reward_granted": false,
		"total_spent": 0,
		"rarity": "common",
		"settled": false,
		"session_settled": false,
	}


## Крутит один реал (всегда успешный символ).
## reel_index — 0-based индекс прокручиваемого реала.
func _spin_reel(state: Dictionary, reel_index: int) -> void:
	var roll := _roll_symbol()
	var rarity: int = int(roll["rarity"])
	var cid: String = String(roll["content_id"])
	var base_frags: int = int(roll["fragments"])

	state["spins"].append({
		"rarity": rarity,
		"color": rarity,
		"content_id": cid,
		"fragments": base_frags,
	})

	# Копим символы по цвету (для комбо после завершения).
	var counts: Dictionary = state["color_counts"]
	counts[rarity] = int(counts.get(rarity, 0)) + 1

	# Следующий реал для UI-запроса (GachaManager решает).
	state["next_reel"] = reel_index + 1
	if int(state["next_reel"]) >= GACHA_DATA.REEL_COUNT:
		# 5-й реал прокручен — спин заканчивается автоматически (можно только забрать).
		state["finished"] = true


## Завершает сессию: считает комбо и выдаёт фрагменты.
func _finish_session(state: Dictionary) -> void:
	if state.get("settled", false):
		return
	# Фрагменты/контент выдаются ровно один раз (анти-эксплойт на повторное открытие).
	if bool(state.get("reward_granted", false)):
		return
	state["settled"] = true
	state["finished"] = true
	state["reward_granted"] = true

	var rewards: Dictionary = {}
	var bonuses: Dictionary = {}  # rarity -> множитель
	var best_rarity: int = GACHA_DATA.RARITY_COMMON

	# Считаем комбо по каждому цвету. Запоминаем МАКСИМАЛЬНЫЙ достигнутый множитель.
	var counts: Dictionary = state["color_counts"]
	var best_mult: float = 1.0
	for rar: int in counts:
		var cnt: int = int(counts[rar])
		if int(rar) > best_rarity:
			best_rarity = int(rar)
		var mult: float = 1.0
		if cnt >= 3 and GACHA_DATA.COMBO_MULTIPLIERS.has(cnt):
			mult = float(GACHA_DATA.COMBO_MULTIPLIERS[cnt])
			bonuses[rar] = mult
			best_mult = max(best_mult, mult)

	# Игрок получает ТОЛЬКО ОДИН финальный множитель (максимальный из достигнутых).
	# Множители не стакаются по цветам.
	# Все фрагменты сессии складываются в ОДИН общий пул...
	var total_frag_pool: int = 0
	for spin: Dictionary in state["spins"]:
		var base: int = int(spin["fragments"])
		total_frag_pool += int(round(base * best_mult))

	# ...и затем случайно распределяются между ещё не разблокированным контентом.
	rewards = _distribute_fragments_randomly(total_frag_pool)

	state["rewards"] = rewards
	state["bonuses"] = bonuses
	state["rarity"] = GACHA_DATA.RARITY_NAMES.get(best_rarity, "common")

	# Фрагменты выдаются только сейчас (финальный результат).
	# Пустой content_id (пул редкости не имеет контента) не зачисляется в MetaProgress —
	# выдаются только сами фрагменты, без привязки к контенту.
	var meta := _meta()
	if meta:
		for cid in rewards:
			if cid.is_empty():
				continue
			meta.add_fragments(cid, rewards[cid])

	# Серия удачи по лучшей редкости. Провал не увеличивает streak.
	if not state.get("failed", false):
		_update_streak(best_rarity)


## Один ролл символа. Возвращает { content_id, rarity, fragments }.
## Редкость определяет ТОЛЬКО количество фрагментов (COLOR_FRAGMENTS): 1/2/3/5.
## Определение того, КАКОЙ контент получит фрагменты, здесь НЕ происходит —
## весь пул фрагментов сессии распределяется случайно в _finish_session()
## через _distribute_fragments_randomly().
func _roll_symbol() -> Dictionary:
	var rarity := _roll_rarity()

	# Базовые фрагменты строго по цвету символа: White=1, Blue=2, Purple=3, Gold=5.
	var frags: int = int(GACHA_DATA.COLOR_FRAGMENTS.get(rarity, 1))

	return {
		"content_id": "",
		"rarity": rarity,
		"fragments": frags,
	}


## Выбор редкости (цвета) по взвешенному распределению.
func _roll_rarity() -> int:
	var streak := get_luck_streak()
	var weights: Dictionary = {}
	var total: float = 0.0

	for rar in GACHA_DATA.BASE_WEIGHT:
		var w: float = GACHA_DATA.BASE_WEIGHT[rar]
		if rar >= GACHA_DATA.RARITY_EPIC:
			w *= 1.0 + streak * GACHA_DATA.STREAK_BONUS_PER_STEP
		weights[rar] = w
		total += w

	var roll: float = randf() * total
	var acc: float = 0.0
	for rar in GACHA_DATA.BASE_WEIGHT:
		acc += weights[rar]
		if roll <= acc:
			return rar
	return GACHA_DATA.RARITY_COMMON


## Единый пул всего ещё не разблокированного контента (герои/оружия/пассивки).
## Редкость не участвует: все закрытые предметы имеют равные шансы выпадения.
## Если весь контент открыт — возвращается пустой массив (content_id == "").
func _get_locked_content_pool() -> Array:
	var meta := _meta()
	var pool: Array = []
	for cid in GACHA_DATA.CONTENT:
		var entry: Dictionary = GACHA_DATA.CONTENT[cid]
		# Уже разблокированный контент исключается из пула выпадения.
		if meta != null and _is_content_unlocked(meta, cid, String(entry.get("category", ""))):
			continue
		pool.append(cid)
	return pool


## Случайное распределение общего пула фрагментов между закрытым контентом.
## Намеренно НЕ оптимизировано: каждый шаг выбирается случайный закрытый предмет,
## которому начисляется случайное количество (1..оставшаяся потребность).
## Предмет, достигший порога разблокировки, исключается из дальнейших выборов.
## Возвращает { content_id: amount } (пустой, если распределять некому).
func _distribute_fragments_randomly(total_fragments: int) -> Dictionary:
	var rewards: Dictionary = {}
	if total_fragments <= 0:
		return rewards
	var meta := _meta()
	if meta == null:
		return rewards

	var locked: Array = _get_locked_content_pool()
	var pool: int = total_fragments

	while pool > 0 and not locked.is_empty():
		var idx: int = randi_range(0, locked.size() - 1)
		var cid: String = String(locked[idx])
		var entry: Dictionary = GACHA_DATA.CONTENT[cid]
		var req: int = int(entry.get("req_fragments", 0))
		if req <= 0:
			# Контент без порога не разблокируется фрагментами — пропускаем.
			locked.remove_at(idx)
			continue
		# Сколько уже начислено предмету (включая текущую сессию).
		var have: int = meta.get_fragment_count(cid) + int(rewards.get(cid, 0))
		var remaining: int = req - have
		if remaining <= 0:
			# Потребность закрыта — предмет больше не участвует в распределении.
			locked.remove_at(idx)
			continue
		# Случайное количество: от 1 до потребности, но не больше оставшегося пула.
		var max_give: int = min(remaining, pool)
		var amount: int = randi_range(1, max_give)
		rewards[cid] = int(rewards.get(cid, 0)) + amount
		pool -= amount
		if have + amount >= req:
			# Предмет достиг порога — убираем из будущих случайных выборов.
			locked.remove_at(idx)

	return rewards


## Разблокирован ли контент уже (по категории).
## Для неизвестной/пустой категории возвращает false — контент считается доступным.
func _is_content_unlocked(meta: Node, cid: String, category: String) -> bool:
	match category:
		"hero":
			return meta.is_hero_unlocked(cid)
		"weapon":
			return meta.is_weapon_unlocked(cid)
		"passive":
			return meta.is_passive_unlocked(cid)
	return false


## Выдача отложенной компенсации при провале. Вызывается только из settle_spin()
## (по нажатию кнопки "Забрать компенсацию" в UI), чтобы игрок видел момент начисления.
func _grant_pending_compensation(state: Dictionary) -> void:
	if not state.get("failed", false):
		return
	if bool(state.get("compensation_granted", false)):
		return
	var comp: int = int(state.get("compensation", 0))
	if comp > 0:
		_compensate_currency(comp)
	state["compensation_granted"] = true


## Возврат компенсации (часть стоимости шага — игрок не теряет всё).
func _compensate_currency(amount: int) -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_method("add_meta_currency"):
		gm.add_meta_currency(amount)


## Обновление luck_streak: сброс при высокой редкости, иначе +1.
func _update_streak(best_rarity: int) -> void:
	var sm := _save()
	if not sm:
		return
	var streak := int(sm.get_value("luck_streak", 0))
	if best_rarity in GACHA_DATA.STREAK_RESET_RARITIES:
		streak = 0
	else:
		streak += 1
	sm.set_value("luck_streak", streak)


## Пакует состояние в результат для UI.
func _result_payload(state: Dictionary) -> Dictionary:
	var payload: Dictionary = state.duplicate(true)
	payload["error"] = ""
	return payload


func _error_payload(code: String, state: Dictionary) -> Dictionary:
	var payload: Dictionary = state.duplicate(true)
	payload["error"] = code
	return payload