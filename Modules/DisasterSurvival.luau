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
        if inst:IsA("BasePart") and not inst:FindFirstAncestorWhichIsA("Tool") and not inst:FindFirstAncestorWhichIsA("Accessory") then
            table.insert(parts, inst)
            if DisasterSurvival.AntiFling then inst.CanCollide = false end
        end
    end
    otherPlayerParts[plr] = parts

    local conns: {RBXScriptConnection} = {}
    table.insert(conns, char.DescendantAdded:Connect(function(inst)
        if inst:IsA("BasePart") and not inst:FindFirstAncestorWhichIsA("Tool") and not inst:FindFirstAncestorWhichIsA("Accessory") then
            table.insert(parts, inst)
            if DisasterSurvival.AntiFling then inst.CanCollide = false end
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

-- ── Anti-Fling (pre-emptive CFrame anchor prevents self-fling) ────
-- When FlingMode is ALSO active, angular velocity is intentionally at
-- 10M rad/s. Anti-fling skips the angular check in that case so the
-- two systems don't fight each other and the player can still walk.
function DisasterSurvival.setAntiFling(enabled: boolean)
    DisasterSurvival.AntiFling = enabled
    if enabled then
        local lastSafeCF: CFrame? = nil
        local lastSafeTime = 0

        antiFlingConn = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
            if not hrp then return end

            local linVel    = hrp.AssemblyLinearVelocity
            local angVel    = hrp.AssemblyAngularVelocity
            local now       = tick()
            local flingOn   = DisasterSurvival.FlingMode

            -- Angular threshold: ignored when FlingMode owns angular velocity
            local angSpike  = if flingOn then false else (angVel.Magnitude > 10)
            local linSpike  = linVel.Magnitude > 60

            -- Record safe position when velocity is normal
            if not linSpike and not angSpike then
                if now - lastSafeTime > 0.25 then
                    lastSafeCF   = hrp.CFrame
                    lastSafeTime = now
                end
            elseif linSpike then
                -- Only snap+zero on LINEAR spikes — don't touch angular when fling is on
                if lastSafeCF then hrp.CFrame = lastSafeCF end
                hrp.AssemblyLinearVelocity = Vector3.zero
                if not flingOn then
                    hrp.AssemblyAngularVelocity = Vector3.zero
                end
            end

            -- Disable collision with other players only when fling mode is OFF
            -- When fling is ON, enemy collision must remain active so touch imparts fling force
            if not flingOn then
                for _, parts in pairs(otherPlayerParts) do
                    for _, part in ipairs(parts) do
                        if part and part.Parent then
                            part.CanCollide = false
                        end
                    end
                end
            end
        end)
    elseif antiFlingConn then
        antiFlingConn:Disconnect() antiFlingConn = nil
        for _, parts in pairs(otherPlayerParts) do
            for _, part in ipairs(parts) do
                if part and part.Parent and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
    end
end

-- ── Anti-Object-Kill ─────────────────────────────────────────────
-- Prevents loose objects (boulders, debris, cars) in NDS from dealing
-- lethal velocity damage.  Works by:
--  1. Setting local character parts to CanCollide = false on Stepped
--     (objects pass through rather than impact)
--  2. Clamping any residual inbound linear velocity from BasePart
--     contacts with the HRP assembly
function DisasterSurvival.setAntiObjectKill(enabled: boolean)
    DisasterSurvival.AntiObjectKill = enabled
    if enabled then
        antiKillConn = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not (hrp and hum and hum.Health > 0) then return end

            -- Prevent object collision on every local part
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = false
                end
            end

            -- Clamp extreme inbound velocity (object impact velocity transfer)
            local lv = hrp.AssemblyLinearVelocity
            if lv.Magnitude > 100 then
                hrp.AssemblyLinearVelocity = lv.Unit * math.min(lv.Magnitude, 60)
            end

            -- Prevent death from falling/impact by restoring health if critically low
            -- (Server health restoration is exploitable via leaderstats remote hooks in NDS)
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
            for _, part in ipairs(char:GetDescendants()) do
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
local dragMouse:         Mouse = LocalPlayer:GetMouse()
local dragTarget:        BasePart? = nil
local dragAttachment0:   Attachment? = nil
local dragAttachment1:   Attachment? = nil
local dragAlignPos:      AlignPosition? = nil
local dragAlignOrient:   AlignOrientation? = nil
local dragNoCollisions:  {NoCollisionConstraint} = {}
local hoverTarget:       BasePart? = nil
local hoverHL:           Highlight? = nil
local grabHL:            Highlight? = nil
local dragHoverConn:     RBXScriptConnection? = nil
local dragWheelConn:     RBXScriptConnection? = nil
local dragInputConn:     RBXScriptConnection? = nil
local dragEndConn:       RBXScriptConnection? = nil
local dragDepth:         number = 30
local DRAG_MAX_RANGE:    number = 300

-- Saved original part properties to restore on drop
local savedPartProperties: {[BasePart]: {
    CanCollide: boolean,
    CustomPhysicalProperties: PhysicalProperties?,
    Massless: boolean
}} = {}

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
    if part.Anchored or part.Locked then return false end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character and part:IsDescendantOf(plr.Character) then return false end
    end
    return part:IsDescendantOf(Workspace)
end

local function getTargetFromMouse(): BasePart?
    local char = LocalPlayer.Character
    local ray = Camera:ScreenPointToRay(dragMouse.X, dragMouse.Y)
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

    local fallback = dragMouse.Target
    if fallback and fallback:IsA("BasePart") and isDraggable(fallback) then
        return fallback
    end

    return nil
end

local function clearDragTarget()
    -- Restore original physical properties
    if dragTarget and dragTarget.Parent then
        local saved = savedPartProperties[dragTarget]
        if saved then
            pcall(function()
                dragTarget.Massless = saved.Massless
                dragTarget.CustomPhysicalProperties = saved.CustomPhysicalProperties
            end)
            savedPartProperties[dragTarget] = nil
        end
        pcall(function()
            dragTarget.AssemblyLinearVelocity = Vector3.zero
            dragTarget.AssemblyAngularVelocity = Vector3.zero
        end)
    end

    -- Cleanup constraints & attachments
    if dragAlignPos and dragAlignPos.Parent then
        pcall(function() dragAlignPos:Destroy() end)
    end
    dragAlignPos = nil

    if dragAlignOrient and dragAlignOrient.Parent then
        pcall(function() dragAlignOrient:Destroy() end)
    end
    dragAlignOrient = nil

    if dragAttachment0 and dragAttachment0.Parent then
        pcall(function() dragAttachment0:Destroy() end)
    end
    dragAttachment0 = nil

    if dragAttachment1 and dragAttachment1.Parent then
        pcall(function() dragAttachment1:Destroy() end)
    end
    dragAttachment1 = nil

    for _, ncc in ipairs(dragNoCollisions) do
        if ncc and ncc.Parent then
            pcall(function() ncc:Destroy() end)
        end
    end
    table.clear(dragNoCollisions)

    if grabHL and grabHL.Parent then
        pcall(function() grabHL:Destroy() end)
    end
    grabHL = nil
    dragTarget = nil

    if dragEndConn then
        dragEndConn:Disconnect()
        dragEndConn = nil
    end
end

local function grabObject(part: BasePart)
    clearDragTarget()
    clearHover()

    dragTarget = part
    local camPos = Camera.CFrame.Position
    dragDepth = math.clamp((part.Position - camPos).Magnitude, 6, DRAG_MAX_RANGE)

    -- Save part state
    savedPartProperties[part] = {
        CanCollide = part.CanCollide,
        CustomPhysicalProperties = part.CustomPhysicalProperties,
        Massless = part.Massless
    }

    -- 1. Make part weightless for zero-inertia effortless movement
    pcall(function()
        part.Massless = true
        part.CustomPhysicalProperties = PhysicalProperties.new(0.001, 0, 0, 0, 0)
        part.AssemblyLinearVelocity = Vector3.zero
        part.AssemblyAngularVelocity = Vector3.zero
    end)

    -- 2. Claim network ownership so movement replicates to server & all players
    pcall(function()
        if type(sethiddenproperty) == "function" then
            sethiddenproperty(part, "NetworkOwnershipRule", Enum.NetworkOwnership.Manual)
        end
        part:SetNetworkOwner(LocalPlayer)
    end)

    -- 3. Prevent self-collision damage
    local char = LocalPlayer.Character
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

    -- 4. Create World Target Attachment in Workspace Terrain
    local targetAtt = Instance.new("Attachment")
    targetAtt.Name = "ModularDragTargetAtt"
    targetAtt.WorldPosition = part.Position
    targetAtt.Parent = Workspace.Terrain
    dragAttachment1 = targetAtt

    -- 5. Create Part Center Attachment
    local partAtt = Instance.new("Attachment")
    partAtt.Name = "ModularDragPartAtt"
    partAtt.Position = Vector3.zero
    partAtt.Parent = part
    dragAttachment0 = partAtt

    -- 6. Hyper-Powered AlignPosition (Instantaneous infinite torque & velocity)
    local ap = Instance.new("AlignPosition")
    ap.Name = "ModularDragAlignPos"
    ap.Mode = Enum.PositionAlignmentMode.TwoAttachment
    ap.Attachment0 = partAtt
    ap.Attachment1 = targetAtt
    ap.MaxForce = math.huge
    ap.MaxVelocity = math.huge
    ap.Responsiveness = 200
    ap.ApplyAtCenterOfMass = true
    ap.Parent = part
    dragAlignPos = ap

    -- 7. AlignOrientation to keep part oriented naturally
    local ao = Instance.new("AlignOrientation")
    ao.Name = "ModularDragAlignOrient"
    ao.Mode = Enum.OrientationAlignmentMode.TwoAttachment
    ao.Attachment0 = partAtt
    ao.Attachment1 = targetAtt
    ao.MaxTorque = math.huge
    ao.MaxAngularVelocity = math.huge
    ao.Responsiveness = 120
    ao.Parent = part
    dragAlignOrient = ao

    grabHL = makeHighlight(part, Color3.fromRGB(255, 140, 0), Color3.fromRGB(255, 220, 80), 0.25)

    -- Drop on release
    dragEndConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            clearDragTarget()
        end
    end)
