--!strict
--[=[
    ✦ Natural Disaster Survival — Full Utility Module ✦
    Features:
    - Disaster Tracker (multi-source: SurvivalTag, ReplicatedStorage, PlayerGui)
    - No Fall Damage (script removal + velocity clamp)
    - Flight Engine (delta-time, no fall impact)
    - Anti-Fling (pre-emptive CFrame anchor + velocity threshold guard, no self-fling)
    - Object / Player Fling (10M rad/s physics exploit)
    - Anti-Object-Kill (shields from high-velocity loose object impacts)
    - Custom Car Driving (VehicleSeat vulnerability scanner + auto-sit)
    - Loose Object Drag (mouse-targeted BodyPosition exploit)
]=]

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local UserInputService= game:GetService("UserInputService")
local Workspace       = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService    = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera: Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

local DisasterSurvival = {
    DisasterTracker   = false,
    CurrentDisaster   = "None (In Lobby)",
    NoFallDamage      = false,
    Flight            = false,
    FlightSpeed       = 50,
    AntiFling         = false,
    FlingMode         = false,
    AntiObjectKill    = false,
    CarDriving        = false,
    ObjectDrag        = false,
}

-- ── Connection handles ────────────────────────────────────────────
local flightConn:       RBXScriptConnection? = nil
local antiFlingConn:    RBXScriptConnection? = nil
local flingConn:        RBXScriptConnection? = nil
local tagConn:          RBXScriptConnection? = nil
local stateConn:        RBXScriptConnection? = nil
local antiKillConn:     RBXScriptConnection? = nil
local carDriveConn:     RBXScriptConnection? = nil
local dragConn:         RBXScriptConnection? = nil
local dragInputConn:    RBXScriptConnection? = nil
local playerAddedConn:  RBXScriptConnection? = nil
local playerRemovingConn: RBXScriptConnection? = nil

-- ── Other player part cache for anti-fling collision bypass ───────
local otherPlayerParts: {[Player]: {BasePart}} = {}
local characterConnections: {[Player]: {RBXScriptConnection}} = {}

local function cleanPlayerConnections(plr: Player)
    local conns = characterConnections[plr]
    if conns then
        for _, conn in ipairs(conns) do pcall(function() conn:Disconnect() end) end
        characterConnections[plr] = nil
    end
    otherPlayerParts[plr] = nil
end

local function cachePlayerParts(plr: Player, char: Model)
    local parts: {BasePart} = {}
    for _, inst in ipairs(char:GetDescendants()) do
        if inst:IsA("BasePart") then
            table.insert(parts, inst)
        end
    end
    otherPlayerParts[plr] = parts

    local conns: {RBXScriptConnection} = {}
    table.insert(conns, char.DescendantAdded:Connect(function(inst)
        if inst:IsA("BasePart") then
            table.insert(parts, inst)
        end
    end))
    table.insert(conns, char.DescendantRemoving:Connect(function(inst)
        if inst:IsA("BasePart") then
            local idx = table.find(parts, inst)
            if idx then table.remove(parts, idx) end
        end
    end))
    characterConnections[plr] = conns
end

local function trackOtherPlayer(plr: Player)
    if plr == LocalPlayer then return end
    if plr.Character then cachePlayerParts(plr, plr.Character) end
    plr.CharacterAdded:Connect(function(char)
        cleanPlayerConnections(plr)
        cachePlayerParts(plr, char)
    end)
    plr.CharacterRemoving:Connect(function()
        cleanPlayerConnections(plr)
    end)
end

-- Initialize tracker
for _, plr in ipairs(Players:GetPlayers()) do trackOtherPlayer(plr) end
playerAddedConn   = Players.PlayerAdded:Connect(trackOtherPlayer)
playerRemovingConn= Players.PlayerRemoving:Connect(cleanPlayerConnections)

