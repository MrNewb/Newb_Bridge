local dispatch = {}

function dispatch.sendAlert(src, jobs, coords, data, blip, alertFlash)
    for i = 1, #jobs do
        exports.origen_police:SendAlert({
            coords = coords,
            title = data.title,
            type = "GENERAL",
            message = data.description,
            job = jobs[i],
        })
    end
end

return dispatch
