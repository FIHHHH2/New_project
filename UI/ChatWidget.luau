--!strict
--[=[
    ✦ Squared Retro Chat Widget ✦
    Clean resizable layout, no duplicate text, smooth standard dragging, full theme support.
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

	-- Detect chat engine
	local useLegacyChat = false
	pcall(function()
		useLegacyChat = (TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService)
	end)

	local DEFAULT_W, DEFAULT_H = 340, 260
	local TOPBAR_H = 28
	local BOTTOM_H = 28

	-- ── Main Widget Frame ─────────────────────────────────────────────
	local widget = Instance.new("Frame")
	widget.Name = "ChatWidget"
	widget.Size = UDim2.new(0, DEFAULT_W, 0, DEFAULT_H)
	widget.Position = UDim2.new(0, 14, 0, 14)
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

	-- ── Topbar (Drag Handle) ──────────────────────────────────────────
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

	-- Avatar Icon
	local mugBox = Instance.new("Frame")
	mugBox.Size = UDim2.new(0, 22, 0, 22)
	mugBox.Position = UDim2.new(0, 3, 0, 3)
	mugBox.BackgroundColor3 = UI.Theme.ContainerDark
	mugBox.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	mugBox.BorderSizePixel = 0
	mugBox.Parent = topbar
	UI.registerThemeElement(mugBox, "ContainerDark")

	local mugStroke = Instance.new("UIStroke")
	mugStroke.Color = UI.Theme.Border
	mugStroke.Thickness = 1
	mugStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	mugStroke.Parent = mugBox
	UI.registerThemeElement(mugStroke, "Border")

	local mugImg = Instance.new("ImageLabel")
	mugImg.Size = UDim2.new(1, 0, 1, 0)
	mugImg.BackgroundTransparency = 1
	mugImg.Image = Players:GetUserThumbnailAsync(Players.LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size60x60)
	mugImg.Parent = mugBox

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -90, 1, 0)
	titleLabel.Position = UDim2.new(0, 30, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = string.format("Chat : @%s", Players.LocalPlayer.Name)
	titleLabel.TextColor3 = UI.Theme.TextPrimary
	titleLabel.Font = UI.Fonts.Header
	titleLabel.TextSize = 10
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

	-- ── Chat Log Scrolling Container ─────────────────────────────────
	local container = Instance.new("ScrollingFrame")
	container.Name = "ChatLogContainer"
	container.Size = UDim2.new(1, -8, 1, -(TOPBAR_H + BOTTOM_H + 8))
	container.Position = UDim2.new(0, 4, 0, TOPBAR_H + 4)
	container.BackgroundColor3 = UI.Theme.ContainerDark
	container.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	container.BorderSizePixel = 0
	container.ScrollBarThickness = 3
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

	-- ── Bottom Bar (Input & Actions) ─────────────────────────────────
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
	botStroke.Thickness = 1.2
	botStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	botStroke.Parent = bottomBar
	UI.registerThemeElement(botStroke, "Border")

	local quickBtn = Instance.new("TextButton")
	quickBtn.Name = "QuickChatBtn"
	quickBtn.Size = UDim2.new(0, 56, 1, -4)
	quickBtn.Position = UDim2.new(0, 3, 0, 2)
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

	local qStroke = Instance.new("UIStroke")
	qStroke.Color = UI.Theme.Border
	qStroke.Thickness = 1
	qStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	qStroke.Parent = quickBtn
	UI.registerThemeElement(qStroke, "Border")

	local inputFrame = Instance.new("Frame")
	inputFrame.Name = "InputFrame"
	inputFrame.Size = UDim2.new(1, -126, 1, -4)
	inputFrame.Position = UDim2.new(0, 62, 0, 2)
	inputFrame.BackgroundColor3 = UI.Theme.ContainerDark
	inputFrame.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	inputFrame.BorderSizePixel = 0
	inputFrame.Parent = bottomBar
	UI.registerThemeElement(inputFrame, "ContainerDark")

	local inStroke = Instance.new("UIStroke")
	inStroke.Color = UI.Theme.Border
	inStroke.Thickness = 1
	inStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	inStroke.Parent = inputFrame
	UI.registerThemeElement(inStroke, "Border")

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
	sendBtn.Size = UDim2.new(0, 56, 1, -4)
	sendBtn.Position = UDim2.new(1, -59, 0, 2)
	sendBtn.BackgroundColor3 = UI.Theme.Accent
	sendBtn.BorderSizePixel = 0
	sendBtn.Text = "Send Msg"
	sendBtn.TextColor3 = UI.Theme.AccentText
	sendBtn.Font = UI.Fonts.Header
	sendBtn.TextSize = 9
	sendBtn.Parent = bottomBar

	local sStroke = Instance.new("UIStroke")
	sStroke.Color = UI.Theme.Border
	sStroke.Thickness = 1
	sStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	sStroke.Parent = sendBtn
	UI.registerThemeElement(sStroke, "Border")

	-- ── Bottom-Right Resize Handle ────────────────────────────────────
	local resizeHandle = Instance.new("TextButton")
	resizeHandle.Name = "ResizeHandle"
	resizeHandle.Size = UDim2.new(0, 10, 0, 10)
	resizeHandle.Position = UDim2.new(1, -10, 1, -10)
	resizeHandle.BackgroundColor3 = UI.Theme.Accent
	resizeHandle.BackgroundTransparency = 0.3
	resizeHandle.BorderSizePixel = 0
	resizeHandle.Text = ""
	resizeHandle.ZIndex = 15
	resizeHandle.Parent = widget

	-- ── Standard Roblox Topbar Drag ──────────────────────────────────
	local dragging = false
	local dragInput: InputObject? = nil
	local dragStart = Vector3.zero
	local startAbsPos = Vector2.zero

	topbar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startAbsPos = widget.AbsolutePosition
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
			local vpSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
			local targetX = math.clamp(startAbsPos.X + delta.X, 0, math.max(0, vpSize.X - widget.AbsoluteSize.X))
			local targetY = math.clamp(startAbsPos.Y + delta.Y, 0, math.max(0, vpSize.Y - widget.AbsoluteSize.Y))
			widget.Position = UDim2.new(0, targetX, 0, targetY)
		end
	end)

	-- ── Resize Drag (Screen Clamped) ─────────────────────────────────
	local resizing = false
	local resizeInput: InputObject? = nil
	local resizeStart = Vector3.zero
	local startSize = Vector2.zero

	resizeHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			resizing = true
			resizeStart = input.Position
			startSize = widget.AbsoluteSize
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					resizing = false
				end
			end)
		end
	end)

	resizeHandle.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			resizeInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input == resizeInput and resizing then
			local delta = input.Position - resizeStart
			local vpSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
			local maxW = vpSize.X - widget.AbsolutePosition.X - 10
			local maxH = vpSize.Y - widget.AbsolutePosition.Y - 10
			local newW = math.clamp(startSize.X + delta.X, 240, math.max(240, maxW))
			local newH = math.clamp(startSize.Y + delta.Y, 160, math.max(160, maxH))
			widget.Size = UDim2.new(0, newW, 0, newH)
		end
	end)

	-- ── Button Hover & Click FX ─────────────────────────────────────
	local function attachBtnFX(btn: TextButton, isClose: boolean?, isAccent: boolean?)
		local stroke = btn:FindFirstChildWhichIsA("UIStroke")
		btn.MouseEnter:Connect(function()
			if stroke then TweenService:Create(stroke, TweenInfo.new(0.12), { Thickness = 1.8 }):Play() end
			local hoverCol = if isClose then Color3.fromRGB(220, 60, 60) elseif isAccent then UI.Theme.AccentDark else UI.Theme.Accent
			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = hoverCol, TextColor3 = Color3.fromRGB(255, 255, 255) }):Play()
		end)
		btn.MouseLeave:Connect(function()
			if stroke then TweenService:Create(stroke, TweenInfo.new(0.12), { Thickness = 1 }):Play() end
			local defaultCol = if isAccent then UI.Theme.Accent else UI.Theme.ContainerDark
			local defaultTextCol = if isAccent then UI.Theme.AccentText else UI.Theme.TextPrimary
			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = defaultCol, TextColor3 = defaultTextCol }):Play()
		end)
		btn.MouseButton1Down:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.08), { Size = UDim2.new(btn.Size.X.Scale, btn.Size.X.Offset, btn.Size.Y.Scale, btn.Size.Y.Offset - 2) }):Play()
		end)
		btn.MouseButton1Up:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Size = UDim2.new(btn.Size.X.Scale, btn.Size.X.Offset, btn.Size.Y.Scale, btn.Size.Y.Offset + 2) }):Play()
		end)
	end

	attachBtnFX(minBtn, false, false)
	attachBtnFX(closeBtn, true, false)
	attachBtnFX(quickBtn, false, false)
	attachBtnFX(sendBtn, false, true)

	-- ── Minimize / Close ─────────────────────────────────────────────
	local minimized = false
	minBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		if minimized then
			container.Visible = false
			bottomBar.Visible = false
			resizeHandle.Visible = false
			TweenService:Create(widget, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, widget.AbsoluteSize.X, 0, TOPBAR_H)
			}):Play()
		else
			container.Visible = true
			bottomBar.Visible = true
			resizeHandle.Visible = true
			TweenService:Create(widget, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, widget.AbsoluteSize.X, 0, DEFAULT_H)
			}):Play()
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
			widget.Size = UDim2.new(0, DEFAULT_W, 0, DEFAULT_H)
			widget.BackgroundTransparency = UI.Theme.BackgroundTransparency
		end)
	end)

	-- ── Message Row Renderer (DisplayName : Message) ─────────────────
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
		row.Position = UDim2.new(0, 0, 0, 4)
		row.Parent = container

		-- Sender name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0, 64, 0, 0)
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
		UI.registerThemeElement(nameLabel, "AccentText")

		-- Message body
		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.new(1, -68, 0, 0)
		textLabel.AutomaticSize = Enum.AutomaticSize.Y
		textLabel.Position = UDim2.new(0, 68, 0, 0)
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

		-- Smooth entry animation
		TweenService:Create(row, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 0)
		}):Play()

		task.defer(function()
			container.CanvasPosition = Vector2.new(0, 999999)
		end)
	end

	-- ── Send Message ─────────────────────────────────────────────────
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

	-- ── Single Incoming Message Hook ─────────────────────────────────
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
