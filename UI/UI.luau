--!strict
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local UI = {}
UI.__index = UI

UI.Themes = {
	Dark = {
		Name = "Dark",
		Background = Color3.fromRGB(13, 13, 15),
		BackgroundTransparency = 0.02,
		Border = Color3.fromRGB(250, 250, 255), -- Crisp white outlines for dark mode
		BorderDim = Color3.fromRGB(85, 85, 95),
		Accent = Color3.fromRGB(55, 175, 245), -- Light blue-ish selection accent
		AccentDark = Color3.fromRGB(30, 120, 200),
		AccentText = Color3.fromRGB(255, 255, 255),
		TextPrimary = Color3.fromRGB(245, 245, 245),
		TextSecondary = Color3.fromRGB(160, 160, 170),
		Container = Color3.fromRGB(22, 22, 26),
		ContainerTransparency = 0,
		ContainerDark = Color3.fromRGB(15, 15, 18),
		ContainerDarkTransparency = 0
	},
	Light = {
		Name = "Light",
		Background = Color3.fromRGB(242, 243, 246),
		BackgroundTransparency = 0.02,
		Border = Color3.fromRGB(12, 12, 16), -- True black outlines for light mode
		BorderDim = Color3.fromRGB(130, 130, 140),
		Accent = Color3.fromRGB(45, 155, 235), -- Light blue accent
		AccentDark = Color3.fromRGB(25, 110, 185),
		AccentText = Color3.fromRGB(255, 255, 255),
		TextPrimary = Color3.fromRGB(15, 15, 20),
		TextSecondary = Color3.fromRGB(75, 75, 85),
		Container = Color3.fromRGB(255, 255, 255),
		ContainerTransparency = 0,
		ContainerDark = Color3.fromRGB(228, 230, 236),
		ContainerDarkTransparency = 0
	},
	TranslucentDark = {
		Name = "Translucent Dark",
		Background = Color3.fromRGB(12, 12, 16),
		BackgroundTransparency = 0.40,
		Border = Color3.fromRGB(250, 250, 255), -- White outlines
		BorderDim = Color3.fromRGB(90, 90, 110),
		Accent = Color3.fromRGB(55, 175, 245), -- Light blue accent
		AccentDark = Color3.fromRGB(30, 120, 200),
		AccentText = Color3.fromRGB(255, 255, 255),
		TextPrimary = Color3.fromRGB(255, 255, 255),
		TextSecondary = Color3.fromRGB(180, 180, 195),
		Container = Color3.fromRGB(24, 24, 32),
		ContainerTransparency = 0.35,
		ContainerDark = Color3.fromRGB(14, 14, 20),
		ContainerDarkTransparency = 0.45
	},
	TranslucentLight = {
		Name = "Translucent Light",
		Background = Color3.fromRGB(240, 242, 248),
		BackgroundTransparency = 0.40,
		Border = Color3.fromRGB(12, 12, 16), -- Black outlines
		BorderDim = Color3.fromRGB(120, 120, 135),
		Accent = Color3.fromRGB(45, 155, 235), -- Light blue accent
		AccentDark = Color3.fromRGB(25, 110, 185),
		AccentText = Color3.fromRGB(255, 255, 255),
		TextPrimary = Color3.fromRGB(12, 12, 16),
		TextSecondary = Color3.fromRGB(70, 70, 80),
		Container = Color3.fromRGB(255, 255, 255),
		ContainerTransparency = 0.35,
		ContainerDark = Color3.fromRGB(225, 228, 236),
		ContainerDarkTransparency = 0.45
	},
	Adaptive = {
		Name = "Adaptive",
		Background = Color3.fromRGB(18, 18, 22),
		BackgroundTransparency = 0.02,
		Border = Color3.fromRGB(240, 240, 250),
		BorderDim = Color3.fromRGB(80, 80, 95),
		Accent = Color3.fromRGB(55, 175, 245),
		AccentDark = Color3.fromRGB(30, 120, 200),
		AccentText = Color3.fromRGB(255, 255, 255),
		TextPrimary = Color3.fromRGB(245, 245, 245),
		TextSecondary = Color3.fromRGB(165, 165, 175),
		Container = Color3.fromRGB(26, 26, 32),
		ContainerTransparency = 0,
		ContainerDark = Color3.fromRGB(18, 18, 22),
		ContainerDarkTransparency = 0
	}
}

local HttpService = game:GetService("HttpService")

