-- Xeno Universal Hub v2.0
-- Inspired by Infinite Yield FE v6.4.1
-- Full command-line + GUI hub for Xeno executor
-- Supports: MM2, Jailbreak, Arsenal, Blox Fruits, Doors, Pet Sim, TDS, Bedwars, Brookhaven

local XenoHub = {}
XenoHub.Version = "2.0"
XenoHub.CurrentGame = ""
XenoHub.Flags = {}
XenoHub.Cmds = {}
XenoHub.Aliases = {}
XenoHub.Waypoints = {}
XenoHub.Binds = {}
XenoHub.CmdHistory = {}
XenoHub.Prefix = ";"

-- Guard for re-execution
if getgenv().XENO_HUB_LOADED then
    warn("[XenoHub] Already loaded. Use hidehub to toggle or rejoin and re-execute.")
    return
end
getgenv().XENO_HUB_LOADED = true
if getgenv then getgenv().XENO_HUB_INSTANCE = XenoHub end

-- === SERVICES ===
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")
local StatsService = game:GetService("Stats")
-- ChatService = game:GetService("Chat") -- unused, keep commented

local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()
local Camera = Workspace.CurrentCamera

-- === GAME DETECTION ===
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

do
    for name, ids in pairs(GameIDs) do
        if type(ids) == "table" then
            for _, id in ipairs(ids) do
                if PlaceId == id then XenoHub.CurrentGame = name; break end
            end
        elseif PlaceId == ids then
            XenoHub.CurrentGame = name; break
        end
    end
    if XenoHub.CurrentGame == "" then XenoHub.CurrentGame = "Unknown" end
end

-- === PLAYER SELECTOR ===
function XenoHub:ParsePlayers(input)
    local results = {}
    if not input or input == "" then return {LP} end

    local function matchPlayer(name)
        local p = Players:FindFirstChild(name)
        if p then return p end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Name:lower():sub(1, #name) == name:lower() then return plr end
        end
        return nil
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
        if term == "all" then
            matched = Players:GetPlayers()
        elseif term == "others" then
            for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then table.insert(matched, p) end end
        elseif term == "me" then
            matched = {LP}
        elseif term == "random" then
            local pool = Players:GetPlayers()
            if #pool > 0 then matched = {pool[math.random(1, #pool)]} end
        elseif term == "nearest" then
            local closest, bestDist
            local myPos = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
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
            local farthest, bestDist
            local myPos = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
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
            local n = tonumber(term:sub(2)) or 1
            local pool = {}
            for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then table.insert(pool, p) end end
            for i = 1, math.min(n, #pool) do
                local idx = math.random(1, #pool)
                table.insert(matched, pool[idx])
                table.remove(pool, idx)
            end
        elseif term:sub(1,1) == "%" then
            local teamName = term:sub(2)
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Team and p.Team.Name:lower() == teamName:lower() then table.insert(matched, p) end
            end
        elseif term == "alive" then
            for _, p in ipairs(Players:GetPlayers()) do
                if p.Character and p.Character:FindFirstChild("Humanoid") and p.Character.Humanoid.Health > 0 then
                    table.insert(matched, p)
                end
            end
        elseif term == "dead" then
            for _, p in ipairs(Players:GetPlayers()) do
                if not p.Character or not p.Character:FindFirstChild("Humanoid") or p.Character.Humanoid.Health <= 0 then
                    table.insert(matched, p)
                end
            end
        elseif term:sub(1,6) == "group:" then
            local gid = term:sub(7)
            for _, p in ipairs(Players:GetPlayers()) do
                if p:IsInGroup(gid) then table.insert(matched, p) end
            end
        else
            local p = matchPlayer(term)
            if p then matched = {p} end
        end

        if exclude then
            local excludeMap = {}
            for _, p in ipairs(matched) do excludeMap[p] = true end
            local filtered = {}
            for _, p in ipairs(results) do if not excludeMap[p] then table.insert(filtered, p) end end
            results = filtered
        else
            for _, p in ipairs(matched) do
                local found = false
                for _, r in ipairs(results) do if r == p then found = true; break end end
                if not found then table.insert(results, p) end
            end
        end
    end

    if #results == 0 then results = {LP} end
    return results
end

-- === COMMAND SYSTEM ===
local function splitArgs(str)
    local args = {}
    for word in str:gmatch("%S+") do table.insert(args, word) end
    return args
end

function XenoHub:AddCmd(name, aliases, desc, func)
    self.Cmds[name] = {func = func, desc = desc, aliases = aliases or {}}
    for _, alias in ipairs(aliases or {}) do
        self.Aliases[alias] = name
    end
end

function XenoHub:ExecCmd(input, speaker)
    speaker = speaker or LP
    if not input or input == "" then return end

    -- Multi-command separator
    if input:find("\\") then
        for part in input:gmatch("[^\\]+") do
            self:ExecCmd(part:match("^%s*(.-)%s*$"), speaker)
        end
        return
    end

    -- Loop syntax: N^delay^command or inf^delay^command
    local loopMatch = input:match("^(%d+%^%d+%.?%d*%^.+)$") or input:match("^(inf%^%d+%.?%d*%^.+)$")
    if loopMatch then
        local countStr, delayStr, cmd = loopMatch:match("^(.-)%^(.-)%^(.+)$")
        local count = countStr == "inf" and -1 or tonumber(countStr)
        local delay = tonumber(delayStr) or 1
        local loopCount = 0
        task.spawn(function()
            while loopCount < count or count < 0 do
                if count > 0 then loopCount = loopCount + 1 end
                XenoHub:ExecCmd(cmd, speaker)
                task.wait(delay)
            end
        end)
        return
    end

    local args = splitArgs(input)
    local cmdName = args[1]:lower()
    table.remove(args, 1)

    -- Check aliases
    if self.Aliases[cmdName] then cmdName = self.Aliases[cmdName] end

    -- Store in history
    table.insert(self.CmdHistory, input)
    if #self.CmdHistory > 30 then table.remove(self.CmdHistory, 1) end

    local cmd = self.Cmds[cmdName]
    if cmd then
        local success, err = pcall(cmd.func, args, speaker)
        if not success then
            warn("[XenoHub] Command error: " .. tostring(err))
        end
    else
        warn("[XenoHub] Unknown command: " .. cmdName)
    end
end

-- === NOTIFICATION SYSTEM ===
local NotificationGui = Instance.new("ScreenGui")
NotificationGui.Name = "XenoHubNotifications"
NotificationGui.ResetOnSpawn = false
NotificationGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
NotificationGui.Parent = LP:WaitForChild("PlayerGui")

function XenoHub:Notify(title, text, length)
    length = length or 5
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 260, 0, 70)
    frame.Position = UDim2.new(1, -270, 1, -100)
    frame.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    frame.BorderSizePixel = 0
    frame.BackgroundTransparency = 0.15
    local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 6); corner.Parent = frame

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -10, 0, 20)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = title or "Xeno Hub"
    titleLbl.TextColor3 = Color3.fromRGB(200, 200, 220)
    titleLbl.TextSize = 14
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Parent = frame

    local textLbl = Instance.new("TextLabel")
    textLbl.Size = UDim2.new(1, -10, 0, 40)
    textLbl.Position = UDim2.new(0, 5, 0, 22)
    textLbl.BackgroundTransparency = 1
    textLbl.Text = text or ""
    textLbl.TextColor3 = Color3.fromRGB(180, 180, 200)
    textLbl.TextSize = 12
    textLbl.Font = Enum.Font.Gotham
    textLbl.TextXAlignment = Enum.TextXAlignment.Left
    textLbl.TextWrapped = true
    textLbl.TextYAlignment = Enum.TextYAlignment.Top
    textLbl.Parent = frame

    frame.Parent = NotificationGui
    local notifCount = #NotificationGui:GetChildren() - 1
    frame:TweenPosition(UDim2.new(1, -270, 1, -100 - (notifCount * 80)), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true)
    task.delay(length, function()
        pcall(function()
            frame:TweenPosition(UDim2.new(1, 0, 1, -100), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.3, true)
            task.delay(0.3, function() pcall(function() frame:Destroy() end) end)
        end)
    end)
end

