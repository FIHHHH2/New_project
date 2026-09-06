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

-- Vendor / Merchant State
local autoBuyVendorEnabled = false
local lastVendorPurchaseTime = 0

-- Runtime references & connections
local purchaseThread: thread? = nil
local rebirthThread: thread? = nil
local farmThread: thread? = nil
local vendorThread: thread? = nil
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
	vendorCardsPurchased = 0,
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

	local pg = localPlayer:FindFirstChild("PlayerGui")
	if pg then
		-- 1. Strictly check if the explicit Capped label in Rebirth dialog is VISIBLE
		local inner = pg:FindFirstChild("Main")
			and pg.Main:FindFirstChild("Rebirth")
			and pg.Main.Rebirth:FindFirstChild("Main")
			and pg.Main.Rebirth.Main:FindFirstChild("Inner")
		if inner then
			local capped = inner:FindFirstChild("Capped")
			if capped and capped:IsA("TextLabel") and capped.Visible and string.find(string.upper(capped.Text), "CAPPED") ~= nil then
				return true, "Rebirth dialog indicates (Capped)"
			end
		end

		-- 2. Check HUD for any explicitly VISIBLE label indicating capped
		local system = pg:FindFirstChild("System")
		if system then
			for _, desc in ipairs(system:GetDescendants()) do
				if desc:IsA("TextLabel") and desc.Visible then
					local textUpper = string.upper(desc.Text or "")
					if string.find(textUpper, "ESSENCE CAPPED") or string.find(textUpper, "(CAPPED)") then
						return true, "HUD indicates " .. desc.Text
					end
				end
			end
		end
	end

	-- 3. Attribute / Value check on player and leaderstats
	local attrCap = localPlayer:GetAttribute("EssenceCap") 
		or localPlayer:GetAttribute("MaxEssence")
		or localPlayer:GetAttribute("RebirthCap")
	if attrCap and tonumber(attrCap) then
		local capNum = tonumber(attrCap)
		if capNum and capNum > 0 and currentEssence >= capNum then
			return true, string.format("Reached Attribute Cap (%d)", capNum)
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

local autoClickRebirthOnOpen = true

-- Simulate a complete physical and signal click on the Rebirth button
local function clickRebirthConfirmButton(rebBtn: GuiButton)
	if not (rebBtn and rebBtn.Parent) then return end

	-- Method 1: firesignal for all mouse/activation signals
	local fs = (firesignal :: any) or (getgenv and getgenv().firesignal)
	if type(fs) == "function" then
		pcall(function()
			fs(rebBtn.MouseButton1Down)
			fs(rebBtn.MouseButton1Click)
			fs(rebBtn.MouseButton1Up)
			fs(rebBtn.Activated)
		end)
	end

	-- Method 2: VirtualInputManager physical cursor click
	local vim = game:GetService("VirtualInputManager")
	if vim and rebBtn.AbsolutePosition.X > 0 and rebBtn.AbsolutePosition.Y > 0 then
		local cx = rebBtn.AbsolutePosition.X + rebBtn.AbsoluteSize.X / 2
		local cy = rebBtn.AbsolutePosition.Y + rebBtn.AbsoluteSize.Y / 2
		pcall(function()
			vim:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
			task.wait(0.04)
			vim:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
		end)
	end

	-- Method 3: Direct connection triggers
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

	-- If farther than 15 studs, pulse to button so server validates proximity
	if dist > 15 then
		pulsed = true
		hrp.CFrame = CFrame.new(part.Position + Vector3.new(0, 2.5, 3.0))
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		task.wait(0.08)
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
		task.wait(0.2)
		if hrp and hrp.Parent then
			hrp.CFrame = origCF
		end
	end

	return true
end

-- Trigger Full Rebirth Sequence (Prompt Obelisk + Confirm Rebirth)
local function executeRebirth(): boolean
	-- Step 1: Prompt the Obelisk to open the dialog
	promptRebirth()
	task.wait(0.35)

	local pg = localPlayer:FindFirstChild("PlayerGui")
	if not pg then return false end

	local mainGui = pg:FindFirstChild("Main")
	local rebirthGui = mainGui and mainGui:FindFirstChild("Rebirth")
	if not (rebirthGui and (rebirthGui.Visible or rebirthGui.Position.Y.Scale >= 0)) then
		promptRebirth()
		task.wait(0.4)
		mainGui = pg:FindFirstChild("Main")
		rebirthGui = mainGui and mainGui:FindFirstChild("Rebirth")
	end

	if not rebirthGui then return false end

	-- Step 2: Confirm rebirth via the GUI button
	local rebBtn = findRebirthConfirmButton(rebirthGui)
	if rebBtn then
		clickRebirthConfirmButton(rebBtn)
		TBODSquared.Metrics.rebirthsTriggered += 1
		cachedTycoon = nil
		return true
	end
	return false
