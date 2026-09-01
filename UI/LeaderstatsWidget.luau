--!strict
--[=[
    ✦ Retro Leaderstats & Universal Currency HUD Widget ✦
    Features:
    - Auto-arranges next to the PlayerList tab widget
    - Clean currency separation: [ Currencies ] vs [ Other Values ] vs [ Server Players ]
    - Full high-contrast legibility across Light, Dark, Translucent, and Adaptive themes
    - Right-click any stat row to move it between Currencies and Other Values (with JSON persistence)
    - Full fluid animations (spring opening, hover glows, click pops, tab transitions)
    - Real-time live polling of leaderstats, Data folders, and game remotes
]=]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local UI = require("UI/UI.luau")
local Animations = require("UI/Animations.luau")

local LocalPlayer = Players.LocalPlayer

local LeaderstatsWidget = {}
LeaderstatsWidget.__index = LeaderstatsWidget

local STAT_OVERRIDES_FILE = "fih_stat_overrides.json"
local UserCategoryOverrides: {[string]: string} = {}

local function loadOverrides()
	pcall(function()
		local rf = readfile or (getgenv and getgenv().readfile)
		local isf = isfile or (getgenv and getgenv().isfile)
		if type(rf) == "function" and (type(isf) ~= "function" or isf(STAT_OVERRIDES_FILE)) then
			local content = rf(STAT_OVERRIDES_FILE)
			local data = HttpService:JSONDecode(content)
			if type(data) == "table" then
				UserCategoryOverrides = data
			end
		end
	end)
end

local function saveOverrides()
	pcall(function()
		local wf = writefile or (getgenv and getgenv().writefile)
		if type(wf) == "function" then
			wf(STAT_OVERRIDES_FILE, HttpService:JSONEncode(UserCategoryOverrides))
		end
	end)
end

loadOverrides()

local PRIMARY_EXACT_NAMES: {[string]: boolean} = {
	["coins"] = true,
	["coin"] = true,
	["cash"] = true,
	["money"] = true,
	["crystals"] = true,
	["crystal"] = true,
	["gems"] = true,
	["gem"] = true,
	["water"] = true,
	["tankwater"] = true,
	["points"] = true,
	["point"] = true,
	["rubies"] = true,
	["ruby"] = true,
	["diamonds"] = true,
	["diamond"] = true,
	["rebirths"] = true,
	["rebirth"] = true,
	["level"] = true,
	["lvl"] = true,
	["kills"] = true,
	["kill"] = true,
	["wins"] = true,
	["win"] = true,
	["score"] = true,
	["tokens"] = true,
	["token"] = true,
	["credits"] = true,
	["credit"] = true,
	["energy"] = true,
	["stars"] = true,
	["star"] = true,
	["shards"] = true,
	["shard"] = true,
	["xp"] = true,
	["exp"] = true,
	["bounty"] = true,
	["rank"] = true,
	["prestige"] = true,
	["timeplayed"] = true
}

local function isPrimaryCurrency(name: string, val: any): boolean
	local override = UserCategoryOverrides[name]
	if override == "currencies" then
		return true
	elseif override == "others" then
		return false
	end

	local lower = name:lower()
	return PRIMARY_EXACT_NAMES[lower] == true
end

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

type StatItem = {
	Name: string,
	Value: string,
	Formatted: string,
	IsPrimary: boolean
}

local function getAllPlayerStats(player: Player): { Primaries: {StatItem}, Others: {StatItem} }
	local primaries: {StatItem} = {}
	local others: {StatItem} = {}
	local seen: {[string]: boolean} = {}

	local function add(name: string, val: any, forcePrimary: boolean?)
		local sVal = tostring(val)
		if seen[name] or sVal == "" or #sVal > 50 then return end
		seen[name] = true

		local primary = if forcePrimary ~= nil then forcePrimary else isPrimaryCurrency(name, val)
		local item: StatItem = {
			Name = name,
			Value = sVal,
			Formatted = formatNum(sVal),
			IsPrimary = primary
		}

		if primary then
			table.insert(primaries, item)
		else
			table.insert(others, item)
		end
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

	return { Primaries = primaries, Others = others }
end

