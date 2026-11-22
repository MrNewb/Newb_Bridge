-- whip_core framework provider (server). Uses whip_core's own exports only.
--
-- Differences from the other frameworks that this file hides:
--  * The character identifier is the charId, returned as text so it compares equal to a varchar column. Numbers are
--    accepted wherever an identifier is passed in.
--  * A Whip character can work at several jobs and is on duty at (usually) one. The bridge's single "job" is the job
--    they are on duty at, else the job where their role is highest.
--  * Grades are the job's roles ordered by level, lowest first, numbered from zero like every other bridge framework.
--  * Cash is an item and the bank is an account, so money goes through PayPlayer and ChargePlayer. 'crypto' does not exist.
--  * Whip forgets nothing about a player, so the bridge cache is rebuilt from Whip's own events.

local BridgePlayers = require '@Newb_Bridge/resource/modules/framework/player_registry'
local ServerHelpers = require '@Newb_Bridge/resource/modules/framework/server_helpers'

local whip = exports.whip_core
local framework = {}

local MONEY_METHODS = { cash = 'cash', money = 'cash', bank = 'bank' }
local NEED_STATS = { hunger = true, thirst = true }

local function asCharId(identifier)
    return tonumber(identifier)
end

local function getCharId(src)
    src = tonumber(src)
    if not src then return nil end
    return whip:GetCharId(src)
end

local function sortedRoles(jobKey)
    local roles = whip:GetJobRoles(jobKey)
    if type(roles) ~= 'table' then return nil end

    table.sort(roles, function(a, b) return a.level < b.level end)
    return roles
end

local function gradeOfRole(jobKey, roleId)
    local roles = sortedRoles(jobKey)
    if not roles then return nil end

    for index, role in ipairs(roles) do
        if role.roleId == roleId then return index - 1, role end
    end
end

local function isBossRole(role)
    return role ~= nil and (role.level >= 100 or (role.permissions ~= nil and role.permissions.canManage == true))
end

---The job the bridge reports for a player: the one they are on duty at, else where their role is highest.
local function primaryJob(src)
    local onDuty = whip:GetPlayerJob(src)
    if onDuty then
        onDuty.clockedOn = true
        return onDuty
    end

    local best
    for _, info in pairs(whip:GetPlayerJobs(src) or {}) do
        if not best or info.roleLevel > best.roleLevel then best = info end
    end
    return best
end

local function jobData(src)
    local info = primaryJob(src)
    if not info then return nil end

    local grade, role = gradeOfRole(info.key, info.roleId)
    return {
        jobName = info.key,
        jobLabel = info.name,
        grade = grade or 0,
        gradeName = info.roleName,
        onDuty = info.clockedOn == true,
        isBoss = isBossRole(role),
    }
end

---Every job the player holds, keyed by job key, shaped like jobData. The client has no way to number grades, so the host
---sends it this after every change.
local function allJobData(src)
    local jobs = {}
    for _, info in pairs(whip:GetPlayerJobs(src) or {}) do
        local grade, role = gradeOfRole(info.key, info.roleId)
        jobs[info.key] = {
            jobName = info.key,
            jobLabel = info.name,
            grade = grade or 0,
            gradeName = info.roleName,
            onDuty = info.clockedOn == true,
            isBoss = isBossRole(role),
        }
    end
    return jobs
end

local dutyCache = ServerHelpers.createDutyCache(function(job)
    return job.onDuty == true
end)

local function buildPlayerData(src)
    local charId = getCharId(src)
    if not charId then return nil end

    local job = primaryJob(src)
    return {
        charId = tostring(charId),
        name = whip:GetPlayerFullName(src) or '',
        jobName = job and job.key,
        onDuty = job ~= nil and job.clockedOn == true,
    }
end

local function syncBridgePlayer(src)
    local data = buildPlayerData(src)
    if data then BridgePlayers.sync(src, data) end
end