-- ── No Fall Damage ────────────────────────────────────────────────
local function applyNoFallDamage(char: Model)
    local fallScript = char:FindFirstChild("FallDamageScript")
    if fallScript then fallScript:Destroy() end
    char.ChildAdded:Connect(function(child)
        if DisasterSurvival.NoFallDamage and child.Name == "FallDamageScript" then
            task.defer(function() child:Destroy() end)
        end
    end)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        if stateConn then stateConn:Disconnect() end
        stateConn = hum.StateChanged:Connect(function(_, newState)
            if not DisasterSurvival.NoFallDamage then return end
            if newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Freefall then
                local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
                if hrp and hrp.AssemblyLinearVelocity.Y < -50 then
                    hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
                end
            end
        end)
    end
end

function DisasterSurvival.setNoFallDamage(enabled: boolean)
    DisasterSurvival.NoFallDamage = enabled
    if enabled and LocalPlayer.Character then applyNoFallDamage(LocalPlayer.Character) end
end

-- ── Disaster Tracker (multi-source) ──────────────────────────────
local function hookDisasterTag(char: Model, notifyCallback: ((string)->())?)
    if tagConn then tagConn:Disconnect() tagConn = nil end

    local function updateDisaster(rawName: string)
        local cleaned = rawName:gsub("^%s+",""):gsub("%s+$","")
        local current = if cleaned ~= "" and cleaned ~= "None" then cleaned else "None (In Lobby)"
        if DisasterSurvival.CurrentDisaster ~= current then
            DisasterSurvival.CurrentDisaster = current
            if notifyCallback and current ~= "None (In Lobby)" then notifyCallback(current) end
        end
    end

    local function checkTag(tag: Instance)
        if tag:IsA("StringValue") and (tag.Name == "SurvivalTag" or tag.Name:find("Disaster")) then
            updateDisaster(tag.Value)
            tag.Changed:Connect(function(v) updateDisaster(v) end)
        end
    end

    local existingTag = char:FindFirstChild("SurvivalTag") or char:FindFirstChild("DisasterTag")
    if existingTag then checkTag(existingTag) else DisasterSurvival.CurrentDisaster = "None (In Lobby)" end
    tagConn = char.ChildAdded:Connect(checkTag)

    pcall(function()
        local rsTag = ReplicatedStorage:FindFirstChild("DisasterName") or ReplicatedStorage:FindFirstChild("CurrentDisaster")
        if rsTag and rsTag:IsA("StringValue") then checkTag(rsTag) end
    end)
end

function DisasterSurvival.init(notifyCallback: ((string)->())?)
    if LocalPlayer.Character then
        if DisasterSurvival.NoFallDamage then applyNoFallDamage(LocalPlayer.Character) end
        hookDisasterTag(LocalPlayer.Character, notifyCallback)
    end
    LocalPlayer.CharacterAdded:Connect(function(char)
        if DisasterSurvival.NoFallDamage then applyNoFallDamage(char) end
        hookDisasterTag(char, notifyCallback)
    end)

    -- Continuously auto-dismiss stuck NDS elevator transition blackout frames
    RunService.RenderStepped:Connect(function()
        local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if pgui then
            local et = pgui:FindFirstChild("Elevator Transition")
            if et and et:IsA("ScreenGui") and et.Enabled then
                local frame = et:FindFirstChild("Frame")
                if frame and frame:IsA("Frame") and frame.BackgroundTransparency < 0.5 then
                    frame.BackgroundTransparency = 1
                    et.Enabled = false
                end
            end
        end
    end)
end

