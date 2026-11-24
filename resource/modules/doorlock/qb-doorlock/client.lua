local doorlock = {}

function doorlock.getClosestDoor()
    local closest = exports['qb-doorlock']:GetClosestDoor()
    if type(closest) == 'table' and next(closest) then return closest end

    local pedCoords = GetEntityCoords(PlayerPedId())
    local closestId, closestDistance
    for doorId, door in pairs(exports['qb-doorlock']:GetDoorList()) do
        local distance = door.objCoords and #(pedCoords - door.objCoords)
        if distance and (not closestDistance or distance < closestDistance) then
            closestId, closestDistance = doorId, distance
        end
    end

    return closestId
end

return doorlock
