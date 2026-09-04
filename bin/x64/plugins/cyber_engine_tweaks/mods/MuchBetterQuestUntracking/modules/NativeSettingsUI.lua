local Settings     = require('modules/Settings')
local Localization = require('modules/Localization')
local Audio        = require('modules/Audio')

local NativeSettingsUI = {}

local nativeSettings
local TAB_PATH = '/MuchBetterQuestUntracking'

local function L(key) return Localization.Get(key) end

local function findSoundIndex(name)
    for i, n in ipairs(Audio.gameplaySoundChoices) do
        if n == name then return i end
    end
    return 1
end

local hasBuilt = false

local function rebuild()
    if not nativeSettings then return end
    if hasBuilt then return end
    hasBuilt = true

    nativeSettings.addTab(TAB_PATH, L('modName'))

    -- Untrack
    local anywhere = TAB_PATH .. '/anywhere'
    nativeSettings.addSubcategory(anywhere, L('settings.category.modifierTriggers'))

    nativeSettings.addKeyBinding(anywhere,
        L('settings.modifierKbmKey.label'),
        L('settings.modifierKbmKey.desc'),
        Settings.Get('modifierKbmKey'),
        Settings.defaults.modifierKbmKey,
        false,
        function(key) Settings.Set('modifierKbmKey', key) end)

    nativeSettings.addSwitch(anywhere,
        L('settings.enableModifierKbm.label'),
        L('settings.enableModifierKbm.desc'),
        Settings.Get('enableModifierKbm'),
        Settings.defaults.enableModifierKbm,
        function(v) Settings.Set('enableModifierKbm', v) end)

    nativeSettings.addKeyBinding(anywhere,
        L('settings.modifierPadKey.label'),
        L('settings.modifierPadKey.desc'),
        Settings.Get('modifierPadKey'),
        Settings.defaults.modifierPadKey,
        false,
        function(key) Settings.Set('modifierPadKey', key) end)

    nativeSettings.addSwitch(anywhere,
        L('settings.enableLongPressPad.label'),
        L('settings.enableLongPressPad.desc'),
        Settings.Get('enableLongPressPad'),
        Settings.defaults.enableLongPressPad,
        function(v) Settings.Set('enableLongPressPad', v) end)

    nativeSettings.addRangeInt(anywhere,
        L('settings.longPressThresholdMs.label'),
        L('settings.longPressThresholdMs.desc'),
        200, 1500, 50,
        Settings.Get('longPressThresholdMs'),
        Settings.defaults.longPressThresholdMs,
        function(v) Settings.Set('longPressThresholdMs', v) end)

    -- Guards ----------------------------------------------------------------
    local guards = TAB_PATH .. '/guards'
    nativeSettings.addSubcategory(guards, L('settings.category.guards'))

    nativeSettings.addSwitch(guards,
        L('settings.preventMainQuestRetrack.label'),
        L('settings.preventMainQuestRetrack.desc'),
        Settings.Get('preventMainQuestRetrack'),
        Settings.defaults.preventMainQuestRetrack,
        function(v) Settings.Set('preventMainQuestRetrack', v) end)

    nativeSettings.addSwitch(guards,
        L('settings.preventFixerRewardAutotrack.label'),
        L('settings.preventFixerRewardAutotrack.desc'),
        Settings.Get('preventFixerRewardAutotrack'),
        Settings.defaults.preventFixerRewardAutotrack,
        function(v) Settings.Set('preventFixerRewardAutotrack', v) end)

    -- Feedback --------------------------------------------------------------
    local feedback = TAB_PATH .. '/feedback'
    nativeSettings.addSubcategory(feedback, L('settings.category.feedback'))

    nativeSettings.addSwitch(feedback,
        L('settings.playFeedbackSounds.label'),
        L('settings.playFeedbackSounds.desc'),
        Settings.Get('playFeedbackSounds'),
        Settings.defaults.playFeedbackSounds,
        function(v) Settings.Set('playFeedbackSounds', v) end)

    nativeSettings.addSelectorString(feedback,
        L('settings.feedbackSoundName.label'),
        L('settings.feedbackSoundName.desc'),
        Audio.gameplaySoundChoices,
        findSoundIndex(Settings.Get('feedbackSoundName')),
        findSoundIndex(Settings.defaults.feedbackSoundName),
        function(idx) Settings.Set('feedbackSoundName', Audio.gameplaySoundChoices[idx]) end)

    nativeSettings.addButton(feedback,
        L('settings.feedbackSoundTest.label'),
        L('settings.feedbackSoundTest.desc'),
        L('settings.feedbackSoundTest.button'),
        45,
        function() Audio.PlaySample(Settings.Get('feedbackSoundName')) end)

    -- Localization ----------------------------------------------------------
    local locales = Localization.AvailableLocales()
    if #locales > 1 then
        local localeChoices = { '' }
        for _, code in ipairs(locales) do table.insert(localeChoices, code) end
        local function findLocaleIdx(code)
            for i, c in ipairs(localeChoices) do if c == code then return i end end
            return 1
        end
        nativeSettings.addSelectorString(feedback,
            L('settings.languageOverride.label'),
            L('settings.languageOverride.desc'),
            localeChoices,
            findLocaleIdx(Settings.Get('languageOverride') or ''),
            findLocaleIdx(Settings.defaults.languageOverride or ''),
            function(idx) Settings.Set('languageOverride', localeChoices[idx]) end)
    end

    -- Misc ------------------------------------------------------------------
    local misc = TAB_PATH .. '/misc'
    nativeSettings.addSubcategory(misc, L('settings.category.misc'))

    nativeSettings.addSwitch(misc,
        L('settings.showSaveListUntrackedLabel.label'),
        L('settings.showSaveListUntrackedLabel.desc'),
        Settings.Get('showSaveListUntrackedLabel'),
        Settings.defaults.showSaveListUntrackedLabel,
        function(v) Settings.Set('showSaveListUntrackedLabel', v) end)
end

function NativeSettingsUI.Init()
    nativeSettings = GetMod('nativeSettings')
    if not nativeSettings then return end
    rebuild()

    Settings.OnChange(function(current)
        local newLocale = current.languageOverride
        if newLocale and newLocale ~= Localization.CurrentLocale() then
            Localization.Load(newLocale)
        end
    end)
end

return NativeSettingsUI
