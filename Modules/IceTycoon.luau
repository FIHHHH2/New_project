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
	SmartPriorityBuy = true,
	AutoFillWater = false,
	AutoCollectCrystals = false,
	AntiFreeze = false,
	AntiJumpscare = false,
	NoLavaDamage = false,
	FastMine = false,
	FastConveyors = false,
	ConveyorSpeed = 75,
	FastGenerators = false,
	GeneratorSpeed = 120,
	OreMagnet = false,
	DuplicatedSellNodes = false,
	AutoArmyFight = false,
}

if _G.__ModularTycoon_Cleanup then
	pcall(_G.__ModularTycoon_Cleanup)
	_G.__ModularTycoon_Cleanup = nil
end

local collectConn: RBXScriptConnection? = nil
local buyConn: RBXScriptConnection? = nil
local waterConn: RBXScriptConnection? = nil
local crystalConn: RBXScriptConnection? = nil
local protectConn: RBXScriptConnection? = nil
local mineConn: RBXScriptConnection? = nil
local conveyorConn: RBXScriptConnection? = nil
local generatorConn: RBXScriptConnection? = nil
local partsAddedConn: RBXScriptConnection? = nil
local oreMagnetConn: RBXScriptConnection? = nil

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

local function getButtonPriority(btn: Instance): number
	local name = string.lower(btn.Name)
	-- Priority 1: Direct Money/Ore Multipliers (Droppers, Upgraders, Saws, Factory, Generators)
	if name:find("dropper") or name:find("upgrader") or name:find("saw") or name:find("generator") or name:find("collector") or name:find("gemthing") or name:find("gemreceiver") then
		return 100
	-- Priority 2: Production Infrastructures (Conveyors, Pumps, Farms, Domes, Wells)
	elseif name:find("conveyor") or name:find("pump") or name:find("farm") or name:find("dome") or name:find("speed") or name:find("multiplier") then
		return 80
	-- Priority 3: Gameplay & Rebirth unlocks (Rebirth, Troops, Units, Keys, Levers)
	elseif name:find("rebirth") or name:find("troop") or name:find("unit") or name:find("key") then
		return 60
	-- Priority 4: Structural access (Doors, Ladders, Bridges, Vaults)
	elseif name:find("door") or name:find("ladder") or name:find("bridge") or name:find("vault") then
		return 40
	-- Priority 5 (Lowest): Cosmetic / Decorative (Walls, Roofs, Windows, Lights, Decor, Signs)
	else
		return 10
	end
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

	if IceTycoon.SmartPriorityBuy then
		table.sort(buttons, function(a, b)
			return getButtonPriority(a) > getButtonPriority(b)
		end)
	end

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

				if IceTycoon.SmartPriorityBuy then
					table.sort(buttons, function(a, b)
						return getButtonPriority(a) > getButtonPriority(b)
					end)
				end

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
				task.wait(1.2)
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

local function ensureWaterCupAvailable(): Tool?
	local lp = Players.LocalPlayer
	local char = lp.Character
	local bp = lp:FindFirstChildOfClass("Backpack")
	local hum = char and char:FindFirstChildOfClass("Humanoid")

	-- 1. Check if already in Character or Backpack
	if char then
		for _, c in ipairs(char:GetChildren()) do
			if c:IsA("Tool") and string.find(c.Name:lower(), "cup") then
				return c
			end
		end
	end
	if bp then
		for _, c in ipairs(bp:GetChildren()) do
			if c:IsA("Tool") and string.find(c.Name:lower(), "cup") then
				if hum then
					pcall(function() hum:EquipTool(c) end)
				end
				return c
			end
		end
	end

	-- 2. If no Cup tool exists, grab one from the WaterPedestal bucket
	local hrp = getHrp()
	local map = Workspace:FindFirstChild("Map")
	local bucket = map and map:FindFirstChild("Troops") and map.Troops:FindFirstChild("WaterPedestal") and map.Troops.WaterPedestal:FindFirstChild("Bucket")
	local prompt = bucket and bucket:FindFirstChildWhichIsA("ProximityPrompt", true)
	local fpp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)

	if hrp and bucket and bucket:IsA("BasePart") and prompt and type(fpp) == "function" then
		local origCF = hrp.CFrame
		local cam = Workspace.CurrentCamera
		local camType = cam and cam.CameraType
		local camCF = cam and cam.CFrame

		if cam and camCF then
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = camCF
		end

		hrp.CFrame = bucket.CFrame * CFrame.new(0, 2, 0)
		task.wait(0.06)
		prompt.HoldDuration = 0
		fpp(prompt, 1, true)
		task.wait(0.04)

		hrp.CFrame = origCF
		if cam and camCF and camType then
			cam.CameraType = camType
			cam.CFrame = camCF
		end

		-- Check backpack for acquired tool
		if bp then
			for _, c in ipairs(bp:GetChildren()) do
				if c:IsA("Tool") and string.find(c.Name:lower(), "cup") then
					if hum then pcall(function() hum:EquipTool(c) end) end
					return c
				end
			end
		end
	end

	return nil
