-- Xeno Cider LRC Lyric Chat
-- Auto-detects songs from Cider (Apple Music) and syncs LRC lyrics to Roblox chat
-- LRCLIB API: https://lrclib.net | Cider API: http://localhost:10767

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")

-- ===== CONFIGURATION =====
local CIDER_PORTS = {10767, 9000}
local CIDER_API_TOKEN = "snzu78ozqivt9veno3lnc1rw"
local POLL_INTERVAL = 2
local CIDER_HOST

-- ===== HTTP HELPERS =====
local function synRequest(url, headers)
    headers = headers or {}
    local funcs = {
        function() return syn.request({Url = url, Method = "GET", Headers = headers}) end,
        function() return http_request({Url = url, Method = "GET", Headers = headers}) end,
        function() return request({Url = url, Method = "GET", Headers = headers}) end,
    }
    for _, f in ipairs(funcs) do
        local ok, res = pcall(f)
        if ok and res then
            return res.status or res.StatusCode, res.Body
        end
    end
    local ok, body = pcall(HttpService.GetAsync, HttpService, url)
    if ok then return 200, body end
    ok, body = pcall(game.HttpGet, game, url)
    if ok then return 200, body end
    return nil, nil
end

-- Probe Cider ports and cache
for _, port in ipairs(CIDER_PORTS) do
    local host = "http://localhost:" .. port
    local status, _ = synRequest(host .. "/api/v1/playback/now-playing", CIDER_API_TOKEN ~= "" and {apitoken = CIDER_API_TOKEN} or {})
    if status then
        CIDER_HOST = host
        break
    end
end
CIDER_HOST = CIDER_HOST or "http://localhost:" .. CIDER_PORTS[1]

local function ciderGet(path)
    local headers = {}
    if CIDER_API_TOKEN ~= "" then
        headers["apitoken"] = CIDER_API_TOKEN
    end
    return synRequest(CIDER_HOST .. path, headers)
end

-- Check if Cider is running
local function isCiderActive()
    return getCiderNowPlaying() ~= nil
end

-- Get play state: /is-playing may return raw boolean or JSON-wrapped
local function isCiderPlaying()
    local status, body = ciderGet("/api/v1/playback/is-playing")
    if status then
        if body then
            local trimmed = body:match("^%s*(.-)%s*$")
            if trimmed == "true" then return true end
            if trimmed == "false" then return false end
            local ok, data = pcall(HttpService.JSONDecode, HttpService, body)
            if ok and type(data) == "table" then
                return data.value == true or data.isPlaying == true
            end
        end
        -- Fallback: derive from now-playing
        local np = getCiderNowPlaying()
        if np then
            local ct = np.currentPlaybackTime
            return ct ~= nil and ct >= 0 and np.name ~= nil
        end
        return true
    end
    return false
end

-- Try multiple possible field names for playback time (varies by Cider version)
local TIME_FIELDS = {"currentPlaybackTime", "currentPlaybackTimeInSeconds", "playbackTime", "elapsedTime", "currentTime"}
local NAME_FIELDS = {"name", "trackName", "title", "track_title"}
local ARTIST_FIELDS = {"artistName", "artist_name", "artist"}

local function extractPlaybackTime(info)
    for _, field in ipairs(TIME_FIELDS) do
        local val = info[field]
        if val ~= nil then return tonumber(val) or 0 end
    end
    return nil
end

local function extractField(info, fields)
    for _, field in ipairs(fields) do
        local val = info[field]
        if val ~= nil then return val end
    end
    return nil
end

