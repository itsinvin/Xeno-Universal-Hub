-- Xeno Hub Loader v2.2
-- Paste this into Xeno executor
-- Tries every possible load method

local XENO_HUB_VERSION = "2.0"
local RAW_URL = "https://raw.githubusercontent.com/itsinvin/Xeno-Universal-Hub/master/workspace/XenoHub.lua"

-- StarterGui notification
local function notif(t, d)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Xeno Hub",
            Text = t,
            Duration = d or 8
        })
    end)
end

-- DO NOT set XENO_HUB_LOADED here — the hub script sets it itself

-- Wait for game
repeat task.wait() until game:IsLoaded()

notif("Loading Xeno Hub...", 3)

-- Try every possible load method
local code, source

-- Method 1: isfile/readfile (local file in executor workspace)
pcall(function()
    if isfile and isfile("XenoHub.lua") then
        code = readfile("XenoHub.lua")
        if code and #code > 100 then source = "local file" end
    end
end)

-- Method 2: XenoHub.lua from script's parent directory (executor workspace)
pcall(function()
    if not code and isfile and isfile("workspace/XenoHub.lua") then
        code = readfile("workspace/XenoHub.lua")
        if code and #code > 100 then source = "workspace file" end
    end
end)

-- Method 3: game:HttpGet (standard Roblox HTTP)
pcall(function()
    if not code then
        local c = game:HttpGet(RAW_URL)
        if c and #c > 100 then code = c; source = "HTTP" end
    end
end)

-- Method 4: syn.request / http_request
pcall(function()
    if not code then
        local req = syn and syn.request or http_request or request
        if req then
            local r = req({Url = RAW_URL, Method = "GET"})
            if r and r.StatusCode == 200 and r.Body and #r.Body > 100 then
                code = r.Body; source = "request"
            end
        end
    end
end)

if not code then
    notif("No download method worked! Open F9 console for details", 10)
    warn("[Xeno Hub] All download methods failed!")
    warn("[Xeno Hub] Check: isfile=" .. tostring(isfile) .. ", syn.request=" .. tostring(syn and syn.request) .. ", http_request=" .. tostring(http_request))
    return
end

-- Execute
local fn, err = loadstring(code)
if not fn then
    notif("loadstring failed: " .. tostring(err):sub(1, 80), 10)
    warn("[Xeno Hub] loadstring failed: " .. tostring(err))
    return
end

local ok, result = pcall(fn)
if not ok then
    notif("Execution FAILED: " .. tostring(result):sub(1, 80), 15)
    warn("[Xeno Hub] execution failed: " .. tostring(result))
    return
end

if type(result) ~= "table" then
    notif("Bad return type: " .. type(result), 10)
    return
end

notif("Loaded from " .. source .. "! RightShift to toggle", 4)
print("[Xeno Hub v" .. XENO_HUB_VERSION .. "] Loaded from " .. source)
getgenv().XENO_HUB_INSTANCE = result

-- Queue on teleport
local qot = syn and syn.queue_on_teleport or queue_on_teleport
if qot then
    qot('loadstring(game:HttpGet("' .. RAW_URL .. '"))()')
end

print("=== Xeno Hub v" .. XENO_HUB_VERSION .. " Loader ===")
print("Press RightShift to toggle menu")