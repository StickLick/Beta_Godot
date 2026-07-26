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

## Targeting & Physics Queries
- For Evolved Aura burst targeting, we use low-level `PhysicsShapeQueryParameters2D` with `CircleShape2D` and `RectangleShape2D` instead of `Area2D` nodes, because Area2D nodes were unreliable and costly at scale.
- `intersect_shape()` queries are performed with a dedicated `collision_mask` (bit 8 = Enemy Layer 4) and directly filter results in code.
- This pattern avoids spawning/managing many Area2D collision shapes for temporary targeting checks.
- Burst damage uses a rectangular shape aligned to the burst direction; detection uses a large circle (radius = `max_attack_distance * 1.5`).
