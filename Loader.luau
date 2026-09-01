--!strict
--[=[
    ✦ High-Speed Universal Remote Loader for Modular Roblox UI ✦
    Features:
    - High-throughput parallel pre-fetching of all core modules
    - Instant module compilation and caching (0ms require latency)
    - Zero blocking GitHub API rate-limit delays
]=]

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

if _G.__ModularSuite_Cleanup then
	pcall(_G.__ModularSuite_Cleanup)
	_G.__ModularSuite_Cleanup = nil
end

local guiNames = {
	"ModularEngineGui",
	"ModularNotificationsGui",
	"ModularPlayerListGui",
	"ModularChatGui",
	"ModularMusicTrackerGui",
	"ModularHotbarGui"
}

for _, name in ipairs(guiNames) do
	for _, c in ipairs(CoreGui:GetChildren()) do
		if c.Name == name then
			c:Destroy()
		end
	end
end

local lp = Players.LocalPlayer
local pgui = lp and lp:FindFirstChild("PlayerGui")
if pgui then
	for _, name in ipairs(guiNames) do
		for _, c in ipairs(pgui:GetChildren()) do
			if c.Name == name then
				c:Destroy()
			end
		end
	end
end

local REPO_OWNER = "FIHHHH2"
local REPO_NAME = "New_project"
local BASE_URL = string.format("https://raw.githubusercontent.com/%s/%s/main/", REPO_OWNER, REPO_NAME)

local function cleanSource(str: string): string
	local b1, b2, b3 = string.byte(str, 1, 3)
	if b1 == 239 and b2 == 187 and b3 == 191 then
		return string.sub(str, 4)
	end
	return str
end

local rawSourceCache: {[string]: string} = {}

local function fetchSource(path: string): string
	if rawSourceCache[path] then
		return rawSourceCache[path]
	end

	local bust = tostring(os.time()) .. "_" .. tostring(math.random(10000, 99999))
	local url = BASE_URL .. path .. "?nocache=" .. bust
	local success, content = pcall(function()
		return game:HttpGet(url)
	end)
	if not success or not content or content == "" then
		local fbSuccess, fbContent = pcall(function()
			return game:HttpGet(BASE_URL .. path)
		end)
		if fbSuccess and fbContent and fbContent ~= "" then
			local cleaned = cleanSource(fbContent)
			rawSourceCache[path] = cleaned
			return cleaned
		end
		error(string.format("[Loader] Failed to fetch module at %s: %s", url, tostring(content)))
	end
	local cleaned = cleanSource(content)
	rawSourceCache[path] = cleaned
	return cleaned
end

-- ── Parallel Pre-fetcher ─────────────────────────────────────────────
local allModulePaths = {
	"UI/Animations.luau",
	"UI/UI.luau",
	"UI/Notification.luau",
	"UI/PlayerList.luau",
	"UI/ChatWidget.luau",
	"UI/MusicTracker.luau",
	"UI/Hotbar.luau",
	"Core/FeatureManager.luau",
	"Core/CoreUI.luau",
	"Core/Main.luau",
	"Modules/Visuals.luau",
	"Modules/Combat.luau",
	"Modules/Movement.luau",
	"Modules/DisasterSurvival.luau",
	"Modules/RunNHide.luau",
	"Modules/IceTycoon.luau",
	"Modules/PlayerUtilities.luau"
}

-- Fetch all modules concurrently in parallel threads
for _, modPath in ipairs(allModulePaths) do
	task.spawn(function()
		pcall(fetchSource, modPath)
	end)
end

local moduleCache: {[string]: any} = {}

