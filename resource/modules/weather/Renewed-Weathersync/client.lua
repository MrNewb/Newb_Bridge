local weather = {}

local function setSync(enabled)
    LocalPlayer.state.syncWeather = enabled
end

function weather.enableSync()
    setSync(true)
end

function weather.disableSync()
    setSync(false)
end

return weather
