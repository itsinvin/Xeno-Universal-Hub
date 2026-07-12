-- MM2 Stealth Bot v2.0
-- Murder Mystery 2 (142823291)
-- Pure inject - no UI, human-like behavior, knife throw support
repeat task.wait() until game:IsLoaded()
if game.PlaceId ~= 142823291 then return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LP = Players.LocalPlayer
local VIM = game:GetService("VirtualInputManager")
local UIS = game:GetService("UserInputService")
local Camera = Workspace.CurrentCamera

repeat task.wait() until LP.Character

local role, prevRole, lastReaction, targetPlayer = "Unknown", "", 0, nil
local aiConns, dead = {}, false

local function gc(p) return p and p.Character end
local function hrp(p) local c = gc(p); return c and c:FindFirstChild("HumanoidRootPart") end
local function hum(p) local c = gc(p); return c and c:FindFirstChildOfClass("Humanoid") end
local function alive(p) local h = hum(p); return h and h.Health > 0 end

local function hasTool(p, name)
    for _, bag in ipairs({gc(p), p:FindFirstChild("Backpack")}) do
        if bag then for _, t in ipairs(bag:GetChildren()) do
            if t:IsA("Tool") and (not name or t.Name:lower():find(name:lower())) then return t end
        end end
    end
end

local function detect()
    if hasTool(LP, "Gun") and not hasTool(LP, "Knife") then return "Sheriff" end
    if hasTool(LP, "Knife") and not hasTool(LP, "Gun") then return "Murderer" end
    return "Innocent"
end

local function findMurderer()
    for _, p in ipairs(Players:GetPlayers()) do if p ~= LP and hasTool(p, "Knife") then return p end end
end

local function nearest(origin, filter)
    local ref = type(origin) == "userdata" and origin or hrp(origin)
    if not ref then return nil, math.huge end
    local best, bestD = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and (not filter or filter(p)) then
            local h = hrp(p)
            if h then
                local d = (ref.Position - h.Position).Magnitude
                if d < bestD then bestD = d; best = p end
            end
        end
    end
    return best, bestD
end

-- Human-like smooth rotation
local lastSmoothTick = 0
local smoothTarget = nil
local function smoothLookAt(pos)
    local rp = hrp(LP)
    if not rp then return end
    smoothTarget = pos
    local now = tick()
    local dt = math.min(now - lastSmoothTick, 0.1)
    lastSmoothTick = now
    local curDir = rp.CFrame.LookVector
    local targetDir = (pos - rp.Position).Unit
    if targetDir.Magnitude < 0.01 then return end
    local dot = math.clamp(curDir:Dot(targetDir), -1, 1)
    local angle = math.acos(dot)
    if angle < 0.02 then return end
    local cross = curDir:Cross(targetDir)
    local turnRate = 1.2 + math.random() * 0.6
    local step = math.min(angle, turnRate * dt)
    if cross.Magnitude > 0.001 then
        rp.CFrame = rp.CFrame * CFrame.fromAxisAngle(cross.Unit, step)
    end
end

-- Human-like movement: not perfectly straight, not always max speed
local function humanMove(targetPos, baseSpeed)
    local rp = hrp(LP); local h = hum(LP)
    if not rp or not h then return end
    local dir = (targetPos - rp.Position).Unit
    local speedVar = baseSpeed * (0.85 + math.random() * 0.3)
    local strafeOffset = Vector3.new(math.random(-6, 6) * 0.3, 0, math.random(-6, 6) * 0.3)
    h:MoveTo(rp.Position + dir * (baseSpeed * 0.5) + strafeOffset)
    h.WalkSpeed = speedVar
end

local function stop()
    local h = hum(LP)
    if h then local rp = hrp(LP); if rp then h:MoveTo(rp.Position) end end
end

local function tapKey(key, held)
    held = held or 0.05
    VIM:SendKeyEvent(true, key, false, game)
    task.wait(held)
    VIM:SendKeyEvent(false, key, false, game)
end

-- Human-like tool use: random micro-delay before action
local function useTool(tool)
    if not tool then return end
    task.wait(math.random() * 0.15)
    pcall(tool.Activate, tool)
end

-- Knife throw using Q key
local function throwKnife()
    pcall(function()
        local knife = hasTool(LP, "Knife")
        if knife then
            knife.Parent = LP.Character
            task.wait(0.05 + math.random() * 0.1)
            tapKey(Enum.KeyCode.Q, 0.08)
        end
    end)
end

local function groundBelow(pos, dist)
    local p = RaycastParams.new(); p.FilterType = Enum.RaycastFilterType.Blacklist
    p.FilterDescendantsInstances = {LP.Character}
    return Workspace:Raycast(pos, Vector3.new(0, -dist, 0), p) ~= nil
end

local function safeSpot()
    local rp = hrp(LP); if not rp then return end
    for _ = 1, 15 do
        local a = math.random() * math.pi * 2
        local r = math.random(15, 70)
        local c = rp.Position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
        if groundBelow(c + Vector3.new(0, 5, 0), 25) then return c end
    end
