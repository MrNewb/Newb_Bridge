local dispatch = {}

function dispatch.sendAlert(src, jobs, coords, data, blip, alertFlash)
    if GetResourceState('redutzu-mdt') ~= 'started' then
        return false
    end

    TriggerEvent('redutzu-mdt:server:addDispatchToMDT', {
        code = data and (data.code or data.title or '10-90') or '10-90',
        title = data and (data.title or data.code or 'Dispatch') or 'Dispatch',
        street = blip and blip.text or 'Unknown Location',
        weapon = nil,
        gender = nil,
        vehicle = nil,
        duration = (data and (data.length or blip and blip.length)) and ((data.length or blip.length) * 1000) or 60000,
        coords = {
            x = coords.x,
            y = coords.y,
            z = coords.z,
        },
    })

    return true
end

return dispatch
