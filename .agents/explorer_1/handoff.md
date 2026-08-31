# Handoff Report — Explorer 1: Sub-Tab Architecture & CoreUI Investigation

## 1. Observation
- **File**: `A:\Potassium\Modular-Roblox-Menu\Core\CoreUI.luau`
  - Lines 15–76: `CoreUI.new(titleText)` initializes `self.Tabs`, `self.ActiveTab`, `self.ActiveToggles`, and `self.SliderFills`.
  - Lines 78–92: `CoreUI:SetTheme(themeName)` calls `UI.setTheme`, re-triggers `SelectTab(self.ActiveTab)`, and iterates over `self.ActiveToggles` and `self.SliderFills` to reapply accent colors.
  - Lines 94–194: `CoreUI:CreateTab(name, isHiddenFromSidebar)` creates a `TextButton` in `self.Sidebar` and a `ScrollingFrame` (`tabContent`) inside `self.ContentContainer`. `tabContent` is configured with `AutomaticCanvasSize = Enum.AutomaticSize.Y`, `CanvasSize = UDim2.new(0, 0, 0, 0)`, `ScrollBarThickness = 3`, `UIListLayout` (padding = 10, SortOrder = LayoutOrder), and `UIPadding` (left 4, right 8, top 2, bottom 12).
  - Lines 196–303: `CoreUI:SelectTab(tabObj)` executes exit tween on outgoing page (`Position = UDim2.new(0, -22, 0, 0)`, 0.16s Quad In) and enter tween on incoming page (`Position = UDim2.new(0, 24, 0, 0)` -> `(0, 0, 0, 0)`, 0.28s Back Out). It also runs a cascaded domino ripple across child frames (`(idx - 1) * 0.03s`, 0.24s Back Out).
  - Lines 317–358: `CoreUI:CreateColumns(tabObj)` creates `ColumnsContainer` (`Size = UDim2.new(1, 0, 0, 0)`, `AutomaticSize = Enum.AutomaticSize.Y`) parented to `tabObj.Page`. It divides horizontal space into `LeftColumn` (`Size = UDim2.new(0.5, -5, 0, 0)`) and `RightColumn` (`Size = UDim2.new(0.5, -5, 0, 0)`, `Position = UDim2.new(0.5, 5, 0, 0)`).
  - Lines 360–412: `CoreUI:AddSection(parent, title)` creates a section frame with `AutomaticSize = Enum.AutomaticSize.Y` and a boxed header `[ Category Name ]` styled with `Container` background, `Border` stroke, and `TextPrimary` label.
- **File**: `A:\Potassium\Modular-Roblox-Menu\Core\Main.luau`
  - Lines 121–131: Tab creation order: `Main`, `Combat`, `GameTab`, `Visuals`, `Settings` (hidden), `Configs` (hidden).
  - Lines 251–316: Combat tab currently invokes `window:CreateColumns(combatTab)` and populates `combatLeftCol` with "Aim Assistance" (11 controls: 8 toggles, 3 sliders) and `combatRightCol` with "Hitbox Modifiers" (1 toggle, 1 slider).
- **File**: `A:\Potassium\Modular-Roblox-Menu\UI\UI.luau`
  - Lines 10–91: Theme definitions (`Dark`, `Light`, `TranslucentDark`, `TranslucentLight`, `Adaptive`) defining `Background`, `Border`, `BorderDim`, `Accent`, `AccentText`, `TextPrimary`, `TextSecondary`, `Container`, `ContainerDark`.
  - Lines 155–230: `UI.registerThemeElement(inst, propType)` and `UI.setTheme(themeName)` handle automated tween transitions for registered elements.

---

## 2. Logic Chain
1. **Parent Tab Compatibility**:
   - In `Core/Main.luau`, tabs are created via `local combatTab = window:CreateTab("Combat")`.
   - `combatTab` contains `.Page` (a `ScrollingFrame`).
   - For `CoreUI:CreateSubTabs(parentTab, subTabNames)` to be completely flexible, `parentTab` should accept either a tab object table (containing `.Page`) or directly a `GuiObject` (Frame / ScrollingFrame).

