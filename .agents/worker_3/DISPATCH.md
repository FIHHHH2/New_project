# Dispatch for Worker 3 — Milestone 3: Integrity Verification & Services Fix

## Objective
Place `check_services.py` in the project root, fix undeclared service accesses in `UI/ChatWidget.luau` and `UI/MusicTracker.luau`, ensure 0 UTF-8 BOM bytes across all `.luau` files, and run full static and engine integrity verification.

## References & Inputs
- `ORIGINAL_REQUEST.md`: `A:\Potassium\Modular-Roblox-Menu\.agents\ORIGINAL_REQUEST.md`
- `PROJECT.md`: `A:\Potassium\Modular-Roblox-Menu\.agents\PROJECT.md`
- Explorer 3 Report: `A:\Potassium\Modular-Roblox-Menu\.agents\explorer_3\handoff.md`
- Service checker script: `A:\Potassium\Modular-Roblox-Menu\.agents\explorer_3\check_services.py`

## Mandatory Integrity Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A forensic auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Requirements
1. Copy/create `check_services.py` in project root `A:\Potassium\Modular-Roblox-Menu\check_services.py`.
2. Fix undeclared service access in `UI/ChatWidget.luau` (line 853) and `UI/MusicTracker.luau` (line 633) by replacing `Workspace.CurrentCamera` with `workspace.CurrentCamera`.
3. Check all 15 `.luau` files in the repository for UTF-8 BOM bytes and strip if any are found.
4. Run `python check_services.py` in project root and verify it outputs 0 missing services.
5. Verify syntax and structure of all 15 `.luau` files.
6. Verify preservation of 5 core engine systems:
   - Post-Camera BindToRenderStep aim tracking (`Modules/Combat.luau`)
   - Walk Fling collision torque (`Core/Main.luau`, `Modules/DisasterSurvival.luau`, `UI/PlayerList.luau`)
   - PlayerList context menu with Roblox actions (`UI/PlayerList.luau`)
   - Continuous 60+ FPS spring-damper visualizer (`UI/MusicTracker.luau`)
   - Persistent theme & dynamic config manager (`UI/UI.luau`, `Core/FeatureManager.luau`)

## Write Ownership
You own `check_services.py`, `UI/ChatWidget.luau`, `UI/MusicTracker.luau`.

## Handoff
Write your full verification report to `A:\Potassium\Modular-Roblox-Menu\.agents\worker_3\handoff.md`.

## 2026-08-31T17:03:22Z
You are Worker 3. Your working directory is A:\Potassium\Modular-Roblox-Menu\.agents\worker_3.
Read your dispatch file at A:\Potassium\Modular-Roblox-Menu\.agents\worker_3\DISPATCH.md and ORIGINAL_REQUEST.md at A:\Potassium\Modular-Roblox-Menu\.agents\ORIGINAL_REQUEST.md.
Place check_services.py in project root, fix undeclared Workspace accesses in UI/ChatWidget.luau and UI/MusicTracker.luau, verify and strip UTF-8 BOMs across all .luau files, run python check_services.py to achieve 0 missing services, and verify all 5 core engine subsystems.
Write your complete report to A:\Potassium\Modular-Roblox-Menu\.agents\worker_3\handoff.md.
Send a message back when complete.