-- ── Flight Engine ─────────────────────────────────────────────────
function DisasterSurvival.setFlight(enabled: boolean)
    DisasterSurvival.Flight = enabled
    if enabled then
        flightConn = RunService.RenderStepped:Connect(function(dt: number)
            local char = LocalPlayer.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if not (hrp and hum) then return end

            hum.PlatformStand = true
            hrp.AssemblyLinearVelocity  = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero

            local move = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up)    then move += Camera.CFrame.LookVector  end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down)  then move -= Camera.CFrame.LookVector  end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left)  then move -= Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then move += Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.E) then move += Vector3.yAxis end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then move -= Vector3.yAxis end

            if move.Magnitude > 0 then
                hrp.CFrame += move.Unit * (DisasterSurvival.FlightSpeed * dt)
            end
        end)
    elseif flightConn then
        flightConn:Disconnect() flightConn = nil
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
            if hum then hum.PlatformStand = false end
            if hrp then hrp.AssemblyLinearVelocity = Vector3.zero hrp.AssemblyAngularVelocity = Vector3.zero end
        end
    end
end

-- ── Anti-Fling (Inertia Hardening & Impulse Absorption) ───────────
-- Neutralizes fling impulses WITHOUT modifying CanCollide:
--  1. Infinite Mass Inertia: CustomPhysicalProperties with max density (100) & zero elasticity (0 bounce)
--  2. Dual-Phase Velocity Clamping: Stepped (pre-solver) and Heartbeat (post-solver)
--  3. Solver Momentum Reset: 1-frame micro-anchor immediately cancels physics solver impulse
--  4. Proximity Kinetic Defuser: Zeros incoming angular and linear velocity of nearby flingers
--  5. Humanoid State Lock: Prevents ragdoll/fallingdown states during collision impact
local antiFlingHeartbeatConn: RBXScriptConnection? = nil
local heavyPhysicalProps = PhysicalProperties.new(100, 1.0, 0, 100, 100)

local function applyHeavyProperties(char: Model, enable: boolean)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            pcall(function()
                if enable then
                    part.CustomPhysicalProperties = heavyPhysicalProps
                else
                    part.CustomPhysicalProperties = nil
                end
            end)
        end
    end
end

