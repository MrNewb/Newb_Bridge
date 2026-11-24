local doorlock = {}

local function setLocked(doorId, locked)
    exports.doors_creator:setDoorState(doorId, locked and 1 or 0)
    return true
end

function doorlock.lockDoor(doorId)
    return setLocked(doorId, true)
end

function doorlock.unlockDoor(doorId)
    return setLocked(doorId, false)
end

return doorlock
