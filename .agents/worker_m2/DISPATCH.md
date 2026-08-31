## 2026-08-31T17:32:29Z
You are Worker 2 for Milestone 2 of the Modular Roblox Menu project.
Your working directory is: A:\Potassium\Modular-Roblox-Menu\.agents\worker_m2
Authoritative request: A:\Potassium\Modular-Roblox-Menu\.agents\ORIGINAL_REQUEST.md
Project plan: A:\Potassium\Modular-Roblox-Menu\PROJECT.md
Survey findings: A:\Potassium\Modular-Roblox-Menu\.agents\explorer_survey_2\handoff.md
Animation engine: `UI/Animations.luau` and `Core/CoreUI.luau`

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

Scope & Assigned Files:
You exclusively own and will modify:
1. `UI/UI.luau`
2. `UI/PlayerList.luau`
3. `UI/ChatWidget.luau`
4. `UI/MusicTracker.luau`
5. `UI/Notification.luau`

Tasks:
1. `UI/UI.luau`:
   - Refactor `openWindow` and `closeWindow` to utilize `Animations.openWindow(mainFrame, uiScale)` and `Animations.closeWindow(mainFrame, uiScale)` (UIScale 0.95 -> 1.0 Back.Out / 1.0 -> 0.95 Quad.In) without modifying Frame Size bounds or breaking dragging.
   - Return window controller table from `UI.createWindow` (`toggleWindow`, `openWindow`, `closeWindow`, `setWindowVisible`, `isOpen`, `isTransitioning`, etc.).
2. `UI/PlayerList.luau`:
   - Add `UIScale` to widget container.
   - Implement animated `Toggle()`, `Open()`, `Close()`, and `SetVisible()` on widget table.
   - Context Menu (`popupFrame`): Add `popupScale` (`UIScale`), implement screen-clamped auto-docking (8px viewport margin) and flip detection, and animate with `Animations.popIn(popupFrame, popupScale)` / `Animations.popOut(popupFrame, popupScale)`.
   - Player rows: cascaded domino slide-in from right (`Position.X = 24 -> 0`, `0.035s` stagger, `Back.Out`).
3. `UI/ChatWidget.luau`:
   - Add `UIScale` to widget container.
   - Implement animated `Toggle()`, `Open()`, `Close()`, `SetVisible()`.
   - Wire `closeBtn` and `Slash` keybind to animated open/close.
   - Add dedicated `quickPopup` context menu above `quickBtn` containing selectable phrases with `UIScale` spring pop-in (`Animations.popIn`).
   - Profile popup (`profilePopup`): Add `UIScale` and animate with `Animations.popIn` / `Animations.popOut`.
   - Incoming messages: animate `msgBtn` slide-in (`Position.X = 16 -> 0`, `0.22s Back.Out`) and text fade (`0.16s Quad.Out`).
4. `UI/MusicTracker.luau`:
   - Add `UIScale` to widget container.
   - Update `Toggle()`, `Open()`, `Close()`, `SetVisible()` to use `Animations.openWindow` and `Animations.closeWindow` without interrupting 60+ FPS visualizer physics.
5. `UI/Notification.luau`:
   - Add `UIScale` spring pop-in (`0.92 -> 1.0`) with horizontal slide-in (`UDim2.new(1, -270, 1, targetY)` with `Back.Out`).
   - Slide-out smoothly fades transparency and scales to `0.92` before destruction.
6. Static verification:
   - Run `python check_services.py` and ensure 0 missing services and 0 UTF-8 BOM bytes across all 15 Luau modules.
