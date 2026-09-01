--!strict
--[=[
    ✦ Squared Retro Hotbar & 3D Model Viewport Backpack Inventory Widget ✦
    Features:
    - 10-slot bottom-center Hotbar HUD with live 3D ViewportFrame model previews
    - Dedicated retro [ ≡ INV ] hamburger button to toggle the Backpack Inventory box
    - Zero-lag debounced viewport caching & lazy-rendered inventory grid
    - Reliable 1-0 number key unequip toggling
    - Drag-to-sort slots: drag any hotbar item onto another slot to swap/reorder
    - Drag-to-drop: dragging an item outside the HUD drops the item into the world
    - 100% Theme-reactive (Dark, Light, Translucent Dark, Translucent Light, Adaptive)
]=]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

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

	if cached and existingVp and cached.Tool == tool and cached.Name == tool.Name and cached.TextureId == tool.TextureId and cached.Signature == sig then
		return
	end

	cleanViewport(container)

	local vp = Instance.new("ViewportFrame")
	vp.Name = "ModelViewport"
	vp.Size = UDim2.new(1, 0, 1, 0)
	vp.Position = UDim2.new(0, 0, 0, 0)
	vp.BackgroundTransparency = 1
	vp.BorderSizePixel = 0
	vp.Ambient = Color3.fromRGB(190, 190, 200)
	vp.LightColor = Color3.fromRGB(255, 255, 255)
	vp.LightDirection = Vector3.new(-1, -1.6, -1).Unit
	vp.ZIndex = 3
	vp.Parent = container

	local count = 0
	local minBounds = Vector3.new(math.huge, math.huge, math.huge)
	local maxBounds = Vector3.new(-math.huge, -math.huge, -math.huge)

	for _, desc in ipairs(tool:GetDescendants()) do
		if desc:IsA("BasePart") then
			count += 1
			local clone = desc:Clone()
			clone.CanCollide = false
			clone.Anchored = true
			clone.Parent = vp

			local p = desc.Position
			local sz = desc.Size
			minBounds = Vector3.new(
				math.min(minBounds.X, p.X - sz.X / 2),
				math.min(minBounds.Y, p.Y - sz.Y / 2),
				math.min(minBounds.Z, p.Z - sz.Z / 2)
			)
			maxBounds = Vector3.new(
				math.max(maxBounds.X, p.X + sz.X / 2),
				math.max(maxBounds.Y, p.Y + sz.Y / 2),
				math.max(maxBounds.Z, p.Z + sz.Z / 2)
			)
		end
	end

	if count == 0 then
		local handle = tool:FindFirstChild("Handle") or tool:FindFirstChildWhichIsA("BasePart")
		if handle and handle:IsA("BasePart") then
			count = 1
			local clone = handle:Clone()
			clone.CanCollide = false
			clone.Anchored = true
			clone.Parent = vp
			minBounds = handle.Position - handle.Size / 2
			maxBounds = handle.Position + handle.Size / 2
		end
	end

	if count > 0 then
		local center = (minBounds + maxBounds) / 2
		local size = (maxBounds - minBounds)
		local maxDim = math.max(size.X, size.Y, size.Z, 0.8)

		local cam = Instance.new("Camera")
		cam.FieldOfView = 50
		cam.CFrame = CFrame.new(center + Vector3.new(maxDim * 1.3, maxDim * 0.9, maxDim * 1.3), center)
		cam.Parent = vp
		vp.CurrentCamera = cam
	end

	cacheStore[cacheKey] = {
		Tool = tool,
		Name = tool.Name,
		TextureId = tool.TextureId,
		Signature = sig
	}
end