end

function DisasterSurvival.setObjectDrag(enabled: boolean)
    DisasterSurvival.ObjectDrag = enabled
    if enabled then
        dragHoverConn = RunService.RenderStepped:Connect(function()
            if dragTarget and dragTarget.Parent then
                local ray = Camera:ScreenPointToRay(dragMouse.X, dragMouse.Y)
                local targetPos = Camera.CFrame.Position + (ray.Direction * dragDepth)

                -- 1. Move target attachment
                if dragAttachment1 and dragAttachment1.Parent then
                    dragAttachment1.WorldPosition = targetPos
                end

                -- 2. Direct velocity & CFrame booster (ensures zero drag lag and lifts massive heavy parts)
                pcall(function()
                    local curPos = dragTarget.Position
                    local delta = targetPos - curPos
                    local dist = delta.Magnitude
                    if dist > 0.05 then
                        local speed = math.clamp(dist * 35, 10, 450)
                        dragTarget.AssemblyLinearVelocity = delta.Unit * speed
                    else
                        dragTarget.AssemblyLinearVelocity = Vector3.zero
                    end
                end)
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
                    dragDepth = math.clamp(dragDepth + (input.Position.Z * 6), 5, DRAG_MAX_RANGE)
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
function DisasterSurvival.setFling(enabled: boolean)
    DisasterSurvival.FlingMode = enabled
    if enabled then
        flingConn = RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if not (hrp and hum and hum.Health > 0) then return end
            hrp.AssemblyAngularVelocity = Vector3.new(0, 10000000, 0)
        end)
    elseif flingConn then
        flingConn:Disconnect() flingConn = nil
        local char = LocalPlayer.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if hrp then hrp.AssemblyAngularVelocity = Vector3.zero end
    end