function DisasterSurvival.setAntiFling(enabled: boolean)
    DisasterSurvival.AntiFling = enabled
    if enabled then
        local isAnchoring = false
        local char = LocalPlayer.Character
        if char then applyHeavyProperties(char, true) end

        -- Humanoid protection
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                pcall(function()
                    hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                    hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, false)
                end)
            end
        end

        -- Stepped (Pre-Physics Step)
        antiFlingConn = RunService.Stepped:Connect(function()
            local curChar = LocalPlayer.Character
            local hrp = curChar and curChar:FindFirstChild("HumanoidRootPart") :: BasePart?
            local hum = curChar and curChar:FindFirstChildOfClass("Humanoid")
            if not (curChar and hrp and hum and hum.Health > 0) then return end

            local flingOn = DisasterSurvival.FlingMode

            -- 1. Anti-Ragdoll / Sit Recovery
            if not flingOn then
                if hum.Sit then hum.Sit = false end
                local state = hum:GetState()
                if state == Enum.HumanoidStateType.Ragdoll or state == Enum.HumanoidStateType.FallingDown then
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                end
            end

            local linVel = hrp.AssemblyLinearVelocity
            local angVel = hrp.AssemblyAngularVelocity

            -- 2. Pre-physics angular velocity suppression
            if not flingOn and angVel.Magnitude > 15 then
                hrp.AssemblyAngularVelocity = Vector3.zero
            end

            -- 3. Pre-physics horizontal speed clamp
            local horizSpeed = math.sqrt(linVel.X * linVel.X + linVel.Z * linVel.Z)
            if not flingOn and horizSpeed > 60 then
                hrp.AssemblyLinearVelocity = Vector3.new(
                    math.clamp(linVel.X, -28, 28),
                    linVel.Y,
                    math.clamp(linVel.Z, -28, 28)
                )
            end

            -- 4. Proximity Kinetic Defuser for incoming flingers (within 15 studs)
            if not flingOn then
                local myPos = hrp.Position
                for plr, parts in pairs(otherPlayerParts) do
                    if plr ~= LocalPlayer and plr.Character then
                        local oppHrp = plr.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
                        if oppHrp and (oppHrp.Position - myPos).Magnitude < 15 then
                            for _, p in ipairs(parts) do
                                if p.AssemblyAngularVelocity.Magnitude > 30 or p.AssemblyLinearVelocity.Magnitude > 80 then
                                    pcall(function()
                                        p.AssemblyAngularVelocity = Vector3.zero
                                        p.AssemblyLinearVelocity = Vector3.zero
                                    end)
                                end
                            end
                        end
                    end
                end
            end
        end)

        -- Heartbeat (Post-Physics Step)
        antiFlingHeartbeatConn = RunService.Heartbeat:Connect(function()
            local curChar = LocalPlayer.Character
            local hrp = curChar and curChar:FindFirstChild("HumanoidRootPart") :: BasePart?
            local hum = curChar and curChar:FindFirstChildOfClass("Humanoid")
            if not (curChar and hrp and hum and hum.Health > 0) then return end

            local flingOn = DisasterSurvival.FlingMode
            if flingOn then return end

            local linVel = hrp.AssemblyLinearVelocity
            local angVel = hrp.AssemblyAngularVelocity
            local horizSpeed = math.sqrt(linVel.X * linVel.X + linVel.Z * linVel.Z)

            local isSpike = (horizSpeed > 65) or (linVel.Y > 85) or (linVel.Y < -150) or (linVel.Magnitude > 100) or (angVel.Magnitude > 25)
            if isSpike then
                hrp.AssemblyLinearVelocity = Vector3.new(
                    math.clamp(linVel.X, -25, 25),
                    math.clamp(linVel.Y, -45, 30),
                    math.clamp(linVel.Z, -25, 25)
                )
                hrp.AssemblyAngularVelocity = Vector3.zero

                if not isAnchoring then
                    isAnchoring = true
                    task.spawn(function()
                        if hrp and hrp.Parent then
                            hrp.Anchored = true
                            RunService.Heartbeat:Wait()
                            if hrp and hrp.Parent then
                                hrp.Anchored = false
                            end
                        end
                        isAnchoring = false
                    end)
                end
            end
        end)
    else
        if antiFlingConn then antiFlingConn:Disconnect() antiFlingConn = nil end
        if antiFlingHeartbeatConn then antiFlingHeartbeatConn:Disconnect() antiFlingHeartbeatConn = nil end

        local char = LocalPlayer.Character
        if char then
            applyHeavyProperties(char, false)
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                pcall(function()
                    hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
                    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
                    hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, true)
                end)
            end
        end
    end
end

