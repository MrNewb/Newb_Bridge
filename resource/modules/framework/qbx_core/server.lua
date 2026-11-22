local BridgePlayers = require '@Newb_Bridge/resource/modules/framework/player_registry'
local ServerHelpers = require '@Newb_Bridge/resource/modules/framework/server_helpers'

local framework = {}

local dutyCache = ServerHelpers.createDutyCache(function(job)
    return job.onduty == true
end)

local function syncBridgePlayer(src)
    local player = exports.qbx_core:GetPlayer(src)
    local data = BridgePlayers.buildQbBridgePlayerData(player)
    if data then
        BridgePlayers.sync(src, data)
    end
end

function framework.getIdentifier(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return nil end

    if not player.PlayerData then return nil end

    return player.PlayerData.citizenid
end

function framework.getSrcFromIdentifier(identifier)
    local player = exports.qbx_core:GetPlayerByCitizenId(identifier)
    if not player then return nil end

    if not player.PlayerData then return nil end

    return player.PlayerData.source
end

function framework.getCharacterName(identifier)
    local player = exports.qbx_core:GetPlayerByCitizenId(identifier)
    if not player or not player.PlayerData then return nil end

    local charInfo = player.PlayerData.charinfo
    if not charInfo or not charInfo.firstname or not charInfo.lastname then return nil end

    return ("%s %s"):format(charInfo.firstname, charInfo.lastname), charInfo.firstname, charInfo.lastname
end

function framework.getFrameworkJobs()
    -- Keyed by job name - consumers look up jobs[jobName] (Prescriptions, MultiJob, AdminMenu).
    return exports.qbx_core:GetJobs() or {}
end

function framework.isAdmin(src)
    if type(src) == "number" then src = tostring(src) end

    -- Normalize to a real boolean: ACE natives may return 1/0, and `1 == true` is false in Lua.
    return (IsPlayerAceAllowed(src, 'admin')
        or IsPlayerAceAllowed(src, 'group.admin')
        or IsPlayerAceAllowed(src, 'god')
        or IsPlayerAceAllowed(src, 'group.god')
        or IsPlayerAceAllowed(src, 'command')) and true or false
end

function framework.setMetadata(src, payload)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    if type(payload) ~= 'table' then return end

    for key, data in pairs(payload) do
        if type(data) == 'table' then
            if data.type == "add" or data.type == "remove" then
                local delta = tonumber(data.value)
                if delta then
                    local currentValue = tonumber(exports.qbx_core:GetMetadata(src, key)) or 0
                    local newValue = data.type == "add" and (currentValue + delta) or (currentValue - delta)

                    exports.qbx_core:SetMetadata(src, key, lib.math.clamp(newValue, 0, 100))
                end
            else
                exports.qbx_core:SetMetadata(src, key, data.value)
            end
        end
    end
end

function framework.getPlayerMetadata(src, key)
    return exports.qbx_core:GetMetadata(src, key)
end

function framework.addMoney(src, moneyType, moneyAmount, reason)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end
    if moneyType == 'money' then moneyType = 'cash' end

    return exports.qbx_core:AddMoney(src, moneyType, moneyAmount, reason)
end

function framework.removeMoney(src, moneyType, moneyAmount, reason)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end
    if moneyType == 'money' then moneyType = 'cash' end

    return exports.qbx_core:RemoveMoney(src, moneyType, moneyAmount, reason)
end

function framework.getMoney(src, moneyType)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return 0 end
    if moneyType == 'money' then moneyType = 'cash' end

    return exports.qbx_core:GetMoney(src, moneyType)
end

function framework.getPlayerJobData(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not player.PlayerData or not player.PlayerData.job then return nil end

    local job = player.PlayerData.job
    return {
        jobName = job.name,
        jobLabel = job.label,
        grade = job.grade and job.grade.level,
        gradeName = job.grade and job.grade.name,
        onDuty = job.onduty,
        isBoss = job.isboss,
    }
end

function framework.hasJob(src, job, grade, duty)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end

    local playerJob = player.PlayerData and player.PlayerData.job
    if not playerJob or playerJob.name ~= job then return false end

    if grade then
        local gradeId = playerJob.grade and playerJob.grade.level
        if not gradeId or gradeId < grade then return false end
    end

    if duty and not playerJob.onduty then return false end

    return true
end

function framework.setPlayerDuty(src, onDuty)
    local player = exports.qbx_core:GetPlayer(src)
    if not player or not player.PlayerData then return false end

    -- SetJobDuty fires QBCore:Server:SetDuty; that handler syncs duty cache + BridgePlayers.
    exports.qbx_core:SetJobDuty(player.PlayerData.citizenid, onDuty)
    return true
end

function framework.setPlayerJob(src, name, grade)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return false end

    return player.Functions.SetJob(name, grade) ~= nil
end

function framework.getPlayersByJob(jobName)
    local sources = {}

    -- dutyCache is only ever populated here, inside the bridge host (see the
    -- isHost note above this file's PlayerLoaded wiring); the ipairs fallback
    -- below is insurance for the same hypothetical, not a live code path.
    if bridge.isHost then
        for src in pairs(dutyCache.getPlayersWithJob(jobName)) do
            sources[#sources + 1] = src
        end
        table.sort(sources)
        return sources
    end

    for _, playerSrc in ipairs(framework.getPlayers()) do
        local player = exports.qbx_core:GetPlayer(playerSrc)
        if player and player.PlayerData and player.PlayerData.job and player.PlayerData.job.name == jobName then
            sources[#sources + 1] = playerSrc
        end
    end
    return sources
end

function framework.addHunger(src, value)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return nil end

    local current = tonumber(exports.qbx_core:GetMetadata(src, 'hunger')) or 0
    local newHunger = lib.math.clamp(current + (tonumber(value) or 0), 0, 100)
    exports.qbx_core:SetMetadata(src, 'hunger', newHunger)
    TriggerClientEvent('hud:client:UpdateNeeds', src, newHunger, exports.qbx_core:GetMetadata(src, 'thirst'))
    return newHunger
end

function framework.addThirst(src, value)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return nil end

    local current = tonumber(exports.qbx_core:GetMetadata(src, 'thirst')) or 0
    local newThirst = lib.math.clamp(current + (tonumber(value) or 0), 0, 100)
    exports.qbx_core:SetMetadata(src, 'thirst', newThirst)
    TriggerClientEvent('hud:client:UpdateNeeds', src, exports.qbx_core:GetMetadata(src, 'hunger'), newThirst)
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
    local playerList = {}
    local players = exports.qbx_core:GetQBPlayers()
    for src, _ in pairs(players) do
        playerList[#playerList + 1] = src
    end
    return playerList
end

function framework.getPlayerDob(src)
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return nil end
    return player.PlayerData and player.PlayerData.charinfo and player.PlayerData.charinfo.birthdate
end

-- framework is always proxied through the host export (see import.lua's
-- hostBacked table), so this file only ever loads once, inside the actual
-- bridge host. isHost is checked as insurance against that routing ever
-- changing (it's what stops every importer from separately registering these
-- QBCore event handlers and firing playerLoad once per importer), not
-- because it's expected to be false in normal operation.
if bridge.isHost then
    local loadedPlayers = {} ---@type table<number, string> src -> the charId last reported loaded, so a genuine character switch (new charId, same src) re-fires playerLoad instead of being swallowed by the latch.

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

    local function syncAndAnnounceLoad(src, identifier)
        src = tonumber(src)
        if not src then return end

        local player = exports.qbx_core:GetPlayer(src)
        if player and player.PlayerData and player.PlayerData.job then
            dutyCache.syncOnDutyPlayer(src, player.PlayerData.job)
        end
        syncBridgePlayer(src)

        identifier = identifier or (player and player.PlayerData and player.PlayerData.citizenid) or framework.getIdentifier(src)
        if announcePlayerLoaded(src, identifier) then return end
        if identifier then return end -- already latched for this character; nothing to retry

        SetTimeout(0, function()
            announcePlayerLoaded(src, framework.getIdentifier(src))
        end)
    end

    CreateThread(function()
        for _, playerSrc in ipairs(framework.getPlayers()) do
            local player = exports.qbx_core:GetPlayer(playerSrc)
            if player and player.PlayerData and player.PlayerData.job then
                dutyCache.syncOnDutyPlayer(playerSrc, player.PlayerData.job)
                syncBridgePlayer(playerSrc)
                announcePlayerLoaded(playerSrc, player.PlayerData.citizenid)
            end
        end
        dutyCache.syncGlobalJobCounts()
    end)

    AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
        if not player or not player.PlayerData then return end
        local src = player.PlayerData.source
        if player.PlayerData.job then
            dutyCache.syncOnDutyPlayer(src, player.PlayerData.job)
        end
        syncBridgePlayer(src)
        local identifier = player.PlayerData.citizenid
        if announcePlayerLoaded(src, identifier) then return end
        if identifier then return end -- already latched for this character; nothing to retry
        SetTimeout(0, function()
            announcePlayerLoaded(src, framework.getIdentifier(src))
        end)
    end)

    RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
        syncAndAnnounceLoad(source)
    end)

    AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
        TriggerEvent('Newb_Bridge:server:playerUnloaded', src)
        TriggerEvent('Newb_Bridge:server:playerUnload', src) -- deprecated 2026-12-17: use Newb_Bridge:server:playerUnloaded
    end)

    AddEventHandler('QBCore:Server:OnJobUpdate', function(src, job)
        src = tonumber(src)
        if not src or not job then return end
        dutyCache.syncOnDutyPlayer(src, job)
        syncBridgePlayer(src)
        TriggerEvent('Newb_Bridge:server:playerJobUpdated', src, job.name)
        TriggerEvent('Newb_Bridge:server:playerJobUpdate', src, job.name) -- deprecated 2026-12-17: use Newb_Bridge:server:playerJobUpdated
    end)

    AddEventHandler('QBCore:Server:SetDuty', function(src, _)
        src = tonumber(src)
        if not src then return end

        local player = exports.qbx_core:GetPlayer(src)
        if player and player.PlayerData and player.PlayerData.job then
            dutyCache.syncOnDutyPlayer(src, player.PlayerData.job)
            syncBridgePlayer(src)
        end
    end)

    AddEventHandler('playerDropped', function()
        local src = source
        TriggerEvent('Newb_Bridge:server:playerUnloaded', src)
        TriggerEvent('Newb_Bridge:server:playerUnload', src) -- deprecated 2026-12-17: use Newb_Bridge:server:playerUnloaded
    end)

    AddEventHandler('Newb_Bridge:server:playerUnloaded', function(src)
        src = tonumber(src)
        if not src then return end
        loadedPlayers[src] = nil
        dutyCache.clearOnDutyPlayer(src)
        BridgePlayers.remove(src)
    end)
end

ServerHelpers.attachSharedFrameworkApi(framework, dutyCache, function(itemName, handler)
    return exports.qbx_core:CreateUseableItem(itemName, handler)
end)

return BridgePlayers.attachBridgePlayerApi(framework)
