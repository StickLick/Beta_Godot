class_name WarBannerGrandMarshal
extends WarBanner

const MARSHAL_MAX_UNITS: int = 4
const MARSHAL_DAMAGE_MULT: float = 1.5
const MARSHAL_DURATION: float = 7.0
const MARSHAL_CRY_INTERVAL: float = 7.0


func _ready() -> void:
    max_banner_units = MARSHAL_MAX_UNITS
    inspired_damage_mult = MARSHAL_DAMAGE_MULT
    inspired_duration = MARSHAL_DURATION
    war_cry_interval = MARSHAL_CRY_INTERVAL
    super._ready()