2. **Horizontal Mini Sub-Tab Bar Design & Sizing**:
   - The sub-tab bar must be compact and sit at the top of the parent tab's `ScrollingFrame` at `LayoutOrder = 1`.
   - The sub-tab bar container is given `Size = UDim2.new(1, -4, 0, 26)`, `Position = UDim2.new(0, 2, 0, 0)`, `BackgroundColor3 = UI.Theme.ContainerDark`, `BackgroundTransparency = UI.Theme.ContainerDarkTransparency`, with a `UIStroke` (`Color = UI.Theme.Border`, `Thickness = 1.2`), and an internal `UIListLayout` (`FillDirection = Enum.FillDirection.Horizontal`, `Padding = UDim.new(0, 4)`, `HorizontalAlignment = Enum.HorizontalAlignment.Center`).
   - For $N$ sub-tabs, each sub-tab button is sized proportionally:
     $$\text{Width} = \text{UDim2.new}(1 / N, -\lfloor(4 \times (N - 1)) / N\rfloor, 1, 0)$$
     For $N = 2$, this resolves to `UDim2.new(0.5, -2, 1, 0)`, fitting the 26px high bar.
   - Text is formatted with clean brackets: `string.format("[ %s ]", name)`.

3. **Sub-View Container Hierarchy & Canvas Stability**:
   - Beneath the sub-tab bar, at `LayoutOrder = 2`, a `SubViewsContainer` frame is created with `Size = UDim2.new(1, 0, 0, 0)`, `AutomaticSize = Enum.AutomaticSize.Y`, `BackgroundTransparency = 1`.
   - For each sub-tab name in `subTabNames`, a `SubTabPage` frame is created inside `SubViewsContainer`:
     - `Name = name .. "SubPage"`
     - `Size = UDim2.new(1, 0, 0, 0)`
     - `AutomaticSize = Enum.AutomaticSize.Y`
     - `BackgroundTransparency = 1`
     - `Visible = (subTabIndex == 1)`
     - `UIListLayout` (`Padding = UDim.new(0, 8)`, `SortOrder = Enum.SortOrder.LayoutOrder`)
   - Because `AutomaticCanvasSize = Enum.AutomaticSize.Y` on `parentTab.Page` ignores `Visible = false` frames, switching sub-tabs automatically resizes the parent canvas to the exact height of the active sub-tab view without phantom scrolling space or vertical jump.

4. **Spring-Damper Transition & Zero-Jitter Animation**:
   - To eliminate layout popping and vertical stacking during transitions:
     1. The outgoing sub-tab page is immediately set to `Visible = false` and its button tweens back to `Container` bg, `TextSecondary` text, `BorderDim` stroke (0.18s Quad Out), with `ActiveGradient.Enabled = false`.
     2. The incoming sub-tab page is set to `Visible = true` and offset to `Position = UDim2.new(0, 16, 0, 0)`.
     3. The incoming page executes a fluid spring slide-in: `TweenService:Create(newPage, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0, 0, 0, 0) }):Play()`.
     4. The incoming button executes an accent spring bounce: `TweenService:Create(newBtn, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { BackgroundColor3 = UI.Theme.Accent, BackgroundTransparency = 0, TextColor3 = UI.Theme.AccentText }):Play()`, `Thickness = 1.5`, with `ActiveGradient.Enabled = true`.
     5. Cascaded domino ripple: Top-level children of `newPage` (such as `ColumnsContainer` or sections) are staggered by `(idx - 1) * 0.025s` from `Position = UDim2.new(0, 10, 0, 0)` to `UDim2.new(0, 0, 0, 0)` with `EasingStyle.Back, EasingDirection.Out`.