-- Normalize now-playing response to a consistent format
local function normalizeNowPlaying(data)
    if not data then return nil end

    -- Apple Music API format: { data = [{ id = "...", attributes = {...} }], currentPlaybackTime = ... }
    if data.data and type(data.data) == "table" and data.data[1] then
        local item = data.data[1]
        local attrs = item.attributes or {}
        local info = {}
        for k, v in pairs(attrs) do info[k] = v end
        info.currentPlaybackTime = extractPlaybackTime(data) or extractPlaybackTime(attrs) or 0
        info.id = item.id or info.id
        info.name = extractField(attrs, NAME_FIELDS) or info.name
        info.artistName = extractField(attrs, ARTIST_FIELDS) or info.artistName
        return info
    end

    -- Flat format: { name = "...", artistName = "...", currentPlaybackTime = ... }
    local info = {}
    for k, v in pairs(data) do info[k] = v end
    info.currentPlaybackTime = extractPlaybackTime(data) or 0
    info.name = extractField(data, NAME_FIELDS) or info.name
    info.artistName = extractField(data, ARTIST_FIELDS) or info.artistName
    return info
end

-- Fetch now-playing data from Cider
local function getCiderNowPlaying()
    local status, body = ciderGet("/api/v1/playback/now-playing")
    if status and body and body ~= "" then
        local ok, data = pcall(HttpService.JSONDecode, HttpService, body)
        if ok and data then
            return normalizeNowPlaying(data)
        end
    end
    return nil
end

-- Compatibility wrapper for LRCLIB functions
local function httpGet(url)
    local _, body = synRequest(url)
    return body
end

-- ===== CHAT =====
local function chat(msg)
    if not msg or msg == "" then return end
    local sayReq = ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents")
    if sayReq then
        sayReq = sayReq:FindFirstChild("SayMessageRequest")
        if sayReq then
            sayReq:FireServer(msg, "All")
            return
        end
    end
    pcall(function()
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):Chat(msg)
    end)
end

-- clearChat removed — empty messages don't clear Roblox chat

-- ===== LRC PARSER =====
local function parseLRC(lrcText)
    local lyrics = {}
    for line in lrcText:gmatch("[^\r\n]+") do
        local m, s, text = line:match("^%[(%d+):(%d+%.?%d*)%]%s*(.-)$")
        if m and s and text ~= "" then
            local ts = tonumber(m) * 60 + tonumber(s)
            table.insert(lyrics, {time = ts, text = text})
        end
    end
    table.sort(lyrics, function(a, b) return a.time < b.time end)
    return lyrics
end

-- ===== LRCLIB API =====
local function searchSong(query)
    local url = "https://lrclib.net/api/search?q=" .. HttpService:UrlEncode(query)
    local response = httpGet(url)
    if response then
        local ok, data = pcall(function() return HttpService:JSONDecode(response) end)
        if ok and type(data) == "table" and #data > 0 then
            return data
        end
    end
    return nil
end

local function getSongLyrics(id)
    local url = "https://lrclib.net/api/get/" .. id
    local response = httpGet(url)
    if response then
        local ok, data = pcall(function() return HttpService:JSONDecode(response) end)
        if ok and data then
            return data
        end
    end
    return nil
end

local function getLyricsByTrack(artist, track)
    local url = "https://lrclib.net/api/get?artist_name=" .. HttpService:UrlEncode(artist) .. "&track_name=" .. HttpService:UrlEncode(track)
    local response = httpGet(url)
    if response then
        local ok, data = pcall(function() return HttpService:JSONDecode(response) end)
        if ok and data then
            return data
        end
    end
    return nil
end

-- (Cider API functions defined above in HTTP HELPERS section)

-- ===== PLAYBACK ENGINE =====
local playbackThread = nil
local isPlaybackActive = false

local function stopPlayback()
    isPlaybackActive = false
    playbackThread = nil
end

local function startPlayback(lyrics, startTime)
    stopPlayback()
    if #lyrics == 0 then return end

    isPlaybackActive = true
    playbackThread = coroutine.create(function()
        local offset = startTime or 0
        local began = tick()

        for _, entry in ipairs(lyrics) do
            if not isPlaybackActive then break end

            local waitTime = (entry.time - offset) - (tick() - began)
            if waitTime > 0 then
                task.wait(waitTime)
            end

            if isPlaybackActive then
                chat(entry.text)
            end
        end

        isPlaybackActive = false
    end)
    coroutine.resume(playbackThread)
end

-- ===== UI =====
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "Cider_LRC_Lyrics"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 450, 0, 450)
frame.Position = UDim2.new(0.5, -225, 0.5, -225)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 8)
uiCorner.Parent = frame

