extends Control
## GachaScreen — UI слот-машины фрагментов.
## Поток: первый спин всегда платный → после каждого реала "Забрать" или "Продолжить".
## Логика (шансы, комбо, компенсация) — полностью в GachaManager.
## Фрагменты выдаются только при финальном результате; экран коллекции отвечает за разблокировки.

const GACHA_DATA := preload("res://scripts/gacha_data.gd")
const REEL_COUNT: int = GACHA_DATA.REEL_COUNT

@onready var currency_label: Label = %CurrencyLabel
@onready var result_label: Label = %ResultLabel
@onready var combo_preview_label: Label = %ComboPreviewLabel
@onready var spin_button: Button = %SpinButton
@onready var continue_button: Button = %ContinueButton
@onready var collect_button: Button = %CollectButton
@onready var reels_container: HBoxContainer = %ReelsContainer
@onready var rules_popup: Panel = %RulesPopup
@onready var rules_label: Label = %RulesLabel
@onready var close_button: Button = get_node("CenterContainer/VBoxContainer/CloseButton")

var _reel_panels: Array = []  # [{panel: PanelContainer, label: Label}]
var _session: Dictionary = {}
var _revealed: int = 0
var _animating: bool = false

# Скорость анимации реалов.
const SPIN_TICK: float = 0.09
const SPIN_TICKS: int = 10
const STOP_DELAY: float = 0.35


func _ready() -> void:
	_build_reels()
	_build_rules_text()
	_reset_ui()
	refresh()


func _build_reels() -> void:
	for i in range(REEL_COUNT):
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(72, 72)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label := Label.new()
		label.text = "?"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 34)
		panel.add_child(label)
		reels_container.add_child(panel)
		_reel_panels.append({"panel": panel, "label": label})


func _build_rules_text() -> void:
	var lines: Array[String] = []
	lines.append("РЕДКОСТИ И НАГРАДЫ:")
	for rar in [GACHA_DATA.RARITY_COMMON, GACHA_DATA.RARITY_RARE, GACHA_DATA.RARITY_EPIC, GACHA_DATA.RARITY_LEGENDARY]:
		var sym: String = String(GACHA_DATA.COLOR_SYMBOLS.get(rar, "?"))
		var name: String = String(GACHA_DATA.RARITY_NAMES.get(rar, "?"))
		lines.append("%s %s — %d фрагмент(ов)" % [sym, name.to_upper(), GACHA_DATA.COLOR_FRAGMENTS[rar]])
	lines.append("")
	lines.append("КОМБО:")
	lines.append("3+ символа одного цвета = бонус: 3=x2, 4=x3, 5=x5")
	lines.append("Символы считаются по всем реалам (соседство не важно)")
	lines.append("")
	lines.append("ПРОДОЛЖЕНИЕ:")
	lines.append("Каждый следующий реал дороже.")
	lines.append("Провал возвращает 35% ВСЕЙ потраченной валюты за попытку.")
	lines.append("При провале фрагменты не выдаются.")
	rules_label.text = "\n".join(lines)


## Обновление валюты и streak.
func refresh() -> void:
	var gm := get_node_or_null("/root/GameManager")
	var gacha := get_node_or_null("/root/GachaManager")
	var meta := get_node_or_null("/root/MetaProgress")
	if not gm or not gacha or not meta:
		return
	currency_label.text = "Валюта: %d" % gm.get_meta_currency()
	spin_button.text = "Крутить (%d)" % gacha.get_first_cost()
	spin_button.disabled = _animating or not meta.can_afford(gacha.get_first_cost())

	# Back/Close недоступны, пока активна сессия или идёт анимация (защита от потери валюты).
	close_button.disabled = _animating or gacha.has_active_session()

	# Восстановление сохранённой сессии после закрытия приложения/устройства.
	if gacha.has_active_session() and _session.is_empty():
		_restore_session()


# --- КНОПКИ ---

func _on_info_pressed() -> void:
	rules_popup.visible = not rules_popup.visible
	rules_popup.move_to_front()


