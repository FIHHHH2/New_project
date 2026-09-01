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
    ✦ Squared Retro Health HUD & Damage Visual Indicator Widget ✦
    Features:
    - Live Local Player Health Bar with smooth spring tweening and exact HP formatting
    - Dynamic Health Color Modes: Theme Accent vs Reactive Health Gradient (Green -> Yellow -> Red)
    - Low HP Warning (<25%): Pulsing retro danger glow and alert outline
    - 3D Floating Damage Numbers over any damaged player/entity with crits & smooth rising bounce
    - Screen Damage Flash & Vignette on taking damage
    - Target Combat HUD: Displays target player/enemy health card when damaged or locked on
    - Fully draggable HUD with position persistence and 100% Theme Reactivity
]=]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local UI = require("UI/UI.luau")
local Animations = require("UI/Animations.luau")

local HealthWidget = {}
HealthWidget.__index = HealthWidget

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

export type HealthWidgetInstance = {
	Frame: Frame,
	ScreenGui: ScreenGui,
	SetVisible: (selfOrVal: any, maybeVal: any) -> (),
	ToggleDamageNumbers: (enabled: boolean) -> (),
	ToggleDamageFlash: (enabled: boolean) -> (),
	SetDynamicColors: (enabled: boolean) -> (),
	ShowDamageNumber: (pos: Vector3, amount: number, isLocalPlayer: boolean, isCrit: boolean?) -> (),
	Cleanup: () -> ()
}

local widgetInstance: HealthWidgetInstance? = nil

function HealthWidget.getHealthColor(healthPercent: number): Color3
	if healthPercent > 0.6 then
		local t = (healthPercent - 0.6) / 0.4
		return Color3.fromRGB(80, 235, 120):Lerp(Color3.fromRGB(235, 205, 50), 1 - t)
	elseif healthPercent > 0.25 then
		local t = (healthPercent - 0.25) / 0.35
		return Color3.fromRGB(235, 205, 50):Lerp(Color3.fromRGB(235, 90, 40), 1 - t)
	else
		return Color3.fromRGB(235, 50, 50)
	end
end

