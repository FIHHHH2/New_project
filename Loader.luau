--!strict
--[=[
    ✦ Universal Remote Loader for Modular Roblox UI ✦
    Fetches and resolves all modular sub-packages dynamically over HTTP.
]=]

local HttpService = game:GetService("HttpService")

-- Dynamically resolve latest commit SHA to bypass any CDN edge cache delays
local REPO_OWNER = "FIHHHH2"
local REPO_NAME = "New_project"
local branchOrSha = "main"

pcall(function()
	local commitJson = game:HttpGet(string.format("https://api.github.com/repos/%s/%s/commits/main", REPO_OWNER, REPO_NAME))
	local data = HttpService:JSONDecode(commitJson)
	if data and data.sha then
		branchOrSha = data.sha
	end
end)

local BASE_URL = string.format("https://raw.githubusercontent.com/%s/%s/%s/", REPO_OWNER, REPO_NAME, branchOrSha)

local function cleanSource(str: string): string
	local b1, b2, b3 = string.byte(str, 1, 3)
	if b1 == 239 and b2 == 187 and b3 == 191 then
		return string.sub(str, 4)
	end
	return str
end

local function fetchSource(path: string): string
	local url = BASE_URL .. path
	local success, content = pcall(function()
		return game:HttpGet(url)
	end)
	if not success or not content or content == "" then
		error(string.format("[Loader] Failed to fetch module at %s: %s", url, tostring(content)))
	end
	return cleanSource(content)
end

-- Virtual module cache emulating standard Luau require behavior
local moduleCache: {[string]: any} = {}

local function requireRemote(path: string): any
	-- Normalize path
	if not string.find(path, "%.luau$") and not string.find(path, "%.lua$") then
		if path == "UI/Animations" or path == "Animations" then
			path = "UI/Animations.luau"
		elseif path == "UI/UI" or path == "UI" then
			path = "UI/UI.luau"
		elseif path == "Core/FeatureManager" or path == "FeatureManager" then
			path = "Core/FeatureManager.luau"
		elseif path == "Core/CoreUI" or path == "CoreUI" then
			path = "Core/CoreUI.luau"
		elseif path == "Core/Main" or path == "Main" then
			path = "Core/Main.luau"
		end
	end

	if moduleCache[path] then
		return moduleCache[path]
	end
	
	local source = fetchSource(path)
	local func, compileErr = loadstring(source, path)
	if not func then
		error(string.format("[Loader] Compile error in %s: %s", path, tostring(compileErr)))
	end
	
	-- Inject custom environment with virtual require
	local env = getfenv(func)
	local customEnv
	customEnv = setmetatable({
		require = function(target: any)
			if typeof(target) == "string" then
				return requireRemote(target)
			end
			if typeof(target) == "Instance" then
				local name = target.Name
				if name == "Animations" then
					return requireRemote("UI/Animations.luau")
				elseif name == "UI" then
					return requireRemote("UI/UI.luau")
				elseif name == "FeatureManager" then
					return requireRemote("Core/FeatureManager.luau")
				elseif name == "CoreUI" then
					return requireRemote("Core/CoreUI.luau")
				end
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

print("[Loader] Initializing Modular Roblox UI suite...")

-- Preload dependencies in order
local Animations = requireRemote("UI/Animations.luau")
local UI = requireRemote("UI/UI.luau")
local FeatureManager = requireRemote("Core/FeatureManager.luau")
local CoreUI = requireRemote("Core/CoreUI.luau")

-- Bootstrap Main Runtime
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
			if name == "CoreUI" then
				return CoreUI
			elseif name == "FeatureManager" then
				return FeatureManager
			elseif name == "UI" then
				return UI
			elseif name == "Animations" then
				return Animations
			end
		end
		return require(target)
	end,
	script = Instance.new("LocalScript")
}, { __index = mainEnv })

setfenv(mainFunc, customMainEnv)
task.spawn(mainFunc)

print("[Loader] Modular Roblox UI successfully loaded and running.")
