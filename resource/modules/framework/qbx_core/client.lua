local ClientHelpers = require '@Newb_Bridge/resource/modules/framework/client_helpers'

local cachedPlayerJob

local QBX = exports.qbx_core
local playerState = LocalPlayer.state

local function getPlayerData()
    return QBX:GetPlayerData()
end

local function getJob()
    if cachedPlayerJob then return cachedPlayerJob end

    local data = getPlayerData()
    return data and data.job
end

local function getMetadataValue(key)
    local data = getPlayerData()
    if data and data.metadata and data.metadata[key] ~= nil then
        return data.metadata[key]
    end

    return playerState[key]
end

-- framework is always proxied through the host export on the client too (see
-- import.lua's hostBacked table), so this file only ever loads once, inside
-- the actual bridge host. The isHost checks below are insurance against that
-- routing ever changing (it's what stops every importer from separately
-- registering these QBCore net events and firing Newb_Bridge:client:playerLoaded
-- once per importer), not because they're expected to be false normally.
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    if not bridge.isHost then return end

    CreateThread(function()
        Wait(0)

        local data = getPlayerData()
        cachedPlayerJob = data and data.job

        TriggerEvent('Newb_Bridge:client:playerLoaded')
        TriggerEvent('Newb_Bridge:client:playerLoad') -- deprecated 2026-12-17: use Newb_Bridge:client:playerLoaded
    end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    if bridge.isHost then
        cachedPlayerJob = nil
        TriggerEvent('Newb_Bridge:client:playerUnloaded')
        TriggerEvent('Newb_Bridge:client:playerUnload') -- deprecated 2026-12-17: use Newb_Bridge:client:playerUnloaded
    end
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    if not bridge.isHost or not job or not job.grade then return end

    cachedPlayerJob = job

    TriggerEvent('Newb_Bridge:client:playerJobUpdated', job.name, job.label, job.grade.name, job.grade.level)
    TriggerEvent('Newb_Bridge:client:playerJobUpdate', job.name, job.label, job.grade.name, job.grade.level) -- deprecated 2026-12-17: use Newb_Bridge:client:playerJobUpdated
end)

RegisterNetEvent('QBCore:Client:SetDuty', function(onDuty)
    if not bridge.isHost then return end

    local data = getPlayerData()
    if not data or not data.job or not data.job.grade then return end

    cachedPlayerJob = data.job
    cachedPlayerJob.onduty = onDuty

    local job = cachedPlayerJob
    TriggerEvent('Newb_Bridge:client:playerJobUpdated', job.name, job.label, job.grade.name, job.grade.level)
    TriggerEvent('Newb_Bridge:client:playerJobUpdate', job.name, job.label, job.grade.name, job.grade.level) -- deprecated 2026-12-17: use Newb_Bridge:client:playerJobUpdated
end)

local framework = {}

function framework.getPlayerData()
    return getPlayerData()
end

function framework.getPlayerMetadata(key)
    return getMetadataValue(key)
end

function framework.getStress()
    local stress = getMetadataValue('stress') or 0
    return math.floor(stress + 0.5)
end

function framework.getHunger()
    local hunger = getMetadataValue('hunger') or 100
    return math.floor(hunger + 0.5)
end

function framework.getThirst()
    local thirst = getMetadataValue('thirst') or 100
    return math.floor(thirst + 0.5)
end

function framework.setStatus(statusType, value)
    if statusType == 'stress' then
        playerState.stress = value
    elseif statusType == 'hunger' then
        playerState.hunger = value
    elseif statusType == 'thirst' then
        playerState.thirst = value
    end
end

function framework.isOnDuty()
    local job = getJob()
    if not job then return false end
    return job.onduty == true
end

function framework.getPlayerJobData()
    local job = getJob()
    if not job or not job.grade then return end

    return {
        jobName = job.name,
        jobLabel = job.label,
        grade = job.grade.level,
        gradeName = job.grade.name,
        onDuty = job.onduty == true,
        isBoss = job.isboss == true,
    }
end

function framework.hasJob(job, grade, duty)
    local playerJob = getJob()
    if not playerJob or not playerJob.grade then return false end
    if playerJob.name ~= job then return false end
    if grade and playerJob.grade.level < grade then return false end
    if duty and not playerJob.onduty then return false end
    return true
end

function framework.getFrameworkJobs()
    -- Keyed by job name - consumers look up jobs[jobName].
    return QBX:GetJobs() or {}
end

function framework.getIdentifier()
    local data = getPlayerData()
    return data and data.citizenid
end

function framework.getCharacterName()
    local data = getPlayerData()
    if not data or not data.charinfo then return end

    local first = data.charinfo.firstname
    local last = data.charinfo.lastname
    if not first or not last then return end

    return ('%s %s'):format(first, last), first, last
end

function framework.getIsPlayerLoaded()
    return LocalPlayer.state.isLoggedIn or false
end

-- Client-side only; not for security-sensitive logic.
function framework.getAccountBalance(moneyType)
    local data = getPlayerData()
    if not data or not data.money then return 0 end

    if moneyType == 'money' then
        moneyType = 'cash'
    end

    local balance = data.money[moneyType] or 0
    if balance <= 0 then return 0 end
    return balance
end

function framework.isPlayerDead()
    local data = getPlayerData()
    if not data or not data.metadata then return false end
    return data.metadata.isdead or data.metadata.inlaststand or false
end

function framework.getPlayerDob()
    local data = getPlayerData()
    return data and data.charinfo and data.charinfo.birthdate
end

return ClientHelpers.attachBridgeClientApi(framework)
