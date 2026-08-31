--!strict
--[=[
    ✦ Squared Retro Player List Widget ✦
    Incremental add/remove with slide animation. Never rebuilds the full list.
]=]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local UI = require("UI/UI.luau")

local PlayerList = {}
PlayerList.__index = PlayerList

local ROW_H = 42
local ROW_GAP = 4
local HEADER_H = 30
local MAX_CONTENT_H = 280

function PlayerList.new()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ModularPlayerListGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 500
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function() screenGui.Parent = CoreGui end)
	if not screenGui.Parent then
		screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end

	-- ── Widget (anchored to top-right) ──────────────────────────────
	local widget = Instance.new("Frame")
	widget.Name = "PlayerListWidget"
	widget.AnchorPoint = Vector2.new(1, 0)
	widget.Size = UDim2.new(0, 260, 0, HEADER_H)
	widget.Position = UDim2.new(1, -8, 0, 8)
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
	topbar.Size = UDim2.new(1, 0, 0, HEADER_H)
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
	titleLabel.Text = string.format("Players (%d)", #Players:GetPlayers())
	titleLabel.TextColor3 = UI.Theme.TextPrimary
	titleLabel.Font = UI.Fonts.Header
	titleLabel.TextSize = 11
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = topbar
	UI.registerThemeElement(titleLabel, "TextPrimary")

	local minBtn = Instance.new("TextButton")
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
	Instance.new("UIStroke", minBtn).Color = UI.Theme.Border

	local closeBtn = Instance.new("TextButton")
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
	Instance.new("UIStroke", closeBtn).Color = UI.Theme.Border

	-- ── Scrolling container ──────────────────────────────────────────
	local container = Instance.new("ScrollingFrame")
	container.Name = "PlayerListContainer"
	container.Size = UDim2.new(1, 0, 1, -HEADER_H)
	container.Position = UDim2.new(0, 0, 0, HEADER_H)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.ScrollBarThickness = 3
	container.ScrollBarImageColor3 = UI.Theme.Accent
	container.CanvasSize = UDim2.new(0, 0, 0, 0)
	container.AutomaticCanvasSize = Enum.AutomaticSize.Y
	container.ClipsDescendants = true
	container.Parent = widget

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, ROW_GAP)
	listLayout.SortOrder = Enum.SortOrder.Name
	listLayout.Parent = container

	local listPad = Instance.new("UIPadding")
	listPad.PaddingLeft = UDim.new(0, 4)
	listPad.PaddingRight = UDim.new(0, 4)
	listPad.PaddingTop = UDim.new(0, 4)
	listPad.PaddingBottom = UDim.new(0, 4)
	listPad.Parent = container

	-- ── Height recalculation ─────────────────────────────────────────
	local minimized = false

	local function recalcHeight()
		if minimized then return end
		local count = #Players:GetPlayers()
		local contentH = count * (ROW_H + ROW_GAP) + 8
		local targetH = HEADER_H + math.min(contentH, MAX_CONTENT_H)
		-- clamp to viewport
		local vpH = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 720
		local posY = widget.AbsolutePosition.Y
		targetH = math.min(targetH, vpH - posY - 8)
		TweenService:Create(widget, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 260, 0, math.max(HEADER_H, targetH))
		}):Play()
	end

	-- ── Drag topbar ──────────────────────────────────────────────────
	local dragging = false
	local dragInput: InputObject? = nil
	local dragStart = Vector3.zero
	local startPos = UDim2.new()

	topbar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = widget.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					recalcHeight()
				end
			end)
		end
	end)
	topbar.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			local vpSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
			local newX = math.clamp(startPos.X.Offset + delta.X, widget.AbsoluteSize.X, vpSize.X)
			local newY = math.clamp(startPos.Y.Offset + delta.Y, 0, vpSize.Y - widget.AbsoluteSize.Y)
			widget.Position = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
		end
	end)

	-- ── Minimize / Close ─────────────────────────────────────────────
	minBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		container.Visible = not minimized
		if minimized then
			TweenService:Create(widget, TweenInfo.new(0.2), { Size = UDim2.new(0, 260, 0, HEADER_H) }):Play()
		else
			recalcHeight()
		end
	end)
	closeBtn.MouseButton1Click:Connect(function()
		widget.Visible = false
	end)

	-- ── Build single player row (no full rebuild) ────────────────────
	local function addPlayerRow(player: Player)
		if container:FindFirstChild("PLR_" .. player.Name) then return end

		local row = Instance.new("Frame")
		row.Name = "PLR_" .. player.Name
		row.Size = UDim2.new(1, 0, 0, 0) -- start collapsed for animation
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
		Instance.new("UIStroke", avatarBox).Color = UI.Theme.Border

		local avatarImg = Instance.new("ImageLabel")
		avatarImg.Size = UDim2.new(1, 0, 1, 0)
		avatarImg.BackgroundTransparency = 1
		avatarImg.Image = Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size60x60)
		avatarImg.Parent = avatarBox

		-- Display name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -44, 0, 18)
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

		-- Sub info
		local subLabel = Instance.new("TextLabel")
		subLabel.Size = UDim2.new(1, -44, 0, 14)
		subLabel.Position = UDim2.new(0, 42, 0, 24)
		subLabel.BackgroundTransparency = 1
		local teamStr = if player.Team then string.format("[%s] ", player.Team.Name) else ""
		subLabel.Text = string.format("%sID: %d | %dd", teamStr, player.UserId, player.AccountAge)
		subLabel.TextColor3 = UI.Theme.TextSecondary
		subLabel.Font = UI.Fonts.Mono
		subLabel.TextSize = 9
		subLabel.TextXAlignment = Enum.TextXAlignment.Left
		subLabel.TextTruncate = Enum.TextTruncate.AtEnd
		subLabel.Parent = row
		UI.registerThemeElement(subLabel, "TextSecondary")

		-- Slide-in animation
		TweenService:Create(row, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(1, 0, 0, ROW_H)
		}):Play()

		titleLabel.Text = string.format("Players (%d)", #Players:GetPlayers())
		recalcHeight()
	end

	local function removePlayerRow(player: Player)
		local row = container:FindFirstChild("PLR_" .. player.Name)
		if not row then return end
		local tween = TweenService:Create(row, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(1, 0, 0, 0)
		})
		tween:Play()
		tween.Completed:Connect(function()
			row:Destroy()
			titleLabel.Text = string.format("Players (%d)", #Players:GetPlayers())
			recalcHeight()
		end)
	end

	-- ── Wire up events ────────────────────────────────────────────────
	Players.PlayerAdded:Connect(addPlayerRow)
	Players.PlayerRemoving:Connect(removePlayerRow)

	-- Initial population
	for _, p in ipairs(Players:GetPlayers()) do
		addPlayerRow(p)
	end
end

return PlayerList
