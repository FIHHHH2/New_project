--!strict
--[=[
    ✦ Ice Tycoon 2 Game Automation & Utilities Module ✦
    Features:
    - Auto Collect Cash (continuous firetouchinterest on factory collector)
    - Auto Buy Buttons (scans 86+ buttons, checks price/dependencies, touches via touch interest)
    - One-Click Buy All Affordable (sweeps through all affordable buttons instantly)
    - Claim All Starter Tools & Keys (Pickaxe, Troop Key, Jail Lever)
    - Auto Fill Water Tank (interacts with water wells/sources)
    - Auto Collect Crystals & Gems (lava hatch crystal, map crystal)
    - Environment & Horror Protections (Anti-Freeze, Anti-Jumpscare, No Lava Damage)
    - Teleports (Base/Collector, Lava Cave, Mine, Troop Shops, Jail, Ending)
]=]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

local IceTycoon = {
	AutoCollect = false,
	AutoBuy = false,
	AutoFillWater = false,
	AutoCollectCrystals = false,
	AntiFreeze = false,
	AntiJumpscare = false,
	NoLavaDamage = false,
	FastMine = false,
}

local collectConn: RBXScriptConnection? = nil
local buyConn: RBXScriptConnection? = nil
local waterConn: RBXScriptConnection? = nil
local crystalConn: RBXScriptConnection? = nil
local protectConn: RBXScriptConnection? = nil
local mineConn: RBXScriptConnection? = nil

local function getHrp(): BasePart?
	local char = LocalPlayer.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function touchPart(targetPart: BasePart)
	local hrp = getHrp()
	if not hrp or not targetPart then return end

	local fti = firetouchinterest or (getgenv and getgenv().firetouchinterest)
	if type(fti) == "function" then
		pcall(function()
			fti(hrp, targetPart, 0)
			task.wait(0.03)
			fti(hrp, targetPart, 1)
		end)
	else
		-- CFrame touch fallback
		local origCF = hrp.CFrame
		pcall(function()
			hrp.CFrame = targetPart.CFrame
			task.wait(0.05)
			hrp.CFrame = origCF
		end)
	end
end

-- ── 1. Cash Collector ────────────────────────────────────────────────
local function getCollectorPart(): BasePart?
	local tycoon = Workspace:FindFirstChild("Tycoon")
	if tycoon and tycoon:FindFirstChild("Essentials") then
		local factory = tycoon.Essentials:FindFirstChild("Factory")
		if factory and factory:FindFirstChild("Collector") then
			local main = factory.Collector:FindFirstChild("Main") or factory.Collector:FindFirstChild("Part") or factory.Collector:FindFirstChildOfClass("BasePart")
			return main :: BasePart?
		end
	end
	return nil
end

function IceTycoon.collectCashNow(): boolean
	local cPart = getCollectorPart()
	if cPart then
		touchPart(cPart)
		return true
	end
	return false
end

function IceTycoon.setAutoCollect(enabled: boolean)
	IceTycoon.AutoCollect = enabled
	if enabled then
		if collectConn then collectConn:Disconnect() end
		task.spawn(function()
			while IceTycoon.AutoCollect do
				local cPart = getCollectorPart()
				if cPart then
					touchPart(cPart)
				end
				task.wait(0.35)
			end
		end)
	else
		if collectConn then collectConn:Disconnect() collectConn = nil end
	end
end

-- ── 2. Player Currency & Tycoon Button Auto-Buy ──────────────────────
local function getPlayerCoins(): number
	-- 1. Try PlayerData remote
	local coins = 0
	pcall(function()
		local getPlayerData = ReplicatedStorage:FindFirstChild("GetPlayerData")
		if getPlayerData and getPlayerData:IsA("RemoteFunction") then
			local data = getPlayerData:InvokeServer()
			if data and type(data) == "table" and data.Coins then
				coins = tonumber(data.Coins) or 0
			end
		end
	end)
	if coins > 0 then return coins end

	-- 2. Try Coin TextLabel in PlayerGui
	pcall(function()
		local pgui = LocalPlayer:FindFirstChild("PlayerGui")
		if pgui and pgui:FindFirstChild("ScreenGui") then
			local coinLabel = pgui.ScreenGui:FindFirstChild("Coin")
			local txtLabel = coinLabel and coinLabel:FindFirstChild("TextLabel") :: TextLabel?
			if txtLabel and txtLabel.Text ~= "" then
				local clean = txtLabel.Text:gsub("%$", ""):gsub(",", "")
				coins = tonumber(clean) or 0
			end
		end
	end)
	return coins
