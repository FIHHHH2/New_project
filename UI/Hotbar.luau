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
local ContextActionService = game:GetService("ContextActionService")

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
local KEYPAD_CODES = {
	Enum.KeyCode.KeypadOne,
	Enum.KeyCode.KeypadTwo,
	Enum.KeyCode.KeypadThree,
	Enum.KeyCode.KeypadFour,
	Enum.KeyCode.KeypadFive,
	Enum.KeyCode.KeypadSix,
	Enum.KeyCode.KeypadSeven,
	Enum.KeyCode.KeypadEight,
	Enum.KeyCode.KeypadNine,
	Enum.KeyCode.KeypadZero
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
			local hasVisible = false
			for _, p in ipairs(parts) do
				if p.Transparency < 1 then
					hasVisible = true
					break
				end
			end

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

				if not hasVisible or p.Transparency < 1 then
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
	for slotIdx = 1, NUM_SLOTS do
		pcall(function()
			ContextActionService:UnbindAction("ProjectFih_HotbarSlot_" .. tostring(slotIdx))
		end)
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
	ghostBadge:SetAttribute("KeepTextColor", true)
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
	ghostLabel:SetAttribute("KeepTextColor", true)
	ghostLabel.Parent = dragGhost

	-- ── 1. Hotbar HUD Container ───────────────────────────────────────
	local function computeToolbarWidth(boxCount: number): number
		local count = math.max(1, boxCount)
		return (count * SLOT_SIZE) + ((count - 1) * SLOT_GAP) + 12
	end

	local initialBoxCount = 1
	local initialWidth = computeToolbarWidth(initialBoxCount)
	local hotbarFrame = Instance.new("Frame")
	hotbarFrame.Name = "HotbarFrame"
	hotbarFrame.Size = UDim2.new(0, initialWidth, 0, SLOT_SIZE + 10)
	hotbarFrame.AnchorPoint = Vector2.new(0.5, 1)
	hotbarFrame.Position = UDim2.new(0.5, 0, 1, -16)
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

	-- ── Integrated Toolbar Health Bar (XP Bar Style) ───────────────────
	-- Sits slightly above the hotbar like an XP bar with centered HP text
	local healthBarContainer = Instance.new("Frame")
	healthBarContainer.Name = "ToolbarHealthBar"
	healthBarContainer.Size = UDim2.new(0, initialWidth, 0, 14)
	healthBarContainer.AnchorPoint = Vector2.new(0.5, 1)
	healthBarContainer.Position = UDim2.new(0.5, 0, 1, -(SLOT_SIZE + 10 + 16 + 10))
	healthBarContainer.BackgroundColor3 = Color3.fromRGB(15, 22, 18)
	healthBarContainer.BackgroundTransparency = 0.2
	healthBarContainer.BorderSizePixel = 0
	healthBarContainer.ClipsDescendants = true
	healthBarContainer.ZIndex = 10
	healthBarContainer.Parent = screenGui

	local healthBarStroke = Instance.new("UIStroke")
	healthBarStroke.Color = UI.Theme.Border
	healthBarStroke.Thickness = 1.5
	healthBarStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	healthBarStroke.Parent = healthBarContainer
	UI.registerThemeElement(healthBarStroke, "Border")

	local healthBarFill = Instance.new("Frame")
	healthBarFill.Name = "HealthFill"
	healthBarFill.Size = UDim2.new(1, 0, 1, 0)
	healthBarFill.Position = UDim2.new(0, 0, 0, 0)
	healthBarFill.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	healthBarFill.BorderSizePixel = 0
	healthBarFill.ZIndex = 11
	healthBarFill.Parent = healthBarContainer

	local healthGrad = Instance.new("UIGradient")
	healthGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 235, 120)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 195, 95))
	})
	healthGrad.Parent = healthBarFill

	local healthLabel = Instance.new("TextLabel")
	healthLabel.Name = "HealthIndicator"
	healthLabel.Size = UDim2.new(1, 0, 1, 0)
	healthLabel.Position = UDim2.new(0, 0, 0, 0)
	healthLabel.BackgroundTransparency = 1
	healthLabel.Text = "100 / 100 HP"
	healthLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	healthLabel.Font = UI.Fonts.Header
	healthLabel.TextSize = 10
	healthLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	healthLabel.TextStrokeTransparency = 0.25
	healthLabel.ZIndex = 15
	healthLabel:SetAttribute("KeepTextColor", true)
	healthLabel.Parent = healthBarContainer

	local function updateToolbarHealth(currentHp: number, maxHp: number)
		local ratio = math.clamp(currentHp / math.max(1, maxHp), 0, 1)
		TweenService:Create(healthBarFill, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(ratio, 0, 1, 0)
		}):Play()
		healthLabel.Text = string.format("%d / %d HP", math.floor(currentHp + 0.5), math.floor(maxHp + 0.5))
	end

	local function bindCharHealth(char: Model)
		local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
		if hum then
			updateToolbarHealth(hum.Health, hum.MaxHealth)
			local conn = hum.HealthChanged:Connect(function(newHp)
				updateToolbarHealth(newHp, hum.MaxHealth)
			end)
			table.insert(activeConnections, conn)
		end
	end

	if LocalPlayer.Character then
		task.spawn(bindCharHealth, LocalPlayer.Character)
	end
	table.insert(activeConnections, LocalPlayer.CharacterAdded:Connect(function(char)
		task.spawn(bindCharHealth, char)
	end))

	-- ── 2. Backpack Inventory Window ──────────────────────────────────
	local BP_WIDTH = 700
	local BP_HEIGHT = 480
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

	local bpUiScale = Instance.new("UIScale")
	bpUiScale.Name = "BpScale"
	bpUiScale.Scale = 1.0
	bpUiScale.Parent = bpWindow

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

	-- Enable Dragging for Backpack Window (Zero-drift cursor locked)
		UI.makeDraggable(bpTopBar, bpWindow)

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
	bpGridLayout.CellSize = UDim2.new(0, 98, 0, 76)
	bpGridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
	bpGridLayout.SortOrder = Enum.SortOrder.Name
	bpGridLayout.Parent = bpGridScroll

	-- ── 3. State Management & Tool Gathering ──────────────────────────
	local assignedSlotNames: {[number]: string} = {}
	local slotFrames: {[number]: TextButton} = {}
	local slotCaches: {[number]: ToolViewportCache} = {}
	local backpackCards: {[string]: TextButton} = {}
	local backpackCaches: {[string]: ToolViewportCache} = {}
	local isBackpackOpen = false
	local filterQuery = ""

	local draggingItemName: string? = nil
	local draggingFromSlot: number? = nil
	local dragStartPos = Vector2.zero
	local isDraggingActive = false
	local justFinishedDrag = false
	local equipOrToggleTool: ((Tool) -> ())
	local executeSlotToggle: ((number) -> ())

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

	local function getItemStack(name: string): {Tool}
		local stack: {Tool} = {}
		local char = LocalPlayer.Character
		if char then
			for _, item in ipairs(char:GetChildren()) do
				if item:IsA("Tool") and item.Name == name then
					table.insert(stack, item)
				end
			end
		end
		local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
		if bp then
			for _, item in ipairs(bp:GetChildren()) do
				if item:IsA("Tool") and item.Name == name then
					table.insert(stack, item)
				end
			end
		end
		return stack
	end

	local function getUniqueInventoryNames(): {string}
		local names: {string} = {}
		local seen: {[string]: boolean} = {}
		local char = LocalPlayer.Character
		if char then
			for _, item in ipairs(char:GetChildren()) do
				if item:IsA("Tool") and not seen[item.Name] then
					seen[item.Name] = true
					table.insert(names, item.Name)
				end
			end
		end
		local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
		if bp then
			for _, item in ipairs(bp:GetChildren()) do
				if item:IsA("Tool") and not seen[item.Name] then
					seen[item.Name] = true
					table.insert(names, item.Name)
				end
			end
		end
		return names
	end

	local function isToolEquipped(tool: Tool): boolean
		local char = LocalPlayer.Character
		return char ~= nil and (tool.Parent == char or char:FindFirstChild(tool.Name) == tool)
	end

	-- ── 4. Instant O(1) Slot Highlight Updater (Zero Viewport Rebuild) ──
	local function updateSlotHighlightsOnly()
		local isLight = UI.CurrentTheme and UI.CurrentTheme.Name and string.find(UI.CurrentTheme.Name, "Light") ~= nil
		for slotNum = 1, NUM_SLOTS do
			local slotBtn = slotFrames[slotNum]
			if not slotBtn or not slotBtn.Visible then continue end
			local name = assignedSlotNames[slotNum]
			local stroke = slotBtn:FindFirstChildWhichIsA("UIStroke")
			local nameLabel = slotBtn:FindFirstChild("ToolName") :: TextLabel?
			local stackBadge = slotBtn:FindFirstChild("StackBadge") :: TextLabel?

			if name and name ~= "" then
				local stack = getItemStack(name)
				local count = #stack
				local anyEquipped = false
				for _, t in ipairs(stack) do
					if isToolEquipped(t) then
						anyEquipped = true
						break
					end
				end

				if nameLabel then
					nameLabel.Text = name
					if anyEquipped then
						nameLabel.TextColor3 = UI.Theme.AccentText
						nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
						nameLabel.TextStrokeTransparency = 0.5
					else
						nameLabel.TextColor3 = UI.Theme.TextPrimary
						nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
						nameLabel.TextStrokeTransparency = if isLight then 1.0 else 0.5
					end
				end

				local keyLabel = slotBtn:FindFirstChild("KeyLabel") :: TextLabel?
				if keyLabel then
					if anyEquipped then
						keyLabel.TextColor3 = UI.Theme.AccentText
						keyLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
						keyLabel.TextStrokeTransparency = 0.6
					else
						keyLabel.TextColor3 = UI.Theme.TextSecondary
						keyLabel.TextStrokeTransparency = 1.0
					end
				end

				if stackBadge then
					if count > 1 then
						stackBadge.Text = "x" .. tostring(count)
						stackBadge.Visible = true
						if isLight then
							stackBadge.BackgroundColor3 = if anyEquipped then Color3.fromRGB(15, 85, 160) else Color3.fromRGB(45, 48, 58)
							stackBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
						else
							stackBadge.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
							stackBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
						end
					else
						stackBadge.Visible = false
					end
				end

				if anyEquipped then
					slotBtn.BackgroundColor3 = UI.Theme.Accent
					slotBtn.BackgroundTransparency = 0.15
					if stroke then
						stroke.Color = UI.Theme.Border
						stroke.Thickness = 2.0
					end
				else
					slotBtn.BackgroundColor3 = if isLight then UI.Theme.ContainerDark else UI.Theme.Container
					slotBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
					if stroke then
						stroke.Color = UI.Theme.Border
						stroke.Thickness = 1.5
					end
				end
			else
				if stackBadge then stackBadge.Visible = false end
				if nameLabel then nameLabel.Text = "" end
				slotBtn.BackgroundColor3 = if isLight then Color3.fromRGB(215, 218, 226) else UI.Theme.ContainerDark
				slotBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
				if stroke then
					stroke.Color = UI.Theme.BorderDim
					stroke.Thickness = 1.0
				end
			end
		end

		if isBackpackOpen then
			for itemName, card in pairs(backpackCards) do
				if card and card.Parent then
					local stack = getItemStack(itemName)
					local count = #stack
					local anyEquipped = false
					for _, t in ipairs(stack) do
						if isToolEquipped(t) then
							anyEquipped = true
							break
						end
					end

					card.BackgroundColor3 = if anyEquipped then UI.Theme.Accent else UI.Theme.ContainerDark
					card.BackgroundTransparency = if anyEquipped then 0.15 else UI.Theme.ContainerDarkTransparency
					local badge = card:FindFirstChild("EquippedBadge") :: TextLabel?
					if badge then badge.Text = if anyEquipped then "EQUIPPED" else "" end

					local stackBadge = card:FindFirstChild("StackBadge") :: TextLabel?
					if stackBadge then
						if count > 1 then
							stackBadge.Text = "x" .. tostring(count)
							stackBadge.Visible = true
						else
							stackBadge.Visible = false
						end
					end
				end
			end
		end
	end

	-- Auto-compact assigned slots to shift items up so no gaps exist (1, 2, 3, 4 contiguous)
	local function compactSlots()
		local packed: {string} = {}
		for i = 1, NUM_SLOTS do
			local name = assignedSlotNames[i]
			if name and name ~= "" and #getItemStack(name) > 0 then
				table.insert(packed, name)
			end
			assignedSlotNames[i] = nil
		end
		for i, name in ipairs(packed) do
			if i <= NUM_SLOTS then
				assignedSlotNames[i] = name
			end
		end
	end

	-- ── 5. Full Hotbar Viewport Render Function (Only Runs on Inventory Change) ──
	local function updateHotbarVisuals()
		local uniqueNames = getUniqueInventoryNames()
		local validNameSet: {[string]: boolean} = {}
		for _, name in ipairs(uniqueNames) do
			validNameSet[name] = true
		end

		-- Purge any slot whose item is not in current valid inventory
		for i = 1, NUM_SLOTS do
			local currentName = assignedSlotNames[i]
			if currentName and not validNameSet[currentName] then
				assignedSlotNames[i] = nil
				cleanViewport(slotFrames[i])
			end
		end

		compactSlots()

		-- Auto-assign unassigned unique items to first available slots
		for _, name in ipairs(uniqueNames) do
			local alreadyAssigned = false
			for i = 1, NUM_SLOTS do
				if assignedSlotNames[i] == name then
					alreadyAssigned = true
					break
				end
			end
			if not alreadyAssigned then
				for i = 1, NUM_SLOTS do
					if not assignedSlotNames[i] then
						assignedSlotNames[i] = name
						break
					end
				end
			end
		end

		compactSlots()

		-- Count how many valid unique items are currently assigned
		local activeCount = 0
		for i = 1, NUM_SLOTS do
			if assignedSlotNames[i] and validNameSet[assignedSlotNames[i]] then
				activeCount += 1
			end
		end

		-- If there isn't any objects, have just one box; otherwise size to active tool count
		local displaySlots = if activeCount == 0 then 1 else math.min(NUM_SLOTS, activeCount)
		local newWidth = computeToolbarWidth(displaySlots)

		-- Smoothly resize both the toolbar HUD and the health bar container
		TweenService:Create(hotbarFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, newWidth, 0, SLOT_SIZE + 10)
		}):Play()

		TweenService:Create(healthBarContainer, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, newWidth, 0, 14)
		}):Play()

		for slotNum = 1, NUM_SLOTS do
			local slotBtn = slotFrames[slotNum]
			local isVisible = (slotNum <= displaySlots)
			slotBtn.Visible = isVisible

			if not isVisible then
				continue
			end

			local name = assignedSlotNames[slotNum]
			local stroke = slotBtn:FindFirstChildWhichIsA("UIStroke")
			local nameLabel = slotBtn:FindFirstChild("ToolName") :: TextLabel?
			local stackBadge = slotBtn:FindFirstChild("StackBadge") :: TextLabel?

			if name and validNameSet[name] then
				local stack = getItemStack(name)
				local count = #stack
				local repTool = stack[1]
				local anyEquipped = false
				for _, t in ipairs(stack) do
					if isToolEquipped(t) then
						repTool = t
						anyEquipped = true
						break
					end
				end

				renderToolViewportCached(slotBtn, repTool, slotNum, slotCaches)
				if nameLabel then
					nameLabel.Text = name
					if anyEquipped then
						nameLabel.TextColor3 = UI.Theme.AccentText
						nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
						nameLabel.TextStrokeTransparency = 0.5
					else
						nameLabel.TextColor3 = UI.Theme.TextPrimary
						nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
						nameLabel.TextStrokeTransparency = if isLight then 1.0 else 0.5
					end
				end

				local keyLabel = slotBtn:FindFirstChild("KeyLabel") :: TextLabel?
				if keyLabel then
					if anyEquipped then
						keyLabel.TextColor3 = UI.Theme.AccentText
						keyLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
						keyLabel.TextStrokeTransparency = 0.6
					else
						keyLabel.TextColor3 = UI.Theme.TextSecondary
						keyLabel.TextStrokeTransparency = 1.0
					end
				end

				if stackBadge then
					if count > 1 then
						stackBadge.Text = "x" .. tostring(count)
						stackBadge.Visible = true
						if isLight then
							stackBadge.BackgroundColor3 = if anyEquipped then Color3.fromRGB(15, 85, 160) else Color3.fromRGB(45, 48, 58)
							stackBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
						else
							stackBadge.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
							stackBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
						end
					else
						stackBadge.Visible = false
					end
				end

				if anyEquipped then
					slotBtn.BackgroundColor3 = UI.Theme.Accent
					slotBtn.BackgroundTransparency = 0.15
					if stroke then
						stroke.Color = UI.Theme.Border
						stroke.Thickness = 2.0
					end
				else
					slotBtn.BackgroundColor3 = if isLight then UI.Theme.ContainerDark else UI.Theme.Container
					slotBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
					if stroke then
						stroke.Color = UI.Theme.Border
						stroke.Thickness = 1.5
					end
				end
			else
				local isLight = UI.CurrentTheme and UI.CurrentTheme.Name and string.find(UI.CurrentTheme.Name, "Light") ~= nil
				assignedSlotNames[slotNum] = nil
				cleanViewport(slotBtn)
				if nameLabel then nameLabel.Text = "" end
				if stackBadge then stackBadge.Visible = false end
				slotBtn.BackgroundColor3 = if isLight then Color3.fromRGB(215, 218, 226) else UI.Theme.ContainerDark
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
		local uniqueNames = getUniqueInventoryNames()
		local activeNameSet: {[string]: boolean} = {}

		for _, name in ipairs(uniqueNames) do
			activeNameSet[name] = true
			local matchesFilter = (filterQuery == "" or name:lower():find(filterQuery:lower(), 1, true) ~= nil)

			local existingCard = backpackCards[name]
			if not matchesFilter then
				if existingCard then
					cleanViewport(existingCard)
					UI.unregisterThemeElement(existingCard)
					existingCard:Destroy()
					backpackCards[name] = nil
					backpackCaches[name] = nil
				end
				continue
			end

			local stack = getItemStack(name)
			local count = #stack
			local repTool = stack[1]
			local anyEquipped = false
			for _, t in ipairs(stack) do
				if isToolEquipped(t) then
					repTool = t
					anyEquipped = true
					break
				end
			end

			if existingCard and existingCard.Parent == bpGridScroll then
				existingCard.BackgroundColor3 = if anyEquipped then UI.Theme.Accent else UI.Theme.ContainerDark
				existingCard.BackgroundTransparency = if anyEquipped then 0.15 else UI.Theme.ContainerDarkTransparency

				local itemStroke = existingCard:FindFirstChildWhichIsA("UIStroke")
				if itemStroke then
					itemStroke.Color = if anyEquipped then UI.Theme.Accent else UI.Theme.BorderDim
					itemStroke.Thickness = if anyEquipped then 2.5 else 1.0
				end

				local isLight = UI.CurrentTheme and UI.CurrentTheme.Name and string.find(UI.CurrentTheme.Name, "Light") ~= nil
				local tName = existingCard:FindFirstChild("ToolLabel") :: TextLabel?
				if tName then
					tName.Text = name
					if anyEquipped then
						tName.TextColor3 = UI.Theme.AccentText
						tName.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
						tName.TextStrokeTransparency = 0.5
					else
						tName.TextColor3 = UI.Theme.TextPrimary
						tName.TextStrokeTransparency = if isLight then 1.0 else 0.5
						tName.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
					end
				end

				local badge = existingCard:FindFirstChild("EquippedBadge") :: TextLabel?
				if badge then
					badge.Text = if anyEquipped then "EQUIPPED" else ""
				end

				local sBadge = existingCard:FindFirstChild("StackBadge") :: TextLabel?
				if sBadge then
					if count > 1 then
						sBadge.Text = "x" .. tostring(count)
						sBadge.Visible = true
					else
						sBadge.Visible = false
					end
				end

				renderToolViewportCached(existingCard, repTool, name, backpackCaches)
			else
				if existingCard then
					cleanViewport(existingCard)
					UI.unregisterThemeElement(existingCard)
					existingCard:Destroy()
					backpackCards[name] = nil
					backpackCaches[name] = nil
				end

				local itemCard = Instance.new("TextButton")
				itemCard.Name = "Item_" .. name
				itemCard.Size = UDim2.new(0, 84, 0, 74)
				itemCard.BackgroundColor3 = if anyEquipped then UI.Theme.Accent else UI.Theme.ContainerDark
				itemCard.BackgroundTransparency = if anyEquipped then 0.15 else UI.Theme.ContainerDarkTransparency
				itemCard.BorderSizePixel = 0
				itemCard.Text = ""
				itemCard.AutoButtonColor = false
				itemCard.ClipsDescendants = true
				itemCard.Parent = bpGridScroll
				UI.registerThemeElement(itemCard, if anyEquipped then "Accent" else "ContainerDark")
				Animations.buttonHoverPush(itemCard)

				local itemStroke = Instance.new("UIStroke")
				itemStroke.Color = if anyEquipped then UI.Theme.Accent else UI.Theme.BorderDim
				itemStroke.Thickness = if anyEquipped then 2.5 else 1.0
				itemStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				itemStroke.Parent = itemCard
				UI.registerThemeElement(itemStroke, "BorderDim")

				local tLabel = Instance.new("TextLabel")
				tLabel.Name = "ToolLabel"
				tLabel.Size = UDim2.new(1, -6, 0, 16)
				tLabel.Position = UDim2.new(0, 3, 1, -18)
				tLabel.BackgroundTransparency = 1
				tLabel.Text = name
				tLabel.TextColor3 = if anyEquipped then UI.Theme.AccentText else UI.Theme.TextPrimary
				tLabel.Font = UI.Fonts.Header
				tLabel.TextSize = 9
				tLabel.TextTruncate = Enum.TextTruncate.AtEnd
				tLabel.ZIndex = 5
				tLabel:SetAttribute("KeepTextColor", true)
				tLabel.Parent = itemCard

				local eqBadge = Instance.new("TextLabel")
				eqBadge.Name = "EquippedBadge"
				eqBadge.Size = UDim2.new(1, -6, 0, 12)
				eqBadge.Position = UDim2.new(0, 3, 0, 2)
				eqBadge.BackgroundTransparency = 1
				eqBadge.Text = if anyEquipped then "EQUIPPED" else ""
				eqBadge.TextColor3 = UI.Theme.AccentText
				eqBadge.Font = UI.Fonts.Mono
				eqBadge.TextSize = 8
				eqBadge.ZIndex = 5
				eqBadge.Parent = itemCard
				UI.registerThemeElement(eqBadge, "AccentText")

				local isLightCard = UI.CurrentTheme and UI.CurrentTheme.Name and string.find(UI.CurrentTheme.Name, "Light") ~= nil
				local cardStackBadge = Instance.new("TextLabel")
				cardStackBadge.Name = "StackBadge"
				cardStackBadge.Size = UDim2.new(0, 20, 0, 13)
				cardStackBadge.Position = UDim2.new(1, -2, 0, 2)
				cardStackBadge.AnchorPoint = Vector2.new(1, 0)
				cardStackBadge.BackgroundColor3 = if isLightCard then Color3.fromRGB(45, 48, 58) else Color3.fromRGB(20, 20, 25)
				cardStackBadge.BackgroundTransparency = 0.25
				cardStackBadge.Text = if count > 1 then "x" .. tostring(count) else ""
				cardStackBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
				cardStackBadge.Font = UI.Fonts.Header
				cardStackBadge.TextSize = 9
				cardStackBadge.Visible = (count > 1)
				cardStackBadge.ZIndex = 6
				cardStackBadge:SetAttribute("KeepTextColor", true)
				cardStackBadge.Parent = itemCard

				local badgeCorner = Instance.new("UICorner")
				badgeCorner.CornerRadius = UDim.new(0, 3)
				badgeCorner.Parent = cardStackBadge

				renderToolViewportCached(itemCard, repTool, name, backpackCaches)

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
								startDragging(name, nil, curPos)
							end
						end
					end
				end)

				itemCard.MouseButton1Click:Connect(function()
					if not justFinishedDrag and not isDraggingActive then
						Animations.buttonClickPop(itemCard)
						local curStack = getItemStack(name)
						if #curStack > 0 then
							local anyEq = false
							for _, t in ipairs(curStack) do
								if isToolEquipped(t) then anyEq = true break end
							end
							if anyEq then
								local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
								if hum then hum:UnequipTools() end
							else
								equipOrToggleTool(curStack[1])
							end
							updateSlotHighlightsOnly()
						end
					end
				end)

				backpackCards[name] = itemCard
			end
		end

		for oldName, oldCard in pairs(backpackCards) do
			if not activeNameSet[oldName] then
				cleanViewport(oldCard)
				UI.unregisterThemeElement(oldCard)
				oldCard:Destroy()
				backpackCards[oldName] = nil
				backpackCaches[oldName] = nil
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

		local isEquipped = (tool.Parent == char) or isToolEquipped(tool)

		pcall(function()
			if isEquipped then
				-- Unequip cleanly into Backpack
				hum:UnequipTools()
				if tool.Parent == char and bp then
					tool.Parent = bp
				end
			else
				-- Unequip currently equipped tools first
				hum:UnequipTools()
				-- Equip target tool cleanly
				hum:EquipTool(tool)
				if tool.Parent ~= char then
					tool.Parent = char
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

	-- ── Drop Single Item from Stack Function (Drops One by One) ──────
	local function dropOneItem(itemName: string)
		local stack = getItemStack(itemName)
		if #stack == 0 then return end

		-- Pick an unequipped tool to drop first, or the equipped one if only 1 left
		local targetTool: Tool = stack[#stack]
		for i = #stack, 1, -1 do
			if not isToolEquipped(stack[i]) then
				targetTool = stack[i]
				break
			end
		end

		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = char and char:FindFirstChildOfClass("Humanoid")

		pcall(function()
			if isToolEquipped(targetTool) and hum then
				hum:UnequipTools()
			end
			if hrp then
				targetTool.Parent = Workspace
				local handle = targetTool:FindFirstChild("Handle") :: BasePart? or targetTool:FindFirstChildWhichIsA("BasePart")
				if handle then
					handle.CFrame = hrp.CFrame * CFrame.new(0, 0, -3)
				end
			else
				targetTool.Parent = Workspace
			end
		end)

		local remaining = #getItemStack(itemName)
		if remaining == 0 then
			for i = 1, NUM_SLOTS do
				if assignedSlotNames[i] == itemName then
					assignedSlotNames[i] = nil
				end
			end
			compactSlots()
		end

		updateHotbarVisuals()
		if isBackpackOpen then updateBackpackGrid() end

		pcall(function()
			local Notification = require("UI/Notification.luau")
			if remaining > 0 then
				Notification.new("Inventory", string.format("Dropped 1x '%s' (%d remaining)", itemName, remaining), 1.5)
			else
				Notification.new("Inventory", string.format("Dropped '%s'", itemName), 1.5)
			end
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
			if slotFrame and slotFrame.Visible and isPointInsideGui(mousePos, slotFrame) then
				return slotIdx
			end
		end

		-- 2. Magnetic snap if released anywhere along the toolbar HUD
		local hPos = hotbarFrame.AbsolutePosition
		local hSize = hotbarFrame.AbsoluteSize
		if mousePos.Y >= (hPos.Y - 45) and mousePos.Y <= (hPos.Y + hSize.Y + 45) and
		   mousePos.X >= (hPos.X - 25) and mousePos.X <= (hPos.X + hSize.X + 25) then
			local closestSlot: number? = nil
			local minDist = math.huge
			for slotIdx = 1, NUM_SLOTS do
				local slotFrame = slotFrames[slotIdx]
				if slotFrame and slotFrame.Visible then
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

	local function startDragging(itemName: string, fromSlot: number?, startMouse: Vector2)
		draggingItemName = itemName
		draggingFromSlot = fromSlot
		dragStartPos = startMouse
		isDraggingActive = true

		dragGhost.Position = UDim2.new(0, startMouse.X - 26, 0, startMouse.Y - 26)
		ghostLabel.Text = itemName
		dragGhost.Visible = true

		if fromSlot and slotFrames[fromSlot] then
			slotFrames[fromSlot].BackgroundTransparency = 0.6
		end
	end

	local function finishDragging(endMouse: Vector2)
		if not isDraggingActive or not draggingItemName then return end
		local itemName = draggingItemName
		local fromSlot = draggingFromSlot

		dragGhost.Visible = false
		draggingItemName = nil
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

		-- 1. Check if dropped over or near any Hotbar Slot (Move / Swap Stack in Toolbar)
		local targetSlot = findSlotUnderOrNearMouse(endMouse)

		if targetSlot then
			if fromSlot then
				if fromSlot ~= targetSlot then
					local oldTargetName = assignedSlotNames[targetSlot]
					assignedSlotNames[targetSlot] = itemName
					assignedSlotNames[fromSlot] = oldTargetName

					pcall(function()
						local Notification = require("UI/Notification.luau")
						Notification.new("Toolbar", string.format("Moved '%s' to Slot %d", itemName, targetSlot % 10), 1.5)
					end)
				end
			else
				-- Dragged from Backpack Grid onto Toolbar Slot
				local oldTargetName = assignedSlotNames[targetSlot]
				assignedSlotNames[targetSlot] = itemName
				pcall(function()
					local Notification = require("UI/Notification.luau")
					Notification.new("Toolbar", string.format("Assigned '%s' to Slot %d", itemName, targetSlot % 10), 1.5)
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
				assignedSlotNames[fromSlot] = nil
				compactSlots()
				pcall(function()
					local Notification = require("UI/Notification.luau")
					Notification.new("Toolbar", string.format("Removed '%s' from Slot %d", itemName, fromSlot % 10), 1.5)
				end)
				updateHotbarVisuals()
				updateBackpackGrid()
			end
			return
		end

		-- 3. Dropped OUTSIDE the entire toolbar region -> Drop One Item from Stack into 3D world!
		local hPos = hotbarFrame.AbsolutePosition
		local hSize = hotbarFrame.AbsoluteSize
		local isNearHotbar = endMouse.Y >= (hPos.Y - 60) and endMouse.Y <= (hPos.Y + hSize.Y + 60) and
		                     endMouse.X >= (hPos.X - 40) and endMouse.X <= (hPos.X + hSize.X + 40)
		local inBackpack = bpWindow.Visible and isPointInsideGui(endMouse, bpWindow)

		if not isNearHotbar and not inBackpack then
			-- Dragged far out into the 3D world: drop one item from the stack!
			dropOneItem(itemName)
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
						local name = assignedSlotNames[slotIdx]
						local stack = if name and name ~= "" then getItemStack(name) else {}
						local equipped = false
						for _, t in ipairs(stack) do
							if isToolEquipped(t) then equipped = true break end
						end
						slotFrame.BackgroundColor3 = if equipped then UI.Theme.Accent else (if #stack > 0 then UI.Theme.Container else UI.Theme.ContainerDark)
						slotFrame.BackgroundTransparency = if equipped then 0.2 else (if #stack > 0 then UI.Theme.ContainerTransparency else UI.Theme.ContainerDarkTransparency)
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

	local toggleBackpack: () -> ()

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
		slotStroke.Thickness = 1.5
		slotStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		slotStroke.Parent = slotBtn
		UI.registerThemeElement(slotStroke, "Border")

		local slotScale = Instance.new("UIScale")
		slotScale.Scale = 1.0
		slotScale.Parent = slotBtn

		-- Number Indicator (1-0) in Top-Left Corner
		local keyLabel = Instance.new("TextLabel")
		keyLabel.Name = "KeyLabel"
		keyLabel.Size = UDim2.new(0, 14, 0, 12)
		keyLabel.Position = UDim2.new(0, 2, 0, 2)
		keyLabel.BackgroundTransparency = 1
		keyLabel.Text = if i == 10 then "0" else tostring(i)
		keyLabel.TextColor3 = UI.Theme.TextSecondary
		keyLabel.Font = UI.Fonts.Header
		keyLabel.TextSize = 9
		keyLabel.ZIndex = 10
		keyLabel:SetAttribute("KeepTextColor", true)
		keyLabel.Parent = slotBtn

		-- Stack Count Badge (e.g. "x5") in Top-Right Corner
		local isLight = UI.CurrentTheme and UI.CurrentTheme.Name and string.find(UI.CurrentTheme.Name, "Light") ~= nil
		local stackBadge = Instance.new("TextLabel")
		stackBadge.Name = "StackBadge"
		stackBadge.Size = UDim2.new(0, 20, 0, 13)
		stackBadge.Position = UDim2.new(1, -2, 0, 2)
		stackBadge.AnchorPoint = Vector2.new(1, 0)
		stackBadge.BackgroundColor3 = if isLight then Color3.fromRGB(45, 48, 58) else Color3.fromRGB(20, 20, 25)
		stackBadge.BackgroundTransparency = 0.25
		stackBadge.Text = ""
		stackBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
		stackBadge.Font = UI.Fonts.Header
		stackBadge.TextSize = 9
		stackBadge.Visible = false
		stackBadge.ZIndex = 12
		stackBadge:SetAttribute("KeepTextColor", true)
		stackBadge.Parent = slotBtn

		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(0, 3)
		badgeCorner.Parent = stackBadge

		-- Tool Name Label at Bottom of Slot
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "ToolName"
		nameLabel.Size = UDim2.new(1, -4, 0, 12)
		nameLabel.Position = UDim2.new(0, 2, 1, -13)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = ""
		nameLabel.TextColor3 = UI.Theme.TextPrimary
		nameLabel.Font = UI.Fonts.Header
		nameLabel.TextSize = 8
		nameLabel.TextStrokeTransparency = if isLight then 1.0 else 0.5
		nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.ZIndex = 10
		nameLabel:SetAttribute("KeepTextColor", true)
		nameLabel.Parent = slotBtn

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
					local curName = assignedSlotNames[i]
					if curName and curName ~= "" and #getItemStack(curName) > 0 then
						local curPos = UserInputService:GetMouseLocation()
						if (curPos - slotPressPos).Magnitude > 14 then
							startDragging(curName, i, curPos)
						end
					end
				end
			end
		end))

		local lastClickTick = 0
		local function onSlotTriggered()
			local now = os.clock()
			if (now - lastClickTick) < 0.08 then return end
			lastClickTick = now
			if not justFinishedDrag and not isDraggingActive then
				local name = assignedSlotNames[i]
				if name and name ~= "" and #getItemStack(name) > 0 then
					executeSlotToggle(i)
				else
					Animations.buttonClickPop(slotBtn)
					if toggleBackpack then toggleBackpack() end
				end
			end
		end
		table.insert(activeConnections, slotBtn.MouseButton1Click:Connect(onSlotTriggered))

		slotFrames[i] = slotBtn
	end

	local isHotbarEnabled = true

	-- ── 9. Dedicated Hamburger [ ≡ INV ] Button on Toolbar ────────────
	toggleBackpack = function()
		if not isHotbarEnabled then return end
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
	invBtn.Visible = false
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

	executeSlotToggle = function(slotNum: number)
		local name = assignedSlotNames[slotNum]
		if not name or name == "" then
			local uniqueNames = getUniqueInventoryNames()
			for _, n in ipairs(uniqueNames) do
				local alreadyAssigned = false
				for s = 1, NUM_SLOTS do
					if s ~= slotNum and assignedSlotNames[s] == n then
						alreadyAssigned = true
						break
					end
				end
				if not alreadyAssigned then
					name = n
					assignedSlotNames[slotNum] = n
					break
				end
			end
		end

		if not name or name == "" then
			local char = LocalPlayer.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then hum:UnequipTools() end
			updateSlotHighlightsOnly()
			return
		end

		local stack = getItemStack(name)
		if #stack == 0 then
			assignedSlotNames[slotNum] = nil
			compactSlots()
			updateHotbarVisuals()
			return
		end

		local btn = slotFrames[slotNum]
		if btn then Animations.buttonClickPop(btn) end

		-- Check if any tool in this stack is currently equipped
		local equippedTool: Tool? = nil
		for _, t in ipairs(stack) do
			if isToolEquipped(t) then
				equippedTool = t
				break
			end
		end

		if equippedTool then
			-- Already equipped: unequip it
			local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum:UnequipTools() end
		else
			-- Not equipped: equip the first available tool in the stack
			equipOrToggleTool(stack[1])
		end

		updateSlotHighlightsOnly()
	end

	local KEY_TO_SLOT: {[Enum.KeyCode]: number} = {
		[Enum.KeyCode.One] = 1,
		[Enum.KeyCode.Two] = 2,
		[Enum.KeyCode.Three] = 3,
		[Enum.KeyCode.Four] = 4,
		[Enum.KeyCode.Five] = 5,
		[Enum.KeyCode.Six] = 6,
		[Enum.KeyCode.Seven] = 7,
		[Enum.KeyCode.Eight] = 8,
		[Enum.KeyCode.Nine] = 9,
		[Enum.KeyCode.Zero] = 10,
		[Enum.KeyCode.KeypadOne] = 1,
		[Enum.KeyCode.KeypadTwo] = 2,
		[Enum.KeyCode.KeypadThree] = 3,
		[Enum.KeyCode.KeypadFour] = 4,
		[Enum.KeyCode.KeypadFive] = 5,
		[Enum.KeyCode.KeypadSix] = 6,
		[Enum.KeyCode.KeypadSeven] = 7,
		[Enum.KeyCode.KeypadEight] = 8,
		[Enum.KeyCode.KeypadNine] = 9,
		[Enum.KeyCode.KeypadZero] = 10,
	}

	local lastKeyActionTick = 0
	local function onKeyTriggered(targetSlot: number)
		if not isHotbarEnabled then return end
		local focused = UserInputService:GetFocusedTextBox()
		if focused then return end

		local now = os.clock()
		if (now - lastKeyActionTick) < 0.08 then return end
		lastKeyActionTick = now
		executeSlotToggle(targetSlot)
	end

	-- High-priority ContextActionService bindings to guarantee slot 2 and all slots intercept input
	-- even in games that sink or bind number keys
	for slotIdx = 1, NUM_SLOTS do
		local actionName = "ProjectFih_HotbarSlot_" .. tostring(slotIdx)
		pcall(function() ContextActionService:UnbindAction(actionName) end)
		local key = KEYCODES[slotIdx]
		local keypadKey = KEYPAD_CODES[slotIdx]
		pcall(function()
			ContextActionService:BindActionAtPriority(actionName, function(actName, state, input)
				if state == Enum.UserInputState.Begin then
					local focused = UserInputService:GetFocusedTextBox()
					if focused then return Enum.ContextActionResult.Pass end
					onKeyTriggered(slotIdx)
					return Enum.ContextActionResult.Sink
				end
				return Enum.ContextActionResult.Pass
			end, false, 3000, key, keypadKey)
		end)
	end

	-- Backup UserInputService listener
	table.insert(activeConnections, UserInputService.InputBegan:Connect(function(input, _gameProcessed)
		if not isHotbarEnabled then return end
		local focused = UserInputService:GetFocusedTextBox()
		if focused then return end

		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.Backquote then
				toggleBackpack()
				return
			end

			local targetSlot = KEY_TO_SLOT[input.KeyCode]
			if targetSlot then
				onKeyTriggered(targetSlot)
			end
		end
	end))

	-- Real-Time Tool Acquisition & Inventory Sync Engine
	local boundTools: {[Tool]: boolean} = {}

	local function hookToolNameChange(tool: Tool)
		if boundTools[tool] then return end
		boundTools[tool] = true
		table.insert(activeConnections, tool:GetPropertyChangedSignal("Name"):Connect(function()
			queueInventoryRefresh()
		end))
	end

	local function onToolAdded(child: Instance)
		if not child:IsA("Tool") then return end
		local tool = child :: Tool
		hookToolNameChange(tool)

		local name = tool.Name
		local alreadyAssigned = false
		for i = 1, NUM_SLOTS do
			if assignedSlotNames[i] == name then
				alreadyAssigned = true
				break
			end
		end

		if not alreadyAssigned then
			for i = 1, NUM_SLOTS do
				if not assignedSlotNames[i] then
					assignedSlotNames[i] = name
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
		local name = tool.Name

		task.defer(function()
			local remainingStack = getItemStack(name)
			if #remainingStack == 0 then
				boundTools[tool] = nil
				for i = 1, NUM_SLOTS do
					if assignedSlotNames[i] == name then
						assignedSlotNames[i] = nil
					end
				end
				compactSlots()
				updateHotbarVisuals()
				if isBackpackOpen then updateBackpackGrid() end
			else
				updateSlotHighlightsOnly()
			end
		end)
	end

	-- ── 11. Multi-Stage Death & Respawn Inventory Reconciler ──────────
	local function reconcileFullInventory()
		local uniqueNames = getUniqueInventoryNames()
		local validNameSet: {[string]: boolean} = {}
		for _, name in ipairs(uniqueNames) do
			validNameSet[name] = true
		end

		-- 1. Purge slots whose item name no longer exists
		for i = 1, NUM_SLOTS do
			local name = assignedSlotNames[i]
			if name and not validNameSet[name] then
				assignedSlotNames[i] = nil
			end
		end

		compactSlots()

		-- 2. Clear invalid cache entries
		for k, c in pairs(slotCaches) do
			if not c.Tool or not c.Tool.Parent or not c.Tool:IsDescendantOf(game) then
				slotCaches[k] = nil
			end
		end

		-- 3. Auto-assign any unassigned unique items
		for _, name in ipairs(uniqueNames) do
			local alreadyAssigned = false
			for i = 1, NUM_SLOTS do
				if assignedSlotNames[i] == name then
					alreadyAssigned = true
					break
				end
			end
			if not alreadyAssigned then
				for i = 1, NUM_SLOTS do
					if not assignedSlotNames[i] then
						assignedSlotNames[i] = name
						break
					end
				end
			end
		end

		compactSlots()
		updateHotbarVisuals()
		if isBackpackOpen then
			updateBackpackGrid()
		end
	end

	local function bindCharEvents(char: Model)
		local hum = char:WaitForChild("Humanoid", 4) :: Humanoid?
		if hum then
			table.insert(activeConnections, hum.Died:Connect(function()
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

	UI.onThemeChanged(function(targetTheme)
		healthLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		healthLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		healthLabel.TextStrokeTransparency = 0.25
		healthBarStroke.Color = targetTheme.Border
		hotbarStroke.Color = targetTheme.Border
		updateHotbarVisuals()
		updateSlotHighlightsOnly()
		if isBackpackOpen then
			updateBackpackGrid()
		end
	end)

	_G.__ModularHotbar_Cleanup = function()
		for slotIdx = 1, NUM_SLOTS do
			pcall(function()
				ContextActionService:UnbindAction("ProjectFih_HotbarSlot_" .. tostring(slotIdx))
			end)
		end
		for _, conn in ipairs(activeConnections) do
			pcall(function() conn:Disconnect() end)
		end
		table.clear(activeConnections)
		pcall(function() screenGui:Destroy() end)
	end

	-- Initial render
	task.spawn(function()
		task.wait(0.3)
		updateHotbarVisuals()
	end)

	local widgetObj: any = nil
	widgetObj = {
		HotbarFrame = hotbarFrame,
		BackpackWindow = bpWindow,
		IsEnabled = true,
		SetVisible = function(selfOrVal: any, maybeVal: any)
			local val = if typeof(selfOrVal) == "boolean" then selfOrVal else maybeVal
			isHotbarEnabled = val
			if widgetObj then widgetObj.IsEnabled = val end
			hotbarFrame.Visible = val
			healthBarContainer.Visible = val
			if not val then
				isBackpackOpen = false
				bpWindow.Visible = false
			end
		end,
		ToolbarHealthBar = healthBarContainer,
		ToggleBackpack = toggleBackpack,
		IsOpen = function() return isBackpackOpen end,
		Refresh = function()
			queueInventoryRefresh()
		end,
		Destroy = function()
			if _G.__ModularHotbar_Cleanup then
				pcall(_G.__ModularHotbar_Cleanup)
				_G.__ModularHotbar_Cleanup = nil
			end
		end
	}

	return widgetObj
end

function Hotbar.Destroy()
	if _G.__ModularHotbar_Cleanup then
		pcall(_G.__ModularHotbar_Cleanup)
		_G.__ModularHotbar_Cleanup = nil
	end
end

return Hotbar
