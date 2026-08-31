# Project: Modular Roblox Menu UI Refactor & Feature Expansion

## Architecture
Modular Luau architecture for Roblox executor environments:
- **Core Layer**:
  - `Core/CoreUI.luau`: Base UI constructor, tab creation, horizontal mini sub-tab system (`CreateSubTabs`), element layouts (columns, sections, toggles, sliders, dropdowns, color pickers, keybinds, buttons).
  - `Core/Main.luau`: Suite orchestration, tab instantiation (Main, Combat, Visuals, Game, Settings, Configs), sub-tab layout bindings, bidirectional settings synchronization, feature connections.
  - `Core/FeatureManager.luau`: Dynamic state management, persistent key-value configuration, change hooks.
  - `Core/ThemeManager.luau`: Theme persistence and cross-widget synchronization.
- **Modules Layer**:
  - `Modules/Visuals.luau`: 2D Drawing ESP (Box with Outlines, Tracers with dynamic origins, Distance tags, Health bars, Skeleton) + 3D Highlight Chams with customizable fill/outline colors.
  - `Modules/Combat.luau`: Silent Aim, Aim Tracking (BindToRenderStep post-camera), FOV Circle with customizable Color3, TriggerBot with configurable delay slider, Wallbang with bidirectional raycasting thickness tolerance.
  - `Modules/PlayerUtilities.luau`: Server Hop, Rejoin Server, Copy Game/Place/Job IDs, Anti-AFK timeout preventer (Idled + VirtualUser), Click Teleport tool.
  - `Modules/Movement.luau`: Speed, Flight, Noclip, Infinite Jump, Walk Fling, Freecam, Physics Modifiers.
  - `Modules/RunNHide.luau` & `Modules/DisasterSurvival.luau`: Game-specific weapon/utility hooks.
- **UI & Peripheral Widgets Layer**:
  - `UI/UI.luau`: Window lifecycle, drag/resize handling, theme registration & tween engine (`setTheme`).
  - `UI/Animations.luau`: Spring-damper physics engine (`openWindow`, `closeWindow`, `popIn`, `popOut`, `pulseIndicator`, `squashButton`).
  - `UI/PlayerList.luau`, `UI/ChatWidget.luau`, `UI/MusicTracker.luau`, `UI/Notification.luau`.
- **Verification Layer**:
  - `check_services.py`: Static analysis ensuring all `game:GetService(...)` declarations are present and 0 UTF-8 BOM bytes.

---

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Mini Sub-Tabs across All Tabs | Refactor Main, Combat, Visuals, Game, and Settings into horizontal `CreateSubTabs` sub-pages | M1 | ORIGINAL_REQUEST §R1 |
| 2 | Right-Click Tab Hiding & Sync | Sidebar right-click hides tab, Settings tab allows restoring, bidirectional sync via FeatureManager | M1 | ORIGINAL_REQUEST §R1 |
| 3 | Visual Cleanliness & Padding | 2px retro borders, topbar insets, responsive element height, frosted acrylic gradients | M1 | ORIGINAL_REQUEST §R1 |
| 4 | ESP Box Outlines | Secondary black Drawing Square (`Thickness = 3.5`) for high contrast against 3D scenes | M2 | ORIGINAL_REQUEST §R2 |
| 5 | Tracer Origin Selector | Configurable origin: `"Bottom"`, `"Center"`, `"Mouse"` with live viewport calculation | M2 | ORIGINAL_REQUEST §R2 |
| 6 | Distance Tags | 3D stud distance calculation (`math.floor((pos - myPos).Magnitude)`) below bounding box | M2 | ORIGINAL_REQUEST §R2 |
| 7 | Customizable Chams Colors | Color customizers for Highlight `FillColor` and `OutlineColor` in Visuals settings | M2 | ORIGINAL_REQUEST §R2 |
| 8 | Server Hop | Safe pcall HTTP request to Roblox public server list API and TeleportService hop | M3 | ORIGINAL_REQUEST §R2 |
| 9 | Rejoin Server | Safe TeleportService teleport back to current `PlaceId` / `JobId` | M3 | ORIGINAL_REQUEST §R2 |
| 10 | Copy Game/Place/Job IDs | Clipboard copy utilities (`setclipboard`) for PlaceId, GameId, and JobId | M3 | ORIGINAL_REQUEST §R2 |
| 11 | Anti-AFK Timeout Preventer | Safe `LocalPlayer.Idled` event listener with `VirtualUser:ClickButton2` / `CaptureController` | M3 | ORIGINAL_REQUEST §R2 |
| 12 | Click Teleport Tool | Non-handle tool in Backpack + Ctrl+Click binding for instant raycast teleportation | M3 | ORIGINAL_REQUEST §R2 |
| 13 | FOV Circle Color Customizer | Live `Drawing.new("Circle")` Color property customization and theme awareness | M4 | ORIGINAL_REQUEST §R2 |
| 14 | TriggerBot Delay Slider | Configurable delay slider (0.00s – 0.50s) before firing in Combat tab | M4 | ORIGINAL_REQUEST §R2 |
| 15 | Wallbang Thickness Tolerance | Bidirectional forward/backward raycast thickness measurement to allow penetrable covers | M4 | ORIGINAL_REQUEST §R2 |
| 16 | Peripheral Widget Adherence | Theme tokens, 2px borders, topbar insets, micro-interaction spring animations across all 4 widgets | M5 | ORIGINAL_REQUEST §R3 |
| 17 | Static Analysis & UTF-8 BOM Cleanliness | Run `check_services.py` ensuring 0 missing services and 0 UTF-8 BOM bytes | M5 | ORIGINAL_REQUEST §R3 |
| 18 | Live MCP Execution & Git Push | Execute via roblox-mcp with 0 compile errors, git commit, and push to main | M5 | ORIGINAL_REQUEST §R3 |

