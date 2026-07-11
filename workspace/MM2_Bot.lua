-- MM2 Auto-Play Bot v1.0
-- Murder Mystery 2 (142823291)
-- For Xeno Executor
-- Strategies: Sheriff hunting, Murderer stalking, Innocent evasion + coin collect + anti-edge + sound-react

repeat task.wait() until game:IsLoaded()
if game.PlaceId ~= 142823291 then return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LP = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")

repeat task.wait() until LP.Character

-- Config
local Config = {
    Enabled = true,
    Sheriff = { AutoShoot = true, ShootRange = 150, TriggerHappy = false },
    Murderer = { AutoKill = true, ChaseSpeed = 50, SheriffAvoid = true },
    Innocent = { Evade = true, CollectCoins = true, EvadeDistance = 120 },
    AntiFall = true,
    WallCheck = true,
}

-- State
local role = "Unknown"
local prevRole = "Unknown"
local targetPlayer = nil
local report = { kills = 0, deaths = 0, coins = 0, shots = 0 }
local localDead = false

-- Utility
local function getChar(p) return p and p.Character end
local function getHRP(p) local c = getChar(p); return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum(p) local c = getChar(p); return c and c:FindFirstChildOfClass("Humanoid") end
local function alive(p) local h = getHum(p); return h and h.Health > 0 end

local function hasTool(p, name)
    for _, container in ipairs({getChar(p), p:FindFirstChild("Backpack")}) do
        if container then
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") and (not name or tool.Name:lower():find(name:lower())) then
                    return tool
                end
            end
        end
    end
end

local function detectRole()
    if hasTool(LP, "Gun") and not hasTool(LP, "Knife") then return "Sheriff" end
    if hasTool(LP, "Knife") and not hasTool(LP, "Gun") then return "Murderer" end
    return "Innocent"
end

local function getMurderer()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and hasTool(p, "Knife") then return p end
    end
end

local function getNearest(target, filterFn)
    local ref = getHRP(target) or (target == LP and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"))
    if not ref then return nil, math.huge end
    local best, bestD = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= target and (not filterFn or filterFn(p)) then
            local h = getHRP(p); if h then
                local d = (ref.Position - h.Position).Magnitude
                if d < bestD then bestD = d; best = p end
            end
        end
    end
    return best, bestD
end

local function getNearestByPos(pos, filterFn)
    local best, bestD = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and (not filterFn or filterFn(p)) then
            local h = getHRP(p); if h then
                local d = (pos - h.Position).Magnitude
                if d < bestD then bestD = d; best = p end
            end
        end
    end
    return best, bestD
end

local function findCoins()
    local coins = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") and (v.Name == "Coin" or v.Name:find("[Cc]oin") or v.Name == "Gold" or v.Name:find("[Gg]old")) then
            table.insert(coins, v)
        end
    end
    return coins
end

local function getNearestCoin(pos)
    local best, bestD = nil, math.huge
    for _, c in ipairs(findCoins()) do
        local d = (pos - c.Position).Magnitude
        if d < bestD then bestD = d; best = c end
    end
    return best, bestD
end

local function lookAt(pos)
    local hrp = getHRP(LP); if not hrp then return end
    local d = (pos - hrp.Position)
    if d.Magnitude > 0 then hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + d.Unit) end
end

local function moveTo(pos, speed)
    local hrp = getHRP(LP); local hum = getHum(LP)
    if not hrp or not hum then return end
    hum:MoveTo(pos)
end

local function stopMove()
    local hum = getHum(LP); if hum then hum:MoveTo(getHRP(LP).Position) end
end

local function tpTo(pos)
    local hrp = getHRP(LP); if hrp then hrp.CFrame = CFrame.new(pos) end
end

local function activateTool(tool)
    if not tool then return end
    pcall(function()
        tool:Activate()
    end)
end

local function hasGroundBelow(pos, dist)
    local p = RaycastParams.new(); p.FilterType = Enum.RaycastFilterType.Blacklist; p.FilterDescendantsInstances = {LP.Character}
    local r = Workspace:Raycast(pos, Vector3.new(0, -dist, 0), p)
    return r ~= nil
end

local function findSafeSpot()
    local hrp = getHRP(LP); if not hrp then return end
    for i = 1, 20 do
        local angle = math.random() * math.pi * 2
        local r = math.random(20, 80)
        local candidate = hrp.Position + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
        if hasGroundBelow(candidate + Vector3.new(0, 5, 0), 30) then
            return candidate
        end
    end
