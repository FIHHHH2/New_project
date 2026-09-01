--!strict
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")

local UI = require("UI/UI.luau")
local Animations = require("UI/Animations.luau")
local FeatureManager = require("Core/FeatureManager.luau")
local Notification = require("UI/Notification.luau")

local CoreUI = {}
CoreUI.__index = CoreUI

function CoreUI.new(titleText: string)
	local self = setmetatable({}, CoreUI)
	
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ModularEngineGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	
	pcall(function()
		screenGui.Parent = CoreGui
	end)
	if not screenGui.Parent then
		screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end
	
	local mainFrame, topbar, sidebar, contentContainer, activeTagLabel, settingsBtn, configsBtn, uiScale = UI.createWindow(titleText)
	mainFrame.Parent = screenGui
	
	self.ScreenGui = screenGui
	self.MainFrame = mainFrame
	self.Sidebar = sidebar
	self.ContentContainer = contentContainer
	self.ActiveTagLabel = activeTagLabel
	self.SettingsBtn = settingsBtn
	self.ConfigsBtn = configsBtn
	self.UiScale = uiScale
	self.IsOpen = true
	self.IsTransitioning = false
	self.Tabs = {}
	self.ActiveTab = nil
	self.PreviousTab = nil
	self.SettingsTab = nil
	self.ConfigsTab = nil
	self.ActiveToggles = {}
	self.SliderFills = {}
	self.SubTabGroups = {}
	
	-- Wire toggle click handlers for Settings and Configs
	if self.SettingsBtn then
		self.SettingsBtn.MouseButton1Click:Connect(function()
			if self.SettingsTab then
				if self.ActiveTab == self.SettingsTab then
					self:SelectTab(self.PreviousTab or self.Tabs[1])
				else
					self:SelectTab(self.SettingsTab)
				end
			end
		end)
	end

	if self.ConfigsBtn then
		self.ConfigsBtn.MouseButton1Click:Connect(function()
			if self.ConfigsTab then
				if self.ActiveTab == self.ConfigsTab then
					self:SelectTab(self.PreviousTab or self.Tabs[1])
				else
					self:SelectTab(self.ConfigsTab)
				end
			end
		end)
	end

	UI.onThemeChanged(function(targetTheme)
		self:UpdateTheme(targetTheme)
	end)
	
	return self
end

function CoreUI:UpdateTheme(targetTheme: any)
	local theme = targetTheme or UI.Theme

	-- 1. Refresh active tab vs inactive tabs
	for _, tab in ipairs(self.Tabs) do
		if tab.Button and tab.Stroke then
			if tab == self.ActiveTab then
				tab.Button.BackgroundColor3 = theme.Accent
				tab.Button.BackgroundTransparency = 0
				tab.Button.TextColor3 = theme.AccentText
				tab.Stroke.Color = theme.Border
				tab.Stroke.Thickness = 1.5
				local grad = tab.Button:FindFirstChild("ActiveGradient") :: UIGradient?
				if grad then grad.Enabled = true end
			else
				tab.Button.BackgroundColor3 = theme.Container
				tab.Button.BackgroundTransparency = theme.ContainerTransparency
				tab.Button.TextColor3 = theme.TextSecondary
				tab.Stroke.Color = theme.BorderDim
				tab.Stroke.Thickness = 1.0
				local grad = tab.Button:FindFirstChild("ActiveGradient") :: UIGradient?
				if grad then grad.Enabled = false end
			end
		end
	end

	-- 2. Refresh Subheader buttons (Settings / Configs)
	if self.SettingsBtn and self.SettingsBtn:FindFirstChild("UIStroke") then
		local isSet = (self.ActiveTab == self.SettingsTab)
		self.SettingsBtn.BackgroundColor3 = if isSet then theme.Accent else theme.Container
		self.SettingsBtn.BackgroundTransparency = if isSet then 0 else theme.ContainerTransparency
		self.SettingsBtn.TextColor3 = if isSet then theme.AccentText else theme.TextPrimary
	end

	if self.ConfigsBtn and self.ConfigsBtn:FindFirstChild("UIStroke") then
		local isConf = (self.ActiveTab == self.ConfigsTab)
		self.ConfigsBtn.BackgroundColor3 = if isConf then theme.Accent else theme.Container
		self.ConfigsBtn.BackgroundTransparency = if isConf then 0 else theme.ContainerTransparency
		self.ConfigsBtn.TextColor3 = if isConf then theme.AccentText else theme.TextPrimary
	end

	-- 3. Refresh all subtab groups
	if self.SubTabGroups then
		for _, subTabGroup in ipairs(self.SubTabGroups) do
			if subTabGroup.UpdateTheme then
				subTabGroup.UpdateTheme()
			end
		end
	end

	-- 4. Refresh all active toggles
	for _, fn in ipairs(self.ActiveToggles) do
		pcall(fn)
	end

	-- 5. Refresh slider fills
	for _, fill in ipairs(self.SliderFills) do
		if fill and fill.Parent then
			fill.BackgroundColor3 = theme.Accent
		end
	end
end

function CoreUI:SetTheme(themeName: string)
	UI.setTheme(themeName)
end

