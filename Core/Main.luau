--!strict
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VoiceChatService = game:GetService("VoiceChatService")
local TextChatService = game:GetService("TextChatService")

local UI = require("UI/UI.luau")
local CoreUI = require("Core/CoreUI.luau")
local FeatureManager = require("Core/FeatureManager.luau")
local PlayerList = require("UI/PlayerList.luau")
local ChatWidget = require("UI/ChatWidget.luau")
local MusicTracker = require("UI/MusicTracker.luau")
local Visuals = require("Modules/Visuals.luau")
local Combat = require("Modules/Combat.luau")
local DisasterSurvival = require("Modules/DisasterSurvival.luau")
local RunNHide = require("Modules/RunNHide.luau")
local IceTycoon = require("Modules/IceTycoon.luau")
local LuckyBlocks = require("Modules/LuckyBlocks.luau")
local RestaurantTycoon = require("Modules/RestaurantTycoon.luau")
local SeekerVsHider = require("Modules/SeekerVsHider.luau")
local PlayerUtilities = require("Modules/PlayerUtilities.luau")
local Hotbar = require("UI/Hotbar.luau")
local Notification = require("UI/Notification.luau")
local LeaderstatsWidget = require("UI/LeaderstatsWidget.luau")
local HealthWidget = require("UI/HealthWidget.luau")

local localPlayer = Players.LocalPlayer
local character = localPlayer.Character
local humanoid: Humanoid? = if character then character:FindFirstChildOfClass("Humanoid") else nil

local cachedCharacterParts: {BasePart} = {}
local charDescendantAddedConn: RBXScriptConnection? = nil
local charDescendantRemovingConn: RBXScriptConnection? = nil

local function updateCachedCharacterParts(char: Model?)
	table.clear(cachedCharacterParts)
	if charDescendantAddedConn then
		charDescendantAddedConn:Disconnect()
		charDescendantAddedConn = nil
	end
	if charDescendantRemovingConn then
		charDescendantRemovingConn:Disconnect()
		charDescendantRemovingConn = nil
	end

	if not char then return end

	for _, inst in ipairs(char:GetDescendants()) do
		if inst:IsA("BasePart") and not inst:FindFirstAncestorWhichIsA("Tool") and not inst:FindFirstAncestorWhichIsA("Accessory") then
			table.insert(cachedCharacterParts, inst)
		end
	end

	charDescendantAddedConn = char.DescendantAdded:Connect(function(inst)
		if inst:IsA("BasePart") and not inst:FindFirstAncestorWhichIsA("Tool") and not inst:FindFirstAncestorWhichIsA("Accessory") then
			table.insert(cachedCharacterParts, inst)
		end
	end)

	charDescendantRemovingConn = char.DescendantRemoving:Connect(function(inst)
		if inst:IsA("BasePart") then
			local idx = table.find(cachedCharacterParts, inst)
			if idx then
				table.remove(cachedCharacterParts, idx)
			end
		end
	end)
end

if character then
	updateCachedCharacterParts(character)
end

localPlayer.CharacterAdded:Connect(function(char)
	character = char
	humanoid = char:WaitForChild("Humanoid", 5) :: Humanoid?
	updateCachedCharacterParts(char)
end)

-- Disable overlapping default CoreGui elements and native Roblox TopBarApp
local coreGuiOverlays = {
	Enum.CoreGuiType.All,
	Enum.CoreGuiType.PlayerList,
	Enum.CoreGuiType.Chat,
	Enum.CoreGuiType.EmotesMenu,
	Enum.CoreGuiType.Backpack,
	Enum.CoreGuiType.Health,
}

local isRobloxCoreHidden = false
_G.__ModularSuite_IsRobloxCoreHidden = false

local function disableRobloxTopBarApp(disable: boolean)
	isRobloxCoreHidden = disable
	_G.__ModularSuite_IsRobloxCoreHidden = disable
	pcall(function()
		StarterGui:SetCore("TopbarEnabled", not disable)
	end)
	pcall(function()
		local topBarApp = CoreGui:FindFirstChild("TopBarApp")
		if topBarApp then
			for _, child in ipairs(topBarApp:GetChildren()) do
				if child:IsA("ScreenGui") then
					child.Enabled = not disable
				elseif child:IsA("GuiObject") then
					child.Visible = not disable
				end
			end
		end
		local robloxGui = CoreGui:FindFirstChild("RobloxGui")
		if robloxGui then
			local tb = robloxGui:FindFirstChild("TopBar") or robloxGui:FindFirstChild("TopBarContainer") or robloxGui:FindFirstChild("TopBarApp")
			if tb and tb:IsA("GuiObject") then
				tb.Visible = not disable
			end
		end
	end)
