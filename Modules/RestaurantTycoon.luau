--!strict
--[=[
    ✦ Restaurant Tycoon 3 Automation & Revenue Engine ✦
    High-performance native interaction pipeline:
    - Auto-Grab Cash & Table Bills (Fires TaskCompleted & Interactions directly with Tycoon reference)
    - Auto-Collect Tip Jar (Fires TipsCollected with Tycoon payload)
    - Auto-Collect Offline Earnings
    - Auto-Clean Dirty Dishes (TaskCompleted: CollectDishes)
    - Auto-Take Customer Orders (TaskCompleted: TakeOrder)
    - Auto-Catch Dine & Dashers Instantly
    - Instant Cooking Accelerator (CookInputRequested & ChefCookInputRequested)
    - Fast Safe Teleports
]=]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer

local RestaurantTycoon = {
	AutoGrabCash = true,
	AutoCleanDishes = true,
	AutoTakeOrders = true,
	AutoCollectTips = true,
	AutoCatchDineAndDash = true,
	AutoClaimDailyRewards = true,
	FastCooking = false,
	ServiceInterval = 0.20,
	CashInterval = 0.30,
}

local cashThread: thread? = nil
local orderThread: thread? = nil
local dishThread: thread? = nil
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

local function getInteractionsModule(): any?
	local pScripts = LocalPlayer:FindFirstChild("PlayerScripts")
	if pScripts and pScripts:FindFirstChild("Source") and pScripts.Source:FindFirstChild("Systems") and pScripts.Source.Systems:FindFirstChild("Restaurant") and pScripts.Source.Systems.Restaurant:FindFirstChild("Interactions") then
		local ok, mod = pcall(function()
			return require(pScripts.Source.Systems.Restaurant.Interactions)
		end)
		if ok and mod then return mod end
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

-- ── 1. NATIVE CASH & TABLE BILLS COLLECTION ENGINE ────────────────────
function RestaurantTycoon.grabAllCashNow(): number
	local tycoon = getTycoon()
	local rEvents = ReplicatedStorage:FindFirstChild("Events")
	local count = 0

	-- 1. Tips Collection (Passes tycoon instance)
	pcall(function()
		local tipsRemote = rEvents and rEvents:FindFirstChild("Restaurant") and rEvents.Restaurant:FindFirstChild("TipsCollected")
		if tipsRemote and tycoon then
			tipsRemote:FireServer(tycoon)
			count += 1
		end
	end)

	-- 2. Offline Revenue
	pcall(function()
		local offlineRemote = rEvents and rEvents:FindFirstChild("Upgrades") and rEvents.Upgrades:FindFirstChild("CollectOfflineEarningsRequested")
		if offlineRemote then
			offlineRemote:FireServer()
			count += 1
		end
	end)

	if not tycoon then return count end

	local taskRemote = rEvents and rEvents:FindFirstChild("Restaurant") and rEvents.Restaurant:FindFirstChild("TaskCompleted")
	local interactedRemote = rEvents and rEvents:FindFirstChild("Restaurant") and rEvents.Restaurant:FindFirstChild("Interactions") and rEvents.Restaurant.Interactions:FindFirstChild("Interacted")
	local interactionsMod = getInteractionsModule()

	-- 3. Sweep Active Interactions System Prompts for Bills
	if interactionsMod and interactionsMod.PromptData and interactionsMod.PromptData[tycoon] then
		for id, promptData in pairs(interactionsMod.PromptData[tycoon]) do
			if promptData.Key == "CollectBill" then
				if interactedRemote then
					pcall(function() interactedRemote:FireServer(tycoon, promptData) end)
				end
				if taskRemote and promptData.Model then
					pcall(function()
						taskRemote:FireServer({
							Name = "CollectBill",
							FurnitureModel = promptData.Model,
							Tycoon = tycoon
						})
					end)
				end
				count += 1
			end
		end
	end

	-- 4. Sweep Surface Tables Directly for Bills
	local surface = tycoon:FindFirstChild("Items") and tycoon.Items:FindFirstChild("Surface")
	if surface and taskRemote then
		for _, tableModel in ipairs(surface:GetChildren()) do
			local bill = tableModel:FindFirstChild("Bill")
			if bill and not bill:GetAttribute("Taken") then
				pcall(function()
					taskRemote:FireServer({
						Name = "CollectBill",
						FurnitureModel = tableModel,
						Tycoon = tycoon
					})
				end)
				count += 1
			end
		end
	end

	-- 5. Sweep Tagged Proximity Prompts
	for _, prompt in ipairs(CollectionService:GetTagged("Interaction")) do
		if prompt:IsA("ProximityPrompt") and prompt.Enabled then
			local n = prompt.Name:lower()
			local act = prompt.ActionText:lower()
			if n:find("bill") or n:find("pay") or n:find("cash") or n:find("tip") or n:find("collect") or act:find("bill") or act:find("pay") or act:find("cash") or act:find("collect") then
				firePrompt(prompt)
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
				task.wait(math.max(RestaurantTycoon.CashInterval, 0.15))
			end
		end)
	end
