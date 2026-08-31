# Handoff Report — Explorer 2: Combat Tab Sub-Tab Refactoring Blueprint

## 1. Observation

Direct code examination of `Core/Main.luau` and related modules reveals:

### Current Combat Tab Hierarchy (`Core/Main.luau:251-316`)
- `combatTab` is instantiated on line 122 via `local combatTab = window:CreateTab("Combat")`.
- Columns are instantiated on line 254: `local combatLeftCol, combatRightCol = window:CreateColumns(combatTab)`.
- All Aim Assistance controls (8 toggles, 3 sliders) are packed into a single section `aimSection` under `combatLeftCol`.
- Hitbox controls (1 toggle, 1 slider) are placed in `hitSection` under `combatRightCol`.

### Enumeration of All Combat Controls and Bindings

| Control Name | Type | Feature ID / Slider Name | Default | Target Module Field | Callback Logic |
|---|---|---|---|---|---|
| Silent Aim | Toggle | `"silent_aim"` | `false` | `Combat.SilentAim` | `Combat.SilentAim = enabled` |
| Wall Bang (Shoot Thru Walls) | Toggle | `"wall_bang"` | `false` | `Combat.Wallbang` | `Combat.Wallbang = enabled` |
| Target Head (Off = Torso) | Toggle | `"target_head"` | `true` | `Combat.TargetPart` | `Combat.TargetPart = if enabled then "Head" else "Torso"` |
| Aim Tracking (Camera Lock) | Toggle | `"aim_tracking"` | `false` | `Combat.AimTracking` | `Combat.AimTracking = enabled` |
| Always Lock (Ignore RMB Hold) | Toggle | `"aim_always"` | `false` | `Combat.AimMode` | `Combat.AimMode = if enabled then "Always" else "Hold RMB"` |
| Track Teammates | Toggle | `"track_teammates"` | `false` | `Combat.TrackTeammates` | `Combat.TrackTeammates = enabled` |
| Trigger Bot | Toggle | `"trigger_bot"` | `false` | `Combat.TriggerBot` | `Combat.TriggerBot = enabled` |
| FOV Circle | Toggle | `"fov_circle"` | `false` | `Combat.FovCircle` | `Combat.FovCircle = enabled` |
| FOV Radius | Slider (30-360) | `"FOV Radius"` | `120` | `Combat.FovRadius` | `Combat.FovRadius = value` |
| Hit Chance % | Slider (10-100) | `"Hit Chance %"` | `100` | `Combat.HitChance` | `Combat.HitChance = value` |
| Aim Smoothing | Slider (5-100) | `"Aim Smoothing"` | `25` | `Combat.Smoothing` | `Combat.Smoothing = value / 100` |
| Expand Hitbox's | Toggle | `"expand_hitboxes"` | `false` | `Combat.ExpandHitboxes` | `Combat.ExpandHitboxes = enabled; if not enabled then Combat.resetHitboxes() end` |
| Hitbox Size | Slider (2-30) | `"Hitbox Size"` | `12` | `Combat.HitboxSize` | `Combat.HitboxSize = value` |

### Settings Tab Module Enforcer (`Core/Main.luau:561-569`)
The module master switch `mod_combat` handles global disable:
```luau
window:AddToggle(moduleSection, "mod_combat", "Combat Module", true, nil, function(enabled)
	FeatureManager.setModuleState("combat", enabled)
	if not enabled then
		Combat.SilentAim = false
		Combat.AimTracking = false
		Combat.TriggerBot = false
		Combat.ExpandHitboxes = false
		Combat.resetHitboxes()
	end
end)
```

---

## 2. Logic Chain

1. **Problem**:
   - Packing 11 complex controls into `combatLeftCol` results in excessive vertical length (~420px height), requiring user scrolling and causing UI imbalance relative to `combatRightCol` (only 2 controls, ~90px height).
   - Mixing silent aim/hit scanning, trigger bot automation, camera locking, and visual FOV circles in one flat list increases cognitive load.

2. **Sub-Tab Division Strategy**:
   - Splitting Combat into two dedicated sub-views: `[ Aim Assistance ]` and `[ Hitbox Modifiers ]`.
   - **`[ Aim Assistance ]` Sub-View**:
     - Dual-column arrangement inside the sub-tab container:
       - **Left Column** (`Targeting & Automation`): Silent Aim, Wallbang, Target Part (Head/Torso), Trigger Bot, Track Teammates.
       - **Right Column** (`Tracking & FOV Dynamics`): Camera Lock Aim Tracking, Always Lock, FOV Circle, FOV Radius slider, Hit Chance % slider, Aim Smoothing slider.
     - **Result**: Perfect 5-control vs 6-control balance, near-identical column heights (~180px), zero vertical scrolling needed, high visual density.
   - **`[ Hitbox Modifiers ]` Sub-View**:
     - Dual-column or focused layout:
       - **Left Column** (`Hitbox Expansion`): Expand Hitboxes toggle, Hitbox Size slider.
       - **Right Column** (`Hitbox Operations`): Reset All Hitboxes instant action button, Hitbox status/info card.

3. **Config and Engine Integrity Preservation**:
   - Every single feature ID string (`"silent_aim"`, `"wall_bang"`, `"target_head"`, `"aim_tracking"`, `"aim_always"`, `"track_teammates"`, `"trigger_bot"`, `"fov_circle"`, `"expand_hitboxes"`) and slider ID string (`"FOV Radius"`, `"Hit Chance %"`, `"Aim Smoothing"`, `"Hitbox Size"`) is preserved verbatim.
   - All state callbacks and math conversions (e.g. `Smoothing = value / 100`, `TargetPart = if enabled then "Head" else "Torso"`) remain identical.
   - Profile save/load via `FeatureManager.saveConfig` and `FeatureManager.loadConfig` will continue to map 1:1 with stored JSON files.

