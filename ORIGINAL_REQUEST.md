# Original User Request

## Initial Request — 2026-08-31T16:56:07Z

Refactor the Modular Roblox Menu UI to implement clean, compact horizontal mini sub-tabs inside parent tabs (starting with Combat: [ Aim Assist ] [ Hitbox Modifiers ]) to eliminate visual clutter, maximize usable screen space without excessive configuration, and maintain flawless engine performance.

Working directory: A:\Potassium\Modular-Roblox-Menu
Integrity mode: development
Requested team: Full multi-agent team

## Requirements

### R1. Mini Sub-Tab Architecture (CoreUI.luau)
Implement a clean `CoreUI:CreateSubTabs(parentTab, subTabNames)` method in `Core/CoreUI.luau` that creates a lightweight, styled horizontal sub-tab bar inside any tab page. Switching sub-tabs must smoothly swap sub-views with fluid spring-damper transitions without overflowing or cluttering the layout.

### R2. Combat Tab Decluttering (Core/Main.luau)
Apply the mini sub-tab system to the Combat tab, organizing its sections into distinct sub-views:
- `[ Aim Assistance ]`: Silent Aim, Wallbang, Target Part, Aim Tracking (Camera Lock), Always Lock, Track Teammates, Trigger Bot, FOV Circle, FOV Radius, Hit Chance, Aim Smoothing.
- `[ Hitbox Modifiers ]`: Expand Hitboxes, Hitbox Size, and range modifications.

### R3. Preservation & Verification of Engine Integrity
Ensure all existing engine systems (Post-Camera BindToRenderStep aim tracking, Walk Fling collision torque, PlayerList context menu with Roblox actions, continuous 60+ FPS spring-damper visualizer, persistent theme & dynamic config manager) remain 100% functional with zero syntax errors, missing services, or UTF-8 BOM encoding issues.

## Acceptance Criteria

### Sub-Tab UI Density & Flow
- [ ] Combat tab renders a clean horizontal mini sub-tab bar (`[ Aim Assistance ]` / `[ Hitbox Modifiers ]`).
- [ ] Switching mini sub-tabs toggles the respective sub-views with silky spring animations and zero layout jitter.
- [ ] UI remains compact, uncluttered, and readable without requiring manual reconfiguration.

### Integrity & Stability
- [ ] `check_services.py` passes with 0 missing services.
- [ ] All `.luau` files are stripped of UTF-8 BOM bytes.
- [ ] Git commit and push succeeds on `main`.

## Follow-up — 2026-08-31T17:18:38Z

Execute a complete GUI animation overhaul and visual polish pass across all suite interfaces (Main Menu, PlayerList, ChatWidget, MusicTracker, Notification), implementing unified spring-damper micro-interactions, silky window/popup pop-in transitions, staggered domino row ripples, and smooth theme color transitions.

Working directory: A:\Potassium\Modular-Roblox-Menu
Integrity mode: development
Requested team: Full multi-agent team

## Requirements

### R1. Micro-Interaction Spring Engine (UI/Animations.luau & CoreUI.luau)
Implement crisp, responsive micro-animations across all UI controls:
- **Toggles**: Spring pop scale for checkmark with fluid background accent fill.
- **Sliders**: Smooth lerping fill track with responsive glow and hover feedback.
- **Buttons**: Micro-squash and border glow on hover/click with instant response.
- **Tabs & Sub-Tabs**: Smooth spring transitions with active tab indicator pulses.

### R2. Window & Popup Transitions (UI/UI.luau, PlayerList, ChatWidget, MusicTracker)
- **Window Open/Close/Toggle**: Spring scale (0.95 -> 1.0) and fade-in/out transitions for the main window, PlayerList, ChatWidget, and MusicTracker.
- **Context Menus**: Smooth pop-in and auto-positioning for PlayerList player action menus and Chat quick phrases.
- **Staggered Domino Animations**: Cascaded slide-in for player list rows and incoming chat messages.

### R3. Theme Color Transitions & Visual Polish
- Smooth color interpolation (0.2s Quad) during theme changes across all 4 widgets simultaneously.
- Clean typography hierarchy, crisp squared retro borders, and consistent container paddings across all themes (`Dark`, `Light`, `TranslucentDark`, `TranslucentLight`, `Adaptive`).

### R4. Static Analysis & Live MCP Verification
- 0 missing Roblox services across all 15 Luau modules.
- 0 UTF-8 BOM encoding bytes across all files.
- Push to `origin/main` and verify execution on live Roblox client via `roblox-mcp` with 0 compile errors.

## Acceptance Criteria

### Animation & Visual Consistency
- [ ] All toggles, sliders, buttons, tabs, sub-tabs, and windows trigger clear, fluid spring-damper animations.
- [ ] Theme changes cleanly interpolate colors across every widget in real time without layout artifacts.
- [ ] PlayerList context popup and chat entries animate smoothly into position.

### Stability & Verification
- [ ] `check_services.py` passes with 0 missing services.
- [ ] Git commit and push succeeds on `main`.
- [ ] Live execution via Roblox MCP runs with 0 compile errors.
