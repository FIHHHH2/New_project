--!strict
--[=[
    ✦ Squared Retro Player List (Tab HUD) with Live Leaderstats Columns & Auto-Positioned Context Menu ✦
    Features:
    - Dedicated live leaderstats columns aligned dynamically in the Tab list
    - Dynamic column detection (leaderstats, Data, Stats, Currencies, PlayerData, Attributes)
    - Auto-scaling widget width based on active leaderstat column count (260px up to 520px)
    - Live-updating column cells with zero-lag .Changed and attribute listeners
    - Dynamic leaderboard ranking & sorting by primary leaderstat (highest value first)
    - Interactive player rows with hover FX, domino entry animations, and click-to-open context menu
    - Smart auto-positioning popup (anchors dynamically to the left or right of clicked row, clamped to viewport)
    - Full Roblox player actions: Profile view, Add/Unfriend, Block, Report/Inspect, Teleport, Fling, Spectate, Copy ID
    - Extended leaderstats inspector in context menu with click-to-copy
    - Domino sliding animations and auto-scaling list height
]=]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local UI = require("UI/UI.luau")
local Animations = require("UI/Animations.luau")

local PlayerList = {}
PlayerList.__index = PlayerList

export type PlayerListWidget = {
	Frame: Frame,
	Container: ScrollingFrame,
	UiScale: UIScale,
	IsMinimized: boolean,
	Visible: boolean,
	IsEnabled: boolean?,
	IsOpen: () -> boolean,
	Open: (selfOrOnComplete: any, maybeOnComplete: any) -> (),
	Close: (selfOrOnComplete: any, maybeOnComplete: any) -> (),
	Toggle: (selfOrOnComplete: any, maybeOnComplete: any) -> (),
	SetVisible: (selfOrVal: any, maybeVal: any) -> (),
	Destroy: () -> (),
	Cleanup: () -> (),
	OnClose: (() -> ())?,
	OnOpen: (() -> ())?,
	OnMinimize: ((isMin: boolean) -> ())?
}

local ROW_H = 36
local ROW_GAP = 3
local HEADER_H = 28
local STAT_HEADER_H = 20
local BASE_W = 260
local STAT_COL_W = 60
local MAX_STAT_COLS = 4
local POPUP_W = 260
local POPUP_H = 345

local function formatStatVal(val: any): string
	if typeof(val) == "number" then
		local absVal = math.abs(val)
		if absVal >= 1_000_000_000_000 then
			return string.format("%.1fT", val / 1_000_000_000_000)
		elseif absVal >= 1_000_000_000 then
			return string.format("%.1fB", val / 1_000_000_000)
		elseif absVal >= 1_000_000 then
			return string.format("%.1fM", val / 1_000_000)
		elseif absVal >= 1_000 then
			return string.format("%.1fK", val / 1_000)
		else
			return tostring(val)
		end
	end
	return tostring(val or "-")
end

