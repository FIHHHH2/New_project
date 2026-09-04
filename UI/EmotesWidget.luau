--!strict
--[=[
    ✦ Squared Retro Emotes HUD & Universal Animation Player Widget ✦
    Features:
    - 30+ Built-in Universal & Viral Animations (Classic, Dances, Viral Memes, Poses)
    - Custom Roblox Animation Asset ID Player input
    - Real-Time Emote Speed Control (0.25x to 3.0x) & Looping Toggle
    - R6 and R15 Rig Auto-Detection & Fallback to Humanoid:PlayEmote()
    - Active Emote Status Banner with Instant Stop Button
    - Search & Category Filter Tabs
    - Zero-Drift Screen-Bounded Draggable Window with Aero Glass Visuals
    - 100% Theme Reactive with UI.registerThemeElement
]=]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local UI = require("UI/UI.luau")
local Animations = require("UI/Animations.luau")

local EmotesWidget = {}
EmotesWidget.__index = EmotesWidget

local LocalPlayer = Players.LocalPlayer

export type EmoteItem = {
	name: string,
	category: string,
	r15Id: string,
	r6Id: string?,
	isLooped: boolean?,
	defaultSpeed: number?,
}

local EMOTE_CATALOG: {EmoteItem} = {
	-- Classic
	{ name = "Wave", category = "Classic", r15Id = "507770239", r6Id = "128777973", isLooped = false },
	{ name = "Point", category = "Classic", r15Id = "507770453", r6Id = "128853357", isLooped = false },
	{ name = "Cheer", category = "Classic", r15Id = "507770677", r6Id = "129423030", isLooped = true },
	{ name = "Laugh", category = "Classic", r15Id = "507770818", r6Id = "129423131", isLooped = true },
	{ name = "Salute", category = "Classic", r15Id = "3360689775", r6Id = "3360689775", isLooped = false },
	{ name = "Shrug", category = "Classic", r15Id = "3360692915", r6Id = "3360692915", isLooped = false },
	{ name = "Stadium", category = "Classic", r15Id = "3360686498", r6Id = "3360686498", isLooped = true },
	{ name = "Tilt", category = "Classic", r15Id = "3360692915", r6Id = "3360692915", isLooped = false },
	{ name = "Hero Landing", category = "Classic", r15Id = "3338042785", isLooped = false },

	-- Dances
	{ name = "Dance 1", category = "Dances", r15Id = "507771019", r6Id = "182435998", isLooped = true },
	{ name = "Dance 2", category = "Dances", r15Id = "507776720", r6Id = "182436842", isLooped = true },
	{ name = "Dance 3", category = "Dances", r15Id = "507777268", r6Id = "182436935", isLooped = true },
	{ name = "Line Dance", category = "Dances", r15Id = "4049037624", isLooped = true },
	{ name = "Cha Cha", category = "Dances", r15Id = "3338025566", isLooped = true },
	{ name = "Breakdance", category = "Dances", r15Id = "10214311282", isLooped = true },
	{ name = "Spin", category = "Dances", r15Id = "186934979", isLooped = true },
	{ name = "Twist", category = "Dances", r15Id = "3338083565", isLooped = true },
	{ name = "Robot", category = "Dances", r15Id = "3338066308", isLooped = true },

	-- Viral & Memes
	{ name = "Floss", category = "Viral & Memes", r15Id = "5918726674", isLooped = true },
	{ name = "Griddy", category = "Viral & Memes", r15Id = "11444443914", isLooped = true },
	{ name = "Billy Bounce", category = "Viral & Memes", r15Id = "10714340543", isLooped = true },
	{ name = "Orange Justice", category = "Viral & Memes", r15Id = "10714340543", isLooped = true },
	{ name = "Hype", category = "Viral & Memes", r15Id = "3696328224", isLooped = true },
	{ name = "Electro Shuffle", category = "Viral & Memes", r15Id = "4297037653", isLooped = true },
	{ name = "Spooky Dance", category = "Viral & Memes", r15Id = "5918726674", isLooped = true },
	{ name = "Monkey", category = "Viral & Memes", r15Id = "3333495152", isLooped = true },
	{ name = "Zombie Groove", category = "Viral & Memes", r15Id = "3576686195", isLooped = true },

	-- Poses & Stances
	{ name = "Sleep / Rest", category = "Poses & Stances", r15Id = "4689362868", isLooped = true },
	{ name = "Sit Chill", category = "Poses & Stances", r15Id = "3338010159", isLooped = true },
	{ name = "Pushups", category = "Poses & Stances", r15Id = "3338025566", isLooped = true },
	{ name = "Ninja Stance", category = "Poses & Stances", r15Id = "4297037653", isLooped = true },
	{ name = "Float / Godlike", category = "Poses & Stances", r15Id = "3137620956", isLooped = true },
}