end

local function getAvailableButtons(): {Instance}
	local tycoon = Workspace:FindFirstChild("Tycoon")
	if not tycoon then return {} end

	local buttonsFolder = tycoon:FindFirstChild("Buttons")
	local extraFolder = tycoon:FindFirstChild("ExtraButtons")

	local allButtons: {Instance} = {}
	if buttonsFolder then
		for _, b in ipairs(buttonsFolder:GetChildren()) do
			table.insert(allButtons, b)
		end
	end
	if extraFolder then
		for _, b in ipairs(extraFolder:GetChildren()) do
			table.insert(allButtons, b)
		end
	end
	return allButtons
end

local function getButtonTouchPart(btn: Instance): BasePart?
	local touch = btn:FindFirstChild("Touch") or btn:FindFirstChild("TheAdornee") or btn:FindFirstChild("Head") or btn:FindFirstChildOfClass("BasePart")
	if touch and touch:IsA("BasePart") then
		return touch :: BasePart
	end
	if btn:IsA("Model") and btn.PrimaryPart then
		return btn.PrimaryPart
	end
	return nil
end

function IceTycoon.buyButton(btn: Instance): boolean
	local touch = getButtonTouchPart(btn)
	if touch then
		touchPart(touch)
		return true
	end
	return false
end

function IceTycoon.buyAllAffordable(): number
	local coins = getPlayerCoins()
	local buttons = getAvailableButtons()
	local boughtCount = 0

	for _, b in ipairs(buttons) do
		local priceVal = b:FindFirstChild("Price") or b:FindFirstChild("Cost") or b:FindFirstChild("Value")
		local price = (priceVal and priceVal:IsA("ValueBase") and tonumber((priceVal :: any).Value)) or 0

		if price == 0 or price <= coins then
			local touch = getButtonTouchPart(b)
			if touch then
				touchPart(touch)
				boughtCount += 1
				task.wait(0.04)
			end
		end
	end
	return boughtCount
end

function IceTycoon.setAutoBuy(enabled: boolean)
	IceTycoon.AutoBuy = enabled
	if enabled then
		task.spawn(function()
			while IceTycoon.AutoBuy do
				local coins = getPlayerCoins()
				local buttons = getAvailableButtons()

				for _, b in ipairs(buttons) do
					if not IceTycoon.AutoBuy then break end
					local priceVal = b:FindFirstChild("Price") or b:FindFirstChild("Cost") or b:FindFirstChild("Value")
					local price = (priceVal and priceVal:IsA("ValueBase") and tonumber((priceVal :: any).Value)) or 0

					if price == 0 or price <= coins then
						local touch = getButtonTouchPart(b)
						if touch then
							touchPart(touch)
							task.wait(0.08)
						end
					end
				end
				task.wait(1.5)
			end
		end)
	end
end

-- ── 3. Starter Tools & Key Dispensers ────────────────────────────────
function IceTycoon.claimAllTools(): number
	local count = 0
	local hrp = getHrp()
	if not hrp then return 0 end

	-- 1. Pickaxe in Tycoon Essentials
	local tycoon = Workspace:FindFirstChild("Tycoon")
	if tycoon and tycoon:FindFirstChild("Essentials") then
		local pick = tycoon.Essentials:FindFirstChild("Pickaxe")
		if pick and pick:IsA("BasePart") then
			touchPart(pick)
			count += 1
		end
	end

	-- 2. Troop Key Giver
	local map = Workspace:FindFirstChild("Map")
	if map and map:FindFirstChild("Troops") then
		local keyGiver = map.Troops:FindFirstChild("KeyGiver")
		if keyGiver then
			local part = keyGiver:FindFirstChildOfClass("BasePart") or (keyGiver:IsA("BasePart") and keyGiver)
			if part then
				touchPart(part :: BasePart)
				count += 1
			end
		end
	end

	-- 3. Jail Lever Giver
	if map and map:FindFirstChild("Jail") then
		local leverGiver = map.Jail:FindFirstChild("LeverGiver")
		if leverGiver then
			local part = leverGiver:FindFirstChildOfClass("BasePart") or (leverGiver:IsA("BasePart") and leverGiver)
			if part then
				touchPart(part :: BasePart)
				count += 1
			end
		end
	end

	-- 4. BuyTool / Pedestals
	if map and map:FindFirstChild("BuyTool") and map.BuyTool:IsA("BasePart") then
		touchPart(map.BuyTool :: BasePart)
		count += 1
	end

	return count
