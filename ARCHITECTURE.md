# Beta_Godot — Architecture Guide

## Project
Roguelike RTS in Godot 4.7.

## Core Pattern
- Upgrades are `.tres` Resource files extending `Upgrade.gd`.
- Weapon logic is in `weapon_component.gd` (shared between Spear and Aura).
- Passive system uses `passive_id` for family identification, `tag_levels` for tracking.
- All weapon stats are `@export` variables on `WeaponComponent`.

## Project Structure
```
scripts/           → GDScript logic
  player.gd        → Movement, inventory, upgrade application
  weapon_component.gd → Spear/Aura combat logic
  UpgradeMenu.gd   → Card generation, filtering, weighted selection
  GameManager.gd   → Anomaly system, game state
  hud.gd           → UI inventory, anomaly notifications
Assets/Scenes/     → PackedScene (.tscn) for each weapon/entity
Shaders/           → GLSL shaders (.gdshader)
Upgrades/          → .tres resource files by category
```

## Rules
- Do not refactor core systems unless explicitly requested.
- Keep code minimal — prefer extending existing branches over new abstractions.
- weapon_tag is for weapon modifier identification only.
- passive_id is for passive family identification only.
- No automatic folder scanning — upgrades are Inspector-assigned.