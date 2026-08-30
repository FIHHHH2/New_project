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
	
	local mainFrame, topbar, sidebar, contentContainer, activeTagLabel, uiScale = UI.createWindow(titleText)
	mainFrame.Parent = screenGui
	
	self.ScreenGui = screenGui
	self.MainFrame = mainFrame
	self.Sidebar = sidebar
	self.ContentContainer = contentContainer
	self.ActiveTagLabel = activeTagLabel
	self.UiScale = uiScale
	self.Tabs = {}
	self.ActiveTab = nil
	
	return self
end

function CoreUI:CreateTab(name: string)
	local tabButton = Instance.new("TextButton")
	tabButton.Name = name .. "TabBtn"
	tabButton.Size = UDim2.new(1, -6, 0, 30)
	tabButton.BackgroundColor3 = UI.Theme.Container
	tabButton.BorderSizePixel = 0
	tabButton.Text = name
	tabButton.TextColor3 = UI.Theme.TextSecondary
	tabButton.Font = UI.Theme.HeaderFont
	tabButton.TextSize = 12
	tabButton.Parent = self.Sidebar
	
	local tabStroke = Instance.new("UIStroke")
	tabStroke.Color = UI.Theme.Border
	tabStroke.Thickness = 1.5
	tabStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	tabStroke.Parent = tabButton
	
	local tabContent = Instance.new("ScrollingFrame")
	tabContent.Name = name .. "Page"
	tabContent.Size = UDim2.new(1, 0, 1, 0)
	tabContent.BackgroundTransparency = 1
	tabContent.ScrollBarThickness = 3
	tabContent.Visible = false
	tabContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tabContent.CanvasSize = UDim2.new(0, 0, 0, 0)
	tabContent.Parent = self.ContentContainer
	
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = tabContent
	
	local tabObj = {
		Name = name,
		Button = tabButton,
		Page = tabContent,
		Stroke = tabStroke,
		Layout = layout
	}
	
	tabButton.MouseButton1Click:Connect(function()
		self:SelectTab(tabObj)
	end)
	
	table.insert(self.Tabs, tabObj)
	
	if #self.Tabs == 1 then
		self:SelectTab(tabObj)
	end
	
	return tabObj
end

function CoreUI:SelectTab(tabObj)
	for _, tab in ipairs(self.Tabs) do
		if tab == tabObj then
			tab.Page.Visible = true
			tab.Button.BackgroundColor3 = UI.Theme.Accent
			tab.Button.TextColor3 = UI.Theme.AccentText
			tab.Stroke.Color = UI.Theme.Border
		else
			tab.Page.Visible = false
			tab.Button.BackgroundColor3 = UI.Theme.Container
			tab.Button.TextColor3 = UI.Theme.TextSecondary
			tab.Stroke.Color = UI.Theme.BorderDim
		end
	end
	self.ActiveTab = tabObj
	if self.ActiveTagLabel then
		self.ActiveTagLabel.Text = tabObj.Name
	end
end

function CoreUI:AddSection(tabObj, title: string): Frame
	local section = Instance.new("Frame")
	section.Name = title .. "Section"
	section.Size = UDim2.new(1, -8, 0, 0)
	section.AutomaticSize = Enum.AutomaticSize.Y
	section.BackgroundColor3 = UI.Theme.Container
	section.BackgroundTransparency = 0.3
	section.BorderSizePixel = 0
	section.Parent = tabObj.Page
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = UI.Theme.Border
	stroke.Thickness = 1.2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = section
	
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = section
	
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = section
	
	-- header label box
	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 18)
	header.BackgroundTransparency = 1
	header.Text = string.format("[ %s ]", title)
	header.TextColor3 = UI.Theme.Accent
	header.Font = UI.Theme.HeaderFont
	header.TextSize = 12
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = section
	
	return section
end

