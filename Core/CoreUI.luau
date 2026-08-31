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
	layout.Padding = UDim.new(0, 8)
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

function CoreUI:AddBanner(tabObj): Frame
	return UI.createBannerCard(tabObj.Page)
end

function CoreUI:CreateColumns(tabObj): (Frame, Frame)
	local columnsContainer = Instance.new("Frame")
	columnsContainer.Name = "ColumnsContainer"
	columnsContainer.Size = UDim2.new(1, -6, 0, 0)
	columnsContainer.AutomaticSize = Enum.AutomaticSize.Y
	columnsContainer.BackgroundTransparency = 1
	columnsContainer.Parent = tabObj.Page

	local leftCol = Instance.new("Frame")
	leftCol.Name = "LeftColumn"
	leftCol.Size = UDim2.new(0.5, -4, 0, 0)
	leftCol.Position = UDim2.new(0, 0, 0, 0)
	leftCol.AutomaticSize = Enum.AutomaticSize.Y
	leftCol.BackgroundTransparency = 1
	leftCol.Parent = columnsContainer

	local leftLayout = Instance.new("UIListLayout")
	leftLayout.Padding = UDim.new(0, 8)
	leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
	leftLayout.Parent = leftCol

	local rightCol = Instance.new("Frame")
	rightCol.Name = "RightColumn"
	rightCol.Size = UDim2.new(0.5, -4, 0, 0)
	rightCol.Position = UDim2.new(0.5, 4, 0, 0)
	rightCol.AutomaticSize = Enum.AutomaticSize.Y
	rightCol.BackgroundTransparency = 1
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
	section.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = section

	-- standalone boxed header [ Option Types ]
	local headerBox = Instance.new("Frame")
	headerBox.Name = "HeaderBox"
	headerBox.Size = UDim2.new(1, 0, 0, 24)
	headerBox.BackgroundColor3 = UI.Theme.Container
	headerBox.BorderSizePixel = 0
	headerBox.Parent = section

	local headerStroke = Instance.new("UIStroke")
	headerStroke.Color = UI.Theme.Border
	headerStroke.Thickness = 1.2
	headerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	headerStroke.Parent = headerBox

	local headerLabel = Instance.new("TextLabel")
	headerLabel.Size = UDim2.new(1, 0, 1, 0)
	headerLabel.BackgroundTransparency = 1
	headerLabel.Text = title
	headerLabel.TextColor3 = UI.Theme.TextPrimary
	headerLabel.Font = UI.Theme.HeaderFont
	headerLabel.TextSize = 11
	headerLabel.Parent = headerBox

	return section
end

