# Technical Analysis: Gameplay, Combat, Visuals, Movement & Player Utilities

**Working Directory**: `A:\Potassium\Modular-Roblox-Menu`  
**Target Files**:
- `Core/Main.luau` (1,129 lines)
- `Core/CoreUI.luau` (1,260 lines)
- `Core/FeatureManager.luau` (383 lines)
- `Modules/Combat.luau` (326 lines)
- `Modules/Visuals.luau` (294 lines)
- `Modules/Movement.luau` (81 lines)
- `Modules/DisasterSurvival.luau` (264 lines)
- `Modules/RunNHide.luau` (763 lines)

---

## 1. Existing Modules & Architecture Overview

### Current Module Breakdown
| Module | Location | Primary Responsibilities | Current Layout |
|---|---|---|---|
| `Core/Main.luau` | `Core/Main.luau:1–1129` | Suite initialization, tab assembly, self modifiers, movement hooks, game specific logic, settings, configs | `Main`, `Combat` (SubTabs), `Game`, `Visuals`, `Settings`, `Configs` |
| `Core/CoreUI.luau` | `Core/CoreUI.luau:1–1260` | Window creation (`UI.createWindow`), `CreateTab`, `CreateSubTabs`, `CreateColumns`, `AddSection`, `AddToggle`, `AddSlider`, `AddButton`, `AddTextBox`, Window animations | Sub-Tab component (`:CreateSubTabs`) fully supported with active gradient, spring transitions, and indicator pulses |
| `Core/FeatureManager.luau` | `Core/FeatureManager.luau:1–383` | State management, JSON config serialization (`FihSuite/Configs/<name>.json`), keybind dispatcher | `register`, `registerSlider`, `registerModule`, `saveConfig`, `loadConfig`, `deleteConfig` |
| `Modules/Combat.luau` | `Modules/Combat.luau:1–326` | Silent Aim, Wallbang metamethod hooks (`__namecall`, `__index`), Post-Camera BindToRenderStep Aim Tracking, TriggerBot, Hitbox Expander | Self-contained table export `Combat` |
| `Modules/Visuals.luau` | `Modules/Visuals.luau:1–294` | Drawing API based 2D Boxes, Health Bars, Tracers, Skeletons, Highlight 3D Chams | Self-contained table export `Visuals` |
| `Modules/Movement.luau` | `Modules/Movement.luau:1–81` | Standalone Noclip, Fly, Infinite Jump, Gravity Manipulation | Export `Movement.init(window)` |
| `Modules/DisasterSurvival.luau` | `Modules/DisasterSurvival.luau:1–264` | Natural Disaster Survival intelligence, No Fall Damage, Flight, Anti-Fling, 10M rad/s Fling Physics | Export `DisasterSurvival` |
| `Modules/RunNHide.luau` | `Modules/RunNHide.luau:1–763` | Weapon auto/burst/semi-auto hooks, zero recoil, rapid fire, map barrier neutralizer, anti-void, role tracker | Export `RunNHide` |

---

## 2. ESP Engine Analysis & Required Enhancements

### 2.1 Current State in `Modules/Visuals.luau`
- **State Table (`Modules/Visuals.luau:18–29`)**:
  ```luau
  local Visuals = {
      Box2D = false,
      HealthBar = false,
      Tracers = false,
      Skeleton = false,
      Chams = false,
      ChamsTransparency = 0.5,
      BoxColor = Color3.fromRGB(55, 175, 245),
      TracerColor = Color3.fromRGB(255, 255, 255),
      SkeletonColor = Color3.fromRGB(255, 200, 50),
      ChamsColor = Color3.fromRGB(55, 175, 245)
  }
  ```
- **Drawing Allocation (`Modules/Visuals.luau:32–97`)**:
  Per-player `PlayerVisual` struct currently holds:
  - `pv.Box`: `Drawing.new("Square")` (single fill/stroke)
  - `pv.HealthBarBg` & `pv.HealthBarFill`: `Drawing.new("Square")`
  - `pv.Tracer`: `Drawing.new("Line")` (origin hardcoded to `Vector2.new(vp.X / 2, vp.Y)`)
  - `pv.Bones`: `{Drawing.new("Line")}` (14 bones)
  - `pv.Highlight`: `Instance.new("Highlight")`

### 2.2 Required Enhancements & Implementation Specifications

#### A. Box Outlines (High-Contrast Reticle Borders)
1. **State Addition**:
   `Visuals.BoxOutlines: boolean = false`