function CoreUI:CreateTab(name: string, isHiddenFromSidebar: boolean?)
	local tabButton: TextButton? = nil
	local tabStroke: UIStroke? = nil
	
	if not isHiddenFromSidebar then
		tabButton = Instance.new("TextButton")
		tabButton.Name = name .. "TabBtn"
		tabButton.Size = UDim2.new(1, -4, 0, 30)
		tabButton.Position = UDim2.new(0, 2, 0, 0)
		tabButton.BackgroundColor3 = UI.Theme.Container
		tabButton.BackgroundTransparency = UI.Theme.ContainerTransparency
		tabButton.BorderSizePixel = 0
		tabButton.Text = name
		tabButton.TextColor3 = UI.Theme.TextSecondary
		tabButton.Font = UI.Fonts.Header
		tabButton.TextSize = 12
		tabButton.TextTruncate = Enum.TextTruncate.AtEnd
		tabButton.ClipsDescendants = true
		tabButton.LayoutOrder = #self.Tabs + 1
		tabButton.Parent = self.Sidebar
		UI.registerThemeElement(tabButton, "Container")
		UI.registerThemeElement(tabButton, "TextSecondary")
		
		-- Active tab gradient overlay
		local tabGrad = Instance.new("UIGradient")
		tabGrad.Name = "ActiveGradient"
		tabGrad.Rotation = 90
		tabGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 220))
		})
		tabGrad.Enabled = false
		tabGrad.Parent = tabButton
		
		tabStroke = Instance.new("UIStroke")
		tabStroke.Color = UI.Theme.Border
		tabStroke.Thickness = 1.5
		tabStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		tabStroke.Parent = tabButton
		UI.registerThemeElement(tabStroke, "Border")
	end
	
	local tabContent = Instance.new("ScrollingFrame")
	tabContent.Name = name .. "Page"
	tabContent.Size = UDim2.new(1, 0, 1, 0)
	tabContent.Position = UDim2.new(0, 0, 0, 0)
	tabContent.BackgroundTransparency = 1
	tabContent.BorderSizePixel = 0
	tabContent.ScrollBarThickness = 3
	tabContent.ScrollBarImageColor3 = UI.Theme.Accent
	tabContent.Visible = false
	tabContent.ClipsDescendants = false
	tabContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tabContent.CanvasSize = UDim2.new(0, 0, 0, 0)
	tabContent.Parent = self.ContentContainer

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 2)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.Parent = tabContent
	
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = tabContent
	
	local tabObj = {
		Name = name,
		Button = tabButton,
		Page = tabContent,
		Stroke = tabStroke,
		Layout = layout,
		IsHidden = isHiddenFromSidebar or false,
		IsVisible = not (isHiddenFromSidebar or false),
		OnVisibilityChanged = nil
	}
	
	if tabButton then
		tabButton.MouseEnter:Connect(function()
			if self.ActiveTab ~= tabObj then
				if tabStroke then TweenService:Create(tabStroke, TweenInfo.new(0.12), { Thickness = 2 }):Play() end
				TweenService:Create(tabButton, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.ContainerDark, TextColor3 = UI.Theme.TextPrimary }):Play()
			end
		end)
		tabButton.MouseLeave:Connect(function()
			if self.ActiveTab ~= tabObj then
				if tabStroke then TweenService:Create(tabStroke, TweenInfo.new(0.12), { Thickness = 1.5 }):Play() end
				TweenService:Create(tabButton, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.Container, TextColor3 = UI.Theme.TextSecondary }):Play()
			end
		end)
		tabButton.MouseButton1Click:Connect(function()
			self:SelectTab(tabObj)
		end)

		local function handleRightClick()
			if tabObj.Name == "Main" or tabObj.IsHidden then return end
			self:SetTabVisibility(tabObj, false)
			self:Notify("Module Hidden", string.format("'%s' tab hidden. Re-enable in Settings > Modules & Tabs.", tabObj.Name), 3.5)
		end

		tabButton.MouseButton2Click:Connect(handleRightClick)
		tabButton.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				handleRightClick()
			end
		end)
	end
	
	table.insert(self.Tabs, tabObj)
	
	if not isHiddenFromSidebar and #self.Tabs == 1 then
		self:SelectTab(tabObj)
	end
	
	return tabObj
end

function CoreUI:GetTab(name: string): any
	for _, tab in ipairs(self.Tabs) do
		if tab.Name == name then
			return tab
		end
	end
	return nil
end

function CoreUI:SetTabVisibility(tabObjOrName: any, visible: boolean)
	local targetTab = nil
	if type(tabObjOrName) == "string" then
		for _, tab in ipairs(self.Tabs) do
			if tab.Name == tabObjOrName then
				targetTab = tab
				break
			end
		end
	elseif type(tabObjOrName) == "table" then
		targetTab = tabObjOrName
	end

	if not targetTab then return end

	targetTab.IsVisible = visible
	if targetTab.Button then
		targetTab.Button.Visible = visible
	end

	if not visible and self.ActiveTab == targetTab then
		-- Fall back to first visible non-hidden tab
		for _, tab in ipairs(self.Tabs) do
			if not tab.IsHidden and tab.IsVisible ~= false then
				self:SelectTab(tab)
				break
			end
		end
	end

	if targetTab.OnVisibilityChanged then
		targetTab.OnVisibilityChanged(visible)
	end
end

