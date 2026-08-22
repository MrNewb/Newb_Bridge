local BridgePlayers = require '@Newb_Bridge/modules/framework/player_registry'
local ServerHelpers = require '@Newb_Bridge/modules/framework/server_helpers'

local QBCore = exports['qb-core']:GetCoreObject()
local framework = {}

-- qb-core fires this after runtime AddJob/AddItems/etc.; re-pull so the copied
-- Shared tables stay current. Server-internal only (not a net event).
AddEventHandler('QBCore:Server:UpdateObject', function()
    QBCore = exports['qb-core']:GetCoreObject()
end)

local dutyCache = ServerHelpers.createDutyCache(function(job)
    return job.onduty == true
end)

local function syncBridgePlayer(src)
    local player = QBCore.Functions.GetPlayer(src)
    local data = BridgePlayers.buildQbBridgePlayerData(player)
    if data then
        BridgePlayers.sync(src, data)
    end
end

function framework.getIdentifier(src)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return nil end

    if not player.PlayerData then return nil end

    return player.PlayerData.citizenid
end

function framework.getSrcFromIdentifier(identifier)
    local player = QBCore.Functions.GetPlayerByCitizenId(identifier)
    if not player then return nil end

    if not player.PlayerData then return nil end

    return player.PlayerData.source
end

function framework.getCharacterName(identifier)
    local player = QBCore.Functions.GetPlayerByCitizenId(identifier)
    if not player or not player.PlayerData then return nil end

    local charInfo = player.PlayerData.charinfo
    if not charInfo or not charInfo.firstname or not charInfo.lastname then return nil end

    return ("%s %s"):format(charInfo.firstname, charInfo.lastname), charInfo.firstname, charInfo.lastname
end

function framework.getFrameworkJobs()
    -- Keyed by job name — consumers look up jobs[jobName] (Prescriptions, MultiJob, AdminMenu).
    return QBCore.Shared.Jobs or {}
end

function framework.isAdmin(src)
    if type(src) == "number" then src = tostring(src) end

    local isAdmin = QBCore.Functions.HasPermission(src, 'admin')
    local isGod = QBCore.Functions.HasPermission(src, 'god')
    local isAceAllowed = IsPlayerAceAllowed(src, 'command')

    -- Normalize to a real boolean: ACE natives may return 1/0, and `1 == true` is false in Lua.
    return (isAdmin or isGod or isAceAllowed) and true or false
end

function framework.setMetadata(src, payload)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end

    for key, data in pairs(payload) do
        if data.type == "add" or data.type == "remove" then
            local currentValue = player.Functions.GetMetaData(key) or 0
            local newValue = data.type == "add" and (currentValue + data.value) or (currentValue - data.value)

            player.Functions.SetMetaData(key, lib.math.clamp(newValue, 0, 100))
        else
            player.Functions.SetMetaData(key, data.value)
        end
    end
end

function framework.getPlayerMetadata(src, key)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end

    return player.Functions.GetMetaData(key)
end

function framework.addMoney(src, moneyType, moneyAmount, reason)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return false end
    if moneyType == 'money' then moneyType = 'cash' end

    return player.Functions.AddMoney(moneyType, moneyAmount, reason)
end

function framework.removeMoney(src, moneyType, moneyAmount, reason)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return false end
    if moneyType == 'money' then moneyType = 'cash' end

    return player.Functions.RemoveMoney(moneyType, moneyAmount, reason)
end

function framework.getMoney(src, moneyType)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return 0 end
    if moneyType == 'money' then moneyType = 'cash' end

    return player.Functions.GetMoney(moneyType)
end

function framework.getPlayerJobData(src)
    local player = QBCore.Functions.GetPlayer(src)
    if not player or not player.PlayerData or not player.PlayerData.job then return nil end

    local job = player.PlayerData.job
    return {
        jobName = job.name,
        jobLabel = job.label,
        grade = job.grade.level,
        gradeName = job.grade.name,
        onDuty = job.onduty,
        isBoss = job.isboss,
    }
end

function framework.hasJob(src, job, grade, duty)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then
        return false
    end

    local jobId = player.PlayerData.job.name
    if jobId ~= job then
        return false
    end

    if grade then
        local gradeId = player.PlayerData.job.grade.level
        if gradeId < grade then
            return false
        end
    end

    if duty then
        if not player.PlayerData.job.onduty then
            return false
        end
    end

    return true
end

