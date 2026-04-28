local State    = require('modules/State')
local Settings = require('modules/Settings')
local Tracking = require('modules/Tracking')
local Input    = require('modules/Input')

local WorldMap = {}

local n_world_map_menu_track_waypoint
local n_activate_secondary
local n_gameuiMappinBaseController
local n_MapPin, n_OnDisable, n_OnCreate
local n_world_map_menu_zoom_to_mappin
local n_Button, n_OnPress

local shouldIgnoreNextTryTrack = false
local lastClickConsumedAt      = 0
local SUPPRESS_WINDOW          = 0.1

local backSuppressUntil  = 0
local BACK_SUPPRESS_WINDOW = 0.4

local padDeferralActive = false
local padDeferralClock  = 0

local function consumeClick()
    shouldIgnoreNextTryTrack = true
    lastClickConsumedAt      = os.clock()
end

local function selectedMappinIsTrackedQuest(controller)
    if not controller then return false end
    local mappin = controller.selectedMappin
    if not State.IsAlive(mappin) then return false end
    if not mappin:IsA(n_gameuiMappinBaseController) then return false end
    if not mappin:IsPlayerTracked() then return false end
    local data = mappin:GetMappin()
    if not data then return false end
    return data:IsQuestPath()
end

-- ---------------------------------------------------------------------------
-- (2.3 POI bug fix)

local function installPatchedOverride()
    Override('WorldMapMenuGameController', 'TryTrackQuestOrSetWaypoint', function(this, wrapped)
        if State.isDisabled then return wrapped() end

        local mappin = this.selectedMappin
        if not mappin then return wrapped() end

        if this:CanQuestTrackMappin(mappin) then return wrapped() end
        if mappin:IsDelamainTaxiTracked() then return wrapped() end
        if this:IsDelamainTaxiEnabled() then return wrapped() end

        if not this:CanPlayerTrackMappin(mappin) then return wrapped() end

        if mappin:IsCustomPositionTracked() then return wrapped() end

        if not mappin:IsPlayerTracked() then return wrapped() end

        if this:IsFastTravelEnabled() then return end

        local inCollection = mappin:IsInCollection()
        if inCollection and not mappin:IsCollection() then
            this:PlaySound(n_MapPin, n_OnCreate)
            return
        end

        this:UntrackMappin()
        this:PlaySound(n_MapPin, n_OnDisable)
        this:PlayRumble(RumbleStrength.SuperLight, RumbleType.Pulse, RumblePosition.Right)
        this:UpdateSelectedMappinTooltip()
        this:PlaySound(n_MapPin, n_OnCreate)
    end)
end

-- ---------------------------------------------------------------------------
-- Pad press deferral

local function dispatchPadShortRelease(controller)
    if not State.IsAlive(controller) then return end

    if controller.HandleNavigateClick then
        local mode = tostring(controller.controlMode or ''):upper()
        if mode:find('NAVIGATE') then
            controller:HandleNavigateClick()
        elseif mode:find('CANCEL') then
            controller:HandleCancelClick()
        elseif mode:find('CONFIRM') then
            controller:HandleConfirmClick()
        elseif mode:find('STOP') then
            controller:HandleStopClick()
        else
            controller:HandleNavigateClick()
        end
        return
    end

    if controller.HasSelectedMappin and controller:HasSelectedMappin()
       and controller.selectedMappin and controller.CanZoomToMappin
       and controller:CanZoomToMappin(controller.selectedMappin) then
        pcall(controller.PlaySound, controller, n_Button, n_OnPress)
        pcall(controller.ZoomToMappin, controller, controller.selectedMappin)
    end
end

local function installPadDeferralOverrides()
    Override('WorldMapMenuGameController', 'HandlePressInput', function(this, e, wrapped)
        if State.isDisabled then return wrapped(e) end
        if not Settings.Get('enableLongPressPad') then return wrapped(e) end
        if not e:IsAction(n_world_map_menu_zoom_to_mappin) then return wrapped(e) end
        local player = GetPlayer()
        if not player or not player:PlayerLastUsedPad() then return wrapped(e) end

        if this.HasSelectedMappin and this:HasSelectedMappin() then
            Input.CancelPendingPadPress()
            return wrapped(e)
        end

        padDeferralActive = true
        padDeferralClock  = os.clock()
        e:Handle()
    end)

    Override('WorldMapMenuGameController', 'HandleReleaseInput', function(this, e, wrapped)
        if State.isDisabled then return wrapped(e) end

        if padDeferralActive and e:IsAction(n_world_map_menu_zoom_to_mappin) then
            padDeferralActive = false
            local elapsedMs   = (os.clock() - padDeferralClock) * 1000
            local thresholdMs = Settings.Get('longPressThresholdMs') or 500
            if elapsedMs < thresholdMs then
                dispatchPadShortRelease(this)
            end
        end

        return wrapped(e)
    end)