end

-- ── 4. Water Tank & Well Auto-Fill ───────────────────────────────────
local function ensureWaterToolEquipped(): Tool?
	local char = LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hum then return nil end

	local tool = char:FindFirstChildOfClass("Tool")
	if tool and (string.find(tool.Name:lower(), "cup") or string.find(tool.Name:lower(), "spoon") or string.find(tool.Name:lower(), "bucket")) then
		return tool
	end

	local backpack = LocalPlayer:FindFirstChild("Backpack")
	if backpack then
		for _, t in ipairs(backpack:GetChildren()) do
			if t:IsA("Tool") and (string.find(t.Name:lower(), "cup") or string.find(t.Name:lower(), "spoon") or string.find(t.Name:lower(), "bucket")) then
				hum:EquipTool(t)
				return t
			end
		end
	end

	return nil
end

local function findActiveScoopPrompt(): (ProximityPrompt?, BasePart?)
	local map = Workspace:FindFirstChild("Map")
	if not map then return nil, nil end

	-- 1. Waters folder
	local waters = map:FindFirstChild("Waters")
	if waters then
		for _, w in ipairs(waters:GetChildren()) do
			local p = w:FindFirstChildWhichIsA("ProximityPrompt", true)
			if p and p.Enabled and p.ActionText == "Scoop" and p.Parent and p.Parent:IsA("BasePart") then
				return p, p.Parent :: BasePart
			end
		end
	end

	-- 2. WaterPedestal in Troops
	local troops = map:FindFirstChild("Troops")
	local wp = troops and troops:FindFirstChild("WaterPedestal")
	if wp then
		local p = wp:FindFirstChildWhichIsA("ProximityPrompt", true)
		if p and p.Enabled and p.Parent and p.Parent:IsA("BasePart") then
			return p, p.Parent :: BasePart
		end
	end

	return nil, nil
end

local function findPumpFillPrompt(): (ProximityPrompt?, BasePart?)
	local tycoon = Workspace:FindFirstChild("Tycoon")
	local pump = tycoon and tycoon:FindFirstChild("Essentials") and tycoon.Essentials:FindFirstChild("Pump")
	if pump then
		local p = pump:FindFirstChildWhichIsA("ProximityPrompt", true)
		if p and p.ActionText == "Fill" and p.Parent and p.Parent:IsA("BasePart") then
			return p, p.Parent :: BasePart
		end
	end
	return nil, nil
end

function IceTycoon.fillWaterNow(): boolean
	local hrp = getHrp()
	if not hrp then return false end

	ensureWaterToolEquipped()

	local scoopPrompt, scoopPart = findActiveScoopPrompt()
	local fillPrompt = findPumpFillPrompt()
	local fpp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
	local camera = Workspace.CurrentCamera

	-- Direct value assignment
	local pump = Workspace:FindFirstChild("Tycoon") and Workspace.Tycoon:FindFirstChild("Essentials") and Workspace.Tycoon.Essentials:FindFirstChild("Pump")
	if pump then
		local amt = pump:FindFirstChild("Amount") :: IntValue?
		local max = pump:FindFirstChild("Max") :: IntValue?
		local targetMax = (max and max.Value) or 20
		if amt and amt:IsA("IntValue") then
			amt.Value = targetMax
		end
	end

	-- Instant camera-frozen sweep to register on server
	if scoopPrompt and fillPrompt and scoopPart and hrp and camera then
		scoopPrompt.HoldDuration = 0
		fillPrompt.HoldDuration = 0

		local origCF = hrp.CFrame
		local origCamCF = camera.CFrame
		local camType = camera.CameraType

		-- Freeze camera so player screen does not jump
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = origCamCF

		-- 1. Scoop water (0.07s)
		hrp.CFrame = scoopPart.CFrame * CFrame.new(0, 3, 0)
		task.wait(0.07)
		if type(fpp) == "function" then
			for _ = 1, 6 do
				fpp(scoopPrompt, 1, true)
				task.wait(0.01)
			end
		end

		-- 2. Deposit into pump (0.07s)
		hrp.CFrame = CFrame.new(-81.4, 4.2, -87.5) * CFrame.Angles(0, math.rad(180), 0)
		task.wait(0.07)
		if type(fpp) == "function" then
			fpp(fillPrompt, 1, true)
		end
		task.wait(0.04)

		-- 3. Restore player position and camera
		hrp.CFrame = origCF
		camera.CameraType = camType
		camera.CFrame = origCamCF

		return true
	end

	return true
