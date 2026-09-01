--!strict
--[=[
    ✦ Restaurant Tycoon 3 Automation & Speed Suite ✦
    Features:
    - Auto Grab Cash & Table Bills (Collects all customer payments instantly)
    - Auto-Collect Tip Jars & Register Revenue
    - Auto-Collect Offline Earnings & Multipliers
    - Auto-Serve Customers (Take Orders, Hand Food, Clean Tables, Take Payments)
    - Auto-Catch Dine & Dashers Instantly
    - Auto-Claim Daily Rewards
    - Instant Cooking / Task Fast-Complete
    - Teleports (Kitchen, Cashier, Drive-Thru, Daily Rewards, Chef Luigi, Tables)
]=]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local RestaurantTycoon = {
	AutoGrabCash = true,
	AutoServeCustomers = false,
	AutoCatchDineAndDash = true,
	AutoCollectTips = true,
	AutoClaimDailyRewards = true,
	FastCooking = false,
	ServiceInterval = 0.20,
	CashInterval = 0.35,
}

local cashThread: thread? = nil
local serveThread: thread? = nil
local tipsThread: thread? = nil
local dineThread: thread? = nil
local cookingConn: RBXScriptConnection? = nil

local function getTycoon(): Instance?
	local tVal = LocalPlayer:FindFirstChild("Tycoon")
	if tVal and tVal:IsA("ObjectValue") and tVal.Value then
		return tVal.Value
	end
	if Workspace:FindFirstChild("Tycoons") then
		for _, t in ipairs(Workspace.Tycoons:GetChildren()) do
			local pVal = t:FindFirstChild("Player")
			if pVal and pVal:IsA("ObjectValue") and pVal.Value == LocalPlayer then
				return t
			end
		end
		return Workspace.Tycoons:FindFirstChild(LocalPlayer.Name) or Workspace.Tycoons:FindFirstChild("Tycoon")
	end
	return nil
end

local function firePrompt(prompt: ProximityPrompt)
	local fpp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
	if type(fpp) == "function" then
		pcall(function()
			prompt.HoldDuration = 0
			fpp(prompt)
		end)
	end
end

local function fireClick(cd: ClickDetector)
	local fcd = fireclickdetector or (getgenv and getgenv().fireclickdetector)
	if type(fcd) == "function" then
		pcall(function()
			fcd(cd)
		end)
	end
end

-- ── 1. Auto Grab Cash & Table Bills Engine ────────────────────────────
function RestaurantTycoon.grabAllCashNow(): number
	local tycoon = getTycoon()
	local rEvents = ReplicatedStorage:FindFirstChild("Events")
	local count = 0

	-- 1. Fire Remote Events for Tips and Offline Revenue
	pcall(function()
		local tipsRemote = rEvents and rEvents:FindFirstChild("Restaurant") and rEvents.Restaurant:FindFirstChild("TipsCollected")
		if tipsRemote then
			tipsRemote:FireServer()
			count += 1
		end
	end)

	pcall(function()
		local offlineRemote = rEvents and rEvents:FindFirstChild("Upgrades") and rEvents.Upgrades:FindFirstChild("CollectOfflineEarningsRequested")
		if offlineRemote then
			offlineRemote:FireServer()
			count += 1
		end
	end)

	if not tycoon then return count end

	local clickRemote = rEvents and rEvents:FindFirstChild("Restaurant") and rEvents.Restaurant:FindFirstChild("Interactions") and rEvents.Restaurant.Interactions:FindFirstChild("ClickableFurnitureInteracted")

	-- 2. Sweep Table Bills and Payments in Surface folder
	local surface = tycoon:FindFirstChild("Items") and tycoon.Items:FindFirstChild("Surface")
	if surface then
		for _, tableObj in ipairs(surface:GetChildren()) do
			-- Check for Bill model on table
			local bill = tableObj:FindFirstChild("Bill")
			if bill then
				if clickRemote then
					pcall(function() clickRemote:FireServer(tableObj) end)
				end
				for _, desc in ipairs(bill:GetDescendants()) do
					if desc:IsA("ClickDetector") then fireClick(desc) end
					if desc:IsA("ProximityPrompt") then firePrompt(desc) end
				end
				count += 1
			end

			-- Check for any Prompt / Click on table
			for _, desc in ipairs(tableObj:GetDescendants()) do
				if desc:IsA("ProximityPrompt") and desc.Enabled then
					local n = desc.Name:lower()
					local act = desc.ActionText:lower()
					if n:find("bill") or n:find("pay") or n:find("cash") or n:find("tip") or n:find("collect") or act:find("bill") or act:find("pay") or act:find("cash") or act:find("collect") then
						firePrompt(desc)
						count += 1
					end
				elseif desc:IsA("ClickDetector") then
					fireClick(desc)
					count += 1
				end
			end
		end
	end

	-- 3. Sweep Tip Jars and Register Furniture
	local furniture = tycoon:FindFirstChild("Items") and tycoon.Items:FindFirstChild("Furniture")
	if furniture then
		for _, item in ipairs(furniture:GetChildren()) do
			local jar = item:FindFirstChild("Jar") or item:FindFirstChild("Cash") or item:FindFirstChild("Coins")
			if jar or item.Name:lower():find("jar") or item.Name:lower():find("register") or item.Name:lower():find("tip") then
				if clickRemote then
					pcall(function() clickRemote:FireServer(item) end)
				end
				for _, desc in ipairs(item:GetDescendants()) do
					if desc:IsA("ClickDetector") then fireClick(desc) end
					if desc:IsA("ProximityPrompt") then firePrompt(desc) end
				end
				count += 1
			end
		end
	end

	return count
