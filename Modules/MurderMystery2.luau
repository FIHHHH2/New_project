--!strict
--[=[
    ✦ Murder Mystery 2 Advanced Combat, Role Intelligence & Utility Suite ✦
    Features:
    - Knife KillAura (3D Customizable Visual Kill Box with Multi-Target Execution)
    - Sheriff Silent Aim (Predictive Murderer Bullet Redirection & Raycast Metamethod Hook)
    - QuickShot (Zero-Delay Instant Draw & Fire Bypass)
    - Role Intelligence & ESP (Murderer / Sheriff / Hero / Innocent / Dropped Gun)
    - Dropped Gun Auto-Grab (Instant Touch / Proximity Warp)
    - Murderer Proximity Radar & Threat Alert
    - Automatic Coin Collector (Safe Tween & Touch Interest)
    - Auto Shoot Murderer on Knife Draw
    - Sheriff Auto-Disarm / Fake Disarm
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

local MurderMystery2 = {
	-- KillAura Configs
	KillAura = false,
	KillBoxVisible = true,
	KillBoxSize = 25,
	KillBoxColor = Color3.fromRGB(255, 35, 75),
	KillAuraDelay = 0.08,
	TargetInnocents = true,
	TargetSheriff = true,
	ExpandKnifeHitbox = true,

	-- Silent Aim (Sheriff)
	SilentAim = true,
	SilentAimFOV = 360,
	Prediction = 0.045,
	HitPart = "HumanoidRootPart", -- "Head" or "HumanoidRootPart"
	WallCheck = false,
	AutoShootMurderer = false,

	-- QuickShot (Sheriff)
	QuickShot = true,
	InstantEquip = true,
	CustomFireDelay = 0.0,

	-- Role ESP
	RoleESP = false,
	ShowDroppedGun = true,
	ShowDistance = true,
	ShowTracers = false,
	MurdererColor = Color3.fromRGB(255, 45, 65),
	SheriffColor = Color3.fromRGB(45, 120, 255),
	HeroColor = Color3.fromRGB(255, 215, 0),
	InnocentColor = Color3.fromRGB(50, 220, 110),
	DroppedGunColor = Color3.fromRGB(0, 255, 240),

	-- Utilities
	AutoGrabGun = false,
	AutoGrabDistance = 300,
	RadarAlert = true,
	RadarThreshold = 40,
	CoinFarm = false,
	CoinFarmSpeed = 26,

	-- Runtime State
	CurrentMurderer = nil :: Player?,
	CurrentSheriff = nil :: Player?,
	CurrentHero = nil :: Player?,
	DroppedGunInstance = nil :: Instance?,
	IsActive = false,
}

local connections: {RBXScriptConnection} = {}
local espInstances: {[Instance]: {Highlight: Highlight?, Billboard: BillboardGui?}} = {}
local killBoxPart: Part? = nil
local killBoxSelection: SelectionBox? = nil
local lastKillAuraTick = 0
local lastShootTick = 0
local isGrabbingGun = false
local originalNamecall: any = nil
local hookInstalled = false

-- ── 1. Role Detection Engine ──────────────────────────────────────────
local function getPlayerTool(player: Player, toolName: string): Tool?
	local char = player.Character
	if char then
		local tool = char:FindFirstChild(toolName)
		if tool and tool:IsA("Tool") then return tool end
	end
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		local tool = backpack:FindFirstChild(toolName)
		if tool and tool:IsA("Tool") then return tool end
	end
	return nil
end

function MurderMystery2.getPlayerRole(player: Player): string
	if player == MurderMystery2.CurrentHero then
		return "Hero"
	end
	if getPlayerTool(player, "Knife") then
		return "Murderer"
	end
	if getPlayerTool(player, "Gun") then
		return if player == MurderMystery2.CurrentHero then "Hero" else "Sheriff"
	end
	return "Innocent"
end

function MurderMystery2.updateRoles()
	local foundMurderer: Player? = nil
	local foundSheriff: Player? = nil

	for _, player in ipairs(Players:GetPlayers()) do
		local hasKnife = getPlayerTool(player, "Knife") ~= nil
		local hasGun = getPlayerTool(player, "Gun") ~= nil

		if hasKnife then
			foundMurderer = player
		end
		if hasGun then
			if MurderMystery2.CurrentHero == player then
				-- Keep as hero
			else
				foundSheriff = player
			end
		end
	end

	MurderMystery2.CurrentMurderer = foundMurderer
	MurderMystery2.CurrentSheriff = foundSheriff
end

-- ── 2. Dropped Gun Locator ───────────────────────────────────────────
function MurderMystery2.locateDroppedGun(): Instance?
	local gunDrop = Workspace:FindFirstChild("GunDrop")
	if gunDrop then return gunDrop end

	for _, obj in ipairs(Workspace:GetChildren()) do
		if obj.Name == "GunDrop" or (obj:IsA("Tool") and obj.Name == "Gun" and obj.Parent == Workspace) then
			return obj
		end
	end
	return nil
end

-- ── 3. Visual Kill Box Visualizer ─────────────────────────────────────
local function ensureKillBox()
	if not killBoxPart or not killBoxPart.Parent then
		local box = Instance.new("Part")
		box.Name = "MM2_KillAura_VisualBox"
		box.Anchored = true
		box.CanCollide = false
		box.CanQuery = false
		box.CanTouch = false
		box.CastShadow = false
		box.Material = Enum.Material.ForceField
		box.Transparency = 0.82
		box.Color = MurderMystery2.KillBoxColor
		box.Size = Vector3.new(MurderMystery2.KillBoxSize, MurderMystery2.KillBoxSize, MurderMystery2.KillBoxSize)
		box.Parent = Workspace

		local sbox = Instance.new("SelectionBox")
		sbox.Name = "Outline"
		sbox.Adornee = box
		sbox.Color3 = MurderMystery2.KillBoxColor
		sbox.LineThickness = 0.04
		sbox.Transparency = 0.35
		sbox.Parent = box

		killBoxPart = box
		killBoxSelection = sbox
	end
end

local function removeKillBox()
	if killBoxPart then
		pcall(function() killBoxPart:Destroy() end)
		killBoxPart = nil
		killBoxSelection = nil
	end
end

function MurderMystery2.setKillBoxSize(size: number)
	MurderMystery2.KillBoxSize = math.clamp(size, 6, 80)
	if killBoxPart then
		killBoxPart.Size = Vector3.new(MurderMystery2.KillBoxSize, MurderMystery2.KillBoxSize, MurderMystery2.KillBoxSize)
	end
end

function MurderMystery2.setKillBoxVisible(visible: boolean)
	MurderMystery2.KillBoxVisible = visible
	if killBoxPart then
		killBoxPart.Transparency = if visible then 0.82 else 1
	end
	if killBoxSelection then
		killBoxSelection.Transparency = if visible then 0.35 else 1
	end
end

-- ── 4. KillAura Execution Engine ──────────────────────────────────────
local function attackTargetWithKnife(knife: Tool, targetChar: Model)
	local targetHrp = targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
	if not (targetHrp and targetHum and targetHum.Health > 0) then return end

	local handle = knife:FindFirstChild("Handle") :: BasePart?
	if not handle then return end

	-- Activate knife swing
	pcall(function() knife:Activate() end)

	-- Direct touch trigger via firetouchinterest if supported
	if type((getgenv and (getgenv() :: any).firetouchinterest) or firetouchinterest) == "function" then
		local fti = (getgenv and (getgenv() :: any).firetouchinterest) or firetouchinterest
		pcall(fti, targetHrp, handle, 0)
		pcall(fti, targetHrp, handle, 1)
	end

	-- Trigger remote slash/stab if present
	local stabRemote = knife:FindFirstChild("Stab") or knife:FindFirstChild("Slash")
	if stabRemote and stabRemote:IsA("RemoteEvent") then
		pcall(function() (stabRemote :: RemoteEvent):FireServer() end)
	end

	-- Hitbox expansion touch simulation
	if MurderMystery2.ExpandKnifeHitbox and handle.CanCollide then
		handle.CanCollide = false
		handle.Massless = true
	end
end

local function runKillAuraStep()
	if not MurderMystery2.KillAura then return end

	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (char and hrp and hum and hum.Health > 0) then return end

	-- Update visual box location
	if MurderMystery2.KillBoxVisible then
		ensureKillBox()
		if killBoxPart then
			killBoxPart.CFrame = hrp.CFrame
		end
	else
		removeKillBox()
	end

	local now = tick()
	if now - lastKillAuraTick < MurderMystery2.KillAuraDelay then return end
	lastKillAuraTick = now

	-- Ensure knife is equipped
	local knife = char:FindFirstChild("Knife") :: Tool?
	if not knife then
		local backpackKnife = LocalPlayer.Backpack:FindFirstChild("Knife") :: Tool?
		if backpackKnife and hum then
			hum:EquipTool(backpackKnife)
			knife = backpackKnife
		end
	end

	if not knife then return end

	local halfSize = MurderMystery2.KillBoxSize / 2
	local boxCF = hrp.CFrame

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local targetChar = player.Character
			local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
			local targetHum = targetChar and targetChar:FindFirstChildOfClass("Humanoid")

			if targetChar and targetHrp and targetHum and targetHum.Health > 0 then
				local role = MurderMystery2.getPlayerRole(player)

				local shouldTarget = false
				if role == "Sheriff" or role == "Hero" then
					shouldTarget = MurderMystery2.TargetSheriff
				elseif role == "Innocent" then
					shouldTarget = MurderMystery2.TargetInnocents
				end

				if shouldTarget then
					local relPos = boxCF:PointToObjectSpace(targetHrp.Position)
					if math.abs(relPos.X) <= halfSize and math.abs(relPos.Y) <= halfSize and math.abs(relPos.Z) <= halfSize then
						attackTargetWithKnife(knife, targetChar)
					end
				end
			end
		end
	end
end

-- ── 5. Sheriff Silent Aim & QuickShot Engine ──────────────────────────
local function getMurdererTarget(): (Player?, BasePart?, Vector3?)
	local murderer = MurderMystery2.CurrentMurderer
	if not murderer then
		MurderMystery2.updateRoles()
		murderer = MurderMystery2.CurrentMurderer
	end

	if not murderer or murderer == LocalPlayer then return nil, nil, nil end

	local char = murderer.Character
	if not char then return nil, nil, nil end

	local hum = char:FindFirstChildOfClass("Humanoid")
	local targetPart = (char:FindFirstChild(MurderMystery2.HitPart) or char:FindFirstChild("HumanoidRootPart")) :: BasePart?
	if not (targetPart and hum and hum.Health > 0) then return nil, nil, nil end

	if MurderMystery2.WallCheck then
		local localChar = LocalPlayer.Character
		local localHrp = localChar and localChar:FindFirstChild("HumanoidRootPart") :: BasePart?
		if localHrp then
			local rayParams = RaycastParams.new()
			rayParams.FilterType = Enum.RaycastFilterType.Exclude
			rayParams.FilterDescendantsInstances = {localChar, char}
			local dir = targetPart.Position - localHrp.Position
			local hit = Workspace:Raycast(localHrp.Position, dir, rayParams)
			if hit then return nil, nil, nil end
		end
	end

	-- Trajectory velocity prediction
	local predictedPos = targetPart.Position + (targetPart.AssemblyLinearVelocity * MurderMystery2.Prediction)
	return murderer, targetPart, predictedPos
end

function MurderMystery2.shootMurderer()
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (char and hum and hum.Health > 0) then return end

	local _, _, targetPos = getMurdererTarget()
	if not targetPos then return end

	-- Ensure Gun is equipped
	local gun = char:FindFirstChild("Gun") :: Tool?
	if not gun then
		local bpGun = LocalPlayer.Backpack:FindFirstChild("Gun") :: Tool?
		if bpGun then
			hum:EquipTool(bpGun)
			gun = bpGun
		end
	end

	if not gun then return end

	-- QuickShot instant draw: cancel draw delay animations
	if MurderMystery2.QuickShot then
		for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
			if track.Animation and (string.find(track.Animation.Name:lower(), "equip") or string.find(track.Animation.Name:lower(), "draw")) then
				track:Stop()
			end
		end
	end

	-- Trigger gun shoot remote directly with predicted position
	local shootRemote = gun:FindFirstChild("Shoot") or gun:FindFirstChildWhichIsA("RemoteEvent")
	if shootRemote and shootRemote:IsA("RemoteEvent") then
		pcall(function()
			shootRemote:FireServer(targetPos)
		end)
	end

	-- Also activate tool
	pcall(function()
		gun:Activate()
	end)
end

local function installMetamethodHook()
	if hookInstalled then return end
	hookInstalled = true

	pcall(function()
		local g = (getgenv and getgenv()) or _G
		local hookfunction = g.hookfunction or hookfunc or replaceclosure
		local getrawmetatable = g.getrawmetatable or debug.getrawmetatable
		local setreadonly = g.setreadonly or make_writeable

		if type(getrawmetatable) == "function" and type(hookfunction) == "function" then
			local mt = getrawmetatable(game)
			local oldNamecall = mt.__namecall
			if setreadonly then setreadonly(mt, false) end

			mt.__namecall = function(self, ...)
				local method = getnamecallmethod()
				local args = {...}

				if MurderMystery2.SilentAim and tostring(method) == "FireServer" then
					local selfName = tostring(self)
					if selfName == "Shoot" or selfName == "ShootGun" or (self.Parent and self.Parent.Name == "Gun") then
						local _, _, predPos = getMurdererTarget()
						if predPos then
							-- Override first Vector3 argument with predicted Murderer position
							for i, arg in ipairs(args) do
								if typeof(arg) == "Vector3" then
									args[i] = predPos
									break
								end
							end
							return oldNamecall(self, unpack(args))
						end
					end
				end

				return oldNamecall(self, ...)
			end

			if setreadonly then setreadonly(mt, true) end
		end
	end)
end

-- ── 6. Dropped Gun Auto-Grab Engine ──────────────────────────────────
local function runAutoGrabStep()
	if not MurderMystery2.AutoGrabGun or isGrabbingGun then return end

	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (char and hrp and hum and hum.Health > 0) then return end

	-- Do not grab if already holding or carrying Gun or Knife
	if getPlayerTool(LocalPlayer, "Gun") or getPlayerTool(LocalPlayer, "Knife") then return end

	local gunDrop = MurderMystery2.locateDroppedGun()
	if not gunDrop then return end

	local handle = (gunDrop:FindFirstChild("Handle") or (gunDrop:IsA("BasePart") and gunDrop)) :: BasePart?
	if not handle then return end

	local dist = (handle.Position - hrp.Position).Magnitude
	if dist > MurderMystery2.AutoGrabDistance then return end

	isGrabbingGun = true
	task.spawn(function()
		-- Fire touch interest if supported
		if type((getgenv and (getgenv() :: any).firetouchinterest) or firetouchinterest) == "function" then
			local fti = (getgenv and (getgenv() :: any).firetouchinterest) or firetouchinterest
			pcall(fti, hrp, handle, 0)
			pcall(fti, hrp, handle, 1)
		else
			-- Proximity touch sweep
			local originalCF = hrp.CFrame
			hrp.CFrame = handle.CFrame
			task.wait(0.1)
			if hrp and hrp.Parent then
				hrp.CFrame = originalCF
			end
		end
		task.wait(0.5)
		isGrabbingGun = false
	end)
end

-- ── 7. Role ESP & Cham Visualizer ────────────────────────────────────
local function clearESP()
	for inst, data in pairs(espInstances) do
		if data.Highlight then pcall(function() data.Highlight:Destroy() end) end
		if data.Billboard then pcall(function() data.Billboard:Destroy() end) end
		espInstances[inst] = nil
	end
end

local function applyPlayerESP(player: Player)
	if player == LocalPlayer then return end

	local char = player.Character
	if not char then return end

	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum and hum.Health > 0) then return end

	local role = MurderMystery2.getPlayerRole(player)
	local roleColor = MurderMystery2.InnocentColor

	if role == "Murderer" then
		roleColor = MurderMystery2.MurdererColor
	elseif role == "Sheriff" then
		roleColor = MurderMystery2.SheriffColor
	elseif role == "Hero" then
		roleColor = MurderMystery2.HeroColor
	end

	local data = espInstances[char]
	if not data then
		local hl = Instance.new("Highlight")
		hl.Name = "MM2_RoleHighlight"
		hl.FillTransparency = 0.55
		hl.OutlineTransparency = 0.1
		hl.Adornee = char
		hl.Parent = char

		local bb = Instance.new("BillboardGui")
		bb.Name = "MM2_RoleBillboard"
		bb.Adornee = hrp
		bb.Size = UDim2.new(0, 140, 0, 40)
		bb.StudsOffset = Vector3.new(0, 3.2, 0)
		bb.AlwaysOnTop = true

		local label = Instance.new("TextLabel")
		label.Name = "Info"
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 1, 0)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 13
		label.TextStrokeTransparency = 0.2
		label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		label.Parent = bb
		bb.Parent = char

		data = {Highlight = hl, Billboard = bb}
		espInstances[char] = data
	end

	if data.Highlight then
		data.Highlight.FillColor = roleColor
		data.Highlight.OutlineColor = roleColor
		data.Highlight.Enabled = MurderMystery2.RoleESP
	end

	if data.Billboard then
		data.Billboard.Enabled = MurderMystery2.RoleESP
		local label = data.Billboard:FindFirstChild("Info") :: TextLabel?
		if label then
			local dist = math.floor((hrp.Position - Camera.CFrame.Position).Magnitude)
			label.TextColor3 = roleColor
			label.Text = string.format("%s\n[%s] %dm", player.DisplayName, role:upper(), dist)
		end
	end
