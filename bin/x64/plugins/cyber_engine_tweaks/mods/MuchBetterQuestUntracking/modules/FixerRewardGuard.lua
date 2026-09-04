local State    = require('modules/State')
local Settings = require('modules/Settings')
local Input    = require('modules/Input')

local FixerRewardGuard = {}

-- sync with data/fixer_reward_objectives.json
local FALLBACK_HASHES = {
    2732033893, 3830829301, 3674610257, 1811132885, 3938093005, 1577333988,
}

local hashesByString = {}
local hashCount = 0
local lastQueuedAt = 0
local QUEUE_DEBOUNCE = 0.1

local function ingestHashes(list)
    for _, h in ipairs(list) do
        local s = tostring(h)
        if #s > 0 and not hashesByString[s] then
            hashesByString[s] = true
            hashCount = hashCount + 1
        end
    end
end

local function loadHashes()
    hashesByString = {}
    hashCount = 0

    local jsonOk = false
    local f = io.open('data/fixer_reward_objectives.json', 'r')
    if f then
        local raw = f:read('*a')
        f:close()
        if raw and #raw > 0 then
            local ok, decoded = pcall(json.decode, raw)
            if ok and type(decoded) == 'table' and type(decoded.hashes) == 'table' then
                ingestHashes(decoded.hashes)
                jsonOk = hashCount > 0
            end
        end
    end

    if not jsonOk then
        spdlog.error('[MBQU] data/fixer_reward_objectives.json missing or invalid; using embedded fallback list.')
        ingestHashes(FALLBACK_HASHES)
    end
end

local function isInMenu()
    if not State.blackboardSystem then return false end
    local defs = Game.GetAllBlackboardDefs()
    if not defs or not defs.UI_System then return false end
    local bb = State.blackboardSystem:Get(defs.UI_System)
    if not bb then return false end
    return bb:GetBool(defs.UI_System.IsInMenu) == true
end

function FixerRewardGuard.Register()
    loadHashes()
    if hashCount == 0 then
        spdlog.error('[MBQU] FixerRewardGuard disabled: no hashes loaded (file missing AND fallback empty).')
        return
    end

    ObserveAfter('QuestTrackerGameController', 'OnTrackedEntryChanges', function(this, hash)
        if State.isDisabled then return end
        if not Settings.Get('preventFixerRewardAutotrack') then return end
        if (not hash) or hash == 0 then return end
        if isInMenu() then return end
        local now = os.clock()
        if now - lastQueuedAt < QUEUE_DEBOUNCE then return end

        local entryHash = hash
        if entryHash < 0 then entryHash = entryHash + 4294967296 end
        if not hashesByString[tostring(entryHash)] then return end

        local player = GetPlayer()
        if not player or player:GetSceneTier() < 1 then return end

        lastQueuedAt = now
        Input.Defer(function()
            if State.isDisabled then return end
            if State.journalManager then
                State.journalManager:UntrackEntry()
            end
        end)
    end)
end

return FixerRewardGuard
