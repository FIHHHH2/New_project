# Comprehensive UI Architecture & Mini Sub-Tabs Analysis Report

## Executive Summary
This investigation analyzes the architecture of the Modular Roblox Menu UI (`Modular-Roblox-Menu`), covering `Core/CoreUI.luau`, `Core/Main.luau`, `UI/UI.luau`, `UI/Animations.luau`, `Core/ThemeManager.luau`, and game modules. The menu utilizes a squared retro aesthetic with 2px borders, 45°/90° frosted acrylic gradient overlays, micro-interaction spring animations, and automatic theme synchronization across 5 themes (`Dark`, `Light`, `TranslucentDark`, `TranslucentLight`, `Adaptive`).

The horizontal mini sub-tab system (`CoreUI:CreateSubTabs`) currently declutters the `Combat` tab into `[ Aim Assistance ]` and `[ Hitbox Modifiers ]`. To achieve visual cleanliness and high density across the entire suite, this architecture report outlines the exact roadmap to extend horizontal mini sub-tabs to **all parent tabs**: `Main` (Movement & Self), `Visuals`, `Game Utils` (Run N Hide / Disaster Survival), and `Settings`.

---

## 1. Core Architecture & Module Breakdown

### 1.1 UI Component Architecture (`Core/CoreUI.luau` & `UI/UI.luau`)
- **ScreenGui Root**:
  - Name: `ModularEngineGui` (CoreGui preferred, fallback to LocalPlayer's `PlayerGui`).
  - Properties: `ResetOnSpawn = false`, `IgnoreGuiInset = true`, `ZIndexBehavior = Sibling`.
- **Main Window Geometry**:
  - MainFrame: `Size = 720 x 480 px`, centered at `Position = (0.5, -360, 0.5, -240)`.
  - Outer Stroke: `UIStroke` (Thickness 2.0px, theme `Border`).
  - Background Gradient: `UIGradient` (Rotation 90, vertical fade with transparency `0.0 -> 0.15`).
  - UIScale: Scale 1.0 (tweens from 0.95 to 1.0 with Back.Out on open; 1.0 to 0.95 Quad.In on close).
- **Layout Zones**:
  1. **TopBar** (`720 x 28 px` at `Y=8, X=8`):
     - `TitleBox` (`220 x 28 px`): GothamBold 12, text `[Title] >>>>>`.
     - `DecoBar` (`UDim2.new(1, -298, 1, 0)`): Clipping frame with repeating mono hatch `>>>>>>>>`.
     - `MinButton` (`30 x 28 px`): Minimizes window height to `44px` (header-only).
     - `CloseButton` (`30 x 28 px`): Close animation handler.
     - Draggable with clamped screen boundaries.
  2. **TopDivider** (`720 x 2 px` at `Y=42`).
  3. **BodyFrame** (`720 x (480 - 62) = 418 px` at `Y=44`):
     - `Sidebar` (`126 x (100% - 12px)` at `X=8, Y=6`): `ScrollingFrame` (`ScrollBarThickness = 0`, `AutomaticCanvasSize = Y`, UIListLayout padding 6px). Holds parent tab buttons (`UDim2.new(1, -4, 0, 30)`).
     - `VertDivider` (`2 x 100% px` at `X=142`).
     - `RightMain` (`UDim2.new(1, -154, 1, -12)` at `X=150, Y=6`):
       - `SubHeader` (`100% x 26 px`): Holds `ActiveTagBox` (`110 x 24 px`), `SettingsBtn` (`72 x 24 px`), and `ConfigsBtn` (`72 x 24 px`).
       - `ContentContainer` (`100% x (100% - 32px)` at `Y=32`): `ClipsDescendants = true`, holds each active tab page.
  4. **FooterBar** (`720 x 14 px` at `Y = 100% - 14px`): Hatch pattern label `/////////` with 1.5px UIStroke.

---

## 2. Horizontal Mini Sub-Tabs Engine (`CoreUI:CreateSubTabs`)

### 2.1 Implementation Mechanics (`CoreUI.luau:378-640`)
The `CoreUI:CreateSubTabs(parentTab, subTabNames)` method constructs a self-contained sub-tab bar and container inside any parent tab's `ScrollingFrame`:

```
Parent ScrollingFrame (Page)
├── SubTabBar (Frame, Height = 26px, LayoutOrder = 1)
│   ├── UIStroke (1.2px, Border)
│   ├── UIPadding (L:3, R:3, T:2, B:2)
│   ├── UIListLayout (Horizontal, Center-aligned, Padding = 4px)
│   └── [ SubTabBtn 1 ] [ SubTabBtn 2 ] ... [ SubTabBtn N ]
└── SubPagesContainer (Frame, AutomaticSize = Y, LayoutOrder = 2)
    ├── UIListLayout (Vertical, Padding = 0px)
    ├── SubPage 1 (Frame, AutomaticSize = Y, LayoutOrder = 1)
    └── SubPage 2 (Frame, AutomaticSize = Y, LayoutOrder = 2)
```

### 2.2 Layout Math & Equal Width Partitioning
For $N$ sub-tabs:
- Scale width: $\text{tabWidthScale} = \frac{1}{\max(1, N)}$
- Spacing offset compensation: $\text{spacingOffset} = \left\lfloor \frac{4 \cdot (N - 1)}{N} \right\rfloor$
- Button Size: $\text{UDim2.new}(\text{tabWidthScale}, -\text{spacingOffset}, 1, 0)$
- This ensures buttons seamlessly fill 100% of the 26px high `SubTabBar` regardless of whether 2, 3, or 4 sub-tabs are configured.

### 2.3 Micro-Interactions & Spring-Damper Physics
1. **Button Active State**:
   - Background: `UI.Theme.Accent` (`BackgroundTransparency = 0`).
   - Text: `UI.Theme.AccentText`.
   - Gradient: `UIGradient` active.
   - Indicator Pulse: `Animations.pulseIndicator(stroke, Accent, Border, 2.2, 1.5)` (surges to 2.2px thickness over 0.09s, settles to 1.5px over 0.15s Quad.Out).
   - Micro-Squash: UIScale compresses to `0.96` on click down, springs back to `1.0` (Back.Out, 0.14s) on click release.
2. **Sub-Page Entrance**:
   - Visible toggled to `true`.
   - Initial Position: `UDim2.new(0, 16, 0, 0)`.
   - Tween: `Position -> (0, 0, 0, 0)` over `0.26s` using `Enum.EasingStyle.Back, Enum.EasingDirection.Out`.
   - Domino Ripple: Child GuiObjects are staggered with `Animations.dominoRipple(elements, 0.025, 10, 0.22)` (0.025s step delay, 10px horizontal slide, 0.22s Back.Out).

---

## 3. Right-Click Tab Hiding & Bidirectional Settings Synchronization

### 3.1 Sidebar Right-Click Mechanism (`CoreUI.luau:199-211`)
- Tab buttons attach to both `MouseButton2Click` and `InputBegan` (MouseButton2).
- If the tab is not `"Main"` and not internally hidden (`IsHidden == false`):
  - Calls `self:SetTabVisibility(tabObj, false)`.
  - Fires notification: `"Module Hidden - '<Tab>' tab hidden. Re-enable in Settings > Game Modules."`.

### 3.2 Visibility Controller (`CoreUI.luau:231-265`)
- Sets `tabObj.IsVisible = visible` and `tabObj.Button.Visible = visible`.
- **Auto-Fallback**: If the hidden tab was the currently active tab (`self.ActiveTab == targetTab`), `CoreUI` iterates over all registered tabs and selects the first visible non-hidden tab (`self:SelectTab(firstVisible)`).
- **Event Dispatch**: Fires `tabObj.OnVisibilityChanged(visible)`.

### 3.3 Bidirectional Synchronization with Settings (`Core/Main.luau:683-783`)
1. **Settings -> Sidebar**:
   - Toggles registered via `FeatureManager.setModuleState("game_module", state)`.
   - Toggle callback calls `window:SetTabVisibility(gameTab, enabled)`.
2. **Sidebar -> Settings**:
   - `gameTab.OnVisibilityChanged` hook is connected:
     ```luau
     gameTab.OnVisibilityChanged = function(vis: boolean)
         local feat = FeatureManager.getFeature("tab_game_module")
         if feat and feat.state ~= vis then
             FeatureManager.setFeatureState("tab_game_module", vis)
         end
     end
     ```
   - When `FeatureManager.setFeatureState` is called, it triggers `feat.onStateChanged(newState)`, which immediately animates the checkmark `[ X ]` and background fill inside the Settings tab, maintaining 100% state synchronization.

---

## 4. Container Padding, Scrolling & Control Metrics

| UI Element | Height (px) | Margins / Padding | Layout / Children Notes |
|---|---|---|---|
| **Tab ScrollingFrame** | 100% | Pad: L:4, R:8, T:2, B:12 | `AutomaticCanvasSize = Y`, `ScrollBarThickness = 3` |
| **SubTabBar** | 26 | Pad: L:3, R:3, T:2, B:2; Gap: 4 | Equal-width partitioned buttons |
| **Two-Column Split** | Auto (Y) | Left: `UDim2.new(0.5, -5, 0, 0)`, Right: `UDim2.new(0.5, -5, 0, 0)` at `X=0.5, +5` | 10px center gap, `AutomaticSize = Y` |
| **Section HeaderBox** | 24 | Size: `1, -4`, Pad: 2 | Gradient 90°, GothamBold 11 |
| **Toggle Row** | 24 | CheckBox (24x24) + Title (1, -90) + Bind (58x24) | 3-segment hover stroke highlight |
| **Slider Row** | 46 | Title (1, -52 x 22) + Val (48x22) + Track (100% x 16 at Y=26) | Hover glow, drag lerp |
| **Button Row** | 26 | TextButton `100% x 26` | Micro-squash UIScale (0.96 -> 1.0) |
| **TextBox Row** | 48 | Title (100% x 20) + InputFrame (100% x 24 at Y=24) | Focus stroke glow (Accent, 1.5px) |
| **PlayerGameBanner** | 88 | Mugshot (78x80) + RightStack (Title, User, AccountAge, PlaceId) | PlaceIcon & Avatar async |

---

## 5. Comprehensive Tab Decluttering & Mini Sub-Tab Roadmap

### 5.1 Tab 1: Main (Player & Movement)
Currently a single dense 2-column page.
**Recommended Mini Sub-Tabs**: `[ Movement & Flight ]`, `[ Physics & Modifiers ]`, `[ Player Utilities ]`

```
MainTab
├── SubTabBar: [ Movement & Flight ] [ Physics & Modifiers ] [ Player Utilities ]
├── SubPage 1: [ Movement & Flight ]
│   ├── LeftCol: Flight & Noclip (Noclip, Infinite Jump, Flight No Fall, Flight Speed)
│   └── RightCol: Speed & Fling (WalkSpeed Boost, Custom Speed, Walk Fling, Fling Mode)
├── SubPage 2: [ Physics & Modifiers ]
│   ├── LeftCol: Jump & Gravity (JumpPower Boost, Custom Gravity, Hip Height Offset)
│   └── RightCol: Ragdoll Mechanics (Ragdoll Walk & Space Jump, Move In Ragdoll, Auto Standup, Ragdoll Speed)
└── SubPage 3: [ Player Utilities ] (New Features)
    ├── LeftCol: Server Utilities (Server Hop, Rejoin Server, Copy Place ID, Copy Job ID)
    └── RightCol: Player Tools (Anti-AFK Disconnect Preventer, Click Teleport Tool, Anti-Fling Protection)
```

### 5.2 Tab 2: Combat
Currently organized with `[ Aim Assistance ]` and `[ Hitbox Modifiers ]`.
**Recommended Mini Sub-Tabs**: `[ Aim Assistance ]`, `[ Camera Tracking ]`, `[ Hitbox Modifiers ]`

```
CombatTab
├── SubTabBar: [ Aim Assistance ] [ Camera Tracking ] [ Hitbox Modifiers ]
├── SubPage 1: [ Aim Assistance ]
│   ├── LeftCol: Silent Aim & Wallbang (Silent Aim, Wallbang, Wallbang Tolerance Slider, Hit Chance %)
│   └── RightCol: Automation (Trigger Bot, Trigger Bot Delay Slider, Target Head/Torso, Track Teammates)
├── SubPage 2: [ Camera Tracking & FOV ]
│   ├── LeftCol: Camera Lock (Aim Tracking, Always Lock, Aim Smoothing Slider)
│   └── RightCol: FOV Visualizer (FOV Circle, FOV Radius Slider, FOV Circle Color Customizer)
└── SubPage 3: [ Hitbox Modifiers ]
    ├── LeftCol: Hitbox Expansion (Expand Hitboxes Toggle, Hitbox Size Slider)
    └── RightCol: Hitbox Operations (Reset All Hitboxes Button, Status Notice)
```

### 5.3 Tab 3: Visuals (ESP & Overlays)
Currently a single 2-column page.
**Recommended Mini Sub-Tabs**: `[ 2D Overlays & ESP ]`, `[ 3D Chams & Skeletons ]`, `[ ESP Customizer ]`

```
VisualsTab
├── SubTabBar: [ 2D Overlays & ESP ] [ 3D Chams & Skeletons ] [ ESP Customizer ]
├── SubPage 1: [ 2D Overlays & ESP ]
│   ├── LeftCol: 2D ESP (2D ESP Box, Box ESP Outlines, Health Bar, Distance Tags)
│   └── RightCol: Tracers & Widgets (Tracers Toggle, Tracers Origin: Bottom/Center/Mouse, Music Tracker Widget)
├── SubPage 2: [ 3D Chams & Skeletons ]
│   ├── LeftCol: Highlights & Chams (3D Chams / Highlights Toggle, Chams Transparency Slider)
│   └── RightCol: Skeletons & Bones (Skeleton ESP Toggle, Bone Thickness)
└── SubPage 3: [ ESP Customizer ] (New Features)
    ├── LeftCol: Color Profiles (Box Color, Tracer Color, Skeleton Color, Chams Color)
    └── RightCol: Display Metrics (Max ESP Distance Slider, Render Names, Render Team Colors)
```

### 5.4 Tab 4: Game Utils (Run N Hide / Disaster Survival)
Currently massive single page (over 20 controls for Run N Hide).
**Recommended Mini Sub-Tabs (Run N Hide)**: `[ Weapons & Firepower ]`, `[ Bounds & Barriers ]`, `[ Mobility & Items ]`

```
GameTab (Run N Hide)
├── SubTabBar: [ Weapons & Firepower ] [ Bounds & Barriers ] [ Mobility & Items ]
├── SubPage 1: [ Weapons & Firepower ]
│   ├── LeftCol: Weapon Mechanics (Silent Gun Audio, Quick Reload, Complete Auto, Semi-Auto Force, Burst Mode, No Recoil, Rapid Fire Overclock)
│   └── RightCol: Fire & Gun Ops (Burst Shot Count Slider, Burst Delay Slider, Force Instant Reload, Chamber Equipped Weapon)
├── SubPage 2: [ Bounds & Barriers ]
│   ├── LeftCol: Map Limits (Disable Map Bounds & Barriers, Disable Kill Bricks & Death Zones, Anti-Void Safety Floor)
│   └── RightCol: Bounds Actions (Audit & Disable All Bounds Now)
└── SubPage 3: [ Mobility & Items ]
    ├── LeftCol: Stamina & Ragdoll (Infinite Stamina, Hyper Fast Stamina Regen, Move In Ragdoll, Auto Standup, Ragdoll Speed)
    └── RightCol: Items & Arena (Role Tracker & ESP, Auto-Grab Dropped Weapons, Grab All Scattered Guns Now, Teleport to PVP Arena)
```

**Recommended Mini Sub-Tabs (Disaster Survival)**: `[ Disaster Intelligence ]`, `[ Physics & Protection ]`

```
GameTab (Natural Disaster)
├── SubTabBar: [ Disaster Intelligence ] [ Physics & Protection ]
├── SubPage 1: [ Disaster Intelligence ]
│   ├── LeftCol: Detection (Disaster Tracker, Check Current Disaster Button, Fall Damage Neutralizer)
│   └── RightCol: Survival Mobility (Flight No Fall Damage, Flight Speed Slider)
└── SubPage 2: [ Physics & Protection ]
    ├── LeftCol: Collision & Protection (Anti-Fling Protection, Godmode Anchor)
    └── RightCol: Interaction (Object / Player Fling Toggle)
```

### 5.5 Tab 5: Settings (System & Preferences)
Currently very dense.
**Recommended Mini Sub-Tabs**: `[ Modules & Tabs ]`, `[ Themes & Visuals ]`, `[ Performance & Rendering ]`, `[ System & Audio ]`

```
SettingsTab
├── SubTabBar: [ Modules & Tabs ] [ Themes & Visuals ] [ Performance & Rendering ] [ System & Audio ]
├── SubPage 1: [ Modules & Tabs ]
│   ├── LeftCol: Tab Visibility (Game Tab, Combat Tab, Visuals Tab, Hide Tab Buttons, Restore All Sidebar Tabs)
│   └── RightCol: Widget Toggles (Music Tracker Widget, Player List Widget, Chat Widget)
├── SubPage 2: [ Themes & Visuals ]
│   ├── LeftCol: Theme Selection (Dark Mode, Light Mode, Translucent Dark, Translucent Light, Adaptive)
│   └── RightCol: GUI Cleaners (Hide Game Default GUIs, Hide Default Game GUIs)
├── SubPage 3: [ Performance & Rendering ]
│   ├── LeftCol: FPS Controls (FPS Boost, FPS Uncap)
│   └── RightCol: 3D Rendering (Don't Render 3D Meshes, Don't Render Decals)
└── SubPage 4: [ System & Audio ]
    ├── LeftCol: Sound & Output (Volume Controller Slider)
    └── RightCol: Suite Diagnostics (Check Services Status, Reload Modules)
```

---

## 6. Implementation Architecture Guide for Feature Coders

### Pattern for Adding Sub-Tabs to Any Tab:
```luau
-- 1. Create SubTabs instance
local mySubTabs = window:CreateSubTabs(parentTab, { "SubTab One", "SubTab Two", "SubTab Three" })
local sub1 = mySubTabs["SubTab One"]
local sub2 = mySubTabs["SubTab Two"]
local sub3 = mySubTabs["SubTab Three"]

-- 2. Create standard 2-column layout inside each sub-tab
local sub1Left, sub1Right = window:CreateColumns(sub1)
local sec1 = window:AddSection(sub1Left, "Section Title")
window:AddToggle(sec1, "toggle_id", "Toggle Name", false, nil, function(val) ... end)

local sub2Left, sub2Right = window:CreateColumns(sub2)
...
```

### Key Technical Guardrails:
1. **Parent References**: Always pass `subTabObj` (which contains `.Page`) to `window:CreateColumns` or `window:AddSection`.
2. **Layout Order**: `SubTabBar` is `LayoutOrder = 1`, `SubPagesContainer` is `LayoutOrder = 2`. Child items inside sub-pages automatically layout without interfering with the subtab bar.
3. **Theme Registration**: `CoreUI:SetTheme` automatically iterates `self.SubTabGroups` and re-applies theme colors and gradients to all sub-tab buttons.
4. **Service Declarations**: Every new utility (`TeleportService`, `HttpService`, `GuiService`, `MarketplaceService`) must be declared via `game:GetService("...")` at the top of the file to pass `check_services.py`.
5. **Encoding**: Ensure all modified files are strictly UTF-8 without BOM.
