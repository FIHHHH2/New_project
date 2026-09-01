--!strict
--[=[
    ✦ Squared Retro Hotbar & Custom Backpack Inventory Widget ✦
    Features:
    - 10-slot bottom-center Hotbar HUD with direct 1-0 keybind tool equipping
    - Tactile spring micro-interactions & equipped tool pop-scale feedback
    - Full-featured expandable Backpack Grid with real-time tool search & filtering
    - Real-time inventory synchronization with Backpack and Character events
    - 100% Theme-reactive (Dark, Light, Translucent Dark, Translucent Light, Adaptive)
]=]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

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
local SLOT_SIZE = 44
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

function Hotbar.new(): HotbarWidget
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ModularHotbarGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 550
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	pcall(function() screenGui.Parent = CoreGui end)
	if not screenGui.Parent then
		screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	end

	-- Disable default Roblox Backpack CoreGui safely
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	-- ── 1. Hotbar HUD Container (Bottom-Center Dock) ──────────────────
	local hotbarTotalW = (NUM_SLOTS * SLOT_SIZE) + ((NUM_SLOTS - 1) * SLOT_GAP) + 36 -- +36 for backpack toggle btn
	local hotbarFrame = Instance.new("Frame")
	hotbarFrame.Name = "HotbarHUD"
	hotbarFrame.Size = UDim2.new(0, hotbarTotalW, 0, SLOT_SIZE + 8)
	hotbarFrame.Position = UDim2.new(0.5, -hotbarTotalW / 2, 1, -(SLOT_SIZE + 16))
	hotbarFrame.BackgroundColor3 = UI.Theme.Background
	hotbarFrame.BackgroundTransparency = UI.Theme.BackgroundTransparency
	hotbarFrame.BorderSizePixel = 0
	hotbarFrame.ClipsDescendants = false
	hotbarFrame.Parent = screenGui
	UI.registerThemeElement(hotbarFrame, "Background")

	local hotbarGrad = Instance.new("UIGradient")
	hotbarGrad.Rotation = 90
	hotbarGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 210))
	})
	hotbarGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0.15)
	})
	hotbarGrad.Parent = hotbarFrame

	local hotbarStroke = Instance.new("UIStroke")
	hotbarStroke.Color = UI.Theme.Border
	hotbarStroke.Thickness = 2
	hotbarStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	hotbarStroke.Parent = hotbarFrame
	UI.registerThemeElement(hotbarStroke, "Border")

	local hotbarScale = Instance.new("UIScale")
	hotbarScale.Scale = 1.0
	hotbarScale.Parent = hotbarFrame

	local hotbarPad = Instance.new("UIPadding")
	hotbarPad.PaddingLeft = UDim.new(0, 4)
	hotbarPad.PaddingRight = UDim.new(0, 4)
	hotbarPad.PaddingTop = UDim.new(0, 4)
	hotbarPad.PaddingBottom = UDim.new(0, 4)
	hotbarPad.Parent = hotbarFrame

	local hotbarLayout = Instance.new("UIListLayout")
	hotbarLayout.FillDirection = Enum.FillDirection.Horizontal
	hotbarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	hotbarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	hotbarLayout.Padding = UDim.new(0, SLOT_GAP)
	hotbarLayout.SortOrder = Enum.SortOrder.LayoutOrder
	hotbarLayout.Parent = hotbarFrame

	-- ── 2. Full Backpack Inventory Window (Popup Grid) ────────────────
	local bpWindow = Instance.new("Frame")
	bpWindow.Name = "BackpackInventoryWindow"
	bpWindow.Size = UDim2.new(0, 460, 0, 310)
	bpWindow.Position = UDim2.new(0.5, -230, 0.5, -155)
	bpWindow.BackgroundColor3 = UI.Theme.Background
	bpWindow.BackgroundTransparency = UI.Theme.BackgroundTransparency
	bpWindow.BorderSizePixel = 0
	bpWindow.Visible = false
	bpWindow.ZIndex = 80
	bpWindow.Parent = screenGui
	UI.registerThemeElement(bpWindow, "Background")

	local bpGrad = Instance.new("UIGradient")
	bpGrad.Rotation = 90
	bpGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 210))
	})
	bpGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0.15)
	})
	bpGrad.Parent = bpWindow

	local bpStroke = Instance.new("UIStroke")
	bpStroke.Color = UI.Theme.Border
	bpStroke.Thickness = 2
	bpStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bpStroke.Parent = bpWindow
	UI.registerThemeElement(bpStroke, "Border")

	local bpScale = Instance.new("UIScale")
	bpScale.Scale = 1.0
	bpScale.Parent = bpWindow

	-- Backpack TopBar
	local bpTopbar = Instance.new("Frame")
	bpTopbar.Name = "TopBar"
	bpTopbar.Size = UDim2.new(1, -12, 0, 28)
	bpTopbar.Position = UDim2.new(0, 6, 0, 6)
	bpTopbar.BackgroundColor3 = UI.Theme.Container
	bpTopbar.BackgroundTransparency = UI.Theme.ContainerTransparency
	bpTopbar.BorderSizePixel = 0
	bpTopbar.Parent = bpWindow
	UI.registerThemeElement(bpTopbar, "Container")

	local bpTopGrad = Instance.new("UIGradient")
	bpTopGrad.Rotation = 45
	bpTopGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 220, 230))
	})
	bpTopGrad.Parent = bpTopbar

	local bpTopStroke = Instance.new("UIStroke")
	bpTopStroke.Color = UI.Theme.Border
	bpTopStroke.Thickness = 1.5
	bpTopStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bpTopStroke.Parent = bpTopbar
	UI.registerThemeElement(bpTopStroke, "Border")

	local bpTitle = Instance.new("TextLabel")
	bpTitle.Size = UDim2.new(1, -60, 1, 0)
	bpTitle.Position = UDim2.new(0, 8, 0, 0)
	bpTitle.BackgroundTransparency = 1
	bpTitle.Text = "Backpack Inventory >>>>>"
	bpTitle.TextColor3 = UI.Theme.TextPrimary
	bpTitle.Font = UI.Fonts.Header
	bpTitle.TextSize = 11
	bpTitle.TextXAlignment = Enum.TextXAlignment.Left
	bpTitle.Parent = bpTopbar
	UI.registerThemeElement(bpTitle, "TextPrimary")

	local bpCloseBtn = Instance.new("TextButton")
	bpCloseBtn.Size = UDim2.new(0, 20, 0, 18)
	bpCloseBtn.Position = UDim2.new(1, -24, 0, 5)
	bpCloseBtn.BackgroundColor3 = UI.Theme.ContainerDark
	bpCloseBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	bpCloseBtn.BorderSizePixel = 0
	bpCloseBtn.Text = "X"
	bpCloseBtn.TextColor3 = UI.Theme.TextPrimary
	bpCloseBtn.Font = UI.Fonts.Header
	bpCloseBtn.TextSize = 10
	bpCloseBtn.Parent = bpTopbar
	UI.registerThemeElement(bpCloseBtn, "ContainerDark")
	UI.registerThemeElement(bpCloseBtn, "TextPrimary")

	local bpCloseStroke = Instance.new("UIStroke")
	bpCloseStroke.Color = UI.Theme.Border
	bpCloseStroke.Thickness = 1
	bpCloseStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bpCloseStroke.Parent = bpCloseBtn
	UI.registerThemeElement(bpCloseStroke, "Border")

	-- Search & Action Bar
	local searchFrame = Instance.new("Frame")
	searchFrame.Name = "SearchFrame"
	searchFrame.Size = UDim2.new(1, -12, 0, 26)
	searchFrame.Position = UDim2.new(0, 6, 0, 40)
	searchFrame.BackgroundColor3 = UI.Theme.Container
	searchFrame.BackgroundTransparency = UI.Theme.ContainerTransparency
	searchFrame.BorderSizePixel = 0
	searchFrame.Parent = bpWindow
	UI.registerThemeElement(searchFrame, "Container")

	local searchStroke = Instance.new("UIStroke")
	searchStroke.Color = UI.Theme.Border
	searchStroke.Thickness = 1.2
	searchStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	searchStroke.Parent = searchFrame
	UI.registerThemeElement(searchStroke, "Border")

	local searchBox = Instance.new("TextBox")
	searchBox.Size = UDim2.new(1, -110, 1, 0)
	searchBox.Position = UDim2.new(0, 8, 0, 0)
	searchBox.BackgroundTransparency = 1
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
	unequipAllBtn.Size = UDim2.new(0, 96, 1, -4)
	unequipAllBtn.Position = UDim2.new(1, -100, 0, 2)
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

	local unequipStroke = Instance.new("UIStroke")
	unequipStroke.Color = UI.Theme.Border
	unequipStroke.Thickness = 1
	unequipStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	unequipStroke.Parent = unequipAllBtn
	UI.registerThemeElement(unequipStroke, "Border")

	unequipAllBtn.MouseButton1Click:Connect(function()
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:UnequipTools()
		end
	end)

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

	local bpGridStroke = Instance.new("UIStroke")
	bpGridStroke.Color = UI.Theme.Border
	bpGridStroke.Thickness = 1.5
	bpGridStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bpGridStroke.Parent = bpGridScroll
	UI.registerThemeElement(bpGridStroke, "Border")

	local bpGridPad = Instance.new("UIPadding")
	bpGridPad.PaddingLeft = UDim.new(0, 6)
	bpGridPad.PaddingRight = UDim.new(0, 6)
	bpGridPad.PaddingTop = UDim.new(0, 6)
	bpGridPad.PaddingBottom = UDim.new(0, 6)
	bpGridPad.Parent = bpGridScroll

	local bpGridLayout = Instance.new("UIGridLayout")
	bpGridLayout.CellSize = UDim2.new(0, 80, 0, 70)
	bpGridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
	bpGridLayout.SortOrder = Enum.SortOrder.Name
	bpGridLayout.Parent = bpGridScroll

	-- ── 3. State Management & Tool Gathering ──────────────────────────
	local assignedSlots: {[number]: Tool} = {}
	local slotFrames: {[number]: TextButton} = {}
	local isBackpackOpen = false
	local filterQuery = ""

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
		return tool.Parent == LocalPlayer.Character
	end

	local function equipOrToggleTool(tool: Tool)
		local char = LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not char or not hum then return end

		if isToolEquipped(tool) then
			hum:UnequipTools()
		else
			hum:UnequipTools()
			task.wait(0.02)
			hum:EquipTool(tool)
		end
	end

	-- ── 4. Render Hotbar Slots ────────────────────────────────────────
	local function updateHotbarVisuals()
		local allTools = getAllTools()

		-- Auto-assign slots if empty or re-order
		for i = 1, NUM_SLOTS do
			local currentTool = assignedSlots[i]
			if currentTool and (not currentTool.Parent or (currentTool.Parent ~= LocalPlayer.Character and currentTool.Parent ~= LocalPlayer:FindFirstChildOfClass("Backpack"))) then
				assignedSlots[i] = nil
			end
		end

		local toolIdx = 1
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
			local numBadge = slotBtn:FindFirstChild("SlotNum") :: TextLabel?
			local uiScale = slotBtn:FindFirstChildWhichIsA("UIScale")

			if tool then
				local equipped = isToolEquipped(tool)
				if nameLabel then
					nameLabel.Text = tool.Name
					nameLabel.TextColor3 = if equipped then UI.Theme.AccentText else UI.Theme.TextPrimary
				end

				if equipped then
					TweenService:Create(slotBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						BackgroundColor3 = UI.Theme.Accent,
						BackgroundTransparency = 0
					}):Play()
					if stroke then
						TweenService:Create(stroke, TweenInfo.new(0.15), {
							Color = UI.Theme.Border,
							Thickness = 2.0
						}):Play()
					end
					if uiScale and uiScale.Scale < 1.05 then
						Animations.popScale(slotBtn, 0.95, 1.05, 1.0, 0.16)
					end
				else
					TweenService:Create(slotBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						BackgroundColor3 = UI.Theme.Container,
						BackgroundTransparency = UI.Theme.ContainerTransparency
					}):Play()
					if stroke then
						TweenService:Create(stroke, TweenInfo.new(0.15), {
							Color = UI.Theme.Border,
							Thickness = 1.2
						}):Play()
					end
				end
			else
				if nameLabel then nameLabel.Text = "" end
				TweenService:Create(slotBtn, TweenInfo.new(0.15), {
					BackgroundColor3 = UI.Theme.ContainerDark,
					BackgroundTransparency = UI.Theme.ContainerDarkTransparency
				}):Play()
				if stroke then
					TweenService:Create(stroke, TweenInfo.new(0.15), {
						Color = UI.Theme.BorderDim,
						Thickness = 1.0
					}):Play()
				end
			end
		end
	end

	-- ── 5. Render Backpack Grid Items ─────────────────────────────────
	local function updateBackpackGrid()
		for _, child in ipairs(bpGridScroll:GetChildren()) do
			if child:IsA("GuiObject") and child.Name:find("Item_") then
				child:Destroy()
			end
		end

		local allTools = getAllTools()
		for _, tool in ipairs(allTools) do
			if filterQuery ~= "" and not tool.Name:lower():find(filterQuery:lower(), 1, true) then
				continue
			end

			local equipped = isToolEquipped(tool)
			local itemCard = Instance.new("TextButton")
			itemCard.Name = "Item_" .. tool.Name
			itemCard.Size = UDim2.new(0, 80, 0, 70)
			itemCard.BackgroundColor3 = if equipped then UI.Theme.Accent else UI.Theme.ContainerDark
			itemCard.BackgroundTransparency = if equipped then 0.1 else UI.Theme.ContainerDarkTransparency
			itemCard.BorderSizePixel = 0
			itemCard.Text = ""
			itemCard.AutoButtonColor = false
			itemCard.ClipsDescendants = true
			itemCard.Parent = bpGridScroll
			UI.registerThemeElement(itemCard, if equipped then "Accent" else "ContainerDark")

			local itemStroke = Instance.new("UIStroke")
			itemStroke.Color = if equipped then UI.Theme.Border else UI.Theme.BorderDim
			itemStroke.Thickness = if equipped then 1.8 else 1.0
			itemStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			itemStroke.Parent = itemCard
			UI.registerThemeElement(itemStroke, "Border")

			local iconImg = Instance.new("ImageLabel")
			iconImg.Size = UDim2.new(0, 32, 0, 32)
			iconImg.Position = UDim2.new(0.5, -16, 0, 6)
			iconImg.BackgroundTransparency = 1
			iconImg.Image = tool.TextureId ~= "" and tool.TextureId or "rbxasset://textures/ui/GuiImagePlaceholder.png"
			iconImg.ScaleType = Enum.ScaleType.Fit
			iconImg.Parent = itemCard

			local tName = Instance.new("TextLabel")
			tName.Size = UDim2.new(1, -6, 0, 16)
			tName.Position = UDim2.new(0, 3, 1, -26)
			tName.BackgroundTransparency = 1
			tName.Text = tool.Name
			tName.TextColor3 = if equipped then UI.Theme.AccentText else UI.Theme.TextPrimary
			tName.Font = UI.Fonts.Header
			tName.TextSize = 10
			tName.TextTruncate = Enum.TextTruncate.AtEnd
			tName.Parent = itemCard
			UI.registerThemeElement(tName, "TextPrimary")

			local badge = Instance.new("TextLabel")
			badge.Size = UDim2.new(1, 0, 0, 10)
			badge.Position = UDim2.new(0, 0, 1, -11)
			badge.BackgroundTransparency = 1
			badge.Text = if equipped then "EQUIPPED" else ""
			badge.TextColor3 = UI.Theme.AccentText
			badge.Font = UI.Fonts.Mono
			badge.TextSize = 8
			badge.Parent = itemCard

			Animations.attachMicroSquash(itemCard, itemStroke, function()
				return if isToolEquipped(tool) then UI.Theme.Accent else UI.Theme.ContainerDark
			end, function()
				return UI.Theme.Accent
			end, function()
				return UI.Theme.AccentDark
			end)

			itemCard.MouseButton1Click:Connect(function()
				equipOrToggleTool(tool)
				task.wait(0.04)
				updateHotbarVisuals()
				updateBackpackGrid()
			end)
		end
	end

	-- ── 6. Create Slots in Hotbar HUD ─────────────────────────────────
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
		numLabel.Parent = slotBtn
		UI.registerThemeElement(numLabel, "TextSecondary")

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "ToolName"
		nameLabel.Size = UDim2.new(1, -4, 0, 22)
		nameLabel.Position = UDim2.new(0, 2, 0.5, -4)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = ""
		nameLabel.TextColor3 = UI.Theme.TextPrimary
		nameLabel.Font = UI.Fonts.Header
		nameLabel.TextSize = 9
		nameLabel.TextWrapped = true
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = slotBtn
		UI.registerThemeElement(nameLabel, "TextPrimary")

		Animations.attachMicroSquash(slotBtn, slotStroke, function()
			local tool = assignedSlots[i]
			if tool and isToolEquipped(tool) then
				return UI.Theme.Accent
			end
			return UI.Theme.Container
		end, function()
			return UI.Theme.ContainerDark
		end, function()
			return UI.Theme.Accent
		end)

		slotBtn.MouseButton1Click:Connect(function()
			local tool = assignedSlots[i]
			if tool then
				equipOrToggleTool(tool)
				task.wait(0.02)
				updateHotbarVisuals()
			end
		end)

		slotFrames[i] = slotBtn
	end

	-- ── 7. Backpack Expand Button on Hotbar [ 🎒 ] ────────────────────
	local bpToggleBtn = Instance.new("TextButton")
	bpToggleBtn.Name = "BackpackToggleBtn"
	bpToggleBtn.Size = UDim2.new(0, 28, 0, SLOT_SIZE)
	bpToggleBtn.BackgroundColor3 = UI.Theme.ContainerDark
	bpToggleBtn.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	bpToggleBtn.BorderSizePixel = 0
	bpToggleBtn.Text = "≡"
	bpToggleBtn.TextColor3 = UI.Theme.TextPrimary
	bpToggleBtn.Font = UI.Fonts.Header
	bpToggleBtn.TextSize = 14
	bpToggleBtn.LayoutOrder = NUM_SLOTS + 1
	bpToggleBtn.Parent = hotbarFrame
	UI.registerThemeElement(bpToggleBtn, "ContainerDark")
	UI.registerThemeElement(bpToggleBtn, "TextPrimary")

	local bpToggleStroke = Instance.new("UIStroke")
	bpToggleStroke.Color = UI.Theme.Border
	bpToggleStroke.Thickness = 1.2
	bpToggleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bpToggleStroke.Parent = bpToggleBtn
	UI.registerThemeElement(bpToggleStroke, "Border")

	local function openBackpackWindow()
		if isBackpackOpen then return end
		isBackpackOpen = true
		updateBackpackGrid()
		Animations.popIn(bpWindow, bpScale)
	end

	local function closeBackpackWindow()
		if not isBackpackOpen then return end
		isBackpackOpen = false
		Animations.popOut(bpWindow, bpScale)
	end

	local function toggleBackpackWindow()
		if isBackpackOpen then
			closeBackpackWindow()
		else
			openBackpackWindow()
		end
	end

	bpToggleBtn.MouseButton1Click:Connect(toggleBackpackWindow)
	bpCloseBtn.MouseButton1Click:Connect(closeBackpackWindow)

	-- TopBar drag on Backpack Window
	local bpDragging = false
	local bpDragStart = Vector3.zero
	local bpStartAbsPos = Vector2.zero
	local bpDragInput: InputObject? = nil

	bpTopbar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			bpDragging = true
			bpDragStart = input.Position
			bpStartAbsPos = bpWindow.AbsolutePosition
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					bpDragging = false
				end
			end)
		end
	end)

	bpTopbar.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			bpDragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if bpDragging and input == bpDragInput then
			local delta = input.Position - bpDragStart
			local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
			local posX = math.clamp(bpStartAbsPos.X + delta.X, 4, math.max(4, vp.X - bpWindow.AbsoluteSize.X - 4))
			local posY = math.clamp(bpStartAbsPos.Y + delta.Y, 4, math.max(4, vp.Y - bpWindow.AbsoluteSize.Y - 4))
			bpWindow.Position = UDim2.new(0, posX, 0, posY)
		end
	end)

	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		filterQuery = searchBox.Text
		updateBackpackGrid()
	end)

	-- ── 8. Number Key & Tilde Listeners (1-0, `) ──────────────────────
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		-- Tilde / Backquote opens backpack grid
		if input.KeyCode == Enum.KeyCode.Backquote or input.KeyCode == Enum.KeyCode.Tilde then
			toggleBackpackWindow()
			return
		end

		for slotNum, key in ipairs(KEYCODES) do
			if input.KeyCode == key then
				local tool = assignedSlots[slotNum]
				if tool then
					equipOrToggleTool(tool)
					task.wait(0.02)
					updateHotbarVisuals()
				end
				break
			end
		end
	end)

	-- ── 9. Backpack & Character Event Hooks ───────────────────────────
	local function hookInventoryEvents()
		local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
		if bp then
			bp.ChildAdded:Connect(function()
				task.wait(0.03)
				updateHotbarVisuals()
				if isBackpackOpen then updateBackpackGrid() end
			end)
			bp.ChildRemoved:Connect(function()
				task.wait(0.03)
				updateHotbarVisuals()
				if isBackpackOpen then updateBackpackGrid() end
			end)
		end

		local char = LocalPlayer.Character
		if char then
			char.ChildAdded:Connect(function(child)
				if child:IsA("Tool") then
					task.wait(0.03)
					updateHotbarVisuals()
					if isBackpackOpen then updateBackpackGrid() end
				end
			end)
			char.ChildRemoved:Connect(function(child)
				if child:IsA("Tool") then
					task.wait(0.03)
					updateHotbarVisuals()
					if isBackpackOpen then updateBackpackGrid() end
				end
			end)
		end
	end

	LocalPlayer.CharacterAdded:Connect(function()
		task.wait(0.3)
		hookInventoryEvents()
		updateHotbarVisuals()
	end)

	hookInventoryEvents()
	updateHotbarVisuals()

	return {
		HotbarFrame = hotbarFrame,
		BackpackWindow = bpWindow,
		SetVisible = function(selfOrVal: any, maybeVal: any)
			local v = if type(selfOrVal) == "boolean" then selfOrVal elseif type(maybeVal) == "boolean" then maybeVal else true
			hotbarFrame.Visible = v
			if not v and isBackpackOpen then
				closeBackpackWindow()
			end
		end,
		ToggleBackpack = toggleBackpackWindow,
		IsOpen = function() return hotbarFrame.Visible end,
		Refresh = function()
			updateHotbarVisuals()
			if isBackpackOpen then updateBackpackGrid() end
		end
	}
end

return Hotbar
