local dispatch = {}

function dispatch.sendAlert(src, jobs, coords, data, blip, alertFlash)
    for i = 1, #jobs do
        exports["lb-tablet"]:AddDispatch({
            priority = "high",
            code = data.code,
            title = data.title,
            description = data.description or data.title or "Dispatch alert",
            location = {
                label = blip.text or data.title,
                coords = vec2(coords.x, coords.y),
            },
            time = (data.length or blip.length or 5) * 60,
            job = jobs[i],
            blip = {
                sprite = blip.sprite,
                color = blip.colour,
                size = blip.scale,
                label = blip.text,
            },
        })
    end
end

return dispatch
