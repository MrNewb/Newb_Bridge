local ClientHelpers = require '@Newb_Bridge/resource/modules/framework/client_helpers'

local cachedPlayerJob

local ESX = exports.es_extended:getSharedObject()
local framework = {}

local function getPlayerData()
    return ESX.GetPlayerData()
end

local function getJob()
    if cachedPlayerJob then return cachedPlayerJob end

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

-- framework is always proxied through the host export on the client too (see
-- import.lua's hostBacked table), so this file only ever loads once, inside
-- the actual bridge host. The isHost checks below are insurance against that
-- routing ever changing (it's what stops every importer from separately
-- registering these ESX net events and firing Newb_Bridge:client:playerLoaded
-- once per importer), not because they're expected to be false normally.
RegisterNetEvent('esx:playerLoaded', function()
    if not bridge.isHost then return end

    CreateThread(function()
        Wait(0)

        local data = getPlayerData()
        cachedPlayerJob = data and data.job

        TriggerEvent('Newb_Bridge:client:playerLoaded')
        TriggerEvent('Newb_Bridge:client:playerLoad') -- deprecated 2026-12-17: use Newb_Bridge:client:playerLoaded
    end)
end)

RegisterNetEvent('esx:onPlayerLogout', function()
    if bridge.isHost then
        cachedPlayerJob = nil
        TriggerEvent('Newb_Bridge:client:playerUnloaded')
        TriggerEvent('Newb_Bridge:client:playerUnload') -- deprecated 2026-12-17: use Newb_Bridge:client:playerUnloaded
    end
end)

RegisterNetEvent('esx:setJob', function(job)
    if not bridge.isHost or not job then return end

    cachedPlayerJob = job

    local gradeName = job.grade_name or job.grade_label
    TriggerEvent('Newb_Bridge:client:playerJobUpdated', job.name, job.label, gradeName, job.grade)
    TriggerEvent('Newb_Bridge:client:playerJobUpdate', job.name, job.label, gradeName, job.grade) -- deprecated 2026-12-17: use Newb_Bridge:client:playerJobUpdated
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
    if grade and (tonumber(playerJob.grade) or -1) < grade then return false end
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
    local ok, jobs = pcall(lib.callback.await, 'Newb_Bridge:callback:getFrameworkJobs', false)
    return ok and jobs or {}
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

return ClientHelpers.attachBridgeClientApi(framework)
