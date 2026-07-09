-- Xeno Universal Hub v3.0
-- Rayfield UI + IY-Style Command System
local XenoHub = {}
XenoHub.Version = "3.0"
XenoHub.CurrentGame = ""
XenoHub.Flags = {}
XenoHub.Cmds = {}
XenoHub.Aliases = {}
XenoHub.Waypoints = {}
XenoHub.Binds = {}
XenoHub.CmdHistory = {}
XenoHub.Prefix = ";"

if getgenv and getgenv().XENO_HUB_LOADED then return end
if getgenv then
    getgenv().XENO_HUB_LOADED = true
    getgenv().XENO_HUB_INSTANCE = XenoHub
end

-- Load Rayfield
local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua"))()

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")
local StatsService = game:GetService("Stats")
local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()
local Camera = Workspace.CurrentCamera

-- Game detection
local GameIDs = {
    MM2 = {1275914089, 2184756954, 232432321},
    Jailbreak = {606849621, 986635478},
    Arsenal = {286090429},
    BloxFruits = {2753915549},
    PetSimulator99 = {1607359912},
    TowerDefenseSim = {3260590327},
    Doors = {6516141723},
    Bedwars = {6872265039},
    Brookhaven = {6135835895},
    DaHood = {11711189196, 2788229376},
    Piggy = {5546768490, 5716188924},
}
local PlaceId = game.PlaceId
for name, ids in pairs(GameIDs) do
    if type(ids) == "table" then
        for _, id in ipairs(ids) do
            if PlaceId == id then XenoHub.CurrentGame = name; break end
        end
    elseif PlaceId == ids then XenoHub.CurrentGame = name; break end
end
if XenoHub.CurrentGame == "" then XenoHub.CurrentGame = "Unknown" end

