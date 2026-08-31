--!strict
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CoreUI = require("Core/CoreUI.luau")
local FeatureManager = require("Core/FeatureManager.luau")
local PlayerList = require("UI/PlayerList.luau")
local ChatWidget = require("UI/ChatWidget.luau")
local Visuals = require("Modules/Visuals.luau")
local Combat = require("Modules/Combat.luau")
local DisasterSurvival = require("Modules/DisasterSurvival.luau")
local RunNHide = require("Modules/RunNHide.luau")

local localPlayer = Players.LocalPlayer
local character = localPlayer.Character
local humanoid: Humanoid? = if character then character:FindFirstChildOfClass("Humanoid") else nil

localPlayer.CharacterAdded:Connect(function(char)
	character = char
	humanoid = char:WaitForChild("Humanoid", 5) :: Humanoid?
end)

-- Force PC Desktop Mode and Disable Mobile Touch Interfaces
pcall(function()
	local hook = hookmetamethod or (getgenv and getgenv().hookmetamethod)
	if type(hook) == "function" then
		local oldIndex: any
		oldIndex = hook(game, "__index", function(self, key)
			if not checkcaller() and self == UserInputService then
				if key == "TouchEnabled" then
					return false
				elseif key == "KeyboardEnabled" or key == "MouseEnabled" then
					return true
				end
			end
			return oldIndex(self, key)
		end)
	else
		local raw = getrawmetatable and getrawmetatable(game)
		if raw and raw.__index and setreadonly then
			local old = raw.__index
			setreadonly(raw, false)
			raw.__index = function(self, key)
				if self == UserInputService then
					if key == "TouchEnabled" then
						return false
					elseif key == "KeyboardEnabled" or key == "MouseEnabled" then
						return true
					end
				end
				return old(self, key)
			end
			setreadonly(raw, true)
		end
	end
end)

local function purgeMobileGuis()
	local pgui = localPlayer:FindFirstChild("PlayerGui")
	if pgui then
		for _, child in ipairs(pgui:GetChildren()) do
			if child.Name == "TouchGui" or child.Name:lower():find("mobile") or child.Name:lower():find("touchcontrol") then
				pcall(function() child:Destroy() end)
			end
		end
	end
end

task.spawn(purgeMobileGuis)

local pguiRef = localPlayer:FindFirstChild("PlayerGui")
if pguiRef then
	pguiRef.ChildAdded:Connect(function(child)
		if child.Name == "TouchGui" or child.Name:lower():find("mobile") or child.Name:lower():find("touchcontrol") then
			task.defer(function()
				pcall(function() child:Destroy() end)
			end)
		end
	end)
end

-- Disable overlapping default CoreGui elements that conflict with our widgets
local coreGuiOverlays = {
	Enum.CoreGuiType.PlayerList,
	Enum.CoreGuiType.Chat,
	Enum.CoreGuiType.EmotesMenu,
	Enum.CoreGuiType.Backpack,
	Enum.CoreGuiType.Health,
}
local function disableCoreGuis()
	purgeMobileGuis()
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
task.spawn(disableCoreGuis)
localPlayer.CharacterAdded:Connect(function()
	task.spawn(disableCoreGuis)
end)

local window = CoreUI.new("Project Fih Menu")
local playerListWidget = PlayerList.new()
local chatWidgetInstance = ChatWidget.new()

local function getGameTabName(): string
	local placeId = game.PlaceId
	local nameLower = string.lower(game.Name)
	if game:GetService("ReplicatedStorage"):FindFirstChild("GunSystem") or string.find(nameLower, "run") or string.find(nameLower, "hide") or string.find(nameLower, "demise") then
		return "Run N Hide"
	elseif placeId == 189707 or string.find(nameLower, "disaster") then
		return "Disasters"
	elseif placeId == 286090429 or string.find(nameLower, "arsenal") then
		return "Arsenal"
	elseif placeId == 6872265039 or placeId == 6872274481 or string.find(nameLower, "bedwars") then
		return "BedWars"
	elseif placeId == 142823291 or string.find(nameLower, "murder") then
		return "MM2"
	end
	
	local conciseName = "Game"
	pcall(function()
		local MarketplaceService = game:GetService("MarketplaceService")
		local info = MarketplaceService:GetProductInfo(placeId)
		if info and info.Name then
			local firstWord = string.split(info.Name, " ")[1]
			if firstWord and #firstWord <= 10 then
				conciseName = firstWord
			end
		end
	end)
	return conciseName
end

local gameTabTitle = getGameTabName()

