local doorlock = {}

local function setLocked(doorId, locked)
    TriggerClientEvent('qb-doorlock:client:setState', -1, 0, doorId, locked, false, false, false)
    return true
end

function doorlock.lockDoor(doorId)
    return setLocked(doorId, true)
end

function doorlock.unlockDoor(doorId)
    return setLocked(doorId, false)
end

return doorlock
