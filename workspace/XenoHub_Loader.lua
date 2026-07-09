-- Xeno Hub Loader v2.0
-- Paste this into Xeno executor

local XENO_HUB_VERSION = "2.0"
local RAW_URL = "https://raw.githubusercontent.com/itsinvin/Xeno-Universal-Hub/master/workspace/XenoHub.lua"

-- Roblox notification helper (visible in-game even if hub fails to load)
local function robloxNotif(title, text, duration)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 5
        })
    end)
end

-- IMPORTANT: Do NOT set XENO_HUB_LOADED here — the hub script sets it itself.
-- If we set it here, the hub's own guard (line 18) will trigger and it'll do nothing.

-- Wait for game
repeat task.wait() until game:IsLoaded()

local function tryLoad(source, code)
    local fn, err = loadstring(code)
    if not fn then
        local msg = "loadstring failed (" .. source .. "): " .. tostring(err)
        warn("[Xeno Hub] " .. msg)
        robloxNotif("Xeno Hub Error", msg, 8)
        return nil
    end
    local ok, result = pcall(fn)
    if not ok then
        local msg = "execution failed (" .. source .. "): " .. tostring(result)
        warn("[Xeno Hub] " .. msg)
        robloxNotif("Xeno Hub Error", msg, 8)
        return nil
    end
    if type(result) ~= "table" then
        local msg = "bad return type (" .. source .. "): " .. type(result)
        warn("[Xeno Hub] " .. msg)
        robloxNotif("Xeno Hub Error", msg, 8)
        return nil
    end
    robloxNotif("Xeno Hub", "Loaded from " .. source, 3)
    return result
end

local hub

-- 1) Try local file
if isfile then
    local ok, err = pcall(function()
        local code = readfile("XenoHub.lua")
        if code then
            hub = tryLoad("local file", code)
        else
            robloxNotif("Xeno Hub", "Local file empty", 5)
        end
    end)
    if not ok then
        local msg = "readfile error: " .. tostring(err)
        warn("[Xeno Hub] " .. msg)
        robloxNotif("Xeno Hub Error", msg, 8)
    end
end

-- 2) Try HTTP
if not hub then
    robloxNotif("Xeno Hub", "Trying HTTP download...", 3)
    local ok, err = pcall(function()
        local code = game:HttpGet(RAW_URL)
        if code and #code > 100 then
            hub = tryLoad("HTTP", code)
        else
            local msg = "HTTP response too short (" .. tostring(#code or 0) .. " bytes)"
            warn("[Xeno Hub] " .. msg)
            robloxNotif("Xeno Hub Error", msg, 8)
        end
    end)
    if not ok then
        local msg = "HTTP error: " .. tostring(err)
        warn("[Xeno Hub] " .. msg)
        robloxNotif("Xeno Hub Error", msg, 8)
    end
end

-- 3) Try syn.request / http_request fallback
if not hub then
    local req = syn and syn.request or http_request or request
    if req then
        robloxNotif("Xeno Hub", "Trying request fallback...", 3)
        local ok, err = pcall(function()
            local resp = req({Url = RAW_URL, Method = "GET"})
            if resp and resp.StatusCode == 200 and resp.Body then
                hub = tryLoad("request", resp.Body)
            else
                local msg = "request returned status " .. tostring(resp and resp.StatusCode)
                warn("[Xeno Hub] " .. msg)
                robloxNotif("Xeno Hub Error", msg, 8)
            end
        end)
        if not ok then
            local msg = "request error: " .. tostring(err)
            warn("[Xeno Hub] " .. msg)
            robloxNotif("Xeno Hub Error", msg, 8)
        end
    end
end

if hub then
    robloxNotif("Xeno Hub", "v" .. XENO_HUB_VERSION .. " loaded! RightShift to toggle", 5)
    print("[Xeno Hub v" .. XENO_HUB_VERSION .. "] Loaded successfully!")
    getgenv().XENO_HUB_INSTANCE = hub

    -- Queue on teleport
    local qot = syn and syn.queue_on_teleport or queue_on_teleport
    if qot then
        qot('loadstring(game:HttpGet("' .. RAW_URL .. '"))()')
    end
else
    robloxNotif("Xeno Hub", "ALL LOAD METHODS FAILED! Try loading XenoHub.lua directly", 10)
    warn("[Xeno Hub] ALL LOAD METHODS FAILED!")
    warn("[Xeno Hub] Try loading XenoHub.lua directly instead of using the loader.")
end

print("=== Xeno Hub v" .. XENO_HUB_VERSION .. " Loader ===")
print("Press RightShift to toggle menu")