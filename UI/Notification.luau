--!strict
--[=[
    ✦ Squared Retro Notification System ✦
    Renders pixel-perfect themed notification popups matching the user mockup.
]=]

local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

local UI = require("UI/UI.luau")
local Animations = require("UI/Animations.luau")

local Notification = {}
Notification.__index = Notification

local notifGui: ScreenGui? = nil
local activeCards: {Frame} = {}

local function getNotificationGui(): ScreenGui
	if not notifGui or not notifGui.Parent then
		notifGui = Instance.new("ScreenGui")
		notifGui.Name = "ModularNotificationsGui"
		notifGui.ResetOnSpawn = false
		notifGui.DisplayOrder = 9999
		notifGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		
		pcall(function()
			notifGui.Parent = CoreGui
		end)
		if not notifGui.Parent then
			notifGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		end
	end
	return notifGui :: ScreenGui
end

local function repositionCards()
	for i, card in ipairs(activeCards) do
		local targetY = -20 - (i * 80)
		TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(1, -280, 1, targetY)
		}):Play()
	end
end

function Notification.show(title: string, message: string, duration: number?)
	local gui = getNotificationGui()
	local displayTime = duration or 3.8
	
	local card = Instance.new("Frame")
	card.Name = "NotificationCard"
	card.Size = UDim2.new(0, 260, 0, 74)
	card.Position = UDim2.new(1, 40, 1, -20 - (#activeCards + 1) * 80)
	card.BackgroundColor3 = UI.Theme.Background
	card.BackgroundTransparency = UI.Theme.BackgroundTransparency
	card.BorderSizePixel = 0
	card.ClipsDescendants = false
	card.Parent = gui
	UI.registerThemeElement(card, "Background")
	
	local bgGradient = Instance.new("UIGradient")
	bgGradient.Rotation = 90
	bgGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 200, 210))
	})
	bgGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0.15)
	})
	bgGradient.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = UI.Theme.Border
	cardStroke.Thickness = 2
	cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cardStroke.Parent = card
	UI.registerThemeElement(cardStroke, "Border")

	local cardScale = Instance.new("UIScale")
	cardScale.Scale = 0.92
	cardScale.Parent = card
	
	-- Inset Topbar
	local topbar = Instance.new("Frame")
	topbar.Name = "TopBar"
	topbar.Size = UDim2.new(1, -12, 0, 22)
	topbar.Position = UDim2.new(0, 6, 0, 6)
	topbar.BackgroundColor3 = UI.Theme.Container
	topbar.BackgroundTransparency = UI.Theme.ContainerTransparency
	topbar.BorderSizePixel = 0
	topbar.Parent = card
	UI.registerThemeElement(topbar, "Container")

	local topGradient = Instance.new("UIGradient")
	topGradient.Rotation = 45
	topGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 220, 230))
	})
	topGradient.Parent = topbar

	local topStroke = Instance.new("UIStroke")
	topStroke.Color = UI.Theme.Border
	topStroke.Thickness = 1.5
	topStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	topStroke.Parent = topbar
	UI.registerThemeElement(topStroke, "Border")
	
	local topTitle = Instance.new("TextLabel")
	topTitle.Size = UDim2.new(1, -44, 1, 0)
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
	minIcon.Size = UDim2.new(0, 14, 1, 0)
	minIcon.Position = UDim2.new(1, -32, 0, 0)
	minIcon.BackgroundTransparency = 1
	minIcon.Text = "—"
	minIcon.TextColor3 = UI.Theme.TextPrimary
	minIcon.Font = UI.Fonts.Header
	minIcon.TextSize = 11
	minIcon.Parent = topbar
	UI.registerThemeElement(minIcon, "TextPrimary")
	
	local sqIcon = Instance.new("TextLabel")
	sqIcon.Size = UDim2.new(0, 14, 1, 0)
	sqIcon.Position = UDim2.new(1, -16, 0, 0)
	sqIcon.BackgroundTransparency = 1
	sqIcon.Text = "□"
	sqIcon.TextColor3 = UI.Theme.TextPrimary
	sqIcon.Font = UI.Fonts.Header
	sqIcon.TextSize = 11
	sqIcon.Parent = topbar
	UI.registerThemeElement(sqIcon, "TextPrimary")
	
	-- message body
	local bodyLabel = Instance.new("TextLabel")
	bodyLabel.Name = "Message"
	bodyLabel.Size = UDim2.new(1, -16, 1, -34)
	bodyLabel.Position = UDim2.new(0, 8, 0, 32)
	bodyLabel.BackgroundTransparency = 1
	bodyLabel.Text = message
	bodyLabel.TextColor3 = UI.Theme.TextPrimary
	bodyLabel.Font = UI.Fonts.Header
	bodyLabel.TextSize = 12
	bodyLabel.TextXAlignment = Enum.TextXAlignment.Center
	bodyLabel.Parent = card
	UI.registerThemeElement(bodyLabel, "TextPrimary")
	
	table.insert(activeCards, 1, card)
	repositionCards()
	
	-- Slide in from right with spring pop-in (0.92 -> 1.0)
	card.Position = UDim2.new(1, 40, 1, -20 - 80)
	TweenService:Create(cardScale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1.0
	}):Play()
	TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(1, -280, 1, -20 - 80)
	}):Play()
	
	task.delay(displayTime, function()
		if card and card.Parent then
			local idx = table.find(activeCards, card)
			if idx then
				table.remove(activeCards, idx)
			end
			repositionCards()
			
			TweenService:Create(cardScale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Scale = 0.92
			}):Play()

			for _, desc in ipairs(card:GetDescendants()) do
				if desc:IsA("TextLabel") or desc:IsA("TextButton") then
					TweenService:Create(desc, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						TextTransparency = 1
					}):Play()
				elseif desc:IsA("Frame") then
					TweenService:Create(desc, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						BackgroundTransparency = 1
					}):Play()
				elseif desc:IsA("UIStroke") then
					TweenService:Create(desc, TweenInfo.new(0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						Transparency = 1
					}):Play()
				end
			end

			local tweenOut = TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(1, 40, card.Position.Y.Scale, card.Position.Y.Offset),
				BackgroundTransparency = 1
			})
			tweenOut:Play()

			local compConn: RBXScriptConnection? = nil
			compConn = tweenOut.Completed:Connect(function()
				if compConn then
					compConn:Disconnect()
					compConn = nil
				end
				for _, desc in ipairs(card:GetDescendants()) do
					UI.unregisterThemeElement(desc)
				end
				UI.unregisterThemeElement(card)
				card:Destroy()
			end)
		end
	end)
end

function Notification.cleanup()
	for _, card in ipairs(activeCards) do
		if card and card.Parent then
			for _, desc in ipairs(card:GetDescendants()) do
				UI.unregisterThemeElement(desc)
			end
			UI.unregisterThemeElement(card)
			card:Destroy()
		end
	end
	table.clear(activeCards)
	if notifGui then
		pcall(function() notifGui:Destroy() end)
		notifGui = nil
	end
end

function Notification.notifyFeature(featureName: string, state: boolean)
	local stateText = if state then "Option Enabled !" else "Option Disabled !"
	Notification.show("New Notification!", string.format("%s: %s", featureName, stateText))
end

return Notification
