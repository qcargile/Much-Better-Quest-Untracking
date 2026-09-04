local State    = require('modules/State')
local Settings = require('modules/Settings')
local Audio    = require('modules/Audio')

local Tracking = {}

-- Persistent fact names
local FACT_LAST_TRACKED_OBJECTIVE = 'mbqu_last_tracked_objective_hash'
local FACT_LAST_TRACKED_POI       = 'mbqu_last_tracked_poi_hash'
local FACT_PREFIX_USER_UNTRACKED  = 'mbqu_user_untracked_'

-- Toggle re-entrancy guard
local lastToggleClock = 0
local TOGGLE_DEBOUNCE = 0.2

-- ---------------------------------------------------------------------------
-- Helpers

local function normalizeHash(hash)
    if not hash then return 0 end
    if hash < 0 then hash = hash + 4294967296 end
    return hash
end

local function getFirstObjectiveOfQuest(controller, quest)
    if not State.IsAlive(controller) then return nil end
    if not controller.GetFirstObjectiveFromQuest then return nil end
    local ok, obj = pcall(controller.GetFirstObjectiveFromQuest, controller, quest)
    if ok then return obj end
    return nil
end

local function getJournalQuestOfEntry(entry)
    if not entry then return nil end
    if not State.journalManager then return nil end
    local current = entry
    for _ = 1, 8 do
        if not current then return nil end
        if current.IsA and current:IsA('gameJournalQuest') then return current end
        local parent = State.journalManager:GetParentEntry(current)
        if not parent or parent == current then return nil end
        current = parent
    end
    return nil
end

local function findMainQuest()
    if not State.journalManager then return nil end
    local filter = JournalRequestStateFilter.new({ active = true })
    local context = JournalRequestContext.new()
    context.stateFilter = filter
    local quests = State.journalManager:GetQuests(context)
    if not quests then return nil end
    local controller = State.lastQuestLogGameController
    for _, quest in ipairs(quests) do
        if State.journalManager:GetQuestType(quest) == gameJournalQuestType.MainQuest then
            local first = getFirstObjectiveOfQuest(controller, quest)
            if first then return first end
            return quest
        end
    end
    return nil
end

local function getSavedEntryFromFact(factName)
    if not State.journalManager or not State.questsSystem then return nil end
    local hash = State.questsSystem:GetFactStr(factName)
    if not hash or hash == 0 then return nil end
    hash = normalizeHash(hash)
    local entry = State.journalManager:GetEntry(hash)
    if not entry then return nil end
    if State.journalManager:GetEntryState(entry) == gameJournalEntryState.Active then
        return entry
    end
    return nil
end

local function pulseInMenuFlag()
    if not State.blackboardSystem then return end
    local defs = Game.GetAllBlackboardDefs()
    if not defs or not defs.UI_System then return end
    local bb = State.blackboardSystem:Get(defs.UI_System)
    if not bb then return end
    local current = bb:GetBool(defs.UI_System.IsInMenu)
    bb:SignalBool(defs.UI_System.IsInMenu)
    bb:SetBool(defs.UI_System.IsInMenu, not current)
    bb:SetBool(defs.UI_System.IsInMenu, current)
end

local function refreshQuestLogControllerAfterChange(newTrackedQuest)
    local controller = State.lastQuestLogGameController
    if not State.IsAlive(controller) then return end

    local evt = UpdateTrackedObjectiveEvent.new()
    evt.trackedObjective = nil
    evt.trackedQuest     = newTrackedQuest

    if newTrackedQuest and controller.GetFirstObjectiveFromQuest then
        local ok, first = pcall(controller.GetFirstObjectiveFromQuest, controller, newTrackedQuest)
        if ok then evt.trackedObjective = first end
    end

    controller.trackedQuest = newTrackedQuest
    controller:QueueEvent(evt)
    if controller.PlayRumble then
        controller:PlayRumble(RumbleStrength.SuperLight, RumbleType.Fast, RumblePosition.Right)
    end

    if controller.listData then
        for i = 1, #controller.listData do
            local entry = controller.listData[i]
            if IsDefined(entry) then
                if newTrackedQuest and entry.questData and entry.questData.id == newTrackedQuest.id then
                    entry.isTrackedQuest = true
                else
                    entry.isTrackedQuest = false
                end
            end
        end
    end

    if controller.UpdateTrackingInputHint then
        pcall(controller.UpdateTrackingInputHint, controller)
    end
end

