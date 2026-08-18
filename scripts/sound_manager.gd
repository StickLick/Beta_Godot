extends Node
## Универсальный менеджер звуковых эффектов.
## Воспроизводит звуки через общий пул плееров (UI-клики и любые эффекты).
## Громкости шин SFX/Music настраиваются в инспекторе.

@export var click_sound: AudioStream
@export var click_volume_db: float = 0.0
@export var click_pitch: float = 1.0

# Звуки игрока (очисти поле звука в инспекторе, чтобы отключить).
@export var player_hit_sound: AudioStream
@export var player_hit_volume_db: float = 0.0
@export var player_hit_pitch: float = 1.0

@export var player_death_sound: AudioStream
@export var player_death_volume_db: float = 0.0
@export var player_death_pitch: float = 1.0

@export var level_up_sound: AudioStream
@export var level_up_volume_db: float = 0.0
@export var level_up_pitch: float = 1.0

@export var xp_pickup_sound: AudioStream
@export var xp_pickup_volume_db: float = 0.0
@export var xp_pickup_pitch: float = 1.0

@export var gold_pickup_sound: AudioStream
@export var gold_pickup_volume_db: float = 0.0
@export var gold_pickup_pitch: float = 1.0

# Звуки выстрелов оружий игрока (по архетипам).
@export var shoot_bow_sound: AudioStream
@export var shoot_bow_volume_db: float = 0.0
@export var shoot_bow_pitch: float = 1.0

@export var shoot_magic_sound: AudioStream
@export var shoot_magic_volume_db: float = 0.0
@export var shoot_magic_pitch: float = 1.0

@export var shoot_heavy_sound: AudioStream
@export var shoot_heavy_volume_db: float = 0.0
@export var shoot_heavy_pitch: float = 1.0

@export var shoot_spear_sound: AudioStream
@export var shoot_spear_volume_db: float = 0.0
@export var shoot_spear_pitch: float = 1.0

@export var shoot_infantry_sound: AudioStream
@export var shoot_infantry_volume_db: float = 0.0
@export var shoot_infantry_pitch: float = 1.0

@export var shoot_lightning_sound: AudioStream
@export var shoot_lightning_volume_db: float = 0.0
@export var shoot_lightning_pitch: float = 1.0

# Звуки врагов (попадания, смерти) и взрывов.
@export var enemy_hit_sound: AudioStream
@export var enemy_hit_volume_db: float = 0.0
@export var enemy_hit_pitch: float = 1.0

@export var enemy_death_sound: AudioStream
@export var enemy_death_volume_db: float = 0.0
@export var enemy_death_pitch: float = 1.0

@export var explosion_sound: AudioStream
@export var explosion_volume_db: float = 0.0
@export var explosion_pitch: float = 1.0

# Событийные звуки мира и меты.
@export var anomaly_start_sound: AudioStream
@export var anomaly_start_volume_db: float = 0.0
@export var anomaly_start_pitch: float = 1.0

@export var anomaly_warning_sound: AudioStream
@export var anomaly_warning_volume_db: float = 0.0
@export var anomaly_warning_pitch: float = 1.0

@export var courier_sound: AudioStream
@export var courier_volume_db: float = 0.0
@export var courier_pitch: float = 1.0

@export var courier_end_sound: AudioStream
@export var courier_end_volume_db: float = 0.0
@export var courier_end_pitch: float = 1.0

@export var mine_ready_sound: AudioStream
@export var mine_ready_volume_db: float = 0.0
@export var mine_ready_pitch: float = 1.0

@export var zone_evolved_sound: AudioStream
@export var zone_evolved_volume_db: float = 0.0
@export var zone_evolved_pitch: float = 1.0

@export var war_cry_sound: AudioStream
@export var war_cry_volume_db: float = 0.0
@export var war_cry_pitch: float = 1.0

@export var victory_sound: AudioStream
@export var victory_volume_db: float = 0.0
@export var victory_pitch: float = 1.0

@export var defeat_sound: AudioStream
@export var defeat_volume_db: float = 0.0
@export var defeat_pitch: float = 1.0

# Звук шагов игрока: одиночный fallback + набор случайных вариантов.
@export var footstep_sound: AudioStream
@export var footstep_sounds: Array[AudioStream] = []
@export var footstep_volume_db: float = 0.0
@export var footstep_pitch: float = 1.0

@export var sfx_volume_db: float = 0.0
@export var music_volume_db: float = 0.0

# --- МУЗЫКА (отдельный плеер, шина Music) ---
## Главное меню. Однократный трек, зацикливается по finished.
@export var menu_music: AudioStream
## Колесо удачи / магазин / коллекция / выбор героя. Однократный трек, зацикливается.
@export var sub_menus_music: AudioStream
## Плейлист забега. Элементы играют по кругу в порядке массива.
@export var run_music_playlist: Array[AudioStream] = []

