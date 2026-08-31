--!strict
--[=[
    ✦ Combat Engine ✦
    High-performance Aim Tracking (Right-Click Hold), Screen-Centered FOV Circle, Trigger Bot, and Hitbox Expander.
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
	AimTracking = false,
	TrackTeammates = false,
	TriggerBot = false,
	TriggerBotDelay = 0.05,
	FovCircle = false,
	FovRadius = 120,
	Smoothing = 0.25,
	ExpandHitboxes = false,
	HitboxSize = 12,
	TargetPart = "Head",
	FovColor = Color3.fromRGB(55, 175, 245)
}

local hasDrawing = (typeof(Drawing) == "table" and typeof(Drawing.new) == "function")
local fovDrawing: any = nil

if hasDrawing then
	local circle = Drawing.new("Circle")
	circle.Thickness = 1.5
	circle.NumSides = 64
	circle.Radius = Combat.FovRadius
	circle.Filled = false
	circle.Color = Combat.FovColor
	circle.Transparency = 1
	circle.Visible = false
	fovDrawing = circle
end

local originalHitboxSizes: {[BasePart]: Vector3} = {}
local lastTriggerTime = 0

local function isTeammate(player: Player): boolean
	if not LocalPlayer.Team then return false end
	return player.Team == LocalPlayer.Team
end

local function getScreenCenter(): Vector2
	return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

local function getClosestTarget(): (Player?, BasePart?)
	local screenCenter = getScreenCenter()
	local closestPlayer: Player? = nil
	local closestPart: BasePart? = nil
	local shortestDist = Combat.FovRadius
	
	for _, player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then continue end
		if not Combat.TrackTeammates and isTeammate(player) then continue end
		
		local character = player.Character
		if not character then continue end
		
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then continue end
		
		local targetPart = (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")) :: BasePart?
		if not targetPart then continue end
		
		local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
		if not onScreen then continue end
		
		local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
		if dist < shortestDist then
			shortestDist = dist
			closestPlayer = player
			closestPart = targetPart
		end
	end
	
	return closestPlayer, closestPart
end

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
						-- Activate equipped tool or click
						local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
						if tool and typeof(tool.Activate) == "function" then
							tool:Activate()
						elseif mouse1click then
							mouse1click()
						end
					end
				end
			end
		end
	end
end

-- Main RenderStepped Combat Loop
RunService.RenderStepped:Connect(function()
	local screenCenter = getScreenCenter()
	
	-- FOV Circle Rendering: Centered strictly on screen center
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
		local _, targetPart = getClosestTarget()
		if targetPart then
			local currentCF = Camera.CFrame
			local targetCF = CFrame.lookAt(currentCF.Position, targetPart.Position)
			Camera.CFrame = currentCF:Lerp(targetCF, math.clamp(Combat.Smoothing, 0.05, 1))
		end
	end
	
	-- Trigger Bot Execution
	checkTriggerBot()
	
	-- Hitbox Expander Loop
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
