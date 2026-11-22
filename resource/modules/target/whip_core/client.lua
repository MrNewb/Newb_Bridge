-- Client-only module
-- whip_core target provider. Whip has no separate target resource: a world prompt, an aim option and an entity prompt
-- are all one AddAction. The bridge speaks ox_target-style options (name, groups, items, anyItem, canInteract,
-- onSelect(data), event/serverEvent/command/export), so every call here becomes one whip action whose options are the
-- bridge options.
--
-- Differences worth knowing:
--  * Whip draws a prompt at a point or on an entity and the player presses E; it is not an eye cursor. Zones become a
--    prompt at the zone's coords, reachable within the zone's radius (or half its box).
--  * `groups` keep the job names only: whip's job roles are not numbered the way grades are.
--  * Models must be given by name; whip refuses a hash.
--  * Whip drops a resource's actions when it stops, and forgets them all if whip_core restarts, so the definitions are
--    kept here and declared again when whip_core says it started.

local target = {}

local whip = exports.whip_core

local GLYPHS = {}
for _, name in ipairs({
    'lock', 'unlock', 'lockpick', 'door', 'hood_closed', 'hood_open', 'trunk_closed', 'trunk_open', 'trunk_lid',
    'garage', 'car', 'store', 'turbo', 'furnish', 'house', 'pickup', 'bank', 'deposit', 'withdraw', 'back', 'fuel',
    'nozzle', 'cash', 'talk', 'phone', 'bag', 'emote', 'id', 'power', 'headlights', 'seat', 'devtools', 'place', 'give',
    'eat', 'respawn', 'objective', 'timer', 'house_door', 'target', 'pin', 'star', 'fail', 'success', 'info', 'warning',
    'object', 'ped', 'camera',
}) do
    GLYPHS[name] = true
end

local DEFAULT_ICON = 'target'
local DEFAULT_REACH = 2.0

local actions = {} ---@type table<string, table> action id -> the definition handed to AddAction
local scopes = {} ---@type table<string, { id: string, options: table[], at: table, extraCheck: (fun(ctx: table): boolean)|nil }> scope key -> registration
local nextId = 0
local disabled = false

local function toList(value)
    if value == nil then return {} end
    if type(value) ~= 'table' or value.label ~= nil then return { value } end
    return value
end

local function toArray(value)
    if type(value) == 'table' then return value end
    return { value }
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

local function newId(prefix)
    nextId = nextId + 1
    return ('%s:%d'):format(prefix, nextId)
end

local function declare(id, def)
    def.id = id
    actions[id] = def

    local ok, reason = whip:AddAction(def)
    if not ok then
        lib.print.warn(('Whip refused target action "%s": %s'):format(id, tostring(reason)))
    end
end

local function withdraw(id)
    actions[id] = nil
    whip:RemoveAction(id)
end

-- Requirements ---------------------------------------------------------------

