--!strict
--[=[
    ✦ Combat Gameplay Module ✦
    Provides Aimbot, Silent Aim, and Hitbox Expansion features.
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

local Combat = {}
Combat.__index = Combat

function Combat.init(window: any)
	local combatTab = window:CreateTab("Combat")
	local leftCol, rightCol = window:CreateColumns(combatTab)
	
	-- Targeting & Aim
	local aimSection = window:AddSection(leftCol, "Aim Assistance")
	
	window:AddToggle(aimSection, "silent_aim", "Silent Aim", false, Enum.KeyCode.Q, function(enabled)
		print("[Combat] Silent Aim:", enabled)
	end)
	
	window:AddToggle(aimSection, "aimbot_fov", "Show FOV Circle", false, nil, function(enabled)
		print("[Combat] Show FOV:", enabled)
	end)
	
	window:AddSlider(aimSection, "Aim FOV Radius", 30, 360, 90, function(value)
		print("[Combat] FOV Radius set to:", value)
	end)
	
	-- Hitboxes & Range
	local hitSection = window:AddSection(rightCol, "Hitbox Modifiers")
	
	local originalSizes: {[BasePart]: Vector3} = {}
	window:AddToggle(hitSection, "hitbox_expander", "Expand Hitboxes", false, nil, function(enabled)
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer and player.Character then
				local hrp = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp then
					if enabled then
						if not originalSizes[hrp] then
							originalSizes[hrp] = hrp.Size
						end
						hrp.Size = Vector3.new(12, 12, 12)
						hrp.Transparency = 0.6
						hrp.CanCollide = false
					else
						local orig = originalSizes[hrp] or Vector3.new(2, 2, 1)
						hrp.Size = orig
						hrp.Transparency = 1
					end
				end
			end
		end
	end)
	
	window:AddSlider(hitSection, "Hitbox Size", 2, 25, 12, function(value)
		print("[Combat] Hitbox Size set to:", value)
	end)
	
	window:SelectTab(combatTab)
	return combatTab
end

return Combat
