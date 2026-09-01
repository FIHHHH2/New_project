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
local LuckyBlocks = require("Modules/LuckyBlocks.luau")
local RestaurantTycoon = require("Modules/RestaurantTycoon.luau")
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

-- Synchronize Player List with Leaderstats and Player Profile Sub-GUIs
playerListWidget.OnClose = function()
	if leaderstatsWidget and typeof(leaderstatsWidget.Close) == "function" then
		leaderstatsWidget.Close()
	end
end

playerListWidget.OnOpen = function()
	if leaderstatsWidget and typeof(leaderstatsWidget.Open) == "function" then
		leaderstatsWidget.Open()
	end
end

playerListWidget.OnMinimize = function(isMin: boolean)
	if leaderstatsWidget and typeof(leaderstatsWidget.SetMinimized) == "function" then
		leaderstatsWidget.SetMinimized(isMin)
	end
end

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

	if placeId == 1190485299606 or string.find(gameName, "restaurant") or (workspace:FindFirstChild("Tycoons") and workspace.Tycoons:FindFirstChildWhichIsA("Folder")) then
		return "Restaurant Tycoon"
	elseif placeId == 662417684 or string.find(gameName, "lucky block") or workspace:FindFirstChild("CenterBlocks") then
		return "Lucky Blocks"
	elseif placeId == 189707 or string.find(gameName, "disaster") then
		return "Natural Disaster"
	elseif placeId == 12901416348 or string.find(gameName, "run and hide") or string.find(gameName, "demise") then
		return "Run N Hide"
	elseif string.find(gameName, "ice tycoon") or (workspace:FindFirstChild("Tycoon") and workspace.Tycoon:FindFirstChild("Buttons")) then
		return "Ice Tycoon"
	end
	return "Restaurant Tycoon"
end

local gameTabTitle = getGameTabName()

-- Create navigation tabs in strict layout order
local mainTab = window:CreateTab("Main")
local combatTab = window:CreateTab("Combat")
local visualsTab = window:CreateTab("Visuals")

-- Create Game Module Tabs (Current detected game is shown on start; all other game modules can be toggled/opened on demand)
local restTab = window:CreateTab("Restaurant Tycoon", gameTabTitle ~= "Restaurant Tycoon")
local luckyTab = window:CreateTab("Lucky Blocks", gameTabTitle ~= "Lucky Blocks")
local iceTab = window:CreateTab("Ice Tycoon", gameTabTitle ~= "Ice Tycoon")
local rnhTab = window:CreateTab("Run N Hide", gameTabTitle ~= "Run N Hide")
local disTab = window:CreateTab("Natural Disaster", gameTabTitle ~= "Natural Disaster")

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

-- Universal Game Module Switcher (Open ANY module in ANY game)
local gameHubSection = window:AddSection(utilLeftCol, "Game Modules Hub (Universal)")

window:AddButton(gameHubSection, "Open Restaurant Tycoon Suite", function()
	window:SetTabVisibility(restTab, true)
	window:SelectTab(restTab)
	window:Notify("Modules", "Opened Restaurant Tycoon Suite", 2)
end)

window:AddButton(gameHubSection, "Open Lucky Blocks Suite", function()
	window:SetTabVisibility(luckyTab, true)
	window:SelectTab(luckyTab)
	window:Notify("Modules", "Opened Lucky Blocks Suite", 2)
end)

window:AddButton(gameHubSection, "Open Ice Tycoon Suite", function()
	window:SetTabVisibility(iceTab, true)
	window:SelectTab(iceTab)
	window:Notify("Modules", "Opened Ice Tycoon Suite", 2)
end)

window:AddButton(gameHubSection, "Open Run N Hide Suite", function()
	window:SetTabVisibility(rnhTab, true)
	window:SelectTab(rnhTab)
	window:Notify("Modules", "Opened Run N Hide Suite", 2)
end)