local function clearWorldMapQuestContainer()
    local controller = State.lastWorldMapMenuGameController
    if not State.IsAlive(controller) then return end
    if controller.questContainer and inkWidgetReference and inkWidgetReference.SetVisible then
        pcall(inkWidgetReference.SetVisible, controller.questContainer, false)
    end
end

-- ---------------------------------------------------------------------------
-- API

function Tracking.RememberUserUntracked(entry)
    if not entry or not State.questsSystem then return end
    if not State.journalManager then return end
    local hash = State.journalManager:GetEntryHash(entry)
    if not hash then return end
    hash = normalizeHash(hash)
    State.questsSystem:SetFactStr(FACT_PREFIX_USER_UNTRACKED .. tostring(hash), 1)
end

function Tracking.WasUserUntracked(hash)
    if not hash or not State.questsSystem then return false end
    hash = normalizeHash(hash)
    local v = State.questsSystem:GetFactStr(FACT_PREFIX_USER_UNTRACKED .. tostring(hash))
    return type(v) == 'number' and v >= 1
end

function Tracking.IsTracked()
    if not State.journalManager then return false end
    return State.journalManager:GetTrackedEntry() ~= nil
end

function Tracking.Toggle()
    if State.isDisabled then return false end
    if not State.journalManager then return false end

    local now = os.clock()
    if now - lastToggleClock < TOGGLE_DEBOUNCE then return false end
    lastToggleClock = now

    local current = State.journalManager:GetTrackedEntry()

    if State.IsAlive(current) then
        return Tracking.Untrack(current)
    end

    return Tracking.Retrack()
end

function Tracking.Untrack(currentEntry)
    if State.isDisabled then return false end
    currentEntry = currentEntry or State.journalManager:GetTrackedEntry()
    if not State.IsAlive(currentEntry) then return false end

    State.journalManager:UntrackEntry()
    pulseInMenuFlag()

    if State.journalManager:GetTrackedEntry() then
        return false
    end

    State.lastTrackedEntry = currentEntry
    local hash = State.journalManager:GetEntryHash(currentEntry)
    if hash and State.questsSystem then
        State.questsSystem:SetFactStr(FACT_LAST_TRACKED_OBJECTIVE, hash)
    end

    Tracking.RememberUserUntracked(currentEntry)

    refreshQuestLogControllerAfterChange(nil)
    clearWorldMapQuestContainer()
    return true
end

function Tracking.Retrack()
    if State.isDisabled then return false end

    local target = State.lastTrackedEntry
    if target and State.journalManager:GetEntryState(target) ~= gameJournalEntryState.Active then
        target = nil
    end
    if not target then target = getSavedEntryFromFact(FACT_LAST_TRACKED_OBJECTIVE) end
    if not target then target = getSavedEntryFromFact(FACT_LAST_TRACKED_POI) end

    if not target then target = findMainQuest() end
    if not target then return false end

    if State.questsSystem then
        local hash = State.journalManager:GetEntryHash(target)
        if hash then
            hash = normalizeHash(hash)
            State.questsSystem:SetFactStr(FACT_PREFIX_USER_UNTRACKED .. tostring(hash), 0)
        end
    end

    State.journalManager:TrackEntry(target)
    if not State.journalManager:GetTrackedEntry() then return false end

    State.lastQuestRestoreTime = os.clock() + 0.05

    local newTrackedQuest = target
    if not (target.IsA and target:IsA('gameJournalQuest')) then
        newTrackedQuest = getJournalQuestOfEntry(target) or target
    end
    refreshQuestLogControllerAfterChange(newTrackedQuest)

    State.lastTrackedEntry = nil
    return true
end

function Tracking.ToggleWithFeedback(isInMenu, player)
    if not Tracking.Toggle() then return false end
    Audio.OnToggle(isInMenu, Tracking.IsTracked(), player)
    return true
end

function Tracking.ClearMapPois()
    local controller = State.lastWorldMapMenuGameController
    if not State.IsAlive(controller) then return end
    if controller.UntrackMappin then
        pcall(controller.UntrackMappin, controller)
    end
    if controller.UntrackCustomPositionMappin then
        pcall(controller.UntrackCustomPositionMappin, controller)
    end
end

function Tracking.ToggleEverythingWithFeedback(isInMenu, player)
    local wasTracked = Tracking.IsTracked()
    if not Tracking.Toggle() then return false end
    Audio.OnToggle(isInMenu, Tracking.IsTracked(), player)
    if wasTracked and not Tracking.IsTracked() then
        Tracking.ClearMapPois()
    end
    return true
end

return Tracking
