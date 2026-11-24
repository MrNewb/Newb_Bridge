local doorlock = {}

function doorlock.getClosestDoor()
    return exports.doors_creator:getClosestActiveDoor()
end

return doorlock