local function ensureThemeFolder(folder: string)
	local mkf = makefolder or (getgenv and getgenv().makefolder)
	local isf = isfolder or (getgenv and getgenv().isfolder)
	if type(mkf) == "function" and type(isf) == "function" then
		pcall(function()
			if not isf(folder) then mkf(folder) end
		end)
	end
end

function UI.saveTheme(themeName: string)
	ensureThemeFolder("FihSuite")
	local wrf = writefile or (getgenv and getgenv().writefile)
	if type(wrf) == "function" then
		pcall(function()
			wrf("FihSuite/Theme.json", HttpService:JSONEncode({ theme = themeName, timestamp = os.time() }))
		end)
	end
end

function UI.getSavedTheme(): string?
	local rdf = readfile or (getgenv and getgenv().readfile)
	local isf = isfile or (getgenv and getgenv().isfile)
	if type(rdf) == "function" and type(isf) == "function" then
		local ok, content = pcall(function()
			if isf("FihSuite/Theme.json") then
				return rdf("FihSuite/Theme.json")
			end
			return nil
		end)
		if ok and content then
			local dOk, decoded = pcall(function() return HttpService:JSONDecode(content) end)
			if dOk and type(decoded) == "table" and type(decoded.theme) == "string" then
				return decoded.theme
			end
		end
	end
	return nil
end

local savedThemeName = UI.getSavedTheme()
if savedThemeName and UI.Themes[savedThemeName] then
	UI.CurrentTheme = UI.Themes[savedThemeName]
	UI.Theme = UI.Themes[savedThemeName]
else
	UI.CurrentTheme = UI.Themes.Dark
	UI.Theme = UI.Themes.Dark
end

UI.Fonts = {
	Header = Enum.Font.GothamBold,
	Body = Enum.Font.GothamMedium,
	Mono = Enum.Font.Code
}

type ThemedElement = {
	Instance: Instance,
	PropType: string
}

UI.RegisteredElements = {} :: {ThemedElement}

function UI.registerThemeElement(inst: Instance, propType: string)
	table.insert(UI.RegisteredElements, { Instance = inst, PropType = propType })
end

function UI.applyAdaptiveTheme(accentCol: Color3, bgCol: Color3, containerCol: Color3, borderCol: Color3?)
	local ad = UI.Themes.Adaptive
	ad.Accent = accentCol
	ad.AccentDark = Color3.fromRGB(math.floor(accentCol.R * 255 * 0.7), math.floor(accentCol.G * 255 * 0.7), math.floor(accentCol.B * 255 * 0.7))
	ad.Background = bgCol
	ad.Container = containerCol
	ad.ContainerDark = bgCol
	ad.Border = borderCol or Color3.fromRGB(240, 240, 250)

	if UI.CurrentTheme.Name == "Adaptive" then
		UI.setTheme("Adaptive")
	end
end

function UI.setTheme(themeName: string)
	local targetTheme = UI.Themes[themeName] or UI.Themes.Dark
	UI.CurrentTheme = targetTheme
	UI.Theme = targetTheme
	UI.saveTheme(themeName)
	
	local tweenInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	for _, entry in ipairs(UI.RegisteredElements) do
		local inst = entry.Instance
		if inst and inst.Parent then
			local pt = entry.PropType
			if pt == "Background" and inst:IsA("GuiObject") then
				TweenService:Create(inst, tweenInfo, {
					BackgroundColor3 = targetTheme.Background,
					BackgroundTransparency = targetTheme.BackgroundTransparency
				}):Play()
			elseif pt == "Container" and inst:IsA("GuiObject") then
				TweenService:Create(inst, tweenInfo, {
					BackgroundColor3 = targetTheme.Container,
					BackgroundTransparency = targetTheme.ContainerTransparency
				}):Play()
			elseif pt == "ContainerDark" and inst:IsA("GuiObject") then
				TweenService:Create(inst, tweenInfo, {
					BackgroundColor3 = targetTheme.ContainerDark,
					BackgroundTransparency = targetTheme.ContainerDarkTransparency
				}):Play()
			elseif pt == "Accent" and inst:IsA("GuiObject") then
				TweenService:Create(inst, tweenInfo, {
					BackgroundColor3 = targetTheme.Accent
				}):Play()
			elseif pt == "Border" and inst:IsA("UIStroke") then
				TweenService:Create(inst, tweenInfo, { Color = targetTheme.Border }):Play()
			elseif pt == "BorderDim" and inst:IsA("UIStroke") then
				TweenService:Create(inst, tweenInfo, { Color = targetTheme.BorderDim }):Play()
			elseif pt == "TextPrimary" then
				if inst:IsA("TextLabel") or inst:IsA("TextButton") then
					TweenService:Create(inst, tweenInfo, { TextColor3 = targetTheme.TextPrimary }):Play()
				elseif inst:IsA("TextBox") then
					TweenService:Create(inst, tweenInfo, {
						TextColor3 = targetTheme.TextPrimary,
						PlaceholderColor3 = targetTheme.TextSecondary
					}):Play()
				end
			elseif pt == "TextSecondary" then
				if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
					TweenService:Create(inst, tweenInfo, { TextColor3 = targetTheme.TextSecondary }):Play()
				end
			elseif pt == "AccentText" and (inst:IsA("TextLabel") or inst:IsA("TextButton")) then
				TweenService:Create(inst, tweenInfo, { TextColor3 = targetTheme.Accent }):Play()
			elseif pt == "BorderDimText" and inst:IsA("TextLabel") then
				TweenService:Create(inst, tweenInfo, { TextColor3 = targetTheme.BorderDim }):Play()
			end
		end
	end
