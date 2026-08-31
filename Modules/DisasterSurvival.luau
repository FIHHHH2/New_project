--!strict
--[=[
    ✦ Natural Disaster Survival & Game Utilities Module ✦
    Provides Disaster Tracker, No Fall Damage, Flight with No Fall Damage, and Fling / Anti-Fling systems.
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

local DisasterSurvival = {
	DisasterTracker = false,
	CurrentDisaster = "None",
	NoFallDamage = false,
	Flight = false,
	FlightSpeed = 50,
	AntiFling = false,
	FlingMode = false
}

local fallConn: RBXScriptConnection? = nil
local flightConn: RBXScriptConnection? = nil
local antiFlingConn: RBXScriptConnection? = nil
local flingConn: RBXScriptConnection? = nil
local tagConn: RBXScriptConnection? = nil

-- Clean Fall Damage Script in character
local function applyNoFallDamage(char: Model)
	local fallScript = char:FindFirstChild("FallDamageScript")
	if fallScript then
		fallScript:Destroy()
	end
	char.ChildAdded:Connect(function(child)
		if DisasterSurvival.NoFallDamage and child.Name == "FallDamageScript" then
			task.defer(function()
				child:Destroy()
			end)
		end
	end)
end

-- Disaster Tracker Setup
local function hookDisasterTag(char: Model, notifyCallback: ((string) -> ())?)
	if tagConn then tagConn:Disconnect() tagConn = nil end
	
	local function checkTag(tag: Instance)
		if tag:IsA("StringValue") and tag.Name == "SurvivalTag" then
			DisasterSurvival.CurrentDisaster = tag.Value
			if notifyCallback and tag.Value ~= "" and tag.Value ~= "None" then
				notifyCallback(tag.Value)
			end
			tag.Changed:Connect(function(newVal)
				DisasterSurvival.CurrentDisaster = newVal
				if notifyCallback and newVal ~= "" and newVal ~= "None" then
					notifyCallback(newVal)
				end
			end)
		end
	end
	
	local existingTag = char:FindFirstChild("SurvivalTag")
	if existingTag then
		checkTag(existingTag)
	end
	tagConn = char.ChildAdded:Connect(checkTag)
end

function DisasterSurvival.init(notifyCallback: ((string) -> ())?)
	if LocalPlayer.Character then
		if DisasterSurvival.NoFallDamage then
			applyNoFallDamage(LocalPlayer.Character)
		end
		hookDisasterTag(LocalPlayer.Character, notifyCallback)
	end
	
	LocalPlayer.CharacterAdded:Connect(function(char)
		if DisasterSurvival.NoFallDamage then
			applyNoFallDamage(char)
		end
		hookDisasterTag(char, notifyCallback)
	end)
end

function DisasterSurvival.setNoFallDamage(enabled: boolean)
	DisasterSurvival.NoFallDamage = enabled
	if enabled and LocalPlayer.Character then
		applyNoFallDamage(LocalPlayer.Character)
	end
end

-- Flight Engine with Zero Fall Impact
function DisasterSurvival.setFlight(enabled: boolean)
	DisasterSurvival.Flight = enabled
	if enabled then
		flightConn = RunService.RenderStepped:Connect(function()
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not hrp or not hum then return end
			
			hum.PlatformStand = true
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
			
			local moveDir = Vector3.zero
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then
				moveDir += Camera.CFrame.LookVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then
				moveDir -= Camera.CFrame.LookVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then
				moveDir -= Camera.CFrame.RightVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then
				moveDir += Camera.CFrame.RightVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				moveDir += Vector3.new(0, 1, 0)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
				moveDir -= Vector3.new(0, 1, 0)
			end
			
			if moveDir.Magnitude > 0 then
				hrp.CFrame += moveDir.Unit * (DisasterSurvival.FlightSpeed * (1/60))
			end
		end)
	elseif flightConn then
		flightConn:Disconnect()
		flightConn = nil
		if LocalPlayer.Character then
			local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if hum then hum.PlatformStand = false end
			if hrp then
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
			end
		end
	end
end

-- Anti-Fling: Clamps external velocity impulses and disables player collision physics
function DisasterSurvival.setAntiFling(enabled: boolean)
	DisasterSurvival.AntiFling = enabled
	if enabled then
		antiFlingConn = RunService.Stepped:Connect(function()
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not hrp then return end
			
			-- Zero out extreme unnatural velocity impulses
			if hrp.AssemblyLinearVelocity.Magnitude > 110 then
				hrp.AssemblyLinearVelocity = Vector3.zero
			end
			if hrp.AssemblyAngularVelocity.Magnitude > 50 then
				hrp.AssemblyAngularVelocity = Vector3.zero
			end
			
			-- Disable collision with other player characters to prevent player collision fling
			for _, otherPlayer in ipairs(Players:GetPlayers()) do
				if otherPlayer ~= LocalPlayer and otherPlayer.Character then
					for _, part in ipairs(otherPlayer.Character:GetDescendants()) do
						if part:IsA("BasePart") then
							part.CanCollide = false
						end
					end
				end
			end
		end)
	elseif antiFlingConn then
		antiFlingConn:Disconnect()
		antiFlingConn = nil
	end
end

-- Player / Object Fling Engine
function DisasterSurvival.setFling(enabled: boolean)
	DisasterSurvival.FlingMode = enabled
	if enabled then
		flingConn = RunService.Stepped:Connect(function()
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not hrp then return end
			
			-- High torque spin velocity for touch fling
			hrp.AssemblyAngularVelocity = Vector3.new(0, 99999, 0)
		end)
	elseif flingConn then
		flingConn:Disconnect()
		flingConn = nil
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			hrp.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

return DisasterSurvival
