-- Xeno Hub Loader v2.5
-- Paste this into Xeno executor
-- Writes hub to workspace for instant loading on subsequent runs

local XENO_HUB_VERSION = "3.1"
local RAW_URL = "https://raw.githubusercontent.com/itsinvin/Xeno-Universal-Hub/master/workspace/XenoHub.lua"

local logLines = {}
local function log(...)
    local msg = table.concat({...}, " ")
    local ts = os.date("%H:%M:%S") or tick()
    local line = "[" .. tostring(ts) .. "] " .. msg
    table.insert(logLines, line); warn(msg)
end
local function saveLog(success)
    local content = table.concat(logLines, "\n")
    local status = success and "SUCCESS" or "FAILED"
    content = "=== Xeno Hub Loader v2.5 - " .. status .. " ===\n" ..
              "Timestamp: " .. (os.date("%Y-%m-%d %H:%M:%S") or "unknown") .. "\n" ..
              "Game: " .. tostring(game.PlaceId) .. "\n" ..
              "URL: " .. RAW_URL .. "\n\n" .. content
    pcall(function() writefile("XenoHub_Log.txt", content) end)
end
local function notif(t, d)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {Title = "Xeno Hub", Text = t, Duration = d or 8})
    end)
end

-- Re-use cached instance
if getgenv and getgenv().XENO_HUB_LOADED and getgenv().XENO_HUB_INSTANCE then
    print("=== Xeno Hub v" .. XENO_HUB_VERSION .. " (reloaded) ===")
    return getgenv().XENO_HUB_INSTANCE
end

log("Loader started, waiting for game...")
repeat task.wait() until game:IsLoaded()
log("Game loaded. PlaceId: " .. tostring(game.PlaceId))
notif("Loading Xeno Hub...", 3)

log("Executor checks:")
pcall(function()
    log("  isfile: " .. tostring(isfile))
    log("  readfile: " .. tostring(readfile))
    log("  writefile: " .. tostring(writefile))
    log("  loadstring: " .. tostring(loadstring))
    log("  syn.request: " .. tostring(syn and syn.request))
    log("  http_request: " .. tostring(http_request))
    log("  request: " .. tostring(request))
    log("  getgenv: " .. tostring(getgenv))
    log("  getrawmetatable: " .. tostring(getrawmetatable))
end)

local code, source

-- Method 1: local file in workspace root
pcall(function()
    if not code and isfile and isfile("XenoHub.lua") then
        code = readfile("XenoHub.lua")
        if code and #code > 100 then source = "local file" end
    end
end)
if not code then
    pcall(function()
        if isfile and isfile("workspace/XenoHub.lua") then
            code = readfile("workspace/XenoHub.lua")
            if code and #code > 100 then source = "workspace file" end
        end
    end)
end

-- Method 2: http_request (bypasses game:HttpGet cache)
if not code then
    local req = http_request or request
    if req then
        log("Method 2: http_request...")
        local ok, r = pcall(function() return req({Url = RAW_URL .. "?_=" .. math.random(1,999999), Method = "GET"}) end)
        if ok and r and r.StatusCode == 200 and r.Body and #r.Body > 100 then
            code = r.Body; source = "http_request"
            log("  SUCCESS (" .. #r.Body .. " bytes)")
        else
            log("  FAILED: " .. tostring(r and r.StatusCode))
        end
    end
end

-- Method 3: game:HttpGet (fallback)
if not code then
    log("Method 3: game:HttpGet...")
    local ok, c = pcall(function() return game:HttpGet(RAW_URL) end)
    if ok and c and #c > 100 then
        code = c; source = "HTTP"
        log("  SUCCESS (" .. #c .. " bytes)")
    else
        log("  FAILED: " .. tostring(c))
    end
end

if not code then
    log("ALL METHODS FAILED - no code retrieved")
    notif("Xeno Hub: Failed to download. Check XenoHub_Log.txt", 10)
    saveLog(false)
    return
end

-- Save to workspace for future runs (only if looks valid)
if code and #code > 100 and writefile and (code:find("XenoHub") or code:find("Rayfield")) then
    pcall(function() writefile("workspace/XenoHub.lua", code) end)
    log("Saved to workspace/XenoHub.lua for next time")
end

-- Execute
log("Executing via loadstring (source: " .. tostring(source) .. ", " .. tostring(#code) .. " bytes)...")
if getgenv then getgenv().XENO_HUB_LOADED = nil end

local fn, err = loadstring(code)
if not fn then
    log("loadstring FAILED: " .. tostring(err))
    log("First 150 chars: " .. tostring(err):sub(1, 150))
    notif("Syntax error. Check XenoHub_Log.txt", 10)
    saveLog(false)
    -- Don't save broken file
    pcall(function() delfile("workspace/XenoHub.lua") end)
    return
end
log("loadstring OK")

local ok, result = pcall(fn)
if not ok then
    log("Execution FAILED: " .. tostring(result))
    log("First 200 chars: " .. tostring(tostring(result):sub(1, 200)))
    notif("Hub crashed on load. Check XenoHub_Log.txt", 10)
    saveLog(false)
    pcall(function() delfile("workspace/XenoHub.lua") end)
    return
end
log("Execution OK, return type: " .. type(result))

if type(result) ~= "table" then
    if getgenv and getgenv().XENO_HUB_INSTANCE then
        result = getgenv().XENO_HUB_INSTANCE; log("Recovered from getgenv")
    else
        notif("Bad return type. Check XenoHub_Log.txt", 10)
        saveLog(false)
        return
    end
end

log("SUCCESS - Hub loaded from " .. tostring(source))
local cmdCount = 0; if result.Cmds then for _ in pairs(result.Cmds) do cmdCount = cmdCount + 1 end end
log("Commands: " .. cmdCount)
notif("Loaded! RightShift to toggle", 4)
getgenv().XENO_HUB_INSTANCE = result

local qot = (syn and syn.queue_on_teleport) or queue_on_teleport
if qot and writefile then
    qot([[
        local s = pcall(function()
            local c = readfile("workspace/XenoHub.lua")
            if c and #c > 100 then
                local f = loadstring(c)
                if f then pcall(f) end
            end
        end)
    ]])
end

saveLog(true)
print("=== Xeno Hub v" .. XENO_HUB_VERSION .. " ===")
return result