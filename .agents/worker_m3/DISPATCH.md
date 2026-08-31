## 2026-08-31T17:42:30Z
You are Worker 3 for Milestone 3 & 4 of the Modular Roblox Menu project.
Your working directory is: A:\Potassium\Modular-Roblox-Menu\.agents\worker_m3
Authoritative request: A:\Potassium\Modular-Roblox-Menu\.agents\ORIGINAL_REQUEST.md
Project plan: A:\Potassium\Modular-Roblox-Menu\PROJECT.md
Survey findings: A:\Potassium\Modular-Roblox-Menu\.agents\explorer_survey_3\handoff.md and Reviewer 2 caveats

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Scope & Assigned Files:
You exclusively own:
1. `UI/UI.luau`
2. `UI/ChatWidget.luau`
3. `UI/PlayerList.luau`
4. `UI/MusicTracker.luau`
5. `Core/ThemeManager.luau`
6. Static analysis and repository verification scripts (`check_services.py`)

Tasks:
1. Theme 0.2s Quad Color Interpolation (Requirement R3):
   - In `UI/UI.luau:181`, ensure `local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)` is configured so all registered elements across all 4 widgets interpolate in exactly 0.2s Quad.
   - Add dead-instance pruning in `UI.setTheme` (`UI/UI.luau`): before or during tweening `UI.RegisteredElements`, prune any entries where `not item.Instance or not item.Instance.Parent` to eliminate memory retention.
   - In `UI/ChatWidget.luau`, ensure message buttons and interactive elements register with `UI.registerThemeElement` for smooth theme color transitions, and fix line 367 where `FindFirstChild("PlayerListFrame")` should look for `FindFirstChild("PlayerListWidget")` or both.
   - Verify crisp squared retro borders (`BorderSizePixel = 0`, `UIStroke`), Gotham typography hierarchy, and consistent container paddings across all 5 themes (`Dark`, `Light`, `TranslucentDark`, `TranslucentLight`, `Adaptive`).
2. Static Analysis & BOM Verification (Requirement R4):
   - Run `python check_services.py` and verify 0 missing services across all 15 Luau modules.
   - Verify 0 UTF-8 BOM encoding bytes across all `.luau` files.
3. Git Commit & Push (Requirement R4):
   - Check `git status`, stage all modified files, commit with descriptive message (e.g. `feat(ui): complete GUI animation overhaul, spring micro-interactions, silky window transitions, and 0.2s Quad theme interpolation`), and push to `origin/main`.
4. Live MCP Verification (Requirement R4):
   - Run live execution probe on active Roblox client via `roblox-mcp` (`get-data-by-code` or `execute`) verifying 0 compile errors and live theme/animation functionality.

Write your comprehensive implementation and verification report to `A:\Potassium\Modular-Roblox-Menu\.agents\worker_m3\handoff.md` and report back when finished.
