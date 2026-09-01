--!strict
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VoiceChatService = game:GetService("VoiceChatService")
local TextChatService = game:GetService("TextChatService")

local UI = require("UI/UI.luau")
local CoreUI = require("Core/CoreUI.luau")
local FeatureManager = require("Core/FeatureManager.luau")
local PlayerList = require("UI/PlayerList.luau")
local ChatWidget = require("UI/ChatWidget.luau")
local MusicTracker = require("UI/MusicTracker.luau")
local Visuals = require("Modules/Visuals.luau")
local Combat = require("Modules/Combat.luau")
local DisasterSurvival = require("Modules/DisasterSurvival.luau")
local RunNHide = require("Modules/RunNHide.luau")
local IceTycoon = require("Modules/IceTycoon.luau")
local PlayerUtilities = require("Modules/PlayerUtilities.luau")
local Hotbar = require("UI/Hotbar.luau")
local Notification = require("UI/Notification.luau")
local LeaderstatsWidget = require("UI/LeaderstatsWidget.luau")
local HealthWidget = require("UI/HealthWidget.luau")

local localPlayer = Players.LocalPlayer
local character = localPlayer.Character
local humanoid: Humanoid? = if character then character:FindFirstChildOfClass("Humanoid") else nil

local cachedCharacterParts: {BasePart} = {}
local charDescendantAddedConn: RBXScriptConnection? = nil
local charDescendantRemovingConn: RBXScriptConnection? = nil

local function updateCachedCharacterParts(char: Model?)
	table.clear(cachedCharacterParts)
	if charDescendantAddedConn then
		charDescendantAddedConn:Disconnect()
		charDescendantAddedConn = nil
	end
	if charDescendantRemovingConn then
		charDescendantRemovingConn:Disconnect()
		charDescendantRemovingConn = nil
	end

	if not char then return end

	for _, inst in ipairs(char:GetDescendants()) do
		if inst:IsA("BasePart") and not inst:FindFirstAncestorWhichIsA("Tool") and not inst:FindFirstAncestorWhichIsA("Accessory") then
			table.insert(cachedCharacterParts, inst)
		end
	end

	charDescendantAddedConn = char.DescendantAdded:Connect(function(inst)
		if inst:IsA("BasePart") and not inst:FindFirstAncestorWhichIsA("Tool") and not inst:FindFirstAncestorWhichIsA("Accessory") then
			table.insert(cachedCharacterParts, inst)
		end
	end)

	charDescendantRemovingConn = char.DescendantRemoving:Connect(function(inst)
		if inst:IsA("BasePart") then
			local idx = table.find(cachedCharacterParts, inst)
			if idx then
				table.remove(cachedCharacterParts, idx)
			end
		end
	end)
end

if character then
	updateCachedCharacterParts(character)
end

localPlayer.CharacterAdded:Connect(function(char)
	character = char
	humanoid = char:WaitForChild("Humanoid", 5) :: Humanoid?
	updateCachedCharacterParts(char)
end)

-- Disable overlapping default CoreGui elements and native Roblox TopBarApp
local coreGuiOverlays = {
	Enum.CoreGuiType.All,
	Enum.CoreGuiType.PlayerList,
	Enum.CoreGuiType.Chat,
	Enum.CoreGuiType.EmotesMenu,
	Enum.CoreGuiType.Backpack,
	Enum.CoreGuiType.Health,
}

local function disableRobloxTopBarApp(disable: boolean)
	pcall(function()
		StarterGui:SetCore("TopbarEnabled", not disable)
	end)
	pcall(function()
		local topBarApp = CoreGui:FindFirstChild("TopBarApp")
		if topBarApp then
			for _, child in ipairs(topBarApp:GetChildren()) do
				if child:IsA("ScreenGui") then
					child.Enabled = not disable
				elseif child:IsA("GuiObject") then
					child.Visible = not disable
				end
			end
		end
		local robloxGui = CoreGui:FindFirstChild("RobloxGui")
		if robloxGui then
			local tb = robloxGui:FindFirstChild("TopBar") or robloxGui:FindFirstChild("TopBarContainer") or robloxGui:FindFirstChild("TopBarApp")
			if tb and tb:IsA("GuiObject") then
				tb.Visible = not disable
			end
		end
	end)
end

local function disableCoreGuis()
	disableRobloxTopBarApp(true)
	for _ = 1, 8 do
		local ok = true
		for _, guiType in ipairs(coreGuiOverlays) do
			local success = pcall(function()
				StarterGui:SetCoreGuiEnabled(guiType, false)
			end)
			if not success then ok = false end
		end
		if ok then break end
		task.wait(0.2)
	end
end

-- Hide all non-Modular PlayerGui ScreenGuis on load.
-- Games frequently render their own black backgrounds / loading screens
-- via ScreenGui which sit on top of everything until explicitly disabled.
local hiddenGameGuis: {[ScreenGui]: boolean} = {}
local function hidePlayerGameGuis(enabled: boolean)
	local pgui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not pgui then return end
	for _, child in ipairs(pgui:GetChildren()) do
		if child:IsA("ScreenGui") and not string.find(child.Name, "Modular") then
			if enabled then
				hiddenGameGuis[child] = child.Enabled
				child.Enabled = false
			else
				child.Enabled = if hiddenGameGuis[child] ~= nil then hiddenGameGuis[child] else true
			end
		end
	end
end

task.spawn(disableCoreGuis)
-- Auto-hide game GUIs immediately — fixes black screen on load
task.spawn(function()
	-- Brief wait for PlayerGui to populate
	task.wait(0.5)
	hidePlayerGameGuis(true)
end)

localPlayer.CharacterAdded:Connect(function()
	task.spawn(disableCoreGuis)
	task.spawn(function()
		task.wait(0.5)
		hidePlayerGameGuis(true)
	end)
end)


-- Continuous enforcer so Roblox topbar never pops back up
task.spawn(function()
	while true do
		task.wait(3)
		disableRobloxTopBarApp(true)
	end
end)

local window = CoreUI.new("Project Fih Menu")
local playerListWidget = PlayerList.new()
local chatWidgetInstance = ChatWidget.new()
local musicTrackerWidget = MusicTracker.new()
local hotbarWidget = Hotbar.new()
local leaderstatsWidget = LeaderstatsWidget.new()
local healthWidget = HealthWidget.new()

_G.__ToggleProjectFihBackpack = function()
	if hotbarWidget then
		hotbarWidget.ToggleBackpack()
	end
end

_G.__ToggleProjectFihMenu = function()
	window:Toggle()
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.Tab then
		playerListWidget:Toggle()
	end
end)

local function getGameTabName(): string
	local placeId = game.PlaceId
	local gameName = string.lower(game.Name)
	pcall(function()
		local MarketplaceService = game:GetService("MarketplaceService")
		local info = MarketplaceService:GetProductInfo(placeId)
		if info and info.Name then
			gameName = string.lower(info.Name)
		end
	end)

	if placeId == 189707 or string.find(gameName, "disaster") then
		return "Natural Disaster"
	elseif placeId == 12901416348 or string.find(gameName, "run and hide") or string.find(gameName, "demise") then
		return "Run N Hide"
	elseif string.find(gameName, "ice tycoon") or (workspace:FindFirstChild("Tycoon") and workspace.Tycoon:FindFirstChild("Buttons")) then
		return "Ice Tycoon"
	end
	return "Run N Hide"
end

local gameTabTitle = getGameTabName()

-- Create navigation tabs in strict layout order
local mainTab = window:CreateTab("Main")
local combatTab = window:CreateTab("Combat")
local gameTab = window:CreateTab(gameTabTitle)
local visualsTab = window:CreateTab("Visuals")

-- Create hidden dedicated settings and configs pages
local settingsTab = window:CreateTab("Settings", true)
local configsTab = window:CreateTab("Configs", true)
window.SettingsTab = settingsTab
window.ConfigsTab = configsTab

---- ============================================================
-- 1. MAIN TAB CONTENT (HORIZONTAL MINI SUB-TABS)
--    [ Movement & Flight ] [ Physics & Modifiers ] [ Player Utilities ]
-- ============================================================
local mainSubTabs = window:CreateSubTabs(mainTab, { "Movement & Flight", "Physics & Modifiers", "Player Utilities" })
local moveFlightSubTab = mainSubTabs["Movement & Flight"]
local physicsSubTab = mainSubTabs["Physics & Modifiers"]
local playerUtilsSubTab = mainSubTabs["Player Utilities"]

-- ── MAIN SUB-TAB 1: MOVEMENT & FLIGHT ────────────────────────
local mfLeftCol, mfRightCol = window:CreateColumns(moveFlightSubTab)

-- Left Column: Flight & Locomotion
local flightSection = window:AddSection(mfLeftCol, "Flight & Locomotion")

local flyConn: RBXScriptConnection? = nil
local flySpeed = 50
local function updateFlightState(enabled: boolean)
	if enabled then
		local char = localPlayer.Character
		if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not (hrp and hum) then return end

		local bg = hrp:FindFirstChild("FlyGyro") :: BodyGyro? or Instance.new("BodyGyro")
		bg.Name = "FlyGyro"
		bg.P = 9e4
		bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
		bg.CFrame = hrp.CFrame
		bg.Parent = hrp

		local bv = hrp:FindFirstChild("FlyVelocity") :: BodyVelocity? or Instance.new("BodyVelocity")
		bv.Name = "FlyVelocity"
		bv.Velocity = Vector3.zero
		bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
		bv.Parent = hrp

		hum.PlatformStand = true

		if flyConn then flyConn:Disconnect() end
		flyConn = RunService.RenderStepped:Connect(function()
			local cam = Workspace.CurrentCamera
			local curChar = localPlayer.Character
			local curHrp = curChar and curChar:FindFirstChild("HumanoidRootPart") :: BasePart?
			local curHum = curChar and curChar:FindFirstChildOfClass("Humanoid")
			if not (curChar and curHrp and curHum and cam and curHum.Health > 0) then return end

			bg.CFrame = cam.CFrame
			local look = cam.CFrame.LookVector
			local right = cam.CFrame.RightVector
			local moveVec = Vector3.zero

			if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec += look end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec -= look end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec -= right end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec += right end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVec += Vector3.new(0, 1, 0) end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveVec -= Vector3.new(0, 1, 0) end

			if moveVec.Magnitude > 0 then
				bv.Velocity = moveVec.Unit * flySpeed
			else
				bv.Velocity = Vector3.zero
			end
		end)
	else
		if flyConn then
			flyConn:Disconnect()
			flyConn = nil
		end
		local char = localPlayer.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hrp then
				local bg = hrp:FindFirstChild("FlyGyro")
				if bg then bg:Destroy() end
				local bv = hrp:FindFirstChild("FlyVelocity")
				if bv then bv:Destroy() end
			end
			if hum then
				hum.PlatformStand = false
			end
		end
	end
