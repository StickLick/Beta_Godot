extends VBoxContainer
class_name EvolutionCollectionView
## EvolutionCollectionView — самостоятельное представление вкладки «Эволюции» в CollectionScreen.
## Формат (аналогичен вкладке «Оружие»): симметричная сетка 2 колонки,
## карточки фиксированного размера с иконкой 32x32, названием, статусом
## и условиями эволюции (оружие + пассивка).

## Пути к эволюциям (ресурсы Upgrade) — тот же список, что в collection_screen.gd.
const EVOLUTION_PATHS: Array[String] = [
    "res://Upgrades/Evolutions/SpearEvolution.tres",
    "res://Upgrades/Evolutions/AuraEvolution.tres",
    "res://Upgrades/Evolutions/BowSiegeEvolution.tres",
    "res://Upgrades/Evolutions/BowSkyEvolution.tres",
    "res://Upgrades/Evolutions/BowSpectralEvolution.tres",
    "res://Upgrades/Evolutions/BannerEvolution.tres",
    "res://Upgrades/Evolutions/BannerArcherEvolution.tres",
    "res://Upgrades/Evolutions/BannerGrandMarshalEvolution.tres",
    "res://Upgrades/Evolutions/BannerIronBulwarkEvolution.tres",
    "res://Upgrades/Evolutions/StaffLightningEvolution.tres",
    "res://Upgrades/Evolutions/StaffSingularityEvolution.tres",
    "res://Upgrades/Evolutions/StaffStarEvolution.tres",
]

## Иконки эволюций: представительные ресурсы семейств улучшений (тот же источник, что в collection_screen.gd).
const EVOLUTION_ICON_PATHS: Dictionary = {
    "SpearEvolution.tres": "res://Upgrades/Spear_Evolved/EvoSpear_DMG_C.tres",
    "AuraEvolution.tres": "res://Upgrades/Aura_Evolved/EvoAura_DMG_C.tres",
    "BowSiegeEvolution.tres": "res://Upgrades/Weapons/SiegeCrossbow/SiegeDMG_C.tres",
    "BowSkyEvolution.tres": "res://Upgrades/Weapons/SkyPiercer/SkyDMG_C.tres",
    "BowSpectralEvolution.tres": "res://Upgrades/Weapons/SpectralVolley/SpectralDMG_C.tres",
    "BannerEvolution.tres": "res://Upgrades/Weapons/Banner/BannerDMG_C.tres",
    "BannerArcherEvolution.tres": "res://Upgrades/Weapons/BannerArcher/ArcherDmg_C.tres",
    "BannerGrandMarshalEvolution.tres": "res://Upgrades/Weapons/BannerMarshal/MarshalDmg_C.tres",
    "BannerIronBulwarkEvolution.tres": "res://Upgrades/Weapons/BannerTank/TankDmg_C.tres",
    "StaffLightningEvolution.tres": "res://Upgrades/Weapons/LightningStaff/LtngDMG_C.tres",
    "StaffSingularityEvolution.tres": "res://Upgrades/Weapons/SingularityStaff/SingDMG_C.tres",
    "StaffStarEvolution.tres": "res://Upgrades/Weapons/StarStaff/StarDMG_C.tres",
}

## Русские имена тегов оружий (требования эволюций).
const WEAPON_TAG_NAMES: Dictionary = {
    "Spear": "Копьё",
    "Aura": "Аура",
    "Bow": "Лук",
    "Staff": "Посох",
    "Banner": "Знамя",
}

## Русские имена тегов пассивок (требования эволюций).
const PASSIVE_TAG_NAMES: Dictionary = {
    "AttackRange": "Радиус атаки",
    "ProjectileAmount": "Количество",
    "MaxHP": "Максимальное здоровье",
    "CritChance": "Критический шанс",
    "Speed": "Скорость передвижения",
    "Damage": "Урон",
}

# ── Палитра (та же, что во вкладке «Оружие») ──
const ACCENT_COLOR := Color(1, 0.85, 0.4, 1)
const MUTED_TEXT_COLOR := Color(0.62, 0.62, 0.68, 1.0)
const GREEN_OK := Color(0.29, 0.72, 0.39, 1.0)
const LOCKED_DIM := Color(0.72, 0.72, 0.78, 1.0)

# ── Размеры иконок (строго 32x32, без растяжки пиксель-арта) ──
const ICON_SIZE := Vector2(32, 32)

# ── Цвета карточек (полупрозрачные, те же, что в коллекции) ──
const CARD_BG := Color(0.1, 0.1, 0.16, 0.55)
const CARD_BG_LOCKED := Color(0.07, 0.07, 0.1, 0.85)
const CARD_BORDER := Color(0.22, 0.22, 0.32, 1)
const CARD_BORDER_LOCKED := Color(0.16, 0.16, 0.24, 1)

# ── Жёсткий размер карточек — выше, чем в «Оружии» (123), чтобы название
# ── и требования эволюции (до 2 строк с переносом) помещались без обрезки. ──
const CARD_HEIGHT := 145

# ── Узлы сцены ──
@onready var grid: GridContainer = %EvolutionGrid

## Локальное состояние выбранной эволюции.
var _selected_index: int = 0
var _cards: Array[Control] = []


func _ready() -> void:
    _build_cards()
    _refresh_view()


# ── Построение сетки карточек ──

