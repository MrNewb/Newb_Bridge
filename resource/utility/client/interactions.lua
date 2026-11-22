---@class InteractionPayload
---@field model number | string ped or prop model hash or name
---@field coords vector3
---@field heading number
---@field radius number
---@field options? table
---@field component? table ped only
---@field anim? table ped only
---@field scenario? string ped only
---@field weapon? number ped only
---@field invincible? boolean ped only, defaults to true
---@field snapToGround? boolean props only
---@field rotation? table props only - pitch/roll/yaw from gizmo placement
---@field matrix? table props only - full entity matrix from gizmo placement
---@field onSpawn? function called after entity spawns and options are registered, receives self (client-only)
---@field onDespawn? function called before entity is deleted, receives self (client-only)
---@field onEnter? function called when the player enters the radius, return false to skip spawning (client-only)
---@field canSpawn? function lightweight spawn gate checked while in range; return false to skip/despawn (client-only)
---@field bucket? number|string Routing bucket id (0 = default world). Prop/ped only spawns when the local player is in this bucket.

---@class Interaction: InteractionPayload
---@field point InteractionPointRuntime
---@field entity? number spawned entity handle (client-only)
---@field interactionId string
---@field resource string

---@type table<string, Interaction>
local interactions = {}

local points = assert(_G.InteractionPointManager, 'Newb_Bridge: interaction_points.lua must load before interactions.lua')

local function toVector3(coords)
    if not coords then return end

    local valueType = type(coords)
    if valueType == 'vector3' then return coords end
    if valueType == 'vector4' then return vec3(coords.x, coords.y, coords.z) end
    if valueType == 'vector2' then return vec3(coords.x, coords.y, 0.0) end
    if valueType == 'table' then
        return vec3(coords.x or coords[1] or 0.0, coords.y or coords[2] or 0.0, coords.z or coords[3] or 0.0)
    end
end

local function isAxis(axis)
    local axisType = type(axis)
    return axisType == 'table' or axisType == 'vector3' or axisType == 'vector4'
end

local function readMatrixAxis(axis)
    if not isAxis(axis) then return end

    local x = axis.x or axis[1]
    local y = axis.y or axis[2]
    local z = axis.z or axis[3]
    if x == nil or y == nil or z == nil then return end

    return x + 0.0, y + 0.0, z + 0.0
end

local function readMatrixPosition(matrix)
    if type(matrix) ~= 'table' or not isAxis(matrix.at) then return end
    return readMatrixAxis(matrix.at)
end

local function applyPropMatrix(entity, matrix)
    if type(matrix) ~= 'table' or not isAxis(matrix.at) then return false end

    local fx, fy, fz = readMatrixAxis(matrix.forward)
    local rx, ry, rz = readMatrixAxis(matrix.right)
    local ux, uy, uz = readMatrixAxis(matrix.up)
    local ax, ay, az = readMatrixAxis(matrix.at)
    if not ax or not fx or not rx or not ux then return false end

    SetEntityMatrix(entity, fx, fy, fz, rx, ry, rz, ux, uy, uz, ax, ay, az)
    SetEntityCollision(entity, true, true)
    return true
end