end

function IceTycoon.fillWaterNow(): boolean
	local hrp = getHrp()
	if not hrp then return false end

	ensureWaterCupAvailable()
	task.wait(0.04)

	local scoopPrompt, scoopPart = findActiveScoopPrompt()
	local fillPrompt, fillPart = findPumpFillPrompt()
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

		-- 1. Scoop water (10 rapid pulses to guarantee full capacity)
		hrp.CFrame = scoopPart.CFrame * CFrame.new(0, 3, 0)
		task.wait(0.08)
		if type(fpp) == "function" then
			for _ = 1, 10 do
				fpp(scoopPrompt, 1, true)
				task.wait(0.015)
			end
		end

		-- 2. Deposit into pump (double verified triggers)
		local depositPos = (fillPart and fillPart.CFrame * CFrame.new(0, 2, 0)) or (CFrame.new(-81.4, 4.2, -87.5) * CFrame.Angles(0, math.rad(180), 0))
		hrp.CFrame = depositPos
		task.wait(0.08)
		if type(fpp) == "function" then
			fpp(fillPrompt, 1, true)
			task.wait(0.04)
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
					local targetMax = (max and max.Value) or 50
					local halfCapacity = targetMax * 0.5
					-- Only fill when water level is strictly under 50% capacity
					if amt and amt:IsA("IntValue") and amt.Value < halfCapacity then
						IceTycoon.fillWaterNow()
					end
				end
				task.wait(0.9)
			end
		end)
	end
end

-- ── 5. Mine Ores Auto-Farm ──────────────────────────────────────────
IceTycoon.AutoMineOres = false

function IceTycoon.mineOresNow(): number
	local mine = Workspace:FindFirstChild("Tycoon") and Workspace.Tycoon:FindFirstChild("Bought") and Workspace.Tycoon.Bought:FindFirstChild("Mine")
	local fpp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
	local mined = 0

	if mine and type(fpp) == "function" then
		for _, d in ipairs(mine:GetDescendants()) do
			if d:IsA("ProximityPrompt") and d.ActionText == "Mine" and d.Enabled then
				d.HoldDuration = 0
				fpp(d, 1, true)
				mined += 1
			end
		end
	end

	return mined
end

function IceTycoon.setAutoMineOres(enabled: boolean)
	IceTycoon.AutoMineOres = enabled
	if enabled then
		task.spawn(function()
			while IceTycoon.AutoMineOres do
				IceTycoon.mineOresNow()
				task.wait(0.5)
			end
		end)
	end
end

-- ── 6. Secrets, Gems & Trophies Auto-Collector ──────────────────────
IceTycoon.AutoCollectSecrets = false

