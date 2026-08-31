# Dispatch for Worker 2 — Milestone 2: Combat Tab Refactoring

## Objective
Refactor the Combat tab in `Core/Main.luau` to use mini sub-tabs `[ Aim Assistance ]` and `[ Hitbox Modifiers ]`.

## References & Inputs
- `ORIGINAL_REQUEST.md`: `A:\Potassium\Modular-Roblox-Menu\.agents\ORIGINAL_REQUEST.md`
- `PROJECT.md`: `A:\Potassium\Modular-Roblox-Menu\.agents\PROJECT.md`
- Explorer 2 Blueprint: `A:\Potassium\Modular-Roblox-Menu\.agents\explorer_2\handoff.md`
- Target file: `A:\Potassium\Modular-Roblox-Menu\Core\Main.luau`

## Mandatory Integrity Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A forensic auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Requirements
1. In `Core/Main.luau`, replace the Combat tab section setup (formerly lines 251-316) with `window:CreateSubTabs(combatTab, { "Aim Assistance", "Hitbox Modifiers" })`.
2. Populate `[ Aim Assistance ]` sub-tab with dual columns (`CreateColumns`):
   - Left Column (`Targeting & Automation`):
     - `silent_aim` (Silent Aim)
     - `wall_bang` (Wall Bang (Shoot Thru Walls))
     - `target_head` (Target Head (Off = Torso))
     - `track_teammates` (Track Teammates)
     - `trigger_bot` (Trigger Bot)
   - Right Column (`Tracking & FOV Dynamics`):
     - `aim_tracking` (Aim Tracking (Camera Lock))
     - `aim_always` (Always Lock (Ignore RMB Hold))
     - `fov_circle` (FOV Circle)
     - `FOV Radius` slider (30-360, default 120)
     - `Hit Chance %` slider (10-100, default 100)
     - `Aim Smoothing` slider (5-100, default 25)
3. Populate `[ Hitbox Modifiers ]` sub-tab with dual columns (`CreateColumns`):
   - Left Column (`Hitbox Expansion`):
     - `expand_hitboxes` (Expand Hitbox's)
     - `Hitbox Size` slider (2-30, default 12)
   - Right Column (`Hitbox Operations`):
     - `Reset All Hitboxes` action button calling `Combat.resetHitboxes()` and `window:Notify`.
4. Ensure 100% preservation of all feature keys, slider names, callbacks, math operations (`Smoothing = value / 100`, `TargetPart = if enabled then "Head" else "Torso"`), and FeatureManager state.
5. Verify syntax and zero missing services.

## Write Ownership
You own `Core/Main.luau`.

## Handoff
Write your implementation report to `A:\Potassium\Modular-Roblox-Menu\.agents\worker_2\handoff.md`.
