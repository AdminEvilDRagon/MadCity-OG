local library = loadstring(game:HttpGet("https://pastebin.com/raw/1c08N4c0", true))()
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local flags = {}

---------------------------------------------------------
--NOTIFY SYSTEM (FIXED)
---------------------------------------------------------
local gameEvent = ReplicatedStorage:WaitForChild("Event")

local function Notify(text, delayTime)
    delayTime = delayTime or 2 
    pcall(function()
        firesignal(gameEvent.OnClientEvent, 
            LocalPlayer,
            "Dialogue",
            {
                {
                    Delay = delayTime,
                    Text = tostring(text)
                }
            }
        )
    end)
end

Notify("<Color=Yellow>MadHaax OG Loaded succesfully, enjoy!<Color=/>\nMade by <Color=Red> EvilDragon & <Color=Blue> Kenny", 3)
task.wait(2)
Notify("<Color=White>You can Toggle the UI with RightAlt", 1.5)

---------------------------------------------------------
-- VELOCITY RESET SYSTEM (NEW)
---------------------------------------------------------
local velocityLockActive = false
local velocityLockConn = nil

local function startVelocityLock(duration)
    duration = duration or 0.5
    velocityLockActive = true

    if velocityLockConn then
        velocityLockConn:Disconnect()
        velocityLockConn = nil
    end

    local startTime = tick()
    velocityLockConn = RunService.Heartbeat:Connect(function()
        if not velocityLockActive then return end
        if tick() - startTime > duration then
            velocityLockActive = false
            if velocityLockConn then
                velocityLockConn:Disconnect()
                velocityLockConn = nil
            end
            return
        end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            hrp.Velocity = Vector3.zero
            hrp.RotVelocity = Vector3.zero
        end
    end)
end

local function stopVelocityLock()
    velocityLockActive = false
    if velocityLockConn then
        velocityLockConn:Disconnect()
        velocityLockConn = nil
    end
end

---------------------------------------------------------
-- VEHICLE TELEPORT LOGIC (FIXED HEIST CLIPPING)
---------------------------------------------------------
local function executeVehicleDriveAndTeleport(vehicle, targetCFrame)
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChild("Humanoid")
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    
    if not (humanoid and hrp) then return end

    local seat = vehicle:FindFirstChild("DriveSeat", true) 
        or vehicle:FindFirstChildWhichIsA("VehicleSeat", true) 
        or vehicle:FindFirstChildWhichIsA("Seat", true)

    if seat then
        if seat:IsA("Seat") or seat:IsA("VehicleSeat") then
            pcall(function() seat.Disabled = false end)
        end

        local sitTimer = tick()
        while humanoid.SeatPart ~= seat and (tick() - sitTimer) < 3 do
            character:PivotTo(seat.CFrame * CFrame.new(0, 1, 0))
            if seat:IsA("Seat") or seat:IsA("VehicleSeat") then
                seat:Sit(humanoid)
            else
                humanoid.Sit = true
            end
            task.wait(0.1)
        end

        if humanoid.SeatPart == seat then
            task.wait(0.5) 

            local safeTargetCFrame = targetCFrame + Vector3.new(0, 5, 0)
            vehicle:PivotTo(safeTargetCFrame)
            hrp.CFrame = safeTargetCFrame + Vector3.new(0, 2, 0)

            startVelocityLock(0.8)

            if vehicle.PrimaryPart then
                vehicle.PrimaryPart.Velocity = Vector3.new(0, 0, 0)
                vehicle.PrimaryPart.RotVelocity = Vector3.new(0, 0, 0)
                vehicle.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
                vehicle.PrimaryPart.AssemblyAngularVelocity = Vector3.zero
            end

            task.wait(0.4) 
            humanoid.Sit = false

            task.wait(0.15) 
            local exitPos = safeTargetCFrame.Position + Vector3.new(0, 3, 0)
            character:PivotTo(CFrame.new(exitPos))

            startVelocityLock(0.6)
        else
            Notify("<Color=Red>Fehler:</Color> Konnte nicht ins Auto einsteigen!", 2)
        end
    else
        Notify("<Color=Red>Fehler:</Color> Fahrzeug hat keinen Sitz!", 2)
    end
end

---------------------------------------------------------
-- WEAPON GIVER LOGIC (Standard Seat Persist)
---------------------------------------------------------
local MAX_RUNTIME = 5.0
local EVENT_SPAM_DELAY = 0.05
local wgRunning = false

local S = {
    armed = false,
    lastSeat = nil,
    conn = nil,
    holding = false,
    standTrack = nil,
    standApplied = false,
}

local VEHICLE_CHASSIS_NAMES = {
    CarChassis = true, HelicopterChassis = true, BoatChassis = true,
    BikeChassis = true, PlaneChassis = true, MechChassis = true,
    JetChassis = true, JetskiChassis = true,
}

local function isVehicleModel(model)
    if not model then return end
    for name in pairs(VEHICLE_CHASSIS_NAMES) do
        if model:FindFirstChild(name) then return true end
    end
    if model:FindFirstChild("Chassis") then return true end
    if model:FindFirstChild("FrontLeftWheel") then return true end
    if model:FindFirstChild("Thruster") then return true end
    if model:FindFirstChild("Rotor") then return true end
    if model:FindFirstChild("Propeller") then return true end
    return false
end

local function isRealSeat(sp)
    if not sp then return false end
    if not (sp:IsA("VehicleSeat") or sp:IsA("Seat")) then return false end
    local model = sp
    while model and not model:IsA("Model") do model = model.Parent end
    return isVehicleModel(model)
end

local SEAT_NAMES = {
    DriveSeat = true, DriverSeat = true, PilotSeat = true,
    MechSeat = true, HeliSeat = true, PlaneSeat = true,
    BoatSeat = true, BikeSeat = true, JetSeat = true,
}

local EXCLUDED_SEAT_NAMES = {
    PassengerSeat = true, Passenger = true, Seat = true,
    BackSeat = true, RearSeat = true, GunnerSeat = true,
}

local function isSwatVehicle(vehicleModel)
    if not vehicleModel then return false end
    local settings = vehicleModel:FindFirstChild("Settings")
    if not settings or not settings:IsA("ModuleScript") then return false end

    local ok, src = pcall(function()
        if getsource then return getsource(settings) end
        if getscriptbytecode then return getscriptbytecode(settings) end
        return settings.Source
    end)
    if ok and type(src) == "string" and src:find("SWAT") then
        return true
    end
    return false
end

local function getClosestDriveSeat(character)
    local objectSelection = Workspace:WaitForChild("ObjectSelection", 10)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp or not objectSelection then return nil end

    local candidates = {}
    local function scanFolder(parent)
        for _, child in ipairs(parent:GetChildren()) do
            local isSeat = child:IsA("VehicleSeat") or child:IsA("Seat")
            if isSeat and SEAT_NAMES[child.Name] and not EXCLUDED_SEAT_NAMES[child.Name] then
                if not child.Occupant then
                    local distance = (hrp.Position - child.Position).Magnitude
                    local model = child
                    while model and not model:IsA("Model") do model = model.Parent end
                    table.insert(candidates, {seat = child, dist = distance, model = model})
                end
            end
            if child:IsA("Folder") or child:IsA("Model") then
                scanFolder(child)
            end
        end
    end
    scanFolder(objectSelection)

    table.sort(candidates, function(a, b) return a.dist < b.dist end)
    for _, c in ipairs(candidates) do
        if not isSwatVehicle(c.model) then
            return c.seat, c.dist
        end
    end
    return nil
end

local function killSeatWelds()
    local char = LocalPlayer.Character
    if not char then return end
    for _, c in ipairs(char:GetChildren()) do
        if c:IsA("Weld") or c:IsA("Motor6D") or c:IsA("WeldConstraint") then
            local p1 = c.Part1
            if p1 and (p1:IsA("VehicleSeat") or p1:IsA("Seat")) then
                pcall(function() c.Enabled = false end)
            end
        end
    end
    if S.lastSeat then
        local sw = S.lastSeat:FindFirstChild("SeatWeld")
        if sw then pcall(function() sw.Enabled = false end) end
    end
end

local STAND_ANIM_R15 = "rbxassetid://507766666"
local STAND_ANIM_R6  = "rbxassetid://180435571"

local function applyVisualStand()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return end

    killSeatWelds()

    if S.standTrack and S.standTrack.IsPlaying and S.standApplied then return end

    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        if track.Name ~= "__queStand" then
            pcall(function() track:Stop(0) end)
        end
    end

    local rigType = hum.RigType
    local id = (rigType == Enum.HumanoidRigType.R6) and STAND_ANIM_R6 or STAND_ANIM_R15

    local existing = animator:FindFirstChild("__queStandAnim")
    if existing then existing:Destroy() end

    local anim = Instance.new("Animation")
    anim.Name = "__queStandAnim"
    anim.AnimationId = id
    anim.Parent = animator

    local track = animator:LoadAnimation(anim)
    track.Name = "__queStand"
    track.Priority = Enum.AnimationPriority.Action4
    track.Looped = false
    track:Play(0)

    task.defer(function()
        pcall(function() track:AdjustSpeed(0) end)
    end)

    S.standTrack = track
    S.standApplied = true
end

local function clearVisualStand()
    S.standApplied = false
    if S.standTrack then
        pcall(function() S.standTrack:Stop(0) end)
        S.standTrack = nil
    end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if animator then
        local anim = animator:FindFirstChild("__queStandAnim")
        if anim then anim:Destroy() end
    end
end

