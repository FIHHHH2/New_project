--!strict
local Players = game:GetService("Players")

local CoreUI = require("Core/CoreUI.luau")
local FeatureManager = require("Core/FeatureManager.luau")

local localPlayer = Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

localPlayer.CharacterAdded:Connect(function(char)
	character = char
	humanoid = char:WaitForChild("Humanoid") :: Humanoid
end)

local window = CoreUI.new("Fih Ui")

-- tabs
local menuTab = window:CreateTab("Menu")
local playerTab = window:CreateTab("Player")
local visualsTab = window:CreateTab("Visuals")
local keybindsTab = window:CreateTab("Keybinds")

-- sections & controls
local selfConfigs = window:AddSection(menuTab, "Self Configs...")

window:AddToggle(selfConfigs, "walkspeed_boost", "WalkSpeed Boost", false, Enum.KeyCode.V, function(enabled)
	if humanoid then
		humanoid.WalkSpeed = if enabled then 32 else 16
	end
end)

window:AddToggle(selfConfigs, "jumppower_boost", "JumpPower Boost", false, Enum.KeyCode.B, function(enabled)
	if humanoid then
		humanoid.JumpPower = if enabled then 100 else 50
	end
end)

window:AddSlider(selfConfigs, "Custom Speed", 16, 150, 16, function(value)
	if humanoid then
		humanoid.WalkSpeed = value
	end
end)

local modulesSection = window:AddSection(menuTab, "Modules")

window:AddToggle(modulesSection, "run_and_hide", "Run & Hide", false, Enum.KeyCode.H, function(enabled)
	print("[Module] Run & Hide state:", enabled)
end)

local visualConfigs = window:AddSection(visualsTab, "Rendering")

window:AddToggle(visualConfigs, "esp_players", "Highlight Players", false, Enum.KeyCode.J, function(enabled)
	print("[Visuals] Highlight state:", enabled)
end)
