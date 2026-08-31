--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local UI = require("UI/UI.luau")
local Animations = require("UI/Animations.luau")
local FeatureManager = require("Core/FeatureManager.luau")

local CoreUI = {}
CoreUI.__index = CoreUI

function CoreUI.new(titleText: string)
	local self = setmetatable({}, CoreUI)
	
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ModularEngineGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	
	pcall(function()
		screenGui.Parent = CoreGui
	end)
	if not screenGui.Parent then
		screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
	
	local mainFrame, topbar, sidebar, contentContainer, activeTagLabel, settingsBtn, configsBtn, uiScale = UI.createWindow(titleText)
	mainFrame.Parent = screenGui
	
	self.ScreenGui = screenGui
	self.MainFrame = mainFrame
	self.Sidebar = sidebar
	self.ContentContainer = contentContainer
	self.ActiveTagLabel = activeTagLabel
	self.SettingsBtn = settingsBtn
	self.ConfigsBtn = configsBtn
	self.UiScale = uiScale
	self.Tabs = {}
	self.ActiveTab = nil
	self.PreviousTab = nil
	self.SettingsTab = nil
	self.ConfigsTab = nil
	
	-- Wire toggle click handlers for Settings and Configs
	if self.SettingsBtn then
		self.SettingsBtn.MouseButton1Click:Connect(function()
			if self.SettingsTab then
				if self.ActiveTab == self.SettingsTab then
					self:SelectTab(self.PreviousTab or self.Tabs[1])
				else
					self:SelectTab(self.SettingsTab)
				end
			end
		end)
	end

	if self.ConfigsBtn then
		self.ConfigsBtn.MouseButton1Click:Connect(function()
			if self.ConfigsTab then
				if self.ActiveTab == self.ConfigsTab then
					self:SelectTab(self.PreviousTab or self.Tabs[1])
				else
					self:SelectTab(self.ConfigsTab)
				end
			end
		end)
	end
	
	return self
end

function CoreUI:SetTheme(themeName: string)
	UI.setTheme(themeName)
	-- Reapply active tab accent visual
	if self.ActiveTab then
		self:SelectTab(self.ActiveTab)
	end
end

function CoreUI:CreateTab(name: string, isHiddenFromSidebar: boolean?)
	local tabButton: TextButton? = nil
	local tabStroke: UIStroke? = nil
	
	if not isHiddenFromSidebar then
		tabButton = Instance.new("TextButton")
		tabButton.Name = name .. "TabBtn"
		tabButton.Size = UDim2.new(1, -4, 0, 30)
		tabButton.Position = UDim2.new(0, 2, 0, 0)
		tabButton.BackgroundColor3 = UI.Theme.Container
		tabButton.BackgroundTransparency = UI.Theme.ContainerTransparency
		tabButton.BorderSizePixel = 0
		tabButton.Text = name
		tabButton.TextColor3 = UI.Theme.TextSecondary
		tabButton.Font = UI.Fonts.Header
		tabButton.TextSize = 12
		tabButton.Parent = self.Sidebar
		UI.registerThemeElement(tabButton, "Container")
		UI.registerThemeElement(tabButton, "TextSecondary")
		
		-- Active tab gradient overlay
		local tabGrad = Instance.new("UIGradient")
		tabGrad.Name = "ActiveGradient"
		tabGrad.Rotation = 90
		tabGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 210, 220))
		})
		tabGrad.Enabled = false
		tabGrad.Parent = tabButton
		
		tabStroke = Instance.new("UIStroke")
		tabStroke.Color = UI.Theme.Border
		tabStroke.Thickness = 1.5
		tabStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		tabStroke.Parent = tabButton
		UI.registerThemeElement(tabStroke, "Border")
	end
	
	local tabContent = Instance.new("ScrollingFrame")
	tabContent.Name = name .. "Page"
	tabContent.Size = UDim2.new(1, 0, 1, 0)
	tabContent.BackgroundTransparency = 1
	tabContent.BorderSizePixel = 0
	tabContent.ScrollBarThickness = 3
	tabContent.Visible = false
	tabContent.ClipsDescendants = true
	tabContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tabContent.CanvasSize = UDim2.new(0, 0, 0, 0)
	tabContent.Parent = self.ContentContainer

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 2)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.Parent = tabContent
	
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = tabContent
	
	local tabObj = {
		Name = name,
		Button = tabButton,
		Page = tabContent,
		Stroke = tabStroke,
		Layout = layout,
		IsHidden = isHiddenFromSidebar or false
	}
	
	if tabButton then
		tabButton.MouseButton1Click:Connect(function()
			self:SelectTab(tabObj)
		end)
	end
	
	table.insert(self.Tabs, tabObj)
	
	if not isHiddenFromSidebar and #self.Tabs == 1 then
		self:SelectTab(tabObj)
	end
	
	return tabObj