5. **Sub-Tab Object Return & Polymorphism**:
   - The returned `subTabs` object provides:
     - Map lookup: `subTabs["Aim Assistance"]`, `subTabs["Hitbox Modifiers"]`
     - Array lookup: `subTabs[1]`, `subTabs[2]`
     - Method: `subTabs:Select(subTabNameOrIndex)`
     - Field: `subTabs.ActiveSubTab`
   - Each `subTabObj` contains `.Page` (the `SubTabPage` frame) and `.Button`, `.Stroke`, `.Gradient`, `.Name`.
   - `CoreUI:CreateColumns(subTabObj)` or `CoreUI:CreateColumns(subTabObj.Page)` will attach columns directly to that sub-view seamlessly.

6. **Theme Reactivity**:
   - In `CoreUI.new`, initialize `self.SubTabGroups = {}`.
   - `CreateSubTabs` appends the created sub-tab group to `self.SubTabGroups`.
   - In `CoreUI:SetTheme(themeName)`, iterate `self.SubTabGroups` and reapply active/inactive visuals so theme switches dynamically update all sub-tabs across all parent pages without stale accent highlights.

---

## 3. Caveats
- No caveats. The sub-tab system operates within Roblox's native `UIListLayout` and `AutomaticSize` pipeline, avoiding heavy `CanvasGroup` bugs or external animation libraries.

---

## 4. Conclusion & Proposed Implementation Specification

### Blueprint 1: `CoreUI:CreateSubTabs` Implementation in `Core/CoreUI.luau`