function IceTycoon.collectAllSecretsNow(): { Gems: number, Trophies: number, Secrets: number }
	local hrp = getHrp()
	local camera = Workspace.CurrentCamera
	local fti = firetouchinterest or (getgenv and getgenv().firetouchinterest)
	local fpp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)

	local results = { Gems = 0, Trophies = 0, Secrets = 0 }
	local map = Workspace:FindFirstChild("Map")
	if not (map and hrp and camera) then return results end

	local origCF = hrp.CFrame
	local origCamCF = camera.CFrame
	local origCamType = camera.CameraType

	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = origCamCF

	-- 1. All 3 Trophies on Pedestals (Camera-Frozen Instant Tap)
	local pedFolder = map:FindFirstChild("Pedestals")
	if pedFolder and type(fpp) == "function" then
		for _, ped in ipairs(pedFolder:GetChildren()) do
			local union = ped:FindFirstChild("Union") :: BasePart? or ped:FindFirstChildWhichIsA("BasePart")
			local pr = ped:FindFirstChildWhichIsA("ProximityPrompt", true)
			if union and pr and pr.Enabled then
				hrp.CFrame = union.CFrame * CFrame.new(0, 2, 0)
				task.wait(0.06)
				pr.HoldDuration = 0
				fpp(pr, 1, true)
				task.wait(0.02)
				fpp(pr, 1, true)
				results.Trophies += 1
			end
		end
	end

	-- 2. All 5 Gem Pedestals (Camera-Frozen Instant Tap)
	local troops = map:FindFirstChild("Troops")
	local gemPed = troops and troops:FindFirstChild("GemPedestals")
	if gemPed and type(fti) == "function" then
		for _, ped in ipairs(gemPed:GetChildren()) do
			local hit = ped:FindFirstChild("Hitbox")
			if hit and hit:IsA("BasePart") then
				hrp.CFrame = hit.CFrame * CFrame.new(0, 2, 0)
				task.wait(0.03)
				fti(hrp, hit, 0)
				task.wait(0.01)
				fti(hrp, hit, 1)
				results.Gems += 1
			end
		end
	end

	-- 3. KeyGiver, Secret House Door, and LittleThing
	if troops and type(fti) == "function" then
		local keyGiver = troops:FindFirstChild("KeyGiver")
		if keyGiver and keyGiver:FindFirstChild("Hitbox") and keyGiver.Hitbox:IsA("BasePart") then
			hrp.CFrame = keyGiver.Hitbox.CFrame * CFrame.new(0, 2, 0)
			task.wait(0.03)
			fti(hrp, keyGiver.Hitbox, 0)
			task.wait(0.01)
			fti(hrp, keyGiver.Hitbox, 1)
			results.Secrets += 1
		end

		local house = troops:FindFirstChild("House")
		local door = house and house:FindFirstChild("Door")
		if door and door:FindFirstChild("Hitbox") and door.Hitbox:IsA("BasePart") then
			hrp.CFrame = door.Hitbox.CFrame * CFrame.new(0, 2, 0)
			task.wait(0.03)
			fti(hrp, door.Hitbox, 0)
			task.wait(0.01)
			fti(hrp, door.Hitbox, 1)
			results.Secrets += 1
		end

		local little = troops:FindFirstChild("JustALittleThing")
		if little and little:FindFirstChild("Hitbox") and little.Hitbox:IsA("BasePart") then
			hrp.CFrame = little.Hitbox.CFrame * CFrame.new(0, 2, 0)
			task.wait(0.03)
			fti(hrp, little.Hitbox, 0)
			task.wait(0.01)
			fti(hrp, little.Hitbox, 1)
			results.Secrets += 1
		end
	end

	-- 4. Hotel & IceHotel Hitboxes
	if map and type(fti) == "function" then
		for _, hName in ipairs({"HotelHitbox", "HotelHitbox2"}) do
			local h = map:FindFirstChild(hName)
			if h and h:IsA("BasePart") then
				fti(hrp, h, 0)
				task.wait(0.01)
				fti(hrp, h, 1)
				results.Secrets += 1
			end
		end
	end

	-- 5. Regular Crystals in Map and Lava Hatch
	if map and map:FindFirstChild("BuyCrystal") and map.BuyCrystal:IsA("BasePart") and type(fti) == "function" then
		fti(hrp, map.BuyCrystal, 0)
		task.wait(0.01)
		fti(hrp, map.BuyCrystal, 1)
		results.Gems += 1
	end

	local tycoon = Workspace:FindFirstChild("Tycoon")
	local lava = tycoon and tycoon:FindFirstChild("Essentials") and tycoon.Essentials:FindFirstChild("Lava")
	local hatch = lava and lava:FindFirstChild("Hatch")
	local crystal = hatch and hatch:FindFirstChild("Crystal")
	if crystal and crystal:IsA("BasePart") and type(fti) == "function" then
		fti(hrp, crystal, 0)
		task.wait(0.01)
		fti(hrp, crystal, 1)
		results.Gems += 1
	end

	-- Restore position and camera
	hrp.CFrame = origCF
	camera.CameraType = origCamType
	camera.CFrame = origCamCF

	return results
end

function IceTycoon.setAutoCollectSecrets(enabled: boolean)
	IceTycoon.AutoCollectSecrets = enabled
	if enabled then
		task.spawn(function()
			while IceTycoon.AutoCollectSecrets do
				IceTycoon.collectAllSecretsNow()
				task.wait(1.5)
			end
		end)
	end
end

