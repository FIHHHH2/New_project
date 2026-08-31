# Project: Modular Roblox Menu — GUI Animation & Visual Overhaul

## Architecture
The Modular Roblox Menu consists of a core UI foundation and 4 standalone widgets connected via a central Theme and Animation engine:
- `UI/Animations.luau`: Central spring-damper / TweenService animation library providing window transitions, micro-squash, spring pop scaling, indicator pulses, and domino ripples.
- `UI/UI.luau`: Core window creation, theme engine (`UI.Themes`, `UI.setTheme`, `UI.RegisteredElements`), and retro layout styling.
- `Core/CoreUI.luau`: Component abstraction layer providing high-density controls (Toggles, Sliders, Buttons, Inputs, Tabs, SubTabs) and window control methods (`:Toggle()`, `:Open()`, `:Close()`).
- `UI/PlayerList.luau`: Standalone player list widget with dynamic player cards, context action menus, and domino row ripples.
- `UI/ChatWidget.luau`: Standalone chat widget with quick phrases popup, profile popup, and incoming message domino animations.
- `UI/MusicTracker.luau`: Standalone music player widget with audio polling, 60+ FPS spring visualizer, and adaptive theme sync.
- `UI/Notification.luau`: Stacked floating notification manager with spring slide-in and auto-card repositioning.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Micro-Interaction Spring Engine | `Animations.luau` helpers (`popScale`, `attachMicroSquash`, `attachSliderGlow`, `pulseIndicator`, `openWindow`, `closeWindow`, `popIn`, `popOut`, `dominoRipple`) | M1 | Survey 1 |
| 2 | Toggle Micro-Animations | Checkmark spring pop scale (`0.0 -> 1.25 -> 1.0`), fluid background accent fill, border glow on hover | M1 | Survey 1 |
| 3 | Slider Smooth Lerp & Glow | Smooth `0.06s Quad` fill track lerping, track border glow on hover, `valLabel` micro-bounce feedback | M1 | Survey 1 |
| 4 | Button Micro-Squash & Border Glow | `UIScale` 0.96 squash on click, 1.0 `Back.Out` spring release, border glow to Accent on hover | M1 | Survey 1 |
| 5 | Tab & Sub-Tab Indicator Pulse | Active tab/sub-tab stroke indicator pulse (`1.5 -> 2.2 -> 1.5`), fluid spring page transitions | M1 | Survey 1 |
| 6 | Window Scale & Fade Transitions | `UIScale` spring scale (`0.95 -> 1.0 Back.Out` / `1.0 -> 0.95 Quad.In`) across Main Menu, PlayerList, ChatWidget, MusicTracker | M2 | Survey 2 |
| 7 | CoreUI Window Controller Methods | Expose `:Toggle()`, `:Open()`, `:Close()`, `:SetVisible()` on `CoreUI` instance to prevent nil runtime call errors | M2 | Survey 2 |
| 8 | PlayerList Context Menu Pop-in | Auto-docking, screen-clamped context popup with `UIScale` spring pop-in (`0.90 -> 1.0 Back.Out`) | M2 | Survey 2 |
| 9 | PlayerList Domino Row Ripple | Cascaded slide-in for player rows (`Position.X = 24 -> 0`, `0.035s` stagger, `Back.Out`) | M2 | Survey 2 |
| 10 | Chat Quick Phrases Context Menu | Interactive popup above Quick Chat button with selectable phrases and `UIScale` pop-in | M2 | Survey 2 |
| 11 | Chat Message Domino Animation | Cascaded slide-in for incoming chat messages (`Position.X = 16 -> 0`, text fade 1 -> 0) | M2 | Survey 2 |
| 12 | MusicTracker & Notification Polish | `UIScale` spring window transitions for MusicTracker, subtle scale spring pop for Notifications | M2 | Survey 2 |
| 13 | Theme 0.2s Quad Color Interpolation | Smooth simultaneous color transition across all registered elements in all 4 widgets on theme switch | M3 | Survey 3 |
| 14 | Theme RegisteredElements Pruning | Dead-instance pruning in `UI.setTheme` to eliminate memory leaks from destroyed rows/cards | M3 | Survey 3 |
| 15 | Typography & Retro Borders Polish | GothamBold headers, GothamMedium body, Code mono tags, crisp 90-deg retro borders (`BorderSizePixel = 0`, `UIStroke`) | M3 | Survey 3 |
| 16 | Static Service & BOM Verification | `python check_services.py` 100% pass (0 missing services, 0 BOM bytes across 15 Luau modules) | M4 | Survey 3 |
| 17 | Git Commit & Push | Clean git commit and push to `origin/main` | M4 | Survey 3 |
| 18 | Live Roblox MCP Verification | Live execution probe on active Roblox client via `roblox-mcp` with 0 compile errors | M4 | Survey 3 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Micro-Interaction Spring Engine | Features 1–5: `UI/Animations.luau` & `Core/CoreUI.luau` | none | DONE |
| 2 | Window & Popup Transitions | Features 6–12: `UI/UI.luau`, `PlayerList.luau`, `ChatWidget.luau`, `MusicTracker.luau`, `Notification.luau` | M1 | DONE |
| 3 | Theme Transitions & Visual Polish | Features 13–15: `UI/UI.luau`, `Core/ThemeManager.luau`, all widgets | M1, M2 | IN_PROGRESS |
| 4 | Static Analysis, Git Push & Live MCP | Features 16–18: `check_services.py`, Git push, live Roblox MCP probe | M1, M2, M3 | IN_PROGRESS |

