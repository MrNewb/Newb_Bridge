local dispatch = {}

local function normalizeJobs(jobs)
    if type(jobs) == 'string' then
        return { jobs }
    end

    local normalized = {}
    for _, job in ipairs(jobs or {}) do
        if type(job) == 'string' and job ~= '' then
            normalized[#normalized + 1] = job
        end
    end

    return normalized[1] and normalized or { 'police' }
end

local function collectPlayerSources(playerSet)
    if type(playerSet) ~= 'table' then return {} end

    if playerSet[1] then
        return playerSet
    end

    local sources = {}
    for src in pairs(playerSet) do
        sources[#sources + 1] = tonumber(src) or src
    end

    return sources
end

local function getEligibleTargets(jobList)
    local framework = bridge and bridge.framework
    if not framework then
        return {}
    end

    local targets = {}
    local seen = {}

    for _, jobName in ipairs(jobList) do
        local players = collectPlayerSources(framework.getPlayersOnDuty and framework.getPlayersOnDuty(jobName))
        if not players[1] then
            players = collectPlayerSources(framework.getPlayersByJob and framework.getPlayersByJob(jobName))
        end

        for _, src in ipairs(players) do
            local numericSrc = tonumber(src)
            if numericSrc and not seen[numericSrc] then
                seen[numericSrc] = true
                targets[#targets + 1] = numericSrc
            end
        end
    end

    return targets
end

function dispatch.sendAlert(src, jobs, coords, data, blip, alertFlash)
    if not coords then return false end

    local payload = {
        coords = coords,
        title = data and (data.title or data.code or 'Dispatch') or 'Dispatch',
        description = data and (data.description or '') or '',
        code = data and (data.code or data.title or '10-11') or '10-11',
        jobs = normalizeJobs(jobs),
        blip = blip or {},
        length = data and data.length or blip and blip.length or 8,
        flash = alertFlash == true,
        icon = data and data.icon or 'bell',
    }

    local targets = getEligibleTargets(payload.jobs)
    if not next(targets) then return false end

    for _, targetSrc in ipairs(targets) do
        TriggerClientEvent('Newb_Bridge:dispatch:internalAlert', targetSrc, payload)
    end

    return true
end

return dispatch
