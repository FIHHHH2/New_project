--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local AnimationEngine = require(script.Parent.AnimationEngine)
local FeatureManager = require(script.Parent.FeatureManager)

local CoreUI = {}
CoreUI.__index = CoreUI

local THEME = {
	Background = Color3.fromRGB(15, 15, 17),
	BackgroundTransparency = 0.35,
	Border = Color3.fromRGB(240, 70, 70),
	TextPrimary = Color3.fromRGB(255, 255, 255),
	TextMuted = Color3.fromRGB(160, 160, 165),
	Accent = Color3.fromRGB(235, 65, 65),
	AccentInactive = Color3.fromRGB(45, 45, 50),
	Container = Color3.fromRGB(22, 22, 26),
	ContainerTransparency = 0.5
}

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
	
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainWindow"
	mainFrame.Size = UDim2.new(0, 680, 0, 440)
	mainFrame.Position = UDim2.new(0.5, -340, 0.5, -220)
	mainFrame.BackgroundColor3 = THEME.Background
	mainFrame.BackgroundTransparency = THEME.BackgroundTransparency
	mainFrame.BorderSizePixel = 0
	mainFrame.ClipsDescendants = true
	mainFrame.Parent = screenGui
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = mainFrame
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = THEME.Border
	stroke.Thickness = 1.2
	stroke.Transparency = 0.4
	stroke.Parent = mainFrame
	
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 1.0
	uiScale.Parent = mainFrame
	
	local topbar = Instance.new("Frame")
	topbar.Name = "TopBar"
	topbar.Size = UDim2.new(1, 0, 0, 42)
	topbar.BackgroundTransparency = 1
	topbar.Parent = mainFrame
	
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(0, 200, 1, 0)
	title.Position = UDim2.new(0, 16, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = titleText
	title.TextColor3 = THEME.TextPrimary
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = topbar
	
	local dragging = false
	local dragInput: InputObject? = nil
	local dragStart: Vector3 = Vector3.zero
	local startPos: UDim2 = UDim2.new()
	
	topbar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = mainFrame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	
	topbar.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)
	
	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
	
	local profileBox = Instance.new("Frame")
	profileBox.Name = "ProfileCard"
	profileBox.Size = UDim2.new(0, 220, 0, 52)
	profileBox.Position = UDim2.new(0, 16, 0, 48)
	profileBox.BackgroundColor3 = THEME.Container
	profileBox.BackgroundTransparency = THEME.ContainerTransparency
	profileBox.Parent = mainFrame
	
	local profCorner = Instance.new("UICorner")
	profCorner.CornerRadius = UDim.new(0, 6)
	profCorner.Parent = profileBox
	
	local avatarImage = Instance.new("ImageLabel")
	avatarImage.Name = "Avatar"
	avatarImage.Size = UDim2.new(0, 40, 0, 40)
	avatarImage.Position = UDim2.new(0, 6, 0, 6)
	avatarImage.BackgroundTransparency = 1
	avatarImage.Image = Players:GetUserThumbnailAsync(Players.LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	avatarImage.Parent = profileBox
	
	local avatarCorner = Instance.new("UICorner")
	avatarCorner.CornerRadius = UDim.new(1, 0)
	avatarCorner.Parent = avatarImage
	
	local userLabel = Instance.new("TextLabel")
	userLabel.Size = UDim2.new(1, -56, 0, 18)
	userLabel.Position = UDim2.new(0, 52, 0, 8)
	userLabel.BackgroundTransparency = 1
	userLabel.Text = Players.LocalPlayer.DisplayName
	userLabel.TextColor3 = THEME.TextPrimary
	userLabel.Font = Enum.Font.GothamBold
	userLabel.TextSize = 13
	userLabel.TextXAlignment = Enum.TextXAlignment.Left
	userLabel.Parent = profileBox
	
	local ageLabel = Instance.new("TextLabel")
	ageLabel.Size = UDim2.new(1, -56, 0, 16)
	ageLabel.Position = UDim2.new(0, 52, 0, 26)
	ageLabel.BackgroundTransparency = 1
	ageLabel.Text = string.format("@%s | age: %d d", Players.LocalPlayer.Name, Players.LocalPlayer.AccountAge)
	ageLabel.TextColor3 = THEME.TextMuted
	ageLabel.Font = Enum.Font.Gotham
	ageLabel.TextSize = 10
	ageLabel.TextXAlignment = Enum.TextXAlignment.Left
	ageLabel.Parent = profileBox
	
	local sidebar = Instance.new("ScrollingFrame")
	sidebar.Name = "Sidebar"
	sidebar.Size = UDim2.new(0, 140, 1, -118)
	sidebar.Position = UDim2.new(0, 16, 0, 108)
	sidebar.BackgroundTransparency = 1
	sidebar.ScrollBarThickness = 2
	sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
	sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sidebar.Parent = mainFrame
	
	local sideList = Instance.new("UIListLayout")
	sideList.Padding = UDim.new(0, 6)
	sideList.SortOrder = Enum.SortOrder.LayoutOrder
	sideList.Parent = sidebar
	
	local contentContainer = Instance.new("Frame")
	contentContainer.Name = "ContentContainer"
	contentContainer.Size = UDim2.new(1, -190, 1, -60)
	contentContainer.Position = UDim2.new(0, 172, 0, 48)
	contentContainer.BackgroundTransparency = 1
	contentContainer.Parent = mainFrame
	
	local resizeHandle = Instance.new("TextButton")
	resizeHandle.Name = "ResizeGrip"
	resizeHandle.Size = UDim2.new(0, 16, 0, 16)
	resizeHandle.Position = UDim2.new(1, -16, 1, -16)
	resizeHandle.BackgroundTransparency = 1
	resizeHandle.Text = "◢"
	resizeHandle.TextColor3 = THEME.TextMuted
	resizeHandle.Font = Enum.Font.GothamBold
	resizeHandle.TextSize = 12
	resizeHandle.Parent = mainFrame
	
	local resizing = false
	local startScale = 1.0
	local resizeStart = Vector2.zero
	
	resizeHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			resizing = true
			resizeStart = Vector2.new(input.Position.X, input.Position.Y)
			startScale = uiScale.Scale
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					resizing = false
				end
			end)
		end
	end)
	
	UserInputService.InputChanged:Connect(function(input)
		if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = (input.Position.X - resizeStart.X) / 400
			local newScale = math.clamp(startScale + delta, 0.6, 1.6)
			uiScale.Scale = newScale
		end
	end)
	
	self.ScreenGui = screenGui
	self.MainFrame = mainFrame
	self.Sidebar = sidebar
	self.ContentContainer = contentContainer
	self.Tabs = {}
	self.ActiveTab = nil
	
	return self
