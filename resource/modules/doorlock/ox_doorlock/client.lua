local doorlock = {}

function doorlock.getClosestDoor()
    local door = exports.ox_doorlock:getClosestDoor()
    return door and tostring(door.id)
end

return doorlock