local function uprightRoot()
    local char = LocalPlayer.Character
    local root = char and (char.PrimaryPart or char:FindFirstChild("HumanoidRootPart"))
    if not root then return end
    local pos = root.Position
    local cur = root.CFrame
    local lookFlat = Vector3.new(cur.LookVector.X, 0, cur.LookVector.Z)
    if lookFlat.Magnitude < 0.01 then lookFlat = Vector3.new(0, 0, -1) end
    root.CFrame = CFrame.lookAt(pos, pos + lookFlat.Unit)
end

local function startFlagLoop()
    if S.conn then S.conn:Disconnect() S.conn = nil end
    S.armed = false
    S.lastSeat = nil
    S.holding = false
    S.standTrack = nil
    S.standApplied = false

    S.conn = RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        local hum = char and char:WaitForChild("Humanoid", 0.1)
        if not hum then return end

        local sp = hum.SeatPart
        if isRealSeat(sp) and hum.Sit then
            S.lastSeat = sp
            S.armed = true
        end

        if not S.armed then return end

        if not S.lastSeat or not S.lastSeat.Parent then
            S.lastSeat = nil
            S.armed = false
            S.holding = false
            clearVisualStand()
            return
        end

        if hum.Sit == false then
            hum.Sit = true
            pcall(function() S.lastSeat:Sit(hum) end)
        end

        if hum:GetState() ~= Enum.HumanoidStateType.Seated then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Seated) end)
        end

        if S.holding then
            applyVisualStand()
            uprightRoot()
        end
    end)
end

local function stopFlagLoop()
    S.armed = false
    S.lastSeat = nil
    S.holding = false
    clearVisualStand()
    if S.conn then S.conn:Disconnect() S.conn = nil end
end

local function executeSeatPersistTeleport(targetPos)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or not hum then return false end

    local startPos = root.CFrame
    S.holding = false
    startFlagLoop()

    local seat, dist = getClosestDriveSeat(char)
    if not seat then
        stopFlagLoop()
        return false
    end

    pcall(function() seat:Sit(hum) end)

    local t = 0
    while hum.SeatPart ~= seat and t < 2 do
        task.wait(0.1)
        t = t + 0.1
    end

    if hum.SeatPart ~= seat then
        stopFlagLoop()
        return false
    end

    task.wait(0.5)
    hum.Sit = false
    pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
    task.wait(0.2) 

    if startPos then
        char:SetPrimaryPartCFrame(CFrame.new(targetPos))
    end

    startVelocityLock(0.6)
    
    task.wait(0.3)
    stopFlagLoop()
    hum.Sit = false
    pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
    
    startVelocityLock(0.4)
    return true
end

local function findNearestEvent(weaponName, playerPos)
    local objectSelection = Workspace:FindFirstChild("ObjectSelection")
    if not objectSelection then return nil end

    local nearest, nearestDist = nil, math.huge
    for _, obj in ipairs(objectSelection:GetDescendants()) do
        if obj.Name == weaponName then
            local pos
            if obj:IsA("BasePart") then pos = obj.Position
            elseif obj:IsA("Model") and obj.PrimaryPart then pos = obj.PrimaryPart.Position
            elseif obj:IsA("Model") then
                for _, p in ipairs(obj:GetChildren()) do
                    if p:IsA("BasePart") then pos = p.Position break end
                end
            end
            if pos then
                local d = (pos - playerPos).Magnitude
                if d < nearestDist then nearestDist = d; nearest = obj end
            end
        end
    end
    if not nearest then return nil end

    local event
    if nearest:FindFirstChild("Event") then event = nearest.Event
    else
        for _, d in ipairs(nearest:GetDescendants()) do
            if d.Name == "Event" and (d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("BindableEvent")) then
                event = d break
            end
        end
    end
    return event
end

local function fireEvent(event)
    if not event then return end
    pcall(function()
        if event:IsA("RemoteEvent") then event:FireServer()
        elseif event:IsA("RemoteFunction") then event:InvokeServer()
        elseif event:IsA("BindableEvent") then event:Fire() end
    end)
end

local function hasItem(itemName)
    local bp = LocalPlayer:FindFirstChild("Backpack")
    local ch = LocalPlayer.Character
    return (bp and bp:FindFirstChild(itemName)) or (ch and ch:FindFirstChild(itemName))
end

local function selectWeapon(weaponName, targetCoords, itemName)
    if wgRunning then return end
    wgRunning = true

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then wgRunning = false return end

    local savedCFrame = hrp.CFrame
    task.wait(0.15)

    if hasItem(itemName) then
        wgRunning = false
        return
    end

    local success = executeSeatPersistTeleport(targetCoords)
    if not success then
        hrp.CFrame = CFrame.new(targetCoords)
        startVelocityLock(0.5)
    end

    local stop = false
    local startTime = os.clock()

    task.spawn(function()
        while not stop do
            local event = findNearestEvent(itemName, targetCoords)
            fireEvent(event)
            task.wait(EVENT_SPAM_DELAY)
        end
    end)

    while not stop do
        if hasItem(itemName) then
            stop = true
            break
        end
        if os.clock() - startTime >= MAX_RUNTIME then
            stop = true
            break
        end
        task.wait(0.05)
    end

    stop = true
    task.wait(0.1)

    local backSuccess = executeSeatPersistTeleport(savedCFrame.Position)
    if not backSuccess then
        local currentHrP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if currentHrP then 
            currentHrP.CFrame = savedCFrame 
            startVelocityLock(0.5)
        end
    end

    wgRunning = false
end

---------------------------------------------------------
-- UI Creating
---------------------------------------------------------
local mainTab = library:CreateWindow('Main')
local modTab = library:CreateWindow('Modifications')
local teleportTab = library:CreateWindow('Teleports')
local miscTab = library:CreateWindow('Misc')
local trollingTab = library:CreateWindow('Trolling')
local farmingTab = library:CreateWindow('Farming')

---------------------------------------------------------
-- TAB 1: MAIN (Player & Combat) 
---------------------------------------------------------
mainTab:Section('--- Player ---')

local customWalkspeedEnabled = false
local targetWalkspeed = 16

mainTab:Toggle("Custom Walkspeed", {flag = "walkspeed_toggle"}, function(state)
    customWalkspeedEnabled = state
    if not state and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.WalkSpeed = 16 
    end
end)

mainTab:Slider("Speed", {flag = "walkspeed_slider", min = 16, max = 300, default = 50}, function(value)
    targetWalkspeed = value
end)

RunService.RenderStepped:Connect(function()
    if customWalkspeedEnabled and LocalPlayer.Character then
        local humanoid = LocalPlayer.Character:FindFirstChild("Humanoid")
        if humanoid and humanoid.WalkSpeed ~= targetWalkspeed then
            humanoid.WalkSpeed = targetWalkspeed
        end
    end
end)

local flyEnabled = false
local flyControlEnabled = false
local flyConnection
local flySpeed = 50
local ctrl = {f = 0, b = 0, l = 0, r = 0}

local function disableFly()
    if flyConnection then
        flyConnection:Disconnect()
        flyConnection = nil
    end
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.PlatformStand = false
    end
    if LocalPlayer.Character then
        for _, v in pairs(LocalPlayer.Character:GetDescendants()) do
            if v:IsA("BodyGyro") or v:IsA("BodyVelocity") then
                v:Destroy()
            end
        end
    end
end

local function enableFly()
    local character = LocalPlayer.Character
    if not character then return end
    local torso = character:FindFirstChild("UpperTorso") or character:WaitForChild("HumanoidRootPart")
    local bg = Instance.new("BodyGyro", torso)
    bg.P = 9e4
    bg.maxTorque = Vector3.new(9e9, 9e9, 9e9)
    bg.cframe = torso.CFrame

    local bv = Instance.new("BodyVelocity", torso)
    bv.velocity = Vector3.new(0, 0, 0)
    bv.maxForce = Vector3.new(9e9, 9e9, 9e9)

    flyConnection = RunService.RenderStepped:Connect(function()
        if not flyEnabled then return end
        character.Humanoid.PlatformStand = true
        bv.velocity = ((Camera.CFrame.lookVector * (ctrl.f + ctrl.b)) + ((Camera.CFrame * CFrame.new(ctrl.l + ctrl.r, (ctrl.f + ctrl.b) * .2, 0).p) - Camera.CFrame.p)) * flySpeed
        bg.cframe = Camera.CFrame
    end)
end

mainTab:Toggle("Fly [F]", {flag = "fly"}, function(state)
    flyControlEnabled = state 
    if not state then
        flyEnabled = false
        disableFly()
    end
end)

mainTab:Slider('Fly Speed', {flag = "flyspeed", min = 1, max = 600, default = flySpeed}, function(value)
    flySpeed = value
end)

---------------------------------------------------------
-- NOCLIP
---------------------------------------------------------
local noclipControlEnabled = false
local SteppedConnection = nil
local noclipSavedSettings = {}

local function collectCharacterParts()
    local parts = {}
    local character = LocalPlayer.Character
    if character then
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                parts[part] = true
            end
        end
    end
    return parts
end

local function disableNoclip()
    if SteppedConnection then
        SteppedConnection:Disconnect()
        SteppedConnection = nil
    end

    for part, state in pairs(noclipSavedSettings) do
        if part and part.Parent then
            pcall(function()
                part.CanCollide = state.CanCollide
                part.CanTouch = state.CanTouch
            end)
        end
    end
    noclipSavedSettings = {}
end

local function enableNoclip()
    if SteppedConnection then
        SteppedConnection:Disconnect()
        SteppedConnection = nil
    end
    noclipSavedSettings = {}

    local function saveAndDisable(part)
        if not noclipSavedSettings[part] then
            noclipSavedSettings[part] = {
                CanCollide = part.CanCollide,
                CanTouch = part.CanTouch,
            }
        end
        part.CanCollide = false
    end

    SteppedConnection = RunService.Stepped:Connect(function()
        local currentParts = collectCharacterParts()

        for part in pairs(currentParts) do
            if not noclipSavedSettings[part] then
                saveAndDisable(part)
            elseif part.CanCollide then
                part.CanCollide = false
            end
        end

        for part in pairs(noclipSavedSettings) do
            if not part.Parent or not currentParts[part] then
                noclipSavedSettings[part] = nil
            end
        end
    end)
