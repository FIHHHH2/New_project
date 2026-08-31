--!strict
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

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

local localPlayer = Players.LocalPlayer
local character = localPlayer.Character
local humanoid: Humanoid? = if character then character:FindFirstChildOfClass("Humanoid") else nil

localPlayer.CharacterAdded:Connect(function(char)
	character = char
	humanoid = char:WaitForChild("Humanoid", 5) :: Humanoid?
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
task.spawn(disableCoreGuis)
localPlayer.CharacterAdded:Connect(function()
	task.spawn(disableCoreGuis)
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
	if placeId == 189707 then
		return "Natural Disaster"
	elseif placeId == 12901416348 or placeId == 12901416348 or string.find(game.Name:lower(), "run and hide") or string.find(game.Name:lower(), "demise") then
		return "Run N Hide"
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

-- ============================================================
-- MAIN TAB CONTENT (PLAYER & MOVEMENT)
-- ============================================================
local leftCol, rightCol = window:CreateColumns(mainTab)

-- LEFT COLUMN: Self Modifiers
local selfSection = window:AddSection(leftCol, "Self Modifiers")

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

local walkFlingConn: RBXScriptConnection? = nil
window:AddToggle(moveSection, "walk_fling", "Walk Fling (Touch To Fling)", false, nil, function(enabled)
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

window:AddToggle(aimSection, "wall_bang", "Wall Bang (Shoot Thru Walls)", false, nil, function(enabled)
	Combat.Wallbang = enabled
end)

window:AddToggle(aimSection, "target_head", "Target Head (Off = Torso)", true, nil, function(enabled)
	Combat.TargetPart = if enabled then "Head" else "Torso"
end)

window:AddToggle(aimSection, "aim_tracking", "Aim Tracking (Camera Lock)", false, nil, function(enabled)
	Combat.AimTracking = enabled
end)

window:AddToggle(aimSection, "aim_always", "Always Lock (Ignore RMB Hold)", false, nil, function(enabled)
	Combat.AimMode = if enabled then "Always" else "Hold RMB"
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

window:AddSlider(aimSection, "Hit Chance %", 10, 100, 100, function(value)
	Combat.HitChance = value
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
	-- ── LEFT COLUMN: WEAPON MECHANISMS & GUN OPERATIONS ────────
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
		RunNHide.ensureVoidPlatform()
	end)

	window:AddButton(boundsSection, "Audit & Disable All Bounds Now", function()
		RunNHide.DisableBarriers = true
		RunNHide.DisableKillbricks = true
		local count = RunNHide.scanAndDisableBoundaries()
		window:Notify("Audit", string.format("Neutralized %d boundaries & killbricks", count), 3.5)
	end)

	local staminaSection = window:AddSection(gameRightCol, "Stamina & Mobility")

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

	local grabSection = window:AddSection(gameRightCol, "Item & Role Tracker")

	window:AddToggle(grabSection, "rnh_role_tracker", "Role Tracker & ESP", false, nil, function(val)
		RunNHide.RoleTracker = val
	end)

	window:AddToggle(grabSection, "rnh_auto_grab", "Auto-Grab Dropped Weapons", false, nil, function(val)
		RunNHide.AutoGrabWeapons = val
	end)

	window:AddButton(grabSection, "Grab All Scattered Guns Now", function()
		local count = RunNHide.grabAllScatteredWeapons()
		window:Notify("Weapons", string.format("Claimed %d dropped guns", count), 3)
	end)

	window:AddButton(grabSection, "Teleport to PVP Arena", function()
		if RunNHide.teleportToArena() then
			window:Notify("Arena", "Teleported to PVP Arena loadout zone", 3)
		end
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

-- 2D ESP & Overlays
local espSection = window:AddSection(visLeftCol, "2D ESP & Overlays")

window:AddToggle(espSection, "music_tracker_widget", "Music Tracker Widget", true, nil, function(enabled)
	musicTrackerWidget.SetVisible(enabled)
end)

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
-- SETTINGS TAB CONTENT (THEMES, MODULES, FPS, RENDERING, AUDIO)
-- ============================================================
local setLeftCol, setRightCol = window:CreateColumns(settingsTab)

-- 1. Module Management (Enable/Disable Main Engine Modules)
local moduleSection = window:AddSection(setLeftCol, "Module Management")

window:AddToggle(moduleSection, "mod_combat", "Combat Module", true, nil, function(enabled)
	FeatureManager.setModuleState("combat", enabled)
	if not enabled then
		Combat.SilentAim = false
		Combat.AimTracking = false
		Combat.TriggerBot = false
		Combat.ExpandHitboxes = false
		Combat.resetHitboxes()
	end
end)

window:AddToggle(moduleSection, "mod_visuals", "Visuals Module (ESP / Chams)", true, nil, function(enabled)
	FeatureManager.setModuleState("visuals", enabled)
	if not enabled then
		Visuals.Box2D = false
		Visuals.HealthBar = false
		Visuals.Tracers = false
		Visuals.Chams = false
		Visuals.Skeleton = false
	end
end)

window:AddToggle(moduleSection, "mod_movement", "Movement & Exploits Module", true, nil, function(enabled)
	FeatureManager.setModuleState("movement", enabled)
	if not enabled then
		if noclipConn then noclipConn:Disconnect() noclipConn = nil end
		if infJumpConn then infJumpConn:Disconnect() infJumpConn = nil end
		if walkFlingConn then walkFlingConn:Disconnect() walkFlingConn = nil end
	end
end)

window:AddToggle(moduleSection, "mod_game_utils", "Game Utilities Module", true, nil, function(enabled)
	FeatureManager.setModuleState("game_utils", enabled)
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
	end
end)

window:AddToggle(moduleSection, "mod_music_tracker", "Music Tracker Widget", true, nil, function(enabled)
	FeatureManager.setModuleState("music_tracker", enabled)
	musicTrackerWidget.SetVisible(enabled)
end)

window:AddToggle(moduleSection, "mod_player_list", "Player List Widget", true, nil, function(enabled)
	FeatureManager.setModuleState("player_list", enabled)
	playerListWidget.Frame.Visible = enabled
end)

window:AddToggle(moduleSection, "mod_chat_widget", "Chat Widget", true, nil, function(enabled)
	FeatureManager.setModuleState("chat_widget", enabled)
	chatWidgetInstance.Frame.Visible = enabled
end)

-- 2. Theme & Appearance (Persistent on Leave)
local themeSection = window:AddSection(setLeftCol, "Theme & Appearance")

window:AddButton(themeSection, "Dark Mode", function()
	window:SetTheme("Dark")
	window:Notify("Theme", "Saved Dark Mode", 2)
end)

window:AddButton(themeSection, "Light Mode", function()
	window:SetTheme("Light")
	window:Notify("Theme", "Saved Light Mode", 2)
end)

window:AddButton(themeSection, "Translucent Dark (Acrylic)", function()
	window:SetTheme("TranslucentDark")
	window:Notify("Theme", "Saved Acrylic Dark Mode", 2)
end)

window:AddButton(themeSection, "Translucent Light (Glass)", function()
	window:SetTheme("TranslucentLight")
	window:Notify("Theme", "Saved Glass Light Mode", 2)
end)

window:AddButton(themeSection, "Adaptive (Album Cover)", function()
	window:SetTheme("Adaptive")
	window:Notify("Theme", "Saved Adaptive Mode", 2)
end)

-- 3. Screen & GUI Cleanup
local cleanSection = window:AddSection(setLeftCol, "Screen & GUI Optimization")

window:AddToggle(cleanSection, "hide_default_guis", "Hide Game Default GUIs (Topbar & Core)", true, nil, function(enabled)
	disableRobloxTopBarApp(enabled)
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

-- 4. Performance Settings
local perfSection = window:AddSection(setRightCol, "Performance")

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

-- 5. Audio Volume Controller
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

-- 6. Rendering Optimization
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

-- Initial scan of configs on startup
task.spawn(refreshProfilesList)

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
