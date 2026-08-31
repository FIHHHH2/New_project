--!strict
--[=[
    ✦ Run and Hide / Demise Engine Advanced Combat & Utility Module ✦
    Provides Demise Gun Engine, Role Tracker, Boundary Breaker, Stamina & Ragdoll Mobility.
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

local RunNHide = {
	-- Stamina & Movement
	InfiniteStamina = false,
	StaminaReduction = 0,
	FastRegen = false,
	SpeedBoost = false,
	SpeedMultiplier = 1.0,
	MoveInRagdoll = false,
	RagdollSpeed = 32,
	RagdollJumpBoost = false,
	AutoStandup = false,

	-- Boundary & Barrier Breaker
	DisableBarriers = false,
	DisableKillbricks = false,
	AntiVoidFloor = false,
	DisabledParts = {} :: {[BasePart]: string},
	VoidSafetyPlat = nil :: Part?,

	-- Weapon Mechanisms
	SilentGunAudio = true,
	QuickReload = false,
	AutoChamber = false,
	CompleteAuto = false,
	SemiAutoForce = false,
	BurstMode = false,
	NoRecoil = false,
	FastFireRate = false,
	CustomFireRate = 0.05,
	BurstCount = 3,
	BurstDelay = 0.06,
	AutoGrabWeapons = false,

	-- Role Tracker
	RoleTracker = false,
	LastKnownRoles = {} :: {[Player]: string},

	-- Internal states
	IsShooting = false,
	BurstActive = false,
	IsActive = false
}

local connections: {RBXScriptConnection} = {}
local originalConfigs: {[string]: any} = {}
local originalStamina: any = nil

-- Resolve Demise Gun System & Movement Modules
local Guns = nil
local Packets = nil
local Config = nil
local Muzzle = nil

local function resolveDemiseModules()
	pcall(function()
		local gunSystemFolder = ReplicatedStorage:FindFirstChild("GunSystem")
		local modulesFolder = ReplicatedStorage:FindFirstChild("Modules")

		local gunsDataModule = gunSystemFolder and gunSystemFolder:FindFirstChild("Data") and gunSystemFolder.Data:FindFirstChild("Guns")
		local packetsModule = modulesFolder and modulesFolder:FindFirstChild("Data") and modulesFolder.Data:FindFirstChild("Packets")
		local configModule = modulesFolder and modulesFolder:FindFirstChild("Data") and modulesFolder.Data:FindFirstChild("Config")
		local muzzleLib = gunSystemFolder and gunSystemFolder:FindFirstChild("Libraries") and gunSystemFolder.Libraries:FindFirstChild("Muzzle")

		if gunsDataModule then Guns = require(gunsDataModule) end
		if packetsModule then Packets = require(packetsModule) end
		if configModule then Config = require(configModule) end
		if muzzleLib then Muzzle = require(muzzleLib) end
	end)

	if Guns and type(Guns) == "table" then
		for gunName, config in pairs(Guns) do
			if type(config) == "table" then
				originalConfigs[gunName] = {
					FireMode    = config.FireMode,
					FireRate    = config.FireRate,
					ReloadTime  = config.ReloadTime,
					ChamberTime = config.ChamberTime,
					Recoil      = config.Recoil,
					MaxAmmo     = config.MaxAmmo,
					Range       = config.Range
				}
			end
		end
	end

	if Config and Config.Stamina then
		originalStamina = {
			Max        = Config.Stamina.Max,
			DrainRate  = Config.Stamina.DrainRate,
			RegenRate  = Config.Stamina.RegenRate,
			RegenDelay = Config.Stamina.RegenDelay
		}
	end
end

resolveDemiseModules()

local function getEquippedGun(): (Tool?, any)
	local char = LocalPlayer.Character
	if not char or not Guns then return nil, nil end
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Tool") and Guns[child.Name] then
			return child, Guns[child.Name]
		end
	end
	return nil, nil
end

local function refreshEquippedGun()
	local char = LocalPlayer.Character
	if not char or not Guns then return end
	local tool: Tool? = nil
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Tool") and Guns[child.Name] then
			tool = child
			break
		end
	end
	if tool then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:UnequipTools()
			task.wait(0.03)
			hum:EquipTool(tool)
		end
	end
end

local function updateWeaponConfigs(skipRefresh: boolean?)
	if not Guns then return end
	for gunName, config in pairs(Guns) do
		local original = originalConfigs[gunName]
		if not original then continue end

		if RunNHide.CompleteAuto then
			config.FireMode = "Auto"
		elseif RunNHide.SemiAutoForce then
			config.FireMode = "Semi"
		else
			config.FireMode = original.FireMode
		end

		if RunNHide.FastFireRate then
			config.FireRate = RunNHide.CustomFireRate
		else
			config.FireRate = original.FireRate
		end

		if RunNHide.QuickReload then
			config.ReloadTime = 0.05
			config.ChamberTime = 0.05
		else
			config.ReloadTime = original.ReloadTime
			config.ChamberTime = original.ChamberTime
		end

		if RunNHide.NoRecoil then
			config.Recoil = 0
		else
			config.Recoil = original.Recoil
		end
	end

	pcall(function()
		local soundFolder = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Sounds") and ReplicatedStorage.Assets.Sounds:FindFirstChild("Firearms")
		if soundFolder then
			for _, gunFolder in ipairs(soundFolder:GetChildren()) do
				for _, s in ipairs(gunFolder:GetDescendants()) do
					if s:IsA("Sound") then
						if RunNHide.SilentGunAudio then
							if s:GetAttribute("OrigVol") == nil then
								s:SetAttribute("OrigVol", s.Volume)
							end
							s.Volume = 0
						else
							local orig = s:GetAttribute("OrigVol")
							if orig ~= nil then
								s.Volume = orig
							end
						end
					end
				end
			end
		end
	end)

	if not skipRefresh then
		task.spawn(refreshEquippedGun)
	end
end

local function applyStaminaState()
	local char = LocalPlayer.Character
	if char then
		if RunNHide.InfiniteStamina then
			char:SetAttribute("StamDrainMult", 0)
			char:SetAttribute("StamMult", 10)
		elseif RunNHide.StaminaReduction > 0 then
			local mult = math.clamp(1 - (RunNHide.StaminaReduction / 100), 0, 1)
			char:SetAttribute("StamDrainMult", mult)
			char:SetAttribute("StamMult", 1 + (RunNHide.StaminaReduction / 50))
		else
			char:SetAttribute("StamDrainMult", 1)
			char:SetAttribute("StamMult", 1)
		end

		if RunNHide.SpeedBoost and RunNHide.SpeedMultiplier > 1 then
			char:SetAttribute("SpeedMult", RunNHide.SpeedMultiplier)
		else
			char:SetAttribute("SpeedMult", 1)
		end
	end

	if Config and Config.Stamina and originalStamina then
		if RunNHide.InfiniteStamina then
			Config.Stamina.DrainRate = 0
			Config.Stamina.RegenRate = 100
			Config.Stamina.RegenDelay = 0
		elseif RunNHide.StaminaReduction > 0 then
			local factor = math.clamp(1 - (RunNHide.StaminaReduction / 100), 0, 1)
			Config.Stamina.DrainRate = originalStamina.DrainRate * factor
			if RunNHide.FastRegen then
				Config.Stamina.RegenRate = originalStamina.RegenRate * 4
				Config.Stamina.RegenDelay = 0.2
			end
		else
			Config.Stamina.DrainRate = originalStamina.DrainRate
			Config.Stamina.RegenRate = originalStamina.RegenRate
			Config.Stamina.RegenDelay = originalStamina.RegenDelay
		end
	end
end

-- Fast Reload and Auto-Chamber triggers
local function executeQuickReload(tool: Tool?)
	if not tool or not tool.Parent or not Packets then return end
	if Packets.GunReload then Packets.GunReload:Fire({ Tool = tool }) end
	task.wait(0.08)
	if Packets.GunChamber then Packets.GunChamber:Fire({ Tool = tool }) end
end

local function executeAutoChamber(tool: Tool?)
	if not tool or not tool.Parent or not Packets then return end
	if not tool:GetAttribute("Chambered") and Packets.GunChamber then
		Packets.GunChamber:Fire({ Tool = tool })
	end
end

local function fireSingleRound(tool: Tool, config: any): boolean
	if not tool or tool.Parent ~= LocalPlayer.Character or not Packets then return false end
	local cam = Workspace.CurrentCamera
	if not cam then return false end

	local ammo = tool:GetAttribute("CurrentAmmo")
	local currentAmmo = if typeof(ammo) == "number" then ammo else (config.MaxAmmo or 0)
	if currentAmmo <= 0 then
		if RunNHide.QuickReload then
			executeQuickReload(tool)
		end
		return false
	end

	if not tool:GetAttribute("Chambered") then
		executeAutoChamber(tool)
		task.wait(0.05)
	end

	if Packets.GunFireHit then
		Packets.GunFireHit:Fire({
			Tool = tool,
			Origin = cam.CFrame.Position,
			Direction = cam.CFrame.LookVector
		})
	end

	if Muzzle then
		pcall(function()
			if not RunNHide.SilentGunAudio then
				Muzzle.Play(tool.Name, LocalPlayer.Character)
			else
				Muzzle.PlayFlash(tool.Name, LocalPlayer.Character)
			end
		end)
	end

	return true
end

local function triggerBurst(tool: Tool, config: any)
	if RunNHide.BurstActive then return end
	RunNHide.BurstActive = true

	task.spawn(function()
		local shotsToFire = RunNHide.BurstCount or 3
		local delayTime = RunNHide.BurstDelay or 0.06

		for _ = 1, shotsToFire do
			if not tool or tool.Parent ~= LocalPlayer.Character then break end
			local fired = fireSingleRound(tool, config)
			if not fired then break end
			task.wait(delayTime)
		end
		RunNHide.BurstActive = false
	end)
end

-- ── Boundary Breaker ──────────────────────────────────────────────
local function neutralizeSinglePart(part: Instance)
	if not part:IsA("BasePart") then return end
	if part:IsDescendantOf(Players) then return end

	local name = part.Name:lower()
	local parentName = (part.Parent and part.Parent.Name or ""):lower()

	local isKill = name:find("kill") or parentName:find("kill") or name:find("death") or parentName:find("death") or name:find("lava") or name:find("hazard")
	if RunNHide.DisableKillbricks and isKill then
		part.CanTouch = false
		part.CanCollide = false
		pcall(function()
			for _, child in ipairs(part:GetDescendants()) do
				if child:IsA("TouchTransmitter") or child:IsA("Script") or child:IsA("LocalScript") then
					child:Destroy()
				end
			end
		end)
		RunNHide.DisabledParts[part] = "Killbrick"
	end

	local isBarrier = name:find("barrier") or name:find("bound") or name:find("border") or name:find("clip") or name:find("limit") or name:find("blocker") or name:find("invis")
	local isInvisWall = (part.Transparency >= 0.75 and part.CanCollide and not name:find("glass") and not name:find("window"))

	if RunNHide.DisableBarriers and (isBarrier or isInvisWall) and not isKill then
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		RunNHide.DisabledParts[part] = "Barrier"
	end
end

function RunNHide.scanAndDisableBoundaries(): number
	local count = 0
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("BasePart") then
			neutralizeSinglePart(obj)
			count += 1
		end
	end
	return count
end

local function updateVoidSafetyFloor()
	if RunNHide.AntiVoidFloor then
		if not RunNHide.VoidSafetyPlat or not RunNHide.VoidSafetyPlat.Parent then
			local plat = Instance.new("Part")
			plat.Name = "Fih_AntiVoidSafetyFloor"
			plat.Size = Vector3.new(4000, 10, 4000)
			plat.Position = Vector3.new(0, -60, 0)
			plat.Anchored = true
			plat.CanCollide = true
			plat.Transparency = 0.7
			plat.Material = Enum.Material.ForceField
			plat.Color = Color3.fromRGB(0, 180, 255)
			plat.Parent = Workspace
			RunNHide.VoidSafetyPlat = plat
		end
	else
		if RunNHide.VoidSafetyPlat then
			pcall(function() RunNHide.VoidSafetyPlat:Destroy() end)
			RunNHide.VoidSafetyPlat = nil
		end
	end
end

function RunNHide.getPlayerRoleCategory(p: Player): (string, Color3)
	local role = p:GetAttribute("Role")
	local roleStr = tostring(role or ""):lower()
	if roleStr:find("murder") or roleStr:find("shoot") or roleStr:find("killer") then
		return "Threat", Color3.fromRGB(255, 45, 45)
	elseif roleStr:find("sheriff") or roleStr:find("armed") or roleStr:find("hero") then
		return "Sheriff", Color3.fromRGB(45, 140, 255)
	end
	local char = p.Character
	if char then
		for _, item in ipairs(char:GetChildren()) do
			if item:IsA("Tool") and (item.Name:find("AK") or item.Name:find("AR") or item.Name:find("CZ") or item.Name:find("BLOCK") or item.Name:find("M249") or item.Name:find("UZI") or item.Name:find("Knife") or item.Name:find("Gun")) then
				return "Armed", Color3.fromRGB(255, 100, 50)
			end
		end
	end
	return "Bystander", Color3.fromRGB(60, 220, 90)
end

-- ── Weapon Grabber ────────────────────────────────────────────────
function RunNHide.grabAllScatteredWeapons(): number
	local count = 0
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			local pName = (d.Parent and d.Parent.Name or ""):lower()
			local gName = (d.Parent and d.Parent.Parent and d.Parent.Parent.Name or ""):lower()
			if pName:find("spawn") or pName:find("weapon") or pName:find("pickup") or gName:find("scattered") or gName:find("weapon") then
				d.MaxActivationDistance = 99999
				d.HoldDuration = 0
				d.RequiresLineOfSight = false
				local fireprompt = (getgenv and getgenv().fireproximityprompt) or fireproximityprompt
				if type(fireprompt) == "function" then
					fireprompt(d)
					count += 1
				else
					local char = LocalPlayer.Character
					local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")) :: BasePart?
					local part = if d.Parent:IsA("BasePart") then d.Parent else d.Parent:FindFirstChildWhichIsA("BasePart")
					if root and part then
						local origCF = root.CFrame
						root.CFrame = part.CFrame * CFrame.new(0, 1, 0)
						task.wait(0.04)
						d:InputHoldBegin()
						task.wait(0.02)
						d:InputHoldEnd()
						task.wait(0.04)
						root.CFrame = origCF
						count += 1
					end
				end
			end
		end
	end
	return count
end

-- ── Initialize Core Module Loop ───────────────────────────────────
function RunNHide.init(notifyCallback: ((string, string) -> ())?)
	if RunNHide.IsActive then return end
	RunNHide.IsActive = true

	resolveDemiseModules()

	-- Stamina Heartbeat Watcher
	local stamConn = RunService.Heartbeat:Connect(function()
		if RunNHide.InfiniteStamina or RunNHide.StaminaReduction > 0 or RunNHide.SpeedBoost then
			local char = LocalPlayer.Character
			if char then
				if RunNHide.InfiniteStamina and char:GetAttribute("StamDrainMult") ~= 0 then
					char:SetAttribute("StamDrainMult", 0)
					char:SetAttribute("StamMult", 10)
				end
				if RunNHide.SpeedBoost and char:GetAttribute("SpeedMult") ~= RunNHide.SpeedMultiplier then
					char:SetAttribute("SpeedMult", RunNHide.SpeedMultiplier)
				end
			end
		end
	end)
	table.insert(connections, stamConn)

	-- Ragdoll Movement & Auto Standup
	local ragdollConn = RunService.Heartbeat:Connect(function()
		local char = LocalPlayer.Character
		if not char then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		local root = (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")) :: BasePart?
		if not (hum and root and hum.Health > 0) then return end

		local isRagdolled = char:GetAttribute("Ragdoll") == true or hum.PlatformStand == true or hum:GetState() == Enum.HumanoidStateType.Ragdoll or hum:GetState() == Enum.HumanoidStateType.Physics

		if isRagdolled and RunNHide.MoveInRagdoll then
			local cam = Workspace.CurrentCamera
			if cam then
				local moveVec = Vector3.zero
				if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec += cam.CFrame.LookVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec -= cam.CFrame.LookVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec -= cam.CFrame.RightVector end
				if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec += cam.CFrame.RightVector end

				local flatMove = Vector3.new(moveVec.X, 0, moveVec.Z)
				if flatMove.Magnitude > 0.05 then
					flatMove = flatMove.Unit
					local speed = RunNHide.RagdollSpeed or 32
					root.AssemblyLinearVelocity = Vector3.new(flatMove.X * speed, root.AssemblyLinearVelocity.Y, flatMove.Z * speed)
				end

				if RunNHide.RagdollJumpBoost and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
					if math.abs(root.AssemblyLinearVelocity.Y) < 6 then
						root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 38, root.AssemblyLinearVelocity.Z)
					end
				end
			end
		end

		if isRagdolled and RunNHide.AutoStandup then
			pcall(function()
				hum.PlatformStand = false
				hum.AutoRotate = true
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
				if Packets and Packets.RagdollToggle then
					Packets.RagdollToggle:Fire({ Mode = false })
				end
			end)
		end
	end)
	table.insert(connections, ragdollConn)

	-- Boundary Watcher
	local boundWatch = Workspace.DescendantAdded:Connect(function(child)
		if RunNHide.DisableBarriers or RunNHide.DisableKillbricks then
			task.wait(0.05)
			neutralizeSinglePart(child)
		end
	end)
	table.insert(connections, boundWatch)

	local boundHeartbeat = RunService.Heartbeat:Connect(function()
		if RunNHide.DisableBarriers or RunNHide.DisableKillbricks then
			for part, _ in pairs(RunNHide.DisabledParts) do
				if part and part.Parent then
					if part.CanCollide then part.CanCollide = false end
					if part.CanTouch then part.CanTouch = false end
				end
			end
		end
	end)
	table.insert(connections, boundHeartbeat)

	-- Role Watchdog Loop
	local roleConn = RunService.Heartbeat:Connect(function()
		if RunNHide.RoleTracker then
			for _, p in ipairs(Players:GetPlayers()) do
				if p ~= LocalPlayer then
					local roleCat = RunNHide.getPlayerRoleCategory(p)
					RunNHide.LastKnownRoles[p] = roleCat
				end
			end
		end
	end)
	table.insert(connections, roleConn)

	-- Auto-Grab Periodic Watcher
	local grabConn = RunService.Heartbeat:Connect(function()
		if RunNHide.AutoGrabWeapons then
			RunNHide.grabAllScatteredWeapons()
		end
	end)
	table.insert(connections, grabConn)

	-- Input Listeners
	local inBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local tool, config = getEquippedGun()
			if not tool or not config then return end

			if RunNHide.BurstMode then
				triggerBurst(tool, config)
			elseif RunNHide.CompleteAuto and config.FireMode ~= "Minigun" then
				RunNHide.IsShooting = true
				task.spawn(function()
					while RunNHide.IsShooting do
						local curTool, curConfig = getEquippedGun()
						if not curTool or curTool ~= tool then break end
						local fired = fireSingleRound(curTool, curConfig)
						if not fired then break end
						local waitTime = if RunNHide.FastFireRate then RunNHide.CustomFireRate else (curConfig.FireRate or 0.1)
						task.wait(math.max(0.03, waitTime))
					end
				end)
			end
		elseif input.KeyCode == Enum.KeyCode.R then
			if RunNHide.QuickReload then
				local tool = getEquippedGun()
				if tool then executeQuickReload(tool) end
			end
		end
	end)
	table.insert(connections, inBegan)

	local inEnded = UserInputService.InputEnded:Connect(function(input, _)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			RunNHide.IsShooting = false
		end
	end)
	table.insert(connections, inEnded)

	-- Tool Trackers for chambering & quick reload
	local function trackTool(tool: Instance)
		if not tool:IsA("Tool") or not Guns or not Guns[tool.Name] then return end

		local chConn = tool:GetAttributeChangedSignal("Chambered"):Connect(function()
			if (RunNHide.AutoChamber or RunNHide.QuickReload) and tool.Parent == LocalPlayer.Character and not tool:GetAttribute("Chambered") then
				task.wait(0.04)
				executeAutoChamber(tool)
			end
		end)
		table.insert(connections, chConn)

		local amConn = tool:GetAttributeChangedSignal("CurrentAmmo"):Connect(function()
			local ammo = tool:GetAttribute("CurrentAmmo")
			if typeof(ammo) == "number" and ammo <= 0 and RunNHide.QuickReload and tool.Parent == LocalPlayer.Character then
				task.wait(0.04)
				executeQuickReload(tool)
			end
		end)
		table.insert(connections, amConn)
	end

	local function scanTools()
		if LocalPlayer.Character then
			for _, item in ipairs(LocalPlayer.Character:GetChildren()) do trackTool(item) end
			LocalPlayer.Character.ChildAdded:Connect(trackTool)
			applyStaminaState()
		end
		local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
		if backpack then
			for _, item in ipairs(backpack:GetChildren()) do trackTool(item) end
			backpack.ChildAdded:Connect(trackTool)
		end
	end

	scanTools()
	local charConn = LocalPlayer.CharacterAdded:Connect(function()
		task.wait(0.3)
		scanTools()
	end)
	table.insert(connections, charConn)

	updateWeaponConfigs(true)
	applyStaminaState()
end

function RunNHide.updateWeapons(skipRefresh: boolean?)
	updateWeaponConfigs(skipRefresh)
end

function RunNHide.updateStamina()
	applyStaminaState()
end

function RunNHide.updateVoidPlatform()
	updateVoidSafetyFloor()
end

function RunNHide.forceStandup()
	local char = LocalPlayer.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.PlatformStand = false
			hum.AutoRotate = true
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
		if Packets and Packets.RagdollToggle then
			Packets.RagdollToggle:Fire({ Mode = false })
		end
	end
end

function RunNHide.teleportToArena(): boolean
	local char = LocalPlayer.Character
	local root = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")) :: BasePart?
	if root then
		root.CFrame = CFrame.new(2093.5, 2743, 494.7)
		return true
	end
	return false
end

function RunNHide.forceReload(): boolean
	local tool = getEquippedGun()
	if tool then
		executeQuickReload(tool)
		return true
	end
	return false
end

function RunNHide.forceChamber(): boolean
	local tool = getEquippedGun()
	if tool then
		executeAutoChamber(tool)
		return true
	end
	return false
end

function RunNHide.cleanup()
	RunNHide.IsActive = false
	for _, conn in ipairs(connections) do
		pcall(function() conn:Disconnect() end)
	end
	table.clear(connections)

	if RunNHide.VoidSafetyPlat then
		pcall(function() RunNHide.VoidSafetyPlat:Destroy() end)
		RunNHide.VoidSafetyPlat = nil
	end

	-- Restore original gun configs
	if Guns and originalConfigs then
		for gunName, original in pairs(originalConfigs) do
			if Guns[gunName] then
				for k, v in pairs(original) do
					Guns[gunName][k] = v
				end
			end
		end
	end

	-- Restore stamina
	if Config and Config.Stamina and originalStamina then
		Config.Stamina.DrainRate = originalStamina.DrainRate
		Config.Stamina.RegenRate = originalStamina.RegenRate
		Config.Stamina.RegenDelay = originalStamina.RegenDelay
	end
end

return RunNHide
