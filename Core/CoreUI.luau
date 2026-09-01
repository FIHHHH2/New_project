--!strict
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")

local function destroyExistingGuis(name: string)
	local containers = {
		(type(gethui) == "function" and gethui()),
		CoreGui,
		CoreGui:FindFirstChild("RobloxGui"),
		(Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui"))
	}
	for _, c in ipairs(containers) do
		if c then
			for _, child in ipairs(c:GetChildren()) do
				if child.Name == name then
					pcall(function() child:Destroy() end)
				end
			end
		end
	end
end

local function safeParentGui(gui: ScreenGui)
	local targetParent = nil
	if type(gethui) == "function" then
		pcall(function() targetParent = gethui() end)
	end
	if not targetParent and CoreGui then
		pcall(function() targetParent = CoreGui end)
	end
	if not targetParent and Players.LocalPlayer then
		targetParent = Players.LocalPlayer:FindFirstChild("PlayerGui")
	end
	pcall(function() gui.Parent = targetParent end)
	if not gui.Parent and Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui") then
		gui.Parent = Players.LocalPlayer.PlayerGui
	end
end

local UI = require("UI/UI.luau")
local Animations = require("UI/Animations.luau")
local FeatureManager = require("Core/FeatureManager.luau")
local Notification = require("UI/Notification.luau")

local function safeParentGui(gui: ScreenGui)
	local targetParent = nil
	if type(gethui) == "function" then
		pcall(function() targetParent = gethui() end)
	end
	if not targetParent and CoreGui then
		pcall(function() targetParent = CoreGui end)
	end
	if not targetParent and Players.LocalPlayer then
		targetParent = Players.LocalPlayer:FindFirstChild("PlayerGui")
	end
	pcall(function() gui.Parent = targetParent end)
	if not gui.Parent and Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerGui") then
		gui.Parent = Players.LocalPlayer.PlayerGui
	end
end