```lua
function CoreUI:CreateSubTabs(parentTab: any, subTabNames: {string})
	local parentPage: GuiObject
	if type(parentTab) == "table" and parentTab.Page then
		parentPage = parentTab.Page
	elseif typeof(parentTab) == "Instance" and parentTab:IsA("GuiObject") then
		parentPage = parentTab
	else
		error("[CoreUI:CreateSubTabs] Invalid parentTab provided.")
	end

	-- 1. Horizontal Sub-Tab Bar Container (LayoutOrder = 1)
	local subTabBar = Instance.new("Frame")
	subTabBar.Name = "SubTabBar"
	subTabBar.Size = UDim2.new(1, -4, 0, 26)
	subTabBar.Position = UDim2.new(0, 2, 0, 0)
	subTabBar.BackgroundColor3 = UI.Theme.ContainerDark
	subTabBar.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	subTabBar.BorderSizePixel = 0
	subTabBar.LayoutOrder = 1
	subTabBar.ClipsDescendants = false
	subTabBar.Parent = parentPage
	UI.registerThemeElement(subTabBar, "ContainerDark")

	local barStroke = Instance.new("UIStroke")
	barStroke.Color = UI.Theme.Border
	barStroke.Thickness = 1.2
	barStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	barStroke.Parent = subTabBar
	UI.registerThemeElement(barStroke, "Border")

	local barPadding = Instance.new("UIPadding")
	barPadding.PaddingLeft = UDim.new(0, 3)
	barPadding.PaddingRight = UDim.new(0, 3)
	barPadding.PaddingTop = UDim.new(0, 2)
	barPadding.PaddingBottom = UDim.new(0, 2)
	barPadding.Parent = subTabBar

	local barLayout = Instance.new("UIListLayout")
	barLayout.FillDirection = Enum.FillDirection.Horizontal
	barLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	barLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	barLayout.Padding = UDim.new(0, 4)
	barLayout.SortOrder = Enum.SortOrder.LayoutOrder
	barLayout.Parent = subTabBar

	-- 2. Sub-Pages Container (LayoutOrder = 2)
	local subPagesContainer = Instance.new("Frame")
	subPagesContainer.Name = "SubPagesContainer"
	subPagesContainer.Size = UDim2.new(1, 0, 0, 0)
	subPagesContainer.AutomaticSize = Enum.AutomaticSize.Y
	subPagesContainer.BackgroundTransparency = 1
	subPagesContainer.BorderSizePixel = 0
	subPagesContainer.LayoutOrder = 2
	subPagesContainer.ClipsDescendants = false
	subPagesContainer.Parent = parentPage

	local subPagesLayout = Instance.new("UIListLayout")
	subPagesLayout.SortOrder = Enum.SortOrder.LayoutOrder
	subPagesLayout.Padding = UDim.new(0, 0)
	subPagesLayout.Parent = subPagesContainer

	local subTabs = {
		Bar = subTabBar,
		Container = subPagesContainer,
		ActiveSubTab = nil,
		Tabs = {},
		SubTabList = {},
		OnTabChanged = nil :: ((string, string?) -> ())?
	}

	local numTabs = #subTabNames
	local tabWidthScale = 1 / math.max(1, numTabs)
	local spacingOffset = math.floor((4 * (numTabs - 1)) / numTabs)

	for idx, name in ipairs(subTabNames) do
		-- Sub-Tab Button
		local btn = Instance.new("TextButton")
		btn.Name = name .. "SubTabBtn"
		btn.Size = UDim2.new(tabWidthScale, -spacingOffset, 1, 0)
		btn.BackgroundColor3 = if idx == 1 then UI.Theme.Accent else UI.Theme.Container
		btn.BackgroundTransparency = if idx == 1 then 0 else UI.Theme.ContainerTransparency
		btn.BorderSizePixel = 0
		btn.Text = string.format("[ %s ]", name)
		btn.TextColor3 = if idx == 1 then UI.Theme.AccentText else UI.Theme.TextSecondary
		btn.Font = UI.Fonts.Header
		btn.TextSize = 11
		btn.LayoutOrder = idx
		btn.Parent = subTabBar

		local btnGrad = Instance.new("UIGradient")
		btnGrad.Name = "ActiveGradient"
		btnGrad.Rotation = 90
		btnGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 220))
		})
		btnGrad.Enabled = (idx == 1)
		btnGrad.Parent = btn

		local btnStroke = Instance.new("UIStroke")
		btnStroke.Color = if idx == 1 then UI.Theme.Border else UI.Theme.BorderDim
		btnStroke.Thickness = if idx == 1 then 1.5 else 1.0
		btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		btnStroke.Parent = btn

		-- Sub-Tab Page
		local page = Instance.new("Frame")
		page.Name = name .. "SubPage"
		page.Size = UDim2.new(1, 0, 0, 0)
		page.AutomaticSize = Enum.AutomaticSize.Y
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.Visible = (idx == 1)
		page.ClipsDescendants = false
		page.LayoutOrder = idx
		page.Parent = subPagesContainer

		local pageLayout = Instance.new("UIListLayout")
		pageLayout.Padding = UDim.new(0, 8)
		pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
		pageLayout.Parent = page

		local subTabObj = {
			Name = name,
			Button = btn,
			Page = page,
			Stroke = btnStroke,
			Gradient = btnGrad,
			ParentTab = parentTab,
			Index = idx
		}

		-- Hover effects
		btn.MouseEnter:Connect(function()
			if subTabs.ActiveSubTab ~= subTabObj then
				TweenService:Create(btnStroke, TweenInfo.new(0.12), { Thickness = 1.5, Color = UI.Theme.Border }):Play()
				TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.ContainerDark, TextColor3 = UI.Theme.TextPrimary }):Play()
			end
		end)

		btn.MouseLeave:Connect(function()
			if subTabs.ActiveSubTab ~= subTabObj then
				TweenService:Create(btnStroke, TweenInfo.new(0.12), { Thickness = 1.0, Color = UI.Theme.BorderDim }):Play()
				TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.Container, TextColor3 = UI.Theme.TextSecondary }):Play()
			end
		end)

		btn.MouseButton1Click:Connect(function()
			subTabs:Select(name)
		end)

		subTabs[name] = subTabObj
		subTabs[idx] = subTabObj
		table.insert(subTabs.SubTabList, subTabObj)

		if idx == 1 then
			subTabs.ActiveSubTab = subTabObj
		end
	end

	-- SubTab Selection Function
	function subTabs:Select(target: any)
		local targetObj = if type(target) == "string" then subTabs[target] elseif type(target) == "number" then subTabs[target] else target
		if not targetObj or subTabs.ActiveSubTab == targetObj then return end

		local oldSubTab = subTabs.ActiveSubTab
		subTabs.ActiveSubTab = targetObj

		-- Deactivate Old SubTab
		if oldSubTab then
			oldSubTab.Page.Visible = false
			oldSubTab.Page.Position = UDim2.new(0, 0, 0, 0)
			if oldSubTab.Button and oldSubTab.Stroke then
				TweenService:Create(oldSubTab.Button, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
					BackgroundColor3 = UI.Theme.Container,
					BackgroundTransparency = UI.Theme.ContainerTransparency,
					TextColor3 = UI.Theme.TextSecondary
				}):Play()
				TweenService:Create(oldSubTab.Stroke, TweenInfo.new(0.18), {
					Color = UI.Theme.BorderDim,
					Thickness = 1.0
				}):Play()
				if oldSubTab.Gradient then oldSubTab.Gradient.Enabled = false end
			end
		end

		-- Activate New SubTab Button
		if targetObj.Button and targetObj.Stroke then
			TweenService:Create(targetObj.Button, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				BackgroundColor3 = UI.Theme.Accent,
				BackgroundTransparency = 0,
				TextColor3 = UI.Theme.AccentText
			}):Play()
			TweenService:Create(targetObj.Stroke, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Color = UI.Theme.Border,
				Thickness = 1.5
			}):Play()
			if targetObj.Gradient then targetObj.Gradient.Enabled = true end
		end

		-- Activate New SubTab Page with Spring Dynamics
		targetObj.Page.Visible = true
		targetObj.Page.Position = UDim2.new(0, 16, 0, 0)
		TweenService:Create(targetObj.Page, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 0)
		}):Play()

		-- Domino Ripple for Top-Level Child Elements
		local rippleElements = {}
		for _, child in ipairs(targetObj.Page:GetChildren()) do
			if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
				table.insert(rippleElements, child)
			end
		end

		for idx, elem in ipairs(rippleElements) do
			elem.Position = UDim2.new(0, 10, 0, 0)
			task.delay((idx - 1) * 0.025, function()
				if subTabs.ActiveSubTab == targetObj and elem and elem.Parent then
					TweenService:Create(elem, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
						Position = UDim2.new(0, 0, 0, 0)
					}):Play()
				end
			end)
		end

		if subTabs.OnTabChanged then
			pcall(subTabs.OnTabChanged, targetObj.Name, oldSubTab and oldSubTab.Name)
		end
	end

	function subTabs:GetActive()
		return subTabs.ActiveSubTab
	end

	-- Theme Re-application Handler
	subTabs.UpdateTheme = function()
		for _, tab in ipairs(subTabs.SubTabList) do
			if tab == subTabs.ActiveSubTab then
				tab.Button.BackgroundColor3 = UI.Theme.Accent
				tab.Button.BackgroundTransparency = 0
				tab.Button.TextColor3 = UI.Theme.AccentText
				tab.Stroke.Color = UI.Theme.Border
				tab.Stroke.Thickness = 1.5
				if tab.Gradient then tab.Gradient.Enabled = true end
			else
				tab.Button.BackgroundColor3 = UI.Theme.Container
				tab.Button.BackgroundTransparency = UI.Theme.ContainerTransparency
				tab.Button.TextColor3 = UI.Theme.TextSecondary
				tab.Stroke.Color = UI.Theme.BorderDim
				tab.Stroke.Thickness = 1.0
				if tab.Gradient then tab.Gradient.Enabled = false end
			end
		end
	end

	if not self.SubTabGroups then
		self.SubTabGroups = {}
	end
	table.insert(self.SubTabGroups, subTabs)

	return subTabs
end
```

