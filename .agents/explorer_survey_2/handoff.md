# Window & Popup Transitions Investigation Report (Requirement R2)

## 1. Observation

### 1.1 Current Window Open/Close/Toggle State Across Modules

Direct source inspections revealed the following implementations:

#### A. Main Menu Window (`UI/UI.luau` & `Core/CoreUI.luau`)
- **File**: `UI/UI.luau` (lines 633–683)
- **Mechanism**:
  ```lua
  local function openWindow()
      if isOpen or isTransitioning then return end
      isTransitioning = true
      mainFrame.Visible = true
      mainFrame.Size = UDim2.new(0, 720 * 0.9, 0, 0)
      mainFrame.BackgroundTransparency = 1
      local openTween = TweenService:Create(mainFrame, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
          Size = if minimized then UDim2.new(0, 720, 0, 44) else UDim2.new(0, 720, 0, 480),
          BackgroundTransparency = UI.Theme.BackgroundTransparency
      })
      openTween:Play()
      ...
  end

  local function closeWindow()
      if not isOpen or isTransitioning then return end
      isTransitioning = true
      local closeTween = TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
          Size = UDim2.new(0, 720 * 0.9, 0, 0),
          BackgroundTransparency = 1
      })
      closeTween:Play()
      closeTween.Completed:Connect(function()
          mainFrame.Visible = false
          mainFrame.Size = UDim2.new(0, 720, 0, 480)
          ...
      end)
  end
  ```
- **Observations**:
  - `UIScale` is created at `UI/UI.luau:262` (`local uiScale = Instance.new("UIScale"); uiScale.Scale = 1.0; uiScale.Parent = mainFrame`), but is completely unused for open/close/toggle animations.
  - The current animation alters `mainFrame.Size.Y` to 0 (accordion squeeze), causing child container clipping and scroll reflows.
  - Only `BackgroundTransparency` is tweened; all child elements (labels, strokes, buttons) stay 100% opaque during animation.
  - **Defect in `Core/CoreUI.luau`**: `UI.createWindow` does not return `openWindow`/`closeWindow`/`toggleWindow` to `CoreUI`. In `Core/Main.luau:99`, `_G.__ToggleProjectFihMenu = function() window:Toggle() end` is called, but `CoreUI:Toggle()` is not defined in `CoreUI.luau`, triggering a runtime nil call error when called externally.

#### B. PlayerList Widget (`UI/PlayerList.luau`)
- **File**: `UI/PlayerList.luau` (lines 271–283, 700–705)
- **Mechanism**:
  - Close button tweens `Size = UDim2.new(0, widget.AbsoluteSize.X * 0.9, 0, 0)` with `Quad.In` (line 273).
  - `Toggle()` method (line 700) abruptly toggles `widget.Visible = not widget.Visible` with zero animation.
  - Keybind `Enum.KeyCode.Tab` (in `Core/Main.luau:103`) calls `playerListWidget:Toggle()`.
  - Feature toggle in `Core/Main.luau:634` sets `playerListWidget.Frame.Visible = enabled` directly without animation.

#### C. Chat Widget (`UI/ChatWidget.luau`)
- **File**: `UI/ChatWidget.luau` (lines 881–893, 929–944, 980–988)
- **Mechanism**:
  - Close button tweens `Size` down to `(AbsoluteSize.X * 0.9, 0)` (line 883).
  - Slash keybind (`Enum.KeyCode.Slash`, line 930) abruptly sets `widget.Visible = true`.
  - `ChatWidget.new()` returns table with no `Toggle()`, `Open()`, or `Close()` methods.
  - Feature toggle in `Core/Main.luau:639` sets `chatWidgetInstance.Frame.Visible = enabled` directly.

#### D. Music Tracker Widget (`UI/MusicTracker.luau`)
- **File**: `UI/MusicTracker.luau` (lines 656–667, 670–677)
- **Mechanism**:
  - Close button tweens `Size` down to `(AbsoluteSize.X * 0.9, 0)` (line 658).
  - `Toggle` and `SetVisible` methods (lines 671–676) abruptly toggle `widget.Visible`.

#### E. Notification System (`UI/Notification.luau`)
- **File**: `UI/Notification.luau` (lines 37–44, 142–164)
- **Mechanism**:
  - Slide-in uses `UDim2.new(1, -270, 1, -20 - 74)` with `Enum.EasingStyle.Back, Enum.EasingDirection.Out` (duration 0.35s).
  - Slide-out uses `UDim2.new(1, 40, ...)` with `Enum.EasingStyle.Quad, Enum.EasingDirection.In` (duration 0.25s).
  - Card repositioning (`repositionCards`, line 37) animates stacked notification slots smoothly at `(1, -270, 1, -20 - (i * 74))` with `Quad.Out` (0.2s).

