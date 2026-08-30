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
	
	local mainFrame, topbar, sidebar, contentContainer, uiScale = UI.createWindow(titleText)
	mainFrame.Parent = screenGui
	
	self.ScreenGui = screenGui
	self.MainFrame = mainFrame
	self.Sidebar = sidebar
	self.ContentContainer = contentContainer
	self.UiScale = uiScale
	self.Tabs = {}
	self.ActiveTab = nil
	
	return self
end

function CoreUI:CreateTab(name: string)
	local tabButton = Instance.new("TextButton")
	tabButton.Name = name .. "TabBtn"
	tabButton.Size = UDim2.new(1, 0, 0, 32)
	tabButton.BackgroundColor3 = UI.Theme.Container
	tabButton.BackgroundTransparency = 0.8
	tabButton.Text = name
	tabButton.TextColor3 = UI.Theme.TextMuted
	tabButton.Font = Enum.Font.GothamMedium
	tabButton.TextSize = 12
	tabButton.Parent = self.Sidebar
	
	local tabCorner = Instance.new("UICorner")
	tabCorner.CornerRadius = UDim.new(0, 6)
	tabCorner.Parent = tabButton
	
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
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = tabContent
	
	local tabObj = {
		Button = tabButton,
		Page = tabContent,
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
			Animations.tween(tab.Button, {
				BackgroundTransparency = 0.2,
				TextColor3 = UI.Theme.TextPrimary,
				BackgroundColor3 = UI.Theme.Accent
			}, { duration = 0.2 })
		else
			tab.Page.Visible = false
			Animations.tween(tab.Button, {
				BackgroundTransparency = 0.8,
				TextColor3 = UI.Theme.TextMuted,
				BackgroundColor3 = UI.Theme.Container
			}, { duration = 0.2 })
		end
	end
	self.ActiveTab = tabObj
end

function CoreUI:AddSection(tabObj, title: string): Frame
	local section = Instance.new("Frame")
	section.Name = title .. "Section"
	section.Size = UDim2.new(1, -6, 0, 0)
	section.AutomaticSize = Enum.AutomaticSize.Y
	section.BackgroundColor3 = UI.Theme.Container
	section.BackgroundTransparency = UI.Theme.ContainerTransparency
	section.Parent = tabObj.Page
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = section
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = UI.Theme.Border
	stroke.Thickness = 0.8
	stroke.Transparency = 0.8
	stroke.Parent = section
	
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = section
	
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = section
	
	local label = Instance.new("TextLabel")
	label.Name = "Header"
	label.Size = UDim2.new(1, 0, 0, 18)
	label.BackgroundTransparency = 1
	label.Text = title
	label.TextColor3 = UI.Theme.Accent
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = section
	
	return section
end

function CoreUI:AddToggle(section: Frame, featureId: string, name: string, defaultState: boolean, defaultKeybind: Enum.KeyCode?, callback: (boolean) -> ())
	local feature = FeatureManager.register(featureId, name, defaultState, defaultKeybind, callback)
	
	local row = Instance.new("Frame")
	row.Name = featureId .. "Row"
	row.Size = UDim2.new(1, 0, 0, 32)
	row.BackgroundTransparency = 1
	row.Parent = section
	
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -120, 1, 0)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = name
	title.TextColor3 = UI.Theme.TextPrimary
	title.Font = Enum.Font.GothamMedium
	title.TextSize = 12
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = row
	
	local toggleButton = Instance.new("TextButton")
	toggleButton.Name = "ToggleSwitch"
	toggleButton.Size = UDim2.new(0, 42, 0, 22)
	toggleButton.Position = UDim2.new(1, -42, 0.5, -11)
	toggleButton.BackgroundColor3 = if feature.state then UI.Theme.Accent else UI.Theme.AccentInactive
	toggleButton.Text = ""
	toggleButton.Parent = row
	
	local switchCorner = Instance.new("UICorner")
	switchCorner.CornerRadius = UDim.new(1, 0)
	switchCorner.Parent = toggleButton
	
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.Position = if feature.state then UDim2.new(1, -19, 0.5, -8) else UDim2.new(0, 3, 0.5, -8)
	knob.BackgroundColor3 = UI.Theme.TextPrimary
	knob.Parent = toggleButton
	
	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob
	
	local keybindBtn = Instance.new("TextButton")
	keybindBtn.Name = "Keybinder"
	keybindBtn.Size = UDim2.new(0, 56, 0, 22)
	keybindBtn.Position = UDim2.new(1, -106, 0.5, -11)
	keybindBtn.BackgroundColor3 = UI.Theme.Container
	keybindBtn.BackgroundTransparency = 0.2
	keybindBtn.Text = if feature.keybind then feature.keybind.Name else "[None]"
	keybindBtn.TextColor3 = UI.Theme.TextMuted
	keybindBtn.Font = Enum.Font.GothamBold
	keybindBtn.TextSize = 10
	keybindBtn.Parent = row
	
	local bindCorner = Instance.new("UICorner")
	bindCorner.CornerRadius = UDim.new(0, 4)
	bindCorner.Parent = keybindBtn
	
	local bindStroke = Instance.new("UIStroke")
	bindStroke.Color = UI.Theme.Border
	bindStroke.Thickness = 0.8
	bindStroke.Transparency = 0.7
	bindStroke.Parent = keybindBtn
	
	local function updateToggleVisual(state: boolean)
		Animations.tween(toggleButton, {
			BackgroundColor3 = if state then UI.Theme.Accent else UI.Theme.AccentInactive
		}, { duration = 0.2 })
		
		local targetPos = if state then UDim2.new(1, -19, 0.5, -8) else UDim2.new(0, 3, 0.5, -8)
		Animations.tween(knob, { Position = targetPos }, { duration = 0.2 })
	end
	
	toggleButton.MouseButton1Click:Connect(function()
		local nextState = not feature.state
		FeatureManager.setFeatureState(featureId, nextState)
		updateToggleVisual(nextState)
		Animations.pulse(knob, 1.15)
	end)
	
	feature.onKeybindChanged = function(newKey)
		keybindBtn.Text = if newKey then newKey.Name else "[None]"
	end
	
	keybindBtn.MouseButton1Click:Connect(function()
		keybindBtn.Text = "..."
		keybindBtn.TextColor3 = UI.Theme.Accent
		FeatureManager.promptKeybindCapture(function(selectedKey)
			FeatureManager.setFeatureKeybind(featureId, selectedKey)
			keybindBtn.Text = if selectedKey then selectedKey.Name else "[None]"
			keybindBtn.TextColor3 = UI.Theme.TextMuted
		end)
	end)