end

local function setRobloxCoreHidden(hide: boolean)
	isRobloxCoreHidden = hide
	_G.__ModularSuite_IsRobloxCoreHidden = hide
	disableRobloxTopBarApp(hide)
	for _, guiType in ipairs(coreGuiOverlays) do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(guiType, not hide)
		end)
	end
	pcall(function()
		local expChat = CoreGui:FindFirstChild("ExperienceChat") or (Players.LocalPlayer:FindFirstChild("PlayerGui") and Players.LocalPlayer.PlayerGui:FindFirstChild("ExperienceChat"))
		if expChat and expChat:IsA("ScreenGui") then
			expChat.Enabled = not hide
		end
		local pgui = Players.LocalPlayer:FindFirstChild("PlayerGui")
		local legacyChat = pgui and pgui:FindFirstChild("Chat")
		if legacyChat and legacyChat:IsA("ScreenGui") then
			legacyChat.Enabled = not hide
		end
	end)
end

local function disableCoreGuis()
	setRobloxCoreHidden(true)
end

local isGameGuisHidden = false

local function isBlackoutObject(obj: Instance): boolean
	if not obj:IsA("GuiObject") then return false end
	local nameLower = obj.Name:lower()
	if nameLower == "backgroundframe" or nameLower:find("elevator") or nameLower:find("blackout") or nameLower:find("fade") or nameLower:find("transition") or nameLower:find("damage flash") then
		return true
	end
	if obj:IsA("Frame") or obj:IsA("ImageLabel") then
		local sz = obj.AbsoluteSize
		if (sz.X >= 1000 and sz.Y >= 600) or (obj.Size.X.Scale >= 1 and obj.Size.Y.Scale >= 1) then
			if obj:IsA("Frame") then
				local bg = obj.BackgroundColor3
				if bg.R < 0.15 and bg.G < 0.15 and bg.B < 0.15 and obj.BackgroundTransparency < 0.5 then
					return true
				end
			elseif obj:IsA("ImageLabel") then
				if obj.ImageTransparency < 0.5 and obj.ZIndex < 5 then
					return true
				end
			end
		end
	end
	return false
end

local function purgeBlackoutScreens()
	pcall(function()
		local pgui = localPlayer:FindFirstChildOfClass("PlayerGui")
		if pgui then
			for _, g in ipairs(pgui:GetChildren()) do
				if g:IsA("ScreenGui") and not string.find(g.Name, "Modular") and not string.find(g.Name, "ProjectFih") then
					local gName = g.Name:lower()
					if gName:find("elevator") or gName:find("blackout") or gName:find("fade") or gName:find("transition") then
						pcall(function() g:Destroy() end)
					else
						for _, desc in ipairs(g:GetDescendants()) do
							if isBlackoutObject(desc) then
								if desc:IsA("Frame") then
									desc.BackgroundTransparency = 1
									desc.Visible = false
								elseif desc:IsA("ImageLabel") then
									desc.ImageTransparency = 1
									desc.Visible = false
								end
							end
						end
					end
				end
			end
		end
		local cam = workspace.CurrentCamera
		if cam then
			if cam.CameraType ~= Enum.CameraType.Custom then
				cam.CameraType = Enum.CameraType.Custom
			end
			if localPlayer.Character then
				local hum = localPlayer.Character:FindFirstChildOfClass("Humanoid")
				if hum and cam.CameraSubject ~= hum then cam.CameraSubject = hum end
			end
		end
	end)
end

local function hidePlayerGameGuis(hide: boolean)
	isGameGuisHidden = hide
	local pgui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if not pgui then return end
	for _, child in ipairs(pgui:GetChildren()) do
		if child:IsA("ScreenGui") and not string.find(child.Name, "Modular") and not string.find(child.Name, "ProjectFih") then
			local cName = child.Name:lower()
			if cName:find("elevator") or cName:find("blackout") or cName:find("fade") or cName:find("transition") then
				pcall(function() child:Destroy() end)
			else
				child.Enabled = not hide
				if not hide then
					for _, desc in ipairs(child:GetDescendants()) do
						if isBlackoutObject(desc) then
							if desc:IsA("Frame") then
								desc.BackgroundTransparency = 1
								desc.Visible = false
							elseif desc:IsA("ImageLabel") then
								desc.ImageTransparency = 1
								desc.Visible = false
							end
						end
					end
				end
			end
		end
	end