function CoreUI:SelectTab(tabObj)
	if not tabObj then return end
	if self.ActiveTab == tabObj then return end

	local oldTab = self.ActiveTab

	if oldTab and not oldTab.IsHidden and tabObj.IsHidden then
		self.PreviousTab = oldTab
	elseif not tabObj.IsHidden then
		self.PreviousTab = nil
	end

	-- 1. Hide and reset all inactive tab pages immediately
	for _, tab in ipairs(self.Tabs) do
		if tab ~= tabObj and tab.Page then
			tab.Page.Visible = false
			tab.Page.Position = UDim2.new(0, 0, 0, 0)
			if tab.Button and tab.Stroke then
				tab.Button.Size = UDim2.new(1, -6, 0, 29)
				tab.Button.Position = UDim2.new(0, 3, 0, 0)
				tab.Button.BackgroundColor3 = UI.Theme.Container
				tab.Button.BackgroundTransparency = UI.Theme.ContainerTransparency
				tab.Button.TextColor3 = UI.Theme.TextSecondary
				tab.Stroke.Color = UI.Theme.BorderDim
				tab.Stroke.Thickness = 1.0
				local grad = tab.Button:FindFirstChild("ActiveGradient") :: UIGradient?
				if grad then grad.Enabled = false end
			end
		end
	end

	-- 2. Animate Incoming Tab Page
	tabObj.Page.Visible = true
	tabObj.Page.Position = UDim2.new(0, 16, 0, 0)
	local enterTween = TweenService:Create(tabObj.Page, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0)
	})
	enterTween:Play()

	-- 3. Animate Tab Button Spring & Indicator Pulse
	if tabObj.Button and tabObj.Stroke then
		tabObj.Button.Size = UDim2.new(1, -8, 0, 27)
		TweenService:Create(tabObj.Button, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(1, -2, 0, 31),
			Position = UDim2.new(0, 1, 0, 0),
			BackgroundColor3 = UI.Theme.Accent,
			BackgroundTransparency = 0,
			TextColor3 = UI.Theme.AccentText
		}):Play()
		
		-- Indicator pulse on active tab stroke
		Animations.pulseIndicator(tabObj.Stroke, UI.Theme.Accent, UI.Theme.Border, 2.2, 1.6)
		
		local grad = tabObj.Button:FindFirstChild("ActiveGradient") :: UIGradient?
		if grad then grad.Enabled = true end
	end

	-- 4. Cascaded Domino Ripple for Elements inside Incoming Tab Page
	local elementsToAnimate: {GuiObject} = {}
	for _, child in ipairs(tabObj.Page:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "ActiveGradient" and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			table.insert(elementsToAnimate, child)
		end
	end

	Animations.dominoRipple(elementsToAnimate, 0.03, 12, 0.24)

	self.ActiveTab = tabObj
	if self.ActiveTagLabel then
		self.ActiveTagLabel.Text = tabObj.Name
	end

	-- Subheader buttons active state
	if self.SettingsBtn and self.SettingsBtn:FindFirstChild("UIStroke") then
		local isSet = (tabObj == self.SettingsTab)
		TweenService:Create(self.SettingsBtn, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			BackgroundColor3 = if isSet then UI.Theme.Accent else UI.Theme.Container,
			BackgroundTransparency = if isSet then 0 else UI.Theme.ContainerTransparency,
			TextColor3 = if isSet then UI.Theme.AccentText else UI.Theme.TextPrimary
		}):Play()
	end

	if self.ConfigsBtn and self.ConfigsBtn:FindFirstChild("UIStroke") then
		local isConf = (tabObj == self.ConfigsTab)
		TweenService:Create(self.ConfigsBtn, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			BackgroundColor3 = if isConf then UI.Theme.Accent else UI.Theme.Container,
			BackgroundTransparency = if isConf then 0 else UI.Theme.ContainerTransparency,
			TextColor3 = if isConf then UI.Theme.AccentText else UI.Theme.TextPrimary
		}):Play()
	end
end

function CoreUI:BindSettingsTab(settingsTabObj)
	self.SettingsTab = settingsTabObj
end

function CoreUI:BindConfigsTab(configsTabObj)
	self.ConfigsTab = configsTabObj
end

function CoreUI:AddBanner(tabObj): Frame
	return UI.createBannerCard(tabObj.Page)
end