-- 3-Segment Toggle Row: [ X ] [ Option Name ] [ Bind ]
function CoreUI:AddToggle(section: Frame, featureId: string, name: string, defaultState: boolean, defaultKeybind: Enum.KeyCode?, callback: (boolean) -> ())
	local feature = FeatureManager.register(featureId, name, defaultState, defaultKeybind, callback)
	
	local row = Instance.new("Frame")
	row.Name = featureId .. "Row"
	row.Size = UDim2.new(1, 0, 0, 24)
	row.BackgroundTransparency = 1
	row.Parent = section

	-- Segment 1: [ X ] (Checkbox Box)
	local checkBtn = Instance.new("TextButton")
	checkBtn.Name = "CheckBtn"
	checkBtn.Size = UDim2.new(0, 24, 1, 0)
	checkBtn.Position = UDim2.new(0, 0, 0, 0)
	checkBtn.BackgroundColor3 = if feature.state then UI.Theme.Accent else UI.Theme.Container
	checkBtn.BorderSizePixel = 0
	checkBtn.Text = if feature.state then "X" else ""
	checkBtn.TextColor3 = UI.Theme.AccentText
	checkBtn.Font = UI.Theme.HeaderFont
	checkBtn.TextSize = 12
	checkBtn.Parent = row

	local checkStroke = Instance.new("UIStroke")
	checkStroke.Color = UI.Theme.Border
	checkStroke.Thickness = 1.2
	checkStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	checkStroke.Parent = checkBtn

	-- Segment 2: [ Option Name ] (Title Box)
	local titleBox = Instance.new("TextButton")
	titleBox.Name = "TitleBox"
	titleBox.Size = UDim2.new(1, -94, 1, 0)
	titleBox.Position = UDim2.new(0, 28, 0, 0)
	titleBox.BackgroundColor3 = UI.Theme.Container
	titleBox.BorderSizePixel = 0
	titleBox.Text = ""
	titleBox.Parent = row

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = UI.Theme.Border
	titleStroke.Thickness = 1.2
	titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	titleStroke.Parent = titleBox

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -8, 1, 0)
	titleLabel.Position = UDim2.new(0, 6, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = name
	titleLabel.TextColor3 = UI.Theme.TextPrimary
	titleLabel.Font = UI.Theme.BodyFont
	titleLabel.TextSize = 11
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = titleBox

	-- Segment 3: [ Bind ] (Keybinder Box)
	local keybindBtn = Instance.new("TextButton")
	keybindBtn.Name = "KeybindBtn"
	keybindBtn.Size = UDim2.new(0, 62, 1, 0)
	keybindBtn.Position = UDim2.new(1, -62, 0, 0)
	keybindBtn.BackgroundColor3 = UI.Theme.Container
	keybindBtn.BorderSizePixel = 0
	keybindBtn.Text = if feature.keybind then string.format("[%s]", feature.keybind.Name) else "[None]"
	keybindBtn.TextColor3 = UI.Theme.TextSecondary
	keybindBtn.Font = UI.Theme.MonoFont
	keybindBtn.TextSize = 10
	keybindBtn.Parent = row

	local bindStroke = Instance.new("UIStroke")
	bindStroke.Color = UI.Theme.Border
	bindStroke.Thickness = 1.2
	bindStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bindStroke.Parent = keybindBtn

	local function updateToggleVisual(state: boolean)
		checkBtn.BackgroundColor3 = if state then UI.Theme.Accent else UI.Theme.Container
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
	row.Size = UDim2.new(1, 0, 0, 42)
	row.BackgroundTransparency = 1
	row.Parent = section

	-- header line: [ Option Name ] + [ Val ]
	local titleBox = Instance.new("Frame")
	titleBox.Name = "TitleBox"
	titleBox.Size = UDim2.new(1, -52, 0, 20)
	titleBox.Position = UDim2.new(0, 0, 0, 0)
	titleBox.BackgroundColor3 = UI.Theme.Container
	titleBox.BorderSizePixel = 0
	titleBox.Parent = row

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = UI.Theme.Border
	titleStroke.Thickness = 1
	titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	titleStroke.Parent = titleBox

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -6, 1, 0)
	titleLabel.Position = UDim2.new(0, 6, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = name
	titleLabel.TextColor3 = UI.Theme.TextPrimary
	titleLabel.Font = UI.Theme.BodyFont
	titleLabel.TextSize = 10
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = titleBox

	local valBox = Instance.new("Frame")
	valBox.Name = "ValBox"
	valBox.Size = UDim2.new(0, 48, 0, 20)
	valBox.Position = UDim2.new(1, -48, 0, 0)
	valBox.BackgroundColor3 = UI.Theme.Container
	valBox.BorderSizePixel = 0
	valBox.Parent = row

	local valStroke = Instance.new("UIStroke")
	valStroke.Color = UI.Theme.Border
	valStroke.Thickness = 1
	valStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	valStroke.Parent = valBox

	local valLabel = Instance.new("TextLabel")
	valLabel.Size = UDim2.new(1, 0, 1, 0)
	valLabel.BackgroundTransparency = 1
	valLabel.Text = tostring(default)
	valLabel.TextColor3 = UI.Theme.Accent
	valLabel.Font = UI.Theme.MonoFont
	valLabel.TextSize = 10
	valLabel.Parent = valBox

	-- track
	local bar = Instance.new("Frame")
	bar.Name = "SliderTrack"
	bar.Size = UDim2.new(1, 0, 0, 14)
	bar.Position = UDim2.new(0, 0, 0, 24)
	bar.BackgroundColor3 = UI.Theme.Container
	bar.BorderSizePixel = 0
	bar.Parent = row

	local barStroke = Instance.new("UIStroke")
	barStroke.Color = UI.Theme.Border
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