end

task.spawn(disableCoreGuis)
task.spawn(purgeBlackoutScreens)
task.spawn(function()
	hidePlayerGameGuis(false)
end)

task.spawn(function()
	local pgui = localPlayer:WaitForChild("PlayerGui", 10)
	if pgui then
		pgui.ChildAdded:Connect(function(child)
			if isBlackoutObject(child) or child.Name:lower():find("elevator") or child.Name:lower():find("transition") then
				task.defer(function() pcall(function() child:Destroy() end) end)
			elseif child:IsA("ScreenGui") and not isGameGuisHidden then
				task.defer(function()
					for _, desc in ipairs(child:GetDescendants()) do
						if isBlackoutObject(desc) then
							if desc:IsA("Frame") then desc.BackgroundTransparency = 1 desc.Visible = false
							elseif desc:IsA("ImageLabel") then desc.ImageTransparency = 1 desc.Visible = false end
						end
					end
				end)
			end
		end)
	end
end)

RunService.RenderStepped:Connect(function()
	local pgui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if pgui then
		local et = pgui:FindFirstChild("Elevator Transition")
		if et then pcall(function() et:Destroy() end) end
		if not isGameGuisHidden then
			for _, g in ipairs(pgui:GetChildren()) do
				if g:IsA("ScreenGui") and not string.find(g.Name, "Modular") and not string.find(g.Name, "ProjectFih") then
					local gn = g.Name:lower()
					if gn:find("elevator") or gn:find("blackout") or gn:find("fade") or gn:find("transition") then
						pcall(function() g:Destroy() end)
					end
				end
			end
		end
	end
end)

localPlayer.CharacterAdded:Connect(function(char)
	task.spawn(function()
		if isRobloxCoreHidden then
			disableCoreGuis()
		else
			setRobloxCoreHidden(false)
		end
		task.wait(0.1)
		purgeBlackoutScreens()
		hidePlayerGameGuis(isGameGuisHidden)
	end)
end)


-- Clean up previous enforcer if it exists
if _G.__ModularSuite_TopBarEnforcer then
	pcall(task.cancel, _G.__ModularSuite_TopBarEnforcer)
	_G.__ModularSuite_TopBarEnforcer = nil
end

-- Continuous enforcer so Roblox topbar only stays hidden IF isRobloxCoreHidden is true!
_G.__ModularSuite_TopBarEnforcer = task.spawn(function()
	while true do
		task.wait(2.5)
		if _G.__ModularSuite_IsRobloxCoreHidden == true and isRobloxCoreHidden == true then
			disableRobloxTopBarApp(true)
		end
	end
end)

local window = CoreUI.new("Project Fih Menu")
local playerListWidget = PlayerList.new()
local chatWidgetInstance = ChatWidget.new()
local musicTrackerWidget = MusicTracker.new()
local hotbarWidget = Hotbar.new()
local leaderstatsWidget = LeaderstatsWidget.new()
local healthWidget = HealthWidget.new()

-- Standalone Leaderstats HUD integrated directly into PlayerList inspection profile
if leaderstatsWidget and typeof(leaderstatsWidget.Close) == "function" then
	leaderstatsWidget.Close()
end

_G.__ToggleProjectFihBackpack = function()
	if hotbarWidget and hotbarWidget.IsEnabled ~= false then
		hotbarWidget.ToggleBackpack()
	end
end

_G.__ToggleProjectFihMenu = function()
	window:Toggle()
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	local focused = UserInputService:GetFocusedTextBox()
	if focused then return end

	if input.UserInputType == Enum.UserInputType.Keyboard then
		if input.KeyCode == Enum.KeyCode.Tab then
			if playerListWidget and playerListWidget.IsEnabled ~= false then
				playerListWidget:Toggle()
			end
		end
	end
end)

local sharedEnv = {
	cachedCharacterParts = cachedCharacterParts,
	disableRobloxTopBarApp = disableRobloxTopBarApp,
	setRobloxCoreHidden = setRobloxCoreHidden,
	hidePlayerGameGuis = hidePlayerGameGuis,
	coreGuiOverlays = coreGuiOverlays,
	purgeBlackoutScreens = purgeBlackoutScreens,
}

require("Core/MainUI.luau")(require, window, playerListWidget, chatWidgetInstance, musicTrackerWidget, hotbarWidget, leaderstatsWidget, healthWidget, nil, sharedEnv)