end

mainTab:Toggle("Noclip [N]", {flag = "noclip"}, function(state)
    noclipControlEnabled = state 
    if state then
        enableNoclip()
    else
        disableNoclip()
    end
end)
---------------------------------------------------------
-- Fly+Noclip+Semi Invis Bypassed (Keybind G)
---------------------------------------------------------
local bypassActive = false
local bypassControlEnabled = false
local bypassRunning = false
local bypassArmed = false
local bypassLastSeat = nil
local bypassConn = nil
local bypassFlyConn = nil
local bypassNoclipConn = nil
local bypassBv = nil
local bypassFlying = false
local bypassNoclipState = false
local bypassSavedCollide = nil
local bypassHolding = false
local bypassStandTrack = nil
local bypassStandApplied = false

local function bypassKillSeatWelds()
    local charModel = LocalPlayer.Character
    if not charModel then return end
    for _, c in ipairs(charModel:GetChildren()) do
        if c:IsA("Weld") or c:IsA("Motor6D") or c:IsA("WeldConstraint") then
            local p1 = c.Part1
            if p1 and (p1:IsA("VehicleSeat") or p1:IsA("Seat")) then
                pcall(function() c.Enabled = false end)
            end
        end
    end
    if bypassLastSeat then
        local sw = bypassLastSeat:FindFirstChild("SeatWeld")
        if sw then pcall(function() sw.Enabled = false end) end
    end
end

local function bypassRestoreSeatWelds()
    local charModel = LocalPlayer.Character
    if not charModel then return end
    for _, c in ipairs(charModel:GetChildren()) do
        if c:IsA("Weld") or c:IsA("Motor6D") or c:IsA("WeldConstraint") then
            local p1 = c.Part1
            if p1 and (p1:IsA("VehicleSeat") or p1:IsA("Seat")) then
                pcall(function() c.Enabled = true end)
            end
        end
    end
    if bypassLastSeat then
        local sw = bypassLastSeat:FindFirstChild("SeatWeld")
        if sw then pcall(function() sw.Enabled = true end) end
    end
end

local function bypassApplyVisualStand()
    local charModel = LocalPlayer.Character
    local hum = charModel and charModel:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return end

    bypassKillSeatWelds()
    if bypassStandTrack and bypassStandTrack.IsPlaying and bypassStandApplied then return end

    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        if track.Name ~= "__queStandBypass" then
            pcall(function() track:Stop(0) end)
        end
    end

    local rigType = hum.RigType
    local id = (rigType == Enum.HumanoidRigType.R6) and "rbxassetid://180435571" or "rbxassetid://507766666"

    local existing = animator:FindFirstChild("__queStandAnimBypass")
    if existing then existing:Destroy() end

    local anim = Instance.new("Animation")
    anim.Name = "__queStandAnimBypass"
    anim.AnimationId = id
    anim.Parent = animator

    local track = animator:LoadAnimation(anim)
    track.Name = "__queStandBypass"
    track.Priority = Enum.AnimationPriority.Action4
    track.Looped = false
    track:Play(0)

    task.defer(function()
        pcall(function() track:AdjustSpeed(0) end)
    end)

    bypassStandTrack = track
    bypassStandApplied = true
end

local function bypassClearVisualStand()
    bypassStandApplied = false
    if bypassStandTrack then
        pcall(function() bypassStandTrack:Stop(0) end)
        bypassStandTrack = nil
    end
    local charModel = LocalPlayer.Character
    local hum = charModel and charModel:FindFirstChildOfClass("Humanoid")
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if animator then
        local anim = animator:FindFirstChild("__queStandAnimBypass")
        if anim then anim:Destroy() end
    end
    bypassRestoreSeatWelds()
end

local function bypassUprightRoot()
    local charModel = LocalPlayer.Character
    local root = charModel and (charModel.PrimaryPart or charModel:FindFirstChild("HumanoidRootPart"))
    if not root then return end
    local pos = root.Position
    local cur = root.CFrame
    local lookFlat = Vector3.new(cur.LookVector.X, 0, cur.LookVector.Z)
    if lookFlat.Magnitude < 0.01 then lookFlat = Vector3.new(0, 0, -1) end
    root.CFrame = CFrame.lookAt(pos, pos + lookFlat.Unit)
end

local function startBypassFly()
    if bypassFlying then return end
    local charModel = LocalPlayer.Character
    local root = charModel and (charModel.PrimaryPart or charModel:FindFirstChild("HumanoidRootPart"))
    if not root then return end

    bypassFlying = true
    local bv = Instance.new("BodyVelocity")
    bv.Name = "__queFlyBypass"
    bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bv.Velocity = Vector3.zero
    bv.Parent = root
    bypassBv = bv

    local current = Vector3.zero
    bypassFlyConn = RunService.RenderStepped:Connect(function(dt)
        if not bypassFlying or not bypassBv or not bypassBv.Parent then return end
        local rootNow = charModel and (charModel.PrimaryPart or charModel:FindFirstChild("HumanoidRootPart"))
        if not rootNow then return end

        local spd = flySpeed
        local dir = Vector3.zero
        local look = Camera.CFrame.LookVector
        local right = Camera.CFrame.RightVector
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + look end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - look end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + right end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - right end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end

        local target = (dir.Magnitude > 0) and (dir.Unit * spd) or Vector3.zero
        local a = math.clamp(dt * 12, 0, 1)
        current = current:Lerp(target, a)

        rootNow.AssemblyLinearVelocity = Vector3.zero
        rootNow.Velocity = Vector3.zero
        bypassBv.Velocity = current
    end)
end

local function stopBypassFly()
    bypassFlying = false
    if bypassFlyConn then bypassFlyConn:Disconnect() bypassFlyConn = nil end
    if bypassBv and bypassBv.Parent then bypassBv:Destroy() bypassBv = nil end
end

local function setBypassNoclip(on)
    if on == bypassNoclipState then return end
    bypassNoclipState = on
    local charModel = LocalPlayer.Character

    if on then
        bypassSavedCollide = {}
        if charModel then
            for _, p in ipairs(charModel:GetDescendants()) do
                if p:IsA("BasePart") then bypassSavedCollide[p] = p.CanCollide end
            end
        end
        if bypassNoclipConn then bypassNoclipConn:Disconnect() bypassNoclipConn = nil end
        bypassNoclipConn = RunService.Stepped:Connect(function()
            if not bypassNoclipState then return end
            local c = LocalPlayer.Character
            if c then
                for _, p in ipairs(c:GetDescendants()) do
                    if p:IsA("BasePart") then
                        if bypassSavedCollide[p] == nil then bypassSavedCollide[p] = p.CanCollide end
                        p.CanCollide = false
                    end
                end
            end
        end)
    else
        if bypassNoclipConn then bypassNoclipConn:Disconnect() bypassNoclipConn = nil end
        if charModel and bypassSavedCollide then
            for part, val in pairs(bypassSavedCollide) do
                if part and part.Parent then pcall(function() part.CanCollide = val end) end
            end
        end
        bypassSavedCollide = nil
    end
end

local function startBypassFlagLoop()
    if bypassConn then bypassConn:Disconnect() bypassConn = nil end
    bypassArmed = false
    bypassLastSeat = nil
    bypassHolding = false
    bypassClearVisualStand()

    bypassConn = RunService.Heartbeat:Connect(function()
        local charModel = LocalPlayer.Character
        local hum = charModel and charModel:FindFirstChildOfClass("Humanoid")
        if not hum then return end

        local sp = hum.SeatPart
        if isRealSeat(sp) and hum.Sit then
            bypassLastSeat = sp
            bypassArmed = true
        end

        if not bypassArmed then return end
        if not bypassLastSeat or not bypassLastSeat.Parent then
            bypassLastSeat = nil
            bypassArmed = false
            bypassHolding = false
            bypassClearVisualStand()
            return
        end

        if hum.Sit == false then
            hum.Sit = true
            pcall(function() bypassLastSeat:Sit(hum) end)
        end

        if hum:GetState() ~= Enum.HumanoidStateType.Seated then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Seated) end)
        end

        if bypassHolding then
            bypassApplyVisualStand()
            bypassUprightRoot()
        end
    end)
end

local function stopBypassFlagLoop()
    bypassArmed = false
    bypassLastSeat = nil
    bypassHolding = false
    bypassClearVisualStand()
    if bypassConn then bypassConn:Disconnect() bypassConn = nil end
end

local function executeBypassStart()
    if bypassRunning then return end
    bypassRunning = true
    task.spawn(function()
        local charModel = LocalPlayer.Character
        local hum = charModel and charModel:FindFirstChildOfClass("Humanoid")
        local root = charModel and charModel:FindFirstChild("HumanoidRootPart")
        if not (hum and root) then bypassRunning = false return end

        local startPos = root.CFrame
        bypassHolding = false
        startBypassFlagLoop()

        local seat, _ = getClosestDriveSeat(charModel)
        if not seat then
            stopBypassFlagLoop()
            bypassRunning = false
            return
        end

        pcall(function() seat:Sit(hum) end)
        local t = 0
        while hum.SeatPart ~= seat and t < 2 do
            task.wait(0.1)
            t = t + 0.1
        end

        if hum.SeatPart ~= seat then
            stopBypassFlagLoop()
            bypassRunning = false
            return
        end

        task.wait(0.5)
        hum.Sit = false
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        task.wait(0.2)

        if startPos then
            charModel:SetPrimaryPartCFrame(startPos)
        end
        task.wait(0.1)

        bypassHolding = true
        startBypassFly()
        setBypassNoclip(true)
        bypassRunning = false
    end)
