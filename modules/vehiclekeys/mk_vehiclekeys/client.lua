local vehiclekeys = {}

local mk = exports['mk_vehiclekeys']

function vehiclekeys.give(vehicle, plate)
    if not vehicle or vehicle == 0 then return end

    mk:AddKey(vehicle)
end

function vehiclekeys.remove(vehicle, plate)
    if not vehicle or vehicle == 0 then return end

    mk:RemoveKey(vehicle)
end

return vehiclekeys