-- Title bar
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 35)
title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
title.BackgroundTransparency = 0.3
title.BorderSizePixel = 0
title.Text = "Cider LRC Lyric Chat"
title.TextColor3 = Color3.fromRGB(200, 200, 200)
title.TextSize = 18
title.Font = Enum.Font.GothamBold

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = title

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -35, 0, 2)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
closeBtn.BorderSizePixel = 0
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 16
closeBtn.Font = Enum.Font.GothamBold

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

-- Cider status indicator
local ciderStatus = Instance.new("TextLabel")
ciderStatus.Size = UDim2.new(1, -20, 0, 22)
ciderStatus.Position = UDim2.new(0, 10, 0, 40)
ciderStatus.BackgroundTransparency = 1
ciderStatus.Text = "Cider: Disconnected"
ciderStatus.TextColor3 = Color3.fromRGB(200, 60, 60)
ciderStatus.TextSize = 13
ciderStatus.Font = Enum.Font.GothamBold
ciderStatus.TextXAlignment = Enum.TextXAlignment.Left

-- Now playing info
local nowPlayingLabel = Instance.new("TextLabel")
nowPlayingLabel.Name = "NowPlaying"
nowPlayingLabel.Size = UDim2.new(1, -20, 0, 36)
nowPlayingLabel.Position = UDim2.new(0, 10, 0, 64)
nowPlayingLabel.BackgroundTransparency = 1
nowPlayingLabel.Text = "Waiting for song..."
nowPlayingLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
nowPlayingLabel.TextSize = 13
nowPlayingLabel.Font = Enum.Font.Gotham
nowPlayingLabel.TextXAlignment = Enum.TextXAlignment.Left
nowPlayingLabel.TextWrapped = true
nowPlayingLabel.TextYAlignment = Enum.TextYAlignment.Top

-- Search box
local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -20, 0, 32)
searchBox.Position = UDim2.new(0, 10, 0, 108)
searchBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
searchBox.BorderSizePixel = 0
searchBox.PlaceholderText = "Manual search (e.g. Artist - Song)"
searchBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
searchBox.Text = ""
searchBox.TextColor3 = Color3.fromRGB(220, 220, 220)
searchBox.TextSize = 13
searchBox.Font = Enum.Font.Gotham
searchBox.ClearTextOnFocus = false

local searchBoxCorner = Instance.new("UICorner")
searchBoxCorner.CornerRadius = UDim.new(0, 6)
searchBoxCorner.Parent = searchBox

local searchBtn = Instance.new("TextButton")
searchBtn.Size = UDim2.new(0, 70, 0, 32)
searchBtn.Position = UDim2.new(1, -80, 0, 108)
searchBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 210)
searchBtn.BorderSizePixel = 0
searchBtn.Text = "Search"
searchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
searchBtn.TextSize = 13
searchBtn.Font = Enum.Font.GothamBold

local searchBtnCorner = Instance.new("UICorner")
searchBtnCorner.CornerRadius = UDim.new(0, 6)
searchBtnCorner.Parent = searchBtn

-- Results list
local resultsFrame = Instance.new("ScrollingFrame")
resultsFrame.Size = UDim2.new(1, -20, 0, 110)
resultsFrame.Position = UDim2.new(0, 10, 0, 148)
resultsFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
resultsFrame.BorderSizePixel = 0
resultsFrame.ScrollBarThickness = 4
resultsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
resultsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

local resultsCorner = Instance.new("UICorner")
resultsCorner.CornerRadius = UDim.new(0, 6)
resultsCorner.Parent = resultsFrame

-- Status
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 22)
statusLabel.Position = UDim2.new(0, 10, 0, 265)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Ready"
statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
statusLabel.TextSize = 12
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Controls row
local autoToggle = Instance.new("TextButton")
autoToggle.Name = "AutoToggle"
autoToggle.Size = UDim2.new(0.5, -6, 0, 32)
autoToggle.Position = UDim2.new(0, 10, 0, 290)
autoToggle.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
autoToggle.BorderSizePixel = 0
autoToggle.Text = "Auto: ON"
autoToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
autoToggle.TextSize = 14
autoToggle.Font = Enum.Font.GothamBold