end

window:AddToggle(flightSection, "fly_toggle", "Flight / Fly Mode", false, nil, function(enabled)
	updateFlightState(enabled)
end)

local noclipConn: RBXScriptConnection? = nil
window:AddToggle(flightSection, "noclip_toggle", "Noclip (Collision Bypass)", false, nil, function(enabled)
	if enabled then
		noclipConn = RunService.Stepped:Connect(function()
			for _, part in ipairs(cachedCharacterParts) do
				part.CanCollide = false
			end
		end)
	else
		if noclipConn then
			noclipConn:Disconnect()
			noclipConn = nil
		end
		if localPlayer.Character then
			local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum:ChangeState(Enum.HumanoidStateType.Running)
			end
			for _, part in ipairs(cachedCharacterParts) do
				if part.Name == "UpperTorso" or part.Name == "LowerTorso" or part.Name == "Torso" or part.Name == "CollisionPart" or part.Name == "Head" then
					part.CanCollide = true
				end
			end
		end
	end
end)

local infJumpConn: RBXScriptConnection? = nil
window:AddToggle(flightSection, "inf_jump", "Infinite Jump", false, nil, function(enabled)
	if enabled then
		infJumpConn = UserInputService.JumpRequest:Connect(function()
			if localPlayer.Character then
				local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
				if hum then
					hum:ChangeState(Enum.HumanoidStateType.Jumping)
				end
			end
		end)
	elseif infJumpConn then
		infJumpConn:Disconnect()
		infJumpConn = nil
	end
end)

window:AddSlider(flightSection, "Fly Speed", 10, 200, 50, function(value)
	flySpeed = value
end)

-- Right Column: Speed & Jump Modifiers (Persistent Locks)
local speedSection = window:AddSection(mfRightCol, "Speed & Jump Modifiers")

local activeSpeedLock: number? = nil
local activeJumpLock: number? = nil

local function enforcePersistentStats()
	if not humanoid or humanoid.Health <= 0 then return end
	if activeSpeedLock ~= nil and humanoid.WalkSpeed ~= activeSpeedLock then
		humanoid.WalkSpeed = activeSpeedLock
	end
	if activeJumpLock ~= nil and humanoid.JumpPower ~= activeJumpLock then
		humanoid.JumpPower = activeJumpLock
	end
end

RunService.RenderStepped:Connect(enforcePersistentStats)
RunService.Heartbeat:Connect(enforcePersistentStats)

window:AddToggle(speedSection, "walkspeed_boost", "WalkSpeed Boost (32 WS)", false, nil, function(enabled)
	activeSpeedLock = if enabled then 32 else nil
	if humanoid then
		humanoid.WalkSpeed = if enabled then 32 else 16
	end
end)

window:AddToggle(speedSection, "jumppower_boost", "JumpPower Boost (100 JP)", false, nil, function(enabled)
	activeJumpLock = if enabled then 100 else nil
	if humanoid then
		humanoid.JumpPower = if enabled then 100 else 50
	end
end)

window:AddSlider(speedSection, "Custom Speed", 16, 250, 16, function(value)
	activeSpeedLock = if value > 16 then value else nil
	if humanoid then
		humanoid.WalkSpeed = value
	end
end)

window:AddSlider(speedSection, "Custom JumpPower", 50, 300, 50, function(value)
	activeJumpLock = if value > 50 then value else nil
	if humanoid then
		humanoid.JumpPower = value
	end
end)

-- ── MAIN SUB-TAB 2: PHYSICS & MODIFIERS ──────────────────────
local physLeftCol, physRightCol = window:CreateColumns(physicsSubTab)

-- Left Column: Character Physics
local charPhysSection = window:AddSection(physLeftCol, "Character Physics")

local walkFlingConn: RBXScriptConnection? = nil
window:AddToggle(charPhysSection, "walk_fling", "Walk Fling (Touch To Fling)", false, nil, function(enabled)
	if enabled then
		walkFlingConn = RunService.Heartbeat:Connect(function()
			local char = localPlayer.Character
			if not char then return end
			local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local hum = char:FindFirstChildOfClass("Humanoid")
			if not (hrp and hum and hum.Health > 0) then return end

			hrp.AssemblyAngularVelocity = Vector3.new(0, 10000000, 0)
			local vel = hrp.AssemblyLinearVelocity
			hrp.AssemblyLinearVelocity = Vector3.new(vel.X, math.clamp(vel.Y, -100, 100), vel.Z)
		end)
	else
		if walkFlingConn then
			walkFlingConn:Disconnect()
			walkFlingConn = nil
		end
		local char = localPlayer.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hrp then
				hrp.AssemblyAngularVelocity = Vector3.zero
			end
		end
	end
end)

local ragdollWalkConn: RBXScriptConnection? = nil
local ragdollJumpConn: RBXScriptConnection? = nil
local lastRagdollJumpTime = 0
local cachedRagdollParts: {BasePart} = {}
local lastRagdollChar: Model? = nil
local wasRagdolled: boolean = false

local function refreshRagdollParts(char: Model)
	table.clear(cachedRagdollParts)
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local torso = (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("LowerTorso")) :: BasePart?
	if root then table.insert(cachedRagdollParts, root) end
	if torso and torso ~= root then table.insert(cachedRagdollParts, torso) end
	for _, p in ipairs(char:GetChildren()) do
		if p:IsA("BasePart") and (string.find(p.Name, "Torso") or string.find(p.Name, "Leg")) then
			if not table.find(cachedRagdollParts, p) then
				table.insert(cachedRagdollParts, p)
			end
		end
	end
end