-- ── Anti-Object-Kill ─────────────────────────────────────────────
-- Prevents loose objects (boulders, debris, cars) in NDS from dealing lethal velocity damage.
function DisasterSurvival.setAntiObjectKill(enabled: boolean)
    DisasterSurvival.AntiObjectKill = enabled
    if enabled then
        local function applyNoCollide(targetChar: Model)
            for _, part in ipairs(targetChar:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = false
                end
            end
        end
        local char = LocalPlayer.Character
        if char then applyNoCollide(char) end

        antiKillConn = RunService.Stepped:Connect(function()
            local c = LocalPlayer.Character
            local hrp = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            if not (hrp and hum and hum.Health > 0) then return end

            -- Clamp extreme inbound velocity
            local lv = hrp.AssemblyLinearVelocity
            if lv.Magnitude > 100 then
                hrp.AssemblyLinearVelocity = lv.Unit * math.min(lv.Magnitude, 60)
            end

            -- Prevent death from falling/impact by restoring health if critically low
            if hum.Health < hum.MaxHealth * 0.15 then
                pcall(function()
                    hum.Health = hum.MaxHealth
                end)
            end
        end)
    elseif antiKillConn then
        antiKillConn:Disconnect() antiKillConn = nil
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
end

-- ── Custom Car Driving ────────────────────────────────────────────
-- Enter: "Enter Nearest Car" button teleports HRP onto the VehicleSeat.
-- Roblox proximity detection fires the SeatWeld automatically.
-- Controls while CarDriving toggle is on: W/S = throttle, A/D = steer.
local activeSeat: VehicleSeat? = nil

function DisasterSurvival.scanCars(): {VehicleSeat}
    local found: {VehicleSeat} = {}
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst:IsA("VehicleSeat") then
            table.insert(found, inst :: VehicleSeat)
        end
    end
    return found
end

function DisasterSurvival.sitInCar(seat: VehicleSeat)
    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not (hrp and hum) then return end

    -- Teleport HRP onto the seat surface — Roblox's proximity SeatWeld fires
    -- automatically once the HRP is within range of the VehicleSeat
    local seatCF = seat.CFrame
    local upOffset = seat.Size.Y * 0.5 + 2.5  -- land on top of seat, not inside it
    hrp.CFrame = seatCF * CFrame.new(0, upOffset, 0)

    -- Give Roblox one frame to register proximity and weld character
    task.delay(0.1, function()
        -- If weld didn't fire automatically, force ThrottleFloat so physics registers
        pcall(function() seat.ThrottleFloat = 0 end)
    end)

    activeSeat = seat
end

function DisasterSurvival.exitCar()
    local char = LocalPlayer.Character
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.Jump = true end
    activeSeat = nil
end


function DisasterSurvival.setCarDriving(enabled: boolean)
    DisasterSurvival.CarDriving = enabled
    if enabled then
        carDriveConn = RunService.Heartbeat:Connect(function()
            if not activeSeat then return end
            local char = LocalPlayer.Character
            if not char then return end

            local ws = 0
            local steer = 0
            if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up)    then ws = 1 end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down)  then ws = -1 end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left)  then steer = -1 end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then steer = 1 end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then ws = 0 steer = 0 end

            pcall(function()
                activeSeat.ThrottleFloat = ws
                activeSeat.SteerFloat    = steer
            end)

            -- F to exit car
            if UserInputService:IsKeyDown(Enum.KeyCode.F) then
                DisasterSurvival.exitCar()
            end
        end)
    elseif carDriveConn then
        carDriveConn:Disconnect() carDriveConn = nil
        activeSeat = nil
    end
end


-- ── Loose Object Drag (Network-Owned BodyPosition for Client+Server replication) ─
-- Controls: LMB hold = grab & drag. Release LMB = drop.
--           Mouse Wheel = pull closer / push farther away.
-- Hover: Cyan Highlight on target.  Grab: Orange Highlight on target.
-- Network Authority: SetNetworkOwner(LocalPlayer) is called on grab so the client
--   owns physics simulation → BodyPosition/BodyGyro replicate to server correctly.
local function getMouse(): Mouse?
    local lp = Players.LocalPlayer
    return if lp then lp:GetMouse() else nil
end

local dragTarget:        BasePart? = nil
local dragTargetRot:     CFrame = CFrame.identity
local dragNoCollisions:  {NoCollisionConstraint} = {}
local hoverTarget:       BasePart? = nil
local hoverHL:           Highlight? = nil
local grabHL:            Highlight? = nil
local dragHoverConn:     RBXScriptConnection? = nil
local dragWheelConn:     RBXScriptConnection? = nil
local dragInputConn:     RBXScriptConnection? = nil
local dragEndConn:       RBXScriptConnection? = nil
local dragDepth:         number = 25
local DRAG_MAX_RANGE:    number = 350
local lastDragPos:       Vector3? = nil
local lastDragTime:      number = 0
local throwVelocity:     Vector3 = Vector3.zero

local function clearHover()
    if hoverHL and hoverHL.Parent then
        pcall(function() hoverHL:Destroy() end)
    end
    hoverHL = nil
    hoverTarget = nil
end

local function makeHighlight(parent: Instance, fill: Color3, outline: Color3, fillTrans: number): Highlight
    local hl = Instance.new("Highlight")
    hl.FillColor = fill
    hl.OutlineColor = outline
    hl.FillTransparency = fillTrans
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee = parent
    hl.Parent = parent
    return hl
