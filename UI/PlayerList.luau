--!strict
--[=[
    ✦ Squared Retro Player List Widget ✦
    Smooth incremental player animations, auto-scaling height, reliable standard dragging.
]=]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
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

local ROW_H = 38
local ROW_GAP = 4
local HEADER_H = 28
local MAX_H = 240

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

	-- ── Main Widget Frame ─────────────────────────────────────────────
	local widget = Instance.new("Frame")
	widget.Name = "PlayerListWidget"
	widget.Size = UDim2.new(0, 260, 0, HEADER_H + 40)
	widget.Position = UDim2.new(1, -270, 0, 10)
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

	-- ── Topbar (Drag Handle) ──────────────────────────────────────────
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

	-- ── Scrolling Player Container ────────────────────────────────────
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

	-- ── Smooth Height Scaling to Player Count ─────────────────────────
	local minimized = false

	local function updateWidgetHeight()
		if minimized then return end
		local count = #Players:GetPlayers()
		local fullNeededHeight = HEADER_H + count * (ROW_H + ROW_GAP) + 8
		local vpH = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 720
		local posY = math.max(0, widget.AbsolutePosition.Y)
		local maxAvailableH = math.max(HEADER_H + 40, vpH - posY - 16)
		local targetH = math.min(fullNeededHeight, maxAvailableH)

		TweenService:Create(widget, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, widget.AbsoluteSize.X, 0, targetH)
		}):Play()
	end

	-- ── Standard Roblox Topbar Drag (Screen Clamped) ──────────────────
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
					updateWidgetHeight()
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
			local vpSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
			local newX = math.clamp(startPos.X.Offset + delta.X, 0, vpSize.X - widget.AbsoluteSize.X)
			local newY = math.clamp(startPos.Y.Offset + delta.Y, 0, vpSize.Y - widget.AbsoluteSize.Y)
			widget.Position = UDim2.new(startPos.X.Scale, newX, startPos.Y.Scale, newY)
		end
	end)

	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateWidgetHeight)
	end

	-- ── Button Hover & Click FX ─────────────────────────────────────
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
	minBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		if minimized then
			container.Visible = false
			TweenService:Create(widget, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, widget.AbsoluteSize.X, 0, HEADER_H)
			}):Play()
		else
			container.Visible = true
			updateWidgetHeight()
		end
	end)

	closeBtn.MouseButton1Click:Connect(function()
		local closeTween = TweenService:Create(widget, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, widget.AbsoluteSize.X * 0.9, 0, 0),
			BackgroundTransparency = 1
		})
		closeTween:Play()
		closeTween.Completed:Connect(function()
			widget.Visible = false
			widget.Size = UDim2.new(0, 260, 0, HEADER_H + 40)
			widget.BackgroundTransparency = UI.Theme.BackgroundTransparency
		end)
	end)

	-- ── Incremental Animated Player Rows ─────────────────────────────
	local function createPlayerRow(player: Player)
		local rowId = "PLR_" .. tostring(player.UserId)
		if container:FindFirstChild(rowId) then return end

		local row = Instance.new("Frame")
		row.Name = rowId
		row.Size = UDim2.new(1, 0, 0, 0) -- Start collapsed for animation
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

		-- Avatar Headshot
		local avatarBox = Instance.new("Frame")
		avatarBox.Size = UDim2.new(0, 30, 0, 30)
		avatarBox.Position = UDim2.new(0, 4, 0, 4)
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

		-- Name Label
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -42, 0, 16)
		nameLabel.Position = UDim2.new(0, 38, 0, 3)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = string.format("%s (@%s)", player.DisplayName, player.Name)
		nameLabel.TextColor3 = UI.Theme.TextPrimary
		nameLabel.Font = UI.Fonts.Header
		nameLabel.TextSize = 10
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = row
		UI.registerThemeElement(nameLabel, "TextPrimary")

		-- Details Label
		local subLabel = Instance.new("TextLabel")
		subLabel.Size = UDim2.new(1, -42, 0, 14)
		subLabel.Position = UDim2.new(0, 38, 0, 19)
		subLabel.BackgroundTransparency = 1
		local teamStr = if player.Team then string.format("[%s] ", player.Team.Name) else ""
		subLabel.Text = string.format("%sID:%d | %dd", teamStr, player.UserId, player.AccountAge)
		subLabel.TextColor3 = UI.Theme.TextSecondary
		subLabel.Font = UI.Fonts.Mono
		subLabel.TextSize = 9
		subLabel.TextXAlignment = Enum.TextXAlignment.Left
		subLabel.TextTruncate = Enum.TextTruncate.AtEnd
		subLabel.Parent = row
		UI.registerThemeElement(subLabel, "TextSecondary")

		-- Animate slide-down
		TweenService:Create(row, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(1, 0, 0, ROW_H)
		}):Play()

		titleLabel.Text = string.format("Players (%d)", #Players:GetPlayers())
		updateWidgetHeight()
	end

	local function deletePlayerRow(player: Player)
		local rowId = "PLR_" .. tostring(player.UserId)
		local row = container:FindFirstChild(rowId)
		if row and row:IsA("Frame") then
			local tween = TweenService:Create(row, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = UDim2.new(1, 0, 0, 0)
			})
			tween:Play()
			tween.Completed:Connect(function()
				row:Destroy()
				titleLabel.Text = string.format("Players (%d)", #Players:GetPlayers())
				updateWidgetHeight()
			end)
		end
	end

	-- Connect Player Added / Removed
	Players.PlayerAdded:Connect(createPlayerRow)
	Players.PlayerRemoving:Connect(deletePlayerRow)

	-- Populate existing players
	for _, p in ipairs(Players:GetPlayers()) do
		createPlayerRow(p)
	end

	return {
		Frame = widget,
		Container = container,
		IsMinimized = false,
		Visible = true
	}
end

return PlayerList
