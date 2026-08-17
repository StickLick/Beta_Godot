extends Control
## CollectionScreen — экран коллекции в стиле Hero Selection.
## Вкладки: Герои / Оружие / Пассивки / Эволюции.
## Одновременно отображается только один активный раздел.
## Источники данных: hero_data.gd (имена/стартовое оружие/бонусы) и
## gacha_data.CONTENT (оружия/пассивки). Только отображение — логика открытия
## и системы гачи/сохранения не меняются.

const HERO_DATA := preload("res://scripts/hero_data.gd")
const GACHA_DATA := preload("res://scripts/gacha_data.gd")

## Идентификаторы разделов коллекции.
const SECTION_HEROES: String = "heroes"
const SECTION_WEAPONS: String = "weapons"
const SECTION_PASSIVES: String = "passives"
const SECTION_EVOLUTIONS: String = "evolutions"

## Пути к эволюциям (ресурсы Upgrade). Все эволюции всегда видны в коллекции.
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

## Стартовая пассивка «Урон» — всегда открыта в коллекции.
const STARTING_PASSIVE_ID: String = "passive_damage"

## Русские имена тегов оружий (тот же источник ид, что у hero_data.weapon_tag).
const WEAPON_TAG_NAMES: Dictionary = {
    "Spear": "Копьё",
    "Aura": "Аура",
    "Bow": "Лук",
    "Staff": "Посох",
    "Banner": "Знамя",
}

## Русские имена тегов пассивок.
const PASSIVE_TAG_NAMES: Dictionary = {
    "AttackRange": "Радиус атаки",
    "ProjectileAmount": "Количество",
    "MaxHP": "Максимальное здоровье",
    "CritChance": "Критический шанс",
    "Speed": "Скорость передвижения",
    "Damage": "Урон",
    "Luck": "Удача",
    "HealthRegen": "Регенерация здоровья",
    "AttackSpeed": "Скорость атаки",
    "MoveSpeed": "Скорость передвижения",
    "ExperienceGain": "Опыт",
    "GoldGain": "Золото",
}

# ── Палитра (та же, что в HeroSelectScreen) ──
const ACCENT_COLOR := Color(1, 0.85, 0.4, 1)
const CARD_BG := Color(0.1, 0.1, 0.16, 1.0)
const CARD_BG_LOCKED := Color(0.07, 0.07, 0.1, 1.0)
const BORDER_NORMAL := Color(0.22, 0.22, 0.32, 1.0)
const BORDER_LOCKED := Color(0.16, 0.16, 0.24, 1.0)
const LOCKED_TEXT_COLOR := Color(0.62, 0.62, 0.68, 1.0)
const SECTION_COLOR := Color(1, 0.85, 0.4, 1)

# ── Визуальные стили (настраиваются в Inspector) ──
## Стиль карточки героя (крупные карточки). StyleBoxTexture/StyleBoxFlat.
@export var hero_card_style: StyleBox = null
## Стиль карточки оружия/пассивки/эволюции (2-колоночная сетка). StyleBoxTexture/StyleBoxFlat.
@export var weapon_card_style: StyleBox = null
## Стиль заблокированной карточки. Если не задан — используется weapon_card_style.
@export var locked_card_style: StyleBox = null
## Стиль заголовка секции («ГЕРОИ», «ОРУЖИЕ», …). Назначьте поверх Label.
@export var section_style: StyleBox = null

@export_group("Card Flat Style")
## Радиус скругления углов карточек. Настраивается в Inspector сцены MainMenu.tscn.
@export var card_corner_radius: int = 8
## Фон разблокированной карточки.
@export var card_bg_color: Color = Color(0.08, 0.1, 0.16, 0.85)
## Фон заблокированной карточки.
@export var card_locked_bg_color: Color = Color(0.07, 0.07, 0.1, 0.85)
## Цвет рамки разблокированной карточки.
@export var card_border_color: Color = Color(0.22, 0.22, 0.32, 1.0)
## Цвет рамки заблокированной карточки.
@export var card_locked_border_color: Color = Color(0.16, 0.16, 0.24, 1.0)
## Толщина рамки карточек.
@export var card_border_width: int = 1

@export_group("Card Icons")
## Размер иконки слева от текста в карточке коллекции (оружия/пассивки/эволюции).
@export var card_icon_size: Vector2 = Vector2(40, 40)
## Размер иконки героя (крупнее остальных).
@export var hero_icon_size: Vector2 = Vector2(56, 56)

