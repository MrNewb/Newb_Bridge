local BridgePlayers = require '@Newb_Bridge/modules/framework/player_registry'
local ServerHelpers = require '@Newb_Bridge/modules/framework/server_helpers'

local ESX = exports.es_extended:getSharedObject()
local framework = {}

local dutyCache = ServerHelpers.createDutyCache(function(job)
    return job.onduty ~= false
end)

local function syncBridgePlayer(src)
    local player = ESX.GetPlayerFromId(src)
    local data = BridgePlayers.buildEsxBridgePlayerData(player)
    if data then
        BridgePlayers.sync(src, data)
    end
end

function framework.getIdentifier(src)
    local player = ESX.GetPlayerFromId(src)
    if not player then return nil end

    return player.getIdentifier()
end

function framework.getSrcFromIdentifier(identifier)
    local player = ESX.GetPlayerFromIdentifier(identifier)
    if not player then return nil end

    return player.source
end

function framework.getCharacterName(identifier)
    local player = ESX.GetPlayerFromIdentifier(identifier)
    if not player then return nil end

    local first = player.variables and player.variables.firstName
    local last = player.variables and player.variables.lastName
    if first and last then
        return ("%s %s"):format(first, last), first, last
    end

    local name = player.name
    if type(name) ~= 'string' then return nil end

    -- Best-effort split of the display name when structured first/last are absent.
    local splitFirst, splitLast = name:match('^(%S+)%s+(.+)$')
    return name, splitFirst or name, splitLast
end

function framework.getFrameworkJobs()
    -- Keyed by job name — consumers look up jobs[jobName].
    return ESX.GetJobs() or {}
end

function framework.isAdmin(src)
    local id = tonumber(src)
    if not id then return false end

    local player = ESX.GetPlayerFromId(id)
    if player and player.isAdmin then
        return player.isAdmin() and true or false
    end

    -- Fallback when the player isn't loaded yet, or on older ESX without xPlayer.isAdmin.
    local aceSrc = tostring(id)
    return (IsPlayerAceAllowed(aceSrc, 'command')
        or IsPlayerAceAllowed(aceSrc, 'group.admin')) and true or false
end

function framework.setMetadata(src, payload)
    local player = ESX.GetPlayerFromId(src)
    if not player then return end

    for key, data in pairs(payload) do
        if data.type == "add" or data.type == "remove" then
            local currentValue = player.getMeta(key) or 0
            local newValue = data.type == "add" and (currentValue + data.value) or (currentValue - data.value)

            player.setMeta(key, lib.math.clamp(newValue, 0, 100))
        else
            player.setMeta(key, data.value)
        end
    end
end

function framework.getPlayerMetadata(src, key)
    local player = ESX.GetPlayerFromId(src)
    if not player then return end

    return player.getMeta(key)
end

function framework.addMoney(src, moneyType, moneyAmount, reason)
    local player = ESX.GetPlayerFromId(src)
    if not player then return false end

    if moneyType == "cash" then
        ---@diagnostic disable-next-line
        moneyType = "money"
    end

    player.addAccountMoney(moneyType, moneyAmount, reason)
    return true
end

function framework.getMoney(src, moneyType)
    local player = ESX.GetPlayerFromId(src)
    if not player then return 0 end

    if moneyType == "cash" then
        ---@diagnostic disable-next-line
        moneyType = "money"
    end

    local account = player.getAccount(moneyType)
    if not account then return 0 end

    return account.money
end

function framework.removeMoney(src, moneyType, moneyAmount, reason)
    local player = ESX.GetPlayerFromId(src)
    if not player then return false end

    if moneyType == "cash" then
        ---@diagnostic disable-next-line
        moneyType = "money"
    end

    local account = player.getAccount(moneyType)
    if not account or account.money < moneyAmount then return false end

    player.removeAccountMoney(moneyType, moneyAmount, reason)
    return true
end

function framework.getPlayerJobData(src)
    local player = ESX.GetPlayerFromId(src)
    if not player then return nil end

    local job = player.getJob and player.getJob() or player.job
    if not job then return nil end

    return {
        jobName = job.name,
        jobLabel = job.label,
        grade = job.grade,
        gradeName = job.grade_label or job.grade_name,
        onDuty = job.onduty ~= false,
        isBoss = job.grade_name == 'boss',
    }
end

function framework.hasJob(src, job, grade, duty)
    local player = ESX.GetPlayerFromId(src)
    if not player then return false end

    local playerJob = player.getJob()

    local jobId = playerJob.name
    if jobId ~= job then return false end

    if grade then
        local gradeId = playerJob.grade
        if gradeId < grade then return false end
    end

    if duty then if playerJob.onduty == false then return false end end

    return true
end

function framework.setPlayerDuty(src, onDuty)
    local player = ESX.GetPlayerFromId(src)
    if not player then return false end

    local job = player.getJob()
    if job.name == 'unemployed' then return false end

    player.setJob(job.name, job.grade, onDuty)
    dutyCache.syncOnDutyPlayer(src, player.getJob())
    return true
