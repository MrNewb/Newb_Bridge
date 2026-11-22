-- kora_core framework provider (server). Uses kora_core's native flat exports
-- only (exports.kora_core:*); it does not depend on the qb-core compatibility
-- layer.
--
-- Grades: kora_core grades are one-based, every other bridge framework reports
-- zero-based grades. This provider converts at the edge (level - 1 on read,
-- grade + 1 on write) so consumer scripts see the same numbers on every stack.

local BridgePlayers = require '@Newb_Bridge/resource/modules/framework/player_registry'
local ServerHelpers = require '@Newb_Bridge/resource/modules/framework/server_helpers'

local kora = exports.kora_core
local framework = {}

local function accountName(moneyType)
    if moneyType == 'money' then return 'cash' end
    return moneyType
end

local function gradeLevel(job)
    local grade = job and job.grade
    if type(grade) == 'table' then grade = grade.level end
    grade = tonumber(grade)
    if not grade then return nil end
    return math.max(grade - 1, 0)
end

local function getData(src)
    src = tonumber(src)
    if not src then return nil end
    return kora:getPlayer(src)
end

local dutyCache = ServerHelpers.createDutyCache(function(job)
    return job.onduty == true
end)

local function buildPlayerData(data)
    if not data or not data.citizenid then return nil end

    local charInfo = data.charinfo or {}
    local job = data.job

    return {
        charId = data.citizenid,
        name = ('%s %s'):format(charInfo.firstname or '', charInfo.lastname or ''),
        jobName = job and job.name,
        onDuty = job and job.onduty == true,
    }
end

local function syncBridgePlayer(src)
    local data = buildPlayerData(getData(src))
    if data then
        BridgePlayers.sync(src, data)
    end
end

function framework.getIdentifier(src)
    local data = getData(src)
    return data and data.citizenid or nil
end

function framework.getSrcFromIdentifier(identifier)
    if not identifier then return nil end

    local data = kora:getPlayerByCitizenId(identifier)
    return data and data.source or nil
end

function framework.getCharacterName(identifier)
    local data = identifier and kora:getPlayerByCitizenId(identifier)
    local charInfo = data and data.charinfo
    if not charInfo or not charInfo.firstname or not charInfo.lastname then return nil end

    return ('%s %s'):format(charInfo.firstname, charInfo.lastname), charInfo.firstname, charInfo.lastname
end

-- Keyed by job name with zero-based grade keys, matching the other providers.
function framework.getFrameworkJobs()
    local jobs = {}

    for _, record in ipairs(kora:allShared('jobs') or {}) do
        local grades = {}
        for index, grade in ipairs(record.grades or {}) do
            grades[index - 1] = grade
        end

        jobs[record.name] = {
            label = record.label,
            type = record.type,
            defaultDuty = record.defaultDuty,
            offDutyPay = record.offDutyPay,
            grades = grades,
        }
    end

    return jobs
end

function framework.isAdmin(src)
    src = tonumber(src)
    if not src then return false end

    local isAdmin = kora:hasPermission(src, 'admin')
    local isGod = kora:hasPermission(src, 'god')
    local isAceAllowed = IsPlayerAceAllowed(tostring(src), 'command')

    return (isAdmin or isGod or isAceAllowed) and true or false
end

function framework.setMetadata(src, payload)
    if type(payload) ~= 'table' then return end
    if not getData(src) then return end

    for key, data in pairs(payload) do
        if type(data) == 'table' then
            if data.type == 'add' or data.type == 'remove' then
                local delta = tonumber(data.value)
                if delta then
                    if data.type == 'remove' then delta = -delta end
                    kora:incrementMetaData(src, key, delta, 0, 100)
                end
            else
                kora:setMetaData(src, key, data.value)
            end
        end
    end
end

function framework.getPlayerMetadata(src, key)
    if not getData(src) then return nil end
    return kora:getMetaData(src, key)
end

function framework.addMoney(src, moneyType, moneyAmount, reason)
    if not getData(src) then return false end
    return kora:addMoney(src, accountName(moneyType), moneyAmount, reason) == true
end

function framework.removeMoney(src, moneyType, moneyAmount, reason)
    if not getData(src) then return false end
    return kora:removeMoney(src, accountName(moneyType), moneyAmount, reason) == true
end

function framework.getMoney(src, moneyType)
    if not getData(src) then return 0 end
    return kora:getMoney(src, accountName(moneyType)) or 0
end

function framework.getPlayerJobData(src)
    local job = kora:getJob(tonumber(src))
    if not job then return nil end

    return {
        jobName = job.name,
        jobLabel = job.label,
        grade = gradeLevel(job),
        gradeName = job.grade and job.grade.name,
        onDuty = job.onduty == true,
        isBoss = job.isboss == true,
    }
end

function framework.hasJob(src, job, grade, duty)
    local playerJob = kora:getJob(tonumber(src))
    if not playerJob or playerJob.name ~= job then
        return false
    end

    if grade then
        local level = gradeLevel(playerJob)
        if not level or level < grade then
            return false
        end
    end

    if duty and not playerJob.onduty then
        return false
    end

    return true
end

function framework.setPlayerDuty(src, onDuty)
    src = tonumber(src)
    if not src or not getData(src) then return false end

    return kora:setJobDuty(src, onDuty == true) == true
end

function framework.setPlayerJob(src, name, grade)
    src = tonumber(src)
    if not src or not getData(src) then return false end

    return kora:setJob(src, name, (tonumber(grade) or 0) + 1) == true