end

local function applyDroppedGunESP()
	local gunDrop = MurderMystery2.locateDroppedGun()
	if not gunDrop then return end

	local handle = (gunDrop:FindFirstChild("Handle") or (gunDrop:IsA("BasePart") and gunDrop)) :: BasePart?
	if not handle then return end

	local data = espInstances[gunDrop]
	if not data then
		local hl = Instance.new("Highlight")
		hl.Name = "MM2_GunHighlight"
		hl.FillColor = MurderMystery2.DroppedGunColor
		hl.OutlineColor = Color3.fromRGB(255, 255, 255)
		hl.FillTransparency = 0.3
		hl.OutlineTransparency = 0.1
		hl.Adornee = gunDrop
		hl.Parent = gunDrop

		local bb = Instance.new("BillboardGui")
		bb.Name = "MM2_GunBillboard"
		bb.Adornee = handle
		bb.Size = UDim2.new(0, 130, 0, 35)
		bb.StudsOffset = Vector3.new(0, 2.2, 0)
		bb.AlwaysOnTop = true

		local label = Instance.new("TextLabel")
		label.Name = "Info"
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 1, 0)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 12
		label.TextColor3 = MurderMystery2.DroppedGunColor
		label.TextStrokeTransparency = 0.2
		label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		label.Text = "★ DROPPED GUN ★"
		label.Parent = bb
		bb.Parent = gunDrop

		data = {Highlight = hl, Billboard = bb}
		espInstances[gunDrop] = data
	end

	if data.Highlight then data.Highlight.Enabled = MurderMystery2.RoleESP and MurderMystery2.ShowDroppedGun end
	if data.Billboard then data.Billboard.Enabled = MurderMystery2.RoleESP and MurderMystery2.ShowDroppedGun end