end

local function isDraggable(part: BasePart): boolean
    if not part or not part:IsA("BasePart") then return false end
    if part.Anchored then return false end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character and part:IsDescendantOf(plr.Character) then return false end
    end
    if part:IsDescendantOf(Workspace.Terrain) then return false end
    if part.Name == "Baseplate" or part.Name == "Terrain" or part.Name == "SpawnLocation" then return false end
    return part:IsDescendantOf(Workspace)
end

local function getTargetFromMouse(): BasePart?
    local m = getMouse()
    if not m then return nil end
    local char = Players.LocalPlayer and Players.LocalPlayer.Character
    local ray = Camera:ScreenPointToRay(m.X, m.Y)
    local params = RaycastParams.new()
    if char then
        params.FilterDescendantsInstances = {char}
    end
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true

    local res = Workspace:Raycast(ray.Origin, ray.Direction * DRAG_MAX_RANGE, params)
    if res and res.Instance and res.Instance:IsA("BasePart") and isDraggable(res.Instance) then
        return res.Instance
    end

    local fallback = m.Target
    if fallback and fallback:IsA("BasePart") and isDraggable(fallback) then
        return fallback
    end

    return nil
end

local function clearDragTarget()
    for _, ncc in ipairs(dragNoCollisions) do
        if ncc and ncc.Parent then
            pcall(function() ncc:Destroy() end)
        end
    end
    table.clear(dragNoCollisions)

    if dragTarget and dragTarget.Parent then
        pcall(function()
            dragTarget.AssemblyLinearVelocity = throwVelocity
            dragTarget.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    if grabHL and grabHL.Parent then
        pcall(function() grabHL:Destroy() end)
    end
    grabHL = nil
    dragTarget = nil
    throwVelocity = Vector3.zero

    if dragEndConn then
        dragEndConn:Disconnect()
        dragEndConn = nil
    end
end

local function grabObject(part: BasePart)
    clearDragTarget()
    clearHover()

    if not isDraggable(part) then return end

    dragTarget = part
    dragTargetRot = part.CFrame - part.Position
    local camPos = Camera.CFrame.Position
    dragDepth = math.clamp((part.Position - camPos).Magnitude, 5, DRAG_MAX_RANGE)
    lastDragPos = part.Position
    lastDragTime = os.clock()
    throwVelocity = Vector3.zero

    -- 1. Free piece from any grounded assembly welds
    pcall(function() part:BreakJoints() end)

    -- 2. Claim network ownership
    pcall(function()
        if type(sethiddenproperty) == "function" then
            sethiddenproperty(part, "NetworkOwnershipRule", Enum.NetworkOwnership.Manual)
        end
        part:SetNetworkOwner(LocalPlayer)
    end)

    -- 3. Prevent self-collision (never pushes or hits player)
    local char = Players.LocalPlayer and Players.LocalPlayer.Character
    if char then
        for _, cPart in ipairs(char:GetDescendants()) do
            if cPart:IsA("BasePart") then
                local ncc = Instance.new("NoCollisionConstraint")
                ncc.Part0 = cPart
                ncc.Part1 = part
                ncc.Parent = part
                table.insert(dragNoCollisions, ncc)
            end
        end
    end

    grabHL = makeHighlight(part, Color3.fromRGB(255, 140, 0), Color3.fromRGB(255, 220, 80), 0.25)

    -- Drop on LMB release
    dragEndConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            clearDragTarget()
        end
    end)
end

