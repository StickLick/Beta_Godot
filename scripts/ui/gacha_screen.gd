extends Control
## GachaScreen — UI слот-машины фрагментов.
## Поток: первый спин всегда платный → после каждого реала "Забрать" или "Продолжить".
## Логика (шансы, комбо, компенсация) — полностью в GachaManager.
## Фрагменты выдаются только при финальном результате; экран коллекции отвечает за разблокировки.

const GACHA_DATA := preload("res://scripts/gacha_data.gd")
const REEL_COUNT: int = GACHA_DATA.REEL_COUNT

# Иконка фрагмента для блока "Открыто:" (резервная, если контент не имеет своей иконки).
const FRAGMENT_ICON: String = "res://Texture/Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_04.png"

# Пути к иконкам контента (те же, что в коллекции collection_screen.gd).
# Герои — прямые PNG; оружия/пассивки — ресурсы Upgrade, из которых берётся поле icon.
const CONTENT_ICON_PATHS: Dictionary = {
    # --- ГЕРОИ ---
    "hero_archer": "res://Texture/Tiny Swords (Free Pack)/UI Elements/UI Elements/Human Avatars/Avatars_Archer.png",
    "hero_monk": "res://Texture/Tiny Swords (Free Pack)/UI Elements/UI Elements/Human Avatars/Avatars_Monk.png",
    # --- ОРУЖИЯ ---
    "weapon_aura": "res://Upgrades/Weapons/Aura/BaseAura.tres",
    "weapon_bow": "res://Upgrades/Weapons/Bow/BaseBow.tres",
    "weapon_staff": "res://Upgrades/Weapons/Staff/BaseStaff.tres",
    "weapon_banner": "res://Upgrades/Weapons/Banner/BaseBanner.tres",
    # --- ПАССИВКИ ---
    "passive_damage": "res://Upgrades/Passives/Damage_C.tres",
    "passive_max_hp": "res://Upgrades/Passives/Stone_HP_C.tres",
    "passive_hp_regen": "res://Upgrades/Passives/HPRegen_C.tres",
    "passive_attack_speed": "res://Upgrades/Passives/AttackSpeed_C.tres",
    "passive_move_speed": "res://Upgrades/Passives/Speed_C.tres",
    "passive_attack_range": "res://Upgrades/Passives/Book_RAD_C.tres",
    "passive_amount": "res://Upgrades/Passives/Amount/Amount_C.tres",
    "passive_crit_chance": "res://Upgrades/Passives/CritChance_C.tres",
    "passive_luck": "res://Upgrades/Passives/Luck_C.tres",
    "passive_experience": "res://Upgrades/Passives/ExperienceGain_C.tres",
    "passive_gold": "res://Upgrades/Passives/GoldGain_C.tres",
}

@onready var currency_label: Label = %CurrencyLabel
@onready var result_label: RichTextLabel = %ResultLabel
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
        var display_name: String = String(GACHA_DATA.COLOR_DISPLAY_NAMES.get(rar, "?"))
        lines.append("%s %s — %d фрагмент(ов)" % [sym, display_name, GACHA_DATA.COLOR_FRAGMENTS[rar]])
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
    currency_label.text = "%d" % gm.get_meta_currency()
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
    # Собираем текст кружков ДО _reset_reels (который очищает _session).
    var color_counts_text: String = "" if was_failed else _build_color_counts_text()
    _session = gacha.settle_spin(_session)
    if was_failed:
        # Компенсация выдана: информация о предыдущей попытке исчезает.
        result_label.text = ""
    else:
        _show_final_result()
    _reset_reels()
    # Строка собранных кружков остаётся под барабанами (после очистки в _reset_reels).
    # При провале кружки не показываем — combo_preview_label остаётся пустым.
    combo_preview_label.text = color_counts_text
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
        var sym: String = String(GACHA_DATA.COLOR_SYMBOLS.get(rar, "?"))
        if cnt >= 3 and GACHA_DATA.COMBO_MULTIPLIERS.has(cnt):
            var mult: float = float(GACHA_DATA.COMBO_MULTIPLIERS[cnt])
            lines.append("%s %d/3 ×%s" % [sym, cnt, _fmt_mult(mult)])
        else:
            lines.append("%s %d/3" % [sym, cnt])

    combo_preview_label.text = "\n".join(lines)


