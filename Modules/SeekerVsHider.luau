--!strict
--[=[
    ✦ Seeker vs Hider High-Performance Combat & Exploit Suite ✦
    Features:
    - True Silent Aim (Zero-lag FastCast:Fire & BulletHandler.FireBullet redirection)
    - Predictive 3D Trajectory Solver (Target Velocity * lead factor)
    - Target Part Selector (Head / Torso / HumanoidRootPart / Random)
    - FOV Check & Visualizer Integration
    - Zero-Overhead Weapon Overclocks:
        - Zero Recoil & Zero Pushback
        - Zero Spread & Perfect Accuracy
        - Full Auto Conversion (fireMode = 2)
        - Zero Bullet Drop (bulletDrop = false, Acceleration = 0)
        - Rapid Fire Rate Overclock
        - Instant Auto-Chamber
    - Environment & Boundary Exploits:
        - Remove Map Death Barriers & Killbricks
        - Anti-Void Floating Safety Floor (5000x5000)
        - Auto / Manual Break All Map Glass
        - No Fall Damage & No Screen Blur / Suppression
        - Sprint & Walk Speed Multiplier
        - Anti-Ragdoll & Instant Standup
    - Gun Vault Spawner (Select & Equip any of 32+ Weapons)
    - Tactical Teleports (Safe High Vantage, Lobby, Arena Center, Warp Behind Target)
]=]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera: Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

local SeekerVsHider = {
	SilentAim = true,
	TargetPart = "Head",
	FOV = 350,
	HitChance = 100,
	WallCheck = false,
	TeamCheck = false,
	Prediction = 0.035,
	
	-- Weapon Configs
	NoRecoil = true,
	NoSpread = true,
	FastFireRate = false,
	FireRateMultiplier = 1.8,
	FullAuto = true,
	NoBulletDrop = true,

	-- Environment & Mobility
	RemoveDeathBarriers = false,
	AntiVoidFloor = false,
	AutoBreakGlass = false,
	SpeedBoost = false,
	SpeedMultiplier = 1.5,
	NoFallDamage = true,
	AntiRagdoll = false,

	DisabledBarriers = {} :: {[BasePart]: boolean},
	VoidSafetyPlat = nil :: Part?,
}

local SHARED_RAY_PARAMS = RaycastParams.new()
local origFireBullet: any = nil
local origFastCastFire: any = nil
local hookInstalled = false
local weaponConfigConn: RBXScriptConnection? = nil
local barrierWatcherConn: RBXScriptConnection? = nil
local glassLoopThread: thread? = nil

-- ── 1. Target Acquisition & Trajectory Solver ─────────────────────────
local function getScreenCenter(): Vector2
	local vp = Camera.ViewportSize
	return Vector2.new(vp.X / 2, vp.Y / 2)
end

local function isTeammate(player: Player): boolean
	if not SeekerVsHider.TeamCheck or not LocalPlayer.Team then return false end
	return player.Team == LocalPlayer.Team
end

