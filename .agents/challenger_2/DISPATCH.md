# Dispatch for Challenger 2

## Objective
Adversarially challenge and stress-test the Combat engine callbacks, feature toggles, math conversions, and physics subsystems.

## References & Inputs
- `ORIGINAL_REQUEST.md`: `A:\Potassium\Modular-Roblox-Menu\.agents\ORIGINAL_REQUEST.md`
- `PROJECT.md`: `A:\Potassium\Modular-Roblox-Menu\.agents\PROJECT.md`
- Codebase: `Core/Main.luau`, `Modules/Combat.luau`, `Modules/DisasterSurvival.luau`, `UI/PlayerList.luau`, `UI/MusicTracker.luau`

## Stress Test Areas
1. Combat Toggle & Slider Mapping: Verify that all 9 feature toggles and 4 sliders in `Core/Main.luau` map 1:1 to their corresponding variables in `Modules/Combat.luau`.
2. Math & State Assertions:
   - `Smoothing`: Slider 5-100 -> `Combat.Smoothing` (0.05 to 1.0) -> `math.clamp(Combat.Smoothing, 0.05, 1.0)`.
   - `TargetPart`: Toggle `target_head` -> `"Head"` or `"Torso"`.
   - `AimMode`: Toggle `aim_always` -> `"Always"` or `"Hold RMB"`.
   - `ExpandHitboxes`: Toggle off calls `Combat.resetHitboxes()`.
   - `Reset All Hitboxes` button calls `Combat.resetHitboxes()`.
3. Physics & Visualizer Stress:
   - Walk Fling torque values: `Vector3.new(0, 10000000, 0)` on RootPart.
   - Spring-damper ODE stability in `UI/MusicTracker.luau`.
   - BindToRenderStep aim tracking priority (`Enum.RenderPriority.Camera.Value + 1`).

## Handoff
Write your findings and verdict (`APPROVE` or `REQUEST_CHANGES`) to `A:\Potassium\Modular-Roblox-Menu\.agents\challenger_2\handoff.md`.
Send a message back when complete.
