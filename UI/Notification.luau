--!strict
--[=[
    ✦ Squared Retro Notification System ✦
    Renders pixel-perfect themed notification popups matching the squared wireframe aesthetic.
]=]

local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

local UI = require("UI/UI.luau")

local Notification = {}
Notification.__index = Notification

local notifGui: ScreenGui? = nil
local notifHolder: Frame? = nil

local function getNotificationHolder(): Frame
	if not notifHolder or not notifHolder.Parent then
		notifGui = Instance.new("ScreenGui")
		notifGui.Name = "ModularNotificationsGui"
		notifGui.ResetOnSpawn = false
		notifGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		
		pcall(function()
			notifGui.Parent = CoreGui
		end)
		if not notifGui.Parent then
			notifGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		end
		
		local holder = Instance.new("Frame")
		holder.Name = "NotificationHolder"
		holder.Size = UDim2.new(0, 280, 1, -40)
		holder.Position = UDim2.new(1, -290, 0, 20)
		holder.BackgroundTransparency = 1
		holder.BorderSizePixel = 0
		holder.ClipsDescendants = false
		holder.Parent = notifGui
		
		local list = Instance.new("UIListLayout")
		list.HorizontalAlignment = Enum.HorizontalAlignment.Right
		list.VerticalAlignment = Enum.VerticalAlignment.Bottom
		list.Padding = UDim.new(0, 8)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = holder
		
		notifHolder = holder
	end
	return notifHolder :: Frame
end

function Notification.show(title: string, message: string, duration: number?)
	local holder = getNotificationHolder()
	local displayTime = duration or 2.5
	
	local card = Instance.new("Frame")
	card.Name = "NotificationCard"
	card.Size = UDim2.new(1, 0, 0, 68)
	card.Position = UDim2.new(1, 40, 0, 0)
	card.BackgroundColor3 = UI.Theme.Background
	card.BackgroundTransparency = UI.Theme.BackgroundTransparency
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	UI.registerThemeElement(card, "Background")
	
	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = UI.Theme.Border
	cardStroke.Thickness = 1.5
	cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cardStroke.Parent = card
	UI.registerThemeElement(cardStroke, "Border")
	
	-- topbar
	local topbar = Instance.new("Frame")
	topbar.Name = "TopBar"
	topbar.Size = UDim2.new(1, 0, 0, 20)
	topbar.Position = UDim2.new(0, 0, 0, 0)
	topbar.BackgroundColor3 = UI.Theme.Container
	topbar.BackgroundTransparency = UI.Theme.ContainerTransparency
	topbar.BorderSizePixel = 0
	topbar.Parent = card
	UI.registerThemeElement(topbar, "Container")
	
	local topTitle = Instance.new("TextLabel")
	topTitle.Size = UDim2.new(1, -48, 1, 0)
	topTitle.Position = UDim2.new(0, 6, 0, 0)
	topTitle.BackgroundTransparency = 1
	topTitle.Text = title or "New Notification!"
	topTitle.TextColor3 = UI.Theme.TextPrimary
	topTitle.Font = UI.Fonts.Header
	topTitle.TextSize = 11
	topTitle.TextXAlignment = Enum.TextXAlignment.Left
	topTitle.Parent = topbar
	UI.registerThemeElement(topTitle, "TextPrimary")
	
	-- topbar icons: [-] and [□]
	local minIcon = Instance.new("TextLabel")
	minIcon.Size = UDim2.new(0, 16, 1, 0)
	minIcon.Position = UDim2.new(1, -36, 0, 0)
	minIcon.BackgroundTransparency = 1
	minIcon.Text = "—"
	minIcon.TextColor3 = UI.Theme.TextPrimary
	minIcon.Font = UI.Fonts.Header
	minIcon.TextSize = 11
	minIcon.Parent = topbar
	UI.registerThemeElement(minIcon, "TextPrimary")
	
	local sqIcon = Instance.new("TextLabel")
	sqIcon.Size = UDim2.new(0, 16, 1, 0)
	sqIcon.Position = UDim2.new(1, -18, 0, 0)
	sqIcon.BackgroundTransparency = 1
	sqIcon.Text = "□"
	sqIcon.TextColor3 = UI.Theme.TextPrimary
	sqIcon.Font = UI.Fonts.Header
	sqIcon.TextSize = 11
	sqIcon.Parent = topbar
	UI.registerThemeElement(sqIcon, "TextPrimary")
	
	-- top divider
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Size = UDim2.new(1, 0, 0, 1.5)
	divider.Position = UDim2.new(0, 0, 0, 20)
	divider.BackgroundColor3 = UI.Theme.Border
	divider.BorderSizePixel = 0
	divider.Parent = card
	UI.registerThemeElement(divider, "Border")
	
	-- message body
	local bodyLabel = Instance.new("TextLabel")
	bodyLabel.Name = "Message"
	bodyLabel.Size = UDim2.new(1, -16, 1, -22)
	bodyLabel.Position = UDim2.new(0, 8, 0, 21)
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.Text = message
	bodyLabel.TextColor3 = UI.Theme.TextPrimary
	bodyLabel.Font = UI.Fonts.Header
	bodyLabel.TextSize = 13
	bodyLabel.TextXAlignment = Enum.TextXAlignment.Center
	bodyLabel.Parent = card
	UI.registerThemeElement(bodyLabel, "TextPrimary")
	
	card.Parent = holder
	
	-- Slide In Animation
	card.Position = UDim2.new(1, 60, 0, 0)
	local tweenIn = TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0)
	})
	tweenIn:Play()
	
	-- Auto Dismiss
	task.delay(displayTime, function()
		if card and card.Parent then
			local tweenOut = TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(1, 60, 0, 0),
				BackgroundTransparency = 1
			})
			tweenOut:Play()
			tweenOut.Completed:Connect(function()
				card:Destroy()
			end)
		end
	end)
end

function Notification.notifyFeature(featureName: string, state: boolean)
	local stateText = if state then "Enabled !" else "Disabled !"
	Notification.show("New Notification!", string.format("%s %s", featureName, stateText))
end

return Notification