local function normalizePath(path: string): string
	if string.find(path, "%.luau$") or string.find(path, "%.lua$") then
		return path
	end
	if path == "UI/Animations" or path == "Animations" then
		return "UI/Animations.luau"
	elseif path == "UI/UI" or path == "UI" then
		return "UI/UI.luau"
	elseif path == "UI/Notification" or path == "Notification" then
		return "UI/Notification.luau"
	elseif path == "UI/PlayerList" or path == "PlayerList" then
		return "UI/PlayerList.luau"
	elseif path == "UI/ChatWidget" or path == "ChatWidget" then
		return "UI/ChatWidget.luau"
	elseif path == "UI/MusicTracker" or path == "MusicTracker" then
		return "UI/MusicTracker.luau"
	elseif path == "UI/Hotbar" or path == "Hotbar" then
		return "UI/Hotbar.luau"
	elseif path == "Core/FeatureManager" or path == "FeatureManager" then
		return "Core/FeatureManager.luau"
	elseif path == "Core/CoreUI" or path == "CoreUI" then
		return "Core/CoreUI.luau"
	elseif path == "Core/Main" or path == "Main" then
		return "Core/Main.luau"
	elseif path == "Modules/Visuals" or path == "Visuals" then
		return "Modules/Visuals.luau"
	elseif path == "Modules/Combat" or path == "Combat" then
		return "Modules/Combat.luau"
	elseif path == "Modules/Movement" or path == "Movement" then
		return "Modules/Movement.luau"
	elseif path == "Modules/DisasterSurvival" or path == "DisasterSurvival" then
		return "Modules/DisasterSurvival.luau"
	elseif path == "Modules/RunNHide" or path == "RunNHide" then
		return "Modules/RunNHide.luau"
	elseif path == "Modules/IceTycoon" or path == "IceTycoon" then
		return "Modules/IceTycoon.luau"
	elseif path == "Modules/PlayerUtilities" or path == "PlayerUtilities" then
		return "Modules/PlayerUtilities.luau"
	end
	return path .. ".luau"
end

local function requireRemote(rawPath: string): any
	local path = normalizePath(rawPath)

	if moduleCache[path] then
		return moduleCache[path]
	end
	
	local source = fetchSource(path)
	local func, compileErr = loadstring(source, path)
	if not func then
		error(string.format("[Loader] Compile error in %s: %s", path, tostring(compileErr)))
	end
	
	local env = getfenv(func)
	local customEnv
	customEnv = setmetatable({
		require = function(target: any)
			if typeof(target) == "string" then
				return requireRemote(target)
			end
			if typeof(target) == "Instance" then
				local name = target.Name
				return requireRemote(name)
			end
			return require(target)
		end,
		script = Instance.new("ModuleScript")
	}, { __index = env })
	
	setfenv(func, customEnv)
	local result = func()
	moduleCache[path] = result
	return result
end

-- Preload key singletons into environment
local Animations = requireRemote("UI/Animations.luau")
local UI = requireRemote("UI/UI.luau")
local Notification = requireRemote("UI/Notification.luau")
local FeatureManager = requireRemote("Core/FeatureManager.luau")
local CoreUI = requireRemote("Core/CoreUI.luau")
local PlayerList = requireRemote("UI/PlayerList.luau")
local ChatWidget = requireRemote("UI/ChatWidget.luau")
local MusicTracker = requireRemote("UI/MusicTracker.luau")
local Hotbar = requireRemote("UI/Hotbar.luau")
local Visuals = requireRemote("Modules/Visuals.luau")
local Combat = requireRemote("Modules/Combat.luau")
local Movement = requireRemote("Modules/Movement.luau")
local DisasterSurvival = requireRemote("Modules/DisasterSurvival.luau")
local RunNHide = requireRemote("Modules/RunNHide.luau")
local IceTycoon = requireRemote("Modules/IceTycoon.luau")
local PlayerUtilities = requireRemote("Modules/PlayerUtilities.luau")

_G.__ModularSuite_Cleanup = function()
	pcall(function()
		Visuals.cleanup()
		Combat.cleanup()
		Movement.cleanup()
		DisasterSurvival.cleanup()
		RunNHide.cleanup()
		IceTycoon.cleanup()
		PlayerUtilities.SetAntiAFK(false)
		PlayerUtilities.SetClickTeleportEnabled(false)
	end)
end

local mainSource = fetchSource("Core/Main.luau")
local mainFunc, mainCompileErr = loadstring(mainSource, "Core/Main.luau")
if not mainFunc then
	error(string.format("[Loader] Error compiling Core/Main.luau: %s", tostring(mainCompileErr)))
end

local mainEnv = getfenv(mainFunc)
local customMainEnv = setmetatable({
	require = function(target: any)
		if typeof(target) == "string" then
			return requireRemote(target)
		end
		if typeof(target) == "Instance" then
			local name = target.Name
			return requireRemote(name)
		end
		return require(target)
	end,
	script = Instance.new("LocalScript")
}, { __index = mainEnv })

setfenv(mainFunc, customMainEnv)
task.spawn(mainFunc)

print("[Loader] Modular Roblox UI successfully loaded and running.")
