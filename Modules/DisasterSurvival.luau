--!strict
--[=[
    ✦ Natural Disaster Survival & Game Utilities Module ✦
    Provides Disaster Tracker, No Fall Damage, Flight with No Fall Damage, and Fling / Anti-Fling systems.
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

local DisasterSurvival = {
	DisasterTracker = false,
	CurrentDisaster = "None (In Lobby)",
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
local stateConn: RBXScriptConnection? = nil

-- Player character BaseParts cache for Anti-Fling physics bypass
local otherPlayerParts: {[Player]: {BasePart}} = {}
local characterConnections: {[Player]: {RBXScriptConnection}} = {}
local playerAddedConn: RBXScriptConnection? = nil
local playerRemovingConn: RBXScriptConnection? = nil

local function cleanPlayerConnections(plr: Player)
	local conns = characterConnections[plr]
	if conns then
		for _, conn in ipairs(conns) do
			pcall(function() conn:Disconnect() end)
		end
		characterConnections[plr] = nil
	end
	otherPlayerParts[plr] = nil
end

local function cachePlayerParts(plr: Player, char: Model)
	local parts: {BasePart} = {}
	for _, inst in ipairs(char:GetDescendants()) do
		if inst:IsA("BasePart") then
			table.insert(parts, inst)
			if DisasterSurvival.AntiFling then
				inst.CanCollide = false
			end
		end
	end
	otherPlayerParts[plr] = parts

	local conns: {RBXScriptConnection} = {}
	local descAdd = char.DescendantAdded:Connect(function(inst)
		if inst:IsA("BasePart") then
			table.insert(parts, inst)
			if DisasterSurvival.AntiFling then
				inst.CanCollide = false
			end
		end
	end)
	table.insert(conns, descAdd)

	local descRem = char.DescendantRemoving:Connect(function(inst)
		if inst:IsA("BasePart") then
			local idx = table.find(parts, inst)
			if idx then
				table.remove(parts, idx)
			end
		end
	end)
	table.insert(conns, descRem)
	characterConnections[plr] = conns
end

local function trackOtherPlayer(plr: Player)
	if plr == LocalPlayer then return end
	if plr.Character then
		cachePlayerParts(plr, plr.Character)
	end
	plr.CharacterAdded:Connect(function(char)
		cleanPlayerConnections(plr)
		cachePlayerParts(plr, char)
	end)
	plr.CharacterRemoving:Connect(function()
		cleanPlayerConnections(plr)
	end)
end

-- Initialize player tracker
for _, plr in ipairs(Players:GetPlayers()) do
	trackOtherPlayer(plr)
end
playerAddedConn = Players.PlayerAdded:Connect(trackOtherPlayer)
playerRemovingConn = Players.PlayerRemoving:Connect(function(plr)
	cleanPlayerConnections(plr)
end)

-- Clean Fall Damage Script in character and hook FreeFall state
local function applyNoFallDamage(char: Model)
	local fallScript = char:FindFirstChild("FallDamageScript")
	if fallScript then
		fallScript:Destroy()
	end
	
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		if stateConn then stateConn:Disconnect() end
		stateConn = hum.StateChanged:Connect(function(oldState, newState)
			if DisasterSurvival.NoFallDamage and (newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Freefall) then
				local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp and hrp.AssemblyLinearVelocity.Y < -40 then
					hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
				end
			end
		end)
	end
	
	char.ChildAdded:Connect(function(child)
		if DisasterSurvival.NoFallDamage and child.Name == "FallDamageScript" then
			task.defer(function()
				child:Destroy()
			end)
		end
	end)
end

-- Disaster Tracker Setup (Multi-Source detection: SurvivalTag, PlayerGui, ReplicatedStorage)
local function hookDisasterTag(char: Model, notifyCallback: ((string) -> ())?)
	if tagConn then tagConn:Disconnect() tagConn = nil end
	
	local function updateDisasterName(rawName: string)
		local cleaned = rawName:gsub("^%s+", ""):gsub("%s+$", "")
		local current = if cleaned ~= "" and cleaned ~= "None" then cleaned else "None (In Lobby)"
		if DisasterSurvival.CurrentDisaster ~= current then
			DisasterSurvival.CurrentDisaster = current
			if notifyCallback and current ~= "None (In Lobby)" then
				notifyCallback(current)
			end
		end
	end

	local function checkTag(tag: Instance)
		if tag:IsA("StringValue") and (tag.Name == "SurvivalTag" or tag.Name:find("Disaster")) then
			updateDisasterName(tag.Value)
			tag.Changed:Connect(function(newVal)
				updateDisasterName(newVal)
			end)
		end
	end
	
	local existingTag = char:FindFirstChild("SurvivalTag") or char:FindFirstChild("DisasterTag")
	if existingTag then
		checkTag(existingTag)
	else
		DisasterSurvival.CurrentDisaster = "None (In Lobby)"
	end
	tagConn = char.ChildAdded:Connect(checkTag)

	-- Secondary check from ReplicatedStorage or PlayerGui
	pcall(function()
		local rsTag = ReplicatedStorage:FindFirstChild("DisasterName") or ReplicatedStorage:FindFirstChild("CurrentDisaster")
		if rsTag and rsTag:IsA("StringValue") then
			checkTag(rsTag)
		end
	end)
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

-- Flight Engine with Zero Fall Impact and Delta Time
function DisasterSurvival.setFlight(enabled: boolean)
	DisasterSurvival.Flight = enabled
	if enabled then
		flightConn = RunService.RenderStepped:Connect(function(dt: number)
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not hrp or not hum then return end
			
			hum.PlatformStand = true
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
			
			local moveDir = Vector3.zero
			if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
				moveDir += Camera.CFrame.LookVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
				moveDir -= Camera.CFrame.LookVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
				moveDir -= Camera.CFrame.RightVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
				moveDir += Camera.CFrame.RightVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.E) then
				moveDir += Vector3.new(0, 1, 0)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.Q) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
				moveDir -= Vector3.new(0, 1, 0)
			end
			
			if moveDir.Magnitude > 0 then
				hrp.CFrame += moveDir.Unit * (DisasterSurvival.FlightSpeed * dt)
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

-- Anti-Fling: Clamps external velocity impulses and disables player collision physics via cached parts
function DisasterSurvival.setAntiFling(enabled: boolean)
	DisasterSurvival.AntiFling = enabled
	if enabled then
		antiFlingConn = RunService.Stepped:Connect(function()
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not hrp then return end
			
			if hrp.AssemblyLinearVelocity.Magnitude > 110 then
				hrp.AssemblyLinearVelocity = Vector3.zero
			end
			if hrp.AssemblyAngularVelocity.Magnitude > 50 then
				hrp.AssemblyAngularVelocity = Vector3.zero
			end
			
			for _, parts in pairs(otherPlayerParts) do
				for _, part in ipairs(parts) do
					part.CanCollide = false
				end
			end
		end)
	elseif antiFlingConn then
		antiFlingConn:Disconnect()
		antiFlingConn = nil
		-- Restore collision
		for _, parts in pairs(otherPlayerParts) do
			for _, part in ipairs(parts) do
				if part and part.Parent and part.Name ~= "HumanoidRootPart" then
					part.CanCollide = true
				end
			end
		end
	end
end

-- Player / Object Fling Engine (High-Torque 10,000,000 rad/s Physics)
function DisasterSurvival.setFling(enabled: boolean)
	DisasterSurvival.FlingMode = enabled
	if enabled then
		flingConn = RunService.Heartbeat:Connect(function()
			local char = LocalPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not (hrp and hum and hum.Health > 0) then return end
			
			hrp.AssemblyAngularVelocity = Vector3.new(0, 10000000, 0)
			local vel = hrp.AssemblyLinearVelocity
			hrp.AssemblyLinearVelocity = Vector3.new(vel.X, math.clamp(vel.Y, -80, 80), vel.Z)
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

function DisasterSurvival.cleanup()
	if flightConn then flightConn:Disconnect() flightConn = nil end
	if antiFlingConn then antiFlingConn:Disconnect() antiFlingConn = nil end
	if flingConn then flingConn:Disconnect() flingConn = nil end
	if tagConn then tagConn:Disconnect() tagConn = nil end
	if stateConn then stateConn:Disconnect() stateConn = nil end
	if playerAddedConn then playerAddedConn:Disconnect() playerAddedConn = nil end
	if playerRemovingConn then playerRemovingConn:Disconnect() playerRemovingConn = nil end

	for plr in pairs(characterConnections) do
		cleanPlayerConnections(plr)
	end
	table.clear(otherPlayerParts)

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

return DisasterSurvival