func _build_cards() -> void:
    for i in EVOLUTION_PATHS.size():
        var path: String = EVOLUTION_PATHS[i]
        var up: Upgrade = load(path) as Upgrade
        if up == null:
            continue

        var card := PanelContainer.new()
        # Жёсткий фиксированный размер — открытые и заблокированные карточки одинаковой высоты.
        card.custom_minimum_size = Vector2(0, CARD_HEIGHT)
        card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        card.size_flags_vertical = Control.SIZE_SHRINK_CENTER

        var vbox := VBoxContainer.new()
        vbox.name = "VBox"
        vbox.add_theme_constant_override("separation", 3)
        vbox.alignment = BoxContainer.ALIGNMENT_CENTER
        vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        card.add_child(vbox)

        # Иконка 32x32 строго в оригинальном размере (KEEP_CENTERED).
        var icon_rect := TextureRect.new()
        icon_rect.name = "EvoIcon"
        icon_rect.custom_minimum_size = ICON_SIZE
        icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
        icon_rect.texture = _load_evo_icon(path, up)
        icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        vbox.add_child(icon_rect)

        # Название — до 2 строк с переносом.
        var name_label := Label.new()
        name_label.name = "NameLabel"
        name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        name_label.add_theme_font_size_override("font_size", 14)
        name_label.add_theme_color_override("font_color", ACCENT_COLOR)
        name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        vbox.add_child(name_label)

        # Статус (✔ Разблокировано / 🔒 Скрыто).
        var status_label := Label.new()
        status_label.name = "StatusLabel"
        status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        status_label.add_theme_font_size_override("font_size", 12)
        status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        vbox.add_child(status_label)

        # Требования (оружие + пассивка) — до 2 строк с переносом.
        var req_label := Label.new()
        req_label.name = "ReqLabel"
        req_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        req_label.add_theme_font_size_override("font_size", 11)
        req_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
        req_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        req_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        vbox.add_child(req_label)

        card.gui_input.connect(_on_card_gui_input.bind(i))
        card.set_meta("evo_path", path)
        card.set_meta("index", i)

        grid.add_child(card)
        _cards.append(card)


func _load_evo_icon(path: String, up: Upgrade) -> Texture2D:
    var fname: String = path.get_file()
    var upg_path: String = String(EVOLUTION_ICON_PATHS.get(fname, ""))
    if upg_path != "":
        var upg := load(upg_path) as Upgrade
        if upg != null and upg.icon != null:
            return upg.icon
    return up.icon


func _on_card_gui_input(event: InputEvent, index: int) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _selected_index = index
        _refresh_view()


# ── Данные эволюций ──

func _get_upgrade(path: String) -> Upgrade:
    return load(path) as Upgrade


func _is_unlocked(path: String, meta: Node) -> bool:
    var up := _get_upgrade(path)
    if up == null:
        return false
    var evo_name: String = up.name if up.name != "" else path.get_file().get_basename()
    return meta != null and meta.is_evolution_unlocked(evo_name)


## Текст требований: «Требуется: <Оружие> + <Пассивка>».
func _get_req_text(path: String, unlocked: bool) -> String:
    var up := _get_upgrade(path)
    if up == null:
        return ""
    if not unlocked:
        return "????"
    var req_parts: Array[String] = []
    var w_name: String = WEAPON_TAG_NAMES.get(up.weapon_tag, up.weapon_tag)
    if w_name != "" and w_name != "General":
        req_parts.append(w_name)
    if up.required_passive_tag != "":
        var p_name: String = PASSIVE_TAG_NAMES.get(up.required_passive_tag, up.required_passive_tag)
        req_parts.append(p_name)
    if req_parts.is_empty():
        return ""
    return "Требуется: %s" % " + ".join(req_parts)


# ── Обновление представления ──

func _refresh_view() -> void:
    var meta := get_node_or_null("/root/MetaProgress")
    _refresh_cards(meta)


## Обновляет карточки: открытые — ✔ Разблокировано + требования,
## заблокированные — 🔒 Скрыто + «????».
func _refresh_cards(meta: Node) -> void:
    for i in _cards.size():
        var card := _cards[i] as PanelContainer
        var path: String = String(card.get_meta("evo_path"))
        var up := _get_upgrade(path)
        if up == null:
            continue
        var unlocked: bool = _is_unlocked(path, meta)
        var active: bool = i == _selected_index

        card.add_theme_stylebox_override("panel", _make_card_style(active, unlocked))
        card.modulate = Color.WHITE if unlocked else LOCKED_DIM

        var icon_rect := card.get_node_or_null("VBox/EvoIcon") as TextureRect
        if icon_rect:
            icon_rect.modulate = Color.WHITE if unlocked else LOCKED_DIM

        var name_label := card.get_node_or_null("VBox/NameLabel") as Label
        if name_label:
            name_label.text = up.display_name if up.display_name != "" else up.name

        var status_label := card.get_node_or_null("VBox/StatusLabel") as Label
        var req_label := card.get_node_or_null("VBox/ReqLabel") as Label
        if status_label == null or req_label == null:
            continue

        if unlocked:
            status_label.text = "✔ Разблокировано"
            status_label.add_theme_color_override("font_color", GREEN_OK)
            status_label.add_theme_font_size_override("font_size", 12)
            req_label.text = _get_req_text(path, true)
        else:
            status_label.text = "🔒 Скрыто"
            status_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
            status_label.add_theme_font_size_override("font_size", 12)
            req_label.text = _get_req_text(path, false)


## Стиль карточки: активная (выбранная) — золотая рамка 2px,
## неактивная — серая рамка 1px. Заблокированные — тёмный фон.
func _make_card_style(active: bool, unlocked: bool) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = CARD_BG if unlocked else CARD_BG_LOCKED
    if active:
        sb.border_color = ACCENT_COLOR
        sb.set_border_width_all(2)
    else:
        sb.border_color = CARD_BORDER if unlocked else CARD_BORDER_LOCKED
        sb.set_border_width_all(1)
    sb.set_corner_radius_all(8)
    sb.content_margin_left = 8
    sb.content_margin_top = 8
    sb.content_margin_right = 8
    sb.content_margin_bottom = 8
    return sb