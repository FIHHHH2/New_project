local function destroyExistingGuis(name: string)
	local containers = {
		(type(gethui) == "function" and gethui()),
		CoreGui,
		CoreGui:FindFirstChild("RobloxGui"),
		(Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui"))
	}
	for _, c in ipairs(containers) do
		if c then
			for _, child in ipairs(c:GetChildren()) do
				if child.Name == name then
					pcall(function() child:Destroy() end)
				end
			end
		end
	end
end

--!strict
--[=[
    ✦ Squared Retro Player List Widget with Auto-Positioned Context Menu ✦
    Features:
    - Interactive player rows with hover FX and click-to-open context menu
    - Smart auto-positioning popup (anchors dynamically to the left or right of clicked row, clamped to viewport)
    - Full Roblox player actions: Profile view, Add/Unfriend, Block, Report/Inspect, Teleport, Fling, Spectate, Copy ID
    - Domino sliding animations and auto-scaling list height
]=]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local UI = require("UI/UI.luau")
local Animations = require("UI/Animations.luau")

local PlayerList = {}
PlayerList.__index = PlayerList

export type PlayerListWidget = {
	Frame: Frame,
	Container: ScrollingFrame,
	UiScale: UIScale,
	IsMinimized: boolean,
	Visible: boolean,
	IsOpen: () -> boolean,
	Open: (selfOrOnComplete: any, maybeOnComplete: any) -> (),
	Close: (selfOrOnComplete: any, maybeOnComplete: any) -> (),
	Toggle: (selfOrOnComplete: any, maybeOnComplete: any) -> (),
	SetVisible: (selfOrVal: any, maybeVal: any) -> (),
	OnClose: (() -> ())?,
	OnOpen: (() -> ())?,
	OnMinimize: ((isMin: boolean) -> ())?
}

local ROW_H = 38
local ROW_GAP = 4
local HEADER_H = 28
local POPUP_W = 220
local POPUP_H = 254

function PlayerList.new(): PlayerListWidget
	destroyExistingGuis("ModularPlayerListGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ModularPlayerListGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 600
	screenGui.IgnoreGuiInset = true
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
	widget.ClipsDescendants = false
	widget.Parent = screenGui
	UI.registerThemeElement(widget, "Background")

	local bgGradient = Instance.new("UIGradient")
	bgGradient.Rotation = 90
	bgGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 210))
	})
	bgGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0.15)
	})
	bgGradient.Parent = widget

	local outerStroke = Instance.new("UIStroke")
	outerStroke.Color = UI.Theme.Border
	outerStroke.Thickness = 2
	outerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outerStroke.Parent = widget
	UI.registerThemeElement(outerStroke, "Border")

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 1.0
	uiScale.Parent = widget

	-- ── Topbar (Drag Handle) ──────────────────────────────────────────
	local topbar = Instance.new("Frame")
	topbar.Name = "TopBar"
	topbar.Size = UDim2.new(1, -12, 0, HEADER_H)
	topbar.Position = UDim2.new(0, 6, 0, 6)
	topbar.BackgroundColor3 = UI.Theme.Container
	topbar.BackgroundTransparency = UI.Theme.ContainerTransparency
	topbar.BorderSizePixel = 0
	topbar.Parent = widget
	UI.registerThemeElement(topbar, "Container")

	local topGradient = Instance.new("UIGradient")
	topGradient.Rotation = 45
	topGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 220, 230))
	})
	topGradient.Parent = topbar

	local topStroke = Instance.new("UIStroke")
	topStroke.Color = UI.Theme.Border
	topStroke.Thickness = 1.5
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
	container.Size = UDim2.new(1, -12, 1, -(HEADER_H + 12))
	container.Position = UDim2.new(0, 6, 0, HEADER_H + 8)
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
	local startAbsPos = Vector2.zero

	-- Forward declare popup frame
	local popupFrame: Frame

	topbar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startAbsPos = widget.AbsolutePosition
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
			local targetX = math.clamp(startAbsPos.X + delta.X, 0, math.max(0, vpSize.X - widget.AbsoluteSize.X))
			local targetY = math.clamp(startAbsPos.Y + delta.Y, 0, math.max(0, vpSize.Y - widget.AbsoluteSize.Y))
			widget.Position = UDim2.new(0, targetX, 0, targetY)
			if popupFrame and popupFrame.Visible then
				if closeContextMenu then
					closeContextMenu()
				else
					popupFrame.Visible = false
				end
			end
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
	local isOpen = true
	local isTransitioning = false
	local isPopupOpen = false

	-- Forward declare closeContextMenu
	local closeContextMenu: () -> ()

	local widgetObj: any = nil

	local function openWidget(selfOrOnComplete: any, maybeOnComplete: any)
		local onComplete = if type(selfOrOnComplete) == "function" then selfOrOnComplete elseif type(maybeOnComplete) == "function" then maybeOnComplete else nil
		if isOpen or isTransitioning then return end
		isTransitioning = true
		Animations.openWindow(widget, uiScale, function()
			isOpen = true
			isTransitioning = false
			if widgetObj and widgetObj.OnOpen then
				pcall(widgetObj.OnOpen)
			end
			if onComplete then onComplete() end
		end)
	end

	local function closeWidget(selfOrOnComplete: any, maybeOnComplete: any)
		local onComplete = if type(selfOrOnComplete) == "function" then selfOrOnComplete elseif type(maybeOnComplete) == "function" then maybeOnComplete else nil
		if not isOpen or isTransitioning then return end
		isTransitioning = true
		if closeContextMenu then closeContextMenu() end
		Animations.closeWindow(widget, uiScale, function()
			isOpen = false
			isTransitioning = false
			if widgetObj and widgetObj.OnClose then
				pcall(widgetObj.OnClose)
			end
			if onComplete then onComplete() end
		end)
	end

	local function toggleWidget(selfOrOnComplete: any, maybeOnComplete: any)
		local onComplete = if type(selfOrOnComplete) == "function" then selfOrOnComplete elseif type(maybeOnComplete) == "function" then maybeOnComplete else nil
		if isOpen then
			closeWidget(onComplete)
		else
			openWidget(onComplete)
		end
	end

	local function setWidgetVisible(selfOrVal: any, maybeVal: any)
		local v = if type(selfOrVal) == "boolean" then selfOrVal elseif type(maybeVal) == "boolean" then maybeVal else true
		if v then
			openWidget()
		else
			closeWidget()
		end
	end

	minBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		if closeContextMenu then closeContextMenu() end
		if minimized then
			container.Visible = false
			TweenService:Create(widget, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, widget.AbsoluteSize.X, 0, HEADER_H)
			}):Play()
		else
			container.Visible = true
			updateWidgetHeight()
		end
		if widgetObj and widgetObj.OnMinimize then
			pcall(function() widgetObj.OnMinimize(minimized) end)
		end
	end)

	closeBtn.MouseButton1Click:Connect(function()
		closeWidget()
	end)

	-- ── Floating Player Context Menu Popup ───────────────────────────
	popupFrame = Instance.new("Frame")
	popupFrame.Name = "PlayerContextMenu"
	popupFrame.Size = UDim2.new(0, POPUP_W, 0, POPUP_H)
	popupFrame.BackgroundColor3 = UI.Theme.Background
	popupFrame.BackgroundTransparency = UI.Theme.BackgroundTransparency
	popupFrame.BorderSizePixel = 0
	popupFrame.Visible = false
	popupFrame.ZIndex = 100
	popupFrame.Parent = screenGui
	UI.registerThemeElement(popupFrame, "Background")

	local popupBgGrad = Instance.new("UIGradient")
	popupBgGrad.Rotation = 90
	popupBgGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 210))
	})
	popupBgGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0.15)
	})
	popupBgGrad.Parent = popupFrame

	local popupStroke = Instance.new("UIStroke")
	popupStroke.Color = UI.Theme.Border
	popupStroke.Thickness = 2
	popupStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	popupStroke.Parent = popupFrame
	UI.registerThemeElement(popupStroke, "Border")

	local popupScale = Instance.new("UIScale")
	popupScale.Scale = 1.0
	popupScale.Parent = popupFrame

	-- Popup Header with Avatar & Details
	local pHeader = Instance.new("Frame")
	pHeader.Name = "PopupHeader"
	pHeader.Size = UDim2.new(1, 0, 0, 52)
	pHeader.BackgroundColor3 = UI.Theme.Container
	pHeader.BackgroundTransparency = UI.Theme.ContainerTransparency
	pHeader.BorderSizePixel = 0
	pHeader.Parent = popupFrame
	UI.registerThemeElement(pHeader, "Container")

	local pHeaderStroke = Instance.new("UIStroke")
	pHeaderStroke.Color = UI.Theme.Border
	pHeaderStroke.Thickness = 1
	pHeaderStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	pHeaderStroke.Parent = pHeader
	UI.registerThemeElement(pHeaderStroke, "Border")

	local pAvatarBox = Instance.new("Frame")
	pAvatarBox.Size = UDim2.new(0, 42, 0, 42)
	pAvatarBox.Position = UDim2.new(0, 5, 0, 5)
	pAvatarBox.BackgroundColor3 = UI.Theme.ContainerDark
	pAvatarBox.BorderSizePixel = 0
	pAvatarBox.Parent = pHeader
	UI.registerThemeElement(pAvatarBox, "ContainerDark")

	local pAvatarImg = Instance.new("ImageLabel")
	pAvatarImg.Size = UDim2.new(1, 0, 1, 0)
	pAvatarImg.BackgroundTransparency = 1
	pAvatarImg.Parent = pAvatarBox

	local pNameLabel = Instance.new("TextLabel")
	pNameLabel.Size = UDim2.new(1, -74, 0, 16)
	pNameLabel.Position = UDim2.new(0, 52, 0, 6)
	pNameLabel.BackgroundTransparency = 1
	pNameLabel.Text = "DisplayName"
	pNameLabel.TextColor3 = UI.Theme.TextPrimary
	pNameLabel.Font = UI.Fonts.Header
	pNameLabel.TextSize = 11
	pNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	pNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	pNameLabel.Parent = pHeader
	UI.registerThemeElement(pNameLabel, "TextPrimary")

	local pSubLabel = Instance.new("TextLabel")
	pSubLabel.Size = UDim2.new(1, -74, 0, 14)
	pSubLabel.Position = UDim2.new(0, 52, 0, 24)
	pSubLabel.BackgroundTransparency = 1
	pSubLabel.Text = "@Username | 0d"
	pSubLabel.TextColor3 = UI.Theme.TextSecondary
	pSubLabel.Font = UI.Fonts.Mono
	pSubLabel.TextSize = 9
	pSubLabel.TextXAlignment = Enum.TextXAlignment.Left
	pSubLabel.TextTruncate = Enum.TextTruncate.AtEnd
	pSubLabel.Parent = pHeader
	UI.registerThemeElement(pSubLabel, "TextSecondary")

	local pCloseBtn = Instance.new("TextButton")
	pCloseBtn.Size = UDim2.new(0, 16, 0, 16)
	pCloseBtn.Position = UDim2.new(1, -20, 0, 6)
	pCloseBtn.BackgroundColor3 = UI.Theme.ContainerDark
	pCloseBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	pCloseBtn.BorderSizePixel = 0
	pCloseBtn.Text = "X"
	pCloseBtn.TextColor3 = UI.Theme.TextPrimary
	pCloseBtn.Font = UI.Fonts.Header
	pCloseBtn.TextSize = 9
	pCloseBtn.Parent = pHeader
	UI.registerThemeElement(pCloseBtn, "ContainerDark")
	UI.registerThemeElement(pCloseBtn, "TextPrimary")
	pCloseBtn.MouseButton1Click:Connect(function()
		if closeContextMenu then closeContextMenu() end
	end)

	-- Popup Action Buttons List
	local pBtnContainer = Instance.new("Frame")
	pBtnContainer.Size = UDim2.new(1, -10, 1, -60)
	pBtnContainer.Position = UDim2.new(0, 5, 0, 56)
	pBtnContainer.BackgroundTransparency = 1
	pBtnContainer.Parent = popupFrame

	local pLayout = Instance.new("UIListLayout")
	pLayout.Padding = UDim.new(0, 4)
	pLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pLayout.Parent = pBtnContainer

	local currentTargetPlayer: Player? = nil
	local isSpying = false

	local function makeActionBtn(text: string, order: number, onClick: () -> ()): TextButton
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, 23)
		btn.BackgroundColor3 = UI.Theme.Container
		btn.BackgroundTransparency = UI.Theme.ContainerTransparency
		btn.BorderSizePixel = 0
		btn.Text = text
		btn.TextColor3 = UI.Theme.TextPrimary
		btn.Font = UI.Fonts.Header
		btn.TextSize = 10
		btn.LayoutOrder = order
		btn.Parent = pBtnContainer
		UI.registerThemeElement(btn, "Container")
		UI.registerThemeElement(btn, "TextPrimary")

		local bStroke = Instance.new("UIStroke")
		bStroke.Color = UI.Theme.Border
		bStroke.Thickness = 1
		bStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		bStroke.Parent = btn
		UI.registerThemeElement(bStroke, "Border")

		btn.MouseEnter:Connect(function()
			TweenService:Create(bStroke, TweenInfo.new(0.12), { Thickness = 1.6, Color = UI.Theme.Accent }):Play()
			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.ContainerDark, TextColor3 = UI.Theme.Accent }):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(bStroke, TweenInfo.new(0.12), { Thickness = 1, Color = UI.Theme.Border }):Play()
			TweenService:Create(btn, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.Container, TextColor3 = UI.Theme.TextPrimary }):Play()
		end)

		btn.MouseButton1Click:Connect(onClick)
		return btn
	end

	-- 1. Friend / Unfriend
	local friendBtn = makeActionBtn("Add Friend", 1, function()
		if currentTargetPlayer and currentTargetPlayer ~= Players.LocalPlayer then
			pcall(function()
				StarterGui:SetCore("PromptSendFriendRequest", currentTargetPlayer)
			end)
		end
	end)

	-- 2. Block Player
	local blockBtn = makeActionBtn("Block Player", 2, function()
		if currentTargetPlayer and currentTargetPlayer ~= Players.LocalPlayer then
			pcall(function()
				StarterGui:SetCore("PromptBlockPlayer", currentTargetPlayer)
			end)
		end
	end)

	-- 3. Teleport To Player
	local tpBtn = makeActionBtn("Teleport Behind", 3, function()
		if currentTargetPlayer and currentTargetPlayer.Character then
			local myChar = Players.LocalPlayer.Character
			local tChar = currentTargetPlayer.Character
			if myChar and tChar and myChar:FindFirstChild("HumanoidRootPart") and tChar:FindFirstChild("HumanoidRootPart") then
				local tHrp = tChar:FindFirstChild("HumanoidRootPart") :: BasePart
				local myHrp = myChar:FindFirstChild("HumanoidRootPart") :: BasePart
				myHrp.CFrame = tHrp.CFrame * CFrame.new(0, 0, 3)
			end
		end
	end)

	-- 4. Fling Player (Target High-Torque Burst)
	local flingBtn = makeActionBtn("Fling Player", 4, function()
		if currentTargetPlayer and currentTargetPlayer.Character then
			local myChar = Players.LocalPlayer.Character
			local tChar = currentTargetPlayer.Character
			local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart") :: BasePart?
			local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart") :: BasePart?
			if myHrp and tHrp then
				local oldCF = myHrp.CFrame
				task.spawn(function()
					local tStart = tick()
					while tick() - tStart < 0.45 do
						if not (myHrp and tHrp and tHrp.Parent) then break end
						myHrp.CFrame = tHrp.CFrame
						myHrp.AssemblyAngularVelocity = Vector3.new(0, 10000000, 0)
						task.wait(0.016)
					end
					myHrp.AssemblyAngularVelocity = Vector3.zero
					myHrp.CFrame = oldCF
				end)
			end
		end
	end)

	-- 5. Spectate / Spy
	local spyBtn = makeActionBtn("Spectate Player", 5, function()
		local cam = workspace.CurrentCamera
		if not cam then return end
		isSpying = not isSpying
		spyBtn.Text = if isSpying then "Unspectate" else "Spectate Player"
		if isSpying and currentTargetPlayer and currentTargetPlayer.Character and currentTargetPlayer.Character:FindFirstChildOfClass("Humanoid") then
			cam.CameraSubject = currentTargetPlayer.Character:FindFirstChildOfClass("Humanoid")
		elseif Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
			cam.CameraSubject = Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		end
	end)

	-- 6. Inspect Profile / Report
	local inspectBtn = makeActionBtn("Inspect / Report", 6, function()
		if currentTargetPlayer then
			pcall(function()
				GuiService:InspectPlayerFromUserId(currentTargetPlayer.UserId)
			end)
		end
	end)

	-- 7. Copy Username & User ID
	local copyBtn = makeActionBtn("Copy Name & ID", 7, function()
		if currentTargetPlayer then
			local clip = string.format("%s (@%s) [ID:%d]", currentTargetPlayer.DisplayName, currentTargetPlayer.Name, currentTargetPlayer.UserId)
			local setclip = setclipboard or (getgenv and getgenv().setclipboard) or toclipboard
			if type(setclip) == "function" then
				setclip(clip)
			end
		end
	end)

	closeContextMenu = function()
		if not isPopupOpen then return end
		isPopupOpen = false
		Animations.popOut(popupFrame, popupScale)
	end

	local function openContextMenuForPlayer(player: Player, rowAbsPos: Vector2)
		currentTargetPlayer = player
		pAvatarImg.Image = Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		pNameLabel.Text = player.DisplayName
		local teamStr = if player.Team then string.format("[%s] ", player.Team.Name) else ""
		pSubLabel.Text = string.format("%s@%s | ID:%d", teamStr, player.Name, player.UserId)

		-- Update Friend Button text based on status
		pcall(function()
			local isFriend = Players.LocalPlayer:IsFriendsWith(player.UserId)
			friendBtn.Text = if isFriend then "Unfriend" else "Add Friend"
		end)

		-- Dynamic Smart Positioning (8px viewport margin & flip detection)
		local vpSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		local wPos = widget.AbsolutePosition
		local wSize = widget.AbsoluteSize
		local margin = 8

		local spaceLeft = wPos.X - margin
		local spaceRight = vpSize.X - (wPos.X + wSize.X) - margin

		local posX = 0
		if spaceLeft >= POPUP_W then
			posX = wPos.X - POPUP_W - margin
		elseif spaceRight >= POPUP_W then
			posX = wPos.X + wSize.X + margin
		elseif spaceLeft >= spaceRight then
			posX = wPos.X - POPUP_W - margin
		else
			posX = wPos.X + wSize.X + margin
		end

		local posY = math.clamp(rowAbsPos.Y, margin, math.max(margin, vpSize.Y - POPUP_H - margin))
		posX = math.clamp(posX, margin, math.max(margin, vpSize.X - POPUP_W - margin))

		popupFrame.Position = UDim2.new(0, posX, 0, posY)
		isPopupOpen = true
		Animations.popIn(popupFrame, popupScale)
	end

	-- ── Incremental Domino-Animated Player Rows (Clickable) ───────────
	local function createPlayerRow(player: Player, delaySec: number?)
		local rowId = "PLR_" .. tostring(player.UserId)
		if container:FindFirstChild(rowId) then return end

		local rowBtn = Instance.new("TextButton")
		rowBtn.Name = rowId
		rowBtn.Size = UDim2.new(1, 0, 0, ROW_H)
		rowBtn.Position = UDim2.new(0, 24, 0, 0)
		rowBtn.BackgroundColor3 = UI.Theme.Container
		rowBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
		rowBtn.BorderSizePixel = 0
		rowBtn.Text = ""
		rowBtn.AutoButtonColor = false
		rowBtn.ClipsDescendants = true
		rowBtn.Parent = container
		UI.registerThemeElement(rowBtn, "Container")

		local rowStroke = Instance.new("UIStroke")
		rowStroke.Color = UI.Theme.Border
		rowStroke.Thickness = 1
		rowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		rowStroke.Parent = rowBtn
		UI.registerThemeElement(rowStroke, "Border")

		-- Avatar Headshot
		local avatarBox = Instance.new("Frame")
		avatarBox.Size = UDim2.new(0, 30, 0, 30)
		avatarBox.Position = UDim2.new(0, 4, 0, 4)
		avatarBox.BackgroundColor3 = UI.Theme.ContainerDark
		avatarBox.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
		avatarBox.BorderSizePixel = 0
		avatarBox.Parent = rowBtn
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
		avatarImg.Parent = avatarBox
		task.spawn(function()
			local ok, thumb = pcall(function()
				return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size60x60)
			end)
			if ok and thumb and avatarImg.Parent then
				avatarImg.Image = thumb
			end
		end)

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
		nameLabel.Parent = rowBtn
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
		subLabel.Parent = rowBtn
		UI.registerThemeElement(subLabel, "TextSecondary")

		-- Row Hover FX
		rowBtn.MouseEnter:Connect(function()
			TweenService:Create(rowStroke, TweenInfo.new(0.12), { Color = UI.Theme.Accent, Thickness = 1.4 }):Play()
			TweenService:Create(rowBtn, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.ContainerDark }):Play()
		end)
		rowBtn.MouseLeave:Connect(function()
			TweenService:Create(rowStroke, TweenInfo.new(0.12), { Color = UI.Theme.Border, Thickness = 1 }):Play()
			TweenService:Create(rowBtn, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.Container }):Play()
		end)

		-- Row Click Opens Context Menu
		rowBtn.MouseButton1Click:Connect(function()
			openContextMenuForPlayer(player, rowBtn.AbsolutePosition)
		end)

		-- Slide-in from right to left (Domino effect)
		local function playSlide()
			if rowBtn and rowBtn.Parent then
				TweenService:Create(rowBtn, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Position = UDim2.new(0, 0, 0, 0)
				}):Play()
			end
		end

		if delaySec and delaySec > 0 then
			task.delay(delaySec, playSlide)
		else
			playSlide()
		end

		titleLabel.Text = string.format("Players (%d)", #Players:GetPlayers())
		updateWidgetHeight()
	end

	local function deletePlayerRow(player: Player)
		local rowId = "PLR_" .. tostring(player.UserId)
		local row = container:FindFirstChild(rowId)
		if row and row:IsA("TextButton") then
			local tween = TweenService:Create(row, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0, 24, 0, 0),
				BackgroundTransparency = 1
			})
			tween:Play()
			tween.Completed:Connect(function()
				row:Destroy()
				titleLabel.Text = string.format("Players (%d)", #Players:GetPlayers())
				updateWidgetHeight()
			end)
		end
		if currentTargetPlayer == player and isPopupOpen then
			closeContextMenu()
		end
	end

	-- Connect Player Added / Removed
	Players.PlayerAdded:Connect(function(p)
		createPlayerRow(p, 0)
	end)
	Players.PlayerRemoving:Connect(deletePlayerRow)

	-- Populate existing players with domino wave
	task.spawn(function()
		for i, p in ipairs(Players:GetPlayers()) do
			createPlayerRow(p, (i - 1) * 0.035)
		end
	end)

	widgetObj = {
		Frame = widget,
		Container = container,
		UiScale = uiScale,
		IsMinimized = false,
		Visible = true,
		IsOpen = function() return isOpen end,
		Open = openWidget,
		Close = closeWidget,
		Toggle = toggleWidget,
		SetVisible = setWidgetVisible,
		OnClose = nil,
		OnOpen = nil,
		OnMinimize = nil,
	}
	return widgetObj
end

return PlayerList