---

### 1.2 Context Menus: Current Positioning & Animation

1. **PlayerList Player Context Menu (`popupFrame` in `UI/PlayerList.luau:286–374, 513–550`)**:
   - Fixed size `220x254`, parented to top-level `ScreenGui` (`ZIndex = 100`).
   - Dynamic positioning logic (lines 527–543):
     - If `widget.AbsolutePosition.X >= POPUP_W + 12`, docks to the left: `posX = wPos.X - POPUP_W - 8`.
     - Otherwise docks to the right: `posX = wPos.X + wSize.X + 8`.
     - Vertical position clamped: `posY = math.clamp(rowAbsPos.Y, 10, math.max(10, vpSize.Y - POPUP_H - 12))`.
   - Animation: Only `BackgroundTransparency` is tweened from 1 to 0 (line 547). No scale pop-in exists; inner buttons and avatar pop in abruptly.

2. **Chat Quick Phrases (`UI/ChatWidget.luau:946–951`)**:
   - Currently, `quickBtn` has NO popup menu. Clicking simply cycles through an inline string array: `sendMessage(quickPhrases[qIdx]); qIdx = (qIdx % #quickPhrases) + 1`.
   - Missing: A visual quick phrases context menu that pops in above/beside `Quick Chat` button with selectable options.

3. **Chat Player Profile Popup (`profilePopup` in `UI/ChatWidget.luau:592–785`)**:
   - Fixed size `190x240`, parented to `ScreenGui` (`ZIndex = 80`).
   - Positioned at click position clamped: `math.clamp(clickPos.X, 10, vp.X - 200)`.
   - Animation: Snaps to `Visible = true` with 0 scale or fade transition.

---

### 1.3 Domino / Cascading Slide-In Animations

1. **PlayerList Rows (`UI/PlayerList.luau:553–660, 689–693`)**:
   - Rows initialized at `Position = UDim2.new(1, 40, 0, 0)`.
   - Slide-in uses `TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)` to `UDim2.new(0, 0, 0, 0)`.
   - Stagger delay: `(i - 1) * 0.04` on initial population (line 691).
   - Removal slides out to `(1, 40, 0, 0)` with `Quad.In` (0.2s) before destroy.

2. **Chat Messages (`UI/ChatWidget.luau:787–827`)**:
   - `addMessage()` creates `msgBtn` and appends to `container`.
   - **Missing**: No animation exists; messages snap into view instantly.

---

### 1.4 Central Animation Suite (`UI/Animations.luau`)
- Contains basic helpers: `tween`, `attachButtonEffects`, `closeWindow`, `openWindow`.
- `Animations.openWindow` and `Animations.closeWindow` (lines 62–84) use accordion size collapsing (`Size.Y = 0`) instead of spring scale (`0.95 -> 1.0`) and unified fade.

---

### 1.5 Service & Static Analysis Baseline
- Executed `python check_services.py`:
  - 15/15 Luau modules inspected.
  - 0 missing services.
  - 0 UTF-8 BOM encoding bytes.

---

## 2. Logic Chain

```
[Observation: Accordion Size.Y tweening squishes content and overrides user drag / manual resize]
       │
       ▼
[Inference: Transitions must not modify frame.Size or frame.Position]
       │
       ▼
[Solution: Attach UIScale instance to each of the 4 window frames (MainWindow, PlayerList, ChatWidget, MusicTracker)]
       │
       ▼
[Scale Transition: 0.95 -> 1.0 (Back.Out 0.24s) on Open; 1.0 -> 0.95 (Quad.In 0.18s) on Close]
       │
       ├─► Position & Size remain 100% untouched during dragging & resizing
       └─► Provides physical spring pop with natural overshoot

[Observation: Direct child element visibility popping occurs when only BackgroundTransparency is tweened]
       │
       ▼
[Solution: Standardize openWindow/closeWindow in Animations.luau to handle UIScale and transparency fading]

[Observation: Chat quick phrases is an inline array cycle without a popup UI]
       │
       ▼
[Solution: Build a dedicated QuickPhrasesPopup in ChatWidget.luau with UIScale pop-in (0.90 -> 1.0) and auto-clamping]

[Observation: Incoming chat messages snap into view without animation]
       │
       ▼
[Solution: Animate incoming MessageLine from UDim2.new(0, 16, 0, 0) with Back.Out (0.22s) and TextTransparency 1 -> 0]

[Observation: CoreUI:Toggle() is missing, causing runtime error on Main Menu toggle]
       │
       ▼
[Solution: Expose Open/Close/Toggle/SetVisible controller on CoreUI instance and UI.createWindow return]
```