## Interface Contracts
### `UI/Animations.luau` ↔ `Core/CoreUI.luau` & Widgets
- `Animations.popScale(guiObject: GuiObject, startScale: number?, peakScale: number?, endScale: number?, duration: number?): Tween`
- `Animations.attachMicroSquash(button: GuiButton, stroke: UIStroke?, getNormalBg: (() -> Color3)?, getHoverBg: (() -> Color3)?, getActiveBg: (() -> Color3)?, getNormalBorder: (() -> Color3)?, getGlowBorder: (() -> Color3)?)`
- `Animations.attachSliderGlow(track: Frame, stroke: UIStroke, fill: Frame, valLabel: TextLabel?)`
- `Animations.pulseIndicator(stroke: UIStroke, pulseColor: Color3, normalColor: Color3, peakThickness: number?, normalThickness: number?)`
- `Animations.openWindow(frame: GuiObject, uiScale: UIScale?, onComplete: (() -> ())?)`
- `Animations.closeWindow(frame: GuiObject, uiScale: UIScale?, onComplete: (() -> ())?)`
- `Animations.popIn(frame: GuiObject, uiScale: UIScale?, onComplete: (() -> ())?)`
- `Animations.popOut(frame: GuiObject, uiScale: UIScale?, onComplete: (() -> ())?)`
- `Animations.dominoRipple(elements: {GuiObject}, baseDelay: number?, offsetDistance: number?, duration: number?)`

### `Core/CoreUI.luau` Window Controller Contract
- `CoreUI:Toggle()` -> toggles main window with spring animation
- `CoreUI:Open()` -> opens main window with spring animation
- `CoreUI:Close()` -> closes main window with spring animation
- `CoreUI:SetVisible(state: boolean)` -> sets visibility with animation

## Code Layout
- `UI/Animations.luau`: Central animation module (Verified & Complete)
- `Core/CoreUI.luau`: High-density control creation (Verified & Complete)
- `UI/UI.luau`: Window container & theme interpolation (Verified & Complete)
- `UI/PlayerList.luau`: Player list widget (Verified & Complete)
- `UI/ChatWidget.luau`: Chat widget (Verified & Complete)
- `UI/MusicTracker.luau`: Music tracker widget (Verified & Complete)
- `UI/Notification.luau`: Notification widget (Verified & Complete)
