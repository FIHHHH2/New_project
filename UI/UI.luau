--!strict
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local UI = {}
UI.__index = UI

UI.Theme = {
	Background = Color3.fromRGB(18, 18, 20),
	BackgroundTransparency = 0.1,
	Border = Color3.fromRGB(220, 220, 225),
	BorderDim = Color3.fromRGB(80, 80, 90),
	Accent = Color3.fromRGB(240, 65, 65),
	AccentText = Color3.fromRGB(255, 255, 255),
	TextPrimary = Color3.fromRGB(245, 245, 245),
	TextSecondary = Color3.fromRGB(150, 150, 160),
	Container = Color3.fromRGB(26, 26, 30),
	ContainerBorder = Color3.fromRGB(60, 60, 70),
	HeaderFont = Enum.Font.GothamBold,
	BodyFont = Enum.Font.GothamMedium,
	MonoFont = Enum.Font.Code
}

function UI.createWindow(titleText: string)
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainWindow"
	mainFrame.Size = UDim2.new(0, 680, 0, 430)
	mainFrame.Position = UDim2.new(0.5, -340, 0.5, -215)
	mainFrame.BackgroundColor3 = UI.Theme.Background
	mainFrame.BackgroundTransparency = UI.Theme.BackgroundTransparency
	mainFrame.BorderSizePixel = 0
	mainFrame.ClipsDescendants = false

	local outerStroke = Instance.new("UIStroke")
	outerStroke.Color = UI.Theme.Border
	outerStroke.Thickness = 2
	outerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outerStroke.Parent = mainFrame

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 1.0
	uiScale.Parent = mainFrame

	-- topbar container
	local topbar = Instance.new("Frame")
	topbar.Name = "TopBar"
	topbar.Size = UDim2.new(1, -8, 0, 28)
	topbar.Position = UDim2.new(0, 4, 0, 4)
	topbar.BackgroundTransparency = 1
	topbar.Parent = mainFrame

	-- topbar title box [Project Fih Menu >>>>>]
	local titleBox = Instance.new("Frame")
	titleBox.Name = "TitleBox"
	titleBox.Size = UDim2.new(0, 220, 1, 0)
	titleBox.Position = UDim2.new(0, 0, 0, 0)
	titleBox.BackgroundColor3 = UI.Theme.Container
	titleBox.BorderSizePixel = 0
	titleBox.Parent = topbar

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = UI.Theme.Border
	titleStroke.Thickness = 1.5
	titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	titleStroke.Parent = titleBox

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -12, 1, 0)
	titleLabel.Position = UDim2.new(0, 8, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = string.format("%s >>>>>", titleText)
	titleLabel.TextColor3 = UI.Theme.TextPrimary
	titleLabel.Font = UI.Theme.HeaderFont
	titleLabel.TextSize = 13
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = titleBox

	-- center decorative bar [>>>>>>>>>>>>>>>>>>>>>>>>>>>>]
	local decoBar = Instance.new("Frame")
	decoBar.Name = "DecoBar"
	decoBar.Size = UDim2.new(1, -298, 1, 0)
	decoBar.Position = UDim2.new(0, 226, 0, 0)
	decoBar.BackgroundColor3 = UI.Theme.Container
	decoBar.BorderSizePixel = 0
	decoBar.ClipsDescendants = true
	decoBar.Parent = topbar

	local decoStroke = Instance.new("UIStroke")
	decoStroke.Color = UI.Theme.Border
	decoStroke.Thickness = 1.5
	decoStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	decoStroke.Parent = decoBar

	local decoLabel = Instance.new("TextLabel")
	decoLabel.Size = UDim2.new(1, 0, 1, 0)
	decoLabel.BackgroundTransparency = 1
	decoLabel.Text = ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
	decoLabel.TextColor3 = UI.Theme.BorderDim
	decoLabel.Font = UI.Theme.MonoFont
	decoLabel.TextSize = 12
	decoLabel.Parent = decoBar

	-- window control buttons: [-] and [X]
	local minButton = Instance.new("TextButton")
	minButton.Name = "MinButton"
	minButton.Size = UDim2.new(0, 30, 1, 0)
	minButton.Position = UDim2.new(1, -64, 0, 0)
	minButton.BackgroundColor3 = UI.Theme.Container
	minButton.BorderSizePixel = 0
	minButton.Text = "—"
	minButton.TextColor3 = UI.Theme.TextPrimary
	minButton.Font = UI.Theme.HeaderFont
	minButton.TextSize = 13
	minButton.Parent = topbar

	local minStroke = Instance.new("UIStroke")
	minStroke.Color = UI.Theme.Border
	minStroke.Thickness = 1.5
	minStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	minStroke.Parent = minButton

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 30, 1, 0)
	closeButton.Position = UDim2.new(1, -30, 0, 0)
	closeButton.BackgroundColor3 = UI.Theme.Container
	closeButton.BorderSizePixel = 0
	closeButton.Text = "X"
	closeButton.TextColor3 = UI.Theme.TextPrimary
	closeButton.Font = UI.Theme.HeaderFont
	closeButton.TextSize = 13
	closeButton.Parent = topbar

	local closeStroke = Instance.new("UIStroke")
	closeStroke.Color = UI.Theme.Border
	closeStroke.Thickness = 1.5
	closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	closeStroke.Parent = closeButton

	-- horizontal divider under topbar
	local topDivider = Instance.new("Frame")
	topDivider.Name = "TopDivider"
	topDivider.Size = UDim2.new(1, 0, 0, 2)
	topDivider.Position = UDim2.new(0, 0, 0, 36)
	topDivider.BackgroundColor3 = UI.Theme.Border
	topDivider.BorderSizePixel = 0
	topDivider.Parent = mainFrame

	-- body frame
	local bodyFrame = Instance.new("Frame")
	bodyFrame.Name = "BodyFrame"
	bodyFrame.Size = UDim2.new(1, 0, 1, -54)
	bodyFrame.Position = UDim2.new(0, 0, 0, 38)
	bodyFrame.BackgroundTransparency = 1
	bodyFrame.Parent = mainFrame

	-- left sidebar
	local sidebar = Instance.new("ScrollingFrame")
	sidebar.Name = "Sidebar"
	sidebar.Size = UDim2.new(0, 130, 1, 0)
	sidebar.Position = UDim2.new(0, 4, 0, 4)
	sidebar.BackgroundTransparency = 1
	sidebar.ScrollBarThickness = 2
	sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
	sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sidebar.Parent = bodyFrame

	local sideList = Instance.new("UIListLayout")
	sideList.Padding = UDim.new(0, 6)
	sideList.SortOrder = Enum.SortOrder.LayoutOrder
	sideList.Parent = sidebar

	-- vertical divider
	local vertDivider = Instance.new("Frame")
	vertDivider.Name = "VertDivider"
	vertDivider.Size = UDim2.new(0, 2, 1, 0)
	vertDivider.Position = UDim2.new(0, 138, 0, 0)
	vertDivider.BackgroundColor3 = UI.Theme.Border
	vertDivider.BorderSizePixel = 0
	vertDivider.Parent = bodyFrame

	-- right main container
	local rightMain = Instance.new("Frame")
	rightMain.Name = "RightMain"
	rightMain.Size = UDim2.new(1, -146, 1, -4)
	rightMain.Position = UDim2.new(0, 142, 0, 4)
	rightMain.BackgroundTransparency = 1
	rightMain.Parent = bodyFrame

	-- subheader bar
	local subHeader = Instance.new("Frame")
	subHeader.Name = "SubHeader"
	subHeader.Size = UDim2.new(1, 0, 0, 26)
	subHeader.BackgroundTransparency = 1
	subHeader.Parent = rightMain

	-- active tab tag box [ Main ]
	local activeTagBox = Instance.new("Frame")
	activeTagBox.Name = "ActiveTagBox"
	activeTagBox.Size = UDim2.new(0, 110, 1, 0)
	activeTagBox.Position = UDim2.new(0, 0, 0, 0)
	activeTagBox.BackgroundColor3 = UI.Theme.Container
	activeTagBox.BorderSizePixel = 0
	activeTagBox.Parent = subHeader

	local activeTagStroke = Instance.new("UIStroke")
	activeTagStroke.Color = UI.Theme.Border
	activeTagStroke.Thickness = 1.5
	activeTagStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	activeTagStroke.Parent = activeTagBox

	local activeTagLabel = Instance.new("TextLabel")
	activeTagLabel.Name = "Label"
	activeTagLabel.Size = UDim2.new(1, 0, 1, 0)
	activeTagLabel.BackgroundTransparency = 1
	activeTagLabel.Text = "Main"
	activeTagLabel.TextColor3 = UI.Theme.TextPrimary
	activeTagLabel.Font = UI.Theme.HeaderFont
	activeTagLabel.TextSize = 12
	activeTagLabel.Parent = activeTagBox

	-- subheader right utility buttons: [Settings] and [configs]
	local configsBtn = Instance.new("TextButton")
	configsBtn.Name = "ConfigsBtn"
	configsBtn.Size = UDim2.new(0, 70, 1, 0)
	configsBtn.Position = UDim2.new(1, -70, 0, 0)
	configsBtn.BackgroundColor3 = UI.Theme.Container
	configsBtn.BorderSizePixel = 0
	configsBtn.Text = "configs"
	configsBtn.TextColor3 = UI.Theme.TextPrimary
	configsBtn.Font = UI.Theme.HeaderFont
	configsBtn.TextSize = 11
	configsBtn.Parent = subHeader

	local configsStroke = Instance.new("UIStroke")
	configsStroke.Color = UI.Theme.Border
	configsStroke.Thickness = 1.5
	configsStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	configsStroke.Parent = configsBtn

	local settingsBtn = Instance.new("TextButton")
	settingsBtn.Name = "SettingsBtn"
	settingsBtn.Size = UDim2.new(0, 70, 1, 0)
	settingsBtn.Position = UDim2.new(1, -146, 0, 0)
	settingsBtn.BackgroundColor3 = UI.Theme.Container
	settingsBtn.BorderSizePixel = 0
	settingsBtn.Text = "Settings"
	settingsBtn.TextColor3 = UI.Theme.TextPrimary
	settingsBtn.Font = UI.Theme.HeaderFont
	settingsBtn.TextSize = 11
	settingsBtn.Parent = subHeader

	local settingsStroke = Instance.new("UIStroke")
	settingsStroke.Color = UI.Theme.Border
	settingsStroke.Thickness = 1.5
	settingsStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	settingsStroke.Parent = settingsBtn

	-- pages container
	local contentContainer = Instance.new("Frame")
	contentContainer.Name = "ContentContainer"
	contentContainer.Size = UDim2.new(1, 0, 1, -32)
	contentContainer.Position = UDim2.new(0, 0, 0, 32)
	contentContainer.BackgroundTransparency = 1
	contentContainer.Parent = rightMain

	-- bottom hatched footer bar (////////////////////////////////)
	local footerBar = Instance.new("Frame")
	footerBar.Name = "FooterBar"
	footerBar.Size = UDim2.new(1, 0, 0, 14)
	footerBar.Position = UDim2.new(0, 0, 1, -14)
	footerBar.BackgroundColor3 = UI.Theme.Background
	footerBar.BorderSizePixel = 0
	footerBar.ClipsDescendants = true
	footerBar.Parent = mainFrame

	local footerStroke = Instance.new("UIStroke")
	footerStroke.Color = UI.Theme.Border
	footerStroke.Thickness = 1.5
	footerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	footerStroke.Parent = footerBar

	local footerHatch = Instance.new("TextLabel")
	footerHatch.Size = UDim2.new(1, 0, 1, 0)
	footerHatch.BackgroundTransparency = 1
	footerHatch.Text = "////////////////////////////////////////////////////////////////////////////////////////////////////"
	footerHatch.TextColor3 = UI.Theme.BorderDim
	footerHatch.Font = UI.Theme.MonoFont
	footerHatch.TextSize = 11
	footerHatch.Parent = footerBar

	-- window dragging
	local dragging = false
	local dragInput: InputObject? = nil
	local dragStart = Vector3.zero
	local startPos = UDim2.new()

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

	-- minimize toggle
	local minimized = false
	minButton.MouseButton1Click:Connect(function()
		minimized = not minimized
		bodyFrame.Visible = not minimized
		footerBar.Visible = not minimized
		mainFrame.Size = if minimized then UDim2.new(0, 680, 0, 36) else UDim2.new(0, 680, 0, 430)
	end)

	closeButton.MouseButton1Click:Connect(function()
		mainFrame.Visible = false
	end)

	return mainFrame, topbar, sidebar, contentContainer, activeTagLabel, uiScale
end

return UI
