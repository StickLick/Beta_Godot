class_name WarBannerArcher
extends WarBanner

func _ready() -> void:
    unit_scene = preload("res://Assets/Scenes/ArcherPawn.tscn")
    super._ready()
    if leash_visual:
        leash_visual.visible = false