end

function UI.createWindow(titleText: string)
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainWindow"
	mainFrame.Size = UDim2.new(0, 720, 0, 480)
	mainFrame.Position = UDim2.new(0.5, -360, 0.5, -240)
	mainFrame.BackgroundColor3 = UI.Theme.Background
	mainFrame.BackgroundTransparency = UI.Theme.BackgroundTransparency
	mainFrame.BorderSizePixel = 0
	mainFrame.ClipsDescendants = false
	UI.registerThemeElement(mainFrame, "Background")

	local bgGradient = Instance.new("UIGradient")
	bgGradient.Rotation = 90
	bgGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 210))
	})
	bgGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0.15)
	})
	bgGradient.Parent = mainFrame

	local outerStroke = Instance.new("UIStroke")
	outerStroke.Color = UI.Theme.Border
	outerStroke.Thickness = 2
	outerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outerStroke.Parent = mainFrame
	UI.registerThemeElement(outerStroke, "Border")

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 1.0
	uiScale.Parent = mainFrame

	local topbar = Instance.new("Frame")
	topbar.Name = "TopBar"
	topbar.Size = UDim2.new(1, -16, 0, 28)
	topbar.Position = UDim2.new(0, 8, 0, 8)
	topbar.BackgroundTransparency = 1
	topbar.BorderSizePixel = 0
	topbar.Parent = mainFrame

	local titleBox = Instance.new("Frame")
	titleBox.Name = "TitleBox"
	titleBox.Size = UDim2.new(0, 220, 1, 0)
	titleBox.Position = UDim2.new(0, 0, 0, 0)
	titleBox.BackgroundColor3 = UI.Theme.Container
	titleBox.BackgroundTransparency = UI.Theme.ContainerTransparency
	titleBox.BorderSizePixel = 0
	titleBox.Parent = topbar
	UI.registerThemeElement(titleBox, "Container")

	local titleGradient = Instance.new("UIGradient")
	titleGradient.Rotation = 45
	titleGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 220, 230))
	})
	titleGradient.Parent = titleBox

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = UI.Theme.Border
	titleStroke.Thickness = 1.5
	titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	titleStroke.Parent = titleBox
	UI.registerThemeElement(titleStroke, "Border")

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -12, 1, 0)
	titleLabel.Position = UDim2.new(0, 8, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = string.format("%s >>>>>", titleText)
	titleLabel.TextColor3 = UI.Theme.TextPrimary
	titleLabel.Font = UI.Fonts.Header
	titleLabel.TextSize = 12
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = titleBox
	UI.registerThemeElement(titleLabel, "TextPrimary")

	local decoBar = Instance.new("Frame")
	decoBar.Name = "DecoBar"
	decoBar.Size = UDim2.new(1, -298, 1, 0)
	decoBar.Position = UDim2.new(0, 228, 0, 0)
	decoBar.BackgroundColor3 = UI.Theme.Container
	decoBar.BackgroundTransparency = UI.Theme.ContainerTransparency
	decoBar.BorderSizePixel = 0
	decoBar.ClipsDescendants = true
	decoBar.Parent = topbar
	UI.registerThemeElement(decoBar, "Container")

	local decoStroke = Instance.new("UIStroke")
	decoStroke.Color = UI.Theme.Border
	decoStroke.Thickness = 1.5
	decoStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	decoStroke.Parent = decoBar
	UI.registerThemeElement(decoStroke, "Border")

	local decoLabel = Instance.new("TextLabel")
	decoLabel.Size = UDim2.new(1, 0, 1, 0)
	decoLabel.BackgroundTransparency = 1
	decoLabel.Text = ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
	decoLabel.TextColor3 = UI.Theme.BorderDim
	decoLabel.Font = UI.Fonts.Mono
	decoLabel.TextSize = 12
	decoLabel.Parent = decoBar
	UI.registerThemeElement(decoLabel, "BorderDimText")

	local minButton = Instance.new("TextButton")
	minButton.Name = "MinButton"
	minButton.Size = UDim2.new(0, 30, 1, 0)
	minButton.Position = UDim2.new(1, -66, 0, 0)
	minButton.BackgroundColor3 = UI.Theme.Container
	minButton.BackgroundTransparency = UI.Theme.ContainerTransparency
	minButton.BorderSizePixel = 0
	minButton.Text = "—"
	minButton.TextColor3 = UI.Theme.TextPrimary
	minButton.Font = UI.Fonts.Header
	minButton.TextSize = 13
	minButton.Parent = topbar
	UI.registerThemeElement(minButton, "Container")
	UI.registerThemeElement(minButton, "TextPrimary")

	local minStroke = Instance.new("UIStroke")
	minStroke.Color = UI.Theme.Border
	minStroke.Thickness = 1.5
	minStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	minStroke.Parent = minButton
	UI.registerThemeElement(minStroke, "Border")

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 30, 1, 0)
	closeButton.Position = UDim2.new(1, -30, 0, 0)
	closeButton.BackgroundColor3 = UI.Theme.Container
	closeButton.BackgroundTransparency = UI.Theme.ContainerTransparency
	closeButton.BorderSizePixel = 0
	closeButton.Text = "X"
	closeButton.TextColor3 = UI.Theme.TextPrimary
	closeButton.Font = UI.Fonts.Header
	closeButton.TextSize = 13
	closeButton.Parent = topbar
	UI.registerThemeElement(closeButton, "Container")
	UI.registerThemeElement(closeButton, "TextPrimary")

	local closeStroke = Instance.new("UIStroke")
	closeStroke.Color = UI.Theme.Border
	closeStroke.Thickness = 1.5
	closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	closeStroke.Parent = closeButton
	UI.registerThemeElement(closeStroke, "Border")

	local topDivider = Instance.new("Frame")
	topDivider.Name = "TopDivider"
	topDivider.Size = UDim2.new(1, 0, 0, 2)
	topDivider.Position = UDim2.new(0, 0, 0, 42)
	topDivider.BackgroundColor3 = UI.Theme.Border
	topDivider.BorderSizePixel = 0
	topDivider.Parent = mainFrame
	UI.registerThemeElement(topDivider, "Border")

	local bodyFrame = Instance.new("Frame")
	bodyFrame.Name = "BodyFrame"
	bodyFrame.Size = UDim2.new(1, 0, 1, -62)
	bodyFrame.Position = UDim2.new(0, 0, 0, 44)
	bodyFrame.BackgroundTransparency = 1
	bodyFrame.BorderSizePixel = 0
	bodyFrame.Parent = mainFrame

	local sidebar = Instance.new("ScrollingFrame")
	sidebar.Name = "Sidebar"
	sidebar.Size = UDim2.new(0, 126, 1, -12)
	sidebar.Position = UDim2.new(0, 8, 0, 6)
	sidebar.BackgroundTransparency = 1
	sidebar.BorderSizePixel = 0
	sidebar.ScrollBarThickness = 0
	sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
	sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sidebar.ClipsDescendants = false
	sidebar.Parent = bodyFrame

	local sidePad = Instance.new("UIPadding")
	sidePad.PaddingLeft = UDim.new(0, 2)
	sidePad.PaddingRight = UDim.new(0, 2)
	sidePad.PaddingTop = UDim.new(0, 2)
	sidePad.PaddingBottom = UDim.new(0, 2)
	sidePad.Parent = sidebar

	local sideList = Instance.new("UIListLayout")
	sideList.Padding = UDim.new(0, 6)
	sideList.SortOrder = Enum.SortOrder.LayoutOrder
	sideList.Parent = sidebar

	local vertDivider = Instance.new("Frame")
	vertDivider.Name = "VertDivider"
	vertDivider.Size = UDim2.new(0, 2, 1, 0)
	vertDivider.Position = UDim2.new(0, 142, 0, 0)
	vertDivider.BackgroundColor3 = UI.Theme.Border
	vertDivider.BorderSizePixel = 0
	vertDivider.Parent = bodyFrame
	UI.registerThemeElement(vertDivider, "Border")

	local rightMain = Instance.new("Frame")
	rightMain.Name = "RightMain"
	rightMain.Size = UDim2.new(1, -154, 1, -12)
	rightMain.Position = UDim2.new(0, 150, 0, 6)
	rightMain.BackgroundTransparency = 1
	rightMain.BorderSizePixel = 0
	rightMain.ClipsDescendants = true
	rightMain.Parent = bodyFrame

	local subHeader = Instance.new("Frame")
	subHeader.Name = "SubHeader"
	subHeader.Size = UDim2.new(1, 0, 0, 26)
	subHeader.Position = UDim2.new(0, 0, 0, 0)
	subHeader.BackgroundTransparency = 1
	subHeader.BorderSizePixel = 0
	subHeader.Parent = rightMain

	local activeTagBox = Instance.new("Frame")
	activeTagBox.Name = "ActiveTagBox"
	activeTagBox.Size = UDim2.new(0, 110, 0, 24)
	activeTagBox.Position = UDim2.new(0, 2, 0, 1)
	activeTagBox.BackgroundColor3 = UI.Theme.Container
	activeTagBox.BackgroundTransparency = UI.Theme.ContainerTransparency
	activeTagBox.BorderSizePixel = 0
	activeTagBox.Parent = subHeader
	UI.registerThemeElement(activeTagBox, "Container")

	local activeTagStroke = Instance.new("UIStroke")
	activeTagStroke.Color = UI.Theme.Border
	activeTagStroke.Thickness = 1.5
	activeTagStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	activeTagStroke.Parent = activeTagBox
	UI.registerThemeElement(activeTagStroke, "Border")

	local activeTagLabel = Instance.new("TextLabel")
	activeTagLabel.Name = "Label"
	activeTagLabel.Size = UDim2.new(1, 0, 1, 0)
	activeTagLabel.BackgroundTransparency = 1
	activeTagLabel.Text = "Main"
	activeTagLabel.TextColor3 = UI.Theme.TextPrimary
	activeTagLabel.Font = UI.Fonts.Header
	activeTagLabel.TextSize = 12
	activeTagLabel.Parent = activeTagBox
	UI.registerThemeElement(activeTagLabel, "TextPrimary")

	local configsBtn = Instance.new("TextButton")
	configsBtn.Name = "ConfigsBtn"
	configsBtn.Size = UDim2.new(0, 72, 0, 24)
	configsBtn.Position = UDim2.new(1, -76, 0, 1)
	configsBtn.BackgroundColor3 = UI.Theme.Container
	configsBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
	configsBtn.BorderSizePixel = 0
	configsBtn.Text = "configs"
	configsBtn.TextColor3 = UI.Theme.TextPrimary
	configsBtn.Font = UI.Fonts.Header
	configsBtn.TextSize = 11
	configsBtn.Visible = true
	configsBtn.Parent = subHeader
	UI.registerThemeElement(configsBtn, "Container")
	UI.registerThemeElement(configsBtn, "TextPrimary")

	local configsStroke = Instance.new("UIStroke")
	configsStroke.Color = UI.Theme.Border
	configsStroke.Thickness = 1.5
	configsStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	configsStroke.Parent = configsBtn
	UI.registerThemeElement(configsStroke, "Border")

	local settingsBtn = Instance.new("TextButton")
	settingsBtn.Name = "SettingsBtn"
	settingsBtn.Size = UDim2.new(0, 72, 0, 24)
	settingsBtn.Position = UDim2.new(1, -154, 0, 1)
	settingsBtn.BackgroundColor3 = UI.Theme.Container
	settingsBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
	settingsBtn.BorderSizePixel = 0
	settingsBtn.Text = "Settings"
	settingsBtn.TextColor3 = UI.Theme.TextPrimary
	settingsBtn.Font = UI.Fonts.Header
	settingsBtn.TextSize = 11
	settingsBtn.Visible = true
	settingsBtn.Parent = subHeader
	UI.registerThemeElement(settingsBtn, "Container")
	UI.registerThemeElement(settingsBtn, "TextPrimary")

	local settingsStroke = Instance.new("UIStroke")
	settingsStroke.Color = UI.Theme.Border
	settingsStroke.Thickness = 1.5
	settingsStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	settingsStroke.Parent = settingsBtn
	UI.registerThemeElement(settingsStroke, "Border")

	local contentContainer = Instance.new("Frame")
	contentContainer.Name = "ContentContainer"
	contentContainer.Size = UDim2.new(1, 0, 1, -32)
	contentContainer.Position = UDim2.new(0, 0, 0, 32)
	contentContainer.BackgroundTransparency = 1
	contentContainer.BorderSizePixel = 0
	contentContainer.ClipsDescendants = true
	contentContainer.Parent = rightMain

	local footerBar = Instance.new("Frame")
	footerBar.Name = "FooterBar"
	footerBar.Size = UDim2.new(1, 0, 0, 14)
	footerBar.Position = UDim2.new(0, 0, 1, -14)
	footerBar.BackgroundColor3 = UI.Theme.Background
	footerBar.BackgroundTransparency = UI.Theme.BackgroundTransparency
	footerBar.BorderSizePixel = 0
	footerBar.ClipsDescendants = true
	footerBar.Parent = mainFrame
	UI.registerThemeElement(footerBar, "Background")

	local footerStroke = Instance.new("UIStroke")
	footerStroke.Color = UI.Theme.Border
	footerStroke.Thickness = 1.5
	footerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	footerStroke.Parent = footerBar
	UI.registerThemeElement(footerStroke, "Border")

	local footerHatch = Instance.new("TextLabel")
	footerHatch.Size = UDim2.new(1, 0, 1, 0)
	footerHatch.BackgroundTransparency = 1
	footerHatch.Text = "////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////"
	footerHatch.TextColor3 = UI.Theme.BorderDim
	footerHatch.Font = UI.Fonts.Mono
	footerHatch.TextSize = 11
	footerHatch.Parent = footerBar
	UI.registerThemeElement(footerHatch, "BorderDimText")

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

	-- Button Hover & Click animations
	local function attachBtnFX(btn: TextButton, isClose: boolean?)
		local stroke = btn:FindFirstChildWhichIsA("UIStroke")
		btn.MouseEnter:Connect(function()
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.12), { Thickness = 2 }):Play()
			end
			local hoverCol = if isClose then Color3.fromRGB(220, 60, 60) else UI.Theme.Accent
			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = hoverCol, TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
		end)
		btn.MouseLeave:Connect(function()
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.12), { Thickness = 1.5 }):Play()
			end
			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.Container, TextColor3 = UI.Theme.TextPrimary }):Play()
		end)
	end

	attachBtnFX(minButton, false)
	attachBtnFX(closeButton, true)
	attachBtnFX(settingsBtn, false)
	attachBtnFX(configsBtn, false)

	local minimized = false
	minButton.MouseButton1Click:Connect(function()
		minimized = not minimized
		if minimized then
			bodyFrame.Visible = false
			footerBar.Visible = false
			TweenService:Create(mainFrame, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, 720, 0, 44)
			}):Play()
		else
			bodyFrame.Visible = true
			footerBar.Visible = true
			TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, 720, 0, 480)
			}):Play()
		end
	end)

	local isOpen = true
	local isTransitioning = false

	local function openWindow()
		if isOpen or isTransitioning then return end
		isTransitioning = true
		mainFrame.Visible = true
		mainFrame.Size = UDim2.new(0, 720 * 0.9, 0, 0)
		mainFrame.BackgroundTransparency = 1
		local openTween = TweenService:Create(mainFrame, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = if minimized then UDim2.new(0, 720, 0, 44) else UDim2.new(0, 720, 0, 480),
			BackgroundTransparency = UI.Theme.BackgroundTransparency
		})
		openTween:Play()
		openTween.Completed:Connect(function()
			isOpen = true
			isTransitioning = false
		end)
	end

	local function closeWindow()
		if not isOpen or isTransitioning then return end
		isTransitioning = true
		local closeTween = TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 720 * 0.9, 0, 0),
			BackgroundTransparency = 1
		})
		closeTween:Play()
		closeTween.Completed:Connect(function()
			mainFrame.Visible = false
			mainFrame.Size = UDim2.new(0, 720, 0, 480)
			mainFrame.BackgroundTransparency = UI.Theme.BackgroundTransparency
			isOpen = false
			isTransitioning = false
		end)
	end

	closeButton.MouseButton1Click:Connect(function()
		closeWindow()
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.RightBracket then
			if isOpen then
				closeWindow()
			else
				openWindow()
			end
		end
	end)

	return mainFrame, topbar, sidebar, contentContainer, activeTagLabel, settingsBtn, configsBtn, uiScale
