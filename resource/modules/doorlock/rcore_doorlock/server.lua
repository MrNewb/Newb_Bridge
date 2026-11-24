local doorlock = {}

-- rcore_doorlock states: 0 is locked, 1 is unlocked.
local function setLocked(doorId, locked)
    exports.rcore_doorlock:changeDoorState(doorId, locked and 0 or 1)
    return true
end

function doorlock.lockDoor(doorId)
    return setLocked(doorId, true)
end

function doorlock.unlockDoor(doorId)
    return setLocked(doorId, false)
end

return doorlock
