-- Client-side group cache and routing bucket helpers for framework adapters.

local ClientHelpers = {}

local cachedGroups ---@type table<string, number>|nil

function ClientHelpers.refreshCachedPlayerGroups(job, gang)
    if not job then
        cachedGroups = nil
        return
    end

    local groups = {}

    if job.name then
        local grade = job.grade
        groups[job.name] = type(grade) == 'table' and grade.level or grade or 0
    end

    if gang and gang.name and gang.name ~= 'none' then
        local gangGrade = gang.grade
        groups[gang.name] = type(gangGrade) == 'table' and gangGrade.level or gangGrade or 0
    end

    cachedGroups = groups
end

function ClientHelpers.clearCachedPlayerGroups()
    cachedGroups = nil
end

local function bridgeHasGroup(group, grade, duty)
    if not cachedGroups then return false end

    local playerGrade = cachedGroups[group]
    if playerGrade == nil then return false end
    if grade and playerGrade < grade then return false end

    if duty and CachedPlayerJob and CachedPlayerJob.name == group and not CachedPlayerJob.onduty then
        return false
    end

    return true
end

function ClientHelpers.getPlayerRoutingBucket()
    return LocalPlayer.state.bucket or 0
end

function ClientHelpers.attachBridgeClientGroupApi(framework)
    framework.hasGroup = bridgeHasGroup
    framework.getGroups = function()
        return cachedGroups
    end
    framework.getPlayerBucket = ClientHelpers.getPlayerRoutingBucket
    return framework
end

return ClientHelpers