-- ── 7. Crystals & Gems Auto-Farm ────────────────────────────────────
function IceTycoon.claimCrystalsNow(): number
	return IceTycoon.collectAllSecretsNow().Gems
end

function IceTycoon.setAutoCollectCrystals(enabled: boolean)
	IceTycoon.setAutoCollectSecrets(enabled)
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


-- ── Fast Conveyors & Ore Accelerator ─────────────────────────────
local conveyorConn: RBXScriptConnection? = nil
local oreMagnetConn: RBXScriptConnection? = nil
local cachedConveyors: {[BasePart]: Vector3} = {}

local function scanConveyors()
	local tycoon = Workspace:FindFirstChild("Tycoon") or Workspace
	for _, desc in ipairs(tycoon:GetDescendants()) do
		if desc:IsA("BasePart") and desc.Name:lower():find("conveyor") then
			if not cachedConveyors[desc] then
				local vel = desc.AssemblyLinearVelocity
				if vel.Magnitude > 0.1 then
					cachedConveyors[desc] = vel
				else
					local oldVel = desc.Velocity
					if oldVel.Magnitude > 0.1 then
						cachedConveyors[desc] = oldVel
					end
				end
			end
		end
	end
end

function IceTycoon.setConveyorSpeed(speed: number)
	IceTycoon.ConveyorSpeed = speed
	if IceTycoon.FastConveyors then
		for part, origVel in pairs(cachedConveyors) do
			if part and part.Parent then
				local dir = if origVel.Magnitude > 0.1 then origVel.Unit else Vector3.new(1, 0, 0)
				part.AssemblyLinearVelocity = dir * speed
				part.Velocity = dir * speed
			end
		end
	end
end

function IceTycoon.setFastConveyors(enabled: boolean)
	IceTycoon.FastConveyors = enabled

	if conveyorConn then
		conveyorConn:Disconnect()
		conveyorConn = nil
	end

	if not enabled then
		-- Restore original conveyor speeds
		for part, origVel in pairs(cachedConveyors) do
			if part and part.Parent then
				pcall(function()
					part.AssemblyLinearVelocity = origVel
					part.Velocity = origVel
				end)
			end
		end
		table.clear(cachedConveyors)
		return
	end

	scanConveyors()

	local lastScan = 0
	conveyorConn = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastScan > 2.0 then
			lastScan = now
			scanConveyors()
		end

		local targetSpeed = IceTycoon.ConveyorSpeed
		for part, origVel in pairs(cachedConveyors) do
			if part and part.Parent then
				local dir = if origVel.Magnitude > 0.1 then origVel.Unit else Vector3.new(1, 0, 0)
				part.AssemblyLinearVelocity = dir * targetSpeed
				part.Velocity = dir * targetSpeed
			end
		end

		-- Anti-Flyoff Track Lock: keep all ores centered on conveyor track
		local tycoon = Workspace:FindFirstChild("Tycoon") or Workspace
		local partsFolder = tycoon:FindFirstChild("Parts")
		if partsFolder then
			for _, ore in ipairs(partsFolder:GetChildren()) do
				if ore:IsA("BasePart") and not ore.Anchored then
					pcall(function()
						-- Zero-bounce & high friction grip
						ore.CustomPhysicalProperties = PhysicalProperties.new(1.0, 2.0, 0.0, 100, 0)

						local orePos = ore.Position
						local nearestConv: BasePart? = nil
						local nearestDist = math.huge

						for conv, origVel in pairs(cachedConveyors) do
							if conv and conv.Parent then
								local cp = conv.Position
								local cs = conv.Size
								local halfX = cs.X / 2 + 3.0
								local halfZ = cs.Z / 2 + 3.0
								if math.abs(orePos.X - cp.X) <= halfX and math.abs(orePos.Z - cp.Z) <= halfZ then
									local dist = (orePos - cp).Magnitude
									if dist < nearestDist then
										nearestDist = dist
										nearestConv = conv
									end
								end
							end
						end

						if nearestConv then
							local cp = nearestConv.Position
							local cs = nearestConv.Size
							local origVel = cachedConveyors[nearestConv]
							if origVel and origVel.Magnitude > 0.1 then
								local dir = origVel.Unit
								-- X-axis conveyor: clamp Z
								if math.abs(dir.X) > 0.7 then
									local clampedZ = math.clamp(orePos.Z, cp.Z - cs.Z * 0.35, cp.Z + cs.Z * 0.35)
									local targetY = cp.Y + cs.Y / 2 + ore.Size.Y / 2
									if math.abs(orePos.Z - clampedZ) > 0.2 then
										ore.CFrame = CFrame.new(orePos.X, math.max(orePos.Y, targetY), clampedZ)
									end
									ore.AssemblyLinearVelocity = Vector3.new(dir.X * targetSpeed, math.min(ore.AssemblyLinearVelocity.Y, 0), 0)
								-- Z-axis conveyor: clamp X
								elseif math.abs(dir.Z) > 0.7 then
									local clampedX = math.clamp(orePos.X, cp.X - cs.X * 0.35, cp.X + cs.X * 0.35)
									local targetY = cp.Y + cs.Y / 2 + ore.Size.Y / 2
									if math.abs(orePos.X - clampedX) > 0.2 then
										ore.CFrame = CFrame.new(clampedX, math.max(orePos.Y, targetY), orePos.Z)
									end
									ore.AssemblyLinearVelocity = Vector3.new(0, math.min(ore.AssemblyLinearVelocity.Y, 0), dir.Z * targetSpeed)
								end
							end
						else
							-- Fail-safe catch if ore fell below conveyor track
							local colPart = getCollectorPart()
							if colPart and colPart:IsA("BasePart") and orePos.Y < 2.5 then
								ore.CFrame = colPart.CFrame * CFrame.new(0, 0.5, 0)
							end
						end
					end)
				end
			end
		end
	end)
