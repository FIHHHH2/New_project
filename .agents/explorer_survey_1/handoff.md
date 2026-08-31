# Handoff Report: Micro-Interaction Spring Engine Survey (R1)

## 1. Observation

### 1.1 UI/Animations.luau Architecture
File: `UI/Animations.luau` (87 lines, 3,113 bytes)
- Lines 18–27: `Animations.tween(instance: Instance, properties: {[string]: any}, config: AnimationConfig?): Tween` provides a simple wrapper over `TweenService:Create` with default `0.15s Quad Out`.
- Lines 30–59: `Animations.attachButtonEffects(button: GuiButton, getNormalBg: (() -> Color3)?, getHoverBg: (() -> Color3)?, getActiveBg: (() -> Color3)?)` connects `MouseEnter`, `MouseLeave`, `MouseButton1Down`, `MouseButton1Up` modifying `UIStroke.Thickness` (1.8 on hover, 1.2 on leave) and `Size.Y` offset (-2 on down, +2 with Back easing on up).
- Lines 62–75: `Animations.closeWindow(frame: GuiObject, onComplete: (() -> ())?)` shrinks height to 0 with `0.2s Quad In`.
- Lines 78–84: `Animations.openWindow(frame: GuiObject, targetSize: UDim2)` expands from height 0 with `0.25s Quad Out`.
- **Gaps Observed**: No spring-damper / `UIScale` spring pop helpers for toggle checkmarks, no slider lerp smoothing, no tab indicator pulse engine, no modular micro-squash utility.

### 1.2 Core/CoreUI.luau Controls & Animations
File: `Core/CoreUI.luau` (1125 lines, 38,632 bytes)
- **Toggles (lines 695–844)**:
  - Created as 3 segments: `CheckBtn` (24x24), `TitleBox` (1, -90, 24), `KeybindBtn` (58x24).
  - Lines 783–789: `updateToggleVisual` changes `checkBtn.Text = if state then "X" else ""` instantly with flat quad background tween `TweenService:Create(checkBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), { BackgroundColor3 = ..., BackgroundTransparency = ... })`. Checkmark text is swapped abruptly without spring scale bounce or pop.
  - Hover on segments only tweens `UIStroke.Thickness` (1.2 to 1.8).
- **Sliders (lines 846–984)**:
  - Composed of `TitleBox`, `ValBox` (with `valLabel`), and `SliderTrack` with `Fill` (having a static `UIGradient`).
  - Lines 951–959: Dragging directly mutates `fill.Size = UDim2.new(ratio, 0, 1, 0)` synchronously on `UserInputService.InputChanged`.
  - No smooth lerping / spring smoothing; no track glow on hover/active drag; no scale/pulse feedback on `valLabel`.
- **Buttons (lines 986–1034)**:
  - `ActionBtn` with `UIStroke`.
  - Hover tweens stroke thickness (1.2 -> 1.8) and background to `ContainerDark`.
  - Click tweens background to `Accent` for 0.08s then reverts after 0.15s delay.
  - No micro-squash (`UIScale` 0.95 -> 1.0 overshoot) and no border glow color transition.
- **Tabs & Tab Selection (lines 103–203, 205–312)**:
  - `SelectTab` animates outgoing page `(-22, 0)` (0.16s Quad In) and incoming page `(24, 0) -> (0, 0)` (0.28s Back Out).
  - Incoming tab button springs size `(1, -8, 0, 27) -> (1, -2, 0, 31)` with `0.25s Back Out` and enables `ActiveGradient`.
  - Cascaded domino ripple offsets children by `(0, 12, 0, 0)` with `(idx - 1) * 0.03s` delay.
  - Missing: active tab indicator pulse / glow surge on selection.
- **Sub-Tabs (lines 326–591)**:
  - `CreateSubTabs` builds horizontal bar with `UIListLayout` (Center, 4px padding).
  - `subTabs:Select` activates new subtab button (`0.24s Back Out`), springs incoming sub-page from `(0, 16, 0, 0) -> (0, 0, 0, 0)` (`0.26s Back Out`), and cascades domino ripple with 0.025s stagger.
  - Missing: active sub-tab indicator pulse, micro-squash on click.

