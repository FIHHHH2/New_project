--!strict
--[=[
    ✦ Player Utilities & Server Operations Engine ✦
    Features:
    - Server Hop: Public server list scraper & TeleportService instance joiner
    - Server Rejoin: Instant PlaceId / JobId teleport reconnection
    - Metadata Clipboard Exporters: Place ID, Game ID, Job ID
    - Anti-AFK Timeout Preventer: LocalPlayer.Idled bypass with VirtualUser
    - Click Teleport Tool & Ctrl+Click Instant Raycast Navigation
]=]

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")

local Notification = require("UI/Notification.luau")

local LocalPlayer = Players.LocalPlayer

local PlayerUtilities = {
	AntiAFK = false,
	ClickTeleport = false,
}

local antiAfkConn: RBXScriptConnection? = nil
local clickTpConn: RBXScriptConnection? = nil
local activeTool: Tool? = nil

local function safeSetClipboard(text: string): boolean
	local setClip = (setclipboard or toclipboard or (Clipboard and (Clipboard :: any).set)) :: any
	if typeof(setClip) == "function" then
		local ok = pcall(function()
			setClip(text)
		end)
		return ok
	end
	return false
end

local function safeTeleport(targetCF: CFrame)
	local char = LocalPlayer.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return end

	pcall(function()
		hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
		hum.PlatformStand = false
		hum.Sit = false
	end)

	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	hrp.Velocity = Vector3.zero
	hrp.RotVelocity = Vector3.zero

	hrp.CFrame = targetCF * CFrame.new(0, 0.5, 0)

	for _, desc in ipairs(char:GetDescendants()) do
		if desc:IsA("Motor6D") then
			desc.Enabled = true
		elseif desc:IsA("BallSocketConstraint") and desc.Name:lower():find("ragdoll") then
			desc.Enabled = false
		end
	end

	pcall(function()
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		hum:ChangeState(Enum.HumanoidStateType.Running)
	end)

	task.defer(function()
		if hum and hum.Parent then
			hum.PlatformStand = false
			hum.Sit = false
			hum:ChangeState(Enum.HumanoidStateType.Running)
		end
		if hrp and hrp.Parent then
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end

local function teleportToMouse()
	local mouse = LocalPlayer:GetMouse()
	if not mouse or not mouse.Hit then return end
	local targetPos = mouse.Hit.Position + Vector3.new(0, 3, 0)
	safeTeleport(CFrame.new(targetPos))
end

function PlayerUtilities.ServerHop(): (boolean, string)
	Notification.show("Server Hop", "Searching for available public servers...", 3)

	local placeId = game.PlaceId
	local currentJobId = game.JobId
	local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100", placeId)

	local fetchSuccess, response = pcall(function()
		local httpGet = (game.HttpGet or (game :: any).HttpGetAsync) :: any
		if typeof(httpGet) == "function" then
			return httpGet(game, url)
		end
		local req = (request or http_request or (syn and (syn :: any).request) or (http and (http :: any).request)) :: any
		if typeof(req) == "function" then
			local res = req({ Url = url, Method = "GET" })
			if res and res.Body then
				return res.Body
			end
		end
		error("No HTTP GET function available on executor")
	end)

	if not fetchSuccess or not response or response == "" then
		local errMsg = string.format("Failed to fetch server list: %s", tostring(response))
		Notification.show("Server Hop Error", errMsg, 4)
		return false, errMsg
	end

	local decodeSuccess, data = pcall(function()
		return HttpService:JSONDecode(response)
	end)

	if not decodeSuccess or not data or type(data.data) ~= "table" then
		local errMsg = "Failed to parse public servers JSON response"
		Notification.show("Server Hop Error", errMsg, 4)
		return false, errMsg
	end

	local validServers: {{id: string, playing: number, maxPlayers: number}} = {}
	for _, srv in ipairs(data.data) do
		if type(srv) == "table" and srv.id and srv.playing ~= nil and srv.maxPlayers ~= nil then
			local playing = tonumber(srv.playing) or 0
			local maxPlayers = tonumber(srv.maxPlayers) or 0
			local srvId = tostring(srv.id)
			if playing < maxPlayers and srvId ~= currentJobId and srvId ~= "" then
				table.insert(validServers, {
					id = srvId,
					playing = playing,
					maxPlayers = maxPlayers
				})
			end
		end
	end

	if #validServers == 0 then
		local errMsg = "No open public servers found with available player slots."
		Notification.show("Server Hop", errMsg, 4)
		return false, errMsg
	end

	-- Randomly pick a candidate to distribute player hops
	local targetServer = validServers[math.random(1, #validServers)]
	Notification.show("Server Hop", string.format("Connecting to server (%d/%d players)...", targetServer.playing, targetServer.maxPlayers), 4)

	local tpSuccess, tpErr = pcall(function()
		TeleportService:TeleportToPlaceInstance(placeId, targetServer.id, LocalPlayer)
	end)

	if not tpSuccess then
		local errMsg = string.format("Teleport failed: %s", tostring(tpErr))
		Notification.show("Server Hop Error", errMsg, 4)
		return false, errMsg
	end

	return true, string.format("Teleporting to %s", targetServer.id)
end

function PlayerUtilities.RejoinServer(): (boolean, string)
	Notification.show("Rejoin", "Reconnecting to current server instance...", 3)
	local placeId = game.PlaceId
	local jobId = game.JobId

	local tpSuccess, tpErr = pcall(function()
		if jobId and jobId ~= "" then
			TeleportService:TeleportToPlaceInstance(placeId, jobId, LocalPlayer)
		else
			TeleportService:Teleport(placeId, LocalPlayer)
		end
	end)

	if not tpSuccess then
		local errMsg = string.format("Rejoin failed: %s", tostring(tpErr))
		Notification.show("Rejoin Error", errMsg, 4)
		return false, errMsg
	end

	return true, "Rejoining current server..."
end

function PlayerUtilities.CopyPlaceId(): (boolean, string)
	local placeId = tostring(game.PlaceId)
	local copied = safeSetClipboard(placeId)
	local msg = if copied then string.format("Copied Place ID: %s", placeId) else string.format("Place ID: %s (clipboard unsupported)", placeId)
	Notification.show("Clipboard", msg, 3)
	return copied, msg
end

function PlayerUtilities.CopyGameId(): (boolean, string)
	local gameId = tostring(game.GameId)
	local copied = safeSetClipboard(gameId)
	local msg = if copied then string.format("Copied Game ID: %s", gameId) else string.format("Game ID: %s (clipboard unsupported)", gameId)
	Notification.show("Clipboard", msg, 3)
	return copied, msg
end

function PlayerUtilities.CopyJobId(): (boolean, string)
	local jobId = tostring(game.JobId)
	if jobId == "" then
		jobId = "Singleplayer / Studio Session"
	end
	local copied = safeSetClipboard(jobId)
	local msg = if copied then string.format("Copied Job ID: %s", jobId) else string.format("Job ID: %s", jobId)
	Notification.show("Clipboard", msg, 3)
	return copied, msg
end

function PlayerUtilities.SetAntiAFK(enabled: boolean)
	PlayerUtilities.AntiAFK = enabled
	if enabled then
		if antiAfkConn then
			antiAfkConn:Disconnect()
			antiAfkConn = nil
		end
		antiAfkConn = LocalPlayer.Idled:Connect(function()
			pcall(function()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.zero)
			end)
		end)
		Notification.show("Anti-AFK", "Anti-AFK timeout protection active", 2.5)
	else
		if antiAfkConn then
			antiAfkConn:Disconnect()
			antiAfkConn = nil
		end
		Notification.show("Anti-AFK", "Anti-AFK protection disabled", 2.5)
	end
end

function PlayerUtilities.GiveClickTeleportTool(): Tool
	if activeTool and activeTool.Parent then
		Notification.show("Click TP", "Click Teleport tool already in inventory", 2.5)
		return activeTool
	end

	local tool = Instance.new("Tool")
	tool.Name = "Click Teleport"
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.ToolTip = "Click anywhere in 3D world to teleport"

	tool.Activated:Connect(function()
		teleportToMouse()
	end)

	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack", 3)
	if backpack then
		tool.Parent = backpack
	elseif LocalPlayer.Character then
		tool.Parent = LocalPlayer.Character
	end

	activeTool = tool
	Notification.show("Click TP", "Received 'Click Teleport' tool in backpack", 3)
	return tool
end

function PlayerUtilities.SetClickTeleportEnabled(enabled: boolean)
	PlayerUtilities.ClickTeleport = enabled
	if enabled then
		if clickTpConn then
			clickTpConn:Disconnect()
			clickTpConn = nil
		end

		clickTpConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) then
					teleportToMouse()
				end
			end
		end)
		Notification.show("Click TP", "Ctrl+Click teleportation enabled", 2.5)
	else
		if clickTpConn then
			clickTpConn:Disconnect()
			clickTpConn = nil
		end
		Notification.show("Click TP", "Ctrl+Click teleportation disabled", 2.5)
	end