end

-- Automatic watcher that prompts a click on the Rebirth button whenever the GUI is opened
local function setupRebirthGuiWatcher()
	task.spawn(function()
		local pg = localPlayer:WaitForChild("PlayerGui", 10)
		if not pg then return end
		local main = pg:WaitForChild("Main", 10)
		if not main then return end
		local rebirthFrame = main:WaitForChild("Rebirth", 10)
		if not rebirthFrame then return end

		local isClicking = false
		local function handleGuiOpen()
			if isClicking then return end
			-- Confirm if user wants auto-click on open, OR if any auto-rebirth mode is enabled
			if not (autoClickRebirthOnOpen or autoRebirthEnabled or autoRebirthOnCapped) then return end
			isClicking = true
			task.wait(0.25) -- Wait for on-screen tween to settle

			for attempt = 1, 3 do
				local rebBtn = findRebirthConfirmButton(rebirthFrame)
				if rebBtn and rebBtn.Visible then
					clickRebirthConfirmButton(rebBtn)
					TBODSquared.Metrics.rebirthsTriggered += 1
					cachedTycoon = nil
					break
				end
				task.wait(0.2)
			end
			task.wait(1.0)
			isClicking = false
		end

		rebirthFrame:GetPropertyChangedSignal("Visible"):Connect(function()
			if rebirthFrame.Visible then
				handleGuiOpen()
			end
		end)

		rebirthFrame:GetPropertyChangedSignal("Position"):Connect(function()
			if rebirthFrame.Position.Y.Scale >= 0 then
				handleGuiOpen()
			end
		end)
	end)
end

-- Start watcher immediately
setupRebirthGuiWatcher()

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

-- Unequip whatever tool is currently held so hands are free
local function unequipAllTools()
	local char = localPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:UnequipTools()
		task.wait(0.04)
	end
end

-- Check if player carries a specific tool by exact name in Backpack or Character
local function getToolCount(name: string): number
	local count = 0
	local char = localPlayer.Character
	if char then
		for _, item in ipairs(char:GetChildren()) do
			if item:IsA("Tool") and item.Name == name then
				count += 1
			end
		end
	end
	local bp = localPlayer:FindFirstChild("Backpack")
	if bp then
		for _, item in ipairs(bp:GetChildren()) do
			if item:IsA("Tool") and item.Name == name then
				count += 1
			end
		end
	end
	return count
end

local function hasSeedTool(): boolean
	return getToolCount("Wheat Seeds") > 0
end

local function hasGrownWheatTool(): boolean
	return getToolCount("Wheat") > 0
end

-- Equip a specific tool by exact name, unequipping anything else first
local function equipExactTool(name: string): boolean
	local char = localPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return false end

	-- Check if already held in character
	for _, item in ipairs(char:GetChildren()) do
		if item:IsA("Tool") and item.Name == name then
			return true
		end
	end

	-- Unequip conflicting tools first
	hum:UnequipTools()
	task.wait(0.03)

	local bp = localPlayer:FindFirstChild("Backpack")
	if bp then
		local tool = bp:FindFirstChild(name)
		if tool and tool:IsA("Tool") then
			hum:EquipTool(tool)
			task.wait(0.04)
			return true
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

-- Count how many seeds are currently in the tycoon's seed basket/box (0 to 4)
local function getBasketSeedCount(box: Instance): number
	-- 1. Check BillboardGui on Display
	local display = box:FindFirstChild("Display")
	if display then
		local bg = display:FindFirstChildWhichIsA("BillboardGui", true)
		local tl = bg and bg:FindFirstChildWhichIsA("TextLabel", true)
		if tl and tl.Text then
			local txt = tl.Text
			if string.find(txt, "4/4") ~= nil then
				return 4
			elseif string.find(txt, "3/4") ~= nil then
				return 3
			elseif string.find(txt, "2/4") ~= nil then
				return 2
			elseif string.find(txt, "1/4") ~= nil then
				return 1
			elseif string.find(string.lower(txt), "empty") ~= nil or string.find(txt, "0/4") ~= nil then
				return 0
			end
		end
	end

	-- 2. Inspect seed models for visible, touchable parts (transparency < 0.5, canTouch == true)
	local solidCount = 0
	for _, child in ipairs(box:GetChildren()) do
		if string.find(string.lower(child.Name), "wheatseed") then
			local isSolid = false
			for _, p in ipairs(child:GetDescendants()) do
				if p:IsA("BasePart") and p.Transparency < 0.5 and p.CanTouch then
					isSolid = true
					break
				end
			end
			if isSolid then
				solidCount += 1
			end
		end
	end

	return solidCount
