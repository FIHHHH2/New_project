--!strict
--[=[
    ✦ Advanced Feature & Config Management Engine ✦
    Provides:
    - Modular Feature, Slider, and Module State registration
    - Disk-based multi-profile configuration manager (FihSuite/Configs/<name>.json)
    - Dynamic config file discovery on join (listfiles)
    - Zero default clutter (clean creation and overwrite workflow)
    - Keybind listening and execution dispatcher
]=]

local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local FeatureManager = {}
FeatureManager.__index = FeatureManager

export type FeatureRecord = {
	id: string,
	name: string,
	state: boolean,
	keybind: Enum.KeyCode?,
	callback: (boolean) -> (),
	callbacks: {(boolean) -> ()},
	onKeybindChanged: ((Enum.KeyCode?) -> ())?,
	onStateChanged: ((boolean) -> ())?,
	stateListeners: {(boolean) -> ()},
	keybindListeners: {(Enum.KeyCode?) -> ()}
}

export type SliderRecord = {
	id: string,
	name: string,
	value: number,
	callback: (number) -> (),
	onValueChanged: ((number) -> ())?
}

export type ModuleRecord = {
	id: string,
	name: string,
	enabled: boolean,
	callback: (boolean) -> (),
	onStateChanged: ((boolean) -> ())?
}

local registeredFeatures: {[string]: FeatureRecord} = {}
local registeredSliders: {[string]: SliderRecord} = {}
local registeredModules: {[string]: ModuleRecord} = {}
local keybindMap: {[Enum.KeyCode]: {string}} = {}
local isListeningForKeybind = false
local activeKeybindCallback: ((Enum.KeyCode?) -> ())? = nil

local ROOT_FOLDER = "FihSuite"
local CONFIGS_FOLDER = "FihSuite/Configs"
local activeConfigName: string? = nil

local function rebuildKeybindMap()
	table.clear(keybindMap)
	for id, feat in pairs(registeredFeatures) do
		if feat.keybind and feat.keybind ~= Enum.KeyCode.Unknown then
			if not keybindMap[feat.keybind] then
				keybindMap[feat.keybind] = {}
			end
			table.insert(keybindMap[feat.keybind], id)
		end
	end
end

local configsIndex: {[string]: boolean} = {}
if type(_G.__ModularConfigsIndex) == "table" then
	for k, v in pairs(_G.__ModularConfigsIndex) do
		if v == true then configsIndex[k] = true end
	end
else
	_G.__ModularConfigsIndex = configsIndex
end

local function ensureFolders()
	local mkf = makefolder or (getgenv and getgenv().makefolder)
	local isf = isfolder or (getgenv and getgenv().isfolder)
	if type(mkf) == "function" then
		pcall(function()
			if type(isf) == "function" then
				if not isf(ROOT_FOLDER) then mkf(ROOT_FOLDER) end
				if not isf(CONFIGS_FOLDER) then mkf(CONFIGS_FOLDER) end
			else
				mkf(ROOT_FOLDER)
				mkf(CONFIGS_FOLDER)
			end
		end)
	end
end

local function sanitizeConfigName(name: string): string
	local clean = name:gsub("[^%w_%-%s]", ""):gsub("^%s+", ""):gsub("%s+$", "")
	return if clean ~= "" then clean else "Config_" .. tostring(os.time())
end

