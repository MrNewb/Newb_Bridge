-- Server-side cached player snapshot (Renewed-style) for job checks and lookups.

---@class BridgePlayer
---@field source number
---@field charId string
---@field name string
---@field jobName string|nil
---@field onDuty boolean
local BridgePlayer = lib.class('BridgePlayer')

function BridgePlayer:constructor(data)
    self.source = data.source
    self.charId = data.charId
    self.name = data.name
    self.jobName = data.jobName
    self.onDuty = data.onDuty == true
end

function BridgePlayer:getCharId()
    return self.charId
end

function BridgePlayer:getName()
    return self.name
end

local BridgePlayers = {
    store = {}, ---@type table<number, BridgePlayer>
    byCharId = {}, ---@type table<string, number> Reverse index kept in sync by BridgePlayers.sync/remove.
}

function BridgePlayers.sync(src, data)
    if not src or not data or not data.charId then return end

    local previous = BridgePlayers.store[src]
    if previous and previous.charId ~= data.charId and BridgePlayers.byCharId[previous.charId] == src then
        BridgePlayers.byCharId[previous.charId] = nil
    end

    BridgePlayers.store[src] = BridgePlayer:new({
        source = src,
        charId = data.charId,
        name = data.name or '',
        jobName = data.jobName,
        onDuty = data.onDuty,
    })
    BridgePlayers.byCharId[data.charId] = src
end

function BridgePlayers.remove(src)
    if not src then return end

    local player = BridgePlayers.store[src]
    if player and BridgePlayers.byCharId[player.charId] == src then
        BridgePlayers.byCharId[player.charId] = nil
    end

    BridgePlayers.store[src] = nil
end

function BridgePlayers.get(src)
    return BridgePlayers.store[tonumber(src) or src]
end

-- O(1) via the byCharId reverse index, kept current by sync/remove above.
function BridgePlayers.getSourceByCharId(charId)
    if not charId then return end
    return BridgePlayers.byCharId[charId]
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

    return {
        charId = pd.citizenid,
        name = ('%s %s'):format(charInfo.firstname or '', charInfo.lastname or ''),
        jobName = job and job.name,
        onDuty = job and job.onduty == true,
    }
end

function BridgePlayers.buildEsxBridgePlayerData(player)
    if not player then return end

    local job = player.getJob and player:getJob() or player.job
    if not job or not player.identifier then return end

    return {
        charId = player.identifier,
        name = player.getName and player:getName() or '',
        jobName = job.name,
        onDuty = job.onduty ~= false,
    }
end

function BridgePlayers.attachBridgePlayerApi(framework)
    framework.getPlayer = BridgePlayers.get
    framework.getSourceByCharId = BridgePlayers.getSourceByCharId
    framework.getPlayerBucket = BridgePlayers.getRoutingBucket
    framework.setPlayerBucket = BridgePlayers.setRoutingBucket
    return framework
end

return BridgePlayers
