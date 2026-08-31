--!strict
--[=[
    ✦ Squared Retro Chat Widget ✦
    Correct implementation: real chat log, no duplicate messages, resizable, theme-reactive, no placeholder column headers.
]=]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
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

	-- Determine which chat system is active exactly once
	local useLegacyChat = false
	pcall(function()
		useLegacyChat = (TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService)
	end)

	-- ── Widget Frame ────────────────────────────────────────────────
	local widget = Instance.new("Frame")
	widget.Name = "ChatWidget"
	widget.Size = UDim2.new(0, 270, 0, 260)
	widget.Position = UDim2.new(1, -282, 0, 210)
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
	topbar.Size = UDim2.new(1, 0, 0, 32)
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
	mugshotBox.Name = "MugshotBox"
	mugshotBox.Size = UDim2.new(0, 26, 0, 26)
	mugshotBox.Position = UDim2.new(0, 3, 0, 3)
	mugshotBox.BackgroundColor3 = UI.Theme.ContainerDark
	mugshotBox.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	mugshotBox.BorderSizePixel = 0
	mugshotBox.Parent = topbar
	UI.registerThemeElement(mugshotBox, "ContainerDark")

	local mugStroke = Instance.new("UIStroke")
	mugStroke.Color = UI.Theme.Border
	mugStroke.Thickness = 1
	mugStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	mugStroke.Parent = mugshotBox
	UI.registerThemeElement(mugStroke, "Border")

	local mugImg = Instance.new("ImageLabel")
	mugImg.Size = UDim2.new(1, -2, 1, -2)
	mugImg.Position = UDim2.new(0, 1, 0, 1)
	mugImg.BackgroundTransparency = 1
	mugImg.Image = Players:GetUserThumbnailAsync(Players.LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size60x60)
	mugImg.Parent = mugshotBox

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -90, 1, 0)
	titleLabel.Position = UDim2.new(0, 34, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = string.format("Chat : @%s", Players.LocalPlayer.Name)
	titleLabel.TextColor3 = UI.Theme.TextPrimary
	titleLabel.Font = UI.Fonts.Header
	titleLabel.TextSize = 11
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = topbar
	UI.registerThemeElement(titleLabel, "TextPrimary")

	local minBtn = Instance.new("TextButton")
	minBtn.Name = "MinBtn"
	minBtn.Size = UDim2.new(0, 24, 0, 24)
	minBtn.Position = UDim2.new(1, -52, 0, 4)
	minBtn.BackgroundColor3 = UI.Theme.ContainerDark
	minBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	minBtn.BorderSizePixel = 0
	minBtn.Text = "—"
	minBtn.TextColor3 = UI.Theme.TextPrimary
	minBtn.Font = UI.Fonts.Header
	minBtn.TextSize = 11
	minBtn.Parent = topbar
	UI.registerThemeElement(minBtn, "ContainerDark")
	UI.registerThemeElement(minBtn, "TextPrimary")

	local minStroke = Instance.new("UIStroke")
	minStroke.Color = UI.Theme.Border
	minStroke.Thickness = 1.2
	minStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	minStroke.Parent = minBtn
	UI.registerThemeElement(minStroke, "Border")

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 24, 0, 24)
	closeBtn.Position = UDim2.new(1, -26, 0, 4)
	closeBtn.BackgroundColor3 = UI.Theme.ContainerDark
	closeBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "X"
	closeBtn.TextColor3 = UI.Theme.TextPrimary
	closeBtn.Font = UI.Fonts.Header
	closeBtn.TextSize = 11
	closeBtn.Parent = topbar
	UI.registerThemeElement(closeBtn, "ContainerDark")
	UI.registerThemeElement(closeBtn, "TextPrimary")

	local closeStroke = Instance.new("UIStroke")
	closeStroke.Color = UI.Theme.Border
	closeStroke.Thickness = 1.2
	closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	closeStroke.Parent = closeBtn
	UI.registerThemeElement(closeStroke, "Border")

	-- ── Chat Log (scrolling, no placeholder header) ─────────────────
	local container = Instance.new("ScrollingFrame")
	container.Name = "ChatLogContainer"
	container.Size = UDim2.new(1, -10, 1, -70)
	container.Position = UDim2.new(0, 5, 0, 36)
	container.BackgroundColor3 = UI.Theme.ContainerDark
	container.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	container.BorderSizePixel = 0
	container.ScrollBarThickness = 2
	container.CanvasSize = UDim2.new(0, 0, 0, 0)
	container.AutomaticCanvasSize = Enum.AutomaticSize.Y
	container.ClipsDescendants = true
	container.ScrollingEnabled = true
	container.Parent = widget
	UI.registerThemeElement(container, "ContainerDark")

	local containerStroke = Instance.new("UIStroke")
	containerStroke.Color = UI.Theme.Border
	containerStroke.Thickness = 1.2
	containerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	containerStroke.Parent = container
	UI.registerThemeElement(containerStroke, "Border")

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 4)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = container

	local logList = Instance.new("UIListLayout")
	logList.Padding = UDim.new(0, 2)
	logList.SortOrder = Enum.SortOrder.LayoutOrder
	logList.Parent = container

	-- ── Bottom Bar ──────────────────────────────────────────────────
	local bottomBar = Instance.new("Frame")
	bottomBar.Name = "BottomBar"
	bottomBar.Size = UDim2.new(1, 0, 0, 28)
	bottomBar.Position = UDim2.new(0, 0, 1, -28)
	bottomBar.BackgroundColor3 = UI.Theme.Container
	bottomBar.BackgroundTransparency = UI.Theme.ContainerTransparency
	bottomBar.BorderSizePixel = 0
	bottomBar.Parent = widget
	UI.registerThemeElement(bottomBar, "Container")

	local bottomStroke = Instance.new("UIStroke")
	bottomStroke.Color = UI.Theme.Border
	bottomStroke.Thickness = 1.2
	bottomStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bottomStroke.Parent = bottomBar
	UI.registerThemeElement(bottomStroke, "Border")

	local quickBtn = Instance.new("TextButton")
	quickBtn.Name = "QuickChatBtn"
	quickBtn.Size = UDim2.new(0, 60, 1, -4)
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

	local quickStroke = Instance.new("UIStroke")
	quickStroke.Color = UI.Theme.Border
	quickStroke.Thickness = 1
	quickStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	quickStroke.Parent = quickBtn
	UI.registerThemeElement(quickStroke, "Border")

	local inputFrame = Instance.new("Frame")
	inputFrame.Name = "InputFrame"
	inputFrame.Size = UDim2.new(1, -130, 1, -4)
	inputFrame.Position = UDim2.new(0, 66, 0, 2)
	inputFrame.BackgroundColor3 = UI.Theme.ContainerDark
	inputFrame.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	inputFrame.BorderSizePixel = 0
	inputFrame.Parent = bottomBar
	UI.registerThemeElement(inputFrame, "ContainerDark")

	local inputStroke = Instance.new("UIStroke")
	inputStroke.Color = UI.Theme.Border
	inputStroke.Thickness = 1
	inputStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	inputStroke.Parent = inputFrame
	UI.registerThemeElement(inputStroke, "Border")

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
	sendBtn.Name = "SendBtn"
	sendBtn.Size = UDim2.new(0, 60, 1, -4)
	sendBtn.Position = UDim2.new(1, -62, 0, 2)
	sendBtn.BackgroundColor3 = UI.Theme.Accent
	sendBtn.BorderSizePixel = 0
	sendBtn.Text = "Send Msg"
	sendBtn.TextColor3 = UI.Theme.AccentText
	sendBtn.Font = UI.Fonts.Header
	sendBtn.TextSize = 9
	sendBtn.Parent = bottomBar

	local sendStroke = Instance.new("UIStroke")
	sendStroke.Color = UI.Theme.Border
	sendStroke.Thickness = 1
	sendStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	sendStroke.Parent = sendBtn
	UI.registerThemeElement(sendStroke, "Border")

	-- ── Resize Handle (bottom-right corner) ────────────────────────
	local resizeHandle = Instance.new("TextButton")
	resizeHandle.Name = "ResizeHandle"
	resizeHandle.Size = UDim2.new(0, 10, 0, 10)
	resizeHandle.Position = UDim2.new(1, -10, 1, -10)
	resizeHandle.BackgroundColor3 = UI.Theme.Accent
	resizeHandle.BackgroundTransparency = 0.4
	resizeHandle.BorderSizePixel = 0
	resizeHandle.Text = ""
	resizeHandle.ZIndex = 10
	resizeHandle.Parent = widget

	-- ── Drag (topbar) ───────────────────────────────────────────────
	local dragging = false
	local resizing = false
	local dragInput: InputObject? = nil
	local resizeInput: InputObject? = nil
	local dragStart = Vector3.zero
	local startPos = UDim2.new()
	local startSize = Vector2.zero
	local MIN_W, MIN_H = 220, 160

	local function clampToScreen(pos: UDim2, size: Vector2): UDim2
		local vpSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		local px = math.clamp(pos.X.Offset, 0, vpSize.X - size.X)
		local py = math.clamp(pos.Y.Offset, 0, vpSize.Y - size.Y)
		return UDim2.new(pos.X.Scale, px, pos.Y.Scale, py)
	end

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

	topbar.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			dragInput = input
		end
	end)

	resizeHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			resizing = true
			dragStart = input.Position
			startSize = Vector2.new(widget.AbsoluteSize.X, widget.AbsoluteSize.Y)
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then resizing = false end
			end)
		end
	end)

	resizeHandle.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			resizeInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		local vpSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			local newPos = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			widget.Position = clampToScreen(newPos, Vector2.new(widget.AbsoluteSize.X, widget.AbsoluteSize.Y))
		end
		if input == resizeInput and resizing then
			local delta = input.Position - dragStart
			local newW = math.max(MIN_W, math.min(startSize.X + delta.X, vpSize.X - widget.AbsolutePosition.X))
			local newH = math.max(MIN_H, math.min(startSize.Y + delta.Y, vpSize.Y - widget.AbsolutePosition.Y))
			widget.Size = UDim2.new(0, newW, 0, newH)
		end
	end)

	-- ── Minimize & Close ────────────────────────────────────────────
	local minimized = false
	minBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		container.Visible = not minimized
		bottomBar.Visible = not minimized
		resizeHandle.Visible = not minimized
		widget.Size = if minimized then UDim2.new(0, widget.AbsoluteSize.X, 0, 32) else UDim2.new(0, widget.AbsoluteSize.X, 0, 260)
	end)

	closeBtn.MouseButton1Click:Connect(function()
		widget.Visible = false
	end)

	-- ── Message Renderer ────────────────────────────────────────────
	local msgIndex = 0
	local function addMessage(senderName: string, text: string)
		msgIndex += 1
		local row = Instance.new("Frame")
		row.Name = "MsgRow_" .. msgIndex
		row.LayoutOrder = msgIndex
		row.Size = UDim2.new(1, 0, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Parent = container

		-- sender column (left 72px)
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0, 72, 1, 0)
		nameLabel.Position = UDim2.new(0, 0, 0, 0)
		nameLabel.AnchorPoint = Vector2.new(0, 0)
		nameLabel.AutomaticSize = Enum.AutomaticSize.Y
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = senderName .. ":"
		nameLabel.TextColor3 = UI.Theme.Accent
		nameLabel.Font = UI.Fonts.Header
		nameLabel.TextSize = 10
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextYAlignment = Enum.TextYAlignment.Top
		nameLabel.TextWrapped = true
		nameLabel.Parent = row
		UI.registerThemeElement(nameLabel, "Accent")

		-- message column
		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.new(1, -76, 0, 0)
		textLabel.Position = UDim2.new(0, 76, 0, 0)
		textLabel.AutomaticSize = Enum.AutomaticSize.Y
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

		-- Scroll to bottom
		task.defer(function()
			container.CanvasPosition = Vector2.new(0, math.huge)
		end)
	end

	-- ── Send Message (single code path, no duplication) ────────────
	local isSending = false

	local function sendMessage(msg: string)
		msg = msg:gsub("^%s+", ""):gsub("%s+$", "")
		if msg == "" or isSending then return end
		isSending = true
		textBox.Text = ""

		local success = false

		if not useLegacyChat then
			-- Modern TextChatService path
			pcall(function()
				local channel = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
				if channel then
					channel:SendAsync(msg)
					success = true
				end
			end)
		end

		if not success then
			-- Legacy fallback
			pcall(function()
				local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
				local sayReq = chatEvents and chatEvents:FindFirstChild("SayMessageRequest")
				if sayReq and sayReq:IsA("RemoteEvent") then
					sayReq:FireServer(msg, "All")
				end
			end)
		end

		task.defer(function()
			isSending = false
		end)
	end

	sendBtn.MouseButton1Click:Connect(function()
		sendMessage(textBox.Text)
	end)

	textBox.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			sendMessage(textBox.Text)
		end
	end)

	local quickPhrases = { "gg", "Hello everyone!", "Need assistance!", "Look out!", "Nice one!" }
	local qIndex = 1
	quickBtn.MouseButton1Click:Connect(function()
		sendMessage(quickPhrases[qIndex])
		qIndex = (qIndex % #quickPhrases) + 1
	end)

	-- ── Listen for Incoming Messages (one listener, correct system) ─
	if not useLegacyChat then
		-- Modern TextChatService: OnIncomingMessage fires for ALL messages including own
		pcall(function()
			TextChatService.OnIncomingMessage = function(message)
				local source = message.TextSource
				if not source then return end
				local player = Players:GetPlayerByUserId(source.UserId)
				local name = if player then player.DisplayName else "System"
				addMessage(name, message.Text)
			end
		end)
	else
		-- Legacy chat: OnMessageDoneFiltering is the correct final message event
		pcall(function()
			local chatEvents = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
			local onMsg = chatEvents and chatEvents:FindFirstChild("OnMessageDoneFiltering")
			if onMsg and onMsg:IsA("RemoteEvent") then
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
