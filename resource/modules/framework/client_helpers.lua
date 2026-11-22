-- Client-side routing bucket helper for framework adapters.

local ClientHelpers = {}

function ClientHelpers.getPlayerRoutingBucket()
    return LocalPlayer.state.bucket or 0
end

function ClientHelpers.attachBridgeClientApi(framework)
    framework.getPlayerBucket = ClientHelpers.getPlayerRoutingBucket
    return framework
end

return ClientHelpers