-- Active sidebar navigation tabs
local mainTab = window:CreateTab("Main")
local visualsTab = window:CreateTab("Visuals")
local combatTab = window:CreateTab("Combat")
local gameTab = window:CreateTab(gameTabTitle)

-- Dedicated Settings & Configs tabs (opened/closed via subheader buttons)
local settingsTab = window:CreateTab("Settings", true)
local configsTab = window:CreateTab("Configs", true)

window:BindSettingsTab(settingsTab)
window:BindConfigsTab(configsTab)

-- Initialize Game Engines
DisasterSurvival.init(function(disasterName)
	if DisasterSurvival.DisasterTracker then
		window:Notify("Disaster Warning!", string.format("Detected: %s", disasterName), 4)
	end
end)

RunNHide.init(function(title, msg)
	window:Notify(title, msg, 4)
end)

-- ============================================================
-- MAIN / MENU TAB CONTENT
-- ============================================================
window:AddBanner(mainTab)

local leftCol, rightCol = window:CreateColumns(mainTab)

-- LEFT COLUMN: Self Configs
local selfSection = window:AddSection(leftCol, "Self Configs")

window:AddToggle(selfSection, "walkspeed_boost", "WalkSpeed Boost", false, nil, function(enabled)
	if humanoid then
		humanoid.WalkSpeed = if enabled then 32 else 16
	end
end)

window:AddToggle(selfSection, "jumppower_boost", "JumpPower Boost", false, nil, function(enabled)
	if humanoid then
		humanoid.JumpPower = if enabled then 100 else 50
	end
end)

window:AddSlider(selfSection, "Custom Speed", 16, 150, 16, function(value)
	if humanoid then
		humanoid.WalkSpeed = value
	end
end)

-- RIGHT COLUMN: Movement (Fixed Noclip with clean state restoration)
local moveSection = window:AddSection(rightCol, "Movement")

