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
Notify("<Color=White>You can Toggle the UI with LeftAlt", 2)

---------------------------------------------------------
-- VEHICLE TELEPORT LOGIC (FIXED HEIST CLIPPING)
---------------------------------------------------------
local SPAWN_SPAM_POS = Vector3.new(632.65, 437.56, 514.56)

local function getPlayerVehicle()
    local objectSelection = Workspace:FindFirstChild("ObjectSelection")
    if objectSelection then
        for _, model in ipairs(objectSelection:GetChildren()) do
            local vehicleOwner = model:FindFirstChild("VehicleOwner")
            if vehicleOwner then
                local ownerValue = vehicleOwner.Value
                if (typeof(ownerValue) == "Instance" and ownerValue == LocalPlayer) 
                or (tostring(ownerValue) == LocalPlayer.Name) then
                    return model
                end
            end
        end
    end
    return nil
end

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

            -- Fix: Setzt das Auto sicher über den Boden (World Space)
            local safeTargetCFrame = targetCFrame + Vector3.new(0, 5, 0)
            vehicle:PivotTo(safeTargetCFrame)
            hrp.CFrame = safeTargetCFrame + Vector3.new(0, 2, 0)

            -- Schwung auf 0 setzen, damit es nicht durch den Heist-Boden fällt!
            if vehicle.PrimaryPart then
                vehicle.PrimaryPart.Velocity = Vector3.new(0, 0, 0)
                vehicle.PrimaryPart.RotVelocity = Vector3.new(0, 0, 0)
            end

            task.wait(0.4) -- Kurz auf dem Boden stabilisieren lassen
            humanoid.Sit = false

            task.wait(0.1)
            local exitPos = safeTargetCFrame.Position + Vector3.new(0, 3, 0)
            character:PivotTo(CFrame.new(exitPos))
        else
            Notify("<Color=Red>Fehler:</Color> Konnte nicht ins Auto einsteigen!", 2)
        end
    else
        Notify("<Color=Red>Fehler:</Color> Fahrzeug hat keinen Sitz!", 2)
    end
end

local function vehicleTeleport(targetCFrame)
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local existingVehicle = getPlayerVehicle()

    if existingVehicle then
        executeVehicleDriveAndTeleport(existingVehicle, targetCFrame)
    else
        local originalCFrame = hrp.CFrame
        hrp.CFrame = CFrame.new(SPAWN_SPAM_POS)
        
        local startTime = tick()
        local spawnedVehicle = nil
        local lastSpawnAttempt = 0

        while tick() - startTime < 10 do
            hrp.CFrame = CFrame.new(SPAWN_SPAM_POS)

            if tick() - lastSpawnAttempt > 1.5 then
                gameEvent:FireServer("SpawnVehicle", "Camaro")
                lastSpawnAttempt = tick()
            end

            spawnedVehicle = getPlayerVehicle()
            if spawnedVehicle then
                break
            end

            task.wait(0.1)
        end

        if not spawnedVehicle then
            hrp.CFrame = originalCFrame
            Notify("<Color=Red>Vehicle Teleport failed!</Color>", 2)
            return
        end

        task.wait(0.5)
        executeVehicleDriveAndTeleport(spawnedVehicle, targetCFrame)
    end
end

---------------------------------------------------------
-- WEAPON GIVER LOGIC
---------------------------------------------------------
local MAX_RUNTIME = 5.0
local EVENT_SPAM_DELAY = 0.05
local TELEPORT_DELAY = 0.001
local wgRunning = false

local function getCharacter()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart")
    return char, hrp
end

local function claimOwnership(hrp)
    pcall(function() hrp:SetNetworkOwner(LocalPlayer) end)
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

    local char, hrp = getCharacter()
    claimOwnership(hrp)

    local savedCFrame = hrp.CFrame
    local targetCFrame = CFrame.new(targetCoords)

    task.wait(0.15)

    if hasItem(itemName) then
        wgRunning = false
        return
    end

    local stop = false
    local startTime = os.clock()

    task.spawn(function()
        while not stop do
            if not hrp or not hrp.Parent then
                local c = LocalPlayer.Character
                if c then hrp = c:FindFirstChild("HumanoidRootPart") end
            end
            if hrp then
                hrp.CFrame = targetCFrame
            end
            task.wait(TELEPORT_DELAY)
        end
    end)

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

    if hrp and hrp.Parent then
        hrp.CFrame = savedCFrame
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

local noclipEnabled = false
local noclipControlEnabled = false
local SteppedConnection

