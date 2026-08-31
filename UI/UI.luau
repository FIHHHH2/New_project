--!strict
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local UI = {}
UI.__index = UI

UI.Theme = {
	Background = Color3.fromRGB(14, 14, 16),
	BackgroundTransparency = 0.05,
	Border = Color3.fromRGB(230, 230, 235),
	BorderDim = Color3.fromRGB(80, 80, 90),
	Accent = Color3.fromRGB(240, 60, 60),
	AccentText = Color3.fromRGB(255, 255, 255),
	TextPrimary = Color3.fromRGB(245, 245, 245),
	TextSecondary = Color3.fromRGB(160, 160, 170),
	Container = Color3.fromRGB(22, 22, 26),
	ContainerDark = Color3.fromRGB(16, 16, 19),
	HeaderFont = Enum.Font.GothamBold,
	BodyFont = Enum.Font.GothamMedium,
	MonoFont = Enum.Font.Code
}

function UI.createWindow(titleText: string)
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainWindow"
	mainFrame.Size = UDim2.new(0, 720, 0, 480)
	mainFrame.Position = UDim2.new(0.5, -360, 0.5, -240)
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
	topbar.Size = UDim2.new(1, -12, 0, 28)
	topbar.Position = UDim2.new(0, 6, 0, 6)
	topbar.BackgroundTransparency = 1
	topbar.Parent = mainFrame

	-- title box [Project Fih Menu >>>>>]
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
	titleLabel.TextSize = 12
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
	decoLabel.Text = ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
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
	topDivider.Position = UDim2.new(0, 0, 0, 40)
	topDivider.BackgroundColor3 = UI.Theme.Border
	topDivider.BorderSizePixel = 0
	topDivider.Parent = mainFrame

	-- body frame
	local bodyFrame = Instance.new("Frame")
	bodyFrame.Name = "BodyFrame"
	bodyFrame.Size = UDim2.new(1, 0, 1, -58)
	bodyFrame.Position = UDim2.new(0, 0, 0, 42)
	bodyFrame.BackgroundTransparency = 1
	bodyFrame.Parent = mainFrame

	-- left sidebar
	local sidebar = Instance.new("ScrollingFrame")
	sidebar.Name = "Sidebar"
	sidebar.Size = UDim2.new(0, 130, 1, -8)
	sidebar.Position = UDim2.new(0, 6, 0, 6)
	sidebar.BackgroundTransparency = 1
	sidebar.ScrollBarThickness = 2
	sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
	sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sidebar.ClipsDescendants = true
	sidebar.Parent = bodyFrame

	local sideList = Instance.new("UIListLayout")
	sideList.Padding = UDim.new(0, 6)
	sideList.SortOrder = Enum.SortOrder.LayoutOrder
	sideList.Parent = sidebar

	-- vertical divider
	local vertDivider = Instance.new("Frame")
	vertDivider.Name = "VertDivider"
	vertDivider.Size = UDim2.new(0, 2, 1, 0)
	vertDivider.Position = UDim2.new(0, 142, 0, 0)
	vertDivider.BackgroundColor3 = UI.Theme.Border
	vertDivider.BorderSizePixel = 0
	vertDivider.Parent = bodyFrame

	-- right main container
	local rightMain = Instance.new("Frame")
	rightMain.Name = "RightMain"
	rightMain.Size = UDim2.new(1, -150, 1, -6)
	rightMain.Position = UDim2.new(0, 146, 0, 6)
	rightMain.BackgroundTransparency = 1
	rightMain.ClipsDescendants = true
	rightMain.Parent = bodyFrame

	-- subheader bar
	local subHeader = Instance.new("Frame")
	subHeader.Name = "SubHeader"
	subHeader.Size = UDim2.new(1, -6, 0, 26)
	subHeader.Position = UDim2.new(0, 0, 0, 0)
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

	-- pages container with strict boundary clamping
	local contentContainer = Instance.new("Frame")
	contentContainer.Name = "ContentContainer"
	contentContainer.Size = UDim2.new(1, -4, 1, -34)
	contentContainer.Position = UDim2.new(0, 0, 0, 32)
	contentContainer.BackgroundTransparency = 1
	contentContainer.ClipsDescendants = true
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
	footerHatch.Text = "////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
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
		mainFrame.Size = if minimized then UDim2.new(0, 720, 0, 42) else UDim2.new(0, 720, 0, 480)
	end)

	closeButton.MouseButton1Click:Connect(function()
		mainFrame.Visible = false
	end)

	return mainFrame, topbar, sidebar, contentContainer, activeTagLabel, uiScale
