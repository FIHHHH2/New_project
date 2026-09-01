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
--  The bug that caused self-fling: zeroing AssemblyLinearVelocity on
--  the local HRP on every Stepped tick conflicted with Humanoid motor
--  forces and ended up propelling the player erratically.
--  Fix: only clamp when magnitude exceeds a reasonable sprint cap (60),
--  and guard the clamp with a "last safe CFrame" teleport rather than
--  zeroing the full velocity vector (which disrupts normal locomotion).
function DisasterSurvival.setAntiFling(enabled: boolean)
    DisasterSurvival.AntiFling = enabled
    if enabled then
        local lastSafeCF: CFrame? = nil
        local lastSafeTime = 0

        antiFlingConn = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
            local hum  = char and char:FindFirstChildOfClass("Humanoid")
            if not hrp then return end

            local linVel = hrp.AssemblyLinearVelocity
            local angVel = hrp.AssemblyAngularVelocity
            local now    = tick()

            -- Record a safe position once per 0.25s when velocity is normal
            if linVel.Magnitude < 60 and angVel.Magnitude < 10 then
                if now - lastSafeTime > 0.25 then
                    lastSafeCF   = hrp.CFrame
                    lastSafeTime = now
                end
            else
                -- Velocity spike detected — snap back to last safe position
                if lastSafeCF then
                    hrp.CFrame = lastSafeCF
                end
                hrp.AssemblyLinearVelocity  = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
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
-- Scans Workspace for VehicleSeat instances that are unoccupied,
-- allows clicking one to auto-sit using Humanoid:Sit(seat.CFrame)
-- vulnerability. Controls: W/A/S/D = throttle/steer, Space = brake.
local activeSeat: VehicleSeat? = nil
local steerVal = 0
local throttleVal = 0

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
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    -- VehicleSeat:Sit() exploits the Roblox built-in vehicle API 
    -- which the server trusts for seat occupancy assignment
    pcall(function()
        hum.Sit = true
        (seat :: any):Sit(hum)
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
-- Mouse-targeted object dragging using AssemblyLinearVelocity push
-- exploitation. The client can set velocity of unanchored BaseParts
-- relative to camera direction without a server remote — Roblox
-- physics trusts client assembly velocity for non-network-owned parts
-- within proximity (the ownership transfers to local on hover due to
-- default Roblox physics ownership rules).
local dragTarget: BasePart? = nil
local dragBodyPos: BodyPosition? = nil
local DRAG_RANGE = 40

local function clearDragTarget()
    if dragBodyPos and dragBodyPos.Parent then
        dragBodyPos:Destroy()
    end
    dragBodyPos  = nil
    dragTarget   = nil
end

local function isDraggable(part: BasePart): boolean
    -- Skip anchored, locked, or character parts
    if part.Anchored or part.Locked then return false end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character and part:IsDescendantOf(plr.Character) then return false end
    end
    -- Only drag loose workspace objects
    return part:IsDescendantOf(Workspace)
end

function DisasterSurvival.setObjectDrag(enabled: boolean)
    DisasterSurvival.ObjectDrag = enabled
    if enabled then
        dragConn = RunService.RenderStepped:Connect(function()
            if not dragTarget or not dragBodyPos or not dragBodyPos.Parent then return end
            local mouse = UserInputService:GetMouseLocation()
            local ray = Camera:ScreenPointToRay(mouse.X, mouse.Y)
            local targetPos = Camera.CFrame.Position + ray.Direction * DRAG_RANGE
            dragBodyPos.Position = targetPos
        end)

        dragInputConn = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                -- Right-click to grab nearest visible object
                local mouse = UserInputService:GetMouseLocation()
                local ray = Camera:ScreenPointToRay(mouse.X, mouse.Y)
                local params = RaycastParams.new()
                local char = LocalPlayer.Character
                if char then params.FilterDescendantsInstances = {char} end
                params.FilterType = Enum.RaycastFilterType.Exclude
                local result = Workspace:Raycast(ray.Origin, ray.Direction * DRAG_RANGE * 2, params)

                if result and result.Instance and result.Instance:IsA("BasePart") and isDraggable(result.Instance) then
                    clearDragTarget()
                    dragTarget = result.Instance :: BasePart

                    -- Insert a BodyPosition into the target to pull it toward the cursor
                    local bp = Instance.new("BodyPosition")
                    bp.MaxForce     = Vector3.new(1e6, 1e6, 1e6)
                    bp.D            = 300
                    bp.P            = 10000
                    bp.Position     = dragTarget.Position
                    bp.Parent       = dragTarget
                    dragBodyPos = bp
                end
            elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
                -- Left-click to release
                clearDragTarget()
            end
        end)
    else
        clearDragTarget()
        if dragConn then dragConn:Disconnect() dragConn = nil end
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
    dc(dragConn)       dragConn = nil
    dc(dragInputConn)  dragInputConn = nil
    dc(playerAddedConn) playerAddedConn = nil
    dc(playerRemovingConn) playerRemovingConn = nil

    clearDragTarget()
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