end

local function executeBypassStop()
    bypassRunning = false
    bypassHolding = false
    stopBypassFlagLoop()
    stopBypassFly()
    setBypassNoclip(false)

    local charModel = LocalPlayer.Character
    local hum = charModel and charModel:FindFirstChildOfClass("Humanoid")
    if hum then
        if hum.Sit then
            hum.Sit = false
            task.wait(0.05)
        end
        hum.Jump = true
    end
end

mainTab:Toggle("God Mode [G]", {flag = "fly_noclip_semi_invis_bypassed"}, function(state)
    bypassControlEnabled = state
    if not state then
        executeBypassStop()
    end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    if input.KeyCode == Enum.KeyCode.F and flyControlEnabled then
        flyEnabled = not flyEnabled
        if flyEnabled then enableFly() else disableFly() end
    elseif flyEnabled then
        if input.KeyCode == Enum.KeyCode.W then ctrl.f = 1
        elseif input.KeyCode == Enum.KeyCode.S then ctrl.b = -1
        elseif input.KeyCode == Enum.KeyCode.A then ctrl.l = -1
        elseif input.KeyCode == Enum.KeyCode.D then ctrl.r = 1 end
    end
    
    if input.KeyCode == Enum.KeyCode.N and noclipControlEnabled then
        noclipEnabled = not noclipEnabled
        if noclipEnabled then enableNoclip() else disableNoclip() end
    end

    if input.KeyCode == Enum.KeyCode.G and bypassControlEnabled then
        if not bypassHolding then
            executeBypassStart()
        else
            executeBypassStop()
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if flyEnabled then
        if input.KeyCode == Enum.KeyCode.W then ctrl.f = 0
        elseif input.KeyCode == Enum.KeyCode.S then ctrl.b = 0
        elseif input.KeyCode == Enum.KeyCode.A then ctrl.l = 0
        elseif input.KeyCode == Enum.KeyCode.D then ctrl.r = 0 end
    end
end)

mainTab:Section('--- Combat ---')

mainTab:Toggle('Super Ultra Guns', {
    location = flags, 
    flag = "superGuns"
})

local WeaponCore = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WeaponCore"))
if setreadonly then 
    setreadonly(WeaponCore, false) 
elseif make_writeable then 
    make_writeable(WeaponCore) 
end

local Crosshair = LocalPlayer.PlayerGui:WaitForChild("CrosshairGUI"):WaitForChild("Center")
local WeaponHUD = LocalPlayer.PlayerGui:WaitForChild("MainGUI").StatsHUD.WeaponHUD
local Ammo1 = WeaponHUD.Ammo:WaitForChild("Ammo1")
local Ammo2 = WeaponHUD.Ammo:WaitForChild("Ammo2")

local mouseDown = false
local oldWeaponCore = {}
for k, v in pairs(WeaponCore) do 
    oldWeaponCore[k] = v 
end

UserInputService.InputBegan:Connect(function(input, processed) 
    if input.UserInputType == Enum.UserInputType.MouseButton1 then mouseDown = true end 
end)
UserInputService.InputEnded:Connect(function(input) 
    if input.UserInputType == Enum.UserInputType.MouseButton1 then mouseDown = false end 
end)

local function isMouseDown() 
    return mouseDown or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) 
end

local function GetMousePoint(x, y)
    local ignore = {Workspace.Ignore, LocalPlayer.Character, Workspace.Water}
    for _, p in pairs(Players:GetPlayers()) do 
        if p.Character then table.insert(ignore, p.Character) end 
    end
    local ray = Camera:ScreenPointToRay(x, y)
    local _, pos = Workspace:FindPartOnRayWithIgnoreList(Ray.new(ray.Origin, ray.Direction * 2000), ignore, false, true)
    return pos
end

local function setInfinite()
    if flags.superGuns then
        if Ammo1.Text ~= "Inf" then Ammo1.Text = "Inf" end
        if Ammo2.Text ~= "Inf" then Ammo2.Text = "Inf" end
    end
end

local function resetUpvalues()
    pcall(function()
        if getreg and getupvalues and debug.setupvalue then
            for _, fn in pairs(getreg()) do
                if type(fn) == "function" then
                    for k, _ in pairs(getupvalues(fn)) do
                        if k == "Ammo" or k == "Clip" then 
                            debug.setupvalue(fn, k, math.huge)
                        elseif k == "Db" then 
                            debug.setupvalue(fn, k, false) 
                        end
                    end
                end
            end
        end
    end)
end

local function customShootGun(...)
    if not flags.superGuns then 
        if oldWeaponCore.ShootGun then return oldWeaponCore.ShootGun(...) end
        return
    end

    local args = { ... }
    local character = args[1] or LocalPlayer.Character
    resetUpvalues()

    repeat
        local targetPos = GetMousePoint(Crosshair.AbsolutePosition.X, Crosshair.AbsolutePosition.Y)
        args[3] = targetPos
        args[6] = 0

        if oldWeaponCore.ShootGun then pcall(function() oldWeaponCore.ShootGun(unpack(args)) end) end

        RunService.Heartbeat:Wait()
    until not isMouseDown()
end

local replaced = pcall(function() WeaponCore.ShootGun = customShootGun end)
if not replaced and hookfunction and oldWeaponCore.ShootGun then
    local orig = hookfunction(oldWeaponCore.ShootGun, customShootGun)
    oldWeaponCore.ShootGun = orig
end

Ammo1:GetPropertyChangedSignal("Text"):Connect(setInfinite)
Ammo2:GetPropertyChangedSignal("Text"):Connect(setInfinite)

--ESP
mainTab:Section('--- Player ESP ---')

local ESPSettings = {
    Enabled = false,
    Tracers = false,
    Distance = false,
    Health = false,
    Chams = false,
    Outline = false,
    TextSize = 14,
    TextFont = Enum.Font.GothamBlack,
    MaxDistance = 5000,
    RefreshRateMS = 20,
    FilteredTeams = {
        ["Criminals"] = true,
        ["Heroes"] = true,
        ["Police"] = true,
        ["Prisoners"] = true,
        ["Villains"] = true,
        ["Neutral"] = true,
    },
    TeamColors = {
        ["Criminals"] = Color3.fromRGB(196, 40, 28),
        ["Heroes"] = Color3.fromRGB(245, 205, 48),
        ["Neutral"] = Color3.fromRGB(242, 243, 243),
        ["Police"] = Color3.fromRGB(13, 105, 172),
        ["Prisoners"] = Color3.fromRGB(218, 133, 65),
        ["Villains"] = Color3.fromRGB(107, 50, 124)
    }
}

local ESP_Cache = {}
local CoreGui = game:GetService("CoreGui")

if CoreGui:FindFirstChild("MadCity_PlayerESP") then
    CoreGui.MadCity_PlayerESP:Destroy()
end

local PlayerESPContainer = Instance.new("ScreenGui")
PlayerESPContainer.Name = "MadCity_PlayerESP"
PlayerESPContainer.IgnoreGuiInset = true
PlayerESPContainer.Parent = CoreGui

local function applyHighlight(char)
    if not char then return end
    local h = char:FindFirstChild("ESPHighlight")
    if not h then
        h = Instance.new("Highlight")
        h.Name = "ESPHighlight"
        h.Parent = char
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Enabled = false
    end
end

local function createPlayerESP(player)
    if player == LocalPlayer then return end
    
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Size = UDim2.new(0, 1, 0, 1)
    label.Font = ESPSettings.TextFont
    label.TextSize = ESPSettings.TextSize
    label.Visible = false
    label.Parent = PlayerESPContainer

    local tracer = Drawing.new("Line")
    tracer.Thickness = 1
    tracer.Visible = false
    
    ESP_Cache[player] = {
        Label = label,
        Tracer = tracer,
        LastText = "",
        LastColor = nil,
        LastTextSize = ESPSettings.TextSize,
        LastHighlightState = {}
    }

    player.CharacterAdded:Connect(applyHighlight)
    if player.Character then applyHighlight(player.Character) end
end

local function removePlayerESP(player)
    if ESP_Cache[player] then
        ESP_Cache[player].Label:Destroy()
        ESP_Cache[player].Tracer:Remove()
        ESP_Cache[player] = nil
    end
end

for _, p in pairs(Players:GetPlayers()) do createPlayerESP(p) end
Players.PlayerAdded:Connect(createPlayerESP)
Players.PlayerRemoving:Connect(removePlayerESP)