end

function UI.createBannerCard(parent: GuiObject): Frame
	local banner = Instance.new("Frame")
	banner.Name = "PlayerGameBanner"
	banner.Size = UDim2.new(1, 0, 0, 88)
	banner.BackgroundColor3 = UI.Theme.Container
	banner.BorderSizePixel = 0
	banner.ClipsDescendants = true
	banner.Parent = parent

	local bannerStroke = Instance.new("UIStroke")
	bannerStroke.Color = UI.Theme.Border
	bannerStroke.Thickness = 1.5
	bannerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bannerStroke.Parent = banner

	-- left player mugshot box
	local mugshotBox = Instance.new("Frame")
	mugshotBox.Name = "MugshotBox"
	mugshotBox.Size = UDim2.new(0, 78, 1, -8)
	mugshotBox.Position = UDim2.new(0, 4, 0, 4)
	mugshotBox.BackgroundColor3 = UI.Theme.ContainerDark
	mugshotBox.BorderSizePixel = 0
	mugshotBox.ClipsDescendants = true
	mugshotBox.Parent = banner

	local mugshotStroke = Instance.new("UIStroke")
	mugshotStroke.Color = UI.Theme.Border
	mugshotStroke.Thickness = 1.2
	mugshotStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	mugshotStroke.Parent = mugshotBox

	local avatarImg = Instance.new("ImageLabel")
	avatarImg.Size = UDim2.new(1, -4, 1, -4)
	avatarImg.Position = UDim2.new(0, 2, 0, 2)
	avatarImg.BackgroundTransparency = 1
	avatarImg.Image = Players:GetUserThumbnailAsync(Players.LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	avatarImg.Parent = mugshotBox

	-- right section
	local rightSide = Instance.new("Frame")
	rightSide.Name = "RightSide"
	rightSide.Size = UDim2.new(1, -92, 1, -8)
	rightSide.Position = UDim2.new(0, 86, 0, 4)
	rightSide.BackgroundTransparency = 1
	rightSide.ClipsDescendants = true
	rightSide.Parent = banner

	-- top row: [ Player Name : Game Name ]
	local titleRow = Instance.new("Frame")
	titleRow.Name = "TitleRow"
	titleRow.Size = UDim2.new(1, 0, 0, 22)
	titleRow.BackgroundColor3 = UI.Theme.ContainerDark
	titleRow.BorderSizePixel = 0
	titleRow.ClipsDescendants = true
	titleRow.Parent = rightSide

	local titleRowStroke = Instance.new("UIStroke")
	titleRowStroke.Color = UI.Theme.Border
	titleRowStroke.Thickness = 1.2
	titleRowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	titleRowStroke.Parent = titleRow

	local gameName = "Roblox Experience"
	pcall(function()
		local info = MarketplaceService:GetProductInfo(game.PlaceId)
		if info and info.Name then
			gameName = info.Name
		end
	end)

	local titleRowLabel = Instance.new("TextLabel")
	titleRowLabel.Size = UDim2.new(1, -12, 1, 0)
	titleRowLabel.Position = UDim2.new(0, 6, 0, 0)
	titleRowLabel.BackgroundTransparency = 1
	titleRowLabel.Text = string.format("%s   :   %s", Players.LocalPlayer.DisplayName, gameName)
	titleRowLabel.TextColor3 = UI.Theme.TextPrimary
	titleRowLabel.Font = UI.Theme.HeaderFont
	titleRowLabel.TextSize = 11
	titleRowLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleRowLabel.Parent = titleRow

	-- middle info block + game icon
	local middleBlock = Instance.new("Frame")
	middleBlock.Name = "MiddleBlock"
	middleBlock.Size = UDim2.new(1, 0, 1, -26)
	middleBlock.Position = UDim2.new(0, 0, 0, 26)
	middleBlock.BackgroundTransparency = 1
	middleBlock.ClipsDescendants = true
	middleBlock.Parent = rightSide

	-- game icon (right side of middle block)
	local gameIconBox = Instance.new("Frame")
	gameIconBox.Name = "GameIconBox"
	gameIconBox.Size = UDim2.new(0, 52, 1, 0)
	gameIconBox.Position = UDim2.new(1, -52, 0, 0)
	gameIconBox.BackgroundColor3 = UI.Theme.ContainerDark
	gameIconBox.BorderSizePixel = 0
	gameIconBox.ClipsDescendants = true
	gameIconBox.Parent = middleBlock

	local gameIconStroke = Instance.new("UIStroke")
	gameIconStroke.Color = UI.Theme.Border
	gameIconStroke.Thickness = 1.2
	gameIconStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	gameIconStroke.Parent = gameIconBox

	local gameIconImg = Instance.new("ImageLabel")
	gameIconImg.Size = UDim2.new(1, -4, 1, -4)
	gameIconImg.Position = UDim2.new(0, 2, 0, 2)
	gameIconImg.BackgroundTransparency = 1
	gameIconImg.Image = string.format("rbxthumb://type=GameIcon&id=%d&w=150&h=150", game.PlaceId)
	gameIconImg.Parent = gameIconBox

	-- info rows
	local infoList = Instance.new("Frame")
	infoList.Name = "InfoList"
	infoList.Size = UDim2.new(1, -58, 1, 0)
	infoList.BackgroundTransparency = 1
	infoList.ClipsDescendants = true
	infoList.Parent = middleBlock

	-- info row 1 [ etc ]
	local infoRow1 = Instance.new("Frame")
	infoRow1.Name = "InfoRow1"
	infoRow1.Size = UDim2.new(1, 0, 0, 22)
	infoRow1.Position = UDim2.new(0, 0, 0, 0)
	infoRow1.BackgroundColor3 = UI.Theme.ContainerDark
	infoRow1.BorderSizePixel = 0
	infoRow1.ClipsDescendants = true
	infoRow1.Parent = infoList

	local row1Stroke = Instance.new("UIStroke")
	row1Stroke.Color = UI.Theme.Border
	row1Stroke.Thickness = 1
	row1Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	row1Stroke.Parent = infoRow1

	local row1Label = Instance.new("TextLabel")
	row1Label.Size = UDim2.new(1, -8, 1, 0)
	row1Label.Position = UDim2.new(0, 6, 0, 0)
	row1Label.BackgroundTransparency = 1
	row1Label.Text = string.format("User: @%s | UserID: %d", Players.LocalPlayer.Name, Players.LocalPlayer.UserId)
	row1Label.TextColor3 = UI.Theme.TextSecondary
	row1Label.Font = UI.Theme.MonoFont
	row1Label.TextSize = 10
	row1Label.TextXAlignment = Enum.TextXAlignment.Left
	row1Label.Parent = infoRow1

	-- info row 2 [ etc ]
	local infoRow2 = Instance.new("Frame")
	infoRow2.Name = "InfoRow2"
	infoRow2.Size = UDim2.new(1, 0, 0, 22)
	infoRow2.Position = UDim2.new(0, 0, 0, 26)
	infoRow2.BackgroundColor3 = UI.Theme.ContainerDark
	infoRow2.BorderSizePixel = 0
	infoRow2.ClipsDescendants = true
	infoRow2.Parent = infoList

	local row2Stroke = Instance.new("UIStroke")
	row2Stroke.Color = UI.Theme.Border
	row2Stroke.Thickness = 1
	row2Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	row2Stroke.Parent = infoRow2

	local row2Label = Instance.new("TextLabel")
	row2Label.Size = UDim2.new(1, -8, 1, 0)
	row2Label.Position = UDim2.new(0, 6, 0, 0)
	row2Label.BackgroundTransparency = 1
	row2Label.Text = string.format("Account Age: %d days | PlaceID: %d", Players.LocalPlayer.AccountAge, game.PlaceId)
	row2Label.TextColor3 = UI.Theme.TextSecondary
	row2Label.Font = UI.Theme.MonoFont
	row2Label.TextSize = 10
	row2Label.TextXAlignment = Enum.TextXAlignment.Left
	row2Label.Parent = infoRow2

	return banner
end

return UI