window:AddToggle(charPhysSection, "ragdoll_walk_jump", "Ragdoll Walk & Space Jump", false, nil, function(enabled)
	if enabled then
		ragdollWalkConn = RunService.Heartbeat:Connect(function()
			local char = localPlayer.Character
			if not char then return end
			local hum = char:FindFirstChildOfClass("Humanoid")
			local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local torso = (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("LowerTorso")) :: BasePart?
			if not (hum and (root or torso) and hum.Health > 0) then return end

			local isRagdolled = char:GetAttribute("Ragdoll") == true
				or char:GetAttribute("Ragdolled") == true
				or char:FindFirstChild("Ragdoll") ~= nil
				or char:FindFirstChild("Ragdolled") ~= nil
				or hum.PlatformStand == true
				or hum.Sit == true
				or hum:GetState() == Enum.HumanoidStateType.Ragdoll
				or hum:GetState() == Enum.HumanoidStateType.Physics
				or hum:GetState() == Enum.HumanoidStateType.FallingDown
				or hum:GetState() == Enum.HumanoidStateType.PlatformStanding

			if isRagdolled then
				if not wasRagdolled or char ~= lastRagdollChar then
					lastRagdollChar = char
					wasRagdolled = true
					refreshRagdollParts(char)
				end

				local cam = Workspace.CurrentCamera
				if cam then
					local look = cam.CFrame.LookVector
					local right = cam.CFrame.RightVector
					local flatLook = Vector3.new(look.X, 0, look.Z)
					local flatRight = Vector3.new(right.X, 0, right.Z)

					local moveVec = Vector3.zero
					if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then moveVec += flatLook end
					if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then moveVec -= flatLook end
					if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then moveVec -= flatRight end
					if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then moveVec += flatRight end

					if moveVec.Magnitude > 0.05 then
						local dir = moveVec.Unit
						local speed = 36
						for _, p in ipairs(cachedRagdollParts) do
							p.AssemblyLinearVelocity = Vector3.new(dir.X * speed, p.AssemblyLinearVelocity.Y, dir.Z * speed)
						end
					end

					if UserInputService:IsKeyDown(Enum.KeyCode.Space) and (tick() - lastRagdollJumpTime > 0.28) then
						local mainPart = root or torso
						if mainPart and math.abs(mainPart.AssemblyLinearVelocity.Y) < 16 then
							lastRagdollJumpTime = tick()
							for _, p in ipairs(cachedRagdollParts) do
								p.AssemblyLinearVelocity = Vector3.new(p.AssemblyLinearVelocity.X, 54, p.AssemblyLinearVelocity.Z)
							end
						end
					end
				end
			else
				wasRagdolled = false
			end
		end)

		ragdollJumpConn = UserInputService.JumpRequest:Connect(function()
			local char = localPlayer.Character
			if not char then return end
			local hum = char:FindFirstChildOfClass("Humanoid")
			local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local torso = (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")) :: BasePart?
			if not (hum and (root or torso) and hum.Health > 0) then return end

			local isRagdolled = char:GetAttribute("Ragdoll") == true
				or hum.PlatformStand == true
				or hum.Sit == true
				or hum:GetState() == Enum.HumanoidStateType.Ragdoll
				or hum:GetState() == Enum.HumanoidStateType.Physics
				or hum:GetState() == Enum.HumanoidStateType.FallingDown

			if isRagdolled and (tick() - lastRagdollJumpTime > 0.28) then
				lastRagdollJumpTime = tick()
				if #cachedRagdollParts == 0 then
					refreshRagdollParts(char)
				end
				for _, p in ipairs(cachedRagdollParts) do
					p.AssemblyLinearVelocity = Vector3.new(p.AssemblyLinearVelocity.X, 54, p.AssemblyLinearVelocity.Z)
				end
			end
		end)
	else
		if ragdollWalkConn then
			ragdollWalkConn:Disconnect()
			ragdollWalkConn = nil
		end
		if ragdollJumpConn then
			ragdollJumpConn:Disconnect()
			ragdollJumpConn = nil
		end
		wasRagdolled = false
	end
end)

window:AddSlider(charPhysSection, "Hip Height Offset", 0, 20, 0, function(value)
	if localPlayer.Character then
		local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.HipHeight = value
		end
	end
end)

-- Right Column: Environment Physics
local envPhysSection = window:AddSection(physRightCol, "Environment Physics")

window:AddSlider(envPhysSection, "Custom Gravity", 0, 196, 196, function(value)
	Workspace.Gravity = value
end)

window:AddButton(envPhysSection, "Reset World Gravity", function()
	Workspace.Gravity = 196.2
	FeatureManager.setSliderValue("Custom Gravity", 196)
	window:Notify("Physics", "World gravity restored to default (196.2)", 2)
end)

window:AddButton(envPhysSection, "Reset Character Height", function()
	if localPlayer.Character then
		local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.HipHeight = 0
		end
	end
	FeatureManager.setSliderValue("Hip Height Offset", 0)
	window:Notify("Physics", "Character hip height restored to default", 2)
end)

-- ── MAIN SUB-TAB 3: PLAYER UTILITIES ─────────────────────────
local utilLeftCol, utilRightCol = window:CreateColumns(playerUtilsSubTab)

-- Left Column: Live Currencies & Leaderstats
local statsSection = window:AddSection(utilLeftCol, "Live Currencies & Leaderstats")

local statsContainer = Instance.new("Frame")
statsContainer.Name = "StatsContainer"
statsContainer.Size = UDim2.new(1, 0, 0, 0)
statsContainer.AutomaticSize = Enum.AutomaticSize.Y
statsContainer.BackgroundTransparency = 1
statsContainer.BorderSizePixel = 0
statsContainer.Parent = statsSection

local statsLayout = Instance.new("UIListLayout")
statsLayout.Padding = UDim.new(0, 4)
statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
statsLayout.Parent = statsContainer

local statRowFrames: {[string]: {Row: Frame, ValLabel: TextLabel}} = {}

local function renderCurrencies()
	local stats = PlayerUtilities.getCurrenciesAndStats()
	if #stats == 0 then
		local noStat = statRowFrames["_empty"]
		if not noStat then
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 24)
			row.BackgroundColor3 = UI.Theme.ContainerDark
			row.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
			row.BorderSizePixel = 0
			row.Parent = statsContainer
			UI.registerThemeElement(row, "ContainerDark")

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, -8, 1, 0)
			lbl.Position = UDim2.new(0, 4, 0, 0)
			lbl.BackgroundTransparency = 1
			lbl.Text = "No active currencies found in session"
			lbl.TextColor3 = UI.Theme.TextSecondary
			lbl.Font = UI.Fonts.Body
			lbl.TextSize = 10
			lbl.Parent = row
			UI.registerThemeElement(lbl, "TextSecondary")

			statRowFrames["_empty"] = {Row = row, ValLabel = lbl}
		end
		return
	end

	if statRowFrames["_empty"] then
		if statRowFrames["_empty"].Row and statRowFrames["_empty"].Row.Parent then
			statRowFrames["_empty"].Row:Destroy()
		end
		statRowFrames["_empty"] = nil
	end

	for idx, s in ipairs(stats) do
		local existing = statRowFrames[s.Name]
		if existing and existing.Row and existing.Row.Parent then
			existing.ValLabel.Text = s.Formatted or s.Value
		else
			local row = Instance.new("Frame")
			row.Name = s.Name .. "StatRow"
			row.Size = UDim2.new(1, 0, 0, 24)
			row.BackgroundColor3 = UI.Theme.Container
			row.BackgroundTransparency = UI.Theme.ContainerTransparency
			row.BorderSizePixel = 0
			row.LayoutOrder = idx
			row.Parent = statsContainer
			UI.registerThemeElement(row, "Container")

			local rStroke = Instance.new("UIStroke")
			rStroke.Color = UI.Theme.Border
			rStroke.Thickness = 1.0
			rStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			rStroke.Parent = row
			UI.registerThemeElement(rStroke, "Border")

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(0.55, -6, 1, 0)
			nameLabel.Position = UDim2.new(0, 6, 0, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = s.Name
			nameLabel.TextColor3 = UI.Theme.TextPrimary
			nameLabel.Font = UI.Fonts.Body
			nameLabel.TextSize = 10
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
			nameLabel.Parent = row
			UI.registerThemeElement(nameLabel, "TextPrimary")

			local valLabel = Instance.new("TextLabel")
			valLabel.Size = UDim2.new(0.45, -8, 1, 0)
			valLabel.Position = UDim2.new(0.55, 0, 0, 0)
			valLabel.BackgroundTransparency = 1
			valLabel.Text = s.Formatted or s.Value
			valLabel.TextColor3 = UI.Theme.Accent
			valLabel.Font = UI.Fonts.Mono
			valLabel.TextSize = 10
			valLabel.TextXAlignment = Enum.TextXAlignment.Right
			valLabel.TextTruncate = Enum.TextTruncate.AtEnd
			valLabel.Parent = row
			UI.registerThemeElement(valLabel, "AccentText")

			statRowFrames[s.Name] = {Row = row, ValLabel = valLabel}
		end
	end
end

-- Initial render
task.spawn(function()
	task.wait(0.5)
	pcall(renderCurrencies)
end)

-- Continuous auto-updater (0.25s high-frequency polling with reactive value change triggers)
local autoUpdateCurrencies = true
local refreshCurrenciesDebounced: thread? = nil
local function triggerInstantCurrencyRefresh()
	if not autoUpdateCurrencies then return end
	if refreshCurrenciesDebounced then task.cancel(refreshCurrenciesDebounced) end
	refreshCurrenciesDebounced = task.delay(0.04, function()
		pcall(renderCurrencies)
	end)
end

-- Hook value objects on LocalPlayer for 0ms latency UI updates
local function hookCurrencyFolder(folder: Instance)
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("ValueBase") then
			child.Changed:Connect(triggerInstantCurrencyRefresh)
		end
	end
	folder.ChildAdded:Connect(function(child)
		if child:IsA("ValueBase") then
			child.Changed:Connect(triggerInstantCurrencyRefresh)
		end
		triggerInstantCurrencyRefresh()
	end)
	folder.ChildRemoved:Connect(triggerInstantCurrencyRefresh)
end

for _, fName in ipairs({"leaderstats", "Data", "Stats", "Values", "Currencies", "PlayerData", "Tycoon"}) do
	local f = localPlayer:FindFirstChild(fName)
	if f then hookCurrencyFolder(f) end
end

localPlayer.ChildAdded:Connect(function(child)
	for _, fName in ipairs({"leaderstats", "Data", "Stats", "Values", "Currencies", "PlayerData", "Tycoon"}) do
		if child.Name == fName then
			hookCurrencyFolder(child)
			triggerInstantCurrencyRefresh()
			break
		end
	end
end)

localPlayer.AttributeChanged:Connect(triggerInstantCurrencyRefresh)

task.spawn(function()
	while true do
		task.wait(0.25)
		if autoUpdateCurrencies then
			pcall(renderCurrencies)
		end
	end
end)

window:AddButton(statsSection, "Refresh Currencies Now", function()
	renderCurrencies()
	window:Notify("Currencies", "Refreshed live leaderstats & currencies", 2)
end)

window:AddToggle(statsSection, "auto_refresh_currencies", "Fast Live Monitor (0.25s)", true, nil, function(enabled)
	autoUpdateCurrencies = enabled
end)

window:AddToggle(statsSection, "show_leaderstats_hud", "Show On-Screen Stats HUD Widget", true, nil, function(enabled)
	leaderstatsWidget.SetVisible(enabled)
end)

-- Left Column: Server & Session Utilities
local serverSection = window:AddSection(utilLeftCol, "Server & Session Utilities")

window:AddButton(serverSection, "Server Hop", function()
	PlayerUtilities.ServerHop()
end)

window:AddButton(serverSection, "Rejoin Current Server", function()
	PlayerUtilities.RejoinServer()
end)

window:AddButton(serverSection, "Copy Place ID", function()
	PlayerUtilities.CopyPlaceId()
end)

window:AddButton(serverSection, "Copy Game ID", function()
	PlayerUtilities.CopyGameId()
end)

window:AddButton(serverSection, "Copy Job / Server ID", function()
	PlayerUtilities.CopyJobId()
end)

-- Right Column: Automation & Tools
local toolSection = window:AddSection(utilRightCol, "Automation & Tools")

window:AddToggle(toolSection, "anti_afk", "Anti-AFK Timeout Preventer", false, nil, function(enabled)
	PlayerUtilities.SetAntiAFK(enabled)
end)

window:AddToggle(toolSection, "click_teleport", "Ctrl+Click Teleport Active", false, nil, function(enabled)
	PlayerUtilities.SetClickTeleportEnabled(enabled)
end)

window:AddButton(toolSection, "Give Click Teleport Tool", function()
	PlayerUtilities.GiveClickTeleportTool()
end)

-- ============================================================
-- 2. COMBAT TAB CONTENT (HORIZONTAL MINI SUB-TABS)
--    [ Aim Assistance ] [ Camera Tracking ] [ Hitbox Modifiers ]
-- ============================================================
local combatSubTabs = window:CreateSubTabs(combatTab, { "Aim Assistance", "Camera Tracking", "Hitbox Modifiers" })
local aimSubTab = combatSubTabs["Aim Assistance"]
local trackSubTab = combatSubTabs["Camera Tracking"]
local hitSubTab = combatSubTabs["Hitbox Modifiers"]

-- ── COMBAT SUB-TAB 1: AIM ASSISTANCE ─────────────────────────
local aimLeftCol, aimRightCol = window:CreateColumns(aimSubTab)

-- Left Column: Targeting & Silent Aim
local targetingSection = window:AddSection(aimLeftCol, "Targeting & Silent Aim")

window:AddToggle(targetingSection, "silent_aim", "Silent Aim", false, nil, function(enabled)
	Combat.SilentAim = enabled
end)

window:AddToggle(targetingSection, "wall_bang", "Wall Bang (Shoot Thru Walls)", false, nil, function(enabled)
	Combat.Wallbang = enabled
end)

window:AddToggle(targetingSection, "target_head", "Target Head (Off = Torso)", true, nil, function(enabled)
	Combat.TargetPart = if enabled then "Head" else "Torso"
end)

window:AddToggle(targetingSection, "track_teammates", "Track Teammates", false, nil, function(enabled)
	Combat.TrackTeammates = enabled
end)

-- Right Column: Automation & Modifiers
local firingSection = window:AddSection(aimRightCol, "Automation & Modifiers")

window:AddToggle(firingSection, "trigger_bot", "Trigger Bot", false, nil, function(enabled)
	Combat.TriggerBot = enabled
end)

window:AddSlider(firingSection, "TriggerBot Delay (ms)", 0, 500, 50, function(value)
	Combat.TriggerBotDelay = value / 1000
end)

window:AddSlider(firingSection, "Wallbang Thickness", 0, 25, 5, function(value)
	Combat.WallbangThickness = value
end)

window:AddSlider(firingSection, "Hit Chance %", 10, 100, 100, function(value)
	Combat.HitChance = value
end)

window:AddSlider(firingSection, "Aim Smoothing", 5, 100, 25, function(value)
	Combat.Smoothing = value / 100
end)

-- ── COMBAT SUB-TAB 2: CAMERA TRACKING ────────────────────────
local trackLeftCol, trackRightCol = window:CreateColumns(trackSubTab)

-- Left Column: Camera Lock Modes
local lockModesSection = window:AddSection(trackLeftCol, "Camera Lock Modes")

window:AddToggle(lockModesSection, "aim_tracking", "Aim Tracking (Camera Lock)", false, nil, function(enabled)
	Combat.AimTracking = enabled
end)

window:AddToggle(lockModesSection, "aim_always", "Always Lock (Ignore RMB Hold)", false, nil, function(enabled)
	Combat.AimMode = if enabled then "Always" else "Hold RMB"
end)

-- Right Column: FOV Dynamics & Colors
local fovSection = window:AddSection(trackRightCol, "FOV Dynamics & Colors")

window:AddToggle(fovSection, "fov_circle", "FOV Circle (Visualizer)", false, nil, function(enabled)
	Combat.FovCircle = enabled
end)

window:AddSlider(fovSection, "FOV Radius", 30, 450, 120, function(value)
	Combat.FovRadius = value
end)

window:AddButton(fovSection, "Cyan FOV Circle", function()
	Combat.setFovColor(Color3.fromRGB(55, 175, 245))
	window:Notify("Combat", "Cyan FOV circle color applied", 2)
end)

window:AddButton(fovSection, "Crimson Red FOV", function()
	Combat.setFovColor(Color3.fromRGB(245, 60, 60))
	window:Notify("Combat", "Red FOV circle color applied", 2)
end)

window:AddButton(fovSection, "White FOV Circle", function()
	Combat.setFovColor(Color3.fromRGB(255, 255, 255))
	window:Notify("Combat", "White FOV circle color applied", 2)
end)

window:AddButton(fovSection, "Lime Green FOV", function()
	Combat.setFovColor(Color3.fromRGB(50, 220, 80))
	window:Notify("Combat", "Green FOV circle color applied", 2)
end)

-- ── COMBAT SUB-TAB 3: HITBOX MODIFIERS ───────────────────────
local hitLeftCol, hitRightCol = window:CreateColumns(hitSubTab)

-- Left Column: Hitbox Expansion
local hitExpSection = window:AddSection(hitLeftCol, "Hitbox Expansion")

window:AddToggle(hitExpSection, "expand_hitboxes", "Expand Hitboxes", false, nil, function(enabled)
	Combat.ExpandHitboxes = enabled
	if not enabled then
		Combat.resetHitboxes()
	end
end)

window:AddSlider(hitExpSection, "Hitbox Size", 2, 30, 12, function(value)
	Combat.HitboxSize = value
end)

-- Right Column: Hitbox Operations
local hitOpsSection = window:AddSection(hitRightCol, "Hitbox Operations")

window:AddButton(hitOpsSection, "Reset All Hitboxes", function()
	Combat.resetHitboxes()
	window:Notify("Hitboxes", "All player hitboxes restored to default", 2.5)
end)

-- ============================================================
-- 3. GAME TAB CONTENT (RUN N HIDE / DISASTER SURVIVAL)
--    [ Weapons & Firepower ] [ Bounds & Barriers ] [ Mobility & Items ]
-- ============================================================
if gameTabTitle == "Run N Hide" then
	local rnhSubTabs = window:CreateSubTabs(gameTab, { "Weapons & Firepower", "Bounds & Barriers", "Mobility & Items" })
	local weaponSubTab = rnhSubTabs["Weapons & Firepower"]
	local boundsSubTab = rnhSubTabs["Bounds & Barriers"]
	local mobilitySubTab = rnhSubTabs["Mobility & Items"]

	-- ── GAME SUB-TAB 1: WEAPONS & FIREPOWER ───────────────────
	local wepLeftCol, wepRightCol = window:CreateColumns(weaponSubTab)

	local weaponMechSection = window:AddSection(wepLeftCol, "Weapon Mechanisms")

	window:AddToggle(weaponMechSection, "rnh_silent_audio", "Silent Gun Audio (Mute)", true, nil, function(val)
		RunNHide.SilentGunAudio = val
		RunNHide.updateWeapons(true)
	end)

	window:AddToggle(weaponMechSection, "rnh_quick_reload", "Quick Reload & Instant Rack", false, nil, function(val)
		RunNHide.QuickReload = val
		RunNHide.AutoChamber = val
		RunNHide.updateWeapons()
	end)

	window:AddToggle(weaponMechSection, "rnh_complete_auto", "Complete Auto (All Guns)", false, nil, function(val)
		RunNHide.CompleteAuto = val
		if val then
			RunNHide.SemiAutoForce = false
			RunNHide.BurstMode = false
		end
		RunNHide.updateWeapons()
	end)

	window:AddToggle(weaponMechSection, "rnh_semi_auto", "The Semi-Auto Force", false, nil, function(val)
		RunNHide.SemiAutoForce = val
		if val then
			RunNHide.CompleteAuto = false
			RunNHide.BurstMode = false
		end
		RunNHide.updateWeapons()
	end)

	window:AddToggle(weaponMechSection, "rnh_burst_mode", "The Burst Rounds", false, nil, function(val)
		RunNHide.BurstMode = val
		if val then
			RunNHide.CompleteAuto = false
			RunNHide.SemiAutoForce = false
		end
		RunNHide.updateWeapons()
	end)

	local fireOverclockSection = window:AddSection(wepRightCol, "Overclocks & Actions")

	window:AddToggle(fireOverclockSection, "rnh_no_recoil", "Zero Recoil", false, nil, function(val)
		RunNHide.NoRecoil = val
		RunNHide.updateWeapons()
	end)

	window:AddToggle(fireOverclockSection, "rnh_fast_fire", "Rapid Fire Rate Overclock", false, nil, function(val)
		RunNHide.FastFireRate = val
		RunNHide.updateWeapons()
	end)

	window:AddSlider(fireOverclockSection, "Burst Shot Count", 2, 10, 3, function(val)
		RunNHide.BurstCount = val
	end)

	window:AddSlider(fireOverclockSection, "Burst Delay (ms)", 20, 150, 60, function(val)
		RunNHide.BurstDelay = val / 1000
	end)

	window:AddButton(fireOverclockSection, "Force Instant Reload", function()
		if RunNHide.forceReload() then
			window:Notify("Run N Hide", "Weapon reloaded & chambered", 3)
		else
			window:Notify("Run N Hide", "No gun equipped", 3)
		end
	end)

	window:AddButton(fireOverclockSection, "Chamber Equipped Weapon", function()
		if RunNHide.forceChamber() then
			window:Notify("Run N Hide", "Weapon chambered", 3)
		else
			window:Notify("Run N Hide", "No gun equipped", 3)
		end
	end)

	-- ── GAME SUB-TAB 2: BOUNDS & BARRIERS ─────────────────────
	local bndLeftCol, bndRightCol = window:CreateColumns(boundsSubTab)

	local boundsSection = window:AddSection(bndLeftCol, "Boundary Removal")

	window:AddToggle(boundsSection, "rnh_disable_barriers", "Disable Map Bounds & Barriers", false, nil, function(val)
		RunNHide.DisableBarriers = val
		if val then
			local count = RunNHide.scanAndDisableBoundaries()
			window:Notify("Bounds", string.format("Barriers & clips disabled (%d checked)", count), 3)
		end
	end)

	window:AddToggle(boundsSection, "rnh_disable_kill", "Disable Kill Bricks & Death Zones", false, nil, function(val)
		RunNHide.DisableKillbricks = val
		if val then
			RunNHide.scanAndDisableBoundaries()
			window:Notify("Bounds", "Killbricks & death zones neutralized", 3)
		end
	end)

	local voidSection = window:AddSection(bndRightCol, "Void Safety & Audits")

	window:AddToggle(voidSection, "rnh_anti_void", "Anti-Void Safety Floor", false, nil, function(val)
		RunNHide.AntiVoidFloor = val
		RunNHide.ensureVoidPlatform()
	end)

	window:AddButton(voidSection, "Audit & Disable All Bounds Now", function()
		RunNHide.DisableBarriers = true
		RunNHide.DisableKillbricks = true
		local count = RunNHide.scanAndDisableBoundaries()
		window:Notify("Audit", string.format("Neutralized %d boundaries & killbricks", count), 3.5)
	end)

	-- ── GAME SUB-TAB 3: MOBILITY & ITEMS ──────────────────────
	local mobLeftCol, mobRightCol = window:CreateColumns(mobilitySubTab)

	local staminaSection = window:AddSection(mobLeftCol, "Stamina & Ragdoll")

	window:AddToggle(staminaSection, "rnh_inf_stamina", "Infinite Stamina", false, nil, function(val)
		RunNHide.InfiniteStamina = val
	end)

	window:AddToggle(staminaSection, "rnh_fast_regen", "Hyper Fast Stamina Regen", false, nil, function(val)
		RunNHide.FastRegen = val
	end)

	window:AddToggle(staminaSection, "rnh_move_ragdoll", "Move In Ragdoll (WASD)", false, nil, function(val)
		RunNHide.MoveInRagdoll = val
	end)

	window:AddToggle(staminaSection, "rnh_auto_stand", "Auto Standup (Anti-Knockdown)", false, nil, function(val)
		RunNHide.AutoStandup = val
	end)

	window:AddSlider(staminaSection, "Ragdoll Speed", 16, 80, 32, function(val)
		RunNHide.RagdollSpeed = val
	end)

	local itemSection = window:AddSection(mobRightCol, "Item & Role Tracker")

	window:AddToggle(itemSection, "rnh_role_tracker", "Role Tracker & ESP", false, nil, function(val)
		RunNHide.RoleTracker = val
	end)

	window:AddToggle(itemSection, "rnh_auto_grab", "Auto-Grab Dropped Weapons", false, nil, function(val)
		RunNHide.AutoGrabWeapons = val
	end)

	window:AddButton(itemSection, "Grab All Scattered Guns Now", function()
		local count = RunNHide.grabAllScatteredWeapons()
		window:Notify("Weapons", string.format("Claimed %d dropped guns", count), 3)
	end)

	window:AddButton(itemSection, "Teleport to PVP Arena", function()
		if RunNHide.teleportToArena() then
			window:Notify("Arena", "Teleported to PVP Arena loadout zone", 3)
		end
	end)
elseif gameTabTitle == "Natural Disaster" then
	-- Disaster Survival Sub-Tabs (4 tabs — all in ONE CreateSubTabs call)
	local ndsSubTabs = window:CreateSubTabs(gameTab, {
		"Disaster Intelligence",
		"Mobility & Flight",
		"Physics & Protection",
		"World & Vehicles",
	})
	local disSubTab   = ndsSubTabs["Disaster Intelligence"]
	local mobSubTab   = ndsSubTabs["Mobility & Flight"]
	local phySubTab   = ndsSubTabs["Physics & Protection"]
	local worldSubTab = ndsSubTabs["World & Vehicles"]

	-- ── DISASTER INTELLIGENCE ─────────────────────────────────────
	local disLeftCol, disRightCol = window:CreateColumns(disSubTab)
	local disasterSection = window:AddSection(disLeftCol, "Disaster Monitor")

	window:AddToggle(disasterSection, "disaster_tracker", "Disaster Tracker", false, nil, function(enabled)
		DisasterSurvival.DisasterTracker = enabled
		if enabled and DisasterSurvival.CurrentDisaster ~= "None (In Lobby)" and DisasterSurvival.CurrentDisaster ~= "" then
			window:Notify("Current Disaster", DisasterSurvival.CurrentDisaster, 3.5)
		end
	end)

	window:AddButton(disasterSection, "Check Current Disaster", function()
		local tag = localPlayer.Character and localPlayer.Character:FindFirstChild("SurvivalTag")
		local cur = if tag and tag:IsA("StringValue") and tag.Value ~= "" then tag.Value else "None (In Lobby)"
		window:Notify("Disaster Status", cur, 3.5)
	end)

	local fallSection = window:AddSection(disRightCol, "Fall Damage Bypass")
	window:AddToggle(fallSection, "no_fall_damage", "No Fall Damage", false, nil, function(enabled)
		DisasterSurvival.setNoFallDamage(enabled)
	end)

	-- ── MOBILITY & FLIGHT ─────────────────────────────────────────
	local mobLeftCol, mobRightCol = window:CreateColumns(mobSubTab)
	local fltSection = window:AddSection(mobLeftCol, "Flight Navigation")
	window:AddToggle(fltSection, "flight_no_fall", "Flight No Fall Damage", false, nil, function(enabled)
		DisasterSurvival.setFlight(enabled)
	end)

	local spdSection = window:AddSection(mobRightCol, "Flight Velocity")
	window:AddSlider(spdSection, "Flight Speed", 20, 150, 50, function(value)
		DisasterSurvival.FlightSpeed = value
	end)

	-- ── PHYSICS & PROTECTION ──────────────────────────────────────
	local phyLeftCol, phyRightCol = window:CreateColumns(phySubTab)
	local protSection = window:AddSection(phyLeftCol, "Protection & Physics")
	window:AddToggle(protSection, "anti_fling", "Anti-Fling Protection", false, nil, function(enabled)
		DisasterSurvival.setAntiFling(enabled)
	end)

	window:AddToggle(protSection, "anti_object_kill", "Anti-Object-Kill Shield", false, nil, function(enabled)
		DisasterSurvival.setAntiObjectKill(enabled)
	end)

	local flngSection = window:AddSection(phyRightCol, "Physics Fling")
	window:AddToggle(flngSection, "player_fling", "Object / Player Fling", false, nil, function(enabled)
		DisasterSurvival.setFling(enabled)
	end)

	-- ── WORLD & VEHICLES ─────────────────────────────────────────
	local worldLeftCol, worldRightCol = window:CreateColumns(worldSubTab)

	local carSection = window:AddSection(worldLeftCol, "Vehicle Exploits")
	window:AddToggle(carSection, "nds_car_drive", "Custom Car Driving (W/A/S/D)", false, nil, function(enabled)
		DisasterSurvival.setCarDriving(enabled)
	end)

	window:AddButton(carSection, "Enter Nearest Car", function()
		local cars = DisasterSurvival.scanCars()
		if #cars == 0 then
			window:Notify("Cars", "No VehicleSeats found in map", 3)
			return
		end
		local char = localPlayer.Character
		local hrp  = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then window:Notify("Cars", "No character found", 3) return end

		local best: VehicleSeat? = nil
		local bestDist = math.huge
		for _, seat in ipairs(cars) do
			if not seat.Occupant then
				local d = (seat.Position - hrp.Position).Magnitude
				if d < bestDist then bestDist = d best = seat end
			end
		end

		if best then
			-- Teleport HRP onto seat — proximity trigger fires the SeatWeld automatically
			DisasterSurvival.sitInCar(best)
			window:Notify("Cars", string.format("Warped to car (%.1f studs) — W/A/S/D to drive", bestDist), 3.5)
		else
			window:Notify("Cars", "No unoccupied car found", 3)
		end
	end)

	window:AddButton(carSection, "Exit Car", function()
		DisasterSurvival.exitCar()
		window:Notify("Cars", "Exited vehicle", 2)
	end)

	local dragSection = window:AddSection(worldRightCol, "Object Interaction")
	window:AddToggle(dragSection, "nds_obj_drag", "Loose Object Drag (LMB hold = grab, release = drop)", false, nil, function(enabled)
		DisasterSurvival.setObjectDrag(enabled)
	end)
elseif gameTabTitle == "Ice Tycoon" then
	local iceSubTabs = window:CreateSubTabs(gameTab, { "Tycoon Automation", "Resources & Farming", "Protections & Zones" })
	local autoSubTab = iceSubTabs["Tycoon Automation"]
	local farmSubTab = iceSubTabs["Resources & Farming"]
	local zoneSubTab = iceSubTabs["Protections & Zones"]

	-- ── 1. TYCOON AUTOMATION ─────────────────────────────────────
	local autoLeftCol, autoRightCol = window:CreateColumns(autoSubTab)

	local convSection = window:AddSection(autoLeftCol, "Conveyors & Generators")
	window:AddToggle(convSection, "ice_fast_conveyors", "Fast Conveyors (Speed Boost)", false, nil, function(enabled)
		IceTycoon.setFastConveyors(enabled)
	end)

	window:AddSlider(convSection, "Conveyor Speed", 15, 250, 75, function(value)
		IceTycoon.setConveyorSpeed(value)
	end)

	window:AddToggle(convSection, "ice_fast_generators", "Turbo Generators & Droppers", false, nil, function(enabled)
		IceTycoon.setFastGenerators(enabled)
	end)

	window:AddSlider(convSection, "Generator Dropper Velocity", 30, 300, 120, function(value)
		IceTycoon.setGeneratorSpeed(value)
	end)

	window:AddToggle(convSection, "ice_ore_magnet", "Ore Vacuum / Magnet to Collector", false, nil, function(enabled)
		IceTycoon.setOreMagnet(enabled)
	end)

	window:AddToggle(convSection, "ice_dup_sells", "Duplicated Proximity Sell Nodes", false, nil, function(enabled)
		IceTycoon.setDuplicatedSellNodes(enabled)
	end)

	local cashSection = window:AddSection(autoLeftCol, "Cash Collection")
	window:AddToggle(cashSection, "ice_auto_collect", "Auto-Collect Tycoon Cash", false, nil, function(enabled)
		IceTycoon.setAutoCollect(enabled)
	end)

	window:AddButton(cashSection, "Collect Cash Now", function()
		if IceTycoon.collectCashNow() then
			window:Notify("Ice Tycoon", "Cash collected from factory", 2.5)
		else
			window:Notify("Ice Tycoon", "Collector not found", 2.5)
		end
	end)

	local buySection = window:AddSection(autoRightCol, "Button Purchases")
	window:AddToggle(buySection, "ice_auto_buy", "Auto-Buy Affordable Buttons", false, nil, function(enabled)
		IceTycoon.setAutoBuy(enabled)
	end)

	window:AddToggle(buySection, "ice_smart_buy", "Smart Priority Buy (Droppers/Upgrades 1st)", true, nil, function(enabled)
		IceTycoon.SmartPriorityBuy = enabled
	end)

	window:AddButton(buySection, "Buy All Affordable Now", function()
		local count = IceTycoon.buyAllAffordable()
		window:Notify("Ice Tycoon", string.format("Purchased %d affordable buttons", count), 3)
	end)

	-- ── 2. RESOURCES & FARMING ───────────────────────────────────
	local farmLeftCol, farmRightCol = window:CreateColumns(farmSubTab)

	local toolSection = window:AddSection(farmLeftCol, "Tools & Dispensers")
	window:AddButton(toolSection, "Claim Starter Tools & Keys", function()
		local count = IceTycoon.claimAllTools()
		window:Notify("Ice Tycoon", string.format("Claimed %d tools/keys (Pickaxe, Key, Lever)", count), 3)
	end)

	window:AddToggle(toolSection, "ice_auto_water", "Auto-Fill Water Reservoir", false, nil, function(enabled)
		IceTycoon.setAutoFillWater(enabled)
	end)

	window:AddButton(toolSection, "Fill Water Tank Now", function()
		if IceTycoon.fillWaterNow() then
			window:Notify("Ice Tycoon", "Water reservoir filled", 2.5)
		else
			window:Notify("Ice Tycoon", "No water source nearby", 2.5)
		end
	end)

	local crystalSection = window:AddSection(farmRightCol, "Mining & Trophies")
	window:AddToggle(crystalSection, "ice_auto_mine", "Auto-Mine Available Ores", false, nil, function(enabled)
		IceTycoon.setAutoMineOres(enabled)
	end)

	window:AddButton(crystalSection, "Mine All Ores Now", function()
		local count = IceTycoon.mineOresNow()
		window:Notify("Ice Tycoon", string.format("Mined %d ore nodes", count), 2.5)
	end)

	window:AddToggle(crystalSection, "ice_auto_secrets", "Auto-Collect Trophies & Secrets", false, nil, function(enabled)
		IceTycoon.setAutoCollectSecrets(enabled)
	end)

	window:AddButton(crystalSection, "Collect All Trophies & Secrets Now", function()
		local res = IceTycoon.collectAllSecretsNow()
		window:Notify("Ice Tycoon", string.format("Claimed %d gems, %d trophies, %d secrets", res.Gems, res.Trophies, res.Secrets), 3.5)
	end)

	local armySection = window:AddSection(farmRightCol, "Sphere Army & Combat")
	window:AddToggle(armySection, "ice_auto_army", "Sphere Army Auto-Battler & Spawner", false, nil, function(enabled)
		IceTycoon.setAutoArmyFight(enabled)
	end)

	window:AddButton(armySection, "Spawn Army Reinforcements Now", function()
		local count = IceTycoon.spawnArmyUnits(8, 8)
		window:Notify("Sphere Army", string.format("Spawned %d Noob and Knight units", count), 3)
	end)

	window:AddButton(armySection, "Command Army to Attack", function()
		if IceTycoon.commandAttack() then
			window:Notify("Sphere Army", "Commanded army units into battle!", 2.5)
		end
	end)

	-- ── 3. PROTECTIONS & ZONES ───────────────────────────────────
	local zoneLeftCol, zoneRightCol = window:CreateColumns(zoneSubTab)

	local protectSection = window:AddSection(zoneLeftCol, "Environment Protections")
	window:AddToggle(protectSection, "ice_anti_freeze", "Anti-Freeze & Shiver Bypass", false, nil, function(enabled)
		IceTycoon.setAntiFreeze(enabled)
	end)

	window:AddToggle(protectSection, "ice_anti_jumpscare", "Anti-Jumpscare Shock Shield", false, nil, function(enabled)
		IceTycoon.setAntiJumpscare(enabled)
	end)

	window:AddToggle(protectSection, "ice_no_lava", "No Lava & Hazard Damage", false, nil, function(enabled)
		IceTycoon.setNoLavaDamage(enabled)
	end)

	local tpSection = window:AddSection(zoneRightCol, "Zone Shortcuts")
	window:AddButton(tpSection, "Tycoon Base / Collector", function()
		if IceTycoon.teleportTo("Tycoon Base / Collector") then
			window:Notify("Teleport", "Warped to Tycoon Base", 2)
		end
	end)

	window:AddButton(tpSection, "Lava Cave & Crystal Hatch", function()
		if IceTycoon.teleportTo("Lava Cave & Crystal Hatch") then
			window:Notify("Teleport", "Warped to Lava Cave", 2)
		end
	end)

	window:AddButton(tpSection, "Troop Shop 1", function()
		if IceTycoon.teleportTo("Troop Shop 1") then
			window:Notify("Teleport", "Warped to Troop Shop 1", 2)
		end
	end)

	window:AddButton(tpSection, "Jail & Lever Room", function()
		if IceTycoon.teleportTo("Jail & Lever Room") then
			window:Notify("Teleport", "Warped to Jail", 2)
		end
	end)

	window:AddButton(tpSection, "Ending Portal Zone", function()
		if IceTycoon.teleportTo("Ending Portal Zone") then
			window:Notify("Teleport", "Warped to Ending Portal", 2)
		end
	end)
end

-- ============================================================
-- ============================================================
-- 4. VISUALS TAB CONTENT (HORIZONTAL MINI SUB-TABS)
--    [ 2D Overlays & ESP ] [ 3D Chams & Skeletons ] [ ESP Customizer ]
-- ============================================================
local visSubTabs = window:CreateSubTabs(visualsTab, { "2D Overlays & ESP", "3D Chams & Skeletons", "ESP Customizer" })
local esp2dSubTab = visSubTabs["2D Overlays & ESP"]
local chamsSubTab = visSubTabs["3D Chams & Skeletons"]
local customSubTab = visSubTabs["ESP Customizer"]

-- ── VISUALS SUB-TAB 1: 2D OVERLAYS & ESP ─────────────────────
local v2dLeftCol, v2dRightCol = window:CreateColumns(esp2dSubTab)

-- Left Column: 2D Bounding Boxes
local boxSection = window:AddSection(v2dLeftCol, "2D Bounding Boxes")

window:AddToggle(boxSection, "esp_box_2d", "2D ESP Box", false, nil, function(enabled)
	Visuals.Box2D = enabled
end)

window:AddToggle(boxSection, "esp_box_outlines", "ESP Box Outlines (Black Contrast)", false, nil, function(enabled)
	Visuals.BoxOutlines = enabled
end)

window:AddToggle(boxSection, "esp_health_bar", "Health Bar (Dynamic Green/Red)", false, nil, function(enabled)
	Visuals.HealthBar = enabled
end)

window:AddToggle(boxSection, "esp_distance", "Distance Tags (Studs)", false, nil, function(enabled)
	Visuals.Distance = enabled
end)

-- Right Column: Tracers & HUD Widgets
local tracerSection = window:AddSection(v2dRightCol, "Tracers & HUD Widgets")

window:AddToggle(tracerSection, "esp_tracers", "Snapline Tracers", false, nil, function(enabled)
	Visuals.Tracers = enabled
end)

window:AddToggle(tracerSection, "music_tracker_widget", "Music Tracker Widget", true, nil, function(enabled)
	musicTrackerWidget.SetVisible(enabled)
end)

window:AddToggle(tracerSection, "hud_leaderstats_widget", "Live Leaderstats & Currencies HUD", true, nil, function(enabled)
	leaderstatsWidget.SetVisible(enabled)
end)

window:AddToggle(tracerSection, "hud_healthbar_widget", "Health Bar HUD Widget", true, nil, function(enabled)
	healthWidget.SetVisible(enabled)
end)

window:AddToggle(tracerSection, "hud_damage_indicators", "3D Floating Damage Numbers", true, nil, function(enabled)
	healthWidget.ToggleDamageNumbers(enabled)
end)

window:AddToggle(tracerSection, "hud_damage_flash", "Damage Taken Screen Flash", true, nil, function(enabled)
	healthWidget.ToggleDamageFlash(enabled)
end)

window:AddToggle(tracerSection, "hud_dynamic_health_color", "Dynamic Health Gradient (Green/Red)", true, nil, function(enabled)
	healthWidget.SetDynamicColors(enabled)
end)

-- ── VISUALS SUB-TAB 2: 3D CHAMS & SKELETONS ──────────────────
local chmLeftCol, chmRightCol = window:CreateColumns(chamsSubTab)

-- Left Column: 3D Highlights & Chams
local chamsSection = window:AddSection(chmLeftCol, "3D Highlights & Chams")

window:AddToggle(chamsSection, "esp_chams_3d", "3D Chams / Highlights", false, nil, function(enabled)
	Visuals.Chams = enabled
end)

window:AddSlider(chamsSection, "Chams Transparency", 0, 100, 50, function(value)
	Visuals.ChamsTransparency = value / 100
end)

window:AddSlider(chamsSection, "Chams Outline Transparency", 0, 100, 20, function(value)
	Visuals.ChamsOutlineTransparency = value / 100
end)

-- Right Column: Skeletons & Colors
local skeletonSection = window:AddSection(chmRightCol, "Skeletons & Colors")

window:AddToggle(skeletonSection, "esp_skeletons", "Skeleton ESP (Bone Rigs)", false, nil, function(enabled)
	Visuals.Skeleton = enabled
end)

window:AddButton(skeletonSection, "Purple / Magenta Chams", function()
	Visuals.ChamsColor = Color3.fromRGB(180, 70, 255)
	Visuals.ChamsFillColor = Color3.fromRGB(180, 70, 255)
	window:Notify("Chams", "Applied Purple / Magenta Chams", 2)
end)

window:AddButton(skeletonSection, "Cyan / Blue Chams", function()
	Visuals.ChamsColor = Color3.fromRGB(55, 175, 245)
	Visuals.ChamsFillColor = Color3.fromRGB(55, 175, 245)
	window:Notify("Chams", "Applied Cyan / Blue Chams", 2)
end)

window:AddButton(skeletonSection, "Red / Crimson Chams", function()
	Visuals.ChamsColor = Color3.fromRGB(245, 60, 60)
	Visuals.ChamsFillColor = Color3.fromRGB(245, 60, 60)
	window:Notify("Chams", "Applied Red / Crimson Chams", 2)
end)

window:AddButton(skeletonSection, "Gold / Yellow Chams", function()
	Visuals.ChamsColor = Color3.fromRGB(255, 200, 50)
	Visuals.ChamsFillColor = Color3.fromRGB(255, 200, 50)
	window:Notify("Chams", "Applied Gold / Yellow Chams", 2)
end)

-- ── VISUALS SUB-TAB 3: ESP CUSTOMIZER ────────────────────────
local cstLeftCol, cstRightCol = window:CreateColumns(customSubTab)

-- Left Column: Tracer Origin Selector
local originSection = window:AddSection(cstLeftCol, "Tracer Origin Selector")

window:AddButton(originSection, "Tracer Origin: Bottom", function()
	Visuals.TracerOrigin = "Bottom"
	window:Notify("Tracers", "Tracer origin set to Screen Bottom", 2)
end)

window:AddButton(originSection, "Tracer Origin: Center", function()
	Visuals.TracerOrigin = "Center"
	window:Notify("Tracers", "Tracer origin set to Screen Center", 2)
end)

window:AddButton(originSection, "Tracer Origin: Mouse", function()
	Visuals.TracerOrigin = "Mouse"
	window:Notify("Tracers", "Tracer origin set to Mouse Cursor", 2)
end)

-- Right Column: ESP Palette Presets
local paletteSection = window:AddSection(cstRightCol, "ESP Palette Presets")

window:AddButton(paletteSection, "Default Cyan Palette", function()
	Visuals.BoxColor = Color3.fromRGB(55, 175, 245)
	Visuals.TracerColor = Color3.fromRGB(255, 255, 255)
	Visuals.SkeletonColor = Color3.fromRGB(255, 200, 50)
	window:Notify("Palette", "Default Cyan Palette applied", 2)
end)

window:AddButton(paletteSection, "Emerald Green Palette", function()
	Visuals.BoxColor = Color3.fromRGB(50, 220, 80)
	Visuals.TracerColor = Color3.fromRGB(50, 220, 80)
	Visuals.SkeletonColor = Color3.fromRGB(120, 255, 140)
	window:Notify("Palette", "Emerald Green Palette applied", 2)
end)

window:AddButton(paletteSection, "Ruby Red Palette", function()
	Visuals.BoxColor = Color3.fromRGB(245, 60, 60)
	Visuals.TracerColor = Color3.fromRGB(245, 60, 60)
	Visuals.SkeletonColor = Color3.fromRGB(255, 120, 120)
	window:Notify("Palette", "Ruby Palette applied", 2)
end)

window:AddButton(paletteSection, "Amethyst Purple Palette", function()
	Visuals.BoxColor = Color3.fromRGB(180, 70, 255)
	Visuals.TracerColor = Color3.fromRGB(220, 120, 255)
	Visuals.SkeletonColor = Color3.fromRGB(200, 100, 255)
	window:Notify("Palette", "Amethyst Palette applied", 2)
end)

-- ============================================================
-- 5. SETTINGS TAB CONTENT (HORIZONTAL MINI SUB-TABS)
--    [ Modules & Tabs ] [ Themes & Visuals ] [ Performance & Rendering ] [ System & Audio ]
-- ============================================================
local setSubTabs = window:CreateSubTabs(settingsTab, { "Modules & Tabs", "Themes & Visuals", "Performance & Rendering", "System & Audio" })
local modSubTab = setSubTabs["Modules & Tabs"]
local thmSubTab = setSubTabs["Themes & Visuals"]
local prfSubTab = setSubTabs["Performance & Rendering"]
local sysSubTab = setSubTabs["System & Audio"]

-- ── SETTINGS SUB-TAB 1: MODULES & TABS ───────────────────────
local modLeftCol, modRightCol = window:CreateColumns(modSubTab)

-- Left Column: Sidebar Tab Visibility
local moduleSection = window:AddSection(modLeftCol, "Sidebar Tab Visibility")

window:AddToggle(moduleSection, "tab_game_module", string.format("%s (Game Tab)", gameTabTitle), true, nil, function(enabled)
	FeatureManager.setModuleState("game_module", enabled)
	window:SetTabVisibility(gameTab, enabled)
	if not enabled then
		RunNHide.SilentGunAudio = false
		RunNHide.QuickReload = false
		RunNHide.CompleteAuto = false
		RunNHide.DisableBarriers = false
		RunNHide.DisableKillbricks = false
		DisasterSurvival.DisasterTracker = false
		DisasterSurvival.setNoFallDamage(false)
		DisasterSurvival.setFlight(false)
		DisasterSurvival.setAntiFling(false)
		DisasterSurvival.setFling(false)
		IceTycoon.cleanup()
	end
end)

window:AddToggle(moduleSection, "tab_combat_module", "Combat (Aim & Hitboxes)", true, nil, function(enabled)
	FeatureManager.setModuleState("combat", enabled)
	window:SetTabVisibility(combatTab, enabled)
	if not enabled then
		Combat.SilentAim = false
		Combat.AimTracking = false
		Combat.TriggerBot = false
		Combat.ExpandHitboxes = false
		Combat.resetHitboxes()
	end
end)

window:AddToggle(moduleSection, "tab_visuals_module", "Visuals (ESP & Chams)", true, nil, function(enabled)
	FeatureManager.setModuleState("visuals", enabled)
	window:SetTabVisibility(visualsTab, enabled)
	if not enabled then
		Visuals.Box2D = false
		Visuals.BoxOutlines = false
		Visuals.HealthBar = false
		Visuals.Tracers = false
		Visuals.Distance = false
		Visuals.Chams = false
		Visuals.Skeleton = false
	end
end)

window:AddButton(moduleSection, string.format("Hide %s Tab", gameTabTitle), function()
	window:SetTabVisibility(gameTab, false)
	FeatureManager.setFeatureState("tab_game_module", false)
	window:Notify("Tab Hidden", string.format("%s tab hidden from sidebar", gameTabTitle), 2.5)
end)

window:AddButton(moduleSection, "Show All Sidebar Tabs", function()
	window:SetTabVisibility(gameTab, true)
	window:SetTabVisibility(combatTab, true)
	window:SetTabVisibility(visualsTab, true)
	FeatureManager.setFeatureState("tab_game_module", true)
	FeatureManager.setFeatureState("tab_combat_module", true)
	FeatureManager.setFeatureState("tab_visuals_module", true)
	window:Notify("Tabs Restored", "All sidebar tabs are now visible", 2.5)
end)

-- Right Column: Peripheral Widgets
local widgetSection = window:AddSection(modRightCol, "Peripheral Widgets")

window:AddToggle(widgetSection, "mod_music_tracker", "Music Tracker Widget", true, nil, function(enabled)
	FeatureManager.setModuleState("music_tracker", enabled)
	musicTrackerWidget.SetVisible(enabled)
end)

window:AddToggle(widgetSection, "mod_player_list", "Player List Widget (Tab Key)", true, nil, function(enabled)
	FeatureManager.setModuleState("player_list", enabled)
	playerListWidget.Frame.Visible = enabled
end)

window:AddToggle(widgetSection, "mod_chat_widget", "Chat Widget", true, nil, function(enabled)
	FeatureManager.setModuleState("chat_widget", enabled)
	chatWidgetInstance.Frame.Visible = enabled
end)

window:AddToggle(widgetSection, "mod_custom_hotbar", "Custom Hotbar & Backpack HUD", true, nil, function(enabled)
	FeatureManager.setModuleState("custom_hotbar", enabled)
	hotbarWidget.SetVisible(enabled)
end)

window:AddToggle(widgetSection, "mod_leaderstats_widget", "Live Leaderstats & Currencies HUD", true, nil, function(enabled)
	FeatureManager.setModuleState("leaderstats_widget", enabled)
	leaderstatsWidget.SetVisible(enabled)
end)

-- Hook tab right-click sync to update settings toggles
gameTab.OnVisibilityChanged = function(vis: boolean)
	local feat = FeatureManager.getFeature("tab_game_module")
	if feat and feat.state ~= vis then
		FeatureManager.setFeatureState("tab_game_module", vis)
	end
end

combatTab.OnVisibilityChanged = function(vis: boolean)
	local feat = FeatureManager.getFeature("tab_combat_module")
	if feat and feat.state ~= vis then
		FeatureManager.setFeatureState("tab_combat_module", vis)
	end
end

visualsTab.OnVisibilityChanged = function(vis: boolean)
	local feat = FeatureManager.getFeature("tab_visuals_module")
	if feat and feat.state ~= vis then
		FeatureManager.setFeatureState("tab_visuals_module", vis)
	end
end

-- ── SETTINGS SUB-TAB 2: THEMES & VISUALS ─────────────────────
local thmLeftCol, thmRightCol = window:CreateColumns(thmSubTab)

-- Left Column: Dark & Acrylic Themes
local darkThemeSection = window:AddSection(thmLeftCol, "Dark & Acrylic Themes")

window:AddButton(darkThemeSection, "Dark Mode", function()
	window:SetTheme("Dark")
	window:Notify("Theme", "Saved Dark Mode", 2)
end)

window:AddButton(darkThemeSection, "Translucent Dark (Acrylic)", function()
	window:SetTheme("TranslucentDark")
	window:Notify("Theme", "Saved Acrylic Dark Mode", 2)
end)

window:AddButton(darkThemeSection, "Adaptive (Album Cover)", function()
	window:SetTheme("Adaptive")
	window:Notify("Theme", "Saved Adaptive Mode", 2)
end)

-- Right Column: Light & Glass Themes
local lightThemeSection = window:AddSection(thmRightCol, "Light & Glass Themes")

window:AddButton(lightThemeSection, "Light Mode", function()
	window:SetTheme("Light")
	window:Notify("Theme", "Saved Light Mode", 2)
end)

window:AddButton(lightThemeSection, "Translucent Light (Glass)", function()
	window:SetTheme("TranslucentLight")
	window:Notify("Theme", "Saved Glass Light Mode", 2)
end)

-- ── SETTINGS SUB-TAB 3: PERFORMANCE & RENDERING ──────────────
local prfLeftCol, prfRightCol = window:CreateColumns(prfSubTab)

-- Left Column: Performance & Framerate
local perfSection = window:AddSection(prfLeftCol, "Performance & Framerate")

local terrain = workspace:FindFirstChildOfClass("Terrain")
window:AddToggle(perfSection, "fps_boost", "FPS BOOST (Shadows & Fog)", false, nil, function(enabled)
	Lighting.GlobalShadows = not enabled
	Lighting.FogEnd = if enabled then 9e9 else 10000
	if terrain then
		terrain.WaterWaveSize = if enabled then 0 else 0.15
		terrain.WaterWaveSpeed = if enabled then 0 else 10
		terrain.WaterReflectance = if enabled then 0 else 1
	end
end)

window:AddToggle(perfSection, "fps_uncap", "FPS UNCAP (Remove 60 FPS Cap)", false, nil, function(enabled)
	local setfps = (setfpscap or (set_fps_cap :: any))
	if typeof(setfps) == "function" then
		setfps(if enabled then 999 else 60)
	end
end)

window:AddToggle(perfSection, "hide_game_guis", "Hide Default Game GUIs (PlayerGui)", true, nil, function(enabled)
	hidePlayerGameGuis(enabled)
end)

-- Right Column: 3D & Texture Optimization
local renderSection = window:AddSection(prfRightCol, "3D & Texture Optimization")

local meshConn: RBXScriptConnection? = nil
window:AddToggle(renderSection, "dont_render_meshes", "DONT RENDER 3D MESHS", false, nil, function(enabled)
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("MeshPart") then
			if enabled then
				if not obj:GetAttribute("OrigTransparency") then
					obj:SetAttribute("OrigTransparency", obj.Transparency)
				end
				obj.Transparency = 1
			else
				local orig = obj:GetAttribute("OrigTransparency") or 0
				obj.Transparency = orig :: number
			end
		end
	end
	
	if enabled then
		meshConn = workspace.DescendantAdded:Connect(function(obj)
			if obj:IsA("MeshPart") then
				obj.Transparency = 1
			end
		end)
	elseif meshConn then
		meshConn:Disconnect()
		meshConn = nil
	end
end)

local decalConn: RBXScriptConnection? = nil
window:AddToggle(renderSection, "dont_render_decals", "DONT RENDER DECALS", false, nil, function(enabled)
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Decal") or obj:IsA("Texture") then
			if enabled then
				if not obj:GetAttribute("OrigTransparency") then
					obj:SetAttribute("OrigTransparency", obj.Transparency)
				end
				obj.Transparency = 1
			else
				local orig = obj:GetAttribute("OrigTransparency") or 0
				obj.Transparency = orig :: number
			end
		end
	end
	
	if enabled then
		decalConn = workspace.DescendantAdded:Connect(function(obj)
			if obj:IsA("Decal") or obj:IsA("Texture") then
				obj.Transparency = 1
			end
		end)
	elseif decalConn then
		decalConn:Disconnect()
		decalConn = nil
	end
end)

-- ── SETTINGS SUB-TAB 4: SYSTEM & AUDIO ───────────────────────
local sysLeftCol, sysRightCol = window:CreateColumns(sysSubTab)

-- Left Column: Screen & GUI Optimization
local cleanSection = window:AddSection(sysLeftCol, "Screen & GUI Optimization")

window:AddToggle(cleanSection, "hide_default_guis", "Hide Game Default GUIs (Topbar & Core)", true, nil, function(enabled)
	disableRobloxTopBarApp(enabled)
	for _, guiType in ipairs(coreGuiOverlays) do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(guiType, not enabled)
		end)
	end
end)

