# Beta_Godot — Architecture Guide

## Project
Roguelike RTS in Godot 4.7.

## Core Pattern
- Upgrades are `.tres` Resource files extending `Upgrade.gd`.
- Weapon logic uses inheritance: `BaseWeapon` → `AuraWeapon` / `SpearWeapon`.
- `BaseWeapon` contains shared stats and virtual `_weapon_ready()` / `_weapon_process()` methods.
- `AuraWeapon` handles aura damage ticks, visual animation, and evolved burst targeting.
- `SpearWeapon` handles cooldown-based glitch strikes with ghost effects.
- `WeaponManager` is a factory/manager — it spawns weapon scenes based on `Upgrade` resources.
- Passive system uses `passive_id` for family identification, `tag_levels` for tracking.
- All weapon stats are `@export` variables on `BaseWeapon`.

## Project Structure
```
scripts/              → GDScript logic
  player.gd           → Movement, inventory, upgrade application
  UpgradeMenu.gd      → Card generation, filtering, weighted selection
  GameManager.gd      → Anomaly system, game state
  hud.gd              → UI inventory, anomaly notifications
  weapons/            → All weapon scripts
    base_weapon.gd      → Shared weapon base class (BaseWeapon)
    weapon_component.gd → WeaponManager — factory for spawning weapons
    aura_weapon.gd      → Aura-specific combat logic (AuraWeapon)
    spear_weapon.gd     → Spear-specific combat logic (SpearWeapon)
    bow_weapon.gd       → Bow fan-arrow logic (BowWeapon)
    siege_crossbow.gd   → Siege Crossbow evolution (SiegeCrossbow)
    arrow.gd            → Arrow projectile (Arrow)
    siege_bolt.gd       → Heavy bolt with AoE explosion (SiegeBolt)
Assets/Scenes/        → PackedScene (.tscn) for each weapon/entity
Shaders/              → GLSL shaders (.gdshader)
Upgrades/             → .tres resource files by category
  Evolutions/         → Evolution triggers (change_mechanic_on_apply)
  Weapons/            → Weapon-specific upgrades by weapon folder
  Passives/           → Passive stat upgrades by family
```

## Rules
- Do not refactor core systems unless explicitly requested.
- Keep code minimal — prefer extending existing branches over new abstractions.
- weapon_tag is for weapon modifier identification only.
- passive_id is for passive family identification only.
- No automatic folder scanning — upgrades are Inspector-assigned.

## Adding a New Weapon
1. Create `scripts/weapons/{name}_weapon.gd` extending `BaseWeapon`.
2. Override `_weapon_ready()` and `_weapon_process(delta)`.
3. Create `Assets/Scenes/{Name}Weapon.tscn` with root node type `Node2D`, attach your script.
4. Add `{Name}Weapon.tscn` to the scene path pattern used by `WeaponManager.spawn_weapon()`.
5. Create upgrade `.tres` resources in `Upgrades/{Name}/`.

## Targeting & Physics Queries
- For Evolved Aura burst targeting, we use low-level `PhysicsShapeQueryParameters2D` with `CircleShape2D` and `RectangleShape2D` instead of `Area2D` nodes, because Area2D nodes were unreliable and costly at scale.
- `intersect_shape()` queries are performed with a dedicated `collision_mask` (bit 8 = Enemy Layer 4) and directly filter results in code.
- This pattern avoids spawning/managing many Area2D collision shapes for temporary targeting checks.
- Burst damage uses a rectangular shape aligned to the burst direction; detection uses a large circle (radius = `max_attack_distance * 1.5`).
