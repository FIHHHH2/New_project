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

function Movement.init(window: any)
	local moveTab = window:CreateTab("Movement")
	local leftCol, rightCol = window:CreateColumns(moveTab)
	
	-- Flight & Collision
	local flightSection = window:AddSection(leftCol, "Flight & Collision")
	
	local noclipConn: RBXScriptConnection? = nil
	window:AddToggle(flightSection, "noclip_toggle", "Noclip", false, Enum.KeyCode.N, function(enabled)
		if enabled then
			noclipConn = RunService.Stepped:Connect(function()
				if LocalPlayer.Character then
					for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
						if part:IsA("BasePart") then
							part.CanCollide = false
						end
					end
				end
			end)
		elseif noclipConn then
			noclipConn:Disconnect()
			noclipConn = nil
		end
	end)
	
	local infJumpConn: RBXScriptConnection? = nil
	window:AddToggle(flightSection, "inf_jump", "Infinite Jump", false, Enum.KeyCode.Space, function(enabled)
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