end

function CoreUI:SelectTab(tabObj)
	if self.ActiveTab and not self.ActiveTab.IsHidden and tabObj.IsHidden then
		self.PreviousTab = self.ActiveTab
	elseif not tabObj.IsHidden then
		self.PreviousTab = nil
	end

	for _, tab in ipairs(self.Tabs) do
		if tab == tabObj then
			tab.Page.Visible = true
			if tab.Button and tab.Stroke then
				tab.Button.BackgroundColor3 = UI.Theme.Accent
				tab.Button.BackgroundTransparency = 0
				tab.Button.TextColor3 = UI.Theme.AccentText
				tab.Stroke.Color = UI.Theme.Border
				local grad = tab.Button:FindFirstChild("ActiveGradient") :: UIGradient?
				if grad then grad.Enabled = true end
			end
		else
			tab.Page.Visible = false
			if tab.Button and tab.Stroke then
				tab.Button.BackgroundColor3 = UI.Theme.Container
				tab.Button.BackgroundTransparency = UI.Theme.ContainerTransparency
				tab.Button.TextColor3 = UI.Theme.TextSecondary
				tab.Stroke.Color = UI.Theme.BorderDim
				local grad = tab.Button:FindFirstChild("ActiveGradient") :: UIGradient?
				if grad then grad.Enabled = false end
			end
		end
	end
	self.ActiveTab = tabObj
	if self.ActiveTagLabel then
		self.ActiveTagLabel.Text = tabObj.Name
	end
	
	-- Keep subheader buttons visible, toggle active highlight styling
	if self.SettingsBtn and self.SettingsBtn:FindFirstChild("UIStroke") then
		local isSet = (tabObj == self.SettingsTab)
		self.SettingsBtn.BackgroundColor3 = if isSet then UI.Theme.Accent else UI.Theme.Container
		self.SettingsBtn.BackgroundTransparency = if isSet then 0 else UI.Theme.ContainerTransparency
		self.SettingsBtn.TextColor3 = if isSet then UI.Theme.AccentText else UI.Theme.TextPrimary
	end

	if self.ConfigsBtn and self.ConfigsBtn:FindFirstChild("UIStroke") then
		local isConf = (tabObj == self.ConfigsTab)
		self.ConfigsBtn.BackgroundColor3 = if isConf then UI.Theme.Accent else UI.Theme.Container
		self.ConfigsBtn.BackgroundTransparency = if isConf then 0 else UI.Theme.ContainerTransparency
		self.ConfigsBtn.TextColor3 = if isConf then UI.Theme.AccentText else UI.Theme.TextPrimary
	end
end

function CoreUI:BindSettingsTab(settingsTabObj)
	self.SettingsTab = settingsTabObj
end

function CoreUI:BindConfigsTab(configsTabObj)
	self.ConfigsTab = configsTabObj
end

function CoreUI:AddBanner(tabObj): Frame
	return UI.createBannerCard(tabObj.Page)
end

function CoreUI:CreateColumns(tabObj): (Frame, Frame)
	local columnsContainer = Instance.new("Frame")
	columnsContainer.Name = "ColumnsContainer"
	columnsContainer.Size = UDim2.new(1, 0, 0, 0)
	columnsContainer.AutomaticSize = Enum.AutomaticSize.Y
	columnsContainer.BackgroundTransparency = 1
	columnsContainer.BorderSizePixel = 0
	columnsContainer.ClipsDescendants = false
	columnsContainer.Parent = tabObj.Page

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

