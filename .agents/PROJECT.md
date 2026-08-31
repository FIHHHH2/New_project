# Project: Modular Roblox Menu UI Refactor

## Architecture
- `Core/CoreUI.luau`: Window, sidebar navigation, tab containers, horizontal mini sub-tabs architecture (`CreateSubTabs`), responsive columns (`CreateColumns`), sections, toggles, sliders, dropdowns, buttons, notifications, dynamic theme engine.
- `Core/Main.luau`: Main orchestration script initializing UI window, tabs (`Main`, `Combat`, `DisasterSurvival`/`GameTab`, `Visuals`, `Settings`, `Configs`), keybinds, feature connections, walk fling, and chat widget toggles.
- `Core/FeatureManager.luau`: Config manager handling dynamic discovery, saving, loading, and deletion of profile JSONs.
- `Modules/Combat.luau`: Combat engine implementing silent aim metamethod hooks, FOV drawing, post-camera aim tracking lerp, trigger bot, and hitbox resizing.
- `UI/UI.luau`: Core styling tokens, palettes (`Dark`, `Light`, `TranslucentDark`, `TranslucentLight`, `Adaptive`), fonts, and theme persistence.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | `CreateSubTabs` Method | Lightweight horizontal mini sub-tab bar with fluid spring transitions and theme reactivity | M1 | ORIGINAL_REQUEST §R1 |
| 2 | `CreateColumns` Generalization | Allow `CreateColumns` to accept sub-tab page tables or GuiObjects directly | M1 | Survey (Explorer 1) |
| 3 | Combat Tab Sub-Views | Split Combat tab into `[ Aim Assistance ]` and `[ Hitbox Modifiers ]` sub-tabs | M2 | ORIGINAL_REQUEST §R2 |
| 4 | Config & Callback Preservation | Preserve all 13 toggle/slider config keys and engine callbacks in Combat tab | M2 | Survey (Explorer 2) |
| 5 | Engine Systems Integrity | Preserve Aim tracking, Walk Fling, PlayerList actions, Music visualizer, Theme/Config | M3 | ORIGINAL_REQUEST §R3 |
| 6 | Service Declarations & check_services.py | Add check_services.py to root and fix missing service accesses in ChatWidget/MusicTracker | M3 | ORIGINAL_REQUEST §Integrity |
| 7 | UTF-8 BOM Verification | Ensure all .luau files have 0 BOM bytes | M3 | ORIGINAL_REQUEST §Integrity |
| 8 | Git Commit & Push | Commit refactor and push cleanly to main branch | M4 | ORIGINAL_REQUEST §Integrity |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | CoreUI Sub-Tabs Architecture | Implement `CreateSubTabs`, update `CreateColumns` and `SetTheme` in `Core/CoreUI.luau` | none | PLANNED |
| 2 | Combat Tab Refactor | Apply sub-tabs to Combat tab in `Core/Main.luau` with balanced columns | M1 | PLANNED |
| 3 | Verification, Integrity & Services Fix | Place `check_services.py`, fix `Workspace` accesses, verify 0 BOM, verify engine subsystems | M1, M2 | PLANNED |
| 4 | Git Deployment & E2E Validation | Stage all modified files, commit with descriptive message, push to main | M1, M2, M3 | PLANNED |

## Interface Contracts
### `CoreUI:CreateSubTabs(parentTab: any, subTabNames: {string})`
- **Inputs**: `parentTab` (Tab object table with `.Page` or GuiObject), `subTabNames` (array of strings)
- **Output**: Sub-tab group table with:
  - `subTabs[name]` -> `{ Name: string, Button: TextButton, Page: Frame, Stroke: UIStroke, Gradient: UIGradient, ParentTab: any, Index: number }`
  - `subTabs[index]` -> Sub-tab object
  - `subTabs.ActiveSubTab` -> Currently active sub-tab object
  - `subTabs:Select(nameOrIndex)` -> Function to switch sub-tab with spring animation
  - `subTabs:GetActive()` -> Returns active sub-tab
  - `subTabs.UpdateTheme()` -> Re-applies theme colors to active/inactive buttons
- **Layout**: `SubTabBar` (LayoutOrder = 1, Height = 26px), `SubPagesContainer` (LayoutOrder = 2, AutomaticSize = Y)

### `CoreUI:CreateColumns(tabObj: any): (Frame, Frame)`
- **Inputs**: `tabObj` (Tab object, sub-tab object, or GuiObject)
- **Output**: `leftCol` (Frame), `rightCol` (Frame)

## Code Layout
- `Core/CoreUI.luau` (Exclusive write: Worker M1)
- `Core/Main.luau` (Exclusive write: Worker M2)
- `check_services.py`, `UI/ChatWidget.luau`, `UI/MusicTracker.luau` (Exclusive write: Worker M3)