-- Right Column: Master Audio Volume
local audioSection = window:AddSection(sysRightCol, "Master Audio Volume")

local currentVolumeScale = 1.0
local function updateSound(sound: Sound)
	if sound:IsDescendantOf(game:GetService("VoiceChatService")) then return end
	local base = sound:GetAttribute("OrigVolume")
	if not base then
		base = sound.Volume
		sound:SetAttribute("OrigVolume", base)
	end
	sound.Volume = (base :: number) * currentVolumeScale
end

window:AddSlider(audioSection, "VOLUME CONTROLLER", 0, 100, 100, function(value)
	currentVolumeScale = value / 100
	for _, obj in ipairs(SoundService:GetDescendants()) do
		if obj:IsA("Sound") then
			updateSound(obj)
		end
	end
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("Sound") then
			updateSound(obj)
		end
	end
end)

SoundService.DescendantAdded:Connect(function(obj)
	if obj:IsA("Sound") then
		task.defer(function()
			updateSound(obj)
		end)
	end
end)

Workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("Sound") then
		task.defer(function()
			updateSound(obj)
		end)
	end
end)

-- ============================================================
-- DYNAMIC CONFIGS TAB CONTENT (ZERO-DEFAULT PROFILE MANAGER)
-- ============================================================
local confLeftCol, confRightCol = window:CreateColumns(configsTab)

