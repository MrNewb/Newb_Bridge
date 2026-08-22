local dispatch = {}

local lastAlertKey = nil
local lastAlertAt = 0

local function normalizeCoords(coords)
    if not coords then return end

    if type(coords) == 'vector3' then return coords end

    if type(coords) == 'table' and coords.x and coords.y and coords.z then
        return vector3(coords.x, coords.y, coords.z)
    end

    return coords
end

local function lengthToMs(length, defaultSec, maxSec)
    local sec = tonumber(length) or defaultSec
    sec = math.min(math.max(sec, 1), maxSec)
    return sec * 1000
end

local function showBlip(coords, payload)
    if not coords then return end

    local blipData = payload.blip or {}
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite(blip, blipData.sprite or 1)
    SetBlipColour(blip, blipData.colour or 3)
    SetBlipScale(blip, blipData.scale or 0.8)
    SetBlipAsShortRange(blip, true)
    SetBlipFlashes(blip, blipData.flash or payload.flash or false)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(blipData.text or payload.title or 'Dispatch')
    EndTextCommandSetBlipName(blip)

    if blipData.radius and blipData.radius > 0 then SetBlipAlpha(blip, 120) end

    CreateThread(function()
        local duration = lengthToMs(blipData.length or payload.length, 30, 90)
        Wait(duration)
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end)

    return blip
end

local function handleInternalAlert(payload)
    if not payload then return end

    local coords = normalizeCoords(payload.coords)
    if not coords then return end

    local alertKey = ('%s:%.0f:%.0f:%.0f'):format(
        payload.title or 'dispatch',
        coords.x,
        coords.y,
        coords.z
    )
    local now = GetGameTimer()
    if lastAlertKey == alertKey and (now - lastAlertAt) < 1500 then
        return
    end
    lastAlertKey = alertKey
    lastAlertAt = now

    showBlip(coords, payload)

    local notifyData = {
        title = payload.title or 'Dispatch Alert',
        description = payload.description or '',
        duration = lengthToMs(payload.length, 8, 15),
        type = 'warning',
        position = 'top-right',
        icon = payload.icon or 'bell',
    }

    if bridge and bridge.notifications and bridge.notifications.notify then
        bridge.notifications.notify(notifyData)
    end
end

-- Only the bridge host registers client net handlers (consumers get a noop module).
if bridge and bridge.isHost then
    RegisterNetEvent("Newb_Bridge:dispatch:internalAlert", function(payload)
        if source ~= 65535 then return end
        handleInternalAlert(payload)
    end)
end

return dispatch