local autoCorner = Instance.new("UICorner")
autoCorner.CornerRadius = UDim.new(0, 6)
autoCorner.Parent = autoToggle

local manualSyncBtn = Instance.new("TextButton")
manualSyncBtn.Size = UDim2.new(0.5, -6, 0, 32)
manualSyncBtn.Position = UDim2.new(0.5, -4, 0, 290)
manualSyncBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 210)
manualSyncBtn.BorderSizePixel = 0
manualSyncBtn.Text = "Sync Now"
manualSyncBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
manualSyncBtn.TextSize = 14
manualSyncBtn.Font = Enum.Font.GothamBold

local manualCorner = Instance.new("UICorner")
manualCorner.CornerRadius = UDim.new(0, 6)
manualCorner.Parent = manualSyncBtn

local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.new(0.5, -6, 0, 32)
stopBtn.Position = UDim2.new(0, 10, 0, 328)
stopBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
stopBtn.BorderSizePixel = 0
stopBtn.Text = "Stop"
stopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
stopBtn.TextSize = 14
stopBtn.Font = Enum.Font.GothamBold

local stopCorner = Instance.new("UICorner")
stopCorner.CornerRadius = UDim.new(0, 6)
stopCorner.Parent = stopBtn

local dumpBtn = Instance.new("TextButton")
dumpBtn.Size = UDim2.new(0.5, -6, 0, 32)
dumpBtn.Position = UDim2.new(0.5, -4, 0, 328)
dumpBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
dumpBtn.BorderSizePixel = 0
dumpBtn.Text = "Dump All"
dumpBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
dumpBtn.TextSize = 14
dumpBtn.Font = Enum.Font.GothamBold

local dumpCorner = Instance.new("UICorner")
dumpCorner.CornerRadius = UDim.new(0, 6)
dumpCorner.Parent = dumpBtn

-- Current song display
local selectedLabel = Instance.new("TextLabel")
selectedLabel.Size = UDim2.new(1, -20, 0, 50)
selectedLabel.Position = UDim2.new(0, 10, 0, 370)
selectedLabel.BackgroundTransparency = 1
selectedLabel.Text = "No song loaded"
selectedLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
selectedLabel.TextSize = 12
selectedLabel.Font = Enum.Font.Gotham
selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
selectedLabel.TextWrapped = true
selectedLabel.TextYAlignment = Enum.TextYAlignment.Top

-- Auto-play indicator dot
local autoDot = Instance.new("Frame")
autoDot.Name = "AutoDot"
autoDot.Size = UDim2.new(0, 10, 0, 10)
autoDot.Position = UDim2.new(0, 12, 0, 428)
autoDot.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
autoDot.BorderSizePixel = 0

local dotCorner = Instance.new("UICorner")
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = autoDot

local autoLabel = Instance.new("TextLabel")
autoLabel.Size = UDim2.new(1, -30, 0, 14)
autoLabel.Position = UDim2.new(0, 28, 0, 427)
autoLabel.BackgroundTransparency = 1
autoLabel.Text = "Auto-sync active — waiting for Cider..."
autoLabel.TextColor3 = Color3.fromRGB(80, 180, 80)
autoLabel.TextSize = 11
autoLabel.Font = Enum.Font.Gotham
autoLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Parent all
title.Parent = frame
closeBtn.Parent = frame
ciderStatus.Parent = frame
nowPlayingLabel.Parent = frame
searchBox.Parent = frame
searchBtn.Parent = frame
resultsFrame.Parent = frame
statusLabel.Parent = frame
autoToggle.Parent = frame
manualSyncBtn.Parent = frame
stopBtn.Parent = frame
dumpBtn.Parent = frame
selectedLabel.Parent = frame
autoDot.Parent = frame
autoLabel.Parent = frame
frame.Parent = screenGui
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- ===== UI LOGIC =====
-- Dragging
local dragging = false
local dragStart, frameStart

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        frameStart = frame.Position
    end