@export_group("Card Layout")
## Минимальная высота карточек в 2-колоночной сетке (оружия/пассивки/эволюции).
@export var card_grid_min_height: int = 90
## Отступ между строками 2-колоночной сетки.
@export var card_row_spacing: int = 8
## Отступ между карточками героев.
@export var card_hero_spacing: int = 8
## Отступ перед заголовком секции (кроме первой).
@export var card_section_spacing: int = 18
## Горизонтальный отступ внутри карточки (слева/справа).
@export var card_pad_h: int = 8
## Вертикальный отступ внутри карточки (сверху/снизу).
@export var card_pad_v: int = 8

# ── Иконки героев: те же портреты, что в экране выбора героя (HeroSelectScreen). ──
const HERO_ICON_PATHS: Dictionary = {
    "hero_spearman": "res://Texture/Tiny Swords (Free Pack)/UI Elements/UI Elements/Human Avatars/Avatars_Lancer.png",
    "hero_archer": "res://Texture/Tiny Swords (Free Pack)/UI Elements/UI Elements/Human Avatars/Avatars_Archer.png",
    "hero_monk": "res://Texture/Tiny Swords (Free Pack)/UI Elements/UI Elements/Human Avatars/Avatars_Monk.png",
}

# ── Иконки оружий: из базовых ресурсов Upgrade (поле icon). ──
const WEAPON_ICON_PATHS: Dictionary = {
    "weapon_aura": "res://Upgrades/Weapons/Aura/BaseAura.tres",
    "weapon_bow": "res://Upgrades/Weapons/Bow/BaseBow.tres",
    "weapon_staff": "res://Upgrades/Weapons/Staff/BaseStaff.tres",
    "weapon_banner": "res://Upgrades/Weapons/Banner/BaseBanner.tres",
}

