--!strict
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local Animations = require("UI/Animations.luau")

local UI = {}
UI.__index = UI

UI.Themes = {
	Dark = {
		Name = "Dark",
		Background = Color3.fromRGB(13, 13, 15),
		BackgroundTransparency = 0.22,
		Border = Color3.fromRGB(250, 250, 255), -- Crisp white outlines for dark mode
		BorderDim = Color3.fromRGB(120, 120, 135),
		Accent = Color3.fromRGB(55, 175, 245), -- Light blue-ish selection accent
		AccentDark = Color3.fromRGB(30, 120, 200),
		AccentText = Color3.fromRGB(255, 255, 255),
		TextPrimary = Color3.fromRGB(245, 245, 245),
		TextSecondary = Color3.fromRGB(170, 170, 185),
		Container = Color3.fromRGB(22, 22, 28),
		ContainerTransparency = 0.28,
		ContainerDark = Color3.fromRGB(15, 15, 20),
		ContainerDarkTransparency = 0.35
	},
	Light = {
		Name = "Light",
		Background = Color3.fromRGB(242, 243, 246),
		BackgroundTransparency = 0.22,
		Border = Color3.fromRGB(12, 12, 16), -- True black outlines for light mode
		BorderDim = Color3.fromRGB(130, 130, 140),
		Accent = Color3.fromRGB(45, 155, 235), -- Light blue accent
		AccentDark = Color3.fromRGB(25, 110, 185),
		AccentText = Color3.fromRGB(255, 255, 255),
		TextPrimary = Color3.fromRGB(15, 15, 20),
		TextSecondary = Color3.fromRGB(75, 75, 85),
		Container = Color3.fromRGB(255, 255, 255),
		ContainerTransparency = 0.25,
		ContainerDark = Color3.fromRGB(228, 230, 236),
		ContainerDarkTransparency = 0.32
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
		Background = Color3.fromRGB(16, 16, 22),
		BackgroundTransparency = 0.35,
		Border = Color3.fromRGB(240, 240, 250),
		BorderDim = Color3.fromRGB(90, 90, 110),
		Accent = Color3.fromRGB(55, 175, 245),
		AccentDark = Color3.fromRGB(30, 120, 200),
		AccentText = Color3.fromRGB(255, 255, 255),
		TextPrimary = Color3.fromRGB(250, 250, 255),
		TextSecondary = Color3.fromRGB(175, 175, 190),
		Container = Color3.fromRGB(24, 24, 32),
		ContainerTransparency = 0.30,
		ContainerDark = Color3.fromRGB(14, 14, 20),
		ContainerDarkTransparency = 0.40
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

-- Persistent theme registry: keys are Instances, values are sets of propType strings.
-- Destroying event automatically cleans up destroyed instances to prevent memory leaks.
UI.RegisteredElements = {} :: {[Instance]: {[string]: boolean}}

function UI.registerThemeElement(inst: Instance, propType: string)
	if not inst then return end
	local propMap = UI.RegisteredElements[inst]
	if not propMap then
		propMap = {}
		UI.RegisteredElements[inst] = propMap

		-- Clean up automatically when the instance is destroyed
		pcall(function()
			inst.Destroying:Connect(function()
				UI.RegisteredElements[inst] = nil
			end)
		end)
	end
	propMap[propType] = true
end

function UI.unregisterThemeElement(inst: Instance, propType: string?)
	if not inst then return end
	if propType then
		local propMap = UI.RegisteredElements[inst]
		if propMap then
			propMap[propType] = nil
		end
	else
		UI.RegisteredElements[inst] = nil
	end
end

function UI.cleanupRegistry()
	for inst in pairs(UI.RegisteredElements) do
		if not inst or not inst.Parent then
			UI.RegisteredElements[inst] = nil
		end
	end
end

local lastAdaptiveAccent: Color3? = nil
local lastAdaptiveBg: Color3? = nil

function UI.applyAdaptiveTheme(accentCol: Color3, bgCol: Color3, containerCol: Color3, borderCol: Color3?)
	if lastAdaptiveAccent == accentCol and lastAdaptiveBg == bgCol then
		return
	end
	lastAdaptiveAccent = accentCol
	lastAdaptiveBg = bgCol

	local ad = UI.Themes.Adaptive
	ad.Accent = accentCol
	ad.AccentDark = Color3.fromRGB(math.floor(accentCol.R * 255 * 0.7), math.floor(accentCol.G * 255 * 0.7), math.floor(accentCol.B * 255 * 0.7))
	ad.Background = bgCol
	ad.BackgroundTransparency = 0.35
	ad.Container = containerCol
	ad.ContainerTransparency = 0.30
	ad.ContainerDark = bgCol
	ad.ContainerDarkTransparency = 0.40
	ad.Border = borderCol or Color3.fromRGB(240, 240, 250)

	if UI.CurrentTheme.Name == "Adaptive" then
		UI.setTheme("Adaptive")
	end
end

UI.ThemeChangedCallbacks = {} :: { (targetTheme: any) -> () }

function UI.onThemeChanged(callback: (targetTheme: any) -> ())
	table.insert(UI.ThemeChangedCallbacks, callback)
end

function UI.setTheme(themeName: string)
	local targetTheme = UI.Themes[themeName] or UI.Themes.Dark
	UI.CurrentTheme = targetTheme
	UI.Theme = targetTheme
	UI.saveTheme(themeName)
	
	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	for inst, propMap in pairs(UI.RegisteredElements) do
		if inst and inst.Parent then
			for pt in pairs(propMap) do
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
					TweenService:Create(inst, tweenInfo, { TextColor3 = targetTheme.AccentText }):Play()
				elseif pt == "BorderDimText" and inst:IsA("TextLabel") then
					TweenService:Create(inst, tweenInfo, { TextColor3 = targetTheme.BorderDim }):Play()
				end
			end
		else
			UI.RegisteredElements[inst] = nil
		end
	end

	for _, cb in ipairs(UI.ThemeChangedCallbacks) do
		pcall(cb, targetTheme)
	end

	-- Universal hierarchy sweep across all Modular UI ScreenGuis to guarantee 100% theme coverage
	pcall(function()
		local CoreGui = game:GetService("CoreGui")
		local Players = game:GetService("Players")
		local roots = {}

		local guiNames = {
			"ModularEngineGui",
			"ModularNotificationsGui",
			"ModularPlayerListGui",
			"ModularChatGui",
			"ModularMusicTrackerGui",
			"ModularHotbarGui"
		}

		for _, name in ipairs(guiNames) do
			local g = CoreGui:FindFirstChild(name)
			if g then table.insert(roots, g) end
			if Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui") then
				local pg = Players.LocalPlayer.PlayerGui:FindFirstChild(name)
				if pg then table.insert(roots, pg) end
			end
		end

		for _, root in ipairs(roots) do
			for _, inst in ipairs(root:GetDescendants()) do
				if inst:IsA("UIStroke") then
					if inst.Thickness >= 1.4 then
						inst.Color = targetTheme.Border
					else
						inst.Color = targetTheme.BorderDim
					end
				elseif inst:IsA("Frame") then
					if inst.Name == "TitleBox" or inst.Name == "DecoBar" or inst.Name == "HeaderBox" or inst.Name == "ActiveTagBox" or string.find(inst.Name, "Box") then
						inst.BackgroundColor3 = targetTheme.Container
						inst.BackgroundTransparency = targetTheme.ContainerTransparency
					elseif inst.Name == "MainWindow" or inst.Name == "Window" then
						inst.BackgroundColor3 = targetTheme.Background
						inst.BackgroundTransparency = targetTheme.BackgroundTransparency
					end
				elseif inst:IsA("TextButton") then
					local propMap = UI.RegisteredElements[inst]
					local isAccent = propMap and propMap["Accent"]
					if not isAccent then
						inst.BackgroundColor3 = targetTheme.Container
						inst.BackgroundTransparency = targetTheme.ContainerTransparency
						if propMap and propMap["TextSecondary"] then
							inst.TextColor3 = targetTheme.TextSecondary
						else
							inst.TextColor3 = targetTheme.TextPrimary
						end
					else
						inst.BackgroundColor3 = targetTheme.Accent
						inst.TextColor3 = targetTheme.AccentText
					end
				elseif inst:IsA("TextLabel") then
					local propMap = UI.RegisteredElements[inst]
					if propMap and propMap["AccentText"] then
						inst.TextColor3 = targetTheme.AccentText
					elseif propMap and propMap["TextSecondary"] then
						inst.TextColor3 = targetTheme.TextSecondary
					elseif propMap and propMap["BorderDimText"] then
						inst.TextColor3 = targetTheme.BorderDim
					else
						inst.TextColor3 = targetTheme.TextPrimary
					end
				elseif inst:IsA("TextBox") then
					inst.TextColor3 = targetTheme.TextPrimary
					inst.PlaceholderColor3 = targetTheme.TextSecondary
					inst.BackgroundColor3 = targetTheme.ContainerDark
					inst.BackgroundTransparency = targetTheme.ContainerDarkTransparency
				end
			end
		end
	end)
end

function UI.makeDraggable(topbar: GuiObject, frame: GuiObject)
	local dragging = false
	local dragInput: InputObject? = nil
	local dragStart = Vector3.zero
	local startPos = UDim2.new()

	local function update(input: InputObject)
		local delta = input.Position - dragStart
		frame.Position = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
	end

	topbar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position

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
			update(input)
		end
	end)
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

	local outerStroke = Instance.new("UIStroke")
	outerStroke.Color = UI.Theme.Border
	outerStroke.Thickness = 1.5
	outerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outerStroke.Parent = mainFrame
	UI.registerThemeElement(outerStroke, "Border")

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 1.0
	uiScale.Parent = mainFrame

	-- ── Top Bar (Segmented: [Version] [Tabs: Main Combat Visuals ...] [Title Controls — X]) ──
	local topbar = Instance.new("Frame")
	topbar.Name = "TopBar"
	topbar.Size = UDim2.new(1, -16, 0, 26)
	topbar.Position = UDim2.new(0, 8, 0, 8)
	topbar.BackgroundTransparency = 1
	topbar.BorderSizePixel = 0
	topbar.Parent = mainFrame

	-- [ Version ] Box on Left
	local versionBox = Instance.new("Frame")
	versionBox.Name = "VersionBox"
	versionBox.Size = UDim2.new(0, 60, 1, 0)
	versionBox.Position = UDim2.new(0, 0, 0, 0)
	versionBox.BackgroundColor3 = UI.Theme.Container
	versionBox.BackgroundTransparency = UI.Theme.ContainerTransparency
	versionBox.BorderSizePixel = 0
	versionBox.Parent = topbar
	UI.registerThemeElement(versionBox, "Container")

	local versionStroke = Instance.new("UIStroke")
	versionStroke.Color = UI.Theme.Border
	versionStroke.Thickness = 1.0
	versionStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	versionStroke.Parent = versionBox
	UI.registerThemeElement(versionStroke, "Border")

	local versionLabel = Instance.new("TextLabel")
	versionLabel.Name = "VersionLabel"
	versionLabel.Size = UDim2.new(1, 0, 1, 0)
	versionLabel.BackgroundTransparency = 1
	versionLabel.Text = "v1.4.5"
	versionLabel.TextColor3 = UI.Theme.TextPrimary
	versionLabel.Font = UI.Fonts.Header
	versionLabel.TextSize = 11
	versionLabel.Parent = versionBox
	UI.registerThemeElement(versionLabel, "TextPrimary")

	-- [ Tabs Container ] in Top Bar Area
	local sidebar = Instance.new("ScrollingFrame")
	sidebar.Name = "Sidebar"
	sidebar.Size = UDim2.new(1, -260, 1, 0)
	sidebar.Position = UDim2.new(0, 66, 0, 0)
	sidebar.BackgroundTransparency = 1
	sidebar.BorderSizePixel = 0
	sidebar.ScrollBarThickness = 0
	sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
	sidebar.AutomaticCanvasSize = Enum.AutomaticSize.X
	sidebar.ClipsDescendants = false
	sidebar.Parent = topbar

	local sideList = Instance.new("UIListLayout")
	sideList.Padding = UDim.new(0, 6)
	sideList.SortOrder = Enum.SortOrder.LayoutOrder
	sideList.FillDirection = Enum.FillDirection.Horizontal
	sideList.VerticalAlignment = Enum.VerticalAlignment.Center
	sideList.Parent = sidebar

	-- [ Title & Controls ] Box on Right
	local titleBox = Instance.new("Frame")
	titleBox.Name = "TitleBox"
	titleBox.Size = UDim2.new(0, 188, 1, 0)
	titleBox.Position = UDim2.new(1, -188, 0, 0)
	titleBox.BackgroundColor3 = UI.Theme.Container
	titleBox.BackgroundTransparency = UI.Theme.ContainerTransparency
	titleBox.BorderSizePixel = 0
	titleBox.Parent = topbar
	UI.registerThemeElement(titleBox, "Container")

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = UI.Theme.Border
	titleStroke.Thickness = 1.0
	titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	titleStroke.Parent = titleBox
	UI.registerThemeElement(titleStroke, "Border")

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, -54, 1, 0)
	titleLabel.Position = UDim2.new(0, 6, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = titleText
	titleLabel.TextColor3 = UI.Theme.TextPrimary
	titleLabel.Font = UI.Fonts.Header
	titleLabel.TextSize = 11
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.Parent = titleBox
	UI.registerThemeElement(titleLabel, "TextPrimary")

	-- Minimize button [ — ]
	local minButton = Instance.new("TextButton")
	minButton.Name = "MinButton"
	minButton.Size = UDim2.new(0, 22, 1, -4)
	minButton.Position = UDim2.new(1, -48, 0, 2)
	minButton.BackgroundColor3 = UI.Theme.ContainerDark
	minButton.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	minButton.BorderSizePixel = 0
	minButton.Text = "—"
	minButton.TextColor3 = UI.Theme.TextPrimary
	minButton.Font = UI.Fonts.Header
	minButton.TextSize = 12
	minButton.Parent = titleBox
	UI.registerThemeElement(minButton, "ContainerDark")
	UI.registerThemeElement(minButton, "TextPrimary")

	local minStroke = Instance.new("UIStroke")
	minStroke.Color = UI.Theme.Border
	minStroke.Thickness = 1.0
	minStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	minStroke.Parent = minButton
	UI.registerThemeElement(minStroke, "Border")

	-- Close button [ X ]
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 22, 1, -4)
	closeButton.Position = UDim2.new(1, -24, 0, 2)
	closeButton.BackgroundColor3 = UI.Theme.ContainerDark
	closeButton.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	closeButton.BorderSizePixel = 0
	closeButton.Text = "X"
	closeButton.TextColor3 = UI.Theme.TextPrimary
	closeButton.Font = UI.Fonts.Header
	closeButton.TextSize = 11
	closeButton.Parent = titleBox
	UI.registerThemeElement(closeButton, "ContainerDark")
	UI.registerThemeElement(closeButton, "TextPrimary")

	local closeStroke = Instance.new("UIStroke")
	closeStroke.Color = UI.Theme.Border
	closeStroke.Thickness = 1.0
	closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	closeStroke.Parent = closeButton
	UI.registerThemeElement(closeStroke, "Border")

	-- ── Body Frame (Full Width Content Area) ──────────────────────────
	local bodyFrame = Instance.new("Frame")
	bodyFrame.Name = "BodyFrame"
	bodyFrame.Size = UDim2.new(1, -16, 1, -72)
	bodyFrame.Position = UDim2.new(0, 8, 0, 40)
	bodyFrame.BackgroundTransparency = 1
	bodyFrame.BorderSizePixel = 0
	bodyFrame.ClipsDescendants = false
	bodyFrame.Parent = mainFrame

	local contentContainer = Instance.new("Frame")
	contentContainer.Name = "ContentContainer"
	contentContainer.Size = UDim2.new(1, 0, 1, 0)
	contentContainer.Position = UDim2.new(0, 0, 0, 0)
	contentContainer.BackgroundTransparency = 1
	contentContainer.BorderSizePixel = 0
	contentContainer.ClipsDescendants = false
	contentContainer.Parent = bodyFrame

	-- ── Footer Bar (Segmented: [Status / Info Bar] [Settings] [Themes]) ─
	local footerBar = Instance.new("Frame")
	footerBar.Name = "FooterBar"
	footerBar.Size = UDim2.new(1, -16, 0, 24)
	footerBar.Position = UDim2.new(0, 8, 1, -30)
	footerBar.BackgroundTransparency = 1
	footerBar.BorderSizePixel = 0
	footerBar.Parent = mainFrame

	-- Left Status / Info Bar
	local statusBox = Instance.new("Frame")
	statusBox.Name = "StatusBox"
	statusBox.Size = UDim2.new(1, -196, 1, 0)
	statusBox.Position = UDim2.new(0, 0, 0, 0)
	statusBox.BackgroundColor3 = UI.Theme.Container
	statusBox.BackgroundTransparency = UI.Theme.ContainerTransparency
	statusBox.BorderSizePixel = 0
	statusBox.ClipsDescendants = true
	statusBox.Parent = footerBar
	UI.registerThemeElement(statusBox, "Container")

	local statusStroke = Instance.new("UIStroke")
	statusStroke.Color = UI.Theme.Border
	statusStroke.Thickness = 1.2
	statusStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	statusStroke.Parent = statusBox
	UI.registerThemeElement(statusStroke, "Border")

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -12, 1, 0)
	statusLabel.Position = UDim2.new(0, 6, 0, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Main"
	statusLabel.TextColor3 = UI.Theme.TextSecondary
	statusLabel.Font = UI.Fonts.Header
	statusLabel.TextSize = 11
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
	statusLabel.Parent = statusBox
	UI.registerThemeElement(statusLabel, "TextSecondary")

	local activeTagLabel = statusLabel -- Seamless compatibility

	-- Settings Button
	local settingsBtn = Instance.new("TextButton")
	settingsBtn.Name = "SettingsBtn"
	settingsBtn.Size = UDim2.new(0, 92, 1, 0)
	settingsBtn.Position = UDim2.new(1, -190, 0, 0)
	settingsBtn.BackgroundColor3 = UI.Theme.Container
	settingsBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
	settingsBtn.BorderSizePixel = 0
	settingsBtn.Text = "Settings"
	settingsBtn.TextColor3 = UI.Theme.TextPrimary
	settingsBtn.Font = UI.Fonts.Header
	settingsBtn.TextSize = 11
	settingsBtn.Parent = footerBar
	UI.registerThemeElement(settingsBtn, "Container")
	UI.registerThemeElement(settingsBtn, "TextPrimary")

	local settingsStroke = Instance.new("UIStroke")
	settingsStroke.Color = UI.Theme.Border
	settingsStroke.Thickness = 1.2
	settingsStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	settingsStroke.Parent = settingsBtn
	UI.registerThemeElement(settingsStroke, "Border")

	-- Themes Button
	local themesBtn = Instance.new("TextButton")
	themesBtn.Name = "ThemesBtn"
	themesBtn.Size = UDim2.new(0, 92, 1, 0)
	themesBtn.Position = UDim2.new(1, -92, 0, 0)
	themesBtn.BackgroundColor3 = UI.Theme.Container
	themesBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
	themesBtn.BorderSizePixel = 0
	themesBtn.Text = "Themes"
	themesBtn.TextColor3 = UI.Theme.TextPrimary
	themesBtn.Font = UI.Fonts.Header
	themesBtn.TextSize = 11
	themesBtn.Parent = footerBar
	UI.registerThemeElement(themesBtn, "Container")
	UI.registerThemeElement(themesBtn, "TextPrimary")

	local themesStroke = Instance.new("UIStroke")
	themesStroke.Color = UI.Theme.Border
	themesStroke.Thickness = 1.2
	themesStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	themesStroke.Parent = themesBtn
	UI.registerThemeElement(themesStroke, "Border")

	local configsBtn = themesBtn -- Seamless compatibility

	UI.makeDraggable(topbar, mainFrame)
	UI.makeDraggable(titleBox, mainFrame)
	UI.makeDraggable(versionBox, mainFrame)

	-- Button Hover & Click animations
	local function attachBtnFX(btn: TextButton, isClose: boolean?)
		local stroke = btn:FindFirstChildWhichIsA("UIStroke")
		btn.MouseEnter:Connect(function()
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.12), { Thickness = 1.8 }):Play()
			end
			local hoverCol = if isClose then Color3.fromRGB(220, 60, 60) else UI.Theme.Accent
			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = hoverCol, TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
		end)
		btn.MouseLeave:Connect(function()
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.12), { Thickness = 1.2 }):Play()
			end
			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.Container, TextColor3 = UI.Theme.TextPrimary }):Play()
		end)
	end

	attachBtnFX(minButton, false)
	attachBtnFX(closeButton, true)
	attachBtnFX(settingsBtn, false)
	attachBtnFX(themesBtn, false)

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

	local function openWindow(onComplete: (() -> ())?)
		if isOpen or isTransitioning then return end
		isTransitioning = true
		Animations.openWindow(mainFrame, uiScale, function()
			isOpen = true
			isTransitioning = false
			if onComplete then
				onComplete()
			end
		end)
	end

	local function closeWindow(onComplete: (() -> ())?)
		if not isOpen or isTransitioning then return end
		isTransitioning = true
		Animations.closeWindow(mainFrame, uiScale, function()
			isOpen = false
			isTransitioning = false
			if onComplete then
				onComplete()
			end
		end)
	end

	local function toggleWindow(onComplete: (() -> ())?)
		if isOpen then
			closeWindow(onComplete)
		else
			openWindow(onComplete)
		end
	end

	local function setWindowVisible(visible: boolean, onComplete: (() -> ())?)
		if visible then
			openWindow(onComplete)
		else
			closeWindow(onComplete)
		end
	end

	closeButton.MouseButton1Click:Connect(function()
		closeWindow()
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.RightBracket then
			toggleWindow()
		end
	end)

	local controller = {
		openWindow = openWindow,
		closeWindow = closeWindow,
		toggleWindow = toggleWindow,
		setWindowVisible = setWindowVisible,
		isOpen = function() return isOpen end,
		isTransitioning = function() return isTransitioning end,
	}

	return mainFrame, topbar, sidebar, contentContainer, activeTagLabel, settingsBtn, configsBtn, uiScale, controller, themesBtn, statusLabel
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
	avatarImg.Parent = mugshotBox
	task.spawn(function()
		local ok, thumb = pcall(function()
			return Players:GetUserThumbnailAsync(Players.LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and thumb and avatarImg.Parent then
			avatarImg.Image = thumb
		end
	end)

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
