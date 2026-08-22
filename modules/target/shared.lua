-- Shared target cleanup. Tracks zone ids registered through this bridge copy so
-- they are removed when the owning resource stops. Providers whose underlying
-- target resource already removes zones per invoking resource (ox_target,
-- sleepless_interact) do not need this.

-- Consumers call bridge.target.* in-process, so GetInvokingResource() is usually
-- nil here; cache.resource is this copy's own resource and is the right owner.
local function CreateTargetCleanup(removeZone)
    local zonesByResource = {} ---@type table<string, (string|number)[]>

    AddEventHandler('onResourceStop', function(resourceName)
        local zones = zonesByResource[resourceName]
        if not zones then return end

        for i = 1, #zones do
            removeZone(zones[i])
        end

        zonesByResource[resourceName] = nil
    end)

    return function(zoneId)
        if zoneId == nil then return zoneId end

        local resource = GetInvokingResource() or cache.resource
        local zones = zonesByResource[resource]
        if not zones then
            zones = {}
            zonesByResource[resource] = zones
        end

        zones[#zones + 1] = zoneId
        return zoneId
    end
end
