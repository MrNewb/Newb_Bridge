-- Proximity manager for AddInteraction. Points live in fixed-size cell buckets
-- and each tick scans the 3x3 around the player so cell edges still resolve.

---@class InteractionPointRuntime
---@field interactionId string
---@field coords vector3
---@field radius number
---@field entity? number
---@field _spawnGen number
---@field remove fun()

---@class InteractionPointRegistration
---@field id string
---@field coords vector3
---@field radius number
---@field bucket number Routing bucket id (0 = default world).
---@field cellX number
---@field cellY number
---@field runtime InteractionPointRuntime
---@field onEnter fun(self: InteractionPointRuntime)
---@field onExit fun(self: InteractionPointRuntime)
---@field onInside? fun(self: InteractionPointRuntime): boolean|nil

local InteractionPointManager = {}

local maxSpawnRadius = 175.0
local cellSize = 200.0
local pointTickMs = 500
local denseThreshold = 50
local denseSpawnBatch = 20
local postBulkDelayMs = 0

if cellSize < 50.0 then cellSize = 50.0 end
if cellSize > maxSpawnRadius * 2.0 then cellSize = maxSpawnRadius * 2.0 end

local entries = {} ---@type table<string, InteractionPointRegistration>
local cells = {} ---@type table<number, table<number, table<string, InteractionPointRegistration>>>
local active = {} ---@type table<string, boolean>
local loopRunning = false
local loopPaused = false
local bulkDepth = 0

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

local function distanceBetween(a, b)
    a = toVector3(a)
    b = toVector3(b)
    if not a or not b then return math.huge end
    return #(a - b)
end

local function normalizeSpawnRadius(spawnRadius)
    local radius = tonumber(spawnRadius) or 50.0
    if radius > maxSpawnRadius then radius = maxSpawnRadius end
    if radius < 1.0 then radius = 1.0 end
    return radius
end

local function normalizeRoutingBucket(bucket)
    return tonumber(bucket) or 0
end

local function getPlayerRoutingBucket()
    -- ox_lib replicates the bucket here; cheaper than a lib.player wrapper per tick
    return LocalPlayer.state.bucket or 0
end

local function bucketsMatch(playerBucket, entryBucket)
    return normalizeRoutingBucket(playerBucket) == normalizeRoutingBucket(entryBucket)
end

local function getCellKey(coords)
    return math.floor(coords.x / cellSize), math.floor(coords.y / cellSize)
end

local function getCellBucket(cellX, cellY)
    local row = cells[cellX]
    if not row then
        row = {}
        cells[cellX] = row
    end

    local bucket = row[cellY]
    if not bucket then
        bucket = {}
        row[cellY] = bucket
    end

    return bucket
end

local function addToCell(registration)
    local cellX, cellY = getCellKey(registration.coords)
    registration.cellX = cellX
    registration.cellY = cellY
    getCellBucket(cellX, cellY)[registration.id] = registration
end

local function removeFromCell(registration)
    local row = cells[registration.cellX]
    local bucket = row and row[registration.cellY]
    if not bucket then return end

    bucket[registration.id] = nil

    if not next(bucket) then
        row[registration.cellY] = nil
    end

    if row and not next(row) then
        cells[registration.cellX] = nil
    end
end

local function setActive(id, isActive)
    active[id] = isActive or nil
end

local function forEachNeighborCell(coords, fn)
    local cellX, cellY = getCellKey(coords)

    for offsetX = -1, 1 do
        local row = cells[cellX + offsetX]
        if row then
            for offsetY = -1, 1 do
                local bucket = row[cellY + offsetY]
                if bucket then
                    fn(bucket)
                end
            end
        end
    end
end

local function trySpawnEntry(id, entry, playerCoords, playerBucket)
    if active[id] or not entries[id] then return false end
    if distanceBetween(playerCoords, entry.coords) > entry.radius then return false end

    if playerBucket == nil then
        playerBucket = getPlayerRoutingBucket()
    end

    if not bucketsMatch(playerBucket, entry.bucket) then return false end

    if entry.onEnter(entry.runtime) == false then
        return false
    end

    setActive(id, true)
    return true
end

local function spawnPendingAsync(pending, startIndex)
    CreateThread(function()
        for i = startIndex, #pending do
            local row = pending[i]
            local entry = entries[row.id]

            if entry and not active[row.id] then
                local ped = cache and cache.ped or PlayerPedId()
                if ped and ped ~= 0 then
                    trySpawnEntry(row.id, entry, GetEntityCoords(ped))
                end
            end

            if i % denseSpawnBatch == 0 then
                Wait(0)
            end
        end
    end)
end

