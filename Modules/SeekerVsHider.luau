--!strict
--[=[
    ✦ Seeker vs Hider Automation & Combat Suite ✦
    Features:
    - True Silent Aim (Hooks FastCast:Fire & BulletHandler.FireBullet directly)
    - Predictive 3D Trajectory Solver (Target Velocity * lead factor)
    - Target Part Selector (Head / Torso / HumanoidRootPart / Random)
    - FOV Radius & Team Check
    - Real-Time Weapon Overclocking (via getgc tables):
        - Zero Recoil & No Pushback
        - Zero Spread & No Bloom
        - Full Auto Conversion (fireMode = 2)
        - Zero Bullet Drop (bulletDrop = false, Acceleration = 0)
        - Rapid Fire Rate Multiplier
        - Instant Auto-Chamber
        - Fall Damage & Wall-Raise Bypass
    - Gun Vault Spawner (Select & Equip any of 32+ Weapons)
    - Break All Map Glass
    - Safe Vantage Teleports
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
}

local SHARED_RAY_PARAMS = RaycastParams.new()
local origFireBullet: any = nil
local origFastCastFire: any = nil
local hookInstalled = false
local weaponConfigConn: RBXScriptConnection? = nil

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
					if onScreen then
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

-- ── 3. Weapon Stats Overclocker (Recoil, Spread, FireRate, Auto) ──────
function SeekerVsHider.applyWeaponConfigs()
	-- 1. Scan getgc for active weapon stats tables
	if type(getgc) == "function" then
		for _, obj in ipairs(getgc(true)) do
			if type(obj) == "table" then
				local hasRecoil = rawget(obj, "recoil") ~= nil
				local hasSpread = rawget(obj, "spread") ~= nil
				local hasFireRate = rawget(obj, "fireRate") ~= nil or rawget(obj, "rpm") ~= nil
				local hasAmmo = rawget(obj, "startAmmoPool") ~= nil or rawget(obj, "magazineCapacity") ~= nil

				if hasRecoil or hasSpread or hasFireRate or hasAmmo then
					if SeekerVsHider.NoSpread then
						rawset(obj, "spread", 0)
						rawset(obj, "minSpread", 0)
						rawset(obj, "maxSpread", 0)
					end
					if SeekerVsHider.NoRecoil then
						rawset(obj, "recoil", 0)
						rawset(obj, "kickUp", 0)
						rawset(obj, "kickRight", 0)
						rawset(obj, "maxPushback", 0)
					end
					if SeekerVsHider.FullAuto then
						rawset(obj, "fireMode", 2)
						rawset(obj, "auto", true)
					end
					if SeekerVsHider.NoBulletDrop then
						rawset(obj, "bulletDrop", false)
					end
					if SeekerVsHider.FastFireRate then
						local rate = rawget(obj, "fireRate")
						if type(rate) == "number" and rate < 1200 then
							rawset(obj, "fireRate", math.floor(rate * SeekerVsHider.FireRateMultiplier))
						end
					end
					rawset(obj, "autoChamber", true)
				end
			end
		end
	end

	-- 2. Modify SPH_Assets.GameConfig
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
			end
		end)
	end
end

-- ── 4. Instant Gun Selection / Spawner ────────────────────────────────
function SeekerVsHider.selectGun(gunName: string): boolean
	local rf = ReplicatedStorage:FindFirstChild("ClientToServerCommunication") and ReplicatedStorage.ClientToServerCommunication:FindFirstChild("RemoteFunctions")
	local selectgun = rf and rf:FindFirstChild("selectgun")

	if selectgun then
		local ok, res = pcall(function()
			return selectgun:InvokeServer(gunName)
		end)
		if ok then
			task.defer(function()
				task.wait(0.15)
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

-- ── 5. Tactical & Map Actions ─────────────────────────────────────────
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

-- Initialize FastCast & BulletHandler hooks
installBulletHook()
SeekerVsHider.applyWeaponConfigs()

-- Continuous WeaponConfig Watcher
if weaponConfigConn then
	weaponConfigConn:Disconnect()
	weaponConfigConn = nil
end

weaponConfigConn = RunService.Heartbeat:Connect(function()
	if SeekerVsHider.NoRecoil or SeekerVsHider.NoSpread or SeekerVsHider.FullAuto then
		SeekerVsHider.applyWeaponConfigs()
	end
end)

return SeekerVsHider