end

-- ── 2. AUTO-CLEAN DISHES ENGINE ──────────────────────────────────────
function RestaurantTycoon.cleanDishesNow(): number
	local tycoon = getTycoon()
	if not tycoon then return 0 end

	local rEvents = ReplicatedStorage:FindFirstChild("Events")
	local taskRemote = rEvents and rEvents:FindFirstChild("Restaurant") and rEvents.Restaurant:FindFirstChild("TaskCompleted")
	local interactedRemote = rEvents and rEvents:FindFirstChild("Restaurant") and rEvents.Restaurant:FindFirstChild("Interactions") and rEvents.Restaurant.Interactions:FindFirstChild("Interacted")
	local interactionsMod = getInteractionsModule()
	local count = 0

	if interactionsMod and interactionsMod.PromptData and interactionsMod.PromptData[tycoon] then
		for id, promptData in pairs(interactionsMod.PromptData[tycoon]) do
			if promptData.Key == "CollectDishes" then
				if interactedRemote then
					pcall(function() interactedRemote:FireServer(tycoon, promptData) end)
				end
				if taskRemote and promptData.Model then
					pcall(function()
						taskRemote:FireServer({
							Name = "CollectDishes",
							FurnitureModel = promptData.Model,
							Tycoon = tycoon
						})
					end)
				end
				count += 1
			end
		end
	end

	local surface = tycoon:FindFirstChild("Items") and tycoon.Items:FindFirstChild("Surface")
	if surface and taskRemote then
		for _, tableModel in ipairs(surface:GetChildren()) do
			local trash = tableModel:FindFirstChild("Trash")
			if trash and trash:GetAttribute("Collectable") then
				pcall(function()
					taskRemote:FireServer({
						Name = "CollectDishes",
						FurnitureModel = tableModel,
						Tycoon = tycoon
					})
				end)
				count += 1
			end
		end
	end

	return count
end

function RestaurantTycoon.setAutoCleanDishes(enabled: boolean)
	RestaurantTycoon.AutoCleanDishes = enabled
	if dishThread then
		task.cancel(dishThread)
		dishThread = nil
	end

	if enabled then
		dishThread = task.spawn(function()
			while RestaurantTycoon.AutoCleanDishes do
				pcall(function()
					RestaurantTycoon.cleanDishesNow()
				end)
				task.wait(0.4)
			end
		end)
	end
end