-- ── File System Utilities ─────────────────────────────────────────
function FeatureManager.listConfigs(): {string}
	ensureFolders()
	local configsMap: {[string]: boolean} = {}

	-- 1. In-memory & Global Registry
	for name, active in pairs(configsIndex) do
		if active then configsMap[name] = true end
	end
	if type(_G.__ModularConfigsIndex) == "table" then
		for name, active in pairs(_G.__ModularConfigsIndex) do
			if active then configsMap[name] = true end
		end
	end

	-- 2. Disk Discovery (listfiles)
	local listf = listfiles or (getgenv and getgenv().listfiles)
	local rdf = readfile or (getgenv and getgenv().readfile)
	if type(listf) == "function" then
		local function scanDir(dir: string)
			local ok, files = pcall(function() return listf(dir) end)
			if ok and type(files) == "table" then
				for _, path in ipairs(files) do
					local s = tostring(path):gsub("\\", "/")
					local fileName = s:match("([^/]+)%.json$")
					if fileName and fileName ~= "" and fileName ~= "autoload_profile" and fileName ~= "config_index" then
						local hasContent = true
						if type(rdf) == "function" then
							pcall(function()
								local content = rdf(path)
								if not content or #content < 5 or not content:find("{") then
									hasContent = false
								end
							end)
						end
						if hasContent then
							configsMap[fileName] = true
							configsIndex[fileName] = true
						else
							configsMap[fileName] = nil
							configsIndex[fileName] = nil
						end
					end
				end
			end
		end
		scanDir(CONFIGS_FOLDER)
		scanDir(ROOT_FOLDER)
	end

	local result: {string} = {}
	for name in pairs(configsMap) do
		table.insert(result, name)
	end
	table.sort(result)
	return result
end

local function readConfigFile(name: string): string?
	ensureFolders()
	local rdf = readfile or (getgenv and getgenv().readfile)
	local isf = isfile or (getgenv and getgenv().isfile)
	if type(rdf) == "function" then
		local paths = {
			CONFIGS_FOLDER .. "/" .. name .. ".json",
			CONFIGS_FOLDER .. "\\" .. name .. ".json",
			ROOT_FOLDER .. "/" .. name .. ".json",
			"FihSuite_Config_" .. name .. ".json",
			name .. ".json"
		}
		for _, p in ipairs(paths) do
			local ok, content = pcall(function()
				if type(isf) == "function" then
					if isf(p) then return rdf(p) end
				else
					return rdf(p)
				end
				return nil
			end)
			if ok and content and #content > 5 and content:find("{") then
				return content
			end
		end
	end
	return nil
end

local function writeConfigFile(name: string, data: string): boolean
	ensureFolders()
	local wrf = writefile or (getgenv and getgenv().writefile)
	if type(wrf) == "function" then
		local paths = {
			CONFIGS_FOLDER .. "/" .. name .. ".json",
			ROOT_FOLDER .. "/" .. name .. ".json",
			"FihSuite_Config_" .. name .. ".json",
			name .. ".json"
		}
		for _, path in ipairs(paths) do
			local ok = pcall(function() wrf(path, data) end)
			if ok then
				configsIndex[name] = true
				if type(_G.__ModularConfigsIndex) == "table" then
					_G.__ModularConfigsIndex[name] = true
				end
				return true
			end
		end
	end
	-- If executor has no writefile, record to in-memory index
	configsIndex[name] = true
	if type(_G.__ModularConfigsIndex) == "table" then
		_G.__ModularConfigsIndex[name] = true
	end
	return true
end

local function deleteConfigFile(name: string): boolean
	ensureFolders()
	configsIndex[name] = nil
	if type(_G.__ModularConfigsIndex) == "table" then
		_G.__ModularConfigsIndex[name] = nil
	end

	local dlf = delfile
		or deletefile
		or removefile
		or (syn and syn.delfile)
		or (fs and (fs.remove or fs.delete))
		or (getgenv and (getgenv().delfile or getgenv().deletefile or getgenv().removefile))

	local paths = {
		CONFIGS_FOLDER .. "/" .. name .. ".json",
		CONFIGS_FOLDER .. "\\" .. name .. ".json",
		ROOT_FOLDER .. "/" .. name .. ".json",
		"FihSuite_Config_" .. name .. ".json",
		name .. ".json"
	}

	if type(dlf) == "function" then
		for _, p in ipairs(paths) do
			pcall(function() dlf(p) end)
		end
	end

	-- Always write empty tombstone so listConfigs / readConfigFile knows it is deleted
	local wrf = writefile or (getgenv and getgenv().writefile)
	if type(wrf) == "function" then
		for _, p in ipairs(paths) do
			pcall(function() wrf(p, "") end)
		end
	end

	return true
end

