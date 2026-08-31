--!strict
--[=[
    ✦ Visuals Rendering Engine ✦
    High-performance 2D ESP Boxes with Outlines, Health Bars, Tracers with Origin Selector,
    Distance Tags, Skeletons, and 3D Highlight Chams with customizable colors.
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	Camera = Workspace.CurrentCamera or Camera
end)

local Visuals = {
	-- 2D ESP Settings
	Box2D = false,
	BoxOutlines = false,
	BoxColor = Color3.fromRGB(55, 175, 245),
	
	HealthBar = false,
	
	Tracers = false,
	TracerOrigin = "Bottom" :: "Bottom" | "Center" | "Mouse",
	TracerColor = Color3.fromRGB(255, 255, 255),
	
	Distance = false,
	DistanceColor = Color3.fromRGB(240, 240, 240),
	
	Skeleton = false,
	SkeletonColor = Color3.fromRGB(255, 200, 50),
	
	-- 3D Chams / Highlights Settings
	Chams = false,
	ChamsTransparency = 0.5,
	ChamsOutlineTransparency = 0.2,
	ChamsColor = Color3.fromRGB(180, 70, 255),
	ChamsFillColor = Color3.fromRGB(180, 70, 255),
	ChamsOutlineColor = Color3.fromRGB(255, 255, 255),
}

-- Registry of created visual elements per player
type PlayerVisual = {
	Highlight: Highlight?,
	BoxOutline: any?,
	Box: any?,
	HealthBarBg: any?,
	HealthBarFill: any?,
	Tracer: any?,
	DistanceTag: any?,
	Bones: {any}
}

local playerVisuals: {[Player]: PlayerVisual} = {}
local hasDrawing = (typeof(Drawing) == "table" and typeof(Drawing.new) == "function")

local function createPlayerVisual(player: Player): PlayerVisual
	local pv: PlayerVisual = {
		Highlight = nil,
		BoxOutline = nil,
		Box = nil,
		HealthBarBg = nil,
		HealthBarFill = nil,
		Tracer = nil,
		DistanceTag = nil,
		Bones = {}
	}
	
	if hasDrawing then
		-- Box Outline (Secondary black square for contrast, Thickness = 3.5)
		local successOutline, boxOutline = pcall(function()
			local square = Drawing.new("Square")
			square.Thickness = 3.5
			square.Filled = false
			square.Color = Color3.fromRGB(0, 0, 0)
			square.Visible = false
			square.Transparency = 1
			return square
		end)
		if successOutline and boxOutline then
			pv.BoxOutline = boxOutline
		end

		-- 2D Box
		local successBox, box = pcall(function()
			local square = Drawing.new("Square")
			square.Thickness = 1.5
			square.Filled = false
			square.Color = Visuals.BoxColor
			square.Visible = false
			square.Transparency = 1
			return square
		end)
		if successBox and box then
			pv.Box = box
		end
		
		-- Health Bar BG
		local successHbBg, hbBg = pcall(function()
			local square = Drawing.new("Square")
			square.Thickness = 1
			square.Filled = true
			square.Color = Color3.fromRGB(15, 15, 15)
			square.Visible = false
			square.Transparency = 1
			return square
		end)
		if successHbBg and hbBg then
			pv.HealthBarBg = hbBg
		end
		
		-- Health Bar Fill
		local successHbFill, hbFill = pcall(function()
			local square = Drawing.new("Square")
			square.Thickness = 1
			square.Filled = true
			square.Color = Color3.fromRGB(50, 220, 80)
			square.Visible = false
			square.Transparency = 1
			return square
		end)
		if successHbFill and hbFill then
			pv.HealthBarFill = hbFill
		end
		
		-- Tracer line
		local successTracer, tracer = pcall(function()
			local line = Drawing.new("Line")
			line.Thickness = 1.2
			line.Color = Visuals.TracerColor
			line.Visible = false
			line.Transparency = 1
			return line
		end)
		if successTracer and tracer then
			pv.Tracer = tracer
		end
		
		-- Distance tag (3D stud distance text positioned below bounding box)
		local successDist, distTag = pcall(function()
			local text = Drawing.new("Text")
			text.Size = 13
			text.Center = true
			text.Outline = true
			text.OutlineColor = Color3.fromRGB(0, 0, 0)
			text.Color = Visuals.DistanceColor
			text.Visible = false
			text.Transparency = 1
			return text
		end)
		if successDist and distTag then
			pv.DistanceTag = distTag
		end
		
		-- Skeleton bones (14 bone segments)
		for i = 1, 14 do
			local successBone, bone = pcall(function()
				local line = Drawing.new("Line")
				line.Thickness = 1.2
				line.Color = Visuals.SkeletonColor
				line.Visible = false
				line.Transparency = 1
				return line
			end)
			if successBone and bone then
				table.insert(pv.Bones, bone)
			end
		end
	end
	
	return pv
end

local function cleanPlayerVisual(pv: PlayerVisual)
	if pv.Highlight then
		pcall(function() pv.Highlight:Destroy() end)
		pv.Highlight = nil
	end
	if pv.BoxOutline then
		pcall(function() pv.BoxOutline:Remove() end)
		pv.BoxOutline = nil
	end
	if pv.Box then
		pcall(function() pv.Box:Remove() end)
		pv.Box = nil
	end
	if pv.HealthBarBg then
		pcall(function() pv.HealthBarBg:Remove() end)
		pv.HealthBarBg = nil
	end
	if pv.HealthBarFill then
		pcall(function() pv.HealthBarFill:Remove() end)
		pv.HealthBarFill = nil
	end
	if pv.Tracer then
		pcall(function() pv.Tracer:Remove() end)
		pv.Tracer = nil
	end
	if pv.DistanceTag then
		pcall(function() pv.DistanceTag:Remove() end)
		pv.DistanceTag = nil
	end
	for _, bone in ipairs(pv.Bones) do
		pcall(function() bone:Remove() end)
	end
	pv.Bones = {}
end

local function hideAll(pv: PlayerVisual)
	if pv.Highlight then pv.Highlight.Enabled = false end
	if pv.BoxOutline then pv.BoxOutline.Visible = false end
	if pv.Box then pv.Box.Visible = false end
	if pv.HealthBarBg then pv.HealthBarBg.Visible = false end
	if pv.HealthBarFill then pv.HealthBarFill.Visible = false end
	if pv.Tracer then pv.Tracer.Visible = false end
	if pv.DistanceTag then pv.DistanceTag.Visible = false end
	for _, bone in ipairs(pv.Bones) do bone.Visible = false end
end

local function updatePlayer(player: Player, pv: PlayerVisual)
	if player == LocalPlayer then return end
	local character = player.Character
	if not character then
		hideAll(pv)
		return
	end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") :: BasePart?
	
	if not humanoid or not rootPart or humanoid.Health <= 0 then
		hideAll(pv)
		return
	end
	
	-- 3D Chams / Highlight
	if Visuals.Chams then
		local fillColor = Visuals.ChamsFillColor or Visuals.ChamsColor or Color3.fromRGB(180, 70, 255)
		local outlineColor = Visuals.ChamsOutlineColor or Color3.fromRGB(255, 255, 255)
		local fillTransparency = Visuals.ChamsTransparency or 0.5
		local outlineTransparency = Visuals.ChamsOutlineTransparency or 0.2
		
		if not pv.Highlight or pv.Highlight.Parent ~= character then
			if pv.Highlight then
				pcall(function() pv.Highlight:Destroy() end)
			end
			local successHl, hl = pcall(function()
				local inst = Instance.new("Highlight")
				inst.Name = "ModularChams"
				inst.FillColor = fillColor
				inst.OutlineColor = outlineColor
				inst.FillTransparency = fillTransparency
				inst.OutlineTransparency = outlineTransparency
				inst.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				inst.Adornee = character
				inst.Parent = character
				return inst
			end)
			if successHl and hl then
				pv.Highlight = hl
			end
		else
			pv.Highlight.Enabled = true
			pv.Highlight.FillColor = fillColor
			pv.Highlight.OutlineColor = outlineColor
			pv.Highlight.FillTransparency = fillTransparency
			pv.Highlight.OutlineTransparency = outlineTransparency
		end
	elseif pv.Highlight then
		pv.Highlight.Enabled = false
	end
	
	-- 2D Calculations
	local rootPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
	if not onScreen or not hasDrawing then
		if pv.BoxOutline then pv.BoxOutline.Visible = false end
		if pv.Box then pv.Box.Visible = false end
		if pv.HealthBarBg then pv.HealthBarBg.Visible = false end
		if pv.HealthBarFill then pv.HealthBarFill.Visible = false end
		if pv.Tracer then pv.Tracer.Visible = false end
		if pv.DistanceTag then pv.DistanceTag.Visible = false end
		for _, bone in ipairs(pv.Bones) do bone.Visible = false end
		return
	end
	
	-- Bounding Box size estimation
	local head = character:FindFirstChild("Head") :: BasePart?
	local headPos = if head then Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0)) else Vector3.new(rootPos.X, rootPos.Y - 30, 0)
	local legPos = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
	
	local boxHeight = math.abs(legPos.Y - headPos.Y)
	local boxWidth = boxHeight * 0.65
	local boxX = rootPos.X - (boxWidth / 2)
	local boxY = headPos.Y
	local boxSize = Vector2.new(boxWidth, boxHeight)
	local boxPosition = Vector2.new(boxX, boxY)
	
	-- Render 2D Box & Box Outline
	if Visuals.Box2D then
		-- Render Box Outline (Secondary black Square behind box with Thickness = 3.5 for high contrast)
		if Visuals.BoxOutlines and pv.BoxOutline then
			pv.BoxOutline.Size = boxSize
			pv.BoxOutline.Position = boxPosition
			pv.BoxOutline.Thickness = 3.5
			pv.BoxOutline.Color = Color3.fromRGB(0, 0, 0)
			pv.BoxOutline.Visible = true
		elseif pv.BoxOutline then
			pv.BoxOutline.Visible = false
		end

		if pv.Box then
			pv.Box.Size = boxSize
			pv.Box.Position = boxPosition
			pv.Box.Thickness = 1.5
			pv.Box.Color = Visuals.BoxColor
			pv.Box.Visible = true
		end
	else
		if pv.Box then pv.Box.Visible = false end
		if pv.BoxOutline then pv.BoxOutline.Visible = false end
	end
	
	-- Render Health Bar next to 2D Box
	if Visuals.HealthBar and pv.HealthBarBg and pv.HealthBarFill then
		local barWidth = 3
		local barX = boxX - 6
		local healthRatio = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		local fillHeight = boxHeight * healthRatio
		
		pv.HealthBarBg.Size = Vector2.new(barWidth + 2, boxHeight + 2)
		pv.HealthBarBg.Position = Vector2.new(barX - 1, boxY - 1)
		pv.HealthBarBg.Visible = true
		
		pv.HealthBarFill.Size = Vector2.new(barWidth, fillHeight)
		pv.HealthBarFill.Position = Vector2.new(barX, boxY + (boxHeight - fillHeight))
		pv.HealthBarFill.Color = Color3.fromHSV(healthRatio * 0.33, 0.9, 0.9)
		pv.HealthBarFill.Visible = true
	else
		if pv.HealthBarBg then pv.HealthBarBg.Visible = false end
		if pv.HealthBarFill then pv.HealthBarFill.Visible = false end
	end
	
	-- Render Tracer with Origin Selector ("Bottom", "Center", "Mouse")
	if Visuals.Tracers and pv.Tracer then
		local tracerOrigin = Visuals.TracerOrigin or "Bottom"
		local fromPos: Vector2
		
		if tracerOrigin == "Center" then
			fromPos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
		elseif tracerOrigin == "Mouse" then
			local mousePos = UserInputService:GetMouseLocation()
			fromPos = Vector2.new(mousePos.X, mousePos.Y)
		else -- "Bottom" or default fallback
			fromPos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
		end
		
		pv.Tracer.From = fromPos
		pv.Tracer.To = Vector2.new(rootPos.X, rootPos.Y)
		pv.Tracer.Color = Visuals.TracerColor
		pv.Tracer.Visible = true
	elseif pv.Tracer then
		pv.Tracer.Visible = false
	end
	
	-- Render Distance Tag (3D stud distance calculation: math.floor((pos - myPos).Magnitude) .. "m")
	if Visuals.Distance and pv.DistanceTag then
		local myRoot = if LocalPlayer.Character then (LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or LocalPlayer.Character:FindFirstChild("Torso") or LocalPlayer.Character:FindFirstChild("UpperTorso")) :: BasePart? else nil
		local myPos = if myRoot then myRoot.Position else Camera.CFrame.Position
		local targetPos = rootPart.Position
		local dist = math.floor((targetPos - myPos).Magnitude)
		
		pv.DistanceTag.Text = dist .. "m"
		pv.DistanceTag.Position = Vector2.new(boxX + (boxWidth / 2), boxY + boxHeight + 2)
		pv.DistanceTag.Color = Visuals.DistanceColor or Color3.fromRGB(240, 240, 240)
		pv.DistanceTag.Visible = true
	elseif pv.DistanceTag then
		pv.DistanceTag.Visible = false
	end
	
	-- Render Skeleton ESP
	if Visuals.Skeleton and #pv.Bones > 0 then
		local bonePairs = {
			{"Head", "UpperTorso"},
			{"UpperTorso", "LowerTorso"},
			{"UpperTorso", "LeftUpperArm"},
			{"LeftUpperArm", "LeftLowerArm"},
			{"LeftLowerArm", "LeftHand"},
			{"UpperTorso", "RightUpperArm"},
			{"RightUpperArm", "RightLowerArm"},
			{"RightLowerArm", "RightHand"},
			{"LowerTorso", "LeftUpperLeg"},
			{"LeftUpperLeg", "LeftLowerLeg"},
			{"LeftLowerLeg", "LeftFoot"},
			{"LowerTorso", "RightUpperLeg"},
			{"RightUpperLeg", "RightLowerLeg"},
			{"RightLowerLeg", "RightFoot"}
		}
		
		for idx, pair in ipairs(bonePairs) do
			local boneLine = pv.Bones[idx]
			if boneLine then
				local p1 = character:FindFirstChild(pair[1]) :: BasePart?
				local p2 = character:FindFirstChild(pair[2]) :: BasePart?
				if p1 and p2 then
					local v1, on1 = Camera:WorldToViewportPoint(p1.Position)
					local v2, on2 = Camera:WorldToViewportPoint(p2.Position)
					if on1 and on2 then
						boneLine.From = Vector2.new(v1.X, v1.Y)
						boneLine.To = Vector2.new(v2.X, v2.Y)
						boneLine.Color = Visuals.SkeletonColor
						boneLine.Visible = true
					else
						boneLine.Visible = false
					end
				else
					boneLine.Visible = false
				end
			end
		end
	else
		for _, bone in ipairs(pv.Bones) do
			bone.Visible = false
		end
	end
end

-- Main render loop
RunService.RenderStepped:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local pv = playerVisuals[player]
			if not pv then
				pv = createPlayerVisual(player)
				playerVisuals[player] = pv
			end
			updatePlayer(player, pv)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player)
	local pv = playerVisuals[player]
	if pv then
		cleanPlayerVisual(pv)
		playerVisuals[player] = nil
	end
end)

function Visuals.cleanup()
	for player, pv in pairs(playerVisuals) do
		cleanPlayerVisual(pv)
	end
	playerVisuals = {}
end

return Visuals
