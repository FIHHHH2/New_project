--!strict
--[=[
    ✦ Squared Retro Player List Widget ✦
    Auto-scales to player count, clamps to viewport, theme-reactive.
]=]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local UI = require("UI/UI.luau")

local PlayerList = {}
PlayerList.__index = PlayerList

export type PlayerListWidget = {
	Frame: Frame,
	Container: ScrollingFrame,
	IsMinimized: boolean,
	Visible: boolean
}

local ROW_H = 42
local ROW_GAP = 4
local HEADER_H = 32
local PAD_V = 4
local MAX_H = 300
local MIN_H = 40

function PlayerList.new(): PlayerListWidget
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ModularPlayerListGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 500
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	pcall(function() screenGui.Parent = CoreGui end)
	if not screenGui.Parent then
		screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end

	-- ── Widget Frame ────────────────────────────────────────────────
	local widget = Instance.new("Frame")
	widget.Name = "PlayerListWidget"
	widget.Size = UDim2.new(0, 270, 0, HEADER_H)
	widget.Position = UDim2.new(1, -282, 0, 10)
	widget.BackgroundColor3 = UI.Theme.Background
	widget.BackgroundTransparency = UI.Theme.BackgroundTransparency
	widget.BorderSizePixel = 0
	widget.ClipsDescendants = true
	widget.Parent = screenGui
	UI.registerThemeElement(widget, "Background")

	local outerStroke = Instance.new("UIStroke")
	outerStroke.Color = UI.Theme.Border
	outerStroke.Thickness = 1.5
	outerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outerStroke.Parent = widget
	UI.registerThemeElement(outerStroke, "Border")

	-- ── Topbar ──────────────────────────────────────────────────────
	local topbar = Instance.new("Frame")
	topbar.Name = "TopBar"
	topbar.Size = UDim2.new(1, 0, 0, HEADER_H - 2)
	topbar.Position = UDim2.new(0, 0, 0, 0)
	topbar.BackgroundColor3 = UI.Theme.Container
	topbar.BackgroundTransparency = UI.Theme.ContainerTransparency
	topbar.BorderSizePixel = 0
	topbar.Parent = widget
	UI.registerThemeElement(topbar, "Container")

	local topStroke = Instance.new("UIStroke")
	topStroke.Color = UI.Theme.Border
	topStroke.Thickness = 1.2
	topStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	topStroke.Parent = topbar
	UI.registerThemeElement(topStroke, "Border")

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, -56, 1, 0)
	titleLabel.Position = UDim2.new(0, 8, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Players (0)"
	titleLabel.TextColor3 = UI.Theme.TextPrimary
	titleLabel.Font = UI.Fonts.Header
	titleLabel.TextSize = 11
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = topbar
	UI.registerThemeElement(titleLabel, "TextPrimary")

	local minBtn = Instance.new("TextButton")
	minBtn.Name = "MinBtn"
	minBtn.Size = UDim2.new(0, 22, 0, 20)
	minBtn.Position = UDim2.new(1, -48, 0, 5)
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
	closeBtn.Size = UDim2.new(0, 22, 0, 20)
	closeBtn.Position = UDim2.new(1, -24, 0, 5)
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

	-- ── Scrolling Player List ────────────────────────────────────────
	local container = Instance.new("ScrollingFrame")
	container.Name = "PlayerListContainer"
	container.Size = UDim2.new(1, 0, 1, -HEADER_H)
	container.Position = UDim2.new(0, 0, 0, HEADER_H)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.ScrollBarThickness = 3
	container.CanvasSize = UDim2.new(0, 0, 0, 0)
	container.AutomaticCanvasSize = Enum.AutomaticSize.Y
	container.ClipsDescendants = true
	container.Parent = widget

	local listPad = Instance.new("UIPadding")
	listPad.PaddingLeft = UDim.new(0, 4)
	listPad.PaddingRight = UDim.new(0, 4)
	listPad.PaddingTop = UDim.new(0, 4)
	listPad.PaddingBottom = UDim.new(0, 4)
	listPad.Parent = container

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, ROW_GAP)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = container

	-- ── Auto-size helper ─────────────────────────────────────────────
	local minimized = false

	local function recalcHeight()
		if minimized then return end
		local vpH = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 720
		local wposY = widget.AbsolutePosition.Y
		local available = vpH - wposY - 8
		local playerCount = #Players:GetPlayers()
		local contentH = playerCount * (ROW_H + ROW_GAP) + PAD_V * 2
		local targetH = HEADER_H + math.min(contentH, MAX_H - HEADER_H)
		targetH = math.max(targetH, MIN_H)
		targetH = math.min(targetH, available)
		widget.Size = UDim2.new(0, 270, 0, targetH)
	end

	-- ── Drag logic (position-clamped) ────────────────────────────────
	local dragging = false
	local dragInput: InputObject? = nil
	local dragStart = Vector3.zero
	local startPos = UDim2.new()

	local function clampPosition()
		local vpSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		local absSize = widget.AbsoluteSize
		local px = math.clamp(widget.Position.X.Offset, 0, vpSize.X - absSize.X)
		local py = math.clamp(widget.Position.Y.Offset, 0, vpSize.Y - absSize.Y)
		widget.Position = UDim2.new(0, px, 0, py)
	end

	topbar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = widget.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					clampPosition()
					recalcHeight()
				end
			end)
		end
	end)

	topbar.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			widget.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)

	-- ── Minimize & Close ────────────────────────────────────────────
	minBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		container.Visible = not minimized
		if minimized then
			widget.Size = UDim2.new(0, 270, 0, HEADER_H)
		else
			recalcHeight()
		end
	end)

	closeBtn.MouseButton1Click:Connect(function()
		widget.Visible = false
	end)

	-- ── Player Row Builder ────────────────────────────────────────────
	local function renderPlayerRow(player: Player)
		local row = Instance.new("Frame")
		row.Name = string.format("PlayerRow_%s", player.Name)
		row.Size = UDim2.new(1, 0, 0, ROW_H)
		row.BackgroundColor3 = UI.Theme.Container
		row.BackgroundTransparency = UI.Theme.ContainerTransparency
		row.BorderSizePixel = 0
		row.ClipsDescendants = true
		row.Parent = container
		UI.registerThemeElement(row, "Container")

		local rowStroke = Instance.new("UIStroke")
		rowStroke.Color = UI.Theme.Border
		rowStroke.Thickness = 1
		rowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		rowStroke.Parent = row
		UI.registerThemeElement(rowStroke, "Border")

		-- Avatar
		local avatarBox = Instance.new("Frame")
		avatarBox.Size = UDim2.new(0, 34, 0, 34)
		avatarBox.Position = UDim2.new(0, 3, 0, 4)
		avatarBox.BackgroundColor3 = UI.Theme.ContainerDark
		avatarBox.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
		avatarBox.BorderSizePixel = 0
		avatarBox.Parent = row
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
		avatarImg.Image = Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size60x60)
		avatarImg.Parent = avatarBox

		-- Name row
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -44, 0, 17)
		nameLabel.Position = UDim2.new(0, 42, 0, 4)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = string.format("%s (@%s)", player.DisplayName, player.Name)
		nameLabel.TextColor3 = UI.Theme.TextPrimary
		nameLabel.Font = UI.Fonts.Header
		nameLabel.TextSize = 10
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = row
		UI.registerThemeElement(nameLabel, "TextPrimary")

		-- Sub info row
		local subLabel = Instance.new("TextLabel")
		subLabel.Size = UDim2.new(1, -44, 0, 14)
		subLabel.Position = UDim2.new(0, 42, 0, 22)
		subLabel.BackgroundTransparency = 1
		local teamStr = if player.Team then string.format("[ %s ] ", player.Team.Name) else ""
		subLabel.Text = string.format("%sID: %d | Age: %dd", teamStr, player.UserId, player.AccountAge)
		subLabel.TextColor3 = UI.Theme.TextSecondary
		subLabel.Font = UI.Fonts.Mono
		subLabel.TextSize = 9
		subLabel.TextXAlignment = Enum.TextXAlignment.Left
		subLabel.TextTruncate = Enum.TextTruncate.AtEnd
		subLabel.Parent = row
		UI.registerThemeElement(subLabel, "TextSecondary")
	end

	-- ── Player Refresh ────────────────────────────────────────────────
	local function refreshPlayers()
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end
		for _, p in ipairs(Players:GetPlayers()) do
			renderPlayerRow(p)
		end
		titleLabel.Text = string.format("Players (%d)", #Players:GetPlayers())
		recalcHeight()
	end

	Players.PlayerAdded:Connect(function()
		task.wait(0.1)
		refreshPlayers()
	end)
	Players.PlayerRemoving:Connect(function()
		task.wait(0.1)
		refreshPlayers()
	end)
	refreshPlayers()

	return {
		Frame = widget,
		Container = container,
		IsMinimized = false,
		Visible = true
	}
end

return PlayerList
