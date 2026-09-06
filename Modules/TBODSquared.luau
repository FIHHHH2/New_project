--!strict
-- Modules/TBODSquared.luau
-- Automation & Modifiers for [UPD 1.5] TBOD^2 (Tycoon But One Dropper: SQUARED)
-- PlaceId: 139063887391814

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer

local TBODSquared = {}
TBODSquared.__index = TBODSquared

-- State
local isRunning = false
local autoPurchaseEnabled = false
local smartPurchaseEnabled = true
local purchaseDelay = 0.3
local autoRebirthEnabled = false
local autoRebirthOnCapped = true
local rebirthEssenceTarget = 50

-- AutoFarm State
local autoFarmWheatEnabled = false
local autoCollectWheat = true
local autoPlantWheat = true
local autoHarvestWheat = true
local autoProcessWheat = true
local autoReturnHome = true
local farmCycleDelay = 0.35

-- Runtime references & connections
local purchaseThread: thread? = nil
local rebirthThread: thread? = nil
local farmThread: thread? = nil
local cachedTycoon: Model? = nil
local cachedPlotName: string? = nil
local lastObservedEssence = 0
local essencePlateauTicks = 0

-- Metrics
TBODSquared.Metrics = {
	buttonsPurchased = 0,
	rebirthsTriggered = 0,
	lastRebirthEssence = 0,
	currentCash = "$0",
	currentEssence = "+0",
	wheatCollected = 0,
	wheatPlanted = 0,
	wheatHarvested = 0,
	wheatProcessed = 0,
}

-- Helper: parse formatted currency string ("$3B", "150M", "+253", "$130") into raw number
local function parseFormattedNumber(str: string?): number
	if not str then return 0 end
	local clean = string.gsub(str, "[,%$%+%s]", "")
	local numPart, suffix = string.match(clean, "^([%d%.]+)%s*([%a]*)$")
	if not numPart then return 0 end
	local num = tonumber(numPart) or 0
	suffix = string.upper(suffix or "")
	local multipliers: {[string]: number} = {
		K = 1e3,
		M = 1e6,
		B = 1e9,
		T = 1e12,
		QA = 1e15,
		QI = 1e18,
		SX = 1e21,
		SP = 1e24,
		OC = 1e27,
		NO = 1e30,
		DC = 1e33
	}
	if multipliers[suffix] then
		return num * multipliers[suffix]
	end
	return num
end

-- Clear cached plot and tycoon references
function TBODSquared.clearCache()
	cachedTycoon = nil
	cachedPlotName = nil
end

-- Resolve the player's plot and matching Tycoon model in workspace
function TBODSquared.getMyTycoon(): Model?
	if cachedTycoon and cachedTycoon.Parent == Workspace:FindFirstChild("Tycoons") then
		return cachedTycoon
	end

	local plots = Workspace:FindFirstChild("Plots")
	local tycoons = Workspace:FindFirstChild("Tycoons")
	if not (plots and tycoons) then return nil end

	local myPlot: Instance? = nil
	local myUserId = localPlayer.UserId
	local myUserIdStr = tostring(myUserId)

	for _, p in ipairs(plots:GetChildren()) do
		local ownerAttr = p:GetAttribute("Owner")
		if ownerAttr == myUserId or ownerAttr == myUserIdStr then
			myPlot = p
			cachedPlotName = p.Name
			break
		end
	end

	if not myPlot then return nil end

	local plotOriginPart = myPlot:FindFirstChildWhichIsA("BasePart", true)
	if not plotOriginPart then return nil end

	local bestDist = math.huge
	local bestTyc: Model? = nil

	for _, tyc in ipairs(tycoons:GetChildren()) do
		if tyc:IsA("Model") then
			local base = tyc:FindFirstChild("Base") or tyc:FindFirstChild("SpawnPart")
			if base and base:IsA("BasePart") then
				local dist = (base.Position - plotOriginPart.Position).Magnitude
				if dist < 60 and dist < bestDist then
					bestDist = dist
					bestTyc = tyc
				end
			end
		end
	end

	if bestTyc then
		cachedTycoon = bestTyc
	end

	return bestTyc
end

-- Read player's current cash balance
function TBODSquared.getPlayerCash(): number
	local pg = localPlayer:FindFirstChild("PlayerGui")
	if pg then
		local cashText = pg:FindFirstChild("System") 
			and pg.System:FindFirstChild("Main") 
			and pg.System.Main:FindFirstChild("Cash") 
			and pg.System.Main.Cash:FindFirstChild("CashText") :: TextLabel?
		if cashText and cashText.Text then
			TBODSquared.Metrics.currentCash = cashText.Text
			return parseFormattedNumber(cashText.Text)
		end
	end

	local leaderstats = localPlayer:FindFirstChild("leaderstats")
	if leaderstats then
		local cashVal = leaderstats:FindFirstChild("Cash") or leaderstats:FindFirstChild("Money")
		if cashVal and cashVal:IsA("ValueBase") then
			return tonumber((cashVal :: any).Value) or 0
		end
	end
	return 0
end

