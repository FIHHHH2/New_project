--!strict
local UserInputService = game:GetService("UserInputService")

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

local registeredFeatures: {[string]: FeatureRecord} = {}
local keybindMap: {[Enum.KeyCode]: {string}} = {}
local isListeningForKeybind = false
local activeKeybindCallback: ((Enum.KeyCode?) -> ())? = nil

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
	local record: FeatureRecord = {
		id = id,
		name = name,
		state = defaultState,
		keybind = defaultKeybind,
		callback = callback,
		onKeybindChanged = nil,
		onStateChanged = nil
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
end

function FeatureManager.setFeatureKeybind(id: string, keycode: Enum.KeyCode?)
	local feat = registeredFeatures[id]
	if not feat then return end
	
	feat.keybind = keycode
	rebuildKeybindMap()
	if feat.onKeybindChanged then
		feat.onKeybindChanged(keycode)
	end
end

function FeatureManager.promptKeybindCapture(onCaptured: (Enum.KeyCode?) -> ())
	isListeningForKeybind = true
	activeKeybindCallback = onCaptured
end

function FeatureManager.getFeature(id: string): FeatureRecord?
	return registeredFeatures[id]
end

return FeatureManager
