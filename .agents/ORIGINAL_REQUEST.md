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