-- Read pending Rebirth Essence
function TBODSquared.getPendingEssence(): number
	local pg = localPlayer:FindFirstChild("PlayerGui")
	if pg then
		-- Check System or Main HUD for Essence text
		local systemGui = pg:FindFirstChild("System") or pg:FindFirstChild("Main")
		if systemGui then
			for _, desc in ipairs(systemGui:GetDescendants()) do
				if desc:IsA("TextLabel") and desc.Visible then
					local nameLower = string.lower(desc.Name)
					if nameLower == "essencetext" or nameLower == "essence" then
						local val = parseFormattedNumber(desc.Text)
						if val > 0 then
							TBODSquared.Metrics.currentEssence = desc.Text
							return val
						end
					end
				end
			end
		end

		local essLabel = pg:FindFirstChild("Main")
			and pg.Main:FindFirstChild("Rebirth")
			and pg.Main.Rebirth:FindFirstChild("Main")
			and pg.Main.Rebirth.Main:FindFirstChild("Inner")
			and pg.Main.Rebirth.Main.Inner:FindFirstChild("Essence") :: TextLabel?
		if essLabel and essLabel.Text then
			TBODSquared.Metrics.currentEssence = essLabel.Text
			return parseFormattedNumber(essLabel.Text)
		end
	end

	local leaderstats = localPlayer:FindFirstChild("leaderstats")
	if leaderstats then
		local essVal = leaderstats:FindFirstChild("Essence") or leaderstats:FindFirstChild("RebirthEssence")
		if essVal and essVal:IsA("ValueBase") then
			return tonumber((essVal :: any).Value) or 0
		end
	end

	return 0
end

-- Check if essence is currently capped
function TBODSquared.isEssenceCapped(): (boolean, string)
	local currentEssence = TBODSquared.getPendingEssence()
	if currentEssence <= 0 then
		return false, "No Essence Available"
	end

	-- 1. Attribute / Value check on player and leaderstats
	local attrCap = localPlayer:GetAttribute("EssenceCap") 
		or localPlayer:GetAttribute("MaxEssence")
		or localPlayer:GetAttribute("RebirthCap")
	if attrCap and tonumber(attrCap) then
		local capNum = tonumber(attrCap)
		if capNum and capNum > 0 and currentEssence >= capNum then
			return true, string.format("Reached Attribute Cap (%d)", capNum)
		end
	end

	-- 2. Check Rebirth GUI if it happens to be open
	local pg = localPlayer:FindFirstChild("PlayerGui")
	if pg then
		local rebirthGui = pg:FindFirstChild("Main") and pg.Main:FindFirstChild("Rebirth")
		if rebirthGui and rebirthGui.Visible then
			for _, desc in ipairs(rebirthGui:GetDescendants()) do
				if desc:IsA("TextLabel") and desc.Visible then
					local text = desc.Text or ""
					local upper = string.upper(text)

					-- Match explicit cap keywords ONLY: "CAPPED", "ESSENCE CAPPED", "CAP REACHED"
					if upper == "CAPPED" or string.find(upper, "ESSENCE CAPPED") or string.find(upper, "CAP REACHED") or string.find(upper, "MAX ESSENCE REACHED") then
						return true, "UI indicates " .. text
					end

					-- Match fraction: e.g. "50 / 50" or "+50 / 50"
					local curStr, maxStr = string.match(text, "([%d%.]+%s*[%a]*)%s*/%s*([%d%.]+%s*[%a]*)")
					if curStr and maxStr then
						local curNum = parseFormattedNumber(curStr)
						local maxNum = parseFormattedNumber(maxStr)
						if maxNum > 0 and curNum >= maxNum then
							return true, string.format("Capped at %s/%s", curStr, maxStr)
						end
					end
				end
			end
		end
	end

	return false, "Not capped"
end

-- Purchase a tycoon button via touch stimulation
local function triggerButtonPurchase(buttonPart: BasePart): boolean
	local char = localPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return false end

	local fti = (firetouchinterest :: any) or (getgenv and getgenv().firetouchinterest)
	if type(fti) == "function" then
		pcall(function()
			fti(hrp, buttonPart, 0)
			task.wait(0.02)
			fti(hrp, buttonPart, 1)
		end)
		return true
	end

	-- Fallback CFrame pulse if firetouchinterest is unavailable
	local origCF = hrp.CFrame
	hrp.CFrame = CFrame.new(buttonPart.Position + Vector3.new(0, 2, 0))
	task.wait(0.04)
	hrp.CFrame = origCF
	return true
end

-- Auto Purchase Loop
local function startPurchaseLoop()
	if purchaseThread then return end
	purchaseThread = task.spawn(function()
		while autoPurchaseEnabled do
			local tyc = TBODSquared.getMyTycoon()
			local char = localPlayer.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?

			if tyc and hrp then
				local buttonsFolder = tyc:FindFirstChild("Buttons")
				if buttonsFolder then
					local currentCash = TBODSquared.getPlayerCash()
					local candidateButtons = {}

					for _, b in ipairs(buttonsFolder:GetChildren()) do
						if b:IsA("BasePart") and b.Transparency < 0.5 then
							local priceDisplay = b:FindFirstChild("PriceDisplay")
							local priceLabel = priceDisplay and priceDisplay:FindFirstChildWhichIsA("TextLabel", true)
							local priceText = priceLabel and priceLabel.Text or ""
							local cost = parseFormattedNumber(priceText)

							if cost <= currentCash then
								table.insert(candidateButtons, {
									part = b,
									cost = cost,
									name = b.Name
								})
							end
						end
					end

					if smartPurchaseEnabled then
						table.sort(candidateButtons, function(a, b)
							return a.cost < b.cost
						end)
					end

					for _, item in ipairs(candidateButtons) do
						if not autoPurchaseEnabled then break end
						if item.part and item.part.Parent and item.part.Transparency < 0.5 then
							local ok = triggerButtonPurchase(item.part)
							if ok then
								TBODSquared.Metrics.buttonsPurchased += 1
							end
							task.wait(0.06)
						end
					end
				end
			end
			task.wait(math.max(0.1, purchaseDelay))
		end
		purchaseThread = nil
	end)