end

-- ---------------------------------------------------------------------------
-- Suppressor Override

local function installSuppressorOverride()
    Override('gameuiWorldMapMenuGameController', 'TryTrackQuestOrSetWaypoint', function(_, wrapped)
        if State.isDisabled then return wrapped() end
        if shouldIgnoreNextTryTrack and (os.clock() - lastClickConsumedAt) < SUPPRESS_WINDOW then
            shouldIgnoreNextTryTrack = false
            return
        end
        return wrapped()
    end)
end

-- ---------------------------------------------------------------------------
-- Public

function WorldMap.Register()
    n_world_map_menu_track_waypoint = CName.new('world_map_menu_track_waypoint')
    n_activate_secondary            = CName.new('activate_secondary')
    n_gameuiMappinBaseController    = CName.new('gameuiMappinBaseController')
    n_MapPin                        = CName.new('MapPin')
    n_OnDisable                     = CName.new('OnDisable')
    n_OnCreate                      = CName.new('OnCreate')
    n_world_map_menu_zoom_to_mappin = CName.new('world_map_menu_zoom_to_mappin')
    n_Button                        = CName.new('Button')
    n_OnPress                       = CName.new('OnPress')

    installPatchedOverride()
    installPadDeferralOverrides()
    installSuppressorOverride()

    Observe('WorldMapMenuGameController', 'OnEntityAttached', function(this)
        if State.isDisabled then return end
        State.lastWorldMapMenuGameController = State.WeakRef(this)
        State.isWorldMapMenuOpen = true
    end)
    ObserveBefore('WorldMapMenuGameController', 'OnEntityDetached', function(this)
        if State.isDisabled then return end
        State.lastWorldMapMenuGameController = nil
        State.isWorldMapMenuOpen = false
    end)

    ObserveBefore('gameuiWorldMapMenuGameController', 'OnPressInput', function(this, e)
        if State.isDisabled then return end
        State.lastWorldMapMenuGameController = State.WeakRef(this)
        State.isWorldMapMenuActive = true
        if State.isQuestLogMenuActive then State.isWorldMapMenuActive = false return end

        shouldIgnoreNextTryTrack = false

        local isPadTrack  = e:IsAction(n_world_map_menu_track_waypoint)
        local isKbmRClick = e:IsAction(n_activate_secondary)
        if not (isPadTrack or isKbmRClick) then return end

        if this:IsFastTravelEnabled() then return end
        if this.IsDelamainTaxiEnabled and this:IsDelamainTaxiEnabled() then return end

        if Input.IsKbmModifierHeld() then
            consumeClick()
            backSuppressUntil = os.clock() + BACK_SUPPRESS_WINDOW
            Tracking.ToggleEverythingWithFeedback(true, this.player)
            return
        end

        if isKbmRClick then
            if selectedMappinIsTrackedQuest(this) then
                consumeClick()
                Tracking.ToggleWithFeedback(true, this.player)
            end
            return
        end

        if isPadTrack then
            if selectedMappinIsTrackedQuest(this) then
                consumeClick()
                Tracking.ToggleWithFeedback(true, this.player)
            end
        end
    end)

    Override('QuestDetailsPanelController', 'OnUpdateTrackedObjectiveEvent', function(_, e, wrapped)
        if State.isDisabled then return wrapped(e) end
        if State.lastQuestRestoreTime and os.clock() < State.lastQuestRestoreTime then
            return true
        end
        return wrapped(e)
    end)

    Override('WorldMapMenuGameController', 'OnBack', function(_, userData, wrapped)
        if State.isDisabled then return wrapped(userData) end
        if os.clock() < backSuppressUntil then
            backSuppressUntil = 0
            return
        end
        return wrapped(userData)
    end)
end

return WorldMap
