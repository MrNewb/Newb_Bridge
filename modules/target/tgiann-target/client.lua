local target = {}

local tgiann_target = exports['tgiann-target']

local trackTarget = CreateTargetCleanup(function(targetId)
    tgiann_target:removeZone(targetId)
end)

function target.removeZone(zoneId)
    tgiann_target:removeZone(zoneId)
end

function target.addBoxZone(payload)
    return trackTarget(tgiann_target:addBoxZone(payload))
end

function target.addSphereZone(payload)
    return trackTarget(tgiann_target:addSphereZone(payload))
end

function target.addLocalEntity(entities, options)
    return tgiann_target:addLocalEntity(entities, options)
end

function target.removeLocalEntity(entities, optionNames)
    return tgiann_target:removeLocalEntity(entities, optionNames)
end

function target.addEntity(netIds, options)
    tgiann_target:addEntity(netIds, options)
end

function target.removeEntity(netIds, optionNames)
    tgiann_target:removeEntity(netIds, optionNames)
end

function target.addGlobalPed(options)
    tgiann_target:addGlobalPed(options)
end

function target.removeGlobalPed(optionNames)
    tgiann_target:removeGlobalPed(optionNames)
end

function target.addGlobalPlayer(options)
    tgiann_target:addGlobalPlayer(options)
end

function target.removeGlobalPlayer(optionNames)
    tgiann_target:removeGlobalPlayer(optionNames)
end

function target.addGlobalVehicle(options)
    tgiann_target:addGlobalVehicle(options)
end

function target.removeGlobalVehicle(optionNames)
    tgiann_target:removeGlobalVehicle(optionNames)
end

function target.addModel(models, options)
    tgiann_target:addModel(models, options)
end

function target.removeModel(models, optionNames)
    tgiann_target:removeModel(models, optionNames)
end

function target.disableTargeting(disable)
    tgiann_target:disableTargeting(disable)
end

return target