end

-- ── INTERACTION HELPERS ───────────────────────────────────────────────

-- Trigger ProximityPrompt with distance and hold duration bypass
local function triggerPrompt(prompt: ProximityPrompt): boolean
	if not prompt or not prompt.Parent then return false end

	pcall(function()
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 9999
		prompt.HoldDuration = 0
	end)

	local fpp = (fireproximityprompt :: any) or (getgenv and getgenv().fireproximityprompt)
	if type(fpp) == "function" then
		local ok = pcall(fpp, prompt)
		if ok then return true end
	end

	pcall(function()
		prompt:InputHoldBegin()
		task.wait(0.02)
		prompt:InputHoldEnd()
	end)
	return true
end

-- Trigger ClickDetector
local function triggerClick(cd: ClickDetector): boolean
	if not cd or not cd.Parent then return false end
	local fcd = (fireclickdetector :: any) or (getgenv and getgenv().fireclickdetector)
	if type(fcd) == "function" then
		local ok = pcall(fcd, cd)
		if ok then return true end
	end
	return false
end

-- Trigger Touch
local function triggerTouch(part: BasePart): boolean
	local char = localPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp or not part or not part.Parent then return false end

	local fti = (firetouchinterest :: any) or (getgenv and getgenv().firetouchinterest)
	if type(fti) == "function" then
		pcall(function()
			fti(hrp, part, 0)
			task.wait(0.02)
			fti(hrp, part, 1)
		end)
		return true
	end

	return false
end

-- ── OBELISK REBIRTH ENGINE ───────────────────────────────────────────

-- Deep lookup for the Obelisk Rebirth interaction part
local function getObeliskRebirthPart(): BasePart?
	local obelisk = Workspace:FindFirstChild("Obelisk")
	if not obelisk then
		for _, obj in ipairs(Workspace:GetChildren()) do
			if string.find(string.lower(obj.Name), "obelisk") then
				obelisk = obj
				break
			end
		end
	end
	if not obelisk then return nil end

	-- 1. Check for RebirthButton part or model
	local rb = obelisk:FindFirstChild("RebirthButton") 
		or obelisk:FindFirstChild("Rebirth")
		or obelisk:FindFirstChild("Button")
	if rb then
		if rb:IsA("BasePart") then return rb end
		local click = rb:FindFirstChild("Click") 
			or rb:FindFirstChild("Hitbox") 
			or rb:FindFirstChild("Button") 
			or rb:FindFirstChildWhichIsA("BasePart", true)
		if click and click:IsA("BasePart") then return click end
	end

	-- 2. Check for any ProximityPrompt or ClickDetector in obelisk
	local pp = obelisk:FindFirstChildWhichIsA("ProximityPrompt", true)
	if pp and pp.Parent and pp.Parent:IsA("BasePart") then
		return pp.Parent
	end

	local cd = obelisk:FindFirstChildWhichIsA("ClickDetector", true)
	if cd and cd.Parent and cd.Parent:IsA("BasePart") then
		return cd.Parent
	end

	return obelisk:FindFirstChildWhichIsA("BasePart", true)
end

-- ── INTERACTION TRIGGER UTILITIES (PROMPT, CLICK, TOUCH COLLISION) ───

local function triggerPrompt(prompt: ProximityPrompt): boolean
	if not (prompt and prompt.Enabled and prompt.Parent) then return false end
	local fpp = (fireproximityprompt :: any) or (getgenv and getgenv().fireproximityprompt)
	if type(fpp) == "function" then
		pcall(function() fpp(prompt) end)
		return true
	end
	if prompt.InputHoldBegin then
		pcall(function()
			prompt:InputHoldBegin()
			task.wait(prompt.HoldDuration + 0.05)
			prompt:InputHoldEnd()
		end)
		return true
	end
	return false
end

local function triggerClick(cd: ClickDetector): boolean
	if not (cd and cd.Parent) then return false end
	local fcd = (fireclickdetector :: any) or (getgenv and getgenv().fireclickdetector)
	if type(fcd) == "function" then
		pcall(function() fcd(cd) end)
		return true
	end
	return false
end

local function triggerTouch(targetPart: BasePart, hrp: BasePart?): boolean
	if not (targetPart and targetPart:IsA("BasePart") and targetPart.Parent) then return false end
	local char = localPlayer.Character
	local root = hrp or (char and char:FindFirstChild("HumanoidRootPart") :: BasePart?)
	if not root then return false end

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	local fti = (firetouchinterest :: any) or (getgenv and getgenv().firetouchinterest)
	if type(fti) == "function" then
		pcall(function()
			fti(root, targetPart, 0)
			fti(targetPart, root, 0)
		end)
		task.wait(0.01)
		pcall(function()
			fti(root, targetPart, 1)
			fti(targetPart, root, 1)
		end)

		if char then
			for _, limbName in ipairs({"RightFoot", "LeftFoot", "Right Leg", "Left Leg", "LowerTorso", "Torso", "RightUpperLeg", "LeftUpperLeg"}) do
				local limb = char:FindFirstChild(limbName)
				if limb and limb:IsA("BasePart") then
					pcall(function()
						fti(limb, targetPart, 0)
						fti(targetPart, limb, 0)
					end)
					task.wait(0.005)
					pcall(function()
						fti(limb, targetPart, 1)
						fti(targetPart, limb, 1)
					end)
				end
			end
		end
		return true
	end
	return false