end

local generatorConn: RBXScriptConnection? = nil
local partsAddedConn: RBXScriptConnection? = nil

function IceTycoon.setGeneratorSpeed(speed: number)
	IceTycoon.GeneratorSpeed = speed
end

function IceTycoon.setFastGenerators(enabled: boolean)
	IceTycoon.FastGenerators = enabled

	if generatorConn then generatorConn:Disconnect() generatorConn = nil end
	if partsAddedConn then partsAddedConn:Disconnect() partsAddedConn = nil end

	if not enabled then return end

	local tycoon = Workspace:FindFirstChild("Tycoon") or Workspace
	local partsFolder = tycoon:FindFirstChild("Parts")

	local function boostOre(part: Instance)
		pcall(function()
			if part:IsA("BasePart") and not part.Anchored then
				local colPart = getCollectorPart()
				if colPart and colPart:IsA("BasePart") then
					local diff = colPart.Position - part.Position
					if diff.Magnitude > 1.0 then
						part.AssemblyLinearVelocity = diff.Unit * IceTycoon.GeneratorSpeed
					end
				end
			end
		end)
	end

	if partsFolder then
		partsAddedConn = partsFolder.ChildAdded:Connect(boostOre)
		for _, child in ipairs(partsFolder:GetChildren()) do
			boostOre(child)
		end
	end

	generatorConn = RunService.Heartbeat:Connect(function()
		pcall(function()
			local colPart = getCollectorPart()
			if not colPart or not colPart:IsA("BasePart") then return end
			local colPos = colPart.Position

			local targetFolder = partsFolder or tycoon
			for _, desc in ipairs(targetFolder:GetChildren()) do
				if desc:IsA("BasePart") and not desc.Anchored and desc ~= colPart then
					local diff = colPos - desc.Position
					if diff.Magnitude > 1.5 and diff.Magnitude < 250 then
						desc.AssemblyLinearVelocity = diff.Unit * IceTycoon.GeneratorSpeed
					end
				end
			end
		end)
	end)
end

function IceTycoon.setOreMagnet(enabled: boolean)
	IceTycoon.OreMagnet = enabled

	if oreMagnetConn then
		oreMagnetConn:Disconnect()
		oreMagnetConn = nil
	end

	if not enabled then return end

	oreMagnetConn = RunService.Heartbeat:Connect(function()
		pcall(function()
			local colPart = getCollectorPart()
			if not colPart or not colPart:IsA("BasePart") then return end
			local colPos = colPart.Position

			local tycoon = Workspace:FindFirstChild("Tycoon") or Workspace
			for _, desc in ipairs(tycoon:GetDescendants()) do
				if desc:IsA("BasePart") and (desc.Name:lower():find("ore") or desc.Name:lower():find("drop") or desc.Name == "Ice" or desc.Name == "Crystal") then
					if not desc.Anchored and desc ~= colPart then
						local diff = colPos - desc.Position
						if diff.Magnitude < 160 and diff.Magnitude > 1.5 then
							desc.AssemblyLinearVelocity = diff.Unit * 60
						end
					end
				end
			end
		end)
	end)
