local Settings = {}

Settings.defaults = {
    modifierKbmKey                   = 'IK_LShift',
    modifierPadKey                   = 'IK_Pad_RightThumb',
    enableModifierKbm                = true,
    enableLongPressPad               = true,
    longPressThresholdMs             = 500,

    -- Re-tracking guards
    preventMainQuestRetrack          = true,
    preventFixerRewardAutotrack      = true,

    -- Audio
    playFeedbackSounds               = true,
    feedbackSoundName                = 'ui_loot_take_all',

    -- Misc
    showSaveListUntrackedLabel       = true,
    languageOverride                 = '',
}

Settings.current     = nil
Settings.filename    = 'settings.json'
local listeners      = {}

local function clone(src)
    local out = {}
    for k, v in pairs(src) do
        if type(v) == 'table' then out[k] = clone(v) else out[k] = v end
    end
    return out
end

local function notify()
    for _, fn in ipairs(listeners) do
        local ok, err = pcall(fn, Settings.current)
        if not ok then spdlog.error('[MBQU] settings listener error: ' .. tostring(err)) end
    end
end

local function readFile(file)
    local f = io.open(file, 'r')
    if not f then return nil end
    local content = f:read('*a')
    f:close()
    return content
end

local function loadJson(file)
    local raw = readFile(file)
    if not raw or #raw == 0 then return nil end
    local ok, decoded = pcall(json.decode, raw)
    if ok and type(decoded) == 'table' then return decoded end
    return nil
end

local function saveJson(file, tbl)
    local ok, encoded = pcall(json.encode, tbl)
    if not ok then return false end
    local f = io.open(file, 'w')
    if not f then return false end
    f:write(encoded)
    f:close()
    return true
end

function Settings.Load()
    Settings.current = clone(Settings.defaults)
    local data = loadJson(Settings.filename)
    if type(data) == 'table' then
        for k, v in pairs(data) do
            if Settings.current[k] ~= nil and type(v) == type(Settings.current[k]) then
                Settings.current[k] = v
            end
        end
    end
    notify()
end

function Settings.Save()
    if not Settings.current then return end
    saveJson(Settings.filename, Settings.current)
end

function Settings.Set(key, value)
    if Settings.current[key] == value then return end
    Settings.current[key] = value
    Settings.Save()
    notify()
end

function Settings.Get(key)
    if not Settings.current then return Settings.defaults[key] end
    return Settings.current[key]
end

function Settings.OnChange(fn)
    table.insert(listeners, fn)
end

return Settings