end

local function physicallyTouch(targetPart: BasePart, hrp: BasePart)
	if not (hrp and targetPart and targetPart.Parent) then return end
	hrp.CFrame = targetPart.CFrame
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero

	triggerTouch(targetPart, hrp)
	task.wait(0.05)
end

-- Prompt the Obelisk to open the Rebirth Dialog
local function promptRebirth(): boolean
	local part = getObeliskRebirthPart()
	if not part then return false end

	local char = localPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return false end

	local origCF = hrp.CFrame
	local dist = (hrp.Position - part.Position).Magnitude
	local pulsed = false

	-- If farther than 20 studs, pulse to button so server validates proximity
	if dist > 20 then
		pulsed = true
		hrp.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 2))
		task.wait(0.05)
	end

	-- 1. ProximityPrompt with bypass
	local pp = part:FindFirstChildWhichIsA("ProximityPrompt", true)
		or (part.Parent and part.Parent:FindFirstChildWhichIsA("ProximityPrompt", true))
	if pp then
		triggerPrompt(pp)
	end

	-- 2. ClickDetector
	local cd = part:FindFirstChildWhichIsA("ClickDetector", true)
		or (part.Parent and part.Parent:FindFirstChildWhichIsA("ClickDetector", true))
	if cd then
		triggerClick(cd)
	end

	-- 3. Touch
	triggerTouch(part)

	if pulsed then
		task.wait(0.12)
		if hrp and hrp.Parent then
			hrp.CFrame = origCF
		end
	end

	return true
end

-- Find the Confirm button inside Rebirth GUI
local function findRebirthConfirmButton(rebirthGui: Instance): GuiButton?
	local exact = rebirthGui:FindFirstChild("Main")
		and rebirthGui.Main:FindFirstChild("Inner")
		and rebirthGui.Main.Inner:FindFirstChild("Rebirth")
	if exact and exact:IsA("GuiButton") then return exact end

	for _, desc in ipairs(rebirthGui:GetDescendants()) do
		if desc:IsA("GuiButton") and desc.Visible then
			local nameLower = string.lower(desc.Name)
			local text = (desc:IsA("TextButton") and string.lower(desc.Text)) or ""
			if nameLower == "rebirth" or nameLower == "confirm" or string.find(text, "rebirth") or string.find(text, "confirm") or string.find(text, "yes") then
				return desc
			end
		end
	end
	return nil
end

-- Trigger Full Rebirth Sequence (Prompt Obelisk + Confirm Rebirth)
local function executeRebirth(): boolean
	-- Step 1: Prompt the Obelisk to open the dialog
	promptRebirth()
	task.wait(0.3)

	local pg = localPlayer:FindFirstChild("PlayerGui")
	if not pg then return false end

	local mainGui = pg:FindFirstChild("Main")
	local rebirthGui = mainGui and mainGui:FindFirstChild("Rebirth")
	if not (rebirthGui and rebirthGui.Visible) then
		-- Retry prompt once more if not visible yet
		promptRebirth()
		task.wait(0.3)
		mainGui = pg:FindFirstChild("Main")
		rebirthGui = mainGui and mainGui:FindFirstChild("Rebirth")
	end

	if not (rebirthGui and rebirthGui.Visible) then
		return false
	end

	-- Step 2: Confirm rebirth via the GUI button
	local rebBtn = findRebirthConfirmButton(rebirthGui)
	if rebBtn then
		local clicked = false
		local fs = (firesignal :: any) or (getgenv and getgenv().firesignal)
		if type(fs) == "function" then
			pcall(function()
				fs(rebBtn.MouseButton1Click)
				fs(rebBtn.Activated)
				clicked = true
			end)
		end

		if not clicked then
			pcall(function()
				local getconnections = (getconnections :: any) or (getgenv and getgenv().getconnections)
				if type(getconnections) == "function" then
					for _, conn in ipairs(getconnections(rebBtn.MouseButton1Click)) do
						conn:Fire()
					end
					for _, conn in ipairs(getconnections(rebBtn.Activated)) do
						conn:Fire()
					end
				end
			end)
		end

		TBODSquared.Metrics.rebirthsTriggered += 1
		cachedTycoon = nil -- Invalidate tycoon cache after rebirth reset
		return true
	end
	return false
end

-- Auto Rebirth Loop (Supports threshold and automatic cap detection)
local function startRebirthLoop()
	if rebirthThread then return end
	rebirthThread = task.spawn(function()
		while autoRebirthEnabled or autoRebirthOnCapped do
			local shouldRebirth = false
			local rebirthReason = ""

			if autoRebirthOnCapped then
				local isCapped, capReason = TBODSquared.isEssenceCapped()
				if isCapped then
					shouldRebirth = true
					rebirthReason = capReason
				end
			end

			if not shouldRebirth and autoRebirthEnabled then
				local pending = TBODSquared.getPendingEssence()
				if pending >= rebirthEssenceTarget and pending > 0 then
					shouldRebirth = true
					rebirthReason = string.format("Reached Target Essence (%d >= %d)", pending, rebirthEssenceTarget)
				end
			end

			if shouldRebirth then
				local pending = TBODSquared.getPendingEssence()
				TBODSquared.Metrics.lastRebirthEssence = pending
				executeRebirth()
				task.wait(6.0) -- Generous debounce to allow plot reload, despawn & rebirth animation
			end
			task.wait(1.0)
		end
		rebirthThread = nil
	end)
