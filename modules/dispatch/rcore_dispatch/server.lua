local dispatch = {}

function dispatch.sendAlert(src, jobs, coords, data, blip, alertFlash)
    TriggerEvent("rcore_dispatch:server:sendAlert", {
        code = data.code,
        default_priority = "high",
        coords = coords,
        job = jobs,
        text = data.title,
        type = "alerts",
        blip_time = (data.length * 60),
        blip = {
            sprite = blip.sprite,
            colour = blip.colour,
            scale = blip.scale,
            text = blip.text,
        },
    })
end

return dispatch
