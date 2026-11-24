local dispatch = {}

-- wasabi_mdt's CreateDispatch has no department filter, so `jobs` is not used here.
function dispatch.sendAlert(src, jobs, coords, data, blip, alertFlash)
    local sender = type(src) == 'number' and GetPlayerName(src) or 'System'

    local created = exports.wasabi_mdt:CreateDispatch({
        type = data.type or data.code or 'disturbance',
        title = data.title or data.code or 'Dispatch',
        description = data.description or '',
        location = blip.text or data.title or 'Unknown Location',
        coords = coords,
        priority = alertFlash and 5 or 3,
        code = data.code,
        senderName = sender,
    })

    return created and true or false
end

return dispatch