end

local function clear()
    for _, c in ipairs(aiConns) do pcall(c.Disconnect, c) end
    aiConns = {}; dead = false
end

-- ========== SHERIFF ==========
local function sheriffAI()
    local conn = RunService.Heartbeat:Connect(function()
        if role ~= "Sheriff" or not alive(LP) or dead then return end
        local gun = hasTool(LP, "Gun"); if not gun then return end
        local mur = findMurderer(); if not mur or not alive(mur) then return end
        local mHRP, myHRP = hrp(mur), hrp(LP)
        if not mHRP or not myHRP then return end
        local dist = (myHRP.Position - mHRP.Position).Magnitude
        targetPlayer = mur

        -- Human-like: don't perfectly track through walls
        local visible = true
        pcall(function()
            local p = RaycastParams.new(); p.FilterType = Enum.RaycastFilterType.Blacklist
            p.FilterDescendantsInstances = {LP.Character, mur.Character}
            local r = Workspace:Raycast(Camera.CFrame.Position, mHRP.Position - Camera.CFrame.Position, p)
            if r and r.Instance and not r.Instance:IsDescendantOf(mur.Character) then visible = false end
        end)

        if dist > 180 then
            -- Too far, move toward but don't run constantly
            if math.random() < 0.7 then humanMove(mHRP.Position, 18 + math.random() * 6) end
            smoothLookAt(mHRP.Position)
            return
        end

        -- Face target with human delay
        smoothLookAt(mHRP.Position)

        if dist <= 40 then
            -- Backpedal + shoot
            useTool(gun)
            local retreat = (myHRP.Position - mHRP.Position).Unit * 40
            humanMove(myHRP.Position + retreat, 16 + math.random() * 4)
        elseif dist <= 120 then
            -- Shoot and strafe
            if math.random() < 0.85 then useTool(gun) end
            local strafeDir = Camera.CFrame.RightVector * (math.random() > 0.5 and 1 or -1) * 15
            humanMove(mHRP.Position + strafeDir, 20 + math.random() * 4)
        else
            -- Approach
            humanMove(mHRP.Position, 26 + math.random() * 4)
        end

        -- Anti-fall
        if myHRP.Position.Y < -40 then
            local s = safeSpot(); if s then pcall(function() hrp(LP).CFrame = CFrame.new(s) end) end
        end
    end)
    table.insert(aiConns, conn)
end

-- ========== MURDERER ==========
local lastThrowTime = 0
local function murdererAI()
    local conn = RunService.Heartbeat:Connect(function()
        if role ~= "Murderer" or not alive(LP) or dead then return end
        local knife = hasTool(LP, "Knife"); if not knife then return end
        local myHRP = hrp(LP); if not myHRP then return end

        local target, dist = nearest(LP, function(p) return p ~= LP and alive(p) and not hasTool(p, "Knife") end)
        if not target then return end
        local tHRP = hrp(target); if not tHRP then return end
        targetPlayer = target

        -- Check for sheriff nearby
        local sheriff, sheriffDist = nearest(LP, function(p) return p ~= LP and hasTool(p, "Gun") and not hasTool(p, "Knife") end)
        if sheriff and sheriffDist < 100 then
            -- Sheriff close: take cover approach
            smoothLookAt(tHRP.Position)
            if sheriffDist < 50 then
                -- Retreat from sheriff, flank around
                local flankDir = (myHRP.Position - hrp(sheriff).Position).Unit
                local flankTarget = myHRP.Position + flankDir * 80 + Camera.CFrame.RightVector * 20
                humanMove(flankTarget, 30 + math.random() * 6)
                return
            end
        end

        -- Decision: throw or stab?
        local now = tick()
        local canThrow = now - lastThrowTime > 6 + math.random() * 3

        smoothLookAt(tHRP.Position)

        if dist <= 14 then
            -- Stab range
            useTool(knife)
            -- Brief pause after stab (human cooldown feel)
            task.wait(math.random() * 0.12)
        elseif dist <= 60 and canThrow then
            -- Throw knife at range
            -- Lead the target slightly
            local leadPos = tHRP.Position + (tHRP.Velocity or Vector3.new()) * 0.3
            smoothLookAt(leadPos)
            throwKnife()
            lastThrowTime = now
            -- Pause after throw
            task.wait(0.2 + math.random() * 0.15)
        else
            -- Chase with human-like variation
            local approachSpeed = 18 + math.random() * 10
            -- Sometimes stop briefly to look around (human behavior)
            if math.random() < 0.05 then stop(); task.wait(0.1 + math.random() * 0.2) end
            humanMove(tHRP.Position, approachSpeed)
        end

        -- Anti-fall
        if myHRP.Position.Y < -40 then
            local s = safeSpot(); if s then pcall(function() hrp(LP).CFrame = CFrame.new(s) end) end
        end
    end)
    table.insert(aiConns, conn)

    -- Keep walkspeed natural
    local speedConn = RunService.RenderStepped:Connect(function()
        if role ~= "Murderer" or not alive(LP) then return end
        local h = hum(LP)
        if h then
            local target = h.WalkSpeed
            if target > 16 then
                h.WalkSpeed = h.WalkSpeed + (target - h.WalkSpeed) * 0.3
            end
        end
    end)
    table.insert(aiConns, speedConn)
