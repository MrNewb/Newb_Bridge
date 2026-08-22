local vehiclefuel = {}

local function setFuel(entityId, amount)
    if not entityId or entityId == 0 or not DoesEntityExist(entityId) then return end

    exports.lc_fuel:SetFuel(entityId, amount)
end

function vehiclefuel.set(vehicle, amount)
    setFuel(vehicle, amount)
end

if bridge.isHost then
    RegisterNetEvent("Newb_Bridge:client:setFuel", function(netId, amount)
        if source ~= 65535 then return end
        setFuel(NetworkGetEntityFromNetworkId(netId), amount)
    end)
end

return vehiclefuel