-- === UI LIBRARY ===
do
    local lib = {}
    local gui = Instance.new("ScreenGui")
    gui.Name = "XenoHub"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = LP:WaitForChild("PlayerGui")

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, 620, 0, 420)
    main.Position = UDim2.new(0.5, -310, 0.5, -210)
    main.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true

    local mainCorner = Instance.new("UICorner"); mainCorner.CornerRadius = UDim.new(0, 8); mainCorner.Parent = main

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 36)
    titleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    titleBar.BorderSizePixel = 0
    local tbc = Instance.new("UICorner"); tbc.CornerRadius = UDim.new(0, 8); tbc.Parent = titleBar

    local titleText = Instance.new("TextLabel")
    titleText.Size = UDim2.new(1, -40, 1, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "Xeno Hub v" .. XenoHub.Version .. " | " .. XenoHub.CurrentGame
    titleText.TextColor3 = Color3.fromRGB(200, 200, 220)
    titleText.TextSize = 16
    titleText.Font = Enum.Font.GothamBold
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = titleBar

    -- Command bar
    local cmdBar = Instance.new("TextBox")
    cmdBar.Size = UDim2.new(0, 240, 0, 22)
    cmdBar.Position = UDim2.new(0, 145, 0, 7)
    cmdBar.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    cmdBar.BorderSizePixel = 0
    cmdBar.PlaceholderText = XenoHub.Prefix .. " command"
    cmdBar.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
    cmdBar.Text = ""
    cmdBar.TextColor3 = Color3.fromRGB(220, 220, 240)
    cmdBar.TextSize = 12
    cmdBar.Font = Enum.Font.Gotham
    cmdBar.ClearTextOnFocus = false
    local cmdBarCorner = Instance.new("UICorner"); cmdBarCorner.CornerRadius = UDim.new(0, 4); cmdBarCorner.Parent = cmdBar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -34, 0, 3)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 16
    closeBtn.Font = Enum.Font.GothamBold
    local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, 6); cc.Parent = closeBtn
    closeBtn.MouseButton1Click:Connect(function() gui.Enabled = not gui.Enabled end)
    closeBtn.Parent = titleBar

    titleBar.Parent = main

    local tabFrame = Instance.new("Frame")
    tabFrame.Size = UDim2.new(0, 140, 1, -36)
    tabFrame.Position = UDim2.new(0, 0, 0, 36)
    tabFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
    tabFrame.BorderSizePixel = 0

    local tabList = Instance.new("ScrollingFrame")
    tabList.Size = UDim2.new(1, 0, 1, 0)
    tabList.BackgroundTransparency = 1
    tabList.BorderSizePixel = 0
    tabList.ScrollBarThickness = 2
    tabList.CanvasSize = UDim2.new(0, 0, 0, 0)
    tabList.AutomaticCanvasSize = Enum.AutomaticSize.Y
    tabList.Parent = tabFrame
    tabFrame.Parent = main

    local contentFrame = Instance.new("ScrollingFrame")
    contentFrame.Size = UDim2.new(1, -145, 1, -6)
    contentFrame.Position = UDim2.new(0, 145, 0, 3)
    contentFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    contentFrame.BorderSizePixel = 0
    contentFrame.ScrollBarThickness = 4
    contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    contentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    contentFrame.Parent = main

    -- Drag
    local windowDragging, dragStart, frameStart
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            windowDragging = true; dragStart = input.Position; frameStart = main.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if windowDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local d = input.Position - dragStart
            main.Position = UDim2.new(frameStart.X.Scale, frameStart.X.Offset + d.X, frameStart.Y.Scale, frameStart.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then windowDragging = false end
    end)

    local tabs = {}
    local tabButtons = {}

    -- Command bar exec
    cmdBar.FocusLost:Connect(function(enter)
        if enter and cmdBar.Text ~= "" then
            local input = cmdBar.Text
            if input:sub(1,1) == XenoHub.Prefix then input = input:sub(2) end
            XenoHub:ExecCmd(input)
            cmdBar.Text = ""
        end
    end)
    cmdBar.Parent = titleBar

    function lib:Tab(name)
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, -10, 0, 0)
        container.AutomaticSize = Enum.AutomaticSize.Y
        container.Position = UDim2.new(0, 5, 0, 0)
        container.BackgroundTransparency = 1
        container.Visible = false
        container.Parent = contentFrame

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 6)
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = container

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -8, 0, 32)
        btn.Position = UDim2.new(0, 4, 0, 0)
        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
        btn.BorderSizePixel = 0
        btn.Text = "  " .. name
        btn.TextColor3 = Color3.fromRGB(160, 160, 180)
        btn.TextSize = 13
        btn.Font = Enum.Font.GothamBold
        btn.TextXAlignment = Enum.TextXAlignment.Left
        local bCorner = Instance.new("UICorner"); bCorner.CornerRadius = UDim.new(0, 4); bCorner.Parent = btn

        btn.MouseButton1Click:Connect(function()
            for _, t in ipairs(tabs) do t.Visible = false end
            for _, b in ipairs(tabButtons) do
                b.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
                b.TextColor3 = Color3.fromRGB(160, 160, 180)
            end
            container.Visible = true
            btn.BackgroundColor3 = Color3.fromRGB(55, 55, 80)
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        end)

        btn.Parent = tabList
        table.insert(tabs, container)
        table.insert(tabButtons, btn)

        if #tabs == 1 then btn.MouseButton1Click:Fire() end

        local tabObj = {}

        function tabObj:Button(text, cb)
            local b = Instance.new("TextButton")
            b.Size = UDim2.new(0, 180, 0, 30)
            b.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
            b.BorderSizePixel = 0
            b.Text = text
            b.TextColor3 = Color3.fromRGB(220, 220, 240)
            b.TextSize = 13
            b.Font = Enum.Font.Gotham
            local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 4); bc.Parent = b
            b.MouseButton1Click:Connect(cb)
            b.Parent = container
            return b
        end

        function tabObj:Toggle(text, default, cb)
            local state = default or false
            local bg = Instance.new("Frame")
            bg.Size = UDim2.new(0, 200, 0, 32)
            bg.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
            bg.BorderSizePixel = 0
            local bgc = Instance.new("UICorner"); bgc.CornerRadius = UDim.new(0, 4); bgc.Parent = bg
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(0, 140, 1, 0); lbl.BackgroundTransparency = 1; lbl.Text = text
            lbl.TextColor3 = Color3.fromRGB(200, 200, 220); lbl.TextSize = 13; lbl.Font = Enum.Font.Gotham
            lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = bg

            local tb = Instance.new("TextButton")
            tb.Size = UDim2.new(0, 50, 0, 24); tb.Position = UDim2.new(1, -55, 0.5, -12)
            tb.BackgroundColor3 = state and Color3.fromRGB(50, 180, 80) or Color3.fromRGB(60, 60, 70)
            tb.BorderSizePixel = 0; tb.Text = state and "ON" or "OFF"
            tb.TextColor3 = Color3.fromRGB(255, 255, 255); tb.TextSize = 12; tb.Font = Enum.Font.GothamBold
            local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0, 4); tc.Parent = tb

            tb.MouseButton1Click:Connect(function()
                state = not state; tb.Text = state and "ON" or "OFF"
                tb.BackgroundColor3 = state and Color3.fromRGB(50, 180, 80) or Color3.fromRGB(60, 60, 70)
                pcall(cb, state)
            end)
            tb.Parent = bg; bg.Parent = container; return function() return state end
        end

        function tabObj:Slider(text, min, max, default, cb)
            local val = default or min
            local bg = Instance.new("Frame")
            bg.Size = UDim2.new(0, 250, 0, 40)
            bg.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
            bg.BorderSizePixel = 0
            local bgc = Instance.new("UICorner"); bgc.CornerRadius = UDim.new(0, 4); bgc.Parent = bg
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(0, 120, 1, 0); lbl.BackgroundTransparency = 1
            lbl.Text = text .. ": " .. tostring(math.floor(val))
            lbl.TextColor3 = Color3.fromRGB(200, 200, 220); lbl.TextSize = 13; lbl.Font = Enum.Font.Gotham
            lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = bg

            local sb = Instance.new("Frame")
            sb.Size = UDim2.new(0, 110, 0, 6); sb.Position = UDim2.new(1, -120, 0.5, -3)
            sb.BackgroundColor3 = Color3.fromRGB(40, 40, 55); sb.BorderSizePixel = 0
            local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(1, 0); sc.Parent = sb
            local fill = Instance.new("Frame")
            fill.Size = UDim2.new((val - min) / (max - min), 0, 1, 0)
            fill.BackgroundColor3 = Color3.fromRGB(50, 120, 210); fill.BorderSizePixel = 0
            local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(1, 0); fc.Parent = fill; fill.Parent = sb

            local sliderDragging = false
            sb.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then sliderDragging = true end end)
            UserInputService.InputChanged:Connect(function(input)
                if sliderDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                    local pos = math.clamp((input.Position.X - sb.AbsolutePosition.X) / sb.AbsoluteSize.X, 0, 1)
                    val = min + (max - min) * pos; fill.Size = UDim2.new(pos, 0, 1, 0); lbl.Text = text .. ": " .. tostring(math.floor(val))
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 and sliderDragging then
                    sliderDragging = false; pcall(cb, math.floor(val))
                end
            end)
            sb.Parent = bg; bg.Parent = container; return function() return math.floor(val) end
        end

        function tabObj:Dropdown(text, options, cb)
            local bg = Instance.new("Frame")
            bg.Size = UDim2.new(0, 200, 0, 32); bg.BackgroundColor3 = Color3.fromRGB(30, 30, 40); bg.BorderSizePixel = 0
            local bgc = Instance.new("UICorner"); bgc.CornerRadius = UDim.new(0, 4); bgc.Parent = bg
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(0, 100, 1, 0); lbl.BackgroundTransparency = 1; lbl.Text = text
            lbl.TextColor3 = Color3.fromRGB(200, 200, 220); lbl.TextSize = 13; lbl.Font = Enum.Font.Gotham
            lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = bg
            local dd = Instance.new("TextButton")
            dd.Size = UDim2.new(0, 90, 0, 24); dd.Position = UDim2.new(1, -95, 0.5, -12)
            dd.BackgroundColor3 = Color3.fromRGB(40, 40, 55); dd.BorderSizePixel = 0; dd.Text = options[1] or ""
            dd.TextColor3 = Color3.fromRGB(220, 220, 240); dd.TextSize = 12; dd.Font = Enum.Font.Gotham
            local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(0, 4); dc.Parent = dd
            local idx = 1
            dd.MouseButton1Click:Connect(function()
                idx = idx % #options + 1; dd.Text = options[idx]; pcall(cb, options[idx])
            end)
            dd.Parent = bg; bg.Parent = container; return function() return options[idx] end
        end

        function tabObj:Input(text, cb, placeholder)
            local bg = Instance.new("Frame")
            bg.Size = UDim2.new(0, 250, 0, 32); bg.BackgroundColor3 = Color3.fromRGB(30, 30, 40); bg.BorderSizePixel = 0
            local bgc = Instance.new("UICorner"); bgc.CornerRadius = UDim.new(0, 4); bgc.Parent = bg
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(0, 60, 1, 0); lbl.BackgroundTransparency = 1; lbl.Text = text
            lbl.TextColor3 = Color3.fromRGB(200, 200, 220); lbl.TextSize = 13; lbl.Font = Enum.Font.Gotham
            lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = bg
            local inp = Instance.new("TextBox")
            inp.Size = UDim2.new(0, 180, 0, 24); inp.Position = UDim2.new(1, -185, 0.5, -12)
            inp.BackgroundColor3 = Color3.fromRGB(40, 40, 55); inp.BorderSizePixel = 0
            inp.PlaceholderText = placeholder or "value"
            inp.PlaceholderColor3 = Color3.fromRGB(120, 120, 120); inp.Text = ""
            inp.TextColor3 = Color3.fromRGB(220, 220, 240); inp.TextSize = 12; inp.Font = Enum.Font.Gotham
            inp.ClearTextOnFocus = false
            local ic = Instance.new("UICorner"); ic.CornerRadius = UDim.new(0, 4); ic.Parent = inp
            inp.FocusLost:Connect(function(enter) if enter and inp.Text ~= "" then pcall(cb, inp.Text); inp.Text = "" end end)
            inp.Parent = bg; bg.Parent = container; return inp
        end

        function tabObj:Section(text)
            local sec = Instance.new("TextLabel")
            sec.Size = UDim2.new(0, 400, 0, 24); sec.BackgroundTransparency = 1
            sec.Text = "--- " .. text .. " ---"
            sec.TextColor3 = Color3.fromRGB(100, 100, 140); sec.TextSize = 12; sec.Font = Enum.Font.GothamBold
            sec.TextXAlignment = Enum.TextXAlignment.Left; sec.Parent = container; return sec
        end

        function tabObj:Label(text)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(0, 400, 0, 20); lbl.BackgroundTransparency = 1; lbl.Text = text
            lbl.TextColor3 = Color3.fromRGB(180, 180, 200); lbl.TextSize = 12; lbl.Font = Enum.Font.Gotham
            lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = container; return lbl
        end

        function tabObj:Separator()
            local sep = Instance.new("Frame")
            sep.Size = UDim2.new(0, 400, 0, 1); sep.BackgroundColor3 = Color3.fromRGB(40, 40, 55); sep.BorderSizePixel = 0
            sep.Parent = container; return sep
        end

        return tabObj
    end

    main.Parent = gui
    XenoHub.UI = gui
    XenoHub.lib = lib