---groups: 'police' | { 'police', 'ambulance' } | { police = 2 }; the job names, any one of them.
local function jobNames(groups)
    if type(groups) == 'string' then return { groups } end

    local jobs = {}
    for key, value in pairs(groups) do
        jobs[#jobs + 1] = type(key) == 'number' and value or key
    end
    return jobs
end

---items: 'lockpick' | { 'lockpick', 'phone' } | { lockpick = 2 }; as whip's `require.item` list.
local function requiredItems(items)
    if type(items) == 'string' then return { items } end

    local list = {}
    for key, value in pairs(items) do
        if type(key) == 'number' then
            list[#list + 1] = value
        else
            list[#list + 1] = { item = key, count = tonumber(value) or 1 }
        end
    end
    return list
end

---Whip's `require.item` needs every item, so "any of these" is a check of its own.
local function carriesAny(items)
    for _, entry in ipairs(requiredItems(items)) do
        local name, count = entry, 1
        if type(entry) == 'table' then name, count = entry.item, entry.count end
        if whip:HasItem(name, count) then return true end
    end
    return false
end

-- Option conversion ----------------------------------------------------------

local function splitExport(path)
    local resource, method = tostring(path):match('^([^%.]+)%.(.+)$')
    return resource, method
end

local function buildData(option, ctx, zoneName)
    local coords = ctx.coords or (ctx.entity and DoesEntityExist(ctx.entity) and GetEntityCoords(ctx.entity)) or GetEntityCoords(cache.ped)

    return {
        entity = ctx.entity,
        coords = coords,
        distance = #(GetEntityCoords(cache.ped) - coords),
        zone = zoneName,
        name = option.name,
        args = option.args,
    }
end

local function selectHandler(option, zoneName)
    local onSelect = option.onSelect

    if not onSelect and not (option.event or option.serverEvent or option.command or option.export) then
        return function() end
    end

    return function(ctx)
        local data = buildData(option, ctx, zoneName)

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

local function interactHandler(option, zoneName, extraCheck)
    local userCheck = option.canInteract
    local anyItem = option.anyItem and option.items

    return function(ctx)
        if disabled then return false end
        if extraCheck and not extraCheck(ctx) then return false end
        if anyItem and not carriesAny(anyItem) then return false end
        if not userCheck then return true end

        local data = buildData(option, ctx, zoneName)
        return userCheck(ctx.entity, data.distance, data.coords, option.name, nil) and true or false
    end
end

local function convertOption(option, zoneName, extraCheck)
    local require = {}
    if option.groups then require.job = jobNames(option.groups) end
    if option.items and not option.anyItem then require.item = requiredItems(option.items) end

    local icon = type(option.icon) == 'string' and GLYPHS[option.icon] and option.icon or DEFAULT_ICON

    return {
        id = option.name,
        label = option.label,
        icon = icon,
        require = next(require) and require or nil,
        canInteract = interactHandler(option, zoneName, extraCheck),
        onSelect = selectHandler(option, zoneName),
    }
end

local function convertOptions(options, zoneName, extraCheck)
    local converted = {}
    for _, option in ipairs(toList(options)) do
        converted[#converted + 1] = convertOption(option, zoneName, extraCheck)
    end
    return converted
end

local function reachOf(options, base)
    local reach = base or DEFAULT_REACH
    for _, option in ipairs(toList(options)) do
        if tonumber(option.distance) and option.distance > reach then reach = option.distance end
    end
    return reach
end

local function actionFor(at, options, zoneName, base, extraCheck)
    local converted = convertOptions(options, zoneName, extraCheck)
    return {
        at = at,
        label = converted[1] and converted[1].label or ' ',
        icon = DEFAULT_ICON,
        options = converted,
        reach = reachOf(options, base),
        group = 'Newb_Bridge:target',
    }
end

-- Scope bookkeeping ----------------------------------------------------------

---@param scope string
---@param at table whip's `at`
---@param options table ox-style option list
local function register(scope, at, options, extraCheck)
    local list = toList(options)

    local existing = scopes[scope]
    local id = existing and existing.id or newId(scope)
    local all = existing and existing.options or {}
    for _, option in ipairs(list) do all[#all + 1] = option end

    scopes[scope] = { id = id, options = all, at = at, extraCheck = extraCheck }
    declare(id, actionFor(at, all, nil, nil, extraCheck))
end

local function unregister(scope, optionNames)
    local entry = scopes[scope]
    if not entry then return end

    local names = optionNames and toNameSet(optionNames) or nil
    local remaining = {}
    if names then
        for _, option in ipairs(entry.options) do
            if not (option.name and names[option.name]) then remaining[#remaining + 1] = option end
        end
    end

    if #remaining == 0 then
        withdraw(entry.id)
        scopes[scope] = nil
        return
    end

    entry.options = remaining
    declare(entry.id, actionFor(entry.at, remaining, nil, nil, entry.extraCheck))
end

-- Zones ----------------------------------------------------------------------

local zonesByName = {} ---@type table<string, string>

local function firstCoords(coords)
    if type(coords) == 'table' and coords.x == nil and coords[1] then return coords[1] end
    return coords
end

local function addZone(payload, radius)
    local coords = firstCoords(payload.coords)
    local id = payload.name and ('zone:' .. payload.name) or newId('zone')

    declare(id, actionFor({ coords = vec3(coords.x, coords.y, coords.z) }, payload.options, payload.name, radius))

    if payload.name then zonesByName[payload.name] = id end
    return id
end

function target.removeZone(zoneId)
    if type(zoneId) == 'string' and zonesByName[zoneId] then
        local id = zonesByName[zoneId]
        zonesByName[zoneId] = nil
        zoneId = id
    end

    if zoneId ~= nil then withdraw(zoneId) end
end

function target.addBoxZone(payload)
    local size = payload.size or vec3(2.0, 2.0, 2.0)
    return addZone(payload, math.max(size.x, size.y) / 2 + 0.5)
end

function target.addSphereZone(payload)
    return addZone(payload, payload.radius or 1.5)
end

-- Entities -------------------------------------------------------------------

function target.addLocalEntity(entities, options)
    for _, entity in ipairs(toArray(entities)) do
        register(('entity:%s'):format(entity), { entity = entity }, options)
    end
end

function target.removeLocalEntity(entities, optionNames)
    for _, entity in ipairs(toArray(entities)) do
        unregister(('entity:%s'):format(entity), optionNames)
    end
end

function target.addEntity(netIds, options)
    for _, netId in ipairs(toArray(netIds)) do
        register(('net:%s'):format(netId), { netId = netId }, options)
    end
end

function target.removeEntity(netIds, optionNames)
    for _, netId in ipairs(toArray(netIds)) do
        unregister(('net:%s'):format(netId), optionNames)
    end
end

-- Models ---------------------------------------------------------------------

function target.addModel(models, options)
    for _, model in ipairs(toArray(models)) do
        if type(model) == 'string' then
            register(('model:%s'):format(model), { model = model }, options)
        else
            lib.print.warn('Whip needs a model name for a target, not a hash; skipped.')
        end
    end
end

function target.removeModel(models, optionNames)
    for _, model in ipairs(toArray(models)) do
        if type(model) == 'string' then unregister(('model:%s'):format(model), optionNames) end
    end
end

-- Global types ---------------------------------------------------------------

local function isPlayerCtx(ctx)
    return ctx.player ~= nil
end

local function isNotPlayerCtx(ctx)
    return ctx.player == nil
end

function target.addGlobalPed(options) register('global:ped', { aimBox = 'ped' }, options, isNotPlayerCtx) end
function target.removeGlobalPed(optionNames) unregister('global:ped', optionNames) end
function target.addGlobalPlayer(options) register('global:player', { aimBox = 'ped' }, options, isPlayerCtx) end
function target.removeGlobalPlayer(optionNames) unregister('global:player', optionNames) end
function target.addGlobalVehicle(options) register('global:vehicle', { aimBox = 'vehicle' }, options) end
function target.removeGlobalVehicle(optionNames) unregister('global:vehicle', optionNames) end

function target.disableTargeting(disable)
    disabled = disable == true
end

-- Whip forgets every action when whip_core restarts and tells each resource when it is ready again.
AddEventHandler('whip_core:onReady', function(info)
    if type(info) ~= 'table' or info.reason ~= 'coreStarted' then return end

    for _, def in pairs(actions) do
        whip:AddAction(def)
    end
end)

return target