# Клик вне попапа — закрывает его; клик внутри попапа не закрывает.
func _gui_input(event: InputEvent) -> void:
	if rules_popup.visible and event is InputEventMouseButton and event.pressed:
		var popup_rect: Rect2 = rules_popup.get_global_rect()
		if not popup_rect.has_point(get_global_mouse_position()):
			rules_popup.visible = false


func _on_close_rules_pressed() -> void:
	rules_popup.visible = false


func _on_spin_pressed() -> void:
	if _animating:
		return
	var gacha := get_node_or_null("/root/GachaManager")
	if not gacha:
		return
	result_label.text = ""
	var result: Dictionary = gacha.start_spin()
	if result.get("error", "") != "":
		_show_error(String(result["error"]))
		refresh()
		return
	_session = result
	await _run_reel_animation()
	_update_combo_preview()
	_show_current_state()
	refresh()


func _on_continue_pressed() -> void:
	if _animating or _session.is_empty():
		return
	var gacha := get_node_or_null("/root/GachaManager")
	if not gacha:
		return
	# Индекс следующего реала полностью управляется GachaManager (state.next_reel).
	var result: Dictionary = gacha.continue_spin(_session)
	if result.get("error", "") != "":
		_show_error(String(result["error"]))
		refresh()
		return
	_session = result
	await _run_reel_animation()
	_update_combo_preview()
	_show_current_state()
	refresh()


func _on_collect_pressed() -> void:
	if _session.is_empty():
		return
	var gacha := get_node_or_null("/root/GachaManager")
	if not gacha:
		return
	var was_failed: bool = bool(_session.get("failed", false))
	_session = gacha.settle_spin(_session)
	if was_failed:
		# Компенсация выдана: информация о предыдущей попытке исчезает.
		result_label.text = ""
	else:
		_show_final_result()
	_reset_reels()
	refresh()


func _on_close_pressed() -> void:
	# Нельзя покинуть экран во время анимации или при активной сессии (анти-эксплойт).
	var gacha := get_node_or_null("/root/GachaManager")
	if _animating or (gacha and gacha.has_active_session()):
		return
	hide()


# --- АНИМАЦИЯ РЕАЛОВ ---

## Анимирует новые реалы (от _revealed до текущего числа spins) последовательно.
## При провале показывает символ ✕ на провальном реале.
func _run_reel_animation() -> void:
	_animating = true
	spin_button.disabled = true
	continue_button.disabled = true
	collect_button.disabled = true

	var spins: Array = _session.get("spins", [])
	for i in range(_revealed, spins.size()):
		await _animate_single_reel(i)
		await get_tree().create_timer(STOP_DELAY).timeout
	_revealed = spins.size()

	# Провал: показываем ✕ на реале fail_reel (он не попал в spins).
	if bool(_session.get("failed", false)):
		var fail_reel: int = int(_session.get("fail_reel", -1))
		if fail_reel >= 0 and fail_reel < _reel_panels.size():
			var entry: Dictionary = _reel_panels[fail_reel]
			var label: Label = entry["label"]
			for t in range(SPIN_TICKS):
				label.text = String(GACHA_DATA.COLOR_SYMBOLS.get(randi_range(0, 3), "?"))
				await get_tree().create_timer(SPIN_TICK).timeout
			await get_tree().create_timer(STOP_DELAY).timeout
			label.text = GACHA_DATA.FAIL_SYMBOL
			label.modulate = Color(0.6, 0.2, 0.2)
		_revealed = fail_reel + 1

	_animating = false


func _animate_single_reel(i: int) -> void:
	var spin: Dictionary = _session["spins"][i]
	var rarity: int = int(spin["rarity"])
	var final_symbol: String = String(GACHA_DATA.COLOR_SYMBOLS.get(rarity, "?"))
	var entry: Dictionary = _reel_panels[i]
	var label: Label = entry["label"]

	# Медленная прокрутка случайных символов.
	for t in range(SPIN_TICKS):
		label.text = String(GACHA_DATA.COLOR_SYMBOLS.get(randi_range(0, 3), "?"))
		label.modulate = Color.WHITE
		await get_tree().create_timer(SPIN_TICK).timeout

	# Стоп-эффект: подсветка перед фиксацией результата.
	label.modulate = Color(1.0, 1.0, 0.4)
	await get_tree().create_timer(0.15).timeout
	label.text = final_symbol
	label.modulate = GACHA_DATA.COLOR_HEX.get(rarity, Color.WHITE)