function CoreUI:AddSection(parent: GuiObject, title: string): Frame
	local section = Instance.new("Frame")
	section.Name = title .. "Section"
	section.Size = UDim2.new(1, 0, 0, 0)
	section.AutomaticSize = Enum.AutomaticSize.Y
	section.BackgroundTransparency = 1
	section.BorderSizePixel = 0
	section.ClipsDescendants = false
	section.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = section

	-- standalone boxed header [ Category Name ]
	local headerBox = Instance.new("Frame")
	headerBox.Name = "HeaderBox"
	headerBox.Size = UDim2.new(1, -4, 0, 24)
	headerBox.Position = UDim2.new(0, 2, 0, 0)
	headerBox.BackgroundColor3 = UI.Theme.Container
	headerBox.BackgroundTransparency = UI.Theme.ContainerTransparency
	headerBox.BorderSizePixel = 0
	headerBox.Parent = section
	UI.registerThemeElement(headerBox, "Container")

	local headerGrad = Instance.new("UIGradient")
	headerGrad.Rotation = 90
	headerGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 220, 230))
	})
	headerGrad.Parent = headerBox

	local headerStroke = Instance.new("UIStroke")
	headerStroke.Color = UI.Theme.Border
	headerStroke.Thickness = 1.2
	headerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	headerStroke.Parent = headerBox
	UI.registerThemeElement(headerStroke, "Border")

	local headerLabel = Instance.new("TextLabel")
	headerLabel.Size = UDim2.new(1, 0, 1, 0)
	headerLabel.BackgroundTransparency = 1
	headerLabel.Text = title
	headerLabel.TextColor3 = UI.Theme.TextPrimary
	headerLabel.Font = UI.Fonts.Header
	headerLabel.TextSize = 11
	headerLabel.Parent = headerBox
	UI.registerThemeElement(headerLabel, "TextPrimary")

	return section
end