end

-- ── Auto Finish / Bypass Ad & Claim Unanchor Hammer ────────────────
local autoAdConn: RBXScriptConnection? = nil
local unanchorAuraConn: RBXScriptConnection? = nil

function DisasterSurvival.claimAdRewardNow(notifyCb: ((string)->())?): boolean
    local claimed = false
    local bba = Workspace:FindFirstChild("BillboardAd")
    if bba then
        local re = bba:FindFirstChild("RewardEvent")
        if re and re:IsA("RemoteEvent") then
            re:FireServer("PlayRewardAd")
            claimed = true
        end
        local cd = bba:FindFirstChild("AdRewardDisplay") and bba.AdRewardDisplay:FindFirstChild("PlayPart") and bba.AdRewardDisplay.PlayPart:FindFirstChildWhichIsA("ClickDetector")
        if cd and type(fireclickdetector) == "function" then
            pcall(function() fireclickdetector(cd) end)
            claimed = true
        end
    end

    -- Auto-dismiss any core ad popups or video ad guis
    pcall(function()
        local pgui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if pgui then
            for _, g in ipairs(pgui:GetChildren()) do
                if g:IsA("ScreenGui") and (g.Name:lower():find("ad") or g.Name:lower():find("reward")) and g.Name ~= "RTDGui" then
                    g.Enabled = false
                end
            end
        end
    end)

    if claimed and notifyCb then
        notifyCb("Requested reward ad & claimed unanchor hammer tool")
    end
    return claimed