end

local function formatNumberValue(strVal: string): string
	local num = tonumber(strVal)
	if not num then return strVal end
	if num >= 1e12 then
		return string.format("%.2fT", num / 1e12)
	elseif num >= 1e9 then
		return string.format("%.2fB", num / 1e9)
	elseif num >= 1e6 then
		return string.format("%.2fM", num / 1e6)
	elseif num >= 1e3 then
		return string.format("%.1fK", num / 1e3)
	end
	return tostring(num)
end

function PlayerUtilities.getCurrenciesAndStats(): {{ Name: string, Value: string, Formatted: string, Source: string }}
	local results: {{ Name: string, Value: string, Formatted: string, Source: string }} = {}
	local seen: {[string]: boolean} = {}

	local function add(name: string, val: any, src: string)
		local strVal = tostring(val)
		if seen[name] or strVal == "" or #strVal > 40 then return end
		seen[name] = true
		table.insert(results, {
			Name = name,
			Value = strVal,
			Formatted = formatNumberValue(strVal),
			Source = src
		})
	end

	-- 1. Standard leaderstats folder
	local ls = LocalPlayer:FindFirstChild("leaderstats")
	if ls then
		for _, v in ipairs(ls:GetChildren()) do
			if v:IsA("ValueBase") then
				add(v.Name, (v :: any).Value, "leaderstats")
			end
		end
	end

	-- 2. Known stat/data folders on Player
	for _, folderName in ipairs({"Data", "Stats", "Values", "Currencies", "PlayerData"}) do
		local f = LocalPlayer:FindFirstChild(folderName)
		if f then
			for _, v in ipairs(f:GetChildren()) do
				if v:IsA("ValueBase") then
					add(v.Name, (v :: any).Value, folderName)
				end
			end
		end
	end

	-- 3. Game Remote Functions (e.g. GetPlayerData)
	pcall(function()
		local RepStorage = game:GetService("ReplicatedStorage")
		local gpd = RepStorage:FindFirstChild("GetPlayerData")
		if gpd and gpd:IsA("RemoteFunction") then
			local data = gpd:InvokeServer()
			if type(data) == "table" then
				for k, v in pairs(data) do
					if type(v) ~= "table" and type(v) ~= "function" and tostring(k) ~= "Name" and tostring(k) ~= "FirstJoin" and tostring(k) ~= "RandomNumber" then
						add(tostring(k), tostring(v), "PlayerData")
					end
				end
			end
		end
	end)

	-- 4. ScreenGui Currency TextLabels fallback
	local pgui = LocalPlayer:FindFirstChild("PlayerGui")
	if pgui then
		for _, d in ipairs(pgui:GetDescendants()) do
			if d:IsA("TextLabel") and d.Visible then
				local pName = d.Parent and d.Parent.Name:lower() or ""
				local dName = d.Name:lower()
				if string.find(pName, "coin") or string.find(pName, "cash") or string.find(pName, "money") or string.find(pName, "gem") or string.find(pName, "water") or string.find(dName, "coin") or string.find(dName, "cash") then
					if d.Text ~= "" and #d.Text < 30 and not string.find(d.Text, "BUY") then
						add(d.Parent.Name, d.Text, "PlayerGui")
					end
				end
			end
		end
	end

	return results
end

return PlayerUtilities