local function disableNoclip()
    if SteppedConnection then
        SteppedConnection:Disconnect()
        SteppedConnection = nil
    end
    for _, child in pairs(Workspace:GetChildren()) do
        if child.Name == LocalPlayer.Name then
            for _, part in pairs(child:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end
end

local function enableNoclip()
    SteppedConnection = RunService.Stepped:Connect(function()
        for _, child in pairs(Workspace:GetChildren()) do
            if child.Name == LocalPlayer.Name then
                for _, part in pairs(child:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end
    end)
end

mainTab:Toggle("Noclip [N]", {flag = "noclip"}, function(state)
    noclipControlEnabled = state 
    if not state then
        noclipEnabled = false
        disableNoclip()
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
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

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

--Inf Nitro
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

--HoverMode
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
            Settings.Missiles = true
            Settings.MissileCooldown = 0
            Settings.MissileLock = 1
            Settings.MissileTargetLock = 600
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
teleportTab:Section('--- Place Teleports ---')

local teleportLocations = {
    ["Prison In"] = {cframe = CFrame.new(-1053, 53, -3065), useVeh = false},
    ["Prison Out"] = {cframe = CFrame.new(-890, 54, -2633), useVeh = false},
    ["Police Station"] = {cframe = CFrame.new(-962, 53, -2945), useVeh = false},
    ["Volcan"] = {cframe = CFrame.new(-1544, 345, 1599), useVeh = false},
    ["Criminal Base"] = {cframe = CFrame.new(2138, 26, 373), useVeh = false},
    ["Gun Shop"] = {cframe = CFrame.new(-1614, 43, 687), useVeh = false},
    
    ["Bank Out"] = {cframe = CFrame.new(733, 26, 441), useVeh = false},
    ["Bank In (Heist)"] = {cframe = CFrame.new(679.78, 84.22, 583.71), useVeh = true},
    
    ["Jewelry Out"] = {cframe = CFrame.new(-217, 112, 759), useVeh = false},
    ["Jewelry In (Heist)"] = {cframe = CFrame.new(-95.46, 25.63, 796.85), useVeh = true},
    
    ["Casino Out"] = {cframe = CFrame.new(1789, 26, 688), useVeh = false},
    ["Casino In (Heist)"] = {cframe = CFrame.new(1695.86, 40.82, 496.46), useVeh = true},
    
    ["Club Out"] = {cframe = CFrame.new(1285, 26, 40), useVeh = false},
    ["Club In (Heist)"] = {cframe = CFrame.new(1327.10, 145.42, -124.89), useVeh = true},
    
    ["Pyramid In (Heist)"] = {cframe = CFrame.new(1001.85, 51072.70, 537.93), useVeh = true}
}

local locationNames = {}
for name, _ in pairs(teleportLocations) do
    table.insert(locationNames, name)
end

teleportTab:Dropdown('Select Location', {
    location = flags,
    flag = 'selectedTeleport', 
    list = locationNames
})

teleportTab:Button('Teleport', function()
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local targetLocation = flags.selectedTeleport
    
    if hrp and targetLocation and teleportLocations[targetLocation] then
        local tpData = teleportLocations[targetLocation]
        if tpData.useVeh then
            task.spawn(function()
                vehicleTeleport(tpData.cframe)
            end)
        else
            hrp.CFrame = tpData.cframe
        end
    end
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

teleportTab:Toggle('Use Vehicle Bypass', {
    location = flags,
    flag = 'tpPlayerUseVehicle'
})

teleportTab:Button('Teleport to Player', function()
    local targetInput = flags.tpPlayerName
    if not targetInput or targetInput == "" then return end
    
    local targetPlayer = nil
    local targetInputLower = targetInput:lower()
    
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            if p.Name:lower():sub(1, #targetInputLower) == targetInputLower or p.DisplayName:lower():sub(1, #targetInputLower) == targetInputLower then
                targetPlayer = p
                break
            end
        end
    end
    
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if myHrp then
            local targetCFrame = targetPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3)
            if flags.tpPlayerUseVehicle then
                Notify("Verwende Vehicle TP zu <Color=Cyan>" .. targetPlayer.Name .. "<Color=/>...", 2)
                task.spawn(function()
                    vehicleTeleport(targetCFrame)
                end)
            else
                myHrp.CFrame = targetCFrame
                Notify("Teleported to <Color=Cyan>" .. targetPlayer.Name .. "<Color=/>", 2)
            end
        end
    end
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
    local gamepasses = {
        1998633357
    }

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

miscTab:Button('Get in Any Vehicle', function()
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
        ["Lasers"] = true,
        ["SpinLaser"] = true,
        ["SpinLaser1"] = true,
        ["SpinLaser2"] = true,
        ["SpinLaser3"] = true,
        ["LaserLights"] = true,
        ["Lasers Club"] = true,
        ["SlideLaser"] = true
    }

    local found = false
    for _, obj in pairs(workspace:GetDescendants()) do
        if laserNames[obj.Name] then
            obj:Destroy()
            found = true
        end
    end
    
    if not found then
        Notify("No Lasers found", 0.8)
    else
        Notify("All lasers removed", 0.8)
    end
end)

miscTab:Button('Remove all doors', function()
    local found = false
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj.Name == "DoubleDoor" or obj.Name == "DoubleKeyDoor" or obj.Name == "CrimGate" or obj.Name == "CrimBaseGarage" or obj.Name == "Gate1" or obj.Name == "Gate2" or obj.Name == "DirectEscape" or obj.Name == "RevolvingDoor" or obj.Name == "PrisonGate1" or obj.Name == "PrisonGate2" then
            obj:Destroy()
            found = true
        end
    end
    
    if not found then
        Notify("No Doors found", 0.8)
    else
        Notify("All doors deleted", 0.8)
    end
end)

---------------------------------------------------------
-- TOGGLE & SLIDE ANIMATION
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
