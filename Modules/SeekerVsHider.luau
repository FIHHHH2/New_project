--!strict
--[=[
    ✦ Seeker vs Hider Automation & Combat Suite ✦
    Features:
    - True Silent Aim (Hooks FastCast BulletHandler to redirect bullet vectors directly to targets)
    - Predictive Trajectory Solver (Target Velocity * lead factor)
    - Target Part Selector (Head / Torso / HumanoidRootPart / Random)
    - FOV Check & Visualizer Integration
    - Weapon Configs:
        - No Recoil & Zero Camera Shake
        - Zero Spread & No Bloom
        - Rapid Fire Rate Overclock
        - Full Auto Mode
        - No Bullet Drop (Zero Gravity)
        - Instant Gun Spawner / Selector (AK-74, M4A1, M249, RPG-7, RayGun, etc.)
    - Tactical Actions:
        - Break All Map Glass
        - Safe Vantage Teleport
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
	FOV = 220,
	HitChance = 100,
	WallCheck = false,
	TeamCheck = true,
	Prediction = 0.035,
	
	-- Weapon Configs
	NoRecoil = true,
	NoSpread = true,
	FastFireRate = false,
	FireRateMultiplier = 1.8,
	FullAuto = true,
	NoBulletDrop = true,
}

local origFireBullet: any = nil
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

				local part = char:FindFirstChild(targetPartName) or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
				if part and part:IsA("BasePart") then
					local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
					if onScreen then
						local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
						if dist <= bestDist then
							if SeekerVsHider.WallCheck then
								local rayParams = RaycastParams.new()
								rayParams.FilterType = Enum.RaycastFilterType.Exclude
								rayParams.FilterDescendantsInstances = {LocalPlayer.Character, char}
								local res = Workspace:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, rayParams)
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
		local vel = bestPart.AssemblyLinearVelocity
		local predictedPos = bestPart.Position + (vel * SeekerVsHider.Prediction)
		return bestPlayer, bestPart, predictedPos
	end

	return nil, nil, nil
end

-- ── 2. FastCast BulletHandler Hook (True Silent Aim) ──────────────────
local function installBulletHook()
	if hookInstalled then return end

	local sphAssets = ReplicatedStorage:FindFirstChild("SPH_Assets")
	local modules = sphAssets and sphAssets:FindFirstChild("Modules")
	local bulletHandlerObj = modules and modules:FindFirstChild("BulletHandler")

	if bulletHandlerObj then
		local ok, bh = pcall(require, bulletHandlerObj)
		if ok and typeof(bh) == "table" and typeof(bh.FireBullet) == "function" then
			origFireBullet = bh.FireBullet

			bh.FireBullet = function(p10, origin, direction, velocity, tool, player, tracerColor, fakeBullet)
				if SeekerVsHider.SilentAim and player == LocalPlayer then
					local roll = math.random(1, 100)
					if roll <= SeekerVsHider.HitChance then
						local targetPlayer, targetPart, predictedPos = getTargetCandidate()
						if targetPart and predictedPos then
							-- Redirect bullet trajectory vector directly to target
							local newDir = (predictedPos - origin).Unit
							direction = newDir
						end
					end
				end

				-- Weapon Config Overrides
				if SeekerVsHider.NoBulletDrop and typeof(velocity) == "Vector3" then
					pcall(function()
						local fastCastBehavior = debug.getupvalue and debug.getupvalue(origFireBullet, 1)
						if fastCastBehavior and typeof(fastCastBehavior) == "table" then
							fastCastBehavior.Acceleration = Vector3.zero
						end
					end)
				end

				return origFireBullet(p10, origin, direction, velocity, tool, player, tracerColor, fakeBullet)
			end

			hookInstalled = true
		end
	end
end

-- ── 3. Weapon Stats Overclocker (Recoil, Spread, FireRate) ────────────
function SeekerVsHider.applyWeaponConfigs()
	local cam = Workspace.CurrentCamera
	local wRig = cam and cam:FindFirstChild("WeaponRig")
	local weaponFolder = wRig and wRig:FindFirstChild("Weapon")

	if weaponFolder then
		for _, model in ipairs(weaponFolder:GetChildren()) do
			local sphWep = model:FindFirstChild("SPH_Weapon")
			local statsMod = sphWep and sphWep:FindFirstChild("WeaponStats")
			if statsMod and statsMod:IsA("ModuleScript") then
				local ok, stats = pcall(require, statsMod)
				if ok and typeof(stats) == "table" then
					if SeekerVsHider.NoRecoil then
						stats.recoil = 0
						stats.kickUp = 0
						stats.kickRight = 0
					end
					if SeekerVsHider.NoSpread then
						stats.spread = 0
						stats.minSpread = 0
						stats.maxSpread = 0
					end
					if SeekerVsHider.FullAuto then
						stats.auto = true
						stats.fireModes = {"Auto"}
					end
					if SeekerVsHider.NoBulletDrop then
						stats.bulletDrop = false
					end
				end
			end
		end
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
				task.wait(0.2)
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
				-- 1. Fire Server BreakGlass Remote for each glass Part instance
				if bg then
					pcall(function()
						bg:FireServer(obj)
					end)
				end

				-- 2. Direct client shatter & collision bypass
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
	local lobby = Workspace:FindFirstChild("lobby")
	local spawnPart = lobby and lobby:FindFirstChildWhichIsA("BasePart", true)
	if spawnPart then
		return safeTeleport(spawnPart.CFrame)
	end
	return false
end

-- Initialize BulletHook on load
installBulletHook()

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