### 1.3 Static Integrity & Service Matrix
- Running `python check_services.py` verified all 15 Luau modules:
  - `Core/CoreUI.luau`: 0 missing services, UTF-8 (No BOM).
  - `UI/Animations.luau`: 0 missing services, UTF-8 (No BOM).
  - Total Missing Services: 0
  - Total UTF-8 BOM Files: 0

---

## 2. Logic Chain

1. **Spring-Damper Micro-Interaction Requirement**:
   - Modern responsive UI physics in Roblox rely either on analytical 2nd-order spring damper step simulation (as seen in `MusicTracker.luau` lines 500–506) or high-performance `TweenService` utilizing `Enum.EasingStyle.Back` and `UIScale` components.
   - For UI controls (Toggles, Sliders, Buttons, Tabs), `UIScale` with `TweenService` (`EasingStyle.Back`, `EasingDirection.Out`) provides frame-rate independent, zero-garbage micro-animations that never stutter or cause memory overhead.

2. **Toggle Animation Upgrade**:
   - Instead of static `checkBtn.Text = "X"`, attaching a nested `CheckIcon` (or `CheckMark` TextLabel) with a `UIScale` allows a spring pop scale:
     - When toggled ON: `UIScale.Scale` springs `0.0 -> 1.25 -> 1.0` in 0.20s with `Back.Out`.
     - When toggled OFF: `UIScale.Scale` pops down `1.0 -> 0.0` in 0.12s with `Quad.In`.
     - `checkBtn.BackgroundColor3` smoothly interpolates from `Container` to `Accent` with fluid quad easing.
     - Hover triggers border glow (`Border` -> `Accent` color and 1.2 -> 1.8 thickness).

3. **Slider Animation Upgrade**:
   - When the user drags or clicks the slider track, instead of assigning `fill.Size` immediately, lerp `fill.Size` via `TweenService:Create(fill, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(ratio, 0, 1, 0) }):Play()`. This eliminates stepping and visual jitter.
   - Hover on `SliderTrack` triggers responsive glow: `barStroke.Color` tweens to `Accent` and `Thickness` to 1.6.
   - On value update, `valLabel` receives a micro-bounce (`UIScale` 1.15 -> 1.0 in 0.15s `Back.Out`) to highlight dynamic value changes.

4. **Button Animation Upgrade**:
   - Unify button interactions via `Animations.attachMicroSquash`:
     - MouseEnter: `UIStroke.Color` -> `UI.Theme.Accent`, `Thickness` -> 1.8, `BackgroundColor3` -> `ContainerDark`.
     - MouseLeave: `UIStroke.Color` -> `UI.Theme.Border`, `Thickness` -> 1.2, `BackgroundColor3` -> `Container`.
     - MouseButton1Down: micro-squash `UIScale.Scale = 0.96` (or Y offset -2px) in 0.06s.
     - MouseButton1Up: spring release `UIScale.Scale = 1.0` in 0.14s with `Back.Out` (natural elastic overshoot).
     - MouseButton1Click: instant accent color flash.

5. **Tabs & Sub-Tabs Pulse & Transition Upgrade**:
   - Add `Animations.pulseIndicator(stroke, pulseColor, normalColor)`:
     - On tab / sub-tab switch, the active tab's `UIStroke` performs an indicator pulse: thickness surges `1.5 -> 2.2 -> 1.5` over 0.22s with an intense accent color flash.
     - Incoming tab and sub-tab pages maintain smooth spring slide-in (`Back.Out`) accompanied by staggered domino ripple for child containers.

---

## 3. Caveats