end


-- ── 8. Duplicated Sell Nodes & Generator Proximity Relays ────────
local proxySellConn: RBXScriptConnection? = nil

function IceTycoon.setDuplicatedSellNodes(enabled: boolean)
	IceTycoon.DuplicatedSellNodes = enabled

	if proxySellConn then
		proxySellConn:Disconnect()
		proxySellConn = nil
	end

	if not enabled then return end

	local tycoon = Workspace:FindFirstChild("Tycoon") or Workspace
	local partsFolder = tycoon:FindFirstChild("Parts")
	local fti = firetouchinterest or (getgenv and getgenv().firetouchinterest)

	proxySellConn = RunService.Heartbeat:Connect(function()
		pcall(function()
			local colPart = getCollectorPart()
			if not colPart or not colPart:IsA("BasePart") then return end

			local targetFolder = partsFolder or tycoon
			for _, ore in ipairs(targetFolder:GetChildren()) do
				if ore:IsA("BasePart") and not ore.Anchored and ore ~= colPart then
					if type(fti) == "function" then
						fti(ore, colPart, 0)
						task.wait(0.01)
						fti(ore, colPart, 1)
					else
						ore.CFrame = colPart.CFrame * CFrame.new(0, 0.5, 0)
					end
				end
			end
		end)
	end)
end

-- ── 9. Sphere Army Spawner & Auto-Battler ─────────────────────────
local armyConn: thread? = nil

function IceTycoon.spawnArmyUnits(noobCount: number?, knightCount: number?): number
	local fpp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
	local troops = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Troops")
	if not troops then return 0 end

	local spawned = 0
	local nTarget = noobCount or 5
	local kTarget = knightCount or 5

	-- Spawn Knights (knbutton / kn2button)
	for _, btnName in ipairs({"knbutton", "kn2button"}) do
		local btn = troops:FindFirstChild(btnName)
		local prompt = btn and btn:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt and type(fpp) == "function" then
			for _ = 1, kTarget do
				fpp(prompt, 1, true)
				spawned += 1
				task.wait(0.03)
			end
		end
	end

	-- Spawn Noobs (nobutton / no2button)
	for _, btnName in ipairs({"nobutton", "no2button"}) do
		local btn = troops:FindFirstChild(btnName)
		local prompt = btn and btn:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt and type(fpp) == "function" then
			for _ = 1, nTarget do
				fpp(prompt, 1, true)
				spawned += 1
				task.wait(0.03)
			end
		end
	end

	return spawned
end

function IceTycoon.commandAttack(): boolean
	local fpp = fireproximityprompt or (getgenv and getgenv().fireproximityprompt)
	local troops = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Troops")
	if not troops or type(fpp) ~= "function" then return false end

	for _, atkName in ipairs({"AttackButton", "Attack2Button"}) do
		local btn = troops:FindFirstChild(atkName)
		local prompt = btn and btn:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			fpp(prompt, 1, true)
			task.wait(0.05)
		end
	end
	return true
end

function IceTycoon.setAutoArmyFight(enabled: boolean)
	IceTycoon.AutoArmyFight = enabled

	if armyConn then
		task.cancel(armyConn)
		armyConn = nil
	end

	if enabled then
		armyConn = task.spawn(function()
			while IceTycoon.AutoArmyFight do
				pcall(function()
					-- 1. Spawn army units
					IceTycoon.spawnArmyUnits(6, 6)
					task.wait(1.5)
					-- 2. Command army to attack & battle
					IceTycoon.commandAttack()
				end)
				task.wait(4.0)
			end
		end)
	end
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
	IceTycoon.setFastConveyors(false)
	IceTycoon.setFastGenerators(false)
	IceTycoon.setOreMagnet(false)
	IceTycoon.setDuplicatedSellNodes(false)
	IceTycoon.setAutoArmyFight(false)

	if collectConn then collectConn:Disconnect() collectConn = nil end
	if buyConn then buyConn:Disconnect() buyConn = nil end
	if waterConn then waterConn:Disconnect() waterConn = nil end
	if crystalConn then crystalConn:Disconnect() crystalConn = nil end
	if protectConn then protectConn:Disconnect() protectConn = nil end
	if mineConn then mineConn:Disconnect() mineConn = nil end
end

_G.__ModularTycoon_Cleanup = IceTycoon.cleanup

return IceTycoon
