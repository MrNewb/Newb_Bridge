-- Client-only module
-- kora_target provider. Registers through kora_target's native API
-- (exports.kora_target:addBoxZone / addEntity / addModel / addGlobalType ...);
-- it does not use the qb-target or ox_target compatibility surfaces.
--
-- The bridge speaks ox_target-style options (name, groups, items, canInteract,
-- onSelect(data), event/serverEvent/command/export). kora_target's native
-- options carry no framework knowledge, so job/gang/item filters become part of
-- canInteract here, using kora_core and the local inventory mirror.
--
-- kora_target removes whole registrations by id, not single options. Every
-- registration made here is recorded per scope (entity, network id, model,
-- global type) so removal by option name can drop the matching options and
-- re-register the rest.

local target = {}

local kt = exports.kora_target
local core = exports.kora_core

local scopes = {} ---@type table<string, table[]> scope key -> registrations { id, options, add, remove, cancelled }
local zonesByName = {} ---@type table<string, number>

local trackZone = CreateTargetCleanup(function(zoneId)
    kt:removeZone(zoneId)
end)

-- Option conversion ---------------------------------------------------------

local function toList(value)
    if value == nil then return {} end
    if type(value) ~= 'table' or value.label ~= nil then return { value } end
    return value
end

local function toNameSet(names)
    local set = {}
    if type(names) == 'string' then
        set[names] = true
    elseif type(names) == 'table' then
        for _, name in ipairs(names) do set[name] = true end
    end
    return set
end

local function gradeLevel(record)
    local grade = record and record.grade
    if type(grade) == 'table' then grade = grade.level end
    grade = tonumber(grade)
    return grade and math.max(grade - 1, 0) or nil
end

-- groups: 'police' | { 'police', 'ambulance' } | { police = 2 } (job or gang name -> min grade, zero-based).
local function passesGroups(groups)
    if not groups then return true end

    local job, gang = core:getJob(), core:getGang()

    local function matches(name, minGrade)
        for _, record in ipairs({ job or false, gang or false }) do
            if record and record.name == name and (gradeLevel(record) or 0) >= (minGrade or 0) then
                return true
            end
        end
        return false
    end

    if type(groups) == 'string' then return matches(groups) end

    for key, value in pairs(groups) do
        if type(key) == 'number' then
            if matches(value) then return true end
        elseif matches(key, tonumber(value)) then
            return true
        end
    end

    return false
end

local function itemCount(name)
    local total = 0
    for _, itemData in pairs(core:getInventory() or {}) do
        if itemData.name == name then total = total + (itemData.count or itemData.amount or 0) end
    end
    return total
end

-- items: 'lockpick' | { 'lockpick', 'phone' } | { lockpick = 2 }; every item is required unless anyItem.
local function passesItems(items, anyItem)
    if not items then return true end

    local required = {}
    if type(items) == 'string' then
        required[items] = 1
    else
        for key, value in pairs(items) do
            if type(key) == 'number' then required[value] = 1 else required[key] = tonumber(value) or 1 end
        end
    end

    for name, count in pairs(required) do
        local has = itemCount(name) >= count
        if anyItem and has then return true end
        if not anyItem and not has then return false end
    end

    return not anyItem
end

local function entityCoords(entity, fallback)
    if fallback then return fallback end
    if entity and entity ~= 0 and DoesEntityExist(entity) then return GetEntityCoords(entity) end
    return GetEntityCoords(cache.ped)
end

local function buildData(option, entity, distance, coords, zoneName)
    return {
        entity = entity,
        coords = entityCoords(entity, coords),
        distance = distance,
        zone = zoneName,
        name = option.name,
        args = option.args,
    }
end

local function splitExport(path)
    local resource, method = tostring(path):match('^([^%.]+)%.(.+)$')
    return resource, method
end