function CoreUI:CreateSubTabs(parentTab: any, subTabNames: {string})
	local parentPage: GuiObject
	if type(parentTab) == "table" and parentTab.Page then
		parentPage = parentTab.Page
	elseif typeof(parentTab) == "Instance" and parentTab:IsA("GuiObject") then
		parentPage = parentTab
	else
		error("[CoreUI:CreateSubTabs] Invalid parentTab provided.")
	end

	-- 1. Horizontal Sub-Tab Bar Container (LayoutOrder = 1)
	local subTabBar = Instance.new("Frame")
	subTabBar.Name = "SubTabBar"
	subTabBar.Size = UDim2.new(1, -4, 0, 26)
	subTabBar.Position = UDim2.new(0, 2, 0, 0)
	subTabBar.BackgroundColor3 = UI.Theme.ContainerDark
	subTabBar.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	subTabBar.BorderSizePixel = 0
	subTabBar.LayoutOrder = 1
	subTabBar.ClipsDescendants = false
	subTabBar.Parent = parentPage
	UI.registerThemeElement(subTabBar, "ContainerDark")

	local barStroke = Instance.new("UIStroke")
	barStroke.Color = UI.Theme.Border
	barStroke.Thickness = 1.2
	barStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	barStroke.Parent = subTabBar
	UI.registerThemeElement(barStroke, "Border")

	local barPadding = Instance.new("UIPadding")
	barPadding.PaddingLeft = UDim.new(0, 3)
	barPadding.PaddingRight = UDim.new(0, 3)
	barPadding.PaddingTop = UDim.new(0, 2)
	barPadding.PaddingBottom = UDim.new(0, 2)
	barPadding.Parent = subTabBar

	local barLayout = Instance.new("UIListLayout")
	barLayout.FillDirection = Enum.FillDirection.Horizontal
	barLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	barLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	barLayout.Padding = UDim.new(0, 4)
	barLayout.SortOrder = Enum.SortOrder.LayoutOrder
	barLayout.Parent = subTabBar

	-- 2. Sub-Pages Container (LayoutOrder = 2)
	local subPagesContainer = Instance.new("Frame")
	subPagesContainer.Name = "SubPagesContainer"
	subPagesContainer.Size = UDim2.new(1, 0, 0, 0)
	subPagesContainer.AutomaticSize = Enum.AutomaticSize.Y
	subPagesContainer.BackgroundTransparency = 1
	subPagesContainer.BorderSizePixel = 0
	subPagesContainer.LayoutOrder = 2
	subPagesContainer.ClipsDescendants = false
	subPagesContainer.Parent = parentPage

	local subPagesLayout = Instance.new("UIListLayout")
	subPagesLayout.SortOrder = Enum.SortOrder.LayoutOrder
	subPagesLayout.Padding = UDim.new(0, 0)
	subPagesLayout.Parent = subPagesContainer

	local subTabs = {
		Bar = subTabBar,
		Container = subPagesContainer,
		ActiveSubTab = nil :: any,
		Tabs = {} :: {[string]: any},
		SubTabList = {} :: {any},
		OnTabChanged = nil :: ((string, string?) -> ())?,
		Select = nil :: any,
		GetActive = nil :: any,
		UpdateTheme = nil :: any,
	}

	local numTabs = #subTabNames
	local tabWidthScale = 1 / math.max(1, numTabs)
	local spacingOffset = math.floor((4 * (numTabs - 1)) / numTabs)

	for idx, name in ipairs(subTabNames) do
		-- Sub-Tab Button
		local btn = Instance.new("TextButton")
		btn.Name = name .. "SubTabBtn"
		btn.Size = UDim2.new(tabWidthScale, -spacingOffset, 1, 0)
		btn.BackgroundColor3 = if idx == 1 then UI.Theme.Accent else UI.Theme.Container
		btn.BackgroundTransparency = if idx == 1 then 0 else UI.Theme.ContainerTransparency
		btn.BorderSizePixel = 0
		btn.Text = string.format("[ %s ]", name)
		btn.TextColor3 = if idx == 1 then UI.Theme.AccentText else UI.Theme.TextSecondary
		btn.Font = UI.Fonts.Header
		btn.TextSize = if numTabs >= 4 then 10 else 11
		btn.TextTruncate = Enum.TextTruncate.None
		btn.TextWrapped = false
		btn.LayoutOrder = idx
		btn.Parent = subTabBar

		local btnGrad = Instance.new("UIGradient")
		btnGrad.Name = "ActiveGradient"
		btnGrad.Rotation = 90
		btnGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 220))
		})
		btnGrad.Enabled = (idx == 1)
		btnGrad.Parent = btn

		local btnStroke = Instance.new("UIStroke")
		btnStroke.Color = if idx == 1 then UI.Theme.Border else UI.Theme.BorderDim
		btnStroke.Thickness = if idx == 1 then 1.5 else 1.0
		btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		btnStroke.Parent = btn

		-- Sub-Tab Page
		local page = Instance.new("Frame")
		page.Name = name .. "SubPage"
		page.Size = UDim2.new(1, 0, 0, 0)
		page.AutomaticSize = Enum.AutomaticSize.Y
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.Visible = (idx == 1)
		page.ClipsDescendants = false
		page.LayoutOrder = idx
		page.Parent = subPagesContainer

		local pageLayout = Instance.new("UIListLayout")
		pageLayout.Padding = UDim.new(0, 8)
		pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
		pageLayout.Parent = page

		local subTabObj = {
			Name = name,
			Button = btn,
			Page = page,
			Stroke = btnStroke,
			Gradient = btnGrad,
			ParentTab = parentTab,
			Index = idx
		}

		-- Hover & click effects with micro-squash and border glow
		Animations.attachMicroSquash(
			btn,
			btnStroke,
			function()
				return if subTabs.ActiveSubTab == subTabObj then UI.Theme.Accent else UI.Theme.Container
			end,
			function()
				return if subTabs.ActiveSubTab == subTabObj then UI.Theme.Accent else UI.Theme.ContainerDark
			end,
			function()
				return UI.Theme.Accent
			end,
			function()
				return if subTabs.ActiveSubTab == subTabObj then UI.Theme.Border else UI.Theme.BorderDim
			end,
			function()
				return UI.Theme.Border
			end
		)

		btn.MouseButton1Click:Connect(function()
			subTabs:Select(name)
		end)

		subTabs[name] = subTabObj
		subTabs[idx] = subTabObj
		subTabs.Tabs[name] = subTabObj
		table.insert(subTabs.SubTabList, subTabObj)

		if idx == 1 then
			subTabs.ActiveSubTab = subTabObj
		end
	end

	-- SubTab Selection Function
	function subTabs:Select(target: any)
		local targetObj = if type(target) == "string" then subTabs[target] elseif type(target) == "number" then subTabs[target] else target
		if not targetObj or subTabs.ActiveSubTab == targetObj then return end

		local oldSubTab = subTabs.ActiveSubTab
		subTabs.ActiveSubTab = targetObj

		-- Deactivate Old SubTab
		if oldSubTab then
			oldSubTab.Page.Visible = false
			oldSubTab.Page.Position = UDim2.new(0, 0, 0, 0)
			if oldSubTab.Button and oldSubTab.Stroke then
				TweenService:Create(oldSubTab.Button, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
					BackgroundColor3 = UI.Theme.Container,
					BackgroundTransparency = UI.Theme.ContainerTransparency,
					TextColor3 = UI.Theme.TextSecondary
				}):Play()
				TweenService:Create(oldSubTab.Stroke, TweenInfo.new(0.18), {
					Color = UI.Theme.BorderDim,
					Thickness = 1.0
				}):Play()
				if oldSubTab.Gradient then oldSubTab.Gradient.Enabled = false end
			end
		end

		-- Activate New SubTab Button with Indicator Pulse
		if targetObj.Button and targetObj.Stroke then
			TweenService:Create(targetObj.Button, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				BackgroundColor3 = UI.Theme.Accent,
				BackgroundTransparency = 0,
				TextColor3 = UI.Theme.AccentText
			}):Play()
			
			-- Active sub-tab indicator pulse
			Animations.pulseIndicator(targetObj.Stroke, UI.Theme.Accent, UI.Theme.Border, 2.2, 1.5)
			
			if targetObj.Gradient then targetObj.Gradient.Enabled = true end
		end

		-- Activate New SubTab Page with Spring Dynamics
		targetObj.Page.Visible = true
		targetObj.Page.Position = UDim2.new(0, 16, 0, 0)
		TweenService:Create(targetObj.Page, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 0)
		}):Play()

		-- Domino Ripple for Top-Level Child Elements
		local rippleElements: {GuiObject} = {}
		for _, child in ipairs(targetObj.Page:GetChildren()) do
			if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
				table.insert(rippleElements, child)
			end
		end

		Animations.dominoRipple(rippleElements, 0.025, 10, 0.22)

		if subTabs.OnTabChanged then
			pcall(subTabs.OnTabChanged, targetObj.Name, oldSubTab and oldSubTab.Name)
		end
	end

	function subTabs:GetActive()
		return subTabs.ActiveSubTab
	end

	-- Theme Re-application Handler
	subTabs.UpdateTheme = function()
		for _, tab in ipairs(subTabs.SubTabList) do
			if tab == subTabs.ActiveSubTab then
				tab.Button.BackgroundColor3 = UI.Theme.Accent
				tab.Button.BackgroundTransparency = 0
				tab.Button.TextColor3 = UI.Theme.AccentText
				tab.Stroke.Color = UI.Theme.Border
				tab.Stroke.Thickness = 1.5
				if tab.Gradient then tab.Gradient.Enabled = true end
			else
				tab.Button.BackgroundColor3 = UI.Theme.Container
				tab.Button.BackgroundTransparency = UI.Theme.ContainerTransparency
				tab.Button.TextColor3 = UI.Theme.TextSecondary
				tab.Stroke.Color = UI.Theme.BorderDim
				tab.Stroke.Thickness = 1.0
				if tab.Gradient then tab.Gradient.Enabled = false end
			end
		end
	end

	if not self.SubTabGroups then
		self.SubTabGroups = {}
	end
	table.insert(self.SubTabGroups, subTabs)

	return subTabs