local profilesSection = window:AddSection(confLeftCol, "Saved Configuration Profiles")
local configActionsSection = window:AddSection(confRightCol, "Config Actions & Management")

local selectedConfigName: string? = nil
local currentConfigInputName = ""
local profileButtonRows: {[string]: Frame} = {}

local configInputBox = window:AddTextBox(configActionsSection, "Profile Name", "e.g. Legit_Main", "", function(text)
	currentConfigInputName = text
end)

local statusNotice = Instance.new("TextLabel")
statusNotice.Name = "StatusNotice"
statusNotice.Size = UDim2.new(1, -4, 0, 36)
statusNotice.BackgroundTransparency = 1
statusNotice.Text = "No Saved Profiles Found\nCreate a new profile on the right to save."
statusNotice.TextColor3 = UI.Theme.TextSecondary
statusNotice.Font = UI.Fonts.Body
statusNotice.TextSize = 10
statusNotice.TextWrapped = true
statusNotice.Parent = profilesSection
UI.registerThemeElement(statusNotice, "TextSecondary")

local function refreshProfilesList()
	for _, row in pairs(profileButtonRows) do
		pcall(function() row:Destroy() end)
	end
	table.clear(profileButtonRows)

	local existingConfigs = FeatureManager.listConfigs()
	if #existingConfigs == 0 then
		statusNotice.Visible = true
		statusNotice.Text = "No Saved Profiles Found\nType a name on the right and click Create Config."
	else
		statusNotice.Visible = false
		for _, cfgName in ipairs(existingConfigs) do
			local pRow = Instance.new("Frame")
			pRow.Name = cfgName .. "Row"
			pRow.Size = UDim2.new(1, -4, 0, 26)
			pRow.Position = UDim2.new(0, 2, 0, 0)
			pRow.BackgroundColor3 = UI.Theme.Container
			pRow.BackgroundTransparency = UI.Theme.ContainerTransparency
			pRow.BorderSizePixel = 0
			pRow.Parent = profilesSection
			UI.registerThemeElement(pRow, "Container")

			local pStroke = Instance.new("UIStroke")
			pStroke.Color = if selectedConfigName == cfgName then UI.Theme.Accent else UI.Theme.Border
			pStroke.Thickness = if selectedConfigName == cfgName then 1.6 else 1.0
			pStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			pStroke.Parent = pRow
			UI.registerThemeElement(pStroke, "Border")

			local pBtn = Instance.new("TextButton")
			pBtn.Size = UDim2.new(1, 0, 1, 0)
			pBtn.BackgroundTransparency = 1
			pBtn.Text = string.format("  [%s] %s", if selectedConfigName == cfgName then "●" else "○", cfgName)
			pBtn.TextColor3 = if selectedConfigName == cfgName then UI.Theme.Accent else UI.Theme.TextPrimary
			pBtn.Font = UI.Fonts.Header
			pBtn.TextSize = 11
			pBtn.TextXAlignment = Enum.TextXAlignment.Left
			pBtn.Parent = pRow
			UI.registerThemeElement(pBtn, "TextPrimary")

			pBtn.MouseButton1Click:Connect(function()
				selectedConfigName = cfgName
				configInputBox.Text = cfgName
				currentConfigInputName = cfgName
				refreshProfilesList()
			end)

			profileButtonRows[cfgName] = pRow
		end
	end
