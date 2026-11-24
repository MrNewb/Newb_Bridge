local function padVersion(version)
    local parts = {}
    for num in version:gmatch("%d+") do parts[#parts + 1] = tonumber(num) end
    while #parts < 3 do parts[#parts + 1] = 0 end
    return parts
end

local function compareVersions(v1, v2)
    local a, b = padVersion(v1), padVersion(v2)
    for i = 1, 3 do
        if a[i] ~= b[i] then return a[i] < b[i] and -1 or 1 end
    end
    return 0
end

local function collectNewerVersions(allVersions, localVersion)
    local result = {}
    for versionStr, notes in pairs(allVersions) do
        if compareVersions(versionStr, localVersion) > 0 and type(notes) == "table" then
            result[#result + 1] = { version = versionStr, notes = notes }
        end
    end
    table.sort(result, function(a, b) return compareVersions(a.version, b.version) < 0 end)
    return result
end

local function fetchAndPrint(branch, resource, repoPath, localVersion)
    local username, reponame = repoPath:match("([^/]+)/([^/]+)")
    local url = ('https://raw.githubusercontent.com/%s/%s/%s/resources.json'):format(username, reponame, branch)

    PerformHttpRequest(url, function(status, body)
        if status ~= 200 then
            if branch == "main" then fetchAndPrint("master", resource, repoPath, localVersion) end
            return
        end

        local patchData = json.decode(body)
        if not patchData then return end

        local resourceData = patchData[resource]
        if type(resourceData) ~= "table" then return end

        local newer = collectNewerVersions(resourceData.versions or resourceData, localVersion)
        if #newer == 0 then return end

        local githubRepo = resourceData.repo or resourceData.actualRepoPath
        local downloadUrl = 'https://portal.cfx.re/assets/granted-assets'
        if type(githubRepo) == 'string' and githubRepo ~= '' then
            downloadUrl = ('https://github.com/%s'):format(githubRepo)
        elseif type(resourceData.portal) == 'string' and resourceData.portal ~= '' then
            downloadUrl = resourceData.portal
        end

        print(bridge.locale('system.version_update_available', {
            resource = resource,
            version = localVersion,
            url = downloadUrl,
        }))
        print(bridge.locale('system.version_patch_notes'))
        for _, entry in ipairs(newer) do
            print(bridge.locale('system.version_entry', { version = entry.version }))
            for _, line in ipairs(entry.notes) do
                print(bridge.locale('system.version_note_line', { line = line }))
            end
        end
    end, 'GET')
end

-- Pulls versions and patch notes from the remote resources.json.
local function VersionCheck(repoPath, resourceName)
    if Config.VersionCheck == false then return end

    if type(repoPath) ~= "string" or type(resourceName) ~= "string" then
        return print(bridge.locale('system.version_invalid_repo'))
    end

    local username, reponame = repoPath:match("([^/]+)/([^/]+)")
    if not username or not reponame then
        return print(bridge.locale('system.version_invalid_repo'))
    end

    local localVersionRaw = GetResourceMetadata(resourceName, "version", 0)
    local localVersion = localVersionRaw and localVersionRaw:match('%d+%.%d+%.%d+')
    if not localVersion then
        return print(bridge.locale('system.version_not_found', { resource = resourceName }))
    end

    fetchAndPrint("main", resourceName, repoPath, localVersion)
end

if Config.VersionCheck ~= false then
    print(bridge.locale('system.version_check_start'))
    VersionCheck("MrNewb/patchnotes", cache.resource)
end

exports('VersionCheck', VersionCheck)