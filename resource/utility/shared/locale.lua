local localeTree = {}
local resolved = {} ---@type table<string, string|false>

-- Uses the same convar as ox_lib (`setr ox:locale en` in server.cfg).
local function getLocaleCode()
    return GetConvar('ox:locale', 'en')
end

local function loadLocaleFile(localeCode)
    local raw = LoadResourceFile(bridge.name, ('locales/%s.json'):format(localeCode))
    if not raw then return end
    return json.decode(raw)
end

local function resolveLocale(key)
    local current = localeTree

    for part in key:gmatch('([^%.]+)') do
        if type(current) ~= 'table' then
            return nil
        end

        current = current[part]
        if current == nil then
            return nil
        end
    end

    return type(current) == 'string' and current or nil
end

Citizen.CreateThreadNow(function()
    local localeCode = getLocaleCode()
    local locales = loadLocaleFile(localeCode)

    if not locales and localeCode ~= 'en' then
        localeCode = 'en'
        locales = loadLocaleFile(localeCode)
    end

    if not locales then
        return print(("^1[Newb_Bridge] Failed to load locale file for locale '%s'. Check if the file exists and is a valid JSON.^0"):format(getLocaleCode()))
    end

    localeTree = locales
end)

function bridge.locale(key, params)
    local template = resolved[key]

    if template == nil then
        template = resolveLocale(key) or false
        resolved[key] = template
    end

    if not template then return key end

    return (template:gsub('{(.-)}', function(found)
        return params and params[found] ~= nil and tostring(params[found]) or '{' .. found .. '}'
    end))
end

function bridge.locales()
    return localeTree
end

-- Consumer resources only load import.lua, so they reach these through the host.
exports('Locale', function(key, params)
    return bridge.locale(key, params)
end)

exports('Locales', function()
    return localeTree
end)