end

-- ========== INNOCENT ==========
local lastLookAround = 0
local function innocentAI()
    local conn = RunService.Heartbeat:Connect(function()
        if role ~= "Innocent" or not alive(LP) or dead then return end
        local myHRP = hrp(LP); if not myHRP then return end

        local murderer = findMurderer()
        local mHRP = murderer and hrp(murderer)
        local distToMurderer = mHRP and (myHRP.Position - mHRP.Position).Magnitude or math.huge

        -- Occasionally look around (human behavior)
        local now = tick()
        if now - lastLookAround > 3 + math.random() * 5 then
            lastLookAround = now
            local randomLook = Camera.CFrame.Position + Camera.CFrame.LookVector * 50
                + Vector3.new(math.random(-30, 30), math.random(-10, 10), math.random(-30, 30))
            smoothLookAt(randomLook)
            return
        end

        if mHRP and distToMurderer < 110 then
            -- Evade: run away but not perfectly
            local escapeDir = (myHRP.Position - mHRP.Position).Unit
            local escapePos = myHRP.Position + escapeDir * 140
            if not groundBelow(escapePos + Vector3.new(0, 5, 0), 40) then
                for angle = 0, 360, 45 do
                    local a = math.rad(angle + math.random() * 20)
                    local altDir = Vector3.new(math.cos(a), 0, math.sin(a))
                    local altPos = myHRP.Position + altDir * 80
                    if groundBelow(altPos + Vector3.new(0, 5, 0), 40) then escapePos = altPos; break end
                end
            end
            smoothLookAt(escapePos)
            humanMove(escapePos, 22 + math.random() * 6)
            return
        end

        -- Collect coins
        local nearestCoin, coinDist = nil, math.huge
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v:IsA("BasePart") and (v.Name:find("[Cc]oin") or v.Name:find("[Gg]old")) then
                local d = (myHRP.Position - v.Position).Magnitude
                if d < coinDist then coinDist = d; nearestCoin = v end
            end
        end

        if nearestCoin and coinDist < 50 then
            smoothLookAt(nearestCoin.Position)
            humanMove(nearestCoin.Position, 16 + math.random() * 4)
            return
        end

        -- Wander toward other players (safety in numbers) but not too close
        local nearestPlayer, nearestDist = nearest(LP, function(p) return p ~= LP and alive(p) end)
        if nearestPlayer and nearestDist > 50 then
            local nHRP = hrp(nearestPlayer)
            if nHRP then
                -- Approach slightly off-center (not directly at them)
                local offset = Vector3.new(math.random(-20, 20), 0, math.random(-20, 20))
                smoothLookAt(nHRP.Position + offset)
                humanMove(nHRP.Position + offset, 16 + math.random() * 4)
                return
            end
        end

        -- Random wander with ground check
        local randDir = Vector3.new(math.random(-60, 60), 0, math.random(-60, 60))
        local wanderPos = myHRP.Position + randDir
        if groundBelow(wanderPos + Vector3.new(0, 5, 0), 20) then
            smoothLookAt(wanderPos)
            humanMove(wanderPos, 14 + math.random() * 4)
        end

        -- Anti-fall
        if myHRP.Position.Y < -40 then
            local s = safeSpot(); if s then pcall(function() hrp(LP).CFrame = CFrame.new(s) end) end
        end
    end)
    table.insert(aiConns, conn)

    -- Human-like occasional jump (not every frame)
    local jumpConn = RunService.Heartbeat:Connect(function()
        if role ~= "Innocent" or not alive(LP) or dead then return end
        local h = hum(LP)
        if h and h.FloorMaterial and h.FloorMaterial ~= Enum.Material.Air and math.random() < 0.03 then
            h:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)
    table.insert(aiConns, jumpConn)
end

-- ========== ROLE MONITOR ==========
task.spawn(function()
    while true do
        task.wait(0.6 + math.random() * 0.3)
        if alive(LP) then
            local nr = detect()
            if nr ~= prevRole then
                prevRole = nr; role = nr; clear()
                if role == "Sheriff" then sheriffAI()
                elseif role == "Murderer" then murdererAI()
                else innocentAI() end
            end
        end
    end
end)

-- Death tracking
local function onLPDeath()
    local h = hum(LP)
    if h then h.Died:Connect(function() dead = true; clear() end) end
end
onLPDeath()
LP.CharacterAdded:Connect(function() task.wait(0.6); dead = false; onLPDeath() end)

print("[MM2 Bot] Stealth mode - no UI. Role: " .. detect())
