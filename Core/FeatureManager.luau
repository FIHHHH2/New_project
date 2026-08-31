--!strict
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
	onKeybindChanged: ((Enum.KeyCode?) -> ())?,
	onStateChanged: ((boolean) -> ())?
}

export type SliderRecord = {
	id: string,
	name: string,
	value: number,
	callback: (number) -> (),
	onValueChanged: ((number) -> ())?
}

local registeredFeatures: {[string]: FeatureRecord} = {}
local registeredSliders: {[string]: SliderRecord} = {}
local keybindMap: {[Enum.KeyCode]: {string}} = {}
local isListeningForKeybind = false
local activeKeybindCallback: ((Enum.KeyCode?) -> ())? = nil

local CONFIG_FOLDER = "FihSuite"
local DEFAULT_CONFIG = "default"
local savedConfigCache: {[string]: any} = {}

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

local function ensureFolder()
	local mkf = makefolder or (getgenv and getgenv().makefolder)
	local isf = isfolder or (getgenv and getgenv().isfolder)
	if type(mkf) == "function" and type(isf) == "function" then
		pcall(function()
			if not isf(CONFIG_FOLDER) then
				mkf(CONFIG_FOLDER)
			end
		end)
	end
end

local function readConfigFile(name: string): string?
	ensureFolder()
	local rdf = readfile or (getgenv and getgenv().readfile)
	local isf = isfile or (getgenv and getgenv().isfile)
	if type(rdf) == "function" and type(isf) == "function" then
		local path = CONFIG_FOLDER .. "/" .. name .. ".json"
		local success, content = pcall(function()
			if isf(path) then
				return rdf(path)
			end
			return nil
		end)
		if success and content then
			return content
		end
	end
	return nil
end

local function writeConfigFile(name: string, data: string): boolean
	ensureFolder()
	local wrf = writefile or (getgenv and getgenv().writefile)
	if type(wrf) == "function" then
		local path = CONFIG_FOLDER .. "/" .. name .. ".json"
		local success = pcall(function()
			wrf(path, data)
		end)
		return success
	end
	return false
end

-- Preload default config cache from disk on startup
pcall(function()
	local raw = readConfigFile(DEFAULT_CONFIG)
	if raw then
		local decoded = HttpService:JSONDecode(raw)
		if type(decoded) == "table" then
			savedConfigCache = decoded
		end
	end
end)

local saveDebounce = false
local function scheduleAutoSave()
	if saveDebounce then return end
	saveDebounce = true
	task.delay(0.4, function()
		saveDebounce = false
		FeatureManager.saveConfig(DEFAULT_CONFIG)
	end)
end

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

function FeatureManager.register(id: string, name: string, defaultState: boolean, defaultKeybind: Enum.KeyCode?, callback: (boolean) -> ()): FeatureRecord
	local initialState = defaultState
	local initialKeybind = defaultKeybind

	-- Check persistent cache on startup
	if savedConfigCache and savedConfigCache.toggles and savedConfigCache.toggles[id] then
		local entry = savedConfigCache.toggles[id]
		if entry.state ~= nil then
			initialState = entry.state
		end
		if entry.keybind then
			pcall(function()
				initialKeybind = (Enum.KeyCode :: any)[entry.keybind]
			end)
		end
	end

	local record: FeatureRecord = {
		id = id,
		name = name,
		state = initialState,
		keybind = initialKeybind,
		callback = callback,
		onKeybindChanged = nil,
		onStateChanged = nil
	}
	registeredFeatures[id] = record
	rebuildKeybindMap()
	
	task.spawn(function()
		local success, err = pcall(callback, initialState)
		if not success then
			warn(string.format("[FeatureManager] error initializing feature %s: %s", id, tostring(err)))
		end
	end)
	
	return record
end

function FeatureManager.registerSlider(id: string, name: string, defaultValue: number, callback: (number) -> ()): (SliderRecord, number)
	local initialVal = defaultValue
	if savedConfigCache and savedConfigCache.sliders and savedConfigCache.sliders[id] ~= nil then
		initialVal = savedConfigCache.sliders[id]
	end

	local record: SliderRecord = {
		id = id,
		name = name,
		value = initialVal,
		callback = callback,
		onValueChanged = nil
	}
	registeredSliders[id] = record

	task.spawn(function()
		local success, err = pcall(callback, initialVal)
		if not success then
			warn(string.format("[FeatureManager] error initializing slider %s: %s", id, tostring(err)))
		end
	end)

	return record, initialVal
end

function FeatureManager.setSliderValue(id: string, value: number)
	local s = registeredSliders[id]
	if not s then return end
	s.value = value
	if s.onValueChanged then
		s.onValueChanged(value)
	end
	pcall(s.callback, value)
	scheduleAutoSave()
end

function FeatureManager.setFeatureState(id: string, state: boolean)
	local feat = registeredFeatures[id]
	if not feat then return end
	if feat.state == state then return end
	
	feat.state = state
	if feat.onStateChanged then
		feat.onStateChanged(state)
	end
	local success, err = pcall(feat.callback, state)
	if not success then
		warn(string.format("[FeatureManager] error toggling feature %s: %s", id, tostring(err)))
	end
	scheduleAutoSave()
end

function FeatureManager.setFeatureKeybind(id: string, keycode: Enum.KeyCode?)
	local feat = registeredFeatures[id]
	if not feat then return end
	
	feat.keybind = keycode
	rebuildKeybindMap()
	if feat.onKeybindChanged then
		feat.onKeybindChanged(keycode)
	end
	scheduleAutoSave()
end

function FeatureManager.promptKeybindCapture(onCaptured: (Enum.KeyCode?) -> ())
	isListeningForKeybind = true
	activeKeybindCallback = onCaptured
end

function FeatureManager.getFeature(id: string): FeatureRecord?
	return registeredFeatures[id]
end

function FeatureManager.saveConfig(name: string?): boolean
	local targetName = name or DEFAULT_CONFIG
	local exportData = {
		toggles = {},
		sliders = {},
		timestamp = os.time()
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

	local success, encoded = pcall(function()
		return HttpService:JSONEncode(exportData)
	end)
	if success and encoded then
		savedConfigCache = exportData
		return writeConfigFile(targetName, encoded)
	end
	return false
end

function FeatureManager.loadConfig(name: string?): boolean
	local targetName = name or DEFAULT_CONFIG
	local raw = readConfigFile(targetName)
	if not raw then return false end

	local success, decoded = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not success or type(decoded) ~= "table" then return false end

	savedConfigCache = decoded

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

	return true
end

return FeatureManager