end

function CoreUI:CreateColumns(tabObj: any): (Frame, Frame)
	local parentPage: GuiObject? = if type(tabObj) == "table" and tabObj.Page then tabObj.Page elseif typeof(tabObj) == "Instance" and tabObj:IsA("GuiObject") then tabObj else nil
	if not parentPage then
		error("[CoreUI:CreateColumns] Expected tabObj table or GuiObject instance.")
	end

	local columnsContainer = Instance.new("Frame")
	columnsContainer.Name = "ColumnsContainer"
	columnsContainer.Size = UDim2.new(1, 0, 0, 0)
	columnsContainer.AutomaticSize = Enum.AutomaticSize.Y
	columnsContainer.BackgroundTransparency = 1
	columnsContainer.BorderSizePixel = 0
	columnsContainer.ClipsDescendants = false
	columnsContainer.Parent = parentPage

	local leftCol = Instance.new("Frame")
	leftCol.Name = "LeftColumn"
	leftCol.Size = UDim2.new(0.5, -5, 0, 0)
	leftCol.Position = UDim2.new(0, 0, 0, 0)
	leftCol.AutomaticSize = Enum.AutomaticSize.Y
	leftCol.BackgroundTransparency = 1
	leftCol.BorderSizePixel = 0
	leftCol.ClipsDescendants = false
	leftCol.Parent = columnsContainer

	local leftLayout = Instance.new("UIListLayout")
	leftLayout.Padding = UDim.new(0, 8)
	leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
	leftLayout.Parent = leftCol

	local rightCol = Instance.new("Frame")
	rightCol.Name = "RightColumn"
	rightCol.Size = UDim2.new(0.5, -5, 0, 0)
	rightCol.Position = UDim2.new(0.5, 5, 0, 0)
	rightCol.AutomaticSize = Enum.AutomaticSize.Y
	rightCol.BackgroundTransparency = 1
	rightCol.BorderSizePixel = 0
	rightCol.ClipsDescendants = false
	rightCol.Parent = columnsContainer

	local rightLayout = Instance.new("UIListLayout")
	rightLayout.Padding = UDim.new(0, 8)
	rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rightLayout.Parent = rightCol

	if type(tabObj) == "table" then
		tabObj.LeftColumn = leftCol
		tabObj.RightColumn = rightCol
	end

	return leftCol, rightCol
end

function CoreUI:AddSection(parent: GuiObject, title: string): Frame
	local section = Instance.new("Frame")
	section.Name = title .. "Section"
	section.Size = UDim2.new(1, 0, 0, 0)
	section.AutomaticSize = Enum.AutomaticSize.Y
	section.BackgroundTransparency = 1
	section.BorderSizePixel = 0
	section.ClipsDescendants = false
	section.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = section

	-- standalone boxed header [ Category Name ]
	local headerBox = Instance.new("Frame")
	headerBox.Name = "HeaderBox"
	headerBox.Size = UDim2.new(1, -4, 0, 24)
	headerBox.Position = UDim2.new(0, 2, 0, 0)
	headerBox.BackgroundColor3 = UI.Theme.Container
	headerBox.BackgroundTransparency = UI.Theme.ContainerTransparency
	headerBox.BorderSizePixel = 0
	headerBox.Parent = section
	UI.registerThemeElement(headerBox, "Container")

	local headerGrad = Instance.new("UIGradient")
	headerGrad.Rotation = 90
	headerGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 220, 230))
	})
	headerGrad.Parent = headerBox

	local headerStroke = Instance.new("UIStroke")
	headerStroke.Color = UI.Theme.Border
	headerStroke.Thickness = 1.2
	headerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	headerStroke.Parent = headerBox
	UI.registerThemeElement(headerStroke, "Border")

	local headerLabel = Instance.new("TextLabel")
	headerLabel.Size = UDim2.new(1, 0, 1, 0)
	headerLabel.BackgroundTransparency = 1
	headerLabel.Text = title
	headerLabel.TextColor3 = UI.Theme.TextPrimary
	headerLabel.Font = UI.Fonts.Header
	headerLabel.TextSize = 11
	headerLabel.Parent = headerBox
	UI.registerThemeElement(headerLabel, "TextPrimary")

	return section
end