end

function DisasterSurvival.setAutoClaimAd(enabled: boolean, notifyCb: ((string)->())?)
    DisasterSurvival.AutoAdReward = enabled
    if enabled then
        -- Trigger immediately on activate
        DisasterSurvival.claimAdRewardNow(notifyCb)

        autoAdConn = RunService.Heartbeat:Connect(function()
            local bba = Workspace:FindFirstChild("BillboardAd")
            if bba then
                local re = bba:FindFirstChild("RewardEvent")
                if re and re:IsA("RemoteEvent") then
                    pcall(function() re:FireServer("PlayRewardAd") end)
                end
            end
        end)
    elseif autoAdConn then
        autoAdConn:Disconnect()
        autoAdConn = nil
    end
end

-- ── Map & Structure Unanchor Engine ───────────────────────────────
function DisasterSurvival.unanchorAllMap(): number
    local count = 0
    for _, part in ipairs(Workspace:GetDescendants()) do
        if part:IsA("BasePart") and part.Anchored and not part:IsDescendantOf(Workspace.Terrain) then
            local isChar = false
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character and part:IsDescendantOf(p.Character) then isChar = true break end
            end
            if not isChar and part.Position.Y > -50 and part.Size.Magnitude < 400 then
                pcall(function()
                    part.Anchored = false
                    part:BreakJoints()
                    if type(sethiddenproperty) == "function" then
                        sethiddenproperty(part, "NetworkOwnershipRule", Enum.NetworkOwnership.Manual)
                    end
                    part:SetNetworkOwner(LocalPlayer)
                end)
                count += 1
            end
        end
    end
    return count
end

function DisasterSurvival.setUnanchorAura(enabled: boolean)
    DisasterSurvival.UnanchorAura = enabled
    if enabled then
        unanchorAuraConn = RunService.Heartbeat:Connect(function()
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
            if not hrp then return end

            local hrpPos = hrp.Position
            for _, part in ipairs(Workspace:GetDescendants()) do
                if part:IsA("BasePart") and part.Anchored and not part:IsDescendantOf(Workspace.Terrain) then
                    local isChar = false
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p.Character and part:IsDescendantOf(p.Character) then isChar = true break end
                    end
                    if not isChar and (part.Position - hrpPos).Magnitude <= 50 then
                        pcall(function()
                            part.Anchored = false
                            part:BreakJoints()
                            part.AssemblyLinearVelocity = Vector3.new(math.random(-8, 8), 8, math.random(-8, 8))
                            if type(sethiddenproperty) == "function" then
                                sethiddenproperty(part, "NetworkOwnershipRule", Enum.NetworkOwnership.Manual)
                            end
                            part:SetNetworkOwner(LocalPlayer)
                        end)
                    end
                end
            end
        end)
    elseif unanchorAuraConn then
        unanchorAuraConn:Disconnect()
        unanchorAuraConn = nil
    end
end

-- ── Cleanup ───────────────────────────────────────────────────────
function DisasterSurvival.cleanup()
    local function dc(c: RBXScriptConnection?) if c then c:Disconnect() end end
    dc(flightConn)       flightConn = nil
    dc(antiFlingConn)    antiFlingConn = nil
    dc(flingConn)        flingConn = nil
    dc(tagConn)          tagConn = nil
    dc(stateConn)        stateConn = nil
    dc(antiKillConn)     antiKillConn = nil
    dc(carDriveConn)     carDriveConn = nil
    dc(dragHoverConn)    dragHoverConn = nil
    dc(dragWheelConn)    dragWheelConn = nil
    dc(dragInputConn)    dragInputConn = nil
    dc(dragEndConn)      dragEndConn   = nil
    dc(autoAdConn)       autoAdConn    = nil
    dc(unanchorAuraConn) unanchorAuraConn = nil
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
