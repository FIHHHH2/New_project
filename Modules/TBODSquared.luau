--!strict
-- Modules/TBODSquared.luau
-- Automation & Modifiers for [UPD 1.5] TBOD^2 (Tycoon But One Dropper: SQUARED)
-- PlaceId: 139063887391814

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local localPlayer = Players.LocalPlayer

local TBODSquared = {}
TBODSquared.__index = TBODSquared

-- State
local isRunning = false
local autoPurchaseEnabled = false
local smartPurchaseEnabled = true
local purchaseDelay = 0.3
local autoRebirthEnabled = false
local rebirthEssenceTarget = 50

-- Runtime references & connections
local purchaseThread: thread? = nil
local rebirthThread: thread? = nil
local cachedTycoon: Model? = nil
local cachedPlotName: string? = nil

-- Metrics
TBODSquared.Metrics = {
	buttonsPurchased = 0,
	rebirthsTriggered = 0,
	lastRebirthEssence = 0,
	currentCash = "$0",
	currentEssence = "+0"
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
	return 0
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

-- Trigger Rebirth Sequence
local function executeRebirth(): boolean
	local obelisk = Workspace:FindFirstChild("Obelisk")
	local clickPart = obelisk and obelisk:FindFirstChild("RebirthButton") and obelisk.RebirthButton:FindFirstChild("Click") :: BasePart?
	if not clickPart then return false end

	-- Open Rebirth Interface via Obelisk Button
	local fcd = (fireclickdetector :: any) or (getgenv and getgenv().fireclickdetector)
	local cd = clickPart:FindFirstChildWhichIsA("ClickDetector")
	if cd and type(fcd) == "function" then
		pcall(fcd, cd)
	end

	local fpp = (fireproximityprompt :: any) or (getgenv and getgenv().fireproximityprompt)
	local pp = clickPart:FindFirstChildWhichIsA("ProximityPrompt")
	if pp and type(fpp) == "function" then
		pcall(fpp, pp)
	end

	-- Wait for UI to show
	task.wait(0.2)

	local pg = localPlayer:FindFirstChild("PlayerGui")
	local rebBtn = pg and pg:FindFirstChild("Main")
		and pg.Main:FindFirstChild("Rebirth")
		and pg.Main.Rebirth:FindFirstChild("Main")
		and pg.Main.Rebirth.Main:FindFirstChild("Inner")
		and pg.Main.Rebirth.Main.Inner:FindFirstChild("Rebirth") :: GuiButton?

	if rebBtn then
		local fs = (firesignal :: any) or (getgenv and getgenv().firesignal)
		if type(fs) == "function" then
			pcall(function()
				fs(rebBtn.MouseButton1Click)
				fs(rebBtn.Activated)
			end)
		end
		TBODSquared.Metrics.rebirthsTriggered += 1
		cachedTycoon = nil -- Invalidate tycoon cache after rebirth reset
		return true
	end
	return false
end

-- Auto Rebirth Loop
local function startRebirthLoop()
	if rebirthThread then return end
	rebirthThread = task.spawn(function()
		while autoRebirthEnabled do
			local pending = TBODSquared.getPendingEssence()
			if pending >= rebirthEssenceTarget and pending > 0 then
				TBODSquared.Metrics.lastRebirthEssence = pending
				executeRebirth()
				task.wait(2.5) -- Debounce to allow plot reload & rebirth animation
			end
			task.wait(0.5)
		end
		rebirthThread = nil
	end)
end

-- Conveyor Speed Boosting
-- Module Interface
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
	if enabled then
		startRebirthLoop()
	elseif rebirthThread then
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

function TBODSquared.stop()
	TBODSquared.setAutoPurchase(false)
	TBODSquared.setAutoRebirth(false)
	if purchaseThread then
		task.cancel(purchaseThread)
		purchaseThread = nil
	end
	if rebirthThread then
		task.cancel(rebirthThread)
		rebirthThread = nil
	end
	cachedTycoon = nil
end

return TBODSquared