-- ── Keybind Listener ──────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if isListeningForKeybind and activeKeybindCallback then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			local key = input.KeyCode
			if key == Enum.KeyCode.Escape then
				activeKeybindCallback(nil)
			else
				activeKeybindCallback(key)
			end
			isListeningForKeybind = false
			activeKeybindCallback = nil
			return
		end
	end
	
	if gameProcessed then return end
	
	if input.UserInputType == Enum.UserInputType.Keyboard then
		local matching = keybindMap[input.KeyCode]
		if matching then
			for _, featId in ipairs(matching) do
				local feat = registeredFeatures[featId]
				if feat then
					FeatureManager.setFeatureState(featId, not feat.state)
				end
			end
		end
	end
end)

-- ── Feature & Slider Registration ─────────────────────────────────
function FeatureManager.register(id: string, name: string, defaultState: boolean, defaultKeybind: Enum.KeyCode?, callback: (boolean) -> ()): FeatureRecord
	local existing = registeredFeatures[id]
	if existing then
		if callback and not table.find(existing.callbacks, callback) then
			table.insert(existing.callbacks, callback)
		end
		return existing
	end

	local record: FeatureRecord = {
		id = id,
		name = name,
		state = defaultState,
		keybind = defaultKeybind,
		callback = callback,
		callbacks = {callback},
		onKeybindChanged = nil,
		onStateChanged = nil,
		stateListeners = {},
		keybindListeners = {}
	}
	registeredFeatures[id] = record
	rebuildKeybindMap()
	
	task.spawn(function()
		local success, err = pcall(callback, defaultState)
		if not success then
			warn(string.format("[FeatureManager] error initializing feature %s: %s", id, tostring(err)))
		end
	end)
	
	return record
end

function FeatureManager.registerSlider(id: string, name: string, defaultValue: number, callback: (number) -> ()): (SliderRecord, number)
	local record: SliderRecord = {
		id = id,
		name = name,
		value = defaultValue,
		callback = callback,
		onValueChanged = nil
	}
	registeredSliders[id] = record

	task.spawn(function()
		local success, err = pcall(callback, defaultValue)
		if not success then
			warn(string.format("[FeatureManager] error initializing slider %s: %s", id, tostring(err)))
		end
	end)

	return record, defaultValue
end

function FeatureManager.registerModule(id: string, name: string, defaultEnabled: boolean, callback: (boolean) -> ()): ModuleRecord
	local record: ModuleRecord = {
		id = id,
		name = name,
		enabled = defaultEnabled,
		callback = callback,
		onStateChanged = nil
	}
	registeredModules[id] = record

	task.spawn(function()
		pcall(callback, defaultEnabled)
	end)

	return record
end

function FeatureManager.setSliderValue(id: string, value: number)
	local s = registeredSliders[id]
	if not s then return end
	s.value = value
	if s.onValueChanged then s.onValueChanged(value) end
	pcall(s.callback, value)
end

function FeatureManager.setFeatureState(id: string, state: boolean)
	local feat = registeredFeatures[id]
	if not feat then return end
	if feat.state == state then return end
	
	feat.state = state
	if feat.onStateChanged then feat.onStateChanged(state) end
	if feat.stateListeners then
		for _, listener in ipairs(feat.stateListeners) do
			pcall(listener, state)
		end
	end

	if feat.callbacks then
		for _, cb in ipairs(feat.callbacks) do
			pcall(cb, state)
		end
	elseif feat.callback then
		pcall(feat.callback, state)
	end
end

function FeatureManager.setFeatureKeybind(id: string, keycode: Enum.KeyCode?)
	local feat = registeredFeatures[id]
	if not feat then return end
	feat.keybind = keycode
	rebuildKeybindMap()
	if feat.onKeybindChanged then feat.onKeybindChanged(keycode) end
	if feat.keybindListeners then
		for _, listener in ipairs(feat.keybindListeners) do
			pcall(listener, keycode)
		end
	end
end

function FeatureManager.setModuleState(id: string, enabled: boolean)
	local mod = registeredModules[id]
	if not mod then return end
	mod.enabled = enabled
	if mod.onStateChanged then mod.onStateChanged(enabled) end
	pcall(mod.callback, enabled)