local function syncJob(src)
    local job = primaryJob(src)
    if job then
        dutyCache.syncOnDutyPlayer(src, { name = job.key, onDuty = job.clockedOn == true })
    else
        dutyCache.clearOnDutyPlayer(src)
    end
    syncBridgePlayer(src)
    return job
end

function framework.getIdentifier(src)
    local charId = getCharId(src)
    return charId and tostring(charId) or nil
end

function framework.getSrcFromIdentifier(identifier)
    local charId = asCharId(identifier)
    if not charId then return nil end

    local player = whip:GetPlayer({ charId = charId })
    return player and player.source or nil
end

function framework.getCharacterName(identifier)
    local charId = asCharId(identifier)
    if not charId then return nil end

    local info = whip:GetCharacterInfo({ charId })
    local entry = info and info[charId]
    if not entry then return nil end

    return entry.fullName, entry.firstName, entry.lastName
end

-- Keyed by job key with zero-based grade keys, matching the other providers.
function framework.getFrameworkJobs()
    local jobs = {}

    for _, def in ipairs(whip:GetJobs() or {}) do
        local grades = {}
        for index, role in ipairs(sortedRoles(def.key) or {}) do
            grades[index - 1] = { name = role.name, level = role.level, isboss = isBossRole(role), permissions = role.permissions }
        end

        jobs[def.key] = {
            label = def.name,
            type = def.key,
            defaultDuty = false,
            offDutyPay = false,
            grades = grades,
        }
    end

    return jobs
end

function framework.isAdmin(src)
    src = tonumber(src)
    if not src then return false end

    return (whip:HasDevTools(src) or IsPlayerAceAllowed(tostring(src), 'command')) and true or false
end

local function setNeed(src, key, value)
    return whip:SetStat(src, key, value, 'Newb_Bridge') == true
end

local function changeNeed(src, key, delta)
    if not whip:AddStat(src, key, delta, 'Newb_Bridge') then return nil end
    return tonumber(whip:GetStat(src, key))
end

function framework.setMetadata(src, payload)
    if type(payload) ~= 'table' or not getCharId(src) then return end

    for key, data in pairs(payload) do
        if type(data) == 'table' then
            if NEED_STATS[key] then
                local delta = tonumber(data.value)
                if delta then
                    if data.type == 'set' then
                        setNeed(src, key, delta)
                    else
                        changeNeed(src, key, data.type == 'remove' and -delta or delta)
                    end
                end
            elseif data.type == 'add' or data.type == 'remove' then
                local delta = tonumber(data.value)
                if delta then
                    local current = tonumber(whip:GetPlayerMetadata(src, key)) or 0
                    whip:SetPlayerMetadata(src, key, data.type == 'add' and current + delta or current - delta)
                end
            else
                whip:SetPlayerMetadata(src, key, data.value)
            end
        end
    end
end

function framework.getPlayerMetadata(src, key)
    if not getCharId(src) then return nil end
    if NEED_STATS[key] then return whip:GetStat(src, key) end
    return whip:GetPlayerMetadata(src, key)
end

function framework.addMoney(src, moneyType, moneyAmount, reason)
    local method = MONEY_METHODS[moneyType]
    local amount = tonumber(moneyAmount)
    if not method or not amount or amount < 0 or not getCharId(src) then return false end

    return whip:PayPlayer(src, math.floor(amount), { method = method, reason = reason }) ~= false
end

function framework.removeMoney(src, moneyType, moneyAmount, reason)
    local method = MONEY_METHODS[moneyType]
    local amount = tonumber(moneyAmount)
    if not method or not amount or amount < 0 or not getCharId(src) then return false end

    return whip:ChargePlayer(src, math.floor(amount), { method = method, reason = reason }) ~= false
end

function framework.getMoney(src, moneyType)
    local method = MONEY_METHODS[moneyType]
    if not method or not getCharId(src) then return 0 end

    if method == 'cash' then return whip:GetPlayerCash(src) or 0 end
    return whip:GetBalance(src) or 0
