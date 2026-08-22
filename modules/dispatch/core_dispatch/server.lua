local dispatch = {}

function dispatch.sendAlert(src, jobs, coords, data, blip, alertFlash)
    for _, job in pairs(jobs) do
        exports.core_dispatch:sendAlert({
            code = data.code,
            message = data.description,
            extraInfo = {},
            coords = coords,
            priority = alertFlash or false,
            job = job,
            time = (data.length or blip.length or 5) * 60000,
            blip = blip.sprite,
            color = blip.colour,
        })
    end
end

return dispatch