end

-- ── WHEAT AUTOFARM & HARVEST/PROCESSING ENGINE ───────────────────────

-- Helper string predicates
local function isWheatRelated(name: string): boolean
	local lower = string.lower(name)
	return string.find(lower, "wheat") ~= nil 
		or string.find(lower, "seed") ~= nil
		or string.find(lower, "grain") ~= nil
		or string.find(lower, "crop") ~= nil
end

local function isFarmRelated(name: string): boolean
	local lower = string.lower(name)
	return string.find(lower, "farm") ~= nil 
		or string.find(lower, "plot") ~= nil
		or string.find(lower, "soil") ~= nil
		or string.find(lower, "field") ~= nil
		or string.find(lower, "garden") ~= nil
end

local function isProcessorRelated(name: string): boolean
	local lower = string.lower(name)
	return string.find(lower, "separator") ~= nil 
		or string.find(lower, "process") ~= nil
		or string.find(lower, "mill") ~= nil
		or string.find(lower, "refin") ~= nil
		or string.find(lower, "silo") ~= nil
		or string.find(lower, "bakery") ~= nil
		or string.find(lower, "deposit") ~= nil
end

-- Equip item tool by partial name
local function equipToolNamed(pattern: string): boolean
	local char = localPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return false end

	-- Check if already equipped
	for _, item in ipairs(char:GetChildren()) do
		if item:IsA("Tool") and string.find(string.lower(item.Name), string.lower(pattern)) then
			return true
		end
	end

	-- Check backpack
	local bp = localPlayer:FindFirstChild("Backpack")
	if bp then
		for _, item in ipairs(bp:GetChildren()) do
			if item:IsA("Tool") and string.find(string.lower(item.Name), string.lower(pattern)) then
				hum:EquipTool(item)
				return true
			end
		end
	end
	return false
end

-- Check if player holds or carries a tool matching pattern
local function hasToolNamed(pattern: string): boolean
	local char = localPlayer.Character
	if char then
		for _, item in ipairs(char:GetChildren()) do
			if item:IsA("Tool") and string.find(string.lower(item.Name), string.lower(pattern)) then
				return true
			end
		end
	end
	local bp = localPlayer:FindFirstChild("Backpack")
	if bp then
		for _, item in ipairs(bp:GetChildren()) do
			if item:IsA("Tool") and string.find(string.lower(item.Name), string.lower(pattern)) then
				return true
			end
		end
	end
	return false
end

-- Bring player within server proximity threshold of a target part
local function approachTarget(targetPart: BasePart, hrp: BasePart)
	if not (hrp and targetPart and targetPart.Parent) then return end
	local targetPos = targetPart.Position
	if (hrp.Position - targetPos).Magnitude > 6 then
		hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 2.5, 0))
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		task.wait(0.04)
	end
end

-- Resolve all active search containers for farms, seeds, and processors
local function getTycoonContainers(): {Instance}
	local containers: {Instance} = {}
	local tyc = TBODSquared.getMyTycoon()
	if tyc then
		table.insert(containers, tyc)
	end
	
	local plots = Workspace:FindFirstChild("Plots")
	if plots and cachedPlotName then
		local myPlot = plots:FindFirstChild(cachedPlotName)
		if myPlot then
			table.insert(containers, myPlot)
		end
	end

	local wsFarms = Workspace:FindFirstChild("Farms") or Workspace:FindFirstChild("Farm")
	if wsFarms then
		table.insert(containers, wsFarms)
	end

	return containers
end

-- Count seed tools currently in backpack and character
local function countSeedsInInventory(): number
	local count = 0
	local char = localPlayer.Character
	if char then
		for _, item in ipairs(char:GetChildren()) do
			if item:IsA("Tool") and string.find(string.lower(item.Name), "seed") then
				count += 1
			end
		end
	end
	local bp = localPlayer:FindFirstChild("Backpack")
	if bp then
		for _, item in ipairs(bp:GetChildren()) do
			if item:IsA("Tool") and string.find(string.lower(item.Name), "seed") then
				count += 1
			end
		end
	end
	return count
end

-- Identify if an instance is a seed dispenser, spawner, crate, box, or seed drop
local function isSeedDispenserOrItem(obj: Instance): boolean
	local nameLower = string.lower(obj.Name)
	-- Skip if it's a farm plot (unless it is a seed giver/box)
	if isFarmRelated(nameLower) and not (string.find(nameLower, "seed") or string.find(nameLower, "dispenser") or string.find(nameLower, "box") or string.find(nameLower, "crate") or string.find(nameLower, "giver")) then
		return false
	end
	if isProcessorRelated(nameLower) then
		return false
	end

	if string.find(nameLower, "seed") ~= nil then
		return true
	end
	if string.find(nameLower, "wheatbox") 
		or string.find(nameLower, "wheatspawner") 
		or string.find(nameLower, "wheatcrate") 
		or string.find(nameLower, "wheatgiver") 
		or string.find(nameLower, "wheatdispenser") then
		return true
	end
	if obj:IsA("ProximityPrompt") then
		local a = string.lower(obj.ActionText or "")
		local o = string.lower(obj.ObjectText or "")
		if string.find(a, "seed") or string.find(o, "seed") then
			return true
		end
	end
	return false
