--!strict
--[=[
    ✦ High-Performance Combat Engine ✦
    Optimized lag-free Silent Aim (with cached O(1) target resolution),
    Wallbang redirection, Aim Tracking (Right-Click Hold), Screen-Centered FOV Circle,
    Trigger Bot, and throttled Hitbox Expander.
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
	TrackTeammates = false,
	TriggerBot = false,
	TriggerBotDelay = 0.05,
	FovCircle = false,
	FovRadius = 120,
	Smoothing = 0.25,
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
local lastTargetUpdateTime = 0

local function isTeammate(player: Player): boolean
	if not LocalPlayer.Team then return false end
	return player.Team == LocalPlayer.Team
end

local function getScreenCenter(): Vector2
	local vp = Camera.ViewportSize
	return Vector2.new(vp.X / 2, vp.Y / 2)
end

local function isPartVisible(origin: Vector3, targetPart: BasePart, ignoreList: {Instance}?): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreList or { LocalPlayer.Character, targetPart.Parent }
	params.IgnoreWater = true

	local direction = targetPart.Position - origin
	local result = Workspace:Raycast(origin, direction, params)
	return result == nil or result.Instance:IsDescendantOf(targetPart.Parent)
end

function Combat.getClosestTarget(ignoreWalls: boolean?): (Player?, BasePart?)
	local screenCenter = getScreenCenter()
	local closestPlayer: Player? = nil
	local closestPart: BasePart? = nil
	local shortestDist = Combat.FovRadius
	local checkWall = (ignoreWalls ~= true and not Combat.Wallbang)
	local camPos = Camera.CFrame.Position
	local myChar = LocalPlayer.Character
	
	for _, player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then continue end
		if not Combat.TrackTeammates and isTeammate(player) then continue end
		
		local character = player.Character
		if not character then continue end
		
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then continue end
		
		local targetPart = if Combat.TargetPart == "Head" then
			character:FindFirstChild("Head") :: BasePart?
		else
			(character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")) :: BasePart?

		if not targetPart then
			targetPart = (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")) :: BasePart?
		end
		if not targetPart then continue end
		
		local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
		if not onScreen then continue end
		
		local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
		if dist < shortestDist then
			local visible = true
			if checkWall then
				visible = isPartVisible(camPos, targetPart, {myChar, character})
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

-- ── Throttled Target Cache Updater (Prevents High-Frequency Frame Spikes) ──
RunService.Heartbeat:Connect(function()
	if not Combat.SilentAim and not Combat.AimTracking then
		cachedTargetPlayer = nil
		cachedTargetPart = nil
		return
	end

	local now = tick()
	if now - lastTargetUpdateTime >= 0.033 then -- 30 FPS update rate for target solver
		lastTargetUpdateTime = now
		cachedTargetPlayer, cachedTargetPart = Combat.getClosestTarget(Combat.Wallbang)
	end
end)

-- ── Metamethod Hooks for Silent Aim & Wallbang (Optimized) ───────────
pcall(function()
	local hook = hookmetamethod or (getgenv and getgenv().hookmetamethod)
	local getnamecall = getnamecallmethod or (getgenv and getgenv().getnamecallmethod)
	local checkcall = checkcaller or (getgenv and getgenv().checkcaller)

	if type(hook) == "function" and type(getnamecall) == "function" then
		-- Fast __namecall hook with O(1) cached target lookup
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

		-- Fast __index hook for Mouse.Hit and Mouse.Target
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

-- Trigger Bot Check (Raycast under cursor or screen center)
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

-- Main RenderStepped Combat Loop (Fast, No Heavy Iteration)
RunService.RenderStepped:Connect(function()
	local screenCenter = getScreenCenter()
	
	-- FOV Circle Rendering
	if fovDrawing then
		if Combat.FovCircle then
			fovDrawing.Position = screenCenter
			fovDrawing.Radius = Combat.FovRadius
			fovDrawing.Color = Combat.FovColor
			fovDrawing.Visible = true
		else
			fovDrawing.Visible = false
		end
	end
	
	-- Aim Tracking Loop: Only tracks when holding Right Mouse Button (MouseButton2)
	if Combat.AimTracking and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
		local targetPart = cachedTargetPart
		if targetPart then
			local currentCF = Camera.CFrame
			local targetCF = CFrame.lookAt(currentCF.Position, targetPart.Position)
			Camera.CFrame = currentCF:Lerp(targetCF, math.clamp(Combat.Smoothing, 0.05, 1))
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