end

-- 1. Harvest Completed / Mature Wheat from Farms
local function harvestCompletedWheat(containers: {Instance}, hrp: BasePart): number
	if not autoHarvestWheat then return 0 end
	local harvested = 0

	for _, container in ipairs(containers) do
		for _, desc in ipairs(container:GetDescendants()) do
			if desc.Name == "FarmPlot" or desc:GetAttribute("IsFarmPlot") == true then
				local isHarvestable = desc:GetAttribute("Harvestable") == true 
					or desc:GetAttribute("Ready") == true 
					or desc:GetAttribute("Mature") == true 
					or desc:GetAttribute("Grown") == true

				if isHarvestable then
					local targetPart = if desc:IsA("BasePart") then desc else desc:FindFirstChildWhichIsA("BasePart", true)
					if targetPart then
						physicallyTouch(targetPart, hrp)

						-- Trigger ClickDetector
						local cd = desc:FindFirstChildWhichIsA("ClickDetector", true)
						if cd then
							triggerClick(cd)
						end

						-- Trigger ProximityPrompt if any
						local pp = desc:FindFirstChildWhichIsA("ProximityPrompt", true)
						if pp and (string.find(string.lower(pp.ActionText or ""), "harvest") or string.find(string.lower(pp.ActionText or ""), "collect")) then
							triggerPrompt(pp)
						end

						harvested += 1
						task.wait(0.04)
					end
				end
			end
		end
	end

	return harvested
end

-- 2. Automatically Process Harvested Wheat (Must be beside Wheat Seperator, equip Wheat, prompt 'E')
local function processHarvestedWheat(containers: {Instance}, hrp: BasePart): number
	if not autoProcessWheat then return 0 end
	if not hasGrownWheatTool() then return 0 end

	local processed = 0

	for _, container in ipairs(containers) do
		-- Look for Wheat Seperator in tycoon
		local ws = container:FindFirstChild("Wheat Seperator", true)
		if not ws then
			for _, desc in ipairs(container:GetDescendants()) do
				local nameLower = string.lower(desc.Name)
				if string.find(nameLower, "seperator") or string.find(nameLower, "separator") or (string.find(nameLower, "wheat") and string.find(nameLower, "mill")) then
					ws = desc
					break
				end
			end
		end

		if ws then
			local ctp = ws:FindFirstChild("clickTouchPart") or ws:FindFirstChildWhichIsA("BasePart", true)
			if ctp and ctp:IsA("BasePart") then
				-- 1. Unequip whatever was held, and equip grown Wheat tool
				if not equipExactTool("Wheat") then
					return 0
				end

				-- 2. Teleport BESIDE the Wheat Seperator (within 3-4 studs of clickTouchPart at floor level)
				local besideCF = CFrame.new(ctp.Position + Vector3.new(0, -1.0, 3.5))
				hrp.CFrame = besideCF
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
				task.wait(0.05)

				-- 3. Prompt 'E' / fire proximity prompt
				local prompt = ctp:FindFirstChildOfClass("ProximityPrompt") 
					or ws:FindFirstChildWhichIsA("ProximityPrompt", true)
				if prompt then
					triggerPrompt(prompt)
					task.wait(0.08)
				end

				-- Also trigger click or touch interest on ctp
				local cd = ws:FindFirstChildWhichIsA("ClickDetector", true)
				if cd then triggerClick(cd) end
				triggerTouch(ctp, hrp)

				processed += 1
				task.wait(0.05)
				break
			end
		end
	end

	return processed
end

-- 3. Collect Wheat Seeds from Basket (Only when full 4/4, unequip tools before touching)
local function collectWheatSeeds(containers: {Instance}, hrp: BasePart, force: boolean?): number
	if not autoCollectWheat and not force then return 0 end

	local collected = 0

	for _, container in ipairs(containers) do
		-- Look for the seed basket/box in Tycoon.Items
		local box = container:FindFirstChild("Box", true)
		if box then
			local count = getBasketSeedCount(box)
			-- ONLY teleport and collect when basket is full (4/4) or if force triggered manually
			if force or count >= 4 then
				-- Unequip all tools first so hands are free to collect
				unequipAllTools()

				local touchPart = box:FindFirstChild("touchPart") 
					or box:FindFirstChildWhichIsA("BasePart")
				if touchPart and touchPart:IsA("BasePart") then
					physicallyTouch(touchPart, hrp)
					task.wait(0.12)
					collected += math.max(1, count)
				end
			end
		end
	end

	return collected
