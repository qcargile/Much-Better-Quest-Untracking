local State    = require('modules/State')
local Settings = require('modules/Settings')
local Tracking = require('modules/Tracking')
local Input    = require('modules/Input')

local MainQuestGuard = {}

local lastQueuedAt = 0
local QUEUE_DEBOUNCE = 0.1

local function getQuestEntryAncestor(entry)
    if not entry or not State.journalManager then return nil end
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

local function isInMenu()
    if not State.blackboardSystem then return false end
    local defs = Game.GetAllBlackboardDefs()
    if not defs or not defs.UI_System then return false end
    local bb = State.blackboardSystem:Get(defs.UI_System)
    if not bb then return false end
    return bb:GetBool(defs.UI_System.IsInMenu) == true
end

function MainQuestGuard.Register()
    ObserveAfter('QuestTrackerGameController', 'OnTrackedEntryChanges', function(this, hash)
        if State.isDisabled then return end
        if not Settings.Get('preventMainQuestRetrack') then return end
        if (not hash) or hash == 0 then return end
        if isInMenu() then return end

        local now = os.clock()
        if now - lastQueuedAt < QUEUE_DEBOUNCE then return end

        -- SceneTier prologue / scripted segments
        local player = GetPlayer()
        if not player or player:GetSceneTier() < 1 then return end
        if State.IsAlive(State.lastQuestLogGameController) then return end

        local quest = getQuestEntryAncestor(this.bufferedEntry)
        if not quest then return end
        if quest:GetType() ~= gameJournalQuestType.MainQuest then return end

        if not Tracking.WasUserUntracked(hash) then return end

        lastQueuedAt = now
        Input.Defer(function()
            if State.isDisabled then return end
            if not State.journalManager then return end
            State.journalManager:UntrackEntry()
        end)
    end)

    local lastTrackedQuest, lastTrackedObjective
    ObserveBefore('questLogGameController', 'OnRequestChangeTrackedObjective', function(this)
        if State.isDisabled then return end
        lastTrackedQuest = State.WeakRef(this.trackedQuest)
        if State.journalManager then
            lastTrackedObjective = State.WeakRef(State.journalManager:GetTrackedEntry())
        end
    end)
    ObserveAfter('questLogGameController', 'OnRequestChangeTrackedObjective', function(this)
        if State.isDisabled then return end
        if not lastTrackedQuest then return end
        if not lastTrackedObjective then return end
        if this.trackedQuest then return end
        local quest = getQuestEntryAncestor(lastTrackedQuest)
        lastTrackedQuest = nil
        if not quest then return end
        if not State.journalManager then return end
        if State.journalManager:GetQuestType(quest) ~= gameJournalQuestType.MainQuest then return end
        Tracking.RememberUserUntracked(lastTrackedObjective)
        lastTrackedObjective = nil
    end)
end

return MainQuestGuard
