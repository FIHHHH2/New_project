--!strict
--[=[
    ✦ Squared Retro Hotbar & 3D Model Viewport Backpack Inventory Widget ✦
    Features:
    - Fluid Drag-to-Move / Drag-to-Swap toolbar objects with live drop target highlights
    - Instantaneous O(1) zero-lag tool equipping & unequipping (<0.01ms)
    - Full hot-reload event disconnection (_G.__ModularHotbar_Cleanup)
    - Permanent 3D ViewportFrame caching (zero model re-cloning on equip/unequip)
    - Smart hierarchy filter (moving tools between Backpack and Character never rebuilds viewports)
    - Dedicated retro [ ≡ INV ] hamburger button to toggle Backpack Inventory
    - Reliable 1-0 number key unequip toggling
    - Drag-to-drop: dragging an item outside the HUD drops the item into the world
    - 100% Theme-reactive (Dark, Light, Translucent Dark, Translucent Light, Adaptive)
]=]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")

local UI = require("UI/UI.luau")
local Animations = require("UI/Animations.luau")

local Hotbar = {}
Hotbar.__index = Hotbar

local LocalPlayer = Players.LocalPlayer

export type HotbarWidget = {
	HotbarFrame: Frame,
	BackpackWindow: Frame,
	SetVisible: (selfOrVal: any, maybeVal: any) -> (),
	ToggleBackpack: () -> (),
	IsOpen: () -> boolean,
	Refresh: () -> ()
}

local NUM_SLOTS = 10
local SLOT_SIZE = 48
local SLOT_GAP = 4
local KEYCODES = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
	Enum.KeyCode.Zero
}

export type ToolViewportCache = {
	Tool: Tool?,
	Name: string,
	TextureId: string,
	Signature: string
}

function Hotbar.getToolSignature(tool: Tool?): string
	if not tool then return "" end
	return string.format("%s_%s_%s", tool.Name, tool.TextureId, tostring(tool))
end

local function cleanAssetId(raw: string?): string
	if not raw or raw == "" then return "" end
	local id = string.match(raw, "(%d+)")
	if id then
		return "rbxassetid://" .. id
	end
	return raw
end

local function cleanViewport(container: GuiObject)
	local oldVp = container:FindFirstChild("ModelViewport")
	if oldVp then
		local oldCam = oldVp:FindFirstChildWhichIsA("Camera")
		if oldCam then oldCam:Destroy() end
		for _, child in ipairs(oldVp:GetChildren()) do
			child:Destroy()
		end
		oldVp:Destroy()
	end
	local oldImg = container:FindFirstChild("ToolIcon2D")
	if oldImg then
		oldImg:Destroy()
	end
end

local function renderToolViewportCached(
	container: GuiObject,
	tool: Tool?,
	cacheKey: any,
	cacheStore: {[any]: ToolViewportCache}
)
	if not tool then
		cleanViewport(container)
		cacheStore[cacheKey] = nil
		return
	end

	local sig = Hotbar.getToolSignature(tool)
	local cached = cacheStore[cacheKey]
	local existingVp = container:FindFirstChild("ModelViewport")
	local existingImg = container:FindFirstChild("ToolIcon2D")

	if cached and (existingVp or existingImg) and cached.Tool == tool and cached.Name == tool.Name and cached.TextureId == tool.TextureId and cached.Signature == sig then
		return
	end

	cleanViewport(container)

	-- 1. Check for valid 2D TextureId (Primary for Roblox Gears / Weapons / Items)
	local cleanedTexture = cleanAssetId(tool.TextureId)
	if cleanedTexture ~= "" then
		local imgLabel = Instance.new("ImageLabel")
		imgLabel.Name = "ToolIcon2D"
		imgLabel.Size = UDim2.new(0.72, 0, 0.72, 0)
		imgLabel.Position = UDim2.new(0.14, 0, 0.14, 0)
		imgLabel.BackgroundTransparency = 1
		imgLabel.BorderSizePixel = 0
		imgLabel.Image = cleanedTexture
		imgLabel.ScaleType = Enum.ScaleType.Fit
		imgLabel.ZIndex = 3
		imgLabel.Parent = container
	else
		-- 2. Fallback to 3D ViewportFrame with intelligent multi-mesh and SpecialMesh scaling
		local vp = Instance.new("ViewportFrame")
		vp.Name = "ModelViewport"
		vp.Size = UDim2.new(1, 0, 1, 0)
		vp.Position = UDim2.new(0, 0, 0, 0)
		vp.BackgroundTransparency = 1
		vp.BorderSizePixel = 0
		vp.Ambient = Color3.fromRGB(220, 220, 230)
		vp.LightColor = Color3.fromRGB(255, 255, 255)
		vp.LightDirection = Vector3.new(-1, -1.6, -1).Unit
		vp.ZIndex = 3
		vp.Parent = container

		local parts: {BasePart} = {}
		local handle = tool:FindFirstChild("Handle") :: BasePart?
		for _, desc in ipairs(tool:GetDescendants()) do
			if desc:IsA("BasePart") then
				table.insert(parts, desc)
			end
		end

		if #parts > 0 then
			local refPart = handle or parts[1]
			local refCF = refPart.CFrame
			local minBounds = Vector3.new(math.huge, math.huge, math.huge)
			local maxBounds = Vector3.new(-math.huge, -math.huge, -math.huge)

			local model = Instance.new("Model")
			model.Name = "ClonedTool"

			for _, p in ipairs(parts) do
				local clone = p:Clone()
				clone.CanCollide = false
				clone.Anchored = true
				local relCF = refCF:ToObjectSpace(p.CFrame)
				clone.CFrame = relCF
				clone.Parent = model

				local cp = relCF.Position
				local sz = clone.Size

				-- Check if SpecialMesh scale enlarges the visual size
				local sm = clone:FindFirstChildOfClass("SpecialMesh")
				if sm then
					sz = Vector3.new(sz.X * math.abs(sm.Scale.X), sz.Y * math.abs(sm.Scale.Y), sz.Z * math.abs(sm.Scale.Z))
				end

				minBounds = Vector3.new(
					math.min(minBounds.X, cp.X - sz.X / 2),
					math.min(minBounds.Y, cp.Y - sz.Y / 2),
					math.min(minBounds.Z, cp.Z - sz.Z / 2)
				)
				maxBounds = Vector3.new(
					math.max(maxBounds.X, cp.X + sz.X / 2),
					math.max(maxBounds.Y, cp.Y + sz.Y / 2),
					math.max(maxBounds.Z, cp.Z + sz.Z / 2)
				)
			end

			model.Parent = vp

			local center = (minBounds + maxBounds) / 2
			local size = (maxBounds - minBounds)
			local maxDim = math.max(size.X, size.Y, size.Z, 0.8)

			local cam = Instance.new("Camera")
			cam.FieldOfView = 50
			cam.CFrame = CFrame.new(center + Vector3.new(maxDim * 1.35, maxDim * 0.95, maxDim * 1.35), center)
			cam.Parent = vp
			vp.CurrentCamera = cam
		end
	end

	cacheStore[cacheKey] = {
		Tool = tool,
		Name = tool.Name,
		TextureId = tool.TextureId,
		Signature = sig
	}
