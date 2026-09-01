if type(cleardrawcache) == "function" then
	pcall(cleardrawcache)
end
--!strict
--[=[
    ✦ Visuals Rendering Engine ✦
    High-performance 2D ESP Boxes with Outlines, Health Bars, Tracers with Origin Selector,
    Distance Tags, Skeletons, and 3D Highlight Chams with customizable colors.
    Optimized with centralized DrawingPool, cached character part hierarchies,
    viewport dimension caching, and zero per-frame heap table allocations.
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

-- Module connections registry for clean unloading
local moduleConnections: {RBXScriptConnection} = {}

local camConn = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	Camera = Workspace.CurrentCamera or Camera
end)
table.insert(moduleConnections, camConn)

-- Constant Bone Hierarchy Table (Module Scope - 0 Heap Allocations per frame)
local BONE_PAIRS: {{string}} = {
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

local Visuals = {
	-- 2D & 3D Name Tag Settings
	Names = true,
	NameColor = Color3.fromRGB(255, 255, 255),
	ShowDisplayNames = true,

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

-- Centralized Drawing Object Pool
local DrawingPool: {[string]: {any}} = {
	Square = {},
	Line = {},
	Text = {},
	Circle = {}
}

local hasDrawing = (typeof(Drawing) == "table" and typeof(Drawing.new) == "function")

-- Public Pool Interface
function Visuals.acquireDrawing(drawingType: string): any?
	local pool = DrawingPool[drawingType]
	if pool and #pool > 0 then
		local obj = table.remove(pool)
		if obj then
			pcall(function()
				obj.Visible = false
			end)
			return obj
		end
	end
	
	if hasDrawing then
		local success, obj = pcall(function()
			return Drawing.new(drawingType)
		end)
		if success and obj then
			pcall(function()
				obj.Visible = false
			end)
			return obj
		end
	end
	return nil
end

function Visuals.releaseDrawing(drawingTypeOrObj: any, maybeObj: any?)
	local drawingType: string?
	local obj: any?
	
	if typeof(drawingTypeOrObj) == "string" then
		drawingType = drawingTypeOrObj
		obj = maybeObj
	else
		obj = drawingTypeOrObj
		if typeof(maybeObj) == "string" then
			drawingType = maybeObj
		end
	end
	
	if not obj then return end
	
	pcall(function()
		obj.Visible = false
	end)
	
	if drawingType and DrawingPool[drawingType] then
		table.insert(DrawingPool[drawingType], obj)
	else
		-- Auto-detect drawing type from object properties if not supplied
		local detectedType = "Square"
		local successText, _ = pcall(function() return obj.Text end)
		if successText then
			detectedType = "Text"
		else
			local successRadius, _ = pcall(function() return obj.Radius end)
			if successRadius then
				detectedType = "Circle"
			else
				local successFrom, _ = pcall(function() return obj.From end)
				if successFrom then
					detectedType = "Line"
				end
			end
		end
		if DrawingPool[detectedType] then
			table.insert(DrawingPool[detectedType], obj)
		end
	end
end

-- Cached Character Parts Structure
type CachedPlayerParts = {
	Character: Model?,
	Humanoid: Humanoid?,
	RootPart: BasePart?,
	Head: BasePart?,
	Torso: BasePart?,
	UpperTorso: BasePart?,
	LowerTorso: BasePart?,
	BoneMap: {[string]: BasePart?},
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
	NameTag: any?,
	Bones: {any},
	LastDistance: number?,
	Parts: CachedPlayerParts?,
	CharAddedConn: RBXScriptConnection?,
	CharRemovingConn: RBXScriptConnection?,
	ChildAddedConn: RBXScriptConnection?,
}

local playerVisuals: {[Player]: PlayerVisual} = {}
local wasAnyVisualEnabled = false

local function isAnyVisualEnabled(): boolean
	return Visuals.Box2D or Visuals.HealthBar or Visuals.Tracers or Visuals.Distance or Visuals.Skeleton or Visuals.Chams or (Visuals.Names and (Visuals.Box2D or Visuals.Chams))
end

local function cachePlayerParts(pv: PlayerVisual, character: Model?)
	if not character then
		pv.Parts = nil
		return
	end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso") :: BasePart?
	local head = character:FindFirstChild("Head") :: BasePart?
	local torso = character:FindFirstChild("Torso") :: BasePart?
	local upperTorso = character:FindFirstChild("UpperTorso") :: BasePart?
	local lowerTorso = character:FindFirstChild("LowerTorso") :: BasePart?
	
	local boneMap: {[string]: BasePart?} = {}
	for _, pair in ipairs(BONE_PAIRS) do
		local p1Name = pair[1]
		local p2Name = pair[2]
		if not boneMap[p1Name] then
			boneMap[p1Name] = character:FindFirstChild(p1Name) :: BasePart?
		end
		if not boneMap[p2Name] then
			boneMap[p2Name] = character:FindFirstChild(p2Name) :: BasePart?
		end
	end
	
	-- Fallback resolution for R6 character rigs
	if not boneMap["UpperTorso"] and torso then
		boneMap["UpperTorso"] = torso
		boneMap["LowerTorso"] = torso
	end
	if not boneMap["LeftUpperArm"] then
		boneMap["LeftUpperArm"] = character:FindFirstChild("Left Arm") :: BasePart?
	end
	if not boneMap["RightUpperArm"] then
		boneMap["RightUpperArm"] = character:FindFirstChild("Right Arm") :: BasePart?
	end
	if not boneMap["LeftUpperLeg"] then
		boneMap["LeftUpperLeg"] = character:FindFirstChild("Left Leg") :: BasePart?
	end
	if not boneMap["RightUpperLeg"] then
		boneMap["RightUpperLeg"] = character:FindFirstChild("Right Leg") :: BasePart?
	end
	
	pv.Parts = {
		Character = character,
		Humanoid = humanoid,
		RootPart = rootPart,
		Head = head,
		Torso = torso,
		UpperTorso = upperTorso,
		LowerTorso = lowerTorso,
		BoneMap = boneMap,
	}
end

local function hideAll(pv: PlayerVisual)
	if pv.Highlight then pv.Highlight.Enabled = false end
	if pv.BoxOutline then pv.BoxOutline.Visible = false end
	if pv.Box then pv.Box.Visible = false end
	if pv.HealthBarBg then pv.HealthBarBg.Visible = false end
	if pv.HealthBarFill then pv.HealthBarFill.Visible = false end
	if pv.Tracer then pv.Tracer.Visible = false end
	if pv.DistanceTag then pv.DistanceTag.Visible = false end
	if pv.NameTag then pv.NameTag.Visible = false end
	for _, bone in ipairs(pv.Bones) do bone.Visible = false end
end

local function createPlayerVisual(player: Player): PlayerVisual
	local pv: PlayerVisual = {
		Highlight = nil,
		BoxOutline = nil,
		Box = nil,
		HealthBarBg = nil,
		HealthBarFill = nil,
		Tracer = nil,
		DistanceTag = nil,
		Bones = {},
		LastDistance = nil,
		Parts = nil,
		CharAddedConn = nil,
		CharRemovingConn = nil,
		ChildAddedConn = nil,
	}
	
	if hasDrawing then
		-- Box Outline (Secondary black square for high contrast, Thickness = 3.5)
		local boxOutline = Visuals.acquireDrawing("Square")
		if boxOutline then
			pcall(function()
				boxOutline.Thickness = 3.5
				boxOutline.Filled = false
				boxOutline.Color = Color3.fromRGB(0, 0, 0)
				boxOutline.Visible = false
				boxOutline.Transparency = 1
			end)
			pv.BoxOutline = boxOutline
		end

		-- 2D Box
		local box = Visuals.acquireDrawing("Square")
		if box then
			pcall(function()
				box.Thickness = 1.5
				box.Filled = false
				box.Color = Visuals.BoxColor
				box.Visible = false
				box.Transparency = 1
			end)
			pv.Box = box
		end
		
		-- Health Bar BG
		local hbBg = Visuals.acquireDrawing("Square")
		if hbBg then
			pcall(function()
				hbBg.Thickness = 1
				hbBg.Filled = true
				hbBg.Color = Color3.fromRGB(15, 15, 15)
				hbBg.Visible = false
				hbBg.Transparency = 1
			end)
			pv.HealthBarBg = hbBg
		end
		
		-- Health Bar Fill
		local hbFill = Visuals.acquireDrawing("Square")
		if hbFill then
			pcall(function()
				hbFill.Thickness = 1
				hbFill.Filled = true
				hbFill.Color = Color3.fromRGB(50, 220, 80)
				hbFill.Visible = false
				hbFill.Transparency = 1
			end)
			pv.HealthBarFill = hbFill
		end
		
		-- Tracer line
		local tracer = Visuals.acquireDrawing("Line")
		if tracer then
			pcall(function()
				tracer.Thickness = 1.2
				tracer.Color = Visuals.TracerColor
				tracer.Visible = false
				tracer.Transparency = 1
			end)
			pv.Tracer = tracer
		end
		
		-- Distance tag (3D stud distance text positioned below bounding box)
		local distTag = Visuals.acquireDrawing("Text")
		if distTag then
			pcall(function()
				distTag.Size = 13
				distTag.Center = true
				distTag.Outline = true
				distTag.OutlineColor = Color3.fromRGB(0, 0, 0)
				distTag.Color = Visuals.DistanceColor
				distTag.Visible = false
				distTag.Transparency = 1
			end)
			pv.DistanceTag = distTag
		end

		-- Player Name Tag (Positioned above head / bounding box)
		local nameTag = Visuals.acquireDrawing("Text")
		if nameTag then
			pcall(function()
				nameTag.Size = 13
				nameTag.Center = true
				nameTag.Outline = true
				nameTag.OutlineColor = Color3.fromRGB(0, 0, 0)
				nameTag.Color = Visuals.NameColor or Color3.fromRGB(255, 255, 255)
				nameTag.Visible = false
				nameTag.Transparency = 1
				nameTag.Text = if player.DisplayName ~= player.Name then string.format("%s (@%s)", player.DisplayName, player.Name) else player.Name
			end)
			pv.NameTag = nameTag
		end
		
		-- Skeleton bones (14 bone segments)
		for i = 1, #BONE_PAIRS do
			local bone = Visuals.acquireDrawing("Line")
			if bone then
				pcall(function()
					bone.Thickness = 1.2
					bone.Color = Visuals.SkeletonColor
					bone.Visible = false
					bone.Transparency = 1
				end)
				table.insert(pv.Bones, bone)
			end
		end
	end
	
	-- Cache character parts and listen for character lifecycle
	if player.Character then
		cachePlayerParts(pv, player.Character)
	end
	
	pv.CharAddedConn = player.CharacterAdded:Connect(function(char)
		cachePlayerParts(pv, char)
		if pv.ChildAddedConn then
			pv.ChildAddedConn:Disconnect()
			pv.ChildAddedConn = nil
		end
		pv.ChildAddedConn = char.ChildAdded:Connect(function()
			if not pv.Parts or not pv.Parts.RootPart or not pv.Parts.Humanoid then
				cachePlayerParts(pv, char)
			end
		end)
	end)
	
	pv.CharRemovingConn = player.CharacterRemoving:Connect(function()
		pv.Parts = nil
		pv.LastDistance = nil
		if pv.ChildAddedConn then
			pv.ChildAddedConn:Disconnect()
			pv.ChildAddedConn = nil
		end
		hideAll(pv)
	end)
	
	return pv
end

local function cleanPlayerVisual(pv: PlayerVisual)
	if pv.CharAddedConn then
		pv.CharAddedConn:Disconnect()
		pv.CharAddedConn = nil
	end
	if pv.CharRemovingConn then
		pv.CharRemovingConn:Disconnect()
		pv.CharRemovingConn = nil
	end
	if pv.ChildAddedConn then
		pv.ChildAddedConn:Disconnect()
		pv.ChildAddedConn = nil
	end
	
	if pv.Highlight then
		pcall(function() pv.Highlight:Destroy() end)
		pv.Highlight = nil
	end
	
	if pv.BoxOutline then
		Visuals.releaseDrawing("Square", pv.BoxOutline)
		pv.BoxOutline = nil
	end
	if pv.Box then
		Visuals.releaseDrawing("Square", pv.Box)
		pv.Box = nil
	end
	if pv.HealthBarBg then
		Visuals.releaseDrawing("Square", pv.HealthBarBg)
		pv.HealthBarBg = nil
	end
	if pv.HealthBarFill then
		Visuals.releaseDrawing("Square", pv.HealthBarFill)
		pv.HealthBarFill = nil
	end
	if pv.Tracer then
		Visuals.releaseDrawing("Line", pv.Tracer)
		pv.Tracer = nil
	end
	if pv.DistanceTag then
		Visuals.releaseDrawing("Text", pv.DistanceTag)
		pv.DistanceTag = nil
	end
	if pv.NameTag then
		Visuals.releaseDrawing("Text", pv.NameTag)
		pv.NameTag = nil
	end
	for _, bone in ipairs(pv.Bones) do
		Visuals.releaseDrawing("Line", bone)
	end
	pv.Bones = {}
	pv.Parts = nil
	pv.LastDistance = nil
end

local function updatePlayer(
	player: Player,
	pv: PlayerVisual,
	screenCenter: Vector2,
	screenBottom: Vector2,
	mousePos: Vector2?,
	myRootPart: BasePart?
)
	if player == LocalPlayer then return end
	local character = player.Character
	if not character then
		hideAll(pv)
		return
	end
	
	-- Verify and update cached character parts if needed
	local parts = pv.Parts
	if not parts or parts.Character ~= character or not parts.RootPart or not parts.Humanoid then
		cachePlayerParts(pv, character)
		parts = pv.Parts
	end
	
	if not parts or not parts.Humanoid or not parts.RootPart or parts.Humanoid.Health <= 0 then
		hideAll(pv)
		return
	end
	
	local humanoid = parts.Humanoid
	local rootPart = parts.RootPart
	
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
		if pv.NameTag then pv.NameTag.Visible = false end
		for _, bone in ipairs(pv.Bones) do bone.Visible = false end
		return
	end
	
	-- Bounding Box size estimation
	local head = parts.Head
	local headPos = if head then Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0)) else Vector3.new(rootPos.X, rootPos.Y - 30, 0)
	local legPos = Camera:WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
	
	local boxHeight = math.abs(legPos.Y - headPos.Y)
	local boxWidth = boxHeight * 0.65
	local boxX = rootPos.X - (boxWidth * 0.5)
	local boxY = headPos.Y
	local boxSize = Vector2.new(boxWidth, boxHeight)
	local boxPosition = Vector2.new(boxX, boxY)
	
	-- Render Player Name Tag (Above Head / Box for both 2D ESP & 3D Chams)
	local shouldShowNames = Visuals.Names and (Visuals.Box2D or Visuals.Chams)
	if shouldShowNames and pv.NameTag then
		pv.NameTag.Position = Vector2.new(boxX + (boxWidth * 0.5), boxY - 16)
		pv.NameTag.Color = Visuals.NameColor or Color3.fromRGB(255, 255, 255)
		local nameText = if Visuals.ShowDisplayNames and player.DisplayName ~= player.Name then string.format("%s (@%s)", player.DisplayName, player.Name) else player.DisplayName
		if pv.NameTag.Text ~= nameText then
			pv.NameTag.Text = nameText
		end
		pv.NameTag.Visible = true
	elseif pv.NameTag then
		pv.NameTag.Visible = false
	end

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
			fromPos = screenCenter
		elseif tracerOrigin == "Mouse" then
			fromPos = mousePos or screenCenter
		else -- "Bottom" or default fallback
			fromPos = screenBottom
		end
		
		pv.Tracer.From = fromPos
		pv.Tracer.To = Vector2.new(rootPos.X, rootPos.Y)
		pv.Tracer.Color = Visuals.TracerColor
		pv.Tracer.Visible = true
	elseif pv.Tracer then
		pv.Tracer.Visible = false
	end
	
	-- Render Distance Tag (3D stud distance calculation with delta threshold cache)
	if Visuals.Distance and pv.DistanceTag then
		local myPos = if myRootPart then myRootPart.Position else Camera.CFrame.Position
		local targetPos = rootPart.Position
		local dist = math.floor((targetPos - myPos).Magnitude)
		
		if not pv.LastDistance or math.abs(dist - pv.LastDistance) >= 1 then
			pv.LastDistance = dist
			pv.DistanceTag.Text = tostring(dist) .. "m"
		end
		
		pv.DistanceTag.Position = Vector2.new(boxX + (boxWidth * 0.5), boxY + boxHeight + 2)
		pv.DistanceTag.Color = Visuals.DistanceColor or Color3.fromRGB(240, 240, 240)
		pv.DistanceTag.Visible = true
	elseif pv.DistanceTag then
		pv.DistanceTag.Visible = false
	end
	
	-- Render Skeleton ESP
	if Visuals.Skeleton and #pv.Bones > 0 and parts then
		local boneMap = parts.BoneMap
		for idx, pair in ipairs(BONE_PAIRS) do
			local boneLine = pv.Bones[idx]
			if boneLine then
				local p1 = boneMap[pair[1]]
				local p2 = boneMap[pair[2]]
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

-- Main RenderStepped render loop
local renderConn = RunService.RenderStepped:Connect(function()
	-- Master Early-Return Gate: Skip loop entirely if all visual modules are disabled
	if not isAnyVisualEnabled() then
		if wasAnyVisualEnabled then
			wasAnyVisualEnabled = false
			for _, pv in pairs(playerVisuals) do
				hideAll(pv)
			end
		end
		return
	end
	wasAnyVisualEnabled = true
	
	-- Cache viewport dimensions and origin vectors once per frame
	local viewportSize = Camera.ViewportSize
	local screenCenter = Vector2.new(viewportSize.X * 0.5, viewportSize.Y * 0.5)
	local screenBottom = Vector2.new(viewportSize.X * 0.5, viewportSize.Y)
	local mousePos: Vector2? = nil
	if Visuals.Tracers and Visuals.TracerOrigin == "Mouse" then
		mousePos = UserInputService:GetMouseLocation()
	end
	
	local localChar = LocalPlayer.Character
	local myRootPart: BasePart? = if localChar then (localChar:FindFirstChild("HumanoidRootPart") or localChar:FindFirstChild("Torso") or localChar:FindFirstChild("UpperTorso")) :: BasePart? else nil
	
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local pv = playerVisuals[player]
			if not pv then
				pv = createPlayerVisual(player)
				playerVisuals[player] = pv
			end
			updatePlayer(player, pv, screenCenter, screenBottom, mousePos, myRootPart)
		end
	end
end)
table.insert(moduleConnections, renderConn)

local playerRemConn = Players.PlayerRemoving:Connect(function(player)
	local pv = playerVisuals[player]
	if pv then
		cleanPlayerVisual(pv)
		playerVisuals[player] = nil
	end
end)
table.insert(moduleConnections, playerRemConn)

-- Module Unload & Resource Cleanup
function Visuals.removeAllVisuals()
	Visuals.Box2D = false
	Visuals.BoxOutlines = false
	Visuals.HealthBar = false
	Visuals.Tracers = false
	Visuals.Distance = false
	Visuals.Skeleton = false
	Visuals.Chams = false

	for player, pv in pairs(playerVisuals) do
		cleanPlayerVisual(pv)
	end
	table.clear(playerVisuals)

	-- Purge highlights and visual adornments across character models
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char then
			for _, desc in ipairs(char:GetDescendants()) do
				if desc:IsA("Highlight") and (desc.Name == "ModularChams" or desc.Name:find("Chams") or desc.Name:find("ESP")) then
					pcall(function() desc:Destroy() end)
				end
			end
		end
	end

	-- Drain Drawing Pool
	for typeName, pool in pairs(DrawingPool) do
		for _, obj in ipairs(pool) do
			pcall(function() obj:Remove() end)
		end
		DrawingPool[typeName] = {}
	end
end

-- Automatic purge on script execution
Visuals.removeAllVisuals()

function Visuals.cleanup()
	-- 1. Clean and release all player visuals
	for player, pv in pairs(playerVisuals) do
		cleanPlayerVisual(pv)
	end
	playerVisuals = {}
	
	-- 2. Drain and permanently remove all pooled Drawing instances
	for typeName, pool in pairs(DrawingPool) do
		for _, obj in ipairs(pool) do
			pcall(function()
				obj:Remove()
			end)
		end
		DrawingPool[typeName] = {}
	end
	
	-- 3. Disconnect all module-level connections
	for _, conn in ipairs(moduleConnections) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	moduleConnections = {}
	wasAnyVisualEnabled = false
end

return Visuals