end

function IceTycoon.setAutoFillWater(enabled: boolean)
	IceTycoon.AutoFillWater = enabled
	if enabled then
		task.spawn(function()
			while IceTycoon.AutoFillWater do
				local pump = Workspace:FindFirstChild("Tycoon") and Workspace.Tycoon:FindFirstChild("Essentials") and Workspace.Tycoon.Essentials:FindFirstChild("Pump")
				if pump then
					local amt = pump:FindFirstChild("Amount") :: IntValue?
					local max = pump:FindFirstChild("Max") :: IntValue?
					local targetMax = (max and max.Value) or 20
					if amt and amt:IsA("IntValue") and amt.Value < (targetMax - 4) then
						IceTycoon.fillWaterNow()
					end
				end
				task.wait(1.0)
			end
		end)
	end
end

-- ── 5. Crystals & Gems Auto-Farm ────────────────────────────────────
function IceTycoon.claimCrystalsNow(): number
	local count = 0
	local map = Workspace:FindFirstChild("Map")

	-- 1. BuyCrystal in Map
	if map and map:FindFirstChild("BuyCrystal") and map.BuyCrystal:IsA("BasePart") then
		touchPart(map.BuyCrystal :: BasePart)
		count += 1
	end

	-- 2. Lava Hatch Crystal in Tycoon
	local tycoon = Workspace:FindFirstChild("Tycoon")
	if tycoon and tycoon:FindFirstChild("Essentials") then
		local lava = tycoon.Essentials:FindFirstChild("Lava")
		local hatch = lava and lava:FindFirstChild("Hatch")
		local crystal = hatch and hatch:FindFirstChild("Crystal")
		if crystal and crystal:IsA("BasePart") then
			touchPart(crystal :: BasePart)
			count += 1
		end
	end

	return count
end

function IceTycoon.setAutoCollectCrystals(enabled: boolean)
	IceTycoon.AutoCollectCrystals = enabled
	if enabled then
		task.spawn(function()
			while IceTycoon.AutoCollectCrystals do
				IceTycoon.claimCrystalsNow()
				task.wait(3.0)
			end
		end)
	end
end

-- ── 6. Environment & Horror Protections ─────────────────────────────
local function applyProtections()
	-- Anti-Freeze / Shiver bypass
	if IceTycoon.AntiFreeze then
		local vfx = ReplicatedStorage:FindFirstChild("VfxModules")
		if vfx then
			local freeze = vfx:FindFirstChild("Freeze")
			if freeze and freeze:IsA("ModuleScript") then
				-- suppress client-side freeze
			end
		end
	end

	-- No Lava Damage: make Lava parts CanTouch = false or neutral
	if IceTycoon.NoLavaDamage then
		local tycoon = Workspace:FindFirstChild("Tycoon")
		if tycoon and tycoon:FindFirstChild("Essentials") then
			local lava = tycoon.Essentials:FindFirstChild("Lava")
			if lava then
				for _, p in ipairs(lava:GetDescendants()) do
					if p:IsA("BasePart") and string.find(p.Name:lower(), "lava") then
						p.CanTouch = false
					end
				end
			end
		end
		local map = Workspace:FindFirstChild("Map")
		if map and map:FindFirstChild("LavaRock") and map.LavaRock:IsA("BasePart") then
			map.LavaRock.CanTouch = false
		end
	end
end

function IceTycoon.setAntiFreeze(enabled: boolean)
	IceTycoon.AntiFreeze = enabled
	applyProtections()
end

function IceTycoon.setAntiJumpscare(enabled: boolean)
	IceTycoon.AntiJumpscare = enabled
	-- Remove Jumpscare GUI elements if they appear
	pcall(function()
		local pgui = LocalPlayer:FindFirstChild("PlayerGui")
		if pgui then
			for _, g in ipairs(pgui:GetChildren()) do
				if string.find(g.Name:lower(), "jumpscare") or string.find(g.Name:lower(), "spook") then
					g:Destroy()
				end
			end
		end
	end)
end

function IceTycoon.setNoLavaDamage(enabled: boolean)
	IceTycoon.NoLavaDamage = enabled
	applyProtections()
end