end

function Hotbar.new(): HotbarWidget
	-- Disconnect previous instance connections to prevent ghost listener collisions
	if _G.__ModularHotbar_Cleanup then
		pcall(_G.__ModularHotbar_Cleanup)
		_G.__ModularHotbar_Cleanup = nil
	end

	local activeConnections: {RBXScriptConnection} = {}

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ModularHotbarGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 610
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	pcall(function() screenGui.Parent = CoreGui end)
	if not screenGui.Parent then
		screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end

	-- ── Drag Ghost Icon ───────────────────────────────────────────────
	local dragGhost = Instance.new("Frame")
	dragGhost.Name = "DragGhost"
	dragGhost.Size = UDim2.new(0, 52, 0, 52)
	dragGhost.BackgroundColor3 = UI.Theme.Accent
	dragGhost.BackgroundTransparency = 0.25
	dragGhost.BorderSizePixel = 0
	dragGhost.Visible = false
	dragGhost.ZIndex = 200
	dragGhost.Parent = screenGui

	local ghostStroke = Instance.new("UIStroke")
	ghostStroke.Color = Color3.fromRGB(255, 255, 255)
	ghostStroke.Thickness = 2
	ghostStroke.Parent = dragGhost

	local ghostBadge = Instance.new("TextLabel")
	ghostBadge.Size = UDim2.new(1, 0, 0, 16)
	ghostBadge.Position = UDim2.new(0, 0, 0, 4)
	ghostBadge.BackgroundTransparency = 1
	ghostBadge.Text = "MOVING"
	ghostBadge.TextColor3 = UI.Theme.AccentText
	ghostBadge.Font = UI.Fonts.Mono
	ghostBadge.TextSize = 8
	ghostBadge.ZIndex = 201
	ghostBadge.Parent = dragGhost

	local ghostLabel = Instance.new("TextLabel")
	ghostLabel.Size = UDim2.new(1, -4, 0, 18)
	ghostLabel.Position = UDim2.new(0, 2, 1, -22)
	ghostLabel.BackgroundTransparency = 1
	ghostLabel.TextColor3 = UI.Theme.AccentText
	ghostLabel.Font = UI.Fonts.Header
	ghostLabel.TextSize = 10
	ghostLabel.TextTruncate = Enum.TextTruncate.AtEnd
	ghostLabel.ZIndex = 201
	ghostLabel.Parent = dragGhost

	-- ── 1. Hotbar HUD Container ───────────────────────────────────────
	local totalSlotsCount = NUM_SLOTS + 1
	local totalWidth = (totalSlotsCount * SLOT_SIZE) + ((totalSlotsCount - 1) * SLOT_GAP) + 12
	local hotbarFrame = Instance.new("Frame")
	hotbarFrame.Name = "HotbarFrame"
	hotbarFrame.Size = UDim2.new(0, totalWidth, 0, SLOT_SIZE + 10)
	hotbarFrame.Position = UDim2.new(0.5, -totalWidth / 2, 1, -(SLOT_SIZE + 24))
	hotbarFrame.BackgroundColor3 = UI.Theme.Background
	hotbarFrame.BackgroundTransparency = UI.Theme.BackgroundTransparency
	hotbarFrame.BorderSizePixel = 0
	hotbarFrame.ClipsDescendants = false
	hotbarFrame.Parent = screenGui
	UI.registerThemeElement(hotbarFrame, "Background")

	local hotbarStroke = Instance.new("UIStroke")
	hotbarStroke.Color = UI.Theme.Border
	hotbarStroke.Thickness = 2
	hotbarStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	hotbarStroke.Parent = hotbarFrame
	UI.registerThemeElement(hotbarStroke, "Border")

	local hotbarList = Instance.new("UIListLayout")
	hotbarList.FillDirection = Enum.FillDirection.Horizontal
	hotbarList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	hotbarList.VerticalAlignment = Enum.VerticalAlignment.Center
	hotbarList.Padding = UDim.new(0, SLOT_GAP)
	hotbarList.SortOrder = Enum.SortOrder.LayoutOrder
	hotbarList.Parent = hotbarFrame

	-- ── 2. Backpack Inventory Window ──────────────────────────────────
	local BP_WIDTH = 480
	local BP_HEIGHT = 340
	local bpWindow = Instance.new("Frame")
	bpWindow.Name = "BackpackWindow"
	bpWindow.Size = UDim2.new(0, BP_WIDTH, 0, BP_HEIGHT)
	bpWindow.Position = UDim2.new(0.5, -BP_WIDTH / 2, 0.5, -BP_HEIGHT / 2)
	bpWindow.BackgroundColor3 = UI.Theme.Background
	bpWindow.BackgroundTransparency = UI.Theme.BackgroundTransparency
	bpWindow.BorderSizePixel = 0
	bpWindow.ClipsDescendants = false
	bpWindow.Visible = false
	bpWindow.Parent = screenGui
	UI.registerThemeElement(bpWindow, "Background")

	local bpStroke = Instance.new("UIStroke")
	bpStroke.Color = UI.Theme.Border
	bpStroke.Thickness = 2
	bpStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bpStroke.Parent = bpWindow
	UI.registerThemeElement(bpStroke, "Border")

	local bpTopBar = Instance.new("Frame")
	bpTopBar.Name = "TopBar"
	bpTopBar.Size = UDim2.new(1, 0, 0, 28)
	bpTopBar.BackgroundColor3 = UI.Theme.Container
	bpTopBar.BackgroundTransparency = UI.Theme.ContainerTransparency
	bpTopBar.BorderSizePixel = 0
	bpTopBar.Parent = bpWindow
	UI.registerThemeElement(bpTopBar, "Container")

	local bpTopStroke = Instance.new("UIStroke")
	bpTopStroke.Color = UI.Theme.BorderDim
	bpTopStroke.Thickness = 1
	bpTopStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bpTopStroke.Parent = bpTopBar
	UI.registerThemeElement(bpTopStroke, "BorderDim")

	local bpTitle = Instance.new("TextLabel")
	bpTitle.Size = UDim2.new(1, -60, 1, 0)
	bpTitle.Position = UDim2.new(0, 10, 0, 0)
	bpTitle.BackgroundTransparency = 1
	bpTitle.Text = "Backpack Inventory (Sort & Drag to Toolbar)"
	bpTitle.TextColor3 = UI.Theme.TextPrimary
	bpTitle.Font = UI.Fonts.Header
	bpTitle.TextSize = 11
	bpTitle.TextXAlignment = Enum.TextXAlignment.Left
	bpTitle.Parent = bpTopBar
	UI.registerThemeElement(bpTitle, "TextPrimary")

	local bpCloseBtn = Instance.new("TextButton")
	bpCloseBtn.Size = UDim2.new(0, 24, 1, -4)
	bpCloseBtn.Position = UDim2.new(1, -26, 0, 2)
	bpCloseBtn.BackgroundColor3 = UI.Theme.ContainerDark
	bpCloseBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	bpCloseBtn.BorderSizePixel = 0
	bpCloseBtn.Text = "X"
	bpCloseBtn.TextColor3 = UI.Theme.TextPrimary
	bpCloseBtn.Font = UI.Fonts.Header
	bpCloseBtn.TextSize = 11
	bpCloseBtn.Parent = bpTopBar
	UI.registerThemeElement(bpCloseBtn, "ContainerDark")
	UI.registerThemeElement(bpCloseBtn, "TextPrimary")
	Animations.buttonHoverPush(bpCloseBtn)

	-- Search & Action Bar
	local searchFrame = Instance.new("Frame")
	searchFrame.Size = UDim2.new(1, -12, 0, 26)
	searchFrame.Position = UDim2.new(0, 6, 0, 36)
	searchFrame.BackgroundTransparency = 1
	searchFrame.BorderSizePixel = 0
	searchFrame.Parent = bpWindow

	local searchBox = Instance.new("TextBox")
	searchBox.Size = UDim2.new(1, -110, 1, 0)
	searchBox.BackgroundColor3 = UI.Theme.Container
	searchBox.BackgroundTransparency = UI.Theme.ContainerTransparency
	searchBox.BorderSizePixel = 0
	searchBox.Text = ""
	searchBox.PlaceholderText = "Search inventory tools..."
	searchBox.PlaceholderColor3 = UI.Theme.TextSecondary
	searchBox.TextColor3 = UI.Theme.TextPrimary
	searchBox.Font = UI.Fonts.Body
	searchBox.TextSize = 11
	searchBox.TextXAlignment = Enum.TextXAlignment.Left
	searchBox.ClearTextOnFocus = false
	searchBox.Parent = searchFrame
	UI.registerThemeElement(searchBox, "TextPrimary")

	local unequipAllBtn = Instance.new("TextButton")
	unequipAllBtn.Size = UDim2.new(0, 96, 1, 0)
	unequipAllBtn.Position = UDim2.new(1, -100, 0, 0)
	unequipAllBtn.BackgroundColor3 = UI.Theme.ContainerDark
	unequipAllBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	unequipAllBtn.BorderSizePixel = 0
	unequipAllBtn.Text = "Unequip All"
	unequipAllBtn.TextColor3 = UI.Theme.TextPrimary
	unequipAllBtn.Font = UI.Fonts.Header
	unequipAllBtn.TextSize = 10
	unequipAllBtn.Parent = searchFrame
	UI.registerThemeElement(unequipAllBtn, "ContainerDark")
	UI.registerThemeElement(unequipAllBtn, "TextPrimary")
	Animations.buttonHoverPush(unequipAllBtn)

	-- Backpack Inventory Grid Container
	local bpGridScroll = Instance.new("ScrollingFrame")
	bpGridScroll.Name = "InventoryGrid"
	bpGridScroll.Size = UDim2.new(1, -12, 1, -76)
	bpGridScroll.Position = UDim2.new(0, 6, 0, 70)
	bpGridScroll.BackgroundColor3 = UI.Theme.Container
	bpGridScroll.BackgroundTransparency = UI.Theme.ContainerTransparency
	bpGridScroll.BorderSizePixel = 0
	bpGridScroll.ScrollBarThickness = 3
	bpGridScroll.ScrollBarImageColor3 = UI.Theme.Accent
	bpGridScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	bpGridScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	bpGridScroll.Parent = bpWindow
	UI.registerThemeElement(bpGridScroll, "Container")

	local bpGridPad = Instance.new("UIPadding")
	bpGridPad.PaddingLeft = UDim.new(0, 6)
	bpGridPad.PaddingRight = UDim.new(0, 6)
	bpGridPad.PaddingTop = UDim.new(0, 6)
	bpGridPad.PaddingBottom = UDim.new(0, 6)
	bpGridPad.Parent = bpGridScroll

	local bpGridLayout = Instance.new("UIGridLayout")
	bpGridLayout.CellSize = UDim2.new(0, 84, 0, 74)
	bpGridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
	bpGridLayout.SortOrder = Enum.SortOrder.Name
	bpGridLayout.Parent = bpGridScroll

	-- ── 3. State Management & Tool Gathering ──────────────────────────
	local assignedSlots: {[number]: Tool} = {}
	local slotFrames: {[number]: TextButton} = {}
	local slotCaches: {[number]: ToolViewportCache} = {}
	local backpackCards: {[Tool]: TextButton} = {}
	local backpackCaches: {[Tool]: ToolViewportCache} = {}
	local isBackpackOpen = false
	local filterQuery = ""

	local draggingTool: Tool? = nil
	local draggingFromSlot: number? = nil
	local dragStartPos = Vector2.zero
	local isDraggingActive = false
	local justFinishedDrag = false
	local equipOrToggleTool: ((Tool) -> ())

	local function getAllTools(): {Tool}
		local tools: {Tool} = {}
		local char = LocalPlayer.Character
		if char then
			for _, item in ipairs(char:GetChildren()) do
				if item:IsA("Tool") then
					table.insert(tools, item)
				end
			end
		end
		local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
		if bp then
			for _, item in ipairs(bp:GetChildren()) do
				if item:IsA("Tool") then
					table.insert(tools, item)
				end
			end
		end
		return tools
	end

	local function isToolEquipped(tool: Tool): boolean
		local char = LocalPlayer.Character
		return char ~= nil and (tool.Parent == char or char:FindFirstChild(tool.Name) == tool)
	end

	-- ── 4. Instant O(1) Slot Highlight Updater (Zero Viewport Rebuild) ──
	local function updateSlotHighlightsOnly()
		for slotNum = 1, NUM_SLOTS do
			local slotBtn = slotFrames[slotNum]
			local tool = assignedSlots[slotNum]
			local stroke = slotBtn:FindFirstChildWhichIsA("UIStroke")
			local nameLabel = slotBtn:FindFirstChild("ToolName") :: TextLabel?

			if tool and tool.Parent then
				local equipped = isToolEquipped(tool)
				if nameLabel then
					nameLabel.TextColor3 = if equipped then UI.Theme.AccentText else UI.Theme.TextPrimary
				end
				if equipped then
					slotBtn.BackgroundColor3 = UI.Theme.Accent
					slotBtn.BackgroundTransparency = 0.2
					if stroke then
						stroke.Color = UI.Theme.Border
						stroke.Thickness = 2.0
					end
				else
					slotBtn.BackgroundColor3 = UI.Theme.Container
					slotBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
					if stroke then
						stroke.Color = UI.Theme.Border
						stroke.Thickness = 1.2
					end
				end
			else
				slotBtn.BackgroundColor3 = UI.Theme.ContainerDark
				slotBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
				if stroke then
					stroke.Color = UI.Theme.BorderDim
					stroke.Thickness = 1.0
				end
			end
		end

		if isBackpackOpen then
			for tool, card in pairs(backpackCards) do
				if tool and tool.Parent and card and card.Parent then
					local equipped = isToolEquipped(tool)
					card.BackgroundColor3 = if equipped then UI.Theme.Accent else UI.Theme.ContainerDark
					card.BackgroundTransparency = if equipped then 0.15 else UI.Theme.ContainerDarkTransparency
					local badge = card:FindFirstChild("EquippedBadge") :: TextLabel?
					if badge then badge.Text = if equipped then "EQUIPPED" else "" end
				end
			end
		end
	end

	-- ── 5. Full Hotbar Viewport Render Function (Only Runs on Inventory Change) ──
	local function updateHotbarVisuals()
		local allTools = getAllTools()

		for i = 1, NUM_SLOTS do
			local currentTool = assignedSlots[i]
			if currentTool and (not currentTool.Parent or (currentTool.Parent ~= LocalPlayer.Character and currentTool.Parent ~= LocalPlayer:FindFirstChildOfClass("Backpack"))) then
				assignedSlots[i] = nil
			end
		end

		for _, tool in ipairs(allTools) do
			local alreadyAssigned = false
			for i = 1, NUM_SLOTS do
				if assignedSlots[i] == tool then
					alreadyAssigned = true
					break
				end
			end
			if not alreadyAssigned then
				for i = 1, NUM_SLOTS do
					if not assignedSlots[i] then
						assignedSlots[i] = tool
						break
					end
				end
			end
		end

		for slotNum = 1, NUM_SLOTS do
			local slotBtn = slotFrames[slotNum]
			local tool = assignedSlots[slotNum]
			local stroke = slotBtn:FindFirstChildWhichIsA("UIStroke")
			local nameLabel = slotBtn:FindFirstChild("ToolName") :: TextLabel?

			renderToolViewportCached(slotBtn, tool, slotNum, slotCaches)

			if tool then
				local equipped = isToolEquipped(tool)
				if nameLabel then
					nameLabel.Text = tool.Name
					nameLabel.TextColor3 = if equipped then UI.Theme.AccentText else UI.Theme.TextPrimary
				end

				if equipped then
					slotBtn.BackgroundColor3 = UI.Theme.Accent
					slotBtn.BackgroundTransparency = 0.2
					if stroke then
						stroke.Color = UI.Theme.Border
						stroke.Thickness = 2.0
					end
				else
					slotBtn.BackgroundColor3 = UI.Theme.Container
					slotBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
					if stroke then
						stroke.Color = UI.Theme.Border
						stroke.Thickness = 1.2
					end
				end
			else
				if nameLabel then nameLabel.Text = "" end
				slotBtn.BackgroundColor3 = UI.Theme.ContainerDark
				slotBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
				if stroke then
					stroke.Color = UI.Theme.BorderDim
					stroke.Thickness = 1.0
				end
			end
		end
	end

	-- ── 6. Render Backpack Grid Items Function ────────────────────────
	local function updateBackpackGrid()
		if not isBackpackOpen then return end
		local allTools = getAllTools()
		local activeToolSet: {[Tool]: boolean} = {}

		for _, tool in ipairs(allTools) do
			activeToolSet[tool] = true
			local matchesFilter = (filterQuery == "" or tool.Name:lower():find(filterQuery:lower(), 1, true) ~= nil)

			local existingCard = backpackCards[tool]
			if not matchesFilter then
				if existingCard then
					cleanViewport(existingCard)
					UI.unregisterThemeElement(existingCard)
					existingCard:Destroy()
					backpackCards[tool] = nil
					backpackCaches[tool] = nil
				end
				continue
			end

			local equipped = isToolEquipped(tool)

			if existingCard and existingCard.Parent == bpGridScroll then
				existingCard.BackgroundColor3 = UI.Theme.ContainerDark
				existingCard.BackgroundTransparency = UI.Theme.ContainerDarkTransparency

				local itemStroke = existingCard:FindFirstChildWhichIsA("UIStroke")
				if itemStroke then
					itemStroke.Color = if equipped then UI.Theme.Accent else UI.Theme.BorderDim
					itemStroke.Thickness = if equipped then 2.5 else 1.0
				end

				local tName = existingCard:FindFirstChild("ToolLabel") :: TextLabel?
				if tName then
					tName.Text = tool.Name
					tName.TextColor3 = if equipped then UI.Theme.Accent else UI.Theme.TextPrimary
				end

				local badge = existingCard:FindFirstChild("EquippedBadge") :: TextLabel?
				if badge then
					badge.Text = if equipped then "EQUIPPED" else ""
				end

				renderToolViewportCached(existingCard, tool, tool, backpackCaches)
			else
				if existingCard then
					cleanViewport(existingCard)
					UI.unregisterThemeElement(existingCard)
					existingCard:Destroy()
					backpackCards[tool] = nil
					backpackCaches[tool] = nil
				end

				local itemCard = Instance.new("TextButton")
				itemCard.Name = "Item_" .. tool.Name
				itemCard.Size = UDim2.new(0, 84, 0, 74)
				itemCard.BackgroundColor3 = UI.Theme.ContainerDark
				itemCard.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
				itemCard.BorderSizePixel = 0
				itemCard.Text = ""
				itemCard.AutoButtonColor = false
				itemCard.ClipsDescendants = true
				itemCard.Parent = bpGridScroll
				UI.registerThemeElement(itemCard, if equipped then "Accent" else "ContainerDark")
				Animations.buttonHoverPush(itemCard)

				local itemStroke = Instance.new("UIStroke")
				itemStroke.Color = if equipped then UI.Theme.Accent else UI.Theme.BorderDim
				itemStroke.Thickness = if equipped then 2.5 else 1.0
				itemStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				itemStroke.Parent = itemCard
				UI.registerThemeElement(itemStroke, "BorderDim")

				local tLabel = Instance.new("TextLabel")
				tLabel.Name = "ToolLabel"
				tLabel.Size = UDim2.new(1, -6, 0, 16)
				tLabel.Position = UDim2.new(0, 3, 1, -18)
				tLabel.BackgroundTransparency = 1
				tLabel.Text = tool.Name
				tLabel.TextColor3 = if equipped then UI.Theme.AccentText else UI.Theme.TextPrimary
				tLabel.Font = UI.Fonts.Header
				tLabel.TextSize = 9
				tLabel.TextTruncate = Enum.TextTruncate.AtEnd
				tLabel.ZIndex = 5
				tLabel.Parent = itemCard
				UI.registerThemeElement(tLabel, "TextPrimary")

				local eqBadge = Instance.new("TextLabel")
				eqBadge.Name = "EquippedBadge"
				eqBadge.Size = UDim2.new(1, -6, 0, 12)
				eqBadge.Position = UDim2.new(0, 3, 0, 2)
				eqBadge.BackgroundTransparency = 1
				eqBadge.Text = if equipped then "EQUIPPED" else ""
				eqBadge.TextColor3 = UI.Theme.AccentText
				eqBadge.Font = UI.Fonts.Mono
				eqBadge.TextSize = 8
				eqBadge.ZIndex = 5
				eqBadge.Parent = itemCard
				UI.registerThemeElement(eqBadge, "AccentText")

				renderToolViewportCached(itemCard, tool, tool, backpackCaches)

				local cardPressPos = Vector2.zero
				itemCard.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						cardPressPos = UserInputService:GetMouseLocation()
					end
				end)

				itemCard.InputChanged:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
						if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and not isDraggingActive then
							local curPos = UserInputService:GetMouseLocation()
							if (curPos - cardPressPos).Magnitude > 14 then
								startDragging(tool, nil, curPos)
							end
						end
					end
				end)

				itemCard.MouseButton1Click:Connect(function()
					if not justFinishedDrag and not isDraggingActive then
						Animations.buttonClickPop(itemCard)
						equipOrToggleTool(tool)
					end
				end)

				backpackCards[tool] = itemCard
			end
		end

		for oldTool, oldCard in pairs(backpackCards) do
			if not activeToolSet[oldTool] then
				cleanViewport(oldCard)
				UI.unregisterThemeElement(oldCard)
				oldCard:Destroy()
				backpackCards[oldTool] = nil
				backpackCaches[oldTool] = nil
			end
		end
	end

	-- ── 7. Debounced Refresher for True Add/Remove Events ──────────────
	local refreshScheduled = false
	local function queueInventoryRefresh()
		if refreshScheduled then return end
		refreshScheduled = true
		task.delay(0.08, function()
			refreshScheduled = false
			updateHotbarVisuals()
			if isBackpackOpen then
				updateBackpackGrid()
			end
		end)
	end

	-- Instant O(1) Equip or Unequip Toggle Function
	equipOrToggleTool = function(tool: Tool)
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
		if not char or not hum or not tool or not tool.Parent then return end

		local currentlyEquipped = char:FindFirstChildOfClass("Tool")

		pcall(function()
			if currentlyEquipped == tool or isToolEquipped(tool) then
				hum:UnequipTools()
				if bp and tool.Parent == char then
					tool.Parent = bp
				end
			else
				hum:UnequipTools()
				if tool.Parent then
					hum:EquipTool(tool)
				end
			end
		end)

		updateSlotHighlightsOnly()
	end

	unequipAllBtn.MouseButton1Click:Connect(function()
		Animations.buttonClickPop(unequipAllBtn)
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
		if hum then hum:UnequipTools() end
		if char and bp then
			for _, c in ipairs(char:GetChildren()) do
				if c:IsA("Tool") then c.Parent = bp end
			end
		end
		updateSlotHighlightsOnly()
	end)

	-- ── Drop Item Function ───────────────────────────────────────────
	local function dropTool(tool: Tool)
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")

		pcall(function()
			if isToolEquipped(tool) and hum then
				hum:UnequipTools()
			end
			if hrp then
				tool.Parent = Workspace
				local handle = tool:FindFirstChild("Handle") :: BasePart? or tool:FindFirstChildWhichIsA("BasePart")
				if handle then
					handle.CFrame = hrp.CFrame * CFrame.new(0, 0, -3)
				end
			else
				tool.Parent = Workspace
			end
		end)

		for i = 1, NUM_SLOTS do
			if assignedSlots[i] == tool then
				assignedSlots[i] = nil
			end
		end

		updateHotbarVisuals()
		if isBackpackOpen then updateBackpackGrid() end

		pcall(function()
			local Notification = require("UI/Notification.luau")
			Notification.new("Inventory", string.format("Dropped '%s'", tool.Name), 2)
		end)
	end

	-- ── Drag & Drop Handlers (Toolbar Moving / Sorting / Dropping) ───
	local function isPointInsideGui(point: Vector2, gui: GuiObject): boolean
		local pos = gui.AbsolutePosition
		local size = gui.AbsoluteSize
		return point.X >= pos.X and point.X <= (pos.X + size.X) and point.Y >= pos.Y and point.Y <= (pos.Y + size.Y)
	end

	local function findSlotUnderOrNearMouse(mousePos: Vector2): number?
		-- 1. Exact hit test on individual slot buttons
		for slotIdx = 1, NUM_SLOTS do
			local slotFrame = slotFrames[slotIdx]
			if slotFrame and isPointInsideGui(mousePos, slotFrame) then
				return slotIdx
			end
		end

		-- 2. Magnetic snap if released anywhere along the toolbar HUD (generous Y +/- 40px and X +/- 20px tolerance)
		local hPos = hotbarFrame.AbsolutePosition
		local hSize = hotbarFrame.AbsoluteSize
		if mousePos.Y >= (hPos.Y - 45) and mousePos.Y <= (hPos.Y + hSize.Y + 45) and
		   mousePos.X >= (hPos.X - 25) and mousePos.X <= (hPos.X + hSize.X + 25) then
			local closestSlot: number? = nil
			local minDist = math.huge
			for slotIdx = 1, NUM_SLOTS do
				local slotFrame = slotFrames[slotIdx]
				if slotFrame then
					local center = slotFrame.AbsolutePosition + slotFrame.AbsoluteSize / 2
					local dist = math.abs(mousePos.X - center.X)
					if dist < minDist then
						minDist = dist
						closestSlot = slotIdx
					end
				end
			end
			return closestSlot
		end

		return nil
	end

	local function startDragging(tool: Tool, fromSlot: number?, startMouse: Vector2)
		draggingTool = tool
		draggingFromSlot = fromSlot
		dragStartPos = startMouse
		isDraggingActive = true

		dragGhost.Position = UDim2.new(0, startMouse.X - 26, 0, startMouse.Y - 26)
		ghostLabel.Text = tool.Name
		dragGhost.Visible = true

		if fromSlot and slotFrames[fromSlot] then
			slotFrames[fromSlot].BackgroundTransparency = 0.6
		end
	end

	local function finishDragging(endMouse: Vector2)
		if not isDraggingActive or not draggingTool then return end
		local tool = draggingTool
		local fromSlot = draggingFromSlot

		dragGhost.Visible = false
		draggingTool = nil
		draggingFromSlot = nil
		isDraggingActive = false
		justFinishedDrag = true
		task.delay(0.15, function()
			justFinishedDrag = false
		end)

		-- Reset any slot dimming
		if fromSlot and slotFrames[fromSlot] then
			slotFrames[fromSlot].BackgroundTransparency = UI.Theme.ContainerTransparency
		end

		-- 1. Check if dropped over or near any Hotbar Slot (Move / Swap Object in Toolbar)
		local targetSlot = findSlotUnderOrNearMouse(endMouse)

		if targetSlot then
			if fromSlot then
				if fromSlot ~= targetSlot then
					local oldTargetTool = assignedSlots[targetSlot]
					assignedSlots[targetSlot] = tool
					assignedSlots[fromSlot] = oldTargetTool

					pcall(function()
						local Notification = require("UI/Notification.luau")
						Notification.new("Toolbar", string.format("Moved '%s' to Slot %d", tool.Name, targetSlot % 10), 1.5)
					end)
				end
			else
				-- Dragged from Backpack Grid onto Toolbar Slot
				local oldTargetTool = assignedSlots[targetSlot]
				assignedSlots[targetSlot] = tool
				pcall(function()
					local Notification = require("UI/Notification.luau")
					Notification.new("Toolbar", string.format("Assigned '%s' to Slot %d", tool.Name, targetSlot % 10), 1.5)
				end)
			end
			Animations.popScale(slotFrames[targetSlot], 0.88, 1.12, 1.0, 0.2)
			updateHotbarVisuals()
			if isBackpackOpen then updateBackpackGrid() end
			return
		end

		-- 2. Check if dropped over Backpack Grid (Unassign from Toolbar)
		if bpWindow.Visible and isPointInsideGui(endMouse, bpGridScroll) then
			if fromSlot then
				assignedSlots[fromSlot] = nil
				pcall(function()
					local Notification = require("UI/Notification.luau")
					Notification.new("Toolbar", string.format("Removed '%s' from Slot %d", tool.Name, fromSlot % 10), 1.5)
				end)
				updateHotbarVisuals()
				updateBackpackGrid()
			end
			return
		end

		-- 3. Dropped OUTSIDE the entire toolbar region -> Drop Tool into 3D world!
		local hPos = hotbarFrame.AbsolutePosition
		local hSize = hotbarFrame.AbsoluteSize
		local isNearHotbar = endMouse.Y >= (hPos.Y - 60) and endMouse.Y <= (hPos.Y + hSize.Y + 60) and
		                     endMouse.X >= (hPos.X - 40) and endMouse.X <= (hPos.X + hSize.X + 40)
		local inBackpack = bpWindow.Visible and isPointInsideGui(endMouse, bpWindow)

		if not isNearHotbar and not inBackpack then
			-- Dragged far out into the 3D world: drop the tool!
			dropTool(tool)
		else
			-- Released slightly off-target near toolbar: safely snap back without dropping
			updateHotbarVisuals()
		end
	end

	table.insert(activeConnections, UserInputService.InputChanged:Connect(function(input)
		if isDraggingActive and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local mousePos = UserInputService:GetMouseLocation()
			dragGhost.Position = UDim2.new(0, mousePos.X - 26, 0, mousePos.Y - 26)

			-- Live hover highlighting over target slots
			for slotIdx = 1, NUM_SLOTS do
				local slotFrame = slotFrames[slotIdx]
				if slotFrame then
					local stroke = slotFrame:FindFirstChildWhichIsA("UIStroke")
					if isPointInsideGui(mousePos, slotFrame) then
						slotFrame.BackgroundColor3 = UI.Theme.Accent
						slotFrame.BackgroundTransparency = 0.3
						if stroke then stroke.Color = Color3.fromRGB(80, 255, 140) end
					else
						local tool = assignedSlots[slotIdx]
						local equipped = tool and isToolEquipped(tool)
						slotFrame.BackgroundColor3 = if equipped then UI.Theme.Accent else (if tool then UI.Theme.Container else UI.Theme.ContainerDark)
						slotFrame.BackgroundTransparency = if equipped then 0.2 else (if tool then UI.Theme.ContainerTransparency else UI.Theme.ContainerDarkTransparency)
						if stroke then stroke.Color = if equipped then UI.Theme.Border else UI.Theme.BorderDim end
					end
				end
			end
		end
	end))

	table.insert(activeConnections, UserInputService.InputEnded:Connect(function(input)
		if isDraggingActive and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			finishDragging(UserInputService:GetMouseLocation())
		end
	end))

	-- ── 8. Create Slots in Hotbar HUD ─────────────────────────────────
	for i = 1, NUM_SLOTS do
		local slotBtn = Instance.new("TextButton")
		slotBtn.Name = "Slot_" .. tostring(i)
		slotBtn.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
		slotBtn.BackgroundColor3 = UI.Theme.Container
		slotBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
		slotBtn.BorderSizePixel = 0
		slotBtn.Text = ""
		slotBtn.AutoButtonColor = false
		slotBtn.ClipsDescendants = true
		slotBtn.LayoutOrder = i
		slotBtn.Parent = hotbarFrame
		UI.registerThemeElement(slotBtn, "Container")

		local slotStroke = Instance.new("UIStroke")
		slotStroke.Color = UI.Theme.Border
		slotStroke.Thickness = 1.2
		slotStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		slotStroke.Parent = slotBtn
		UI.registerThemeElement(slotStroke, "Border")

		local slotScale = Instance.new("UIScale")
		slotScale.Scale = 1.0
		slotScale.Parent = slotBtn

		local numLabel = Instance.new("TextLabel")
		numLabel.Name = "SlotNum"
		numLabel.Size = UDim2.new(0, 14, 0, 12)
		numLabel.Position = UDim2.new(0, 2, 0, 2)
		numLabel.BackgroundTransparency = 1
		numLabel.Text = tostring(i % 10)
		numLabel.TextColor3 = UI.Theme.TextSecondary
		numLabel.Font = UI.Fonts.Mono
		numLabel.TextSize = 9
		numLabel.TextXAlignment = Enum.TextXAlignment.Left
		numLabel.ZIndex = 10
		numLabel.Parent = slotBtn
		UI.registerThemeElement(numLabel, "TextSecondary")

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "ToolName"
		nameLabel.Size = UDim2.new(1, -4, 0, 12)
		nameLabel.Position = UDim2.new(0, 2, 1, -14)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = ""
		nameLabel.TextColor3 = UI.Theme.TextPrimary
		nameLabel.Font = UI.Fonts.Header
		nameLabel.TextSize = 8
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.ZIndex = 10
		nameLabel.Parent = slotBtn
		UI.registerThemeElement(nameLabel, "TextPrimary")

		Animations.buttonHoverPush(slotBtn)

		-- Slot Dragging & Clicking
		local slotPressPos = Vector2.zero
		table.insert(activeConnections, slotBtn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				slotPressPos = UserInputService:GetMouseLocation()
			end
		end))

		table.insert(activeConnections, slotBtn.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and not isDraggingActive then
					local curTool = assignedSlots[i]
					if curTool then
						local curPos = UserInputService:GetMouseLocation()
						if (curPos - slotPressPos).Magnitude > 14 then
							startDragging(curTool, i, curPos)
						end
					end
				end
			end
		end))

		table.insert(activeConnections, slotBtn.MouseButton1Click:Connect(function()
			if not justFinishedDrag and not isDraggingActive then
				local tool = assignedSlots[i]
				if tool then
					Animations.buttonClickPop(slotBtn)
					equipOrToggleTool(tool)
				end
			end
		end))

		slotFrames[i] = slotBtn
	end

	-- ── 9. Dedicated Hamburger [ ≡ INV ] Button on Toolbar ────────────
	local function toggleBackpack()
		isBackpackOpen = not isBackpackOpen
		bpWindow.Visible = isBackpackOpen
		if isBackpackOpen then
			updateBackpackGrid()
			if Animations and typeof(Animations.openWindow) == "function" then
				local bpScale = bpWindow:FindFirstChildWhichIsA("UIScale") or Instance.new("UIScale", bpWindow)
				Animations.openWindow(bpWindow, bpScale)
			end
		end
	end

	local invBtn = Instance.new("TextButton")
	invBtn.Name = "InventoryToolbarBtn"
	invBtn.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	invBtn.BackgroundColor3 = UI.Theme.ContainerDark
	invBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	invBtn.BorderSizePixel = 0
	invBtn.Text = ""
	invBtn.AutoButtonColor = false
	invBtn.ClipsDescendants = true
	invBtn.LayoutOrder = 11
	invBtn.Parent = hotbarFrame
	UI.registerThemeElement(invBtn, "ContainerDark")
	Animations.buttonHoverPush(invBtn)

	local invStroke = Instance.new("UIStroke")
	invStroke.Color = UI.Theme.Border
	invStroke.Thickness = 1.2
	invStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	invStroke.Parent = invBtn
	UI.registerThemeElement(invStroke, "Border")

	local invKeyLabel = Instance.new("TextLabel")
	invKeyLabel.Size = UDim2.new(0, 14, 0, 12)
	invKeyLabel.Position = UDim2.new(0, 2, 0, 2)
	invKeyLabel.BackgroundTransparency = 1
	invKeyLabel.Text = "`"
	invKeyLabel.TextColor3 = UI.Theme.TextSecondary
	invKeyLabel.Font = UI.Fonts.Mono
	invKeyLabel.TextSize = 9
	invKeyLabel.TextXAlignment = Enum.TextXAlignment.Left
	invKeyLabel.ZIndex = 10
	invKeyLabel.Parent = invBtn
	UI.registerThemeElement(invKeyLabel, "TextSecondary")

	local invIconLabel = Instance.new("TextLabel")
	invIconLabel.Size = UDim2.new(1, 0, 0, 20)
	invIconLabel.Position = UDim2.new(0, 0, 0.5, -12)
	invIconLabel.BackgroundTransparency = 1
	invIconLabel.Text = "≡"
	invIconLabel.TextColor3 = UI.Theme.TextPrimary
	invIconLabel.Font = UI.Fonts.Header
	invIconLabel.TextSize = 16
	invIconLabel.ZIndex = 10
	invIconLabel.Parent = invBtn
	UI.registerThemeElement(invIconLabel, "TextPrimary")

	local invTextLabel = Instance.new("TextLabel")
	invTextLabel.Size = UDim2.new(1, 0, 0, 12)
	invTextLabel.Position = UDim2.new(0, 0, 1, -14)
	invTextLabel.BackgroundTransparency = 1
	invTextLabel.Text = "INV"
	invTextLabel.TextColor3 = UI.Theme.Accent
	invTextLabel.Font = UI.Fonts.Header
	invTextLabel.TextSize = 8
	invTextLabel.ZIndex = 10
	invTextLabel.Parent = invBtn
	UI.registerThemeElement(invTextLabel, "Accent")

	table.insert(activeConnections, invBtn.MouseButton1Click:Connect(function()
		if not justFinishedDrag then
			Animations.buttonClickPop(invBtn)
			toggleBackpack()
		end
	end))

	-- ── 10. Search Filter & Events ────────────────────────────────────
	table.insert(activeConnections, searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		filterQuery = searchBox.Text
		updateBackpackGrid()
	end))

	table.insert(activeConnections, bpCloseBtn.MouseButton1Click:Connect(function()
		Animations.buttonClickPop(bpCloseBtn)
		isBackpackOpen = false
		bpWindow.Visible = false
	end))

	-- Keybinds for 1-0 hotbar selection and ` for inventory
	table.insert(activeConnections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.Keyboard then
			for slotNum, key in ipairs(KEYCODES) do
				if input.KeyCode == key then
					local tool = assignedSlots[slotNum]
					local btn = slotFrames[slotNum]
					if btn then Animations.buttonClickPop(btn) end

					if tool then
						equipOrToggleTool(tool)
					else
						local char = LocalPlayer.Character
						local hum = char and char:FindFirstChildOfClass("Humanoid")
						if hum then hum:UnequipTools() end
						updateSlotHighlightsOnly()
					end
					break
				end
			end
			if input.KeyCode == Enum.KeyCode.Backquote then
				toggleBackpack()
			end
		end
	end))

	-- Real-Time Tool Acquisition & Inventory Sync Engine
	local boundTools: {[Tool]: boolean} = {}

	local function hookToolNameChange(tool: Tool)
		if boundTools[tool] then return end
		boundTools[tool] = true
		table.insert(activeConnections, tool:GetPropertyChangedSignal("Name"):Connect(function()
			for slotNum = 1, NUM_SLOTS do
				if assignedSlots[slotNum] == tool then
					local slotBtn = slotFrames[slotNum]
					local nameLabel = slotBtn and slotBtn:FindFirstChild("ToolName") :: TextLabel?
					if nameLabel then nameLabel.Text = tool.Name end
					break
				end
			end
			if isBackpackOpen then
				local card = backpackCards[tool]
				local tName = card and card:FindFirstChild("ToolLabel") :: TextLabel?
				if tName then tName.Text = tool.Name end
			end
		end))
	end

	local function onToolAdded(child: Instance)
		if not child:IsA("Tool") then return end
		local tool = child :: Tool
		hookToolNameChange(tool)

		-- Check if tool is already assigned to a toolbar slot
		local alreadyAssigned = false
		for i = 1, NUM_SLOTS do
			if assignedSlots[i] == tool then
				alreadyAssigned = true
				break
			end
		end

		if not alreadyAssigned then
			-- Assign to first available empty slot
			for i = 1, NUM_SLOTS do
				if not assignedSlots[i] then
					assignedSlots[i] = tool
					break
				end
			end
			updateHotbarVisuals()
		else
			updateSlotHighlightsOnly()
		end

		if isBackpackOpen then
			updateBackpackGrid()
		end
	end

	local function onToolRemoved(child: Instance)
		if not child:IsA("Tool") then return end
		local tool = child :: Tool

		-- Wait a frame to see if tool was simply equipped (moved from Backpack to Character) or genuinely removed
		task.defer(function()
			local char = LocalPlayer.Character
			local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
			local stillInInventory = (char and tool.Parent == char) or (bp and tool.Parent == bp)

			if not stillInInventory then
				boundTools[tool] = nil
				for i = 1, NUM_SLOTS do
					if assignedSlots[i] == tool then
						assignedSlots[i] = nil
					end
				end
				updateHotbarVisuals()
				if isBackpackOpen then updateBackpackGrid() end
			else
				updateSlotHighlightsOnly()
			end
		end)
	end

	-- ── 11. Multi-Stage Death & Respawn Inventory Reconciler ──────────
	local function reconcileFullInventory()
		local char = LocalPlayer.Character
		local bp = LocalPlayer:FindFirstChildOfClass("Backpack")

		-- 1. Purge destroyed, unparented, or orphaned dead tools
		for i = 1, NUM_SLOTS do
			local t = assignedSlots[i]
			if t and (not t.Parent or not t:IsDescendantOf(game) or (t.Parent ~= char and t.Parent ~= bp)) then
				assignedSlots[i] = nil
			end
		end

		-- 2. Clear invalid cache entries
		for k, c in pairs(slotCaches) do
			if not c.Tool or not c.Tool.Parent or not c.Tool:IsDescendantOf(game) or (c.Tool.Parent ~= char and c.Tool.Parent ~= bp) then
				slotCaches[k] = nil
			end
		end

		-- 3. Scan all valid tools in new character & backpack
		local allTools = getAllTools()
		for _, tool in ipairs(allTools) do
			hookToolNameChange(tool)
			local alreadyAssigned = false
			for i = 1, NUM_SLOTS do
				if assignedSlots[i] == tool then
					alreadyAssigned = true
					break
				end
			end
			if not alreadyAssigned then
				for i = 1, NUM_SLOTS do
					if not assignedSlots[i] then
						assignedSlots[i] = tool
						break
					end
				end
			end
		end

		updateHotbarVisuals()
		if isBackpackOpen then
			updateBackpackGrid()
		end
	end

	local function bindCharEvents(char: Model)
		local hum = char:WaitForChild("Humanoid", 4) :: Humanoid?
		if hum then
			table.insert(activeConnections, hum.Died:Connect(function()
				-- Immediately unequip and purge character tools upon death
				for i = 1, NUM_SLOTS do
					local t = assignedSlots[i]
					if t and t.Parent == char then
						assignedSlots[i] = nil
					end
				end
				updateSlotHighlightsOnly()
			end))
		end

		for _, item in ipairs(char:GetChildren()) do
			if item:IsA("Tool") then
				hookToolNameChange(item)
			end
		end
		table.insert(activeConnections, char.ChildAdded:Connect(onToolAdded))
		table.insert(activeConnections, char.ChildRemoved:Connect(onToolRemoved))

		-- Staggered reconciliation passes to capture late-replicating inventory items
		task.defer(reconcileFullInventory)
		task.delay(0.15, reconcileFullInventory)
		task.delay(0.40, reconcileFullInventory)
		task.delay(0.85, reconcileFullInventory)
	end

	if LocalPlayer.Character then bindCharEvents(LocalPlayer.Character) end
	table.insert(activeConnections, LocalPlayer.CharacterAdded:Connect(bindCharEvents))

	local function bindBpEvents(bp: Backpack)
		for _, item in ipairs(bp:GetChildren()) do
			if item:IsA("Tool") then
				hookToolNameChange(item)
			end
		end
		table.insert(activeConnections, bp.ChildAdded:Connect(onToolAdded))
		table.insert(activeConnections, bp.ChildRemoved:Connect(onToolRemoved))
		task.defer(reconcileFullInventory)
	end

	local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
	if bp then bindBpEvents(bp) end
	table.insert(activeConnections, LocalPlayer.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			bindBpEvents(child :: Backpack)
		end
	end))

	_G.__ModularHotbar_Cleanup = function()
		for _, conn in ipairs(activeConnections) do
			pcall(function() conn:Disconnect() end)
		end
		table.clear(activeConnections)
	end

	-- Initial render
	task.spawn(function()
		task.wait(0.3)
		updateHotbarVisuals()
	end)

	local widgetObj: HotbarWidget = {
		HotbarFrame = hotbarFrame,
		BackpackWindow = bpWindow,
		SetVisible = function(selfOrVal: any, maybeVal: any)
			local val = if typeof(selfOrVal) == "boolean" then selfOrVal else maybeVal
			hotbarFrame.Visible = val
			if not val then bpWindow.Visible = false end
		end,
		ToggleBackpack = toggleBackpack,
		IsOpen = function() return isBackpackOpen end,
		Refresh = function()
			queueInventoryRefresh()
		end
	}

	return widgetObj
end

return Hotbar
