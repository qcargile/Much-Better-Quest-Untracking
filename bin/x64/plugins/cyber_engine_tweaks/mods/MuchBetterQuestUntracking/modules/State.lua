local State = {}

-- Game systems
State.journalManager = nil
State.questsSystem = nil
State.audioSystem = nil
State.blackboardSystem = nil

-- Live UI controllers (weak refs)
State.lastWorldMapMenuGameController = nil
State.lastQuestLogGameController     = nil

-- Menu state flags
State.isQuestLogMenuActive = false
State.isWorldMapMenuActive = false
State.isWorldMapMenuOpen   = false

-- Last-known tracking state (for retrack)
State.lastTrackedEntry = nil

State.lastQuestRestoreTime = 0

-- Disable flag
State.isDisabled       = false
State.disabledReason   = ''

local weakBridge
local function ensureWeakBridge()
    if not weakBridge then
        weakBridge = inkScriptWeakHashMap.new()
        weakBridge:Insert(0, nil)
    end
end
function State.WeakRef(obj)
    ensureWeakBridge()
    weakBridge:Set(0, obj)
    return weakBridge:Get(0)
end

function State.IsAlive(obj)
    if not obj then return false end
    local ok, val = pcall(IsDefined, obj)
    return ok and val or false
end

return State