local noclipConn: RBXScriptConnection? = nil
window:AddToggle(moveSection, "noclip_toggle", "Noclip", false, nil, function(enabled)
	if enabled then
		noclipConn = RunService.Stepped:Connect(function()
			if localPlayer.Character then
				for _, part in ipairs(localPlayer.Character:GetDescendants()) do
					if part:IsA("BasePart") then
						part.CanCollide = false
					end
				end
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
			for _, part in ipairs(localPlayer.Character:GetDescendants()) do
				if part:IsA("BasePart") and (part.Name == "UpperTorso" or part.Name == "LowerTorso" or part.Name == "Torso" or part.Name == "CollisionPart" or part.Name == "Head") then
					part.CanCollide = true
				end
			end
		end
	end
end)

local infJumpConn: RBXScriptConnection? = nil
window:AddToggle(moveSection, "inf_jump", "Infinite Jump", false, nil, function(enabled)
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

window:AddSlider(moveSection, "Custom Gravity", 0, 196, 196, function(value)
	Workspace.Gravity = value
end)

window:AddSlider(moveSection, "Hip Height Offset", 0, 20, 0, function(value)
	if localPlayer.Character then
		local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.HipHeight = value
		end
	end
end)

-- ============================================================
-- COMBAT TAB CONTENT
-- ============================================================
local combatLeftCol, combatRightCol = window:CreateColumns(combatTab)

-- Aim Assistance & Tracking
local aimSection = window:AddSection(combatLeftCol, "Aim Assistance")

window:AddToggle(aimSection, "silent_aim", "Silent Aim", false, nil, function(enabled)
	Combat.SilentAim = enabled
end)

window:AddToggle(aimSection, "aim_tracking", "Aim Tracking", false, nil, function(enabled)
	Combat.AimTracking = enabled
end)

window:AddToggle(aimSection, "track_teammates", "Track Teammates", false, nil, function(enabled)
	Combat.TrackTeammates = enabled
end)

window:AddToggle(aimSection, "trigger_bot", "Trigger Bot", false, nil, function(enabled)
	Combat.TriggerBot = enabled
end)

window:AddToggle(aimSection, "fov_circle", "FOV Circle", false, nil, function(enabled)
	Combat.FovCircle = enabled
end)

window:AddSlider(aimSection, "FOV Radius", 30, 360, 120, function(value)
	Combat.FovRadius = value
end)

window:AddSlider(aimSection, "Aim Smoothing", 5, 100, 25, function(value)
	Combat.Smoothing = value / 100
end)

-- Hitboxes & Range
local hitSection = window:AddSection(combatRightCol, "Hitbox Modifiers")

window:AddToggle(hitSection, "expand_hitboxes", "Expand Hitbox's", false, nil, function(enabled)
	Combat.ExpandHitboxes = enabled
	if not enabled then
		Combat.resetHitboxes()
	end
end)

window:AddSlider(hitSection, "Hitbox Size", 2, 30, 12, function(value)
	Combat.HitboxSize = value
end)

-- ============================================================
-- GAME TAB CONTENT (RUN N HIDE / DISASTER SURVIVAL & UTILITIES)
-- ============================================================
local gameLeftCol, gameRightCol = window:CreateColumns(gameTab)

if gameTabTitle == "Run N Hide" then
	-- ── LEFT COLUMN: AIM ASSIST & COMBAT ───────────────────────
	local aimSection = window:AddSection(gameLeftCol, "Aim Assist Engine")

	window:AddToggle(aimSection, "rnh_aim_assist", "Aim Assist (Hold R-Click)", false, nil, function(val)
		RunNHide.AimAssist = val
	end)

	window:AddToggle(aimSection, "rnh_aim_fov", "Show Aim Assist FOV", false, nil, function(val)
		RunNHide.AimAssistFOV = val
	end)

	window:AddToggle(aimSection, "rnh_aim_wallcheck", "Aim Wallcheck (Visible Only)", true, nil, function(val)
		RunNHide.AimWallCheck = val
	end)

	window:AddToggle(aimSection, "rnh_aim_head", "Target Head (Off = Torso)", true, nil, function(val)
		RunNHide.AimTargetPart = if val then "Head" else "Torso"
	end)

	window:AddSlider(aimSection, "Aim FOV Radius", 40, 350, 140, function(val)
		RunNHide.AimRadius = val
	end)

	window:AddSlider(aimSection, "Aim Smoothing (1=Snap)", 1, 15, 5, function(val)
		RunNHide.AimSmoothing = val
	end)

	local weaponMechSection = window:AddSection(gameLeftCol, "Weapon Mechanisms")

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

	window:AddToggle(weaponMechSection, "rnh_no_recoil", "Zero Recoil", false, nil, function(val)
		RunNHide.NoRecoil = val
		RunNHide.updateWeapons()
	end)

	window:AddToggle(weaponMechSection, "rnh_fast_fire", "Rapid Fire Rate Overclock", false, nil, function(val)
		RunNHide.FastFireRate = val
		RunNHide.updateWeapons()
	end)

	window:AddSlider(weaponMechSection, "Burst Shot Count", 2, 10, 3, function(val)
		RunNHide.BurstCount = val
	end)

	window:AddSlider(weaponMechSection, "Burst Delay (ms)", 20, 150, 60, function(val)
		RunNHide.BurstDelay = val / 1000
	end)

	local gunOpsSection = window:AddSection(gameLeftCol, "Gun Operations")

	window:AddButton(gunOpsSection, "Force Instant Reload", function()
		if RunNHide.forceReload() then
			window:Notify("Run N Hide", "Weapon reloaded & chambered", 3)
		else
			window:Notify("Run N Hide", "No gun equipped", 3)
		end
	end)

	window:AddButton(gunOpsSection, "Chamber Equipped Weapon", function()
		if RunNHide.forceChamber() then
			window:Notify("Run N Hide", "Weapon chambered", 3)
		else
			window:Notify("Run N Hide", "No gun equipped", 3)
		end
	end)

	-- ── RIGHT COLUMN: BOUNDS, ROLES, STAMINA & CONTROLS ────────
	local boundsSection = window:AddSection(gameRightCol, "Map Bounds & Barrier Breaker")

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

	window:AddToggle(boundsSection, "rnh_anti_void", "Anti-Void Safety Floor", false, nil, function(val)
		RunNHide.AntiVoidFloor = val
		RunNHide.updateVoidPlatform()
	end)

	window:AddButton(boundsSection, "Audit & Disable All Bounds Now", function()
		RunNHide.DisableBarriers = true
		RunNHide.DisableKillbricks = true
		local count = RunNHide.scanAndDisableBoundaries()
		window:Notify("Boundary Audit", string.format("All invisible walls & killbricks purged (%d checked)", count), 3.5)
	end)

	local roleSection = window:AddSection(gameRightCol, "Role Tracker")

	window:AddToggle(roleSection, "rnh_role_tracker", "Role Tracker Watcher", false, nil, function(val)
		RunNHide.RoleTracker = val
	end)

	local stamSection = window:AddSection(gameRightCol, "Stamina & Ragdoll Mobility")

	window:AddToggle(stamSection, "rnh_move_ragdoll", "Move In Ragdoll (WASD Steer)", true, nil, function(val)
		RunNHide.MoveInRagdoll = val
	end)

	window:AddToggle(stamSection, "rnh_ragdoll_jump", "Ragdoll Jump Boost (Spacebar)", true, nil, function(val)
		RunNHide.RagdollJumpBoost = val
	end)

	window:AddToggle(stamSection, "rnh_auto_standup", "Auto Instant Standup", false, nil, function(val)
		RunNHide.AutoStandup = val
	end)

	window:AddToggle(stamSection, "rnh_inf_stamina", "Infinite Stamina (Zero Drain)", false, nil, function(val)
		RunNHide.InfiniteStamina = val
		RunNHide.updateStamina()
	end)

	window:AddToggle(stamSection, "rnh_fast_regen", "Fast Stamina Recovery", false, nil, function(val)
		RunNHide.FastRegen = val
		RunNHide.updateStamina()
	end)

	window:AddToggle(stamSection, "rnh_speed_boost", "Sprint Speed Multiplier", false, nil, function(val)
		RunNHide.SpeedBoost = val
		RunNHide.updateStamina()
	end)

	window:AddSlider(stamSection, "Ragdoll Move Speed", 16, 120, 32, function(val)
		RunNHide.RagdollSpeed = val
	end)

	window:AddSlider(stamSection, "Stamina Drain Reduction %", 0, 100, 50, function(val)
		RunNHide.StaminaReduction = val
		RunNHide.updateStamina()
	end)

	window:AddSlider(stamSection, "Sprint Speed Factor", 1, 3, 1, function(val)
		RunNHide.SpeedMultiplier = val
		RunNHide.updateStamina()
	end)

	window:AddButton(stamSection, "Force Instant Standup / Recover", function()
		RunNHide.forceStandup()
		window:Notify("Ragdoll", "Recovered from ragdoll state", 3)
	end)

	local grabSection = window:AddSection(gameRightCol, "Weapon Spawns & Arena")

	window:AddToggle(grabSection, "rnh_auto_grab", "Auto-Grab Spawned Weapons", false, nil, function(val)
		RunNHide.AutoGrabWeapons = val
		if val then
			local c = RunNHide.grabAllScatteredWeapons()
			window:Notify("Weapon Grabber", string.format("Auto-grab active (%d prompts checked)", c), 3)
		end
	end)

	window:AddButton(grabSection, "Grab All Map Weapons Now", function()
		local c = RunNHide.grabAllScatteredWeapons()
		window:Notify("Weapon Grabber", string.format("Grabbed %d weapons from map", c), 3.5)
	end)

	window:AddButton(grabSection, "Teleport to PVP Arena", function()
		if RunNHide.teleportToArena() then
			window:Notify("Arena", "Teleported to PVP Arena loadout zone", 3)
		end
	end)

	window:AddButton(grabSection, "Join VC Server Only", function()
		window:Notify("Server Hop", "Initiating voice server hop...", 3)
		RunNHide.joinVCServer()
	end)
else
	-- Disaster Intelligence (Default / NDS)
	local disasterSection = window:AddSection(gameLeftCol, "Disaster Intelligence")

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

	window:AddToggle(disasterSection, "no_fall_damage", "No Fall Damage", false, nil, function(enabled)
		DisasterSurvival.setNoFallDamage(enabled)
	end)

	window:AddToggle(disasterSection, "flight_no_fall", "Flight No Fall Damage", false, nil, function(enabled)
		DisasterSurvival.setFlight(enabled)
	end)

	window:AddSlider(disasterSection, "Flight Speed", 20, 150, 50, function(value)
		DisasterSurvival.FlightSpeed = value
	end)

	-- Physics & Protection
	local physicsSection = window:AddSection(gameRightCol, "Physics & Protection")

	window:AddToggle(physicsSection, "anti_fling", "Anti-Fling Protection", false, nil, function(enabled)
		DisasterSurvival.setAntiFling(enabled)
	end)

	window:AddToggle(physicsSection, "player_fling", "Object / Player Fling", false, nil, function(enabled)
		DisasterSurvival.setFling(enabled)
	end)
end

-- ============================================================
-- VISUALS TAB CONTENT
-- ============================================================
local visLeftCol, visRightCol = window:CreateColumns(visualsTab)

-- 2D ESP & Boxes
local espSection = window:AddSection(visLeftCol, "2D ESP & Overlays")

window:AddToggle(espSection, "esp_box_2d", "2D ESP Box", false, nil, function(enabled)
	Visuals.Box2D = enabled
end)

window:AddToggle(espSection, "esp_health_bar", "Health Bar", false, nil, function(enabled)
	Visuals.HealthBar = enabled
end)

window:AddToggle(espSection, "esp_tracers", "Tracers", false, nil, function(enabled)
	Visuals.Tracers = enabled
end)

-- 3D Chams & Skeletons
local chamsSection = window:AddSection(visRightCol, "Chams & Skeletons")

window:AddToggle(chamsSection, "esp_chams_3d", "3D Chams / Highlights", false, nil, function(enabled)
	Visuals.Chams = enabled
end)

window:AddToggle(chamsSection, "esp_skeletons", "Skeleton ESP", false, nil, function(enabled)
	Visuals.Skeleton = enabled
end)

window:AddSlider(chamsSection, "Chams Transparency", 0, 100, 50, function(value)
	Visuals.ChamsTransparency = value / 100
end)

-- ============================================================
-- SETTINGS TAB CONTENT (THEMES, FPS, RENDERING, AUDIO, ETC)
-- ============================================================
local setLeftCol, setRightCol = window:CreateColumns(settingsTab)

-- Themes Section (Smooth Transitions: Light, Dark, Translucent Dark, Translucent Light)
local themeSection = window:AddSection(setLeftCol, "Theme & Appearance")

window:AddButton(themeSection, "Dark Mode", function()
	window:SetTheme("Dark")
end)

window:AddButton(themeSection, "Light Mode", function()
	window:SetTheme("Light")
end)

window:AddButton(themeSection, "Translucent Dark (Acrylic)", function()
	window:SetTheme("TranslucentDark")
end)

window:AddButton(themeSection, "Translucent Light (Glass)", function()
	window:SetTheme("TranslucentLight")
end)

-- GUI Visibility & Screen Cleanup Controls
local cleanSection = window:AddSection(setLeftCol, "Screen & GUI Optimization")

window:AddToggle(cleanSection, "hide_core_guis", "Disable CoreGUIs (Overlays)", true, nil, function(enabled)
	for _, guiType in ipairs(coreGuiOverlays) do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(guiType, not enabled)
		end)
	end
end)

local hiddenGameGuis: {[ScreenGui]: boolean} = {}
window:AddToggle(cleanSection, "hide_game_guis", "Hide Default Game GUIs", false, nil, function(enabled)
	local pgui = localPlayer:FindFirstChild("PlayerGui")
	if pgui then
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
end)

-- Performance Settings
local perfSection = window:AddSection(setLeftCol, "Performance")

local terrain = workspace:FindFirstChildOfClass("Terrain")
window:AddToggle(perfSection, "fps_boost", "FPS BOOST", false, nil, function(enabled)
	Lighting.GlobalShadows = not enabled
	Lighting.FogEnd = if enabled then 9e9 else 10000
	if terrain then
		terrain.WaterWaveSize = if enabled then 0 else 0.15
		terrain.WaterWaveSpeed = if enabled then 0 else 10
		terrain.WaterReflectance = if enabled then 0 else 1
	end
end)

window:AddToggle(perfSection, "fps_uncap", "FPS UNCAP", false, nil, function(enabled)
	local setfps = (setfpscap or (set_fps_cap :: any))
	if typeof(setfps) == "function" then
		setfps(if enabled then 999 else 60)
	end
end)

-- Audio Volume Controller (Scales all game audios, excludes VoiceChat)
local audioSection = window:AddSection(setRightCol, "Audio Controls")

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
	for _, obj in ipairs(game:GetDescendants()) do
		if obj:IsA("Sound") then
			updateSound(obj)
		end
	end
end)