# --- ОТОБРАЖЕНИЕ СОСТОЯНИЯ ---

## Превью текущей комбинации (не финальные награды!).
## Показывает счётчики редкостей остановленных реалов и прогресс к бонусу комбо.
## Ничего не выдаёт и не модифицирует состояние.
func _update_combo_preview() -> void:
	var spins: Array = _session.get("spins", [])
	if spins.is_empty() or bool(_session.get("failed", false)):
		combo_preview_label.text = ""
		return

	# Подсчёт только остановленных реалов (скрытые/крутящиеся не включаются).
	var counts: Dictionary = {}
	for spin: Dictionary in spins:
		var rar: int = int(spin["rarity"])
		counts[rar] = int(counts.get(rar, 0)) + 1

	var lines: Array[String] = []
	# Счётчики редкостей: от COMMON к LEGENDARY.
	for rar in [GACHA_DATA.RARITY_COMMON, GACHA_DATA.RARITY_RARE, GACHA_DATA.RARITY_EPIC, GACHA_DATA.RARITY_LEGENDARY]:
		var cnt: int = int(counts.get(rar, 0))
		if cnt <= 0:
			continue
		var name: String = String(GACHA_DATA.RARITY_NAMES.get(rar, "?")).to_upper()
		if cnt >= 3:
			var mult: float = float(GACHA_DATA.COMBO_MULTIPLIERS.get(cnt, 1.0))
			lines.append("%s: %d/3 → БОНУС x%s ГОТОВ" % [name, cnt, str(mult)])
		else:
			var need: int = 3 - cnt
			lines.append("%s: %d/3 → нужно ещё %d" % [name, cnt, need])

	combo_preview_label.text = "\n".join(lines)


## Промежуточное состояние после реала (не финал).
func _show_current_state() -> void:
	var spins: Array = _session.get("spins", [])
	var failed: bool = bool(_session.get("failed", false))
	var finished: bool = bool(_session.get("finished", false))
	var next: int = int(_session.get("next_reel", 0))

	var lines: Array[String] = []
	lines.append("Текущие символы:")
	var syms: Array[String] = []
	for spin: Dictionary in spins:
		syms.append(String(GACHA_DATA.COLOR_SYMBOLS.get(int(spin["rarity"]), "?")))
	lines.append(" ".join(syms))

	if failed:
		var comp: int = int(_session.get("compensation", 0))
		lines.append("ПРОВАЛ на реале %d!" % (int(_session.get("fail_reel", -1)) + 1))
		if comp > 0:
			lines.append("Компенсация: +%d валюты" % comp)
		lines.append("Фрагменты не выданы.")
	elif finished:
		lines.append("Все реалы прокручены! Заберите награду.")

	result_label.text = "\n".join(lines)
	result_label.modulate = Color.WHITE

	# Управление кнопками.
	spin_button.visible = false
	collect_button.visible = true
	collect_button.disabled = _animating
	# При провале кнопка называется "Забрать компенсацию".
	collect_button.text = "Забрать компенсацию" if failed else "Забрать награду"
	continue_button.visible = (not finished) and (not _animating)
	if continue_button.visible:
		var gacha := get_node_or_null("/root/GachaManager")
		var meta := get_node_or_null("/root/MetaProgress")
		var cost: int = gacha.get_continue_cost(next) if gacha else -1
		continue_button.text = "Продолжить (%d)" % cost
		continue_button.disabled = (meta == null) or (not meta.can_afford(cost))


