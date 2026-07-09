-- Xeno Hub Loader v2.4
-- Paste this into Xeno executor
-- Re-uses cached hub if already loaded, auto-logs to XenoHub_Log.txt

local XENO_HUB_VERSION = "2.0"
local RAW_URL = "https://raw.githubusercontent.com/itsinvin/Xeno-Universal-Hub/master/workspace/XenoHub.lua"

-- === LOG SYSTEM ===
local logLines = {}
local function log(...)
    local msg = table.concat({...}, " ")
    local ts = os.date("%H:%M:%S") or tick()
    local line = "[" .. tostring(ts) .. "] " .. msg
    table.insert(logLines, line)
    warn(msg)
end

local function saveLog(success)
    local content = table.concat(logLines, "\n")
    local status = success and "SUCCESS" or "FAILED"
    content = "=== Xeno Hub Loader v" .. XENO_HUB_VERSION .. " - " .. status .. " ===\n" ..
              "Timestamp: " .. (os.date("%Y-%m-%d %H:%M:%S") or "unknown") .. "\n" ..
              "Game: " .. tostring(game.PlaceId) .. "\n" ..
              "Executor: Xeno v1.3.55\n" ..
              "URL: " .. RAW_URL .. "\n\n" .. content
    pcall(function() writefile("XenoHub_Log.txt", content) end)
end

local function notif(t, d)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "Xeno Hub",
            Text = t,
            Duration = d or 8
        })
    end)
end

-- Check if already loaded (handles re-execution)
if getgenv and getgenv().XENO_HUB_LOADED and getgenv().XENO_HUB_INSTANCE then
    print("=== Xeno Hub v" .. XENO_HUB_VERSION .. " (reloaded from cache) ===")
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

-- Try every load method
local code, source

-- Method 1: isfile XenoHub.lua (executor root)
pcall(function()
    if not code and isfile then
        log("Method 1: checking isfile('XenoHub.lua')...")
        local exists = isfile("XenoHub.lua")
        log("  exists: " .. tostring(exists))
        if exists then
            code = readfile("XenoHub.lua")
            if code then
                log("  read " .. tostring(#code) .. " bytes")
                if #code > 100 then source = "local file" end
            end
        end
    end
end)

-- Method 2: isfile workspace/XenoHub.lua
pcall(function()
    if not code and isfile then
        log("Method 2: checking isfile('workspace/XenoHub.lua')...")
        local exists = isfile("workspace/XenoHub.lua")
        log("  exists: " .. tostring(exists))
        if exists then
            code = readfile("workspace/XenoHub.lua")
            if code then
                log("  read " .. tostring(#code) .. " bytes")
                if #code > 100 then source = "workspace file" end
            end
        end
    end
end)

-- Method 3: game:HttpGet
if not code then
    log("Method 3: game:HttpGet...")
    local ok, c = pcall(function()
        local t = game:HttpGet(RAW_URL)
        log("  response length: " .. tostring(#(t or "")))
        return t
    end)
    if ok and c and #c > 100 then
        code = c; source = "HTTP"
        log("  Method 3 SUCCESS")
    elseif ok then
        log("  Method 3 FAILED: response too short or empty")
    else
        log("  Method 3 ERROR: " .. tostring(c))
    end
end

-- Method 4: syn.request / http_request
if not code then
    local req = syn and syn.request or http_request or request
    log("Method 4: request fallback... req=" .. tostring(req))
    if req then
        local ok, r = pcall(function()
            return req({Url = RAW_URL, Method = "GET"})
        end)
        if ok and r then
            log("  status: " .. tostring(r.StatusCode) .. ", body length: " .. tostring(#(r.Body or "")))
            if r.StatusCode == 200 and r.Body and #r.Body > 100 then
                code = r.Body; source = "request"
                log("  Method 4 SUCCESS")
            elseif r.StatusCode ~= 200 then
                log("  Method 4 FAILED: HTTP " .. tostring(r.StatusCode))
            else
                log("  Method 4 FAILED: body too short")
            end
        else
            log("  Method 4 ERROR: " .. tostring(r))
        end
    else
        log("  Method 4 SKIPPED: no HTTP request function available")
    end
end

if not code then
    log("ALL METHODS FAILED - no code retrieved")
    notif("Xeno Hub: All methods failed. Check XenoHub_Log.txt", 10)
    saveLog(false)
    return
end

-- Execute
log("Executing via loadstring (source: " .. tostring(source) .. ", " .. tostring(#code) .. " bytes)...")

-- Clear guard so hub always runs and returns the table
if getgenv then getgenv().XENO_HUB_LOADED = nil end

local fn, err = loadstring(code)
if not fn then
    log("loadstring FAILED: " .. tostring(err))
    notif("loadstring failed. Check XenoHub_Log.txt", 10)
    saveLog(false)
    return
end
log("loadstring OK")

local ok, result = pcall(fn)
if not ok then
    log("Execution FAILED: " .. tostring(result))
    log("First 200 chars of error: " .. tostring(tostring(result):sub(1, 200)))
    notif("Hub crashed on load. Check XenoHub_Log.txt", 10)
    saveLog(false)
    return
end
log("Execution OK, return type: " .. type(result))

if type(result) ~= "table" then
    log("Bad return type (expected table, got " .. type(result) .. ")")
    -- Last resort: try to grab it from getgenv if hub set it anyway
    if getgenv and getgenv().XENO_HUB_INSTANCE then
        result = getgenv().XENO_HUB_INSTANCE
        log("Recovered XENO_HUB_INSTANCE from getgenv")
    else
        notif("Bad return type. Check XenoHub_Log.txt", 10)
        saveLog(false)
        return
    end
end

log("SUCCESS - Hub loaded from " .. tostring(source))
local cmdCount = 0; if result.Cmds then for _ in pairs(result.Cmds) do cmdCount = cmdCount + 1 end end
log("Commands registered: " .. cmdCount)
notif("Loaded! RightShift to toggle", 4)
getgenv().XENO_HUB_INSTANCE = result

-- Queue on teleport
local qot = syn and syn.queue_on_teleport or queue_on_teleport
if qot then
    log("Setting queue_on_teleport")
    qot('loadstring(game:HttpGet("' .. RAW_URL .. '"))()')
end

saveLog(true)
print("=== Xeno Hub Loader v" .. XENO_HUB_VERSION .. " ===")
print("Log saved to XenoHub_Log.txt")

return result