function LeaderstatsWidget.new()
	local self = setmetatable({}, LeaderstatsWidget)

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ModularLeaderstatsGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 605
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	pcall(function() screenGui.Parent = CoreGui end)
	if not screenGui.Parent then
		screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end

	local WIDGET_W = 248
	local TOPBAR_H = 26

	-- Default position: Auto-arranged directly to the left of the PlayerList widget
	local widget = Instance.new("Frame")
	widget.Name = "LeaderstatsWidgetFrame"
	widget.Size = UDim2.new(0, WIDGET_W, 0, 0)
	widget.AutomaticSize = Enum.AutomaticSize.Y
	widget.Position = UDim2.new(1, -(270 + WIDGET_W + 8), 0, 10)
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

	-- ── Topbar (Drag Handle & Controls) ──────────────────────────────
	local topbar = Instance.new("Frame")
	topbar.Name = "TopBar"
	topbar.Size = UDim2.new(1, -8, 0, TOPBAR_H)
	topbar.Position = UDim2.new(0, 4, 0, 4)
	topbar.BackgroundTransparency = 1
	topbar.BorderSizePixel = 0
	topbar.Parent = widget

	local titleBox = Instance.new("Frame")
	titleBox.Name = "TitleBox"
	titleBox.Size = UDim2.new(1, -78, 1, 0)
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
	liveDot.BackgroundColor3 = Color3.fromRGB(50, 225, 100)
	liveDot.BorderSizePixel = 0
	liveDot.Parent = titleBox

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = liveDot

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -20, 1, 0)
	titleLabel.Position = UDim2.new(0, 16, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Leaderstats HUD"
	titleLabel.TextColor3 = UI.Theme.TextPrimary
	titleLabel.Font = UI.Fonts.Header
	titleLabel.TextSize = 10
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = titleBox
	UI.registerThemeElement(titleLabel, "TextPrimary")

	-- Dock Button (Snaps directly next to PlayerList)
	local dockBtn = Instance.new("TextButton")
	dockBtn.Name = "DockBtn"
	dockBtn.Size = UDim2.new(0, 22, 1, 0)
	dockBtn.Position = UDim2.new(1, -74, 0, 0)
	dockBtn.BackgroundColor3 = UI.Theme.Container
	dockBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
	dockBtn.BorderSizePixel = 0
	dockBtn.Text = "⇲"
	dockBtn.TextColor3 = UI.Theme.TextSecondary
	dockBtn.Font = UI.Fonts.Header
	dockBtn.TextSize = 11
	dockBtn.Parent = topbar
	UI.registerThemeElement(dockBtn, "Container")
	UI.registerThemeElement(dockBtn, "TextSecondary")
	Animations.buttonHoverPush(dockBtn)

	local dockStroke = Instance.new("UIStroke")
	dockStroke.Color = UI.Theme.BorderDim
	dockStroke.Thickness = 1.0
	dockStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	dockStroke.Parent = dockBtn
	UI.registerThemeElement(dockStroke, "BorderDim")

	-- Minimize & Close Buttons
	local minBtn = Instance.new("TextButton")
	minBtn.Name = "MinBtn"
	minBtn.Size = UDim2.new(0, 22, 1, 0)
	minBtn.Position = UDim2.new(1, -48, 0, 0)
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
	Animations.buttonHoverPush(minBtn)

	local minStroke = Instance.new("UIStroke")
	minStroke.Color = UI.Theme.Border
	minStroke.Thickness = 1.0
	minStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	minStroke.Parent = minBtn
	UI.registerThemeElement(minStroke, "Border")

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 22, 1, 0)
	closeBtn.Position = UDim2.new(1, -22, 0, 0)
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
	Animations.buttonHoverPush(closeBtn)

	local closeStroke = Instance.new("UIStroke")
	closeStroke.Color = UI.Theme.Border
	closeStroke.Thickness = 1.0
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

	-- Mode Selector: [ Currencies ] [ Other Values ] [ Server ]
	local modeBar = Instance.new("Frame")
	modeBar.Name = "ModeBar"
	modeBar.Size = UDim2.new(1, 0, 0, 22)
	modeBar.BackgroundTransparency = 1
	modeBar.BorderSizePixel = 0
	modeBar.LayoutOrder = 1
	modeBar.Parent = body

	local modeList = Instance.new("UIListLayout")
	modeList.FillDirection = Enum.FillDirection.Horizontal
	modeList.Padding = UDim.new(0, 3)
	modeList.Parent = modeBar

	local function makeModeBtn(name: string, text: string): (TextButton, UIStroke)
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.Size = UDim2.new(0.333, -2, 1, 0)
		btn.BackgroundColor3 = UI.Theme.Container
		btn.BackgroundTransparency = UI.Theme.ContainerTransparency
		btn.BorderSizePixel = 0
		btn.Text = text
		btn.TextColor3 = UI.Theme.TextSecondary
		btn.Font = UI.Fonts.Header
		btn.TextSize = 9
		btn.Parent = modeBar
		UI.registerThemeElement(btn, "Container")
		UI.registerThemeElement(btn, "TextSecondary")
		Animations.buttonHoverPush(btn)

		local st = Instance.new("UIStroke")
		st.Color = UI.Theme.BorderDim
		st.Thickness = 1.0
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Parent = btn
		UI.registerThemeElement(st, "BorderDim")

		return btn, st
	end

	local curBtn, curStroke = makeModeBtn("CurrenciesBtn", "Currencies")
	local othBtn, othStroke = makeModeBtn("OthersBtn", "Other Values")
	local svrBtn, svrStroke = makeModeBtn("ServerBtn", "Server")

	-- 1. Currencies Container
	local curContainer = Instance.new("ScrollingFrame")
	curContainer.Name = "CurrenciesContainer"
	curContainer.Size = UDim2.new(1, 0, 0, 168)
	curContainer.BackgroundTransparency = 1
	curContainer.BorderSizePixel = 0
	curContainer.ScrollBarThickness = 2
	curContainer.ScrollBarImageColor3 = UI.Theme.Accent
	curContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	curContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
	curContainer.LayoutOrder = 2
	curContainer.Parent = body

	local curLayout = Instance.new("UIListLayout")
	curLayout.Padding = UDim.new(0, 3)
	curLayout.SortOrder = Enum.SortOrder.LayoutOrder
	curLayout.Parent = curContainer

	-- 2. Other Values Container
	local othContainer = Instance.new("ScrollingFrame")
	othContainer.Name = "OthersContainer"
	othContainer.Size = UDim2.new(1, 0, 0, 168)
	othContainer.BackgroundTransparency = 1
	othContainer.BorderSizePixel = 0
	othContainer.ScrollBarThickness = 2
	othContainer.ScrollBarImageColor3 = UI.Theme.Accent
	othContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	othContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
	othContainer.LayoutOrder = 2
	othContainer.Visible = false
	othContainer.Parent = body

	local othLayout = Instance.new("UIListLayout")
	othLayout.Padding = UDim.new(0, 3)
	othLayout.SortOrder = Enum.SortOrder.LayoutOrder
	othLayout.Parent = othContainer

	-- 3. Server Players Container
	local svrContainer = Instance.new("ScrollingFrame")
	svrContainer.Name = "ServerContainer"
	svrContainer.Size = UDim2.new(1, 0, 0, 168)
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

	local activeMode = "currencies"

	local function updateTabStyles()
		local theme = UI.Theme
		local function setStyle(btn: TextButton, st: UIStroke, isActive: boolean)
			if isActive then
				btn.BackgroundColor3 = theme.Accent
				btn.BackgroundTransparency = 0
				btn.TextColor3 = theme.AccentText
				st.Color = theme.Border
				st.Thickness = 1.2
			else
				btn.BackgroundColor3 = theme.Container
				btn.BackgroundTransparency = theme.ContainerTransparency
				btn.TextColor3 = theme.TextSecondary
				st.Color = theme.BorderDim
				st.Thickness = 1.0
			end
		end

		setStyle(curBtn, curStroke, activeMode == "currencies")
		setStyle(othBtn, othStroke, activeMode == "others")
		setStyle(svrBtn, svrStroke, activeMode == "server")
	end

	-- ── Render Functions ─────────────────────────────────────────────
	local curRowFrames: {[string]: {Row: TextButton, ValLabel: TextLabel}} = {}
	local othRowFrames: {[string]: {Row: TextButton, ValLabel: TextLabel}} = {}
	local serverRowFrames: {[string]: Frame} = {}

	local function clearCache(cache: {[string]: any})
		for k, item in pairs(cache) do
			if item and item.Row and item.Row.Parent then
				item.Row:Destroy()
			end
			cache[k] = nil
		end
	end

	local renderAllStats: () -> ()

	local function renderCurrenciesList(items: {StatItem}, container: ScrollingFrame, cache: {[string]: {Row: TextButton, ValLabel: TextLabel}}, emptyText: string, currentCategory: string)
		if #items == 0 then
			local empty = cache["_empty"]
			if not empty then
				local row = Instance.new("TextButton")
				row.Size = UDim2.new(1, -2, 0, 22)
				row.BackgroundColor3 = UI.Theme.ContainerDark
				row.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
				row.BorderSizePixel = 0
				row.Text = ""
				row.AutoButtonColor = false
				row.Parent = container
				UI.registerThemeElement(row, "ContainerDark")

				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.new(1, -8, 1, 0)
				lbl.Position = UDim2.new(0, 4, 0, 0)
				lbl.BackgroundTransparency = 1
				lbl.Text = emptyText
				lbl.TextColor3 = UI.Theme.TextSecondary
				lbl.Font = UI.Fonts.Body
				lbl.TextSize = 10
				lbl.Parent = row
				UI.registerThemeElement(lbl, "TextSecondary")

				cache["_empty"] = {Row = row, ValLabel = lbl}
			end
			return
		end

		if cache["_empty"] then
			if cache["_empty"].Row and cache["_empty"].Row.Parent then
				cache["_empty"].Row:Destroy()
			end
			cache["_empty"] = nil
		end

		for idx, s in ipairs(items) do
			local existing = cache[s.Name]
			if existing and existing.Row and existing.Row.Parent then
				if existing.ValLabel.Text ~= s.Formatted then
					existing.ValLabel.Text = s.Formatted
					Animations.buttonClickPop(existing.Row)
				end
			else
				local row = Instance.new("TextButton")
				row.Name = s.Name .. "Row"
				row.Size = UDim2.new(1, -2, 0, 22)
				row.BackgroundColor3 = UI.Theme.Container
				row.BackgroundTransparency = UI.Theme.ContainerTransparency
				row.BorderSizePixel = 0
				row.Text = ""
				row.AutoButtonColor = false
				row.LayoutOrder = idx
				row.Parent = container
				UI.registerThemeElement(row, "Container")
				Animations.buttonHoverPush(row)

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

				-- Value label with high contrast for Light & Dark mode
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
				UI.registerThemeElement(valLabel, "Accent")

				-- Right-Click to swap between Currencies & Other Values
				row.MouseButton2Click:Connect(function()
					Animations.buttonClickPop(row)
					local targetCat = if currentCategory == "currencies" then "others" else "currencies"
					UserCategoryOverrides[s.Name] = targetCat
					saveOverrides()

					clearCache(curRowFrames)
					clearCache(othRowFrames)
					renderAllStats()

					pcall(function()
						local Notification = require("UI/Notification.luau")
						local catName = if targetCat == "others" then "Other Values" else "Currencies"
						Notification.new("Leaderstats HUD", string.format("Moved '%s' to %s", s.Name, catName), 2.5)
					end)
				end)

				cache[s.Name] = {Row = row, ValLabel = valLabel}
			end
		end
	end

	renderAllStats = function()
		local data = getAllPlayerStats(LocalPlayer)
		renderCurrenciesList(data.Primaries, curContainer, curRowFrames, "No active currencies found", "currencies")
		renderCurrenciesList(data.Others, othContainer, othRowFrames, "No secondary values found", "others")
	end

	local function renderServerPlayers()
		local plrs = Players:GetPlayers()
		for idx, p in ipairs(plrs) do
			local pKey = "P_" .. tostring(p.UserId)
			local existing = serverRowFrames[pKey]

			local pStats = getAllPlayerStats(p)
			local summary = ""
			for _, st in ipairs(pStats.Primaries) do
				if #summary > 0 then summary = summary .. " | " end
				summary = summary .. string.format("%s: %s", st.Name, st.Formatted)
			end
			if summary == "" then
				for _, st in ipairs(pStats.Others) do
					if #summary > 0 then summary = summary .. " | " end
					summary = summary .. string.format("%s: %s", st.Name, st.Formatted)
				end
			end
			if summary == "" then summary = "No public stats" end

			if existing and existing.Parent then
				local statLbl = existing:FindFirstChild("StatSummary") :: TextLabel?
				if statLbl then statLbl.Text = summary end
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
				statLbl.Text = summary
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

	local function setMode(mode: string)
		activeMode = mode
		updateTabStyles()

		local targetCont = if mode == "currencies" then curContainer elseif mode == "others" then othContainer else svrContainer

		for _, cont in ipairs({curContainer, othContainer, svrContainer}) do
			if cont == targetCont then
				cont.Visible = true
				cont.Position = UDim2.new(0, 4, 0, 0)
				TweenService:Create(cont, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Position = UDim2.new(0, 0, 0, 0)
				}):Play()
			else
				cont.Visible = false
			end
		end

		if mode == "currencies" or mode == "others" then
			renderAllStats()
		else
			renderServerPlayers()
		end
	end

	curBtn.MouseButton1Click:Connect(function()
		Animations.buttonClickPop(curBtn)
		setMode("currencies")
	end)
	othBtn.MouseButton1Click:Connect(function()
		Animations.buttonClickPop(othBtn)
		setMode("others")
	end)
	svrBtn.MouseButton1Click:Connect(function()
		Animations.buttonClickPop(svrBtn)
		setMode("server")
	end)

	setMode("currencies")

	-- ── Auto-Arranging & Docking Next to PlayerList ──────────────────
	local function autoDockNextToPlayerList()
		local pListGui = CoreGui:FindFirstChild("ModularPlayerListGui") or (LocalPlayer and LocalPlayer.PlayerGui:FindFirstChild("ModularPlayerListGui"))
		local pListFrame = pListGui and pListGui:FindFirstChild("PlayerListWidget")
		if pListFrame and pListFrame:IsA("GuiObject") then
			local pListPos = pListFrame.Position
			local targetPos = UDim2.new(
				pListPos.X.Scale,
				pListPos.X.Offset - WIDGET_W - 8,
				pListPos.Y.Scale,
				pListPos.Y.Offset
			)
			TweenService:Create(widget, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = targetPos
			}):Play()
		else
			widget.Position = UDim2.new(1, -(270 + WIDGET_W + 8), 0, 10)
		end
	end

	dockBtn.MouseButton1Click:Connect(function()
		Animations.buttonClickPop(dockBtn)
		autoDockNextToPlayerList()
	end)

	-- ── Theme Change Listener ────────────────────────────────────────
	UI.onThemeChanged(function(targetTheme)
		updateTabStyles()
		for _, item in pairs(curRowFrames) do
			if item and item.ValLabel then
				item.ValLabel.TextColor3 = targetTheme.Accent
			end
		end
		for _, item in pairs(othRowFrames) do
			if item and item.ValLabel then
				item.ValLabel.TextColor3 = targetTheme.Accent
			end
		end
	end)

	-- ── Continuous Polling Loop ───────────────────────────────────────
	task.spawn(function()
		task.wait(0.5)
		while true do
			pcall(function()
				if widget.Visible then
					if activeMode == "currencies" or activeMode == "others" then
						renderAllStats()
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
		Animations.buttonClickPop(minBtn)
		minimized = not minimized
		body.Visible = not minimized
	end)

	closeBtn.MouseButton1Click:Connect(function()
		Animations.buttonClickPop(closeBtn)
		widget.Visible = false
	end)

	self.Widget = widget
	self.ScreenGui = screenGui
	self.Dock = autoDockNextToPlayerList
	self.SetVisible = function(selfOrVal: any, maybeVal: any)
		local vis = if typeof(selfOrVal) == "boolean" then selfOrVal else maybeVal
		if typeof(vis) ~= "boolean" then vis = true end
		widget.Visible = vis
		if vis then
			pcall(autoDockNextToPlayerList)
			pcall(function()
				if uiScale then
					uiScale.Scale = 0.92
					TweenService:Create(uiScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
						Scale = 1.0
					}):Play()
				end
			end)
		end
	end

	return self
end

return LeaderstatsWidget