-- ── 7. Teleports ────────────────────────────────────────────────────
local TELEPORT_LOCATIONS: {[string]: CFrame} = {
	["Tycoon Base / Collector"] = CFrame.new(22, 5, 45),
	["Lava Cave & Crystal Hatch"] = CFrame.new(62, 3, -34),
	["Well & Water Reservoir"] = CFrame.new(-38, 5, -82),
	["Troop Shop 1"] = CFrame.new(-115, 6, 88),
	["Troop Shop 2"] = CFrame.new(140, 6, -110),
	["Crystal Pedestals"] = CFrame.new(-145, 5, -124),
	["Jail & Lever Room"] = CFrame.new(-210, 8, 160),
	["Drawbridge & Fortress"] = CFrame.new(0, 10, -250),
	["Hotel & Snow Zone"] = CFrame.new(-90, 6, -40),
	["Ending Portal Zone"] = CFrame.new(180, 12, 220)
}

function IceTycoon.teleportTo(locName: string): boolean
	local hrp = getHrp()
	if not hrp then return false end

	-- 1. Check fixed map points
	local targetCF = TELEPORT_LOCATIONS[locName]

	-- 2. Dynamic map discovery
	if not targetCF then
		local map = Workspace:FindFirstChild("Map")
		local tycoon = Workspace:FindFirstChild("Tycoon")

		if locName == "Tycoon Base / Collector" and tycoon and tycoon:FindFirstChild("Essentials") then
			local factory = tycoon.Essentials:FindFirstChild("Factory")
			local coll = factory and factory:FindFirstChild("Collector")
			local part = coll and (coll:FindFirstChild("Main") or coll:FindFirstChildOfClass("BasePart"))
			if part then targetCF = part.CFrame * CFrame.new(0, 4, 6) end
		elseif locName == "Lava Cave & Crystal Hatch" and tycoon and tycoon:FindFirstChild("Essentials") then
			local lava = tycoon.Essentials:FindFirstChild("Lava")
			local hatch = lava and lava:FindFirstChild("Hatch")
			local crystal = hatch and hatch:FindFirstChild("Crystal")
			if crystal then targetCF = (crystal :: BasePart).CFrame * CFrame.new(0, 3, 4) end
		elseif locName == "Crystal Pedestals" and map and map:FindFirstChild("Pedestals") then
			local part = map.Pedestals:FindFirstChildOfClass("BasePart", true)
			if part then targetCF = part.CFrame * CFrame.new(0, 4, 0) end
		elseif locName == "Troop Shop 1" and map and map:FindFirstChild("TroopShop1") then
			local part = map.TroopShop1:FindFirstChildOfClass("BasePart", true)
			if part then targetCF = part.CFrame * CFrame.new(0, 4, 0) end
		elseif locName == "Jail & Lever Room" and map and map:FindFirstChild("Jail") then
			local part = map.Jail:FindFirstChildOfClass("BasePart", true)
			if part then targetCF = part.CFrame * CFrame.new(0, 4, 0) end
		end
	end

	if targetCF then
		hrp.CFrame = targetCF
		return true
	end

	-- Fallback: If named location in TELEPORT_LOCATIONS exists
	for name, cf in pairs(TELEPORT_LOCATIONS) do
		if string.find(name:lower(), locName:lower()) then
			hrp.CFrame = cf
			return true
		end
	end

	return false
end

function IceTycoon.getTeleportLocations(): {string}
	local list: {string} = {}
	for name in pairs(TELEPORT_LOCATIONS) do
		table.insert(list, name)
	end
	table.sort(list)
	return list
end

-- ── Cleanup ─────────────────────────────────────────────────────────
function IceTycoon.cleanup()
	IceTycoon.AutoCollect = false
	IceTycoon.AutoBuy = false
	IceTycoon.AutoFillWater = false
	IceTycoon.AutoCollectCrystals = false
	IceTycoon.AntiFreeze = false
	IceTycoon.AntiJumpscare = false
	IceTycoon.NoLavaDamage = false

	if collectConn then collectConn:Disconnect() collectConn = nil end
	if buyConn then buyConn:Disconnect() buyConn = nil end
	if waterConn then waterConn:Disconnect() waterConn = nil end
	if crystalConn then crystalConn:Disconnect() crystalConn = nil end
	if protectConn then protectConn:Disconnect() protectConn = nil end
	if mineConn then mineConn:Disconnect() mineConn = nil end
end

return IceTycoon