function PlayerList.new(): PlayerListWidget
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ModularPlayerListGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 600
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function() screenGui.Parent = CoreGui end)
	if not screenGui.Parent then
		screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end

	local activeConnections: {RBXScriptConnection} = {}
	local playerConnections: {[Player]: {RBXScriptConnection}} = {}
	local activeStatColumns: {string} = {}
	local rowRefreshCallbacks: {[Player]: () -> ()} = {}
	local rowObjects: {[Player]: TextButton} = {}

	-- ── Main Widget Frame ─────────────────────────────────────────────
	local currentWidth = BASE_W
	local widget = Instance.new("Frame")
	widget.Name = "PlayerListWidget"
	widget.Size = UDim2.new(0, BASE_W, 0, HEADER_H + 40)
	widget.Position = UDim2.new(1, -(BASE_W + 10), 0, 10)
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
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 210))
	})
	bgGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0.15)
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

	-- ── Topbar (Drag Handle) ──────────────────────────────────────────
	local topbar = Instance.new("Frame")
	topbar.Name = "TopBar"
	topbar.Size = UDim2.new(1, -12, 0, HEADER_H)
	topbar.Position = UDim2.new(0, 6, 0, 6)
	topbar.BackgroundColor3 = UI.Theme.Container
	topbar.BackgroundTransparency = UI.Theme.ContainerTransparency
	topbar.BorderSizePixel = 0
	topbar.Parent = widget
	UI.registerThemeElement(topbar, "Container")

	local topGradient = Instance.new("UIGradient")
	topGradient.Rotation = 45
	topGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 220, 230))
	})
	topGradient.Parent = topbar

	local topStroke = Instance.new("UIStroke")
	topStroke.Color = UI.Theme.Border
	topStroke.Thickness = 1.5
	topStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	topStroke.Parent = topbar
	UI.registerThemeElement(topStroke, "Border")

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, -56, 1, 0)
	titleLabel.Position = UDim2.new(0, 8, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = string.format("Players (%d)", #Players:GetPlayers())
	titleLabel.TextColor3 = UI.Theme.TextPrimary
	titleLabel.Font = UI.Fonts.Header
	titleLabel.TextSize = 11
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = topbar
	UI.registerThemeElement(titleLabel, "TextPrimary")

	local minBtn = Instance.new("TextButton")
	minBtn.Name = "MinBtn"
	minBtn.Size = UDim2.new(0, 20, 0, 18)
	minBtn.Position = UDim2.new(1, -44, 0, 5)
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
	closeBtn.Position = UDim2.new(1, -22, 0, 5)
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

	-- ── Column Headers Bar (for Leaderstats) ───────────────────────────
	local statHeaderBar = Instance.new("Frame")
	statHeaderBar.Name = "StatHeaderBar"
	statHeaderBar.Size = UDim2.new(1, -12, 0, STAT_HEADER_H)
	statHeaderBar.Position = UDim2.new(0, 6, 0, HEADER_H + 8)
	statHeaderBar.BackgroundColor3 = UI.Theme.ContainerDark
	statHeaderBar.BackgroundTransparency = 0.5
	statHeaderBar.BorderSizePixel = 0
	statHeaderBar.Visible = false
	statHeaderBar.Parent = widget
	UI.registerThemeElement(statHeaderBar, "ContainerDark")

	local statHeaderStroke = Instance.new("UIStroke")
	statHeaderStroke.Color = UI.Theme.BorderDim
	statHeaderStroke.Thickness = 1
	statHeaderStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	statHeaderStroke.Parent = statHeaderBar
	UI.registerThemeElement(statHeaderStroke, "BorderDim")

	local playerHeaderLabel = Instance.new("TextLabel")
	playerHeaderLabel.Name = "PlayerHeaderLabel"
	playerHeaderLabel.Size = UDim2.new(1, 0, 1, 0)
	playerHeaderLabel.Position = UDim2.new(0, 8, 0, 0)
	playerHeaderLabel.BackgroundTransparency = 1
	playerHeaderLabel.Text = "PLAYER"
	playerHeaderLabel.TextColor3 = UI.Theme.TextSecondary
	playerHeaderLabel.Font = UI.Fonts.Header
	playerHeaderLabel.TextSize = 9
	playerHeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
	playerHeaderLabel.Parent = statHeaderBar
	UI.registerThemeElement(playerHeaderLabel, "TextSecondary")

	local colLabelsContainer = Instance.new("Frame")
	colLabelsContainer.Name = "ColLabelsContainer"
	colLabelsContainer.Size = UDim2.new(0, 0, 1, 0)
	colLabelsContainer.Position = UDim2.new(1, 0, 0, 0)
	colLabelsContainer.AnchorPoint = Vector2.new(1, 0)
	colLabelsContainer.BackgroundTransparency = 1
	colLabelsContainer.Parent = statHeaderBar

	-- ── Scrolling Player Container ────────────────────────────────────
	local container = Instance.new("ScrollingFrame")
	container.Name = "PlayerListContainer"
	container.Size = UDim2.new(1, -12, 1, -(HEADER_H + 12))
	container.Position = UDim2.new(0, 6, 0, HEADER_H + 8)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.ScrollBarThickness = 3
	container.ScrollBarImageColor3 = UI.Theme.Accent
	container.CanvasSize = UDim2.new(0, 0, 0, 0)
	container.AutomaticCanvasSize = Enum.AutomaticSize.Y
	container.ClipsDescendants = true
	container.Parent = widget

	local listPad = Instance.new("UIPadding")
	listPad.PaddingLeft = UDim.new(0, 2)
	listPad.PaddingRight = UDim.new(0, 2)
	listPad.PaddingTop = UDim.new(0, 2)
	listPad.PaddingBottom = UDim.new(0, 2)
	listPad.Parent = container

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, ROW_GAP)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = container

	-- ── Smooth Height & Width Scaling ─────────────────────────────────
	local minimized = false

	local function updateWidgetLayout()
		if minimized then return end
		local hasCols = #activeStatColumns > 0
		statHeaderBar.Visible = hasCols

		local headerOffset = HEADER_H + (if hasCols then STAT_HEADER_H + 4 else 0)
		container.Position = UDim2.new(0, 6, 0, headerOffset + 8)
		container.Size = UDim2.new(1, -12, 1, -(headerOffset + 12))

		local count = #Players:GetPlayers()
		local fullNeededHeight = headerOffset + count * (ROW_H + ROW_GAP) + 16
		local vpH = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 720
		local posY = math.max(0, widget.AbsolutePosition.Y)
		local maxAvailableH = math.max(HEADER_H + 40, vpH - posY - 16)
		local targetH = math.min(fullNeededHeight, maxAvailableH)

		local targetW = math.clamp(BASE_W + (#activeStatColumns * STAT_COL_W), BASE_W, 520)
		currentWidth = targetW

		TweenService:Create(widget, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, targetW, 0, targetH)
		}):Play()
	end

	-- ── Standard Topbar Drag ──────────────────────────────────────────
	UI.makeDraggable(topbar, widget)

	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateWidgetLayout)
	end

	-- ── Button Hover & Click FX ───────────────────────────────────────
	local function attachBtnFX(btn: TextButton, isClose: boolean?)
		local stroke = btn:FindFirstChildWhichIsA("UIStroke")
		btn.MouseEnter:Connect(function()
			if stroke then TweenService:Create(stroke, TweenInfo.new(0.12), { Thickness = 1.8 }):Play() end
			local hoverCol = if isClose then Color3.fromRGB(220, 60, 60) else UI.Theme.Accent
			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = hoverCol, TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
		end)
		btn.MouseLeave:Connect(function()
			if stroke then TweenService:Create(stroke, TweenInfo.new(0.12), { Thickness = 1 }):Play() end
			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.ContainerDark, TextColor3 = UI.Theme.TextPrimary }):Play()
		end)
		btn.MouseButton1Down:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.08), { Size = UDim2.new(0, 18, 0, 16) }):Play()
		end)
		btn.MouseButton1Up:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Size = UDim2.new(0, 20, 0, 18) }):Play()
		end)
	end

	attachBtnFX(minBtn, false)
	attachBtnFX(closeBtn, true)

	-- ── Minimize / Close ─────────────────────────────────────────────
	local isOpen = true
	local isTransitioning = false
	local isPopupOpen = false
	local isWidgetEnabled = true
	local closeContextMenu: () -> ()

	local widgetObj: any = nil

	local function openWidget(selfOrOnComplete: any, maybeOnComplete: any)
		local onComplete = if type(selfOrOnComplete) == "function" then selfOrOnComplete elseif type(maybeOnComplete) == "function" then maybeOnComplete else nil
		if isOpen or isTransitioning then return end
		isTransitioning = true
		Animations.openWindow(widget, uiScale, function()
			isOpen = true
			isTransitioning = false
			if widgetObj and widgetObj.OnOpen then
				pcall(widgetObj.OnOpen)
			end
			if onComplete then onComplete() end
		end)
	end

	local function closeWidget(selfOrOnComplete: any, maybeOnComplete: any)
		local onComplete = if type(selfOrOnComplete) == "function" then selfOrOnComplete elseif type(maybeOnComplete) == "function" then maybeOnComplete else nil
		if not isOpen or isTransitioning then return end
		isTransitioning = true
		if closeContextMenu then closeContextMenu() end
		Animations.closeWindow(widget, uiScale, function()
			isOpen = false
			isTransitioning = false
			if widgetObj and widgetObj.OnClose then
				pcall(widgetObj.OnClose)
			end
			if onComplete then onComplete() end
		end)
	end

	local function toggleWidget(selfOrOnComplete: any, maybeOnComplete: any)
		if not isWidgetEnabled then return end
		local onComplete = if type(selfOrOnComplete) == "function" then selfOrOnComplete elseif type(maybeOnComplete) == "function" then maybeOnComplete else nil
		if isOpen then
			closeWidget(onComplete)
		else
			openWidget(onComplete)
		end
	end

	local function setWidgetVisible(selfOrVal: any, maybeVal: any)
		local v = if type(selfOrVal) == "boolean" then selfOrVal elseif type(maybeVal) == "boolean" then maybeVal else true
		isWidgetEnabled = v
		if widgetObj then widgetObj.IsEnabled = v end
		if v then
			openWidget()
		else
			closeWidget()
		end
	end

	minBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		if closeContextMenu then closeContextMenu() end
		if minimized then
			container.Visible = false
			statHeaderBar.Visible = false
			TweenService:Create(widget, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, widget.AbsoluteSize.X, 0, HEADER_H)
			}):Play()
		else
			container.Visible = true
			updateWidgetLayout()
		end
		if widgetObj and widgetObj.OnMinimize then
			pcall(function() widgetObj.OnMinimize(minimized) end)
		end
	end)

	closeBtn.MouseButton1Click:Connect(function()
		closeWidget()
	end)

	-- ── Floating Player Extended Profile & Leaderstats Popup ─────────
	local popupFrame = Instance.new("Frame")
	popupFrame.Name = "PlayerContextMenu"
	popupFrame.Size = UDim2.new(0, POPUP_W, 0, POPUP_H)
	popupFrame.BackgroundColor3 = UI.Theme.Background
	popupFrame.BackgroundTransparency = UI.Theme.BackgroundTransparency
	popupFrame.BorderSizePixel = 0
	popupFrame.Visible = false
	popupFrame.ZIndex = 100
	popupFrame.Parent = screenGui
	UI.registerThemeElement(popupFrame, "Background")

	local popupBgGrad = Instance.new("UIGradient")
	popupBgGrad.Rotation = 90
	popupBgGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 210))
	})
	popupBgGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0.15)
	})
	popupBgGrad.Parent = popupFrame

	local popupStroke = Instance.new("UIStroke")
	popupStroke.Color = UI.Theme.Border
	popupStroke.Thickness = 2
	popupStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	popupStroke.Parent = popupFrame
	UI.registerThemeElement(popupStroke, "Border")

	local popupScale = Instance.new("UIScale")
	popupScale.Scale = 1.0
	popupScale.Parent = popupFrame

	-- 1. Popup Header with Avatar & Details
	local pHeader = Instance.new("Frame")
	pHeader.Name = "PopupHeader"
	pHeader.Size = UDim2.new(1, 0, 0, 50)
	pHeader.BackgroundColor3 = UI.Theme.Container
	pHeader.BackgroundTransparency = UI.Theme.ContainerTransparency
	pHeader.BorderSizePixel = 0
	pHeader.Parent = popupFrame
	UI.registerThemeElement(pHeader, "Container")

	local pHeaderStroke = Instance.new("UIStroke")
	pHeaderStroke.Color = UI.Theme.Border
	pHeaderStroke.Thickness = 1
	pHeaderStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	pHeaderStroke.Parent = pHeader
	UI.registerThemeElement(pHeaderStroke, "Border")

	local pAvatarBox = Instance.new("Frame")
	pAvatarBox.Size = UDim2.new(0, 40, 0, 40)
	pAvatarBox.Position = UDim2.new(0, 5, 0, 5)
	pAvatarBox.BackgroundColor3 = UI.Theme.ContainerDark
	pAvatarBox.BorderSizePixel = 0
	pAvatarBox.Parent = pHeader
	UI.registerThemeElement(pAvatarBox, "ContainerDark")

	local pAvatarImg = Instance.new("ImageLabel")
	pAvatarImg.Size = UDim2.new(1, 0, 1, 0)
	pAvatarImg.BackgroundTransparency = 1
	pAvatarImg.Parent = pAvatarBox

	local pNameLabel = Instance.new("TextLabel")
	pNameLabel.Size = UDim2.new(1, -74, 0, 16)
	pNameLabel.Position = UDim2.new(0, 50, 0, 6)
	pNameLabel.BackgroundTransparency = 1
	pNameLabel.Text = "DisplayName"
	pNameLabel.TextColor3 = UI.Theme.TextPrimary
	pNameLabel.Font = UI.Fonts.Header
	pNameLabel.TextSize = 11
	pNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	pNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	pNameLabel.Parent = pHeader
	UI.registerThemeElement(pNameLabel, "TextPrimary")

	local pSubLabel = Instance.new("TextLabel")
	pSubLabel.Size = UDim2.new(1, -74, 0, 14)
	pSubLabel.Position = UDim2.new(0, 50, 0, 24)
	pSubLabel.BackgroundTransparency = 1
	pSubLabel.Text = "@Username | 0d"
	pSubLabel.TextColor3 = UI.Theme.TextSecondary
	pSubLabel.Font = UI.Fonts.Mono
	pSubLabel.TextSize = 9
	pSubLabel.TextXAlignment = Enum.TextXAlignment.Left
	pSubLabel.TextTruncate = Enum.TextTruncate.AtEnd
	pSubLabel.Parent = pHeader
	UI.registerThemeElement(pSubLabel, "TextSecondary")

	local pCloseBtn = Instance.new("TextButton")
	pCloseBtn.Size = UDim2.new(0, 16, 0, 16)
	pCloseBtn.Position = UDim2.new(1, -20, 0, 6)
	pCloseBtn.BackgroundColor3 = UI.Theme.ContainerDark
	pCloseBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	pCloseBtn.BorderSizePixel = 0
	pCloseBtn.Text = "X"
	pCloseBtn.TextColor3 = UI.Theme.TextPrimary
	pCloseBtn.Font = UI.Fonts.Header
	pCloseBtn.TextSize = 9
	pCloseBtn.Parent = pHeader
	UI.registerThemeElement(pCloseBtn, "ContainerDark")
	UI.registerThemeElement(pCloseBtn, "TextPrimary")
	pCloseBtn.MouseButton1Click:Connect(function()
		if closeContextMenu then closeContextMenu() end
	end)

	-- 2. Live Leaderstats & Currencies Section
	local statsHeader = Instance.new("TextLabel")
	statsHeader.Size = UDim2.new(1, -12, 0, 16)
	statsHeader.Position = UDim2.new(0, 6, 0, 54)
	statsHeader.BackgroundTransparency = 1
	statsHeader.Text = "LIVE LEADERSTATS & VALUES"
	statsHeader.TextColor3 = UI.Theme.TextSecondary
	statsHeader.Font = UI.Fonts.Header
	statsHeader.TextSize = 9
	statsHeader.TextXAlignment = Enum.TextXAlignment.Left
	statsHeader.Parent = popupFrame
	UI.registerThemeElement(statsHeader, "TextSecondary")

	local statsContainer = Instance.new("ScrollingFrame")
	statsContainer.Name = "StatsContainer"
	statsContainer.Size = UDim2.new(1, -12, 0, 105)
	statsContainer.Position = UDim2.new(0, 6, 0, 72)
	statsContainer.BackgroundColor3 = UI.Theme.ContainerDark
	statsContainer.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	statsContainer.BorderSizePixel = 0
	statsContainer.ScrollBarThickness = 2
	statsContainer.ScrollBarImageColor3 = UI.Theme.Accent
	statsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	statsContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
	statsContainer.Parent = popupFrame
	UI.registerThemeElement(statsContainer, "ContainerDark")

	local statsStroke = Instance.new("UIStroke")
	statsStroke.Color = UI.Theme.BorderDim
	statsStroke.Thickness = 0.8
	statsStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	statsStroke.Parent = statsContainer
	UI.registerThemeElement(statsStroke, "BorderDim")

	local statsList = Instance.new("UIListLayout")
	statsList.Padding = UDim.new(0, 2)
	statsList.SortOrder = Enum.SortOrder.LayoutOrder
	statsList.Parent = statsContainer

	-- 3. Action Buttons Section
	local actionsHeader = Instance.new("TextLabel")
	actionsHeader.Size = UDim2.new(1, -12, 0, 16)
	actionsHeader.Position = UDim2.new(0, 6, 0, 182)
	actionsHeader.BackgroundTransparency = 1
	actionsHeader.Text = "PLAYER ACTIONS"
	actionsHeader.TextColor3 = UI.Theme.TextSecondary
	actionsHeader.Font = UI.Fonts.Header
	actionsHeader.TextSize = 9
	actionsHeader.TextXAlignment = Enum.TextXAlignment.Left
	actionsHeader.Parent = popupFrame
	UI.registerThemeElement(actionsHeader, "TextSecondary")

	local pBtnContainer = Instance.new("Frame")
	pBtnContainer.Size = UDim2.new(1, -12, 0, 138)
	pBtnContainer.Position = UDim2.new(0, 6, 0, 200)
	pBtnContainer.BackgroundTransparency = 1
	pBtnContainer.Parent = popupFrame

	local pGridLayout = Instance.new("UIGridLayout")
	pGridLayout.CellSize = UDim2.new(0.5, -3, 0, 24)
	pGridLayout.CellPadding = UDim2.new(0, 6, 0, 4)
	pGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pGridLayout.Parent = pBtnContainer

	local currentTargetPlayer: Player? = nil
	local isSpying = false
	local activeStatConns: {RBXScriptConnection} = {}

	local function clearStatConns()
		for _, conn in ipairs(activeStatConns) do
			pcall(function() conn:Disconnect() end)
		end
		table.clear(activeStatConns)
	end

	local function makeActionBtn(text: string, order: number, onClick: () -> ()): TextButton
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 1, 0)
		btn.BackgroundColor3 = UI.Theme.Container
		btn.BackgroundTransparency = UI.Theme.ContainerTransparency
		btn.BorderSizePixel = 0
		btn.Text = text
		btn.TextColor3 = UI.Theme.TextPrimary
		btn.Font = UI.Fonts.Header
		btn.TextSize = 9
		btn.LayoutOrder = order
		btn.Parent = pBtnContainer
		UI.registerThemeElement(btn, "Container")
		UI.registerThemeElement(btn, "TextPrimary")

		local bStroke = Instance.new("UIStroke")
		bStroke.Color = UI.Theme.Border
		bStroke.Thickness = 1
		bStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		bStroke.Parent = btn
		UI.registerThemeElement(bStroke, "Border")

		btn.MouseEnter:Connect(function()
			TweenService:Create(bStroke, TweenInfo.new(0.12), { Thickness = 1.4, Color = UI.Theme.Accent }):Play()
			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.ContainerDark, TextColor3 = UI.Theme.Accent }):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(bStroke, TweenInfo.new(0.12), { Thickness = 1, Color = UI.Theme.Border }):Play()
			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.Container, TextColor3 = UI.Theme.TextPrimary }):Play()
		end)

		btn.MouseButton1Click:Connect(onClick)
		return btn
	end

	local friendBtn = makeActionBtn("Add Friend", 1, function()
		if currentTargetPlayer and currentTargetPlayer ~= Players.LocalPlayer then
			pcall(function()
				StarterGui:SetCore("PromptSendFriendRequest", currentTargetPlayer)
			end)
		end
	end)

	local tpBtn = makeActionBtn("Teleport", 2, function()
		if currentTargetPlayer and currentTargetPlayer.Character then
			local myChar = Players.LocalPlayer.Character
			local tChar = currentTargetPlayer.Character
			if myChar and tChar and myChar:FindFirstChild("HumanoidRootPart") and tChar:FindFirstChild("HumanoidRootPart") then
				local tHrp = tChar:FindFirstChild("HumanoidRootPart") :: BasePart
				local myHrp = myChar:FindFirstChild("HumanoidRootPart") :: BasePart
				myHrp.CFrame = tHrp.CFrame * CFrame.new(0, 0, 3)
			end
		end
	end)

	local spyBtn = makeActionBtn("Spectate", 3, function()
		local cam = workspace.CurrentCamera
		if not cam then return end
		isSpying = not isSpying
		spyBtn.Text = if isSpying then "Unspectate" else "Spectate"
		if isSpying and currentTargetPlayer and currentTargetPlayer.Character and currentTargetPlayer.Character:FindFirstChildOfClass("Humanoid") then
			cam.CameraSubject = currentTargetPlayer.Character:FindFirstChildOfClass("Humanoid")
		elseif Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
			cam.CameraSubject = Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		end
	end)

	local copyBtn = makeActionBtn("Copy ID", 4, function()
		if currentTargetPlayer then
			local clip = string.format("%s (@%s) [ID:%d]", currentTargetPlayer.DisplayName, currentTargetPlayer.Name, currentTargetPlayer.UserId)
			local setclip = setclipboard or (getgenv and getgenv().setclipboard) or toclipboard
			if type(setclip) == "function" then
				setclip(clip)
			end
		end
	end)

	local inspectBtn = makeActionBtn("Inspect", 5, function()
		if currentTargetPlayer then
			pcall(function()
				GuiService:InspectPlayerFromUserId(currentTargetPlayer.UserId)
			end)
		end
	end)

	local flingBtn = makeActionBtn("Fling", 6, function()
		if currentTargetPlayer and currentTargetPlayer.Character then
			local myChar = Players.LocalPlayer.Character
			local tChar = currentTargetPlayer.Character
			local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart") :: BasePart?
			local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart") :: BasePart?
			if myHrp and tHrp then
				local oldCF = myHrp.CFrame
				task.spawn(function()
					local tStart = tick()
					while tick() - tStart < 0.45 do
						if not (myHrp and tHrp and tHrp.Parent) then break end
						myHrp.CFrame = tHrp.CFrame
						myHrp.AssemblyAngularVelocity = Vector3.new(0, 10000000, 0)
						task.wait(0.016)
					end
					myHrp.AssemblyAngularVelocity = Vector3.zero
					myHrp.CFrame = oldCF
				end)
			end
		end
	end)

	closeContextMenu = function()
		if not isPopupOpen then return end
		isPopupOpen = false
		clearStatConns()
		Animations.popOut(popupFrame, popupScale)
	end

	UserInputService.InputBegan:Connect(function(input)
		if not isPopupOpen then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			task.defer(function()
				if not isPopupOpen then return end
				local mousePos = UserInputService:GetMouseLocation()
				local pPos = popupFrame.AbsolutePosition
				local pSize = popupFrame.AbsoluteSize
				if mousePos.X < pPos.X or mousePos.X > (pPos.X + pSize.X) or
				   mousePos.Y < pPos.Y or mousePos.Y > (pPos.Y + pSize.Y) then
					closeContextMenu()
				end
			end)
		end
	end)

	local function openContextMenuForPlayer(player: Player, rowAbsPos: Vector2)
		currentTargetPlayer = player
		pAvatarImg.Image = Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		pNameLabel.Text = player.DisplayName
		pSubLabel.Text = string.format("@%s | ID: %d | %dd", player.Name, player.UserId, player.AccountAge or 0)

		clearStatConns()
		for _, child in ipairs(statsContainer:GetChildren()) do
			if child:IsA("GuiObject") and child ~= statsList then
				child:Destroy()
			end
		end

		local statItems: {{Name: string, Value: any, Object: Instance?}} = {}
		local seenNames: {[string]: boolean} = {}

		local function addStat(name: string, val: any, obj: Instance?)
			if seenNames[name] then return end
			seenNames[name] = true
			table.insert(statItems, { Name = name, Value = val, Object = obj })
		end

		local statFolders = {
			player:FindFirstChild("leaderstats"),
			player:FindFirstChild("Data"),
			player:FindFirstChild("Stats"),
			player:FindFirstChild("Currencies"),
			player:FindFirstChild("Values"),
			player:FindFirstChild("PlayerData"),
			player:FindFirstChild("hiddenstats")
		}
		for _, folder in ipairs(statFolders) do
			if folder then
				for _, c in ipairs(folder:GetChildren()) do
					if c:IsA("ValueBase") then
						addStat(c.Name, (c :: any).Value, c)
					end
				end
			end
		end

		for attrName, attrVal in pairs(player:GetAttributes()) do
			if type(attrVal) == "number" or type(attrVal) == "string" or type(attrVal) == "boolean" then
				addStat(attrName, attrVal, nil)
			end
		end

		if #statItems > 0 then
			for _, item in ipairs(statItems) do
				local sRow = Instance.new("Frame")
				sRow.Name = "StatRow_" .. item.Name
				sRow.Size = UDim2.new(1, -4, 0, 20)
				sRow.BackgroundColor3 = UI.Theme.Container
				sRow.BackgroundTransparency = 0.55
				sRow.BorderSizePixel = 0
				sRow.Parent = statsContainer

				local nameLbl = Instance.new("TextLabel")
				nameLbl.Size = UDim2.new(0.55, -4, 1, 0)
				nameLbl.Position = UDim2.new(0, 4, 0, 0)
				nameLbl.BackgroundTransparency = 1
				nameLbl.Text = item.Name
				nameLbl.TextColor3 = UI.Theme.TextPrimary
				nameLbl.Font = UI.Fonts.Header
				nameLbl.TextSize = 10
				nameLbl.TextXAlignment = Enum.TextXAlignment.Left
				nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
				nameLbl.Parent = sRow
				UI.registerThemeElement(nameLbl, "TextPrimary")

				local valLbl = Instance.new("TextLabel")
				valLbl.Size = UDim2.new(0.45, -4, 1, 0)
				valLbl.Position = UDim2.new(0.55, 0, 0, 0)
				valLbl.BackgroundTransparency = 1
				valLbl.Text = formatStatVal(item.Value)
				valLbl.TextColor3 = UI.Theme.Accent
				valLbl.Font = UI.Fonts.Mono
				valLbl.TextSize = 10
				valLbl.TextXAlignment = Enum.TextXAlignment.Right
				valLbl.TextTruncate = Enum.TextTruncate.AtEnd
				valLbl.Parent = sRow
				UI.registerThemeElement(valLbl, "Accent")

				if item.Object and item.Object:IsA("ValueBase") then
					local conn = (item.Object :: any).Changed:Connect(function(newVal)
						valLbl.Text = formatStatVal(newVal)
					end)
					table.insert(activeStatConns, conn)
				end
			end
		else
			local emptyLbl = Instance.new("TextLabel")
			emptyLbl.Size = UDim2.new(1, 0, 0, 28)
			emptyLbl.BackgroundTransparency = 1
			emptyLbl.Text = "No active leaderstats recorded"
			emptyLbl.TextColor3 = UI.Theme.TextSecondary
			emptyLbl.Font = UI.Fonts.Body
			emptyLbl.TextSize = 10
			emptyLbl.TextXAlignment = Enum.TextXAlignment.Center
			emptyLbl.Parent = statsContainer
			UI.registerThemeElement(emptyLbl, "TextSecondary")
		end

		pcall(function()
			local isFriend = Players.LocalPlayer:IsFriendsWith(player.UserId)
			friendBtn.Text = if isFriend then "Unfriend" else "Add Friend"
		end)

		local vpSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		local wPos = widget.AbsolutePosition
		local wSize = widget.AbsoluteSize
		local margin = 8

		local spaceLeft = wPos.X - margin
		local spaceRight = vpSize.X - (wPos.X + wSize.X) - margin

		local posX = 0
		if spaceLeft >= POPUP_W then
			posX = wPos.X - POPUP_W - margin
		elseif spaceRight >= POPUP_W then
			posX = wPos.X + wSize.X + margin
		elseif spaceLeft >= spaceRight then
			posX = wPos.X - POPUP_W - margin
		else
			posX = wPos.X + wSize.X + margin
		end

		local posY = math.clamp(rowAbsPos.Y, margin, math.max(margin, vpSize.Y - POPUP_H - margin))
		posX = math.clamp(posX, margin, math.max(margin, vpSize.X - POPUP_W - margin))

		popupFrame.Position = UDim2.new(0, posX, 0, posY)
		isPopupOpen = true
		Animations.popIn(popupFrame, popupScale)
	end

	-- ── Universal Leaderstat Reader for Player ─────────────────────────
	local function getPlayerStatValue(player: Player, statName: string): (any, Instance?)
		local statFolders = {
			player:FindFirstChild("leaderstats"),
			player:FindFirstChild("Data"),
			player:FindFirstChild("Stats"),
			player:FindFirstChild("Currencies"),
			player:FindFirstChild("Values"),
			player:FindFirstChild("PlayerData")
		}
		for _, f in ipairs(statFolders) do
			if f then
				local c = f:FindFirstChild(statName)
				if c and c:IsA("ValueBase") then
					return (c :: any).Value, c
				end
			end
		end

		local attr = player:GetAttribute(statName)
		if attr ~= nil then
			return attr, nil
		end

		-- Also check case-insensitive match in leaderstats
		local ls = player:FindFirstChild("leaderstats")
		if ls then
			local lowerTarget = statName:lower()
			for _, c in ipairs(ls:GetChildren()) do
				if c:IsA("ValueBase") and c.Name:lower() == lowerTarget then
					return (c :: any).Value, c
				end
			end
		end

		return nil, nil
	end

	-- ── Rebuild Column Header Row ─────────────────────────────────────
	local function renderColumnHeaders()
		for _, child in ipairs(colLabelsContainer:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		local numCols = #activeStatColumns
		colLabelsContainer.Size = UDim2.new(0, numCols * STAT_COL_W, 1, 0)
		playerHeaderLabel.Size = UDim2.new(1, -(numCols * STAT_COL_W + 8), 1, 0)

		for i, colName in ipairs(activeStatColumns) do
			local lbl = Instance.new("TextLabel")
			lbl.Name = "ColHeader_" .. colName
			lbl.Size = UDim2.new(0, STAT_COL_W, 1, 0)
			lbl.Position = UDim2.new(0, (i - 1) * STAT_COL_W, 0, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = colName
			lbl.TextColor3 = UI.Theme.Accent
			lbl.Font = UI.Fonts.Header
			lbl.TextSize = 9
			lbl.TextXAlignment = Enum.TextXAlignment.Center
			lbl.TextTruncate = Enum.TextTruncate.AtEnd
			lbl.Parent = colLabelsContainer
			UI.registerThemeElement(lbl, "Accent")
		end

		updateWidgetLayout()
	end

	-- ── Global Leaderstats Columns Discovery ──────────────────────────
	local function discoverServerLeaderstats()
		local newFound = false
		local function inspectFolder(folder: Instance)
			for _, c in ipairs(folder:GetChildren()) do
				if c:IsA("ValueBase") and #activeStatColumns < MAX_STAT_COLS then
					if not table.find(activeStatColumns, c.Name) then
						table.insert(activeStatColumns, c.Name)
						newFound = true
					end
				end
			end
		end

		-- Prioritize LocalPlayer's leaderstats order
		local lp = Players.LocalPlayer
		if lp then
			local lpLs = lp:FindFirstChild("leaderstats")
			if lpLs then inspectFolder(lpLs) end
		end

		-- Check other players if more slots available
		for _, p in ipairs(Players:GetPlayers()) do
			if #activeStatColumns >= MAX_STAT_COLS then break end
			local ls = p:FindFirstChild("leaderstats")
			if ls then inspectFolder(ls) end
		end

		-- Fallback to Data/Stats/Currencies folders
		if #activeStatColumns == 0 then
			for _, p in ipairs(Players:GetPlayers()) do
				if #activeStatColumns >= MAX_STAT_COLS then break end
				for _, fName in ipairs({"Data", "Stats", "Currencies", "Values", "PlayerData"}) do
					local f = p:FindFirstChild(fName)
					if f then inspectFolder(f) end
				end
			end
		end

		if newFound then
			renderColumnHeaders()
			for _, cb in pairs(rowRefreshCallbacks) do
				pcall(cb)
			end
		end
	end

	-- ── Sort Players by Primary Leaderstat ─────────────────────────────
	local function updateSorting()
		local primaryStat = activeStatColumns[1]
		local scores: {[Player]: number} = {}

		for _, p in ipairs(Players:GetPlayers()) do
			if primaryStat then
				local val = getPlayerStatValue(p, primaryStat)
				scores[p] = tonumber(val) or 0
			else
				scores[p] = 0
			end
		end

		local sorted = Players:GetPlayers()
		table.sort(sorted, function(a, b)
			local sA = scores[a] or 0
			local sB = scores[b] or 0
			if sA ~= sB then
				return sA > sB
			end
			return a.Name:lower() < b.Name:lower()
		end)

		for rank, p in ipairs(sorted) do
			local row = rowObjects[p]
			if row and row.Parent then
				row.LayoutOrder = rank
			end
		end
	end

	-- ── Incremental Domino-Animated Player Rows (Clickable) ───────────
	local function createPlayerRow(player: Player, delaySec: number?)
		local rowId = "PLR_" .. tostring(player.UserId)
		if container:FindFirstChild(rowId) then return end

		local rowBtn = Instance.new("TextButton")
		rowBtn.Name = rowId
		rowBtn.Size = UDim2.new(1, 0, 0, ROW_H)
		rowBtn.Position = UDim2.new(0, 24, 0, 0)
		rowBtn.BackgroundColor3 = if player == Players.LocalPlayer then UI.Theme.ContainerDark else UI.Theme.Container
		rowBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
		rowBtn.BorderSizePixel = 0
		rowBtn.Text = ""
		rowBtn.AutoButtonColor = false
		rowBtn.ClipsDescendants = true
		rowBtn.Parent = container
		UI.registerThemeElement(rowBtn, "Container")
		rowObjects[player] = rowBtn

		local rowStroke = Instance.new("UIStroke")
		rowStroke.Color = if player == Players.LocalPlayer then UI.Theme.Accent else UI.Theme.Border
		rowStroke.Thickness = 1
		rowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		rowStroke.Parent = rowBtn
		UI.registerThemeElement(rowStroke, "Border")

		-- Avatar Headshot
		local avatarBox = Instance.new("Frame")
		avatarBox.Size = UDim2.new(0, 28, 0, 28)
		avatarBox.Position = UDim2.new(0, 4, 0, 4)
		avatarBox.BackgroundColor3 = UI.Theme.ContainerDark
		avatarBox.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
		avatarBox.BorderSizePixel = 0
		avatarBox.Parent = rowBtn
		UI.registerThemeElement(avatarBox, "ContainerDark")

		local avStroke = Instance.new("UIStroke")
		avStroke.Color = UI.Theme.Border
		avStroke.Thickness = 1
		avStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		avStroke.Parent = avatarBox
		UI.registerThemeElement(avStroke, "Border")

		local avatarImg = Instance.new("ImageLabel")
		avatarImg.Size = UDim2.new(1, 0, 1, 0)
		avatarImg.BackgroundTransparency = 1
		avatarImg.Parent = avatarBox
		task.spawn(function()
			local ok, thumb = pcall(function()
				return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size60x60)
			end)
			if ok and thumb and avatarImg.Parent then
				avatarImg.Image = thumb
			end
		end)

		-- Identity Container (Name + Username/Team)
		local infoContainer = Instance.new("Frame")
		infoContainer.Name = "InfoContainer"
		infoContainer.Position = UDim2.new(0, 36, 0, 2)
		infoContainer.Size = UDim2.new(1, -(36 + (#activeStatColumns * STAT_COL_W) + 4), 1, -4)
		infoContainer.BackgroundTransparency = 1
		infoContainer.Parent = rowBtn

		-- Name Label
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, 0, 0, 16)
		nameLabel.Position = UDim2.new(0, 0, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = player.DisplayName .. (if player == Players.LocalPlayer then " (You)" else "")
		nameLabel.TextColor3 = UI.Theme.TextPrimary
		nameLabel.Font = UI.Fonts.Header
		nameLabel.TextSize = 10
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = infoContainer
		UI.registerThemeElement(nameLabel, "TextPrimary")

		-- Subtitle Label (@Username or Team)
		local subLabel = Instance.new("TextLabel")
		subLabel.Size = UDim2.new(1, 0, 0, 13)
		subLabel.Position = UDim2.new(0, 0, 0, 16)
		subLabel.BackgroundTransparency = 1
		subLabel.TextColor3 = UI.Theme.TextSecondary
		subLabel.Font = UI.Fonts.Mono
		subLabel.TextSize = 9
		subLabel.TextXAlignment = Enum.TextXAlignment.Left
		subLabel.TextTruncate = Enum.TextTruncate.AtEnd
		subLabel.Parent = infoContainer
		UI.registerThemeElement(subLabel, "TextSecondary")

		-- Stats Cells Container
		local statsRowFrame = Instance.new("Frame")
		statsRowFrame.Name = "StatsRowFrame"
		statsRowFrame.Size = UDim2.new(0, #activeStatColumns * STAT_COL_W, 1, 0)
		statsRowFrame.Position = UDim2.new(1, -4, 0, 0)
		statsRowFrame.AnchorPoint = Vector2.new(1, 0)
		statsRowFrame.BackgroundTransparency = 1
		statsRowFrame.Parent = rowBtn

		local statLabels: {[string]: TextLabel} = {}

		local function refreshRowStats()
			if not rowBtn or not rowBtn.Parent then return end

			-- Update Info container width to accommodate columns
			local numCols = #activeStatColumns
			statsRowFrame.Size = UDim2.new(0, numCols * STAT_COL_W, 1, 0)
			infoContainer.Size = UDim2.new(1, -(36 + (numCols * STAT_COL_W) + 4), 1, -4)

			-- SubLabel text (Team or username)
			if player.Team then
				subLabel.Text = string.format("[%s] @%s", player.Team.Name, player.Name)
				subLabel.TextColor3 = player.TeamColor.Color
			else
				subLabel.Text = "@" .. player.Name
				subLabel.TextColor3 = UI.Theme.TextSecondary
			end

			-- Clear missing columns and create new ones
			for colName, lbl in pairs(statLabels) do
				if not table.find(activeStatColumns, colName) then
					lbl:Destroy()
					statLabels[colName] = nil
				end
			end

			for i, colName in ipairs(activeStatColumns) do
				local sVal, _ = getPlayerStatValue(player, colName)
				local lbl = statLabels[colName]
				if not lbl then
					lbl = Instance.new("TextLabel")
					lbl.Name = "StatVal_" .. colName
					lbl.Size = UDim2.new(0, STAT_COL_W, 1, 0)
					lbl.Position = UDim2.new(0, (i - 1) * STAT_COL_W, 0, 0)
					lbl.BackgroundTransparency = 1
					lbl.Font = UI.Fonts.Mono
					lbl.TextSize = 10
					lbl.TextXAlignment = Enum.TextXAlignment.Center
					lbl.TextTruncate = Enum.TextTruncate.AtEnd
					lbl.Parent = statsRowFrame
					statLabels[colName] = lbl
				else
					lbl.Position = UDim2.new(0, (i - 1) * STAT_COL_W, 0, 0)
				end

				if sVal ~= nil then
					lbl.Text = formatStatVal(sVal)
					lbl.TextColor3 = UI.Theme.Accent
				else
					lbl.Text = "-"
					lbl.TextColor3 = UI.Theme.TextSecondary
				end
			end

			updateSorting()
		end

		rowRefreshCallbacks[player] = refreshRowStats

		-- Dynamic live listeners for this player's stats
		local pConns: {RBXScriptConnection} = {}
		playerConnections[player] = pConns

		local function hookStatItem(item: Instance)
			if item:IsA("ValueBase") then
				if not table.find(activeStatColumns, item.Name) and #activeStatColumns < MAX_STAT_COLS then
					table.insert(activeStatColumns, item.Name)
					renderColumnHeaders()
					for _, cb in pairs(rowRefreshCallbacks) do
						pcall(cb)
					end
				end

				table.insert(pConns, item.Changed:Connect(function()
					refreshRowStats()
				end))
			end
		end

		local function hookFolder(folder: Instance)
			for _, child in ipairs(folder:GetChildren()) do
				hookStatItem(child)
			end
			table.insert(pConns, folder.ChildAdded:Connect(function(c)
				hookStatItem(c)
				refreshRowStats()
			end))
			table.insert(pConns, folder.ChildRemoved:Connect(function()
				refreshRowStats()
			end))
		end

		for _, fName in ipairs({"leaderstats", "Data", "Stats", "Currencies", "Values", "PlayerData"}) do
			local f = player:FindFirstChild(fName)
			if f then hookFolder(f) end
		end

		table.insert(pConns, player.ChildAdded:Connect(function(child)
			for _, fName in ipairs({"leaderstats", "Data", "Stats", "Currencies", "Values", "PlayerData"}) do
				if child.Name == fName then
					hookFolder(child)
					refreshRowStats()
					break
				end
			end
		end))

		table.insert(pConns, player.AttributeChanged:Connect(function(attr)
			if not table.find(activeStatColumns, attr) and #activeStatColumns < MAX_STAT_COLS then
				table.insert(activeStatColumns, attr)
				renderColumnHeaders()
				for _, cb in pairs(rowRefreshCallbacks) do
					pcall(cb)
				end
			else
				refreshRowStats()
			end
		end))

		table.insert(pConns, player:GetPropertyChangedSignal("Team"):Connect(refreshRowStats))

		refreshRowStats()

		-- Row Hover FX
		rowBtn.MouseEnter:Connect(function()
			TweenService:Create(rowStroke, TweenInfo.new(0.12), { Color = UI.Theme.Accent, Thickness = 1.4 }):Play()
			TweenService:Create(rowBtn, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.ContainerDark }):Play()
		end)
		rowBtn.MouseLeave:Connect(function()
			local defBorder = if player == Players.LocalPlayer then UI.Theme.Accent else UI.Theme.Border
			local defBg = if player == Players.LocalPlayer then UI.Theme.ContainerDark else UI.Theme.Container
			TweenService:Create(rowStroke, TweenInfo.new(0.12), { Color = defBorder, Thickness = 1 }):Play()
			TweenService:Create(rowBtn, TweenInfo.new(0.12), { BackgroundColor3 = defBg }):Play()
		end)

		-- Row Click Opens Context Menu
		rowBtn.MouseButton1Click:Connect(function()
			openContextMenuForPlayer(player, rowBtn.AbsolutePosition)
		end)

		-- Domino Slide-in
		local function playSlide()
			if rowBtn and rowBtn.Parent then
				TweenService:Create(rowBtn, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Position = UDim2.new(0, 0, 0, 0)
				}):Play()
			end
		end

		if delaySec and delaySec > 0 then
			task.delay(delaySec, playSlide)
		else
			playSlide()
		end

		titleLabel.Text = string.format("Players (%d)", #Players:GetPlayers())
		updateWidgetLayout()
	end

	local function deletePlayerRow(player: Player)
		rowRefreshCallbacks[player] = nil
		rowObjects[player] = nil

		if playerConnections[player] then
			for _, conn in ipairs(playerConnections[player]) do
				pcall(function() conn:Disconnect() end)
			end
			playerConnections[player] = nil
		end

		local rowId = "PLR_" .. tostring(player.UserId)
		local row = container:FindFirstChild(rowId)
		if row and row:IsA("TextButton") then
			local tween = TweenService:Create(row, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0, 24, 0, 0),
				BackgroundTransparency = 1
			})
			tween:Play()
			tween.Completed:Connect(function()
				row:Destroy()
				titleLabel.Text = string.format("Players (%d)", #Players:GetPlayers())
				updateWidgetLayout()
			end)
		end
		if currentTargetPlayer == player and isPopupOpen then
			closeContextMenu()
		end
	end

	-- Connect Player Added / Removed
	table.insert(activeConnections, Players.PlayerAdded:Connect(function(p)
		discoverServerLeaderstats()
		createPlayerRow(p, 0)
	end))
	table.insert(activeConnections, Players.PlayerRemoving:Connect(deletePlayerRow))

	-- Discover leaderstats across present players
	discoverServerLeaderstats()

	-- Periodic safety scan for late-replicating leaderstats
	task.spawn(function()
		while true do
			task.wait(2.5)
			if not screenGui.Parent then break end
			discoverServerLeaderstats()
		end
	end)

	-- Populate existing players with domino wave
	task.spawn(function()
		for i, p in ipairs(Players:GetPlayers()) do
			createPlayerRow(p, (i - 1) * 0.035)
		end
	end)

	local function destroyWidget()
		for _, conn in ipairs(activeConnections) do
			pcall(function() conn:Disconnect() end)
		end
		table.clear(activeConnections)

		for _, conns in pairs(playerConnections) do
			for _, c in ipairs(conns) do
				pcall(function() c:Disconnect() end)
			end
		end
		table.clear(playerConnections)
		table.clear(rowRefreshCallbacks)
		table.clear(rowObjects)

		pcall(function() screenGui:Destroy() end)
	end

	widgetObj = {
		Frame = widget,
		Container = container,
		UiScale = uiScale,
		IsMinimized = false,
		Visible = true,
		IsEnabled = true,
		IsOpen = function() return isOpen end,
		Open = openWidget,
		Close = closeWidget,
		Toggle = toggleWidget,
		SetVisible = setWidgetVisible,
		Destroy = destroyWidget,
		Cleanup = destroyWidget,
		OnClose = nil,
		OnOpen = nil,
		OnMinimize = nil,
	}

	return widgetObj
end

function PlayerList.Destroy()
	pcall(function()
		local CoreGui = game:GetService("CoreGui")
		local g = CoreGui:FindFirstChild("ModularPlayerListGui")
		if g then g:Destroy() end
		local pgui = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui")
		if pgui then
			local pg = pgui:FindFirstChild("ModularPlayerListGui")
			if pg then pg:Destroy() end
		end
	end)
end

return PlayerList