-- 3-Segment Toggle Row: [ X ] [ Option Name ] [ Bind ]
function CoreUI:AddToggle(section: Frame, featureId: string, name: string, defaultState: boolean, defaultKeybind: Enum.KeyCode?, callback: (boolean) -> ())
	local feature = FeatureManager.register(featureId, name, defaultState, defaultKeybind, callback)
	
	local row = Instance.new("Frame")
	row.Name = featureId .. "Row"
	row.Size = UDim2.new(1, -4, 0, 24)
	row.Position = UDim2.new(0, 2, 0, 0)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.ClipsDescendants = false
	row.Parent = section

	-- Segment 1: [ X ]
	local checkBtn = Instance.new("TextButton")
	checkBtn.Name = "CheckBtn"
	checkBtn.Size = UDim2.new(0, 24, 0, 24)
	checkBtn.Position = UDim2.new(0, 0, 0, 0)
	checkBtn.BackgroundColor3 = if feature.state then UI.Theme.Accent else UI.Theme.Container
	checkBtn.BackgroundTransparency = if feature.state then 0 else UI.Theme.ContainerTransparency
	checkBtn.BorderSizePixel = 0
	checkBtn.Text = if feature.state then "X" else ""
	checkBtn.TextColor3 = UI.Theme.AccentText
	checkBtn.Font = UI.Fonts.Header
	checkBtn.TextSize = 12
	checkBtn.Parent = row
	if not feature.state then
		UI.registerThemeElement(checkBtn, "Container")
	end

	local checkStroke = Instance.new("UIStroke")
	checkStroke.Color = UI.Theme.Border
	checkStroke.Thickness = 1.2
	checkStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	checkStroke.Parent = checkBtn
	UI.registerThemeElement(checkStroke, "Border")

	-- Segment 2: [ Option Name ]
	local titleBox = Instance.new("TextButton")
	titleBox.Name = "TitleBox"
	titleBox.Size = UDim2.new(1, -90, 0, 24)
	titleBox.Position = UDim2.new(0, 28, 0, 0)
	titleBox.BackgroundColor3 = UI.Theme.Container
	titleBox.BackgroundTransparency = UI.Theme.ContainerTransparency
	titleBox.BorderSizePixel = 0
	titleBox.Text = ""
	titleBox.Parent = row
	UI.registerThemeElement(titleBox, "Container")

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = UI.Theme.Border
	titleStroke.Thickness = 1.2
	titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	titleStroke.Parent = titleBox
	UI.registerThemeElement(titleStroke, "Border")

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -8, 1, 0)
	titleLabel.Position = UDim2.new(0, 6, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = name
	titleLabel.TextColor3 = UI.Theme.TextPrimary
	titleLabel.Font = UI.Fonts.Body
	titleLabel.TextSize = 11
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = titleBox
	UI.registerThemeElement(titleLabel, "TextPrimary")

	-- Segment 3: [ Bind ]
	local keybindBtn = Instance.new("TextButton")
	keybindBtn.Name = "KeybindBtn"
	keybindBtn.Size = UDim2.new(0, 58, 0, 24)
	keybindBtn.Position = UDim2.new(1, -58, 0, 0)
	keybindBtn.BackgroundColor3 = UI.Theme.Container
	keybindBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
	keybindBtn.BorderSizePixel = 0
	keybindBtn.Text = if feature.keybind then string.format("[%s]", feature.keybind.Name) else "[None]"
	keybindBtn.TextColor3 = UI.Theme.TextSecondary
	keybindBtn.Font = UI.Fonts.Mono
	keybindBtn.TextSize = 10
	keybindBtn.Parent = row
	UI.registerThemeElement(keybindBtn, "Container")
	UI.registerThemeElement(keybindBtn, "TextSecondary")

	local bindStroke = Instance.new("UIStroke")
	bindStroke.Color = UI.Theme.Border
	bindStroke.Thickness = 1.2
	bindStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bindStroke.Parent = keybindBtn
	UI.registerThemeElement(bindStroke, "Border")

	local function updateToggleVisual(state: boolean)
		checkBtn.BackgroundColor3 = if state then UI.Theme.Accent else UI.Theme.Container
		checkBtn.BackgroundTransparency = if state then 0 else UI.Theme.ContainerTransparency
		checkBtn.Text = if state then "X" else ""
	end

	local function toggleAction()
		local nextState = not feature.state
		FeatureManager.setFeatureState(featureId, nextState)
		updateToggleVisual(nextState)
	end

	checkBtn.MouseButton1Click:Connect(toggleAction)
	titleBox.MouseButton1Click:Connect(toggleAction)

	feature.onKeybindChanged = function(newKey)
		keybindBtn.Text = if newKey then string.format("[%s]", newKey.Name) else "[None]"
	end

	keybindBtn.MouseButton1Click:Connect(function()
		keybindBtn.Text = "[ ... ]"
		keybindBtn.TextColor3 = UI.Theme.Accent
		FeatureManager.promptKeybindCapture(function(selectedKey)
			FeatureManager.setFeatureKeybind(featureId, selectedKey)
			keybindBtn.Text = if selectedKey then string.format("[%s]", selectedKey.Name) else "[None]"
			keybindBtn.TextColor3 = UI.Theme.TextSecondary
		end)
	end)
end

function CoreUI:AddSlider(section: Frame, name: string, min: number, max: number, default: number, callback: (number) -> ())
	local row = Instance.new("Frame")
	row.Name = name .. "SliderRow"
	row.Size = UDim2.new(1, -4, 0, 46)
	row.Position = UDim2.new(0, 2, 0, 0)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.ClipsDescendants = false
	row.Parent = section

	-- header line: [ Option Name ] + [ Val ]
	local titleBox = Instance.new("Frame")
	titleBox.Name = "TitleBox"
	titleBox.Size = UDim2.new(1, -52, 0, 22)
	titleBox.Position = UDim2.new(0, 0, 0, 0)
	titleBox.BackgroundColor3 = UI.Theme.Container
	titleBox.BackgroundTransparency = UI.Theme.ContainerTransparency
	titleBox.BorderSizePixel = 0
	titleBox.Parent = row
	UI.registerThemeElement(titleBox, "Container")

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = UI.Theme.Border
	titleStroke.Thickness = 1.2
	titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	titleStroke.Parent = titleBox
	UI.registerThemeElement(titleStroke, "Border")

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -8, 1, 0)
	titleLabel.Position = UDim2.new(0, 6, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = name
	titleLabel.TextColor3 = UI.Theme.TextPrimary
	titleLabel.Font = UI.Fonts.Body
	titleLabel.TextSize = 11
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = titleBox
	UI.registerThemeElement(titleLabel, "TextPrimary")

	local valBox = Instance.new("Frame")
	valBox.Name = "ValBox"
	valBox.Size = UDim2.new(0, 48, 0, 22)
	valBox.Position = UDim2.new(1, -48, 0, 0)
	valBox.BackgroundColor3 = UI.Theme.Container
	valBox.BackgroundTransparency = UI.Theme.ContainerTransparency
	valBox.BorderSizePixel = 0
	valBox.Parent = row
	UI.registerThemeElement(valBox, "Container")

	local valStroke = Instance.new("UIStroke")
	valStroke.Color = UI.Theme.Border
	valStroke.Thickness = 1.2
	valStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	valStroke.Parent = valBox
	UI.registerThemeElement(valStroke, "Border")

	local valLabel = Instance.new("TextLabel")
	valLabel.Size = UDim2.new(1, 0, 1, 0)
	valLabel.BackgroundTransparency = 1
	valLabel.Text = tostring(default)
	valLabel.TextColor3 = UI.Theme.Accent
	valLabel.Font = UI.Fonts.Mono
	valLabel.TextSize = 11
	valLabel.Parent = valBox

	-- track
	local bar = Instance.new("Frame")
	bar.Name = "SliderTrack"
	bar.Size = UDim2.new(1, 0, 0, 16)
	bar.Position = UDim2.new(0, 0, 0, 26)
	bar.BackgroundColor3 = UI.Theme.ContainerDark
	bar.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	bar.BorderSizePixel = 0
	bar.Parent = row
	UI.registerThemeElement(bar, "ContainerDark")

	local barStroke = Instance.new("UIStroke")
	barStroke.Color = UI.Theme.Border
	barStroke.Thickness = 1.2
	barStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	barStroke.Parent = bar
	UI.registerThemeElement(barStroke, "Border")

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	local initialRatio = math.clamp((default - min) / (max - min), 0, 1)
	fill.Size = UDim2.new(initialRatio, 0, 1, 0)
	fill.BackgroundColor3 = UI.Theme.Accent
	fill.BorderSizePixel = 0
	fill.Parent = bar

	local fillGrad = Instance.new("UIGradient")
	fillGrad.Rotation = 90
	fillGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 210, 210))
	})
	fillGrad.Parent = fill

	local sliding = false

	local function update(input: InputObject)
		local ratio = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		local rawVal = min + (max - min) * ratio
		local val = math.floor(rawVal + 0.5)
		fill.Size = UDim2.new(ratio, 0, 1, 0)
		valLabel.Text = tostring(val)
		callback(val)
	end

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			sliding = true
			update(input)
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					sliding = false
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
			update(input)
		end
	end)