end

function CoreUI:AddSlider(section: Frame, name: string, min: number, max: number, default: number, callback: (number) -> ())
	local row = Instance.new("Frame")
	row.Name = name .. "SliderRow"
	row.Size = UDim2.new(1, 0, 0, 44)
	row.BackgroundTransparency = 1
	row.Parent = section
	
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -50, 0, 18)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = name
	title.TextColor3 = UI.Theme.TextPrimary
	title.Font = Enum.Font.GothamMedium
	title.TextSize = 12
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = row
	
	local valLabel = Instance.new("TextLabel")
	valLabel.Size = UDim2.new(0, 45, 0, 18)
	valLabel.Position = UDim2.new(1, -45, 0, 0)
	valLabel.BackgroundTransparency = 1
	valLabel.Text = tostring(default)
	valLabel.TextColor3 = UI.Theme.Accent
	valLabel.Font = Enum.Font.GothamBold
	valLabel.TextSize = 12
	valLabel.TextXAlignment = Enum.TextXAlignment.Right
	valLabel.Parent = row
	
	local bar = Instance.new("Frame")
	bar.Name = "SliderTrack"
	bar.Size = UDim2.new(1, 0, 0, 8)
	bar.Position = UDim2.new(0, 0, 0, 24)
	bar.BackgroundColor3 = UI.Theme.Container
	bar.Parent = row
	
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = bar
	
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	local initialRatio = math.clamp((default - min) / (max - min), 0, 1)
	fill.Size = UDim2.new(initialRatio, 0, 1, 0)
	fill.BackgroundColor3 = UI.Theme.Accent
	fill.BorderSizePixel = 0
	fill.Parent = bar
	
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	
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
