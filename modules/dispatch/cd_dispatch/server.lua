local dispatch = {}

function dispatch.sendAlert(src, jobs, coords, data, blip, alertFlash)
    TriggerEvent("cd_dispatch:AddNotification", {
        job_table = jobs,
        coords = coords,
        title = data.title,
        message = data.description,
        flash = alertFlash and 1 or 0,
        unique_id = string.random("1111111"),
        sound = 1,
        blip = {
            sprite = blip.sprite,
            scale = blip.scale,
            colour = blip.colour,
            flashes = blip.flash,
            text = blip.text,
            time = blip.length,
            radius = 0,
        },
    })
end

return dispatch
