--!strict
--[=[
    ✦ High-Performance Combat & Aim Tracking Engine ✦
    Features:
    - Post-Camera BindToRenderStep (Enum.RenderPriority.Camera.Value + 1) Aim Tracking
      (Guarantees camera aim lock is never overwritten by Roblox CameraModule)
    - Full-screen / FOV adaptive target resolution with transparent-barrier bypass
    - Spatial 3D distance & FOV culling with two-pass screen-distance sorted target solver
    - Zero-allocation static RaycastParams and reusable filter arrays for 60+ FPS stability
    - Throttled Trigger Bot and Leak-Free Hitbox Expander with lifecycle cleanup
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	Camera = Workspace.CurrentCamera or Camera
end)

local MAX_AIM_DISTANCE = 500 -- Maximum 3D stud distance
local MAX_AIM_DISTANCE_SQ = MAX_AIM_DISTANCE * MAX_AIM_DISTANCE
local TRIGGER_CHECK_INTERVAL = 0.033 -- ~30 Hz TriggerBot throttle

local Combat = {
	SilentAim = false,
	Wallbang = false,
	WallbangThickness = 5,
	HitChance = 100,
	TargetPart = "Head",
	AimTracking = false,
	AimMode = "Hold RMB", -- "Hold RMB" or "Always"
	TrackTeammates = false,
	TriggerBot = false,
	TriggerBotDelay = 0.05,
	FovCircle = false,
	FovRadius = 160,
	Smoothing = 0.40,
	ExpandHitboxes = false,
	HitboxSize = 12,
	FovColor = Color3.fromRGB(255, 255, 255)
}

-- ── Drawing Setup ────────────────────────────────────────────────────
local hasDrawing = (typeof(Drawing) == "table" and typeof(Drawing.new) == "function")
local fovDrawing: any = nil

if hasDrawing then
	local circle = Drawing.new("Circle")
	circle.Thickness = 1.5
	circle.NumSides = 48
	circle.Radius = Combat.FovRadius
	circle.Filled = false
	circle.Color = Combat.FovColor
	circle.Transparency = 1
	circle.Visible = false
	fovDrawing = circle
end

-- ── Static Shared RaycastParams & Reusable Filter Tables ──────────────
local SHARED_RAY_PARAMS = RaycastParams.new()
SHARED_RAY_PARAMS.FilterType = Enum.RaycastFilterType.Exclude
SHARED_RAY_PARAMS.IgnoreWater = true

local SHARED_TRIGGER_PARAMS = RaycastParams.new()
SHARED_TRIGGER_PARAMS.FilterType = Enum.RaycastFilterType.Exclude
SHARED_TRIGGER_PARAMS.IgnoreWater = true

local reusableFilterArray: {Instance} = {}
local triggerFilterArray: {Instance} = {}

local function setSharedFilter(targetChar: Model?)
	table.clear(reusableFilterArray)
	if LocalPlayer.Character then
		table.insert(reusableFilterArray, LocalPlayer.Character)
	end
	if targetChar and targetChar ~= LocalPlayer.Character then
		table.insert(reusableFilterArray, targetChar)
	end
	SHARED_RAY_PARAMS.FilterDescendantsInstances = reusableFilterArray
end

local function updateTriggerParams()
	table.clear(triggerFilterArray)
	if LocalPlayer.Character then
		table.insert(triggerFilterArray, LocalPlayer.Character)
	end
	SHARED_TRIGGER_PARAMS.FilterDescendantsInstances = triggerFilterArray
end

-- ── Target Solver Types & Reusable Data Structures ───────────────────
type TargetCandidate = {
	player: Player,
	character: Model,
	targetPart: BasePart,
	screenDist: number
}

local candidateList: {TargetCandidate} = {}

local function compareCandidates(a: TargetCandidate, b: TargetCandidate): boolean
	return a.screenDist < b.screenDist
end

local originalHitboxSizes: {[BasePart]: Vector3} = {}
local lastTriggerTime = 0
local lastTriggerCheck = 0
local cachedTargetPlayer: Player? = nil
local cachedTargetPart: BasePart? = nil

-- ── Helper Functions ─────────────────────────────────────────────────
local function isTeammate(player: Player): boolean
	if not LocalPlayer.Team then return false end
	return player.Team == LocalPlayer.Team
end

local function getScreenCenter(): Vector2
	local vp = Camera.ViewportSize
	return Vector2.new(vp.X / 2, vp.Y / 2)
end

local function isPartVisible(origin: Vector3, targetPart: BasePart, targetChar: Model): boolean
	setSharedFilter(targetChar)
	local direction = targetPart.Position - origin
	local result = Workspace:Raycast(origin, direction, SHARED_RAY_PARAMS)
	if not result then return true end

	-- Check if hit object is invisible/non-collidable trigger
	if not result.Instance.CanCollide and result.Instance.Transparency >= 0.75 then
		return true
	end

	return result.Instance:IsDescendantOf(targetChar)
end

function Combat.setFovColor(color: Color3)
	Combat.FovColor = color
	if fovDrawing then
		fovDrawing.Color = color
	end
end

function Combat.setTriggerBotDelay(delaySec: number)
	Combat.TriggerBotDelay = math.clamp(delaySec, 0, 0.5)
end

function Combat.setWallbangThickness(thicknessStuds: number)
	Combat.WallbangThickness = math.clamp(thicknessStuds, 0, 20)
end

function Combat.checkWallbangPenetration(origin: Vector3, targetPart: BasePart, targetChar: Model): (boolean, number)
	if not targetPart or not targetChar then return false, 999 end

	local targetPos = targetPart.Position
	local toTarget = targetPos - origin
	local totalDist = toTarget.Magnitude
	if totalDist < 0.1 then
		return true, 0
	end

	setSharedFilter(targetChar)

	-- 1. Forward Raycast: from origin towards target to find entry point
	local forwardResult = Workspace:Raycast(origin, toTarget, SHARED_RAY_PARAMS)
	if not forwardResult then
		-- No obstacles between origin and target (Direct line of sight)
		return true, 0
	end

	-- If non-collidable transparent barrier, allow hit
	if not forwardResult.Instance.CanCollide and forwardResult.Instance.Transparency >= 0.75 then
		return true, 0
	end

	local entryPoint = forwardResult.Position

	-- 2. Backward Raycast: from target towards origin to find exit point
	local fromTarget = origin - targetPos
	local backwardResult = Workspace:Raycast(targetPos, fromTarget, SHARED_RAY_PARAMS)
	local exitPoint = if backwardResult then backwardResult.Position else targetPos

	-- 3. Calculate Wall Thickness: (exitPoint - entryPoint).Magnitude
	local thickness = if not backwardResult then (targetPos - entryPoint).Magnitude else (exitPoint - entryPoint).Magnitude

	local canPenetrate = (thickness <= Combat.WallbangThickness)
	return canPenetrate, thickness
end

-- ── Spatial Distance Filtering Helper (PROJECT.md contract) ──────────
function Combat.getNearbyTargets(radius: number?, maxTargets: number?): {Player}
	local maxDist = radius or MAX_AIM_DISTANCE
	local limit = maxTargets or 10
	local targets: {Player} = {}
	local camPos = Camera.CFrame.Position

	for _, player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then continue end
		if not Combat.TrackTeammates and isTeammate(player) then continue end
		local character = player.Character
		if not character then continue end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then continue end
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then continue end

		local dist = (root.Position - camPos).Magnitude
		if dist <= maxDist then
			table.insert(targets, player)
			if #targets >= limit then break end
		end
	end

	return targets
end

-- ── Optimized Two-Pass Target Solver ─────────────────────────────────
function Combat.getClosestTarget(ignoreWalls: boolean?): (Player?, BasePart?)
	local screenCenter = getScreenCenter()
	local maxRadius = if Combat.FovCircle then Combat.FovRadius else 1200
	local camCF = Camera.CFrame
	local camPos = camCF.Position
	local camLook = camCF.LookVector
	local candidateCount = 0

	-- ── PASS 1: Fast Spatial 3D & 2D Screen Filtering (Zero Raycasts) ─
	for _, player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then continue end
		if not Combat.TrackTeammates and isTeammate(player) then continue end

		local character = player.Character
		if not character then continue end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then continue end

		local targetPart: BasePart? = nil
		if Combat.TargetPart == "Head" then
			targetPart = character:FindFirstChild("Head") :: BasePart?
		else
			targetPart = (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")) :: BasePart?
		end

		if not targetPart then
			targetPart = (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart") or character:FindFirstChildWhichIsA("BasePart")) :: BasePart?
		end
		if not targetPart then continue end

		-- 3D Distance check (cull distant players beyond 500 studs)
		local targetPos = targetPart.Position
		local offset = targetPos - camPos
		local distSq = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z
		if distSq > MAX_AIM_DISTANCE_SQ then continue end

		-- FOV angle check (must be in front of camera)
		if camLook:Dot(offset) <= 0 then continue end

		-- 2D Screen projection check
		local screenPos, onScreen = Camera:WorldToViewportPoint(targetPos)
		if not onScreen then continue end

		-- 2D Screen distance check
		local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
		if screenDist > maxRadius then continue end

		-- Add or reuse candidate in array
		candidateCount += 1
		local cand = candidateList[candidateCount]
		if not cand then
			cand = {
				player = player,
				character = character,
				targetPart = targetPart,
				screenDist = screenDist
			}
			candidateList[candidateCount] = cand
		else
			cand.player = player
			cand.character = character
			cand.targetPart = targetPart
			cand.screenDist = screenDist
		end
	end

	if candidateCount == 0 then
		return nil, nil
	end

	-- Clean up trailing entries to keep table length accurate for sorting
	for i = candidateCount + 1, #candidateList do
		candidateList[i] = nil
	end

	-- Sort candidates ascending by screen distance
	if candidateCount > 1 then
		table.sort(candidateList, compareCandidates)
	end

	-- ── PASS 2: Visibility Raycasts Only for Closest Candidate(s) ─────
	for i = 1, candidateCount do
		local cand = candidateList[i]
		local visible = false

		if ignoreWalls == true then
			visible = true
		elseif Combat.Wallbang then
			visible = Combat.checkWallbangPenetration(camPos, cand.targetPart, cand.character)
		else
			visible = isPartVisible(camPos, cand.targetPart, cand.character)
		end

		if visible then
			return cand.player, cand.targetPart
		end
	end

	return nil, nil
end

-- ── 60 FPS Continuous Target Solver ──────────────────────────────────
RunService.Heartbeat:Connect(function()
	if not Combat.SilentAim and not Combat.AimTracking then
		cachedTargetPlayer = nil
		cachedTargetPart = nil
		return
	end

	cachedTargetPlayer, cachedTargetPart = Combat.getClosestTarget()
end)

-- ── Metamethod Hooks for Silent Aim & Wallbang (Optimized) ───────────
pcall(function()
	local hook = hookmetamethod or (getgenv and getgenv().hookmetamethod)
	local getnamecall = getnamecallmethod or (getgenv and getgenv().getnamecallmethod)
	local checkcall = checkcaller or (getgenv and getgenv().checkcaller)

	if type(hook) == "function" and type(getnamecall) == "function" then
		local oldNamecall: any
		oldNamecall = hook(game, "__namecall", function(self, ...)
			if not Combat.SilentAim then
				return oldNamecall(self, ...)
			end

			local method = getnamecall()
			if method == "Raycast" and self == Workspace then
				if not (checkcall and checkcall()) then
					local target = cachedTargetPart
					if target and target.Parent and (Combat.HitChance >= 100 or math.random(1, 100) <= Combat.HitChance) then
						local origin = select(1, ...)
						if typeof(origin) == "Vector3" then
							local targetChar = target.Parent :: Model?
							local canHit = true
							if Combat.Wallbang and targetChar then
								canHit = Combat.checkWallbangPenetration(origin, target, targetChar)
							end
							if canHit then
								local dir = (target.Position - origin).Unit * 1000
								local p3 = select(3, ...)
								if Combat.Wallbang and typeof(p3) == "RaycastParams" then
									p3.FilterType = Enum.RaycastFilterType.Include
									p3.FilterDescendantsInstances = { target.Parent }
								end
								return oldNamecall(self, origin, dir, p3)
							end
						end
					end
				end
			elseif (method == "FindPartOnRay" or method == "findPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist") and self == Workspace then
				if not (checkcall and checkcall()) then
					local target = cachedTargetPart
					if target and target.Parent and (Combat.HitChance >= 100 or math.random(1, 100) <= Combat.HitChance) then
						local ray = select(1, ...)
						if typeof(ray) == "Ray" then
							local newDir = (target.Position - ray.Origin).Unit * 1000
							local newRay = Ray.new(ray.Origin, newDir)
							return oldNamecall(self, newRay, select(2, ...))
						end
					end
				end
			end

			return oldNamecall(self, ...)
		end)

		local oldIndex: any
		oldIndex = hook(game, "__index", function(self, key)
			if not Combat.SilentAim then
				return oldIndex(self, key)
			end

			if (key == "Hit" or key == "Target") and typeof(self) == "Instance" and self:IsA("Mouse") then
				if not (checkcall and checkcall()) then
					local target = cachedTargetPart
					if target and target.Parent and (Combat.HitChance >= 100 or math.random(1, 100) <= Combat.HitChance) then
						if key == "Hit" then
							return target.CFrame
						elseif key == "Target" then
							return target
						end
					end
				end
			end

			return oldIndex(self, key)
		end)
	end
end)

-- ── Throttled Trigger Bot Check (Reusing SHARED_TRIGGER_PARAMS) ──────
local function checkTriggerBot()
	if not Combat.TriggerBot then return end
	local now = os.clock()
	if now - lastTriggerCheck < TRIGGER_CHECK_INTERVAL then return end
	lastTriggerCheck = now
	if now - lastTriggerTime < Combat.TriggerBotDelay then return end

	local mousePos = UserInputService:GetMouseLocation()
	local unitRay = Camera:ViewportPointToRay(mousePos.X, mousePos.Y)

	updateTriggerParams()
	local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, SHARED_TRIGGER_PARAMS)
	if result and result.Instance then
		local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
		if hitChar then
			local hitPlayer = Players:GetPlayerFromCharacter(hitChar)
			if hitPlayer and hitPlayer ~= LocalPlayer then
				if Combat.TrackTeammates or not isTeammate(hitPlayer) then
					local hum = hitChar:FindFirstChildOfClass("Humanoid")
					if hum and hum.Health > 0 then
						lastTriggerTime = now + Combat.TriggerBotDelay
						task.spawn(function()
							if Combat.TriggerBotDelay > 0 then
								task.wait(Combat.TriggerBotDelay)
							end
							if Combat.TriggerBot and LocalPlayer.Character then
								local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
								if tool and typeof(tool.Activate) == "function" then
									tool:Activate()
								end
							end
						end)
					end
				end
			end
		end
	end
end

-- ── Post-Camera Priority Aim Tracking (Enum.RenderPriority.Camera.Value + 1) ──
RunService:BindToRenderStep("FihCombatAimTrack", Enum.RenderPriority.Camera.Value + 1, function()
	-- FOV Circle Position
	if fovDrawing then
		if Combat.FovCircle then
			fovDrawing.Position = getScreenCenter()
			fovDrawing.Radius = Combat.FovRadius
			fovDrawing.Color = Combat.FovColor
			fovDrawing.Visible = true
		else
			fovDrawing.Visible = false
		end
	end

	-- Aim Tracking Logic
	if Combat.AimTracking then
		local shouldTrack = (Combat.AimMode == "Always") or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		if shouldTrack then
			local targetPart = cachedTargetPart
			if targetPart and targetPart.Parent then
				local currentCF = Camera.CFrame
				local targetCF = CFrame.lookAt(currentCF.Position, targetPart.Position)
				local smoothFactor = math.clamp(Combat.Smoothing, 0.05, 1.0)
				Camera.CFrame = currentCF:Lerp(targetCF, smoothFactor)
			end
		end
	end

	-- Trigger Bot Execution (Throttled internally)
	checkTriggerBot()
end)

-- ── Hitbox Expander Lifecycle Cleanup Hooks ───────────────────────────
local function setupPlayerCleanup(player: Player)
	player.CharacterRemoving:Connect(function(character: Model)
		local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			originalHitboxSizes[hrp] = nil
		end
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayerCleanup(player)
end

Players.PlayerAdded:Connect(setupPlayerCleanup)

Players.PlayerRemoving:Connect(function(player: Player)
	if player.Character then
		local hrp = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			originalHitboxSizes[hrp] = nil
		end
	end
	-- Prune any orphaned keys
	for hrp in pairs(originalHitboxSizes) do
		if not hrp.Parent or hrp.Parent.Parent == nil then
			originalHitboxSizes[hrp] = nil
		end
	end
end)

-- Hitbox Expander Loop (Throttled at 5 Hz)
task.spawn(function()
	while true do
		task.wait(0.2)
		if Combat.ExpandHitboxes then
			for _, player in ipairs(Players:GetPlayers()) do
				if player ~= LocalPlayer and player.Character then
					if not Combat.TrackTeammates and isTeammate(player) then continue end
					local hrp = player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if hrp then
						if not originalHitboxSizes[hrp] then
							originalHitboxSizes[hrp] = hrp.Size
						end
						hrp.Size = Vector3.new(Combat.HitboxSize, Combat.HitboxSize, Combat.HitboxSize)
						hrp.Transparency = 0.6
						hrp.CanCollide = false
					end
				end
			end
		else
			-- Periodic sweep for detached parts even when disabled
			for hrp in pairs(originalHitboxSizes) do
				if not hrp.Parent then
					originalHitboxSizes[hrp] = nil
				end
			end
		end
	end
end)

function Combat.resetHitboxes()
	for hrp, origSize in pairs(originalHitboxSizes) do
		if hrp and hrp.Parent then
			hrp.Size = origSize
			hrp.Transparency = 1
		end
	end
	table.clear(originalHitboxSizes)
end

return Combat