-- Player selector
function XenoHub:ParsePlayers(input)
    local results = {}
    if not input or input == "" then return {LP} end
    local function matchPlayer(name)
        local p = Players:FindFirstChild(name)
        if p then return p end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Name:lower():sub(1, #name) == name:lower() then return plr end
        end
    end
    local parts = {}
    for part in input:gmatch("[^,]+") do
        table.insert(parts, part:match("^%s*(.-)%s*$"))
    end
    for _, part in ipairs(parts) do
        local exclude = false
        local term = part
        if term:sub(1,1) == "-" then exclude = true; term = term:sub(2) end
        if term:sub(1,1) == "+" then term = term:sub(2) end
        local matched = {}
        if term == "all" then matched = Players:GetPlayers()
        elseif term == "others" then for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then table.insert(matched, p) end end
        elseif term == "me" then matched = {LP}
        elseif term == "random" then local pool = Players:GetPlayers(); if #pool > 0 then matched = {pool[math.random(1, #pool)]} end
        elseif term == "nearest" then
            local closest, bestDist; local myPos = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if myPos then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        local d = (myPos.Position - p.Character.HumanoidRootPart.Position).Magnitude
                        if d < (bestDist or math.huge) then bestDist = d; closest = p end
                    end
                end
            end
            if closest then matched = {closest} end
        elseif term == "farthest" then
            local farthest, bestDist; local myPos = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if myPos then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        local d = (myPos.Position - p.Character.HumanoidRootPart.Position).Magnitude
                        if d > (bestDist or 0) then bestDist = d; farthest = p end
                    end
                end
            end
            if farthest then matched = {farthest} end
        elseif term:sub(1,1) == "#" then
            local n = tonumber(term:sub(2)) or 1; local pool = {}
            for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then table.insert(pool, p) end end
            for i = 1, math.min(n, #pool) do local idx = math.random(1, #pool); table.insert(matched, pool[idx]); table.remove(pool, idx) end
        elseif term:sub(1,1) == "%" then
            local teamName = term:sub(2)
            for _, p in ipairs(Players:GetPlayers()) do if p.Team and p.Team.Name:lower() == teamName:lower() then table.insert(matched, p) end end
        elseif term == "alive" then for _, p in ipairs(Players:GetPlayers()) do if p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then table.insert(matched, p) end end
        elseif term == "dead" then for _, p in ipairs(Players:GetPlayers()) do if not p.Character or not p.Character:FindFirstChild("Humanoid") or p.Character.Humanoid.Health <= 0 then table.insert(matched, p) end end
        elseif term:sub(1,6) == "group:" then local gid = term:sub(7); for _, p in ipairs(Players:GetPlayers()) do if p:IsInGroup(gid) then table.insert(matched, p) end end
        else local p = matchPlayer(term); if p then matched = {p} end end
        if exclude then
            local excludeMap = {}; for _, p in ipairs(matched) do excludeMap[p] = true end
            local filtered = {}; for _, p in ipairs(results) do if not excludeMap[p] then table.insert(filtered, p) end end; results = filtered
        else
            for _, p in ipairs(matched) do local found = false; for _, r in ipairs(results) do if r == p then found = true; break end end; if not found then table.insert(results, p) end end
        end
    end
    if #results == 0 then results = {LP} end
    return results
end

-- Command system
local function splitArgs(str) local args = {}; for word in str:gmatch("%S+") do table.insert(args, word) end; return args end
function XenoHub:AddCmd(name, aliases, desc, func)
    self.Cmds[name] = {func = func, desc = desc, aliases = aliases or {}}
    for _, alias in ipairs(aliases or {}) do self.Aliases[alias] = name end
end
function XenoHub:ExecCmd(input, speaker)
    speaker = speaker or LP; if not input or input == "" then return end
    if input:find("\\") then for part in input:gmatch("[^\\]+") do self:ExecCmd(part:match("^%s*(.-)%s*$"), speaker) end; return end
    local loopMatch = input:match("^(%d+%^%d+%.?%d*%^.+)$") or input:match("^(inf%^%d+%.?%d*%^.+)$")
    if loopMatch then
        local countStr, delayStr, cmd = loopMatch:match("^(.-)%^(.-)%^(.+)$"); local count = countStr == "inf" and -1 or tonumber(countStr); local delay = tonumber(delayStr) or 1
        local loopCount = 0; task.spawn(function() while loopCount < count or count < 0 do if count > 0 then loopCount = loopCount + 1 end; XenoHub:ExecCmd(cmd, speaker); task.wait(delay) end end); return
    end
    local args = splitArgs(input); local cmdName = args[1]:lower(); table.remove(args, 1)
    if self.Aliases[cmdName] then cmdName = self.Aliases[cmdName] end
    table.insert(self.CmdHistory, input); if #self.CmdHistory > 30 then table.remove(self.CmdHistory, 1) end
    local cmd = self.Cmds[cmdName]
    if cmd then local success, err = pcall(cmd.func, args, speaker); if not success then warn("[XenoHub] Command error: " .. tostring(err)) end
    else warn("[XenoHub] Unknown command: " .. cmdName) end
end

-- Notify helper (Rayfield)
function XenoHub:Notify(title, text, len)
    Rayfield:Notify({Title = title or "Xeno Hub", Content = text or "", Duration = len or 5})
end

-- Fly physics
local flyConn
local function startFlyPhysics()
    if flyConn then flyConn:Disconnect() end
    flyConn = RunService.RenderStepped:Connect(function()
        if not XenoHub.Flags.fly then return end
        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local bv = hrp:FindFirstChild("XenoFly")
        if bv then
            local dir = Vector3.new(0, 0, 0)
            if XenoHub.Flags.fly_up then dir = dir + Vector3.new(0, 1, 0) end
            if XenoHub.Flags.fly_down then dir = dir + Vector3.new(0, -1, 0) end
            local camLook = Camera.CFrame.LookVector
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + camLook end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - camLook end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + Camera.CFrame.RightVector end
            if dir.Magnitude > 0 then dir = dir.Unit * (XenoHub.Flags.fly_speed or 50) end
            bv.Velocity = dir
        end
    end)
end
local function stopFlyPhysics()
    if flyConn then flyConn:Disconnect(); flyConn = nil end
end

-- Teleport
function XenoHub:Teleport(pos)
    local char = LP.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFrame.new(pos)
    end
end

-- fireTouchinterest wrapper
local function fireTouch(a, b, t)
    pcall(function()
        if firetouchinterest then return firetouchinterest(a, b, t) end
        local con; con = a.Touched:Connect(function(h) if h == b then con:Disconnect() end end)
    end)
end

-- === COMMANDS ===
XenoHub:AddCmd("fly", {"fly"}, "Toggle fly mode", function(args)
    local spd = tonumber(args[1]) or 50
    XenoHub.Flags.fly = not XenoHub.Flags.fly
    XenoHub.Flags.fly_speed = spd
    local char = LP.Character; if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart"); local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    if XenoHub.Flags.fly then
        hum.PlatformStand = true
        local bv = Instance.new("BodyVelocity"); bv.Name = "XenoFly"; bv.MaxForce = Vector3.new(100000, 100000, 100000); bv.Velocity = Vector3.new(0,0,0); bv.Parent = hrp
        startFlyPhysics()
    else
        hum.PlatformStand = false; stopFlyPhysics(); local bv = hrp:FindFirstChild("XenoFly"); if bv then bv:Destroy() end
    end
end)
XenoHub:AddCmd("unfly", {"nofly"}, "Disable fly", function()
    XenoHub.Flags.fly = false; stopFlyPhysics()
    local char = LP.Character
    if char then
        local hum = char:FindFirstChild("Humanoid"); if hum then hum.PlatformStand = false end
        local hrp = char:FindFirstChild("HumanoidRootPart"); if hrp then local bv = hrp:FindFirstChild("XenoFly"); if bv then bv:Destroy() end end
    end
end)
XenoHub:AddCmd("noclip", {"clip"}, "Toggle noclip", function()
    XenoHub.Flags.noclip = not XenoHub.Flags.noclip
    if XenoHub.Flags.noclip and not XenoHub.Flags.noclip_conn then
        XenoHub.Flags.noclip_conn = RunService.Stepped:Connect(function()
            if XenoHub.Flags.noclip and LP.Character then
                for _, part in ipairs(LP.Character:GetChildren()) do if part:IsA("BasePart") then part.CanCollide = false end end
            end
        end)
    end
end)
XenoHub:AddCmd("speed", {"ws", "walkspeed"}, "Set walkspeed", function(args)
    local speed = tonumber(args[1]) or 16; local char = LP.Character
    if char and char:FindFirstChild("Humanoid") then char.Humanoid.WalkSpeed = speed end
end)
XenoHub:AddCmd("jumppower", {"jp", "jpower"}, "Set jump power", function(args)
    local power = tonumber(args[1]) or 50; local char = LP.Character
    if char and char:FindFirstChild("Humanoid") then char.Humanoid.JumpPower = power end
end)
XenoHub:AddCmd("gravity", {"grav"}, "Set gravity", function(args)
    Workspace.Gravity = tonumber(args[1]) or 196.2
end)
XenoHub:AddCmd("hipheight", {"hheight"}, "Set hip height", function(args)
    local h = tonumber(args[1]) or 0; local char = LP.Character
    if char and char:FindFirstChild("Humanoid") then char.Humanoid.HipHeight = h end
end)
XenoHub:AddCmd("infinitejump", {"infjump", "infj"}, "Toggle infinite jump", function()
    XenoHub.Flags.infjump = not XenoHub.Flags.infjump
    if XenoHub.Flags.infjump and not XenoHub.Flags.infjump_conn then
        XenoHub.Flags.infjump_conn = UserInputService.JumpRequest:Connect(function()
            if XenoHub.Flags.infjump and LP.Character and LP.Character:FindFirstChild("Humanoid") then LP.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end
        end)
    end
end)
XenoHub:AddCmd("antivoid", {}, "Prevent void fall", function()
    XenoHub.Flags.antivoid = not XenoHub.Flags.antivoid
    if XenoHub.Flags.antivoid and not XenoHub.Flags.antivoid_conn then
        XenoHub.Flags.antivoid_conn = RunService.RenderStepped:Connect(function()
            if XenoHub.Flags.antivoid and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = LP.Character.HumanoidRootPart
                if hrp.Position.Y < -50 then hrp.CFrame = hrp.CFrame * CFrame.new(0, 100, 0); hrp.AssemblyLinearVelocity = Vector3.new(0, 50, 0) end
            end
        end)
    end
end)

XenoHub:AddCmd("goto", {"to", "tp"}, "Teleport to a player", function(args)
    if not args[1] then return end; local targets = XenoHub:ParsePlayers(args[1]); local char = LP.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    for _, target in ipairs(targets) do if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then char.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 3, 0); break end end
end)
XenoHub:AddCmd("tweengoto", {"tgoto", "tweento", "tto"}, "Tween teleport to player", function(args)
    if not args[1] then return end; local targets = XenoHub:ParsePlayers(args[1]); local char = LP.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    for _, target in ipairs(targets) do
        if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear); local tween = TweenService:Create(char.HumanoidRootPart, tweenInfo, {CFrame = target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 3, 0)}); tween:Play(); break
        end
    end