end

-- Fly physics functions (must be defined before command registrations)
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

-- === COMMAND REGISTRATIONS (IY-inspired) ===

-- Movement
XenoHub:AddCmd("fly", {"fly"}, "Toggle fly mode", function(args)
    local spd = tonumber(args[1]) or 50
    XenoHub.Flags.fly = not XenoHub.Flags.fly
    XenoHub.Flags.fly_speed = spd
    local char = LP.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    if XenoHub.Flags.fly then
        hum.PlatformStand = true
        local bv = Instance.new("BodyVelocity")
        bv.Name = "XenoFly"; bv.MaxForce = Vector3.new(100000, 100000, 100000); bv.Velocity = Vector3.new(0,0,0); bv.Parent = hrp
        startFlyPhysics()
        XenoHub:Notify("Fly", "Fly enabled (speed: " .. spd .. ")")
    else
        hum.PlatformStand = false
        stopFlyPhysics()
        local bv = hrp:FindFirstChild("XenoFly"); if bv then bv:Destroy() end
        XenoHub:Notify("Fly", "Fly disabled")
    end
end)

XenoHub:AddCmd("unfly", {"nofly"}, "Disable fly", function()
    XenoHub.Flags.fly = false
    stopFlyPhysics()
    local char = LP.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then hum.PlatformStand = false end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local bv = hrp:FindFirstChild("XenoFly"); if bv then bv:Destroy() end
        end
    end
    XenoHub:Notify("Fly", "Fly disabled")
end)

XenoHub:AddCmd("noclip", {"clip"}, "Toggle noclip", function()
    XenoHub.Flags.noclip = not XenoHub.Flags.noclip
    if XenoHub.Flags.noclip then
        if not XenoHub.Flags.noclip_conn then
            XenoHub.Flags.noclip_conn = RunService.Stepped:Connect(function()
                if XenoHub.Flags.noclip and LP.Character then
                    for _, part in ipairs(LP.Character:GetChildren()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                end
            end)
        end
        XenoHub:Notify("Noclip", "Noclip enabled")
    else
        XenoHub:Notify("Noclip", "Noclip disabled")
    end
end)

XenoHub:AddCmd("speed", {"ws", "walkspeed"}, "Set walkspeed", function(args)
    local speed = tonumber(args[1]) or 16
    local char = LP.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.WalkSpeed = speed
        XenoHub:Notify("Speed", "Walkspeed set to " .. speed)
    end
end)

XenoHub:AddCmd("jumppower", {"jp", "jpower"}, "Set jump power", function(args)
    local power = tonumber(args[1]) or 50
    local char = LP.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.JumpPower = power
        XenoHub:Notify("Jump", "Jump power set to " .. power)
    end
end)

XenoHub:AddCmd("gravity", {"grav"}, "Set gravity", function(args)
    local grav = tonumber(args[1]) or 196.2
    Workspace.Gravity = grav
    XenoHub:Notify("Gravity", "Gravity set to " .. grav)
end)

XenoHub:AddCmd("hipheight", {"hheight"}, "Set hip height", function(args)
    local h = tonumber(args[1]) or 0
    local char = LP.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.HipHeight = h
    end
end)

XenoHub:AddCmd("infinitejump", {"infjump", "infj"}, "Toggle infinite jump", function()
    XenoHub.Flags.infjump = not XenoHub.Flags.infjump
    if XenoHub.Flags.infjump and not XenoHub.Flags.infjump_conn then
        XenoHub.Flags.infjump_conn = UserInputService.JumpRequest:Connect(function()
            if XenoHub.Flags.infjump and LP.Character and LP.Character:FindFirstChild("Humanoid") then
                LP.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    end
    XenoHub:Notify("Infinite Jump", XenoHub.Flags.infjump and "Enabled" or "Disabled")
end)

XenoHub:AddCmd("antivoid", {}, "Prevent void fall", function()
    XenoHub.Flags.antivoid = not XenoHub.Flags.antivoid
    if XenoHub.Flags.antivoid and not XenoHub.Flags.antivoid_conn then
        XenoHub.Flags.antivoid_conn = RunService.RenderStepped:Connect(function()
            if XenoHub.Flags.antivoid and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = LP.Character.HumanoidRootPart
                if hrp.Position.Y < -50 then
                    hrp.CFrame = hrp.CFrame * CFrame.new(0, 100, 0)
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 50, 0)
                end
            end
        end)
    end
    XenoHub:Notify("Anti-Void", XenoHub.Flags.antivoid and "Enabled" or "Disabled")
end)

-- Teleportation
XenoHub:AddCmd("goto", {"to", "tp"}, "Teleport to a player", function(args)
    if not args[1] then return end
    local targets = XenoHub:ParsePlayers(args[1])
    local char = LP.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    for _, target in ipairs(targets) do
        if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 3, 0)
            break
        end
    end
end)

