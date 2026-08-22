local ClientHelpers = require '@Newb_Bridge/modules/framework/client_helpers'

CachedPlayerJob = nil

local ESX = exports.es_extended:getSharedObject()
local framework = {}

local function getPlayerData()
    return ESX.GetPlayerData()
end

local function getJob()
    if CachedPlayerJob then return CachedPlayerJob end

    local data = getPlayerData()
    return data and data.job
end

local function getStatusData(search)
    local playerData = getPlayerData()
    if not playerData or not playerData.variables or not playerData.variables.status then return 0 end

    for _, entry in ipairs(playerData.variables.status) do
        if entry.name == search then
            return entry.percent or 0
        end
    end

    return 0
end

RegisterNetEvent('esx:playerLoaded', function()
    if not bridge.isHost then return end

    CreateThread(function()
        Wait(0)

        local data = getPlayerData()
        CachedPlayerJob = data and data.job
        ClientHelpers.refreshCachedPlayerGroups(CachedPlayerJob)

        TriggerEvent('Newb_Bridge:client:playerLoad')
    end)
end)

RegisterNetEvent('esx:onPlayerLogout', function()
    if bridge.isHost then
        CachedPlayerJob = nil
        ClientHelpers.clearCachedPlayerGroups()
        TriggerEvent('Newb_Bridge:client:playerUnload')
    end
end)

RegisterNetEvent('esx:setJob', function(job)
    if not bridge.isHost or not job then return end

    CachedPlayerJob = job
    ClientHelpers.refreshCachedPlayerGroups(job)

    TriggerEvent(
        'Newb_Bridge:client:playerJobUpdate',
        job.name,
        job.label,
        job.grade_name or job.grade_label,
        job.grade
    )
end)

function framework.getStress()
    return math.floor(getStatusData('stress') + 0.5)
end

function framework.getHunger()
    return math.floor(getStatusData('hunger') + 0.5)
end

function framework.getThirst()
    return math.floor(getStatusData('thirst') + 0.5)
end

function framework.setStatus(statusType, value)
    if statusType == "stress" then
        TriggerEvent("esx_status:set", 'stress', value)
    elseif statusType == "hunger" then
        TriggerEvent("esx_status:set", 'hunger', value)
    elseif statusType == "thirst" then
        TriggerEvent("esx_status:set", 'thirst', value)
    end
end

function framework.isOnDuty()
    local job = getJob()
    if not job then return false end
    return job.onduty ~= false
end

function framework.hasJob(job, grade, duty)
    local playerJob = getJob()
    if not playerJob then return false end
    if playerJob.name ~= job then return false end
    if grade and playerJob.grade < grade then return false end
    if duty and playerJob.onduty == false then return false end
    return true
end

function framework.getPlayerData()
    return getPlayerData()
end

function framework.getPlayerMetadata(key)
    local data = getPlayerData()
    if not data then return end
    if data.metadata then return data.metadata[key] end
    if data.variables then return data.variables[key] end
end

function framework.getPlayerJobData()
    local job = getJob()
    if not job then return end

    return {
        jobName = job.name,
        jobLabel = job.label,
        grade = job.grade,
        gradeName = job.grade_name,
        onDuty = job.onduty ~= false,
        isBoss = job.grade_name == 'boss',
    }
end

function framework.getFrameworkJobs()
    return lib.callback.await('Newb_Bridge:callback:getFrameworkJobs', false) or {}
end

function framework.getIdentifier()
    local data = getPlayerData()
    return data and data.identifier
end

function framework.getCharacterName()
    local player = getPlayerData()
    if not player or not player.firstName or not player.lastName then return end

    return ("%s %s"):format(player.firstName, player.lastName), player.firstName, player.lastName
end

function framework.getIsPlayerLoaded()
    return ESX.IsPlayerLoaded()
end

-- Client-side only; not for security-sensitive logic.
function framework.getAccountBalance(moneyType)
    local data = getPlayerData()
    if not data or not data.accounts then return 0 end
    if moneyType == "cash" then moneyType = "money" end
    for _, account in ipairs(data.accounts) do
        if account.name == moneyType then
            return account.money or 0
        end
    end
    return 0
end

function framework.isPlayerDead()
    local data = getPlayerData()
    return data and data.dead or false
end

function framework.getPlayerDob()
    local data = getPlayerData()
    return data and data.dateofbirth
end

return ClientHelpers.attachBridgeClientGroupApi(framework)
