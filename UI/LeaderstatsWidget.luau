--!strict
--[=[
    ✦ Retro Leaderstats & Universal Currency HUD Widget ✦
    Features:
    - Dedicated draggable on-screen ScreenGui widget
    - Multi-mode display: [ My Currencies ] & [ Server Players Leaderboard ]
    - Real-time live polling of player leaderstats, Data folders, and game remotes
    - Inspect any player in the server to see all their stats & values
    - Full drag handle, minimize, close, and theme reactivity
]=]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UI = require("UI/UI.luau")
local Animations = require("UI/Animations.luau")

local LocalPlayer = Players.LocalPlayer

local LeaderstatsWidget = {}
LeaderstatsWidget.__index = LeaderstatsWidget

local function formatNum(strVal: string): string
	local num = tonumber(strVal)
	if not num then return strVal end
	if num >= 1e12 then
		return string.format("%.2fT", num / 1e12)
	elseif num >= 1e9 then
		return string.format("%.2fB", num / 1e9)
	elseif num >= 1e6 then
		return string.format("%.2fM", num / 1e6)
	elseif num >= 1e3 then
		return string.format("%.1fK", num / 1e3)
	end
	return tostring(num)
end

local function getPlayerStats(player: Player): {{ Name: string, Value: string, Formatted: string }}
	local list: {{ Name: string, Value: string, Formatted: string }} = {}
	local seen: {[string]: boolean} = {}

	local function add(name: string, val: any)
		local sVal = tostring(val)
		if seen[name] or sVal == "" or #sVal > 40 then return end
		seen[name] = true
		table.insert(list, {
			Name = name,
			Value = sVal,
			Formatted = formatNum(sVal)
		})
	end

	-- 1. leaderstats folder
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		for _, v in ipairs(ls:GetChildren()) do
			if v:IsA("ValueBase") then
				add(v.Name, (v :: any).Value)
			end
		end
	end

	-- 2. Known folders on Player
	for _, fName in ipairs({"Data", "Stats", "Values", "Currencies", "PlayerData"}) do
		local f = player:FindFirstChild(fName)
		if f then
			for _, v in ipairs(f:GetChildren()) do
				if v:IsA("ValueBase") then
					add(v.Name, (v :: any).Value)
				end
			end
		end
	end

	-- 3. If LocalPlayer, check remote data
	if player == LocalPlayer then
		pcall(function()
			local gpd = ReplicatedStorage:FindFirstChild("GetPlayerData")
			if gpd and gpd:IsA("RemoteFunction") then
				local data = gpd:InvokeServer()
				if type(data) == "table" then
					for k, v in pairs(data) do
						if type(v) ~= "table" and type(v) ~= "function" and tostring(k) ~= "Name" and tostring(k) ~= "FirstJoin" and tostring(k) ~= "RandomNumber" then
							add(tostring(k), tostring(v))
						end
					end
				end
			end
		end)
	end

	return list
end