end

window:AddButton(configActionsSection, "Create & Save Config", function()
	local targetName = if currentConfigInputName ~= "" then currentConfigInputName else configInputBox.Text
	if targetName == "" then
		window:Notify("Configs", "Please enter a profile name first", 3)
		return
	end

	local saved = FeatureManager.saveConfig(targetName)
	if saved then
		selectedConfigName = targetName
		window:Notify("Configs", string.format("Created & saved '%s'", targetName), 3)
		refreshProfilesList()
	else
		window:Notify("Configs", "Failed to write configuration to disk", 3)
	end
end)

window:AddButton(configActionsSection, "Save / Overwrite Selected", function()
	local targetName = selectedConfigName or (if currentConfigInputName ~= "" then currentConfigInputName else configInputBox.Text)
	if not targetName or targetName == "" then
		window:Notify("Configs", "No configuration selected to overwrite", 3)
		return
	end

	local saved = FeatureManager.saveConfig(targetName)
	if saved then
		window:Notify("Configs", string.format("Saved current settings to '%s'", targetName), 3)
		refreshProfilesList()
	else
		window:Notify("Configs", "Failed to save configuration", 3)
	end
end)

window:AddButton(configActionsSection, "Load Selected Config", function()
	if not selectedConfigName or selectedConfigName == "" then
		window:Notify("Configs", "Select a profile from the left first", 3)
		return
	end

	local loaded = FeatureManager.loadConfig(selectedConfigName)
	if loaded then
		window:Notify("Configs", string.format("Loaded profile '%s'", selectedConfigName), 3)
	else
		window:Notify("Configs", string.format("Failed to load '%s'", selectedConfigName), 3)
	end
end)