end)
title.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(frameStart.X.Scale, frameStart.X.Offset + delta.X, frameStart.Y.Scale, frameStart.Y.Offset + delta.Y)
    end
end)
title.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    stopPlayback()
    screenGui:Destroy()
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Escape then
        stopPlayback()
        screenGui:Destroy()
    end
end)

-- State
local currentResults = {}
local selectedSong = nil
local currentLyrics = {}
local autoMode = true
local lastSongId = nil

local function clearResults()
    for _, child in ipairs(resultsFrame:GetChildren()) do
        if child:IsA("TextButton") then child:Destroy() end
    end
    currentResults = {}
end

local function setCiderStatus(connected, playing, songName)
    if connected then
        if playing then
            ciderStatus.Text = "Cider: Playing"
            ciderStatus.TextColor3 = Color3.fromRGB(50, 220, 80)
        else
            ciderStatus.Text = "Cider: Paused"
            ciderStatus.TextColor3 = Color3.fromRGB(220, 200, 50)
        end
    else
        ciderStatus.Text = "Cider: Disconnected"
        ciderStatus.TextColor3 = Color3.fromRGB(200, 60, 60)
    end
    nowPlayingLabel.Text = songName or "Waiting for song..."
    autoDot.BackgroundColor3 = autoMode and Color3.fromRGB(50, 220, 80) or Color3.fromRGB(80, 80, 80)
    autoLabel.Text = autoMode and "Auto-sync active — " .. (connected and "watching Cider" or "waiting for Cider...") or "Auto-sync disabled"
end

local function showResults(results)
    clearResults()
    currentResults = results
    for i, song in ipairs(results) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 28)
        btn.Position = UDim2.new(0, 0, 0, (i - 1) * 30)
        btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        btn.BackgroundTransparency = 0.5
        btn.BorderSizePixel = 0
        btn.Text = (song.artistName or "Unknown") .. " - " .. (song.trackName or "Unknown")
        btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        btn.TextSize = 12
        btn.Font = Enum.Font.Gotham
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.TextTruncate = Enum.TextTruncate.AtEnd

        btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60) end)
        btn.MouseLeave:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40) end)

        btn.MouseButton1Click:Connect(function()
            selectedSong = song
            selectedLabel.Text = "Selected: " .. (song.artistName or "?") .. " - " .. (song.trackName or "?")
            statusLabel.Text = "Fetching lyrics..."

            local data = getSongLyrics(song.id)
            if data and data.syncedLyrics then
                currentLyrics = parseLRC(data.syncedLyrics)
                statusLabel.Text = "Lyrics loaded! " .. #currentLyrics .. " timed lines"
            elseif data and data.plainLyrics then
                currentLyrics = {}
                for line in data.plainLyrics:gmatch("[^\r\n]+") do
                    table.insert(currentLyrics, {time = 0, text = line})
                end
                statusLabel.Text = "Plain lyrics loaded (" .. #currentLyrics .. " lines, no timestamps)"
            else
                statusLabel.Text = "No lyrics found"
                currentLyrics = {}
            end
        end)

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = btn
        btn.Parent = resultsFrame
    end
end

searchBtn.MouseButton1Click:Connect(function()
    local query = searchBox.Text:match("^%s*(.-)%s*$")
    if query == "" then return end
    statusLabel.Text = "Searching..."
    clearResults()
    local results = searchSong(query)
    if results then
        statusLabel.Text = "Found " .. #results .. " result(s)"
        showResults(results)
    else
        statusLabel.Text = "No results or API error"
    end
end)

searchBox.FocusLost:Connect(function(enter)
    if enter then searchBtn.MouseButton1Click:Fire() end
end)

-- Manual sync using Cider's current time
manualSyncBtn.MouseButton1Click:Connect(function()
    if #currentLyrics == 0 then
        statusLabel.Text = "No lyrics loaded"
        return
    end
    local np = getCiderNowPlaying()
    local time = np and np.currentPlaybackTime or 0
    statusLabel.Text = "Manual sync at " .. string.format("%.1f", time) .. "s"
    startPlayback(currentLyrics, time)
end)