local function runTick()
    if loopPaused then return end

    local ped = cache and cache.ped or PlayerPedId()
    if not ped or ped == 0 then return end

    local coords = GetEntityCoords(ped)
    local playerBucket = getPlayerRoutingBucket()

    local shouldActive = {} ---@type table<string, boolean>
    local pending ---@type { id: string, distance: number, entry: InteractionPointRegistration }[]?

    forEachNeighborCell(coords, function(bucket)
        for id, entry in pairs(bucket) do
            local distance = #(coords - entry.coords)

            if distance <= entry.radius and bucketsMatch(playerBucket, entry.bucket) then
                shouldActive[id] = true

                if not active[id] then
                    pending = pending or {}
                    pending[#pending + 1] = { id = id, distance = distance, entry = entry }
                end
            elseif active[id] then
                entry.onExit(entry.runtime)
                setActive(id, false)
            end
        end
    end)

    -- one pass: exit what left range, run the stay gate on what didn't
    for id in pairs(active) do
        local entry = entries[id]

        if not shouldActive[id] then
            if entry then
                entry.onExit(entry.runtime)
            end
            setActive(id, false)
        elseif entry and entry.onInside and entry.onInside(entry.runtime) == false then
            entry.onExit(entry.runtime)
            setActive(id, false)
        end
    end

    if not pending then return end

    if #pending > 1 then
        table.sort(pending, function(a, b)
            return a.distance < b.distance
        end)
    end

    if #pending <= denseThreshold then
        for i = 1, #pending do
            local row = pending[i]
            trySpawnEntry(row.id, row.entry, coords, playerBucket)
        end
        return
    end

    for i = 1, math.min(denseSpawnBatch, #pending) do
        local row = pending[i]
        trySpawnEntry(row.id, row.entry, coords, playerBucket)
    end

    if #pending > denseSpawnBatch then
        spawnPendingAsync(pending, denseSpawnBatch + 1)
    end
end

local startLoop

startLoop = function()
    if loopRunning or loopPaused then return end
    loopRunning = true

    CreateThread(function()
        while loopRunning do
            if not next(entries) then
                loopRunning = false
                return
            end

            runTick()
            Wait(pointTickMs)
        end
    end)
end

function InteractionPointManager.beginBulk()
    bulkDepth = bulkDepth + 1
    loopPaused = true
end

function InteractionPointManager.commitBulk()
    if bulkDepth <= 0 then return end

    bulkDepth = bulkDepth - 1
    if bulkDepth > 0 then return end

    CreateThread(function()
        if postBulkDelayMs > 0 then
            Wait(postBulkDelayMs)
        end

        if bulkDepth > 0 then return end

        loopPaused = false
        startLoop()
        runTick()
    end)
end

function InteractionPointManager.add(id, coords, radius, onEnter, onExit, onInside, bucket)
    local existing = entries[id]
    if existing then
        InteractionPointManager.remove(id)
    end

    coords = toVector3(coords)
    if not coords then return end

    radius = normalizeSpawnRadius(radius)
    bucket = normalizeRoutingBucket(bucket)

    local runtime = {
        interactionId = id,
        coords = coords,
        radius = radius,
        entity = nil,
        _spawnGen = 0,
        remove = function()
            InteractionPointManager.remove(id)
        end,
    }

    local registration = {
        id = id,
        coords = coords,
        radius = radius,
        bucket = bucket,
        runtime = runtime,
        onEnter = onEnter,
        onExit = onExit,
        onInside = onInside,
    }

    addToCell(registration)
    entries[id] = registration

    if bulkDepth == 0 then
        startLoop()

        local ped = cache and cache.ped or PlayerPedId()
        if ped and ped ~= 0 then
            trySpawnEntry(id, registration, GetEntityCoords(ped))
        end
    end

    return runtime
end

function InteractionPointManager.update(id, coords, radius, bucket)
    local entry = entries[id]
    if not entry then return false end

    local newCoords = coords and toVector3(coords) or entry.coords
    if not newCoords then return false end

    local newRadius = radius and normalizeSpawnRadius(radius) or entry.radius
    local newBucket = bucket ~= nil and normalizeRoutingBucket(bucket) or entry.bucket
    local coordsChanged = distanceBetween(newCoords, entry.coords) > 0.01
    local bucketChanged = newBucket ~= entry.bucket

    if coordsChanged then
        if active[id] then
            entry.onExit(entry.runtime)
            setActive(id, false)
        end

        removeFromCell(entry)
        entry.coords = newCoords
        entry.runtime.coords = newCoords
        addToCell(entry)
    end

    if newRadius ~= entry.radius then
        entry.radius = newRadius
        entry.runtime.radius = newRadius
    end

    if bucketChanged then
        entry.bucket = newBucket

        if active[id] and not bucketsMatch(getPlayerRoutingBucket(), entry.bucket) then
            entry.onExit(entry.runtime)
            setActive(id, false)
        end
    end

    if bulkDepth == 0 then
        local ped = cache and cache.ped or PlayerPedId()
        if ped and ped ~= 0 then
            trySpawnEntry(id, entry, GetEntityCoords(ped))
        end
    end

    return true
end

function InteractionPointManager.remove(id)
    local entry = entries[id]
    if not entry then return end

    if active[id] then
        entry.onExit(entry.runtime)
        setActive(id, false)
    end

    removeFromCell(entry)
    entries[id] = nil
end

function InteractionPointManager.removeAll()
    bulkDepth = 0
    loopPaused = false

    for id, entry in pairs(entries) do
        if active[id] then
            entry.onExit(entry.runtime)
        end
        removeFromCell(entry)
        entries[id] = nil
    end

    active = {}
    cells = {}
end

function InteractionPointManager.getNearby(playerCoords)
    playerCoords = toVector3(playerCoords)
    if not playerCoords then return {} end

    local result = {}

    forEachNeighborCell(playerCoords, function(bucket)
        for id, entry in pairs(bucket) do
            result[#result + 1] = {
                id = id,
                distance = #(playerCoords - entry.coords),
                coords = entry.coords,
            }
        end
    end)

    if #result > 1 then
        table.sort(result, function(a, b)
            return a.distance < b.distance
        end)
    end

    return result
end

function InteractionPointManager.clearActiveWithoutEntity()
    for id in pairs(active) do
        local entry = entries[id]
        local entity = entry and entry.runtime and entry.runtime.entity

        if not entity or not DoesEntityExist(entity) then
            if entry then
                entry.onExit(entry.runtime)
            end
            setActive(id, false)
        end
    end
end

function InteractionPointManager.refreshProximity()
    runTick()
end

AddStateBagChangeHandler('bucket', ('player:%s'):format(cache.serverId), function(_, _, _, _, replicated)
    if replicated then return end
    runTick()
end)

_G.InteractionPointManager = InteractionPointManager
