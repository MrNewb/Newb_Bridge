local doorlock = {}

local function setLocked(doorId, locked)
    exports.ox_doorlock:setDoorState(tonumber(doorId), locked and 1 or 0)
    return true
end

function doorlock.lockDoor(doorId)
    return setLocked(doorId, true)
end

function doorlock.unlockDoor(doorId)
    return setLocked(doorId, false)
end

return doorlock