local function selectHandler(option, zoneName, zoneCoords)
    local onSelect = option.onSelect

    if not onSelect and not (option.event or option.serverEvent or option.command or option.export) then
        return function() end
    end

    return function(entity)
        -- For zones kora_target passes the entity the crosshair hit (map geometry,
        -- often far away), so measure to the zone itself.
        local coords = zoneCoords or entityCoords(entity)
        local data = buildData(option, entity, #(GetEntityCoords(cache.ped) - coords), coords, zoneName)

        if onSelect then return onSelect(data) end
        if option.export then
            local resource, method = splitExport(option.export)
            if resource and method then return exports[resource][method](nil, data) end
        elseif option.event then
            return TriggerEvent(option.event, data)
        elseif option.serverEvent then
            -- a client entity handle means nothing on the server: send its network id (0 when not networked)
            local serverData = table.clone(data)
            local entityHandle = data.entity
            serverData.entity = (entityHandle and entityHandle ~= 0 and DoesEntityExist(entityHandle) and NetworkGetEntityIsNetworked(entityHandle))
                and NetworkGetNetworkIdFromEntity(entityHandle) or 0
            return TriggerServerEvent(option.serverEvent, serverData)
        elseif option.command then
            return ExecuteCommand(option.command)
        end
    end
end

local function interactHandler(option, zoneName)
    local userCheck = option.canInteract
    local groups, items, anyItem = option.groups, option.items, option.anyItem

    if not userCheck and not groups and not items then return nil end

    -- kora_target calls canInteract(entity, distance, option.data, anchorCoords).
    return function(entity, distance, _, anchorCoords)
        if groups and not passesGroups(groups) then return false end
        if items and not passesItems(items, anyItem) then return false end
        if not userCheck then return true end

        return userCheck(entity, distance, entityCoords(entity, anchorCoords), option.name, nil) and true or false
    end
end

local function convertOptions(options, zoneName, zoneCoords)
    local converted = {}

    for _, option in ipairs(toList(options)) do
        local icon = option.icon
        -- kora_target icons are names ('Car', 'eye'); Font Awesome classes do not render.
        if type(icon) ~= 'string' or icon:find('^fa[%-s ]') or icon:find('^fa$') then icon = nil end

        local bones = option.bones
        if type(bones) == 'string' then bones = { bones } end

        converted[#converted + 1] = {
            label = option.label,
            icon = icon,
            distance = option.distance,
            bones = bones,
            allowInVehicle = option.allowInVehicle,
            canInteract = interactHandler(option, zoneName),
            onSelect = selectHandler(option, zoneName, zoneCoords),
        }
    end

    return converted
end

-- Scope bookkeeping ---------------------------------------------------------

---@param scope string
---@param options table ox-style option list
---@param add fun(converted: table[]): any registers and returns the kora_target id
---@param remove fun(id: any) removes by that id
local function register(scope, options, add, remove)
    local list = toList(options)
    local entry = { options = list, add = add, remove = remove }

    entry.id = add(convertOptions(list))

    scopes[scope] = scopes[scope] or {}
    scopes[scope][#scopes[scope] + 1] = entry
    return entry
end

local function unregister(scope, optionNames)
    local entries = scopes[scope]
    if not entries then return end

    local names = optionNames and toNameSet(optionNames) or nil
    local kept = {}

    for _, entry in ipairs(entries) do
        local remaining = {}
        if names then
            for _, option in ipairs(entry.options) do
                if not (option.name and names[option.name]) then remaining[#remaining + 1] = option end
            end
        end

        if entry.id ~= nil then entry.remove(entry.id) end

        if #remaining > 0 then
            entry.options = remaining
            entry.id = entry.add(convertOptions(remaining))
            kept[#kept + 1] = entry
        end
    end

    scopes[scope] = #kept > 0 and kept or nil
end

local function toArray(value)
    if type(value) == 'table' then return value end
    return { value }
end

-- Zones ---------------------------------------------------------------------

local function firstCoords(coords)
    if type(coords) == 'table' and coords.x == nil and coords[1] then return coords[1] end
    return coords
end

local function rememberZone(name, id)
    if name then zonesByName[name] = id end
    return trackZone(id)
end

function target.removeZone(zoneId)
    if type(zoneId) == 'string' and zonesByName[zoneId] then
        local id = zonesByName[zoneId]
        zonesByName[zoneId] = nil
        zoneId = id
    end

    kt:removeZone(zoneId)
end

function target.addBoxZone(payload)
    local size = payload.size or vec3(2.0, 2.0, 2.0)

    local id = kt:addBoxZone({
        coords = firstCoords(payload.coords),
        size = size,
        rotation = payload.rotation,
        debug = payload.debug,
        drawSprite = payload.drawSprite,
        options = convertOptions(payload.options, payload.name, firstCoords(payload.coords)),
    })

    return rememberZone(payload.name, id)
end

function target.addSphereZone(payload)
    local id = kt:addSphereZone({
        coords = firstCoords(payload.coords),
        radius = payload.radius or 1.5,
        debug = payload.debug,
        drawSprite = payload.drawSprite,
        options = convertOptions(payload.options, payload.name, firstCoords(payload.coords)),
    })

    return rememberZone(payload.name, id)
end

-- Entities ------------------------------------------------------------------

local function addEntityHandle(scope, entity, options)
    register(scope, options, function(converted)
        return kt:addEntity(entity, converted)
    end, function(id)
        kt:removeEntity(entity, id)
    end)
end

function target.addLocalEntity(entities, options)
    for _, entity in ipairs(toArray(entities)) do
        addEntityHandle(('entity:%s'):format(entity), entity, options)
    end
end

function target.removeLocalEntity(entities, optionNames)
    for _, entity in ipairs(toArray(entities)) do
        unregister(('entity:%s'):format(entity), optionNames)
    end
end

-- A network id may not be streamed in yet, so wait for it (up to 10 s).
function target.addEntity(netIds, options)
    for _, netId in ipairs(toArray(netIds)) do
        local scope = ('net:%s'):format(netId)

        CreateThread(function()
            local waited = 0
            local entity = 0

            while waited < 10000 do
                if NetworkDoesNetworkIdExist(netId) then
                    entity = NetworkGetEntityFromNetworkId(netId)
                    if entity ~= 0 and DoesEntityExist(entity) then break end
                end
                Wait(250)
                waited = waited + 250
            end

            if entity == 0 or not DoesEntityExist(entity) then return end
            addEntityHandle(scope, entity, options)
        end)
    end
end

function target.removeEntity(netIds, optionNames)
    for _, netId in ipairs(toArray(netIds)) do
        unregister(('net:%s'):format(netId), optionNames)
    end
end

-- Models --------------------------------------------------------------------

local function modelHash(model)
    if type(model) == 'string' then return joaat(model) end
    return model
end

function target.addModel(models, options)
    for _, model in ipairs(toArray(models)) do
        local hash = modelHash(model)

        register(('model:%s'):format(hash), options, function(converted)
            return kt:addModel(hash, converted)
        end, function(id)
            kt:removeModel(hash, id)
        end)
    end
end

function target.removeModel(models, optionNames)
    for _, model in ipairs(toArray(models)) do
        unregister(('model:%s'):format(modelHash(model)), optionNames)
    end
end

-- Global types --------------------------------------------------------------

local function addGlobal(entityType, options)
    register('global:' .. entityType, options, function(converted)
        return kt:addGlobalType(entityType, converted)
    end, function(id)
        kt:removeGlobalType(entityType, id)
    end)
end

function target.addGlobalPed(options) addGlobal('ped', options) end
function target.removeGlobalPed(optionNames) unregister('global:ped', optionNames) end
function target.addGlobalPlayer(options) addGlobal('player', options) end
function target.removeGlobalPlayer(optionNames) unregister('global:player', optionNames) end
function target.addGlobalVehicle(options) addGlobal('vehicle', options) end
function target.removeGlobalVehicle(optionNames) unregister('global:vehicle', optionNames) end

function target.disableTargeting(disable)
    kt:setEnabled(not disable)
end

return target