game.DescendantAdded:Connect(function(obj)
	if obj:IsA("Sound") then
		task.defer(function()
			updateSound(obj)
		end)
	end
end)

-- Rendering Optimization Settings
local renderSection = window:AddSection(setRightCol, "3D & Texture Rendering")

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

-- ============================================================
-- CONFIGS TAB CONTENT
-- ============================================================
local confLeftCol, confRightCol = window:CreateColumns(configsTab)

local profileSection = window:AddSection(confLeftCol, "Profile Slots")
window:AddButton(profileSection, "Load Default Profile", function()
	print("[Configs] Loaded Default Profile")
end)

window:AddButton(profileSection, "Load Legit Profile", function()
	print("[Configs] Loaded Legit Profile")
end)

window:AddButton(profileSection, "Load Rage Profile", function()
	print("[Configs] Loaded Rage Profile")
end)

local actionSection = window:AddSection(confRightCol, "Config Actions")
window:AddButton(actionSection, "Save Current Config", function()
	print("[Configs] Saved Current Config")
end)

window:AddButton(actionSection, "Create New Profile", function()
	print("[Configs] Created New Profile")
end)

window:AddButton(actionSection, "Reset All Defaults", function()
	print("[Configs] Reset All Defaults")
end)

-- Explicitly activate default Main tab on load
window:SelectTab(mainTab)
