local MOD_NAME    = 'Much Better Quest Untracking'
local MOD_VERSION = '1.0.1'

local State            = require('modules/State')
local Settings         = require('modules/Settings')
local Localization     = require('modules/Localization')
local Tracking         = require('modules/Tracking')
local Audio            = require('modules/Audio')
local Input            = require('modules/Input')
local WorldMap         = require('modules/WorldMap')
local QuestLog         = require('modules/QuestLog')
local MainQuestGuard   = require('modules/MainQuestGuard')
local FixerRewardGuard = require('modules/FixerRewardGuard')
local SaveMetadata     = require('modules/SaveMetadata')
local NativeSettingsUI = require('modules/NativeSettingsUI')

-- ---------------------------------------------------------------------------
-- Lifecycle

registerForEvent('onInit', function()
    Settings.Load()
    Localization.Load(Settings.Get('languageOverride'))

    local versionStr = tostring(Game.GetSystemRequestsHandler():GetGameVersion() or '0')
    local major = tonumber(versionStr:match('^(%d+)') or '0') or 0
    if major < 2 then
        State.isDisabled = true
        State.disabledReason = 'Game version 2.x required.'
        spdlog.error('[MBQU] disabled: ' .. State.disabledReason)
        return
    end

    State.journalManager    = State.WeakRef(Game.GetJournalManager())
    State.questsSystem      = State.WeakRef(Game.GetQuestsSystem())
    State.audioSystem       = State.WeakRef(Game.GetAudioSystem())
    State.blackboardSystem  = State.WeakRef(Game.GetBlackboardSystem())

    QuestLog.Register()
    WorldMap.Register()
    Input.RegisterCallbacks()
    MainQuestGuard.Register()
    FixerRewardGuard.Register()
    SaveMetadata.Register()
    NativeSettingsUI.Init()

    print(MOD_NAME .. ' ' .. MOD_VERSION .. ' initialized.')
end)

registerForEvent('onUpdate', function()
    if State.isDisabled then return end
    Input.Tick()
    SaveMetadata.Tick()
end)

registerForEvent('onShutdown', function()
    Settings.Save()
end)
