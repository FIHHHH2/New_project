--!strict
--[=[
    ✦ High-Performance Combat & Aim Tracking Engine ✦
    Features:
    - Post-Camera BindToRenderStep (Enum.RenderPriority.Camera.Value + 1) Aim Tracking
      (Guarantees camera aim lock is never overwritten by Roblox CameraModule)
    - Full-screen / FOV adaptive target resolution with transparent-barrier bypass
    - Cached O(1) Raycast and Mouse metamethod hooks for instant Silent Aim & Wallbang
    - Trigger Bot and Customizable Hitbox Expander
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

local Combat = {
	SilentAim = false,
	Wallbang = false,
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
	FovColor = Color3.fromRGB(55, 175, 245)
}

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

local originalHitboxSizes: {[BasePart]: Vector3} = {}
local lastTriggerTime = 0
local cachedTargetPlayer: Player? = nil
local cachedTargetPart: BasePart? = nil

local function isTeammate(player: Player): boolean
	if not LocalPlayer.Team then return false end
	return player.Team == LocalPlayer.Team
end

local function getScreenCenter(): Vector2
	local vp = Camera.ViewportSize
	return Vector2.new(vp.X / 2, vp.Y / 2)
end

local function isPartVisible(origin: Vector3, targetPart: BasePart, targetChar: Model): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { LocalPlayer.Character, targetChar }
	params.IgnoreWater = true

	local direction = targetPart.Position - origin
	local result = Workspace:Raycast(origin, direction, params)
	if not result then return true end

	-- Check if hit object is invisible/non-collidable trigger
	if not result.Instance.CanCollide and result.Instance.Transparency >= 0.75 then
		return true
	end

	return result.Instance:IsDescendantOf(targetChar)
end

function Combat.getClosestTarget(ignoreWalls: boolean?): (Player?, BasePart?)
	local screenCenter = getScreenCenter()
	local closestPlayer: Player? = nil
	local closestPart: BasePart? = nil
	local maxRadius = if Combat.FovCircle then Combat.FovRadius else 1200
	local shortestDist = maxRadius
	local checkWall = (ignoreWalls ~= true and not Combat.Wallbang)
	local camPos = Camera.CFrame.Position
	
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
		
		local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
		if not onScreen then continue end
		
		local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
		if dist < shortestDist then
			local visible = true
			if checkWall then
				visible = isPartVisible(camPos, targetPart, character)
			end

			if visible then
				shortestDist = dist
				closestPlayer = player
				closestPart = targetPart
			end
		end
	end
	
	return closestPlayer, closestPart
end

-- ── 60 FPS Continuous Target Solver ──────────────────────────────────
RunService.Heartbeat:Connect(function()
	if not Combat.SilentAim and not Combat.AimTracking then
		cachedTargetPlayer = nil
		cachedTargetPart = nil
		return
	end

	cachedTargetPlayer, cachedTargetPart = Combat.getClosestTarget(Combat.Wallbang)
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
					if target and (Combat.HitChance >= 100 or math.random(1, 100) <= Combat.HitChance) then
						local origin = select(1, ...)
						if typeof(origin) == "Vector3" then
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
			elseif (method == "FindPartOnRay" or method == "findPartOnRay" or method == "FindPartOnRayWithIgnoreList" or method == "FindPartOnRayWithWhitelist") and self == Workspace then
				if not (checkcall and checkcall()) then
					local target = cachedTargetPart
					if target and (Combat.HitChance >= 100 or math.random(1, 100) <= Combat.HitChance) then
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
					if target and (Combat.HitChance >= 100 or math.random(1, 100) <= Combat.HitChance) then
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

-- Trigger Bot Check (Raycast under cursor)
local function checkTriggerBot()
	if not Combat.TriggerBot then return end
	local now = tick()
	if now - lastTriggerTime < Combat.TriggerBotDelay then return end
	
	local mousePos = UserInputService:GetMouseLocation()
	local unitRay = Camera:ViewportPointToRay(mousePos.X, mousePos.Y)
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	if LocalPlayer.Character then
		raycastParams.FilterDescendantsInstances = { LocalPlayer.Character }
	end
	
	local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * 1000, raycastParams)
	if result and result.Instance then
		local hitChar = result.Instance:FindFirstAncestorOfClass("Model")
		if hitChar then
			local hitPlayer = Players:GetPlayerFromCharacter(hitChar)
			if hitPlayer and hitPlayer ~= LocalPlayer then
				if Combat.TrackTeammates or not isTeammate(hitPlayer) then
					local hum = hitChar:FindFirstChildOfClass("Humanoid")
					if hum and hum.Health > 0 then
						lastTriggerTime = now
						local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
						if tool and typeof(tool.Activate) == "function" then
							tool:Activate()
						end
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

	-- Trigger Bot Execution
	checkTriggerBot()
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
