--!strict
--[=[
    ✦ Lucky Blocks Battlegrounds Automation & Combat Suite ✦
    Features:
    - Auto-Claim All Lucky Blocks (Normal, Super, Diamond, Rainbow, Galaxy, Void)
    - Auto-Open / Use Inventory Lucky Blocks
    - Weapon Auto-Spam / Turbo Sword Slash
    - Anti-Void Fall Rescue
    - Fast Block Teleports (Center, Rainbow, Galaxy, Void, Spawns 1-8)
]=]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

local LuckyBlocks = {
	AutoClaimBlocks = false,
	AutoOpenBlocks = false,
	TurboSword = false,
	AntiVoid = true,
	ClaimInterval = 0.35,
	ClaimVoid = true,
	ClaimRainbow = true,
	ClaimGalaxy = true,
	ClaimDiamond = true,
	ClaimSuper = true,
	ClaimLucky = true,
}

local claimThread: thread? = nil
local openThread: thread? = nil
local swordThread: thread? = nil
local antiVoidConn: RBXScriptConnection? = nil

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
			task.wait(0.01)
			fti(hrp, targetPart, 1)
		end)
	else
		local origCF = hrp.CFrame
		pcall(function()
			hrp.CFrame = targetPart.CFrame
			task.wait(0.03)
			hrp.CFrame = origCF
		end)
	end
end

-- ── 1. Lucky Block Collector Engine ───────────────────────────────────
local function getBlockGivers(): {BasePart}
	local parts: {BasePart} = {}
	for _, desc in ipairs(Workspace:GetDescendants()) do
		if desc.Name == "TouchMe" and desc:IsA("BasePart") then
			local giver = desc:FindFirstAncestorOfClass("Model")
			local gName = giver and giver.Name:lower() or ""

			local allow = false
			if gName:find("void") and LuckyBlocks.ClaimVoid then
				allow = true
			elseif gName:find("rainbow") and LuckyBlocks.ClaimRainbow then
				allow = true
			elseif gName:find("galaxy") and LuckyBlocks.ClaimGalaxy then
				allow = true
			elseif gName:find("diamond") and LuckyBlocks.ClaimDiamond then
				allow = true
			elseif gName:find("super") and LuckyBlocks.ClaimSuper then
				allow = true
			elseif (gName:find("lucky") or gName:find("block")) and LuckyBlocks.ClaimLucky then
				allow = true
			else
				allow = true
			end

			if allow then
				table.insert(parts, desc)
			end
		end
	end
	return parts
end

function LuckyBlocks.claimAllBlocksNow(): number
	local givers = getBlockGivers()
	local count = 0
	for _, p in ipairs(givers) do
		touchPart(p)
		count += 1
	end
	return count
end

function LuckyBlocks.setAutoClaim(enabled: boolean)
	LuckyBlocks.AutoClaimBlocks = enabled
	if claimThread then
		task.cancel(claimThread)
		claimThread = nil
	end

	if enabled then
		claimThread = task.spawn(function()
			while LuckyBlocks.AutoClaimBlocks do
				pcall(function()
					local givers = getBlockGivers()
					for _, p in ipairs(givers) do
						if not LuckyBlocks.AutoClaimBlocks then break end
						touchPart(p)
					end
				end)
				task.wait(math.max(LuckyBlocks.ClaimInterval, 0.2))
			end
		end)
	end
end

-- ── 2. Auto-Open / Use Inventory Blocks ──────────────────────────────
function LuckyBlocks.setAutoOpen(enabled: boolean)
	LuckyBlocks.AutoOpenBlocks = enabled
	if openThread then
		task.cancel(openThread)
		openThread = nil
	end

	if enabled then
		openThread = task.spawn(function()
			while LuckyBlocks.AutoOpenBlocks do
				pcall(function()
					local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
					local char = LocalPlayer.Character
					local hum = char and char:FindFirstChildOfClass("Humanoid")

					if bp and hum then
						for _, item in ipairs(bp:GetChildren()) do
							if item:IsA("Tool") and item.Name:lower():find("block") then
								hum:EquipTool(item)
								task.wait(0.05)
								item:Activate()
								task.wait(0.05)
							end
						end
					end

					if char then
						for _, item in ipairs(char:GetChildren()) do
							if item:IsA("Tool") and item.Name:lower():find("block") then
								item:Activate()
							end
						end
					end
				end)
				task.wait(0.2)
			end
		end)
	end
end

-- ── 3. Turbo Sword / Fast Weapon Attack ──────────────────────────────
function LuckyBlocks.setTurboSword(enabled: boolean)
	LuckyBlocks.TurboSword = enabled
	if swordThread then
		task.cancel(swordThread)
		swordThread = nil
	end

	if enabled then
		swordThread = task.spawn(function()
			while LuckyBlocks.TurboSword do
				pcall(function()
					local char = LocalPlayer.Character
					if char then
						local tool = char:FindFirstChildOfClass("Tool")
						if tool and typeof(tool.Activate) == "function" and not tool.Name:lower():find("block") then
							tool:Activate()
						end
					end
				end)
				task.wait(0.04)
			end
		end)
	end
end

-- ── 4. Anti-Void Rescue ──────────────────────────────────────────────
function LuckyBlocks.setAntiVoid(enabled: boolean)
	LuckyBlocks.AntiVoid = enabled
	if antiVoidConn then
		antiVoidConn:Disconnect()
		antiVoidConn = nil
	end

	if enabled then
		antiVoidConn = RunService.Heartbeat:Connect(function()
			local hrp = getHrp()
			if hrp and hrp.Position.Y < 120 then
				hrp.AssemblyLinearVelocity = Vector3.new(0, 80, 0)
				hrp.CFrame = CFrame.new(hrp.Position.X, 195, hrp.Position.Z)
			end
		end)
	end
end

-- ── 5. Fast Teleports ────────────────────────────────────────────────
local TELEPORT_POINTS: {[string]: CFrame} = {
	["Center Void / High Tier"] = CFrame.new(-1041, 198, 90),
	["Center Rainbow Giver"] = CFrame.new(-1050, 195, 81),
	["Center Galaxy Giver"] = CFrame.new(-1031, 195, 81),
	["Spawn 1 Base"] = CFrame.new(-1130, 195, 360),
	["Spawn 2 Base"] = CFrame.new(-950, 195, 360),
	["Spawn 3 Base"] = CFrame.new(-750, 195, 200),
	["Spawn 4 Base"] = CFrame.new(-750, 195, -20),
	["Spawn 5 Base"] = CFrame.new(-950, 195, -180),
	["Spawn 6 Base"] = CFrame.new(-1130, 195, -180),
	["Spawn 7 Base"] = CFrame.new(-1330, 195, -20),
	["Spawn 8 Base"] = CFrame.new(-1330, 195, 200),
}

function LuckyBlocks.teleportTo(locName: string): boolean
	local hrp = getHrp()
	local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then return false end

	local targetCF = TELEPORT_POINTS[locName]
	if targetCF then
		pcall(function()
			hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
			hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
			hum.PlatformStand = false
			hum.Sit = false
		end)
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		hrp.CFrame = targetCF * CFrame.new(0, 2, 0)
		pcall(function()
			hum:ChangeState(Enum.HumanoidStateType.Running)
		end)
		return true
	end
	return false
end

function LuckyBlocks.getLocations(): {string}
	local list: {string} = {}
	for name in pairs(TELEPORT_POINTS) do
		table.insert(list, name)
	end
	table.sort(list)
	return list
end

return LuckyBlocks
