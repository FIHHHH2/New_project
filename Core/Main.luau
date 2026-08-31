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

local window = CoreUI.new("Project Fih Menu")

-- active tabs: Main & Tab placeholder
local mainTab = window:CreateTab("Main")
local subTab = window:CreateTab("Tab")

-- top banner card on Main tab
window:AddBanner(mainTab)

-- dual-column layout below banner
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

-- right column: category "Modules"
local moduleSection = window:AddSection(rightCol, "Modules")

window:AddToggle(moduleSection, "run_and_hide", "Run & Hide", false, Enum.KeyCode.H, function(enabled)
	print("[Module] Run & Hide:", enabled)
end)

window:AddToggle(moduleSection, "esp_players", "Highlight Players", false, Enum.KeyCode.J, function(enabled)
	print("[Visuals] Highlight:", enabled)
end)

window:AddToggle(moduleSection, "infinite_jump", "Infinite Jump", false, Enum.KeyCode.Space, function(enabled)
	print("[Combat] Infinite Jump:", enabled)
end)