### Blueprint 2: `CreateColumns` Generalization in `Core/CoreUI.luau`

```lua
function CoreUI:CreateColumns(tabObj: any): (Frame, Frame)
	local parentPage = if type(tabObj) == "table" and tabObj.Page then tabObj.Page elseif typeof(tabObj) == "Instance" then tabObj else nil
	if not parentPage then
		error("[CoreUI:CreateColumns] Expected tabObj table or GuiObject instance.")
	end

	local columnsContainer = Instance.new("Frame")
	columnsContainer.Name = "ColumnsContainer"
	columnsContainer.Size = UDim2.new(1, 0, 0, 0)
	columnsContainer.AutomaticSize = Enum.AutomaticSize.Y
	columnsContainer.BackgroundTransparency = 1
	columnsContainer.BorderSizePixel = 0
	columnsContainer.ClipsDescendants = false
	columnsContainer.Parent = parentPage

	local leftCol = Instance.new("Frame")
	leftCol.Name = "LeftColumn"
	leftCol.Size = UDim2.new(0.5, -5, 0, 0)
	leftCol.Position = UDim2.new(0, 0, 0, 0)
	leftCol.AutomaticSize = Enum.AutomaticSize.Y
	leftCol.BackgroundTransparency = 1
	leftCol.BorderSizePixel = 0
	leftCol.ClipsDescendants = false
	leftCol.Parent = columnsContainer

	local leftLayout = Instance.new("UIListLayout")
	leftLayout.Padding = UDim.new(0, 8)
	leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
	leftLayout.Parent = leftCol

	local rightCol = Instance.new("Frame")
	rightCol.Name = "RightColumn"
	rightCol.Size = UDim2.new(0.5, -5, 0, 0)
	rightCol.Position = UDim2.new(0.5, 5, 0, 0)
	rightCol.AutomaticSize = Enum.AutomaticSize.Y
	rightCol.BackgroundTransparency = 1
	rightCol.BorderSizePixel = 0
	rightCol.ClipsDescendants = false
	rightCol.Parent = columnsContainer

	local rightLayout = Instance.new("UIListLayout")
	rightLayout.Padding = UDim.new(0, 8)
	rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rightLayout.Parent = rightCol

	return leftCol, rightCol
end
```

