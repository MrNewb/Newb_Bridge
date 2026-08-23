-- Server-side helpers reused by framework provider modules (ESX, QB, QBX).

local ServerHelpers = {}

ServerHelpers.GLOBAL_JOB_COUNTS_KEY = 'newbsJobCounts'

-- Reads the replicated job counts published by the bridge instance.
-- Consumer resources load their own copy of the framework module whose local
-- duty cache is never fed; this is their source of truth for counts.
function ServerHelpers.readGlobalJobCounts(jobName)
    local counts = GlobalState[ServerHelpers.GLOBAL_JOB_COUNTS_KEY]
    local entry = type(counts) == 'table' and counts[jobName] or nil

    return {
        count = entry and tonumber(entry.count) or 0,
        onDuty = entry and tonumber(entry.onDuty) or 0,
    }
end

---@class BridgeJobCountSnapshot
---@field count number Players currently online with this job.
---@field onDuty number Players currently on duty for this job.

---@class FrameworkDutyCache
---@field syncOnDutyPlayer fun(src: number, job: table)
---@field clearOnDutyPlayer fun(src: number)
---@field getDutyCountJob fun(jobName: string): number
---@field getOnlineCountJob fun(jobName: string): number
---@field getJobCounts fun(jobName: string): BridgeJobCountSnapshot
---@field getPlayersOnDuty fun(jobName: string): table<number, true>
---@field getPlayersWithJob fun(jobName: string): table<number, true>
---@field syncGlobalJobCounts fun()

function ServerHelpers.createDutyCache(isPlayerOnDuty)
    local jobByPlayerSrc = {} ---@type table<number, string>
    local playersByJob = {} ---@type table<string, table<number, true>>
    local onDutyPlayersByJob = {} ---@type table<string, table<number, true>>

    -- Local authoritative mirror of GlobalState. The bridge host is the only
    -- writer, so we mutate this and push it to GlobalState on change rather than
    -- reading the replicated value back and rebuilding it every job event.
    local jobCounts = {} ---@type table<string, BridgeJobCountSnapshot>

    local function removePlayerFromJob(src, jobName)
        if not jobName then return end

        if playersByJob[jobName] then
            playersByJob[jobName][src] = nil
        end

        if onDutyPlayersByJob[jobName] then
            onDutyPlayersByJob[jobName][src] = nil
        end
    end

    local function countSet(set)
        if not set then return 0 end
        local total = 0
        for _ in pairs(set) do
            total = total + 1
        end
        return total
    end

    local function publishJobEntry(jobName)
        if not jobName then return end

        local count = countSet(playersByJob[jobName])
        local onDuty = countSet(onDutyPlayersByJob[jobName])
        local previous = jobCounts[jobName]

        if count <= 0 and onDuty <= 0 then
            if previous == nil then return end
            jobCounts[jobName] = nil
            GlobalState[ServerHelpers.GLOBAL_JOB_COUNTS_KEY] = jobCounts
            return
        end

        if previous and previous.count == count and previous.onDuty == onDuty then
            return
        end

        jobCounts[jobName] = { count = count, onDuty = onDuty }
        GlobalState[ServerHelpers.GLOBAL_JOB_COUNTS_KEY] = jobCounts
    end

    local function syncGlobalJobCounts()
        local snapshot = {}

        for jobName in pairs(playersByJob) do
            local count = countSet(playersByJob[jobName])
            local onDuty = countSet(onDutyPlayersByJob[jobName])
            if count > 0 or onDuty > 0 then
                snapshot[jobName] = {
                    count = count,
                    onDuty = onDuty,
                }
            end
        end

        jobCounts = snapshot
        GlobalState[ServerHelpers.GLOBAL_JOB_COUNTS_KEY] = jobCounts
    end

    local function clearOnDutyPlayer(src)
        local previousJob = jobByPlayerSrc[src]
        removePlayerFromJob(src, previousJob)
        jobByPlayerSrc[src] = nil
        publishJobEntry(previousJob)
    end

    local function syncOnDutyPlayer(src, job)
        local previousJob = jobByPlayerSrc[src]

        removePlayerFromJob(src, previousJob)

        jobByPlayerSrc[src] = job.name
        playersByJob[job.name] = playersByJob[job.name] or {}
        playersByJob[job.name][src] = true

        if isPlayerOnDuty(job) then
            onDutyPlayersByJob[job.name] = onDutyPlayersByJob[job.name] or {}
            onDutyPlayersByJob[job.name][src] = true
        end

        if previousJob and previousJob ~= job.name then
            publishJobEntry(previousJob)
        end

        publishJobEntry(job.name)
    end

    local function getDutyCountJob(jobName)
        return countSet(onDutyPlayersByJob[jobName])
    end

    local function getOnlineCountJob(jobName)
        return countSet(playersByJob[jobName])
    end

    local function getJobCounts(jobName)
        return {
            count = getOnlineCountJob(jobName),
            onDuty = getDutyCountJob(jobName),
        }
    end

    local function getPlayersOnDuty(jobName)
        return onDutyPlayersByJob[jobName] or {}
    end

    local function getPlayersWithJob(jobName)
        return playersByJob[jobName] or {}
    end

    return {
        syncOnDutyPlayer = syncOnDutyPlayer,
        clearOnDutyPlayer = clearOnDutyPlayer,
        getDutyCountJob = getDutyCountJob,
        getOnlineCountJob = getOnlineCountJob,
        getJobCounts = getJobCounts,
        getPlayersOnDuty = getPlayersOnDuty,
        getPlayersWithJob = getPlayersWithJob,
        syncGlobalJobCounts = syncGlobalJobCounts,
    }