function framework.setPlayerDuty(src, onDuty)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return false end

    -- SetJobDuty fires QBCore:Server:SetDuty; that handler syncs duty cache + BridgePlayers.
    player.Functions.SetJobDuty(onDuty)
    return true
end

function framework.setPlayerJob(src, name, grade)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return false end

    return player.Functions.SetJob(name, grade) ~= nil
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
        local player = QBCore.Functions.GetPlayer(playerSrc)
        if player and player.PlayerData and player.PlayerData.job and player.PlayerData.job.name == jobName then
            sources[#sources + 1] = playerSrc
        end
    end
    return sources
end

function framework.addHunger(src, value)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return nil end

    local newHunger = lib.math.clamp((player.PlayerData.metadata.hunger or 0) + value, 0, 100)
    player.Functions.SetMetaData('hunger', newHunger)
    TriggerClientEvent('hud:client:UpdateNeeds', src, newHunger, player.PlayerData.metadata.thirst)
    return newHunger
end

function framework.addThirst(src, value)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return nil end

    local newThirst = lib.math.clamp((player.PlayerData.metadata.thirst or 0) + value, 0, 100)
    player.Functions.SetMetaData('thirst', newThirst)
    TriggerClientEvent('hud:client:UpdateNeeds', src, player.PlayerData.metadata.hunger, newThirst)
    return newThirst
end

function framework.getOwnedVehicles(src)
    local identifier = framework.getIdentifier(src)
    if not identifier then return {} end

    local result = MySQL.query.await('SELECT vehicle, plate FROM player_vehicles WHERE citizenid = ?', { identifier })
    if not result then return {} end

    local vehicles = {}
    for i = 1, #result do
        vehicles[#vehicles + 1] = { vehicle = result[i].vehicle, plate = result[i].plate }
    end
    return vehicles
end

function framework.getPlayers()
    return QBCore.Functions.GetPlayers()
end

function framework.getPlayerDob(src)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return nil end
    return player.PlayerData.charinfo and player.PlayerData.charinfo.birthdate
end

if bridge.isHost then
    -- Seed the duty cache from players already online (bridge restart) and
    -- publish a fresh GlobalState snapshot, clearing stale counts from a
    -- previous run.
    CreateThread(function()
        for _, playerSrc in ipairs(QBCore.Functions.GetPlayers()) do
            local player = QBCore.Functions.GetPlayer(playerSrc)
            if player and player.PlayerData and player.PlayerData.job then
                dutyCache.syncOnDutyPlayer(playerSrc, player.PlayerData.job)
                syncBridgePlayer(playerSrc)
            end
        end
        dutyCache.syncGlobalJobCounts()
    end)

    RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
        local src = source
        local player = QBCore.Functions.GetPlayer(src)
        if player and player.PlayerData and player.PlayerData.job then
            dutyCache.syncOnDutyPlayer(src, player.PlayerData.job)
        end

        syncBridgePlayer(src)

        local stateId = framework.getIdentifier(src)
        if not stateId then return end
        TriggerEvent('Newb_Bridge:server:playerLoad', src)
    end)

    AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
        TriggerEvent('Newb_Bridge:server:playerUnload', src)
    end)

    AddEventHandler('QBCore:Server:OnJobUpdate', function(src, job)
        if not src or not job then return end
        dutyCache.syncOnDutyPlayer(src, job)
        syncBridgePlayer(src)
        TriggerEvent('Newb_Bridge:server:playerJobUpdate', src, job.name)
    end)

    AddEventHandler('QBCore:Server:SetDuty', function(src, _)
        src = tonumber(src)
        if not src then return end

        local player = QBCore.Functions.GetPlayer(src)
        if player and player.PlayerData and player.PlayerData.job then
            dutyCache.syncOnDutyPlayer(src, player.PlayerData.job)
            syncBridgePlayer(src)
        end
    end)

    AddEventHandler('playerDropped', function()
        local src = source
        TriggerEvent('Newb_Bridge:server:playerUnload', src)
    end)

    AddEventHandler('Newb_Bridge:server:playerUnload', function(src)
        src = tonumber(src)
        if not src then return end
        dutyCache.clearOnDutyPlayer(src)
        BridgePlayers.remove(src)
    end)
end

ServerHelpers.attachSharedFrameworkApi(framework, dutyCache, function(itemName, handler)
    return QBCore.Functions.CreateUseableItem(itemName, handler)
end)

return BridgePlayers.attachBridgePlayerApi(framework)
