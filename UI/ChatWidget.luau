--!strict
--[=[
    ✦ Squared Retro Chat Widget ✦
    Renders the squared wireframe Chat interface matching the bottom-right diagram specification.
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

	pcall(function()
		screenGui.Parent = CoreGui
	end)
	if not screenGui.Parent then
		screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end

	local widget = Instance.new("Frame")
	widget.Name = "ChatWidget"
	widget.Size = UDim2.new(0, 270, 0, 260)
	widget.Position = UDim2.new(1, -282, 0, 210)
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

	-- topbar with mugshot, info, and controls
	local topbar = Instance.new("Frame")
	topbar.Name = "TopBar"
	topbar.Size = UDim2.new(1, -10, 0, 32)
	topbar.Position = UDim2.new(0, 5, 0, 5)
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

	-- mugshot
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

	-- title info
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

	-- subheader: [ Player Name ] [ Player Text Output ]
	local subHeader = Instance.new("Frame")
	subHeader.Name = "SubHeader"
	subHeader.Size = UDim2.new(1, -10, 0, 22)
	subHeader.Position = UDim2.new(0, 5, 0, 41)
	subHeader.BackgroundTransparency = 1
	subHeader.BorderSizePixel = 0
	subHeader.Parent = widget

	local colNameBox = Instance.new("Frame")
	colNameBox.Name = "ColNameBox"
	colNameBox.Size = UDim2.new(0, 80, 1, 0)
	colNameBox.Position = UDim2.new(0, 0, 0, 0)
	colNameBox.BackgroundColor3 = UI.Theme.Container
	colNameBox.BackgroundTransparency = UI.Theme.ContainerTransparency
	colNameBox.BorderSizePixel = 0
	colNameBox.Parent = subHeader
	UI.registerThemeElement(colNameBox, "Container")

	local colNameStroke = Instance.new("UIStroke")
	colNameStroke.Color = UI.Theme.Border
	colNameStroke.Thickness = 1.2
	colNameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	colNameStroke.Parent = colNameBox
	UI.registerThemeElement(colNameStroke, "Border")

	local colNameLabel = Instance.new("TextLabel")
	colNameLabel.Size = UDim2.new(1, 0, 1, 0)
	colNameLabel.BackgroundTransparency = 1
	colNameLabel.Text = "Player Name"
	colNameLabel.TextColor3 = UI.Theme.TextPrimary
	colNameLabel.Font = UI.Fonts.Header
	colNameLabel.TextSize = 10
	colNameLabel.Parent = colNameBox
	UI.registerThemeElement(colNameLabel, "TextPrimary")

	local colMsgBox = Instance.new("Frame")
	colMsgBox.Name = "ColMsgBox"
	colMsgBox.Size = UDim2.new(1, -84, 1, 0)
	colMsgBox.Position = UDim2.new(0, 84, 0, 0)
	colMsgBox.BackgroundColor3 = UI.Theme.Container
	colMsgBox.BackgroundTransparency = UI.Theme.ContainerTransparency
	colMsgBox.BorderSizePixel = 0
	colMsgBox.Parent = subHeader
	UI.registerThemeElement(colMsgBox, "Container")

	local colMsgStroke = Instance.new("UIStroke")
	colMsgStroke.Color = UI.Theme.Border
	colMsgStroke.Thickness = 1.2
	colMsgStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	colMsgStroke.Parent = colMsgBox
	UI.registerThemeElement(colMsgStroke, "Border")

	local colMsgLabel = Instance.new("TextLabel")
	colMsgLabel.Size = UDim2.new(1, -6, 1, 0)
	colMsgLabel.Position = UDim2.new(0, 6, 0, 0)
	colMsgLabel.BackgroundTransparency = 1
	colMsgLabel.Text = "Player Text Output"
	colMsgLabel.TextColor3 = UI.Theme.TextPrimary
	colMsgLabel.Font = UI.Fonts.Header
	colMsgLabel.TextSize = 10
	colMsgLabel.TextXAlignment = Enum.TextXAlignment.Left
	colMsgLabel.Parent = colMsgBox
	UI.registerThemeElement(colMsgLabel, "TextPrimary")

	-- middle scrolling chat logs
	local container = Instance.new("ScrollingFrame")
	container.Name = "ChatLogContainer"
	container.Size = UDim2.new(1, -10, 1, -100)
	container.Position = UDim2.new(0, 5, 0, 67)
	container.BackgroundColor3 = UI.Theme.ContainerDark
	container.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	container.BorderSizePixel = 0
	container.ScrollBarThickness = 2
	container.CanvasSize = UDim2.new(0, 0, 0, 0)
	container.AutomaticCanvasSize = Enum.AutomaticSize.Y
	container.ClipsDescendants = true
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
	logList.Padding = UDim.new(0, 4)
	logList.SortOrder = Enum.SortOrder.LayoutOrder
	logList.Parent = container

	-- bottom bar: [ Quick Chat ] [ / Text Message ] [ Send Msg ]
	local bottomBar = Instance.new("Frame")
	bottomBar.Name = "BottomBar"
	bottomBar.Size = UDim2.new(1, -10, 0, 24)
	bottomBar.Position = UDim2.new(0, 5, 1, -29)
	bottomBar.BackgroundTransparency = 1
	bottomBar.BorderSizePixel = 0
	bottomBar.Parent = widget

	local quickBtn = Instance.new("TextButton")
	quickBtn.Name = "QuickChatBtn"
	quickBtn.Size = UDim2.new(0, 64, 1, 0)
	quickBtn.Position = UDim2.new(0, 0, 0, 0)
	quickBtn.BackgroundColor3 = UI.Theme.Container
	quickBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
	quickBtn.BorderSizePixel = 0
	quickBtn.Text = "Quick Chat"
	quickBtn.TextColor3 = UI.Theme.TextPrimary
	quickBtn.Font = UI.Fonts.Header
	quickBtn.TextSize = 9
	quickBtn.Parent = bottomBar
	UI.registerThemeElement(quickBtn, "Container")
	UI.registerThemeElement(quickBtn, "TextPrimary")

	local quickStroke = Instance.new("UIStroke")
	quickStroke.Color = UI.Theme.Border
	quickStroke.Thickness = 1.2
	quickStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	quickStroke.Parent = quickBtn
	UI.registerThemeElement(quickStroke, "Border")

	local inputFrame = Instance.new("Frame")
	inputFrame.Name = "InputFrame"
	inputFrame.Size = UDim2.new(1, -132, 1, 0)
	inputFrame.Position = UDim2.new(0, 68, 0, 0)
	inputFrame.BackgroundColor3 = UI.Theme.ContainerDark
	inputFrame.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	inputFrame.BorderSizePixel = 0
	inputFrame.Parent = bottomBar
	UI.registerThemeElement(inputFrame, "ContainerDark")

	local inputStroke = Instance.new("UIStroke")
	inputStroke.Color = UI.Theme.Border
	inputStroke.Thickness = 1.2
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
	sendBtn.Size = UDim2.new(0, 60, 1, 0)
	sendBtn.Position = UDim2.new(1, -60, 0, 0)
	sendBtn.BackgroundColor3 = UI.Theme.Accent
	sendBtn.BorderSizePixel = 0
	sendBtn.Text = "Send Msg"
	sendBtn.TextColor3 = UI.Theme.AccentText
	sendBtn.Font = UI.Fonts.Header
	sendBtn.TextSize = 9
	sendBtn.Parent = bottomBar

	local sendStroke = Instance.new("UIStroke")
	sendStroke.Color = UI.Theme.Border
	sendStroke.Thickness = 1.2
	sendStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	sendStroke.Parent = sendBtn
	UI.registerThemeElement(sendStroke, "Border")

	-- Dragging
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
		subHeader.Visible = not minimized
		container.Visible = not minimized
		bottomBar.Visible = not minimized
		widget.Size = if minimized then UDim2.new(0, 270, 0, 42) else UDim2.new(0, 270, 0, 260)
	end)

	closeBtn.MouseButton1Click:Connect(function()
		widget.Visible = false
	end)

	-- Message dispatch helper
	local function addMessage(senderName: string, text: string)
		local row = Instance.new("Frame")
		row.Name = "MsgRow"
		row.Size = UDim2.new(1, 0, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Parent = container

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0, 76, 1, 0)
		nameLabel.Position = UDim2.new(0, 0, 0, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = senderName .. ":"
		nameLabel.TextColor3 = UI.Theme.Accent
		nameLabel.Font = UI.Fonts.Header
		nameLabel.TextSize = 10
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextYAlignment = Enum.TextYAlignment.Top
		nameLabel.Parent = row

		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.new(1, -80, 0, 0)
		textLabel.Position = UDim2.new(0, 80, 0, 0)
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

		container.CanvasPosition = Vector2.new(0, 99999)
	end

	local function sendMessage(msg: string)
		if msg == "" then return end
		textBox.Text = ""

		-- Modern TextChatService
		pcall(function()
			local general = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
			if general then
				general:SendAsync(msg)
			end
		end)

		-- Legacy Chat
		pcall(function()
			local sayMsg = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents") and ReplicatedStorage.DefaultChatSystemChatEvents:FindFirstChild("SayMessageRequest")
			if sayMsg and sayMsg:IsA("RemoteEvent") then
				sayMsg:FireServer(msg, "All")
			end
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

	-- Quick chat macros
	local quickPhrases = { "gg", "Hello everyone!", "Need assistance!", "Look out!", "Nice one!" }
	local qIndex = 1
	quickBtn.MouseButton1Click:Connect(function()
		local phrase = quickPhrases[qIndex]
		qIndex = (qIndex % #quickPhrases) + 1
		sendMessage(phrase)
	end)

	-- Listen for incoming chat messages
	pcall(function()
		TextChatService.OnIncomingMessage = function(message)
			if message.TextSource then
				local player = Players:GetPlayerByUserId(message.TextSource.UserId)
				local name = if player then player.DisplayName else "System"
				addMessage(name, message.Text)
			end
		end
	end)

	-- Hook Legacy Chat Events
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

	addMessage("System", "Chat suite initialized.")

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
