--!strict
--[=[
    ✦ Squared Retro Player List Widget ✦
    Renders the squared wireframe Player List matching the top-right diagram specification.
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

function PlayerList.new(): PlayerListWidget
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ModularPlayerListGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 500
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	pcall(function()
		screenGui.Parent = CoreGui
	end)
	if not screenGui.Parent then
		screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end

	-- main widget frame (top right, 270px width)
	local widget = Instance.new("Frame")
	widget.Name = "PlayerListWidget"
	widget.Size = UDim2.new(0, 270, 0, 190)
	widget.Position = UDim2.new(1, -282, 0, 10)
	widget.BackgroundColor3 = UI.Theme.Background
	widget.BackgroundTransparency = UI.Theme.BackgroundTransparency
	widget.BorderSizePixel = 0
	widget.ClipsDescendants = false
	widget.Parent = screenGui
	UI.registerThemeElement(widget, "Background")

	local outerStroke = Instance.new("UIStroke")
	outerStroke.Color = UI.Theme.Border
	outerStroke.Thickness = 1.5
	outerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outerStroke.Parent = widget
	UI.registerThemeElement(outerStroke, "Border")

	-- topbar
	local topbar = Instance.new("Frame")
	topbar.Name = "TopBar"
	topbar.Size = UDim2.new(1, -10, 0, 22)
	topbar.Position = UDim2.new(0, 5, 0, 5)
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

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, -8, 1, 0)
	titleLabel.Position = UDim2.new(0, 6, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Players"
	titleLabel.TextColor3 = UI.Theme.TextPrimary
	titleLabel.Font = UI.Fonts.Header
	titleLabel.TextSize = 11
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = titleBox
	UI.registerThemeElement(titleLabel, "TextPrimary")

	local minBtn = Instance.new("TextButton")
	minBtn.Name = "MinBtn"
	minBtn.Size = UDim2.new(0, 24, 1, 0)
	minBtn.Position = UDim2.new(1, -50, 0, 0)
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

	-- divider
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Size = UDim2.new(1, 0, 0, 1.5)
	divider.Position = UDim2.new(0, 0, 0, 31)
	divider.BackgroundColor3 = UI.Theme.Border
	divider.BorderSizePixel = 0
	divider.Parent = widget
	UI.registerThemeElement(divider, "Border")

	-- scrolling player card container
	local container = Instance.new("ScrollingFrame")
	container.Name = "PlayerListContainer"
	container.Size = UDim2.new(1, -10, 1, -38)
	container.Position = UDim2.new(0, 5, 0, 35)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.ScrollBarThickness = 2
	container.CanvasSize = UDim2.new(0, 0, 0, 0)
	container.AutomaticCanvasSize = Enum.AutomaticSize.Y
	container.ClipsDescendants = true
	container.Parent = widget

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 2)
	pad.PaddingRight = UDim.new(0, 4)
	pad.PaddingTop = UDim.new(0, 2)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = container

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 4)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = container

	-- Dragging logic
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

	-- Minimize & Close
	local minimized = false
	minBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		container.Visible = not minimized
		divider.Visible = not minimized
		widget.Size = if minimized then UDim2.new(0, 270, 0, 32) else UDim2.new(0, 270, 0, 190)
	end)

	closeBtn.MouseButton1Click:Connect(function()
		widget.Visible = false
	end)

	local function renderPlayerRow(player: Player)
		local row = Instance.new("Frame")
		row.Name = string.format("PlayerRow_%s", player.Name)
		row.Size = UDim2.new(1, 0, 0, 38)
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

		-- avatar box
		local avatarBox = Instance.new("Frame")
		avatarBox.Name = "AvatarBox"
		avatarBox.Size = UDim2.new(0, 32, 0, 32)
		avatarBox.Position = UDim2.new(0, 3, 0, 3)
		avatarBox.BackgroundColor3 = UI.Theme.ContainerDark
		avatarBox.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
		avatarBox.BorderSizePixel = 0
		avatarBox.Parent = row
		UI.registerThemeElement(avatarBox, "ContainerDark")

		local avatarStroke = Instance.new("UIStroke")
		avatarStroke.Color = UI.Theme.Border
		avatarStroke.Thickness = 1
		avatarStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		avatarStroke.Parent = avatarBox
		UI.registerThemeElement(avatarStroke, "Border")

		local avatarImg = Instance.new("ImageLabel")
		avatarImg.Size = UDim2.new(1, -2, 1, -2)
		avatarImg.Position = UDim2.new(0, 1, 0, 1)
		avatarImg.BackgroundTransparency = 1
		avatarImg.Image = Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size60x60)
		avatarImg.Parent = avatarBox

		-- details block
		local nameRow = Instance.new("Frame")
		nameRow.Name = "NameRow"
		nameRow.Size = UDim2.new(1, -44, 0, 15)
		nameRow.Position = UDim2.new(0, 40, 0, 3)
		nameRow.BackgroundColor3 = UI.Theme.ContainerDark
		nameRow.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
		nameRow.BorderSizePixel = 0
		nameRow.Parent = row
		UI.registerThemeElement(nameRow, "ContainerDark")

		local nameStroke = Instance.new("UIStroke")
		nameStroke.Color = UI.Theme.Border
		nameStroke.Thickness = 1
		nameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		nameStroke.Parent = nameRow
		UI.registerThemeElement(nameStroke, "Border")

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -6, 1, 0)
		nameLabel.Position = UDim2.new(0, 4, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = string.format("%s (@%s)", player.DisplayName, player.Name)
		nameLabel.TextColor3 = UI.Theme.TextPrimary
		nameLabel.Font = UI.Fonts.Header
		nameLabel.TextSize = 10
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = nameRow
		UI.registerThemeElement(nameLabel, "TextPrimary")

		local subRow = Instance.new("Frame")
		subRow.Name = "SubRow"
		subRow.Size = UDim2.new(1, -44, 0, 14)
		subRow.Position = UDim2.new(0, 40, 0, 20)
		subRow.BackgroundColor3 = UI.Theme.ContainerDark
		subRow.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
		subRow.BorderSizePixel = 0
		subRow.Parent = row
		UI.registerThemeElement(subRow, "ContainerDark")

		local subStroke = Instance.new("UIStroke")
		subStroke.Color = UI.Theme.Border
		subStroke.Thickness = 1
		subStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		subStroke.Parent = subRow
		UI.registerThemeElement(subStroke, "Border")

		local subLabel = Instance.new("TextLabel")
		subLabel.Size = UDim2.new(1, -6, 1, 0)
		subLabel.Position = UDim2.new(0, 4, 0, 0)
		subLabel.BackgroundTransparency = 1
		local teamStr = if player.Team then string.format("Team: %s | ", player.Team.Name) else ""
		subLabel.Text = string.format("%sAge: %dd | ID: %d", teamStr, player.AccountAge, player.UserId)
		subLabel.TextColor3 = UI.Theme.TextSecondary
		subLabel.Font = UI.Fonts.Mono
		subLabel.TextSize = 9
		subLabel.TextXAlignment = Enum.TextXAlignment.Left
		subLabel.Parent = subRow
		UI.registerThemeElement(subLabel, "TextSecondary")
	end

	local function refreshPlayers()
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for _, p in ipairs(Players:GetPlayers()) do
			renderPlayerRow(p)
		end
		titleLabel.Text = string.format("Players (%d)", #Players:GetPlayers())
	end

	Players.PlayerAdded:Connect(refreshPlayers)
	Players.PlayerRemoving:Connect(refreshPlayers)
	refreshPlayers()

	return {
		Frame = widget,
		Container = container,
		IsMinimized = false,
		Visible = true
	}
end

return PlayerList
