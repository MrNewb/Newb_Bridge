local weather = {}

local function setSync(enabled)
    TriggerEvent(enabled and 'qb-weathersync:client:EnableSync' or 'qb-weathersync:client:DisableSync')
end

function weather.enableSync()
    setSync(true)
end

function weather.disableSync()
    setSync(false)
end

return weather