end

function CoreUI:CreateTab(name: string)
	local tabButton = Instance.new("TextButton")
	tabButton.Name = name .. "TabBtn"
	tabButton.Size = UDim2.new(1, 0, 0, 32)
	tabButton.BackgroundColor3 = THEME.Container
	tabButton.BackgroundTransparency = 0.8
	tabButton.Text = name
	tabButton.TextColor3 = THEME.TextMuted
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
			AnimationEngine.tween(tab.Button, {
				BackgroundTransparency = 0.2,
				TextColor3 = THEME.TextPrimary,
				BackgroundColor3 = THEME.Accent
			}, { duration = 0.2 })
		else
			tab.Page.Visible = false
			AnimationEngine.tween(tab.Button, {
				BackgroundTransparency = 0.8,
				TextColor3 = THEME.TextMuted,
				BackgroundColor3 = THEME.Container
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
	section.BackgroundColor3 = THEME.Container
	section.BackgroundTransparency = THEME.ContainerTransparency
	section.Parent = tabObj.Page
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = section
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = THEME.Border
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
	label.TextColor3 = THEME.Accent
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
	title.TextColor3 = THEME.TextPrimary
	title.Font = Enum.Font.GothamMedium
	title.TextSize = 12
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = row
	
	local toggleButton = Instance.new("TextButton")
	toggleButton.Name = "ToggleSwitch"
	toggleButton.Size = UDim2.new(0, 42, 0, 22)
	toggleButton.Position = UDim2.new(1, -42, 0.5, -11)
	toggleButton.BackgroundColor3 = if feature.state then THEME.Accent else THEME.AccentInactive
	toggleButton.Text = ""
	toggleButton.Parent = row
	
	local switchCorner = Instance.new("UICorner")
	switchCorner.CornerRadius = UDim.new(1, 0)
	switchCorner.Parent = toggleButton
	
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.Position = if feature.state then UDim2.new(1, -19, 0.5, -8) else UDim2.new(0, 3, 0.5, -8)
	knob.BackgroundColor3 = THEME.TextPrimary
	knob.Parent = toggleButton
	
	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob
	
	local keybindBtn = Instance.new("TextButton")
	keybindBtn.Name = "Keybinder"
	keybindBtn.Size = UDim2.new(0, 56, 0, 22)
	keybindBtn.Position = UDim2.new(1, -106, 0.5, -11)
	keybindBtn.BackgroundColor3 = THEME.Container
	keybindBtn.BackgroundTransparency = 0.2
	keybindBtn.Text = if feature.keybind then feature.keybind.Name else "[None]"
	keybindBtn.TextColor3 = THEME.TextMuted
	keybindBtn.Font = Enum.Font.GothamBold
	keybindBtn.TextSize = 10
	keybindBtn.Parent = row
	
	local bindCorner = Instance.new("UICorner")
	bindCorner.CornerRadius = UDim.new(0, 4)
	bindCorner.Parent = keybindBtn
	
	local bindStroke = Instance.new("UIStroke")
	bindStroke.Color = THEME.Border
	bindStroke.Thickness = 0.8
	bindStroke.Transparency = 0.7
	bindStroke.Parent = keybindBtn
	
	local function updateToggleVisual(state: boolean)
		AnimationEngine.tween(toggleButton, {
			BackgroundColor3 = if state then THEME.Accent else THEME.AccentInactive
		}, { duration = 0.2 })
		
		local targetPos = if state then UDim2.new(1, -19, 0.5, -8) else UDim2.new(0, 3, 0.5, -8)
		AnimationEngine.tween(knob, { Position = targetPos }, { duration = 0.2 })
	end
	
	toggleButton.MouseButton1Click:Connect(function()
		local nextState = not feature.state
		FeatureManager.setFeatureState(featureId, nextState)
		updateToggleVisual(nextState)
		AnimationEngine.pulse(knob, 1.15)
	end)
	
	feature.onKeybindChanged = function(newKey)
		keybindBtn.Text = if newKey then newKey.Name else "[None]"
	end
	
	keybindBtn.MouseButton1Click:Connect(function()
		keybindBtn.Text = "..."
		keybindBtn.TextColor3 = THEME.Accent
		FeatureManager.promptKeybindCapture(function(selectedKey)
			FeatureManager.setFeatureKeybind(featureId, selectedKey)
			keybindBtn.Text = if selectedKey then selectedKey.Name else "[None]"
			keybindBtn.TextColor3 = THEME.TextMuted
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
	title.TextColor3 = THEME.TextPrimary
	title.Font = Enum.Font.GothamMedium
	title.TextSize = 12
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = row
	
	local valLabel = Instance.new("TextLabel")
	valLabel.Size = UDim2.new(0, 45, 0, 18)
	valLabel.Position = UDim2.new(1, -45, 0, 0)
	valLabel.BackgroundTransparency = 1
	valLabel.Text = tostring(default)
	valLabel.TextColor3 = THEME.Accent
	valLabel.Font = Enum.Font.GothamBold
	valLabel.TextSize = 12
	valLabel.TextXAlignment = Enum.TextXAlignment.Right
	valLabel.Parent = row
	
	local bar = Instance.new("Frame")
	bar.Name = "SliderTrack"
	bar.Size = UDim2.new(1, 0, 0, 8)
	bar.Position = UDim2.new(0, 0, 0, 24)
	bar.BackgroundColor3 = THEME.Container
	bar.Parent = row
	
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = bar
	
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	local initialRatio = math.clamp((default - min) / (max - min), 0, 1)
	fill.Size = UDim2.new(initialRatio, 0, 1, 0)
	fill.BackgroundColor3 = THEME.Accent
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
