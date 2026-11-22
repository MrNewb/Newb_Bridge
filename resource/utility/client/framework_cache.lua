---Keeps the answers to the cheap job questions inside the resource that asks. Each of these is a call into the bridge host, which costs
---between 0.09 and 0.2 ms, so a script that asks every frame paid for it every frame. The host already tells everyone when the answer
---changes, so the cache is dropped on those events and asked again on the next read.
---@param framework table
return function(framework)
    local hostGetIsPlayerLoaded = framework.getIsPlayerLoaded
    local hostGetPlayerJobData = framework.getPlayerJobData
    local loaded = false
    local jobData ---@type table?

    local function forgetJob()
        jobData = nil
    end

    AddEventHandler("Newb_Bridge:client:playerLoaded", function()
        loaded = true
        jobData = nil
    end)

    AddEventHandler("Newb_Bridge:client:playerUnloaded", function()
        loaded = false
        jobData = nil
    end)

    AddEventHandler("Newb_Bridge:client:playerJobUpdated", forgetJob)

    local function readJob()
        if not jobData then jobData = hostGetPlayerJobData() end
        return jobData
    end

    function framework.getIsPlayerLoaded()
        if loaded then return true end
        loaded = hostGetIsPlayerLoaded() == true
        return loaded
    end

    function framework.getPlayerJobData()
        local data = readJob()
        if not data then return end

        local copy = {}
        for key, value in pairs(data) do copy[key] = value end
        return copy
    end

    function framework.isOnDuty()
        local data = readJob()
        return data ~= nil and data.onDuty == true
    end

    function framework.hasJob(job, grade, duty)
        local data = readJob()
        if not data or data.jobName ~= job then return false end
        if grade and (tonumber(data.grade) or -1) < grade then return false end
        if duty and not data.onDuty then return false end
        return true
    end
end