-- ── 3. AUTO-TAKE ORDERS & SERVE ENGINE ───────────────────────────────
function RestaurantTycoon.takeOrdersNow(): number
	local tycoon = getTycoon()
	if not tycoon then return 0 end

	local rEvents = ReplicatedStorage:FindFirstChild("Events")
	local taskRemote = rEvents and rEvents:FindFirstChild("Restaurant") and rEvents.Restaurant:FindFirstChild("TaskCompleted")
	local interactedRemote = rEvents and rEvents:FindFirstChild("Restaurant") and rEvents.Restaurant:FindFirstChild("Interactions") and rEvents.Restaurant.Interactions:FindFirstChild("Interacted")
	local count = 0

	-- Sweep customer models in ClientCustomers
	local clientCustomers = tycoon:FindFirstChild("ClientCustomers")
	if clientCustomers and taskRemote then
		for _, group in ipairs(clientCustomers:GetChildren()) do
			local groupId = group.Name
			for _, npc in ipairs(group:GetChildren()) do
				local customerId = npc.Name
				local prompt = npc:FindFirstChildWhichIsA("ProximityPrompt", true)
				if prompt and prompt.Enabled then
					firePrompt(prompt)
					pcall(function()
						taskRemote:FireServer({
							Name = "TakeOrder",
							GroupId = groupId,
							CustomerId = customerId,
							Tycoon = tycoon
						})
					end)
					count += 1
				end
			end
		end
	end

	return count
end

function RestaurantTycoon.setAutoServe(enabled: boolean)
	RestaurantTycoon.AutoTakeOrders = enabled
	if orderThread then
		task.cancel(orderThread)
		orderThread = nil
	end

	if enabled then
		orderThread = task.spawn(function()
			while RestaurantTycoon.AutoTakeOrders do
				pcall(function()
					RestaurantTycoon.takeOrdersNow()
				end)
				task.wait(math.max(RestaurantTycoon.ServiceInterval, 0.25))
			end
		end)
	end
end

-- ── 4. AUTO-CATCH DINE & DASHERS ─────────────────────────────────────
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
									if npc:FindFirstChild("DineAndDash") or npc:GetAttribute("DineAndDash") then
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

-- ── 5. TIPS & REVENUE ────────────────────────────────────────────────
function RestaurantTycoon.collectTipsNow(): boolean
	local success = false
	pcall(function()
		local tycoon = getTycoon()
		local rEvents = ReplicatedStorage:FindFirstChild("Events")
		local tipsRemote = rEvents and rEvents:FindFirstChild("Restaurant") and rEvents.Restaurant:FindFirstChild("TipsCollected")
		if tipsRemote and tycoon then
			tipsRemote:FireServer(tycoon)
			success = true
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

-- ── 6. DAILY REWARDS ─────────────────────────────────────────────────
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

-- ── 7. FAST COOKING ACCELERATOR ──────────────────────────────────────
function RestaurantTycoon.setFastCooking(enabled: boolean)
	RestaurantTycoon.FastCooking = enabled
	if cookingConn then
		cookingConn:Disconnect()
		cookingConn = nil
	end

	if enabled then
		pcall(function()
			local rEvents = ReplicatedStorage:FindFirstChild("Events")
			local cookReq = rEvents and rEvents:FindFirstChild("Cook") and rEvents.Cook:FindFirstChild("CookInputRequested")
			local chefCookReq = rEvents and rEvents:FindFirstChild("Cook") and rEvents.Cook:FindFirstChild("ChefCookInputRequested")
			local cookEvent = rEvents and rEvents:FindFirstChild("Cook") and rEvents.Cook:FindFirstChild("CookUpdated")

			if cookEvent and cookReq then
				cookingConn = cookEvent.OnClientEvent:Connect(function(...)
					if RestaurantTycoon.FastCooking then
						task.defer(function()
							pcall(function()
								cookReq:FireServer("CompleteTask")
								if chefCookReq then
									chefCookReq:FireServer("CompleteTask", "Chef", "Chef")
								end
							end)
						end)
					end
				end)
			end
		end)
	end
end

-- ── 8. SAFE TELEPORTS ────────────────────────────────────────────────
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
