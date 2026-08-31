--!strict
--[=[
    ✦ Squared Retro Chat Widget with TopBar Integration ✦
    Includes integrated Roblox Logo, Hamburger Menu (Menu Toggle),
    Voice Chat Mute Toggle, Hide UI, and Backpack pill bar.
]=]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextChatService = game:GetService("TextChatService")
local VoiceChatService = pcall(function() return game:GetService("VoiceChatService") end) and game:GetService("VoiceChatService") or nil
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")

local UI = require("UI/UI.luau")

local ChatWidget = {}
ChatWidget.__index = ChatWidget

export type ChatWidgetInstance = {
	Frame: Frame,
	TopBarPills: Frame,
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

	-- ============================================================
	-- ── ROBLOX TOPBAR PILLS CLUSTER (ABOVE CHAT) ─────────────────
	-- ============================================================
	local topPillsBar = Instance.new("Frame")
	topPillsBar.Name = "CustomRobloxTopBar"
	topPillsBar.Size = UDim2.new(0, DEFAULT_W, 0, 36)
	topPillsBar.Position = UDim2.new(0, 14, 0, 10)
	topPillsBar.BackgroundTransparency = 1
	topPillsBar.BorderSizePixel = 0
	topPillsBar.Parent = screenGui

	local pillsLayout = Instance.new("UIListLayout")
	pillsLayout.FillDirection = Enum.FillDirection.Horizontal
	pillsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	pillsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	pillsLayout.Padding = UDim.new(0, 6)
	pillsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pillsLayout.Parent = topPillsBar

	-- 1. Roblox Logo Box
	local rbxBtn = Instance.new("ImageButton")
	rbxBtn.Name = "RobloxMenuBtn"
	rbxBtn.Size = UDim2.new(0, 36, 0, 34)
	rbxBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	rbxBtn.BackgroundTransparency = 0.15
	rbxBtn.BorderSizePixel = 0
	rbxBtn.Image = "rbxassetid://10888371919"
	rbxBtn.ScaleType = Enum.ScaleType.Fit
	rbxBtn.LayoutOrder = 1
	rbxBtn.Parent = topPillsBar

	local rbxCorner = Instance.new("UICorner")
	rbxCorner.CornerRadius = UDim.new(0, 8)
	rbxCorner.Parent = rbxBtn

	local rbxStroke = Instance.new("UIStroke")
	rbxStroke.Color = Color3.fromRGB(60, 60, 70)
	rbxStroke.Thickness = 1.2
	rbxStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rbxStroke.Parent = rbxBtn

	rbxBtn.MouseButton1Click:Connect(function()
		pcall(function()
			GuiService:SetMenuIsOpen(true)
		end)
	end)

	-- 2. Combined Menu (≡) & Voice Chat Mic Pill
	local menuVoicePill = Instance.new("Frame")
	menuVoicePill.Name = "MenuVoicePill"
	menuVoicePill.Size = UDim2.new(0, 78, 0, 34)
	menuVoicePill.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	menuVoicePill.BackgroundTransparency = 0.15
	menuVoicePill.BorderSizePixel = 0
	menuVoicePill.LayoutOrder = 2
	menuVoicePill.Parent = topPillsBar

	local mvCorner = Instance.new("UICorner")
	mvCorner.CornerRadius = UDim.new(0, 8)
	mvCorner.Parent = menuVoicePill

	local mvStroke = Instance.new("UIStroke")
	mvStroke.Color = Color3.fromRGB(60, 60, 70)
	mvStroke.Thickness = 1.2
	mvStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	mvStroke.Parent = menuVoicePill

	-- Left: Hamburger Menu (≡)
	local menuBtn = Instance.new("TextButton")
	menuBtn.Name = "HamburgerMenuBtn"
	menuBtn.Size = UDim2.new(0.5, -1, 1, 0)
	menuBtn.Position = UDim2.new(0, 0, 0, 0)
	menuBtn.BackgroundTransparency = 1
	menuBtn.Text = "≡"
	menuBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
	menuBtn.Font = Enum.Font.GothamBold
	menuBtn.TextSize = 18
	menuBtn.Parent = menuVoicePill

	-- Center Divider
	local div = Instance.new("Frame")
	div.Name = "Divider"
	div.Size = UDim2.new(0, 1, 0.6, 0)
	div.Position = UDim2.new(0.5, 0, 0.2, 0)
	div.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	div.BorderSizePixel = 0
	div.Parent = menuVoicePill

	-- Right: Voice Chat Mic Toggle
	local micBtn = Instance.new("ImageButton")
	micBtn.Name = "VoiceChatMicBtn"
	micBtn.Size = UDim2.new(0.5, -1, 1, 0)
	micBtn.Position = UDim2.new(0.5, 1, 0, 0)
	micBtn.BackgroundTransparency = 1
	micBtn.Image = "rbxassetid://7072720970"
	micBtn.ImageColor3 = Color3.fromRGB(245, 70, 70)
	micBtn.ScaleType = Enum.ScaleType.Fit
	micBtn.Parent = menuVoicePill

	local isMuted = true
	micBtn.MouseButton1Click:Connect(function()
		isMuted = not isMuted
		if isMuted then
			micBtn.ImageColor3 = Color3.fromRGB(245, 70, 70)
		else
			micBtn.ImageColor3 = Color3.fromRGB(60, 225, 90)
		end
		pcall(function()
			if VoiceChatService and VoiceChatService:IsVoiceEnabledForUserIdAsync(Players.LocalPlayer.UserId) then
				VoiceChatService:joinVoice()
			end
		end)
	end)

	-- Hamburger Menu Click -> Toggle Main Window
	menuBtn.MouseButton1Click:Connect(function()
		if _G.__ToggleProjectFihMenu then
			_G.__ToggleProjectFihMenu()
		end
	end)

	-- 3. [ Hide UI ] Pill Button
	local hideUiBtn = Instance.new("TextButton")
	hideUiBtn.Name = "HideUiPill"
	hideUiBtn.Size = UDim2.new(0, 76, 0, 34)
	hideUiBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	hideUiBtn.BackgroundTransparency = 0.15
	hideUiBtn.BorderSizePixel = 0
	hideUiBtn.Text = "Hide UI"
	hideUiBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
	hideUiBtn.Font = Enum.Font.GothamBold
	hideUiBtn.TextSize = 11
	hideUiBtn.LayoutOrder = 3
	hideUiBtn.Parent = topPillsBar

	local hideCorner = Instance.new("UICorner")
	hideCorner.CornerRadius = UDim.new(0, 17)
	hideCorner.Parent = hideUiBtn

	local hideStroke = Instance.new("UIStroke")
	hideStroke.Color = Color3.fromRGB(60, 60, 70)
	hideStroke.Thickness = 1.2
	hideStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	hideStroke.Parent = hideUiBtn

	local allUiHidden = false
	hideUiBtn.MouseButton1Click:Connect(function()
		allUiHidden = not allUiHidden
		hideUiBtn.Text = if allUiHidden then "Show UI" else "Hide UI"
		hideUiBtn.TextColor3 = if allUiHidden then UI.Theme.Accent else Color3.fromRGB(240, 240, 245)
		
		-- Toggle GUI visibility
		for _, name in ipairs({"ModularEngineGui", "ModularPlayerListGui", "ModularMusicTrackerGui"}) do
			for _, g in ipairs(CoreGui:GetChildren()) do
				if g.Name == name then
					g.Enabled = not allUiHidden
				end
			end
		end
	end)

	-- 4. [ 🎒 ] Backpack Pill Button
	local bpBtn = Instance.new("ImageButton")
	bpBtn.Name = "BackpackPill"
	bpBtn.Size = UDim2.new(0, 36, 0, 34)
	bpBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
	bpBtn.BackgroundTransparency = 0.15
	bpBtn.BorderSizePixel = 0
	bpBtn.Image = "rbxassetid://7072717697"
	bpBtn.ImageColor3 = Color3.fromRGB(200, 200, 210)
	bpBtn.ScaleType = Enum.ScaleType.Fit
	bpBtn.LayoutOrder = 4
	bpBtn.Parent = topPillsBar

	local bpCorner = Instance.new("UICorner")
	bpCorner.CornerRadius = UDim.new(0, 17)
	bpCorner.Parent = bpBtn

	local bpStroke = Instance.new("UIStroke")
	bpStroke.Color = Color3.fromRGB(60, 60, 70)
	bpStroke.Thickness = 1.2
	bpStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bpStroke.Parent = bpBtn

	local bpActive = false
	bpBtn.MouseButton1Click:Connect(function()
		bpActive = not bpActive
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, bpActive)
		end)
	end)

	-- Hover effects on pills
	local function addPillHover(btn: GuiButton, stroke: UIStroke)
		btn.MouseEnter:Connect(function()
			TweenService:Create(stroke, TweenInfo.new(0.12), { Thickness = 1.8, Color = UI.Theme.Accent }):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(stroke, TweenInfo.new(0.12), { Thickness = 1.2, Color = Color3.fromRGB(60, 60, 70) }):Play()
		end)
	end

	addPillHover(rbxBtn, rbxStroke)
	addPillHover(menuBtn, mvStroke)
	addPillHover(micBtn, mvStroke)
	addPillHover(hideUiBtn, hideStroke)
	addPillHover(bpBtn, bpStroke)

	-- ============================================================
	-- ── CHAT WIDGET FRAME (DIRECTLY UNDER TOPBAR) ───────────────
	-- ============================================================
	local widget = Instance.new("Frame")
	widget.Name = "ChatWidget"
	widget.Size = UDim2.new(0, DEFAULT_W, 0, DEFAULT_H)
	widget.Position = UDim2.new(0, 14, 0, 50)
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

	-- Minimize / Close Buttons
	local minBtn = Instance.new("TextButton")
	minBtn.Name = "MinBtn"
	minBtn.Size = UDim2.new(0, 20, 0, 18)
	minBtn.Position = UDim2.new(1, -50, 0, 5)
	minBtn.BackgroundColor3 = UI.Theme.ContainerDark
	minBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	minBtn.BorderSizePixel = 0
	minBtn.Text = "-"
	minBtn.TextColor3 = UI.Theme.TextPrimary
	minBtn.Font = UI.Fonts.Mono
	minBtn.TextSize = 13
	minBtn.Parent = topbar
	UI.registerThemeElement(minBtn, "ContainerDark")

	local minStroke = Instance.new("UIStroke")
	minStroke.Color = UI.Theme.Border
	minStroke.Thickness = 1
	minStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	minStroke.Parent = minBtn
	UI.registerThemeElement(minStroke, "Border")

	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseBtn"
	closeBtn.Size = UDim2.new(0, 20, 0, 18)
	closeBtn.Position = UDim2.new(1, -26, 0, 5)
	closeBtn.BackgroundColor3 = UI.Theme.ContainerDark
	closeBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	closeBtn.BorderSizePixel = 0
	closeBtn.Text = "X"
	closeBtn.TextColor3 = UI.Theme.TextPrimary
	closeBtn.Font = UI.Fonts.Mono
	closeBtn.TextSize = 11
	closeBtn.Parent = topbar
	UI.registerThemeElement(closeBtn, "ContainerDark")

	local closeStroke = Instance.new("UIStroke")
	closeStroke.Color = UI.Theme.Border
	closeStroke.Thickness = 1
	closeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	closeStroke.Parent = closeBtn
	UI.registerThemeElement(closeStroke, "Border")

	-- ── Message Container ─────────────────────────────────────────────
	local container = Instance.new("ScrollingFrame")
	container.Name = "MessageContainer"
	container.Size = UDim2.new(1, -12, 1, -(TOPBAR_H + BOTTOM_H + 16))
	container.Position = UDim2.new(0, 6, 0, TOPBAR_H + 6)
	container.BackgroundColor3 = UI.Theme.Container
	container.BackgroundTransparency = UI.Theme.ContainerTransparency
	container.BorderSizePixel = 0
	container.ScrollBarThickness = 3
	container.ScrollBarImageColor3 = UI.Theme.Border
	container.CanvasSize = UDim2.new(0, 0, 0, 0)
	container.AutomaticCanvasSize = Enum.AutomaticSize.Y
	container.Parent = widget
	UI.registerThemeElement(container, "Container")

	local containerStroke = Instance.new("UIStroke")
	containerStroke.Color = UI.Theme.Border
	containerStroke.Thickness = 1
	containerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	containerStroke.Parent = container
	UI.registerThemeElement(containerStroke, "Border")

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 4)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = container

	-- ── Bottom Control Bar ────────────────────────────────────────────
	local bottomBar = Instance.new("Frame")
	bottomBar.Name = "BottomBar"
	bottomBar.Size = UDim2.new(1, -12, 0, BOTTOM_H)
	bottomBar.Position = UDim2.new(0, 6, 1, -(BOTTOM_H + 6))
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

	local quickStroke = Instance.new("UIStroke")
	quickStroke.Color = UI.Theme.Border
	quickStroke.Thickness = 1
	quickStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	quickStroke.Parent = quickBtn
	UI.registerThemeElement(quickStroke, "Border")

	local inputFrame = Instance.new("Frame")
	inputFrame.Name = "InputFrame"
	inputFrame.Size = UDim2.new(1, -134, 1, 0)
	inputFrame.Position = UDim2.new(0, 68, 0, 0)
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
	textBox.Size = UDim2.new(1, -8, 1, 0)
	textBox.Position = UDim2.new(0, 4, 0, 0)
	textBox.BackgroundTransparency = 1
	textBox.PlaceholderText = "/Text Message"
	textBox.PlaceholderColor3 = UI.Theme.TextMuted
	textBox.Text = ""
	textBox.TextColor3 = UI.Theme.TextPrimary
	textBox.Font = UI.Fonts.Body
	textBox.TextSize = 11
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
	UI.registerThemeElement(sendBtn, "Accent")

	local sendStroke = Instance.new("UIStroke")
	sendStroke.Color = UI.Theme.Border
	sendStroke.Thickness = 1
	sendStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	sendStroke.Parent = sendBtn
	UI.registerThemeElement(sendStroke, "Border")

	-- ── Message Line Constructor ──────────────────────────────────────
	local function addMessage(sender: string, text: string)
		local isSystem = (sender == "System")
		local row = Instance.new("Frame")
		row.Name = "MessageRow"
		row.Size = UDim2.new(1, 0, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Parent = container

		local senderLabel = Instance.new("TextLabel")
		senderLabel.Name = "Sender"
		senderLabel.Size = UDim2.new(0, 75, 0, 14)
		senderLabel.Position = UDim2.new(0, 4, 0, 1)
		senderLabel.BackgroundTransparency = 1
		senderLabel.Text = sender .. ":"
		senderLabel.TextColor3 = if isSystem then UI.Theme.TextMuted else UI.Theme.Accent
		senderLabel.Font = UI.Fonts.Header
		senderLabel.TextSize = 10
		senderLabel.TextXAlignment = Enum.TextXAlignment.Left
		senderLabel.TextTruncate = Enum.TextTruncate.AtEnd
		senderLabel.Parent = row

		local textLabel = Instance.new("TextLabel")
		textLabel.Name = "Content"
		textLabel.Size = UDim2.new(1, -85, 0, 0)
		textLabel.Position = UDim2.new(0, 82, 0, 1)
		textLabel.AutomaticSize = Enum.AutomaticSize.Y
		textLabel.BackgroundTransparency = 1
		textLabel.Text = text
		textLabel.TextColor3 = UI.Theme.TextPrimary
		textLabel.Font = UI.Fonts.Body
		textLabel.TextSize = 10
		textLabel.TextXAlignment = Enum.TextXAlignment.Left
		textLabel.TextWrapped = true
		textLabel.Parent = row
		UI.registerThemeElement(textLabel, "TextPrimary")

		task.defer(function()
			container.CanvasPosition = Vector2.new(0, math.max(0, container.AbsoluteCanvasSize.Y - container.AbsoluteWindowSize.Y))
		end)
	end

	-- ── Dragging & Resize Handlers ────────────────────────────────────
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
			local vpSize = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
			local targetX = math.clamp(startAbsPos.X + delta.X, 0, math.max(0, vpSize.X - widget.AbsoluteSize.X))
			local targetY = math.clamp(startAbsPos.Y + delta.Y, 0, math.max(0, vpSize.Y - widget.AbsoluteSize.Y))
			widget.Position = UDim2.new(0, targetX, 0, targetY)
		end
	end)

	local minimized = false
	minBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		if minimized then
			container.Visible = false
			bottomBar.Visible = false
			TweenService:Create(widget, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, widget.AbsoluteSize.X, 0, TOPBAR_H)
			}):Play()
		else
			container.Visible = true
			bottomBar.Visible = true
			TweenService:Create(widget, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
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

	-- ── Message Sending Logic ─────────────────────────────────────────
	local isSending = false
	local function sendMessage(msg: string)
		if isSending or not msg or msg == "" then return end
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

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Slash then
			widget.Visible = true
			task.defer(function()
				textBox:CaptureFocus()
			end)
		end
	end)

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
		TopBarPills = topPillsBar,
		Container = container,
		InputBox = textBox,
		SendBtn = sendBtn,
		QuickBtn = quickBtn,
		IsMinimized = false,
		Visible = true
	}
end

return ChatWidget
