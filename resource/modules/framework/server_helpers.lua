-- Server-side helpers reused by framework provider modules (ESX, QB, QBX).

local ServerHelpers = {}

ServerHelpers.GLOBAL_JOB_COUNTS_KEY = 'newbsJobCounts'

-- Fallback for getJobCounts/getDutyCountJob/getOnlineCountJob below, used only
-- if a framework provider module is ever mounted outside the bridge host (see
-- isHost in attachSharedFrameworkApi). GlobalState[GLOBAL_JOB_COUNTS_KEY]
-- itself is not dead either way: other resources (e.g. Buckshot_PauseMenu, client-side)
-- read it directly, so createDutyCache below keeps publishing to it regardless.
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

    local function copySet(set)
        local copy = {}
        if not set then return copy end

        for src in pairs(set) do
            copy[src] = true
        end

        return copy
    end

    -- Shallow-copied so callers can't mutate the live membership sets above.
    local function getPlayersOnDuty(jobName)
        return copySet(onDutyPlayersByJob[jobName])
    end

    local function getPlayersWithJob(jobName)
        return copySet(playersByJob[jobName])
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

function ServerHelpers.attachSharedFrameworkApi(framework, dutyCache, registerUsableItem)
    -- bridge.framework is always proxied through the host export (see
    -- import.lua's hostBacked table), so a provider module only ever loads
    -- once, inside the actual bridge host, no matter how many resources
    -- import it - that's what stops the framework's own event handlers
    -- (PlayerLoaded, SetDuty, etc.) from being registered once per importer
    -- and firing multiple times per event. isHost is checked here
    -- as insurance against that routing ever changing, not because it's
    -- expected to be false in normal operation.
    local isHost = bridge.isHost

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
        if isHost then
            return dutyCache.getDutyCountJob(jobName)
        end
        return ServerHelpers.readGlobalJobCounts(jobName).onDuty
    end

    function framework.getOnlineCountJob(jobName)
        if isHost then
            return dutyCache.getOnlineCountJob(jobName)
        end
        return ServerHelpers.readGlobalJobCounts(jobName).count
    end

    function framework.getJobCounts(jobName)
        if isHost then
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
        local function registerActiveUsableItem(itemName, handler)
            if Config.Providers and Config.Providers.inventory == 'wasabi_inventory' and GetResourceState('wasabi_inventory') ~= 'missing' then
                if not handler then
                    return exports.wasabi_inventory:registerUsableItem(itemName, function() end)
                end

                return exports.wasabi_inventory:registerUsableItem(itemName, function(inventoryId, item, context)
                    local src = tonumber(inventoryId)
                    if not src and type(context) == 'table' then
                        src = tonumber(context.source)
                    end
                    src = src or source
                    if type(item) ~= 'table' then
                        item = {
                            name = itemName,
                            count = 1,
                            metadata = {},
                            slot = type(context) == 'table' and context.slot or nil,
                        }
                    elseif type(context) == 'table' and context.slot and not item.slot then
                        item.slot = context.slot
                    end
                    return handler(src, item, item)
                end)
            end

            return registerUsableItem(itemName, handler)
        end

        local itemOwners = {} ---@type table<string, string>

        local function isItemUseCallback(value)
            local valueType = type(value)
            return valueType == 'function' or valueType == 'table'
        end

        local function resolveItemUseOwner(cb)
            local invokingResource = GetInvokingResource()
            if invokingResource and invokingResource ~= '' then
                return invokingResource
            end

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

            return registerActiveUsableItem(itemName, function(src, item, itemData)
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
                    registerActiveUsableItem(itemName, nil)
                end
            end
        end)
    end

    return framework
end

return ServerHelpers