---

## 3. Caveats

1. **`UIScale` vs `CanvasGroup`**:
   - `UIScale` scales all GUI objects cleanly around the frame's anchor with zero GPU texture overhead.
   - `CanvasGroup` provides `GroupTransparency` for whole-tree fading, but in some older Roblox environments or low-end mobile devices, nested CanvasGroups can have minor texture caching costs. Using `UIScale` for scale + `BackgroundTransparency` / child fade provides maximum executor compatibility and high framerates.
2. **`UIListLayout` Horizontal Positioning**:
   - In Roblox, when `UIListLayout.FillDirection = Vertical`, `UIListLayout` strictly overrides child `Position.Y`, but allows child `Position.X` and `UDim2.new(0, xOffset, 0, 0)` offsets. This allows horizontal slide-in domino animations on rows and chat messages without breaking vertical layout ordering.
3. **No Code Modification Constraint**:
   - Per explorer role constraints, all code proposals are documented below as clean drop-in specifications for implementers.

---

## 4. Conclusion & Concrete Implementation Recommendations

### 4.1 Requirement R2 Implementation Specifications

#### 1. Centralized Animation Engine (`UI/Animations.luau`)
Update `UI/Animations.luau` to include unified spring-scale window and popup transition functions:

```lua
-- Standard Window Spring Open (0.95 -> 1.0 with Back.Out)
function Animations.openWindow(frame: GuiObject, uiScale: UIScale?, onComplete: (() -> ())?)
    frame.Visible = true
    if uiScale then
        uiScale.Scale = 0.95
        local tween = TweenService:Create(uiScale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Scale = 1.0
        })
        tween:Play()
        if onComplete then tween.Completed:Connect(onComplete) end
    elseif onComplete then
        onComplete()
    end
end

-- Standard Window Spring Close (1.0 -> 0.95 with Quad.In)
function Animations.closeWindow(frame: GuiObject, uiScale: UIScale?, onComplete: (() -> ())?)
    if uiScale then
        local tween = TweenService:Create(uiScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Scale = 0.95
        })
        tween:Play()
        tween.Completed:Connect(function()
            frame.Visible = false
            uiScale.Scale = 1.0
            if onComplete then onComplete() end
        end)
    else
        frame.Visible = false
        if onComplete then onComplete() end
    end
end

-- Standard Popup Spring Pop-In (0.90 -> 1.0 with Back.Out)
function Animations.popIn(frame: GuiObject, uiScale: UIScale?, onComplete: (() -> ())?)
    frame.Visible = true
    if uiScale then
        uiScale.Scale = 0.90
        local tween = TweenService:Create(uiScale, TweenInfo.new(0.20, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Scale = 1.0
        })
        tween:Play()
        if onComplete then tween.Completed:Connect(onComplete) end
    elseif onComplete then
        onComplete()
    end
end

-- Standard Popup Pop-Out (1.0 -> 0.90 with Quad.In)
function Animations.popOut(frame: GuiObject, uiScale: UIScale?, onComplete: (() -> ())?)
    if uiScale then
        local tween = TweenService:Create(uiScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Scale = 0.90
        })
        tween:Play()
        tween.Completed:Connect(function()
            frame.Visible = false
            uiScale.Scale = 1.0
            if onComplete then onComplete() end
        end)
    else
        frame.Visible = false
        if onComplete then onComplete() end
    end
end
```

#### 2. Main Menu Window (`UI/UI.luau` & `Core/CoreUI.luau`)
- In `UI.luau`:
  - Attach `uiScale` to `mainFrame` (already at line 262).
  - Replace `openWindow` and `closeWindow` to call `Animations.openWindow(mainFrame, uiScale)` and `Animations.closeWindow(mainFrame, uiScale)`.
  - Return `toggleWindow`, `openWindow`, `closeWindow`, and `isOpen` from `UI.createWindow`.
- In `CoreUI.luau`:
  - Add `:Toggle()`, `:Open()`, `:Close()`, and `:SetVisible(state)` to `CoreUI` prototype, routing to the window controller.

