local dispatch = {}

function dispatch.sendAlert(src, jobs, coords, data, blip, alertFlash)
    exports["codem-dispatch"]:CustomDispatch({
        type = data.code or "General",
        header = data.title,
        text = data.description,
        code = data.code,
    })
end

return dispatch