# ── Иконки пассивок: из ресурсов Upgrade (поле icon). ──
const PASSIVE_ICON_PATHS: Dictionary = {
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

# ── Иконки эволюций: из представительных ресурсов семейств улучшений эволюций. ──
## В Upgrades/Evolutions/*.tres у всех эволюций один и тот же icon (Icon_12.png),
## поэтому иконка берётся из ресурса улучшения соответствующей эволюции,
## где у каждой семьи своя уникальная текстура. Ключ = имя .tres файла эволюции.
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

var cards_container: VBoxContainer
var _cards: Array[Control] = []

# Текущий активный раздел коллекции.
var current_section: String = SECTION_HEROES

# Текущая строка для 2-колоночной сетки (оружия/пассивки/эволюции).
var _current_row: HBoxContainer = null
var _row_count: int = 0


func _ready() -> void:
    cards_container = %CardsContainer as VBoxContainer
    if cards_container:
        # Центрирование контента по горизонтали (карточки по центру экрана).
        cards_container.alignment = BoxContainer.ALIGNMENT_CENTER
    _connect_tabs()
    refresh()


## Подключает кнопки вкладок к переключению разделов.
func _connect_tabs() -> void:
    var heroes_btn := get_node_or_null("OuterMargin/ModalCenter/Layout/TopPanel/TopBox/HeaderMarginPad/TabBar/HeroesButton") as Button
    var weapons_btn := get_node_or_null("OuterMargin/ModalCenter/Layout/TopPanel/TopBox/HeaderMarginPad/TabBar/WeaponsButton") as Button
    var passives_btn := get_node_or_null("OuterMargin/ModalCenter/Layout/TopPanel/TopBox/HeaderMarginPad/TabBar/PassivesButton") as Button
    var evolutions_btn := get_node_or_null("OuterMargin/ModalCenter/Layout/TopPanel/TopBox/HeaderMarginPad/TabBar/EvolutionsButton") as Button
    if heroes_btn:
        heroes_btn.pressed.connect(_on_heroes_tab_pressed)
    if weapons_btn:
        weapons_btn.pressed.connect(_on_weapons_tab_pressed)
    if passives_btn:
        passives_btn.pressed.connect(_on_passives_tab_pressed)
    if evolutions_btn:
        evolutions_btn.pressed.connect(_on_evolutions_tab_pressed)


## Обновление коллекции: перестраивает активный раздел.
## При каждом открытии коллекции (refresh вызывается из MainMenu)
## раздел сбрасывается на «Герои».
func refresh() -> void:
    var meta := get_node_or_null("/root/MetaProgress")
    if meta == null:
        return
    current_section = SECTION_HEROES
    _update_tab_states()
    _show_section()


## Переключение раздела коллекции.
## Очищает CardsContainer и строит только карточки указанного раздела.
func switch_section(section_name: String) -> void:
    if section_name == current_section:
        return
    var meta := get_node_or_null("/root/MetaProgress")
    if meta == null:
        return
    current_section = section_name
    _update_tab_states()
    _show_section()


## Собирает карточки текущего раздела.
func _show_section() -> void:
    var meta := get_node_or_null("/root/MetaProgress")
    if meta == null:
        return
    _reset_scroll()
    _clear_cards()
    match current_section:
        SECTION_HEROES:
            _build_hero_section(meta)
        SECTION_WEAPONS:
            _build_weapon_section(meta)
        SECTION_PASSIVES:
            _build_passive_section(meta)
        SECTION_EVOLUTIONS:
            _build_evolution_section(meta)


## Сбрасывает вертикальный скролл в начало при каждом переключении раздела.
func _reset_scroll() -> void:
    pass


## Обновляет визуальное состояние вкладок (активная — нажата).
func _update_tab_states() -> void:
    var tab_map: Dictionary = {
        SECTION_HEROES: "OuterMargin/ModalCenter/Layout/TopPanel/TopBox/HeaderMarginPad/TabBar/HeroesButton",
        SECTION_WEAPONS: "OuterMargin/ModalCenter/Layout/TopPanel/TopBox/HeaderMarginPad/TabBar/WeaponsButton",
        SECTION_PASSIVES: "OuterMargin/ModalCenter/Layout/TopPanel/TopBox/HeaderMarginPad/TabBar/PassivesButton",
        SECTION_EVOLUTIONS: "OuterMargin/ModalCenter/Layout/TopPanel/TopBox/HeaderMarginPad/TabBar/EvolutionsButton",
    }
    for section_name: String in tab_map:
        var btn := get_node_or_null(tab_map[section_name]) as Button
        if btn:
            btn.button_pressed = (section_name == current_section)


func _on_heroes_tab_pressed() -> void:
    switch_section(SECTION_HEROES)


func _on_weapons_tab_pressed() -> void:
    switch_section(SECTION_WEAPONS)


func _on_passives_tab_pressed() -> void:
    switch_section(SECTION_PASSIVES)


func _on_evolutions_tab_pressed() -> void:
    switch_section(SECTION_EVOLUTIONS)


func _clear_cards() -> void:
    _current_row = null
    _row_count = 0
    # Немедленное удаление (free) вместо queue_free:
    # при переключении разделов старые карточки исчезают сразу,
    # без «хвоста» из остатков предыдущего раздела в тот же кадр.
    for c in _cards:
        if is_instance_valid(c):
            c.free()
    _cards.clear()


## Добавляет вертикальный отступ в контейнер карточек.
func _add_vspacer(height: float) -> void:
    var sp := Control.new()
    sp.custom_minimum_size = Vector2(0, height)
    cards_container.add_child(sp)
    _cards.append(sp)


## Начинает новую строку для 2-колоночной сетки (растягивается на всю ширину).
func _begin_row() -> void:
    _current_row = HBoxContainer.new()
    _current_row.add_theme_constant_override("separation", 10)
    _current_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cards_container.add_child(_current_row)
    _cards.append(_current_row)
    _row_count = 0


## Добавляет карточку. Если dual_column — раскладывает по 2 в строку.
## icon — необязательная текстура слева от текста (как в меню улучшений).
func _add_item_card(unlocked: bool, name_lines: Array[String], lines: Array[String], dual_column: bool, icon: Texture2D = null, icon_override_size: Vector2 = Vector2(-1, -1)) -> void:
    var card := PanelContainer.new()
    if dual_column:
        if _current_row == null or _row_count >= 2:
            # Отступ между заполненными строками сетки.
            if _current_row != null and _row_count >= 2:
                _add_vspacer(card_row_spacing)
            _begin_row()
        card.custom_minimum_size = Vector2(0, card_grid_min_height)
        _current_row.add_child(card)
        _row_count += 1
    else:
        card.custom_minimum_size = Vector2(0, 0)
        cards_container.add_child(card)
        _cards.append(card)

    var use_icon_size: Vector2 = icon_override_size if icon_override_size.x > 0 else card_icon_size

    # Карточки занимают всю доступную ширину (сетка поровну, одиночные — по центру).
    card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.size_flags_vertical = Control.SIZE_SHRINK_CENTER

    # Вертикальный блок: имя сверху (по центру карточки), контент (иконка + описание) ниже.
    var main_vbox := VBoxContainer.new()
    main_vbox.add_theme_constant_override("separation", 4)
    main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    main_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    card.add_child(main_vbox)

    # Имя — всегда видно, по центру ВСЕЙ карточки. Длинные имена переносятся на 2 строки.
    for ln in name_lines:
        var name_label := Label.new()
        name_label.text = ln
        name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        name_label.add_theme_font_size_override("font_size", 17)
        name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        main_vbox.add_child(name_label)

    # Статус ("Разблокировано"/"🔒 Заблокировано") — сразу после названия, по центру карточки.
    if lines.size() > 0:
        var status_label := Label.new()
        status_label.name = "StatusLabel"
        status_label.text = lines[0]
        status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        status_label.add_theme_font_size_override("font_size", 13)
        status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        if unlocked:
            # Статус "Разблокировано" — золотой акцент (как заголовки секций).
            status_label.add_theme_color_override("font_color", ACCENT_COLOR)
        else:
            status_label.add_theme_color_override("font_color", LOCKED_TEXT_COLOR)
        main_vbox.add_child(status_label)

    # Горизонтальный ряд: иконка слева, описание справа (по центру ширины карточки).
    var hbox := HBoxContainer.new()
    hbox.name = "CardContent"
    hbox.add_theme_constant_override("separation", 8)
    hbox.alignment = BoxContainer.ALIGNMENT_CENTER
    hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    main_vbox.add_child(hbox)

    # Иконка слева (если задана), вертикально по центру текстового блока.
    if icon != null:
        var icon_rect := TextureRect.new()
        icon_rect.name = "CardIcon"
        icon_rect.texture = icon
        icon_rect.custom_minimum_size = use_icon_size
        icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        hbox.add_child(icon_rect)

    var vbox := VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 4)
    vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    hbox.add_child(vbox)

    # Описание (строки после статуса) — прижимается влево (как в карточках улучшений).
    for i in range(1, lines.size()):
        var ln: String = lines[i]
        var desc_label := Label.new()
        desc_label.text = ln
        desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        desc_label.add_theme_font_size_override("font_size", 13)
        desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        vbox.add_child(desc_label)

    # Визуальное состояние карточки.
    if unlocked:
        card.add_theme_stylebox_override("panel", _get_card_style(dual_column))
        card.modulate = Color.WHITE
    else:
        card.add_theme_stylebox_override("panel", _get_locked_card_style())
        card.modulate = Color(0.72, 0.72, 0.78, 1.0)

    if not dual_column:
        _cards.append(card)


