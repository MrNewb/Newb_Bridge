local vehiclekeys = {}

local mk = exports['mk_vehiclekeys']

function vehiclekeys.give(src, vehicle, plate)
    if not vehicle or vehicle == 0 then return end

    mk:AddKey(vehicle, src)
end

function vehiclekeys.remove(src, vehicle, plate)
    if not vehicle or vehicle == 0 then return end

    mk:RemoveKey(vehicle, src)
end

return vehiclekeys
