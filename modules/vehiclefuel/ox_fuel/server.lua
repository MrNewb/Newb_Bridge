local vehiclefuel = {}

function vehiclefuel.set(source, vehicle, amount)
    if not vehicle or not DoesEntityExist(vehicle) then return false end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not netId or netId <= 0 then return false end

    TriggerClientEvent("Newb_Bridge:client:setFuel", source, netId, amount)
    return true
end

return vehiclefuel