end

local function runESPStep()
	if not MurderMystery2.RoleESP then
		clearESP()
		return
	end

	for _, player in ipairs(Players:GetPlayers()) do
		applyPlayerESP(player)
	end
	applyDroppedGunESP()
end

-- ── 8. Proximity Alert & Auto Shoot on Knife Draw ─────────────────────
local function runRadarStep()
	local murderer = MurderMystery2.CurrentMurderer
	if not murderer or murderer == LocalPlayer then return end

	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local mChar = murderer.Character
	local mHrp = mChar and mChar:FindFirstChild("HumanoidRootPart") :: BasePart?

	if not (hrp and mHrp) then return end

	local dist = (mHrp.Position - hrp.Position).Magnitude

	-- Auto Shoot Murderer if they draw Knife and local player holds Gun
	if MurderMystery2.AutoShootMurderer and getPlayerTool(LocalPlayer, "Gun") and mChar:FindFirstChild("Knife") then
		local now = tick()
		if now - lastShootTick > 0.4 then
			lastShootTick = now
			MurderMystery2.shootMurderer()
		end
	end
end

-- ── 8.5 Coin Farming Automation ─────────────────────────────────────
local coinFarmThread: thread? = nil

local function getNearestCoin(): BasePart?
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return nil end

	local bestCoin: BasePart? = nil
	local bestDist = math.huge

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("BasePart") then
			local n = obj.Name:lower()
			if n == "coin_server" or n == "coin" or n:find("coin") then
				if obj:FindFirstChildWhichIsA("TouchTransmitter") or obj:FindFirstChild("CoinVisual") or obj.Name == "Coin_Server" then
					local d = (obj.Position - hrp.Position).Magnitude
					if d < bestDist then
						bestDist = d
						bestCoin = obj
					end
				end
			end
		end
	end

	return bestCoin
