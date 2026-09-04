local Localization = {}

local strings = {}
local fallback = {}
local currentLocale = 'en-us'
local fallbackLocale = 'en-us'
local availableLocales = {}

local function readJson(path)
    local f = io.open(path, 'r')
    if not f then return nil end
    local raw = f:read('*a')
    f:close()
    if not raw or #raw == 0 then return nil end
    local ok, decoded = pcall(json.decode, raw)
    if ok and type(decoded) == 'table' then return decoded end
    return nil
end

local function detectGameLocale()
    local ok, lang = pcall(function()
        return Game.NameToString(Game.GetSettingsSystem():GetVar('/language', 'OnScreen'):GetValue())
    end)
    if ok and type(lang) == 'string' and #lang > 0 then
        return lang:lower()
    end
    return fallbackLocale
end

local function discoverLocales()
    local KNOWN_LOCALES = {
        'ar-ar', 'cz-cz', 'de-de', 'en-us', 'es-es', 'es-mx', 'fr-fr',
        'hu-hu', 'it-it', 'jp-jp', 'kr-kr', 'pl-pl', 'pt-br', 'ru-ru',
        'th-th', 'tr-tr', 'ua-ua', 'zh-cn', 'zh-tw',
    }
    availableLocales = {}
    for _, code in ipairs(KNOWN_LOCALES) do
        local f = io.open(string.format('language/%s.json', code), 'r')
        if f then
            f:close()
            table.insert(availableLocales, code)
        end
    end
end

function Localization.Load(override)
    discoverLocales()

    fallback = readJson(string.format('language/%s.json', fallbackLocale))
    if not fallback then
        spdlog.error('[MBQU] CRITICAL: language/' .. fallbackLocale .. '.json missing or invalid. UI strings will appear as raw keys.')
        fallback = {}
    end

    local target = (override and #override > 0 and override) or detectGameLocale()
    currentLocale = target

    local localeStrings = readJson(string.format('language/%s.json', target))
    if localeStrings then
        strings = localeStrings
    else
        strings = fallback
        currentLocale = fallbackLocale
    end
end

function Localization.Get(key)
    if strings[key] then return strings[key] end
    if fallback[key] then return fallback[key] end
    return key
end

function Localization.CurrentLocale()
    return currentLocale
end

function Localization.AvailableLocales()
    if #availableLocales == 0 then return { fallbackLocale } end
    return availableLocales
end

return Localization
