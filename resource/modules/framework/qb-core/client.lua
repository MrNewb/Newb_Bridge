local ClientHelpers = require '@Newb_Bridge/resource/modules/framework/client_helpers'

local cachedPlayerJob

local QBCore = exports['qb-core']:GetCoreObject()

-- Re-pull after runtime Shared changes so the copied core stays current.
RegisterNetEvent('QBCore:Client:UpdateObject', function()
    QBCore = exports['qb-core']:GetCoreObject()
end)

local function getPlayerData()
    return QBCore.Functions.GetPlayerData()
end

local function getJob()
    if cachedPlayerJob then return cachedPlayerJob end

    local data = getPlayerData()
    return data and data.job
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
    if not bridge.isHost then return end
    cachedPlayerJob = nil
    TriggerEvent('Newb_Bridge:client:playerUnloaded')
    TriggerEvent('Newb_Bridge:client:playerUnload') -- deprecated 2026-12-17: use Newb_Bridge:client:playerUnloaded
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    if not bridge.isHost or not job then return end

    cachedPlayerJob = job

    local gradeName = job.grade and job.grade.name or job.grade_label
    local gradeLevel = job.grade and job.grade.level or job.grade

    TriggerEvent('Newb_Bridge:client:playerJobUpdated', job.name, job.label, gradeName, gradeLevel)
    TriggerEvent('Newb_Bridge:client:playerJobUpdate', job.name, job.label, gradeName, gradeLevel) -- deprecated 2026-12-17: use Newb_Bridge:client:playerJobUpdated
end)

RegisterNetEvent('QBCore:Client:SetDuty', function(onDuty)
    if not bridge.isHost then return end

    local data = getPlayerData()
    if not data or not data.job then return end

    cachedPlayerJob = data.job
    cachedPlayerJob.onduty = onDuty

    local job = cachedPlayerJob
    local gradeName = job.grade and job.grade.name or job.grade_label
    local gradeLevel = job.grade and job.grade.level or job.grade

    TriggerEvent('Newb_Bridge:client:playerJobUpdated', job.name, job.label, gradeName, gradeLevel)
    TriggerEvent('Newb_Bridge:client:playerJobUpdate', job.name, job.label, gradeName, gradeLevel) -- deprecated 2026-12-17: use Newb_Bridge:client:playerJobUpdated
end)

local framework = {}

function framework.getPlayerData()
    return getPlayerData()
end

function framework.getPlayerMetadata(key)
    local data = getPlayerData()
    if not data or not data.metadata then return end
    return data.metadata[key]
end

function framework.getStress()
    local data = getPlayerData()
    if not data or not data.metadata then return 0 end
    return data.metadata.stress or 0
end

function framework.getHunger()
    local data = getPlayerData()
    if not data or not data.metadata then return 100 end
    return data.metadata.hunger or 100
end

function framework.getThirst()
    local data = getPlayerData()
    if not data or not data.metadata then return 100 end
    return data.metadata.thirst or 100
end

function framework.setStatus(statusType, value)
    local data = getPlayerData()
    if not data then return end

    data.metadata = data.metadata or {}
    if statusType == 'stress' then
        data.metadata.stress = value
    elseif statusType == 'hunger' then
        data.metadata.hunger = value
    elseif statusType == 'thirst' then
        data.metadata.thirst = value
    end
end

function framework.isOnDuty()
    local job = getJob()
    if not job then return false end
    return job.onduty == true
end

function framework.getPlayerJobData()
    local job = getJob()
    if not job or job.grade == nil then return end

    local grade = job.grade

    return {
        jobName = job.name,
        jobLabel = job.label,
        grade = type(grade) == 'table' and grade.level or grade,
        gradeName = type(grade) == 'table' and grade.name or job.grade_label,
        onDuty = job.onduty == true,
        isBoss = job.isboss == true,
    }
end

function framework.hasJob(job, grade, duty)
    local playerJob = getJob()
    if not playerJob or playerJob.grade == nil then return false end
    if playerJob.name ~= job then return false end

    local gradeLevel = type(playerJob.grade) == 'table' and playerJob.grade.level or playerJob.grade
    if grade and gradeLevel < grade then return false end
    if duty and not playerJob.onduty then return false end
    return true
end

function framework.getFrameworkJobs()
    -- Keyed by job name - consumers look up jobs[jobName].
    return QBCore.Shared.Jobs or {}
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
    if moneyType == 'money' then moneyType = 'cash' end
    return data.money[moneyType] or 0
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
