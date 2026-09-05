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

local function safeParentGui(gui: ScreenGui)
	local lp = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	local pgui = lp and (lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui", 5))

	local parented = false
	if CoreGui then
		pcall(function()
			gui.Parent = CoreGui
			parented = (gui.Parent == CoreGui)
		end)
	end
	if not parented and pgui then
		pcall(function()
			gui.Parent = pgui
			parented = (gui.Parent == pgui)
		end)
	end
	if not parented and type(gethui) == "function" then
		pcall(function()
			local h = gethui()
			if h and not h:IsA("ScreenGui") then
				gui.Parent = h
				parented = (gui.Parent == h)
			end
		end)
	end
end

local CoreUI = {}
CoreUI.__index = CoreUI

function CoreUI.new(titleText: string)
	local self = setmetatable({}, CoreUI)
	
	pcall(function()
		local containers = {
			(type(gethui) == "function" and gethui()),
			CoreGui,
			CoreGui:FindFirstChild("RobloxGui"),
			(Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui"))
		}
		for _, c in ipairs(containers) do
			if c then
				for _, child in ipairs(c:GetChildren()) do
					if child.Name == "ModularEngineGui" then
						pcall(function() child:Destroy() end)
					end
				end
			end
		end
	end)

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ModularEngineGui"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	
	safeParentGui(screenGui)
	
	local mainFrame, topbar, sidebar, contentContainer, activeTagLabel, settingsBtn, configsBtn, uiScale, controller, themesBtn, statusLabel = UI.createWindow(titleText)
	mainFrame.Parent = screenGui
	
	self.ScreenGui = screenGui
	self.MainFrame = mainFrame
	self.Sidebar = sidebar
	self.ContentContainer = contentContainer
	self.ActiveTagLabel = activeTagLabel
	self.StatusLabel = statusLabel
	self.SettingsBtn = settingsBtn
	self.ConfigsBtn = configsBtn
	self.ThemesBtn = themesBtn
	self.UiScale = uiScale
	self.Controller = controller
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
	
	-- Wire toggle click handlers for Settings and Themes
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

	if self.ThemesBtn then
		self.ThemesBtn.MouseButton1Click:Connect(function()
			if self.SettingsTab then
				self:SelectTab(self.SettingsTab)
				for _, subGroup in ipairs(self.SubTabGroups or {}) do
					if subGroup.Tabs and (subGroup.Tabs["Themes & Visuals"] or subGroup.Tabs["Themes"]) then
						subGroup:Select(subGroup.Tabs["Themes & Visuals"] and "Themes & Visuals" or "Themes")
					end
				end
			end
		end)
	end

	if self.ConfigsBtn and self.ConfigsBtn ~= self.ThemesBtn then
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
	local tabButton = Instance.new("TextButton")
	tabButton.Name = name .. "TabBtn"
	tabButton.Size = UDim2.new(0, 80, 1, 0)
	tabButton.AutomaticSize = Enum.AutomaticSize.X
	tabButton.Position = UDim2.new(0, 0, 0, 0)
	tabButton.BackgroundColor3 = UI.Theme.Container
	tabButton.BackgroundTransparency = UI.Theme.ContainerTransparency
	tabButton.BorderSizePixel = 0
	tabButton.Text = name
	tabButton.TextColor3 = UI.Theme.TextSecondary
	tabButton.Font = UI.Fonts.Header
	tabButton.TextSize = 11
	tabButton.TextTruncate = Enum.TextTruncate.AtEnd
	tabButton.ClipsDescendants = false
	tabButton.LayoutOrder = #self.Tabs + 1
	tabButton.Visible = not (isHiddenFromSidebar or false)
	tabButton.Parent = self.Sidebar
	UI.registerThemeElement(tabButton, "Container")
	UI.registerThemeElement(tabButton, "TextSecondary")

	local tabPad = Instance.new("UIPadding")
	tabPad.PaddingLeft = UDim.new(0, 10)
	tabPad.PaddingRight = UDim.new(0, 10)
	tabPad.Parent = tabButton
	
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
	
	local tabStroke = Instance.new("UIStroke")
	tabStroke.Color = UI.Theme.Border
	tabStroke.Thickness = 1.0
	tabStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	tabStroke.Parent = tabButton
	UI.registerThemeElement(tabStroke, "Border")
	
	local tabContent = Instance.new("ScrollingFrame")
	tabContent.Name = name .. "Page"
	tabContent.Size = UDim2.new(1, 0, 1, 0)
	tabContent.Position = UDim2.new(0, 0, 0, 0)
	tabContent.BackgroundTransparency = 1
	tabContent.BorderSizePixel = 0
	tabContent.ScrollBarThickness = 3
	tabContent.ScrollBarImageColor3 = UI.Theme.Accent
	tabContent.Visible = false
	tabContent.ClipsDescendants = true
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
	
	tabButton.MouseEnter:Connect(function()
		if self.ActiveTab ~= tabObj then
			if tabStroke then TweenService:Create(tabStroke, TweenInfo.new(0.12), { Thickness = 1.5 }):Play() end
			TweenService:Create(tabButton, TweenInfo.new(0.12), { BackgroundColor3 = UI.Theme.ContainerDark, TextColor3 = UI.Theme.TextPrimary }):Play()
		end
	end)
	tabButton.MouseLeave:Connect(function()
		if self.ActiveTab ~= tabObj then
			if tabStroke then TweenService:Create(tabStroke, TweenInfo.new(0.12), { Thickness = 1.0 }):Play() end
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
				tab.Button.BackgroundColor3 = UI.Theme.Container
				tab.Button.BackgroundTransparency = UI.Theme.ContainerTransparency
				tab.Button.TextColor3 = UI.Theme.TextSecondary
				tab.Stroke.Color = UI.Theme.Border
				tab.Stroke.Thickness = 1.0
				local grad = tab.Button:FindFirstChild("ActiveGradient") :: UIGradient?
				if grad then grad.Enabled = false end
			end
		end
	end

	-- 2. Show Incoming Tab Page with smooth subtle deceleration
	tabObj.Page.Visible = true
	tabObj.Page.Position = UDim2.new(0, 6, 0, 0)
	TweenService:Create(tabObj.Page, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0)
	}):Play()

	-- 3. Highlight Tab Button if present
	if tabObj.Button and tabObj.Stroke then
		tabObj.Button.BackgroundColor3 = UI.Theme.Accent
		tabObj.Button.BackgroundTransparency = 0
		tabObj.Button.TextColor3 = UI.Theme.AccentText
		tabObj.Stroke.Color = UI.Theme.Border
		tabObj.Stroke.Thickness = 1.2
		
		Animations.pulseIndicator(tabObj.Stroke, UI.Theme.Accent, UI.Theme.Border, 2.0, 1.5)

		local grad = tabObj.Button:FindFirstChild("ActiveGradient") :: UIGradient?
		if grad then grad.Enabled = true end
	end

	self.ActiveTab = tabObj
	if self.ActiveTagLabel then
		self.ActiveTagLabel.Text = tabObj.Name
	end
	if self.StatusLabel then
		self.StatusLabel.Text = tabObj.Name
	end

	-- Subheader buttons active state
	if self.SettingsBtn then
		local isSet = (tabObj == self.SettingsTab)
		self.SettingsBtn.BackgroundColor3 = if isSet then UI.Theme.Accent else UI.Theme.Container
		self.SettingsBtn.BackgroundTransparency = if isSet then 0 else UI.Theme.ContainerTransparency
		self.SettingsBtn.TextColor3 = if isSet then UI.Theme.AccentText else UI.Theme.TextPrimary
	end

	if self.ConfigsBtn then
		local isConf = (tabObj == self.ConfigsTab)
		self.ConfigsBtn.BackgroundColor3 = if isConf then UI.Theme.Accent else UI.Theme.Container
		self.ConfigsBtn.BackgroundTransparency = if isConf then 0 else UI.Theme.ContainerTransparency
		self.ConfigsBtn.TextColor3 = if isConf then UI.Theme.AccentText else UI.Theme.TextPrimary
	end

	if tabObj.OnSelected then
		pcall(tabObj.OnSelected)
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

	-- If parent tab page is a ScrollingFrame, disable outer scroll so subpage/columns control scrolling
	if parentPage:IsA("ScrollingFrame") then
		parentPage.ScrollBarThickness = 0
		parentPage.AutomaticCanvasSize = Enum.AutomaticSize.None
	end

	-- 1. Horizontal Sub-Tab Bar Container (LayoutOrder = 1)
	local subTabBar = Instance.new("Frame")
	subTabBar.Name = "SubTabBar"
	subTabBar.Size = UDim2.new(1, 0, 0, 24)
	subTabBar.Position = UDim2.new(0, 0, 0, 0)
	subTabBar.BackgroundColor3 = UI.Theme.ContainerDark
	subTabBar.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	subTabBar.BorderSizePixel = 0
	subTabBar.LayoutOrder = 1
	subTabBar.ClipsDescendants = false
	subTabBar.Parent = parentPage
	UI.registerThemeElement(subTabBar, "ContainerDark")

	local barStroke = Instance.new("UIStroke")
	barStroke.Color = UI.Theme.Border
	barStroke.Thickness = 1.0
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
	subPagesContainer.Size = UDim2.new(1, 0, 1, -28)
	subPagesContainer.Position = UDim2.new(0, 0, 0, 28)
	subPagesContainer.BackgroundTransparency = 1
	subPagesContainer.BorderSizePixel = 0
	subPagesContainer.LayoutOrder = 2
	subPagesContainer.ClipsDescendants = true
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
		btnStroke.Thickness = if idx == 1 then 1.2 else 1.0
		btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		btnStroke.Parent = btn

		-- Sub-Tab Page
		local page = Instance.new("Frame")
		page.Name = name .. "SubPage"
		page.Size = UDim2.new(1, 0, 1, 0)
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.Visible = (idx == 1)
		page.ClipsDescendants = true
		page.LayoutOrder = idx
		page.Parent = subPagesContainer

		local pageLayout = Instance.new("UIListLayout")
		pageLayout.Padding = UDim.new(0, 6)
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
			TweenService:Create(targetObj.Button, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = UI.Theme.Accent,
				BackgroundTransparency = 0,
				TextColor3 = UI.Theme.AccentText
			}):Play()
			
			-- Active sub-tab indicator pulse
			Animations.pulseIndicator(targetObj.Stroke, UI.Theme.Accent, UI.Theme.Border, 2.0, 1.5)
			
			if targetObj.Gradient then targetObj.Gradient.Enabled = true end
		end

		-- Activate New SubTab Page with smooth subtle slide
		targetObj.Page.Visible = true
		targetObj.Page.Position = UDim2.new(0, 6, 0, 0)
		TweenService:Create(targetObj.Page, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 0)
		}):Play()

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