### Blueprint 3: `CoreUI:SetTheme` Theme Hook in `Core/CoreUI.luau`

```lua
function CoreUI:SetTheme(themeName: string)
	UI.setTheme(themeName)
	-- Reapply active tab and toggle accent visuals
	if self.ActiveTab then
		self:SelectTab(self.ActiveTab)
	end
	for _, fn in ipairs(self.ActiveToggles) do
		fn()
	end
	for _, fill in ipairs(self.SliderFills) do
		if fill and fill.Parent then
			fill.BackgroundColor3 = UI.Theme.Accent
		end
	end
	-- Reapply active subtab visuals across all registered subtab bars
	if self.SubTabGroups then
		for _, subTabGroup in ipairs(self.SubTabGroups) do
			if subTabGroup.UpdateTheme then
				subTabGroup.UpdateTheme()
			end
		end
	end
end
```

---

## 5. Verification Method
1. **API Call Verification**:
   - Inspect that calling `local subTabs = window:CreateSubTabs(combatTab, {"Aim Assistance", "Hitbox Modifiers"})` creates a `SubTabBar` and `SubPagesContainer` under `combatTab.Page`.
2. **Column & Section Nesting**:
   - Verify `window:CreateColumns(subTabs["Aim Assistance"])` correctly parents columns under `subTabs["Aim Assistance"].Page`.
3. **Zero Jitter Check**:
   - Verify `AutomaticCanvasSize` responds strictly to the active `SubTabPage`, with no canvas jumping or height inflation.
4. **Theme Switch Check**:
   - Verify calling `window:SetTheme("Light")` or `window:SetTheme("Dark")` calls `UpdateTheme()` on all `SubTabGroups`, keeping active buttons in `UI.Theme.Accent` and inactive buttons in `UI.Theme.Container`.