## Промежуточное состояние после реала (не финал).
func _show_current_state() -> void:
    var failed: bool = bool(_session.get("failed", false))
    var finished: bool = bool(_session.get("finished", false))
    var next: int = int(_session.get("next_reel", 0))

    var lines: Array[String] = []

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


## Возвращает путь к ресурсу иконки контента по content_id.
## Оружия/пассивки — ресурсы Upgrade (поле icon), герои — прямые PNG.
## Пустая строка, если иконки нет.
func _get_content_icon_path(content_id: String) -> String:
    return String(CONTENT_ICON_PATHS.get(content_id, ""))


## Возвращает путь к ЗАГРУЖАЕМОЙ текстуре иконки контента для [img].
## Если путь ведёт на Upgrade .tres — берётся resource_path его поля icon.
## Если иконки нет — резервный FRAGMENT_ICON.
func _get_content_icon_image_path(content_id: String) -> String:
    var path: String = _get_content_icon_path(content_id)
    if path == "":
        return FRAGMENT_ICON
    var res := load(path)
    if res is Texture2D:
        return path
    if res != null and "icon" in res and res.get("icon") != null:
        var tex: Texture2D = res.get("icon")
        if tex != null and tex.resource_path != "":
            return tex.resource_path
    return FRAGMENT_ICON


## Строит строку собранных кружков по цветам: «⚪ x2   🔵 x1»
## (символы из COLOR_SYMBOLS, счётчик из _session["color_counts"], порядок от COMMON к LEGENDARY).
func _build_color_counts_text() -> String:
    var counts: Dictionary = _session.get("color_counts", {})
    var parts: Array[String] = []
    for rar in [GACHA_DATA.RARITY_COMMON, GACHA_DATA.RARITY_RARE, GACHA_DATA.RARITY_EPIC, GACHA_DATA.RARITY_LEGENDARY]:
        var cnt: int = int(counts.get(rar, 0))
        if cnt <= 0:
            continue
        var sym: String = String(GACHA_DATA.COLOR_SYMBOLS.get(rar, "?"))
        parts.append("%s x%d" % [sym, cnt])
    if parts.is_empty():
        return ""
    return "   ".join(parts)


## Финальный итог (после settle). Игрок видит чётко:
## сколько фрагментов получено (СОБРАНО) и что открыто (ОТКРЫТО).
## Две смысловые части разделены заголовками и строкой-разделителем.
func _show_final_result() -> void:
    var lines: Array[String] = []
    var rewards: Dictionary = _session.get("rewards", {})

    # Часть 1: СОБРАНО — суммарные фрагменты за попытку.
    var total_frags: int = 0
    for cid in rewards:
        total_frags += int(rewards[cid])
    var gold: String = Color(1.0, 0.85, 0.4).to_html(false)
    var dim: String = "555a66"
    var has_collected: bool = total_frags > 0
    if has_collected:
        lines.append("[color=%s]СОБРАНО:[/color]" % gold)
        lines.append("[font_size=20]+%d фрагмент(ов)[/font_size]" % total_frags)
        lines.append("[color=%s]%s[/color]" % [dim, "─".repeat(20)])
        lines.append("")
    else:
        lines.append("Фрагментов не получено")

    # Часть 2: ОТКРЫТО — что открыто/разблокировано.
    var content_lines: Array[String] = []
    for cid in rewards:
        if cid.is_empty():
            continue
        var entry: Variant = GACHA_DATA.CONTENT.get(cid)
        var display_name: String = String(entry.get("display_name", cid)) if typeof(entry) == TYPE_DICTIONARY else cid
        content_lines.append("[img=22x22]%s[/img] %s: +%d фрагмент(ов)" % [_get_content_icon_image_path(cid), display_name, int(rewards[cid])])
    if not content_lines.is_empty():
        lines.append("[color=%s]ОТКРЫТО:[/color]" % gold)
        lines.append_array(content_lines)
    else:
        lines.append("нет доступных открытий")

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