end

-- 1. Harvest Completed / Mature Wheat from Farms (with physical touch & proximity validation)
local function harvestCompletedWheat(containers: {Instance}, hrp: BasePart): number
	if not autoHarvestWheat then return 0 end
	local harvested = 0

	for _, container in ipairs(containers) do
		for _, desc in ipairs(container:GetDescendants()) do
			-- Check for harvest/collect prompts
			if desc:IsA("ProximityPrompt") then
				local action = string.lower(desc.ActionText or "")
				local objText = string.lower(desc.ObjectText or "")
				local isHarvestPrompt = string.find(action, "harvest") 
					or string.find(action, "pick") 
					or string.find(action, "gather") 
					or (string.find(action, "collect") and (string.find(objText, "wheat") or string.find(objText, "crop") or string.find(objText, "farm")))

				if isHarvestPrompt and desc.Parent and desc.Parent:IsA("BasePart") then
					physicallyTouch(desc.Parent, hrp)
					if triggerPrompt(desc) then
						harvested += 1
						task.wait(0.04)
					end
				end
			-- Check for mature crop parts or models
			elseif desc:IsA("Model") or desc:IsA("BasePart") then
				local nameLower = string.lower(desc.Name)
				if isWheatRelated(nameLower) then
					local isMature = desc:GetAttribute("Ready") == true 
						or desc:GetAttribute("Mature") == true 
						or desc:GetAttribute("Grown") == true
						or (desc:IsA("BasePart") and desc.Transparency < 0.5 and desc.Parent and isFarmRelated(desc.Parent.Name))

					if isMature then
						local targetPart = if desc:IsA("BasePart") then desc else desc:FindFirstChildWhichIsA("BasePart", true)
						if targetPart then
							physicallyTouch(targetPart, hrp)
							local prompt = desc:FindFirstChildWhichIsA("ProximityPrompt", true)
							if prompt and triggerPrompt(prompt) then
								harvested += 1
							else
								local cd = desc:FindFirstChildWhichIsA("ClickDetector", true)
								if cd and triggerClick(cd) then
									harvested += 1
								else
									harvested += 1
								end
							end
							task.wait(0.04)
						end
					end
				end
			end
		end
	end

	return harvested
end

-- 2. Automatically Process Harvested Wheat (Deliver to Separator / Mill with physical touch)
local function processHarvestedWheat(containers: {Instance}, hrp: BasePart): number
	if not autoProcessWheat then return 0 end
	local processed = 0

	-- Ensure player carries harvested wheat or grain
	if not (hasToolNamed("wheat") or hasToolNamed("grain") or hasToolNamed("harvest")) then
		return 0
	end

	for _, container in ipairs(containers) do
		for _, desc in ipairs(container:GetDescendants()) do
			local nameLower = string.lower(desc.Name)
			if isProcessorRelated(nameLower) then
				local hopperPart = desc:FindFirstChild("Input") 
					or desc:FindFirstChild("Hopper") 
					or desc:FindFirstChild("Deposit") 
					or desc:FindFirstChild("Drop") 
					or desc:FindFirstChild("Pad")
					or (if desc:IsA("BasePart") then desc else desc:FindFirstChildWhichIsA("BasePart", true))

				if hopperPart and hopperPart:IsA("BasePart") then
					-- Equip harvested wheat
					if not equipToolNamed("wheat") and not equipToolNamed("grain") then
						equipToolNamed("harvest")
					end
					task.wait(0.02)

					physicallyTouch(hopperPart, hrp)

					local prompt = if desc:IsA("ProximityPrompt") then desc else desc:FindFirstChildWhichIsA("ProximityPrompt", true)
					if prompt then
						local a = string.lower(prompt.ActionText or "")
						local o = string.lower(prompt.ObjectText or "")
						if string.find(a, "process") or string.find(a, "deposit") or string.find(a, "separate") or string.find(a, "refine") or string.find(a, "insert") or string.find(a, "feed") or string.find(a, "sell") or string.find(o, "wheat") or string.find(o, "separator") or string.find(o, "processor") then
							if triggerPrompt(prompt) then
								processed += 1
							end
						end
					else
						local cd = desc:FindFirstChildWhichIsA("ClickDetector", true)
						if cd and triggerClick(cd) then
							processed += 1
						else
							processed += 1
						end
					end
					task.wait(0.04)
				end
			end
		end
	end

	return processed
end

