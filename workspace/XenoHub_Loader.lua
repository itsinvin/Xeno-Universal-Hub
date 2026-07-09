-- Xeno Hub Loader v2.0
-- Paste this into Xeno executor
-- Tries local file first, then HTTP fallback

local XENO_HUB_VERSION = "2.0"
local RAW_URL = "https://raw.githubusercontent.com/itsinvin/Xeno-Universal-Hub/master/workspace/XenoHub.lua"

-- Guard
if getgenv().XENO_HUB_LOADED then
    warn("[Xeno Hub] Already loaded!")
    return
end
getgenv().XENO_HUB_LOADED = true

-- Wait for game
repeat task.wait() until game:IsLoaded()

local function tryLoad(source, code)
    local fn, err = loadstring(code)
    if not fn then
        warn("[Xeno Hub] loadstring failed (" .. source .. "): " .. tostring(err))
        return nil
    end
    local ok, result = pcall(fn)
    if not ok then
        warn("[Xeno Hub] execution failed (" .. source .. "): " .. tostring(result))
        return nil
    end
    if type(result) ~= "table" then
        warn("[Xeno Hub] bad return type (" .. source .. "): " .. type(result))
        return nil
    end
    return result
end

local hub

-- 1) Try local file
if isfile then
    local ok, err = pcall(function()
        local code = readfile("XenoHub.lua")
        if code then
            hub = tryLoad("local file", code)
        end
    end)
    if not ok then warn("[Xeno Hub] readfile error: " .. tostring(err)) end
end

-- 2) Try HTTP
if not hub then
    local ok, err = pcall(function()
        local code = game:HttpGet(RAW_URL)
        if code and #code > 100 then
            hub = tryLoad("http", code)
        else
            warn("[Xeno Hub] HTTP response too short (" .. tostring(#code or 0) .. " bytes)")
        end
    end)
    if not ok then warn("[Xeno Hub] HTTP error: " .. tostring(err)) end
end

-- 3) Try syn.request fallback
if not hub then
    local req = syn and syn.request or http_request or request
    if req then
        local ok, err = pcall(function()
            local resp = req({Url = RAW_URL, Method = "GET"})
            if resp and resp.StatusCode == 200 and resp.Body then
                hub = tryLoad("syn.request", resp.Body)
            else
                warn("[Xeno Hub] request returned status " .. tostring(resp and resp.StatusCode))
            end
        end)
        if not ok then warn("[Xeno Hub] request error: " .. tostring(err)) end
    end
end

if hub then
    print("[Xeno Hub v" .. XENO_HUB_VERSION .. "] Loaded successfully!")
    getgenv().XENO_HUB_INSTANCE = hub
else
    warn("[Xeno Hub] ALL LOAD METHODS FAILED!")
    warn("[Xeno Hub] Try loading XenoHub.lua directly instead of using the loader.")
end

-- Queue on teleport
local qot = syn and syn.queue_on_teleport or queue_on_teleport
if qot and hub then
    qot('loadstring(game:HttpGet("' .. RAW_URL .. '"))()')
end

print("=== Xeno Hub v" .. XENO_HUB_VERSION .. " Loader ===")
print("Press RightShift to toggle menu")
print("Supports: MM2, Jailbreak, Arsenal, Blox Fruits, Doors, Pet Sim, Bedwars, TDS, Brookhaven")