end

function UI.createBannerCard(parent: GuiObject): Frame
	local banner = Instance.new("Frame")
	banner.Name = "PlayerGameBanner"
	banner.Size = UDim2.new(1, -6, 0, 88)
	banner.Position = UDim2.new(0, 3, 0, 0)
	banner.BackgroundColor3 = UI.Theme.Container
	banner.BackgroundTransparency = UI.Theme.ContainerTransparency
	banner.BorderSizePixel = 0
	banner.ClipsDescendants = true
	banner.Parent = parent
	UI.registerThemeElement(banner, "Container")

	local bannerGradient = Instance.new("UIGradient")
	bannerGradient.Rotation = 90
	bannerGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(215, 215, 225))
	})
	bannerGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0.1)
	})
	bannerGradient.Parent = banner

	local bannerStroke = Instance.new("UIStroke")
	bannerStroke.Color = UI.Theme.Border
	bannerStroke.Thickness = 1.5
	bannerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bannerStroke.Parent = banner
	UI.registerThemeElement(bannerStroke, "Border")

	local mugshotBox = Instance.new("Frame")
	mugshotBox.Name = "MugshotBox"
	mugshotBox.Size = UDim2.new(0, 78, 1, -8)
	mugshotBox.Position = UDim2.new(0, 4, 0, 4)
	mugshotBox.BackgroundColor3 = UI.Theme.ContainerDark
	mugshotBox.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	mugshotBox.BorderSizePixel = 0
	mugshotBox.ClipsDescendants = true
	mugshotBox.Parent = banner
	UI.registerThemeElement(mugshotBox, "ContainerDark")

	local mugshotStroke = Instance.new("UIStroke")
	mugshotStroke.Color = UI.Theme.Border
	mugshotStroke.Thickness = 1.2
	mugshotStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	mugshotStroke.Parent = mugshotBox
	UI.registerThemeElement(mugshotStroke, "Border")

	local avatarImg = Instance.new("ImageLabel")
	avatarImg.Size = UDim2.new(1, -4, 1, -4)
	avatarImg.Position = UDim2.new(0, 2, 0, 2)
	avatarImg.BackgroundTransparency = 1
	avatarImg.Image = Players:GetUserThumbnailAsync(Players.LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
	avatarImg.Parent = mugshotBox

	local rightSide = Instance.new("Frame")
	rightSide.Name = "RightSide"
	rightSide.Size = UDim2.new(1, -92, 1, -8)
	rightSide.Position = UDim2.new(0, 86, 0, 4)
	rightSide.BackgroundTransparency = 1
	rightSide.BorderSizePixel = 0
	rightSide.ClipsDescendants = true
	rightSide.Parent = banner

	local titleRow = Instance.new("Frame")
	titleRow.Name = "TitleRow"
	titleRow.Size = UDim2.new(1, 0, 0, 22)
	titleRow.Position = UDim2.new(0, 0, 0, 0)
	titleRow.BackgroundColor3 = UI.Theme.ContainerDark
	titleRow.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	titleRow.BorderSizePixel = 0
	titleRow.ClipsDescendants = true
	titleRow.Parent = rightSide
	UI.registerThemeElement(titleRow, "ContainerDark")

	local titleRowStroke = Instance.new("UIStroke")
	titleRowStroke.Color = UI.Theme.Border
	titleRowStroke.Thickness = 1.2
	titleRowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	titleRowStroke.Parent = titleRow
	UI.registerThemeElement(titleRowStroke, "Border")

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
	titleRowLabel.Font = UI.Fonts.Header
	titleRowLabel.TextSize = 11
	titleRowLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleRowLabel.Parent = titleRow
	UI.registerThemeElement(titleRowLabel, "TextPrimary")

	local middleBlock = Instance.new("Frame")
	middleBlock.Name = "MiddleBlock"
	middleBlock.Size = UDim2.new(1, 0, 1, -26)
	middleBlock.Position = UDim2.new(0, 0, 0, 26)
	middleBlock.BackgroundTransparency = 1
	middleBlock.BorderSizePixel = 0
	middleBlock.ClipsDescendants = true
	middleBlock.Parent = rightSide

	local gameIconBox = Instance.new("Frame")
	gameIconBox.Name = "GameIconBox"
	gameIconBox.Size = UDim2.new(0, 52, 1, 0)
	gameIconBox.Position = UDim2.new(1, -52, 0, 0)
	gameIconBox.BackgroundColor3 = UI.Theme.ContainerDark
	gameIconBox.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	gameIconBox.BorderSizePixel = 0
	gameIconBox.ClipsDescendants = true
	gameIconBox.Parent = middleBlock
	UI.registerThemeElement(gameIconBox, "ContainerDark")

	local gameIconStroke = Instance.new("UIStroke")
	gameIconStroke.Color = UI.Theme.Border
	gameIconStroke.Thickness = 1.2
	gameIconStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	gameIconStroke.Parent = gameIconBox
	UI.registerThemeElement(gameIconStroke, "Border")

	local gameIconImg = Instance.new("ImageLabel")
	gameIconImg.Size = UDim2.new(1, -4, 1, -4)
	gameIconImg.Position = UDim2.new(0, 2, 0, 2)
	gameIconImg.BackgroundTransparency = 1
	gameIconImg.Image = string.format("rbxthumb://type=GameIcon&id=%d&w=150&h=150", game.PlaceId)
	gameIconImg.Parent = gameIconBox

	local infoList = Instance.new("Frame")
	infoList.Name = "InfoList"
	infoList.Size = UDim2.new(1, -58, 1, 0)
	infoList.Position = UDim2.new(0, 0, 0, 0)
	infoList.BackgroundTransparency = 1
	infoList.BorderSizePixel = 0
	infoList.ClipsDescendants = true
	infoList.Parent = middleBlock

	local infoRow1 = Instance.new("Frame")
	infoRow1.Name = "InfoRow1"
	infoRow1.Size = UDim2.new(1, 0, 0, 22)
	infoRow1.Position = UDim2.new(0, 0, 0, 0)
	infoRow1.BackgroundColor3 = UI.Theme.ContainerDark
	infoRow1.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	infoRow1.BorderSizePixel = 0
	infoRow1.ClipsDescendants = true
	infoRow1.Parent = infoList
	UI.registerThemeElement(infoRow1, "ContainerDark")

	local row1Stroke = Instance.new("UIStroke")
	row1Stroke.Color = UI.Theme.Border
	row1Stroke.Thickness = 1
	row1Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	row1Stroke.Parent = infoRow1
	UI.registerThemeElement(row1Stroke, "Border")

	local row1Label = Instance.new("TextLabel")
	row1Label.Size = UDim2.new(1, -8, 1, 0)
	row1Label.Position = UDim2.new(0, 6, 0, 0)
	row1Label.BackgroundTransparency = 1
	row1Label.Text = string.format("User: @%s | UserID: %d", Players.LocalPlayer.Name, Players.LocalPlayer.UserId)
	row1Label.TextColor3 = UI.Theme.TextSecondary
	row1Label.Font = UI.Fonts.Mono
	row1Label.TextSize = 10
	row1Label.TextXAlignment = Enum.TextXAlignment.Left
	row1Label.Parent = infoRow1
	UI.registerThemeElement(row1Label, "TextSecondary")

	local infoRow2 = Instance.new("Frame")
	infoRow2.Name = "InfoRow2"
	infoRow2.Size = UDim2.new(1, 0, 0, 22)
	infoRow2.Position = UDim2.new(0, 0, 0, 26)
	infoRow2.BackgroundColor3 = UI.Theme.ContainerDark
	infoRow2.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	infoRow2.BorderSizePixel = 0
	infoRow2.ClipsDescendants = true
	infoRow2.Parent = infoList
	UI.registerThemeElement(infoRow2, "ContainerDark")

	local row2Stroke = Instance.new("UIStroke")
	row2Stroke.Color = UI.Theme.Border
	row2Stroke.Thickness = 1
	row2Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	row2Stroke.Parent = infoRow2
	UI.registerThemeElement(row2Stroke, "Border")

	local row2Label = Instance.new("TextLabel")
	row2Label.Size = UDim2.new(1, -8, 1, 0)
	row2Label.Position = UDim2.new(0, 6, 0, 0)
	row2Label.BackgroundTransparency = 1
	row2Label.Text = string.format("Account Age: %d days | PlaceID: %d", Players.LocalPlayer.AccountAge, game.PlaceId)
	row2Label.TextColor3 = UI.Theme.TextSecondary
	row2Label.Font = UI.Fonts.Mono
	row2Label.TextSize = 10
	row2Label.TextXAlignment = Enum.TextXAlignment.Left
	row2Label.Parent = infoRow2
	UI.registerThemeElement(row2Label, "TextSecondary")

	return banner
end

return UI
