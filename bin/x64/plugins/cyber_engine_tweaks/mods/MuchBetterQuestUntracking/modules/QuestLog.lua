local State = require('modules/State')

local QuestLog = {}

function QuestLog.Register()
    Observe('questLogGameController', 'BuildQuestList', function(self)
        State.lastQuestLogGameController = State.WeakRef(self)
    end)
    Observe('questLogGameController', 'UpdateTrackingInputHint', function(self)
        State.lastQuestLogGameController = State.WeakRef(self)
    end)

    ObserveAfter('questLogGameController', 'OnInitialize', function(this)
        if State.isDisabled then return end
        if not this:IsA('questLogGameController') then return end
        State.isQuestLogMenuActive = true
        State.lastQuestLogGameController = State.WeakRef(this)
    end)
    ObserveAfter('questLogGameController', 'OnUninitialize', function(this)
        if State.isDisabled then return end
        if not this:IsA('questLogGameController') then return end
        State.isQuestLogMenuActive = false
    end)

    Observe('QuestDetailsObjectiveController', 'OnHoverOver', function()
        if State.isDisabled then return end
        State.isQuestLogMenuActive = true
    end)
    Observe('QuestDetailsObjectiveController', 'OnHoverOut', function()
        if State.isDisabled then return end
        State.isQuestLogMenuActive = true
    end)

    ObserveAfter('MenuScenario_HubMenu', 'OnOpenMenu', function(_, name)
        if State.isDisabled then return end
        State.isQuestLogMenuActive = false
        State.isWorldMapMenuActive = false
        local nameStr = NameToString(name)
        if nameStr == 'quest_log' then State.isQuestLogMenuActive = true end
        if nameStr == 'world_map' then State.isWorldMapMenuActive = true end
    end)
end

return QuestLog