#### 3. PlayerList Window & Context Menu (`UI/PlayerList.luau`)
- **Window Transitions**:
  - Add `local uiScale = Instance.new("UIScale"); uiScale.Parent = widget`.
  - Replace `Toggle()` in return table with animated `openWindow` / `closeWindow`.
  - Replace `closeBtn.MouseButton1Click` to call `Animations.closeWindow(widget, uiScale)`.
- **Context Menu Pop-in & Auto-positioning**:
  - Add `local popupScale = Instance.new("UIScale"); popupScale.Parent = popupFrame`.
  - In `openContextMenuForPlayer`:
    - Auto-positioning: compute X and Y with screen clamping (8px viewport margin) and flip detection.
    - Trigger `Animations.popIn(popupFrame, popupScale)`.
  - In close / dismiss: call `Animations.popOut(popupFrame, popupScale)`.
- **Domino Rows**:
  - Set initial `rowBtn.Position = UDim2.new(0, 24, 0, 0)`.
  - Tween to `UDim2.new(0, 0, 0, 0)` with `TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out)` staggered with `(i - 1) * 0.035s`.

#### 4. ChatWidget Window, Quick Phrases & Incoming Messages (`UI/ChatWidget.luau`)
- **Window Transitions**:
  - Add `local uiScale = Instance.new("UIScale"); uiScale.Parent = widget`.
  - Implement animated `Toggle()`, `Open()`, `Close()`, and `SetVisible(v)` in the return table.
  - Wire `closeBtn` and `Slash` keybind to use `Animations.openWindow` and `Animations.closeWindow`.
- **Quick Phrases Context Menu**:
  - Create `quickPopup` frame with `UIScale` containing selectable quick phrases (`[ "gg" ]`, `[ "Hello!" ]`, `[ "Nice one!" ]`, `[ "Look out!" ]`, `[ "Need help!" ]`, `[ "AFK" ]`, `[ "On my way!" ]`).
  - Auto-position above `quickBtn` clamped to viewport.
  - Animate with `Animations.popIn(quickPopup, quickScale)`.
- **Player Profile Popup**:
  - Add `UIScale` to `profilePopup` and animate with `Animations.popIn(profilePopup, profileScale)`.
- **Incoming Message Domino Slide-in**:
  - In `addMessage(sender, text)`:
    - Set `msgBtn.Position = UDim2.new(0, 16, 0, 0)` and `msgBtn.TextTransparency = 1`.
    - Tween `Position` to `UDim2.new(0, 0, 0, 0)` (`Back.Out`, 0.22s).
    - Tween `TextTransparency` to `0` (`Quad.Out`, 0.16s).

#### 5. MusicTracker Window (`UI/MusicTracker.luau`)
- Add `local uiScale = Instance.new("UIScale"); uiScale.Parent = widget`.
- Update `Toggle()` and `SetVisible()` to use `Animations.openWindow` and `Animations.closeWindow`.
- Update `closeBtn` to use `Animations.closeWindow(widget, uiScale)`.

#### 6. Notification System (`UI/Notification.luau`)
- Add subtle scale spring pop (`UIScale` 0.92 -> 1.0) along with horizontal slide-in (`UDim2.new(1, -270, 1, targetY)` with `Back.Out`).
- Slide-out smoothly fades transparency and scales to 0.92 before destruction.

---

## 5. Verification Method

### 5.1 Static Verification Commands
Run the service and integrity checker:
```powershell
python check_services.py
```
Expected output: 0 missing services, 0 UTF-8 BOM files across all 15 Luau modules.

### 5.2 Dynamic & Runtime Verification
1. **Window Spring Transitions**:
   - Toggle Main Menu with `RightBracket` or Chat dropdown -> Verify smooth scale (0.95 -> 1.0) without size jumps.
   - Toggle PlayerList with `Tab` -> Verify smooth scale (0.95 -> 1.0) and height preservation.
   - Toggle Chat with `Slash` or button -> Verify smooth scale (0.95 -> 1.0) with custom resize dimensions preserved.
   - Toggle MusicTracker -> Verify smooth scale (0.95 -> 1.0) with uninterrupted 60+ FPS visualizer wave physics.
2. **Context Menu Pop-ins**:
   - Click player row in PlayerList -> Context menu springs in (0.90 -> 1.0 Back.Out) cleanly docked beside row.
   - Click `Quick Chat` in ChatWidget -> Quick phrases popup springs in docked above button.
   - Click player name in chat log -> Profile popup springs in docked at cursor.
3. **Domino Animations**:
   - Open PlayerList -> Player rows cascade slide-in from right (`Position.X = 24 -> 0`).
   - Send/receive chat message -> New message cascades smoothly into chat log with subtle horizontal spring and text fade.