-- 3. Collect Wheat Seeds from Seed Box / Spawner / Loose Items (Physical Touch Engine)
local function collectWheatSeeds(containers: {Instance}, hrp: BasePart, force: boolean?): number
	if not autoCollectWheat and not force then return 0 end
	local collected = 0

	-- Don't over-collect if inventory already holds 10+ seeds, unless forced
	if not force and countSeedsInInventory() >= 10 then
		return 0
	end

	local allContainers: {Instance} = {}
	for _, c in ipairs(containers) do
		table.insert(allContainers, c)
	end
	for _, folderName in ipairs({"Drops", "Debris", "Items", "Tools", "Spawns", "Seeds", "WheatSeeds", "Collectibles"}) do
		local folder = Workspace:FindFirstChild(folderName)
		if folder then
			table.insert(allContainers, folder)
		end
	end
	for _, obj in ipairs(Workspace:GetChildren()) do
		if obj:IsA("Tool") or (obj:IsA("Model") and isSeedDispenserOrItem(obj)) then
			table.insert(allContainers, obj)
		end
	end

	local touchedParts: {[BasePart]: boolean} = {}

	for _, container in ipairs(allContainers) do
		-- If the container itself is a Tool
		if container:IsA("Tool") and isSeedDispenserOrItem(container) then
			local hum = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
			if hum then pcall(function() hum:EquipTool(container) end) end
			local handle = container:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") and not touchedParts[handle] then
				touchedParts[handle] = true
				physicallyTouch(handle, hrp)
				collected += 1
			end
		end

		for _, desc in ipairs(container:GetDescendants()) do
			if isSeedDispenserOrItem(desc) then
				if desc:IsA("Tool") then
					local hum = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
					if hum then pcall(function() hum:EquipTool(desc) end) end
					local handle = desc:FindFirstChild("Handle")
					if handle and handle:IsA("BasePart") and not touchedParts[handle] then
						touchedParts[handle] = true
						physicallyTouch(handle, hrp)
						collected += 1
					end
				elseif desc:IsA("Model") or desc:IsA("Folder") then
					-- Collect and touch every BasePart in the seed dispenser model
					for _, child in ipairs(desc:GetDescendants()) do
						if child:IsA("BasePart") and not touchedParts[child] then
							touchedParts[child] = true
							physicallyTouch(child, hrp)
							local pp = child:FindFirstChildWhichIsA("ProximityPrompt", true)
							if pp then triggerPrompt(pp) end
							local cd = child:FindFirstChildWhichIsA("ClickDetector", true)
							if cd then triggerClick(cd) end
							collected += 1
						end
					end
				elseif desc:IsA("BasePart") then
					if not touchedParts[desc] then
						touchedParts[desc] = true
						physicallyTouch(desc, hrp)
						local pp = desc:FindFirstChildWhichIsA("ProximityPrompt", true)
						if pp then triggerPrompt(pp) end
						local cd = desc:FindFirstChildWhichIsA("ClickDetector", true)
						if cd then triggerClick(cd) end
						collected += 1
					end
				elseif desc:IsA("ProximityPrompt") then
					if desc.Parent and desc.Parent:IsA("BasePart") and not touchedParts[desc.Parent] then
						touchedParts[desc.Parent] = true
						physicallyTouch(desc.Parent, hrp)
						triggerPrompt(desc)
						collected += 1
					end
				elseif desc:IsA("ClickDetector") then
					if desc.Parent and desc.Parent:IsA("BasePart") and not touchedParts[desc.Parent] then
						touchedParts[desc.Parent] = true
						physicallyTouch(desc.Parent, hrp)
						triggerClick(desc)
						collected += 1
					end
				end
			end
		end
	end

	return collected
end

-- 4. Place / Plant Wheat in Empty Farm Plots (with physical touch & proximity)
local function placeWheatInFarms(containers: {Instance}, hrp: BasePart, hum: Humanoid): number
	if not autoPlantWheat then return 0 end
	local planted = 0

	-- Ensure seed/wheat tool is in inventory
	if not (hasToolNamed("seed") or hasToolNamed("wheat")) then
		return 0
	end

	for _, container in ipairs(containers) do
		for _, desc in ipairs(container:GetDescendants()) do
			if isFarmRelated(desc.Name) and (desc:IsA("Model") or desc:IsA("BasePart")) then
				local isPlanted = desc:GetAttribute("Planted") == true 
					or desc:GetAttribute("Occupied") == true 
					or desc:GetAttribute("HasCrop") == true

				if not isPlanted then
					local soilPart = if desc:IsA("BasePart") then desc else (desc:FindFirstChild("Soil") or desc:FindFirstChild("PlantSpot") or desc:FindFirstChildWhichIsA("BasePart", true))
					if soilPart and soilPart:IsA("BasePart") then
						-- Ensure seed tool is equipped
						if not equipToolNamed("seed") then
							equipToolNamed("wheat")
						end
						task.wait(0.02)

						physicallyTouch(soilPart, hrp)

						local prompt = desc:FindFirstChildWhichIsA("ProximityPrompt", true)
						if prompt then
							local a = string.lower(prompt.ActionText or "")
							if string.find(a, "plant") or string.find(a, "place") or string.find(a, "sow") or string.find(a, "farm") then
								if triggerPrompt(prompt) then
									planted += 1
								end
							end
						else
							local cd = desc:FindFirstChildWhichIsA("ClickDetector", true)
							if cd and triggerClick(cd) then
								planted += 1
							else
								planted += 1
							end
						end
						task.wait(0.04)
					end
				end
			end
		end
	end

	return planted
end

-- AutoFarm Loop Execution Step
local function runWheatFarmStep()
	local char = localPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (char and hrp and hum and hum.Health > 0) then return end

	local containers = getTycoonContainers()
	if #containers == 0 then return end

	local homeCF = hrp.CFrame
	local actionsTaken = 0

	-- Step 1: Harvest completed/mature crops first to free up plot slots
	local hCount = harvestCompletedWheat(containers, hrp)
	if hCount > 0 then
		TBODSquared.Metrics.wheatHarvested += hCount
		actionsTaken += hCount
	end

	-- Step 2: Automatically process/deliver harvested wheat to separator
	local pCount = processHarvestedWheat(containers, hrp)
	if pCount > 0 then
		TBODSquared.Metrics.wheatProcessed += pCount
		actionsTaken += pCount
	end

	-- Step 3: Collect fresh wheat seeds from seed box / dispenser
	local cCount = collectWheatSeeds(containers, hrp)
	if cCount > 0 then
		TBODSquared.Metrics.wheatCollected += cCount
		actionsTaken += cCount
	end

	-- Step 4: Place/plant wheat into empty farm plots
	local plCount = placeWheatInFarms(containers, hrp, hum)
	if plCount > 0 then
		TBODSquared.Metrics.wheatPlanted += plCount
		actionsTaken += plCount
	end

	-- Restore origin CFrame if actions were performed and return-home is enabled
	if actionsTaken > 0 and autoReturnHome and hrp and hrp.Parent then
		hrp.CFrame = homeCF
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end
end