end

function framework.setPlayerJob(src, name, grade)
    local player = ESX.GetPlayerFromId(src)
    if not player then return false end

    if not ESX.DoesJobExist(name, grade) then return false end

    player.setJob(name, grade, true)
    return true
end

function framework.getPlayersByJob(jobName)
    local sources = {}

    -- The duty cache sync events only register inside the bridge resource;
    -- consumer copies of this module have an empty cache and must query the
    -- framework directly.
    if bridge.isHost then
        for src in pairs(dutyCache.getPlayersWithJob(jobName)) do
            sources[#sources + 1] = src
        end
        table.sort(sources)
        return sources
    end

    for _, playerSrc in ipairs(framework.getPlayers()) do
        local player = ESX.GetPlayerFromId(playerSrc)
        local job = player and player.getJob and player.getJob()
        if job and job.name == jobName then
            sources[#sources + 1] = playerSrc
        end
    end
    return sources
end

-- `value` is percent points (negative subtracts), matching the QB modules.
function framework.addHunger(src, value)
    -- esx_status stores 0-1,000,000 where 1% = 10,000.
    local percent = lib.math.clamp(tonumber(value) or 0, -100, 100)
    TriggerClientEvent('esx_status:add', src, 'hunger', percent * 10000)
    return percent
end

-- `value` is percent points (negative subtracts), matching the QB modules.
function framework.addThirst(src, value)
    local percent = lib.math.clamp(tonumber(value) or 0, -100, 100)
    TriggerClientEvent('esx_status:add', src, 'thirst', percent * 10000)
    return percent
end

function framework.getOwnedVehicles(src)
    local identifier = framework.getIdentifier(src)
    if not identifier then return {} end

    local result = MySQL.query.await('SELECT vehicle, plate FROM owned_vehicles WHERE owner = ?', { identifier })
    if not result then return {} end

    local vehicles = {}
    for i = 1, #result do
        local row = result[i]
        local model = row.vehicle
        local decoded = json.decode(row.vehicle)
        if decoded and decoded.model then
            model = decoded.model
        end
        vehicles[#vehicles + 1] = { vehicle = model, plate = row.plate }
    end
    return vehicles
end

function framework.getPlayers()
    if ESX.GetPlayers ~= nil then
        return ESX.GetPlayers()
    end
    local playerList = {}
    local players = ESX.GetExtendedPlayers()
    for _, player in ipairs(players) do
        playerList[#playerList + 1] = tonumber(player.source)
    end
    return playerList
end

function framework.getPlayerDob(src)
    local player = ESX.GetPlayerFromId(src)
    if not player then return nil end
    return player.get("dateofbirth")
end

if bridge.isHost then
    -- Seed the duty cache from players already online (bridge restart) and
    -- publish a fresh GlobalState snapshot, clearing stale counts from a
    -- previous run.
    CreateThread(function()
        for _, playerSrc in ipairs(framework.getPlayers()) do
            local player = ESX.GetPlayerFromId(playerSrc)
            if player then
                dutyCache.syncOnDutyPlayer(playerSrc, player.getJob())
                syncBridgePlayer(playerSrc)
            end
        end
        dutyCache.syncGlobalJobCounts()
    end)

    AddEventHandler('esx:playerLoaded', function(src)
        src = tonumber(src)
        if not src then return end

        local player = ESX.GetPlayerFromId(src)
        if player then
            dutyCache.syncOnDutyPlayer(src, player.getJob())
            syncBridgePlayer(src)
        end

        local stateId = framework.getIdentifier(src)
        if not stateId then return end

        -- Defer one tick so the bridge player sync above is settled for listeners.
        SetTimeout(0, function()
            TriggerEvent('Newb_Bridge:server:playerLoad', src)
        end)
    end)

    AddEventHandler("esx:playerLogout", function(src)
        TriggerEvent("Newb_Bridge:server:playerUnload", src)
    end)

    AddEventHandler("esx:setJob", function(src, job)
        src = tonumber(src)
        if not src or not job then return end
        dutyCache.syncOnDutyPlayer(src, job)
        syncBridgePlayer(src)
        TriggerEvent('Newb_Bridge:server:playerJobUpdate', src, job.name)
    end)

    AddEventHandler("playerDropped", function()
        local src = tonumber(source)
        if not src then return end
        TriggerEvent('Newb_Bridge:server:playerUnload', src)
    end)

    AddEventHandler("Newb_Bridge:server:playerUnload", function(src)
        src = tonumber(src)
        if not src then return end
        dutyCache.clearOnDutyPlayer(src)
        BridgePlayers.remove(src)
    end)

    lib.callback.register('Newb_Bridge:callback:getFrameworkJobs', function()
        return framework.getFrameworkJobs()
    end)
end

ServerHelpers.attachSharedFrameworkApi(framework, dutyCache, function(itemName, handler)
    return ESX.RegisterUsableItem(itemName, handler)
end)

return BridgePlayers.attachBridgePlayerApi(framework)