1. **UIScale Hierarchy**: Adding a `UIScale` inside a GuiObject scales that specific GuiObject and all its children relative to its center. For buttons and checkmarks, ensure `AnchorPoint = Vector2.new(0.5, 0.5)` or center positioning is applied when `UIScale` is used, or apply `UIScale` to inner content containers.
2. **Strict Mode & Service Declarations**: Any new service used in `Animations.luau` or `CoreUI.luau` (e.g. `RunService`) must be declared with `game:GetService(...)` at the top of the file to maintain 100% compliance with `check_services.py`.
3. **Roblox Client Thread Safety**: Rapid slider mouse dragging generates many mouse move events; using short (0.05s–0.08s) tweens or continuous lerp variables ensures smooth 60+ FPS performance without accumulating queued tweens.

---

## 4. Conclusion & Proposed Architecture

### Recommended Functions to Add to `UI/Animations.luau`

```luau
-- 1. Spring Pop Scale (for Checkmarks, Icons, Value Badges)
function Animations.popScale(guiObject: GuiObject, startScale: number?, peakScale: number?, endScale: number?, duration: number?): Tween

-- 2. Micro-Squash & Border Glow Feedback (for Action Buttons, Sub-Tab Buttons, Keybind Buttons)
function Animations.attachMicroSquash(
    button: GuiButton, 
    stroke: UIStroke?, 
    getNormalBg: (() -> Color3)?, 
    getHoverBg: (() -> Color3)?, 
    getActiveBg: (() -> Color3)?, 
    getNormalBorder: (() -> Color3)?, 
    getGlowBorder: (() -> Color3)?
)

-- 3. Slider Lerp & Glow Feedback (for Smooth Fill & Track Glow)
function Animations.attachSliderGlow(track: Frame, stroke: UIStroke, fill: Frame, valLabel: TextLabel?)

-- 4. Active Tab Indicator Pulse (for Tab & Sub-Tab Selection)
function Animations.pulseIndicator(stroke: UIStroke, pulseColor: Color3, normalColor: Color3, peakThickness: number?, normalThickness: number?)

-- 5. Unified Domino Ripple (for Tab Pages, Sub-Pages, Player Lists)
function Animations.dominoRipple(elements: {GuiObject}, baseDelay: number?, offsetDistance: number?, duration: number?)
```

### Changes in `Core/CoreUI.luau`
1. **`CoreUI:AddToggle`**:
   - Add inner `CheckIcon` label with `UIScale`.
   - On state change: animate `UIScale` (0.0 -> 1.25 -> 1.0 on enable; 1.0 -> 0.0 on disable) and smooth quad background color tween.
   - Attach border glow on hover for all 3 segments (`checkBtn`, `titleBox`, `keybindBtn`).
2. **`CoreUI:AddSlider`**:
   - Connect hover glow to `SliderTrack` (`UIStroke.Color = Accent`, `Thickness = 1.6`).
   - Smooth `fill.Size` updates via fast lerp tween (`0.06s Quad Out`).
   - Add micro-pop on `valLabel` upon value change.
3. **`CoreUI:AddButton`**:
   - Integrate `Animations.attachMicroSquash` for squash on click and border glow on hover.
4. **`CoreUI:SelectTab` & `CoreUI:CreateSubTabs`**:
   - Trigger `Animations.pulseIndicator` on active tab and sub-tab strokes.
   - Maintain fluid spring page transitions and cascaded domino ripple.

---

## 5. Verification Method

1. **Static Service & BOM Verification**:
   ```powershell
   python check_services.py
   ```
   Must return code `0` with `0 missing services` and `0 UTF-8 BOM files`.

2. **Codebase Inspection**:
   - Verify `UI/Animations.luau` exports all micro-animation helper functions.
   - Verify `Core/CoreUI.luau` calls the new animation functions across `AddToggle`, `AddSlider`, `AddButton`, `CreateTab`, `SelectTab`, and `CreateSubTabs`.
   - Verify `--!strict` typing compliance.

3. **Live Execution Verification**:
   - Execute script in Roblox environment via `roblox-mcp` or executor test suite.
   - Confirm smooth 60 FPS transitions with zero syntax errors, jitter, or layout overflow.