end)
XenoHub:AddCmd("tpposition", {"tppos"}, "TP to coordinates", function(args)
    if #args < 3 then return end; local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3]); local char = LP.Character
    if char and char:FindFirstChild("HumanoidRootPart") then char.HumanoidRootPart.CFrame = CFrame.new(x, y, z) end
end)
XenoHub:AddCmd("waypoint", {"wp"}, "Set or teleport to waypoint", function(args)
    if not args[1] then for name, pos in pairs(XenoHub.Waypoints) do XenoHub:Notify("Waypoint", name .. ": " .. tostring(pos), 3) end; return end
    local name = args[1]; local char = LP.Character; local hasPos = char and char:FindFirstChild("HumanoidRootPart")
    if args[2] == "set" then if hasPos then XenoHub.Waypoints[name] = char.HumanoidRootPart.Position; XenoHub:Notify("Waypoint", "Saved: " .. name, 3) end
    elseif XenoHub.Waypoints[name] then if hasPos then char.HumanoidRootPart.CFrame = CFrame.new(XenoHub.Waypoints[name]); XenoHub:Notify("Waypoint", "Teleported to: " .. name, 3) end
    elseif hasPos then XenoHub.Waypoints[name] = char.HumanoidRootPart.Position; XenoHub:Notify("Waypoint", "Saved: " .. name, 3) end
end)
XenoHub:AddCmd("offset", {}, "Offset position by X Y Z", function(args)
    if #args < 3 then return end; local char = LP.Character
    if char and char:FindFirstChild("HumanoidRootPart") then char.HumanoidRootPart.CFrame = char.HumanoidRootPart.CFrame + Vector3.new(tonumber(args[1]) or 0, tonumber(args[2]) or 0, tonumber(args[3]) or 0) end
end)
XenoHub:AddCmd("notifyposition", {"getpos", "getposition"}, "Get position", function(args)
    local target = LP; if args[1] then local targets = XenoHub:ParsePlayers(args[1]); if #targets > 0 then target = targets[1] end end
    if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then local pos = target.Character.HumanoidRootPart.Position; XenoHub:Notify("Position", target.Name .. ": " .. string.format("%.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z), 3) end
end)
XenoHub:AddCmd("clientbring", {"cbring"}, "Bring a player to you", function(args)
    if not args[1] then return end; local targets = XenoHub:ParsePlayers(args[1]); local char = LP.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    for _, target in ipairs(targets) do if target ~= LP and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then target.Character.HumanoidRootPart.CFrame = char.HumanoidRootPart.CFrame * CFrame.new(0, 3, 3) end end
end)
XenoHub:AddCmd("lookat", {"stare", "stareat"}, "Look at a player", function(args)
    if not args[1] then return end; local targets = XenoHub:ParsePlayers(args[1]); if #targets == 0 then return end
    local target = targets[1]; XenoHub.Flags.lookat_target = target
    if not XenoHub.Flags.lookat_conn then
        XenoHub.Flags.lookat_conn = RunService.RenderStepped:Connect(function()
            if XenoHub.Flags.lookat_target and XenoHub.Flags.lookat_target.Character and XenoHub.Flags.lookat_target.Character:FindFirstChild("Head") then Camera.CFrame = CFrame.new(Camera.CFrame.Position, XenoHub.Flags.lookat_target.Character.Head.Position) end
        end)
    end
end)
XenoHub:AddCmd("unlookat", {"unstare", "nostare"}, "Stop looking", function()
    XenoHub.Flags.lookat_target = nil; if XenoHub.Flags.lookat_conn then XenoHub.Flags.lookat_conn:Disconnect(); XenoHub.Flags.lookat_conn = nil end
end)

XenoHub:AddCmd("reset", {}, "Reset character", function()
    local char = LP.Character; if char and char:FindFirstChild("Humanoid") then char.Humanoid.Health = 0 end; pcall(function() LP:LoadCharacter() end)
end)
XenoHub:AddCmd("sit", {}, "Make character sit", function()
    local char = LP.Character; if char and char:FindFirstChild("Humanoid") then char.Humanoid.Sit = true end
end)
XenoHub:AddCmd("god", {}, "Make character hard to kill", function()
    local char = LP.Character
    if char then
        local hum = char:FindFirstChild("Humanoid"); if hum then hum.MaxHealth = math.huge; hum.Health = math.huge end
        for _, part in ipairs(char:GetChildren()) do if part:IsA("BasePart") then part.Massless = true end end
    end
end)
XenoHub:AddCmd("spin", {}, "Spin your character", function(args)
    local speed = tonumber(args[1]) or 20; XenoHub.Flags.spin = not XenoHub.Flags.spin
    if XenoHub.Flags.spin then
        XenoHub.Flags.spin_conn = RunService.RenderStepped:Connect(function()
            if XenoHub.Flags.spin and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then LP.Character.HumanoidRootPart.CFrame = LP.Character.HumanoidRootPart.CFrame * CFrame.Angles(0, math.rad(speed), 0) end
        end)
    elseif XenoHub.Flags.spin_conn then XenoHub.Flags.spin_conn:Disconnect() end
end)
XenoHub:AddCmd("invisible", {"invis"}, "Toggle invisibility", function()
    XenoHub.Flags.invisible = not XenoHub.Flags.invisible; local char = LP.Character; if not char then return end
    for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then part.Transparency = XenoHub.Flags.invisible and 1 or 0 end; if part:IsA("Decal") then part.Transparency = XenoHub.Flags.invisible and 1 or 0 end end
    local hl = char:FindFirstChild("Highlight"); if hl then hl.Enabled = not XenoHub.Flags.invisible end
end)
XenoHub:AddCmd("headsize", {}, "Set head size", function(args)
    local size = tonumber(args[1]) or 5; local char = LP.Character; if char and char:FindFirstChild("Head") then char.Head.Size = Vector3.new(size, size, size) end
end)
XenoHub:AddCmd("noface", {"removeface"}, "Remove face", function()
    local char = LP.Character; if char and char:FindFirstChild("Head") then for _, child in ipairs(char.Head:GetChildren()) do if child:IsA("Decal") then child:Destroy() end end end
end)
XenoHub:AddCmd("noarms", {"rarms"}, "Remove arms", function()
    local char = LP.Character; if char then local left = char:FindFirstChild("Left Arm") or char:FindFirstChild("LeftHand"); local right = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand"); if left then left.Transparency = 1 end; if right then right.Transparency = 1 end end
end)
XenoHub:AddCmd("nolegs", {"rlegs"}, "Remove legs", function()
    local char = LP.Character; if char then local left = char:FindFirstChild("Left Leg") or char:FindFirstChild("LeftFoot"); local right = char:FindFirstChild("Right Leg") or char:FindFirstChild("RightFoot"); if left then left.Transparency = 1 end; if right then right.Transparency = 1 end end
end)
XenoHub:AddCmd("blockhead", {}, "Make head a block", function()
    local char = LP.Character; if char and char:FindFirstChild("Head") then char.Head.MeshId = ""; char.Head.Shape = Enum.PartType.Block; char.Head.Size = Vector3.new(2, 2, 2) end
end)

XenoHub:AddCmd("esp", {}, "Toggle player ESP", function()
    XenoHub.Flags.esp_enabled = not XenoHub.Flags.esp_enabled
    if XenoHub.Flags.esp_enabled then
        for _, p in ipairs(Players:GetPlayers()) do if p ~= LP and p.Character and not p.Character:FindFirstChild("XenoESP") then local hl = Instance.new("Highlight"); hl.Name = "XenoESP"; hl.FillColor = Color3.fromRGB(255, 50, 50); hl.OutlineColor = Color3.fromRGB(255, 255, 255); hl.FillTransparency = 0.5; hl.Adornee = p.Character; hl.Parent = p.Character end end
    else
        for _, p in ipairs(Players:GetPlayers()) do if p.Character then local hl = p.Character:FindFirstChild("XenoESP"); if hl then hl:Destroy() end end end
    end
end)
XenoHub:AddCmd("xray", {}, "Toggle X-Ray", function()
    XenoHub.Flags.xray = not XenoHub.Flags.xray
    for _, v in ipairs(Workspace:GetDescendants()) do if v:IsA("BasePart") and not v:IsA("Terrain") then v.LocalTransparencyModifier = XenoHub.Flags.xray and 0.7 or 0 end end
end)
XenoHub:AddCmd("fullbright", {"fb"}, "Toggle fullbright", function()
    XenoHub.Flags.fullbright = not XenoHub.Flags.fullbright
    if XenoHub.Flags.fullbright then Lighting.Ambient = Color3.fromRGB(255, 255, 255); Lighting.Brightness = 2; Lighting.FogEnd = 100000; Lighting.GlobalShadows = false
    else Lighting.Ambient = Color3.fromRGB(80, 80, 80); Lighting.Brightness = 1; Lighting.FogEnd = 786432; Lighting.GlobalShadows = true end
end)
XenoHub:AddCmd("fov", {}, "Set field of view", function(args) Camera.FieldOfView = tonumber(args[1]) or 90 end)
XenoHub:AddCmd("freecam", {"fc"}, "Toggle freecam", function()
    XenoHub.Flags.freecam = not XenoHub.Flags.freecam
    if XenoHub.Flags.freecam then
        XenoHub.Flags.freecam_cam = Instance.new("Camera"); XenoHub.Flags.freecam_cam.Name = "XenoFreeCam"; XenoHub.Flags.freecam_cam.CFrame = Camera.CFrame; XenoHub.Flags.freecam_cam.Parent = Workspace.CurrentCamera; Camera.CameraType = Enum.CameraType.Scriptable
        XenoHub.Flags.freecam_conn = RunService.RenderStepped:Connect(function()
            if XenoHub.Flags.freecam then
                local speed = 20; local move = Vector3.new(0, 0, 0)
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + XenoHub.Flags.freecam_cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - XenoHub.Flags.freecam_cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - XenoHub.Flags.freecam_cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + XenoHub.Flags.freecam_cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0, 1, 0) end
                if move.Magnitude > 0 then XenoHub.Flags.freecam_cam.CFrame = XenoHub.Flags.freecam_cam.CFrame + move.Unit * speed end; Camera.CFrame = XenoHub.Flags.freecam_cam.CFrame
            end
        end)
    else
        if XenoHub.Flags.freecam_conn then XenoHub.Flags.freecam_conn:Disconnect() end; if XenoHub.Flags.freecam_cam then XenoHub.Flags.freecam_cam:Destroy() end; Camera.CameraType = Enum.CameraType.Custom
    end
end)
XenoHub:AddCmd("hitbox", {"hitboxexpand"}, "Expand hitbox of a player", function(args)
    if not args[1] then return end; local targets = XenoHub:ParsePlayers(args[1]); local size = Vector3.new(tonumber(args[2]) or 10, tonumber(args[2]) or 10, tonumber(args[2]) or 10)
    for _, p in ipairs(targets) do if p.Character then for _, part in ipairs(p.Character:GetDescendants()) do if part:IsA("BasePart") then part.Size = size end end end end
end)
XenoHub:AddCmd("ambient", {}, "Set ambient color", function(args) if #args < 3 then return end; Lighting.Ambient = Color3.fromRGB(tonumber(args[1]) or 255, tonumber(args[2]) or 255, tonumber(args[3]) or 255) end)
XenoHub:AddCmd("day", {}, "Client-side day", function() Lighting.ClockTime = 12 end)
XenoHub:AddCmd("night", {}, "Client-side night", function() Lighting.ClockTime = 0 end)
XenoHub:AddCmd("nofog", {}, "Remove fog", function() Lighting.FogEnd = 100000; Lighting.FogStart = 100000 end)

XenoHub:AddCmd("chat", {"say"}, "Send chat message", function(args)
    local text = table.concat(args, " "); if text == "" then return end
    pcall(function() local sayReq = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents"); if sayReq then sayReq = sayReq:FindFirstChild("SayMessageRequest") end; if sayReq then sayReq:FireServer(text, "All") end end)
end)
XenoHub:AddCmd("spam", {}, "Spam chat messages", function(args)
    local text = table.concat(args, " "); if text == "" then text = "Xeno Hub owns!" end; XenoHub.Flags.spam = not XenoHub.Flags.spam
    if XenoHub.Flags.spam then
        local sayReq = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents"); if sayReq then sayReq = sayReq:FindFirstChild("SayMessageRequest") end
        XenoHub.Flags.spam_conn = RunService.Heartbeat:Connect(function() if not XenoHub.Flags.spam then XenoHub.Flags.spam_conn:Disconnect() return end; pcall(function() if sayReq then sayReq:FireServer(text, "All") end end); task.wait(0.3) end)
    end
end)
XenoHub:AddCmd("unspam", {"nospam"}, "Stop spam", function() XenoHub.Flags.spam = false; if XenoHub.Flags.spam_conn then XenoHub.Flags.spam_conn:Disconnect() end end)

XenoHub:AddCmd("fling", {}, "Toggle fling", function()
    XenoHub.Flags.fling = not XenoHub.Flags.fling
    if XenoHub.Flags.fling then
        XenoHub.Flags.fling_conn = RunService.Stepped:Connect(function()
            if XenoHub.Flags.fling and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = LP.Character.HumanoidRootPart; hrp.RotVelocity = Vector3.new(200, 200, 200)
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        local target = p.Character.HumanoidRootPart
                        if (target.Position - hrp.Position).Magnitude < 10 then target.CFrame = CFrame.new(target.Position) * CFrame.Angles(math.rad(45), 0, 0); target.AssemblyLinearVelocity = Vector3.new(0, 100, 0) end
                    end
                end
            end
        end)
    else
        if XenoHub.Flags.fling_conn then XenoHub.Flags.fling_conn:Disconnect() end; if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then LP.Character.HumanoidRootPart.RotVelocity = Vector3.new(0, 0, 0) end
    end
end)
XenoHub:AddCmd("antifling", {}, "Toggle anti-fling", function() -- pcall handles missing getrawmetatable
    XenoHub.Flags.antifling = not XenoHub.Flags.antifling
    if XenoHub.Flags.antifling then
        pcall(function()
            local mt = getrawmetatable(game); XenoHub.Flags.antifling_old = mt.__index; setreadonly(mt, false)
            mt.__index = newcclosure(function(self, key) if key == "CanCollide" and self:IsA("BasePart") and self.Parent == LP.Character then return false end; return XenoHub.Flags.antifling_old(self, key) end)
            setreadonly(mt, true)
        end)
    else
        pcall(function() local mt = getrawmetatable(game); if XenoHub.Flags.antifling_old then setreadonly(mt, false); mt.__index = XenoHub.Flags.antifling_old; setreadonly(mt, true); XenoHub.Flags.antifling_old = nil end end)
    end
end)
XenoHub:AddCmd("handlekill", {"hkill"}, "Kill player with tool", function(args)
    if not args[1] then return end; local targets = XenoHub:ParsePlayers(args[1]); local radius = tonumber(args[2]) or 10; local char = LP.Character; if not char then return end
    local tool = char:FindFirstChildOfClass("Tool"); if not tool then tool = LP.Backpack:FindFirstChildOfClass("Tool") end; if not tool then XenoHub:Notify("Kill", "Need a tool!", 3); return end
    tool.Parent = char; task.wait(0.1)
    for _, p in ipairs(targets) do if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then local targetPos = p.Character.HumanoidRootPart.Position; local hrp = char:FindFirstChild("HumanoidRootPart"); if hrp and (targetPos - hrp.Position).Magnitude <= radius then fireTouch(tool.Handle, p.Character.HumanoidRootPart, 0); task.wait(0.1); fireTouch(tool.Handle, p.Character.HumanoidRootPart, 1) end end end
end)

XenoHub:AddCmd("rejoin", {"rj"}, "Rejoin the game", function() TeleportService:Teleport(PlaceId, LP) end)
XenoHub:AddCmd("serverhop", {"shop"}, "Server hop", function()
    local cursor = ""
    for i = 1, 10 do
        local suc, res = pcall(function() local url = "https://apis.roblox.com/universes/v1/places/" .. PlaceId .. "/servers/Public?limit=100"; if cursor ~= "" then url = url .. "&cursor=" .. cursor end; return game:HttpGet(url) end)
        if suc then
            local suc2, decoded = pcall(function() return HttpService:JSONDecode(res) end)
            if suc2 and decoded and decoded.data then
                for _, server in ipairs(decoded.data) do if server.id ~= game.JobId then TeleportService:TeleportToPlaceInstance(PlaceId, server.id, LP); return end end
            end
            if decoded then cursor = decoded.nextPageCursor or "" end; if cursor == "" then break end
        else break end
    end
    XenoHub:Notify("Server Hop", "No other servers found", 3)
end)
XenoHub:AddCmd("antiafk", {"antiidle"}, "Toggle anti-AFK", function()
    XenoHub.Flags.antiafk = not XenoHub.Flags.antiafk
    if XenoHub.Flags.antiafk and not XenoHub.Flags.antiafk_conn then
        XenoHub.Flags.antiafk_conn = RunService.Heartbeat:Connect(function()
            if XenoHub.Flags.antiafk then
                local char = LP.Character; if char and char:FindFirstChild("Humanoid") then char.Humanoid:ChangeState(Enum.HumanoidStateType.RunningNoPhysics) end
                VirtualInputManager:SendMouseMoveEvent(0, 0, false); task.wait(5)
            end
        end)
    elseif not XenoHub.Flags.antiafk and XenoHub.Flags.antiafk_conn then XenoHub.Flags.antiafk_conn:Disconnect(); XenoHub.Flags.antiafk_conn = nil end
end)
XenoHub:AddCmd("exit", {}, "Exit Roblox", function() game:Shutdown() end)
XenoHub:AddCmd("serverinfo", {"sinfo", "info"}, "Show server info", function() XenoHub:Notify("Server Info", "Place: " .. PlaceId .. " | Job: " .. game.JobId .. " | Players: " .. #Players:GetPlayers(), 5) end)
XenoHub:AddCmd("jobid", {}, "Copy JobId", function() pcall(function() setclipboard(game.JobId) end); XenoHub:Notify("JobID", "Copied to clipboard", 3) end)

XenoHub:AddCmd("killall", {}, "Kill all players", function()
    for _, p in ipairs(Players:GetPlayers()) do if p ~= LP and p.Character then local hum = p.Character:FindFirstChild("Humanoid"); if hum and hum.Health > 0 then hum.Health = 0 end end end
end)
XenoHub:AddCmd("freeze", {"fr"}, "Freeze a player", function(args)
    if not args[1] then return end; local targets = XenoHub:ParsePlayers(args[1])
    for _, p in ipairs(targets) do if p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then local hrp = p.Character.HumanoidRootPart; local bp = Instance.new("BodyPosition"); bp.Position = hrp.Position; bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge); bp.Name = "XenoFreeze"; bp.Parent = hrp end end
end)
XenoHub:AddCmd("thaw", {"unfreeze", "unfr"}, "Unfreeze a player", function(args)
    if not args[1] then return end; local targets = XenoHub:ParsePlayers(args[1])
    for _, p in ipairs(targets) do if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then local hrp = p.Character.HumanoidRootPart; local bp = hrp:FindFirstChild("XenoFreeze"); if bp then bp:Destroy() end end end
end)
XenoHub:AddCmd("explode", {}, "Explode at mouse", function()
    local target = Mouse.Target or (LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"))
    if target then local exp = Instance.new("Explosion"); exp.BlastRadius = 20; exp.BlastPressure = 100000; exp.Position = target.Position; exp.Parent = Workspace end
end)
XenoHub:AddCmd("loopoof", {}, "Loop oof sounds on all players", function()
    XenoHub.Flags.loopoof = not XenoHub.Flags.loopoof
    if XenoHub.Flags.loopoof then
        XenoHub.Flags.loopoof_conn = RunService.Heartbeat:Connect(function()
            if not XenoHub.Flags.loopoof then XenoHub.Flags.loopoof_conn:Disconnect(); return end
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    local s = Instance.new("Sound"); s.SoundId = "rbxassetid://12222480"; s.Volume = 5; s.Parent = p.Character.HumanoidRootPart; s:Play()
                    task.delay(0.5, function() pcall(function() s:Destroy() end) end)
                end
            end; task.wait(0.8)
        end)
    end
end)
XenoHub:AddCmd("forcefield", {"ff"}, "Give forcefield to all or target", function(args)
    local targets = args[1] and XenoHub:ParsePlayers(args[1]) or Players:GetPlayers()
    for _, p in ipairs(targets) do if p.Character then local ff = Instance.new("ForceField"); ff.Parent = p.Character end end
end)
XenoHub:AddCmd("fakeshutdown", {}, "Fake server shutdown", function()
    local msg = Instance.new("Message"); msg.Text = "SERVER SHUTDOWN IN 10 SECONDS"; msg.Parent = Workspace
    task.delay(3, function() msg.Text = "5..."; task.delay(2, function() msg.Text = "Just kidding! Xeno Hub!"; task.delay(3, function() pcall(function() msg:Destroy() end) end) end) end)
end)
XenoHub:AddCmd("unanchor", {"breakparts"}, "Unanchor nearby parts", function(args)
    local radius = tonumber(args[1]) or 50; local char = LP.Character; if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local pos = char.HumanoidRootPart.Position
    for _, v in ipairs(Workspace:GetDescendants()) do if v:IsA("BasePart") and v.Anchored and not v:IsA("Terrain") then if (v.Position - pos).Magnitude < radius then v.Anchored = false end end end
end)

XenoHub:AddCmd("btools", {"f3x", "fex"}, "Give building tools", function() pcall(function() pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/f3x.lua"))() end) end) end)
XenoHub:AddCmd("delete", {"remove"}, "Delete part by name", function(args)
    local name = table.concat(args, " "); if name == "" then return end
    for _, v in ipairs(Workspace:GetDescendants()) do if v.Name:lower():find(name:lower()) and v:IsA("BasePart") then v:Destroy(); break end end
end)
XenoHub:AddCmd("deleteclass", {"dc", "removeclass"}, "Delete parts by class", function(args)
    local className = args[1]; if not className then return end
    for _, v in ipairs(Workspace:GetDescendants()) do if v.ClassName:lower() == className:lower() then v:Destroy() end end
end)
XenoHub:AddCmd("removeterrain", {"rterrain", "noterrain"}, "Remove terrain", function() pcall(function() Workspace.Terrain:Clear() end) end)
XenoHub:AddCmd("notify", {}, "Send notification", function(args) local text = table.concat(args, " "); if text ~= "" then XenoHub:Notify("Xeno Hub", text, 5) end end)
XenoHub:AddCmd("console", {}, "Open Roblox console", function() pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/console.lua"))() end) end)
XenoHub:AddCmd("hideiy", {"hidehub", "hidegui"}, "Toggle hub visibility", function() Window:SetVisibility(not Window.Visible) end)
XenoHub:AddCmd("togglefullscreen", {"togglefs"}, "Toggle fullscreen", function() UserInputService:ToggleFullscreen() end)
XenoHub:AddCmd("ping", {"notifyping"}, "Show ping", function()
    local ping = StatsService:FindFirstChild("Network") and StatsService.Network:FindFirstChild("ServerStatsItem")
    if ping then XenoHub:Notify("Ping", "Network Ping: " .. math.floor(ping:GetValue()) .. "ms", 5) end
end)
XenoHub:AddCmd("fps", {}, "Toggle FPS counter", function()
    XenoHub.Flags.fps = not XenoHub.Flags.fps
    if XenoHub.Flags.fps then
        local stats = Instance.new("Folder"); stats.Name = "XenoFPS"
        local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(0, 100, 0, 30); lbl.Position = UDim2.new(0, 10, 0, 10)
        lbl.BackgroundTransparency = 0.8; lbl.BackgroundColor3 = Color3.fromRGB(0, 0, 0); lbl.TextColor3 = Color3.fromRGB(0, 255, 0); lbl.TextSize = 16; lbl.Font = Enum.Font.GothamBold; lbl.ZIndex = 100; lbl.Parent = stats
        stats.Parent = LP:WaitForChild("PlayerGui")
        local fc = 0; local lt = tick()
        XenoHub.Flags.fps_conn = RunService.RenderStepped:Connect(function() fc = fc + 1; local now = tick(); if now - lt >= 1 then lbl.Text = "FPS: " .. fc; fc = 0; lt = now end end)
        XenoHub.Flags.fps_stats = stats
    else
        if XenoHub.Flags.fps_conn then XenoHub.Flags.fps_conn:Disconnect() end; local s = LP.PlayerGui:FindFirstChild("XenoFPS"); if s then s:Destroy() end
    end
end)

-- === RAYFIELD WINDOW ===
local Window = Rayfield:CreateWindow({
    Name = "Xeno Hub v" .. XenoHub.Version .. " | " .. XenoHub.CurrentGame,
    LoadingTitle = "Xeno Universal Hub",
    LoadingSubtitle = "by itsinvin",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "XenoHub",
        FileName = "Config"
    },
    Discord = {
        Enabled = false,
        Invite = "",
        RememberJoins = true
    },
    KeySystem = false,
    KeySettings = {}
})

-- === TABS ===
-- Movement
local movTab = Window:CreateTab("Movement", nil)
local movSection = movTab:CreateSection("Movement")
movTab:CreateToggle({Name = "Fly", CurrentValue = false, Callback = function(v) XenoHub.Flags.fly = v; if v then XenoHub:ExecCmd("fly 50") else XenoHub:ExecCmd("unfly") end end})
movTab:CreateSlider({Name = "Fly Speed", Range = {10, 200}, Increment = 5, Default = 50, Callback = function(v) XenoHub.Flags.fly_speed = v end})
movTab:CreateToggle({Name = "Noclip", CurrentValue = false, Callback = function(v) XenoHub.Flags.noclip = v; if v and not XenoHub.Flags.noclip_conn then XenoHub:ExecCmd("noclip") end end})
movTab:CreateSlider({Name = "WalkSpeed", Range = {1, 250}, Increment = 1, Default = 16, Callback = function(v) if LP.Character and LP.Character:FindFirstChild("Humanoid") then LP.Character.Humanoid.WalkSpeed = v end end})
movTab:CreateSlider({Name = "Jump Power", Range = {1, 500}, Increment = 1, Default = 50, Callback = function(v) if LP.Character and LP.Character:FindFirstChild("Humanoid") then LP.Character.Humanoid.JumpPower = v end end})
movTab:CreateSlider({Name = "Gravity", Range = {0, 500}, Increment = 1, Default = 196, Callback = function(v) Workspace.Gravity = v end})
movTab:CreateToggle({Name = "Infinite Jump", CurrentValue = false, Callback = function(v) XenoHub.Flags.infjump = v; if v and not XenoHub.Flags.infjump_conn then XenoHub:ExecCmd("infinitejump") end end})
movTab:CreateToggle({Name = "Anti-Void", CurrentValue = false, Callback = function(v) XenoHub.Flags.antivoid = v; if v then XenoHub:ExecCmd("antivoid") end end})
movTab:CreateToggle({Name = "Spin", CurrentValue = false, Callback = function(v) XenoHub.Flags.spin = v; XenoHub:ExecCmd("spin " .. (v and "20" or "0")) end})
movTab:CreateToggle({Name = "Invisible", CurrentValue = false, Callback = function(v) XenoHub.Flags.invisible = v; XenoHub:ExecCmd("invisible") end})

-- Player
local plrTab = Window:CreateTab("Player", nil)
plrTab:CreateSection("Appearance")
plrTab:CreateButton({Name = "Reset Character", Callback = function() XenoHub:ExecCmd("reset") end})
plrTab:CreateButton({Name = "Sit", Callback = function() XenoHub:ExecCmd("sit") end})
plrTab:CreateButton({Name = "God Mode", Callback = function() XenoHub:ExecCmd("god") end})
plrTab:CreateInput({Name = "Set Head Size", PlaceholderText = "size (default 5)", Callback = function(v) XenoHub:ExecCmd("headsize " .. v) end})
plrTab:CreateButton({Name = "Remove Face", Callback = function() XenoHub:ExecCmd("noface") end})
plrTab:CreateButton({Name = "Remove Arms", Callback = function() XenoHub:ExecCmd("noarms") end})
plrTab:CreateButton({Name = "Remove Legs", Callback = function() XenoHub:ExecCmd("nolegs") end})
plrTab:CreateButton({Name = "Block Head", Callback = function() XenoHub:ExecCmd("blockhead") end})

-- Teleport
local tpTab = Window:CreateTab("Teleport", nil)
tpTab:CreateSection("Teleport")
tpTab:CreateInput({Name = "TP to Player", PlaceholderText = "username", Callback = function(v) XenoHub:ExecCmd("goto " .. v) end})
tpTab:CreateInput({Name = "Tween to Player", PlaceholderText = "username", Callback = function(v) XenoHub:ExecCmd("tweengoto " .. v) end})
tpTab:CreateInput({Name = "TP to Coordinates", PlaceholderText = "X Y Z", Callback = function(v) XenoHub:ExecCmd("tpposition " .. v) end})
tpTab:CreateInput({Name = "Offset Position", PlaceholderText = "X Y Z", Callback = function(v) XenoHub:ExecCmd("offset " .. v) end})
tpTab:CreateInput({Name = "Bring Player", PlaceholderText = "username", Callback = function(v) XenoHub:ExecCmd("clientbring " .. v) end})
tpTab:CreateInput({Name = "Look At Player", PlaceholderText = "username", Callback = function(v) XenoHub:ExecCmd("lookat " .. v) end})
tpTab:CreateButton({Name = "Stop Looking", Callback = function() XenoHub:ExecCmd("unlookat") end})
tpTab:CreateInput({Name = "Waypoint", PlaceholderText = "name (add 'set' to save)", Callback = function(v) XenoHub:ExecCmd("waypoint " .. v) end})
tpTab:CreateButton({Name = "List Waypoints", Callback = function() XenoHub:ExecCmd("waypoint") end})

-- Visual
local visTab = Window:CreateTab("Visual", nil)
visTab:CreateSection("Visuals")
visTab:CreateToggle({Name = "ESP", CurrentValue = false, Callback = function(v) XenoHub.Flags.esp_enabled = v; XenoHub:ExecCmd("esp") end})
visTab:CreateToggle({Name = "X-Ray", CurrentValue = false, Callback = function(v) XenoHub.Flags.xray = v; XenoHub:ExecCmd("xray") end})
visTab:CreateToggle({Name = "Fullbright", CurrentValue = false, Callback = function(v) XenoHub.Flags.fullbright = v; XenoHub:ExecCmd("fullbright") end})
visTab:CreateSlider({Name = "Field of View", Range = {1, 120}, Increment = 1, Default = 70, Callback = function(v) Camera.FieldOfView = v end})
visTab:CreateToggle({Name = "Freecam", CurrentValue = false, Callback = function(v) XenoHub.Flags.freecam = v; XenoHub:ExecCmd("freecam") end})
visTab:CreateInput({Name = "Hitbox Size", PlaceholderText = "username size", Callback = function(v) XenoHub:ExecCmd("hitbox " .. v) end})
visTab:CreateInput({Name = "Ambient Color", PlaceholderText = "R G B", Callback = function(v) XenoHub:ExecCmd("ambient " .. v) end})
visTab:CreateButton({Name = "Day", Callback = function() XenoHub:ExecCmd("day") end})
visTab:CreateButton({Name = "Night", Callback = function() XenoHub:ExecCmd("night") end})
visTab:CreateButton({Name = "No Fog", Callback = function() XenoHub:ExecCmd("nofog") end})
visTab:CreateToggle({Name = "FPS Counter", CurrentValue = false, Callback = function(v) XenoHub.Flags.fps = v; XenoHub:ExecCmd("fps") end})

-- Chat
local chatTab = Window:CreateTab("Chat", nil)
chatTab:CreateSection("Chat")
chatTab:CreateInput({Name = "Send Message", PlaceholderText = "text", Callback = function(v) XenoHub:ExecCmd("chat " .. v) end})
chatTab:CreateInput({Name = "Spam Message", PlaceholderText = "text", Callback = function(v) XenoHub:ExecCmd("spam " .. v) end})
chatTab:CreateButton({Name = "Stop Spam", Callback = function() XenoHub:ExecCmd("unspam") end})

-- Server
local srvTab = Window:CreateTab("Server", nil)
srvTab:CreateSection("Server")
srvTab:CreateButton({Name = "Rejoin", Callback = function() XenoHub:ExecCmd("rejoin") end})
srvTab:CreateButton({Name = "Server Hop", Callback = function() XenoHub:ExecCmd("serverhop") end})
srvTab:CreateToggle({Name = "Anti-AFK", CurrentValue = false, Callback = function(v) XenoHub.Flags.antiafk = v; XenoHub:ExecCmd("antiafk") end})
srvTab:CreateButton({Name = "Server Info", Callback = function() XenoHub:ExecCmd("serverinfo") end})
srvTab:CreateButton({Name = "Copy JobID", Callback = function() XenoHub:ExecCmd("jobid") end})
srvTab:CreateButton({Name = "Exit Roblox", Callback = function() XenoHub:ExecCmd("exit") end})

-- Combat
local cmbTab = Window:CreateTab("Combat", nil)
cmbTab:CreateSection("Combat")
cmbTab:CreateToggle({Name = "Fling", CurrentValue = false, Callback = function(v) XenoHub.Flags.fling = v; XenoHub:ExecCmd("fling") end})
cmbTab:CreateToggle({Name = "Anti-Fling", CurrentValue = false, Callback = function(v) XenoHub.Flags.antifling = v; XenoHub:ExecCmd("antifling") end})
cmbTab:CreateInput({Name = "Kill with Tool", PlaceholderText = "username [radius]", Callback = function(v) XenoHub:ExecCmd("handlekill " .. v) end})

-- Troll
local trlTab = Window:CreateTab("Troll", nil)
trlTab:CreateSection("Troll")
trlTab:CreateButton({Name = "Kill All", Callback = function() XenoHub:ExecCmd("killall") end})
trlTab:CreateInput({Name = "Freeze Player", PlaceholderText = "username", Callback = function(v) XenoHub:ExecCmd("freeze " .. v) end})
trlTab:CreateInput({Name = "Thaw Player", PlaceholderText = "username", Callback = function(v) XenoHub:ExecCmd("thaw " .. v) end})
trlTab:CreateButton({Name = "Explode at Mouse", Callback = function() XenoHub:ExecCmd("explode") end})
trlTab:CreateToggle({Name = "Loop Oof", CurrentValue = false, Callback = function(v) XenoHub.Flags.loopoof = v; XenoHub:ExecCmd("loopoof") end})
trlTab:CreateInput({Name = "Forcefield", PlaceholderText = "username (blank=all)", Callback = function(v) XenoHub:ExecCmd("forcefield " .. (v ~= "" and v or "")) end})
trlTab:CreateButton({Name = "Fake Shutdown", Callback = function() XenoHub:ExecCmd("fakeshutdown") end})
trlTab:CreateInput({Name = "Unanchor Parts", PlaceholderText = "radius", Callback = function(v) XenoHub:ExecCmd("unanchor " .. v) end})

-- Tools
local tlsTab = Window:CreateTab("Tools", nil)
tlsTab:CreateSection("Tools")
tlsTab:CreateButton({Name = "Give Building Tools (F3X)", Callback = function() XenoHub:ExecCmd("btools") end})
tlsTab:CreateButton({Name = "Open Console", Callback = function() XenoHub:ExecCmd("console") end})
tlsTab:CreateInput({Name = "Delete Part by Name", PlaceholderText = "name", Callback = function(v) XenoHub:ExecCmd("delete " .. v) end})
tlsTab:CreateInput({Name = "Delete by Class", PlaceholderText = "className", Callback = function(v) XenoHub:ExecCmd("deleteclass " .. v) end})
tlsTab:CreateButton({Name = "Remove Terrain", Callback = function() XenoHub:ExecCmd("removeterrain") end})

-- Settings
local setTab = Window:CreateTab("Settings", nil)
setTab:CreateSection("Info")
setTab:CreateButton({Name = "Ping", Callback = function() XenoHub:ExecCmd("ping") end})
setTab:CreateToggle({Name = "Fullscreen", CurrentValue = false, Callback = function() XenoHub:ExecCmd("togglefullscreen") end})
setTab:CreateParagraph({Title = "Xeno Hub v" .. XenoHub.Version, Content = "Game: " .. XenoHub.CurrentGame .. "\nCommands: ;command\nBy: itsinvin\n\nRightShift = Toggle GUI\nSpace/Shift = Fly up/down\nWASD = Fly/Freecam movement"})

-- Game-specific: MM2
if XenoHub.CurrentGame == "MM2" then
    local mm2Tab = Window:CreateTab("MM2", nil)
    mm2Tab:CreateSection("Murder Mystery 2")
    mm2Tab:CreateButton({Name = "Auto-Shoot (Sheriff)", Callback = function()
        local gun
        for _, item in ipairs(LP.Backpack:GetChildren()) do if item:FindFirstChild("Gun") then gun = item; break end end
        if not gun and LP.Character then for _, item in ipairs(LP.Character:GetChildren()) do if item:FindFirstChild("Gun") then gun = item; break end end end
        if not gun then XenoHub:Notify("Auto-Shoot", "Not sheriff", 3); return end
        XenoHub.Flags.mm2_autoshoot = RunService.Heartbeat:Connect(function()
            if not gun or not gun.Parent then XenoHub.Flags.mm2_autoshoot:Disconnect() return end
            local closest, bestDist; local myPos = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not myPos then return end
            for _, p in ipairs(Players:GetPlayers()) do if p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then local d = (myPos.Position - p.Character.HumanoidRootPart.Position).Magnitude; if d < (bestDist or math.huge) then bestDist = d; closest = p end end end
            if closest and closest.Character and closest.Character:FindFirstChild("HumanoidRootPart") then pcall(function() gun:Activate() end) end
        end)
    end end)
    mm2Tab:CreateButton({Name = "Auto-Attack (Murderer)", Callback = function()
        local knife
        for _, item in ipairs(LP.Backpack:GetChildren()) do if item:FindFirstChild("Knife") then knife = item; break end end
        if not knife and LP.Character then for _, item in ipairs(LP.Character:GetChildren()) do if item:FindFirstChild("Knife") then knife = item; break end end end
        if not knife then XenoHub:Notify("Auto-Attack", "Not murderer", 3); return end
        XenoHub.Flags.mm2_autoattack = RunService.Heartbeat:Connect(function()
            if not knife or not knife.Parent then XenoHub.Flags.mm2_autoattack:Disconnect(); return end
            local closest, bestDist; local myPos = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"); if not myPos then return end
            for _, p in ipairs(Players:GetPlayers()) do if p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then local d = (myPos.Position - p.Character.HumanoidRootPart.Position).Magnitude; if d < (bestDist or math.huge) then bestDist = d; closest = p end end end
            if closest and closest.Character and closest.Character:FindFirstChild("HumanoidRootPart") and (myPos.Position - closest.Character.HumanoidRootPart.Position).Magnitude < 15 then pcall(function() knife:Activate() end) end
        end)
    end end)
end

-- Game-specific: Jailbreak
if XenoHub.CurrentGame == "Jailbreak" then
    local jbTab = Window:CreateTab("Jailbreak", nil)
    jbTab:CreateSection("Jailbreak")
    jbTab:CreateButton({Name = "TP to Bank", Callback = function() XenoHub:Teleport(Vector3.new(-1200, 20, 600)) end})
    jbTab:CreateButton({Name = "TP to Prison", Callback = function() XenoHub:Teleport(Vector3.new(1850, 20, -250)) end})
    jbTab:CreateButton({Name = "TP to Museum", Callback = function() XenoHub:Teleport(Vector3.new(-300, 20, -900)) end})
    jbTab:CreateButton({Name = "TP to Jewelry", Callback = function() XenoHub:Teleport(Vector3.new(-800, 20, -600)) end})
    jbTab:CreateButton({Name = "TP to Donut", Callback = function() XenoHub:Teleport(Vector3.new(0, 20, 600)) end})
    jbTab:CreateButton({Name = "TP to Gas Station", Callback = function() XenoHub:Teleport(Vector3.new(500, 20, 200)) end})
    jbTab:CreateButton({Name = "TP to Police Station", Callback = function() XenoHub:Teleport(Vector3.new(1700, 20, -50)) end})
end

-- ESP auto-add on new players
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(char)
        if XenoHub.Flags.esp_enabled and not char:FindFirstChild("XenoESP") then
            local hl = Instance.new("Highlight"); hl.Name = "XenoESP"; hl.FillColor = Color3.fromRGB(255, 50, 50); hl.OutlineColor = Color3.fromRGB(255, 255, 255); hl.FillTransparency = 0.5; hl.Adornee = char; hl.Parent = char
        end
    end)
end)

XenoHub.UI = Window

print("=== Xeno Universal Hub v" .. XenoHub.Version .. " loaded ===")
print("Detected game: " .. XenoHub.CurrentGame)
local cmdCount = 0; for _ in pairs(XenoHub.Cmds) do cmdCount = cmdCount + 1 end
print("Commands: " .. cmdCount .. " | Press RightShift to toggle GUI")

return XenoHub