end

function FeatureManager.getModuleState(id: string): boolean
	local mod = registeredModules[id]
	return if mod then mod.enabled else true
end

function FeatureManager.promptKeybindCapture(onCaptured: (Enum.KeyCode?) -> ())
	isListeningForKeybind = true
	activeKeybindCallback = onCaptured
end

function FeatureManager.getFeature(id: string): FeatureRecord?
	return registeredFeatures[id]
end

function FeatureManager.getActiveConfigName(): string?
	return activeConfigName
end

-- ── Config Serialization & Restoration ───────────────────────────
function FeatureManager.saveConfig(name: string): boolean
	local cleanName = sanitizeConfigName(name)
	local exportData = {
		name = cleanName,
		timestamp = os.time(),
		toggles = {},
		sliders = {},
		modules = {}
	}

	for id, feat in pairs(registeredFeatures) do
		exportData.toggles[id] = {
			state = feat.state,
			keybind = if feat.keybind and feat.keybind ~= Enum.KeyCode.Unknown then feat.keybind.Name else nil
		}
	end

	for id, slider in pairs(registeredSliders) do
		exportData.sliders[id] = slider.value
	end

	for id, mod in pairs(registeredModules) do
		exportData.modules[id] = mod.enabled
	end

	local ok, encoded = pcall(function() return HttpService:JSONEncode(exportData) end)
	if ok and encoded then
		local written = writeConfigFile(cleanName, encoded)
		if written then activeConfigName = cleanName end
		return written
	end
	return false
end

function FeatureManager.loadConfig(name: string): boolean
	local cleanName = sanitizeConfigName(name)
	local raw = readConfigFile(cleanName)
	if not raw then return false end

	local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
	if not ok or type(decoded) ~= "table" then return false end

	if decoded.toggles then
		for id, data in pairs(decoded.toggles) do
			local feat = registeredFeatures[id]
			if feat then
				if data.state ~= nil and feat.state ~= data.state then
					FeatureManager.setFeatureState(id, data.state)
				end
				if data.keybind then
					pcall(function()
						local key = (Enum.KeyCode :: any)[data.keybind]
						FeatureManager.setFeatureKeybind(id, key)
					end)
				elseif data.keybind == nil and feat.keybind ~= nil then
					FeatureManager.setFeatureKeybind(id, nil)
				end
			end
		end
	end

	if decoded.sliders then
		for id, val in pairs(decoded.sliders) do
			local s = registeredSliders[id]
			if s and type(val) == "number" then
				FeatureManager.setSliderValue(id, val)
			end
		end
	end

	if decoded.modules then
		for id, enabled in pairs(decoded.modules) do
			local m = registeredModules[id]
			if m and type(enabled) == "boolean" then
				FeatureManager.setModuleState(id, enabled)
			end
		end
	end

	activeConfigName = cleanName
	return true
end

function FeatureManager.deleteConfig(name: string): boolean
	local cleanName = sanitizeConfigName(name)
	local ok = deleteConfigFile(cleanName)
	if activeConfigName == cleanName then activeConfigName = nil end
	return ok
end

-- ── Auto-Load on Startup Persistence ─────────────────────────────────
local AUTOLOAD_FILE = "autoload_profile.json"

function FeatureManager.getAutoLoadConfig(): { enabled: boolean, configName: string }
	local raw = readConfigFile(AUTOLOAD_FILE)
	if raw then
		local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
		if ok and type(data) == "table" and data.configName then
			return {
				enabled = (data.enabled == true),
				configName = tostring(data.configName)
			}
		end
	end
	return { enabled = false, configName = "" }
end

function FeatureManager.setAutoLoadConfig(enabled: boolean, configName: string): boolean
	local cleanName = sanitizeConfigName(configName)
	local payload = {
		enabled = enabled,
		configName = cleanName
	}
	local ok, encoded = pcall(function() return HttpService:JSONEncode(payload) end)
	if ok and encoded then
		return writeConfigFile(AUTOLOAD_FILE, encoded)
	end
	return false
end

return FeatureManager
