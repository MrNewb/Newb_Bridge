local phone = {}

local function getQbPlayer(src)
    if GetResourceState('qbx_core') == 'started' then
        return exports.qbx_core:GetPlayer(src)
    end

    return exports['qb-core']:GetCoreObject().Functions.GetPlayer(src)
end

function phone.getPlayerPhone(src)
    local player = getQbPlayer(src)
    return player and player.PlayerData.charinfo.phone or false
end

function phone.sendEmail(src, email, title, message)
    local identifier = bridge.framework.getIdentifier(src)
    if not identifier then return false end

    exports['qb-phone']:sendNewMailToOffline(identifier, { sender = email, subject = title, message = message })
    return true
end

return phone