function DisasterSurvival.setObjectDrag(enabled: boolean)
    DisasterSurvival.ObjectDrag = enabled
    if enabled then
        dragHoverConn = RunService.RenderStepped:Connect(function(dt)
            if dragTarget and dragTarget.Parent then
                local m = getMouse()
                if m then
                    local ray = Camera:ScreenPointToRay(m.X, m.Y)
                    local targetPos = Camera.CFrame.Position + (ray.Direction * dragDepth)

                    pcall(function()
                        local curPos = dragTarget.Position
                        local delta = targetPos - curPos
                        local vel = if dt > 0.001 then (delta / dt) else Vector3.zero
                        if vel.Magnitude > 450 then vel = vel.Unit * 450 end
                        throwVelocity = vel

                        dragTarget.CFrame = CFrame.new(targetPos) * dragTargetRot
                        dragTarget.AssemblyLinearVelocity = vel
                        dragTarget.AssemblyAngularVelocity = Vector3.zero
                    end)
                end
            else
                if dragTarget and not dragTarget.Parent then
                    clearDragTarget()
                end

                local target = getTargetFromMouse()
                if target then
                    if hoverTarget ~= target then
                        clearHover()
                        hoverTarget = target
                        hoverHL = makeHighlight(target, Color3.fromRGB(0, 220, 255), Color3.fromRGB(255, 255, 255), 0.5)
                    end
                else
                    clearHover()
                end
            end
        end)

        -- Mouse wheel: push/pull distance
        dragWheelConn = UserInputService.InputChanged:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType == Enum.UserInputType.MouseWheel then
                if dragTarget then
                    dragDepth = math.clamp(dragDepth + (input.Position.Z * 6), 4, DRAG_MAX_RANGE)
                end
            end
        end)

        -- LMB: grab hovered object
        dragInputConn = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local target = hoverTarget or getTargetFromMouse()
                if target and target.Parent then
                    grabObject(target)
                end
            end
        end)
    else
        clearDragTarget()
        clearHover()
        if dragHoverConn then dragHoverConn:Disconnect() dragHoverConn = nil end
        if dragWheelConn then dragWheelConn:Disconnect() dragWheelConn = nil end
        if dragInputConn then dragInputConn:Disconnect() dragInputConn = nil end
    end
end

-- ── Player / Object Fling Engine ──────────────────────────────────
-- How it works:
--   1. Spins LOCAL HRP at 10M rad/s so physics engine has angular momentum ready
--   2. PlatformStand = true makes LOCAL player immune to their own spin (no ragdoll)
--   3. Touched events on every local part detect when another player physically hits us
--   4. On touch: explicitly spike the TOUCHING player's HRP angular + linear velocity
-- Local player is NEVER flung by this — only players who walk into you get sent.

local flingTouchedConns: {RBXScriptConnection} = {}

local function getFlingTargetHRP(hit: BasePart): BasePart?
    -- Walk up the hit part's ancestry to find a player character's HRP
    local model = hit:FindFirstAncestorOfClass("Model")
    if not model then return nil end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character == model then
            return model:FindFirstChild("HumanoidRootPart") :: BasePart?
        end
    end
    return nil
end

local function applyFlingToHRP(hrp: BasePart)
    pcall(function()
        hrp.AssemblyAngularVelocity = Vector3.new(
            (math.random(0, 1) == 0 and -1 or 1) * 10000000,
            10000000,
            (math.random(0, 1) == 0 and -1 or 1) * 10000000
        )
        hrp.AssemblyLinearVelocity = Vector3.new(
            math.random(-300, 300),
            900,
            math.random(-300, 300)
        )
    end)
end

local function connectFlingTouched(char: Model)
    for _, conn in ipairs(flingTouchedConns) do pcall(function() conn:Disconnect() end) end
    table.clear(flingTouchedConns)

    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") then
            table.insert(flingTouchedConns, part.Touched:Connect(function(hit)
                if not DisasterSurvival.FlingMode then return end
                if not hit or hit:IsDescendantOf(char) then return end

                -- Fling enemy player characters
                local targetHrp = getFlingTargetHRP(hit)
                if targetHrp then
                    applyFlingToHRP(targetHrp)
                    return
                end

                -- Fling loose disaster objects (unanchored boulders, debris, vehicles)
                if hit:IsA("BasePart") and not hit.Anchored and not hit:FindFirstAncestorOfClass("Tool") then
                    pcall(function()
                        hit.AssemblyLinearVelocity = Vector3.new(
                            math.random(-500, 500),
                            1800,
                            math.random(-500, 500)
                        )
                        hit.AssemblyAngularVelocity = Vector3.new(
                            math.random(-100000, 100000),
                            100000,
                            math.random(-100000, 100000)
                        )
                    end)
                end
            end))
        end
    end