window:AddButton(gameHubSection, "Open Natural Disaster Suite", function()
	window:SetTabVisibility(disTab, true)
	window:SelectTab(disTab)
	window:Notify("Modules", "Opened Natural Disaster Suite", 2)
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

window:AddToggle(hitExpSection, "hitbox_visuals", "Show Hitbox Visuals (ForceField)", false, nil, function(enabled)
	Combat.HitboxVisuals = enabled
end)

window:AddToggle(hitExpSection, "hitbox_target_part", "Target Part: Head (Off = RootPart)", false, nil, function(enabled)
	Combat.HitboxPart = if enabled then "Head" else "HumanoidRootPart"
end)

window:AddSlider(hitExpSection, "Hitbox Size", 2, 45, 15, function(value)
	Combat.HitboxSize = value
end)

-- Right Column: Hitbox Operations
local hitOpsSection = window:AddSection(hitRightCol, "Hitbox Operations & Presets")

window:AddButton(hitOpsSection, "Small Size (8)", function()
	Combat.HitboxSize = 8
	FeatureManager.setSliderValue("Hitbox Size", 8)
	window:Notify("Hitboxes", "Hitbox size set to 8", 2)
end)

window:AddButton(hitOpsSection, "Medium Size (16)", function()
	Combat.HitboxSize = 16
	FeatureManager.setSliderValue("Hitbox Size", 16)
	window:Notify("Hitboxes", "Hitbox size set to 16", 2)
end)

window:AddButton(hitOpsSection, "Massive Size (30)", function()
	Combat.HitboxSize = 30
	FeatureManager.setSliderValue("Hitbox Size", 30)
	window:Notify("Hitboxes", "Hitbox size set to 30", 2)
end)

window:AddButton(hitOpsSection, "Reset All Hitboxes", function()
	Combat.resetHitboxes()
	window:Notify("Hitboxes", "All player hitboxes restored to default", 2.5)
end)

-- ============================================================
-- 3. UNIVERSAL GAME MODULE SUITES (LOADABLE IN EVERY GAME)
-- ============================================================

-- ── 1. RUN N HIDE SUITE ─────────────────────────────────────
do
	local rnhSubTabs = window:CreateSubTabs(rnhTab, { "Weapons & Firepower", "Bounds & Barriers", "Mobility & Items" })
	local weaponSubTab = rnhSubTabs["Weapons & Firepower"]
	local boundsSubTab = rnhSubTabs["Bounds & Barriers"]
	local mobilitySubTab = rnhSubTabs["Mobility & Items"]

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

	local boundsLeftCol, boundsRightCol = window:CreateColumns(boundsSubTab)
	local boundarySection = window:AddSection(boundsLeftCol, "Spawn Barriers & Walls")

	window:AddToggle(boundarySection, "rnh_kill_spawn_walls", "Disable Spawn Forcefields", false, nil, function(val)
		RunNHide.RemoveSpawnWalls = val
		RunNHide.updateBarriers()
	end)

	window:AddToggle(boundarySection, "rnh_kill_bounds", "Remove Map Death Barriers", false, nil, function(val)
		RunNHide.RemoveInvisibleWalls = val
		RunNHide.updateBarriers()
	end)

	local mapInteractSection = window:AddSection(boundsRightCol, "Door & Object Controls")

	window:AddToggle(mapInteractSection, "rnh_open_doors", "Auto-Unlock Map Doors", false, nil, function(val)
		RunNHide.AutoOpenDoors = val
		RunNHide.updateBarriers()
	end)

	window:AddButton(mapInteractSection, "Clear Map Breakables", function()
		RunNHide.clearBreakableGlass()
		window:Notify("Run N Hide", "Map breakables cleared", 2.5)
	end)

	local mobLeftCol, mobRightCol = window:CreateColumns(mobilitySubTab)
	local powerUpSection = window:AddSection(mobLeftCol, "Power-Ups & Drops")

	window:AddToggle(powerUpSection, "rnh_auto_powerups", "Auto-Collect Power-Ups", false, nil, function(val)
		RunNHide.AutoCollectPowerUps = val
	end)

	window:AddButton(powerUpSection, "Sweep All Power-Ups Now", function()
		local count = RunNHide.collectPowerUpsNow()
		window:Notify("Run N Hide", string.format("Collected %d power-ups", count), 3)
	end)

	local escapeSection = window:AddSection(mobRightCol, "Tactical Escapes")

	window:AddButton(escapeSection, "Safe High Ground Teleport", function()
		RunNHide.teleportSafeHigh()
		window:Notify("Tactical", "Teleported to safe vantage point", 2)
	end)
end

-- ── 2. NATURAL DISASTER SURVIVAL SUITE ───────────────────────
do
	local ndsSubTabs = window:CreateSubTabs(disTab, { "Automation & Survival", "Map Teleports", "Visuals & Alerts" })
	local autoSubTab = ndsSubTabs["Automation & Survival"]
	local mapSubTab = ndsSubTabs["Map Teleports"]
	local alertsSubTab = ndsSubTabs["Visuals & Alerts"]

	local autoLeftCol, autoRightCol = window:CreateColumns(autoSubTab)
	local godSection = window:AddSection(autoLeftCol, "God Mode & Physics Protections")

	window:AddToggle(godSection, "nds_anti_fall", "Anti-Fall Damage (Safe Landings)", false, nil, function(enabled)
		DisasterSurvival.setAntiFallDamage(enabled)
	end)

	window:AddToggle(godSection, "nds_anti_void", "Anti-Void Fall Recovery", false, nil, function(enabled)
		DisasterSurvival.setAntiVoid(enabled)
	end)

	window:AddToggle(godSection, "nds_walk_on_water", "Walk on Water (Acid/Tsunami/Lava)", false, nil, function(enabled)
		DisasterSurvival.setWalkOnWater(enabled)
	end)

	local autoPlaySection = window:AddSection(autoRightCol, "Automated Disaster Defenses")

	window:AddToggle(autoPlaySection, "nds_auto_run_away", "Auto-Evade Disasters", false, nil, function(enabled)
		DisasterSurvival.setAutoRunAway(enabled)
	end)

	window:AddToggle(autoPlaySection, "nds_auto_balloon", "Auto-Deploy Green Balloon", false, nil, function(enabled)
		DisasterSurvival.setAutoBalloon(enabled)
	end)

	window:AddToggle(autoPlaySection, "nds_auto_apple", "Auto-Consume Health Apples", false, nil, function(enabled)
		DisasterSurvival.setAutoEatApples(enabled)
	end)

	local mapLeftCol, mapRightCol = window:CreateColumns(mapSubTab)
	local safeTpSection = window:AddSection(mapLeftCol, "Safe Zone Teleports")

	window:AddButton(safeTpSection, "Teleport to Safe Island Tower", function()
		DisasterSurvival.teleportToIsland()
		window:Notify("Natural Disaster", "Teleported to Safe Island Tower", 2.5)
	end)

	window:AddButton(safeTpSection, "Teleport to Spawn Lobby", function()
		DisasterSurvival.teleportToLobby()
		window:Notify("Natural Disaster", "Teleported to Spawn Lobby", 2.5)
	end)

	local structTpSection = window:AddSection(mapRightCol, "Structure & High Ground")

	window:AddButton(structTpSection, "Teleport to High Ground", function()
		DisasterSurvival.teleportToHighGround()
		window:Notify("Natural Disaster", "Teleported to Highest Structure Point", 2.5)
	end)

	local alertLeftCol, alertRightCol = window:CreateColumns(alertsSubTab)
	local alertSection = window:AddSection(alertLeftCol, "Disaster Warnings & Radar")

	window:AddToggle(alertSection, "nds_disaster_alerts", "On-Screen Disaster Notifications", true, nil, function(enabled)
		DisasterSurvival.DisasterAlerts = enabled
	end)

	window:AddToggle(alertSection, "nds_show_collapse", "Highlight Collapsing Buildings (Red)", false, nil, function(enabled)
		DisasterSurvival.HighlightCollapsing = enabled
	end)

	local weatherSection = window:AddSection(alertRightCol, "Weather & Environment")

	window:AddToggle(weatherSection, "nds_clear_fog", "Remove Disaster Fog & Dust", false, nil, function(enabled)
		DisasterSurvival.ClearFog = enabled
	end)

	window:AddToggle(weatherSection, "nds_anti_flling", "Anti-Fling Structural Anchoring", false, nil, function(enabled)
		DisasterSurvival.AntiFling = enabled
	end)
end

-- ── 3. ICE TYCOON 2 SUITE ───────────────────────────────────
do
	local iceSubTabs = window:CreateSubTabs(iceTab, { "Automation & Tycoon", "Production & Buttons", "Teleports & Pedestals" })
	local autoSubTab = iceSubTabs["Automation & Tycoon"]
	local prodSubTab = iceSubTabs["Production & Buttons"]
	local tpSubTab = iceSubTabs["Teleports & Pedestals"]

	local autoLeftCol, autoRightCol = window:CreateColumns(autoSubTab)
	local collectionSection = window:AddSection(autoLeftCol, "Automated Harvesters")

	window:AddToggle(collectionSection, "ice_auto_collect_drops", "Auto-Collect Dropper Ice", false, nil, function(enabled)
		IceTycoon.setAutoCollect(enabled)
	end)

	window:AddToggle(collectionSection, "ice_auto_harvest_flowers", "Auto-Harvest Ice Flowers", false, nil, function(enabled)
		IceTycoon.setAutoHarvest(enabled)
	end)

	window:AddToggle(collectionSection, "ice_auto_claim_pedestals", "Auto-Claim Tool Pedestals", false, nil, function(enabled)
		IceTycoon.setAutoClaimPedestals(enabled)
	end)

	window:AddToggle(collectionSection, "ice_auto_fill_water", "Auto-Fill Water & Well", false, nil, function(enabled)
		IceTycoon.setAutoFillWater(enabled)
	end)

	local tycoonControlSection = window:AddSection(autoRightCol, "Instant Tycoon Actions")

	window:AddButton(tycoonControlSection, "Claim All Pedestal Tools Now", function()
		local count = IceTycoon.claimAllPedestalTools()
		window:Notify("Ice Tycoon", string.format("Claimed %d pedestal tools", count), 3)
	end)

	window:AddButton(tycoonControlSection, "Harvest All Ice Flowers Now", function()
		local count = IceTycoon.harvestAllFlowersNow()
		window:Notify("Ice Tycoon", string.format("Harvested %d mature flower domes", count), 3)
	end)

	window:AddButton(tycoonControlSection, "Collect All Hidden Secrets", function()
		local count = IceTycoon.collectSecrets()
		window:Notify("Ice Tycoon", string.format("Collected %d hidden secrets", count), 3)
	end)

	local prodLeftCol, prodRightCol = window:CreateColumns(prodSubTab)
	local buttonSection = window:AddSection(prodLeftCol, "Tycoon Button Purchasing")

	window:AddToggle(buttonSection, "ice_auto_buy_buttons", "Smart Priority Auto-Buy", false, nil, function(enabled)
		IceTycoon.setAutoBuyButtons(enabled)
	end)

	window:AddSlider(buttonSection, "Auto-Buy Interval (s)", 1, 10, 2, function(value)
		IceTycoon.BuyInterval = value
	end)

	local speedSection = window:AddSection(prodRightCol, "Production Overclocking")

	window:AddButton(prodSection or prodRightCol, "Deposit All Carried Ice", function()
		IceTycoon.depositIce()
		window:Notify("Ice Tycoon", "Deposited ice at factory furnace", 2)
	end)

	local tpLeftCol, tpRightCol = window:CreateColumns(tpSubTab)
	local zonesSection = window:AddSection(tpLeftCol, "Base & Map Locations")

	local locations = IceTycoon.getLocations()
	for _, locName in ipairs(locations) do
		window:AddButton(zonesSection, locName, function()
			IceTycoon.teleportTo(locName)
			window:Notify("Teleport", "Teleported to " .. locName, 2)
		end)
	end
end

-- ── 4. LUCKY BLOCKS BATTLEGROUNDS SUITE ──────────────────────
do
	local lbSubTabs = window:CreateSubTabs(luckyTab, { "Block Automation", "Combat & Turbo", "Fast Teleports" })
	local blockSubTab = lbSubTabs["Block Automation"]
	local combatSubTab = lbSubTabs["Combat & Turbo"]
	local tpSubTab = lbSubTabs["Fast Teleports"]

	local bLeftCol, bRightCol = window:CreateColumns(blockSubTab)
	local autoBlockSection = window:AddSection(bLeftCol, "Lucky Block Collector")

	window:AddToggle(autoBlockSection, "lb_auto_claim", "Auto-Claim Lucky Blocks", false, nil, function(enabled)
		LuckyBlocks.setAutoClaim(enabled)
	end)

	window:AddToggle(autoBlockSection, "lb_auto_open", "Auto-Open Inventory Blocks", false, nil, function(enabled)
		LuckyBlocks.setAutoOpen(enabled)
	end)

	window:AddButton(autoBlockSection, "Claim All Blocks Now", function()
		local count = LuckyBlocks.claimAllBlocksNow()
		window:Notify("Lucky Blocks", string.format("Claimed %d lucky block givers", count), 2.5)
	end)

	window:AddSlider(autoBlockSection, "Claim Interval (s)", 20, 100, 35, function(value)
		LuckyBlocks.ClaimInterval = value / 100
	end)

	local filterSection = window:AddSection(bRightCol, "Tier Filters (Auto-Claim)")
	window:AddToggle(filterSection, "lb_tier_void", "Claim Void Blocks", true, nil, function(val) LuckyBlocks.ClaimVoid = val end)
	window:AddToggle(filterSection, "lb_tier_rainbow", "Claim Rainbow Blocks", true, nil, function(val) LuckyBlocks.ClaimRainbow = val end)
	window:AddToggle(filterSection, "lb_tier_galaxy", "Claim Galaxy Blocks", true, nil, function(val) LuckyBlocks.ClaimGalaxy = val end)
	window:AddToggle(filterSection, "lb_tier_diamond", "Claim Diamond Blocks", true, nil, function(val) LuckyBlocks.ClaimDiamond = val end)
	window:AddToggle(filterSection, "lb_tier_super", "Claim Super Blocks", true, nil, function(val) LuckyBlocks.ClaimSuper = val end)
	window:AddToggle(filterSection, "lb_tier_lucky", "Claim Normal Blocks", true, nil, function(val) LuckyBlocks.ClaimLucky = val end)

	local cLeftCol, cRightCol = window:CreateColumns(combatSubTab)
	local weaponSpamSection = window:AddSection(cLeftCol, "Weapon Spam & Turbo")

	window:AddToggle(weaponSpamSection, "lb_turbo_sword", "Turbo Sword / Weapon Auto-Slash", false, nil, function(enabled)
		LuckyBlocks.setTurboSword(enabled)
	end)

	window:AddToggle(weaponSpamSection, "lb_anti_void", "Anti-Void Fall Rescue", true, nil, function(enabled)
		LuckyBlocks.setAntiVoid(enabled)
	end)

	local quickCombatSection = window:AddSection(cRightCol, "Combat Shortcuts")
	window:AddButton(quickCombatSection, "Equip Sword & Turbo Attack", function()
		local char = localPlayer.Character
		local bp = localPlayer:FindFirstChildOfClass("Backpack")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if bp and hum then
			for _, item in ipairs(bp:GetChildren()) do
				if item:IsA("Tool") and (item.Name:lower():find("sword") or item.Name:lower():find("katana") or item.Name:lower():find("axe") or item.Name:lower():find("blade")) then
					hum:EquipTool(item)
					break
				end
			end
		end
		LuckyBlocks.setTurboSword(true)
		FeatureManager.setToggleState("lb_turbo_sword", true)
		window:Notify("Lucky Blocks", "Equipped weapon with Turbo Attack", 2)
	end)

	local tpLeftCol, tpRightCol = window:CreateColumns(tpSubTab)
	local centerSection = window:AddSection(tpLeftCol, "High Tier Center Zones")
	window:AddButton(centerSection, "Center Void Giver", function() LuckyBlocks.teleportTo("Center Void / High Tier"); window:Notify("Teleport", "Teleported to Void Giver", 2) end)
	window:AddButton(centerSection, "Center Rainbow Giver", function() LuckyBlocks.teleportTo("Center Rainbow Giver"); window:Notify("Teleport", "Teleported to Rainbow Giver", 2) end)
	window:AddButton(centerSection, "Center Galaxy Giver", function() LuckyBlocks.teleportTo("Center Galaxy Giver"); window:Notify("Teleport", "Teleported to Galaxy Giver", 2) end)

	local spawnSection = window:AddSection(tpRightCol, "Spawn Bases 1 - 8")
	for i = 1, 8 do
		local sName = string.format("Spawn %d Base", i)
		window:AddButton(spawnSection, sName, function()
			LuckyBlocks.teleportTo(sName)
			window:Notify("Teleport", string.format("Teleported to %s", sName), 2)
		end)
	end
end

-- ── 5. RESTAURANT TYCOON 3 SUITE ────────────────────────────
do
	local rtSubTabs = window:CreateSubTabs(restTab, { "Service & Orders", "Revenue & Rewards", "Restaurant Teleports" })
	local servSubTab = rtSubTabs["Service & Orders"]
	local revSubTab = rtSubTabs["Revenue & Rewards"]
	local tpSubTab = rtSubTabs["Restaurant Teleports"]

	local sLeftCol, sRightCol = window:CreateColumns(servSubTab)
	local servSection = window:AddSection(sLeftCol, "Customer Automation")

	window:AddToggle(servSection, "rt_auto_serve", "Auto-Serve Customers (Take Orders & Food)", false, nil, function(enabled)
		RestaurantTycoon.setAutoServe(enabled)
	end)

	window:AddToggle(servSection, "rt_fast_cooking", "Instant Cooking Accelerator", false, nil, function(enabled)
		RestaurantTycoon.setFastCooking(enabled)
	end)

	window:AddButton(servSection, "Serve All Active Customers Now", function()
		local count = RestaurantTycoon.serveAllCustomersNow()
		window:Notify("Restaurant Tycoon", string.format("Served %d customer prompts", count), 2.5)
	end)

	local dineSection = window:AddSection(sRightCol, "Restaurant Security")

	window:AddToggle(dineSection, "rt_catch_dine_dash", "Auto-Catch Dine & Dashers", true, nil, function(enabled)
		RestaurantTycoon.setAutoCatchDineAndDash(enabled)
	end)

	local rLeftCol, rRightCol = window:CreateColumns(revSubTab)
	local cashSection = window:AddSection(rLeftCol, "Cash & Table Bills Collector")

	window:AddToggle(cashSection, "rt_auto_grab_cash", "Auto-Grab Cash & Table Bills", true, nil, function(enabled)
		RestaurantTycoon.setAutoGrabCash(enabled)
	end)

	window:AddToggle(cashSection, "rt_auto_collect_tips", "Auto-Collect Customer Tips", true, nil, function(enabled)
		RestaurantTycoon.setAutoCollectTips(enabled)
	end)

	window:AddButton(cashSection, "Grab All Cash & Bills Now", function()
		local count = RestaurantTycoon.grabAllCashNow()
		window:Notify("Restaurant Tycoon", string.format("Swept %d cash & bill sources", count), 2.5)
	end)

	window:AddSlider(cashSection, "Cash Sweep Interval (ms)", 150, 800, 350, function(value)
		RestaurantTycoon.CashInterval = value / 1000
	end)

	local rewardSection = window:AddSection(rRightCol, "Offline Earnings & Daily Rewards")

	window:AddButton(rewardSection, "Collect Offline Earnings", function()
		local rEvents = game:GetService("ReplicatedStorage"):FindFirstChild("Events")
		if rEvents and rEvents:FindFirstChild("Upgrades") and rEvents.Upgrades:FindFirstChild("CollectOfflineEarningsRequested") then
			rEvents.Upgrades.CollectOfflineEarningsRequested:FireServer()
			window:Notify("Restaurant Tycoon", "Collected offline restaurant revenue", 2.5)
		end
	end)

	window:AddButton(rewardSection, "Claim Daily Reward Box", function()
		if RestaurantTycoon.claimDailyRewards() then
			window:Notify("Restaurant Tycoon", "Claimed daily reward box", 2.5)
		else
			window:Notify("Restaurant Tycoon", "Daily reward not ready or not found", 2.5)
		end
	end)

	window:AddButton(rewardSection, "Collect Tip Jar Now", function()
		if RestaurantTycoon.collectTipsNow() then
			window:Notify("Restaurant Tycoon", "Collected restaurant tips", 2)
		else
			window:Notify("Restaurant Tycoon", "No pending tips to collect", 2)
		end
	end)

	local tpLeftCol, tpRightCol = window:CreateColumns(tpSubTab)
	local locSection = window:AddSection(tpLeftCol, "Restaurant Fast Teleports")

	local locs = RestaurantTycoon.getTeleportLocations()
	for _, loc in ipairs(locs) do
		window:AddButton(locSection, loc, function()
			if RestaurantTycoon.teleportToArea(loc) then
				window:Notify("Teleport", "Teleported to " .. loc, 2)
			else
				window:Notify("Teleport", "Could not locate " .. loc, 2)
			end
		end)
	end
end