window:AddButton(configActionsSection, "Delete Selected Config", function()
	if not selectedConfigName or selectedConfigName == "" then
		window:Notify("Configs", "Select a profile from the left to delete", 3)
		return
	end

	local deletedName = selectedConfigName
	local deleted = FeatureManager.deleteConfig(deletedName)
	if deleted then
		selectedConfigName = nil
		configInputBox.Text = ""
		currentConfigInputName = ""
		window:Notify("Configs", string.format("Deleted profile '%s'", deletedName), 3)
		refreshProfilesList()
	else
		window:Notify("Configs", "Failed to delete profile", 3)
	end
end)

window:AddButton(configActionsSection, "Refresh Config List", function()
	refreshProfilesList()
	window:Notify("Configs", "Config list refreshed", 2)
end)

-- Auto-Load on Startup Section
local autoLoadSection = window:AddSection(confRightCol, "Auto-Load on Startup")

local autoLoadData = FeatureManager.getAutoLoadConfig()

local autoLoadStatusLabel = Instance.new("TextLabel")
autoLoadStatusLabel.Name = "AutoLoadStatus"
autoLoadStatusLabel.Size = UDim2.new(1, -4, 0, 24)
autoLoadStatusLabel.BackgroundTransparency = 1
autoLoadStatusLabel.Text = if autoLoadData.enabled and autoLoadData.configName ~= "" then string.format("Default Startup Config: [%s]", autoLoadData.configName) else "Default Startup Config: [ None ]"
autoLoadStatusLabel.TextColor3 = if autoLoadData.enabled then UI.Theme.Accent else UI.Theme.TextSecondary
autoLoadStatusLabel.Font = UI.Fonts.Mono
autoLoadStatusLabel.TextSize = 10
autoLoadStatusLabel.Parent = autoLoadSection
UI.registerThemeElement(autoLoadStatusLabel, "TextSecondary")