end

-- Kill/death tracking
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LP then
        local hum = getHum(p)
        if hum then hum.Died:Connect(function() if role == "Murderer" then report.kills = report.kills + 1 end end) end
    end
end
Players.PlayerAdded:Connect(function(p)
    if p ~= LP then
        p.CharacterAdded:Connect(function(char)
            local hum = char:WaitForChild("Humanoid", 5)
            if hum then hum.Died:Connect(function() if role == "Murderer" then report.kills = report.kills + 1 end end) end
        end)
    end
end)

-- Role-based AI connections
local aiConns = {}

local function clearAI()
    for _, c in ipairs(aiConns) do pcall(c.Disconnect, c) end; aiConns = {}
    localDead = false
end

-- === SHERIFF AI ===
local function startSheriffAI()
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not Config.Enabled or role ~= "Sheriff" or not alive(LP) then return end
        if localDead then return end

        local gun = hasTool(LP, "Gun")
        if not gun then return end

        -- Find murderer (someone with Knife, not us)
        local murderer = getMurderer()
        if not murderer or not alive(murderer) then
            -- No one has knife yet - round might not have started
            -- Wander and look around
            local hrp = getHRP(LP)
            if hrp and not hasGroundBelow(hrp.Position, 10) then
                local s = findSafeSpot(); if s then tpTo(s) end
            end
            return
        end

        local mHRP = getHRP(murderer)
        if not mHRP then return end

        local myHRP = getHRP(LP)
        if not myHRP then return end

        local dist = (myHRP.Position - mHRP.Position).Magnitude
        targetPlayer = murderer

        if dist <= Config.Sheriff.ShootRange then
            -- Face and shoot
            lookAt(mHRP.Position)

            if Config.Sheriff.AutoShoot then
                if Config.Sheriff.TriggerHappy then
                    activateTool(gun) activateTool(gun) activateTool(gun)
                else
                    activateTool(gun)
                end
                report.shots = report.shots + 1
            end

            -- If murderer is < 30 studs, backpedal
            if dist < 30 then
                local retreat = (myHRP.Position - mHRP.Position).Unit * 50
                moveTo(myHRP.Position + retreat, 24)
            else
                moveTo(mHRP.Position, 22)
            end
        else
            -- Chase the murderer
            moveTo(mHRP.Position, Config.Murderer.ChaseSpeed or 40)
        end

        -- Anti-fall
        if Config.AntiFall and myHRP.Position.Y < -50 then
            local s = findSafeSpot(); if s then tpTo(s) end
        end
    end)
    table.insert(aiConns, conn)
end

-- === MURDERER AI ===
local function startMurdererAI()
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not Config.Enabled or role ~= "Murderer" or not alive(LP) then return end
        if localDead then return end

        local knife = hasTool(LP, "Knife")
        if not knife then return end

        local myHRP = getHRP(LP)
        if not myHRP then return end

        -- Find nearest alive player who is NOT the murderer
        local target, dist = getNearest(LP, function(p) return p ~= LP and alive(p) and not hasTool(p, "Knife") end)

        if not target then
            -- No targets - maybe round hasn't started or all dead
            if not hasGroundBelow(myHRP.Position, 10) then
                local s = findSafeSpot(); if s then tpTo(s) end
            end
            return
        end

        local tHRP = getHRP(target)
        if not tHRP then return end

        targetPlayer = target
        local tDist = (myHRP.Position - tHRP.Position).Magnitude

        -- Check for sheriff nearby (avoid them if config says so)
        if Config.Murderer.SheriffAvoid then
            local sheriff = getNearest(LP, function(p) return p ~= LP and hasTool(p, "Gun") and not hasTool(p, "Knife") end)
            if sheriff and sheriff ~= target then
                local sHRP = getHRP(sheriff)
                if sHRP then
                    local distToSheriff = (myHRP.Position - sHRP.Position).Magnitude
                    -- If sheriff is closer than target AND close enough to be dangerous, retreat
                    if distToSheriff < tDist and distToSheriff < Config.Sheriff.ShootRange then
                        -- Retreat from sheriff while keeping target in sight
                        local retreatDir = (myHRP.Position - sHRP.Position).Unit
                        local retreatPos = myHRP.Position + retreatDir * 150
                        lookAt(tHRP.Position)
                        moveTo(retreatPos, Config.Murderer.ChaseSpeed)
                        return
                    end
                end
            end
        end

        if tDist <= 16 then
            -- In range - face and stab
            lookAt(tHRP.Position)
            if Config.Murderer.AutoKill then
                activateTool(knife)
            end
        else
            -- Chase target
            lookAt(tHRP.Position)
            moveTo(tHRP.Position, Config.Murderer.ChaseSpeed)
        end

        -- Anti-fall
        if Config.AntiFall and myHRP.Position.Y < -50 then
            local s = findSafeSpot(); if s then tpTo(s) end
        end
    end)
    table.insert(aiConns, conn)

    -- Extra: sprint between kills using shift
    local sprintConn = RunService.RenderStepped:Connect(function()
        if not Config.Enabled or role ~= "Murderer" then return end
        pcall(function()
            local hum = getHum(LP)
            if hum and Config.Murderer.ChaseSpeed > 16 then
                hum.WalkSpeed = Config.Murderer.ChaseSpeed
            end
        end)
    end)
    table.insert(aiConns, sprintConn)
