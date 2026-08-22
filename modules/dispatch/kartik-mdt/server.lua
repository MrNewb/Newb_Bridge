local dispatch = {}

local function normalizeJobs(jobs)
    if not jobs then
        return { police = true }
    end

    if type(jobs) == "table" then
        local normalized = {}

        for key, value in pairs(jobs) do
            if type(key) == "string" and value == true then
                normalized[key] = true
            elseif type(value) == "string" then
                normalized[value] = true
            end
        end

        return next(normalized) and normalized or { police = true }
    end

    if type(jobs) == "string" then
        return { [jobs] = true }
    end

    return { police = true }
end

local function getCoords(src, coords)
    if coords then
        return coords
    end

    if src then
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then
            return GetEntityCoords(ped)
        end
    end

    return vector3(0.0, 0.0, 0.0)
end

function dispatch.sendAlert(src, jobs, coords, data, blip, alertFlash)
    if GetResourceState("kartik-mdt") ~= "started" then
        print("^1[Newb_Bridge] kartik-mdt is not started. Dispatch alert skipped.^0")
        return false
    end

    data = data or {}
    coords = getCoords(src, coords)

    TriggerEvent("kartik-mdt:server:sendDispatchNotification", {
        title = data.title or "Alert",
        code = data.code or "10-90",
        description = data.description or "Dispatch alert",
        location = "Unknown",
        sound = "dispatch",
        type = "Alert",
        x = coords.x,
        y = coords.y,
        z = coords.z,
        blip = {
            radius = blip and blip.radius or 0.0,
            sprite = blip and blip.sprite or 161,
            color = blip and blip.colour or 1,
            scale = blip and blip.scale or 1.2,
            length = blip and blip.length or data.length or 5,
        },
        jobs = normalizeJobs(jobs),
    })

    return true
end

return dispatch