## Возвращает стиль разблокированной карточки.
## Герои используют hero_card_style, оружия/пассивки/эволюции — weapon_card_style.
## Если стиль не назначен в Inspector — создаётся стандартный StyleBoxFlat (fallback).
func _get_card_style(dual_column: bool) -> StyleBox:
    var style: StyleBox = null
    if dual_column:
        style = weapon_card_style
    else:
        style = hero_card_style
    if style != null:
        return style
    return _make_default_card_style(card_bg_color, card_border_color)


## Возвращает стиль заблокированной карточки.
## Приоритет: locked_card_style → weapon_card_style → стандартный StyleBoxFlat (fallback).
func _get_locked_card_style() -> StyleBox:
    if locked_card_style != null:
        return locked_card_style
    if weapon_card_style != null:
        return weapon_card_style
    return _make_default_card_style(card_locked_bg_color, card_locked_border_color)


## Стиль прямоугольной карточки со скруглёнными углами (настраивается в Inspector).
## ВАЖНО: PanelContainer берёт внутренние отступы ИЗ CONTENT MARGINS StyleBox,
## а не из theme_override_constants/margin_*. Без этих значений VBox прилипает
## к верхней границе и правки "margin_*" не дают видимого эффекта.
func _make_default_card_style(bg: Color, border: Color) -> StyleBoxFlat:
    var sb := StyleBoxFlat.new()
    sb.bg_color = bg
    sb.border_color = border
    sb.set_border_width_all(card_border_width)
    sb.set_corner_radius_all(card_corner_radius)
    sb.content_margin_left = card_pad_h
    sb.content_margin_top = card_pad_v
    sb.content_margin_right = card_pad_h
    sb.content_margin_bottom = card_pad_v
    return sb


