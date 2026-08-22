-- Server-side cached player snapshot (Renewed-style) for group checks and lookups.

---@class BridgePlayer
---@field source number
---@field charId string
---@field name string
---@field groups table<string, number>
---@field jobName string|nil
---@field onDuty boolean
local BridgePlayer = lib.class('BridgePlayer')

function BridgePlayer:constructor(data)
    self.source = data.source
    self.charId = data.charId
    self.name = data.name
    self.groups = data.groups or {}
    self.jobName = data.jobName
    self.onDuty = data.onDuty == true
end

function BridgePlayer:hasGroup(group, grade, duty)
    local playerGrade = self.groups[group]
    if playerGrade == nil then return false end
    if grade and playerGrade < grade then return false end
    if duty and self.jobName == group and not self.onDuty then return false end
    return true
end

function BridgePlayer:getCharId()
    return self.charId
end

function BridgePlayer:getName()
    return self.name
end

function BridgePlayer:getGroups()
    return self.groups
end

local BridgePlayers = {
    store = {} ---@type table<number, BridgePlayer>
}

function BridgePlayers.sync(src, data)
    if not src or not data or not data.charId then return end

    BridgePlayers.store[src] = BridgePlayer:new({
        source = src,
        charId = data.charId,
        name = data.name or '',
        groups = data.groups or {},
        jobName = data.jobName,
        onDuty = data.onDuty,
    })
end

function BridgePlayers.remove(src)
    if not src then return end
    BridgePlayers.store[src] = nil
end

function BridgePlayers.get(src)
    return BridgePlayers.store[tonumber(src) or src]
end

function BridgePlayers.getSourceByCharId(charId)
    if not charId then return end

    for source, player in pairs(BridgePlayers.store) do
        if player.charId == charId then
            return source
        end
    end
end

function BridgePlayers.hasGroup(src, group, grade, duty)
    local player = BridgePlayers.get(src)
    if not player then return false end
    return player:hasGroup(group, grade, duty)
end

function BridgePlayers.getGroups(src)
    local player = BridgePlayers.get(src)
    return player and player.groups
end

function BridgePlayers.getRoutingBucket(src)
    src = tonumber(src)
    if not src then return 0 end

    return GetPlayerRoutingBucket(src)
end

-- Uses ox_lib Player:setRoutingBucket; ox_lib replicates `bucket` to clients for getRoutingBucket().
function BridgePlayers.setRoutingBucket(src, bucketId)
    src = tonumber(src)
    bucketId = tonumber(bucketId) or 0
    if not src then return false end

    lib.player:new(src):setRoutingBucket(bucketId)
    return true
end

function BridgePlayers.buildQbBridgePlayerData(player)
    if not player or not player.PlayerData then return end

    local pd = player.PlayerData
    local job = pd.job
    local charInfo = pd.charinfo or {}
    local groups = {}

    if job and job.name then
        local grade = job.grade
        groups[job.name] = type(grade) == 'table' and grade.level or grade or 0
    end

    local gang = pd.gang
    if gang and gang.name and gang.name ~= 'none' then
        local gangGrade = gang.grade
        groups[gang.name] = type(gangGrade) == 'table' and gangGrade.level or gangGrade or 0
    end

    return {
        charId = pd.citizenid,
        name = ('%s %s'):format(charInfo.firstname or '', charInfo.lastname or ''),
        groups = groups,
        jobName = job and job.name,
        onDuty = job and job.onduty == true,
    }
end

function BridgePlayers.buildEsxBridgePlayerData(player)
    if not player then return end

    local job = player.getJob and player:getJob() or player.job
    if not job or not player.identifier then return end

    local groups = {}
    if job.name then
        groups[job.name] = job.grade or 0
    end

    return {
        charId = player.identifier,
        name = player.getName and player:getName() or '',
        groups = groups,
        jobName = job.name,
        onDuty = job.onduty ~= false,
    }
end

function BridgePlayers.attachBridgePlayerApi(framework)
    framework.getPlayer = BridgePlayers.get
    framework.getGroups = BridgePlayers.getGroups
    framework.hasGroup = BridgePlayers.hasGroup
    framework.getSourceByCharId = BridgePlayers.getSourceByCharId
    framework.getPlayerBucket = BridgePlayers.getRoutingBucket
    framework.setPlayerBucket = BridgePlayers.setRoutingBucket
    return framework
end

return BridgePlayers
