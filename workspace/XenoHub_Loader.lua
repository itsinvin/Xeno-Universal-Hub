-- Xeno Hub Loader
-- Paste this into Xeno executor
-- Loads the main hub script with auto-update

local XENO_HUB_VERSION = "1.0"
local GITHUB_RAW = "https://raw.githubusercontent.com" -- Replace with your repo if hosting

-- Check if already loaded
if getgenv().XENO_HUB_LOADED then
    warn("[Xeno Hub] Already loaded! Closing...")
    return
end
getgenv().XENO_HUB_LOADED = true

-- Wait for game
repeat task.wait() until game:IsLoaded()

-- Try to load from workspace first, then fallback
local function loadHub()
    local success, result = pcall(function()
        -- Try loading from workspace/XenoHub.lua
        local path = "XenoHub.lua"
        if isfile and isfile(path) then
            return loadstring(readfile(path))()
        end
        return nil, "not found"
    end)
    
    if success and type(result) == "table" then
        print("[Xeno Hub v" .. Xeno_HUB_VERSION .. "] Loaded successfully from workspace!")
        return result
    end
    
    -- Fallback: load from raw (if hosted)
    pcall(function()
        local url = GITHUB_RAW .. "/main/XenoHub.lua"
        local req = syn and syn.request or http_request or request
        if req then
            local resp = req({Url = url, Method = "GET"})
            if resp and resp.StatusCode == 200 then
                loadstring(resp.Body)()
                print("[Xeno Hub] Loaded from remote!")
                return
            end
        end
        loadstring(game:HttpGet(url))()
    end)
end

local hub = loadHub()

-- Queue on teleport
if syn and syn.queue_on_teleport then
    syn.queue_on_teleport([[
        loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
        wait(1)
        loadstring(game:HttpGet("https://pastebin.com/raw/..."))() -- Your pastebin link
    ]])
elseif queue_on_teleport then
    queue_on_teleport("loadstring(game:HttpGet('https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source'))()")
end

print("=== Xeno Hub v" .. Xeno_HUB_VERSION .. " Loader ===")
print("Press RightShift to toggle menu")
print("Supports: MM2, Jailbreak, Arsenal, Blox Fruits, Doors, Pet Sim, Bedwars, TDS, Brookhaven")