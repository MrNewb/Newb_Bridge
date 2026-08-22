---@param id string
---@param target? number server id, or nil for every client
---@return boolean
local function remove(id, target)
    if not id then
        lib.print.debug("Interaction ID missing for removal")
        return false
    end

    if target ~= nil then
        target = tonumber(target)
        if not target then -- never fall back to the broadcast on a bad target
            lib.print.debug("Interaction target invalid for removal:", id)
            return false
        end
    end

    TriggerClientEvent("Newb_Bridge:Interaction:Remove", target or -1, id)

    lib.print.debug("Interaction removed:", id, target or "all clients")
    return true
end

exports('RemoveInteraction', remove)
