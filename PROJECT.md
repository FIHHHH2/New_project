# Project: Modular Roblox Menu — Performance & Memory Overhaul

## Architecture
The Modular Roblox Menu consists of 18 Luau modules spanning core systems, UI widgets, and gameplay modules:
- `Core/Init.luau`: Entry point and module loader.
- `Core/Main.luau`: Primary menu window, tab switching, and render hooks.
- `Core/CoreUI.luau`: Component abstraction layer (Toggles, Sliders, Buttons, SubTabs, Window controllers).
- `Core/ThemeManager.luau`: Theme definitions, palette interpolation, and registered element styling.
- `Core/ConfigManager.luau`: Serialization, persistence, and state management.
- `UI/UI.luau`: Low-level window construction and theme registration.
- `UI/Animations.luau`: Spring-damper and TweenService animation engine.
- `UI/Hotbar.luau`: Custom inventory hotbar with 3D ViewportFrame tool previews and keybinds.
- `UI/PlayerList.luau`: Player list widget with context actions and domino animations.
- `UI/ChatWidget.luau`: Chat widget with quick phrases and player profile popups.
- `UI/MusicTracker.luau`: Standalone music tracker widget with audio visualizer.
- `UI/Notification.luau`: Stacked floating notification manager.
- `Modules/Combat.luau`: Silent aim, camera lock, wallbang penetration, triggerbot, FOV circles, hitbox expansion.
- `Modules/Visuals.luau`: ESP boxes, tracers, chams, distance tags, drawing object pooling.
- `Modules/Movement.luau`: Speed, fly, infinite jump, noclip, walk fling, bunny hop.
- `Modules/GameUtils.luau`: Anti-AFK, server hop, rejoin, copy game ID, click teleport, disaster helpers.
- `Modules/RunNHide.luau`: Game-specific runner utilities, entity radar, automatic evasion.
- `Modules/Self.luau`: Local character modifications, godmode checks, humanoid state modifiers.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | RenderStepped & Heartbeat Table Allocation Elimination | Pre-allocate and reuse scratch tables, vector buffers, and eliminate per-frame string formatting | M1 | R1 |
| 2 | Timestamp Caching & Invalidation | Cache player references, character parts, screen positions, and viewport dimensions with tick timestamps | M1 | R1 |
| 3 | Fixed Tick-Rate Throttling | Throttle non-critical loops (ESP distance sorting, disaster tag lookups, inventory scans) to 10–20 Hz | M1 | R1 |
| 4 | ViewportFrame Dirty-Check Caching | Implement hash/tool reference caching in `UI/Hotbar.luau` to prevent redundant `Clone()` instantiation | M2 | R2 |
| 5 | Memory & Instance Lifecycle Cleanup | Explicitly destroy orphaned ViewportFrame Cameras, Cloned BaseParts, and tween connections | M2 | R2 |
| 6 | Drawing Object Pooling | Pool and reuse Drawing objects (Boxes, Lines, Text) in `Modules/Visuals.luau` across join/leave events | M2 | R2 |
| 7 | Noclip & Locomotion Sweep Optimization | Use cached descendant lists / targeted part filtering in `Movement.luau` and `RunNHide.luau` | M3 | R3 |
| 8 | Spatial Bounding & Raycast Optimization | Spatial partitioning / distance bounding checks prior to multi-target raycasts in `Combat.luau` | M3 | R3 |
| 9 | Empirical Luau Benchmark Suite | Luau benchmark script measuring frame times, GC pressure, and memory under 50+ player load | M4 | R4 |
| 10 | Static Service & BOM Verification | `check_services.py` 100% pass (0 missing services, 0 BOM bytes across 18 Luau modules) | M4 | R4 |
| 11 | Git Commit & Push | Clean commit and push to `origin/main` | M4 | R4 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | RenderStepped & Heartbeat Pipeline Optimization | Features 1–3: `Combat.luau`, `Visuals.luau`, `Movement.luau`, `GameUtils.luau`, `RunNHide.luau`, `Core/Main.luau`, `UI/Animations.luau` | none | PLANNED |
| 2 | 3D ViewportFrame & Memory Lifecycle Optimization | Features 4–6: `UI/Hotbar.luau`, `Modules/Visuals.luau`, peripheral widgets | none | PLANNED |
| 3 | Collision, Physics & Raycast Optimization | Features 7–8: `Movement.luau`, `Combat.luau`, `RunNHide.luau` | none | PLANNED |
| 4 | Empirical Benchmark, Static Analysis & Git Push | Features 9–11: Benchmark script, `check_services.py`, BOM check, Git push | M1, M2, M3 | PLANNED |

## Interface Contracts
- Drawing Object Pool: `Visuals.acquireDrawing(type: string)`, `Visuals.releaseDrawing(obj: any)`
- Tool Dirty Checking: `Hotbar.getToolSignature(tool: Tool): string`
- Throttled Tick Timer: `local now = os.clock(); if now - lastTick < INTERVAL then return end; lastTick = now`
- Spatial Filter: `Combat.getNearbyTargets(radius: number, maxTargets: number): {Player}`

## Code Layout
- `Core/`: `Init.luau`, `Main.luau`, `CoreUI.luau`, `ThemeManager.luau`, `ConfigManager.luau`
- `UI/`: `UI.luau`, `Animations.luau`, `Hotbar.luau`, `PlayerList.luau`, `ChatWidget.luau`, `MusicTracker.luau`, `Notification.luau`
- `Modules/`: `Combat.luau`, `Visuals.luau`, `Movement.luau`, `GameUtils.luau`, `RunNHide.luau`, `Self.luau`
- `tests/`: `check_services.py`, benchmark scripts
