local State        = require('modules/State')
local Settings     = require('modules/Settings')
local Localization = require('modules/Localization')
local Input        = require('modules/Input')

local SaveMetadata = {}

local CACHE_FILE         = 'untracked_saves.json'
local CACHE_TTL_SECONDS  = 126144000   -- 4 years
local CACHE_SIZE_LIMIT   = 3000

-- Polling parameters
local POLL_INTERVAL    = 0.25
local POLL_MAX_TRIES   = 240
local POLL_TIMEOUT_SEC = 30

local cache       = {}
local lastLoadMeta

local pollActive    = false
local pollBefore    = nil
local pollDeadline  = 0
local pollTries     = 0
local nextPollClock = 0

-- ---------------------------------------------------------------------------
-- IO

local function readJson(file)
    local f = io.open(file, 'r')
    if not f then return nil end
    local raw = f:read('*a')
    f:close()
    if not raw or #raw == 0 then return nil end
    local ok, decoded = pcall(json.decode, raw)
    if ok and type(decoded) == 'table' then return decoded end
    return nil
end

local function writeJson(file, tbl)
    local ok, encoded = pcall(json.encode, tbl)
    if not ok then return end
    local f = io.open(file, 'w')
    if not f then return end
    f:write(encoded)
    f:close()
end

local function loadCache()
    local data = readJson(CACHE_FILE)
    cache = (type(data) == 'table') and data or {}
end

local function saveCache() writeJson(CACHE_FILE, cache) end

-- ---------------------------------------------------------------------------
-- Metadata helpers

local function getLatestSaveMetadata()
    local handler = Game.GetSystemRequestsHandler()
    if not handler then return nil end
    local ok, meta = pcall(function() return handler:GetLatestSaveMetadata() end)
    if ok and meta then return meta end
    return nil
end

local function captureMetadataKey(meta)
    if not meta then return nil end
    return {
        recordCreationTime = os.time(),
        playTime           = meta.playTime,
        playthroughTime    = meta.playthroughTime,
        locationName       = meta.locationName,
        lifePath           = meta.lifePath,
        gameVersion        = meta.gameVersion,
    }
end

local function metaKeysEqual(a, b)
    if not a or not b then return false end
    if a.playTime        ~= b.playTime        then return false end
    if a.playthroughTime ~= b.playthroughTime then return false end
    if a.locationName    ~= b.locationName    then return false end
    if a.lifePath        ~= b.lifePath        then return false end
    if a.gameVersion     ~= b.gameVersion     then return false end
    return true
end

local function isTrackedQuestEmpty(meta)
    if not meta then return true end
    local s = meta.trackedQuest
    if s == nil then return true end
    if type(s) ~= 'string' then return false end
    return #s == 0
end

local function purge()
    if type(cache) ~= 'table' then return end
    local now    = os.time()
    local cutoff = now - CACHE_TTL_SECONDS
    local removed = false
    for i = #cache, 1, -1 do
        local rec = cache[i]
        if type(rec) ~= 'table' then
            table.remove(cache, i)
            removed = true
        elseif type(rec.recordCreationTime) == 'number' and rec.recordCreationTime < cutoff then
            table.remove(cache, i)
            removed = true
        end
    end
    while #cache > CACHE_SIZE_LIMIT do
        table.remove(cache, 1)
        removed = true
    end
    if removed then saveCache() end
end

local function rememberAsUntracked(meta)
    if not meta then return end
    local snap = captureMetadataKey(meta)
    if not snap then return end
    for i = #cache, 1, -1 do
        if metaKeysEqual(cache[i], snap) then return end
    end
    table.insert(cache, snap)
    if #cache > CACHE_SIZE_LIMIT then table.remove(cache, 1) end
    saveCache()
end

local function patchMetaIfMatched(info)
    if not Settings.Get('showSaveListUntrackedLabel') then return end
    if type(cache) ~= 'table' then return end
    for i = #cache, 1, -1 do
        if metaKeysEqual(cache[i], info) then
            info.trackedQuest = Localization.Get('saveList.untracked')
            return
        end
    end
end

-- ---------------------------------------------------------------------------
-- Polling

local function startSavePolling()
    pollBefore    = getLatestSaveMetadata()
    pollDeadline  = os.clock() + POLL_TIMEOUT_SEC
    pollTries     = 0
    nextPollClock = os.clock() + 0.01
    pollActive    = true
end

function SaveMetadata.Tick()
    if not pollActive then return end
    local now = os.clock()
    if now < nextPollClock then return end
    nextPollClock = now + POLL_INTERVAL
    pollTries = pollTries + 1

    if pollTries > POLL_MAX_TRIES or now > pollDeadline then
        pollActive = false
        return
    end

    local current = getLatestSaveMetadata()
    if not current then
        pollActive = false
        return
    end

    if not metaKeysEqual(pollBefore, current) then
        if isTrackedQuestEmpty(current) then
            rememberAsUntracked(current)
        end
        pollActive = false
    end
end

-- ---------------------------------------------------------------------------
-- Public

function SaveMetadata.Register()
    loadCache()
    purge()

    ObserveAfter('LoadGameMenuGameController', 'LoadGame', function(_, controller)
        if State.isDisabled then return end
        if not controller then return end
        local m = controller.metadata
        if not m then return end
        lastLoadMeta = {
            playTime         = m.playTime,
            playthroughTime  = m.playthroughTime,
            locationName     = m.locationName,
            lifePath         = m.lifePath,
            gameVersion      = m.gameVersion,
            trackedQuest     = m.trackedQuest,
        }
    end)

    ObserveAfter('PlayerPuppet', 'OnMakePlayerVisibleAfterSpawn', function(self)
        if State.isDisabled then return end
        if self:IsReplacer() then return end
        if not State.journalManager then return end
        if State.journalManager:GetTrackedEntry() then
            lastLoadMeta = nil
            return
        end
        if lastLoadMeta then
            local snapshot = lastLoadMeta
            lastLoadMeta = nil
            Input.Defer(function() rememberAsUntracked(snapshot) end)
        end
    end)

    Observe('gameuiInGameMenuGameController', 'OnSavingComplete', function()
        if State.isDisabled then return end
        if not State.journalManager then return end
        if State.journalManager:GetTrackedEntry() then return end
        startSavePolling()
    end)

    
    Observe('LoadGameMenuGameController', 'OnSaveMetadataReady', function(_, info)
        if State.isDisabled then return end
        patchMetaIfMatched(info)
    end)
    Observe('SaveGameMenuGameController', 'OnSaveMetadataReady', function(_, info)
        if State.isDisabled then return end
        patchMetaIfMatched(info)
    end)
    Observe('SingleplayerMenuGameController', 'OnSaveMetadataReady', function(_, info)
        if State.isDisabled then return end
        patchMetaIfMatched(info)
    end)
end

return SaveMetadata
