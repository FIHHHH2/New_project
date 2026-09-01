## 2026-08-31T17:35:23Z
You are Worker Combat for the Modular Roblox Menu project.
Your working directory is: A:\Potassium\Modular-Roblox-Menu\.agents\worker_combat
Project root: A:\Potassium\Modular-Roblox-Menu
Authoritative request: A:\Potassium\Modular-Roblox-Menu\.agents\ORIGINAL_REQUEST.md
Survey analysis: A:\Potassium\Modular-Roblox-Menu\.agents\explorer_lead_survey\analysis.md
PROJECT plan: A:\Potassium\Modular-Roblox-Menu\PROJECT.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Your EXCLUSIVE file ownership:
- `A:\Potassium\Modular-Roblox-Menu\Modules\Combat.luau`

Your mission:
1. Eliminate per-frame / per-candidate `RaycastParams.new()` allocations in `isPartVisible()`, `checkWallbangPenetration()`, and `checkTriggerBot()`. Create a static module-level `SHARED_RAY_PARAMS` instance and reusable filter arrays.
2. Add spatial 3D distance and FOV angle bounding checks in `Combat.getClosestTarget()` before running raycasts.
3. Implement a two-pass target solver:
   - Pass 1: Filter candidates by 3D distance (e.g. <= 500 studs) and 2D screen distance, sorting candidates by screen distance.
   - Pass 2: Fire raycasts ONLY for the closest candidate(s), rather than raycasting all players in the server.
4. Throttle TriggerBot raycasting and reuse static `RaycastParams`.
5. In Hitbox Expander, clear `originalHitboxSizes` on player/character removing to prevent memory leaks from retained `HumanoidRootPart` references.
6. Verify code compiles cleanly with 0 syntax errors and 0 missing services via `python check_services.py`.
7. Ensure 0 UTF-8 BOM encoding bytes.
8. Document all changes in `A:\Potassium\Modular-Roblox-Menu\.agents\worker_combat\changes.md` and complete `handoff.md`.
9. Send message back to parent (conversation ID: ff7f85b0-c16f-42f0-b5a1-15980cc2d2e8) when done.