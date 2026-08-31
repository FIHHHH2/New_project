--!strict
--[=[
    ✦ Squared Retro Chat Widget ✦
    Fixed positioning, no placeholder headers, no double messages, resizable, theme-reactive.
]=]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")

local UI = require("UI/UI.luau")

local ChatWidget = {}
ChatWidget.__index = ChatWidget

export type ChatWidgetInstance = {
	Frame: Frame,
	Container: ScrollingFrame,
	InputBox: TextBox,
	SendBtn: TextButton,
	QuickBtn: TextButton,
	IsMinimized: boolean,
	Visible: boolean
}

function ChatWidget.new(): ChatWidgetInstance
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ModularChatGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 500
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function() screenGui.Parent = CoreGui end)
	if not screenGui.Parent then
		screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end

	-- Detect chat system once
	local useLegacyChat = false
	pcall(function()
		useLegacyChat = (TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService)
	end)

	-- ── Widget (anchored to top-right, below player list) ────────────
	local DEFAULT_W, DEFAULT_H = 260, 240
	local TOPBAR_H = 30
	local BOTTOM_H = 28

	local widget = Instance.new("Frame")
	widget.Name = "ChatWidget"
	widget.AnchorPoint = Vector2.new(1, 0)
	widget.Size = UDim2.new(0, DEFAULT_W, 0, DEFAULT_H)
	-- Positioned 8px from right edge, 220px down (below player list area)
	widget.Position = UDim2.new(1, -8, 0, 220)
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
	topbar.Size = UDim2.new(1, 0, 0, TOPBAR_H)
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

	-- Mugshot
	local mugshotBox = Instance.new("Frame")
	mugshotBox.Size = UDim2.new(0, 24, 0, 24)
	mugshotBox.Position = UDim2.new(0, 3, 0, 3)
	mugshotBox.BackgroundColor3 = UI.Theme.ContainerDark
	mugshotBox.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	mugshotBox.BorderSizePixel = 0
	mugshotBox.Parent = topbar
	UI.registerThemeElement(mugshotBox, "ContainerDark")
	Instance.new("UIStroke", mugshotBox).Color = UI.Theme.Border

	local mugImg = Instance.new("ImageLabel")
	mugImg.Size = UDim2.new(1, 0, 1, 0)
	mugImg.BackgroundTransparency = 1
	mugImg.Image = Players:GetUserThumbnailAsync(Players.LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size60x60)
	mugImg.Parent = mugshotBox

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -90, 1, 0)
	titleLabel.Position = UDim2.new(0, 32, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = string.format("Chat : @%s", Players.LocalPlayer.Name)
	titleLabel.TextColor3 = UI.Theme.TextPrimary
	titleLabel.Font = UI.Fonts.Header
	titleLabel.TextSize = 10
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

	-- ── Chat Log ────────────────────────────────────────────────────
	local container = Instance.new("ScrollingFrame")
	container.Name = "ChatLogContainer"
	container.Size = UDim2.new(1, -6, 1, -(TOPBAR_H + BOTTOM_H + 6))
	container.Position = UDim2.new(0, 3, 0, TOPBAR_H + 3)
	container.BackgroundColor3 = UI.Theme.ContainerDark
	container.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	container.BorderSizePixel = 0
	container.ScrollBarThickness = 2
	container.ScrollBarImageColor3 = UI.Theme.Accent
	container.CanvasSize = UDim2.new(0, 0, 0, 0)
	container.AutomaticCanvasSize = Enum.AutomaticSize.Y
	container.ClipsDescendants = true
	container.Parent = widget
	UI.registerThemeElement(container, "ContainerDark")

	local containerStroke = Instance.new("UIStroke")
	containerStroke.Color = UI.Theme.Border
	containerStroke.Thickness = 1
	containerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	containerStroke.Parent = container
	UI.registerThemeElement(containerStroke, "Border")

	local logPad = Instance.new("UIPadding")
	logPad.PaddingLeft = UDim.new(0, 4)
	logPad.PaddingRight = UDim.new(0, 4)
	logPad.PaddingTop = UDim.new(0, 3)
	logPad.PaddingBottom = UDim.new(0, 3)
	logPad.Parent = container

	local logList = Instance.new("UIListLayout")
	logList.Padding = UDim.new(0, 2)
	logList.SortOrder = Enum.SortOrder.LayoutOrder
	logList.Parent = container

	-- ── Bottom Bar ──────────────────────────────────────────────────
	local bottomBar = Instance.new("Frame")
	bottomBar.Name = "BottomBar"
	bottomBar.Size = UDim2.new(1, 0, 0, BOTTOM_H)
	bottomBar.Position = UDim2.new(0, 0, 1, -BOTTOM_H)
	bottomBar.BackgroundColor3 = UI.Theme.Container
	bottomBar.BackgroundTransparency = UI.Theme.ContainerTransparency
	bottomBar.BorderSizePixel = 0
	bottomBar.Parent = widget
	UI.registerThemeElement(bottomBar, "Container")

	local botStroke = Instance.new("UIStroke")
	botStroke.Color = UI.Theme.Border
	botStroke.Thickness = 1
	botStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	botStroke.Parent = bottomBar
	UI.registerThemeElement(botStroke, "Border")

	local quickBtn = Instance.new("TextButton")
	quickBtn.Size = UDim2.new(0, 56, 1, -4)
	quickBtn.Position = UDim2.new(0, 2, 0, 2)
	quickBtn.BackgroundColor3 = UI.Theme.ContainerDark
	quickBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	quickBtn.BorderSizePixel = 0
	quickBtn.Text = "Quick Chat"
	quickBtn.TextColor3 = UI.Theme.TextPrimary
	quickBtn.Font = UI.Fonts.Header
	quickBtn.TextSize = 9
	quickBtn.Parent = bottomBar
	UI.registerThemeElement(quickBtn, "ContainerDark")
	UI.registerThemeElement(quickBtn, "TextPrimary")
	Instance.new("UIStroke", quickBtn).Color = UI.Theme.Border

	local inputFrame = Instance.new("Frame")
	inputFrame.Size = UDim2.new(1, -122, 1, -4)
	inputFrame.Position = UDim2.new(0, 62, 0, 2)
	inputFrame.BackgroundColor3 = UI.Theme.ContainerDark
	inputFrame.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	inputFrame.BorderSizePixel = 0
	inputFrame.Parent = bottomBar
	UI.registerThemeElement(inputFrame, "ContainerDark")
	Instance.new("UIStroke", inputFrame).Color = UI.Theme.Border

	local textBox = Instance.new("TextBox")
	textBox.Name = "MessageInput"
	textBox.Size = UDim2.new(1, -8, 1, 0)
	textBox.Position = UDim2.new(0, 4, 0, 0)
	textBox.BackgroundTransparency = 1
	textBox.PlaceholderText = "/ Text Message"
	textBox.PlaceholderColor3 = UI.Theme.TextSecondary
	textBox.Text = ""
	textBox.TextColor3 = UI.Theme.TextPrimary
	textBox.Font = UI.Fonts.Body
	textBox.TextSize = 10
	textBox.TextXAlignment = Enum.TextXAlignment.Left
	textBox.ClearTextOnFocus = false
	textBox.Parent = inputFrame
	UI.registerThemeElement(textBox, "TextPrimary")

	local sendBtn = Instance.new("TextButton")
	sendBtn.Size = UDim2.new(0, 56, 1, -4)
	sendBtn.Position = UDim2.new(1, -58, 0, 2)
	sendBtn.BackgroundColor3 = UI.Theme.Accent
	sendBtn.BorderSizePixel = 0
	sendBtn.Text = "Send Msg"
	sendBtn.TextColor3 = UI.Theme.AccentText
	sendBtn.Font = UI.Fonts.Header
	sendBtn.TextSize = 9
	sendBtn.Parent = bottomBar

	-- ── Resize handle (bottom-right corner) ─────────────────────────
	local resizeHandle = Instance.new("Frame")
	resizeHandle.Name = "ResizeHandle"
	resizeHandle.Size = UDim2.new(0, 8, 0, 8)
	resizeHandle.Position = UDim2.new(1, -8, 1, -8)
	resizeHandle.BackgroundColor3 = UI.Theme.Accent
	resizeHandle.BorderSizePixel = 0
	resizeHandle.ZIndex = 10
	resizeHandle.Parent = widget

	-- ── Drag & Resize Logic ─────────────────────────────────────────
	local dragging = false
	local resizing = false
	local dragStart = Vector3.zero
	local startPos = UDim2.new()
	local startSize = Vector2.zero
	local MIN_W, MIN_H = 200, 140

	topbar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = widget.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)

	resizeHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			resizing = true
			dragStart = input.Position
			startSize = widget.AbsoluteSize
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then resizing = false end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		local vpSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)

		if dragging then
			local delta = input.Position - dragStart
			-- AnchorPoint is (1,0) so Position.X.Offset is measured from right
			local newXOffset = math.clamp(startPos.X.Offset - delta.X, widget.AbsoluteSize.X, vpSize.X)
			local newYOffset = math.clamp(startPos.Y.Offset + delta.Y, 0, vpSize.Y - widget.AbsoluteSize.Y)
			widget.Position = UDim2.new(1, -newXOffset + widget.AbsoluteSize.X, 0, newYOffset)
		end

		if resizing then
			local delta = input.Position - dragStart
			local newW = math.clamp(startSize.X + delta.X, MIN_W, vpSize.X - widget.AbsolutePosition.X)
			local newH = math.clamp(startSize.Y + delta.Y, MIN_H, vpSize.Y - widget.AbsolutePosition.Y)
			widget.Size = UDim2.new(0, newW, 0, newH)
		end
	end)

	-- ── Minimize / Close ─────────────────────────────────────────────
	local minimized = false
	minBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		container.Visible = not minimized
		bottomBar.Visible = not minimized
		resizeHandle.Visible = not minimized
		TweenService:Create(widget, TweenInfo.new(0.18), {
			Size = if minimized then UDim2.new(0, widget.AbsoluteSize.X, 0, TOPBAR_H) else UDim2.new(0, widget.AbsoluteSize.X, 0, DEFAULT_H)
		}):Play()
	end)

	closeBtn.MouseButton1Click:Connect(function()
		widget.Visible = false
	end)

	-- ── Message Renderer ────────────────────────────────────────────
	local msgIndex = 0
	local function addMessage(senderName: string, text: string)
		msgIndex += 1
		local row = Instance.new("Frame")
		row.Name = "Msg_" .. msgIndex
		row.LayoutOrder = msgIndex
		row.Size = UDim2.new(1, 0, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Parent = container

		-- Sender name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0, 68, 0, 0)
		nameLabel.AutomaticSize = Enum.AutomaticSize.Y
		nameLabel.Position = UDim2.new(0, 0, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = senderName .. ":"
		nameLabel.TextColor3 = UI.Theme.Accent
		nameLabel.Font = UI.Fonts.Header
		nameLabel.TextSize = 10
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextYAlignment = Enum.TextYAlignment.Top
		nameLabel.TextWrapped = true
		nameLabel.Parent = row

		-- Message text
		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.new(1, -72, 0, 0)
		textLabel.AutomaticSize = Enum.AutomaticSize.Y
		textLabel.Position = UDim2.new(0, 72, 0, 0)
		textLabel.BackgroundTransparency = 1
		textLabel.Text = text
		textLabel.TextColor3 = UI.Theme.TextPrimary
		textLabel.Font = UI.Fonts.Body
		textLabel.TextSize = 10
		textLabel.TextWrapped = true
		textLabel.TextXAlignment = Enum.TextXAlignment.Left
		textLabel.TextYAlignment = Enum.TextYAlignment.Top
		textLabel.Parent = row
		UI.registerThemeElement(textLabel, "TextPrimary")

		task.defer(function()
			container.CanvasPosition = Vector2.new(0, math.huge)
		end)
	end

	-- ── Send (single path, guarded) ─────────────────────────────────
	local isSending = false
	local function sendMessage(msg: string)
		msg = msg:gsub("^%s+", ""):gsub("%s+$", "")
		if msg == "" or isSending then return end
		isSending = true
		textBox.Text = ""

		local sent = false
		if not useLegacyChat then
			pcall(function()
				local ch = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
				if ch then
					ch:SendAsync(msg)
					sent = true
				end
			end)
		end
		if not sent then
			pcall(function()
				local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
				local req = chatEvents and chatEvents:FindFirstChild("SayMessageRequest")
				if req and req:IsA("RemoteEvent") then
					req:FireServer(msg, "All")
				end
			end)
		end

		task.defer(function() isSending = false end)
	end

	sendBtn.MouseButton1Click:Connect(function() sendMessage(textBox.Text) end)
	textBox.FocusLost:Connect(function(enter) if enter then sendMessage(textBox.Text) end end)

	local quickPhrases = { "gg", "Hello!", "Nice one!", "Look out!", "Need help!" }
	local qIdx = 1
	quickBtn.MouseButton1Click:Connect(function()
		sendMessage(quickPhrases[qIdx])
		qIdx = (qIdx % #quickPhrases) + 1
	end)

	-- ── Incoming Message Hook (single listener only) ─────────────────
	if not useLegacyChat then
		pcall(function()
			TextChatService.OnIncomingMessage = function(msg)
				if not msg.TextSource then return end
				local player = Players:GetPlayerByUserId(msg.TextSource.UserId)
				local name = if player then player.DisplayName else "Server"
				addMessage(name, msg.Text)
			end
		end)
	else
		pcall(function()
			local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
			local onMsg = chatEvents and chatEvents:FindFirstChild("OnMessageDoneFiltering")
			if onMsg then
				onMsg.OnClientEvent:Connect(function(data)
					if data and data.FromSpeaker and data.Message then
						addMessage(tostring(data.FromSpeaker), tostring(data.Message))
					end
				end)
			end
		end)
	end

	addMessage("System", "Chat connected.")

	return {
		Frame = widget,
		Container = container,
		InputBox = textBox,
		SendBtn = sendBtn,
		QuickBtn = quickBtn,
		IsMinimized = false,
		Visible = true
	}
end

return ChatWidget
