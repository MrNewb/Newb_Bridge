local weather = {}

local function setSync(enabled)
    TriggerEvent('cd_easytime:PauseSync', enabled)
end

function weather.enableSync()
    setSync(true)
end

function weather.disableSync()
    setSync(false)
end

return weather
