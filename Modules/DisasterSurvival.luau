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
            if DisasterSurvival.AntiFling then inst.CanCollide = false end
        end
    end
    otherPlayerParts[plr] = parts

    local conns: {RBXScriptConnection} = {}
    table.insert(conns, char.DescendantAdded:Connect(function(inst)
        if inst:IsA("BasePart") then
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

            -- Always disable collision with other player characters
            for _, parts in pairs(otherPlayerParts) do
                for _, part in ipairs(parts) do
                    if part and part.Parent then
                        part.CanCollide = false
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


-- ── Loose Object Drag ─────────────────────────────────────────────
-- Controls: LMB hold on part = grab and drag.  Release LMB = drop.
-- Hover: cyan Highlight via Mouse.Target (engine-level, pixel-perfect).
-- Drag: direct AssemblyLinearVelocity push each frame — no BodyPosition,
--       no ownership transfer needed, grab is instant, regrab works fine.
local dragMouse:     Mouse        = LocalPlayer:GetMouse()
local dragTarget:    BasePart?    = nil
local hoverTarget:   BasePart?    = nil
local hoverHL:       Highlight?   = nil
local grabHL:        Highlight?   = nil
local dragHoverConn: RBXScriptConnection? = nil
local dragEndConn:   RBXScriptConnection? = nil
local dragDepth      = 60

-- Track parts whose CanCollide we suppressed during drag so we can restore them
local dragSuppressedParts: {[BasePart]: boolean} = {}

local function clearHover()
    if hoverHL and hoverHL.Parent then hoverHL:Destroy() end
    hoverHL     = nil
    hoverTarget = nil
end

local function suppressDragCollision(part: BasePart)
    -- Collect the root model (or the part itself) and disable collision on all BaseParts
    local root: Instance = part
    if part.Parent and part.Parent:IsA("Model") then
        root = part.Parent
    end
    table.clear(dragSuppressedParts)
    for _, inst in ipairs(root:GetDescendants()) do
        if inst:IsA("BasePart") then
            local bp = inst :: BasePart
            dragSuppressedParts[bp] = bp.CanCollide
            bp.CanCollide = false
        end
    end
    -- Also suppress the part itself
    dragSuppressedParts[part] = part.CanCollide
    part.CanCollide = false
end

local function restoreDragCollision()
    for bp, original in pairs(dragSuppressedParts) do
        if bp and bp.Parent then
            pcall(function() bp.CanCollide = original end)
        end
    end
    table.clear(dragSuppressedParts)
end

local function clearDragTarget()
    -- Zero velocity so part doesn't keep flying after release
    if dragTarget and dragTarget.Parent then
        pcall(function() dragTarget.AssemblyLinearVelocity = Vector3.zero end)
    end
    restoreDragCollision()
    if grabHL and grabHL.Parent then grabHL:Destroy() end
    dragTarget = nil
    grabHL     = nil
    if dragEndConn then dragEndConn:Disconnect() dragEndConn = nil end
end

local function isDraggable(part: BasePart): boolean
    if part.Anchored or part.Locked then return false end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character and part:IsDescendantOf(plr.Character) then return false end
    end
    return part:IsDescendantOf(Workspace)
end

local function makeHighlight(parent: BasePart, fill: Color3, outline: Color3, fillTrans: number): Highlight
    local hl = Instance.new("Highlight")
    hl.FillColor           = fill
    hl.OutlineColor        = outline
    hl.FillTransparency    = fillTrans
    hl.OutlineTransparency = 0
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Adornee             = parent
    hl.Parent              = parent
    return hl
end

local function grabObject(part: BasePart)
    clearDragTarget()
    clearHover()
    dragTarget = part
    -- Disable collision on the object so it can't physically throw the player
    suppressDragCollision(part)
    -- Lock depth at grab distance so part stays at same Z while dragging
    dragDepth = math.clamp((part.Position - Camera.CFrame.Position).Magnitude, 4, 150)
    grabHL = makeHighlight(part, Color3.fromRGB(255, 140, 0), Color3.fromRGB(255, 200, 50), 0.28)
    -- One-shot release listener
    dragEndConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            clearDragTarget()
        end
    end)
end


function DisasterSurvival.setObjectDrag(enabled: boolean)
    DisasterSurvival.ObjectDrag = enabled
    if enabled then
        -- RenderStepped: hover via Mouse.Target + velocity push while dragging
        dragHoverConn = RunService.RenderStepped:Connect(function()
            if dragTarget then
                -- Part may have been destroyed mid-drag
                if not dragTarget.Parent then clearDragTarget() return end

                -- Target world position along camera ray at locked depth
                local ray       = Camera:ScreenPointToRay(dragMouse.X, dragMouse.Y)
                local targetPos = Camera.CFrame.Position + ray.Direction * dragDepth
                local diff      = targetPos - dragTarget.Position
                local dist      = diff.Magnitude

                -- Spring-damper velocity: proportional to distance, damps at close range
                local speed = math.clamp(dist * 14, 0, 100)
                pcall(function()
                    dragTarget.AssemblyLinearVelocity = if dist > 0.05
                        then diff.Unit * speed
                        else Vector3.zero
                end)
            else
                -- Hover: Mouse.Target is engine-resolved, always pixel-accurate
                local target = dragMouse.Target
                if target and target:IsA("BasePart") and isDraggable(target) then
                    if hoverTarget ~= target then
                        clearHover()
                        hoverTarget = target
                        hoverHL = makeHighlight(target,
                            Color3.fromRGB(0, 220, 255),
                            Color3.fromRGB(255, 255, 255),
                            0.52)
                    end
                else
                    clearHover()
                end
            end
        end)

        -- LMB down = grab whatever is currently highlighted
        dragInputConn = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                if hoverTarget and hoverTarget.Parent then
                    grabObject(hoverTarget)
                end
            end
        end)
    else
        clearDragTarget()
        clearHover()
        if dragHoverConn then dragHoverConn:Disconnect() dragHoverConn = nil end
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

-- ── Cleanup ───────────────────────────────────────────────────────
function DisasterSurvival.cleanup()
    local function dc(c: RBXScriptConnection?) if c then c:Disconnect() end end
    dc(flightConn)     flightConn = nil
    dc(antiFlingConn)  antiFlingConn = nil
    dc(flingConn)      flingConn = nil
    dc(tagConn)        tagConn = nil
    dc(stateConn)      stateConn = nil
    dc(antiKillConn)   antiKillConn = nil
    dc(carDriveConn)   carDriveConn = nil
    dc(dragHoverConn)  dragHoverConn = nil
    dc(dragInputConn)  dragInputConn = nil
    dc(dragEndConn)    dragEndConn   = nil
    dc(playerAddedConn) playerAddedConn = nil
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
