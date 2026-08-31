--!strict
--[=[
    ✦ Visuals Rendering Engine ✦
    High-performance 2D ESP Boxes, Health Bars, Tracers, Skeletons, and 3D Highlights.
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	Camera = Workspace.CurrentCamera or Camera
end)

local Visuals = {
	Box2D = false,
	HealthBar = false,
	Tracers = false,
	Skeleton = false,
	Chams = false,
	ChamsTransparency = 0.5,
	BoxColor = Color3.fromRGB(55, 175, 245),
	TracerColor = Color3.fromRGB(255, 255, 255),
	SkeletonColor = Color3.fromRGB(255, 200, 50),
	ChamsColor = Color3.fromRGB(55, 175, 245)
}

-- Registry of created visual elements per player
type PlayerVisual = {
	Highlight: Highlight?,
	Box: any?,
	HealthBarBg: any?,
	HealthBarFill: any?,
	Tracer: any?,
	Bones: {any}
}

local playerVisuals: {[Player]: PlayerVisual} = {}
local hasDrawing = (typeof(Drawing) == "table" and typeof(Drawing.new) == "function")

local function createPlayerVisual(player: Player): PlayerVisual
	local pv: PlayerVisual = {
		Highlight = nil,
		Box = nil,
		HealthBarBg = nil,
		HealthBarFill = nil,
		Tracer = nil,
		Bones = {}
	}
	
	if hasDrawing then
		-- 2D Box
		local box = Drawing.new("Square")
		box.Thickness = 1.5
		box.Filled = false
		box.Color = Visuals.BoxColor
		box.Visible = false
		pv.Box = box
		
		-- Health Bar BG
		local hbBg = Drawing.new("Square")
		hbBg.Thickness = 1
		hbBg.Filled = true
		hbBg.Color = Color3.fromRGB(15, 15, 15)
		hbBg.Visible = false
		pv.HealthBarBg = hbBg
		
		-- Health Bar Fill
		local hbFill = Drawing.new("Square")
		hbFill.Thickness = 1
		hbFill.Filled = true
		hbFill.Color = Color3.fromRGB(50, 220, 80)
		hbFill.Visible = false
		pv.HealthBarFill = hbFill
		
		-- Tracer line
		local tracer = Drawing.new("Line")
		tracer.Thickness = 1.2
		tracer.Color = Visuals.TracerColor
		tracer.Visible = false
		pv.Tracer = tracer
		
		-- Skeleton bones (14 bone segments)
		for i = 1, 14 do
			local bone = Drawing.new("Line")
			bone.Thickness = 1.2
			bone.Color = Visuals.SkeletonColor
			bone.Visible = false
			table.insert(pv.Bones, bone)
		end
	end
	
	return pv
end

local function cleanPlayerVisual(pv: PlayerVisual)
	if pv.Highlight then
		pv.Highlight:Destroy()
		pv.Highlight = nil
	end
	if pv.Box then pv.Box:Remove() end
	if pv.HealthBarBg then pv.HealthBarBg:Remove() end
	if pv.HealthBarFill then pv.HealthBarFill:Remove() end
	if pv.Tracer then pv.Tracer:Remove() end
	for _, bone in ipairs(pv.Bones) do
		bone:Remove()
	end
	pv.Bones = {}
end

local function updatePlayer(player: Player, pv: PlayerVisual)
	if player == LocalPlayer then return end
	local character = player.Character
	if not character then
		if pv.Highlight then pv.Highlight.Enabled = false end
		if pv.Box then pv.Box.Visible = false end
		if pv.HealthBarBg then pv.HealthBarBg.Visible = false end
		if pv.HealthBarFill then pv.HealthBarFill.Visible = false end
		if pv.Tracer then pv.Tracer.Visible = false end
		for _, bone in ipairs(pv.Bones) do bone.Visible = false end
		return
	end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") :: BasePart?
	
	if not humanoid or not rootPart or humanoid.Health <= 0 then
		if pv.Highlight then pv.Highlight.Enabled = false end
		if pv.Box then pv.Box.Visible = false end
		if pv.HealthBarBg then pv.HealthBarBg.Visible = false end
		if pv.HealthBarFill then pv.HealthBarFill.Visible = false end
		if pv.Tracer then pv.Tracer.Visible = false end
		for _, bone in ipairs(pv.Bones) do bone.Visible = false end
		return
	end
	
	-- 3D Chams / Highlight
	if Visuals.Chams then
		if not pv.Highlight or pv.Highlight.Parent ~= character then
			if pv.Highlight then pv.Highlight:Destroy() end
			local hl = Instance.new("Highlight")
			hl.Name = "ModularChams"
			hl.FillColor = Visuals.ChamsColor
			hl.OutlineColor = Color3.fromRGB(255, 255, 255)
			hl.FillTransparency = Visuals.ChamsTransparency
			hl.OutlineTransparency = 0.2
			hl.Adornee = character
			hl.Parent = character
			pv.Highlight = hl
		else
			pv.Highlight.Enabled = true
			pv.Highlight.FillColor = Visuals.ChamsColor
			pv.Highlight.FillTransparency = Visuals.ChamsTransparency
		end
	elseif pv.Highlight then
		pv.Highlight.Enabled = false
	end
	
	-- 2D Calculations
	local rootPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
	if not onScreen or not hasDrawing then
		if pv.Box then pv.Box.Visible = false end
		if pv.HealthBarBg then pv.HealthBarBg.Visible = false end
		if pv.HealthBarFill then pv.HealthBarFill.Visible = false end
		if pv.Tracer then pv.Tracer.Visible = false end
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
	
	-- Render 2D Box
	if Visuals.Box2D and pv.Box then
		pv.Box.Size = Vector2.new(boxWidth, boxHeight)
		pv.Box.Position = Vector2.new(boxX, boxY)
		pv.Box.Color = Visuals.BoxColor
		pv.Box.Visible = true
	elseif pv.Box then
		pv.Box.Visible = false
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
	
	-- Render Tracer
	if Visuals.Tracers and pv.Tracer then
		local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
		pv.Tracer.From = screenCenter
		pv.Tracer.To = Vector2.new(rootPos.X, rootPos.Y)
		pv.Tracer.Color = Visuals.TracerColor
		pv.Tracer.Visible = true
	elseif pv.Tracer then
		pv.Tracer.Visible = false
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

return Visuals