---

## 3. Caveats

- `CoreUI:CreateSubTabs` must support returning container objects or sub-tab page tables that are directly compatible with `CoreUI:CreateColumns(subTabObj)`.
- If `CoreUI:CreateColumns` expects `tabObj.Page`, the sub-tab object returned by `CreateSubTabs` must either provide a `.Page` field pointing to its sub-view frame or `CreateColumns` should accept both tab objects and direct frame containers.
- No existing config keys or slider names may be altered or renamed.

---

## 4. Conclusion & Refactoring Blueprint

### Refactored Code Blueprint for `Core/Main.luau`

Replace lines 251-316 of `Core/Main.luau` with the following implementation:

```luau
-- ============================================================
-- COMBAT TAB CONTENT (MINI SUB-TABS: AIM ASSISTANCE & HITBOXES)
-- ============================================================
local combatSubTabs = window:CreateSubTabs(combatTab, { "Aim Assistance", "Hitbox Modifiers" })
local aimSubTab = combatSubTabs["Aim Assistance"]
local hitSubTab = combatSubTabs["Hitbox Modifiers"]

-- ── SUB-TAB 1: AIM ASSISTANCE ────────────────────────────────
local aimLeftCol, aimRightCol = window:CreateColumns(aimSubTab)

-- Left Column: Targeting & Automation
local targetingSection = window:AddSection(aimLeftCol, "Targeting & Automation")

window:AddToggle(targetingSection, "silent_aim", "Silent Aim", false, nil, function(enabled)
	Combat.SilentAim = enabled
end)

window:AddToggle(targetingSection, "wall_bang", "Wall Bang (Shoot Thru Walls)", false, nil, function(enabled)
	Combat.Wallbang = enabled
end)

window:AddToggle(targetingSection, "target_head", "Target Head (Off = Torso)", true, nil, function(enabled)
	Combat.TargetPart = if enabled then "Head" else "Torso"
end)

window:AddToggle(targetingSection, "track_teammates", "Track Teammates", false, nil, function(enabled)
	Combat.TrackTeammates = enabled
end)

window:AddToggle(targetingSection, "trigger_bot", "Trigger Bot", false, nil, function(enabled)
	Combat.TriggerBot = enabled
end)

-- Right Column: Camera Tracking & FOV Dynamics
local trackingSection = window:AddSection(aimRightCol, "Tracking & FOV Dynamics")

window:AddToggle(trackingSection, "aim_tracking", "Aim Tracking (Camera Lock)", false, nil, function(enabled)
	Combat.AimTracking = enabled
end)

window:AddToggle(trackingSection, "aim_always", "Always Lock (Ignore RMB Hold)", false, nil, function(enabled)
	Combat.AimMode = if enabled then "Always" else "Hold RMB"
end)

window:AddToggle(trackingSection, "fov_circle", "FOV Circle", false, nil, function(enabled)
	Combat.FovCircle = enabled
end)

window:AddSlider(trackingSection, "FOV Radius", 30, 360, 120, function(value)
	Combat.FovRadius = value
end)

window:AddSlider(trackingSection, "Hit Chance %", 10, 100, 100, function(value)
	Combat.HitChance = value
end)

window:AddSlider(trackingSection, "Aim Smoothing", 5, 100, 25, function(value)
	Combat.Smoothing = value / 100
end)

-- ── SUB-TAB 2: HITBOX MODIFIERS ──────────────────────────────
local hitLeftCol, hitRightCol = window:CreateColumns(hitSubTab)

-- Left Column: Hitbox Expansion
local hitSection = window:AddSection(hitLeftCol, "Hitbox Expansion")

window:AddToggle(hitSection, "expand_hitboxes", "Expand Hitbox's", false, nil, function(enabled)
	Combat.ExpandHitboxes = enabled
	if not enabled then
		Combat.resetHitboxes()
	end
end)

window:AddSlider(hitSection, "Hitbox Size", 2, 30, 12, function(value)
	Combat.HitboxSize = value
end)

-- Right Column: Hitbox Operations & Utilities
local hitOpsSection = window:AddSection(hitRightCol, "Hitbox Operations")

window:AddButton(hitOpsSection, "Reset All Hitboxes", function()
	Combat.resetHitboxes()
	window:Notify("Hitboxes", "All player hitboxes restored to default", 2.5)
end)
```

---

## 5. Verification Method

1. **Syntax and Luau Static Analysis**:
   - Check file for Luau syntax validity and strict typing compliance (`--!strict`).
   - Verify `CreateSubTabs` return value matches indexing `combatSubTabs["Aim Assistance"]` and `combatSubTabs["Hitbox Modifiers"]`.
2. **Config Key Regression Check**:
   - Verify that all 9 toggle IDs and 4 slider IDs exist in `FeatureManager.register` and match disk configs exactly.
3. **Execution & UI Validation**:
   - Ensure switching between `[ Aim Assistance ]` and `[ Hitbox Modifiers ]` toggles sub-views smoothly without layout jumping or canvas clipping.
   - Verify that all combat features (`Combat.SilentAim`, `Combat.Wallbang`, `Combat.AimTracking`, `Combat.ExpandHitboxes`) toggle as expected.