end

-- 4. Place / Plant Wheat in Empty Farm Plots (Only when Wheat Seeds are in inventory, unequip other items)
local function placeWheatInFarms(containers: {Instance}, hrp: BasePart, hum: Humanoid): number
	if not autoPlantWheat then return 0 end

	-- MUST HAVE SEEDS: grown regular wheat cannot be planted!
	if not hasSeedTool() then
		return 0
	end

	local planted = 0

	local farmPlantRemote = ReplicatedStorage:FindFirstChild("RemoteEvents")
		and ReplicatedStorage.RemoteEvents:FindFirstChild("FarmPlant") :: RemoteEvent?

	for _, container in ipairs(containers) do
		for _, desc in ipairs(container:GetDescendants()) do
			if desc.Name == "FarmPlot" or desc:GetAttribute("IsFarmPlot") == true then
				local plantedCrops = desc:GetAttribute("PlantedCrops") or 0
				local requiredCrops = desc:GetAttribute("RequiredCrops") or 1
				local growing = desc:GetAttribute("Growing") == true
				local harvestable = desc:GetAttribute("Harvestable") == true

				-- Plot needs planting if it has space and is not currently growing/harvestable
				if plantedCrops < requiredCrops and not growing and not harvestable then
					-- Stop if we ran out of seeds
					if not hasSeedTool() then
						break
					end

					-- Ensure Wheat Seeds tool is equipped (unequips any other item first)
					if not equipExactTool("Wheat Seeds") then
						break
					end

					local soilPart = if desc:IsA("BasePart") then desc else desc:FindFirstChildWhichIsA("BasePart", true)
					if soilPart then
						physicallyTouch(soilPart, hrp)

						-- Fire server FarmPlant remote with plot target
						if farmPlantRemote then
							pcall(function()
								farmPlantRemote:FireServer(desc)
							end)
						end

						-- Also trigger proximity prompt if present
						local pp = desc:FindFirstChildWhichIsA("ProximityPrompt", true)
						if pp then
							triggerPrompt(pp)
						end

						local cd = desc:FindFirstChildWhichIsA("ClickDetector", true)
						if cd then
							triggerClick(cd)
						end

						planted += 1
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

function TBODSquared.setAutoClickRebirthOnOpen(enabled: boolean)
	autoClickRebirthOnOpen = enabled
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

-- ── VENDOR / MERCHANT AUTOMATION ─────────────────────────────────────────

-- Find player's closest vendor/bits shop
local function getMyBitsShop(): Model?
	local bs = Workspace:FindFirstChild("BitsShops")
	if not bs then return nil end

	local tyc = TBODSquared.getMyTycoon()
	local refPos: Vector3? = nil
	if tyc then
		local cf, _ = tyc:GetBoundingBox()
		refPos = cf.Position
	elseif localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
		refPos = (localPlayer.Character.HumanoidRootPart :: BasePart).Position
	end

	local bestShop: Model? = nil
	local bestDist = math.huge

	for _, child in ipairs(bs:GetChildren()) do
		if child:IsA("Model") then
			local cf, _ = child:GetBoundingBox()
			local dist = refPos and (refPos - cf.Position).Magnitude or 0
			if dist < bestDist then
				bestDist = dist
				bestShop = child
			end
		end
	end

	return bestShop
end