local lastPlayerUpdate = 0
RunService.Heartbeat:Connect(function()
    if not ESPSettings.Enabled then return end    
    local now = os.clock()
    if now - lastPlayerUpdate < (ESPSettings.RefreshRateMS / 1000) then return end
    lastPlayerUpdate = now

    local cameraCF = workspace.CurrentCamera.CFrame.Position
    local viewportSize = workspace.CurrentCamera.ViewportSize
    
    for player, obj in pairs(ESP_Cache) do
        local char = player.Character
        local head = char and char:FindFirstChild("Head")
        local hum = char and char:FindFirstChildOfClass("Humanoid")

        if head and hum and hum.Health > 0 then
            local worldPos = head.Position + Vector3.new(0, 2, 0)
            local screenPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(worldPos)
            
            if onScreen then
                local magnitude = (cameraCF - head.Position).Magnitude
                
                if magnitude <= ESPSettings.MaxDistance then
                    local team = player.Team and player.Team.Name or "Neutral"

                    if not ESPSettings.FilteredTeams[team] then
                        obj.Label.Visible = false
                        obj.Tracer.Visible = false
                        continue
                    end

                    local color = ESPSettings.TeamColors[team] or ESPSettings.TeamColors["Neutral"]
                    local newText = player.Name
                    
                    if ESPSettings.Distance then newText = newText .. " [" .. math.floor(magnitude * 0.28) .. "m]" end
                    if ESPSettings.Health then newText = newText .. " [" .. math.floor(hum.Health) .. " HP]" end
                    
                    if obj.LastText ~= newText then
                        obj.Label.Text = newText
                        obj.LastText = newText
                    end
                    
                    if obj.LastColor ~= color then
                        obj.Label.TextColor3 = color
                        obj.LastColor = color
                    end
                    
                    obj.Label.TextSize = ESPSettings.TextSize
                    obj.Label.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y)
                    obj.Label.Visible = true

                    local h = char:FindFirstChild("ESPHighlight")
                    if h then
                        local newState = {
                            enabled = true,
                            fillTrans = ESPSettings.Chams and 0.5 or 1,
                            outlineTrans = ESPSettings.Outline and 0 or 1
                        }
                        
                        if obj.LastHighlightState.enabled ~= newState.enabled or
                            obj.LastHighlightState.fillTrans ~= newState.fillTrans or
                            obj.LastHighlightState.outlineTrans ~= newState.outlineTrans or
                            h.FillColor ~= color then
                            
                            h.Enabled = true
                            h.FillColor = color
                            h.FillTransparency = newState.fillTrans
                            h.OutlineColor = Color3.new(1, 1, 1)
                            h.OutlineTransparency = newState.outlineTrans
                            obj.LastHighlightState = newState
                        end
                    end

                    if ESPSettings.Tracers then
                        obj.Tracer.Color = color
                        obj.Tracer.From = Vector2.new(viewportSize.X / 2, viewportSize.Y)
                        obj.Tracer.To = Vector2.new(screenPos.X, screenPos.Y + 10)
                        obj.Tracer.Visible = true
                    else
                        obj.Tracer.Visible = false
                    end
                    continue
                end
            end
        end
        
        obj.Label.Visible = false
        obj.Tracer.Visible = false
        if char then
            local h = char:FindFirstChild("ESPHighlight")
            if h and h.Enabled then
                h.Enabled = false
                obj.LastHighlightState = {}
            end
        end
    end
end)

mainTab:Toggle("Enable Player ESP", {location = flags, flag = "esp_enabled"}, function(state)
    ESPSettings.Enabled = state 
    if not state then
        for _, obj in pairs(ESP_Cache) do
            obj.Label.Visible = false
            obj.Tracer.Visible = false
        end
    end
end)

mainTab:Toggle("ESP Tracers", {location = flags, flag = "esp_tracers"}, function(state)
    ESPSettings.Tracers = state
end)

mainTab:Toggle("ESP Distance", {location = flags, flag = "esp_distance"}, function(state)
    ESPSettings.Distance = state
end)

mainTab:Toggle("ESP Health", {location = flags, flag = "esp_health"}, function(state)
    ESPSettings.Health = state
end)

mainTab:Toggle("ESP Chams", {location = flags, flag = "esp_chams"}, function(state)
    ESPSettings.Chams = state
end)

mainTab:Toggle("ESP Outlines", {location = flags, flag = "esp_outlines"}, function(state)
    ESPSettings.Outline = state
end)

mainTab:Slider("Nametag Size", {
    location = flags,
    flag = "esp_text_size",
    min = 5,
    max = 30,
    default = ESPSettings.TextSize
}, function(value)
    ESPSettings.TextSize = value
end)

mainTab:Slider("Refresh Rate", {
    location = flags,
    flag = "esp_refresh",
    min = 0,
    max = 100,
    default = ESPSettings.RefreshRateMS
}, function(value)
    ESPSettings.RefreshRateMS = value
end)

mainTab:Slider("Max Distance", {
    location = flags,
    flag = "esp_max_dist",
    min = 100,
    max = 5000,
    default = math.floor(ESPSettings.MaxDistance * 0.28)
}, function(value)
    ESPSettings.MaxDistance = math.floor(value / 0.28)
end)

---------------------------------------------------------
-- TAB 2: MODIFICATIONS (Vehicles)
---------------------------------------------------------
modTab:Section('--- Vehicle Mods ---')

modTab:Toggle('Inf. Nitro', {
    location = flags, 
    flag = "infGas"
})

task.spawn(function()
    while true do
        task.wait(1)
        if flags.infGas then
            local refillTrigger = Workspace:FindFirstChild("City")
                and Workspace.City:FindFirstChild("GasStation")
                and Workspace.City.GasStation:FindFirstChild("RefillGas")
                and Workspace.City.GasStation.RefillGas:FindFirstChild("Trigger")
                
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local seat = hum and hum.SeatPart
            
            if seat and refillTrigger and firetouchinterest then
                local vehiclePart = (seat.Parent and seat.Parent.PrimaryPart) or seat
                firetouchinterest(vehiclePart, refillTrigger, 0)
                task.wait(0.05)
                firetouchinterest(vehiclePart, refillTrigger, 1)
            end
        end
    end
end)

modTab:Toggle("Hover Mode", {
    location = flags,
    flag = "hoverMode"
}, function(state)
    local vehicle = Workspace:FindFirstChild("ObjectSelection") and Workspace.ObjectSelection:FindFirstChild(LocalPlayer.Name .. "'s Vehicle")
    if vehicle and vehicle:FindFirstChild("CarChassis") then
        local event = vehicle.CarChassis:FindFirstChild("Event")
        if event then
            event:FireServer("HoverMode", state)
        end
    end
end)

modTab:Button('Super Car', function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/AdminEvilDRagon/carmod/refs/heads/main/cmd", true))()
    Notify("Go out and jump back into you vehicle", 2)
end)

modTab:Button('Super Flyer', function()
    local function ModifyCar()
        local Car = Workspace:FindFirstChild("ObjectSelection") and Workspace.ObjectSelection:FindFirstChild(LocalPlayer.Name.."'s Vehicle")
        if Car and Car:FindFirstChild("Settings") then
            local Settings = require(Car:FindFirstChild("Settings"))
            Settings.Bounce = 100
            Settings.Height = 3.5
            Settings.Suspension = 15
            Settings.TurnSpeed = 1.7
            Settings.Sway = 15
            Settings.Torque = 7
            Settings.MaxSpeed = 750
            Settings.BrakeForce = 0.2
            Settings.SpeedDecay = 0.75
            Settings.Boost = true
            Settings.BoostParticles = "LeftRight"
            Settings.Drift = true
            Settings.VelLerp = 0.1
            Settings.RotLerp = 0.075
            Settings.DriftVelLerp = 0.05
            Settings.DriftRotLerp = 0.1
            Settings.HideCharacter = true
            Settings.CameraOffset = 26
        end
    end
    
    if Workspace:FindFirstChild("ObjectSelection") then
        Workspace.ObjectSelection.ChildAdded:Connect(function(Child)
            if Child.Name == LocalPlayer.Name.."'s Vehicle" then
                ModifyCar()
            end
        end)
    end
    ModifyCar()
    Notify("Go out and jump back into you vehicle", 2)
end)

modTab:Button('Super Tank (S.2)', function()
    UserInputService.InputBegan:Connect(function(Key, processed)
        if processed then return end
        if Key.KeyCode == Enum.KeyCode.F then
            local char = LocalPlayer.Character
            local car = char and char:FindFirstChild("Humanoid") and char.Humanoid.SeatPart
            if car and car.Parent:FindFirstChild("Body") and car.Parent:FindFirstChild("Body"):FindFirstChild("Tip") then
                car = car.Parent
                require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WeaponCore")).ShootTank(char, char, car:WaitForChild("Body"), car:WaitForChild("Body").Tip.CFrame)
            end
        end
    end)
end)

---------------------------------------------------------
-- TAB 3: TELEPORTS
---------------------------------------------------------
teleportTab:Section('--- Teleport Method ---')

teleportTab:Dropdown('Method', {
    location = flags,
    flag = 'tpMethod',
    list = {
        "Normal",
        "Respawn",
        "Seat Persist",
    }
})

local function tpNormal(targetCFrame)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not (hum and hrp) then return false end

    if hum.Sit and hum.SeatPart then
        pcall(function() hum.SeatPart:Sit(nil) end)
        hum.Sit = false
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
        task.wait(0.15)
    end

    for i = 1, 5 do
        hrp.CFrame = targetCFrame
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.Velocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.RotVelocity = Vector3.zero
        task.wait(0.03)
    end
    return true
end

local function tpRespawn(targetCFrame)
    local TARGET_POSITION = targetCFrame.Position
    local TELEPORT_COUNT = 10
    local TELEPORT_DELAY = 0.05
    local hasTeleported = false

    local connection
    connection = LocalPlayer.CharacterAdded:Connect(function(character)
        if not hasTeleported then
            hasTeleported = true
            if connection then
                connection:Disconnect()
            end
            
            local rootPart = character:WaitForChild("HumanoidRootPart")
            startVelocityLock(0.8)
            for i = 1, TELEPORT_COUNT do
                rootPart.CFrame = CFrame.new(TARGET_POSITION)
                rootPart.AssemblyLinearVelocity = Vector3.zero
                rootPart.Velocity = Vector3.zero
                rootPart.AssemblyAngularVelocity = Vector3.zero
                rootPart.RotVelocity = Vector3.zero
                task.wait(TELEPORT_DELAY)
            end
            startVelocityLock(0.4)
        end
    end)

    task.spawn(function()
        local teamName = LocalPlayer.Team and LocalPlayer.Team.Name or ""
        local Event = ReplicatedStorage:FindFirstChild("RemoteFunction")

        if Event then
            if teamName == "Criminals" then
                Event:InvokeServer("SetTeam", "Prisoners")
            elseif teamName == "Heroes" then
                Event:InvokeServer("SetTeam", "Heroes")
            elseif teamName == "Police" then
                Event:InvokeServer("SetTeam", "Police")
            elseif teamName == "Prisoners" then
                Event:InvokeServer("SetTeam", "Prisoners")
            else
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.Health = 0
                end
            end
        end
    end)

    return true