end

function MurderMystery2.setCoinFarm(enabled: boolean)
	MurderMystery2.CoinFarm = enabled
	if enabled then
		if coinFarmThread then task.cancel(coinFarmThread) end
		coinFarmThread = task.spawn(function()
			while MurderMystery2.CoinFarm do
				task.wait(0.1)
				local char = LocalPlayer.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp then
					local coin = getNearestCoin()
					if coin and coin.Parent then
						pcall(function()
							hrp.CFrame = coin.CFrame
							local touch = (firetouchinterest :: any)
							if touch then
								touch(hrp, coin, 0)
								touch(hrp, coin, 1)
							end
						end)
						task.wait(math.clamp(30 / (MurderMystery2.CoinFarmSpeed or 26), 0.15, 1.2))
					end
				end
			end
		end)
	else
		if coinFarmThread then
			task.cancel(coinFarmThread)
			coinFarmThread = nil
		end
	end
end

-- ── 9. Lifecycle & Main Loop Initialization ───────────────────────────
function MurderMystery2.Init()
	if MurderMystery2.IsActive then return end
	MurderMystery2.IsActive = true

	installMetamethodHook()

	-- Primary stepped combat & physics loop (KillAura already has tick throttle)
	table.insert(connections, RunService.Stepped:Connect(function()
		pcall(runKillAuraStep)
		pcall(runAutoGrabStep)
	end))

	-- Heartbeat role & radar loop (throttled to 10Hz to save CPU cycles)
	local lastRoleUpdate = 0
	table.insert(connections, RunService.Heartbeat:Connect(function()
		local now = tick()
		if now - lastRoleUpdate >= 0.1 then
			lastRoleUpdate = now
			pcall(MurderMystery2.updateRoles)
			pcall(runRadarStep)
		end
	end))

	-- RenderStepped ESP loop (throttled to 20Hz - billboard/highlight properties do not need 60Hz re-assignment)
	local lastEspUpdate = 0
	table.insert(connections, RunService.RenderStepped:Connect(function()
		local now = tick()
		if now - lastEspUpdate >= 0.05 then
			lastEspUpdate = now
			pcall(runESPStep)
		end
	end))

	-- User input for QuickShot keybind (default: Q or middle click)
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.Q then
			if getPlayerTool(LocalPlayer, "Gun") then
				MurderMystery2.shootMurderer()
			end
		end
	end))
end

function MurderMystery2.Destroy()
	MurderMystery2.IsActive = false
	MurderMystery2.KillAura = false
	MurderMystery2.RoleESP = false
	MurderMystery2.SilentAim = false
	MurderMystery2.setCoinFarm(false)

	for _, conn in ipairs(connections) do
		pcall(function() conn:Disconnect() end)
	end
	table.clear(connections)

	removeKillBox()
	clearESP()
end

return MurderMystery2