function LeaderstatsWidget.new()
	local self = setmetatable({}, LeaderstatsWidget)

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ModularLeaderstatsGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	pcall(function() screenGui.Parent = CoreGui end)
	if not screenGui.Parent then
		screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end

	local WIDGET_W = 240
	local TOPBAR_H = 26

	-- ── Main Widget Frame ─────────────────────────────────────────────
	local widget = Instance.new("Frame")
	widget.Name = "LeaderstatsWidgetFrame"
	widget.Size = UDim2.new(0, WIDGET_W, 0, 0)
	widget.AutomaticSize = Enum.AutomaticSize.Y
	widget.Position = UDim2.new(1, -254, 0, 48)
	widget.BackgroundColor3 = UI.Theme.Background
	widget.BackgroundTransparency = UI.Theme.BackgroundTransparency
	widget.BorderSizePixel = 0
	widget.ClipsDescendants = false
	widget.Parent = screenGui
	UI.registerThemeElement(widget, "Background")

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
	topbar.Size = UDim2.new(1, -8, 0, TOPBAR_H)
	topbar.Position = UDim2.new(0, 4, 0, 4)
	topbar.BackgroundTransparency = 1
	topbar.BorderSizePixel = 0
	topbar.Parent = widget

	local titleBox = Instance.new("Frame")
	titleBox.Name = "TitleBox"
	titleBox.Size = UDim2.new(1, -56, 1, 0)
	titleBox.Position = UDim2.new(0, 0, 0, 0)
	titleBox.BackgroundColor3 = UI.Theme.Container
	titleBox.BackgroundTransparency = UI.Theme.ContainerTransparency
	titleBox.BorderSizePixel = 0
	titleBox.Parent = topbar
	UI.registerThemeElement(titleBox, "Container")

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = UI.Theme.Border
	titleStroke.Thickness = 1.2
	titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	titleStroke.Parent = titleBox
	UI.registerThemeElement(titleStroke, "Border")

	local liveDot = Instance.new("Frame")
	liveDot.Size = UDim2.new(0, 6, 0, 6)
	liveDot.Position = UDim2.new(0, 6, 0.5, -3)
	liveDot.BackgroundColor3 = Color3.fromRGB(50, 220, 90)
	liveDot.BorderSizePixel = 0
	liveDot.Parent = titleBox

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = liveDot

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -20, 1, 0)
	titleLabel.Position = UDim2.new(0, 16, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Stats & Currencies"
	titleLabel.TextColor3 = UI.Theme.TextPrimary
	titleLabel.Font = UI.Fonts.Header
	titleLabel.TextSize = 10
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = titleBox
	UI.registerThemeElement(titleLabel, "TextPrimary")

	-- Minimize & Close Buttons
	local minBtn = Instance.new("TextButton")
	minBtn.Name = "MinBtn"
	minBtn.Size = UDim2.new(0, 24, 1, 0)
	minBtn.Position = UDim2.new(1, -52, 0, 0)
	minBtn.BackgroundColor3 = UI.Theme.Container
	minBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
	minBtn.BorderSizePixel = 0
	minBtn.Text = "—"
	minBtn.TextColor3 = UI.Theme.TextPrimary
	minBtn.Font = UI.Fonts.Header
	minBtn.TextSize = 11
	minBtn.Parent = topbar
	UI.registerThemeElement(minBtn, "Container")
	UI.registerThemeElement(minBtn, "TextPrimary")

	local minStroke = Instance.new("UIStroke")
	minStroke.Color = UI.Theme.Border
	minStroke.Thickness = 1.2
	minStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	minStroke.Parent = minBtn
	UI.registerThemeElement(minStroke, "Border")

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 24, 1, 0)
	closeBtn.Position = UDim2.new(1, -24, 0, 0)
	closeBtn.BackgroundColor3 = UI.Theme.Container
	closeBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "X"
	closeBtn.TextColor3 = UI.Theme.TextPrimary
	closeBtn.Font = UI.Fonts.Header
	closeBtn.TextSize = 11
	closeBtn.Parent = topbar
	UI.registerThemeElement(closeBtn, "Container")
	UI.registerThemeElement(closeBtn, "TextPrimary")

	local closeStroke = Instance.new("UIStroke")
	closeStroke.Color = UI.Theme.Border
	closeStroke.Thickness = 1.2
	closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	closeStroke.Parent = closeBtn
	UI.registerThemeElement(closeStroke, "Border")

	-- ── Body Frame ────────────────────────────────────────────────────
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.new(1, -8, 0, 0)
	body.Position = UDim2.new(0, 4, 0, TOPBAR_H + 8)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Parent = widget

	local bodyPad = Instance.new("UIPadding")
	bodyPad.PaddingBottom = UDim.new(0, 6)
	bodyPad.Parent = body

	local bodyLayout = Instance.new("UIListLayout")
	bodyLayout.Padding = UDim.new(0, 4)
	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bodyLayout.Parent = body

	-- Mode Selector: [ My Stats ] [ Server Players ]
	local modeBar = Instance.new("Frame")
	modeBar.Name = "ModeBar"
	modeBar.Size = UDim2.new(1, 0, 0, 22)
	modeBar.BackgroundTransparency = 1
	modeBar.BorderSizePixel = 0
	modeBar.LayoutOrder = 1
	modeBar.Parent = body

	local modeList = Instance.new("UIListLayout")
	modeList.FillDirection = Enum.FillDirection.Horizontal
	modeList.Padding = UDim.new(0, 4)
	modeList.Parent = modeBar

	local myStatsBtn = Instance.new("TextButton")
	myStatsBtn.Name = "MyStatsBtn"
	myStatsBtn.Size = UDim2.new(0.5, -2, 1, 0)
	myStatsBtn.BackgroundColor3 = UI.Theme.Accent
	myStatsBtn.BorderSizePixel = 0
	myStatsBtn.Text = "[ My Stats ]"
	myStatsBtn.TextColor3 = UI.Theme.AccentText
	myStatsBtn.Font = UI.Fonts.Header
	myStatsBtn.TextSize = 10
	myStatsBtn.Parent = modeBar

	local myStroke = Instance.new("UIStroke")
	myStroke.Color = UI.Theme.Border
	myStroke.Thickness = 1.2
	myStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	myStroke.Parent = myStatsBtn

	local svrBtn = Instance.new("TextButton")
	svrBtn.Name = "ServerBtn"
	svrBtn.Size = UDim2.new(0.5, -2, 1, 0)
	svrBtn.BackgroundColor3 = UI.Theme.Container
	svrBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
	svrBtn.BorderSizePixel = 0
	svrBtn.Text = "[ Server Players ]"
	svrBtn.TextColor3 = UI.Theme.TextSecondary
	svrBtn.Font = UI.Fonts.Header
	svrBtn.TextSize = 10
	svrBtn.Parent = modeBar
	UI.registerThemeElement(svrBtn, "Container")
	UI.registerThemeElement(svrBtn, "TextSecondary")

	local svrStroke = Instance.new("UIStroke")
	svrStroke.Color = UI.Theme.BorderDim
	svrStroke.Thickness = 1.0
	svrStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	svrStroke.Parent = svrBtn
	UI.registerThemeElement(svrStroke, "BorderDim")

	-- Container for My Stats
	local myStatsContainer = Instance.new("ScrollingFrame")
	myStatsContainer.Name = "MyStatsContainer"
	myStatsContainer.Size = UDim2.new(1, 0, 0, 160)
	myStatsContainer.BackgroundTransparency = 1
	myStatsContainer.BorderSizePixel = 0
	myStatsContainer.ScrollBarThickness = 2
	myStatsContainer.ScrollBarImageColor3 = UI.Theme.Accent
	myStatsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	myStatsContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
	myStatsContainer.LayoutOrder = 2
	myStatsContainer.Parent = body

	local myLayout = Instance.new("UIListLayout")
	myLayout.Padding = UDim.new(0, 3)
	myLayout.SortOrder = Enum.SortOrder.LayoutOrder
	myLayout.Parent = myStatsContainer

	-- Container for Server Players
	local svrContainer = Instance.new("ScrollingFrame")
	svrContainer.Name = "ServerContainer"
	svrContainer.Size = UDim2.new(1, 0, 0, 160)
	svrContainer.BackgroundTransparency = 1
	svrContainer.BorderSizePixel = 0
	svrContainer.ScrollBarThickness = 2
	svrContainer.ScrollBarImageColor3 = UI.Theme.Accent
	svrContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	svrContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
	svrContainer.LayoutOrder = 2
	svrContainer.Visible = false
	svrContainer.Parent = body

	local svrLayout = Instance.new("UIListLayout")
	svrLayout.Padding = UDim.new(0, 3)
	svrLayout.SortOrder = Enum.SortOrder.LayoutOrder
	svrLayout.Parent = svrContainer

	local activeMode = "mine" -- "mine" or "server"

	local function setMode(mode: string)
		activeMode = mode
		if mode == "mine" then
			myStatsBtn.BackgroundColor3 = UI.Theme.Accent
			myStatsBtn.TextColor3 = UI.Theme.AccentText
			myStroke.Color = UI.Theme.Border
			myStroke.Thickness = 1.2

			svrBtn.BackgroundColor3 = UI.Theme.Container
			svrBtn.TextColor3 = UI.Theme.TextSecondary
			svrStroke.Color = UI.Theme.BorderDim
			svrStroke.Thickness = 1.0

			myStatsContainer.Visible = true
			svrContainer.Visible = false
		else
			svrBtn.BackgroundColor3 = UI.Theme.Accent
			svrBtn.TextColor3 = UI.Theme.AccentText
			svrStroke.Color = UI.Theme.Border
			svrStroke.Thickness = 1.2

			myStatsBtn.BackgroundColor3 = UI.Theme.Container
			myStatsBtn.TextColor3 = UI.Theme.TextSecondary
			myStroke.Color = UI.Theme.BorderDim
			myStroke.Thickness = 1.0

			myStatsContainer.Visible = false
			svrContainer.Visible = true
		end
	end

	myStatsBtn.MouseButton1Click:Connect(function() setMode("mine") end)
	svrBtn.MouseButton1Click:Connect(function() setMode("server") end)

	-- ── Render Functions ─────────────────────────────────────────────
	local myRowFrames: {[string]: {Row: Frame, ValLabel: TextLabel}} = {}

	local function renderMyStats()
		local stats = getPlayerStats(LocalPlayer)
		if #stats == 0 then
			local empty = myRowFrames["_empty"]
			if not empty then
				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, -2, 0, 22)
				row.BackgroundColor3 = UI.Theme.ContainerDark
				row.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
				row.BorderSizePixel = 0
				row.Parent = myStatsContainer
				UI.registerThemeElement(row, "ContainerDark")

				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.new(1, -8, 1, 0)
				lbl.Position = UDim2.new(0, 4, 0, 0)
				lbl.BackgroundTransparency = 1
				lbl.Text = "No active leaderstats found"
				lbl.TextColor3 = UI.Theme.TextSecondary
				lbl.Font = UI.Fonts.Body
				lbl.TextSize = 10
				lbl.Parent = row
				UI.registerThemeElement(lbl, "TextSecondary")

				myRowFrames["_empty"] = {Row = row, ValLabel = lbl}
			end
			return
		end

		if myRowFrames["_empty"] then
			if myRowFrames["_empty"].Row and myRowFrames["_empty"].Row.Parent then
				myRowFrames["_empty"].Row:Destroy()
			end
			myRowFrames["_empty"] = nil
		end

		for idx, s in ipairs(stats) do
			local existing = myRowFrames[s.Name]
			if existing and existing.Row and existing.Row.Parent then
				existing.ValLabel.Text = s.Formatted
			else
				local row = Instance.new("Frame")
				row.Name = s.Name .. "Row"
				row.Size = UDim2.new(1, -2, 0, 22)
				row.BackgroundColor3 = UI.Theme.Container
				row.BackgroundTransparency = UI.Theme.ContainerTransparency
				row.BorderSizePixel = 0
				row.LayoutOrder = idx
				row.Parent = myStatsContainer
				UI.registerThemeElement(row, "Container")

				local rStroke = Instance.new("UIStroke")
				rStroke.Color = UI.Theme.BorderDim
				rStroke.Thickness = 1.0
				rStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				rStroke.Parent = row
				UI.registerThemeElement(rStroke, "BorderDim")

				local nameLabel = Instance.new("TextLabel")
				nameLabel.Size = UDim2.new(0.55, -6, 1, 0)
				nameLabel.Position = UDim2.new(0, 6, 0, 0)
				nameLabel.BackgroundTransparency = 1
				nameLabel.Text = s.Name
				nameLabel.TextColor3 = UI.Theme.TextPrimary
				nameLabel.Font = UI.Fonts.Body
				nameLabel.TextSize = 10
				nameLabel.TextXAlignment = Enum.TextXAlignment.Left
				nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
				nameLabel.Parent = row
				UI.registerThemeElement(nameLabel, "TextPrimary")

				local valLabel = Instance.new("TextLabel")
				valLabel.Size = UDim2.new(0.45, -8, 1, 0)
				valLabel.Position = UDim2.new(0.55, 0, 0, 0)
				valLabel.BackgroundTransparency = 1
				valLabel.Text = s.Formatted
				valLabel.TextColor3 = UI.Theme.Accent
				valLabel.Font = UI.Fonts.Mono
				valLabel.TextSize = 10
				valLabel.TextXAlignment = Enum.TextXAlignment.Right
				valLabel.TextTruncate = Enum.TextTruncate.AtEnd
				valLabel.Parent = row
				UI.registerThemeElement(valLabel, "AccentText")

				myRowFrames[s.Name] = {Row = row, ValLabel = valLabel}
			end
		end
	end

	local serverRowFrames: {[string]: Frame} = {}

	local function renderServerPlayers()
		local plrs = Players:GetPlayers()
		for idx, p in ipairs(plrs) do
			local pKey = "P_" .. tostring(p.UserId)
			local existing = serverRowFrames[pKey]

			local pStats = getPlayerStats(p)
			local statsSummary = ""
			for _, st in ipairs(pStats) do
				if #statsSummary > 0 then statsSummary = statsSummary .. " | " end
				statsSummary = statsSummary .. string.format("%s: %s", st.Name, st.Formatted)
			end
			if statsSummary == "" then statsSummary = "No public stats" end

			if existing and existing.Parent then
				local statLbl = existing:FindFirstChild("StatSummary") :: TextLabel?
				if statLbl then statLbl.Text = statsSummary end
			else
				local row = Instance.new("Frame")
				row.Name = pKey
				row.Size = UDim2.new(1, -2, 0, 32)
				row.BackgroundColor3 = UI.Theme.Container
				row.BackgroundTransparency = UI.Theme.ContainerTransparency
				row.BorderSizePixel = 0
				row.LayoutOrder = idx
				row.Parent = svrContainer
				UI.registerThemeElement(row, "Container")

				local rStroke = Instance.new("UIStroke")
				rStroke.Color = UI.Theme.BorderDim
				rStroke.Thickness = 1.0
				rStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				rStroke.Parent = row
				UI.registerThemeElement(rStroke, "BorderDim")

				local nameLabel = Instance.new("TextLabel")
				nameLabel.Size = UDim2.new(1, -12, 0, 14)
				nameLabel.Position = UDim2.new(0, 6, 0, 2)
				nameLabel.BackgroundTransparency = 1
				nameLabel.Text = string.format("%s (@%s)", p.DisplayName, p.Name)
				nameLabel.TextColor3 = UI.Theme.TextPrimary
				nameLabel.Font = UI.Fonts.Header
				nameLabel.TextSize = 10
				nameLabel.TextXAlignment = Enum.TextXAlignment.Left
				nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
				nameLabel.Parent = row
				UI.registerThemeElement(nameLabel, "TextPrimary")

				local statLbl = Instance.new("TextLabel")
				statLbl.Name = "StatSummary"
				statLbl.Size = UDim2.new(1, -12, 0, 14)
				statLbl.Position = UDim2.new(0, 6, 0, 16)
				statLbl.BackgroundTransparency = 1
				statLbl.Text = statsSummary
				statLbl.TextColor3 = UI.Theme.TextSecondary
				statLbl.Font = UI.Fonts.Mono
				statLbl.TextSize = 9
				statLbl.TextXAlignment = Enum.TextXAlignment.Left
				statLbl.TextTruncate = Enum.TextTruncate.AtEnd
				statLbl.Parent = row
				UI.registerThemeElement(statLbl, "TextSecondary")

				serverRowFrames[pKey] = row
			end
		end
	end

	-- ── Continuous Polling Loop ───────────────────────────────────────
	task.spawn(function()
		task.wait(0.5)
		while true do
			pcall(function()
				if widget.Visible then
					if activeMode == "mine" then
						renderMyStats()
					else
						renderServerPlayers()
					end
				end
			end)
			task.wait(2.0)
		end
	end)

	-- ── Dragging Mechanics ───────────────────────────────────────────
	local dragging = false
	local dragInput: InputObject? = nil
	local dragStart = Vector3.zero
	local startPos = UDim2.new()

	topbar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = widget.Position

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
			widget.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)

	-- Minimize & Close actions
	local minimized = false
	minBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		body.Visible = not minimized
	end)

	closeBtn.MouseButton1Click:Connect(function()
		widget.Visible = false
	end)

	self.Widget = widget
	self.ScreenGui = screenGui
	self.SetVisible = function(vis: boolean)
		widget.Visible = vis
	end

	return self
end

return LeaderstatsWidget
