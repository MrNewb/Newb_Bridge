local dispatch = {}

function dispatch.sendAlert(src, jobs, coords, data, blip, alertFlash)
    exports.tk_dispatch:addCall({
        title = data.title,
        code = data.code,
        message = data.description,
        coords = coords,
        flash = alertFlash,
        playSound = true,
        jobs = jobs,
        blip = {
            sprite = blip.sprite,
            scale = blip.scale,
            color = blip.colour,
            flash = blip.flash,
        },
    })
end

return dispatch