2. **Type Definition & Object Creation**:
   - In `type PlayerVisual`: Add `BoxOutline: any?`
   - In `createPlayerVisual(player)`:
     ```luau
     local boxOutline = Drawing.new("Square")
     boxOutline.Thickness = 3.5
     boxOutline.Filled = false
     boxOutline.Color = Color3.fromRGB(0, 0, 0)
     boxOutline.Transparency = 1
     boxOutline.Visible = false
     pv.BoxOutline = boxOutline
     ```
3. **Render Step Updates (`updatePlayer`)**:
   ```luau
   if Visuals.Box2D and Visuals.BoxOutlines and pv.BoxOutline then
       pv.BoxOutline.Size = Vector2.new(boxWidth, boxHeight)
       pv.BoxOutline.Position = Vector2.new(boxX, boxY)
       pv.BoxOutline.Visible = true
   elseif pv.BoxOutline then
       pv.BoxOutline.Visible = false
   end
   ```
4. **Cleanup (`cleanPlayerVisual`)**:
   `if pv.BoxOutline then pv.BoxOutline:Remove() end`

#### B. Tracers Origin Selector (`Bottom`, `Center`, `Mouse`)
1. **State Addition**:
   `Visuals.TracerOrigin: string = "Bottom"` -- `"Bottom"`, `"Center"`, or `"Mouse"`
2. **Render Step Calculation**:
   Replace static bottom origin (`Modules/Visuals.luau:215`) with dynamic resolver:
   ```luau
   if Visuals.Tracers and pv.Tracer then
       local origin = Vector2.zero
       local vpSize = Camera.ViewportSize
       if Visuals.TracerOrigin == "Bottom" then
           origin = Vector2.new(vpSize.X / 2, vpSize.Y)
       elseif Visuals.TracerOrigin == "Center" then
           origin = Vector2.new(vpSize.X / 2, vpSize.Y / 2)
       elseif Visuals.TracerOrigin == "Mouse" then
           origin = UserInputService:GetMouseLocation()
       else
           origin = Vector2.new(vpSize.X / 2, vpSize.Y)
       end
       pv.Tracer.From = origin
       pv.Tracer.To = Vector2.new(rootPos.X, rootPos.Y)
       pv.Tracer.Color = Visuals.TracerColor
       pv.Tracer.Visible = true
   elseif pv.Tracer then
       pv.Tracer.Visible = false
   end
   ```

#### C. Distance Tags
1. **State Addition**:
   `Visuals.Distance: boolean = false`
2. **Type Definition & Object Creation**:
   - In `type PlayerVisual`: Add `DistanceTag: any?`
   - In `createPlayerVisual(player)`:
     ```luau
     local distTag = Drawing.new("Text")
     distTag.Size = 12
     distTag.Center = true
     distTag.Outline = true
     distTag.OutlineColor = Color3.fromRGB(0, 0, 0)
     distTag.Color = Color3.fromRGB(240, 240, 240)
     distTag.Font = 2
     distTag.Visible = false
     pv.DistanceTag = distTag
     ```
3. **Render Step Updates (`updatePlayer`)**:
   ```luau
   if Visuals.Distance and pv.DistanceTag then
       local myPos = if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
           then (LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart).Position
           else Camera.CFrame.Position
       local distStuds = math.floor((rootPart.Position - myPos).Magnitude)
       pv.DistanceTag.Text = string.format("[%d m]", distStuds)
       pv.DistanceTag.Position = Vector2.new(rootPos.X, boxY + boxHeight + 3)
       pv.DistanceTag.Visible = true
   elseif pv.DistanceTag then
       pv.DistanceTag.Visible = false
   end
   ```
4. **Cleanup**:
   `if pv.DistanceTag then pv.DistanceTag:Remove() end`

#### D. Customizable Chams Colors
1. **State Additions**:
   `Visuals.ChamsOutlineColor = Color3.fromRGB(255, 255, 255)`
2. **Render Step Application**:
   In `updatePlayer`, dynamically set:
   `pv.Highlight.FillColor = Visuals.ChamsColor`
   `pv.Highlight.OutlineColor = Visuals.ChamsOutlineColor`
   `pv.Highlight.FillTransparency = Visuals.ChamsTransparency`

---

## 3. Player Utilities Implementation Architecture

### 3.1 Required Services
Must declare in `Core/Main.luau` (or utility module):
```luau
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualUser = pcall(function() return game:GetService("VirtualUser") end)
```

### 3.2 Utilities Technical Specifications

