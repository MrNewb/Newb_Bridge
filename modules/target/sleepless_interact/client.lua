local target = {}

local sleepless_interact = exports.sleepless_interact

-- sleepless_interact removes interactions registered by a resource when that
-- resource stops, so the bridge does not track zones for cleanup here.

function target.removeZone(zoneId)
    sleepless_interact:removeCoords(zoneId)
end

function target.addBoxZone(payload)
    return sleepless_interact:addCoords(payload.coords, payload.options)
end

function target.addSphereZone(payload)
    return sleepless_interact:addCoords(payload.coords, payload.options)
end

function target.addLocalEntity(entities, options)
    sleepless_interact:addLocalEntity(entities, options)
end

function target.removeLocalEntity(entities, optionNames)
    sleepless_interact:removeLocalEntity(entities, optionNames)
end

function target.addEntity(netIds, options)
    sleepless_interact:addEntity(netIds, options)
end

function target.removeEntity(netIds, optionNames)
    sleepless_interact:removeEntity(netIds, optionNames)
end

function target.addGlobalPed(options)
    sleepless_interact:addGlobalPed(options)
end

function target.removeGlobalPed(optionNames)
    sleepless_interact:removeGlobalPed(optionNames)
end

function target.addGlobalPlayer(options)
    sleepless_interact:addGlobalPlayer(options)
end

function target.removeGlobalPlayer(optionNames)
    sleepless_interact:removeGlobalPlayer(optionNames)
end

function target.addGlobalVehicle(options)
    sleepless_interact:addGlobalVehicle(options)
end

function target.removeGlobalVehicle(optionNames)
    sleepless_interact:removeGlobalVehicle(optionNames)
end

function target.addModel(models, options)
    sleepless_interact:addModel(models, options)
end

function target.removeModel(models, optionNames)
    sleepless_interact:removeModel(models, optionNames)
end

function target.disableTargeting(disable)
    sleepless_interact:disableInteract(disable)
end

return target