-- 3-Segment Toggle Row: [ X ] [ Option Name ] [ Bind ]
function CoreUI:AddToggle(section: Frame, featureId: string, name: string, defaultState: boolean, defaultKeybind: Enum.KeyCode?, callback: (boolean) -> ())
	local feature = FeatureManager.register(featureId, name, defaultState, defaultKeybind, callback)
	
	local row = Instance.new("Frame")
	row.Name = featureId .. "Row"
	row.Size = UDim2.new(1, -4, 0, 24)
	row.Position = UDim2.new(0, 2, 0, 0)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.ClipsDescendants = false
	row.Parent = section

	-- Segment 1: [ X ]
	local checkBtn = Instance.new("TextButton")
	checkBtn.Name = "CheckBtn"
	checkBtn.Size = UDim2.new(0, 24, 0, 24)
	checkBtn.Position = UDim2.new(0, 0, 0, 0)
	checkBtn.BackgroundColor3 = if feature.state then UI.Theme.Accent else UI.Theme.Container
	checkBtn.BackgroundTransparency = if feature.state then 0 else UI.Theme.ContainerTransparency
	checkBtn.BorderSizePixel = 0
	checkBtn.Text = ""
	checkBtn.Parent = row

	local checkStroke = Instance.new("UIStroke")
	checkStroke.Color = UI.Theme.Border
	checkStroke.Thickness = 1.2
	checkStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	checkStroke.Parent = checkBtn
	UI.registerThemeElement(checkStroke, "Border")

	local checkMark = Instance.new("TextLabel")
	checkMark.Name = "CheckMark"
	checkMark.Size = UDim2.new(1, 0, 1, 0)
	checkMark.Position = UDim2.new(0, 0, 0, 0)
	checkMark.BackgroundTransparency = 1
	checkMark.Text = "X"
	checkMark.TextColor3 = UI.Theme.AccentText
	checkMark.Font = UI.Fonts.Header
	checkMark.TextSize = 12
	checkMark.Visible = feature.state
	checkMark.Parent = checkBtn

	local checkScale = Instance.new("UIScale")
	checkScale.Scale = if feature.state then 1.0 else 0.0
	checkScale.Parent = checkMark

	-- Segment 2: [ Option Name ]
	local titleBox = Instance.new("TextButton")
	titleBox.Name = "TitleBox"
	titleBox.Size = UDim2.new(1, -90, 0, 24)
	titleBox.Position = UDim2.new(0, 28, 0, 0)
	titleBox.BackgroundColor3 = UI.Theme.Container
	titleBox.BackgroundTransparency = UI.Theme.ContainerTransparency
	titleBox.BorderSizePixel = 0
	titleBox.ClipsDescendants = true
	titleBox.Text = ""
	titleBox.Parent = row
	UI.registerThemeElement(titleBox, "Container")

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = UI.Theme.Border
	titleStroke.Thickness = 1.2
	titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	titleStroke.Parent = titleBox
	UI.registerThemeElement(titleStroke, "Border")

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -8, 1, 0)
	titleLabel.Position = UDim2.new(0, 6, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = name
	titleLabel.TextColor3 = UI.Theme.TextPrimary
	titleLabel.Font = UI.Fonts.Body
	titleLabel.TextSize = 11
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.ClipsDescendants = true
	titleLabel.Parent = titleBox
	UI.registerThemeElement(titleLabel, "TextPrimary")

	-- Segment 3: [ Bind ]
	local keybindBtn = Instance.new("TextButton")
	keybindBtn.Name = "KeybindBtn"
	keybindBtn.Size = UDim2.new(0, 58, 0, 24)
	keybindBtn.Position = UDim2.new(1, -58, 0, 0)
	keybindBtn.BackgroundColor3 = UI.Theme.Container
	keybindBtn.BackgroundTransparency = UI.Theme.ContainerTransparency
	keybindBtn.BorderSizePixel = 0
	keybindBtn.Text = if feature.keybind then string.format("[%s]", feature.keybind.Name) else "[None]"
	keybindBtn.TextColor3 = UI.Theme.TextSecondary
	keybindBtn.Font = UI.Fonts.Mono
	keybindBtn.TextSize = 10
	keybindBtn.TextTruncate = Enum.TextTruncate.AtEnd
	keybindBtn.ClipsDescendants = true
	keybindBtn.Parent = row
	UI.registerThemeElement(keybindBtn, "Container")
	UI.registerThemeElement(keybindBtn, "TextSecondary")

	local bindStroke = Instance.new("UIStroke")
	bindStroke.Color = UI.Theme.Border
	bindStroke.Thickness = 1.2
	bindStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bindStroke.Parent = keybindBtn
	UI.registerThemeElement(bindStroke, "Border")

	local function updateToggleVisual(state: boolean)
		if state then
			TweenService:Create(checkBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = UI.Theme.Accent,
				BackgroundTransparency = 0
			}):Play()
			checkMark.Visible = true
			checkMark.TextColor3 = UI.Theme.AccentText
			Animations.popScale(checkMark, 0.0, 1.25, 1.0, 0.20)
		else
			TweenService:Create(checkBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundColor3 = UI.Theme.Container,
				BackgroundTransparency = UI.Theme.ContainerTransparency
			}):Play()
			local closeTween = TweenService:Create(checkScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Scale = 0.0
			})
			closeTween:Play()
			closeTween.Completed:Connect(function()
				if not feature.state then
					checkMark.Visible = false
				end
			end)
		end
	end

	-- Hover animations on toggle components across all 3 segments with border glow
	local function onToggleHoverEnter()
		TweenService:Create(checkStroke, TweenInfo.new(0.12), { Thickness = 1.8, Color = UI.Theme.Accent }):Play()
		TweenService:Create(titleStroke, TweenInfo.new(0.12), { Thickness = 1.8, Color = UI.Theme.Accent }):Play()
		TweenService:Create(bindStroke, TweenInfo.new(0.12), { Thickness = 1.8, Color = UI.Theme.Accent }):Play()
		TweenService:Create(titleBox, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.ContainerDark }):Play()
	end

	local function onToggleHoverLeave()
		TweenService:Create(checkStroke, TweenInfo.new(0.12), { Thickness = 1.2, Color = UI.Theme.Border }):Play()
		TweenService:Create(titleStroke, TweenInfo.new(0.12), { Thickness = 1.2, Color = UI.Theme.Border }):Play()
		TweenService:Create(bindStroke, TweenInfo.new(0.12), { Thickness = 1.2, Color = UI.Theme.Border }):Play()
		TweenService:Create(titleBox, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.Container }):Play()
	end

	titleBox.MouseEnter:Connect(onToggleHoverEnter)
	titleBox.MouseLeave:Connect(onToggleHoverLeave)
	checkBtn.MouseEnter:Connect(onToggleHoverEnter)
	checkBtn.MouseLeave:Connect(onToggleHoverLeave)
	keybindBtn.MouseEnter:Connect(onToggleHoverEnter)
	keybindBtn.MouseLeave:Connect(onToggleHoverLeave)

	-- Synchronize visual state when toggled via keyboard keybind or external call
	feature.onStateChanged = function(newState: boolean)
		updateToggleVisual(newState)
		Notification.notifyFeature(name, newState)
	end

	table.insert(self.ActiveToggles, function()
		updateToggleVisual(feature.state)
	end)

	local function toggleAction()
		Animations.buttonClickPop(checkBtn)
		local nextState = not feature.state
		FeatureManager.setFeatureState(featureId, nextState)
	end

	checkBtn.MouseButton1Click:Connect(toggleAction)
	titleBox.MouseButton1Click:Connect(toggleAction)

	feature.onKeybindChanged = function(newKey)
		keybindBtn.Text = if newKey then string.format("[%s]", newKey.Name) else "[None]"
	end

	keybindBtn.MouseButton1Click:Connect(function()
		keybindBtn.Text = "[ ... ]"
		keybindBtn.TextColor3 = UI.Theme.Accent
		FeatureManager.promptKeybindCapture(function(selectedKey)
			FeatureManager.setFeatureKeybind(featureId, selectedKey)
			keybindBtn.Text = if selectedKey then string.format("[%s]", selectedKey.Name) else "[None]"
			keybindBtn.TextColor3 = UI.Theme.TextSecondary
		end)
	end)
