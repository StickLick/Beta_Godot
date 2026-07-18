extends Node

# Сигналы для системы аномалий
signal anomaly_started(type: String, duration: float)
signal anomaly_ended()

# Метрики для экрана итогов
var total_xp_collected: int = 0
var rival_camps_destroyed: int = 0
var units_spawned: int = 0
var zones_captured: int = 0
var time_elapsed: float = 0.0

var is_game_over: bool = false
var map_rect: Rect2 = Rect2(-2000, -2000, 4000, 4000)

# Логика аномалий
var _anomaly_timer: float = 0.0
const ANOMALY_INTERVAL: float = 180.0 # Каждые 3 минуты
const ANOMALY_DURATION: float = 30.0
var current_anomaly: String = ""

func _ready() -> void:
    # Инициализация мета-данных для других скриптов
    set_meta("prod_mult", 1.0)
    set_meta("scarcity_active", false)
    set_meta("map_rect", map_rect)

func _process(delta: float) -> void:
    if not is_game_over:
        time_elapsed += delta
        _process_anomalies(delta)

func _process_anomalies(delta: float) -> void:
    _anomaly_timer += delta
    if _anomaly_timer >= ANOMALY_INTERVAL:
        _anomaly_timer = 0.0
        trigger_anomaly()

func trigger_anomaly() -> void:
    var types = ["OVERDRIVE", "SCARCITY", "PRESSURE_WAVE"]
    current_anomaly = types.pick_random()
    
    match current_anomaly:
        "OVERDRIVE":
            set_meta("prod_mult", 0.4) # Ускорение производства на 60%
        "SCARCITY":
            set_meta("scarcity_active", true)
        "PRESSURE_WAVE":
            # Повышаем давление через менеджер, если он есть
            var pm = get_tree().root.find_child("PressureManager", true, false)
            if pm: pm.current_pressure_level += 2.0
    
    # Испускаем сигнал для HUD
    anomaly_started.emit(current_anomaly, ANOMALY_DURATION)
    
    # Таймер завершения аномалии
    get_tree().create_timer(ANOMALY_DURATION).timeout.connect(_end_anomaly)
    print("[SYSTEM] ANOMALY TRIGGERED: ", current_anomaly)

func _end_anomaly() -> void:
    set_meta("prod_mult", 1.0)
    set_meta("scarcity_active", false)
    current_anomaly = ""
    anomaly_ended.emit()
    print("[SYSTEM] ANOMALY ENDED")

func log_event(type: String, value: Variant = 1) -> void:
    match type:
        "xp": total_xp_collected += int(value)
        "camp_destroyed": rival_camps_destroyed += int(value)
        "unit_spawned": units_spawned += int(value)
        "zone_captured": zones_captured += int(value)

func stop_game() -> void:
    is_game_over = true

func reset_game() -> void:
    total_xp_collected = 0
    rival_camps_destroyed = 0
    units_spawned = 0
    zones_captured = 0
    time_elapsed = 0.0
    is_game_over = false
    set_meta("prod_mult", 1.0)
    set_meta("scarcity_active", false)

# Вспомогательный метод для HUD
func get_time_formatted() -> String:
    var total_minutes: int = int(time_elapsed / 60.0)
    var seconds: int = int(fmod(time_elapsed, 60.0))
    return "%02d:%02d" % [total_minutes, seconds]
