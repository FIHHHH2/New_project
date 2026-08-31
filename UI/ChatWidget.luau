--!strict
--[=[
    ✦ Squared Retro Chat Widget with Scaling Grip & Player Profile Action Popup ✦
    Features:
    - Corner resize grip: smooth scaling from 260x180 to 800x600
    - Player Name Click: opens sleek Player Profile & Action Popup (Teleport, Spectate, Friend, Block, Report, Copy ID)
    - Full IgnoreGuiInset dragging
    - RichText seamless message flow
    - Action Header: [ ⯎ ] Roblox Menu, [ ≡ ] Hamburger Dropdown, [ 🎙 ] VoiceChat Mic Toggle
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
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	pcall(function() screenGui.Parent = CoreGui end)
	if not screenGui.Parent then
		screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end

	-- Disable default Roblox CoreGuis cleanly
	local function disableRobloxCoreGuis()
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)
		end)
	end
	disableRobloxCoreGuis()

	-- Detect chat engine
	local useLegacyChat = false
	pcall(function()
		useLegacyChat = (TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService)
	end)

	local DEFAULT_W, DEFAULT_H = 340, 260
	local TOPBAR_H = 28
	local BOTTOM_H = 28

	-- ── Main Unified Widget Frame ─────────────────────────────────────
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

	-- ============================================================
	-- ── TOPBAR: HEADER (AVATAR, TITLE, ACTIONS, [-] & [X]) ──────
	-- ============================================================
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

	-- Avatar Thumbnail
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

	-- Title: Chat : @Username
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(0, 115, 1, 0)
	titleLabel.Position = UDim2.new(0, 29, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = string.format("Chat : @%s", Players.LocalPlayer.Name)
	titleLabel.TextColor3 = UI.Theme.TextPrimary
	titleLabel.Font = UI.Fonts.Header
	titleLabel.TextSize = 10
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.Parent = topbar
	UI.registerThemeElement(titleLabel, "TextPrimary")

	-- ── Center Action Buttons: [ ⯎ ] [ ≡ ] [ 🎙 ] ─────────────────────
	local actionGroup = Instance.new("Frame")
	actionGroup.Name = "TopBarActions"
	actionGroup.Size = UDim2.new(0, 84, 0, 22)
	actionGroup.Position = UDim2.new(0, 148, 0, 3)
	actionGroup.BackgroundTransparency = 1
	actionGroup.BorderSizePixel = 0
	actionGroup.Parent = topbar

	local actLayout = Instance.new("UIListLayout")
	actLayout.FillDirection = Enum.FillDirection.Horizontal
	actLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	actLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	actLayout.Padding = UDim.new(0, 4)
	actLayout.SortOrder = Enum.SortOrder.LayoutOrder
	actLayout.Parent = actionGroup

	-- 1. Roblox Menu Button [ ⯎ ]
	local rbxBtn = Instance.new("ImageButton")
	rbxBtn.Name = "RobloxLogoBtn"
	rbxBtn.Size = UDim2.new(0, 24, 0, 22)
	rbxBtn.BackgroundColor3 = UI.Theme.ContainerDark
	rbxBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	rbxBtn.BorderSizePixel = 0
	rbxBtn.Image = "rbxasset://textures/ui/TopBar/icon_roblox.png"
	rbxBtn.ScaleType = Enum.ScaleType.Fit
	rbxBtn.LayoutOrder = 1
	rbxBtn.Parent = actionGroup
	UI.registerThemeElement(rbxBtn, "ContainerDark")

	local rbxStroke = Instance.new("UIStroke")
	rbxStroke.Color = UI.Theme.Border
	rbxStroke.Thickness = 1
	rbxStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rbxStroke.Parent = rbxBtn
	UI.registerThemeElement(rbxStroke, "Border")

	rbxBtn.MouseEnter:Connect(function()
		TweenService:Create(rbxStroke, TweenInfo.new(0.12), { Thickness = 1.6, Color = UI.Theme.Accent }):Play()
	end)
	rbxBtn.MouseLeave:Connect(function()
		TweenService:Create(rbxStroke, TweenInfo.new(0.12), { Thickness = 1, Color = UI.Theme.Border }):Play()
	end)

	rbxBtn.MouseButton1Click:Connect(function()
		local vim = pcall(function() return game:GetService("VirtualInputManager") end) and game:GetService("VirtualInputManager") or nil
		if vim then
			pcall(function()
				vim:SendKeyEvent(true, Enum.KeyCode.Escape, false, game)
				task.delay(0.05, function()
					vim:SendKeyEvent(false, Enum.KeyCode.Escape, false, game)
				end)
			end)
		else
			pcall(function()
				GuiService:SetMenuIsOpen(not GuiService.MenuIsOpen)
			end)
		end
	end)

	-- 2. Hamburger Menu Button [ ≡ ]
	local menuBtn = Instance.new("TextButton")
	menuBtn.Name = "HamburgerBtn"
	menuBtn.Size = UDim2.new(0, 24, 0, 22)
	menuBtn.BackgroundColor3 = UI.Theme.ContainerDark
	menuBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	menuBtn.BorderSizePixel = 0
	menuBtn.Text = "≡"
	menuBtn.TextColor3 = UI.Theme.TextPrimary
	menuBtn.Font = Enum.Font.GothamBold
	menuBtn.TextSize = 16
	menuBtn.LayoutOrder = 2
	menuBtn.Parent = actionGroup
	UI.registerThemeElement(menuBtn, "ContainerDark")
	UI.registerThemeElement(menuBtn, "TextPrimary")

	local menuStroke = Instance.new("UIStroke")
	menuStroke.Color = UI.Theme.Border
	menuStroke.Thickness = 1
	menuStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	menuStroke.Parent = menuBtn
	UI.registerThemeElement(menuStroke, "Border")

	menuBtn.MouseEnter:Connect(function()
		TweenService:Create(menuStroke, TweenInfo.new(0.12), { Thickness = 1.6, Color = UI.Theme.Accent }):Play()
		TweenService:Create(menuBtn, TweenInfo.new(0.12), { TextColor3 = UI.Theme.Accent }):Play()
	end)
	menuBtn.MouseLeave:Connect(function()
		TweenService:Create(menuStroke, TweenInfo.new(0.12), { Thickness = 1, Color = UI.Theme.Border }):Play()
		TweenService:Create(menuBtn, TweenInfo.new(0.12), { TextColor3 = UI.Theme.TextPrimary }):Play()
	end)

	-- 3. Voice Chat Mic Button [ 🎙 ]
	local micBtn = Instance.new("TextButton")
	micBtn.Name = "VoiceChatMicBtn"
	micBtn.Size = UDim2.new(0, 24, 0, 22)
	micBtn.BackgroundColor3 = UI.Theme.ContainerDark
	micBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	micBtn.BorderSizePixel = 0
	micBtn.Text = "MIC"
	micBtn.TextColor3 = Color3.fromRGB(245, 75, 75)
	micBtn.Font = Enum.Font.GothamBold
	micBtn.TextSize = 8
	micBtn.LayoutOrder = 3
	micBtn.Parent = actionGroup
	UI.registerThemeElement(micBtn, "ContainerDark")

	local micStroke = Instance.new("UIStroke")
	micStroke.Color = UI.Theme.Border
	micStroke.Thickness = 1
	micStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	micStroke.Parent = micBtn
	UI.registerThemeElement(micStroke, "Border")

	local isMuted = true
	micBtn.MouseButton1Click:Connect(function()
		isMuted = not isMuted
		if isMuted then
			micBtn.Text = "MIC"
			micBtn.TextColor3 = Color3.fromRGB(245, 75, 75)
		else
			micBtn.Text = "ON"
			micBtn.TextColor3 = Color3.fromRGB(60, 225, 90)
		end
		pcall(function()
			if VoiceChatService and VoiceChatService:IsVoiceEnabledForUserIdAsync(Players.LocalPlayer.UserId) then
				VoiceChatService:joinVoice()
			end
		end)
	end)

	-- ============================================================
	-- ── HAMBURGER DROPDOWN QUICK MENU ───────────────────────────
	-- ============================================================
	local dropdown = Instance.new("Frame")
	dropdown.Name = "HamburgerDropdown"
	dropdown.Size = UDim2.new(0, 150, 0, 170)
	dropdown.Position = UDim2.new(0, 110, 0, TOPBAR_H + 4)
	dropdown.BackgroundColor3 = UI.Theme.Background
	dropdown.BackgroundTransparency = 0.05
	dropdown.BorderSizePixel = 0
	dropdown.Visible = false
	dropdown.ZIndex = 50
	dropdown.Parent = widget
	UI.registerThemeElement(dropdown, "Background")

	local dropStroke = Instance.new("UIStroke")
	dropStroke.Color = UI.Theme.Border
	dropStroke.Thickness = 1.2
	dropStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	dropStroke.Parent = dropdown
	UI.registerThemeElement(dropStroke, "Border")

	local dropLayout = Instance.new("UIListLayout")
	dropLayout.FillDirection = Enum.FillDirection.Vertical
	dropLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dropLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	dropLayout.Padding = UDim.new(0, 2)
	dropLayout.Parent = dropdown

	local bpActive = false
	local function createDropItem(text: string, onClick: () -> ())
		local item = Instance.new("TextButton")
		item.Size = UDim2.new(1, -6, 0, 25)
		item.BackgroundColor3 = UI.Theme.ContainerDark
		item.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
		item.BorderSizePixel = 0
		item.Text = "  " .. text
		item.TextColor3 = UI.Theme.TextPrimary
		item.Font = UI.Fonts.Header
		item.TextSize = 10
		item.TextXAlignment = Enum.TextXAlignment.Left
		item.ZIndex = 51
		item.Parent = dropdown
		UI.registerThemeElement(item, "ContainerDark")
		UI.registerThemeElement(item, "TextPrimary")

		item.MouseEnter:Connect(function()
			TweenService:Create(item, TweenInfo.new(0.1), { BackgroundColor3 = UI.Theme.Accent, TextColor3 = UI.Theme.AccentText }):Play()
		end)
		item.MouseLeave:Connect(function()
			TweenService:Create(item, TweenInfo.new(0.1), { BackgroundColor3 = UI.Theme.ContainerDark, TextColor3 = UI.Theme.TextPrimary }):Play()
		end)

		item.MouseButton1Click:Connect(function()
			dropdown.Visible = false
			onClick()
		end)
	end

	createDropItem("Backpack", function()
		bpActive = not bpActive
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, bpActive)
		end)
	end)

	createDropItem("Music Tracker", function()
		for _, g in ipairs(CoreGui:GetChildren()) do
			if g.Name == "ModularMusicTrackerGui" then
				local w = g:FindFirstChild("MusicTrackerWidget")
				if w and w:IsA("Frame") then
					w.Visible = not w.Visible
				end
			end
		end
	end)

	createDropItem("Player List", function()
		for _, g in ipairs(CoreGui:GetChildren()) do
			if g.Name == "ModularPlayerListGui" then
				local w = g:FindFirstChild("PlayerListFrame")
				if w and w:IsA("Frame") then
					w.Visible = not w.Visible
				end
			end
		end
	end)

	createDropItem("Main Menu", function()
		if _G.__ToggleProjectFihMenu then
			_G.__ToggleProjectFihMenu()
		end
	end)

	createDropItem("Reset Character", function()
		local char = Players.LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then hum.Health = 0 end
	end)

	createDropItem("Leave Game", function()
		pcall(function()
			game:Shutdown()
		end)
	end)

	menuBtn.MouseButton1Click:Connect(function()
		dropdown.Visible = not dropdown.Visible
	end)

	-- Right: Minimize [-] & Close [X] Buttons
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

	-- ============================================================
	-- ── MESSAGE CONTAINER (CHAT LOGS) ───────────────────────────
	-- ============================================================
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
	listLayout.Padding = UDim.new(0, 3)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = container

	-- ============================================================
	-- ── BOTTOM CONTROL BAR (INPUT, QUICK CHAT, SEND MSG) ────────
	-- ============================================================
	local bottomBar = Instance.new("Frame")
	bottomBar.Name = "BottomBar"
	bottomBar.Size = UDim2.new(1, -12, 0, BOTTOM_H)
	bottomBar.Position = UDim2.new(0, 6, 1, -(BOTTOM_H + 6))
	bottomBar.BackgroundTransparency = 1
	bottomBar.BorderSizePixel = 0
	bottomBar.ZIndex = 5
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
	quickBtn.ZIndex = 6
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
	inputFrame.ZIndex = 6
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
	textBox.PlaceholderColor3 = UI.Theme.TextSecondary
	textBox.Text = ""
	textBox.TextColor3 = UI.Theme.TextPrimary
	textBox.Font = UI.Fonts.Body
	textBox.TextSize = 11
	textBox.TextXAlignment = Enum.TextXAlignment.Left
	textBox.ClearTextOnFocus = false
	textBox.ZIndex = 7
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
	sendBtn.TextSize = 10
	sendBtn.ZIndex = 7
	sendBtn.Parent = bottomBar
	UI.registerThemeElement(sendBtn, "Accent")

	local sendStroke = Instance.new("UIStroke")
	sendStroke.Color = UI.Theme.Border
	sendStroke.Thickness = 1.2
	sendStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	sendStroke.Parent = sendBtn
	UI.registerThemeElement(sendStroke, "Border")

	-- ============================================================
	-- ── CORNER RESIZE GRIP (SCALE CHATBAR ANY SIZE) ─────────────
	-- ============================================================
	local resizeGrip = Instance.new("TextButton")
	resizeGrip.Name = "ResizeGrip"
	resizeGrip.Size = UDim2.new(0, 14, 0, 14)
	resizeGrip.Position = UDim2.new(1, -14, 1, -14)
	resizeGrip.BackgroundTransparency = 1
	resizeGrip.Text = "///"
	resizeGrip.TextColor3 = UI.Theme.BorderDim
	resizeGrip.Font = UI.Fonts.Mono
	resizeGrip.TextSize = 9
	resizeGrip.ZIndex = 20
	resizeGrip.Parent = widget
	UI.registerThemeElement(resizeGrip, "BorderDimText")

	local isResizing = false
	local resizeStart = Vector2.zero
	local sizeStart = Vector2.zero

	resizeGrip.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isResizing = true
			resizeStart = Vector2.new(input.Position.X, input.Position.Y)
			sizeStart = Vector2.new(widget.AbsoluteSize.X, widget.AbsoluteSize.Y)
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					isResizing = false
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if isResizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - resizeStart
			local newW = math.clamp(sizeStart.X + delta.X, 260, 800)
			local newH = math.clamp(sizeStart.Y + delta.Y, 180, 600)
			widget.Size = UDim2.new(0, newW, 0, newH)
		end
	end)

	-- ============================================================
	-- ── PLAYER ACTION CONTEXT MENU POPUP ────────────────────────
	-- ============================================================
	local profilePopup = Instance.new("Frame")
	profilePopup.Name = "PlayerProfilePopup"
	profilePopup.Size = UDim2.new(0, 190, 0, 240)
	profilePopup.Position = UDim2.new(0, 20, 0, 35)
	profilePopup.BackgroundColor3 = UI.Theme.Background
	profilePopup.BackgroundTransparency = 0.02
	profilePopup.BorderSizePixel = 0
	profilePopup.Visible = false
	profilePopup.ZIndex = 80
	profilePopup.Parent = screenGui
	UI.registerThemeElement(profilePopup, "Background")

	local popStroke = Instance.new("UIStroke")
	popStroke.Color = UI.Theme.Border
	popStroke.Thickness = 1.5
	popStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	popStroke.Parent = profilePopup
	UI.registerThemeElement(popStroke, "Border")

	local popHeader = Instance.new("Frame")
	popHeader.Size = UDim2.new(1, 0, 0, 48)
	popHeader.BackgroundColor3 = UI.Theme.Container
	popHeader.BackgroundTransparency = UI.Theme.ContainerTransparency
	popHeader.BorderSizePixel = 0
	popHeader.ZIndex = 81
	popHeader.Parent = profilePopup
	UI.registerThemeElement(popHeader, "Container")

	local popHeadStroke = Instance.new("UIStroke")
	popHeadStroke.Color = UI.Theme.Border
	popHeadStroke.Thickness = 1
	popHeadStroke.Parent = popHeader
	UI.registerThemeElement(popHeadStroke, "Border")

	local popAvatar = Instance.new("ImageLabel")
	popAvatar.Size = UDim2.new(0, 36, 0, 36)
	popAvatar.Position = UDim2.new(0, 6, 0, 6)
	popAvatar.BackgroundTransparency = 1
	popAvatar.ZIndex = 82
	popAvatar.Parent = popHeader

	local popTitle = Instance.new("TextLabel")
	popTitle.Size = UDim2.new(1, -50, 0, 18)
	popTitle.Position = UDim2.new(0, 46, 0, 6)
	popTitle.BackgroundTransparency = 1
	popTitle.Text = "Player"
	popTitle.TextColor3 = UI.Theme.TextPrimary
	popTitle.Font = UI.Fonts.Header
	popTitle.TextSize = 11
	popTitle.TextXAlignment = Enum.TextXAlignment.Left
	popTitle.ZIndex = 82
	popTitle.Parent = popHeader
	UI.registerThemeElement(popTitle, "TextPrimary")

	local popUser = Instance.new("TextLabel")
	popUser.Size = UDim2.new(1, -50, 0, 14)
	popUser.Position = UDim2.new(0, 46, 0, 24)
	popUser.BackgroundTransparency = 1
	popUser.Text = "@Username"
	popUser.TextColor3 = UI.Theme.TextSecondary
	popUser.Font = UI.Fonts.Mono
	popUser.TextSize = 9
	popUser.TextXAlignment = Enum.TextXAlignment.Left
	popUser.ZIndex = 82
	popUser.Parent = popHeader
	UI.registerThemeElement(popUser, "TextSecondary")

	local popClose = Instance.new("TextButton")
	popClose.Size = UDim2.new(0, 18, 0, 18)
	popClose.Position = UDim2.new(1, -22, 0, 6)
	popClose.BackgroundTransparency = 1
	popClose.Text = "X"
	popClose.TextColor3 = UI.Theme.TextPrimary
	popClose.Font = UI.Fonts.Mono
	popClose.TextSize = 10
	popClose.ZIndex = 83
	popClose.Parent = popHeader

	popClose.MouseButton1Click:Connect(function()
		profilePopup.Visible = false
	end)

	local popBtnsFrame = Instance.new("Frame")
	popBtnsFrame.Size = UDim2.new(1, -8, 1, -54)
	popBtnsFrame.Position = UDim2.new(0, 4, 0, 52)
	popBtnsFrame.BackgroundTransparency = 1
	popBtnsFrame.ZIndex = 81
	popBtnsFrame.Parent = profilePopup

	local popLayout = Instance.new("UIListLayout")
	popLayout.Padding = UDim.new(0, 3)
	popLayout.SortOrder = Enum.SortOrder.LayoutOrder
	popLayout.Parent = popBtnsFrame

	local activeSelectedPlayer: Player? = nil
	local function createPopAction(text: string, order: number, onClick: (Player) -> ())
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, 22)
		btn.BackgroundColor3 = UI.Theme.ContainerDark
		btn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
		btn.BorderSizePixel = 0
		btn.Text = "  " .. text
		btn.TextColor3 = UI.Theme.TextPrimary
		btn.Font = UI.Fonts.Body
		btn.TextSize = 10
		btn.TextXAlignment = Enum.TextXAlignment.Left
		btn.LayoutOrder = order
		btn.ZIndex = 82
		btn.Parent = popBtnsFrame
		UI.registerThemeElement(btn, "ContainerDark")
		UI.registerThemeElement(btn, "TextPrimary")

		local stroke = Instance.new("UIStroke")
		stroke.Color = UI.Theme.Border
		stroke.Thickness = 0.8
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = btn
		UI.registerThemeElement(stroke, "Border")

		btn.MouseEnter:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = UI.Theme.Accent, TextColor3 = UI.Theme.AccentText }):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.1), { BackgroundColor3 = UI.Theme.ContainerDark, TextColor3 = UI.Theme.TextPrimary }):Play()
		end)

		btn.MouseButton1Click:Connect(function()
			if activeSelectedPlayer then
				onClick(activeSelectedPlayer)
			end
			profilePopup.Visible = false
		end)
	end

	createPopAction("Teleport To", 1, function(target)
		local myChar = Players.LocalPlayer.Character
		local tChar = target.Character
		if myChar and tChar and myChar:FindFirstChild("HumanoidRootPart") and tChar:FindFirstChild("HumanoidRootPart") then
			myChar.HumanoidRootPart.CFrame = tChar.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
		end
	end)

	local isSpying = false
	createPopAction("Spectate / Spy", 2, function(target)
		isSpying = not isSpying
		local cam = workspace.CurrentCamera
		if isSpying and target.Character and target.Character:FindFirstChildOfClass("Humanoid") then
			cam.CameraSubject = target.Character:FindFirstChildOfClass("Humanoid")
		else
			if Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
				cam.CameraSubject = Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			end
			isSpying = false
		end
	end)

	createPopAction("Add Friend", 3, function(target)
		pcall(function()
			StarterGui:SetCore("PromptSendFriendRequest", target)
		end)
	end)

	createPopAction("Block Player", 4, function(target)
		pcall(function()
			StarterGui:SetCore("PromptBlockPlayer", target)
		end)
	end)

	createPopAction("Report Player", 5, function(target)
		pcall(function()
			StarterGui:SetCore("PromptReportPlayer", target)
		end)
	end)

	createPopAction("Copy Username", 6, function(target)
		local setclip = setclipboard or (getgenv and getgenv().setclipboard) or toclipboard
		if type(setclip) == "function" then
			setclip(target.Name)
		end
	end)

	local function openPlayerProfile(player: Player, clickPos: Vector2)
		activeSelectedPlayer = player
		popTitle.Text = player.DisplayName
		popUser.Text = "@" .. player.Name
		popAvatar.Image = Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size60x60)
		
		local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		local x = math.clamp(clickPos.X, 10, vp.X - 200)
		local y = math.clamp(clickPos.Y, 10, vp.Y - 250)
		profilePopup.Position = UDim2.new(0, x, 0, y)
		profilePopup.Visible = true
	end

	-- ── Message Line Constructor (Seamless RichText Flow + Profile Hook) ──
	local function addMessage(sender: string, text: string)
		local isSystem = (sender == "System")
		local targetPlayer: Player? = nil
		if not isSystem then
			for _, p in ipairs(Players:GetPlayers()) do
				if p.Name == sender or p.DisplayName == sender then
					targetPlayer = p
					break
				end
			end
		end

		local msgBtn = Instance.new("TextButton")
		msgBtn.Name = "MessageLine"
		msgBtn.Size = UDim2.new(1, -8, 0, 0)
		msgBtn.AutomaticSize = Enum.AutomaticSize.Y
		msgBtn.BackgroundTransparency = 1
		msgBtn.RichText = true
		msgBtn.TextWrapped = true
		msgBtn.Font = UI.Fonts.Body
		msgBtn.TextSize = 11
		msgBtn.TextXAlignment = Enum.TextXAlignment.Left
		msgBtn.TextColor3 = UI.Theme.TextPrimary
		msgBtn.Parent = container

		local senderHex = if isSystem then "#A0A0AA" else "#37AFF5"
		local cleanName = sender:gsub("<", "&lt;"):gsub(">", "&gt;")
		local cleanMsg = text:gsub("<", "&lt;"):gsub(">", "&gt;")
		msgBtn.Text = string.format("<font color='%s'><b>%s:</b></font> %s", senderHex, cleanName, cleanMsg)

		if targetPlayer then
			msgBtn.MouseButton1Click:Connect(function()
				local mousePos = UserInputService:GetMouseLocation()
				openPlayerProfile(targetPlayer :: Player, mousePos)
			end)
		end

		task.defer(function()
			container.CanvasPosition = Vector2.new(0, math.max(0, container.AbsoluteCanvasSize.Y - container.AbsoluteWindowSize.Y))
		end)
	end

	-- ── Dragging & Full-Screen Boundaries Handlers ────────────────────
	local dragging = false
	local dragInput: InputObject? = nil
	local dragStart = Vector3.zero
	local startAbsPos = Vector2.zero

	local function startDrag(input: InputObject)
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
	end

	topbar.InputBegan:Connect(startDrag)

	UserInputService.InputChanged:Connect(function(input)
		if (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and dragging then
			local delta = input.Position - dragStart
			local vpSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
			local targetX = math.clamp(startAbsPos.X + delta.X, 0, math.max(0, vpSize.X - widget.AbsoluteSize.X))
			local targetY = math.clamp(startAbsPos.Y + delta.Y, 0, math.max(0, vpSize.Y - widget.AbsoluteSize.Y))
			widget.Position = UDim2.new(0, targetX, 0, targetY)
		end
	end)

	local minimized = false
	minBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		dropdown.Visible = false
		if minimized then
			container.Visible = false
			bottomBar.Visible = false
			resizeGrip.Visible = false
			TweenService:Create(widget, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, widget.AbsoluteSize.X, 0, TOPBAR_H)
			}):Play()
		else
			container.Visible = true
			bottomBar.Visible = true
			resizeGrip.Visible = true
			TweenService:Create(widget, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, widget.AbsoluteSize.X, 0, DEFAULT_H)
			}):Play()
		end
	end)

	closeBtn.MouseButton1Click:Connect(function()
		dropdown.Visible = false
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

	-- Slash key opens & focuses chat input
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Slash then
			widget.Visible = true
			if minimized then
				minimized = false
				container.Visible = true
				bottomBar.Visible = true
				resizeGrip.Visible = true
				widget.Size = UDim2.new(0, widget.AbsoluteSize.X, 0, DEFAULT_H)
			end
			task.defer(function()
				textBox.Text = ""
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
				local name = if player then (player.DisplayName ~= "" and player.DisplayName or player.Name) else "Server"
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