function HealthWidget.new(): HealthWidgetInstance
	if _G.__ModularHealth_Cleanup then
		pcall(_G.__ModularHealth_Cleanup)
		_G.__ModularHealth_Cleanup = nil
	end

	local activeConns: {RBXScriptConnection} = {}

	destroyExistingGuis("ModularHealthGui")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ModularHealthGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 605
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	pcall(function() screenGui.Parent = CoreGui end)
	if not screenGui.Parent then
		screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end

	-- ── 1. Screen Damage Flash & Vignette Overlay ──────────────────────
	local vignette = Instance.new("Frame")
	vignette.Name = "DamageVignette"
	vignette.Size = UDim2.new(1, 0, 1, 0)
	vignette.Position = UDim2.new(0, 0, 0, 0)
	vignette.BackgroundColor3 = Color3.fromRGB(255, 30, 30)
	vignette.BackgroundTransparency = 1
	vignette.BorderSizePixel = 0
	vignette.ZIndex = 50
	vignette.Parent = screenGui

	local vignetteGrad = Instance.new("UIGradient")
	vignetteGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(0.6, 0.9),
		NumberSequenceKeypoint.new(1, 1)
	})
	vignetteGrad.Parent = vignette

	local function triggerDamageFlash(intensity: number)
		local peakAlpha = math.clamp(0.85 - (intensity * 0.4), 0.35, 0.85)
		vignette.BackgroundTransparency = peakAlpha
		TweenService:Create(vignette, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1
		}):Play()
	end

	-- ── 2. Floating Damage Number Container ───────────────────────────
	local damageContainer = Instance.new("Folder")
	damageContainer.Name = "DamageNumbers"
	damageContainer.Parent = screenGui

	local function showDamageNumber(worldPos: Vector3, amount: number, isLocalPlayer: boolean, isCrit: boolean?)
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "DamageIndicator"
		billboard.Size = UDim2.new(0, 110, 0, 36)
		billboard.StudsOffsetWorldSpace = worldPos + Vector3.new(math.random(-10, 10) * 0.08, math.random(5, 15) * 0.1, math.random(-10, 10) * 0.08)
		billboard.AlwaysOnTop = true
		billboard.ResetOnSpawn = false
		billboard.ClipsDescendants = false
		billboard.Parent = damageContainer

		local dmgBox = Instance.new("Frame")
		dmgBox.Size = UDim2.new(1, 0, 1, 0)
		dmgBox.BackgroundTransparency = 1
		dmgBox.Parent = billboard

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = if isCrit then 2.0 else 1.2
		stroke.Color = if isLocalPlayer then Color3.fromRGB(60, 0, 0) else (if isCrit then Color3.fromRGB(120, 60, 0) else Color3.fromRGB(20, 20, 20))
		stroke.Parent = dmgBox

		local dmgLabel = Instance.new("TextLabel")
		dmgLabel.Size = UDim2.new(1, 0, 1, 0)
		dmgLabel.BackgroundTransparency = 1
		dmgLabel.Text = string.format("%s%d%s", if isCrit then "✦ -" else "-", math.floor(amount + 0.5), if isCrit then " ✦" else "")
		dmgLabel.TextColor3 = if isLocalPlayer then Color3.fromRGB(255, 65, 65) else (if isCrit then Color3.fromRGB(255, 215, 0) else Color3.fromRGB(255, 160, 40))
		dmgLabel.Font = UI.Fonts.Header
		dmgLabel.TextSize = if isCrit then 16 else 13
		dmgLabel.TextStrokeTransparency = 0.5
		dmgLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		dmgLabel.Parent = dmgBox

		local scale = Instance.new("UIScale")
		scale.Scale = 0.4
		scale.Parent = dmgBox

		-- Bounce pop animation
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = if isCrit then 1.35 else 1.05
		}):Play()

		-- Smooth rise & fade
		local riseTween = TweenService:Create(billboard, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			StudsOffsetWorldSpace = billboard.StudsOffsetWorldSpace + Vector3.new(0, 2.5, 0)
		})
		riseTween:Play()

		task.delay(0.45, function()
			TweenService:Create(dmgLabel, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				TextTransparency = 1,
				TextStrokeTransparency = 1
			}):Play()
		end)

		riseTween.Completed:Connect(function()
			billboard:Destroy()
		end)
	end

	-- ── 3. Main Player Health Bar Widget HUD ──────────────────────────
	local HUD_WIDTH = 230
	local HUD_HEIGHT = 54
	local hudFrame = Instance.new("Frame")
	hudFrame.Name = "HealthWidgetFrame"
	hudFrame.Size = UDim2.new(0, HUD_WIDTH, 0, HUD_HEIGHT)
	hudFrame.AnchorPoint = Vector2.new(0.5, 0)
	hudFrame.Position = UDim2.new(0.5, 0, 0, 10)
	hudFrame.BackgroundColor3 = UI.Theme.Background
	hudFrame.BackgroundTransparency = UI.Theme.BackgroundTransparency
	hudFrame.BorderSizePixel = 0
	hudFrame.ClipsDescendants = false
	hudFrame.Parent = screenGui
	UI.registerThemeElement(hudFrame, "Background")

	local hudStroke = Instance.new("UIStroke")
	hudStroke.Color = UI.Theme.Border
	hudStroke.Thickness = 2
	hudStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	hudStroke.Parent = hudFrame
	UI.registerThemeElement(hudStroke, "Border")

	-- Dragging handler for Health HUD
	local isDragging = false
	local dragStart = Vector2.zero
	local startPos = hudFrame.Position

	hudFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = true
			dragStart = UserInputService:GetMouseLocation()
			startPos = hudFrame.Position
		end
	end)

	table.insert(activeConns, UserInputService.InputChanged:Connect(function(input)
		if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local mousePos = UserInputService:GetMouseLocation()
			local delta = mousePos - dragStart
			hudFrame.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end))

	table.insert(activeConns, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			isDragging = false
		end
	end))

	-- Player Headshot Avatar Box
	local headshotBox = Instance.new("Frame")
	headshotBox.Name = "AvatarBox"
	headshotBox.Size = UDim2.new(0, 38, 0, 38)
	headshotBox.Position = UDim2.new(0, 8, 0, 8)
	headshotBox.BackgroundColor3 = UI.Theme.ContainerDark
	headshotBox.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	headshotBox.BorderSizePixel = 0
	headshotBox.ClipsDescendants = true
	headshotBox.Parent = hudFrame
	UI.registerThemeElement(headshotBox, "ContainerDark")

	local avatarStroke = Instance.new("UIStroke")
	avatarStroke.Color = UI.Theme.BorderDim
	avatarStroke.Thickness = 1
	avatarStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	avatarStroke.Parent = headshotBox
	UI.registerThemeElement(avatarStroke, "BorderDim")

	local avatarImg = Instance.new("ImageLabel")
	avatarImg.Size = UDim2.new(1, 0, 1, 0)
	avatarImg.BackgroundTransparency = 1
	avatarImg.Parent = headshotBox

	task.spawn(function()
		local ok, thumb = pcall(function()
			return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size60x60)
		end)
		if ok and thumb and avatarImg.Parent then
			avatarImg.Image = thumb
		end
	end)

	-- Info Header: Username & HP Text
	local infoContainer = Instance.new("Frame")
	infoContainer.Size = UDim2.new(1, -58, 0, 18)
	infoContainer.Position = UDim2.new(0, 52, 0, 7)
	infoContainer.BackgroundTransparency = 1
	infoContainer.BorderSizePixel = 0
	infoContainer.Parent = hudFrame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "PlayerName"
	nameLabel.Size = UDim2.new(0.55, 0, 1, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = LocalPlayer.DisplayName or LocalPlayer.Name
	nameLabel.TextColor3 = UI.Theme.TextPrimary
	nameLabel.Font = UI.Fonts.Header
	nameLabel.TextSize = 10
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.ClipsDescendants = true
	nameLabel.Parent = infoContainer
	UI.registerThemeElement(nameLabel, "TextPrimary")

	local hpLabel = Instance.new("TextLabel")
	hpLabel.Name = "HPLabel"
	hpLabel.Size = UDim2.new(0.45, 0, 1, 0)
	hpLabel.Position = UDim2.new(0.55, 0, 0, 0)
	hpLabel.BackgroundTransparency = 1
	hpLabel.Text = "100 / 100 HP"
	hpLabel.TextColor3 = UI.Theme.Accent
	hpLabel.Font = UI.Fonts.Mono
	hpLabel.TextSize = 9
	hpLabel.TextXAlignment = Enum.TextXAlignment.Right
	hpLabel.TextTruncate = Enum.TextTruncate.AtEnd
	hpLabel.ClipsDescendants = true
	hpLabel.Parent = infoContainer
	UI.registerThemeElement(hpLabel, "Accent")

	-- Main Health Bar Track
	local barTrack = Instance.new("Frame")
	barTrack.Name = "HealthTrack"
	barTrack.Size = UDim2.new(1, -58, 0, 14)
	barTrack.Position = UDim2.new(0, 52, 0, 29)
	barTrack.BackgroundColor3 = UI.Theme.ContainerDark
	barTrack.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	barTrack.BorderSizePixel = 0
	barTrack.ClipsDescendants = true
	barTrack.Parent = hudFrame
	UI.registerThemeElement(barTrack, "ContainerDark")

	local barTrackStroke = Instance.new("UIStroke")
	barTrackStroke.Color = UI.Theme.Border
	barTrackStroke.Thickness = 1.2
	barTrackStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	barTrackStroke.Parent = barTrack
	UI.registerThemeElement(barTrackStroke, "Border")

	-- Health Bar Damage Lag Buffer (Shows white/red drain effect behind actual health)
	local bufferFill = Instance.new("Frame")
	bufferFill.Name = "BufferFill"
	bufferFill.Size = UDim2.new(1, 0, 1, 0)
	bufferFill.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
	bufferFill.BackgroundTransparency = 0.35
	bufferFill.BorderSizePixel = 0
	bufferFill.Parent = barTrack

	-- Health Bar Primary Fill
	local barFill = Instance.new("Frame")
	barFill.Name = "HealthFill"
	barFill.Size = UDim2.new(1, 0, 1, 0)
	barFill.BackgroundColor3 = UI.Theme.Accent
	barFill.BorderSizePixel = 0
	barFill.Parent = barTrack
	UI.registerThemeElement(barFill, "Accent")

	local fillGrad = Instance.new("UIGradient")
	fillGrad.Rotation = 90
	fillGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 190, 210))
	})
	fillGrad.Parent = barFill

	-- ── 4. Target Combat Health HUD Card ──────────────────────────────
	local targetCard = Instance.new("Frame")
	targetCard.Name = "TargetCombatHUD"
	targetCard.Size = UDim2.new(0, 180, 0, 42)
	targetCard.Position = UDim2.new(0.5, -90, 0, 18)
	targetCard.BackgroundColor3 = UI.Theme.Background
	targetCard.BackgroundTransparency = UI.Theme.BackgroundTransparency
	targetCard.BorderSizePixel = 0
	targetCard.Visible = false
	targetCard.ClipsDescendants = false
	targetCard.Parent = screenGui
	UI.registerThemeElement(targetCard, "Background")

	local targetStroke = Instance.new("UIStroke")
	targetStroke.Color = UI.Theme.Border
	targetStroke.Thickness = 1.5
	targetStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	targetStroke.Parent = targetCard
	UI.registerThemeElement(targetStroke, "Border")

	local targetTitle = Instance.new("TextLabel")
	targetTitle.Size = UDim2.new(1, -12, 0, 16)
	targetTitle.Position = UDim2.new(0, 6, 0, 4)
	targetTitle.BackgroundTransparency = 1
	targetTitle.Text = "Target"
	targetTitle.TextColor3 = UI.Theme.TextPrimary
	targetTitle.Font = UI.Fonts.Header
	targetTitle.TextSize = 9
	targetTitle.TextXAlignment = Enum.TextXAlignment.Left
	targetTitle.TextTruncate = Enum.TextTruncate.AtEnd
	targetTitle.Parent = targetCard
	UI.registerThemeElement(targetTitle, "TextPrimary")

	local targetTrack = Instance.new("Frame")
	targetTrack.Size = UDim2.new(1, -12, 0, 10)
	targetTrack.Position = UDim2.new(0, 6, 0, 24)
	targetTrack.BackgroundColor3 = UI.Theme.ContainerDark
	targetTrack.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	targetTrack.BorderSizePixel = 0
	targetTrack.ClipsDescendants = true
	targetTrack.Parent = targetCard
	UI.registerThemeElement(targetTrack, "ContainerDark")

	local targetFill = Instance.new("Frame")
	targetFill.Size = UDim2.new(1, 0, 1, 0)
	targetFill.BackgroundColor3 = Color3.fromRGB(245, 60, 60)
	targetFill.BorderSizePixel = 0
	targetFill.Parent = targetTrack

	local hideTargetDebounce: thread? = nil
	local function updateTargetCard(targetName: string, curHealth: number, maxHealth: number)
		targetTitle.Text = string.format("Target: %s  [%d/%d]", targetName, math.floor(curHealth), math.floor(maxHealth))
		local ratio = math.clamp(curHealth / math.max(maxHealth, 1), 0, 1)
		targetFill.BackgroundColor3 = HealthWidget.getHealthColor(ratio)
		TweenService:Create(targetFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(ratio, 0, 1, 0)
		}):Play()

		targetCard.Visible = true

		if hideTargetDebounce then task.cancel(hideTargetDebounce) end
		hideTargetDebounce = task.delay(4.0, function()
			targetCard.Visible = false
		end)
	end

	-- ── 5. Humanoid Tracking & Damage Listeners ────────────────────────
	local damageNumbersEnabled = true
	local damageFlashEnabled = true
	local useDynamicColors = true

	local previousHealth = 100
	local trackedHumanoids: {[Humanoid]: number} = {}

	local function hookHumanoid(hum: Humanoid, ownerName: string, isLocal: boolean)
		trackedHumanoids[hum] = hum.Health

		local healthConn = hum.HealthChanged:Connect(function(newHealth)
			local oldHealth = trackedHumanoids[hum] or newHealth
			trackedHumanoids[hum] = newHealth

			local maxHp = math.max(hum.MaxHealth, 1)
			local ratio = math.clamp(newHealth / maxHp, 0, 1)

			if isLocal then
				-- Update local player health bar
				hpLabel.Text = string.format("%d / %d HP", math.floor(newHealth + 0.5), math.floor(maxHp))

				if useDynamicColors then
					barFill.BackgroundColor3 = HealthWidget.getHealthColor(ratio)
				else
					barFill.BackgroundColor3 = UI.Theme.Accent
				end

				TweenService:Create(barFill, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = UDim2.new(ratio, 0, 1, 0)
				}):Play()

				task.delay(0.25, function()
					TweenService:Create(bufferFill, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						Size = UDim2.new(ratio, 0, 1, 0)
					}):Play()
				end)

				-- Low health warning pulse (<25%)
				if ratio < 0.25 and newHealth > 0 then
					Animations.pulseIndicator(hudStroke, Color3.fromRGB(255, 40, 40), UI.Theme.Border, 2.4, 1.6)
				end

				-- Damage Taken Effect
				if newHealth < oldHealth then
					local dmg = oldHealth - newHealth
					if damageFlashEnabled then
						triggerDamageFlash(dmg / maxHp)
					end
					if damageNumbersEnabled then
						local hrp = hum.RootPart or (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?)
						if hrp then
							showDamageNumber(hrp.Position + Vector3.new(0, 1.5, 0), dmg, true, dmg > 35)
						end
					end
				end
			else
				-- Damage Dealt to another player / entity
				if newHealth < oldHealth then
					local dmg = oldHealth - newHealth
					updateTargetCard(ownerName, newHealth, maxHp)

					if damageNumbersEnabled then
						local hrp = hum.RootPart
						if hrp then
							showDamageNumber(hrp.Position + Vector3.new(0, 2, 0), dmg, false, dmg > 35)
						end
					end
				end
			end
		end)
		table.insert(activeConns, healthConn)
	end

	-- Hook LocalPlayer with instant full health bar reset
	local function refreshLocalHealth(hum: Humanoid)
		local maxHp = math.max(hum.MaxHealth, 1)
		local curHp = math.clamp(hum.Health, 0, maxHp)
		local ratio = math.clamp(curHp / maxHp, 0, 1)

		hpLabel.Text = string.format("%d / %d HP", math.floor(curHp + 0.5), math.floor(maxHp))
		if useDynamicColors then
			barFill.BackgroundColor3 = HealthWidget.getHealthColor(ratio)
		else
			barFill.BackgroundColor3 = UI.Theme.Accent
		end
		barFill.Size = UDim2.new(ratio, 0, 1, 0)
		bufferFill.Size = UDim2.new(ratio, 0, 1, 0)
	end

	local function onCharAdded(char: Model)
		local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
		if hum then
			previousHealth = hum.Health
			hookHumanoid(hum, LocalPlayer.DisplayName or LocalPlayer.Name, true)
			refreshLocalHealth(hum)

			-- Property change listeners for instant updates
			table.insert(activeConns, hum:GetPropertyChangedSignal("Health"):Connect(function()
				refreshLocalHealth(hum)
			end))
			table.insert(activeConns, hum:GetPropertyChangedSignal("MaxHealth"):Connect(function()
				refreshLocalHealth(hum)
			end))
		end
	end

	if LocalPlayer.Character then onCharAdded(LocalPlayer.Character) end
	table.insert(activeConns, LocalPlayer.CharacterAdded:Connect(onCharAdded))

	-- Hook other players in server
	local function hookOtherPlayer(p: Player)
		if p == LocalPlayer then return end
		local function onOtherChar(char: Model)
			local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
			if hum then
				hookHumanoid(hum, p.DisplayName or p.Name, false)
			end
		end
		if p.Character then onOtherChar(p.Character) end
		table.insert(activeConns, p.CharacterAdded:Connect(onOtherChar))
	end

	for _, p in ipairs(Players:GetPlayers()) do
		hookOtherPlayer(p)
	end
	table.insert(activeConns, Players.PlayerAdded:Connect(hookOtherPlayer))

	-- ── 6. Cleanup & Export Instance ──────────────────────────────────
	local widgetObj: HealthWidgetInstance = {
		Frame = hudFrame,
		ScreenGui = screenGui,
		SetVisible = function(selfOrVal: any, maybeVal: any)
			local val = if typeof(selfOrVal) == "boolean" then selfOrVal else maybeVal
			hudFrame.Visible = val
		end,
		ToggleDamageNumbers = function(enabled: boolean)
			damageNumbersEnabled = enabled
		end,
		ToggleDamageFlash = function(enabled: boolean)
			damageFlashEnabled = enabled
		end,
		SetDynamicColors = function(enabled: boolean)
			useDynamicColors = enabled
			if not enabled then barFill.BackgroundColor3 = UI.Theme.Accent end
		end,
		ShowDamageNumber = showDamageNumber,
		Cleanup = function()
			for _, conn in ipairs(activeConns) do
				pcall(function() conn:Disconnect() end)
			end
			table.clear(activeConns)
			screenGui:Destroy()
		end
	}

	_G.__ModularHealth_Cleanup = function()
		widgetObj.Cleanup()
	end

	widgetInstance = widgetObj
	return widgetObj
end

return HealthWidget
