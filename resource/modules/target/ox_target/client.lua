local target = {}

local ox_target = exports.ox_target

-- ox_target removes any zone registered by a resource when that resource stops,
-- so the bridge does not track zones for cleanup here.

function target.removeZone(zoneId)
    ox_target:removeZone(zoneId)
end

function target.addBoxZone(payload)
    return ox_target:addBoxZone(payload)
end

function target.addSphereZone(payload)
    return ox_target:addSphereZone(payload)
end

function target.addLocalEntity(entities, options)
    return ox_target:addLocalEntity(entities, options)
end

function target.removeLocalEntity(entities, optionNames)
    return ox_target:removeLocalEntity(entities, optionNames)
end

function target.addEntity(netIds, options)
    ox_target:addEntity(netIds, options)
end

function target.removeEntity(netIds, optionNames)
    ox_target:removeEntity(netIds, optionNames)
end

function target.addGlobalPed(options)
    ox_target:addGlobalPed(options)
end

function target.removeGlobalPed(optionNames)
    exports.ox_target:removeGlobalPed(optionNames)
end

function target.addGlobalPlayer(options)
    ox_target:addGlobalPlayer(options)
end

function target.removeGlobalPlayer(optionNames)
    ox_target:removeGlobalPlayer(optionNames)
end

function target.addGlobalVehicle(options)
    ox_target:addGlobalVehicle(options)
end

function target.removeGlobalVehicle(optionNames)
    ox_target:removeGlobalVehicle(optionNames)
end

function target.addModel(models, options)
    ox_target:addModel(models, options)
end

function target.removeModel(models, optionNames)
    ox_target:removeModel(models, optionNames)
end

function target.disableTargeting(disable)
    ox_target:disableTargeting(disable)
end

return target