function CoreUI:CreateColumns(tabObj: any, leftTitle: string?, rightTitle: string?): (Frame, Frame)
	local parentPage: GuiObject? = if type(tabObj) == "table" and tabObj.Page then tabObj.Page elseif typeof(tabObj) == "Instance" and tabObj:IsA("GuiObject") then tabObj else nil
	if not parentPage then
		error("[CoreUI:CreateColumns] Expected tabObj table or GuiObject instance.")
	end

	-- If parent page is a ScrollingFrame, disable outer scroll so columns control their own scrolling
	if parentPage:IsA("ScrollingFrame") then
		parentPage.ScrollBarThickness = 0
		parentPage.AutomaticCanvasSize = Enum.AutomaticSize.None
	end

	local columnsContainer = Instance.new("Frame")
	columnsContainer.Name = "ColumnsContainer"
	columnsContainer.Size = UDim2.new(1, 0, 1, 0)
	columnsContainer.Position = UDim2.new(0, 0, 0, 0)
	columnsContainer.BackgroundTransparency = 1
	columnsContainer.BorderSizePixel = 0
	columnsContainer.ClipsDescendants = true
	columnsContainer.Parent = parentPage

	-- ── Left Column Card (fills 50% width and full height) ───────────
	local leftCard = Instance.new("Frame")
	leftCard.Name = "LeftCard"
	leftCard.Size = UDim2.new(0.5, -4, 1, 0)
	leftCard.Position = UDim2.new(0, 0, 0, 0)
	leftCard.BackgroundColor3 = UI.Theme.ContainerDark
	leftCard.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	leftCard.BorderSizePixel = 0
	leftCard.ClipsDescendants = true
	leftCard.Parent = columnsContainer
	UI.registerThemeElement(leftCard, "ContainerDark")

	local leftCardStroke = Instance.new("UIStroke")
	leftCardStroke.Color = UI.Theme.Border
	leftCardStroke.Thickness = 1.0
	leftCardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	leftCardStroke.Parent = leftCard
	UI.registerThemeElement(leftCardStroke, "Border")

	local leftTopOffset = 0
	local leftHeaderLabel: TextLabel? = nil
	if leftTitle and leftTitle ~= "" and leftTitle ~= "Side Tab" then
		leftTopOffset = 24
		local leftHeaderBox = Instance.new("Frame")
		leftHeaderBox.Name = "HeaderBox"
		leftHeaderBox.Size = UDim2.new(1, 0, 0, 22)
		leftHeaderBox.Position = UDim2.new(0, 0, 0, 0)
		leftHeaderBox.BackgroundColor3 = UI.Theme.Container
		leftHeaderBox.BackgroundTransparency = UI.Theme.ContainerTransparency
		leftHeaderBox.BorderSizePixel = 0
		leftHeaderBox.Parent = leftCard
		UI.registerThemeElement(leftHeaderBox, "Container")

		local leftHeaderStroke = Instance.new("UIStroke")
		leftHeaderStroke.Color = UI.Theme.Border
		leftHeaderStroke.Thickness = 1.0
		leftHeaderStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		leftHeaderStroke.Parent = leftHeaderBox
		UI.registerThemeElement(leftHeaderStroke, "Border")

		leftHeaderLabel = Instance.new("TextLabel")
		leftHeaderLabel.Name = "HeaderLabel"
		leftHeaderLabel.Size = UDim2.new(1, -8, 1, 0)
		leftHeaderLabel.Position = UDim2.new(0, 4, 0, 0)
		leftHeaderLabel.BackgroundTransparency = 1
		leftHeaderLabel.Text = string.format("Section (%s)", leftTitle)
		leftHeaderLabel.TextColor3 = UI.Theme.TextPrimary
		leftHeaderLabel.Font = UI.Fonts.Header
		leftHeaderLabel.TextSize = 11
		leftHeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
		leftHeaderLabel.Parent = leftHeaderBox
		UI.registerThemeElement(leftHeaderLabel, "TextPrimary")
	end

	-- Scalable Scrolling Content Area in Left Card
	local leftScroll = Instance.new("ScrollingFrame")
	leftScroll.Name = "LeftScroll"
	leftScroll.Size = UDim2.new(1, 0, 1, -leftTopOffset)
	leftScroll.Position = UDim2.new(0, 0, 0, leftTopOffset)
	leftScroll.BackgroundTransparency = 1
	leftScroll.BorderSizePixel = 0
	leftScroll.ScrollBarThickness = 2
	leftScroll.ScrollBarImageColor3 = UI.Theme.Accent
	leftScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	leftScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	leftScroll.ClipsDescendants = true
	leftScroll.Parent = leftCard

	local leftCardPad = Instance.new("UIPadding")
	leftCardPad.PaddingLeft = UDim.new(0, 6)
	leftCardPad.PaddingRight = UDim.new(0, 6)
	leftCardPad.PaddingTop = UDim.new(0, 6)
	leftCardPad.PaddingBottom = UDim.new(0, 8)
	leftCardPad.Parent = leftScroll

	local leftLayout = Instance.new("UIListLayout")
	leftLayout.Padding = UDim.new(0, 6)
	leftLayout.SortOrder = Enum.SortOrder.LayoutOrder
	leftLayout.Parent = leftScroll

	-- ── Right Column Card ────────────────────────────────────────────
	local rightCard = Instance.new("Frame")
	rightCard.Name = "RightCard"
	rightCard.Size = UDim2.new(0.5, -4, 1, 0)
	rightCard.Position = UDim2.new(0.5, 4, 0, 0)
	rightCard.BackgroundColor3 = UI.Theme.ContainerDark
	rightCard.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	rightCard.BorderSizePixel = 0
	rightCard.ClipsDescendants = true
	rightCard.Parent = columnsContainer
	UI.registerThemeElement(rightCard, "ContainerDark")

	local rightCardStroke = Instance.new("UIStroke")
	rightCardStroke.Color = UI.Theme.Border
	rightCardStroke.Thickness = 1.0
	rightCardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rightCardStroke.Parent = rightCard
	UI.registerThemeElement(rightCardStroke, "Border")

	local rightTopOffset = 0
	local rightHeaderLabel: TextLabel? = nil
	if rightTitle and rightTitle ~= "" and rightTitle ~= "Side Tab" then
		rightTopOffset = 24
		local rightHeaderBox = Instance.new("Frame")
		rightHeaderBox.Name = "HeaderBox"
		rightHeaderBox.Size = UDim2.new(1, 0, 0, 22)
		rightHeaderBox.Position = UDim2.new(0, 0, 0, 0)
		rightHeaderBox.BackgroundColor3 = UI.Theme.Container
		rightHeaderBox.BackgroundTransparency = UI.Theme.ContainerTransparency
		rightHeaderBox.BorderSizePixel = 0
		rightHeaderBox.Parent = rightCard
		UI.registerThemeElement(rightHeaderBox, "Container")

		local rightHeaderStroke = Instance.new("UIStroke")
		rightHeaderStroke.Color = UI.Theme.Border
		rightHeaderStroke.Thickness = 1.0
		rightHeaderStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		rightHeaderStroke.Parent = rightHeaderBox
		UI.registerThemeElement(rightHeaderStroke, "Border")

		rightHeaderLabel = Instance.new("TextLabel")
		rightHeaderLabel.Name = "HeaderLabel"
		rightHeaderLabel.Size = UDim2.new(1, -8, 1, 0)
		rightHeaderLabel.Position = UDim2.new(0, 4, 0, 0)
		rightHeaderLabel.BackgroundTransparency = 1
		rightHeaderLabel.Text = string.format("Section (%s)", rightTitle)
		rightHeaderLabel.TextColor3 = UI.Theme.TextPrimary
		rightHeaderLabel.Font = UI.Fonts.Header
		rightHeaderLabel.TextSize = 11
		rightHeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
		rightHeaderLabel.Parent = rightHeaderBox
		UI.registerThemeElement(rightHeaderLabel, "TextPrimary")
	end

	local rightScroll = Instance.new("ScrollingFrame")
	rightScroll.Name = "RightScroll"
	rightScroll.Size = UDim2.new(1, 0, 1, -rightTopOffset)
	rightScroll.Position = UDim2.new(0, 0, 0, rightTopOffset)
	rightScroll.BackgroundTransparency = 1
	rightScroll.BorderSizePixel = 0
	rightScroll.ScrollBarThickness = 2
	rightScroll.ScrollBarImageColor3 = UI.Theme.Accent
	rightScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	rightScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rightScroll.ClipsDescendants = true
	rightScroll.Parent = rightCard

	local rightCardPad = Instance.new("UIPadding")
	rightCardPad.PaddingLeft = UDim.new(0, 6)
	rightCardPad.PaddingRight = UDim.new(0, 6)
	rightCardPad.PaddingTop = UDim.new(0, 6)
	rightCardPad.PaddingBottom = UDim.new(0, 8)
	rightCardPad.Parent = rightScroll

	local rightLayout = Instance.new("UIListLayout")
	rightLayout.Padding = UDim.new(0, 6)
	rightLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rightLayout.Parent = rightScroll

	if type(tabObj) == "table" then
		tabObj.LeftColumn = leftScroll
		tabObj.RightColumn = rightScroll
		tabObj.LeftHeaderLabel = leftHeaderLabel
		tabObj.RightHeaderLabel = rightHeaderLabel
	end

	return leftScroll, rightScroll
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
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = section

	local displayTitle = if string.sub(title, 1, 8) == "Section " then title else string.format("Section (%s)", title)

	-- clean minimal section header: Section (cheat type)
	local headerBox = Instance.new("Frame")
	headerBox.Name = "HeaderBox"
	headerBox.Size = UDim2.new(1, 0, 0, 22)
	headerBox.Position = UDim2.new(0, 0, 0, 0)
	headerBox.BackgroundColor3 = UI.Theme.Container
	headerBox.BackgroundTransparency = UI.Theme.ContainerTransparency
	headerBox.BorderSizePixel = 0
	headerBox.Parent = section
	UI.registerThemeElement(headerBox, "Container")

	local headerStroke = Instance.new("UIStroke")
	headerStroke.Color = UI.Theme.Border
	headerStroke.Thickness = 1.0
	headerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	headerStroke.Parent = headerBox
	UI.registerThemeElement(headerStroke, "Border")

	local headerLabel = Instance.new("TextLabel")
	headerLabel.Size = UDim2.new(1, -8, 1, 0)
	headerLabel.Position = UDim2.new(0, 4, 0, 0)
	headerLabel.BackgroundTransparency = 1
	headerLabel.Text = displayTitle
	headerLabel.TextColor3 = UI.Theme.TextPrimary
	headerLabel.Font = UI.Fonts.Header
	headerLabel.TextSize = 11
	headerLabel.TextXAlignment = Enum.TextXAlignment.Left
	headerLabel.Parent = headerBox
	UI.registerThemeElement(headerLabel, "TextPrimary")

	return section