stopBtn.MouseButton1Click:Connect(function()
    stopPlayback()
    statusLabel.Text = "Stopped"
end)

dumpBtn.MouseButton1Click:Connect(function()
    if #currentLyrics == 0 then statusLabel.Text = "No lyrics" return end
    stopPlayback()
    for _, entry in ipairs(currentLyrics) do
        chat(entry.text)
        task.wait(0.1)
    end
    statusLabel.Text = "Dumped " .. #currentLyrics .. " lines"
end)

autoToggle.MouseButton1Click:Connect(function()
    autoMode = not autoMode
    autoToggle.Text = autoMode and "Auto: ON" or "Auto: OFF"
    autoToggle.BackgroundColor3 = autoMode and Color3.fromRGB(50, 180, 80) or Color3.fromRGB(80, 80, 80)
    if not autoMode then stopPlayback() end
    setCiderStatus(isCiderActive(), isCiderPlaying(), nowPlayingLabel.Text)
end)

-- ===== CIDER POLLING LOOP =====
coroutine.wrap(function()
    local lastSyncTime = 0

    while screenGui and screenGui.Parent do
        local np = getCiderNowPlaying()
        local connected = np ~= nil
        local playing = connected and (np.currentPlaybackTime or -1) >= 0 and np.name ~= nil

        if connected then
            local displayText = (np.artistName or np.artist_name or "?") .. " — " .. (np.name or np.trackName or "?")
            setCiderStatus(connected, playing, displayText)
        else
            setCiderStatus(false, false, "Cider not detected — start Cider or search manually")
        end

        if autoMode and connected and playing and np then
            local track = np.name or np.trackName or ""
            local artist = np.artistName or np.artist_name or ""
            local songKey = artist .. "::" .. track

            if songKey ~= lastSongId then
                lastSongId = songKey
                lastSyncTime = tick()
                selectedLabel.Text = "Auto-detected: " .. artist .. " - " .. track

                local data = getLyricsByTrack(artist, track)
                if not data or not data.syncedLyrics then
                    local results = searchSong(artist .. " " .. track)
                    if results and #results > 0 then
                        data = getSongLyrics(results[1].id)
                    end
                end

                if data and data.syncedLyrics then
                    currentLyrics = parseLRC(data.syncedLyrics)
                    statusLabel.Text = "Auto-loaded " .. #currentLyrics .. " timed lines"
                    if #currentLyrics > 0 then
                        local ct = np.currentPlaybackTime or 0
                        task.wait(0.3)
                        startPlayback(currentLyrics, ct)
                    end
                elseif data and data.plainLyrics then
                    currentLyrics = {}
                    for line in data.plainLyrics:gmatch("[^\r\n]+") do
                        table.insert(currentLyrics, {time = 0, text = line})
                    end
                    statusLabel.Text = "Auto-loaded plain lyrics (" .. #currentLyrics .. " lines)"
                else
                    statusLabel.Text = "No lyrics found for this song"
                    currentLyrics = {}
                end
            else
                local ct = np.currentPlaybackTime or 0
                if not isPlaybackActive and #currentLyrics > 0 and ct > 1 and ct < tonumber((currentLyrics[#currentLyrics] or {}).time or 99999) then
                    local timeSinceSync = tick() - lastSyncTime
                    if timeSinceSync > 10 then
                        lastSyncTime = tick()
                        startPlayback(currentLyrics, ct)
                    end
                end
            end
        elseif autoMode and (not connected or not playing) then
            if isPlaybackActive then
                stopPlayback()
                statusLabel.Text = "Stopped (Cider paused/changed)"
            end
            lastSongId = nil
            lastSyncTime = 0
        end

        task.wait(POLL_INTERVAL)
    end
end)()

statusLabel.Text = "Cider auto-sync enabled"
print("=== Cider LRC Lyric Chat Loaded ===")
print("Auto-detecting songs from Cider (localhost:10767)")
print("If Cider has API auth enabled, set CIDER_API_TOKEN at line 10")