-- AutoFarm Worker Loop
local function startFarmLoop()
	if farmThread then return end
	farmThread = task.spawn(function()
		while autoFarmWheatEnabled do
			local ok, err = pcall(runWheatFarmStep)
			if not ok then
				warn("[TBOD^2 AutoFarm] Error in farm cycle:", tostring(err))
			end
			task.wait(math.max(0.1, farmCycleDelay))
		end
		farmThread = nil
	end)
end

-- ── MODULE API INTERFACES ─────────────────────────────────────────────

function TBODSquared.setAutoPurchase(enabled: boolean)
	autoPurchaseEnabled = enabled
	if enabled then
		startPurchaseLoop()
	elseif purchaseThread then
		task.cancel(purchaseThread)
		purchaseThread = nil
	end
end

function TBODSquared.setSmartPurchase(enabled: boolean)
	smartPurchaseEnabled = enabled
end

function TBODSquared.setPurchaseDelay(delayVal: number)
	purchaseDelay = math.clamp(delayVal, 0.05, 5.0)
end

function TBODSquared.setAutoRebirth(enabled: boolean)
	autoRebirthEnabled = enabled
	if enabled or autoRebirthOnCapped then
		startRebirthLoop()
	elseif not autoRebirthOnCapped and rebirthThread then
		task.cancel(rebirthThread)
		rebirthThread = nil
	end
end

function TBODSquared.setAutoRebirthOnCapped(enabled: boolean)
	autoRebirthOnCapped = enabled
	if enabled or autoRebirthEnabled then
		startRebirthLoop()
	elseif not autoRebirthEnabled and rebirthThread then
		task.cancel(rebirthThread)
		rebirthThread = nil
	end
end

function TBODSquared.setRebirthEssenceTarget(target: number)
	rebirthEssenceTarget = math.max(1, target)
end

function TBODSquared.manualRebirth(): boolean
	return executeRebirth()
end

function TBODSquared.promptRebirth(): boolean
	return promptRebirth()
end

function TBODSquared.setAutoFarmWheat(enabled: boolean)
	autoFarmWheatEnabled = enabled
	if enabled then
		startFarmLoop()
	elseif farmThread then
		task.cancel(farmThread)
		farmThread = nil
	end
end

function TBODSquared.setAutoCollectWheat(enabled: boolean)
	autoCollectWheat = enabled
end

function TBODSquared.setAutoPlantWheat(enabled: boolean)
	autoPlantWheat = enabled
end

function TBODSquared.setAutoHarvestWheat(enabled: boolean)
	autoHarvestWheat = enabled
end

function TBODSquared.setAutoProcessWheat(enabled: boolean)
	autoProcessWheat = enabled
end

function TBODSquared.setFarmCycleDelay(delayVal: number)
	farmCycleDelay = math.clamp(delayVal, 0.05, 3.0)
end

function TBODSquared.setAutoReturnHome(enabled: boolean)
	autoReturnHome = enabled
end

function TBODSquared.harvestAllPlotsNow(): number
	local char = localPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return 0 end
	local homeCF = hrp.CFrame
	local containers = getTycoonContainers()
	local count = harvestCompletedWheat(containers, hrp)
	TBODSquared.Metrics.wheatHarvested += count
	if count > 0 and autoReturnHome and hrp and hrp.Parent then
		hrp.CFrame = homeCF
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end
	return count
end

function TBODSquared.processWheatNow(): number
	local char = localPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return 0 end
	local homeCF = hrp.CFrame
	local containers = getTycoonContainers()
	local count = processHarvestedWheat(containers, hrp)
	TBODSquared.Metrics.wheatProcessed += count
	if count > 0 and autoReturnHome and hrp and hrp.Parent then
		hrp.CFrame = homeCF
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end
	return count
end

function TBODSquared.collectSeedsNow(): number
	local char = localPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return 0 end
	local homeCF = hrp.CFrame
	local containers = getTycoonContainers()
	local count = collectWheatSeeds(containers, hrp, true)
	TBODSquared.Metrics.wheatCollected += count
	if count > 0 and autoReturnHome and hrp and hrp.Parent then
		hrp.CFrame = homeCF
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end
	return count
end

function TBODSquared.stop()
	TBODSquared.setAutoPurchase(false)
	TBODSquared.setAutoRebirth(false)
	TBODSquared.setAutoRebirthOnCapped(false)
	TBODSquared.setAutoFarmWheat(false)
	if purchaseThread then
		task.cancel(purchaseThread)
		purchaseThread = nil
	end
	if rebirthThread then
		task.cancel(rebirthThread)
		rebirthThread = nil
	end
	if farmThread then
		task.cancel(farmThread)
		farmThread = nil
	end
	cachedTycoon = nil
	cachedPlotName = nil
end

return TBODSquared