end

-- 3-Segment Toggle Row: [ X ] Option Name [ Bind ]
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
	checkStroke.Thickness = 1.0
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

	-- Segment 2: Option Name (Clean label without nested box/outline)
	local titleBox = Instance.new("TextButton")
	titleBox.Name = "TitleBox"
	titleBox.Size = UDim2.new(1, -90, 0, 24)
	titleBox.Position = UDim2.new(0, 28, 0, 0)
	titleBox.BackgroundTransparency = 1
	titleBox.BorderSizePixel = 0
	titleBox.ClipsDescendants = true
	titleBox.Text = ""
	titleBox.Parent = row

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -6, 1, 0)
	titleLabel.Position = UDim2.new(0, 4, 0, 0)
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
	bindStroke.Thickness = 1.0
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

	-- Hover animations on toggle components
	local function onToggleHoverEnter()
		TweenService:Create(checkStroke, TweenInfo.new(0.12), { Thickness = 1.4, Color = UI.Theme.Accent }):Play()
		TweenService:Create(bindStroke, TweenInfo.new(0.12), { Thickness = 1.4, Color = UI.Theme.Accent }):Play()
		TweenService:Create(titleLabel, TweenInfo.new(0.12), { TextColor3 = UI.Theme.Accent }):Play()
	end

	local function onToggleHoverLeave()
		TweenService:Create(checkStroke, TweenInfo.new(0.12), { Thickness = 1.0, Color = UI.Theme.Border }):Play()
		TweenService:Create(bindStroke, TweenInfo.new(0.12), { Thickness = 1.0, Color = UI.Theme.Border }):Play()
		TweenService:Create(titleLabel, TweenInfo.new(0.12), { TextColor3 = UI.Theme.TextPrimary }):Play()
	end

	titleBox.MouseEnter:Connect(onToggleHoverEnter)
	titleBox.MouseLeave:Connect(onToggleHoverLeave)
	checkBtn.MouseEnter:Connect(onToggleHoverEnter)
	checkBtn.MouseLeave:Connect(onToggleHoverLeave)
	keybindBtn.MouseEnter:Connect(onToggleHoverEnter)
	keybindBtn.MouseLeave:Connect(onToggleHoverLeave)

	-- Synchronize visual state when toggled via keyboard keybind or external call
	local function onStateChangedListener(newState: boolean)
		updateToggleVisual(newState)
		Notification.notifyFeature(name, newState)
	end
	if feature.stateListeners then
		table.insert(feature.stateListeners, onStateChangedListener)
	else
		feature.onStateChanged = onStateChangedListener
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

	local function onKeybindChangedListener(newKey)
		keybindBtn.Text = if newKey then string.format("[%s]", newKey.Name) else "[None]"
	end
	if feature.keybindListeners then
		table.insert(feature.keybindListeners, onKeybindChangedListener)
	else
		feature.onKeybindChanged = onKeybindChangedListener
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
	row.Size = UDim2.new(1, -4, 0, 44)
	row.Position = UDim2.new(0, 2, 0, 0)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.ClipsDescendants = false
	row.Parent = section

	-- header line: Option Name + [ Val ]
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -52, 0, 20)
	titleLabel.Position = UDim2.new(0, 2, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = name
	titleLabel.TextColor3 = UI.Theme.TextPrimary
	titleLabel.Font = UI.Fonts.Body
	titleLabel.TextSize = 11
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.ClipsDescendants = true
	titleLabel.Parent = row
	UI.registerThemeElement(titleLabel, "TextPrimary")

	local valBox = Instance.new("Frame")
	valBox.Name = "ValBox"
	valBox.Size = UDim2.new(0, 48, 0, 20)
	valBox.Position = UDim2.new(1, -48, 0, 0)
	valBox.BackgroundColor3 = UI.Theme.Container
	valBox.BackgroundTransparency = UI.Theme.ContainerTransparency
	valBox.BorderSizePixel = 0
	valBox.ClipsDescendants = true
	valBox.Parent = row
	UI.registerThemeElement(valBox, "Container")

	local valStroke = Instance.new("UIStroke")
	valStroke.Color = UI.Theme.Border
	valStroke.Thickness = 1.0
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
	bar.Position = UDim2.new(0, 0, 0, 24)
	bar.BackgroundColor3 = UI.Theme.ContainerDark
	bar.BackgroundTransparency = UI.Theme.ContainerDarkTransparency
	bar.BorderSizePixel = 0
	bar.Parent = row
	UI.registerThemeElement(bar, "ContainerDark")

	local barStroke = Instance.new("UIStroke")
	barStroke.Color = UI.Theme.Border
	barStroke.Thickness = 1.0
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

	local currentVal = initialValue
	local dragConn: RBXScriptConnection? = nil
	local releaseConn: RBXScriptConnection? = nil

	local function applyValue(val: number, isDragging: boolean?)
		if val ~= currentVal then
			currentVal = val
			valLabel.Text = tostring(val)
			valLabel.TextColor3 = UI.Theme.Accent
		end
		local ratio = math.clamp((val - min) / (max - min), 0, 1)
		if isDragging then
			fill.Size = UDim2.new(ratio, 0, 1, 0)
		else
			fill.Size = UDim2.new(ratio, 0, 1, 0)
		end
	end

	local function update(input: InputObject)
		local barWidth = bar.AbsoluteSize.X
		if barWidth <= 0 then return end
		local ratio = math.clamp((input.Position.X - bar.AbsolutePosition.X) / barWidth, 0, 1)
		local rawVal = min + (max - min) * ratio
		local val = math.floor(rawVal + 0.5)
		if val ~= currentVal then
			applyValue(val, true)
			FeatureManager.setSliderValue(name, val)
		end
	end

	sliderRecord.onValueChanged = function(newVal: number)
		applyValue(newVal, false)
	end

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			update(input)
			if dragConn then dragConn:Disconnect() end
			if releaseConn then releaseConn:Disconnect() end

			dragConn = UserInputService.InputChanged:Connect(function(moveInput)
				if moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch then
					update(moveInput)
				end
			end)

			releaseConn = UserInputService.InputEnded:Connect(function(endInput)
				if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
					if dragConn then dragConn:Disconnect() dragConn = nil end
					if releaseConn then releaseConn:Disconnect() releaseConn = nil end
				end
			end)
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

	-- Zero-lag instant button micro-squash and border feedback
	local btnScale = Instance.new("UIScale")
	btnScale.Scale = 1.0
	btnScale.Parent = btn

	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = UI.Theme.ContainerDark
		btnStroke.Color = UI.Theme.Accent
		btnStroke.Thickness = 1.6
	end)

	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = UI.Theme.Container
		btnStroke.Color = UI.Theme.Border
		btnStroke.Thickness = 1.2
		btnScale.Scale = 1.0
	end)

	btn.MouseButton1Down:Connect(function()
		btnScale.Scale = 0.95
		btn.BackgroundColor3 = UI.Theme.Accent
		btn.TextColor3 = UI.Theme.AccentText
	end)

	btn.MouseButton1Up:Connect(function()
		btnScale.Scale = 1.0
		btn.BackgroundColor3 = UI.Theme.ContainerDark
		btn.TextColor3 = UI.Theme.TextPrimary
	end)

	btn.MouseButton1Click:Connect(function()
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