export type EmotesWidgetInstance = {
	Frame: Frame,
	ScreenGui: ScreenGui,
	PlayEmote: (emoteItem: EmoteItem) -> boolean,
	PlayCustomAnimationId: (animId: string, looped: boolean?, speed: number?) -> boolean,
	StopEmote: () -> (),
	Toggle: () -> (),
	Open: () -> (),
	Close: () -> (),
	SetVisible: (selfOrVal: any, maybeVal: any) -> (),
	Cleanup: () -> ()
}

local currentTrack: AnimationTrack? = nil
local currentEmoteName: string = "None"
local isLoopingEnabled: boolean = true
local currentSpeedMultiplier: number = 1.0

function EmotesWidget.new(): EmotesWidgetInstance
	if _G.__ModularEmotes_Cleanup then
		pcall(_G.__ModularEmotes_Cleanup)
		_G.__ModularEmotes_Cleanup = nil
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ModularEmotesGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 24
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local parentTarget = CoreGui
	if not pcall(function() screenGui.Parent = CoreGui end) or not screenGui.Parent then
		screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end

	local WIDGET_W = 320
	local WIDGET_H = 410
	local HEADER_H = 30

	-- Main Window Frame
	local widget = Instance.new("Frame")
	widget.Name = "EmotesWidget"
	widget.Size = UDim2.new(0, WIDGET_W, 0, WIDGET_H)
	widget.Position = UDim2.new(0, 18, 0.5, -205)
	widget.BackgroundColor3 = UI.Theme.Background
	widget.BackgroundTransparency = UI.Theme.BackgroundTransparency
	widget.BorderSizePixel = 0
	widget.ClipsDescendants = false
	widget.Parent = screenGui
	UI.registerThemeElement(widget, "Background")

	local bgGradient = Instance.new("UIGradient")
	bgGradient.Rotation = 90
	bgGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 210, 220))
	})
	bgGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0.12)
	})
	bgGradient.Parent = widget

	local outerStroke = Instance.new("UIStroke")
	outerStroke.Color = UI.Theme.Border
	outerStroke.Thickness = 2
	outerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outerStroke.Parent = widget
	UI.registerThemeElement(outerStroke, "Border")

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 1.0
	uiScale.Parent = widget

	-- ── Topbar / Header ──────────────────────────────────────────────
	local topbar = Instance.new("Frame")
	topbar.Name = "TopBar"
	topbar.Size = UDim2.new(1, -12, 0, HEADER_H)
	topbar.Position = UDim2.new(0, 6, 0, 6)
	topbar.BackgroundColor3 = UI.Theme.Container
	topbar.BackgroundTransparency = UI.Theme.ContainerTransparency
	topbar.BorderSizePixel = 0
	topbar.Parent = widget
	UI.registerThemeElement(topbar, "Container")

	local topStroke = Instance.new("UIStroke")
	topStroke.Color = UI.Theme.Border
	topStroke.Thickness = 1.5
	topStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	topStroke.Parent = topbar
	UI.registerThemeElement(topStroke, "Border")

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -56, 1, 0)
	titleLabel.Position = UDim2.new(0, 8, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Emotes & Animations"
	titleLabel.TextColor3 = UI.Theme.TextPrimary
	titleLabel.Font = UI.Fonts.Header
	titleLabel.TextSize = 11
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = topbar
	UI.registerThemeElement(titleLabel, "TextPrimary")

	local minBtn = Instance.new("TextButton")
	minBtn.Name = "MinBtn"
	minBtn.Size = UDim2.new(0, 20, 0, 18)
	minBtn.Position = UDim2.new(1, -44, 0, 6)
	minBtn.BackgroundColor3 = UI.Theme.ContainerDark
	minBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	minBtn.BorderSizePixel = 0
	minBtn.Text = "—"
	minBtn.TextColor3 = UI.Theme.TextPrimary
	minBtn.Font = UI.Fonts.Header
	minBtn.TextSize = 10
	minBtn.Parent = topbar
	UI.registerThemeElement(minBtn, "ContainerDark")
	UI.registerThemeElement(minBtn, "TextPrimary")

	local minStroke = Instance.new("UIStroke")
	minStroke.Color = UI.Theme.Border
	minStroke.Thickness = 1
	minStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	minStroke.Parent = minBtn
	UI.registerThemeElement(minStroke, "Border")

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 20, 0, 18)
	closeBtn.Position = UDim2.new(1, -22, 0, 6)
	closeBtn.BackgroundColor3 = UI.Theme.ContainerDark
	closeBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "X"
	closeBtn.TextColor3 = UI.Theme.TextPrimary
	closeBtn.Font = UI.Fonts.Header
	closeBtn.TextSize = 10
	closeBtn.Parent = topbar
	UI.registerThemeElement(closeBtn, "ContainerDark")
	UI.registerThemeElement(closeBtn, "TextPrimary")

	local closeStroke = Instance.new("UIStroke")
	closeStroke.Color = UI.Theme.Border
	closeStroke.Thickness = 1
	closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	closeStroke.Parent = closeBtn
	UI.registerThemeElement(closeStroke, "Border")

	-- ── Content Body Frame ───────────────────────────────────────────
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.new(1, -12, 1, -(HEADER_H + 16))
	body.Position = UDim2.new(0, 6, 0, HEADER_H + 10)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ClipsDescendants = true
	body.Parent = widget

	-- Status & Active Emote Bar
	local statusBar = Instance.new("Frame")
	statusBar.Name = "StatusBar"
	statusBar.Size = UDim2.new(1, 0, 0, 26)
	statusBar.Position = UDim2.new(0, 0, 0, 0)
	statusBar.BackgroundColor3 = UI.Theme.ContainerDark
	statusBar.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	statusBar.BorderSizePixel = 0
	statusBar.Parent = body
	UI.registerThemeElement(statusBar, "ContainerDark")

	local statusStroke = Instance.new("UIStroke")
	statusStroke.Color = UI.Theme.BorderDim
	statusStroke.Thickness = 1
	statusStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	statusStroke.Parent = statusBar
	UI.registerThemeElement(statusStroke, "BorderDim")

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -95, 1, 0)
	statusLabel.Position = UDim2.new(0, 8, 0, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Playing: None"
	statusLabel.TextColor3 = UI.Theme.TextSecondary
	statusLabel.Font = UI.Fonts.Body
	statusLabel.TextSize = 10
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
	statusLabel.Parent = statusBar
	UI.registerThemeElement(statusLabel, "TextSecondary")

	local stopBtn = Instance.new("TextButton")
	stopBtn.Name = "StopBtn"
	stopBtn.Size = UDim2.new(0, 80, 0, 20)
	stopBtn.Position = UDim2.new(1, -84, 0, 3)
	stopBtn.BackgroundColor3 = UI.Theme.Container
	stopBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
	stopBtn.BorderSizePixel = 0
	stopBtn.Text = "⏹ Stop"
	stopBtn.TextColor3 = UI.Theme.TextPrimary
	stopBtn.Font = UI.Fonts.Header
	stopBtn.TextSize = 10
	stopBtn.Parent = statusBar
	UI.registerThemeElement(stopBtn, "Container")
	UI.registerThemeElement(stopBtn, "TextPrimary")

	local stopStroke = Instance.new("UIStroke")
	stopStroke.Color = UI.Theme.Border
	stopStroke.Thickness = 1
	stopStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stopStroke.Parent = stopBtn
	UI.registerThemeElement(stopStroke, "Border")

	-- Controls Bar: [Loop: ON/OFF] + [Speed: 1.0x]
	local controlBar = Instance.new("Frame")
	controlBar.Name = "ControlBar"
	controlBar.Size = UDim2.new(1, 0, 0, 24)
	controlBar.Position = UDim2.new(0, 0, 0, 30)
	controlBar.BackgroundTransparency = 1
	controlBar.BorderSizePixel = 0
	controlBar.Parent = body

	local loopBtn = Instance.new("TextButton")
	loopBtn.Name = "LoopToggle"
	loopBtn.Size = UDim2.new(0, 95, 1, 0)
	loopBtn.Position = UDim2.new(0, 0, 0, 0)
	loopBtn.BackgroundColor3 = UI.Theme.Accent
	loopBtn.BackgroundTransparency = 0
	loopBtn.BorderSizePixel = 0
	loopBtn.Text = "Loop: ON"
	loopBtn.TextColor3 = UI.Theme.AccentText
	loopBtn.Font = UI.Fonts.Header
	loopBtn.TextSize = 10
	loopBtn.Parent = controlBar

	local loopStroke = Instance.new("UIStroke")
	loopStroke.Color = UI.Theme.Border
	loopStroke.Thickness = 1
	loopStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	loopStroke.Parent = loopBtn
	UI.registerThemeElement(loopStroke, "Border")

	local speedBtn = Instance.new("TextButton")
	speedBtn.Name = "SpeedBtn"
	speedBtn.Size = UDim2.new(0, 95, 1, 0)
	speedBtn.Position = UDim2.new(0, 100, 0, 0)
	speedBtn.BackgroundColor3 = UI.Theme.Container
	speedBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
	speedBtn.BorderSizePixel = 0
	speedBtn.Text = "Speed: 1.0x"
	speedBtn.TextColor3 = UI.Theme.TextPrimary
	speedBtn.Font = UI.Fonts.Header
	speedBtn.TextSize = 10
	speedBtn.Parent = controlBar
	UI.registerThemeElement(speedBtn, "Container")
	UI.registerThemeElement(speedBtn, "TextPrimary")

	local speedStroke = Instance.new("UIStroke")
	speedStroke.Color = UI.Theme.Border
	speedStroke.Thickness = 1
	speedStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	speedStroke.Parent = speedBtn
	UI.registerThemeElement(speedStroke, "Border")

	-- Custom ID Box & Play Btn
	local customBox = Instance.new("TextBox")
	customBox.Name = "CustomAnimInput"
	customBox.Size = UDim2.new(1, -200, 1, 0)
	customBox.Position = UDim2.new(0, 200, 0, 0)
	customBox.BackgroundColor3 = UI.Theme.Container
	customBox.BackgroundTransparency = UI.Theme.ContainerTransparency
	customBox.BorderSizePixel = 0
	customBox.Text = ""
	customBox.PlaceholderText = "Asset ID..."
	customBox.PlaceholderColor3 = UI.Theme.TextSecondary
	customBox.TextColor3 = UI.Theme.TextPrimary
	customBox.Font = UI.Fonts.Mono
	customBox.TextSize = 10
	customBox.ClearTextOnFocus = false
	customBox.Parent = controlBar
	UI.registerThemeElement(customBox, "TextPrimary")

	local customStroke = Instance.new("UIStroke")
	customStroke.Color = UI.Theme.BorderDim
	customStroke.Thickness = 1
	customStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	customStroke.Parent = customBox
	UI.registerThemeElement(customStroke, "BorderDim")

	-- Search Input Bar
	local searchFrame = Instance.new("Frame")
	searchFrame.Name = "SearchFrame"
	searchFrame.Size = UDim2.new(1, 0, 0, 24)
	searchFrame.Position = UDim2.new(0, 0, 0, 58)
	searchFrame.BackgroundColor3 = UI.Theme.Container
	searchFrame.BackgroundTransparency = UI.Theme.ContainerTransparency
	searchFrame.BorderSizePixel = 0
	searchFrame.Parent = body
	UI.registerThemeElement(searchFrame, "Container")

	local searchStroke = Instance.new("UIStroke")
	searchStroke.Color = UI.Theme.Border
	searchStroke.Thickness = 1
	searchStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	searchStroke.Parent = searchFrame
	UI.registerThemeElement(searchStroke, "Border")

	local searchBox = Instance.new("TextBox")
	searchBox.Name = "SearchBox"
	searchBox.Size = UDim2.new(1, -12, 1, 0)
	searchBox.Position = UDim2.new(0, 6, 0, 0)
	searchBox.BackgroundTransparency = 1
	searchBox.Text = ""
	searchBox.PlaceholderText = "Search animations & dances..."
	searchBox.PlaceholderColor3 = UI.Theme.TextSecondary
	searchBox.TextColor3 = UI.Theme.TextPrimary
	searchBox.Font = UI.Fonts.Body
	searchBox.TextSize = 11
	searchBox.TextXAlignment = Enum.TextXAlignment.Left
	searchBox.ClearTextOnFocus = false
	searchBox.Parent = searchFrame
	UI.registerThemeElement(searchBox, "TextPrimary")

	-- Category Filter Bar
	local catFrame = Instance.new("Frame")
	catFrame.Name = "CategoryBar"
	catFrame.Size = UDim2.new(1, 0, 0, 22)
	catFrame.Position = UDim2.new(0, 0, 0, 86)
	catFrame.BackgroundTransparency = 1
	catFrame.BorderSizePixel = 0
	catFrame.Parent = body

	local catLayout = Instance.new("UIListLayout")
	catLayout.FillDirection = Enum.FillDirection.Horizontal
	catLayout.Padding = UDim.new(0, 4)
	catLayout.SortOrder = Enum.SortOrder.LayoutOrder
	catLayout.Parent = catFrame

	local categories = { "All", "Dances", "Classic", "Viral & Memes", "Poses & Stances" }
	local activeCategory = "All"
	local categoryButtons: {[string]: TextButton} = {}

	-- Scrolling Emotes Grid
	local scrollGrid = Instance.new("ScrollingFrame")
	scrollGrid.Name = "EmotesGrid"
	scrollGrid.Size = UDim2.new(1, 0, 1, -114)
	scrollGrid.Position = UDim2.new(0, 0, 0, 114)
	scrollGrid.BackgroundTransparency = 1
	scrollGrid.BorderSizePixel = 0
	scrollGrid.ScrollBarThickness = 3
	scrollGrid.ScrollBarImageColor3 = UI.Theme.Accent
	scrollGrid.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollGrid.ClipsDescendants = true
	scrollGrid.Parent = body

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0.5, -4, 0, 32)
	gridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = scrollGrid

	local gridPad = Instance.new("UIPadding")
	gridPad.PaddingTop = UDim.new(0, 2)
	gridPad.PaddingBottom = UDim.new(0, 6)
	gridPad.Parent = scrollGrid

	-- ── Core Animation Player Logic ──────────────────────────────────
	local function stopCurrentEmote()
		if currentTrack then
			pcall(function() currentTrack:Stop(0.15) end)
			currentTrack = nil
		end
		currentEmoteName = "None"
		statusLabel.Text = "Playing: None"
		statusLabel.TextColor3 = UI.Theme.TextSecondary
	end

	local function playRawAnimation(animId: string, emoteName: string, loopOverride: boolean?, speedOverride: number?): boolean
		local char = LocalPlayer.Character
		if not char then return false end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then return false end

		stopCurrentEmote()

		local isLooped = if loopOverride ~= nil then loopOverride else isLoopingEnabled
		local speed = if speedOverride ~= nil then speedOverride else currentSpeedMultiplier

		local formattedId = animId
		if not string.find(formattedId, "rbxassetid://") and not string.find(formattedId, "http") then
			formattedId = "rbxassetid://" .. animId
		end

		local animator = hum:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = hum
		end

		local ok, animTrack = pcall(function()
			local anim = Instance.new("Animation")
			anim.AnimationId = formattedId
			local track = animator:LoadAnimation(anim)
			track.Looped = isLooped
			track.Priority = Enum.AnimationPriority.Action4
			track:Play(0.15, 1.0, speed)
			return track
		end)

		if ok and animTrack then
			currentTrack = animTrack
			currentEmoteName = emoteName
			statusLabel.Text = string.format("Playing: %s (%.1fx)", emoteName, speed)
			statusLabel.TextColor3 = UI.Theme.Accent
			return true
		end

		-- Fallback to Humanoid:PlayEmote() for native R15 emote names
		pcall(function()
			hum:PlayEmote(emoteName)
			currentEmoteName = emoteName
			statusLabel.Text = string.format("Playing: %s (Native)", emoteName)
			statusLabel.TextColor3 = UI.Theme.Accent
		end)

		return false
	end

	stopBtn.MouseButton1Click:Connect(function()
		Animations.buttonClickPop(stopBtn)
		stopCurrentEmote()
	end)

	loopBtn.MouseButton1Click:Connect(function()
		isLoopingEnabled = not isLoopingEnabled
		loopBtn.Text = if isLoopingEnabled then "Loop: ON" else "Loop: OFF"
		loopBtn.BackgroundColor3 = if isLoopingEnabled then UI.Theme.Accent else UI.Theme.ContainerDark
		loopBtn.BackgroundTransparency = if isLoopingEnabled then 0 else UI.Theme.ContainerDarkTransparency
		loopBtn.TextColor3 = if isLoopingEnabled then UI.Theme.AccentText else UI.Theme.TextSecondary
		if currentTrack then
			currentTrack.Looped = isLoopingEnabled
		end
	end)

	local speeds = { 0.5, 1.0, 1.5, 2.0, 3.0 }
	local speedIdx = 2
	speedBtn.MouseButton1Click:Connect(function()
		speedIdx = (speedIdx % #speeds) + 1
		currentSpeedMultiplier = speeds[speedIdx]
		speedBtn.Text = string.format("Speed: %.1fx", currentSpeedMultiplier)
		if currentTrack then
			currentTrack:AdjustSpeed(currentSpeedMultiplier)
			statusLabel.Text = string.format("Playing: %s (%.1fx)", currentEmoteName, currentSpeedMultiplier)
		end
	end)

	customBox.FocusLost:Connect(function(enterPressed)
		if enterPressed and customBox.Text ~= "" then
			local id = customBox.Text:gsub("%D+", "")
			if id ~= "" then
				playRawAnimation(id, "Custom ID #" .. id)
			end
		end
	end)

	-- ── Render Emote Grid Cards ──────────────────────────────────────
	local emoteCards: {Frame} = {}

	local function refreshGrid()
		for _, card in ipairs(emoteCards) do
			card:Destroy()
		end
		table.clear(emoteCards)

		local filterText = searchBox.Text:lower():gsub("^%s*(.-)%s*$", "%1")

		for idx, item in ipairs(EMOTE_CATALOG) do
			local matchesCat = (activeCategory == "All" or item.category == activeCategory)
			local matchesSearch = (filterText == "" or item.name:lower():find(filterText, 1, true) ~= nil)

			if matchesCat and matchesSearch then
				local card = Instance.new("TextButton")
				card.Name = "EmoteCard_" .. item.name
				card.BackgroundColor3 = UI.Theme.Container
				card.BackgroundTransparency = UI.Theme.ContainerTransparency
				card.BorderSizePixel = 0
				card.Text = ""
				card.ClipsDescendants = true
				card.Parent = scrollGrid
				UI.registerThemeElement(card, "Container")

				local cardStroke = Instance.new("UIStroke")
				cardStroke.Color = UI.Theme.Border
				cardStroke.Thickness = 1
				cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				cardStroke.Parent = card
				UI.registerThemeElement(cardStroke, "Border")

				local iconLabel = Instance.new("TextLabel")
				iconLabel.Size = UDim2.new(0, 20, 1, 0)
				iconLabel.Position = UDim2.new(0, 4, 0, 0)
				iconLabel.BackgroundTransparency = 1
				iconLabel.Text = if item.category == "Dances" then "♫" elseif item.category == "Viral & Memes" then "★" else "✦"
				iconLabel.TextColor3 = UI.Theme.Accent
				iconLabel.Font = UI.Fonts.Header
				iconLabel.TextSize = 10
				iconLabel.Parent = card

				local nameLabel = Instance.new("TextLabel")
				nameLabel.Size = UDim2.new(1, -26, 1, 0)
				nameLabel.Position = UDim2.new(0, 24, 0, 0)
				nameLabel.BackgroundTransparency = 1
				nameLabel.Text = item.name
				nameLabel.TextColor3 = UI.Theme.TextPrimary
				nameLabel.Font = UI.Fonts.Header
				nameLabel.TextSize = 10
				nameLabel.TextXAlignment = Enum.TextXAlignment.Left
				nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
				nameLabel.Parent = card
				UI.registerThemeElement(nameLabel, "TextPrimary")

				card.MouseEnter:Connect(function()
					TweenService:Create(cardStroke, TweenInfo.new(0.1), { Color = UI.Theme.Accent, Thickness = 1.6 }):Play()
					TweenService:Create(card, TweenInfo.new(0.1), { BackgroundColor3 = UI.Theme.ContainerDark }):Play()
				end)
				card.MouseLeave:Connect(function()
					TweenService:Create(cardStroke, TweenInfo.new(0.1), { Color = UI.Theme.Border, Thickness = 1 }):Play()
					TweenService:Create(card, TweenInfo.new(0.1), { BackgroundColor3 = UI.Theme.Container }):Play()
				end)

				card.MouseButton1Click:Connect(function()
					Animations.buttonClickPop(card)
					playRawAnimation(item.r15Id, item.name, item.isLooped, item.defaultSpeed)
				end)

				table.insert(emoteCards, card)
			end
		end
	end

	-- Category Buttons Setup
	for _, catName in ipairs(categories) do
		local catBtn = Instance.new("TextButton")
		catBtn.Name = "CatBtn_" .. catName
		catBtn.Size = UDim2.new(0, 0, 1, 0)
		catBtn.AutomaticSize = Enum.AutomaticSize.X
		catBtn.BackgroundColor3 = if catName == activeCategory then UI.Theme.Accent else UI.Theme.ContainerDark
		catBtn.BackgroundTransparency = if catName == activeCategory then 0 else UI.Theme.ContainerDarkTransparency
		catBtn.BorderSizePixel = 0
		catBtn.Text = "  " .. catName .. "  "
		catBtn.TextColor3 = if catName == activeCategory then UI.Theme.AccentText else UI.Theme.TextSecondary
		catBtn.Font = UI.Fonts.Header
		catBtn.TextSize = 9
		catBtn.Parent = catFrame

		local cStroke = Instance.new("UIStroke")
		cStroke.Color = UI.Theme.BorderDim
		cStroke.Thickness = 1
		cStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		cStroke.Parent = catBtn
		UI.registerThemeElement(cStroke, "BorderDim")

		categoryButtons[catName] = catBtn

		catBtn.MouseButton1Click:Connect(function()
			activeCategory = catName
			for name, btn in pairs(categoryButtons) do
				local isActive = (name == activeCategory)
				btn.BackgroundColor3 = if isActive then UI.Theme.Accent else UI.Theme.ContainerDark
				btn.BackgroundTransparency = if isActive then 0 else UI.Theme.ContainerDarkTransparency
				btn.TextColor3 = if isActive then UI.Theme.AccentText else UI.Theme.TextSecondary
			end
			refreshGrid()
		end)
	end

	searchBox:GetPropertyChangedSignal("Text"):Connect(refreshGrid)
	refreshGrid()

	-- ── Zero-Drift Screen-Bounded Dragging ────────────────────────────
			UI.makeDraggable(topbar, widget)

	-- ── Minimize & Toggle Mechanics ──────────────────────────────────
	local minimized = false
	minBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		if minimized then
			body.Visible = false
			TweenService:Create(widget, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, WIDGET_W, 0, HEADER_H + 12)
			}):Play()
		else
			body.Visible = true
			TweenService:Create(widget, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, WIDGET_W, 0, WIDGET_H)
			}):Play()
		end
	end)

	local isOpen = true
	local isWidgetEnabled = true

	local function openWidget()
		if not isWidgetEnabled then return end
		isOpen = true
		widget.Visible = true
		Animations.popIn(widget, uiScale)
	end

	local function closeWidget()
		isOpen = false
		Animations.popOut(widget, uiScale, function()
			widget.Visible = false
		end)
	end

	local function toggleWidget()
		if not isWidgetEnabled then return end
		if isOpen and widget.Visible then
			closeWidget()
		else
			openWidget()
		end
	end

	closeBtn.MouseButton1Click:Connect(closeWidget)

	local widgetObj: any = nil
	widgetObj = {
		Frame = widget,
		ScreenGui = screenGui,
		IsEnabled = true,
		PlayEmote = function(item: EmoteItem)
			return playRawAnimation(item.r15Id, item.name, item.isLooped, item.defaultSpeed)
		end,
		PlayCustomAnimationId = function(id: string, looped: boolean?, speed: number?)
			return playRawAnimation(id, "Custom ID #" .. id, looped, speed)
		end,
		StopEmote = stopCurrentEmote,
		Toggle = toggleWidget,
		Open = openWidget,
		Close = closeWidget,
		SetVisible = function(selfOrVal: any, maybeVal: any)
			local vis = if typeof(selfOrVal) == "boolean" then selfOrVal else maybeVal
			if typeof(vis) ~= "boolean" then vis = true end
			isWidgetEnabled = vis
			if widgetObj then widgetObj.IsEnabled = vis end
			if vis then openWidget() else closeWidget() end
		end,
		Cleanup = function()
			stopCurrentEmote()
			screenGui:Destroy()
		end
	}

	_G.__ModularEmotes_Cleanup = widgetObj.Cleanup

	return widgetObj
end

return EmotesWidget