end

-- Installs the framework API that is identical across every provider (ESX, QB,
-- QBX): command registration, the duty-count reads (host cache vs replicated
-- GlobalState), usable-item registration, and setPlayerMetadata. Provider
-- modules keep only framework-specific bodies and call this before returning.
--
-- Consumer copies never feed the duty cache, so the count reads fall back to
-- the GlobalState snapshot the bridge host publishes.
function ServerHelpers.attachSharedFrameworkApi(framework, dutyCache, registerUsableItem)
    local isBridgeInstance = bridge.isHost

    function framework.registerCommand(commandName, helpText, params, restrictedGroup, callback)
        lib.addCommand(commandName, {
            help = helpText,
            params = params,
            restricted = restrictedGroup
        }, callback)
    end

    function framework.setPlayerMetadata(src, key, value)
        framework.setMetadata(src, { [key] = { type = 'set', value = value } })
    end

    function framework.getDutyCountJob(jobName)
        if isBridgeInstance then
            return dutyCache.getDutyCountJob(jobName)
        end
        return ServerHelpers.readGlobalJobCounts(jobName).onDuty
    end

    function framework.getOnlineCountJob(jobName)
        if isBridgeInstance then
            return dutyCache.getOnlineCountJob(jobName)
        end
        return ServerHelpers.readGlobalJobCounts(jobName).count
    end

    function framework.getJobCounts(jobName)
        if isBridgeInstance then
            return dutyCache.getJobCounts(jobName)
        end
        return ServerHelpers.readGlobalJobCounts(jobName)
    end

    function framework.getPlayersOnDuty(jobName)
        return dutyCache.getPlayersOnDuty(jobName)
    end

    function framework.getPlayersWithJob(jobName)
        return dutyCache.getPlayersWithJob(jobName)
    end

    if registerUsableItem then
        -- Host-backed framework stores consumer callbacks across the script-host
        -- boundary. If the owner stops/restarts without clearing QBX/QB/ESX
        -- usable-item slots, use invokes hit a dead function ref and surface as
        -- "Execution of function reference in script host failed" at the cb call.
        local itemOwners = {} ---@type table<string, string>

        -- Host-proxied callers pass CFX funcrefs: type() is "table", not "function".
        -- See citizenfx/fivem#1586 — same reason ox_lib accepts table callbacks.
        local function isItemUseCallback(value)
            local valueType = type(value)
            return valueType == 'function' or valueType == 'table'
        end

        local function resolveItemUseOwner(cb)
            local invokingResource = GetInvokingResource()
            if invokingResource and invokingResource ~= '' then
                return invokingResource
            end

            -- Methods on the Framework export table are often invoked without an
            -- invoking-resource context; fall back to the callback chunk path.
            -- Local functions only — funcrefs have no usable debug source.
            if type(cb) == 'function' then
                local debugInfo = debug.getinfo(cb, 'S')
                local sourcePath = debugInfo and debugInfo.source
                if type(sourcePath) == 'string' then
                    local resourceName = sourcePath:match('^@@?([^/\\]+)')
                    if resourceName and resourceName ~= '' then
                        return resourceName
                    end
                end
            end

            return bridge.resource
        end

        function framework.registerItemUse(itemName, cb)
            if type(itemName) ~= 'string' or itemName == '' then
                error('registerItemUse requires a non-empty item name', 2)
            end
            if not isItemUseCallback(cb) then
                error(('registerItemUse("%s") requires a function callback'):format(itemName), 2)
            end

            local ownerResource = resolveItemUseOwner(cb)
            itemOwners[itemName] = ownerResource

            return registerUsableItem(itemName, function(src, item, itemData)
                if GetResourceState(ownerResource) ~= 'started' then
                    print(('^3[Newb_Bridge] Skipping use of "%s": owner resource "%s" is not started (stale usable-item callback).^0'):format(itemName, ownerResource))
                    return
                end

                itemData = itemData or item
                if type(itemData) ~= 'table' then
                    error(('Item use for "%s" (%s) received a non-table payload'):format(itemName, ownerResource), 0)
                end

                itemData.metadata = itemData.metadata or itemData.info or {}
                itemData.slot = itemData.id or itemData.slot
                cb(src, itemData)
            end)
        end

        AddEventHandler('onResourceStop', function(stoppedResource)
            for itemName, ownerResource in pairs(itemOwners) do
                if ownerResource == stoppedResource then
                    itemOwners[itemName] = nil
                    registerUsableItem(itemName, nil)
                end
            end
        end)
    end

    return framework
end

return ServerHelpers