#### 1. Server Hop (Public Server API with Safe pcall)
- **Endpoint**: `https://games.roblox.com/v1/games/<placeId>/servers/Public?sortOrder=Asc&limit=100`
- **Method Signature**: `serverHop(): boolean`
- **Logic**:
  1. Fetch server listing via `game:HttpGet(url)`.
  2. Parse with `HttpService:JSONDecode(jsonStr)`.
  3. Filter: `server.id ~= game.JobId and server.playing < server.maxPlayers and server.playing > 0`.
  4. Call `TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)`.
  5. Fallback cleanly with UI notifications on network/rate-limit failure.

#### 2. Rejoin Server
- **Method Signature**: `rejoinServer(): ()`
- **Logic**:
  1. If `#Players:GetPlayers() <= 1`, call `TeleportService:Teleport(game.PlaceId, LocalPlayer)`.
  2. Else, call `TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)`.
  3. Wrap with fallback to `TeleportService:Teleport(game.PlaceId, LocalPlayer)` on error.

#### 3. Copy Place ID / Game ID / Job ID
- **Clipboard Function Fallback**:
  `local setclip = setclipboard or (getgenv and getgenv().setclipboard) or toclipboard or (Clipboard and Clipboard.set)`
- **Implementations**:
  - Copy Place ID: `setclip(tostring(game.PlaceId))`
  - Copy Universe Game ID: `setclip(tostring(game.GameId))`
  - Copy Server Job ID: `setclip(tostring(game.JobId))`

#### 4. Anti-AFK Timeout Preventer
- **Logic**:
  - Connect to `LocalPlayer.Idled`:
    ```luau
    local antiAfkConn: RBXScriptConnection? = nil
    local function toggleAntiAFK(enabled: boolean)
        if enabled then
            antiAfkConn = LocalPlayer.Idled:Connect(function()
                pcall(function()
                    local vu = game:GetService("VirtualUser") or (game:FindService("VirtualUser") :: any)
                    if vu then
                        vu:CaptureController()
                        vu:ClickButton2(Vector2.new(0, 0))
                    end
                end)
            end)
        elseif antiAfkConn then
            antiAfkConn:Disconnect()
            antiAfkConn = nil
        end
    end
    ```

#### 5. Click Teleport Tool & Keybind
- **Tool Creation**:
  - `tool = Instance.new("Tool")`, `Name = "Click Teleport"`, `RequiresHandle = false`, `CanBeDropped = false`.
  - `tool.Activated:Connect(function() ... targetHrp.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0)) end)`
  - Placed into `LocalPlayer.Backpack`.
- **Keyboard Shortcut Mode**:
  - `Ctrl + Left Click` teleport listener via `UserInputService.InputBegan`.

---

## 4. Combat Refinements Technical Specifications

### 4.1 FOV Circle Color Customizer
- **State in `Modules/Combat.luau`**:
  `Combat.FovColor: Color3 = Color3.fromRGB(55, 175, 245)`
- **Render Loop**:
  `fovDrawing.Color = Combat.FovColor` (already bound at `Modules/Combat.luau:267`).
- **UI Exposure**:
  Provide color preset buttons or color cycler in `Core/Main.luau` Combat tab (`[ Cyan ]`, `[ Red ]`, `[ Green ]`, `[ Gold ]`, `[ Violet ]`, `[ White ]`).

### 4.2 TriggerBot Delay Slider
- **State in `Modules/Combat.luau:33`**:
  `Combat.TriggerBotDelay: number = 0.05`
- **Execution Hook (`Modules/Combat.luau:225–258`)**:
  `if now - lastTriggerTime < Combat.TriggerBotDelay then return end`
- **UI Exposure**:
  Add slider: `window:AddSlider(targetingSection, "TriggerBot Delay (ms)", 0, 500, 50, function(val) Combat.TriggerBotDelay = val / 1000 end)`

### 4.3 Wallbang Thickness Tolerance (Bidirectional Raycast Penetration)
- **State Addition in `Modules/Combat.luau`**:
  `Combat.WallbangThickness: number = 10` -- Max wall thickness in studs (0 = infinite / bypass all)
