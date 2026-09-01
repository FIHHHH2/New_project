--!strict
--[=[
    ✦ Movement Gameplay Module ✦
    Provides Noclip, Fly, Infinite Jump, and Gravity Manipulation features.
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

local Movement = {}
Movement.__index = Movement

-- Flat cached BaseParts array to eliminate per-physics-frame hierarchy traversals
local cachedCharacterParts: {BasePart} = {}
local charDescendantAddedConn: RBXScriptConnection? = nil
local charDescendantRemovingConn: RBXScriptConnection? = nil

local function updateCachedParts(char: Model?)
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
		if inst:IsA("BasePart") then
			table.insert(cachedCharacterParts, inst)
		end
	end

	charDescendantAddedConn = char.DescendantAdded:Connect(function(inst)
		if inst:IsA("BasePart") then
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

if LocalPlayer.Character then
	updateCachedParts(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(updateCachedParts)

function Movement.init(window: any)
	local moveTab = window:CreateTab("Movement")
	local leftCol, rightCol = window:CreateColumns(moveTab)
	
	-- Flight & Collision
	local flightSection = window:AddSection(leftCol, "Flight & Collision")
	
	local noclipConn: RBXScriptConnection? = nil
	window:AddToggle(flightSection, "noclip_toggle", "Noclip", false, nil, function(enabled)
		if enabled then
			noclipConn = RunService.Stepped:Connect(function()
				for _, part in ipairs(cachedCharacterParts) do
					part.CanCollide = false
				end
			end)
		elseif noclipConn then
			noclipConn:Disconnect()
			noclipConn = nil
			if LocalPlayer.Character then
				local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
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
				if LocalPlayer.Character then
					local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
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
	
	-- Physics & Gravity
	local physicsSection = window:AddSection(rightCol, "World Physics")
	
	window:AddSlider(physicsSection, "Custom Gravity", 0, 196, 196, function(value)
		Workspace.Gravity = value
	end)
	
	window:AddSlider(physicsSection, "Hip Height Offset", 0, 20, 0, function(value)
		if LocalPlayer.Character then
			local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.HipHeight = value
			end
		end
	end)
	
	window:SelectTab(moveTab)
	return moveTab
end

return Movement