end

function framework.getPlayerJobData(src)
    src = tonumber(src)
    if not src or not getCharId(src) then return nil end
    return jobData(src)
end

function framework.hasJob(src, job, grade, duty)
    src = tonumber(src)
    if not src or not getCharId(src) then return false end

    local role = whip:GetPlayerRole(src, job)
    if not role then return false end

    if grade then
        local level = gradeOfRole(job, role.roleId)
        if not level or level < grade then return false end
    end

    if duty and not whip:IsPlayerClockedOn(src, job) then return false end

    return true
end

function framework.setPlayerDuty(src, onDuty)
    src = tonumber(src)
    if not src or not getCharId(src) then return false end

    local job = primaryJob(src)
    if not job then return false end

    if onDuty == true then
        return whip:ClockOn(src, job.key) == true
    end

    return whip:ClockOff(src, job.key) == true
end

-- Hires the player at the job (or changes their role there). The job and a role at that grade must already exist; the
-- bridge never creates jobs.
function framework.setPlayerJob(src, name, grade)
    src = tonumber(src)
    if not src or not getCharId(src) or not whip:GetJob(name) then return false end

    local role = (sortedRoles(name) or {})[(tonumber(grade) or 0) + 1]
    if not role then return false end

    local works = whip:GetPlayerRole(src, name)
    if works then
        return whip:SetPlayerRole(src, name, role.roleId) == true
    end

    return whip:HirePlayer(src, name, role.roleId) == true
end