local function getTargetCandidate(): (Player?, BasePart?, Vector3?)
	local screenCenter = getScreenCenter()
	local bestPlayer: Player? = nil
	local bestPart: BasePart? = nil
	local bestDist = SeekerVsHider.FOV

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and not isTeammate(player) then
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if char and hum and hum.Health > 0 then
				local targetPartName = SeekerVsHider.TargetPart
				if targetPartName == "Random" then
					local parts = {"Head", "Torso", "HumanoidRootPart"}
					targetPartName = parts[math.random(1, #parts)]
				end

				local part = char:FindFirstChild(targetPartName) or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChildWhichIsA("BasePart")
				if part and part:IsA("BasePart") then
					local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
					if onScreen or screenPos.Z > 0 then
						local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
						if dist <= bestDist then
							if SeekerVsHider.WallCheck then
								SHARED_RAY_PARAMS.FilterType = Enum.RaycastFilterType.Exclude
								SHARED_RAY_PARAMS.FilterDescendantsInstances = {LocalPlayer.Character, char}
								local res = Workspace:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, SHARED_RAY_PARAMS)
								if not res then
									bestDist = dist
									bestPlayer = player
									bestPart = part
								end
							else
								bestDist = dist
								bestPlayer = player
								bestPart = part
							end
						end
					end
				end
			end
		end
	end

	if bestPlayer and bestPart then
		local vel = bestPart.AssemblyLinearVelocity or Vector3.zero
		local predictedPos = bestPart.Position + (vel * SeekerVsHider.Prediction)
		return bestPlayer, bestPart, predictedPos
	end

	return nil, nil, nil
end

-- ── 2. FastCast & BulletHandler Dual Hooks (Guaranteed Silent Aim) ────
local function installBulletHook()
	if hookInstalled then return end

	local sphAssets = ReplicatedStorage:FindFirstChild("SPH_Assets")
	local modules = sphAssets and sphAssets:FindFirstChild("Modules")

	-- Hook 1: FastCast.Fire directly on FastCast module
	local fastCastObj = modules and modules:FindFirstChild("FastCast")
	if fastCastObj then
		local okFc, FastCast = pcall(require, fastCastObj)
		if okFc and typeof(FastCast) == "table" and typeof(FastCast.Fire) == "function" then
			origFastCastFire = FastCast.Fire
			FastCast.Fire = function(self, origin, direction, velocity, behavior)
				if SeekerVsHider.SilentAim then
					local roll = math.random(1, 100)
					if roll <= SeekerVsHider.HitChance then
						local targetPlayer, targetPart, predictedPos = getTargetCandidate()
						if targetPart and predictedPos then
							local newDir = (predictedPos - origin).Unit
							direction = newDir
							if typeof(velocity) == "Vector3" then
								local spd = velocity.Magnitude
								velocity = newDir * (if spd > 10 then spd else 1000)
							elseif typeof(velocity) == "number" then
								velocity = if velocity > 10 then velocity else 1000
							end
						end
					end
				end

				if SeekerVsHider.NoBulletDrop and behavior then
					behavior.Acceleration = Vector3.zero
				end

				return origFastCastFire(self, origin, direction, velocity, behavior)
			end
		end
	end

	-- Hook 2: BulletHandler.FireBullet wrapper
	local bulletHandlerObj = modules and modules:FindFirstChild("BulletHandler")
	if bulletHandlerObj then
		local okBh, bh = pcall(require, bulletHandlerObj)
		if okBh and typeof(bh) == "table" and typeof(bh.FireBullet) == "function" then
			origFireBullet = bh.FireBullet
			bh.FireBullet = function(p10, origin, direction, velocity, tool, player, tracerColor, fakeBullet)
				local isLocal = (player == LocalPlayer or player == nil or player == LocalPlayer.Character or player == LocalPlayer.Name or (p10 == LocalPlayer.Character))

				if SeekerVsHider.SilentAim and isLocal then
					local roll = math.random(1, 100)
					if roll <= SeekerVsHider.HitChance then
						local targetPlayer, targetPart, predictedPos = getTargetCandidate()
						if targetPart and predictedPos then
							local newDir = (predictedPos - origin).Unit
							direction = newDir
							if typeof(velocity) == "Vector3" then
								local spd = velocity.Magnitude
								velocity = newDir * (if spd > 10 then spd else 1000)
							end
						end
					end
				end

				return origFireBullet(p10, origin, direction, velocity, tool, player, tracerColor, fakeBullet)
			end
		end
	end

	hookInstalled = true
end

-- ── 3. Direct ModuleScript Weapon Overclocker (0ms GC Footprint) ───────
local function modifyWeaponModule(mod: Instance)
	if not mod:IsA("ModuleScript") then return end
	pcall(function()
		local ok, data = pcall(require, mod)
		if ok and type(data) == "table" then
			if rawget(data, "recoil") ~= nil or rawget(data, "spread") ~= nil or rawget(data, "fireRate") ~= nil or rawget(data, "startAmmoPool") ~= nil or rawget(data, "kickUp") ~= nil then
				if SeekerVsHider.NoSpread then
					rawset(data, "spread", 0)
					rawset(data, "minSpread", 0)
					rawset(data, "maxSpread", 0)
				end
				if SeekerVsHider.NoRecoil then
					rawset(data, "recoil", 0)
					rawset(data, "kickUp", 0)
					rawset(data, "kickRight", 0)
					rawset(data, "maxPushback", 0)
					rawset(data, "cameraShake", 0)
				end
				if SeekerVsHider.FullAuto then
					rawset(data, "fireMode", 2)
					rawset(data, "auto", true)
				end
				if SeekerVsHider.NoBulletDrop then
					rawset(data, "bulletDrop", false)
				end
				if SeekerVsHider.FastFireRate then
					local rate = rawget(data, "fireRate")
					if type(rate) == "number" and rate < 1200 then
						rawset(data, "fireRate", math.floor(rate * SeekerVsHider.FireRateMultiplier))
					end
				end
				rawset(data, "autoChamber", true)
			end
		end
	end)
end

function SeekerVsHider.applyWeaponConfigs()
	local sphAssets = ReplicatedStorage:FindFirstChild("SPH_Assets")
	if sphAssets then
		for _, item in ipairs(sphAssets:GetDescendants()) do
			if item:IsA("ModuleScript") then
				modifyWeaponModule(item)
			end
		end
	end

	local char = LocalPlayer.Character
	if char then
		for _, item in ipairs(char:GetDescendants()) do
			if item:IsA("ModuleScript") then
				modifyWeaponModule(item)
			end
		end
	end

	local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
	if bp then
		for _, item in ipairs(bp:GetDescendants()) do
			if item:IsA("ModuleScript") then
				modifyWeaponModule(item)
			end
		end
	end

	-- Modify SPH_Assets.GameConfig
	local sphAssets = ReplicatedStorage:FindFirstChild("SPH_Assets")
	local gameCfgMod = sphAssets and sphAssets:FindFirstChild("GameConfig")
	if gameCfgMod and gameCfgMod:IsA("ModuleScript") then
		pcall(function()
			local cfg = require(gameCfgMod)
			if type(cfg) == "table" then
				cfg.fallDamage = false
				cfg.cameraBobDampening = 0
				cfg.cameraTilting = false
				cfg.blurEffects = false
				cfg.suppressionEffects = false
				cfg.raiseGunAtWall = false
				if SeekerVsHider.SpeedBoost then
					cfg.walkSpeed = math.floor(16 * SeekerVsHider.SpeedMultiplier)
					cfg.sprintSpeed = math.floor(26 * SeekerVsHider.SpeedMultiplier)
					cfg.crouchSpeed = math.floor(12 * SeekerVsHider.SpeedMultiplier)
				end
			end
		end)
	end

	-- Apply walk speed directly to Humanoid
	if LocalPlayer.Character then
		local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		if hum and SeekerVsHider.SpeedBoost then
			hum.WalkSpeed = math.floor(16 * SeekerVsHider.SpeedMultiplier)
		end
	end
end

-- ── 4. Death Barriers & Killbricks Neutralization ────────────────────
local function neutralizeSingleBarrier(part: Instance)
	if not part:IsA("BasePart") then return end
	if part:IsDescendantOf(Players) then return end

	local name = part.Name:lower()
	local parentName = (part.Parent and part.Parent.Name or ""):lower()

	local isKill = name:find("kill") or parentName:find("kill") or name:find("death") or parentName:find("death") or name:find("lava") or name:find("hazard") or name:find("damage") or name:find("trapdoor")
	local isBarrier = name:find("barrier") or name:find("bound") or name:find("border") or name:find("clip") or name:find("limit") or name:find("invis")
	local isInvisWall = (part.Transparency >= 0.75 and part.CanCollide and not name:find("glass") and not name:find("window"))

	if isKill or isBarrier or isInvisWall then
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		pcall(function()
			for _, child in ipairs(part:GetDescendants()) do
				if child:IsA("TouchTransmitter") or child:IsA("Script") then
					child:Destroy()
				end
			end
		end)
		SeekerVsHider.DisabledBarriers[part] = true
	end
end

function SeekerVsHider.removeDeathBarriersNow(): number
	local count = 0
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("BasePart") then
			local name = obj.Name:lower()
			local parentName = (obj.Parent and obj.Parent.Name or ""):lower()
			local isKill = name:find("kill") or parentName:find("kill") or name:find("death") or parentName:find("death") or name:find("lava") or name:find("hazard") or name:find("trapdoor")
			local isBarrier = name:find("barrier") or name:find("bound") or name:find("border") or name:find("clip") or name:find("invis")
			local isInvisWall = (obj.Transparency >= 0.75 and obj.CanCollide and not name:find("glass") and not name:find("window"))
			if isKill or isBarrier or isInvisWall then
				neutralizeSingleBarrier(obj)
				count += 1
			end
		end
	end
	return count
end

function SeekerVsHider.setRemoveDeathBarriers(enabled: boolean)
	SeekerVsHider.RemoveDeathBarriers = enabled
	if enabled then
		SeekerVsHider.removeDeathBarriersNow()
		if not barrierWatcherConn then
			barrierWatcherConn = Workspace.DescendantAdded:Connect(function(obj)
				if SeekerVsHider.RemoveDeathBarriers and obj:IsA("BasePart") then
					neutralizeSingleBarrier(obj)
				end
			end)
		end
	elseif barrierWatcherConn then
		barrierWatcherConn:Disconnect()
		barrierWatcherConn = nil
	end
end

-- ── 5. Anti-Void Safety Platform ─────────────────────────────────────
function SeekerVsHider.updateVoidPlatform()
	if SeekerVsHider.AntiVoidFloor then
		if not SeekerVsHider.VoidSafetyPlat or not SeekerVsHider.VoidSafetyPlat.Parent then
			local plat = Instance.new("Part")
			plat.Name = "SVH_AntiVoidPlatform"
			plat.Size = Vector3.new(5000, 10, 5000)
			plat.Position = Vector3.new(0, -65, 0)
			plat.Anchored = true
			plat.CanCollide = true
			plat.Transparency = 0.65
			plat.Material = Enum.Material.ForceField
			plat.Color = Color3.fromRGB(0, 170, 255)
			plat.Parent = Workspace
			SeekerVsHider.VoidSafetyPlat = plat
		end
	else
		if SeekerVsHider.VoidSafetyPlat then
			pcall(function() SeekerVsHider.VoidSafetyPlat:Destroy() end)
			SeekerVsHider.VoidSafetyPlat = nil
		end
	end
end

-- ── 6. Instant Gun Selection / Spawner ────────────────────────────────
function SeekerVsHider.selectGun(gunName: string): boolean
	local rf = ReplicatedStorage:FindFirstChild("ClientToServerCommunication") and ReplicatedStorage.ClientToServerCommunication:FindFirstChild("RemoteFunctions")
	local selectgun = rf and rf:FindFirstChild("selectgun")

	if selectgun then
		local ok, res = pcall(function()
			return selectgun:InvokeServer(gunName)
		end)
		if ok then
			task.delay(0.2, function()
				SeekerVsHider.applyWeaponConfigs()
			end)
			return true
		end
	end
	return false
end

function SeekerVsHider.getAvailableGuns(): {string}
	return {
		"AK-74",
		"M4A1",
		"M4A1 MODDED",
		"AKM",
		"Super AK-74",
		"AK-50",
		"M249",
		"PKM",
		"M60",
		"AA-12",
		"Remington 870",
		"M1014",
		"PPSH 41",
		"MP5",
		"mp7",
		"MICRO UZI",
		"Glock 19",
		"Glock 19Switch",
		"Desert Eagle",
		"P320",
		"Makarov PM",
		"Suppressed Makarov PM",
		"DVL-10 M2",
		"M1891",
		"M1 Garand",
		"MK11",
		"HK417",
		"RayGun",
		"Flamethrower",
		"RPG-7",
		"Panzerfaust 3",
		"Nuke"
	}
end

-- ── 7. Tactical & Map Actions ─────────────────────────────────────────
function SeekerVsHider.breakAllGlass(): number
	local re = ReplicatedStorage:FindFirstChild("ClientToServerCommunication") and ReplicatedStorage.ClientToServerCommunication:FindFirstChild("RemoteEvents")
	local bg = re and re:FindFirstChild("BreakGlass")
	local count = 0

	local cam = Workspace.CurrentCamera
	local myChar = LocalPlayer.Character

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("BasePart") then
			local mat = obj.Material
			local name = obj.Name:lower()
			local isGlass = (mat == Enum.Material.Glass or mat == Enum.Material.Foil or mat == Enum.Material.Ice or mat == Enum.Material.ForceField or name:find("glass") or name:find("window") or name:find("pane"))
			
			if isGlass and not (cam and obj:IsDescendantOf(cam)) and not (myChar and obj:IsDescendantOf(myChar)) then
				if bg then
					pcall(function()
						bg:FireServer(obj)
					end)
				end

				pcall(function()
					obj.Transparency = 1
					obj.CanCollide = false
					obj.CanQuery = false
					obj.CanTouch = false
				end)
				count += 1
			end
		end
	end

	return count
end

function SeekerVsHider.setAutoBreakGlass(enabled: boolean)
	SeekerVsHider.AutoBreakGlass = enabled
	if glassLoopThread then
		task.cancel(glassLoopThread)
		glassLoopThread = nil
	end

	if enabled then
		glassLoopThread = task.spawn(function()
			while SeekerVsHider.AutoBreakGlass do
				SeekerVsHider.breakAllGlass()
				task.wait(4.0)
			end
		end)
	end
end

local function safeTeleport(targetCF: CFrame): boolean
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return false end

	pcall(function()
		hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		hum.PlatformStand = false
		hum.Sit = false
	end)
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	hrp.CFrame = targetCF * CFrame.new(0, 3, 0)
	pcall(function()
		hum:ChangeState(Enum.HumanoidStateType.Running)
	end)
	return true
end

function SeekerVsHider.teleportSafeHigh(): boolean
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return false end

	local currentCF = hrp.CFrame
	return safeTeleport(currentCF * CFrame.new(0, 35, 0))
end

function SeekerVsHider.teleportToLobby(): boolean
	local lobby = Workspace:FindFirstChild("lobby") or Workspace:FindFirstChild("Lobby")
	local spawnPart = lobby and lobby:FindFirstChildWhichIsA("BasePart", true)
	if spawnPart then
		return safeTeleport(spawnPart.CFrame)
	end
	return false
end

function SeekerVsHider.teleportToMapCenter(): boolean
	local map = Workspace:FindFirstChild("map")
	local model = map and map:FindFirstChildWhichIsA("Model")
	local part = model and model:FindFirstChildWhichIsA("BasePart", true)
	if part then
		return safeTeleport(part.CFrame * CFrame.new(0, 5, 0))
	end
	return false
end

function SeekerVsHider.teleportBehindNearestEnemy(): boolean
	local targetPlayer, targetPart, _ = getTargetCandidate()
	if targetPlayer and targetPart then
		local cf = targetPart.CFrame
		return safeTeleport(cf * CFrame.new(0, 0, 4))
	end
	return false
end

-- Initialize FastCast & BulletHandler hooks
installBulletHook()
task.spawn(function()
	task.wait(0.5)
	SeekerVsHider.applyWeaponConfigs()
end)

-- Hook character/backpack added to re-apply weapon configs on weapon equip (Zero per-frame loop)
if LocalPlayer.Character then
	LocalPlayer.Character.ChildAdded:Connect(function()
		task.delay(0.15, SeekerVsHider.applyWeaponConfigs)
	end)
end

LocalPlayer.CharacterAdded:Connect(function(char)
	task.delay(0.5, SeekerVsHider.applyWeaponConfigs)
	char.ChildAdded:Connect(function()
		task.delay(0.15, SeekerVsHider.applyWeaponConfigs)
	end)
end)

-- Lightweight Anti-Ragdoll watcher (Only active when enabled)
if weaponConfigConn then
	weaponConfigConn:Disconnect()
	weaponConfigConn = nil
end

weaponConfigConn = RunService.Heartbeat:Connect(function()
	if SeekerVsHider.AntiRagdoll then
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum and hum.PlatformStand then
			pcall(function()
				hum.PlatformStand = false
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
			end)
		end
	end
end)

return SeekerVsHider