- **Penetration Depth Detection Algorithm**:
  ```luau
  local function canPenetrateWall(origin: Vector3, targetPart: BasePart, maxThickness: number): boolean
      if maxThickness <= 0 then return true end
      local dir = targetPart.Position - origin
      local dist = dir.Magnitude
      if dist < 0.1 then return true end
      local unitDir = dir.Unit

      -- 1. Raycast Forward from Origin to Target
      local pForward = RaycastParams.new()
      pForward.FilterType = Enum.RaycastFilterType.Exclude
      pForward.FilterDescendantsInstances = { LocalPlayer.Character }
      pForward.IgnoreWater = true
      local rForward = Workspace:Raycast(origin, unitDir * dist, pForward)
      if not rForward then return true end
      if rForward.Instance:IsDescendantOf(targetPart.Parent) then return true end

      -- 2. Raycast Backward from Target to Origin
      local pBackward = RaycastParams.new()
      pBackward.FilterType = Enum.RaycastFilterType.Exclude
      pBackward.FilterDescendantsInstances = { targetPart.Parent }
      pBackward.IgnoreWater = true
      local rBackward = Workspace:Raycast(targetPart.Position, -unitDir * dist, pBackward)
      if not rBackward then return true end

      -- 3. Calculate Obstacle Thickness
      local wallThickness = (rBackward.Position - rForward.Position).Magnitude
      return wallThickness <= maxThickness
  end
  ```
- **Integration**:
  - In `Combat.getClosestTarget`: Check `canPenetrateWall(camPos, targetPart, Combat.WallbangThickness)` before accepting target.
  - In UI: `window:AddSlider(targetingSection, "Wallbang Max Wall (studs)", 1, 50, 10, function(val) Combat.WallbangThickness = val end)`.

---

## 5. Main UI Layout & Mini Sub-Tab Architecture

To achieve zero vertical clutter and maximize usability, all parent tabs in `Core/Main.luau` will leverage `CoreUI:CreateSubTabs`:

```
Main Window
├── Main Tab
│   ├── [ Self Modifiers ]        (WalkSpeed, JumpPower, Custom Speed, Hip Height)
│   ├── [ Physics & Movement ]    (Noclip, Inf Jump, Walk Fling, Ragdoll WASD/Space, Gravity)
│   └── [ Player Utilities ]      (Click TP Tool, Ctrl+Click TP, Anti-AFK, Server Hop, Rejoin, Copy IDs)
│
├── Combat Tab
│   ├── [ Aim Assistance ]        (Silent Aim, Wallbang, Max Wall Slider, Head/Torso, Track Teammates, TriggerBot, Delay Slider, FOV Circle, Radius, Hit Chance, Smoothing, FOV Colors)
│   └── [ Hitbox Modifiers ]      (Expand Hitboxes, Hitbox Size Slider, Reset All Hitboxes)
│
├── Game Tab (Dynamic: Run N Hide / Disaster Survival)
│   ├── Run N Hide:
│   │   ├── [ Weapon Overclocks ] (Silent Audio, Quick Reload, Full Auto, Semi Auto, Burst, Zero Recoil, Rapid Fire)
│   │   ├── [ Bounds & Safety ]   (Disable Barriers, Disable Killbricks, Anti-Void Floor, Neutralize Audit)
│   │   └── [ Mobility & Items ]  (Inf Stamina, Fast Regen, Ragdoll WASD, Auto Standup, Role ESP, Auto Grab, Arena TP)
│   └── Disaster Survival:
│       ├── [ Disaster Tracker ]  (Disaster Tracker, Notify Current Disaster)
│       ├── [ Flight & Safety ]   (No Fall Damage, Flight with No Fall Damage, Flight Speed)
│       └── [ Physics & Fling ]   (Anti-Fling Clamping, Player Fling Torque)
│
├── Visuals Tab
│   ├── [ 2D ESP & Overlays ]     (2D Box, Box Outlines, Health Bar, Distance Tags, Tracers, Tracer Origin: Bottom/Center/Mouse, Music Widget)
│   ├── [ 3D Chams & Skeletons ]  (3D Chams Highlight, Chams Transparency, Skeleton ESP)
│   └── [ Color Customization ]   (Chams Colors, Box Colors, Tracer Colors)
│
├── Settings Tab
│   ├── [ Game Modules & UI ]     (Sidebar Tab Toggles, Restore Sidebar Tabs, Widget Toggles)
│   ├── [ Themes & Audio ]        (Dark, Light, Acrylic, Glass, Adaptive, Master Volume Slider)
│   └── [ Performance & Render ]  (FPS Boost, FPS Uncap, Hide Default Game GUIs, Don't Render Meshes/Decals)
│
└── Configs Tab
    ├── Left: Saved Configuration Profiles list
    └── Right: Profile Name input, Create & Save, Save / Overwrite, Load Selected, Delete Selected, Refresh List
```
