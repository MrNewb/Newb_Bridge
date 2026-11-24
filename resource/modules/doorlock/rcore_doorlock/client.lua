local doorlock = {}

function doorlock.getClosestDoor()
    local pedCoords = GetEntityCoords(PlayerPedId())
    local closestId, closestDistance
    for _, door in pairs(exports.rcore_doorlock:getLoadedDoors()) do
        local distance = door.coords and #(pedCoords - door.coords)
        if distance and (not closestDistance or distance < closestDistance) then
            closestId, closestDistance = door.id, distance
        end
    end

    return closestId
end

return doorlock