window:AddToggle(autoLoadSection, "autoload_startup_enabled", "Enable Auto-Load on Startup", autoLoadData.enabled, nil, function(enabled)
	local cur = FeatureManager.getAutoLoadConfig()
	FeatureManager.setAutoLoadConfig(enabled, cur.configName)
	autoLoadStatusLabel.TextColor3 = if enabled then UI.Theme.Accent else UI.Theme.TextSecondary
	window:Notify("Auto-Load", if enabled then "Auto-load on startup enabled" else "Auto-load on startup disabled", 2)
end)

window:AddButton(autoLoadSection, "Set Selected as Startup Profile", function()
	if not selectedConfigName or selectedConfigName == "" then
		window:Notify("Auto-Load", "Please select a profile on the left first", 3)
		return
	end
	FeatureManager.setAutoLoadConfig(true, selectedConfigName)
	local tgl = FeatureManager.getFeature("autoload_startup_enabled")
	if tgl and not tgl.state then
		FeatureManager.setFeatureState("autoload_startup_enabled", true)
	end
	autoLoadStatusLabel.Text = string.format("Default Startup Config: [%s]", selectedConfigName)
	autoLoadStatusLabel.TextColor3 = UI.Theme.Accent
	window:Notify("Auto-Load", string.format("Set '%s' to load automatically on startup", selectedConfigName), 3)
end)

window:AddButton(autoLoadSection, "Clear Startup Profile", function()
	FeatureManager.setAutoLoadConfig(false, "")
	local tgl = FeatureManager.getFeature("autoload_startup_enabled")
	if tgl and tgl.state then
		FeatureManager.setFeatureState("autoload_startup_enabled", false)
	end
	autoLoadStatusLabel.Text = "Default Startup Config: [ None ]"
	autoLoadStatusLabel.TextColor3 = UI.Theme.TextSecondary
	window:Notify("Auto-Load", "Startup auto-load profile cleared", 2)
end)

-- Initial scan of configs on startup
task.spawn(refreshProfilesList)

-- Auto-load configuration profile on startup if configured
task.spawn(function()
	task.wait(1.0)
	pcall(function()
		local auto = FeatureManager.getAutoLoadConfig()
		if auto.enabled and auto.configName ~= "" then
			local ok = FeatureManager.loadConfig(auto.configName)
			if ok then
				window:Notify("Auto-Load", string.format("Auto-loaded startup config '%s'", auto.configName), 4)
			end
		end
	end)
end)

-- Ensure saved theme is applied and saved on leave
pcall(function()
	local savedTheme = UI.getSavedTheme()
	if savedTheme and UI.Themes[savedTheme] then
		window:SetTheme(savedTheme)
	end
end)

pcall(function()
	game:BindToClose(function()
		UI.saveTheme(UI.CurrentTheme.Name)
	end)
end)

Players.PlayerRemoving:Connect(function(plr)
	if plr == localPlayer then
		UI.saveTheme(UI.CurrentTheme.Name)
	end
end)

-- Explicitly activate default Main tab on load
window:SelectTab(mainTab)