end

function RestaurantTycoon.setAutoGrabCash(enabled: boolean)
	RestaurantTycoon.AutoGrabCash = enabled
	if cashThread then
		task.cancel(cashThread)
		cashThread = nil
	end

	if enabled then
		cashThread = task.spawn(function()
			while RestaurantTycoon.AutoGrabCash do
				pcall(function()
					RestaurantTycoon.grabAllCashNow()
				end)
				task.wait(math.max(RestaurantTycoon.CashInterval, 0.2))
			end
		end)
	end
end

-- ── 2. Customer Service Engine ───────────────────────────────────────
function RestaurantTycoon.serveAllCustomersNow(): number
	local tycoon = getTycoon()
	if not tycoon then return 0 end

	local count = 0
	local clientCustomers = tycoon:FindFirstChild("ClientCustomers")
	if clientCustomers then
		for _, group in ipairs(clientCustomers:GetChildren()) do
			for _, npc in ipairs(group:GetChildren()) do
				local prompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
				if prompt and prompt.Enabled then
					firePrompt(prompt)
					count += 1
				end
			end
		end
	end

	-- Also sweep tables & furniture for prompts (cleaning dishes, taking orders)
	local items = tycoon:FindFirstChild("Items")
	if items then
		for _, desc in ipairs(items:GetDescendants()) do
			if desc:IsA("ProximityPrompt") and desc.Enabled then
				local n = desc.Name:lower()
				local act = desc.ActionText:lower()
				if n:find("customer") or n:find("order") or n:find("dish") or n:find("clean") or act:find("take") or act:find("serve") or act:find("clean") then
					firePrompt(desc)
					count += 1
				end
			end
		end
	end

	return count
end

function RestaurantTycoon.setAutoServe(enabled: boolean)
	RestaurantTycoon.AutoServeCustomers = enabled
	if serveThread then
		task.cancel(serveThread)
		serveThread = nil
	end

	if enabled then
		serveThread = task.spawn(function()
			while RestaurantTycoon.AutoServeCustomers do
				pcall(function()
					RestaurantTycoon.serveAllCustomersNow()
				end)
				task.wait(math.max(RestaurantTycoon.ServiceInterval, 0.15))
			end
		end)
	end
end

-- ── 3. Dine & Dash Auto-Catch Engine ─────────────────────────────────
function RestaurantTycoon.setAutoCatchDineAndDash(enabled: boolean)
	RestaurantTycoon.AutoCatchDineAndDash = enabled
	if dineThread then
		task.cancel(dineThread)
		dineThread = nil
	end

	if enabled then
		dineThread = task.spawn(function()
			while RestaurantTycoon.AutoCatchDineAndDash do
				pcall(function()
					local rEvents = ReplicatedStorage:FindFirstChild("Events")
					local dineRemote = rEvents and rEvents:FindFirstChild("Restaurant") and rEvents.Restaurant:FindFirstChild("Customers") and rEvents.Restaurant.Customers:FindFirstChild("DineAndDashCaught")
					local tycoon = getTycoon()

					if dineRemote and tycoon then
						local clientCustomers = tycoon:FindFirstChild("ClientCustomers")
						if clientCustomers then
							for _, group in ipairs(clientCustomers:GetChildren()) do
								for _, npc in ipairs(group:GetChildren()) do
									local tag = npc:FindFirstChild("DineAndDash") or npc:GetAttribute("DineAndDash")
									if tag then
										dineRemote:FireServer(npc)
										local prompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
										if prompt then firePrompt(prompt) end
									end
								end
							end
						end
					end
				end)
				task.wait(0.5)
			end
		end)
	end
end

-- ── 4. Tips & Revenue Collection Engine ──────────────────────────────
function RestaurantTycoon.collectTipsNow(): boolean
	local success = false
	pcall(function()
		local rEvents = ReplicatedStorage:FindFirstChild("Events")
		local tipsRemote = rEvents and rEvents:FindFirstChild("Restaurant") and rEvents.Restaurant:FindFirstChild("TipsCollected")
		if tipsRemote then
			tipsRemote:FireServer()
			success = true
		end

		local tycoon = getTycoon()
		if tycoon then
			for _, desc in ipairs(tycoon:GetDescendants()) do
				if desc:IsA("ProximityPrompt") and (desc.Name:lower():find("tip") or desc.ActionText:lower():find("tip") or desc.ActionText:lower():find("collect")) then
					firePrompt(desc)
					success = true
				end
			end
		end
	end)
	return success