end

function CoreUI:AddSlider(section: Frame, name: string, min: number, max: number, default: number, callback: (number) -> ())
	local sliderRecord, initialValue = FeatureManager.registerSlider(name, name, default, callback)

	local row = Instance.new("Frame")
	row.Name = name .. "SliderRow"
	row.Size = UDim2.new(1, -4, 0, 46)
	row.Position = UDim2.new(0, 2, 0, 0)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.ClipsDescendants = false
	row.Parent = section

	-- header line: [ Option Name ] + [ Val ]
	local titleBox = Instance.new("Frame")
	titleBox.Name = "TitleBox"
	titleBox.Size = UDim2.new(1, -52, 0, 22)
	titleBox.Position = UDim2.new(0, 0, 0, 0)
	titleBox.BackgroundColor3 = UI.Theme.Container
	titleBox.BackgroundTransparency = UI.Theme.ContainerTransparency
	titleBox.BorderSizePixel = 0
	titleBox.Parent = row
	UI.registerThemeElement(titleBox, "Container")

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = UI.Theme.Border
	titleStroke.Thickness = 1.2
	titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	titleStroke.Parent = titleBox
	UI.registerThemeElement(titleStroke, "Border")

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -8, 1, 0)
	titleLabel.Position = UDim2.new(0, 6, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = name
	titleLabel.TextColor3 = UI.Theme.TextPrimary
	titleLabel.Font = UI.Fonts.Body
	titleLabel.TextSize = 11
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.ClipsDescendants = true
	titleLabel.Parent = titleBox
	UI.registerThemeElement(titleLabel, "TextPrimary")

	local valBox = Instance.new("Frame")
	valBox.Name = "ValBox"
	valBox.Size = UDim2.new(0, 48, 0, 22)
	valBox.Position = UDim2.new(1, -48, 0, 0)
	valBox.BackgroundColor3 = UI.Theme.Container
	valBox.BackgroundTransparency = UI.Theme.ContainerTransparency
	valBox.BorderSizePixel = 0
	valBox.ClipsDescendants = true
	valBox.Parent = row
	UI.registerThemeElement(valBox, "Container")

	local valStroke = Instance.new("UIStroke")
	valStroke.Color = UI.Theme.Border
	valStroke.Thickness = 1.2
	valStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	valStroke.Parent = valBox
	UI.registerThemeElement(valStroke, "Border")

	local valLabel = Instance.new("TextLabel")
	valLabel.Size = UDim2.new(1, 0, 1, 0)
	valLabel.BackgroundTransparency = 1
	valLabel.Text = tostring(initialValue)
	valLabel.TextColor3 = UI.Theme.Accent
	valLabel.Font = UI.Fonts.Mono
	valLabel.TextSize = 10
	valLabel.TextTruncate = Enum.TextTruncate.AtEnd
	valLabel.ClipsDescendants = true
	valLabel.Parent = valBox

	-- track
	local bar = Instance.new("Frame")
	bar.Name = "SliderTrack"
	bar.Size = UDim2.new(1, 0, 0, 16)
	bar.Position = UDim2.new(0, 0, 0, 26)
	bar.BackgroundColor3 = UI.Theme.ContainerDark
	bar.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	bar.BorderSizePixel = 0
	bar.Parent = row
	UI.registerThemeElement(bar, "ContainerDark")

	local barStroke = Instance.new("UIStroke")
	barStroke.Color = UI.Theme.Border
	barStroke.Thickness = 1.2
	barStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	barStroke.Parent = bar
	UI.registerThemeElement(barStroke, "Border")

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	local initialRatio = math.clamp((initialValue - min) / (max - min), 0, 1)
	fill.Size = UDim2.new(initialRatio, 0, 1, 0)
	fill.BackgroundColor3 = UI.Theme.Accent
	fill.BorderSizePixel = 0
	fill.Parent = bar
	table.insert(self.SliderFills, fill)

	local fillGrad = Instance.new("UIGradient")
	fillGrad.Rotation = 90
	fillGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 220))
	})
	fillGrad.Parent = fill

	-- Responsive track border glow on hover
	bar.MouseEnter:Connect(function()
		TweenService:Create(barStroke, TweenInfo.new(0.12), { Color = UI.Theme.Accent, Thickness = 1.6 }):Play()
	end)
	bar.MouseLeave:Connect(function()
		TweenService:Create(barStroke, TweenInfo.new(0.12), { Color = UI.Theme.Border, Thickness = 1.2 }):Play()
	end)

	local sliding = false
	local currentVal = initialValue

	local function applyValue(val: number)
		if val ~= currentVal then
			currentVal = val
			valLabel.Text = tostring(val)
			valLabel.TextColor3 = UI.Theme.Accent
			Animations.popScale(valLabel, 1.15, nil, 1.0, 0.15)
		end
		local ratio = math.clamp((val - min) / (max - min), 0, 1)
		TweenService:Create(fill, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(ratio, 0, 1, 0)
		}):Play()
	end

	local function update(input: InputObject)
		local ratio = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		local rawVal = min + (max - min) * ratio
		local val = math.floor(rawVal + 0.5)
		applyValue(val)
		FeatureManager.setSliderValue(name, val)
	end

	sliderRecord.onValueChanged = function(newVal: number)
		applyValue(newVal)
	end

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			sliding = true
			update(input)
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					sliding = false
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
			update(input)
		end
	end)
end