## Загружает иконку из пути к ресурсу Upgrade (поле icon). null — если не удалось.
func _load_upgrade_icon(path: String) -> Texture2D:
    if path == "":
        return null
    var up := load(path) as Upgrade
    if up == null:
        return null
    return up.icon


## Возвращает иконку героя по hero_id (те же портреты, что в выборе героя). null — если нет.
func _get_hero_icon(hero_id: String) -> Texture2D:
    var path: String = String(HERO_ICON_PATHS.get(hero_id, ""))
    if path == "":
        return null
    return load(path) as Texture2D


## Возвращает иконку по content_id (оружие/пассивка). null — если нет.
func _get_content_icon(content_id: String) -> Texture2D:
    var path: String = String(WEAPON_ICON_PATHS.get(content_id, PASSIVE_ICON_PATHS.get(content_id, "")))
    if path == "":
        return null
    return _load_upgrade_icon(path)


## Возвращает иконку эволюции по res:// пути её .tres файла.
## Иконка берётся из представительного ресурса семейства улучшений эволюции,
## так как в Upgrades/Evolutions/*.tres у всех эволюций один и тот же icon.
## null — если путь не найден в таблице или иконка не загрузилась.
func _get_evolution_icon(evo_path: String) -> Texture2D:
    var fname: String = evo_path.get_file()
    var upg_path: String = String(EVOLUTION_ICON_PATHS.get(fname, ""))
    if upg_path == "":
        return null
    return _load_upgrade_icon(upg_path)


# ── ГЕРОИ (отдельный компонент HeroCollectionView) ──

const HERO_COLLECTION_VIEW_SCENE: String = "res://Assets/Scenes/UI/HeroCollectionView.tscn"

func _build_hero_section(meta: Node) -> void:
    # Инстанцируем самостоятельное представление вкладки «Герои».
    # HeroCollectionView сам читает GameManager.selected_hero_id (только чтение),
    # строит мини-карточки и обрабатывает навигацию стрелками/кликами.
    var view_scene := load(HERO_COLLECTION_VIEW_SCENE) as PackedScene
    if view_scene == null:
        return
    var view := view_scene.instantiate() as Control
    cards_container.add_child(view)
    _cards.append(view)


# ── ОРУЖИЯ (отдельный компонент WeaponCollectionView) ──

const WEAPON_COLLECTION_VIEW_SCENE: String = "res://Assets/Scenes/UI/WeaponCollectionView.tscn"

func _build_weapon_section(meta: Node) -> void:
    # Инстанцируем самостоятельное представление вкладки «Оружие».
    # WeaponCollectionView сам читает MetaProgress (только чтение),
    # строит мини-карточки и обрабатывает навигацию стрелками/кликами.
    var view_scene := load(WEAPON_COLLECTION_VIEW_SCENE) as PackedScene
    if view_scene == null:
        return
    var view := view_scene.instantiate() as Control
    cards_container.add_child(view)
    _cards.append(view)


# ── ПАССИВКИ (отдельный компонент PassiveCollectionView) ──

const PASSIVE_COLLECTION_VIEW_SCENE: String = "res://Assets/Scenes/UI/PassiveCollectionView.tscn"

func _build_passive_section(meta: Node) -> void:
    # Инстанцируем самостоятельное представление вкладки «Пассивки».
    # PassiveCollectionView сам читает MetaProgress (только чтение),
    # строит мини-карточки и обрабатывает навигацию кликами.
    var view_scene := load(PASSIVE_COLLECTION_VIEW_SCENE) as PackedScene
    if view_scene == null:
        return
    var view := view_scene.instantiate() as Control
    cards_container.add_child(view)
    _cards.append(view)


# ── ЭВОЛЮЦИИ (отдельный компонент EvolutionCollectionView) ──

const EVOLUTION_COLLECTION_VIEW_SCENE: String = "res://Assets/Scenes/UI/EvolutionCollectionView.tscn"

func _build_evolution_section(meta: Node) -> void:
    # Инстанцируем самостоятельное представление вкладки «Эволюции».
    # EvolutionCollectionView сам читает MetaProgress (только чтение),
    # строит мини-карточки и обрабатывает навигацию кликами.
    var view_scene := load(EVOLUTION_COLLECTION_VIEW_SCENE) as PackedScene
    if view_scene == null:
        return
    var view := view_scene.instantiate() as Control
    cards_container.add_child(view)
    _cards.append(view)


func _on_close_pressed() -> void:
    hide()
