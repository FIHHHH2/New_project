# BRIEFING — 2026-08-31T17:36:48Z

## Mission
Eliminate per-frame raycast allocations, implement spatial two-pass target solver, throttle TriggerBot, and fix hitbox memory leaks in Combat.luau.

## 🔒 My Identity
- Archetype: worker_combat
- Roles: implementer, qa, specialist
- Working directory: A:\Potassium\Modular-Roblox-Menu\.agents\worker_combat
- Original parent: ff7f85b0-c16f-42f0-b5a1-15980cc2d2e8
- Milestone: M1, M3

## 🔒 Key Constraints
- Exclusive file ownership: A:\Potassium\Modular-Roblox-Menu\Modules\Combat.luau
- No UTF-8 BOM encoding bytes
- 0 missing services via python check_services.py
- Do not cheat: genuine implementation, no dummy stubs

## Current Parent
- Conversation ID: ff7f85b0-c16f-42f0-b5a1-15980cc2d2e8
- Updated: 2026-08-31T17:36:48Z

## Task Summary
- **What to build**: Optimize Combat.luau: eliminate per-frame RaycastParams allocations, add spatial 3D bounding & FOV checks, implement two-pass target solver (Pass 1: filter and sort by 2D distance; Pass 2: raycast only closest candidate(s)), throttle TriggerBot and reuse RaycastParams, clear originalHitboxSizes on player/character removing.
- **Success criteria**: 0 missing services, 0 BOM, clean syntax, optimized raycasting and memory lifecycle.
- **Interface contracts**: PROJECT.md
- **Code layout**: Modules/Combat.luau

## Change Tracker
- **Files modified**: `A:\Potassium\Modular-Roblox-Menu\Modules\Combat.luau` — Refactored with static RaycastParams, two-pass target solver, spatial bounding, throttled TriggerBot, and lifecycle cleanup for Hitbox Expander.
- **Build status**: check_services.py PASS (0 missing services, 0 BOM)
- **Pending issues**: none

## Quality Status
- **Build/test result**: check_services.py PASS
- **Lint status**: clean
- **Tests added/modified**: check_services.py validation

## Key Decisions Made
- Used module-level `SHARED_RAY_PARAMS` and `SHARED_TRIGGER_PARAMS` with `table.clear()` reused filter arrays.
- Implemented two-pass target solver: pass 1 fast 3D distance and 2D viewport projection with sorting; pass 2 raycasting only closest candidate(s).
- TriggerBot throttled to ~30 Hz and reusing static RaycastParams.
- Hooked `Players.PlayerRemoving`, `player.CharacterRemoving`, and orphaned sweeps to clear `originalHitboxSizes` entries.

## Artifact Index
- `A:\Potassium\Modular-Roblox-Menu\Modules\Combat.luau` — Target implementation
- `A:\Potassium\Modular-Roblox-Menu\.agents\worker_combat\changes.md` — Detailed change log
- `A:\Potassium\Modular-Roblox-Menu\.agents\worker_combat\handoff.md` — Final handoff report
