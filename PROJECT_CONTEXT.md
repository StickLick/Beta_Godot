# PROJECT_CONTEXT.md

# Project Overview

Vampire Survivors style game made in Godot.

The project already has an existing architecture.
Do not redesign working systems unless explicitly requested.

The goal is minimal, safe implementation.

---

# Development Workflow

The assistant implementing code is not responsible for architecture decisions.

Follow the provided plan exactly.

Rules
- Inspect current files before editing.
- Modify only required files.
- Do not create unnecessary systems.
- Do not refactor unrelated code.
- Do not replace existing architecture with a different approach.
- Do not rethink already solved problems.

Existing solutions are considered correct unless a bug is specifically reported.

---

# Upgrade System

All upgrades are `.tres` resources.

Main resource
`Upgrade.gd`

Upgrade contains
- weapon_tag
- stats modification data
- rarity
- uniqueness
- evolution data
- global modifier flag

UpgradeMenu uses

```gdscript
@export var all_available_upgrades Array[Upgrade]

Important

Upgrade resources are manually added through Godot Inspector.

Do not implement automatic folder scanning.

Active Weapons

Player stores active weapons

active_weapons

UpgradeMenu uses active weapons to determine available weapon modifiers.

Weapon modifier availability depends on

weapon_tag

matching between

Upgrade resource
active weapon entry
Weapon Tags

Each weapon branch has its own tag.

Examples

Normal weapons

Aura
Spear

Evolution weapons

Aura_Evolved
Spear_Evolved

Tags are the source of progression separation.

Weapon Progression

Weapon levels are stored in

tag_levels Dictionary

Example

{
    Aura 8,
    Aura_Evolved 3,
    Spear 5
}

Maximum level

8
Evolution System

Evolution is a completely new weapon branch.

Important rules

Evolution replaces the original weapon.
Evolution occupies the same weapon slot.
Original weapon disappears.
Previous modifiers are NOT inherited.
Previous stats are NOT inherited.
Evolution starts from level 1.
Evolution has its own weapon_tag.
Evolution has its own modifiers.

Example

Before

Aura
Level 8
Aura modifiers

After

Aura_Evolved
Level 1
No Aura bonuses
Evolution Implementation

Evolution resource contains

@export var evolved_weapon_tag String = 

Example

AuraEvolution.tres

evolved_weapon_tag = Aura_Evolved

During evolution

Remove old weapon from active_weapons.
Replace it with evolved weapon entry.
Create new progression
tag_levels[Aura_Evolved] = 1

The old weapon tag must no longer be used for modifier filtering.

Evolution Modifiers

Evolution modifiers use evolved tags.

Example

Normal

weapon_tag = Aura

Evolution

weapon_tag = Aura_Evolved

They are separate branches.

Normal weapon modifiers must not appear after evolution.

Evolution modifiers must start from level 1.

Global Modifiers

Global modifiers are marked

is_global_modifier = true

Examples

Global_Damage_I
Global_MoveSpeed_I
Global_Area_I

Rules

Available without weapons.
Available without passives.
Do not require weapon_tag.
Controlled separately.

For global modifiers

_can_take_modifier()

returns true.

Other checks still apply

uniqueness
prerequisites
Passive Items

Examples

BaseStone
Book

Passives use their own progression.

Passive modifiers use

weapon_tag = passive name

Example

BaseStone modifier

weapon_tag = BaseStone

Passive logic should remain separate from weapons.

Upgrade Filtering

UpgradeMenu determines available modifiers.

Rules

Weapon modifier

Requires

active_weapons contains matching weapon_tag
Evolution modifier

Requires

active_weapons contains evolved weapon_tag
Passive modifier

Requires

active_passives contains matching passive
Global modifier

Requires

is_global_modifier == true
Current Implemented Systems

Completed

✅ Weapon evolution replacement
✅ Evolution separate progression
✅ Evolution separate modifiers
✅ active_weapons updates during evolution
✅ Global modifier system
✅ Inspector based upgrade pool
✅ Weapon tag based filtering

Important Previous Fixes

Do not undo

Evolution progression separation

Evolution does not share old weapon levels.

Example

Wrong

Aura lvl 8
Aura_Evolved lvl 8

Correct

Aura lvl 8
Aura_Evolved lvl 1
Active weapon replacement

After evolution

Wrong

active_weapons
Aura

Correct

active_weapons
Aura_Evolved
Forbidden Changes

Do not

merge weapon and evolution progression;
inherit old weapon stats;
create weapon_name based checks;
create hardcoded checks for specific weapons;
replace Inspector workflow;
add automatic upgrade loading;
redesign UpgradeMenu without necessity.

Prefer

weapon_tag based logic;
resource configuration;
minimal changes.
Future Development

Possible future features

more evolution types;
unique evolution modifiers;
advanced global modifiers;
new weapon branches.

Do not implement future systems unless requested.

Implementation Style

When fixing bugs

Find exact root cause.
Make the smallest possible change.
Keep existing architecture.
Avoid unrelated improvements.
Do not create unnecessary abstractions.