function Hotbar.new(): HotbarWidget
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
	dragGhost.BackgroundTransparency = 0.3
	dragGhost.BorderSizePixel = 0
	dragGhost.Visible = false
	dragGhost.ZIndex = 100
	dragGhost.Parent = screenGui

	local ghostStroke = Instance.new("UIStroke")
	ghostStroke.Color = UI.Theme.Border
	ghostStroke.Thickness = 2
	ghostStroke.Parent = dragGhost

	local ghostLabel = Instance.new("TextLabel")
	ghostLabel.Size = UDim2.new(1, -4, 0, 16)
	ghostLabel.Position = UDim2.new(0, 2, 1, -18)
	ghostLabel.BackgroundTransparency = 1
	ghostLabel.TextColor3 = UI.Theme.AccentText
	ghostLabel.Font = UI.Fonts.Header
	ghostLabel.TextSize = 9
	ghostLabel.TextTruncate = Enum.TextTruncate.AtEnd
	ghostLabel.ZIndex = 101
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
	bpTitle.Text = "Backpack Inventory (Sort & Drag)"
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

	-- ── 4. Render Hotbar Slots Function ──────────────────────────────
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

	-- ── 5. Render Backpack Grid Items Function ────────────────────────
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
				existingCard.BackgroundColor3 = if equipped then UI.Theme.Accent else UI.Theme.ContainerDark
				existingCard.BackgroundTransparency = if equipped then 0.15 else UI.Theme.ContainerDarkTransparency

				local itemStroke = existingCard:FindFirstChildWhichIsA("UIStroke")
				if itemStroke then
					itemStroke.Color = if equipped then UI.Theme.Border else UI.Theme.BorderDim
					itemStroke.Thickness = if equipped then 1.8 else 1.0
				end

				local tName = existingCard:FindFirstChild("ToolLabel") :: TextLabel?
				if tName then
					tName.Text = tool.Name
					tName.TextColor3 = if equipped then UI.Theme.AccentText else UI.Theme.TextPrimary
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
				itemCard.BackgroundColor3 = if equipped then UI.Theme.Accent else UI.Theme.ContainerDark
				itemCard.BackgroundTransparency = if equipped then 0.15 else UI.Theme.ContainerDarkTransparency
				itemCard.BorderSizePixel = 0
				itemCard.Text = ""
				itemCard.AutoButtonColor = false
				itemCard.ClipsDescendants = true
				itemCard.Parent = bpGridScroll
				UI.registerThemeElement(itemCard, if equipped then "Accent" else "ContainerDark")
				Animations.buttonHoverPush(itemCard)

				local itemStroke = Instance.new("UIStroke")
				itemStroke.Color = if equipped then UI.Theme.Border else UI.Theme.BorderDim
				itemStroke.Thickness = if equipped then 1.8 else 1.0
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
						if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and not draggingTool then
							local curPos = UserInputService:GetMouseLocation()
							if (curPos - cardPressPos).Magnitude > 8 then
								startDragging(tool, nil, curPos)
							end
						end
					end
				end)

				itemCard.MouseButton1Click:Connect(function()
					if not draggingTool then
						local char = LocalPlayer.Character
						local hum = char and char:FindFirstChildOfClass("Humanoid")
						local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
						if not char or not hum then return end

						if isToolEquipped(tool) then
							pcall(function() hum:UnequipTools() end)
							if bp and tool.Parent == char then pcall(function() tool.Parent = bp end) end
						else
							pcall(function() hum:UnequipTools() end)
							task.wait(0.01)
							pcall(function() hum:EquipTool(tool) end)
							if tool.Parent ~= char then pcall(function() tool.Parent = char end) end
						end
						updateHotbarVisuals()
						updateBackpackGrid()
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

	-- ── 6. Debounced Single-Flight Refresher ──────────────────────────
	local refreshScheduled = false
	local function queueInventoryRefresh()
		if refreshScheduled then return end
		refreshScheduled = true
		task.delay(0.03, function()
			refreshScheduled = false
			updateHotbarVisuals()
			if isBackpackOpen then
				updateBackpackGrid()
			end
		end)
	end

	local function equipOrToggleTool(tool: Tool)
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
		if not char or not hum then return end

		local currentlyEquipped = char:FindFirstChildOfClass("Tool")

		if currentlyEquipped == tool or isToolEquipped(tool) then
			-- Un-equip
			pcall(function() hum:UnequipTools() end)
			if bp and tool.Parent == char then
				pcall(function() tool.Parent = bp end)
			end
		else
			-- Equip
			pcall(function() hum:UnequipTools() end)
			task.wait(0.01)
			pcall(function() hum:EquipTool(tool) end)
			if tool.Parent ~= char then
				pcall(function() tool.Parent = char end)
			end
		end

		queueInventoryRefresh()
	end

	unequipAllBtn.MouseButton1Click:Connect(function()
		Animations.buttonClickPop(unequipAllBtn)
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
		if hum then pcall(function() hum:UnequipTools() end) end
		if char and bp then
			for _, c in ipairs(char:GetChildren()) do
				if c:IsA("Tool") then pcall(function() c.Parent = bp end) end
			end
		end
		queueInventoryRefresh()
	end)

	-- ── Drop Item Function ───────────────────────────────────────────
	local function dropTool(tool: Tool)
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")

		pcall(function()
			if isToolEquipped(tool) and hum then
				hum:UnequipTools()
				task.wait(0.02)
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

		pcall(function()
			local Notification = require("UI/Notification.luau")
			Notification.new("Inventory", string.format("Dropped '%s'", tool.Name), 2)
		end)
	end

	-- ── Drag & Drop Handlers ─────────────────────────────────────────
	local function isPointInsideGui(point: Vector2, gui: GuiObject): boolean
		local pos = gui.AbsolutePosition
		local size = gui.AbsoluteSize
		return point.X >= pos.X and point.X <= (pos.X + size.X) and point.Y >= pos.Y and point.Y <= (pos.Y + size.Y)
	end

	local function startDragging(tool: Tool, fromSlot: number?, startMouse: Vector2)
		draggingTool = tool
		draggingFromSlot = fromSlot
		dragStartPos = startMouse

		dragGhost.Position = UDim2.new(0, startMouse.X - 26, 0, startMouse.Y - 26)
		ghostLabel.Text = tool.Name
		dragGhost.Visible = true
	end

	local function finishDragging(endMouse: Vector2)
		if not draggingTool then return end
		local tool = draggingTool
		local fromSlot = draggingFromSlot

		dragGhost.Visible = false
		draggingTool = nil
		draggingFromSlot = nil

		-- 1. Check if dropped over a Hotbar Slot (Swap / Reorder)
		local targetSlot: number? = nil
		for slotIdx = 1, NUM_SLOTS do
			local slotFrame = slotFrames[slotIdx]
			if slotFrame and isPointInsideGui(endMouse, slotFrame) then
				targetSlot = slotIdx
				break
			end
		end

		if targetSlot then
			if fromSlot then
				local oldTargetTool = assignedSlots[targetSlot]
				assignedSlots[targetSlot] = tool
				assignedSlots[fromSlot] = oldTargetTool
			else
				assignedSlots[targetSlot] = tool
			end
			Animations.popScale(slotFrames[targetSlot], 0.9, 1.08, 1.0, 0.18)
			queueInventoryRefresh()
			return
		end

		-- 2. Check if dropped over Backpack Grid
		if bpWindow.Visible and isPointInsideGui(endMouse, bpGridScroll) then
			if fromSlot then
				assignedSlots[fromSlot] = nil
				queueInventoryRefresh()
			end
			return
		end

		-- 3. Dropped OUTSIDE both Hotbar and Backpack -> Drop Tool into world!
		local inHotbar = isPointInsideGui(endMouse, hotbarFrame)
		local inBackpack = bpWindow.Visible and isPointInsideGui(endMouse, bpWindow)

		if not inHotbar and not inBackpack then
			dropTool(tool)
			queueInventoryRefresh()
		end
	end

	UserInputService.InputChanged:Connect(function(input)
		if draggingTool and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local mousePos = UserInputService:GetMouseLocation()
			dragGhost.Position = UDim2.new(0, mousePos.X - 26, 0, mousePos.Y - 26)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if draggingTool and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			finishDragging(UserInputService:GetMouseLocation())
		end
	end)

	-- ── 7. Create Slots in Hotbar HUD ─────────────────────────────────
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
		slotBtn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				slotPressPos = UserInputService:GetMouseLocation()
			end
		end)

		slotBtn.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) and not draggingTool then
					local curTool = assignedSlots[i]
					if curTool then
						local curPos = UserInputService:GetMouseLocation()
						if (curPos - slotPressPos).Magnitude > 8 then
							startDragging(curTool, i, curPos)
						end
					end
				end
			end
		end)

		slotBtn.MouseButton1Click:Connect(function()
			if not draggingTool then
				local tool = assignedSlots[i]
				if tool then
					Animations.buttonClickPop(slotBtn)
					equipOrToggleTool(tool)
				end
			end
		end)

		slotFrames[i] = slotBtn
	end

	-- ── 8. Dedicated Hamburger [ ≡ INV ] Button on Toolbar ────────────
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

	invBtn.MouseButton1Click:Connect(function()
		Animations.buttonClickPop(invBtn)
		toggleBackpack()
	end)

	-- ── 9. Search Filter & Events ─────────────────────────────────────
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		filterQuery = searchBox.Text
		updateBackpackGrid()
	end)

	bpCloseBtn.MouseButton1Click:Connect(function()
		Animations.buttonClickPop(bpCloseBtn)
		isBackpackOpen = false
		bpWindow.Visible = false
	end)

	-- Keybinds for 1-0 hotbar selection and ` for inventory
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
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
						if hum then pcall(function() hum:UnequipTools() end) end
						queueInventoryRefresh()
					end
					break
				end
			end
			if input.KeyCode == Enum.KeyCode.Backquote then
				toggleBackpack()
			end
		end
	end)

	-- Debounced Inventory synchronization
	local function bindCharEvents(char: Model)
		char.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				queueInventoryRefresh()
			end
		end)
		char.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				queueInventoryRefresh()
			end
		end)
	end

	if LocalPlayer.Character then bindCharEvents(LocalPlayer.Character) end
	LocalPlayer.CharacterAdded:Connect(bindCharEvents)

	local function bindBpEvents(bp: Backpack)
		bp.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				queueInventoryRefresh()
			end
		end)
		bp.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				queueInventoryRefresh()
			end
		end)
	end

	local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
	if bp then bindBpEvents(bp) end
	LocalPlayer.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then bindBpEvents(child :: Backpack) end
	end)

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