end

function framework.getPlayersByJob(jobName)
    -- The duty cache is populated inside the bridge host (see the isHost note
    -- on the event wiring below); other realms fall back to kora_core's index.
    if bridge.isHost then
        local sources = {}
        for src in pairs(dutyCache.getPlayersWithJob(jobName)) do
            sources[#sources + 1] = src
        end
        table.sort(sources)
        return sources
    end

    return kora:getPlayersByJob(jobName, false) or {}
end

local function addNeed(src, key, value)
    if not getData(src) then return nil end

    local newValue = kora:incrementMetaData(src, key, tonumber(value) or 0, 0, 100)
    return tonumber(newValue)
end

function framework.addHunger(src, value)
    return addNeed(src, 'hunger', value)
end

function framework.addThirst(src, value)
    return addNeed(src, 'thirst', value)
end

function framework.getOwnedVehicles(src)
    local identifier = framework.getIdentifier(src)
    if not identifier then return {} end

    local vehicles = {}
    for _, row in ipairs(kora:getByOwner(identifier) or {}) do
        vehicles[#vehicles + 1] = { vehicle = row.vehicle or row.model, plate = row.plate }
    end

    return vehicles
end

function framework.getPlayers()
    return kora:getPlayers() or {}
end

function framework.getPlayerDob(src)
    local data = getData(src)
    return data and data.charinfo and data.charinfo.birthdate or nil
end

-- framework is always proxied through the host export (see import.lua's
-- hostBacked table), so this block only runs once, inside the bridge host.
-- isHost is insurance against that routing changing: it stops every importer
-- from registering these handlers and firing playerLoad once per importer.
if bridge.isHost then
    local loadedPlayers = {} ---@type table<number, string> src -> charId last reported loaded, so a character switch on the same src re-fires playerLoad.

    local function announcePlayerLoaded(src, identifier)
        src = tonumber(src)
        if not src or not identifier or loadedPlayers[src] == identifier then
            return false
        end
        loadedPlayers[src] = identifier
        TriggerEvent('Newb_Bridge:server:playerLoaded', src)
        TriggerEvent('Newb_Bridge:server:playerLoad', src) -- deprecated 2026-12-17: use Newb_Bridge:server:playerLoaded
        return true
    end

    local function loadPlayer(src, data)
        src = tonumber(src)
        data = data or getData(src)
        if not src or not data then return end

        if data.job then
            dutyCache.syncOnDutyPlayer(src, data.job)
        end
        syncBridgePlayer(src)
        announcePlayerLoaded(src, data.citizenid)
    end

    local function unloadPlayer(src)
        src = tonumber(src)
        if not src then return end

        loadedPlayers[src] = nil
        dutyCache.clearOnDutyPlayer(src)
        BridgePlayers.remove(src)
        TriggerEvent('Newb_Bridge:server:playerUnloaded', src)
        TriggerEvent('Newb_Bridge:server:playerUnload', src) -- deprecated 2026-12-17: use Newb_Bridge:server:playerUnloaded
    end

    -- Characters already loaded when the bridge starts (resource restart).
    CreateThread(function()
        for _, playerSrc in ipairs(kora:getPlayers() or {}) do
            loadPlayer(playerSrc)
        end
        dutyCache.syncGlobalJobCounts()
    end)

    -- Fires after the character is adopted, before the client snapshot is sent.
    AddEventHandler('kora_core:server:playerLoaded', function(src, citizenid)
        src = tonumber(src)
        if not src then return end

        local data = getData(src)
        if data and data.job then
            dutyCache.syncOnDutyPlayer(src, data.job)
        end
        syncBridgePlayer(src)
        announcePlayerLoaded(src, citizenid or (data and data.citizenid))
    end)

    -- Job and duty changes are both writes under PlayerData.job.
    kora:onChange({ 'job' }, function(src)
        src = tonumber(src)
        if not src then return end

        local job = kora:getJob(src)
        if not job then return end

        dutyCache.syncOnDutyPlayer(src, job)
        syncBridgePlayer(src)
        TriggerEvent('Newb_Bridge:server:playerJobUpdated', src, job.name)
        TriggerEvent('Newb_Bridge:server:playerJobUpdate', src, job.name) -- deprecated 2026-12-17: use Newb_Bridge:server:playerJobUpdated
    end)

    -- A disconnect. kora_core does not raise this on logout or character switch.
    AddEventHandler('kora_core:server:playerDropped', function(src)
        unloadPlayer(src)
    end)

    -- Logout / character switch: kora_core exposes no native event for it, so
    -- this is the one place the bridge listens to its legacy unload event. It
    -- also fires on disconnect; unloadPlayer is idempotent.
    AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
        unloadPlayer(src)
    end)

    AddEventHandler('playerDropped', function()
        unloadPlayer(source)
    end)
end

-- With kora_inventory running it owns the use path, so handlers go to its own
-- useable table (kora_core keeps a separate one for staged rollouts without an
-- inventory provider). Handlers are owned by the registering resource (the
-- bridge host) and cannot be unregistered, so nil handlers are ignored:
-- registerItemUse's own wrapper skips items whose owner resource has stopped.
ServerHelpers.attachSharedFrameworkApi(framework, dutyCache, function(itemName, handler)
    if not handler then return end

    if GetResourceState('kora_inventory') == 'started' then
        return exports.kora_inventory:createUseable(itemName, handler)
    end

    return kora:createUseable(itemName, handler)
end)

return BridgePlayers.attachBridgePlayerApi(framework)