end

function RestaurantTycoon.setAutoCollectTips(enabled: boolean)
	RestaurantTycoon.AutoCollectTips = enabled
	if tipsThread then
		task.cancel(tipsThread)
		tipsThread = nil
	end

	if enabled then
		tipsThread = task.spawn(function()
			while RestaurantTycoon.AutoCollectTips do
				pcall(function()
					RestaurantTycoon.collectTipsNow()
				end)
				task.wait(1.5)
			end
		end)
	end
end

-- ── 5. Daily Rewards Claimer ─────────────────────────────────────────
function RestaurantTycoon.claimDailyRewards(): boolean
	local claimed = false
	local tycoon = getTycoon()
	if tycoon then
		local defaultFolder = tycoon:FindFirstChild("Default")
		local dailyBox = defaultFolder and defaultFolder:FindFirstChild("DailyRewards")
		if dailyBox then
			local prompt = dailyBox:FindFirstChildWhichIsA("ProximityPrompt", true)
			if prompt then
				firePrompt(prompt)
				claimed = true
			end
		end
	end
	return claimed
end

-- ── 6. Fast Cooking Accelerator ─────────────────────────────────────
function RestaurantTycoon.setFastCooking(enabled: boolean)
	RestaurantTycoon.FastCooking = enabled
	if cookingConn then
		cookingConn:Disconnect()
		cookingConn = nil
	end

	if enabled then
		pcall(function()
			local rEvents = ReplicatedStorage:FindFirstChild("Events")
			local cookEvent = rEvents and rEvents:FindFirstChild("Cook") and rEvents.Cook:FindFirstChild("CookUpdated")
			local taskComp = rEvents and rEvents:FindFirstChild("Restaurant") and rEvents.Restaurant:FindFirstChild("TaskCompleted")

			if cookEvent and taskComp then
				cookingConn = cookEvent.OnClientEvent:Connect(function(...)
					if RestaurantTycoon.FastCooking then
						task.defer(function()
							pcall(function()
								taskComp:FireServer()
							end)
						end)
					end
				end)
			end
		end)
	end
end

-- ── 7. Fast Restaurant Teleports ─────────────────────────────────────
local function safeTeleport(targetCF: CFrame): boolean
	local char = LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return false end

	pcall(function()
		hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
		hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
		hum.PlatformStand = false
		hum.Sit = false
	end)
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	hrp.CFrame = targetCF * CFrame.new(0, 3, 0)
	pcall(function()
		hum:ChangeState(Enum.HumanoidStateType.Running)
	end)
	return true
end

function RestaurantTycoon.teleportToArea(areaName: string): boolean
	local tycoon = getTycoon()
	if not tycoon then return false end

	if areaName == "Kitchen" or areaName == "Cooking Stations" then
		local cookingRes = tycoon:FindFirstChild("Objects") and tycoon.Objects:FindFirstChild("CookingResources")
		local targetPart = cookingRes and cookingRes:FindFirstChildWhichIsA("BasePart", true)
		if targetPart then return safeTeleport(targetPart.CFrame) end
	elseif areaName == "Chef Luigi" then
		local luigi = tycoon:FindFirstChild("Default") and tycoon.Default:FindFirstChild("ChefLuigi")
		local hrp = luigi and (luigi:FindFirstChild("HumanoidRootPart") or luigi:FindFirstChildWhichIsA("BasePart"))
		if hrp then return safeTeleport(hrp.CFrame) end
	elseif areaName == "Daily Rewards" then
		local daily = tycoon:FindFirstChild("Default") and tycoon.Default:FindFirstChild("DailyRewards")
		local base = daily and daily:FindFirstChild("Base") :: BasePart?
		if base then return safeTeleport(base.CFrame) end
	elseif areaName == "Entrance / Sign" then
		local sign = tycoon:FindFirstChild("Default") and tycoon.Default:FindFirstChild("Signs")
		local p = sign and sign:FindFirstChildWhichIsA("BasePart", true)
		if p then return safeTeleport(p.CFrame) end
	elseif areaName == "Dining Tables" then
		local items = tycoon:FindFirstChild("Items")
		local p = items and items:FindFirstChildWhichIsA("BasePart", true)
		if p then return safeTeleport(p.CFrame) end
	end

	local anyPart = tycoon:FindFirstChildWhichIsA("BasePart", true)
	if anyPart then return safeTeleport(anyPart.CFrame) end
	return false
end

function RestaurantTycoon.getTeleportLocations(): {string}
	return {
		"Kitchen",
		"Chef Luigi",
		"Daily Rewards",
		"Entrance / Sign",
		"Dining Tables"
	}
end

return RestaurantTycoon
