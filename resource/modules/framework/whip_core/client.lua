-- whip_core framework provider (client). Reads whip_core's client exports. Whip numbers a job's roles by level and the
-- client cannot list them, so the grade numbers (zero-based, lowest role first, like every other bridge framework) come
-- from the bridge host's server side, which sends them whenever the player's jobs change.

local ClientHelpers = require '@Newb_Bridge/resource/modules/framework/client_helpers'

local whip = exports.whip_core

local primaryJob ---@type table|nil The job the bridge reports: where they are on duty, else where their role is highest.
local heldJobs = {} ---@type table<string, table> Every job they hold, by key.

local function notifyJobUpdate()
    local job = primaryJob
    if not job then return end

    TriggerEvent('Newb_Bridge:client:playerJobUpdated', job.jobName, job.jobLabel, job.gradeName, job.grade)
    TriggerEvent('Newb_Bridge:client:playerJobUpdate', job.jobName, job.jobLabel, job.gradeName, job.grade) -- deprecated 2026-12-17: use Newb_Bridge:client:playerJobUpdated
end

-- framework is always proxied through the host export on the client too (see import.lua's hostBacked table), so this
-- block only runs inside the bridge host.
if bridge.isHost then
    local loadedCharId ---@type number|nil

    RegisterNetEvent('Newb_Bridge:client:whipJobsChanged', function(job, jobs)
        if source ~= 65535 then return end

        primaryJob = job
        heldJobs = jobs or {}
        notifyJobUpdate()
    end)

    local function announceLoaded(charId)
        if charId and charId == loadedCharId then return end

        loadedCharId = charId
        TriggerEvent('Newb_Bridge:client:playerLoaded')
        TriggerEvent('Newb_Bridge:client:playerLoad') -- deprecated 2026-12-17: use Newb_Bridge:client:playerLoaded
    end

    AddEventHandler('whip_core:player:loaded', function(info)
        announceLoaded(type(info) == 'table' and info.charId or whip:GetCharId())
    end)

    AddEventHandler('whip_core:player:logout', function()
        loadedCharId = nil
        primaryJob, heldJobs = nil, {}
        TriggerEvent('Newb_Bridge:client:playerUnloaded')
        TriggerEvent('Newb_Bridge:client:playerUnload') -- deprecated 2026-12-17: use Newb_Bridge:client:playerUnloaded
    end)

    -- The bridge started after the character was already in.
    CreateThread(function()
        while GetResourceState('whip_core') ~= 'started' or not whip:IsReady() do Wait(250) end

        if whip:IsPlayerLoaded() then
            loadedCharId = whip:GetCharId()
            TriggerServerEvent('Newb_Bridge:server:whipJobsRequested')
        end
    end)
end

local framework = {}

function framework.getPlayerData()
    return whip:GetPlayer()
end

function framework.getPlayerMetadata(key)
    if key == 'hunger' or key == 'thirst' then return whip:GetStat(key) end

    local data = whip:GetPlayer()
    if not data or not data.metadata then return end
    return data.metadata[key]
end

function framework.getStress()
    local data = whip:GetPlayer()
    if not data or not data.metadata then return 0 end
    return data.metadata.stress or 0
end

function framework.getHunger()
    return whip:GetStat('hunger') or 100
end

function framework.getThirst()
    return whip:GetStat('thirst') or 100
end

-- Whip's needs are server-owned stats and the client cannot write them; changing one here would only be undone by the
-- next sync, so this does nothing. Use the server's framework.addHunger / addThirst / setMetadata.
function framework.setStatus() end

function framework.isOnDuty()
    return primaryJob ~= nil and primaryJob.onDuty == true
end

function framework.getPlayerJobData()
    if not primaryJob then return end

    local copy = {}
    for key, value in pairs(primaryJob) do copy[key] = value end
    return copy
end

function framework.hasJob(job, grade, duty)
    local held = heldJobs[job]
    if not held then return false end

    if grade and held.grade < grade then return false end
    if duty and not whip:IsPlayerClockedOn(job) then return false end

    return true
end

-- Keyed by job name with zero-based grade keys, matching the other providers.
function framework.getFrameworkJobs()
    return lib.callback.await('Newb_Bridge:server:whipFrameworkJobs', false)
end

function framework.getIdentifier()
    local charId = whip:GetCharId()
    return charId and tostring(charId) or nil
end

function framework.getCharacterName()
    local data = whip:GetPlayer()
    if not data or not data.firstName then return end

    return data.fullName, data.firstName, data.lastName
end

function framework.getIsPlayerLoaded()
    return whip:IsPlayerLoaded() == true
end

-- Client-side only; not for security-sensitive logic. Whip keeps no bank balance on the client, so only cash is known.
function framework.getAccountBalance(moneyType)
    if moneyType ~= 'cash' and moneyType ~= 'money' then return 0 end

    local data = whip:GetPlayer()
    return data and data.cash or 0
end

function framework.isPlayerDead()
    return whip:IsPlayerDead() == true
end

function framework.getPlayerDob()
    local data = whip:GetPlayer()
    return data and data.dateOfBirth
end

return ClientHelpers.attachBridgeClientApi(framework)
