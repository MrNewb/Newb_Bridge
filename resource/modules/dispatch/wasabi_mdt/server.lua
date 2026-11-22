local dispatch = {}

function dispatch.sendAlert(src, jobs, coords, data, blip, alertFlash)
    if GetResourceState('wasabi_mdt') ~= 'started' then
        return false
    end

    local dispatchType = data and (data['type'] or data.code or 'disturbance') or 'disturbance'
    local dispatchTitle = data and (data['title'] or data.code or 'Dispatch') or 'Dispatch'
    local dispatchDescription = data and (data['description'] or '') or ''
    local dispatchLocation = (blip and blip.text) or (data and data['title']) or 'Unknown Location'
    local createdByName = type(src) == 'number' and GetPlayerName(src) or tostring(src or 'System')

    local dispatchData = {
        type = dispatchType,
        title = dispatchTitle,
        description = dispatchDescription,
        location = dispatchLocation,
        coords = {
            x = coords.x,
            y = coords.y,
            z = coords.z,
        },
        priority = alertFlash and 5 or 3,
        status = 'pending',
        created_by = tostring(src or 'system'),
        created_by_name = createdByName or 'System',
        departments = jobs or { 'police' },
        metadata = {
            bridge = true,
            source = src,
            alertFlash = alertFlash == true,
            blipText = blip and blip.text or nil,
        },
    }

    exports.wasabi_mdt:CreateDispatch(dispatchData)
    return true
end

return dispatch