end

-- === INNOCENT AI ===
local function startInnocentAI()
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not Config.Enabled or role ~= "Innocent" or not alive(LP) then return end
        if localDead then return end

        local myHRP = getHRP(LP)
        if not myHRP then return end

        -- Find murderer (we can detect them via Backpack tool check)
        local murderer = getMurderer()
        local mHRP = murderer and getHRP(murderer)
        local distToMurderer = mHRP and (myHRP.Position - mHRP.Position).Magnitude or math.huge

        targetPlayer = murderer

        -- Strategy 1: Evade murderer
        if Config.Innocent.Evade and mHRP and distToMurderer < Config.Innocent.EvadeDistance then
            -- Run AWAY from murderer
            local escapeDir = (myHRP.Position - mHRP.Position).Unit
            local escapePos = myHRP.Position + escapeDir * (Config.Innocent.EvadeDistance + 50)

            -- But don't run off the map
            if not hasGroundBelow(escapePos + Vector3.new(0, 5, 0), 50) then
                -- Find alternative direction that has ground
                for angle = 0, 360, 30 do
                    local a = math.rad(angle)
                    local altDir = Vector3.new(math.cos(a), 0, math.sin(a))
                    local altPos = myHRP.Position + altDir * 100
                    if hasGroundBelow(altPos + Vector3.new(0, 5, 0), 50) then
                        escapePos = altPos; break
                    end
                end
            end

            lookAt(escapePos)
            moveTo(escapePos, 24)
            return
        end

        -- Strategy 2: Collect coins
        if Config.Innocent.CollectCoins then
            local coin, coinDist = getNearestCoin(myHRP.Position)
            if coin and coinDist < 60 then
                lookAt(coin.Position)
                moveTo(coin.Position, 20)
                if coinDist < 5 then report.coins = report.coins + 1 end
                return
            end

            -- No close coins - wander toward areas with ground
            if not hasGroundBelow(myHRP.Position, 10) then
                local s = findSafeSpot(); if s then moveTo(s, 20); return end
            end

            -- Wander toward center-ish of map (near other players but not too close)
            local nearestPlayer, nearestDist = getNearest(LP, function(p) return p ~= LP and alive(p) end)
            if nearestPlayer and nearestDist > 60 then
                local nHRP = getHRP(nearestPlayer)
                if nHRP then
                    -- Move toward other players (safety in numbers)
                    moveTo(nHRP.Position, 20)
                    return
                end
            end

            -- Move randomly
            local randDir = Vector3.new(math.random(-50, 50), 0, math.random(-50, 50))
            local wanderPos = myHRP.Position + randDir
            if hasGroundBelow(wanderPos + Vector3.new(0, 5, 0), 30) then
                moveTo(wanderPos, 18)
            end
        end

        -- Anti-fall
        if Config.AntiFall and myHRP.Position.Y < -50 then
            local s = findSafeSpot(); if s then tpTo(s) end
        end
    end)
    table.insert(aiConns, conn)

    -- Jump spam to make harder to hit
    local jumpConn = RunService.Heartbeat:Connect(function()
        if not Config.Enabled or role ~= "Innocent" or not alive(LP) then return end
        local hum = getHum(LP)
        if hum and hum.FloorMaterial and hum.FloorMaterial ~= Enum.Material.Air then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
    table.insert(aiConns, jumpConn)
end

-- Role monitor
task.spawn(function()
    while true do
        task.wait(0.5)
        if not Config.Enabled then
            if #aiConns > 0 then clearAI() end
            prevRole = ""
            continue
        end

        if alive(LP) then localDead = false end

        -- Only detect role when alive
        if alive(LP) then
            local newRole = detectRole()
            if newRole ~= prevRole then
                prevRole = newRole
                role = newRole
                clearAI()
                print("[MM2 Bot] Role: " .. role)

                if role == "Sheriff" then startSheriffAI()
                elseif role == "Murderer" then startMurdererAI()
                elseif role == "Innocent" then startInnocentAI() end
            end
        end
    end
end)

-- Local player death/respawn
local function trackLPDeath()
    local hum = getHum(LP)
    if hum then
        hum.Died:Connect(function()
            localDead = true; report.deaths = report.deaths + 1
            clearAI()
        end)
    end
end
trackLPDeath()
LP.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    localDead = false
    trackLPDeath()
end)