end

local function tpSeatPersist(targetCFrame)
    return executeSeatPersistTeleport(targetCFrame.Position)
end

local function doTeleportWithMethod(method, targetCFrame)
    method = method or "Normal"
    startVelocityLock(0.5)
    local result
    if method == "Seat Persist" then
        result = tpSeatPersist(targetCFrame)
    elseif method == "Respawn" then
        result = tpRespawn(targetCFrame)
    else
        result = tpNormal(targetCFrame)
    end
    startVelocityLock(0.5)
    return result
end

teleportTab:Section('--- Place Teleports ---')

local teleportLocations = {
    ["In Prison"] = CFrame.new(-1048.11, 53.67, -3085.44),
    ["Outside Prison"] = CFrame.new(-890.40, 53.57, -2671.90),
    ["Inside Police Station"] = CFrame.new(-962.43, 53.47, -2955.52),
    ["Airport"] = CFrame.new(-2114.43, 29.84, -1155.65),
    ["Gun Store"] = CFrame.new(-1641.56, 43.18, 686.17),
    ["Hero Base"] = CFrame.new(-1753.00, 76.08, 1604.66),
    ["In Crime Base"] = CFrame.new(2138.39, 25.69, 376.61),
    ["Outside Crime Base"] = CFrame.new(2082.39, 25.66, 356.27),
    ["Inside Casino"] = CFrame.new(1682.04, 30.28, 486.17),
    ["Outside Casino"] = CFrame.new(1788.61, 26.10, 685.85),
    ["Inside Club"] = CFrame.new(1350.60, 144.56, -51.54),
    ["Outside Club"] = CFrame.new(1285.22, 25.78, 35.10),
    ["Inside Bank"] = CFrame.new(675.95, 1.46, 503.81),
    ["Outside Bank"] = CFrame.new(697.15, 25.84, 441.46),
    ["Inside Jewelery"] = CFrame.new(-210.46, 25.11, 758.74),
    ["Outside Jewelery"] = CFrame.new(-209.48, 24.89, 719.63),
    ["Vehicle Shop"] = CFrame.new(215.34, 26.00, -586.76),
    ["Outside House 1"] = CFrame.new(1432.63, 37.24, -1236.28),
    ["Inside House 1"] = CFrame.new(1410.82, 36.73, -1181.55),
    ["Outside House 2"] = CFrame.new(1581.39, 25.51, 1577.70),
    ["Inside House 2"] = CFrame.new(1601.85, 24.97, 1620.59),
    ["Cluckdonalds"] = CFrame.new(1308.40, 24.73, 627.20),
    ["Coffe Shop"] = CFrame.new(695.83, 36.18, -117.32)
}

local locationNames = {
    "In Prison",
    "Outside Prison",
    "Inside Police Station",
    "Airport",
    "Gun Store",
    "Hero Base",
    "In Crime Base",
    "Outside Crime Base",
    "Inside Casino",
    "Outside Casino",
    "Inside Club",
    "Outside Club",
    "Inside Bank",
    "Outside Bank",
    "Inside Jewelery",
    "Outside Jewelery",
    "Vehicle Shop",
    "Outside House 1",
    "Inside House 1",
    "Outside House 2",
    "Inside House 2",
    "Cluckdonalds",
    "Coffe Shop"
}

teleportTab:Dropdown('Select Location', {
    location = flags,
    flag = 'selectedTeleport',
    list = locationNames
})

teleportTab:Button('Teleport', function()
    local targetLocation = flags.selectedTeleport
    if not targetLocation or not teleportLocations[targetLocation] then
        return
    end

    local method = flags.tpMethod or "Normal"
    local targetCFrame = teleportLocations[targetLocation]

    task.spawn(function()
        doTeleportWithMethod(method, targetCFrame)
    end)
end)

teleportTab:Section('--- TP 2 Player ---')

local playerNames = {}
for _, v in pairs(Players:GetPlayers()) do
    if v ~= LocalPlayer then
        table.insert(playerNames, v.Name)
    end
end

local reloadPlayers, playerBox = teleportTab:SearchBox('Player Name...', {
    location = flags,
    flag = 'tpPlayerName',
    list = playerNames
})