---

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | UI Architecture & Sub-Tab Decluttering | `Core/CoreUI.luau`, `Core/Main.luau` sub-tab layout restructuring for Main, Combat, Visuals, Game, Settings | none | PLANNED |
| M2 | Visuals Expansion Engine | `Modules/Visuals.luau` (Box outlines, Tracer origins, Distance tags, Chams colors) | M1 | PLANNED |
| M3 | Player Utilities & Game QoL | `Modules/PlayerUtilities.luau` (Server hop, Rejoin, Copy IDs, Anti-AFK, Click TP) | M1 | PLANNED |
| M4 | Combat Refinements | `Modules/Combat.luau` (FOV color, TriggerBot delay, Wallbang thickness tolerance) | M1 | PLANNED |
| M5 | Integration, Review, Audit & Verification | Reviewers, Challengers, Forensic Auditor, check_services.py, BOM check, roblox-mcp execution, git push | M1, M2, M3, M4 | PLANNED |

---

## Interface Contracts

### `CoreUI:CreateSubTabs(parentTab, subTabNames)`
- **Inputs**: `parentTab` (Tab object), `subTabNames` (array of strings, e.g. `{"Aim Assistance", "Hitbox Modifiers"}`)
- **Returns**: `subTabs` dictionary where `subTabs[tabName]` contains `{ Page = ScrollingFrame, LeftColumn = Frame, RightColumn = Frame }`
- **Behavior**: Animates sub-page visibility using `Animations.popIn` / `Animations.pulseIndicator`, synchronizes active sub-tab styling.

### `Modules/Visuals.luau`
- `Visuals.BoxOutlines`: `boolean` (default `false`)
- `Visuals.TracerOrigin`: `"Bottom"` | `"Center"` | `"Mouse"` (default `"Bottom"`)
- `Visuals.Distance`: `boolean` (default `false`)
- `Visuals.ChamsFillColor`: `Color3` (default `Color3.fromRGB(180, 70, 255)`)
- `Visuals.ChamsOutlineColor`: `Color3` (default `Color3.fromRGB(255, 255, 255)`)

### `Modules/PlayerUtilities.luau`
- `PlayerUtilities.ServerHop()` -> `boolean, string` (Safe pcall HTTP + TeleportService)
- `PlayerUtilities.RejoinServer()` -> `boolean, string` (Teleport to current PlaceId/JobId)
- `PlayerUtilities.CopyPlaceId()`, `PlayerUtilities.CopyGameId()`, `PlayerUtilities.CopyJobId()` -> `boolean, string`
- `PlayerUtilities.SetAntiAFK(enabled: boolean)` -> `void` (`Idled` connection management)
- `PlayerUtilities.GiveClickTeleportTool()` -> `Tool`
- `PlayerUtilities.SetClickTeleportEnabled(enabled: boolean)` -> `void`

### `Modules/Combat.luau`
- `Combat.FovColor`: `Color3` (default `Color3.fromRGB(255, 255, 255)`)
- `Combat.TriggerBotDelay`: `number` (0.0 to 0.5s, default `0.05`)
- `Combat.WallbangThickness`: `number` (studs penetration tolerance, 0 to 20, default `5`)

---

## Code Layout
```
Modular-Roblox-Menu/
├── Core/
│   ├── CoreUI.luau             # UI layout & CreateSubTabs engine
│   ├── Main.luau               # Tab instantiation & sub-tab section bindings
│   ├── FeatureManager.luau     # State & configuration manager
│   └── ThemeManager.luau       # Theme manager
├── Modules/
│   ├── Combat.luau             # Silent aim, camera tracking, FOV, triggerbot, wallbang
│   ├── Visuals.luau            # Drawing ESP, Box outlines, Tracer origins, Distance, Chams
│   ├── PlayerUtilities.luau    # Server hop, Rejoin, Copy IDs, Anti-AFK, Click TP
│   ├── Movement.luau           # Flight, speed, noclip, inf jump, fling
│   ├── RunNHide.luau           # Game specific hooks
│   └── DisasterSurvival.luau   # Game specific hooks
├── UI/
│   ├── UI.luau                 # Window management, theme registration
│   ├── Animations.luau         # Spring-damper animation helpers
│   ├── PlayerList.luau         # Player list widget
│   ├── ChatWidget.luau         # Chat widget
│   ├── MusicTracker.luau       # Music tracker widget
│   └── Notification.luau       # Notification banner widget
├── check_services.py           # Roblox services and UTF-8 BOM static analyzer
└── README.md
```