function CoreUI:AddToggle(section: Frame, featureId: string, name: string, defaultState: boolean, defaultKeybind: Enum.KeyCode?, callback: (boolean) -> ())
	local feature = FeatureManager.register(featureId, name, defaultState, defaultKeybind, callback)
	
	local row = Instance.new("Frame")
	row.Name = featureId .. "Row"
	row.Size = UDim2.new(1, 0, 0, 26)
	row.BackgroundTransparency = 1
	row.Parent = section
	
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -120, 1, 0)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = name
	title.TextColor3 = UI.Theme.TextPrimary
	title.Font = UI.Theme.BodyFont
	title.TextSize = 12
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = row
	
	-- squared checkbox toggle box
	local toggleButton = Instance.new("TextButton")
	toggleButton.Name = "ToggleBox"
	toggleButton.Size = UDim2.new(0, 22, 0, 22)
	toggleButton.Position = UDim2.new(1, -24, 0.5, -11)
	toggleButton.BackgroundColor3 = if feature.state then UI.Theme.Accent else UI.Theme.Container
	toggleButton.BorderSizePixel = 0
	toggleButton.Text = if feature.state then "X" else ""
	toggleButton.TextColor3 = UI.Theme.AccentText
	toggleButton.Font = UI.Theme.HeaderFont
	toggleButton.TextSize = 12
	toggleButton.Parent = row
	
	local toggleStroke = Instance.new("UIStroke")
	toggleStroke.Color = UI.Theme.Border
	toggleStroke.Thickness = 1.2
	toggleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	toggleStroke.Parent = toggleButton
	
	-- inline squared keybind binder button
	local keybindBtn = Instance.new("TextButton")
	keybindBtn.Name = "Keybinder"
	keybindBtn.Size = UDim2.new(0, 60, 0, 22)
	keybindBtn.Position = UDim2.new(1, -92, 0.5, -11)
	keybindBtn.BackgroundColor3 = UI.Theme.Container
	keybindBtn.BorderSizePixel = 0
	keybindBtn.Text = if feature.keybind then string.format("[%s]", feature.keybind.Name) else "[None]"
	keybindBtn.TextColor3 = UI.Theme.TextSecondary
	keybindBtn.Font = UI.Theme.MonoFont
	keybindBtn.TextSize = 10
	keybindBtn.Parent = row
	
	local bindStroke = Instance.new("UIStroke")
	bindStroke.Color = UI.Theme.BorderDim
	bindStroke.Thickness = 1.2
	bindStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bindStroke.Parent = keybindBtn
	
	local function updateToggleVisual(state: boolean)
		toggleButton.BackgroundColor3 = if state then UI.Theme.Accent else UI.Theme.Container
		toggleButton.Text = if state then "X" else ""
	end
	
	toggleButton.MouseButton1Click:Connect(function()
		local nextState = not feature.state
		FeatureManager.setFeatureState(featureId, nextState)
		updateToggleVisual(nextState)
	end)
	
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
	row.Size = UDim2.new(1, 0, 0, 38)
	row.BackgroundTransparency = 1
	row.Parent = section
	
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -60, 0, 16)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = name
	title.TextColor3 = UI.Theme.TextPrimary
	title.Font = UI.Theme.BodyFont
	title.TextSize = 12
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = row
	
	local valBox = Instance.new("Frame")
	valBox.Name = "ValBox"
	valBox.Size = UDim2.new(0, 48, 0, 16)
	valBox.Position = UDim2.new(1, -48, 0, 0)
	valBox.BackgroundColor3 = UI.Theme.Container
	valBox.BorderSizePixel = 0
	valBox.Parent = row
	
	local valStroke = Instance.new("UIStroke")
	valStroke.Color = UI.Theme.BorderDim
	valStroke.Thickness = 1
	valStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	valStroke.Parent = valBox
	
	local valLabel = Instance.new("TextLabel")
	valLabel.Size = UDim2.new(1, 0, 1, 0)
	valLabel.BackgroundTransparency = 1
	valLabel.Text = tostring(default)
	valLabel.TextColor3 = UI.Theme.Accent
	valLabel.Font = UI.Theme.MonoFont
	valLabel.TextSize = 11
	valLabel.Parent = valBox
	
	local bar = Instance.new("Frame")
	bar.Name = "SliderTrack"
	bar.Size = UDim2.new(1, 0, 0, 12)
	bar.Position = UDim2.new(0, 0, 0, 20)
	bar.BackgroundColor3 = UI.Theme.Container
	bar.BorderSizePixel = 0
	bar.Parent = row
	
	local barStroke = Instance.new("UIStroke")
	barStroke.Color = UI.Theme.BorderDim
	barStroke.Thickness = 1
	barStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	barStroke.Parent = bar
	
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	local initialRatio = math.clamp((default - min) / (max - min), 0, 1)
	fill.Size = UDim2.new(initialRatio, 0, 1, 0)
	fill.BackgroundColor3 = UI.Theme.Accent
	fill.BorderSizePixel = 0
	fill.Parent = bar
	
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

return CoreUI