playerBox.FocusLost:Connect(function()
    local currentText = playerBox.Text:lower()
    if currentText == "" then return end

    for _, name in ipairs(playerNames) do
        if name:lower():sub(1, #currentText) == currentText then
            playerBox.Text = name
            flags.tpPlayerName = name
            break
        end
    end
end)

Players.PlayerAdded:Connect(function(p)
    table.insert(playerNames, p.Name)
    reloadPlayers(playerNames)
end)

Players.PlayerRemoving:Connect(function(p)
    for i, name in ipairs(playerNames) do
        if name == p.Name then
            table.remove(playerNames, i)
            break
        end
    end
    reloadPlayers(playerNames)
end)

teleportTab:Button('Teleport to Player', function()
    local targetInput = flags.tpPlayerName
    if not targetInput or targetInput == "" then return end

    local targetPlayer = nil
    local targetInputLower = targetInput:lower()

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            if p.Name:lower():sub(1, #targetInputLower) == targetInputLower
                or p.DisplayName:lower():sub(1, #targetInputLower) == targetInputLower then
                targetPlayer = p
                break
            end
        end
    end

    if not (targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")) then
        return
    end

    local method = flags.tpMethod or "Normal"
    local targetCFrame = targetPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)

    task.spawn(function()
        doTeleportWithMethod(method, targetCFrame)
    end)
end)

---------------------------------------------------------
-- TAB 4: MISC (Weapon Giver & Utilities)
---------------------------------------------------------
miscTab:Section('--- Weapon Giver ---')

local weaponList = {
    {name = "Pistol",  coords = Vector3.new(-1644.95, 42.97, 727.37), itemName = "Pistol"},
    {name = "Deagle",  coords = Vector3.new(-1644.53, 42.97, 724.74), itemName = "Deagle"},
    {name = "TEC9",    coords = Vector3.new(-1644.34, 42.97, 721.54), itemName = "TEC9"},
    {name = "MP5",     coords = Vector3.new(-1644.13, 42.97, 718.08), itemName = "MP5"},
    {name = "M4A1",    coords = Vector3.new(-1643.91, 42.97, 713.15), itemName = "M4A1"},
    {name = "AK47",    coords = Vector3.new(-1643.73, 42.97, 709.03), itemName = "AK47"},
    {name = "AWP",     coords = Vector3.new(-1643.46, 42.97, 702.90), itemName = "AWP"},
    {name = "RPG",     coords = Vector3.new(-1652.17, 42.97, 703.17), itemName = "RPG"},
    {name = "Shotgun", coords = Vector3.new(-1652.53, 42.97, 709.05), itemName = "Shotgun"},
    {name = "Grenade", coords = Vector3.new(-1652.77, 42.97, 712.92), itemName = "Grenade"},
    {name = "Knife",   coords = Vector3.new(-1652.65, 42.97, 714.90), itemName = "Knife"},
    {name = "Baton",   coords = Vector3.new(-1652.77, 42.97, 716.83), itemName = "Baton"},
    {name = "Bat",     coords = Vector3.new(-1653.06, 42.97, 721.58), itemName = "Bat"},
    {name = "SPAS",    coords = Vector3.new(-1653.34, 42.97, 726.08), itemName = "SPAS"},
}

local weaponDropdownNames = {}
for _, w in ipairs(weaponList) do
    table.insert(weaponDropdownNames, w.name)
end

miscTab:Dropdown('Select Weapon', {
    location = flags,
    flag = 'wgSelectedWeapon', 
    list = weaponDropdownNames
})

miscTab:Button('Get Weapon', function()
    local selectedName = flags.wgSelectedWeapon
    if not selectedName then return end

    if wgRunning then
        Notify("<Color=Red>Aktion läuft bereits!</Color>", 2)
        return
    end

    local weaponData = nil
    for _, w in ipairs(weaponList) do
        if w.name == selectedName then
            weaponData = w
            break
        end
    end

    if weaponData then
        task.spawn(function()
            selectWeapon(weaponData.name, weaponData.coords, weaponData.itemName)
        end)
    end
end)

miscTab:Section('--- Utilities ---')

miscTab:Button('Give EmotePack', function()
    local gamepasses = {1998633357}
    local added = false
    for _, v in pairs(gamepasses) do
        if not LocalPlayer:FindFirstChild(tostring(v)) then
            local l = Instance.new("BoolValue", LocalPlayer)
            l.Name = tostring(v)
            l.Value = true
            added = true
        end
    end
    if added then
        Notify("Emote pack has been given!", 2)
    end
end)

miscTab:Button('Enter Nearest Vehicle', function()
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local objectSelection = Workspace:FindFirstChild("ObjectSelection")

    if hrp and objectSelection then
        local closestSeat = nil
        local shortestDistance = math.huge

        for _, child in ipairs(objectSelection:GetChildren()) do
            local driveSeat = child:FindFirstChild("DriveSeat")
            if driveSeat and (driveSeat:IsA("VehicleSeat") or driveSeat:IsA("Seat")) then
                local distance = (hrp.Position - driveSeat.Position).Magnitude
                if distance < shortestDistance then
                    shortestDistance = distance
                    closestSeat = driveSeat
                end
            end
        end

        if closestSeat then
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                closestSeat:Sit(humanoid)
            end
        end
    end
end)

miscTab:Button('Remove all Lasers', function()
    local laserNames = {
        ["Lasers"] = true, ["SpinLaser"] = true, ["SpinLaser1"] = true,
        ["SpinLaser2"] = true, ["SpinLaser3"] = true, ["LaserLights"] = true,
        ["Lasers Club"] = true, ["SlideLaser"] = true
    }
    for _, obj in pairs(workspace:GetDescendants()) do
        if laserNames[obj.Name] then
            obj:Destroy()
        end
    end
end)

miscTab:Button('Remove all doors', function()
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name == "DoubleDoor" or obj.Name == "DoubleKeyDoor" or obj.Name == "CrimGate" or obj.Name == "CrimBaseGarage" or obj.Name == "Gate1" or obj.Name == "Gate2" or obj.Name == "DirectEscape" or obj.Name == "RevolvingDoor" or obj.Name == "PrisonGate1" or obj.Name == "PrisonGate2" then
            obj:Destroy()
        end
    end
end)

miscTab:Button('Remove Ferris Wheel', function()
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name == "FerrisWheel" then
            obj:Destroy()
        end
    end
end)

---------------------------------------------------------
-- TAB 5: TROLLING
---------------------------------------------------------
trollingTab:Section('--- Vehicle Trolling ---')

local isCarCollectorRunning = false
local autoHornEnabled = false
local autoDriftEnabled = false

local function isSwatCar(car)
    local settingsModule = car:FindFirstChild("Settings")
    if settingsModule then
        if string.find(string.upper(settingsModule.Name), "SWAT") or string.find(string.upper(car.Name), "SWAT") then
            return true
        end

        if settingsModule:IsA("ModuleScript") then
            local success, settingsData = pcall(function()
                return require(settingsModule)
            end)

            if success then
                if type(settingsData) == "table" then
                    for key, value in pairs(settingsData) do
                        if string.find(string.upper(tostring(key)), "SWAT") or string.find(string.upper(tostring(value)), "SWAT") then
                            return true
                        end
                    end
                elseif type(settingsData) == "string" and string.find(string.upper(settingsData), "SWAT") then
                    return true
                end
            end
        end
    end
    return false
end

local function findNextCar(objectSelection, startPosition, processedCars)
    for _, obj in ipairs(objectSelection:GetChildren()) do
        if not processedCars[obj] and isCarCollectorRunning then
            if isSwatCar(obj) then
                processedCars[obj] = true
            else
                local driveSeat = obj:FindFirstChild("DriveSeat")
                if driveSeat and driveSeat:IsA("VehicleSeat") then
                    if driveSeat.Occupant == nil then
                        local distance = (driveSeat.Position - startPosition).Magnitude
                        if distance > 30 then
                            return obj, driveSeat
                        end
                    end
                end
            end
        end
    end
    return nil, nil
end

local function startCarCollection()
    if isCarCollectorRunning then return end

    local character = LocalPlayer.Character
    local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end

    isCarCollectorRunning = true
    
    local lockedStartCFrame = humanoidRootPart.CFrame
    local lockedStartPosition = lockedStartCFrame.Position

    task.spawn(function()
        local processedCars = {}
        local objectSelection = Workspace:WaitForChild("ObjectSelection", 5)
        if not objectSelection then
            isCarCollectorRunning = false
            return
        end

        while isCarCollectorRunning do
            local charNow = LocalPlayer.Character
            local hrpNow = charNow and charNow:FindFirstChild("HumanoidRootPart")
            local humNow = charNow and charNow:FindFirstChild("Humanoid")

            if not (hrpNow and humNow) then
                task.wait(1)
                continue
            end

            local car, driveSeat = findNextCar(objectSelection, lockedStartPosition, processedCars)
            
            if not car or not isCarCollectorRunning then
                break
            end

            processedCars[car] = true

            if humNow and isCarCollectorRunning then
                driveSeat:Sit(humNow)
            end

            task.wait(0.3)
            if not isCarCollectorRunning then break end

            local carChassis = car:FindFirstChild("CarChassis")
            if carChassis then
                local event = carChassis:FindFirstChild("Event")
                if event and event:IsA("RemoteEvent") then
                    pcall(function()
                        event:FireServer("Horn", autoHornEnabled)
                        event:FireServer("Drift", autoDriftEnabled)
                    end)
                end
            end

            if car:IsA("Model") then
                car:PivotTo(lockedStartCFrame)
            else
                hrpNow.CFrame = lockedStartCFrame
            end

            task.wait(0.3)
            if not isCarCollectorRunning then break end

            if humNow then
                humNow.Sit = false
            end

            task.wait(0.3)
        end

        isCarCollectorRunning = false
    end)
end

trollingTab:Toggle('Auto Enable Horn', {location = flags, flag = "auto_enable_horn"}, function(state)
    autoHornEnabled = state
end)

trollingTab:Toggle('Auto Enable Drift', {location = flags, flag = "auto_enable_drift"}, function(state)
    autoDriftEnabled = state
end)

trollingTab:Button('Start Bring All Vehicles', function()
    if not isCarCollectorRunning then
        startCarCollection()
    end
end)

trollingTab:Button('Stop Bring All Vehicles', function()
    isCarCollectorRunning = false
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.Sit = false
    end
end)

local function ensureShotgun()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local character = LocalPlayer.Character
    
    local hasShotgun = (backpack and backpack:FindFirstChild("Shotgun")) or (character and character:FindFirstChild("Shotgun"))
    
    if not hasShotgun then
        local shotgunCoords = Vector3.new(-1652.53, 42.97, 709.05)
        selectWeapon("Shotgun", shotgunCoords, "Shotgun")
        task.wait(0.5)
    end
end

local Event = ReplicatedStorage:WaitForChild("Event")

local function processOtherVehicles()
    ensureShotgun()
    local objSel = workspace:FindFirstChild("ObjectSelection")
    if not objSel then return end
    for _, child in ipairs(objSel:GetChildren()) do
        local vehicleType = child:FindFirstChild("VehicleType")
        if vehicleType and vehicleType:IsA("ValueBase") then
            local vValue = vehicleType.Value
            if vValue ~= "Plane" and vValue ~= "Helicopter" then
                for _, part in ipairs(child:GetChildren()) do
                    if string.match(part.Name, "Wheel") then
                        for i = 1, 6 do
                            Event:FireServer("sZ4tk", part)
                        end
                    end
                end
            end
        end
    end
end

local function processAirVehicles()
    ensureShotgun()
    local objSel = workspace:FindFirstChild("ObjectSelection")
    if not objSel then return end
    for _, child in ipairs(objSel:GetChildren()) do
        local vehicleType = child:FindFirstChild("VehicleType")
        if vehicleType and vehicleType:IsA("ValueBase") then
            if vehicleType.Value == "Helicopter" or vehicleType.Value == "Plane" then
                local bodyPart = child:FindFirstChild("Body") and child.Body:FindFirstChild("Body")
                if bodyPart then
                    for i = 1, 6 do
                        Event:FireServer("sZ4tk", bodyPart)
                    end
                end
            end
        end
    end
end

trollingTab:Button('Pop all Tires', function()
    processOtherVehicles()
end)

local loopPopTiresActive = false
trollingTab:Toggle('Loop Pop all Tires', {location = flags, flag = "loop_pop_tires"}, function(state)
    loopPopTiresActive = state
    task.spawn(function()
        while loopPopTiresActive do
            processOtherVehicles()
            task.wait(10.5)
        end
    end)
end)

trollingTab:Button('Disable all Air Vehicles', function()
    processAirVehicles()
end)

local loopDisableAirActive = false
trollingTab:Toggle('Loop Disable Air Vehicles', {location = flags, flag = "loop_disable_air"}, function(state)
    loopDisableAirActive = state
    task.spawn(function()
        while loopDisableAirActive do
            processAirVehicles()
            task.wait(8)
        end
    end)
end)

---------------------------------------------------------
-- KILL PLAYER & KILL ALL (Kill All durchläuft alle, Heli-Rückgabe/Rückteleport erst ganz am Ende)
---------------------------------------------------------
trollingTab:Section('--- Player Trolling ---')

local FIXED_HELI_RETURN_CFRAME = CFrame.new(-4255.49, 38.73, -3878.23)

local trollPlayerNames = {}
for _, v in pairs(Players:GetPlayers()) do
    if v ~= LocalPlayer then
        table.insert(trollPlayerNames, v.Name)
    end
end

local reloadTrollPlayers, trollPlayerBox = trollingTab:SearchBox('Player Name...', {
    location = flags,
    flag = 'trollPlayerName',
    list = trollPlayerNames
})

trollPlayerBox.FocusLost:Connect(function()
    local currentText = trollPlayerBox.Text:lower()
    if currentText == "" then return end

    for _, name in ipairs(trollPlayerNames) do
        if name:lower():sub(1, #currentText) == currentText then
            trollPlayerBox.Text = name
            flags.trollPlayerName = name
            break
        end
    end
end)

Players.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then
        table.insert(trollPlayerNames, p.Name)
        reloadTrollPlayers(trollPlayerNames)
    end
end)

Players.PlayerRemoving:Connect(function(p)
    for i, name in ipairs(trollPlayerNames) do
        if name == p.Name then
            table.remove(trollPlayerNames, i)
            break
        end
    end
    reloadTrollPlayers(trollPlayerNames)
end)

local function hasMissileHelicopterSettings(model)
    local settings = model:FindFirstChild("Settings")
    if settings and settings:IsA("ModuleScript") then
        local success, data = pcall(function()
            return require(settings)
        end)
        if success and type(data) == "table" and data.Missiles == true then
            return true
        end
    end
    return false
end

local function getSuitableHelicopter()
    local objectSelection = Workspace:FindFirstChild("ObjectSelection")
    if not objectSelection then return nil end

    for _, model in ipairs(objectSelection:GetChildren()) do
        if hasMissileHelicopterSettings(model) then
            local seat = model:FindFirstChild("DriveSeat", true) or model:FindFirstChildWhichIsA("VehicleSeat", true)
            if seat then
                return model, seat
            end
        end
    end
    return nil, nil
end

local function executeKillOnTarget(targetPlayer, isBatchMode)
    if not (targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")) then
        return
    end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not (char and hum and hrp) then return end

    local originalCFrame = hrp.CFrame

    local currentSeat = hum.SeatPart
    local currentHeli = nil
    local hadHeliBefore = false
    local initialHeliCFrame = nil

    if currentSeat then
        local model = currentSeat.Parent
        while model and not model:IsA("Model") do model = model.Parent end
        if model and hasMissileHelicopterSettings(model) then
            currentHeli = model
            hadHeliBefore = true
            initialHeliCFrame = currentHeli:GetPivot()
        else
            hum.Sit = false
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            task.wait(1.0)
        end
    end

    if not currentHeli then
        local heliModel, seat = getSuitableHelicopter()
        if not heliModel or not seat then
            Notify("<Color=Red>Kein passender Heli mit Missiles=true gefunden!</Color>", 2)
            return
        end
        
        currentHeli = heliModel
        hadHeliBefore = false
        
        startFlagLoop()
        S.holding = true

        seat:Sit(hum)
        local t = 0
        while hum.SeatPart ~= seat and t < 3 do
            task.wait(0.1)
            t = t + 0.1
        end
        task.wait(1.0)

        local targetHrp = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not targetHrp then stopFlagLoop() return end
        
        local targetPos = targetHrp.Position
        local attackCFrame = CFrame.new(targetPos.X, targetPos.Y + 300, targetPos.Z)

        currentHeli:PivotTo(attackCFrame)
        startVelocityLock(0.5)
        task.wait(1.0)

        for i = 1, 8 do
            if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                targetPos = targetPlayer.Character.HumanoidRootPart.Position
                currentHeli:PivotTo(CFrame.new(targetPos.X, targetPos.Y + 300, targetPos.Z))
            end
            Event:FireServer("bX2mc", Vector3.new(targetPos.X, targetPos.Y, targetPos.Z))
            task.wait(0.05)
        end

        -- Nur zurückbringen/teleportieren, wenn es kein Batch-Modus (Kill All) ist
        if not isBatchMode then
            currentHeli:PivotTo(FIXED_HELI_RETURN_CFRAME)
            startVelocityLock(0.5)
            task.wait(1.0)

            startVelocityLock(0.6)
            for i = 1, 5 do
                hrp.CFrame = originalCFrame
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.Velocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
                hrp.RotVelocity = Vector3.zero
                task.wait(0.03)
            end
            startVelocityLock(0.4)

            stopFlagLoop()

            hum.Sit = false
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            task.wait(1.0)

            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
            task.wait(1.0)
        else
            stopFlagLoop()
        end
        return
    end

    -- Wenn der Spieler schon im Heli saß
    local targetHrp = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetHrp then return end

    local targetPos = targetHrp.Position
    local attackCFrame = CFrame.new(targetPos.X, targetPos.Y + 300, targetPos.Z)

    currentHeli:PivotTo(attackCFrame)
    startVelocityLock(0.5)
    task.wait(1.0)

    for i = 1, 8 do
        if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
            targetPos = targetPlayer.Character.HumanoidRootPart.Position
            currentHeli:PivotTo(CFrame.new(targetPos.X, targetPos.Y + 300, targetPos.Z))
        end
        Event:FireServer("bX2mc", Vector3.new(targetPos.X, targetPos.Y, targetPos.Z))
        task.wait(0.05)
    end

    if not isBatchMode then
        if initialHeliCFrame then
            currentHeli:PivotTo(initialHeliCFrame)
        end
        startVelocityLock(0.5)
        task.wait(1.0)
    end
end

trollingTab:Button('Kill', function()
    local targetInput = flags.trollPlayerName
    if not targetInput or targetInput == "" then return end

    local targetPlayer = nil
    local targetInputLower = targetInput:lower()

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            if p.Name:lower():sub(1, #targetInputLower) == targetInputLower
                or p.DisplayName:lower():sub(1, #targetInputLower) == targetInputLower then
                targetPlayer = p
                break
            end
        end
    end

    if targetPlayer then
        task.spawn(function()
            executeKillOnTarget(targetPlayer, false)
        end)
    end
end)

trollingTab:Button('Kill All', function()
    task.spawn(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        
        local originalCFrame = hrp.CFrame
        local currentSeat = char:FindFirstChild("Humanoid") and char.Humanoid.SeatPart
        local hadHeliBefore = false
        local initialHeliCFrame = nil
        local currentHeli = nil

        if currentSeat then
            local model = currentSeat.Parent
            while model and not model:IsA("Model") do model = model.Parent end
            if model and hasMissileHelicopterSettings(model) then
                currentHeli = model
                hadHeliBefore = true
                initialHeliCFrame = currentHeli:GetPivot()
            end
        end

        -- 1. Alle Spieler nacheinander abarbeiten (ohne Zwischentransport)
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                executeKillOnTarget(p, true)
                task.wait(0.2)
            end
        end

        -- 2. ERST GANZ AM ENDE: Heli zurückbringen & Spieler zurückteleportieren
        local activeHeli, _ = getSuitableHelicopter()
        if activeHeli then
            if not hadHeliBefore then
                activeHeli:PivotTo(FIXED_HELI_RETURN_CFRAME)
            else
                if initialHeliCFrame then
                    activeHeli:PivotTo(initialHeliCFrame)
                end
            end
        end

        startVelocityLock(0.5)
        task.wait(0.5)

        startVelocityLock(0.6)
        for i = 1, 5 do
            hrp.CFrame = originalCFrame
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.Velocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            hrp.RotVelocity = Vector3.zero
            task.wait(0.03)
        end
        startVelocityLock(0.4)

        stopFlagLoop()

        local hum = char and char:FindFirstChild("Humanoid")
        if hum then
            hum.Sit = false
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            task.wait(1.0)
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
        end
    end)
end)

---------------------------------------------------------
-- TAB 6: FARMING
---------------------------------------------------------
farmingTab:Section('--- Exp Farm ---')

local TARGET_EXP_POS = Vector3.new(-1025.13, 53.08, -3242.94)
local scriptRunning = false

local function executeNormalTeleport(targetPos)
    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = CFrame.new(targetPos)
        startVelocityLock(0.5)
    end
end

local function getClosestModelsByName(targetName, count)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local objectSelection = Workspace:FindFirstChild("ObjectSelection")
    if not hrp or not objectSelection then return {} end

    local list = {}
    for _, child in ipairs(objectSelection:GetChildren()) do
        if child.Name == targetName then
            local pos = child:GetPivot().Position
            local dist = (hrp.Position - pos).Magnitude
            table.insert(list, {model = child, dist = dist})
        end
    end

    table.sort(list, function(a, b) return a.dist < b.dist end)

    local result = {}
    for i = 1, math.min(count, #list) do
        table.insert(result, list[i].model)
    end
    return result
end

local function fireAllEventsSimultaneously()
    local targetsToFind = {"BenchPress", "Treadmill", "Pullups"}
    local eventsToFire = {}

    for _, name in ipairs(targetsToFind) do
        local models = getClosestModelsByName(name, 2)
        for _, model in ipairs(models) do
            local child1 = model:FindFirstChild(name)
            if child1 then
                local child2 = child1:FindFirstChild(name)
                if child2 then
                    local event = child2:FindFirstChild("Event")
                    if event and event:IsA("RemoteEvent") then
                        table.insert(eventsToFire, event)
                    end
                end
            end
        end
    end

    for _, event in ipairs(eventsToFire) do
        task.spawn(function()
            event:FireServer()
        end)
    end
end

local function startMainLoop()
    task.spawn(function()
        local ok = executeSeatPersistTeleport(TARGET_EXP_POS)
        if not ok then
            executeNormalTeleport(TARGET_EXP_POS)
        end

        task.wait(0.5)
        local firstRun = true

        while scriptRunning do
            if not firstRun then
                executeNormalTeleport(TARGET_EXP_POS)
                task.wait(0.3)
            end
            firstRun = false

            if not scriptRunning then break end

            fireAllEventsSimultaneously()

            local elapsedTime = 0
            while elapsedTime < 5 and scriptRunning do
                task.wait(0.1)
                elapsedTime = elapsedTime + 0.1
            end
        end
    end)
end

farmingTab:Toggle("Exp Farm", {
    location = flags,
    flag = "exp_farm_toggle"
}, function(state)
    scriptRunning = state
    if scriptRunning then
        startMainLoop()
    else
        stopFlagLoop()
    end
end)

---------------------------------------------------------
-- TOGGLE & SLIDE ANIMATION (RightAlt)
---------------------------------------------------------
local toggleKey = Enum.KeyCode.RightAlt
local toggled = true

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == toggleKey then
        if library.container then
            toggled = not toggled
            if toggled then
                library.container:TweenPosition(UDim2.new(0, 20, 0, 20), "Out", "Quad", 0.4, true)
            else
                library.container:TweenPosition(UDim2.new(-1, 0, -1, 0), "In", "Quad", 0.4, true)
            end
        end
    end
end)
