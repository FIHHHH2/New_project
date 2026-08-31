--!strict
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local CoreUI = require("Core/CoreUI.luau")
local FeatureManager = require("Core/FeatureManager.luau")
local Visuals = require("Modules/Visuals.luau")

local localPlayer = Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

localPlayer.CharacterAdded:Connect(function(char)
	character = char
	humanoid = char:WaitForChild("Humanoid") :: Humanoid
end)

local window = CoreUI.new("Project Fih Menu")

-- Active sidebar navigation tabs
local mainTab = window:CreateTab("Main")
local visualsTab = window:CreateTab("Visuals")
local subTab = window:CreateTab("Tab")

-- Dedicated Settings & Configs tabs (opened/closed via top right buttons)
local settingsTab = window:CreateTab("Settings", true)
local configsTab = window:CreateTab("Configs", true)

window:BindSettingsTab(settingsTab)
window:BindConfigsTab(configsTab)

-- Track loaded modules to prevent duplicate tabs
local loadedModules: {[string]: any} = {}

-- ============================================================
-- MAIN TAB CONTENT
-- ============================================================
window:AddBanner(mainTab)

local leftCol, rightCol = window:CreateColumns(mainTab)

-- left column: category "Self Configs"
local selfSection = window:AddSection(leftCol, "Self Configs")

window:AddToggle(selfSection, "walkspeed_boost", "WalkSpeed Boost", false, Enum.KeyCode.V, function(enabled)
	if humanoid then
		humanoid.WalkSpeed = if enabled then 32 else 16
	end
end)

window:AddToggle(selfSection, "jumppower_boost", "JumpPower Boost", false, Enum.KeyCode.B, function(enabled)
	if humanoid then
		humanoid.JumpPower = if enabled then 100 else 50
	end
end)

window:AddSlider(selfSection, "Custom Speed", 16, 150, 16, function(value)
	if humanoid then
		humanoid.WalkSpeed = value
	end
end)

-- right column: category "Modules" (Dynamic Module Loader)
local moduleSection = window:AddSection(rightCol, "Modules")

window:AddButton(moduleSection, "Load Combat Module", function()
	if loadedModules["Combat"] then
		window:SelectTab(loadedModules["Combat"])
	else
		local success, Combat = pcall(function()
			return require("Modules/Combat.luau")
		end)
		if success and Combat and typeof(Combat.init) == "function" then
			local tab = Combat.init(window)
			loadedModules["Combat"] = tab
		else
			warn("[Main] Failed to load Combat module:", Combat)
		end
	end
end)

window:AddButton(moduleSection, "Load Movement Module", function()
	if loadedModules["Movement"] then
		window:SelectTab(loadedModules["Movement"])
	else
		local success, Movement = pcall(function()
			return require("Modules/Movement.luau")
		end)
		if success and Movement and typeof(Movement.init) == "function" then
			local tab = Movement.init(window)
			loadedModules["Movement"] = tab
		else
			warn("[Main] Failed to load Movement module:", Movement)
		end
	end
end)

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