## Финальный итог (после settle). Игрок видит чётко:
## редкость (с множителем комбо), сколько фрагментов получено, и что открыто.
func _show_final_result() -> void:
	var lines: Array[String] = []

	# 1) Редкость финального результата (лучшая выпавшая) + множитель комбо.
	var final_rarity: String = String(_session.get("rarity", "common")).to_upper()
	var bonus_mult: float = 1.0
	var bonuses: Dictionary = _session.get("bonuses", {})
	if not bonuses.is_empty():
		for rar: int in bonuses:
			bonus_mult = max(bonus_mult, float(bonuses[rar]))
	if bonus_mult > 1.0:
		lines.append("%s x%s" % [final_rarity, _fmt_mult(bonus_mult)])
	else:
		lines.append(final_rarity)
	lines.append("")

	# 2) Суммарные фрагменты за попытку.
	var rewards: Dictionary = _session.get("rewards", {})
	var total_frags: int = 0
	for cid in rewards:
		total_frags += int(rewards[cid])
	if total_frags > 0:
		lines.append("+%d фрагмент(ов)" % total_frags)
	else:
		lines.append("Фрагментов не получено")
	lines.append("")

	# 3) Контент: что открыто/разблокировано (или "нет доступных открытий").
	var content_lines: Array[String] = []
	for cid in rewards:
		if cid.is_empty():
			continue
		var entry: Variant = GACHA_DATA.CONTENT.get(cid)
		var name: String = String(entry.get("display_name", cid)) if typeof(entry) == TYPE_DICTIONARY else cid
		var rarity_name: String = String(GACHA_DATA.RARITY_NAMES.get(int(entry.get("rarity", GACHA_DATA.RARITY_COMMON)), "?")) if typeof(entry) == TYPE_DICTIONARY else "?"
		content_lines.append("%s [%s]: +%d фрагмент(ов)" % [name, rarity_name.to_upper(), int(rewards[cid])])
	if content_lines.is_empty():
		lines.append("Контент:")
		lines.append("нет доступных открытий")
	else:
		lines.append("Открыто:")
		lines.append_array(content_lines)

	# Компенсация (при провале — отдельный случай; тут только информативно).
	var comp: int = int(_session.get("compensation", 0))
	if comp > 0 and not bool(_session.get("failed", false)):
		lines.append("")
		lines.append("Компенсация: +%d валюты" % comp)

	result_label.text = "\n".join(lines)
	result_label.modulate = Color.WHITE


## Форматирует множитель комбо (2.0 -> "2", 3.0 -> "3", 5.0 -> "5").
func _fmt_mult(mult: float) -> String:
	if mult == int(mult):
		return str(int(mult))
	return str(mult)


func _show_error(code: String) -> void:
	match code:
		"not_enough_currency":
			result_label.text = "Недостаточно валюты!"
			result_label.modulate = Color(1.0, 0.4, 0.4)
		_:
			result_label.text = "Ошибка: %s" % code
			result_label.modulate = Color(1.0, 0.4, 0.4)


## Сброс реалов и кнопок после завершения спина.
## Результат показывается отдельно (_show_final_result) и не стирается.
func _reset_reels() -> void:
	_revealed = 0
	_session = {}
	combo_preview_label.text = ""
	for entry: Dictionary in _reel_panels:
		var label: Label = entry["label"]
		label.text = "?"
		label.modulate = Color.WHITE

	continue_button.visible = false
	collect_button.visible = false
	spin_button.visible = true


## Полный сброс интерфейса (включая результат) — при входе на экран.
func _reset_ui() -> void:
	_reset_reels()
	result_label.text = ""
	result_label.modulate = Color.WHITE
	rules_popup.visible = false


## Восстановление незавершённой сессии из сохранения (после закрытия приложения).
## Показывает уже прокрученные реалы, превью и доступные кнопки (Продолжить / Забрать).
func _restore_session() -> void:
	var gacha := get_node_or_null("/root/GachaManager")
	if gacha == null:
		return
	var saved: Dictionary = gacha.load_session()
	if saved.is_empty():
		return

	_session = saved

	# Отрисовать уже остановленные реалы.
	_revealed = _session.get("spins", []).size()
	var spins: Array = _session.get("spins", [])
	for i in range(spins.size()):
		if i >= _reel_panels.size():
			break
		var rarity: int = int(spins[i].get("rarity", 0))
		var label: Label = _reel_panels[i]["label"]
		label.text = String(GACHA_DATA.COLOR_SYMBOLS.get(rarity, "?"))
		label.modulate = GACHA_DATA.COLOR_HEX.get(rarity, Color.WHITE)

	_update_combo_preview()
	_show_current_state()