-- === RAYFIELD UI ===
local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua"))()
local Window = Rayfield:CreateWindow({
    Name = "MM2 Auto-Play Bot v1.0",
    LoadingTitle = "MM2 Bot",
    LoadingSubtitle = "by itsinvin",
    ConfigurationSaving = { Enabled = true, FolderName = "MM2Bot", FileName = "Config" },
    KeySystem = false,
})

local mainTab = Window:CreateTab("Main", nil)
mainTab:CreateSection("Control")
local toggleEnabled = mainTab:CreateToggle({Name = "Bot Enabled", CurrentValue = true, Callback = function(v) Config.Enabled = v; if not v and #aiConns > 0 then clearAI(); prevRole = "" end end})

mainTab:CreateSection("Sheriff")
mainTab:CreateToggle({Name = "Auto-Shoot", CurrentValue = true, Callback = function(v) Config.Sheriff.AutoShoot = v end})
mainTab:CreateSlider({Name = "Shoot Range", Range = {30, 300}, Increment = 10, CurrentValue = 150, Callback = function(v) Config.Sheriff.ShootRange = v end})
mainTab:CreateToggle({Name = "Trigger-Happy Mode", CurrentValue = false, Callback = function(v) Config.Sheriff.TriggerHappy = v end})

mainTab:CreateSection("Murderer")
mainTab:CreateToggle({Name = "Auto-Kill", CurrentValue = true, Callback = function(v) Config.Murderer.AutoKill = v end})
mainTab:CreateSlider({Name = "Chase Speed", Range = {16, 120}, Increment = 1, CurrentValue = 50, Callback = function(v) Config.Murderer.ChaseSpeed = v end})
mainTab:CreateToggle({Name = "Avoid Sheriff", CurrentValue = true, Callback = function(v) Config.Murderer.SheriffAvoid = v end})

mainTab:CreateSection("Innocent")
mainTab:CreateToggle({Name = "Evade Murderer", CurrentValue = true, Callback = function(v) Config.Innocent.Evade = v end})
mainTab:CreateToggle({Name = "Collect Coins", CurrentValue = true, Callback = function(v) Config.Innocent.CollectCoins = v end})
mainTab:CreateSlider({Name = "Evade Distance", Range = {50, 300}, Increment = 10, CurrentValue = 120, Callback = function(v) Config.Innocent.EvadeDistance = v end})

mainTab:CreateSection("General")
mainTab:CreateToggle({Name = "Anti-Fall", CurrentValue = true, Callback = function(v) Config.AntiFall = v end})

local infoTab = Window:CreateTab("Info", nil)
infoTab:CreateSection("Status")
local statusP = infoTab:CreateParagraph({Title = "Bot Status", Content = "Role: Unknown\nTarget: None\nAlive: Yes"})

-- Status updater
task.spawn(function()
    while true do
        task.wait(1)
        local targetName = targetPlayer and targetPlayer.Name or "None"
        local isAlive = alive(LP) and "Yes" or "No"
        statusP:Set({
            Title = "Bot Status",
            Content = "Role: " .. role .. "\nTarget: " .. targetName .. "\nAlive: " .. isAlive .. "\n\nStats:\nKills: " .. report.kills .. "\nDeaths: " .. report.deaths .. "\nShots: " .. report.shots .. "\nCoins: " .. report.coins
        })
    end
end)

print("[MM2 Bot] Loaded - Role: " .. role)
return { Role = role, Config = Config }