end

function DisasterSurvival.setFling(enabled: boolean)
    DisasterSurvival.FlingMode = enabled
    for _, conn in ipairs(flingTouchedConns) do pcall(function() conn:Disconnect() end) end
    table.clear(flingTouchedConns)

    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local hum  = char and char:FindFirstChildOfClass("Humanoid")

    if enabled then
        -- Prevent ragdoll / tripping without freezing character
        if hum then
            hum.PlatformStand = false
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
            hum:ChangeState(Enum.HumanoidStateType.Running)
        end

        -- Spin local HRP while preserving walk and run velocities so player never gets stuck
        flingConn = RunService.Heartbeat:Connect(function()
            local c   = LocalPlayer.Character
            local r   = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
            local h   = c and c:FindFirstChildOfClass("Humanoid")
            if not (r and h and h.Health > 0) then return end

            h.PlatformStand = false
            if h.Sit then h.Sit = false end

            local moveDir = h.MoveDirection
            local curY = r.AssemblyLinearVelocity.Y
            if moveDir.Magnitude > 0 then
                r.AssemblyLinearVelocity = Vector3.new(moveDir.X * h.WalkSpeed, curY, moveDir.Z * h.WalkSpeed)
            end
            r.AssemblyAngularVelocity = Vector3.new(0, 10000000, 0)
        end)

        if char then connectFlingTouched(char) end

        table.insert(flingTouchedConns, LocalPlayer.CharacterAdded:Connect(function(newChar)
            if DisasterSurvival.FlingMode then
                local newHum = newChar:WaitForChild("Humanoid", 5) :: Humanoid?
                if newHum then
                    newHum.PlatformStand = false
                    newHum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
                    newHum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                end
                connectFlingTouched(newChar)
            end
        end))
    else
        if flingConn then
            flingConn:Disconnect()
            flingConn = nil
        end
        if hum then
            hum.PlatformStand = false
            hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, true)
            hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
        end
        if hrp then
            hrp.AssemblyAngularVelocity = Vector3.zero
        end
    end
end


-- ── Cleanup ───────────────────────────────────────────────────────
function DisasterSurvival.cleanup()
    local function dc(c: RBXScriptConnection?) if c then c:Disconnect() end end
    dc(flightConn)       flightConn = nil
    dc(antiFlingConn)    antiFlingConn = nil
    dc(flingConn)        flingConn = nil
    for _, conn in ipairs(flingTouchedConns) do pcall(function() conn:Disconnect() end) end
    table.clear(flingTouchedConns)
    dc(tagConn)          tagConn = nil
    dc(stateConn)        stateConn = nil
    dc(antiKillConn)     antiKillConn = nil
    dc(carDriveConn)     carDriveConn = nil
    dc(dragHoverConn)    dragHoverConn = nil
    dc(dragWheelConn)    dragWheelConn = nil
    dc(dragInputConn)    dragInputConn = nil
    dc(dragEndConn)      dragEndConn   = nil
    dc(playerAddedConn)  playerAddedConn = nil
    dc(playerRemovingConn) playerRemovingConn = nil

    clearDragTarget()
    clearHover()
    for plr in pairs(characterConnections) do cleanPlayerConnections(plr) end
    table.clear(otherPlayerParts)

    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if hum then hum.PlatformStand = false end
        if hrp then hrp.AssemblyLinearVelocity = Vector3.zero hrp.AssemblyAngularVelocity = Vector3.zero end
    end
end

return DisasterSurvival