local function optionNames(interactionId, options)
    local names = {}

    if not options then return names end

    for index = 1, #options do
        names[#names + 1] = ('%s_%s'):format(interactionId, index)
    end

    return names
end

local function buildOptions(interactionId, entity, options)
    local built = {}

    for index, option in ipairs(options) do
        local opt = {}
        for key, value in pairs(option) do
            opt[key] = value
        end

        opt.name = ('%s_%s'):format(interactionId, index)

        if opt.onSelect then
            local callback = opt.onSelect
            opt.onSelect = function(data)
                if type(data) ~= 'table' then
                    data = {}
                end
                data.entity = entity
                data.interactionId = interactionId
                return callback(data)
            end
        end

        built[#built + 1] = opt
    end

    return built
end

local function removeOptions(interactionId, entity, options)
    if not options or #options == 0 then return end

    bridge.target.removeLocalEntity(entity, optionNames(interactionId, options))
end

local function addOptions(interactionId, entity, options)
    if not options or #options == 0 then return end

    bridge.target.addLocalEntity(entity, buildOptions(interactionId, entity, options))
end

local function canEnter(self)
    local payload = interactions[self.interactionId]
    if not payload then return false end
    if payload.canSpawn and payload.canSpawn(self) == false then return false end
    if payload.onEnter and payload.onEnter(self) == false then return false end
    return true
end

-- only canSpawn re-runs on the tick; onEnter stays enter-only so consumer
-- side effects don't fire every 500ms
local function canStay(self)
    local payload = interactions[self.interactionId]
    if not payload then return false end
    if payload.canSpawn and payload.canSpawn(self) == false then return false end
    return true
end

local function playAnim(ped, anim, interactionId)
    if not DoesAnimDictExist(anim.animDict) then
        lib.print.debug('Interaction invalid animDict:', interactionId, anim.animDict)
        return
    end

    ClearPedTasks(ped)
    lib.requestAnimDict(anim.animDict)
    TaskPlayAnim(
        ped, anim.animDict, anim.anim,
        anim.blendIn or 8.0, anim.blendOut or 8.0, anim.duration or -1,
        anim.flag or 1, anim.playback or 0,
        anim.lockX or false, anim.lockY or false, anim.lockZ or false
    )
    RemoveAnimDict(anim.animDict)
end

local function startScenario(ped, scenario, x, y, z, heading)
    ClearPedTasks(ped)
    TaskStartScenarioAtPosition(ped, scenario, x, y, z, heading, -1, false, true)
end

local function spawnPed(self, payload, model)
    local x, y, z = payload.coords.x, payload.coords.y, payload.coords.z
    local heading = payload.heading or payload.coords.w or 0.0

    self.entity = CreatePed(5, model, x, y, z, heading, false, false)
    if not self.entity or self.entity == 0 or not DoesEntityExist(self.entity) then
        self.entity = nil
        return false
    end

    -- CreatePed treats z as a feet hint and floats the ped; placements store origin coords
    SetEntityCoordsNoOffset(self.entity, x, y, z, false, false, false)
    SetEntityHeading(self.entity, heading)
    SetEntityAsMissionEntity(self.entity, true, true)
    FreezeEntityPosition(self.entity, true)
    SetPedCanRagdoll(self.entity, false)
    TaskSetBlockingOfNonTemporaryEvents(self.entity, true)
    SetBlockingOfNonTemporaryEvents(self.entity, true)
    SetPedFleeAttributes(self.entity, 0, false)
    SetPedCombatAttributes(self.entity, 17, true)
    SetEntityInvincible(self.entity, payload.invincible ~= false)
    SetPedSeeingRange(self.entity, 0)
    SetPedDefaultComponentVariation(self.entity)

    if type(payload.component) == 'table' then
        SetPedComponentVariation(
            self.entity,
            payload.component.componentId or 0,
            payload.component.drawableId or 0,
            payload.component.textureId or 0,
            payload.component.paletteId or 0
        )
    end

    if type(payload.anim) == 'table' and payload.anim.animDict and payload.anim.anim then
        playAnim(self.entity, payload.anim, self.interactionId)
    elseif type(payload.scenario) == 'string' then
        startScenario(self.entity, payload.scenario, x, y, z, heading)
    end

    if payload.weapon then
        GiveWeaponToPed(self.entity, payload.weapon, 1, false, true)
        SetCurrentPedWeapon(self.entity, payload.weapon, true)
    end

    return true
end

local function spawnProp(self, payload, model)
    local x, y, z = payload.coords.x, payload.coords.y, payload.coords.z

    -- gizmo-placed props carry their exact position in the matrix
    local matrixX, matrixY, matrixZ = readMatrixPosition(payload.matrix)
    if matrixX then
        x, y, z = matrixX, matrixY, matrixZ
    end

    RequestCollisionAtCoord(x, y, z)

    self.entity = CreateObject(model, x, y, z, false, true, false)
    if not self.entity or self.entity == 0 or not DoesEntityExist(self.entity) then
        self.entity = nil
        return false
    end

    SetEntityAsMissionEntity(self.entity, true, true)

    local rotation = payload.rotation
    local rotationType = type(rotation)
    if type(payload.matrix) == 'table' and applyPropMatrix(self.entity, payload.matrix) then
        -- full gizmo matrix applied, nothing else to do
    elseif rotationType == 'table' or rotationType == 'vector3' then
        SetEntityRotation(self.entity, rotation.x or 0.0, rotation.y or 0.0, rotation.z or 0.0, 2, true)
        SetEntityCollision(self.entity, true, true)
    else
        SetEntityHeading(self.entity, payload.coords.w or payload.heading or 0.0)
        SetEntityCollision(self.entity, true, true)
    end

    SetEntityDynamic(self.entity, false)

    if payload.snapToGround and not matrixX then
        PlaceObjectOnGroundProperly(self.entity)
    end

    FreezeEntityPosition(self.entity, true)
    return true
end

local function onEnter(self)
    local payload = interactions[self.interactionId]
    if not payload then
        lib.print.debug('Interaction not found on Enter:', self.interactionId)
        return false
    end

    -- bumping discards a stale model load from a previous enter
    self._spawnGen = (self._spawnGen or 0) + 1
    local spawnGen = self._spawnGen

    if not canEnter(self) then
        return false
    end

    if self.entity and DoesEntityExist(self.entity) then
        return true
    end

    local model = type(payload.model) == 'string' and joaat(payload.model) or payload.model

    if type(model) ~= 'number' then
        lib.print.debug('Interaction model invalid on Enter:', self.interactionId, payload.model)
        return false
    end

    if not HasModelLoaded(model) then
        lib.requestModel(model, 10000)
    end

    if not IsModelValid(model) then
        lib.print.debug('Interaction model invalid on Enter:', self.interactionId, payload.model)
        return false
    end

    -- the point may have been removed or re-entered while the model streamed in
    -- a same-id replace swaps in a new point while this one streams, which would leave an orphaned entity behind
    local current = interactions[self.interactionId]
    if self._spawnGen ~= spawnGen or not current or (current.point and current.point ~= self) then
        SetModelAsNoLongerNeeded(model)
        return false
    end

    local spawned
    if IsModelAPed(model) then
        spawned = spawnPed(self, payload, model)
    else
        spawned = spawnProp(self, payload, model)
    end

    if not spawned then
        lib.print.debug('Interaction entity failed to spawn:', self.interactionId, payload.model)
        SetModelAsNoLongerNeeded(model)
        return false
    end

    if payload.options and #payload.options > 0 then
        addOptions(self.interactionId, self.entity, payload.options)
    end

    if payload.onSpawn then payload.onSpawn(self) end

    SetModelAsNoLongerNeeded(model)
    return true
end

local function onExit(self)
    self._spawnGen = (self._spawnGen or 0) + 1

    local payload = interactions[self.interactionId]
    local entity = self.entity
    local exists = entity and DoesEntityExist(entity)

    if payload then
        if entity and payload.onDespawn then
            payload.onDespawn(self)
        end
        if entity and payload.options and #payload.options > 0 then
            removeOptions(self.interactionId, entity, payload.options)
        end
    end

    if exists then
        SetEntityAsMissionEntity(entity, false, true)
        DeleteEntity(entity)
    end

    self.entity = nil
end

local function refreshForJobChange()
    for id, payload in pairs(interactions) do
        local point = payload.point
        if point and point.entity and DoesEntityExist(point.entity) then
            if not canStay(point) then
                onExit(point)
            elseif payload.options and #payload.options > 0 then
                removeOptions(id, point.entity, payload.options)
                addOptions(id, point.entity, payload.options)
            end
        end
    end

    points.clearActiveWithoutEntity()
    points.refreshProximity()
end

AddEventHandler('Newb_Bridge:client:playerJobUpdated', refreshForJobChange)

local function remove(id)
    if not id then
        lib.print.debug('Interaction ID missing for removal')
        return false
    end

    if not interactions[id] then
        lib.print.debug('Interaction with ID does not exist for removal:', id)
        return false
    end

    points.remove(id)
    interactions[id] = nil
    return true
end

-- silent skips the debug spam during bulk registration
local function add(id, payload, silent)
    if not id or not payload then
        if not silent then
            lib.print.debug('Interaction ID or Payload missing:', id, payload)
        end
        return false, 'missing'
    end

    if interactions[id] then
        if not silent then
            lib.print.debug('Interaction with ID already exists, replacing:', id)
        end
        remove(id)
    end

    local matrixX, matrixY, matrixZ = readMatrixPosition(payload.matrix)
    if matrixX then
        payload.coords = vector3(matrixX, matrixY, matrixZ)
    end

    payload.coords = toVector3(payload.coords)
    if not payload.coords then
        if not silent then
            lib.print.debug('Interaction coords missing or invalid:', id, payload.coords)
        end
        return false, 'coords'
    end

    interactions[id] = payload

    if not payload.resource then
        payload.resource = GetInvokingResource()
    end

    local radius = lib.math.clamp(tonumber(payload.radius) or 100.0, 1.0, 200.0)
    payload.bucket = tonumber(payload.bucket) or 0
    payload.point = points.add(id, payload.coords, radius, onEnter, onExit, canStay, payload.bucket)

    return true
end

local function update(id, updates)
    if not id or not updates then
        lib.print.debug('Interaction ID or Updates missing:', id, updates)
        return false
    end

    local interaction = interactions[id]
    if not interaction then
        lib.print.debug('Interaction with ID does not exist for update:', id)
        return false
    end

    local point = interaction.point

    if updates.model then interaction.model = updates.model end
    if updates.heading then interaction.heading = updates.heading end
    if updates.scenario then interaction.scenario = updates.scenario end
    if updates.anim then interaction.anim = updates.anim end
    if updates.component then interaction.component = updates.component end
    if updates.weapon then interaction.weapon = updates.weapon end

    local previousOptions
    if updates.options then
        previousOptions = interaction.options
        interaction.options = updates.options
    end

    if updates.onEnter then interaction.onEnter = updates.onEnter end
    if updates.canSpawn then interaction.canSpawn = updates.canSpawn end

    if updates.coords or updates.radius or updates.bucket ~= nil then
        if updates.coords then
            interaction.coords = toVector3(updates.coords) or interaction.coords
        end

        if updates.radius then
            interaction.radius = lib.math.clamp(tonumber(updates.radius) or interaction.radius, 1.0, 200.0)
        end

        if updates.bucket ~= nil then
            interaction.bucket = tonumber(updates.bucket) or 0
        end

        if point then
            points.update(id, interaction.coords, interaction.radius, interaction.bucket)
            point = interaction.point
        end
    end

    if not point or not point.entity or not DoesEntityExist(point.entity) then
        return true
    end

    -- a model swap needs a full respawn; everything else patches in place
    if updates.model then
        onExit(point)
        point.entity = nil
        onEnter(point)
        return true
    end

    if updates.heading then SetEntityHeading(point.entity, updates.heading) end

    if IsEntityAPed(point.entity) then
        if updates.scenario then
            local coords = GetEntityCoords(point.entity)
            startScenario(point.entity, updates.scenario, coords.x, coords.y, coords.z, GetEntityHeading(point.entity))
        end

        if updates.anim then
            playAnim(point.entity, updates.anim, id)
        end

        if updates.component then
            SetPedComponentVariation(
                point.entity,
                updates.component.componentId or 0,
                updates.component.drawableId or 0,
                updates.component.textureId or 0,
                updates.component.paletteId or 0
            )
        end

        if updates.weapon then
            RemoveAllPedWeapons(point.entity, true)
            GiveWeaponToPed(point.entity, updates.weapon, 1, false, true)
            SetCurrentPedWeapon(point.entity, updates.weapon, true)
        end
    end

    if updates.options then
        removeOptions(id, point.entity, previousOptions)

        if #updates.options > 0 then
            addOptions(id, point.entity, interaction.options)
        end
    end

    return true
end

-- per-resource so one consumer's batch can't cancel another's in-flight run
local batchGenerations = {} ---@type table<string, number>
local batchOwner ---@type string?
local bulkDepth = 0
local bulkHolds = {} ---@type table<string, number>

local function removeAll()
    points.removeAll()
    interactions = {}
    bulkDepth = 0
    bulkHolds = {}
    batchGenerations = {}
    batchOwner = nil
end

exports('RemoveAllInteractions', removeAll)

local function describe(row, interaction)
    return {
        id = row.id,
        distance = row.distance,
        coords = interaction.coords,
        heading = interaction.heading,
        radius = interaction.radius,
        model = interaction.model,
        scenario = interaction.scenario,
    }
end

local function getClosestInteraction()
    local playerCoords = GetEntityCoords(cache.ped or PlayerPedId())
    local closest = points.getNearby(playerCoords)[1]
    if not closest then return end

    local interaction = interactions[closest.id]
    if not interaction then return end

    return describe(closest, interaction)
end
exports('GetClosestInteraction', getClosestInteraction)

local function getNearbyInteractions()
    local playerCoords = GetEntityCoords(cache.ped or PlayerPedId())
    local nearby = points.getNearby(playerCoords)
    local result = {}

    for i = 1, #nearby do
        local interaction = interactions[nearby[i].id]
        if interaction then
            result[#result + 1] = describe(nearby[i], interaction)
        end
    end

    return result
end
exports('GetNearbyInteractions', getNearbyInteractions)

local function getInteractionByEntity(entity)
    if not entity or entity == 0 then return end

    for id, interaction in pairs(interactions) do
        local point = interaction.point
        if point and point.entity == entity then
            return id, interaction
        end
    end
end

exports('GetInteractionByEntity', getInteractionByEntity)

---@class InteractionBatchEntry
---@field id string
---@field payload InteractionPayload

---@class InteractionBatchOptions
---@field batchSize? number points per frame when spreading (default 25)
---@field batchDelayMs? number delay between batches (default 0)
---@field batchThreshold? number spread only when entry count >= this (default 1)
---@field sortByDistance? boolean nearest-first before registering (default true)
---@field onProgress? fun(index: number, total: number, id: string, ok: boolean)
---@field onComplete? fun(added: number, failed: number)

-- accepts an array of { id, payload } rows or a map of id -> payload
local function parseEntries(entries)
    local list = {}
    if type(entries) ~= 'table' then return list end

    if entries[1] ~= nil then
        for i = 1, #entries do
            local row = entries[i]
            if type(row) == 'table' and type(row.id) == 'string' and type(row.payload) == 'table' then
                list[#list + 1] = { id = row.id, payload = row.payload }
            end
        end
        return list
    end

    for id, payload in pairs(entries) do
        if type(id) == 'string' and type(payload) == 'table' then
            list[#list + 1] = { id = id, payload = payload }
        end
    end

    return list
end

local function sortNearestFirst(list)
    if #list <= 1 then return end

    local ped = cache and cache.ped or PlayerPedId()
    if not ped or ped == 0 then return end

    local playerCoords = GetEntityCoords(ped)

    -- compute each distance once instead of inside the sort comparator
    local tagged = {}
    for i, entry in ipairs(list) do
        local coords = toVector3(entry.payload.coords)
        tagged[i] = { dist = coords and #(playerCoords - coords) or math.huge, entry = entry }
    end

    table.sort(tagged, function(a, b)
        return a.dist < b.dist
    end)

    for i, taggedEntry in ipairs(tagged) do
        list[i] = taggedEntry.entry
    end
end

local function batchSettings(options)
    options = type(options) == 'table' and options or {}

    local batchSize = math.max(tonumber(options.batchSize) or 25, 1)
    local batchDelayMs = math.max(tonumber(options.batchDelayMs) or 0, 0)
    local batchThreshold = math.max(tonumber(options.batchThreshold) or 1, 1)

    return batchSize, batchDelayMs, batchThreshold, options.sortByDistance ~= false
end

-- registers across frames to avoid join spikes; returns a token for CancelInteractionBatch
---@param entries table[]|table<string, InteractionPayload>
---@param options? InteractionBatchOptions
---@return number
local function addBatch(entries, options)
    local list = parseEntries(entries)
    -- captured here because GetInvokingResource() returns nil inside the thread below
    local owningResource = GetInvokingResource() or cache.resource

    if #list == 0 then
        if type(options) == 'table' and options.onComplete then
            options.onComplete(0, 0)
        end
        return batchGenerations[owningResource] or 0
    end

    batchGenerations[owningResource] = (batchGenerations[owningResource] or 0) + 1
    local generation = batchGenerations[owningResource]

    local batchSize, batchDelayMs, batchThreshold, nearestFirst = batchSettings(options)
    local spread = #list >= batchThreshold
    batchOwner = owningResource

    CreateThread(function()
        Wait(0)
        if generation ~= batchGenerations[owningResource] then return end

        points.beginBulk()

        if nearestFirst then
            sortNearestFirst(list)
        end

        local added, failed, total = 0, 0, #list

        for i = 1, total do
            if generation ~= batchGenerations[owningResource] then
                points.commitBulk()
                return
            end

            local row = list[i]
            if row.payload.resource == nil then
                row.payload.resource = owningResource
            end

            local ok = add(row.id, row.payload, true)
            if ok then
                added = added + 1
            else
                failed = failed + 1
            end

            if type(options) == 'table' and options.onProgress then
                options.onProgress(i, total, row.id, ok == true)
            end

            if spread and i % batchSize == 0 then
                Wait(batchDelayMs)
            end
        end

        points.commitBulk()

        if generation ~= batchGenerations[owningResource] then return end
        if batchOwner == owningResource then
            batchOwner = nil
        end
        if type(options) == 'table' and options.onComplete then
            options.onComplete(added, failed)
        end
    end)

    return generation
end

-- aborts the calling resource's batch; a newer batch invalidates older tokens
local function cancelBatch()
    local resource = GetInvokingResource() or batchOwner
    if not resource then return end
    batchGenerations[resource] = (batchGenerations[resource] or 0) + 1
    if batchOwner == resource then
        batchOwner = nil
    end
end

exports('AddInteraction', function(id, payload)
    return add(id, payload, bulkDepth > 0)
end)
exports('AddInteractionsBatch', addBatch)
exports('CancelInteractionBatch', cancelBatch)
exports('BeginInteractionBulk', function()
    -- held per resource so a consumer dying between Begin and Commit
    -- can't leave the proximity loop paused forever
    local resource = GetInvokingResource() or cache.resource
    bulkHolds[resource] = (bulkHolds[resource] or 0) + 1
    bulkDepth = bulkDepth + 1
    points.beginBulk()
end)
exports('CommitInteractionBulk', function()
    local resource = GetInvokingResource() or cache.resource
    local held = bulkHolds[resource]
    if held then
        bulkHolds[resource] = held > 1 and held - 1 or nil
    end
    if bulkDepth > 0 then
        bulkDepth = bulkDepth - 1
    end
    points.commitBulk()
end)
exports('RemoveInteraction', function(id) return remove(id) end)
exports('UpdateInteraction', function(id, updates) return update(id, updates) end)

local function handleInteractionRemoved(id)
    if source ~= 65535 then return end
    remove(id)
end

RegisterNetEvent('Newb_Bridge:client:interactionRemoved', handleInteractionRemoved)
RegisterNetEvent('Newb_Bridge:Interaction:Remove', handleInteractionRemoved) -- deprecated 2026-12-17: use Newb_Bridge:client:interactionRemoved

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == cache.resource then
        removeAll()
        return
    end

    -- an in-flight batch would keep registering points with dead funcrefs
    if batchGenerations[resourceName] then
        batchGenerations[resourceName] = batchGenerations[resourceName] + 1
    end
    if batchOwner == resourceName then
        batchOwner = nil
    end

    -- release holds it never committed, or the proximity loop stays paused
    local held = bulkHolds[resourceName]
    if held then
        bulkHolds[resourceName] = nil
        for _ = 1, held do
            if bulkDepth > 0 then
                bulkDepth = bulkDepth - 1
            end
            points.commitBulk()
        end
    end

    local ids = {}
    for id, interaction in pairs(interactions) do
        if interaction.resource == resourceName then
            ids[#ids + 1] = id
        end
    end

    for i = #ids, 1, -1 do
        remove(ids[i])
    end
end)
