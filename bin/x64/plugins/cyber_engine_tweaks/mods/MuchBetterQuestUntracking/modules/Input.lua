local State    = require('modules/State')
local Settings = require('modules/Settings')
local Tracking = require('modules/Tracking')

local Input = {}

local heldKeys = {}
local listeningKeybindWidget = nil
local inputListener           = nil

local padPressClock      = 0
local padInVehicleAtPress = false
local pendingPadTaskId   = 0
local taskQueue          = {}

local n_CameraAim
local n_world_map_menu_rotate_mouse

local function isInMenu()
    if not State.blackboardSystem then return false end
    local defs = Game.GetAllBlackboardDefs()
    if not defs or not defs.UI_System then return false end
    local bb = State.blackboardSystem:Get(defs.UI_System)
    if not bb then return false end
    return bb:GetBool(defs.UI_System.IsInMenu) == true
end
function Input.IsInMenu() return isInMenu() end

function Input.IsKbmModifierHeld()
    if not Settings.Get('enableModifierKbm') then return false end
    local key = Settings.Get('modifierKbmKey') or ''
    if #key == 0 then return false end
    return heldKeys[key] == true
end

local function isPlayerInVehicle()
    local player = GetPlayer()
    if not player then return false end
    local mounted = GetMountedVehicle(player)
    return mounted ~= nil
end

-- ---------------------------------------------------------------------------
-- Gamepad press handling

local function startPadPress()
    padInVehicleAtPress = isPlayerInVehicle() and not isInMenu()
    padPressClock       = os.clock()
    pendingPadTaskId    = pendingPadTaskId + 1
    local taskId        = pendingPadTaskId

    if padInVehicleAtPress then
        return
    end

    local thresholdSec = (Settings.Get('longPressThresholdMs') or 500) / 1000
    table.insert(taskQueue, {
        fireAt = os.clock() + thresholdSec,
        fn = function()
            if taskId ~= pendingPadTaskId then return end
            if padPressClock == 0 then return end
            Tracking.ToggleEverythingWithFeedback(isInMenu())
            padPressClock = 0
        end,
    })
end

local function endPadPress()
    pendingPadTaskId = pendingPadTaskId + 1

    if padPressClock == 0 then return end
    local elapsedMs = (os.clock() - padPressClock) * 1000
    padPressClock = 0

    if not padInVehicleAtPress then return end

    local thresholdMs = Settings.Get('longPressThresholdMs') or 500
    if elapsedMs <= thresholdMs then
        Tracking.ToggleEverythingWithFeedback(isInMenu())
    end
end

function Input.CancelPendingPadPress()
    pendingPadTaskId = pendingPadTaskId + 1
    padPressClock    = 0
end

function Input.Defer(fn, delaySec)
    table.insert(taskQueue, {
        fireAt = os.clock() + (delaySec or 0.01),
        fn    = fn,
    })
end

function Input.Tick()
    if #taskQueue == 0 then return end
    local now = os.clock()
    local i = 1
    while i <= #taskQueue do
        local t = taskQueue[i]
        if now >= t.fireAt then
            local ok, err = pcall(t.fn)
            if not ok then spdlog.error('[MBQU] task error: ' .. tostring(err)) end
            table.remove(taskQueue, i)
        else
            i = i + 1
        end
    end
end

-- ---------------------------------------------------------------------------
-- Global Input/Key callback

local function handleKeyInput(event)
    local key    = event:GetKey().value
    local action = event:GetAction().value
    local pressed = (action == 'IACT_Press')

    heldKeys[key] = pressed

    if listeningKeybindWidget then
        if action == 'IACT_Release' and key:find('IK_Pad') == 1 then
            listeningKeybindWidget:OnKeyBindingEvent(KeyBindingEvent.new({ keyName = key }))
        end
        return
    end

    if State.isDisabled then return end

    if pressed and key == 'IK_RightMouse' then
        if Input.IsKbmModifierHeld() and not State.isWorldMapMenuOpen then
            Tracking.ToggleEverythingWithFeedback(isInMenu())
            return
        end
    end

    if Settings.Get('enableLongPressPad') then
        local padKey = Settings.Get('modifierPadKey') or ''
        if #padKey > 0 and key == padKey then
            if pressed then
                startPadPress()
            elseif action == 'IACT_Release' then
                endPadPress()
            end
        end
    end
end

function Input.RegisterCallbacks()
    n_CameraAim                   = CName.new('CameraAim')
    n_world_map_menu_rotate_mouse = CName.new('world_map_menu_rotate_mouse')

    inputListener = NewProxy({
        OnKeyInput = {
            args     = { 'handle:KeyInputEvent' },
            callback = handleKeyInput,
        },
    })
    Game.GetCallbackSystem():RegisterCallback('Input/Key',
        inputListener:Target(),
        inputListener:Function('OnKeyInput'),
        true)

    Observe('SettingsSelectorControllerKeyBinding', 'ListenForInput', function(this)
        listeningKeybindWidget = this
    end)
    Observe('SettingsSelectorControllerKeyBinding', 'StopListeningForInput', function()
        listeningKeybindWidget = nil
    end)

    local nextGameplayClock = 0
    local GAMEPLAY_RETRIGGER = 0.25

    Observe('PlayerPuppet', 'OnAction', function(this, action, consumer)
        if State.isDisabled then return end
        if not action then return end
        if this:IsReplacer() then return end
        if not action:IsButton() then return end
        if not Input.IsKbmModifierHeld() then return end
        if action:GetType(action) ~= gameinputActionType.BUTTON_PRESSED then return end
        if not (action:IsAction(action, n_CameraAim) or action:IsAction(action, n_world_map_menu_rotate_mouse)) then return end

        local now = os.clock()
        if now < nextGameplayClock then
            consumer:Consume()
            return
        end
        nextGameplayClock = now + GAMEPLAY_RETRIGGER

        local mounted = GetMountedVehicle(this)
        if (not mounted) or (mounted and this:GetActiveWeapon()) then
            consumer:Consume()
        end

        Tracking.ToggleEverythingWithFeedback(isInMenu(), this)
    end)
end

return Input