-- Inspect and attempt to purchase the best affordable card from the vendor
function TBODSquared.buyBestVendorCardNow(): (boolean, string)
	local shop = getMyBitsShop()
	if not shop then
		return false, "Vendor shop not found"
	end

	local cardsFolder = shop:FindFirstChild("Cards")
	if not cardsFolder or #cardsFolder:GetChildren() == 0 then
		return false, "No cards available at vendor (Merchant absent)"
	end

	local currentCash = TBODSquared.getPlayerCash()

	type CardOption = {
		model: Instance,
		bits: number,
		price: number,
		targetPart: BasePart?,
		prompt: ProximityPrompt?,
		click: ClickDetector?,
	}

	local candidates: {CardOption} = {}

	for _, cardModel in ipairs(cardsFolder:GetChildren()) do
		local bitsVal = 0
		local priceVal = 0

		-- 1. Check Model Attributes
		local attrBits = cardModel:GetAttribute("Bits") or cardModel:GetAttribute("Value")
		if attrBits and tonumber(attrBits) then
			bitsVal = tonumber(attrBits) or 0
		end

		local attrPrice = cardModel:GetAttribute("Price") 
			or cardModel:GetAttribute("DiscountedPrice") 
			or cardModel:GetAttribute("Cost")
		if attrPrice and tonumber(attrPrice) then
			priceVal = tonumber(attrPrice) or 0
		end

		-- 2. Check SurfaceGui labels
		for _, desc in ipairs(cardModel:GetDescendants()) do
			if desc:IsA("TextLabel") then
				local nameLower = string.lower(desc.Name)
				if nameLower == "bitsdisplay" or (string.find(nameLower, "bits") and not string.find(nameLower, "dash")) then
					local parsed = parseFormattedNumber(desc.Text)
					if parsed > bitsVal then bitsVal = parsed end
				elseif nameLower == "pricedisplay" or (string.find(nameLower, "price") and not string.find(nameLower, "dash")) then
					local parsed = parseFormattedNumber(desc.Text)
					if parsed > priceVal then priceVal = parsed end
				end
			end
		end

		-- 3. Resolve interaction triggers
		local prompt = cardModel:FindFirstChildWhichIsA("ProximityPrompt", true)
		local click = cardModel:FindFirstChildWhichIsA("ClickDetector", true)
		local targetPart = (prompt and prompt.Parent:IsA("BasePart") and prompt.Parent :: BasePart)
			or (click and click.Parent:IsA("BasePart") and click.Parent :: BasePart)
			or (cardModel:IsA("Model") and cardModel.PrimaryPart)
			or cardModel:FindFirstChildWhichIsA("BasePart", true)

		table.insert(candidates, {
			model = cardModel,
			bits = bitsVal,
			price = priceVal,
			targetPart = targetPart,
			prompt = prompt,
			click = click,
		})
	end

	if #candidates == 0 then
		return false, "No valid cards detected"
	end

	-- Filter to affordable cards: if currentCash > 0, price must be <= currentCash
	local affordable: {CardOption} = {}
	for _, cand in ipairs(candidates) do
		if currentCash <= 0 or cand.price <= currentCash or cand.price == 0 then
			table.insert(affordable, cand)
		end
	end

	if #affordable == 0 then
		return false, string.format("Cannot afford any cards (Balance: $%d, Lowest: $%d)", 
			currentCash, candidates[1].price)
	end

	-- Sort by best value: highest bits first; if equal or 0, highest price first
	table.sort(affordable, function(a, b)
		if a.bits ~= b.bits then
			return a.bits > b.bits
		end
		return a.price > b.price
	end)

	local best = affordable[1]
	local char = localPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then return false, "No HumanoidRootPart" end

	local origCF = hrp.CFrame
	local didBuy = false

	if best.targetPart then
		-- Position character right at card
		hrp.CFrame = CFrame.new(best.targetPart.Position + Vector3.new(0, 2.5, 2.0))
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		task.wait(0.06)

		if best.prompt then
			triggerPrompt(best.prompt)
			didBuy = true
		end
		if best.click then
			triggerClick(best.click)
			didBuy = true
		end
		triggerTouch(best.targetPart, hrp)
		didBuy = true

		task.wait(0.15)
		if hrp and hrp.Parent then
			hrp.CFrame = origCF
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
		end
	end

	if didBuy then
		TBODSquared.Metrics.vendorCardsPurchased += 1
		lastVendorPurchaseTime = os.clock()
		return true, string.format("Purchased best card (Bits: %d, Cost: $%d)", best.bits, best.price)
	end

	return false, "Failed to interact with card"
end

local function startVendorLoop()
	if vendorThread then return end
	vendorThread = task.spawn(function()
		while autoBuyVendorEnabled do
			local now = os.clock()
			if now - lastVendorPurchaseTime >= 3.0 then
				pcall(function()
					TBODSquared.buyBestVendorCardNow()
				end)
			end
			task.wait(2.5)
		end
		vendorThread = nil
	end)
end

function TBODSquared.setAutoBuyVendor(enabled: boolean)
	autoBuyVendorEnabled = enabled
	if enabled then
		startVendorLoop()
	elseif vendorThread then
		task.cancel(vendorThread)
		vendorThread = nil
	end
end

function TBODSquared.stop()
	TBODSquared.setAutoPurchase(false)
	TBODSquared.setAutoRebirth(false)
	TBODSquared.setAutoRebirthOnCapped(false)
	TBODSquared.setAutoFarmWheat(false)
	TBODSquared.setAutoBuyVendor(false)
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
	if vendorThread then
		task.cancel(vendorThread)
		vendorThread = nil
	end
	cachedTycoon = nil
	cachedPlotName = nil
end

return TBODSquared