function framework.getPlayersByJob(jobName)
    if bridge.isHost then
        local sources = {}
        for src in pairs(dutyCache.getPlayersWithJob(jobName)) do
            sources[#sources + 1] = src
        end
        table.sort(sources)
        return sources
    end

    local sources = {}
    for _, employee in pairs(whip:GetJobEmployees(jobName) or {}) do
        if employee.source then sources[#sources + 1] = employee.source end
    end
    table.sort(sources)
    return sources
end

function framework.addHunger(src, value)
    if not getCharId(src) then return nil end
    return changeNeed(src, 'hunger', tonumber(value) or 0)
end

function framework.addThirst(src, value)
    if not getCharId(src) then return nil end
    return changeNeed(src, 'thirst', tonumber(value) or 0)
end

function framework.getOwnedVehicles(src)
    local vehicles = {}
    for _, row in ipairs(whip:GetVehiclesOf(tonumber(src)) or {}) do
        vehicles[#vehicles + 1] = { vehicle = row.model, plate = row.plate }
    end
    return vehicles
end

function framework.getPlayers()
    local sources = {}
    for src in pairs(whip:GetPlayers({ light = true }) or {}) do
        sources[#sources + 1] = src
    end
    table.sort(sources)
    return sources
end

function framework.getPlayerDob(src)
    local player = getCharId(src) and whip:GetPlayer(tonumber(src))
    return player and player.dateOfBirth or nil
end

-- framework is always proxied through the host export (see import.lua's hostBacked table), so this block only runs
-- once, inside the bridge host.
if bridge.isHost then
    local loadedPlayers = {} ---@type table<number, number> src -> charId last reported loaded

    local function announcePlayerLoaded(src, charId)
        if not src or not charId or loadedPlayers[src] == charId then return end

        loadedPlayers[src] = charId
        TriggerEvent('Newb_Bridge:server:playerLoaded', src)
        TriggerEvent('Newb_Bridge:server:playerLoad', src) -- deprecated 2026-12-17: use Newb_Bridge:server:playerLoaded
    end

    local function pushJobs(src)
        TriggerClientEvent('Newb_Bridge:client:whipJobsChanged', src, jobData(src), allJobData(src))
    end

    local function loadPlayer(src)
        src = tonumber(src)
        local charId = src and getCharId(src)
        if not charId then return end

        syncJob(src)
        pushJobs(src)
        announcePlayerLoaded(src, charId)
    end

    local function unloadPlayer(src)
        src = tonumber(src)
        if not src or not loadedPlayers[src] then return end

        loadedPlayers[src] = nil
        dutyCache.clearOnDutyPlayer(src)
        BridgePlayers.remove(src)
        TriggerEvent('Newb_Bridge:server:playerUnloaded', src)
        TriggerEvent('Newb_Bridge:server:playerUnload', src) -- deprecated 2026-12-17: use Newb_Bridge:server:playerUnloaded
    end

    local function updateJob(src)
        src = tonumber(src)
        if not src or not loadedPlayers[src] then return end

        local job = syncJob(src)
        pushJobs(src)
        if job then
            TriggerEvent('Newb_Bridge:server:playerJobUpdated', src, job.key)
            TriggerEvent('Newb_Bridge:server:playerJobUpdate', src, job.key) -- deprecated 2026-12-17: use Newb_Bridge:server:playerJobUpdated
        end
        dutyCache.syncGlobalJobCounts()
    end

    -- Characters already loaded when the bridge starts (resource restart).
    CreateThread(function()
        while GetResourceState('whip_core') ~= 'started' or not whip:IsReady() do Wait(250) end

        for src in pairs(whip:GetPlayers({ light = true }) or {}) do
            loadPlayer(src)
        end
        dutyCache.syncGlobalJobCounts()
    end)

    AddEventHandler('whip_core:player:loaded', function(info)
        if type(info) == 'table' then loadPlayer(info.source) end
    end)

    AddEventHandler('whip_core:player:logout', function(info)
        if type(info) == 'table' then unloadPlayer(info.source) end
    end)

    -- A job event carries the person when it is about one; clock on and off, hiring, firing and a new role all change
    -- the job the bridge reports.
    for _, name in ipairs({ 'clockedOn', 'clockedOff', 'hired', 'fired', 'roleChanged' }) do
        AddEventHandler(('whip_core:job:%s'):format(name), function(info)
            if type(info) == 'table' then updateJob(info.source) end
        end)
    end

    AddEventHandler('playerDropped', function()
        unloadPlayer(source)
    end)

    -- A client that started after its character loaded (the bridge restarted) asks for what it missed.
    RegisterNetEvent('Newb_Bridge:server:whipJobsRequested', function()
        local src = source
        if getCharId(src) then pushJobs(src) end
    end)

    lib.callback.register('Newb_Bridge:server:whipFrameworkJobs', function()
        return framework.getFrameworkJobs()
    end)
end

-- Whip forgets use handlers when whip_core restarts, so the ones registered here are declared again each time it says
-- it started. Handlers belong to the registering resource (the bridge host); a nil handler is ignored because the
-- shared wrapper already skips items whose owner resource has stopped.
--
-- Whip uses one item up when a handler returns anything but false. Use handlers written for the bridge take the item
-- themselves (as on QBCore and ESX), so this always answers false and Whip leaves the stack alone.
local useHandlers = {} ---@type table<string, function>

local function declareUseHandler(itemName, handler)
    whip:RegisterUseHandler(itemName, function(src, _, slotData, addr)
        handler(src, {
            name = itemName,
            count = slotData and slotData.amount or 1,
            metadata = slotData and slotData.metadata or {},
            slot = addr and addr.slot,
        })
        return false
    end)
end

if bridge.isHost then
    AddEventHandler('whip_core:onReady', function(info)
        if type(info) ~= 'table' or info.reason ~= 'coreStarted' then return end

        for itemName, handler in pairs(useHandlers) do
            declareUseHandler(itemName, handler)
        end
    end)
end

ServerHelpers.attachSharedFrameworkApi(framework, dutyCache, function(itemName, handler)
    if not handler then
        useHandlers[itemName] = nil
        return
    end

    useHandlers[itemName] = handler
    declareUseHandler(itemName, handler)
end)

return BridgePlayers.attachBridgePlayerApi(framework)