function CoreUI:AddButton(section: Frame, name: string, callback: () -> ())
	local row = Instance.new("Frame")
	row.Name = name .. "ButtonRow"
	row.Size = UDim2.new(1, -4, 0, 26)
	row.Position = UDim2.new(0, 2, 0, 0)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.ClipsDescendants = false
	row.Parent = section

	local btn = Instance.new("TextButton")
	btn.Name = "ActionBtn"
	btn.Size = UDim2.new(1, 0, 1, 0)
	btn.BackgroundColor3 = UI.Theme.Container
	btn.BackgroundTransparency = UI.Theme.ContainerTransparency
	btn.BorderSizePixel = 0
	btn.Text = string.format("[ %s ]", name)
	btn.TextColor3 = UI.Theme.TextPrimary
	btn.Font = UI.Fonts.Header
	btn.TextSize = 11
	btn.TextTruncate = Enum.TextTruncate.AtEnd
	btn.ClipsDescendants = true
	btn.Parent = row
	UI.registerThemeElement(btn, "Container")
	UI.registerThemeElement(btn, "TextPrimary")

	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = UI.Theme.Border
	btnStroke.Thickness = 1.2
	btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	btnStroke.Parent = btn
	UI.registerThemeElement(btnStroke, "Border")

	-- Micro-squash and border glow on hover/click with instant response (UIScale 0.96 down, 1.0 Back.Out up)
	Animations.attachMicroSquash(
		btn,
		btnStroke,
		function() return UI.Theme.Container end,
		function() return UI.Theme.ContainerDark end,
		function() return UI.Theme.Accent end,
		function() return UI.Theme.Border end,
		function() return UI.Theme.Accent end
	)

	btn.MouseButton1Click:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.08), { BackgroundColor3 = UI.Theme.Accent, TextColor3 = UI.Theme.AccentText }):Play()
		task.delay(0.15, function()
			TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = UI.Theme.Container, TextColor3 = UI.Theme.TextPrimary }):Play()
		end)
		callback()
	end)
end

function CoreUI:AddTextBox(section: Frame, name: string, placeholder: string, defaultText: string?, onSubmitted: ((string) -> ())?): (TextBox, Frame)
	local row = Instance.new("Frame")
	row.Name = name .. "InputRow"
	row.Size = UDim2.new(1, -4, 0, 48)
	row.Position = UDim2.new(0, 2, 0, 0)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.Parent = section

	local titleBox = Instance.new("Frame")
	titleBox.Name = "TitleBox"
	titleBox.Size = UDim2.new(1, 0, 0, 20)
	titleBox.Position = UDim2.new(0, 0, 0, 0)
	titleBox.BackgroundColor3 = UI.Theme.Container
	titleBox.BackgroundTransparency = UI.Theme.ContainerTransparency
	titleBox.BorderSizePixel = 0
	titleBox.Parent = row
	UI.registerThemeElement(titleBox, "Container")

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = UI.Theme.Border
	titleStroke.Thickness = 1
	titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	titleStroke.Parent = titleBox
	UI.registerThemeElement(titleStroke, "Border")

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -8, 1, 0)
	titleLabel.Position = UDim2.new(0, 6, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = name
	titleLabel.TextColor3 = UI.Theme.TextPrimary
	titleLabel.Font = UI.Fonts.Header
	titleLabel.TextSize = 10
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.ClipsDescendants = true
	titleLabel.Parent = titleBox
	UI.registerThemeElement(titleLabel, "TextPrimary")

	local inputFrame = Instance.new("Frame")
	inputFrame.Name = "InputFrame"
	inputFrame.Size = UDim2.new(1, 0, 0, 24)
	inputFrame.Position = UDim2.new(0, 0, 0, 24)
	inputFrame.BackgroundColor3 = UI.Theme.ContainerDark
	inputFrame.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	inputFrame.BorderSizePixel = 0
	inputFrame.ClipsDescendants = true
	inputFrame.Parent = row
	UI.registerThemeElement(inputFrame, "ContainerDark")

	local inStroke = Instance.new("UIStroke")
	inStroke.Color = UI.Theme.Border
	inStroke.Thickness = 1
	inStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	inStroke.Parent = inputFrame
	UI.registerThemeElement(inStroke, "Border")

	local box = Instance.new("TextBox")
	box.Name = "InputBox"
	box.Size = UDim2.new(1, -12, 1, 0)
	box.Position = UDim2.new(0, 6, 0, 0)
	box.BackgroundTransparency = 1
	box.Text = defaultText or ""
	box.PlaceholderText = placeholder
	box.TextColor3 = UI.Theme.TextPrimary
	box.PlaceholderColor3 = UI.Theme.TextSecondary
	box.Font = UI.Fonts.Mono
	box.TextSize = 10
	box.ClearTextOnFocus = false
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.ClipsDescendants = true
	box.Parent = inputFrame
	UI.registerThemeElement(box, "TextPrimary")

	box.Focused:Connect(function()
		TweenService:Create(inStroke, TweenInfo.new(0.12), { Color = UI.Theme.Accent, Thickness = 1.5 }):Play()
	end)
	box.FocusLost:Connect(function(enter)
		TweenService:Create(inStroke, TweenInfo.new(0.12), { Color = UI.Theme.Border, Thickness = 1 }):Play()
		if enter and onSubmitted then
			onSubmitted(box.Text)
		end
	end)

	return box, row
end

function CoreUI:Notify(title: string, message: string, duration: number?)
	Notification.show(title, message, duration)
end

function CoreUI:Open(onComplete: (() -> ())?)
	if self.IsOpen or self.IsTransitioning then return end
	self.IsTransitioning = true
	Animations.openWindow(self.MainFrame, self.UiScale, function()
		self.IsOpen = true
		self.IsTransitioning = false
		if onComplete then onComplete() end
	end)
end

function CoreUI:Close(onComplete: (() -> ())?)
	if not self.IsOpen or self.IsTransitioning then return end
	self.IsTransitioning = true
	Animations.closeWindow(self.MainFrame, self.UiScale, function()
		self.IsOpen = false
		self.IsTransitioning = false
		if onComplete then onComplete() end
	end)
end

function CoreUI:Toggle(onComplete: (() -> ())?)
	if self.IsOpen then
		self:Close(onComplete)
	else
		self:Open(onComplete)
	end
end

function CoreUI:SetVisible(state: boolean, onComplete: (() -> ())?)
	if state then
		self:Open(onComplete)
	else
		self:Close(onComplete)
	end
end

return CoreUI
