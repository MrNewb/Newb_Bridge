local target = {}

local namesToLabels = {} ---@type table<string, string>

local qb_target = exports["qb-target"]

local trackZone = CreateTargetCleanup(function(zoneName)
    qb_target:RemoveZone(zoneName)
end)

local function generateUUID()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return template:gsub("[xy]", function(c)
        local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
        return string.format("%x", v)
    end)
end

local function split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        t[#t + 1] = str
    end
    return t
end

local function convertToArray(data)
    if type(data) ~= "table" then
        return { data }
    end

    ---@diagnostic disable-next-line: param-type-mismatch
    local key, value = next(data)

    if type(key) == "string" then -- its key value table then
        local arr = {}
        for k, v in pairs(data) do
            arr[#arr + 1] = k
        end
        return arr
    else
        return data
    end
end

local function convertOptionsFromOxTarget(payload)
    local options = {}
    local function formatQbOption(zone, o)
        local option = {
            type = o.event and "client" or o.serverEvent and "server" or o.export and "export" or "client",
            event = o.event or o.serverEvent,
            icon = o.icon,
            item = o.items,
            label = o.label
        }

        if o.canInteract then
            option.canInteract = o.canInteract
        end

        if o.onSelect then
            option.action = function(entity)
                local coords = zone.coords
                if entity and DoesEntityExist(entity) then
                    coords = GetEntityCoords(entity)
                end
                if not coords then
                    coords = GetEntityCoords(cache.ped)
                end

                local distance = #(GetEntityCoords(cache.ped) - coords)

                o.onSelect({
                    entity = entity,
                    coords = coords,
                    distance = distance,
                    zone = zone.name,
                })
            end
        end

        if not o.onSelect and o.export then
            option.action = function(entity)
                local coords = zone.coords
                if entity and DoesEntityExist(entity) then
                    coords = GetEntityCoords(entity)
                end
                if not coords then
                    coords = GetEntityCoords(cache.ped)
                end

                local distance = #(GetEntityCoords(cache.ped) - coords)
                local exportInfo = split(o.export, ".")
                local exportResource = exportInfo[1]
                local exportFunction = exportInfo[2]
                exports[exportResource][exportFunction](nil, {
                    entity = entity,
                    coords = coords,
                    distance = distance,
                    zone = zone.name,
                }
                )
            end
        end

        return option
    end

    for i = 1, #payload.options do
        local o = payload.options[i]

        namesToLabels[o.name] = o.label

        if o.groups then
            local jobs = convertToArray(o.groups)

            for j = 1, #jobs do
                local jobName = jobs[j]
                local index = #options + 1
                options[index] = formatQbOption(payload, o)
                options[index].job = jobName
            end
        else
            options[#options + 1] = formatQbOption(payload, o)
        end
    end

    return options
end

function target.removeZone(zoneId)
    qb_target:RemoveZone(zoneId)
end

function target.addBoxZone(payload)
    local sizeZ = payload.size.z / 2.0
    local minZ, maxZ = (payload.coords.z - sizeZ), (payload.coords.z + sizeZ)

    local options = convertOptionsFromOxTarget(payload)

    qb_target:AddBoxZone(payload.name, payload.coords, payload.size.x, payload.size.y, {
        name = payload.name,
        heading = payload.rotation or 0,
        debugPoly = payload.debug,
        minZ = minZ,
        maxZ = maxZ,
    }, {
        options = options,
        distance = 2.5
    })

    trackZone(payload.name)
    return payload.name
end

function target.addSphereZone(payload)
    local size = payload.radius / 2.0
    local minZ, maxZ = (payload.coords.z - size), (payload.coords.z + size)

    local options = convertOptionsFromOxTarget(payload)

    qb_target:AddBoxZone(payload.name, payload.coords, size, size, {
        name = payload.name,
        heading = 0,
        debugPoly = payload.debug,
        minZ = minZ,
        maxZ = maxZ,
    }, {
        options = options,
        distance = 2.5
    })

    trackZone(payload.name)
    return payload.name
end

function target.addLocalEntity(entities, options)
    local op = convertOptionsFromOxTarget({
        name = generateUUID(),
        options = options,
    })

    qb_target:AddTargetEntity(entities, {
        options = op,
        distance = 2.5
    })
end

function target.removeLocalEntity(entities, optionNames)
    local labels = {}
    if type(optionNames) == "string" then
        if namesToLabels[optionNames] then
            labels[#labels + 1] = namesToLabels[optionNames]
        end
    else
        for i = 1, #optionNames do
            if namesToLabels[optionNames[i]] then
                labels[#labels + 1] = namesToLabels[optionNames[i]]
            end
        end
    end

    if #labels == 0 then return end

    qb_target:RemoveTargetEntity(entities, labels)
end

function target.addEntity(netIds, options)
    local entities = {}
    if type(netIds) ~= "table" then
        entities[1] = NetworkGetEntityFromNetworkId(netIds)
    else
        for i = 1, #netIds do
            entities[i] = NetworkGetEntityFromNetworkId(netIds[i])
        end
    end

    local op = convertOptionsFromOxTarget({
        name = generateUUID(),
        options = options,
    })

    qb_target:AddTargetEntity(entities, {
        options = op,
        distance = 2.5
    })
end

function target.removeEntity(netIds, optionNames)
    local entities = {}
    if type(netIds) ~= "table" then
        entities[1] = NetworkGetEntityFromNetworkId(netIds)
    else
        for i = 1, #netIds do
            entities[i] = NetworkGetEntityFromNetworkId(netIds[i])
        end
    end

    local labels = {}
    if type(optionNames) == "string" then
        if namesToLabels[optionNames] then
            labels[#labels + 1] = namesToLabels[optionNames]
        end
    else
        for i = 1, #optionNames do
            if namesToLabels[optionNames[i]] then
                labels[#labels + 1] = namesToLabels[optionNames[i]]
            end
        end
    end

    if #labels == 0 then return end

    qb_target:RemoveTargetEntity(entities, labels)
end

function target.addGlobalPed(options)
    local op = convertOptionsFromOxTarget({
        name = generateUUID(),
        options = options,
    })

    qb_target:AddGlobalPed({
        options = op,
        distance = 2.5
    })
end

function target.removeGlobalPed(optionNames)
    local labels = {}
    if type(optionNames) == "string" then
        if namesToLabels[optionNames] then
            labels[#labels + 1] = namesToLabels[optionNames]
        end
    else
        for i = 1, #optionNames do
            if namesToLabels[optionNames[i]] then
                labels[#labels + 1] = namesToLabels[optionNames[i]]
            end
        end
    end

    if #labels == 0 then return end

    qb_target:RemoveGlobalPed(labels)
end

function target.addGlobalPlayer(options)
    local op = convertOptionsFromOxTarget({
        name = generateUUID(),
        options = options,
    })

    qb_target:AddGlobalPlayer({
        options = op,
        distance = 2.5
    })
end

function target.removeGlobalPlayer(optionNames)
    local labels = {}
    if type(optionNames) == "string" then
        if namesToLabels[optionNames] then
            labels[#labels + 1] = namesToLabels[optionNames]
        end
    else
        for i = 1, #optionNames do
            if namesToLabels[optionNames[i]] then
                labels[#labels + 1] = namesToLabels[optionNames[i]]
            end
        end
    end

    if #labels == 0 then return end

    qb_target:RemoveGlobalPlayer(labels)
end

function target.addGlobalVehicle(options)
    local op = convertOptionsFromOxTarget({
        name = generateUUID(),
        options = options,
    })

    qb_target:AddGlobalVehicle({
        options = op,
        distance = 2.5
    })
end

function target.removeGlobalVehicle(optionNames)
    local labels = {}
    if type(optionNames) == "string" then
        if namesToLabels[optionNames] then
            labels[#labels + 1] = namesToLabels[optionNames]
        end
    else
        for i = 1, #optionNames do
            if namesToLabels[optionNames[i]] then
                labels[#labels + 1] = namesToLabels[optionNames[i]]
            end
        end
    end

    if #labels == 0 then return end

    qb_target:RemoveGlobalVehicle(labels)
end

function target.addModel(models, options)
    local op = convertOptionsFromOxTarget({
        name = generateUUID(),
        options = options,
    })

    qb_target:AddTargetModel(models, {
        options = op,
        distance = 2.5,
    })
end

function target.removeModel(models, optionNames)
    local labels = {}
    if type(optionNames) == "string" then
        if namesToLabels[optionNames] then
            labels[#labels + 1] = namesToLabels[optionNames]
        end
    else
        for i = 1, #optionNames do
            if namesToLabels[optionNames[i]] then
                labels[#labels + 1] = namesToLabels[optionNames[i]]
            end
        end
    end

    if #labels == 0 then return end

    qb_target:RemoveTargetModel(models, labels)
end

function target.disableTargeting(disable)
    qb_target:AllowTargeting(not disable)
end

return target