XenoHub:AddCmd("tweengoto", {"tgoto", "tweento", "tto"}, "Tween teleport to player", function(args)
    if not args[1] then return end
    local targets = XenoHub:ParsePlayers(args[1])
    local char = LP.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    for _, target in ipairs(targets) do
        if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
            local tween = TweenService:Create(char.HumanoidRootPart, tweenInfo, {CFrame = target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 3, 0)})
            tween:Play()
            break
        end
    end
end)

XenoHub:AddCmd("tpposition", {"tppos"}, "TP to coordinates", function(args)
    if #args < 3 then XenoHub:Notify("TP", "Usage: tppos X Y Z"); return end
    local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
    local char = LP.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFrame.new(x, y, z)
    end
end)

XenoHub:AddCmd("waypoint", {"wp"}, "Set or teleport to waypoint", function(args)
    if not args[1] then
        -- List waypoints
        for name, pos in pairs(XenoHub.Waypoints) do
            XenoHub:Notify("Waypoint", name .. ": " .. tostring(pos))
        end
        return
    end
    local name = args[1]
    if args[2] == "set" or args[#args] == "set" then
        local char = LP.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            XenoHub.Waypoints[name] = char.HumanoidRootPart.Position
            XenoHub:Notify("Waypoint", "Saved: " .. name)
        end
    elseif XenoHub.Waypoints[name] then
        local char = LP.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = CFrame.new(XenoHub.Waypoints[name])
            XenoHub:Notify("Waypoint", "Teleported to: " .. name)
        end
    else
        local char = LP.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            XenoHub.Waypoints[name] = char.HumanoidRootPart.Position
            XenoHub:Notify("Waypoint", "Saved: " .. name)
        end
    end
end)

XenoHub:AddCmd("offset", {}, "Offset position by X Y Z", function(args)
    if #args < 3 then return end
    local char = LP.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = char.HumanoidRootPart.CFrame + Vector3.new(tonumber(args[1]) or 0, tonumber(args[2]) or 0, tonumber(args[3]) or 0)
    end
end)

XenoHub:AddCmd("notifyposition", {"getpos", "getposition"}, "Get position", function(args)
    local target = LP
    if args[1] then
        local targets = XenoHub:ParsePlayers(args[1])
        if #targets > 0 then target = targets[1] end
    end
    if target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
        local pos = target.Character.HumanoidRootPart.Position
        XenoHub:Notify("Position", target.Name .. ": " .. string.format("%.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z))
    end
end)

XenoHub:AddCmd("clientbring", {"cbring"}, "Bring a player to you", function(args)
    if not args[1] then return end
    local targets = XenoHub:ParsePlayers(args[1])
    local char = LP.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    for _, target in ipairs(targets) do
        if target ~= LP and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
            target.Character.HumanoidRootPart.CFrame = char.HumanoidRootPart.CFrame * CFrame.new(0, 3, 3)
        end
    end
end)

XenoHub:AddCmd("lookat", {"stare", "stareat"}, "Look at a player", function(args)
    if not args[1] then return end
    local targets = XenoHub:ParsePlayers(args[1])
    if #targets == 0 then return end
    local target = targets[1]
    XenoHub.Flags.lookat_target = target
    if not XenoHub.Flags.lookat_conn then
        XenoHub.Flags.lookat_conn = RunService.RenderStepped:Connect(function()
            if XenoHub.Flags.lookat_target and XenoHub.Flags.lookat_target.Character and XenoHub.Flags.lookat_target.Character:FindFirstChild("Head") then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position, XenoHub.Flags.lookat_target.Character.Head.Position)
            end
        end)
    end
    XenoHub:Notify("Look", "Now looking at " .. target.Name)
end)

XenoHub:AddCmd("unlookat", {"unstare", "nostare"}, "Stop looking", function()
    XenoHub.Flags.lookat_target = nil
    if XenoHub.Flags.lookat_conn then XenoHub.Flags.lookat_conn:Disconnect(); XenoHub.Flags.lookat_conn = nil end
end)

-- Player / Character
XenoHub:AddCmd("reset", {}, "Reset character", function()
    local char = LP.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.Health = 0
    end
    pcall(function() LP:LoadCharacter() end)
end)

XenoHub:AddCmd("sit", {}, "Make character sit", function()
    local char = LP.Character
    if char and char:FindFirstChild("Humanoid") then
        char.Humanoid.Sit = true
    end
end)

XenoHub:AddCmd("god", {}, "Make character hard to kill", function()
    local char = LP.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        if hum then
            hum.MaxHealth = math.huge
            hum.Health = math.huge
        end
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") then part.Massless = true end
        end
    end
    XenoHub:Notify("God", "God mode enabled")
end)

XenoHub:AddCmd("spin", {}, "Spin your character", function(args)
    local speed = tonumber(args[1]) or 20
    XenoHub.Flags.spin = not XenoHub.Flags.spin
    if XenoHub.Flags.spin then
        XenoHub.Flags.spin_conn = RunService.RenderStepped:Connect(function()
            if XenoHub.Flags.spin and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
                LP.Character.HumanoidRootPart.CFrame = LP.Character.HumanoidRootPart.CFrame * CFrame.Angles(0, math.rad(speed), 0)
            end
        end)
    else
        if XenoHub.Flags.spin_conn then XenoHub.Flags.spin_conn:Disconnect() end
    end
end)

XenoHub:AddCmd("invisible", {"invis"}, "Toggle invisibility", function()
    XenoHub.Flags.invisible = not XenoHub.Flags.invisible
    local char = LP.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.Transparency = XenoHub.Flags.invisible and 1 or 0 end
        if part:IsA("Decal") then part.Transparency = XenoHub.Flags.invisible and 1 or 0 end
    end
    local hl = char:FindFirstChild("Highlight"); if hl then hl.Enabled = not XenoHub.Flags.invisible end
    XenoHub:Notify("Invisible", XenoHub.Flags.invisible and "You are invisible" or "You are visible")
end)

XenoHub:AddCmd("headsize", {}, "Set head size", function(args)
    local size = tonumber(args[1]) or 5
    local char = LP.Character
    if char and char:FindFirstChild("Head") then
        char.Head.Size = Vector3.new(size, size, size)
    end
end)

XenoHub:AddCmd("noface", {"removeface"}, "Remove face", function()
    local char = LP.Character
    if char and char:FindFirstChild("Head") then
        for _, child in ipairs(char.Head:GetChildren()) do
            if child:IsA("Decal") then child:Destroy() end
        end
    end
end)

XenoHub:AddCmd("noarms", {"rarms"}, "Remove arms", function()
    local char = LP.Character
    if char then
        local left = char:FindFirstChild("Left Arm") or char:FindFirstChild("LeftHand")
        local right = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightHand")
        if left then left.Transparency = 1 end
        if right then right.Transparency = 1 end
    end
end)

XenoHub:AddCmd("nolegs", {"rlegs"}, "Remove legs", function()
    local char = LP.Character
    if char then
        local left = char:FindFirstChild("Left Leg") or char:FindFirstChild("LeftFoot")
        local right = char:FindFirstChild("Right Leg") or char:FindFirstChild("RightFoot")
        if left then left.Transparency = 1 end
        if right then right.Transparency = 1 end
    end
end)

XenoHub:AddCmd("blockhead", {}, "Make head a block", function()
    local char = LP.Character
    if char and char:FindFirstChild("Head") then
        char.Head.MeshId = ""
        char.Head.Shape = Enum.PartType.Block
        char.Head.Size = Vector3.new(2, 2, 2)
    end
end)

-- Visual
XenoHub:AddCmd("esp", {}, "Toggle player ESP", function()
    XenoHub.Flags.esp_enabled = not XenoHub.Flags.esp_enabled
    if XenoHub.Flags.esp_enabled then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character and not p.Character:FindFirstChild("XenoESP") then
                local hl = Instance.new("Highlight"); hl.Name = "XenoESP"
                hl.FillColor = Color3.fromRGB(255, 50, 50); hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                hl.FillTransparency = 0.5; hl.Adornee = p.Character; hl.Parent = p.Character
            end
        end
        XenoHub:Notify("ESP", "ESP enabled")
    else
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then local hl = p.Character:FindFirstChild("XenoESP"); if hl then hl:Destroy() end end
        end
        XenoHub:Notify("ESP", "ESP disabled")
    end
end)

XenoHub:AddCmd("xray", {}, "Toggle X-Ray", function()
    XenoHub.Flags.xray = not XenoHub.Flags.xray
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") and not v:IsA("Terrain") then
            v.LocalTransparencyModifier = XenoHub.Flags.xray and 0.7 or 0
        end
    end
end)

XenoHub:AddCmd("fullbright", {"fb"}, "Toggle fullbright", function()
    XenoHub.Flags.fullbright = not XenoHub.Flags.fullbright
    if XenoHub.Flags.fullbright then
        Lighting.Ambient = Color3.fromRGB(255, 255, 255); Lighting.Brightness = 2; Lighting.FogEnd = 100000; Lighting.GlobalShadows = false
    else
        Lighting.Ambient = Color3.fromRGB(80, 80, 80); Lighting.Brightness = 1; Lighting.FogEnd = 786432; Lighting.GlobalShadows = true
    end
end)

XenoHub:AddCmd("fov", {}, "Set field of view", function(args)
    local fov = tonumber(args[1]) or 90
    Camera.FieldOfView = fov
end)

XenoHub:AddCmd("freecam", {"fc"}, "Toggle freecam", function()
    XenoHub.Flags.freecam = not XenoHub.Flags.freecam
    if XenoHub.Flags.freecam then
        XenoHub.Flags.freecam_cam = Instance.new("Camera")
        XenoHub.Flags.freecam_cam.Name = "XenoFreeCam"
        XenoHub.Flags.freecam_cam.CFrame = Camera.CFrame
        XenoHub.Flags.freecam_cam.Parent = Workspace.CurrentCamera
        Camera.CameraType = Enum.CameraType.Scriptable
        XenoHub.Flags.freecam_conn = RunService.RenderStepped:Connect(function()
            if XenoHub.Flags.freecam then
                local speed = 20
                local move = Vector3.new(0, 0, 0)
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + XenoHub.Flags.freecam_cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - XenoHub.Flags.freecam_cam.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - XenoHub.Flags.freecam_cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + XenoHub.Flags.freecam_cam.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0, 1, 0) end
                if move.Magnitude > 0 then
                    XenoHub.Flags.freecam_cam.CFrame = XenoHub.Flags.freecam_cam.CFrame + move.Unit * speed
                end
                Camera.CFrame = XenoHub.Flags.freecam_cam.CFrame
            end
        end)
    else
        if XenoHub.Flags.freecam_conn then XenoHub.Flags.freecam_conn:Disconnect() end
        if XenoHub.Flags.freecam_cam then XenoHub.Flags.freecam_cam:Destroy() end
        Camera.CameraType = Enum.CameraType.Custom
    end
end)

XenoHub:AddCmd("hitbox", {"hitboxexpand"}, "Expand hitbox of a player", function(args)
    if not args[1] then return end
    local targets = XenoHub:ParsePlayers(args[1])
    local size = Vector3.new(tonumber(args[2]) or 10, tonumber(args[2]) or 10, tonumber(args[2]) or 10)
    for _, p in ipairs(targets) do
        if p.Character then
            for _, part in ipairs(p.Character:GetDescendants()) do
                if part:IsA("BasePart") then part.Size = size end
            end
        end
    end
end)

XenoHub:AddCmd("ambient", {}, "Set ambient color", function(args)
    if #args < 3 then return end
    Lighting.Ambient = Color3.fromRGB(tonumber(args[1]) or 255, tonumber(args[2]) or 255, tonumber(args[3]) or 255)
end)

XenoHub:AddCmd("day", {}, "Client-side day", function()
    Lighting.ClockTime = 12
end)

XenoHub:AddCmd("night", {}, "Client-side night", function()
    Lighting.ClockTime = 0
end)

XenoHub:AddCmd("nofog", {}, "Remove fog", function()
    Lighting.FogEnd = 100000
    Lighting.FogStart = 100000
end)

-- Chat
XenoHub:AddCmd("chat", {"say"}, "Send chat message", function(args)
    local text = table.concat(args, " ")
    if text == "" then return end
    pcall(function()
        local sayReq = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        if sayReq then sayReq = sayReq:FindFirstChild("SayMessageRequest") end
        if sayReq then sayReq:FireServer(text, "All") end
    end)
end)

XenoHub:AddCmd("spam", {}, "Spam chat messages", function(args)
    local text = table.concat(args, " ")
    if text == "" then text = "Xeno Hub owns!" end
    XenoHub.Flags.spam = not XenoHub.Flags.spam
    if XenoHub.Flags.spam then
        local sayReq = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
        if sayReq then sayReq = sayReq:FindFirstChild("SayMessageRequest") end
        XenoHub.Flags.spam_conn = RunService.Heartbeat:Connect(function()
            if not XenoHub.Flags.spam then XenoHub.Flags.spam_conn:Disconnect() return end
            pcall(function() if sayReq then sayReq:FireServer(text, "All") end end)
            task.wait(0.3)
        end)
    end
end)

XenoHub:AddCmd("unspam", {"nospam"}, "Stop spam", function()
    XenoHub.Flags.spam = false
    if XenoHub.Flags.spam_conn then XenoHub.Flags.spam_conn:Disconnect() end
end)

-- Combat
XenoHub:AddCmd("fling", {}, "Toggle fling", function()
    XenoHub.Flags.fling = not XenoHub.Flags.fling
    if XenoHub.Flags.fling then
        XenoHub.Flags.fling_conn = RunService.Stepped:Connect(function()
            if XenoHub.Flags.fling and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = LP.Character.HumanoidRootPart
                hrp.RotVelocity = Vector3.new(200, 200, 200)
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                        local target = p.Character.HumanoidRootPart
                        if (target.Position - hrp.Position).Magnitude < 10 then
                            target.CFrame = CFrame.new(target.Position) * CFrame.Angles(math.rad(45), 0, 0)
                            target.AssemblyLinearVelocity = Vector3.new(0, 100, 0)
                        end
                    end
                end
            end
        end)
        XenoHub:Notify("Fling", "Fling enabled")
    else
        if XenoHub.Flags.fling_conn then XenoHub.Flags.fling_conn:Disconnect() end
        if LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
            LP.Character.HumanoidRootPart.RotVelocity = Vector3.new(0, 0, 0)
        end
        XenoHub:Notify("Fling", "Fling disabled")
    end
end)

XenoHub:AddCmd("antifling", {}, "Toggle anti-fling", function()
    XenoHub.Flags.antifling = not XenoHub.Flags.antifling
    if XenoHub.Flags.antifling then
        local suc = pcall(function()
            local mt = getrawmetatable(game)
            XenoHub.Flags.antifling_old = mt.__index
            setreadonly(mt, false)
            mt.__index = newcclosure(function(self, key)
                if key == "CanCollide" and self:IsA("BasePart") and self.Parent == LP.Character then
                    return false
                end
                return XenoHub.Flags.antifling_old(self, key)
            end)
            setreadonly(mt, true)
        end)
        if suc then XenoHub:Notify("Anti-Fling", "Enabled") end
    else
        pcall(function()
            local mt = getrawmetatable(game)
            if XenoHub.Flags.antifling_old then
                setreadonly(mt, false)
                mt.__index = XenoHub.Flags.antifling_old
                setreadonly(mt, true)
                XenoHub.Flags.antifling_old = nil
            end
        end)
        XenoHub:Notify("Anti-Fling", "Disabled")
    end
end)

function XenoHub:Teleport(pos)
    local char = LP.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = CFrame.new(pos)
    end
end

local fireTouch = firetouchinterest or function()
    warn("[XenoHub] firetouchinterest not available on this executor")
end

XenoHub:AddCmd("handlekill", {"hkill"}, "Kill player with tool", function(args)
    if not args[1] then return end
    local targets = XenoHub:ParsePlayers(args[1])
    local radius = tonumber(args[2]) or 10
    local char = LP.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then tool = LP.Backpack:FindFirstChildOfClass("Tool") end
    if not tool then XenoHub:Notify("Kill", "Need a tool!"); return end
    tool.Parent = char
    task.wait(0.1)
    for _, p in ipairs(targets) do
        if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local targetPos = p.Character.HumanoidRootPart.Position
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp and (targetPos - hrp.Position).Magnitude <= radius then
                fireTouch(tool.Handle, p.Character.HumanoidRootPart, 0)
                task.wait(0.1)
                fireTouch(tool.Handle, p.Character.HumanoidRootPart, 1)
            end
        end
    end
end)

-- Server
XenoHub:AddCmd("rejoin", {"rj"}, "Rejoin the game", function()
    TeleportService:Teleport(PlaceId, LP)
end)

XenoHub:AddCmd("serverhop", {"shop"}, "Server hop", function()
    local cursor = ""
    for i = 1, 10 do
        local suc, res = pcall(function()
            local url = "https://apis.roblox.com/universes/v1/places/" .. PlaceId .. "/servers/Public?limit=100"
            if cursor ~= "" then url = url .. "&cursor=" .. cursor end
            return game:HttpGet(url)
        end)
        local data
        if suc then
            local suc2, decoded = pcall(function() return HttpService:JSONDecode(res) end)
            if suc2 then data = decoded end
            if data and data.data then
                for _, server in ipairs(data.data) do
                    if server.id ~= game.JobId then
                        TeleportService:TeleportToPlaceInstance(PlaceId, server.id, LP)
                        return
                    end
                end
            end
            if data then cursor = data.nextPageCursor or "" end
            if cursor == "" then break end
        else break end
    end
    XenoHub:Notify("Server Hop", "No other servers found")
end)

XenoHub:AddCmd("antiafk", {"antiidle"}, "Toggle anti-AFK", function()
    XenoHub.Flags.antiafk = not XenoHub.Flags.antiafk
    if XenoHub.Flags.antiafk then
        if not XenoHub.Flags.antiafk_conn then
            XenoHub.Flags.antiafk_conn = RunService.Heartbeat:Connect(function()
                if XenoHub.Flags.antiafk then
                    local char = LP.Character
                    if char and char:FindFirstChild("Humanoid") then
                        char.Humanoid:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
                    end
                    VirtualInputManager:SendMouseMoveEvent(0, 0, false)
                    task.wait(5)
                end
            end)
        end
    else
        if XenoHub.Flags.antiafk_conn then
            XenoHub.Flags.antiafk_conn:Disconnect()
            XenoHub.Flags.antiafk_conn = nil
        end
    end
    XenoHub:Notify("Anti-AFK", XenoHub.Flags.antiafk and "Enabled" or "Disabled")
end)

XenoHub:AddCmd("exit", {}, "Exit Roblox", function()
    game:Shutdown()
end)

XenoHub:AddCmd("serverinfo", {"sinfo", "info"}, "Show server info", function()
    XenoHub:Notify("Server Info", "Place: " .. PlaceId .. " | Job: " .. game.JobId .. " | Players: " .. #Players:GetPlayers())
end)

XenoHub:AddCmd("jobid", {}, "Copy JobId", function()
    pcall(function() setclipboard(game.JobId) end)
    XenoHub:Notify("JobID", "Copied to clipboard")
end)

-- Troll
XenoHub:AddCmd("killall", {}, "Kill all players", function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local hum = p.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then hum.Health = 0 end
        end
    end
    XenoHub:Notify("Kill All", "All players killed")
end)

XenoHub:AddCmd("freeze", {"fr"}, "Freeze a player", function(args)
    if not args[1] then return end
    local targets = XenoHub:ParsePlayers(args[1])
    for _, p in ipairs(targets) do
        if p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = p.Character.HumanoidRootPart
            local bp = Instance.new("BodyPosition"); bp.Position = hrp.Position; bp.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bp.Name = "XenoFreeze"; bp.Parent = hrp
        end
    end
end)

XenoHub:AddCmd("thaw", {"unfreeze", "unfr"}, "Unfreeze a player", function(args)
    if not args[1] then return end
    local targets = XenoHub:ParsePlayers(args[1])
    for _, p in ipairs(targets) do
        if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local hrp = p.Character.HumanoidRootPart
            local bp = hrp:FindFirstChild("XenoFreeze"); if bp then bp:Destroy() end
        end
    end
end)

XenoHub:AddCmd("explode", {}, "Explode at mouse", function()
    local target = Mouse.Target or (LP.Character and LP.Character:FindFirstChild("HumanoidRootPart"))
    if target then
        local exp = Instance.new("Explosion"); exp.BlastRadius = 20; exp.BlastPressure = 100000; exp.Position = target.Position; exp.Parent = Workspace
    end
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
            end
            task.wait(0.8)
        end)
    end
end)

XenoHub:AddCmd("forcefield", {"ff"}, "Give forcefield to all or target", function(args)
    local targets = args[1] and XenoHub:ParsePlayers(args[1]) or Players:GetPlayers()
    for _, p in ipairs(targets) do
        if p.Character then
            local ff = Instance.new("ForceField"); ff.Parent = p.Character
        end
    end
end)

XenoHub:AddCmd("fakeshutdown", {}, "Fake server shutdown", function()
    local msg = Instance.new("Message"); msg.Text = "SERVER SHUTDOWN IN 10 SECONDS"; msg.Parent = Workspace
    task.delay(3, function() msg.Text = "5..."; task.delay(2, function() msg.Text = "Just kidding! Xeno Hub!"; task.delay(3, function() pcall(function() msg:Destroy() end) end) end) end)
end)

XenoHub:AddCmd("unanchor", {"breakparts"}, "Unanchor nearby parts", function(args)
    local radius = tonumber(args[1]) or 50
    local char = LP.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local pos = char.HumanoidRootPart.Position
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") and v.Anchored and not v:IsA("Terrain") then
            if (v.Position - pos).Magnitude < radius then v.Anchored = false end
        end
    end
end)

-- World
XenoHub:AddCmd("btools", {"f3x", "fex"}, "Give building tools", function()
    pcall(function()
        pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/f3x.lua"))() end)
        XenoHub:Notify("BTools", "Building tools given")
    end)
end)

XenoHub:AddCmd("delete", {"remove"}, "Delete part by name", function(args)
    local name = table.concat(args, " ")
    if name == "" then return end
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v.Name:lower():find(name:lower()) and v:IsA("BasePart") then
            v:Destroy()
            break
        end
    end
end)

XenoHub:AddCmd("deleteclass", {"dc", "removeclass"}, "Delete parts by class", function(args)
    local className = args[1]
    if not className then return end
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v.ClassName:lower() == className:lower() then v:Destroy() end
    end
end)

XenoHub:AddCmd("removeterrain", {"rterrain", "noterrain"}, "Remove terrain", function()
    pcall(function() Workspace.Terrain:Clear() end)
end)

-- UI
XenoHub:AddCmd("notify", {}, "Send notification", function(args)
    local text = table.concat(args, " ")
    if text ~= "" then XenoHub:Notify("Xeno Hub", text) end
end)

XenoHub:AddCmd("console", {}, "Open Roblox console", function()
    pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/console.lua"))() end)
end)

XenoHub:AddCmd("hideiy", {"hidehub", "hidegui"}, "Toggle hub visibility", function()
    if XenoHub.UI then XenoHub.UI.Enabled = not XenoHub.UI.Enabled end
end)

XenoHub:AddCmd("togglefullscreen", {"togglefs"}, "Toggle fullscreen", function()
    UserInputService:ToggleFullscreen()
end)

XenoHub:AddCmd("ping", {"notifyping"}, "Show ping", function()
    local ping = StatsService:FindFirstChild("Network") and StatsService.Network:FindFirstChild("ServerStatsItem")
    if ping then
        XenoHub:Notify("Ping", "Network Ping: " .. math.floor(ping:GetValue()) .. "ms")
    end
end)

XenoHub:AddCmd("fps", {}, "Toggle FPS counter", function()
    XenoHub.Flags.fps = not XenoHub.Flags.fps
    if XenoHub.Flags.fps then
        local stats = Instance.new("Folder"); stats.Name = "XenoFPS"
        local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(0, 100, 0, 30); lbl.Position = UDim2.new(0, 10, 0, 10)
        lbl.BackgroundTransparency = 0.8; lbl.BackgroundColor3 = Color3.fromRGB(0, 0, 0); lbl.TextColor3 = Color3.fromRGB(0, 255, 0)
        lbl.TextSize = 16; lbl.Font = Enum.Font.GothamBold; lbl.ZIndex = 100; lbl.Parent = stats
        stats.Parent = LP:WaitForChild("PlayerGui")
        local fc = 0; local lt = tick()
        XenoHub.Flags.fps_conn = RunService.RenderStepped:Connect(function()
            fc = fc + 1; local now = tick()
            if now - lt >= 1 then lbl.Text = "FPS: " .. fc; fc = 0; lt = now end
        end)
        XenoHub.Flags.fps_stats = stats
    else
        if XenoHub.Flags.fps_conn then XenoHub.Flags.fps_conn:Disconnect() end
        local s = LP.PlayerGui:FindFirstChild("XenoFPS"); if s then s:Destroy() end
    end
end)


-- === UI BUILD ===
local tabs = XenoHub.lib

-- Main tab
local mainTab = tabs:Tab("Main")
mainTab:Label("Xeno Hub v" .. XenoHub.Version .. " | " .. XenoHub.CurrentGame)
mainTab:Label("Player: " .. LP.Name .. " | Prefix: " .. XenoHub.Prefix)
mainTab:Button("Rejoin Game", function() XenoHub:ExecCmd("rejoin") end)
mainTab:Button("Server Hop", function() XenoHub:ExecCmd("serverhop") end)
mainTab:Toggle("ESP (Players)", false, function(state) XenoHub.Flags.esp_enabled = state
    if state then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then
                local hl = Instance.new("Highlight"); hl.Name = "XenoESP"; hl.FillColor = Color3.fromRGB(255, 50, 50)
                hl.OutlineColor = Color3.fromRGB(255, 255, 255); hl.FillTransparency = 0.5; hl.Adornee = p.Character; hl.Parent = p.Character
            end
        end
    else
        for _, p in ipairs(Players:GetPlayers()) do if p.Character then local h = p.Character:FindFirstChild("XenoESP"); if h then h:Destroy() end end end
    end
end)
mainTab:Toggle("FPS Counter", false, function(state)
    if state ~= XenoHub.Flags.fps then XenoHub:ExecCmd("fps") end
end)
mainTab:Toggle("Anti-AFK", false, function(state)
    if state ~= XenoHub.Flags.antiafk then XenoHub:ExecCmd("antiafk") end
end)

-- Movement tab
local moveTab = tabs:Tab("Movement")
moveTab:Section("Movement")
moveTab:Button("Fly", function() XenoHub:ExecCmd("fly") end)
moveTab:Button("Noclip", function() XenoHub:ExecCmd("noclip") end)
moveTab:Button("Infinite Jump", function() XenoHub:ExecCmd("infinitejump") end)
moveTab:Slider("Walk Speed", 16, 200, 16, function(v) XenoHub:ExecCmd("speed " .. v) end)
moveTab:Slider("Jump Power", 50, 400, 50, function(v) XenoHub:ExecCmd("jumppower " .. v) end)
moveTab:Slider("Gravity", 0, 500, 196, function(v) XenoHub:ExecCmd("gravity " .. v) end)
moveTab:Button("Spin", function() XenoHub:ExecCmd("spin") end)
moveTab:Button("Anti-Void", function() XenoHub:ExecCmd("antivoid") end)
moveTab:Toggle("No Fall Damage", false, function(state)
    XenoHub.Flags.nofall = state
    if state then
        if XenoHub.Flags.nofall_conn then XenoHub.Flags.nofall_conn:Disconnect() end
        XenoHub.Flags.nofall_conn = LP.CharacterAdded:Connect(function(char)
            local hum = char:WaitForChild("Humanoid")
            local stateConn
            stateConn = hum.StateChanged:Connect(function(_, new)
                if new == Enum.HumanoidStateType.Freefall and XenoHub.Flags.nofall then
                    hum:ChangeState(Enum.HumanoidStateType.Landed)
                end
            end)
            char:AncestryChanged:Connect(function()
                if not char.Parent and stateConn then stateConn:Disconnect() end
            end)
        end)
        -- Also apply to current character
        if LP.Character and LP.Character:FindFirstChild("Humanoid") then
            local hum = LP.Character.Humanoid
            local stateConn
            stateConn = hum.StateChanged:Connect(function(_, new)
                if new == Enum.HumanoidStateType.Freefall and XenoHub.Flags.nofall then
                    hum:ChangeState(Enum.HumanoidStateType.Landed)
                end
            end)
        end
    else
        if XenoHub.Flags.nofall_conn then XenoHub.Flags.nofall_conn:Disconnect(); XenoHub.Flags.nofall_conn = nil end
    end
end)

-- Teleport tab
local tpTab = tabs:Tab("Teleport")
tpTab:Section("Teleport")
tpTab:Input("TP to player", function(t) XenoHub:ExecCmd("goto " .. t) end, "username")
tpTab:Input("Tween to player", function(t) XenoHub:ExecCmd("tweengoto " .. t) end, "username")
tpTab:Input("Bring player", function(t) XenoHub:ExecCmd("clientbring " .. t) end, "username")
tpTab:Input("TP to coords", function(t) if t:match("^[%d%.%-]+ [%d%.%-]+ [%d%.%-]+$") then XenoHub:ExecCmd("tpposition " .. t) end end, "X Y Z")
tpTab:Separator()
tpTab:Section("Waypoints")
tpTab:Input("Save waypoint", function(t) XenoHub:ExecCmd("waypoint " .. t .. " set") end, "name")
tpTab:Input("Go to waypoint", function(t) XenoHub:ExecCmd("waypoint " .. t) end, "name")
tpTab:Input("Look at player", function(t) XenoHub:ExecCmd("lookat " .. t) end, "username")

-- Visual tab
local visualTab = tabs:Tab("Visuals")
visualTab:Button("Fullbright", function() XenoHub:ExecCmd("fullbright") end)
visualTab:Button("X-Ray", function() XenoHub:ExecCmd("xray") end)
visualTab:Button("Freecam (WASD)", function() XenoHub:ExecCmd("freecam") end)
visualTab:Slider("FOV", 30, 120, 70, function(v) Camera.FieldOfView = v end)
visualTab:Button("Day", function() Lighting.ClockTime = 12 end)
visualTab:Button("Night", function() Lighting.ClockTime = 0 end)
visualTab:Button("No Fog", function() Lighting.FogEnd = 100000; Lighting.FogStart = 100000 end)

-- Combat tab
local combatTab = tabs:Tab("Combat")
combatTab:Button("Fling (touch kill)", function() XenoHub:ExecCmd("fling") end)
combatTab:Button("Anti-Fling", function() XenoHub:ExecCmd("antifling") end)
combatTab:Button("Kill All", function() XenoHub:ExecCmd("killall") end)
combatTab:Input("Kill player (need tool)", function(t) XenoHub:ExecCmd("handlekill " .. t) end, "username")
combatTab:Input("Hitbox player", function(t) XenoHub:ExecCmd("hitbox " .. t) end, "username")

-- Player tab
local playerTab = tabs:Tab("Player")
playerTab:Button("Invisible", function() XenoHub:ExecCmd("invisible") end)
playerTab:Button("God Mode", function() XenoHub:ExecCmd("god") end)
playerTab:Button("Reset", function() XenoHub:ExecCmd("reset") end)
playerTab:Button("Sit", function() XenoHub:ExecCmd("sit") end)
playerTab:Button("Remove Face", function() XenoHub:ExecCmd("noface") end)
playerTab:Button("Block Head", function() XenoHub:ExecCmd("blockhead") end)
playerTab:Slider("Head Size", 1, 10, 1, function(v) XenoHub:ExecCmd("headsize " .. v) end)

-- Troll tab
local trollTab = tabs:Tab("Troll")
trollTab:Section("Player Trolling")
trollTab:Button("Kill All Players", function() XenoHub:ExecCmd("killall") end)
trollTab:Input("Freeze player", function(t) XenoHub:ExecCmd("freeze " .. t) end, "username")
trollTab:Input("Thaw player", function(t) XenoHub:ExecCmd("thaw " .. t) end, "username")
trollTab:Button("Forcefield Everyone", function() XenoHub:ExecCmd("forcefield") end)
trollTab:Button("Loop Oof All", function() XenoHub:ExecCmd("loopoof") end)
trollTab:Button("Explode at Mouse", function() XenoHub:ExecCmd("explode") end)
trollTab:Separator()
trollTab:Section("Chat Trolling")
trollTab:Button("Spam Chat", function() XenoHub:ExecCmd("spam Xeno Hub owns!") end)
trollTab:Button("Stop Spam", function() XenoHub:ExecCmd("unspam") end)
trollTab:Input("Send Chat", function(t) XenoHub:ExecCmd("chat " .. t) end, "message")
trollTab:Button("Fake Shutdown", function() XenoHub:ExecCmd("fakeshutdown") end)
trollTab:Separator()
trollTab:Section("World Trolling")
trollTab:Input("Unanchor Nearby (radius)", function(t) XenoHub:ExecCmd("unanchor " .. t) end, "50")
trollTab:Input("Delete Part by Name", function(t) XenoHub:ExecCmd("delete " .. t) end, "part name")
trollTab:Button("Remove Terrain", function() pcall(function() Workspace.Terrain:Clear() end) end)
trollTab:Button("BTools", function() XenoHub:ExecCmd("btools") end)

-- Server tab
local serverTab = tabs:Tab("Server")
serverTab:Button("Rejoin", function() XenoHub:ExecCmd("rejoin") end)
serverTab:Button("Server Hop", function() XenoHub:ExecCmd("serverhop") end)
serverTab:Button("Toggle Fullscreen", function() XenoHub:ExecCmd("togglefullscreen") end)
serverTab:Button("Console", function() XenoHub:ExecCmd("console") end)
serverTab:Button("Open DEX Explorer", function()
    pcall(function() loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/dex.lua"))() end)
end)
serverTab:Button("Server Info", function() XenoHub:ExecCmd("serverinfo") end)
serverTab:Button("Show Ping", function() XenoHub:ExecCmd("ping") end)
serverTab:Button("Anti-AFK", function() XenoHub:ExecCmd("antiafk") end)

-- Game-specific tabs (simplified - same as original)
if XenoHub.CurrentGame == "MM2" then
    local mm2Tab = tabs:Tab("MM2")
    mm2Tab:Section("Murder Mystery 2")
    mm2Tab:Button("Reveal Roles", function()
        for _, p in ipairs(Players:GetPlayers()) do
            local data = p:FindFirstChild("Data")
            if data then
                local role = data:FindFirstChild("Role")
                if role then XenoHub:Notify("Role Reveal", p.Name .. " is " .. role.Value) end
            end
        end
    end)
    mm2Tab:Button("Auto-Shoot (Sheriff)", function()
        local gun
        for _, item in ipairs(LP.Backpack:GetChildren()) do if item:FindFirstChild("Gun") then gun = item; break end end
        if not gun and LP.Character then for _, item in ipairs(LP.Character:GetChildren()) do if item:FindFirstChild("Gun") then gun = item; break end end end
        if not gun then XenoHub:Notify("Auto-Shoot", "Not sheriff"); return end
        XenoHub.Flags.mm2_autoshoot = RunService.Heartbeat:Connect(function()
            if not gun or not gun.Parent then XenoHub.Flags.mm2_autoshoot:Disconnect() return end
            local closest, bestDist; local myPos = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if not myPos then return end
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    local d = (myPos.Position - p.Character.HumanoidRootPart.Position).Magnitude
                    if d < (bestDist or math.huge) then bestDist = d; closest = p end
                end
            end
            if closest and closest.Character and closest.Character:FindFirstChild("HumanoidRootPart") then
                pcall(function() gun:Activate() end)
            end
        end)
    end)
    mm2Tab:Button("Auto-Attack (Murderer)", function()
        local knife
        for _, item in ipairs(LP.Backpack:GetChildren()) do if item:FindFirstChild("Knife") then knife = item; break end end
        if not knife and LP.Character then for _, item in ipairs(LP.Character:GetChildren()) do if item:FindFirstChild("Knife") then knife = item; break end end end
        if not knife then XenoHub:Notify("Auto-Attack", "Not murderer"); return end
        XenoHub.Flags.mm2_autoattack = RunService.Heartbeat:Connect(function()
            if not knife or not knife.Parent then XenoHub.Flags.mm2_autoattack:Disconnect(); return end
            local closest, bestDist; local myPos = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if not myPos then return end
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    local d = (myPos.Position - p.Character.HumanoidRootPart.Position).Magnitude
                    if d < (bestDist or math.huge) then bestDist = d; closest = p end
                end
            end
            if closest and closest.Character and closest.Character:FindFirstChild("HumanoidRootPart") then
                if (myPos.Position - closest.Character.HumanoidRootPart.Position).Magnitude < 15 then
                    pcall(function() knife:Activate() end)
                end
            end
        end)
    end)
end

if XenoHub.CurrentGame == "Jailbreak" then
    local jbTab = tabs:Tab("Jailbreak")
    jbTab:Button("TP to Bank", function() XenoHub:Teleport(Vector3.new(-99, 0, -377)) end)
    jbTab:Button("TP to Prison", function() XenoHub:Teleport(Vector3.new(317, 0, -317)) end)
    jbTab:Button("TP to Jewelry", function() XenoHub:Teleport(Vector3.new(-347, 0, 127)) end)
end

-- === GLOBAL INPUT ===
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    -- RightShift to toggle GUI (only when not flying)
    if input.KeyCode == Enum.KeyCode.RightShift then
        if XenoHub.UI and not XenoHub.Flags.fly then
            XenoHub.UI.Enabled = not XenoHub.UI.Enabled
        end
    end
    -- Fly controls
    if input.KeyCode == Enum.KeyCode.Space and XenoHub.Flags.fly then XenoHub.Flags.fly_up = true end
    if input.KeyCode == Enum.KeyCode.LeftShift and XenoHub.Flags.fly then XenoHub.Flags.fly_down = true end
end)

UserInputService.InputEnded:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Space and XenoHub.Flags.fly then XenoHub.Flags.fly_up = false end
    if input.KeyCode == Enum.KeyCode.LeftShift and XenoHub.Flags.fly then XenoHub.Flags.fly_down = false end
end)

-- Fly physics (managed by fly/unfly commands, defined above)

-- Infinite jump
UserInputService.JumpRequest:Connect(function()
    if XenoHub.Flags.infjump and LP.Character and LP.Character:FindFirstChild("Humanoid") then
        LP.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

-- ESP auto-add
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function(char)
        if XenoHub.Flags.esp_enabled and not char:FindFirstChild("XenoESP") then
            local hl = Instance.new("Highlight"); hl.Name = "XenoESP"; hl.FillColor = Color3.fromRGB(255, 50, 50)
            hl.OutlineColor = Color3.fromRGB(255, 255, 255); hl.FillTransparency = 0.5; hl.Adornee = char; hl.Parent = char
        end
    end)
end)

-- Command history keyboard nav
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Up then
        -- Not implemented for cmd bar focus in this version
    end
end)

print("=== Xeno Universal Hub v" .. XenoHub.Version .. " loaded ===")
print("Detected game: " .. XenoHub.CurrentGame)
print("Commands available: " .. #XenoHub.Cmds .. " | Use " .. XenoHub.Prefix .. "command in the command bar")
print("Press RightShift to toggle GUI")

return XenoHub