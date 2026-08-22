local target = {}

local core_focus = exports.core_focus

local function getCallingResource()
    return GetInvokingResource() or cache.resource
end

local trackZone = CreateTargetCleanup(function(zoneName)
    core_focus:RemoveZone(zoneName)
end)

local function generateZoneName(kind)
    return ('%s_%s_%s'):format(getCallingResource(), kind, tostring(math.random(11111111, 99999999)))
end

local function toLabelArray(optionNames)
    if type(optionNames) == 'string' then
        return { optionNames }
    end

    return optionNames
end

local function convertOptions(options)
    local converted = {}

    for i = 1, #options do
        local option = options[i]
        local entry = {}

        for key, value in pairs(option) do
            entry[key] = value
        end

        if entry.onSelect and not entry.action then
            entry.action = entry.onSelect
        end

        if entry.groups then
            local jobs = {}

            for _, value in pairs(entry.groups) do
                if type(value) == 'string' then
                    jobs[value] = 0
                else
                    jobs = entry.groups
                    break
                end
            end

            entry.job = jobs
            entry.groups = nil
        end

        if entry.items and not entry.item then
            entry.item = entry.items
            entry.items = nil
        end

        if not entry.label and entry.name then
            entry.label = entry.name
        end

        converted[i] = entry
    end

    return converted
end

local function resolveDistance(options, fallback)
    return options[1] and options[1].distance or fallback or 2.0
end

local function buildTargetParams(options)
    local converted = convertOptions(options)

    return {
        options = converted,
        distance = resolveDistance(converted),
    }
end

function target.removeZone(zoneId)
    core_focus:RemoveZone(zoneId)
end

function target.addBoxZone(payload)
    local options = convertOptions(payload.options)
    local zoneName = payload.name or generateZoneName('box')
    local sizeZ = payload.size.z / 2.0

    core_focus:AddBoxZone(zoneName, payload.coords, payload.size.x, payload.size.y, {
        name = zoneName,
        heading = payload.rotation or 0,
        debugPoly = payload.debug or Config.Debug,
        minZ = payload.coords.z - sizeZ,
        maxZ = payload.coords.z + sizeZ,
    }, {
        options = options,
        distance = resolveDistance(options),
    })

    trackZone(zoneName)
    return zoneName
end

function target.addSphereZone(payload)
    local options = convertOptions(payload.options)
    local zoneName = payload.name or generateZoneName('sphere')

    core_focus:AddSphereZone(zoneName, payload.coords, payload.radius or 1.0, {
        debugPoly = payload.debug or Config.Debug,
    }, {
        options = options,
        distance = resolveDistance(options),
    })

    trackZone(zoneName)
    return zoneName
end

function target.addLocalEntity(entities, options)
    core_focus:AddTargetEntity(entities, buildTargetParams(options))
end

function target.removeLocalEntity(entities, optionNames)
    core_focus:RemoveTargetEntity(entities, toLabelArray(optionNames))
end

function target.addEntity(netIds, options)
    local entities = {}

    if type(netIds) == 'number' then
        entities[1] = NetworkGetEntityFromNetworkId(netIds)
    else
        for i = 1, #netIds do
            entities[i] = NetworkGetEntityFromNetworkId(netIds[i])
        end
    end

    core_focus:AddTargetEntity(entities, buildTargetParams(options))
end

function target.removeEntity(netIds, optionNames)
    local entities = {}

    if type(netIds) == 'number' then
        entities[1] = NetworkGetEntityFromNetworkId(netIds)
    else
        for i = 1, #netIds do
            entities[i] = NetworkGetEntityFromNetworkId(netIds[i])
        end
    end

    core_focus:RemoveTargetEntity(entities, toLabelArray(optionNames))
end

function target.addGlobalPed(options)
    core_focus:AddGlobalPed(buildTargetParams(options))
end

function target.removeGlobalPed(optionNames)
    core_focus:RemoveGlobalPed(toLabelArray(optionNames))
end

function target.addGlobalPlayer(options)
    core_focus:AddGlobalPlayer(buildTargetParams(options))
end

function target.removeGlobalPlayer(optionNames)
    core_focus:RemoveGlobalPlayer(toLabelArray(optionNames))
end

function target.addGlobalVehicle(options)
    core_focus:AddGlobalVehicle(buildTargetParams(options))
end

function target.removeGlobalVehicle(optionNames)
    core_focus:RemoveGlobalVehicle(toLabelArray(optionNames))
end

function target.addModel(models, options)
    core_focus:AddTargetModel(models, buildTargetParams(options))
end

function target.removeModel(models, optionNames)
    core_focus:RemoveTargetModel(models, toLabelArray(optionNames))
end

function target.disableTargeting(disable)
    core_focus:AllowTargeting(not disable)
end

return target
