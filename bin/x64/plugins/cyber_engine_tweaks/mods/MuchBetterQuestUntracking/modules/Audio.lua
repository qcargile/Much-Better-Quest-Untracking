local State    = require('modules/State')
local Settings = require('modules/Settings')

local Audio = {}

Audio.gameplaySoundChoices = {
    'ui_loot_take_all',
    'ui_menu_hover',
    'ui_menu_map_pin_on',
    'ui_menu_map_pin_off',
    'ui_menu_map_pin_created',
    'ui_jingle_quest_success',
    'ui_jingle_quest_update',
}

local function play(player, soundName)
    if not player then return end
    if soundName and #soundName > 0 then
        pcall(function() player:PlaySoundEvent(soundName) end)
        return
    end
    if State.audioSystem then
        pcall(function() State.audioSystem:PlayLootAllSound() end)
    end
end

function Audio.OnToggle(isInMenu, isNowTracked, player)
    if not Settings.Get('playFeedbackSounds') then return end
    player = player or GetPlayer()
    if not player then return end

    if not isInMenu then
        play(player, Settings.Get('feedbackSoundName'))
        return
    end

    if State.isQuestLogMenuActive then
        if isNowTracked then
            pcall(function() player:PlaySoundEvent('ui_menu_map_pin_created') end)
        else
            pcall(function() player:PlaySoundEvent('ui_menu_map_pin_off') end)
        end
        return
    end

    if State.isWorldMapMenuActive then
        if isNowTracked then
            pcall(function() player:PlaySoundEvent('ui_menu_map_pin_on') end)
        else
            pcall(function() player:PlaySoundEvent('ui_menu_map_pin_off') end)
        end
        return
    end

    if isNowTracked then
        pcall(function() player:PlaySoundEvent('ui_menu_map_pin_on') end)
    else
        pcall(function() player:PlaySoundEvent('ui_menu_map_pin_off') end)
    end
end

function Audio.PlaySample(soundName)
    local player = GetPlayer()
    if not player then return end
    if soundName and #soundName > 0 then
        pcall(function() player:PlaySoundEvent(soundName) end)
    end
end

return Audio