end

function CoreUI:AddButton(section: Frame, name: string, callback: () -> ())
	local row = Instance.new("Frame")
	row.Name = name .. "ButtonRow"
	row.Size = UDim2.new(1, -4, 0, 26)
	row.Position = UDim2.new(0, 2, 0, 0)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.ClipsDescendants = false
	row.Parent = section

	local btn = Instance.new("TextButton")
	btn.Name = "ActionBtn"
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundColor3 = UI.Theme.Container
	btn.BackgroundTransparency = UI.Theme.ContainerTransparency
	btn.BorderSizePixel = 0
	btn.Text = string.format("[ %s ]", name)
	btn.TextColor3 = UI.Theme.TextPrimary
	btn.Font = UI.Fonts.Header
	btn.TextSize = 11
	btn.Parent = row
	UI.registerThemeElement(btn, "Container")
	UI.registerThemeElement(btn, "TextPrimary")

	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = UI.Theme.Border
	btnStroke.Thickness = 1.2
	btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	btnStroke.Parent = btn
	UI.registerThemeElement(btnStroke, "Border")

	btn.MouseButton1Click:Connect(function()
		btn.BackgroundColor3 = UI.Theme.Accent
		task.delay(0.15, function()
			btn.BackgroundColor3 = UI.Theme.Container
		end)
		callback()
	end)
end

return CoreUI