const POOL_SIZE := 16
const BUS_SFX := "SFX"
const BUS_MUSIC := "Music"
const BUS_MASTER := "Master"

var _players: Array[AudioStreamPlayer] = []

# Отдельный плеер фоновой музыки (не из пула SFX!).
var _music_player: AudioStreamPlayer
var _current_music_state: String = ""
var _playlist_index: int = 0


func _ready() -> void:
    # Гарантируем существование шин (Master уже есть по индексу 0).
    _ensure_bus(BUS_SFX)
    _ensure_bus(BUS_MUSIC)

    # Применяем громкости из инспектора.
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_SFX), sfx_volume_db)
    AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_MUSIC), music_volume_db)

    # Общий пул плееров: при быстрых вызовах звук не обрывается.
    for i in POOL_SIZE:
        var player := AudioStreamPlayer.new()
        player.name = "SFXPlayer_%02d" % (i + 1)
        player.bus = BUS_SFX
        add_child(player)
        _players.append(player)

    # Отдельный плеер музыки: шина Music, не пересекается со звуками SFX.
    _music_player = AudioStreamPlayer.new()
    _music_player.name = "MusicPlayer"
    _music_player.bus = BUS_MUSIC
    _music_player.finished.connect(_on_music_finished)
    add_child(_music_player)

    # Глобальный перехват: любой узел, добавленный в дерево, проверяется.
    get_tree().node_added.connect(_on_node_added)

    # Кнопки, созданные до подключения сигнала (например, загруженные вместе
    # с главной сценой), подхватываем отложенным проходом по всему дереву.
    call_deferred("_connect_existing_buttons")


func _ensure_bus(bus_name: String) -> void:
    if AudioServer.get_bus_index(bus_name) != -1:
        return
    AudioServer.add_bus(AudioServer.bus_count)
    var idx := AudioServer.bus_count - 1
    AudioServer.set_bus_name(idx, bus_name)
    AudioServer.set_bus_send(idx, BUS_MASTER)


## Воспроизводит любой звук через общий пул. stream == null — молча.
func play(stream: AudioStream, volume_db: float = 0.0, pitch: float = 1.0) -> void:
    if stream == null:
        return

    # Берём первый свободный (не играющий) плеер из пула.
    for player in _players:
        if not player.playing:
            player.stream = stream
            player.volume_db = volume_db
            player.pitch_scale = pitch
            player.play()
            return


## Звук шага: случайный из набора footstep_sounds, иначе одиночный footstep_sound.
func play_footstep() -> void:
    var stream := footstep_sound
    if not footstep_sounds.is_empty():
        stream = footstep_sounds[randi() % footstep_sounds.size()]
    play(stream, footstep_volume_db, footstep_pitch * randf_range(0.95, 1.05))


func _connect_existing_buttons() -> void:
    for node in get_tree().root.find_children("*", "Button", true, false):
        _connect_button(node)


func _connect_button(node: Node) -> void:
    if node is Button and not node.pressed.is_connected(_play_click):
        node.pressed.connect(_play_click)


func _on_node_added(node: Node) -> void:
    _connect_button(node)


func _play_click() -> void:
    play(click_sound, click_volume_db, click_pitch)


# --- ФОНОВАЯ МУЗЫКА ---

## Переключает состояние фоновой музыки.
## state: "menu" | "sub_menus" | "run".
## Повторный вызов того же состояния не перезапускает трек.
func set_music_state(state: String) -> void:
    if state == _current_music_state:
        return
    _current_music_state = state
    _music_player.stop()
    _playlist_index = 0
    _start_music()


## Запускает музыку для текущего состояния.
func _start_music() -> void:
    var stream: AudioStream = null
    match _current_music_state:
        "menu":
            stream = menu_music
        "sub_menus":
            stream = sub_menus_music
        "run":
            if not run_music_playlist.is_empty():
                stream = run_music_playlist[_playlist_index % run_music_playlist.size()]
            # Пустой плейлист -> тишина.
    if stream == null:
        # Тишина: без ошибок, просто молчим.
        return
    _music_player.stream = stream
    _music_player.play()


## Обработка окончания текущего трека.
func _on_music_finished() -> void:
    match _current_music_state:
        "run":
            if run_music_playlist.is_empty():
                return
            _playlist_index = (_playlist_index + 1) % run_music_playlist.size()
            _start_music()
        "menu", "sub_menus":
            var stream: AudioStream = menu_music
            if _current_music_state == "sub_menus":
                stream = sub_menus_music
            if stream != null:
                # Зацикливаем трек.
                _music_player.stream = stream
                _music_player.play()
